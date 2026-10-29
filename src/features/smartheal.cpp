// smartHealTargets [UnitType ...] [log]: a healer's automatic search heals the best candidate, not
// the first one.
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
#include <cmath>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::size_t kMaxTypes = 8;
constexpr int kMaxLoggedPicks = 200;

using RatioFn = float(__thiscall*)(const char* unit);
using IsAFn = bool(__thiscall*)(const char* proto, std::int32_t type);
const auto kHealthRatio = reinterpret_cast<RatioFn>(0x0045F295);
const auto kIsA = reinterpret_cast<IsAFn>(0x0044D7FA);

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

// From the range hook (0x9CDA36), for a candidate that passed every stock test.
void __stdcall UhcSmartHealConsider(const char* healer, const char* unit) {
  if (healer != g_healer) {  // a new search
    g_healer = healer;
    g_considered = 0;
  }
  Candidate c;
  c.unit = unit;
  c.rank = g_uhcSmartHealTypeCount;
  const char* proto = Field<const char*>(unit, 0x5C);
  for (std::int32_t i = 0; proto != nullptr && i < g_uhcSmartHealTypeCount; ++i) {
    if (g_uhcSmartHealTypes[i] >= 0 && kIsA(proto, g_uhcSmartHealTypes[i])) {
      c.rank = i;
      break;
    }
  }
  c.ratio = kHealthRatio(unit);
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
  if (!have) {
    return nullptr;
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
}

namespace uhc {

Outcome ApplySmartHealTargets(const Config& config) {
  const Config::Args* args = config.First("smartHealTargets");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::vector<std::string> typeNames;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (typeNames.size() == kMaxTypes) {
      Log(L"smartHealTargets: more than %u unit types (expected: [UnitType ...] [log]); feature not applied",
          static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      typeNames.push_back(arg);
    }
  }
  if (!VerifyAll("smartHealTargets", {&sites::kSmartHealLoop, &sites::kSmartHealRange, &sites::kSmartHealLoopEnd,
                                      &sites::kHealthRatio, &sites::kIsA})) {
    return Outcome::kFailed;
  }
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    if (!RequestAbstractUnitType(typeNames[i].c_str(), &g_uhcSmartHealTypes[i])) {
      return Outcome::kFailed;
    }
  }
  g_uhcSmartHealTypeCount = static_cast<std::int32_t>(typeNames.size());
  // Replaces call 7FCF2Dh at 0x9CDA36 and pop esi / pop ebx / pop edi / xor al,al at 0x9CDA58.
  if (!WriteJmp(0x009CDA36, reinterpret_cast<const void*>(&UhcSmartHealRangeHook), 5) ||
      !WriteJmp(0x009CDA58, reinterpret_cast<const void*>(&UhcSmartHealPickHook), 5)) {
    return Outcome::kFailed;
  }
  std::string order;
  for (const std::string& name : typeNames) {
    order += name + ", ";
  }
  Log(L"smartHealTargets: automatic heal searches pick the best candidate: %hslowest HP ratio, nearest, lowest unit "
      L"ID%ls (multiplayer unverified)",
      order.c_str(), g_log ? L"; picks logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
