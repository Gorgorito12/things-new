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
// The getter's hook is shared (autogatherrate.h, with nurseryFactor); this key's filter is ScaleFilter.
#include <cstdint>

#include "../autogatherrate.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// The tactics flag ScaleByContainedUnits: bit 18 of the flag bytes [+64h], whose bit count is [+68h]. The factor
// follows the stock attack rule (0x4996C7..0x49970A): the contained count [unit+74h], or DamageFactorCap [+48h]
// when the count is at least the cap and the cap is above 0. Both are exact as floats, so the product is the one the
// hook of earlier builds computed on the x87 stack.
bool ScaleFilter(const char* unitAction, std::int32_t, float* factor) {
  const char* tactics = Field<const char*>(unitAction, 4);
  if (tactics == nullptr || Field<std::uint32_t>(tactics, 0x68) <= 0x12 ||
      (Field<const std::uint8_t*>(tactics, 0x64)[2] & 4) == 0) {
    return false;
  }
  const char* unit = Field<const char*>(unitAction, 0x10);
  const float count = static_cast<float>(Field<std::int32_t>(unit, 0x74));
  const float cap = Field<float>(tactics, 0x48);
  *factor *= (cap <= count && cap > 0.0f) ? cap : count;
  return true;
}

}  // namespace

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
  if (!AddAutoGatherRateFilter("autoGatherScaleByContained", &ScaleFilter)) {
    return Outcome::kFailed;
  }
  Log(L"autoGatherScaleByContained: AutoGather actions with ScaleByContainedUnits multiply their rate by the units "
      L"inside (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
