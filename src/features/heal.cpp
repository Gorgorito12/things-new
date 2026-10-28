// healNonIdle: healers whose proto has a marker unittype (default AbstractHealNonIdle) heal
// targets that are moving or fighting. Stock blocks them twice: the automatic target search
// only takes idle targets, and each heal tick stops when the target moves or fights. Both
// hooks are in hooks/heal_hooks.asm; the marker is registered as an extra abstract unit type
// (unittypes.h), so protoy.xml can list it on any healer.
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
std::int32_t g_uhcHealNonIdleType = -1;

void UhcHealNonIdleHook();
void UhcHealAutoSearchHook();
}

namespace uhc {

Outcome ApplyHealNonIdle(const Config& config) {
  const Config::Args* args = config.First("healNonIdle");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  const char* typeName = args->empty() ? "AbstractHealNonIdle" : args->front().c_str();
  if (!VerifyAll("healNonIdle", {&sites::kHealIdleCheck, &sites::kHealAutoSearchIdle})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(typeName, &g_uhcHealNonIdleType)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kHealIdleCheck.va, reinterpret_cast<const void*>(&UhcHealNonIdleHook), 5) ||
      !WriteJmp(0x009CD9C7, reinterpret_cast<const void*>(&UhcHealAutoSearchHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"healNonIdle: healers of unittype %hs heal busy targets (multiplayer unverified)", typeName);
  return Outcome::kApplied;
}

}  // namespace uhc
