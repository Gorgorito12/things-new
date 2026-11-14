// buildingWorkRateAuras: an aura (or any other stat modifier) whose ModifyType is BuildingWorkRate
// changes how fast the units it reaches train, research and spawn their Maintain units, and how fast
// they heal and build.
//
// Stock: ModifyType names are read by FUN_005F5645, for the tactics tag <ModifyType> (0x5FC8AE,
// stored unchecked in the byte [action+B8h]) and for the <unitModify> powers (0x5F3EFA, which
// rejects a negative stat). It knows Speed, MaxHP, Damage, MovingDamage, Bounty, SiegeDamage,
// UnitDamage, LOS, Armor, GatherRate, AbilityROF, ROF and AutoGatherRate (stats 0..8, 0Bh..0Eh);
// any other name gives -1, so an aura with <ModifyType>BuildingWorkRate</ModifyType> does nothing.
// An AutoRangedModify aura (FUN_009D033E) gives each unit it reaches a modifier through 0x4DD22D:
// a unit action of type 2Ch with the stat, the multiplier and operation 2 (multiply). The record
// recompute FUN_0049F1BA sums the modifiers of those 13 stats into [[unit+B4h]+C8h], where the
// stat readers find them (GatherRate +24h, AutoGatherRate +28h, ...). The BuildingWorkRate getter
// 0x9BFE33, which the Train, Research, CommandResearch and Maintain updates call on every tick,
// reads only the building's copy or the proto's value, never a modifier.
//
// The change:
// - the parser's last compare also accepts "BuildingWorkRate" (case ignored, like every name) and
//   returns the new stat 40h. No stock code produces or computes it: the record recompute ignores
//   it, saved games store it as an int, the aura tooltip shows no stat line for it;
// - the four calls of the getter go to a wrapper. For a unit with a modifier record it multiplies
//   the getter's result by the stock modifier sum 0x4B3C7D over the unit's stat-40h modifiers,
//   starting from 1.0, with the GatherRate reader's rule: no modifier, or a sum below 1e-6, counts
//   as 1.0. A unit without a record (it never had a modifier) gets the stock call.
// The getter itself is not touched, so liveBuildingWorkRate (which hooks it) combines with this
// key: the factor then multiplies the proto's live rate. The data refs currentUnitBuildingWorkRate and
// its Float twin, the panel's number, read the proto (0x6F49FC): they now read the rate the unit works at,
// the building's own copy and the factor. The hooks are in hooks/bwraura_hooks.asm.
//
// Heal and build read their rate through 0x487C45, which has 22 callers (gather too), so the callee is
// left alone: only the calls that add the work go to UhcBwrRateCall, with the worker in [esi+10h]. The
// calls that only ask whether the rate is above 0 stay stock. Repair is the building's own AutoRepair action
// (the command repairUnit, type 3Ah): its update adds [action+64h] x time at 0x9D0BF2, hooked there.
#include <bit>
#include <cstdint>
#include <cstring>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifiers.h"
#include "../modifytypes.h"
#include "../patch.h"

extern "C" {
void UhcBwrAuraCall();
void UhcBwrRateCall();
void UhcBwrGetterHook();  // liveBuildingWorkRate's getter hook (hooks/workrate_hooks.asm)
void UhcBwrPanelHook();
void UhcBwrRepairHook();
}

namespace {

// Engine layout (docs/engine-symbols.md, "Building work rate auras").
constexpr std::int32_t kStatBuildingWorkRate = 0x40;  // the new ModifyType stat, as in bwraura_hooks.asm
constexpr float kMinFactor = 1.0e-6f;  // 0xB9FB64: a smaller sum counts as no modifier (0x69FE56)
constexpr std::uint32_t kTrainCall = 0x009EA413;     // call 9BFE33h in the Train update

using GetterFn = float(__thiscall*)(const char* unit);
const auto kGetter = reinterpret_cast<GetterFn>(0x009BFE33);

// The four callers of the getter: the address of the call and the return address it pushes.
struct Caller {
  std::uint32_t call;
  std::uint32_t ret;
  const wchar_t* name;
};
constexpr Caller kCallers[] = {
    {kTrainCall, 0x009EA418, L"Train"},
    {0x009E65F7, 0x009E65FC, L"Research"},
    {0x009D58D4, 0x009D58D9, L"CommandResearch"},
    {0x006AB23F, 0x006AB244, L"Maintain"},
};

// The calls of the rate lookup that add the work.
struct RateCaller {
  std::uint32_t call;
  std::uint32_t ret;
  const wchar_t* name;
};
constexpr RateCaller kRateCallers[] = {
    {0x009E0CCF, 0x009E0CD4, L"Heal"},
    {0x009D3D7B, 0x009D3D80, L"Build"},
};

// The list the stock sum reads, {data +0, count +4}: the layout of the collector's list 0xCF0718.
struct ModifierArray {
  const char* const* data;
  std::int32_t count;
};

// bool thiscall(unused, float* value, list, stat), ret 0Ch: applies each modifier of `stat` in
// order (0 set, 1 add, 2 multiply, rounded by fstp), stops after an exclusive one; true if any
// matched. ECX is not read.
using ModifierSumFn = bool(__thiscall*)(void* unused, float* value, const ModifierArray* list, std::int32_t stat);
const auto kModifierSum = reinterpret_cast<ModifierSumFn>(0x004B3C7D);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

bool g_log = false;  // "buildingWorkRateAuras log"
// The unit's stat-40h modifiers in walk order, reused by every call. Only the game thread (the
// simulation update) touches these.
std::vector<const char*> g_matched;
// Unit ID -> the factor bits last logged for it; a unit back at 1.0 is erased.
std::unordered_map<std::int32_t, std::uint32_t> g_logged;

// The unit's BuildingWorkRate factor: the stock sum over its stat-40h modifiers in the collector's
// order, from 1.0, used as FUN_004ECD87 uses the GatherRate record (0x69FE53): 1.0 when no
// modifier matched or the sum is below 1e-6. 1.0 too for an action tree deeper than
// modifiers::kMaxDepth.
float Factor(const char* unit) {
  const char* list = uhc::modifiers::ModifierList(unit);
  if (list == nullptr) {
    return 1.0f;
  }
  g_matched.clear();
  auto visit = [](const char* action) {
    if (Field<std::int32_t>(action, 0x64) == kStatBuildingWorkRate) {
      g_matched.push_back(action);
    }
    return true;
  };
  if (uhc::modifiers::WalkModifiers(list, visit, 0) != uhc::modifiers::Walk::kDone || g_matched.empty()) {
    return 1.0f;
  }
  // Only stat-40h modifiers are passed: the sum skips the others anyway, and stops only after a
  // matching one, so the result is the one it gives on the full collected list.
  const ModifierArray array{g_matched.data(), static_cast<std::int32_t>(g_matched.size())};
  float factor = 1.0f;
  if (!kModifierSum(nullptr, &factor, &array, kStatBuildingWorkRate) || factor < kMinFactor) {
    return 1.0f;
  }
  return factor;
}

const wchar_t* CallerName(std::uint32_t ret) {
  for (const Caller& caller : kCallers) {
    if (caller.ret == ret) {
      return caller.name;
    }
  }
  for (const RateCaller& caller : kRateCallers) {
    if (caller.ret == ret) {
      return caller.name;
    }
  }
  return L"through g_uhcBwrTrainGetter";
}

// "log": one line when a unit's factor changes, and one when it is back to 1.0.
void LogFactor(const char* unit, float factor, std::uint32_t ret) {
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const std::uint32_t bits = std::bit_cast<std::uint32_t>(factor);
  const auto it = g_logged.find(id);
  if (factor == 1.0f) {
    if (it == g_logged.end()) {
      return;
    }
    g_logged.erase(it);
  } else {
    if (it != g_logged.end() && it->second == bits) {
      return;
    }
    g_logged[id] = bits;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  const char* player = Field<const char*>(unit, 0x44);
  const std::int32_t playerId = player == nullptr ? -1 : Field<std::int32_t>(player, 0);
  if (factor == 1.0f) {
    uhc::Log(L"buildingWorkRateAuras: unit %d (%hs, player %d) works at x1.000 again: no BuildingWorkRate "
             L"modifier left (%ls)",
             id, name == nullptr ? "?" : name, playerId, CallerName(ret));
  } else {
    uhc::Log(L"buildingWorkRateAuras: unit %d (%hs, player %d) works at x%.3f from BuildingWorkRate modifiers "
             L"(%ls)",
             id, name == nullptr ? "?" : name, playerId, static_cast<double>(factor), CallerName(ret));
  }
}

// The getter's first two instructions are stock, or liveBuildingWorkRate's jmp (that key is applied
// before this one and keeps the getter's contract).
bool GetterHeadIsKnown() {
  const uhc::Site& getter = uhc::sites::kBuildingWorkRateGetter;
  const auto* live = reinterpret_cast<const std::uint8_t*>(static_cast<std::uintptr_t>(getter.va));
  if (std::memcmp(live, getter.bytes, 5) == 0) {
    return true;
  }
  std::uint32_t rel = 0;
  std::memcpy(&rel, live + 1, sizeof(rel));
  const std::uint32_t target = getter.va + 5 + rel;
  return live[0] == 0xE9 && target == static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(&UhcBwrGetterHook));
}

}  // namespace

extern "C" {
// The getter that the Train update's call should reach. noTrainNearEnemyTC replaces that call
// (0x9EA410) with a hook that re-executes it; the hook calls through this pointer, which this key
// sets to its wrapper. Same contract as the getter: float thiscall(unit), ECX and EDX kept.
void* g_uhcBwrTrainGetter = reinterpret_cast<void*>(0x009BFE33);

// Called by the wrapper for a unit with a modifier record, with the getter's result and the
// caller's return address. Reads only simulation state.
float __stdcall UhcBwrAuraRate(float base, const char* unit, std::uint32_t ret) {
  const float factor = Factor(unit);
  if (g_log) {
    LogFactor(unit, factor, ret);
  }
  return factor == 1.0f ? base : base * factor;
}

// From the panel's read, with the selected unit: what the unit works at. Display only.
float __stdcall UhcBwrPanelRate(const char* unit) {
  const float base = kGetter(unit);
  if (Field<const char*>(unit, 0xB4) == nullptr || Field<const char*>(Field<const char*>(unit, 0xB4), 0xC8) == nullptr) {
    return base;
  }
  return base * Factor(unit);
}
}

namespace uhc {

Outcome ApplyBuildingWorkRateAuras(const Config& config) {
  const Config::Args* args = config.First("buildingWorkRateAuras");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"buildingWorkRateAuras: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  // The compare the name hook calls, three call sites (the Train one is checked alone below), the
  // getter's tail, and the stock code the factor calls or mirrors. AddModifyType checks the name hook:
  // it may be in place already.
  if (!VerifyAll("buildingWorkRateAuras",
                 {&sites::kModifyTypeNameCompare, &sites::kWorkRateResearchCall,
                  &sites::kWorkRateCommandResearchCall, &sites::kWorkRateMaintainCall, &sites::kBwrTrainCallNext,
                  &sites::kBwrGetterTail, &sites::kSnareCollector, &sites::kSnareModifierSum,
                  &sites::kSnareModifierSumEnd, &sites::kSnareModifierSumTactic, &sites::kBwrGatherRateRecord,
                  &sites::kBwrGatherRateRule, &sites::kCurrentUnitRateRead, &sites::kBwrRateCallHeal,
                  &sites::kBwrRateCallBuild, &sites::kBwrRepairRate})) {
    return Outcome::kFailed;
  }
  if (!GetterHeadIsKnown()) {
    Log(L"buildingWorkRateAuras: the BuildingWorkRate getter at 0x%08X holds neither the stock bytes nor "
        L"liveBuildingWorkRate's hook; feature not applied",
        sites::kBuildingWorkRateGetter.va);
    return Outcome::kFailed;
  }
  // noTrainNearEnemyTC, applied earlier, may own the Train call; its hook then calls the wrapper
  // through g_uhcBwrTrainGetter. The other three calls are redirected either way.
  const bool trainCallStock = Matches(sites::kBwrTrainCall);
  g_log = log;
  if (!AddModifyType(L"BuildingWorkRate", kStatBuildingWorkRate)) {
    return Outcome::kFailed;
  }
  for (const Caller& caller : kCallers) {
    if (caller.call == kTrainCall && !trainCallStock) {
      continue;
    }
    if (!WriteCall(caller.call, reinterpret_cast<const void*>(&UhcBwrAuraCall))) {
      return Outcome::kFailed;
    }
  }
  for (const RateCaller& caller : kRateCallers) {
    if (!WriteCall(caller.call, reinterpret_cast<const void*>(&UhcBwrRateCall))) {
      return Outcome::kFailed;
    }
  }
  g_uhcBwrTrainGetter = reinterpret_cast<void*>(&UhcBwrAuraCall);
  if (!WriteJmp(sites::kBwrRepairRate.va, reinterpret_cast<const void*>(&UhcBwrRepairHook), 7) ||
      !WriteJmp(sites::kCurrentUnitRateRead.va, reinterpret_cast<const void*>(&UhcBwrPanelHook), 6)) {
    return Outcome::kFailed;
  }
  if (!trainCallStock) {
    Log(L"buildingWorkRateAuras: the Train call at 0x%08X is already hooked (noTrainNearEnemyTC); Train speed "
        L"gets the factor only through that hook's call of g_uhcBwrTrainGetter",
        sites::kBwrTrainCall.va);
  }
  Log(L"buildingWorkRateAuras: modifiers with ModifyType BuildingWorkRate (stat 0x%02X) scale train, research, "
      L"Maintain, heal and build speed%ls (multiplayer unverified)",
      kStatBuildingWorkRate, log ? L", every change of a unit's factor logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
