// selectionLimit N: the most units one selection holds (stock 50). The cap is the immediate of
// `mov eax,32h` at eight places: the getter 0x4E0BEE (`mov eax,32h / ret`) and seven compares of
// a selection's count ([list+24h], a growable array) with it before a unit is added. Each site's
// imm32 is rewritten; no hook.
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace uhc {

Outcome ApplySelectionLimit(const Config& config) {
  if (!config.Has("selectionLimit")) {
    return Outcome::kNotConfigured;
  }
  const auto value = config.Int("selectionLimit");
  constexpr int kMax = 200;
  if (!value || *value < 1 || *value > kMax) {
    Log(L"selectionLimit: needs a number from 1 to %d (stock 50)", kMax);
    return Outcome::kFailed;
  }
  const Site* const sites[] = {&sites::kSelectionCap1, &sites::kSelectionCap2, &sites::kSelectionCap3,
                               &sites::kSelectionCap4, &sites::kSelectionCap5, &sites::kSelectionCap6,
                               &sites::kSelectionCap7, &sites::kSelectionCap8};
  if (!VerifyAll("selectionLimit", {sites[0], sites[1], sites[2], sites[3], sites[4], sites[5], sites[6], sites[7]})) {
    return Outcome::kFailed;
  }
  for (const Site* site : sites) {
    if (!WriteDword(site->va + 1, static_cast<std::uint32_t>(*value))) {
      return Outcome::kFailed;
    }
  }
  Log(L"selectionLimit: a selection holds up to %d units (stock 50)%ls", *value,
      *value > 75 ? L"; above 75 not tested" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
