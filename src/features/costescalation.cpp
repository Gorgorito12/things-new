// costEscalationTechs: a tech effect type="Data" subtype="CostEscalation" changes a proto's
// <CostEscalation>.
//
// Stock keeps the tag in the proto's [+78h], default 1. The cost getter 0x480B1E reads it from the
// player's copy on every call: when it is not 1, each cost is multiplied by it (N + count - 1) times,
// N being the count of that proto the player has. No Data subtype reaches the field, so the effect
// is a new one (techsubtypes.h), applied through the stock value function 0x7F892A, which gives it
// every relativity and its removal.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../log.h"
#include "../techsubtypes.h"

namespace {

constexpr std::size_t kEscalation = 0x78;
constexpr int kMaxLogLines = 200;

using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);

bool g_log = false;
int g_logLines = 0;

void ChangeEscalation(char* proto, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  auto* value = reinterpret_cast<float*>(proto + kEscalation);
  const float before = *value;
  kEffectValue(relativity, value, *reinterpret_cast<const float*>(base + kEscalation), amount, unapply);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"costEscalationTechs: proto %d, relativity %u, amount %g%ls: %g -> %g",
             *reinterpret_cast<const std::int32_t*>(proto + 8), relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", static_cast<double>(before), static_cast<double>(*value));
  }
}

}  // namespace

namespace uhc {

Outcome ApplyCostEscalationTechs(const Config& config) {
  const Config::Args* args = config.First("costEscalationTechs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"costEscalationTechs: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!AddTechSubtype("CostEscalation", &ChangeEscalation)) {
    return Outcome::kFailed;
  }
  Log(L"costEscalationTechs: the Data subtype CostEscalation is on");
  return Outcome::kApplied;
}

}  // namespace uhc
