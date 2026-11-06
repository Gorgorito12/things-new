# Code for WoL: Civs

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [danceBonusCivs](#dancebonuscivs)
- [startingTC](#startingtc)
- [civFirstTC](#civfirsttc)

## danceBonusCivs

Contract: [danceBonusCivs](../porting-to-another-dll.md#dancebonuscivs).

Besides the core helpers, it needs: [`prototags.h`](helpers.md#proto-tags), [`transformcalls.h`](helpers.md#transform-calls), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `UnitOfTypeLookup` `0x48195C` (12 B), `FirePitHead` `0x4819EF` (5 B), `DanceRegenGate` `0x490486` (17 B), `DanceXpGate` `0x4E0DFA` (13 B), `DanceXpBranch` `0x4E0E29` (10 B), `DanceGatherGate` `0x4ECD4E` (13 B), `DanceGatherBranch` `0x4ECD7D` (10 B), `DanceRegenBranch` `0x679E66` (13 B), `DanceTrainGate` `0x8D47A6` (13 B), `DanceTrainBranch` `0x8D47CF` (13 B), `DancerProtoRead` `0x9C1604` (7 B).

### src/features/dance.cpp

```cpp
// danceBonusCivs: the fire pit's Training, XPTrickle, Gathering and Regeneration dances for civs
// other than the four native ones.
//
// A dance is a tactic of the fire pit (firepit.tactics). Its DanceBonus actions only hold a kind
// and a strength, exp^n + mult*n - 1 + base with n = the dancers. UnitModification, UnitSpawn,
// PopCap and WarChiefRansom act by themselves, for any civ. The other four kinds are read by the
// engine where it needs them: FUN_008D4790 (train rate), FUN_004E0DE5 (XP trickle), FUN_004ECD39
// (gather rate) and FUN_00490476 (regeneration). Each one first compares the player's civ with
// XPIroquois, XPSioux, XPAztec and XPSPC (IDs cached at 0xC6FB50..0xC6FB5C) and returns "no
// bonus" for any other civ; only for those four does it look up the player's fire pit and
// multiply its dances of that kind.
//
// danceBonusCivs <Civ> ... lets the listed civs pass those four compares, so they get these
// dances exactly as the native civs do. Nothing else about the civ changes (a key that makes a civ
// native everywhere would be broader, and the XP compare is easy to miss). The hooks are in
// hooks/dance_hooks.asm.
//
// Each of those reads walks the player's units to find the fire pit, every time: with no fire pit, all
// of them, once per gatherer per tick. getFirePit 0x4819EF now remembers, per player, where the first
// unit of the type is in the list, or that there is none, for as long as the list and the protos stay
// the same. The answer is never taken from memory: the stock lookup still decides, starting at that
// place, so a foundation, a dead unit and the rest of its filter stay stock. It is a cache of a fact
// about the list, not of a game step, so a UI call between two updates cannot change what the next
// update reads, and every machine gets what stock gives.
//
// <DanceWeight>N</DanceWeight> in a proto: that many dancers, instead of 1 for a villager and 2 for any
// other unit (the count 0x9C1577, read by the strength and the tooltips).
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
#include "../prototags.h"
#include "../unittypes.h"
#include "../transformcalls.h"

namespace {

// Engine layout (docs/engine-symbols.md, "Dances").
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database

// int thiscall(database, name): the civ's ID, its index in [database+24h]; -1 if no civ has that
// name (compared with _stricmp). FUN_00512651 resolves the four native IDs with it.
using CivIdByNameFn = std::int32_t(__thiscall*)(char* database, const char* name);
const auto kCivIdByName = reinterpret_cast<CivIdByNameFn>(0x0058E71F);

// The DanceBonusType values the four readers test ([action+0C1h]), as the hooks pass them.
constexpr std::int32_t kTraining = 1;
constexpr std::int32_t kXpTrickle = 2;
constexpr std::int32_t kRegeneration = 5;
constexpr std::int32_t kGathering = 8;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

char* Game() { return *reinterpret_cast<char**>(kGameGlobal); }

std::vector<std::string> g_civNames;  // as written in uhc.cfg
bool g_log = false;  // "danceBonusCivs ... log": each player's first use of each kind in a game

// The listed civs by civ ID, for the database they were resolved in. civs.xml is read again with
// the rest of the data when a skirmish starts, so a new database (or a new civ count) is
// resolved again on its first use.
const char* g_resolvedDatabase = nullptr;
std::int32_t g_resolvedCount = -1;
std::vector<std::uint8_t> g_allowed;

// Civs: [database+24h] array of civ pointers, [database+28h] count; a civ's name is at [civ+4].
const char* CivName(const char* database, std::int32_t civ) {
  if (civ < 0 || civ >= Field<std::int32_t>(database, 0x28)) {
    return "?";
  }
  const char* entry = Field<const char**>(database, 0x24)[civ];
  const char* name = entry == nullptr ? nullptr : Field<const char*>(entry, 0x04);
  return name == nullptr ? "?" : name;
}

const wchar_t* KindName(std::int32_t kind) {
  switch (kind) {
    case kTraining:
      return L"Training";
    case kXpTrickle:
      return L"XPTrickle";
    case kRegeneration:
      return L"Regeneration";
    case kGathering:
      return L"Gathering";
    default:
      return L"?";
  }
}

std::uint8_t KindBit(std::int32_t kind) {
  switch (kind) {
    case kTraining:
      return 1;
    case kXpTrickle:
      return 2;
    case kRegeneration:
      return 4;
    case kGathering:
      return 8;
    default:
      return 0;
  }
}

// Kinds already logged per player ID, for the game world and game time they were logged in.
constexpr std::int32_t kMaxPlayers = 32;

// getFirePit's memory. firstIndex: where the first unit of the type is in the list, -1 none.
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using UnitOfTypeFn = std::int32_t(__thiscall*)(const char* player, std::int32_t type, std::int32_t startId, bool flag,
                                               std::int32_t other);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kUnitOfType = reinterpret_cast<UnitOfTypeFn>(0x0048195C);
constexpr std::int32_t kFirePitType = 0x52;  // AbstractFirePit, after the protos

struct PitMemory {
  const char* world = nullptr;
  std::uint32_t generation = 0;
  std::int32_t count = -1;
  std::int32_t last = -1;
  std::int32_t firstIndex = -1;
};
PitMemory g_pits[kMaxPlayers] = {};
std::uint32_t g_protoGeneration = 1;
std::uint32_t g_pitTime = 0;

// A transform changes a unit's proto with the list as it was.
float BeforeTransform(const char*) { return 0.0f; }
void AfterTransform(char*, float) { ++g_protoGeneration; }

const char* UnitById(const char* world, std::int32_t id) {
  if (id < 0) {
    return nullptr;
  }
  const std::int32_t index = id & 0x3FFFF;
  if (index >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char**>(world, 0x0C)[index];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

std::unordered_map<std::int32_t, std::int32_t> g_weights;  // by proto ID
std::uint8_t g_loggedKinds[kMaxPlayers] = {};
const char* g_logWorld = nullptr;
std::uint32_t g_logTime = 0;

void ResetLogged() {
  for (std::uint8_t& kinds : g_loggedKinds) {
    kinds = 0;
  }
}

void Resolve(char* database, std::int32_t count) {
  g_resolvedDatabase = database;
  g_resolvedCount = count;
  g_allowed.assign(static_cast<std::size_t>(count), 0);
  for (const std::string& name : g_civNames) {
    const std::int32_t id = kCivIdByName(database, name.c_str());
    if (id < 0 || id >= count) {
      uhc::Log(L"danceBonusCivs: %hs is not a civ in civs.xml; ignored", name.c_str());
      continue;
    }
    g_allowed[static_cast<std::size_t>(id)] = 1;
    uhc::Log(L"danceBonusCivs: %hs -> civ %d", name.c_str(), id);
  }
  bool any = false;
  for (const std::uint8_t allowed : g_allowed) {
    any = any || allowed != 0;
  }
  if (!any) {
    uhc::Log(L"danceBonusCivs: none of the listed civs exists; the four dance kinds stay native-only");
  }
  ResetLogged();
}

// With "log": one line the first time each player passes each gate, so the log proves that the
// listed civ now reads its fire pit's dances of that kind. A new world, or the game time going
// back (another game in the same world object), starts the count again.
void LogFirstUse(std::int32_t kind, const char* player, std::int32_t civ, const char* database) {
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const std::uint32_t now = world == nullptr ? 0 : Field<std::uint32_t>(world, 0x108);
  if (world != g_logWorld || static_cast<std::int32_t>(now - g_logTime) < 0) {
    ResetLogged();
    g_logWorld = world;
  }
  g_logTime = now;
  const std::int32_t id = Field<std::int32_t>(player, 0x00);  // [player+0]: the player ID
  const std::uint8_t bit = KindBit(kind);
  if (id < 0 || id >= kMaxPlayers || (g_loggedKinds[id] & bit) != 0) {
    return;
  }
  g_loggedKinds[id] |= bit;
  uhc::Log(L"danceBonusCivs: player %d (%hs) reads its fire pit's %ls dances (game time %u ms)", id,
           CivName(database, civ), KindName(kind), now);
}

}  // namespace

extern "C" {
void UhcDanceTrainHook();
void UhcDanceXpHook();
void UhcDanceGatherHook();
void UhcDanceRegenHook();
void UhcFirePitHook();
void UhcDancerHook();

// The head of getFirePit: what it returns, or -1 for the stock code to run.
const char* __stdcall UhcFirePit(const char* player) {
  char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (player == nullptr || world == nullptr || database == nullptr) {
    return reinterpret_cast<const char*>(-1);
  }
  const std::int32_t id = Field<std::int32_t>(player, 0x00);
  if (id < 0 || id >= kMaxPlayers) {
    return reinterpret_cast<const char*>(-1);
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (now < g_pitTime) {
    ++g_protoGeneration;  // another game in the same world object
  }
  g_pitTime = now;
  const std::int32_t type = Field<std::int32_t>(database, 0x19B0) + kFirePitType;
  const std::int32_t count = Field<std::int32_t>(player, 0xFC);
  const std::int32_t* list = Field<const std::int32_t*>(player, 0xF8);
  const std::int32_t last = count > 0 ? list[count - 1] : -1;
  PitMemory& pit = g_pits[id];
  if (pit.world != world || pit.generation != g_protoGeneration || pit.count != count || pit.last != last) {
    pit.world = world;
    pit.generation = g_protoGeneration;
    pit.count = count;
    pit.last = last;
    pit.firstIndex = -1;
    for (std::int32_t i = 0; i < count; ++i) {
      const char* unit = UnitById(world, list[i]);
      const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
      if (proto != nullptr && kProtoIsType(proto, type)) {
        pit.firstIndex = i;
        break;
      }
    }
  }
  if (pit.firstIndex < 0) {
    return nullptr;
  }
  const std::int32_t start = pit.firstIndex == 0 ? -1 : list[pit.firstIndex - 1];
  return UnitById(world, kUnitOfType(player, type, start, false, -1));
}

// From the dancer count: the proto's weight, or -1 for stock's count.
std::int32_t __stdcall UhcDancerWeight(const char* proto) {
  if (g_weights.empty()) {
    return -1;
  }
  const auto found = g_weights.find(Field<std::int32_t>(proto, 0x04));
  return found == g_weights.end() ? -1 : found->second;
}

// From the four hooks, in place of the first native compare. kind = the reader's DanceBonusType,
// player = its this, civ = the player's first civ ID (-1 when it has none). True if the civ is
// listed; the hook then takes the native civs' branch. Depends only on the civ and the data, so
// every machine with the same uhc.cfg decides the same.
bool __stdcall UhcDanceCivAllowed(std::int32_t kind, const char* player, std::int32_t civ) {
  char* game = Game();
  char* database = game == nullptr ? nullptr : Field<char*>(game, 0x140);
  if (civ < 0 || database == nullptr) {
    return false;
  }
  const std::int32_t count = Field<std::int32_t>(database, 0x28);
  if (count <= 0) {
    return false;  // civs.xml not read yet: resolve later, when the civs exist
  }
  if (database != g_resolvedDatabase || count != g_resolvedCount) {
    Resolve(database, count);
  }
  if (civ >= count || g_allowed[static_cast<std::size_t>(civ)] == 0) {
    return false;
  }
  if (g_log && player != nullptr) {
    LogFirstUse(kind, player, civ, database);
  }
  return true;
}
}

namespace {

bool __cdecl ReadWeight(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  wchar_t* end = nullptr;
  const long weight = text == nullptr ? -1 : std::wcstol(text, &end, 10);
  if (text == nullptr || end == text || weight < 0 || weight > 1000) {
    uhc::Log(L"danceBonusCivs: proto %d: <DanceWeight> needs a whole number from 0 to 1000; ignored",
             Field<std::int32_t>(proto, 0x04));
    return true;
  }
  g_weights[Field<std::int32_t>(proto, 0x04)] = static_cast<std::int32_t>(weight);
  return true;
}

void NewDatabase(char*) {
  g_weights.clear();
  ++g_protoGeneration;
}

}  // namespace

namespace uhc {

namespace {
bool g_gatesInstalled = false;
bool g_extrasInstalled = false;

// The fire pit's memory and the weights. Neither is needed for the dances to work, so a site another
// DLL patched leaves them off and the key on.
void InstallExtras(const char* feature) {
  if (g_extrasInstalled) {
    return;
  }
  g_extrasInstalled = true;
  if (!VerifyAll(feature, {&sites::kFirePitHead, &sites::kUnitOfTypeLookup, &sites::kDancerProtoRead}) ||
      !AddProtoTagHandler("DanceWeight", &ReadWeight) || !OnDatabaseLoad(&NewDatabase) ||
      !AddTransformObserver({&BeforeTransform, &AfterTransform}) ||
      !WriteJmp(sites::kFirePitHead.va, reinterpret_cast<const void*>(&UhcFirePitHook), 5) ||
      !WriteJmp(sites::kDancerProtoRead.va, reinterpret_cast<const void*>(&UhcDancerHook), 7)) {
    Log(L"%hs: no fire pit memory and no <DanceWeight>; the dances work as they did", feature);
  }
}
}  // namespace

// The four dance gates, installed once (danceBonusCivs and nativeCivs share them).
bool InstallDanceGates(const char* feature) {
  if (g_gatesInstalled) {
    return true;
  }
  if (!VerifyAll(feature, {&sites::kDanceTrainGate, &sites::kDanceTrainBranch, &sites::kDanceXpGate,
                           &sites::kDanceXpBranch, &sites::kDanceGatherGate, &sites::kDanceGatherBranch,
                           &sites::kDanceRegenGate, &sites::kDanceRegenBranch})) {
    return false;
  }
  // Each jmp replaces the 6-byte cmp eax,[0C6FB50h] (XPIroquois), the first native compare.
  struct Gate {
    std::uint32_t va;
    void (*hook)();
  };
  const Gate gates[] = {
      {0x008D47AB, &UhcDanceTrainHook},
      {0x004E0DFF, &UhcDanceXpHook},
      {0x004ECD53, &UhcDanceGatherHook},
      {0x0049048B, &UhcDanceRegenHook},
  };
  for (const Gate& gate : gates) {
    if (!WriteJmp(gate.va, reinterpret_cast<const void*>(gate.hook), 6)) {
      return false;
    }
  }
  g_gatesInstalled = true;
  InstallExtras(feature);
  return true;
}

bool AddDanceCivs(const std::vector<std::string>& names, const char* feature) {
  if (!InstallDanceGates(feature)) {
    return false;
  }
  g_civNames.insert(g_civNames.end(), names.begin(), names.end());
  g_resolvedDatabase = nullptr;  // resolve again with the new names
  return true;
}

Outcome ApplyDanceBonusCivs(const Config& config) {
  const std::vector<Config::Args>* lines = config.All("danceBonusCivs");
  if (lines == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  std::string listed;
  for (const Config::Args& args : *lines) {
    for (const std::string& arg : args) {
      if (_stricmp(arg.c_str(), "log") == 0) {
        log = true;
        continue;
      }
      g_civNames.push_back(arg);
      listed += listed.empty() ? arg : ", " + arg;
    }
  }
  if (g_civNames.empty()) {
    Log(L"danceBonusCivs: expected \"danceBonusCivs <Civ> [<Civ> ...] [log]\" with at least one civ name; "
        L"feature not applied");
    return Outcome::kFailed;
  }
  g_log = log;

  if (!InstallDanceGates("danceBonusCivs")) {
    return Outcome::kFailed;
  }
  Log(L"danceBonusCivs: civs %hs get the fire pit's Training, XPTrickle, Gathering and Regeneration dances like "
      L"the native civs%ls (multiplayer unverified)",
      listed.c_str(), log ? L", each player's first use of each kind logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/dance_hooks.asm

```asm
; Hooks for danceBonusCivs. Each is entered through a jmp written over the first native civ
; compare of one dance reader, cmp eax,[0C6FB50h] (XPIroquois), and leaves through an explicit jmp
; to a verified continuation (docs/engine-symbols.md, "Dances"). Both paths into that compare
; arrive with EAX = the player's first civ ID, or -1 when [player+24h] (the civ count) is 0.
;
; A listed civ jumps to the branch the stock code takes for a native civ (the fire pit lookup).
; Any other civ re-executes the stolen compare and continues at the stock je, which reads its
; flags; the other three native compares then run unchanged. EAX, ECX, EDX and ESP are the same
; on both exits; no x87 value is live at these sites.
.686
.model flat, c
option casemap :none

include common.inc

UhcDanceCivAllowed PROTO STDCALL kind:DWORD, player:DWORD, civ:DWORD
UhcFirePit PROTO STDCALL player:DWORD
UhcDancerWeight PROTO STDCALL unitProto:DWORD

.data
trainNext       dd 008D47B1h    ; je 8D47CFh, then the XPSioux, XPAztec and XPSPC compares
trainDance      dd 008D47CFh    ; call 4819EFh (the player's first fire pit) / test eax,eax
xpNext          dd 004E0E05h    ; je 4E0E29h, then the other three compares
xpDance         dd 004E0E29h    ; call 4819EFh / jmp 679D72h
gatherNext      dd 004ECD59h    ; je 4ECD7Dh, then the other three compares
gatherDance     dd 004ECD7Dh    ; call 4819EFh / jmp 679DECh
regenNext       dd 00490491h    ; je 679E66h (near), then the other three compares
firePitNext     dd 004819F4h    ; mov edx,[eax+140h], the rest of getFirePit
dancerType      dd 009C160Bh    ; push 16h / mov ecx,eax / call 44CAC4h: EAX = the proto
dancerOther     dd 009C161Fh    ; add [esp+10h],2: a dancer that is not a villager
dancerNext      dd 009C1629h    ; add esi,1, the next worker
regenDance      dd 00679E66h    ; cmp dword ptr [edi+80h],0 / je 4904BBh, then the fire pit

.code

; Replaces 0x4819EF, the head of getFirePit, thiscall(player), no arguments: mov eax,[0C66234h]. EDX
; and ECX are free on return, as they are after the stock body.
UhcFirePitHook PROC
    TRACE_ONCE "danceBonusCivs fire pit (0x4819EF)"
    push ecx
    push ecx
    call UhcFirePit
    pop ecx
    cmp eax, -1
    je stock
    ret
stock:
    mov eax, dword ptr ds:[0C66234h]    ; replaced
    jmp firePitNext
UhcFirePitHook ENDP

; Replaces 0x9C1604 in the dancer count 0x9C1577, with EAX = the worker unit: mov eax,[eax+5Ch] /
; test eax,eax / je 9C161Fh. The stale workers it removes are handled before this. [esp+10h] is the
; count; EAX, ECX and EDX are free at every exit but the type test, which wants the proto in EAX.
UhcDancerHook PROC
    TRACE_ONCE "danceBonusCivs dancer (0x9C1604)"
    mov eax, dword ptr [eax+5Ch]        ; replaced
    test eax, eax                       ; replaced
    je other
    push eax
    push eax
    call UhcDancerWeight
    mov ecx, eax
    pop eax
    test ecx, ecx
    jl stock
    add dword ptr [esp+10h], ecx
    jmp dancerNext
stock:
    jmp dancerType
other:
    jmp dancerOther
UhcDancerHook ENDP

; Replaces 0x8D47AB in FUN_008D4790 (train rate, thiscall; ret 4 with the trained proto ID).
; ECX = player; the fire pit lookup at the continuation takes it as this.
UhcDanceTrainHook PROC
    TRACE_ONCE "danceBonusCivs Training (0x8D47AB)"
    push eax
    push ecx
    push edx
    push eax                        ; civ ID
    push ecx                        ; player
    push 1                          ; DanceBonusType Training
    call UhcDanceCivAllowed
    test al, al
    pop edx
    pop ecx
    pop eax
    jne dance
    cmp eax, dword ptr ds:[0C6FB50h]    ; stolen 0x8D47AB
    jmp trainNext
dance:
    jmp trainDance
UhcDanceTrainHook ENDP

; Replaces 0x4E0DFF in FUN_004E0DE5 (XP trickle multiplier, thiscall). ECX = player. Also
; reached from the dance tooltips (0x9D6D98, 0x9D793F), which show the same multiplier.
UhcDanceXpHook PROC
    TRACE_ONCE "danceBonusCivs XPTrickle (0x4E0DFF)"
    push eax
    push ecx
    push edx
    push eax                        ; civ ID
    push ecx                        ; player
    push 2                          ; DanceBonusType XPTrickle
    call UhcDanceCivAllowed
    test al, al
    pop edx
    pop ecx
    pop eax
    jne dance
    cmp eax, dword ptr ds:[0C6FB50h]    ; stolen 0x4E0DFF
    jmp xpNext
dance:
    jmp xpDance
UhcDanceXpHook ENDP

; Replaces 0x4ECD53 in FUN_004ECD39 (gather rate multiplier, thiscall). ECX = player.
UhcDanceGatherHook PROC
    TRACE_ONCE "danceBonusCivs Gathering (0x4ECD53)"
    push eax
    push ecx
    push edx
    push eax                        ; civ ID
    push ecx                        ; player
    push 8                          ; DanceBonusType Gathering
    call UhcDanceCivAllowed
    test al, al
    pop edx
    pop ecx
    pop eax
    jne dance
    cmp eax, dword ptr ds:[0C6FB50h]    ; stolen 0x4ECD53
    jmp gatherNext
dance:
    jmp gatherDance
UhcDanceGatherHook ENDP

; Replaces 0x49048B in FUN_00490476 (regeneration, thiscall, this in EDI since 0x49047A; ECX
; holds the same value). The continuation reads EDI.
UhcDanceRegenHook PROC
    TRACE_ONCE "danceBonusCivs Regeneration (0x49048B)"
    push eax
    push ecx
    push edx
    push eax                        ; civ ID
    push edi                        ; player
    push 5                          ; DanceBonusType Regeneration
    call UhcDanceCivAllowed
    test al, al
    pop edx
    pop ecx
    pop eax
    jne dance
    cmp eax, dword ptr ds:[0C6FB50h]    ; stolen 0x49048B
    jmp regenNext
dance:
    jmp regenDance
UhcDanceRegenHook ENDP

END
```

## startingTC

Contract: [startingTC](../porting-to-another-dll.md#startingtc).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `IsA` `0x44D7FA` (105 B), `SetLifespanArm` `0x48DCB9` (40 B), `FirstTcGate` `0x49880A` (22 B), `FirstTcChunk` `0x506B2A` (17 B), `FirstTcProtoCheck` `0x506B3B` (17 B), `FirstTcSet` `0x67ABD4` (14 B), `FirstTcRuleLookup` `0x8CE597` (68 B), `UnitAliveSlot` `0xB9355C` (4 B).

### src/features/startingtc.cpp

```cpp
// startingTC [UnitType] [log]: buildings of a marker unittype (default AbstractStartingTC) can be
// a player's first town center, the unit the placement rules call FirstTC.
//
// Stock keeps one first town center per player, a unit ID at [player+4F0h] (-1 at first). The
// placement rules read it through the keyword FirstTC (stock placementrules: no building within
// 65 m of an enemy's FirstTC, and the "norushonly" rule within 75 m of a team FirstTC; rule
// evaluators FUN_008CE515 / FUN_008CE935). Player::addUnit FUN_0049874F sets it once, while it is
// still -1, to a unit whose exact proto ID is TownCenter's ([database+5E08h], 0x506B3B). Nothing
// clears it when that unit dies. A civ that starts with another building has no FirstTC, or a
// dead one: e.g. a start tech that gives TownCenter a Lifespan of 0.5 s and then a free
// replacement building in the same tech, so the replacement is added while the town center is
// still alive and FirstTC stays on it.
//
// Two hooks in addUnit (hooks/startingtc_hooks.asm), for a unit whose proto is of the marker type:
// - a player with no FirstTC yet takes it, as stock takes a TownCenter;
// - a player whose FirstTC is gone (not in the unit table), dead (unit vtable slot A4h) or has a
//   pending lifespan (state bit 3, set by setLifespan 0x48DCB9) gets it as the new FirstTC.
// A TownCenter keeps its stock behavior. The test reads only game state, the same on every machine.
#include <cstdint>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world

using IsAliveFn = bool(__thiscall*)(const char* unit);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// The world the FirstTC rules read ([game+13Ch], 0x8CE5A8).
const char* MainWorld() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

// Players: [world+58h] array, [world+5Ch] count; a player's ID is at [player+0].
const char* PlayerById(const char* world, std::int32_t id) {
  if (id < 0 || id >= Field<std::int32_t>(world, 0x5C)) {
    return nullptr;
  }
  return Field<const char* const*>(world, 0x58)[id];
}

// Units by ID, as the FirstTC rule looks them up (0x8CE5B5): [world+0Ch] array, [world+10h]
// count; the low 18 bits index the array and [unit+10h] must equal the full ID.
const char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

// Unit vtable slot A4h (0x44D019): state bit 8 set, bit 12 clear and HP > 0, the stock alive test.
bool IsAlive(const char* unit) { return (*reinterpret_cast<IsAliveFn const* const*>(unit))[0xA4 / 4](unit); }

// State bit 3 of the bitset [unit+4] (bit count [unit+8]): setLifespan sets it for a lifespan
// > 0, and the lifespan tick clears it when the countdown [[unit+B4h]+1Ch] ends and queues the kill.
bool LifespanPending(const char* unit) {
  return Field<std::uint32_t>(unit, 0x08) > 3 && (Field<const std::uint8_t*>(unit, 0x04)[0] & 0x08) != 0;
}

const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

}  // namespace

extern "C" {
std::int32_t g_uhcStartingTcType = -1;  // marker unittype ID, set on each database load
std::int32_t g_uhcStartingTcLog = 0;    // 1 with "startingTC ... log"

void UhcStartingTcGateHook();
void UhcStartingTcProtoHook();

// From the proto hook, only with "log": a marked unit is the first FirstTC of its player.
void __stdcall UhcStartingTcFirst(const char* player, const char* unit) {
  uhc::Log(L"startingTC: unit %d (%hs) is player %d's first town center (FirstTC)", Field<std::int32_t>(unit, 0x10),
           ProtoName(unit), Field<std::int32_t>(player, 0x00));
}

// From the gate hook, for a marked unit added to a player who has a FirstTC: true if that FirstTC
// no longer counts, so the unit replaces it.
bool __stdcall UhcStartingTcStale(const char* player, const char* unit) {
  const std::int32_t playerId = Field<std::int32_t>(player, 0x00);
  const std::int32_t old = Field<std::int32_t>(player, 0x4F0);
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const char* world = MainWorld();
  // A player of another world (the home city's) is left alone.
  if (old == id || world == nullptr || PlayerById(world, playerId) != player) {
    return false;
  }
  const char* tc = UnitById(world, old);
  if (tc == nullptr) {
    if (g_uhcStartingTcLog != 0) {
      uhc::Log(L"startingTC: unit %d (%hs) replaces player %d's first town center %d, which is gone", id,
               ProtoName(unit), playerId, old);
    }
    return true;
  }
  if (!IsAlive(tc)) {
    if (g_uhcStartingTcLog != 0) {
      uhc::Log(L"startingTC: unit %d (%hs) replaces player %d's first town center %d (%hs), which is dead", id,
               ProtoName(unit), playerId, old, ProtoName(tc));
    }
    return true;
  }
  if (LifespanPending(tc)) {
    if (g_uhcStartingTcLog != 0) {
      const char* sub = Field<const char*>(tc, 0xB4);
      uhc::Log(L"startingTC: unit %d (%hs) replaces player %d's first town center %d (%hs), whose lifespan ends in "
               L"%.2f s",
               id, ProtoName(unit), playerId, old, ProtoName(tc),
               sub == nullptr ? -1.0 : static_cast<double>(Field<float>(sub, 0x1C)));
    }
    return true;
  }
  return false;
}
}

namespace uhc {

namespace {
bool g_protoHookInstalled = false;
}  // namespace

// The hook at 0x506B3B serves startingTC and civFirstTC (features/civfirsttc.cpp): whichever key
// applies first writes it, after its own VerifyAll.
bool FirstTcProtoHookInstalled() { return g_protoHookInstalled; }

bool InstallFirstTcProtoHook() {
  if (!g_protoHookInstalled) {
    // Replaces cmp eax,[ecx+5E08h] at 0x506B3B; the hook re-executes it.
    g_protoHookInstalled =
        WriteJmp(sites::kFirstTcProtoCheck.va, reinterpret_cast<const void*>(&UhcStartingTcProtoHook), 6);
  }
  return g_protoHookInstalled;
}

// firstTC [UnitType] [log] is startingTC and civFirstTC in one line. The marker type is registered only when the line
// names one, as it changes the unit type count: with none, this part stays off, and civFirstTC runs alone.
Outcome ApplyStartingTc(const Config& config) {
  const Config::Args* args = config.First("startingTC");
  if (args == nullptr) {
    args = config.First("firstTC");
    bool named = false;
    if (args != nullptr) {
      for (const std::string& arg : *args) {
        named = named || _stricmp(arg.c_str(), "log") != 0;
      }
    }
    if (!named) {
      return Outcome::kNotConfigured;
    }
  }
  std::string typeName = "AbstractStartingTC";
  bool typeGiven = false;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (!typeGiven) {
      typeName = arg;
      typeGiven = true;
    } else {
      Log(L"startingTC: unexpected argument %hs (expected: [UnitType] [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("startingTC", {&sites::kFirstTcGate, &sites::kFirstTcChunk, &sites::kFirstTcProtoCheck,
                                &sites::kFirstTcSet, &sites::kFirstTcRuleLookup, &sites::kSetLifespanArm,
                                &sites::kUnitAliveSlot, &sites::kIsA})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(typeName.c_str(), &g_uhcStartingTcType)) {
    return Outcome::kFailed;
  }
  g_uhcStartingTcLog = log ? 1 : 0;
  if (!InstallFirstTcProtoHook()) {
    return Outcome::kFailed;
  }
  // Replaces cmp dword ptr [esi+4F0h],0 / jl 506B2Ah at 0x49880A; the hook re-executes both. Without
  // it the proto hook would run alone: put its stock bytes back rather than run half the feature.
  if (!WriteJmp(sites::kFirstTcGate.va, reinterpret_cast<const void*>(&UhcStartingTcGateHook), 13)) {
    if (WriteBytes(sites::kFirstTcProtoCheck.va, sites::kFirstTcProtoCheck.bytes, 6)) {
      g_protoHookInstalled = false;
    }
    return Outcome::kFailed;
  }
  Log(L"startingTC: units of unittype %hs can be a player's first town center (FirstTC) like TownCenter, and "
      L"replace one that is gone, dead or has a pending lifespan%ls (multiplayer unverified)",
      typeName.c_str(), log ? L", every new FirstTC logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/startingtc_hooks.asm

```asm
; Hooks for startingTC. Entered through a jmp written over the stock code; each leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Starting town center").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcStartingTcType:SDWORD   ; marker unittype ID, set on each database load; -1 before
EXTERNDEF g_uhcStartingTcLog:SDWORD    ; 1 with "startingTC ... log"
EXTERNDEF g_uhcCivFirstTcOn:SDWORD     ; 1 with civFirstTC (features/civfirsttc.cpp)

UhcStartingTcFirst PROTO STDCALL player:DWORD, unit:DWORD
UhcStartingTcStale PROTO STDCALL player:DWORD, unit:DWORD
UhcCivFirstTcMatches PROTO STDCALL player:DWORD, protoId:DWORD, unit:DWORD

.data
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): proto IDs and abstract types
firstTcChunk    dd 00506B2Ah    ; stock: EAX = the unit's proto ID, ECX = database, then the TownCenter compare
firstTcSet      dd 0067ABD4h    ; mov ecx,[edi+10h] / mov [esi+4F0h],ecx / jmp 498817h: the unit is FirstTC
addUnitExit     dd 00498817h    ; pop ebx / pop ebp / pop edi / mov al,1 / pop esi / ret 8

.code

; Replaces 0x49880A..0x498816 (cmp dword ptr [esi+4F0h],0 / jl 506B2Ah) at the end of
; Player::addUnit FUN_0049874F. ESI = player, EDI = the unit just added; EBX and EBP are the
; function's. 0x498817 pops EBX, EBP, EDI and ESI and reads no other register and no flag, and
; 0x67ABD4 reads only EDI and ESI. A player whose FirstTC [esi+4F0h] is still -1 runs the stock
; cold chunk (and the proto hook below). For a player that has one, a unit whose proto is of the
; marker type becomes FirstTC when UhcStartingTcStale finds the old one gone, dead or with a
; pending lifespan; every other unit leaves as in stock.
UhcStartingTcGateHook PROC
    TRACE_ONCE "startingTC (0x49880A)"
    cmp dword ptr [esi+4F0h], 0     ; stolen 0x49880A
    jl noFirstTc                    ; stolen 0x498811
    cmp g_uhcStartingTcType, 0
    jl done
    mov ecx, dword ptr [edi+5Ch]    ; the unit's proto
    test ecx, ecx
    je done
    push g_uhcStartingTcType
    call protoIsType
    test al, al
    je done
    push edi
    push esi
    call UhcStartingTcStale         ; true: the old FirstTC no longer counts
    test al, al
    je done
    jmp firstTcSet
done:
    jmp addUnitExit
noFirstTc:
    jmp firstTcChunk
UhcStartingTcGateHook ENDP

; Replaces 0x506B3B..0x506B40 (cmp eax,[ecx+5E08h]) in the cold chunk of Player::addUnit, which
; runs only while the player has no FirstTC. EAX = the unit's exact proto ID, ECX = database,
; EDX = proto, EDI = unit, ESI = player. Stock makes the unit FirstTC only when the ID is
; TownCenter's (jne 498817h / jmp 67ABD4h); the hook also accepts, with civFirstTC, the <firstTC>
; proto of the player's civ and, with startingTC, a unit whose proto is of the marker type.
; Both exits read only EDI and ESI. Installed once for both keys (features/startingtc.cpp).
UhcStartingTcProtoHook PROC
    TRACE_ONCE "FirstTC proto check (0x506B3B)"
    cmp eax, dword ptr [ecx+5E08h]  ; stolen 0x506B3B: TownCenter
    je setFirst
    cmp g_uhcCivFirstTcOn, 0
    je marker
    push edi
    push eax
    push esi
    call UhcCivFirstTcMatches       ; the civ's <firstTC> proto (logs it); clobbers EAX/ECX/EDX
    test al, al
    jne setFirst
marker:
    cmp g_uhcStartingTcType, 0
    jl done
    mov ecx, dword ptr [edi+5Ch]    ; the unit's proto
    test ecx, ecx
    je done
    push g_uhcStartingTcType
    call protoIsType
    test al, al
    je done
    cmp g_uhcStartingTcLog, 0
    je setFirst
    push edi
    push esi
    call UhcStartingTcFirst         ; logs the new FirstTC
setFirst:
    jmp firstTcSet
done:
    jmp addUnitExit
UhcStartingTcProtoHook ENDP

END
```

## civFirstTC

Contract: [civFirstTC](../porting-to-another-dll.md#civfirsttc).

Besides the core helpers, it needs: [`civtags.h`](helpers.md#civ-tags).

Sites: `CivById` `0x405C2E` (24 B), `PlayerById` `0x44CB21` (30 B), `UnitById` `0x44CC6D` (58 B), `ProtoById` `0x45316E` (30 B), `CivOfPlayer` `0x4539D3` (16 B), `ProtoFlag` `0x45EE02` (53 B), `FirstTcChunk` `0x506B2A` (17 B), `FirstTcProtoCheck` `0x506B3B` (17 B), `ProtoByName` `0x5A2346` (32 B), `TownStartQuery` `0x679AC1` (21 B), `TownStartSpawn` `0x679B50` (26 B), `FirstTcSet` `0x67ABD4` (14 B), `TownStartColonyLoop` `0x7C2407` (49 B), `RmNomadStart` `0x90B683` (25 B), `RmItemFootprint` `0x924B1D` (158 B), `RmPlace` `0x925936` (111 B), `RmPlaceCall` `0x925F45` (14 B), `UnitAliveSlot` `0xB9355C` (4 B).

### src/features/civfirsttc.cpp

```cpp
// civFirstTC [log]: a civ's <firstTC>Proto</firstTC> in civs.xml replaces the TownCenter that a
// random map places for its players, and that building is the player's first town center
// (FirstTC), the unit the placement rules read. A Nomad start (rmGetNomadStart()) keeps the
// map's units.
//
// Four hooks, all simulation-side:
// - civs.xml: the parser FUN_0052A590 skips a <civ> child tag it does not know at 0x52BB07; the
//   hook reads <firstTC> there (hooks/civfirsttc_hooks.asm). Stock ignores the tag.
// - Map placement: every rmPlaceObjectDef* reaches objectDef::place FUN_00925936 through one call,
//   0x925F4C. The wrapper below gives the def's TownCenter items the player's <firstTC> proto (and
//   its footprint, when larger) for that call only, so the same def still places a TownCenter for
//   the next player. The Special_StartingUnits def (rmCreateStartingUnitsObjectDef) is left alone:
//   place() rebuilds its items from the civ's <startingunit> list.
// - FirstTC: Player::addUnit takes only a TownCenter as FirstTC (0x506B3B); the hook shared with
//   startingTC (hooks/startingtc_hooks.asm) also takes the civ's <firstTC> proto, outside a Nomad
//   start, so a reloaded scenario or save finds the same FirstTC.
// - Town starting units: FUN_0049039A gives the civ's <townstartingunit> units (settlers, crates)
//   to the first built TownCenter, through FUN_007C238E, which spawns them only at a colony that
//   starts at that unit (placementrules\colonies.xml <starttypes>), then clears the request. The
//   hook queries the <firstTC> proto instead when the player's FirstTC is such a building with a
//   colony; otherwise the stock wait for a TownCenter stays, and no unit is lost.
#include <windows.h>

#include <cstdint>
#include <cstring>
#include <cwchar>
#include <set>
#include <string>
#include <tuple>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

#include "../civtags.h"

namespace uhc {
bool FirstTcProtoHookInstalled();  // features/startingtc.cpp
bool InstallFirstTcProtoHook();
}  // namespace uhc

extern "C" void __stdcall UhcTraceHook(const char* hookName);

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database, +92Ch RM

using CivByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
using ProtoByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using ProtoByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
using ProtoFlagFn = bool(__thiscall*)(const char* proto, std::int32_t flag);
using IsAliveFn = bool(__thiscall*)(const char* unit);
using PlaceFn = std::int32_t(__fastcall*)(char* def, void* unused, std::int32_t player, std::uint32_t x,
                                         std::uint32_t z, std::uint32_t count);

const auto kCivById = reinterpret_cast<CivByIdFn>(0x00405C2E);
const auto kProtoByName = reinterpret_cast<ProtoByNameFn>(0x005A2346);
const auto kProtoById = reinterpret_cast<ProtoByIdFn>(0x0045316E);
const auto kProtoFlag = reinterpret_cast<ProtoFlagFn>(0x0045EE02);
const auto kPlace = reinterpret_cast<PlaceFn>(0x00925936);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* GameField(std::uint32_t offset) {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, offset);
}

// rmGetNomadStart (0x90B683): byte [RM+1A95h], false when there is no RM.
bool NomadStart() {
  const char* rm = GameField(0x92C);
  return rm != nullptr && Field<std::uint8_t>(rm, 0x1A95) != 0;
}

// Players: [world+58h] array, [world+5Ch] count (0x44CB21).
const char* PlayerById(const char* world, std::int32_t id) {
  if (id < 0 || id >= Field<std::int32_t>(world, 0x5C)) {
    return nullptr;
  }
  return Field<const char* const*>(world, 0x58)[id];
}

// Units by ID: [world+0Ch] array, [world+10h] count; the low 18 bits index it and [unit+10h] must
// equal the full ID (0x44CC6D).
const char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<IsAliveFn const* const*>(unit))[0xA4 / 4](unit); }

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* UnitName(const char* unit) { return ProtoName(Field<const char*>(unit, 0x5C)); }

std::int32_t UnitProto(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  return proto == nullptr ? -1 : Field<std::int32_t>(proto, 0x04);
}

const char* CivName(const char* civ) {
  const char* name = civ == nullptr ? nullptr : Field<const char*>(civ, 0x04);
  return name == nullptr ? "?" : name;
}

// A player's civ ID (0x4539D3): [[player+20h]] when [player+24h] > 0, else -1.
std::int32_t CivIdOf(const char* player) {
  return Field<std::int32_t>(player, 0x24) > 0 ? *Field<const std::int32_t*>(player, 0x20) : -1;
}

struct CivTag {
  const char* civ = nullptr;  // the civ object it was read for; a new parse makes new ones
  std::string name;           // the text of <firstTC>
  const char* table = nullptr;  // the database's proto array [db+54h] when proto was resolved
  std::int32_t proto = -1;
};

std::vector<CivTag> g_tags;  // by civ ID
bool g_log = false;

// Log lines that a state repeats every update are written once per game.
std::set<std::tuple<int, std::int32_t, std::int32_t>> g_logged;  // kind, player, unit or civ
const char* g_logWorld = nullptr;
std::uint32_t g_logStep = 0;

bool FirstTime(int kind, std::int32_t player, std::int32_t what) {
  const char* world = GameField(0x13C);
  const std::uint32_t step = world == nullptr ? 0 : Field<std::uint32_t>(world, 0xF8);
  if (world != g_logWorld || step < g_logStep) {
    g_logged.clear();
  }
  g_logWorld = world;
  g_logStep = step;
  return g_logged.emplace(kind, player, what).second;
}

std::string Narrow(const wchar_t* text) {
  std::string out;
  for (; *text != L'\0'; ++text) {
    out += *text < 0x80 ? static_cast<char>(*text) : '?';
  }
  const auto first = out.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) {
    return {};
  }
  return out.substr(first, out.find_last_not_of(" \t\r\n") - first + 1);
}

// The <firstTC> proto ID of the player's civ, or -1. Resolved by name on first use and again when
// the database's proto array changes; an unknown name is logged once and gives -1.
std::int32_t CivFirstTcProto(const char* player) {
  const char* db = GameField(0x140);
  const std::int32_t civId = CivIdOf(player);
  if (db == nullptr || civId < 0 || civId >= static_cast<std::int32_t>(g_tags.size())) {
    return -1;
  }
  CivTag& tag = g_tags[civId];
  if (tag.name.empty() || kCivById(db, civId) != tag.civ) {
    return -1;
  }
  const char* table = Field<const char*>(db, 0x54);
  if (tag.table != table) {
    tag.table = table;
    tag.proto = kProtoByName(db, tag.name.c_str());
    if (tag.proto < 0) {
      uhc::Log(L"civFirstTC: civ %d (%hs): <firstTC> names no proto unit (%hs); its players keep TownCenter", civId,
               CivName(tag.civ), tag.name.c_str());
    }
  }
  return tag.proto;
}

// Item footprint (+0Ch, +10h) as objectDef::addItem computes it (0x924B1D).
void Footprint(const char* db, const char* world, std::int32_t protoId, std::int32_t* x, std::int32_t* z) {
  *x = 0;
  *z = 0;
  const char* proto = kProtoById(db, protoId);
  const char* terrain = Field<const char*>(world, 0x88);
  if (proto == nullptr || terrain == nullptr || !kProtoFlag(proto, 2)) {
    return;
  }
  const float scale = Field<float>(terrain, 0x1C);
  *x = static_cast<std::int32_t>(Field<float>(proto, 0x88) * scale * 2.0f + 0.5f);
  *z = static_cast<std::int32_t>(Field<float>(proto, 0x8C) * scale * 2.0f + 0.5f);
}

struct Item {
  std::int32_t proto;
  std::int32_t count;
  std::int32_t cluster;
  std::int32_t footprintX;
  std::int32_t footprintZ;
};
static_assert(sizeof(Item) == 20);

struct Saved {
  std::int32_t index;
  Item item;
};

}  // namespace

extern "C" {
std::int32_t g_uhcCivFirstTcOn = 0;  // 1 with civFirstTC; read by the shared FirstTC proto hook

// From the civ tags registry (civtags.cpp), for a <firstTC> child of a <civ>.
void ReadFirstTc(const char* civ, std::int32_t civId, const wchar_t* text) {
  const std::string name = text == nullptr ? std::string() : Narrow(text);
  if (civId >= static_cast<std::int32_t>(g_tags.size())) {
    g_tags.resize(civId + 1);
  }
  g_tags[civId] = CivTag{civ, name};
  if (name.empty()) {
    uhc::Log(L"civFirstTC: civ %d (%hs): empty <firstTC>; its players keep TownCenter", civId, CivName(civ));
  } else {
    uhc::Log(L"civFirstTC: civ %d (%hs) starts with %hs instead of TownCenter", civId, CivName(civ), name.c_str());
  }
}

// From the shared FirstTC proto hook, for a unit added to a player with no FirstTC: true if its
// proto is the <firstTC> proto of the player's civ, outside a Nomad start.
bool __stdcall UhcCivFirstTcMatches(const char* player, std::int32_t protoId, const char* unit) {
  if (g_tags.empty() || CivFirstTcProto(player) != protoId || protoId < 0 || NomadStart()) {
    return false;
  }
  if (g_log) {
    uhc::Log(L"civFirstTC: unit %d (%hs) is player %d's first town center (FirstTC)", Field<std::int32_t>(unit, 0x10),
             UnitName(unit), Field<std::int32_t>(player, 0x00));
  }
  return true;
}

// From the town starting units hook (EDI = player): the proto to query instead of TownCenter, or
// -1. Only when the player's FirstTC is alive, of the civ's <firstTC> proto, its own, and a colony
// starts at it, the same test as FUN_007C238E (0x7C2407).
std::int32_t __stdcall UhcCivFirstTcTownProto(const char* player) {
  if (g_tags.empty()) {
    return -1;
  }
  const std::int32_t proto = CivFirstTcProto(player);
  const char* world = GameField(0x13C);
  if (proto < 0 || world == nullptr) {
    return -1;
  }
  const std::int32_t playerId = Field<std::int32_t>(player, 0x00);
  const std::int32_t id = Field<std::int32_t>(player, 0x4F0);
  const char* unit = UnitById(world, id);
  if (unit == nullptr || UnitProto(unit) != proto || Field<const char*>(unit, 0x44) != player || !IsAlive(unit)) {
    return -1;
  }
  const char* colonies = Field<const char*>(player, 0x3E0);
  bool found = false;
  if (colonies != nullptr && (Field<std::uint8_t>(colonies, 0x00) & 1) == 0) {
    const std::int32_t* indices = Field<const std::int32_t*>(colonies, 0x14);
    const char* const* list = Field<const char* const*>(colonies, 0x08);
    for (std::int32_t k = 0; k < Field<std::int32_t>(colonies, 0x18) && !found; ++k) {
      const char* colony = list[indices[k]];
      found = colony != nullptr && Field<std::int32_t>(colony, 0x28) == id;
    }
  }
  if (!found) {
    if (FirstTime(0, playerId, id)) {
      uhc::Log(L"civFirstTC: no colony starts at player %d's first town center %d (%hs): its town starting units "
               L"wait for a TownCenter (add the proto to placementrules\\colonies.xml <starttypes>)",
               playerId, id, UnitName(unit));
    }
    return -1;
  }
  if (g_log && FirstTime(1, playerId, id)) {
    uhc::Log(L"civFirstTC: player %d's town starting units go to its first town center %d (%hs)", playerId, id,
             UnitName(unit));
  }
  return proto;
}

// Replaces the call of objectDef::place at 0x925F4C (thiscall(def, player, x, z, count), ret 10h;
// x and z are floats, passed through as they are).
std::int32_t __fastcall UhcRmPlaceObjectDef(char* def, void*, std::int32_t player, std::uint32_t x, std::uint32_t z,
                                            std::uint32_t count) {
  static bool traced = false;
  if (!traced) {
    traced = true;
    UhcTraceHook("civFirstTC map placement (0x925F4C)");
  }
  const char* world = GameField(0x13C);
  const char* db = GameField(0x140);
  const std::int32_t items = def == nullptr ? 0 : Field<std::int32_t>(def, 0x0C);
  if (g_tags.empty() || world == nullptr || db == nullptr || items <= 0 || Field<std::uint8_t>(def, 0x55) != 0) {
    return kPlace(def, nullptr, player, x, z, count);
  }
  const std::int32_t townCenter = Field<std::int32_t>(db, 0x5E08);
  Item* list = Field<Item*>(def, 0x08);
  bool hasTownCenter = false;
  for (std::int32_t i = 0; i < items && !hasTownCenter; ++i) {
    hasTownCenter = list[i].proto == townCenter;
  }
  const char* owner = hasTownCenter ? PlayerById(world, player) : nullptr;
  const std::int32_t proto = owner == nullptr ? -1 : CivFirstTcProto(owner);
  if (proto < 0 || proto == townCenter) {
    return kPlace(def, nullptr, player, x, z, count);
  }
  const char* defName = Field<const char*>(def, 0x04);
  if (NomadStart()) {
    if (g_log) {
      uhc::Log(L"civFirstTC: player %d keeps TownCenter in object def %d '%hs' (Nomad start)", player,
               Field<std::int32_t>(def, 0x00), defName == nullptr ? "" : defName);
    }
    return kPlace(def, nullptr, player, x, z, count);
  }
  std::int32_t footprintX = 0;
  std::int32_t footprintZ = 0;
  Footprint(db, world, proto, &footprintX, &footprintZ);
  std::vector<Saved> saved;
  for (std::int32_t i = 0; i < items; ++i) {
    if (list[i].proto == townCenter) {
      saved.push_back({i, list[i]});
      list[i].proto = proto;
      list[i].footprintX = list[i].footprintX > footprintX ? list[i].footprintX : footprintX;
      list[i].footprintZ = list[i].footprintZ > footprintZ ? list[i].footprintZ : footprintZ;
    }
  }
  if (g_log) {
    uhc::Log(L"civFirstTC: player %d gets %hs instead of TownCenter in object def %d '%hs'", player,
             ProtoName(kProtoById(db, proto)), Field<std::int32_t>(def, 0x00), defName == nullptr ? "" : defName);
  }
  const std::int32_t placed = kPlace(def, nullptr, player, x, z, count);
  // Put the def back for the next player; place() does not add or remove items of such a def.
  list = Field<Item*>(def, 0x08);
  const std::int32_t after = Field<std::int32_t>(def, 0x0C);
  for (const Saved& entry : saved) {
    if (entry.index < after && list[entry.index].proto == proto) {
      list[entry.index] = entry.item;
    }
  }
  return placed;
}

void UhcCivFirstTcTownHook();
}

namespace uhc {

Outcome ApplyCivFirstTc(const Config& config) {
  const Config::Args* args = config.First("civFirstTC");
  const bool alias = args == nullptr;  // firstTC [UnitType] [log]: the type is startingTC's
  if (alias) {
    args = config.First("firstTC");
  }
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (!alias) {
      Log(L"civFirstTC: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  // startingTC, applied first, may already have written 0x506B3B: its bytes are then ours.
  const Site* protoCheck = FirstTcProtoHookInstalled() ? &sites::kFirstTcChunk : &sites::kFirstTcProtoCheck;
  if (!VerifyAll("civFirstTC",
                 {&sites::kCivById, &sites::kCivOfPlayer,
                  &sites::kProtoByName, &sites::kProtoById, &sites::kProtoFlag, &sites::kRmPlaceCall,
                  &sites::kRmPlace, &sites::kRmItemFootprint, &sites::kRmNomadStart, &sites::kTownStartQuery,
                  &sites::kTownStartSpawn, &sites::kTownStartColonyLoop, &sites::kFirstTcChunk, protoCheck,
                  &sites::kFirstTcSet, &sites::kPlayerById, &sites::kUnitById, &sites::kUnitAliveSlot})) {
    return Outcome::kFailed;
  }
  g_log = log;
  g_uhcCivFirstTcOn = 1;
  if (!InstallFirstTcProtoHook()) {
    g_uhcCivFirstTcOn = 0;
    return Outcome::kFailed;
  }
  // The civs.xml hook (civtags.cpp) runs after UHCMain, so every tag is seen.
  if (!AddCivTagHandler("firstTC", &ReadFirstTc)) {
    return Outcome::kFailed;
  }
  if (!WriteCall(0x00925F4C, reinterpret_cast<const void*>(&UhcRmPlaceObjectDef))) {
    return Outcome::kFailed;
  }
  // Replaces mov ebx,[ecx+5E08h] at 0x679AC8; the hook re-executes it.
  if (!WriteJmp(0x00679AC8, reinterpret_cast<const void*>(&UhcCivFirstTcTownHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"civFirstTC: a civ's <firstTC> proto in civs.xml replaces the TownCenter random maps place for its players "
      L"(not in a Nomad start) and is their first town center (FirstTC)%ls (multiplayer unverified)",
      log ? L", every substitution logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/civfirsttc_hooks.asm

```asm
; Hooks for civFirstTC. Entered through a jmp written over the stock code; each leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Civ first town center"). The
; FirstTC test is in startingtc_hooks.asm (UhcStartingTcProtoHook), shared with startingTC, and the
; map placement wrapper is C++ (UhcRmPlaceObjectDef in features/civfirsttc.cpp).
.686
.model flat, c
option casemap :none

include common.inc

UhcCivTagDispatch PROTO STDCALL node:DWORD, civ:DWORD  ; civtags.cpp; true: a registered tag, consumed
UhcCivFirstTcTownProto PROTO STDCALL player:DWORD      ; the proto for the town units, or -1

.data
civTagResume    dd 0052BB0Fh    ; jle 52B43Dh / jmp 52C066h: the stock unknown-tag path, on the flags
civTagNext      dd 0052B43Dh    ; the next child of the <civ> node
townQueryResume dd 00679ACEh    ; push ebp / push esi / mov esi,[edi+80h]: the query of proto EBX

.code

; Replaces 0x52BB07..0x52BB0E (xor edi,edi / cmp dword ptr [ebx+80h],edi) in the civs.xml
; parser FUN_0052A590: a child tag of <civ> that matched none of the stock names. ESI = the node,
; EBX = database, [esp+10h] = the civ. UhcCivTagDispatch (civtags.cpp, shared by civFirstTC and
; sharedBuildLimit) reads a registered tag and the hook goes to the next child, as every stock
; handler does; any other tag runs the stock path (the resource names, then a silent skip).
; 0x52B43D reads only the stack.
UhcCivTagsHook PROC
    TRACE_ONCE "civ tags civs.xml (0x52BB07)"
    pushad
    push dword ptr [esp+30h]        ; the civ: [esp+10h] at entry, +20h for pushad
    push esi                        ; the node
    call UhcCivTagDispatch
    mov dword ptr [esp+1Ch], eax    ; popad's EAX slot
    popad
    test al, al
    jne nextChild
    xor edi, edi                    ; stolen 0x52BB07
    cmp dword ptr [ebx+80h], edi    ; stolen 0x52BB09: the flags the jle at 0x52BB0F reads
    jmp civTagResume
nextChild:
    jmp civTagNext
UhcCivTagsHook ENDP

; Replaces 0x679AC8..0x679ACD (mov ebx,[ecx+5E08h]) in FUN_0049039A, which gives the civ's
; <townstartingunit> units to the first built unit of proto EBX (stock: TownCenter) when a colony
; starts at it. EDI = player. EAX, ECX and EDX are written before they are read after 0x679ACE.
; UhcCivFirstTcTownProto returns the civ's <firstTC> proto when the player's FirstTC is such a
; building with a colony; otherwise EBX stays TownCenter.
UhcCivFirstTcTownHook PROC
    TRACE_ONCE "civFirstTC town units (0x679AC8)"
    mov ebx, dword ptr [ecx+5E08h]  ; stolen 0x679AC8: TownCenter
    push edi
    call UhcCivFirstTcTownProto
    test eax, eax
    jl done
    mov ebx, eax
done:
    jmp townQueryResume
UhcCivFirstTcTownHook ENDP

END
```
