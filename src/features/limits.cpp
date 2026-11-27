// Limit features: deckCardCount, basePop/extraPop. The hooks live in hooks/limit_hooks.asm and read
// the values below. decimalPopulation (features/decimalpop.cpp) sets the population scale the cap
// hook multiplies its limits by, and installs that hook itself when basePop/extraPop did not.
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
std::int32_t g_uhcDeckCardCount = 25;
std::int32_t g_uhcBasePop = 200;
std::int32_t g_uhcExtraPop = 50;
std::int32_t g_uhcPopScale = 1;         // decimalPopulation's K
std::int32_t g_uhcPopStockClamps = 0;   // 1: keep stock's world clamp and 250 cap (decimalPopulation alone)

void UhcDeckLimitHook();
void UhcPopLimitHook();
void UhcPopLimitBaseHook();
}

namespace uhc {
namespace {

constexpr int kStockDeckMin = 20;  // the function's lower clamp (0x7EF019)
constexpr int kMaxLimit = 10000;

bool g_popLimitHooked = false;

}  // namespace

// The population cap hook (0x4581F3), once: basePop/extraPop, or decimalPopulation without them.
bool InstallPopLimitHook(const char* feature) {
  if (g_popLimitHooked) {
    return true;
  }
  if (!VerifyAll(feature, {&sites::kPopLimit})) {
    return false;
  }
  // 0x4581FC (`lea esi,[ecx+0C8h]`, 6 bytes) is where the negative-extra path rejoins.
  if (!WriteJmp(sites::kPopLimit.va, reinterpret_cast<const void*>(&UhcPopLimitHook), 5) ||
      !WriteJmp(sites::kPopLimit.va + 9, reinterpret_cast<const void*>(&UhcPopLimitBaseHook), 6)) {
    return false;
  }
  g_popLimitHooked = true;
  return true;
}

bool PopLimitHooked() { return g_popLimitHooked; }

// Max deck size (0x7EEFF7): 20 for a bad index, 25 past the end of the table, otherwise the
// table value clamped to 20..25. Both 25s become deckCardCount.
Outcome ApplyDeckCardCount(const Config& config) {
  if (!config.Has("deckCardCount")) {
    return Outcome::kNotConfigured;
  }
  const auto count = config.Int("deckCardCount");
  if (!count || *count < kStockDeckMin || *count > kMaxLimit) {
    Log(L"deckCardCount: expected an integer from %d to %d", kStockDeckMin, kMaxLimit);
    return Outcome::kFailed;
  }
  if (!VerifyAll("deckCardCount", {&sites::kDeckLimit, &sites::kDeckOutOfRange})) {
    return Outcome::kFailed;
  }
  g_uhcDeckCardCount = *count;
  // mov eax, imm32 at 0x7EF005: the imm32 starts one byte in.
  if (!WriteDword(sites::kDeckOutOfRange.va + 1, static_cast<std::uint32_t>(*count)) ||
      !WriteJmp(sites::kDeckLimit.va, reinterpret_cast<const void*>(&UhcDeckLimitHook), 10)) {
    return Outcome::kFailed;
  }
  Log(L"deckCardCount: limit %d", *count);
  return Outcome::kApplied;
}

// Population cap (0x4581F3): stock allows at most 50 extra and 200 base population.
Outcome ApplyPopLimit(const Config& config) {
  const bool hasBase = config.Has("basePop");
  const bool hasExtra = config.Has("extraPop");
  if (!hasBase && !hasExtra) {
    return Outcome::kNotConfigured;
  }
  const auto base = hasBase ? config.Int("basePop") : std::optional<int>(g_uhcBasePop);
  const auto extra = hasExtra ? config.Int("extraPop") : std::optional<int>(g_uhcExtraPop);
  if (!base || !extra || *base < 0 || *base > kMaxLimit || *extra < 0 || *extra > kMaxLimit) {
    Log(L"basePop/extraPop: expected integers from 0 to %d", kMaxLimit);
    return Outcome::kFailed;
  }
  if (!VerifyAll("basePop/extraPop", {&sites::kPopLimit})) {
    return Outcome::kFailed;
  }
  g_uhcBasePop = *base;
  g_uhcExtraPop = *extra;
  if (!InstallPopLimitHook("basePop/extraPop")) {
    return Outcome::kFailed;
  }
  Log(L"basePop/extraPop: base %d, extra %d (stock 250 cap and world clamp removed; "
      L"shared team population at 0x679641 keeps its 200-per-player cap)",
      *base, *extra);
  return Outcome::kApplied;
}

}  // namespace uhc
