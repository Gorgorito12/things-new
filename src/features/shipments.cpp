// hcShipmentPointFallback: when the home city gather unit is gone and none of the stock
// fallback types (TC, FortFrontier, WarHut, Blockhouse, NoblesHut and three more) is left, try
// the proto units listed in uhc.cfg, in order. The hook is in hooks/shipment_hooks.asm.
#include <windows.h>

#include <cstdint>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr int kMaxFallbackTypes = 64;

// Proto names from uhc.cfg; resolved to IDs only once the game database exists.
std::vector<std::string> g_typeNames;

}  // namespace

extern "C" {
std::int32_t g_uhcGatherFallbackTypes[kMaxFallbackTypes];
std::int32_t g_uhcGatherFallbackCount = 0;

void UhcHcGatherFallbackHook();

// Called once from the hook, inside the simulation, when the database is loaded.
void __stdcall UhcResolveGatherFallbackTypes() {
  using ProtoIdByName = int(__thiscall*)(void* database, const char* name);
  const auto protoIdByName = reinterpret_cast<ProtoIdByName>(0x005A2346);
  void* game = *reinterpret_cast<void**>(0x00C66234);
  void* database = game == nullptr ? nullptr : *reinterpret_cast<void**>(static_cast<char*>(game) + 0x140);
  for (int i = 0; i < g_uhcGatherFallbackCount; ++i) {
    const int id = database == nullptr ? -1 : protoIdByName(database, g_typeNames[i].c_str());
    g_uhcGatherFallbackTypes[i] = id;
    uhc::Log(L"hcShipmentPointFallback: %hs -> proto %d%ls", g_typeNames[i].c_str(), id,
             id < 0 ? L" (unknown proto; skipped)" : L"");
  }
}
}

namespace uhc {

// FUN_004C6CAE returns the unit shipments arrive at. When the stored one is gone it searches a
// fixed list of unit types; this extends that list. Choice order is the cfg order, then the
// stock unit-query order, so every machine with the same cfg picks the same building.
Outcome ApplyHcShipmentPointFallback(const Config& config) {
  const Config::Args* names = config.First("hcShipmentPointFallback");
  if (names == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (names->empty() || names->size() > kMaxFallbackTypes) {
    Log(L"hcShipmentPointFallback: expected 1 to %d proto unit names", kMaxFallbackTypes);
    return Outcome::kFailed;
  }
  if (!VerifyAll("hcShipmentPointFallback",
                 {&sites::kGatherFallbackExit, &sites::kGatherFallbackStore, &sites::kGatherFallbackBlock})) {
    return Outcome::kFailed;
  }
  g_typeNames = *names;
  for (int& id : g_uhcGatherFallbackTypes) {
    id = -1;
  }
  g_uhcGatherFallbackCount = static_cast<std::int32_t>(g_typeNames.size());
  if (!WriteJmp(sites::kGatherFallbackExit.va, reinterpret_cast<const void*>(&UhcHcGatherFallbackHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"hcShipmentPointFallback: %d extra types after the stock list (multiplayer unverified)",
      g_uhcGatherFallbackCount);
  return Outcome::kApplied;
}

}  // namespace uhc
