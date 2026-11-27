// noTrainNearEnemyTC <meters> [UnitType] [near <UnitType>|FirstTC ...] [nowarn | warn=<text>] [refuse] [log]:
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
//
// With "refuse", a marked trainer in that place also takes no new unit: the head of the enqueue FUN_009EAC35
// answers false before the cost is paid at 0x9EAF86, for the train command's three calls and 0x8D60EA.
// What was queued before the trainer walked in keeps waiting, as without it.
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
bool g_refuse = false;

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
void UhcNoTrainEnqueueHook();

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

// From the head of the enqueue, for each unit asked of any trainer.
bool __stdcall UhcNoTrainRefused(const char* trainer) {
  if (!UhcNoTrainBlocked(trainer)) {
    return false;
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"noTrainNearEnemyTC: unit %d (%hs, player %d) refused a unit", Field<std::int32_t>(trainer, 0x10),
             ProtoName(trainer), PlayerIdOf(trainer));
  }
  return true;
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
        L"warn=<text>] [refuse] [log]\" with meters above 0 and at most %.0f, got \"%hs\"; feature not applied",
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
    } else if (_stricmp(arg, "refuse") == 0) {
      g_refuse = true;
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
          L"warn=<text>] [refuse] [log]); feature not applied",
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
  if (g_refuse && !VerifyAll("noTrainNearEnemyTC refuse", {&sites::kTrainEnqueueHead})) {
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
  if (!WriteJmp(sites::kWorkRateTrainCall.va, reinterpret_cast<const void*>(&UhcNoTrainHook), 8) ||
      (g_refuse && !WriteJmp(sites::kTrainEnqueueHead.va, reinterpret_cast<const void*>(&UhcNoTrainEnqueueHook), 6))) {
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
