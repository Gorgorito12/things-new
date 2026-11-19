// directionalAttack: a projectile that flies on past its target and hits every unit it flies over, before
// and after the target (a "monster truck" attack, like a Scorpion bolt).
//
// An action (a .tactics <action> or a protoy.xml <ProtoAction>) becomes directional with one of two tags, the
// two variants:
// - <DirectionalAttack>D</DirectionalAttack>: the unit targets and fires at its MaxRange as in stock, and the
//   projectile lands D metres from the shooter (at the target if the target is farther);
// - <DirectionalFiringRange>F</DirectionalFiringRange>: the unit fires at F metres, and the projectile lands
//   at the MaxRange the data gives the action. The action's MaxRange becomes F when the data loads (the call
//   0x5F8A51 of the MaxRange setter in the action parser, or the tag itself when MaxRange came first), so
//   the game targets and fires at F; the landing is the data's MaxRange plus what techs added to the
//   player's copy since (a range tech moves both by the same amount).
// Optional: <DirectionalWidth>W</DirectionalWidth>, metres either side of the flight line that still count as
// flown over (default 0.25), and <DirectionalDamageFactor>X</DirectionalDamageFactor>, the share of the
// attack each unit flown over takes (default 1).
//
// The launch: one hook at 0x4998A7, where every launch path of FUN_004995C7 meets with the impact point and
// the mode final. For a directional action with a target and a projectile unit, the point moves along the
// line from the shooter through it, to the landing distance (its height from the terrain), and the mode
// becomes 3, the ground shot: the projectile flies there and the stock landing applies the attack at the
// point (area damage with <DamageArea>, as a TargetGround shot does). InstantBallistics shots are left alone
// (the instant arrival hits only [projectile+8]).
// The flight: after each world update, each tracked shot's projectile unit (by ID) has moved; the 2D segment
// it flew since the last update is tested against the units near it, and each unit whose obstruction it
// passes within W is hit once, through the stock TakeDamage with the shot's action (damage, bonuses, armor and
// the DamageFlags as for a direct hit). When the projectile unit is gone, the rest of the line to the landing
// point is flown, unless the shot ended far from it (it hit a cliff). Shots are kept by projectile unit ID
// and walked in ID order, so every machine hits the same units in the same order.
#include <windows.h>

#include <algorithm>
#include <cmath>
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <cwctype>
#include <map>
#include <set>
#include <string>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr float kDefaultWidth = 0.25f;
constexpr float kMaxDistance = 300.0f;  // a landing farther than this would leave most maps
constexpr float kMaxWidth = 10.0f;
constexpr float kMaxFactor = 100.0f;
constexpr std::size_t kMaxShots = 512;  // shots in flight; the oldest is dropped beyond
constexpr unsigned kMaxInvalidLines = 50;
constexpr unsigned kMaxLaunchLines = 60;
constexpr unsigned kMaxHitLines = 200;

constexpr std::int32_t kGroundShot = 3;          // [projectile+20h]: lands at the point, the attack applied there
constexpr std::int32_t kInstantBallistics = 22;  // action flag bit (0x5F8D2E)
constexpr std::int32_t kMuteDamage = 6;          // action flag bit, TakeDamage's 10th argument (0x49BFEF)
constexpr std::int32_t kFlagProjectile = 0x0A;   // proto flag "Projectile": the area damage skips these too

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
using HeightFn = bool(__thiscall*)(void* terrain, const float* point, float* out, std::int32_t, std::int32_t);
// TakeDamage FUN_0049B3D9 (docs/engine-symbols.md, "Damage and poison"), ret 34h.
using TakeDamageFn = float(__thiscall*)(char* unit, std::int32_t player, std::int32_t proto, char* action,
                                        std::int32_t attacker, float multiplier, float damage, float cap, char p8,
                                        char p9, char p10, char p11, std::int32_t p12, char p13);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kProtoFlag = reinterpret_cast<ProtoFlagFn>(0x0045EE02);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);
const auto kTakeDamage = reinterpret_cast<TakeDamageFn>(0x0049B3D9);
// The MaxRange setter FUN_005FA709 (thiscall(action, float), ret 4): data[0]+8 of the range array
// [action+18h], and data[0]+0Ch too while that one is unset.
using SetMaxRangeFn = void(__thiscall*)(char* action, float value);
const auto kSetMaxRange = reinterpret_cast<SetMaxRangeFn>(0x005FA709);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* World() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

const char* Database() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<UnitTestFn const* const*>(unit))[0xA4 / 4](unit); }

float ObstructionDistance(const char* unit, const float* point) {
  return (*reinterpret_cast<DistanceFn const* const*>(unit))[0xB8 / 4](unit, point);
}

bool ActionFlag(const char* action, std::int32_t bit) {
  if (Field<std::uint32_t>(action, 0x68) <= static_cast<std::uint32_t>(bit)) {
    return false;
  }
  return (Field<const std::uint8_t*>(action, 0x64)[bit >> 3] & (1u << (bit & 7))) != 0;
}

// The action's MaxRange: the first entry of the range array [action+18h] (the setter 0x5FA709 writes its
// +8). 0 without one.
float MaxRange(const char* action) {
  const char* ranges = Field<const char*>(action, 0x18);
  return ranges == nullptr ? 0.0f : Field<float>(ranges, 0x08);
}

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

char* PlayerById(const char* world, std::int32_t id) {
  if (id < 0 || id >= Field<std::int32_t>(world, 0x5C)) {
    return nullptr;
  }
  return Field<char**>(world, 0x58)[id];
}

// The terrain height under (x, z), as the ground lead FUN_004C4DF8 asks it (0x4C4E62: the world's
// [+88h] object, vtable slot 18h). False without terrain.
bool TerrainHeight(const char* world, float* point) {
  void* terrain = Field<void*>(world, 0x88);
  if (terrain == nullptr) {
    return false;
  }
  float height = point[1];
  const auto fn = (*reinterpret_cast<HeightFn const* const*>(terrain))[0x18 / 4];
  if (!fn(terrain, point, &height, 0, 0)) {
    return false;
  }
  point[1] = height;
  return true;
}

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Directional {
  float distance = -1.0f;     // <DirectionalAttack>: the landing distance (variant 1)
  float firingRange = -1.0f;  // <DirectionalFiringRange> (variant 2): the landing is the data's MaxRange
  float dataMaxRange = -1.0f; // variant 2: the MaxRange the data gave, before it became firingRange
  float width = kDefaultWidth;
  float factor = 1.0f;
  bool Enabled() const { return distance >= 0.0f || firingRange >= 0.0f; }
};

// Filled while the data loads, by the action's proto ID and name index (the same in every player's copy).
std::map<ActionKey, Directional> g_actions;
bool g_anyEnabled = false;
// Variant 2: the database actions with <DirectionalFiringRange>, for the MaxRange setter call.
std::map<char*, ActionKey> g_firingActions;
bool g_log = false;
unsigned g_invalidLines = 0;
unsigned g_launchLines = 0;
unsigned g_hitLines = 0;

// One shot in flight.
struct Shot {
  float last[2];         // where the projectile unit was at the last update (x, z); its position at the launch first
  float landing[3];      // the point it lands at
  float dir[2];          // the unit vector from the shooter to the landing point
  float origin[2];       // the shooter's position at the launch
  float landingDistance; // from origin along dir
  float lastStep = 0.0f;
  float width;
  float multiplier;
  std::int32_t shooter;
  std::int32_t player;
  std::int32_t protoId;
  char* action;
  char muted;
  char p10;
  std::int32_t p12;
  std::int32_t target;
  std::set<std::int32_t> hit;  // the units already hit by this shot
};

std::map<std::int32_t, Shot> g_shots;  // by projectile unit ID
std::int32_t g_resourceType = -1;
IdList g_found = {nullptr, 0, 0};
const char* g_tickWorld = nullptr;
std::uint32_t g_tickStep = 0;
std::uint32_t g_tickTime = 0;

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
  *out = value == 0.0f ? 0.0f : value;
  return true;
}

void OnActionTag(const uhc::ActionTag& tag) {
  enum { kDistance, kFiringRange, kWidth, kFactor } which;
  if (_wcsicmp(tag.name, L"DirectionalAttack") == 0) {
    which = kDistance;
  } else if (_wcsicmp(tag.name, L"DirectionalFiringRange") == 0) {
    which = kFiringRange;
  } else if (_wcsicmp(tag.name, L"DirectionalWidth") == 0) {
    which = kWidth;
  } else if (_wcsicmp(tag.name, L"DirectionalDamageFactor") == 0) {
    which = kFactor;
  } else {
    return;
  }
  const wchar_t* source = tag.source == uhc::ActionSource::kTactics ? L"tactics" : L"protoy";
  const ActionKey key{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)};
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  if (key.name < 0) {
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"directionalAttack: %hs (%ls): <%ls> before the action's <name>; ignored (put <name> first)",
               ProtoName(tag.proto), source, tag.name);
    }
    return;
  }
  const float limit = which == kWidth ? kMaxWidth : which == kFactor ? kMaxFactor : kMaxDistance;
  float value = 0.0f;
  if (!ParseValue(tag.text, limit, &value)) {
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"directionalAttack: %hs/%ls (%ls): <%ls>%ls</%ls> is not a number from 0 to %.0f; ignored",
               ProtoName(tag.proto), ActionName(key.name), source, tag.name, text, tag.name,
               static_cast<double>(limit));
    }
    return;
  }
  Directional& entry = g_actions[key];
  switch (which) {
    case kDistance:
      entry.distance = value;
      break;
    case kFiringRange: {
      entry.firingRange = value;
      char* action = const_cast<char*>(tag.action);
      g_firingActions[action] = key;
      // MaxRange read before this tag (it comes later in most data, through the setter call below).
      const char* ranges = Field<const char*>(action, 0x18);
      if (ranges != nullptr && Field<float>(ranges, 0x08) > 0.0f) {
        entry.dataMaxRange = Field<float>(ranges, 0x08);
        kSetMaxRange(action, value);
      }
      break;
    }
    case kWidth:
      entry.width = value;
      break;
    case kFactor:
      entry.factor = value;
      break;
  }
  g_anyEnabled = g_anyEnabled || entry.Enabled();
  if (g_log) {
    uhc::Log(L"directionalAttack: %hs/%ls (%ls): %ls %.2f", ProtoName(tag.proto), ActionName(key.name), source,
             tag.name, static_cast<double>(value));
  }
}

void ResetForDataLoad(char*) {
  g_actions.clear();
  g_firingActions.clear();
  g_anyEnabled = false;
  g_shots.clear();
  g_invalidLines = 0;
  g_launchLines = 0;
  g_hitLines = 0;
}

const Directional* Find(const char* proto, const char* action) {
  if (!g_anyEnabled || proto == nullptr || action == nullptr) {
    return nullptr;
  }
  const auto it = g_actions.find({Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)});
  return it == g_actions.end() || !it->second.Enabled() ? nullptr : &it->second;
}

// The engine's diplomacy filter FUN_0049AEE0, from the shooter's player: DamageFlags at [[action+24h]+4]
// (GAIA 1, Self 2, Ally 4, Enemy 8; FFh when the data sets none), relations at [player+1D4h + 4*id],
// 2 = enemy. It is applied here too so that a unit the attack cannot damage is not hit at all (a hit
// of 0 damage would still make it react).
bool DamageAllowed(const char* world, const Shot& shot, const char* unit) {
  const char* info = Field<const char*>(shot.action, 0x24);
  const char* owner = Field<const char*>(unit, 0x44);
  const char* attacker = PlayerById(world, shot.player);
  if (info == nullptr || owner == nullptr || attacker == nullptr) {
    return false;
  }
  const std::uint8_t flags = Field<std::uint8_t>(info, 0x04);
  const std::int32_t unitPlayer = Field<std::int32_t>(owner, 0x00);
  if (unitPlayer == 0) {
    return (flags & 1) != 0;
  }
  if (unitPlayer == shot.player) {
    return (flags & 2) != 0;
  }
  const bool enemy = unitPlayer > 0 && unitPlayer < 32 &&
                     Field<std::int32_t>(attacker, 0x1D4 + 4 * static_cast<std::uint32_t>(unitPlayer)) == 2;
  return (flags & (enemy ? 8 : 4)) != 0;
}

struct Candidate {
  float along;  // distance along the segment, for the order
  std::int32_t id;
  char* unit;
};

// Hits every unit the segment a -> b passes within the shot's width, once per shot.
void FlySegment(const char* world, std::int32_t projectileId, Shot& shot, const float* a, const float* b) {
  const float sx = b[0] - a[0];
  const float sz = b[1] - a[1];
  const float length2 = sx * sx + sz * sz;
  const float length = std::sqrt(length2);
  float mid[3] = {(a[0] + b[0]) * 0.5f, shot.landing[1], (a[1] + b[1]) * 0.5f};
  kUnitsNear(world, mid, length * 0.5f + shot.width + 0.5f, 1, &g_found);
  std::vector<std::int32_t> ids(g_found.data, g_found.data + g_found.count);
  std::vector<Candidate> hits;
  for (const std::int32_t id : ids) {
    if (id == shot.shooter || id == projectileId || shot.hit.count(id) != 0) {
      continue;
    }
    char* unit = kUnitById(world, id);
    const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    if (proto == nullptr || !IsAlive(unit) || Field<std::int32_t>(unit, 0x6C) != -1 ||
        kProtoFlag(proto, kFlagProjectile)) {
      continue;
    }
    const char* owner = Field<const char*>(unit, 0x44);
    if (owner != nullptr && Field<std::int32_t>(owner, 0) == 0 && g_resourceType >= 0 &&
        kProtoIsType(proto, g_resourceType)) {
      continue;  // a tree, a mine, a hunt
    }
    // The point of the segment nearest the unit's centre.
    const float cx = Field<float>(unit, 0x14);
    const float cz = Field<float>(unit, 0x1C);
    float t = length2 > 0.0f ? ((cx - a[0]) * sx + (cz - a[1]) * sz) / length2 : 0.0f;
    t = std::clamp(t, 0.0f, 1.0f);
    const float q[3] = {a[0] + sx * t, Field<float>(unit, 0x18), a[1] + sz * t};
    if (ObstructionDistance(unit, q) > shot.width || !DamageAllowed(world, shot, unit)) {
      continue;
    }
    hits.push_back({t * length, id, unit});
  }
  std::sort(hits.begin(), hits.end(), [](const Candidate& l, const Candidate& r) {
    return l.along != r.along ? l.along < r.along : l.id < r.id;
  });
  for (const Candidate& c : hits) {
    char* unit = kUnitById(world, c.id);
    if (unit == nullptr || !IsAlive(unit)) {
      continue;  // killed by an earlier hit of this segment
    }
    shot.hit.insert(c.id);
    const bool shooterThere = kUnitById(world, shot.shooter) != nullptr;
    const float dealt = kTakeDamage(unit, shot.player, shot.protoId, shot.action, shot.shooter, shot.multiplier, 0.0f,
                                    0.0f, 0, shot.muted, shot.p10, shooterThere ? 1 : 0, shot.p12, 1);
    if (g_log && g_hitLines < kMaxHitLines) {
      ++g_hitLines;
      const char* owner = Field<const char*>(unit, 0x44);
      uhc::Log(L"directionalAttack: shot %d of unit %d hits unit %d (%hs, player %d%ls) at (%.1f, %.1f): %.1f damage",
               projectileId, shot.shooter, c.id, ProtoName(Field<const char*>(unit, 0x5C)),
               owner == nullptr ? -1 : Field<std::int32_t>(owner, 0), c.id == shot.target ? L", its target" : L"",
               static_cast<double>(Field<float>(unit, 0x14)), static_cast<double>(Field<float>(unit, 0x1C)),
               static_cast<double>(dealt));
    }
  }
}

// After each world update: every shot in flight flies the segment since the last update.
void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_tickWorld || step - g_tickStep > 1 || now < g_tickTime) {
    g_shots.clear();  // another game: these IDs are not its units
  }
  g_tickWorld = world;
  g_tickStep = step;
  g_tickTime = now;
  for (auto it = g_shots.begin(); it != g_shots.end();) {
    Shot& shot = it->second;
    const char* projectile = kUnitById(world, it->first);
    float next[2];
    bool done = false;
    if (projectile == nullptr) {
      // Landed (or ended) during the update: fly on to the landing point if it ended near it.
      const float dx = shot.landing[0] - shot.last[0];
      const float dz = shot.landing[2] - shot.last[1];
      const float remaining = std::sqrt(dx * dx + dz * dz);
      done = true;
      if (remaining > std::max(3.0f * shot.lastStep, 3.0f)) {
        if (g_log && g_launchLines < kMaxLaunchLines) {
          ++g_launchLines;
          uhc::Log(L"directionalAttack: shot %d ended at (%.1f, %.1f), %.1f m short of its landing point (%.1f, %.1f), "
                   L"last step %.2f m; %u unit(s) hit",
                   it->first, static_cast<double>(shot.last[0]), static_cast<double>(shot.last[1]),
                   static_cast<double>(remaining), static_cast<double>(shot.landing[0]),
                   static_cast<double>(shot.landing[2]), static_cast<double>(shot.lastStep),
                   static_cast<unsigned>(shot.hit.size()));
        }
        it = g_shots.erase(it);
        continue;
      }
      next[0] = shot.landing[0];
      next[1] = shot.landing[2];
    } else {
      next[0] = Field<float>(projectile, 0x14);
      next[1] = Field<float>(projectile, 0x1C);
      const float along = (next[0] - shot.origin[0]) * shot.dir[0] + (next[1] - shot.origin[1]) * shot.dir[1];
      if (along >= shot.landingDistance) {
        next[0] = shot.landing[0];  // past the landing point (a bounce): the line ends there
        next[1] = shot.landing[2];
        done = true;
      }
    }
    const float sx = next[0] - shot.last[0];
    const float sz = next[1] - shot.last[1];
    const float stepLength = std::sqrt(sx * sx + sz * sz);
    if (stepLength > 0.0f || done) {
      FlySegment(world, it->first, shot, shot.last, next);
    }
    if (stepLength > 0.0f) {
      shot.lastStep = stepLength;
    }
    shot.last[0] = next[0];
    shot.last[1] = next[1];
    if (done) {
      if (g_log && g_launchLines < kMaxLaunchLines) {
        ++g_launchLines;
        uhc::Log(L"directionalAttack: shot %d reached its landing point (%.1f, %.1f); %u unit(s) hit", it->first,
                 static_cast<double>(shot.landing[0]), static_cast<double>(shot.landing[2]),
                 static_cast<unsigned>(shot.hit.size()));
      }
      it = g_shots.erase(it);
    } else {
      ++it;
    }
  }
}

}  // namespace

extern "C" {
void UhcDirLaunchHook();

// Replaces the action parser's call 0x5F8A51 of the MaxRange setter (ECX = the action, the value on the
// stack): an action with <DirectionalFiringRange> keeps the data's value as its landing distance and gets
// the firing range as its MaxRange.
void __fastcall UhcDirSetMaxRange(char* action, void*, float value) {
  const auto it = g_firingActions.find(action);
  if (it != g_firingActions.end()) {
    const auto entry = g_actions.find(it->second);
    if (entry != g_actions.end() && entry->second.firingRange >= 0.0f) {
      entry->second.dataMaxRange = value;
      if (g_log) {
        uhc::Log(L"directionalAttack: %ls: MaxRange %.2f is the landing distance; the unit fires at %.2f",
                 ActionName(it->second.name), static_cast<double>(value),
                 static_cast<double>(entry->second.firingRange));
      }
      value = entry->second.firingRange;
    }
  }
  kSetMaxRange(action, value);
}

// The launch hook (hooks/directional_hooks.asm), for every projectile launched.
void __stdcall UhcDirLaunch(char* projectile, const char* unitAction, const char* shooter, const char* target,
                            std::int32_t p12, float multiplier, float* point) {
  if (!g_anyEnabled || unitAction == nullptr || shooter == nullptr || target == nullptr) {
    return;
  }
  char* action = Field<char*>(unitAction, 0x04);
  const char* proto = Field<const char*>(shooter, 0x5C);
  const Directional* entry = Find(proto, action);
  if (entry == nullptr || ActionFlag(action, kInstantBallistics)) {
    return;
  }
  const char* projectileUnit = Field<const char*>(projectile, 0x00);
  const char* world = World();
  if (projectileUnit == nullptr || world == nullptr) {
    return;
  }
  const float ox = Field<float>(shooter, 0x14);
  const float oz = Field<float>(shooter, 0x1C);
  const float dx = point[0] - ox;
  const float dz = point[2] - oz;
  const float targetDistance = std::sqrt(dx * dx + dz * dz);
  if (targetDistance < 0.1f) {
    return;
  }
  // Variant 2: the data's MaxRange, moved by what techs added to this player's copy since the load.
  const float wanted = entry->distance >= 0.0f ? entry->distance
                       : entry->dataMaxRange >= 0.0f ? entry->dataMaxRange + MaxRange(action) - entry->firingRange
                                                     : MaxRange(action);
  const float landingDistance = std::max(wanted, targetDistance);
  Shot shot{};
  shot.dir[0] = dx / targetDistance;
  shot.dir[1] = dz / targetDistance;
  shot.origin[0] = ox;
  shot.origin[1] = oz;
  shot.landingDistance = landingDistance;
  shot.landing[0] = ox + shot.dir[0] * landingDistance;
  shot.landing[1] = point[1];
  shot.landing[2] = oz + shot.dir[1] * landingDistance;
  TerrainHeight(world, shot.landing);
  shot.last[0] = Field<float>(projectileUnit, 0x14);
  shot.last[1] = Field<float>(projectileUnit, 0x1C);
  shot.width = entry->width;
  shot.multiplier = multiplier * entry->factor;
  shot.shooter = Field<std::int32_t>(shooter, 0x10);
  const char* owner = Field<const char*>(shooter, 0x44);
  shot.player = owner == nullptr ? 0 : Field<std::int32_t>(owner, 0x00);
  shot.protoId = Field<std::int32_t>(proto, 0x04);
  shot.action = action;
  shot.muted = ActionFlag(action, kMuteDamage) ? 1 : 0;
  shot.p10 = (Field<std::uint32_t>(projectile, 0x30) >> 14 & 1) == 0 ? 1 : 0;
  shot.p12 = p12;
  shot.target = Field<std::int32_t>(target, 0x10);
  point[0] = shot.landing[0];
  point[1] = shot.landing[1];
  point[2] = shot.landing[2];
  *reinterpret_cast<std::int32_t*>(projectile + 0x20) = kGroundShot;
  const std::int32_t projectileId = Field<std::int32_t>(projectileUnit, 0x10);
  if (g_log && g_launchLines < kMaxLaunchLines) {
    ++g_launchLines;
    uhc::Log(L"directionalAttack: unit %d (%hs/%ls) fires shot %d at unit %d %.1f m away; it lands %.1f m away at "
             L"(%.1f, %.1f)",
             shot.shooter, ProtoName(proto), ActionName(Field<std::int32_t>(action, 0x04)), projectileId, shot.target,
             static_cast<double>(targetDistance), static_cast<double>(landingDistance),
             static_cast<double>(shot.landing[0]), static_cast<double>(shot.landing[2]));
  }
  g_shots[projectileId] = std::move(shot);
  while (g_shots.size() > kMaxShots) {
    g_shots.erase(g_shots.begin());
  }
}
}

namespace uhc {

Outcome ApplyDirectionalAttack(const Config& config) {
  const Config::Args* args = config.First("directionalAttack");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"directionalAttack: unknown option %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("directionalAttack", {&sites::kDirectionalLaunch, &sites::kDirectionalLaunchCall,
                                       &sites::kDirectionalTerrainHeight, &sites::kDirectionalTakeDamage,
                                       &sites::kDirectionalMaxRangeCall,
                                       &sites::kUnitsNearPoint, &sites::kUnitById, &sites::kProtoFlag}) ||
      !RequestAbstractUnitType("Resource", &g_resourceType) || !OnDatabaseLoad(&ResetForDataLoad) ||
      !AddActionTagHandler(&OnActionTag) || !AddWorldTick(&Tick) ||
      !WriteJmp(sites::kDirectionalLaunch.va, reinterpret_cast<const void*>(&UhcDirLaunchHook), 7) ||
      !WriteCall(sites::kDirectionalMaxRangeCall.va + 7, reinterpret_cast<const void*>(&UhcDirSetMaxRange))) {
    return Outcome::kFailed;
  }
  Log(L"directionalAttack: actions with <DirectionalAttack> or <DirectionalFiringRange> fly past their target and "
      L"hit what they fly over%ls (multiplayer unverified)",
      g_log ? L"; shots and hits logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
