// overhealSources [UnitType ...] [log]: only healers of the source types (default
// AbstractOverhealer) heal marked units above their reference; every other heal stops there.
//
// "Marked" and "reference" are overhealHitpointBars' (overheal.cpp, OverhealUsesInitial and
// OverhealReference, called here through their public forms in overheal_hooks.asm): a unit whose
// proto is of one of its types with 1e-6 < InitialHitpoints < MaxHitpoints, and its reference
// InitialHitpoints (or max x Initial / Max when a modifier changed its max). Without that key no
// unit is marked, so this key needs it.
//
// Four hooks (hooks/overhealsources_hooks.asm):
// - the add-HP function FUN_004823A3, through which every heal of a unit goes (the heal action,
//   area heals, regeneration, dances, powers, self heals; damage too, as negative amounts): a
//   positive amount on a marked unit is lowered so that HP stops at the reference, unless the
//   heal comes from a source healer's heal tick (g_uhcOverhealAllow);
// - the heal tick FUN_009E0B53's "HP < max" test (0x9E0BBB): for a normal healer on a marked
//   target it uses the reference, so the heal action ends there (state 10) and the healer goes
//   idle; a direct order on a unit at its reference ends the same way at once;
// - the tick's add (0x9E0CE9): sets g_uhcOverhealAllow for a source healer;
// - the automatic search FUN_009CD865's first ratio test (0x9CD984): for a normal healer a marked
//   unit at its reference is no candidate.
// A source healer heals to MaxHitpoints, as in stock. The decisions read only the units' protos
// and HP, the same on every machine.
//
// Per source type, "cap=<percent>" (100..1000) and "rate=<percent>" (1..1000) follow its name:
// - cap: such a healer heals a marked unit to at most cap % of its reference (never above the max).
//   The tick's limit (0x9E0BBB) and the search's ratio (0x9CD984) use it as they use the reference
//   for a normal healer, so the heal ends there and a unit at its cap is no candidate; the add-HP
//   hook lowers the amount to it;
// - rate: the part of each of its heals that lands above the reference is that percent of what
//   stock adds (below the reference the heal is unchanged).
// The tick add hook sets g_uhcOverhealAllow to 1 + the index of the healer's first source type, so
// the add-HP hook knows which options apply.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <set>
#include <string>
#include <string_view>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
float UhcOverhealReferenceOf(const char* unit);  // overheal_hooks.asm, cdecl
float UhcOverhealRatioOf(const char* unit);
std::int32_t UhcOverhealMarked(const char* proto);
}

namespace uhc {
extern void (*g_overhealGain)(const char* unit, bool restartDelay);  // set by overhealDecay
extern void (*g_hpLoss)(const char* unit, float amount);             // set by detonationDeath: every loss
}

namespace {

constexpr std::size_t kMaxTypes = 8;

using IsAFn = bool(__thiscall*)(const char* proto, std::int32_t type);
using UnitFloatFn = float(__thiscall*)(const char* unit);
const auto kIsA = reinterpret_cast<IsAFn>(0x0044D7FA);
const auto kMaxHitpoints = reinterpret_cast<UnitFloatFn>(0x00480408);
const auto kHealthRatio = reinterpret_cast<UnitFloatFn>(0x0045F295);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// A source type's options: cap in % of the reference (0: none, the max), rate in % above it.
struct SourceOptions {
  std::int32_t cap = 0;
  std::int32_t rate = 100;
};
SourceOptions g_options[kMaxTypes];

bool g_log = false;
bool g_cap = false;      // overhealSources is on
bool g_addHooked = false;
std::set<std::string, std::less<>> g_loggedCaps;     // proto names, "log" only
std::set<std::string, std::less<>> g_loggedSources;  // healer proto names, "log" only
std::set<std::string, std::less<>> g_loggedSourceCaps;  // proto names, "log" only

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

}  // namespace

extern "C" {
std::int32_t g_uhcOverhealSourceTypes[kMaxTypes] = {-1, -1, -1, -1, -1, -1, -1, -1};
std::int32_t g_uhcOverhealSourceTypeCount = 0;
std::int32_t g_uhcOverhealAllow = 0;  // set by the tick hook around a source healer's add
std::int32_t g_uhcOverhealRegen = 0;  // set by overhealDecay's hooks around a regeneration's add

void UhcOverhealAddHook();
void UhcOverhealTickMaxHook();
void UhcOverhealTickAddHook();
void UhcOverhealSearchRatioHook();

// 1 + the index of the healer's first source type (cfg order), or 0 for a healer of none.
std::int32_t __stdcall UhcOverhealSourceIndex(const char* healer) {
  const char* proto = healer == nullptr ? nullptr : Field<const char*>(healer, 0x5C);
  for (std::int32_t i = 0; proto != nullptr && i < g_uhcOverhealSourceTypeCount; ++i) {
    if (g_uhcOverhealSourceTypes[i] >= 0 && kIsA(proto, g_uhcOverhealSourceTypes[i])) {
      return i + 1;
    }
  }
  return 0;
}

// The most HP this healer's heal action gives the target: the reference for a marked target and a
// healer of no source type; cap % of the reference (at most the max) for a source type with a cap;
// else the stock max. From the tick hook (0x9E0BBB), in ST0.
float __stdcall UhcOverhealTickLimit(const char* target, const char* healer) {
  const char* proto = Field<const char*>(target, 0x5C);
  if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
    return kMaxHitpoints(target);
  }
  const std::int32_t source = UhcOverhealSourceIndex(healer);
  if (source == 0) {
    return UhcOverhealReferenceOf(target);
  }
  const float max = kMaxHitpoints(target);
  const std::int32_t cap = g_options[source - 1].cap;
  if (cap <= 0) {
    return max;
  }
  const float limit = UhcOverhealReferenceOf(target) * (static_cast<float>(cap) * 0.01f);
  return limit < max ? limit : max;
}

// The automatic search's ratio of a candidate for this healer (0x9CD984), in ST0: HP over the tick's
// limit with the stock rules of 0x45F295 (0 below 1e-6, 1.0 from the limit on), so a unit at the
// limit is no candidate; the stock ratio for an unmarked unit or a source without a cap.
float __stdcall UhcOverhealSearchRatio(const char* candidate, const char* healer) {
  const char* proto = Field<const char*>(candidate, 0x5C);
  if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
    return kHealthRatio(candidate);
  }
  const std::int32_t source = UhcOverhealSourceIndex(healer);
  if (source == 0) {
    return UhcOverhealRatioOf(candidate);
  }
  if (g_options[source - 1].cap <= 0) {
    return kHealthRatio(candidate);
  }
  const float limit = UhcOverhealTickLimit(candidate, healer);
  const float hp = Field<float>(candidate, 0x64);
  if (!(limit >= 1e-6f)) {
    return 0.0f;
  }
  return hp >= limit ? 1.0f : hp / limit;
}

// From the add-HP hook, before every HP addition: with overhealSources a positive amount on a marked
// unit is lowered so that HP does not pass the reference, unless a source healer's tick is adding
// it; with overhealDecay a unit that still goes above its reference is noted.
void __stdcall UhcOverhealAddHp(const char* unit, float* amount) {
  if (!(*amount > 0.0f)) {
    if (*amount < 0.0f && uhc::g_hpLoss != nullptr) {
      uhc::g_hpLoss(unit, *amount);
    }
    return;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
    return;
  }
  const float reference = UhcOverhealReferenceOf(unit);
  const float hp = Field<float>(unit, 0x64);
  if (g_cap && g_uhcOverhealAllow > 0 && g_uhcOverhealAllow <= g_uhcOverhealSourceTypeCount) {
    // A source healer's tick: its type's rate above the reference, then its cap.
    const SourceOptions& options = g_options[g_uhcOverhealAllow - 1];
    if (options.rate != 100 && hp + *amount > reference) {
      const float below = hp < reference ? reference - hp : 0.0f;
      *amount = below + (*amount - below) * (static_cast<float>(options.rate) * 0.01f);
    }
    if (options.cap > 0) {
      const float limit = reference * (static_cast<float>(options.cap) * 0.01f);
      if (hp + *amount > limit) {
        if (g_log && FirstLog(g_loggedSourceCaps, ProtoName(unit))) {
          uhc::Log(L"overhealSources: a source heal of unit %d (%hs) stops at its cap %.1f, %d %% of its 100 %% %.1f "
                   L"(HP %.1f + %.2f); logged once per proto",
                   Field<std::int32_t>(unit, 0x10), ProtoName(unit), static_cast<double>(limit), options.cap,
                   static_cast<double>(reference), static_cast<double>(hp), static_cast<double>(*amount));
        }
        *amount = limit > hp ? limit - hp : 0.0f;
      }
    }
  }
  if (!g_cap || g_uhcOverhealAllow != 0) {
    if (uhc::g_overhealGain != nullptr && hp + *amount > reference) {
      uhc::g_overhealGain(unit, g_uhcOverhealRegen == 0);
    }
    if (!g_cap) {
      return;
    }
    if (g_log && hp + *amount > reference && FirstLog(g_loggedSources, ProtoName(unit))) {
      const SourceOptions& options = g_options[(g_uhcOverhealAllow > 0 ? g_uhcOverhealAllow : 1) - 1];
      uhc::Log(L"overhealSources: unit %d (%hs) is healed above its 100 %% %.1f by a source healer (HP %.1f + %.2f; "
               L"rate %d %%); logged once per proto",
               Field<std::int32_t>(unit, 0x10), ProtoName(unit), static_cast<double>(reference),
               static_cast<double>(hp), static_cast<double>(*amount), options.rate);
    }
    return;
  }
  if (hp + *amount <= reference) {
    return;
  }
  const float capped = reference > hp ? reference - hp : 0.0f;
  if (g_log && FirstLog(g_loggedCaps, ProtoName(unit))) {
    uhc::Log(L"overhealSources: a heal of unit %d (%hs) stops at its 100 %% %.1f (HP %.1f, +%.2f -> +%.2f; not "
             L"from a source healer); logged once per proto",
             Field<std::int32_t>(unit, 0x10), ProtoName(unit), static_cast<double>(reference),
             static_cast<double>(hp), static_cast<double>(*amount), static_cast<double>(capped));
  }
  *amount = capped;
}
}

namespace uhc {

void (*g_overhealGain)(const char* unit, bool restartDelay) = nullptr;
void (*g_hpLoss)(const char* unit, float amount) = nullptr;

bool InstallOverhealAddHook() {
  if (!g_addHooked) {
    // Replaces push ecx / push esi / mov esi,ecx / cmp dword ptr [esi+8],8 at 0x4823A3.
    g_addHooked = WriteJmp(0x004823A3, reinterpret_cast<const void*>(&UhcOverhealAddHook), 8);
  }
  return g_addHooked;
}

bool OverhealAddHookInstalled() { return g_addHooked; }

Outcome ApplyOverhealSources(const Config& config) {
  const Config::Args* args = config.First("overhealSources");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (config.First("overhealHitpointBars") == nullptr) {
    Log(L"overhealSources: needs overhealHitpointBars, whose unit types mark the units with a reference below their "
        L"max; feature not applied");
    return Outcome::kFailed;
  }
  std::vector<std::string> typeNames;
  for (const std::string& arg : *args) {
    const bool cap = _strnicmp(arg.c_str(), "cap=", 4) == 0;
    const bool rate = _strnicmp(arg.c_str(), "rate=", 5) == 0;
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (cap || rate) {
      std::string text = arg.substr(cap ? 4 : 5);
      if (!text.empty() && text.back() == '%') {
        text.pop_back();
      }
      char* end = nullptr;
      const long value = std::strtol(text.c_str(), &end, 10);
      const bool valid = !text.empty() && end == text.c_str() + text.size() && value <= 1000 && value >= (cap ? 100 : 1);
      if (typeNames.empty() || !valid) {
        Log(L"overhealSources: %hs: expected <UnitType> [cap=<percent>, 100 to 1000] [rate=<percent>, 1 to 1000] after "
            L"each source type; feature not applied",
            arg.c_str());
        return Outcome::kFailed;
      }
      SourceOptions& options = g_options[typeNames.size() - 1];
      (cap ? options.cap : options.rate) = static_cast<std::int32_t>(value);
    } else if (arg.find('=') != std::string::npos) {
      Log(L"overhealSources: %hs: expected [<UnitType> [cap=<percent>] [rate=<percent>] ...] [log]; feature not "
          L"applied",
          arg.c_str());
      return Outcome::kFailed;
    } else if (typeNames.size() == kMaxTypes) {
      Log(L"overhealSources: more than %u unit types (expected: [UnitType ...] [log]); feature not applied",
          static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      typeNames.push_back(arg);
    }
  }
  if (typeNames.empty()) {
    typeNames.push_back("AbstractOverhealer");
  }
  if (!VerifyAll("overhealSources", {&sites::kOverhealAddEntry, &sites::kHealTickMax, &sites::kHealTickAdd,
                                     &sites::kHealSearchRatio, &sites::kMaxHitpointsGetter, &sites::kHealthRatio,
                                     &sites::kIsA})) {
    return Outcome::kFailed;
  }
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    if (!RequestAbstractUnitType(typeNames[i].c_str(), &g_uhcOverhealSourceTypes[i])) {
      return Outcome::kFailed;
    }
  }
  g_uhcOverhealSourceTypeCount = static_cast<std::int32_t>(typeNames.size());
  g_cap = true;
  if (!InstallOverhealAddHook() || !WriteJmp(0x009E0BBB, reinterpret_cast<const void*>(&UhcOverhealTickMaxHook), 5) ||
      !WriteJmp(0x009E0CE9, reinterpret_cast<const void*>(&UhcOverhealTickAddHook), 5) ||
      !WriteJmp(0x009CD984, reinterpret_cast<const void*>(&UhcOverhealSearchRatioHook), 5)) {
    return Outcome::kFailed;
  }
  std::string names;
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    names += i == 0 ? typeNames[i] : ", " + typeNames[i];
    const SourceOptions& options = g_options[i];
    if (options.cap > 0 || options.rate != 100) {
      char text[64];
      if (options.cap <= 0) {
        std::snprintf(text, sizeof text, " (rate %d %% above 100 %%)", options.rate);
      } else if (options.rate == 100) {
        std::snprintf(text, sizeof text, " (up to %d %%)", options.cap);
      } else {
        std::snprintf(text, sizeof text, " (up to %d %%, rate %d %% above 100 %%)", options.cap, options.rate);
      }
      names += text;
    }
  }
  Log(L"overhealSources: only healers of unittype %hs heal marked units above their 100 %%; every other heal stops "
      L"there%ls (multiplayer unverified)",
      names.c_str(), g_log ? L", the first cap and source heal of each proto logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
