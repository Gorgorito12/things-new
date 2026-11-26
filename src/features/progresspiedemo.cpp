// progressPieDemo [seconds] [RRGGBBAA]: a dev key that shows the shared progress pie (progresspie.h) over the portrait
// of any one selected unit, filling once every `seconds` of game time (default 10, 1 to 600), in the train button's
// blue or the colour given. It has no game effect: it is the test bed of the pie for the keys that use it.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../log.h"
#include "../progresspie.h"

namespace uhc {
namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // [+13Ch] the world, [world+108h] its game time in ms

std::uint32_t g_periodMs = 10000;
std::uint32_t g_argb = kPieTrainBlue;

std::uint32_t GameTimeMs() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : *reinterpret_cast<const char* const*>(game + 0x13C);
  return world == nullptr ? 0 : *reinterpret_cast<const std::uint32_t*>(world + 0x108);
}

bool __stdcall DemoSource(const char*, float* fraction, std::uint32_t* argb) {
  *fraction = static_cast<float>(GameTimeMs() % g_periodMs) / static_cast<float>(g_periodMs);
  *argb = g_argb;
  return true;
}

}  // namespace

Outcome ApplyProgressPieDemo(const Config& config) {
  const Config::Args* args = config.First("progressPieDemo");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!args->empty()) {
    const int seconds = std::atoi((*args)[0].c_str());
    if (seconds < 1 || seconds > 600) {
      Log(L"progressPieDemo: the period is 1 to 600 seconds");
      return Outcome::kFailed;
    }
    g_periodMs = static_cast<std::uint32_t>(seconds) * 1000;
  }
  if (args->size() > 1) {
    const std::string& colour = (*args)[1];
    char* end = nullptr;
    const unsigned long rgba = std::strtoul(colour.c_str(), &end, 16);
    if (colour.size() != 8 || end == nullptr || *end != '\0') {
      Log(L"progressPieDemo: the colour is RRGGBBAA in hex");
      return Outcome::kFailed;
    }
    g_argb = static_cast<std::uint32_t>((rgba >> 8) | ((rgba & 0xFF) << 24));
  }
  if (!AddProgressPieSource(&DemoSource)) {
    return Outcome::kFailed;
  }
  Log(L"progressPieDemo: the pie fills over the portrait of one selected unit every %u s, colour %08X (ARGB)",
      g_periodMs / 1000, g_argb);
  return Outcome::kApplied;
}

}  // namespace uhc
