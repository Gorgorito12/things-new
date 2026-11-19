// autoGatherScaleByContained: <ScaleByContainedUnits> also works on AutoGather actions.
//
// Stock: the tactics flag ScaleByContainedUnits (bit 18, set at 0x5FEE1A) is read by the attack
// code only (0x4996C7, and the stat panel): the damage is multiplied by the unit's contained count
// [unit+74h], at most DamageFactorCap ([tacticsAction+48h]) when that is above 0. An AutoGather
// action accepts the tag and ignores it. ActiveIfContainsUnits, which the AutoGather update does
// read, is on or off and no more.
//
// With the key, the AutoGather rate getter 0x49EBE4 multiplies its result in the same way, so the
// update (0x48D16E) and the rate rows of both panels (0x6992BD, 0x69B005) follow. An action without
// the flag runs the stock getter unchanged. With nobody inside the factor is 0, as in an attack.
// The hook is in hooks/gatherscale_hooks.asm.
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcAutoGatherRateHook();
}

namespace uhc {

Outcome ApplyAutoGatherScaleByContained(const Config& config) {
  const Config::Args* args = config.First("autoGatherScaleByContained");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!args->empty()) {
    Log(L"autoGatherScaleByContained: unexpected argument %hs (it takes none); feature not applied",
        args->front().c_str());
    return Outcome::kFailed;
  }
  if (!VerifyAll("autoGatherScaleByContained", {&sites::kAutoGatherRateEntry})) {
    return Outcome::kFailed;
  }
  // Replaces push ecx / push ebx / mov ebx,[esp+0Ch] at 0x49EBE4; the hook re-executes them.
  if (!WriteJmp(sites::kAutoGatherRateEntry.va, reinterpret_cast<const void*>(&UhcAutoGatherRateHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"autoGatherScaleByContained: AutoGather actions with ScaleByContainedUnits multiply their rate by the units "
      L"inside (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
