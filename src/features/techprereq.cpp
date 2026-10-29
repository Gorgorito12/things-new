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
