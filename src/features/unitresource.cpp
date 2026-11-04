// unitResourceAuras: an AutoRangedModify action with <ModifyType>UnitResource</ModifyType> gathers
// from the units around it, for its owner, with DE's tags.
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
// The hook is in hooks/unitresource_hooks.asm. The time of each aura's last update lives here, so a
// saved game restarts that clock; nothing else is kept.
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifytypes.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
void UhcUnitResourceAuraHook();
}

namespace {

constexpr std::int32_t kStatUnitResource = 0x41;  // as in unitresource_hooks.asm
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr std::int32_t kFlagEndless = 0x24;        // proto flag tested at 0x4ED062
constexpr std::uint32_t kMaxStepMs = 5000;         // a longer gap (a load, a pause) pays this much
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
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

void NewDatabase(char*) {
  g_params.clear();
  g_lastUpdate.clear();
  g_logLines = 0;
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
                  &sites::kUnitById, &sites::kProtoFlag, &sites::kIsAbstractIndex, &sites::kResListGet})) {
    return Outcome::kFailed;
  }
  if (!AddModifyType(L"UnitResource", kStatUnitResource) || !AddActionTagHandler(&ActionTagRead) ||
      !OnDatabaseLoad(&NewDatabase)) {
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
