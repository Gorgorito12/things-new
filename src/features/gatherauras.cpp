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
// A unit with no modifier record pays one load. The hook is in hooks/gatherauras_hooks.asm.
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

}  // namespace

// From the wrapper of the dance factor's call in the gather tick. `action` is the Gather action:
// [+10h] the gatherer, [+14h] the target's ID, [+70h] the resource.
extern "C" float __stdcall UhcGatherAuraFactor(const char* action) {
  const char* unit = Field<const char*>(action, 0x10);
  const char* list = unit == nullptr ? nullptr : uhc::modifiers::ModifierList(unit);
  if (list == nullptr) {
    return 1.0f;
  }
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* target = kUnitById(Field<const char*>(game, 0x13C), Field<std::int32_t>(action, 0x14));
  const char* proto = target == nullptr ? nullptr : Field<const char*>(target, 0x5C);
  const std::int32_t resource = Field<std::int32_t>(action, 0x70);
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
                                         &sites::kUnitById})) {
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
  if (!WriteCall(sites::kGatherDanceCall.va, reinterpret_cast<const void*>(&UhcGatherAuraCall))) {
    return Outcome::kFailed;
  }
  Log(L"resourceGatherAuras: modifiers can change the gather rate of one kind of target or one resource%ls "
      L"(multiplayer unverified)",
      log ? L", the first factors logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
