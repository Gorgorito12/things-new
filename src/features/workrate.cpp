// liveBuildingWorkRate: train, research and Maintain speed follow the proto's current
// BuildingWorkRate, and the units being trained or spawned follow their current TrainPoints.
//
// Stock keeps a copy of a building's BuildingWorkRate ([proto+D0h]) in its building data
// ([[unit+68h]+28h]), taken once: when the building completes, or when a ForceBuildingData unit is
// created (FUN_006A1F82, and again for completed buildings when a save loads). The getter at
// 0x9BFE33, which the Train, Research, CommandResearch and Maintain updates call on every tick,
// returns that copy. A BuildingWorkRate tech (Data effect, subtype 0x5E) only changes the proto,
// so it reaches the buildings completed after it and never the ones already standing, although
// the stat panel shows the new rate (it reads the proto). The hook in hooks/workrate_hooks.asm
// makes the getter return the proto's value, as stock already does for a unit without building
// data. The copy is still written and saved, so saved games load with or without the key.
//
// TrainPoints (second part). Every queued unit (or batch) is its own Train action, and the
// enqueue (0x9EB19F) stores the trained proto's TrainPoints in the action ([action+64h]) once, when
// the unit is queued; a Maintain cycle stores count x TrainPoints ([action+6Ch]) when it starts
// (0x9E2A05). A TrainPoints tech therefore misses every unit already queued or in training, on old
// and new buildings alike, and the current Maintain cycle. ResearchPoints are read live by stock
// (0x9E5F27). The two fraction functions (Train 0x9EA1FA, Maintain 0x9E27E4) run on every tick of
// their update; their hooks first write the points the stock rule gives now, so the progress (kept
// in points) is measured against the current value, as research progress already is.
#include <bit>
#include <cstdint>
#include <cstring>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// Unit ID -> the (snapshot, proto) rate bits last logged for it, so a unit is logged once per
// change of either value. Only the game thread (the simulation update) touches it. Unit IDs start
// again in every game: a new world, or a step count [world+F8h] that went back, clears it.
std::unordered_map<std::int32_t, std::uint64_t> g_logged;
// (unit ID, trained proto ID) -> the (cached, current) points last logged for that pair.
std::unordered_map<std::uint64_t, std::uint64_t> g_loggedPoints;
const char* g_logWorld = nullptr;
std::uint32_t g_logStep = 0;

using PlayerProtoFn = const char*(__thiscall*)(const char* player, std::int32_t protoId);
using UnitFlagFn = bool(__thiscall*)(const char* unit, std::int32_t flag);
using ProtoByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
// The calls the stock rule makes; the sites TrainPointsProto, TrainPointsSet, MaintainPointsProto
// and MaintainPointsSet hold them and are verified before any write.
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kUnitFlag = reinterpret_cast<UnitFlagFn>(0x0044D063);
const auto kProtoById = reinterpret_cast<ProtoByIdFn>(0x0045316E);
constexpr std::int32_t kForceBaseTrainPoints = 0x9E;  // unit flag YPForceTrainAtBaseTrainPoints

void ForgetOtherGames() {
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const std::uint32_t step = world == nullptr ? 0 : Field<std::uint32_t>(world, 0xF8);
  if (world != g_logWorld || step < g_logStep) {
    g_logged.clear();
    g_loggedPoints.clear();
  }
  g_logWorld = world;
  g_logStep = step;
}

// The points the stock rule gives now for a unit of protoId trained (count 0) or spawned in a
// Maintain cycle of `count` units by `trainer`: the trainer's player's copy of the proto, times the
// count for Maintain; with the trainer's flag YPForceTrainAtBaseTrainPoints, the database's base
// proto, not multiplied (as stock). False when a lookup fails: the caller keeps the stock value.
bool CurrentPoints(const char* trainer, std::int32_t protoId, std::int32_t count, std::uint32_t* bits,
                   const char** name) {
  const char* player = trainer == nullptr ? nullptr : Field<const char*>(trainer, 0x44);
  const char* proto = player == nullptr ? nullptr : kPlayerProto(player, protoId);
  if (proto == nullptr) {
    return false;
  }
  *name = Field<const char*>(proto, 0x10);
  const float points = Field<float>(proto, 0x6C);
  // fild count / fmul points / fstp: the exact product (count is small) rounded once to a float.
  *bits = std::bit_cast<std::uint32_t>(
      count > 0 ? static_cast<float>(static_cast<double>(count) * static_cast<double>(points)) : points);
  if (kUnitFlag(trainer, kForceBaseTrainPoints)) {
    const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
    const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
    const char* base = database == nullptr ? nullptr : kProtoById(database, Field<std::int32_t>(proto, 8));
    if (base != nullptr) {
      *bits = Field<std::uint32_t>(base, 0x6C);
    }
  }
  return true;
}

void LogPoints(const char* trainer, std::int32_t protoId, const char* name, std::uint32_t cached,
               std::uint32_t current, bool maintain) {
  ForgetOtherGames();
  const std::int32_t id = Field<std::int32_t>(trainer, 0x10);
  const std::uint64_t key =
      (static_cast<std::uint64_t>(static_cast<std::uint32_t>(id)) << 32) | static_cast<std::uint32_t>(protoId);
  const std::uint64_t pair = (static_cast<std::uint64_t>(cached) << 32) | current;
  const auto [it, added] = g_loggedPoints.try_emplace(key, pair);
  if (!added) {
    if (it->second == pair) {
      return;
    }
    it->second = pair;
  }
  const char* trainerProto = Field<const char*>(trainer, 0x5C);
  const char* trainerName = trainerProto == nullptr ? nullptr : Field<const char*>(trainerProto, 0x10);
  const char* player = Field<const char*>(trainer, 0x44);
  uhc::Log(maintain ? L"liveBuildingWorkRate: unit %d (%hs, player %d) spawns %hs at %.3f points per cycle, "
                      L"not the %.3f its cycle started with"
                    : L"liveBuildingWorkRate: unit %d (%hs, player %d) trains %hs at TrainPoints %.3f, not "
                      L"the %.3f it was queued with",
           id, trainerName == nullptr ? "?" : trainerName, player == nullptr ? -1 : Field<std::int32_t>(player, 0),
           name == nullptr ? "?" : name, static_cast<double>(std::bit_cast<float>(current)),
           static_cast<double>(std::bit_cast<float>(cached)));
}

}  // namespace

extern "C" {
std::int32_t g_uhcBwrLog = 0;  // 1 with "liveBuildingWorkRate log"

void UhcBwrGetterHook();
void UhcTrainFracHook();
void UhcMaintainFracHook();

// Called by the Train fraction hook with the Train action: the first entry's proto ([[a+70h]],
// entry count [a+74h]), the trainer [a+10h], and the points [a+64h] the enqueue stored.
void __stdcall UhcTrainPointsRefresh(char* action) {
  const std::int32_t* entries = Field<const std::int32_t*>(action, 0x70);
  if (Field<std::int32_t>(action, 0x74) <= 0 || entries == nullptr) {
    return;
  }
  const char* trainer = Field<const char*>(action, 0x10);
  std::uint32_t current = 0;
  const char* name = nullptr;
  if (!CurrentPoints(trainer, entries[0], 0, &current, &name)) {
    return;
  }
  const std::uint32_t cached = Field<std::uint32_t>(action, 0x64);
  if (cached == current) {
    return;
  }
  *reinterpret_cast<std::uint32_t*>(action + 0x64) = current;
  if (g_uhcBwrLog != 0) {
    LogPoints(trainer, entries[0], name, cached, current, false);
  }
}

// Called by the Maintain fraction hook with the Maintain action: proto ID [a+64h], unit count
// [a+68h], trainer [a+10h], and the cycle's points [a+6Ch] its start stored.
void __stdcall UhcMaintainPointsRefresh(char* action) {
  const char* trainer = Field<const char*>(action, 0x10);
  const std::int32_t protoId = Field<std::int32_t>(action, 0x64);
  const std::int32_t count = Field<std::int32_t>(action, 0x68);
  std::uint32_t current = 0;
  const char* name = nullptr;
  // With a count of 0 stock stores 0 points (the cycle is done at once); leave that alone.
  if (count <= 0 || !CurrentPoints(trainer, protoId, count, &current, &name)) {
    return;
  }
  const std::uint32_t cached = Field<std::uint32_t>(action, 0x6C);
  if (cached == current) {
    return;
  }
  *reinterpret_cast<std::uint32_t*>(action + 0x6C) = current;
  if (g_uhcBwrLog != 0) {
    LogPoints(trainer, protoId, name, cached, current, true);
  }
}

// Called by the getter hook (only with log) with ECX's unit: logs a unit whose snapshot differs
// from its proto's current rate, i.e. one whose speed this feature changes.
void __stdcall UhcBwrLogUnit(const char* unit) {
  const char* data = Field<const char*>(unit, 0x68);
  const char* proto = Field<const char*>(unit, 0x5C);
  if (data == nullptr || proto == nullptr) {
    return;
  }
  const std::uint32_t snapshot = Field<std::uint32_t>(data, 0x28);
  const std::uint32_t live = Field<std::uint32_t>(proto, 0xD0);
  if (snapshot == live) {
    return;
  }
  ForgetOtherGames();
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const std::uint64_t pair = (static_cast<std::uint64_t>(snapshot) << 32) | live;
  const auto [it, added] = g_logged.try_emplace(id, pair);
  if (!added) {
    if (it->second == pair) {
      return;
    }
    it->second = pair;
  }
  const char* name = Field<const char*>(proto, 0x10);
  const char* player = Field<const char*>(unit, 0x44);
  uhc::Log(L"liveBuildingWorkRate: unit %d (%hs, player %d) works at BuildingWorkRate %.3f, not its "
           L"snapshot %.3f",
           id, name == nullptr ? "?" : name, player == nullptr ? -1 : Field<std::int32_t>(player, 0),
           static_cast<double>(std::bit_cast<float>(live)), static_cast<double>(std::bit_cast<float>(snapshot)));
}
}

namespace uhc {

Outcome ApplyLiveBuildingWorkRate(const Config& config) {
  const Config::Args* args = config.First("liveBuildingWorkRate");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"liveBuildingWorkRate: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("liveBuildingWorkRate",
                 {&sites::kBuildingWorkRateGetter, &sites::kWorkRateTrainCall, &sites::kWorkRateResearchCall,
                  &sites::kWorkRateCommandResearchCall, &sites::kWorkRateMaintainCall, &sites::kTrainFrac,
                  &sites::kTrainPointsProto, &sites::kTrainPointsSet, &sites::kMaintainFrac,
                  &sites::kMaintainPointsProto, &sites::kMaintainPointsSet})) {
    return Outcome::kFailed;
  }
  g_uhcBwrLog = log ? 1 : 0;
  if (!WriteJmp(sites::kBuildingWorkRateGetter.va, reinterpret_cast<const void*>(&UhcBwrGetterHook), 5) ||
      !WriteJmp(sites::kTrainFrac.va, reinterpret_cast<const void*>(&UhcTrainFracHook), 9) ||
      !WriteJmp(sites::kMaintainFrac.va, reinterpret_cast<const void*>(&UhcMaintainFracHook), 9)) {
    return Outcome::kFailed;
  }
  Log(L"liveBuildingWorkRate: train, research and Maintain speed follow the proto's current "
      L"BuildingWorkRate, and queued, training and Maintain units their current TrainPoints%ls "
      L"(multiplayer unverified)",
      log ? L", every building and unit it changes logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
