# Code for WoL: Buildings and training

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [liveBuildingWorkRate](#livebuildingworkrate)
- [buildingWorkRateAuras](#buildingworkrateauras)
- [costEscalationTechs](#costescalationtechs)
- [trainBatchSize](#trainbatchsize)
- [sharedBuildLimit](#sharedbuildlimit)
- [doNotQueue](#donotqueue)
- [nextResearchFree](#nextresearchfree)
- [maintainWaitForPop](#maintainwaitforpop)
- [noTrainNearEnemyTC](#notrainnearenemytc)
- [lifespanAfterConstruction](#lifespanafterconstruction)
- [gaiaSocketsOnly](#gaiasocketsonly)
- [hcShipmentPointFallback](#hcshipmentpointfallback)

## liveBuildingWorkRate

Contract: [liveBuildingWorkRate](../porting-to-another-dll.md#livebuildingworkrate).

Sites: `WorkRateMaintainCall` `0x6AB23C` (20 B), `BuildingWorkRateGetter` `0x9BFE33` (21 B), `WorkRateCommandResearchCall` `0x9D58D1` (13 B), `MaintainFrac` `0x9E27E4` (69 B), `MaintainPointsProto` `0x9E28BD` (17 B), `MaintainPointsSet` `0x9E2A05` (61 B), `WorkRateResearchCall` `0x9E65F4` (13 B), `TrainFrac` `0x9EA1FA` (69 B), `WorkRateTrainCall` `0x9EA410` (20 B), `TrainPointsProto` `0x9EAC3D` (41 B), `TrainPointsSet` `0x9EB19F` (67 B).

### src/features/workrate.cpp

```cpp
// liveBuildingWorkRate: train, research and Maintain speed follow the proto's current
// BuildingWorkRate, and the units being trained or spawned follow their current TrainPoints.
//
// Stock keeps a copy of a building's BuildingWorkRate ([proto+D0h]) in its building data
// ([[unit+68h]+28h]), taken once: when the building completes, or when a ForceBuildingData unit is
// created (FUN_006A1F82, and again for completed buildings when a save loads). The getter at
// 0x9BFE33, which the Train, Research, CommandResearch and Maintain updates call on every tick,
// returns that copy. A BuildingWorkRate tech (Data effect, subtype 0x5E) only changes the proto,
// so it reaches the buildings completed after it and never the ones already standing, although
// the stat panel shows the new rate (it reads the proto). The hook in hooks/workrate_hooks.asm
// makes the getter return the proto's value, as stock already does for a unit without building
// data. The copy is still written and saved, so saved games load with or without the key.
//
// TrainPoints (second part). Every queued unit (or batch) is its own Train action, and the
// enqueue (0x9EB19F) stores the trained proto's TrainPoints in the action ([action+64h]) once, when
// the unit is queued; a Maintain cycle stores count x TrainPoints ([action+6Ch]) when it starts
// (0x9E2A05). A TrainPoints tech therefore misses every unit already queued or in training, on old
// and new buildings alike, and the current Maintain cycle. ResearchPoints are read live by stock
// (0x9E5F27). The two fraction functions (Train 0x9EA1FA, Maintain 0x9E27E4) run on every tick of
// their update; their hooks first write the points the stock rule gives now, so the progress (kept
// in points) is measured against the current value, as research progress already is.
#include <bit>
#include <cstdint>
#include <cstring>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// Unit ID -> the (snapshot, proto) rate bits last logged for it, so a unit is logged once per
// change of either value. Only the game thread (the simulation update) touches it. Unit IDs start
// again in every game: a new world, or a step count [world+F8h] that went back, clears it.
std::unordered_map<std::int32_t, std::uint64_t> g_logged;
// (unit ID, trained proto ID) -> the (cached, current) points last logged for that pair.
std::unordered_map<std::uint64_t, std::uint64_t> g_loggedPoints;
const char* g_logWorld = nullptr;
std::uint32_t g_logStep = 0;

using PlayerProtoFn = const char*(__thiscall*)(const char* player, std::int32_t protoId);
using UnitFlagFn = bool(__thiscall*)(const char* unit, std::int32_t flag);
using ProtoByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
// The calls the stock rule makes; the sites TrainPointsProto, TrainPointsSet, MaintainPointsProto
// and MaintainPointsSet hold them and are verified before any write.
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kUnitFlag = reinterpret_cast<UnitFlagFn>(0x0044D063);
const auto kProtoById = reinterpret_cast<ProtoByIdFn>(0x0045316E);
constexpr std::int32_t kForceBaseTrainPoints = 0x9E;  // unit flag YPForceTrainAtBaseTrainPoints

void ForgetOtherGames() {
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const std::uint32_t step = world == nullptr ? 0 : Field<std::uint32_t>(world, 0xF8);
  if (world != g_logWorld || step < g_logStep) {
    g_logged.clear();
    g_loggedPoints.clear();
  }
  g_logWorld = world;
  g_logStep = step;
}

// The points the stock rule gives now for a unit of protoId trained (count 0) or spawned in a
// Maintain cycle of `count` units by `trainer`: the trainer's player's copy of the proto, times the
// count for Maintain; with the trainer's flag YPForceTrainAtBaseTrainPoints, the database's base
// proto, not multiplied (as stock). False when a lookup fails: the caller keeps the stock value.
bool CurrentPoints(const char* trainer, std::int32_t protoId, std::int32_t count, std::uint32_t* bits,
                   const char** name) {
  const char* player = trainer == nullptr ? nullptr : Field<const char*>(trainer, 0x44);
  const char* proto = player == nullptr ? nullptr : kPlayerProto(player, protoId);
  if (proto == nullptr) {
    return false;
  }
  *name = Field<const char*>(proto, 0x10);
  const float points = Field<float>(proto, 0x6C);
  // fild count / fmul points / fstp: the exact product (count is small) rounded once to a float.
  *bits = std::bit_cast<std::uint32_t>(
      count > 0 ? static_cast<float>(static_cast<double>(count) * static_cast<double>(points)) : points);
  if (kUnitFlag(trainer, kForceBaseTrainPoints)) {
    const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
    const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
    const char* base = database == nullptr ? nullptr : kProtoById(database, Field<std::int32_t>(proto, 8));
    if (base != nullptr) {
      *bits = Field<std::uint32_t>(base, 0x6C);
    }
  }
  return true;
}

void LogPoints(const char* trainer, std::int32_t protoId, const char* name, std::uint32_t cached,
               std::uint32_t current, bool maintain) {
  ForgetOtherGames();
  const std::int32_t id = Field<std::int32_t>(trainer, 0x10);
  const std::uint64_t key =
      (static_cast<std::uint64_t>(static_cast<std::uint32_t>(id)) << 32) | static_cast<std::uint32_t>(protoId);
  const std::uint64_t pair = (static_cast<std::uint64_t>(cached) << 32) | current;
  const auto [it, added] = g_loggedPoints.try_emplace(key, pair);
  if (!added) {
    if (it->second == pair) {
      return;
    }
    it->second = pair;
  }
  const char* trainerProto = Field<const char*>(trainer, 0x5C);
  const char* trainerName = trainerProto == nullptr ? nullptr : Field<const char*>(trainerProto, 0x10);
  const char* player = Field<const char*>(trainer, 0x44);
  uhc::Log(maintain ? L"liveBuildingWorkRate: unit %d (%hs, player %d) spawns %hs at %.3f points per cycle, "
                      L"not the %.3f its cycle started with"
                    : L"liveBuildingWorkRate: unit %d (%hs, player %d) trains %hs at TrainPoints %.3f, not "
                      L"the %.3f it was queued with",
           id, trainerName == nullptr ? "?" : trainerName, player == nullptr ? -1 : Field<std::int32_t>(player, 0),
           name == nullptr ? "?" : name, static_cast<double>(std::bit_cast<float>(current)),
           static_cast<double>(std::bit_cast<float>(cached)));
}

}  // namespace

extern "C" {
std::int32_t g_uhcBwrLog = 0;  // 1 with "liveBuildingWorkRate log"

void UhcBwrGetterHook();
void UhcTrainFracHook();
void UhcMaintainFracHook();

// Called by the Train fraction hook with the Train action: the first entry's proto ([[a+70h]],
// entry count [a+74h]), the trainer [a+10h], and the points [a+64h] the enqueue stored.
void __stdcall UhcTrainPointsRefresh(char* action) {
  const std::int32_t* entries = Field<const std::int32_t*>(action, 0x70);
  if (Field<std::int32_t>(action, 0x74) <= 0 || entries == nullptr) {
    return;
  }
  const char* trainer = Field<const char*>(action, 0x10);
  std::uint32_t current = 0;
  const char* name = nullptr;
  if (!CurrentPoints(trainer, entries[0], 0, &current, &name)) {
    return;
  }
  const std::uint32_t cached = Field<std::uint32_t>(action, 0x64);
  if (cached == current) {
    return;
  }
  *reinterpret_cast<std::uint32_t*>(action + 0x64) = current;
  if (g_uhcBwrLog != 0) {
    LogPoints(trainer, entries[0], name, cached, current, false);
  }
}

// Called by the Maintain fraction hook with the Maintain action: proto ID [a+64h], unit count
// [a+68h], trainer [a+10h], and the cycle's points [a+6Ch] its start stored.
void __stdcall UhcMaintainPointsRefresh(char* action) {
  const char* trainer = Field<const char*>(action, 0x10);
  const std::int32_t protoId = Field<std::int32_t>(action, 0x64);
  const std::int32_t count = Field<std::int32_t>(action, 0x68);
  std::uint32_t current = 0;
  const char* name = nullptr;
  // With a count of 0 stock stores 0 points (the cycle is done at once); leave that alone.
  if (count <= 0 || !CurrentPoints(trainer, protoId, count, &current, &name)) {
    return;
  }
  const std::uint32_t cached = Field<std::uint32_t>(action, 0x6C);
  if (cached == current) {
    return;
  }
  *reinterpret_cast<std::uint32_t*>(action + 0x6C) = current;
  if (g_uhcBwrLog != 0) {
    LogPoints(trainer, protoId, name, cached, current, true);
  }
}

// Called by the getter hook (only with log) with ECX's unit: logs a unit whose snapshot differs
// from its proto's current rate, i.e. one whose speed this feature changes.
void __stdcall UhcBwrLogUnit(const char* unit) {
  const char* data = Field<const char*>(unit, 0x68);
  const char* proto = Field<const char*>(unit, 0x5C);
  if (data == nullptr || proto == nullptr) {
    return;
  }
  const std::uint32_t snapshot = Field<std::uint32_t>(data, 0x28);
  const std::uint32_t live = Field<std::uint32_t>(proto, 0xD0);
  if (snapshot == live) {
    return;
  }
  ForgetOtherGames();
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const std::uint64_t pair = (static_cast<std::uint64_t>(snapshot) << 32) | live;
  const auto [it, added] = g_logged.try_emplace(id, pair);
  if (!added) {
    if (it->second == pair) {
      return;
    }
    it->second = pair;
  }
  const char* name = Field<const char*>(proto, 0x10);
  const char* player = Field<const char*>(unit, 0x44);
  uhc::Log(L"liveBuildingWorkRate: unit %d (%hs, player %d) works at BuildingWorkRate %.3f, not its "
           L"snapshot %.3f",
           id, name == nullptr ? "?" : name, player == nullptr ? -1 : Field<std::int32_t>(player, 0),
           static_cast<double>(std::bit_cast<float>(live)), static_cast<double>(std::bit_cast<float>(snapshot)));
}
}

namespace uhc {

Outcome ApplyLiveBuildingWorkRate(const Config& config) {
  const Config::Args* args = config.First("liveBuildingWorkRate");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"liveBuildingWorkRate: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("liveBuildingWorkRate",
                 {&sites::kBuildingWorkRateGetter, &sites::kWorkRateTrainCall, &sites::kWorkRateResearchCall,
                  &sites::kWorkRateCommandResearchCall, &sites::kWorkRateMaintainCall, &sites::kTrainFrac,
                  &sites::kTrainPointsProto, &sites::kTrainPointsSet, &sites::kMaintainFrac,
                  &sites::kMaintainPointsProto, &sites::kMaintainPointsSet})) {
    return Outcome::kFailed;
  }
  g_uhcBwrLog = log ? 1 : 0;
  if (!WriteJmp(sites::kBuildingWorkRateGetter.va, reinterpret_cast<const void*>(&UhcBwrGetterHook), 5) ||
      !WriteJmp(sites::kTrainFrac.va, reinterpret_cast<const void*>(&UhcTrainFracHook), 9) ||
      !WriteJmp(sites::kMaintainFrac.va, reinterpret_cast<const void*>(&UhcMaintainFracHook), 9)) {
    return Outcome::kFailed;
  }
  Log(L"liveBuildingWorkRate: train, research and Maintain speed follow the proto's current "
      L"BuildingWorkRate, and queued, training and Maintain units their current TrainPoints%ls "
      L"(multiplayer unverified)",
      log ? L", every building and unit it changes logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/workrate_hooks.asm

```asm
; Hooks for liveBuildingWorkRate.
; - The BuildingWorkRate getter: entered through a jmp written over its first two instructions;
;   leaves through an explicit jmp to the getter's own tail (docs/engine-symbols.md, "Building
;   work rate").
; - TrainPoints: the Train and Maintain fraction functions, entered through a jmp written over
;   their first two instructions (fld / fcomp); each refreshes the action's cached points, then
;   re-executes the two instructions and continues in the stock function (docs/engine-symbols.md,
;   "Train points").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcBwrLog:SDWORD        ; 1 with "liveBuildingWorkRate log", else 0

UhcBwrLogUnit PROTO STDCALL unit:DWORD
UhcTrainPointsRefresh PROTO STDCALL action:DWORD
UhcMaintainPointsRefresh PROTO STDCALL action:DWORD

.data
bwrTail         dd 009BFE3Eh    ; mov eax,[ecx+5Ch] / fld dword ptr [eax+0D0h] / ret: the proto's rate
trainFracNext   dd 009EA203h    ; fnstsw ax, after fld [ecx+64h] / fcomp [0C3755Ch]
maintainFracNext dd 009E27EDh   ; fnstsw ax, after fld [ecx+6Ch] / fcomp [0C37468h]

.code

; Replaces 0x9BFE33..0x9BFE37 (mov eax,[ecx+68h] / test eax,eax) in the getter, float
; thiscall(unit), whose next instruction (je 9BFE3Eh) chose between the building data's snapshot
; [[ecx+68h]+28h] and the proto's current rate [[ecx+5Ch]+0D0h]. ECX = the unit and the x87
; stack is empty (the callers are compiled calls). The hook always takes the proto's rate. It
; re-executes the two stolen instructions last, so EFLAGS are the ones stock returns with; EAX
; returns as the tail leaves it (the proto, not the building data), which all four callers
; overwrite before reading. Every other register, ESP and the x87 stack depth are as in stock.
UhcBwrGetterHook PROC
    TRACE_ONCE "liveBuildingWorkRate (0x9BFE33)"
    cmp g_uhcBwrLog, 0
    je live
    pushad
    push ecx
    call UhcBwrLogUnit              ; logs the unit if its snapshot differs from the proto's rate
    popad
live:
    mov eax, dword ptr [ecx+68h]    ; stolen 0x9BFE33 (building data), for the flags
    test eax, eax                   ; stolen 0x9BFE36
    jmp bwrTail
UhcBwrGetterHook ENDP

; Replaces 0x9EA1FA..0x9EA202 (fld dword ptr [ecx+64h] / fcomp dword ptr [0C3755Ch]), the head of
; the Train fraction function, void thiscall(action), frac [ecx+6Ch] = progress [ecx+68h] /
; points [ecx+64h]. Its only caller is the Train update (0x9EA4B3), with an empty x87 stack.
; UhcTrainPointsRefresh writes the current TrainPoints into [ecx+64h] (stock took them once, when
; the unit was queued). pushad / popad keep every register; the two stolen instructions run after
; it, so the x87 stack and the FPU status are the ones stock has at 0x9EA203, whose fnstsw / test
; set the flags again. Every register, ESP and the return address are as in stock.
UhcTrainFracHook PROC
    TRACE_ONCE "liveBuildingWorkRate TrainPoints (0x9EA1FA)"
    pushad
    push ecx
    call UhcTrainPointsRefresh      ; [ecx+64h] = the current TrainPoints, when they differ
    popad
    fld dword ptr [ecx+64h]         ; stolen 0x9EA1FA
    fcomp dword ptr ds:[00C3755Ch]  ; stolen 0x9EA1FD (1e-6)
    jmp trainFracNext
UhcTrainFracHook ENDP

; Replaces 0x9E27E4..0x9E27EC (fld dword ptr [ecx+6Ch] / fcomp dword ptr [0C37468h]), the head of
; the Maintain fraction function, [ecx+74h] = [ecx+70h] / [ecx+6Ch], called only by the Maintain
; update (0x6AB264). Same contract as UhcTrainFracHook; UhcMaintainPointsRefresh writes the cycle's
; current points into [ecx+6Ch] (stock took them when the cycle started).
UhcMaintainFracHook PROC
    TRACE_ONCE "liveBuildingWorkRate Maintain TrainPoints (0x9E27E4)"
    pushad
    push ecx
    call UhcMaintainPointsRefresh   ; [ecx+6Ch] = the cycle's current points, when they differ
    popad
    fld dword ptr [ecx+6Ch]         ; stolen 0x9E27E4
    fcomp dword ptr ds:[00C37468h]  ; stolen 0x9E27E7
    jmp maintainFracNext
UhcMaintainFracHook ENDP

END
```

## buildingWorkRateAuras

Contract: [buildingWorkRateAuras](../porting-to-another-dll.md#buildingworkrateauras).

Besides the core helpers, it needs: [`modifiers.h`](helpers.md#modifier-walk), [`modifytypes.h`](helpers.md#modify-types).

Sites: `ModifyTypeNameCompare` `0x443C10` (16 B), `SnareCollector` `0x49F34B` (121 B), `SnareModifierSum` `0x4B3C48` (183 B), `SnareModifierSumEnd` `0x4E2A8E` (27 B), `BwrGatherRateRecord` `0x4ECFE9` (20 B), `BwrGatherRateRule` `0x69FE53` (28 B), `SnareModifierSumTactic` `0x6A88D6` (34 B), `WorkRateMaintainCall` `0x6AB23C` (20 B), `BuildingWorkRateGetter` `0x9BFE33` (21 B), `BwrGetterTail` `0x9BFE38` (16 B), `WorkRateCommandResearchCall` `0x9D58D1` (13 B), `WorkRateResearchCall` `0x9E65F4` (13 B), `BwrTrainCall` `0x9EA410` (8 B), `BwrTrainCallNext` `0x9EA418` (12 B).

### src/features/bwrauras.cpp

```cpp
// buildingWorkRateAuras: an aura (or any other stat modifier) whose ModifyType is BuildingWorkRate
// changes how fast the units it reaches train, research and spawn their Maintain units.
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
// key: the factor then multiplies the proto's live rate. The hooks are in hooks/bwraura_hooks.asm.
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
void UhcBwrGetterHook();  // liveBuildingWorkRate's getter hook (hooks/workrate_hooks.asm)
}

namespace {

// Engine layout (docs/engine-symbols.md, "Building work rate auras").
constexpr std::int32_t kStatBuildingWorkRate = 0x40;  // the new ModifyType stat, as in bwraura_hooks.asm
constexpr float kMinFactor = 1.0e-6f;  // 0xB9FB64: a smaller sum counts as no modifier (0x69FE56)
constexpr std::uint32_t kTrainCall = 0x009EA413;     // call 9BFE33h in the Train update

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
                  &sites::kBwrGatherRateRule})) {
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
  g_uhcBwrTrainGetter = reinterpret_cast<void*>(&UhcBwrAuraCall);
  if (!trainCallStock) {
    Log(L"buildingWorkRateAuras: the Train call at 0x%08X is already hooked (noTrainNearEnemyTC); Train speed "
        L"gets the factor only through that hook's call of g_uhcBwrTrainGetter",
        sites::kBwrTrainCall.va);
  }
  Log(L"buildingWorkRateAuras: modifiers with ModifyType BuildingWorkRate (stat 0x%02X) scale train, research "
      L"and Maintain speed%ls (multiplayer unverified)",
      kStatBuildingWorkRate, log ? L", every change of a unit's factor logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/bwraura_hooks.asm

```asm
; Hooks for buildingWorkRateAuras. The rate wrapper is the target of the redirected calls of the BuildingWorkRate getter and returns to its caller
; (docs/engine-symbols.md, "Building work rate auras").
.686
.model flat, c
option casemap :none

include common.inc

UhcBwrAuraRate PROTO STDCALL base:DWORD, unit:DWORD, caller:DWORD

kStatBuildingWorkRate EQU 40h       ; the new ModifyType stat; bwrauras.cpp uses the same value

.data
workRateGetter  dd 009BFE33h    ; float thiscall(unit): the BuildingWorkRate getter (liveBuildingWorkRate may hook it)

.code

; Target of the calls of the getter at 0x9EA413 (Train), 0x9E65F7 (Research), 0x9D58D4
; (CommandResearch) and 0x6AB23F (Maintain), whose rel32 is redirected here, and of
; g_uhcBwrTrainGetter. Same contract as the getter, float thiscall(unit): ECX = the unit (the
; callers' mov ecx,[esi+10h]), x87 stack empty, [esp] = the return address into the caller.
; Returns ST0 = the rate, with ECX, EDX, EBX, ESI, EDI and EBP unchanged; EAX and the flags differ
; from stock, which the four callers allow (each writes EAX before reading it and calls a function
; before reading the flags). A unit without a modifier record ([[ecx+0B4h]+0C8h], created with its
; first modifier) tail-calls the getter, exactly the stock call. Any other unit gets the getter's
; rate times its BuildingWorkRate factor.
UhcBwrAuraCall PROC
    TRACE_ONCE "buildingWorkRateAuras (calls of 0x9BFE33)"
    mov eax, dword ptr [ecx+0B4h]   ; the unit's extension
    test eax, eax
    je stock
    cmp dword ptr [eax+0C8h], 0     ; its modifier record
    je stock
    TRACE_ONCE "buildingWorkRateAuras: a unit with modifiers (calls of 0x9BFE33)"
    push ecx
    push edx
    push dword ptr [esp+8]          ; caller: the return address, for the log
    push ecx                        ; unit
    call workRateGetter             ; ST0 = the stock rate; ECX is still the unit
    sub esp, 4
    fstp dword ptr [esp]            ; base: the getter's float (an fld of a float, so exact)
    call UhcBwrAuraRate             ; -> ST0 = base x factor; pops its three arguments
    pop edx
    pop ecx
    ret
stock:
    jmp workRateGetter              ; no modifier record: the stock call
UhcBwrAuraCall ENDP

END
```

## costEscalationTechs

Contract: [costEscalationTechs](../porting-to-another-dll.md#costescalationtechs).

Besides the core helpers, it needs: [`techsubtypes.h`](helpers.md#tech-subtypes).

### src/features/costescalation.cpp

```cpp
// costEscalationTechs: a tech effect type="Data" subtype="CostEscalation" changes a proto's
// <CostEscalation>.
//
// Stock keeps the tag in the proto's [+78h], default 1. The cost getter 0x480B1E reads it from the
// player's copy on every call: when it is not 1, each cost is multiplied by it (N + count - 1) times,
// N being the count of that proto the player has. No Data subtype reaches the field, so the effect
// is a new one (techsubtypes.h), applied through the stock value function 0x7F892A, which gives it
// every relativity and its removal.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../log.h"
#include "../techsubtypes.h"

namespace {

constexpr std::size_t kEscalation = 0x78;
constexpr int kMaxLogLines = 200;

using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);

bool g_log = false;
int g_logLines = 0;

void ChangeEscalation(char* proto, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  auto* value = reinterpret_cast<float*>(proto + kEscalation);
  const float before = *value;
  kEffectValue(relativity, value, *reinterpret_cast<const float*>(base + kEscalation), amount, unapply);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"costEscalationTechs: proto %d, relativity %u, amount %g%ls: %g -> %g",
             *reinterpret_cast<const std::int32_t*>(proto + 8), relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", static_cast<double>(before), static_cast<double>(*value));
  }
}

}  // namespace

namespace uhc {

Outcome ApplyCostEscalationTechs(const Config& config) {
  const Config::Args* args = config.First("costEscalationTechs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"costEscalationTechs: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!AddTechSubtype("CostEscalation", &ChangeEscalation)) {
    return Outcome::kFailed;
  }
  Log(L"costEscalationTechs: the Data subtype CostEscalation is on");
  return Outcome::kApplied;
}

}  // namespace uhc
```

## trainBatchSize

Contract: [trainBatchSize](../porting-to-another-dll.md#trainbatchsize).

Besides the core helpers, it needs: [`prototags.h`](helpers.md#proto-tags), [`techsubtypes.h`](helpers.md#tech-subtypes), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `TrainQueueCall1` `0x7560B5` (5 B), `TrainQueueCall2` `0x7CAF6E` (5 B), `TrainQueueCall3` `0x7D797A` (5 B), `TrainBatchLimitCall` `0x9CE645` (5 B), `TrainBatchProtoArg` `0x9CE6DE` (4 B), `TrainQueueCall4` `0x9EBF03` (5 B).

### src/features/trainbatch.cpp

```cpp
// trainBatchSize: <TrainBatchSize>N</TrainBatchSize> in a proto limits how many of it share one Train
// action. <DontTrainInBatches>1</DontTrainInBatches> is a size of 1 (an explicit size wins), and
// <ForceBatchTrain> is read and does nothing: the trains it changes elsewhere do not exist here.
// The tech effect type="Data" subtype="TrainBatchSize" changes the size for one player's copy of the
// proto (base: the tag's size, or the stock 5), through the stock value function 0x7F892A; the hook
// forwards the player, whose copy 0x45311B finds.
//
// Stock takes the limit from one call, 0x8D051B (0x9CE645, in the routine that queues units in a
// building): the player's [+2ACh] when a tech set it, else the database's default of [+178h]. The routine
// then fills the last Train action up to the limit and opens a new one for the rest. The hook keeps that
// call and replaces its result for a proto with the tag.
//
// The new action takes all that remains, whatever the limit, so a Shift+click of 5 is one action of 5.
// So the routine's four calls go through a wrapper that asks for more than the tag allows in pieces of
// that size, and each piece is queued and paid by the stock routine. Values are read once, kept by proto
// ID, and are the same for every player. The hook is in hooks/trainbatch_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

extern "C" void UhcTrainBatchHook();

namespace {

constexpr std::uint32_t kLimitCall = 0x009CE645;
constexpr std::uint32_t kQueueCalls[] = {0x007560B5, 0x007CAF6E, 0x007D797A, 0x009EBF03};
constexpr int kMaxLogLines = 200;

using QueueFn = bool(__thiscall*)(void* building, std::int32_t a, std::int32_t b, std::int32_t proto,
                                  std::int32_t count, std::int32_t c, std::int32_t d, std::int32_t e);
const auto kQueue = reinterpret_cast<QueueFn>(0x009CE2BE);
using PlayerProtoFn = const char*(__thiscall*)(const char* player, std::int32_t id);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
constexpr float kStockDefault = 5.0f;

std::unordered_map<std::int32_t, std::int32_t> g_sizes;  // filled while protos load, read-only after
std::unordered_map<std::int32_t, bool> g_explicit;        // protos whose size came from <TrainBatchSize>
struct TechSize {
  std::int32_t id;  // the proto ID the copy had: a reused pointer with another ID is ignored
  float value;
};
std::unordered_map<const char*, TechSize> g_techSizes;  // by the player's copy of the proto
bool g_log = false;
int g_logLines = 0;

// The size for a player's copy: the tech's, else the tag's, else none (-1).
std::int32_t SizeFor(const char* copy, std::int32_t id) {
  if (copy != nullptr && !g_techSizes.empty()) {
    const auto tech = g_techSizes.find(copy);
    if (tech != g_techSizes.end() && tech->second.id == id) {
      const long value = std::lround(tech->second.value);
      return value < 1 ? 1 : static_cast<std::int32_t>(value);
    }
  }
  const auto found = g_sizes.find(id);
  return found == g_sizes.end() ? -1 : found->second;
}

void ChangeSize(char* proto, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 8);
  const auto tag = g_sizes.find(*reinterpret_cast<const std::int32_t*>(base + 8));
  const float baseValue = tag == g_sizes.end() ? kStockDefault : static_cast<float>(tag->second);
  auto inserted = g_techSizes.emplace(proto, TechSize{id, baseValue});
  if (inserted.first->second.id != id) {
    inserted.first->second = TechSize{id, baseValue};  // the pointer was another proto's copy before
  }
  float& value = inserted.first->second.value;
  const float before = value;
  kEffectValue(relativity, &value, baseValue, amount, unapply);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"trainBatchSize: proto %d, tech subtype TrainBatchSize, relativity %u, amount %g%ls: %g -> %g", id,
             relativity, static_cast<double>(amount), unapply ? L" (removed)" : L"", static_cast<double>(before),
             static_cast<double>(value));
  }
}

void ForgetOnDataLoad(char*) { g_techSizes.clear(); }

// A flag written as an element: absent text or anything but 0 is on.
bool FlagOn(const char* node) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  return text == nullptr || text[0] == L'\0' || _wtoi(text) != 0;
}

bool __cdecl ReadTrainBatchSize(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  const int size = text != nullptr ? _wtoi(text) : 0;
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 8);
  if (size < 1) {
    uhc::Log(L"trainBatchSize: proto %d: <TrainBatchSize> needs a number from 1, ignored", id);
    return true;
  }
  g_sizes[id] = size;
  g_explicit[id] = true;
  if (g_log) {
    uhc::Log(L"trainBatchSize: proto %d has %d", id, size);
  }
  return true;
}

bool __cdecl ReadDontTrainInBatches(void*, const char* node, char* proto) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 8);
  if (!FlagOn(node)) {
    return true;
  }
  if (g_explicit.count(id) == 0) {
    g_sizes[id] = 1;
  }
  if (g_log) {
    uhc::Log(L"trainBatchSize: proto %d has DontTrainInBatches: one per action%ls", id,
             g_explicit.count(id) == 0 ? L"" : L" (its TrainBatchSize wins)");
  }
  return true;
}

bool __cdecl ReadForceBatchTrain(void*, const char* node, char* proto) {
  if (g_log && FlagOn(node)) {
    uhc::Log(L"trainBatchSize: proto %d has ForceBatchTrain, which changes nothing in this engine",
             *reinterpret_cast<const std::int32_t*>(proto + 8));
  }
  return true;
}

// Replaces the calls of the queue routine.
bool __fastcall Queue(void* building, void*, std::int32_t a, std::int32_t b, std::int32_t proto, std::int32_t count,
                      std::int32_t c, std::int32_t d, std::int32_t e) {
  // `building` is the unit's action manager: [+4] its unit, and [unit+44h] the player (0x9CE63F..0x9CE642).
  const char* unit = building == nullptr ? nullptr
                                         : *reinterpret_cast<const char* const*>(reinterpret_cast<const char*>(building) + 4);
  const char* player = unit == nullptr ? nullptr : *reinterpret_cast<const char* const*>(unit + 0x44);
  const std::int32_t size = SizeFor(player == nullptr ? nullptr : kPlayerProto(player, proto), proto);
  if (size < 1 || count <= size) {
    return kQueue(building, a, b, proto, count, c, d, e);
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"trainBatchSize: proto %d: %d asked, in pieces of %d", proto, count, size);
  }
  bool queued = false;
  for (std::int32_t left = count; left > 0; left -= size) {
    if (!kQueue(building, a, b, proto, left < size ? left : size, c, d, e)) {
      break;
    }
    queued = true;
  }
  return queued;
}

}  // namespace

// From the hook, with the stock limit, the proto being queued and the player.
extern "C" std::int32_t __stdcall UhcTrainBatchLimit(std::int32_t stock, std::int32_t proto, const char* player) {
  const std::int32_t size = SizeFor(player == nullptr ? nullptr : kPlayerProto(player, proto), proto);
  if (size < 1) {
    return stock;
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"trainBatchSize: proto %d queues up to %d per action (stock %d)", proto, size, stock);
  }
  return size;
}

namespace uhc {

Outcome ApplyTrainBatchSize(const Config& config) {
  const Config::Args* args = config.First("trainBatchSize");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"trainBatchSize: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("trainBatchSize", {&sites::kTrainBatchLimitCall, &sites::kTrainBatchProtoArg, &sites::kTrainQueueCall1,
                                    &sites::kTrainQueueCall2, &sites::kTrainQueueCall3, &sites::kTrainQueueCall4}) ||
      !AddProtoTagHandler("TrainBatchSize", &ReadTrainBatchSize) ||
      !AddProtoTagHandler("DontTrainInBatches", &ReadDontTrainInBatches) ||
      !AddProtoTagHandler("ForceBatchTrain", &ReadForceBatchTrain) ||
      !AddTechSubtype("TrainBatchSize", &ChangeSize) || !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !WriteJmp(kLimitCall, reinterpret_cast<const void*>(&UhcTrainBatchHook), 5)) {
    return Outcome::kFailed;
  }
  for (const std::uint32_t call : kQueueCalls) {
    if (!WriteCall(call, reinterpret_cast<const void*>(&Queue))) {
      return Outcome::kFailed;
    }
  }
  Log(L"trainBatchSize: the proto tags TrainBatchSize, DontTrainInBatches and ForceBatchTrain are on, and the Data "
      L"subtype TrainBatchSize");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/trainbatch_hooks.asm

```asm
; trainBatchSize (src/features/trainbatch.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcTrainBatchLimit PROTO STDCALL stockLimit:DWORD, protoId:DWORD, player:DWORD

.data
stockLimitFn    dd 008D051Bh    ; the limit of units per Train action, thiscall(player)
limitCallNext   dd 009CE64Ah    ; cmp bl,1 / mov ebp,eax

.code

; Replaces 0x9CE645 (call 0x8D051B) in the routine that queues units in a building. ECX = the player,
; [esp+30h] = the proto ID, as the routine reads it at 0x9CE6DE. The code that follows reads only EAX
; of what the call leaves (EDX is free).
UhcTrainBatchHook PROC
    TRACE_ONCE "trainBatchSize limit (0x9CE645)"
    push ecx                        ; the player, for the tech subtype's copy
    call stockLimitFn
    pop edx
    mov ecx, dword ptr [esp+30h]
    invoke UhcTrainBatchLimit, eax, ecx, edx
    jmp limitCallNext
UhcTrainBatchHook ENDP

END
```

## sharedBuildLimit

Contract: [sharedBuildLimit](../porting-to-another-dll.md#sharedbuildlimit).

Besides the core helpers, it needs: [`civtags.h`](helpers.md#civ-tags), [`prototags.h`](helpers.md#proto-tags), [`techsubtypes.h`](helpers.md#tech-subtypes), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `XmlText` `0x402733` (9 B), `PlayerProtoEntry` `0x45311B` (8 B), `ProtoById` `0x45316E` (30 B), `BuildLimitEntry` `0x4C7B5F` (5 B), `BuildCountEntry` `0x4C7BC5` (8 B), `BuildCountTooltip1` `0x4C8B81` (5 B), `XmlAttribute` `0x598F37` (16 B), `BuildCountTooltip2` `0x70F5EF` (5 B).

### src/features/sharedlimit.cpp

```cpp
// sharedBuildLimit: a proto's build limit may be shared with other units.
//
//   <SharedBuildLimitUnit>Name</SharedBuildLimitUnit>             whose limit applies (default: its own)
//   <SharedBuildLimitUnitType weight="N">Type</SharedBuildLimitUnitType>   what counts toward it: an
//                                                                 abstract type or a proto; repeatable
//   <TeamBuildLimit>1</TeamBuildLimit>                            the whole team counts
//   <UseSharedBuildLimit>1</UseSharedBuildLimit>                  accepted; the lists alone are enough
//   <SharedBuildLimitUnitTypes weight="N">Type</SharedBuildLimitUnitTypes>   the same list, plural
//   <SettlerBuildLimit>1</SettlerBuildLimit>                      the limit of the civ's settler, shared by
//                                                                 every unit of LogicalTypeSettlerBuildLimit;
//                                                                 the civ names it in civs.xml:
//                                                                 <SettlerProtoName>Settler</SettlerProtoName>
//
// Stock compares two numbers everywhere: a count of the proto, by many routes, and the limit, always
// from 0x4C7B5F (50 callers: the buttons, the train action, Maintain, cards, the AI). So the count stays
// and the hook changes only the limit: for a tagged proto it returns the room the other units leave,
// (limit - the others' weight) / its own weight, never below 0, because a negative limit means none.
// Every check then gives the right answer, and a batch that does not fit is cut as stock cuts it. The
// others are counted by 0x4C7BC5 with the arguments of the train check, so queued units count.
// The two tooltips that print "Build Limit: N out of M" are the exception: they get the group's total
// and the real limit, through their own count calls and the return address of their limit calls.
// The tags are read once and are the same for every player; the limit comes from the player's copy
// of the proto, so techs reach it. A tech effect type="Data" subtype="EnableSharedBuildLimit" with
// amount 0 turns the share off for that player's copy (the proto keeps its own limit), anything else
// on; base 1. The hook is in hooks/sharedlimit_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "../civtags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

extern "C" {
void UhcSharedLimitHook();
void UhcSharedLimitStock();  // the stock entry: thiscall(player, proto), ret 4
}

namespace {

constexpr std::uint32_t kLimitEntry = 0x004C7B5F;
constexpr std::uint32_t kTooltipCounts[] = {0x004C8B81, 0x0070F5EF};
// After the calls of the limit in the two tooltips.
constexpr std::uint32_t kTooltipLimits[] = {0x004C8B46, 0x004C8B9E, 0x004C8BC4, 0x0070F5D5, 0x0070F60C, 0x0070F628};
constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr int kMaxLogLines = 200;
constexpr int kMaxPlayers = 16;

using LimitFn = std::int32_t(__thiscall*)(const char* player, const char* proto);
using CountFn = std::int32_t(__thiscall*)(const char* proto, std::int32_t player, bool first, bool second);
using PlayerProtoFn = const char*(__thiscall*)(const char* player, std::int32_t id);
using ProtoByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);

const auto kCount = reinterpret_cast<CountFn>(0x004C7BC5);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kProtoById = reinterpret_cast<ProtoByIdFn>(0x0045316E);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);

struct Listed {
  std::string name;
  std::int32_t weight;
};

struct Share {
  std::string limitUnit;       // empty: the proto's own limit
  std::vector<Listed> listed;  // as the data has them
  bool team = false;
  bool use = false;            // <UseSharedBuildLimit>, read and kept for the log
  bool settler = false;        // <SettlerBuildLimit>
  bool built = false;
  std::int32_t limitProto = -1;
  std::int32_t ownWeight = 1;
  std::vector<std::pair<std::int32_t, std::int32_t>> members;  // proto ID, weight
  std::int32_t lastLogged = -2;
};

std::unordered_map<std::int32_t, Share> g_shares;  // by proto ID; the load fills it
std::vector<bool> g_tagged;                        // by proto ID, for the calls of every other proto
bool g_log = false;
int g_logLines = 0;

// <SettlerProtoName> per civ, from civs.xml; the proto is resolved by name on first use and again
// when the database's proto table changes (a data reload).
struct SettlerCiv {
  std::string name;
  const char* table = nullptr;
  std::int32_t proto = -1;
};
std::vector<SettlerCiv> g_settlerCivs;  // by civ ID
std::int32_t g_settlerType = -1;        // LogicalTypeSettlerBuildLimit

bool FlagOn(const char* text) { return text == nullptr || text[0] == 0 || std::atoi(text) != 0; }

using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
struct Enabled {
  std::int32_t id;  // the proto ID the copy had: a reused pointer with another ID is ignored
  float value;      // 0 turns the share off
};
std::unordered_map<const char*, Enabled> g_enabled;  // by the player's copy

void ChangeEnabled(char* proto, const char*, float amount, std::uint8_t relativity, bool unapply) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 4);
  Enabled& slot = g_enabled.emplace(proto, Enabled{id, 1.0f}).first->second;
  if (slot.id != id) {
    slot = Enabled{id, 1.0f};
  }
  float& value = slot.value;
  const float before = value;
  kEffectValue(relativity, &value, 1.0f, amount, unapply);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"sharedBuildLimit: proto %d, tech subtype EnableSharedBuildLimit, relativity %u, amount %g%ls: %g -> %g",
             *reinterpret_cast<const std::int32_t*>(proto + 4), relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"",
             static_cast<double>(before), static_cast<double>(value));
  }
}

void ForgetOnDataLoad(char*) { g_enabled.clear(); }

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

Share& ShareOf(const char* proto) {
  const std::int32_t id = Field<std::int32_t>(proto, 4);
  if (id >= 0) {
    if (g_tagged.size() <= static_cast<std::size_t>(id)) {
      g_tagged.resize(static_cast<std::size_t>(id) + 1, false);
    }
    g_tagged[static_cast<std::size_t>(id)] = true;
  }
  return g_shares[id];
}

const char* TagText(const char* node) { return kXmlText(node + 0x14); }

bool __cdecl ReadLimitUnit(void*, const char* node, char* proto) {
  const char* text = TagText(node);
  if (text != nullptr) {
    ShareOf(proto).limitUnit = text;
  }
  return true;
}

bool __cdecl ReadUnitType(void*, const char* node, char* proto) {
  const char* text = TagText(node);
  if (text == nullptr) {
    return true;
  }
  std::int32_t weight = 1;
  const void* value = nullptr;
  if (kXmlAttribute(node, "weight", &value) && value != nullptr) {
    const char* digits = kXmlText(value);
    if (digits != nullptr && std::atoi(digits) > 0) {
      weight = std::atoi(digits);
    }
  }
  ShareOf(proto).listed.push_back({text, weight});
  return true;
}

bool __cdecl ReadTeam(void*, const char* node, char* proto) {
  const char* text = TagText(node);
  ShareOf(proto).team = text == nullptr || std::atoi(text) != 0;
  return true;
}

bool __cdecl ReadUse(void*, const char* node, char* proto) {
  ShareOf(proto).use = FlagOn(TagText(node));
  return true;
}

bool __cdecl ReadSettler(void*, const char* node, char* proto) {
  ShareOf(proto).settler = FlagOn(TagText(node));
  return true;
}

void ReadSettlerProtoName(const char* civ, std::int32_t civId, const wchar_t* text) {
  if (civId >= static_cast<std::int32_t>(g_settlerCivs.size())) {
    g_settlerCivs.resize(civId + 1);
  }
  std::string name;
  for (const wchar_t* c = text; c != nullptr && *c != 0; ++c) {
    name.push_back(static_cast<char>(*c));
  }
  g_settlerCivs[civId] = SettlerCiv{name};
  const char* civName = civ == nullptr ? nullptr : Field<const char*>(civ, 0x04);
  uhc::Log(L"sharedBuildLimit: civ %d (%hs): its settler is %hs (SettlerProtoName)", civId,
           civName == nullptr ? "?" : civName, name.c_str());
}

const char* Database() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

const char* World() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

// A proto or an abstract type by name, through the table <UnitType> reads; -1 if absent.
std::int32_t NameId(const char* database, const std::string& name) {
  const char* table = database + 0x190;
  std::int32_t id = -1;
  const std::int32_t bucket = kNameBucket(table, name.c_str());
  return kNameFind(table, name.c_str(), bucket, &id) ? id : -1;
}

// A player's civ ID (0x4539D3): [[player+20h]] when [player+24h] > 0, else -1.
std::int32_t CivIdOf(const char* player) {
  return Field<std::int32_t>(player, 0x24) > 0 ? *Field<const std::int32_t*>(player, 0x20) : -1;
}

// The <SettlerProtoName> proto of the player's civ, or -1.
std::int32_t SettlerProtoOf(const char* player, const char* database) {
  const std::int32_t civ = CivIdOf(player);
  if (civ < 0 || civ >= static_cast<std::int32_t>(g_settlerCivs.size()) || g_settlerCivs[civ].name.empty()) {
    return -1;
  }
  SettlerCiv& entry = g_settlerCivs[civ];
  const char* table = Field<const char*>(database, 0x54);
  if (entry.table != table) {
    entry.table = table;
    entry.proto = NameId(database, entry.name);
    if (entry.proto < 0 || entry.proto >= Field<std::int32_t>(database, 0x19B0)) {
      uhc::Log(L"sharedBuildLimit: civ %d: %hs is no proto (SettlerProtoName); its settler limit is each proto's own",
               civ, entry.name.c_str());
      entry.proto = -1;
    }
  }
  return entry.proto;
}

// Built at the first use: the protos are not all read while the tags load.
void Build(std::int32_t ownId, Share& share, const char* database) {
  share.built = true;
  if (!share.limitUnit.empty()) {
    share.limitProto = NameId(database, share.limitUnit);
    if (share.limitProto < 0 || share.limitProto >= Field<std::int32_t>(database, 0x19B0)) {
      uhc::Log(L"sharedBuildLimit: proto %d: %hs is no proto: it keeps its own limit", ownId, share.limitUnit.c_str());
      share.limitProto = -1;
    }
  }
  const std::int32_t protos = Field<std::int32_t>(database, 0x19B0);
  if (share.settler && g_settlerType >= 0) {
    for (std::int32_t id = 0; id < protos; ++id) {
      const char* proto = kProtoById(database, id);
      if (proto != nullptr && kProtoIsType(proto, g_settlerType)) {
        share.members.emplace_back(id, 1);
      }
    }
  }
  for (const Listed& entry : share.listed) {
    const std::int32_t type = NameId(database, entry.name);
    if (type < 0) {
      uhc::Log(L"sharedBuildLimit: proto %d: unknown unit type %hs", ownId, entry.name.c_str());
      continue;
    }
    for (std::int32_t id = 0; id < protos; ++id) {
      const char* proto = kProtoById(database, id);
      if (proto == nullptr || !kProtoIsType(proto, type)) {
        continue;
      }
      bool known = false;
      for (const auto& member : share.members) {
        known = known || member.first == id;
      }
      if (!known) {
        share.members.emplace_back(id, entry.weight);
      }
      if (id == ownId) {
        share.ownWeight = entry.weight;
      }
    }
  }
  if (g_log) {
    uhc::Log(L"sharedBuildLimit: proto %d: limit of %d, %u protos count, own weight %d%ls%ls%ls", ownId,
             share.limitProto, static_cast<unsigned>(share.members.size()), share.ownWeight,
             share.team ? L", the team's" : L"", share.settler ? L", the civ's settler limit" : L"",
             share.use ? L", UseSharedBuildLimit" : L"");
  }
}

bool IsTagged(std::int32_t id) {
  return id >= 0 && static_cast<std::size_t>(id) < g_tagged.size() && g_tagged[static_cast<std::size_t>(id)];
}

bool ReadyShare(std::int32_t id, Share** out) {
  const char* database = Database();
  if (!IsTagged(id) || database == nullptr) {
    return false;
  }
  Share& share = g_shares[id];
  if (!share.built) {
    Build(id, share, database);
  }
  *out = &share;
  return true;
}

// What the other units weigh for this player: its own other protos, and with TeamBuildLimit every
// unit of the team's other players (the test the shared resources use, 0x67995B).
std::int64_t Others(const char* player, std::int32_t ownId, const Share& share) {
  const char* world = World();
  if (world == nullptr) {
    return 0;
  }
  const std::int32_t self = Field<std::int32_t>(player, 0);
  const auto players = Field<const char* const*>(world, 0x58);
  const std::int32_t count = Field<std::int32_t>(world, 0x5C);
  std::int64_t sum = 0;
  for (std::int32_t i = 0; i < count && i < kMaxPlayers; ++i) {
    if (i != self) {
      const std::int32_t relation = Field<std::int32_t>(player, 0x1D4 + 4 * i);
      if (!share.team || i == 0 || (relation != 0 && relation != 1)) {
        continue;
      }
    }
    const char* other = players[i];
    if (other == nullptr) {
      continue;
    }
    for (const auto& member : share.members) {
      if (i == self && member.first == ownId) {
        continue;  // the stock compare adds these
      }
      const char* proto = kPlayerProto(other, member.first);
      if (proto != nullptr) {
        sum += static_cast<std::int64_t>(kCount(proto, i, true, true)) * member.second;
      }
    }
  }
  return sum;
}

// Replaces the count calls of the tooltips: the group's total, in the proto's own weight.
std::int32_t __fastcall TooltipCount(const char* proto, void*, std::int32_t playerId, bool first, bool second) {
  const std::int32_t own = kCount(proto, playerId, first, second);
  Share* share = nullptr;
  const char* world = World();
  if (proto == nullptr || world == nullptr || !ReadyShare(Field<std::int32_t>(proto, 4), &share)) {
    return own;
  }
  const char* player = Field<const char* const*>(world, 0x58)[playerId];
  return own + static_cast<std::int32_t>(Others(player, Field<std::int32_t>(proto, 4), *share) / share->ownWeight);
}

bool FromTooltip(std::uint32_t returnAddress) {
  for (const std::uint32_t address : kTooltipLimits) {
    if (address == returnAddress) {
      return true;
    }
  }
  return false;
}

}  // namespace

// From the hook at the entry of the limit.
extern "C" std::int32_t __stdcall UhcSharedLimit(const char* player, const char* proto, std::uint32_t returnAddress) {
  const auto stockLimit = reinterpret_cast<LimitFn>(&UhcSharedLimitStock);
  const std::int32_t stock = stockLimit(player, proto);
  if (proto == nullptr) {
    return stock;
  }
  const std::int32_t id = Field<std::int32_t>(proto, 4);
  Share* found = nullptr;
  if (!ReadyShare(id, &found)) {
    return stock;
  }
  if (!g_enabled.empty()) {
    const auto enabled = g_enabled.find(proto);
    if (enabled != g_enabled.end() && enabled->second.id == id && enabled->second.value == 0.0f) {
      return stock;  // a tech turned the share off for this player
    }
  }
  Share& share = *found;
  std::int32_t limit = stock;
  std::int32_t limitId = share.limitProto;
  if (share.settler) {
    const char* database = Database();
    const std::int32_t settler = database == nullptr ? -1 : SettlerProtoOf(player, database);
    if (settler >= 0) {
      limitId = settler;
    }
  }
  if (limitId >= 0) {
    const char* limitProto = kPlayerProto(player, limitId);
    if (limitProto != nullptr) {
      limit = stockLimit(player, limitProto);
    }
  }
  if (limit < 0) {
    return stock;  // no limit to share
  }
  if (FromTooltip(returnAddress)) {
    return limit / share.ownWeight;
  }
  const std::int64_t room = (static_cast<std::int64_t>(limit) - Others(player, id, share)) / share.ownWeight;
  const std::int32_t result = room < 0 ? 0 : static_cast<std::int32_t>(room);
  if (g_log && result != share.lastLogged && g_logLines < kMaxLogLines) {
    ++g_logLines;
    share.lastLogged = result;
    uhc::Log(L"sharedBuildLimit: player %d, proto %d: room %d of %d (stock %d)", Field<std::int32_t>(player, 0), id, result,
             limit, stock);
  }
  return result;
}

namespace uhc {

Outcome ApplySharedBuildLimit(const Config& config) {
  const Config::Args* args = config.First("sharedBuildLimit");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"sharedBuildLimit: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("sharedBuildLimit", {&sites::kBuildLimitEntry, &sites::kBuildCountEntry, &sites::kPlayerProtoEntry,
                                      &sites::kBuildCountTooltip1, &sites::kBuildCountTooltip2, &sites::kProtoById, &sites::kXmlAttribute, &sites::kXmlText}) ||
      !AddProtoTagHandler("SharedBuildLimitUnit", &ReadLimitUnit) ||
      !AddProtoTagHandler("SharedBuildLimitUnitType", &ReadUnitType) ||
      !AddProtoTagHandler("TeamBuildLimit", &ReadTeam) ||
      !AddProtoTagHandler("UseSharedBuildLimit", &ReadUse) ||
      !AddProtoTagHandler("SharedBuildLimitUnitTypes", &ReadUnitType) ||
      !AddProtoTagHandler("SettlerBuildLimit", &ReadSettler) ||
      !AddCivTagHandler("SettlerProtoName", &ReadSettlerProtoName) ||
      !AddTechSubtype("EnableSharedBuildLimit", &ChangeEnabled) || !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !RequestAbstractUnitType("LogicalTypeSettlerBuildLimit", &g_settlerType) ||
      !WriteJmp(kLimitEntry, reinterpret_cast<const void*>(&UhcSharedLimitHook), 5)) {
    return Outcome::kFailed;
  }
  for (const std::uint32_t call : kTooltipCounts) {
    if (!WriteCall(call, reinterpret_cast<const void*>(&TooltipCount))) {
      return Outcome::kFailed;
    }
  }
  Log(L"sharedBuildLimit: the proto tags are on, the civ tag SettlerProtoName and the Data subtype "
      L"EnableSharedBuildLimit");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/sharedlimit_hooks.asm

```asm
; sharedBuildLimit (src/features/sharedlimit.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcSharedLimit PROTO STDCALL player:DWORD, protoUnit:DWORD, returnAddress:DWORD

.data
limitEntryNext  dd 004C7B64h    ; mov ecx,[esp+14h], the rest of the stock limit

.code

; Replaces 0x4C7B5F..0x4C7B63 (sub esp,10h / mov edx,ecx), the entry of the limit, thiscall(player,
; proto), ret 4. No branch lands inside them.
UhcSharedLimitHook PROC
    TRACE_ONCE "sharedBuildLimit limit (0x4C7B5F)"
    mov eax, dword ptr [esp+4]
    mov edx, dword ptr [esp]
    invoke UhcSharedLimit, ecx, eax, edx
    ret 4
UhcSharedLimitHook ENDP

; The stock limit, for the helper: the two instructions the hook replaced, then the rest.
UhcSharedLimitStock PROC
    sub esp, 10h
    mov edx, ecx
    jmp limitEntryNext
UhcSharedLimitStock ENDP

END
```

## doNotQueue

Contract: [doNotQueue](../porting-to-another-dll.md#donotqueue).

Besides the core helpers, it needs: [`prototags.h`](helpers.md#proto-tags).

Sites: `ShipQueueAddCall` `0x85AD38` (5 B), `TrainQueueAddCall` `0x9CE81A` (5 B).

### src/features/donotqueue.cpp

```cpp
// doNotQueue: <DoNotQueue/> in a proto trains it ahead of what waits in the building.
//
// The queue routine 0x9CE2BE adds each new Train action at the end of the unit's action list with
// 0x494894 (the call at 0x9CE81A). The list is at [manager+14h]: +0 the count, +8 the pointers. It
// also holds the unit's other actions (idle, Maintain...), and the building works on the first Train or
// Research action of the list. After the stock add, the hook moves the new action before the first
// of them, behind any action of a tagged proto, so those keep their order. An action already training
// waits with its progress, and goes on when the tagged one is done. The proto IDs are read once and are
// the same for every player.
//
// Shipments: the home city holds a queue of the cards sent, {data, count, capacity} at [hc+288h]. Only the
// first entry advances, and the send 0x85A724 adds at the end with 0x857204 (the call at 0x85AD38). A card
// whose tech has the stock flag DoNotQueue moves in the same way: before the first card without the flag.
// What was on its way keeps its progress, as the entry holds it.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unordered_set>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"

namespace {

constexpr std::size_t kActionList = 0x14;
constexpr std::uint8_t kResearchAction = 0x0C;
constexpr std::uint8_t kTrainAction = 0x0D;
constexpr int kMaxLogLines = 200;
constexpr std::size_t kShipQueue = 0x288;
constexpr std::int32_t kTechDoNotQueue = 0x1A;  // the flag's bit
constexpr std::uintptr_t kGameGlobal = 0x00C66234;

// Each entry owns its cost list and nothing points into an entry, so entries move as plain bytes.
struct ShipEntry {
  std::int32_t card;
  std::int32_t tech;
  float points;
  float progress;
  char cost[8];
};
static_assert(sizeof(ShipEntry) == 0x18);

using AddActionFn = bool(__thiscall*)(char* manager, char* action, std::int32_t a, std::int32_t b, std::int32_t c);
using ShipAddFn = std::int32_t(__thiscall*)(char* queue, const void* entry);
using PlayerTechFn = const char*(__thiscall*)(const char* player, std::int32_t tech);
using TechFlagFn = bool(__thiscall*)(const char* tech, std::int32_t bit);
const auto kAddAction = reinterpret_cast<AddActionFn>(0x00494894);
const auto kShipAdd = reinterpret_cast<ShipAddFn>(0x00857204);
const auto kPlayerTech = reinterpret_cast<PlayerTechFn>(0x00511924);
const auto kTechFlag = reinterpret_cast<TechFlagFn>(0x0044D863);

std::unordered_set<std::int32_t> g_protos;  // filled while protos load, read-only after
bool g_log = false;
int g_logLines = 0;

bool __cdecl ReadDoNotQueue(void*, const char*, char* proto) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 8);
  g_protos.insert(id);
  if (g_log) {
    uhc::Log(L"doNotQueue: proto %d has the tag", id);
  }
  return true;
}

// The proto of a Train action, or -1: the first entry of [action+70h], 14h bytes each, +0 the proto ID.
std::int32_t TrainProto(const char* action) {
  if (static_cast<std::uint8_t>(action[0x60]) != kTrainAction ||
      *reinterpret_cast<const std::int32_t*>(action + 0x74) <= 0) {
    return -1;
  }
  return **reinterpret_cast<const std::int32_t* const*>(action + 0x70);
}

bool Tagged(const char* action) { return g_protos.count(TrainProto(action)) != 0; }

bool InQueue(const char* action) {
  const auto type = static_cast<std::uint8_t>(action[0x60]);
  return type == kResearchAction || type == kTrainAction;
}

// Replaces the call of the add in the queue routine.
bool __fastcall AddAction(char* manager, void*, char* action, std::int32_t a, std::int32_t b, std::int32_t c) {
  if (!kAddAction(manager, action, a, b, c)) {
    return false;
  }
  if (!Tagged(action)) {
    return true;
  }
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(manager + kActionList);
  char** list = *reinterpret_cast<char***>(manager + kActionList + 8);
  std::int32_t from = count - 1;
  while (from >= 0 && list[from] != action) {
    --from;
  }
  std::int32_t to = 0;
  while (to < from && !InQueue(list[to])) {
    ++to;
  }
  while (to < from && Tagged(list[to])) {
    ++to;
  }
  if (from < 0 || to >= from) {
    return true;
  }
  for (std::int32_t i = from; i > to; --i) {
    list[i] = list[i - 1];
  }
  list[to] = action;
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"doNotQueue: proto %d goes from place %d to place %d of %d", TrainProto(action), from, to, count);
  }
  return true;
}

template <typename T>
T Field(const char* base, std::size_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

bool CardFirst(const char* hc, const ShipEntry& entry) {
  const char* tech = kPlayerTech(Field<const char*>(hc, 0x08), entry.tech);
  return tech != nullptr && kTechFlag(tech, kTechDoNotQueue);
}

// The home city screen's shipment models name their card by its place in the queue, on the local player's only.
void MoveVisuals(const char* hc, std::int32_t to, std::int32_t from) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* player = Field<const char*>(hc, 0x08);
  if (game == nullptr || player == nullptr || Field<std::int32_t>(game, 0x3C0) != Field<std::int32_t>(player, 0x00)) {
    return;
  }
  const char* scene = Field<const char*>(hc, 0xA4);
  if (scene == nullptr) {
    scene = hc;
  }
  char* const* models = Field<char* const*>(scene, 0x134);
  const std::int32_t count = Field<std::int32_t>(scene, 0x138);
  for (std::int32_t i = 0; i < count; ++i) {
    if (models[i] != nullptr) {
      auto* place = reinterpret_cast<std::int32_t*>(models[i] + 0x2C);
      if (*place >= to && *place < from) {
        ++*place;
      }
    }
  }
}

// Replaces the call of the add in the send. Its result is the place of the new entry, which the send gives to
// the shipment's models.
std::int32_t __fastcall AddCard(char* queue, void*, const void* entry) {
  const std::int32_t from = kShipAdd(queue, entry);
  if (from <= 0) {
    return from;
  }
  const char* hc = queue - kShipQueue;
  auto* list = *reinterpret_cast<ShipEntry**>(queue);
  if (!CardFirst(hc, list[from])) {
    return from;
  }
  std::int32_t to = 0;
  while (to < from && CardFirst(hc, list[to])) {
    ++to;
  }
  if (to >= from) {
    return from;
  }
  const ShipEntry moved = list[from];
  std::memmove(list + to + 1, list + to, static_cast<std::size_t>(from - to) * sizeof(ShipEntry));
  list[to] = moved;
  MoveVisuals(hc, to, from);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"doNotQueue: card with tech %d goes from place %d to place %d of the shipments", moved.tech, from, to);
  }
  return to;
}

}  // namespace

namespace uhc {

Outcome ApplyDoNotQueue(const Config& config) {
  const Config::Args* args = config.First("doNotQueue");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"doNotQueue: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("doNotQueue", {&sites::kTrainQueueAddCall, &sites::kShipQueueAddCall}) ||
      !AddProtoTagHandler("DoNotQueue", &ReadDoNotQueue) ||
      !WriteCall(sites::kTrainQueueAddCall.va, reinterpret_cast<const void*>(&AddAction)) ||
      !WriteCall(sites::kShipQueueAddCall.va, reinterpret_cast<const void*>(&AddCard))) {
    return Outcome::kFailed;
  }
  Log(L"doNotQueue: the proto tag DoNotQueue and the cards with the tech flag DoNotQueue are on");
  return Outcome::kApplied;
}

}  // namespace uhc
```

## nextResearchFree

Contract: [nextResearchFree](../porting-to-another-dll.md#nextresearchfree).

Besides the core helpers, it needs: [`techsubtypes.h`](helpers.md#tech-subtypes), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `CommandResearchPayCall` `0x9D54CF` (5 B), `CommandResearchCostCopyCall` `0x9D5548` (5 B), `ResearchPayCall` `0x9E67E1` (5 B), `ResearchCostCopyCall` `0x9E68A0` (5 B).

### src/features/freeresearch.cpp

```cpp
// nextResearchFree: a tech effect type='Data' subtype='NextResearchIsFree' on a ProtoUnit target makes
// the next research queued in a building of that proto free. SetNextResearchFree is the same subtype.
//
// A research is paid when its action starts: 0x8D946A at 0x9E67E1 (Research) and at 0x9D54CF
// (CommandResearch). Each action then keeps a copy of the cost for the refund of a cancel (0x9E68A0,
// 0x9D5548). The effect adds its amount to a count kept by the player's copy of the proto. With a count
// above 0 the payment is skipped, and the copy of the cost is emptied, so a cancel refunds nothing and
// spends the count. The count is not in saved games: a load applies the tech's effects again, so it
// is back to what the effects give. The hooks are in hooks/freeresearch_hooks.asm.
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

extern "C" {
void UhcFreeResearchPayHook();
void UhcFreeCommandPayHook();
}

namespace {

constexpr int kMaxLogLines = 200;
constexpr std::uint32_t kCostCopyCalls[] = {0x009E68A0, 0x009D5548};

using PayFn = bool(__thiscall*)(void* player, const void* cost);
using CostCopyFn = void*(__thiscall*)(void* cost, const void* from);
using CostFillFn = void(__thiscall*)(void* cost, float value);
const auto kPay = reinterpret_cast<PayFn>(0x008D946A);
const auto kCostCopy = reinterpret_cast<CostCopyFn>(0x00480A73);
const auto kCostFill = reinterpret_cast<CostFillFn>(0x004E2617);

std::unordered_map<const char*, std::int32_t> g_free;  // by the player's copy of the proto
bool g_skipped = false;                                // the payment just skipped, for the copy that follows
bool g_log = false;
int g_logLines = 0;

void LogLine(const wchar_t* what, const char* proto, std::int32_t count) {
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"nextResearchFree: proto %d: %ls, %d left", *reinterpret_cast<const std::int32_t*>(proto + 8), what, count);
  }
}

void ChangeCount(char* proto, const char*, float amount, std::uint8_t, bool unapply) {
  const std::int32_t delta = static_cast<std::int32_t>(std::lround(amount));
  std::int32_t& count = g_free[proto];
  count = unapply ? (count > delta ? count - delta : 0) : count + delta;
  LogLine(unapply ? L"effect removed" : L"effect applied", proto, count);
}

void ForgetOnDataLoad(char*) {
  g_free.clear();
  g_skipped = false;
}

// Replaces the call of the copy of the cost into the action.
void* __fastcall CostCopy(void* cost, void*, const void* from) {
  void* result = kCostCopy(cost, from);
  if (g_skipped) {
    g_skipped = false;
    kCostFill(cost, 0.0f);
  }
  return result;
}

}  // namespace

// From the two hooks, instead of the payment. The action is the one being started.
extern "C" bool __stdcall UhcFreeResearchPay(const char* action, void* player, const void* cost) {
  const char* unit = *reinterpret_cast<const char* const*>(action + 0x10);
  const char* proto = unit != nullptr ? *reinterpret_cast<const char* const*>(unit + 0x5C) : nullptr;
  const auto found = proto != nullptr ? g_free.find(proto) : g_free.end();
  if (found == g_free.end() || found->second <= 0) {
    return kPay(player, cost);
  }
  --found->second;
  g_skipped = true;
  LogLine(L"a free research", proto, found->second);
  return true;
}

namespace uhc {

Outcome ApplyNextResearchFree(const Config& config) {
  const Config::Args* args = config.First("nextResearchFree");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"nextResearchFree: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("nextResearchFree", {&sites::kResearchPayCall, &sites::kCommandResearchPayCall,
                                      &sites::kResearchCostCopyCall, &sites::kCommandResearchCostCopyCall}) ||
      !AddTechSubtype("NextResearchIsFree", &ChangeCount) || !AddTechSubtype("SetNextResearchFree", &ChangeCount) ||
      !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !WriteCall(sites::kResearchPayCall.va, reinterpret_cast<const void*>(&UhcFreeResearchPayHook)) ||
      !WriteCall(sites::kCommandResearchPayCall.va, reinterpret_cast<const void*>(&UhcFreeCommandPayHook))) {
    return Outcome::kFailed;
  }
  for (const std::uint32_t call : kCostCopyCalls) {
    if (!WriteCall(call, reinterpret_cast<const void*>(&CostCopy))) {
      return Outcome::kFailed;
    }
  }
  Log(L"nextResearchFree: the Data subtype NextResearchIsFree is on");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/freeresearch_hooks.asm

```asm
; nextResearchFree (src/features/freeresearch.cpp). Both replace a call of the payment 0x8D946A, whose
; argument, the cost, is already on the stack, and return to the stock code as that call did: al, ret 4.
.686
.model flat, c
option casemap :none

include common.inc

UhcFreeResearchPay PROTO STDCALL action:DWORD, player:DWORD, cost:DWORD

.code

; The call at 0x9E67E1 in the Research action's start. ECX = the player, EBP = the action.
UhcFreeResearchPayHook PROC
    TRACE_ONCE "nextResearchFree research (0x9E67E1)"
    mov eax, dword ptr [esp+4]
    invoke UhcFreeResearchPay, ebp, ecx, eax
    ret 4
UhcFreeResearchPayHook ENDP

; The call at 0x9D54CF in the CommandResearch action's start. ECX = the player, ESI = the action.
UhcFreeCommandPayHook PROC
    TRACE_ONCE "nextResearchFree command research (0x9D54CF)"
    mov eax, dword ptr [esp+4]
    invoke UhcFreeResearchPay, esi, ecx, eax
    ret 4
UhcFreeCommandPayHook ENDP

END
```

## maintainWaitForPop

Contract: [maintainWaitForPop](../porting-to-another-dll.md#maintainwaitforpop).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `MaintainEpilogue` `0x493039` (7 B), `MaintainNotDone` `0x6AB180` (6 B), `MaintainCycleDone` `0x6AB264` (25 B), `MaintainSpawn` `0x6AB27D` (44 B), `MaintainRestart` `0x6AB2D1` (15 B), `MaintainGroupPopTest` `0x9E2B69` (113 B), `MaintainSpawnSetup` `0x9E2E35` (186 B), `MaintainSpawnPopTest` `0x9E2F79` (109 B), `MaintainSpawnPopTest2` `0x9E3110` (25 B).

### src/features/maintain.cpp

```cpp
// maintainWaitForPop: a building's automatic production (the Maintain action: factory cannons,
// the Ottoman Town Center's settlers, dock boats, native warriors, ...) keeps a finished unit while
// its player has no population room, instead of losing it.
//
// Stock: the Maintain update FUN_00492F3E adds train points to [action+70h] every tick; when the
// fraction [action+74h] reaches 1.0 it calls the spawn FUN_009E2DEF(this, [+64h] proto ID, [+68h]
// units per cycle), whose population test stops before the first unit when it does not fit. The
// update never looks at the result: a persistent action restarts its cycle from zero
// (setState(14h)), a SingleUse one ends (setState(0Ah)), so a cycle that ends while the player is
// housed produces nothing.
//
// The change: a hook just before the spawn call asks UhcMaintainPopBlocked, which repeats the
// spawn's first-unit test with the engine's own getters. When that unit would not fit and the
// building's proto has the marker unittype (default AbstractMaintainWaitForPop), the call and the
// restart are skipped and the cycle stays complete; every later update comes back to the same
// test, and the unit spawns on the first update with room. The hook is in hooks/maintain_hooks.asm.
#include <cstdint>
#include <cstring>
#include <map>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" void UhcMaintainSpawnHook();

namespace {

// Engine layout (docs/engine-symbols.md, "Maintain (automatic production)").
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using PlayerProtoFn = char*(__thiscall*)(char* player, std::int32_t protoId);
using ProtoBitFn = bool(__thiscall*)(const char* proto, std::int32_t bit);
using PlayerCountFn = std::int32_t(__thiscall*)(char* player);

const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kProtoHasAbstractBit = reinterpret_cast<ProtoBitFn>(0x0044CAC4);  // raw bitset [proto+30h]
const auto kProtoHasFlag = reinterpret_cast<ProtoBitFn>(0x0045EE02);         // flags [proto+50h]
const auto kPlayerPop = reinterpret_cast<PlayerCountFn>(0x0045805C);
const auto kPlayerPopCap = reinterpret_cast<PlayerCountFn>(0x004581A1);  // includes basePop/extraPop

constexpr std::int32_t kAbstractMonk = 0x5D;           // may reuse a unit with no population test
constexpr std::int32_t kAllowOverPopCap = 0x9F;        // needs only cap - used > 0
constexpr std::int32_t kAlwaysAllowOverPopCap = 0xA3;  // no population test

// Database offsets of the proto IDs the spawn replaces with xpColonialMilitia ([db+609Ch]) once
// the player has revolted: Settler, Coureur, SettlerWagon, CoureurCree.
constexpr std::uint32_t kRevoltedIds[] = {0x5E1C, 0x6054, 0x6050, 0x6058};
constexpr std::uint32_t kMilitiaId = 0x609C;

std::int32_t g_markerType = -1;  // marker unittype ID, set on each database load; -1 before

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

char* Database() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<char*>(game, 0x140);
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

struct PopCheck {
  bool blocked = false;
  bool measured = false;        // pop, used and cap below were read
  const char* proto = nullptr;  // the player's proto of the unit to spawn
  std::int32_t pop = 0;
  std::int32_t used = 0;
  std::int32_t cap = 0;
};

// The first-unit test of FUN_009E2DEF (0x9E2E35..0x9E2EE9, 0x9E2F79..0x9E2FE2, 0x9E3110..0x9E311F)
// and of the group spawn FUN_009E2AC8 (0x9E2B69..0x9E2BD5), in the engine's order and with its
// 32-bit arithmetic. Every step that lets the stock call create a unit, or that the test does not
// cover (AbstractMonk reuse, an empty cycle), answers "not blocked", so the stock call runs.
PopCheck CheckFirstUnit(char* action) {
  PopCheck check;
  char* owner = Field<char*>(action, 0x10);
  char* player = owner == nullptr ? nullptr : Field<char*>(owner, 0x44);
  if (player == nullptr || Field<std::int32_t>(action, 0x68) < 1) {
    return check;
  }
  const char* ownerProto = Field<const char*>(owner, 0x5C);
  if (g_markerType < 0 || ownerProto == nullptr || !kProtoIsType(ownerProto, g_markerType)) {
    return check;
  }
  std::int32_t protoId = Field<std::int32_t>(action, 0x64);
  const char* database = Database();
  if (Field<std::uint8_t>(player, 0x50A) != 0 && database != nullptr) {
    for (std::uint32_t offset : kRevoltedIds) {
      if (protoId == Field<std::int32_t>(database, offset)) {
        protoId = Field<std::int32_t>(database, kMilitiaId);
        break;
      }
    }
  }
  check.proto = kPlayerProto(player, protoId);
  if (check.proto == nullptr || kProtoHasAbstractBit(check.proto, kAbstractMonk)) {
    return check;
  }
  check.pop = Field<std::int32_t>(check.proto, 0xD8);
  if (check.pop <= 0 || kProtoHasFlag(check.proto, kAlwaysAllowOverPopCap)) {
    return check;
  }
  const std::uint32_t used = Field<std::uint32_t>(player, 0x78) + static_cast<std::uint32_t>(kPlayerPop(player));
  const std::uint32_t cap = static_cast<std::uint32_t>(kPlayerPopCap(player));
  check.used = static_cast<std::int32_t>(used);
  check.cap = static_cast<std::int32_t>(cap);
  check.measured = true;
  if (kProtoHasFlag(check.proto, kAllowOverPopCap)) {
    check.blocked = static_cast<std::int32_t>(cap - used) <= 0;
  } else {
    check.blocked = check.cap < static_cast<std::int32_t>(used + static_cast<std::uint32_t>(check.pop));
  }
  return check;
}

// "maintainWaitForPop ... log": the actions holding a unit, with their building's unit ID (an
// action freed with its building may be reused at the same address). Logging only; cleared on
// each database load.
bool g_log = false;
std::map<const char*, std::int32_t> g_held;

void ClearHeld(char*) { g_held.clear(); }

void LogTransition(const char* action, const PopCheck& check) {
  const char* owner = Field<const char*>(action, 0x10);
  const std::int32_t ownerId = owner == nullptr ? -1 : Field<std::int32_t>(owner, 0x10);
  const char* ownerName = owner == nullptr ? "?" : ProtoName(Field<const char*>(owner, 0x5C));
  const auto held = g_held.find(action);
  const bool wasHeld = held != g_held.end() && held->second == ownerId;
  if (check.blocked && !wasHeld) {
    g_held[action] = ownerId;
    uhc::Log(L"maintainWaitForPop: unit %d (%hs) holds a finished %hs (pop %d, %d of %d used)", ownerId, ownerName,
             ProtoName(check.proto), check.pop, check.used, check.cap);
  } else if (!check.blocked && wasHeld) {
    g_held.erase(held);
    if (check.measured) {
      uhc::Log(L"maintainWaitForPop: unit %d (%hs) releases its %hs (pop %d, %d of %d used)", ownerId, ownerName,
               ProtoName(check.proto), check.pop, check.used, check.cap);
    } else {
      uhc::Log(L"maintainWaitForPop: unit %d (%hs) releases its %hs", ownerId, ownerName, ProtoName(check.proto));
    }
  }
}

}  // namespace

extern "C" {
// Called from the hook with the Maintain action whose cycle is complete. True: the first unit
// does not fit, so the hook keeps the cycle complete instead of calling the spawn. Reads only
// simulation state.
bool __stdcall UhcMaintainPopBlocked(char* action) {
  const PopCheck check = CheckFirstUnit(action);
  if (g_log) {
    LogTransition(action, check);
  }
  return check.blocked;
}
}

namespace uhc {

Outcome ApplyMaintainWaitForPop(const Config& config) {
  const Config::Args* args = config.First("maintainWaitForPop");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::string typeName = "AbstractMaintainWaitForPop";
  bool typeGiven = false;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (!typeGiven) {
      typeName = arg;
      typeGiven = true;
    } else {
      Log(L"maintainWaitForPop: unexpected argument %hs (expected: [UnitType] [log]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("maintainWaitForPop",
                 {&sites::kMaintainCycleDone, &sites::kMaintainSpawn, &sites::kMaintainRestart,
                  &sites::kMaintainNotDone, &sites::kMaintainEpilogue, &sites::kMaintainSpawnSetup,
                  &sites::kMaintainSpawnPopTest, &sites::kMaintainSpawnPopTest2, &sites::kMaintainGroupPopTest})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(typeName.c_str(), &g_markerType)) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (log && !OnDatabaseLoad(&ClearHeld)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kMaintainSpawn.va, reinterpret_cast<const void*>(&UhcMaintainSpawnHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"maintainWaitForPop: buildings of unittype %hs keep a finished Maintain unit until there is "
      L"population room%ls (multiplayer unverified)",
      typeName.c_str(), log ? L", holds and releases logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/maintain_hooks.asm

```asm
; Hook for maintainWaitForPop. Entered through a jmp written over the stock code; leaves through
; an explicit jmp to a verified continuation (docs/engine-symbols.md, "Maintain (automatic
; production)").
.686
.model flat, c
option casemap :none

include common.inc

UhcMaintainPopBlocked PROTO STDCALL action:DWORD

.data
spawnNext       dd 006AB283h    ; push edx / push eax / call 9E2DEFh (spawn), then the restart
notDone         dd 006AB180h    ; pop ebx / jmp 493039h: the update's "cycle not complete" exit

.code

; Replaces 0x6AB27D..0x6AB282 (mov edx,[esi+68h] / mov eax,[esi+64h]) in the cold chunk of the
; Maintain update FUN_00492F3E, reached only by the fall-through of the "cycle complete" test
; ([esi+74h] >= 1.0). ESI = the Maintain action, ECX = ESI (this of the spawn call), EBX pushed
; by the chunk, FPU stack empty. When the first unit of the cycle does not fit in its player's
; population and the building has the marker type, the cycle stays complete and the update leaves
; as for an unfinished cycle: no spawn, no restart. Otherwise the stock spawn and restart run.
UhcMaintainSpawnHook PROC
    TRACE_ONCE "maintainWaitForPop (0x6AB27D)"
    pushad
    push esi
    call UhcMaintainPopBlocked      ; AL = 1: hold the finished unit
    test al, al
    popad                           ; leaves the flags of the test
    jne hold
    mov edx, dword ptr [esi+68h]    ; stolen 0x6AB27D: units per cycle
    mov eax, dword ptr [esi+64h]    ; stolen 0x6AB280: proto ID to spawn
    jmp spawnNext
hold:
    mov eax, dword ptr [esi+6Ch]    ; train points of a whole cycle
    mov dword ptr [esi+70h], eax    ; progress stays exactly complete; EAX is not read after
    jmp notDone
UhcMaintainSpawnHook ENDP

END
```

## noTrainNearEnemyTC

Contract: [noTrainNearEnemyTC](../porting-to-another-dll.md#notrainnearenemytc).

Besides the core helpers, it needs: [`floatingtext.h`](helpers.md#floating-text), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `PlayerById` `0x44CB21` (30 B), `UnitById` `0x44CC6D` (58 B), `IsA` `0x44D7FA` (105 B), `IsBuilt` `0x44DDB4` (31 B), `IsATrue` `0x44F139` (5 B), `PlayerByIdNull` `0x4649E1` (5 B), `PlayerIsEnemy` `0x484D2D` (32 B), `NoCorpseDoppleAliveCall` `0x4868FA` (21 B), `UnitsNearPoint` `0x4A1C55` (248 B), `UnitByIdNull` `0x4E2A35` (5 B), `FirstTcRuleLoop` `0x8CE9BE` (104 B), `TypeRuleQuery` `0x8CEA69` (34 B), `FirstTcRuleFilter` `0x8CEB45` (55 B), `TrainUpdateTrainer` `0x9EA2B2` (11 B), `WorkRateTrainCall` `0x9EA410` (20 B), `TrainRateScale` `0x9EA424` (19 B).

### src/features/notrainneartc.cpp

```cpp
// noTrainNearEnemyTC <meters> [UnitType] [near <UnitType>|FirstTC ...] [nowarn | warn=<text>] [log]:
// a unit of the marker type (default AbstractDaimyo, the Daimyos and the Shogun) does not train
// while it stands near an enemy's first Town Center, or near an enemy's building of a listed type.
//
// Stock: each player keeps the unit ID of its first Town Center, "FirstTC", at [player+4F0h].
// Player::addUnit (FUN_0049874F) sets it when the first unit of the TownCenter proto joins the
// player, and nothing clears it. placementrules.xml reads it through the keyword FirstTC: the
// stock rule `distanceatleastfromtype player=enemy distance=65 FirstTC` keeps buildings 65 m
// away from an enemy's first TC (evaluated by FUN_008CE935). Nothing limits a unit that trains:
// a Daimyo can walk into the enemy base and train an army there.
//
// The Train update FUN_009EA28B adds the trainer's work rate (getter 0x9BFE33) times the game
// speed and the civ's train rate to the queue's progress on every tick. The hook in
// hooks/notrainneartc_hooks.asm asks UhcNoTrainBlocked first: when the trainer's proto has the
// marker and an enemy's FirstTC is alive and less than <meters> away, the rate is 0.0, so the
// queue keeps its progress and waits; it resumes when the trainer leaves or the TC dies. Nothing
// is refunded or cancelled. The test is the placement rule's: each player's FirstTC through the
// unit table, its owner's stance toward the trainer's player (0x484D2D, the rule's player=enemy)
// and the distance from the TC to the trainer's position (the TC's vtable slot B8h, the rule's
// distance call); the alive test (vtable slot A4h) is added, so a destroyed TC stops blocking.
//
// That distance (slot B8h -> B0h(own position, point)) is not centre to centre. For a proto with
// flag bit 4 ([proto+50h]; the Town Center has it) 0x45EE55 is false and slot
// 108h, 0x4A0ED5, measures from the point to the unit's obstruction footprint, the nearest of
// its four edges, 0 inside it (0x485E35). Otherwise 0x485DBC takes the centre distance in x and z
// minus the proto's larger obstruction radius times sqrt(2), at least 0. The trainer counts by
// its centre, [trainer+14h].
//
// "near <UnitType>" (up to 4, "near FirstTC" being the default above) blocks near any enemy unit of
// that type that is alive and built, through the placement rule's generic path: the world's
// spatial query FUN_004A1C55(point, radius, 1, list), which returns the IDs of the units whose
// distance to the point (their vtable slot B8h, the same distance as above) is at most the
// radius, without walking the world's units. The list is the DLL's and is reused, so no tick
// allocates once it has grown. The query fills the obstruction manager's scratch list
// ([[world+260h]+4ECh]) and copies it out before it returns, as the placement rule's call does.
//
// The warning: while a trainer of the local player ([game+3C0h]) is held, the floating text of the
// stock dodge (0x6A24FC..0x6A2604: the text manager [world+8A8h], 0x8023AE) appears over it at most
// once every kWarnIntervalMs of game time, red and without the dodge's rise. Interface only: every
// machine holds the same trainers, and only the owner's screen shows the text.
#include <windows.h>

#include <algorithm>
#include <charconv>
#include <cstdint>
#include <cstring>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../floatingtext.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

// Engine layout (docs/engine-symbols.md, "Training near an enemy Town Center").
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr std::uint32_t kWorldPlayerCount = 0x5C;  // players 0 (gaia) .. count - 1
constexpr std::uint32_t kPlayerFirstTc = 0x4F0;    // unit ID of the player's first Town Center; -1 none
constexpr std::uint32_t kAliveSlot = 0xA4;         // unit vtable: bool thiscall(unit)
constexpr std::uint32_t kDistanceSlot = 0xB8;      // unit vtable: float thiscall(unit, const float* point)

// The list FUN_004A1C55 fills (the engine's dynamic array: data, count, capacity).
struct IdList {
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using PlayerByIdFn = const char*(__thiscall*)(char* world, std::int32_t id);
using UnitByIdFn = const char*(__thiscall*)(char* world, std::int32_t id);
using IsEnemyFn = bool(__thiscall*)(const char* player, std::int32_t otherId);
using UnitIsAliveFn = bool(__thiscall*)(const char* unit);
using UnitDistanceFn = float(__thiscall*)(const char* unit, const float* point);
using IsBuiltFn = bool(__thiscall*)(const char* unit);
using UnitsNearFn = std::int32_t(__thiscall*)(char* world, const float* point, float radius, char precise, IdList* out);

const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kIsEnemy = reinterpret_cast<IsEnemyFn>(0x00484D2D);
const auto kIsBuilt = reinterpret_cast<IsBuiltFn>(0x0044DDB4);
const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);

constexpr float kMaxMeters = 1000.0f;
constexpr unsigned kMaxLogLines = 1000;
constexpr std::size_t kMaxNear = 4;
constexpr std::int32_t kFirstTc = -2;                   // a "near" entry: the enemy's FirstTC
constexpr std::uint32_t kWarnIntervalMs = 8000;         // game time between two warnings over a unit
constexpr std::uint32_t kWarnColour = 0xFFFF4040;       // ARGB
constexpr wchar_t kDefaultWarning[] = L"Too close to the enemy: training paused";

float g_meters = 65.0f;
bool g_log = false;  // "noTrainNearEnemyTC ... log": every pause and resume

// What the trainers may not stand near: kFirstTc, or a unit type ID set on each data load.
std::int32_t g_nearTypes[kMaxNear] = {kFirstTc, -1, -1, -1};
std::string g_nearNames[kMaxNear] = {"FirstTC"};
std::size_t g_nearCount = 1;

bool g_warn = true;
std::wstring g_warnText = kDefaultWarning;
std::int32_t g_warnStringId = -1;

IdList g_found = {nullptr, 0, 0};  // FUN_004A1C55's output, reused

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

template <typename Fn>
Fn Virtual(const char* object, std::uint32_t slot) {
  return reinterpret_cast<Fn>(Field<void* const*>(object, 0)[slot / 4]);
}

char* World() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<char*>(game, 0x13C);
}

const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

std::int32_t PlayerIdOf(const char* unit) {
  const char* player = Field<const char*>(unit, 0x44);
  return player == nullptr ? -1 : Field<std::int32_t>(player, 0x00);
}

struct Nearest {
  const char* tc = nullptr;  // the blocker (a FirstTC or a unit of a near type); null: none
  std::int32_t player = -1;  // its owner's player ID
  float distance = 0.0f;
};

// The nearest alive FirstTC whose owner is the enemy of the trainer's player. Reads only
// simulation state, in player order, so every machine gets the same answer.
Nearest NearestEnemyFirstTc(const char* trainer);

// The nearest enemy unit of the type that is alive and built, at most g_meters from the trainer
// (the spatial query's own test, to the unit's edge). Whether one exists does not depend on the
// order of the query's list; only the logged one would.
Nearest NearestEnemyOfType(const char* trainer, std::int32_t typeId) {
  Nearest nearest;
  const char* owner = Field<const char*>(trainer, 0x44);
  char* world = World();
  if (owner == nullptr || world == nullptr || typeId < 0) {
    return nearest;
  }
  const std::int32_t ownerId = Field<std::int32_t>(owner, 0x00);
  const auto* position = reinterpret_cast<const float*>(trainer + 0x14);
  kUnitsNear(world, position, g_meters, 1, &g_found);
  for (std::int32_t i = 0; i < g_found.count && g_found.data != nullptr; ++i) {
    const char* unit = kUnitById(world, g_found.data[i]);
    const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    const char* unitOwner = unit == nullptr ? nullptr : Field<const char*>(unit, 0x44);
    // Player 0 (Gaia: natives, treasures) is skipped, as the FirstTC loop starts at player 1.
    if (proto == nullptr || unitOwner == nullptr || unitOwner == owner || Field<std::int32_t>(unitOwner, 0x00) == 0 ||
        !kProtoIsType(proto, typeId) || !kIsEnemy(unitOwner, ownerId) ||
        !Virtual<UnitIsAliveFn>(unit, kAliveSlot)(unit) || !kIsBuilt(unit)) {
      continue;
    }
    const float distance = Virtual<UnitDistanceFn>(unit, kDistanceSlot)(unit, position);
    if (distance < g_meters && (nearest.tc == nullptr || distance < nearest.distance)) {
      nearest = {unit, Field<std::int32_t>(unitOwner, 0x00), distance};
    }
  }
  return nearest;
}

// The nearest thing that holds the trainer, over the "near" entries; tc null if none.
Nearest NearestBlocker(const char* trainer) {
  Nearest best;
  for (std::size_t i = 0; i < g_nearCount; ++i) {
    const Nearest found = g_nearTypes[i] == kFirstTc ? NearestEnemyFirstTc(trainer)
                                                     : NearestEnemyOfType(trainer, g_nearTypes[i]);
    if (found.tc != nullptr && (best.tc == nullptr || found.distance < best.distance)) {
      best = found;
    }
  }
  return best;
}

Nearest NearestEnemyFirstTc(const char* trainer) {
  Nearest nearest;
  const char* owner = Field<const char*>(trainer, 0x44);
  char* world = World();
  if (owner == nullptr || world == nullptr) {
    return nearest;
  }
  const std::int32_t ownerId = Field<std::int32_t>(owner, 0x00);
  const auto* position = reinterpret_cast<const float*>(trainer + 0x14);
  const std::int32_t players = Field<std::int32_t>(world, kWorldPlayerCount);
  for (std::int32_t id = 1; id < players; ++id) {  // from 1, as the placement rule
    const char* player = kPlayerById(world, id);
    const std::int32_t tcId = player == nullptr ? -1 : Field<std::int32_t>(player, kPlayerFirstTc);
    const char* tc = tcId < 0 ? nullptr : kUnitById(world, tcId);
    if (tc == nullptr) {
      continue;
    }
    const char* tcOwner = Field<const char*>(tc, 0x44);
    if (tcOwner == nullptr || tcOwner == owner || !kIsEnemy(tcOwner, ownerId) ||
        !Virtual<UnitIsAliveFn>(tc, kAliveSlot)(tc)) {
      continue;
    }
    const float distance = Virtual<UnitDistanceFn>(tc, kDistanceSlot)(tc, position);
    if (nearest.tc == nullptr || distance < nearest.distance) {
      nearest = {tc, id, distance};
    }
  }
  return nearest;
}

// With "log": each marked trainer's last state by unit ID (true = paused), so the first tick of
// a trainer and every change are one line each. Logging only; cleared on each database load.
std::unordered_map<std::int32_t, bool> g_paused;
unsigned g_logLines = 0;

// The warning's last game time per trainer ID, for the world and game time it was set in.
// Interface state: it changes only what the local player sees.
std::unordered_map<std::int32_t, std::uint32_t> g_warned;
const char* g_warnWorld = nullptr;
std::uint32_t g_warnTime = 0;

void ClearLogged(char*) {
  g_paused.clear();
  g_warned.clear();
}

// The stock dodge's floating text (floatingtext.h), over a held trainer of the local player, at
// most once every kWarnIntervalMs of game time.
void Warn(const char* trainer) {
  char* world = World();
  if (world == nullptr || PlayerIdOf(trainer) != uhc::LocalPlayer() || !uhc::CanShowUnitText(trainer)) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_warnWorld || static_cast<std::int32_t>(now - g_warnTime) < 0) {
    g_warned.clear();  // another game
    g_warnWorld = world;
  }
  g_warnTime = now;
  const std::int32_t id = Field<std::int32_t>(trainer, 0x10);
  const auto it = g_warned.find(id);
  if (it != g_warned.end() && now - it->second < kWarnIntervalMs) {
    return;
  }
  g_warned[id] = now;
  const std::int32_t shown = uhc::ShowUnitText(trainer, g_warnText.c_str(), g_warnStringId, kWarnColour);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"noTrainNearEnemyTC: warning shown over unit %d (%hs)%ls", id, ProtoName(trainer),
             shown < 0 ? L": refused by the engine" : L"");
  }
}

// "Too_close" (at most 127 characters; UTF-8, else ANSI; '_' for a space) or "90001" (a string table ID).
bool ParseWarning(const std::string& text) {
  if (text.empty()) {
    return false;
  }
  if (text.find_first_not_of("0123456789") == std::string::npos) {
    std::int32_t id = -1;
    const auto [end, ec] = std::from_chars(text.data(), text.data() + text.size(), id);
    g_warnStringId = id;
    return ec == std::errc() && end == text.data() + text.size();
  }
  wchar_t wide[128];  // with its terminator
  int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.c_str(), -1, wide, 128);
  if (length == 0) {
    length = MultiByteToWideChar(CP_ACP, 0, text.c_str(), -1, wide, 128);
  }
  if (length == 0) {
    return false;
  }
  std::replace(wide, wide + length, L'_', L' ');
  g_warnText = wide;
  return true;
}

void LogState(const char* trainer, bool paused, const Nearest& nearest) {
  const std::int32_t id = Field<std::int32_t>(trainer, 0x10);
  const auto [it, added] = g_paused.try_emplace(id, paused);
  if (!added) {
    if (it->second == paused) {
      return;
    }
    it->second = paused;
  }
  if (g_logLines >= kMaxLogLines) {
    return;
  }
  ++g_logLines;
  const wchar_t* what = paused ? L"paused training" : (added ? L"trains" : L"resumed training");
  if (nearest.tc == nullptr) {
    uhc::Log(L"noTrainNearEnemyTC: unit %d (%hs, player %d) %ls: nothing to keep away from", id, ProtoName(trainer),
             PlayerIdOf(trainer), what);
  } else {
    uhc::Log(L"noTrainNearEnemyTC: unit %d (%hs, player %d) %ls: player %d's unit %d (%hs) is %.1f m away "
             L"(limit %.1f m)",
             id, ProtoName(trainer), PlayerIdOf(trainer), what, nearest.player, Field<std::int32_t>(nearest.tc, 0x10),
             ProtoName(nearest.tc), static_cast<double>(nearest.distance), static_cast<double>(g_meters));
  }
  if (g_logLines == kMaxLogLines) {
    uhc::Log(L"noTrainNearEnemyTC: %u lines logged; the next changes are not", kMaxLogLines);
  }
}

bool ParseMeters(const std::string& text, float* meters) {
  float value = 0.0f;
  const auto [end, ec] = std::from_chars(text.data(), text.data() + text.size(), value);
  if (ec != std::errc() || end != text.data() + text.size() || !(value > 0.0f) || value > kMaxMeters) {
    return false;
  }
  *meters = value;
  return true;
}

}  // namespace

extern "C" {
std::int32_t g_uhcNoTrainType = -1;  // marker unittype ID, set on each database load; -1 before

void UhcNoTrainHook();

// Called by the hook on every tick of an active Train action, with its trainer. True: the
// trainer is of the marker type and a blocker (an enemy's FirstTC, or an enemy unit of a "near"
// type) is alive within the configured distance, so this tick adds no progress.
bool __stdcall UhcNoTrainBlocked(const char* trainer) {
  const char* proto = trainer == nullptr ? nullptr : Field<const char*>(trainer, 0x5C);
  if (proto == nullptr || g_uhcNoTrainType < 0 || !kProtoIsType(proto, g_uhcNoTrainType)) {
    return false;
  }
  const Nearest nearest = NearestBlocker(trainer);
  const bool blocked = nearest.tc != nullptr && nearest.distance < g_meters;
  if (g_log) {
    LogState(trainer, blocked, nearest);
  }
  if (blocked && g_warn) {
    Warn(trainer);
  }
  return blocked;
}
}

namespace uhc {

Outcome ApplyNoTrainNearEnemyTc(const Config& config) {
  const auto* lines = config.All("noTrainNearEnemyTC");
  if (lines == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (lines->size() != 1) {
    Log(L"noTrainNearEnemyTC: %u lines, expected one; feature not applied", static_cast<unsigned>(lines->size()));
    return Outcome::kFailed;
  }
  const Config::Args& args = lines->front();
  float meters = 0.0f;
  if (args.empty() || !ParseMeters(args.front(), &meters)) {
    Log(L"noTrainNearEnemyTC: expected \"noTrainNearEnemyTC <meters> [UnitType] [near <UnitType> ...] [nowarn | "
        L"warn=<text>] [log]\" with meters above 0 and at most %.0f, got \"%hs\"; feature not applied",
        static_cast<double>(kMaxMeters), args.empty() ? "" : args.front().c_str());
    return Outcome::kFailed;
  }
  std::string typeName = "AbstractDaimyo";
  bool typeGiven = false;
  bool log = false;
  std::vector<std::string> nearNames;
  for (std::size_t i = 1; i < args.size(); ++i) {
    const char* arg = args[i].c_str();
    if (_stricmp(arg, "log") == 0) {
      log = true;
    } else if (_stricmp(arg, "nowarn") == 0) {
      g_warn = false;
    } else if (_strnicmp(arg, "warn=", 5) == 0) {
      if (!ParseWarning(args[i].substr(5))) {
        Log(L"noTrainNearEnemyTC: %hs: expected warn=<text> (at most 127 characters, '_' for a space) or "
            L"warn=<string table ID>; feature not applied",
            arg);
        return Outcome::kFailed;
      }
    } else if (_stricmp(arg, "near") == 0) {
      if (i + 1 >= args.size() || nearNames.size() == kMaxNear) {
        Log(L"noTrainNearEnemyTC: near needs a unit type (or FirstTC), at most %u; feature not applied",
            static_cast<unsigned>(kMaxNear));
        return Outcome::kFailed;
      }
      nearNames.push_back(args[++i]);
    } else if (!typeGiven) {
      typeName = args[i];
      typeGiven = true;
    } else {
      Log(L"noTrainNearEnemyTC: unexpected argument %hs (expected: <meters> [UnitType] [near <UnitType> ...] [nowarn | "
          L"warn=<text>] [log]); feature not applied",
          arg);
      return Outcome::kFailed;
    }
  }

  // WorkRateTrainCall is also verified by liveBuildingWorkRate, which runs earlier (features.h).
  if (!VerifyAll("noTrainNearEnemyTC",
                 {&sites::kWorkRateTrainCall, &sites::kTrainUpdateTrainer, &sites::kTrainRateScale,
                  &sites::kFirstTcRuleLoop, &sites::kFirstTcRuleFilter, &sites::kPlayerById, &sites::kPlayerByIdNull,
                  &sites::kUnitById, &sites::kUnitByIdNull, &sites::kPlayerIsEnemy, &sites::kIsA, &sites::kIsATrue,
                  &sites::kNoCorpseDoppleAliveCall})) {
    return Outcome::kFailed;
  }
  const bool nearType = std::any_of(nearNames.begin(), nearNames.end(),
                                    [](const std::string& name) { return _stricmp(name.c_str(), "FirstTC") != 0; });
  if (nearType &&
      !VerifyAll("noTrainNearEnemyTC near", {&sites::kUnitsNearPoint, &sites::kTypeRuleQuery, &sites::kIsBuilt})) {
    return Outcome::kFailed;
  }
  if (g_warn && !uhc::VerifyFloatingText("noTrainNearEnemyTC warning")) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(typeName.c_str(), &g_uhcNoTrainType)) {
    return Outcome::kFailed;
  }
  if (!nearNames.empty()) {
    g_nearCount = nearNames.size();
    for (std::size_t i = 0; i < nearNames.size(); ++i) {
      g_nearNames[i] = nearNames[i];
      g_nearTypes[i] = kFirstTc;
      if (_stricmp(nearNames[i].c_str(), "FirstTC") != 0 &&
          !RequestAbstractUnitType(nearNames[i].c_str(), &g_nearTypes[i])) {
        return Outcome::kFailed;
      }
    }
  }
  g_meters = meters;
  g_log = log;
  if ((log || g_warn) && !OnDatabaseLoad(&ClearLogged)) {
    return Outcome::kFailed;
  }
  // Replaces mov ecx,[esi+10h] / call 9BFE33h at 0x9EA410; the hook re-executes them.
  if (!WriteJmp(sites::kWorkRateTrainCall.va, reinterpret_cast<const void*>(&UhcNoTrainHook), 8)) {
    return Outcome::kFailed;
  }
  std::string blockers;  // not "near": windows.h defines it as a macro
  for (std::size_t i = 0; i < g_nearCount; ++i) {
    blockers += i == 0 ? "" : ", ";
    blockers += g_nearTypes[i] == kFirstTc ? std::string("an enemy's first Town Center (FirstTC)")
                                           : "an enemy's " + g_nearNames[i];
  }
  Log(L"noTrainNearEnemyTC: units of unittype %hs do not train within %.1f m (from the trainer's centre to the "
      L"edge of the building) of %hs%ls%ls (multiplayer unverified)",
      typeName.c_str(), static_cast<double>(meters), blockers.c_str(),
      g_warn ? L", with a warning over the local player's held units" : L"",
      log ? L", every pause and resume logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/notrainneartc_hooks.asm

```asm
; Hook for noTrainNearEnemyTC. Entered through a jmp written over the stock code; leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Training near an enemy Town
; Center").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcNoTrainType:SDWORD      ; marker unittype ID, set on each database load; -1 before
; float thiscall(unit): the trainer's BuildingWorkRate in st0. 0x9BFE33 (the stock getter), or
; buildingWorkRateAuras' wrapper, which multiplies in the unit's auras (features/bwrauras.cpp).
EXTERNDEF g_uhcBwrTrainGetter:DWORD

UhcNoTrainBlocked PROTO STDCALL trainer:DWORD

.data
trainRateNext   dd 009EA418h    ; mov ebx,[0C66234h] / mov eax,[ebx+13Ch] / fmul [eax+310h]

.code

; Replaces 0x9EA410..0x9EA417 (mov ecx,[esi+10h] / call 9BFE33h) in FUN_009EA28B, the Train
; update, where an active queue reads its trainer's work rate; the code after it multiplies the
; rate by the game speed and the civ's train rate and adds it to the progress [esi+68h].
; ESI = the Train action (trainer at [esi+10h]), EDI = the trainer's player, and the x87 stack is
; empty (no x87 code runs in the function before this point). A trainer that UhcNoTrainBlocked
; holds gets the rate 0.0, so the queue keeps its progress and waits; any other trainer runs the
; two stolen instructions. Both paths leave st0 = the rate, one x87 slot, as the getter does.
; EAX, EBX and ECX are written after 0x9EA418 before they are read, EDX is not read (0x485D2C,
; called at 0x9EA432, overwrites it), nor are the flags; the helper keeps ESI, EDI, EBP and EBX.
UhcNoTrainHook PROC
    TRACE_ONCE "noTrainNearEnemyTC (0x9EA410)"
    cmp g_uhcNoTrainType, 0
    jl stock
    push dword ptr [esi+10h]        ; the trainer
    call UhcNoTrainBlocked          ; bool: marked, and a blocker is alive within range
    test al, al
    je stock
    fldz                            ; rate 0.0: no progress this tick
    jmp trainRateNext
stock:
    mov ecx, dword ptr [esi+10h]    ; stolen 0x9EA410
    call g_uhcBwrTrainGetter        ; stolen 0x9EA413 (call 9BFE33h), or the aura wrapper
    jmp trainRateNext
UhcNoTrainHook ENDP

END
```

## lifespanAfterConstruction

Contract: [lifespanAfterConstruction](../porting-to-another-dll.md#lifespanafterconstruction).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `IsA` `0x44D7FA` (105 B), `IsBuilt` `0x44DDB4` (31 B), `IsATrue` `0x44F139` (5 B), `FadeUpdateHead` `0x4829FA` (32 B), `FadeTimerCommit` `0x482A1A` (12 B), `FadeDispatch` `0x482A26` (99 B), `LifespanTickHead` `0x482BF6` (42 B), `LifespanTickReturn` `0x482C20` (5 B), `LifespanTick` `0x483EEC` (12 B), `FadeOutTimerTest` `0x4A174A` (21 B), `IsBuiltFalse` `0x69F904` (3 B).

### src/features/lifespan.cpp

```cpp
// lifespanAfterConstruction: a building's <Lifespan> counts from the end of its construction,
// not from the moment its foundation is placed.
//
// Stock arms a unit's lifespan once, when the unit is created: unit init FUN_00498274 calls
// setLifespan 0x48DCB9 with [proto+ACh]. A foundation is created when it is placed, so its
// countdown [[unit+B4h]+1Ch] runs during construction, and with AlphaFadeLifespan so does its
// fade-out timer [[unit+B4h]+88h], whose end kills the unit by itself. Completion
// (FUN_006A1F82) touches neither. For a unit whose proto has a marker unittype (default
// AbstractLifespanAfterConstruction), that is alive (state bit 11 clear) and not fully built,
// two hooks skip the store that advances each timer: both keep their full value until the
// percent reaches 100 %, then run as in stock. A destroyed or deleted foundation is never held,
// so its corpse fades and leaves as in stock. The hooks are in hooks/lifespan_hooks.asm.
#include <cstdint>
#include <cstring>
#include <set>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
std::int32_t g_uhcLifespanType = -1;      // marker unittype ID, set on each database load
std::int32_t g_uhcLifespanLog = 0;        // "lifespanAfterConstruction ... log"
std::int32_t g_uhcLifespanHeldCount = 0;  // logged held units whose countdown has not run again yet

void UhcLifespanTickHook();
void UhcLifespanFadeHook();
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world

using IsBuiltFn = bool(__thiscall*)(const char* unit);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kIsBuilt = reinterpret_cast<IsBuiltFn>(0x0044DDB4);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* MainWorld() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

// Game time in ms, [world+108h].
std::uint32_t GameTime() {
  const char* world = MainWorld();
  return world == nullptr ? 0 : Field<std::uint32_t>(world, 0x108);
}

const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

// The unit's sub-object [unit+B4h] holds the countdown (+1Ch), the fade duration (+84h) and the
// time left before the fade starts (+88h); the stock tick reads it without a null check.
float SubFloat(const char* unit, std::uint32_t offset) { return Field<float>(Field<const char*>(unit, 0xB4), offset); }

// Build percent [[unit+68h]+8], 0..1; a unit without BuildInfo counts as built.
float BuiltPercent(const char* unit) {
  const char* build = Field<const char*>(unit, 0x68);
  return build == nullptr ? 100.0f : Field<float>(build, 0x08) * 100.0f;
}

// State bit 11 of the bitset [unit+4] (bit count [unit+8]): set by the kill handler, so the
// lifespan expiry only removes the corpse.
bool Dying(const char* unit) {
  return Field<std::uint32_t>(unit, 0x08) > 11 && (Field<const std::uint8_t*>(unit, 0x04)[1] & 0x08) != 0;
}

// Unit IDs whose held countdown / fade-out was logged. A countdown leaves g_held when it runs
// again, so each hold and each start is one line.
std::set<std::int32_t> g_held;
std::set<std::int32_t> g_fadeHeld;
const char* g_logWorld = nullptr;
std::uint32_t g_logStep = 0;

void Forget() {
  g_held.clear();
  g_fadeHeld.clear();
  g_uhcLifespanHeldCount = 0;
}

// Unit IDs start again in every game: forget the logged units when another main world runs, or
// when its step count [world+F8h] (raised by 1 per step at 0x481A87) goes back.
void SyncGame() {
  const char* world = MainWorld();
  const std::uint32_t step = world == nullptr ? 0 : Field<std::uint32_t>(world, 0xF8);
  if (world != g_logWorld || step < g_logStep) {
    Forget();
  }
  g_logWorld = world;
  g_logStep = step;
}

// From the database load hook (unittypes.h): the data of another game is being loaded.
void ForgetOnDataLoad(char*) {
  Forget();
  g_logWorld = nullptr;
}

}  // namespace

extern "C" {

// From the tick hook, only with "log": the countdown of a held unit did not advance this step.
void __stdcall UhcLifespanHeld(const char* unit) {
  SyncGame();
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (g_held.insert(id).second) {
    g_uhcLifespanHeldCount = static_cast<std::int32_t>(g_held.size());
    uhc::Log(L"lifespanAfterConstruction: unit %d (%hs) is %.0f %% built; its lifespan (%.2f s left) waits for "
             L"the construction (game time %u ms)",
             id, ProtoName(unit), BuiltPercent(unit), SubFloat(unit, 0x1C), GameTime());
  }
}

// From the tick hook, only with "log" and while g_held is not empty: a countdown runs this step.
// For a unit that was held, logs why it runs again.
void __stdcall UhcLifespanTicking(const char* unit) {
  SyncGame();
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (g_held.erase(id) == 0) {
    return;
  }
  g_uhcLifespanHeldCount = static_cast<std::int32_t>(g_held.size());
  const char* proto = Field<const char*>(unit, 0x5C);
  const wchar_t* why = L"is no longer held; its lifespan runs";
  if (Dying(unit)) {
    why = L"is dying; its lifespan runs as in stock";
  } else if (kIsBuilt(unit)) {
    why = L"is built; its lifespan starts";
  } else if (proto != nullptr && !kProtoIsType(proto, g_uhcLifespanType)) {
    why = L"lost the marker unittype; its lifespan runs";
  }
  uhc::Log(L"lifespanAfterConstruction: unit %d (%hs) %ls with %.2f s left (game time %u ms)", id, ProtoName(unit),
           why, SubFloat(unit, 0x1C), GameTime());
}

// From the fade hook, only with "log": the lifespan fade-out of a held unit did not advance.
void __stdcall UhcLifespanFadeHeld(const char* unit) {
  SyncGame();
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (g_fadeHeld.insert(id).second) {
    uhc::Log(L"lifespanAfterConstruction: unit %d (%hs) is %.0f %% built; its fade-out (due in %.2f s, %.2f s "
             L"long) waits for the construction (game time %u ms)",
             id, ProtoName(unit), BuiltPercent(unit), SubFloat(unit, 0x88), SubFloat(unit, 0x84), GameTime());
  }
}

}  // extern "C"

namespace uhc {

Outcome ApplyLifespanAfterConstruction(const Config& config) {
  const Config::Args* args = config.First("lifespanAfterConstruction");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::string typeName = "AbstractLifespanAfterConstruction";
  bool typeGiven = false;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (!typeGiven) {
      typeName = arg;
      typeGiven = true;
    } else {
      Log(L"lifespanAfterConstruction: unexpected argument %hs (expected: [UnitType] [log]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("lifespanAfterConstruction",
                 {&sites::kLifespanTickHead, &sites::kLifespanTick, &sites::kLifespanTickReturn,
                  &sites::kFadeUpdateHead, &sites::kFadeTimerCommit, &sites::kFadeDispatch,
                  &sites::kFadeOutTimerTest, &sites::kIsBuilt, &sites::kIsBuiltFalse, &sites::kIsA,
                  &sites::kIsATrue})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(typeName.c_str(), &g_uhcLifespanType) ||
      (log && !OnDatabaseLoad(&ForgetOnDataLoad))) {
    return Outcome::kFailed;
  }
  g_uhcLifespanLog = log ? 1 : 0;
  if (!WriteJmp(sites::kLifespanTick.va, reinterpret_cast<const void*>(&UhcLifespanTickHook), 10)) {
    return Outcome::kFailed;
  }
  // The tick hook alone would let an AlphaFadeLifespan foundation fade out and then hold it at
  // 2e-6 s until completion: put the stock bytes back rather than run half the feature.
  if (!WriteJmp(sites::kFadeTimerCommit.va, reinterpret_cast<const void*>(&UhcLifespanFadeHook), 6)) {
    WriteBytes(sites::kLifespanTick.va, sites::kLifespanTick.bytes, 10);
    return Outcome::kFailed;
  }
  Log(L"lifespanAfterConstruction: units of unittype %hs keep their Lifespan and its fade-out until their "
      L"construction is finished%ls (multiplayer unverified)",
      typeName.c_str(), log ? L", every hold and start logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/lifespan_hooks.asm

```asm
; Hooks for lifespanAfterConstruction. Entered through a jmp written over the stock code; each
; leaves through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Lifespan
; and construction").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcLifespanType:SDWORD       ; marker unittype ID, set on each database load; -1 before
EXTERNDEF g_uhcLifespanLog:SDWORD        ; 1 with "lifespanAfterConstruction ... log"
EXTERNDEF g_uhcLifespanHeldCount:SDWORD  ; logged held units not yet running again (log only)

UhcLifespanHeld PROTO STDCALL unit:DWORD
UhcLifespanTicking PROTO STDCALL unit:DWORD
UhcLifespanFadeHeld PROTO STDCALL unit:DWORD

.data
isBuilt         dd 0044DDB4h    ; bool thiscall(unit): no BuildInfo [unit+68h], or percent [+8] >= 1.0
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): proto IDs and abstract types
tickNext        dd 00483EF6h    ; fnstsw ax / test ah,41h / jne 482C20h (dt <= 0: no countdown)
tickReturn      dd 00482C20h    ; pop esi / pop ecx / ret 4: the lifespan tick's exit
fadeCommit      dd 00482A20h    ; mov [eax+88h],ecx: store the fade timer t
fadeSkip        dd 00482A26h    ; cmp dword ptr [esi+8],3Dh: the fade branches, timer not stored

.code

; Replaces 0x483EEC..0x483EF5 (fld dword ptr [esp+0Ch] / fcomp dword ptr [0B84BE4h], dt against
; 0), the start of the cold part of the lifespan tick FUN_00482BF6, which only runs for a unit
; whose lifespan is armed (state bit 3). ESI = unit; [esp] = saved ESI, [esp+4] = local,
; [esp+8] = return address, [esp+0Ch] = dt. EAX, ECX and EDX are free (the stock code writes
; them before it reads them); EBX, EDI and EBP are the caller's. A unit that is alive (state
; bit 11 clear, the test the stock expiry makes), not fully built and of the marker type leaves
; through the stock exit 0x482C20, the one taken for dt <= 0: no countdown, no expiry. Any other
; unit re-executes the two instructions and continues at 0x483EF6.
UhcLifespanTickHook PROC
    TRACE_ONCE "lifespanAfterConstruction (0x483EEC)"
    cmp g_uhcLifespanType, 0
    jl stock
    cmp dword ptr [esi+8], 0Bh      ; bit count of the unit state [esi+4]
    jbe alive
    mov ecx, dword ptr [esi+4]
    test byte ptr [ecx+1], 08h      ; bit 11: dead or dying, the expiry only removes the corpse
    jne ticking
alive:
    mov ecx, esi
    call isBuilt                    ; changes EAX only
    test al, al
    jne ticking
    mov ecx, dword ptr [esi+5Ch]    ; proto
    test ecx, ecx
    je ticking
    push g_uhcLifespanType
    call protoIsType
    test al, al
    je ticking
    cmp g_uhcLifespanLog, 0
    je hold
    pushad
    push esi
    call UhcLifespanHeld
    popad
hold:
    jmp tickReturn
ticking:
    cmp g_uhcLifespanHeldCount, 0
    je stock
    pushad
    push esi
    call UhcLifespanTicking         ; logs a held unit whose countdown runs again
    popad
stock:
    fld dword ptr [esp+0Ch]         ; stolen 0x483EEC: dt
    fcomp dword ptr ds:[0B84BE4h]   ; stolen 0x483EF0: against 0.0
    jmp tickNext
UhcLifespanTickHook ENDP

; Replaces 0x482A1A..0x482A1F (jne 482A26h / mov ecx,[esp+10h]) in the fade update FUN_004829FA,
; which runs for every unit on every step. t = [sub+88h] - dt is in [esp+10h], and 0x482A20
; stores it when the commit flag is set (the flags of cmp bl,1 at 0x482A00). EAX = the unit's
; sub-object [esi+0B4h], ESI = unit, EBX = commit flag; [esp] = saved ESI, [esp+4] = saved EBX,
; [esp+8] = local, [esp+0Ch] = return address, [esp+10h] = t, [esp+14h] = commit. ECX and EDX
; are reloaded at 0x482A2A and 0x482A30. A unit whose pending fade is the lifespan fade-out
; (state bits 5 and 3 set; bits 4 and 61, whose fades take priority with the same timer, clear),
; alive (bit 11 clear: a corpse's fade is the same bit 5), not fully built and of the marker type
; keeps its stored timer, and this step sees that value as t: the fade-out neither advances nor
; starts. Every other unit runs the stock code.
UhcLifespanFadeHook PROC
    TRACE_ONCE "lifespanAfterConstruction fade (0x482A1A)"
    jne skip                        ; stolen 0x482A1A: no commit asked
    cmp g_uhcLifespanType, 0
    jl commit
    mov edx, dword ptr [esi+8]      ; bit count of the unit state
    cmp edx, 5
    jbe commit
    mov ecx, dword ptr [esi+4]      ; unit state bits
    test byte ptr [ecx], 20h        ; bit 5: fade-out pending
    je commit
    test byte ptr [ecx], 10h        ; bit 4: a fade-in, which takes priority
    jne commit
    test byte ptr [ecx], 08h        ; bit 3: the lifespan is armed
    je commit
    cmp edx, 0Bh
    jbe alive
    test byte ptr [ecx+1], 08h      ; bit 11: dead or dying
    jne commit
    cmp edx, 3Dh
    jbe alive
    test byte ptr [ecx+7], 20h      ; bit 61: another fade, which takes priority
    jne commit
alive:
    push eax                        ; the sub-object, needed by the stock store
    mov ecx, esi
    call isBuilt
    test al, al
    jne notHeld
    mov ecx, dword ptr [esi+5Ch]    ; proto
    test ecx, ecx
    je notHeld
    push g_uhcLifespanType
    call protoIsType
    test al, al
    je notHeld
    cmp g_uhcLifespanLog, 0
    je hold
    pushad
    push esi
    call UhcLifespanFadeHeld
    popad
hold:
    pop eax
    mov ecx, dword ptr [eax+88h]    ; the stored timer: no time passes for this fade-out
    mov dword ptr [esp+10h], ecx
    jmp fadeSkip
notHeld:
    pop eax
commit:
    mov ecx, dword ptr [esp+10h]    ; stolen 0x482A1C
    jmp fadeCommit
skip:
    jmp fadeSkip
UhcLifespanFadeHook ENDP

END
```

## gaiaSocketsOnly

Contract: [gaiaSocketsOnly](../porting-to-another-dll.md#gaiasocketsonly).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `GaiaSocketLoopNext` `0x50757E` (17 B), `GaiaSocketMatch` `0x508BE6` (219 B), `GaiaSocketFound` `0x508CC1` (10 B), `GaiaSocketMissing` `0x509215` (21 B).

### src/features/sockets.cpp

```cpp
// gaiaSocketsOnly: a socketed building (one whose proto has <SocketUnitType>, e.g. TradingPost)
// may only be placed on a socket that Gaia owns.
//
// Stock tests the owner in one place only: the UI's snap to a socket (FUN_00A036BB, 0xA0383B)
// takes only Gaia sockets as candidates, so the placement preview shows a socket a player owns in
// red. The check that decides, FUN_0050703D ("PLACE", World vtable +14h: run by the build
// command on every machine, by uiBuildAtPointer's pre-check and by the AI's checkPlacement),
// accepts any socket of the right type at exactly the building's position and never reads its
// owner. Stock data never shows it, because every stock socket has ForceToGaia; a mod socket that
// a player owns (e.g. a mine socket) is red in the preview, but an order that carries its exact
// position (AI, triggers) builds on it anyway.
//
// The hook (hooks/socket_hooks.asm) sits where PLACE records "socket found" (0x508CC1). When the
// check uses a player's knowledge (its a5 != 0: the build commands, the UI and the AI) and the
// socket's owner is not Gaia, the socket does not count, and PLACE fails through its stock "no
// socket here" path. Without a unittype the rule covers every socket; with one, only sockets of
// that type (or proto name; an extra abstract type, unittypes.h), and every other socket keeps
// the stock rule. Placement with a5 = 0 (the editor, the engine, the in-place conversion
// command 13h) is left alone. The rule reads only the socket's owner, the placing player and the
// data, so every machine decides alike.
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <set>
#include <string>
#include <tuple>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

// An AI build plan that picked a refused socket retries its checkPlacement, maybe on every update
// (0x73E273 takes the first socket of the right type), so each refusal is logged once per socket,
// owner, player and building, and at most this many in all.
constexpr std::size_t kMaxLogged = 1000;

bool g_markerOnly = false;       // "gaiaSocketsOnly <UnitType>": only sockets of that unittype
std::int32_t g_markerType = -1;  // its ID, set on each database load; -1 before
bool g_log = false;              // "gaiaSocketsOnly ... log": log the refusals
std::set<std::tuple<std::int32_t, std::int32_t, std::int32_t, std::int32_t>> g_logged;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Name(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* g_logWorld = nullptr;  // the game g_logged belongs to
std::uint32_t g_logStep = 0;

void LogRefusal(const char* socket, std::int32_t owner, const char* building, std::int32_t player) {
  // Unit IDs start again in every game: a new world, or a step count [world+F8h] that went back,
  // forgets the refusals logged so far.
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const std::uint32_t step = world == nullptr ? 0 : Field<std::uint32_t>(world, 0xF8);
  if (world != g_logWorld || step < g_logStep) {
    g_logged.clear();
  }
  g_logWorld = world;
  g_logStep = step;
  const std::int32_t socketId = Field<std::int32_t>(socket, 0x10);
  const std::int32_t buildingId = Field<std::int32_t>(building, 0x04);
  if (g_logged.size() >= kMaxLogged || !g_logged.insert({socketId, owner, player, buildingId}).second) {
    return;
  }
  uhc::Log(L"gaiaSocketsOnly: refused %hs for player %d on socket %d (%hs), owned by player %d", Name(building), player,
           socketId, Name(Field<const char*>(socket, 0x5C)), owner);
  if (g_logged.size() == kMaxLogged) {
    uhc::Log(L"gaiaSocketsOnly: %u refusals logged; further ones are not", static_cast<unsigned>(kMaxLogged));
  }
}

}  // namespace

extern "C" {
void UhcGaiaSocketFoundHook();

// From the hook, for a socket of the building's type at exactly its position, in a check that uses
// the player's knowledge. False: the socket does not count. `socket` is the socket unit, `building`
// the proto being placed, `player` the placing player (PLACE's a1).
bool __stdcall UhcGaiaSocketAllowed(const char* socket, const char* building, std::int32_t player) {
  if (g_markerOnly) {
    const char* proto = Field<const char*>(socket, 0x5C);
    if (g_markerType < 0 || proto == nullptr || !kProtoIsType(proto, g_markerType)) {
      return true;  // not a marked socket: stock rule
    }
  }
  const char* owner = Field<const char*>(socket, 0x44);
  if (owner == nullptr) {
    return true;  // never seen; the stock snap would read through it
  }
  const std::int32_t ownerId = Field<std::int32_t>(owner, 0x00);
  if (ownerId == 0) {
    return true;
  }
  if (g_log) {
    LogRefusal(socket, ownerId, building, player);
  }
  return false;
}
}

namespace uhc {

Outcome ApplyGaiaSocketsOnly(const Config& config) {
  const Config::Args* args = config.First("gaiaSocketsOnly");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }

  std::string typeName;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (typeName.empty()) {
      typeName = arg;
    } else {
      Log(L"gaiaSocketsOnly: unexpected argument %hs (expected: [UnitType] [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("gaiaSocketsOnly", {&sites::kGaiaSocketMatch, &sites::kGaiaSocketFound, &sites::kGaiaSocketLoopNext,
                                     &sites::kGaiaSocketMissing})) {
    return Outcome::kFailed;
  }
  g_log = log;
  g_markerOnly = !typeName.empty();
  if (g_markerOnly && !RequestAbstractUnitType(typeName.c_str(), &g_markerType)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kGaiaSocketFound.va, reinterpret_cast<const void*>(&UhcGaiaSocketFoundHook), 5)) {
    return Outcome::kFailed;
  }
  if (g_markerOnly) {
    Log(L"gaiaSocketsOnly: sockets of unittype %hs take a socketed building only while Gaia owns them%ls "
        L"(multiplayer unverified)",
        typeName.c_str(), log ? L", refusals logged" : L"");
  } else {
    Log(L"gaiaSocketsOnly: socketed buildings take only sockets owned by Gaia%ls (multiplayer unverified)",
        log ? L", refusals logged" : L"");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/socket_hooks.asm

```asm
; Hook for gaiaSocketsOnly. Entered through a jmp written over the stock code; leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Sockets and placement").
.686
.model flat, c
option casemap :none

include common.inc

UhcGaiaSocketAllowed PROTO STDCALL socket:DWORD, building:DWORD, player:DWORD

.data
socketFoundNext dd 00508CC6h    ; jmp 50757Eh: PLACE's next obstruction entry

.code

; Replaces 0x508CC1 (mov byte ptr [esp+37h],1) in FUN_0050703D, PLACE, where a socketed building
; records that a socket of its type stands exactly at its position. Reached only by falling
; through from 0x508CBB: ESI = the socket unit + 14h (its position), EDI = the building's proto,
; EBP = the world; PLACE's frame: a1 (the player) at [esp+1C0h], a5 (knowledge) at [esp+1D0h],
; the found flag at [esp+37h]. EAX, ECX, EDX and the flags are dead at the continuation; the
; helper keeps EBX, ESI, EDI and EBP. With a5 = 0 (editor, engine, in-place conversion), or a
; socket the rule accepts, the flag is set as in stock; otherwise the socket does not count.
UhcGaiaSocketFoundHook PROC
    TRACE_ONCE "gaiaSocketsOnly (0x508CC1)"
    cmp dword ptr [esp+1D0h], 0     ; a5 = 0: placement without a player's knowledge
    je found
    lea eax, [esi-14h]              ; the socket unit
    push dword ptr [esp+1C0h]       ; a1, the placing player
    push edi                        ; the building's proto
    push eax
    call UhcGaiaSocketAllowed       ; -> al = 0 when the rule refuses the socket's owner
    test al, al
    je refused
found:
    mov byte ptr [esp+37h], 1       ; stolen 0x508CC1: socket found
refused:
    jmp socketFoundNext
UhcGaiaSocketFoundHook ENDP

END
```

## hcShipmentPointFallback

Contract: [hcShipmentPointFallback](../porting-to-another-dll.md#hcshipmentpointfallback).

Sites: `PlayerById` `0x44CB21` (30 B), `UnitById` `0x44CC6D` (58 B), `PlayerByIdNull` `0x4649E1` (5 B), `GatherFallbackStore` `0x4C6CB2` (12 B), `UnitByIdNull` `0x4E2A35` (5 B), `GatherFallbackBlock` `0x6698B4` (176 B), `GatherFallbackExit` `0x669E2E` (10 B), `FirstTcSet` `0x67ABD4` (14 B), `GatherPointValid` `0x85302C` (56 B).

### src/features/shipments.cpp

```cpp
// hcShipmentPointFallback <Proto|FirstTC> [...]: when the home city gather unit is gone and none of
// the 10 stock fallback types is left (TownCenter, then Outpost, FortFrontier, WarHut, Blockhouse,
// NoblesHut, AbstractAgraFort, AbstractDaimyo, ypCastle, ypVillage), try the entries listed in
// uhc.cfg, in order. An entry is a proto unit name, or the keyword FirstTC: the player's first town
// center, the unit ID at [player+4F0h] that the placement rules call FirstTC. Stock makes only a
// TownCenter FirstTC, which the stock list already tries first, so FirstTC is useful with
// startingTC (a marked building can be FirstTC). The hook is in hooks/shipment_hooks.asm.
#include <windows.h>

#include <cstdint>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr int kMaxFallbackTypes = 64;
// The entry of the keyword FirstTC; -1 is an unknown proto, >= 0 a proto ID.
constexpr std::int32_t kFirstTcEntry = -2;
constexpr char kFirstTcKeyword[] = "FirstTC";

// Engine layout (docs/engine-symbols.md, "Home city gather point").
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint32_t kHcPlayer = 0x08;          // home city: its player; [player+0] the player ID
constexpr std::uint32_t kPlayerFirstTc = 0x4F0;    // unit ID of the player's first town center; -1 none
constexpr std::uint32_t kUnitId = 0x10;
constexpr std::uint32_t kUnitOwner = 0x44;  // the owning Player*
constexpr std::uint32_t kUnitProto = 0x5C;  // proto; [proto+10h] its name
constexpr int kMaxLoggedPlayers = 32;

using PlayerByIdFn = const char*(__thiscall*)(char* world, std::int32_t id);
using UnitByIdFn = const char*(__thiscall*)(char* world, std::int32_t id);
using GatherPointValidFn = bool(__thiscall*)(const char* hc, const char* unit);

const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
// The check stock applies to the stored point and to every candidate: not null, alive (unit vtable
// slot A4h), 0x44DDB4 true, 0x4802C6 not 1.
const auto kGatherPointValid = reinterpret_cast<GatherPointValidFn>(0x0085302C);

// Proto names from uhc.cfg; resolved to IDs only once the game database exists.
std::vector<std::string> g_typeNames;

// Log only: the FirstTC unit last logged per player ID, and the world it was logged in. The game
// never reads them, so they cannot make two machines disagree.
const char* g_loggedWorld = nullptr;
std::int32_t g_loggedFirstTc[kMaxLoggedPlayers];

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

char* World() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<char*>(game, 0x13C);
}

const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, kUnitProto);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

bool IsFirstTcKeyword(const std::string& name) { return _stricmp(name.c_str(), kFirstTcKeyword) == 0; }

void LogFirstTcPick(const char* world, std::int32_t playerId, const char* unit) {
  if (playerId < 0 || playerId >= kMaxLoggedPlayers) {
    return;
  }
  if (world != g_loggedWorld) {
    g_loggedWorld = world;
    for (std::int32_t& id : g_loggedFirstTc) {
      id = -1;
    }
  }
  const std::int32_t id = Field<std::int32_t>(unit, kUnitId);
  if (g_loggedFirstTc[playerId] == id) {
    return;
  }
  g_loggedFirstTc[playerId] = id;
  uhc::Log(L"hcShipmentPointFallback: player %d's shipment point -> unit %d (%hs), its first town center (FirstTC)",
           playerId, id, ProtoName(unit));
}

}  // namespace

extern "C" {
std::int32_t g_uhcGatherFallbackTypes[kMaxFallbackTypes];
std::int32_t g_uhcGatherFallbackCount = 0;

void UhcHcGatherFallbackHook();

// Called once from the hook, inside the simulation, when the database is loaded.
void __stdcall UhcResolveGatherFallbackTypes() {
  using ProtoIdByName = int(__thiscall*)(void* database, const char* name);
  const auto protoIdByName = reinterpret_cast<ProtoIdByName>(0x005A2346);
  void* game = *reinterpret_cast<void**>(kGameGlobal);
  void* database = game == nullptr ? nullptr : *reinterpret_cast<void**>(static_cast<char*>(game) + 0x140);
  for (int i = 0; i < g_uhcGatherFallbackCount; ++i) {
    // The keyword comes first: the hook must never run a unit query for it.
    if (IsFirstTcKeyword(g_typeNames[i])) {
      g_uhcGatherFallbackTypes[i] = kFirstTcEntry;
      uhc::Log(L"hcShipmentPointFallback: FirstTC -> each player's first town center (FirstTC)");
      continue;
    }
    const int id = database == nullptr ? -1 : protoIdByName(database, g_typeNames[i].c_str());
    g_uhcGatherFallbackTypes[i] = id;
    uhc::Log(L"hcShipmentPointFallback: %hs -> proto %d%ls", g_typeNames[i].c_str(), id,
             id < 0 ? L" (unknown proto; skipped)" : L"");
  }
}

// Called from the hook for a FirstTC entry, [esp+10h] of FUN_004C6B9E = the home city. Returns the
// player's first town center if it still belongs to that player and passes the stock gather point
// check 0x85302C, else null. It writes no game state: the store=0 callers (the UI among them) may
// run it every frame, and the store=1 path stores the result in stock code (0x4C6CB2).
const char* __stdcall UhcGatherFirstTcUnit(const char* hc) {
  char* world = World();
  if (world == nullptr || hc == nullptr) {
    return nullptr;
  }
  const char* hcPlayer = Field<const char*>(hc, kHcPlayer);
  if (hcPlayer == nullptr) {
    return nullptr;
  }
  const std::int32_t playerId = Field<std::int32_t>(hcPlayer, 0x00);
  const char* player = kPlayerById(world, playerId);
  if (player == nullptr) {
    return nullptr;
  }
  const std::int32_t id = Field<std::int32_t>(player, kPlayerFirstTc);
  if (id < 0) {
    return nullptr;
  }
  const char* unit = kUnitById(world, id);
  if (unit == nullptr) {
    return nullptr;
  }
  // FirstTC is never cleared: a converted or captured one belongs to someone else now.
  const char* owner = Field<const char*>(unit, kUnitOwner);
  if (owner == nullptr || Field<std::int32_t>(owner, 0x00) != playerId) {
    return nullptr;
  }
  if (!kGatherPointValid(hc, unit)) {
    return nullptr;
  }
  LogFirstTcPick(world, playerId, unit);
  return unit;
}
}

namespace uhc {

// FUN_004C6B9E returns the unit shipments arrive at. When the stored one is gone it searches a
// fixed list of 10 unit types; this extends that list. Choice order is the cfg order, then the
// stock unit-query order, so every machine with the same cfg picks the same building.
Outcome ApplyHcShipmentPointFallback(const Config& config) {
  const Config::Args* names = config.First("hcShipmentPointFallback");
  if (names == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (names->empty() || names->size() > kMaxFallbackTypes) {
    Log(L"hcShipmentPointFallback: expected 1 to %d proto unit names or FirstTC", kMaxFallbackTypes);
    return Outcome::kFailed;
  }
  bool firstTc = false;
  for (const std::string& name : *names) {
    firstTc = firstTc || IsFirstTcKeyword(name);
  }
  // FirstTC also reads [player+4F0h] (set at 0x67ABD4), player and unit by ID and the stored point
  // check; no feature writes those sites.
  const bool verified =
      firstTc ? VerifyAll("hcShipmentPointFallback",
                          {&sites::kGatherFallbackExit, &sites::kGatherFallbackStore, &sites::kGatherFallbackBlock,
                           &sites::kFirstTcSet, &sites::kPlayerById, &sites::kPlayerByIdNull, &sites::kUnitById,
                           &sites::kUnitByIdNull, &sites::kGatherPointValid})
              : VerifyAll("hcShipmentPointFallback",
                          {&sites::kGatherFallbackExit, &sites::kGatherFallbackStore, &sites::kGatherFallbackBlock});
  if (!verified) {
    return Outcome::kFailed;
  }
  if (firstTc && config.First("startingTC") == nullptr && config.First("civFirstTC") == nullptr) {
    Log(L"hcShipmentPointFallback: FirstTC without startingTC: a first town center can only be a TownCenter, which "
        L"the stock list already tries first");
  }
  g_typeNames = *names;
  for (int& id : g_uhcGatherFallbackTypes) {
    id = -1;
  }
  g_uhcGatherFallbackCount = static_cast<std::int32_t>(g_typeNames.size());
  if (!WriteJmp(sites::kGatherFallbackExit.va, reinterpret_cast<const void*>(&UhcHcGatherFallbackHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"hcShipmentPointFallback: %d extra types after the stock list%ls (multiplayer unverified)",
      g_uhcGatherFallbackCount, firstTc ? L", including each player's first town center (FirstTC)" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/shipment_hooks.asm

```asm
; Hook for hcShipmentPointFallback. Entered through a jmp written over the stock code; leaves
; through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Home city
; gather point").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcGatherFallbackTypes:DWORD    ; proto IDs, resolved on first use
EXTERNDEF g_uhcGatherFallbackCount:SDWORD
UhcResolveGatherFallbackTypes PROTO STDCALL
UhcGatherFirstTcUnit PROTO STDCALL hc:DWORD   ; the player's FirstTC if it is a valid point, else 0

FIRST_TC_ENTRY EQU -2                       ; g_uhcGatherFallbackTypes entry of the keyword FirstTC

.data
querySetPlayer   dd 00453618h   ; thiscall(query, 0, playerId, 1)
queryAddType     dd 0045356Dh   ; thiscall(query, 0, protoId)
querySetState    dd 004532B4h   ; thiscall(query, 0, 2 = alive)
queryRun         dd 00453484h   ; thiscall(query, 0) -> count
queryUnitId      dd 00453A36h   ; thiscall(query, 0, index) -> unit ID
unitCheckA       dd 0044DDB4h   ; thiscall(unit) -> bool, required
unitCheckB       dd 004802C6h   ; thiscall(unit) -> 1 rejects the unit
storeAndReturn   dd 004C6CB2h   ; stores [hc+18Ch] = [EDI+10h] if [esp+18h] == 1; returns EDI
notFoundReturn   dd 00669E33h   ; pop ebx / pop ecx / ret 4
typeIndex        dd 0
resolved         db 0

.code

; Replaces 0x669E2E..0x669E32, the "no valid gather unit" exit of FUN_004C6B9E, reached after
; the stock search of its ten fixed unit types (TownCenter at 0x4C6BF1, then nine in the cold
; chunk 0x669804..0x669E2C). State on entry, as in the stock blocks: ESI = unit query object,
; [esp+10h] = home city, [esp+18h] = store flag. EBX, EBP and EDI are free (the epilogue pops
; them). Each configured proto is searched exactly like a stock block (0x6698B4..0x669963), and
; the first unit that passes the same checks becomes the point. A FirstTC entry runs no query:
; UhcGatherFirstTcUnit returns the player's first town center when it passes the stock check
; 0x85302C, and it becomes the point the same way.
UhcHcGatherFallbackHook PROC
    TRACE_ONCE "hcShipmentPointFallback (0x669E2E)"
    cmp resolved, 0
    jne searchTypes
    mov resolved, 1
    pushad
    call UhcResolveGatherFallbackTypes
    popad
searchTypes:
    mov typeIndex, 0
nextType:
    mov eax, typeIndex
    cmp eax, g_uhcGatherFallbackCount
    jge notFound
    mov edx, g_uhcGatherFallbackTypes[eax*4]
    cmp edx, FIRST_TC_ENTRY
    je firstTc
    cmp edx, -1
    je typeDone
    mov eax, dword ptr [esp+10h]    ; home city
    mov ecx, dword ptr [eax+8]
    mov eax, dword ptr [ecx]        ; owning player ID
    push 1
    push eax
    push 0
    mov ecx, esi
    call querySetPlayer
    mov eax, typeIndex
    mov edx, g_uhcGatherFallbackTypes[eax*4]
    push edx
    push 0
    mov ecx, esi
    call queryAddType
    push 2
    push 0
    mov ecx, esi
    call querySetState
    push 0
    mov ecx, esi
    call queryRun
    mov ebx, eax
    xor ebp, ebp
    test ebx, ebx
    jle typeDone
unitLoop:
    mov eax, dword ptr ds:[0C66234h]
    mov edi, dword ptr [eax+13Ch]   ; world
    push ebp
    push 0
    mov ecx, esi
    call queryUnitId
    test eax, eax
    jl unitNext
    mov ecx, eax
    and ecx, 3FFFFh
    cmp ecx, dword ptr [edi+10h]
    jge unitNext
    mov edx, dword ptr [edi+0Ch]
    mov edi, dword ptr [edx+ecx*4]
    test edi, edi
    je unitNext
    cmp dword ptr [edi+10h], eax
    jne unitNext
    mov eax, dword ptr [edi]
    mov ecx, edi
    call dword ptr [eax+0A4h]
    test al, al
    je unitNext
    mov ecx, edi
    call unitCheckA
    test al, al
    je unitNext
    mov ecx, edi
    call unitCheckB
    cmp al, 1
    jne found
unitNext:
    add ebp, 1
    cmp ebp, ebx
    jl unitLoop
typeDone:
    inc typeIndex
    jmp nextType
found:
    jmp storeAndReturn              ; EDI = the chosen unit
firstTc:
    TRACE_ONCE "hcShipmentPointFallback FirstTC (0x669E2E)"
    push dword ptr [esp+10h]        ; home city (address taken before the push)
    call UhcGatherFirstTcUnit       ; Unit* or 0; clobbers EAX/ECX/EDX only
    test eax, eax
    je typeDone
    mov edi, eax
    jmp storeAndReturn              ; 0x4C6CB2: stores [hc+18Ch] when [esp+18h]==1, returns EDI
notFound:
    pop ebp                         ; stolen 0x669E2E..0x669E32
    pop edi
    pop esi
    xor eax, eax
    jmp notFoundReturn
UhcHcGatherFallbackHook ENDP

END
```
