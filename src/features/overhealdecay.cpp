// overhealDecay <rate>[%] [delay] [UnitType ...] [log]: the HP of marked units above their reference
// goes back down to it over time, Overwatch style.
//
// "Marked" and "reference" are overhealHitpointBars' (through the public helpers of
// overheal_hooks.asm), so this key needs it. A unit is noted when a heal takes it above its
// reference: the add-HP hook (shared with overhealSources, overhealsources.cpp) calls Note with the
// game time (a heal restarts the delay; a regeneration, flagged by two call-site hooks, does not:
// an idle unit regenerates every step and would otherwise never decay). After each world update (the shared wrapper of worldtick.cpp), every noted unit, in
// unit ID order, loses rate HP per second (or rate % of its reference per second) of game time,
// once <delay> seconds have passed since its last gain, down to the reference and never below it.
// A unit that is gone, dead, unmarked or back at its reference is forgotten. HP is set through the
// stock setter FUN_004820A1 with flag 0: it clamps and updates the damage visuals, and skips its
// death check 0x482152, which a HP above the reference never needs. The setter raises no attack
// event (those come from TakeDamage), so the decay is not seen as an attack.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <map>
#include <set>
#include <string>
#include <string_view>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
float UhcOverhealReferenceOf(const char* unit);  // overheal_hooks.asm, cdecl
std::int32_t UhcOverhealMarked(const char* proto);
}

namespace uhc {
extern void (*g_overhealGain)(const char* unit, bool restartDelay);  // overhealsources.cpp
bool InstallOverhealAddHook();
bool OverhealAddHookInstalled();
}  // namespace uhc

extern "C" {
void UhcOverhealRegenAddHook();       // overhealsources_hooks.asm: the unit's own regeneration
void UhcOverhealDanceRegenAddHook();  // the Regeneration dance
}

namespace {

constexpr std::size_t kMaxTypes = 8;
constexpr std::uint32_t kGameGlobal = 0x00C66234;

using SetHpFn = void(__thiscall*)(char* unit, float value, std::int32_t flag);
using IsAFn = bool(__thiscall*)(const char* proto, std::int32_t type);
using IsAliveFn = bool(__thiscall*)(const char* unit);
const auto kSetHp = reinterpret_cast<SetHpFn>(0x004820A1);
const auto kIsA = reinterpret_cast<IsAFn>(0x0044D7FA);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

float g_rate = 0.0f;  // HP per second, or % of the reference per second
bool g_percent = false;
std::uint32_t g_delayMs = 0;
std::int32_t g_types[kMaxTypes] = {-1, -1, -1, -1, -1, -1, -1, -1};
std::int32_t g_typeCount = 0;
bool g_log = false;

// Noted units by unit ID (so every machine walks them in the same order): the game time of their
// last gain above the reference.
std::map<std::int32_t, std::uint32_t> g_units;
const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
std::set<std::string, std::less<>> g_loggedStart;  // proto names, "log" only
std::set<std::string, std::less<>> g_loggedEnd;

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<IsAliveFn const* const*>(unit))[0xA4 / 4](unit); }

const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

bool FirstLog(std::set<std::string, std::less<>>& logged, const char* name) {
  if (logged.find(std::string_view(name)) != logged.end()) {
    return false;
  }
  logged.emplace(name);
  return true;
}

// The unit decays: marked, and of one of the listed types when types were given.
bool Decays(const char* proto) {
  if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
    return false;
  }
  if (g_typeCount == 0) {
    return true;
  }
  for (std::int32_t i = 0; i < g_typeCount; ++i) {
    if (g_types[i] >= 0 && kIsA(proto, g_types[i])) {
      return true;
    }
  }
  return false;
}

// From the add-HP hook: a gain takes this marked unit above its reference. A heal restarts the
// delay; a regeneration (the unit's own, or the Regeneration dance) does not: it only notes a unit
// that was not noted yet, as if its delay had passed, so regenerating every step cannot hold the
// overheal.
void Note(const char* unit, bool restartDelay) {
  const char* world = World();
  if (world == nullptr || !Decays(Field<const char*>(unit, 0x5C))) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (restartDelay) {
    g_units[Field<std::int32_t>(unit, 0x10)] = now;
  } else {
    g_units.emplace(Field<std::int32_t>(unit, 0x10), now - g_delayMs);
  }
}

void Reset(char*) { g_units.clear(); }

// After each world update: game time [world+108h] since the last tick, never the real clock. A new
// game (another game world, the time going back or the step count jumping) forgets every unit.
void DecayTick(char* world, std::int32_t) {
  // The world update also runs for other worlds (the home city's; 0x481D01 compares this with
  // [game+13Ch]): only the game world's units decay, and another world must not look like a new game.
  if (world != World()) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const bool sameGame = world == g_world && now >= g_lastTime && step - g_lastStep <= 1;
  const std::uint32_t elapsed = sameGame ? now - g_lastTime : 0;
  if (!sameGame) {
    g_units.clear();
    g_world = world;
  }
  g_lastTime = now;
  g_lastStep = step;
  if (elapsed == 0) {
    return;
  }
  for (auto it = g_units.begin(); it != g_units.end();) {
    char* unit = UnitById(world, it->first);
    if (unit == nullptr || !IsAlive(unit) || !Decays(Field<const char*>(unit, 0x5C))) {
      it = g_units.erase(it);
      continue;
    }
    const float reference = UhcOverhealReferenceOf(unit);
    const float hp = Field<float>(unit, 0x64);
    if (!(hp > reference)) {
      if (g_log && FirstLog(g_loggedEnd, ProtoName(unit))) {
        uhc::Log(L"overhealDecay: unit %d (%hs) is back at its 100 %% %.1f; logged once per proto", it->first,
                 ProtoName(unit), static_cast<double>(reference));
      }
      it = g_units.erase(it);
      continue;
    }
    if (now - it->second < g_delayMs) {
      ++it;
      continue;
    }
    const float perSecond = g_percent ? reference * g_rate * 0.01f : g_rate;
    float value = hp - perSecond * static_cast<float>(elapsed) * 0.001f;
    if (g_log && FirstLog(g_loggedStart, ProtoName(unit))) {
      uhc::Log(L"overhealDecay: unit %d (%hs) decays from %.1f toward its 100 %% %.1f at %.2f HP/s; logged once "
               L"per proto",
               it->first, ProtoName(unit), static_cast<double>(hp), static_cast<double>(reference),
               static_cast<double>(perSecond));
    }
    const bool reached = !(value > reference);
    if (reached) {
      value = reference;
    }
    kSetHp(unit, value, 0);
    ++it;  // forgotten on the next tick once it is at its reference
  }
}

// "2", "1.5", "3%": a positive number, with an optional % sign.
bool ParseRate(const std::string& arg, float* rate, bool* percent) {
  std::string text = arg;
  *percent = !text.empty() && text.back() == '%';
  if (*percent) {
    text.pop_back();
  }
  char* end = nullptr;
  const double value = std::strtod(text.c_str(), &end);
  if (text.empty() || end != text.c_str() + text.size() || !(value > 0.0) || value > 1.0e6) {
    return false;
  }
  *rate = static_cast<float>(value);
  return true;
}

bool ParseSeconds(const std::string& arg, std::uint32_t* ms) {
  char* end = nullptr;
  const double value = std::strtod(arg.c_str(), &end);
  if (arg.empty() || end != arg.c_str() + arg.size() || value < 0.0 || value > 3600.0) {
    return false;
  }
  *ms = static_cast<std::uint32_t>(value * 1000.0 + 0.5);
  return true;
}

}  // namespace

namespace uhc {

Outcome ApplyOverhealDecay(const Config& config) {
  const Config::Args* args = config.First("overhealDecay");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (config.First("overhealHitpointBars") == nullptr) {
    Log(L"overhealDecay: needs overhealHitpointBars, whose unit types mark the units with a reference below their "
        L"max; feature not applied");
    return Outcome::kFailed;
  }
  if (args->empty() || !ParseRate(args->front(), &g_rate, &g_percent)) {
    Log(L"overhealDecay: expected <HP per second>[%%] [delay seconds] [UnitType ...] [log], e.g. overhealDecay 2 3; "
        L"feature not applied");
    return Outcome::kFailed;
  }
  std::vector<std::string> typeNames;
  for (std::size_t i = 1; i < args->size(); ++i) {
    const std::string& arg = (*args)[i];
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (i == 1 && ParseSeconds(arg, &g_delayMs)) {
      // the delay
    } else if (typeNames.size() == kMaxTypes) {
      Log(L"overhealDecay: more than %u unit types; feature not applied", static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      typeNames.push_back(arg);
    }
  }
  const Site* addEntry = OverhealAddHookInstalled() ? &sites::kHpSetter : &sites::kOverhealAddEntry;
  if (!VerifyAll("overhealDecay", {addEntry, &sites::kHpSetter, &sites::kMaxHitpointsGetter, &sites::kUnitAliveSlot,
                                   &sites::kIsA, &sites::kRegenAddHp, &sites::kDanceRegenAddHp}) ||
      !OnDatabaseLoad(&Reset)) {
    return Outcome::kFailed;
  }
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    if (!RequestAbstractUnitType(typeNames[i].c_str(), &g_types[i])) {
      return Outcome::kFailed;
    }
  }
  g_typeCount = static_cast<std::int32_t>(typeNames.size());
  g_overhealGain = &Note;
  // The adder's two regeneration calls (call 4823A3h) are flagged, so they do not restart the delay.
  if (!InstallOverhealAddHook() || !WriteJmp(0x00490881, reinterpret_cast<const void*>(&UhcOverhealRegenAddHook), 5) ||
      !WriteJmp(0x0067A03B, reinterpret_cast<const void*>(&UhcOverhealDanceRegenAddHook), 5) ||
      !AddWorldTick(&DecayTick)) {
    g_overhealGain = nullptr;
    return Outcome::kFailed;
  }
  std::string names;
  for (const std::string& name : typeNames) {
    names += ", " + name;
  }
  Log(L"overhealDecay: marked units above their 100 %% lose %.2f %ls per second of game time, %.1f s after their "
      L"last gain, down to it%hs%ls (multiplayer unverified)",
      static_cast<double>(g_rate), g_percent ? L"% of it" : L"HP", g_delayMs / 1000.0,
      names.empty() ? "" : (" (units of" + names.substr(1) + " only)").c_str(), g_log ? L"; logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
