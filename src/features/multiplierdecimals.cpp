// multiplierDecimals: the decimals of the bonus multipliers in the attack rows of both selection panels.
//
//   multiplierDecimals [N]   (N 0..3, default 2)
//
// A multiplier that is not whole is written with the wide format ", %.1fx %s" at 0xBA2060 (.rdata) by the stat panel
// fill (0x4D7F7D) and by the minimized block's attack rows (0x699E1F), so a DamageBonus of 1.25 shows as "1.3x" and
// 0.75 as "0.8x". The key writes N over the format's digit (0xBA2068): "1.25x" with N = 2. Whole multipliers keep
// their own format ", %dx %s" (0xC364A8): "2x".
// Each multiplier's rollover line is string 42229, "%1.1fX Bonus Damage against %2s (%3s)" in the English table,
// loaded at 0x4D7FBB (fill) and 0x699E9A (minimized block) through 0x447719; those two calls go to a loader that
// gives the string's "%1.1f" the same N, so the help text says "1.25X" as the row does. A table whose string has
// no "%1.1f" is left as it is.
// The other "%.1fx" of the exe (0xBF1AD0: "Bonus Damage: %s" in the special attacks' and abilities' rollovers,
// 0x69BC28 and 0x6EEC97) is not changed.
// Beside another DLL that already wrote the same digit, the key logs it and writes nothing there.
#include <cstdint>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

struct BString {
  wchar_t* text;
};

using BStringLoadIdFn = BString*(__thiscall*)(BString* self, std::int32_t id);
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringSetFn = void(__thiscall*)(BString* self, const BString* source);
using BStringFreeFn = void(__thiscall*)(BString* self);
const auto kBStringLoadId = reinterpret_cast<BStringLoadIdFn>(0x00447719);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringSet = reinterpret_cast<BStringSetFn>(0x0040196F);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);

constexpr std::uint32_t kDigitOffset = 8;  // the '1' of ", %.1fx %s" (UTF-16)
wchar_t g_digit = L'2';
bool g_tipLogged = false;

// The redirected calls are thiscall (ECX = the BString, the string ID on the stack, popped by the callee); __fastcall
// with an unused EDX has the same frame.
BString* __fastcall LoadMultiplierTip(BString* self, void* /*edx*/, std::int32_t id) {
  BString* result = kBStringLoadId(self, id);
  if (self == nullptr || self->text == nullptr) {
    return result;
  }
  std::wstring text = self->text;
  const size_t at = text.find(L"%1.1f");
  if (at == std::wstring::npos || text[at + 3] == g_digit) {
    return result;
  }
  text[at + 3] = g_digit;
  BString copy{nullptr};
  kBStringFromWide(&copy, text.c_str());
  kBStringSet(self, &copy);
  kBStringFree(&copy);
  if (!g_tipLogged) {
    g_tipLogged = true;
    uhc::Log(L"multiplierDecimals: rollover string %d written with %%1.%lcf", id, g_digit);
  }
  return result;
}

}  // namespace

namespace uhc {

Outcome ApplyMultiplierDecimals(const Config& config) {
  const Config::Args* args = config.First("multiplierDecimals");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  int decimals = 2;
  if (args->size() > 1 || (args->size() == 1 && ((*args)[0].size() != 1 || (*args)[0][0] < '0' ||
                                                  (*args)[0][0] > '3'))) {
    Log(L"multiplierDecimals: expected at most one argument, the decimals 0..3; feature not applied");
    return Outcome::kFailed;
  }
  if (args->size() == 1) {
    decimals = (*args)[0][0] - '0';
  }
  g_digit = static_cast<wchar_t>(L'0' + decimals);
  // The format: stock, or already this digit (another DLL wrote it); anything else is someone else's format.
  const Site& format = sites::kMultiplierFormat;
  const auto* live = reinterpret_cast<const std::uint8_t*>(static_cast<std::uintptr_t>(format.va));
  bool othersMatch = true;
  for (std::uint32_t i = 0; i < format.size; ++i) {
    if (i != kDigitOffset && live[i] != format.bytes[i]) {
      othersMatch = false;
    }
  }
  const wchar_t liveDigit = static_cast<wchar_t>(live[kDigitOffset] | (live[kDigitOffset + 1] << 8));
  bool wrote = false;
  if (othersMatch && liveDigit == g_digit) {
    Log(L"multiplierDecimals: the multiplier format at 0x%08X already has %d decimals; not written", format.va,
        decimals);
  } else if (Matches(format)) {
    const std::uint8_t digit[2] = {static_cast<std::uint8_t>(g_digit), 0};
    if (!WriteBytes(format.va + kDigitOffset, digit, sizeof(digit))) {
      return Outcome::kFailed;
    }
    wrote = true;
  } else {
    Log(L"multiplierDecimals: site %hs at 0x%08X does not hold the stock bytes (nor %d decimals); feature not "
        L"applied",
        format.name, format.va, decimals);
    return Outcome::kFailed;
  }
  // The rollover lines: only while both calls and the loader are stock; otherwise they keep their own text.
  const bool tips = Matches(sites::kMultiplierTipStat) && Matches(sites::kMultiplierTipMin) &&
                    Matches(sites::kBStringLoadId) && Matches(sites::kBStringFromWide) &&
                    Matches(sites::kBStringSet) && Matches(sites::kBStringFree);
  if (tips && (!WriteCall(sites::kMultiplierTipStat.va + 5, reinterpret_cast<const void*>(&LoadMultiplierTip)) ||
               !WriteCall(sites::kMultiplierTipMin.va + 5, reinterpret_cast<const void*>(&LoadMultiplierTip)))) {
    return Outcome::kFailed;
  }
  Log(L"multiplierDecimals: bonus multipliers with %d decimals (%ls)%ls", decimals,
      wrote ? L"format written" : L"format as another DLL left it",
      tips ? L", their rollover lines too" : L"; the rollover calls are not stock, their lines left as they are");
  return Outcome::kApplied;
}

}  // namespace uhc
