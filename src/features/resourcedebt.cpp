// resourceDebt: only a player's trickles and the rates of its units may take a stockpile of the listed
// resources below 0.
//
// Stock: the add 0x49A98A clamps the sum at 0 at its cold part 0x679A0E, in its shared-resources path
// at 0x6799D4 (once per teammate), and the set 0x49A8C5 clamps its value at 0x6798F4.
// With the key each clamp asks UhcDebtFloor, by the return address of the add:
// - the global trickle (0x4E0CF9), unit AutoGather (0x4C3798) and the gather tick (0x4ED1EE) have no floor;
// - anything else (tech effects, triggers, costs, shipments) stops at 0, or at the debt the stockpile
//   already has: it neither digs a debt nor wipes one. An income on a debt keeps the rest of the debt.
// A set called by the add itself keeps what the add settled.
// Stock also stops negative rates before the add: the AutoGather getter returns 0 below 1e-6, its update
// skips an amount below 1e-6 and the gather tick ends the action at a rate of 1e-6 or less. The other
// three hooks let the negative rates of the listed resources through. A cost is compared with the
// stockpile, so a player in debt cannot pay until it is back above the cost. The hooks are in
// hooks/resourcedebt_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
std::uint8_t g_uhcDebtResources[16] = {};  // by resource index; 1: no floor at 0

void UhcDebtAddHook();
void UhcDebtSetHook();
void UhcDebtShareHook();
void UhcDebtAutoGateHook();
void UhcDebtAutoRateHook();
void UhcDebtGatherGateHook();
}

namespace {

struct ResourceName {
  const char* name;
  int index;
};
constexpr ResourceName kResources[] = {{"Gold", 0}, {"Coin", 0}, {"Wood", 1}, {"Food", 2}};
constexpr int kMaxLogLines = 200;
// Where the add returns to in the three callers that have no floor.
constexpr std::uint32_t kGlobalTrickle = 0x004E0CFE;
constexpr std::uint32_t kUnitAutoGather = 0x004C379D;
constexpr std::uint32_t kGatherTick = 0x004ED1F3;
constexpr std::size_t kStockpiles = 0x230;  // [player+230h], the stockpile array

using StockpileFn = float(__thiscall*)(const void* stockpiles, std::int32_t resource);
const auto kStockpile = reinterpret_cast<StockpileFn>(0x0044EFFF);

bool g_log = false;
int g_logLines = 0;

}  // namespace

// From the clamps, for a listed resource. `value` holds a sum or value below 1e-6; `caller` is where
// the add or the set returns to.
extern "C" void __stdcall UhcDebtFloor(const char* player, std::int32_t resource, float* value,
                                       std::uint32_t caller) {
  const bool source = caller == kGlobalTrickle || caller == kUnitAutoGather || caller == kGatherTick;
  const float before = *value;
  if (!source) {
    const float current = kStockpile(player + kStockpiles, resource);
    *value = current < 0.0f ? (before > current ? before : current) : 0.0f;
  }
  if (!g_log || g_logLines >= kMaxLogLines || before >= 0.0f) {
    return;
  }
  ++g_logLines;
  uhc::Log(L"resourceDebt: player %d, resource %d, from 0x%08X: %.1f%ls", *reinterpret_cast<const std::int32_t*>(player),
           resource, caller, static_cast<double>(*value), *value == before ? L"" : L" (held by the floor)");
}

namespace uhc {

Outcome ApplyResourceDebt(const Config& config) {
  const Config::Args* args = config.First("resourceDebt");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::string list;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    int index = -1;
    for (const ResourceName& resource : kResources) {
      if (_stricmp(arg.c_str(), resource.name) == 0) {
        index = resource.index;
      }
    }
    if (index < 0) {
      Log(L"resourceDebt: unknown resource %hs (expected: Food, Wood, Gold); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_uhcDebtResources[index] = 1;
    list += (list.empty() ? "" : " ") + arg;
  }
  if (list.empty()) {
    g_uhcDebtResources[0] = g_uhcDebtResources[1] = g_uhcDebtResources[2] = 1;
    list = "Food Wood Gold";
  }
  if (!VerifyAll("resourceDebt", {&sites::kDebtAddClamp, &sites::kDebtSetClamp, &sites::kDebtShareClamp,
                                  &sites::kDebtAutoGate, &sites::kDebtAutoRate, &sites::kDebtGatherGate})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kDebtAddClamp.va, reinterpret_cast<const void*>(&UhcDebtAddHook), 8) ||
      !WriteJmp(sites::kDebtSetClamp.va, reinterpret_cast<const void*>(&UhcDebtSetHook), 8) ||
      !WriteJmp(sites::kDebtShareClamp.va, reinterpret_cast<const void*>(&UhcDebtShareHook), 8) ||
      !WriteJmp(sites::kDebtAutoGate.va, reinterpret_cast<const void*>(&UhcDebtAutoGateHook), 6) ||
      !WriteJmp(sites::kDebtAutoRate.va, reinterpret_cast<const void*>(&UhcDebtAutoRateHook), 6) ||
      !WriteJmp(sites::kDebtGatherGate.va, reinterpret_cast<const void*>(&UhcDebtGatherGateHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"resourceDebt: trickles and unit rates may take %hs below 0 (multiplayer unverified)", list.c_str());
  return Outcome::kApplied;
}

}  // namespace uhc
