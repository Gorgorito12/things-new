# Code for WoL: Interface

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [abilitySlots](#abilityslots)
- [wonderPanelSkipAuras](#wonderpanelskipauras)
- [nativePreview](#nativepreview)
- [noCorpseDopples](#nocorpsedopples)
- [steadyHitpointBars](#steadyhitpointbars)
- [inventoryBars](#inventorybars)
- [multiplierDecimals](#multiplierdecimals)
- [attackTypeIcons](#attacktypeicons)
- [minUIStats](#minuistats)
- [playerIcon](#playericon)
- [autoScout](#autoscout)
- [transformChecks](#transformchecks)

## abilitySlots

Contract: [abilitySlots](../porting-to-another-dll.md#abilityslots).

Sites: `AbilityPage11Branch` `0x4C5AEB` (16 B), `AbilitySlotCopies` `0x695BB6` (76 B), `AbilityNthCall` `0x696C0B` (101 B), `AbilityButtonCost` `0x696C70` (11 B).

### src/features/abilityslots.cpp

```cpp
// abilitySlots <N> [log]: how many abilities (abilities.xml) the command panel asks for per unit.
//
// A proto's <Command page='11'>Abilities</Command> is the Abilities page of the command panel
// (commandpanel2, FUN_0046188E). On each refresh the panel appends that command entry 6 times:
// once at 0x4C5ACA, then 5 more in the do-while at 0x695BB6 (mov edi,5 at 0x695BD2). Each copy
// asks AbilityMgr::GetNth (0x6EE5CC) for the unit's next ability, n = 0, 1, ... 5. GetNth counts
// the unit's records that are not NeverShowInGrid, so an ability at position 7 or later never
// gets a button, even when the first 6 are disabled by their <Tech> or <Age>: a disabled one
// takes no column but still uses up one n. abilitySlots writes N-1 over the 5, so the panel asks
// for n = 0..N-1. GetNth returns false past the end of a unit's list, so a unit with 6 abilities
// or fewer looks the same. The extra buttons wrap to the next row of the 6x6 grid like any page
// wider than 6 columns, and the grid still stops at row 6.
//
// Only the local panel changes: a click runs the same ability(record, unit) UI command as stock,
// and the hotkey route doAbilityInSelected already reaches abilities past the 6th.
//
// log: the call at 0x696C70, on the path GetNth's "true" takes, goes through
// hooks/abilityslot_hooks.asm, which logs every button at n >= 6 once per unit and record.
#include <cstdint>
#include <cstring>
#include <set>
#include <string>
#include <utility>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr int kStockSlots = 6;  // 1 entry at 0x4C5ACA + 5 copies
constexpr int kMaxSlots = 36;   // the 6x6 button grid at [commandpanel2+1B4h]

// (unit ID, record index) pairs already logged; the panel refreshes many times a second.
// Read and written only from the game thread, by the hook. Unit IDs start again in every game: a
// new world, or a step count [world+F8h] that went back, clears it.
std::set<std::pair<std::int32_t, std::int32_t>> g_logged;
const char* g_logWorld = nullptr;
std::uint32_t g_logStep = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

void ForgetOtherGames() {
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const std::uint32_t step = world == nullptr ? 0 : Field<std::uint32_t>(world, 0xF8);
  if (world != g_logWorld || step < g_logStep) {
    g_logged.clear();
  }
  g_logWorld = world;
  g_logStep = step;
}

const char* ProtoName(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

}  // namespace

extern "C" {
void UhcAbilityButtonHook();

// Called by the hook when GetNth returned true for n >= 6: the unit gets a button that stock
// never asks for. `enabled` is GetNth's out byte (0 for AlwaysDisabledInGrid). The panel's loop over the 36 cells
// (0x695202..0x695440) draws the recharge on any button, so one past the sixth gets it too.
void __stdcall UhcAbilitySlotsLogButton(const char* unit, std::int32_t n, std::int32_t record, std::int32_t power,
                                        std::int32_t enabled) {
  ForgetOtherGames();
  const std::int32_t id = unit == nullptr ? -1 : Field<std::int32_t>(unit, 0x10);
  if (!g_logged.insert({id, record}).second) {
    return;
  }
  uhc::Log(L"abilitySlots: unit %d (%hs) shows ability %d of its list (record %d, power %d, %ls), past the stock 6",
           id, ProtoName(unit), n + 1, record, power, enabled != 0 ? L"enabled" : L"greyed");
}
}

namespace uhc {

Outcome ApplyAbilitySlots(const Config& config) {
  const Config::Args* args = config.First("abilitySlots");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  const auto slots = config.Int("abilitySlots");
  if (!slots || *slots < kStockSlots || *slots > kMaxSlots) {
    Log(L"abilitySlots: expected an integer from %d to %d, then optionally log; feature not applied", kStockSlots,
        kMaxSlots);
    return Outcome::kFailed;
  }
  bool log = false;
  for (std::size_t i = 1; i < args->size(); ++i) {
    const std::string& arg = (*args)[i];
    if (_stricmp(arg.c_str(), "log") == 0 && !log) {
      log = true;
    } else {
      Log(L"abilitySlots: unexpected argument %hs (expected: <N> [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("abilitySlots", {&sites::kAbilitySlotCopies, &sites::kAbilityPage11Branch, &sites::kAbilityNthCall,
                                  &sites::kAbilityButtonCost})) {
    return Outcome::kFailed;
  }
  // mov edi,5 at 0x695BD2, the do-while's count: the imm32 starts one byte in. N-1 >= 5, so the
  // loop's sub edi,1 / je never starts from 0.
  if (!WriteDword(sites::kAbilitySlotCopies.va + 0x1D, static_cast<std::uint32_t>(*slots - 1))) {
    return Outcome::kFailed;
  }
  if (log && !WriteJmp(sites::kAbilityButtonCost.va, reinterpret_cast<const void*>(&UhcAbilityButtonHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"abilitySlots: the command panel asks for %d abilities per unit (stock %d)%ls", *slots, kStockSlots,
      log ? L", every button past the 6th logged once per unit" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/abilityslot_hooks.asm

```asm
; Hook for "abilitySlots <N> log". Entered through a jmp written over the stock code; leaves
; through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Abilities").
; abilitySlots itself is a one-dword patch (features/abilityslots.cpp) and needs no hook.
.686
.model flat, c
option casemap :none

include common.inc

UhcAbilitySlotsLogButton PROTO STDCALL unit:DWORD, n:DWORD, recordIndex:DWORD, power:DWORD, enabled:DWORD

.data
costTotal       dd 0045EE37h    ; float thiscall(list): total of the ResList GetNth filled, the ability's cost, in ST0
costNext        dd 00696C75h    ; fcomp dword ptr [0B84BE4h] (compares that result with 0.0)

.code

; Replaces 0x696C70 (call 45EE37h, ECX = [esp+58h]) in FUN_0046188E, the command panel refresh:
; the path taken when AbilityMgr::GetNth (call at 0x696C59) found the unit's n-th ability.
; The frame is the stock one. EDI = the unit; GetNth's out slots are [esp+0Ch] (enabled byte),
; [esp+2Ch] (record index) and [esp+78h] (power ID); [esp+34h] = n + 1 (0x696C1F). Logs the
; buttons at n >= 6, which stock never asks for, then makes the stock call: EAX, ECX, EDX and the
; flags are dead before a call, and the FPU stack is empty there, so the log runs before it.
UhcAbilityButtonHook PROC
    TRACE_ONCE "abilitySlots log (0x696C70)"
    cmp dword ptr [esp+34h], 7      ; n + 1 >= 7: past the stock 6
    jl stock
    pushad
    movzx eax, byte ptr [esp+20h+0Ch]
    push eax                        ; enabled
    push dword ptr [esp+24h+78h]    ; power ID
    push dword ptr [esp+28h+2Ch]    ; record index
    mov eax, dword ptr [esp+2Ch+34h]
    sub eax, 1
    push eax                        ; n
    push edi                        ; unit
    call UhcAbilitySlotsLogButton
    popad
stock:
    call costTotal                  ; stolen 0x696C70, ECX unchanged
    jmp costNext
UhcAbilityButtonHook ENDP

END
```

## wonderPanelSkipAuras

Contract: [wonderPanelSkipAuras](../porting-to-another-dll.md#wonderpanelskipauras).

Sites: `AbilityByIndex` `0x44E702` (29 B), `WonderPanelAbilityArgs` `0x69EE37` (38 B), `WonderPanelAbilityCall` `0x69EE5D` (45 B), `NthVisibleAbility` `0x6EE5CC` (20 B).

### src/features/wonderpanel.cpp

```cpp
// wonderPanelSkipAuras: the wonder power panel (the row of global power buttons, gadget
// uiwonderpowerpanel) shows a wonder's first available ability that is not a passive aura,
// instead of only its first ability.
//
// Stock: for each <Command page='11'>Abilities</Command> of an AbstractWonder the local player
// owns, the panel refresh (a cold chunk of FUN_004586B1) asks the ability manager [world+56Ch]
// for the unit's ability n = 0 only (push 0 / call 6EE5CCh at 0x69EE5B), and adds no button when
// that call fails (the ability's tech is not active, or its age differs) or when the record is
// AlwaysDisabledInGrid (0x69EE80), the flag abilities.xml puts on passive auras. A wonder that
// lists an aura first (Toshogu Shrine, Shogunate, ...) therefore never gets a panel button for a
// global power listed after it, although the command grid of the selected wonder shows both.
//
// The hook replaces that call: it asks for n = 0, 1, ... 7 and returns the first ability that
// exists, is available and is not AlwaysDisabledInGrid, with the outputs of that call. With stock
// data every wonder has a single ability, so the panel is unchanged. The button still runs
// ability(record, unit, true), the UI command a command grid button already sends, so only what
// the panel shows changes (UI only). The hook is in hooks/wonderpanel_hooks.asm.
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* ProtoName(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

// Ability records already logged with "log": the panel asks again on every refresh, so each
// record is logged once per game (a new world, or a step count [world+F8h] that went back,
// clears it). Used only by the hook, on the game thread.
std::vector<std::int32_t> g_loggedRecords;
const char* g_logWorld = nullptr;
std::uint32_t g_logStep = 0;

void ForgetOtherGames() {
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const std::uint32_t step = world == nullptr ? 0 : Field<std::uint32_t>(world, 0xF8);
  if (world != g_logWorld || step < g_logStep) {
    g_loggedRecords.clear();
  }
  g_logWorld = world;
  g_logStep = step;
}

}  // namespace

extern "C" {
std::int32_t g_uhcWonderPanelLog = 0;

void UhcWonderPanelAbilityHook();

// Called by the hook, with "log", when the panel shows an ability that stock would not (n > 0).
void __stdcall UhcWonderPanelLogAbility(const char* unit, std::int32_t n, std::int32_t record, std::int32_t power) {
  ForgetOtherGames();
  if (std::find(g_loggedRecords.begin(), g_loggedRecords.end(), record) != g_loggedRecords.end()) {
    return;
  }
  g_loggedRecords.push_back(record);
  uhc::Log(L"wonderPanelSkipAuras: unit %d (%hs) shows its ability n=%d in the wonder power panel "
           L"(record %d, power %d)",
           Field<std::int32_t>(unit, 0x10), ProtoName(unit), n, record, power);
}
}

namespace uhc {

Outcome ApplyWonderPanelSkipAuras(const Config& config) {
  const Config::Args* args = config.First("wonderPanelSkipAuras");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"wonderPanelSkipAuras: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("wonderPanelSkipAuras", {&sites::kWonderPanelAbilityArgs, &sites::kWonderPanelAbilityCall,
                                          &sites::kNthVisibleAbility, &sites::kAbilityByIndex})) {
    return Outcome::kFailed;
  }
  g_uhcWonderPanelLog = log ? 1 : 0;
  if (!WriteCall(sites::kWonderPanelAbilityCall.va, reinterpret_cast<const void*>(&UhcWonderPanelAbilityHook))) {
    return Outcome::kFailed;
  }
  Log(L"wonderPanelSkipAuras: the wonder power panel shows a wonder's first available ability that is not a "
      L"passive aura (AlwaysDisabledInGrid)%ls (UI only)",
      log ? L", each ability it shows past the first logged once" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/wonderpanel_hooks.asm

```asm
; Hook for wonderPanelSkipAuras. Entered through a call redirected from the stock code, so it
; leaves through ret 24h, like the function it stands in for, to the verified test al,al after
; the call (docs/engine-symbols.md, "Abilities and the wonder power panel").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcWonderPanelLog:SDWORD   ; nonzero with "wonderPanelSkipAuras log"

UhcWonderPanelLogAbility PROTO STDCALL unit:DWORD, n:DWORD, recIdx:DWORD, powerId:DWORD

.data
nthAbility      dd 006EE5CCh    ; bool thiscall(mgr, n, player, unit, cost*, icon*, rollover*,
                                ; usable*, recIdx*, powerId*), ret 24h: the unit's n-th visible ability
abilityByIndex  dd 0044E702h    ; record* thiscall(mgr, int index), ret 4; 0 when out of range

.code

; Called instead of 0x6EE5CC by the call at 0x69EE5D in the wonder power panel refresh, so it
; returns to 0x69EE62 (test al,al / je 69F31Bh). ECX = the ability manager ([world+56Ch], never 0
; here: 0x458744 skips the panel otherwise); the nine stack arguments are those of 0x6EE5CC, with
; n = 0 (push 0 at 0x69EE5B). Asks for n = 0..7 and returns true with the first ability that
; exists, is available (tech and age, checked by 0x6EE5CC) and is not AlwaysDisabledInGrid (byte
; +1Dh bit 0, a passive aura); the outputs are those of that call. With none it returns false.
; EBX and ESI are saved, EDI and EBP are kept by every callee; the stock code after the call
; reads neither EAX above AL, ECX, EDX nor the flags it was entered with.
UhcWonderPanelAbilityHook PROC
    TRACE_ONCE "wonderPanelSkipAuras (0x69EE5D)"
    push ebx
    push esi
    mov esi, ecx                    ; ability manager
    xor ebx, ebx                    ; n
scan:
    push dword ptr [esp+2Ch]        ; powerId*   (each push moves the next argument to +2Ch)
    push dword ptr [esp+2Ch]        ; recIdx*
    push dword ptr [esp+2Ch]        ; usable*
    push dword ptr [esp+2Ch]        ; rollover*
    push dword ptr [esp+2Ch]        ; icon*
    push dword ptr [esp+2Ch]        ; cost*
    push dword ptr [esp+2Ch]        ; unit
    push dword ptr [esp+2Ch]        ; player
    push ebx                        ; n
    mov ecx, esi
    call nthAbility
    test al, al
    je next                         ; no n-th ability, or its tech or age is not reached
    mov eax, dword ptr [esp+28h]    ; recIdx*
    push dword ptr [eax]
    mov ecx, esi
    call abilityByIndex             ; the record, as the stock code after the call reads it
    test eax, eax
    je next
    test byte ptr [eax+1Dh], 1      ; AlwaysDisabledInGrid: a passive aura, never a panel button
    je found
next:
    inc ebx
    cmp ebx, 8
    jb scan
    xor al, al
    jmp done
found:
    test ebx, ebx
    je shown                        ; n = 0: the ability stock shows
    cmp g_uhcWonderPanelLog, 0
    je shown
    mov eax, dword ptr [esp+2Ch]    ; powerId*
    push dword ptr [eax]
    mov eax, dword ptr [esp+2Ch]    ; recIdx* (one push deeper)
    push dword ptr [eax]
    push ebx                        ; n
    push dword ptr [esp+20h]        ; unit
    call UhcWonderPanelLogAbility
shown:
    mov al, 1
done:
    pop esi
    pop ebx
    ret 24h
UhcWonderPanelAbilityHook ENDP

END
```

## nativePreview

Contract: [nativePreview](../porting-to-another-dll.md#nativepreview).

Besides the core helpers, it needs: [`prototags.h`](helpers.md#proto-tags), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `IsA` `0x44D7FA` (105 B), `PlayerProtoEntry` `0x45311B` (8 B), `NpSocketPanelSkip` `0x454354` (4 B), `NpGate` `0x46193E` (15 B), `NpProto` `0x461BBD` (11 B), `NpCollectSkip` `0x461C3F` (4 B), `NpTechLayout` `0x4620B9` (12 B), `NpTechBuild` `0x462172` (3 B), `NpLayoutNext` `0x46268A` (4 B), `NpCollect` `0x4C58AD` (12 B), `NpCollectAppend` `0x4C59F5` (7 B), `NpTechPrereqAge` `0x4C5DDA` (8 B), `NpTechNoPrereq` `0x4C7330` (6 B), `ProtoByName` `0x5A2346` (32 B), `NpSocketPanel` `0x645FE7` (15 B), `NpSubCiv` `0x646124` (9 B), `NpSubCivSkip` `0x646163` (5 B), `SocketOccupant` `0xA01A20` (14 B).

### src/features/nativepreview.cpp

```cpp
// nativePreview [tagged] [log] [<BuildingProto>]: selecting an empty native socket shows the command
// panel its Trading Post would have there: the native's units and techs, as disabled buttons with
// their normal rollovers. A click on one does nothing.
//
// Stock, for a selected native socket: the bottom panel chooser (FUN_00454270 and its chunks)
// hides the command panel ([ui+78h]) and shows the native's settlement panel instead; and the
// command panel refresh FUN_0046188E, when it runs, leaves at once (0x46194D) unless the
// selection's player [sel+0Ch] is the local player. Its entries come from the selected unit's
// proto ([proto+0E8h], 6-byte records {word id, kind 0 Train / 1 Tech / 2 Command, page,
// column}); a socket proto has none. The Trading Post has one list for every native, and the
// panel shows what the player's alliances made available.
//
// The hooks (hooks/nativepreview_hooks.asm). In the chooser:
// - 0x645FE7, where a selected Socket would get the settlement panel, and 0x646124, where a
//   socket with a <SubCiv> hides the command panel: a socket that gets a preview goes on as any
//   other unit, so the chooser shows the command panel.
// In the command panel refresh:
// - 0x46193E, the gate: the refresh goes on as for the local player's own unit, and the preview is
//   on for this refresh;
// - 0x461BBD: the entries are the local player's copy of the building (TradingPost by default);
// - 0x4C58AD: of those, only the Train entries of units the native's age techs enable (Data effect
//   Enable) and the Tech entries they make obtainable (TechStatus) are collected; the stock
//   availability tests, which would drop all of them, are skipped;
// - 0x4620B9: a tech skips the "can research here" and status tests but keeps the stock
//   prerequisite test (0x4C7330, 0x4C5DDA): one waiting for another tech stays hidden, and one
//   waiting for an age gets its age mark, as on a real Trading Post;
// - 0x462317 (the shared button hook, panelbuttons.*): every button of the preview is disabled and gets
//   no command.
//
// A socket gets a preview when its proto carries NativeSocket (and, with "tagged", the tag
// <NativePreview/>), names a <SubCiv>, and no building of its socket type stands on it (0xA01A20,
// the occupant lookup of trPlayerControlsSocket). The native's sets come from the civ's age techs
// ([civ+50h]): their effects are read once per civ and database. Nothing here writes game state;
// the panel is the local player's own view, so nothing reaches the other machines.
#include <cstdint>
#include <cstring>
#include <map>
#include <set>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../panelbuttons.h"
#include "../patch.h"
#include "../prototags.h"
#include "../unittypes.h"

extern "C" {
std::int32_t g_uhcNpActive = 0;        // 1 while the current refresh builds a preview
const char* g_uhcNpEntries = nullptr;  // the building's entries, &[proto+0E8h]
void UhcNpSocketPanelHook();
void UhcNpSubCivHook();
void UhcNpGateHook();
void UhcNpProtoHook();
void UhcNpCollectHook();
void UhcNpTechLayoutHook();
}

namespace {

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

using IsAFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using PlayerProtoFn = char*(__thiscall*)(const char* player, std::int32_t protoId);
using ProtoByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using SocketOccupantFn = std::int32_t(__thiscall*)(const char* world, const float* position, const char* socketProto);
const auto kIsA = reinterpret_cast<IsAFn>(0x0044D7FA);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kProtoByName = reinterpret_cast<ProtoByNameFn>(0x005A2346);
const auto kSocketOccupant = reinterpret_cast<SocketOccupantFn>(0x00A01A20);

constexpr std::uint32_t kTechStatusVtable = 0x00B969B0;  // BEffect TechStatus (ctor 0x620B4D)
constexpr std::uint32_t kDataVtable = 0x00B9E5A8;        // BEffect Data (ctor 0x620BAC)
constexpr std::int32_t kSubtypeEnable = 0x10;            // registered at 0x524F2B
constexpr int kMaxDepth = 4;                              // "active" techs followed this deep

bool g_tagged = false;
bool g_log = false;
std::string g_buildingName = "TradingPost";
std::int32_t g_nativeSocketType = -1;  // set on each database load

std::set<std::int32_t> g_taggedProtos;  // protos with <NativePreview/>, by ID

struct NativeSets {
  std::set<std::int32_t> units;
  std::set<std::int32_t> techs;
};
std::map<std::int32_t, NativeSets> g_sets;  // by civ ID, for the database below
const char* g_setsDatabase = nullptr;
std::int32_t g_buildingId = -2;  // -2: not looked up for this database
const NativeSets* g_current = nullptr;

std::int32_t g_loggedSocket = -1;  // the socket last logged with "log"
const char* g_logWorld = nullptr;

void ForgetData(char*) {
  g_taggedProtos.clear();
  g_sets.clear();
  g_setsDatabase = nullptr;
  g_buildingId = -2;
  g_current = nullptr;
}

bool __cdecl ReadTag(void*, const char*, char* proto) {
  g_taggedProtos.insert(Field<std::int32_t>(proto, 0x04));
  return true;
}

void AddTechEffects(const char* database, std::int32_t techId, NativeSets& sets, int depth) {
  const char* tree = Field<const char*>(database, 0x5D9C);
  if (tree == nullptr || techId < 0 || techId >= Field<std::int32_t>(tree, 0x10)) {
    return;
  }
  const char* node = Field<const char*>(Field<const char*>(tree, 0x0C) + 0x24 * techId, 0);
  if (node == nullptr) {
    return;
  }
  const char* const* effects = Field<const char* const*>(node, 0x24);
  const std::int32_t count = Field<std::int32_t>(node, 0x28);
  for (std::int32_t i = 0; effects != nullptr && i < count; ++i) {
    const char* effect = effects[i];
    if (effect == nullptr) {
      continue;
    }
    const std::uint32_t vtable = Field<std::uint32_t>(effect, 0);
    if (vtable == kTechStatusVtable) {
      const std::int32_t target = Field<std::int32_t>(effect, 0x0C);
      const std::uint8_t status = Field<std::uint8_t>(effect, 0x10);  // 0 unobtainable, 1 obtainable, 2 active
      if (target >= 0 && (status == 1 || status == 2) && sets.techs.insert(target).second && status == 2 &&
          depth < kMaxDepth) {
        AddTechEffects(database, target, sets, depth + 1);
      }
    } else if (vtable == kDataVtable) {
      const std::int32_t target = Field<std::int32_t>(effect, 0x04);
      if (Field<std::int32_t>(effect, 0x0C) == kSubtypeEnable && Field<float>(effect, 0x18) > 0.0f && target >= 0) {
        sets.units.insert(target);
      }
    }
  }
}

const NativeSets& SetsOf(const char* database, std::int32_t civId) {
  if (database != g_setsDatabase) {
    g_sets.clear();
    g_setsDatabase = database;
    g_buildingId = -2;
  }
  auto found = g_sets.find(civId);
  if (found != g_sets.end()) {
    return found->second;
  }
  NativeSets& sets = g_sets[civId];
  const char* civ = Field<const char* const*>(database, 0x24)[civId];
  const char* ages = civ == nullptr ? nullptr : Field<const char*>(civ, 0x50);
  const std::int32_t ageCount = civ == nullptr ? 0 : Field<std::int32_t>(civ, 0x54);
  for (std::int32_t age = 0; ages != nullptr && age < ageCount; ++age) {
    AddTechEffects(database, Field<std::int32_t>(ages, 8 * age), sets, 0);
  }
  return sets;
}

const char* UnitById(const char* world, std::int32_t id) {
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

// Techs the layout would put in one of its four big-button slots instead of the grid (tech flags
// 27, 36, 37, 39, tested before 0x696652): that path skips the button hook, so they are left out of
// a preview. No native tech of the data tested has them.
bool BigButtonTech(const char* database, std::int32_t techId) {
  const char* tree = Field<const char*>(database, 0x5D9C);
  if (tree == nullptr || techId < 0 || techId >= Field<std::int32_t>(tree, 0x10)) {
    return true;
  }
  const char* record = Field<const char*>(tree, 0x0C) + 0x24 * techId;
  const std::uint8_t* bits = Field<const std::uint8_t*>(record, 0x04);
  const std::uint32_t bitCount = Field<std::uint32_t>(record, 0x08);
  for (const std::uint32_t bit : {27u, 36u, 37u, 39u}) {
    if (bits != nullptr && bit < bitCount && (bits[bit >> 3] & (1u << (bit & 7))) != 0) {
      return true;
    }
  }
  return false;
}

bool Shown(const std::uint8_t* entry, const NativeSets& sets, const char* database) {
  const std::int32_t id = *reinterpret_cast<const std::uint16_t*>(entry);
  const std::uint8_t kind = entry[2];
  const std::uint8_t page = entry[3];
  if (page == 0xFF || page == 0x0A) {
    return false;
  }
  if (kind == 0) {
    return sets.units.count(id) != 0;
  }
  if (kind == 1) {
    return sets.techs.count(id) != 0 && !BigButtonTech(database, id);
  }
  return false;
}

// The preview a selected unit gets: the building whose entries the panel shows, with the native's
// sets; a null building for a unit that keeps the stock panels.
struct Preview {
  const char* building = nullptr;  // the local player's copy
  const NativeSets* sets = nullptr;
  std::int32_t civId = -1;
};

Preview PreviewOf(const char* unit) {
  const Preview none;
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (world == nullptr || database == nullptr || proto == nullptr || g_nativeSocketType < 0 ||
      !kIsA(proto, g_nativeSocketType)) {
    return none;
  }
  if (g_tagged && g_taggedProtos.count(Field<std::int32_t>(proto, 0x04)) == 0) {
    return none;
  }
  const std::uint8_t civId = Field<std::uint8_t>(proto, 0x1D1);  // <SubCiv>, 0xFF for none
  if (civId == 0xFF || civId >= Field<std::int32_t>(database, 0x28)) {
    return none;
  }
  const std::int32_t local = Field<std::int32_t>(game, 0x3C0);
  if (local < 0 || local >= Field<std::int32_t>(world, 0x5C)) {
    return none;
  }
  const char* player = Field<const char* const*>(world, 0x58)[local];
  if (player == nullptr) {
    return none;
  }
  if (kSocketOccupant(world, reinterpret_cast<const float*>(unit + 0x14), proto) >= 0) {
    return none;  // a building stands on it: its own panel, as in stock
  }
  const NativeSets& sets = SetsOf(database, civId);
  if (g_buildingId == -2) {
    g_buildingId = kProtoByName(database, g_buildingName.c_str());
    if (g_buildingId < 0) {
      uhc::Log(L"nativePreview: no proto %hs in this data; no preview", g_buildingName.c_str());
    }
  }
  if (g_buildingId < 0) {
    return none;
  }
  const char* building = kPlayerProto(player, g_buildingId);
  if (building == nullptr || Field<std::int32_t>(building, 0xEC) <= 0) {
    return none;
  }
  Preview preview;
  preview.building = building;
  preview.sets = &sets;
  preview.civId = civId;
  return preview;
}

void LogPreview(const char* unit, const Preview& preview, const char* database, const char* world) {
  if (world != g_logWorld) {
    g_loggedSocket = -1;
    g_logWorld = world;
  }
  const std::int32_t socketId = Field<std::int32_t>(unit, 0x10);
  if (socketId == g_loggedSocket) {
    return;
  }
  g_loggedSocket = socketId;
  const char* entries = Field<const char*>(preview.building, 0xE8);
  const std::int32_t count = Field<std::int32_t>(preview.building, 0xEC);
  int units = 0;
  int techs = 0;
  for (std::int32_t i = 0; entries != nullptr && i < count; ++i) {
    const auto* entry = reinterpret_cast<const std::uint8_t*>(entries + 6 * i);
    if (Shown(entry, *preview.sets, database)) {
      ++(entry[2] == 0 ? units : techs);
    }
  }
  const char* civ = Field<const char* const*>(database, 0x24)[preview.civId];
  const char* civName = civ == nullptr ? nullptr : Field<const char*>(civ, 0x04);
  const char* socketName = Field<const char*>(Field<const char*>(unit, 0x5C), 0x10);
  uhc::Log(L"nativePreview: socket %d (%hs, %hs): %d unit(s) and %d tech(s) of %hs, read-only", socketId,
           socketName == nullptr ? "?" : socketName, civName == nullptr ? "?" : civName, units, techs,
           g_buildingName.c_str());
}

// In a preview every button is disabled (its age mark stays as the stock code set it) and has no command for a
// click or a shift-click.
void PreviewButton(const uhc::PanelButton& button) {
  if (g_uhcNpActive == 0) {
    return;
  }
  button.State() = 1;
  button.Click()[0] = 0;
  button.ShiftClick()[0] = 0;
}

}  // namespace

extern "C" {

// From the two chooser hooks: true for a unit that gets a preview, so the chooser treats it as any
// other unit and shows the command panel. The chooser runs hundreds of times a second while a socket
// is selected, so the answer is kept for one simulation step ([world+F8h]) of one unit.
bool __stdcall UhcNpChooserPreview(const char* unit) {
  static const char* cachedUnit = nullptr;
  static std::int32_t cachedId = -1;
  static std::uint32_t cachedStep = 0;
  static const char* cachedWorld = nullptr;
  static bool cached = false;
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (unit == nullptr || world == nullptr) {
    return false;
  }
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (unit != cachedUnit || id != cachedId || step != cachedStep || world != cachedWorld) {
    cached = PreviewOf(unit).building != nullptr;
    cachedUnit = unit;
    cachedId = id;
    cachedStep = step;
    cachedWorld = world;
  }
  return cached;
}

// From the gate hook, on every refresh that reaches it. Returns the player the refresh compares with
// the local one: the selection's, or the local player's for a socket that gets a preview.
std::int32_t __stdcall UhcNpGate(const char* selection) {
  g_uhcNpActive = 0;
  g_current = nullptr;
  const std::int32_t owner = Field<std::int32_t>(selection, 0x0C);
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  if (game == nullptr || Field<std::int32_t>(selection, 0x14) != 1 || owner == Field<std::int32_t>(game, 0x3C0)) {
    return owner;
  }
  const char* world = Field<const char*>(game, 0x13C);
  const char* unit = UnitById(world, Field<const std::int32_t*>(selection, 0x10)[0]);
  const Preview preview = PreviewOf(unit);
  if (preview.building == nullptr) {
    return owner;
  }
  g_uhcNpEntries = preview.building + 0xE8;
  g_current = preview.sets;
  g_uhcNpActive = 1;
  if (g_log) {
    LogPreview(unit, preview, Field<const char*>(game, 0x140), world);
  }
  return Field<std::int32_t>(game, 0x3C0);
}

// From the collection hook in a preview: true to show this entry of the building.
bool __stdcall UhcNpTakeEntry(const std::uint8_t* entry) {
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  return g_current != nullptr && database != nullptr && Shown(entry, *g_current, database);
}

}  // extern "C"

namespace uhc {

Outcome ApplyNativePreview(const Config& config) {
  const Config::Args* args = config.First("nativePreview");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool named = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "tagged") == 0) {
      g_tagged = true;
    } else if (!named) {
      g_buildingName = arg;
      named = true;
    } else {
      Log(L"nativePreview: unexpected argument %hs (expected: [tagged] [log] [BuildingProto]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("nativePreview",
                 {&sites::kNpSocketPanel, &sites::kNpSocketPanelSkip, &sites::kNpSubCiv, &sites::kNpSubCivSkip,
                  &sites::kNpGate, &sites::kNpProto, &sites::kNpCollect, &sites::kNpCollectAppend,
                  &sites::kNpCollectSkip, &sites::kNpTechLayout, &sites::kNpTechBuild, &sites::kNpLayoutNext,
                  &sites::kNpTechNoPrereq, &sites::kNpTechPrereqAge,
                  &sites::kSocketOccupant, &sites::kIsA, &sites::kPlayerProtoEntry, &sites::kProtoByName})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType("NativeSocket", &g_nativeSocketType) || !OnDatabaseLoad(&ForgetData) ||
      !AddProtoTagHandler("NativePreview", &ReadTag) || !AddPanelButtonFilter(&PreviewButton)) {
    return Outcome::kFailed;
  }
  struct Jump {
    const Site& site;
    void (*hook)();
    std::size_t size;
  };
  const Jump jumps[] = {
      {sites::kNpSocketPanel, &UhcNpSocketPanelHook, 12}, {sites::kNpSubCiv, &UhcNpSubCivHook, 7},
      {sites::kNpGate, &UhcNpGateHook, 9},                {sites::kNpProto, &UhcNpProtoHook, 9},
      {sites::kNpCollect, &UhcNpCollectHook, 6},          {sites::kNpTechLayout, &UhcNpTechLayoutHook, 7},
  };
  for (const Jump& jump : jumps) {
    if (!WriteJmp(jump.site.va, reinterpret_cast<const void*>(jump.hook), jump.size)) {
      return Outcome::kFailed;
    }
  }
  Log(L"nativePreview: an empty native socket%ls shows the panel of %hs for its native, read-only%ls",
      g_tagged ? L" with <NativePreview/>" : L"", g_buildingName.c_str(), g_log ? L", previews logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/nativepreview_hooks.asm

```asm
; Hooks for nativePreview, in the bottom panel chooser FUN_00454270 and in the command panel refresh
; FUN_0046188E. Each is entered through a jmp written over the stock code and leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Native socket preview"). Nothing
; here writes game state: the hooks only change which panel shows, which entries the command panel
; collects and how it draws them.
.686
.model flat, c
option casemap :none

include common.inc

UhcNpChooserPreview PROTO STDCALL unit:DWORD
UhcNpGate PROTO STDCALL selection:DWORD
UhcNpTakeEntry PROTO STDCALL entry:DWORD

EXTERN g_uhcNpActive:DWORD      ; nativepreview.cpp: 1 while the refresh builds a socket's preview
EXTERN g_uhcNpEntries:DWORD     ; the building proto's command entries ([proto+0E8h])

.data
socketPanelNext dd 00645FF3h    ; mov eax,[esi+5Ch]: the trade route socket test, then the settlement panel
socketPanelSkip dd 00454354h    ; the end of the unit tests, as for a unit none of them claims
subCivNext      dd 0064612Bh    ; cmp al,0FFh after the <SubCiv> read
subCivSkip      dd 00646163h    ; the chooser's next test, as for a unit with no <SubCiv>
gateNext        dd 00461947h    ; cmp edx,[ecx+3C0h]: the selection's player against the local one
protoNext       dd 00461BC6h    ; push 1, after EBX = the proto's command entries
collectNext     dd 004C58B3h    ; je 6959D1h: the Train branch of the collection
collectAppend   dd 004C59F5h    ; the collection's append of the entry (index, column, page)
collectSkip     dd 00461C3Fh    ; the collection loop's next entry
techNext        dd 004620C0h    ; call 4C6968h: can this unit research the tech
techBuild       dd 00462172h    ; the tech button's build-up (rollover, icon, cost)
layoutNext      dd 0046268Ah    ; the layout's next entry

.code

; 0x645FE7: mov ecx,[0C66234h] / mov edx,[ecx+140h] (12 B), in the chooser's branch for a selected
; unit of type Socket (4Bh), which ends with the settlement panel in place of the command panel.
; ESI = the unit; EAX, ECX and EDX are dead at both continuations (each reloads what it reads), and
; the stack is the chooser's frame at both (0x4BC5D7 jumps to 0x454354 from the same level). A
; socket that gets a preview goes on at 0x454354 as a unit no test claims: [esp+12h] stays 1, so
; the chooser keeps the command grid ([grid+342h] = 0, set by 0x45447D) and its refresh runs.
UhcNpSocketPanelHook PROC
    TRACE_ONCE "nativePreview chooser socket (0x645FE7)"
    push esi
    call UhcNpChooserPreview        ; -> al = 1: preview
    test al, al
    jne preview
    mov ecx, dword ptr ds:[0C66234h]
    mov edx, dword ptr [ecx+140h]
    jmp socketPanelNext
preview:
    jmp socketPanelSkip
UhcNpSocketPanelHook ENDP

; 0x646124: mov ecx,ebx / call 4BC54Ah (7 B), the <SubCiv> read of the chooser's test that hides the
; command panel for a native socket. EBX = the unit. The stock call (it returns the byte
; [[unit+5Ch]+1D1h] in AL) is made here for any other unit; a socket that gets a preview goes on at
; 0x646163, as a unit without one. ECX and EDX are dead at both continuations.
UhcNpSubCivHook PROC
    TRACE_ONCE "nativePreview chooser sub-civ (0x646124)"
    push ebx
    call UhcNpChooserPreview        ; -> al = 1: preview
    test al, al
    jne preview
    mov ecx, ebx
    mov eax, 004BC54Ah
    call eax
    jmp subCivNext
preview:
    jmp subCivSkip
UhcNpSubCivHook ENDP

; 0x46193E: mov edx,[eax+0Ch] / mov ecx,[0C66234h] (9 B). EAX = the selection (count >= 1 checked
; above), EBX = the panel, ESI = 0; the stock compares EDX with the local player at 0x461947 and
; leaves the refresh when they differ. The helper returns the selection's player, or the local
; player when the selection is a native socket that gets a preview. EAX, EBX, ESI, EDI and EBP are
; kept; ECX is reloaded as in stock.
UhcNpGateHook PROC
    TRACE_ONCE "nativePreview gate (0x46193E)"
    push eax
    push eax
    call UhcNpGate                  ; -> eax = the player to compare with the local one
    mov edx, eax
    pop eax
    mov ecx, dword ptr ds:[0C66234h]
    jmp gateNext
UhcNpGateHook ENDP

; 0x461BBD: mov ebx,[esi+5Ch] / add ebx,0E8h (9 B). ESI = the selected unit. In a preview EBX gets
; the building's command entries instead of the socket proto's (which has none). No flag is read
; before the next write.
UhcNpProtoHook PROC
    TRACE_ONCE "nativePreview entries (0x461BBD)"
    cmp g_uhcNpActive, 0
    jne preview
    mov ebx, dword ptr [esi+5Ch]
    add ebx, 0E8h
    jmp protoNext
preview:
    mov ebx, g_uhcNpEntries
    jmp protoNext
UhcNpProtoHook ENDP

; 0x4C58AD: mov cl,[esi+eax+2] / test cl,cl (6 B), the kind test of the collection loop. EAX = the
; entries, ESI = 6 * index, EBX = &entries. In a preview the helper decides: an entry of the
; native goes straight to the append (the stock availability tests and the unit's action check
; would drop it), any other entry to the next one. ECX and EDX are dead at both targets.
UhcNpCollectHook PROC
    TRACE_ONCE "nativePreview collection (0x4C58AD)"
    cmp g_uhcNpActive, 0
    jne preview
    mov cl, byte ptr [esi+eax+2]
    test cl, cl
    jmp collectNext
preview:
    push eax
    lea ecx, [eax+esi]
    push ecx
    call UhcNpTakeEntry             ; -> al = 1: show it
    test al, al
    pop eax
    jne take
    jmp collectSkip
take:
    jmp collectAppend
UhcNpCollectHook ENDP

; 0x4620B9: mov edi,[esp+28h] / push edi / mov ecx,esi (7 B), before the call of 0x4C6968 in the
; tech branch of the layout. ESI = the player's tech entry, [esp+20h] = the player. In a preview the
; tech skips the "can research here" test and the status tests (the socket has no actions and the
; tech is not obtainable for the player), but keeps the stock prerequisite test of 0x462115..
; 0x462136: 0x4C7330, then 0x4C5DDA, whose -1 (a tech prerequisite not met) hides the tech and
; whose age index goes to [esp+6Ch] for the age mark. It then goes to the stock build-up as a
; disabled button ([esp+24h] = 1), with EBX = the player as at 0x4C6918. Both calls are thiscall
; on the tech entry and keep EBX, ESI, EDI and EBP.
UhcNpTechLayoutHook PROC
    TRACE_ONCE "nativePreview tech button (0x4620B9)"
    mov edi, dword ptr [esp+28h]
    cmp g_uhcNpActive, 0
    jne preview
    push edi
    mov ecx, esi
    jmp techNext
preview:
    mov ebx, dword ptr [esp+20h]
    push edi
    mov ecx, esi
    mov eax, 004C7330h
    call eax                        ; al = 1: no prerequisite to show
    test al, al
    jne build
    push edi
    push ebx
    mov ecx, esi
    mov eax, 004C5DDAh
    call eax                        ; eax = -1: hidden; else the age it waits for
    test eax, eax
    jl hidden
    mov dword ptr [esp+6Ch], eax
build:
    mov dword ptr [esp+24h], 1
    jmp techBuild
hidden:
    jmp layoutNext
UhcNpTechLayoutHook ENDP


END
```

## noCorpseDopples

Contract: [noCorpseDopples](../porting-to-another-dll.md#nocorpsedopples).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `NoCorpseDoppleAliveCall` `0x4868FA` (21 B), `NoCorpseDoppleSkip` `0x486A30` (23 B), `DoppleUpdateCall` `0x49198B` (5 B), `NoCorpseDoppleCreate` `0x49534D` (36 B), `DoppleInitProto` `0x4E4701` (6 B), `NoCorpseDoppleGaiaCheck` `0x4F1088` (17 B).

### src/features/dopples.cpp

```cpp
// noCorpseDopples [UnitType] [expire=<seconds>] [log]: a dead unit of the marker type leaves no dopple.
//
// A dopple is the copy of a unit that a player keeps seeing under the fog of war after the unit
// left his view. The per-unit visibility update FUN_0048679A creates one when a unit leaves a
// player's view (0x49520B) and its proto is Doppled, the unit is in the world (state bit 8) and
// state bit 1Dh is clear; a DoppleOnlyWhenDead proto only while gaia owns it. The creation call
// 0x4DB3D0 makes the dopple for that player and for the players who share his vision. Nothing
// asks whether the unit is alive: a hunt's carcass that still holds food gets a dopple in its
// death pose, and the dopple stays until the player sees the spot again, long after the carcass
// was eaten (by other players' hunters, or allies') or abandoned. A depleted carcass is never
// doppled, because the game takes it out of the world (bit 8) before it decays. Stock hunts use
// VisibleUnderFogOnlyAfterSeen instead and are never doppled; a mod that makes its hunts Doppled
// keeps a live herd stays where it was last seen.
//
// The hook runs just before the creation call: a unit whose proto is of the marker type (default
// AbstractNoCorpseDopple; "Huntable" covers every hunt with no data change) and that is not alive
// (unit vtable slot A4h, the stock test) gets no dopple, for any player. It simply disappears
// into the fog. A live marked unit is still doppled. The hook is in hooks/dopple_hooks.asm.
//
// A dopple made while the unit lived stays when it dies out of sight. expire= ends every dopple of a marked
// proto that many seconds after it was made, live or dead, so its going says nothing about the unit. The
// world update's manager update 0x491961 asks 0x49192B of each dopple whether it ends (true: 0x5038E0 takes it
// out); the call at 0x49198B goes to a wrapper that also says true past that age. [dopple+0] is the game time
// it was made and [dopple+12Ch] its proto ID. Simulation time and data only, in the simulation update, so
// every machine ends the same dopples.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

// One line per skipped dopple; a long game with many hunts stops logging after this many.
constexpr unsigned kMaxLogLines = 1000;
unsigned g_logged = 0;

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr float kMaxExpireSeconds = 3600.0f;

using DoppleUpdateFn = bool(__thiscall*)(char* dopple, std::int32_t a, std::int32_t b, std::int32_t c);
using ProtoByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kDoppleUpdate = reinterpret_cast<DoppleUpdateFn>(0x0049192B);
const auto kProtoById = reinterpret_cast<ProtoByIdFn>(0x0045316E);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

std::uint32_t g_expireMs = 0;
// By proto ID: 0 not asked yet, 1 marked, 2 not. Cleared on each database load.
std::vector<std::uint8_t> g_marked;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// A unit's proto is at [unit+5Ch]; its name, for the log, at [proto+10h].
const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

}  // namespace

extern "C" {
extern std::int32_t g_uhcNoCorpseDoppleType;
extern std::int32_t g_uhcNoCorpseDoppleLog;
}

namespace {

void NewDatabase(char*) { g_marked.clear(); }

bool IsMarked(const char* database, std::int32_t protoId) {
  if (protoId < 0 || g_uhcNoCorpseDoppleType < 0) {
    return false;
  }
  if (static_cast<std::size_t>(protoId) >= g_marked.size()) {
    g_marked.resize(static_cast<std::size_t>(protoId) + 1, 0);
  }
  std::uint8_t& known = g_marked[protoId];
  if (known == 0) {
    const char* proto = kProtoById(database, protoId);
    known = proto != nullptr && kProtoIsType(proto, g_uhcNoCorpseDoppleType) ? 1 : 2;
  }
  return known == 1;
}

// In place of the call at 0x49198B. Runs the stock update, and ends a marked dopple past its age.
bool __fastcall DoppleUpdate(char* dopple, void*, std::int32_t a, std::int32_t b, std::int32_t c) {
  if (kDoppleUpdate(dopple, a, b, c)) {
    return true;
  }
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (world == nullptr || database == nullptr) {
    return false;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::uint32_t made = Field<std::uint32_t>(dopple, 0x00);
  if (static_cast<std::int32_t>(now - made) < static_cast<std::int32_t>(g_expireMs) ||
      !IsMarked(database, Field<std::int32_t>(dopple, 0x12C))) {
    return false;
  }
  if (g_uhcNoCorpseDoppleLog != 0 && g_logged < kMaxLogLines) {
    ++g_logged;
    uhc::Log(L"noCorpseDopples: the dopple of unit %d, made at %.1f s, ends at %.1f s (player %d)",
             Field<std::int32_t>(dopple, 0x0C), made / 1000.0, now / 1000.0, b);
  }
  return true;
}

}  // namespace

extern "C" {
std::int32_t g_uhcNoCorpseDoppleType = -1;  // marker unittype ID, set on each database load
std::int32_t g_uhcNoCorpseDoppleLog = 0;    // 1 with "noCorpseDopples ... log"

void UhcNoCorpseDoppleHook();

// Called by the hook for every dopple it skips (only with "log"). `player` lost sight of `unit`.
void __stdcall UhcNoCorpseDoppleLog(const char* unit, std::int32_t player) {
  if (g_logged >= kMaxLogLines) {
    return;
  }
  ++g_logged;
  uhc::Log(L"noCorpseDopples: unit %d (%hs, hp %.1f) left player %d's view dead; no dopple",
           Field<std::int32_t>(unit, 0x10), ProtoName(unit), static_cast<double>(Field<float>(unit, 0x64)), player);
  if (g_logged == kMaxLogLines) {
    uhc::Log(L"noCorpseDopples: %u dopples logged; the next ones are skipped without a log line", kMaxLogLines);
  }
}
}

namespace uhc {

Outcome ApplyNoCorpseDopples(const Config& config) {
  const Config::Args* args = config.First("noCorpseDopples");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }

  std::string typeName = "AbstractNoCorpseDopple";
  bool typeGiven = false;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (_strnicmp(arg.c_str(), "expire=", 7) == 0) {
      const float seconds = static_cast<float>(std::atof(arg.c_str() + 7));
      if (!(seconds > 0.0f) || seconds > kMaxExpireSeconds) {
        Log(L"noCorpseDopples: %hs: expected seconds above 0 and at most %.0f; feature not applied", arg.c_str(),
            static_cast<double>(kMaxExpireSeconds));
        return Outcome::kFailed;
      }
      g_expireMs = static_cast<std::uint32_t>(seconds * 1000.0f);
    } else if (!typeGiven) {
      typeName = arg;
      typeGiven = true;
    } else {
      Log(L"noCorpseDopples: unexpected argument %hs (expected: [UnitType] [expire=<seconds>] [log]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("noCorpseDopples", {&sites::kNoCorpseDoppleCreate, &sites::kNoCorpseDoppleGaiaCheck,
                                     &sites::kNoCorpseDoppleSkip, &sites::kNoCorpseDoppleAliveCall})) {
    return Outcome::kFailed;
  }
  if (g_expireMs != 0 && !VerifyAll("noCorpseDopples expire", {&sites::kDoppleUpdateCall, &sites::kDoppleInitProto})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(typeName.c_str(), &g_uhcNoCorpseDoppleType)) {
    return Outcome::kFailed;
  }
  g_uhcNoCorpseDoppleLog = log ? 1 : 0;
  // Replaces mov eax,[esp+2Ch] / mov ecx,[esp+54h] at 0x49534D; the hook re-executes them.
  if (!WriteJmp(sites::kNoCorpseDoppleCreate.va, reinterpret_cast<const void*>(&UhcNoCorpseDoppleHook), 8)) {
    return Outcome::kFailed;
  }
  if (g_expireMs != 0 && (!OnDatabaseLoad(&NewDatabase) ||
                          !WriteCall(sites::kDoppleUpdateCall.va, reinterpret_cast<const void*>(&DoppleUpdate)))) {
    return Outcome::kFailed;
  }
  Log(L"noCorpseDopples: dead units of unittype %hs leave no dopple in the fog of war%ls (multiplayer unverified)",
      typeName.c_str(), log ? L", every skipped dopple logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/dopple_hooks.asm

```asm
; Hook for noCorpseDopples. Entered through a jmp written over the stock code; leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Dopples").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcNoCorpseDoppleType:SDWORD   ; marker unittype ID, set on each database load; -1 before
EXTERNDEF g_uhcNoCorpseDoppleLog:SDWORD    ; 1 with "noCorpseDopples ... log"

UhcNoCorpseDoppleLog PROTO STDCALL unit:DWORD, player:DWORD

.data
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): proto IDs and abstract types
doppleCreate    dd 00495355h    ; mov edx,[esi+10h] / push eax / ... / call 4DB3D0h (create the dopples)
noDopple        dd 00486A30h    ; the stock exit when no dopple is made: on to the next player

.code

; Replaces 0x49534D..0x495354 (mov eax,[esp+2Ch] / mov ecx,[esp+54h]) in FUN_0048679A, the unit
; visibility update, where unit ESI has left the view of player EBX (EBP = 1 << EBX, EDI = that
; player) and has passed the stock dopple tests. The frame is the stock one: [esp+2Ch] is the new
; visibility mask and [esp+54h] the forced argument, both passed on to 0x4DB3D0. EAX, ECX, EDX
; and the flags are dead here and at 0x486A30. A unit whose proto is of the marker type and that
; is not alive skips the creation; any other unit, and gaia (for whom 0x4DB3D0 makes nothing),
; runs the stock code.
UhcNoCorpseDoppleHook PROC
    TRACE_ONCE "noCorpseDopples (0x49534D)"
    cmp g_uhcNoCorpseDoppleType, 0
    jl stock
    test ebx, ebx                   ; player 0 (gaia)
    je stock
    mov ecx, dword ptr [esi+5Ch]    ; proto
    test ecx, ecx
    je stock
    push g_uhcNoCorpseDoppleType
    call protoIsType
    test al, al
    je stock
    mov eax, dword ptr [esi]        ; unit vtable
    mov ecx, esi
    call dword ptr [eax+0A4h]       ; isAlive, called as the stock code does at 0x4868FA
    test al, al
    jne stock
    cmp g_uhcNoCorpseDoppleLog, 0
    je skip
    pushad
    push ebx
    push esi
    call UhcNoCorpseDoppleLog
    popad
skip:
    jmp noDopple
stock:
    mov eax, dword ptr [esp+2Ch]    ; stolen 0x49534D
    mov ecx, dword ptr [esp+54h]    ; stolen 0x495351
    jmp doppleCreate
UhcNoCorpseDoppleHook ENDP

END
```

## steadyHitpointBars

Contract: [steadyHitpointBars](../porting-to-another-dll.md#steadyhitpointbars).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `IsA` `0x44D7FA` (105 B), `BoneLocalPosition` `0x45F22D` (95 B), `SteadyBarBone` `0x45FAE2` (93 B), `SteadyBarFallback` `0x460633` (73 B).

### src/features/steadybars.cpp

```cpp
// steadyHitpointBars [UnitType ...] [log]: the floating HP bars stay still while the unit gallops,
// attacks or works, instead of following its animation.
//
// The unit visual update's bar chunk (0x45FAE2) asks 0x45F22D for the HITPOINTBAR tag of the unit's
// model, in model space, and takes it to the world with the unit's matrix (0x406BDB); the bar is
// queued there (0x45FB71). When the current animation has no such tag, the cold block 0x460633 puts
// the bar at the unit's position plus a height from data instead. The tag's position is not a pose
// of the model: each animation file carries its own sampled track of it (0x45F072 interpolates two
// keys at the visual's clock), so the bar follows the rider through a gallop, and it jumps to the
// other height whenever the unit switches to an animation without the tag. There is no rest position
// to read: an animation is chosen per state and variation, and its track is the only one the game
// keeps.
//
// So the key holds, per unit, what the tag did over the last 3 to 6 seconds of animations that have
// it: the highest height (where the bar is when the unit stands) and the middle of its sideways and
// forward range, and moves the bar toward that by at most 1.5 model units a second. While the
// animation has no tag, the bar stays at that held position instead of the fallback; a unit whose
// tag was never seen keeps the stock fallback. A building's or a static model's tag never moves, so
// its bar stays exactly where it was.
//
// Display only: the hook writes the model-space vector the stock code takes to the world, nothing
// else; the clock is the real one, which only this machine's drawing reads.
#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" void UhcSteadyBarHook();

namespace {

constexpr std::size_t kMaxTypes = 8;
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr DWORD kBucketMs = 3000;                  // the history is two buckets: 3 to 6 s of tag time
constexpr DWORD kStepMs = 100;                     // the most one call counts, for the clock and the rate
constexpr DWORD kForgetMs = 10000;                 // unseen longer: the unit's history is dropped
constexpr DWORD kPurgeMs = 5000;
constexpr float kRate = 1.5f;                      // model units per second

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// What the tag did in one bucket, in model space.
struct Range {
  float lo[3];
  float hi[3];
  void Reset(const float* v) {
    for (int i = 0; i < 3; ++i) {
      lo[i] = hi[i] = v[i];
    }
  }
  void Add(const float* v) {
    for (int i = 0; i < 3; ++i) {
      lo[i] = std::min(lo[i], v[i]);
      hi[i] = std::max(hi[i], v[i]);
    }
  }
};

struct Steady {
  std::int32_t id = -1;           // [unit+10h]: a reused pointer is another unit
  const char* proto = nullptr;    // [unit+5Ch] when `marked` was decided
  bool marked = false;
  bool held = false;              // the tag was seen: `out` is valid
  bool logged = false;
  DWORD seen = 0;                 // the last call, real time
  DWORD clock = 0;                // tag time: what the calls with the tag add up to, kStepMs at most each
  DWORD bucketStart = 0;          // on `clock`
  std::uint32_t calls = 0;
  std::uint32_t missing = 0;      // calls without the tag
  Range current{};
  Range previous{};
  float out[3] = {};              // what the bar uses
};

std::int32_t g_types[kMaxTypes] = {-1, -1, -1, -1, -1, -1, -1, -1};
std::size_t g_typeCount = 0;
bool g_log = false;
std::unordered_map<const char*, Steady> g_units;
const char* g_world = nullptr;
DWORD g_lastPurge = 0;
std::set<std::string> g_loggedProtos;

bool Marked(const char* proto) {
  if (g_typeCount == 0) {
    return true;
  }
  if (proto == nullptr) {
    return false;
  }
  for (std::size_t i = 0; i < g_typeCount; ++i) {
    if (g_types[i] >= 0 && kProtoIsType(proto, g_types[i])) {
      return true;
    }
  }
  return false;
}

void Purge(DWORD now) {
  if (now - g_lastPurge < kPurgeMs) {
    return;
  }
  g_lastPurge = now;
  for (auto it = g_units.begin(); it != g_units.end();) {
    it = now - it->second.seen > kForgetMs ? g_units.erase(it) : std::next(it);
  }
}

void LogOnce(const char* unit, const Steady& s) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  const std::string key = name == nullptr ? "?" : name;
  if (!g_loggedProtos.insert(key).second) {
    return;
  }
  uhc::Log(L"steadyHitpointBars: unit %d (%hs): the bar holds at height %.2f in model space; over 3 s the tag went "
           L"from %.2f to %.2f (sideways %.2f..%.2f, forward %.2f..%.2f), and %u of %u frames had no tag; logged once "
           L"per proto",
           s.id, key.c_str(), static_cast<double>(s.out[1]), static_cast<double>(s.previous.lo[1]),
           static_cast<double>(s.previous.hi[1]), static_cast<double>(s.previous.lo[0]),
           static_cast<double>(s.previous.hi[0]), static_cast<double>(s.previous.lo[2]),
           static_cast<double>(s.previous.hi[2]), s.missing, s.calls);
}

// The held position: the tag's highest height and the middle of its other two ranges, over both buckets.
void Target(const Steady& s, float* target) {
  for (int i = 0; i < 3; ++i) {
    const float lo = std::min(s.current.lo[i], s.previous.lo[i]);
    const float hi = std::max(s.current.hi[i], s.previous.hi[i]);
    target[i] = i == 1 ? hi : (lo + hi) * 0.5f;
  }
}

}  // namespace

// From the bar chunk (0x45FB24). `found`: the current animation has the HITPOINTBAR tag, and
// `local` holds it in model space. True: `local` holds the bar's position (the stock path takes it
// to the world); false: the stock fallback (no tag, and none seen yet for this unit).
extern "C" bool __stdcall UhcSteadyBarLocal(const char* unit, float* local, std::int32_t found) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world != g_world) {  // a new game: no unit of the last one is drawn again
    g_units.clear();
    g_world = world;
  }
  const DWORD now = GetTickCount();
  Purge(now);

  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const char* proto = Field<const char*>(unit, 0x5C);
  Steady& s = g_units[unit];
  if (s.id != id || s.proto != proto) {  // a new unit, or a transform in place: another model
    s = Steady{};
    s.id = id;
    s.proto = proto;
    s.marked = Marked(proto);
    s.seen = now;
  }
  if (!s.marked) {
    s.seen = now;
    return found != 0;
  }
  const DWORD step = std::min<DWORD>(now - s.seen, kStepMs);
  s.seen = now;
  ++s.calls;
  if (found == 0) {
    ++s.missing;
    if (!s.held) {
      return false;
    }
    std::copy(s.out, s.out + 3, local);
    return true;
  }
  if (!s.held) {
    s.held = true;
    s.clock = 0;
    s.bucketStart = 0;
    s.current.Reset(local);
    s.previous.Reset(local);
    std::copy(local, local + 3, s.out);
    return true;
  }

  s.clock += step;
  if (s.clock - s.bucketStart >= kBucketMs) {
    s.previous = s.current;
    s.current.Reset(local);
    s.bucketStart = s.clock;
    if (g_log && !s.logged) {
      s.logged = true;
      LogOnce(unit, s);
    }
  } else {
    s.current.Add(local);
  }

  float target[3];
  Target(s, target);
  const float most = kRate * static_cast<float>(step) / 1000.0f;
  for (int i = 0; i < 3; ++i) {
    const float d = target[i] - s.out[i];
    s.out[i] += d > most ? most : (d < -most ? -most : d);
  }
  std::copy(s.out, s.out + 3, local);
  return true;
}

namespace uhc {

Outcome ApplySteadyHitpointBars(const Config& config) {
  const Config::Args* args = config.First("steadyHitpointBars");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::vector<std::string> typeNames;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (typeNames.size() == kMaxTypes) {
      Log(L"steadyHitpointBars: more than %u unit types (expected: [UnitType ...] [log]); feature not applied",
          static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      typeNames.push_back(arg);
    }
  }
  if (!VerifyAll("steadyHitpointBars", {&sites::kSteadyBarBone, &sites::kSteadyBarFallback, &sites::kBoneLocalPosition,
                                           &sites::kIsA})) {
    return Outcome::kFailed;
  }
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    if (!RequestAbstractUnitType(typeNames[i].c_str(), &g_types[i])) {
      return Outcome::kFailed;
    }
  }
  g_typeCount = typeNames.size();
  g_units.reserve(1024);
  // test al,al / jz 460633h at 0x45FB24 (8 bytes), inside the verified range 0x45FAE2..0x45FB3F
  if (!WriteJmp(0x0045FB24, reinterpret_cast<const void*>(&UhcSteadyBarHook), 8)) {
    return Outcome::kFailed;
  }
  std::string types;
  for (const std::string& name : typeNames) {
    types += (types.empty() ? "" : ", ") + name;
  }
  Log(L"steadyHitpointBars: floating HP bars hold their position (%hs)%ls (display only)",
      types.empty() ? "every unit" : types.c_str(), g_log ? L", log" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/steadybar_hooks.asm

```asm
; Hook for steadyHitpointBars. Entered through a jmp written over the stock code and left through
; an explicit jmp to a verified continuation (docs/how-it-works.md, "steadyHitpointBars").
;
; The floating bar chunk of the unit visual update (0x45FAE2..0x45FB6C): 0x45F22D(tag, 0, &v, 0, 0)
; returns AL = 1 when the current animation has the HITPOINTBAR tag, and then wrote its position in
; model space to v at [esp+2Ch]. Stock then tests AL (test al,al / jz 460633h at 0x45FB24, 8 bytes):
; with the tag it goes on at 0x45FB2C, which takes v to the world (0x406BDB) with the unit's matrix
; [esp+74h]; without it the cold block 0x460633 places the bar at the unit's position plus a height
; from data. The hook asks UhcSteadyBarLocal(unit, &v, AL): 1 = v holds the unit's steady position
; (go on at 0x45FB2C), 0 = no steady position, the stock fallback (0x460633). ESI = the unit.
; EAX, ECX, EDX and the flags are written before they are read on both paths (0x45FB2C: lea ecx /
; push ecx / lea edx; 0x460633: mov eax,[esp+48h] / mov ecx,[eax] / mov edx,[eax+4]); the helper
; keeps EBX, ESI, EDI and EBP, and the x87 stack is empty here and after it.
.686
.model flat, c
option casemap :none

include common.inc

UhcSteadyBarLocal PROTO STDCALL unit:DWORD, modelPos:DWORD, found:DWORD

.data
steadyBarNext     dd 0045FB2Ch  ; lea ecx,[esp+18h] / push ecx / lea edx,[esp+30h] / push edx / call 406BDBh
steadyBarFallback dd 00460633h  ; the stock position without the tag: the unit's position + a height

.code

UhcSteadyBarHook PROC
    TRACE_ONCE "steadyHitpointBars bar position (0x45FB24)"
    movzx eax, al                   ; 1: the tag was found and v holds it
    lea ecx, [esp+2Ch]              ; v: the tag's position in model space
    push eax
    push ecx
    push esi                        ; the unit
    call UhcSteadyBarLocal
    test al, al
    jz noSteady
    jmp steadyBarNext
noSteady:
    jmp steadyBarFallback
UhcSteadyBarHook ENDP

END
```

## inventoryBars

Contract: [inventoryBars](../porting-to-another-dll.md#inventorybars).

Besides the core helpers, it needs: [`floatingbars.h`](helpers.md#floating-bars), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `IsA` `0x44D7FA` (105 B), `IsATrue` `0x44F139` (5 B), `InventoryNoHpBar` `0x452EC5` (100 B), `VisualSize` `0x4605C1` (16 B), `SteadyBarFallback` `0x460633` (73 B).

### src/features/inventorybars.cpp

```cpp
// inventoryBars [UnitType] [always] [log]: while Alt is held, a unit with a resource inventory shows a second
// floating bar under its HP bar: what it still holds, as a share of what it was created with, in the colour of the
// resource it holds most of.
//
// Stock: holding Alt shows the HP bar of every unit whose proto has the HP bar flag (proto flag 5), with the profile
// option 57h on (FUN_00451F9D: the modifier query 0x473E37(2) into BL at 0x452EBD, read at 0x511D80). Each unit with
// resources has its own inventory at [[unit+B4h]+94h] (+4 a resource list), seeded at creation from its proto's
// resource object [proto+E0h] (+0 the InitialResource list): gathering takes from the inventory, and nothing on
// screen shows how much is left.
//
// The bar is queued right after the unit's HP bar, through the shared floating bar hooks (floatingbars.h), with the
// Alt state the bar chunk read, so it shows for the units whose HP bar shows then. Its kind (player ID 0x80494E00 |
// resource) moves its six vertices one bar height and a gap down the camera's up vector and gives them the resource's
// colour. Display only: reading the inventory changes nothing, and Alt is this machine's key. "always" shows the bars
// with every HP bar, Alt or not (for a test or a video).
#include <windows.h>

#include <bit>
#include <cstdint>
#include <cstdlib>
#include <set>
#include <string>

#include "../features.h"
#include "../floatingbars.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::uint32_t kKind = 0x80494E00;  // 'IN', negative: no player has it; the low byte is the resource
// A resource list is 8 bytes: +0 an array of [kResourceCount] floats, entry r XORed with the dword at
// kEntryKeys + 4r; +4 their total, XORed with [kTotalKey] (ResList total recompute 0x58EF02).
constexpr std::uint32_t kTotalKey = 0x00C6DF10;
constexpr std::uint32_t kEntryKeys = 0x00C6DF14;
constexpr std::uint32_t kResourceCount = 0x00C6DF38;
constexpr std::int32_t kMaxResources = 64;
constexpr float kEpsilon = 1e-6f;  // the engine's "holds this resource" threshold (0xBA1388)
constexpr unsigned kMaxLogLines = 40;

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

// ARGB per resource ID: 0 Gold, 1 Wood, 2 Food; any other (Fame, XP, a mod's own) the last one.
constexpr std::uint32_t kColours[] = {0xFFFFD23C, 0xFFB4783C, 0xFFE8503C};
std::uint32_t g_otherColour = 0xFF50B4FF;

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +3C0h the local player's ID

bool g_always = false;
bool g_trees = false;         // "trees": trees too, on the no-HP-bar path
std::int32_t g_treeType = -1;  // the built-in unittype Tree, set on each database load
bool g_log = false;
bool g_typeGiven = false;
std::int32_t g_type = -1;  // the UnitType's ID, set on each database load
std::string g_typeName;
std::set<std::int32_t> g_loggedProtos;
std::set<std::int32_t> g_sitesLogged;  // "log": protos whose bar position on the no-HP-bar path was logged
unsigned g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

std::uint32_t Global(std::uint32_t va) {
  return *reinterpret_cast<const std::uint32_t*>(static_cast<std::uintptr_t>(va));
}

// Entry r of a resource list, decoded as ResList get 0x44EFFF does; 0 if the list has no array.
float Amount(const char* list, std::int32_t r) {
  const auto* entries = Field<const std::uint32_t*>(list, 0);
  if (entries == nullptr) {
    return 0.0f;
  }
  return std::bit_cast<float>(entries[r] ^ Global(kEntryKeys + 4u * static_cast<std::uint32_t>(r)));
}

float Total(const char* list) { return std::bit_cast<float>(Field<std::uint32_t>(list, 4) ^ Global(kTotalKey)); }

// Queues the inventory bar of a unit with resources, at the position of its HP bar.
void QueueInventoryBar(const char* unit, const float* position, bool altHeld) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* block = Field<const char*>(unit, 0xB4);
  if (proto == nullptr || block == nullptr) {
    return;
  }
  const char* inventory = Field<const char*>(block, 0x94);
  const char* resources = Field<const char*>(proto, 0xE0);
  if (inventory == nullptr || resources == nullptr) {
    return;
  }
  if (g_typeGiven && (g_type < 0 || !kProtoIsType(proto, g_type))) {
    return;
  }
  const std::int32_t count = static_cast<std::int32_t>(Global(kResourceCount));
  if (count <= 0 || count > kMaxResources) {
    return;
  }
  const float initial = Total(resources);
  if (!(initial > kEpsilon)) {
    return;
  }
  const char* held = inventory + 4;
  // The colour: the resource it holds most of; an empty inventory, the one it was created with most of.
  std::int32_t main = -1;
  float most = kEpsilon;
  for (const char* list : {held, resources}) {
    for (std::int32_t r = 0; r < count; ++r) {
      const float amount = Amount(list, r);
      if (amount > most) {
        most = amount;
        main = r;
      }
    }
    if (main >= 0) {
      break;
    }
  }
  if (main < 0) {
    return;
  }
  float fill = Total(held) / initial;
  fill = fill < 0.0f ? 0.0f : (fill > 1.0f ? 1.0f : fill);
  uhc::QueueFloatingBar(position, fill, kKind | static_cast<std::uint32_t>(main & 0xFF));
  if (g_log && g_logLines < kMaxLogLines && g_loggedProtos.insert(Field<std::int32_t>(proto, 0x04)).second) {
    ++g_logLines;
    const char* name = Field<const char*>(proto, 0x10);
    uhc::Log(L"inventoryBars: unit %d (%hs) holds %.1f of %.1f (resource %d most): bar %.0f %% at (%.1f, %.1f, %.1f)"
             L"%ls; logged once per proto",
             Field<std::int32_t>(unit, 0x10), name == nullptr ? "?" : name, static_cast<double>(Total(held)),
             static_cast<double>(initial), main, static_cast<double>(fill * 100.0f), static_cast<double>(position[0]),
             static_cast<double>(position[1]), static_cast<double>(position[2]), altHeld ? L", Alt held" : L"");
  }
}

// After a unit's HP bar was queued (floatingbars.h).
void BarQueued(const char* unit, const float* position, bool constructing, bool altHeld) {
  if (!constructing && (altHeld || g_always)) {
    QueueInventoryBar(unit, position, altHeld);
  }
}

// The six vertices of an inventory bar: one bar height and a gap below the HP bar, in the resource's colour.
void BarVertices(const uhc::FloatingBarRecord& record, uhc::FloatingBarVertex* vertices, const char* camera) {
  const std::uint32_t resource = static_cast<std::uint32_t>(record.player) & 0xFFu;
  const std::uint32_t colour = resource < sizeof(kColours) / sizeof(kColours[0]) ? kColours[resource] : g_otherColour;
  // The quad's half height is scale / 16 along the camera's up vector A (0x45C4AF): the bar is scale / 8 high.
  const float drop = record.scale * 0.17f;
  const float* up = reinterpret_cast<const float*>(camera + 0x1C);
  for (int k = 0; k < 6; ++k) {
    for (int axis = 0; axis < 3; ++axis) {
      vertices[k].position[axis] -= drop * up[axis];
    }
    vertices[k].colour = colour;
  }
}

void ResetForDataLoad(char*) {
  g_loggedProtos.clear();
  g_sitesLogged.clear();
  g_logLines = 0;
}

// FUN_004605C1, thiscall(unit, vec3* out): the size of the unit's visual (its bounding box), into out.
using VisualSizeFn = const float*(__thiscall*)(const char* unit, float* out);
const auto kVisualSize = reinterpret_cast<VisualSizeFn>(0x004605C1);

}  // namespace

extern "C" {

void UhcInventoryNoHpBarHook();  // hooks/inventorybars_hooks.asm
void UhcInventoryCorpseHook();
std::int32_t g_uhcInventorySites = 1;   // 0 with "noSites"
std::int32_t g_uhcInventoryAlways = 0;  // 1 with "always"

// From the hook at 0x452F1B, for a unit with no HP bar (a mine, a tree, a bush) while Alt is held, or always: its
// bar goes where the bar chunk's fallback (0x460633) would put an HP bar, the unit's position raised by its visual's
// height plus [[unit+B4h]+24h], times its scale [unit+A8h], plus 1.
void __stdcall UhcInventoryNoHpBar(const char* unit, const float* position, std::int32_t altHeld) {
  if (unit == nullptr || position == nullptr || Field<const char*>(unit, 0xB4) == nullptr) {
    return;
  }
  // Only what the local player ([game+3C0h]) sees now: the visual update also runs for units drawn under the black
  // map and the fog, whose HP bar stock never shows. [[unit+B4h]+ACh] is the mask of the players that see the unit
  // (0x486A60).
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const std::int32_t local = game == nullptr ? -1 : Field<std::int32_t>(game, 0x3C0);
  if (local < 0 || local >= 32 || (Field<std::uint32_t>(Field<const char*>(unit, 0xB4), 0xAC) & (1u << local)) == 0) {
    return;
  }
  // Most of these units (projectiles, revealers, corpses of soldiers) have no resources: nothing else is read for them.
  const char* proto = Field<const char*>(unit, 0x5C);
  if (proto == nullptr || Field<const char*>(proto, 0xE0) == nullptr ||
      Field<const char*>(Field<const char*>(unit, 0xB4), 0x94) == nullptr) {
    return;
  }
  if (!g_trees && g_treeType >= 0 && kProtoIsType(proto, g_treeType)) {
    return;
  }
  float size[3] = {0.0f, 0.0f, 0.0f};
  const float* box = kVisualSize(unit, size);
  const float height = box == nullptr ? 0.0f : box[1];
  // The fallback's base [[esp+48h]] keeps the height 0 for such a unit (seen in game: a mine at y 0.0 on ground at
  // about 1.3); its own position [unit+14h] has the ground's height.
  const float* ground = reinterpret_cast<const float*>(unit + 0x14);
  float bar[3] = {position[0], ground[1] > position[1] ? ground[1] : position[1], position[2]};
  // 1 m higher than the fallback's + 1: a low model (a mine's rocks, a corpse) would hide a bar on its top.
  bar[1] += (height + Field<float>(Field<const char*>(unit, 0xB4), 0x24)) * Field<float>(unit, 0xA8) + 2.0f;
  if (g_log && g_logLines < kMaxLogLines && g_sitesLogged.insert(Field<std::int32_t>(proto, 0x04)).second) {
    ++g_logLines;
    uhc::Log(L"inventoryBars: unit %d with no HP bar at (%.1f, %.1f, %.1f): bar at height %.2f (visual %.2f, offset "
             L"%.2f, scale %.2f)",
             Field<std::int32_t>(unit, 0x10), static_cast<double>(position[0]), static_cast<double>(position[1]),
             static_cast<double>(position[2]), static_cast<double>(bar[1]), static_cast<double>(height),
             static_cast<double>(Field<float>(Field<const char*>(unit, 0xB4), 0x24)),
             static_cast<double>(Field<float>(unit, 0xA8)));
  }
  QueueInventoryBar(unit, bar, altHeld != 0);
}

}  // extern "C"

namespace uhc {

Outcome ApplyInventoryBars(const Config& config) {
  const Config::Args* args = config.First("inventoryBars");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "always") == 0) {
      g_always = true;
      g_uhcInventoryAlways = 1;
    } else if (_stricmp(arg.c_str(), "noSites") == 0) {
      g_uhcInventorySites = 0;
    } else if (_stricmp(arg.c_str(), "trees") == 0) {
      g_trees = true;
    } else if (_strnicmp(arg.c_str(), "other=", 6) == 0) {
      char* end = nullptr;
      const unsigned long rgb = std::strtoul(arg.c_str() + 6, &end, 16);
      if (arg.size() != 12 || end != arg.c_str() + 12) {
        Log(L"inventoryBars: %hs: expected other=RRGGBB (hex); feature not applied", arg.c_str());
        return Outcome::kFailed;
      }
      g_otherColour = 0xFF000000u | static_cast<std::uint32_t>(rgb);
    } else if (!g_typeGiven) {
      g_typeGiven = true;
      g_typeName = arg;
    } else {
      Log(L"inventoryBars: unexpected argument %hs (expected: [UnitType] [always] [noSites] [trees] [other=RRGGBB] [log]); "
          L"feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("inventoryBars", {&sites::kIsA, &sites::kIsATrue, &sites::kInventoryNoHpBar,
                                   &sites::kSteadyBarFallback, &sites::kVisualSize}) ||
      !OnDatabaseLoad(&ResetForDataLoad) || (g_typeGiven && !RequestAbstractUnitType(g_typeName.c_str(), &g_type)) ||
      !RequestAbstractUnitType("Tree", &g_treeType) ||
      !AddFloatingBarQueued(&BarQueued, "inventoryBars") || !AddFloatingBarKind(kKind, &BarVertices, "inventoryBars")) {
    return Outcome::kFailed;
  }
  // test al,al / jne 45F78Bh (8 B) at 0x452F1B: the HP bar flag test of the unit visual update; test al,al / je
  // 452F23h / push 5 / mov ecx,esi (8 B) at 0x452ED4: its test of a live unit, which a corpse fails.
  if (g_uhcInventorySites != 0 &&
      (!WriteJmp(0x00452F1B, reinterpret_cast<const void*>(&UhcInventoryNoHpBarHook), 8) ||
       !WriteJmp(0x00452ED4, reinterpret_cast<const void*>(&UhcInventoryCorpseHook), 8))) {
    return Outcome::kFailed;
  }
  Log(L"inventoryBars: units%hs%hs with resources show what they hold under their HP bar %ls%ls (display only)",
      g_typeGiven ? " of unittype " : "", g_typeGiven ? g_typeName.c_str() : "",
      g_always ? L"whenever it shows (always)" : L"while Alt is held",
      g_uhcInventorySites == 0 ? L""
      : g_trees                ? L"; units with no HP bar (mines, bushes, trees) too"
                               : L"; units with no HP bar but trees (mines, bushes) too");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/inventorybars_hooks.asm

```asm
; The hook of inventoryBars for units with no HP bar (features/inventorybars.cpp), entered through a jmp written over
; the stock code and left through an explicit jmp to one of its two stock targets (docs/how-it-works.md,
; "inventoryBars").
.686
.model flat, c
option casemap :none

include common.inc

UhcInventoryNoHpBar PROTO STDCALL :DWORD, :DWORD, :DWORD

EXTERNDEF g_uhcInventorySites:DWORD     ; 1 with the bars on units with no HP bar
EXTERNDEF g_uhcInventoryAlways:DWORD    ; 1 with "always"

.data
hpBarChecks     dd 0045F78Bh    ; cmp byte [esp+16h],0: the unit has the HP bar flag; the bar's conditions
noHpBar         dd 00452F23h    ; mov eax,[esi+0B4h]: no HP bar for this unit
flagTest        dd 00452EDCh    ; sub esp,4: the inlined test of proto flag 5

.code

; Replaces test al,al / jne 45F78Bh (8 bytes) at 0x452F1B in FUN_00451F9D, the unit visual update: AL = proto flag 5
; (the HP bar flag) of unit ESI, BL = the Alt state (0x452EBD). A unit with the flag goes on to the stock bar
; conditions. A unit without it (a mine, a tree, a bush) while Alt is held, or always with "always", is given to
; UhcInventoryNoHpBar with [esp+48h], the pointer to its position that the bar chunk's fallback (0x460633) reads in
; this same frame. Both targets write EAX, ECX, EDX and the flags before they read them (0x45F78B cmp, 0x452F23 mov /
; fld / fcomp).
UhcInventoryNoHpBarHook PROC
    TRACE_ONCE "inventoryBars no HP bar (0x452F1B)"
    test al, al
    jne hasFlag
    cmp g_uhcInventorySites, 0
    je done
    test bl, bl
    jne queue
    cmp g_uhcInventoryAlways, 0
    je done
queue:
    pushad
    movzx eax, bl
    push eax                        ; Alt held
    push dword ptr [esp+24h+48h]    ; the position pointer
    push esi                        ; unit
    call UhcInventoryNoHpBar
    popad
done:
    jmp noHpBar
hasFlag:
    jmp hpBarChecks
UhcInventoryNoHpBarHook ENDP

; Replaces test al,al / je 452F23h / push 5 / mov ecx,esi (8 bytes) at 0x452ED4, right after the unit's vtable +A4h
; test (0x452ECF; false for a corpse, which stock never gives an HP bar): AL = its result, BL = Alt, ESI = the unit.
; A unit that passes goes on with the re-executed push 5 / mov ecx,esi at 0x452EDC (the inlined test of proto flag 5,
; then the hook above). One that fails (a hunted animal's corpse that settlers gather) is given to
; UhcInventoryNoHpBar like a unit with no HP bar, then goes to the stock target 0x452F23.
UhcInventoryCorpseHook PROC
    TRACE_ONCE "inventoryBars corpse (0x452ED4)"
    test al, al
    je corpse
    push 5                          ; stolen 0x452ED8
    mov ecx, esi                    ; stolen 0x452EDA
    jmp flagTest
corpse:
    cmp g_uhcInventorySites, 0
    je skip
    test bl, bl
    jne queue
    cmp g_uhcInventoryAlways, 0
    je skip
queue:
    pushad
    movzx eax, bl
    push eax                        ; Alt held
    push dword ptr [esp+24h+48h]    ; the position pointer
    push esi                        ; unit
    call UhcInventoryNoHpBar
    popad
skip:
    jmp noHpBar
UhcInventoryCorpseHook ENDP

END
```

## multiplierDecimals

Contract: [multiplierDecimals](../porting-to-another-dll.md#multiplierdecimals).

Sites: `BStringFree` `0x4010CA` (31 B), `BStringSet` `0x40196F` (36 B), `BStringFromWide` `0x401A12` (40 B), `BStringLoadId` `0x447719` (19 B), `MultiplierTipStat` `0x4D7FB6` (10 B), `MultiplierTipMin` `0x699E95` (10 B), `MultiplierFormat` `0xBA2060` (22 B).

### src/features/multiplierdecimals.cpp

```cpp
// multiplierDecimals: the decimals of the bonus multipliers in the attack rows of both selection panels.
//
//   multiplierDecimals [N]   (N 0..3, default 2)
//
// A multiplier that is not whole is written with the wide format ", %.1fx %s" at 0xBA2060 (.rdata) by the stat panel
// fill (0x4D7F7D) and by the minimized block's attack rows (0x699E1F), so a DamageBonus of 1.25 shows as "1.3x" and
// 0.75 as "0.8x". The key writes N over the format's digit (0xBA2068): "1.25x" with N = 2. Whole multipliers keep
// their own format ", %dx %s" (0xC364A8): "2x".
// Each multiplier's rollover line is string 42229, "%1.1fX Bonus Damage against %2s (%3s)" in the English table,
// loaded at 0x4D7FBB (fill) and 0x699E9A (minimized block) through 0x447719; those two calls go to a loader that
// gives the string's "%1.1f" the same N, so the help text says "1.25X" as the row does. A table whose string has
// no "%1.1f" is left as it is.
// The other "%.1fx" of the exe (0xBF1AD0: "Bonus Damage: %s" in the special attacks' and abilities' rollovers,
// 0x69BC28 and 0x6EEC97) is not changed.
// Beside another DLL that already wrote the same digit, the key logs it and writes nothing there.
#include <cstdint>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

struct BString {
  wchar_t* text;
};

using BStringLoadIdFn = BString*(__thiscall*)(BString* self, std::int32_t id);
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringSetFn = void(__thiscall*)(BString* self, const BString* source);
using BStringFreeFn = void(__thiscall*)(BString* self);
const auto kBStringLoadId = reinterpret_cast<BStringLoadIdFn>(0x00447719);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringSet = reinterpret_cast<BStringSetFn>(0x0040196F);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);

constexpr std::uint32_t kDigitOffset = 8;  // the '1' of ", %.1fx %s" (UTF-16)
wchar_t g_digit = L'2';
bool g_tipLogged = false;

// The redirected calls are thiscall (ECX = the BString, the string ID on the stack, popped by the callee); __fastcall
// with an unused EDX has the same frame.
BString* __fastcall LoadMultiplierTip(BString* self, void* /*edx*/, std::int32_t id) {
  BString* result = kBStringLoadId(self, id);
  if (self == nullptr || self->text == nullptr) {
    return result;
  }
  std::wstring text = self->text;
  const size_t at = text.find(L"%1.1f");
  if (at == std::wstring::npos || text[at + 3] == g_digit) {
    return result;
  }
  text[at + 3] = g_digit;
  BString copy{nullptr};
  kBStringFromWide(&copy, text.c_str());
  kBStringSet(self, &copy);
  kBStringFree(&copy);
  if (!g_tipLogged) {
    g_tipLogged = true;
    uhc::Log(L"multiplierDecimals: rollover string %d written with %%1.%lcf", id, g_digit);
  }
  return result;
}

}  // namespace

namespace uhc {

Outcome ApplyMultiplierDecimals(const Config& config) {
  const Config::Args* args = config.First("multiplierDecimals");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  int decimals = 2;
  if (args->size() > 1 || (args->size() == 1 && ((*args)[0].size() != 1 || (*args)[0][0] < '0' ||
                                                  (*args)[0][0] > '3'))) {
    Log(L"multiplierDecimals: expected at most one argument, the decimals 0..3; feature not applied");
    return Outcome::kFailed;
  }
  if (args->size() == 1) {
    decimals = (*args)[0][0] - '0';
  }
  g_digit = static_cast<wchar_t>(L'0' + decimals);
  // The format: stock, or already this digit (another DLL wrote it); anything else is someone else's format.
  const Site& format = sites::kMultiplierFormat;
  const auto* live = reinterpret_cast<const std::uint8_t*>(static_cast<std::uintptr_t>(format.va));
  bool othersMatch = true;
  for (std::uint32_t i = 0; i < format.size; ++i) {
    if (i != kDigitOffset && live[i] != format.bytes[i]) {
      othersMatch = false;
    }
  }
  const wchar_t liveDigit = static_cast<wchar_t>(live[kDigitOffset] | (live[kDigitOffset + 1] << 8));
  bool wrote = false;
  if (othersMatch && liveDigit == g_digit) {
    Log(L"multiplierDecimals: the multiplier format at 0x%08X already has %d decimals; not written", format.va,
        decimals);
  } else if (Matches(format)) {
    const std::uint8_t digit[2] = {static_cast<std::uint8_t>(g_digit), 0};
    if (!WriteBytes(format.va + kDigitOffset, digit, sizeof(digit))) {
      return Outcome::kFailed;
    }
    wrote = true;
  } else {
    Log(L"multiplierDecimals: site %hs at 0x%08X does not hold the stock bytes (nor %d decimals); feature not "
        L"applied",
        format.name, format.va, decimals);
    return Outcome::kFailed;
  }
  // The rollover lines: only while both calls and the loader are stock; otherwise they keep their own text.
  const bool tips = Matches(sites::kMultiplierTipStat) && Matches(sites::kMultiplierTipMin) &&
                    Matches(sites::kBStringLoadId) && Matches(sites::kBStringFromWide) &&
                    Matches(sites::kBStringSet) && Matches(sites::kBStringFree);
  if (tips && (!WriteCall(sites::kMultiplierTipStat.va + 5, reinterpret_cast<const void*>(&LoadMultiplierTip)) ||
               !WriteCall(sites::kMultiplierTipMin.va + 5, reinterpret_cast<const void*>(&LoadMultiplierTip)))) {
    return Outcome::kFailed;
  }
  Log(L"multiplierDecimals: bonus multipliers with %d decimals (%ls)%ls", decimals,
      wrote ? L"format written" : L"format as another DLL left it",
      tips ? L", their rollover lines too" : L"; the rollover calls are not stock, their lines left as they are");
  return Outcome::kApplied;
}

}  // namespace uhc
```

## attackTypeIcons

Contract: [attackTypeIcons](../porting-to-another-dll.md#attacktypeicons).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `BStringFormat` `0x444EFB` (20 B), `TypeIconStatFound` `0x4D7F44` (9 B), `TypeIconMinChain` `0x699D31` (7 B), `TypeIconMinFound` `0x699DE6` (9 B), `TypeIconStatChain` `0x69B909` (7 B).

### src/features/attacktypeicons.cpp

```cpp
// attackTypeIcons: a bonus multiplier against an abstract type the panels have no icon for shows in the attack rows.
//
//   attackTypeIcons <UnitType> <StringID> <IconPath> [<UnitType> <StringID> <IconPath> ...]
//
// The attack rows list a DamageBonus only when its type is one of the stock chain's types with an icon (the stat
// panel fill 0x4D7E86.. and its cold part, the minimized block 0x699A95..); any other type is skipped, so an
// Escopetero's "1.5x against AbstractRangedCavalry" is not shown at all. With the key, a listed type gets its row
// part as the stock types do: ", 1.50x <icon>" with the icon at IconPath (a texture path, as ui\ingame\stat_icon_cavalry),
// and the rollover line "1.50X Bonus Damage against <StringID's text> (<icon>)".
// Hooks (hooks/attacktypeicons_hooks.asm) at the chain's test of type +11h, after every stock type but +11h and +54h:
// 0x69B909 (fill, icons "(16)") and 0x699D31 (minimized block, "(10)"). A listed type there writes the icon into the
// row's icon BString through the BString format 0x444EFB and joins the stock path with its string ID (0x4D7F44,
// 0x699DE6); any other type re-executes the test and goes on.
#include <cstdint>
#include <cstdlib>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
void UhcTypeIconStatHook();  // hooks/attacktypeicons_hooks.asm
void UhcTypeIconMinHook();
}

namespace {

struct BString {
  wchar_t* text;
};

using BStringFormatFn = void(__cdecl*)(BString* out, const wchar_t* format, ...);
const auto kBStringFormat = reinterpret_cast<BStringFormatFn>(0x00444EFB);

struct TypeIcon {
  std::string name;
  std::int32_t stringId = -1;
  std::wstring path;
  std::int32_t id = -1;  // the unittype ID, set on each database load (unittypes.h)
};

std::vector<TypeIcon>* g_icons = nullptr;  // never freed: read by the hooks until the process ends
bool g_logged = false;

}  // namespace

extern "C" {

// From the hooks: the icon of `type` into `out` at `size` and its string ID, or -1 for a type the key does not list.
std::int32_t __stdcall UhcAttackTypeIcon(std::int32_t type, BString* out, std::int32_t size) {
  if (g_icons == nullptr || out == nullptr) {
    return -1;
  }
  for (const TypeIcon& icon : *g_icons) {
    if (icon.id >= 0 && icon.id == type) {
      kBStringFormat(out, L"<icon=\"(%d)(%s)\">", size, icon.path.c_str());
      if (!g_logged) {
        g_logged = true;
        uhc::Log(L"attackTypeIcons: first multiplier against %hs shown", icon.name.c_str());
      }
      return icon.stringId;
    }
  }
  return -1;
}

}  // extern "C"

namespace uhc {

Outcome ApplyAttackTypeIcons(const Config& config) {
  const Config::Args* args = config.First("attackTypeIcons");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (args->empty() || args->size() % 3 != 0) {
    Log(L"attackTypeIcons: expected triples <UnitType> <StringID> <IconPath>, got %zu values; feature not applied",
        args->size());
    return Outcome::kFailed;
  }
  auto* icons = new std::vector<TypeIcon>();
  for (size_t i = 0; i + 2 < args->size(); i += 3) {
    char* end = nullptr;
    const long id = std::strtol((*args)[i + 1].c_str(), &end, 10);
    if (end == (*args)[i + 1].c_str() || *end != '\0' || id < 0) {
      Log(L"attackTypeIcons: %hs: string ID %hs is not a number; feature not applied", (*args)[i].c_str(),
          (*args)[i + 1].c_str());
      delete icons;
      return Outcome::kFailed;
    }
    const std::string& path = (*args)[i + 2];
    icons->push_back({(*args)[i], static_cast<std::int32_t>(id), std::wstring(path.begin(), path.end())});
  }
  if (!VerifyAll("attackTypeIcons", {&sites::kTypeIconStatChain, &sites::kTypeIconStatFound, &sites::kTypeIconMinChain,
                                     &sites::kTypeIconMinFound, &sites::kBStringFormat})) {
    delete icons;
    return Outcome::kFailed;
  }
  for (TypeIcon& icon : *icons) {
    if (!RequestAbstractUnitType(icon.name.c_str(), &icon.id)) {
      delete icons;
      return Outcome::kFailed;
    }
  }
  g_icons = icons;  // the vector does not move again: the IDs above are written into it on each database load
  if (!WriteJmp(sites::kTypeIconStatChain.va, reinterpret_cast<const void*>(&UhcTypeIconStatHook), 5) ||
      !WriteJmp(sites::kTypeIconMinChain.va, reinterpret_cast<const void*>(&UhcTypeIconMinHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"attackTypeIcons: %zu unit types get an icon in the attack rows' bonus multipliers", icons->size());
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/attacktypeicons_hooks.asm

```asm
; attackTypeIcons (features/attacktypeicons.cpp): the bonus multipliers' type chain of the two selection panels.
; Entered through a jmp written over lea edx,[eax+11h] / cmp esi,edx; leaves through an explicit jmp to the stock
; jne that follows (an unlisted type, the two instructions re-executed) or to the stock path of a type with an icon.
.686
.model flat, c
option casemap :none

include common.inc

UhcAttackTypeIcon PROTO STDCALL unitType:DWORD, iconText:DWORD, iconSize:DWORD

.data
typeIconId      dd -1           ; the listed type's string ID, or -1
statFound       dd 004D7F44h    ; lea ecx,[esp+40h] / call 447719h: the fill's path of a type with an icon
statNext        dd 0069B90Eh    ; jne 69B939h: the fill's next type test
minFound        dd 00699DE6h    ; lea ecx,[esp+44h] / call 447719h: the minimized block's path
minNext         dd 00699D36h    ; jne 699D65h: the minimized block's next type test

.code

; Replaces 0x69B909..0x69B90D in the stat panel fill's cold part. ESI = the bonus's unittype, EAX = the proto count
; [db+19B0h], ECX = the game; the row's icon BString is [esp+28h] (a stock branch pushes the texture, then formats
; into [esp+2Ch]). A listed type: the icon goes there, its string ID is pushed and the stock path joined, as the
; stock branches do (they leave EAX, ECX and EDX dead there). Otherwise every register is as it was and the test is
; re-executed.
UhcTypeIconStatHook PROC
    TRACE_ONCE "attackTypeIcons stat panel (0x69B909)"
    pushad
    push 16
    lea edx, [esp+4+20h+28h]            ; the icon BString, past pushad and the push above
    push edx
    push esi
    call UhcAttackTypeIcon
    mov typeIconId, eax
    popad
    cmp typeIconId, -1
    je statStock
    push typeIconId
    jmp statFound
statStock:
    lea edx, [eax+11h]
    cmp esi, edx
    jmp statNext
UhcTypeIconStatHook ENDP

; Replaces 0x699D31..0x699D35 in the minimized block's attack rows: the same registers; the icon BString is
; [esp+24h] (a stock branch pushes the texture, then formats into [esp+28h]).
UhcTypeIconMinHook PROC
    TRACE_ONCE "attackTypeIcons minimized panel (0x699D31)"
    pushad
    push 10
    lea edx, [esp+4+20h+24h]
    push edx
    push esi
    call UhcAttackTypeIcon
    mov typeIconId, eax
    popad
    cmp typeIconId, -1
    je minStock
    push typeIconId
    jmp minFound
minStock:
    lea edx, [eax+11h]
    cmp esi, edx
    jmp minNext
UhcTypeIconMinHook ENDP

END
```

## minUIStats

Contract: [minUIStats](../porting-to-another-dll.md#minuistats).

Besides the core helpers, it needs: [`datarefs.h`](helpers.md#data-refs), [`unitinfo.h`](helpers.md#unit-info-for-the-panels), [`unitpanel.h`](helpers.md#unit-panel-row-the-minimized-interface), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `BStringFree` `0x4010CA` (31 B), `BStringSet` `0x40196F` (36 B), `BStringFromWide` `0x401A12` (40 B), `GadgetLookupAny` `0x404296` (49 B), `GadgetRelease` `0x40431B` (44 B), `BStringAssign` `0x443BB8` (15 B), `GadgetShow` `0x447F7B` (70 B), `GadgetHide` `0x448F13` (57 B), `IsA` `0x44D7FA` (105 B), `ResListGet` `0x44EFFF` (61 B), `HoldsResource` `0x45EE8B` (20 B), `MaxHitpointsGetter` `0x480408` (38 B), `LosGetterHead` `0x48206D` (52 B), `RateLookupHead` `0x487C45` (16 B), `AttackListFill` `0x487EEE` (24 B), `RegenPlayerHead` `0x4905E1` (16 B), `RegenRateRead` `0x4907FF` (31 B), `UnitCarryCapacity` `0x494503` (16 B), `ActionRangeEntry` `0x4946D6` (55 B), `MaxContained` `0x49EB5A` (17 B), `GadgetRef` `0x4C519C` (27 B), `StackLayoutCall` `0x4C7DB3` (14 B), `MinBlockChoice` `0x4C8276` (11 B), `StackLayout` `0x4C8F49` (675 B), `StackFillReset` `0x4C9458` (42 B), `StackFillCurrent` `0x4C9587` (65 B), `StackFillAppend` `0x4C979A` (27 B), `StatFillHead` `0x4D70ED` (24 B), `StatFillMinGate` `0x4D721B` (76 B), `StatFillRowCap` `0x4D7944` (28 B), `AttackRowName` `0x4D7A2E` (116 B), `AttackRowDamage` `0x4D7AC8` (273 B), `AttackRowTypeIcon` `0x4D7BD9` (126 B), `AttackRowRange` `0x4D7D2A` (120 B), `AttackRowSiege` `0x4D8265` (79 B), `MainResource` `0x4DBEC1` (16 B), `HeldAmount` `0x4E5979` (20 B), `BStringFromId` `0x58EA52` (25 B), `PowerUnitActionStore` `0x5F22CA` (54 B), `ActionRawName` `0x5F8FC3` (24 B), `MinResistsUnitGate` `0x698BE2` (26 B), `MinResistsArmorTest` `0x698BFC` (26 B), `AttackRowCold` `0x69B617` (128 B), `AttackRowModifier` `0x69FDDC` (28 B), `AttackRowTyped` `0x69FE1F` (25 B), `AbilityAvailableTest` `0x6EE68C` (118 B), `CurrentUnitRef` `0x6F49B1` (65 B), `ResourceIconText` `0x706EFB` (16 B), `BuildPointsAdd` `0x7ADE95` (16 B), `BuildPointsAddCall` `0x9C4BE3` (30 B), `BuilderFactor` `0x9C4C0C` (26 B), `BuildTickRateHead` `0x9D3D6B` (16 B), `BuildTickScale` `0x9D3D80` (71 B), `BuildTickAdd` `0x9D3DE9` (12 B), `GadgetByName` `0xAB7C2F` (38 B), `PowerUnitActionVtable` `0xB855F4` (4 B).

### src/features/minuistats.cpp

```cpp
// minUIStats: the minimized in-game interface shows what the normal one shows, and more, in rows a data file lists.
//
//   minUIStats [file]      (default minuirows.xml in the build's data folder; without it, the rows below)
//
// The minimized selection panel (uiunitselectionmin.xml) gets top-level formatText gadgets the DLL fills:
// - <row gadget="..." item="speed" label="Speed: " types="Unit"/>: one catalog item (kItems) per gadget;
// - <bigPanelRows gadget="unitselectionpanel-uhcRow%d" first="3" skip="auto,speed"/>: the rows the normal
//   interface's stat panel shows (FUN_004D70ED), mirrored: the fill runs for these gadgets and its rows are kept
//   in order, less the ones the minimized panel already shows ("auto") and the kinds `skip` names.
//   With stockRows="take" the original attack rows (StackLabel0..2) are written from the same list, so that every
//   attack row gets rofIcon="..." (the action's ROF and that icon after its damage) and the ability attacks the unit
//   cannot use are left out (ActionEnabled; abilities="all" keeps them). With projectilesIcon="...", an attack that
//   fires more than one projectile before its reload gets shots x projectiles and that icon after its ROF: the
//   tags as the data writes them (<NumberOfShots>, <NumberProjectiles>: unitinfo.h, Shots), or with
//   projectiles="combat" as combat fires them (numberOfShots and its "projectiles" option). The multipliers lose the
//   zeros that end their decimals ("1.50x" is "1.5x"; multiplierZeros="keep" keeps them), and each attack row's help
//   text gets a line for its ROF and one for its projectiles (rofTip, projectilesTip) after the game's own lines,
//   whose parentheses around an icon or around the name after one go (tipParentheses="keep" keeps them).
// - "[string:ID]" in a text, label or tip: that string of the game's string table, as the player's language has it
//   (resolved when shown: "[string:68852]" is "Hitpoints" in the English table).
// - <replace row="..." stock="a,b"/>: while that row shows, those original gadgets are hidden (the hit points and
//   resists rows with icons over the original ones, which the layout keeps in place for the panel without the key);
//   <stockLabel gadget="..." text="..."/>: an original label's text, written over the game's while it shows.
// - join="line" on a text= row: each part on a line of its own (a two-line block); spill="<gadget>": when the row is
//   too wide for its gadget and the row of that gadget shows nothing, the words that do not fit go there.
// A row whose gadget the selection's stack portraits cover (one per unit type, placed by the panel each fill), or
// that a shown <avoid gadget="..."/> covers, is hidden for that fill (a bigPanelRows gadget is skipped and the rows
// go on in the next one); overlap="show" on a row or bigPanelRows keeps it.
// It also shows a building's armor in the stock resists gadgets (the minimized block's test of abstract type Unit
// goes), and adds a {uhc...} data ref per item for a layout's own texts (datarefs.h).
// The normal interface is unchanged: it has none of these gadgets, and every write is to a gadget found by name.
// docs/how-it-works.md, "minUIStats"; docs/unit-panel-catalog.md.
#include <windows.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cwchar>
#include <map>
#include <string>
#include <vector>

#include "../datarefs.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unitpanel.h"
#include "../unitinfo.h"
#include "../unittypes.h"
#include "../xmllist.h"

extern "C" {
// 1 while minUIStats runs the stat panel fill for the minimized panel's rows (hooks/minuistats_hooks.asm).
std::uint32_t g_uhcMinUiForceFill = 0;
void UhcStatFillMinGate();
void UhcMinBlockChoice();
}

namespace {

// ---- Engine layout (docs/engine-symbols.md, "Unit panels") ----

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // +13Ch world, +140h database, +920h the UI's view
constexpr std::uint32_t kUiGlobal = 0x00C67310;    // [[+920h]+13Ch]: the data refs' current unit ID
constexpr std::uint32_t kUiManager = 0x00C66244;   // [[+44h]]: the gadget manager (show / hide)
constexpr std::uint32_t kNoGadget = 0x00C672C0;    // [..]: the handle of "no gadget"; valid ones are above it
constexpr std::uint32_t kLabelStyle = 0x00D6F5D0;  // the stat rows' label style
constexpr std::uint32_t kAttackStyle = 0x00CF05A4; // the attack rows' label style (0x4D7A90)
constexpr std::uint32_t kStatRowLabels = 0x174;    // the stat panel's row handles, 9 labels then 9 values
constexpr std::uint32_t kStatRowValues = 0x198;
constexpr int kStatRows = 9;
constexpr std::uint32_t kGadgetTip = 0x68;         // a gadget's help text, a BString
constexpr float kWholeEpsilon = 1e-6f;             // the panels' "%d" test (0xBA20B4)
// The icon size of the minimized panel's own rows: its attack and resists rows use "(10)" (0xC36508, 0xC364C0), the
// big stat panel "(16)" (0xBA2100). Every icon the key writes there uses the minimized panel's size.
constexpr int kIconSize = 10;

struct BString {
  wchar_t* text;
};

using GadgetByNameFn = std::int32_t*(__thiscall*)(char* panel, std::int32_t* out, BString* name, std::int32_t flag);
using GadgetRefFn = std::int32_t*(__thiscall*)(std::int32_t* ref, std::int32_t handle);
using GadgetReleaseFn = std::int32_t(__cdecl*)(std::int32_t handle);
using GadgetShowFn = void(__thiscall*)(void* manager, std::int32_t handle);
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t id);
using BStringSetFn = void(__thiscall*)(BString* self, const BString* source);
using BStringAssignFn = void(__thiscall*)(BString* self, const BString* source, std::int32_t, std::int32_t);
using BStringFreeFn = void(__thiscall*)(BString* self);
using StatFillFn = void(__thiscall*)(char* panel, const char* selection);
using UnitFloatFn = float(__thiscall*)(const char* unit);
using ProtoIntFn = std::int32_t(__thiscall*)(const char* proto);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kGadgetByName = reinterpret_cast<GadgetByNameFn>(0x00AB7C2F);
const auto kGadgetRef = reinterpret_cast<GadgetRefFn>(0x004C519C);
const auto kGadgetRelease = reinterpret_cast<GadgetReleaseFn>(0x0040431B);
const auto kGadgetShow = reinterpret_cast<GadgetShowFn>(0x00447F7B);
const auto kGadgetHide = reinterpret_cast<GadgetShowFn>(0x00448F13);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringSet = reinterpret_cast<BStringSetFn>(0x0040196F);
const auto kBStringAssign = reinterpret_cast<BStringAssignFn>(0x00443BB8);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kStatFill = reinterpret_cast<StatFillFn>(0x004D70ED);
const auto kMaxHp = reinterpret_cast<UnitFloatFn>(0x00480408);
const auto kLos = reinterpret_cast<UnitFloatFn>(0x0048206D);
const auto kMaxContained = reinterpret_cast<ProtoIntFn>(0x0049EB5A);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

template <typename Fn>
Fn VirtualAt(const void* object, std::uint32_t offset) {
  return *reinterpret_cast<const Fn*>(*reinterpret_cast<const char* const*>(object) + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* UnitById(std::int32_t id) {
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr || id < 0) {
    return nullptr;
  }
  const std::int32_t index = id & 0x3FFFF;
  if (index >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[index];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

// The unit the data refs describe, as the stock providers find it (FUN_006F49B1).
const char* CurrentRefUnit() {
  const char* ui = *reinterpret_cast<const char* const*>(kUiGlobal);
  const char* view = ui == nullptr ? nullptr : Field<const char*>(ui, 0x920);
  return view == nullptr ? nullptr : UnitById(Field<std::int32_t>(view, 0x13C));
}

std::wstring Number(float value) {
  wchar_t text[32];
  const float whole = std::floor(value);
  if (value - whole <= kWholeEpsilon) {
    swprintf_s(text, L"%d", static_cast<int>(whole));
  } else {
    swprintf_s(text, L"%.2f", static_cast<double>(value));
  }
  return text;
}

std::wstring StringById(std::int32_t id) {
  BString text{nullptr};
  kBStringFromId(&text, id);
  std::wstring copy = text.text == nullptr ? L"" : text.text;
  kBStringFree(&text);
  return copy;
}

// ---- Catalog items: the value of one item for one unit, or false when it does not apply ----

// As the minimized block's hit points value: "%d/%d" (0x698B63), or overheal's text when that key runs (its max, its
// colour above 100 %).
bool ItemHitpoints(const char* unit, std::wstring* out) {
  if (uhc::unitinfo::HitpointsText(unit, out)) {
    return true;
  }
  wchar_t text[48];
  swprintf_s(text, L"%d/%d", static_cast<int>(Field<float>(unit, 0x64)), static_cast<int>(kMaxHp(unit)));
  *out = text;
  return true;
}

// The live maximum speed, with techs, snares and auras, as the stat panel's Speed row (the unit's vtable +34h).
bool ItemSpeed(const char* unit, std::wstring* out) {
  const float speed = VirtualAt<UnitFloatFn>(unit, 0x34)(unit);
  if (!(speed > 0.0f)) {
    return false;
  }
  *out = Number(speed);
  return true;
}

bool ItemBaseSpeed(const char* unit, std::wstring* out) {
  const float speed = Field<float>(Field<const char*>(unit, 0x5C), 0x80);
  if (!(speed > 0.0f)) {
    return false;
  }
  *out = Number(speed);
  return true;
}

bool ItemLos(const char* unit, std::wstring* out) {
  const float los = kLos(unit);
  if (!(los > 0.0f)) {
    return false;
  }
  *out = std::to_wstring(static_cast<int>(los));
  return true;
}

// Another DLL replaced the minimized block's armor read (0x698BFC.., e.g. a multiarmor of its own): the armor items
// then answer nothing, so a layout's armor row stays hidden and the block's own resists row shows that DLL's text.
bool g_armorOther = false;

std::wstring DamageIcon(std::uint8_t type) {
  const char* view = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x920);
  if (view == nullptr || type > 2) {
    return L"";
  }
  wchar_t tag[64];
  swprintf_s(tag, L" <icon=\"(%d)(TextureID(%d))\">", kIconSize, Field<std::int32_t>(view, 0x1CC + 4u * type));
  return tag;
}

// The armor as the stock resists value: "0.20" and the icon of its damage type ([proto+1D3h]: 0 hand, 1 ranged,
// 2 siege, icons [[game+920h]+1CCh/1D0h/1D4h]). With multiarmor (a proto with an armor per damage type), every armor
// above 0, by damage type: "0.30 <hand>  0.20 <ranged>".
bool ArmorText(const char* unit, bool icon, std::wstring* out) {
  if (g_armorOther) {
    return false;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  unsigned char types[8];
  float values[8];
  const int n = uhc::unitinfo::Armors(proto, types, values, 8);
  if (n >= 2) {
    std::vector<std::pair<unsigned char, float>> armors;
    for (int i = 0; i < n; ++i) {
      armors.emplace_back(types[i], values[i]);
    }
    std::sort(armors.begin(), armors.end());  // hand, ranged, siege, then the mod's own
    out->clear();
    for (const auto& [type, armor] : armors) {
      *out += (out->empty() ? L"" : L"  ") + Number(armor) + (icon ? DamageIcon(type) : L"");
    }
    return true;
  }
  const float armor = Field<float>(proto, 0xC4);
  if (!(armor > 0.0f)) {
    return false;
  }
  *out = Number(armor) + (icon ? DamageIcon(Field<std::uint8_t>(proto, 0x1D3)) : L"");
  return true;
}

bool ItemArmor(const char* unit, std::wstring* out) { return ArmorText(unit, true, out); }
bool ItemArmorValue(const char* unit, std::wstring* out) { return ArmorText(unit, false, out); }

bool ItemGarrison(const char* unit, std::wstring* out) {
  const std::int32_t capacity = kMaxContained(Field<const char*>(unit, 0x5C));
  if (capacity <= 0) {
    return false;
  }
  wchar_t text[48];
  swprintf_s(text, L"%d / %d", Field<std::int32_t>(unit, 0x74), capacity);
  *out = text;
  return true;
}

bool ProtoPoints(const char* unit, std::uint32_t field, std::wstring* out) {
  const float points = Field<float>(Field<const char*>(unit, 0x5C), field);
  if (!(points > 0.0f)) {
    return false;
  }
  *out = Number(points);
  return true;
}

// Train points are a unit's: a building keeps a default value there (30) that trains nothing.
std::int32_t g_unitTypeId = -1;  // the abstract type Unit, set on each database load (unittypes.h)
bool ItemTrainPoints(const char* unit, std::wstring* out) {
  if (g_unitTypeId < 0 || !kProtoIsType(Field<const char*>(unit, 0x5C), g_unitTypeId)) {
    return false;
  }
  return ProtoPoints(unit, 0x6C, out);
}
bool ItemBuildPoints(const char* unit, std::wstring* out) { return ProtoPoints(unit, 0xCC, out); }

// ---- Batch 2: attacks, costs and what other keys know ----

constexpr std::uint32_t kAttackList = 0x00CF05B0;   // the stat panel fill's attack list {data, count, capacity}
constexpr std::uint32_t kAttackListGuard = 0x00CF05BC;  // bit 0: the list was constructed (0x4D7905)

using AttackListFn = void(__thiscall*)(const char* tactic, const char* unit, std::int32_t, std::int32_t, std::int32_t,
                                       void* list);
using ResListGetFn = float(__thiscall*)(const char* list, std::int32_t resource);
using ResourceIconFn = const char*(__thiscall*)(const char* database, std::int32_t resource);
using UnitResourceFn = std::int32_t(__thiscall*)(const char* unit);
using UnitAmountFn = float(__thiscall*)(const char* unit, std::int32_t resource);
using UnitTestFn = bool(__thiscall*)(const char* unit);
const auto kAttackListFill = reinterpret_cast<AttackListFn>(0x00487EEE);
const auto kResListGet = reinterpret_cast<ResListGetFn>(0x0044EFFF);
const auto kResourceIcon = reinterpret_cast<ResourceIconFn>(0x00706EFB);
const auto kHoldsResource = reinterpret_cast<UnitTestFn>(0x0045EE8B);
const auto kHeldResource = reinterpret_cast<UnitResourceFn>(0x004DBEC1);
const auto kHeldAmount = reinterpret_cast<UnitAmountFn>(0x004E5979);
const auto kHeldInitial = reinterpret_cast<UnitAmountFn>(0x00494503);

const char* Database() { return Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x140); }

// ---- Ability attacks: shown only when the unit can use them ----
//
// An action of a tactics file that a power names in its <unitAction> (powers.xml) is used only through that power,
// that is through an ability record of abilities.xml (Crack Shot, Sharpshooter...). The tactic lists it as active
// all the same, so the stat panels show it on every unit of the tactics file, though most cannot use it. Such an
// action counts as enabled when one of the unit's ability records is available, as the command panel's GetNth
// (0x6EE68C..0x6EE701) tests it: the player's proto (0x45311B) is the record's +4, the record's tech +0Ch is active
// (0x94AF27), its age +10h is the player's [player+50h], and its power (0x6076E9) names that action
// ([power+12Ch]: a 4-byte block with the action name's index, set by the <unitAction> handler 0x5F22CA, the index
// space of [action+4]). Any other action is enabled.

using PlayerProtoFn = const char*(__thiscall*)(const char* player, std::int32_t protoId);
using TechActiveFn = bool(__thiscall*)(const char* techs, std::int32_t player, std::int32_t tech);
using PowerByIdFn = const char*(__thiscall*)(const char* database, std::int32_t power);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kTechActive = reinterpret_cast<TechActiveFn>(0x0094AF27);
const auto kPowerById = reinterpret_cast<PowerByIdFn>(0x006076E9);
constexpr std::uint32_t kWorldAbilities = 0x56C;  // [world+56Ch]: the ability manager, records {data, count}
constexpr std::uint32_t kPowerAction = 0x12C;     // [power+12Ch]: the <unitAction> block, or null
// The UnitAction powers' vtable: its +24h slot (0xB855F4) is that <unitAction> handler's function 0x5F2231, the only
// vtable slot that points there; other power classes keep other data at +12Ch.
constexpr std::uint32_t kUnitActionPowerVtable = 0x00B855D0;

bool g_abilityReads = false;  // the GetNth test and the <unitAction> handler hold the stock bytes
bool g_filterAbilities = true;  // <bigPanelRows abilities="all"> turns the filter off

struct AbilityCache {
  const char* manager = nullptr;
  std::int32_t count = -1;
  std::vector<std::int32_t> actions;  // the action name indices a power of a record names, sorted
} g_abilityCache;

std::int32_t PowerActionName(const char* database, std::int32_t powerId) {
  const char* power = kPowerById(database, powerId);
  if (power == nullptr || Field<std::uint32_t>(power, 0) != kUnitActionPowerVtable) {
    return -1;  // another kind of power: +12Ch is something else
  }
  const std::int32_t* block = Field<const std::int32_t*>(power, kPowerAction);
  return block == nullptr ? -1 : *block;
}

const char* AbilityManager() {
  const char* world = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x13C);
  return world == nullptr ? nullptr : Field<const char*>(world, kWorldAbilities);
}

// The actions some ability record's power names, rebuilt when the manager or its record count changes (a game load).
const std::vector<std::int32_t>& AbilityActions() {
  const char* manager = AbilityManager();
  const char* database = Database();
  const std::int32_t count = manager == nullptr ? 0 : Field<std::int32_t>(manager, 4);
  if (manager != g_abilityCache.manager || count != g_abilityCache.count) {
    g_abilityCache = AbilityCache{manager, count, {}};
    for (std::int32_t i = 0; database != nullptr && i < count; ++i) {
      const char* record = Field<const char* const*>(manager, 0)[i];
      const std::int32_t name = record == nullptr ? -1 : PowerActionName(database, Field<std::int32_t>(record, 8));
      if (name >= 0) {
        g_abilityCache.actions.push_back(name);
      }
    }
    std::sort(g_abilityCache.actions.begin(), g_abilityCache.actions.end());
    g_abilityCache.actions.erase(std::unique(g_abilityCache.actions.begin(), g_abilityCache.actions.end()),
                                 g_abilityCache.actions.end());
  }
  return g_abilityCache.actions;
}

bool ActionEnabled(const char* unit, const char* action) {
  if (!g_filterAbilities || !g_abilityReads || unit == nullptr || action == nullptr) {
    return true;
  }
  const std::int32_t name = Field<std::int32_t>(action, 4);
  const std::vector<std::int32_t>& powered = AbilityActions();
  if (name < 0 || !std::binary_search(powered.begin(), powered.end(), name)) {
    return true;  // not an ability's action: the tactic uses it itself
  }
  const char* manager = AbilityManager();
  const char* database = Database();
  const char* player = Field<const char*>(unit, 0x44);
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* world = Field<const char*>(Game(), 0x13C);
  const char* techs = world == nullptr ? nullptr : Field<const char*>(world, 0x7C);
  if (manager == nullptr || database == nullptr || player == nullptr || proto == nullptr || techs == nullptr) {
    return true;
  }
  const char* own = kPlayerProto(player, Field<std::int32_t>(proto, 8));
  if (own == nullptr) {
    return true;
  }
  const std::int32_t ownId = Field<std::int32_t>(own, 4);
  const std::int32_t count = Field<std::int32_t>(manager, 4);
  for (std::int32_t i = 0; i < count; ++i) {
    const char* record = Field<const char* const*>(manager, 0)[i];
    if (record == nullptr || Field<std::int32_t>(record, 4) != ownId) {
      continue;
    }
    const std::int32_t tech = Field<std::int32_t>(record, 0x0C);
    if (tech >= 0 && !kTechActive(techs, Field<std::int32_t>(player, 0), tech)) {
      continue;
    }
    const std::int32_t age = Field<std::int32_t>(record, 0x10);
    if (age >= 0 && Field<std::int32_t>(player, 0x50) != age) {
      continue;
    }
    if (PowerActionName(database, Field<std::int32_t>(record, 8)) == name) {
      return true;
    }
  }
  return false;
}

// The unit's attacks, as the stat panel lists them (0x4D7892..0x4D79A1): its current tactic
// [[[proto+44h]+10h] + [[unit+58h]+0A8h]*4] fills the list through 0x487EEE, each entry's +4 an index into the
// proto's actions [[proto+44h]+1Ch]; only actions with damage ([action+24h]) are kept.
// withoutDamage: also the listed actions with no damage record, as the stat panel fill writes a row for each.
// enabledOnly: without the ability actions the unit cannot use (ActionEnabled).
std::vector<const char*> Attacks(const char* unit, bool withoutDamage = false, bool enabledOnly = true) {
  std::vector<const char*> out;
  const char* manager = Field<const char*>(unit, 0x58);
  const char* data = Field<const char*>(Field<const char*>(unit, 0x5C), 0x44);
  if (manager == nullptr || data == nullptr) {
    return out;
  }
  const std::int32_t tacticIndex = Field<std::int32_t>(manager, 0xA8);
  if (tacticIndex < 0 || tacticIndex >= Field<std::int32_t>(data, 0x14)) {
    return out;
  }
  const char* tactic = Field<const char* const*>(data, 0x10)[tacticIndex];
  if (tactic == nullptr) {
    return out;
  }
  auto* guard = reinterpret_cast<std::uint32_t*>(kAttackListGuard);
  auto* list = reinterpret_cast<std::int32_t*>(kAttackList);
  if ((*guard & 1) == 0) {  // as the fill's own first use does, less the exit handler
    *guard |= 1;
    list[0] = list[1] = list[2] = 0;
  }
  if (list[2] >= 0) {
    list[1] = 0;
  }
  kAttackListFill(tactic, unit, 0, -1, 1, list);
  const char* entries = reinterpret_cast<const char*>(static_cast<std::intptr_t>(list[0]));
  const std::int32_t actions = Field<std::int32_t>(data, 0x20);
  for (std::int32_t k = 0; entries != nullptr && k < list[1]; ++k) {
    const std::int32_t id = Field<std::int32_t>(entries, 12u * k + 4);
    const char* action = id >= 0 && id < actions ? Field<const char* const*>(data, 0x1C)[id] : nullptr;
    if (action != nullptr && (withoutDamage || Field<const char*>(action, 0x24) != nullptr) &&
        (!enabledOnly || ActionEnabled(unit, action))) {
      out.push_back(action);
    }
  }
  return out;
}

// The icon of a damage type (0 hand, 1 ranged, 2 siege), as the panels show it.
std::wstring TypeIcon(std::uint8_t type) {
  const char* view = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x920);
  if (view == nullptr || type > 2) {
    return L"";
  }
  wchar_t tag[64];
  swprintf_s(tag, L" <icon=\"(%d)(TextureID(%d))\">", kIconSize, Field<std::int32_t>(view, 0x1CC + 4u * type));
  return tag;
}

// The distinct values of the unit's attacks, each with the damage type icon of the first attack that has it (the
// panel has little room: a Musketeer's ROF reads "3 (ranged) 1.5 (hand)"), skipping the values `value` rejects.
template <typename Fn>
bool PerAttack(const char* unit, std::wstring* out, Fn value) {
  std::vector<float> seen;
  out->clear();
  for (const char* action : Attacks(unit)) {
    float v = 0.0f;
    if (!value(action, &v)) {
      continue;
    }
    bool repeated = false;
    for (const float s : seen) {
      repeated |= std::fabs(s - v) < 0.01f;
    }
    if (!repeated) {
      seen.push_back(v);
      *out += (out->empty() ? L"" : L"  ") + Number(v) +
              TypeIcon(Field<std::uint8_t>(Field<const char*>(action, 0x24), 5));
    }
  }
  return !out->empty();
}

// Hand attacks (damage type 0) have a melee reach, not a range worth a row.
bool Ranged(const char* action) { return Field<std::uint8_t>(Field<const char*>(action, 0x24), 5) != 0; }

// ROF [action+34h], ms (<ROF> x 1000); ranges at [[action+18h]+4] (min) and +8 (max); area byte [[action+24h]+6].
bool ItemRof(const char* unit, std::wstring* out) {
  return PerAttack(unit, out, [](const char* a, float* v) {
    *v = static_cast<float>(Field<std::int32_t>(a, 0x34)) / 1000.0f;
    return *v > 0.0f;
  });
}

bool ItemRange(const char* unit, std::wstring* out) {
  return PerAttack(unit, out, [](const char* a, float* v) {
    const char* ranges = Field<const char*>(a, 0x18);
    *v = ranges == nullptr ? 0.0f : Field<float>(ranges, 8);
    return Ranged(a) && *v > 0.0f;
  });
}

bool ItemMinRange(const char* unit, std::wstring* out) {
  return PerAttack(unit, out, [](const char* a, float* v) {
    const char* ranges = Field<const char*>(a, 0x18);
    *v = ranges == nullptr ? 0.0f : Field<float>(ranges, 4);
    return *v > 0.0f;
  });
}

bool ItemArea(const char* unit, std::wstring* out) {
  return PerAttack(unit, out, [](const char* a, float* v) {
    *v = static_cast<float>(Field<std::uint8_t>(Field<const char*>(a, 0x24), 6));
    return *v > 0.0f;
  });
}

// The projectiles an attack fires before its reload: <NumberOfShots> x <NumberProjectiles> (or <NumberOfProjectiles>)
// as the data writes them, with or without numberOfShots (the default, projectiles="data"). With
// projectiles="combat", as combat fires them: the shots while numberOfShots is on, the projectiles only with its
// "projectiles" option; 1 otherwise (no game code but that key reads the tags).
bool g_projectilesData = true;

int ProjectilesPerReload(const char* unit, const char* action) {
  int shots = 1;
  int projectiles = 1;
  if (!uhc::unitinfo::Shots(Field<const char*>(unit, 0x5C), action, &shots, &projectiles, g_projectilesData)) {
    return 1;
  }
  return shots * projectiles;
}

bool ItemProjectiles(const char* unit, std::wstring* out) {
  return PerAttack(unit, out, [unit](const char* a, float* v) {
    *v = static_cast<float>(ProjectilesPerReload(unit, a));
    return *v > 1.0f;
  });
}

// ---- An attack row the stat panel fill had no room for ----

using ActionNameFn = const wchar_t* const*(__thiscall*)(const char* action);
const auto kActionName = reinterpret_cast<ActionNameFn>(0x005F8FC3);  // the action's raw name (0x69B617)

bool ActionFlag(const char* action, std::uint32_t bit) {  // the bit set [action+64h], size [action+68h] in bits
  if (bit >= Field<std::uint32_t>(action, 0x68)) {
    return false;
  }
  return (Field<const std::uint8_t*>(action, 0x64)[bit >> 3] & (1u << (bit & 7))) != 0;
}

// A modifier factor of the unit's modifier record, as the fill reads it: 1.0 below 1e-6 (0xB9FB64) or without one.
float DamageFactor(const char* unit, std::uint32_t field) {
  const char* sub = Field<const char*>(unit, 0xB4);
  const char* record = sub == nullptr ? nullptr : Field<const char*>(sub, 0xC8);
  if (record == nullptr) {
    return 1.0f;
  }
  const float value = Field<float>(record, field);
  return value < *reinterpret_cast<const float*>(0x00B9FB64) ? 1.0f : value;
}

// The label and value of one attack row as the stat panel fill writes them (0x4D7A2E..0x4D7E0F): "%s:" with the
// action's name (string ID [[db+1FE4h] + [action+4]*4], or its raw name), then "%d <icon>": the damage
// [[action+24h]] x the count scale (flag 12h: the contained units [unit+74h], capped by [action+48h] when above 0)
// x the modifier record's +8 x its +14h (hand, ranged) or +10h (siege), truncated, with the damage type's icon;
// then, with flag 0Ah, " %d <icon>": the range of the action's range entry -1 (0x4946D6) and the range icon
// [[game+920h]+218h]. The bonus multipliers that follow in the stock row are left out.
// The name the stat panel fill gives an action's row (0x4D7A2E): its string, or its raw name.
std::wstring ActionDisplayName(const char* action) {
  const char* database = Database();
  if (database == nullptr) {
    return L"";
  }
  const std::int32_t nameIndex = Field<std::int32_t>(action, 4);
  std::int32_t stringId = -1;
  if (nameIndex >= 0 && nameIndex < Field<std::int32_t>(database, 0x1FDC)) {
    stringId = Field<const std::int32_t*>(database, 0x1FE4)[nameIndex];
  }
  std::wstring name = stringId >= 0 ? StringById(stringId) : L"";
  if (name.empty()) {
    const wchar_t* const* raw = kActionName(action);
    name = raw != nullptr && *raw != nullptr ? *raw : L"";
  }
  return name;
}

bool AttackRow(const char* unit, const char* action, std::wstring* label, std::wstring* value) {
  const char* database = Database();
  const char* view = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x920);
  if (database == nullptr || view == nullptr) {
    return false;
  }
  *label = ActionDisplayName(action) + L":";
  const char* damage = Field<const char*>(action, 0x24);
  const float base = damage == nullptr ? 0.0f : Field<float>(damage, 0);
  const std::uint8_t type = damage == nullptr ? 0 : Field<std::uint8_t>(damage, 5);
  float scale = 1.0f;
  if (ActionFlag(action, 0x12)) {
    scale = static_cast<float>(Field<std::int32_t>(unit, 0x74));
    const float cap = Field<float>(action, 0x48);
    if (scale > cap && cap > 0.0f) {
      scale = cap;
    }
  }
  scale *= DamageFactor(unit, 0x08);
  const float typed = DamageFactor(unit, type == 2 ? 0x10 : 0x14);
  wchar_t text[160];
  swprintf_s(text, L"%d <icon=\"(%d)(TextureID(%d))\">", static_cast<int>(typed * scale * base), kIconSize,
             type <= 2 ? Field<std::int32_t>(view, 0x1CC + 4u * type) : 0);
  *value = text;
  if (ActionFlag(action, 0x0A)) {
    const char* ranges = Field<const char*>(action, 0x18);
    const std::int32_t count = Field<std::int32_t>(action, 0x1C);
    for (std::int32_t i = 0; ranges != nullptr && i < count; ++i) {
      if (Field<std::int32_t>(ranges, 16u * i) == -1) {
        swprintf_s(text, L" %d <icon=\"(%d)(TextureID(%d))\">", static_cast<int>(Field<float>(ranges, 16u * i + 8)),
                   kIconSize, Field<std::int32_t>(view, 0x218));
        *value += text;
        break;
      }
    }
  }
  return true;
}

// The player's proto cost list [proto+70h] (with its techs; read through 0x44EFFF, which unmasks it): each resource's
// icon, then its amount, as the game's resource bar shows them ("<food> 100  <gold> 25").
bool ItemCost(const char* unit, std::wstring* out) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* database = Database();
  if (database == nullptr) {
    return false;
  }
  out->clear();
  const std::int32_t resources = Field<std::int32_t>(database, 0x80);
  for (std::int32_t r = 0; r < resources && r < 16; ++r) {
    const float cost = kResListGet(proto + 0x70, r);
    if (cost > 0.0f) {
      wchar_t text[96];
      swprintf_s(text, L"%ls<icon=\"(%d)(%hs)\">%d", out->empty() ? L"" : L" ", kIconSize, kResourceIcon(database, r),
                 static_cast<int>(cost + 0.5f));
      *out += text;
    }
  }
  return !out->empty();
}

bool ProtoInt(const char* unit, std::uint32_t field, std::wstring* out) {
  const std::int32_t value = Field<std::int32_t>(Field<const char*>(unit, 0x5C), field);
  if (value <= 0) {
    return false;
  }
  *out = std::to_wstring(value);
  return true;
}

// PopulationCount [proto+0D8h], stored times K by decimalPopulation (its own panels divide it back the same way).
bool ItemPopulation(const char* unit, std::wstring* out) {
  const std::int32_t value = Field<std::int32_t>(Field<const char*>(unit, 0x5C), 0xD8);
  if (value <= 0) {
    return false;
  }
  *out = Number(static_cast<float>(value) / static_cast<float>(uhc::unitinfo::PopulationScale()));
  return true;
}
bool ItemBuildLimit(const char* unit, std::wstring* out) { return ProtoInt(unit, 0x108, out); }  // BuildLimit

bool ItemBounty(const char* unit, std::wstring* out) {  // <Bounty>, float [proto+168h] (handler 0x5F5D79)
  const float bounty = Field<float>(Field<const char*>(unit, 0x5C), 0x168);
  if (!(bounty > 0.0f)) {
    return false;
  }
  *out = Number(bounty);
  return true;
}

// What a mine, bush, carcass or herd animal holds, as the stock "resource held" row reads it.
bool ItemInventory(const char* unit, std::wstring* out) {
  const char* database = Database();
  if (database == nullptr || !kHoldsResource(unit)) {
    return false;
  }
  const std::int32_t resource = kHeldResource(unit);
  if (resource < 0) {
    return false;
  }
  wchar_t text[96];
  swprintf_s(text, L"%d/%d <icon=\"(16)(%hs)\">", static_cast<int>(kHeldAmount(unit, resource)),
             static_cast<int>(kHeldInitial(unit, resource)), kResourceIcon(database, resource));
  *out = text;
  return true;
}

// The countdown of a unit with a lifespan, [[unit+0B4h]+1Ch], while state bit 3 is set (setLifespan 0x48DCB9).
bool ItemLifespan(const char* unit, std::wstring* out) {
  const auto* bits = Field<const std::uint8_t*>(unit, 4);
  const char* sub = Field<const char*>(unit, 0xB4);
  if (bits == nullptr || sub == nullptr || (bits[0] & 0x08) == 0) {
    return false;
  }
  const float left = Field<float>(sub, 0x1C);
  if (!(left > 0.0f)) {
    return false;
  }
  wchar_t text[32];
  swprintf_s(text, L"%d s", static_cast<int>(left + 0.5f));
  *out = text;
  return true;
}

// overhealHitpointBars: the hit points above InitialHitpoints of a marked unit.
bool ItemOverheal(const char* unit, std::wstring* out) {
  const char* proto = Field<const char*>(unit, 0x5C);
  if (!uhc::unitinfo::OverhealOn(proto)) {
    return false;
  }
  const float above = Field<float>(unit, 0x64) - Field<float>(proto, 0x9C);
  if (!(above >= 1.0f)) {
    return false;
  }
  *out = L"+" + std::to_wstring(static_cast<int>(above));
  return true;
}

bool ItemVeterancy(const char* unit, std::wstring* out) { return uhc::unitinfo::Veterancy(unit, out); }
bool ItemPoison(const char* unit, std::wstring* out) { return uhc::unitinfo::Poison(unit, out); }
bool ItemRandomCost(const char* unit, std::wstring* out) { return uhc::unitinfo::RandomCost(unit, out); }
bool ItemShipments(const char* unit, std::wstring* out) { return uhc::unitinfo::ShipmentCounts(unit, out); }
bool ItemGatherRate(const char* unit, std::wstring* out) { return uhc::unitinfo::GatherRate(unit, out); }

// ---- Batch 3: building, regeneration, our auras ----

constexpr std::uint8_t kBuildActionType = 0;  // [action+60h] of a unit's Build action (the type list, 0x5227B4)
constexpr std::uint8_t kBuildingState = 8;    // [action+61h] while it works (its animation loop, 0x9D34B1)
constexpr int kMaxWorkers = 64;
bool g_buildReads = false;  // the build tick's code matches what BuildRateOn mirrors
bool g_regenReads = false;  // the regeneration's code matches what ItemRegen mirrors

bool AllMatch(std::initializer_list<const uhc::Site*> list) {
  bool all = true;
  for (const uhc::Site* site : list) {
    if (!uhc::Matches(*site)) {
      uhc::Log(L"minUIStats: site %hs at 0x%08X does not hold the stock bytes", site->name, site->va);
      all = false;
    }
  }
  return all;
}

using RateForFn = float(__thiscall*)(const char* tacticsAction, const char* target);
using BuilderFactorFn = float(__thiscall*)(const char* target, std::int32_t builderId, std::int32_t protoActionId);
const auto kRateFor = reinterpret_cast<RateForFn>(0x00487C45);
const auto kBuilderFactor = reinterpret_cast<BuilderFactorFn>(0x009C4C0C);

// What one builder adds to its target per second, as the build tick 0x9D3D6B..0x9D3DC3 computes it before it
// multiplies by the frame time [world+104h]: the rate of its tactics action for the target (0x487C45; with
// buildingWorkRateAuras, the factor that key's hook of that call applies), the builder factor 0x9C4C0C (1.0 for
// the first builder of the site, the civ's figure for the others), the world's rate [world+318h] and the
// builder's player's [player+37Ch]. 0 when the unit is not building `target` right now.
float BuildRateOn(const char* builder, const char* target) {
  if (!g_buildReads) {
    return 0.0f;
  }
  const char* manager = Field<const char*>(builder, 0x58);
  const char* action = manager == nullptr ? nullptr : Field<const char*>(manager, 0x24);
  const char* player = Field<const char*>(builder, 0x44);
  const char* world = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x13C);
  if (action == nullptr || player == nullptr || world == nullptr || Field<std::uint8_t>(action, 0x60) != kBuildActionType ||
      Field<std::uint8_t>(action, 0x61) != kBuildingState || Field<std::int32_t>(action, 0x14) != Field<std::int32_t>(target, 0x10)) {
    return 0.0f;
  }
  const char* tactics = Field<const char*>(action, 0x04);
  if (tactics == nullptr) {
    return 0.0f;
  }
  const float rate = kRateFor(tactics, target) * uhc::unitinfo::BuildWorkFactor(builder);
  const float factor = kBuilderFactor(target, Field<std::int32_t>(builder, 0x10), Field<std::int32_t>(tactics, 0x08));
  return rate * factor * Field<float>(world, 0x318) * Field<float>(player, 0x37C);
}

// A building under construction: its building data [unit+68h] (+4 the build points so far, +8 the fraction),
// below 1.0.
bool UnderConstruction(const char* unit, const char** data) {
  *data = Field<const char*>(unit, 0x68);
  return *data != nullptr && Field<float>(*data, 8) < 1.0f;
}

// The builders of a site: its worker list [unit+94h], count [unit+98h], 18h-byte entries whose +0 is the worker's
// ID (the list 0x9C4C0C walks).
float SiteBuildRate(const char* unit, int* builders) {
  const std::int32_t count = Field<std::int32_t>(unit, 0x98);
  const char* entries = Field<const char*>(unit, 0x94);
  float total = 0.0f;
  *builders = 0;
  std::int32_t seen[kMaxWorkers];
  for (std::int32_t i = 0; entries != nullptr && i < count && i < kMaxWorkers; ++i) {
    const std::int32_t id = Field<std::int32_t>(entries, 0x18u * i);
    seen[i] = id;
    bool repeated = false;
    for (std::int32_t j = 0; j < i && !repeated; ++j) {
      repeated = seen[j] == id;  // a unit is counted once, by its one current action
    }
    const char* worker = repeated ? nullptr : UnitById(id);
    const float rate = worker == nullptr ? 0.0f : BuildRateOn(worker, unit);
    if (rate > 0.0f) {
      total += rate;
      ++*builders;
    }
  }
  return total;
}

// "0:45" to finish: the build points left ([proto+0CCh], the cap the tick passes to the add 0x7ADE95, less
// [data+4]) over the sum of the builders' rates. Nothing while nobody builds it.
bool ItemBuildTime(const char* unit, std::wstring* out) {
  const char* data = nullptr;
  if (!UnderConstruction(unit, &data)) {
    return false;
  }
  int builders = 0;
  const float rate = SiteBuildRate(unit, &builders);
  const float left = Field<float>(Field<const char*>(unit, 0x5C), 0xCC) - Field<float>(data, 4);
  if (!(rate > 0.0f) || left < 0.0f) {
    return false;
  }
  const int seconds = static_cast<int>(left / rate + 0.5f);
  wchar_t text[32];
  swprintf_s(text, L"%d:%02d", seconds / 60, seconds % 60);
  *out = text;
  return true;
}

bool ItemBuildProgress(const char* unit, std::wstring* out) {
  const char* data = nullptr;
  if (!g_buildReads || !UnderConstruction(unit, &data)) {
    return false;
  }
  *out = std::to_wstring(static_cast<int>(Field<float>(data, 8) * 100.0f)) + L"%";
  return true;
}

// A builder at work: the points per second it adds to the site it builds.
bool ItemBuildRate(const char* unit, std::wstring* out) {
  const char* manager = Field<const char*>(unit, 0x58);
  const char* action = manager == nullptr ? nullptr : Field<const char*>(manager, 0x24);
  const char* target = action == nullptr ? nullptr : UnitById(Field<std::int32_t>(action, 0x14));
  const float rate = target == nullptr ? 0.0f : BuildRateOn(unit, target);
  if (!(rate > 0.0f)) {
    return false;
  }
  wchar_t text[32];
  swprintf_s(text, L"%.2f", static_cast<double>(rate));
  *out = text;
  return true;
}

// Regeneration, per player (FUN_004905E1, from the player update 0x490A52; `this` the player). For each civ ID of
// the list [player+20h] (count +24h) that the database's civ table knows ([db+24h], count [db+28h]), the records
// [player+44h] + ID*0Ch ({data, count}) of 14h bytes: +0 the unit type healed (the player's query 0x45356D),
// +8 the rate in % of max HP per second (skipped when |rate| is below 0xB9FD78), +0Ch the idle time it needs
// (0: none). A unit of that type gains rate x max HP x 0.01 per second (0x490811..0x49085D), while idle that long
// when the record asks for it. The fire pit's Regeneration dance (0x679E66, native civs and danceBonusCivs) is a
// separate source, not added here.
bool ItemRegen(const char* unit, std::wstring* out) {
  const char* player = Field<const char*>(unit, 0x44);
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* database = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x140);
  if (!g_regenReads || player == nullptr || proto == nullptr || database == nullptr) {
    return false;
  }
  const std::int32_t* civs = Field<const std::int32_t*>(player, 0x20);
  const std::int32_t civCount = Field<std::int32_t>(player, 0x24);
  const char* table = Field<const char*>(player, 0x44);
  const char* const* civTable = Field<const char* const*>(database, 0x24);
  const std::int32_t civTableCount = Field<std::int32_t>(database, 0x28);
  if (civs == nullptr || table == nullptr || civTable == nullptr) {
    return false;
  }
  const float minRate = *reinterpret_cast<const float*>(0x00B9FD78);
  float percent = 0.0f;
  for (std::int32_t k = 0; k < civCount && k < 64; ++k) {
    const std::int32_t civ = civs[k];
    if (civ < 0 || civ >= civTableCount || civTable[civ] == nullptr) {
      continue;
    }
    const char* records = Field<const char*>(table, 0x0Cu * civ);
    const std::int32_t count = Field<std::int32_t>(table, 0x0Cu * civ + 4);
    for (std::int32_t r = 0; records != nullptr && r < count && r < 256; ++r) {
      const float rate = Field<float>(records, 0x14u * r + 8);
      if (!(std::fabs(rate) < minRate) && kProtoIsType(proto, Field<std::int32_t>(records, 0x14u * r))) {
        percent += rate;
      }
    }
  }
  if (!(percent > 0.0f)) {
    return false;
  }
  *out = Number(percent * kMaxHp(unit) * 0.01f);
  return true;
}

// Our aura keys only.
bool ItemAuras(const char* unit, std::wstring* out) {
  out->clear();
  std::wstring part;
  if (uhc::unitinfo::WorkAura(unit, &part)) {
    *out += part;
  }
  if (uhc::unitinfo::GatherAura(unit, &part)) {
    *out += (out->empty() ? L"" : L" ") + part;
  }
  if (uhc::unitinfo::ResourceAura(unit, &part)) {
    *out += (out->empty() ? L"" : L" ") + part;
  }
  return !out->empty();
}

using ItemFn = bool (*)(const char* unit, std::wstring* out);

template <ItemFn Item>
bool __stdcall ItemRef(uhc::DataRefValue* value) {
  if (value == nullptr || value->type != uhc::kDataRefString) {
    return false;
  }
  const char* unit = CurrentRefUnit();
  std::wstring text;
  if (unit == nullptr || Field<const char*>(unit, 0x5C) == nullptr || !Item(unit, &text)) {
    return true;  // the empty string the evaluator made
  }
  const BString source{text.data()};
  kBStringAssign(reinterpret_cast<BString*>(&value->text), &source, -1, -1);
  return true;
}

struct ItemInfo {
  const char* name;     // the data file's item
  const wchar_t* ref;   // its data ref
  ItemFn fn;
  uhc::DataRefProvider provider;
};

const ItemInfo kItems[] = {
    {"hitpoints", L"uhcHitpoints", &ItemHitpoints, &ItemRef<&ItemHitpoints>},
    {"speed", L"uhcSpeed", &ItemSpeed, &ItemRef<&ItemSpeed>},
    {"baseSpeed", L"uhcBaseSpeed", &ItemBaseSpeed, &ItemRef<&ItemBaseSpeed>},
    {"los", L"uhcLOS", &ItemLos, &ItemRef<&ItemLos>},
    {"armor", L"uhcArmor", &ItemArmor, &ItemRef<&ItemArmor>},
    {"armorValue", L"uhcArmorValue", &ItemArmorValue, &ItemRef<&ItemArmorValue>},
    {"garrison", L"uhcGarrison", &ItemGarrison, &ItemRef<&ItemGarrison>},
    {"trainPoints", L"uhcTrainPoints", &ItemTrainPoints, &ItemRef<&ItemTrainPoints>},
    {"buildPoints", L"uhcBuildPoints", &ItemBuildPoints, &ItemRef<&ItemBuildPoints>},
    {"rof", L"uhcROF", &ItemRof, &ItemRef<&ItemRof>},
    {"range", L"uhcRange", &ItemRange, &ItemRef<&ItemRange>},
    {"minRange", L"uhcMinRange", &ItemMinRange, &ItemRef<&ItemMinRange>},
    {"area", L"uhcArea", &ItemArea, &ItemRef<&ItemArea>},
    {"projectiles", L"uhcProjectiles", &ItemProjectiles, &ItemRef<&ItemProjectiles>},
    {"cost", L"uhcCost", &ItemCost, &ItemRef<&ItemCost>},
    {"population", L"uhcPopulation", &ItemPopulation, &ItemRef<&ItemPopulation>},
    {"bounty", L"uhcBounty", &ItemBounty, &ItemRef<&ItemBounty>},
    {"buildLimit", L"uhcBuildLimit", &ItemBuildLimit, &ItemRef<&ItemBuildLimit>},
    {"inventory", L"uhcInventory", &ItemInventory, &ItemRef<&ItemInventory>},
    {"lifespan", L"uhcLifespan", &ItemLifespan, &ItemRef<&ItemLifespan>},
    {"overheal", L"uhcOverheal", &ItemOverheal, &ItemRef<&ItemOverheal>},
    {"veterancy", L"uhcVeterancy", &ItemVeterancy, &ItemRef<&ItemVeterancy>},
    {"poison", L"uhcPoison", &ItemPoison, &ItemRef<&ItemPoison>},
    {"randomCost", L"uhcRandomCost", &ItemRandomCost, &ItemRef<&ItemRandomCost>},
    {"shipments", L"uhcShipments", &ItemShipments, &ItemRef<&ItemShipments>},
    {"gatherRate", L"uhcGatherRate", &ItemGatherRate, &ItemRef<&ItemGatherRate>},
    {"buildTime", L"uhcBuildTime", &ItemBuildTime, &ItemRef<&ItemBuildTime>},
    {"buildProgress", L"uhcBuildProgress", &ItemBuildProgress, &ItemRef<&ItemBuildProgress>},
    {"buildRate", L"uhcBuildRate", &ItemBuildRate, &ItemRef<&ItemBuildRate>},
    {"regen", L"uhcRegen", &ItemRegen, &ItemRef<&ItemRegen>},
    {"auras", L"uhcAuras", &ItemAuras, &ItemRef<&ItemAuras>},
};

const ItemInfo* FindItem(const std::string& name) {
  for (const ItemInfo& item : kItems) {
    if (_stricmp(item.name, name.c_str()) == 0) {
      return &item;
    }
  }
  return nullptr;
}

// ---- The data file ----

struct TypeFilter {
  std::string name;
  std::int32_t id = -1;  // set on each database load (unittypes.h)
};

struct Row {
  std::wstring gadget;
  const ItemInfo* item = nullptr;  // item= ...
  std::wstring label;
  std::wstring text;               // ... or text=: segments split by '|', each with its {item}s
  std::vector<TypeFilter*> types;  // empty: every unit
  bool keep = false;               // overlap="show": shown even over the stack portraits or an <avoid> gadget
  std::wstring tip;                // tip= / tipId=: the help text (what the icons mean)
  bool lines = false;              // join="line": each part on a line of its own instead of joined by spaces
  // spill="...": the gadget of another row, the next line; when this row's text is too wide for its gadget and that
  // row shows nothing, the words that do not fit go there (four costs over the portrait of a unit without population)
  std::wstring spill;
  int spillRow = -1;               // its index in g_rows, set after the file is read
};

// <stockLabel gadget="..." text="..." tip="..."/>: a label of the original panel whose text the key replaces while
// the original panel shows it (the hit points and resists labels by an icon). The panel's own fill writes it each
// time; the key writes it again after.
struct StockLabel {
  std::wstring gadget;
  std::wstring text;
  std::wstring tip;
};
std::vector<StockLabel> g_labels;

// <replace row="..." stock="a,b"/>: while that row of the key shows, the original gadgets named are hidden (the
// panel's own fill shows them each time; the key hides them again after it). The layout can then keep the original
// gadgets where they were, so it reads the same without the key, and draw the key's version in a gadget of its own
// (the hit points and resists rows with their icons).
struct Replace {
  std::wstring row;
  std::vector<std::wstring> stock;
};
std::vector<Replace> g_replaces;

// "[icon:ui\ingame\stat_icon_los]" in a data file's text: the icon markup at the minimized panel's icon size.
std::wstring ExpandIcons(const std::wstring& text) {
  std::wstring out;
  size_t pos = 0;
  for (size_t open = text.find(L"[icon:"); open != std::wstring::npos; open = text.find(L"[icon:", pos)) {
    const size_t close = text.find(L']', open);
    if (close == std::wstring::npos) {
      break;
    }
    out += text.substr(pos, open - pos);
    wchar_t size[16];
    swprintf_s(size, L"(%d)", kIconSize);
    out += L"<icon=\"" + std::wstring(size) + L"(" + text.substr(open + 6, close - open - 6) + L")\">";
    pos = close + 1;
  }
  return out + text.substr(pos);
}

// "[string:68852]" in a text, label or tip: that string of the game's string table, read when the row is shown (the
// tables load after the DLL starts) and kept once read.
std::map<std::int32_t, std::wstring> g_stringCache;

std::wstring ExpandStrings(const std::wstring& text) {
  static const std::wstring kOpen = L"[string:";
  size_t open = text.find(kOpen);
  if (open == std::wstring::npos) {
    return text;
  }
  std::wstring out;
  size_t pos = 0;
  for (; open != std::wstring::npos; open = text.find(kOpen, pos)) {
    const size_t close = text.find(L']', open);
    if (close == std::wstring::npos) {
      break;
    }
    out += text.substr(pos, open - pos);
    pos = close + 1;
    const std::int32_t id = _wtoi(text.c_str() + open + kOpen.size());
    auto found = g_stringCache.find(id);
    if (found == g_stringCache.end()) {
      std::wstring value = StringById(id);
      if (value.empty()) {
        continue;  // not kept: the table may not be read yet
      }
      found = g_stringCache.emplace(id, std::move(value)).first;
    }
    out += found->second;
  }
  return out + text.substr(pos);
}

// A text= row: each '|'-separated segment with its {item}s replaced; a segment with an item that has nothing for
// the unit is left out, the rest are joined by three spaces. False when no segment is left.
bool RenderTemplate(const std::wstring& text, const char* unit, std::wstring* out, bool lines = false) {
  out->clear();
  size_t start = 0;
  while (start <= text.size()) {
    size_t bar = text.find(L'|', start);
    if (bar == std::wstring::npos) {
      bar = text.size();
    }
    const std::wstring segment = text.substr(start, bar - start);
    std::wstring rendered;
    bool ok = true;
    size_t pos = 0;
    while (ok && pos < segment.size()) {
      const size_t open = segment.find(L'{', pos);
      const size_t close = open == std::wstring::npos ? std::wstring::npos : segment.find(L'}', open);
      if (open == std::wstring::npos || close == std::wstring::npos) {
        rendered += ExpandStrings(segment.substr(pos));
        break;
      }
      rendered += ExpandStrings(segment.substr(pos, open - pos));
      const std::wstring name = segment.substr(open + 1, close - open - 1);
      std::string narrow(name.begin(), name.end());
      const ItemInfo* item = FindItem(narrow);
      std::wstring value;
      ok = item != nullptr && item->fn(unit, &value);
      rendered += value;
      pos = close + 1;
    }
    if (ok && !rendered.empty()) {
      *out += (out->empty() ? L"" : (lines ? L"\n" : L"   ")) + rendered;
    }
    start = bar + 1;
  }
  return !out->empty();
}

// Kinds of mirrored stat rows.
enum Kind : std::uint32_t {
  kName = 1u << 0, kHitpoints = 1u << 1, kGroupHealth = 1u << 2, kResource = 1u << 3, kGatherers = 1u << 4,
  kRate = 1u << 5, kSpeed = 1u << 6, kResists = 1u << 7, kAttack = 1u << 8, kShownAttack = 1u << 9,
  kSpecial = 1u << 10, kOther = 1u << 11, kDropped = 1u << 12, kAuto = 1u << 31,
};

struct BigPanel {
  bool on = false;
  std::wstring pattern;  // with one %d
  int first = 0;
  int count = 16;
  std::uint32_t skip = kAuto;
  bool keep = false;  // overlap="show"
  bool takeStock = false;  // stockRows="take": the original attack rows (StackLabel0..2) are written by the key too
  std::wstring rofIcon;    // rofIcon="...": each attack row gets its ROF and this icon after its damage
  std::wstring projectilesIcon;  // projectilesIcon="...": shots x projectiles before the reload, when above 1
  bool trimZeros = true;   // multiplierZeros="keep" turns it off: "1.50x" written as "1.5x", "2.00x" as "2x"
  // tipParentheses="keep" turns it off: the game's help text lines lose the parentheses around an icon and around
  // the name right after one ("11 <icon> (Ranged) Damage" is "11 <icon> Ranged Damage")
  bool unwrapIcons = true;
  // The attack rows' help text gets a line for the ROF and one for the projectiles ("%s": the number), each with
  // its icon, after the stock lines (damage, range and area, one per multiplier).
  std::wstring rofTip = L"Attacks every %s s";
  std::wstring projectilesTip = L"%s projectiles";
};

std::vector<Row> g_rows;
BigPanel g_big;
std::vector<TypeFilter*> g_filters;
std::vector<std::wstring> g_avoid;  // <avoid gadget="..."/>: stock gadgets whose text a row must not cover
std::wstring g_file;
bool g_stackReads = false;  // the stack portrait code matches what CollectBlockers reads
bool g_attackReads = false;  // the stat fill's attack rows match what AttackRow mirrors

const char kDefaultRows[] =
    "<minUIRows>"
    "<row gadget='unitselectionpanel-uhcCost' text='{cost}' tip='Cost' spill='unitselectionpanel-uhcPop'/>"
    "<row gadget='unitselectionpanel-uhcPop' text='[icon:ui\\ingame\\stat_icon_building]{population}' "
    "tip='Population'/>"
    "<row gadget='unitselectionpanel-uhcSight' text='[icon:ui\\ingame\\stat_icon_los]{los}|"
    "[icon:ui\\ingame\\stat_icon_speed]{speed}' tip='Line of sight, speed'/>"
    "<row gadget='unitselectionpanel-uhcTrainGarrison' text='[icon:ui\\ingame\\stat_icon_traintime]{trainPoints}|"
    "[icon:ui\\cursors\\cursor_garrison]{garrison}' tip='Train time (seconds), garrison'/>"
    "<row gadget='unitselectionpanel-uhcRow2' text='Done in {buildTime}|Builds {buildRate}/s|Regen {regen}/s|"
    "Overheal {overheal}|Poison {poison}|Aura {auras}'/>"
    "<row gadget='unitselectionpanel-uhcHitpoints' "
    "text='&lt;color=1, 1, 0&gt;[string:68852]:&lt;/color&gt;  {hitpoints}' tipId='68852'/>"
    "<row gadget='unitselectionpanel-uhcResists' text='[icon:ui\\ingame\\stat_icon_armor] {armor}' tipId='35758'/>"
    "<replace row='unitselectionpanel-uhcHitpoints' "
    "stock='unitselectionpanel-unitHitPointsLabel,unitselectionpanel-unitHitPointsValue'/>"
    "<replace row='unitselectionpanel-uhcResists' "
    "stock='unitselectionpanel-unitResistsLabel,unitselectionpanel-unitResistsValue'/>"
    "<bigPanelRows gadget='unitselectionpanel-uhcRow%d' first='3' skip='auto,speed' stockRows='take' "
    "rofIcon='ui\\ingame\\stat_icon_rof' projectilesIcon='ui\\ingame\\stat_icon_projectiles'/>"
    "<avoid gadget='unitselectionpanel-unitResourceValue'/>"
    "<avoid gadget='unitselectionpanel-unitResourceRateLabel'/>"
    "</minUIRows>";

std::string Lower(std::string text) {
  for (char& c : text) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  return text;
}

std::string Trim(const std::string& text) {
  const size_t a = text.find_first_not_of(" \t\r\n");
  const size_t b = text.find_last_not_of(" \t\r\n");
  return a == std::string::npos ? std::string() : text.substr(a, b - a + 1);
}

std::wstring Wide(const std::string& text) {
  if (text.empty()) {
    return {};
  }
  const int length = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0);
  std::wstring out(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), out.data(), length);
  return out;
}

std::string Decode(const std::string& text) {
  std::string out;
  for (size_t i = 0; i < text.size(); ++i) {
    if (text[i] == '&') {
      static const struct { const char* name; char c; } kEntities[] = {
          {"&lt;", '<'}, {"&gt;", '>'}, {"&amp;", '&'}, {"&quot;", '"'}, {"&apos;", '\''}};
      bool done = false;
      for (const auto& e : kEntities) {
        const size_t n = std::strlen(e.name);
        if (text.compare(i, n, e.name) == 0) {
          out += e.c;
          i += n - 1;
          done = true;
          break;
        }
      }
      if (done) {
        continue;
      }
    }
    out += text[i];
  }
  return out;
}

struct Element {
  std::string tag;
  std::map<std::string, std::string> attributes;
};

// The start tags of `text` with their attributes (names lowercased); comments and declarations skipped. False if a
// tag is not closed or an attribute is malformed.
bool ParseTags(const std::string& text, std::vector<Element>* out) {
  size_t pos = 0;
  while ((pos = text.find('<', pos)) != std::string::npos) {
    if (text.compare(pos, 4, "<!--") == 0) {
      const size_t end = text.find("-->", pos + 4);
      if (end == std::string::npos) {
        return false;
      }
      pos = end + 3;
      continue;
    }
    size_t gt = pos + 1;
    for (char quote = 0; gt < text.size(); ++gt) {
      const char c = text[gt];
      if (quote != 0) {
        quote = c == quote ? 0 : quote;
      } else if (c == '"' || c == '\'') {
        quote = c;
      } else if (c == '>') {
        break;
      }
    }
    if (gt >= text.size()) {
      return false;
    }
    const std::string body = text.substr(pos + 1, gt - pos - 1);
    pos = gt + 1;
    if (body.empty() || body[0] == '?' || body[0] == '!' || body[0] == '/') {
      continue;
    }
    Element element;
    size_t i = 0;
    while (i < body.size() && (std::isalnum(static_cast<unsigned char>(body[i])) || body[i] == '_')) {
      ++i;
    }
    element.tag = Lower(body.substr(0, i));
    while (i < body.size()) {
      while (i < body.size() && (std::isspace(static_cast<unsigned char>(body[i])) || body[i] == '/')) {
        ++i;
      }
      if (i >= body.size()) {
        break;
      }
      const size_t nameStart = i;
      while (i < body.size() && body[i] != '=' && !std::isspace(static_cast<unsigned char>(body[i]))) {
        ++i;
      }
      const std::string name = Lower(body.substr(nameStart, i - nameStart));
      while (i < body.size() && std::isspace(static_cast<unsigned char>(body[i]))) {
        ++i;
      }
      if (i >= body.size() || body[i] != '=') {
        return false;
      }
      ++i;
      while (i < body.size() && std::isspace(static_cast<unsigned char>(body[i]))) {
        ++i;
      }
      if (i >= body.size() || (body[i] != '"' && body[i] != '\'')) {
        return false;
      }
      const size_t close = body.find(body[i], i + 1);
      if (close == std::string::npos) {
        return false;
      }
      element.attributes[name] = Decode(body.substr(i + 1, close - i - 1));
      i = close + 1;
    }
    out->push_back(std::move(element));
  }
  return true;
}

const std::string* Attr(const Element& element, const char* name) {
  const auto found = element.attributes.find(name);
  return found == element.attributes.end() ? nullptr : &found->second;
}

std::vector<std::string> SplitList(const std::string& text) {
  std::vector<std::string> out;
  size_t start = 0;
  while (start <= text.size()) {
    const size_t comma = text.find(',', start);
    const std::string part = Trim(text.substr(start, comma == std::string::npos ? std::string::npos : comma - start));
    if (!part.empty()) {
      out.push_back(part);
    }
    if (comma == std::string::npos) {
      break;
    }
    start = comma + 1;
  }
  return out;
}

std::wstring Label(const Element& element) {
  if (const std::string* id = Attr(element, "labelid")) {
    return L"\x01" + Wide(*id);  // resolved when shown: the string table is read after the DLL starts
  }
  const std::string* label = Attr(element, "label");
  return label == nullptr ? std::wstring() : ExpandIcons(Wide(*label));
}

// tip="..." or tipId="..." (a string ID, resolved when shown, as labelId).
std::wstring Tip(const Element& element) {
  if (const std::string* id = Attr(element, "tipid")) {
    return L"\x01" + Wide(*id);
  }
  const std::string* tip = Attr(element, "tip");
  return tip == nullptr ? std::wstring() : Wide(*tip);
}

bool LoadRows(const std::string& arg) {
  std::wstring path;
  std::string raw;
  std::string text;
  if (uhc::ReadDataListFile(arg, L"minuirows.xml", &path, &raw)) {
    g_file = path;
    if (raw.size() >= 2 && static_cast<unsigned char>(raw[0]) == 0xFF && static_cast<unsigned char>(raw[1]) == 0xFE) {
      const wchar_t* wide = reinterpret_cast<const wchar_t*>(raw.data() + 2);
      const int count = static_cast<int>((raw.size() - 2) / 2);
      const int length = WideCharToMultiByte(CP_UTF8, 0, wide, count, nullptr, 0, nullptr, nullptr);
      text.assign(static_cast<size_t>(length), '\0');
      WideCharToMultiByte(CP_UTF8, 0, wide, count, text.data(), length, nullptr, nullptr);
    } else {
      text = raw.compare(0, 3, "\xEF\xBB\xBF") == 0 ? raw.substr(3) : raw;
    }
  } else if (!arg.empty()) {
    uhc::Log(L"minUIStats: cannot read %ls (error %lu); feature not applied", path.c_str(), GetLastError());
    return false;
  } else {
    g_file = L"(built-in rows; no " + path + L")";
    text = kDefaultRows;
  }
  std::vector<Element> elements;
  if (!ParseTags(text, &elements)) {
    uhc::Log(L"minUIStats: %ls is not well-formed XML; feature not applied", g_file.c_str());
    return false;
  }
  std::map<std::string, TypeFilter*> filters;
  auto typeList = [&](const Element& element) {
    std::vector<TypeFilter*> list;
    if (const std::string* types = Attr(element, "types")) {
      for (const std::string& name : SplitList(*types)) {
        TypeFilter*& filter = filters[Lower(name)];
        if (filter == nullptr) {
          filter = new TypeFilter{name};
          g_filters.push_back(filter);
        }
        list.push_back(filter);
      }
    }
    return list;
  };
  // overlap="show" keeps a row over the stack portraits and <avoid> gadgets; "hide" (the default) hides it there.
  auto keepOnOverlap = [&](const Element& element) {
    const std::string* overlap = Attr(element, "overlap");
    if (overlap == nullptr || _stricmp(Trim(*overlap).c_str(), "hide") == 0) {
      return false;
    }
    if (_stricmp(Trim(*overlap).c_str(), "show") != 0) {
      uhc::Log(L"minUIStats: %ls: overlap=\"%hs\" is not hide or show; hide used", g_file.c_str(), overlap->c_str());
      return false;
    }
    return true;
  };
  for (const Element& element : elements) {
    if (element.tag == "minuirows") {
      continue;
    }
    if (element.tag == "avoid") {
      const std::string* gadget = Attr(element, "gadget");
      if (gadget == nullptr || Trim(*gadget).empty()) {
        uhc::Log(L"minUIStats: %ls: avoid needs gadget; ignored", g_file.c_str());
        continue;
      }
      g_avoid.push_back(Wide(Trim(*gadget)));
      continue;
    }
    if (element.tag == "row") {
      const std::string* gadget = Attr(element, "gadget");
      const std::string* item = Attr(element, "item");
      const std::string* text = Attr(element, "text");
      const ItemInfo* info = item == nullptr ? nullptr : FindItem(Trim(*item));
      if (gadget == nullptr || (info == nullptr && text == nullptr)) {
        uhc::Log(L"minUIStats: %ls: a row needs gadget and a known item= (%hs) or text=; ignored", g_file.c_str(),
                 item == nullptr ? "none" : item->c_str());
        continue;
      }
      if (text != nullptr) {
        const std::wstring wide = Wide(*text);
        for (size_t open = wide.find(L'{'); open != std::wstring::npos; open = wide.find(L'{', open + 1)) {
          const size_t close = wide.find(L'}', open);
          const std::wstring name = close == std::wstring::npos ? L"" : wide.substr(open + 1, close - open - 1);
          if (FindItem(std::string(name.begin(), name.end())) == nullptr) {
            uhc::Log(L"minUIStats: %ls: unknown item {%ls} in a text= row; its segment never shows", g_file.c_str(),
                     name.c_str());
          }
        }
        const std::string* join = Attr(element, "join");
        g_rows.push_back({Wide(Trim(*gadget)), nullptr, L"", ExpandIcons(wide), typeList(element),
                          keepOnOverlap(element), Tip(element),
                          join != nullptr && _stricmp(Trim(*join).c_str(), "line") == 0});
      } else {
        g_rows.push_back({Wide(Trim(*gadget)), info, Label(element), L"", typeList(element), keepOnOverlap(element),
                          Tip(element)});
      }
      if (const std::string* spill = Attr(element, "spill")) {
        g_rows.back().spill = Wide(Trim(*spill));
      }
      continue;
    }
    if (element.tag == "replace") {
      const std::string* row = Attr(element, "row");
      const std::string* stock = Attr(element, "stock");
      if (row == nullptr || stock == nullptr) {
        uhc::Log(L"minUIStats: %ls: replace needs row and stock; ignored", g_file.c_str());
        continue;
      }
      Replace replace{Wide(Trim(*row)), {}};
      for (const std::string& name : SplitList(*stock)) {
        replace.stock.push_back(Wide(name));
      }
      g_replaces.push_back(replace);
      continue;
    }
    if (element.tag == "stocklabel") {
      const std::string* gadget = Attr(element, "gadget");
      const std::string* labelText = Attr(element, "text");
      if (gadget == nullptr || labelText == nullptr) {
        uhc::Log(L"minUIStats: %ls: stockLabel needs gadget and text; ignored", g_file.c_str());
        continue;
      }
      g_labels.push_back({Wide(Trim(*gadget)), ExpandIcons(Wide(*labelText)), Tip(element)});
      continue;
    }
    if (element.tag == "bigpanelrows") {
      const std::string* gadget = Attr(element, "gadget");
      if (gadget == nullptr || gadget->find("%d") == std::string::npos) {
        uhc::Log(L"minUIStats: %ls: bigPanelRows needs gadget with %%d; ignored", g_file.c_str());
        continue;
      }
      g_big.on = true;
      g_big.pattern = Wide(Trim(*gadget));
      g_big.keep = keepOnOverlap(element);
      if (const std::string* first = Attr(element, "first")) {
        g_big.first = std::atoi(first->c_str());
      }
      if (const std::string* count = Attr(element, "count")) {
        g_big.count = std::atoi(count->c_str());
      }
      if (const std::string* skip = Attr(element, "skip")) {
        static const struct { const char* name; std::uint32_t kind; } kKinds[] = {
            {"auto", kAuto}, {"name", kName}, {"hitpoints", kHitpoints}, {"grouphealth", kGroupHealth},
            {"resource", kResource}, {"gatherers", kGatherers}, {"rate", kRate}, {"speed", kSpeed},
            {"resists", kResists}, {"attacks", kAttack}, {"shownattacks", kShownAttack}, {"special", kSpecial},
            {"other", kOther}};
        g_big.skip = 0;
        for (const std::string& part : SplitList(*skip)) {
          bool known = false;
          for (const auto& kind : kKinds) {
            if (_stricmp(kind.name, part.c_str()) == 0) {
              g_big.skip |= kind.kind;
              known = true;
            }
          }
          if (!known) {
            uhc::Log(L"minUIStats: %ls: unknown skip kind %hs; ignored", g_file.c_str(), part.c_str());
          }
        }
      }
      g_big.count = g_big.count < 2 ? 2 : (g_big.count > 32 ? 32 : g_big.count);
      if (const std::string* stock = Attr(element, "stockrows")) {
        g_big.takeStock = _stricmp(Trim(*stock).c_str(), "take") == 0;
        if (!g_big.takeStock && _stricmp(Trim(*stock).c_str(), "keep") != 0) {
          uhc::Log(L"minUIStats: %ls: stockRows=\"%hs\" is not take or keep; keep used", g_file.c_str(), stock->c_str());
        }
      }
      if (const std::string* rof = Attr(element, "roficon")) {
        g_big.rofIcon = Wide(Trim(*rof));
      }
      if (const std::string* projectiles = Attr(element, "projectilesicon")) {
        g_big.projectilesIcon = Wide(Trim(*projectiles));
      }
      if (const std::string* from = Attr(element, "projectiles")) {
        g_projectilesData = _stricmp(Trim(*from).c_str(), "combat") != 0;
        if (g_projectilesData && _stricmp(Trim(*from).c_str(), "data") != 0) {
          uhc::Log(L"minUIStats: %ls: projectiles=\"%hs\" is not data or combat; data used", g_file.c_str(),
                   from->c_str());
        }
      }
      if (const std::string* zeros = Attr(element, "multiplierzeros")) {
        g_big.trimZeros = _stricmp(Trim(*zeros).c_str(), "keep") != 0;
        if (g_big.trimZeros && _stricmp(Trim(*zeros).c_str(), "drop") != 0) {
          uhc::Log(L"minUIStats: %ls: multiplierZeros=\"%hs\" is not drop or keep; drop used", g_file.c_str(),
                   zeros->c_str());
        }
      }
      if (const std::string* parentheses = Attr(element, "tipparentheses")) {
        g_big.unwrapIcons = _stricmp(Trim(*parentheses).c_str(), "keep") != 0;
        if (g_big.unwrapIcons && _stricmp(Trim(*parentheses).c_str(), "drop") != 0) {
          uhc::Log(L"minUIStats: %ls: tipParentheses=\"%hs\" is not drop or keep; drop used", g_file.c_str(),
                   parentheses->c_str());
        }
      }
      for (const auto& [name, field] : {std::pair<const char*, std::wstring*>{"roftip", &g_big.rofTip},
                                        {"projectilestip", &g_big.projectilesTip}}) {
        if (const std::string* tip = Attr(element, name)) {
          const std::wstring wide = Wide(*tip);
          const size_t at = wide.find(L"%s");
          if (!wide.empty() && (at == std::wstring::npos || wide.find(L'%', at + 2) != std::wstring::npos)) {
            uhc::Log(L"minUIStats: %ls: %hs=\"%hs\" needs one %%s (the number) and no other %%; the default used",
                     g_file.c_str(), name, tip->c_str());
          } else {
            *field = wide;  // empty: no such line
          }
        }
      }
      if (const std::string* abilities = Attr(element, "abilities")) {
        g_filterAbilities = _stricmp(Trim(*abilities).c_str(), "all") != 0;
      }
      continue;
    }
    uhc::Log(L"minUIStats: %ls: unknown element <%hs>; ignored", g_file.c_str(), element.tag.c_str());
  }
  for (Row& row : g_rows) {
    if (row.spill.empty()) {
      continue;
    }
    for (size_t j = 0; j < g_rows.size(); ++j) {
      if (&g_rows[j] != &row && _wcsicmp(g_rows[j].gadget.c_str(), row.spill.c_str()) == 0) {
        row.spillRow = static_cast<int>(j);
      }
    }
    if (row.spillRow < 0) {
      uhc::Log(L"minUIStats: %ls: spill=\"%ls\" is not the gadget of another row; ignored", g_file.c_str(),
               row.spill.c_str());
    }
  }
  return true;
}

// ---- The gadgets of the panel ----

struct Gadget {
  std::int32_t handle = 0;
  bool valid = false;
  bool shown = true;  // as far as the DLL knows: show and hide only on a change
  bool known = false;
  std::wstring text;
  std::uint32_t style = 0;
  std::wstring tip;
};

constexpr std::uint32_t kStockRows = 0x344;      // the selection panel's StackLabel0..2 handles (bind 0x9BB18F)
constexpr std::uint32_t kResourceLabel = 0x300;  // unitResourceLabel: shown, the attack rows start at StackLabel1

struct PanelGadgets {
  char* panel = nullptr;
  std::int32_t typeNameHandle = 0;
  std::vector<Gadget> rows;  // g_rows order
  std::vector<Gadget> big;   // the bigPanelRows block, consecutive gadgets
  std::vector<std::int32_t> avoid;  // the <avoid> gadgets this layout has
  std::vector<Gadget> stock;        // StackLabel0..2 ([panel+344h+i*4]), written by the key with stockRows="take"
  std::vector<std::int32_t> labels; // the <stockLabel> gadgets, in g_labels order (0 when the layout lacks one)
  struct ReplaceState {
    int row = -1;                       // its index in g_rows, or -1
    std::vector<std::int32_t> stock;    // the original gadgets this layout has
    bool active = false;                // the row showed at the last full fill
  };
  std::vector<ReplaceState> replaces;  // in g_replaces order
  bool any = false;
  bool logged = false;  // the first fill with stack portraits in our rows' band was logged
};
PanelGadgets g_panel;

void* Manager() {
  const char* ui = *reinterpret_cast<const char* const*>(kUiManager);
  return ui == nullptr ? nullptr : Field<void*>(ui, 0x44);
}

std::int32_t Lookup(char* panel, const std::wstring& name) {
  BString text{nullptr};
  kBStringFromWide(&text, name.c_str());
  std::int32_t handle = 0;
  kGadgetByName(panel, &handle, &text, 1);
  kBStringFree(&text);
  return handle;
}

bool ValidHandle(std::int32_t handle) {
  return handle != *reinterpret_cast<const std::int32_t*>(kNoGadget) && handle != 0;
}

// The gadget object behind a handle, or null; the reference is released at once, as stock does.
void* GadgetObject(std::int32_t handle) {
  std::int32_t ref[2] = {0, 0};
  std::int32_t* result = kGadgetRef(ref, handle);
  void* gadget = reinterpret_cast<void*>(static_cast<std::intptr_t>(result[1]));
  if (gadget != nullptr) {
    kGadgetRelease(result[0]);
  }
  return gadget;
}

// Finds this panel's gadgets by name, once per panel (the panel's own type name handle tells a new panel at the
// same address).
void ResolvePanel(char* panel) {
  const std::int32_t typeName = Field<std::int32_t>(panel, 0x2E8);
  if (g_panel.panel == panel && g_panel.typeNameHandle == typeName) {
    return;
  }
  g_panel = PanelGadgets{};
  g_panel.panel = panel;
  g_panel.typeNameHandle = typeName;
  for (const Row& row : g_rows) {
    Gadget gadget;
    gadget.handle = Lookup(panel, row.gadget);
    gadget.valid = ValidHandle(gadget.handle);
    g_panel.any |= gadget.valid;
    g_panel.rows.push_back(gadget);
  }
  if (g_big.on) {
    for (int i = 0; i < g_big.count; ++i) {
      wchar_t name[160];
      swprintf_s(name, g_big.pattern.c_str(), g_big.first + i);
      Gadget gadget;
      gadget.handle = Lookup(panel, name);
      gadget.valid = ValidHandle(gadget.handle);
      if (!gadget.valid) {
        break;
      }
      g_panel.big.push_back(gadget);
    }
    g_panel.any |= !g_panel.big.empty();
  }
  for (const std::wstring& name : g_avoid) {
    const std::int32_t handle = Lookup(panel, name);
    if (ValidHandle(handle)) {
      g_panel.avoid.push_back(handle);
    }
  }
  if (g_big.takeStock) {
    for (int i = 0; i < 3; ++i) {
      Gadget gadget;
      gadget.handle = Field<std::int32_t>(panel, kStockRows + 4u * i);
      gadget.valid = ValidHandle(gadget.handle);
      g_panel.stock.push_back(gadget);
    }
  }
  for (const StockLabel& label : g_labels) {
    const std::int32_t handle = Lookup(panel, label.gadget);
    g_panel.labels.push_back(ValidHandle(handle) ? handle : 0);
  }
  for (const Replace& replace : g_replaces) {
    PanelGadgets::ReplaceState state;
    for (size_t i = 0; i < g_rows.size(); ++i) {
      if (_wcsicmp(g_rows[i].gadget.c_str(), replace.row.c_str()) == 0 && g_panel.rows[i].valid) {
        state.row = static_cast<int>(i);
      }
    }
    for (const std::wstring& name : replace.stock) {
      const std::int32_t handle = Lookup(panel, name);
      if (ValidHandle(handle)) {
        state.stock.push_back(handle);
      }
    }
    g_panel.replaces.push_back(state);
  }
  int rows = 0;
  for (const Gadget& g : g_panel.rows) {
    rows += g.valid ? 1 : 0;
  }
  uhc::Log(L"minUIStats: panel %p: %d of %u row gadgets, %u big panel row gadgets", panel, rows,
           static_cast<unsigned>(g_panel.rows.size()), static_cast<unsigned>(g_panel.big.size()));
}

void SetVisible(Gadget* gadget, bool visible) {
  void* manager = Manager();
  if (manager == nullptr || (gadget->known && gadget->shown == visible)) {
    return;
  }
  (visible ? kGadgetShow : kGadgetHide)(manager, gadget->handle);
  gadget->shown = visible;
  gadget->known = true;
}

// Writes the gadget's text (and style, when not 0, and help text) only when they changed.
void SetText(Gadget* gadget, const std::wstring& text, std::uint32_t style, const std::wstring& tip) {
  if (gadget->text == text && gadget->style == style && gadget->tip == tip && !gadget->text.empty()) {
    SetVisible(gadget, true);
    return;
  }
  void* object = GadgetObject(gadget->handle);
  if (object == nullptr) {
    return;
  }
  BString value{nullptr};
  kBStringFromWide(&value, text.c_str());
  if (style != 0) {
    VirtualAt<void(__thiscall*)(void*, std::uint32_t)>(object, 0x84)(object, style);
  }
  VirtualAt<void(__thiscall*)(void*, const BString*)>(object, 0x80)(object, &value);
  VirtualAt<void(__thiscall*)(void*)>(object, 0x54)(object);
  kBStringFree(&value);
  BString help{nullptr};
  kBStringFromWide(&help, tip.c_str());
  kBStringSet(reinterpret_cast<BString*>(static_cast<char*>(object) + kGadgetTip), &help);
  kBStringFree(&help);
  gadget->text = text;
  gadget->style = style;
  gadget->tip = tip;
  SetVisible(gadget, true);
}

void Hide(Gadget* gadget) {
  gadget->text.clear();
  SetVisible(gadget, false);
}

// A gadget the panel's own fill writes and shows each time (the original attack rows and labels): what the DLL
// knows of it is stale after every fill, so it is written again as if new.
void ForceText(Gadget* gadget, const std::wstring& text, std::uint32_t style, const std::wstring& tip) {
  gadget->text.clear();
  gadget->known = false;
  SetText(gadget, text, style, tip);
}

void ForceHide(Gadget* gadget) {
  gadget->known = false;
  Hide(gadget);
}

// A label of the original panel: only its text (and help text when one is given), not whether it shows.
void WriteLabel(std::int32_t handle, const std::wstring& text, const std::wstring& tip) {
  void* object = GadgetObject(handle);
  if (object == nullptr) {
    return;
  }
  BString value{nullptr};
  kBStringFromWide(&value, text.c_str());
  VirtualAt<void(__thiscall*)(void*, const BString*)>(object, 0x80)(object, &value);
  VirtualAt<void(__thiscall*)(void*)>(object, 0x54)(object);
  kBStringFree(&value);
  if (!tip.empty()) {
    BString help{nullptr};
    kBStringFromWide(&help, tip.c_str());
    kBStringSet(reinterpret_cast<BString*>(static_cast<char*>(object) + kGadgetTip), &help);
    kBStringFree(&help);
  }
}

// ---- The stack portraits and the <avoid> gadgets: where a row must not be drawn ----

// A gadget's rectangle in screen pixels: its top left point at +28h ({x, y} as fractions of the screen, then
// {x, y} in pixels at +30h / +34h) and its bottom right one at +38h (+40h / +44h), as 0x44B9D8 and the stack
// layout 0x4C8F49 read them. Every gadget of the screen uses the same space, whatever its parent.
struct Box {
  std::int32_t left = 0, top = 0, right = 0, bottom = 0;
  float screenHeight = 0.0f;  // the screen's height in pixels, from the gadget's top as pixels and as a fraction
};

// Any gadget behind a handle, buttons included (0x404296: the lookup 0x40423C with type mask 0; GadgetObject's
// 0x44900A asks for mask 10h, which a button does not have), released at once as the stack layout does (0x40431B).
using GadgetAnyFn = void*(__cdecl*)(std::int32_t handle);
const auto kGadgetAny = reinterpret_cast<GadgetAnyFn>(0x00404296);

bool g_anyLookup = false;  // 0x404296 holds the stock bytes

const char* AnyGadget(std::int32_t handle) {
  if (!g_anyLookup) {
    return nullptr;
  }
  void* object = kGadgetAny(handle);
  if (object != nullptr) {
    kGadgetRelease(handle);
  }
  return static_cast<const char*>(object);
}

bool GadgetBox(std::int32_t handle, Box* out) {
  if (!ValidHandle(handle)) {
    return false;
  }
  const char* object = AnyGadget(handle);
  if (object == nullptr) {
    return false;
  }
  *out = {Field<std::int32_t>(object, 0x30), Field<std::int32_t>(object, 0x34), Field<std::int32_t>(object, 0x40),
          Field<std::int32_t>(object, 0x44)};
  const float fy = Field<float>(object, 0x2C);  // the top as a fraction of the screen
  out->screenHeight = fy > 0.01f ? static_cast<float>(out->top) / fy : 0.0f;
  return out->right > out->left && out->bottom > out->top;
}

// About how wide one character of the panel's text font is, in pixels: the font follows the screen's height, not the
// gadget's (measured at 1920 x 1080: 38 characters and two icons, an icon counting as two, in 210 px, 4.9 px each).
// Below 1080 lines it does not shrink with it: at 1024 x 768 an attack row is as wide in pixels as at 1920 x 1080
// (an Escopetero's ranged row, 61 characters in 314 px, 5.1 px each).
float CharPixels(const Box& box) {
  return box.screenHeight > 0.0f ? 0.00452f * (std::max)(box.screenHeight, 1080.0f) : 0.217f * 23.0f;
}

// Shown, as the base show (0x447BBC) tests it before doing nothing: flag bits 0 and 1 of [gadget+0A4h] set, bit 7
// clear.
bool GadgetShown(std::int32_t handle) {
  if (!ValidHandle(handle)) {
    return false;
  }
  const char* object = AnyGadget(handle);
  const std::uint8_t flags = object == nullptr ? 0 : Field<std::uint8_t>(object, 0xA4);
  return (flags & 0x03) == 0x03 && (flags & 0x80) == 0;
}

constexpr std::uint32_t kStackPlaced = 0x2CC;     // the buttons the stack fill placed this fill {data, count}
constexpr std::uint32_t kStackBigIndex = 0x36C;   // the index of the current stack's Big0 in that list, or -1
constexpr std::uint32_t kStackBigBack = 0x324;    // unitStackButtonBigBackground
constexpr int kMaxStackButtons = 16;              // 9 small + Big0 in the stock fill

struct Blockers {
  std::vector<Box> stack;  // the portraits the panel shows now
  std::vector<Box> avoid;  // the <avoid> gadgets shown now
};

// The stack portraits as the selection panel's fill placed them earlier in this same fill (0x4C940E: the list
// [panel+2CCh] emptied, then one button per stack, at most 9; 0x4C8F49 centred them in buttonArea and showed
// them, with the big background around the current one), and the <avoid> gadgets that are shown.
void CollectBlockers(const char* panel, Blockers* out) {
  out->stack.clear();
  out->avoid.clear();
  if (g_stackReads) {
    const std::int32_t* placed = Field<const std::int32_t*>(panel, kStackPlaced);
    const std::int32_t count = Field<std::int32_t>(panel, kStackPlaced + 4);
    for (std::int32_t i = 0; placed != nullptr && i < count && i < kMaxStackButtons; ++i) {
      Box box;
      if (GadgetBox(placed[i], &box)) {
        out->stack.push_back(box);
      }
    }
    const std::int32_t big = Field<std::int32_t>(panel, kStackBigIndex);
    Box box;
    if (big >= 0 && big < count && GadgetBox(Field<std::int32_t>(panel, kStackBigBack), &box)) {
      out->stack.push_back(box);
    }
  }
  for (const std::int32_t handle : g_panel.avoid) {
    Box box;
    if (GadgetShown(handle) && GadgetBox(handle, &box)) {
      out->avoid.push_back(box);
    }
  }
}

// A portrait is an image that fills its rectangle: any common pixel blocks the row. A text gadget's rectangle is
// padded (the stock ones overlap each other by a few pixels): it blocks only a row it covers over more than half
// the row's height.
bool Blocked(const Gadget& gadget, const Blockers& blockers) {
  if (blockers.stack.empty() && blockers.avoid.empty()) {
    return false;
  }
  Box own;
  if (!GadgetBox(gadget.handle, &own)) {
    return false;
  }
  auto across = [&](const Box& other) {
    return (std::min)(own.right, other.right) - (std::max)(own.left, other.left);
  };
  auto down = [&](const Box& other) {
    return (std::min)(own.bottom, other.bottom) - (std::max)(own.top, other.top);
  };
  for (const Box& box : blockers.stack) {
    if (across(box) > 0 && down(box) > 0) {
      return true;
    }
  }
  for (const Box& box : blockers.avoid) {
    if (across(box) > 0 && 2 * down(box) > own.bottom - own.top) {
      return true;
    }
  }
  return false;
}

// Once per panel, the first time the portraits cover one of our rows: where they are, for the log.
void LogBlocked(const Blockers& blockers, const std::wstring& names) {
  if (g_panel.logged) {
    return;
  }
  g_panel.logged = true;
  std::wstring boxes;
  for (const Box& box : blockers.stack) {
    wchar_t text[64];
    swprintf_s(text, L" %d,%d-%d,%d", box.left, box.top, box.right, box.bottom);
    boxes += text;
  }
  uhc::Log(L"minUIStats: %u stack portraits (px%ls) and %u avoid gadgets shown; hidden for them:%ls",
           static_cast<unsigned>(blockers.stack.size()), boxes.c_str(), static_cast<unsigned>(blockers.avoid.size()),
           names.c_str());
}

// ---- The mirrored stat panel rows ----

struct StatRow {
  std::uint32_t labelStyle = 0;
  std::wstring label;
  std::wstring value;
  std::wstring tip;
  bool labelSet = false;
  bool valueSet = false;
  size_t compactEnd = std::wstring::npos;  // an attack row: the end of its damage, ROF and projectiles (MarkAttacks)
};

constexpr int kVtableSlots = 128;
void* g_stageLabel = nullptr;
void* g_stageValue = nullptr;
StatRow g_current;
std::vector<StatRow> g_stat;
void* g_vtableCopy[kVtableSlots];
const void* g_vtableOf = nullptr;

std::wstring BStringText(const void* field) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(field);
  return text == nullptr ? std::wstring() : std::wstring(text);
}

void FinishRow() {
  if (!g_current.labelSet && !g_current.valueSet) {
    return;
  }
  g_current.tip = BStringText(static_cast<char*>(g_stageLabel) + kGadgetTip);
  g_stat.push_back(g_current);
  g_current = StatRow{};
}

// The staging gadgets' vtable entries while the fill runs (thiscall: ECX = the gadget, the callee pops the
// arguments, as __fastcall with the EDX slot unused does).
void __fastcall RecordStyle(void* gadget, void*, std::uint32_t style) {
  if (gadget == g_stageLabel) {
    if (g_current.labelSet || g_current.valueSet) {
      FinishRow();
    }
    g_current.labelStyle = style;
  }
}

void __fastcall RecordText(void* gadget, void*, const BString* text) {
  const std::wstring copy = text == nullptr || text->text == nullptr ? std::wstring() : std::wstring(text->text);
  if (gadget == g_stageLabel) {
    if (g_current.labelSet) {
      FinishRow();
    }
    g_current.label = copy;
    g_current.labelSet = true;
  } else if (gadget == g_stageValue) {
    g_current.value = copy;
    g_current.valueSet = true;
  }
}

void __fastcall RecordRefresh(void*, void*) {}
void __fastcall RecordShow(void*, void*, std::int32_t) {}

// The fill's rows for the selection, as the normal interface's stat panel would show them; false if it could not
// run. The fill writes row i into the gadgets of handles [panel+174h+i*4] / [panel+198h+i*4] and reads nothing
// else of its panel; here every row points to the same two staging gadgets, whose text, style, refresh and
// show calls are recorded instead of done while it runs.
bool MirrorStatRows(const char* selection) {
  if (g_panel.big.size() < 2) {
    return false;
  }
  void* label = GadgetObject(g_panel.big[0].handle);
  void* value = GadgetObject(g_panel.big[1].handle);
  if (label == nullptr || value == nullptr || label == value) {
    return false;
  }
  const void* vtable = *static_cast<void**>(label);
  if (vtable != *static_cast<void**>(value)) {
    return false;
  }
  if (g_vtableOf != vtable) {
    std::memcpy(g_vtableCopy, vtable, sizeof(g_vtableCopy));
    g_vtableCopy[0x54 / 4] = reinterpret_cast<void*>(&RecordRefresh);
    g_vtableCopy[0x58 / 4] = reinterpret_cast<void*>(&RecordShow);
    g_vtableCopy[0x80 / 4] = reinterpret_cast<void*>(&RecordText);
    g_vtableCopy[0x84 / 4] = reinterpret_cast<void*>(&RecordStyle);
    g_vtableOf = vtable;
  }
  char panel[kStatRowValues + 4 * kStatRows] = {};
  for (int i = 0; i < kStatRows; ++i) {
    *reinterpret_cast<std::int32_t*>(panel + kStatRowLabels + 4 * i) = g_panel.big[0].handle;
    *reinterpret_cast<std::int32_t*>(panel + kStatRowValues + 4 * i) = g_panel.big[1].handle;
  }
  // The staging gadgets' help texts, which the fill overwrites, are put back after.
  const std::wstring labelTip = BStringText(static_cast<char*>(label) + kGadgetTip);
  const std::wstring valueTip = BStringText(static_cast<char*>(value) + kGadgetTip);
  g_stageLabel = label;
  g_stageValue = value;
  g_current = StatRow{};
  g_stat.clear();
  *static_cast<const void**>(label) = g_vtableCopy;
  *static_cast<const void**>(value) = g_vtableCopy;
  g_uhcMinUiForceFill = 1;
  kStatFill(panel, selection);
  g_uhcMinUiForceFill = 0;
  FinishRow();
  *static_cast<const void**>(label) = vtable;
  *static_cast<const void**>(value) = vtable;
  for (const auto& [object, tip] : {std::pair<void*, const std::wstring*>{label, &labelTip}, {value, &valueTip}}) {
    BString help{nullptr};
    kBStringFromWide(&help, tip->c_str());
    kBStringSet(reinterpret_cast<BString*>(static_cast<char*>(object) + kGadgetTip), &help);
    kBStringFree(&help);
  }
  g_stageLabel = g_stageValue = nullptr;
  return true;
}

struct KindStrings {
  std::wstring hitpoints, speed, resists, gatherers;
  bool loaded = false;
} g_strings;

void LoadKindStrings() {
  if (g_strings.loaded) {
    return;
  }
  g_strings.hitpoints = StringById(24320);  // "Hitpoints:" (0x4D750E)
  g_strings.speed = StringById(24323);      // "Speed:" (0x69B21C)
  g_strings.resists = StringById(35758);    // "Resists:" (0x69B3DF)
  g_strings.gatherers = StringById(34986);  // "Gatherers:" (0x69AED2)
  g_strings.loaded = !g_strings.hitpoints.empty();
}

std::uint32_t Classify(const StatRow& row, size_t index) {
  if (index == 0) {
    return kName;
  }
  if (row.labelStyle == kAttackStyle) {
    return kAttack;
  }
  if (row.label == g_strings.hitpoints) {
    return kHitpoints;
  }
  if (row.label == g_strings.speed) {
    return kSpeed;
  }
  if (row.label == g_strings.resists) {
    return kResists;
  }
  if (row.label == g_strings.gatherers) {
    return kGatherers;
  }
  if (row.label == L"Group Health") {  // a literal in the exe (0xC36838)
    return kGroupHealth;
  }
  if (row.value.size() >= 2 && row.value.compare(row.value.size() - 2, 2, L"/s") == 0) {
    return kRate;
  }
  if (row.label.find(L"<icon=\"(32)") != std::wstring::npos) {
    return kResource;  // "%s (<icon="(32)(%S)">):" with a held amount
  }
  return kOther;
}

// The stat panel fill stops at its 9th row (0x4D7957: cmp ebx,9 / jge): a unit with more attacks than rows left
// loses the last ones. They are added after the fill's last attack row, from the same list (0x487EEE, every action
// it gives, as the fill writes a row for each) and in the fill's own format (AttackRow).
void AddOverflowAttacks(const char* unit, std::vector<std::uint32_t>* kinds, size_t* lastAttack) {
  if (!g_attackReads || unit == nullptr || g_stat.size() < static_cast<size_t>(kStatRows)) {
    return;
  }
  size_t written = 0;
  for (const std::uint32_t kind : *kinds) {
    written += kind == kAttack ? 1 : 0;
  }
  const std::vector<const char*> actions = Attacks(unit, true, false);  // as the fill lists them; MarkAttacks filters
  size_t at = *lastAttack;
  for (size_t i = written; i < actions.size() && i < 32; ++i) {
    StatRow row;
    if (!AttackRow(unit, actions[i], &row.label, &row.value)) {
      break;
    }
    row.labelStyle = kAttackStyle;
    row.labelSet = row.valueSet = true;
    g_stat.insert(g_stat.begin() + static_cast<std::ptrdiff_t>(at), row);
    kinds->insert(kinds->begin() + static_cast<std::ptrdiff_t>(at), kAttack);
    *lastAttack = ++at;
  }
}

// The text without its markup (<icon=...> and the like).
std::wstring StripMarkup(const std::wstring& text) {
  std::wstring out;
  bool tag = false;
  for (const wchar_t c : text) {
    if (c == L'<') {
      tag = true;
    } else if (c == L'>') {
      tag = false;
    } else if (!tag) {
      out += c;
    }
  }
  return out;
}

// Characters on screen, an icon counting as two.
size_t VisibleLength(const std::wstring& text) {
  size_t icons = 0;
  for (size_t at = text.find(L"<icon"); at != std::wstring::npos; at = text.find(L"<icon", at + 1)) {
    ++icons;
  }
  return StripMarkup(text).size() + 2 * icons;
}

// About how many characters of the stat font fit one line of the gadget (CharPixels, with 10 % to spare).
size_t LineBudget(const Gadget& gadget) {
  Box box;
  if (!GadgetBox(gadget.handle, &box) || box.bottom <= box.top) {
    return 30;
  }
  return static_cast<size_t>(0.9f * static_cast<float>(box.right - box.left) / CharPixels(box));
}

// A row in short form, for the last gadget when the rows outnumber the gadgets: an attack's name and damage (its
// value up to the first icon), any other row's label and value. With `withRof`, an attack keeps what MarkAttacks put
// after its damage too (its ROF and projectiles), which a row too long for its column shows when that fits.
std::wstring Compact(const StatRow& row, bool withRof = false) {
  if (row.labelStyle != kAttackStyle) {
    return row.value.empty() ? row.label : row.label + L" " + row.value;
  }
  const size_t icon = row.value.find(L'>');
  std::wstring name = row.label;
  if (!name.empty() && name.back() == L':') {
    name.pop_back();
  }
  if (withRof && row.compactEnd != std::wstring::npos && row.compactEnd <= row.value.size()) {
    return name + L" " + row.value.substr(0, row.compactEnd);
  }
  return name + L" " + (icon == std::wstring::npos ? row.value : row.value.substr(0, icon + 1));
}

// Every icon of a row at the minimized panel's icon size: the stat panel fill writes "(16)" icons (0xBA2100), the
// minimized block "(10)" ones (0xC36508), and both kinds of rows share the panel.
std::wstring NormaliseIcons(const std::wstring& text) {
  static const std::wstring kOpen = L"<icon=\"(";
  std::wstring out = text;
  for (size_t at = out.find(kOpen); at != std::wstring::npos; at = out.find(kOpen, at + 1)) {
    const size_t start = at + kOpen.size();
    const size_t close = out.find(L')', start);
    if (close == std::wstring::npos) {
      break;
    }
    out.replace(start, close - start, std::to_wstring(kIconSize));
  }
  return out;
}

// The multipliers of a text without the zeros that end their decimals: "1.50x" is "1.5x", "2.00x" is "2x", "1.25x"
// stays (a number with a decimal point right before an x or X that ends a word, as the rows' ", %.2fx <icon>" and the
// help text's "%1.2fX Bonus Damage" write them).
std::wstring TrimMultipliers(const std::wstring& text) {
  std::wstring out;
  out.reserve(text.size());
  for (size_t i = 0; i < text.size(); ++i) {
    const wchar_t c = text[i];
    const bool endsWord = i + 1 == text.size() || text[i + 1] == L' ' || text[i + 1] == L'<';
    if ((c == L'x' || c == L'X') && endsWord && !out.empty() && iswdigit(out.back())) {
      size_t digits = out.size();
      while (digits > 0 && iswdigit(out[digits - 1])) {
        --digits;
      }
      if (digits >= 2 && out[digits - 1] == L'.' && iswdigit(out[digits - 2])) {
        size_t end = out.size();
        while (end > digits && out[end - 1] == L'0') {
          --end;
        }
        out.erase(end == digits ? digits - 1 : end);
      }
    }
    out += c;
  }
  return out;
}

// One help text line of the key: `format` with the number for its %s, then " <icon>" (no parentheses).
std::wstring TipLine(const std::wstring& format, const std::wstring& number, const std::wstring& icon) {
  const size_t at = format.find(L"%s");
  if (format.empty() || at == std::wstring::npos) {
    return L"";
  }
  std::wstring line = ExpandStrings(format.substr(0, at) + number + format.substr(at + 2));
  if (!icon.empty()) {
    line += L" <icon=\"(16)(" + icon + L")\">";
  }
  return line;
}

// A help text without the parentheses around its icons, nor around the name right after an icon: the game's lines
// "11 <icon> (Ranged) Damage" (string 42226, "%1s (%2s) Damage"), "1.5X Bonus Damage against <icon> (<color>Maneuver
// Unit</color>)" (42229 and 42230, "... against %2s (%3s)") and "Resists 20% of Ranged (<icon>) Damage" (42223) read
// "11 <icon> Ranged Damage", "... against <icon> Maneuver Unit" and "... of Ranged <icon> Damage". A pair is removed
// only when it holds no other parenthesis and does not run past the line (the next "<ttf>").
std::wstring UnwrapIcons(const std::wstring& text) {
  static const std::wstring kOpen = L"<icon=\"";
  std::wstring out = text;
  for (size_t at = out.find(kOpen); at != std::wstring::npos; at = out.find(kOpen, at + 1)) {
    const size_t end = out.find(L"\">", at);
    if (end == std::wstring::npos) {
      break;
    }
    const size_t after = end + 2;
    size_t before = at;  // "(<icon>)": the icon alone in its pair
    while (before > 0 && out[before - 1] == L' ') {
      --before;
    }
    size_t close = after;
    while (close < out.size() && out[close] == L' ') {
      ++close;
    }
    if (before > 0 && out[before - 1] == L'(' && close < out.size() && out[close] == L')') {
      out.erase(close, 1);
      out.erase(before - 1, 1);
      at = before - 1;
      continue;
    }
    if (close < out.size() && close > after && out[close] == L'(') {  // "<icon> (name)": the name after the icon
      const size_t shut = out.find(L')', close + 1);
      const size_t line = out.find(L"<ttf>", close + 1);
      const size_t nested = out.find(L'(', close + 1);
      if (shut != std::wstring::npos && (line == std::wstring::npos || shut < line) &&
          (nested == std::wstring::npos || nested > shut)) {
        out.erase(shut, 1);
        out.erase(close, 1);
      }
    }
  }
  return out;
}

// What starts each bulleted line of a help text the fill builds: 0x4C5076(text, line, 1, 0) puts "<ttf><ttb>" before
// the line (0x4C50B0); with its fourth argument 1, "<ttf><ttr>" (0x4C8F35), a red line; with both 0, "<ttf><tti>".
const std::wstring kTipLine = L"<ttf><ttb>";

// The attack rows of the fill (and the ones AddOverflowAttacks added), matched in order with the attack list they
// come from (0x487EEE, every listed action, as the fill writes one row per action): a row of an ability action the
// unit cannot use is dropped (ActionEnabled), the others get the minimized panel's icon size and, with rofIcon,
// the action's ROF after the damage: "Ranged ATK:  23 <ranged> 3 <rof> 12 <range>, 3x <cavalry>", and with
// projectilesIcon the projectiles it fires before its reload after that, when above 1 ("4 <cylinder>"); their help
// text gets the same two numbers as lines of their own. The row's label must be the action's name; at the first
// that is not, the matching stops (rows left as written, less the multipliers' zeros).
void MarkAttacks(const char* unit, std::vector<std::uint32_t>* kinds) {
  const std::vector<const char*> actions = Attacks(unit, true, false);
  size_t next = 0;
  for (size_t i = 0; i < g_stat.size(); ++i) {
    if ((*kinds)[i] != kAttack) {
      continue;
    }
    StatRow& row = g_stat[i];
    row.value = NormaliseIcons(row.value);
    if (g_big.trimZeros) {
      row.value = TrimMultipliers(row.value);
      row.tip = TrimMultipliers(row.tip);
    }
    if (g_big.unwrapIcons) {
      row.tip = UnwrapIcons(row.tip);
    }
    const std::wstring shown = StripMarkup(row.label);
    if (shown.find_first_not_of(L" :") == std::wstring::npos) {
      (*kinds)[i] = kDropped;  // nothing to read: a blank line in the panel
    }
    if (next >= actions.size()) {
      break;
    }
    const char* action = actions[next++];
    const std::wstring name = ActionDisplayName(action);
    if (row.label != name + L":") {
      break;
    }
    if (name.empty() || !ActionEnabled(unit, action)) {  // a nameless action's row is a blank line
      (*kinds)[i] = kDropped;
      continue;
    }
    const float rof = static_cast<float>(Field<std::int32_t>(action, 0x34)) / 1000.0f;
    const size_t icon = row.value.find(L"\">");
    if (icon == std::wstring::npos) {
      continue;
    }
    wchar_t size[16];
    swprintf_s(size, L"(%d)", kIconSize);
    size_t at = icon + 2;  // after the damage and its icon
    std::wstring tipLines;
    if (!g_big.rofIcon.empty() && rof > 0.0f) {
      const std::wstring text = L" " + Number(rof) + L" <icon=\"" + size + L"(" + g_big.rofIcon + L")\">";
      row.value.insert(at, text);
      at += text.size();
      const std::wstring line = TipLine(g_big.rofTip, Number(rof), g_big.rofIcon);
      tipLines += line.empty() ? L"" : kTipLine + line;
    }
    const int projectiles = g_big.projectilesIcon.empty() ? 1 : ProjectilesPerReload(unit, action);
    if (projectiles > 1) {
      const std::wstring text =
          L" " + std::to_wstring(projectiles) + L" <icon=\"" + size + L"(" + g_big.projectilesIcon + L")\">";
      row.value.insert(at, text);
      at += text.size();
      const std::wstring line = TipLine(g_big.projectilesTip, std::to_wstring(projectiles), g_big.projectilesIcon);
      tipLines += line.empty() ? L"" : kTipLine + line;
    }
    row.compactEnd = at;
    if (!tipLines.empty()) {
      // After the game's first bulleted line (the damage), as the numbers follow the damage in the row; at the end
      // when the help text has no such line.
      const size_t first = row.tip.find(kTipLine);
      const size_t next = first == std::wstring::npos ? first : row.tip.find(L"<ttf>", first + kTipLine.size());
      if (next == std::wstring::npos) {
        row.tip += tipLines;
      } else {
        row.tip.insert(next, tipLines);
      }
    }
  }
}

// What the key writes into the original attack rows this fill (stockRows="take"), written again after each fill of
// the panel, which rewrites them, until the next selection change or refresh.
struct StockWrite {
  bool show = false;
  std::wstring text;
  std::uint32_t style = 0;
  std::wstring tip;
};
std::vector<StockWrite> g_stockPlan;

void ApplyStockPlan() {
  for (size_t i = 0; i < g_stockPlan.size() && i < g_panel.stock.size(); ++i) {
    Gadget& gadget = g_panel.stock[i];
    if (!gadget.valid) {
      continue;
    }
    if (g_stockPlan[i].show) {
      ForceText(&gadget, g_stockPlan[i].text, g_stockPlan[i].style, g_stockPlan[i].tip);
    } else {
      ForceHide(&gadget);
    }
  }
}

constexpr std::uint32_t kResistsValue = 0x2FC;  // the selection panel's unitResistsValue handle

// With multiarmor, a proto can have an armor per damage type, and the minimized block writes only the stock one
// ("%.2f %s", 0x698C41..): its resists value then lists them all, "0.30 <hand>  0.20 <ranged>".
void ApplyResists(const char* unit) {
  unsigned char types[8];
  float values[8];
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const int n = proto == nullptr ? 0 : uhc::unitinfo::Armors(proto, types, values, 8);
  const std::int32_t handle = Field<std::int32_t>(g_panel.panel, kResistsValue);
  if (n < 2 || !ValidHandle(handle) || !GadgetShown(handle)) {
    return;
  }
  std::vector<std::pair<unsigned char, float>> armors;
  for (int i = 0; i < n; ++i) {
    armors.emplace_back(types[i], values[i]);
  }
  std::sort(armors.begin(), armors.end());  // by damage type: hand, ranged, siege, then the mod's own
  std::wstring text;
  for (const auto& [type, armor] : armors) {
    wchar_t value[32];
    swprintf_s(value, L"%.2f", static_cast<double>(armor));
    text += (text.empty() ? L"" : L"  ") + std::wstring(value) + TypeIcon(type);
  }
  WriteLabel(handle, text, L"");
}

// <replace>: the original gadgets of a row the key shows are hidden again after the panel's own fill showed them.
void ApplyReplaces() {
  void* manager = Manager();
  if (manager == nullptr) {
    return;
  }
  for (const auto& state : g_panel.replaces) {
    if (state.active) {
      for (const std::int32_t handle : state.stock) {
        kGadgetHide(manager, handle);
      }
    }
  }
}

// The <stockLabel> texts, while the original panel shows those labels.
void ApplyStockLabels(const char* unit) {
  ApplyResists(unit);
  for (size_t i = 0; i < g_labels.size() && i < g_panel.labels.size(); ++i) {
    if (g_panel.labels[i] != 0 && GadgetShown(g_panel.labels[i])) {
      std::wstring tip = g_labels[i].tip;
      if (!tip.empty() && tip[0] == L'\x01') {
        tip = StringById(_wtoi(tip.c_str() + 1));
        while (!tip.empty() && (tip.back() == L':' || tip.back() == L' ')) {
          tip.pop_back();
        }
      }
      WriteLabel(g_panel.labels[i], ExpandStrings(g_labels[i].text), ExpandStrings(tip));
    }
  }
}

// An original attack row (its gadget spans the panel to its right edge) too long for its line: the multipliers at its
// end go, last first, until it fits, and " (+N)" says how many; the help text lists them all. At 1920 x 1080 every
// row tested fits; at 1024 x 768 the font is relatively wider and an Escopetero's three multipliers reach the edge.
std::wstring FitMultipliers(const std::wstring& text, const Gadget& gadget) {
  Box box;
  if (!GadgetBox(gadget.handle, &box) || box.right <= box.left) {
    return text;
  }
  const size_t budget = static_cast<size_t>(static_cast<float>(box.right - box.left) / CharPixels(box));
  if (VisibleLength(text) <= budget) {
    return text;
  }
  // Where each multiplier begins: ", " then a digit, up to an x right after a digit (", 1.25x <icon>").
  std::vector<size_t> starts;
  for (size_t at = text.find(L", "); at != std::wstring::npos; at = text.find(L", ", at + 1)) {
    size_t i = at + 2;
    if (i >= text.size() || !iswdigit(text[i])) {
      continue;
    }
    while (i < text.size() && (iswdigit(text[i]) || text[i] == L'.')) {
      ++i;
    }
    if (i < text.size() && (text[i] == L'x' || text[i] == L'X')) {
      starts.push_back(at);
    }
  }
  for (size_t dropped = 1; dropped <= starts.size(); ++dropped) {
    const std::wstring shorter = text.substr(0, starts[starts.size() - dropped]) + L" (+" +
                                 std::to_wstring(dropped) + L")";
    if (VisibleLength(shorter) <= budget || dropped == starts.size()) {
      return shorter;
    }
  }
  return text;
}

// The help text of a row shown in short form: the game's own help text of the row (an attack's damage, range, area
// and multipliers, worded, with the key's ROF and projectiles lines), or the whole row as text when it has none.
// `first`: the help text starts with it (otherwise a plain row goes on a line of its own).
std::wstring FullTip(const StatRow& row, bool first) {
  if (!row.tip.empty()) {
    return row.tip;
  }
  return (first ? L"" : L"\n") + StripMarkup(row.label + L" " + row.value);
}

void FillBigRows(const char* selection, const char* unit, bool minimizedBlock, const Blockers& blockers,
                 std::wstring* blockedNames) {
  const bool take = g_big.takeStock && minimizedBlock && g_panel.stock.size() == 3;
  g_stockPlan.clear();
  if (!MirrorStatRows(selection)) {
    for (Gadget& gadget : g_panel.big) {
      Hide(&gadget);
    }
    return;  // the original attack rows stay as the panel wrote them
  }
  LoadKindStrings();
  std::uint32_t skip = g_big.skip;
  bool resourceShown = false;
  std::vector<std::uint32_t> kinds;
  size_t lastAttack = 0;
  for (size_t i = 0; i < g_stat.size(); ++i) {
    kinds.push_back(Classify(g_stat[i], i));
    resourceShown |= kinds.back() == kResource;
    if (kinds.back() == kAttack) {
      lastAttack = i + 1;
    }
  }
  AddOverflowAttacks(unit, &kinds, &lastAttack);
  MarkAttacks(unit, &kinds);
  if (skip & kAuto) {
    // What the minimized block shows itself (0x6987D7..0x69A60F): the owner, hit points, resists, the resource held,
    // the AutoGather rate, the special attacks inline, and the first three rows of attacks less the resource row.
    // With stockRows="take" the key writes those attack and special rows itself, from the first original row on.
    skip |= minimizedBlock ? (kName | kHitpoints | kResists | kResource | kRate | kShownAttack | kSpecial) : kName;
  }
  if (take) {
    skip &= ~(kShownAttack | kSpecial);
  }
  skip |= kDropped;
  int shownAttacks = (skip & kShownAttack) ? (resourceShown ? 2 : 3) : 0;
  // The rows to show, in order.
  std::vector<const StatRow*> rows;
  for (size_t i = 0; i < g_stat.size(); ++i) {
    std::uint32_t kind = kinds[i];
    if (kind == kOther && lastAttack != 0 && i >= lastAttack) {
      kind = kSpecial;
    }
    if (kind == kAttack && shownAttacks > 0) {
      --shownAttacks;
      continue;
    }
    const std::wstring visible = StripMarkup(g_stat[i].label + g_stat[i].value);
    if (!(skip & kind) && visible.find_first_not_of(L" :") != std::wstring::npos) {
      rows.push_back(&g_stat[i]);  // a row with nothing to read would be a blank line
    }
  }
  // The gadgets the rows go into, in order: with stockRows="take", the original attack rows the minimized block
  // used (StackLabel0..2, from StackLabel1 when it showed a resource row), then the bigPanelRows block. A block
  // gadget under a stack portrait or a shown <avoid> gadget is left empty, and the rows go on in the next one; the
  // original rows are never covered (they are the panel's own lines).
  struct Slot {
    Gadget* gadget;
    int stock;  // its StackLabel index, or -1
  };
  std::vector<Slot> free;
  if (take) {
    g_stockPlan.assign(3, StockWrite{});
    // The block's resource row (its own gadgets, on the first line) moved its attacks down one line; a shown but
    // empty resource label (seen on cavalry) does not count, so both tests.
    const bool resourceRow = resourceShown && GadgetShown(Field<std::int32_t>(g_panel.panel, kResourceLabel));    for (int i = resourceRow ? 1 : 0; i < 3; ++i) {
      if (g_panel.stock[i].valid) {
        free.push_back({&g_panel.stock[i], i});
      }
    }
  }
  // An original row too long for its column (a Villero's ranged row with five multipliers reaches x ~600) runs under
  // the block gadget on its line: that gadget is left empty, and the rows go on in the next one (CharPixels per
  // character, an icon counting as two).
  std::vector<std::pair<Box, size_t>> stockLines;
  for (size_t n = 0; n < free.size() && n < rows.size(); ++n) {
    Box box;
    if (GadgetBox(free[n].gadget->handle, &box)) {
      stockLines.emplace_back(box, VisibleLength(rows[n]->label + L"  " + rows[n]->value));
    }
  }
  auto runsUnder = [&](const Gadget& gadget) {
    Box box;
    if (!GadgetBox(gadget.handle, &box)) {
      return false;
    }
    const int middle = (box.top + box.bottom) / 2;
    for (const auto& [line, chars] : stockLines) {
      if (middle > line.top && middle < line.bottom && box.left > line.left &&
          static_cast<float>(chars) * CharPixels(line) > static_cast<float>(box.left - line.left)) {
        return true;
      }
    }
    return false;
  };
  for (size_t k = 0; k < g_panel.big.size(); ++k) {
    if (runsUnder(g_panel.big[k])) {
      Hide(&g_panel.big[k]);
      continue;
    }
    if (!g_big.keep && Blocked(g_panel.big[k], blockers)) {
      Hide(&g_panel.big[k]);
      wchar_t name[160];
      swprintf_s(name, g_big.pattern.c_str(), g_big.first + static_cast<int>(k));
      *blockedNames += L" " + std::wstring(name);
    } else {
      free.push_back({&g_panel.big[k], -1});
    }
  }
  auto write = [](const Slot& slot, const std::wstring& text, std::uint32_t style, const std::wstring& tip) {
    if (slot.stock >= 0) {
      g_stockPlan[slot.stock] = {true, text, style, tip};
    } else {
      SetText(slot.gadget, text, style, tip);
    }
  };
  for (size_t n = 0; n < free.size(); ++n) {
    if (n >= rows.size()) {
      if (free[n].stock < 0) {
        Hide(free[n].gadget);
      }
      continue;  // an original row left empty stays hidden (its plan entry)
    }
    const StatRow& row = *rows[n];
    const std::uint32_t style = row.labelStyle == kAttackStyle ? kAttackStyle : kLabelStyle;
    if (n + 1 == free.size() && rows.size() > free.size()) {
      // One line: as many short rows as fit the gadget (a formatText wraps a longer text and centres it, which
      // would show a middle line), then "+N more"; the help text lists them all.
      const size_t budget = LineBudget(*free[n].gadget);
      std::wstring text;
      std::wstring tip;
      size_t shown = 0;
      for (size_t r = n; r < rows.size(); ++r) {
        const std::wstring part = Compact(*rows[r]);
        const size_t left = rows.size() - r - 1;
        const std::wstring more = left == 0 ? L"" : L" +" + std::to_wstring(left) + L" more";
        if (shown == 0 || VisibleLength(text + L"   " + part + more) <= budget) {
          text += (text.empty() ? L"" : L"   ") + part;
          ++shown;
        } else {
          text += L" +" + std::to_wstring(rows.size() - r) + L" more";
          break;
        }
      }
      for (size_t r = n; r < rows.size(); ++r) {
        tip += FullTip(*rows[r], tip.empty());
      }
      write(free[n], text, style, tip);
      continue;
    }
    std::wstring text = row.label;
    if (!row.value.empty()) {
      text += L"  " + row.value;
    }
    if (free[n].stock < 0 && VisibleLength(text) > LineBudget(*free[n].gadget)) {
      // Too long for its column ("Anti-artillery Crackshot Attack", a Spanish name): name and damage, the whole row
      // in the help text, rather than a row cut at the panel's edge.
      const std::wstring longer = Compact(row, true);
      write(free[n], VisibleLength(longer) <= LineBudget(*free[n].gadget) ? longer : Compact(row), style,
            FullTip(row, true));
      continue;
    }
    if (free[n].stock >= 0 && row.labelStyle == kAttackStyle) {
      text = FitMultipliers(text, *free[n].gadget);
    }
    write(free[n], text, style, row.tip);
  }
  ApplyStockPlan();
}

bool Applies(const Row& row, const char* proto) {
  if (row.types.empty()) {
    return true;
  }
  for (const TypeFilter* filter : row.types) {
    if (filter->id >= 0 && kProtoIsType(proto, filter->id)) {
      return true;
    }
  }
  return false;
}

std::wstring ResolveLabel(const std::wstring& label) {
  if (!label.empty() && label[0] == L'\x01') {
    return StringById(_wtoi(label.c_str() + 1));
  }
  return ExpandStrings(label);
}

// A text too wide for a line of `budget` characters (VisibleLength) cut in two lines at a space outside markup: of the
// cuts whose first part fits, the one that makes the two lines most even ("600 600 / 200 200", not "600 600 200 /
// 200"). The first part stays in `text`, the rest goes to `rest`. False when it fits, or no space does.
bool SplitToFit(std::wstring* text, std::wstring* rest, size_t budget) {
  if (VisibleLength(*text) <= budget) {
    return false;
  }
  size_t cut = std::wstring::npos;
  size_t best = static_cast<size_t>(-1);
  bool tag = false;
  for (size_t k = 0; k < text->size(); ++k) {
    const wchar_t c = (*text)[k];
    tag = c == L'<' ? true : (c == L'>' ? false : tag);
    if (c != L' ' || tag || k == 0) {
      continue;
    }
    const size_t first = VisibleLength(text->substr(0, k));
    const size_t second = VisibleLength(text->substr(k + 1));
    if (first <= budget && (std::max)(first, second) < best) {
      best = (std::max)(first, second);
      cut = k;
    }
  }
  if (cut == std::wstring::npos) {
    return false;
  }
  *rest = text->substr(cut + 1);
  text->resize(cut);
  return true;
}

// The last selection the rows were written for, and when.
std::int32_t g_lastUnitId = -1;
std::int32_t g_lastCount = -1;
std::int32_t g_lastStacks = -1;
std::int32_t g_lastBigIndex = -2;
ULONGLONG g_lastTick = 0;
constexpr ULONGLONG kRefreshMs = 250;
bool g_busy = false;

void __stdcall MinUiTail(char* panel, const char* selection, const char* unit, bool minimizedBlock) {
  if (g_busy) {
    return;
  }
  ResolvePanel(panel);
  if (!g_panel.any) {
    return;  // a layout without these gadgets: the normal interface, or one that does not use them
  }
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const std::int32_t unitId = unit == nullptr ? -1 : Field<std::int32_t>(unit, 0x10);
  const std::int32_t count = selection == nullptr ? 0 : Field<std::int32_t>(selection, 0x14);
  // The portraits move with the number of stacks and the current one.
  const std::int32_t stacks = g_stackReads ? Field<std::int32_t>(panel, kStackPlaced + 4) : 0;
  const std::int32_t bigIndex = g_stackReads ? Field<std::int32_t>(panel, kStackBigIndex) : 0;
  const ULONGLONG now = GetTickCount64();
  if (unitId == g_lastUnitId && count == g_lastCount && stacks == g_lastStacks && bigIndex == g_lastBigIndex &&
      now - g_lastTick < kRefreshMs) {
    // The panel's own fill wrote its original rows and labels again: the key's texts go back over them.
    if (minimizedBlock) {
      g_busy = true;
      ApplyStockPlan();
      ApplyStockLabels(unit);
      ApplyReplaces();
      g_busy = false;
    }
    return;
  }
  g_lastUnitId = unitId;
  g_lastCount = count;
  g_lastStacks = stacks;
  g_lastBigIndex = bigIndex;
  g_lastTick = now;
  g_busy = true;
  Blockers blockers;
  CollectBlockers(panel, &blockers);
  std::wstring blockedNames;
  // Each row's text first (empty: hidden), then the spills, then the writes.
  std::vector<std::wstring> texts(g_rows.size());
  std::vector<std::wstring> tips(g_rows.size());
  std::vector<bool> open(g_rows.size(), false);  // valid and not covered: the row is written or hidden this fill
  for (size_t i = 0; i < g_rows.size(); ++i) {
    Gadget& gadget = g_panel.rows[i];
    if (!gadget.valid) {
      continue;
    }
    if (!g_rows[i].keep && Blocked(gadget, blockers)) {
      Hide(&gadget);
      blockedNames += L" " + g_rows[i].gadget;
      continue;
    }
    open[i] = true;
    std::wstring value;
    const bool has = proto != nullptr && Applies(g_rows[i], proto) &&
                     (g_rows[i].item != nullptr ? g_rows[i].item->fn(unit, &value)
                                                : RenderTemplate(g_rows[i].text, unit, &value, g_rows[i].lines));
    if (has) {
      texts[i] = ResolveLabel(g_rows[i].label) + value;
      tips[i] = ResolveLabel(g_rows[i].tip);
    }
  }
  for (size_t i = 0; i < g_rows.size(); ++i) {
    const int j = g_rows[i].spillRow;
    if (j >= 0 && open[i] && open[j] && !texts[i].empty() && texts[j].empty()) {
      std::wstring rest;
      if (SplitToFit(&texts[i], &rest, LineBudget(g_panel.rows[i]))) {
        texts[j] = rest;
        tips[j] = tips[i];
      }
    }
  }
  for (size_t i = 0; i < g_rows.size(); ++i) {
    if (!open[i]) {
      continue;
    }
    if (texts[i].empty()) {
      Hide(&g_panel.rows[i]);
    } else {
      SetText(&g_panel.rows[i], texts[i], 0, tips[i]);
    }
  }
  if (!g_panel.big.empty()) {
    if (proto == nullptr || selection == nullptr || count <= 0) {
      for (Gadget& gadget : g_panel.big) {
        Hide(&gadget);
      }
      g_stockPlan.clear();
    } else {
      FillBigRows(selection, unit, minimizedBlock, blockers, &blockedNames);
    }
  }
  for (auto& state : g_panel.replaces) {
    state.active = minimizedBlock && state.row >= 0 && g_panel.rows[state.row].shown &&
                   !g_panel.rows[state.row].text.empty();
  }
  if (minimizedBlock && proto != nullptr) {
    ApplyStockLabels(unit);
    ApplyReplaces();
  }
  if (!blockedNames.empty() && !blockers.stack.empty()) {
    LogBlocked(blockers, blockedNames);
  }
  g_busy = false;
}

void OnDatabase(char*) {}

}  // namespace

namespace uhc {

Outcome ApplyMinUiStats(const Config& config) {
  const Config::Args* args = config.First("minUIStats");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (args->size() > 1) {
    Log(L"minUIStats: expected at most one argument, the rows file; feature not applied");
    return Outcome::kFailed;
  }
  if (!LoadRows(args->empty() ? std::string() : args->front())) {
    return Outcome::kFailed;
  }
  if (!VerifyAll("minUIStats",
                 {&sites::kStatFillHead, &sites::kStatFillMinGate, &sites::kMinResistsUnitGate, &sites::kMinBlockChoice,
                  &sites::kGadgetByName, &sites::kGadgetRef, &sites::kGadgetRelease, &sites::kGadgetShow,
                  &sites::kGadgetHide, &sites::kBStringFromWide, &sites::kBStringFromId, &sites::kBStringSet,
                  &sites::kBStringAssign, &sites::kBStringFree, &sites::kCurrentUnitRef, &sites::kMaxHitpointsGetter,
                  &sites::kLosGetterHead, &sites::kMaxContained, &sites::kIsA, &sites::kAttackListFill,
                  &sites::kResListGet, &sites::kResourceIconText, &sites::kHoldsResource, &sites::kMainResource,
                  &sites::kHeldAmount, &sites::kUnitCarryCapacity})) {
    return Outcome::kFailed;
  }
  // The build and regeneration items mirror stock code they never write to; they are checked apart, so another DLL
  // that changed that code turns off only these items (each checks its flag), not the key.
  g_buildReads = AllMatch({&sites::kBuildTickRateHead, &sites::kBuildTickScale, &sites::kBuildTickAdd,
                           &sites::kBuildPointsAddCall, &sites::kBuildPointsAdd, &sites::kBuilderFactor,
                           &sites::kRateLookupHead});
  g_regenReads = AllMatch({&sites::kRegenPlayerHead, &sites::kRegenRateRead});
  if (!g_buildReads || !g_regenReads) {
    Log(L"minUIStats: the stock %ls code is not what these items mirror; %ls left empty",
        !g_buildReads ? L"build tick" : L"regeneration", !g_buildReads ? L"buildTime, buildProgress, buildRate" : L"regen");
  }
  g_anyLookup = AllMatch({&sites::kGadgetLookupAny});
  // Where the stack portraits are is read from the panel after the fill placed them; checked apart too, so a
  // changed stack code only stops the rows from making room for the portraits.
  g_stackReads = AllMatch({&sites::kStackFillReset, &sites::kStackFillCurrent, &sites::kStackFillAppend,
                           &sites::kStackLayoutCall, &sites::kStackLayout, &sites::kGadgetLookupAny});
  if (!g_stackReads) {
    Log(L"minUIStats: the stock stack portrait code is not what the rows read; rows are not hidden under portraits");
  }
  g_attackReads = AllMatch({&sites::kStatFillRowCap, &sites::kAttackRowName, &sites::kAttackRowDamage,
                            &sites::kAttackRowTypeIcon, &sites::kAttackRowRange, &sites::kAttackRowSiege,
                            &sites::kAttackRowCold, &sites::kAttackRowModifier, &sites::kAttackRowTyped,
                            &sites::kActionRawName, &sites::kActionRangeEntry});
  if (!g_attackReads) {
    Log(L"minUIStats: the stock attack row code is not what the rows mirror; attacks past the 9th stat row left out");
  }
  g_abilityReads =
      AllMatch({&sites::kAbilityAvailableTest, &sites::kPowerUnitActionStore, &sites::kPowerUnitActionVtable});
  if (!g_abilityReads && g_filterAbilities) {
    Log(L"minUIStats: the stock ability code is not what the rows mirror; ability attacks shown on every unit");
  }
  // Building armor: the minimized block's resists show only for type Unit (0x698BF6). The gate goes only while the
  // armor test after it is stock: another DLL's armor there (a multiarmor of its own) writes a text made for units only
  // ("0 (null)" on a building), so then buildings keep the stock rule and show no resists row.
  const bool buildingArmor = AllMatch({&sites::kMinResistsArmorTest});
  g_armorOther = !buildingArmor;
  if (!buildingArmor) {
    Log(L"minUIStats: another DLL changed the resists armor test (0x698BFC); building armor not shown, unit armor as "
        L"that DLL writes it (the armor items answer nothing)");
  }
  // The projectiles per reload (projectilesIcon, the projectiles item): as the data writes them (the default), the key
  // registers the tag reader itself, with no effect on combat; as combat fires them (projectiles="combat"), they are
  // what numberOfShots fires, so its own reader is enough. Another DLL on the shared action tag site only leaves the
  // number out.
  const bool shotTags = !g_projectilesData || uhc::unitinfo::RequestShotTags();
  if (!shotTags) {
    Log(L"minUIStats: the action tags cannot be read; projectiles per reload not shown");
  }
  for (TypeFilter* filter : g_filters) {
    if (!RequestAbstractUnitType(filter->name.c_str(), &filter->id)) {
      return Outcome::kFailed;
    }
  }
  if (!RequestAbstractUnitType("Unit", &g_unitTypeId)) {  // the trainPoints item
    return Outcome::kFailed;
  }
  static const std::uint8_t kNops[6] = {0x90, 0x90, 0x90, 0x90, 0x90, 0x90};
  if (!WriteJmp(sites::kStatFillMinGate.va + 0x41, reinterpret_cast<const void*>(&UhcStatFillMinGate), 11) ||
      (buildingArmor && !WriteBytes(sites::kMinResistsUnitGate.va + 0x14, kNops, sizeof(kNops))) ||
      !AddUnitPanelTail(&MinUiTail) ||
      // After the tail hook, which verifies these bytes too: the minimized block also runs for a minimized layout
      // loaded without the profile option.
      !WriteJmp(sites::kMinBlockChoice.va, reinterpret_cast<const void*>(&UhcMinBlockChoice), 11)) {
    return Outcome::kFailed;
  }
  int refs = 0;
  for (const ItemInfo& item : kItems) {
    refs += AddDataRef(item.ref, kDataRefString, item.provider) ? 1 : 0;
  }
  Log(L"minUIStats: %u rows and %ls from %ls; %ls; %d data refs {uhc...} (UI only); rows give way to the stack "
      L"portraits and %u avoid gadgets; %u stock labels; attack rows: %ls, %ls, %ls, ability attacks %ls",
      static_cast<unsigned>(g_rows.size()), g_big.on ? L"the normal interface's stat rows" : L"no stat rows",
      g_file.c_str(), buildingArmor ? L"building armor shown in the minimized panel's resists" : L"no building armor",
      refs, static_cast<unsigned>(g_avoid.size()), static_cast<unsigned>(g_labels.size()),
      g_big.takeStock ? L"the original ones written by the key" : L"the original ones kept",
      g_big.rofIcon.empty() ? L"no ROF" : L"ROF after the damage",
      g_big.projectilesIcon.empty() ? L"no projectiles"
      : !shotTags                   ? L"no projectiles (tags not read)"
      : g_projectilesData           ? L"projectiles per reload after it (the tags as the data writes them)"
                                    : L"projectiles per reload after it (as numberOfShots fires them)",
      g_filterAbilities && g_abilityReads ? L"only when enabled" : L"all");
  Log(L"minUIStats: multipliers %ls; help text lines for ROF %ls and projectiles %ls",
      g_big.trimZeros ? L"without their trailing zeros" : L"as written", g_big.rofTip.empty() ? L"off" : L"on",
      g_big.projectilesTip.empty() ? L"off" : L"on");
  (void)&OnDatabase;
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/minuistats_hooks.asm

```asm
; minUIStats (features/minuistats.cpp): the stat panel fill's minimized-interface gate. Entered through a jmp written
; over the stock code; leaves through an explicit jmp to one of the two stock continuations.
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcMinUiForceFill:DWORD     ; 1 while minUIStats runs the fill for the minimized panel's rows

.data
statFillReturn  dd 004D81A1h    ; pop edi / ... / ret 4: the fill's end, stock with option 49h
statFillGo      dd 004D7267h    ; lea ecx,[esp+14h]: the first row
minBlockGo      dd 006987D7h    ; the selection panel's minimized block
panelTailGo     dd 004C8281h    ; the fill's tail (the shared tail hook, unitpanel.cpp)

.code

; Replaces 0x4C8276..0x4C8280 (cmp byte ptr [esp+5Eh],1 / je 6987D7h) in the selection panel fill FUN_004C7E52:
; byte [esp+5Eh] is profile option 49h, optionminimizedui. Stock runs the minimized block with the option on.
; This also runs it when the panel was built from a minimized layout with the option off (another DLL can force
; that layout without the option): the panel's unitHitPointsLabel handle [panel+2F0h] (bound at 0x9BAD77) is a real
; gadget only in the minimized layouts. The byte is then set to 1, as the block's way back and the tail read it.
; EAX is kept (the block and the tail reload what they use: EBX, the unit, is untouched); the flags are dead.
UhcMinBlockChoice PROC
    TRACE_ONCE "minUIStats minimized block choice (0x4C8276)"
    cmp byte ptr [esp+5Eh], 1
    je minimized
    push eax
    mov eax, dword ptr [esp+4+50h]      ; the panel
    mov eax, dword ptr [eax+2F0h]       ; its unitHitPointsLabel handle
    test eax, eax
    jz normal
    cmp eax, dword ptr ds:[00C672C0h]   ; the "no gadget" handle
    je normal
    pop eax
    mov byte ptr [esp+5Eh], 1
minimized:
    jmp minBlockGo
normal:
    pop eax
    jmp panelTailGo
UhcMinBlockChoice ENDP

; Replaces 0x4D725C..0x4D7266 (cmp byte ptr [esp+63h],1 / je 4D81A1h) in FUN_004D70ED: byte [esp+63h] is profile
; option 49h, optionminimizedui, read just above. Stock returns there; this goes on to the rows when the DLL asked
; for them (g_uhcMinUiForceFill), and otherwise does what stock does. Registers are untouched; the flags are dead
; at both continuations (lea, then the fill's own tests).
UhcStatFillMinGate PROC
    TRACE_ONCE "minUIStats stat fill gate (0x4D725C)"
    cmp byte ptr [esp+63h], 1
    jne go
    cmp g_uhcMinUiForceFill, 0
    jne go
    jmp statFillReturn
go:
    jmp statFillGo
UhcStatFillMinGate ENDP

END
```

## playerIcon

Contract: [playerIcon](../porting-to-another-dll.md#playericon).

Sites: `PlayerIconStringDtor` `0x4010CA` (7 B), `PlayerIconStringCtor` `0x401A12` (8 B), `PlayerIconCivPortrait` `0x774D56` (10 B), `PlayerIconSlotHandler` `0x776BED` (8 B), `PlayerIconAvatarCase` `0x776DEA` (10 B), `PlayerIconCallCiv` `0x776FFC` (5 B), `PlayerIconCallPersonality` `0x7773DD` (5 B), `PlayerIconSettingSet` `0xA26361` (11 B), `PlayerIconSettingGet` `0xA263C7` (15 B).

### src/features/playericon.cpp

```cpp
// playerIcon <avatarId>: the player's icon in a LAN lobby. The local player's slot gets the avatar <avatarId> of the
// data's avatar_*.xml tables, in place of the civ's portrait, and keeps it when the player changes civ.
//
// Stock already has the field: each lobby slot has a string setting GamePlayer<N>AvatarID, shared through the lobby
// settings like the civ (the setter sends it to the host, which sends it to every peer). When it changes, the slot's
// handler 0x776BED (case 0x776DEA) looks it up in the avatar table loaded from data\avatar_*.xml and puts the
// record's image on the slot's icon. ESO wrote it from the online profile; in a LAN game nothing writes it, and the
// civ portrait FUN_00774D56 sets on every civ change (and AI personality change) covers it again.
//
// The two calls of FUN_00774D56 (0x776FFC, after a civ change; 0x7773DD, after an AI personality change) go through
// a hook that runs it, then, for a slot that is not an AI's:
// - if the slot is the local player's ([slot+14h], the flag that enables its own controls) and its AvatarID is not
//   the cfg's value, writes it with the stock setter 0xA26361;
// - if its AvatarID is not empty, runs the slot's handler for that field again, so the avatar goes back over the civ
//   portrait. A name that is not in the table leaves the civ portrait, as stock does.
// AI slots ([slot+1Ch]) keep the civ portrait, as the stock handler does. A peer without this key shows another
// player's avatar when it has the same avatar_*.xml entry and texture, until that player's next civ change.
#include <windows.h>

#include <cstdint>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace uhc {
namespace {

// The game's string: a pointer to the characters, with its header 10h bytes before them.
struct GameString {
  wchar_t* text = nullptr;
};

using StringCtorFn = GameString*(__thiscall*)(GameString*, const wchar_t*);
using StringDtorFn = void(__thiscall*)(GameString*);
using SettingGetFn = bool(__thiscall*)(void* lobby, int id, GameString* out);
using SettingSetFn = bool(__thiscall*)(void* lobby, int id, const GameString* value);
using SlotHandlerFn = void(__thiscall*)(void* slot, void* settings, int id, int flags);

const auto kStringCtor = reinterpret_cast<StringCtorFn>(0x00401A12);
const auto kStringDtor = reinterpret_cast<StringDtorFn>(0x004010CA);
const auto kSettingGetString = reinterpret_cast<SettingGetFn>(0x00A263C7);
const auto kSettingSetString = reinterpret_cast<SettingSetFn>(0x00A26361);
const auto kSlotHandler = reinterpret_cast<SlotHandlerFn>(0x00776BED);

constexpr std::uint32_t kCivPortraitCallA = 0x00776FFC;
constexpr std::uint32_t kCivPortraitCallB = 0x007773DD;

// Slot of the lobby page: [+0Ch] the lobby settings, [+14h] the local player's slot, [+18h] its index (0..7),
// [+1Ch] an AI's slot. The lobby settings: [+8] the session, [+20h] the settings table.
// Setting ID of a player field: 3Ah + (index + 1) * 18h + field; AvatarID is field 10.
constexpr int kFieldAvatarId = 10;
constexpr int kHandlerFlags = 0x10;  // the flag the handler tests before it reads a field

std::wstring g_avatar;

std::wstring ReadString(void* lobby, int id) {
  GameString value;
  std::wstring text;
  if (kSettingGetString(lobby, id, &value) && value.text != nullptr) {
    text = value.text;
  }
  kStringDtor(&value);
  return text;
}

}  // namespace

extern "C" {

void __stdcall UhcPlayerIconAfterPortrait(std::uint8_t* slot) {
  void* const lobby = *reinterpret_cast<void**>(slot + 0x0C);
  if (lobby == nullptr || *reinterpret_cast<void**>(static_cast<std::uint8_t*>(lobby) + 8) == nullptr ||
      slot[0x1C] != 0) {
    return;
  }
  const int index = *reinterpret_cast<int*>(slot + 0x18);
  if (index < 0 || index >= 8) {
    return;
  }
  const int id = 0x3A + (index + 1) * 0x18 + kFieldAvatarId;
  std::wstring avatar = ReadString(lobby, id);
  if (slot[0x14] != 0 && avatar != g_avatar) {
    GameString value;
    kStringCtor(&value, g_avatar.c_str());
    kSettingSetString(lobby, id, &value);
    kStringDtor(&value);
    Log(L"playerIcon: player %d's AvatarID set to \"%ls\" (was \"%ls\")", index + 1, g_avatar.c_str(),
        avatar.c_str());
    avatar = g_avatar;
  }
  if (!avatar.empty()) {
    kSlotHandler(slot, *reinterpret_cast<void**>(static_cast<std::uint8_t*>(lobby) + 0x20), id, kHandlerFlags);
  }
}

void UhcPlayerIconHook();

}  // extern "C"

Outcome ApplyPlayerIcon(const Config& config) {
  const auto* args = config.First("playerIcon");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (args->size() != 1 || (*args)[0].empty() || (*args)[0].size() > 63) {
    Log(L"playerIcon: give one avatar ID (the id of an <avatar> in data\\avatar_*.xml), up to 63 characters");
    return Outcome::kFailed;
  }
  for (unsigned char c : (*args)[0]) {
    if (c < 0x21 || c > 0x7E) {
      Log(L"playerIcon: the avatar ID may hold only printable ASCII characters, no spaces");
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("playerIcon",
                 {&sites::kPlayerIconCallCiv, &sites::kPlayerIconCallPersonality, &sites::kPlayerIconCivPortrait,
                  &sites::kPlayerIconSlotHandler, &sites::kPlayerIconAvatarCase, &sites::kPlayerIconSettingGet,
                  &sites::kPlayerIconSettingSet, &sites::kPlayerIconStringCtor, &sites::kPlayerIconStringDtor})) {
    return Outcome::kFailed;
  }
  g_avatar.assign((*args)[0].begin(), (*args)[0].end());
  if (!WriteCall(kCivPortraitCallA, reinterpret_cast<const void*>(&UhcPlayerIconHook)) ||
      !WriteCall(kCivPortraitCallB, reinterpret_cast<const void*>(&UhcPlayerIconHook))) {
    return Outcome::kFailed;
  }
  Log(L"playerIcon: the local player's lobby icon is avatar \"%ls\"", g_avatar.c_str());
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/playericon_hooks.asm

```asm
; playerIcon (src/features/playericon.cpp). The two calls of the lobby slot's civ portrait FUN_00774D56 (0x776FFC and
; 0x7773DD, ECX = the slot) call this hook instead. It runs the stock function itself, then the helper, and returns
; to the caller with every register as the stock function left it.
.686
.model flat, c
option casemap :none

include common.inc

UhcPlayerIconAfterPortrait PROTO STDCALL slot:DWORD


.data
civPortrait dd 00774D56h   ; FUN_00774D56, the slot's civ portrait

.code

UhcPlayerIconHook PROC
    TRACE_ONCE "playerIcon civ portrait (0x776FFC / 0x7773DD)"
    push ecx
    call civPortrait             ; thiscall(slot), no arguments
    pop ecx
    pushfd
    pushad
    push ecx
    call UhcPlayerIconAfterPortrait
    popad
    popfd
    ret
UhcPlayerIconHook ENDP

END
```

## autoScout

Contract: [autoScout](../porting-to-another-dll.md#autoscout).

Besides the core helpers, it needs: [`worldtick.h`](helpers.md#world-tick).

Sites: `UnitById` `0x44CC6D` (58 B), `AutoScoutIdle` `0x44F1A7` (8 B), `AutoScoutSetTactic` `0x4F7ECD` (10 B), `AutoScoutDoMove` `0x50E36A` (10 B), `AutoScoutCmdExecute` `0x7C8E49` (10 B), `AutoScoutTacticIndex` `0x948161` (8 B).

### src/features/autoscout.cpp

```cpp
// autoScout [ScoutTactic [ReturnTactic]] [log]: a unit whose current tactic is ScoutTactic (default "AutoScout")
// explores the map on its own.
//
// The data decides who scouts: a unit gets the behaviour from a tactic of that name in its tactics file, and
// buttons that set it (unitSetTactic, a command every machine runs and saved games keep). A unit whose first
// tactic is the scouting one scouts from birth.
//
// After each world update (the shared wrapper of worldtick.cpp), every 500 ms of game time:
// - every unit of every player (the player's unit list [player+F8h], walked in ID order) whose current tactic
//   [[[proto+44h]+10h][[mgr+A8h]]+8] is the scouting tactic's name ID is a scout;
// - the player's visibility grid ([world+250h]: width +14h, height +18h, dword cells +20h, the player's mask
//   [[world+2D8h]+4*id]; low half explored, high half visible, 0x44E9FE) is summed in blocks of 8x8 cells;
// - a scout that is idle (0x44F1A7), or still on the move order it got from here, gets a new order when it has
//   none, or when its target became explored: the move order of the action manager 0x50E36A (the one the unit
//   order code gives, 0x9444D3), to the unexplored cell nearest to it that its movement type ([proto+1D2h]: 1
//   land, 2 water, 4 air) can stand on (water from the terrain's per-tile water lookup, vtable +194h), skipping
//   blocks another scout of the player has taken and blocks it could not reach, and weighing cells behind its
//   heading against them; the move sets action flag 17h, which the action manager's leash 0x489B15 skips;
// - a scout that stops with its target still unexplored, or is on one target for more than 90 s, gives that
//   block up (it could not get there); with nothing unexplored left in reach, it goes to the block not visible
//   now that was seen longest ago (by game time), the nearest first among equals;
// - a scout's leash anchor [mgr+7Ch] follows it, so that a unit that stops scouting stays where it is.
// Any other action (a fight, a flee) is left alone; the scout goes on once it is idle again.
//
// The switch-off: the head of the command execute 0x7C8E49 (hooks/autoscout_hooks.asm), which the world update
// runs for each command in turn, on every machine. A unit order (command type 0: move, attack, gather,
// garrison; type 9: stop) from the unit's owner to a scout that is not inside another unit first puts it in its
// return tactic (ReturnTactic, or the first tactic of its file that is not the scouting one) through the stock
// setTactic 0x4F7ECD, as the SetTactic command does (0x7D107C); then the order applies. Without that hook (another
// DLL owns the site) the key works without the switch-off, and the Stop-scouting button is the way out.
//
// Everything read is simulation state (no local player, no rendering), the time is the game time [world+108h],
// and the per-unit and per-player tables are only a cache: a loaded game rebuilds them from the units' tactics
// and the grid.
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../worldtick.h"

extern "C" void UhcAutoScoutCmdHook();

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr int kBlock = 8;                  // cells per block side
constexpr std::uint32_t kScanMs = 500;     // game time between scans
constexpr std::uint32_t kTargetMs = 90000; // a target taking longer than this is given up
constexpr int kMaxLogLines = 400;
constexpr int kMaxTries = 3;

struct Vec3 {
  float x, y, z;
};

using DoMoveFn = bool(__thiscall*)(char* mgr, const Vec3* point, float tolerance, char a3, char a4, std::int32_t a5,
                                   char a6, char a7, std::int32_t a8, std::int32_t a9, float a10);
using SetTacticFn = char(__thiscall*)(char* mgr, std::int32_t player, std::int32_t index, std::int32_t a3,
                                      std::int32_t a4, float a5, std::int32_t a6, std::int32_t a7);
using IdleFn = bool(__thiscall*)(const char* mgr);
using AliveFn = bool(__thiscall*)(const char* unit);
using WaterFn = std::uint8_t(__thiscall*)(const char* terrain, std::int32_t x, std::int32_t z);

const auto kDoMove = reinterpret_cast<DoMoveFn>(0x0050E36A);
const auto kSetTactic = reinterpret_cast<SetTacticFn>(0x004F7ECD);
const auto kIdle = reinterpret_cast<IdleFn>(0x0044F1A7);

std::wstring g_scoutName = L"AutoScout";
std::wstring g_returnName;
bool g_log = false;
bool g_switchOff = false;
int g_logLines = 0;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

void Note(const wchar_t* format, ...);

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

const char* Database() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

std::int32_t OwnerId(const char* unit) {
  const char* player = Field<const char*>(unit, 0x44);
  return player == nullptr ? -1 : Field<std::int32_t>(player, 0);
}

std::int32_t ProtoId(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  return proto == nullptr ? -1 : Field<std::int32_t>(proto, 8);
}

bool Alive(const char* unit) {
  const auto alive = reinterpret_cast<AliveFn>(Field<const void* const*>(unit, 0)[0xA4 / 4]);
  return alive(unit);
}

// ---- tactic names ----------------------------------------------------------------------------------------------

// The database's tactic names, [db+1FF0h] (count +1FF4h): the IDs a tactic's +8 holds (0x5E0CA6 looks one up).
std::int32_t g_scoutId = -1;
std::int32_t g_returnId = -1;
const char* g_namesDb = nullptr;
std::int32_t g_namesCount = -1;

std::int32_t FindName(const char* db, const std::wstring& name) {
  const char* names = Field<const char*>(db, 0x1FF0);
  const std::int32_t count = Field<std::int32_t>(db, 0x1FF4);
  for (std::int32_t i = 0; names != nullptr && i < count; ++i) {
    const wchar_t* text = Field<const wchar_t*>(names, 4 * i);
    if (text != nullptr && _wcsicmp(text, name.c_str()) == 0) {
      return i;
    }
  }
  return -1;
}

void ResolveNames() {
  const char* db = Database();
  if (db == nullptr) {
    return;
  }
  const std::int32_t count = Field<std::int32_t>(db, 0x1FF4);
  if (db == g_namesDb && count == g_namesCount) {
    return;
  }
  g_namesDb = db;
  g_namesCount = count;
  g_scoutId = FindName(db, g_scoutName);
  g_returnId = g_returnName.empty() ? -1 : FindName(db, g_returnName);
  Note(L"autoScout: %d tactic names; '%ls' is name %d%ls", count, g_scoutName.c_str(), g_scoutId,
       g_returnName.empty() ? L"" : (std::wstring(L", '") + g_returnName + L"' is name " +
                                     std::to_wstring(g_returnId)).c_str());
}

// The unit's tactics: the action set [proto+44h], its tactics +10h (count +14h); the current index [mgr+A8h].
std::int32_t TacticNameAt(const char* set, std::int32_t index) {
  if (set == nullptr || index < 0 || index >= Field<std::int32_t>(set, 0x14)) {
    return -1;
  }
  const char* tactic = Field<const char* const*>(set, 0x10)[index];
  return tactic == nullptr ? -1 : Field<std::int32_t>(tactic, 8);
}

bool Scouting(const char* unit) {
  if (g_scoutId < 0) {
    return false;
  }
  const char* mgr = Field<const char*>(unit, 0x58);
  const char* proto = Field<const char*>(unit, 0x5C);
  if (mgr == nullptr || proto == nullptr) {
    return false;
  }
  return TacticNameAt(Field<const char*>(proto, 0x44), Field<std::int32_t>(mgr, 0xA8)) == g_scoutId;
}

// The tactic a scout goes back to: ReturnTactic when the unit has it, else the first one that is not the scouting one.
std::int32_t ReturnIndex(const char* unit) {
  const char* set = Field<const char*>(Field<const char*>(unit, 0x5C), 0x44);
  if (set == nullptr) {
    return -1;
  }
  const std::int32_t count = Field<std::int32_t>(set, 0x14);
  if (g_returnId >= 0) {
    for (std::int32_t i = 0; i < count; ++i) {
      if (TacticNameAt(set, i) == g_returnId) {
        return i;
      }
    }
  }
  for (std::int32_t i = 0; i < count; ++i) {
    const std::int32_t name = TacticNameAt(set, i);
    if (name >= 0 && name != g_scoutId) {
      return i;
    }
  }
  return -1;
}

// ---- the grid --------------------------------------------------------------------------------------------------

enum Move { kLand = 0, kWater = 1, kAir = 2 };

struct Map {
  const char* world = nullptr;
  std::int32_t w = 0, h = 0;  // cells: x < w, z < h, index x * h + z
  float inv = 0.0f;           // cells per world unit, [terrain+1Ch]
  std::int32_t bw = 0, bh = 0;
  std::vector<std::uint8_t> water;              // per cell
  std::vector<std::int32_t> standCell[3];       // per block and movement: the cell nearest its centre one can stand on
};

Map g_map;

struct PlayerGrid {
  std::vector<std::int32_t> unexploredCell[3];  // per block and movement: an unexplored cell one can stand on, or -1
  std::vector<std::uint8_t> visible;            // per block: a cell of it is visible now
  std::vector<std::uint32_t> lastSeen;          // per block: the game time it was last visible
  std::int32_t unexplored = 0;                  // cells
};

std::map<std::int32_t, PlayerGrid> g_grids;

struct Scout {
  std::int32_t cell = -1;    // target cell
  std::int32_t block = -1;
  bool revisit = false;      // the target is a seen block, not an unexplored one
  std::uint32_t orderTime = 0;
  std::int32_t actionId = 0;
  bool interrupted = false;      // another action took over since the order
  bool moved = false;            // a heading is known
  float lastX = 0.0f, lastZ = 0.0f, headX = 0.0f, headZ = 0.0f;
  std::set<std::int32_t> given;  // blocks this unit could not reach
};

std::map<std::int32_t, Scout> g_scouts;
std::uint32_t g_lastScan = 0;
std::uint32_t g_lastTime = 0;
const char* g_lastWorld = nullptr;

std::int32_t BlockOf(std::int32_t cell) {
  const std::int32_t x = cell / g_map.h;
  const std::int32_t z = cell % g_map.h;
  return (x / kBlock) * g_map.bh + z / kBlock;
}

bool CanStand(std::int32_t cell, int move) {
  if (move == kAir) {
    return true;
  }
  return (g_map.water[cell] != 0) == (move == kWater);
}

bool BuildMap(const char* world) {
  const char* vm = Field<const char*>(world, 0x250);
  const char* terrain = Field<const char*>(world, 0x88);
  if (vm == nullptr || terrain == nullptr || Field<const void*>(vm, 0x20) == nullptr) {
    return false;
  }
  const std::int32_t w = Field<std::int32_t>(vm, 0x14);
  const std::int32_t h = Field<std::int32_t>(vm, 0x18);
  const float inv = Field<float>(terrain, 0x1C);
  if (w <= 0 || h <= 0 || w > 4096 || h > 4096 || !(inv > 0.0f)) {
    return false;
  }
  if (g_map.world == world && g_map.w == w && g_map.h == h) {
    return true;
  }
  g_map = Map{};
  g_map.world = world;
  g_map.w = w;
  g_map.h = h;
  g_map.inv = inv;
  g_map.bw = (w + kBlock - 1) / kBlock;
  g_map.bh = (h + kBlock - 1) / kBlock;
  g_map.water.assign(static_cast<std::size_t>(w) * h, 0);
  const auto water = reinterpret_cast<WaterFn>(Field<const void* const*>(terrain, 0)[0x194 / 4]);
  std::int32_t wet = 0;
  for (std::int32_t x = 0; x < w; ++x) {
    for (std::int32_t z = 0; z < h; ++z) {
      if (water(terrain, x, z) != 0xFF) {
        g_map.water[x * h + z] = 1;
        ++wet;
      }
    }
  }
  const std::size_t blocks = static_cast<std::size_t>(g_map.bw) * g_map.bh;
  for (int move = 0; move < 3; ++move) {
    g_map.standCell[move].assign(blocks, -1);
    for (std::int32_t bx = 0; bx < g_map.bw; ++bx) {
      for (std::int32_t bz = 0; bz < g_map.bh; ++bz) {
        const float cx = bx * kBlock + kBlock / 2.0f;
        const float cz = bz * kBlock + kBlock / 2.0f;
        float best = 1e30f;
        for (std::int32_t x = bx * kBlock; x < std::min(w, (bx + 1) * kBlock); ++x) {
          for (std::int32_t z = bz * kBlock; z < std::min(h, (bz + 1) * kBlock); ++z) {
            const std::int32_t cell = x * h + z;
            const float d = (x + 0.5f - cx) * (x + 0.5f - cx) + (z + 0.5f - cz) * (z + 0.5f - cz);
            if (CanStand(cell, move) && d < best) {
              best = d;
              g_map.standCell[move][bx * g_map.bh + bz] = cell;
            }
          }
        }
      }
    }
  }
  g_grids.clear();
  Note(L"autoScout: map of %d x %d cells (%.2f per metre), %d water cells, %d x %d blocks", w, h,
       static_cast<double>(inv), wet, g_map.bw, g_map.bh);
  return true;
}

// The player's grid in blocks, from the visibility cells.
void Summarize(const char* world, std::int32_t player, std::uint32_t now) {
  PlayerGrid& grid = g_grids[player];
  const std::size_t blocks = static_cast<std::size_t>(g_map.bw) * g_map.bh;
  if (grid.lastSeen.size() != blocks) {
    grid.lastSeen.assign(blocks, 0);
  }
  grid.visible.assign(blocks, 0);
  for (auto& cells : grid.unexploredCell) {
    cells.assign(blocks, -1);
  }
  grid.unexplored = 0;
  const std::int32_t masks = Field<std::int32_t>(world, 0x2DC);
  if (player >= masks) {
    return;
  }
  const std::uint32_t mask = Field<const std::uint32_t*>(world, 0x2D8)[player];
  const std::uint32_t* cells = Field<const std::uint32_t*>(Field<const char*>(world, 0x250), 0x20);
  const std::int32_t w = g_map.w;
  const std::int32_t h = g_map.h;
  for (std::int32_t x = 0; x < w; ++x) {
    const std::int32_t bx = x / kBlock;
    for (std::int32_t z = 0; z < h; ++z) {
      const std::int32_t cell = x * h + z;
      const std::uint32_t bits = cells[cell] & mask;
      const std::int32_t block = bx * g_map.bh + z / kBlock;
      if ((bits & 0xFFFF0000u) != 0) {
        grid.visible[block] = 1;
      }
      if ((bits & 0xFFFFu) != 0) {
        continue;
      }
      ++grid.unexplored;
      for (int move = 0; move < 3; ++move) {
        if (grid.unexploredCell[move][block] < 0 && CanStand(cell, move)) {
          grid.unexploredCell[move][block] = cell;
        }
      }
    }
  }
  for (std::size_t b = 0; b < blocks; ++b) {
    if (grid.visible[b] != 0) {
      grid.lastSeen[b] = now;
    }
  }
}

bool Explored(const char* world, std::int32_t player, std::int32_t cell) {
  if (player >= Field<std::int32_t>(world, 0x2DC)) {
    return true;
  }
  const std::uint32_t mask = Field<const std::uint32_t*>(world, 0x2D8)[player];
  const std::uint32_t* cells = Field<const std::uint32_t*>(Field<const char*>(world, 0x250), 0x20);
  return (cells[cell] & mask & 0xFFFFu) != 0;
}

Vec3 CellPoint(std::int32_t cell, float y) {
  return Vec3{(cell / g_map.h + 0.5f) / g_map.inv, y, (cell % g_map.h + 0.5f) / g_map.inv};
}

int MoveOf(const char* unit) {
  switch (Field<std::uint8_t>(Field<const char*>(unit, 0x5C), 0x1D2)) {
    case 2:
      return kWater;
    case 4:
      return kAir;
    default:
      return kLand;
  }
}

const wchar_t* MoveName(int move) { return move == kAir ? L"air" : move == kWater ? L"water" : L"land"; }

// The target for a scout: the nearest unexplored cell it can stand on, in a block no other scout of the player
// holds and it has not given up; else the reachable block not visible now that was seen longest ago.
bool PickTarget(const char* world, std::int32_t player, const char* unit, Scout& scout,
                const std::set<std::int32_t>& taken, const PlayerGrid& grid) {
  const int move = MoveOf(unit);
  const float ux = Field<float>(unit, 0x14) * g_map.inv;
  const float uz = Field<float>(unit, 0x1C) * g_map.inv;
  const std::size_t blocks = grid.visible.size();
  // The squared distance in cells, up to 4.8 times more for a cell behind the unit's heading: a scout keeps going
  // the way it goes rather than zigzag between two frontiers.
  auto distance = [&](std::int32_t cell) {
    const float dx = cell / g_map.h + 0.5f - ux;
    const float dz = cell % g_map.h + 0.5f - uz;
    const float d2 = dx * dx + dz * dz;
    if (!scout.moved || d2 < 1e-6f) {
      return d2;
    }
    const float bias = 1.6f - 0.6f * (dx * scout.headX + dz * scout.headZ) / std::sqrt(d2);
    return d2 * bias * bias;
  };
  std::int32_t best = -1;
  float bestDistance = 0.0f;
  for (std::size_t b = 0; b < blocks; ++b) {
    const std::int32_t cell = grid.unexploredCell[move][b];
    if (cell < 0 || taken.count(static_cast<std::int32_t>(b)) != 0 || scout.given.count(static_cast<std::int32_t>(b)) != 0) {
      continue;
    }
    const float d = distance(cell);
    if (best < 0 || d < bestDistance) {
      best = cell;
      bestDistance = d;
    }
  }
  if (best >= 0) {
    // The nearest unexplored cell of that block it can stand on.
    const std::int32_t block = BlockOf(best);
    const std::int32_t bx = block / g_map.bh;
    const std::int32_t bz = block % g_map.bh;
    float nearest = distance(best);
    for (std::int32_t x = bx * kBlock; x < std::min(g_map.w, (bx + 1) * kBlock); ++x) {
      for (std::int32_t z = bz * kBlock; z < std::min(g_map.h, (bz + 1) * kBlock); ++z) {
        const std::int32_t cell = x * g_map.h + z;
        if (CanStand(cell, move) && !Explored(world, player, cell) && distance(cell) < nearest) {
          nearest = distance(cell);
          best = cell;
        }
      }
    }
    scout.cell = best;
    scout.block = block;
    scout.revisit = false;
    return true;
  }
  std::uint32_t oldest = 0;
  for (std::size_t b = 0; b < blocks; ++b) {
    const std::int32_t cell = g_map.standCell[move][b];
    if (cell < 0 || grid.visible[b] != 0 || taken.count(static_cast<std::int32_t>(b)) != 0 ||
        scout.given.count(static_cast<std::int32_t>(b)) != 0) {
      continue;
    }
    const float d = distance(cell);
    if (best < 0 || grid.lastSeen[b] < oldest || (grid.lastSeen[b] == oldest && d < bestDistance)) {
      best = cell;
      oldest = grid.lastSeen[b];
      bestDistance = d;
    }
  }
  if (best < 0) {
    if (!scout.given.empty()) {
      scout.given.clear();  // everything was given up: try them again on the next scan
    }
    return false;
  }
  scout.cell = best;
  scout.block = BlockOf(best);
  scout.revisit = true;
  return true;
}

// The action manager's anchor [mgr+7Ch] (x, y, z), where its leash 0x489B15 walks a unit back to when its current
// action has no order and it strays too far (0x489C34 -> 0x50E50E: a move with tolerance 1.0). A scout's anchor
// follows it, so a unit that stops scouting stays where it is instead of walking back to where it was last ordered.
void SetAnchor(char* unit) {
  char* mgr = Field<char*>(unit, 0x58);
  for (std::uint32_t i = 0; i < 3; ++i) {
    *reinterpret_cast<float*>(mgr + 0x7C + 4 * i) = Field<float>(unit, 0x14 + 4 * i);
  }
}

std::int32_t CurrentActionId(const char* mgr) {
  const char* action = Field<const char*>(mgr, 0x24);
  return action == nullptr ? 0 : Field<std::int32_t>(action, 8);
}

void Order(const char* world, char* unit, std::int32_t id, std::int32_t player, Scout& scout,
           std::set<std::int32_t>& taken, const PlayerGrid& grid, std::uint32_t now) {
  char* mgr = Field<char*>(unit, 0x58);
  for (int tries = 0; tries < kMaxTries; ++tries) {
    if (!PickTarget(world, player, unit, scout, taken, grid)) {
      scout.cell = -1;
      return;
    }
    const Vec3 point = CellPoint(scout.cell, Field<float>(unit, 0x18));
    // a4 = 1 sets the move action's flag 17h, which the action manager's leash 0x489B15 honours (0x4B95E4): without
    // it the unit is walked back to its anchor [mgr+7Ch] every few seconds.
    const bool ok = kDoMove(mgr, &point, 0.1f, 0, 1, -1, 0, 0, -1, -1, -1.0f);
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"autoScout: unit %d (proto %d, player %d, %ls) at (%.1f, %.1f) -> %ls cell (%.1f, %.1f), block %d: %ls",
               id, ProtoId(unit), player, MoveName(MoveOf(unit)), static_cast<double>(Field<float>(unit, 0x14)),
               static_cast<double>(Field<float>(unit, 0x1C)), scout.revisit ? L"seen" : L"unexplored",
               static_cast<double>(point.x), static_cast<double>(point.z), scout.block, ok ? L"ordered" : L"refused");
    }
    if (ok) {
      scout.orderTime = now;
      scout.actionId = CurrentActionId(mgr);
      scout.interrupted = false;
      taken.insert(scout.block);
      return;
    }
    scout.given.insert(scout.block);
    scout.cell = -1;
  }
}

void Forget() {
  g_scouts.clear();
  g_grids.clear();
  g_map = Map{};
  g_lastScan = 0;
}

void Scan(char* world, std::uint32_t now);

void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_lastWorld || now < g_lastTime) {
    Forget();
    g_lastWorld = world;
  }
  g_lastTime = now;
  if (now - g_lastScan < kScanMs && g_lastScan != 0) {
    return;
  }
  g_lastScan = now == 0 ? 1 : now;
  if (!g_log) {
    Scan(world, now);
    return;
  }
  // With log: the cost of the scans, every 120 of them (a real clock, for the log only: it feeds nothing back).
  static int scans = 0;
  static double total = 0.0, longest = 0.0;
  const auto start = std::chrono::steady_clock::now();
  Scan(world, now);
  const double us = std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - start).count();
  total += us;
  longest = std::max(longest, us);
  if (++scans == 120) {
    uhc::Log(L"autoScout: 120 scans, %.0f us on average, %.0f us the longest, %zu scout(s), %d x %d cells",
             total / scans, longest, g_scouts.size(), g_map.w, g_map.h);
    scans = 0;
    total = longest = 0.0;
  }
}

void Scan(char* world, std::uint32_t now) {
  ResolveNames();
  if (g_scoutId < 0 || !BuildMap(world)) {
    return;
  }

  // The scouts, by player then by ID.
  std::map<std::int32_t, std::vector<std::int32_t>> scouts;
  const std::int32_t players = Field<std::int32_t>(world, 0x5C);
  for (std::int32_t p = 1; p < players; ++p) {
    const char* player = Field<const char* const*>(world, 0x58)[p];
    if (player == nullptr) {
      continue;
    }
    const std::int32_t* ids = Field<const std::int32_t*>(player, 0xF8);
    const std::int32_t count = Field<std::int32_t>(player, 0xFC);
    for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
      const char* unit = UnitById(world, ids[i]);
      if (unit != nullptr && OwnerId(unit) == p && Scouting(unit) && Alive(unit)) {
        scouts[p].push_back(ids[i]);
      }
    }
  }
  for (auto it = g_scouts.begin(); it != g_scouts.end();) {
    const char* unit = UnitById(world, it->first);
    const auto list = unit == nullptr ? scouts.end() : scouts.find(OwnerId(unit));
    if (list == scouts.end() || !std::binary_search(list->second.begin(), list->second.end(), it->first)) {
      it = g_scouts.erase(it);
    } else {
      ++it;
    }
  }
  for (auto& [player, ids] : scouts) {
    std::sort(ids.begin(), ids.end());
    Summarize(world, player, now);
    const PlayerGrid& grid = g_grids[player];
    std::set<std::int32_t> taken;
    for (const std::int32_t id : ids) {
      const auto found = g_scouts.find(id);
      if (found != g_scouts.end() && found->second.cell >= 0) {
        taken.insert(found->second.block);
      }
    }
    for (const std::int32_t id : ids) {
      char* unit = UnitById(world, id);
      if (Field<std::int32_t>(unit, 0x6C) != -1) {
        continue;  // inside another unit
      }
      Scout& scout = g_scouts[id];
      SetAnchor(unit);
      const float x = Field<float>(unit, 0x14);
      const float z = Field<float>(unit, 0x1C);
      const float step = std::hypot(x - scout.lastX, z - scout.lastZ);
      if (step > 1.0f) {
        if (scout.lastX != 0.0f || scout.lastZ != 0.0f) {
          scout.headX = (x - scout.lastX) / step;
          scout.headZ = (z - scout.lastZ) / step;
          scout.moved = true;
        }
        scout.lastX = x;
        scout.lastZ = z;
      }
      const char* mgr = Field<const char*>(unit, 0x58);
      const bool idle = kIdle(mgr);
      const bool ours = !idle && scout.actionId != 0 && CurrentActionId(mgr) == scout.actionId;
      if (!idle && !ours) {
        scout.interrupted = true;  // another action (a flee, a fight): leave it, scout again once it is idle
        continue;
      }
      bool order = scout.cell < 0;
      if (scout.cell >= 0) {
        const bool explored = !scout.revisit && Explored(world, player, scout.cell);
        const bool late = now - scout.orderTime > kTargetMs;
        if (explored || (scout.revisit && grid.visible[scout.block] != 0)) {
          order = true;
        } else if (idle && scout.interrupted) {
          order = true;  // it stopped for another reason: the same target is still good
        } else if (idle || late) {
          scout.given.insert(scout.block);  // it stopped short of its target: out of its reach
          if (g_log && g_logLines < kMaxLogLines) {
            ++g_logLines;
            const Vec3 point = CellPoint(scout.cell, 0.0f);
            uhc::Log(L"autoScout: unit %d stopped at (%.1f, %.1f), %.1f m from its target (%.1f, %.1f)%ls: block %d given up",
                     id, static_cast<double>(Field<float>(unit, 0x14)), static_cast<double>(Field<float>(unit, 0x1C)),
                     static_cast<double>(std::hypot(Field<float>(unit, 0x14) - point.x, Field<float>(unit, 0x1C) - point.z)),
                     static_cast<double>(point.x), static_cast<double>(point.z), late ? L" (too long)" : L"",
                     scout.block);
          }
          order = true;
        }
        if (order) {
          taken.erase(scout.block);
          scout.cell = -1;
        }
      }
      if (order) {
        Order(world, unit, id, player, scout, taken, grid, now);
      }
    }
  }
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

}  // namespace

// From the hook at the head of the command execute, on every machine, in the world update: a unit order from the
// owner puts a scout back in its return tactic before the order applies.
extern "C" void __stdcall UhcAutoScoutCommand(const char* command) {
  if (command == nullptr || g_scoutId < 0) {
    return;
  }
  const std::uint8_t type = Field<std::uint8_t>(command, 0x81);
  if (type != 0 && type != 9) {
    return;
  }
  const char* world = World();
  if (world == nullptr) {
    return;
  }
  const std::int32_t player = Field<std::int32_t>(command, 0x20);
  const std::int32_t* ids = Field<const std::int32_t*>(command, 0x40);
  const std::int32_t count = Field<std::int32_t>(command, 0x44);
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    char* unit = UnitById(world, ids[i]);
    if (unit == nullptr || OwnerId(unit) != player || Field<std::int32_t>(unit, 0x6C) != -1 || !Scouting(unit)) {
      continue;
    }
    const std::int32_t index = ReturnIndex(unit);
    if (index < 0) {
      continue;
    }
    SetAnchor(unit);
    kSetTactic(Field<char*>(unit, 0x58), player, index, -1, 1, -1.0f, 1, 0);
    g_scouts.erase(ids[i]);
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"autoScout: unit %d (proto %d, player %d) got an order (command type %u): back to tactic %d", ids[i],
               ProtoId(unit), player, static_cast<unsigned>(type), index);
    }
  }
}

namespace uhc {

Outcome ApplyAutoScout(const Config& config) {
  const Config::Args* args = config.First("autoScout");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  int names = 0;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    const bool valid = !arg.empty() && std::all_of(arg.begin(), arg.end(), [](char c) {
      return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_';
    });
    if (!valid || names == 2) {
      Log(L"autoScout: bad argument %hs (expected [ScoutTactic [ReturnTactic]] [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    (names == 0 ? g_scoutName : g_returnName) = std::wstring(arg.begin(), arg.end());
    ++names;
  }
  if (!VerifyAll("autoScout", {&sites::kAutoScoutDoMove, &sites::kAutoScoutSetTactic, &sites::kAutoScoutTacticIndex,
                               &sites::kAutoScoutIdle, &sites::kUnitById})) {
    return Outcome::kFailed;
  }
  if (Matches(sites::kAutoScoutCmdExecute)) {
    if (!WriteJmp(sites::kAutoScoutCmdExecute.va, reinterpret_cast<const void*>(&UhcAutoScoutCmdHook), 8)) {
      return Outcome::kFailed;
    }
    g_switchOff = true;
  }
  if (!AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  Log(L"autoScout: units in tactic '%ls' explore the map on their own%ls (multiplayer unverified)", g_scoutName.c_str(),
      g_returnName.empty() ? L"" : (std::wstring(L"; they go back to '") + g_returnName + L"'").c_str());
  if (!g_switchOff) {
    Log(L"autoScout: limited mode: the command execute head 0x7C8E49 is not stock (another DLL patched it), so an order "
        L"does not switch scouting off; use the Stop-scouting button");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/autoscout_hooks.asm

```asm
; autoScout (src/features/autoscout.cpp). Entered through a jmp written over the stock code; it leaves
; through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcAutoScoutCommand PROTO STDCALL command:DWORD

.data
cmdExecuteNext dd 007C8E51h   ; jbe 7C8E85h, after the four instructions this hook re-executes

.code

; Replaces 0x7C8E49..0x7C8E50 (push ecx / push esi / mov esi,ecx / cmp dword [esi+5Ch],5), the head of the
; command execute FUN_007C8E49, thiscall(cmd), called once per command by the world update's command
; processing (0x64D31A, inside 0x490015, called at 0x481BC2): the simulation, on every machine, in the
; same order. On entry ECX = the command. UhcAutoScoutCommand (stdcall, keeps EBX, ESI, EDI, EBP) looks at
; the command first: a unit order (move, attack, garrison, stop) to a unit in the scouting tactic puts that
; unit back in its other tactic before the order applies. Then the stock head runs, and the jbe at
; 0x7C8E51 takes the flags of its cmp.
UhcAutoScoutCmdHook PROC
    TRACE_ONCE "autoScout command (0x7C8E49)"
    push eax
    push ecx
    push edx
    push ecx                        ; the command
    call UhcAutoScoutCommand
    pop edx
    pop ecx
    pop eax
    push ecx
    push esi
    mov esi, ecx
    cmp dword ptr [esi+5Ch], 5
    jmp cmdExecuteNext
UhcAutoScoutCmdHook ENDP

END
```

## transformChecks

Contract: [transformChecks](../porting-to-another-dll.md#transformchecks).

Sites: `BStringAppend` `0x443960` (16 B), `CostListCtor` `0x44717F` (9 B), `CostListDtor` `0x44C817` (11 B), `PlayerById` `0x44CB21` (30 B), `UnitById` `0x44CC6D` (58 B), `PlayerProtoEntry` `0x45311B` (8 B), `CurrentSelectionGroup` `0x453B28` (33 B), `NpButton` `0x462317` (13 B), `BuildLimitEntry` `0x4C7B5F` (5 B), `BStringFromId` `0x58EA52` (25 B), `ProtoByName` `0x5A2346` (32 B), `XformExecBody` `0x7D652D` (190 B), `XformPlaceTest` `0x7D65E3` (15 B), `XformRefuse` `0x7D6762` (9 B), `PayAffordCheck` `0x8D6BAE` (30 B), `PaySharedAffordCheck` `0x8D6C1B` (26 B).

### src/features/transformchecks.cpp

```cpp
// transformChecks [log]: transform buttons (uiTransformSelectedUnit) grey out with the reason when no selected unit
// can transform, and a transform respects the target's build limit.
//
// Stock: uiTransformSelectedUnit("Proto") (0x7E7193) sends a network command (type 17h) for the selection. Every
// machine runs its per-unit execute FUN_007D64F7 for each selected unit on its own: the player's copy of the target
// proto and its cost (0x480B1E); the unit alive and its owner the command's player; the world placement check PLACE
// (world vtable +14h, FUN_0050703D) with the target proto at the unit's position, which applies the target's
// PlacementFile rules (a distanceatmostfromtype from a kraal too) and its AllowedAge; the payment 0x8D946A (or the
// "not enough resources" message); the new unit, built, at the unit's place; the old unit removed. Nothing tests the
// target's BuildLimit, and a refused unit gives no sign: the button is always enabled, and a click that fails does
// nothing.
//
// The key:
// - in the simulation (hooks/transformchecks_hooks.asm, at 0x7D65E3 after PLACE succeeded): a target whose limit
//   (0x4C7B5F on the player's copy) the player's living units of that proto already reach is refused as PLACE
//   refuses it (0x7D6762), before the payment. The count walks the player's unit list [player+F8h] (count +FCh): the
//   same on every machine, and units transformed earlier in the same command count, since each is created at once;
// - in the command panel (the shared button hook, panelbuttons.h): a button whose command is
//   uiTransformSelectedUnit("Proto") (its click, or the record's command for a click commandResearch(ID, unit), the
//   form a command with an <associatedtech> takes) asks, for each of the local player's selected units, the checks
//   the command makes (the cost of that many units and its affordability 0x8D6BAE / 0x8D6C1B, the build limit,
//   PLACE with the same arguments). With no
//   unit that passes, the button is disabled, its click and shift-click emptied, and its rollover gets the reason in
//   red: the failing placement rule's error string when PLACE gives one, else "Other objects prevent you..." (25528),
//   "Not enough resources" (41543) or the build limit (36198). With some that pass, the rollover says how many. The
//   answer is kept 250 ms per button (real time): the panel is interface only, so nothing here reaches the game.
#include <windows.h>

#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <map>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../panelbuttons.h"
#include "../patch.h"

extern "C" void UhcXformPlaceHook();

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database, +3C0h the local player
constexpr DWORD kCacheMs = 250;
constexpr int kMaxLogLines = 200;

using PlayerByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using UnitByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using PlayerProtoFn = char*(__thiscall*)(const char* player, std::int32_t protoId);
using ProtoByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using BuildLimitFn = std::int32_t(__thiscall*)(const char* player, const char* proto);
using CostListFn = void(__thiscall*)(void* list);
using CostGetFn = bool(__thiscall*)(const char* player, std::int32_t protoId, void* cost, std::int32_t count);
using AffordFn = bool(__thiscall*)(const char* player, const void* cost);
using SelectionFn = const char*(__cdecl*)();
using AliveFn = bool(__thiscall*)(const char* unit);
using PlaceFn = bool(__thiscall*)(const char* world, std::int32_t protoId, std::int32_t playerId, const float* pos,
                                  const float* forward, const float* right, std::int32_t a5, std::int32_t flags,
                                  std::int32_t* reason, std::int32_t a8, std::int32_t a9, std::int32_t a10);
using BStringFromIdFn = void*(__thiscall*)(void* text, std::int32_t id);
using BStringFreeFn = void(__thiscall*)(void* text);
using AppendFn = void(__thiscall*)(void* text, const wchar_t* more, std::int32_t length, std::int32_t start);

const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kProtoByName = reinterpret_cast<ProtoByNameFn>(0x005A2346);
const auto kBuildLimit = reinterpret_cast<BuildLimitFn>(0x004C7B5F);
const auto kCostCtor = reinterpret_cast<CostListFn>(0x0044717F);
const auto kCostDtor = reinterpret_cast<CostListFn>(0x0044C817);
const auto kCostGet = reinterpret_cast<CostGetFn>(0x00480B1E);
const auto kAfford = reinterpret_cast<AffordFn>(0x008D6BAE);
const auto kSharedAfford = reinterpret_cast<AffordFn>(0x008D6C1B);
const auto kSelection = reinterpret_cast<SelectionFn>(0x00453B28);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kAppend = reinterpret_cast<AppendFn>(0x00443960);

constexpr std::int32_t kStringObjects = 25528;      // "Other objects prevent you from placing this here."
constexpr std::int32_t kStringResources = 41543;    // "Not enough resources"
constexpr std::int32_t kStringBuildLimit = 36198;   // "You are at the build limit for the %s."
constexpr std::uint32_t kProtoDisplayName = 0x140;  // the proto's DisplayNameID (read in game)

bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

bool Alive(const char* unit) {
  const auto alive = reinterpret_cast<AliveFn>(Field<const void* const*>(unit, 0)[0xA4 / 4]);
  return alive(unit);
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

// The player's living units of a proto ID: its unit list [player+F8h] (IDs, count +FCh).
std::int32_t CountLiving(const char* world, const char* player, std::int32_t protoId) {
  const auto* ids = Field<const std::int32_t*>(player, 0xF8);
  const std::int32_t count = Field<std::int32_t>(player, 0xFC);
  std::int32_t living = 0;
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    const char* unit = kUnitById(world, ids[i]);
    const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    if (proto != nullptr && Field<std::int32_t>(proto, 8) == protoId && Alive(unit)) {
      ++living;
    }
  }
  return living;
}

// The limit left for the player's copy of a proto: -1 when it has none.
std::int32_t LimitLeft(const char* world, const char* player, const char* playerProto) {
  const std::int32_t limit = kBuildLimit(player, playerProto);
  if (limit < 0) {
    return -1;
  }
  const std::int32_t left = limit - CountLiving(world, player, Field<std::int32_t>(playerProto, 8));
  return left < 0 ? 0 : left;
}

std::wstring StringById(std::int32_t id) {
  struct BString {
    const wchar_t* text;
  } text{nullptr};
  kBStringFromId(&text, id);
  std::wstring copy = text.text == nullptr ? L"" : text.text;
  kBStringFree(&text);
  return copy;
}

// ---- The command panel --------------------------------------------------------------------------------------------

struct Verdict {
  std::int32_t total = 0;  // the local player's selected units
  std::int32_t pass = 0;   // those that would transform
  std::wstring reason;     // why the first refused one is refused
};

struct Cached {
  DWORD at = 0;
  std::string selection;  // the selection's player and IDs when it was asked
  Verdict verdict;
};
std::map<std::string, Cached> g_cache;  // by target name

std::string SelectionKey(const char* selection) {
  std::string key;
  if (selection == nullptr) {
    return key;
  }
  const std::int32_t count = Field<std::int32_t>(selection, 0x14);
  const auto* ids = Field<const std::int32_t*>(selection, 0x10);
  key.append(reinterpret_cast<const char*>(selection + 0x0C), 4);
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    key.append(reinterpret_cast<const char*>(&ids[i]), 4);
  }
  return key;
}

Verdict Judge(const std::string& name) {
  Verdict verdict;
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* db = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  const char* selection = kSelection();
  if (world == nullptr || db == nullptr || selection == nullptr) {
    return verdict;
  }
  const std::int32_t local = Field<std::int32_t>(game, 0x3C0);
  if (Field<std::int32_t>(selection, 0x0C) != local) {
    return verdict;
  }
  const char* player = kPlayerById(world, local);
  const std::int32_t protoId = kProtoByName(db, name.c_str());
  const char* playerProto = player == nullptr || protoId < 0 ? nullptr : kPlayerProto(player, protoId);
  if (playerProto == nullptr) {
    return verdict;
  }

  // The cost of one more unit: the units accepted so far pay first, as the command pays them in turn.
  const auto affordable = [&](std::int32_t units) {
    std::uint32_t cost[4] = {};
    kCostCtor(cost);
    bool ok = kCostGet(player, protoId, cost, units);
    if (ok) {
      ok = Field<std::uint8_t>(world, 0x6912) != 0 ? kSharedAfford(player, cost) : kAfford(player, cost);
    }
    kCostDtor(cost);
    return ok;
  };
  std::int32_t left = LimitLeft(world, player, playerProto);

  const std::int32_t count = Field<std::int32_t>(selection, 0x14);
  const auto* ids = Field<const std::int32_t*>(selection, 0x10);
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    const char* unit = kUnitById(world, ids[i]);
    const char* owner = unit == nullptr ? nullptr : Field<const char*>(unit, 0x44);
    if (owner == nullptr || Field<std::int32_t>(owner, 0) != local || !Alive(unit)) {
      continue;
    }
    ++verdict.total;
    std::int32_t reasonId = -1;
    if (!affordable(verdict.pass + 1)) {
      reasonId = kStringResources;
    } else if (left == 0) {
      reasonId = kStringBuildLimit;
    } else {
      std::int32_t placeReason = -1;
      const auto place = reinterpret_cast<PlaceFn>(Field<const void* const*>(world, 0)[0x14 / 4]);
      if (!place(world, protoId, local, reinterpret_cast<const float*>(unit + 0x14),
                 reinterpret_cast<const float*>(unit + 0x20), reinterpret_cast<const float*>(unit + 0x38), 0, 2,
                 &placeReason, 0, 0, 0)) {
        reasonId = placeReason > 0 ? placeReason : kStringObjects;
      }
    }
    if (reasonId < 0) {
      ++verdict.pass;
      if (left > 0) {
        --left;
      }
      continue;
    }
    if (verdict.reason.empty()) {
      verdict.reason = StringById(reasonId);
      if (reasonId == kStringBuildLimit) {
        wchar_t text[256];
        const std::wstring display = StringById(Field<std::int32_t>(playerProto, kProtoDisplayName));
        swprintf_s(text, verdict.reason.c_str(), display.c_str());
        verdict.reason = text;
      }
      if (verdict.reason.empty()) {
        verdict.reason = StringById(kStringObjects);
      }
    }
  }
  return verdict;
}

// "uiTransformSelectedUnit("Name")" -> Name; false for any other command.
bool TargetName(const std::string& command, std::string* name) {
  const char* click = command.c_str();
  static const char kPrefix[] = "uiTransformSelectedUnit(";
  if (_strnicmp(click, kPrefix, sizeof(kPrefix) - 1) != 0) {
    return false;
  }
  const char* open = std::strchr(click + sizeof(kPrefix) - 1, '"');
  const char* close = open == nullptr ? nullptr : std::strchr(open + 1, '"');
  if (close == nullptr || close == open + 1) {
    return false;
  }
  name->assign(open + 1, close);
  return true;
}

// The command a button runs: its click, or, for a command with an <associatedtech> (whose click is
// "commandResearch(<command ID>, <unit ID>)"), the <command> of its record in [db+2968h] (4Ch B each, count +296Ch;
// the record's first dword the wide text).
std::string ButtonCommand(const char* click) {
  static const char kPrefix[] = "commandResearch(";
  if (_strnicmp(click, kPrefix, sizeof(kPrefix) - 1) != 0) {
    return click;
  }
  const std::int32_t id = std::atoi(click + sizeof(kPrefix) - 1);
  const char* game = Game();
  const char* db = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  const char* records = db == nullptr ? nullptr : Field<const char*>(db, 0x2968);
  if (records == nullptr || id < 0 || id >= Field<std::int32_t>(db, 0x296C)) {
    return "";
  }
  const wchar_t* text = Field<const wchar_t*>(records + 0x4C * id, 0);
  std::string narrow;
  for (; text != nullptr && *text != 0 && narrow.size() < 256; ++text) {
    narrow.push_back(*text < 0x80 ? static_cast<char>(*text) : '?');
  }
  return narrow;
}

void TransformButton(const uhc::PanelButton& button) {
  std::string name;
  if (!TargetName(ButtonCommand(button.Click()), &name)) {
    return;
  }
  const DWORD now = GetTickCount();
  const std::string key = SelectionKey(kSelection());
  Cached& cached = g_cache[name];
  if (cached.at == 0 || now - cached.at >= kCacheMs || cached.selection != key) {
    Verdict fresh = Judge(name);
    if (fresh.pass != cached.verdict.pass || fresh.total != cached.verdict.total ||
        fresh.reason != cached.verdict.reason) {
      Note(L"transformChecks: button %hs: %d of %d selected unit(s) can transform%ls%ls", name.c_str(), fresh.pass,
           fresh.total, fresh.reason.empty() ? L"" : L"; ", fresh.reason.c_str());
    }
    cached.verdict = fresh;
    cached.at = now == 0 ? 1 : now;
    cached.selection = key;
  }
  const Verdict& verdict = cached.verdict;
  if (verdict.total == 0 || verdict.pass == verdict.total) {
    return;
  }
  std::wstring line;
  if (verdict.pass == 0) {
    button.State() = 1;
    button.Click()[0] = 0;
    button.ShiftClick()[0] = 0;
    line = L"\n<color=1, 0.35, 0.35>" + verdict.reason + L"</color>";
  } else {
    wchar_t text[96];
    swprintf_s(text, L"\n<color=1, 0.8, 0.3>%d / %d: </color>", verdict.pass, verdict.total);
    line = text + verdict.reason;
  }
  kAppend(button.Rollover(), line.c_str(), -1, -1);
}

}  // namespace

extern "C" {

// From the hook at 0x7D65E3, after PLACE accepted the target at the unit's place: false refuses the transform as
// PLACE does. Simulation code: the same answer on every machine.
bool __stdcall UhcXformAllowed(const char* player, const char* playerProto, const char* unit) {
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr || player == nullptr || playerProto == nullptr) {
    return true;
  }
  const char* name = Field<const char*>(playerProto, 0x10);
  const std::int32_t unitId = unit == nullptr ? -1 : Field<std::int32_t>(unit, 0x10);
  if (LimitLeft(world, player, playerProto) != 0) {
    return true;
  }
  Note(L"transformChecks: unit %d of player %d refused: at the build limit of %hs (%d)", unitId,
       Field<std::int32_t>(player, 0), name == nullptr ? "?" : name, kBuildLimit(player, playerProto));
  return false;
}

}  // extern "C"

namespace uhc {

Outcome ApplyTransformChecks(const Config& config) {
  const Config::Args* args = config.First("transformChecks");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"transformChecks: unknown argument %hs (expected: log); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("transformChecks",
                 {&sites::kXformExecBody, &sites::kXformPlaceTest, &sites::kXformRefuse, &sites::kCostListCtor,
                  &sites::kCostListDtor, &sites::kPlayerById, &sites::kUnitById, &sites::kPlayerProtoEntry,
                  &sites::kProtoByName, &sites::kBuildLimitEntry, &sites::kPayAffordCheck,
                  &sites::kPaySharedAffordCheck, &sites::kCurrentSelectionGroup, &sites::kBStringFromId,
                  &sites::kBStringAppend})) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!WriteJmp(sites::kXformPlaceTest.va, reinterpret_cast<const void*>(&UhcXformPlaceHook), 8)) {
    return Outcome::kFailed;
  }
  if (!AddPanelButtonFilter(&TransformButton)) {
    Log(L"transformChecks: the command panel's buttons are taken; the build limit applies, the buttons stay as they "
        L"are");
  }
  Log(L"transformChecks: uiTransformSelectedUnit buttons grey out with the reason, and a transform respects the "
      L"target's build limit%ls (multiplayer unverified)",
      log ? L", refusals logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/transformchecks_hooks.asm

```asm
; The hook of transformChecks in the transform command's per-unit execute FUN_007D64F7 (thiscall(cmd, unit),
; ret 4), which every machine runs inside the world update. Entered through a jmp written over the stock code, it
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcXformAllowed PROTO STDCALL player:DWORD, playerProto:DWORD, unit:DWORD

.data
placeNext  dd 007D65EBh    ; cmp byte [esi+90h],0: the payment, then the new unit
placeFail  dd 007D6762h    ; the refusal: the cost list's destructor, AL = 0, ret 4

.code

; 0x7D65E3: test al,al / je 7D6762h (8 B), right after PLACE (world vtable +14h) returned in AL. ESI = the
; command, EBP = the unit, [esp+30h] the player, [esp+14h] the player's copy of the target proto. A refusal of
; PLACE goes to the refusal as in stock; an acceptance asks UhcXformAllowed (the build limit) and goes on to the
; payment only when it agrees. Every register but EAX is kept; EAX is not read before it is loaded again at
; either continuation (AL only fed the stolen test).
UhcXformPlaceHook PROC
    TRACE_ONCE "transformChecks placement result (0x7D65E3)"
    test al, al
    je refuse
    pushad
    push ebp                            ; the unit
    push dword ptr [esp+24h+14h]        ; the player's proto (pushad 20h + one push)
    push dword ptr [esp+28h+30h]        ; the player (pushad 20h + two pushes)
    call UhcXformAllowed
    mov dword ptr [esp+1Ch], eax        ; the EAX that popad restores
    popad
    test al, al
    je refuse
    jmp placeNext
refuse:
    jmp placeFail
UhcXformPlaceHook ENDP

END
```

### src/panelbuttons.cpp

```cpp
#include "panelbuttons.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcPanelButtonHook();

namespace {

constexpr std::size_t kMaxFilters = 4;
uhc::PanelButtonFilter g_filters[kMaxFilters] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

extern "C" void __stdcall UhcPanelButton(char* frame) {
  const uhc::PanelButton button{frame};
  for (std::size_t i = 0; i < g_count; ++i) {
    g_filters[i](button);
  }
}

namespace uhc {

bool AddPanelButtonFilter(PanelButtonFilter filter) {
  if (g_count == kMaxFilters) {
    Log(L"command panel buttons: no room for another filter");
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("command panel buttons", {&sites::kNpButton}) ||
        !WriteJmp(sites::kNpButton.va, reinterpret_cast<const void*>(&UhcPanelButtonHook), 7)) {
      return false;
    }
    g_installed = true;
  }
  g_filters[g_count++] = filter;
  return true;
}

}  // namespace uhc
```

### src/panelbuttons.h

```cpp
// One hook on each button the command panel lays out (FUN_0046188E at 0x462317, before the button's
// state and commands are applied), shared by every key that changes a button there (nativePreview,
// transformChecks): a single jmp, whichever of those keys are on. Interface only: nothing here reaches
// the simulation.
#pragma once

#include <cstdint>

namespace uhc {

// The refresh's frame at 0x462317 (its ESP there). The fields a filter may read and write.
struct PanelButton {
  char* frame;

  std::int32_t Column() const { return *reinterpret_cast<const std::int32_t*>(frame + 0x1C); }
  // 0 enabled, 1 disabled (grey), 2 red, 3.
  std::int32_t& State() const { return *reinterpret_cast<std::int32_t*>(frame + 0x24); }
  // The console commands of a click and of a shift-click (256-byte narrow buffers).
  char* Click() const { return frame + 0x1C0; }
  char* ShiftClick() const { return frame + 0x3C0; }
  // The text on the button (256-byte narrow buffer, the Buy buttons' price).
  char* Overlay() const { return frame + 0x2C0; }
  // The rollover, a BString (its first dword the wide text).
  void* Rollover() const { return frame + 0x18; }
};

using PanelButtonFilter = void (*)(const PanelButton& button);

// Writes the jmp the first time (after checking the stock bytes) and adds the filter; filters run in the
// order they were added.
bool AddPanelButtonFilter(PanelButtonFilter filter);

}  // namespace uhc
```

### src/hooks/panelbuttons_hooks.asm

```asm
; The shared hook on each command panel button (panelbuttons.*), in the refresh FUN_0046188E. Entered
; through a jmp written over the stock code, it leaves through an explicit jmp to the verified
; continuation. Interface only: the filters change how a button looks and what a click on it sends.
.686
.model flat, c
option casemap :none

include common.inc

UhcPanelButton PROTO STDCALL frame:DWORD

.data
buttonNext dd 0046231Eh    ; jge 69700Dh: the grid is full

.code

; 0x462317: mov ebx,[esp+1Ch] / cmp ebx,6 (7 B, followed by the jge at 0x46231E), at the start of the
; layout of one button: [esp+24h] its state, [esp+1C0h] / [esp+3C0h] its click and shift-click
; commands, [esp+2C0h] its overlay text, [esp+18h] its rollover. The filters get the frame (ESP at the
; site); every register is kept, then the stock instructions run again and set the flags of the jge.
UhcPanelButtonHook PROC
    TRACE_ONCE "command panel button (0x462317)"
    pushad
    lea eax, [esp+20h]
    push eax
    call UhcPanelButton
    popad
    mov ebx, dword ptr [esp+1Ch]
    cmp ebx, 6
    jmp buttonNext
UhcPanelButtonHook ENDP

END
```
