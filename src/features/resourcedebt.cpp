// resourceDebt: a player's stockpile of the listed resources may go below 0.
//
// Stock: a negative ResourceTrickleRate, with MinimumResourceTrickleRate lowered too, drains a
// stockpile, and it stops at 0: the add 0x49A98A clamps the sum at its cold part 0x679A0E, and the
// set 0x49A8C5 clamps its value at 0x6798F4. With the key those two clamps skip the listed
// resources. Nothing else changes: a cost is compared with the stockpile, so a player in debt
// cannot pay until the stockpile is back above the cost. The hooks are in
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
}

namespace {

struct ResourceName {
  const char* name;
  int index;
};
constexpr ResourceName kResources[] = {{"Gold", 0}, {"Coin", 0}, {"Wood", 1}, {"Food", 2}};

}  // namespace

namespace uhc {

Outcome ApplyResourceDebt(const Config& config) {
  const Config::Args* args = config.First("resourceDebt");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::string list;
  for (const std::string& arg : *args) {
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
  if (!VerifyAll("resourceDebt", {&sites::kDebtAddClamp, &sites::kDebtSetClamp})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kDebtAddClamp.va, reinterpret_cast<const void*>(&UhcDebtAddHook), 8) ||
      !WriteJmp(sites::kDebtSetClamp.va, reinterpret_cast<const void*>(&UhcDebtSetHook), 8)) {
    return Outcome::kFailed;
  }
  Log(L"resourceDebt: stockpiles of %hs may go below 0 (multiplayer unverified)", list.c_str());
  return Outcome::kApplied;
}

}  // namespace uhc
