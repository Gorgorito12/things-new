// resourceGatherAuras: stat modifiers that change a unit's gather rate for one kind of target or one
// resource only.
//
// Stock: the modifier stat GatherRate (<ModifyType>GatherRate</ModifyType>) multiplies a unit's rate
// for everything it gathers (the record's +24h, read at 0x4ECFE9).
//
// With the key, seven more names are ModifyType stats (modifytypes.h): by what is gathered,
// MineGatherRate (AbstractMine), TreeGatherRate (Tree), FarmingGatherRate (AbstractFarm) and
// NaturalFoodGatherRate (food from anything else); and by resource, FoodGatherRate, WoodGatherRate
// and GoldGatherRate. The aura code needs no change: it gives the units in range a modifier of that
// stat, as for any stat, and the record recompute ignores it. The gather tick FUN_004ECD87 multiplies
// its rate by the dance factor of 0x4ECD39 (0x4ED02A). The call goes to a wrapper that multiplies in
// the stock sum 0x4B3C7D of the unit's modifiers of the stats that fit this target and resource,
// each from 1.0, with the GatherRate reader's rule: no modifier, or a sum below 1e-6, counts as 1.0.
// A unit with no modifier record pays one load.
//
// The aura update hangs the action's <ModelAttachment> on every unit in range, whatever it does, so a
// villager cutting wood under a MineGatherRate aura would wear a ring that means nothing. For these
// stats only, the two calls of the update that decide it (0x9D0584, has it; 0x9D06DC, a new target)
// go through wrappers that give the ring to the units gathering something the stat fits, and take it
// off the others, by the same rule as the factor. The hooks are in hooks/gatherauras_hooks.asm.
#include <bit>
#include <cstdint>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifiers.h"
#include "../modifytypes.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
void UhcGatherAuraCall();
void UhcGatherAuraHasRingHook();
void UhcGatherAuraHangRingHook();
}

namespace {

constexpr std::int32_t kStatMine = 0x42;
constexpr std::int32_t kStatTree = 0x43;
constexpr std::int32_t kStatFarming = 0x44;
constexpr std::int32_t kStatNaturalFood = 0x45;
constexpr std::int32_t kStatFood = 0x46;
constexpr std::int32_t kStatWood = 0x47;
constexpr std::int32_t kStatGold = 0x48;
constexpr std::int32_t kResourceGold = 0;
constexpr std::int32_t kResourceWood = 1;
constexpr std::int32_t kResourceFood = 2;
constexpr float kMinFactor = 1.0e-6f;
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr std::uint32_t kGatherVtable = 0x00B97880;  // the Gather action
constexpr std::uint8_t kGatheringState = 5;          // [action+61h] while the tick runs (0x4ECC8E)

struct ModifierArray {
  const char* const* data;
  std::int32_t count;
};

using ModifierSumFn = bool(__thiscall*)(void* unused, float* value, const ModifierArray* list, std::int32_t stat);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using UnitByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);
const auto kModifierSum = reinterpret_cast<ModifierSumFn>(0x004B3C7D);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
using HasModelFn = bool(__thiscall*)(const char* unit, std::int32_t model);
using HangModelFn = bool(__thiscall*)(char* unit, const void* object, std::int32_t bone, std::int32_t flag);
using RemoveModelFn = void(__thiscall*)(char* unit, std::int32_t model);
const auto kHasModel = reinterpret_cast<HasModelFn>(0x009C28DE);
const auto kHangModel = reinterpret_cast<HangModelFn>(0x009C04F3);
const auto kRemoveModel = reinterpret_cast<RemoveModelFn>(0x009C2885);

std::int32_t g_mineType = -1;
std::int32_t g_treeType = -1;
std::int32_t g_farmType = -1;
bool g_log = false;
int g_logLines = 0;
constexpr int kMaxLogLines = 200;
std::vector<const char*> g_matched;  // only the game thread touches it

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// The stock sum over the unit's modifiers of one stat, from 1.0.
float StatFactor(const char* list, std::int32_t stat) {
  g_matched.clear();
  auto visit = [stat](const char* action) {
    if (Field<std::int32_t>(action, 0x64) == stat) {
      g_matched.push_back(action);
    }
    return true;
  };
  if (uhc::modifiers::WalkModifiers(list, visit, 0) != uhc::modifiers::Walk::kDone || g_matched.empty()) {
    return 1.0f;
  }
  const ModifierArray array{g_matched.data(), static_cast<std::int32_t>(g_matched.size())};
  float factor = 1.0f;
  if (!kModifierSum(nullptr, &factor, &array, stat) || factor < kMinFactor) {
    return 1.0f;
  }
  return factor;
}

// What a Gather action gathers, as the stats see it.
struct Gathers {
  const char* proto;
  std::int32_t resource;
};

Gathers WhatItGathers(const char* action) {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* target = kUnitById(Field<const char*>(game, 0x13C), Field<std::int32_t>(action, 0x14));
  return {target == nullptr ? nullptr : Field<const char*>(target, 0x5C), Field<std::int32_t>(action, 0x70)};
}

// True when the stat changes what this Gather action gathers: the rule of UhcGatherAuraFactor.
bool StatFits(std::int32_t stat, const Gathers& what) {
  switch (stat) {
    case kStatFood:
      return what.resource == kResourceFood;
    case kStatWood:
      return what.resource == kResourceWood;
    case kStatGold:
      return what.resource == kResourceGold;
    default:
      break;
  }
  if (what.proto == nullptr) {
    return false;
  }
  const bool mine = kProtoIsType(what.proto, g_mineType);
  const bool tree = !mine && kProtoIsType(what.proto, g_treeType);
  const bool farm = !mine && !tree && kProtoIsType(what.proto, g_farmType);
  switch (stat) {
    case kStatMine:
      return mine;
    case kStatTree:
      return tree;
    case kStatFarming:
      return farm;
    case kStatNaturalFood:
      return !mine && !tree && !farm && what.resource == kResourceFood;
    default:
      return false;
  }
}

bool IsGatherStat(const char* auraAction) {
  const std::int32_t stat = Field<std::int8_t>(Field<const char*>(auraAction, 0x04), 0xB8);
  return stat >= kStatMine && stat <= kStatGold;
}

// True when the unit is gathering, now, something the aura's stat changes.
bool GetsTheEffect(const char* auraAction, const char* unit) {
  const char* manager = Field<const char*>(unit, 0x58);
  const char* current = manager == nullptr ? nullptr : Field<const char*>(manager, 0x24);
  if (current == nullptr || Field<std::uint32_t>(current, 0) != kGatherVtable ||
      Field<std::uint8_t>(current, 0x61) != kGatheringState) {
    return false;
  }
  return StatFits(Field<std::int8_t>(Field<const char*>(auraAction, 0x04), 0xB8), WhatItGathers(current));
}

}  // namespace

// Replaces the has-it call in the aura update, for a unit that stays in range. True keeps the update
// from hanging the model, so it answers true for a unit that must not have it.
extern "C" bool __stdcall UhcGatherAuraHasRing(const char* auraAction, char* unit, std::int32_t model) {
  const bool has = kHasModel(unit, model);
  if (!IsGatherStat(auraAction) || GetsTheEffect(auraAction, unit)) {
    return has;
  }
  if (has) {
    kRemoveModel(unit, model);
  }
  return true;
}

// Replaces the hang call in the aura update, for a unit that has just come into range.
extern "C" bool __stdcall UhcGatherAuraHangRing(const char* auraAction, char* unit, const void* object,
                                                std::int32_t bone, std::int32_t flag) {
  if (IsGatherStat(auraAction) && !GetsTheEffect(auraAction, unit)) {
    return false;
  }
  return kHangModel(unit, object, bone, flag);
}

// From the wrapper of the dance factor's call in the gather tick. `action` is the Gather action:
// [+10h] the gatherer, [+14h] the target's ID, [+70h] the resource.
extern "C" float __stdcall UhcGatherAuraFactor(const char* action) {
  const char* unit = Field<const char*>(action, 0x10);
  const char* list = unit == nullptr ? nullptr : uhc::modifiers::ModifierList(unit);
  if (list == nullptr) {
    return 1.0f;
  }
  const Gathers what = WhatItGathers(action);
  const char* proto = what.proto;
  const std::int32_t resource = what.resource;
  float factor = 1.0f;
  if (proto != nullptr) {
    if (kProtoIsType(proto, g_mineType)) {
      factor *= StatFactor(list, kStatMine);
    } else if (kProtoIsType(proto, g_treeType)) {
      factor *= StatFactor(list, kStatTree);
    } else if (kProtoIsType(proto, g_farmType)) {
      factor *= StatFactor(list, kStatFarming);
    } else if (resource == kResourceFood) {
      factor *= StatFactor(list, kStatNaturalFood);
    }
  }
  if (resource == kResourceFood) {
    factor *= StatFactor(list, kStatFood);
  } else if (resource == kResourceWood) {
    factor *= StatFactor(list, kStatWood);
  } else if (resource == kResourceGold) {
    factor *= StatFactor(list, kStatGold);
  }
  if (g_log && factor != 1.0f && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"resourceGatherAuras: unit %d, resource %d, target %hs: x%.3f", Field<std::int32_t>(unit, 0x10), resource,
             proto == nullptr ? "?" : Field<const char*>(proto, 0x10), static_cast<double>(factor));
  }
  return factor;
}

namespace uhc {

Outcome ApplyResourceGatherAuras(const Config& config) {
  const Config::Args* args = config.First("resourceGatherAuras");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"resourceGatherAuras: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("resourceGatherAuras", {&sites::kGatherDanceCall, &sites::kSnareCollector, &sites::kSnareModifierSum,
                                         &sites::kSnareModifierSumEnd, &sites::kSnareModifierSumTactic, &sites::kIsA,
                                         &sites::kUnitById, &sites::kAuraHasModelCall, &sites::kAuraHangModelCall,
                                         &sites::kUnitHasModel, &sites::kUnitAttachModel, &sites::kUnitRemoveModel})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType("AbstractMine", &g_mineType) || !RequestAbstractUnitType("Tree", &g_treeType) ||
      !RequestAbstractUnitType("AbstractFarm", &g_farmType) || !AddModifyType(L"MineGatherRate", kStatMine) ||
      !AddModifyType(L"TreeGatherRate", kStatTree) || !AddModifyType(L"FarmingGatherRate", kStatFarming) ||
      !AddModifyType(L"NaturalFoodGatherRate", kStatNaturalFood) || !AddModifyType(L"FoodGatherRate", kStatFood) ||
      !AddModifyType(L"WoodGatherRate", kStatWood) || !AddModifyType(L"GoldGatherRate", kStatGold)) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!WriteCall(sites::kGatherDanceCall.va, reinterpret_cast<const void*>(&UhcGatherAuraCall)) ||
      !WriteCall(sites::kAuraHasModelCall.va, reinterpret_cast<const void*>(&UhcGatherAuraHasRingHook)) ||
      !WriteCall(sites::kAuraHangModelCall.va, reinterpret_cast<const void*>(&UhcGatherAuraHangRingHook))) {
    return Outcome::kFailed;
  }
  Log(L"resourceGatherAuras: modifiers can change the gather rate of one kind of target or one resource%ls "
      L"(multiplayer unverified)",
      log ? L", the first factors logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
