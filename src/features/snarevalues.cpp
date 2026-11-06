// snareValues: the slowdown of <TargetSpeedBoost> by action and by tech.
//
// Stock has two literals, 0.65 and 3000 ms, in the arguments of the creator 0x4DD22D at 0x4DD201. The key
// takes over from 0x4DD207, after the part cantBeSlowed writes, and pushes the action's values:
//   <SnareFactor>0.3</SnareFactor>       the speed factor, from 0 to 10
//   <SnareDuration>6</SnareDuration>     seconds, above 0
// in a <ProtoAction> or a tactics <action> that has <TargetSpeedBoost>. The Data subtypes SnareFactor and
// SnareDuration change them for one player's copy of the action, through the stock value function, from
// the tag's value as base. A tech that leaves a duration of 0 or less means no snare: the creator takes a
// duration of 0 as a modifier with no end.
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <unordered_map>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

extern "C" void UhcSnareValuesHook();

namespace {

constexpr float kStockFactor = 0.65f;
constexpr float kStockSeconds = 3.0f;
constexpr int kMaxLogLines = 200;

using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Values {
  float factor = kStockFactor;
  float seconds = kStockSeconds;
};

struct TechValues {
  std::int32_t name;
  Values values;
};

std::map<ActionKey, Values> g_values;                   // by proto and action, from the data
std::unordered_map<const char*, TechValues> g_tech;     // by the player's copy of the action
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

Values BaseValues(std::int32_t proto, std::int32_t name) {
  const auto found = g_values.find({proto, name});
  return found == g_values.end() ? Values{} : found->second;
}

void NewDatabase(char*) {
  g_values.clear();
  g_tech.clear();
  g_logLines = 0;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  const bool factor = _wcsicmp(tag.name, L"SnareFactor") == 0;
  if (!factor && _wcsicmp(tag.name, L"SnareDuration") != 0) {
    return;
  }
  wchar_t* end = nullptr;
  const float value = tag.text == nullptr ? -1.0f : std::wcstof(tag.text, &end);
  const std::int32_t name = Field<std::int32_t>(tag.action, 0x04);
  const bool good = tag.text != nullptr && end != tag.text && (factor ? value >= 0.0f && value <= 10.0f : value > 0.0f);
  if (!good || name < 0) {
    uhc::Log(L"snareValues: proto %hs: <%ls> needs %ls, after the action's <Name>; ignored",
             Field<const char*>(tag.proto, 0x10), tag.name, factor ? L"a factor from 0 to 10" : L"seconds above 0");
    return;
  }
  Values& values = g_values[{Field<std::int32_t>(tag.proto, 0x04), name}];
  (factor ? values.factor : values.seconds) = value;
  if (g_log) {
    uhc::Log(L"snareValues: proto %hs, action %d: factor %g, %g s", Field<const char*>(tag.proto, 0x10), name,
             static_cast<double>(values.factor), static_cast<double>(values.seconds));
  }
}

template <bool kFactor>
void Change(char* action, const char*, const char* proto, float amount, std::uint8_t relativity, bool unapply) {
  const std::int32_t name = Field<std::int32_t>(action, 0x04);
  const Values base = BaseValues(Field<std::int32_t>(proto, 0x04), name);
  TechValues& slot = g_tech.emplace(action, TechValues{name, base}).first->second;
  if (slot.name != name) {
    slot = TechValues{name, base};
  }
  float& value = kFactor ? slot.values.factor : slot.values.seconds;
  kEffectValue(relativity, &value, kFactor ? base.factor : base.seconds, amount, unapply);
  if (g_log) {
    uhc::Log(L"snareValues: action %d of proto %d: %ls %g%ls", name, Field<std::int32_t>(proto, 0x04),
             kFactor ? L"factor" : L"duration", static_cast<double>(value), unapply ? L" (removed)" : L"");
  }
}

}  // namespace

// From the hook: the values of the attacker's unit action. *ms 0: no snare.
extern "C" void __stdcall UhcSnareValues(const char* unitAction, float* factor, std::int32_t* ms) {
  Values values;
  const char* tactics = unitAction == nullptr ? nullptr : Field<const char*>(unitAction, 0x04);
  const char* unit = unitAction == nullptr ? nullptr : Field<const char*>(unitAction, 0x10);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (tactics != nullptr && proto != nullptr) {
    const std::int32_t name = Field<std::int32_t>(tactics, 0x04);
    values = BaseValues(Field<std::int32_t>(proto, 0x04), name);
    const auto tech = g_tech.find(tactics);
    if (tech != g_tech.end() && tech->second.name == name) {
      values = tech->second.values;
    }
  }
  *factor = values.factor;
  *ms = values.seconds > 0.0f ? static_cast<std::int32_t>(values.seconds * 1000.0f + 0.5f) : 0;
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"snareValues: a snare of factor %g for %d ms", static_cast<double>(*factor), *ms);
  }
}

namespace uhc {

Outcome ApplySnareValues(const Config& config) {
  const Config::Args* args = config.First("snareValues");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"snareValues: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("snareValues", {&sites::kSnareDurationPush, &sites::kSnareCreateTail}) ||
      !AddActionTagHandler(&ActionTagRead) || !OnDatabaseLoad(&NewDatabase) ||
      !AddTechActionSubtype("SnareFactor", &Change<true>) || !AddTechActionSubtype("SnareDuration", &Change<false>) ||
      !WriteJmp(sites::kSnareDurationPush.va, reinterpret_cast<const void*>(&UhcSnareValuesHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"snareValues: <SnareFactor>, <SnareDuration> and their Data subtypes are on (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
