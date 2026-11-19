// healNonIdle [UnitType] [moving] [fighting] [busyRate=<percent>]: healers whose proto has a
// marker unittype (default AbstractHealNonIdle) heal targets that are moving or fighting. Stock
// blocks them twice: the automatic target search only takes idle targets, and each heal tick
// stops when the target moves or fights. Both hooks are in hooks/heal_hooks.asm; the marker is
// registered as an extra abstract unit type (unittypes.h), so protoy.xml can list it on any healer.
//
// "moving" / "fighting" (both when neither is given): the busy states a marked healer may heal.
// With only one, the other keeps its stock test, in the tick (the heal ends) and in the search
// (no such candidate), through the same two predicates the stock tick calls. "busyRate=<percent>"
// (1..1000, default 100): a tick whose target is moving or fighting heals that percent of the
// normal amount; the tick hook notes the action, and a third hook in the heal path (0x9E0CC7)
// scales the [world+318h] factor of that tick's heal. Every decision reads only simulation state.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
std::int32_t g_uhcHealNonIdleType = -1;
std::int32_t g_uhcHealAllowMoving = 1;
std::int32_t g_uhcHealAllowFighting = 1;
std::int32_t g_uhcHealCheckBusy = 0;
const char* g_uhcHealBusyAction = nullptr;
float g_uhcHealBusyFactor = 1.0f;

void UhcHealNonIdleHook();
void UhcHealAutoSearchHook();
void UhcHealBusyRateHook();
}

namespace {

// "busyRate=50": an integer percent in [1, 1000].
bool ParsePercent(const std::string& text, std::int32_t* percent) {
  char* end = nullptr;
  const long value = std::strtol(text.c_str(), &end, 10);
  if (text.empty() || end != text.c_str() + text.size() || value < 1 || value > 1000) {
    return false;
  }
  *percent = static_cast<std::int32_t>(value);
  return true;
}

}  // namespace

namespace uhc {

Outcome ApplyHealNonIdle(const Config& config) {
  const Config::Args* args = config.First("healNonIdle");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::string typeName;
  bool moving = false;
  bool fighting = false;
  std::int32_t busyRate = 100;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "moving") == 0) {
      moving = true;
    } else if (_stricmp(arg.c_str(), "fighting") == 0) {
      fighting = true;
    } else if (_strnicmp(arg.c_str(), "busyRate=", 9) == 0) {
      std::string value = arg.substr(9);
      if (!value.empty() && value.back() == '%') {
        value.pop_back();
      }
      if (!ParsePercent(value, &busyRate)) {
        Log(L"healNonIdle: %hs: expected busyRate=<percent>, 1 to 1000; feature not applied", arg.c_str());
        return Outcome::kFailed;
      }
    } else if (typeName.empty() && arg.find('=') == std::string::npos) {
      typeName = arg;
    } else {
      Log(L"healNonIdle: %hs: expected healNonIdle [UnitType] [moving] [fighting] [busyRate=<percent>]; feature not "
          L"applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (typeName.empty()) {
    typeName = "AbstractHealNonIdle";
  }
  if (!moving && !fighting) {
    moving = fighting = true;
  }
  const bool scaled = busyRate != 100;
  if (!VerifyAll("healNonIdle", {&sites::kHealIdleCheck, &sites::kHealAutoSearchIdle}) ||
      (scaled && !VerifyAll("healNonIdle busyRate", {&sites::kHealTickFactors})) ||
      ((scaled || !moving || !fighting) &&
       !VerifyAll("healNonIdle states", {&sites::kHealTargetMoving, &sites::kHealTargetFighting}))) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(typeName.c_str(), &g_uhcHealNonIdleType)) {
    return Outcome::kFailed;
  }
  g_uhcHealAllowMoving = moving ? 1 : 0;
  g_uhcHealAllowFighting = fighting ? 1 : 0;
  g_uhcHealCheckBusy = (scaled || !moving || !fighting) ? 1 : 0;
  g_uhcHealBusyFactor = static_cast<float>(busyRate) / 100.0f;
  if (!WriteJmp(sites::kHealIdleCheck.va, reinterpret_cast<const void*>(&UhcHealNonIdleHook), 5) ||
      !WriteJmp(0x009CD9C7, reinterpret_cast<const void*>(&UhcHealAutoSearchHook), 5) ||
      (scaled && !WriteJmp(0x009E0CC7, reinterpret_cast<const void*>(&UhcHealBusyRateHook), 8))) {
    return Outcome::kFailed;
  }
  const wchar_t* states = moving && fighting ? L"busy" : moving ? L"moving (not fighting)" : L"fighting (not moving)";
  if (scaled) {
    Log(L"healNonIdle: healers of unittype %hs heal %ls targets, at %d %% of their rate (multiplayer unverified)",
        typeName.c_str(), states, busyRate);
  } else {
    Log(L"healNonIdle: healers of unittype %hs heal %ls targets (multiplayer unverified)", typeName.c_str(), states);
  }
  return Outcome::kApplied;
}

}  // namespace uhc
