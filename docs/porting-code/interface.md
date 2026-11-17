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
- [minUIStats](#minuistats)
- [playerIcon](#playericon)

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

Sites: `IsA` `0x44D7FA` (105 B), `PlayerProtoEntry` `0x45311B` (8 B), `NpSocketPanelSkip` `0x454354` (4 B), `NpGate` `0x46193E` (15 B), `NpProto` `0x461BBD` (11 B), `NpCollectSkip` `0x461C3F` (4 B), `NpTechLayout` `0x4620B9` (12 B), `NpTechBuild` `0x462172` (3 B), `NpButton` `0x462317` (13 B), `NpLayoutNext` `0x46268A` (4 B), `NpCollect` `0x4C58AD` (12 B), `NpCollectAppend` `0x4C59F5` (7 B), `NpTechPrereqAge` `0x4C5DDA` (8 B), `NpTechNoPrereq` `0x4C7330` (6 B), `ProtoByName` `0x5A2346` (32 B), `NpSocketPanel` `0x645FE7` (15 B), `NpSubCiv` `0x646124` (9 B), `NpSubCivSkip` `0x646163` (5 B), `SocketOccupant` `0xA01A20` (14 B).

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
// - 0x462317: every button of the preview is disabled and gets no command.
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
void UhcNpButtonHook();
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
                  &sites::kNpTechNoPrereq, &sites::kNpTechPrereqAge, &sites::kNpButton,
                  &sites::kSocketOccupant, &sites::kIsA, &sites::kPlayerProtoEntry, &sites::kProtoByName})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType("NativeSocket", &g_nativeSocketType) || !OnDatabaseLoad(&ForgetData) ||
      !AddProtoTagHandler("NativePreview", &ReadTag)) {
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
      {sites::kNpButton, &UhcNpButtonHook, 7},
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
buttonNext      dd 0046231Eh    ; jge 69700Dh: the grid is full

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

; 0x462317: mov ebx,[esp+1Ch] / cmp ebx,6 (7 B), where every grid button joins before it is placed.
; In a preview the button is disabled ([esp+24h] = 1; its age mark [esp+6Ch] stays as the stock
; code set it) and has no command for a click or a shift-click (the strings at [esp+1C0h] and
; [esp+3C0h]). The flags of the stolen cmp reach the jge at the continuation.
UhcNpButtonHook PROC
    TRACE_ONCE "nativePreview button (0x462317)"
    cmp g_uhcNpActive, 0
    je stock
    mov dword ptr [esp+24h], 1
    mov byte ptr [esp+1C0h], 0
    mov byte ptr [esp+3C0h], 0
stock:
    mov ebx, dword ptr [esp+1Ch]
    cmp ebx, 6
    jmp buttonNext
UhcNpButtonHook ENDP

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

## minUIStats

Contract: [minUIStats](../porting-to-another-dll.md#minuistats).

Besides the core helpers, it needs: [`datarefs.h`](helpers.md#data-refs), [`unitinfo.h`](helpers.md#unit-info-for-the-panels), [`unitpanel.h`](helpers.md#unit-panel-row-the-minimized-interface), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `BStringFree` `0x4010CA` (31 B), `BStringSet` `0x40196F` (36 B), `BStringFromWide` `0x401A12` (40 B), `GadgetRelease` `0x40431B` (44 B), `BStringAssign` `0x443BB8` (15 B), `GadgetShow` `0x447F7B` (70 B), `GadgetHide` `0x448F13` (57 B), `IsA` `0x44D7FA` (105 B), `ResListGet` `0x44EFFF` (61 B), `HoldsResource` `0x45EE8B` (20 B), `MaxHitpointsGetter` `0x480408` (38 B), `LosGetterHead` `0x48206D` (52 B), `AttackListFill` `0x487EEE` (24 B), `UnitCarryCapacity` `0x494503` (16 B), `MaxContained` `0x49EB5A` (17 B), `GadgetRef` `0x4C519C` (27 B), `MinBlockChoice` `0x4C8276` (11 B), `StatFillHead` `0x4D70ED` (24 B), `StatFillMinGate` `0x4D721B` (76 B), `MainResource` `0x4DBEC1` (16 B), `HeldAmount` `0x4E5979` (20 B), `BStringFromId` `0x58EA52` (25 B), `MinResistsUnitGate` `0x698BE2` (26 B), `CurrentUnitRef` `0x6F49B1` (65 B), `ResourceIconText` `0x706EFB` (16 B), `GadgetByName` `0xAB7C2F` (38 B).

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
// It also shows a building's armor in the stock resists gadgets (the minimized block's test of abstract type Unit
// goes), and adds a {uhc...} data ref per item for a layout's own texts (datarefs.h).
// The normal interface is unchanged: it has none of these gadgets, and every write is to a gadget found by name.
// docs/how-it-works.md, "minUIStats"; docs/unit-panel-catalog.md.
#include <windows.h>

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

bool ItemHitpoints(const char* unit, std::wstring* out) {
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

// The armor as the stock resists value: "0.20" and the icon of its damage type ([proto+1D3h]: 0 hand, 1 ranged,
// 2 siege, icons [[game+920h]+1CCh/1D0h/1D4h]).
bool ArmorText(const char* unit, bool icon, std::wstring* out) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const float armor = Field<float>(proto, 0xC4);
  if (!(armor > 0.0f)) {
    return false;
  }
  *out = Number(armor);
  const std::uint8_t type = Field<std::uint8_t>(proto, 0x1D3);
  const char* view = Field<const char*>(Game(), 0x920);
  if (icon && view != nullptr && type <= 2) {
    wchar_t tag[64];
    swprintf_s(tag, L" <icon=\"(16)(TextureID(%d))\">", Field<std::int32_t>(view, 0x1CC + 4u * type));
    *out += tag;
  }
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

bool ItemTrainPoints(const char* unit, std::wstring* out) { return ProtoPoints(unit, 0x6C, out); }
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

// The unit's attacks, as the stat panel lists them (0x4D7892..0x4D79A1): its current tactic
// [[[proto+44h]+10h] + [[unit+58h]+0A8h]*4] fills the list through 0x487EEE, each entry's +4 an index into the
// proto's actions [[proto+44h]+1Ch]; only actions with damage ([action+24h]) are kept.
std::vector<const char*> Attacks(const char* unit) {
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
    if (action != nullptr && Field<const char*>(action, 0x24) != nullptr) {
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
  swprintf_s(tag, L" <icon=\"(16)(TextureID(%d))\">", Field<std::int32_t>(view, 0x1CC + 4u * type));
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

// The player's proto cost list [proto+70h] (with its techs; read through 0x44EFFF, which unmasks it).
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
      swprintf_s(text, L"%ls%d <icon=\"(16)(%hs)\">", out->empty() ? L"" : L"  ", static_cast<int>(cost + 0.5f),
                 kResourceIcon(database, r));
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

bool ItemPopulation(const char* unit, std::wstring* out) { return ProtoInt(unit, 0xD8, out); }  // PopulationCount
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
};

// A text= row: each '|'-separated segment with its {item}s replaced; a segment with an item that has nothing for
// the unit is left out, the rest are joined by three spaces. False when no segment is left.
bool RenderTemplate(const std::wstring& text, const char* unit, std::wstring* out) {
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
        rendered += segment.substr(pos);
        break;
      }
      rendered += segment.substr(pos, open - pos);
      const std::wstring name = segment.substr(open + 1, close - open - 1);
      std::string narrow(name.begin(), name.end());
      const ItemInfo* item = FindItem(narrow);
      std::wstring value;
      ok = item != nullptr && item->fn(unit, &value);
      rendered += value;
      pos = close + 1;
    }
    if (ok && !rendered.empty()) {
      *out += (out->empty() ? L"" : L"   ") + rendered;
    }
    start = bar + 1;
  }
  return !out->empty();
}

// Kinds of mirrored stat rows.
enum Kind : std::uint32_t {
  kName = 1u << 0, kHitpoints = 1u << 1, kGroupHealth = 1u << 2, kResource = 1u << 3, kGatherers = 1u << 4,
  kRate = 1u << 5, kSpeed = 1u << 6, kResists = 1u << 7, kAttack = 1u << 8, kShownAttack = 1u << 9,
  kSpecial = 1u << 10, kOther = 1u << 11, kAuto = 1u << 31,
};

struct BigPanel {
  bool on = false;
  std::wstring pattern;  // with one %d
  int first = 0;
  int count = 16;
  std::uint32_t skip = kAuto;
};

std::vector<Row> g_rows;
BigPanel g_big;
std::vector<TypeFilter*> g_filters;
std::wstring g_file;

const char kDefaultRows[] =
    "<minUIRows>"
    "<row gadget='unitselectionpanel-uhcTrainPoints' item='trainPoints' label='Train Points: ' types='Unit'/>"
    "<row gadget='unitselectionpanel-uhcRow0' text='LOS: {los}|Speed: {speed}|Garrison: {garrison}'/>"
    "<row gadget='unitselectionpanel-uhcRow1' text='ROF: {rof}|Range: {range}'/>"
    "<row gadget='unitselectionpanel-uhcCostPop' text='Cost: {cost}|Pop: {population}'/>"
    "<row gadget='unitselectionpanel-uhcRow2' text='Overheal {overheal}|Poison {poison}'/>"
    "<bigPanelRows gadget='unitselectionpanel-uhcRow%d' first='3' skip='auto,speed'/>"
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
  return label == nullptr ? std::wstring() : Wide(*label);
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
  for (const Element& element : elements) {
    if (element.tag == "minuirows") {
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
        g_rows.push_back({Wide(Trim(*gadget)), nullptr, L"", wide, typeList(element)});
      } else {
        g_rows.push_back({Wide(Trim(*gadget)), info, Label(element), L"", typeList(element)});
      }
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
      continue;
    }
    uhc::Log(L"minUIStats: %ls: unknown element <%hs>; ignored", g_file.c_str(), element.tag.c_str());
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

struct PanelGadgets {
  char* panel = nullptr;
  std::int32_t typeNameHandle = 0;
  std::vector<Gadget> rows;  // g_rows order
  std::vector<Gadget> big;   // the bigPanelRows block, consecutive gadgets
  bool any = false;
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

// ---- The mirrored stat panel rows ----

struct StatRow {
  std::uint32_t labelStyle = 0;
  std::wstring label;
  std::wstring value;
  std::wstring tip;
  bool labelSet = false;
  bool valueSet = false;
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

void FillBigRows(const char* selection, bool minimizedBlock) {
  if (!MirrorStatRows(selection)) {
    for (Gadget& gadget : g_panel.big) {
      Hide(&gadget);
    }
    return;
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
  if (skip & kAuto) {
    // What the minimized block shows itself (0x6987D7..0x69A60F): the owner, hit points, resists, the resource held,
    // the AutoGather rate, the special attacks inline, and the first three rows of attacks less the resource row.
    skip |= minimizedBlock ? (kName | kHitpoints | kResists | kResource | kRate | kShownAttack | kSpecial) : kName;
  }
  int shownAttacks = (skip & kShownAttack) ? (resourceShown ? 2 : 3) : 0;
  size_t out = 0;
  for (size_t i = 0; i < g_stat.size() && out < g_panel.big.size(); ++i) {
    std::uint32_t kind = kinds[i];
    if (kind == kOther && lastAttack != 0 && i >= lastAttack) {
      kind = kSpecial;
    }
    if (kind == kAttack && shownAttacks > 0) {
      --shownAttacks;
      continue;
    }
    if (skip & kind) {
      continue;
    }
    const StatRow& row = g_stat[i];
    std::wstring text = row.label;
    if (!row.value.empty()) {
      text += L"  " + row.value;
    }
    const std::uint32_t style = row.labelStyle == kAttackStyle ? kAttackStyle : kLabelStyle;
    SetText(&g_panel.big[out++], text, style, row.tip);
  }
  for (; out < g_panel.big.size(); ++out) {
    Hide(&g_panel.big[out]);
  }
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
  return label;
}

// The last selection the rows were written for, and when.
std::int32_t g_lastUnitId = -1;
std::int32_t g_lastCount = -1;
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
  const ULONGLONG now = GetTickCount64();
  if (unitId == g_lastUnitId && count == g_lastCount && now - g_lastTick < kRefreshMs) {
    return;
  }
  g_lastUnitId = unitId;
  g_lastCount = count;
  g_lastTick = now;
  g_busy = true;
  for (size_t i = 0; i < g_rows.size(); ++i) {
    Gadget& gadget = g_panel.rows[i];
    if (!gadget.valid) {
      continue;
    }
    std::wstring value;
    const bool has = proto != nullptr && Applies(g_rows[i], proto) &&
                     (g_rows[i].item != nullptr ? g_rows[i].item->fn(unit, &value)
                                                : RenderTemplate(g_rows[i].text, unit, &value));
    if (!has) {
      Hide(&gadget);
      continue;
    }
    SetText(&gadget, ResolveLabel(g_rows[i].label) + value, 0, L"");
  }
  if (!g_panel.big.empty()) {
    if (proto == nullptr || selection == nullptr || count <= 0) {
      for (Gadget& gadget : g_panel.big) {
        Hide(&gadget);
      }
    } else {
      FillBigRows(selection, minimizedBlock);
    }
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
  for (TypeFilter* filter : g_filters) {
    if (!RequestAbstractUnitType(filter->name.c_str(), &filter->id)) {
      return Outcome::kFailed;
    }
  }
  static const std::uint8_t kNops[6] = {0x90, 0x90, 0x90, 0x90, 0x90, 0x90};
  if (!WriteJmp(sites::kStatFillMinGate.va + 0x41, reinterpret_cast<const void*>(&UhcStatFillMinGate), 11) ||
      !WriteBytes(sites::kMinResistsUnitGate.va + 0x14, kNops, sizeof(kNops)) || !AddUnitPanelTail(&MinUiTail) ||
      // After the tail hook, which verifies these bytes too: the minimized block also runs for a minimized layout
      // loaded without the profile option.
      !WriteJmp(sites::kMinBlockChoice.va, reinterpret_cast<const void*>(&UhcMinBlockChoice), 11)) {
    return Outcome::kFailed;
  }
  int refs = 0;
  for (const ItemInfo& item : kItems) {
    refs += AddDataRef(item.ref, kDataRefString, item.provider) ? 1 : 0;
  }
  Log(L"minUIStats: %u rows and %ls from %ls; building armor shown in the minimized panel's resists; %d data refs "
      L"{uhc...} (UI only)",
      static_cast<unsigned>(g_rows.size()), g_big.on ? L"the normal interface's stat rows" : L"no stat rows",
      g_file.c_str(), refs);
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
