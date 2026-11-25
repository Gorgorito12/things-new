// garrisonConvert [log]: the units that enter a building become another unit. In a proto's <Unit>:
//
//   <GarrisonConvertTo>Musketeer</GarrisonConvertTo>              each unit becomes a Musketeer as it enters
//   <GarrisonConvertTo delay="10">Musketeer</GarrisonConvertTo>   one at a time, each after 10 seconds inside
//
// Only the units of the building's owner are converted, and never a unit that already is the target. The unit is
// changed in place by the shared transform (transformcalls.h, so the transform observers such as veterancyBonus see
// it): it keeps its ID, its owner and its share of hit points, stays inside, and counts its new population. A
// building has one tag (with several, the last counts). The tag is read once per data load, by proto ID.
//
// The entries come from the shared garrison observer (garrisonobservers.h), which only marks the building active; the
// conversions happen after the world update (worldtick.h). The queue is the building's own list of contained units
// [unit+70h] (count [+74h]), which is in entry order: the first unit of it that qualifies is the one in progress, so
// a unit that leaves simply drops out of it. With a delay, the game time the unit in progress has spent is the only
// state; it is a saved marker on the building (savedmarkers.h, stat 6Ch: the time and the unit's ID), so a save
// keeps the progress. The timer waits while nobody qualifies. A game that starts or loads finds its active buildings
// with one walk of the world's unit table.
//
// GarrisonConvertProgress (features.h) gives the panels the progress of a building.
#include <windows.h>

#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <vector>

#include "../features.h"
#include "../garrisonobservers.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../savedmarkers.h"
#include "../transformcalls.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::int32_t kStat = 0x6C;               // savedmarkers.h: no other key uses it
constexpr std::uint32_t kWord = 0x564E4347;        // word 0 of a building's marker: 'GCNV'
constexpr float kMaxDelay = 3600.0f;
constexpr int kMaxLogLines = 400;

using IsAliveFn = bool(__thiscall*)(const char* unit);
using ProtoByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kProtoByName = reinterpret_cast<ProtoByNameFn>(0x005A2346);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Tag {
  std::string target;     // as read
  std::uint32_t delayMs;  // 0: at once
  const char* table;      // the proto array the target was resolved against
  std::int32_t targetId;  // -1: not a proto of that database
};
std::map<std::int32_t, Tag> g_tags;  // by the building's proto ID; the data load fills it

struct State {
  std::uint32_t elapsed = 0;  // ms of game time the unit in progress has spent
  std::int32_t head = -1;     // the unit in progress; -1: the next one that qualifies takes `elapsed` over
};
std::map<std::int32_t, State> g_active;  // by building ID, in ID order: the same walk on every machine

const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
std::uint32_t g_converted = 0;

bool g_log = false;
int g_logLines = 0;

bool LogOk() {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return false;
  }
  ++g_logLines;
  return true;
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* MainWorld() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

const char* Database() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

char* UnitById(const char* world, std::int32_t id) {
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<IsAliveFn const* const*>(unit))[0xA4 / 4](unit); }

std::int32_t ProtoId(const char* proto) { return proto == nullptr ? -1 : Field<std::int32_t>(proto, 8); }

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* PlayerOf(const char* unit) { return Field<const char*>(unit, 0x44); }

// The tag of the unit's proto, with its target resolved against the current database; null when it has none.
Tag* TagOf(const char* unit) {
  if (g_tags.empty() || unit == nullptr) {
    return nullptr;
  }
  const auto found = g_tags.find(ProtoId(Field<const char*>(unit, 0x5C)));
  if (found == g_tags.end()) {
    return nullptr;
  }
  Tag& tag = found->second;
  const char* database = Database();
  const char* table = database == nullptr ? nullptr : Field<const char*>(database, 0x54);
  if (table != nullptr && tag.table != table) {
    tag.table = table;
    tag.targetId = kProtoByName(database, tag.target.c_str());
    if (tag.targetId < 0) {
      uhc::Log(L"garrisonConvert: proto %d: <GarrisonConvertTo> %hs is not a proto; it converts nothing", found->first,
               tag.target.c_str());
    }
  }
  return tag.targetId >= 0 ? &tag : nullptr;
}

// --- The tag ----------------------------------------------------------------------------------------------------

std::string Narrow(const wchar_t* text) {
  std::string out;
  for (; text != nullptr && *text != L'\0'; ++text) {
    out += *text < 0x80 ? static_cast<char>(*text) : '?';
  }
  const auto first = out.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) {
    return {};
  }
  return out.substr(first, out.find_last_not_of(" \t\r\n") - first + 1);
}

std::string Attribute(const char* node, const char* name) {
  const void* value = nullptr;
  if (node == nullptr || !kXmlAttribute(node, name, &value) || value == nullptr) {
    return {};
  }
  const char* text = kXmlText(value);
  return text == nullptr ? std::string() : std::string(text);
}

bool __cdecl ReadConvertTo(void*, const char* node, char* proto) {
  const std::int32_t id = ProtoId(proto);
  const std::string target = Narrow(*reinterpret_cast<const wchar_t* const*>(node + 0x14));
  if (target.empty()) {
    uhc::Log(L"garrisonConvert: proto %d (%hs): <GarrisonConvertTo> is empty; ignored", id, ProtoName(proto));
    return true;
  }
  std::uint32_t delayMs = 0;
  const std::string delay = Attribute(node, "delay");
  if (!delay.empty()) {
    char* end = nullptr;
    const double seconds = std::strtod(delay.c_str(), &end);
    if (end == delay.c_str() || *end != '\0' || !(seconds >= 0.0) || !(seconds <= kMaxDelay)) {
      uhc::Log(L"garrisonConvert: proto %d (%hs): delay=\"%hs\" is not a number of seconds from 0 to %g; 0 is used",
               id, ProtoName(proto), delay.c_str(), static_cast<double>(kMaxDelay));
    } else {
      delayMs = static_cast<std::uint32_t>(seconds * 1000.0 + 0.5);
    }
  }
  if (g_tags.count(id) != 0) {
    uhc::Log(L"garrisonConvert: proto %d (%hs) has more than one <GarrisonConvertTo>; the last one counts", id,
             ProtoName(proto));
  }
  g_tags[id] = Tag{target, delayMs, nullptr, -1};
  if (g_log) {
    uhc::Log(L"garrisonConvert: proto %d (%hs): the units that enter become %hs, %ls %u ms", id, ProtoName(proto),
             target.c_str(), delayMs == 0 ? L"at once," : L"one at a time, each after", delayMs);
  }
  return true;
}

void ForgetOnDataLoad(char*) {
  g_tags.clear();
  g_active.clear();
  g_world = nullptr;
}

// --- The buildings ----------------------------------------------------------------------------------------------

char* MarkerOf(const char* unit) { return uhc::markers::Find(unit, kStat, kWord); }

// Words 1 to 3: the time spent, the unit in progress, the game time of the write (so a loaded game adds the time of
// the update the save was made in, which the first tick after the load does not see).
void WriteMarker(char* building, const State& state, std::uint32_t now) {
  char* marker = MarkerOf(building);
  if (marker == nullptr) {
    marker = uhc::markers::Take(building, kStat);
    if (marker == nullptr) {
      return;
    }
    uhc::markers::Word(marker, 0) = kWord;
  }
  uhc::markers::Word(marker, 1) = state.elapsed;
  uhc::markers::Word(marker, 2) = static_cast<std::uint32_t>(state.head);
  uhc::markers::Word(marker, 3) = now;
}

void ClearMarker(char* building) {
  if (char* marker = MarkerOf(building)) {
    uhc::markers::Free(marker);
  }
}

// The contained units that qualify, in entry order.
std::vector<char*> Queue(const char* world, const char* building, const Tag& tag) {
  std::vector<char*> queue;
  const std::int32_t count = Field<std::int32_t>(building, 0x74);
  const std::int32_t* ids = Field<const std::int32_t*>(building, 0x70);
  const std::int32_t buildingId = Field<std::int32_t>(building, 0x10);
  const char* owner = PlayerOf(building);
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    char* unit = UnitById(world, ids[i]);
    if (unit != nullptr && Field<std::int32_t>(unit, 0x6C) == buildingId && PlayerOf(unit) == owner &&
        ProtoId(Field<const char*>(unit, 0x5C)) != tag.targetId && IsAlive(unit)) {
      queue.push_back(unit);
    }
  }
  return queue;
}

void Convert(char* unit, const char* building, const Tag& tag, std::uint32_t now) {
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const char* before = Field<const char*>(unit, 0x5C);
  const std::int32_t fromId = ProtoId(before);
  const char* fromName = ProtoName(before);
  uhc::TransformUnit(unit, tag.targetId);
  ++g_converted;
  if (LogOk()) {
    uhc::Log(L"garrisonConvert: unit %d (%hs) in %hs %d became %hs (proto %d -> %d, game time %u ms)", id, fromName,
             ProtoName(Field<const char*>(building, 0x5C)), Field<std::int32_t>(building, 0x10),
             ProtoName(Field<const char*>(unit, 0x5C)), fromId, tag.targetId, now);
  }
}

void Consider(char* unit, std::uint32_t now) {
  if (unit == nullptr || Field<std::int32_t>(unit, 0x74) <= 0 || TagOf(unit) == nullptr || !IsAlive(unit)) {
    return;
  }
  State state;
  if (char* marker = MarkerOf(unit)) {
    const std::uint32_t written = uhc::markers::Word(marker, 3);
    state.elapsed = uhc::markers::Word(marker, 1) + (now > written && now - written < 60000 ? now - written : 0);
    state.head = static_cast<std::int32_t>(uhc::markers::Word(marker, 2));
  }
  g_active.emplace(Field<std::int32_t>(unit, 0x10), state);
}

// A game that just started or loaded: its buildings with units inside. One walk.
void Rebuild(const char* world) {
  g_active.clear();
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
    Consider(table[i], Field<std::uint32_t>(world, 0x108));
  }
  if (!g_active.empty()) {
    uhc::Log(L"garrisonConvert: %u building(s) with units inside in this game (game time %u ms)",
             static_cast<unsigned>(g_active.size()), Field<std::uint32_t>(world, 0x108));
  }
}

// The game time since the last tick; a new game rebuilds the list and gives 0.
std::uint32_t Sync(const char* world) {
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const bool sameGame = world == g_world && now >= g_lastTime && step - g_lastStep <= 1;
  const std::uint32_t elapsed = sameGame ? now - g_lastTime : 0;
  if (!sameGame) {
    g_world = world;
    Rebuild(world);
  }
  g_lastTime = now;
  g_lastStep = step;
  return elapsed;
}

// From the shared garrison observer, inside the load: only marks the building.
void OnEnter(char* container, char*) {
  if (g_tags.empty() || TagOf(container) == nullptr) {
    return;
  }
  g_active.emplace(Field<std::int32_t>(container, 0x10), State{});
}

void Tick(char* world, std::int32_t) {
  if (world != MainWorld() || g_tags.empty()) {
    return;
  }
  const std::uint32_t elapsed = Sync(world);
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  for (auto it = g_active.begin(); it != g_active.end();) {
    char* building = UnitById(world, it->first);
    const Tag* tag = building != nullptr ? TagOf(building) : nullptr;
    if (tag == nullptr || !IsAlive(building)) {
      it = g_active.erase(it);
      continue;
    }
    std::vector<char*> queue = Queue(world, building, *tag);
    State& state = it->second;
    if (queue.empty()) {
      ClearMarker(building);
      it = g_active.erase(it);
      continue;
    }
    if (tag->delayMs == 0) {
      for (char* unit : queue) {
        Convert(unit, building, *tag, now);
      }
      it = g_active.erase(it);
      continue;
    }
    std::size_t next = 0;
    const std::int32_t headId = Field<std::int32_t>(queue[0], 0x10);
    if (state.head != headId) {
      if (state.head >= 0) {
        state.elapsed = 0;  // the unit in progress left: the next one starts again
      }
      state.head = headId;
    }
    state.elapsed += elapsed;
    while (next < queue.size() && state.elapsed >= tag->delayMs) {
      Convert(queue[next++], building, *tag, now);
      state.elapsed -= tag->delayMs;
      state.head = -1;
    }
    if (next == queue.size()) {
      state.elapsed = 0;
    } else if (state.head < 0) {
      state.head = Field<std::int32_t>(queue[next], 0x10);
    }
    WriteMarker(building, state, now);
    ++it;
  }
}

}  // namespace

namespace uhc {

bool GarrisonConvertProgress(const char* building, float* fraction, std::int32_t* waiting) {
  if (building == nullptr || g_tags.empty() || MainWorld() != g_world) {
    return false;
  }
  const Tag* tag = TagOf(building);
  if (tag == nullptr) {
    return false;
  }
  const std::vector<char*> queue = Queue(g_world, building, *tag);
  if (queue.empty()) {
    return false;
  }
  const auto found = g_active.find(Field<std::int32_t>(building, 0x10));
  const std::uint32_t spent = found != g_active.end() ? found->second.elapsed : 0;
  if (fraction != nullptr) {
    *fraction = tag->delayMs == 0 ? 1.0f
                                  : static_cast<float>(spent < tag->delayMs ? spent : tag->delayMs) /
                                        static_cast<float>(tag->delayMs);
  }
  if (waiting != nullptr) {
    *waiting = static_cast<std::int32_t>(queue.size());
  }
  return true;
}

Outcome ApplyGarrisonConvert(const Config& config) {
  const Config::Args* args = config.First("garrisonConvert");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"garrisonConvert: unknown option %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("garrisonConvert", {&sites::kUnitAliveSlot, &sites::kProtoByName, &sites::kXmlAttribute}) ||
      !AddProtoTagHandler("GarrisonConvertTo", &ReadConvertTo) || !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !AddWorldTick(&Tick) || !AddGarrisonObserver(&OnEnter, "garrisonConvert")) {
    return Outcome::kFailed;
  }
  Log(L"garrisonConvert: <GarrisonConvertTo> converts the units that enter a building%ls",
      g_log ? L"; logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
