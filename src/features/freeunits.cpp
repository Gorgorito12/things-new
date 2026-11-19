// betterfreedynamicunit: "dynamic" free units grow smoothly with game time.
//
// A FreeHomeCityUnit effect with a negative amount gives a count that grows with the game: stock
// computes -amount * min([world+134h], 15), with an integer from the world, in two copies of the
// same code (0x7FA6D5 and 0x8D8C6F, each after a test that skips other amounts). The key
// replaces both computations with -amount * min(gameTime / 120 s, 15), the game time
// ([world+108h], ms) in 2-minute steps without rounding, so the count rises continuously up to
// the same cap.
#include <cstdint>
#include <cstring>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcFreeDynamicUnit1Hook();
void UhcFreeDynamicUnit2Hook();
}

namespace {
bool g_logged = false;
}

extern "C" std::uint32_t __cdecl UhcDynamicUnitCount(std::uint32_t amountBits) {
  float amount;
  std::memcpy(&amount, &amountBits, sizeof amount);
  const char* game = *reinterpret_cast<char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : *reinterpret_cast<char* const*>(game + 0x13C);
  float steps = 0.0f;
  if (world != nullptr) {
    steps = static_cast<float>(*reinterpret_cast<const std::int32_t*>(world + 0x108)) / 120000.0f;
  }
  if (steps > 15.0f) {
    steps = 15.0f;
  }
  const float count = -amount * steps;
  if (!g_logged) {
    g_logged = true;
    uhc::Log(L"betterfreedynamicunit: amount %.3f at %.2f steps of 2 min -> %.3f", static_cast<double>(amount),
             static_cast<double>(steps), static_cast<double>(count));
  }
  std::uint32_t bits;
  std::memcpy(&bits, &count, sizeof bits);
  return bits;
}

namespace uhc {

Outcome ApplyBetterFreeDynamicUnit(const Config& config) {
  if (config.First("betterfreedynamicunit") == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("betterfreedynamicunit", {&sites::kFreeDynamicUnit1, &sites::kFreeDynamicUnit2})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kFreeDynamicUnit1.va, reinterpret_cast<const void*>(&UhcFreeDynamicUnit1Hook),
                sites::kFreeDynamicUnit1.size) ||
      !WriteJmp(sites::kFreeDynamicUnit2.va, reinterpret_cast<const void*>(&UhcFreeDynamicUnit2Hook),
                sites::kFreeDynamicUnit2.size)) {
    return Outcome::kFailed;
  }
  Log(L"betterfreedynamicunit: dynamic free units grow with game time (2-minute steps, unrounded, at most 15)");
  return Outcome::kApplied;
}

}  // namespace uhc
