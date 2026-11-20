# Code for WoL: Civs

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [danceBonusCivs](#dancebonuscivs)
- [startingTC](#startingtc)
- [civFirstTC](#civfirsttc)
- [ageUpBuildings](#ageupbuildings)
- [politicianPlacesFix](#politicianplacesfix)
- [politicianEnablesTech](#politicianenablestech)

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

Sites: `CivById` `0x405C2E` (24 B), `PlayerById` `0x44CB21` (30 B), `UnitById` `0x44CC6D` (58 B), `ProtoById` `0x45316E` (30 B), `CivOfPlayer` `0x4539D3` (16 B), `ProtoFlag` `0x45EE02` (53 B), `FirstTcChunk` `0x506B2A` (17 B), `FirstTcProtoCheck` `0x506B3B` (17 B), `ProtoByName` `0x5A2346` (32 B), `TownStartQuery` `0x679AC1` (21 B), `TownStartSpawn` `0x679B50` (26 B), `FirstTcSet` `0x67ABD4` (14 B), `StartColonyFlagRead` `0x6A2130` (6 B), `TownStartColonyLoop` `0x7C2407` (49 B), `RmNomadStart` `0x90B683` (25 B), `RmItemFootprint` `0x924B1D` (158 B), `RmPlace` `0x925936` (111 B), `RmPlaceCall` `0x925F45` (14 B), `UnitAliveSlot` `0xB9355C` (4 B).

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

// From the test of flag 136 when a unit is created, with the key firstTC: true for the player's FirstTC
// of its civ's <firstTC> proto, which then asks for the town starting units as a TownCenter does.
bool __stdcall UhcCivFirstTcColonyFlag(const char* unit) {
  const char* player = Field<const char*>(unit, 0x44);
  return player != nullptr && !g_tags.empty() && Field<std::int32_t>(player, 0x4F0) == Field<std::int32_t>(unit, 0x10) &&
         CivFirstTcProto(player) == UnitProto(unit) && UnitProto(unit) >= 0 && !NomadStart();
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
void UhcCivFirstTcColonyHook();
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
  // firstTC derives from the tag what civFirstTC asks of the data: StartingColonyBuilding and the shipment
  // point. <starttypes> in placementrules\colonies.xml stays data.
  if (alias && (!VerifyAll("firstTC", {&sites::kStartColonyFlagRead}) ||
                !WriteJmp(sites::kStartColonyFlagRead.va, reinterpret_cast<const void*>(&UhcCivFirstTcColonyHook), 6) ||
                !AddFirstTcShipmentPoint())) {
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
UhcCivFirstTcColonyFlag PROTO STDCALL unit:DWORD       ; true: this unit counts as StartingColonyBuilding

.data
civTagResume    dd 0052BB0Fh    ; jle 52B43Dh / jmp 52C066h: the stock unknown-tag path, on the flags
civTagNext      dd 0052B43Dh    ; the next child of the <civ> node
colonyFlagResume dd 006A2136h   ; and eax,1 / mov [esp+74h],eax: the rest of the test of flag 136
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

; Replaces 0x6A2130..0x6A2135 with the key firstTC, at the creation of a unit, ESI: the test of flag 136 of its
; proto, StartingColonyBuilding. A civ's <firstTC> building counts as having it, without writing the proto,
; which every civ shares. AL is what `and eax,1` reads; EAX's other bytes do not matter there.
UhcCivFirstTcColonyHook PROC
    TRACE_ONCE "firstTC colony flag (0x6A2130)"
    mov edx, dword ptr [eax+50h]    ; stolen 0x6A2130
    mov al, byte ptr [edx+11h]      ; stolen 0x6A2133
    test al, 1
    jne done
    push eax
    push ecx
    push edx
    push esi
    call UhcCivFirstTcColonyFlag
    test al, al
    pop edx
    pop ecx
    pop eax
    je done
    or al, 1
done:
    jmp colonyFlagResume
UhcCivFirstTcColonyHook ENDP

END
```

## ageUpBuildings

Contract: [ageUpBuildings](../porting-to-another-dll.md#ageupbuildings).

Besides the core helpers, it needs: [`namelists.h`](helpers.md#name-lists).

Sites: `ProtoByName` `0x5A2346` (32 B), `AgeUpPickerTc` `0x7E6905` (16 B), `AgeUpPickerAccept` `0x7E6926` (6 B), `AgeUpPickerReject` `0x7E6A2E` (4 B), `AgeUpSelectedTc` `0x7E803F` (13 B), `AgeUpSelectedAccept` `0x7E8059` (4 B), `AgeUpSelectedReject` `0x7E8092` (4 B), `AgeUpListB` `0x819052` (5 B), `AgeUpListA` `0x81A44D` (5 B).

### src/features/ageupbuildings.cpp

```cpp
// ageUpBuildings [log] Proto ...: the age-up button opens its dialog on the listed protos too, not only on the
// Town Center, and a listed proto offers only the politicians its own proto lists.
//
// The command panel already builds the age-up button (uiPoliticianUI(unit, player, revolt)) for any unit whose proto
// lists a tech with the AgeUpgrade or RevoltTech flag. The two pickers that open the dialog, uiPoliticianUI 0x7E686E
// and uiPoliticianUIInSelected 0x7E7EC1, then refuse every unit whose player's proto is not the TownCenter
// ([db+5E08h]), for a civ that isAsianCiv(player, true) 0x454ED7 rejects (an Asian civ needs a unit of abstract type
// 16h there, for its wonders; wonderCivUnitType widens that test, this key leaves it alone). The hooks
// (hooks/ageup_hooks.asm) re-execute the TownCenter compare and, when it fails, accept a listed proto.
//
// The dialog's list builders (FUN_0081A2B8 for the European dialog, FUN_00818EE5) keep each tech status of the next
// age that 0x4C6968(status, unit) accepts: its flags, status and prerequisites, not whether the unit's proto lists
// the tech. On a listed proto the key also requires that the proto's tech list ([proto+E8h], 6-byte entries
// {word id, byte kind 1 = tech, ...}, count [proto+ECh]) holds the tech, so a building shows its own politicians.
// The chosen politician is researched by the unit the dialog was opened on (its ID [dlg+140h]).
#include <cstdint>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../namelists.h"
#include "../patch.h"

namespace {

using CanResearch = bool(__thiscall*)(void* techStatus, void* unit);
const auto kCanResearch = reinterpret_cast<CanResearch>(0x004C6968);

uhc::ProtoIdList g_ageUpProtos;
bool g_ageUpLog = false;
int g_ageUpLogged = 0;
bool g_filterLogged = false;

bool Listed(const char* proto) {
  return proto != nullptr && g_ageUpProtos.IndexOf(*reinterpret_cast<const std::int32_t*>(proto + 4)) >= 0;
}

// True if the proto's command list holds the tech (kind 1).
bool ProtoListsTech(const char* proto, std::int32_t techId) {
  const auto* entries = *reinterpret_cast<const std::uint8_t* const*>(proto + 0xE8);
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(proto + 0xEC);
  if (entries == nullptr || count <= 0) {
    return false;
  }
  for (std::int32_t i = 0; i < count; ++i) {
    const std::uint8_t* entry = entries + 6 * i;
    if (entry[2] == 1 && *reinterpret_cast<const std::uint16_t*>(entry) == static_cast<std::uint16_t>(techId)) {
      return true;
    }
  }
  return false;
}

// Replaces the builders' call 4C6968h (thiscall(status, unit), ret 4); __fastcall with an unused EDX has that frame.
bool __fastcall CanResearchHere(void* techStatus, void* /*edx*/, char* unit) {
  static bool reached = false;
  if (!reached) {
    reached = true;
    uhc::Log(L"hook reached: ageUpBuildings politician list (0x81A44D / 0x819052)");
  }
  if (!kCanResearch(techStatus, unit)) {
    return false;
  }
  const char* proto = unit == nullptr ? nullptr : *reinterpret_cast<const char* const*>(unit + 0x5C);
  if (!Listed(proto)) {
    return true;
  }
  const char* tech = *reinterpret_cast<const char* const*>(techStatus);
  if (tech == nullptr) {
    return false;
  }
  const std::int32_t techId = *reinterpret_cast<const std::int32_t*>(tech);
  const bool here = ProtoListsTech(proto, techId);
  if (g_ageUpLog && !g_filterLogged) {
    g_filterLogged = true;
    uhc::Log(L"ageUpBuildings: list filter on proto %d, first tech %d %ls",
             *reinterpret_cast<const std::int32_t*>(proto + 4), techId, here ? L"listed" : L"not listed");
  }
  return here;
}

}  // namespace

extern "C" {
void UhcAgeUpPickerTcHook();
void UhcAgeUpSelectedTcHook();

// True if the player's proto (its ID at +4, the field the stock TownCenter compare reads) is listed.
bool __stdcall UhcAgeUpListed(const char* proto) {
  if (!Listed(proto)) {
    return false;
  }
  if (g_ageUpLog && g_ageUpLogged < 50) {
    ++g_ageUpLogged;
    uhc::Log(L"ageUpBuildings: the age-up dialog opens on proto %d", *reinterpret_cast<const std::int32_t*>(proto + 4));
  }
  return true;
}
}

namespace uhc {

Outcome ApplyAgeUpBuildings(const Config& config) {
  const Config::Args* args = config.First("ageUpBuildings");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::vector<std::string> names;
  for (const std::string& arg : *args) {
    if (names.empty() && !g_ageUpLog && _stricmp(arg.c_str(), "log") == 0) {
      g_ageUpLog = true;
      continue;
    }
    names.push_back(arg);
  }
  if (names.empty()) {
    Log(L"ageUpBuildings: no proto listed");
    return Outcome::kFailed;
  }
  if (!VerifyAll("ageUpBuildings",
                 {&sites::kAgeUpPickerTc, &sites::kAgeUpPickerAccept, &sites::kAgeUpPickerReject,
                  &sites::kAgeUpSelectedTc, &sites::kAgeUpSelectedAccept, &sites::kAgeUpSelectedReject,
                  &sites::kAgeUpListA, &sites::kAgeUpListB, &sites::kProtoByName})) {
    return Outcome::kFailed;
  }
  g_ageUpProtos.Set("ageUpBuildings", names);
  if (!WriteJmp(sites::kAgeUpPickerTc.va, reinterpret_cast<const void*>(&UhcAgeUpPickerTcHook),
                sites::kAgeUpPickerTc.size) ||
      !WriteJmp(sites::kAgeUpSelectedTc.va, reinterpret_cast<const void*>(&UhcAgeUpSelectedTcHook),
                sites::kAgeUpSelectedTc.size) ||
      !WriteCall(sites::kAgeUpListA.va, reinterpret_cast<const void*>(&CanResearchHere)) ||
      !WriteCall(sites::kAgeUpListB.va, reinterpret_cast<const void*>(&CanResearchHere))) {
    return Outcome::kFailed;
  }
  Log(L"ageUpBuildings: %zu proto(s) open the age-up dialog besides the Town Center, with the politicians they list%ls",
      names.size(), g_ageUpLog ? L" (log)" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/ageup_hooks.asm

```asm
; Hooks for ageUpBuildings (src/features/ageupbuildings.cpp). Each one replaces the TownCenter compare of an age-up
; picker (reached for a civ that isAsianCiv(player, true) rejects), re-executes it, and when it fails asks the DLL
; whether the cfg lists the player's proto. It leaves through an explicit jmp to the stock accepted or rejected
; continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcAgeUpListed PROTO STDCALL playerProto:DWORD

.data
pickerAccept        dd 007E6926h   ; mov ecx,[0C67310h] (find the dialog)
pickerReject        dd 007E6A2Eh   ; pop edi / pop esi / pop ebp / pop ebx
selectedAccept      dd 007E8059h   ; mov ecx,[esp+14h] (open it for this unit)
selectedReject      dd 007E8092h   ; pop ebp / pop edi / pop esi / pop ebx

.code

; 0x7E6905 in uiPoliticianUI 0x7E686E (16 B replaced). ESI = the player's proto (not null), EDI = the database.
; EAX, ECX and EDX are free: both continuations reload what they use.
UhcAgeUpPickerTcHook PROC
    TRACE_ONCE "ageUpBuildings uiPoliticianUI (0x7E6905)"
    mov eax, dword ptr [edi+5E08h]
    cmp eax, dword ptr [esi+4]
    je accept
    push esi
    call UhcAgeUpListed
    test al, al
    jz reject
accept:
    jmp pickerAccept
reject:
    jmp pickerReject
UhcAgeUpPickerTcHook ENDP

; 0x7E803F in uiPoliticianUIInSelected 0x7E7EC1 (13 B replaced). ECX = the database, EDI = the player's proto of the
; selected unit, EBX = the player, ESI = the unit. EAX, ECX and EDX are free.
UhcAgeUpSelectedTcHook PROC
    TRACE_ONCE "ageUpBuildings uiPoliticianUIInSelected (0x7E803F)"
    mov edx, dword ptr [ecx+5E08h]
    cmp edx, dword ptr [edi+4]
    je accept
    push edi
    call UhcAgeUpListed
    test al, al
    jz reject
accept:
    jmp selectedAccept
reject:
    jmp selectedReject
UhcAgeUpSelectedTcHook ENDP

END
```

## politicianPlacesFix

Contract: [politicianPlacesFix](../porting-to-another-dll.md#politicianplacesfix).

Sites: `GadgetLookup` `0x40423C` (16 B), `TechStatusTechId` `0x58EA03` (13 B), `PoliticianPanelBind` `0x818C93` (3 B), `PoliticianNameBind` `0x818D51` (3 B), `PoliticianPlaceTake` `0x81A45A` (12 B), `PoliticianNameRead` `0x81A4FF` (17 B), `PoliticianListEnd` `0x81A848` (6 B).

### src/features/politicianplaces.cpp

```cpp
// politicianPlacesFix: the European age-up dialog shows only as many politicians as its layout has places, instead of
// crashing on the first politician that has no place.
//
// The dialog binds five places by name when it is built (0x818C5B..0x818DBD, loop to 5 at 0x818DBA): for place n,
// PoliticianDlg-Politician%d at [dlg+198h+4n], PoliticianButton%d at +1ACh, Poli%dPortrait at +1C0h,
// PoliticianHilightPositive%d at +1D4h, Poli%dName at +1E8h, Poli%dCost at +1FCh and Poli%dDescription at +210h, each a
// gadget handle that resolves to nothing when the layout file lacks that name. The European list builder FUN_0081A2B8
// keeps up to five politicians of the next age ([dlg+26Ch], cmp with 5 at 0x81A82A) and fills place n for the n-th:
// it null-checks the portrait, the name and the description, then dereferences the name gadget (EBP) without a check,
// mov eax,[ebp] at 0x81A80C (and at 0x81A63C on the revolution path). With a layout of four places, as the
// stock uipoliticianEuropeandlg.xml, a fifth obtainable politician is an access violation there.
//
// One hook (hooks/politicianplaces_hooks.asm) at 0x81A45A, where an accepted politician is about to take the next
// place: when the place has no PoliticianDlg-Politician%d gadget or no Poli%dName text gadget, the builder ends as it
// does after the fifth (0x81A848), so the dialog lists the politicians it can show. The other builders null-check every
// gadget (FUN_00818EE5) or place their entries by a fixed index of their own data (the Asian and native dialogs).
// UI only: the dialog is the local player's, and the politician chosen is sent as the stock command.
//
// The same hook serves politicianEnablesTech (AddPoliticianPlaceObserver in features.h): whichever key applies first
// writes it, and each observer sees every place a politician is about to fill.
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcPoliticianPlacesHook();

namespace {

// The UI manager's gadget by handle and type (0 any, 10h text), null when there is none; no reference is taken.
using GadgetLookup = void*(__fastcall*)(void* manager, void* edx, std::int32_t handle, std::int32_t type);
const auto kGadgetLookup = reinterpret_cast<GadgetLookup>(0x0040423C);

constexpr std::int32_t kAnyGadget = 0;
constexpr std::int32_t kTextGadget = 0x10;
constexpr int kStockPlaces = 5;
constexpr std::size_t kMaxObservers = 4;

bool g_log = false;
bool g_logged = false;
bool g_fix = false;          // politicianPlacesFix applied
bool g_hookWritten = false;  // the jmp at 0x81A45A
uhc::PoliticianPlaceObserver g_observers[kMaxObservers] = {};
std::size_t g_observerCount = 0;

bool HasGadget(void* manager, std::int32_t handle, std::int32_t type) {
  return kGadgetLookup(manager, nullptr, handle, type) != nullptr;
}

// The leading places that have both the place panel and its name text.
int PlaceCount(const char* dlg) {
  const char* ui = *reinterpret_cast<const char* const*>(0x00C66244);
  void* manager = ui == nullptr ? nullptr : *reinterpret_cast<void* const*>(ui + 0x44);
  if (manager == nullptr) {
    return 0;
  }
  int places = 0;
  for (; places < kStockPlaces; ++places) {
    const std::int32_t panel = *reinterpret_cast<const std::int32_t*>(dlg + 0x198 + 4 * places);
    const std::int32_t name = *reinterpret_cast<const std::int32_t*>(dlg + 0x1E8 + 4 * places);
    if (!HasGadget(manager, panel, kAnyGadget) || !HasGadget(manager, name, kTextGadget)) {
      break;
    }
  }
  return places;
}

std::int32_t TechId(const char* techStatus) {
  const char* tech = techStatus == nullptr ? nullptr : *reinterpret_cast<const char* const*>(techStatus);
  return tech == nullptr ? -1 : *reinterpret_cast<const std::int32_t*>(tech);
}

}  // namespace

// From the hook, for each politician the builder accepts, before it takes the next place. True: no place is left, so
// the builder ends with the politicians it has (politicianPlacesFix). Otherwise the observers (politicianEnablesTech)
// see the place the politician is about to fill.
extern "C" bool __stdcall UhcPoliticianNoPlace(char* dlg, const char* techStatus) {
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(dlg + 0x26C);
  if (g_fix) {
    const int places = PlaceCount(dlg);
    if (count >= places) {
      if (!g_logged || g_log) {
        g_logged = true;
        uhc::Log(L"politicianPlacesFix: the European age-up dialog has %d place(s); politician tech %d and any after "
                 L"it are left out (%ls)",
                 places, TechId(techStatus),
                 *reinterpret_cast<const std::uint8_t*>(dlg + 0x144) != 0 ? L"revolutions" : L"age-up");
      }
      return true;
    }
  }
  for (std::size_t i = 0; i < g_observerCount; ++i) {
    g_observers[i](dlg, techStatus, count);
  }
  return false;
}

namespace uhc {

// The hook at 0x81A45A, written once for politicianPlacesFix and the observers.
bool InstallPoliticianPlaceHook(const char* feature) {
  if (g_hookWritten) {
    return true;
  }
  if (!VerifyAll(feature, {&sites::kPoliticianPlaceTake, &sites::kPoliticianListEnd, &sites::kPoliticianPanelBind,
                           &sites::kPoliticianNameBind, &sites::kPoliticianNameRead, &sites::kTechStatusTechId,
                           &sites::kGadgetLookup}) ||
      !WriteJmp(sites::kPoliticianPlaceTake.va, reinterpret_cast<const void*>(&UhcPoliticianPlacesHook), 7)) {
    return false;
  }
  g_hookWritten = true;
  return true;
}

bool AddPoliticianPlaceObserver(PoliticianPlaceObserver observer, const char* feature) {
  if (g_observerCount == kMaxObservers || !InstallPoliticianPlaceHook(feature)) {
    return false;
  }
  g_observers[g_observerCount++] = observer;
  return true;
}

Outcome ApplyPoliticianPlacesFix(const Config& config) {
  const Config::Args* args = config.First("politicianPlacesFix");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"politicianPlacesFix: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!InstallPoliticianPlaceHook("politicianPlacesFix")) {
    return Outcome::kFailed;
  }
  g_fix = true;
  Log(L"politicianPlacesFix: the European age-up dialog lists only the politicians its layout has places for");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/politicianplaces_hooks.asm

```asm
; politicianPlacesFix (src/features/politicianplaces.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcPoliticianNoPlace PROTO STDCALL dlg:DWORD, techStatus:DWORD

.data
techIdGetter dd 0058EA03h   ; int thiscall(techStatus): the tech ID [[status]]
placeNext    dd 0081A461h   ; cmp dword [esp+24h],0, after the two instructions this hook re-executes
listEnd      dd 0081A848h   ; mov eax,[ebx+26Ch], the builder's own exit after the fifth politician

.code

; Replaces 0x81A45A..0x81A460 (mov ecx,edi / call 58EA03h) in the European politician list builder FUN_0081A2B8,
; reached for each politician the builder accepted (next age, or a revolution, and 0x4C6968 said yes), before it
; fills the next place [ebx+26Ch]. EBX = the dialog, EDI = the tech status. EAX, ECX and EDX are dead here: the
; re-executed call returns EAX and the code after it writes ECX (0x81A466) and EDX (0x81A487) before reading them.
; When the place has no gadgets, the builder ends at 0x81A848 with the stack as the loop leaves it there (no local of
; this iteration exists yet; the per-entry local is built at 0x81A559).
UhcPoliticianPlacesHook PROC
    TRACE_ONCE "politicianPlacesFix (0x81A45A)"
    push edi                        ; tech status
    push ebx                        ; dialog
    call UhcPoliticianNoPlace
    test al, al
    jne full
    mov ecx, edi
    call techIdGetter
    jmp placeNext
full:
    jmp listEnd
UhcPoliticianPlacesHook ENDP

END
```

## politicianEnablesTech

Contract: [politicianEnablesTech](../porting-to-another-dll.md#politicianenablestech).

Besides the core helpers, it needs: [`techtags.h`](helpers.md#tech-tags), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `BStringFree` `0x4010CA` (31 B), `BStringSet` `0x40196F` (36 B), `BStringFromWide` `0x401A12` (40 B), `GadgetLookupAny` `0x404296` (49 B), `GadgetRelease` `0x40431B` (44 B), `GadgetShow` `0x447F7B` (70 B), `GadgetHide` `0x448F13` (57 B), `PlayerById` `0x44CB21` (30 B), `UnitById` `0x44CC6D` (58 B), `TechStatusAt` `0x4804B3` (21 B), `TechStatusList` `0x4C5394` (24 B), `TechRolloverHead` `0x4C737C` (16 B), `BStringFromId` `0x58EA52` (25 B), `TechByName` `0x600BE1` (16 B), `GadgetSetTexture` `0x638823` (16 B), `PoliticianPortraitFill` `0x81A487` (114 B), `PoliticianDescriptionRead` `0x81A590` (57 B), `GadgetByName` `0xAB7C2F` (38 B).

### src/features/politicianenablestech.cpp

```cpp
// politicianEnablesTech [log] [flag <u> <v>]: a politician of the European age-up dialog shows the techs it makes
// available as their own icons and names, each with the tech's research rollover, from
// <PoliticianEnablesTech>TechName</PoliticianEnablesTech> children of its <Tech> (up to four). UI only: the tag enables
// nothing; the politician's own effects still do that.
//
// Data. The tags are read through the shared <Tech> node hook (techtags.h), with the <Icon> of every tech, since the
// tech record keeps only a texture handle ([NodeData+14h], set by 0x621143) and a gadget's texture is set by path. The
// names are resolved to tech IDs on the first dialog after a data load (0x600BE1).
//
// The dialog. The hook of politicianPlacesFix at 0x81A45A (AddPoliticianPlaceObserver) runs for each politician the
// European list builder FUN_0081A2B8 accepts, before it fills place n = [dlg+26Ch]. The builder then sets the
// portrait's texture from the politiciandata record (0x638823) and its texture coordinates to (0, 0, 0.75, 0.7734375)
// (vtable +D8h), and the description to the tech's RolloverTextID through the handle [dlg+210h+4n]; see the sites
// PoliticianPortraitFill and PoliticianDescriptionRead. For a politician with tags this key hides the place's
// Poli%dPortrait and Poli%dDescription and shows its own gadgets instead, which the layout file adds to the place,
// hidden:
//   PoliticianDlg-Poli%dEnablesTechPortrait     the same picture, cut to its top part (`flag`, default 0.75 0.5833:
//                                               a 145 x 231 flag in a 192 x 396 picture);
//   PoliticianDlg-Poli%dEnablesTechDescription  the description, in a box that ends above the techs: the key puts its
//                                               handle in [dlg+210h+4n], so the builder fills it (beside a DLL that
//                                               replaces the text at 0x81A5CB, with that DLL's text);
//   PoliticianDlg-Poli%dEnablesTech%dIcon/Name  one or two techs, one per row;
//   PoliticianDlg-Poli%dEnablesTechGrid%dIcon/Name  three or four techs, two per row.
// A politician without tags gets the stock gadgets back, so it looks as without the key. A layout without these
// gadgets (the stock file, the Asian and native dialogs) is left alone.
#include <windows.h>

#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../techtags.h"
#include "../unittypes.h"

namespace {

struct BString {
  wchar_t* text;
};

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // +13Ch world, +140h database, +3C0h the local player's ID
constexpr std::uint32_t kNoGadget = 0x00C672C0;    // [..]: the handle of "no gadget"
constexpr std::uint32_t kUiManager = 0x00C66244;   // [[+44h]]: the gadget manager (show / hide)
constexpr std::uint32_t kGadgetTip = 0x68;         // a gadget's help text, a BString
constexpr int kPlaces = 5;
constexpr int kMaxTags = 4;
constexpr int kListRows = 2;  // up to this many techs: one per row; more: two per row

using GadgetByNameFn = std::int32_t*(__thiscall*)(void* panel, std::int32_t* out, BString* name, std::int32_t flag);
using GadgetAnyFn = void*(__cdecl*)(std::int32_t handle);
using GadgetReleaseFn = std::int32_t(__cdecl*)(std::int32_t handle);
using GadgetShowFn = void(__thiscall*)(void* manager, std::int32_t handle);
using SetTextureFn = void(__thiscall*)(void* gadget, const BString* path);
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t id);
using BStringSetFn = void(__thiscall*)(BString* self, const BString* source);
using BStringFreeFn = void(__thiscall*)(BString* self);
using TechByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using PlayerByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using UnitByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using StatusListFn = const char*(__thiscall*)(const char* statuses, std::int32_t playerId);
using StatusAtFn = const char*(__thiscall*)(const char* list, std::int32_t index);
using RolloverFn = void(__cdecl*)(BString* text, const char* status, const char* player, const char* unit,
                                  std::int32_t a5, const void* costOverride, std::int32_t a7, std::int32_t a8);
const auto kGadgetByName = reinterpret_cast<GadgetByNameFn>(0x00AB7C2F);
const auto kGadgetAny = reinterpret_cast<GadgetAnyFn>(0x00404296);
const auto kGadgetRelease = reinterpret_cast<GadgetReleaseFn>(0x0040431B);
const auto kGadgetShow = reinterpret_cast<GadgetShowFn>(0x00447F7B);
const auto kGadgetHide = reinterpret_cast<GadgetShowFn>(0x00448F13);
const auto kSetTexture = reinterpret_cast<SetTextureFn>(0x00638823);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringSet = reinterpret_cast<BStringSetFn>(0x0040196F);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kTechByName = reinterpret_cast<TechByNameFn>(0x00600BE1);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kStatusList = reinterpret_cast<StatusListFn>(0x004C5394);
const auto kStatusAt = reinterpret_cast<StatusAtFn>(0x004804B3);
const auto kRollover = reinterpret_cast<RolloverFn>(0x004C737C);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

template <typename Fn>
Fn VirtualAt(const void* object, std::uint32_t offset) {
  return reinterpret_cast<Fn>((*reinterpret_cast<void* const* const*>(object))[offset / 4]);
}

bool g_log = false;
float g_flagU = 0.75f;
float g_flagV = 0.5833f;  // 231 of 396 rows

// Read with the data: each politician's name and tags in file order, and every tech's <Icon>, by lowercase tech name.
struct Politician {
  std::wstring name;
  std::vector<std::wstring> tags;
};
std::map<std::wstring, Politician> g_tagNames;
std::map<std::wstring, std::wstring> g_icons;
// Resolved on the first dialog after a load: politician tech ID -> enabled tech IDs.
std::map<std::int32_t, std::vector<std::int32_t>> g_tags;
std::map<std::int32_t, std::wstring> g_iconById;
bool g_resolved = false;
bool g_loggedLayout = false;

std::wstring Lower(const wchar_t* text) {
  std::wstring out = text == nullptr ? L"" : text;
  for (wchar_t& c : out) {
    c = static_cast<wchar_t>(towlower(c));
  }
  return out;
}

std::wstring Trim(const wchar_t* text) {
  std::wstring out = text == nullptr ? L"" : text;
  const std::size_t first = out.find_first_not_of(L" \t\r\n");
  if (first == std::wstring::npos) {
    return {};
  }
  return out.substr(first, out.find_last_not_of(L" \t\r\n") - first + 1);
}

std::string Narrow(const std::wstring& text) {
  std::string out;
  for (wchar_t c : text) {
    out.push_back(c < 0x80 ? static_cast<char>(c) : '?');
  }
  return out;
}

void NewDatabase(char*) {
  g_tagNames.clear();
  g_icons.clear();
  g_tags.clear();
  g_iconById.clear();
  g_resolved = false;
}

void TagRead(const char*, const wchar_t* techName, const wchar_t* text) {
  const std::wstring name = Trim(text);
  if (name.empty()) {
    uhc::Log(L"politicianEnablesTech: an empty <PoliticianEnablesTech> in tech %ls; ignored", techName);
    return;
  }
  Politician& politician = g_tagNames[Lower(techName)];
  politician.name = techName == nullptr ? L"" : techName;
  politician.tags.push_back(name);
}

void IconRead(const char*, const wchar_t* techName, const wchar_t* text) {
  const std::wstring icon = Trim(text);
  if (!icon.empty()) {
    g_icons[Lower(techName)] = icon;
  }
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

void Resolve() {
  g_resolved = true;
  const char* database = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x140);
  if (database == nullptr) {
    return;
  }
  int politicians = 0;
  int tags = 0;
  for (const auto& entry : g_tagNames) {
    const std::int32_t politician = kTechByName(database, Narrow(entry.second.name).c_str());
    if (politician < 0) {
      uhc::Log(L"politicianEnablesTech: tech %ls not found by its name; its tags are left out",
               entry.second.name.c_str());
      continue;
    }
    std::vector<std::int32_t>& list = g_tags[politician];
    for (const std::wstring& name : entry.second.tags) {
      const std::int32_t id = kTechByName(database, Narrow(name).c_str());
      if (id < 0) {
        uhc::Log(L"politicianEnablesTech: <PoliticianEnablesTech>%ls</PoliticianEnablesTech> in tech %ls: no such "
                 L"tech; left out",
                 name.c_str(), entry.second.name.c_str());
        continue;
      }
      if (static_cast<int>(list.size()) == kMaxTags) {
        uhc::Log(L"politicianEnablesTech: tech %ls has more than %d <PoliticianEnablesTech>; %ls and any after it are "
                 L"left out",
                 entry.second.name.c_str(), kMaxTags, name.c_str());
        break;
      }
      list.push_back(id);
      const auto icon = g_icons.find(Lower(name.c_str()));
      if (icon != g_icons.end()) {
        g_iconById[id] = icon->second;
      }
      ++tags;
    }
    ++politicians;
  }
  uhc::Log(L"politicianEnablesTech: %d politician(s) with %d <PoliticianEnablesTech> tag(s)", politicians, tags);
}

bool Valid(std::int32_t handle) { return handle != 0 && handle != *reinterpret_cast<const std::int32_t*>(kNoGadget); }

std::int32_t Lookup(void* panel, const wchar_t* format, int a, int b = 0) {
  wchar_t name[96];
  swprintf_s(name, format, a, b);
  BString text{nullptr};
  kBStringFromWide(&text, name);
  std::int32_t handle = 0;
  kGadgetByName(panel, &handle, &text, 1);
  kBStringFree(&text);
  return Valid(handle) ? handle : 0;
}

// The gadget object behind a handle (any type), the reference released at once as the stock code does.
void* Object(std::int32_t handle) {
  if (handle == 0) {
    return nullptr;
  }
  void* object = kGadgetAny(handle);
  if (object != nullptr) {
    kGadgetRelease(handle);
  }
  return object;
}

void Show(std::int32_t handle, bool visible) {
  const char* ui = *reinterpret_cast<const char* const*>(kUiManager);
  void* manager = ui == nullptr ? nullptr : Field<void*>(ui, 0x44);
  if (manager != nullptr && handle != 0) {
    (visible ? kGadgetShow : kGadgetHide)(manager, handle);
  }
}

void SetText(std::int32_t handle, const BString& text, const BString* tip) {
  void* object = Object(handle);
  if (object == nullptr) {
    return;
  }
  VirtualAt<void(__thiscall*)(void*, const BString*)>(object, 0x80)(object, &text);
  if (tip != nullptr) {
    kBStringSet(reinterpret_cast<BString*>(static_cast<char*>(object) + kGadgetTip), tip);
  }
}

void SetTip(std::int32_t handle, const BString* tip) {
  void* object = Object(handle);
  if (object != nullptr && tip != nullptr) {
    kBStringSet(reinterpret_cast<BString*>(static_cast<char*>(object) + kGadgetTip), tip);
  }
}

// The player's tech status of a tech: the list 0x4C5394 is indexed by tech ID in the games seen; a search otherwise.
const char* StatusOf(const char* world, std::int32_t playerId, std::int32_t techId) {
  const char* statuses = Field<const char*>(world, 0x7C);
  const char* list = statuses == nullptr ? nullptr : kStatusList(statuses, playerId);
  if (list == nullptr) {
    return nullptr;
  }
  const std::int32_t count = Field<std::int32_t>(list, 0x08);
  auto idOf = [](const char* status) {
    const char* data = status == nullptr ? nullptr : Field<const char*>(status, 0);
    return data == nullptr ? -1 : Field<std::int32_t>(data, 0);
  };
  if (techId >= 0 && techId < count && idOf(kStatusAt(list, techId)) == techId) {
    return kStatusAt(list, techId);
  }
  for (std::int32_t i = 0; i < count; ++i) {
    const char* status = kStatusAt(list, i);
    if (idOf(status) == techId) {
      return status;
    }
  }
  return nullptr;
}

struct Place {
  std::int32_t portrait = 0, description = 0;          // the stock gadgets
  std::int32_t myPortrait = 0, myDescription = 0;      // this key's
  std::int32_t icon[kListRows] = {}, name[kListRows] = {};
  std::int32_t gridIcon[kMaxTags] = {}, gridName[kMaxTags] = {};
};

Place PlaceGadgets(const char* dlg, void* panel, int n) {
  Place place;
  place.portrait = Field<std::int32_t>(dlg, 0x1C0 + 4 * n);
  // By name: the dialog's own slot may hold this key's box from an earlier opening.
  place.description = Lookup(panel, L"PoliticianDlg-Poli%dDescription", n);
  if (place.description == 0) {
    place.description = Field<std::int32_t>(dlg, 0x210 + 4 * n);
  }
  place.myPortrait = Lookup(panel, L"PoliticianDlg-Poli%dEnablesTechPortrait", n);
  place.myDescription = Lookup(panel, L"PoliticianDlg-Poli%dEnablesTechDescription", n);
  for (int k = 0; k < kListRows; ++k) {
    place.icon[k] = Lookup(panel, L"PoliticianDlg-Poli%dEnablesTech%dIcon", n, k);
    place.name[k] = Lookup(panel, L"PoliticianDlg-Poli%dEnablesTech%dName", n, k);
  }
  for (int k = 0; k < kMaxTags; ++k) {
    place.gridIcon[k] = Lookup(panel, L"PoliticianDlg-Poli%dEnablesTechGrid%dIcon", n, k);
    place.gridName[k] = Lookup(panel, L"PoliticianDlg-Poli%dEnablesTechGrid%dName", n, k);
  }
  return place;
}

void HideOurs(const Place& place) {
  Show(place.myPortrait, false);
  Show(place.myDescription, false);
  for (int k = 0; k < kListRows; ++k) {
    Show(place.icon[k], false);
    Show(place.name[k], false);
  }
  for (int k = 0; k < kMaxTags; ++k) {
    Show(place.gridIcon[k], false);
    Show(place.gridName[k], false);
  }
}

// The politiciandata record of a tech: [dlg+18Ch] records of 14h bytes, +0 the tech ID, +4 the portrait path, count
// [dlg+190h] (the builder's own match, 0x81A487..0x81A49D).
const BString* PortraitOf(const char* dlg, std::int32_t techId) {
  const char* records = Field<const char*>(dlg, 0x18C);
  const std::int32_t count = Field<std::int32_t>(dlg, 0x190);
  for (std::int32_t i = 0; records != nullptr && i < count; ++i) {
    if (Field<std::int32_t>(records, 0x14 * i) == techId) {
      return reinterpret_cast<const BString*>(records + 0x14 * i + 4);
    }
  }
  return nullptr;
}

void FillTech(std::int32_t iconHandle, std::int32_t nameHandle, std::int32_t techId, const char* world,
              const char* player, std::int32_t playerId, const char* unit) {
  const char* status = StatusOf(world, playerId, techId);
  const char* data = status == nullptr ? nullptr : Field<const char*>(status, 0);
  BString name{nullptr};
  if (data != nullptr) {
    kBStringFromId(&name, Field<std::int32_t>(data, 0x08));
  } else {
    kBStringFromWide(&name, L"?");
  }
  // The tooltip: the tech button's own rollover (the command panel's call 0x4622C5 passes 1, 0, 1, 1).
  BString tip{nullptr};
  kBStringFromWide(&tip, L"");
  if (status != nullptr) {
    kRollover(&tip, status, player, unit, 1, nullptr, 1, 1);
  }
  if (tip.text == nullptr || tip.text[0] == 0) {
    kBStringFree(&tip);
    if (data != nullptr) {
      kBStringFromId(&tip, Field<std::int32_t>(data, 0x0C));
    } else {
      kBStringFromWide(&tip, L"");
    }
  }
  SetText(nameHandle, name, &tip);
  Show(nameHandle, true);
  const auto icon = g_iconById.find(techId);
  void* iconObject = Object(iconHandle);
  if (iconObject != nullptr && icon != g_iconById.end()) {
    BString path{nullptr};
    kBStringFromWide(&path, icon->second.c_str());
    kSetTexture(iconObject, &path);
    kBStringFree(&path);
    SetTip(iconHandle, &tip);
    Show(iconHandle, true);
  } else {
    Show(iconHandle, false);
  }
  if (g_log) {
    uhc::Log(L"politicianEnablesTech: tech %d: '%ls', icon %ls", techId, name.text == nullptr ? L"" : name.text,
             icon == g_iconById.end() ? L"(none)" : icon->second.c_str());
  }
  kBStringFree(&name);
  kBStringFree(&tip);
}

// From politicianPlacesFix's hook: the politician `status` is about to fill place `n` of the European dialog.
void PlaceFilled(char* dlg, const char* techStatus, int n) {
  if (n < 0 || n >= kPlaces || techStatus == nullptr) {
    return;
  }
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr) {
    return;
  }
  const std::int32_t rootHandle = Field<std::int32_t>(dlg, 0x148);
  void* panel = Object(rootHandle);
  if (panel == nullptr) {
    return;
  }
  const Place place = PlaceGadgets(dlg, panel, n);
  const bool layout = place.myPortrait != 0 && place.myDescription != 0 && place.icon[0] != 0 && place.name[0] != 0;
  if (!g_loggedLayout) {
    g_loggedLayout = true;
    uhc::Log(L"politicianEnablesTech: the age-up dialog %ls this key's gadgets", layout ? L"has" : L"does not have");
  }
  if (!layout) {
    return;
  }
  if (!g_resolved) {
    Resolve();
  }
  const char* data = Field<const char*>(techStatus, 0);
  const std::int32_t techId = data == nullptr ? -1 : Field<std::int32_t>(data, 0);
  const auto found = g_tags.find(techId);
  HideOurs(place);
  // The description the builder fills next: [dlg+210h+4n] (read at 0x81A596). A tagged politician's goes to this
  // key's shorter box, so the text is whatever fills it (the RolloverTextID in stock, another DLL's own text beside
  // it); any other politician's goes back to the stock box.
  std::int32_t* descriptionSlot = reinterpret_cast<std::int32_t*>(dlg + 0x210 + 4 * n);
  if (found == g_tags.end() || found->second.empty()) {
    *descriptionSlot = place.description;
    Show(place.portrait, true);
    Show(place.description, true);
    return;
  }
  const std::vector<std::int32_t>& techs = found->second;
  Show(place.portrait, false);
  Show(place.description, false);
  *descriptionSlot = place.myDescription;

  // The portrait's top part, from the picture the builder is about to give the stock portrait.
  if (void* portrait = Object(place.myPortrait)) {
    if (const BString* path = PortraitOf(dlg, techId)) {
      kSetTexture(portrait, path);
      VirtualAt<void(__thiscall*)(void*, float, float, float, float)>(portrait, 0xD8)(portrait, 0.0f, 0.0f, g_flagU,
                                                                                         g_flagV);
    }
    Show(place.myPortrait, true);
  }
  Show(place.myDescription, true);

  const std::int32_t playerId = Field<std::int32_t>(dlg, 0x13C);
  const char* player = kPlayerById(world, playerId);
  const char* unit = kUnitById(world, Field<std::int32_t>(dlg, 0x140));
  const bool list = static_cast<int>(techs.size()) <= kListRows || place.gridIcon[0] == 0;
  const int shown = list ? (static_cast<int>(techs.size()) < kListRows ? static_cast<int>(techs.size()) : kListRows)
                         : static_cast<int>(techs.size());
  for (int k = 0; k < shown; ++k) {
    FillTech(list ? place.icon[k] : place.gridIcon[k], list ? place.name[k] : place.gridName[k], techs[k], world,
             player, playerId, unit);
  }
  if (g_log) {
    uhc::Log(L"politicianEnablesTech: place %d, politician tech %d, %d tech(s) (%ls)", n, techId, shown,
             list ? L"one per row" : L"two per row");
  }
}

}  // namespace

namespace uhc {

Outcome ApplyPoliticianEnablesTech(const Config& config) {
  const Config::Args* args = config.First("politicianEnablesTech");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (std::size_t i = 0; i < args->size(); ++i) {
    const std::string& arg = (*args)[i];
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "flag") == 0 && i + 2 < args->size()) {
      const float u = static_cast<float>(std::atof((*args)[i + 1].c_str()));
      const float v = static_cast<float>(std::atof((*args)[i + 2].c_str()));
      if (u <= 0.0f || u > 1.0f || v <= 0.0f || v > 1.0f) {
        Log(L"politicianEnablesTech: flag %hs %hs: each must be above 0 and at most 1; feature not applied",
            (*args)[i + 1].c_str(), (*args)[i + 2].c_str());
        return Outcome::kFailed;
      }
      g_flagU = u;
      g_flagV = v;
      i += 2;
    } else {
      Log(L"politicianEnablesTech: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("politicianEnablesTech",
                 {&sites::kPoliticianPortraitFill, &sites::kPoliticianDescriptionRead, &sites::kGadgetSetTexture,
                  &sites::kTechStatusList, &sites::kTechStatusAt, &sites::kTechRolloverHead, &sites::kTechByName,
                  &sites::kPlayerById, &sites::kUnitById, &sites::kGadgetByName, &sites::kGadgetLookupAny,
                  &sites::kGadgetRelease, &sites::kGadgetShow, &sites::kGadgetHide, &sites::kBStringFromWide,
                  &sites::kBStringFromId, &sites::kBStringSet, &sites::kBStringFree}) ||
      !OnDatabaseLoad(&NewDatabase) || !AddTechTagHandler("PoliticianEnablesTech", &TagRead) ||
      !AddTechTagHandler("Icon", &IconRead) || !AddPoliticianPlaceObserver(&PlaceFilled, "politicianEnablesTech")) {
    return Outcome::kFailed;
  }
  Log(L"politicianEnablesTech: the European age-up dialog shows each politician's <PoliticianEnablesTech> techs "
      L"(flag %.4f x %.4f)",
      static_cast<double>(g_flagU), static_cast<double>(g_flagV));
  return Outcome::kApplied;
}

}  // namespace uhc
```
