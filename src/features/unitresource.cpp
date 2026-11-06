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
// Also read: <IncludeGaia> (as <TargetGaia>), <DeadExclusive> and <DoNotIgnoreDead> (dead targets are skipped
// without them), <SingleUnit> (one target, kept until it is used up) and <ForbidUnitType>. The Data subtypes
// ModifyRate and ModifyAmount change the amount for one player's copy of the action, and
// <ShowUnitResourceActionRates> in a proto writes what its auras pay in the unit panel's rate row.
//
// The hook is in hooks/unitresource_hooks.asm. The time of each aura's last update and the rings it
// hung live here, so a saved game restarts that clock; nothing else is kept.
#include <algorithm>
#include <compare>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "../actiontags.h"
#include "../aurastacking.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifytypes.h"
#include "../patch.h"
#include "../prototags.h"
#include "../techsubtypes.h"
#include "../unitpanel.h"
#include "../unitmodels.h"
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
constexpr std::uint32_t kRingSweepMs = 1000;       // how often the auras that hung rings are checked
constexpr float kMinAmount = 1.0e-6f;
constexpr int kMaxLogLines = 200;
constexpr std::size_t kMaxResources = 8;           // rates kept per aura; the game has 7 (food to ships)
constexpr std::uint32_t kRateFreshMs = 8000;       // a rate older than this no longer shows: the aura stopped
constexpr std::int32_t kAutoGatherAction = 0x1D;   // the unit action type the stock panel asks for

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
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
using UnitActionFn = const char*(__thiscall*)(const char* manager, std::int32_t type);
using AutoGatherRateFn = float(__thiscall*)(const char* action, std::int32_t resource);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
const auto kUnitAction = reinterpret_cast<UnitActionFn>(0x00485CAC);
const auto kAutoGatherRate = reinterpret_cast<AutoGatherRateFn>(0x0049EBE4);

// The engine's string: one pointer to a wide, reference-counted buffer; null is empty.
struct BString {
  wchar_t* text;
};
const wchar_t* const kRateLabelFormat = reinterpret_cast<const wchar_t*>(0x00C36580);  // "%s (<icon=...>):"
using BStringFormatFn = void(__cdecl*)(BString* out, const wchar_t* format, ...);
using BStringFreeFn = void(__thiscall*)(BString* self);
using ResourceIconFn = const wchar_t*(__thiscall*)(const char* database, std::int32_t resource);
const auto kBStringFormat = reinterpret_cast<BStringFormatFn>(0x00444EFB);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kResourceIcon = reinterpret_cast<ResourceIconFn>(0x00706EFB);

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

enum class DeadTargets { kSkip, kInclude, kOnly };

struct Params {
  float amount = 0.0f;
  std::int32_t limit = -1;  // -1: every unit in range
  bool gaia = false;        // <TargetGaia> or <IncludeGaia>
  bool single = false;      // <SingleUnit>: one target, kept until it is used up
  DeadTargets dead = DeadTargets::kSkip;  // <DoNotIgnoreDead>, <DeadExclusive>
  std::wstring forbidName;                // <ForbidUnitType>, a unit type or a proto
  std::int32_t forbidId = -2;             // -2: not looked up yet, -1: none or unknown
};

// One aura of one unit: a building has several (a mine's, a tree's...), each with its own clock.
struct AuraKey {
  std::int32_t owner;
  std::int32_t name;
  auto operator<=>(const AuraKey&) const = default;
};

struct AuraState {
  std::uint32_t time = 0;                   // game time of the last update
  float perSecond[kMaxResources] = {};      // what that update paid, for the panel
  std::int32_t singleTarget = -1;           // <SingleUnit>: the unit it is working
};

struct TechAmount {
  std::int32_t name;  // the action's name: a reused pointer with another name is ignored
  float value;
};

std::map<ActionKey, Params> g_params;
std::map<AuraKey, AuraState> g_auras;                    // in owner, then action order
std::unordered_map<const char*, TechAmount> g_techAmount;  // by the player's copy of the action
std::set<std::int32_t> g_showRates;                      // proto IDs with <ShowUnitResourceActionRates>
IdList g_list = {};

struct Rings {
  std::int32_t model = -1;
  std::vector<std::int32_t> targets;
};

struct RingUser {
  std::int32_t unit;
  std::int32_t model;
  auto operator<=>(const RingUser&) const = default;
};

std::map<AuraKey, Rings> g_rings;           // by aura
std::map<RingUser, std::int32_t> g_ringUsers;  // the auras holding a model on a unit
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
  g_auras.clear();
  g_techAmount.clear();
  g_showRates.clear();
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

// False: the unit has no visual yet, and the next update tries again. A model that is not in the game is
// taken as hung, or it would be hung again on every update: the engine accepts it and shows nothing.
bool HangRing(const char* world, std::int32_t id, std::int32_t model, std::int32_t bone, const char* tactics) {
  char* unit = const_cast<char*>(kUnitById(world, id));
  const uhc::ModelHang hang = uhc::HangUnitModel(unit, model, bone);
  if (hang == uhc::ModelHang::kRetry) {
    return false;
  }
  if (hang == uhc::ModelHang::kAlready) {
    return true;
  }
  if (hang == uhc::ModelHang::kNotInGame) {
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
  const auto users = g_ringUsers.find({id, model});
  if (users == g_ringUsers.end() || --users->second > 0) {
    return;
  }
  g_ringUsers.erase(users);
  if (char* unit = const_cast<char*>(kUnitById(world, id))) {
    uhc::RemoveUnitModel(unit, model);
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"unitResourceAuras: ring off unit %d", id);
    }
  }
}

void UpdateRings(const char* world, const AuraKey& owner, const char* tactics, std::int32_t model, std::int32_t bone) {
  Rings& rings = g_rings[owner];
  rings.model = model;
  std::vector<std::int32_t> held;
  for (const std::int32_t id : g_ringTargets) {
    const bool had = std::find(rings.targets.begin(), rings.targets.end(), id) != rings.targets.end();
    if (had) {
      held.push_back(id);
    } else if (HangRing(world, id, model, bone, tactics)) {
      ++g_ringUsers[{id, model}];
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
    const char* owner = kUnitById(world, it->first.owner);
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
  const bool gaia = _wcsicmp(tag.name, L"TargetGaia") == 0 || _wcsicmp(tag.name, L"IncludeGaia") == 0;
  const bool single = _wcsicmp(tag.name, L"SingleUnit") == 0;
  const bool ignoreDead = _wcsicmp(tag.name, L"DoNotIgnoreDead") == 0;
  const bool deadOnly = _wcsicmp(tag.name, L"DeadExclusive") == 0;
  const bool forbid = _wcsicmp(tag.name, L"ForbidUnitType") == 0 || _wcsicmp(tag.name, L"ForbidAbstractType") == 0;
  if (!amount && !limit && !gaia && !single && !ignoreDead && !deadOnly && !forbid) {
    return;  // <ForceUpdateMode> stays unread: the take already follows the game time between updates
  }
  Params& params = g_params[{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)}];
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  // These flags may be written empty.
  const bool on = text[0] == L'\0' || std::wcstol(text, nullptr, 10) != 0;
  if (amount) {
    params.amount = std::wcstof(text, nullptr);
  } else if (limit) {
    params.limit = std::wcstol(text, nullptr, 10);
  } else if (gaia) {
    params.gaia = params.gaia || on;
  } else if (single) {
    params.single = on;
  } else if (forbid) {
    params.forbidName = text;
  } else if (deadOnly) {
    params.dead = on ? DeadTargets::kOnly : params.dead;
  } else if (on && params.dead == DeadTargets::kSkip) {
    params.dead = DeadTargets::kInclude;
  }
}

// <ForbidUnitType>, through the table <UnitType> reads, on the first update: every name is known by then.
std::int32_t ForbiddenType(Params& params) {
  if (params.forbidId != -2) {
    return params.forbidId;
  }
  params.forbidId = -1;
  if (params.forbidName.empty()) {
    return -1;
  }
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (database == nullptr) {
    return -1;
  }
  std::string name;
  for (const wchar_t c : params.forbidName) {
    name.push_back(static_cast<char>(c));
  }
  const char* table = database + 0x190;
  std::int32_t id = -1;
  const std::int32_t bucket = kNameBucket(table, name.c_str());
  if (kNameFind(table, name.c_str(), bucket, &id)) {
    params.forbidId = id;
  } else {
    uhc::Log(L"unitResourceAuras: <ForbidUnitType>%hs names no unit type or proto; ignored", name.c_str());
  }
  return params.forbidId;
}

// ModifyAmount or ModifyRate on an action: the player's copy gets its own amount, from the tag's as base.
void ChangeAmount(char* action, const char*, const char* proto, float amount, std::uint8_t relativity, bool unapply) {
  const std::int32_t name = Field<std::int32_t>(action, 0x04);
  const auto params = g_params.find({Field<std::int32_t>(proto, 0x04), name});
  if (params == g_params.end()) {
    return;  // not an aura of this key
  }
  const float base = params->second.amount;
  TechAmount& slot = g_techAmount.emplace(action, TechAmount{name, base}).first->second;
  if (slot.name != name) {
    slot = TechAmount{name, base};
  }
  const float before = slot.value;
  kEffectValue(relativity, &slot.value, base, amount, unapply);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"unitResourceAuras: proto %d, action %d, relativity %u, amount %g%ls: %g -> %g",
             Field<std::int32_t>(proto, 0x04), name, relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", static_cast<double>(before), static_cast<double>(slot.value));
  }
}

bool __cdecl ReadShowRates(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  if (text == nullptr || text[0] == L'\0' || std::wcstol(text, nullptr, 10) != 0) {
    g_showRates.insert(Field<std::int32_t>(proto, 0x04));
  }
  return true;
}

// The minimized interface's row: what the unit's auras paid, per resource, on top of its own AutoGather,
// which the stock row just wrote in these two gadgets.
bool __stdcall UhcUnitResourceRow(const char* panel, const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (proto == nullptr || world == nullptr || database == nullptr || g_showRates.count(Field<std::int32_t>(proto, 0x04)) == 0 ||
      !kIsBuilt(unit)) {
    return false;
  }
  float rates[kMaxResources] = {};
  const std::int32_t owner = Field<std::int32_t>(unit, 0x10);
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  bool any = false;
  for (auto it = g_auras.lower_bound({owner, INT32_MIN}); it != g_auras.end() && it->first.owner == owner; ++it) {
    if (now - it->second.time > kRateFreshMs) {
      continue;
    }
    for (std::size_t r = 0; r < kMaxResources; ++r) {
      rates[r] += it->second.perSecond[r];
      any = any || it->second.perSecond[r] > kMinAmount;
    }
  }
  if (!any) {
    return false;  // the stock row stands
  }
  const char* manager = Field<const char*>(unit, 0x58);
  const char* autoGather = manager == nullptr ? nullptr : kUnitAction(manager, kAutoGatherAction);
  const std::int32_t resources = Field<std::int32_t>(database, 0x80);
  std::wstring row;
  for (std::int32_t r = 0; r < resources && r < static_cast<std::int32_t>(kMaxResources); ++r) {
    const float rate = rates[r] + (autoGather != nullptr ? kAutoGatherRate(autoGather, r) : 0.0f);
    if (rate <= kMinAmount) {
      continue;
    }
    // The stock label with no name: only the icon, so that the row is short.
    BString label{nullptr};
    kBStringFormat(&label, kRateLabelFormat, L"", kResourceIcon(database, r));
    wchar_t text[16];
    swprintf_s(text, L" %.2f ", static_cast<double>(rate));
    if (label.text != nullptr) {
      row += label.text;
    }
    row += text;
    kBStringFree(&label);
  }
  // All in the label: the value gadget holds one number, and a building can pay several resources.
  return uhc::SetUnitPanelRow(panel, row.c_str(), L"");
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
  const AuraKey auraKey{Field<std::int32_t>(owner, 0x10), Field<std::int32_t>(tactics, 0x04)};
  const std::int32_t model = Field<std::int32_t>(tactics, 0xA4);
  // An action a tech turned off (ActionEnable) still gets here: bit 0 of [tactics+64h] is <Active>.
  const auto* flags = Field<const std::uint8_t*>(tactics, 0x64);
  if (flags != nullptr && (flags[0] & 1) == 0) {
    if (model != -1 && g_rings.count(auraKey) != 0) {
      g_ringTargets.clear();
      UpdateRings(world, auraKey, tactics, model, Field<std::int32_t>(tactics, 0xA8));
    }
    g_auras.erase(auraKey);
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
  Params& params = found->second;
  float perSecondAmount = params.amount;
  const auto tech = g_techAmount.find(tactics);
  if (tech != g_techAmount.end() && tech->second.name == auraKey.name) {
    perSecondAmount = tech->second.value;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  CheckRingWorld(world, now);
  const auto [aura, isNew] = g_auras.try_emplace(auraKey);
  AuraState& state = aura->second;
  const std::uint32_t since = now - state.time;
  if (isNew || since == 0) {
    state.time = now;
    return;
  }
  state.time = now;
  const float seconds = static_cast<float>(since > kMaxStepMs ? kMaxStepMs : since) / 1000.0f;
  const float amount = perSecondAmount * seconds;
  float paid[kMaxResources] = {};
  const std::int32_t forbidden = ForbiddenType(params);

  const std::int32_t ownerPlayer = Field<std::int32_t>(player, 0x00);
  const float multiplier = Field<float>(player, 0x37C);
  g_list.count = 0;
  kScan(action, &g_list);
  g_ringTargets.clear();
  if (params.single && state.singleTarget >= 0) {
    // The unit it was working goes first, so it finishes one before the next.
    for (std::int32_t i = 1; i < g_list.count; ++i) {
      if (g_list.data[i] == state.singleTarget) {
        std::swap(g_list.data[0], g_list.data[i]);
        break;
      }
    }
  }
  const std::int32_t limit = params.single ? 1 : params.limit;
  std::int32_t gathered = 0;
  for (std::int32_t i = 0; i < g_list.count; ++i) {
    if (limit >= 0 && gathered >= limit) {
      break;
    }
    char* target = const_cast<char*>(kUnitById(world, g_list.data[i]));
    if (target == nullptr || target == owner) {
      continue;
    }
    const char* targetProto = Field<const char*>(target, 0x5C);
    const char* targetPlayer = Field<const char*>(target, 0x44);
    if (targetProto == nullptr || targetPlayer == nullptr || !TypeMatches(tactics, targetProto) ||
        (forbidden >= 0 && kProtoIsType(targetProto, forbidden))) {
      continue;
    }
    const std::int32_t targetOwner = Field<std::int32_t>(targetPlayer, 0x00);
    if (targetOwner != ownerPlayer && !(params.gaia && targetOwner == 0)) {
      continue;
    }
    // Not 0x4802C6, the owner's test above: a carcass does not pass it. As the game's own, slot A4h.
    const bool dead = !(*reinterpret_cast<UnitTestFn const* const*>(target))[0xA4 / 4](target);
    if ((dead && params.dead == DeadTargets::kSkip) || (!dead && params.dead == DeadTargets::kOnly)) {
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
    if (!uhc::AuraClaim(world, Field<std::int32_t>(ownerProto, 0x04), auraKey.name, auraKey.owner,
                        Field<std::int32_t>(target, 0x10), now)) {
      continue;
    }
    const float take = have < amount ? have : amount;
    ++gathered;
    state.singleTarget = Field<std::int32_t>(target, 0x10);
    if (static_cast<std::size_t>(resource) < kMaxResources) {
      paid[resource] += take * multiplier;
    }
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
  for (std::size_t r = 0; r < kMaxResources; ++r) {
    state.perSecond[r] = paid[r] / seconds;
  }
  if (model != -1) {
    UpdateRings(world, auraKey, tactics, model, Field<std::int32_t>(tactics, 0xA8));
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
                  &sites::kUnitRemoveModel, &sites::kIsA, &sites::kUnitAliveSlot})) {
    return Outcome::kFailed;
  }
  if (!AddModifyType(L"UnitResource", kStatUnitResource) || !AddActionTagHandler(&ActionTagRead) ||
      !AddProtoTagHandler("ShowUnitResourceActionRates", &ReadShowRates) ||
      !AddTechActionSubtype("ModifyAmount", &ChangeAmount) || !AddTechActionSubtype("ModifyRate", &ChangeAmount) ||
      !AddUnitPanelRow(&UhcUnitResourceRow) || !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&RingTick)) {
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
