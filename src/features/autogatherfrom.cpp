// autoGatherFrom [log]: a unit idle for a few seconds gathers on its own from a unit of a type named in its action.
//
//   <action> <type>Gather</type> <maxrange>6</maxrange> ...
//     <AutogatherFrom delay="3">AbstractTypeHerdableMagnet</AutogatherFrom>   (a proto or a unit type; delay in
//   </action>                                                                    seconds, 3 when absent)
//
// The tag goes in any action of a .tactics file or a protoy.xml <ProtoAction> (the shared action tag hook,
// actiontags.h); an action may hold several. Its range is the longest of the action's ranges (maxrange and its
// typedmaxrange entries: [action+18h], 16-byte entries, count [action+1Ch], +8 the maximum).
//
// After each world update (worldtick.h), every 500 ms of game time, for every unit of every player (the player's unit
// list [player+F8h], in ID order) whose proto has a tagged action:
// - a unit that is busy (its current action [[unit+58h]+24h] is not null, 0x44F1A7) is left alone: a player's order,
//   a fight or a gather in progress always wins; while it gathers (Gather action, vtable 0xB97880) its leash anchor
//   [mgr+7Ch] follows it, so that a unit that followed a moving target does not walk back to where it started;
// - a unit idle for `delay` seconds of game time gets a work order (0x4EFCB2, the order the stock herdable search
//   0x4C31EE gives: thiscall(mgr, targetId, 0, -1, 0)) on the nearest unit of a tagged type within the action's range
//   (0x4A1C55; distance to the target's edge, its vtable +B8h), owned by the unit's player, an ally or Gaia, alive;
//   the stock order code then picks the action and walks the unit as a right-click would; a target the player cannot
//   see (0x48A9EF, the test the Gather update makes before it drops such an order, 0x4EC753) is not picked;
// - a unit that gained nothing (its held amount 0x4E5979 did not rise) from the last order to the same target is
//   not sent there again until its amount changes: a fattened herdable, for one, is refused by the gather tick.
// Inside a building or a transport ([unit+6Ch] != -1), not built (0x44DDB4), or without an inventory
// ([[unit+B4h]+94h], which the gather start requires of the gatherer, 0x50DE89), a unit is skipped.
// A unit that cannot move (MaxVelocity [proto+80h] at 0: a building) is ordered only while buildingGather is on, since
// its Gather action never starts otherwise; its target must pass the gather's own range test (its vtable +CCh with the
// action's range, which counts its size), as a building cannot walk closer.
//
// Everything read is simulation state (no local player, no clock but the game time [world+108h]); the per-unit table
// is only a cache (idle-since time, last target, held amount): a loaded game rebuilds it, and a unit idle at the load
// waits `delay` again.
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <cwctype>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kScanMs = 500;
constexpr std::uint32_t kGatherVtable = 0x00B97880;
constexpr std::int32_t kDefaultDelayMs = 3000;
constexpr float kSearchSlack = 12.0f;  // metres added to the search radius: the largest target's half size
constexpr int kMaxLogLines = 300;

struct IdList {
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using UnitsNearFn = std::int32_t(__thiscall*)(const char* world, const float* point, float radius, char precise, IdList* out);
using IdleFn = bool(__thiscall*)(const char* mgr);
using UnitTestFn = bool(__thiscall*)(const char* unit);
using IsEnemyFn = bool(__thiscall*)(const char* player, std::int32_t otherId);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using HeldAmountFn = float(__thiscall*)(const char* unit, std::int32_t resource);
using MainResourceFn = std::int32_t(__thiscall*)(const char* unit);
using DistanceFn = float(__thiscall*)(const char* unit, const float* point);
using WorkOrderFn = bool(__thiscall*)(char* mgr, std::int32_t target, std::int32_t a2, std::int32_t a3, std::int32_t a4);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);

const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);
const auto kIdle = reinterpret_cast<IdleFn>(0x0044F1A7);
const auto kIsBuilt = reinterpret_cast<UnitTestFn>(0x0044DDB4);
const auto kIsEnemy = reinterpret_cast<IsEnemyFn>(0x00484D2D);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kHeldAmount = reinterpret_cast<HeldAmountFn>(0x004E5979);
const auto kMainResource = reinterpret_cast<MainResourceFn>(0x004DBEC1);
const auto kWorkOrder = reinterpret_cast<WorkOrderFn>(0x004EFCB2);
using InRangeFn = bool(__thiscall*)(const char* unit, const char* target, float range);
using SeeableFn = bool(__thiscall*)(const char* unit, std::int32_t player);
const auto kIsSeeable = reinterpret_cast<SeeableFn>(0x0048A9EF);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

// One <AutogatherFrom> tag.
struct Source {
  std::string name;
  std::int32_t type = -2;  // unittype ID (proto or abstract type); -2 not looked up yet, -1 unknown
  std::int32_t delayMs = kDefaultDelayMs;
};

struct ActionKey {
  std::int32_t proto;  // [proto+4]
  std::int32_t name;   // [action+4]
  auto operator<=>(const ActionKey&) const = default;
};

std::map<ActionKey, std::vector<Source>> g_tags;
std::map<std::int32_t, std::vector<ActionKey>> g_byProto;  // proto ID -> its tagged actions

// What a unit's proto (the player's copy) gathers from: the sources of its tagged actions, each with that action's
// range. A cache by proto pointer, emptied with the data.
struct Want {
  const Source* source;
  float range;
};
std::unordered_map<const char*, std::vector<Want>> g_wants;

struct Unit {
  std::uint32_t idleSince = 0;  // game time, 0 while busy
  std::int32_t lastTarget = -1;
  float heldAtOrder = -1.0f;    // the held amount when it was last ordered to lastTarget
  bool refused = false;         // that order gained nothing: not again until the amount changes
};
std::map<std::int32_t, Unit> g_units;

bool g_log = false;
int g_logLines = 0;
std::set<std::string> g_badNames;  // bad values already logged since the data load
std::uint32_t g_lastScan = 0;
std::uint32_t g_lastTime = 0;
const char* g_lastWorld = nullptr;
IdList g_found = {nullptr, 0, 0};

}  // namespace

bool g_uhcBuildingGather = false;  // buildinggather.cpp sets it when that key is applied

namespace {

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* World() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

const char* Database() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

bool Alive(const char* unit) { return Field<UnitTestFn const*>(unit, 0)[0xA4 / 4](unit); }

std::int32_t OwnerId(const char* unit) {
  const char* player = Field<const char*>(unit, 0x44);
  return player == nullptr ? -1 : Field<std::int32_t>(player, 0);
}

const char* PlayerAt(const char* world, std::int32_t id) {
  return id < 0 || id >= Field<std::int32_t>(world, 0x5C) ? nullptr : Field<const char* const*>(world, 0x58)[id];
}

void Note(const wchar_t* format, ...) {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return;
  }
  ++g_logLines;
  wchar_t text[512];
  va_list args;
  va_start(args, format);
  _vsnwprintf_s(text, _TRUNCATE, format, args);
  va_end(args);
  uhc::Log(L"%ls", text);
}

// ---- the tag ---------------------------------------------------------------------------------------------------

std::int32_t DelayOf(const char* node) {
  for (const char* name : {"delay", "Delay", "DELAY"}) {
    const void* text = nullptr;
    if (node != nullptr && kXmlAttribute(node, name, &text) && text != nullptr) {
      const char* value = kXmlText(text);
      char* end = nullptr;
      const double seconds = value == nullptr ? -1.0 : std::strtod(value, &end);
      if (value == nullptr || end == value || !(seconds >= 0.0) || seconds > 3600.0) {
        const std::string bad = value == nullptr ? "" : value;
        if (g_badNames.insert("delay=" + bad).second) {  // once per load: every proto of a tactics file reads it
          uhc::Log(L"autoGatherFrom: delay=\"%hs\" is not a number of seconds from 0 to 3600; 3 s", bad.c_str());
        }
        return kDefaultDelayMs;
      }
      return static_cast<std::int32_t>(seconds * 1000.0 + 0.5);
    }
  }
  return kDefaultDelayMs;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  if (_wcsicmp(tag.name, L"AutogatherFrom") != 0) {
    return;
  }
  Source source;
  for (const wchar_t* c = tag.text; c != nullptr && *c != 0; ++c) {
    if (!std::iswspace(*c)) {
      source.name.push_back(static_cast<char>(*c));
    }
  }
  const ActionKey key{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)};
  if (source.name.empty()) {
    uhc::Log(L"autoGatherFrom: proto %d: an empty <AutogatherFrom> is ignored", key.proto);
    return;
  }
  source.delayMs = DelayOf(tag.node);
  auto& list = g_tags[key];
  if (list.empty()) {
    g_byProto[key.proto].push_back(key);
  }
  list.push_back(source);
}

void NewDatabase(char*) {
  g_tags.clear();
  g_byProto.clear();
  g_wants.clear();
  g_units.clear();
  g_badNames.clear();
  g_logLines = 0;
}

std::int32_t TypeOf(Source& source) {
  if (source.type != -2) {
    return source.type;
  }
  source.type = -1;
  const char* database = Database();
  if (database == nullptr) {
    return -1;
  }
  const char* table = database + 0x190;
  std::int32_t id = -1;
  const std::int32_t bucket = kNameBucket(table, source.name.c_str());
  if (kNameFind(table, source.name.c_str(), bucket, &id)) {
    source.type = id;
  } else {
    if (g_badNames.insert(source.name).second) {
      uhc::Log(L"autoGatherFrom: <AutogatherFrom>%hs names no proto or unit type; ignored", source.name.c_str());
    }
  }
  return source.type;
}

// The longest range of an action: its range entries [action+18h] (16 bytes each, count [action+1Ch], +8 the maximum).
float RangeOf(const char* action) {
  const char* ranges = Field<const char*>(action, 0x18);
  const std::int32_t count = Field<std::int32_t>(action, 0x1C);
  float longest = 0.0f;
  for (std::int32_t i = 0; ranges != nullptr && i < count && i < 64; ++i) {
    longest = std::max(longest, Field<float>(ranges, 16u * i + 8));
  }
  return longest;
}

const std::vector<Want>& WantsOf(const char* proto) {
  const auto found = g_wants.find(proto);
  if (found != g_wants.end()) {
    return found->second;
  }
  std::vector<Want>& wants = g_wants[proto];
  const auto tagged = g_byProto.find(Field<std::int32_t>(proto, 0x04));
  const char* set = Field<const char*>(proto, 0x44);
  if (tagged == g_byProto.end() || set == nullptr) {
    return wants;
  }
  const char* const* actions = Field<const char* const*>(set, 0x1C);
  const std::int32_t count = Field<std::int32_t>(set, 0x20);
  for (const ActionKey& key : tagged->second) {
    for (std::int32_t i = 0; actions != nullptr && i < count; ++i) {
      const char* action = actions[i];
      if (action == nullptr || Field<std::int32_t>(action, 0x04) != key.name) {
        continue;
      }
      const float range = RangeOf(action);
      for (Source& source : g_tags[key]) {
        if (TypeOf(source) >= 0) {
          wants.push_back({&source, range});
        }
      }
      break;
    }
  }
  return wants;
}

// ---- the scan --------------------------------------------------------------------------------------------------

float Held(const char* unit) {
  const std::int32_t resource = kMainResource(unit);
  return resource < 0 ? 0.0f : kHeldAmount(unit, resource);
}

void SetAnchor(char* unit) {
  char* mgr = Field<char*>(unit, 0x58);
  for (std::uint32_t i = 0; i < 3; ++i) {
    *reinterpret_cast<float*>(mgr + 0x7C + 4 * i) = Field<float>(unit, 0x14 + 4 * i);
  }
}

// The nearest unit of a wanted type within its action's range, that the unit's player may gather from.
std::int32_t PickTarget(const char* world, const char* unit, std::int32_t player, const std::vector<Want>& wants,
                        const Unit& state, bool immobile, float* outDistance, std::int32_t* outDelay) {
  const auto inRange = Field<InRangeFn const*>(unit, 0)[0xCC / 4];
  const float* position = reinterpret_cast<const float*>(unit + 0x14);
  float radius = 0.0f;
  for (const Want& want : wants) {
    radius = std::max(radius, want.range);
  }
  g_found.count = 0;
  kUnitsNear(world, position, radius + kSearchSlack, 1, &g_found);
  const char* me = PlayerAt(world, player);
  const std::int32_t selfId = Field<std::int32_t>(unit, 0x10);
  std::int32_t best = -1;
  float bestDistance = 0.0f;
  for (std::int32_t i = 0; g_found.data != nullptr && i < g_found.count; ++i) {
    const std::int32_t id = g_found.data[i];
    const char* other = id == selfId ? nullptr : UnitById(world, id);
    const char* proto = other == nullptr ? nullptr : Field<const char*>(other, 0x5C);
    if (proto == nullptr || !Alive(other) || (state.refused && id == state.lastTarget) || !kIsSeeable(other, player)) {
      continue;
    }
    const std::int32_t owner = OwnerId(other);
    if (owner != 0 && owner != player && (me == nullptr || kIsEnemy(me, owner))) {
      continue;
    }
    const float distance = Field<DistanceFn const*>(other, 0)[0xB8 / 4](other, position);
    for (const Want& want : wants) {
      if ((immobile ? inRange(unit, other, want.range) : distance <= want.range) &&
          kProtoIsType(proto, want.source->type) &&
          (best < 0 || distance < bestDistance || (distance == bestDistance && id < best))) {
        best = id;
        bestDistance = distance;
        *outDelay = want.source->delayMs;
      }
    }
  }
  *outDistance = bestDistance;
  return best;
}

std::int32_t DelayFor(const std::vector<Want>& wants) {
  std::int32_t delay = wants.empty() ? kDefaultDelayMs : wants.front().source->delayMs;
  for (const Want& want : wants) {
    delay = std::min(delay, want.source->delayMs);
  }
  return delay;
}

void Scan(char* world, std::uint32_t now) {
  if (g_byProto.empty()) {
    return;
  }
  const std::int32_t players = Field<std::int32_t>(world, 0x5C);
  std::map<std::int32_t, Unit> seen;
  for (std::int32_t p = 1; p < players; ++p) {
    const char* player = PlayerAt(world, p);
    if (player == nullptr) {
      continue;
    }
    const std::int32_t* ids = Field<const std::int32_t*>(player, 0xF8);
    const std::int32_t count = Field<std::int32_t>(player, 0xFC);
    std::vector<std::int32_t> sorted(ids == nullptr ? 0 : count);
    for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
      sorted[i] = ids[i];
    }
    std::sort(sorted.begin(), sorted.end());
    for (const std::int32_t id : sorted) {
      char* unit = UnitById(world, id);
      const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
      if (proto == nullptr || OwnerId(unit) != p || Field<std::int32_t>(unit, 0x6C) != -1 ||
          Field<const char*>(unit, 0x58) == nullptr) {
        continue;
      }
      const std::vector<Want>& wants = WantsOf(proto);
      if (wants.empty() || !Alive(unit) || !kIsBuilt(unit)) {
        continue;
      }
      const char* record = Field<const char*>(unit, 0xB4);
      if (record == nullptr || Field<const char*>(record, 0x94) == nullptr) {
        continue;  // no inventory: the gather start refuses such a gatherer (0x50DE89, setState 9)
      }
      const bool immobile = Field<float>(proto, 0x80) <= 0.0f;
      if (immobile && !g_uhcBuildingGather) {
        continue;  // a building's Gather action never starts without buildingGather
      }
      auto old = g_units.find(id);
      Unit state = old == g_units.end() ? Unit{} : old->second;
      char* mgr = Field<char*>(unit, 0x58);
      const float held = Held(unit);
      if (state.refused && held != state.heldAtOrder) {
        state.refused = false;  // its amount changed: it may be sent there again
      }
      if (!kIdle(mgr)) {
        state.idleSince = 0;
        const char* action = Field<const char*>(mgr, 0x24);
        if (action != nullptr && Field<std::uint32_t>(action, 0) == kGatherVtable) {
          SetAnchor(unit);
        }
        seen[id] = state;
        continue;
      }
      if (state.idleSince == 0) {
        state.idleSince = now;
        if (!immobile && state.lastTarget >= 0 && state.heldAtOrder >= 0.0f && held <= state.heldAtOrder) {
          state.refused = true;  // the last order gained nothing (a building's gather goes to the stockpile: never)
          state.heldAtOrder = held;
        }
      }
      if (now - state.idleSince < static_cast<std::uint32_t>(DelayFor(wants))) {
        seen[id] = state;
        continue;
      }
      float distance = 0.0f;
      std::int32_t delay = kDefaultDelayMs;
      const std::int32_t target = PickTarget(world, unit, p, wants, state, immobile, &distance, &delay);
      if (target >= 0 && now - state.idleSince >= static_cast<std::uint32_t>(delay)) {
        const bool ok = kWorkOrder(mgr, target, 0, -1, 0);
        Note(L"autoGatherFrom: unit %d (player %d, proto %d) idle %.1f s -> unit %d, %.1f m: %ls", id, p,
             Field<std::int32_t>(proto, 0x04), (now - state.idleSince) / 1000.0, target, static_cast<double>(distance),
             ok ? L"ordered" : L"refused");
        if (target != state.lastTarget) {
          state.refused = false;
        }
        state.lastTarget = target;
        state.heldAtOrder = held;
        state.idleSince = ok ? 0 : now;  // refused: try again after the delay
      }
      seen[id] = state;
    }
  }
  g_units.swap(seen);  // units gone or no longer tagged are forgotten
}

void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_lastWorld || now < g_lastTime) {
    g_units.clear();
    g_lastScan = 0;
    g_lastWorld = world;
  }
  g_lastTime = now;
  if (g_lastScan != 0 && now - g_lastScan < kScanMs) {
    return;
  }
  g_lastScan = now == 0 ? 1 : now;
  if (!g_log) {
    Scan(world, now);
    return;
  }
  // With log: the cost of the scans, every 240 of them (a real clock, for the log only: it feeds nothing back).
  static int scans = 0;
  static double total = 0.0, longest = 0.0;
  const auto start = std::chrono::steady_clock::now();
  Scan(world, now);
  const double us = std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - start).count();
  total += us;
  longest = std::max(longest, us);
  if (++scans == 240) {
    uhc::Log(L"autoGatherFrom: 240 scans, %.0f us on average, %.0f us the longest, %zu tagged unit(s)", total / scans,
             longest, g_units.size());
    scans = 0;
    total = longest = 0.0;
  }
}

}  // namespace

namespace uhc {

Outcome ApplyAutoGatherFrom(const Config& config) {
  const Config::Args* args = config.First("autoGatherFrom");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    Log(L"autoGatherFrom: bad argument %hs (expected [log]); feature not applied", arg.c_str());
    return Outcome::kFailed;
  }
  if (!VerifyAll("autoGatherFrom", {&sites::kGatherWorkOrder, &sites::kAutoScoutIdle, &sites::kUnitsNearPoint,
                                    &sites::kUnitById, &sites::kIsA, &sites::kIsBuilt, &sites::kPlayerIsEnemy,
                                    &sites::kHeldAmount, &sites::kMainResource, &sites::kUnitAliveSlot,
                                    &sites::kXmlAttribute, &sites::kXmlText, &sites::kUnitIsSeeable}) ||
      !AddActionTagHandler(&ActionTagRead) || !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  Log(L"autoGatherFrom: units with an <AutogatherFrom> action tag gather on their own once idle (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
