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
// - a marked unit's TargetGround shot, which never rolls, lands at such an offset point too, and a marked
//   unit goes through the roll even with the cfg var ballisticPrecalcHits off.
// - a marked unit's InstantBallistics shot (a sure hit that skips the roll) is aimed at such an offset
//   point too. At its arrival, in the attack applier: a point inside the target's obstruction hits the
//   target as in stock; otherwise the attack's area damage lands at the point (with <DamageArea>), or
//   the shot hits the unit whose obstruction holds the point, or nothing.
// - a marked unit's ground shot without <DamageArea>, which stock lands with nothing to hit, hits the
//   unit whose obstruction holds the point where it lands, if any.
// Shots with no target unit never reach that code (docs/how-it-works.md). The hooks are in
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
#include <set>
#include <string>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"
#include "../worldtick.h"

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

constexpr unsigned kStrayLinesPerAction = 5;  // "log": stray shots per (proto, action)
constexpr unsigned kMaxStrayLines = 100;

// The list FUN_004A1C55 fills (the engine's dynamic array: data, count, capacity).
struct IdList {
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using ProtoFlagFn = bool(__thiscall*)(const char* proto, std::int32_t flag);
using UnitByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using UnitsNearFn = std::int32_t(__thiscall*)(const char* world, const float* point, float radius, char precise,
                                              IdList* out);
using UnitTestFn = bool(__thiscall*)(const char* unit);
using DistanceFn = float(__thiscall*)(const char* unit, const float* point);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kProtoFlag = reinterpret_cast<ProtoFlagFn>(0x0045EE02);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);

constexpr std::int32_t kFlagProjectile = 0x0A;  // proto flag "Projectile": the area damage skips these
constexpr std::int32_t kInstantBallistics = 22;  // action flag bit (0x5F8D2E)
// The box around the point for the spatial query; a unit is kept only when its obstruction holds
// the point (distance 0, vtable slot B8h).
constexpr float kQueryRadius = 0.01f;
constexpr std::size_t kMaxPendingInstant = 512;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Database() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<UnitTestFn const* const*>(unit))[0xA4 / 4](unit); }

// The distance from a point to the unit's obstruction, 0 inside it (vtable slot B8h).
float ObstructionDistance(const char* unit, const float* point) {
  return (*reinterpret_cast<DistanceFn const* const*>(unit))[0xB8 / 4](unit, point);
}

// A bit of an action's flag bitset ([action+64h], its size in bits at [action+68h]), as the launch
// reads InstantBallistics at 0x4997BE.
bool ActionFlag(const char* action, std::int32_t bit) {
  if (Field<std::uint32_t>(action, 0x68) <= static_cast<std::uint32_t>(bit)) {
    return false;
  }
  return (Field<const std::uint8_t*>(action, 0x64)[bit >> 3] & (1u << (bit & 7))) != 0;
}

// The applier's area test (0x49BF92): the byte [[action+24h]+6] above 0.
bool HasDamageArea(const char* action) {
  const char* damage = Field<const char*>(action, 0x24);
  return damage != nullptr && Field<std::uint8_t>(damage, 6) > 0;
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
bool g_ground = false;  // a TargetGround shot of a marked unit
bool g_tagged = false;
const char* g_shooter = nullptr;
ActionKey g_shotKey{-1, -1};
bool g_instant = false;          // the shot being offset is an InstantBallistics shot
const float* g_aim = nullptr;    // its offset point, for the log

// InstantBallistics shots of marked units that were offset, by their projectile unit's ID, until
// their arrival reaches the applier. Unit IDs are the same on every machine, and the set is only
// read by key and trimmed from its lowest ID, so it stays in step. A shot whose arrival never comes
// (its target died first) is trimmed once more than kMaxPendingInstant are pending.
std::set<std::int32_t> g_instantShots;
const char* g_tickWorld = nullptr;  // the world tick's last world, step and time
std::uint32_t g_tickStep = 0;
std::uint32_t g_tickTime = 0;
std::int32_t g_resourceType = -1;  // Gaia units of this type (trees, mines, hunts) do not stop a stray shot
IdList g_found = {nullptr, 0, 0};  // FUN_004A1C55's output, reused
float g_point[3] = {};             // the point an instant shot's area damage lands at
std::map<ActionKey, unsigned> g_strayLines;
unsigned g_strayLinesTotal = 0;
// "log": what marked units' shots hit, counted per game and reported at 25, 50, 100, ... shots.
struct StrayCounts {
  unsigned target = 0;  // instant, inside the target's obstruction
  unsigned area = 0;    // instant, area damage at the point
  unsigned unit = 0;    // instant, another unit at the point
  unsigned none = 0;    // instant, nothing at the point
  unsigned groundUnit = 0;
  unsigned groundNone = 0;
  unsigned next = 25;
};
StrayCounts g_counts;

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
  g_instantShots.clear();
  g_strayLines.clear();
  g_strayLinesTotal = 0;
  g_counts = {};
}

// After each world update: in another game (a new or loaded one can reuse the world's address, so
// the test is the step count [world+F8h] going up by more than 1, or the game time going back, as
// damageOverTime's), the pending instant shots are forgotten (their IDs are not that game's) and the
// "log" counts start again.
void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_tickWorld || step - g_tickStep > 1 || now < g_tickTime) {
    g_instantShots.clear();
    g_counts = {};
  }
  g_tickWorld = world;
  g_tickStep = step;
  g_tickTime = now;
}

// The unit whose obstruction holds the point and that a stray shot hits: any player's, alive, not
// the shooter or the projectile, not a projectile (the area damage skips those too), and not a Gaia
// resource (a tree, a mine, a hunt). Of several, the nearest centre in x and z, then the lowest ID,
// so every machine picks the same one. nullptr if none.
char* UnitAt(const char* world, const float* point, std::int32_t shooterId, std::int32_t projectileUnitId) {
  kUnitsNear(world, point, kQueryRadius, 1, &g_found);
  char* best = nullptr;
  float bestDistance = 0.0f;
  for (std::int32_t i = 0; i < g_found.count; ++i) {
    const std::int32_t id = g_found.data[i];
    if (id == shooterId || id == projectileUnitId) {
      continue;
    }
    char* unit = kUnitById(world, id);
    const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    if (proto == nullptr || !IsAlive(unit) || kProtoFlag(proto, kFlagProjectile)) {
      continue;
    }
    const char* player = Field<const char*>(unit, 0x44);
    if (player != nullptr && Field<std::int32_t>(player, 0) == 0 && g_resourceType >= 0 &&
        kProtoIsType(proto, g_resourceType)) {
      continue;
    }
    if (ObstructionDistance(unit, point) > 0.0f) {
      continue;
    }
    const float dx = Field<float>(unit, 0x14) - point[0];
    const float dz = Field<float>(unit, 0x1C) - point[2];
    const float distance = dx * dx + dz * dz;
    if (best == nullptr || distance < bestDistance ||
        (distance == bestDistance && id < Field<std::int32_t>(best, 0x10))) {
      best = unit;
      bestDistance = distance;
    }
  }
  return best;
}

enum class Stray { kTarget, kArea, kUnit };

// "log": what a marked unit's stray shot hit. targetDistance < 0: a ground shot (no target).
void LogStray(const char* shooter, const char* action, Stray kind, const char* hit, const float* point,
              float targetDistance) {
  if (!g_log) {
    return;
  }
  const bool ground = targetDistance < 0.0f;
  unsigned& count = kind == Stray::kTarget ? g_counts.target
                    : kind == Stray::kArea ? g_counts.area
                    : ground               ? (hit != nullptr ? g_counts.groundUnit : g_counts.groundNone)
                    : hit != nullptr       ? g_counts.unit
                                           : g_counts.none;
  ++count;
  const unsigned total = g_counts.target + g_counts.area + g_counts.unit + g_counts.none + g_counts.groundUnit +
                         g_counts.groundNone;
  if (total >= g_counts.next) {
    g_counts.next *= 2;
    uhc::Log(L"spreadAnyAccuracy: %u marked shots so far: InstantBallistics %u on the target, %u area damage at "
             L"the point, %u on another unit, %u on nothing; ground shots without DamageArea %u on a unit, %u on "
             L"nothing",
             total, g_counts.target, g_counts.area, g_counts.unit, g_counts.none, g_counts.groundUnit,
             g_counts.groundNone);
  }
  if (g_strayLinesTotal >= kMaxStrayLines) {
    return;
  }
  const char* proto = Field<const char*>(shooter, 0x5C);
  const ActionKey key{proto == nullptr ? -1 : Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)};
  unsigned& lines = g_strayLines[key];
  if (lines >= kStrayLinesPerAction) {
    return;
  }
  ++lines;
  ++g_strayLinesTotal;
  wchar_t what[144] = L"it hits nothing";
  if (kind == Stray::kTarget) {
    swprintf_s(what, L"inside its target's obstruction, the target takes the hit");
  } else if (kind == Stray::kArea) {
    swprintf_s(what, L"the area damage lands there");
  } else if (hit != nullptr) {
    const char* owner = Field<const char*>(hit, 0x44);
    swprintf_s(what, L"it hits unit %d (%hs, player %d, at %.1f, %.1f)", Field<std::int32_t>(hit, 0x10),
               ProtoName(Field<const char*>(hit, 0x5C)), owner == nullptr ? -1 : Field<std::int32_t>(owner, 0),
               static_cast<double>(Field<float>(hit, 0x14)), static_cast<double>(Field<float>(hit, 0x1C)));
  }
  wchar_t off[56] = L" (a ground shot)";
  if (targetDistance >= 0.0f) {
    swprintf_s(off, L" (instant, %.2f m from its target's obstruction)", static_cast<double>(targetDistance));
  }
  uhc::Log(L"spreadAnyAccuracy: shot by unit %d (%hs/%ls) lands at (%.1f, %.1f)%ls: %ls",
           Field<std::int32_t>(shooter, 0x10), ProtoName(proto), ActionName(key.name),
           static_cast<double>(point[0]), static_cast<double>(point[2]), off, what);
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
void UhcSpreadGroundHook();
void UhcSpreadPrecalcHook();
void UhcSpreadInstantHook();
void UhcSpreadApplyHook();

// The precalc hook and the ground hook.
bool __stdcall UhcSpreadIsMarked(const char* shooter) { return IsMarked(shooter); }

bool __stdcall UhcSpreadMarkedGround(const char* shooter) {
  g_ground = IsMarked(shooter);
  return g_ground;
}

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
      wchar_t radius[80] = L"no offset (FUN_004CEF8C found no target)";
      if (g_uhcSpreadRadius >= 0.0f && g_instant && g_aim != nullptr) {
        swprintf_s(radius, L"at (%.1f, %.1f), r = %.2f m", static_cast<double>(g_aim[0]), static_cast<double>(g_aim[2]),
                   static_cast<double>(g_uhcSpreadRadius));
      } else if (g_uhcSpreadRadius >= 0.0f) {
        swprintf_s(radius, L"r = %.2f m", static_cast<double>(g_uhcSpreadRadius));
      }
      uhc::Log(L"spreadAnyAccuracy: shot by unit %d (%hs/%ls): %ls, %ls (SpreadFactor %.2f, MaxSpread %.2f%ls)",
               g_shooter == nullptr ? -1 : Field<std::int32_t>(g_shooter, 0x10), ProtoName(proto),
               ActionName(g_shotKey.name),
               !g_marked   ? L"a miss"
               : g_instant ? L"marked unit, an InstantBallistics shot aimed at the offset point"
               : g_ground  ? L"marked unit, its shot lands at the offset point"
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
  g_ground = false;
  g_instant = false;
  g_aim = nullptr;
  return marked ? kGroundShot : kMiss;
}

// The instant hook, before the offset: true for a marked shooter with a target unit and a
// projectile unit (the instant launch flies only with one); the shooting action's values are
// then selected as for a miss.
bool __stdcall UhcSpreadInstantSelect(const char* projectile, const char* unitAction, const char* shooter,
                                      const char* target) {
  if (target == nullptr || Field<const char*>(projectile, 0x00) == nullptr || !IsMarked(shooter)) {
    return false;
  }
  UhcSpreadSelect(unitAction, shooter);
  g_instant = true;
  return true;
}

// The instant hook, after the offset: an offset shot (r above the stock 1e-6, so the draws ran) is
// remembered for its arrival; then the log and the stock values, as for a miss. The hit result
// stays 1.
void __stdcall UhcSpreadInstantDone(const char* projectile, const float* aim) {
  g_aim = aim;
  if (g_uhcSpreadRadius > 1.0e-6f) {
    g_instantShots.insert(Field<std::int32_t>(Field<const char*>(projectile, 0x00), 0x10));
    while (g_instantShots.size() > kMaxPendingInstant) {
      g_instantShots.erase(g_instantShots.begin());
    }
  }
  UhcSpreadDone();
}

// The applier hook, at the head of FUN_0049BE95(projectile, targetId, point), on every hit or
// landing of every projectile. It changes nothing unless the shooter (still alive) is marked:
// - an InstantBallistics shot (mode 1) that the instant hook offset: the point it flew to
//   [projectile+70h] inside the target's obstruction hits the target as in stock; otherwise, with
//   <DamageArea>, the shot becomes a ground shot (mode 3) at that point, which deals the area
//   damage there; without, it hits the unit at that point, or nothing (a mode-1 shot with no live
//   target deals nothing);
// - a ground shot (mode 3, no target unit) without <DamageArea>: it hits the unit at the point where
//   it lands. With <DamageArea> it stays as it is.
void __stdcall UhcSpreadApply(char* projectile, std::int32_t* targetId, const float** point) {
  if (g_markerType < 0) {
    return;
  }
  const char* action = Field<const char*>(projectile, 0x10);
  if (action == nullptr) {
    return;
  }
  const std::int32_t mode = Field<std::int32_t>(projectile, 0x20);
  const bool instant = ActionFlag(action, kInstantBallistics);
  if (instant ? mode != 1 || g_instantShots.empty() : mode != kGroundShot) {
    return;
  }
  const char* world = World();
  if (world == nullptr) {
    return;
  }
  const char* projectileUnit = Field<const char*>(projectile, 0x00);
  const std::int32_t projectileUnitId = projectileUnit == nullptr ? -1 : Field<std::int32_t>(projectileUnit, 0x10);
  if (instant) {
    const auto pending = g_instantShots.find(projectileUnitId);
    if (projectileUnit == nullptr || pending == g_instantShots.end()) {
      return;
    }
    g_instantShots.erase(pending);
  } else if (*targetId >= 0 && kUnitById(world, *targetId) != nullptr) {
    return;  // a ground shot that hits a unit: as in stock
  } else if (HasDamageArea(action)) {
    return;
  }
  const std::int32_t shooterId = Field<std::int32_t>(projectile, 0x04);
  const char* shooter = kUnitById(world, shooterId);
  if (shooter == nullptr || !IsAlive(shooter) || !IsMarked(shooter)) {
    return;
  }
  if (!instant) {
    const float* landing = *point != nullptr ? *point : reinterpret_cast<const float*>(projectile + 0x70);
    char* hit = UnitAt(world, landing, shooterId, projectileUnitId);
    if (hit != nullptr) {
      *targetId = Field<std::int32_t>(hit, 0x10);
    }
    LogStray(shooter, action, Stray::kUnit, hit, landing, -1.0f);
    return;
  }
  const char* target = *targetId >= 0 ? kUnitById(world, *targetId) : nullptr;
  if (target == nullptr || !IsAlive(target)) {
    return;  // stock: no damage
  }
  const float* aim = reinterpret_cast<const float*>(projectile + 0x70);
  const float distance = ObstructionDistance(target, aim);
  if (distance <= 0.0f) {
    LogStray(shooter, action, Stray::kTarget, target, aim, distance);
    return;
  }
  if (HasDamageArea(action)) {
    g_point[0] = aim[0];
    g_point[1] = aim[1];
    g_point[2] = aim[2];
    *reinterpret_cast<std::int32_t*>(projectile + 0x20) = kGroundShot;
    *targetId = -1;
    *point = g_point;
    LogStray(shooter, action, Stray::kArea, nullptr, aim, distance);
    return;
  }
  char* hit = UnitAt(world, aim, shooterId, projectileUnitId);
  *targetId = hit == nullptr ? -1 : Field<std::int32_t>(hit, 0x10);
  LogStray(shooter, action, Stray::kUnit, hit, aim, distance);
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
                                       &sites::kSpreadDraws, &sites::kIsA, &sites::kSpreadPrecalcGate,
                                       &sites::kSpreadGroundStore, &sites::kSpreadInstantMode,
                                       &sites::kSpreadInstantLaunch, &sites::kSpreadApplierHead,
                                       &sites::kSpreadInstantArrival, &sites::kUnitsNearPoint, &sites::kUnitById,
                                       &sites::kProtoFlag}) ||
      !RequestAbstractUnitType(g_markerName.c_str(), &g_markerType) ||
      !RequestAbstractUnitType("Resource", &g_resourceType) || !OnDatabaseLoad(&ResetForDataLoad) ||
      !AddActionTagHandler(&OnActionTag) || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kSpreadRadius.va, reinterpret_cast<const void*>(&UhcSpreadRadiusHook), 27) ||
      !WriteJmp(sites::kSpreadMissStub.va, reinterpret_cast<const void*>(&UhcSpreadMissHook), 7) ||
      !WriteJmp(sites::kSpreadHitRoll.va, reinterpret_cast<const void*>(&UhcSpreadHitHook), 9) ||
      !WriteJmp(sites::kSpreadGroundStore.va, reinterpret_cast<const void*>(&UhcSpreadGroundHook), 7) ||
      !WriteJmp(sites::kSpreadPrecalcGate.va, reinterpret_cast<const void*>(&UhcSpreadPrecalcHook), 8) ||
      !WriteJmp(sites::kSpreadApplierHead.va, reinterpret_cast<const void*>(&UhcSpreadApplyHook), 6) ||
      !WriteJmp(sites::kSpreadInstantMode.va, reinterpret_cast<const void*>(&UhcSpreadInstantHook), 7)) {
    return Outcome::kFailed;
  }
  Log(L"spreadAnyAccuracy: <MaxSpread> and <SpreadFactor> are read per action (stock 5.0 and 0.25) and every "
      L"miss uses them; units of unittype %hs scatter every precalculated and InstantBallistics shot, and a "
      L"stray shot hits what it lands on%ls (multiplayer unverified)",
      g_markerName.c_str(), g_log ? L"; values and shots logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
