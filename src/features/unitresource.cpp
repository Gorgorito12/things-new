// unitResourceAuras: an AutoRangedModify action with <ModifyType>UnitResource</ModifyType> gathers
// from the units around it, for its owner.
//
// Stock: an aura gives each unit in range a modifier (FUN_009D033E). UnitResource is not one of the
// names of the parser, and <ModifyAmount>, <ModifyTargetLimit> and <TargetGaia> are unknown tags.
//
// With the key, UnitResource is stat 41h (modifytypes.h), the action tags are read while the data
// loads, and the aura update of such an action runs this code instead of the stock update, so no
// modifier is ever made. For a built, living owner, on each update, the units the stock scan finds
// in range (0x9CFF9A, the action's MaxRange) are filtered: of <ModifyAbstractType> or
// <ModifyProtoID>; owned by the aura's player, or by Gaia with <TargetGaia>; with a resource
// inventory. Each of the first <ModifyTargetLimit> gives <ModifyAmount> per second of its main
// resource (0x4DBEC1), as the gather tick does: taken from its inventory (0x49A5E6, then the state
// check 0x482152, which removes an empty tree), and paid to the owner (0x49A98A), multiplied by the
// player's gather multiplier [player+37Ch]. The time comes from the game clock. A target whose
// proto has flag 24h (an endless resource) pays and is not drained, as in the gather tick.
//
// The stock update also hangs the action's <ModelAttachment> on each target (0x9D053F: the ring under
// units that an aura affects). Running instead of it, this code does the same, through the same
// functions, for the targets that gave resources in this update, and takes the model off the ones that
// stop. A target in two auras keeps its ring until the last one lets go. A model is only a visual of the
// unit: it does not reach the simulation.
//
// The hook is in hooks/unitresource_hooks.asm. The time of each aura's last update and the rings it
// hung live here, so a saved game restarts that clock; nothing else is kept.
#include <algorithm>
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <utility>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifytypes.h"
#include "../patch.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
void UhcUnitResourceAuraHook();
}

namespace {

constexpr std::int32_t kStatUnitResource = 0x41;  // as in unitresource_hooks.asm
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr std::int32_t kFlagEndless = 0x24;        // proto flag tested at 0x4ED062
constexpr std::uint32_t kMaxStepMs = 5000;         // a longer gap (a load, a pause) pays this much
constexpr std::uint32_t kModelTable = 0x00C66240;  // the table of models; read as at 0x9D054A
constexpr std::uint32_t kRingSweepMs = 1000;       // how often the auras that hung rings are checked
constexpr float kMinAmount = 1.0e-6f;
constexpr int kMaxLogLines = 200;

// The list FUN_004A1C55 fills (the engine's dynamic array: data, count, capacity).
struct IdList {
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using UnitTestFn = bool(__thiscall*)(const char* unit);
using ScanFn = void(__thiscall*)(const char* action, IdList* list);
using UnitByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);
using MainResourceFn = std::int32_t(__thiscall*)(const char* unit);
using ListGetFn = float(__thiscall*)(const char* list, std::int32_t resource);
using InventoryAddFn = bool(__thiscall*)(char* inventory, std::int32_t resource, float amount);
using PlayerAddFn = bool(__thiscall*)(char* player, std::int32_t resource, float amount, bool flag);
using CheckStateFn = void(__thiscall*)(char* unit);
using ProtoBitFn = bool(__thiscall*)(const char* proto, std::int32_t bit);
using ModelByIdFn = const void*(__thiscall*)(void* table, std::int32_t model);
using HasModelFn = bool(__thiscall*)(const char* unit, std::int32_t model);
using AttachModelFn = bool(__thiscall*)(char* unit, const void* object, std::int32_t bone, std::int32_t flag);
using RemoveModelFn = void(__thiscall*)(char* unit, std::int32_t model);

const auto kIsBuilt = reinterpret_cast<UnitTestFn>(0x0044DDB4);
const auto kIsDead = reinterpret_cast<UnitTestFn>(0x004802C6);
const auto kScan = reinterpret_cast<ScanFn>(0x009CFF9A);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kMainResource = reinterpret_cast<MainResourceFn>(0x004DBEC1);
const auto kListGet = reinterpret_cast<ListGetFn>(0x0044EFFF);
const auto kInventoryAdd = reinterpret_cast<InventoryAddFn>(0x0049A5E6);
const auto kPlayerAdd = reinterpret_cast<PlayerAddFn>(0x0049A98A);
const auto kCheckState = reinterpret_cast<CheckStateFn>(0x00482152);
const auto kProtoFlag = reinterpret_cast<ProtoBitFn>(0x0045EE02);
const auto kIsAbstractIndex = reinterpret_cast<ProtoBitFn>(0x0044CAC4);
const auto kModelById = reinterpret_cast<ModelByIdFn>(0x00405E83);
const auto kHasModel = reinterpret_cast<HasModelFn>(0x009C28DE);
const auto kAttachModel = reinterpret_cast<AttachModelFn>(0x009C04F3);
const auto kRemoveModel = reinterpret_cast<RemoveModelFn>(0x009C2885);

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Params {
  float amount = 0.0f;
  std::int32_t limit = -1;  // -1: every unit in range
  bool gaia = false;
};

std::map<ActionKey, Params> g_params;
std::map<std::int32_t, std::uint32_t> g_lastUpdate;  // by the owner's unit ID: in ID order, game time
IdList g_list = {};

struct Rings {
  std::int32_t model = -1;
  std::vector<std::int32_t> targets;
};

std::map<std::int32_t, Rings> g_rings;          // by the owner's unit ID
std::map<std::int32_t, std::int32_t> g_ringUsers;  // by the target's unit ID: the auras holding its ring
std::vector<std::int32_t> g_ringTargets;        // the targets of the update that is running
const char* g_ringWorld = nullptr;
std::uint32_t g_ringTime = 0;
std::uint32_t g_nextRingSweep = 0;
bool g_ringModelWarned = false;
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

void ForgetRings() {
  g_rings.clear();
  g_ringUsers.clear();
  g_nextRingSweep = 0;
}

void NewDatabase(char*) {
  g_params.clear();
  g_lastUpdate.clear();
  ForgetRings();
  g_logLines = 0;
}

// Another game: its unit IDs are not the ones held here.
void CheckRingWorld(const char* world, std::uint32_t now) {
  if (world != g_ringWorld || now < g_ringTime) {
    ForgetRings();
    g_ringWorld = world;
  }
  g_ringTime = now;
}

// As the stock update does at 0x9D054A..0x9D059C. False: the unit has no visual yet, and the next
// update tries again. A model that is not in the game is taken as hung, or it would be hung again on
// every update: the engine accepts it and shows nothing.
bool HangRing(const char* world, std::int32_t id, std::int32_t model, std::int32_t bone, const char* tactics) {
  char* unit = const_cast<char*>(kUnitById(world, id));
  void* table = *reinterpret_cast<void**>(kModelTable);
  if (unit == nullptr || table == nullptr) {
    return false;
  }
  if (kHasModel(unit, model)) {
    return true;
  }
  const void* object = kModelById(table, model);
  if (object == nullptr || !kAttachModel(unit, object, bone, 0)) {
    return false;
  }
  if (!kHasModel(unit, model)) {
    if (!g_ringModelWarned) {
      g_ringModelWarned = true;
      uhc::Log(L"unitResourceAuras: the action %d has a <ModelAttachment> that is not in the game: no ring shows",
               Field<std::int32_t>(tactics, 0x04));
    }
  } else if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"unitResourceAuras: ring on unit %d", id);
  }
  return true;
}

void ReleaseRing(const char* world, std::int32_t id, std::int32_t model) {
  const auto users = g_ringUsers.find(id);
  if (users == g_ringUsers.end() || --users->second > 0) {
    return;
  }
  g_ringUsers.erase(users);
  if (char* unit = const_cast<char*>(kUnitById(world, id))) {
    kRemoveModel(unit, model);
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"unitResourceAuras: ring off unit %d", id);
    }
  }
}

void UpdateRings(const char* world, std::int32_t owner, const char* tactics, std::int32_t model, std::int32_t bone) {
  Rings& rings = g_rings[owner];
  rings.model = model;
  std::vector<std::int32_t> held;
  for (const std::int32_t id : g_ringTargets) {
    const bool had = std::find(rings.targets.begin(), rings.targets.end(), id) != rings.targets.end();
    if (had) {
      held.push_back(id);
    } else if (HangRing(world, id, model, bone, tactics)) {
      ++g_ringUsers[id];
      held.push_back(id);
    }
  }
  for (const std::int32_t id : rings.targets) {
    if (std::find(held.begin(), held.end(), id) == held.end()) {
      ReleaseRing(world, id, model);
    }
  }
  rings.targets = std::move(held);
  if (rings.targets.empty()) {
    g_rings.erase(owner);
  }
}

// An aura that dies has no more updates, so its rings are taken off from here.
void RingTick(char* world, std::int32_t) {
  if (g_rings.empty()) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  CheckRingWorld(world, now);
  if (now < g_nextRingSweep) {
    return;
  }
  g_nextRingSweep = now + kRingSweepMs;
  for (auto it = g_rings.begin(); it != g_rings.end();) {
    const char* owner = kUnitById(world, it->first);
    if (owner != nullptr && kIsBuilt(owner) && !kIsDead(owner)) {
      ++it;
      continue;
    }
    for (const std::int32_t id : it->second.targets) {
      ReleaseRing(world, id, it->second.model);
    }
    it = g_rings.erase(it);
  }
}

void ActionTagRead(const uhc::ActionTag& tag) {
  const bool amount = _wcsicmp(tag.name, L"ModifyAmount") == 0;
  const bool limit = _wcsicmp(tag.name, L"ModifyTargetLimit") == 0;
  const bool gaia = _wcsicmp(tag.name, L"TargetGaia") == 0;
  if (!amount && !limit && !gaia) {
    return;
  }
  Params& params = g_params[{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)}];
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  if (amount) {
    params.amount = std::wcstof(text, nullptr);
  } else if (limit) {
    params.limit = std::wcstol(text, nullptr, 10);
  } else {
    params.gaia = std::wcstol(text, nullptr, 10) != 0;
  }
}

bool TypeMatches(const char* tactics, const char* proto) {
  const std::int32_t abstractIndex = Field<std::int16_t>(tactics, 0x9C);
  const std::int32_t protoId = Field<std::int16_t>(tactics, 0x9E);
  if (abstractIndex < 0 && protoId < 0) {
    return false;
  }
  return Field<std::int32_t>(proto, 0x04) == protoId || (abstractIndex >= 0 && kIsAbstractIndex(proto, abstractIndex));
}

}  // namespace

extern "C" void __stdcall UhcUnitResourceAura(const char* action) {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* owner = Field<const char*>(action, 0x10);
  const char* tactics = Field<const char*>(action, 0x04);
  if (world == nullptr || owner == nullptr || !kIsBuilt(owner) || kIsDead(owner)) {
    return;
  }
  const char* ownerProto = Field<const char*>(owner, 0x5C);
  char* player = Field<char*>(owner, 0x44);
  if (ownerProto == nullptr || player == nullptr) {
    return;
  }
  const auto found = g_params.find({Field<std::int32_t>(ownerProto, 0x04), Field<std::int32_t>(tactics, 0x04)});
  if (found == g_params.end() || found->second.amount <= kMinAmount) {
    return;
  }
  const Params& params = found->second;
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  CheckRingWorld(world, now);
  const auto [last, isNew] = g_lastUpdate.try_emplace(Field<std::int32_t>(owner, 0x10), now);
  const std::uint32_t since = now - last->second;
  if (isNew || since == 0) {
    return;
  }
  last->second = now;
  const float seconds = static_cast<float>(since > kMaxStepMs ? kMaxStepMs : since) / 1000.0f;
  const float amount = params.amount * seconds;

  const std::int32_t ownerPlayer = Field<std::int32_t>(player, 0x00);
  const float multiplier = Field<float>(player, 0x37C);
  g_list.count = 0;
  kScan(action, &g_list);
  g_ringTargets.clear();
  std::int32_t gathered = 0;
  for (std::int32_t i = 0; i < g_list.count; ++i) {
    if (params.limit >= 0 && gathered >= params.limit) {
      break;
    }
    char* target = const_cast<char*>(kUnitById(world, g_list.data[i]));
    if (target == nullptr || target == owner) {
      continue;
    }
    const char* targetProto = Field<const char*>(target, 0x5C);
    const char* targetPlayer = Field<const char*>(target, 0x44);
    if (targetProto == nullptr || targetPlayer == nullptr || !TypeMatches(tactics, targetProto)) {
      continue;
    }
    const std::int32_t targetOwner = Field<std::int32_t>(targetPlayer, 0x00);
    if (targetOwner != ownerPlayer && !(params.gaia && targetOwner == 0)) {
      continue;
    }
    const char* record = Field<const char*>(target, 0xB4);
    char* inventory = record == nullptr ? nullptr : Field<char*>(record, 0x94);
    if (inventory == nullptr) {
      continue;
    }
    std::int32_t resource = Field<std::int32_t>(inventory, 0x10);
    if (resource == -1) {
      resource = kMainResource(target);
    }
    if (resource < 0) {
      continue;
    }
    const float have = kListGet(inventory + 4, resource);
    if (have <= kMinAmount) {
      continue;
    }
    const float take = have < amount ? have : amount;
    ++gathered;
    g_ringTargets.push_back(Field<std::int32_t>(target, 0x10));  // the state check below may remove it
    if (!kProtoFlag(targetProto, kFlagEndless)) {
      kInventoryAdd(inventory, resource, -take);
      kCheckState(target);
    }
    kPlayerAdd(player, resource, take * multiplier, false);
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"unitResourceAuras: unit %d (%hs) took %.3f of resource %d from unit %d (%hs), %.1f left",
               Field<std::int32_t>(owner, 0x10), Field<const char*>(ownerProto, 0x10), static_cast<double>(take),
               resource, Field<std::int32_t>(target, 0x10), Field<const char*>(targetProto, 0x10),
               static_cast<double>(have - take));
    }
  }
  const std::int32_t model = Field<std::int32_t>(tactics, 0xA4);
  if (model != -1) {
    UpdateRings(world, Field<std::int32_t>(owner, 0x10), tactics, model, Field<std::int32_t>(tactics, 0xA8));
  }
}

namespace uhc {

Outcome ApplyUnitResourceAuras(const Config& config) {
  const Config::Args* args = config.First("unitResourceAuras");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"unitResourceAuras: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("unitResourceAuras",
                 {&sites::kUnitResourceAuraEntry, &sites::kAuraScan, &sites::kInventoryAdd, &sites::kCheckState,
                  &sites::kMainResource, &sites::kUnitIsDead, &sites::kPlayerAddResource, &sites::kIsBuilt,
                  &sites::kUnitById, &sites::kProtoFlag, &sites::kIsAbstractIndex, &sites::kResListGet,
                  &sites::kAuraModelBlock, &sites::kModelById, &sites::kUnitHasModel, &sites::kUnitAttachModel,
                  &sites::kUnitRemoveModel})) {
    return Outcome::kFailed;
  }
  if (!AddModifyType(L"UnitResource", kStatUnitResource) || !AddActionTagHandler(&ActionTagRead) ||
      !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&RingTick)) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!WriteJmp(sites::kUnitResourceAuraEntry.va, reinterpret_cast<const void*>(&UhcUnitResourceAuraHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"unitResourceAuras: AutoRangedModify actions with ModifyType UnitResource gather from units in range%ls "
      L"(multiplayer unverified)",
      log ? L", the first takes logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
