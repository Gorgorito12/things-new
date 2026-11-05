# Code for WoL: Healing and hit points

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [healNonIdle](#healnonidle)
- [smartHealTargets](#smarthealtargets)
- [overhealHitpointBars](#overhealhitpointbars)
- [overhealSources](#overhealsources)
- [overhealDecay](#overhealdecay)

## healNonIdle

Contract: [healNonIdle](../porting-to-another-dll.md#healnonidle).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `HealAutoSearchIdle` `0x9CD9C0` (21 B), `HealIdleCheck` `0x9E0C79` (44 B).

### src/features/heal.cpp

```cpp
// healNonIdle: healers whose proto has a marker unittype (default AbstractHealNonIdle) heal
// targets that are moving or fighting. Stock blocks them twice: the automatic target search
// only takes idle targets, and each heal tick stops when the target moves or fights. Both
// hooks are in hooks/heal_hooks.asm; the marker is registered as an extra abstract unit type
// (unittypes.h), so protoy.xml can list it on any healer.
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
std::int32_t g_uhcHealNonIdleType = -1;

void UhcHealNonIdleHook();
void UhcHealAutoSearchHook();
}

namespace uhc {

Outcome ApplyHealNonIdle(const Config& config) {
  const Config::Args* args = config.First("healNonIdle");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  const char* typeName = args->empty() ? "AbstractHealNonIdle" : args->front().c_str();
  if (!VerifyAll("healNonIdle", {&sites::kHealIdleCheck, &sites::kHealAutoSearchIdle})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(typeName, &g_uhcHealNonIdleType)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kHealIdleCheck.va, reinterpret_cast<const void*>(&UhcHealNonIdleHook), 5) ||
      !WriteJmp(0x009CD9C7, reinterpret_cast<const void*>(&UhcHealAutoSearchHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"healNonIdle: healers of unittype %hs heal busy targets (multiplayer unverified)", typeName);
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/heal_hooks.asm

```asm
; Hook for healNonIdle. Entered through a jmp written over the stock code; leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Healing").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcHealNonIdleType:SDWORD      ; unittype ID, set on each database load; -1 before

.data
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): proto IDs and abstract types
healPath        dd 009E0C9Fh    ; apply this tick's heal
busyChecks      dd 009E0C80h    ; stock: push -1 / call 4802D4h (target moving?) / call 9CA5ACh
targetIsIdle    dd 0044F1A7h    ; bool thiscall(actionManager): no current action, or an idle one
autoSearchNext  dd 009CD9CCh    ; test al,al / je 9CDA3Fh (skip this candidate)

.code

; Replaces 0x9E0C79..0x9E0C7D (mov ecx,[edi+58h] / test ecx,ecx) in FUN_009E0B53, where each heal
; tick stops if the target has a current action that is a move or a fight. EDI = target unit,
; ESI = heal action (healer unit at [esi+10h]). A healer whose proto is of the configured
; unittype skips the busy test; any other healer runs the stock code unchanged.
UhcHealNonIdleHook PROC
    TRACE_ONCE "healNonIdle (0x9E0C79)"
    cmp g_uhcHealNonIdleType, 0
    jl stock
    mov ecx, dword ptr [esi+10h]    ; healer unit
    test ecx, ecx
    je stock
    mov ecx, dword ptr [ecx+5Ch]    ; healer proto
    test ecx, ecx
    je stock
    push g_uhcHealNonIdleType
    call protoIsType
    test al, al
    jne heal
stock:
    mov ecx, dword ptr [edi+58h]    ; stolen 0x9E0C79
    test ecx, ecx                   ; stolen 0x9E0C7C
    je heal                         ; stock 0x9E0C7E: no current action -> heal
    jmp busyChecks
heal:
    jmp healPath
UhcHealNonIdleHook ENDP

; Replaces the call 44F1A7h at 0x9CD9C7 in FUN_009CD865, where a healer's automatic search skips
; every candidate that is not idle. ECX = the candidate's action manager ([esi+58h]),
; ESI = candidate, EBP = the search's owner, with the healer at [ebp+4]. For a healer of the
; configured unittype the candidate counts as idle; any other healer runs the stock test.
UhcHealAutoSearchHook PROC
    TRACE_ONCE "healNonIdle auto-search (0x9CD9C7)"
    cmp g_uhcHealNonIdleType, 0
    jl idleTest
    push ecx
    mov ecx, dword ptr [ebp+4]      ; healer unit
    test ecx, ecx
    je restore
    mov ecx, dword ptr [ecx+5Ch]    ; healer proto
    test ecx, ecx
    je restore
    push g_uhcHealNonIdleType
    call protoIsType
    test al, al
    je restore
    pop ecx
    mov al, 1
    jmp autoSearchNext
restore:
    pop ecx
idleTest:
    call targetIsIdle               ; stolen 0x9CD9C7
    jmp autoSearchNext
UhcHealAutoSearchHook ENDP

END
```

## smartHealTargets

Contract: [smartHealTargets](../porting-to-another-dll.md#smarthealtargets).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `IsA` `0x44D7FA` (105 B), `HealthRatio` `0x45F295` (72 B), `SmartHealLoop` `0x9CD923` (95 B), `SmartHealRange` `0x9CDA21` (30 B), `SmartHealLoopEnd` `0x9CDA3F` (64 B).

### src/features/smartheal.cpp

```cpp
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
```

### src/hooks/smartheal_hooks.asm

```asm
; Hooks for smartHealTargets. Entered through a jmp written over the stock code; each leaves
; through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Unit types and
; healing").
.686
.model flat, c
option casemap :none

include common.inc

UhcSmartHealConsider PROTO STDCALL healer:DWORD, unit:DWORD
UhcSmartHealPick PROTO STDCALL healer:DWORD

.data
inRange         dd 007FCF2Dh    ; bool thiscall(healer, unit, range), ret 8: the search's last test
nextCandidate   dd 009CDA3Fh    ; the loop's step to the next query entry
acceptCandidate dd 009CDA62h    ; healer vtbl+64h(1), then 0x9CBDC4(owner, [esi+10h]): heal ESI
searchFailExit  dd 009CDA5Dh    ; pop ebp / add esp,10h / ret: AL = 0, no target

.code

; Replaces call 7FCF2Dh at 0x9CDA36 in the automatic heal search FUN_009CD865, the last of the
; stock tests: ECX = healer, the candidate and the action's range are pushed, ESI = candidate,
; EBP = the search's owner (healer at [ebp+4]). Stock heals the first candidate in range
; (jne 9CDA62h); here a candidate in range is only recorded (UhcSmartHealConsider keeps the best
; one) and the loop goes on. EBX, ESI, EDI and EBP are kept; EAX, ECX, EDX and the flags are
; written again at 0x9CDA3F before they are read.
UhcSmartHealRangeHook PROC
    TRACE_ONCE "smartHealTargets candidate (0x9CDA36)"
    call inRange                    ; stolen 0x9CDA36
    test al, al
    je next
    pushad
    push esi                        ; candidate
    push dword ptr [ebp+4]          ; healer
    call UhcSmartHealConsider
    popad
next:
    jmp nextCandidate
UhcSmartHealRangeHook ENDP

; Replaces pop esi / pop ebx / pop edi / xor al,al at 0x9CDA58, where the search ends without a
; target (the loop is exhausted, or the query was empty, 0x9CD92A). The stack is the one the
; accept path 0x9CDA62 expects (it pops ESI, EBX, EDI and EBP at 0x9CDA77): with a recorded best
; candidate the hook jumps there with ESI = that unit; without one it re-does the stolen bytes.
UhcSmartHealPickHook PROC
    TRACE_ONCE "smartHealTargets pick (0x9CDA58)"
    push dword ptr [ebp+4]          ; healer
    call UhcSmartHealPick           ; EAX = the best candidate, or 0; clobbers ECX, EDX
    test eax, eax
    je none
    mov esi, eax
    jmp acceptCandidate
none:
    pop esi                         ; stolen 0x9CDA58
    pop ebx                         ; stolen 0x9CDA59
    pop edi                         ; stolen 0x9CDA5A
    xor al, al                      ; stolen 0x9CDA5B
    jmp searchFailExit
UhcSmartHealPickHook ENDP

END
```

## overhealHitpointBars

Contract: [overhealHitpointBars](../porting-to-another-dll.md#overhealhitpointbars).

Besides the core helpers, it needs: [`unitpanel.h`](helpers.md#unit-panel-row-the-minimized-interface), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `BStringFree` `0x4010CA` (31 B), `BStringSet` `0x40196F` (36 B), `BStringFromWide` `0x401A12` (40 B), `GadgetRelease` `0x40431B` (44 B), `DynamicVbFull` `0x40A689` (25 B), `DynamicVbLock` `0x40A6A2` (69 B), `ProgressGadget` `0x44B8B8` (35 B), `IsA` `0x44D7FA` (105 B), `IsATrue` `0x44F139` (5 B), `HpBarRenderStart` `0x45C4AF` (63 B), `HpBarRenderLoop` `0x45C60B` (1415 B), `HealthRatio` `0x45F295` (72 B), `OverhealBarRatio` `0x45FAA7` (17 B), `OverhealSegmentQueue` `0x45FB3F` (50 B), `HpBarQueue` `0x45FB71` (111 B), `MaxHitpointsGetter` `0x480408` (38 B), `OverhealGroupRatio` `0x4C5012` (15 B), `GadgetRef` `0x4C519C` (27 B), `OverhealPortraitTail` `0x4C82E6` (258 B), `OverhealStatMax` `0x4D7560` (81 B), `OverhealStatBase` `0x4D75DA` (69 B), `OverhealTextStat` `0x4D7647` (21 B), `OverhealStatRow` `0x4D76DB` (9 B), `BStringFromId` `0x58EA52` (25 B), `ProgressFill` `0x590772` (73 B), `InitialHitpointsTag` `0x5F5CE3` (6 B), `MaxHitpointsTag` `0x5F5D39` (6 B), `OverhealPanelMax` `0x698B18` (38 B), `OverhealPortraitColours` `0x69A614` (22 B), `OverhealTextStatSplit` `0x69A9B0` (27 B), `GroupHealthRow` `0x69A9D3` (316 B), `OverhealInfoProto` `0x9AF33B` (25 B), `OverhealInfoBase` `0x9AFA07` (45 B), `OverhealInfoMax` `0x9AFA34` (35 B), `HealthBarGadgets` `0x9BAEE5` (135 B).

### src/features/overheal.cpp

```cpp
// overhealHitpointBars [UnitType ...] [segment[=RRGGBB]] [log]: the HP bars and HP texts of marked
// units take InitialHitpoints as 100 %, not MaxHitpoints; with "segment" the HP above it shows.
//
// A unit is created with its proto's InitialHitpoints ([proto+9Ch], 0x498390 in FUN_00498274)
// and is healed up to MaxHitpoints ([proto+98h]); a Hitpoints tech adds the same amount to both
// (0x8F97DD). Every HP display reads the max: the floating bars (0x45FAAF) and the selection
// group bar and 'Group Health' (0x4C5014) take the health ratio FUN_0045F295, HP / max clamped to
// 1; the three HP texts print 'HP/max' with the max from FUN_00480408 (or a copy of it inlined in
// the stat row, 0x4D7575), and '%d/%d (%d+%d)' when that max is above the database proto's
// MaxHitpoints. A mod that gives infantry and cavalry MaxHitpoints = 1.1 x InitialHitpoints, so a fresh
// unit shows a 91 % bar and '150/165'.
//
// For a unit whose proto has a marker type (default AbstractOverheal; a stock type or a proto
// name works too, several may be listed) and 1e-6 < InitialHitpoints < MaxHitpoints, the hooks in
// hooks/overheal_hooks.asm replace that max by a reference: InitialHitpoints itself, or
// max x InitialHitpoints / MaxHitpoints when an aura or modifier changed the unit's max (the
// stock rescale 0x9C738B keeps HP / max through such a change, so a full unit stays full). A fresh
// unit then shows a full bar and '150/150', an overhealed one a full bar and '165/150'. The base
// of the '(%d+%d)' split becomes the database proto's InitialHitpoints.
//
// Display only: 0x45F295 and 0x480408 themselves stay stock, so the heal search, transforms,
// modifiers, AI queries and triggers still use the max, and nothing depends on the local player.
// The floating bar is not drawn past 100 %, and the group average stays clamped at 1.
//
// "segment" (Overwatch style): a unit whose HP is above its 100 % gets an orange segment over the
// right end of its full floating bar, (HP - 100 %) / 100 % of the bar's width (all of it from
// twice the 100 %), and its HP texts are coloured the same. The bar keeps its width. The renderer
// FUN_0045C4AF draws every queued bar as one textured quad (ui\hitpoint_bars\hpbar: the fill
// half is a white gradient tinted by the vertex colour, the player's [player+0C8h]) in a single
// draw call; the segment is a second record queued right after the unit's own bar, with a player
// ID no player has, whose six vertices are then moved to the right end of the bar and given the
// segment colour. The stat row's HP text uses the UI markup <color=r, g, b> for the colour. A unit
// at or below its 100 %, and every unmarked unit (whose HP never exceeds its max), keeps the stock
// bar and texts. The selection panel's bar under the portrait is one of three progress bar gadgets
// (green, yellow, red) of uiunitselection.xml; "segment" also fills a fourth one, when the mod's UI
// data has it: unitselectionpanel-unitHealthBarOverheal, looked up by name as the panel looks up
// the stock three (0xAB7C2F), filled with the group's average overheal share and raised above them
// after each refresh (0x4C83DF). Its look and place are the UI data's; without it nothing changes.
//
// "stat[=Label]": the stat panel gets an "Overheal" row right after the HP row (0x4D76DB) for a
// marked unit, 'overheal/capacity' (HP above the 100 % / max above it, truncated like the HP row),
// written with the calls of the stock "Group Health" row (0x69A9D3), whose label is a literal too.
// The label is the text after '=' ('_' for a space; UTF-8 or ANSI), or a string table entry when it
// is a number.
#include <windows.h>

#include <cstdint>
#include <cctype>
#include <cstdlib>
#include <cwchar>
#include <cstring>
#include <set>
#include <string>
#include <string_view>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../unitpanel.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::size_t kMaxTypes = 8;  // the size of g_uhcOverhealTypes
constexpr std::uint32_t kGameGlobal = 0x00C66234;    // game; +13Ch world
constexpr std::uint32_t kDeviceGlobal = 0x00C66044;  // render device; +660h its dynamic vertex buffer
constexpr std::int32_t kSegmentPlayer = static_cast<std::int32_t>(0x804F5648);  // as in overheal_hooks.asm
constexpr std::uint32_t kRecordSize = 0x1C;                  // a queued bar
constexpr std::uint32_t kVertexSize = 0x24;                  // six per bar
constexpr std::uint32_t kDefaultSegmentColour = 0xFFFF8C00;  // ARGB orange

// FUN_0045FB71: queues a floating HP bar, thiscall(world, pos*, scale, fill, player, colour byte).
using QueueBarFn = bool(__fastcall*)(const char* world, void* unused, const float* pos, float scale, float fill,
                                     std::int32_t player, std::uint32_t colourByte);
const auto kQueueBar = reinterpret_cast<QueueBarFn>(0x0045FB71);

// Proto names already logged with "log"; only the game thread touches them.
std::set<std::string, std::less<>> g_loggedProtos;
std::set<std::string, std::less<>> g_loggedSegments;
bool g_loggedDrop = false;
std::uint32_t g_segmentColour = kDefaultSegmentColour;

struct Vertex {  // the renderer's vertex (24h bytes)
  float position[3];
  float normal[3];
  std::uint32_t colour;
  float u;
  float v;
};
static_assert(sizeof(Vertex) == kVertexSize);

struct BarRecord {  // a queued bar (1Ch bytes)
  float position[3];
  float scale;
  float fill;
  std::int32_t player;
  std::uint8_t colourByte;
  std::uint8_t padding[3];
};
static_assert(sizeof(BarRecord) == kRecordSize);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Hook {
  std::uint32_t va;
  std::size_t length;  // the stolen instruction: a call (5) or an fld / mov (6)
  void (*target)();
};

// The engine's string: one pointer to a wide, reference-counted buffer; null is empty.
struct BString {
  wchar_t* text;
};

// UI gadgets (docs/engine-symbols.md, "Hit points").
constexpr std::uint32_t kLabelStyle = 0x00D6F5D0;    // the Group Health row's label style (vtable +84h)
constexpr std::uint32_t kValueStyle = 0x00C6657C;    // its value style
constexpr std::int32_t kStatPanelRows = 9;           // StackLabel/StackValue 0..8 (0x9BBAD1)
constexpr wchar_t kBarBackground[] = L"ui\\ingame\\ui_health_bar";  // the bars' background in the UI data

using ProgressGadgetFn = char*(__cdecl*)(std::int32_t handle);
using GadgetReleaseFn = std::int32_t(__cdecl*)(std::int32_t handle);
using ProgressFillFn = void(__thiscall*)(char* bar, float fill);
using DrawableTextureFn = void(__thiscall*)(void* drawable, const BString* texture, std::int32_t unused);
using GadgetRefFn = std::int32_t*(__thiscall*)(std::int32_t* ref, std::int32_t handle);  // ref: handle, gadget
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t stringId);
using BStringSetFn = BString*(__thiscall*)(BString* self, const BString* source);
using BStringFreeFn = void(__thiscall*)(BString* self);
using MaxHitpointsFn = float(__thiscall*)(const char* unit);
using GadgetStyleFn = void(__thiscall*)(char* gadget, const void* style);
using GadgetTextFn = void(__thiscall*)(char* gadget, const BString* text);
using GadgetUpdateFn = void(__thiscall*)(char* gadget);
const auto kProgressGadget = reinterpret_cast<ProgressGadgetFn>(0x0044B8B8);
const auto kGadgetRelease = reinterpret_cast<GadgetReleaseFn>(0x0040431B);
const auto kProgressFill = reinterpret_cast<ProgressFillFn>(0x00590772);
const auto kGadgetRef = reinterpret_cast<GadgetRefFn>(0x004C519C);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringSet = reinterpret_cast<BStringSetFn>(0x0040196F);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kMaxHitpoints = reinterpret_cast<MaxHitpointsFn>(0x00480408);

template <typename Fn>
Fn VirtualAt(const char* object, std::uint32_t offset) {
  return *reinterpret_cast<const Fn*>(*reinterpret_cast<const char* const*>(object) + offset);
}

const char* GameWorld() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

// The unit with this ID in the world's table ([world+0Ch], count [world+10h]), as the engine looks
// it up (ID & 3FFFFh, then the stored ID must match); null if it is gone.
const char* UnitById(const char* world, std::int32_t id) {
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

// The portrait gadget's handle, looked up again when the panel is another one or was rebuilt (its
// green bar has another handle).
const char* g_portraitPanel = nullptr;
std::int32_t g_portraitGreen = 0;
bool g_portraitBackground = false;  // the green bar has the overheal texture now
bool g_portraitFillLogged = false;
std::wstring g_portraitTexture = L"ui\\ingame\\ingame_ui_health_yellow";

// The stat row: its label (a literal, or a string table ID when g_statLabelId >= 0).
bool g_statRow = false;
std::wstring g_statLabel = L"Overheal";
std::int32_t g_statLabelId = -1;
bool g_statLogged = false;


// Sets a stat row gadget's text as the Group Health row does: the style, the text, the update
// (vtable +84h, +80h, +54h), then an empty help text ([gadget+68h]).
void SetRowText(char* gadget, const void* style, const wchar_t* text) {
  BString value;
  kBStringFromWide(&value, text);
  VirtualAt<GadgetStyleFn>(gadget, 0x84)(gadget, style);
  VirtualAt<GadgetTextFn>(gadget, 0x80)(gadget, &value);
  VirtualAt<GadgetUpdateFn>(gadget, 0x54)(gadget);
  kBStringFree(&value);
  BString empty;
  kBStringFromWide(&empty, L"");
  kBStringSet(reinterpret_cast<BString*>(gadget + 0x68), &empty);
  kBStringFree(&empty);
}

// A row gadget from its handle, as 0x69A9D3 gets it (the reference is released at once; the panel
// keeps the gadget).
char* RowGadget(std::int32_t handle) {
  std::int32_t ref[2] = {0, 0};
  std::int32_t* result = kGadgetRef(ref, handle);
  char* gadget = reinterpret_cast<char*>(static_cast<std::uintptr_t>(static_cast<std::uint32_t>(result[1])));
  if (result[1] != 0) {
    kGadgetRelease(result[0]);
  }
  return gadget;
}

// "Sobrecuración", "Over_heal" (a space), or "12345" (a string table ID); UTF-8, else ANSI.
bool ParseLabel(const std::string& text, std::wstring* label, std::int32_t* stringId) {
  if (text.empty()) {
    return false;
  }
  if (text.find_first_not_of("0123456789") == std::string::npos) {
    *stringId = std::atoi(text.c_str());
    return true;
  }
  wchar_t wide[64];
  int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.c_str(), -1, wide, 64);
  if (length == 0) {
    length = MultiByteToWideChar(CP_ACP, 0, text.c_str(), -1, wide, 64);
  }
  if (length == 0) {
    return false;
  }
  for (wchar_t& c : wide) {
    c = c == L'_' ? L' ' : c;
  }
  *label = wide;
  return true;
}

}  // namespace

extern "C" {
// Marker unittype IDs, set on each database load (-1 before); the hooks read the first
// g_uhcOverhealTypeCount of them.
std::int32_t g_uhcOverhealTypes[kMaxTypes] = {-1, -1, -1, -1, -1, -1, -1, -1};
std::int32_t g_uhcOverhealTypeCount = 0;
std::int32_t g_uhcOverhealLog = 0;  // 1 with "overhealHitpointBars ... log"
std::int32_t g_uhcOverhealTextColor = 0;  // 1 with "segment": HP texts above 100 % are coloured
wchar_t g_uhcOverhealFmtPlain[64] = L"%d/%d";  // set with the segment colour
wchar_t g_uhcOverhealFmtSplit[64] = L"%d/%d (%d+%d)";

void UhcOverhealBarHook();
void UhcOverhealGroupHook();
void UhcOverhealPanelMaxHook();
void UhcOverhealStatMaxHook();
void UhcOverhealStatBaseHook();
void UhcOverhealInfoBaseHook();
void UhcOverhealInfoMaxHook();
void UhcOverhealSegmentQueueHook();
void UhcOverhealSegmentRenderHook();
void UhcOverhealSegmentVertexHook();
void UhcOverhealTextStatHook();
void UhcOverhealTextStatSplitHook();
void UhcOverhealPortraitHook();
void UhcOverhealStatRowHook();
float UhcOverhealReferenceOf(const char* unit);  // overheal_hooks.asm, cdecl; the max for an unmarked unit
std::int32_t UhcOverhealMarked(const char* proto);

// Called by the hooks (only with "log") each time a unit's reference differs from its max; logs
// the first such unit of each proto name.
void __stdcall UhcOverhealLogReference(const char* unit, float reference, float maxHp) {
  const char* proto = Field<const char*>(unit, 0x5C);  // not null: the hooks checked it
  const char* name = Field<const char*>(proto, 0x10);
  const std::string_view key = name == nullptr ? "?" : name;
  if (g_loggedProtos.find(key) != g_loggedProtos.end()) {
    return;
  }
  g_loggedProtos.emplace(key);
  uhc::Log(L"overhealHitpointBars: unit %d (%hs) HP %.1f is shown against %.1f instead of its max %.1f "
           L"(InitialHitpoints %.1f, MaxHitpoints %.1f); logged once per proto",
           Field<std::int32_t>(unit, 0x10), key.data(), static_cast<double>(Field<float>(unit, 0x64)),
           static_cast<double>(reference), static_cast<double>(maxHp), static_cast<double>(Field<float>(proto, 0x9C)),
           static_cast<double>(Field<float>(proto, 0x98)));
}

// From the bar queue hook (0x45FB6C), after the unit's own bar was queued at pos: queues the
// overheal segment when HP is above the reference (OverhealReference: the max for an unmarked
// unit, so never). The record's fill is the segment's share of the bar, at most 1.
void __stdcall UhcOverhealQueueSegment(const char* unit, const float* pos, float reference) {
  const float hp = Field<float>(unit, 0x64);
  if (!(reference > 1e-6f) || !(hp > reference)) {
    return;
  }
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr) {
    return;
  }
  float share = (hp - reference) / reference;
  share = share < 1.0f ? share : 1.0f;
  kQueueBar(world, nullptr, pos, 1.0f, share, kSegmentPlayer, 0xFF);
  if (g_uhcOverhealLog != 0) {
    const char* proto = Field<const char*>(unit, 0x5C);
    const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
    const std::string_view key = name == nullptr ? "?" : name;
    if (g_loggedSegments.find(key) == g_loggedSegments.end()) {
      g_loggedSegments.emplace(key);
      uhc::Log(L"overhealHitpointBars: unit %d (%hs) HP %.1f is above its 100 %% %.1f: overheal segment of %.1f %% "
               L"of the bar; logged once per proto",
               Field<std::int32_t>(unit, 0x10), key.data(), static_cast<double>(hp), static_cast<double>(reference),
               static_cast<double>(share * 100.0f));
    }
  }
}

// From the renderer hook (0x45C4B9), before the vertex lock: when the queue's six vertices per bar
// would not fit in the dynamic vertex buffer ([vb+4] bytes; stock then draws no bar that frame),
// the segment records are removed so that the stock bars are drawn as without the feature.
void __stdcall UhcOverhealSegmentFit(char* world) {
  const std::int32_t count = Field<std::int32_t>(world, 0x8D4);
  const char* device = *reinterpret_cast<const char* const*>(kDeviceGlobal);
  const char* buffer = device == nullptr ? nullptr : Field<const char*>(device, 0x660);
  if (count <= 0 || buffer == nullptr ||
      static_cast<std::uint64_t>(count) * 6 * kVertexSize <= Field<std::uint32_t>(buffer, 4)) {
    return;
  }
  auto* records = Field<BarRecord*>(world, 0x8D0);
  std::int32_t kept = 0;
  for (std::int32_t i = 0; i < count; ++i) {
    if (records[i].player != kSegmentPlayer) {
      records[kept++] = records[i];
    }
  }
  *reinterpret_cast<std::int32_t*>(world + 0x8D4) = kept;
  if (!g_loggedDrop && kept != count) {
    g_loggedDrop = true;
    uhc::Log(L"overhealHitpointBars: %d bars do not fit in the vertex buffer (%u bytes): this frame's %d overheal "
             L"segments were dropped (logged once)",
             count, Field<std::uint32_t>(buffer, 4), count - kept);
  }
}

// From the renderer loop hook (0x45CB72), for a segment record: its six vertices, written by the
// stock loop like a full bar (fill = the segment's share), become the right end of the bar. The
// left ones (v0, v2, v3, at P - scale/2 x B) move right by scale x (1 - share) x B; every vertex
// takes the fill part of the texture (u 1.0 on the left, 0.5 on the right, as for a full bar) and
// the segment colour.
void __stdcall UhcOverhealSegmentVertices(const char* world, std::int32_t offset, Vertex* vertices,
                                          const char* camera) {
  const auto* record = reinterpret_cast<const BarRecord*>(Field<const char*>(world, 0x8D0) + offset);
  float share = record->fill;
  share = share < 0.0f ? 0.0f : (share > 1.0f ? 1.0f : share);
  const float shift = record->scale * (1.0f - share);
  const float* right = reinterpret_cast<const float*>(camera + 0x28);  // B, the camera's right vector
  for (int k = 0; k < 6; ++k) {
    Vertex& vertex = vertices[k];
    const bool left = k == 0 || k == 2 || k == 3;
    if (left) {
      for (int axis = 0; axis < 3; ++axis) {
        vertex.position[axis] += shift * right[axis];
      }
    }
    vertex.u = left ? 1.0f : 0.5f;
    vertex.colour = g_segmentColour;
  }
}

// From the portrait hook (0x4C83DF), after the selection panel filled the group's colour bar. While
// the group has an overheal the green bar, the game's own gadget, shows it: the mask (green) stops at
// 1 - the group's average overheal share ((HP - 100 %) / 100 %, at most 1; 0 for a unit at or below
// its 100 % or unmarked), and the rest shows the bar's background, whose texture is the overheal one
// while it lasts (vtable +7Ch of the bar's drawable [bar+140h], as the game's setter 0x5CAF02 calls it). The group: unit IDs [group+10h], count [group+14h]
// (FUN_004C4FB5).
void __stdcall UhcOverhealPortrait(char* panel, const char* group) {
  if (panel == nullptr || group == nullptr) {
    return;
  }
  const std::int32_t green = Field<std::int32_t>(panel, 0x310);
  if (panel != g_portraitPanel || green != g_portraitGreen) {
    g_portraitPanel = panel;
    g_portraitGreen = green;
    g_portraitBackground = false;  // a new gadget has the UI data's background
  }
  float share = 0.0f;
  std::int32_t units = 0;
  // The stock bar is full only when every unit of the group is at or above its 100 % (the average
  // of the ratios, each clamped to 1).
  if (Field<float>(group, 0x1C) >= 0.999f) {
    const char* world = GameWorld();
    const auto* ids = Field<const std::int32_t*>(group, 0x10);
    const std::int32_t count = Field<std::int32_t>(group, 0x14);
    float sum = 0.0f;
    for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
      const char* unit = UnitById(world, ids[i]);
      if (unit == nullptr) {
        continue;
      }
      ++units;
      const char* proto = Field<const char*>(unit, 0x5C);
      if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
        continue;
      }
      const float reference = UhcOverhealReferenceOf(unit);
      const float hp = Field<float>(unit, 0x64);
      if (reference > 1e-6f && hp > reference) {
        const float part = (hp - reference) / reference;
        sum += part < 1.0f ? part : 1.0f;
      }
    }
    share = units > 0 ? sum / static_cast<float>(units) : 0.0f;
  }
  const bool overheal = share > 0.0f;
  if (!overheal && !g_portraitBackground) {
    return;  // the bar is as the game left it
  }
  char* bar = kProgressGadget(green);
  if (bar == nullptr) {
    return;
  }
  kGadgetRelease(green);
  void* background = Field<void*>(bar, 0x140);  // the bar's drawable: it keeps its size, only the texture changes
  if (background == nullptr) {
    return;
  }
  if (overheal != g_portraitBackground) {
    BString texture;
    kBStringFromWide(&texture, overheal ? g_portraitTexture.c_str() : kBarBackground);
    const auto setTexture = reinterpret_cast<DrawableTextureFn>((*reinterpret_cast<void***>(background))[0x7C / 4]);
    setTexture(background, &texture, -1);
    kBStringFree(&texture);
    g_portraitBackground = overheal;
  }
  if (!overheal) {
    return;
  }
  kProgressFill(bar, 1.0f - share);  // the mask (the HP part) from the left, the background shows the rest
  if (g_uhcOverhealLog != 0 && !g_portraitFillLogged) {
    g_portraitFillLogged = true;
    uhc::Log(L"overhealHitpointBars: the portrait bar shows an overheal of %.1f %% of the bar (%d units; logged once)",
             static_cast<double>(share * 100.0f), units);
  }
}

// From the stat row hook (0x4D76DB, right after the HP row; row = the next free row): writes the
// overheal row for the panel's unit when it is marked. True if it did; the hook then counts it.
bool __stdcall UhcOverhealStatRow(const char* panel, const char* unit, std::int32_t row) {
  if (panel == nullptr || unit == nullptr || row < 0 || row >= kStatPanelRows) {
    return false;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
    return false;
  }
  char* label = RowGadget(Field<std::int32_t>(panel, 0x174 + row * 4));
  char* value = RowGadget(Field<std::int32_t>(panel, 0x198 + row * 4));
  if (label == nullptr || value == nullptr) {
    return false;
  }
  // Truncated like the HP row's '%d/%d' (fistp with the chop rounding), so the numbers add up.
  const int reference = static_cast<int>(UhcOverhealReferenceOf(unit));
  const int hp = static_cast<int>(Field<float>(unit, 0x64));
  const int maxHp = static_cast<int>(kMaxHitpoints(unit));
  const int overheal = hp > reference ? hp - reference : 0;
  const int capacity = maxHp > reference ? maxHp - reference : 0;
  wchar_t text[96];
  if (overheal > 0 && g_uhcOverhealTextColor != 0) {
    swprintf_s(text, L"<color=%.2f, %.2f, %.2f>%d/%d</color>", ((g_segmentColour >> 16) & 0xFF) / 255.0,
               ((g_segmentColour >> 8) & 0xFF) / 255.0, (g_segmentColour & 0xFF) / 255.0, overheal, capacity);
  } else {
    swprintf_s(text, L"%d/%d", overheal, capacity);
  }
  if (g_statLabelId >= 0) {
    BString name;
    kBStringFromId(&name, g_statLabelId);
    SetRowText(label, reinterpret_cast<const void*>(kLabelStyle), name.text == nullptr ? L"" : name.text);
    kBStringFree(&name);
  } else {
    SetRowText(label, reinterpret_cast<const void*>(kLabelStyle), g_statLabel.c_str());
  }
  SetRowText(value, reinterpret_cast<const void*>(kValueStyle), text);
  if (g_uhcOverhealLog != 0 && !g_statLogged) {
    g_statLogged = true;
    uhc::Log(L"overhealHitpointBars: stat row %d of unit %d (%hs): overheal %ls (logged once)", row,
             Field<std::int32_t>(unit, 0x10), Field<const char*>(proto, 0x10), text);
  }
  return true;
}

// The minimized interface's row (unitpanel.cpp): the same numbers as the stat row, which that
// interface never fills. It shows for a marked unit once it has overheal: the row is shared.
bool __stdcall UhcOverhealUnitPanel(const char* panel, const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
    return false;
  }
  const int reference = static_cast<int>(UhcOverhealReferenceOf(unit));
  const int hp = static_cast<int>(Field<float>(unit, 0x64));
  const int maxHp = static_cast<int>(kMaxHitpoints(unit));
  if (hp <= reference || maxHp <= reference) {
    return false;
  }
  wchar_t text[96];
  if (g_uhcOverhealTextColor != 0) {
    swprintf_s(text, L"<color=%.2f, %.2f, %.2f>%d/%d</color>", ((g_segmentColour >> 16) & 0xFF) / 255.0,
               ((g_segmentColour >> 8) & 0xFF) / 255.0, (g_segmentColour & 0xFF) / 255.0, hp - reference,
               maxHp - reference);
  } else {
    swprintf_s(text, L"%d/%d", hp - reference, maxHp - reference);
  }
  wchar_t label[96];
  if (g_statLabelId >= 0) {
    BString name;
    kBStringFromId(&name, g_statLabelId);
    swprintf_s(label, L"%ls:", name.text == nullptr ? L"" : name.text);
    kBStringFree(&name);
  } else {
    swprintf_s(label, L"%ls:", g_statLabel.c_str());
  }
  return uhc::SetUnitPanelRow(panel, label, text);
}
}

namespace uhc {

Outcome ApplyOverhealHitpointBars(const Config& config) {
  const Config::Args* args = config.First("overhealHitpointBars");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }

  std::vector<std::string> typeNames;
  bool log = false;
  bool segment = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (_strnicmp(arg.c_str(), "segment", 7) == 0 && (arg.size() == 7 || arg[7] == '=')) {
      segment = true;
      if (arg.size() > 7) {
        char* end = nullptr;
        const unsigned long rgb = std::strtoul(arg.c_str() + 8, &end, 16);
        if (arg.size() != 14 || end != arg.c_str() + 14 || std::isxdigit(static_cast<unsigned char>(arg[8])) == 0) {
          Log(L"overhealHitpointBars: %hs: expected segment or segment=RRGGBB (hex); feature not applied",
              arg.c_str());
          return Outcome::kFailed;
        }
        g_segmentColour = 0xFF000000u | static_cast<std::uint32_t>(rgb);
      }
    } else if (_strnicmp(arg.c_str(), "bar=", 4) == 0 && arg.size() > 4) {
      g_portraitTexture.assign(arg.begin() + 4, arg.end());
    } else if (_strnicmp(arg.c_str(), "stat", 4) == 0 && (arg.size() == 4 || arg[4] == '=')) {
      g_statRow = true;
      if (arg.size() > 4 && !ParseLabel(arg.substr(5), &g_statLabel, &g_statLabelId)) {
        Log(L"overhealHitpointBars: %hs: expected stat or stat=<label> (a word, '_' for a space, or a string table "
            L"ID); feature not applied",
            arg.c_str());
        return Outcome::kFailed;
      }
    } else if (typeNames.size() == kMaxTypes) {
      Log(L"overhealHitpointBars: more than %u unit types (expected: [UnitType ...] [segment[=RRGGBB]] [stat[=Label]] "
          L"[log]); feature not applied",
          static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      typeNames.push_back(arg);
    }
  }
  if (typeNames.empty()) {
    typeNames.push_back("AbstractOverheal");
  }

  if (!VerifyAll("overhealHitpointBars",
                 {&sites::kOverhealBarRatio, &sites::kOverhealGroupRatio, &sites::kOverhealPanelMax,
                  &sites::kOverhealStatMax, &sites::kOverhealStatBase, &sites::kOverhealInfoProto,
                  &sites::kOverhealInfoBase, &sites::kOverhealInfoMax, &sites::kMaxHitpointsGetter,
                  &sites::kHealthRatio, &sites::kInitialHitpointsTag, &sites::kMaxHitpointsTag, &sites::kIsA,
                  &sites::kIsATrue})) {
    return Outcome::kFailed;
  }
  if (segment && !VerifyAll("overhealHitpointBars segment",
                            {&sites::kOverhealSegmentQueue, &sites::kHpBarQueue, &sites::kHpBarRenderStart,
                             &sites::kHpBarRenderLoop, &sites::kDynamicVbLock, &sites::kDynamicVbFull,
                             &sites::kOverhealTextStat, &sites::kOverhealTextStatSplit,
                             &sites::kOverhealPortraitTail, &sites::kOverhealPortraitColours,
                             &sites::kHealthBarGadgets, &sites::kProgressGadget,
                             &sites::kGadgetRelease, &sites::kProgressFill,
                             &sites::kBStringFromWide, &sites::kBStringFree})) {
    return Outcome::kFailed;
  }
  if (g_statRow && !VerifyAll("overhealHitpointBars stat",
                              {&sites::kOverhealStatRow, &sites::kGroupHealthRow, &sites::kGadgetRef,
                               &sites::kGadgetRelease, &sites::kBStringFromWide, &sites::kBStringSet,
                               &sites::kBStringFree, &sites::kBStringFromId})) {
    return Outcome::kFailed;
  }
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    if (!RequestAbstractUnitType(typeNames[i].c_str(), &g_uhcOverhealTypes[i])) {
      return Outcome::kFailed;
    }
  }
  g_uhcOverhealTypeCount = static_cast<std::int32_t>(typeNames.size());
  g_uhcOverhealLog = log ? 1 : 0;

  // Each hook re-does the stolen instruction with the reference in place of the max, then jumps
  // to the instruction after it.
  const Hook hooks[] = {
      {0x0045FAAF, 5, &UhcOverhealBarHook},       // call 45F295h: the floating bar's fill
      {0x004C5014, 5, &UhcOverhealGroupHook},     // call 45F295h: the selection group's average
      {0x00698B35, 5, &UhcOverhealPanelMaxHook},  // call 480408h: unitHitPointsValue's max
      {0x004D7575, 6, &UhcOverhealStatMaxHook},   // mov eax,[ecx+0B4h]: the stat row's inlined max
      {0x004D7615, 6, &UhcOverhealStatBaseHook},  // fld [eax+98h]: the stat row's base
      {0x009AFA2A, 6, &UhcOverhealInfoBaseHook},  // fld [ecx+98h]: ObjectInfo's base
      {0x009AFA4E, 5, &UhcOverhealInfoMaxHook},   // call 480408h: ObjectInfo's max
  };
  for (const Hook& hook : hooks) {
    if (!WriteJmp(hook.va, reinterpret_cast<const void*>(hook.target), hook.length)) {
      return Outcome::kFailed;
    }
  }
  if (segment) {
    // The text colour, as the UI markup <color=r, g, b> takes it (0xBA1E44: '<color=1, 0, 0>').
    const double red = ((g_segmentColour >> 16) & 0xFF) / 255.0;
    const double green = ((g_segmentColour >> 8) & 0xFF) / 255.0;
    const double blue = (g_segmentColour & 0xFF) / 255.0;
    swprintf_s(g_uhcOverhealFmtPlain, L"<color=%.2f, %.2f, %.2f>%%d/%%d</color>", red, green, blue);
    swprintf_s(g_uhcOverhealFmtSplit, L"<color=%.2f, %.2f, %.2f>%%d/%%d (%%d+%%d)</color>", red, green, blue);
    g_uhcOverhealTextColor = 1;
    // Each replaces 5 or 6 bytes and re-does them (a push of the format, or the stolen
    // instructions), then jumps to the next instruction.
    const Hook segmentHooks[] = {
        {0x0045FB6C, 5, &UhcOverhealSegmentQueueHook},   // jmp 4516B3h: after the bar was queued
        {0x0045C4B9, 6, &UhcOverhealSegmentRenderHook},  // mov ebx,[ebp+8D4h]: the renderer's count
        {0x0045CB72, 6, &UhcOverhealSegmentVertexHook},  // add eax,1 / add ecx,1Ch: a record's end
        {0x004D7651, 5, &UhcOverhealTextStatHook},       // push '%d/%d': the stat row
        {0x0069A9C0, 5, &UhcOverhealTextStatSplitHook},  // push '%d/%d (%d+%d)': the stat row
        {0x004C83DF, 9, &UhcOverhealPortraitHook},       // lea ecx,[esp+70h] / call 4010CAh: the portrait bar
    };
    for (const Hook& hook : segmentHooks) {
      if (!WriteJmp(hook.va, reinterpret_cast<const void*>(hook.target), hook.length)) {
        return Outcome::kFailed;
      }
    }
  }
  // mov edi,2 / mov [esp+2Ch],edi: the row counter after the HP row.
  if (g_statRow && !WriteJmp(0x004D76DB, reinterpret_cast<const void*>(&UhcOverhealStatRowHook), 9)) {
    return Outcome::kFailed;
  }
  if (g_statRow && !AddUnitPanelRow(&UhcOverhealUnitPanel)) {
    return Outcome::kFailed;
  }

  std::string names;
  for (const std::string& name : typeNames) {
    names += names.empty() ? name : ", " + name;
  }
  wchar_t segmentText[96] = L"";
  if (segment) {
    swprintf_s(segmentText, L", HP above it shown as a segment and texts coloured %06X", g_segmentColour & 0xFFFFFFu);
  }
  wchar_t statText[96] = L"";
  if (g_statRow && g_statLabelId >= 0) {
    swprintf_s(statText, L", an overheal stat row labelled by string %d", g_statLabelId);
  } else if (g_statRow) {
    swprintf_s(statText, L", an overheal stat row labelled '%ls'", g_statLabel.c_str());
  }
  Log(L"overhealHitpointBars: HP bars and HP texts of units of unittype %hs take InitialHitpoints as 100 %%%ls%ls%ls "
      L"(display only)",
      names.c_str(), segmentText, statText, log ? L", the first unit of each proto logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/overheal_hooks.asm

```asm
; Hooks for overhealHitpointBars. Each is entered through a jmp written over the stock code and
; leaves through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Hit
; points"). Only display code is hooked: the max HP getter 0x480408 and the health ratio 0x45F295
; stay stock for their simulation callers. At every hook site the FPU stack is empty (the HP was
; just stored with fistp, or the site is a call) and EAX, ECX, EDX and the flags are dead after
; the continuation; the helpers preserve EBX, ESI, EDI and EBP.
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcOverhealTypes:SDWORD      ; marker unittype IDs, set on each database load; -1 before
EXTERNDEF g_uhcOverhealTypeCount:SDWORD  ; how many of them the cfg line names
EXTERNDEF g_uhcOverhealLog:SDWORD        ; 1 with "overhealHitpointBars ... log"
EXTERNDEF g_uhcOverhealTextColor:SDWORD  ; 1 with "segment": an HP text above its 100 % is coloured
EXTERNDEF g_uhcOverhealFmtPlain:WORD     ; '<color=r, g, b>%d/%d</color>'
EXTERNDEF g_uhcOverhealFmtSplit:WORD     ; '<color=r, g, b>%d/%d (%d+%d)</color>'

UhcOverhealLogReference PROTO STDCALL unit:DWORD, reference:DWORD, maxHp:DWORD
UhcOverhealQueueSegment PROTO STDCALL unit:DWORD, pos:DWORD, reference:DWORD
UhcOverhealSegmentFit PROTO STDCALL world:DWORD
UhcOverhealSegmentVertices PROTO STDCALL world:DWORD, recordOffset:DWORD, vertices:DWORD, camera:DWORD
UhcOverhealPortrait PROTO STDCALL panel:DWORD, selGroup:DWORD
UhcOverhealStatRow PROTO STDCALL panel:DWORD, unit:DWORD, row:DWORD

SEGMENT_PLAYER EQU 804F5648h            ; the player ID of a segment record ('OVH', negative: no player colour)

.data
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): integer code, ret 4
maxHitpoints    dd 00480408h    ; float thiscall(unit): override if > -1e-6, else [proto+98h], else 0
barNext         dd 0045FAB4h    ; fstp [esp+10h]: the floating bar's fill, then its clamp to [0, 1]
groupNext       dd 004C5019h    ; fadd [esi+1Ch] / pop edi / pop ebx / fidiv [esi+14h]: group average
panelMaxNext    dd 00698B3Ah    ; fnstcw / ... / fistp: the max of unitHitPointsValue's '%d/%d'
statMaxNext     dd 004D75ADh    ; fnstcw / ... / fistp [esp+18h]: the stat row's max
statBaseNext    dd 004D761Bh    ; fnstcw / ... / fistp [esp+0Ch]: the stat row's base
infoBaseNext    dd 009AFA30h    ; fnstcw / mov ecx,esi / ... / fistp [esp+20h]: ObjectInfo's base
infoMaxNext     dd 009AFA53h    ; fnstcw / ... / fistp [esp+24h]: ObjectInfo's max
minHitpoints    real4 1.0E-6    ; the stock threshold of 0x45F295 (0xB9FB64)
barQueueExit    dd 004516B3h    ; where the bar chunk goes after queueing the bar (jmp at 0x45FB6C)
renderCountNext dd 0045C4BFh    ; test ebx,ebx / mov [esp+3Ch],ebx / jle: the renderer's record count
vertexLoopNext  dd 0045CB78h    ; add edi,24h / add ebx,24h / cmp eax,[ebp+8D4h]: the next record
textStatNext    dd 004D7656h    ; push eax / call 444EFBh: the stat row's '%d/%d'
textStatSplitNext dd 0069A9C5h  ; push ecx / call 444EFBh: the stat row's '%d/%d (%d+%d)'
bstringFree     dd 004010CAh    ; void thiscall(BString*): the free 0x4C83E3 calls
portraitNext    dd 004C83E8h    ; mov ecx,[esp+1C4h] / call 4C83F6h: after the portrait bar
statRowNext     dd 004D76E4h    ; mov edx,[0CF059Ch]: the rows after the HP row

.code

; AL = 1 if proto ECX has one of the configured unit types and 1e-6 < InitialHitpoints [+9Ch] <
; MaxHitpoints [+98h], else AL = 0. Clobbers EAX, ECX, EDX and the flags, like the is-a test it
; calls; leaves the FPU stack as it found it (it needs one free slot).
OverhealUsesInitial PROC PRIVATE
    push esi
    push edi
    mov esi, ecx                    ; proto
    xor edi, edi
nextType:
    cmp edi, g_uhcOverhealTypeCount
    jge notMarked
    mov eax, g_uhcOverhealTypes[edi*4]
    inc edi
    test eax, eax
    jl nextType                     ; not registered yet (no database loaded)
    push eax
    mov ecx, esi
    call protoIsType
    test al, al
    je nextType
    fld dword ptr [esi+9Ch]         ; InitialHitpoints
    fcom minHitpoints
    fnstsw ax
    test ah, 45h                    ; C0, C2 or C3: not above 1e-6, or NaN
    jne popNo
    fcomp dword ptr [esi+98h]       ; against MaxHitpoints, and popped
    fnstsw ax
    and ah, 45h
    cmp ah, 1                       ; C0 alone: InitialHitpoints < MaxHitpoints
    sete al
    jmp done
popNo:
    fstp st(0)
notMarked:
    xor eax, eax
done:
    pop edi
    pop esi
    ret
OverhealUsesInitial ENDP

; float thiscall(unit ECX): the 100 % reference of the unit's HP, in ST0 like 0x480408. Stock it
; is the max (0x480408); for a unit whose proto uses its InitialHitpoints (OverhealUsesInitial)
; it is InitialHitpoints, or max x InitialHitpoints / MaxHitpoints when a modifier gave the unit
; another max. InitialHitpoints is returned as it is, not through the product: the texts truncate
; (fistp with RC = 11b), and 165 x 150 / 165 rounded at single precision could print 149. Called
; with an empty FPU stack; preserves EBX, ESI, EDI and EBP.
OverhealReference PROC PRIVATE
    push esi
    push edi
    mov esi, ecx                    ; unit
    call maxHitpoints               ; ST0 = max
    mov edi, dword ptr [esi+5Ch]    ; the unit's proto (its player's copy)
    test edi, edi
    je done
    mov ecx, edi
    call OverhealUsesInitial
    test al, al
    je done
    fld dword ptr [edi+98h]
    fcomp st(1)                     ; MaxHitpoints against the unit's max
    fnstsw ax
    test ah, 40h                    ; C3: equal, no modifier
    je scaled
    fld dword ptr [edi+9Ch]         ; reference = InitialHitpoints, max
    jmp haveReference
scaled:
    fld st(0)                       ; max, max
    fmul dword ptr [edi+9Ch]
    fdiv dword ptr [edi+98h]        ; reference = max x InitialHitpoints / MaxHitpoints, max
haveReference:
    cmp g_uhcOverhealLog, 0
    jne logReference
    fstp st(1)                      ; reference
    jmp done
logReference:
    sub esp, 8
    fstp dword ptr [esp]            ; [esp] = reference
    fstp dword ptr [esp+4]          ; [esp+4] = max; the FPU stack is empty for the C++ call
    push dword ptr [esp+4]          ; maxHp
    push dword ptr [esp+4]          ; reference (moved to [esp+4] by the push above)
    push esi                        ; unit
    call UhcOverhealLogReference
    fld dword ptr [esp]             ; ST0 = reference
    add esp, 8
done:
    pop edi
    pop esi
    ret
OverhealReference ENDP

; float thiscall(unit ECX): HP [+64h] / reference, with the stock rules of 0x45F295 for HP / max:
; 0 when the reference is below 1e-6, 1.0 when the HP reaches it. Returns in ST0; preserves EBX,
; ESI, EDI and EBP.
OverhealRatio PROC PRIVATE
    push esi
    mov esi, ecx                    ; unit
    call OverhealReference          ; ST0 = reference
    fcom minHitpoints
    fnstsw ax
    test ah, 5
    jnp zero                        ; C0 alone, as at 0x45F2C5: reference < 1e-6
    fcom dword ptr [esi+64h]
    fnstsw ax
    test ah, 41h
    jnp full                        ; C0 or C3 alone, as at 0x45F2D3: reference <= HP
    fdivr dword ptr [esi+64h]       ; HP / reference
    jmp done
zero:
    fstp st(0)
    fldz
    jmp done
full:
    fstp st(0)
    fld1
done:
    pop esi
    ret
OverhealRatio ENDP

; float thiscall(database proto ECX): the base of the '(%d+%d)' split, which stock reads from the
; database proto's MaxHitpoints [+98h]: its InitialHitpoints [+9Ch] instead when it uses them.
; Returns in ST0; preserves EBX, ESI, EDI and EBP.
OverhealBase PROC PRIVATE
    push esi
    mov esi, ecx                    ; database proto
    call OverhealUsesInitial
    test al, al
    je useMax
    fld dword ptr [esi+9Ch]
    jmp done
useMax:
    fld dword ptr [esi+98h]
done:
    pop esi
    ret
OverhealBase ENDP

; Replaces call 45F295h at 0x45FAAF in the unit visual update's bar chunk 0x45FAA2: the floating
; HP bar's fill, which 0x45FAB8 clamps to [0, 1] before 0x45FB71 queues the bar. ECX = ESI = the
; unit. A unit under construction takes the build fraction (0x6A1431) and does not come here.
UhcOverhealBarHook PROC
    TRACE_ONCE "overhealHitpointBars (0x45FAAF)"
    call OverhealRatio
    jmp barNext
UhcOverhealBarHook ENDP

; Replaces jmp 4516B3h at 0x45FB6C, right after the floating bar of unit ESI was queued (0x45FB67):
; with "segment", a unit above its 100 % gets a second record, the overheal segment, which the
; renderer hooks below draw over the right end of the bar. [esp+18h] = the bar's position (the
; record copies it), [esp+15h] = under construction (that bar is the build progress). The FPU
; stack is empty here and every register is kept for 0x4516B3.
UhcOverhealSegmentQueueHook PROC
    TRACE_ONCE "overhealHitpointBars segment queue (0x45FB6C)"
    cmp byte ptr [esp+15h], 0
    jne done
    pushad
    mov ecx, esi
    call OverhealReference          ; ST0 = the unit's 100 % (its max when not marked)
    sub esp, 4
    fstp dword ptr [esp]            ; reference
    lea eax, [esp+3Ch]              ; the position: [esp+18h] at entry, +20h pushad, +4 reference
    push eax
    push esi                        ; unit
    call UhcOverhealQueueSegment    ; queues the segment when HP > reference
    popad
done:
    jmp barQueueExit
UhcOverhealSegmentQueueHook ENDP

; Replaces mov ebx,[ebp+8D4h] at 0x45C4B9 in the bar renderer FUN_0045C4AF (EBP = world): before
; the vertex lock, UhcOverhealSegmentFit drops the segment records when the queue would not fit
; in the dynamic vertex buffer, so they never cost a stock bar; then the stolen load of the count.
UhcOverhealSegmentRenderHook PROC
    TRACE_ONCE "overhealHitpointBars segment fit (0x45C4B9)"
    pushad
    push ebp
    call UhcOverhealSegmentFit
    popad
    mov ebx, dword ptr [ebp+8D4h]   ; stolen 0x45C4B9
    jmp renderCountNext
UhcOverhealSegmentRenderHook ENDP

; Replaces add eax,1 / add ecx,1Ch at 0x45CB72, the end of the renderer's per-record loop: ECX =
; the record's offset in [ebp+8D0h], EDI = its sixth vertex, ESI = the camera. The six vertices of
; a segment record are rewritten (UhcOverhealSegmentVertices); every other record is left as the
; stock loop wrote it. The FPU stack is empty here (checked over one iteration); the flags are
; set again by the stolen adds.
UhcOverhealSegmentVertexHook PROC
    TRACE_ONCE "overhealHitpointBars segment vertices (0x45CB72)"
    push edx
    mov edx, dword ptr [ebp+8D0h]
    cmp dword ptr [edx+ecx+14h], SEGMENT_PLAYER
    pop edx
    jne done
    pushad
    push esi                        ; camera
    lea eax, [edi-0B4h]             ; the first vertex, five 24h-byte vertices back
    push eax
    push ecx                        ; the record's offset
    push ebp                        ; world
    call UhcOverhealSegmentVertices
    popad
done:
    add eax, 1                      ; stolen 0x45CB72
    add ecx, 1Ch                    ; stolen 0x45CB75
    jmp vertexLoopNext
UhcOverhealSegmentVertexHook ENDP

; Replaces a push of an HP text's format (5 bytes) right after the HP ([esp]) and the 100 % value
; ([esp+4]) were pushed: with "segment", an HP above it gets the coloured copy of the format. Only
; the flags change (the next instruction does not read them); stock HP never exceeds the max, so
; an unmarked unit always gets the stock format. Only the stat row's two formats are hooked: its
; gadget draws the <color> markup (seen in game). The minimized UI's unitHitPointsValue (0x698B63)
; formats the same way, but its gadget prints the markup as text (seen in game), so it stays white;
; ObjectInfo (0x9AFA8B, 0x9AFAA5), an editor panel, is not hooked either.
OVERHEAL_TEXT_HOOK MACRO hookName:REQ, traceText:REQ, stockFormat:REQ, colourFormat:REQ, nextAddress:REQ
hookName PROC
    TRACE_ONCE traceText
    push stockFormat
    cmp g_uhcOverhealTextColor, 0
    je @F
    push eax
    mov eax, dword ptr [esp+8]      ; HP
    cmp eax, dword ptr [esp+0Ch]    ; the 100 % value
    pop eax
    jle @F
    mov dword ptr [esp], OFFSET colourFormat
@@:
    jmp nextAddress
hookName ENDP
ENDM

OVERHEAL_TEXT_HOOK UhcOverhealTextStatHook, "overhealHitpointBars text (0x4D7651)", 0BA2054h, g_uhcOverhealFmtPlain, textStatNext
OVERHEAL_TEXT_HOOK UhcOverhealTextStatSplitHook, "overhealHitpointBars text (0x69A9C0)", 0C34A54h, g_uhcOverhealFmtSplit, textStatSplitNext

; Replaces call 45F295h at 0x4C5014 in FUN_004C4FB5, which adds unit EBP (= ECX) to the selection
; group ESI: [esi+1Ch] keeps the group's average health, which the group bar (colour and fill,
; 0x4C82EA) and 'Group Health' (0x69AA75) show. EBX and EDI are popped at 0x4C501C.
UhcOverhealGroupHook PROC
    TRACE_ONCE "overhealHitpointBars (0x4C5014)"
    call OverhealRatio
    jmp groupNext
UhcOverhealGroupHook ENDP

; Replaces call 480408h at 0x698B35, the max of the selection panel's unitHitPointsValue text
; ('%d/%d', 0x698B63). ECX = EBX = the unit; the HP is already stored at [esp+88h].
UhcOverhealPanelMaxHook PROC
    TRACE_ONCE "overhealHitpointBars (0x698B35)"
    call OverhealReference
    jmp panelMaxNext
UhcOverhealPanelMaxHook ENDP

; Replaces mov eax,[ecx+0B4h] at 0x4D7575, the first instruction of the max HP getter inlined in
; the selection panel's 'Hit Points' stat row: 0x4D7575..0x4D75AC leaves the max in ST0 at
; 0x4D75AD, and every branch of it stays inside or rejoins there. ECX = EDI = the unit.
UhcOverhealStatMaxHook PROC
    TRACE_ONCE "overhealHitpointBars (0x4D7575)"
    call OverhealReference
    jmp statMaxNext
UhcOverhealStatMaxHook ENDP

; Replaces fld [eax+98h] at 0x4D7615, the same row's base (EAX = the database proto, not null):
; below the max, the row prints '%d/%d (%d+%d)' (0x69A9B0) with this base.
UhcOverhealStatBaseHook PROC
    TRACE_ONCE "overhealHitpointBars (0x4D7615)"
    mov ecx, eax
    call OverhealBase
    jmp statBaseNext
UhcOverhealStatBaseHook ENDP

; Replaces fld [ecx+98h] at 0x9AFA2A in FUN_009AF31A (the ObjectInfo_singleUnitStats panel), the
; base of its '%d/%d (%d+%d)' (0x9AFA8B). ECX = the database proto ([esp+30h], from 0x45316E).
UhcOverhealInfoBaseHook PROC
    TRACE_ONCE "overhealHitpointBars (0x9AFA2A)"
    call OverhealBase
    jmp infoBaseNext
UhcOverhealInfoBaseHook ENDP

; Replaces call 480408h at 0x9AFA4E, the same panel's max ('%d/%d' 0x9AFAA5, or the split).
; ECX = ESI = the unit.
UhcOverhealInfoMaxHook PROC
    TRACE_ONCE "overhealHitpointBars (0x9AFA4E)"
    call OverhealReference
    jmp infoMaxNext
UhcOverhealInfoMaxHook ENDP

; Replaces lea ecx,[esp+70h] / call 4010CAh (9 bytes) at 0x4C83DF, the end of the selection
; panel's portrait bar: the colour gadget was filled and raised. [esp+50h] = the panel, [esp+78h] =
; the group, at the stack level of 0x4C82E6. UhcOverhealPortrait fills and raises the UI data's
; overheal gadget, if any; then the stolen free. The FPU stack is empty (the fcomp pairs at
; 0x4C82F5 / 0x4C830A pop what they load); EAX, ECX, EDX and the flags are dead after the free.
UhcOverhealPortraitHook PROC
    TRACE_ONCE "overhealHitpointBars portrait bar (0x4C83DF)"
    pushad
    push dword ptr [esp+20h+78h]    ; group
    push dword ptr [esp+24h+50h]    ; panel
    call UhcOverhealPortrait
    popad
    lea ecx, [esp+70h]              ; stolen 0x4C83DF
    call bstringFree                ; stolen 0x4C83E3: call 4010CAh
    jmp portraitNext
UhcOverhealPortraitHook ENDP

; Replaces mov edi,2 / mov [esp+2Ch],edi (9 bytes) at 0x4D76DB, the stat panel fill right after
; the HP row: EDI and [esp+2Ch] are the next free row (the Group Health branch 0x69A9D3 writes row
; EDI, then adds 1 to both). UhcOverhealStatRow writes the overheal row there for a marked unit
; ([esp+38h], the panel [esp+50h]); when it did, the row is counted the same way. EAX, ECX, EDX
; and the flags are dead at 0x4D76E4 (mov edx,[0CF059Ch] / mov eax,[edx] / ... / mov ecx,0C66500h).
UhcOverhealStatRowHook PROC
    TRACE_ONCE "overhealHitpointBars stat row (0x4D76DB)"
    mov edi, 2                      ; stolen 0x4D76DB
    mov dword ptr [esp+2Ch], edi    ; stolen 0x4D76E0
    pushad
    push edi                        ; row
    push dword ptr [esp+24h+38h]    ; unit
    push dword ptr [esp+28h+50h]    ; panel
    call UhcOverhealStatRow
    mov dword ptr [esp+1Ch], eax    ; the pushad slot of EAX: the result survives popad
    popad
    test al, al
    jz done
    add edi, 1
    mov dword ptr [esp+2Ch], edi
done:
    jmp statRowNext
UhcOverhealStatRowHook ENDP

; Public forms of the reference helpers for the other overheal keys (overhealSources,
; overhealDecay), cdecl so the C++ side can call them: the same definition, not a copy.
; float UhcOverhealReferenceOf(unit): the 100 % reference in ST0 (the stock max for an unmarked unit).
UhcOverhealReferenceOf PROC
    mov ecx, dword ptr [esp+4]
    jmp OverhealReference
UhcOverhealReferenceOf ENDP

; float UhcOverhealRatioOf(unit): HP / reference with the stock rules of 0x45F295, in ST0.
UhcOverhealRatioOf PROC
    mov ecx, dword ptr [esp+4]
    jmp OverhealRatio
UhcOverhealRatioOf ENDP

; int UhcOverhealMarked(proto): 1 if the proto is of a configured type and 1e-6 <
; InitialHitpoints < MaxHitpoints (a unit of it has a reference below its max), else 0.
UhcOverhealMarked PROC
    mov ecx, dword ptr [esp+4]
    call OverhealUsesInitial
    movzx eax, al
    ret
UhcOverhealMarked ENDP

END
```

## overhealSources

Contract: [overhealSources](../porting-to-another-dll.md#overhealsources).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `IsA` `0x44D7FA` (105 B), `HealthRatio` `0x45F295` (72 B), `MaxHitpointsGetter` `0x480408` (38 B), `OverhealAddEntry` `0x4823A3` (10 B), `HealSearchRatio` `0x9CD982` (24 B), `HealTickMax` `0x9E0BA5` (41 B), `HealTickAdd` `0x9E0CCF` (38 B).

### src/features/overhealsources.cpp

```cpp
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
#include <cstdint>
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
std::int32_t UhcOverhealMarked(const char* proto);
}

namespace uhc {
extern void (*g_overhealGain)(const char* unit, bool restartDelay);  // set by overhealDecay
extern void (*g_hpLoss)(const char* unit, float amount);             // set by detonationDeath: every loss
}

namespace {

constexpr std::size_t kMaxTypes = 8;

using IsAFn = bool(__thiscall*)(const char* proto, std::int32_t type);
const auto kIsA = reinterpret_cast<IsAFn>(0x0044D7FA);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

bool g_log = false;
bool g_cap = false;      // overhealSources is on
bool g_addHooked = false;
std::set<std::string, std::less<>> g_loggedCaps;     // proto names, "log" only
std::set<std::string, std::less<>> g_loggedSources;  // healer proto names, "log" only

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

bool __stdcall UhcOverhealIsSource(const char* healer) {
  const char* proto = healer == nullptr ? nullptr : Field<const char*>(healer, 0x5C);
  for (std::int32_t i = 0; proto != nullptr && i < g_uhcOverhealSourceTypeCount; ++i) {
    if (g_uhcOverhealSourceTypes[i] >= 0 && kIsA(proto, g_uhcOverhealSourceTypes[i])) {
      return true;
    }
  }
  return false;
}

// True for a marked target and a healer that gives no overheal: the heal stops at the reference.
bool __stdcall UhcOverhealUseReference(const char* target, const char* healer) {
  const char* proto = target == nullptr ? nullptr : Field<const char*>(target, 0x5C);
  return proto != nullptr && UhcOverhealMarked(proto) != 0 && !UhcOverhealIsSource(healer);
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
  if (!g_cap || g_uhcOverhealAllow != 0) {
    if (uhc::g_overhealGain != nullptr && hp + *amount > reference) {
      uhc::g_overhealGain(unit, g_uhcOverhealRegen == 0);
    }
    if (!g_cap) {
      return;
    }
    if (g_log && hp + *amount > reference && FirstLog(g_loggedSources, ProtoName(unit))) {
      uhc::Log(L"overhealSources: unit %d (%hs) is healed above its 100 %% %.1f by a source healer (HP %.1f + %.2f); "
               L"logged once per proto",
               Field<std::int32_t>(unit, 0x10), ProtoName(unit), static_cast<double>(reference),
               static_cast<double>(hp), static_cast<double>(*amount));
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
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
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
  for (const std::string& name : typeNames) {
    names += names.empty() ? name : ", " + name;
  }
  Log(L"overhealSources: only healers of unittype %hs heal marked units above their 100 %%; every other heal stops "
      L"there%ls (multiplayer unverified)",
      names.c_str(), g_log ? L", the first cap and source heal of each proto logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/overhealsources_hooks.asm

```asm
; Hooks for overhealSources (and the add-HP hook overhealDecay shares). Entered through a jmp
; written over the stock code; each leaves through an explicit jmp to a verified continuation
; (docs/engine-symbols.md, "Unit types and healing").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcOverhealAllow:SDWORD   ; 1 while a source healer's heal tick adds HP
EXTERNDEF g_uhcOverhealRegen:SDWORD   ; 1 while a regeneration adds HP (overhealDecay)

UhcOverhealAddHp PROTO STDCALL unit:DWORD, amount:DWORD         ; may lower [amount]
UhcOverhealUseReference PROTO STDCALL target:DWORD, healer:DWORD  ; AL: a normal healer, a marked target
UhcOverhealIsSource PROTO STDCALL healer:DWORD                   ; AL: the healer gives overheal
UhcOverhealReferenceOf PROTO C unit:DWORD                         ; ST0 (overheal_hooks.asm)
UhcOverhealRatioOf PROTO C unit:DWORD                             ; ST0 (overheal_hooks.asm)

.data
addHpNext       dd 004823ABh    ; jbe 4823FEh: the adder after its stolen cmp [esi+8],8
addHp           dd 004823A3h    ; thiscall(unit, amount, flag), ret 8: HP += amount (our hook first)
maxHitpoints    dd 00480408h    ; float thiscall(unit): the stock max
healthRatio     dd 0045F295h    ; float thiscall(unit): the stock HP / max
tickMaxNext     dd 009E0BC0h    ; fcomp [edi+64h] / fnstsw / test ah,41h / jnp 9E0D3Fh: HP < max?
tickAddNext     dd 009E0CEEh    ; fld [esp+10h] / fadd [esi+68h]: the tick's bookkeeping
searchRatioNext dd 009CD989h    ; fcomp 1.0 / fnstsw / test ah,1 / je 9CDA3Fh: ratio < 1?
regenNext       dd 00490886h    ; mov ecx,[esp+1Ch] / add ecx,1: the regeneration loop
danceRegenNext  dd 0067A040h    ; add ebp,1 / cmp ebp,ebx / jl: the Regeneration dance loop

.code

; Replaces push ecx / push esi / mov esi,ecx / cmp dword ptr [esi+8],8 (8 bytes) at the entry of
; the add-HP function FUN_004823A3 (ECX = unit, [esp+4] = amount, [esp+8] = flag). Every heal
; and every damage that goes through it passes here first: UhcOverhealAddHp may lower a positive
; amount (the cap) and notes a unit that goes above its reference (overhealDecay). Then the
; stolen instructions run as they were; jbe at 0x4823AB reads the flags of the stolen cmp.
UhcOverhealAddHook PROC
    TRACE_ONCE "overheal add HP (0x4823A3)"
    pushad
    lea eax, dword ptr [esp+24h]    ; &amount: [esp+4] at entry, +20h for pushad
    push eax
    push ecx                        ; unit
    call UhcOverhealAddHp
    popad
    push ecx                        ; stolen 0x4823A3
    push esi                        ; stolen 0x4823A4
    mov esi, ecx                    ; stolen 0x4823A5
    cmp dword ptr [esi+8], 8        ; stolen 0x4823A7
    jmp addHpNext
UhcOverhealAddHook ENDP

; Replaces call 480408h at 0x9E0BBB in the heal tick FUN_009E0B53 (ECX = EDI = target, ESI = the
; heal action, healer at [esi+10h]): each tick heals only while HP < this value, and ends the
; action (state 10) otherwise. For a healer that gives no overheal and a marked target the value
; is the target's reference, so the action ends there; else the stock max. The FPU stack is empty
; at the site; ECX and EDX are written again after 0x9E0BC0 before they are read.
UhcOverhealTickMaxHook PROC
    TRACE_ONCE "overhealSources heal tick (0x9E0BBB)"
    push dword ptr [esi+10h]        ; healer
    push edi                        ; target
    call UhcOverhealUseReference
    test al, al
    jne useReference
    mov ecx, edi
    call maxHitpoints               ; stolen 0x9E0BBB
    jmp tickMaxNext
useReference:
    push edi
    call UhcOverhealReferenceOf
    add esp, 4
    jmp tickMaxNext
UhcOverhealTickMaxHook ENDP

; Replaces call 4823A3h at 0x9E0CE9, where the heal tick adds this tick's HP to the target (ECX =
; EDI = target, the amount and 1 pushed, ESI = the action). A source healer's heal is let through
; above the reference: g_uhcOverhealAllow is set for the call and cleared after it.
UhcOverhealTickAddHook PROC
    TRACE_ONCE "overhealSources heal (0x9E0CE9)"
    push ecx
    push dword ptr [esi+10h]        ; healer
    call UhcOverhealIsSource
    pop ecx
    movzx eax, al
    mov g_uhcOverhealAllow, eax
    call addHp                      ; stolen 0x9E0CE9
    mov g_uhcOverhealAllow, 0
    jmp tickAddNext
UhcOverhealTickAddHook ENDP

; Replaces the first call 45F295h at 0x9CD984 in the automatic heal search FUN_009CD865 (ECX =
; ESI = candidate, healer at [ebp+4]), whose result must be below 1.0 for the candidate to count.
; For a healer that gives no overheal and a marked candidate it is HP / reference, so a unit at
; its reference is no candidate; else the stock ratio. The second ratio call (the 1e-6 floor) is
; stock.
UhcOverhealSearchRatioHook PROC
    TRACE_ONCE "overhealSources heal search (0x9CD984)"
    push dword ptr [ebp+4]          ; healer
    push esi                        ; candidate
    call UhcOverhealUseReference
    test al, al
    jne useReference
    mov ecx, esi
    call healthRatio                ; stolen 0x9CD984
    jmp searchRatioNext
useReference:
    push esi
    call UhcOverhealRatioOf
    add esp, 4
    jmp searchRatioNext
UhcOverhealSearchRatioHook ENDP

; overhealDecay: replace call 4823A3h at 0x490881 (the unit's own regeneration, FUN_004905E1) and
; at 0x67A03B (the Regeneration dance), with the amount and 1 pushed and ECX = ESI = the unit:
; g_uhcOverhealRegen is set around the call, so these gains do not restart the decay's delay.
; Only memory writes are added; registers and flags are as after the stock call.
UhcOverhealRegenAddHook PROC
    TRACE_ONCE "overhealDecay regeneration (0x490881)"
    mov g_uhcOverhealRegen, 1
    call addHp                      ; stolen 0x490881
    mov g_uhcOverhealRegen, 0
    jmp regenNext
UhcOverhealRegenAddHook ENDP

UhcOverhealDanceRegenAddHook PROC
    TRACE_ONCE "overhealDecay Regeneration dance (0x67A03B)"
    mov g_uhcOverhealRegen, 1
    call addHp                      ; stolen 0x67A03B
    mov g_uhcOverhealRegen, 0
    jmp danceRegenNext
UhcOverhealDanceRegenAddHook ENDP

END
```

## overhealDecay

Contract: [overhealDecay](../porting-to-another-dll.md#overhealdecay).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `IsA` `0x44D7FA` (105 B), `MaxHitpointsGetter` `0x480408` (38 B), `HpSetter` `0x4820A1` (34 B), `OverhealAddEntry` `0x4823A3` (10 B), `RegenAddHp` `0x49087C` (18 B), `DanceRegenAddHp` `0x67A036` (21 B), `UnitAliveSlot` `0xB9355C` (4 B).

### src/features/overhealdecay.cpp

```cpp
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
```
