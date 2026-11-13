// killSpawn [log]: a civ whose players turn the enemies they kill into animals. In civs.xml, per <civ>:
//
//   <killSpawn>LivestockCamel 80, ypGoat 20</killSpawn>    protos and weights (a weight left out is 1)
//   <killSpawnChance>100</killSpawnChance>                 optional: the % of kills that give an animal (default 100)
//   <killSpawnVictims>Military, Hero</killSpawnVictims>    optional: the victim must be of one of these types or protos
//
// A unit of such a player that lands the killing blow on an enemy unit (TakeDamage's kill path, killobservers.h, shared
// with veterancyBonus) may get an animal of the list, owned by its player, where the victim stood. Gaia, the killer's
// own and allied units, buildings, ships and herdables (no chains) never give one; with no room for the animal within
// 4 m (water, a cliff, a building, the animals of the kills before) it gives none. The chance and the pick are rolls of
// the game's synced RNG 0x407CE7 (stream 2, as the stock dodge), drawn at the blow, so every machine draws the same and
// nothing needs saving.
//
// The kill path runs inside TakeDamage, which the attack applier may call for each unit of an area attack: the unit is
// not created there. The kill queues it, and the world tick (worldtick.h), after the stock world update, places it the
// way the stock death replacement 0x506F61 does from the kill handler: the placement test (world vtable +14h,
// FUN_0050703D) at the victim's position and axes, then the creation 0x498ACC(world, proto, player, pos, forward, 0, -1,
// 0, -1). An animal waits at most kMaxUpdates updates for its victim's kill handler, so a save rarely holds one, and it
// is not saved.
//
// A tech effect type="Data" subtype="KillSpawnChance" on the killer's proto changes the chance for that player's copy,
// from the civ's: Assign sets it, Absolute adds to it, Percent multiplies it (0 turns it off, 100 makes every kill count).
#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <string>
#include <unordered_map>
#include <vector>

#include "../civtags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../killobservers.h"
#include "../log.h"
#include "../patch.h"
#include "../techsubtypes.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::int32_t kMaxTotalWeight = 1000;      // the RNG gives 0..32767: a larger total skews the pick
constexpr int kMaxLogLines = 2000;
constexpr std::uint32_t kPlaceSlot = 0x14;  // the world's placement test PLACE, FUN_0050703D
// PLACE's seventh argument is a set of flags. The stock death replacement passes 2; 4 also takes bit 1 out of the
// obstruction mask of its query (0x5074BD → 0x508A45), the bit the living units around fill: without it a melee
// refused one animal in four. Terrain (water, cliffs) and buildings are still tested.
constexpr std::int32_t kPlaceFlags = 2 | 4;
constexpr std::int32_t kMaxUpdates = 10;  // world updates an animal waits for its victim's kill handler
// Where PLACE is asked, in turn, on the ground plane (x, z) from the victim's position: the spot, then 8 points at 2 m,
// then 8 at 4 m. The order is fixed, so every machine picks the same one.
constexpr int kSpots = 17;
constexpr float kSpotOffsets[kSpots][2] = {
    {0.0f, 0.0f},   {2.0f, 0.0f},   {0.0f, 2.0f},   {-2.0f, 0.0f},  {0.0f, -2.0f},  {1.41f, 1.41f},
    {-1.41f, 1.41f}, {-1.41f, -1.41f}, {1.41f, -1.41f}, {4.0f, 0.0f},   {0.0f, 4.0f},   {-4.0f, 0.0f},
    {0.0f, -4.0f},  {2.83f, 2.83f},  {-2.83f, 2.83f}, {-2.83f, -2.83f}, {2.83f, -2.83f}};
constexpr float kSpotReach = 4.0f;

using CivByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
using ProtoByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using PlayerProtoFn = char*(__thiscall*)(const char* player, std::int32_t protoId);
using SyncRandomFn = std::int32_t(__thiscall*)(void* rng, std::int32_t stream, std::int32_t max);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
using PlaceFn = bool(__thiscall*)(char* world, std::int32_t proto, std::int32_t player, const float* position,
                                  const float* forward, const float* right, std::int32_t a, std::int32_t b,
                                  std::int32_t c, std::int32_t d, std::int32_t e, std::int32_t f);
using CreateFn = char*(__thiscall*)(char* world, std::int32_t proto, std::int32_t player, const float* position,
                                    const float* forward, std::int32_t a, std::int32_t b, std::int32_t c, std::int32_t d);

const auto kCivById = reinterpret_cast<CivByIdFn>(0x00405C2E);
const auto kProtoByName = reinterpret_cast<ProtoByNameFn>(0x005A2346);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kSyncRandom = reinterpret_cast<SyncRandomFn>(0x00407CE7);
void* const kSyncRng = reinterpret_cast<void*>(0x00C66588);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
const auto kCreate = reinterpret_cast<CreateFn>(0x00498ACC);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* GameField(std::uint32_t offset) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, offset);
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* CivName(const char* civ) {
  const char* name = civ == nullptr ? nullptr : Field<const char*>(civ, 0x04);
  return name == nullptr ? "?" : name;
}

// A player's civ ID (0x4539D3): [[player+20h]] when [player+24h] > 0, else -1.
std::int32_t CivIdOf(const char* player) {
  return Field<std::int32_t>(player, 0x24) > 0 ? *Field<const std::int32_t*>(player, 0x20) : -1;
}

std::string Narrow(const wchar_t* text) {
  std::string out;
  for (; text != nullptr && *text != L'\0'; ++text) {
    out += *text < 0x80 ? static_cast<char>(*text) : '?';
  }
  return out;
}

std::string Trim(const std::string& text) {
  const auto first = text.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) {
    return {};
  }
  return text.substr(first, text.find_last_not_of(" \t\r\n") - first + 1);
}

std::vector<std::string> SplitCommas(const std::string& text) {
  std::vector<std::string> parts;
  std::size_t start = 0;
  while (start <= text.size()) {
    const std::size_t comma = text.find(',', start);
    const std::string part = Trim(text.substr(start, comma == std::string::npos ? std::string::npos : comma - start));
    if (!part.empty()) {
      parts.push_back(part);
    }
    if (comma == std::string::npos) {
      break;
    }
    start = comma + 1;
  }
  return parts;
}

struct Animal {
  std::string name;
  std::int32_t weight;
  std::int32_t proto = -1;
};

struct CivSpawn {
  const char* civ = nullptr;  // the civ object the tags were read for; a new parse makes new ones
  std::vector<Animal> animals;  // as read
  float chance = 100.0f;
  std::vector<std::string> victimNames;
  bool hasVictims = false;
  // Resolved against the database whose proto array is `table`:
  const char* table = nullptr;
  std::vector<Animal> pick;  // the valid ones
  std::int32_t total = 0;
  std::vector<std::int32_t> victimTypes;
};

std::vector<CivSpawn> g_civs;  // by civ ID

// The exclusions, by name, once per database.
const char* g_typesTable = nullptr;
std::int32_t g_building = -1;
std::int32_t g_ship = -1;
std::int32_t g_herdable = -1;

// KillSpawnChance effects on a player's copy of a proto, in the order they came: the chance is the civ's, then each
// effect in turn through the stock value function, so a relative effect acts on that player's civ chance.
struct TechEffect {
  std::uint8_t relativity;
  float amount;
  bool unapply;
};
struct TechSlot {
  std::int32_t id = -1;  // the copy's proto ID, so a reused pointer is not taken for another proto
  std::vector<TechEffect> effects;
};
std::unordered_map<const char*, TechSlot> g_tech;

struct Pending {
  std::int32_t player;
  std::int32_t proto;
  std::int32_t victim;
  float position[3];
  float forward[3];
  float right[3];
  std::int32_t updates;  // world updates waited
  const char* world;      // the world and its game time [world+108h] at the kill: a new or loaded game drops it
  std::uint32_t time;
};
std::vector<Pending> g_pending;  // filled by the kills, emptied by the ticks after them

bool g_log = false;
int g_logLines = 0;
std::uint32_t g_spawned = 0;
std::uint32_t g_noRoom = 0;

void LogLine(const wchar_t* format, ...) {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return;
  }
  ++g_logLines;
  wchar_t text[512];
  va_list args;
  va_start(args, format);
  _vsnwprintf_s(text, _TRUNCATE, format, args);
  va_end(args);
  uhc::Log(L"%ls", text);
}

CivSpawn& CivSlot(std::int32_t civId, const char* civ) {
  if (civId >= static_cast<std::int32_t>(g_civs.size())) {
    g_civs.resize(civId + 1);
  }
  CivSpawn& slot = g_civs[civId];
  if (slot.civ != civ) {
    slot = CivSpawn{};
    slot.civ = civ;
  }
  return slot;
}

void ReadKillSpawn(const char* civ, std::int32_t civId, const wchar_t* text) {
  if (civId < 0) {
    return;
  }
  CivSpawn& slot = CivSlot(civId, civ);
  slot.animals.clear();
  slot.table = nullptr;
  for (const std::string& part : SplitCommas(Narrow(text))) {
    const std::size_t space = part.find_last_of(" \t");
    std::string name = part;
    std::int32_t weight = 1;
    if (space != std::string::npos) {
      const std::string number = Trim(part.substr(space + 1));
      char* end = nullptr;
      const long value = std::strtol(number.c_str(), &end, 10);
      if (!number.empty() && end != nullptr && *end == '\0') {
        name = Trim(part.substr(0, space));
        weight = static_cast<std::int32_t>(value);
      }
    }
    if (weight <= 0) {
      uhc::Log(L"killSpawn: civ %d (%hs): %hs has weight %d; ignored", civId, CivName(civ), name.c_str(), weight);
      continue;
    }
    slot.animals.push_back({name, weight});
  }
  uhc::Log(L"killSpawn: civ %d (%hs): %u animal(s) in <killSpawn>", civId, CivName(civ),
           static_cast<unsigned>(slot.animals.size()));
}

void ReadKillSpawnChance(const char* civ, std::int32_t civId, const wchar_t* text) {
  if (civId < 0) {
    return;
  }
  CivSpawn& slot = CivSlot(civId, civ);
  const std::string number = Trim(Narrow(text));
  char* end = nullptr;
  const double value = std::strtod(number.c_str(), &end);
  if (number.empty() || end == nullptr || *end != '\0' || !(value >= 0.0 && value <= 100.0)) {
    uhc::Log(L"killSpawn: civ %d (%hs): <killSpawnChance> \"%hs\" is not a number from 0 to 100; 100 is kept", civId,
             CivName(civ), number.c_str());
    slot.chance = 100.0f;
    return;
  }
  slot.chance = static_cast<float>(value);
}

void ReadKillSpawnVictims(const char* civ, std::int32_t civId, const wchar_t* text) {
  if (civId < 0) {
    return;
  }
  CivSpawn& slot = CivSlot(civId, civ);
  slot.victimNames = SplitCommas(Narrow(text));
  slot.hasVictims = true;
  slot.table = nullptr;
}

std::int32_t TypeByName(const char* database, const char* name) {
  const char* table = database + 0x190;
  std::int32_t id = -1;
  return kNameFind(table, name, kNameBucket(table, name), &id) ? id : -1;
}

void ResolveExclusions(const char* database) {
  const char* table = Field<const char*>(database, 0x54);
  if (g_typesTable == table) {
    return;
  }
  g_typesTable = table;
  g_building = TypeByName(database, "Building");
  g_ship = TypeByName(database, "Ship");
  g_herdable = TypeByName(database, "Herdable");
  uhc::Log(L"killSpawn: no animal from a Building (%d), a Ship (%d) or a Herdable (%d)", g_building, g_ship, g_herdable);
}

// The civ's list for this player, resolved against the current database; null when it has none.
const CivSpawn* SpawnFor(const char* database, const char* player) {
  const std::int32_t civId = CivIdOf(player);
  if (civId < 0 || civId >= static_cast<std::int32_t>(g_civs.size())) {
    return nullptr;
  }
  CivSpawn& slot = g_civs[civId];
  if (slot.animals.empty() || kCivById(database, civId) != slot.civ) {
    return nullptr;
  }
  const char* table = Field<const char*>(database, 0x54);
  if (slot.table != table) {
    slot.table = table;
    slot.pick.clear();
    slot.total = 0;
    for (const Animal& animal : slot.animals) {
      const std::int32_t proto = kProtoByName(database, animal.name.c_str());
      if (proto < 0) {
        uhc::Log(L"killSpawn: civ %d (%hs): <killSpawn> names no proto unit (%hs); ignored", civId, CivName(slot.civ),
                 animal.name.c_str());
        continue;
      }
      if (slot.total + animal.weight > kMaxTotalWeight) {
        uhc::Log(L"killSpawn: civ %d (%hs): the weights add up to more than %d; %hs and the rest are ignored", civId,
                 CivName(slot.civ), kMaxTotalWeight, animal.name.c_str());
        break;
      }
      Animal resolved = animal;
      resolved.proto = proto;
      slot.pick.push_back(resolved);
      slot.total += animal.weight;
    }
    slot.victimTypes.clear();
    for (const std::string& name : slot.victimNames) {
      const std::int32_t type = TypeByName(database, name.c_str());
      if (type < 0) {
        uhc::Log(L"killSpawn: civ %d (%hs): <killSpawnVictims> names no unit type or proto (%hs); ignored", civId,
                 CivName(slot.civ), name.c_str());
        continue;
      }
      slot.victimTypes.push_back(type);
    }
    if (slot.pick.empty()) {
      uhc::Log(L"killSpawn: civ %d (%hs): no valid animal in <killSpawn>; its players spawn nothing", civId,
               CivName(slot.civ));
    } else if (slot.hasVictims && slot.victimTypes.empty()) {
      uhc::Log(L"killSpawn: civ %d (%hs): no valid type in <killSpawnVictims>; its players spawn nothing", civId,
               CivName(slot.civ));
    } else {
      uhc::Log(L"killSpawn: civ %d (%hs): %u animal(s), total weight %d, chance %g %%, %u victim type(s)%ls", civId,
               CivName(slot.civ), static_cast<unsigned>(slot.pick.size()), slot.total,
               static_cast<double>(slot.chance), static_cast<unsigned>(slot.victimTypes.size()),
               slot.hasVictims ? L"" : L" (any)");
    }
  }
  if (slot.pick.empty() || (slot.hasVictims && slot.victimTypes.empty())) {
    return nullptr;
  }
  return &slot;
}

float ChanceFor(const CivSpawn& spawn, const char* copy) {
  float chance = spawn.chance;
  if (copy != nullptr && !g_tech.empty()) {
    const auto found = g_tech.find(copy);
    if (found != g_tech.end() && found->second.id == Field<std::int32_t>(copy, 8)) {
      for (const TechEffect& effect : found->second.effects) {
        kEffectValue(effect.relativity, &chance, spawn.chance, effect.amount, effect.unapply);
      }
    }
  }
  return chance < 0.0f ? 0.0f : (chance > 100.0f ? 100.0f : chance);
}

void ChangeChance(char* proto, const char*, float amount, std::uint8_t relativity, bool unapply) {
  TechSlot& slot = g_tech[proto];
  const std::int32_t id = Field<std::int32_t>(proto, 8);
  if (slot.id != id) {
    slot = TechSlot{};
    slot.id = id;
  }
  slot.effects.push_back({relativity, amount, unapply});
  LogLine(L"killSpawn: proto %d (%hs), tech subtype KillSpawnChance, relativity %u, amount %g%ls", id, ProtoName(proto),
          relativity, static_cast<double>(amount), unapply ? L" (removed)" : L"");
}

void ForgetOnDataLoad(char*) {
  g_tech.clear();
  g_pending.clear();
  g_typesTable = nullptr;
}

bool IsType(const char* proto, std::int32_t type) { return type >= 0 && kProtoIsType(proto, type); }

void OnKill(char* attacker, char* attackerPlayer, std::int32_t attackerProto, char* victim) {
  if (attackerPlayer == nullptr || g_civs.empty()) {
    return;
  }
  const char* database = GameField(0x140);
  if (database == nullptr) {
    return;
  }
  const CivSpawn* spawn = SpawnFor(database, attackerPlayer);
  if (spawn == nullptr) {
    return;
  }
  const char* victimPlayer = Field<const char*>(victim, 0x44);
  const char* victimProto = Field<const char*>(victim, 0x5C);
  if (victimPlayer == nullptr || victimProto == nullptr) {
    return;
  }
  const std::int32_t owner = Field<std::int32_t>(victimPlayer, 0);
  if (owner == 0 || owner == Field<std::int32_t>(attackerPlayer, 0) ||
      Field<std::int32_t>(victimPlayer, 0x10) == Field<std::int32_t>(attackerPlayer, 0x10)) {
    return;  // Gaia (hunted game too), its own units or an ally's
  }
  ResolveExclusions(database);
  if (IsType(victimProto, g_building) || IsType(victimProto, g_ship) || IsType(victimProto, g_herdable)) {
    return;
  }
  if (spawn->hasVictims) {
    bool match = false;
    for (const std::int32_t type : spawn->victimTypes) {
      if (kProtoIsType(victimProto, type)) {
        match = true;
        break;
      }
    }
    if (!match) {
      return;
    }
  }
  const char* copy = attacker != nullptr ? Field<const char*>(attacker, 0x5C)
                                         : (attackerProto >= 0 ? kPlayerProto(attackerPlayer, attackerProto) : nullptr);
  const std::int32_t percent = static_cast<std::int32_t>(std::lround(ChanceFor(*spawn, copy)));
  const std::int32_t killer = attacker != nullptr ? Field<std::int32_t>(attacker, 0x10) : -1;
  const std::int32_t victimId = Field<std::int32_t>(victim, 0x10);
  std::int32_t roll = -1;
  if (percent <= 0) {
    return;
  }
  if (percent < 100) {
    roll = kSyncRandom(kSyncRng, 2, 99);
    if (roll >= percent) {
      LogLine(L"killSpawn: unit %d (%hs) killed unit %d (%hs): chance %d %%, roll %d: nothing", killer,
              ProtoName(copy), victimId, ProtoName(victimProto), percent, roll);
      return;
    }
  }
  const Animal* animal = &spawn->pick.front();
  std::int32_t pickRoll = -1;
  if (spawn->pick.size() > 1) {
    pickRoll = kSyncRandom(kSyncRng, 2, spawn->total - 1);
    std::int32_t left = pickRoll;
    for (const Animal& candidate : spawn->pick) {
      animal = &candidate;
      if (left < candidate.weight) {
        break;
      }
      left -= candidate.weight;
    }
  }
  Pending pending{Field<std::int32_t>(attackerPlayer, 0), animal->proto, victimId, {}, {}, {}, 0, nullptr, 0};
  for (int i = 0; i < 3; ++i) {
    pending.position[i] = Field<float>(victim, 0x14 + 4 * i);
    pending.forward[i] = Field<float>(victim, 0x20 + 4 * i);
    pending.right[i] = Field<float>(victim, 0x38 + 4 * i);
  }
  pending.world = GameField(0x13C);
  pending.time = pending.world == nullptr ? 0 : Field<std::uint32_t>(pending.world, 0x108);
  g_pending.push_back(pending);
  LogLine(L"killSpawn: unit %d (%hs) of player %d killed unit %d (%hs): chance %d %%, roll %d, pick %d of %d: %hs",
          killer, ProtoName(copy), pending.player, victimId, ProtoName(victimProto), percent, roll, pickRoll,
          spawn->total, animal->name.c_str());
}

// The victim, while the world still has it and its kill handler has not run (state bit 11 clear): its obstruction
// is still there.
bool VictimStands(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return false;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  if (unit == nullptr || Field<std::int32_t>(unit, 0x10) != id) {
    return false;
  }
  const auto* bits = Field<const std::uint8_t*>(unit, 4);
  return bits == nullptr || Field<std::uint32_t>(unit, 8) <= 11 || (bits[1] & 0x08) == 0;
}

void Tick(char* world, std::int32_t) {
  if (g_pending.empty()) {
    return;
  }
  const auto place = (*reinterpret_cast<PlaceFn const* const*>(world))[kPlaceSlot / 4];
  std::size_t kept = 0;
  for (std::size_t i = 0; i < g_pending.size(); ++i) {
    Pending pending = g_pending[i];
    if (pending.world != world || Field<std::uint32_t>(world, 0x108) < pending.time) {
      continue;
    }
    ++pending.updates;
    if (VictimStands(world, pending.victim) && pending.updates < kMaxUpdates) {
      g_pending[kept++] = pending;  // its kill handler has not run: its obstruction is still there
      continue;
    }
    // The spot, then rings around it: where many die together, the animals of the first kills fill it.
    float at[3] = {pending.position[0], pending.position[1], pending.position[2]};
    bool found = false;
    for (int k = 0; k < kSpots && !found; ++k) {
      at[0] = pending.position[0] + kSpotOffsets[k][0];
      at[2] = pending.position[2] + kSpotOffsets[k][1];
      found = place(world, pending.proto, pending.player, at, pending.forward, pending.right, 0, kPlaceFlags, 0, 0, 0,
                    0);
    }
    if (!found) {
      ++g_noRoom;
      LogLine(L"killSpawn: no room for proto %d within %g m of (%.1f, %.1f), where unit %d died", pending.proto,
              static_cast<double>(kSpotReach), static_cast<double>(pending.position[0]),
              static_cast<double>(pending.position[2]), pending.victim);
      continue;
    }
    char* unit = kCreate(world, pending.proto, pending.player, at, pending.forward, 0, -1, 0, -1);
    if (unit == nullptr) {
      LogLine(L"killSpawn: proto %d for player %d not created", pending.proto, pending.player);
      continue;
    }
    ++g_spawned;
    LogLine(L"killSpawn: unit %d (%hs) for player %d at (%.1f, %.1f), %.1f m from where unit %d died, update %d (%u so far)",
            Field<std::int32_t>(unit, 0x10), ProtoName(Field<const char*>(unit, 0x5C)), pending.player,
            static_cast<double>(at[0]), static_cast<double>(at[2]),
            std::sqrt(static_cast<double>((at[0] - pending.position[0]) * (at[0] - pending.position[0]) +
                                          (at[2] - pending.position[2]) * (at[2] - pending.position[2]))),
            pending.victim, pending.updates, g_spawned);
  }
  g_pending.resize(kept);
}

}  // namespace

namespace uhc {

Outcome ApplyKillSpawn(const Config& config) {
  const Config::Args* args = config.First("killSpawn");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"killSpawn: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("killSpawn", {&sites::kCivById, &sites::kCivOfPlayer, &sites::kProtoByName, &sites::kIsA,
                               &sites::kPlayerProtoEntry, &sites::kSyncRandom, &sites::kEffectValueApply,
                               &sites::kUnitCreate, &sites::kKillSpawnPlace}) ||
      !AddCivTagHandler("killSpawn", &ReadKillSpawn) || !AddCivTagHandler("killSpawnChance", &ReadKillSpawnChance) ||
      !AddCivTagHandler("killSpawnVictims", &ReadKillSpawnVictims) ||
      !AddTechSubtype("KillSpawnChance", &ChangeChance) || !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !AddWorldTick(&Tick) || !AddKillObserver(&OnKill)) {
    return Outcome::kFailed;
  }
  Log(L"killSpawn: the civ tags killSpawn, killSpawnChance and killSpawnVictims and the Data subtype KillSpawnChance "
      L"are on%ls (multiplayer unverified)",
      g_log ? L", every kill and animal logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
