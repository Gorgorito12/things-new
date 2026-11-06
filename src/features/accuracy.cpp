// accuracyTechs: a tech effect type="Data" subtype="Accuracy" changes an action's <Accuracy>.
//
// Stock keeps the tag in the action's [+38h], default 1, and reads it at the projectile launch: the
// hit chance is accuracy x 100 - d / 2, d the distance. No Data subtype reaches the field, so the
// effect is a new one on the action (techsubtypes.h), applied through the stock value function 0x7F892A,
// which gives it every relativity and its removal.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../log.h"
#include "../techsubtypes.h"

namespace {

constexpr std::size_t kAccuracy = 0x38;
constexpr int kMaxLogLines = 200;

using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);

bool g_log = false;
int g_logLines = 0;

void ChangeAccuracy(char* action, const char* baseAction, const char*, float amount, std::uint8_t relativity,
                    bool unapply) {
  auto* value = reinterpret_cast<float*>(action + kAccuracy);
  const float before = *value;
  const float base = baseAction != nullptr ? *reinterpret_cast<const float*>(baseAction + kAccuracy) : 1.0f;
  kEffectValue(relativity, value, base, amount, unapply);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"accuracyTechs: action %d, relativity %u, amount %g%ls: %g -> %g",
             *reinterpret_cast<const std::int32_t*>(action + 4), relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", static_cast<double>(before), static_cast<double>(*value));
  }
}

}  // namespace

namespace uhc {

Outcome ApplyAccuracyTechs(const Config& config) {
  const Config::Args* args = config.First("accuracyTechs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"accuracyTechs: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!AddTechActionSubtype("Accuracy", &ChangeAccuracy)) {
    return Outcome::kFailed;
  }
  Log(L"accuracyTechs: the Data subtype Accuracy is on");
  return Outcome::kApplied;
}

}  // namespace uhc
