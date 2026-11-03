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
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

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

namespace uhc {

namespace {
bool g_gatesInstalled = false;
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
