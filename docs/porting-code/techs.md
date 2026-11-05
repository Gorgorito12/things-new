# Code for WoL: Techs and transforms

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [techPrereqRecheck](#techprereqrecheck)
- [transformUpdatesLOS](#transformupdateslos)
- [transformSpan](#transformspan)
- [transformInventory](#transforminventory)

## techPrereqRecheck

Contract: [techPrereqRecheck](../porting-to-another-dll.md#techprereqrecheck).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `TechTemplateFallback` `0x48050F` (27 B), `WorldStepCount` `0x481A87` (15 B), `TechStatusUpdateCall` `0x481D3D` (25 B), `TechPrereqDirtyCheck` `0x491A18` (10 B), `TechPrereqNoPass` `0x491A22` (10 B), `TechPrereqListLoop` `0x50946A` (74 B), `TechPrereqListEval` `0x5094B4` (36 B), `TechPrereqEntryUpdate` `0x5094EB` (81 B), `TechPrereqPassLoop` `0x5095A1` (119 B), `TechPrereqPassEntry` `0x5096D4` (9 B), `TechNameById` `0x5C400B` (25 B), `TechTemplateLoop` `0x61FE63` (60 B), `PrereqBaseCtor` `0x6201AA` (22 B), `TypeCountCtor` `0x8EE860` (16 B), `TypeCountEval` `0x8EE8E7` (52 B).

### src/features/techprereq.cpp

```cpp
// techPrereqRecheck: tech prerequisites on unit counts (techtree <TypeCount>) follow the units.
//
// Stock evaluates a tech's <Prereqs> only in the re-check pass of the player's tech tree
// (0x5096D4), which FUN_004919CE enters at 0x491A18 when the tree's dirty byte [tree+10h] is
// set. Tech status changes, age-ups, home city levels and pop cap changes set it (0x506A41 and an
// inline copy in 0x506A5F); creating or killing a unit without PopulationCapAddition never does.
// A <TypeCount> prerequisite (a count of the player's units, read through the player's KB) is
// therefore noticed only at the player's next such event, typically the next house.
//
// techPrereqRecheck jumps at 0x491A18. On the player's turn (every N world updates, scheduled on
// the world's step count) it evaluates, for each tech whose definition has a TypeCount
// prerequisite, the prerequisite list with the stock evaluator 0x5094B4, as the pass does, and
// compares the result with the cached "prerequisites met" bit 3 of the player's status entry. On
// a difference it sets the dirty byte, so the stock pass runs in the same call, exactly as after
// a house is built: auto-activation, Volatile toggles, the AI's tech list and the UI are the
// stock ones. "full" sets the dirty byte on every turn instead (a whole stock pass every N
// updates), for cost measurements. The hook is in hooks/techprereq_hooks.asm.
#include <windows.h>

#include <charconv>
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

// Engine layout (docs/engine-symbols.md, "Tech prerequisites").
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint32_t kMaxEvery = 1000000;
constexpr std::size_t kMaxListedTechs = 100;  // scan lines per data load; the rest are counted

// bool thiscall(PrereqList* = def+1Ch, Player*, bool orPrereqs), ret 8: ANDs (or ORs) the
// prerequisites through their vtable slot +8. Its only stock caller is 0x509537.
using PrereqListMetFn = bool(__thiscall*)(char* list, char* player, std::int32_t orPrereqs);
const auto kPrereqListMet = reinterpret_cast<PrereqListMetFn>(0x005094B4);

template <typename T>
T& Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<T*>(const_cast<char*>(base) + offset);
}

char* Game() { return *reinterpret_cast<char**>(kGameGlobal); }

// "techPrereqRecheck [N] [full] [log]".
std::uint32_t g_every = 1;
bool g_full = false;
bool g_log = false;

// Tech IDs whose definition has a TypeCount prerequisite, ascending; rebuilt once per data load.
std::vector<std::int32_t> g_techs;
bool g_scanned = false;
const char* g_scanDatabase = nullptr;
const char* g_scanTemplates = nullptr;
std::int32_t g_scanTemplateCount = -1;

bool g_loggedFirstFlip = false;

// "log": counters of the current game minute, written when the minute changes.
std::uint32_t g_minute = 0xFFFFFFFF;
std::uint32_t g_checks = 0;
std::uint32_t g_evaluations = 0;
std::uint32_t g_flips = 0;
std::uint32_t g_fullPasses = 0;
std::int64_t g_ticks = 0;
double g_ticksPerMicrosecond = 0.0;

// Tech names: [db+3824h] is an array of wide strings, one per tech ID, [db+3828h] the count
// (the getter 0x5C400B).
const wchar_t* TechName(const char* database, std::int32_t id) {
  const wchar_t* const* names = Field<const wchar_t* const*>(database, 0x3824);
  if (names == nullptr || id < 0 || id >= Field<std::int32_t>(database, 0x3828)) {
    return L"?";
  }
  return names[id] != nullptr ? names[id] : L"?";
}

// A tech definition's prerequisites: array at def+1Ch, its length in the byte def+20h, null
// slots skipped (0x50946A). A prerequisite's type is the byte [p+5] (base ctor 0x6201AA); the
// TypeCount ctor 0x8EE860 passes 0.
int TypeCountPrereqs(const char* def) {
  const std::uint8_t length = Field<std::uint8_t>(def, 0x20);
  const char* const* list = Field<const char* const*>(def, 0x1C);
  int count = 0;
  for (std::uint8_t i = 0; list != nullptr && i < length; ++i) {
    if (list[i] != nullptr && Field<std::uint8_t>(list[i], 0x05) == 0) {
      ++count;
    }
  }
  return count;
}

// Lists the techs to watch from the template status records, [[db+5D9Ch]+0Ch], 24h bytes each,
// count [+10h] (0x48050F, 0x61FE63); a record's +0 is the tech's definition, the same one every
// player's status entry points to.
void Scan(char* database, const char* templates, std::int32_t templateCount) {
  g_techs.clear();
  g_scanned = true;
  g_scanDatabase = database;
  g_scanTemplates = templates;
  g_scanTemplateCount = templateCount;
  const char* records = templates == nullptr ? nullptr : Field<const char*>(templates, 0x0C);
  int prereqs = 0;
  for (std::int32_t id = 0; records != nullptr && id < templateCount; ++id) {
    const char* def = Field<const char*>(records, 0x24 * static_cast<std::uint32_t>(id));
    const int found = def == nullptr ? 0 : TypeCountPrereqs(def);
    if (found > 0) {
      g_techs.push_back(id);
      prereqs += found;
    }
  }
  uhc::Log(L"techPrereqRecheck: %u tech(s) of %d have TypeCount prerequisites (%d in all)%ls",
           static_cast<unsigned>(g_techs.size()), templateCount, prereqs,
           g_techs.empty() ? L"; nothing to re-check" : L"");
  for (std::size_t i = 0; i < g_techs.size() && i < kMaxListedTechs; ++i) {
    const char* def = Field<const char*>(records, 0x24 * static_cast<std::uint32_t>(g_techs[i]));
    uhc::Log(L"techPrereqRecheck:   tech %d (%ls), %d TypeCount prerequisite(s)", g_techs[i],
             TechName(database, g_techs[i]), TypeCountPrereqs(def));
  }
  if (g_techs.size() > kMaxListedTechs) {
    uhc::Log(L"techPrereqRecheck:   and %u more", static_cast<unsigned>(g_techs.size() - kMaxListedTechs));
  }
}

// From the database load hook (unittypes.h): the next check scans the new techtree.
void ResetForDataLoad(char*) { g_scanned = false; }

void FlushMinute(std::uint32_t minute) {
  if (g_minute != 0xFFFFFFFF && minute != g_minute) {
    uhc::Log(L"techPrereqRecheck: game minute %u: %u check(s), %u evaluation(s), %u re-check(s) started, "
             L"%u full pass(es) requested, %.0f us in checks",
             g_minute, g_checks, g_evaluations, g_flips, g_fullPasses,
             g_ticksPerMicrosecond > 0.0 ? static_cast<double>(g_ticks) / g_ticksPerMicrosecond : 0.0);
    g_checks = g_evaluations = g_flips = g_fullPasses = 0;
    g_ticks = 0;
  }
  g_minute = minute;
}

// One player's turn of the targeted check. Returns after the first tech whose prerequisites
// changed, with the dirty byte set: the stock pass re-evaluates every tech anyway.
void CheckTechs(char* techTree, char* player, const char* world, const char* database) {
  const char* const* entries = Field<const char* const*>(techTree, 0x04);
  const std::int32_t entryCount = Field<std::int32_t>(techTree, 0x08);
  for (const std::int32_t id : g_techs) {
    if (entries == nullptr || id >= entryCount) {
      break;
    }
    // Status entry: +0 definition, +4 bit array, +8 bit count. A null entry is created (and
    // evaluated) by the stock pass when the tech becomes relevant to the player, and every
    // status change that creates one also sets the dirty byte.
    const char* entry = entries[id];
    if (entry == nullptr) {
      continue;
    }
    const char* def = Field<const char*>(entry, 0x00);
    const std::uint8_t* bits = Field<const std::uint8_t*>(entry, 0x04);
    const std::uint32_t bitCount = Field<std::uint32_t>(entry, 0x08);
    if (def == nullptr || bits == nullptr || bitCount <= 3 ||
        (Field<std::uint8_t>(def, 0x20) != 0 && Field<const void*>(def, 0x1C) == nullptr)) {
      continue;
    }
    // As 0x5094EB: bit 3 is the cached result, bit 21 the OrPrereqs flag.
    const bool cached = (bits[0] & 0x08) != 0;
    const bool orPrereqs = bitCount > 21 && (bits[2] & 0x20) != 0;
    ++g_evaluations;
    const bool met = kPrereqListMet(const_cast<char*>(def) + 0x1C, player, orPrereqs ? 1 : 0);
    if (met != cached) {
      Field<std::uint8_t>(techTree, 0x10) = 1;
      ++g_flips;
      if (g_log || !g_loggedFirstFlip) {
        uhc::Log(L"techPrereqRecheck: player %d, tech %d (%ls): prerequisites %ls; stock re-check at step %u, game "
                 L"time %u ms%ls",
                 Field<std::int32_t>(player, 0x00), id, TechName(database, id), met ? L"now met" : L"no longer met",
                 Field<std::uint32_t>(world, 0xF8), Field<std::uint32_t>(world, 0x108),
                 g_log ? L"" : L" (add log to see every re-check)");
        g_loggedFirstFlip = true;
      }
      return;
    }
  }
}

}  // namespace

extern "C" {

void UhcTechPrereqHook();

// From the hook at 0x491A18, before the stock dirty test: techTree = EDI, player = EBP (non-null,
// tested at 0x4919D6). Reads only simulation state, so every machine makes the same choice.
void __stdcall UhcTechPrereqMaybeMark(char* techTree, char* player) {
  if (techTree == nullptr || player == nullptr || Field<std::uint8_t>(techTree, 0x10) != 0) {
    return;  // already dirty: the stock pass runs anyway
  }
  char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  char* database = game == nullptr ? nullptr : Field<char*>(game, 0x140);
  // [player+80h] is the player's KB; TypeCount (0x8EE8E7) uses it without a null check.
  if (world == nullptr || database == nullptr || Field<const char*>(player, 0x80) == nullptr) {
    return;
  }
  LARGE_INTEGER start{};
  if (g_log) {
    FlushMinute(Field<std::uint32_t>(world, 0x108) / 60000);
    QueryPerformanceCounter(&start);
  }
  // The player's turn: a stateless schedule on the step count [world+F8h], +1 per world update
  // (0x481A87), offset by the player ID so the players' turns are spread over the N updates.
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const auto playerId = static_cast<std::uint32_t>(Field<std::int32_t>(player, 0x00));
  if (g_every <= 1 || (step + playerId) % g_every == 0) {
    ++g_checks;
    if (g_full) {
      Field<std::uint8_t>(techTree, 0x10) = 1;
      ++g_fullPasses;
    } else {
      const char* templates = Field<const char*>(database, 0x5D9C);
      const std::int32_t templateCount = templates == nullptr ? 0 : Field<std::int32_t>(templates, 0x10);
      if (!g_scanned || database != g_scanDatabase || templates != g_scanTemplates ||
          templateCount != g_scanTemplateCount) {
        Scan(database, templates, templateCount);
      }
      CheckTechs(techTree, player, world, database);
    }
  }
  if (g_log) {
    LARGE_INTEGER end{};
    QueryPerformanceCounter(&end);
    g_ticks += end.QuadPart - start.QuadPart;
  }
}
}

namespace uhc {

namespace {

bool ParseEvery(const std::string& text, std::uint32_t* every) {
  std::uint32_t value = 0;
  const char* first = text.data();
  const char* last = first + text.size();
  const auto [end, error] = std::from_chars(first, last, value);
  if (error != std::errc() || end != last || value < 1 || value > kMaxEvery) {
    return false;
  }
  *every = value;
  return true;
}

}  // namespace

Outcome ApplyTechPrereqRecheck(const Config& config) {
  const Config::Args* args = config.First("techPrereqRecheck");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::uint32_t every = 1;
  bool everyGiven = false;
  bool full = false;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (_stricmp(arg.c_str(), "full") == 0) {
      full = true;
    } else if (!everyGiven && ParseEvery(arg, &every)) {
      everyGiven = true;
    } else {
      Log(L"techPrereqRecheck: unexpected argument %hs (expected: [N] [full] [log], N a whole number of world "
          L"updates from 1 to %u); feature not applied",
          arg.c_str(), kMaxEvery);
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("techPrereqRecheck",
                 {&sites::kTechPrereqDirtyCheck, &sites::kTechPrereqNoPass, &sites::kTechPrereqPassEntry,
                  &sites::kTechPrereqPassLoop, &sites::kTechPrereqEntryUpdate, &sites::kTechPrereqListEval,
                  &sites::kTechPrereqListLoop, &sites::kTypeCountCtor, &sites::kPrereqBaseCtor,
                  &sites::kTypeCountEval, &sites::kTechTemplateFallback, &sites::kTechTemplateLoop,
                  &sites::kTechNameById, &sites::kTechStatusUpdateCall, &sites::kWorldStepCount})) {
    return Outcome::kFailed;
  }
  g_every = every;
  g_full = full;
  g_log = log;
  if (log) {
    LARGE_INTEGER frequency{};
    if (QueryPerformanceFrequency(&frequency) && frequency.QuadPart > 0) {
      g_ticksPerMicrosecond = static_cast<double>(frequency.QuadPart) / 1e6;
    }
  }
  // The scan follows the data; the full mode does not use it.
  if (!full && !OnDatabaseLoad(&ResetForDataLoad)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kTechPrereqDirtyCheck.va, reinterpret_cast<const void*>(&UhcTechPrereqHook), 10)) {
    return Outcome::kFailed;
  }
  if (full) {
    Log(L"techPrereqRecheck: full: the stock re-check of every tech runs every %u world update(s) for each player%ls "
        L"(multiplayer unverified)",
        every, log ? L"; a summary is logged every game minute" : L"");
  } else {
    Log(L"techPrereqRecheck: techs with TypeCount prerequisites are re-checked every %u world update(s); a change "
        L"starts the stock re-check%ls (multiplayer unverified)",
        every, log ? L"; every re-check and a summary every game minute are logged" : L"");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/techprereq_hooks.asm

```asm
; Hook for techPrereqRecheck. Entered through a jmp written over the stock dirty test of a
; player's tech tree; leaves through an explicit jmp to one of the test's two verified
; continuations (docs/engine-symbols.md, "Tech prerequisites").
.686
.model flat, c
option casemap :none

include common.inc

UhcTechPrereqMaybeMark PROTO STDCALL techTree:DWORD, player:DWORD

.data
recheckPass     dd 005096D4h    ; xor esi,esi / cmp [edi+8],esi / mov byte [edi+10h],0: the stock re-check
noRecheck       dd 00491A22h    ; pop esi / pop ebx / pop edi / pop ebp / add esp,0Ch / ret 4

.code

; Replaces 0x491A18..0x491A21 (cmp byte ptr [edi+10h],0 / jne 5096D4h) in FUN_004919CE, the
; per-player tech tree update, thiscall(tree, Player*), run for each live player on every world
; update. EDI = the tree, EBP = the player (non-null); ESI, EBX, EDI and EBP are pushed below the
; return address and the 0Ch locals. The C++ check may set the dirty byte [edi+10h]; the stock
; test then runs as written, so a set byte enters the stock re-check of every tech in this same
; call. Every register is preserved, and the flags are those of the re-executed cmp, as in stock.
UhcTechPrereqHook PROC
    TRACE_ONCE "techPrereqRecheck (0x491A18)"
    pushad
    push ebp                        ; Player*
    push edi                        ; the player's tech tree
    call UhcTechPrereqMaybeMark
    popad
    cmp byte ptr [edi+10h], 0       ; stolen 0x491A18
    jne recheck                     ; stolen 0x491A1C: jne 5096D4h
    jmp noRecheck
recheck:
    jmp recheckPass
UhcTechPrereqHook ENDP

END
```

## transformUpdatesLOS

Contract: [transformUpdatesLOS](../porting-to-another-dll.md#transformupdateslos).

Sites: `LosGetter` `0x48207E` (32 B), `LosBuildCopyRead` `0x6A20B2` (8 B), `LosBuildCopyWrite` `0x6A20ED` (16 B), `TransformProtoLookup` `0x9C754C` (22 B), `TransformVisRemove` `0x9C756A` (11 B), `TransformPushProto` `0x9C763C` (3 B), `TransformSetProto` `0x9C763F` (14 B), `TransformVisAdd` `0x9C772A` (11 B).

### src/features/transform.cpp

```cpp
// transformUpdatesLOS: a unit that changes proto in place takes the line of sight of its new proto.
//
// Each unit has its own base LOS at [[unit+B4h]+90h]. Stock copies it from the proto's <LOS>
// ([proto+48h]) when the unit is created, when it is built, and when a tech changes that proto's
// LOS. FUN_009C754C changes a live unit into another proto (TransformUnit tech effects, the
// revolution, the construction-object transforms): it takes the unit off the visibility map,
// calls setProto 0x4981F3, rebuilds its HP, build points and obstruction, and puts it back on the
// map, but never copies the new proto's LOS. The unit keeps the old proto's LOS until something
// else resets it. The hook (hooks/transform_hooks.asm) runs just before setProto, between the
// visibility remove and add, as build completion FUN_006A1F82 does: a unit whose LOS still equals
// its old proto's takes the new proto's (the player's copy, so its LOS techs count). A unit with
// another value (a foundation's footprint LOS, a knocked-out hero's 6) keeps it.
//
// Units that a transform replaces with a new unit (uiTransformSelectedUnit, e.g. wall -> gate) get
// the new proto's LOS in stock and never reach the hook. trUnitChangeProtoUnit takes another path
// too: in game the unit kept its ID, already had the new LOS and never reached the hook.
#include <bit>
#include <cstdint>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

bool g_log = false;  // "transformUpdatesLOS log": one line per unit transformed in place

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

// LOS values are compared and copied as raw dwords, as stock copies them: no float operation
// touches the simulation.
float AsFloat(std::uint32_t bits) {
  return std::bit_cast<float>(bits);
}

}  // namespace

extern "C" {
void UhcTransformLosHook();

// Called by the hook at 0x9C763F with the unit and the proto setProto is about to install;
// [unit+5Ch] is still the old proto.
void __stdcall UhcTransformLos(char* unit, const char* newProto) {
  const char* oldProto = Field<const char*>(unit, 0x5C);
  char* block = Field<char*>(unit, 0xB4);
  if (oldProto == nullptr || newProto == nullptr || block == nullptr) {
    return;
  }
  const std::uint32_t unitLos = Field<std::uint32_t>(block, 0x90);
  const std::uint32_t oldLos = Field<std::uint32_t>(oldProto, 0x48);
  const std::uint32_t newLos = Field<std::uint32_t>(newProto, 0x48);
  if (unitLos != oldLos) {
    if (g_log) {
      uhc::Log(L"transformUpdatesLOS: unit %d (%hs -> %hs) keeps its own LOS %.6g (its proto's is %.6g)",
               Field<std::int32_t>(unit, 0x10), ProtoName(oldProto), ProtoName(newProto),
               static_cast<double>(AsFloat(unitLos)), static_cast<double>(AsFloat(oldLos)));
    }
    return;
  }
  *reinterpret_cast<std::uint32_t*>(block + 0x90) = newLos;
  if (g_log) {
    uhc::Log(L"transformUpdatesLOS: unit %d (%hs -> %hs) LOS %.6g -> %.6g", Field<std::int32_t>(unit, 0x10),
             ProtoName(oldProto), ProtoName(newProto), static_cast<double>(AsFloat(unitLos)),
             static_cast<double>(AsFloat(newLos)));
  }
}
}

namespace uhc {

Outcome ApplyTransformUpdatesLos(const Config& config) {
  const Config::Args* args = config.First("transformUpdatesLOS");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"transformUpdatesLOS: unknown argument %hs (expected: log); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  g_log = log;
  if (!VerifyAll("transformUpdatesLOS",
                 {&sites::kTransformSetProto, &sites::kTransformProtoLookup, &sites::kTransformPushProto,
                  &sites::kTransformVisRemove, &sites::kTransformVisAdd, &sites::kLosBuildCopyRead,
                  &sites::kLosBuildCopyWrite, &sites::kLosGetter})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kTransformSetProto.va, reinterpret_cast<const void*>(&UhcTransformLosHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"transformUpdatesLOS: units transformed in place (TransformUnit, revolution) take their new proto's "
      L"LOS%ls (multiplayer unverified)",
      log ? L", every transform logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/transform_hooks.asm

```asm
; Hook for transformUpdatesLOS. Entered through a jmp written over the stock code; leaves through
; an explicit jmp to a verified continuation (docs/engine-symbols.md, "Line of sight and
; transforms").
.686
.model flat, c
option casemap :none

include common.inc

UhcTransformLos PROTO STDCALL unit:DWORD, newProto:DWORD

.data
setProto        dd 004981F3h    ; void thiscall(unit, Proto* proto), ret 4: writes [unit+5Ch]
transformNext   dd 009C7644h    ; mov ecx,[esi+5Ch] / push esi / call 8F7AD2h

.code

; Replaces the call 4981F3h (setProto) at 0x9C763F in FUN_009C754C, where a unit changes proto in
; place. ESI = ECX = the unit, [esp] = the new proto (the player's copy, pushed at 0x9C763C from
; EBP), [esi+5Ch] = the old proto. The unit left the visibility map at 0x9C7570 with its old LOS
; and goes back on it at 0x9C7730 with whatever [[esi+B4h]+90h] holds then, so the C++ helper
; writes the new proto's LOS there first. Every register is preserved for the stolen call;
; afterwards EAX, ECX, EDX and the flags are what setProto leaves, as in stock.
UhcTransformLosHook PROC
    TRACE_ONCE "transformUpdatesLOS (0x9C763F)"
    pushad
    push dword ptr [esp+20h]        ; the new proto, setProto's argument (above the 8 saved registers)
    push esi                        ; the unit
    call UhcTransformLos
    popad
    call setProto                   ; stolen 0x9C763F: ECX = unit, the argument is still at [esp]
    jmp transformNext
UhcTransformLosHook ENDP

END
```

## transformSpan

Contract: [transformSpan](../porting-to-another-dll.md#transformspan).

Besides the core helpers, it needs: [`modifiers.h`](helpers.md#modifier-walk), [`worldtick.h`](helpers.md#world-tick).

Sites: `XmlText` `0x402733` (9 B), `SnareApply` `0x4DD22D` (130 B), `XmlAttribute` `0x598F37` (16 B), `TransformEffectCall` `0x7FBC79` (5 B), `TransformProtoLookup` `0x9C754C` (22 B), `TransformEffectSetDataSlot` `0xB96B64` (4 B), `TransformEffectApplySlot` `0xB96B9C` (4 B).

### src/features/transformspan.cpp

```cpp
// transformSpan: the attribute transformspan="<seconds>" on a TransformUnit effect: when the time ends,
// the units that effect transformed turn back into what they were.
//
// Stock's TransformUnit (apply 0x7FBBAF) changes each alive, built unit of fromprotoid in place with
// 0x9C754C, which keeps the unit's ID, and nothing ever turns it back. The key reads the attribute
// in a wrapper of the effect's setData slot, knows which effect is running through a wrapper of its
// apply slot, and records each unit in the wrapper of the call 0x7FBC79. A world tick turns the unit
// back with the same 0x9C754C, so whatever that function keeps (HP by proportion, transformInventory,
// transformUpdatesLOS) applies both ways.
//
// A unit is turned back only if it is still alive, built, and of the proto this key gave it: a unit
// transformed again by something else stays what it is. A second transformspan on a pending unit
// keeps the first proto and the new end, and a TransformUnit without the attribute ends the pending
// one.
//
// Saved games: the table lives in this DLL, so a copy of each entry lives on the unit, as two modifiers
// of stats nothing reads (the unit's actions are in the save). When another game is running (see
// SyncWorld) the table is rebuilt from them. A modifier's value is written in place, which is the
// only write here into a unit's actions; it runs in the simulation on every machine.
#include <cstdint>
#include <cstdlib>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifiers.h"
#include "../patch.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr std::uint32_t kApplyCall = 0x007FBC79;   // call 0x9C754C in the effect's apply
constexpr std::int32_t kStatFrom = 0x60;           // a modifier's value: the proto to go back to
constexpr std::int32_t kStatEnd = 0x61;            // the game time to do it, in tenths of a second
constexpr std::int32_t kMarkerExtraMs = 5000;      // the marker outlives the entry by this
constexpr float kDoneMarker = -1.0f;
constexpr int kMaxLogLines = 200;

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
using SetDataFn = bool(__thiscall*)(void* effect, const void* node);
using ApplyFn = void(__thiscall*)(void* effect, void* a, void* b, void* c, void* d);
using TransformFn = void(__thiscall*)(char* unit, std::int32_t proto);
using ModifierFn = std::int32_t(__thiscall*)(char* unit, std::int32_t stat, float value, float, float, std::int32_t,
                                             std::int32_t operation, std::int32_t ms, std::int32_t, std::int32_t,
                                             std::int32_t exclusive);
using IsBuiltFn = bool(__thiscall*)(const char* unit);
using IsAliveFn = bool(__thiscall*)(const char* unit);

const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
const auto kTransform = reinterpret_cast<TransformFn>(0x009C754C);
const auto kModifier = reinterpret_cast<ModifierFn>(0x004DD22D);
const auto kIsBuilt = reinterpret_cast<IsBuiltFn>(0x0044DDB4);

struct Pending {
  std::int32_t unit;
  std::int32_t from;
  std::int32_t to;
  std::uint32_t end;  // game time, ms
};

SetDataFn g_setData = nullptr;
ApplyFn g_apply = nullptr;
std::unordered_map<const void*, std::int32_t> g_spans;  // effect -> ms; written while the data loads
std::vector<Pending> g_pending;                         // in the order the effects ran
std::int32_t g_runningSpan = 0;                         // of the effect in its apply
std::uint32_t g_nextEnd = 0;
const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* World() {
  const char* game = Field<const char*>(reinterpret_cast<const char*>(kGameGlobal), 0);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

bool Reached(std::uint32_t now, std::uint32_t time) { return static_cast<std::int32_t>(now - time) >= 0; }

bool LogLine() {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return false;
  }
  ++g_logLines;
  return true;
}

// Units by ID: [world+0Ch] array, [world+10h] count; the low 18 bits index the array and [unit+10h]
// must equal the full ID.
char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char**>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

std::int32_t ProtoId(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  return proto == nullptr ? -1 : Field<std::int32_t>(proto, 8);
}

bool Alive(const char* unit) {
  const auto alive = Field<IsAliveFn>(Field<const char*>(unit, 0), 0xA4);
  return alive(unit);
}

// The marker of that stat on a unit, or nullptr. Its value is at +68h.
char* FindMarker(const char* unit, std::int32_t stat) {
  const char* list = uhc::modifiers::ModifierList(unit);
  if (list == nullptr) {
    return nullptr;
  }
  char* found = nullptr;
  auto visit = [&](const char* action) {
    if (Field<std::int32_t>(action, 0x64) != stat) {
      return true;
    }
    found = const_cast<char*>(action);
    return false;
  };
  uhc::modifiers::WalkModifiers(list, visit, 0);
  return found;
}

void SetMarker(char* unit, std::int32_t stat, float value, std::int32_t ms) {
  if (char* marker = FindMarker(unit, stat)) {
    *reinterpret_cast<float*>(marker + 0x68) = value;
    return;
  }
  kModifier(unit, stat, value, -1.0f, -1.0f, 0, 1, ms, -1, -1, 0);
}

void UpdateNextEnd() {
  if (g_pending.empty()) {
    return;
  }
  g_nextEnd = g_pending.front().end;
  for (const Pending& entry : g_pending) {
    if (static_cast<std::int32_t>(entry.end - g_nextEnd) < 0) {
      g_nextEnd = entry.end;
    }
  }
}

// The table again, from the markers of a game that just started or loaded.
void Rebuild(const char* world) {
  g_pending.clear();
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* units = Field<char* const*>(world, 0x0C);
  for (std::int32_t i = 0; i < count; ++i) {
    const char* unit = units[i];
    if (unit == nullptr) {
      continue;
    }
    const char* from = FindMarker(unit, kStatFrom);
    const char* end = from == nullptr ? nullptr : FindMarker(unit, kStatEnd);
    if (end == nullptr || Field<float>(from, 0x68) < 0.0f) {
      continue;
    }
    g_pending.push_back({Field<std::int32_t>(unit, 0x10), static_cast<std::int32_t>(Field<float>(from, 0x68)),
                         ProtoId(unit), static_cast<std::uint32_t>(Field<float>(end, 0x68)) * 100});
  }
  UpdateNextEnd();
  if (!g_pending.empty()) {
    uhc::Log(L"transformSpan: %u pending unit(s) found in the saved game", static_cast<unsigned>(g_pending.size()));
  }
}

// A new or loaded game can reuse the old world's address, so the test is the step count [world+F8h],
// which rises by 1 per step, and the game time going back. The tick sees every step.
void SyncWorld(const char* world, std::uint32_t now) {
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  if (world != g_world || !Reached(now, g_lastTime) || step - g_lastStep > 1) {
    g_world = world;
    Rebuild(world);
  }
  g_lastTime = now;
  g_lastStep = step;
}

void TurnBack(const char* world, const Pending& entry) {
  char* unit = UnitById(world, entry.unit);
  if (unit == nullptr || !Alive(unit)) {
    if (LogLine()) {
      uhc::Log(L"transformSpan: unit %d is gone", entry.unit);
    }
    return;
  }
  if (char* marker = FindMarker(unit, kStatFrom)) {
    *reinterpret_cast<float*>(marker + 0x68) = kDoneMarker;
  }
  if (ProtoId(unit) != entry.to) {
    if (LogLine()) {
      uhc::Log(L"transformSpan: unit %d is proto %d now, not %d: left as it is", entry.unit, ProtoId(unit), entry.to);
    }
    return;
  }
  kTransform(unit, entry.from);
  if (LogLine()) {
    uhc::Log(L"transformSpan: unit %d turned back, proto %d -> %d, game time %.1f s", entry.unit, entry.to, ProtoId(unit),
             static_cast<double>(Field<std::uint32_t>(world, 0x108)) / 1000.0);
  }
}

void Tick(char* world, std::int32_t) {
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  SyncWorld(world, now);
  if (g_pending.empty() || !Reached(now, g_nextEnd)) {
    return;
  }
  std::vector<Pending> due;
  std::size_t kept = 0;
  for (const Pending& entry : g_pending) {
    if (Reached(now, entry.end)) {
      due.push_back(entry);
    } else {
      g_pending[kept++] = entry;
    }
  }
  g_pending.resize(kept);
  UpdateNextEnd();
  for (const Pending& entry : due) {
    TurnBack(world, entry);
  }
}

bool __fastcall SetData(void* effect, void*, const void* node) {
  const bool ok = g_setData(effect, node);
  const void* text = nullptr;
  if (ok && node != nullptr && kXmlAttribute(node, "transformspan", &text) && text != nullptr) {
    const double seconds = std::atof(kXmlText(text));
    if (seconds > 0.0) {
      g_spans[effect] = static_cast<std::int32_t>(seconds * 1000.0 + 0.5);
      if (g_log) {
        uhc::Log(L"transformSpan: an effect lasts %.1f s", seconds);
      }
    }
  }
  return ok;
}

void __fastcall Apply(void* effect, void*, void* a, void* b, void* c, void* d) {
  const auto found = g_spans.find(effect);
  g_runningSpan = found == g_spans.end() ? 0 : found->second;
  g_apply(effect, a, b, c, d);
  g_runningSpan = 0;
}

// Replaces the call of 0x9C754C in the effect's apply.
void __fastcall Transform(char* unit, void*, std::int32_t proto) {
  const std::int32_t was = ProtoId(unit);
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  Pending* pending = nullptr;
  for (Pending& entry : g_pending) {
    if (entry.unit == id) {
      pending = &entry;
    }
  }
  kTransform(unit, proto);
  if (g_runningSpan == 0) {
    if (pending != nullptr) {  // a lasting transform ends the timed one
      if (char* marker = FindMarker(unit, kStatFrom)) {
        *reinterpret_cast<float*>(marker + 0x68) = kDoneMarker;
      }
      g_pending.erase(g_pending.begin() + (pending - g_pending.data()));
      UpdateNextEnd();
    }
    return;
  }
  const char* world = World();
  if (world == nullptr) {
    return;
  }
  const std::uint32_t end = Field<std::uint32_t>(world, 0x108) + static_cast<std::uint32_t>(g_runningSpan);
  const std::int32_t from = pending != nullptr ? pending->from : was;
  if (pending != nullptr) {
    pending->to = proto;
    pending->end = end;
  } else {
    g_pending.push_back({id, from, proto, end});
  }
  UpdateNextEnd();
  // The markers go on after the transform: they must outlive anything it rebuilds.
  const std::int32_t markerMs = g_runningSpan + kMarkerExtraMs;
  SetMarker(unit, kStatFrom, static_cast<float>(from), markerMs);
  SetMarker(unit, kStatEnd, static_cast<float>((end + 99) / 100), markerMs);
  if (LogLine()) {
    uhc::Log(L"transformSpan: unit %d, proto %d -> %d, back to %d in %.1f s, at game time %.1f s", id, was, proto, from,
             static_cast<double>(g_runningSpan) / 1000.0, static_cast<double>(end - g_runningSpan) / 1000.0);
  }
}

}  // namespace

namespace uhc {

Outcome ApplyTransformSpan(const Config& config) {
  const Config::Args* args = config.First("transformSpan");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"transformSpan: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("transformSpan", {&sites::kTransformEffectSetDataSlot, &sites::kTransformEffectApplySlot,
                                   &sites::kTransformEffectCall, &sites::kSnareApply, &sites::kXmlAttribute,
                                   &sites::kXmlText, &sites::kTransformProtoLookup})) {
    return Outcome::kFailed;
  }
  g_setData = *reinterpret_cast<SetDataFn*>(sites::kTransformEffectSetDataSlot.va);
  g_apply = *reinterpret_cast<ApplyFn*>(sites::kTransformEffectApplySlot.va);
  if (!WriteDword(sites::kTransformEffectSetDataSlot.va, reinterpret_cast<std::uintptr_t>(&SetData)) ||
      !WriteDword(sites::kTransformEffectApplySlot.va, reinterpret_cast<std::uintptr_t>(&Apply)) ||
      !WriteCall(kApplyCall, reinterpret_cast<const void*>(&Transform)) || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  Log(L"transformSpan: TransformUnit effects take transformspan");
  return Outcome::kApplied;
}

}  // namespace uhc
```

## transformInventory

Contract: [transformInventory](../porting-to-another-dll.md#transforminventory).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `IsA` `0x44D7FA` (105 B), `ResListCopy` `0x480A73` (73 B), `ResListScale` `0x480B94` (126 B), `InventoryFree` `0x4BA757` (80 B), `ResListTotal` `0x58EF02` (129 B), `InventorySeed` `0x67DE0D` (30 B), `InventoryRecreate` `0x9BFE5A` (110 B), `TransformProtoLookup` `0x9C754C` (22 B), `TransformKbRemove` `0x9C75CF` (86 B), `TransformInvHook` `0x9C7625` (23 B), `TransformPushProto` `0x9C763C` (3 B), `TransformKbReAdd` `0x9C766F` (35 B).

### src/features/transforminv.cpp

```cpp
// transformInventory: a unit that changes proto in place takes the resource inventory of its new
// proto, as if it had been created as that proto.
//
// Each unit with resources has its own inventory at [[unit+B4h]+94h], a pool object: +0 the unit
// ID, +4 a resource list, +0Ch and +10h -1 (+10h forces the type a gatherer takes). Unit creation
// seeds it from the proto's resource object [proto+E0h], whose InitialResource list is at +0
// (0x67DE0D: FUN_009BFE5A makes a fresh inventory, 0x480A73 copies the list). Gathering, the AI
// knowledge bases and the DieAtZeroResources check all read the inventory, never the proto.
// FUN_009C754C changes a live unit into another proto (TransformUnit tech effects, the
// revolution, construction-object transforms) but never touches the inventory: the unit keeps
// its old proto's resource types and amounts, or has none at all. A coin crate turned into an
// XP crate still pays gold; a unit with no inventory turned into a crate cannot be gathered. A
// later conversion makes it worse: the owner change 0x514358 rescales each amount by
// newInit[r] / oldInit[r] of the same proto, and zeroes every type its InitialResource lacks.
//
// The hook (hooks/transforminv_hooks.asm) runs at 0x9C7625, after the other players' knowledge
// bases have dropped the unit and before they take it back, and before setHP's checkState. A unit
// whose old and new protos list the same resource types keeps its inventory (a fattened sheep
// turned into a cow keeps its food), unless "all" is given. Any other unit gets the new proto's
// InitialResource: an existing inventory is reused (no gatherer keeps a dangling pointer) with
// its +0Ch/+10h reset to -1, a missing one is made with FUN_009BFE5A. "scale" keeps the fraction
// not yet gathered. A new proto with no resource object leaves the unit as in stock; with "all"
// its inventory is freed, as trUnitChangeProtoUnit does (0x4729D0). Units already gathering the
// target keep their old resource type, so after a cross-type rebuild they stop at their next
// gather tick and must be re-tasked.
#include <bit>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

// A resource list is 8 bytes: +0 an array of [kResourceCount] floats, entry r XORed with the dword
// at kEntryKeys + 4r; +4 their total, XORed with [kTotalKey] (ResList total recompute 0x58EF02).
constexpr std::uint32_t kTotalKey = 0x00C6DF10;
constexpr std::uint32_t kEntryKeys = 0x00C6DF14;
constexpr std::uint32_t kResourceCount = 0x00C6DF38;
constexpr std::int32_t kMaxResources = 64;  // a larger count means the globals are not what we expect
constexpr float kEpsilon = 1e-6f;           // the engine's "holds this resource" threshold (0xBA1388)

using RecreateInventoryFn = char*(__thiscall*)(char* unit);
using ResListCopyFn = void*(__thiscall*)(char* dst, const char* src);
using ResListScaleFn = void(__thiscall*)(char* list, float factor);
using FreeInventoryFn = void(__cdecl*)(char* inventory);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kRecreateInventory = reinterpret_cast<RecreateInventoryFn>(0x009BFE5A);
const auto kResListCopy = reinterpret_cast<ResListCopyFn>(0x00480A73);
const auto kResListScale = reinterpret_cast<ResListScaleFn>(0x00480B94);
const auto kFreeInventory = reinterpret_cast<FreeInventoryFn>(0x004BA757);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

bool g_all = false;          // "all": rebuild same-type inventories too, free them when the new proto has none
bool g_scale = false;        // "scale": keep the fraction of the old InitialResource not yet gathered
bool g_log = false;          // "log": one line per unit whose inventory the hook looks at
bool g_typeGiven = false;    // "[UnitType]": only transforms into protos of this unit type
std::int32_t g_type = -1;    // its ID, set on each database load

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

template <typename T>
void SetField(char* base, std::uint32_t offset, T value) {
  *reinterpret_cast<T*>(base + offset) = value;
}

std::uint32_t Global(std::uint32_t va) {
  return *reinterpret_cast<const std::uint32_t*>(static_cast<std::uintptr_t>(va));
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

// Entry r of a resource list, decoded as ResList get 0x44EFFF does; 0 if the list has no array.
// Only raw dwords and float compares: no float arithmetic touches the simulation here.
float Amount(const char* list, std::int32_t r) {
  const auto* entries = Field<const std::uint32_t*>(list, 0);
  if (entries == nullptr) {
    return 0.0f;
  }
  return std::bit_cast<float>(entries[r] ^ Global(kEntryKeys + 4u * static_cast<std::uint32_t>(r)));
}

float Total(const char* list) {
  return std::bit_cast<float>(Field<std::uint32_t>(list, 4) ^ Global(kTotalKey));
}

// True if both lists hold the same resource types (an amount above the engine's threshold).
bool SameTypes(const char* a, const char* b, std::int32_t count) {
  for (std::int32_t r = 0; r < count; ++r) {
    if ((Amount(a, r) > kEpsilon) != (Amount(b, r) > kEpsilon)) {
      return false;
    }
  }
  return true;
}

// "{0: 100, 2: 50}": the resource IDs and amounts a list holds; "none" for no inventory.
std::wstring Describe(const char* list, std::int32_t count) {
  if (list == nullptr) {
    return L"none";
  }
  std::wstring text = L"{";
  for (std::int32_t r = 0; r < count; ++r) {
    const float amount = Amount(list, r);
    if (amount > kEpsilon || amount < -kEpsilon) {
      wchar_t item[48];
      std::swprintf(item, 48, L"%ls%d: %.6g", text.size() > 1 ? L", " : L"", r, static_cast<double>(amount));
      text += item;
    }
  }
  return text + L"}";
}

}  // namespace

extern "C" {
void UhcTransformInventoryHook();

// Called by the hook at 0x9C7625 with the unit and the proto setProto is about to install (the
// player's copy); [unit+5Ch] is still the old proto.
void __stdcall UhcTransformInventory(char* unit, const char* newProto) {
  char* block = Field<char*>(unit, 0xB4);
  if (block == nullptr || newProto == nullptr) {
    return;
  }
  if (g_typeGiven && (g_type < 0 || !kProtoIsType(newProto, g_type))) {
    return;
  }
  const auto count = static_cast<std::int32_t>(Global(kResourceCount));
  if (count < 0 || count > kMaxResources) {
    return;
  }
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const char* oldProto = Field<const char*>(unit, 0x5C);
  const char* oldRes = oldProto == nullptr ? nullptr : Field<const char*>(oldProto, 0xE0);
  const char* newRes = Field<const char*>(newProto, 0xE0);
  char* inventory = Field<char*>(block, 0x94);

  if (newRes == nullptr) {
    if (inventory == nullptr) {
      return;  // no resources before or after: nothing to do
    }
    if (!g_all) {
      if (g_log) {
        uhc::Log(L"transformInventory: unit %d (%hs -> %hs) keeps its inventory %ls (the new proto has no "
                 L"resources; \"all\" frees it)",
                 id, ProtoName(oldProto), ProtoName(newProto), Describe(inventory + 4, count).c_str());
      }
      return;
    }
    const std::wstring before = g_log ? Describe(inventory + 4, count) : std::wstring();
    kFreeInventory(inventory);  // as 0x4BA74C / 0x4BA7A7 do for trUnitChangeProtoUnit
    SetField<char*>(block, 0x94, nullptr);
    if (g_log) {
      uhc::Log(L"transformInventory: unit %d (%hs -> %hs) inventory freed: %ls -> none", id, ProtoName(oldProto),
               ProtoName(newProto), before.c_str());
    }
    return;
  }

  if (!g_all && inventory != nullptr && oldRes != nullptr && SameTypes(oldRes, newRes, count)) {
    if (g_log) {
      uhc::Log(L"transformInventory: unit %d (%hs -> %hs) keeps its inventory %ls (same resource types)", id,
               ProtoName(oldProto), ProtoName(newProto), Describe(inventory + 4, count).c_str());
    }
    return;
  }

  // The fraction of the old InitialResource still in the inventory, read before the copy. Single
  // precision division of two game values: the same result on every machine with this build.
  float factor = 1.0f;
  if (g_scale && inventory != nullptr && oldRes != nullptr) {
    const float oldTotal = Total(oldRes);
    if (oldTotal > kEpsilon) {
      factor = Total(inventory + 4) / oldTotal;
      if (!(factor >= 0.0f)) {
        factor = 0.0f;
      } else if (factor > 1.0f) {
        factor = 1.0f;
      }
    }
  }

  const bool created = inventory == nullptr;
  const std::wstring before = g_log && !created ? Describe(inventory + 4, count) : std::wstring(L"none");
  if (created) {
    inventory = kRecreateInventory(unit);  // as unit creation does at 0x67DE0F
    if (inventory == nullptr) {
      if (g_log) {
        uhc::Log(L"transformInventory: unit %d (%hs -> %hs) got no inventory (pool exhausted)", id,
                 ProtoName(oldProto), ProtoName(newProto));
      }
      return;
    }
  } else {
    SetField<std::int32_t>(inventory, 0x0C, -1);  // as a fresh inventory from 0x86A865
    SetField<std::int32_t>(inventory, 0x10, -1);
  }
  kResListCopy(inventory + 4, newRes);  // raw encoded entries and the total, as at 0x67DE26
  if (factor < 1.0f) {
    kResListScale(inventory + 4, factor);
  }
  if (g_log) {
    wchar_t scaled[48] = L"";
    if (factor < 1.0f) {
      std::swprintf(scaled, 48, L" (scaled by %.6g)", static_cast<double>(factor));
    }
    uhc::Log(L"transformInventory: unit %d (%hs -> %hs) inventory %ls: %ls -> %ls%ls", id, ProtoName(oldProto),
             ProtoName(newProto), created ? L"created" : L"rebuilt", before.c_str(),
             Describe(inventory + 4, count).c_str(), scaled);
  }
}
}

namespace uhc {

Outcome ApplyTransformInventory(const Config& config) {
  const Config::Args* args = config.First("transformInventory");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool all = false;
  bool scale = false;
  bool log = false;
  std::string typeName;
  bool typeGiven = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "all") == 0) {
      all = true;
    } else if (_stricmp(arg.c_str(), "scale") == 0) {
      scale = true;
    } else if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (!typeGiven) {
      typeName = arg;
      typeGiven = true;
    } else {
      Log(L"transformInventory: unexpected argument %hs (expected: [all] [scale] [UnitType] [log]); feature not "
          L"applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }

  // Not kTransformSetProto: transformUpdatesLOS writes its jmp there.
  if (!VerifyAll("transformInventory",
                 {&sites::kTransformInvHook, &sites::kTransformProtoLookup, &sites::kTransformKbRemove,
                  &sites::kTransformPushProto, &sites::kTransformKbReAdd, &sites::kInventorySeed,
                  &sites::kInventoryRecreate, &sites::kInventoryFree, &sites::kResListCopy, &sites::kResListScale,
                  &sites::kResListTotal, &sites::kIsA})) {
    return Outcome::kFailed;
  }
  if (typeGiven && !RequestAbstractUnitType(typeName.c_str(), &g_type)) {
    return Outcome::kFailed;
  }
  g_all = all;
  g_scale = scale;
  g_log = log;
  g_typeGiven = typeGiven;
  if (!WriteJmp(sites::kTransformInvHook.va, reinterpret_cast<const void*>(&UhcTransformInventoryHook), 7)) {
    return Outcome::kFailed;
  }
  Log(L"transformInventory: units transformed in place (TransformUnit, revolution)%hs%hs take their new proto's "
      L"InitialResource %ls%ls%ls (multiplayer unverified)",
      typeGiven ? " into protos of unittype " : "", typeGiven ? typeName.c_str() : "",
      all ? L"always, and lose their inventory when it has none" : L"when the resource types differ",
      scale ? L", scaled by the fraction left" : L"", log ? L", every transform logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/transforminv_hooks.asm

```asm
; Hook for transformInventory. Entered through a jmp written over the stock code; leaves through
; an explicit jmp to a verified continuation (docs/engine-symbols.md, "Resource inventories").
.686
.model flat, c
option casemap :none

include common.inc

UhcTransformInventory PROTO STDCALL unit:DWORD, newProto:DWORD

.data
transformActions    dd 009C762Ch    ; push eax / call 4BA630h / add esp,4 / mov dword [esi+58h],0
transformSetProto   dd 009C763Ch    ; push ebp / mov ecx,esi / call 4981F3h (setProto)

.code

; Replaces 0x9C7625..0x9C762B (mov eax,[esi+58h] / test eax,eax / je 9C763Ch) in FUN_009C754C,
; where a unit changes proto in place. ESI = the unit, EBP = the new proto (the player's copy,
; from 0x9C7560, unchanged until 0x9C764D), [esi+5Ch] = the old proto. The other players'
; knowledge bases dropped the unit at 0x9C75FE (reading its old resource type) and take it back at
; 0x9C768D (reading its amounts); setHP's checkState runs at 0x9C76F3. The C++ helper gives the
; unit its new proto's inventory in between. Every register is preserved for the stolen code; the
; flags are dead after its je, which the hook re-executes, and the x87 stack is empty here.
UhcTransformInventoryHook PROC
    TRACE_ONCE "transformInventory (0x9C7625)"
    pushad
    push ebp                        ; the new proto
    push esi                        ; the unit
    call UhcTransformInventory
    popad
    mov eax, dword ptr [esi+58h]    ; stolen 0x9C7625: the unit's action manager
    test eax, eax                   ; stolen 0x9C7628
    je noActions                    ; stolen 0x9C762A (je 9C763Ch)
    jmp transformActions            ; 0x9C762C: push eax / call 4BA630h (needs EAX = [esi+58h])
noActions:
    jmp transformSetProto
UhcTransformInventoryHook ENDP

END
```
