// linkedResource: a resource building whose stock is that of a mine beside it.
//
//   <LinkedResourceType>AbstractMine</LinkedResourceType>   a unit type or a proto, in the building's proto
//   <LinkedResourceRange>8</LinkedResourceRange>            metres, default 8
//   <GatherLinkedResource>1</GatherLinkedResource>          in an AutoGather action
//
// Each tagged unit is linked to the nearest unit of the type in range, of any owner (FUN_004A1C55 and the
// distance slot B8h), looked for once a second while it has none. Its inventory then shows the mine's: the
// entry of the mine's main resource is copied in, so the panel reads it, the gather tick's clamp holds, and at 0
// villagers stop by the stock paths. Every take goes to the mine: the head of 0x49A5E6, which the gather tick
// calls at 0x4ED124, sends a negative add on a linked inventory to the mine's and runs the state check 0x482152
// there, so the mine ends as if it were mined. With no mine in range the building keeps its own stock.
//
// An AutoGather action pays from nothing (0x4C3798). With the tag, the amount is taken first from the same
// source, the mine or the building's own stock, and what is paid is what was there: the hook at 0x4C378A changes
// the amount and leaves the stock call of the add, whose return address resourceDebt reads.
//
// Links are by unit ID in an ordered map and looked up by game time, on every machine alike. A new game forgets
// them; a saved game finds them again, from the building's first take or update. Hooks: linkedresource_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <utility>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
void UhcLinkedRecreateHook();
void UhcLinkedInventoryHook();
void UhcLinkedAutoGatherHook();
void UhcLinkedInventoryStock();  // the stock entry of 0x49A5E6
std::int32_t g_uhcLinkedOn = 0;  // read by the inventory hook: 1 once the data has a tagged proto
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kResolveMs = 1000;
constexpr std::uint32_t kMirrorMs = 250;
constexpr float kDefaultRange = 8.0f;
constexpr float kMinAmount = 1.0e-6f;
constexpr int kMaxLogLines = 200;

// The list FUN_004A1C55 fills (the engine's dynamic array: data, count, capacity).
struct IdList {
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using UnitsNearFn = std::int32_t(__thiscall*)(char* world, const float* point, float radius, char precise, IdList* out);
using UnitByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using UnitTestFn = bool(__thiscall*)(const char* unit);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using MainResourceFn = std::int32_t(__thiscall*)(const char* unit);
using ListGetFn = float(__thiscall*)(const char* list, std::int32_t resource);
using ListSetFn = void(__thiscall*)(char* list, std::int32_t resource, float value);
using InventoryAddFn = bool(__thiscall*)(char* inventory, std::int32_t resource, float amount);
using CheckStateFn = void(__thiscall*)(char* unit);
using DistanceFn = float(__thiscall*)(const char* unit, const float* point);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);

const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kIsBuilt = reinterpret_cast<UnitTestFn>(0x0044DDB4);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kMainResource = reinterpret_cast<MainResourceFn>(0x004DBEC1);
const auto kListGet = reinterpret_cast<ListGetFn>(0x0044EFFF);
const auto kListSet = reinterpret_cast<ListSetFn>(0x0058EF83);
const auto kInventoryAdd = reinterpret_cast<InventoryAddFn>(&UhcLinkedInventoryStock);
const auto kCheckState = reinterpret_cast<CheckStateFn>(0x00482152);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);

struct ProtoLink {
  std::string typeName;
  std::int32_t type = -2;  // -2: not looked up yet, -1: unknown
  float range = kDefaultRange;
};

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Link {
  std::int32_t mine = -1;
  std::int32_t resource = -1;
  std::uint32_t nextResolve = 0;
};

std::unordered_map<std::int32_t, ProtoLink> g_protos;  // by proto ID; the load fills it
std::set<ActionKey> g_gatherActions;                   // AutoGather actions with the tag
std::map<std::int32_t, Link> g_links;                  // by the building's unit ID
const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_nextMirror = 0;
IdList g_found = {};
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* World() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<UnitTestFn const* const*>(unit))[0xA4 / 4](unit); }

char* InventoryOf(const char* unit) {
  const char* record = Field<const char*>(unit, 0xB4);
  return record == nullptr ? nullptr : Field<char*>(record, 0x94);
}

void LogLine(const wchar_t* format, std::int32_t a, std::int32_t b, double c) {
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(format, a, b, c);
  }
}

bool __cdecl ReadType(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  if (text == nullptr || text[0] == L'\0') {
    return true;
  }
  ProtoLink& link = g_protos[Field<std::int32_t>(proto, 0x04)];
  link.typeName.clear();
  for (const wchar_t* c = text; *c != 0; ++c) {
    link.typeName.push_back(static_cast<char>(*c));
  }
  g_uhcLinkedOn = 1;
  return true;
}

bool __cdecl ReadRange(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  const float range = text == nullptr ? 0.0f : std::wcstof(text, nullptr);
  if (range > 0.0f) {
    g_protos[Field<std::int32_t>(proto, 0x04)].range = range;
  } else {
    uhc::Log(L"linkedResource: proto %d: <LinkedResourceRange> needs a number above 0, ignored",
             Field<std::int32_t>(proto, 0x04));
  }
  return true;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  if (_wcsicmp(tag.name, L"GatherLinkedResource") != 0) {
    return;
  }
  if (tag.text == nullptr || tag.text[0] == L'\0' || std::wcstol(tag.text, nullptr, 10) != 0) {
    g_gatherActions.insert({Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)});
    g_uhcLinkedOn = 1;
  }
}

void NewDatabase(char*) {
  g_protos.clear();
  g_gatherActions.clear();
  g_links.clear();
  g_uhcLinkedOn = 0;
  g_logLines = 0;
}

std::int32_t TypeOf(ProtoLink& proto) {
  if (proto.type != -2) {
    return proto.type;
  }
  proto.type = -1;
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (database == nullptr) {
    return -1;
  }
  const char* table = database + 0x190;
  std::int32_t id = -1;
  const std::int32_t bucket = kNameBucket(table, proto.typeName.c_str());
  if (kNameFind(table, proto.typeName.c_str(), bucket, &id)) {
    proto.type = id;
  } else {
    uhc::Log(L"linkedResource: <LinkedResourceType>%hs names no unit type or proto; ignored", proto.typeName.c_str());
  }
  return proto.type;
}

// The inventory entry of the building follows the mine's.
void Mirror(const char* building, const char* mine, std::int32_t resource) {
  char* own = InventoryOf(building);
  char* source = InventoryOf(mine);
  if (own != nullptr && source != nullptr) {
    kListSet(own + 4, resource, kListGet(source + 4, resource));
  }
}

// The nearest unit of the type in range that holds something. A tagged building is never a mine.
void Resolve(char* world, char* building, std::int32_t id, ProtoLink& proto, Link& link) {
  const std::int32_t type = TypeOf(proto);
  if (type < 0) {
    return;
  }
  const auto* position = reinterpret_cast<const float*>(building + 0x14);
  g_found.count = 0;
  kUnitsNear(world, position, proto.range, 1, &g_found);
  float bestDistance = 0.0f;
  std::int32_t best = -1;
  std::int32_t bestResource = -1;
  for (std::int32_t i = 0; i < g_found.count; ++i) {
    const char* unit = kUnitById(world, g_found.data[i]);
    const char* unitProto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    if (unitProto == nullptr || unit == building || !kProtoIsType(unitProto, type) ||
        g_protos.count(Field<std::int32_t>(unitProto, 0x04)) != 0 || !IsAlive(unit)) {
      continue;
    }
    const char* inventory = InventoryOf(unit);
    const std::int32_t resource = inventory == nullptr ? -1 : kMainResource(unit);
    if (resource < 0 || kListGet(inventory + 4, resource) <= kMinAmount) {
      continue;
    }
    const auto distance = (*reinterpret_cast<DistanceFn const* const*>(unit))[0xB8 / 4](unit, position);
    const std::int32_t unitId = Field<std::int32_t>(unit, 0x10);
    if (best < 0 || distance < bestDistance || (distance == bestDistance && unitId < best)) {
      bestDistance = distance;
      best = unitId;
      bestResource = resource;
    }
  }
  if (best >= 0) {
    link.mine = best;
    link.resource = bestResource;
    LogLine(L"linkedResource: unit %d linked to unit %d, %.1f m", id, best, static_cast<double>(bestDistance));
    Mirror(building, kUnitById(world, best), bestResource);
  }
}

Link* LinkOf(char* world, char* unit) {
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const auto found = g_links.find(id);
  if (found != g_links.end()) {
    return &found->second;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  const auto tagged = proto == nullptr ? g_protos.end() : g_protos.find(Field<std::int32_t>(proto, 0x04));
  if (tagged == g_protos.end()) {
    return nullptr;
  }
  Link& link = g_links[id];  // a loaded game: found on its first take, which goes to the mine too
  Resolve(world, unit, id, tagged->second, link);
  return &link;
}

// The unit that holds the stock of this building now: the mine, or null for its own.
char* SourceOf(const char* world, Link& link) {
  if (link.mine < 0) {
    return nullptr;
  }
  char* mine = kUnitById(world, link.mine);
  return mine != nullptr && IsAlive(mine) ? mine : nullptr;
}

void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_world || now < g_lastTime) {
    g_links.clear();  // another game: its unit IDs are not these
    g_world = world;
    g_nextMirror = 0;
  }
  g_lastTime = now;
  if (g_links.empty() || now < g_nextMirror) {
    return;
  }
  g_nextMirror = now + kMirrorMs;
  for (auto it = g_links.begin(); it != g_links.end();) {
    char* building = kUnitById(world, it->first);
    const char* proto = building == nullptr ? nullptr : Field<const char*>(building, 0x5C);
    const auto tagged = proto == nullptr ? g_protos.end() : g_protos.find(Field<std::int32_t>(proto, 0x04));
    if (tagged == g_protos.end() || !IsAlive(building)) {
      it = g_links.erase(it);
      continue;
    }
    Link& link = it->second;
    if (const char* mine = SourceOf(world, link)) {
      if (kListGet(InventoryOf(mine) + 4, link.resource) > kMinAmount) {
        Mirror(building, mine, link.resource);
        ++it;
        continue;
      }
    }
    if (link.mine >= 0) {
      // The mine is gone or empty: its gold is over, and this building shows it.
      if (char* own = InventoryOf(building)) {
        kListSet(own + 4, link.resource, 0.0f);
      }
      LogLine(L"linkedResource: unit %d lost unit %d (%.0f left)", it->first, link.mine, 0.0);
      link.mine = -1;
    }
    if (now >= link.nextResolve && kIsBuilt(building)) {
      link.nextResolve = now + kResolveMs;
      Resolve(world, building, it->first, tagged->second, link);
    }
    ++it;
  }
}

}  // namespace

extern "C" {

// After the inventory of a unit is made: a tagged unit joins the links.
void __stdcall UhcLinkedRegister(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  if (g_uhcLinkedOn != 0 && proto != nullptr && g_protos.count(Field<std::int32_t>(proto, 0x04)) != 0) {
    g_links.try_emplace(Field<std::int32_t>(unit, 0x10));
  }
}

// From the head of 0x49A5E6. True: a take from a linked building went to its mine, and *result is what it gave.
std::int32_t __stdcall UhcLinkedInventory(char* inventory, std::int32_t resource, float amount, std::int32_t* result) {
  if (!(amount < 0.0f)) {
    return 0;
  }
  char* world = const_cast<char*>(World());
  char* building = world == nullptr ? nullptr : kUnitById(world, Field<std::int32_t>(inventory, 0));
  if (building == nullptr) {
    return 0;
  }
  Link* link = LinkOf(world, building);
  if (link == nullptr) {
    return 0;
  }
  char* mine = SourceOf(world, *link);
  if (mine == nullptr) {
    return 0;
  }
  *result = kInventoryAdd(InventoryOf(mine), link->resource, amount) ? 1 : 0;
  Mirror(building, mine, link->resource);
  kCheckState(mine);
  return 1;
}

// From the AutoGather update, before the add 0x4C3798. *amount is what it would pay: an action with the tag pays
// what its source holds, and the source loses it.
void __stdcall UhcLinkedAutoGather(const char* action, std::int32_t resource, float* amount) {
  if (g_uhcLinkedOn == 0 || !(*amount > 0.0f)) {
    return;
  }
  char* unit = Field<char*>(action, 0x10);
  const char* tactics = Field<const char*>(action, 0x04);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (proto == nullptr || tactics == nullptr ||
      g_gatherActions.count({Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(tactics, 0x04)}) == 0) {
    return;
  }
  char* world = const_cast<char*>(World());
  Link* link = world == nullptr ? nullptr : LinkOf(world, unit);
  char* mine = link == nullptr ? nullptr : SourceOf(world, *link);
  char* inventory = InventoryOf(mine != nullptr ? mine : unit);
  const float have = inventory == nullptr ? 0.0f : kListGet(inventory + 4, resource);
  const float take = have < *amount ? have : *amount;
  if (take > 0.0f) {
    kInventoryAdd(inventory, resource, -take);
    if (mine != nullptr) {
      Mirror(unit, mine, resource);
      kCheckState(mine);
    }
  }
  *amount = take;
}
}

namespace uhc {

Outcome ApplyLinkedResource(const Config& config) {
  const Config::Args* args = config.First("linkedResource");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"linkedResource: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("linkedResource", {&sites::kInventoryAddHead, &sites::kInventoryRecreateHead, &sites::kAutoGatherPayPoint,
                                    &sites::kUnitsNearPoint, &sites::kUnitById, &sites::kIsA, &sites::kResListGet,
                                    &sites::kResListSet, &sites::kCheckState, &sites::kMainResource, &sites::kIsBuilt,
                                    &sites::kUnitAliveSlot}) ||
      !AddProtoTagHandler("LinkedResourceType", &ReadType) || !AddProtoTagHandler("LinkedResourceRange", &ReadRange) ||
      !AddActionTagHandler(&ActionTagRead) || !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&Tick) ||
      !WriteJmp(sites::kInventoryAddHead.va, reinterpret_cast<const void*>(&UhcLinkedInventoryHook), 5) ||
      !WriteJmp(sites::kInventoryRecreateHead.va, reinterpret_cast<const void*>(&UhcLinkedRecreateHook), 9) ||
      !WriteJmp(sites::kAutoGatherPayPoint.va, reinterpret_cast<const void*>(&UhcLinkedAutoGatherHook), 7)) {
    return Outcome::kFailed;
  }
  Log(L"linkedResource: the proto tags LinkedResourceType and LinkedResourceRange and the action tag GatherLinkedResource "
      L"are on (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
