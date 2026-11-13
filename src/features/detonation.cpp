// detonationDeath: <DetonationProtoAction>Name</DetonationProtoAction> in a proto fires that action around
// the unit when it dies.
//
// Every death goes through one queue: TakeDamage, a lifespan, a delete and the rest ask 0x4B4DC2, and the
// queue's drain 0x493D46 calls the kill handler 0x4B4F70 for each, from a single call, 0x493D8F. The key
// observes that call through the shared wrapper (deathobservers.h). Before the stock handler runs, the unit still exists, so the stock area damage
// 0x4C9D89 gets it as the attacker, in the same call the game makes for a unit that hits around
// itself (0x6A4A6B). Units that die from the blast join the queue, and the drain reads its count again,
// so a chain runs one by one and does not recurse.
//
// The action is the player's copy, so a tech that changes its damage counts. The names are read once and
// are the same for every player.
//
// The three other tags (the names of another edition of the game):
// - <DetonationCommand>Name</DetonationCommand>: the unit detonates when it is deleted. The modder gives
//   the proto a command of that name wired to the console command uiDeleteSelectedUnit (the stock Delete
//   does the same), so the button and the Delete key both send the synced delete command (type 7),
//   whose executor FUN_007CCF7F sets the unit's HP to 0 through 0x4820A1 (flag 1) for most protos, or
//   asks the kill queue with flags 1 0 0 for a proto with flag 0Dh. The two calls are wrapped: the first
//   fires the blast before the setter, the second marks the unit as deleted so the kill handler's wrapper
//   knows the kill is a delete. Without the tag a delete gives no blast.
// - <DetonationHitpointThreshold>Ratio</DetonationHitpointThreshold>: when a loss of HP leaves the unit
//   at or under that share of its max HP, it detonates by itself: the shared add-HP hook of
//   overhealSources (0x4823A3, which TakeDamage's subtraction 0x49B822 reaches) reports every loss, and
//   the unit's kill is asked from the queue with the combat flags, so the drain fires the blast.
// - <DetonationHitpointDecay>HP per second</DetonationHitpointDecay>: with a threshold, the unit does
//   not die at once but loses that many HP per second of game time from the threshold on, through the
//   HP setter, and detonates when it reaches 0 (or when anything else kills it). Healed back over the
//   threshold, it stops decaying until the next loss. The decaying units are kept by unit ID (the same
//   order on every machine) and forgotten on a new game and a data load; a saved game does not keep them.
//
// The blast on screen: the stock terrain impact FUN_004CB11C, the visual of a shot that lands on the ground
// (a mortar shell, a missed cannon ball), plays the impact effect of a projectile's action ([proj+10h],
// whose [+70h] is the <impacteffect> ID) at a point, with the impact type of the terrain there. The key
// calls it with a record that has only the three fields it reads: the action, [+28h] = 0 (the entry's
// particleSet, not its secondaryParticleSet) and the origin [+64h] = the point (no direction: the stock
// default). By default the action's own <impacteffect>; <DetonationImpactEffect>path</DetonationImpactEffect>
// names another, loaded at the data load as the tactics parser does (FUN_0058F017), and none plays nothing.
// The stock function draws only what the local player sees, and only drawing and sound follow from it.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <unordered_map>

#include "../deathobservers.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace uhc {
extern void (*g_hpLoss)(const char* unit, float amount);  // overhealsources.cpp
bool InstallOverhealAddHook();
bool OverhealAddHookInstalled();
}  // namespace uhc

namespace {

constexpr std::size_t kUnitState = 4;       // bit array; +8h its size in bits
constexpr std::size_t kUnitId = 0x10;
constexpr std::size_t kUnitPosition = 0x14;
constexpr std::size_t kUnitProto = 0x5C;
constexpr std::size_t kProtoId = 8;
constexpr std::size_t kProtoActions = 0x44;  // the action set
constexpr std::size_t kActionList = 0x1C;    // in the set: the array of actions, its count at +20h
constexpr std::size_t kActionId = 4;
constexpr std::size_t kActionFlags = 0x64;   // bit array; +68h its size in bits
constexpr std::size_t kActionNames = 0x1FD8; // in the database: the names by action ID, the count at +1FDCh
constexpr std::uint32_t kDeadBit = 11;       // the kill handler returns at once when it is set
constexpr std::uint32_t kAreaFlagBit = 6;    // what the stock caller reads and passes on
constexpr std::uint32_t kZeroVector = 0x00CF0618;
constexpr int kMaxLogLines = 200;

using AreaFn = void(__thiscall*)(const char* world, std::int32_t unit, char* action, const void* point, float multiplier,
                                 std::int32_t a, std::int32_t b, std::int32_t c, std::int32_t* hit, std::uint32_t flag,
                                 const void* offset);
const auto kArea = reinterpret_cast<AreaFn>(0x004C9D89);
using KillAskFn = void(__thiscall*)(char* unit, std::int32_t a, std::int32_t b, std::int32_t c);
const auto kKillAsk = reinterpret_cast<KillAskFn>(0x004B4DC2);
using SetHpFn = void(__thiscall*)(char* unit, float value, std::int32_t flag);
const auto kSetHp = reinterpret_cast<SetHpFn>(0x004820A1);
using MaxHpFn = float(__thiscall*)(const char* unit);
const auto kMaxHp = reinterpret_cast<MaxHpFn>(0x00480408);
using IsAliveFn = bool(__thiscall*)(const char* unit);
using TerrainImpactFn = void(__thiscall*)(const void* projectile, const float* point);
const auto kTerrainImpact = reinterpret_cast<TerrainImpactFn>(0x004CB11C);
using EffectByNameFn = std::int32_t(__thiscall*)(void* manager, const void* name);
const auto kEffectByName = reinterpret_cast<EffectByNameFn>(0x0058F017);
constexpr std::size_t kActionImpactEffect = 0x70;  // the <impacteffect> ID, -1 for none
constexpr std::size_t kGameEffects = 0xBB8;        // the impact effect manager
constexpr std::uint32_t kDeleteSetHpCall = 0x007CD0CF;
constexpr std::uint32_t kDeleteKillCall = 0x007CD0DC;
constexpr std::size_t kUnitContainer = 0x6C;  // -1 when the unit is not inside another

struct Detonation {
  std::wstring name;
  std::int32_t action = -2;  // -2: not looked up yet, -1: the proto has no action of that name
  std::wstring command;      // <DetonationCommand>: the proto command that detonates (a delete)
  float threshold = -1.0f;   // <DetonationHitpointThreshold>: the HP ratio that detonates by itself
  float decay = -1.0f;       // <DetonationHitpointDecay>: HP lost per second under the threshold
  std::int32_t effect = -2;  // <DetonationImpactEffect>: -2 the action's own, -1 none, else the effect's ID
};

std::unordered_map<std::int32_t, Detonation> g_protos;  // by proto ID; the map's shape is fixed after the load
bool g_log = false;
int g_logLines = 0;

struct Decay {
  float perSecond;
  std::uint32_t lastMs;  // game time of the last step applied
};
std::set<std::int32_t> g_deleting;    // unit IDs the delete executor sent to the kill queue
std::set<std::int32_t> g_asked;       // unit IDs whose kill the threshold asked, until the handler runs
std::map<std::int32_t, Decay> g_decay;  // by unit ID
const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;

bool IsAlive(const char* unit) { return (*reinterpret_cast<IsAliveFn const* const*>(unit))[0xA4 / 4](unit); }

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  return game == nullptr ? nullptr : *reinterpret_cast<const char* const*>(game + 0x13C);
}

char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= *reinterpret_cast<const std::int32_t*>(world + 0x10)) {
    return nullptr;
  }
  char* unit = (*reinterpret_cast<char* const* const*>(world + 0x0C))[id & 0x3FFFF];
  return unit != nullptr && *reinterpret_cast<const std::int32_t*>(unit + 0x10) == id ? unit : nullptr;
}

void Forget(char*) {
  g_deleting.clear();
  g_asked.clear();
  g_decay.clear();
}

bool Bit(const char* owner, std::size_t array, std::uint32_t bit) {
  const auto* bits = *reinterpret_cast<const std::uint8_t* const*>(owner + array);
  const std::uint32_t size = *reinterpret_cast<const std::uint32_t*>(owner + array + 4);
  return bits != nullptr && bit < size && (bits[bit / 8] & (1u << (bit % 8))) != 0;
}

const char* Game() { return *reinterpret_cast<const char* const*>(0x00C66234); }

// The action of the player's copy with that name, by its ID in the database's list of names.
char* FindAction(const char* proto, Detonation& detonation) {
  const char* game = Game();
  const char* db = *reinterpret_cast<const char* const*>(game + 0x140);
  const char* set = *reinterpret_cast<const char* const*>(proto + kProtoActions);
  if (set == nullptr) {
    return nullptr;
  }
  const auto* names = *reinterpret_cast<const wchar_t* const* const*>(db + kActionNames);
  const std::int32_t nameCount = *reinterpret_cast<const std::int32_t*>(db + kActionNames + 4);
  char* const* actions = *reinterpret_cast<char* const* const*>(set + kActionList);
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(set + kActionList + 4);
  for (std::int32_t i = 0; i < count; ++i) {
    const std::int32_t id = *reinterpret_cast<const std::int32_t*>(actions[i] + kActionId);
    if (detonation.action >= 0) {
      if (id == detonation.action) {
        return actions[i];
      }
      continue;
    }
    if (id >= 0 && id < nameCount && names[id] != nullptr && _wcsicmp(names[id], detonation.name.c_str()) == 0) {
      detonation.action = id;
      return actions[i];
    }
  }
  if (detonation.action == -2) {
    detonation.action = -1;
    uhc::Log(L"detonationDeath: proto %d has no action %ls", *reinterpret_cast<const std::int32_t*>(proto + kProtoId),
             detonation.name.c_str());
  }
  return nullptr;
}

bool __cdecl ReadDetonation(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  if (text == nullptr || text[0] == L'\0') {
    uhc::Log(L"detonationDeath: proto %d: <DetonationProtoAction> names no action, ignored", id);
    return true;
  }
  g_protos[id].name = text;
  if (g_log) {
    uhc::Log(L"detonationDeath: proto %d fires %ls", id, text);
  }
  return true;
}

const wchar_t* NodeText(const char* node) { return *reinterpret_cast<const wchar_t* const*>(node + 0x14); }

bool __cdecl ReadCommand(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  if (text == nullptr || text[0] == L'\0') {
    uhc::Log(L"detonationDeath: proto %d: <DetonationCommand> names no command, ignored", id);
    return true;
  }
  g_protos[id].command = text;
  if (g_log) {
    uhc::Log(L"detonationDeath: proto %d detonates on its command %ls (a delete)", id, text);
  }
  return true;
}

bool ReadRatio(const char* node, char* proto, const wchar_t* tag, float* out, float low, float high) {
  const wchar_t* text = NodeText(node);
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  wchar_t* end = nullptr;
  const double value = text == nullptr ? -1.0 : std::wcstod(text, &end);
  if (text == nullptr || end == text || !(value >= low) || !(value <= high)) {
    uhc::Log(L"detonationDeath: proto %d: <%ls> needs a number from %g to %g, ignored", id, tag, static_cast<double>(low),
             static_cast<double>(high));
    return true;
  }
  *out = static_cast<float>(value);
  return true;
}

bool __cdecl ReadImpactEffect(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  if (text == nullptr || text[0] == L'\0') {
    uhc::Log(L"detonationDeath: proto %d: <DetonationImpactEffect> names no effect, ignored", id);
    return true;
  }
  if (_wcsicmp(text, L"none") == 0) {
    g_protos[id].effect = -1;
    if (g_log) {
      uhc::Log(L"detonationDeath: proto %d: its blast plays no impact effect", id);
    }
    return true;
  }
  char* game = *reinterpret_cast<char* const*>(0x00C66234);
  void* manager = game == nullptr ? nullptr : *reinterpret_cast<void* const*>(game + kGameEffects);
  const std::int32_t effect = manager == nullptr ? -1 : kEffectByName(manager, node + 0x14);
  if (effect < 0) {
    uhc::Log(L"detonationDeath: proto %d: <DetonationImpactEffect> %ls is not an impact effect, ignored", id, text);
    return true;
  }
  g_protos[id].effect = effect;
  if (g_log) {
    uhc::Log(L"detonationDeath: proto %d: its blast plays the impact effect %ls (%d)", id, text, effect);
  }
  return true;
}

bool __cdecl ReadThreshold(void*, const char* node, char* proto) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  float value = -1.0f;
  ReadRatio(node, proto, L"DetonationHitpointThreshold", &value, 0.0f, 1.0f);
  if (value >= 0.0f) {
    g_protos[id].threshold = value;
    if (g_log) {
      uhc::Log(L"detonationDeath: proto %d detonates at %.0f %% of its hit points", id, static_cast<double>(value * 100.0f));
    }
  }
  return true;
}

bool __cdecl ReadDecay(void*, const char* node, char* proto) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  float value = -1.0f;
  ReadRatio(node, proto, L"DetonationHitpointDecay", &value, 0.0f, 1.0e6f);
  if (value >= 0.0f) {
    g_protos[id].decay = value;
    if (g_log) {
      uhc::Log(L"detonationDeath: proto %d loses %.2f hit points a second under its threshold", id,
               static_cast<double>(value));
    }
  }
  return true;
}

// The blast on screen, as a shot landing on the ground there (FUN_004CB11C).
void ShowBlast(const char* action, std::int32_t effect, const float* point) {
  if (effect == -1) {
    return;
  }
  alignas(4) char custom[kActionImpactEffect + 4] = {};
  if (effect >= 0) {
    *reinterpret_cast<std::int32_t*>(custom + kActionImpactEffect) = effect;
    action = custom;
  } else if (*reinterpret_cast<const std::int32_t*>(action + kActionImpactEffect) < 0) {
    return;  // the action has no <impacteffect>
  }
  alignas(4) char projectile[0x70] = {};
  *reinterpret_cast<const char**>(projectile + 0x10) = action;
  std::memcpy(projectile + 0x64, point, 3 * sizeof(float));
  kTerrainImpact(projectile, point);
}

void Detonate(char* unit, std::uint32_t a, std::uint32_t b, std::uint32_t c, bool deleted) {
  const char* proto = *reinterpret_cast<const char* const*>(unit + kUnitProto);
  if (proto == nullptr) {
    return;
  }
  const std::int32_t protoId = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  const auto found = g_protos.find(protoId);
  if (found == g_protos.end() || found->second.action == -1 || Bit(unit, kUnitState, kDeadBit)) {
    return;
  }
  if (deleted && found->second.command.empty()) {
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"detonationDeath: unit %d, proto %d: deleted without a DetonationCommand, no blast",
               *reinterpret_cast<std::int32_t*>(unit + kUnitId), protoId);
    }
    return;
  }
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : *reinterpret_cast<const char* const*>(game + 0x13C);
  if (world == nullptr) {
    return;
  }
  char* action = FindAction(proto, found->second);
  if (action == nullptr) {
    return;
  }
  const auto* position = reinterpret_cast<const float*>(unit + kUnitPosition);
  const float point[3] = {position[0], position[1], position[2]};  // the unit may move or go in the blast
  std::int32_t hit = 0;
  kArea(world, *reinterpret_cast<const std::int32_t*>(unit + kUnitId), action, point, 1.0f, 0, 0, -1, &hit,
        Bit(action, kActionFlags, kAreaFlagBit) ? 1 : 0, reinterpret_cast<const void*>(kZeroVector));
  ShowBlast(action, found->second.effect, point);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"detonationDeath: unit %d, proto %d, at %.1f, %.1f, kill flags %u %u %u%ls", *reinterpret_cast<std::int32_t*>(unit + kUnitId),
             protoId, static_cast<double>(position[0]), static_cast<double>(position[2]), a & 0xFF, b & 0xFF, c & 0xFF,
             deleted ? L" (a delete)" : L"");
  }
}

// Before the drain's call of the kill handler (the shared death observer).
void Kill(char* unit, std::uint32_t a, std::uint32_t b, std::uint32_t c) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(unit + kUnitId);
  const bool deleted = g_deleting.erase(id) > 0;
  g_asked.erase(id);
  g_decay.erase(id);
  Detonate(unit, a, b, c, deleted);
}

// Replaces the delete executor's call of the HP setter (a proto without flag 0Dh): the blast first,
// while the unit is whole.
void __fastcall DeleteSetHp(char* unit, void*, float value, std::int32_t flag) {
  Detonate(unit, 1, 0, 0, true);
  kSetHp(unit, value, flag);
}

// Replaces the delete executor's ask of the kill queue (a proto with flag 0Dh): the handler's wrapper
// then knows the kill is a delete.
void __fastcall DeleteKill(char* unit, void*, std::int32_t a, std::int32_t b, std::int32_t c) {
  g_deleting.insert(*reinterpret_cast<const std::int32_t*>(unit + kUnitId));
  kKillAsk(unit, a, b, c);
}

// The threshold: from the shared add-HP hook, for every loss, before it is applied.
void HpLoss(const char* unit, float amount) {
  const char* proto = *reinterpret_cast<const char* const*>(unit + kUnitProto);
  if (proto == nullptr || g_protos.empty()) {
    return;
  }
  const auto found = g_protos.find(*reinterpret_cast<const std::int32_t*>(proto + kProtoId));
  if (found == g_protos.end() || found->second.threshold < 0.0f || found->second.action == -1) {
    return;
  }
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(unit + kUnitId);
  if (Bit(unit, kUnitState, kDeadBit) || !IsAlive(unit) ||
      *reinterpret_cast<const std::int32_t*>(unit + kUnitContainer) >= 0 || g_asked.count(id) != 0) {
    return;
  }
  const float after = *reinterpret_cast<const float*>(unit + 0x64) + amount;
  const float max = kMaxHp(unit);
  if (after < 1e-6f || !(max > 0.0f) || after / max > found->second.threshold) {
    return;  // the killing blow's own path, or still above the threshold
  }
  if (found->second.decay > 0.0f) {
    const char* world = World();
    if (world == nullptr || g_decay.count(id) != 0) {
      return;
    }
    g_decay[id] = Decay{found->second.decay, *reinterpret_cast<const std::uint32_t*>(world + 0x108)};
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"detonationDeath: unit %d, proto %d: HP %.1f of %.1f (%.0f %%) under the threshold %.0f %%: loses %.2f HP a "
               L"second from here",
               id, found->first, static_cast<double>(after), static_cast<double>(max),
               static_cast<double>(after / max * 100.0f), static_cast<double>(found->second.threshold * 100.0f),
               static_cast<double>(found->second.decay));
    }
    return;
  }
  g_asked.insert(id);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"detonationDeath: unit %d, proto %d: HP %.1f of %.1f (%.0f %%) under the threshold %.0f %%: kill queued", id,
             found->first, static_cast<double>(after), static_cast<double>(max),
             static_cast<double>(after / max * 100.0f), static_cast<double>(found->second.threshold * 100.0f));
  }
  kKillAsk(const_cast<char*>(unit), 0, 0, 0);
}

// The decay: after each world update of the game world, by game time; a new game forgets every unit.
void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  const std::uint32_t now = *reinterpret_cast<const std::uint32_t*>(world + 0x108);
  const std::uint32_t step = *reinterpret_cast<const std::uint32_t*>(world + 0xF8);
  const bool sameGame = world == g_world && now >= g_lastTime && step - g_lastStep <= 1;
  if (!sameGame) {
    Forget(nullptr);
    g_world = world;
  }
  g_lastTime = now;
  g_lastStep = step;
  for (auto it = g_decay.begin(); it != g_decay.end();) {
    char* unit = UnitById(world, it->first);
    if (unit == nullptr || !IsAlive(unit) || Bit(unit, kUnitState, kDeadBit)) {
      it = g_decay.erase(it);
      continue;
    }
    const char* proto = *reinterpret_cast<const char* const*>(unit + kUnitProto);
    const auto found = proto == nullptr ? g_protos.end() : g_protos.find(*reinterpret_cast<const std::int32_t*>(proto + kProtoId));
    const float hp = *reinterpret_cast<const float*>(unit + 0x64);
    const float max = kMaxHp(unit);
    if (found == g_protos.end() || found->second.threshold < 0.0f || !(max > 0.0f) || hp / max > found->second.threshold) {
      if (g_log && g_logLines < kMaxLogLines && found != g_protos.end()) {
        ++g_logLines;
        uhc::Log(L"detonationDeath: unit %d is back over its threshold (HP %.1f): the decay stops", it->first,
                 static_cast<double>(hp));
      }
      it = g_decay.erase(it);
      continue;
    }
    const std::uint32_t elapsed = now - it->second.lastMs;
    it->second.lastMs = now;
    if (elapsed == 0) {
      ++it;
      continue;
    }
    const float value = hp - it->second.perSecond * static_cast<float>(elapsed) * 0.001f;
    if (value < 1e-6f) {
      if (g_log && g_logLines < kMaxLogLines) {
        ++g_logLines;
        uhc::Log(L"detonationDeath: unit %d decayed to 0: kill queued", it->first);
      }
      g_asked.insert(it->first);
      it = g_decay.erase(it);
      kKillAsk(unit, 0, 0, 0);
      continue;
    }
    kSetHp(unit, value, 0);
    ++it;
  }
}

}  // namespace

namespace uhc {

Outcome ApplyDetonationDeath(const Config& config) {
  const Config::Args* args = config.First("detonationDeath");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"detonationDeath: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  // overhealSources or overhealDecay may already have written the add-HP hook: its bytes are then ours.
  const Site* addEntry = OverhealAddHookInstalled() ? &sites::kHpSetter : &sites::kOverhealAddEntry;
  if (!VerifyAll("detonationDeath", {&sites::kDetonationAreaHead, addEntry, &sites::kHpSetter,
                                     &sites::kMaxHitpointsGetter, &sites::kUnitAliveSlot, &sites::kKillQueueAsk,
                                     &sites::kDeleteSetHpCall, &sites::kDeleteKillCall, &sites::kDetonationTakeDamageHp,
                                     &sites::kTerrainImpact, &sites::kImpactEffectByName}) ||
      !AddProtoTagHandler("DetonationProtoAction", &ReadDetonation) ||
      !AddProtoTagHandler("DetonationCommand", &ReadCommand) ||
      !AddProtoTagHandler("DetonationHitpointThreshold", &ReadThreshold) ||
      !AddProtoTagHandler("DetonationHitpointDecay", &ReadDecay) ||
      !AddProtoTagHandler("DetonationImpactEffect", &ReadImpactEffect) || !OnDatabaseLoad(&Forget) ||
      !AddDeathObserver(&Kill) ||
      !WriteCall(kDeleteSetHpCall, reinterpret_cast<const void*>(&DeleteSetHp)) ||
      !WriteCall(kDeleteKillCall, reinterpret_cast<const void*>(&DeleteKill)) || !InstallOverhealAddHook() ||
      !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  g_hpLoss = &HpLoss;
  Log(L"detonationDeath: the proto tags DetonationProtoAction, DetonationCommand, DetonationHitpointThreshold, "
      L"DetonationHitpointDecay and DetonationImpactEffect are on (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
