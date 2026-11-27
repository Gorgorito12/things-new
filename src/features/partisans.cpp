// partisans [log]: the guerrilla (the stock Partisans tags) per civ, changed by techs, and spawned by nearby buildings.
//
// Stock (docs/engine-symbols.md, "Partisans"): a civ with <Partisans>1</Partisans> (an on/off flag) gets, when one of its
// finished units dies, PartisanCount units of PartisanType inside its footprint. A proto has one type and one count:
// a second <PartisanType> replaces the first. The kill handler 0x4B4F70 decides it at 0x4B532F (the civ test, then the
// count, its first flag and the build in the cold block 0x6A3F04) and calls the spawn 0x9C07D6, which reads the type
// and the count from the dying unit's proto, its player's copy (+160h, +164h). This key replaces that test (one hook,
// partisans_hooks.asm) and adds, in protoy.xml:
//
//   <CivPartisan civ="Spanish" count="3">Rodelero</CivPartisan>   one per civ: that civ's guerrilla on this proto, on
//                                                                 even without <Partisans>; count left out: the
//                                                                 proto's PartisanCount
//   <PartisanFromNearby>30</PartisanFromNearby>                   the units come out of the owner's finished
//                                                                 buildings within 30 m, not out of this one
//
// and two Data subtypes on a ProtoUnit target, for the player who gets the tech:
//
//   <Effect type="Data" subtype="PartisanType" amount="0" relativity="Assign" unittype="Rodelero">
//   <Effect type="Data" subtype="PartisanCount" amount="2" relativity="Assign">   (Absolute adds, Percent multiplies)
//
// The type and the count of a death: the civ's line if it has one, else the copy's PartisanType and PartisanCount; then
// each effect on that copy, in the order they came (a removed PartisanType goes back to the value before it). The stock
// conditions stay: the owner's civ has <Partisans> (or a line), the count is above 0, the kill is not a trigger's (its
// first flag), the unit is built. With the stock type and count the stock spawn runs as it is; with others, the copy's
// two fields hold them for the call and get their values back after it. Nearby: the same type and count, one unit at
// a time to each of the owner's living, finished Buildings within the radius of the dying one, closest first, placed
// beside it with the placement test PLACE; with none in range, the stock spawn at the dying building.
//
// Nothing is saved: the lines come from the data, the effects run again when a game loads, and the spawn picks no
// random number of its own (the stock spawn draws the game's synced random as before).
#include <algorithm>
#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint32_t kCivTestSite = 0x004B532F;
constexpr std::size_t kCivTestLength = 16;
constexpr std::uint32_t kProtoTable = 0x54;       // in the database: the proto array (new for each data load)
constexpr std::uint32_t kTypeNames = 0x190;       // in the database: the unit type name table
constexpr std::uint32_t kFirstAbstract = 0x19B0;  // in the database: the first abstract type's ID
constexpr std::uint32_t kPartisanType = 0x160;    // in a proto
constexpr std::uint32_t kPartisanCount = 0x164;
constexpr std::uint32_t kAliveSlot = 0xA4;     // unit vtable: bool thiscall(unit)
constexpr std::uint32_t kDistanceSlot = 0xB8;  // unit vtable: float thiscall(unit, const float* point)
constexpr std::uint32_t kPlaceSlot = 0x14;     // world vtable: PLACE, FUN_0050703D
constexpr std::int32_t kPlaceFlags = 2 | 4;    // as killSpawn: terrain and buildings tested, living units not
constexpr std::int32_t kMaxCount = 100;
constexpr float kMaxRadius = 200.0f;
constexpr int kMaxLogLines = 2000;
// Where PLACE is asked around a building, on the ground plane: rings at its size plus these metres, 12 points each,
// in a fixed order so every machine picks the same one.
constexpr float kRingGaps[] = {1.0f, 2.5f, 4.0f, 6.0f};
constexpr int kRingPoints = 12;

struct IdList {  // the engine's dynamic array FUN_004A1C55 fills
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using CivTestFn = bool(__thiscall*)(const char* player);
using SpawnFn = void(__thiscall*)(char* unit);
using IsBuiltFn = bool(__thiscall*)(const char* unit);
using CivIdByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using CivByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
using ProtoByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using PlayerProtoFn = char*(__thiscall*)(const char* player, std::int32_t protoId);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
using UnitsNearFn = std::int32_t(__thiscall*)(char* world, const float* point, float radius, char precise, IdList* out);
using UnitByIdFn = char*(__thiscall*)(char* world, std::int32_t id);
using UnitIsAliveFn = bool(__thiscall*)(const char* unit);
using UnitDistanceFn = float(__thiscall*)(const char* unit, const float* point);
using PlaceFn = bool(__thiscall*)(char* world, std::int32_t proto, std::int32_t player, const float* position,
                                  const float* forward, const float* right, std::int32_t a, std::int32_t b,
                                  std::int32_t c, std::int32_t d, std::int32_t e, std::int32_t f);
using CreateFn = char*(__thiscall*)(char* world, std::int32_t proto, std::int32_t player, const float* position,
                                    const float* forward, std::int32_t a, std::int32_t b, std::int32_t c, std::int32_t d);

const auto kCivTest = reinterpret_cast<CivTestFn>(0x004B4EBD);
const auto kSpawn = reinterpret_cast<SpawnFn>(0x009C07D6);
const auto kIsBuilt = reinterpret_cast<IsBuiltFn>(0x0044DDB4);
const auto kCivIdByName = reinterpret_cast<CivIdByNameFn>(0x0058E71F);
const auto kCivById = reinterpret_cast<CivByIdFn>(0x00405C2E);
const auto kProtoByName = reinterpret_cast<ProtoByNameFn>(0x005A2346);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kCreate = reinterpret_cast<CreateFn>(0x00498ACC);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

template <typename Fn>
Fn Virtual(const char* object, std::uint32_t slot) {
  return reinterpret_cast<Fn>(Field<void* const*>(object, 0)[slot / 4]);
}

const char* GameField(std::uint32_t offset) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, offset);
}

std::int32_t ProtoId(const char* proto) { return proto == nullptr ? -1 : Field<std::int32_t>(proto, 8); }

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

// A player's civ ID (0x4539D3): [[player+20h]] when [player+24h] > 0, else -1.
std::int32_t CivIdOf(const char* player) {
  return Field<std::int32_t>(player, 0x24) > 0 ? *Field<const std::int32_t*>(player, 0x20) : -1;
}

std::string Trim(const std::string& text) {
  const auto first = text.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) {
    return {};
  }
  return text.substr(first, text.find_last_not_of(" \t\r\n") - first + 1);
}

std::string NarrowWide(const wchar_t* text) {
  std::string out;
  for (; text != nullptr && *text != L'\0'; ++text) {
    out += *text < 0x80 ? static_cast<char>(*text) : '?';
  }
  return Trim(out);
}

bool Attribute(const char* node, const char* name, std::string* out) {
  const void* value = nullptr;
  out->clear();
  if (node == nullptr || !kXmlAttribute(node, name, &value) || value == nullptr) {
    return false;
  }
  const char* text = kXmlText(value);
  *out = Trim(text == nullptr ? std::string() : std::string(text));
  return true;
}

bool g_log = false;
int g_logLines = 0;

void LogLine(const wchar_t* format, ...) {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return;
  }
  if (++g_logLines == kMaxLogLines) {
    uhc::Log(L"partisans: %d lines logged; no more", kMaxLogLines);
    return;
  }
  wchar_t text[512];
  va_list args;
  va_start(args, format);
  _vsnwprintf_s(text, _TRUNCATE, format, args);
  va_end(args);
  uhc::Log(L"%ls", text);
}

// --- Data ---------------------------------------------------------------------------------------------------------

struct CivLine {
  std::string civ;
  std::string unit;
  std::int32_t count = -1;  // -1: the proto's PartisanCount
  // Resolved against the database whose proto array is `table`:
  std::int32_t civId = -1;
  std::int32_t unitId = -1;
};

struct ProtoData {
  std::vector<CivLine> lines;
  float nearby = 0.0f;  // the radius of <PartisanFromNearby>; 0: off
  const char* table = nullptr;
};

std::unordered_map<std::int32_t, ProtoData> g_protos;  // by base proto ID
std::int32_t g_building = -1;                          // the abstract type Building, per data load
const char* g_buildingTable = nullptr;

// The effects on a player's copy of a proto, in the order they came.
struct TechEffect {
  bool type;  // PartisanType; else PartisanCount
  std::int32_t unit;
  std::uint8_t relativity;
  float amount;
  bool unapply;
};
struct TechSlot {
  std::int32_t id = -1;  // the copy's proto ID, so a reused pointer is not taken for another proto
  std::vector<TechEffect> effects;
};
std::unordered_map<const char*, TechSlot> g_tech;

IdList g_found = {nullptr, 0, 0};


const char* Database() { return GameField(0x140); }

bool __cdecl ReadCivPartisan(void*, const char* node, char* proto) {
  const std::int32_t id = ProtoId(proto);
  CivLine line;
  line.unit = NarrowWide(*reinterpret_cast<const wchar_t* const*>(node + 0x14));
  if (!Attribute(node, "civ", &line.civ) || line.civ.empty()) {
    uhc::Log(L"partisans: proto %d (%hs): <CivPartisan> has no civ=\"...\"; ignored", id, ProtoName(proto));
    return true;
  }
  if (line.unit.empty()) {
    uhc::Log(L"partisans: proto %d (%hs): <CivPartisan civ=\"%hs\"> names no unit; ignored", id, ProtoName(proto),
             line.civ.c_str());
    return true;
  }
  std::string text;
  if (Attribute(node, "count", &text)) {
    char* end = nullptr;
    const long n = std::strtol(text.c_str(), &end, 10);
    if (text.empty() || *end != '\0' || n < 0 || n > kMaxCount) {
      uhc::Log(L"partisans: proto %d (%hs): <CivPartisan civ=\"%hs\"> count=\"%hs\" is not a number from 0 to %d; the "
               L"proto's PartisanCount is used",
               id, ProtoName(proto), line.civ.c_str(), text.c_str(), kMaxCount);
    } else {
      line.count = static_cast<std::int32_t>(n);
    }
  }
  ProtoData& data = g_protos[id];
  for (CivLine& old : data.lines) {
    if (_stricmp(old.civ.c_str(), line.civ.c_str()) == 0) {
      uhc::Log(L"partisans: proto %d (%hs): a second <CivPartisan civ=\"%hs\">; it replaces the first", id,
               ProtoName(proto), line.civ.c_str());
      old = line;
      data.table = nullptr;
      return true;
    }
  }
  data.lines.push_back(line);
  data.table = nullptr;
  LogLine(L"partisans: proto %d (%hs): civ %hs gets %hs x %d", id, ProtoName(proto), line.civ.c_str(),
          line.unit.c_str(), line.count);
  return true;
}

bool __cdecl ReadFromNearby(void*, const char* node, char* proto) {
  const std::int32_t id = ProtoId(proto);
  const std::string text = NarrowWide(*reinterpret_cast<const wchar_t* const*>(node + 0x14));
  char* end = nullptr;
  const double radius = std::strtod(text.c_str(), &end);
  if (text.empty() || *end != '\0' || !(radius >= 0.0) || !(radius <= kMaxRadius)) {
    uhc::Log(L"partisans: proto %d (%hs): <PartisanFromNearby> \"%hs\" is not a radius from 0 to %g m; ignored", id,
             ProtoName(proto), text.c_str(), static_cast<double>(kMaxRadius));
    return true;
  }
  g_protos[id].nearby = static_cast<float>(radius);
  LogLine(L"partisans: proto %d (%hs): from the buildings within %g m", id, ProtoName(proto), radius);
  return true;
}

std::int32_t TypeByName(const char* database, const char* name) {
  const char* table = database + kTypeNames;
  std::int32_t id = -1;
  return kNameFind(table, name, kNameBucket(table, name), &id) ? id : -1;
}

void Resolve(const char* database, std::int32_t protoId, ProtoData& data) {
  const char* table = Field<const char*>(database, kProtoTable);
  if (data.table == table) {
    return;
  }
  data.table = table;
  const std::int32_t firstAbstract = Field<std::int32_t>(database, kFirstAbstract);
  for (CivLine& line : data.lines) {
    line.civId = kCivIdByName(database, line.civ.c_str());
    line.unitId = kProtoByName(database, line.unit.c_str());
    if (line.civId < 0) {
      uhc::Log(L"partisans: proto %d: <CivPartisan civ=\"%hs\">: no such civ; ignored", protoId, line.civ.c_str());
    }
    if (line.unitId < 0 || line.unitId >= firstAbstract) {
      uhc::Log(L"partisans: proto %d: <CivPartisan civ=\"%hs\">: %hs is not a proto unit; ignored", protoId,
               line.civ.c_str(), line.unit.c_str());
      line.unitId = -1;
    }
  }
}

void ForgetOnDataLoad(char*) {
  g_protos.clear();
  g_tech.clear();
  g_buildingTable = nullptr;
  g_building = -1;
}

// --- Tech subtypes ----------------------------------------------------------------------------------------------

bool ParseType(void* db, char* effect, const char* node) {
  std::string name;
  if (!Attribute(node, "unittype", &name) || name.empty()) {
    uhc::Log(L"partisans: a PartisanType effect names no unittype; effect dropped");
    return false;
  }
  const char* database = static_cast<const char*>(db);
  const std::int32_t id = kProtoByName(database, name.c_str());
  if (id < 0 || id >= Field<std::int32_t>(database, kFirstAbstract)) {
    uhc::Log(L"partisans: a PartisanType effect names %hs, not a proto unit; effect dropped", name.c_str());
    return false;
  }
  *reinterpret_cast<std::int32_t*>(effect + 0x10) = id;
  return true;
}

TechSlot& SlotOf(char* proto) {
  TechSlot& slot = g_tech[proto];
  const std::int32_t id = ProtoId(proto);
  if (slot.id != id) {
    slot = TechSlot{};
    slot.id = id;
  }
  return slot;
}

void ChangeType(char* proto, const char*, std::int32_t unit, float, std::uint8_t, bool unapply) {
  SlotOf(proto).effects.push_back({true, unit, 0, 0.0f, unapply});
  LogLine(L"partisans: proto %d (%hs), tech subtype PartisanType, unit %d%ls", ProtoId(proto), ProtoName(proto), unit,
          unapply ? L" (removed)" : L"");
}

void ChangeCount(char* proto, const char*, float amount, std::uint8_t relativity, bool unapply) {
  SlotOf(proto).effects.push_back({false, -1, relativity, amount, unapply});
  LogLine(L"partisans: proto %d (%hs), tech subtype PartisanCount, relativity %u, amount %g%ls", ProtoId(proto),
          ProtoName(proto), relativity, static_cast<double>(amount), unapply ? L" (removed)" : L"");
}

// --- The death ----------------------------------------------------------------------------------------------------

struct Guerrilla {
  bool on = false;
  std::int32_t type = -1;
  std::int32_t count = 0;
  float nearby = 0.0f;
};

Guerrilla GuerrillaOf(const char* database, const char* player, const char* copy) {
  Guerrilla g;
  g.type = Field<std::int32_t>(copy, kPartisanType);
  g.count = Field<std::int32_t>(copy, kPartisanCount);
  const CivLine* line = nullptr;
  const auto found = g_protos.find(ProtoId(copy));
  if (found != g_protos.end()) {
    Resolve(database, found->first, found->second);
    g.nearby = found->second.nearby;
    const std::int32_t civId = CivIdOf(player);
    for (const CivLine& candidate : found->second.lines) {
      if (candidate.civId >= 0 && candidate.civId == civId && candidate.unitId >= 0) {
        line = &candidate;
        break;
      }
    }
  }
  if (line != nullptr) {
    g.on = true;
    g.type = line->unitId;
    if (line->count >= 0) {
      g.count = line->count;
    }
  } else {
    g.on = kCivTest(player);
  }
  const auto tech = g_tech.find(copy);
  if (tech != g_tech.end() && tech->second.id == ProtoId(copy)) {
    const std::int32_t baseType = g.type;
    std::vector<std::int32_t> types;  // the type before each PartisanType effect still applied
    const float baseCount = static_cast<float>(g.count);
    float count = baseCount;
    for (const TechEffect& effect : tech->second.effects) {
      if (!effect.type) {
        kEffectValue(effect.relativity, &count, baseCount, effect.amount, effect.unapply);
      } else if (!effect.unapply) {
        types.push_back(g.type);
        g.type = effect.unit;
      } else if (!types.empty()) {
        g.type = types.back();
        types.pop_back();
      } else {
        g.type = baseType;
      }
    }
    const long rounded = std::lround(count);
    g.count = rounded < 0 ? 0 : (rounded > kMaxCount ? kMaxCount : static_cast<std::int32_t>(rounded));
  }
  return g;
}

struct Near {
  char* unit;
  std::int32_t id;
  float distance;
};

// The owner's living, finished Buildings within the radius of the dying unit's edge, closest first (then by ID).
std::vector<Near> NearbyBuildings(char* world, const char* database, char* dying, float radius, int* unfinished) {
  std::vector<Near> out;
  const char* types = Field<const char*>(database, kProtoTable);
  if (g_buildingTable != types) {
    g_buildingTable = types;
    g_building = TypeByName(database, "Building");
  }
  if (g_building < 0) {
    return out;
  }
  const char* owner = Field<const char*>(dying, 0x44);
  const auto* position = reinterpret_cast<const float*>(dying + 0x14);
  const std::int32_t dyingId = Field<std::int32_t>(dying, 0x10);
  kUnitsNear(world, position, radius, 1, &g_found);
  for (std::int32_t i = 0; i < g_found.count && g_found.data != nullptr; ++i) {
    char* unit = kUnitById(world, g_found.data[i]);
    if (unit == nullptr || Field<std::int32_t>(unit, 0x10) == dyingId || Field<const char*>(unit, 0x44) != owner) {
      continue;
    }
    const char* proto = Field<const char*>(unit, 0x5C);
    if (proto == nullptr || !kProtoIsType(proto, g_building) || !Virtual<UnitIsAliveFn>(unit, kAliveSlot)(unit)) {
      continue;
    }
    if (!kIsBuilt(unit)) {
      ++*unfinished;
      continue;
    }
    out.push_back({unit, Field<std::int32_t>(unit, 0x10), Virtual<UnitDistanceFn>(unit, kDistanceSlot)(unit, position)});
  }
  std::sort(out.begin(), out.end(), [](const Near& a, const Near& b) {
    return a.distance != b.distance ? a.distance < b.distance : a.id < b.id;
  });
  return out;
}

// One unit of `proto` beside `building`: the first point of the rings PLACE accepts.
char* SpawnBeside(char* world, std::int32_t proto, std::int32_t player, const char* building) {
  const auto place = Virtual<PlaceFn>(world, kPlaceSlot);
  const char* buildingProto = Field<const char*>(building, 0x5C);
  const float size = std::max(Field<float>(buildingProto, 0x88), Field<float>(buildingProto, 0x8C));
  const auto* centre = reinterpret_cast<const float*>(building + 0x14);
  const auto* forward = reinterpret_cast<const float*>(building + 0x20);
  const auto* right = reinterpret_cast<const float*>(building + 0x38);
  for (const float gap : kRingGaps) {
    const float reach = size + gap;
    for (int k = 0; k < kRingPoints; ++k) {
      const double angle = 6.283185307179586 * k / kRingPoints;
      float at[3] = {centre[0] + reach * static_cast<float>(std::cos(angle)), centre[1],
                     centre[2] + reach * static_cast<float>(std::sin(angle))};
      if (place(world, proto, player, at, forward, right, 0, kPlaceFlags, 0, 0, 0, 0)) {
        return kCreate(world, proto, player, at, forward, 1, -1, 1, -1);  // the stock spawn's arguments
      }
    }
  }
  return nullptr;
}

// The stock spawn with this type and count: the copy holds them for the call.
void StockSpawn(char* unit, char* copy, const Guerrilla& g) {
  auto* type = reinterpret_cast<std::int32_t*>(copy + kPartisanType);
  auto* count = reinterpret_cast<std::int32_t*>(copy + kPartisanCount);
  const std::int32_t oldType = *type;
  const std::int32_t oldCount = *count;
  *type = g.type;
  *count = g.count;
  kSpawn(unit);
  *type = oldType;
  *count = oldCount;
}

}  // namespace

extern "C" {

void UhcPartisansHook();

void __stdcall UhcPartisansOnDeath(char* unit, std::int32_t flag) {
  char* player = unit == nullptr ? nullptr : Field<char*>(unit, 0x44);
  char* copy = unit == nullptr ? nullptr : Field<char*>(unit, 0x5C);
  const char* database = Database();
  char* world = const_cast<char*>(GameField(0x13C));
  if (player == nullptr || copy == nullptr || database == nullptr || world == nullptr) {
    return;
  }
  const Guerrilla g = GuerrillaOf(database, player, copy);
  if (!g.on || g.count <= 0) {
    return;  // the stock order of the tests does not matter: none has an effect
  }
  if (flag != 0 || !kIsBuilt(unit)) {
    const char* build = Field<const char*>(unit, 0x68);
    LogLine(L"partisans: unit %d (%hs) of player %d died: no guerrilla (%ls, build %.0f %%)",
            Field<std::int32_t>(unit, 0x10), ProtoName(copy), Field<std::int32_t>(player, 0),
            flag != 0 ? L"the kill's first flag is set" : L"not finished",
            build == nullptr ? 100.0 : 100.0 * static_cast<double>(Field<float>(build, 8)));
    return;
  }
  const std::int32_t playerId = Field<std::int32_t>(player, 0);
  const char* partisan = g.type >= 0 ? kPlayerProto(player, g.type) : nullptr;
  if (partisan == nullptr) {
    LogLine(L"partisans: unit %d (%hs) of player %d died: type %d is no proto; nothing", Field<std::int32_t>(unit, 0x10),
            ProtoName(copy), playerId, g.type);
    return;
  }
  if (g.nearby > 0.0f) {
    int unfinished = 0;
    const std::vector<Near> near = NearbyBuildings(world, database, unit, g.nearby, &unfinished);
    if (!near.empty()) {
      LogLine(L"partisans: unit %d (%hs) of player %d died: %d x %hs beside %u building(s) within %g m (%d unfinished "
              L"left out)",
              Field<std::int32_t>(unit, 0x10), ProtoName(copy), playerId, g.count, ProtoName(partisan),
              static_cast<unsigned>(near.size()), static_cast<double>(g.nearby), unfinished);
      for (std::int32_t i = 0; i < g.count; ++i) {
        const Near& at = near[static_cast<std::size_t>(i) % near.size()];
        const char* spawned = SpawnBeside(world, ProtoId(partisan), playerId, at.unit);
        if (spawned == nullptr) {
          LogLine(L"partisans: %hs %d of %d: no room beside unit %d (%hs)", ProtoName(partisan), i + 1, g.count, at.id,
                  ProtoName(Field<const char*>(at.unit, 0x5C)));
          continue;
        }
        LogLine(L"partisans: %hs %d of %d (unit %d) beside unit %d (%hs, %.1f m from the dead one) at (%.1f, %.1f)",
                ProtoName(partisan), i + 1, g.count, Field<std::int32_t>(spawned, 0x10), at.id,
                ProtoName(Field<const char*>(at.unit, 0x5C)), static_cast<double>(at.distance),
                static_cast<double>(Field<float>(spawned, 0x14)), static_cast<double>(Field<float>(spawned, 0x1C)));
      }
      return;
    }
    LogLine(L"partisans: unit %d (%hs) of player %d died: no finished building of its owner within %g m (%d unfinished); "
            L"from the unit itself",
            Field<std::int32_t>(unit, 0x10), ProtoName(copy), playerId, static_cast<double>(g.nearby), unfinished);
  }
  LogLine(L"partisans: unit %d (%hs) of player %d (civ %d) died: %d x %hs", Field<std::int32_t>(unit, 0x10),
          ProtoName(copy), playerId, CivIdOf(player), g.count, ProtoName(partisan));
  StockSpawn(unit, copy, g);
}

}  // extern "C"

namespace uhc {

Outcome ApplyPartisans(const Config& config) {
  const Config::Args* args = config.First("partisans");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"partisans: unknown option %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("partisans",
                 {&sites::kPartisanCivTest, &sites::kPartisanColdBlock, &sites::kPartisanSpawn,
                  &sites::kPartisanCivFlag, &sites::kIsBuilt, &sites::kCivIdByName, &sites::kCivById,
                  &sites::kProtoByName, &sites::kIsA, &sites::kPlayerProtoEntry, &sites::kEffectValueApply,
                  &sites::kUnitsNearPoint, &sites::kUnitById, &sites::kUnitCreate, &sites::kKillSpawnPlace}) ||
      !AddProtoTagHandler("CivPartisan", &ReadCivPartisan) ||
      !AddProtoTagHandler("PartisanFromNearby", &ReadFromNearby) ||
      !AddTechProtoSubtype("PartisanType", &ParseType, &ChangeType) ||
      !AddTechSubtype("PartisanCount", &ChangeCount) || !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !WriteJmp(kCivTestSite, reinterpret_cast<const void*>(&UhcPartisansHook), kCivTestLength)) {
    return Outcome::kFailed;
  }
  Log(L"partisans: the proto tags CivPartisan and PartisanFromNearby and the Data subtypes PartisanType and "
      L"PartisanCount are on%ls",
      g_log ? L", every guerrilla logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
