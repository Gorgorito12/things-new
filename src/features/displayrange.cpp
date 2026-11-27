// displayedRange: a selected unit shows its range on the ground while Alt is held, one ring per ranged attack.
//
// Proto data:
//   <DisplayRange>1</DisplayRange>              the unit shows its rings when it is selected and Alt is held;
//   <AlwaysDisplayRange>1</AlwaysDisplayRange>  (or <Flag>AlwaysDisplayRange</Flag>) it shows them whenever it is
//                                               selected, without Alt;
//   <DisplayedRange>N</DisplayedRange>          a fixed radius instead of the attacks', repeatable.
// With no <DisplayedRange>, the rings are those of each active action of the unit's current tactic with the ranged
// flag 0Ah (<RangedLogic>), read from the player's copy, so range techs show at once. The radius is where an infantry
// unit's centre comes into that attack's range, as the game measures it (kRadii's comment): its MaxRange (0x4946D6 with
// key -1, the number the stat panel shows) plus the target's radius x sqrt(2), plus the attacker's own radius x
// sqrt(2), or for a building the half side of its rectangle. Each radius is drawn as the ring of tools/rings nearest to
// it (1 m apart up to 50); two attacks on one ring share it.
//
// Alt is the game's own query, the one the HP bar chunk makes (0x452EA0..0x452EB3: [[[0C66244h]+74h]+2Ch], vtable
// +34h with 2). The ring is a model of the table the tactics parser uses (0x58F68F, 0x58E506), hung on the unit as
// the stock aura update does. A world tick every 100 ms compares the local selection (0x453B28: IDs [group+10h],
// count [group+14h]) and the Alt state with the rings the units hold. Display only: a model is a visual of the unit,
// the selection and the keyboard are this machine's, and nothing here reaches the simulation.
//
// Placement: while a building is being placed, its ghost shows the rings of its proto's ranged attacks (every tactic's,
// from the local player's copy) or its <DisplayedRange>, with no tag needed (option noPlacement turns it off). The
// shared ghost update (ghostobservers.h, 0x96E4E7) hangs them on the ghost's model [[[0xC67300]+200h]+34h], of a unit
// visual's class, through the stock model functions, which read only a unit's visual (unitmodels.h); a new proto or a
// new model starts again, and the model takes its rings with it when the placement ends.
//
// Player colour: the rings are aoe3-blender-tools' range meshes (make_rings.py), whose texture marks player colour as a
// unit's does; the engine tints a model hung on a unit with the unit's owner's colour, and on the ghost with the local
// player's. The line needs nothing from here.
//
// Each ring has a fill, a transparent disc under its line graded from clear at the centre to the owner's colour at the
// edge (effects\uhc_rings\rangefill_<N>_p<player>.xml). The game's alphablend shader has no player colour, so there is
// one disc per player ID (0 to 8) and this key picks the owner's; the placement ghost gets no fill (a ghost that cannot
// be placed is tinted, and the tint draws the disc opaque). An attack that
// reaches no unit on land gets a dashed ring with no fill instead (range_<N>_ships.xml): only ships (each type of its
// <Rate> list is Ship or a type whose every proto is a Ship, such as AbstractWarShip), or only structures (each type's
// protos are Buildings or Ships, such as a torch's LogicalTypeShipsAndBuildings). A structures-only attack is left out
// when the unit has an attack on land units (the Grenzer's 6 m torch beside its musket). Two attacks on one ring size
// share it, filled if either reaches land units. The caps count models: a filled ring is two.
//
// The options menu: with `menuOptions displayedRange` the player turns the rings on and off (OptionDisplayedRange), at
// once, also during a match. The key is applied either way and asks the choice (FollowMenuSwitch); off, the tick and the
// ghost update take down the rings they hung and draw none, and the arguments of the cfg line still hold.
//
// <Flag>: the proto flag parser 0x5F640A (stdcall(proto, name)) compares the name with each flag it knows and
// returns with nothing for any other name. Its last compare, the call 0x5F726F of the string compare 0x4028B4, is
// redirected: the compare runs, and a name it does not match is offered to this key.
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../ghostobservers.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../menuoptions.h"
#include "../patch.h"
#include "../prototags.h"
#include "../unitmodels.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
void UhcProtoFlagCompareHook();
std::uint32_t g_uhcStringCompare = 0x004028B4;
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kUiGlobal = 0x00C67300;     // the placement ghost: +1FCh the proto ID, +200h its visual
constexpr std::uint32_t kInputGlobal = 0x00C66244;  // [[+74h]+2Ch]: the object the Alt query asks
constexpr std::uint32_t kTickMs = 100;
constexpr std::uint32_t kRangedFlag = 0x0A;  // <RangedLogic> (0x5FAC6D), the bit the stat panel tests for a range
// Measured (perfprobe, 2026-11-21, 50 selected units on screen, render time a frame): 100 rings 6.6 ms against 6.0
// with the key off, 200 rings 8.0 against 7.6, inside the noise of the runs (0.6 ms). The caps keep a big selection
// readable: at most 4 rings a unit and 60 models in all (a filled ring is two: its line and its fill), the units with
// the longest ranges first.
constexpr std::size_t kMaxRingsPerUnit = 4;
constexpr std::size_t kMaxRings = 60;
// The sizes aoe3-blender-tools' make_rings.py writes (RANGES): every metre from 4 to 50, then 55 to 100.
constexpr std::int32_t kRadii[] = {4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
                                   23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41,
                                   42, 43, 44, 45, 46, 47, 48, 49, 50, 55, 60, 65, 70, 80, 90, 100};
// How the game measures an attack's reach (the action's range test 0x48B6AA..0x48B779 compares the unit distance,
// unit vtable +0BCh -> +0B4h 0x487B81, with the action's MaxRange [action+24h]):
//   - attacker and target that can move (0x45EE55): centre distance - each one's radius x sqrt(2) (0x4889AF; the
//     radius is the larger of its proto's obstruction radii, 0x48272C);
//   - a building (cannot move) on a unit: the unit's centre to the building's obstruction rectangle, minus the unit's
//     radius x sqrt(2) (0x4945FE, 0x485E26);
//   - a unit on a building: its centre to the building's rectangle minus its own radius x sqrt(2) (0x4882FE).
// So a ring is drawn where an infantry unit's centre (radius 0.49 m, the common one) comes into range: MaxRange +
// 0.49 x sqrt(2), plus the attacker's own radius x sqrt(2) for a unit that moves, or the half side of a building's
// rectangle (the smaller one). Measured in game, 2026-11-24 (a mod's Fort, MaxRange 26, rectangle 12 x 12 m; Settlers,
// radius 0.49): Settlers whose centre was 26.08, 26.31 and 26.68 m from the rectangle were shot, 26.83, 26.9 and
// 27.2 m were not (the limit 26 + 0.69). Past a corner the zone reaches further than the ring (2.5 m for the Fort).
constexpr float kSqrt2 = 1.41421356f;
constexpr float kTargetRadius = 0.49f;  // an infantry unit's obstruction radius (Musketeer, Settler, Grenzer)

using SelectionFn = const char*(__cdecl*)();
using UnitByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);
using RangeFn = float(__thiscall*)(const char* action, std::int32_t key);
using KeyQueryFn = bool(__thiscall*)(void* input, std::int32_t key);
using PlayerByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);
using PlayerProtoFn = const char*(__thiscall*)(const char* player, std::int32_t id);
using IsAFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);

const auto kSelection = reinterpret_cast<SelectionFn>(0x00453B28);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kRange = reinterpret_cast<RangeFn>(0x004946D6);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kIsA = reinterpret_cast<IsAFn>(0x0044D7FA);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
constexpr std::int32_t kFillPlayers = 9;  // rangefill_<N>_p0 .. p8 (make_rings.py, RANGE_FILL_PLAYERS)

struct Range {
  bool show = false;    // <DisplayRange>
  bool always = false;  // <AlwaysDisplayRange>
  std::vector<float> fixed;  // <DisplayedRange>, each
};

std::unordered_map<std::int32_t, Range> g_protos;  // by proto ID; the load fills it
std::map<std::wstring, std::int32_t> g_models;     // by file
// What an attack reaches: land units (a filled ring), only ships, or only structures (buildings, or buildings and ships).
enum class Reach { kLand, kShips, kStructures };
std::unordered_map<std::int32_t, Reach> g_typeReach;  // by unittype ID
std::int32_t g_shipType = -2;                         // the unittype Ship; -2 until looked up
std::int32_t g_buildingType = -1;                     // the unittype Building
std::int32_t g_unitType = -1;                         // the unittype Unit
std::map<std::int32_t, std::vector<std::int32_t>> g_hung;  // by unit ID: the models on it
std::int32_t g_bone = -2;
const char* g_world = nullptr;
std::uint32_t g_nextTick = 0;
bool g_lastAlt = false;
bool g_log = false;
bool g_placement = true;      // the ghost's rings (option noPlacement: off)
// The player's switch in the options menu (menuOptions displayedRange, FollowMenuSwitch): off, no rings are drawn and
// the next tick and ghost update take down those hung. Always on when the key does not follow the menu.
bool g_enabled = true;

struct Ghost {
  char* visual = nullptr;
  std::int32_t proto = -2;
  std::vector<std::int32_t> models;  // what the observer hung on this visual
};
Ghost g_ghost;
int g_logLines = 0;
constexpr int kMaxLogLines = 200;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

bool Bit(const char* object, std::uint32_t offset, std::uint32_t bit) {
  if (Field<std::uint32_t>(object, offset + 4) <= bit) {
    return false;
  }
  const auto* bytes = Field<const std::uint8_t*>(object, offset);
  return bytes != nullptr && (bytes[bit >> 3] & (1u << (bit & 7))) != 0;
}

const wchar_t* NodeText(const char* node) { return *reinterpret_cast<const wchar_t* const*>(node + 0x14); }

bool On(const wchar_t* text) { return text == nullptr || text[0] == L'\0' || _wtoi(text) != 0; }

bool __cdecl ReadShow(void*, const char* node, char* proto) {
  g_protos[Field<std::int32_t>(proto, 0x04)].show = On(NodeText(node));
  return true;
}

bool __cdecl ReadAlways(void*, const char* node, char* proto) {
  g_protos[Field<std::int32_t>(proto, 0x04)].always = On(NodeText(node));
  return true;
}

bool __cdecl ReadMetres(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  const float metres = text == nullptr ? 0.0f : std::wcstof(text, nullptr);
  if (metres > 0.0f) {
    g_protos[Field<std::int32_t>(proto, 0x04)].fixed.push_back(metres);
  } else {
    uhc::Log(L"displayedRange: proto %d: <DisplayedRange> needs a number above 0, ignored", Field<std::int32_t>(proto, 0x04));
  }
  return true;
}

void NewDatabase(char*) {
  g_protos.clear();
  g_models.clear();
  g_typeReach.clear();
  g_shipType = -2;
  g_buildingType = -1;
  g_unitType = -1;
  g_hung.clear();
  g_bone = -2;
  g_logLines = 0;
  g_ghost = Ghost{};
}

bool AltHeld() {
  const char* root = *reinterpret_cast<const char* const*>(kInputGlobal);
  const char* inner = root == nullptr ? nullptr : Field<const char*>(root, 0x74);
  char* input = inner == nullptr ? nullptr : Field<char*>(inner, 0x2C);
  if (input == nullptr || Field<const void*>(input, 0) == nullptr) {
    return false;
  }
  const auto query = Field<KeyQueryFn>(Field<const char*>(input, 0), 0x34);
  return query(input, 2);
}

std::int32_t RingRadius(float metres) {
  std::int32_t radius = kRadii[0];
  for (const std::int32_t candidate : kRadii) {
    if (std::abs(static_cast<float>(candidate) - metres) < std::abs(static_cast<float>(radius) - metres)) {
      radius = candidate;
    }
  }
  return radius;
}

// The model of a file of effects\uhc_rings: range_<N>.xml (a line), range_<N>_ships.xml (dashed), rangefill_<N>_p<k>.xml.
std::int32_t ModelOf(const wchar_t* path) {
  const auto found = g_models.find(path);
  if (found != g_models.end()) {
    return found->second;
  }
  const std::int32_t model = uhc::ModelOfPath(path);
  if (g_log) {
    uhc::Log(L"displayedRange: %ls is model %d", path, model);
  }
  if (model != -1) {  // -1: the table does not exist yet
    g_models[path] = model;
  }
  return model;
}

struct Ring {
  std::int32_t radius;
  bool dashed;  // no attack on this ring reaches a unit on land: only ships, or only buildings
};

// The models of one ring for an owner: its line (dashed when it reaches no land unit) and, unless dashed, the owner's
// fill.
std::vector<std::int32_t> RingModels(const Ring& ring, std::int32_t player) {
  std::vector<std::int32_t> models;
  wchar_t path[80];
  swprintf_s(path, ring.dashed ? L"effects\\uhc_rings\\range_%d_ships.xml" : L"effects\\uhc_rings\\range_%d.xml",
             ring.radius);
  const std::int32_t line = ModelOf(path);
  if (line == -1) {
    return models;
  }
  models.push_back(line);
  if (!ring.dashed && player >= 0 && player < kFillPlayers) {
    swprintf_s(path, L"effects\\uhc_rings\\rangefill_%d_p%d.xml", ring.radius, player);
    const std::int32_t fill = ModelOf(path);
    if (fill != -1) {
      models.push_back(fill);
    }
  }
  return models;
}

const char* Database() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

std::int32_t TypeId(const char* database, const char* name) {
  const char* table = database + 0x190;
  std::int32_t id = -1;
  return kNameFind(table, name, kNameBucket(table, name), &id) ? id : -1;
}

// What the protos of unittype `type` are: kLand when one of them is a Unit that is neither a Ship nor a Building (a unit
// on land), kShips when there are some and every one is a Ship (Ship itself, AbstractWarShip, a ship's proto), else
// kStructures (buildings, or buildings and ships: LogicalTypeShipsAndBuildings). "A Unit" matters: a mod's helper
// objects (an aura's carrier, a packed wagon) can carry LogicalTypeShipsAndBuildings without being Buildings. The protos
// of the database [db+54h] (count +58h), tested by the is-a test 0x44D7FA; the name table [db+190h] gives the IDs of
// Ship, Building and Unit. Each type is worked out once per database.
Reach TypeReach(std::int32_t type) {
  const char* database = Database();
  if (database == nullptr || type < 0) {
    return Reach::kLand;
  }
  if (g_shipType == -2) {
    g_shipType = TypeId(database, "Ship");
    g_buildingType = TypeId(database, "Building");
    g_unitType = TypeId(database, "Unit");
    if (g_log) {
      uhc::Log(L"displayedRange: unittype Ship is %d, Building %d, Unit %d", g_shipType, g_buildingType, g_unitType);
    }
  }
  const auto found = g_typeReach.find(type);
  if (found != g_typeReach.end()) {
    return found->second;
  }
  const auto* protos = Field<const char* const*>(database, 0x54);
  const std::int32_t count = Field<std::int32_t>(database, 0x58);
  bool any = false;
  bool land = false;
  bool ships = true;
  for (std::int32_t i = 0; protos != nullptr && i < count && !land; ++i) {
    const char* proto = protos[i];
    if (proto == nullptr || !kIsA(proto, type)) {
      continue;
    }
    any = true;
    const bool ship = g_shipType >= 0 && kIsA(proto, g_shipType);
    const bool building = g_buildingType >= 0 && kIsA(proto, g_buildingType);
    land = !ship && !building && g_unitType >= 0 && kIsA(proto, g_unitType);
    ships = ships && ship;
  }
  const Reach reach = !any || land ? Reach::kLand : ships ? Reach::kShips : Reach::kStructures;
  g_typeReach[type] = reach;
  return reach;
}

// What an attack reaches, from its <Rate> list ([action+0Ch], count +10h, 0Ch-byte entries, +0 the unittype): land
// units when one of its types has them (or the list is empty), ships when every type is a ship type, else structures.
Reach AttackReach(const char* action) {
  const char* rates = Field<const char*>(action, 0x0C);
  const std::int32_t count = Field<std::int32_t>(action, 0x10);
  if (rates == nullptr || count <= 0) {
    return Reach::kLand;
  }
  bool ships = true;
  for (std::int32_t i = 0; i < count; ++i) {
    const Reach reach = TypeReach(Field<std::int32_t>(rates, 12 * i));
    if (reach == Reach::kLand) {
      return Reach::kLand;
    }
    ships = ships && reach == Reach::kShips;
  }
  return ships ? Reach::kShips : Reach::kStructures;
}

// The proto's own share of an attack's reach, as the unit distance counts it: a unit that moves, its radius x sqrt(2)
// (the larger obstruction radius, [proto+88h] / [proto+8Ch], 0x48272C); a building, the half side of its rectangle
// (the smaller of the two, so that the ring stays inside the zone on every side). Can move is 0x45EE55: not when the
// first flag byte has bit 4 ([[proto+50h]], with [proto+54h] > 4), else when [proto+80h] is above 1e-6.
float OwnReach(const char* proto) {
  const float x = Field<float>(proto, 0x88);
  const float z = Field<float>(proto, 0x8C);
  const auto* flags = Field<const std::uint8_t*>(proto, 0x50);
  const bool fixed = Field<std::uint32_t>(proto, 0x54) > 4 && flags != nullptr && (flags[0] & 0x10) != 0;
  const bool moves = !fixed && Field<float>(proto, 0x80) > 1e-6f;
  return moves ? std::max(x, z) * kSqrt2 : std::min(x, z);
}

struct Attack {
  float metres;  // where an infantry unit's centre comes into range, or a building's wall for a structures-only attack
  Reach reach;
};

// The ranged attacks of one tactic, as the attack list 0x487EEE reads them: 12-byte entries at [tactic+44h] (count
// +48h), +4 the index of the action in the set [tactic+0] (actions [set+1Ch], count +20h); an action counts when it is
// active (bit 0 of [action+64h]), has the ranged flag and a range entry. `own` is the attacker's share (OwnReach).
void TacticAttacks(const char* tactic, float own, std::vector<Attack>& attacks) {
  const char* owner = Field<const char*>(tactic, 0x00);
  const char* entries = Field<const char*>(tactic, 0x44);
  const std::int32_t count = Field<std::int32_t>(tactic, 0x48);
  const auto* actions = owner == nullptr ? nullptr : Field<const char* const*>(owner, 0x1C);
  const std::int32_t actionCount = owner == nullptr ? 0 : Field<std::int32_t>(owner, 0x20);
  for (std::int32_t i = 0; i < count && entries != nullptr && actions != nullptr; ++i) {
    const std::int32_t which = Field<std::int32_t>(entries, 12 * i + 4);
    if (which < 0 || which >= actionCount) {
      continue;
    }
    const char* action = actions[which];
    if (action == nullptr || !Bit(action, 0x64, 0) || !Bit(action, 0x64, kRangedFlag) ||
        Field<std::int32_t>(action, 0x1C) <= 0) {
      continue;
    }
    const float range = kRange(action, -1);
    if (range > 0.5f) {
      const Reach reach = AttackReach(action);
      // On a building the distance runs to its wall, with no radius of the target's.
      attacks.push_back({range + own + (reach == Reach::kStructures ? 0.0f : kTargetRadius * kSqrt2), reach});
    }
  }
}

// Largest first, each size once (filled if any of its attacks reaches land units), at most kMaxRingsPerUnit. An attack
// that reaches only structures (a torch on buildings and ships) is left out when another attack reaches land units:
// its ring would read as a range on your army. Alone (a mortar) it gets its dashed ring.
std::vector<Ring> Rings(const std::vector<Attack>& attacks) {
  const bool land =
      std::any_of(attacks.begin(), attacks.end(), [](const Attack& a) { return a.reach == Reach::kLand; });
  std::vector<Ring> radii;
  for (const Attack& attack : attacks) {
    if (!(land && attack.reach == Reach::kStructures)) {
      radii.push_back({RingRadius(attack.metres), attack.reach != Reach::kLand});
    }
  }
  std::sort(radii.begin(), radii.end(), [](const Ring& a, const Ring& b) {
    return a.radius != b.radius ? a.radius > b.radius : a.dashed < b.dashed;
  });
  radii.erase(std::unique(radii.begin(), radii.end(), [](const Ring& a, const Ring& b) { return a.radius == b.radius; }),
              radii.end());
  if (radii.size() > kMaxRingsPerUnit) {
    radii.resize(kMaxRingsPerUnit);
  }
  return radii;
}

// <DisplayedRange>: radii from the unit's centre, as written.
std::vector<Ring> FixedRings(const Range& range) {
  std::vector<Attack> attacks;
  for (const float metres : range.fixed) {
    attacks.push_back({metres, Reach::kLand});
  }
  return Rings(attacks);
}

// The rings the unit wants, largest first, at most kMaxRingsPerUnit: the fixed <DisplayedRange> values, or the ranged
// attacks of its current tactic ([mgr+0A8h], an index into the player's proto's tactics [[proto+44h]+10h], count
// +14h); a tactic with none (an artillery piece limbered to move) takes those of all its tactics, the attacks it
// unlimbers to.
std::vector<Ring> WantedRadii(const char* unit, const Range& range) {
  if (!range.fixed.empty()) {
    return FixedRings(range);
  }
  std::vector<Attack> attacks;
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* manager = Field<const char*>(unit, 0x58);
  const char* set = proto == nullptr ? nullptr : Field<const char*>(proto, 0x44);
  const auto* tactics = set == nullptr ? nullptr : Field<const char* const*>(set, 0x10);
  const std::int32_t count = set == nullptr ? 0 : Field<std::int32_t>(set, 0x14);
  if (manager != nullptr && tactics != nullptr) {
    const float own = OwnReach(proto);
    const std::int32_t index = Field<std::int32_t>(manager, 0xA8);
    if (index >= 0 && index < count && tactics[index] != nullptr) {
      TacticAttacks(tactics[index], own, attacks);
    }
    for (std::int32_t i = 0; attacks.empty() && i < count; ++i) {
      if (tactics[i] != nullptr) {
        TacticAttacks(tactics[i], own, attacks);
      }
    }
  }
  return Rings(attacks);
}

// The rings of a proto with no unit (the placement ghost): its <DisplayedRange> values, or the ranged attacks of every
// tactic of the player's copy (a building has no current tactic before it stands).
std::vector<Ring> ProtoRadii(const char* proto, const Range* range) {
  if (range != nullptr && !range->fixed.empty()) {
    return FixedRings(*range);
  }
  std::vector<Attack> attacks;
  const char* set = Field<const char*>(proto, 0x44);
  const auto* tactics = set == nullptr ? nullptr : Field<const char* const*>(set, 0x10);
  const std::int32_t count = set == nullptr ? 0 : Field<std::int32_t>(set, 0x14);
  const float own = OwnReach(proto);
  for (std::int32_t i = 0; tactics != nullptr && i < count; ++i) {
    if (tactics[i] != nullptr) {
      TacticAttacks(tactics[i], own, attacks);
    }
  }
  return Rings(attacks);
}

void Release(const char* world, std::int32_t id, const std::vector<std::int32_t>& models) {
  if (char* unit = const_cast<char*>(kUnitById(world, id))) {
    for (const std::int32_t model : models) {
      uhc::RemoveUnitModel(unit, model);
    }
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"displayedRange: rings off unit %d", id);
  }
}

struct Want {
  std::int32_t id;
  char* unit;
  std::vector<std::int32_t> models;
  std::vector<Ring> rings;  // each model's ring
  std::vector<bool> fills;  // each model: the ring's fill
  std::int32_t largest;
};

void Tick(char* world, std::int32_t) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  if (game == nullptr || world != Field<const char*>(game, 0x13C)) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_world || now < g_nextTick - kTickMs) {
    g_hung.clear();  // another game: its unit IDs are not these
    g_world = world;
    g_nextTick = 0;
  }
  if (!g_enabled) {  // turned off in the options menu: take down what is hung, draw nothing
    for (const auto& [id, models] : g_hung) {
      Release(world, id, models);
    }
    g_hung.clear();
    return;
  }
  if (now < g_nextTick) {
    return;
  }
  g_nextTick = now + kTickMs;
  const bool alt = AltHeld();
  if (g_log && alt != g_lastAlt && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"displayedRange: Alt %ls", alt ? L"held" : L"released");
  }
  g_lastAlt = alt;

  std::vector<Want> wants;
  const char* selection = kSelection();
  const std::int32_t count = selection == nullptr ? 0 : Field<std::int32_t>(selection, 0x14);
  const auto* ids = selection == nullptr ? nullptr : Field<const std::int32_t*>(selection, 0x10);
  for (std::int32_t i = 0; i < count && ids != nullptr; ++i) {
    char* unit = const_cast<char*>(kUnitById(world, ids[i]));
    const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    if (proto == nullptr) {
      continue;
    }
    const auto found = g_protos.find(Field<std::int32_t>(proto, 0x04));
    if (found == g_protos.end() || !(found->second.always || (found->second.show && alt))) {
      continue;
    }
    Want want{ids[i], unit, {}, {}, {}, 0};
    const char* owner = Field<const char*>(unit, 0x44);
    const std::int32_t player = owner == nullptr ? -1 : Field<std::int32_t>(owner, 0);
    for (const Ring& ring : WantedRadii(unit, found->second)) {
      const std::vector<std::int32_t> models = RingModels(ring, player);
      for (std::size_t k = 0; k < models.size(); ++k) {
        want.models.push_back(models[k]);
        want.rings.push_back(ring);
        want.fills.push_back(k > 0);
        want.largest = std::max(want.largest, ring.radius);
      }
    }
    if (!want.models.empty()) {
      wants.push_back(std::move(want));
    }
  }
  std::stable_sort(wants.begin(), wants.end(), [](const Want& a, const Want& b) { return a.largest > b.largest; });
  std::size_t budget = kMaxRings;
  for (Want& want : wants) {  // each unit's rings are largest first
    const std::size_t keep = std::min(budget, want.models.size());
    want.models.resize(keep);
    want.rings.resize(keep);
    want.fills.resize(keep);
    budget -= keep;
  }
  std::erase_if(wants, [](const Want& want) { return want.models.empty(); });

  std::map<std::int32_t, const Want*> byId;
  for (const Want& want : wants) {
    byId[want.id] = &want;
  }
  for (auto it = g_hung.begin(); it != g_hung.end();) {
    const auto wanted = byId.find(it->first);
    if (wanted == byId.end()) {
      Release(world, it->first, it->second);
      it = g_hung.erase(it);
      continue;
    }
    // Rings the unit no longer wants (a tactic or a tech changed its attacks).
    std::vector<std::int32_t> keep;
    char* unit = wanted->second->unit;
    for (const std::int32_t model : it->second) {
      if (std::find(wanted->second->models.begin(), wanted->second->models.end(), model) !=
          wanted->second->models.end()) {
        keep.push_back(model);
      } else {
        uhc::RemoveUnitModel(unit, model);
      }
    }
    it->second = std::move(keep);
    ++it;
  }
  if (g_bone == -2 && !wants.empty()) {
    g_bone = uhc::NoBone();
  }
  for (const Want& want : wants) {
    std::vector<std::int32_t>& hung = g_hung[want.id];
    for (std::size_t k = 0; k < want.models.size(); ++k) {
      const std::int32_t model = want.models[k];
      if (std::find(hung.begin(), hung.end(), model) != hung.end()) {
        continue;
      }
      const uhc::ModelHang hang = uhc::HangUnitModel(want.unit, model, g_bone);
      if (hang == uhc::ModelHang::kHung || hang == uhc::ModelHang::kNotInGame) {
        hung.push_back(model);
        if (g_log && g_logLines < kMaxLogLines) {
          ++g_logLines;
          uhc::Log(L"displayedRange: %ls of %d m on unit %d (%hs)%ls%ls", want.fills[k] ? L"fill" : L"ring",
                   want.rings[k].radius, want.id, Field<const char*>(Field<const char*>(want.unit, 0x5C), 0x10),
                   want.rings[k].dashed ? L", no land unit (dashed)" : L"", alt ? L", Alt held" : L"");
        }
      }
    }
  }
}

// From the shared ghost update (ghostobservers.h), each frame while a building is placed: the rings of its proto on
// the ghost's model. The ghost object [[0xC67300]+200h] holds its transform; the model drawn is [ghost+34h], an object
// of the class of a unit's visual [unit+60h] (in game both start with the same word, and the ghost's code calls three
// of that class's functions on it: 0x40431B, 0xA3FEF8, 0xADA24B), so the stock model functions take it.
void __stdcall OnGhost(char* ghost) {
  const char* ui = *reinterpret_cast<const char* const*>(kUiGlobal);
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  if (ui == nullptr || game == nullptr || ghost == nullptr || Field<char*>(ui, 0x200) != ghost) {
    return;
  }
  char* visual = Field<char*>(ghost, 0x34);
  if (visual == nullptr || Field<const char*>(visual, 0xA8) == nullptr) {  // the model functions read its +0A8h
    return;
  }
  if (!g_enabled) {  // turned off in the options menu
    if (visual == g_ghost.visual) {
      for (const std::int32_t model : g_ghost.models) {
        uhc::RemoveVisualModel(visual, model);
      }
    }
    g_ghost = Ghost{};  // turned on again, the rings are worked out anew
    return;
  }
  const std::int32_t protoId = Field<std::int32_t>(ui, 0x1FC);
  if (visual != g_ghost.visual) {
    g_ghost = Ghost{visual};  // another visual: what was hung on the old one went with it
  }
  if (protoId != g_ghost.proto) {
    for (const std::int32_t model : g_ghost.models) {
      uhc::RemoveVisualModel(visual, model);
    }
    g_ghost.models.clear();
    g_ghost.proto = protoId;
    const char* world = Field<const char*>(game, 0x13C);
    const std::int32_t playerId = Field<std::int32_t>(game, 0x3C0);
    const char* player = world == nullptr || protoId < 0 ? nullptr : kPlayerById(world, playerId);
    const char* proto = player == nullptr ? nullptr : kPlayerProto(player, protoId);
    if (proto != nullptr) {
      const auto found = g_protos.find(Field<std::int32_t>(proto, 0x04));
      for (const Ring& ring : ProtoRadii(proto, found == g_protos.end() ? nullptr : &found->second)) {
        // No fill on the ghost: a ghost that cannot be placed is drawn with the game's tint, and the alphablend
        // shader's tint technique draws the disc opaque (seen in game, 2026-11-23, a Fort's ghost).
        const std::vector<std::int32_t> models = RingModels(ring, -1);
        g_ghost.models.insert(g_ghost.models.end(), models.begin(), models.end());
        if (!models.empty() && g_log && g_logLines < kMaxLogLines) {
          ++g_logLines;
          uhc::Log(L"displayedRange: ring of %d m on the placement ghost (%hs)%ls", ring.radius,
                   Field<const char*>(proto, 0x10),
                   ring.dashed ? L", no land unit (dashed)" : L"");
        }
      }
    }
  }
  if (g_ghost.models.empty()) {
    return;
  }
  if (g_bone == -2) {
    g_bone = uhc::NoBone();
  }
  for (const std::int32_t model : g_ghost.models) {
    if (!uhc::VisualHasModel(visual, model)) {
      uhc::HangVisualModel(visual, model, g_bone);
    }
  }
}

// From the options menu's Apply (menuoptions.h, FollowMenuSwitch), on the game's thread. Only the flag changes here
// (g_nextTick is left alone: 0 would read as another game and drop g_hung without taking its rings down); the world
// tick (within 100 ms of game time) and the ghost update take the rings down or hang them, since only they know the
// world.
void OnMenuSwitch(bool on) {
  g_enabled = on;
  uhc::Log(L"displayedRange: %ls from the options menu", on ? L"on" : L"off");
}

}  // namespace

extern "C" {

// From the flag parser's last compare: a name no stock flag matched.
void __stdcall UhcUnknownProtoFlag(const char* proto, const char* name) {
  if (proto == nullptr || name == nullptr || _stricmp(name, "AlwaysDisplayRange") != 0) {
    return;
  }
  g_protos[Field<std::int32_t>(proto, 0x04)].always = true;
  if (g_log) {
    uhc::Log(L"displayedRange: proto %hs: <Flag>AlwaysDisplayRange</Flag>", Field<const char*>(proto, 0x10));
  }
}
}

namespace uhc {

Outcome ApplyDisplayedRange(const Config& config) {
  const Config::Args* args = config.First("displayedRange");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "noPlacement") == 0) {
      g_placement = false;
    } else {
      Log(L"displayedRange: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("displayedRange", {&sites::kCurrentSelectionGroup, &sites::kUnitById, &sites::kAltQuery,
                                    &sites::kActionRangeByKey, &sites::kProtoFlagLastCompare, &sites::kPlayerById,
                                    &sites::kPlayerProtoEntry, &sites::kIsA}) ||
      (g_placement && !AddGhostObserver(&OnGhost)) ||
      !VerifyUnitModels("displayedRange") || !AddProtoTagHandler("DisplayRange", &ReadShow) ||
      !AddProtoTagHandler("DisplayedRange", &ReadMetres) || !AddProtoTagHandler("AlwaysDisplayRange", &ReadAlways) ||
      !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&Tick) ||
      !WriteCall(sites::kProtoFlagLastCompare.va + 6, reinterpret_cast<const void*>(&UhcProtoFlagCompareHook))) {
    return Outcome::kFailed;
  }
  const bool follows = FollowMenuSwitch("displayedRange", &OnMenuSwitch, &g_enabled);
  Log(L"displayedRange: rings while Alt is held (<DisplayRange>) or always (<AlwaysDisplayRange>), one per ranged "
      L"attack or <DisplayedRange>%ls%ls",
      g_placement ? L"; on the placement ghost of a ranged building" : L"",
      !follows ? L"" : g_enabled ? L"; on in the options menu" : L"; off in the options menu (none drawn until it is on)");
  return Outcome::kApplied;
}

}  // namespace uhc
