// noTrainNearEnemyTC <meters> [UnitType] [log]: a unit of the marker type (default AbstractDaimyo,
// the Daimyos and the Shogun) does not train while it stands near an enemy's first Town Center.
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
#include <charconv>
#include <cstdint>
#include <cstring>
#include <string>
#include <unordered_map>

#include "../features.h"
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

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using PlayerByIdFn = const char*(__thiscall*)(char* world, std::int32_t id);
using UnitByIdFn = const char*(__thiscall*)(char* world, std::int32_t id);
using IsEnemyFn = bool(__thiscall*)(const char* player, std::int32_t otherId);
using UnitIsAliveFn = bool(__thiscall*)(const char* unit);
using UnitDistanceFn = float(__thiscall*)(const char* unit, const float* point);

const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kIsEnemy = reinterpret_cast<IsEnemyFn>(0x00484D2D);

constexpr float kMaxMeters = 1000.0f;
constexpr unsigned kMaxLogLines = 1000;

float g_meters = 65.0f;
bool g_log = false;  // "noTrainNearEnemyTC ... log": every pause and resume

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
  const char* tc = nullptr;  // null: no enemy FirstTC is alive
  std::int32_t player = -1;  // the player whose FirstTC it is
  float distance = 0.0f;
};

// The nearest alive FirstTC whose owner is the enemy of the trainer's player. Reads only
// simulation state, in player order, so every machine gets the same answer.
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

void ClearLogged(char*) { g_paused.clear(); }

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
    uhc::Log(L"noTrainNearEnemyTC: unit %d (%hs, player %d) %ls: no enemy FirstTC", id, ProtoName(trainer),
             PlayerIdOf(trainer), what);
  } else {
    uhc::Log(L"noTrainNearEnemyTC: unit %d (%hs, player %d) %ls: player %d's FirstTC %d (%hs) is %.1f m away "
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

// Called by the hook on every tick of an active Train action, with its trainer. True: the
// trainer is of the marker type and an enemy's FirstTC is alive within the configured distance,
// so this tick adds no progress.
bool __stdcall UhcNoTrainBlocked(const char* trainer) {
  const char* proto = trainer == nullptr ? nullptr : Field<const char*>(trainer, 0x5C);
  if (proto == nullptr || g_uhcNoTrainType < 0 || !kProtoIsType(proto, g_uhcNoTrainType)) {
    return false;
  }
  const Nearest nearest = NearestEnemyFirstTc(trainer);
  const bool blocked = nearest.tc != nullptr && nearest.distance < g_meters;
  if (g_log) {
    LogState(trainer, blocked, nearest);
  }
  return blocked;
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
    Log(L"noTrainNearEnemyTC: expected \"noTrainNearEnemyTC <meters> [UnitType] [log]\" with meters above 0 and "
        L"at most %.0f, got \"%hs\"; feature not applied",
        static_cast<double>(kMaxMeters), args.empty() ? "" : args.front().c_str());
    return Outcome::kFailed;
  }
  std::string typeName = "AbstractDaimyo";
  bool typeGiven = false;
  bool log = false;
  for (std::size_t i = 1; i < args.size(); ++i) {
    if (_stricmp(args[i].c_str(), "log") == 0) {
      log = true;
    } else if (!typeGiven) {
      typeName = args[i];
      typeGiven = true;
    } else {
      Log(L"noTrainNearEnemyTC: unexpected argument %hs (expected: <meters> [UnitType] [log]); feature not applied",
          args[i].c_str());
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
  if (!RequestAbstractUnitType(typeName.c_str(), &g_uhcNoTrainType)) {
    return Outcome::kFailed;
  }
  g_meters = meters;
  g_log = log;
  if (log && !OnDatabaseLoad(&ClearLogged)) {
    return Outcome::kFailed;
  }
  // Replaces mov ecx,[esi+10h] / call 9BFE33h at 0x9EA410; the hook re-executes them.
  if (!WriteJmp(sites::kWorkRateTrainCall.va, reinterpret_cast<const void*>(&UhcNoTrainHook), 8)) {
    return Outcome::kFailed;
  }
  Log(L"noTrainNearEnemyTC: units of unittype %hs do not train within %.1f m of an enemy's first Town Center "
      L"(FirstTC)%ls (multiplayer unverified)",
      typeName.c_str(), static_cast<double>(meters), log ? L", every pause and resume logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
