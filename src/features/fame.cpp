// removeFameRestriction: fame, XP and shipment costs on the politician screens, home-city icons
// for fame and XP, and fame trickle. The hooks are in hooks/fame_hooks.asm.
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
// Texture handles from 0x58E3EB; -1 until loaded, and when the art file is missing.
std::int32_t g_uhcXpIcon = -1;
std::int32_t g_uhcFameIcon = -1;
// The mod supplies Art\ui\home_city\{xp,fame}_hc_icon.ddt (the conventional names).
extern const wchar_t g_uhcXpIconPath[] = L"ui\\home_city\\xp_hc_icon";
extern const wchar_t g_uhcFameIconPath[] = L"ui\\home_city\\fame_hc_icon";

void UhcPoliticianCostsHook();
void UhcPoliticianCosts2Hook();
void UhcFameIconsHook();
void UhcFameIconCase();
void UhcXpIconCase();
}

namespace uhc {
namespace {

std::uint32_t Address(void (*hook)()) {
  return static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(hook));
}

}  // namespace

Outcome ApplyRemoveFameRestriction(const Config& config) {
  if (!config.Has("removeFameRestriction")) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("removeFameRestriction",
                 {&sites::kFameTrickle, &sites::kFameKey, &sites::kFameHcIcons, &sites::kFameIconSlot,
                  &sites::kXpIconSlot, &sites::kIconSetCase, &sites::kIconDefaultCase,
                  &sites::kPoliticianCosts, &sites::kPoliticianCosts2})) {
    return Outcome::kFailed;
  }
  // push imm32 at 0x51B025: the trickle reads the "Fame" resource instead of "FavoriteUnit".
  const bool ok = WriteDword(sites::kFameTrickle.va + 1, sites::kFameKey.va) &&
                  WriteJmp(sites::kFameHcIcons.va, reinterpret_cast<const void*>(&UhcFameIconsHook), 5) &&
                  WriteDword(sites::kFameIconSlot.va, Address(&UhcFameIconCase)) &&
                  WriteDword(sites::kXpIconSlot.va, Address(&UhcXpIconCase)) &&
                  WriteJmp(sites::kPoliticianCosts.va, reinterpret_cast<const void*>(&UhcPoliticianCostsHook), 6) &&
                  WriteJmp(sites::kPoliticianCosts2.va, reinterpret_cast<const void*>(&UhcPoliticianCosts2Hook), 6);
  if (!ok) {
    return Outcome::kFailed;
  }
  Log(L"removeFameRestriction: icons need Art\\%ls.ddt and Art\\%ls.ddt from the mod; "
      L"without them those resources keep the stock (no) icon",
      g_uhcXpIconPath, g_uhcFameIconPath);
  return Outcome::kApplied;
}

}  // namespace uhc
