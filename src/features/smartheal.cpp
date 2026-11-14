// smartHealTargets [UnitType ...] [switch=<percent>] [log]: a healer's automatic search heals the
// best candidate, not the first one.
//
// FUN_009CD865 (the automatic heal search, called from 0x68C14E for an idle healer) runs a unit
// query around the healer and walks its results ([query+0], 38h-byte entries, count [query+4], no
// cap of its own) in query order. Each candidate must pass every stock test: not the healer, HP
// ratio (0x45F295) in [1e-6, 1), alive (vtbl+A4h), an action manager, idle (0x44F1A7, or any with
// healNonIdle), not abstract bit 6, not flag 42h, a heal action (0x4EE797, type 5), 0x9C2E40(5, 8)
// <= 0, and in range (0x7FCF2D). The first one that passes is healed (0x9CDA62: vtbl+64h(1), then
// 0x9CBDC4 with its ID); with none the search returns 0 (0x9CDA58).
//
// The hooks (hooks/smartheal_hooks.asm) keep every test and only change the choice: a candidate in
// range is recorded and the loop goes on; at the loop's end the best one goes to the stock accept
// path. Best = first the listed unit types (in cfg order; a unit of none of them ranks after
// them), then the lowest HP ratio, then the nearest to the healer (squared ground distance), then
// the lowest unit ID: no memory address and no query order decides, so every machine picks the
// same unit. The key applies to every healer: the search is the same function for all of them,
// and the change only reorders units the stock rules already accept.
//
// "switch=<percent>": stock never searches again while a heal runs (the search is called only for
// an idle healer). With the option, a hook at the start of the healing state of the heal tick
// FUN_009E0B53 (0x9E0C3A) re-checks a heal this search started, once per second of game time per
// healer: it calls the same search as a dry run (the pick hook returns nothing, so nothing starts),
// in which a candidate counts only if it ranks at the target's type or before it and its HP ratio
// is lower than the target's by more than the margin. If one does, the tick ends the heal through
// its own end path 0x9E0D3F (state 10, as when the target is full); the healer is idle again and
// the stock idle search picks the best unit, which that candidate beats the old target to. A heal
// the player ordered is never re-checked. The last pick and re-check second of each healer live in
// the DLL, so after a load only the heals started since then are re-checked.
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::size_t kMaxTypes = 8;
constexpr int kMaxLoggedPicks = 200;
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr std::uint32_t kRecheckMs = 1000;         // game time between two re-checks of one healer

using RatioFn = float(__thiscall*)(const char* unit);
using IsAFn = bool(__thiscall*)(const char* proto, std::int32_t type);
using SearchFn = bool(__thiscall*)(char* owner);
const auto kHealthRatio = reinterpret_cast<RatioFn>(0x0045F295);
const auto kIsA = reinterpret_cast<IsAFn>(0x0044D7FA);
const auto kHealSearch = reinterpret_cast<SearchFn>(0x009CD865);  // thiscall(the healer's action manager)

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Candidate {
  const char* unit = nullptr;
  std::int32_t rank = 0;
  float ratio = 0.0f;
  float distance2 = 0.0f;
  std::int32_t id = 0;
};

// The search in progress (the simulation is single-threaded and the search does not re-enter).
const char* g_healer = nullptr;
Candidate g_best;
Candidate g_first;  // what stock would have healed, for the log
int g_considered = 0;
int g_loggedPicks = 0;
bool g_log = false;

// "switch=<percent>": the margin as a ratio; negative while the option is off.
float g_switchMargin = -1.0f;
int g_loggedSwitches = 0;

// A dry run of the search from the re-check: only candidates that beat the current target by the
// margin count, and the pick starts nothing.
struct Recheck {
  bool active = false;
  std::int32_t rank = 0;  // the current target's
  float ratio = 0.0f;     // the current target's
  bool found = false;
  Candidate best;
};
Recheck g_recheck;

// Per healer ID: the target of the last heal this search started, and the second of game time of
// its last re-check. A heal of another target (a player's order) is not re-checked.
struct AutoHeal {
  std::int32_t target = -1;
  std::uint32_t second = 0;
};
std::unordered_map<std::int32_t, AutoHeal> g_autoHeals;

std::uint32_t GameTime() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  return world == nullptr ? 0 : Field<std::uint32_t>(world, 0x108);
}

void ForgetHeals(char*) { g_autoHeals.clear(); }

bool Better(const Candidate& a, const Candidate& b) {
  if (a.rank != b.rank) {
    return a.rank < b.rank;
  }
  if (a.ratio != b.ratio) {
    return a.ratio < b.ratio;
  }
  if (a.distance2 != b.distance2) {
    return a.distance2 < b.distance2;
  }
  return a.id < b.id;
}

const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

}  // namespace

extern "C" {
std::int32_t g_uhcSmartHealTypes[kMaxTypes] = {-1, -1, -1, -1, -1, -1, -1, -1};
std::int32_t g_uhcSmartHealTypeCount = 0;

void UhcSmartHealRangeHook();
void UhcSmartHealPickHook();
void UhcSmartHealSwitchHook();
}

namespace {

// The index of the first listed type the unit is of; the type count for none.
std::int32_t RankOf(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  for (std::int32_t i = 0; proto != nullptr && i < g_uhcSmartHealTypeCount; ++i) {
    if (g_uhcSmartHealTypes[i] >= 0 && kIsA(proto, g_uhcSmartHealTypes[i])) {
      return i;
    }
  }
  return g_uhcSmartHealTypeCount;
}

}  // namespace

extern "C" {

// From the range hook (0x9CDA36), for a candidate that passed every stock test.
void __stdcall UhcSmartHealConsider(const char* healer, const char* unit) {
  if (healer != g_healer) {  // a new search
    g_healer = healer;
    g_considered = 0;
  }
  Candidate c;
  c.unit = unit;
  c.rank = RankOf(unit);
  c.ratio = kHealthRatio(unit);
  if (g_recheck.active && (c.rank > g_recheck.rank || !(c.ratio < g_recheck.ratio - g_switchMargin))) {
    return;  // a dry run: not worth leaving the current target for
  }
  const float dx = Field<float>(unit, 0x14) - Field<float>(healer, 0x14);
  const float dz = Field<float>(unit, 0x1C) - Field<float>(healer, 0x1C);
  c.distance2 = dx * dx + dz * dz;
  c.id = Field<std::int32_t>(unit, 0x10);
  if (g_considered == 0) {
    g_first = c;
    g_best = c;
  } else if (Better(c, g_best)) {
    g_best = c;
  }
  ++g_considered;
}

// From the pick hook (0x9CDA58), at the end of the search: the unit to heal, or null.
const char* __stdcall UhcSmartHealPick(const char* healer) {
  const bool have = healer == g_healer && g_considered > 0;
  const Candidate best = g_best;
  const Candidate first = g_first;
  const int considered = g_considered;
  g_healer = nullptr;
  g_considered = 0;
  if (g_recheck.active) {  // a dry run: nothing starts
    g_recheck.found = have;
    g_recheck.best = best;
    return nullptr;
  }
  if (!have) {
    return nullptr;
  }
  if (g_switchMargin >= 0.0f) {
    AutoHeal& heal = g_autoHeals[Field<std::int32_t>(healer, 0x10)];
    heal.target = best.id;
    heal.second = GameTime() / kRecheckMs;
  }
  if (g_log && g_loggedPicks < kMaxLoggedPicks) {
    ++g_loggedPicks;
    uhc::Log(L"smartHealTargets: unit %d (%hs) heals unit %d (%hs, rank %d, HP ratio %.3f, %.1f m) among %d "
             L"candidates; stock would heal unit %d (%hs, HP ratio %.3f)%ls",
             Field<std::int32_t>(healer, 0x10), ProtoName(healer), best.id, ProtoName(best.unit), best.rank,
             static_cast<double>(best.ratio), static_cast<double>(std::sqrt(best.distance2)), considered, first.id,
             ProtoName(first.unit), static_cast<double>(first.ratio),
             g_loggedPicks == kMaxLoggedPicks ? L" (further picks not logged)" : L"");
  }
  return best.unit;
}

// From the switch hook (0x9E0C3A), on each tick of a heal in its healing state: true ends the heal
// (the tick's own end path), because a candidate beats its target by more than the margin.
bool __stdcall UhcSmartHealRecheck(char* healer, const char* target) {
  if (healer == nullptr || target == nullptr || g_switchMargin < 0.0f) {
    return false;
  }
  const auto it = g_autoHeals.find(Field<std::int32_t>(healer, 0x10));
  if (it == g_autoHeals.end() || it->second.target != Field<std::int32_t>(target, 0x10)) {
    return false;  // not a heal the search started: a player's order is kept
  }
  const std::uint32_t second = GameTime() / kRecheckMs;
  if (it->second.second == second) {
    return false;
  }
  it->second.second = second;
  char* owner = Field<char*>(healer, 0x58);  // the action manager the stock search is called with
  if (owner == nullptr || Field<const char*>(owner, 0x04) != healer) {
    return false;
  }
  g_recheck = Recheck{};
  g_recheck.active = true;
  g_recheck.rank = RankOf(target);
  g_recheck.ratio = kHealthRatio(target);
  kHealSearch(owner);
  g_recheck.active = false;
  if (!g_recheck.found) {
    return false;
  }
  if (g_log && g_loggedSwitches < kMaxLoggedPicks) {
    ++g_loggedSwitches;
    uhc::Log(L"smartHealTargets: unit %d (%hs) leaves unit %d (%hs, rank %d, HP ratio %.3f) for a better candidate, "
             L"unit %d (%hs, rank %d, HP ratio %.3f; switch margin %.2f)%ls",
             Field<std::int32_t>(healer, 0x10), ProtoName(healer), Field<std::int32_t>(target, 0x10),
             ProtoName(target), g_recheck.rank, static_cast<double>(g_recheck.ratio), g_recheck.best.id,
             ProtoName(g_recheck.best.unit), g_recheck.best.rank, static_cast<double>(g_recheck.best.ratio),
             static_cast<double>(g_switchMargin),
             g_loggedSwitches == kMaxLoggedPicks ? L" (further switches not logged)" : L"");
  }
  g_autoHeals.erase(it);  // the next pick notes the new heal
  return true;
}
}

namespace uhc {

Outcome ApplySmartHealTargets(const Config& config) {
  const Config::Args* args = config.First("smartHealTargets");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::vector<std::string> typeNames;
  std::int32_t switchPercent = -1;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_strnicmp(arg.c_str(), "switch=", 7) == 0) {
      std::string value = arg.substr(7);
      if (!value.empty() && value.back() == '%') {
        value.pop_back();
      }
      char* end = nullptr;
      const long percent = std::strtol(value.c_str(), &end, 10);
      if (value.empty() || end != value.c_str() + value.size() || percent < 1 || percent > 100) {
        Log(L"smartHealTargets: %hs: expected switch=<percent>, 1 to 100; feature not applied", arg.c_str());
        return Outcome::kFailed;
      }
      switchPercent = static_cast<std::int32_t>(percent);
    } else if (arg.find('=') != std::string::npos) {
      Log(L"smartHealTargets: %hs: expected [UnitType ...] [switch=<percent>] [log]; feature not applied", arg.c_str());
      return Outcome::kFailed;
    } else if (typeNames.size() == kMaxTypes) {
      Log(L"smartHealTargets: more than %u unit types (expected: [UnitType ...] [switch=<percent>] [log]); feature "
          L"not applied",
          static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      typeNames.push_back(arg);
    }
  }
  if (!VerifyAll("smartHealTargets", {&sites::kSmartHealLoop, &sites::kSmartHealRange, &sites::kSmartHealLoopEnd,
                                      &sites::kHealthRatio, &sites::kIsA}) ||
      (switchPercent > 0 && !VerifyAll("smartHealTargets switch", {&sites::kHealTickHealing, &sites::kHealTickEnd,
                                                                   &sites::kHealSearchHead}))) {
    return Outcome::kFailed;
  }
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    if (!RequestAbstractUnitType(typeNames[i].c_str(), &g_uhcSmartHealTypes[i])) {
      return Outcome::kFailed;
    }
  }
  g_uhcSmartHealTypeCount = static_cast<std::int32_t>(typeNames.size());
  if (switchPercent > 0 && !OnDatabaseLoad(&ForgetHeals)) {
    return Outcome::kFailed;
  }
  // Replaces call 7FCF2Dh at 0x9CDA36 and pop esi / pop ebx / pop edi / xor al,al at 0x9CDA58.
  if (!WriteJmp(0x009CDA36, reinterpret_cast<const void*>(&UhcSmartHealRangeHook), 5) ||
      !WriteJmp(0x009CDA58, reinterpret_cast<const void*>(&UhcSmartHealPickHook), 5)) {
    return Outcome::kFailed;
  }
  if (switchPercent > 0) {
    g_switchMargin = static_cast<float>(switchPercent) / 100.0f;
    // Replaces mov ecx,[esi+24h] / push 8 / mov [esp+14h],ecx at 0x9E0C3A.
    if (!WriteJmp(0x009E0C3A, reinterpret_cast<const void*>(&UhcSmartHealSwitchHook), 9)) {
      return Outcome::kFailed;
    }
  }
  std::string order;
  for (const std::string& name : typeNames) {
    order += name + ", ";
  }
  wchar_t switching[96] = L"";
  if (switchPercent > 0) {
    swprintf_s(switching, L"; a running heal switches to a candidate more than %d %% lower", switchPercent);
  }
  Log(L"smartHealTargets: automatic heal searches pick the best candidate: %hslowest HP ratio, nearest, lowest unit "
      L"ID%ls%ls (multiplayer unverified)",
      order.c_str(), switching, g_log ? L"; picks logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
