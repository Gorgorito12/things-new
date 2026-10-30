// spreadAnyAccuracy: per-action <MaxSpread> and <SpreadFactor>, and shots that scatter whatever the
// accuracy.
//
// Stock TAD scatters a projectile only when its precalculated accuracy roll misses: FUN_004CEF8C
// moves the impact point by uniform(-r, r) on x and z with a hardcoded r = min(0.25 * d, 5.0), d being
// the 2D distance from the projectile to the impact point. The <MaxSpread> and <SpreadFactor> tags of
// the tactics files (Age of Mythology leftovers) are not read at all. With this key:
// - every action (a .tactics <action> or a protoy.xml <ProtoAction>) accepts <MaxSpread> and
//   <SpreadFactor>, floats from 0 (no tag: the stock 5.0 and 0.25);
// - every miss uses the shooting action's values: r = min(SpreadFactor * d, MaxSpread), with the
//   stock random draws;
// - a unit whose proto has the marker type (default AbstractSpreadAnyAccuracy) scatters every shot
//   that goes through the precalculated roll, PerfectAccuracy and accuracy 1 included: the projectile
//   lands at the offset point as a ground shot (the TargetGround mode, 3), which deals the attack's
//   area damage where it lands. A stock miss (mode 2) deals no damage at all, area included.
// InstantBallistics and TargetGround shots, shots with no target unit and every shot while the cfg
// var ballisticPrecalcHits is off never reach that code (docs/how-it-works.md). The hooks are in
// hooks/spread_hooks.asm; the tags come through the shared action tag hook (actiontags.h).
#include <windows.h>

#include <cmath>
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <cwctype>
#include <map>
#include <string>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
constexpr float kStockFactor = 0.25f;              // [0xBA0AEC], read at 0x4CF00B
constexpr float kStockMax = 5.0f;                  // [0xBA0AF8] and the clamp at 0x4E2CE3
// Upper limits of the tags: a bigger offset could send a shot far off the map.
constexpr float kMaxFactor = 10.0f;
constexpr float kMaxSpread = 100.0f;
// Log limits.
constexpr unsigned kMaxValueLines = 200;     // "log": parsed values other than the stock ones
constexpr unsigned kMaxInvalidLines = 50;    // invalid values (always logged)
constexpr unsigned kShotLinesPerAction = 5;  // "log": offset shots per (proto, action)
constexpr unsigned kMaxShotLines = 100;

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Database() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

// ProtoAction names: [database+1FD8h] holds one UTF-16 string per name index, [+1FDCh] the count.
const wchar_t* ActionName(std::int32_t index) {
  const char* database = Database();
  if (database == nullptr || index < 0 || index >= Field<std::int32_t>(database, 0x1FDC)) {
    return L"?";
  }
  const wchar_t* name = Field<const wchar_t* const*>(database, 0x1FD8)[index];
  return name != nullptr ? name : L"?";
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name != nullptr ? name : "?";
}

// Every player's copy of a proto and of its actions keeps the proto ID [proto+4] and the action's
// name index [action+4], so this key finds the values from the copy a unit shoots with.
struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Spread {
  float factor = kStockFactor;
  float max = kStockMax;
};

// Filled while the data loads, read on the game thread at each miss; cleared on every data load.
std::map<ActionKey, Spread> g_spreads;
std::map<ActionKey, unsigned> g_shotLines;
std::string g_markerName = "AbstractSpreadAnyAccuracy";
std::int32_t g_markerType = -1;
bool g_log = false;
unsigned g_valueLines = 0;
unsigned g_valuesNotLogged = 0;
unsigned g_invalidLines = 0;
unsigned g_shotLinesTotal = 0;
bool g_loadReported = false;

// The projectile's hit result [projectile+20h] (written at 0x499899): 1 a sure hit on the target, 2 a
// miss (no damage at all), 3 a ground shot (the TargetGround mode: the attack is applied where the
// projectile lands, FUN_0049BE95 with no target).
constexpr std::int32_t kMiss = 2;
constexpr std::int32_t kGroundShot = 3;

// The shot being offset, between the hit hook or UhcSpreadSelect and UhcSpreadDone.
bool g_forced = false;  // a hit (the roll, or PerfectAccuracy without one); the shooter is marked
bool g_marked = false;  // the shooter is marked
bool g_tagged = false;
const char* g_shooter = nullptr;
ActionKey g_shotKey{-1, -1};

// The shooting unit's proto (the player's copy, [unit+5Ch]) has the marker type.
bool IsMarked(const char* shooter) {
  const char* proto = shooter == nullptr ? nullptr : Field<const char*>(shooter, 0x5C);
  return g_markerType >= 0 && proto != nullptr && kProtoIsType(proto, g_markerType);
}

// A float from 0 to limit, spaces around it allowed.
bool ParseValue(const wchar_t* text, float limit, float* out) {
  if (text == nullptr) {
    return false;
  }
  while (std::iswspace(*text)) {
    ++text;
  }
  wchar_t* end = nullptr;
  const float value = std::wcstof(text, &end);
  if (end == text) {
    return false;
  }
  while (std::iswspace(*end)) {
    ++end;
  }
  if (*end != L'\0' || !std::isfinite(value) || value < 0.0f || value > limit) {
    return false;
  }
  *out = value == 0.0f ? 0.0f : value;  // no -0
  return true;
}

void OnActionTag(const uhc::ActionTag& tag) {
  const bool isMax = _wcsicmp(tag.name, L"MaxSpread") == 0;
  if (!isMax && _wcsicmp(tag.name, L"SpreadFactor") != 0) {
    return;
  }
  const wchar_t* tagName = isMax ? L"MaxSpread" : L"SpreadFactor";
  const wchar_t* source = tag.source == uhc::ActionSource::kTactics ? L"tactics" : L"protoy";
  const ActionKey key{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)};
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  if (key.name < 0) {
    // Only possible in a tactics <action> whose <name> comes later; every known file has it
    // first, and the action has no name to key the value by yet.
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"spreadAnyAccuracy: %hs (%ls): <%ls> before the action's <name>; ignored (put <name> first)",
               ProtoName(tag.proto), source, tagName);
    }
    return;
  }
  float value = 0.0f;
  if (!ParseValue(tag.text, isMax ? kMaxSpread : kMaxFactor, &value)) {
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"spreadAnyAccuracy: %hs/%ls (%ls): <%ls>%ls</%ls> is not a number from 0 to %.0f; ignored",
               ProtoName(tag.proto), ActionName(key.name), source, tagName, text, tagName,
               static_cast<double>(isMax ? kMaxSpread : kMaxFactor));
    }
    return;
  }
  Spread& spread = g_spreads[key];
  (isMax ? spread.max : spread.factor) = value;
  // Most stock tactics files carry the stock values: "log" lists only the others.
  if (g_log && value != (isMax ? kStockMax : kStockFactor)) {
    if (g_valueLines < kMaxValueLines) {
      ++g_valueLines;
      uhc::Log(L"spreadAnyAccuracy: %hs/%ls (%ls): %ls %.2f", ProtoName(tag.proto), ActionName(key.name), source,
               tagName, static_cast<double>(value));
    } else {
      ++g_valuesNotLogged;
    }
  }
}

// From the database load hook (unittypes.h), before the protos' contents (their tactics files and
// <ProtoAction> children) are read: every load reads the tags again.
void ResetForDataLoad(char*) {
  g_spreads.clear();
  g_shotLines.clear();
  g_valueLines = 0;
  g_valuesNotLogged = 0;
  g_invalidLines = 0;
  g_shotLinesTotal = 0;
  g_loadReported = false;
}

// Once per data load, at the first miss: how many actions carry the tags.
void ReportLoad() {
  if (g_loadReported) {
    return;
  }
  g_loadReported = true;
  unsigned changed = 0;
  for (const auto& [key, spread] : g_spreads) {
    changed += spread.factor != kStockFactor || spread.max != kStockMax ? 1 : 0;
  }
  wchar_t more[64] = L"";
  if (g_valuesNotLogged > 0) {
    swprintf_s(more, L"; %u more values not logged", g_valuesNotLogged);
  }
  uhc::Log(L"spreadAnyAccuracy: %u action(s) of this data carry <MaxSpread> or <SpreadFactor>, %u of them with "
           L"values other than the stock 5.0 and 0.25%ls",
           static_cast<unsigned>(g_spreads.size()), changed, more);
}

}  // namespace

extern "C" {
// Read by the radius hook inside FUN_004CEF8C; the stock values except during a miss hook's call.
float g_uhcSpreadFactor = kStockFactor;
float g_uhcSpreadMax = kStockMax;
float g_uhcSpreadRadius = -1.0f;

void UhcSpreadHitHook();
void UhcSpreadMissHook();
void UhcSpreadRadiusHook();

// The hit hook, for a shot the roll did not make a miss: true if the shooting unit is marked, so
// that the shot takes the miss stub too.
bool __stdcall UhcSpreadForceMiss(const char* shooter, const char*) {
  g_forced = IsMarked(shooter);
  return g_forced;
}

// The miss hook, before the stock offset: the shooting action's values, from the unit action
// [unitAction+4] (the player's copy of the action) and the shooting unit's proto.
void __stdcall UhcSpreadSelect(const char* unitAction, const char* shooter) {
  g_uhcSpreadFactor = kStockFactor;
  g_uhcSpreadMax = kStockMax;
  g_uhcSpreadRadius = -1.0f;
  g_tagged = false;
  g_shooter = shooter;
  g_marked = g_forced || IsMarked(shooter);
  ReportLoad();
  const char* action = unitAction == nullptr ? nullptr : Field<const char*>(unitAction, 0x04);
  const char* proto = shooter == nullptr ? nullptr : Field<const char*>(shooter, 0x5C);
  g_shotKey = {proto == nullptr ? -1 : Field<std::int32_t>(proto, 0x04),
               action == nullptr ? -1 : Field<std::int32_t>(action, 0x04)};
  if (proto == nullptr || action == nullptr || g_spreads.empty()) {
    return;
  }
  const auto it = g_spreads.find(g_shotKey);
  if (it != g_spreads.end()) {
    g_uhcSpreadFactor = it->second.factor;
    g_uhcSpreadMax = it->second.max;
    g_tagged = true;
  }
}

// The miss hook, after the stock offset: the log, then the stock values back. Returns the hit result
// the launch stores in [projectile+20h]: 2, a miss, which deals no damage; 3 for a marked unit, a
// ground shot (the TargetGround mode), which deals the attack where it lands.
std::int32_t __stdcall UhcSpreadDone() {
  if (g_log && g_shotLinesTotal < kMaxShotLines) {
    unsigned& lines = g_shotLines[g_shotKey];
    if (lines < kShotLinesPerAction) {
      ++lines;
      ++g_shotLinesTotal;
      const char* proto = g_shooter == nullptr ? nullptr : Field<const char*>(g_shooter, 0x5C);
      wchar_t radius[48] = L"no offset (FUN_004CEF8C found no target)";
      if (g_uhcSpreadRadius >= 0.0f) {
        swprintf_s(radius, L"r = %.2f m", static_cast<double>(g_uhcSpreadRadius));
      }
      uhc::Log(L"spreadAnyAccuracy: shot by unit %d (%hs/%ls): %ls, %ls (SpreadFactor %.2f, MaxSpread %.2f%ls)",
               g_shooter == nullptr ? -1 : Field<std::int32_t>(g_shooter, 0x10), ProtoName(proto),
               ActionName(g_shotKey.name),
               !g_marked  ? L"a miss"
               : g_forced ? L"marked unit, a hit made a ground shot at the offset point"
                          : L"marked unit, a miss made a ground shot at the offset point",
               radius, static_cast<double>(g_uhcSpreadFactor), static_cast<double>(g_uhcSpreadMax),
               g_tagged ? L"" : L", stock values");
    }
  }
  g_uhcSpreadFactor = kStockFactor;
  g_uhcSpreadMax = kStockMax;
  const bool marked = g_marked;
  g_forced = false;
  g_marked = false;
  return marked ? kGroundShot : kMiss;
}
}

namespace uhc {

Outcome ApplySpreadAnyAccuracy(const Config& config) {
  const Config::Args* args = config.First("spreadAnyAccuracy");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool typeGiven = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (!typeGiven) {
      g_markerName = arg;
      typeGiven = true;
    } else {
      Log(L"spreadAnyAccuracy: unexpected argument %hs (expected: [UnitType] [log]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }
  // The hit hook jumps straight to the miss hook, and the miss hook relies on the radius hook: all
  // three are written, or none.
  if (!VerifyAll("spreadAnyAccuracy", {&sites::kSpreadHitRoll, &sites::kSpreadMissStub, &sites::kSpreadRadius,
                                       &sites::kSpreadDraws, &sites::kIsA}) ||
      !RequestAbstractUnitType(g_markerName.c_str(), &g_markerType) || !OnDatabaseLoad(&ResetForDataLoad) ||
      !AddActionTagHandler(&OnActionTag)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kSpreadRadius.va, reinterpret_cast<const void*>(&UhcSpreadRadiusHook), 27) ||
      !WriteJmp(sites::kSpreadMissStub.va, reinterpret_cast<const void*>(&UhcSpreadMissHook), 7) ||
      !WriteJmp(sites::kSpreadHitRoll.va, reinterpret_cast<const void*>(&UhcSpreadHitHook), 9)) {
    return Outcome::kFailed;
  }
  Log(L"spreadAnyAccuracy: <MaxSpread> and <SpreadFactor> are read per action (stock 5.0 and 0.25) and every "
      L"miss uses them; units of unittype %hs scatter every precalculated shot%ls (multiplayer unverified)",
      g_markerName.c_str(), g_log ? L"; values and shots logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
