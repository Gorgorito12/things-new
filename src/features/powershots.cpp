// powerShots [log]: an attack launched by a power (an ability such as an explorer's sharpshooter shot) whose action
// carries <PowerShots>N</PowerShots> fires a shot at each Attack tag of its animation, up to N shots a use, instead of
// one.
//
// Stock: a power-launched attack keeps its power use at [ua+6Ch] (the ability record at [use+1Ch]). At each Attack
// tag of its animation (the event handler 0x48CED0, event 5 -> 0x48F739, state 1), the shot path 0x48F7E4 sends it to
// 0x48EA3D, which asks the power manager [world+56Ch] whether the power is ready (0x6EDB7E(unit ID, record, ...)) and
// goes on at 0x4B7766: ready, the shot (0x48F7F1); not ready, no shot (0x48CF7B). The first shot starts the power's
// recharge, so every later tag of the same use gets "not ready": [O, hardware breakpoints in game] the three Attack
// tags of an explorer's power animation, 210 ms apart, fired one shot; 0x6EDB7E answered 1, 0, 0.
//
// The hook (hooks/powershots_hooks.asm, at 0x4B7766) keeps the stock answer when the power is ready. When it is not,
// UhcPowerShotsAllow lets the tag fire for an action with the tag, in state 1, that has fired at least one shot of
// this use (so the first shot of a use is always the stock, ready one) and fewer than N ([ua+68h], the unit action's
// shot count, 0 at each use). The shot then goes through the stock path, so retargetInAction, numberOfShots' ROF
// filters and the projectile launch see it as any other shot.
#include <windows.h>

#include <compare>
#include <cstdint>
#include <cwchar>
#include <map>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
void UhcPowerShotsHook();  // hooks/powershots_hooks.asm
// Above 0 while some action carries <PowerShots> above 1: the hook asks UhcPowerShotsAllow only then.
std::int32_t g_uhcPowerShotsOn = 0;
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint8_t kStateFiring = 0x01;        // the attack animation: its Attack tags fire
constexpr std::int32_t kMaxShots = 50;
constexpr unsigned kMaxLogLines = 300;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

std::int32_t Now() {
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  return world == nullptr ? 0 : Field<std::int32_t>(world, 0x108);
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name != nullptr ? name : "?";
}

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

std::map<ActionKey, std::int32_t> g_shots;  // filled while the data loads; a later tag of the same action wins
bool g_log = false;
unsigned g_logLines = 0;
unsigned g_tagLines = 0;
unsigned g_invalidLines = 0;

void SyncGate() {
  bool on = false;
  for (const auto& [key, shots] : g_shots) {
    on = on || shots > 1;
  }
  g_uhcPowerShotsOn = on ? 1 : 0;
}

void ResetForDataLoad(char*) {
  g_shots.clear();
  g_logLines = 0;
  g_tagLines = 0;
  g_invalidLines = 0;
  SyncGate();
}

bool ParseShots(const wchar_t* text, std::int32_t* out) {
  if (text == nullptr) {
    return false;
  }
  while (*text == L' ' || *text == L'\t' || *text == L'\r' || *text == L'\n') {
    ++text;
  }
  wchar_t* end = nullptr;
  const long value = std::wcstol(text, &end, 10);
  while (end != nullptr && (*end == L' ' || *end == L'\t' || *end == L'\r' || *end == L'\n')) {
    ++end;
  }
  if (end == text || end == nullptr || *end != L'\0' || value < 1 || value > kMaxShots) {
    return false;
  }
  *out = static_cast<std::int32_t>(value);
  return true;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  if (_wcsicmp(tag.name, L"PowerShots") != 0) {
    return;
  }
  const wchar_t* source = tag.source == uhc::ActionSource::kTactics ? L"tactics" : L"protoy";
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  const ActionKey key{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)};
  std::int32_t shots = 0;
  if (key.name < 0 || !ParseShots(text, &shots)) {
    if (g_invalidLines < 50) {
      ++g_invalidLines;
      uhc::Log(key.name < 0 ? L"powerShots: %hs (%ls): <PowerShots> before the action's <name>; ignored"
                            : L"powerShots: %hs (%ls): <PowerShots>%ls</PowerShots> is not a whole number from 1 to 50; "
                              L"ignored",
               ProtoName(tag.proto), source, text);
    }
    return;
  }
  g_shots[key] = shots;
  SyncGate();
  if (g_log && g_tagLines < 200) {
    ++g_tagLines;
    uhc::Log(L"powerShots: %hs, action name %d (%ls): PowerShots %d", ProtoName(tag.proto), key.name, source, shots);
  }
}

}  // namespace

extern "C" {

// From the hook at 0x4B7766, when the power manager answered "not ready" for an Attack tag of a power-launched attack
// (EBP = the unit action): 1 to fire the shot anyway.
std::int32_t __stdcall UhcPowerShotsAllow(const char* unitAction) {
  const char* unit = unitAction == nullptr ? nullptr : Field<const char*>(unitAction, 0x10);
  const char* action = unitAction == nullptr ? nullptr : Field<const char*>(unitAction, 0x04);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (proto == nullptr || action == nullptr || Field<const char*>(unitAction, 0x6C) == nullptr) {
    return 0;
  }
  const auto found = g_shots.find(ActionKey{Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)});
  if (found == g_shots.end()) {
    return 0;
  }
  const std::int32_t fired = Field<std::int32_t>(unitAction, 0x68);
  const std::uint8_t state = Field<std::uint8_t>(unitAction, 0x61);
  const bool allow = state == kStateFiring && fired >= 1 && fired < found->second;
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"powerShots: %d ms, unit %d (%hs): the power is recharging; Attack tag after %d of %d shots in state "
             L"%02Xh at target %d: %ls",
             Now(), Field<std::int32_t>(unit, 0x10), ProtoName(proto), fired, found->second, state,
             Field<std::int32_t>(unitAction, 0x14), allow ? L"fires" : L"no shot (stock)");
  }
  return allow ? 1 : 0;
}

}  // extern "C"

namespace uhc {

Outcome ApplyPowerShots(const Config& config) {
  const Config::Args* args = config.First("powerShots");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"powerShots: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("powerShots", {&sites::kPowerShotsGate, &sites::kPowerShotsReady, &sites::kPowerShotsNoShot,
                                &sites::kPowerShotsFire}) ||
      !OnDatabaseLoad(&ResetForDataLoad) || !AddActionTagHandler(&ActionTagRead)) {
    return Outcome::kFailed;
  }
  // test al,al / jne 48F7F1h (8 B) at 0x4B7766, where an Attack tag of a power-launched attack goes on with the power
  // manager's answer.
  if (!WriteJmp(sites::kPowerShotsReady.va, reinterpret_cast<const void*>(&UhcPowerShotsHook), 8)) {
    return Outcome::kFailed;
  }
  Log(L"powerShots: an attack launched by a power whose action has <PowerShots>N fires a shot at each Attack tag of "
      L"its animation, up to N a use%ls (multiplayer unverified)",
      g_log ? L"; tags and shots logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
