// liveBuildingWorkRate: train, research and Maintain speed follow the proto's current
// BuildingWorkRate.
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
// change of either value. Only the game thread (the simulation update) touches it.
std::unordered_map<std::int32_t, std::uint64_t> g_logged;

}  // namespace

extern "C" {
std::int32_t g_uhcBwrLog = 0;  // 1 with "liveBuildingWorkRate log"

void UhcBwrGetterHook();

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
  if (!VerifyAll("liveBuildingWorkRate", {&sites::kBuildingWorkRateGetter, &sites::kWorkRateTrainCall,
                                          &sites::kWorkRateResearchCall, &sites::kWorkRateCommandResearchCall,
                                          &sites::kWorkRateMaintainCall})) {
    return Outcome::kFailed;
  }
  g_uhcBwrLog = log ? 1 : 0;
  if (!WriteJmp(sites::kBuildingWorkRateGetter.va, reinterpret_cast<const void*>(&UhcBwrGetterHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"liveBuildingWorkRate: train, research and Maintain speed follow the proto's current "
      L"BuildingWorkRate%ls (multiplayer unverified)",
      log ? L", every building it changes logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
