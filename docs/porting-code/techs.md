# Code for WoL: Techs and transforms

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [hcTargetTechs](#hctargettechs)
- [techPrereqRecheck](#techprereqrecheck)
- [orPrereqsQty](#orprereqsqty)
- [shipmentCounts](#shipmentcounts)
- [ageFiveShipments](#agefiveshipments)
- [Tech flags](#tech-flags)
- [Card tags](#card-tags)
- [resendableCards](#resendablecards)
- [quickArrivalCards](#quickarrivalcards)
- [kothTimer](#kothtimer)
- [transformUpdatesLOS](#transformupdateslos)
- [transformSpan](#transformspan)
- [transformInventory](#transforminventory)
- [garrisonConvert](#garrisonconvert)

## hcTargetTechs

Contract: [hcTargetTechs](../porting-to-another-dll.md#hctargettechs).

Sites: `IsEnemyHead` `0x484D2D` (6 B), `TechApplyCall` `0x94D0AE` (5 B), `TechRemoveHead` `0x94DCB2` (6 B), `TechLoadHead` `0x94DDEA` (7 B).

### src/features/hctargets.cpp

```cpp
// hcTargetTechs: <Flag>HCTargetEnemy</Flag> and <Flag>HCTargetAll</Flag> on a tech send its effects to
// the owner's enemies, or to every player, instead of to the owner.
//
// A team tech keeps its list inside three routines: applyEffects 0x94DAE1, removeEffects 0x94DCB2 and the
// pass after a load 0x94DDEA, each with its own copy of the loop over the team. So the key wraps the
// three: for a marked tech it calls the stock routine once per target, without the team flag. The tech
// stays active in the owner's tree only; a load and a removal go through the owner, and the targets are
// counted again then. The two flags are read through the shared flag reader hook (techflags.h): the stock chain
// ignores a name it does not know. The other hooks are in hooks/hctarget_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../techflags.h"

extern "C" {
void UhcTechRemoveStock();
void UhcTechLoadStock();
}

namespace {

enum class Target { kEnemies, kAll };

constexpr std::uint32_t kApplyCall = 0x0094D0AE;
constexpr std::uint32_t kRemoveHead = 0x0094DCB2;
constexpr std::uint32_t kLoadHead = 0x0094DDEA;
constexpr std::size_t kWorld = 0x13C;
constexpr std::size_t kPlayerCount = 0x5C;
constexpr int kMaxLogLines = 200;

using ApplyFn = bool(__thiscall*)(char* tech, char* player, void* unit, std::uint32_t team, std::int32_t a,
                                  std::int32_t b);
const auto kApply = reinterpret_cast<ApplyFn>(0x0094DAE1);
using RemoveFn = bool(__thiscall*)(char* tech, char* player, std::int32_t a, std::uint32_t team);
const auto kRemove = reinterpret_cast<RemoveFn>(&UhcTechRemoveStock);
const auto kLoad = reinterpret_cast<RemoveFn>(&UhcTechLoadStock);
using PlayerByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
using IsEnemyFn = bool(__thiscall*)(const char* player, std::int32_t other);
const auto kIsEnemy = reinterpret_cast<IsEnemyFn>(0x00484D2D);

std::unordered_map<const void*, Target> g_techs;  // filled while the techs load, read-only after
bool g_log = false;
int g_logLines = 0;

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  return game == nullptr ? nullptr : *reinterpret_cast<const char* const*>(game + kWorld);
}

template <typename Call>
void ForTargets(Target target, const char* player, Call call) {
  const char* world = World();
  if (world == nullptr) {
    return;
  }
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(world + kPlayerCount);
  for (std::int32_t id = 1; id < count; ++id) {
    char* other = kPlayerById(world, id);
    if (other != nullptr && (target == Target::kAll || kIsEnemy(player, id))) {
      call(other);
    }
  }
}

void Note(const wchar_t* what, const char* tech, const char* player) {
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"hcTargetTechs: %ls tech %d of player %d", what, *reinterpret_cast<const std::int32_t*>(tech),
             *reinterpret_cast<const std::int32_t*>(player));
  }
}

bool __fastcall Apply(char* tech, void*, char* player, void* unit, std::uint32_t team, std::int32_t a, std::int32_t b) {
  const auto found = g_techs.find(tech);
  if (found == g_techs.end()) {
    return kApply(tech, player, unit, team, a, b);
  }
  Note(L"apply", tech, player);
  bool done = true;
  ForTargets(found->second, player, [&](char* other) {
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"hcTargetTechs: effects on player %d", *reinterpret_cast<const std::int32_t*>(other));
    }
    done = kApply(tech, other, nullptr, team & ~0xFFu, a, b) && done;
  });
  return done;
}

}  // namespace

// From the shared flag reader hook: true for the two flags of the key, which stock would ignore.
static bool UhcTechFlag(char* entry, const char* name) {
  const bool enemy = name != nullptr && _stricmp(name, "HCTargetEnemy") == 0;
  if (!enemy && (name == nullptr || _stricmp(name, "HCTargetAll") != 0)) {
    return false;
  }
  g_techs[*reinterpret_cast<void* const*>(entry)] = enemy ? Target::kEnemies : Target::kAll;
  if (g_log) {
    uhc::Log(L"hcTargetTechs: %hs read", name);
  }
  return true;
}

// Both replace the head of the routine, through a jmp: same arguments, same ret 0Ch.
extern "C" bool __fastcall UhcTechRemove(char* tech, void*, char* player, std::int32_t a, std::uint32_t team) {
  const auto found = g_techs.find(tech);
  if (found == g_techs.end()) {
    return kRemove(tech, player, a, team);
  }
  Note(L"remove", tech, player);
  bool done = true;
  ForTargets(found->second, player, [&](char* other) { done = kRemove(tech, other, a, team & ~0xFFu) && done; });
  return done;
}

extern "C" bool __fastcall UhcTechLoad(char* tech, void*, char* player, std::int32_t a, std::uint32_t team) {
  const auto found = g_techs.find(tech);
  if (found == g_techs.end()) {
    return kLoad(tech, player, a, team);
  }
  Note(L"load", tech, player);
  bool done = true;
  ForTargets(found->second, player, [&](char* other) { done = kLoad(tech, other, a, team & ~0xFFu) && done; });
  return done;
}

namespace uhc {

Outcome ApplyHcTargetTechs(const Config& config) {
  const Config::Args* args = config.First("hcTargetTechs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"hcTargetTechs: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("hcTargetTechs", {&sites::kTechApplyCall, &sites::kTechRemoveHead,
                                   &sites::kTechLoadHead, &sites::kIsEnemyHead}) ||
      !AddTechFlagHandler("hcTargetTechs", &UhcTechFlag) ||
      !WriteCall(kApplyCall, reinterpret_cast<const void*>(&Apply)) ||
      !WriteJmp(kRemoveHead, reinterpret_cast<const void*>(&UhcTechRemove), 6) ||
      !WriteJmp(kLoadHead, reinterpret_cast<const void*>(&UhcTechLoad), 7)) {
    return Outcome::kFailed;
  }
  Log(L"hcTargetTechs: the tech flags HCTargetEnemy and HCTargetAll are on");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/hctarget_hooks.asm

```asm
; hcTargetTechs (src/features/hctargets.cpp): the stock heads of the two routines the key replaces with a jmp (its
; flags are read through the shared flag reader hook, hooks/techflags_hooks.asm). The C++ wrappers call these,
; which re-execute the replaced instructions and leave through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

.data
removeNext      dd 0094DCB8h    ; push edi, in removeEffects
loadNext        dd 0094DDF1h    ; xor ebx,ebx, in the pass after a load

.code

; removeEffects: replaces 0x94DCB2..0x94DCB7 (push ebx / push ebp / mov ebp,[esp+0Ch]).
UhcTechRemoveStock PROC
    TRACE_ONCE "hcTargetTechs remove (0x94DCB2)"
    push ebx
    push ebp
    mov ebp, dword ptr [esp+0Ch]
    jmp removeNext
UhcTechRemoveStock ENDP

; The pass after a load: replaces 0x94DDEA..0x94DDF0 (push ebx / push ebp / push edi / mov edi,[esp+10h]).
UhcTechLoadStock PROC
    TRACE_ONCE "hcTargetTechs load (0x94DDEA)"
    push ebx
    push ebp
    push edi
    mov edi, dword ptr [esp+10h]
    jmp loadNext
UhcTechLoadStock ENDP

END
```

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

## orPrereqsQty

Contract: [orPrereqsQty](../porting-to-another-dll.md#orprereqsqty).

Sites: `OrQtyVtableThunk` `0x4C5F02` (2 B), `TechPrereqListLoop` `0x50946A` (74 B), `OrQtyEvalHead` `0x5094B4` (10 B), `TechPrereqEntryUpdate` `0x5094EB` (81 B), `OrQtyTechSetup` `0x620277` (60 B), `OrQtyFlagHandler` `0x620BF1` (62 B), `OrQtyFlagBit` `0x62237E` (10 B), `OrQtyFlagRegister` `0x6237E4` (8 B), `OrQtyEvalTrue` `0x67C412` (9 B).

### src/features/orprereqs.cpp

```cpp
// orPrereqsQty: <Flag qty="N">OrPrereqs</Flag> makes a tech available when at least N of its prerequisites are
// met, instead of one.
//
// Stock reads <Flag>OrPrereqs</Flag> into bit 21 of the tech's status bits (the flag setter's case 0x62237E), and
// the prerequisite list evaluator FUN_005094B4 (bool thiscall(list = def+1Ch, Player*, bool or), ret 8) then ORs
// the prerequisites instead of ANDing them: the first one met returns true. Its only stock caller is the per-tech
// update 0x509537, which caches the result in status bit 3; techPrereqRecheck calls it too.
//
// The key redirects the tech tag table's <Flag> handler (the immediate of its registration, 0x6237E8) to
// UhcOrQtyFlag, which runs the stock handler and then reads qty="N" of an OrPrereqs flag into a table by tech ID
// (the setup 0x6201E5 stores the ID in [def+0] and the def in [record+0]). A jmp at the evaluator's head
// (hooks/orprereqs_hooks.asm) asks UhcOrQtyEval first: for an OR list whose tech has N >= 2 it counts the
// prerequisites met through their vtable slot +8, as stock calls them, and returns true from the N-th one;
// anything else goes on to the stock code.
#include <windows.h>

#include <charconv>
#include <cstdint>
#include <map>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
constexpr std::uint32_t kStockFlagHandler = 0x00620BF1;
constexpr std::uint32_t kFlagRegisterImm = 0x006237E8;  // the immediate of mov dword ptr [esp+10h], 620BF1h
constexpr int kMaxQty = 255;  // the list's length is a byte
constexpr int kMaxLines = 40;
constexpr int kMaxEvalLines = 200;

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
using FlagHandlerFn = bool(__cdecl*)(const char* node, char* record);
const auto kFlagHandler = reinterpret_cast<FlagHandlerFn>(kStockFlagHandler);
using PrereqMetFn = bool(__thiscall*)(const char* prereq, char* player);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Qty {
  const char* def = nullptr;  // the tech's definition when qty was read, to tell a stale entry
  std::uint8_t qty = 0;
};

std::vector<Qty> g_qty;  // by tech ID
int g_techs = 0;         // with a qty, in this data load
bool g_log = false;
bool g_listed = false;  // the techs were listed (once per data load, at the first evaluation)
int g_lines = 0;
int g_evalLines = 0;
std::map<std::uint32_t, int> g_lastMet;  // "log": (player << 24 | tech ID) -> prerequisites met at the last evaluation

const wchar_t* TechName(std::int32_t id) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (database == nullptr) {
    return L"?";
  }
  const wchar_t* const* names = Field<const wchar_t* const*>(database, 0x3824);
  if (names == nullptr || id < 0 || id >= Field<std::int32_t>(database, 0x3828) || names[id] == nullptr) {
    return L"?";
  }
  return names[id];
}

int PrereqCount(const char* def) {
  const char* const* list = Field<const char* const*>(def, 0x1C);
  const std::uint8_t length = Field<std::uint8_t>(def, 0x20);
  int count = 0;
  for (std::uint8_t i = 0; list != nullptr && i < length; ++i) {
    count += list[i] != nullptr ? 1 : 0;
  }
  return count;
}

// Once per data load, at the first evaluation, when every tech's prerequisites are read.
void ListTechs() {
  g_listed = true;
  uhc::Log(L"orPrereqsQty: %d tech(s) with qty on OrPrereqs", g_techs);
  int listed = 0;
  int never = 0;
  for (std::size_t id = 0; id < g_qty.size(); ++id) {
    const Qty& entry = g_qty[id];
    if (entry.def == nullptr || entry.qty == 0) {
      continue;
    }
    const int count = PrereqCount(entry.def);
    if (entry.qty > count) {
      ++never;
    }
    if (listed++ < kMaxLines) {
      uhc::Log(L"orPrereqsQty:   tech %u (%ls): %u of %d prerequisite(s)%ls", static_cast<unsigned>(id),
               TechName(static_cast<std::int32_t>(id)), entry.qty, count,
               entry.qty > count ? L"; more than it has, so never met" : L"");
    }
  }
  if (listed > kMaxLines) {
    uhc::Log(L"orPrereqsQty:   and %d more", listed - kMaxLines);
  }
  if (never > 0) {
    uhc::Log(L"orPrereqsQty: %d tech(s) ask more prerequisites than they have and are never available", never);
  }
}

bool ParseQty(const char* text, int* qty) {
  if (text == nullptr) {
    return false;
  }
  while (*text == ' ') {
    ++text;
  }
  const char* last = text + std::strlen(text);
  while (last > text && last[-1] == ' ') {
    --last;
  }
  int value = 0;
  const auto [end, error] = std::from_chars(text, last, value);
  if (error != std::errc() || end != last || value < 1 || value > kMaxQty) {
    return false;
  }
  *qty = value;
  return true;
}

}  // namespace

extern "C" {

void UhcOrQtyEvalHook();  // hooks/orprereqs_hooks.asm

// The tech tag table's <Flag> handler while the techtree is read: cdecl(node, record), like the stock one.
bool __cdecl UhcOrQtyFlag(const char* node, char* record) {
  const bool result = kFlagHandler(node, record);
  if (!result || node == nullptr || record == nullptr) {
    return result;
  }
  const void* attribute = nullptr;
  if (!kXmlAttribute(node, "qty", &attribute) || attribute == nullptr) {
    return result;
  }
  const char* flag = kXmlText(node + 0x14);
  const char* def = Field<const char*>(record, 0x00);
  const std::int32_t id = def == nullptr ? -1 : Field<std::int32_t>(def, 0x00);
  const char* text = kXmlText(attribute);
  if (flag == nullptr || _stricmp(flag, "OrPrereqs") != 0) {
    if (g_lines++ < kMaxLines) {
      uhc::Log(L"orPrereqsQty: tech %d (%ls): qty on <Flag>%hs</Flag> ignored; it belongs on OrPrereqs", id,
               TechName(id), flag == nullptr ? "" : flag);
    }
    return result;
  }
  int qty = 0;
  if (id < 0 || id > 0xFFFFF || !ParseQty(text, &qty)) {
    if (g_lines++ < kMaxLines) {
      uhc::Log(L"orPrereqsQty: tech %d (%ls): qty=\"%hs\" is not a whole number from 1 to %d; ignored", id,
               TechName(id), text == nullptr ? "" : text, kMaxQty);
    }
    return result;
  }
  if (static_cast<std::size_t>(id) >= g_qty.size()) {
    g_qty.resize(static_cast<std::size_t>(id) + 1);
  }
  if (g_qty[id].def != def) {
    ++g_techs;
  }
  g_qty[id] = {def, static_cast<std::uint8_t>(qty)};
  g_listed = false;
  return result;
}

// From the evaluator's head: list = ECX (def+1Ch), the player, and the OR flag (its low byte, as stock reads it).
// Returns 0 or 1 for a tech with qty >= 2 and the OR flag; -1 lets the stock code evaluate the list.
std::int32_t __stdcall UhcOrQtyEval(const char* list, char* player, std::uint32_t orFlag) {
  if ((orFlag & 0xFF) == 0 || list == nullptr || g_qty.empty()) {
    return -1;
  }
  const char* def = list - 0x1C;
  const std::int32_t id = Field<std::int32_t>(def, 0x00);
  if (id < 0 || static_cast<std::size_t>(id) >= g_qty.size() || g_qty[id].def != def || g_qty[id].qty < 2) {
    return -1;
  }
  if (!g_listed) {
    ListTechs();
  }
  const int qty = g_qty[id].qty;
  const char* const* items = Field<const char* const*>(list, 0x00);
  const std::uint8_t length = Field<std::uint8_t>(list, 0x04);
  int met = 0;
  for (std::uint8_t i = 0; items != nullptr && i < length && met < qty; ++i) {
    const char* prereq = items[i];
    if (prereq == nullptr) {
      continue;
    }
    const auto metFn = reinterpret_cast<PrereqMetFn>(Field<const void* const*>(prereq, 0x00)[2]);
    if (metFn(prereq, player)) {
      ++met;
    }
  }
  if (g_log && g_evalLines < kMaxEvalLines) {
    // Only a change: techPrereqRecheck may evaluate the same list on every world update.
    const std::int32_t playerId = player == nullptr ? -1 : Field<std::int32_t>(player, 0x00);
    const std::uint32_t key = (static_cast<std::uint32_t>(playerId & 0xFF) << 24) | static_cast<std::uint32_t>(id);
    const auto last = g_lastMet.find(key);
    if (last == g_lastMet.end() || last->second != met) {
      g_lastMet[key] = met;
      ++g_evalLines;
      uhc::Log(L"orPrereqsQty: player %d, tech %d (%ls): %d of %d needed met%ls%ls", playerId, id, TechName(id),
               met, qty, met >= qty ? L": available" : L": not yet",
               g_evalLines == kMaxEvalLines ? L" (no more changes are logged)" : L"");
    }
  }
  return met >= qty ? 1 : 0;
}
}

namespace uhc {

Outcome ApplyOrPrereqsQty(const Config& config) {
  const Config::Args* args = config.First("orPrereqsQty");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"orPrereqsQty: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  // techPrereqRecheck verifies the evaluator's head before this key writes it.
  if (!VerifyAll("orPrereqsQty", {&sites::kOrQtyEvalHead, &sites::kOrQtyEvalTrue, &sites::kOrQtyVtableThunk,
                                  &sites::kOrQtyFlagHandler, &sites::kOrQtyFlagRegister, &sites::kOrQtyFlagBit,
                                  &sites::kOrQtyTechSetup, &sites::kTechPrereqListLoop,
                                  &sites::kTechPrereqEntryUpdate})) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!WriteDword(kFlagRegisterImm, reinterpret_cast<std::uint32_t>(&UhcOrQtyFlag)) ||
      !WriteJmp(sites::kOrQtyEvalHead.va, reinterpret_cast<const void*>(&UhcOrQtyEvalHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"orPrereqsQty: <Flag qty=\"N\">OrPrereqs</Flag> needs N of the tech's prerequisites%ls (multiplayer "
      L"unverified)",
      log ? L"; each change of a tech's count is logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/orprereqs_hooks.asm

```asm
; Hook for orPrereqsQty. Entered through a jmp written over the head of the prerequisite list evaluator
; FUN_005094B4; leaves through an explicit jmp to the verified continuation, or returns from the evaluator itself.
.686
.model flat, c
option casemap :none

include common.inc

UhcOrQtyEval PROTO STDCALL list:DWORD, player:DWORD, orFlag:DWORD

.data
evalNext        dd 005094B9h    ; push ebp / push esi / test bl,bl: the stock evaluator after its first two instructions

.code

; Replaces 0x5094B4..0x5094B8 (push ebx / mov bl,[esp+0Ch]). bool thiscall(list = ECX, Player* [esp+4], bool or
; [esp+8]), ret 8. UhcOrQtyEval returns 0 or 1 for a list it evaluates (returned as AL, ret 8, as the stock exits
; 0x5094D5 and 0x67C418 do), or -1: then ECX is restored and the two stolen instructions run before the stock code.
; EAX and EDX are free on entry (thiscall); EBX, ESI, EDI and EBP are kept by the C++ code.
UhcOrQtyEvalHook PROC
    TRACE_ONCE "orPrereqsQty (0x5094B4)"
    push ecx
    push dword ptr [esp+0Ch]        ; or, [esp+8] + the push
    push dword ptr [esp+0Ch]        ; player, [esp+4] + two pushes
    push ecx                        ; list
    call UhcOrQtyEval
    pop ecx
    cmp eax, -1
    je stock
    ret 8
stock:
    push ebx                        ; stolen 0x5094B4
    mov bl, byte ptr [esp+0Ch]      ; stolen 0x5094B5
    jmp evalNext
UhcOrQtyEvalHook ENDP

END
```

## shipmentCounts

Contract: [shipmentCounts](../porting-to-another-dll.md#shipmentcounts).

Besides the core helpers, it needs: [`savedmarkers.h`](helpers.md#state-kept-for-a-saved-game), [`techsubtypes.h`](helpers.md#tech-subtypes), [`unitinfo.h`](helpers.md#unit-info-for-the-panels), [`worldtick.h`](helpers.md#world-tick).

Sites: `ShipQueueCaller` `0x66AEA0` (5 B), `ShipActivateCall` `0x8584E7` (36 B), `ShipEntryArg` `0x85856A` (10 B), `ShipCardLookup` `0x85FFCE` (30 B), `FreeHomeCityUnitCase` `0x8D8C62` (193 B).

### src/features/shipmentcounts.cpp

```cpp
// shipmentCounts: per-player counts of the home city shipments, by the age of each card (its <age>, the age that
// enables it), for the Data subtype FreeHomeCityUnitByShipmentCount (with `unittype`, `includeself` and this key's
// `age`, one age or a range) and the XS syscalls xsGetShipmentCount and xsGetShipmentCountRange.
//
// A card is sent by FUN_0085A724: it checks the card's age [card+18h] against the player's ([player+50h]), pays,
// then appends an entry {card index, tech ID, ...} to the home city's shipment queue ([hc+288h], entries of 18h).
// The card is shipped later by FUN_00858299 when its transit ends (the queue update 0x4BF86F): it activates the
// card's tech with call 94CF27h at 0x8584FF, which applies the tech's effects there and then. A queued card can
// also be cancelled, by the player or by a Blockade; a cancelled card never ships.
//
// So a card counts when it ships, in the age of the card: the redirected activation call reads the shipping
// entry's card index (+0), finds the card with FUN_0085FFCE(hc+228h, index), as the send and the shipment do, and
// takes its age [card+18h] (the scale of [player+50h] and kbGetAge: Age I = 0; -1, a card with no <age>, counts in
// Age I). The card's effects run with the shipment current, then it is counted. While the card's own effects run
// the counts do not hold it yet: `includeself` adds it.
//
// Saved games: the counts are kept on one unit of the world as saved markers (savedmarkers.h, stat 67h): per
// player one marker with the five counts (16 bits each). A world tick writes them when they change and moves them
// to another unit when theirs dies, transforms or loses them, so the markers are on a living unit at every save. A
// game that starts or loads reads them back (one walk over the units). Older builds also kept a second marker kind
// (2) with the send ages of the queued cards; a save that has one loads, the marker is ignored and dropped at the
// next write.
//
// The subtype is a Player target (techsubtypes.h, AddTechPlayerSubtype). Its unittype, age range and includeself
// are packed into the effect's field +10h when the techtree is read; when it applies it becomes the stock
// FreeHomeCityUnit (subtype 37h) with the proto and amount x count, so the units come the stock way (the home
// city gather point, the same checks).
#include <windows.h>

#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <utility>

#include "../features.h"
#include "../unitinfo.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../savedmarkers.h"
#include "../syscalls.h"
#include "../techsubtypes.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint32_t kShipActivateCall = 0x008584FF;
constexpr std::int32_t kFreeHomeCityUnit = 0x37;
constexpr int kPlayers = 16;
constexpr int kAges = 5;  // cAge1..cAge5; a higher age counts in the last one
constexpr std::uint32_t kProtoMask = 0x00FFFFFF;
constexpr int kFirstAgeShift = 24;  // bits 24..26: the first age of the range, 1..5 (0: every age)
constexpr std::uint32_t kSelfBit = 0x10000000;
constexpr int kLastAgeShift = 29;   // bits 29..31: the last age of the range, 1..5
constexpr std::size_t kTypeNames = 0x190;       // in the database: the unit type name table
constexpr std::size_t kFirstAbstract = 0x19B0;  // in the database: the first abstract type's ID
constexpr int kMaxLines = 200;

// The home city, its cards and its shipment queue.
constexpr std::uint32_t kPlayerAge = 0x50;     // the player's age, cAge1 = 0
constexpr std::uint32_t kHcCards = 0x228;      // the card list: FUN_0085FFCE(list, index) -> card, 28h each
constexpr std::uint32_t kCardAge = 0x18;       // the card's <age>, cAge1 = 0, -1 with none
constexpr std::uint32_t kHcQueue = 0x288;      // entries; +28Ch count
constexpr std::uint32_t kQueueEntrySize = 0x18;  // +0 card index, +4 tech ID

// Saved markers (savedmarkers.h): word 0 is 'SC' << 16 | player << 8 | kind.
constexpr std::int32_t kStat = 0x67;
constexpr std::uint32_t kTag = 0x53430000;
constexpr std::uint32_t kTagMask = 0xFFFF0000;
constexpr std::uint32_t kKindCounts = 1;  // words 1..3: the counts of ages I..V, 16 bits each
constexpr std::uint32_t kKindOldAges = 2; // older builds: the send ages of the queued cards; ignored, dropped

using CardOfFn = const char*(__thiscall*)(const void* list, std::int32_t index);
const auto kCardOf = reinterpret_cast<CardOfFn>(0x0085FFCE);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
using NameBucketFn = std::int32_t(__thiscall*)(const void* table, const char* name);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
using NameFindFn = bool(__thiscall*)(const void* table, const char* name, std::int32_t bucket, std::int32_t* id);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
using UnitTestFn = bool(__thiscall*)(const char* unit);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

struct PlayerState {
  std::int32_t counts[kAges];
};

bool g_log = false;
int g_lines = 0;
const char* g_world = nullptr;  // the world the counts belong to
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
PlayerState g_state[kPlayers];
bool g_dirty = false;                 // the markers need writing
std::int32_t g_carrier = -1;          // the unit that holds the markers
std::uint32_t g_carrierWord = 0;      // word 0 of one of its markers

// The shipment being made: its player and its card's age while its tech activates.
bool g_shipping = false;
std::int32_t g_shipPlayer = -1;
std::int32_t g_shipAge = 0;

void Line(const wchar_t* format, ...) {
  if (g_lines >= kMaxLines) {
    return;
  }
  wchar_t text[512];
  va_list args;
  va_start(args, format);
  _vsnwprintf_s(text, _TRUNCATE, format, args);
  va_end(args);
  ++g_lines;
  uhc::Log(L"%ls%ls", text, g_lines == kMaxLines ? L" (no more lines are logged)" : L"");
}

int AgeIndex(std::int32_t age) { return age < 0 ? 0 : (age >= kAges ? kAges - 1 : age); }

// The name of an age index 0..4 in the log: Age I..Age V.
const wchar_t* AgeName(int index) {
  static const wchar_t* const kNames[kAges] = {L"I", L"II", L"III", L"IV", L"V"};
  return kNames[AgeIndex(index)];
}

// --- Units and players --------------------------------------------------------------------------------------

char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<UnitTestFn const* const*>(unit))[0xA4 / 4](unit); }

bool IsDead(const char* unit) {  // state bit 11: the kill handler returns at once
  const auto* bits = Field<const std::uint8_t*>(unit, 4);
  return bits != nullptr && Field<std::uint32_t>(unit, 8) > 11 && (bits[1] & 0x08) != 0;
}

std::int32_t OwnerOf(const char* unit) {
  const char* owner = Field<const char*>(unit, 0x44);
  return owner == nullptr ? -1 : Field<std::int32_t>(owner, 0);
}

std::int32_t QueueCount(const char* hc) { return Field<std::int32_t>(hc, kHcQueue + 4); }

// The <age> of the card of a shipment queue entry of that home city (cAge1 = 0, -1 with none), or -2 if the entry
// or its card is not found.
std::int32_t CardAge(const char* hc, const char* shipment) {
  if (hc == nullptr || shipment == nullptr) {
    return -2;
  }
  const char* base = Field<const char*>(hc, kHcQueue);
  if (base == nullptr || shipment < base) {
    return -2;
  }
  const auto offset = static_cast<std::uint32_t>(shipment - base);
  if (offset % kQueueEntrySize != 0 || static_cast<std::int32_t>(offset / kQueueEntrySize) >= QueueCount(hc)) {
    return -2;
  }
  const char* card = kCardOf(hc + kHcCards, Field<std::int32_t>(shipment, 0));
  return card == nullptr ? -2 : Field<std::int32_t>(card, kCardAge);
}

// --- Saved markers ------------------------------------------------------------------------------------------

std::uint32_t MarkerWord(std::int32_t player, std::uint32_t kind) {
  return kTag | (static_cast<std::uint32_t>(player) << 8) | kind;
}

bool IsOurs(char* marker) { return (uhc::markers::Word(marker, 0) & kTagMask) == kTag; }

void FreeOurs(char* unit) {
  uhc::markers::ForEach(unit, kStat, [](char* marker) {
    if (IsOurs(marker)) {
      uhc::markers::Free(marker);
    }
    return true;
  });
}

bool HasState(int player) {
  for (const std::int32_t count : g_state[player].counts) {
    if (count != 0) {
      return true;
    }
  }
  return false;
}

bool CarrierValid(const char* world) {
  char* unit = UnitById(world, g_carrier);
  return unit != nullptr && IsAlive(unit) && !IsDead(unit) &&
         uhc::markers::Find(unit, kStat, g_carrierWord) != nullptr;
}

// A living unit that takes a marker, a player's first; nullptr if none.
char* PickCarrier(const char* world) {
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  for (int pass = 0; pass < 2; ++pass) {
    for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
      char* unit = table[i];
      if (unit == nullptr || (pass == 0 && OwnerOf(unit) < 1) || !IsAlive(unit) || IsDead(unit)) {
        continue;
      }
      if (char* marker = uhc::markers::Take(unit, kStat)) {
        uhc::markers::Free(marker);  // a free marker of the stat, reused by the write
        return unit;
      }
    }
  }
  return nullptr;
}

bool WriteMarker(char* unit, std::uint32_t word0, const std::uint32_t (&words)[3]) {
  char* marker = uhc::markers::Take(unit, kStat);
  if (marker == nullptr) {
    return false;
  }
  uhc::markers::Word(marker, 0) = word0;
  for (int w = 0; w < 3; ++w) {
    uhc::markers::Word(marker, w + 1) = words[w];
  }
  return true;
}

// Writes every player's counts on the carrier, a new one if it is gone.
void WriteMarkers(const char* world) {
  bool any = false;
  for (int p = 0; p < kPlayers; ++p) {
    any = any || HasState(p);
  }
  char* unit = UnitById(world, g_carrier);
  const bool keep = unit != nullptr && IsAlive(unit) && !IsDead(unit);
  if (unit != nullptr) {
    FreeOurs(unit);
  }
  if (!any) {
    g_carrier = -1;
    g_dirty = false;
    return;
  }
  if (!keep) {
    unit = PickCarrier(world);
    if (unit == nullptr) {
      return;  // no unit to hold them: try again at the next tick
    }
  }
  std::uint32_t first = 0;
  bool ok = true;
  for (int p = 0; p < kPlayers && ok; ++p) {
    const PlayerState& state = g_state[p];
    if (!HasState(p)) {
      continue;
    }
    std::uint32_t counts[3] = {};
    for (int a = 0; a < kAges; ++a) {
      const std::uint32_t c = state.counts[a] > 0xFFFF ? 0xFFFF : static_cast<std::uint32_t>(state.counts[a]);
      counts[a / 2] |= c << (16 * (a % 2));
    }
    ok = WriteMarker(unit, MarkerWord(p, kKindCounts), counts);
    first = first != 0 ? first : MarkerWord(p, kKindCounts);
  }
  if (!ok) {
    FreeOurs(unit);
    return;  // try again at the next tick
  }
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (g_log && id != g_carrier) {
    Line(L"shipmentCounts: the counts are kept on unit %d", id);
  }
  g_carrier = id;
  g_carrierWord = first;
  g_dirty = false;
}

// A game that just started or loaded: the counts its markers keep. One walk.
void Rebuild(const char* world) {
  for (PlayerState& state : g_state) {
    std::memset(state.counts, 0, sizeof(state.counts));
  }
  g_shipping = false;
  g_carrier = -1;
  g_carrierWord = 0;
  g_dirty = false;
  bool oldAges = false;
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  int carriers = 0;
  for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
    char* unit = table[i];
    if (unit == nullptr) {
      continue;
    }
    bool found = false;
    uhc::markers::ForEach(unit, kStat, [&](char* marker) {
      if (!IsOurs(marker)) {
        return true;
      }
      const std::uint32_t word0 = uhc::markers::Word(marker, 0);
      const int player = static_cast<int>((word0 >> 8) & 0xFF);
      const std::uint32_t kind = word0 & 0xFF;
      if (player >= kPlayers) {
        return true;
      }
      found = true;
      if (kind == kKindCounts) {
        for (int a = 0; a < kAges; ++a) {
          g_state[player].counts[a] =
              static_cast<std::int32_t>((uhc::markers::Word(marker, 1 + a / 2) >> (16 * (a % 2))) & 0xFFFF);
        }
        g_carrierWord = word0;
      } else if (kind == kKindOldAges) {
        oldAges = true;  // an older build's send ages: not used, dropped by the next write
      }
      return true;
    });
    if (found) {
      ++carriers;
      g_carrier = Field<std::int32_t>(unit, 0x10);
    }
  }
  if (oldAges) {
    g_dirty = true;
    Line(L"shipmentCounts: loaded a save of an older build: the send ages it kept are not used, a card counts in "
         L"the age of the card");
  }
  if (carriers > 1) {
    g_dirty = true;  // markers on two units: the next write keeps one set
    for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
      if (table[i] != nullptr && Field<std::int32_t>(table[i], 0x10) != g_carrier) {
        FreeOurs(table[i]);
      }
    }
  }
  if (carriers > 0) {
    for (int p = 0; p < kPlayers; ++p) {
      if (!HasState(p)) {
        continue;
      }
      const PlayerState& s = g_state[p];
      Line(L"shipmentCounts: loaded: player %d has shipped %d, %d, %d, %d, %d cards of ages I to V", p, s.counts[0],
           s.counts[1], s.counts[2], s.counts[3], s.counts[4]);
    }
  }
}

// The counts follow the world: a new game, a loaded one, a scenario rebuilds them from its markers.
void Sync() {
  const char* world = World();
  if (world == nullptr) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const bool sameGame = world == g_world && now >= g_lastTime && step - g_lastStep <= 1;
  if (!sameGame) {
    g_world = world;
    Rebuild(world);
  }
  g_lastTime = now;
  g_lastStep = step;
}

void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  Sync();
  if (g_dirty || (g_carrier >= 0 && !CarrierValid(world))) {
    WriteMarkers(world);
  }
}

// --- Counts -------------------------------------------------------------------------------------------------

// Ages first..last, cAge1 = 0 .. cAge5 = 4.
std::int32_t Count(std::int32_t player, std::int32_t first, std::int32_t last) {
  if (player < 0 || player >= kPlayers) {
    return 0;
  }
  Sync();
  std::int32_t total = 0;
  for (int a = AgeIndex(first); a <= AgeIndex(last); ++a) {
    total += g_state[player].counts[a];
  }
  return total;
}

const wchar_t* TechName(std::int32_t id) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (database == nullptr) {
    return L"?";
  }
  const wchar_t* const* names = Field<const wchar_t* const*>(database, 0x3824);
  if (names == nullptr || id < 0 || id >= Field<std::int32_t>(database, 0x3828) || names[id] == nullptr) {
    return L"?";
  }
  return names[id];
}

std::string Attribute(const char* node, const char* name) {
  const void* value = nullptr;
  if (node == nullptr || !kXmlAttribute(node, name, &value) || value == nullptr) {
    return {};
  }
  const char* text = kXmlText(value);
  return text == nullptr ? std::string() : std::string(text);
}

// age="N": one age, 0..4 (Age I to V, the scale of a card's <age> and of cAge1..cAge5); age="NM": two digits, the
// ages N to M, N <= M (age="13": Ages II to IV). Out: the first and last age, 1..5 (Age I to V), as packed.
bool ParseAgeRange(const std::string& text, long* first, long* last) {
  const std::size_t n = text.size();
  if (n < 1 || n > 2) {
    return false;
  }
  for (const char c : text) {
    if (c < '0' || c > static_cast<char>('0' + kAges - 1)) {
      return false;
    }
  }
  *first = text[0] - '0' + 1;
  *last = text[n - 1] - '0' + 1;
  return *first <= *last;
}

// While the techtree is read: unittype (a proto), includeself, age, packed into the effect's field +10h.
bool ParseEffect(void* db, char* effect, const char* node) {
  const std::string unit = Attribute(node, "unittype");
  const char* table = static_cast<const char*>(db) + kTypeNames;
  std::int32_t proto = -1;
  if (unit.empty() || !kNameFind(table, unit.c_str(), kNameBucket(table, unit.c_str()), &proto) || proto < 0 ||
      proto >= Field<std::int32_t>(static_cast<const char*>(db), kFirstAbstract) ||
      static_cast<std::uint32_t>(proto) > kProtoMask) {
    Line(L"shipmentCounts: a FreeHomeCityUnitByShipmentCount effect names %hs, which is not a proto; effect dropped",
         unit.empty() ? "no unittype" : unit.c_str());
    return false;
  }
  std::uint32_t packed = static_cast<std::uint32_t>(proto);
  const std::string age = Attribute(node, "age");
  if (!age.empty()) {
    long first = 0;
    long last = 0;
    if (!ParseAgeRange(age, &first, &last)) {
      Line(L"shipmentCounts: age=\"%hs\" is not an age 0 to %d (Age I to V) or two of them for a range, first <= last, "
           L"with no hyphen (13: Ages II to IV); effect dropped",
           age.c_str(), kAges - 1);
      return false;
    }
    packed |= static_cast<std::uint32_t>(first) << kFirstAgeShift;
    packed |= static_cast<std::uint32_t>(last) << kLastAgeShift;
  }
  const std::string self = Attribute(node, "includeself");
  if (_stricmp(self.c_str(), "true") == 0 || self == "1") {
    packed |= kSelfBit;
  }
  *reinterpret_cast<std::uint32_t*>(effect + 0x10) = packed;
  return true;
}

// When the effect applies: the stock FreeHomeCityUnit with amount x the count.
std::int32_t RunEffect(char* player, std::int32_t* field, float* amount) {
  const auto packed = static_cast<std::uint32_t>(*field);
  const std::int32_t proto = static_cast<std::int32_t>(packed & kProtoMask);
  const int first = static_cast<int>((packed >> kFirstAgeShift) & 0x7);  // 0: every age, 1..5: Age I..V (age="0".."4")
  const int last = first == 0 ? kAges : static_cast<int>((packed >> kLastAgeShift) & 0x7);
  const int lo = first == 0 ? 0 : first - 1;
  const int hi = last - 1;
  const bool self = (packed & kSelfBit) != 0;
  const std::int32_t playerId = Field<std::int32_t>(player, 0x00);
  std::int32_t count = Count(playerId, lo, hi);
  const bool current = self && g_shipping && g_shipPlayer == playerId && g_shipAge >= lo && g_shipAge <= hi;
  if (current) {
    ++count;
  }
  const float units = *amount * static_cast<float>(count);
  if (g_log) {
    wchar_t ages[48];
    if (first == 0) {
      wcscpy_s(ages, L"every age");
    } else if (first == last) {
      swprintf_s(ages, L"age=\"%d\" (Age %ls)", lo, AgeName(lo));
    } else {
      swprintf_s(ages, L"age=\"%d%d\" (Ages %ls to %ls)", lo, hi, AgeName(lo), AgeName(hi));
    }
    Line(L"shipmentCounts: player %d, FreeHomeCityUnitByShipmentCount proto %d, %ls: %d shipment(s)%ls x %.2f = "
         L"%.2f unit(s)",
         playerId, proto, ages, count, current ? L" (this one included)" : L"", *amount, units);
  }
  if (!(units >= 1.0f)) {
    return uhc::kPlayerSubtypeDone;  // nothing to send
  }
  *field = proto;
  *amount = units;
  return kFreeHomeCityUnit;
}

bool ValidAge(std::int32_t age) { return age >= 0 && age < kAges; }

// XS: int xsGetShipmentCount(int playerID, int age): age cAge1..cAge5, or -1 for every age.
std::int32_t __cdecl XsGetShipmentCount(std::int32_t player, std::int32_t age) {
  if (age == -1) {
    return Count(player, 0, kAges - 1);
  }
  return ValidAge(age) ? Count(player, age, age) : 0;
}

// XS: int xsGetShipmentCountRange(int playerID, int firstAge, int lastAge): ages cAge1..cAge5, first <= last.
std::int32_t __cdecl XsGetShipmentCountRange(std::int32_t player, std::int32_t first, std::int32_t last) {
  return ValidAge(first) && ValidAge(last) && first <= last ? Count(player, first, last) : 0;
}

}  // namespace

extern "C" {

void UhcShipActivateHook();  // hooks/shipmentcount_hooks.asm

// Before the card's tech activates: entry = its status entry, player = the shipping player, hc = its home city,
// shipment = the queue entry being shipped. The shipment counts in the age of its card.
void __stdcall UhcShipBegin(const char* entry, const char* player, const char* hc, const char* shipment) {
  if (player == nullptr) {
    return;
  }
  Sync();
  g_shipping = true;
  g_shipPlayer = Field<std::int32_t>(player, 0x00);
  const std::int32_t card = CardAge(hc, shipment);
  g_shipAge = AgeIndex(card);  // -1 (no <age>) counts in Age I; -2 (not found) too, logged
  if (g_log) {
    const char* def = entry == nullptr ? nullptr : Field<const char*>(entry, 0x00);
    const std::int32_t tech = def == nullptr ? -1 : Field<std::int32_t>(def, 0x00);
    const std::int32_t now = AgeIndex(Field<std::int32_t>(player, kPlayerAge));
    Line(L"shipmentCounts: player %d ships tech %d (%ls), a card of Age %ls%ls, in Age %ls", g_shipPlayer, tech,
         TechName(tech), AgeName(g_shipAge),
         card == -1 ? L" (it has no <age>)" : (card < -1 ? L" (its card was not found)" : L""), AgeName(now));
  }
}

// After it: the shipment counts, in the age of its card.
void __stdcall UhcShipEnd() {
  if (!g_shipping) {
    return;
  }
  g_shipping = false;
  if (g_shipPlayer < 0 || g_shipPlayer >= kPlayers) {
    return;
  }
  ++g_state[g_shipPlayer].counts[g_shipAge];
  g_dirty = true;
  if (g_log) {
    const std::int32_t* c = g_state[g_shipPlayer].counts;
    Line(L"shipmentCounts: player %d has shipped %d, %d, %d, %d, %d in ages I to V", g_shipPlayer, c[0], c[1], c[2],
         c[3], c[4]);
  }
}
}

namespace {
bool g_unitInfoOn = false;  // the key applied: unitinfo.h answers
}  // namespace

namespace uhc {

Outcome ApplyShipmentCounts(const Config& config) {
  const Config::Args* args = config.First("shipmentCounts");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"shipmentCounts: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("shipmentCounts", {&sites::kShipActivateCall, &sites::kShipQueueCaller,
                                    &sites::kShipEntryArg, &sites::kShipCardLookup,
                                    &sites::kFreeHomeCityUnitCase})) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!AddTechPlayerSubtype("FreeHomeCityUnitByShipmentCount", &ParseEffect, &RunEffect) ||
      !InstallSyscallHooks("shipmentCounts") || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  SyscallParam player;
  player.type = kSyscallInt;
  player.intValue = -1;
  SyscallParam age;
  age.type = kSyscallInt;
  age.intValue = -1;

  SyscallDef def;
  def.group = SyscallGroup::kXs;
  def.retType = kSyscallInt;
  def.name = "xsGetShipmentCount";
  def.fn = reinterpret_cast<const void*>(&XsGetShipmentCount);
  def.comment = "int xsGetShipmentCount(int playerID, int age): the home city shipments of cards of that age "
                "(cAge1..cAge5; a card with no age is cAge1) that arrived for the player, or of every age with -1, "
                "in this game.";
  def.params = {player, age};
  def.source = "shipmentCounts";
  AddSyscall(std::move(def));

  SyscallDef range;
  range.group = SyscallGroup::kXs;
  range.retType = kSyscallInt;
  range.name = "xsGetShipmentCountRange";
  range.fn = reinterpret_cast<const void*>(&XsGetShipmentCountRange);
  range.comment = "int xsGetShipmentCountRange(int playerID, int firstAge, int lastAge): the home city shipments of "
                  "cards of ages firstAge to lastAge (cAge1..cAge5) that arrived for the player, in this game.";
  range.params = {player, age, age};
  range.source = "shipmentCounts";
  AddSyscall(std::move(range));

  if (!WriteCall(kShipActivateCall, reinterpret_cast<const void*>(&UhcShipActivateHook))) {
    return Outcome::kFailed;
  }
  Log(L"shipmentCounts: shipments are counted per player and the age of each card (its <age>; none: Age I), and "
      L"kept in saved games; the Data subtype FreeHomeCityUnitByShipmentCount and the XS syscalls xsGetShipmentCount "
      L"and xsGetShipmentCountRange read them%ls (multiplayer unverified)",
      log ? L"; each shipment and effect is logged" : L"");
  g_unitInfoOn = true;
  return Outcome::kApplied;
}

}  // namespace uhc

namespace uhc::unitinfo {

bool ShipmentCounts(const char* unit, std::wstring* out) {
  const char* player = !g_unitInfoOn || unit == nullptr ? nullptr : Field<const char*>(unit, 0x44);
  const std::int32_t id = player == nullptr ? -1 : Field<std::int32_t>(player, 0x00);
  if (id < 0 || id >= kPlayers || World() != g_world) {
    return false;
  }
  static const wchar_t* const kAgeNames[] = {L"I", L"II", L"III", L"IV", L"V", L"VI", L"VII", L"VIII"};
  out->clear();
  for (int age = 0; age < kAges && age < 8; ++age) {
    wchar_t text[24];
    swprintf_s(text, L"%ls%ls %d", out->empty() ? L"" : L"  ", kAgeNames[age], g_state[id].counts[age]);
    *out += text;
  }
  return true;
}

}  // namespace uhc::unitinfo
```

### src/hooks/shipmentcount_hooks.asm

```asm
; Hook for shipmentCounts: the call of the tech activation in the shipment of a card. It leaves through an explicit
; jmp to its verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcShipBegin PROTO STDCALL entry:DWORD, player:DWORD, hc:DWORD, shipment:DWORD
UhcShipEnd PROTO STDCALL

.data
activate        dd 0094CF27h    ; the tech activation, thiscall(entry, player, unit, 0, &ok, flags), ret 14h
shipReturn      dd 0            ; 0x858504, the call's return address while the activation runs

.code

; Replaces call 94CF27h at 0x8584FF in FUN_00858299. ECX = EDI = the card tech's status entry, ESI = the home
; city, [esp+4] = the player (the first of the five arguments), [esp] = the return address 0x858504, and
; [esp+3Ch] = FUN_00858299's argument, the queue entry being shipped ([esp+24h] before the five pushes and the
; return address). UhcShipBegin notes the player and the age of the entry's card; the activation runs with the
; stock arguments (it pops them, ret 14h) and its effects see the shipment as current; UhcShipEnd counts it. EAX,
; the activation's result, is kept; ECX and EDX are free after the call, and the code at 0x858504 reloads ECX from
; EDI. One shipment at a time: the activation does not ship another card.
UhcShipActivateHook PROC
    TRACE_ONCE "shipmentCounts (0x8584FF)"
    push ecx
    push dword ptr [esp+40h]        ; the queue entry, [esp+3Ch] + the push
    push esi                        ; the home city
    push dword ptr [esp+10h]        ; player, [esp+4] + three pushes
    push ecx                        ; entry
    call UhcShipBegin
    pop ecx
    pop eax                         ; the return address
    mov shipReturn, eax
    call activate                   ; the five arguments are on the stack, as at the stock call
    push eax
    call UhcShipEnd
    pop eax
    jmp shipReturn
UhcShipActivateHook ENDP

END
```

## ageFiveShipments

Contract: [ageFiveShipments](../porting-to-another-dll.md#agefiveshipments).

Sites: `CardListAgePasses` `0x63022E` (7 B), `DeckBuilderAgeRow` `0x9A0489` (39 B), `DeckBuilderColumn` `0x9A04B0` (27 B), `CardPanelAgeRow` `0x9A5A22` (20 B), `CardPanelColumn` `0x9A5A7C` (27 B), `DeckEditorAgeRow` `0x9A77BE` (39 B), `DeckEditorColumn` `0x9A77E5` (24 B).

### src/features/agefiveshipments.cpp

```cpp
// ageFiveShipments: home city cards of the fifth age (<age>4</age>, the Imperial Age) can be in the game's deck and
// be sent once the player is in that age.
//
// Stock leaves such a card out three times over:
// - the game's card list of a player (hc+228h) is built from the chosen deck by FUN_006301DE, one pass per age, and
//   the passes stop after age 3 (`cmp eax,4` at 0x63022E): a card of age 4 never gets into the game;
// - the in-game shipment panel (the gadget homeCityCardPanel, FUN_009A5658) places each card in the row of its age
//   and skips an age below 0 or above 3 (0x9A5A22..0x9A5A30); its rows are four arrays of 4 x 11 buttons;
// - the deck builder of the home city screen (buttons hcDeck-button<row><column>) and the homeCityDeck dialog
//   (FUN_009A7670) stop at the first card whose age is 4 or more (0x9A0489..0x9A04AA, 0x9A77BE..0x9A77DF).
//
// The key lets the list builder take five ages (the immediate 4 becomes 5) and shows a card of age 4 in the row of
// age 3 in the three panels: the hooks at 0x9A5A22, 0x9A0489 and 0x9A77BE read the card's age as stock does and hand
// age 4 on as 3 for the row only. The card keeps its age: the panel still greys it out until the player's age
// reaches it (FUN_009A5658 compares [card+18h] with the player's age), and the send FUN_0085A724 refuses it before
// (0x85A90A). A fifth row needs room the panels' objects do not have (their button arrays hold 4 x 11), so the
// cards share the Imperial row.
//
// In that row (JTMaston, #83, 2026-11-22) the Age IV cards stay packed at the left, as stock places them, and the
// Age V cards are packed at the right: once a fill has set a card's row, the hooks at 0x9A5A7C, 0x9A04B0 and
// 0x9A77E5 give it its column (UhcAgeFiveColumn). A fill computes the slot row x 11 + column only after that, and
// stores both the card's button and its link (panel +1F0h, builder +228h) at that slot, so the click and rollover
// of a button find the card the fill put there. Slots left between the two groups stay hidden: each fill hides the
// 44 buttons and resets the links before it places a card.
#include <windows.h>

#include <cstdint>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcAgeFivePanelHook();  // hooks/agefive_hooks.asm
void UhcAgeFiveDeckHook();
void UhcAgeFiveBuilderHook();
void UhcAgeFivePanelColumnHook();
void UhcAgeFiveBuilderColumnHook();
void UhcAgeFiveDeckColumnHook();
}

namespace {

constexpr int kColumns = 11;              // buttons in a row of every deck panel
constexpr std::uint32_t kCardAge = 0x18;  // [card+18h], the card's <age>, 0 = Age I
constexpr std::int32_t kCardSize = 0x28;
constexpr std::uint32_t kListData = 0x1C;   // a card list: its cards, 28h bytes each
constexpr std::uint32_t kListCount = 0x20;  // and how many

const wchar_t* const kWhere[] = {L"in-game shipment panel", L"deck builder", L"deck editor"};
int g_lastAgeFour[3] = {-1, -1, -1};  // the counts last logged, per panel, so a fill that repeats logs nothing
int g_lastAgeFive[3] = {-1, -1, -1};

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

}  // namespace

// Called by the three column hooks once a fill has set the card's row and column, before it uses them. Returns the
// column of the card, or -1 to leave the card out (the fill then goes on to the next card, as for a twelfth card of
// a row). Only the row of Age IV changes, and only when the list holds an Age V card: an Age IV card keeps its
// column (its rank among the Age IV cards) if it is left of the Age V cards, and an Age V card takes column
// 11 - (Age V cards) + its rank among them. `counter` is the panel's count of the row's cards, or null.
extern "C" int __stdcall UhcAgeFiveColumn(const char* list, const char* card, int column, int* counter, int where) {
  if (list == nullptr || card == nullptr) {
    return column;
  }
  const std::int32_t age = Field<std::int32_t>(card, kCardAge);
  if (age != 3 && age != 4) {
    return column;
  }
  const char* data = Field<const char*>(list, kListData);
  const std::int32_t count = Field<std::int32_t>(list, kListCount);
  if (data == nullptr || count <= 0 || card < data || card >= data + count * kCardSize ||
      (card - data) % kCardSize != 0) {
    return column;
  }
  const auto index = static_cast<std::int32_t>((card - data) / kCardSize);
  int ageFour = 0;
  int ageFive = 0;
  int rank = 0;  // the card's rank among the cards of its age in the list
  for (std::int32_t i = 0; i < count; ++i) {
    const std::int32_t a = Field<std::int32_t>(data + i * kCardSize, kCardAge);
    if (a == 3) {
      ++ageFour;
    } else if (a == 4) {
      ++ageFive;
    }
    if (i < index && a == age) {
      ++rank;
    }
  }
  if (ageFive == 0) {
    return column;  // as before: no Age V card, the stock layout
  }
  const int shown = ageFive < kColumns ? ageFive : kColumns;
  const int first = kColumns - shown;  // the first column of the Age V cards
  if (where >= 0 && where < 3 && (ageFour != g_lastAgeFour[where] || ageFive != g_lastAgeFive[where])) {
    g_lastAgeFour[where] = ageFour;
    g_lastAgeFive[where] = ageFive;
    if (ageFour + ageFive > kColumns) {
      uhc::Log(L"ageFiveShipments: the %ls's Age IV row gets %d Age IV and %d Age V cards, more than its %d buttons: "
               L"the Age V cards keep the right side, and %d Age IV card(s)%ls are not shown",
               kWhere[where], ageFour, ageFive, kColumns, ageFour - first > 0 ? ageFour - first : 0,
               ageFive > kColumns ? L" and the Age V cards after the eleventh" : L"");
    } else {
      uhc::Log(L"ageFiveShipments: the %ls's Age IV row: %d Age IV card(s) at the left, %d Age V card(s) at the "
               L"right (columns %d to %d)",
               kWhere[where], ageFour, ageFive, first + 1, kColumns);
    }
  }
  int result = age == 4 ? first + rank : rank;
  if (age == 3 && result >= first) {
    result = -1;  // its slot is the Age V cards'
  }
  if (result >= kColumns) {
    result = -1;
  }
  if (result < 0 && counter != nullptr && *counter > 0) {
    --*counter;  // the panel counted it in the row before the hook
  }
  return result;
}

namespace uhc {

Outcome ApplyAgeFiveShipments(const Config& config) {
  const Config::Args* args = config.First("ageFiveShipments");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!args->empty()) {
    Log(L"ageFiveShipments: unexpected argument %hs (it takes none); feature not applied", (*args)[0].c_str());
    return Outcome::kFailed;
  }
  if (!VerifyAll("ageFiveShipments", {&sites::kCardListAgePasses, &sites::kCardPanelAgeRow,
                                      &sites::kDeckEditorAgeRow, &sites::kDeckBuilderAgeRow,
                                      &sites::kCardPanelColumn, &sites::kDeckBuilderColumn,
                                      &sites::kDeckEditorColumn})) {
    return Outcome::kFailed;
  }
  const std::uint8_t five = 5;
  // The immediate of `cmp eax,4` (83 F8 04) at 0x63022E.
  if (!WriteBytes(sites::kCardListAgePasses.va + 2, &five, 1) ||
      !WriteJmp(sites::kCardPanelAgeRow.va, reinterpret_cast<const void*>(&UhcAgeFivePanelHook), 5) ||
      !WriteJmp(sites::kDeckEditorAgeRow.va, reinterpret_cast<const void*>(&UhcAgeFiveDeckHook), 5) ||
      !WriteJmp(sites::kDeckBuilderAgeRow.va, reinterpret_cast<const void*>(&UhcAgeFiveBuilderHook), 5) ||
      !WriteJmp(sites::kCardPanelColumn.va, reinterpret_cast<const void*>(&UhcAgeFivePanelColumnHook), 8) ||
      !WriteJmp(sites::kDeckBuilderColumn.va, reinterpret_cast<const void*>(&UhcAgeFiveBuilderColumnHook), 8) ||
      !WriteJmp(sites::kDeckEditorColumn.va, reinterpret_cast<const void*>(&UhcAgeFiveDeckColumnHook), 7)) {
    return Outcome::kFailed;
  }
  Log(L"ageFiveShipments: cards of the fifth age (<age>4</age>) are in the game's deck, shown at the right of the "
      L"fourth age's row of the shipment panel and the deck panels (the Age IV cards at the left), and sendable in "
      L"the fifth age (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/agefive_hooks.asm

```asm
; Hooks for ageFiveShipments: the row and the column of a card in the in-game shipment panel, the deck builder and
; the deck editor. A card of the fifth age (age 4) takes the row of age 3; its own age [card+18h] is left alone.
; In that row the Age IV cards stay at the left and the Age V cards go to the right (UhcAgeFiveColumn). Each hook
; leaves through an explicit jmp to its verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcAgeFiveColumn PROTO STDCALL list:DWORD, card:DWORD, column:DWORD, counter:DWORD, where:DWORD

.data
panelContinue   dd 009A5A27h    ; FUN_009A5658: jl 9A620Bh, after the replaced mov / cmp
deckContinue    dd 009A77C3h    ; FUN_009A7670: jge 9A77D1h, after the replaced mov / cmp
builderContinue dd 009A048Eh    ; the deck builder's fill: jge 9A049Ch, after the replaced mov / cmp
panelColContinue   dd 009A5A84h ; FUN_009A5658: lea eax,[ebx+ebx*2], after the replaced mov ecx / mov edx
panelColSkip       dd 009A620Bh ; FUN_009A5658: the next card, as for a twelfth card of a row
builderColContinue dd 009A04B8h ; the deck builder's fill: lea ecx,[edi+edi*2], after the replaced mov edx / mov eax
builderColSkip     dd 009A076Ch ; the deck builder's fill: the next card
deckColContinue    dd 009A77ECh ; FUN_009A7670: add eax,eax, after the replaced mov ecx / lea eax
deckColSkip        dd 009A7A73h ; FUN_009A7670: the next card

.code

; Replaces mov eax,[esi+18h] / cmp eax,edi (5 bytes) at 0x9A5A22 in the panel fill FUN_009A5658: ESI = the card,
; EDI = 0; EAX becomes the card's row (its age, 4 -> 3); the cmp is re-run for the jl at 0x9A5A27.
UhcAgeFivePanelHook PROC
    TRACE_ONCE "ageFiveShipments panel (0x9A5A22)"
    mov eax, dword ptr [esi+18h]
    cmp eax, 4
    jne panelRow
    mov eax, 3
panelRow:
    cmp eax, edi
    jmp panelContinue
UhcAgeFivePanelHook ENDP

; Replaces mov eax,[esi+18h] / cmp ebx,eax (5 bytes) at 0x9A77BE in the deck editor fill FUN_009A7670: ESI = the
; card, EBX = the current row; EAX becomes the card's row (4 -> 3); the cmp is re-run for the jge at 0x9A77C3.
UhcAgeFiveDeckHook PROC
    TRACE_ONCE "ageFiveShipments deck editor (0x9A77BE)"
    mov eax, dword ptr [esi+18h]
    cmp eax, 4
    jne deckRow
    mov eax, 3
deckRow:
    cmp ebx, eax
    jmp deckContinue
UhcAgeFiveDeckHook ENDP

; Replaces mov eax,[esi+18h] / cmp edi,eax (5 bytes) at 0x9A0489 in the deck builder's fill (the home city screen's
; "Build a Deck", uihcdeckbuilder.xml, buttons hcDeck-button<row><column>): ESI = the card, EDI = the current row;
; EAX becomes the card's row (4 -> 3); the cmp is re-run for the jge at 0x9A048E.
UhcAgeFiveBuilderHook PROC
    TRACE_ONCE "ageFiveShipments deck builder (0x9A0489)"
    mov eax, dword ptr [esi+18h]
    cmp eax, 4
    jne builderRow
    mov eax, 3
builderRow:
    cmp edi, eax
    jmp builderContinue
UhcAgeFiveBuilderHook ENDP

; Replaces mov ecx,[esp+28h] / mov edx,[esp+14h] (8 bytes) at 0x9A5A7C in the panel fill FUN_009A5658, once the
; card's row is set: ESI = the card, EBX = its row, [esp+28h] = its column, [esp+14h] = the panel, [esp+2Ch] = the
; card list. UhcAgeFiveColumn gives the column (written back to [esp+28h]) or -1: the card is left out and its
; count in the row's counter [panel+4D0h+4*row] is taken back. EAX and the flags are free (the code after it sets
; them); the other registers are kept.
UhcAgeFivePanelColumnHook PROC
    TRACE_ONCE "ageFiveShipments panel column (0x9A5A7C)"
    pushad
    mov eax, dword ptr [esp+20h+14h]        ; the panel
    lea eax, [eax+ebx*4+4D0h]               ; the row's counter
    push 0                                  ; where: the in-game panel
    push eax
    push dword ptr [esp+20h+8+28h]          ; the column
    push esi                                ; the card
    push dword ptr [esp+20h+10h+2Ch]        ; the card list
    call UhcAgeFiveColumn
    mov dword ptr [esp+1Ch], eax            ; EAX after the popad
    popad
    cmp eax, -1
    je panelColLeftOut
    mov dword ptr [esp+28h], eax
    mov ecx, eax
    mov edx, dword ptr [esp+14h]
    jmp panelColContinue
panelColLeftOut:
    jmp panelColSkip
UhcAgeFivePanelColumnHook ENDP

; Replaces mov edx,[esp+14h] / mov eax,[esp+28h] (8 bytes) at 0x9A04B0 in the deck builder's fill: ESI = the card,
; EBP = the deck's card list, [esp+14h] = the column, [esp+28h] = the builder. -1 leaves the card out. ECX and the
; flags are free (lea ecx follows); EAX and EDX get the replaced loads.
UhcAgeFiveBuilderColumnHook PROC
    TRACE_ONCE "ageFiveShipments deck builder column (0x9A04B0)"
    pushad
    push 1                                  ; where: the deck builder
    push 0                                  ; no row counter
    push dword ptr [esp+20h+8+14h]          ; the column
    push esi                                ; the card
    push ebp                                ; the card list
    call UhcAgeFiveColumn
    mov dword ptr [esp+1Ch], eax
    popad
    cmp eax, -1
    je builderColLeftOut
    mov dword ptr [esp+14h], eax
    mov edx, eax
    mov eax, dword ptr [esp+28h]
    jmp builderColContinue
builderColLeftOut:
    jmp builderColSkip
UhcAgeFiveBuilderColumnHook ENDP

; Replaces mov ecx,[esp+30h] / lea eax,[ebx+ebx*2] (7 bytes) at 0x9A77E5 in the deck editor fill FUN_009A7670:
; ESI = the card, EBP = the deck's card list, EBX = the row, [esp+1Ch] = the column (added at 0x9A77F2). -1 leaves
; the card out. EAX, ECX and the flags get the replaced instructions' values.
UhcAgeFiveDeckColumnHook PROC
    TRACE_ONCE "ageFiveShipments deck editor column (0x9A77E5)"
    pushad
    push 2                                  ; where: the deck editor
    push 0                                  ; no row counter
    push dword ptr [esp+20h+8+1Ch]          ; the column
    push esi                                ; the card
    push ebp                                ; the card list
    call UhcAgeFiveColumn
    mov dword ptr [esp+1Ch], eax
    popad
    cmp eax, -1
    je deckColLeftOut
    mov dword ptr [esp+1Ch], eax
    mov ecx, dword ptr [esp+30h]
    lea eax, [ebx+ebx*2]
    jmp deckColContinue
deckColLeftOut:
    jmp deckColSkip
UhcAgeFiveDeckColumnHook ENDP

END
```

## Tech flags

Contract: [Tech flags](../porting-to-another-dll.md#tech-flags).

Sites: `TechFlagHead` `0x620C2F` (5 B).

### src/techflags.h

```cpp
// New <Flag> names of a <Tech> in the techtree: one hook on the head of the flag reader FUN_00620C2F
// (cdecl(record, name), called once per <Flag> at 0x620C23), shared by every key that reads a flag of its own
// (hcTargetTechs' HCTargetEnemy / HCTargetAll, quickArrivalCards' QuickArrival). Stock ignores a name it does not know.
#pragma once

namespace uhc {

// `record` is the tech's template record ([[loader+4]+0Ch] + 24h * id: [record+0] its definition, whose +0 is the
// tech ID); `name` the flag's text. Returns true when the key took the flag: stock then does not read it.
using TechFlagHandler = bool (*)(char* record, const char* name);

// Asks `handler` about every <Flag> of every tech, in the order the keys added them, before stock reads it. Writes
// the hook the first time, after checking the stock bytes of the reader's head.
bool AddTechFlagHandler(const char* feature, TechFlagHandler handler);

}  // namespace uhc
```

### src/techflags.cpp

```cpp
// The head of the tech flag reader 0x620C2F jumps to UhcTechFlagHook (hooks/techflags_hooks.asm), which asks
// UhcTechFlagDispatch; a flag no key takes goes on to the stock reader.
#include "techflags.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcTechFlagHook();

namespace {

constexpr std::size_t kMaxHandlers = 8;
constexpr std::uint32_t kFlagHead = 0x00620C2F;  // push esi / mov esi,[esp+8]

uhc::TechFlagHandler g_handlers[kMaxHandlers] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

// From the hook: true when a key took the flag.
extern "C" bool __stdcall UhcTechFlagDispatch(char* record, const char* name) {
  if (record == nullptr || name == nullptr) {
    return false;
  }
  for (std::size_t i = 0; i < g_count; ++i) {
    if (g_handlers[i](record, name)) {
      return true;
    }
  }
  return false;
}

namespace uhc {

bool AddTechFlagHandler(const char* feature, TechFlagHandler handler) {
  if (g_count == kMaxHandlers) {
    Log(L"%hs: no room for another tech flag handler", feature);
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll(feature, {&sites::kTechFlagHead}) ||
        !WriteJmp(kFlagHead, reinterpret_cast<const void*>(&UhcTechFlagHook), 5)) {
      return false;
    }
    g_installed = true;
  }
  g_handlers[g_count++] = handler;
  return true;
}

}  // namespace uhc
```

### src/hooks/techflags_hooks.asm

```asm
; The tech <Flag> reader's head (src/techflags.cpp), shared by the keys that read flags of their own. It leaves
; through an explicit jmp to the verified continuation, or returns for a flag a key took.
.686
.model flat, c
option casemap :none

include common.inc

UhcTechFlagDispatch PROTO STDCALL :DWORD, :DWORD

.data
flagNext        dd 00620C34h    ; test esi,esi, in the flag reader

.code

; The flag reader, cdecl (record, name): replaces 0x620C2F..0x620C33 (push esi / mov esi,[esp+8]). The head, not
; its one call 0x620C23: another DLL may wrap the call, and what it does not know still reaches this head. EAX, ECX
; and EDX are free at a cdecl head.
UhcTechFlagHook PROC
    TRACE_ONCE "tech flags (0x620C2F)"
    push dword ptr [esp+8]          ; name
    push dword ptr [esp+8]          ; record, [esp+4] + the push
    call UhcTechFlagDispatch
    test al, al
    jz stock
    ret
stock:
    push esi
    mov esi, dword ptr [esp+8]
    jmp flagNext
UhcTechFlagHook ENDP

END
```

## Card tags

Contract: [Card tags](../porting-to-another-dll.md#card-tags).

Sites: `CardChildLoop` `0x62FD1D` (7 B), `CardChildLoopEnd` `0x62FF42` (20 B), `CardCommitPrep` `0x630002` (21 B), `CardCommitCall` `0x630017` (5 B).

### src/cardtags.h

```cpp
// New child tags of a <card> in a home city file (homecity<civ>.xml): one hook on the home city loader's commit of
// each card (the call 0x630017 of the append to the home city's card array hc+204h), shared by every key that reads
// one (resendableCards' <resendeveryage>). The stock loader reads past a tag it does not know.
#pragma once

#include <cstdint>

namespace uhc {

// `hc` is the home city being loaded, `card` the card just added to its card array (a record of 28h bytes: +0 the
// tech ID, +4 <maxcount>, +18h <age>, +20h the sends left in a game, byte +24h <infiniteinlastage>; the game's card
// list of a player, hc+228h, is built from these records by copying them), `text` the tag's text (may be null).
using CardTagHandler = void (*)(char* hc, char* card, const wchar_t* text);

// Makes each child element of a <card> named `name` (static text, case ignored) reach `handler`, once the card is in
// the home city's array. Writes the hook the first time, after checking the stock bytes.
bool AddCardTagHandler(const char* feature, const char* name, CardTagHandler handler);

}  // namespace uhc
```

### src/cardtags.cpp

```cpp
// The home city loader's call of the card append at 0x630017 goes to UhcCardCommitHook (hooks/cardtags_hooks.asm):
// it appends the card as stock does, then UhcCardTagsDispatch walks the card node's children for the keys' tags.
#include "cardtags.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcCardCommitHook();

namespace {

constexpr std::size_t kMaxTags = 8;
constexpr std::uint32_t kCommitCall = 0x00630017;  // call 62FBC7h
constexpr std::uint32_t kCardArray = 0x204;        // in the home city: {data, count, capacity}
constexpr std::uint32_t kCardSize = 0x28;

struct Tag {
  const char* name;
  uhc::CardTagHandler handler;
};

Tag g_tags[kMaxTags] = {};
std::size_t g_count = 0;
bool g_installed = false;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// The element's name, as the loader's compare chain reads it: [[node+4]+18h][[node+18h]]; null for a node without one.
const wchar_t* NodeName(const char* node) {
  const std::int32_t index = Field<std::int32_t>(node, 0x18);
  const char* names = Field<const char*>(node, 0x04);
  if (index < 0 || names == nullptr || index >= Field<std::int32_t>(names, 0x1C)) {
    return nullptr;
  }
  return Field<const wchar_t* const*>(names, 0x18)[index];
}

// name (narrow) == tag (wide), case ignored.
bool SameName(const char* name, const wchar_t* tag) {
  for (;; ++name, ++tag) {
    const wchar_t a = static_cast<wchar_t>(*name >= 'A' && *name <= 'Z' ? *name + 32 : *name);
    const wchar_t b = *tag >= L'A' && *tag <= L'Z' ? *tag + 32 : *tag;
    if (a != b) {
      return false;
    }
    if (a == 0) {
      return true;
    }
  }
}

}  // namespace

// From the hook, after the append: `node` is the <card> (EBX in the loader), `array` the home city's card array
// (hc+204h), `index` the new card's index in it.
extern "C" void __stdcall UhcCardTagsDispatch(const char* node, char* array, std::int32_t index) {
  if (node == nullptr || array == nullptr || index < 0 || index >= Field<std::int32_t>(array, 4)) {
    return;
  }
  char* data = Field<char*>(array, 0);
  if (data == nullptr) {
    return;
  }
  char* card = data + static_cast<std::uint32_t>(index) * kCardSize;
  char* hc = array - kCardArray;
  // The children: [node+8] an array of nodes, [node+0Ch] their count (as the loader's loop reads them).
  const std::int32_t count = Field<std::int32_t>(node, 0x0C);
  const char* const* children = Field<const char* const*>(node, 0x08);
  for (std::int32_t c = 0; children != nullptr && c < count; ++c) {
    const char* child = children[c];
    const wchar_t* name = child == nullptr ? nullptr : NodeName(child);
    if (name == nullptr) {
      continue;
    }
    for (std::size_t t = 0; t < g_count; ++t) {
      if (SameName(g_tags[t].name, name)) {
        g_tags[t].handler(hc, card, Field<const wchar_t*>(child, 0x14));
      }
    }
  }
}

namespace uhc {

bool AddCardTagHandler(const char* feature, const char* name, CardTagHandler handler) {
  if (g_count == kMaxTags) {
    Log(L"%hs: no room for the card tag %hs", feature, name);
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll(feature, {&sites::kCardChildLoop, &sites::kCardChildLoopEnd, &sites::kCardCommitPrep,
                             &sites::kCardCommitCall}) ||
        !WriteCall(kCommitCall, reinterpret_cast<const void*>(&UhcCardCommitHook))) {
      return false;
    }
    g_installed = true;
  }
  g_tags[g_count++] = {name, handler};
  return true;
}

}  // namespace uhc
```

### src/hooks/cardtags_hooks.asm

```asm
; The home city loader's commit of a card (src/cardtags.cpp), shared by the keys that read card tags of their own.
.686
.model flat, c
option casemap :none

include common.inc

UhcCardTagsDispatch PROTO STDCALL node:DWORD, array:DWORD, index:DWORD

.data
cardAppend      dd 0062FBC7h    ; the card array's append, thiscall(array, card*), ret 4, the new index in EAX

.code

; Replaces call 62FBC7h at 0x630017 in the home city loader FUN_0062E6C9. ECX = the home city's card array
; (hc+204h), [esp+4] = the card built on the stack, [esp] = the return address 0x63001C, EBX = the <card> node.
; Calls the append with the same this and argument, then the dispatch, and returns its index with ret 4 as the
; append does. The loader overwrites ECX and EDX after the call (lea ecx,[esp+0A8h] at 0x63001C) and does not read
; EAX again; EBX, ESI, EDI and EBP are kept by both calls.
UhcCardCommitHook PROC
    TRACE_ONCE "card tags (0x630017)"
    push ecx                        ; the array, kept
    push dword ptr [esp+8]          ; the card, [esp+4] + the push
    call dword ptr [cardAppend]     ; ECX is still the array; pops the card
    pop ecx
    push eax                        ; the index, returned
    push eax
    push ecx
    push ebx
    call UhcCardTagsDispatch
    pop eax
    ret 4
UhcCardCommitHook ENDP

END
```

## resendableCards

Contract: [resendableCards](../porting-to-another-dll.md#resendablecards).

Sites: `CardRolloverHead` `0x7103CE` (38 B), `CardRolloverAgeCheck` `0x7107F4` (22 B), `SetAgeAdvanceFlag` `0x8D4EE3` (15 B), `AgeUpJoin` `0x8D502F` (5 B), `AgeUpStockRefill` `0x8D5034` (36 B).

### src/features/resendcards.cpp

```cpp
// resendableCards: <resendeveryage>1</resendeveryage> in a home city card makes the card sendable again each time
// its player reaches a new age: its sends left go back to its <maxcount>, as stock does once for an
// <infiniteinlastage> card when the player reaches the Imperial Age.
//
// How stock counts a card's sends: the game's card list of a player (hc+228h, records of 28h built from the deck by
// FUN_006301DE) keeps the sends left in [card+20h], set to <maxcount> [card+4] when the list is built. The send
// FUN_0085A724 refuses a card with <maxcount> >= 0 and no sends left ("You have already sent %s", 8FFDh, 0x85A9B9)
// and takes one with FUN_0085FBEA(card, -1) (0x85ACF8); a cancel gives it back (+1, 0x85AE98); the shipment panel
// greys such a card (0x9A5AFC). The card's tech has the HomeCity flag, which the tech activation 0x94CF27 never
// refuses as already active, so the tech runs again at each shipment. The age setter FUN_008D4E01 calls
// FUN_0085650A(hc) when the new age is above 3 (the Imperial Age), which sets [card+20h] = [card+4] for each card of
// the list whose byte [card+24h] is 1 (<infiniteinlastage>). The field is in the saved game (the card's save at
// 0x85FC40 writes +20h and the byte +24h).
//
// The key: the tag sets bit 1 (02h) of the card's byte +24h in the home city's card array, read through the shared
// card tag hook (cardtags.h); the deck build, the save and the load copy the byte whole, so every player's copy of
// the card carries it. At the age setter's join after the new age is written (0x8D502F, before the stock refill),
// when the player advances (the setter's flag [esp+13h] is 0), each card of the player's list with the bit and a
// <maxcount> of 0 or more gets [card+20h] = [card+4]: one reset per age-up, never added to what is left, so an age
// with no send does not stack. An <infiniteinlastage> card that also has the bit is refilled the same way at the
// Imperial Age (stock's test `== 1` no longer matches it, and this reset has already done it). The card rollover
// builder hides the card's cost after its tech was researched unless the card is <infiniteinlastage> in age 4 with
// sends left; for a card with the bit the age test is skipped, so the cost shows again when it can be sent.
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <string>

#include "../cardtags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcResendAgeHook();
void UhcResendCostHook();
}

namespace {

constexpr std::uint32_t kAgeJoin = 0x008D502F;     // mov eax,[0C66234h]
constexpr std::uint32_t kCostAgeCheck = 0x00710804;  // cmp dword ptr [eax+50h],4 / jne 710863h
constexpr std::uint8_t kResendBit = 0x02;           // in the card's byte +24h; bit 0 is <infiniteinlastage>
constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr int kMaxLines = 200;

bool g_log = false;
int g_lines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

void Line(const wchar_t* format, ...) {
  if (g_lines >= kMaxLines) {
    return;
  }
  wchar_t text[512];
  va_list args;
  va_start(args, format);
  _vsnwprintf_s(text, _TRUNCATE, format, args);
  va_end(args);
  ++g_lines;
  uhc::Log(L"%ls%ls", text, g_lines == kMaxLines ? L" (no more lines are logged)" : L"");
}

const wchar_t* TechName(std::int32_t id) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (database == nullptr) {
    return L"?";
  }
  const wchar_t* const* names = Field<const wchar_t* const*>(database, 0x3824);
  if (names == nullptr || id < 0 || id >= Field<std::int32_t>(database, 0x3828) || names[id] == nullptr) {
    return L"?";
  }
  return names[id];
}

const wchar_t* AgeName(std::int32_t age) {
  static const wchar_t* const kNames[] = {L"I", L"II", L"III", L"IV", L"V"};
  return age >= 0 && age < 5 ? kNames[age] : L"?";
}

// <resendeveryage>: 1 or true sets the bit, 0 or false clears it.
void ReadTag(char* hc, char* card, const wchar_t* text) {
  std::wstring value = text == nullptr ? L"" : text;
  while (!value.empty() && iswspace(value.back())) {
    value.pop_back();
  }
  std::size_t first = 0;
  while (first < value.size() && iswspace(value[first])) {
    ++first;
  }
  value = value.substr(first);
  auto& flags = *reinterpret_cast<std::uint8_t*>(card + 0x24);
  const std::int32_t tech = Field<std::int32_t>(card, 0x00);
  if (value == L"1" || _wcsicmp(value.c_str(), L"true") == 0) {
    flags = static_cast<std::uint8_t>(flags | kResendBit);
    if (g_log) {
      Line(L"resendableCards: card %d (%ls) of home city %p is sent again in each new age (maxcount %d)", tech,
           TechName(tech), static_cast<void*>(hc), Field<std::int32_t>(card, 0x04));
    }
  } else if (value == L"0" || _wcsicmp(value.c_str(), L"false") == 0) {
    flags = static_cast<std::uint8_t>(flags & ~kResendBit);
  } else {
    Line(L"resendableCards: <resendeveryage>%ls</resendeveryage> on card %d (%ls) is not 1, 0, true or false; ignored",
         value.c_str(), tech, TechName(tech));
  }
}

}  // namespace

extern "C" {

// From the age setter's join: `player` has its new age in [player+50h]; `notAdvance` is the setter's flag, 1 when
// the old age was the same or higher.
void __stdcall UhcResendAgeUp(char* player, std::uint32_t notAdvance) {
  if (player == nullptr || (notAdvance & 0xFF) != 0) {
    return;
  }
  char* hc = Field<char*>(player, 0x84);
  if (hc == nullptr) {
    return;
  }
  // The game's card list hc+228h: [list+1Ch] the records, [list+20h] their count (FUN_0085FFCE).
  char* cards = Field<char*>(hc, 0x228 + 0x1C);
  const std::int32_t count = Field<std::int32_t>(hc, 0x228 + 0x20);
  for (std::int32_t i = 0; cards != nullptr && i < count; ++i) {
    char* card = cards + static_cast<std::uint32_t>(i) * 0x28;
    if ((Field<std::uint8_t>(card, 0x24) & kResendBit) == 0) {
      continue;
    }
    const std::int32_t max = Field<std::int32_t>(card, 0x04);
    const std::int32_t left = Field<std::int32_t>(card, 0x20);
    if (max < 0 || left == max) {
      continue;  // infinite, or not sent since the last reset
    }
    *reinterpret_cast<std::int32_t*>(card + 0x20) = max;
    if (g_log) {
      const std::int32_t tech = Field<std::int32_t>(card, 0x00);
      Line(L"resendableCards: player %d reached Age %ls: card %d (%ls) can be sent %d time(s) again (it had %d left)",
           Field<std::int32_t>(player, 0x00), AgeName(Field<std::int32_t>(player, 0x50)), tech, TechName(tech), max,
           left);
    }
  }
}

// From the card rollover's cost test: true when the card has the bit (the age test is then skipped).
bool __stdcall UhcResendCard(const char* card) {
  return card != nullptr && (Field<std::uint8_t>(card, 0x24) & kResendBit) != 0;
}
}

namespace uhc {

Outcome ApplyResendableCards(const Config& config) {
  const Config::Args* args = config.First("resendableCards");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"resendableCards: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("resendableCards", {&sites::kAgeUpJoin, &sites::kAgeUpStockRefill, &sites::kSetAgeAdvanceFlag,
                                     &sites::kCardRolloverAgeCheck, &sites::kCardRolloverHead})) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!AddCardTagHandler("resendableCards", "resendeveryage", &ReadTag) ||
      !WriteJmp(kAgeJoin, reinterpret_cast<const void*>(&UhcResendAgeHook), 5) ||
      !WriteJmp(kCostAgeCheck, reinterpret_cast<const void*>(&UhcResendCostHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"resendableCards: a card with <resendeveryage>1</resendeveryage> gets its sends back (its maxcount) each time "
      L"its player reaches a new age%ls (multiplayer unverified)",
      log ? L"; each card read and each reset is logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/resendcards_hooks.asm

```asm
; resendableCards (src/features/resendcards.cpp): the age setter's join and the card rollover's cost test. Each
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcResendAgeUp PROTO STDCALL player:DWORD, notAdvance:DWORD
UhcResendCard PROTO STDCALL card:DWORD

.data
ageNext         dd 008D5034h    ; mov ecx,[eax+13Ch], in the age setter
costShow        dd 0071080Ah    ; mov eax,[ebp] / push eax / mov ecx,edi / call 852F11h: the sends-left test
costHide        dd 00710863h    ; past the cost line

.code

; Replaces mov eax,[0C66234h] at 0x8D502F in the age setter FUN_008D4E01 (thiscall(player, age, announce, tech)),
; the join every path takes once the new age is in [esi+50h] (0x8D4F49, 0x8D4F54, 0x8D4F5F and the fall-through
; after the age-up message). ESI = the player; the byte [esp+13h] is 1 when the old age was the same or higher
; (0x8D4EE3..0x8D4EF2, same frame). EAX, ECX and EDX are written before they are read after 0x8D5034
; (mov ecx,[eax+13Ch], the cmp at 0x8D503A, mov edx,[esi] at 0x8D505D); EBX, ESI, EDI and EBP are kept by the call.
UhcResendAgeHook PROC
    TRACE_ONCE "resendableCards age (0x8D502F)"
    movzx eax, byte ptr [esp+13h]
    push eax
    push esi
    call UhcResendAgeUp
    mov eax, dword ptr ds:[0C66234h]
    jmp ageNext
UhcResendAgeHook ENDP

; Replaces cmp dword ptr [eax+50h],4 / jne 710863h at 0x710804 in the card rollover builder FUN_007103CE, reached
; only for the local player's own card whose byte [ebp+24h] is not 0, with EAX = the player and EBP = the card.
; Age 4 goes on as stock; otherwise a card with the resend bit goes on to the sends-left test too, and any other
; card skips the cost line as stock. EAX and ECX are reloaded at 0x71080A; EDX is not read before it is written.
UhcResendCostHook PROC
    TRACE_ONCE "resendableCards rollover (0x710804)"
    cmp dword ptr [eax+50h], 4
    je show
    push ebp
    call UhcResendCard
    test al, al
    jz hide
show:
    jmp costShow
hide:
    jmp costHide
UhcResendCostHook ENDP

END
```

## quickArrivalCards

Contract: [quickArrivalCards](../porting-to-another-dll.md#quickarrivalcards).

Sites: `BStringAppend` `0x443960` (16 B), `CardBulletLine` `0x4C5076` (42 B), `CardRolloverHead` `0x7103CE` (38 B), `CardRolloverAdvanced` `0x710909` (6 B).

### src/features/quickarrival.cpp

```cpp
// quickArrivalCards [stringid N] [log]: <Flag>QuickArrival</Flag> on a home city card's tech adds the bullet line
// "This is a QUICK-ARRIVAL card." to the card's rollover, right after its send-limit line ("This Card may be sent
// INFINITE times" / "ONE time" / N times), before the advanced info. Display only.
//
// The card rollover builder FUN_007103CE(list, hc, tech, ...) is the one used by the in-game shipment panel
// (0x9A61B7), the deck builder of the home city screen (0x9A0714) and the deck dialog (0x9A7A1E), all three in list
// mode (its sixth argument 1). Its lines, in order: the name (header, FUN_004C5032), the population, the unit's own
// text when the tech has no rollover text, "This Card cannot be sent until Age N" (9012h), the cost, the tech's
// rollover text, the send-limit line (9001h/9002h/9003h), then, with the detailed help option on, the advanced info
// FUN_0071006D. Each line goes through FUN_004C5076(list, line, 1, 0), which appends "<ttf><ttb>" and the line: the
// bullet. The key's hook sits at the join before the advanced info (0x710909) and appends its line the same way.
//
// The flag is read through the shared flag reader hook (techflags.h); the techs are kept by ID.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../techflags.h"

extern "C" void UhcQuickArrivalHook();

namespace {

constexpr std::uint32_t kAdvancedJoin = 0x00710909;  // mov ecx,[0D6F6F0h]
constexpr std::int32_t kMaxTech = 1 << 20;
constexpr const wchar_t* kDefaultText = L"This is a QUICK-ARRIVAL card.";
constexpr const wchar_t* kBullet = L"<ttf><ttb>";  // what FUN_004C5076(list, line, 1, 0) puts before a line

// The engine's string: one pointer to a wide, reference-counted buffer; null is empty.
struct BString {
  wchar_t* text;
};
using AppendFn = void(__thiscall*)(void* text, const wchar_t* more, std::int32_t length, std::int32_t start);
const auto kAppend = reinterpret_cast<AppendFn>(0x00443960);  // BString append; -1, -1: all of it, at the end
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t stringId);
using BStringFreeFn = void(__thiscall*)(BString* self);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);

std::vector<bool> g_quick;  // by tech ID; filled while the techtree loads
std::int32_t g_stringId = -1;
bool g_log = false;
int g_logLines = 0;
bool g_loggedLine = false;

bool ReadFlag(char* record, const char* name) {
  if (_stricmp(name, "QuickArrival") != 0) {
    return false;
  }
  const char* def = *reinterpret_cast<const char* const*>(record);
  const std::int32_t tech = def == nullptr ? -1 : *reinterpret_cast<const std::int32_t*>(def);
  if (tech < 0 || tech >= kMaxTech) {
    return true;
  }
  if (static_cast<std::size_t>(tech) >= g_quick.size()) {
    g_quick.resize(static_cast<std::size_t>(tech) + 1, false);
  }
  g_quick[static_cast<std::size_t>(tech)] = true;
  if (g_log && g_logLines < 200) {
    ++g_logLines;
    uhc::Log(L"quickArrivalCards: tech %d has the QuickArrival flag", tech);
  }
  return true;
}

}  // namespace

// From the hook, once the card's send-limit line is in: `list` is the rollover being built, `tech` the card's tech
// ID, `listMode` the builder's sixth argument (1 in the three callers: one bulleted line per entry).
extern "C" void __stdcall UhcQuickArrivalLine(void* list, std::int32_t tech, std::uint32_t listMode) {
  if (list == nullptr || tech < 0 || static_cast<std::size_t>(tech) >= g_quick.size() ||
      !g_quick[static_cast<std::size_t>(tech)]) {
    return;
  }
  BString fromTable{nullptr};
  const wchar_t* text = kDefaultText;
  if (g_stringId >= 0) {
    kBStringFromId(&fromTable, g_stringId);
    if (fromTable.text != nullptr && fromTable.text[0] != 0) {
      text = fromTable.text;
    }
  }
  if ((listMode & 0xFF) != 0) {
    kAppend(list, kBullet, -1, -1);
  } else {
    kAppend(list, L"\n", -1, -1);  // the builder's string mode puts each line after a line break
  }
  kAppend(list, text, -1, -1);
  if (g_log && !g_loggedLine) {
    g_loggedLine = true;
    uhc::Log(L"quickArrivalCards: the line was added to the rollover of tech %d (logged once)", tech);
  }
  if (g_stringId >= 0) {
    kBStringFree(&fromTable);
  }
}

namespace uhc {

Outcome ApplyQuickArrivalCards(const Config& config) {
  const Config::Args* args = config.First("quickArrivalCards");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  std::int32_t stringId = -1;
  for (std::size_t i = 0; i < args->size(); ++i) {
    const std::string& arg = (*args)[i];
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (_stricmp(arg.c_str(), "stringid") == 0 && i + 1 < args->size()) {
      const std::string& value = (*args)[++i];
      char* end = nullptr;
      const long id = std::strtol(value.c_str(), &end, 10);
      if (value.empty() || *end != 0 || id < 0 || id > 0x7FFFFFFF) {
        Log(L"quickArrivalCards: stringid %hs is not a string ID (0 or more); feature not applied", value.c_str());
        return Outcome::kFailed;
      }
      stringId = static_cast<std::int32_t>(id);
    } else {
      Log(L"quickArrivalCards: unexpected argument %hs (expected: [stringid N] [log]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("quickArrivalCards", {&sites::kCardRolloverHead, &sites::kCardRolloverAdvanced,
                                       &sites::kCardBulletLine, &sites::kBStringAppend})) {
    return Outcome::kFailed;
  }
  g_log = log;
  g_stringId = stringId;
  if (!AddTechFlagHandler("quickArrivalCards", &ReadFlag) ||
      !WriteJmp(kAdvancedJoin, reinterpret_cast<const void*>(&UhcQuickArrivalHook), 6)) {
    return Outcome::kFailed;
  }
  if (stringId >= 0) {
    Log(L"quickArrivalCards: the tech flag QuickArrival adds the line of string %d to a card's rollover", stringId);
  } else {
    Log(L"quickArrivalCards: the tech flag QuickArrival adds the line \"%ls\" to a card's rollover", kDefaultText);
  }
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/quickarrival_hooks.asm

```asm
; quickArrivalCards (src/features/quickarrival.cpp): the card rollover builder's join before the advanced info. It
; leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcQuickArrivalLine PROTO STDCALL list:DWORD, tech:DWORD, listMode:DWORD

.data
advancedNext    dd 0071090Fh    ; mov edx,[ecx], in the card rollover builder

.code

; Replaces mov ecx,[0D6F6F0h] at 0x710909 in FUN_007103CE (cdecl(list, hc, tech, ...), frame: sub esp,30h and four
; pushes), reached from 0x7108C3, 0x7108DB and the fall-through at 0x710904, all with no push outstanding: the
; list is [esp+44h], the tech ID [esp+4Ch], the list-mode byte [esp+58h] (EBX holds it too). ECX is reloaded here,
; EDX at 0x71090F and EAX by the call at 0x710917; EBX, ESI, EDI and EBP are kept by the call.
UhcQuickArrivalHook PROC
    TRACE_ONCE "quickArrivalCards (0x710909)"
    push dword ptr [esp+58h]        ; list mode
    push dword ptr [esp+50h]        ; tech, [esp+4Ch] + one push
    push dword ptr [esp+4Ch]        ; list, [esp+44h] + two pushes
    call UhcQuickArrivalLine
    mov ecx, dword ptr ds:[0D6F6F0h]
    jmp advancedNext
UhcQuickArrivalHook ENDP

END
```

## kothTimer

Contract: [kothTimer](../porting-to-another-dll.md#kothtimer).

Sites: `KothSetEnd` `0x948A4C` (28 B), `KothStartCall` `0x948F93` (18 B), `KothTotalTime` `0x9F02DD` (72 B).

### src/features/kothtimer.cpp

```cpp
// kothTimer: the King of the Hill victory time from a table by the number of players or of teams.
//
// When a team takes the hill (ypKingsHill), FUN_00948F32 (thiscall on the team) starts its timer: the time is
// FUN_009F02DD() - [team+84h], in seconds, and 0x948A1F sets the end at now + 1000 x that. FUN_009F02DD, on the
// victory settings of DefaultVP.xml ([world+0A8h]), computes KOTHVictoryTime (+104h) + (players - 1) x
// KOTHVictoryTimePerPlayer (+108h, when above 0) - (teams - AdjustKOTHTotalTimeByTeams (+10Ch)) x
// AdjustKOTHTotalTimeByTeamsFactor (+110h), with players = [world+5Ch] (Gaia included) and teams = [world+18Ch].
// Its only caller is 0x948F95.
//
// The key jumps at its head (hooks/kothtimer_hooks.asm) and answers from the cfg's table: the time of the largest
// count listed that is not above the game's count (or of the smallest listed). Players are the players without Gaia,
// teams the distinct teams of those players.
#include <windows.h>

#include <charconv>
#include <climits>
#include <cstdint>
#include <cstring>
#include <iterator>
#include <map>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr int kMaxCount = 16;
constexpr int kMaxSeconds = 86400;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

bool g_teams = false;               // count teams, not players
std::map<int, int> g_seconds;       // count -> seconds

bool ParseInt(const std::string& text, int low, int high, int* value) {
  const char* first = text.data();
  const char* last = first + text.size();
  const auto [end, error] = std::from_chars(first, last, *value);
  return error == std::errc() && end == last && *value >= low && *value <= high;
}

// The stock time, as FUN_009F02DD computes it, for the log.
int StockSeconds(const char* vp, const char* world) {
  int time = Field<std::int32_t>(vp, 0x104);
  const int perPlayer = Field<std::int32_t>(vp, 0x108);
  if (perPlayer > 0) {
    time += (Field<std::int32_t>(world, 0x5C) - 1) * perPlayer;
  }
  return time - (Field<std::int32_t>(world, 0x18C) - Field<std::int32_t>(vp, 0x10C)) * Field<std::int32_t>(vp, 0x110);
}

}  // namespace

extern "C" {

void UhcKothTimeHook();  // hooks/kothtimer_hooks.asm

// From the head of FUN_009F02DD: the victory settings in ECX. INT_MIN lets the stock code compute the time.
std::int32_t __stdcall UhcKothTime(const char* vp) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (vp == nullptr || world == nullptr || g_seconds.empty()) {
    return INT_MIN;
  }
  const std::int32_t slots = Field<std::int32_t>(world, 0x5C);
  const char* const* players = Field<const char* const*>(world, 0x58);
  int playerCount = 0;
  std::uint32_t teamMask = 0;
  int teamCount = 0;
  for (std::int32_t id = 1; players != nullptr && id < slots && id < 32; ++id) {
    const char* player = players[id];
    if (player == nullptr) {
      continue;
    }
    ++playerCount;
    const std::int32_t team = Field<std::int32_t>(player, 0x10);
    if (team >= 0 && team < 32 && (teamMask & (1u << team)) == 0) {
      teamMask |= 1u << team;
      ++teamCount;
    }
  }
  const int count = g_teams ? teamCount : playerCount;
  auto entry = g_seconds.upper_bound(count);
  entry = entry == g_seconds.begin() ? entry : std::prev(entry);
  const int seconds = entry->second;
  uhc::Log(L"kothTimer: %d player(s) in %d team(s): the hill holds for %d s (the %ls %d entry; stock %d s, its counts "
           L"%d slot(s), %d team(s))",
           playerCount, teamCount, seconds, g_teams ? L"teams" : L"players", entry->first, StockSeconds(vp, world),
           slots, Field<std::int32_t>(world, 0x18C));
  return seconds;
}
}

namespace uhc {

Outcome ApplyKothTimer(const Config& config) {
  const Config::Args* args = config.First("kothTimer");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::map<int, int> seconds;
  bool teams = false;
  bool modeGiven = false;
  for (const std::string& arg : *args) {
    const std::size_t equals = arg.find('=');
    int count = 0;
    int value = 0;
    if (!modeGiven && seconds.empty() &&
               (_stricmp(arg.c_str(), "players") == 0 || _stricmp(arg.c_str(), "teams") == 0)) {
      teams = _stricmp(arg.c_str(), "teams") == 0;
      modeGiven = true;
    } else if (equals != std::string::npos && ParseInt(arg.substr(0, equals), 1, kMaxCount, &count) &&
               ParseInt(arg.substr(equals + 1), 1, kMaxSeconds, &value) && seconds.count(count) == 0) {
      seconds[count] = value;
    } else {
      Log(L"kothTimer: unexpected argument %hs (expected: [players | teams] N=seconds ..., N from 1 to %d, "
          L"seconds from 1 to %d, each N once); feature not applied",
          arg.c_str(), kMaxCount, kMaxSeconds);
      return Outcome::kFailed;
    }
  }
  if (seconds.empty()) {
    Log(L"kothTimer: no N=seconds entry; feature not applied");
    return Outcome::kFailed;
  }
  if (!VerifyAll("kothTimer", {&sites::kKothTotalTime, &sites::kKothStartCall, &sites::kKothSetEnd})) {
    return Outcome::kFailed;
  }
  g_teams = teams;
  g_seconds = seconds;
  if (!WriteJmp(sites::kKothTotalTime.va, reinterpret_cast<const void*>(&UhcKothTimeHook), 5)) {
    return Outcome::kFailed;
  }
  std::wstring table;
  for (const auto& [count, value] : seconds) {
    table += L" " + std::to_wstring(count) + L"=" + std::to_wstring(value);
  }
  Log(L"kothTimer: the King of the Hill time by the number of %ls:%ls s (multiplayer unverified)",
      teams ? L"teams" : L"players", table.c_str());
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/kothtimer_hooks.asm

```asm
; Hook for kothTimer. Entered through a jmp over the head of FUN_009F02DD, the King of the Hill time; returns from
; that function itself, or leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcKothTime PROTO STDCALL vp:DWORD

.data
kothNext        dd 009F02E2h    ; mov edx,[eax+13Ch]: the stock function after its first instruction

.code

; Replaces 0x9F02DD..0x9F02E1 (mov eax,[0C66234h]). int thiscall(victory settings = ECX), no arguments, plain ret;
; its only caller is 0x948F95, which reads EAX. UhcKothTime returns the seconds, or 80000000h: then ECX is restored
; and the stolen load runs before the stock code. EAX, ECX and EDX are free in a thiscall.
UhcKothTimeHook PROC
    TRACE_ONCE "kothTimer (0x9F02DD)"
    push ecx
    push ecx                        ; the victory settings
    call UhcKothTime
    pop ecx
    cmp eax, 80000000h
    je stock
    ret
stock:
    mov eax, dword ptr ds:[0C66234h]  ; stolen 0x9F02DD
    jmp kothNext
UhcKothTimeHook ENDP

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

Besides the core helpers, it needs: [`modifiers.h`](helpers.md#modifier-walk), [`transformcalls.h`](helpers.md#transform-calls), [`worldtick.h`](helpers.md#world-tick).

Sites: `XmlText` `0x402733` (9 B), `SnareApply` `0x4DD22D` (130 B), `XmlAttribute` `0x598F37` (16 B), `TransformProtoLookup` `0x9C754C` (22 B).

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
#include "../transformcalls.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr std::int32_t kStatFrom = 0x60;           // a modifier's value: the proto to go back to
constexpr std::int32_t kStatEnd = 0x61;            // the game time to do it, in tenths of a second
constexpr std::int32_t kMarkerExtraMs = 5000;      // the marker outlives the entry by this
constexpr float kDoneMarker = -1.0f;
constexpr int kMaxLogLines = 200;

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
using TransformFn = void(__thiscall*)(char* unit, std::int32_t proto);
using ModifierFn = std::int32_t(__thiscall*)(char* unit, std::int32_t stat, float value, float, float, std::int32_t,
                                             std::int32_t operation, std::int32_t ms, std::int32_t, std::int32_t,
                                             std::int32_t exclusive);
using IsBuiltFn = bool(__thiscall*)(const char* unit);
using IsAliveFn = bool(__thiscall*)(const char* unit);

const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
const auto kModifier = reinterpret_cast<ModifierFn>(0x004DD22D);
const auto kIsBuilt = reinterpret_cast<IsBuiltFn>(0x0044DDB4);

struct Pending {
  std::int32_t unit;
  std::int32_t from;
  std::int32_t to;
  std::uint32_t end;  // game time, ms
};

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
  uhc::TransformUnit(unit, entry.from);
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

void ReadEffect(void* effect, const void* node) {
  const void* text = nullptr;
  if (kXmlAttribute(node, "transformspan", &text) && text != nullptr) {
    const double seconds = std::atof(kXmlText(text));
    if (seconds > 0.0) {
      g_spans[effect] = static_cast<std::int32_t>(seconds * 1000.0 + 0.5);
      if (g_log) {
        uhc::Log(L"transformSpan: an effect lasts %.1f s", seconds);
      }
    }
  }
}

void BeforeApply(void* effect) {
  const auto found = g_spans.find(effect);
  g_runningSpan = found == g_spans.end() ? 0 : found->second;
}

void AfterApply(void*) { g_runningSpan = 0; }

// Takes the call of 0x9C754C in the effect's apply.
void Transform(char* unit, std::int32_t proto) {
  const std::int32_t was = ProtoId(unit);
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  Pending* pending = nullptr;
  for (Pending& entry : g_pending) {
    if (entry.unit == id) {
      pending = &entry;
    }
  }
  uhc::TransformUnit(unit, proto);
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
  if (!VerifyAll("transformSpan", {&sites::kSnareApply, &sites::kXmlAttribute, &sites::kXmlText,
                                   &sites::kTransformProtoLookup}) ||
      !AddTransformEffectReader({&ReadEffect, &BeforeApply, &AfterApply}) ||
      !SetTransformEffectWrapper(&Transform) || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  Log(L"transformSpan: TransformUnit effects take transformspan");
  return Outcome::kApplied;
}

}  // namespace uhc
```

## transformInventory

Contract: [transformInventory](../porting-to-another-dll.md#transforminventory).

Besides the core helpers, it needs: [`transformcalls.h`](helpers.md#transform-calls), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `XmlText` `0x402733` (9 B), `IsA` `0x44D7FA` (105 B), `ResListCopy` `0x480A73` (73 B), `ResListScale` `0x480B94` (126 B), `InventoryFree` `0x4BA757` (80 B), `ResListTotal` `0x58EF02` (129 B), `XmlAttribute` `0x598F37` (16 B), `InventorySeed` `0x67DE0D` (30 B), `InventoryRecreate` `0x9BFE5A` (110 B), `TransformProtoLookup` `0x9C754C` (22 B), `TransformKbRemove` `0x9C75CF` (86 B), `TransformInvHook` `0x9C7625` (23 B), `TransformPushProto` `0x9C763C` (3 B), `TransformKbReAdd` `0x9C766F` (35 B).

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
//
// inventory='keep', 'rebuild' or 'scale' on a TransformUnit effect decides for that effect, over the
// cfg: keep leaves the inventory as stock does, rebuild is "all", and scale is "all scale". A transform
// that no effect runs, as a revolution or a turn back, follows the cfg.
#include <bit>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../transformcalls.h"
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

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);

enum class Mode { kCfg, kKeep, kRebuild, kScale };
std::unordered_map<void*, Mode> g_modes;  // by effect, from inventory='...'
Mode g_running = Mode::kCfg;              // of the effect that is applying

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
  if (g_running == Mode::kKeep) {
    return;
  }
  const bool all = g_all || g_running == Mode::kRebuild || g_running == Mode::kScale;
  const bool scale = g_running == Mode::kScale || (g_running == Mode::kCfg && g_scale);
  if (g_running == Mode::kCfg && g_typeGiven && (g_type < 0 || !kProtoIsType(newProto, g_type))) {
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
    if (!all) {
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

  if (!all && inventory != nullptr && oldRes != nullptr && SameTypes(oldRes, newRes, count)) {
    if (g_log) {
      uhc::Log(L"transformInventory: unit %d (%hs -> %hs) keeps its inventory %ls (same resource types)", id,
               ProtoName(oldProto), ProtoName(newProto), Describe(inventory + 4, count).c_str());
    }
    return;
  }

  // The fraction of the old InitialResource still in the inventory, read before the copy. Single
  // precision division of two game values: the same result on every machine with this build.
  float factor = 1.0f;
  if (scale && inventory != nullptr && oldRes != nullptr) {
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

namespace {

void ReadEffect(void* effect, const void* node) {
  const void* text = nullptr;
  if (!kXmlAttribute(node, "inventory", &text) || text == nullptr) {
    return;
  }
  const char* value = kXmlText(text);
  if (_stricmp(value, "keep") == 0) {
    g_modes[effect] = Mode::kKeep;
  } else if (_stricmp(value, "rebuild") == 0) {
    g_modes[effect] = Mode::kRebuild;
  } else if (_stricmp(value, "scale") == 0) {
    g_modes[effect] = Mode::kScale;
  } else {
    uhc::Log(L"transformInventory: inventory='%hs' is not keep, rebuild or scale; ignored", value);
    return;
  }
  if (g_log) {
    uhc::Log(L"transformInventory: an effect has inventory='%hs'", value);
  }
}

void BeforeApply(void* effect) {
  const auto found = g_modes.find(effect);
  g_running = found == g_modes.end() ? Mode::kCfg : found->second;
}

void AfterApply(void*) { g_running = Mode::kCfg; }

void NewDatabase(char*) { g_modes.clear(); }

}  // namespace

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
                  &sites::kResListTotal, &sites::kIsA, &sites::kXmlAttribute, &sites::kXmlText})) {
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
  if (!OnDatabaseLoad(&NewDatabase) || !AddTransformEffectReader({&ReadEffect, &BeforeApply, &AfterApply})) {
    Log(L"transformInventory: no inventory= on effects; the key works from the cfg");
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

## garrisonConvert

Contract: [garrisonConvert](../porting-to-another-dll.md#garrisonconvert).

Besides the core helpers, it needs: [`garrisonobservers.h`](helpers.md#garrison-entries), [`progresspie.h`](helpers.md#progress-pie), [`prototags.h`](helpers.md#proto-tags), [`savedmarkers.h`](helpers.md#state-kept-for-a-saved-game), [`techsubtypes.h`](helpers.md#tech-subtypes), [`transformcalls.h`](helpers.md#transform-calls), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `BStringFree` `0x4010CA` (31 B), `IsA` `0x44D7FA` (105 B), `PlayerProtoEntry` `0x45311B` (8 B), `PlayerPopHead` `0x45805C` (13 B), `PlayerPopCapHead` `0x4581A1` (18 B), `ProtoFlag` `0x45EE02` (53 B), `BStringFromId` `0x58EA52` (25 B), `XmlAttribute` `0x598F37` (16 B), `ProtoByName` `0x5A2346` (32 B), `EffectValueApply` `0x7F892A` (16 B), `GarrisonLoadHead` `0x9C24B5` (16 B), `GarrisonEnterTail` `0x9C26E1` (31 B), `GarrisonUnloadHead` `0x9C68C3` (30 B), `PopCapToast` `0x9EB0D6` (51 B), `PopCapToastSound` `0x9EB137` (15 B), `UnitAliveSlot` `0xB9355C` (4 B).

### src/features/garrisonconvert.cpp

```cpp
// garrisonConvert [log]: the units that enter a building become another unit. In a proto's <Unit>, one tag or more:
//
//   <GarrisonConvertTo>Musketeer</GarrisonConvertTo>                each unit becomes a Musketeer as it enters
//   <GarrisonConvertTo delay="10">Musketeer</GarrisonConvertTo>     one at a time, each after 10 seconds inside
//   <GarrisonConvertTo eject="true">Musketeer</GarrisonConvertTo>   and is put out of the building once converted
//   <GarrisonConvertTo from="Settler">Pikeman</GarrisonConvertTo>   only Settlers (a proto or an abstract type)
//
// Only the units of the building's owner are converted, and never a unit that already is the target of one of the
// building's tags, as the data or the techs have them (so a converted unit is not converted again). The unit is changed in place by the shared transform
// (transformcalls.h, so the transform observers such as veterancyBonus see it): it keeps its ID, its owner and its
// share of hit points; it stays inside, or with eject the unload of one unit 0x9C68C3 puts it out as the building's
// eject command does. The tags are read once per data load, by proto ID, in their order.
//
// Several tags: round robin. For each conversion the building takes, from its cursor, the first tag (in order,
// wrapping) whose from matches the unit in progress; the cursor then moves past that tag. With A (from Settler) and
// B (no from), Settler, Settler -> A, B; Musketeer, Settler -> B, A.
//
// The population: a conversion that would put the owner over his cap (the target's population minus the unit's, the
// test the Maintain spawn makes, with AllowOverPopCap and AlwaysAllowOverPopCap) waits, with its timer held full,
// and the owner's screen gets the train's own message once per pause (string 17996, "No population room for %s;
// training will be suspended.", and its sound: 0x9EB0D6). It goes on by itself once there is room.
//
// The entries come from the shared garrison observer (garrisonobservers.h), which only marks the building active; the
// conversions happen after the world update (worldtick.h). The queue is the building's own list of contained units
// [unit+70h] (count [+74h]), which is in entry order: the first unit of it that qualifies is the one in progress, so
// a unit that leaves simply drops out of it. State, kept on the building as saved markers (savedmarkers.h, stat 6Ch):
// 'GCNV' the time the unit in progress has spent, its ID and the game time of the write; 'GCRR' the round robin
// cursor and the pause. A game that starts or loads finds its active buildings with one walk of the world's units.
//
// Techs: Data subtypes on a ProtoUnit target change one player's copy of the building's tags (GarrisonConvertDelay,
// GarrisonConvertEject, GarrisonConvertTarget, GarrisonConvertFrom, GarrisonConvertAdd, GarrisonConvertRemove; the
// optional effect attribute tag="N" picks the N-th tag). A load applies the effects again, so nothing is saved.
//
// GarrisonConvertProgress (features.h) gives the panels the progress of a building; with a delay, the progress pie
// (progresspie.h, the train button's pie) fills over the portrait of a selected building while a unit converts.
#include <windows.h>

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../garrisonobservers.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../progresspie.h"
#include "../prototags.h"
#include "../savedmarkers.h"
#include "../techsubtypes.h"
#include "../transformcalls.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database, +3C0h the local player
constexpr std::int32_t kStat = 0x6C;               // savedmarkers.h: no other key uses it
constexpr std::uint32_t kWord = 0x564E4347;        // word 0 of the progress marker: 'GCNV'
constexpr std::uint32_t kCursorWord = 0x52524347;  // word 0 of the round robin marker: 'GCRR'
constexpr float kMaxDelay = 3600.0f;
constexpr std::size_t kMaxTags = 32;
constexpr int kMaxLogLines = 400;
constexpr std::size_t kTypeNames = 0x190;       // in the database: the unit type name table
constexpr std::size_t kFirstAbstract = 0x19B0;  // in the database: the first abstract type's ID
constexpr std::size_t kProtoTable = 0x54;       // in the database: the proto array (a new one for each data load)
constexpr std::uint32_t kProtoPop = 0xD8;       // the proto's population count
constexpr std::uint32_t kProtoDisplayName = 0x140;
constexpr std::int32_t kAllowOverPopCap = 0x9F;        // proto flags: needs only cap - used > 0
constexpr std::int32_t kAlwaysAllowOverPopCap = 0xA3;  // no population test
constexpr std::int32_t kStringNoPopRoom = 17996;       // cStringNoPopcapRoom, the train's message
constexpr std::uint32_t kMessageStyle = 0x00C6657C;    // the train's message: its style
constexpr std::uint32_t kNoPosition = 0x00C665E4;      // (-1, -1, -1): the unload finds the place
constexpr std::uint32_t kZeroVector = 0x00C66550;      // (0, 0, 0): no point to walk to

using IsAliveFn = bool(__thiscall*)(const char* unit);
using ProtoByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
using NameBucketFn = std::int32_t(__thiscall*)(const void* table, const char* name);
using NameFindFn = bool(__thiscall*)(const void* table, const char* name, std::int32_t bucket, std::int32_t* id);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
using PlayerProtoFn = char*(__thiscall*)(const char* player, std::int32_t protoId);
using PlayerCountFn = std::int32_t(__thiscall*)(const char* player);
using ProtoFlagFn = bool(__thiscall*)(const char* proto, std::int32_t bit);
using UnloadFn = bool(__thiscall*)(char* container, std::int32_t unitId, const void* position, bool usePosition,
                                   bool keepOrders, bool force, std::int32_t a6, const void* goTo, std::int32_t a8,
                                   std::int32_t a9);
using BStringFromIdFn = void*(__thiscall*)(void* string, std::int32_t id);
using BStringFreeFn = void(__thiscall*)(void* string);
using MessageFn = bool(__cdecl*)(const char* game, std::int32_t ms, const void* style, const wchar_t* format, ...);
using SoundFn = void(__thiscall*)(const char* game, std::int32_t sound, std::int32_t a);
const auto kProtoByName = reinterpret_cast<ProtoByNameFn>(0x005A2346);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kPlayerPop = reinterpret_cast<PlayerCountFn>(0x0045805C);
const auto kPlayerPopCap = reinterpret_cast<PlayerCountFn>(0x004581A1);  // with basePop / extraPop
const auto kProtoHasFlag = reinterpret_cast<ProtoFlagFn>(0x0045EE02);
const auto kUnload = reinterpret_cast<UnloadFn>(0x009C68C3);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kPlaySound = reinterpret_cast<SoundFn>(0x0050547A);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Tag {
  std::string target;      // the proto's name, as read or as a tech set it
  std::string from;        // empty: any unit
  float delay = 0.0f;      // seconds
  float baseDelay = 0.0f;  // the value the tag was made with (BasePercent's base)
  float eject = 0.0f;      // 1: put out once converted
  float baseEject = 0.0f;
  std::int32_t targetId = -1;  // resolved against the current database; -1: converts nothing
  std::int32_t fromId = -1;    // a proto's or an abstract type's ID; -1: any
  bool fromBad = false;        // a from that names nothing: the tag converts nothing

  std::uint32_t DelayMs() const { return static_cast<std::uint32_t>(delay * 1000.0f + 0.5f); }
  bool Ejects() const { return eject > 0.5f; }
};
using Tags = std::vector<Tag>;
std::map<std::int32_t, Tags> g_tags;  // by the building's proto ID; the data load fills it
const char* g_resolvedFor = nullptr;  // the proto array the names were resolved against

struct TechTags {
  std::int32_t id;  // the proto ID the copy had: a reused pointer with another ID starts again
  Tags tags;
};
std::unordered_map<const char*, TechTags> g_tech;  // by the player's copy of the proto; lookups only

struct EffectArgs {
  std::int32_t type = -1;  // unittype: an ID in the unit type table, -1 when the effect names none
  std::string typeName;
  std::uint32_t tag = 0;  // tag="N": the N-th tag; 0 every tag
};
std::vector<EffectArgs> g_effects;  // an effect's field +10h is its index; each techtree read appends to it

struct State {
  std::uint32_t elapsed = 0;  // ms of game time the unit in progress has spent
  std::int32_t head = -1;     // the unit in progress; -1: the next one that qualifies takes `elapsed` over
  std::uint32_t cursor = 0;   // the next tag to try first
  bool paused = false;        // waiting for population room (the message was shown)
  bool loaded = false;        // cursor and pause read from the building's marker
};
std::map<std::int32_t, State> g_active;  // by building ID, in ID order: the same walk on every machine

const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
bool g_rescan = false;  // a tech changed some tags: look again for buildings with units inside
int g_failures = 0;

bool g_log = false;
int g_logLines = 0;

bool LogOk() {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return false;
  }
  ++g_logLines;
  return true;
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* MainWorld() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

const char* Database() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

char* UnitById(const char* world, std::int32_t id) {
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<IsAliveFn const* const*>(unit))[0xA4 / 4](unit); }

std::int32_t ProtoId(const char* proto) { return proto == nullptr ? -1 : Field<std::int32_t>(proto, 8); }

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* PlayerOf(const char* unit) { return Field<const char*>(unit, 0x44); }

std::int32_t UnitId(const char* unit) { return Field<std::int32_t>(unit, 0x10); }

const char* BuildingName(const char* building) { return ProtoName(Field<const char*>(building, 0x5C)); }

std::int32_t TypeId(const void* db, const char* name) {
  const char* table = static_cast<const char*>(db) + kTypeNames;
  std::int32_t id = -1;
  if (name == nullptr || *name == '\0' || !kNameFind(table, name, kNameBucket(table, name), &id)) {
    return -1;
  }
  return id;
}

// The tags read from the data, resolved against the current database once per data load.
void ResolveAll() {
  const char* database = Database();
  const char* table = database == nullptr ? nullptr : Field<const char*>(database, kProtoTable);
  if (table == nullptr || table == g_resolvedFor) {
    return;
  }
  g_resolvedFor = table;
  for (auto& [id, tags] : g_tags) {
    for (std::size_t i = 0; i < tags.size(); ++i) {
      Tag& tag = tags[i];
      tag.targetId = kProtoByName(database, tag.target.c_str());
      if (tag.targetId < 0) {
        uhc::Log(L"garrisonConvert: proto %d: <GarrisonConvertTo> %u, %hs, is not a proto; it converts nothing", id,
                 static_cast<unsigned>(i + 1), tag.target.c_str());
      }
      tag.fromId = -1;
      tag.fromBad = false;
      if (!tag.from.empty()) {
        tag.fromId = TypeId(database, tag.from.c_str());
        if (tag.fromId < 0) {
          tag.fromBad = true;
          uhc::Log(L"garrisonConvert: proto %d: <GarrisonConvertTo> %u: from=\"%hs\" is neither a proto nor a unit "
                   L"type; it converts nothing",
                   id, static_cast<unsigned>(i + 1), tag.from.c_str());
        }
      }
    }
  }
}

// The tags of the player's copy of a proto, as the data and the player's techs left them; null when it has none.
const Tags* TagsOfProto(const char* copy) {
  if (copy == nullptr || (g_tags.empty() && g_tech.empty())) {
    return nullptr;
  }
  ResolveAll();
  if (!g_tech.empty()) {
    const auto found = g_tech.find(copy);
    if (found != g_tech.end() && found->second.id == ProtoId(copy)) {
      return found->second.tags.empty() ? nullptr : &found->second.tags;
    }
  }
  const auto found = g_tags.find(ProtoId(copy));
  return found == g_tags.end() || found->second.empty() ? nullptr : &found->second;
}

const Tags* TagsOf(const char* unit) { return unit == nullptr ? nullptr : TagsOfProto(Field<const char*>(unit, 0x5C)); }

bool Matches(const Tag& tag, const char* copy) {
  if (tag.targetId < 0 || tag.fromBad) {
    return false;
  }
  return tag.fromId < 0 || ProtoId(copy) == tag.fromId || kProtoIsType(copy, tag.fromId);
}

bool IsTarget(const Tags& tags, std::int32_t protoId) {
  for (const Tag& tag : tags) {
    if (tag.targetId == protoId) {
      return true;
    }
  }
  return false;
}

// The tag a unit takes, from the cursor on; -1 when none of them takes it.
int ChooseTag(const Tags& tags, const char* copy, std::uint32_t cursor) {
  const std::size_t count = tags.size();
  for (std::size_t k = 0; k < count; ++k) {
    const std::size_t i = (cursor + k) % count;
    if (Matches(tags[i], copy)) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

// A target of the building's tags, as the techs left them or as the data has them (so that a tech that changes a
// target does not convert again the units the old target made).
bool IsBuildingTarget(const char* building, const Tags& tags, std::int32_t protoId) {
  if (IsTarget(tags, protoId)) {
    return true;
  }
  const auto data = g_tags.find(ProtoId(Field<const char*>(building, 0x5C)));
  return data != g_tags.end() && &data->second != &tags && IsTarget(data->second, protoId);
}

// A contained unit that qualifies: still inside, alive, the owner's, not a target of the building, and taken by a tag.
bool Qualifies(const char* unit, const char* building, const Tags& tags) {
  if (unit == nullptr || Field<std::int32_t>(unit, 0x6C) != UnitId(building) || PlayerOf(unit) != PlayerOf(building)) {
    return false;
  }
  const char* copy = Field<const char*>(unit, 0x5C);
  if (copy == nullptr || IsBuildingTarget(building, tags, ProtoId(copy)) || !IsAlive(unit)) {
    return false;
  }
  for (const Tag& tag : tags) {
    if (Matches(tag, copy)) {
      return true;
    }
  }
  return false;
}

// The first contained unit that qualifies, in entry order, and (if asked) how many do.
char* Head(const char* world, const char* building, const Tags& tags, std::int32_t* waiting) {
  const std::int32_t count = Field<std::int32_t>(building, 0x74);
  const std::int32_t* ids = Field<const std::int32_t*>(building, 0x70);
  char* head = nullptr;
  std::int32_t total = 0;
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    char* unit = UnitById(world, ids[i]);
    if (Qualifies(unit, building, tags)) {
      if (head == nullptr) {
        head = unit;
        if (waiting == nullptr) {
          break;
        }
      }
      ++total;
    }
  }
  if (waiting != nullptr) {
    *waiting = total;
  }
  return head;
}

// --- The tags --------------------------------------------------------------------------------------------------

std::string Trim(std::string text) {
  const auto first = text.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) {
    return {};
  }
  return text.substr(first, text.find_last_not_of(" \t\r\n") - first + 1);
}

std::string NarrowWide(const wchar_t* text) {
  std::string out;
  for (; text != nullptr && *text != L'\0'; ++text) {
    out += *text < 0x80 ? static_cast<char>(*text) : '?';
  }
  return Trim(out);
}

// True when the attribute is there; its text (maybe empty) in *out.
bool Attribute(const char* node, const char* name, std::string* out) {
  const void* value = nullptr;
  out->clear();
  if (node == nullptr || !kXmlAttribute(node, name, &value) || value == nullptr) {
    return false;
  }
  const char* text = kXmlText(value);
  *out = Trim(text == nullptr ? std::string() : std::string(text));
  return true;
}

bool __cdecl ReadConvertTo(void*, const char* node, char* proto) {
  const std::int32_t id = ProtoId(proto);
  Tag tag;
  tag.target = NarrowWide(*reinterpret_cast<const wchar_t* const*>(node + 0x14));
  if (tag.target.empty()) {
    uhc::Log(L"garrisonConvert: proto %d (%hs): <GarrisonConvertTo> is empty; ignored", id, ProtoName(proto));
    return true;
  }
  Tags& tags = g_tags[id];
  if (tags.size() >= kMaxTags) {
    uhc::Log(L"garrisonConvert: proto %d (%hs): more than %u <GarrisonConvertTo>; %hs ignored", id, ProtoName(proto),
             static_cast<unsigned>(kMaxTags), tag.target.c_str());
    return true;
  }
  std::string text;
  if (Attribute(node, "delay", &text)) {
    char* end = nullptr;
    const double seconds = std::strtod(text.c_str(), &end);
    if (text.empty() || *end != '\0' || !(seconds >= 0.0) || !(seconds <= kMaxDelay)) {
      uhc::Log(L"garrisonConvert: proto %d (%hs): delay=\"%hs\" is not a number of seconds from 0 to %g; 0 is used",
               id, ProtoName(proto), text.c_str(), static_cast<double>(kMaxDelay));
    } else {
      tag.delay = static_cast<float>(seconds);
    }
  }
  if (Attribute(node, "eject", &text)) {
    if (text.empty() || _stricmp(text.c_str(), "true") == 0 || text == "1") {
      tag.eject = 1.0f;
    } else if (_stricmp(text.c_str(), "false") != 0 && text != "0") {
      uhc::Log(L"garrisonConvert: proto %d (%hs): eject=\"%hs\" is not true, 1, false or 0; the units stay inside", id,
               ProtoName(proto), text.c_str());
    }
  }
  Attribute(node, "from", &tag.from);
  tag.baseDelay = tag.delay;
  tag.baseEject = tag.eject;
  tags.push_back(tag);
  g_resolvedFor = nullptr;
  if (g_log) {
    uhc::Log(L"garrisonConvert: proto %d (%hs), tag %u: %hs%hs become %hs, %ls %u ms%ls", id, ProtoName(proto),
             static_cast<unsigned>(tags.size()), tag.from.empty() ? "the units that enter" : "the units of ",
             tag.from.c_str(), tag.target.c_str(), tag.delay == 0.0f ? L"at once," : L"one at a time, each after",
             tag.DelayMs(), tag.Ejects() ? L", put out" : L"");
  }
  return true;
}

// g_effects stays: a loaded game reads the protos again but not the techtree, whose effects keep their indices.
void ForgetOnDataLoad(char*) {
  g_tags.clear();
  g_tech.clear();
  g_active.clear();
  g_resolvedFor = nullptr;
  g_world = nullptr;
  g_rescan = false;
}

// --- Tech subtypes ----------------------------------------------------------------------------------------------

enum class Unit { kProto, kProtoOrType, kProtoOptional };

// unittype and tag="N", into g_effects; the effect's field +10h is the index.
bool ParseEffect(void* db, char* effect, const char* node, const char* name, Unit rule) {
  EffectArgs args;
  std::string text;
  if (Attribute(node, "unittype", &text) && !text.empty()) {
    args.type = TypeId(db, text.c_str());
    args.typeName = text;
    if (args.type < 0) {
      uhc::Log(L"garrisonConvert: a %hs effect names the unknown unit %hs; effect dropped", name, text.c_str());
      return false;
    }
    const std::int32_t firstAbstract =
        *reinterpret_cast<const std::int32_t*>(static_cast<const char*>(db) + kFirstAbstract);
    if (rule != Unit::kProtoOrType && args.type >= firstAbstract) {
      uhc::Log(L"garrisonConvert: a %hs effect names %hs, an abstract type and not a proto; effect dropped", name,
               text.c_str());
      return false;
    }
  } else if (rule == Unit::kProto) {
    uhc::Log(L"garrisonConvert: a %hs effect names no unittype; effect dropped", name);
    return false;
  }
  if (Attribute(node, "tag", &text)) {
    char* end = nullptr;
    const long n = std::strtol(text.c_str(), &end, 10);
    if (text.empty() || *end != '\0' || n < 1 || n > static_cast<long>(kMaxTags)) {
      uhc::Log(L"garrisonConvert: a %hs effect has tag=\"%hs\", not a tag number from 1 to %u; effect dropped", name,
               text.c_str(), static_cast<unsigned>(kMaxTags));
      return false;
    }
    args.tag = static_cast<std::uint32_t>(n);
  }
  *reinterpret_cast<std::int32_t*>(effect + 0x10) = static_cast<std::int32_t>(g_effects.size());
  g_effects.push_back(args);
  return true;
}

bool ParseDelay(void* db, char* effect, const char* node) {
  return ParseEffect(db, effect, node, "GarrisonConvertDelay", Unit::kProtoOptional);
}
bool ParseEject(void* db, char* effect, const char* node) {
  return ParseEffect(db, effect, node, "GarrisonConvertEject", Unit::kProtoOptional);
}
bool ParseTarget(void* db, char* effect, const char* node) {
  return ParseEffect(db, effect, node, "GarrisonConvertTarget", Unit::kProto);
}
bool ParseFrom(void* db, char* effect, const char* node) {
  return ParseEffect(db, effect, node, "GarrisonConvertFrom", Unit::kProtoOrType);
}
bool ParseAdd(void* db, char* effect, const char* node) {
  return ParseEffect(db, effect, node, "GarrisonConvertAdd", Unit::kProto);
}
bool ParseRemove(void* db, char* effect, const char* node) {
  return ParseEffect(db, effect, node, "GarrisonConvertRemove", Unit::kProtoOptional);
}

// The player's copy of the tags, made from the data's the first time a tech changes them.
Tags* Slot(char* copy, const char* base) {
  ResolveAll();
  const auto data = g_tags.find(ProtoId(base));
  TechTags fresh{ProtoId(copy), data != g_tags.end() ? data->second : Tags()};
  auto inserted = g_tech.emplace(copy, fresh);
  if (inserted.first->second.id != ProtoId(copy)) {
    inserted.first->second = fresh;
  }
  return &inserted.first->second.tags;
}

const EffectArgs* ArgsOf(std::int32_t field) {
  return field >= 0 && static_cast<std::size_t>(field) < g_effects.size() ? &g_effects[field] : nullptr;
}

// The tags an effect picks: tag="N" if it has one, and with `byTarget`, the tags converting to its unittype.
bool Picks(const EffectArgs& args, const Tag& tag, std::size_t index, bool byTarget) {
  if (args.tag != 0 && index + 1 != args.tag) {
    return false;
  }
  return !byTarget || args.type < 0 || tag.targetId == args.type;
}

void Changed(const char* copy, const wchar_t* subtype, float amount, bool unapply, int changed) {
  g_rescan = true;
  if (LogOk()) {
    uhc::Log(L"garrisonConvert: proto %d (%hs), player's copy %p, tech subtype %ls, amount %g%ls: %d tag(s) changed",
             ProtoId(copy), ProtoName(copy), static_cast<const void*>(copy), subtype, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", changed);
  }
}

void NotUndone(const char* copy, const wchar_t* subtype) {
  if (LogOk()) {
    uhc::Log(L"garrisonConvert: proto %d (%hs): the removal of a %ls effect keeps the change", ProtoId(copy),
             ProtoName(copy), subtype);
  }
}

float ClampDelay(float seconds) { return seconds < 0.0f ? 0.0f : (seconds > kMaxDelay ? kMaxDelay : seconds); }

void ChangeDelay(char* copy, const char* base, std::int32_t field, float amount, std::uint8_t relativity,
                 bool unapply) {
  const EffectArgs* args = ArgsOf(field);
  if (args == nullptr) {
    return;
  }
  Tags& tags = *Slot(copy, base);
  int changed = 0;
  for (std::size_t i = 0; i < tags.size(); ++i) {
    if (Picks(*args, tags[i], i, true)) {
      kEffectValue(relativity, &tags[i].delay, tags[i].baseDelay, amount, unapply);
      tags[i].delay = ClampDelay(tags[i].delay);
      ++changed;
    }
  }
  Changed(copy, L"GarrisonConvertDelay", amount, unapply, changed);
}

void ChangeEject(char* copy, const char* base, std::int32_t field, float amount, std::uint8_t relativity,
                 bool unapply) {
  const EffectArgs* args = ArgsOf(field);
  if (args == nullptr) {
    return;
  }
  Tags& tags = *Slot(copy, base);
  int changed = 0;
  for (std::size_t i = 0; i < tags.size(); ++i) {
    if (Picks(*args, tags[i], i, true)) {
      kEffectValue(relativity, &tags[i].eject, tags[i].baseEject, amount, unapply);
      ++changed;
    }
  }
  Changed(copy, L"GarrisonConvertEject", amount, unapply, changed);
}

void ChangeTarget(char* copy, const char* base, std::int32_t field, float amount, std::uint8_t, bool unapply) {
  const EffectArgs* args = ArgsOf(field);
  if (args == nullptr) {
    return;
  }
  if (unapply) {
    NotUndone(copy, L"GarrisonConvertTarget");
    return;
  }
  Tags& tags = *Slot(copy, base);
  int changed = 0;
  for (std::size_t i = 0; i < tags.size(); ++i) {
    if (Picks(*args, tags[i], i, false)) {
      tags[i].target = args->typeName;
      tags[i].targetId = args->type;
      ++changed;
    }
  }
  Changed(copy, L"GarrisonConvertTarget", amount, unapply, changed);
}

void ChangeFrom(char* copy, const char* base, std::int32_t field, float amount, std::uint8_t, bool unapply) {
  const EffectArgs* args = ArgsOf(field);
  if (args == nullptr) {
    return;
  }
  if (unapply) {
    NotUndone(copy, L"GarrisonConvertFrom");
    return;
  }
  Tags& tags = *Slot(copy, base);
  int changed = 0;
  for (std::size_t i = 0; i < tags.size(); ++i) {
    if (Picks(*args, tags[i], i, false)) {
      tags[i].from = args->typeName;
      tags[i].fromId = args->type;
      tags[i].fromBad = false;
      ++changed;
    }
  }
  Changed(copy, L"GarrisonConvertFrom", amount, unapply, changed);
}

void ChangeAdd(char* copy, const char* base, std::int32_t field, float amount, std::uint8_t, bool unapply) {
  const EffectArgs* args = ArgsOf(field);
  if (args == nullptr) {
    return;
  }
  Tags& tags = *Slot(copy, base);
  if (unapply) {
    // The last tag with that target and no from goes, as the effect made it.
    for (std::size_t i = tags.size(); i-- > 0;) {
      if (tags[i].targetId == args->type && tags[i].from.empty()) {
        tags.erase(tags.begin() + static_cast<std::ptrdiff_t>(i));
        Changed(copy, L"GarrisonConvertAdd", amount, unapply, 1);
        return;
      }
    }
    Changed(copy, L"GarrisonConvertAdd", amount, unapply, 0);
    return;
  }
  if (tags.size() >= kMaxTags) {
    uhc::Log(L"garrisonConvert: proto %d (%hs): a GarrisonConvertAdd effect finds %u tags already; nothing added",
             ProtoId(copy), ProtoName(copy), static_cast<unsigned>(kMaxTags));
    return;
  }
  Tag tag;
  tag.target = args->typeName;
  tag.targetId = args->type;
  tag.delay = ClampDelay(amount);
  tag.baseDelay = tag.delay;
  tags.push_back(tag);
  Changed(copy, L"GarrisonConvertAdd", amount, unapply, 1);
}

void ChangeRemove(char* copy, const char* base, std::int32_t field, float amount, std::uint8_t, bool unapply) {
  const EffectArgs* args = ArgsOf(field);
  if (args == nullptr) {
    return;
  }
  if (unapply) {
    NotUndone(copy, L"GarrisonConvertRemove");
    return;
  }
  Tags& tags = *Slot(copy, base);
  int changed = 0;
  Tags kept;
  for (std::size_t i = 0; i < tags.size(); ++i) {
    if (Picks(*args, tags[i], i, true)) {
      ++changed;
    } else {
      kept.push_back(tags[i]);
    }
  }
  tags.swap(kept);
  Changed(copy, L"GarrisonConvertRemove", amount, unapply, changed);
}

// --- The buildings ----------------------------------------------------------------------------------------------

// Words 1 to 3 of 'GCNV': the time spent, the unit in progress, the game time of the write (so a loaded game adds
// the time of the update the save was made in, which the first tick after the load does not see).
void WriteProgress(char* building, const State& state, std::uint32_t now) {
  char* marker = uhc::markers::Find(building, kStat, kWord);
  if (marker == nullptr) {
    marker = uhc::markers::Take(building, kStat);
    if (marker == nullptr) {
      return;
    }
    uhc::markers::Word(marker, 0) = kWord;
  }
  uhc::markers::Word(marker, 1) = state.elapsed;
  uhc::markers::Word(marker, 2) = static_cast<std::uint32_t>(state.head);
  uhc::markers::Word(marker, 3) = now;
}

void ClearProgress(char* building) {
  if (char* marker = uhc::markers::Find(building, kStat, kWord)) {
    uhc::markers::Free(marker);
  }
}

// Words 1 and 2 of 'GCRR': the cursor and the pause. Written when they change; a building with both at 0 has none.
void WriteCursor(char* building, const State& state) {
  char* marker = uhc::markers::Find(building, kStat, kCursorWord);
  if (marker == nullptr) {
    if (state.cursor == 0 && !state.paused) {
      return;
    }
    marker = uhc::markers::Take(building, kStat);
    if (marker == nullptr) {
      return;
    }
    uhc::markers::Word(marker, 0) = kCursorWord;
  }
  uhc::markers::Word(marker, 1) = state.cursor;
  uhc::markers::Word(marker, 2) = state.paused ? 1u : 0u;
}

void ReadCursor(const char* building, State* state) {
  if (char* marker = uhc::markers::Find(building, kStat, kCursorWord)) {
    state->cursor = uhc::markers::Word(marker, 1);
    state->paused = uhc::markers::Word(marker, 2) != 0;
  }
  state->loaded = true;
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

// Room in the owner's population for the unit to become the target: the Maintain spawn's test, on the difference.
bool PopRoom(const char* player, const char* unitCopy, std::int32_t targetId) {
  const char* target = kPlayerProto(player, targetId);
  if (target == nullptr) {
    return true;
  }
  const std::int32_t delta = Field<std::int32_t>(target, kProtoPop) - Field<std::int32_t>(unitCopy, kProtoPop);
  if (delta <= 0 || kProtoHasFlag(target, kAlwaysAllowOverPopCap)) {
    return true;
  }
  const std::int32_t used = Field<std::int32_t>(player, 0x78) + kPlayerPop(player);
  const std::int32_t cap = kPlayerPopCap(player);
  if (kProtoHasFlag(target, kAllowOverPopCap)) {
    return cap - used > 0;
  }
  return cap >= used + delta;
}

// The train's own message and sound, on the owner's screen only (0x9EB0D6): interface, nothing reaches the game.
void ShowPopMessage(const char* player, std::int32_t targetId) {
  const char* game = Game();
  if (game == nullptr || player == nullptr || Field<std::int32_t>(game, 0x3C0) != Field<std::int32_t>(player, 0)) {
    return;
  }
  const char* target = kPlayerProto(player, targetId);
  const std::wstring format = StringById(kStringNoPopRoom);
  const std::wstring name = target == nullptr ? L"?" : StringById(Field<std::int32_t>(target, kProtoDisplayName));
  if (format.empty()) {
    return;
  }
  const auto message = (*reinterpret_cast<MessageFn const* const*>(game))[0x68 / 4];
  message(game, 2000, reinterpret_cast<const void*>(kMessageStyle), format.c_str(), name.c_str());
  kPlaySound(game, 4, 0);
}

bool Convert(char* unit, const char* building, const Tag& tag, std::size_t index, std::uint32_t now) {
  const std::int32_t id = UnitId(unit);
  const char* before = Field<const char*>(unit, 0x5C);
  const std::int32_t fromId = ProtoId(before);
  const char* fromName = ProtoName(before);
  uhc::TransformUnit(unit, tag.targetId);
  const char* after = Field<const char*>(unit, 0x5C);
  const bool done = ProtoId(after) == tag.targetId;
  if (!done) {
    if (++g_failures <= 20) {
      uhc::Log(L"garrisonConvert: unit %d (%hs) in %hs %d did not become %hs (proto %d); it waits", id, fromName,
               BuildingName(building), UnitId(building), tag.target.c_str(), tag.targetId);
    }
  } else if (LogOk()) {
    uhc::Log(L"garrisonConvert: unit %d (%hs) in %hs %d became %hs (tag %u, proto %d -> %d, game time %u ms)", id,
             fromName, BuildingName(building), UnitId(building), ProtoName(after), static_cast<unsigned>(index + 1),
             fromId, tag.targetId, now);
  }
  return done;
}

// The building's eject of one unit: the unload 0x9C68C3 as the command handler FUN_009CBEA1 calls it (the place found
// around the building, no point to walk to), forced as the death eject FUN_009C6C79 does.
void Eject(char* building, const char* unit, std::uint32_t now) {
  const std::int32_t id = UnitId(unit);
  const bool out = kUnload(building, id, reinterpret_cast<const void*>(kNoPosition), false, false, true, -1,
                           reinterpret_cast<const void*>(kZeroVector), 0, 0);
  if (!out) {
    uhc::Log(L"garrisonConvert: unit %d could not be put out of %hs %d (no room around it?); it stays inside", id,
             BuildingName(building), UnitId(building));
  } else if (LogOk()) {
    uhc::Log(L"garrisonConvert: unit %d put out of %hs %d (game time %u ms)", id, BuildingName(building),
             UnitId(building), now);
  }
}

void Consider(char* unit, std::uint32_t now) {
  if (unit == nullptr || Field<std::int32_t>(unit, 0x74) <= 0 || TagsOf(unit) == nullptr || !IsAlive(unit)) {
    return;
  }
  const std::int32_t id = UnitId(unit);
  if (g_active.count(id) != 0) {
    return;
  }
  State state;
  if (char* marker = uhc::markers::Find(unit, kStat, kWord)) {
    const std::uint32_t written = uhc::markers::Word(marker, 3);
    state.elapsed = uhc::markers::Word(marker, 1) + (now > written && now - written < 60000 ? now - written : 0);
    state.head = static_cast<std::int32_t>(uhc::markers::Word(marker, 2));
  }
  ReadCursor(unit, &state);
  g_active.emplace(id, state);
}

// The buildings with units inside, after a game started or loaded (`clear`) or after a tech changed some tags. One walk.
void Walk(const char* world, bool clear) {
  if (clear) {
    g_active.clear();
  }
  const std::size_t before = g_active.size();
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
    Consider(table[i], now);
  }
  if (g_active.size() != before) {
    uhc::Log(L"garrisonConvert: %u building(s) with units inside %ls (game time %u ms)",
             static_cast<unsigned>(g_active.size() - before), clear ? L"in this game" : L"after a tech", now);
  }
}

// The game time since the last tick; a new game rebuilds the list and gives 0.
std::uint32_t Sync(const char* world) {
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const bool sameGame = world == g_world && now >= g_lastTime && step - g_lastStep <= 1;
  const std::uint32_t elapsed = sameGame ? now - g_lastTime : 0;
  if (!sameGame) {
    g_world = world;
    g_rescan = false;
    Walk(world, true);
  }
  g_lastTime = now;
  g_lastStep = step;
  return elapsed;
}

// From the shared garrison observer, inside the load: only marks the building.
void OnEnter(char* container, char*) {
  if ((g_tags.empty() && g_tech.empty()) || TagsOf(container) == nullptr) {
    return;
  }
  g_active.emplace(UnitId(container), State{});
}

// One building's conversions for this tick; false when it has nothing left to do.
bool Step(const char* world, char* building, State& state, std::uint32_t elapsed, std::uint32_t now) {
  const Tags* tags = TagsOf(building);
  if (tags == nullptr || !IsAlive(building)) {
    return false;
  }
  if (!state.loaded) {
    ReadCursor(building, &state);
  }
  const char* owner = PlayerOf(building);
  bool added = false;
  const std::int32_t rounds = Field<std::int32_t>(building, 0x74) + 1;
  for (std::int32_t round = 0; round < rounds; ++round) {
    char* head = Head(world, building, *tags, nullptr);
    if (head == nullptr) {
      ClearProgress(building);
      if (state.paused) {
        state.paused = false;
        WriteCursor(building, state);
      }
      return false;
    }
    const std::int32_t headId = UnitId(head);
    if (state.head != headId) {
      if (state.head >= 0) {
        state.elapsed = 0;  // the unit in progress left: the next one starts again
      }
      state.head = headId;
    }
    if (!added) {
      state.elapsed += elapsed;
      added = true;
    }
    const char* copy = Field<const char*>(head, 0x5C);
    const int index = ChooseTag(*tags, copy, state.cursor);
    if (index < 0) {
      return false;  // not reached: Qualifies found a tag that takes it
    }
    const Tag tag = (*tags)[static_cast<std::size_t>(index)];  // a copy: the transform may run tech code
    const std::uint32_t delay = tag.DelayMs();
    if (state.elapsed < delay) {
      break;
    }
    if (owner != nullptr && !PopRoom(owner, copy, tag.targetId)) {
      state.elapsed = delay;  // held full until there is room
      if (!state.paused) {
        state.paused = true;
        WriteCursor(building, state);
        if (LogOk()) {
          uhc::Log(L"garrisonConvert: %hs %d waits: no population room for unit %d to become %hs (population %d + "
                   L"%d of %d, game time %u ms)",
                   BuildingName(building), UnitId(building), headId, tag.target.c_str(),
                   Field<std::int32_t>(owner, 0x78) + kPlayerPop(owner),
                   kPlayerProto(owner, tag.targetId) == nullptr
                       ? 0
                       : Field<std::int32_t>(kPlayerProto(owner, tag.targetId), kProtoPop) -
                             Field<std::int32_t>(copy, kProtoPop),
                   kPlayerPopCap(owner), now);
        }
        ShowPopMessage(owner, tag.targetId);
      }
      break;
    }
    if (state.paused) {
      state.paused = false;
      if (LogOk()) {
        uhc::Log(L"garrisonConvert: %hs %d goes on: population room (game time %u ms)", BuildingName(building),
                 UnitId(building), now);
      }
    }
    if (!Convert(head, building, tag, static_cast<std::size_t>(index), now)) {
      WriteCursor(building, state);
      break;
    }
    state.elapsed -= delay;
    state.head = -1;
    state.cursor = static_cast<std::uint32_t>((static_cast<std::size_t>(index) + 1) % tags->size());
    WriteCursor(building, state);
    if (tag.Ejects()) {
      Eject(building, head, now);
    }
    tags = TagsOf(building);
    if (tags == nullptr) {
      return false;
    }
  }
  WriteProgress(building, state, now);
  return true;
}

void Tick(char* world, std::int32_t) {
  if (world != MainWorld() || (g_tags.empty() && g_tech.empty())) {
    return;
  }
  const std::uint32_t elapsed = Sync(world);
  if (g_rescan) {
    g_rescan = false;
    Walk(world, false);
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  for (auto it = g_active.begin(); it != g_active.end();) {
    char* building = UnitById(world, it->first);
    if (building == nullptr || !Step(world, building, it->second, elapsed, now)) {
      it = g_active.erase(it);
    } else {
      ++it;
    }
  }
}

}  // namespace

namespace uhc {

bool GarrisonConvertProgress(const char* building, float* fraction, std::int32_t* waiting) {
  if (building == nullptr || (g_tags.empty() && g_tech.empty()) || MainWorld() != g_world) {
    return false;
  }
  const Tags* tags = TagsOf(building);
  if (tags == nullptr) {
    return false;
  }
  std::int32_t count = 0;
  const char* head = Head(g_world, building, *tags, &count);
  if (head == nullptr) {
    return false;
  }
  const auto found = g_active.find(UnitId(building));
  const State* state = found != g_active.end() ? &found->second : nullptr;
  const int index = ChooseTag(*tags, Field<const char*>(head, 0x5C), state != nullptr ? state->cursor : 0);
  if (index < 0) {
    return false;
  }
  const std::uint32_t delay = (*tags)[static_cast<std::size_t>(index)].DelayMs();
  const std::uint32_t spent = state != nullptr && state->head == UnitId(head) ? state->elapsed : 0;
  if (fraction != nullptr) {
    *fraction = delay == 0 || (state != nullptr && state->paused)
                    ? 1.0f
                    : static_cast<float>(spent < delay ? spent : delay) / static_cast<float>(delay);
  }
  if (waiting != nullptr) {
    *waiting = count;
  }
  return true;
}

namespace {

// The progress pie over the portrait (progresspie.h): a selected building whose unit in progress has a delay.
bool __stdcall PieSource(const char* unit, float* fraction, std::uint32_t*) {
  if ((g_tags.empty() && g_tech.empty()) || MainWorld() != g_world) {
    return false;
  }
  const Tags* tags = TagsOf(unit);
  if (tags == nullptr) {
    return false;
  }
  const char* head = Head(g_world, unit, *tags, nullptr);
  if (head == nullptr) {
    return false;
  }
  const auto found = g_active.find(UnitId(unit));
  const int index =
      ChooseTag(*tags, Field<const char*>(head, 0x5C), found != g_active.end() ? found->second.cursor : 0);
  return index >= 0 && (*tags)[static_cast<std::size_t>(index)].DelayMs() != 0 &&
         GarrisonConvertProgress(unit, fraction, nullptr);
}

}  // namespace

Outcome ApplyGarrisonConvert(const Config& config) {
  const Config::Args* args = config.First("garrisonConvert");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"garrisonConvert: unknown option %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("garrisonConvert",
                 {&sites::kUnitAliveSlot, &sites::kProtoByName, &sites::kXmlAttribute, &sites::kIsA,
                  &sites::kEffectValueApply, &sites::kPlayerProtoEntry, &sites::kProtoFlag, &sites::kPlayerPopHead,
                  &sites::kPlayerPopCapHead, &sites::kGarrisonUnloadHead, &sites::kPopCapToast,
                  &sites::kPopCapToastSound, &sites::kBStringFromId, &sites::kBStringFree}) ||
      !AddProtoTagHandler("GarrisonConvertTo", &ReadConvertTo) || !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !AddTechProtoSubtype("GarrisonConvertDelay", &ParseDelay, &ChangeDelay) ||
      !AddTechProtoSubtype("GarrisonConvertEject", &ParseEject, &ChangeEject) ||
      !AddTechProtoSubtype("GarrisonConvertTarget", &ParseTarget, &ChangeTarget) ||
      !AddTechProtoSubtype("GarrisonConvertFrom", &ParseFrom, &ChangeFrom) ||
      !AddTechProtoSubtype("GarrisonConvertAdd", &ParseAdd, &ChangeAdd) ||
      !AddTechProtoSubtype("GarrisonConvertRemove", &ParseRemove, &ChangeRemove) || !AddWorldTick(&Tick) ||
      !AddGarrisonObserver(&OnEnter, "garrisonConvert")) {
    return Outcome::kFailed;
  }
  const bool pie = AddProgressPieSource(&PieSource);
  Log(L"garrisonConvert: <GarrisonConvertTo> converts the units that enter a building (several tags in turn, eject, "
      L"from, the population cap, six tech subtypes)%ls%ls",
      pie ? L"; the progress pie over the portrait" : L"; no progress pie", g_log ? L"; logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/garrisonobservers.h

```cpp
// Every unit that enters another (a building's garrison, a ship, a wagon), shared by the keys that act on it
// (garrisonConvert, nurseryFactor). The load of a unit into another, FUN_009C24B5 bool thiscall(container, unitId,
// flag), ret 8, has eleven direct callers (the garrison and load actions, triggers, the random map placement, the
// scenario load); one jmp at its success tail 0x9C26E1, whichever keys are on, runs every observer there.
#pragma once

namespace uhc {

// Called once per successful entry, inside the load: [unit+6Ch] is already the container's ID and the unit is the
// last ID of [container+70h] (count [container+74h]). The load has not returned yet, and its caller may still read
// the unit: an observer must not transform, kill, eject or move it there. It queues the unit's ID and acts after
// the world update (worldtick.h), checking again that the unit is still inside.
using GarrisonObserver = void (*)(char* container, char* unit);

// Writes the jmp the first time (after checking the site's stock bytes and the function's head) and adds the
// observer, in the order the keys add them (their kFeatures order, the same on every machine). `key` names the
// caller in the log.
bool AddGarrisonObserver(GarrisonObserver observer, const char* key);

}  // namespace uhc
```

### src/garrisonobservers.cpp

```cpp
#include "garrisonobservers.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcGarrisonEnterHook();

namespace {

constexpr std::size_t kMaxObservers = 8;

uhc::GarrisonObserver g_observers[kMaxObservers] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

// From the hook at 0x9C26E1: EDI = the container, ESI = the unit that just entered it.
extern "C" void __stdcall UhcGarrisonDispatch(char* container, char* unit) {
  if (container == nullptr || unit == nullptr) {
    return;
  }
  for (std::size_t i = 0; i < g_count; ++i) {
    g_observers[i](container, unit);
  }
}

namespace uhc {

bool AddGarrisonObserver(GarrisonObserver observer, const char* key) {
  if (g_count == kMaxObservers) {
    Log(L"garrison entries: more than %u observers (%hs)", static_cast<unsigned>(kMaxObservers), key);
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("garrison entries", {&sites::kGarrisonEnterTail, &sites::kGarrisonLoadHead}) ||
        !WriteJmp(sites::kGarrisonEnterTail.va, reinterpret_cast<const void*>(&UhcGarrisonEnterHook), 7)) {
      return false;
    }
    g_installed = true;
  }
  g_observers[g_count++] = observer;
  return true;
}

}  // namespace uhc
```

### src/hooks/garrisonobs_hooks.asm

```asm
; The entries of a unit into another, shared by the keys that observe them (src/garrisonobservers.cpp). Entered
; through a jmp written over the stock code; it leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcGarrisonDispatch PROTO STDCALL container:DWORD, unit:DWORD

.data
enterNext       dd 009C26E8h    ; mov eax,[0C66234h]: the store of the game time in the action manager
enterDone       dd 009C26FFh    ; pop ebx: the load returns true

.code

; Replaces mov edi,[edi+58h] / test edi,edi / je 9C26FFh (7 bytes) at 0x9C26E1, the success tail of the load
; FUN_009C24B5: EDI = the container, ESI = the unit, after [unit+6Ch] = the container's ID (0x9C25C2) and the
; append of the unit's ID to [container+70h] (0x9C26DC). The stock code after it reads EDI (the action manager,
; replayed here) and writes EAX, ECX and EDX before reading them; invoke keeps EBX, ESI and EDI.
UhcGarrisonEnterHook PROC
    TRACE_ONCE "garrison entries (0x9C26E1)"
    invoke UhcGarrisonDispatch, edi, esi
    mov edi, dword ptr [edi+58h]
    test edi, edi
    je skip
    jmp enterNext
skip:
    jmp enterDone
UhcGarrisonEnterHook ENDP

END
```
