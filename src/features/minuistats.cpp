// minUIStats: the minimized in-game interface shows what the normal one shows, and more, in rows a data file lists.
//
//   minUIStats [file]      (default minuirows.xml in the build's data folder; without it, the rows below)
//
// The minimized selection panel (uiunitselectionmin.xml) gets top-level formatText gadgets the DLL fills:
// - <row gadget="..." item="speed" label="Speed: " types="Unit"/>: one catalog item (kItems) per gadget;
// - <bigPanelRows gadget="unitselectionpanel-uhcRow%d" first="3" skip="auto,speed"/>: the rows the normal
//   interface's stat panel shows (FUN_004D70ED), mirrored: the fill runs for these gadgets and its rows are kept
//   in order, less the ones the minimized panel already shows ("auto") and the kinds `skip` names.
//   With stockRows="take" the original attack rows (StackLabel0..2) are written from the same list, so that every
//   attack row gets rofIcon="..." (the action's ROF and that icon after its damage) and the ability attacks the unit
//   cannot use are left out (ActionEnabled; abilities="all" keeps them). With projectilesIcon="...", an attack that
//   fires more than one projectile before its reload gets shots x projectiles and that icon after its ROF (the
//   tactics' <NumberOfShots> and <NumberProjectiles>, read by shots.cpp: unitinfo.h, Shots).
// - "[string:ID]" in a text, label or tip: that string of the game's string table, as the player's language has it
//   (resolved when shown: "[string:68852]" is "Hitpoints" in the English table).
// - <replace row="..." stock="a,b"/>: while that row shows, those original gadgets are hidden (the hit points and
//   resists rows with icons over the original ones, which the layout keeps in place for the panel without the key);
//   <stockLabel gadget="..." text="..."/>: an original label's text, written over the game's while it shows.
// - join="line" on a text= row: each part on a line of its own (a two-line block).
// A row whose gadget the selection's stack portraits cover (one per unit type, placed by the panel each fill), or
// that a shown <avoid gadget="..."/> covers, is hidden for that fill (a bigPanelRows gadget is skipped and the rows
// go on in the next one); overlap="show" on a row or bigPanelRows keeps it.
// It also shows a building's armor in the stock resists gadgets (the minimized block's test of abstract type Unit
// goes), and adds a {uhc...} data ref per item for a layout's own texts (datarefs.h).
// The normal interface is unchanged: it has none of these gadgets, and every write is to a gadget found by name.
// docs/how-it-works.md, "minUIStats"; docs/unit-panel-catalog.md.
#include <windows.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cwchar>
#include <map>
#include <string>
#include <vector>

#include "../datarefs.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unitpanel.h"
#include "../unitinfo.h"
#include "../unittypes.h"
#include "../xmllist.h"

extern "C" {
// 1 while minUIStats runs the stat panel fill for the minimized panel's rows (hooks/minuistats_hooks.asm).
std::uint32_t g_uhcMinUiForceFill = 0;
void UhcStatFillMinGate();
void UhcMinBlockChoice();
}

namespace {

// ---- Engine layout (docs/engine-symbols.md, "Unit panels") ----

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // +13Ch world, +140h database, +920h the UI's view
constexpr std::uint32_t kUiGlobal = 0x00C67310;    // [[+920h]+13Ch]: the data refs' current unit ID
constexpr std::uint32_t kUiManager = 0x00C66244;   // [[+44h]]: the gadget manager (show / hide)
constexpr std::uint32_t kNoGadget = 0x00C672C0;    // [..]: the handle of "no gadget"; valid ones are above it
constexpr std::uint32_t kLabelStyle = 0x00D6F5D0;  // the stat rows' label style
constexpr std::uint32_t kAttackStyle = 0x00CF05A4; // the attack rows' label style (0x4D7A90)
constexpr std::uint32_t kStatRowLabels = 0x174;    // the stat panel's row handles, 9 labels then 9 values
constexpr std::uint32_t kStatRowValues = 0x198;
constexpr int kStatRows = 9;
constexpr std::uint32_t kGadgetTip = 0x68;         // a gadget's help text, a BString
constexpr float kWholeEpsilon = 1e-6f;             // the panels' "%d" test (0xBA20B4)
// The icon size of the minimized panel's own rows: its attack and resists rows use "(10)" (0xC36508, 0xC364C0), the
// big stat panel "(16)" (0xBA2100). Every icon the key writes there uses the minimized panel's size.
constexpr int kIconSize = 10;

struct BString {
  wchar_t* text;
};

using GadgetByNameFn = std::int32_t*(__thiscall*)(char* panel, std::int32_t* out, BString* name, std::int32_t flag);
using GadgetRefFn = std::int32_t*(__thiscall*)(std::int32_t* ref, std::int32_t handle);
using GadgetReleaseFn = std::int32_t(__cdecl*)(std::int32_t handle);
using GadgetShowFn = void(__thiscall*)(void* manager, std::int32_t handle);
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t id);
using BStringSetFn = void(__thiscall*)(BString* self, const BString* source);
using BStringAssignFn = void(__thiscall*)(BString* self, const BString* source, std::int32_t, std::int32_t);
using BStringFreeFn = void(__thiscall*)(BString* self);
using StatFillFn = void(__thiscall*)(char* panel, const char* selection);
using UnitFloatFn = float(__thiscall*)(const char* unit);
using ProtoIntFn = std::int32_t(__thiscall*)(const char* proto);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kGadgetByName = reinterpret_cast<GadgetByNameFn>(0x00AB7C2F);
const auto kGadgetRef = reinterpret_cast<GadgetRefFn>(0x004C519C);
const auto kGadgetRelease = reinterpret_cast<GadgetReleaseFn>(0x0040431B);
const auto kGadgetShow = reinterpret_cast<GadgetShowFn>(0x00447F7B);
const auto kGadgetHide = reinterpret_cast<GadgetShowFn>(0x00448F13);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringSet = reinterpret_cast<BStringSetFn>(0x0040196F);
const auto kBStringAssign = reinterpret_cast<BStringAssignFn>(0x00443BB8);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kStatFill = reinterpret_cast<StatFillFn>(0x004D70ED);
const auto kMaxHp = reinterpret_cast<UnitFloatFn>(0x00480408);
const auto kLos = reinterpret_cast<UnitFloatFn>(0x0048206D);
const auto kMaxContained = reinterpret_cast<ProtoIntFn>(0x0049EB5A);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

template <typename Fn>
Fn VirtualAt(const void* object, std::uint32_t offset) {
  return *reinterpret_cast<const Fn*>(*reinterpret_cast<const char* const*>(object) + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* UnitById(std::int32_t id) {
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr || id < 0) {
    return nullptr;
  }
  const std::int32_t index = id & 0x3FFFF;
  if (index >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[index];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

// The unit the data refs describe, as the stock providers find it (FUN_006F49B1).
const char* CurrentRefUnit() {
  const char* ui = *reinterpret_cast<const char* const*>(kUiGlobal);
  const char* view = ui == nullptr ? nullptr : Field<const char*>(ui, 0x920);
  return view == nullptr ? nullptr : UnitById(Field<std::int32_t>(view, 0x13C));
}

std::wstring Number(float value) {
  wchar_t text[32];
  const float whole = std::floor(value);
  if (value - whole <= kWholeEpsilon) {
    swprintf_s(text, L"%d", static_cast<int>(whole));
  } else {
    swprintf_s(text, L"%.2f", static_cast<double>(value));
  }
  return text;
}

std::wstring StringById(std::int32_t id) {
  BString text{nullptr};
  kBStringFromId(&text, id);
  std::wstring copy = text.text == nullptr ? L"" : text.text;
  kBStringFree(&text);
  return copy;
}

// ---- Catalog items: the value of one item for one unit, or false when it does not apply ----

// As the minimized block's hit points value: "%d/%d" (0x698B63), or overheal's text when that key runs (its max, its
// colour above 100 %).
bool ItemHitpoints(const char* unit, std::wstring* out) {
  if (uhc::unitinfo::HitpointsText(unit, out)) {
    return true;
  }
  wchar_t text[48];
  swprintf_s(text, L"%d/%d", static_cast<int>(Field<float>(unit, 0x64)), static_cast<int>(kMaxHp(unit)));
  *out = text;
  return true;
}

// The live maximum speed, with techs, snares and auras, as the stat panel's Speed row (the unit's vtable +34h).
bool ItemSpeed(const char* unit, std::wstring* out) {
  const float speed = VirtualAt<UnitFloatFn>(unit, 0x34)(unit);
  if (!(speed > 0.0f)) {
    return false;
  }
  *out = Number(speed);
  return true;
}

bool ItemBaseSpeed(const char* unit, std::wstring* out) {
  const float speed = Field<float>(Field<const char*>(unit, 0x5C), 0x80);
  if (!(speed > 0.0f)) {
    return false;
  }
  *out = Number(speed);
  return true;
}

bool ItemLos(const char* unit, std::wstring* out) {
  const float los = kLos(unit);
  if (!(los > 0.0f)) {
    return false;
  }
  *out = std::to_wstring(static_cast<int>(los));
  return true;
}

// Another DLL replaced the minimized block's armor read (0x698BFC.., e.g. a multiarmor of its own): the armor items
// then answer nothing, so a layout's armor row stays hidden and the block's own resists row shows that DLL's text.
bool g_armorOther = false;

std::wstring DamageIcon(std::uint8_t type) {
  const char* view = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x920);
  if (view == nullptr || type > 2) {
    return L"";
  }
  wchar_t tag[64];
  swprintf_s(tag, L" <icon=\"(%d)(TextureID(%d))\">", kIconSize, Field<std::int32_t>(view, 0x1CC + 4u * type));
  return tag;
}

// The armor as the stock resists value: "0.20" and the icon of its damage type ([proto+1D3h]: 0 hand, 1 ranged,
// 2 siege, icons [[game+920h]+1CCh/1D0h/1D4h]). With multiarmor (a proto with an armor per damage type), every armor
// above 0, by damage type: "0.30 <hand>  0.20 <ranged>".
bool ArmorText(const char* unit, bool icon, std::wstring* out) {
  if (g_armorOther) {
    return false;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  unsigned char types[8];
  float values[8];
  const int n = uhc::unitinfo::Armors(proto, types, values, 8);
  if (n >= 2) {
    std::vector<std::pair<unsigned char, float>> armors;
    for (int i = 0; i < n; ++i) {
      armors.emplace_back(types[i], values[i]);
    }
    std::sort(armors.begin(), armors.end());  // hand, ranged, siege, then the mod's own
    out->clear();
    for (const auto& [type, armor] : armors) {
      *out += (out->empty() ? L"" : L"  ") + Number(armor) + (icon ? DamageIcon(type) : L"");
    }
    return true;
  }
  const float armor = Field<float>(proto, 0xC4);
  if (!(armor > 0.0f)) {
    return false;
  }
  *out = Number(armor) + (icon ? DamageIcon(Field<std::uint8_t>(proto, 0x1D3)) : L"");
  return true;
}

bool ItemArmor(const char* unit, std::wstring* out) { return ArmorText(unit, true, out); }
bool ItemArmorValue(const char* unit, std::wstring* out) { return ArmorText(unit, false, out); }

bool ItemGarrison(const char* unit, std::wstring* out) {
  const std::int32_t capacity = kMaxContained(Field<const char*>(unit, 0x5C));
  if (capacity <= 0) {
    return false;
  }
  wchar_t text[48];
  swprintf_s(text, L"%d / %d", Field<std::int32_t>(unit, 0x74), capacity);
  *out = text;
  return true;
}

bool ProtoPoints(const char* unit, std::uint32_t field, std::wstring* out) {
  const float points = Field<float>(Field<const char*>(unit, 0x5C), field);
  if (!(points > 0.0f)) {
    return false;
  }
  *out = Number(points);
  return true;
}

// Train points are a unit's: a building keeps a default value there (30) that trains nothing.
std::int32_t g_unitTypeId = -1;  // the abstract type Unit, set on each database load (unittypes.h)
bool ItemTrainPoints(const char* unit, std::wstring* out) {
  if (g_unitTypeId < 0 || !kProtoIsType(Field<const char*>(unit, 0x5C), g_unitTypeId)) {
    return false;
  }
  return ProtoPoints(unit, 0x6C, out);
}
bool ItemBuildPoints(const char* unit, std::wstring* out) { return ProtoPoints(unit, 0xCC, out); }

// ---- Batch 2: attacks, costs and what other keys know ----

constexpr std::uint32_t kAttackList = 0x00CF05B0;   // the stat panel fill's attack list {data, count, capacity}
constexpr std::uint32_t kAttackListGuard = 0x00CF05BC;  // bit 0: the list was constructed (0x4D7905)

using AttackListFn = void(__thiscall*)(const char* tactic, const char* unit, std::int32_t, std::int32_t, std::int32_t,
                                       void* list);
using ResListGetFn = float(__thiscall*)(const char* list, std::int32_t resource);
using ResourceIconFn = const char*(__thiscall*)(const char* database, std::int32_t resource);
using UnitResourceFn = std::int32_t(__thiscall*)(const char* unit);
using UnitAmountFn = float(__thiscall*)(const char* unit, std::int32_t resource);
using UnitTestFn = bool(__thiscall*)(const char* unit);
const auto kAttackListFill = reinterpret_cast<AttackListFn>(0x00487EEE);
const auto kResListGet = reinterpret_cast<ResListGetFn>(0x0044EFFF);
const auto kResourceIcon = reinterpret_cast<ResourceIconFn>(0x00706EFB);
const auto kHoldsResource = reinterpret_cast<UnitTestFn>(0x0045EE8B);
const auto kHeldResource = reinterpret_cast<UnitResourceFn>(0x004DBEC1);
const auto kHeldAmount = reinterpret_cast<UnitAmountFn>(0x004E5979);
const auto kHeldInitial = reinterpret_cast<UnitAmountFn>(0x00494503);

const char* Database() { return Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x140); }

// ---- Ability attacks: shown only when the unit can use them ----
//
// An action of a tactics file that a power names in its <unitAction> (powers.xml) is used only through that power,
// that is through an ability record of abilities.xml (Crack Shot, Sharpshooter...). The tactic lists it as active
// all the same, so the stat panels show it on every unit of the tactics file, though most cannot use it. Such an
// action counts as enabled when one of the unit's ability records is available, as the command panel's GetNth
// (0x6EE68C..0x6EE701) tests it: the player's proto (0x45311B) is the record's +4, the record's tech +0Ch is active
// (0x94AF27), its age +10h is the player's [player+50h], and its power (0x6076E9) names that action
// ([power+12Ch]: a 4-byte block with the action name's index, set by the <unitAction> handler 0x5F22CA, the index
// space of [action+4]). Any other action is enabled.

using PlayerProtoFn = const char*(__thiscall*)(const char* player, std::int32_t protoId);
using TechActiveFn = bool(__thiscall*)(const char* techs, std::int32_t player, std::int32_t tech);
using PowerByIdFn = const char*(__thiscall*)(const char* database, std::int32_t power);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kTechActive = reinterpret_cast<TechActiveFn>(0x0094AF27);
const auto kPowerById = reinterpret_cast<PowerByIdFn>(0x006076E9);
constexpr std::uint32_t kWorldAbilities = 0x56C;  // [world+56Ch]: the ability manager, records {data, count}
constexpr std::uint32_t kPowerAction = 0x12C;     // [power+12Ch]: the <unitAction> block, or null
// The UnitAction powers' vtable: its +24h slot (0xB855F4) is that <unitAction> handler's function 0x5F2231, the only
// vtable slot that points there; other power classes keep other data at +12Ch.
constexpr std::uint32_t kUnitActionPowerVtable = 0x00B855D0;

bool g_abilityReads = false;  // the GetNth test and the <unitAction> handler hold the stock bytes
bool g_filterAbilities = true;  // <bigPanelRows abilities="all"> turns the filter off

struct AbilityCache {
  const char* manager = nullptr;
  std::int32_t count = -1;
  std::vector<std::int32_t> actions;  // the action name indices a power of a record names, sorted
} g_abilityCache;

std::int32_t PowerActionName(const char* database, std::int32_t powerId) {
  const char* power = kPowerById(database, powerId);
  if (power == nullptr || Field<std::uint32_t>(power, 0) != kUnitActionPowerVtable) {
    return -1;  // another kind of power: +12Ch is something else
  }
  const std::int32_t* block = Field<const std::int32_t*>(power, kPowerAction);
  return block == nullptr ? -1 : *block;
}

const char* AbilityManager() {
  const char* world = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x13C);
  return world == nullptr ? nullptr : Field<const char*>(world, kWorldAbilities);
}

// The actions some ability record's power names, rebuilt when the manager or its record count changes (a game load).
const std::vector<std::int32_t>& AbilityActions() {
  const char* manager = AbilityManager();
  const char* database = Database();
  const std::int32_t count = manager == nullptr ? 0 : Field<std::int32_t>(manager, 4);
  if (manager != g_abilityCache.manager || count != g_abilityCache.count) {
    g_abilityCache = AbilityCache{manager, count, {}};
    for (std::int32_t i = 0; database != nullptr && i < count; ++i) {
      const char* record = Field<const char* const*>(manager, 0)[i];
      const std::int32_t name = record == nullptr ? -1 : PowerActionName(database, Field<std::int32_t>(record, 8));
      if (name >= 0) {
        g_abilityCache.actions.push_back(name);
      }
    }
    std::sort(g_abilityCache.actions.begin(), g_abilityCache.actions.end());
    g_abilityCache.actions.erase(std::unique(g_abilityCache.actions.begin(), g_abilityCache.actions.end()),
                                 g_abilityCache.actions.end());
  }
  return g_abilityCache.actions;
}

bool ActionEnabled(const char* unit, const char* action) {
  if (!g_filterAbilities || !g_abilityReads || unit == nullptr || action == nullptr) {
    return true;
  }
  const std::int32_t name = Field<std::int32_t>(action, 4);
  const std::vector<std::int32_t>& powered = AbilityActions();
  if (name < 0 || !std::binary_search(powered.begin(), powered.end(), name)) {
    return true;  // not an ability's action: the tactic uses it itself
  }
  const char* manager = AbilityManager();
  const char* database = Database();
  const char* player = Field<const char*>(unit, 0x44);
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* world = Field<const char*>(Game(), 0x13C);
  const char* techs = world == nullptr ? nullptr : Field<const char*>(world, 0x7C);
  if (manager == nullptr || database == nullptr || player == nullptr || proto == nullptr || techs == nullptr) {
    return true;
  }
  const char* own = kPlayerProto(player, Field<std::int32_t>(proto, 8));
  if (own == nullptr) {
    return true;
  }
  const std::int32_t ownId = Field<std::int32_t>(own, 4);
  const std::int32_t count = Field<std::int32_t>(manager, 4);
  for (std::int32_t i = 0; i < count; ++i) {
    const char* record = Field<const char* const*>(manager, 0)[i];
    if (record == nullptr || Field<std::int32_t>(record, 4) != ownId) {
      continue;
    }
    const std::int32_t tech = Field<std::int32_t>(record, 0x0C);
    if (tech >= 0 && !kTechActive(techs, Field<std::int32_t>(player, 0), tech)) {
      continue;
    }
    const std::int32_t age = Field<std::int32_t>(record, 0x10);
    if (age >= 0 && Field<std::int32_t>(player, 0x50) != age) {
      continue;
    }
    if (PowerActionName(database, Field<std::int32_t>(record, 8)) == name) {
      return true;
    }
  }
  return false;
}

// The unit's attacks, as the stat panel lists them (0x4D7892..0x4D79A1): its current tactic
// [[[proto+44h]+10h] + [[unit+58h]+0A8h]*4] fills the list through 0x487EEE, each entry's +4 an index into the
// proto's actions [[proto+44h]+1Ch]; only actions with damage ([action+24h]) are kept.
// withoutDamage: also the listed actions with no damage record, as the stat panel fill writes a row for each.
// enabledOnly: without the ability actions the unit cannot use (ActionEnabled).
std::vector<const char*> Attacks(const char* unit, bool withoutDamage = false, bool enabledOnly = true) {
  std::vector<const char*> out;
  const char* manager = Field<const char*>(unit, 0x58);
  const char* data = Field<const char*>(Field<const char*>(unit, 0x5C), 0x44);
  if (manager == nullptr || data == nullptr) {
    return out;
  }
  const std::int32_t tacticIndex = Field<std::int32_t>(manager, 0xA8);
  if (tacticIndex < 0 || tacticIndex >= Field<std::int32_t>(data, 0x14)) {
    return out;
  }
  const char* tactic = Field<const char* const*>(data, 0x10)[tacticIndex];
  if (tactic == nullptr) {
    return out;
  }
  auto* guard = reinterpret_cast<std::uint32_t*>(kAttackListGuard);
  auto* list = reinterpret_cast<std::int32_t*>(kAttackList);
  if ((*guard & 1) == 0) {  // as the fill's own first use does, less the exit handler
    *guard |= 1;
    list[0] = list[1] = list[2] = 0;
  }
  if (list[2] >= 0) {
    list[1] = 0;
  }
  kAttackListFill(tactic, unit, 0, -1, 1, list);
  const char* entries = reinterpret_cast<const char*>(static_cast<std::intptr_t>(list[0]));
  const std::int32_t actions = Field<std::int32_t>(data, 0x20);
  for (std::int32_t k = 0; entries != nullptr && k < list[1]; ++k) {
    const std::int32_t id = Field<std::int32_t>(entries, 12u * k + 4);
    const char* action = id >= 0 && id < actions ? Field<const char* const*>(data, 0x1C)[id] : nullptr;
    if (action != nullptr && (withoutDamage || Field<const char*>(action, 0x24) != nullptr) &&
        (!enabledOnly || ActionEnabled(unit, action))) {
      out.push_back(action);
    }
  }
  return out;
}

// The icon of a damage type (0 hand, 1 ranged, 2 siege), as the panels show it.
std::wstring TypeIcon(std::uint8_t type) {
  const char* view = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x920);
  if (view == nullptr || type > 2) {
    return L"";
  }
  wchar_t tag[64];
  swprintf_s(tag, L" <icon=\"(%d)(TextureID(%d))\">", kIconSize, Field<std::int32_t>(view, 0x1CC + 4u * type));
  return tag;
}

// The distinct values of the unit's attacks, each with the damage type icon of the first attack that has it (the
// panel has little room: a Musketeer's ROF reads "3 (ranged) 1.5 (hand)"), skipping the values `value` rejects.
template <typename Fn>
bool PerAttack(const char* unit, std::wstring* out, Fn value) {
  std::vector<float> seen;
  out->clear();
  for (const char* action : Attacks(unit)) {
    float v = 0.0f;
    if (!value(action, &v)) {
      continue;
    }
    bool repeated = false;
    for (const float s : seen) {
      repeated |= std::fabs(s - v) < 0.01f;
    }
    if (!repeated) {
      seen.push_back(v);
      *out += (out->empty() ? L"" : L"  ") + Number(v) +
              TypeIcon(Field<std::uint8_t>(Field<const char*>(action, 0x24), 5));
    }
  }
  return !out->empty();
}

// Hand attacks (damage type 0) have a melee reach, not a range worth a row.
bool Ranged(const char* action) { return Field<std::uint8_t>(Field<const char*>(action, 0x24), 5) != 0; }

// ROF [action+34h], ms (<ROF> x 1000); ranges at [[action+18h]+4] (min) and +8 (max); area byte [[action+24h]+6].
bool ItemRof(const char* unit, std::wstring* out) {
  return PerAttack(unit, out, [](const char* a, float* v) {
    *v = static_cast<float>(Field<std::int32_t>(a, 0x34)) / 1000.0f;
    return *v > 0.0f;
  });
}

bool ItemRange(const char* unit, std::wstring* out) {
  return PerAttack(unit, out, [](const char* a, float* v) {
    const char* ranges = Field<const char*>(a, 0x18);
    *v = ranges == nullptr ? 0.0f : Field<float>(ranges, 8);
    return Ranged(a) && *v > 0.0f;
  });
}

bool ItemMinRange(const char* unit, std::wstring* out) {
  return PerAttack(unit, out, [](const char* a, float* v) {
    const char* ranges = Field<const char*>(a, 0x18);
    *v = ranges == nullptr ? 0.0f : Field<float>(ranges, 4);
    return *v > 0.0f;
  });
}

bool ItemArea(const char* unit, std::wstring* out) {
  return PerAttack(unit, out, [](const char* a, float* v) {
    *v = static_cast<float>(Field<std::uint8_t>(Field<const char*>(a, 0x24), 6));
    return *v > 0.0f;
  });
}

// The projectiles an attack fires before its reload: its <NumberOfShots> x <NumberProjectiles> (shots.cpp); 1 without
// them.
int ProjectilesPerReload(const char* unit, const char* action) {
  int shots = 1;
  int projectiles = 1;
  if (!uhc::unitinfo::Shots(Field<const char*>(unit, 0x5C), action, &shots, &projectiles)) {
    return 1;
  }
  return shots * projectiles;
}

bool ItemProjectiles(const char* unit, std::wstring* out) {
  return PerAttack(unit, out, [unit](const char* a, float* v) {
    *v = static_cast<float>(ProjectilesPerReload(unit, a));
    return *v > 1.0f;
  });
}

// ---- An attack row the stat panel fill had no room for ----

using ActionNameFn = const wchar_t* const*(__thiscall*)(const char* action);
const auto kActionName = reinterpret_cast<ActionNameFn>(0x005F8FC3);  // the action's raw name (0x69B617)

bool ActionFlag(const char* action, std::uint32_t bit) {  // the bit set [action+64h], size [action+68h] in bits
  if (bit >= Field<std::uint32_t>(action, 0x68)) {
    return false;
  }
  return (Field<const std::uint8_t*>(action, 0x64)[bit >> 3] & (1u << (bit & 7))) != 0;
}

// A modifier factor of the unit's modifier record, as the fill reads it: 1.0 below 1e-6 (0xB9FB64) or without one.
float DamageFactor(const char* unit, std::uint32_t field) {
  const char* sub = Field<const char*>(unit, 0xB4);
  const char* record = sub == nullptr ? nullptr : Field<const char*>(sub, 0xC8);
  if (record == nullptr) {
    return 1.0f;
  }
  const float value = Field<float>(record, field);
  return value < *reinterpret_cast<const float*>(0x00B9FB64) ? 1.0f : value;
}

// The label and value of one attack row as the stat panel fill writes them (0x4D7A2E..0x4D7E0F): "%s:" with the
// action's name (string ID [[db+1FE4h] + [action+4]*4], or its raw name), then "%d <icon>": the damage
// [[action+24h]] x the count scale (flag 12h: the contained units [unit+74h], capped by [action+48h] when above 0)
// x the modifier record's +8 x its +14h (hand, ranged) or +10h (siege), truncated, with the damage type's icon;
// then, with flag 0Ah, " %d <icon>": the range of the action's range entry -1 (0x4946D6) and the range icon
// [[game+920h]+218h]. The bonus multipliers that follow in the stock row are left out.
// The name the stat panel fill gives an action's row (0x4D7A2E): its string, or its raw name.
std::wstring ActionDisplayName(const char* action) {
  const char* database = Database();
  if (database == nullptr) {
    return L"";
  }
  const std::int32_t nameIndex = Field<std::int32_t>(action, 4);
  std::int32_t stringId = -1;
  if (nameIndex >= 0 && nameIndex < Field<std::int32_t>(database, 0x1FDC)) {
    stringId = Field<const std::int32_t*>(database, 0x1FE4)[nameIndex];
  }
  std::wstring name = stringId >= 0 ? StringById(stringId) : L"";
  if (name.empty()) {
    const wchar_t* const* raw = kActionName(action);
    name = raw != nullptr && *raw != nullptr ? *raw : L"";
  }
  return name;
}

bool AttackRow(const char* unit, const char* action, std::wstring* label, std::wstring* value) {
  const char* database = Database();
  const char* view = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x920);
  if (database == nullptr || view == nullptr) {
    return false;
  }
  *label = ActionDisplayName(action) + L":";
  const char* damage = Field<const char*>(action, 0x24);
  const float base = damage == nullptr ? 0.0f : Field<float>(damage, 0);
  const std::uint8_t type = damage == nullptr ? 0 : Field<std::uint8_t>(damage, 5);
  float scale = 1.0f;
  if (ActionFlag(action, 0x12)) {
    scale = static_cast<float>(Field<std::int32_t>(unit, 0x74));
    const float cap = Field<float>(action, 0x48);
    if (scale > cap && cap > 0.0f) {
      scale = cap;
    }
  }
  scale *= DamageFactor(unit, 0x08);
  const float typed = DamageFactor(unit, type == 2 ? 0x10 : 0x14);
  wchar_t text[160];
  swprintf_s(text, L"%d <icon=\"(%d)(TextureID(%d))\">", static_cast<int>(typed * scale * base), kIconSize,
             type <= 2 ? Field<std::int32_t>(view, 0x1CC + 4u * type) : 0);
  *value = text;
  if (ActionFlag(action, 0x0A)) {
    const char* ranges = Field<const char*>(action, 0x18);
    const std::int32_t count = Field<std::int32_t>(action, 0x1C);
    for (std::int32_t i = 0; ranges != nullptr && i < count; ++i) {
      if (Field<std::int32_t>(ranges, 16u * i) == -1) {
        swprintf_s(text, L" %d <icon=\"(%d)(TextureID(%d))\">", static_cast<int>(Field<float>(ranges, 16u * i + 8)),
                   kIconSize, Field<std::int32_t>(view, 0x218));
        *value += text;
        break;
      }
    }
  }
  return true;
}

// The player's proto cost list [proto+70h] (with its techs; read through 0x44EFFF, which unmasks it): each resource's
// icon, then its amount, as the game's resource bar shows them ("<food> 100  <gold> 25").
bool ItemCost(const char* unit, std::wstring* out) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* database = Database();
  if (database == nullptr) {
    return false;
  }
  out->clear();
  const std::int32_t resources = Field<std::int32_t>(database, 0x80);
  for (std::int32_t r = 0; r < resources && r < 16; ++r) {
    const float cost = kResListGet(proto + 0x70, r);
    if (cost > 0.0f) {
      wchar_t text[96];
      swprintf_s(text, L"%ls<icon=\"(%d)(%hs)\">%d", out->empty() ? L"" : L" ", kIconSize, kResourceIcon(database, r),
                 static_cast<int>(cost + 0.5f));
      *out += text;
    }
  }
  return !out->empty();
}

bool ProtoInt(const char* unit, std::uint32_t field, std::wstring* out) {
  const std::int32_t value = Field<std::int32_t>(Field<const char*>(unit, 0x5C), field);
  if (value <= 0) {
    return false;
  }
  *out = std::to_wstring(value);
  return true;
}

// PopulationCount [proto+0D8h], stored times K by decimalPopulation (its own panels divide it back the same way).
bool ItemPopulation(const char* unit, std::wstring* out) {
  const std::int32_t value = Field<std::int32_t>(Field<const char*>(unit, 0x5C), 0xD8);
  if (value <= 0) {
    return false;
  }
  *out = Number(static_cast<float>(value) / static_cast<float>(uhc::unitinfo::PopulationScale()));
  return true;
}
bool ItemBuildLimit(const char* unit, std::wstring* out) { return ProtoInt(unit, 0x108, out); }  // BuildLimit

bool ItemBounty(const char* unit, std::wstring* out) {  // <Bounty>, float [proto+168h] (handler 0x5F5D79)
  const float bounty = Field<float>(Field<const char*>(unit, 0x5C), 0x168);
  if (!(bounty > 0.0f)) {
    return false;
  }
  *out = Number(bounty);
  return true;
}

// What a mine, bush, carcass or herd animal holds, as the stock "resource held" row reads it.
bool ItemInventory(const char* unit, std::wstring* out) {
  const char* database = Database();
  if (database == nullptr || !kHoldsResource(unit)) {
    return false;
  }
  const std::int32_t resource = kHeldResource(unit);
  if (resource < 0) {
    return false;
  }
  wchar_t text[96];
  swprintf_s(text, L"%d/%d <icon=\"(16)(%hs)\">", static_cast<int>(kHeldAmount(unit, resource)),
             static_cast<int>(kHeldInitial(unit, resource)), kResourceIcon(database, resource));
  *out = text;
  return true;
}

// The countdown of a unit with a lifespan, [[unit+0B4h]+1Ch], while state bit 3 is set (setLifespan 0x48DCB9).
bool ItemLifespan(const char* unit, std::wstring* out) {
  const auto* bits = Field<const std::uint8_t*>(unit, 4);
  const char* sub = Field<const char*>(unit, 0xB4);
  if (bits == nullptr || sub == nullptr || (bits[0] & 0x08) == 0) {
    return false;
  }
  const float left = Field<float>(sub, 0x1C);
  if (!(left > 0.0f)) {
    return false;
  }
  wchar_t text[32];
  swprintf_s(text, L"%d s", static_cast<int>(left + 0.5f));
  *out = text;
  return true;
}

// overhealHitpointBars: the hit points above InitialHitpoints of a marked unit.
bool ItemOverheal(const char* unit, std::wstring* out) {
  const char* proto = Field<const char*>(unit, 0x5C);
  if (!uhc::unitinfo::OverhealOn(proto)) {
    return false;
  }
  const float above = Field<float>(unit, 0x64) - Field<float>(proto, 0x9C);
  if (!(above >= 1.0f)) {
    return false;
  }
  *out = L"+" + std::to_wstring(static_cast<int>(above));
  return true;
}

bool ItemVeterancy(const char* unit, std::wstring* out) { return uhc::unitinfo::Veterancy(unit, out); }
bool ItemPoison(const char* unit, std::wstring* out) { return uhc::unitinfo::Poison(unit, out); }
bool ItemRandomCost(const char* unit, std::wstring* out) { return uhc::unitinfo::RandomCost(unit, out); }
bool ItemShipments(const char* unit, std::wstring* out) { return uhc::unitinfo::ShipmentCounts(unit, out); }
bool ItemGatherRate(const char* unit, std::wstring* out) { return uhc::unitinfo::GatherRate(unit, out); }

// ---- Batch 3: building, regeneration, our auras ----

constexpr std::uint8_t kBuildActionType = 0;  // [action+60h] of a unit's Build action (the type list, 0x5227B4)
constexpr std::uint8_t kBuildingState = 8;    // [action+61h] while it works (its animation loop, 0x9D34B1)
constexpr int kMaxWorkers = 64;
bool g_buildReads = false;  // the build tick's code matches what BuildRateOn mirrors
bool g_regenReads = false;  // the regeneration's code matches what ItemRegen mirrors

bool AllMatch(std::initializer_list<const uhc::Site*> list) {
  bool all = true;
  for (const uhc::Site* site : list) {
    if (!uhc::Matches(*site)) {
      uhc::Log(L"minUIStats: site %hs at 0x%08X does not hold the stock bytes", site->name, site->va);
      all = false;
    }
  }
  return all;
}

using RateForFn = float(__thiscall*)(const char* tacticsAction, const char* target);
using BuilderFactorFn = float(__thiscall*)(const char* target, std::int32_t builderId, std::int32_t protoActionId);
const auto kRateFor = reinterpret_cast<RateForFn>(0x00487C45);
const auto kBuilderFactor = reinterpret_cast<BuilderFactorFn>(0x009C4C0C);

// What one builder adds to its target per second, as the build tick 0x9D3D6B..0x9D3DC3 computes it before it
// multiplies by the frame time [world+104h]: the rate of its tactics action for the target (0x487C45; with
// buildingWorkRateAuras, the factor that key's hook of that call applies), the builder factor 0x9C4C0C (1.0 for
// the first builder of the site, the civ's figure for the others), the world's rate [world+318h] and the
// builder's player's [player+37Ch]. 0 when the unit is not building `target` right now.
float BuildRateOn(const char* builder, const char* target) {
  if (!g_buildReads) {
    return 0.0f;
  }
  const char* manager = Field<const char*>(builder, 0x58);
  const char* action = manager == nullptr ? nullptr : Field<const char*>(manager, 0x24);
  const char* player = Field<const char*>(builder, 0x44);
  const char* world = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x13C);
  if (action == nullptr || player == nullptr || world == nullptr || Field<std::uint8_t>(action, 0x60) != kBuildActionType ||
      Field<std::uint8_t>(action, 0x61) != kBuildingState || Field<std::int32_t>(action, 0x14) != Field<std::int32_t>(target, 0x10)) {
    return 0.0f;
  }
  const char* tactics = Field<const char*>(action, 0x04);
  if (tactics == nullptr) {
    return 0.0f;
  }
  const float rate = kRateFor(tactics, target) * uhc::unitinfo::BuildWorkFactor(builder);
  const float factor = kBuilderFactor(target, Field<std::int32_t>(builder, 0x10), Field<std::int32_t>(tactics, 0x08));
  return rate * factor * Field<float>(world, 0x318) * Field<float>(player, 0x37C);
}

// A building under construction: its building data [unit+68h] (+4 the build points so far, +8 the fraction),
// below 1.0.
bool UnderConstruction(const char* unit, const char** data) {
  *data = Field<const char*>(unit, 0x68);
  return *data != nullptr && Field<float>(*data, 8) < 1.0f;
}

// The builders of a site: its worker list [unit+94h], count [unit+98h], 18h-byte entries whose +0 is the worker's
// ID (the list 0x9C4C0C walks).
float SiteBuildRate(const char* unit, int* builders) {
  const std::int32_t count = Field<std::int32_t>(unit, 0x98);
  const char* entries = Field<const char*>(unit, 0x94);
  float total = 0.0f;
  *builders = 0;
  std::int32_t seen[kMaxWorkers];
  for (std::int32_t i = 0; entries != nullptr && i < count && i < kMaxWorkers; ++i) {
    const std::int32_t id = Field<std::int32_t>(entries, 0x18u * i);
    seen[i] = id;
    bool repeated = false;
    for (std::int32_t j = 0; j < i && !repeated; ++j) {
      repeated = seen[j] == id;  // a unit is counted once, by its one current action
    }
    const char* worker = repeated ? nullptr : UnitById(id);
    const float rate = worker == nullptr ? 0.0f : BuildRateOn(worker, unit);
    if (rate > 0.0f) {
      total += rate;
      ++*builders;
    }
  }
  return total;
}

// "0:45" to finish: the build points left ([proto+0CCh], the cap the tick passes to the add 0x7ADE95, less
// [data+4]) over the sum of the builders' rates. Nothing while nobody builds it.
bool ItemBuildTime(const char* unit, std::wstring* out) {
  const char* data = nullptr;
  if (!UnderConstruction(unit, &data)) {
    return false;
  }
  int builders = 0;
  const float rate = SiteBuildRate(unit, &builders);
  const float left = Field<float>(Field<const char*>(unit, 0x5C), 0xCC) - Field<float>(data, 4);
  if (!(rate > 0.0f) || left < 0.0f) {
    return false;
  }
  const int seconds = static_cast<int>(left / rate + 0.5f);
  wchar_t text[32];
  swprintf_s(text, L"%d:%02d", seconds / 60, seconds % 60);
  *out = text;
  return true;
}

bool ItemBuildProgress(const char* unit, std::wstring* out) {
  const char* data = nullptr;
  if (!g_buildReads || !UnderConstruction(unit, &data)) {
    return false;
  }
  *out = std::to_wstring(static_cast<int>(Field<float>(data, 8) * 100.0f)) + L"%";
  return true;
}

// A builder at work: the points per second it adds to the site it builds.
bool ItemBuildRate(const char* unit, std::wstring* out) {
  const char* manager = Field<const char*>(unit, 0x58);
  const char* action = manager == nullptr ? nullptr : Field<const char*>(manager, 0x24);
  const char* target = action == nullptr ? nullptr : UnitById(Field<std::int32_t>(action, 0x14));
  const float rate = target == nullptr ? 0.0f : BuildRateOn(unit, target);
  if (!(rate > 0.0f)) {
    return false;
  }
  wchar_t text[32];
  swprintf_s(text, L"%.2f", static_cast<double>(rate));
  *out = text;
  return true;
}

// Regeneration, per player (FUN_004905E1, from the player update 0x490A52; `this` the player). For each civ ID of
// the list [player+20h] (count +24h) that the database's civ table knows ([db+24h], count [db+28h]), the records
// [player+44h] + ID*0Ch ({data, count}) of 14h bytes: +0 the unit type healed (the player's query 0x45356D),
// +8 the rate in % of max HP per second (skipped when |rate| is below 0xB9FD78), +0Ch the idle time it needs
// (0: none). A unit of that type gains rate x max HP x 0.01 per second (0x490811..0x49085D), while idle that long
// when the record asks for it. The fire pit's Regeneration dance (0x679E66, native civs and danceBonusCivs) is a
// separate source, not added here.
bool ItemRegen(const char* unit, std::wstring* out) {
  const char* player = Field<const char*>(unit, 0x44);
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* database = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x140);
  if (!g_regenReads || player == nullptr || proto == nullptr || database == nullptr) {
    return false;
  }
  const std::int32_t* civs = Field<const std::int32_t*>(player, 0x20);
  const std::int32_t civCount = Field<std::int32_t>(player, 0x24);
  const char* table = Field<const char*>(player, 0x44);
  const char* const* civTable = Field<const char* const*>(database, 0x24);
  const std::int32_t civTableCount = Field<std::int32_t>(database, 0x28);
  if (civs == nullptr || table == nullptr || civTable == nullptr) {
    return false;
  }
  const float minRate = *reinterpret_cast<const float*>(0x00B9FD78);
  float percent = 0.0f;
  for (std::int32_t k = 0; k < civCount && k < 64; ++k) {
    const std::int32_t civ = civs[k];
    if (civ < 0 || civ >= civTableCount || civTable[civ] == nullptr) {
      continue;
    }
    const char* records = Field<const char*>(table, 0x0Cu * civ);
    const std::int32_t count = Field<std::int32_t>(table, 0x0Cu * civ + 4);
    for (std::int32_t r = 0; records != nullptr && r < count && r < 256; ++r) {
      const float rate = Field<float>(records, 0x14u * r + 8);
      if (!(std::fabs(rate) < minRate) && kProtoIsType(proto, Field<std::int32_t>(records, 0x14u * r))) {
        percent += rate;
      }
    }
  }
  if (!(percent > 0.0f)) {
    return false;
  }
  *out = Number(percent * kMaxHp(unit) * 0.01f);
  return true;
}

// Our aura keys only.
bool ItemAuras(const char* unit, std::wstring* out) {
  out->clear();
  std::wstring part;
  if (uhc::unitinfo::WorkAura(unit, &part)) {
    *out += part;
  }
  if (uhc::unitinfo::GatherAura(unit, &part)) {
    *out += (out->empty() ? L"" : L" ") + part;
  }
  if (uhc::unitinfo::ResourceAura(unit, &part)) {
    *out += (out->empty() ? L"" : L" ") + part;
  }
  return !out->empty();
}

using ItemFn = bool (*)(const char* unit, std::wstring* out);

template <ItemFn Item>
bool __stdcall ItemRef(uhc::DataRefValue* value) {
  if (value == nullptr || value->type != uhc::kDataRefString) {
    return false;
  }
  const char* unit = CurrentRefUnit();
  std::wstring text;
  if (unit == nullptr || Field<const char*>(unit, 0x5C) == nullptr || !Item(unit, &text)) {
    return true;  // the empty string the evaluator made
  }
  const BString source{text.data()};
  kBStringAssign(reinterpret_cast<BString*>(&value->text), &source, -1, -1);
  return true;
}

struct ItemInfo {
  const char* name;     // the data file's item
  const wchar_t* ref;   // its data ref
  ItemFn fn;
  uhc::DataRefProvider provider;
};

const ItemInfo kItems[] = {
    {"hitpoints", L"uhcHitpoints", &ItemHitpoints, &ItemRef<&ItemHitpoints>},
    {"speed", L"uhcSpeed", &ItemSpeed, &ItemRef<&ItemSpeed>},
    {"baseSpeed", L"uhcBaseSpeed", &ItemBaseSpeed, &ItemRef<&ItemBaseSpeed>},
    {"los", L"uhcLOS", &ItemLos, &ItemRef<&ItemLos>},
    {"armor", L"uhcArmor", &ItemArmor, &ItemRef<&ItemArmor>},
    {"armorValue", L"uhcArmorValue", &ItemArmorValue, &ItemRef<&ItemArmorValue>},
    {"garrison", L"uhcGarrison", &ItemGarrison, &ItemRef<&ItemGarrison>},
    {"trainPoints", L"uhcTrainPoints", &ItemTrainPoints, &ItemRef<&ItemTrainPoints>},
    {"buildPoints", L"uhcBuildPoints", &ItemBuildPoints, &ItemRef<&ItemBuildPoints>},
    {"rof", L"uhcROF", &ItemRof, &ItemRef<&ItemRof>},
    {"range", L"uhcRange", &ItemRange, &ItemRef<&ItemRange>},
    {"minRange", L"uhcMinRange", &ItemMinRange, &ItemRef<&ItemMinRange>},
    {"area", L"uhcArea", &ItemArea, &ItemRef<&ItemArea>},
    {"projectiles", L"uhcProjectiles", &ItemProjectiles, &ItemRef<&ItemProjectiles>},
    {"cost", L"uhcCost", &ItemCost, &ItemRef<&ItemCost>},
    {"population", L"uhcPopulation", &ItemPopulation, &ItemRef<&ItemPopulation>},
    {"bounty", L"uhcBounty", &ItemBounty, &ItemRef<&ItemBounty>},
    {"buildLimit", L"uhcBuildLimit", &ItemBuildLimit, &ItemRef<&ItemBuildLimit>},
    {"inventory", L"uhcInventory", &ItemInventory, &ItemRef<&ItemInventory>},
    {"lifespan", L"uhcLifespan", &ItemLifespan, &ItemRef<&ItemLifespan>},
    {"overheal", L"uhcOverheal", &ItemOverheal, &ItemRef<&ItemOverheal>},
    {"veterancy", L"uhcVeterancy", &ItemVeterancy, &ItemRef<&ItemVeterancy>},
    {"poison", L"uhcPoison", &ItemPoison, &ItemRef<&ItemPoison>},
    {"randomCost", L"uhcRandomCost", &ItemRandomCost, &ItemRef<&ItemRandomCost>},
    {"shipments", L"uhcShipments", &ItemShipments, &ItemRef<&ItemShipments>},
    {"gatherRate", L"uhcGatherRate", &ItemGatherRate, &ItemRef<&ItemGatherRate>},
    {"buildTime", L"uhcBuildTime", &ItemBuildTime, &ItemRef<&ItemBuildTime>},
    {"buildProgress", L"uhcBuildProgress", &ItemBuildProgress, &ItemRef<&ItemBuildProgress>},
    {"buildRate", L"uhcBuildRate", &ItemBuildRate, &ItemRef<&ItemBuildRate>},
    {"regen", L"uhcRegen", &ItemRegen, &ItemRef<&ItemRegen>},
    {"auras", L"uhcAuras", &ItemAuras, &ItemRef<&ItemAuras>},
};

const ItemInfo* FindItem(const std::string& name) {
  for (const ItemInfo& item : kItems) {
    if (_stricmp(item.name, name.c_str()) == 0) {
      return &item;
    }
  }
  return nullptr;
}

// ---- The data file ----

struct TypeFilter {
  std::string name;
  std::int32_t id = -1;  // set on each database load (unittypes.h)
};

struct Row {
  std::wstring gadget;
  const ItemInfo* item = nullptr;  // item= ...
  std::wstring label;
  std::wstring text;               // ... or text=: segments split by '|', each with its {item}s
  std::vector<TypeFilter*> types;  // empty: every unit
  bool keep = false;               // overlap="show": shown even over the stack portraits or an <avoid> gadget
  std::wstring tip;                // tip= / tipId=: the help text (what the icons mean)
  bool lines = false;              // join="line": each part on a line of its own instead of joined by spaces
};

// <stockLabel gadget="..." text="..." tip="..."/>: a label of the original panel whose text the key replaces while
// the original panel shows it (the hit points and resists labels by an icon). The panel's own fill writes it each
// time; the key writes it again after.
struct StockLabel {
  std::wstring gadget;
  std::wstring text;
  std::wstring tip;
};
std::vector<StockLabel> g_labels;

// <replace row="..." stock="a,b"/>: while that row of the key shows, the original gadgets named are hidden (the
// panel's own fill shows them each time; the key hides them again after it). The layout can then keep the original
// gadgets where they were, so it reads the same without the key, and draw the key's version in a gadget of its own
// (the hit points and resists rows with their icons).
struct Replace {
  std::wstring row;
  std::vector<std::wstring> stock;
};
std::vector<Replace> g_replaces;

// "[icon:ui\ingame\stat_icon_los]" in a data file's text: the icon markup at the minimized panel's icon size.
std::wstring ExpandIcons(const std::wstring& text) {
  std::wstring out;
  size_t pos = 0;
  for (size_t open = text.find(L"[icon:"); open != std::wstring::npos; open = text.find(L"[icon:", pos)) {
    const size_t close = text.find(L']', open);
    if (close == std::wstring::npos) {
      break;
    }
    out += text.substr(pos, open - pos);
    wchar_t size[16];
    swprintf_s(size, L"(%d)", kIconSize);
    out += L"<icon=\"" + std::wstring(size) + L"(" + text.substr(open + 6, close - open - 6) + L")\">";
    pos = close + 1;
  }
  return out + text.substr(pos);
}

// "[string:68852]" in a text, label or tip: that string of the game's string table, read when the row is shown (the
// tables load after the DLL starts) and kept once read.
std::map<std::int32_t, std::wstring> g_stringCache;

std::wstring ExpandStrings(const std::wstring& text) {
  static const std::wstring kOpen = L"[string:";
  size_t open = text.find(kOpen);
  if (open == std::wstring::npos) {
    return text;
  }
  std::wstring out;
  size_t pos = 0;
  for (; open != std::wstring::npos; open = text.find(kOpen, pos)) {
    const size_t close = text.find(L']', open);
    if (close == std::wstring::npos) {
      break;
    }
    out += text.substr(pos, open - pos);
    pos = close + 1;
    const std::int32_t id = _wtoi(text.c_str() + open + kOpen.size());
    auto found = g_stringCache.find(id);
    if (found == g_stringCache.end()) {
      std::wstring value = StringById(id);
      if (value.empty()) {
        continue;  // not kept: the table may not be read yet
      }
      found = g_stringCache.emplace(id, std::move(value)).first;
    }
    out += found->second;
  }
  return out + text.substr(pos);
}

// A text= row: each '|'-separated segment with its {item}s replaced; a segment with an item that has nothing for
// the unit is left out, the rest are joined by three spaces. False when no segment is left.
bool RenderTemplate(const std::wstring& text, const char* unit, std::wstring* out, bool lines = false) {
  out->clear();
  size_t start = 0;
  while (start <= text.size()) {
    size_t bar = text.find(L'|', start);
    if (bar == std::wstring::npos) {
      bar = text.size();
    }
    const std::wstring segment = text.substr(start, bar - start);
    std::wstring rendered;
    bool ok = true;
    size_t pos = 0;
    while (ok && pos < segment.size()) {
      const size_t open = segment.find(L'{', pos);
      const size_t close = open == std::wstring::npos ? std::wstring::npos : segment.find(L'}', open);
      if (open == std::wstring::npos || close == std::wstring::npos) {
        rendered += ExpandStrings(segment.substr(pos));
        break;
      }
      rendered += ExpandStrings(segment.substr(pos, open - pos));
      const std::wstring name = segment.substr(open + 1, close - open - 1);
      std::string narrow(name.begin(), name.end());
      const ItemInfo* item = FindItem(narrow);
      std::wstring value;
      ok = item != nullptr && item->fn(unit, &value);
      rendered += value;
      pos = close + 1;
    }
    if (ok && !rendered.empty()) {
      *out += (out->empty() ? L"" : (lines ? L"\n" : L"   ")) + rendered;
    }
    start = bar + 1;
  }
  return !out->empty();
}

// Kinds of mirrored stat rows.
enum Kind : std::uint32_t {
  kName = 1u << 0, kHitpoints = 1u << 1, kGroupHealth = 1u << 2, kResource = 1u << 3, kGatherers = 1u << 4,
  kRate = 1u << 5, kSpeed = 1u << 6, kResists = 1u << 7, kAttack = 1u << 8, kShownAttack = 1u << 9,
  kSpecial = 1u << 10, kOther = 1u << 11, kDropped = 1u << 12, kAuto = 1u << 31,
};

struct BigPanel {
  bool on = false;
  std::wstring pattern;  // with one %d
  int first = 0;
  int count = 16;
  std::uint32_t skip = kAuto;
  bool keep = false;  // overlap="show"
  bool takeStock = false;  // stockRows="take": the original attack rows (StackLabel0..2) are written by the key too
  std::wstring rofIcon;    // rofIcon="...": each attack row gets its ROF and this icon after its damage
  std::wstring projectilesIcon;  // projectilesIcon="...": shots x projectiles before the reload, when above 1
};

std::vector<Row> g_rows;
BigPanel g_big;
std::vector<TypeFilter*> g_filters;
std::vector<std::wstring> g_avoid;  // <avoid gadget="..."/>: stock gadgets whose text a row must not cover
std::wstring g_file;
bool g_stackReads = false;  // the stack portrait code matches what CollectBlockers reads
bool g_attackReads = false;  // the stat fill's attack rows match what AttackRow mirrors

const char kDefaultRows[] =
    "<minUIRows>"
    "<row gadget='unitselectionpanel-uhcCost' text='{cost}' tip='Cost'/>"
    "<row gadget='unitselectionpanel-uhcPop' text='[icon:ui\\ingame\\stat_icon_building]{population}' "
    "tip='Population'/>"
    "<row gadget='unitselectionpanel-uhcSight' text='[icon:ui\\ingame\\stat_icon_los]{los}|"
    "[icon:ui\\ingame\\stat_icon_speed]{speed}' tip='Line of sight, speed'/>"
    "<row gadget='unitselectionpanel-uhcTrainGarrison' text='[icon:ui\\ingame\\stat_icon_traintime]{trainPoints}|"
    "[icon:ui\\cursors\\cursor_garrison]{garrison}' tip='Train time (seconds), garrison'/>"
    "<row gadget='unitselectionpanel-uhcRow2' text='Done in {buildTime}|Builds {buildRate}/s|Regen {regen}/s|"
    "Overheal {overheal}|Poison {poison}|Aura {auras}'/>"
    "<row gadget='unitselectionpanel-uhcHitpoints' "
    "text='&lt;color=1, 1, 0&gt;[string:68852]:&lt;/color&gt;  {hitpoints}' tipId='68852'/>"
    "<row gadget='unitselectionpanel-uhcResists' text='[icon:ui\\ingame\\stat_icon_armor] {armor}' tipId='35758'/>"
    "<replace row='unitselectionpanel-uhcHitpoints' "
    "stock='unitselectionpanel-unitHitPointsLabel,unitselectionpanel-unitHitPointsValue'/>"
    "<replace row='unitselectionpanel-uhcResists' "
    "stock='unitselectionpanel-unitResistsLabel,unitselectionpanel-unitResistsValue'/>"
    "<bigPanelRows gadget='unitselectionpanel-uhcRow%d' first='3' skip='auto,speed' stockRows='take' "
    "rofIcon='ui\\ingame\\stat_icon_rof' projectilesIcon='ui\\ingame\\stat_icon_projectiles'/>"
    "<avoid gadget='unitselectionpanel-unitResourceValue'/>"
    "<avoid gadget='unitselectionpanel-unitResourceRateLabel'/>"
    "</minUIRows>";

std::string Lower(std::string text) {
  for (char& c : text) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  return text;
}

std::string Trim(const std::string& text) {
  const size_t a = text.find_first_not_of(" \t\r\n");
  const size_t b = text.find_last_not_of(" \t\r\n");
  return a == std::string::npos ? std::string() : text.substr(a, b - a + 1);
}

std::wstring Wide(const std::string& text) {
  if (text.empty()) {
    return {};
  }
  const int length = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0);
  std::wstring out(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), out.data(), length);
  return out;
}

std::string Decode(const std::string& text) {
  std::string out;
  for (size_t i = 0; i < text.size(); ++i) {
    if (text[i] == '&') {
      static const struct { const char* name; char c; } kEntities[] = {
          {"&lt;", '<'}, {"&gt;", '>'}, {"&amp;", '&'}, {"&quot;", '"'}, {"&apos;", '\''}};
      bool done = false;
      for (const auto& e : kEntities) {
        const size_t n = std::strlen(e.name);
        if (text.compare(i, n, e.name) == 0) {
          out += e.c;
          i += n - 1;
          done = true;
          break;
        }
      }
      if (done) {
        continue;
      }
    }
    out += text[i];
  }
  return out;
}

struct Element {
  std::string tag;
  std::map<std::string, std::string> attributes;
};

// The start tags of `text` with their attributes (names lowercased); comments and declarations skipped. False if a
// tag is not closed or an attribute is malformed.
bool ParseTags(const std::string& text, std::vector<Element>* out) {
  size_t pos = 0;
  while ((pos = text.find('<', pos)) != std::string::npos) {
    if (text.compare(pos, 4, "<!--") == 0) {
      const size_t end = text.find("-->", pos + 4);
      if (end == std::string::npos) {
        return false;
      }
      pos = end + 3;
      continue;
    }
    size_t gt = pos + 1;
    for (char quote = 0; gt < text.size(); ++gt) {
      const char c = text[gt];
      if (quote != 0) {
        quote = c == quote ? 0 : quote;
      } else if (c == '"' || c == '\'') {
        quote = c;
      } else if (c == '>') {
        break;
      }
    }
    if (gt >= text.size()) {
      return false;
    }
    const std::string body = text.substr(pos + 1, gt - pos - 1);
    pos = gt + 1;
    if (body.empty() || body[0] == '?' || body[0] == '!' || body[0] == '/') {
      continue;
    }
    Element element;
    size_t i = 0;
    while (i < body.size() && (std::isalnum(static_cast<unsigned char>(body[i])) || body[i] == '_')) {
      ++i;
    }
    element.tag = Lower(body.substr(0, i));
    while (i < body.size()) {
      while (i < body.size() && (std::isspace(static_cast<unsigned char>(body[i])) || body[i] == '/')) {
        ++i;
      }
      if (i >= body.size()) {
        break;
      }
      const size_t nameStart = i;
      while (i < body.size() && body[i] != '=' && !std::isspace(static_cast<unsigned char>(body[i]))) {
        ++i;
      }
      const std::string name = Lower(body.substr(nameStart, i - nameStart));
      while (i < body.size() && std::isspace(static_cast<unsigned char>(body[i]))) {
        ++i;
      }
      if (i >= body.size() || body[i] != '=') {
        return false;
      }
      ++i;
      while (i < body.size() && std::isspace(static_cast<unsigned char>(body[i]))) {
        ++i;
      }
      if (i >= body.size() || (body[i] != '"' && body[i] != '\'')) {
        return false;
      }
      const size_t close = body.find(body[i], i + 1);
      if (close == std::string::npos) {
        return false;
      }
      element.attributes[name] = Decode(body.substr(i + 1, close - i - 1));
      i = close + 1;
    }
    out->push_back(std::move(element));
  }
  return true;
}

const std::string* Attr(const Element& element, const char* name) {
  const auto found = element.attributes.find(name);
  return found == element.attributes.end() ? nullptr : &found->second;
}

std::vector<std::string> SplitList(const std::string& text) {
  std::vector<std::string> out;
  size_t start = 0;
  while (start <= text.size()) {
    const size_t comma = text.find(',', start);
    const std::string part = Trim(text.substr(start, comma == std::string::npos ? std::string::npos : comma - start));
    if (!part.empty()) {
      out.push_back(part);
    }
    if (comma == std::string::npos) {
      break;
    }
    start = comma + 1;
  }
  return out;
}

std::wstring Label(const Element& element) {
  if (const std::string* id = Attr(element, "labelid")) {
    return L"\x01" + Wide(*id);  // resolved when shown: the string table is read after the DLL starts
  }
  const std::string* label = Attr(element, "label");
  return label == nullptr ? std::wstring() : ExpandIcons(Wide(*label));
}

// tip="..." or tipId="..." (a string ID, resolved when shown, as labelId).
std::wstring Tip(const Element& element) {
  if (const std::string* id = Attr(element, "tipid")) {
    return L"\x01" + Wide(*id);
  }
  const std::string* tip = Attr(element, "tip");
  return tip == nullptr ? std::wstring() : Wide(*tip);
}

bool LoadRows(const std::string& arg) {
  std::wstring path;
  std::string raw;
  std::string text;
  if (uhc::ReadDataListFile(arg, L"minuirows.xml", &path, &raw)) {
    g_file = path;
    if (raw.size() >= 2 && static_cast<unsigned char>(raw[0]) == 0xFF && static_cast<unsigned char>(raw[1]) == 0xFE) {
      const wchar_t* wide = reinterpret_cast<const wchar_t*>(raw.data() + 2);
      const int count = static_cast<int>((raw.size() - 2) / 2);
      const int length = WideCharToMultiByte(CP_UTF8, 0, wide, count, nullptr, 0, nullptr, nullptr);
      text.assign(static_cast<size_t>(length), '\0');
      WideCharToMultiByte(CP_UTF8, 0, wide, count, text.data(), length, nullptr, nullptr);
    } else {
      text = raw.compare(0, 3, "\xEF\xBB\xBF") == 0 ? raw.substr(3) : raw;
    }
  } else if (!arg.empty()) {
    uhc::Log(L"minUIStats: cannot read %ls (error %lu); feature not applied", path.c_str(), GetLastError());
    return false;
  } else {
    g_file = L"(built-in rows; no " + path + L")";
    text = kDefaultRows;
  }
  std::vector<Element> elements;
  if (!ParseTags(text, &elements)) {
    uhc::Log(L"minUIStats: %ls is not well-formed XML; feature not applied", g_file.c_str());
    return false;
  }
  std::map<std::string, TypeFilter*> filters;
  auto typeList = [&](const Element& element) {
    std::vector<TypeFilter*> list;
    if (const std::string* types = Attr(element, "types")) {
      for (const std::string& name : SplitList(*types)) {
        TypeFilter*& filter = filters[Lower(name)];
        if (filter == nullptr) {
          filter = new TypeFilter{name};
          g_filters.push_back(filter);
        }
        list.push_back(filter);
      }
    }
    return list;
  };
  // overlap="show" keeps a row over the stack portraits and <avoid> gadgets; "hide" (the default) hides it there.
  auto keepOnOverlap = [&](const Element& element) {
    const std::string* overlap = Attr(element, "overlap");
    if (overlap == nullptr || _stricmp(Trim(*overlap).c_str(), "hide") == 0) {
      return false;
    }
    if (_stricmp(Trim(*overlap).c_str(), "show") != 0) {
      uhc::Log(L"minUIStats: %ls: overlap=\"%hs\" is not hide or show; hide used", g_file.c_str(), overlap->c_str());
      return false;
    }
    return true;
  };
  for (const Element& element : elements) {
    if (element.tag == "minuirows") {
      continue;
    }
    if (element.tag == "avoid") {
      const std::string* gadget = Attr(element, "gadget");
      if (gadget == nullptr || Trim(*gadget).empty()) {
        uhc::Log(L"minUIStats: %ls: avoid needs gadget; ignored", g_file.c_str());
        continue;
      }
      g_avoid.push_back(Wide(Trim(*gadget)));
      continue;
    }
    if (element.tag == "row") {
      const std::string* gadget = Attr(element, "gadget");
      const std::string* item = Attr(element, "item");
      const std::string* text = Attr(element, "text");
      const ItemInfo* info = item == nullptr ? nullptr : FindItem(Trim(*item));
      if (gadget == nullptr || (info == nullptr && text == nullptr)) {
        uhc::Log(L"minUIStats: %ls: a row needs gadget and a known item= (%hs) or text=; ignored", g_file.c_str(),
                 item == nullptr ? "none" : item->c_str());
        continue;
      }
      if (text != nullptr) {
        const std::wstring wide = Wide(*text);
        for (size_t open = wide.find(L'{'); open != std::wstring::npos; open = wide.find(L'{', open + 1)) {
          const size_t close = wide.find(L'}', open);
          const std::wstring name = close == std::wstring::npos ? L"" : wide.substr(open + 1, close - open - 1);
          if (FindItem(std::string(name.begin(), name.end())) == nullptr) {
            uhc::Log(L"minUIStats: %ls: unknown item {%ls} in a text= row; its segment never shows", g_file.c_str(),
                     name.c_str());
          }
        }
        const std::string* join = Attr(element, "join");
        g_rows.push_back({Wide(Trim(*gadget)), nullptr, L"", ExpandIcons(wide), typeList(element),
                          keepOnOverlap(element), Tip(element),
                          join != nullptr && _stricmp(Trim(*join).c_str(), "line") == 0});
      } else {
        g_rows.push_back({Wide(Trim(*gadget)), info, Label(element), L"", typeList(element), keepOnOverlap(element),
                          Tip(element)});
      }
      continue;
    }
    if (element.tag == "replace") {
      const std::string* row = Attr(element, "row");
      const std::string* stock = Attr(element, "stock");
      if (row == nullptr || stock == nullptr) {
        uhc::Log(L"minUIStats: %ls: replace needs row and stock; ignored", g_file.c_str());
        continue;
      }
      Replace replace{Wide(Trim(*row)), {}};
      for (const std::string& name : SplitList(*stock)) {
        replace.stock.push_back(Wide(name));
      }
      g_replaces.push_back(replace);
      continue;
    }
    if (element.tag == "stocklabel") {
      const std::string* gadget = Attr(element, "gadget");
      const std::string* labelText = Attr(element, "text");
      if (gadget == nullptr || labelText == nullptr) {
        uhc::Log(L"minUIStats: %ls: stockLabel needs gadget and text; ignored", g_file.c_str());
        continue;
      }
      g_labels.push_back({Wide(Trim(*gadget)), ExpandIcons(Wide(*labelText)), Tip(element)});
      continue;
    }
    if (element.tag == "bigpanelrows") {
      const std::string* gadget = Attr(element, "gadget");
      if (gadget == nullptr || gadget->find("%d") == std::string::npos) {
        uhc::Log(L"minUIStats: %ls: bigPanelRows needs gadget with %%d; ignored", g_file.c_str());
        continue;
      }
      g_big.on = true;
      g_big.pattern = Wide(Trim(*gadget));
      g_big.keep = keepOnOverlap(element);
      if (const std::string* first = Attr(element, "first")) {
        g_big.first = std::atoi(first->c_str());
      }
      if (const std::string* count = Attr(element, "count")) {
        g_big.count = std::atoi(count->c_str());
      }
      if (const std::string* skip = Attr(element, "skip")) {
        static const struct { const char* name; std::uint32_t kind; } kKinds[] = {
            {"auto", kAuto}, {"name", kName}, {"hitpoints", kHitpoints}, {"grouphealth", kGroupHealth},
            {"resource", kResource}, {"gatherers", kGatherers}, {"rate", kRate}, {"speed", kSpeed},
            {"resists", kResists}, {"attacks", kAttack}, {"shownattacks", kShownAttack}, {"special", kSpecial},
            {"other", kOther}};
        g_big.skip = 0;
        for (const std::string& part : SplitList(*skip)) {
          bool known = false;
          for (const auto& kind : kKinds) {
            if (_stricmp(kind.name, part.c_str()) == 0) {
              g_big.skip |= kind.kind;
              known = true;
            }
          }
          if (!known) {
            uhc::Log(L"minUIStats: %ls: unknown skip kind %hs; ignored", g_file.c_str(), part.c_str());
          }
        }
      }
      g_big.count = g_big.count < 2 ? 2 : (g_big.count > 32 ? 32 : g_big.count);
      if (const std::string* stock = Attr(element, "stockrows")) {
        g_big.takeStock = _stricmp(Trim(*stock).c_str(), "take") == 0;
        if (!g_big.takeStock && _stricmp(Trim(*stock).c_str(), "keep") != 0) {
          uhc::Log(L"minUIStats: %ls: stockRows=\"%hs\" is not take or keep; keep used", g_file.c_str(), stock->c_str());
        }
      }
      if (const std::string* rof = Attr(element, "roficon")) {
        g_big.rofIcon = Wide(Trim(*rof));
      }
      if (const std::string* projectiles = Attr(element, "projectilesicon")) {
        g_big.projectilesIcon = Wide(Trim(*projectiles));
      }
      if (const std::string* abilities = Attr(element, "abilities")) {
        g_filterAbilities = _stricmp(Trim(*abilities).c_str(), "all") != 0;
      }
      continue;
    }
    uhc::Log(L"minUIStats: %ls: unknown element <%hs>; ignored", g_file.c_str(), element.tag.c_str());
  }
  return true;
}

// ---- The gadgets of the panel ----

struct Gadget {
  std::int32_t handle = 0;
  bool valid = false;
  bool shown = true;  // as far as the DLL knows: show and hide only on a change
  bool known = false;
  std::wstring text;
  std::uint32_t style = 0;
  std::wstring tip;
};

constexpr std::uint32_t kStockRows = 0x344;      // the selection panel's StackLabel0..2 handles (bind 0x9BB18F)
constexpr std::uint32_t kResourceLabel = 0x300;  // unitResourceLabel: shown, the attack rows start at StackLabel1

struct PanelGadgets {
  char* panel = nullptr;
  std::int32_t typeNameHandle = 0;
  std::vector<Gadget> rows;  // g_rows order
  std::vector<Gadget> big;   // the bigPanelRows block, consecutive gadgets
  std::vector<std::int32_t> avoid;  // the <avoid> gadgets this layout has
  std::vector<Gadget> stock;        // StackLabel0..2 ([panel+344h+i*4]), written by the key with stockRows="take"
  std::vector<std::int32_t> labels; // the <stockLabel> gadgets, in g_labels order (0 when the layout lacks one)
  struct ReplaceState {
    int row = -1;                       // its index in g_rows, or -1
    std::vector<std::int32_t> stock;    // the original gadgets this layout has
    bool active = false;                // the row showed at the last full fill
  };
  std::vector<ReplaceState> replaces;  // in g_replaces order
  bool any = false;
  bool logged = false;  // the first fill with stack portraits in our rows' band was logged
};
PanelGadgets g_panel;

void* Manager() {
  const char* ui = *reinterpret_cast<const char* const*>(kUiManager);
  return ui == nullptr ? nullptr : Field<void*>(ui, 0x44);
}

std::int32_t Lookup(char* panel, const std::wstring& name) {
  BString text{nullptr};
  kBStringFromWide(&text, name.c_str());
  std::int32_t handle = 0;
  kGadgetByName(panel, &handle, &text, 1);
  kBStringFree(&text);
  return handle;
}

bool ValidHandle(std::int32_t handle) {
  return handle != *reinterpret_cast<const std::int32_t*>(kNoGadget) && handle != 0;
}

// The gadget object behind a handle, or null; the reference is released at once, as stock does.
void* GadgetObject(std::int32_t handle) {
  std::int32_t ref[2] = {0, 0};
  std::int32_t* result = kGadgetRef(ref, handle);
  void* gadget = reinterpret_cast<void*>(static_cast<std::intptr_t>(result[1]));
  if (gadget != nullptr) {
    kGadgetRelease(result[0]);
  }
  return gadget;
}

// Finds this panel's gadgets by name, once per panel (the panel's own type name handle tells a new panel at the
// same address).
void ResolvePanel(char* panel) {
  const std::int32_t typeName = Field<std::int32_t>(panel, 0x2E8);
  if (g_panel.panel == panel && g_panel.typeNameHandle == typeName) {
    return;
  }
  g_panel = PanelGadgets{};
  g_panel.panel = panel;
  g_panel.typeNameHandle = typeName;
  for (const Row& row : g_rows) {
    Gadget gadget;
    gadget.handle = Lookup(panel, row.gadget);
    gadget.valid = ValidHandle(gadget.handle);
    g_panel.any |= gadget.valid;
    g_panel.rows.push_back(gadget);
  }
  if (g_big.on) {
    for (int i = 0; i < g_big.count; ++i) {
      wchar_t name[160];
      swprintf_s(name, g_big.pattern.c_str(), g_big.first + i);
      Gadget gadget;
      gadget.handle = Lookup(panel, name);
      gadget.valid = ValidHandle(gadget.handle);
      if (!gadget.valid) {
        break;
      }
      g_panel.big.push_back(gadget);
    }
    g_panel.any |= !g_panel.big.empty();
  }
  for (const std::wstring& name : g_avoid) {
    const std::int32_t handle = Lookup(panel, name);
    if (ValidHandle(handle)) {
      g_panel.avoid.push_back(handle);
    }
  }
  if (g_big.takeStock) {
    for (int i = 0; i < 3; ++i) {
      Gadget gadget;
      gadget.handle = Field<std::int32_t>(panel, kStockRows + 4u * i);
      gadget.valid = ValidHandle(gadget.handle);
      g_panel.stock.push_back(gadget);
    }
  }
  for (const StockLabel& label : g_labels) {
    const std::int32_t handle = Lookup(panel, label.gadget);
    g_panel.labels.push_back(ValidHandle(handle) ? handle : 0);
  }
  for (const Replace& replace : g_replaces) {
    PanelGadgets::ReplaceState state;
    for (size_t i = 0; i < g_rows.size(); ++i) {
      if (_wcsicmp(g_rows[i].gadget.c_str(), replace.row.c_str()) == 0 && g_panel.rows[i].valid) {
        state.row = static_cast<int>(i);
      }
    }
    for (const std::wstring& name : replace.stock) {
      const std::int32_t handle = Lookup(panel, name);
      if (ValidHandle(handle)) {
        state.stock.push_back(handle);
      }
    }
    g_panel.replaces.push_back(state);
  }
  int rows = 0;
  for (const Gadget& g : g_panel.rows) {
    rows += g.valid ? 1 : 0;
  }
  uhc::Log(L"minUIStats: panel %p: %d of %u row gadgets, %u big panel row gadgets", panel, rows,
           static_cast<unsigned>(g_panel.rows.size()), static_cast<unsigned>(g_panel.big.size()));
}

void SetVisible(Gadget* gadget, bool visible) {
  void* manager = Manager();
  if (manager == nullptr || (gadget->known && gadget->shown == visible)) {
    return;
  }
  (visible ? kGadgetShow : kGadgetHide)(manager, gadget->handle);
  gadget->shown = visible;
  gadget->known = true;
}

// Writes the gadget's text (and style, when not 0, and help text) only when they changed.
void SetText(Gadget* gadget, const std::wstring& text, std::uint32_t style, const std::wstring& tip) {
  if (gadget->text == text && gadget->style == style && gadget->tip == tip && !gadget->text.empty()) {
    SetVisible(gadget, true);
    return;
  }
  void* object = GadgetObject(gadget->handle);
  if (object == nullptr) {
    return;
  }
  BString value{nullptr};
  kBStringFromWide(&value, text.c_str());
  if (style != 0) {
    VirtualAt<void(__thiscall*)(void*, std::uint32_t)>(object, 0x84)(object, style);
  }
  VirtualAt<void(__thiscall*)(void*, const BString*)>(object, 0x80)(object, &value);
  VirtualAt<void(__thiscall*)(void*)>(object, 0x54)(object);
  kBStringFree(&value);
  BString help{nullptr};
  kBStringFromWide(&help, tip.c_str());
  kBStringSet(reinterpret_cast<BString*>(static_cast<char*>(object) + kGadgetTip), &help);
  kBStringFree(&help);
  gadget->text = text;
  gadget->style = style;
  gadget->tip = tip;
  SetVisible(gadget, true);
}

void Hide(Gadget* gadget) {
  gadget->text.clear();
  SetVisible(gadget, false);
}

// A gadget the panel's own fill writes and shows each time (the original attack rows and labels): what the DLL
// knows of it is stale after every fill, so it is written again as if new.
void ForceText(Gadget* gadget, const std::wstring& text, std::uint32_t style, const std::wstring& tip) {
  gadget->text.clear();
  gadget->known = false;
  SetText(gadget, text, style, tip);
}

void ForceHide(Gadget* gadget) {
  gadget->known = false;
  Hide(gadget);
}

// A label of the original panel: only its text (and help text when one is given), not whether it shows.
void WriteLabel(std::int32_t handle, const std::wstring& text, const std::wstring& tip) {
  void* object = GadgetObject(handle);
  if (object == nullptr) {
    return;
  }
  BString value{nullptr};
  kBStringFromWide(&value, text.c_str());
  VirtualAt<void(__thiscall*)(void*, const BString*)>(object, 0x80)(object, &value);
  VirtualAt<void(__thiscall*)(void*)>(object, 0x54)(object);
  kBStringFree(&value);
  if (!tip.empty()) {
    BString help{nullptr};
    kBStringFromWide(&help, tip.c_str());
    kBStringSet(reinterpret_cast<BString*>(static_cast<char*>(object) + kGadgetTip), &help);
    kBStringFree(&help);
  }
}

// ---- The stack portraits and the <avoid> gadgets: where a row must not be drawn ----

// A gadget's rectangle in screen pixels: its top left point at +28h ({x, y} as fractions of the screen, then
// {x, y} in pixels at +30h / +34h) and its bottom right one at +38h (+40h / +44h), as 0x44B9D8 and the stack
// layout 0x4C8F49 read them. Every gadget of the screen uses the same space, whatever its parent.
struct Box {
  std::int32_t left = 0, top = 0, right = 0, bottom = 0;
  float screenHeight = 0.0f;  // the screen's height in pixels, from the gadget's top as pixels and as a fraction
};

// Any gadget behind a handle, buttons included (0x404296: the lookup 0x40423C with type mask 0; GadgetObject's
// 0x44900A asks for mask 10h, which a button does not have), released at once as the stack layout does (0x40431B).
using GadgetAnyFn = void*(__cdecl*)(std::int32_t handle);
const auto kGadgetAny = reinterpret_cast<GadgetAnyFn>(0x00404296);

bool g_anyLookup = false;  // 0x404296 holds the stock bytes

const char* AnyGadget(std::int32_t handle) {
  if (!g_anyLookup) {
    return nullptr;
  }
  void* object = kGadgetAny(handle);
  if (object != nullptr) {
    kGadgetRelease(handle);
  }
  return static_cast<const char*>(object);
}

bool GadgetBox(std::int32_t handle, Box* out) {
  if (!ValidHandle(handle)) {
    return false;
  }
  const char* object = AnyGadget(handle);
  if (object == nullptr) {
    return false;
  }
  *out = {Field<std::int32_t>(object, 0x30), Field<std::int32_t>(object, 0x34), Field<std::int32_t>(object, 0x40),
          Field<std::int32_t>(object, 0x44)};
  const float fy = Field<float>(object, 0x2C);  // the top as a fraction of the screen
  out->screenHeight = fy > 0.01f ? static_cast<float>(out->top) / fy : 0.0f;
  return out->right > out->left && out->bottom > out->top;
}

// About how wide one character of the panel's text font is, in pixels: the font follows the screen's height, not the
// gadget's (measured at 1920 x 1080: 38 characters and two icons, an icon counting as two, in 210 px, 4.9 px each).
float CharPixels(const Box& box) {
  return box.screenHeight > 0.0f ? 0.00452f * box.screenHeight : 0.217f * 23.0f;
}

// Shown, as the base show (0x447BBC) tests it before doing nothing: flag bits 0 and 1 of [gadget+0A4h] set, bit 7
// clear.
bool GadgetShown(std::int32_t handle) {
  if (!ValidHandle(handle)) {
    return false;
  }
  const char* object = AnyGadget(handle);
  const std::uint8_t flags = object == nullptr ? 0 : Field<std::uint8_t>(object, 0xA4);
  return (flags & 0x03) == 0x03 && (flags & 0x80) == 0;
}

constexpr std::uint32_t kStackPlaced = 0x2CC;     // the buttons the stack fill placed this fill {data, count}
constexpr std::uint32_t kStackBigIndex = 0x36C;   // the index of the current stack's Big0 in that list, or -1
constexpr std::uint32_t kStackBigBack = 0x324;    // unitStackButtonBigBackground
constexpr int kMaxStackButtons = 16;              // 9 small + Big0 in the stock fill

struct Blockers {
  std::vector<Box> stack;  // the portraits the panel shows now
  std::vector<Box> avoid;  // the <avoid> gadgets shown now
};

// The stack portraits as the selection panel's fill placed them earlier in this same fill (0x4C940E: the list
// [panel+2CCh] emptied, then one button per stack, at most 9; 0x4C8F49 centred them in buttonArea and showed
// them, with the big background around the current one), and the <avoid> gadgets that are shown.
void CollectBlockers(const char* panel, Blockers* out) {
  out->stack.clear();
  out->avoid.clear();
  if (g_stackReads) {
    const std::int32_t* placed = Field<const std::int32_t*>(panel, kStackPlaced);
    const std::int32_t count = Field<std::int32_t>(panel, kStackPlaced + 4);
    for (std::int32_t i = 0; placed != nullptr && i < count && i < kMaxStackButtons; ++i) {
      Box box;
      if (GadgetBox(placed[i], &box)) {
        out->stack.push_back(box);
      }
    }
    const std::int32_t big = Field<std::int32_t>(panel, kStackBigIndex);
    Box box;
    if (big >= 0 && big < count && GadgetBox(Field<std::int32_t>(panel, kStackBigBack), &box)) {
      out->stack.push_back(box);
    }
  }
  for (const std::int32_t handle : g_panel.avoid) {
    Box box;
    if (GadgetShown(handle) && GadgetBox(handle, &box)) {
      out->avoid.push_back(box);
    }
  }
}

// A portrait is an image that fills its rectangle: any common pixel blocks the row. A text gadget's rectangle is
// padded (the stock ones overlap each other by a few pixels): it blocks only a row it covers over more than half
// the row's height.
bool Blocked(const Gadget& gadget, const Blockers& blockers) {
  if (blockers.stack.empty() && blockers.avoid.empty()) {
    return false;
  }
  Box own;
  if (!GadgetBox(gadget.handle, &own)) {
    return false;
  }
  auto across = [&](const Box& other) {
    return (std::min)(own.right, other.right) - (std::max)(own.left, other.left);
  };
  auto down = [&](const Box& other) {
    return (std::min)(own.bottom, other.bottom) - (std::max)(own.top, other.top);
  };
  for (const Box& box : blockers.stack) {
    if (across(box) > 0 && down(box) > 0) {
      return true;
    }
  }
  for (const Box& box : blockers.avoid) {
    if (across(box) > 0 && 2 * down(box) > own.bottom - own.top) {
      return true;
    }
  }
  return false;
}

// Once per panel, the first time the portraits cover one of our rows: where they are, for the log.
void LogBlocked(const Blockers& blockers, const std::wstring& names) {
  if (g_panel.logged) {
    return;
  }
  g_panel.logged = true;
  std::wstring boxes;
  for (const Box& box : blockers.stack) {
    wchar_t text[64];
    swprintf_s(text, L" %d,%d-%d,%d", box.left, box.top, box.right, box.bottom);
    boxes += text;
  }
  uhc::Log(L"minUIStats: %u stack portraits (px%ls) and %u avoid gadgets shown; hidden for them:%ls",
           static_cast<unsigned>(blockers.stack.size()), boxes.c_str(), static_cast<unsigned>(blockers.avoid.size()),
           names.c_str());
}

// ---- The mirrored stat panel rows ----

struct StatRow {
  std::uint32_t labelStyle = 0;
  std::wstring label;
  std::wstring value;
  std::wstring tip;
  bool labelSet = false;
  bool valueSet = false;
};

constexpr int kVtableSlots = 128;
void* g_stageLabel = nullptr;
void* g_stageValue = nullptr;
StatRow g_current;
std::vector<StatRow> g_stat;
void* g_vtableCopy[kVtableSlots];
const void* g_vtableOf = nullptr;

std::wstring BStringText(const void* field) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(field);
  return text == nullptr ? std::wstring() : std::wstring(text);
}

void FinishRow() {
  if (!g_current.labelSet && !g_current.valueSet) {
    return;
  }
  g_current.tip = BStringText(static_cast<char*>(g_stageLabel) + kGadgetTip);
  g_stat.push_back(g_current);
  g_current = StatRow{};
}

// The staging gadgets' vtable entries while the fill runs (thiscall: ECX = the gadget, the callee pops the
// arguments, as __fastcall with the EDX slot unused does).
void __fastcall RecordStyle(void* gadget, void*, std::uint32_t style) {
  if (gadget == g_stageLabel) {
    if (g_current.labelSet || g_current.valueSet) {
      FinishRow();
    }
    g_current.labelStyle = style;
  }
}

void __fastcall RecordText(void* gadget, void*, const BString* text) {
  const std::wstring copy = text == nullptr || text->text == nullptr ? std::wstring() : std::wstring(text->text);
  if (gadget == g_stageLabel) {
    if (g_current.labelSet) {
      FinishRow();
    }
    g_current.label = copy;
    g_current.labelSet = true;
  } else if (gadget == g_stageValue) {
    g_current.value = copy;
    g_current.valueSet = true;
  }
}

void __fastcall RecordRefresh(void*, void*) {}
void __fastcall RecordShow(void*, void*, std::int32_t) {}

// The fill's rows for the selection, as the normal interface's stat panel would show them; false if it could not
// run. The fill writes row i into the gadgets of handles [panel+174h+i*4] / [panel+198h+i*4] and reads nothing
// else of its panel; here every row points to the same two staging gadgets, whose text, style, refresh and
// show calls are recorded instead of done while it runs.
bool MirrorStatRows(const char* selection) {
  if (g_panel.big.size() < 2) {
    return false;
  }
  void* label = GadgetObject(g_panel.big[0].handle);
  void* value = GadgetObject(g_panel.big[1].handle);
  if (label == nullptr || value == nullptr || label == value) {
    return false;
  }
  const void* vtable = *static_cast<void**>(label);
  if (vtable != *static_cast<void**>(value)) {
    return false;
  }
  if (g_vtableOf != vtable) {
    std::memcpy(g_vtableCopy, vtable, sizeof(g_vtableCopy));
    g_vtableCopy[0x54 / 4] = reinterpret_cast<void*>(&RecordRefresh);
    g_vtableCopy[0x58 / 4] = reinterpret_cast<void*>(&RecordShow);
    g_vtableCopy[0x80 / 4] = reinterpret_cast<void*>(&RecordText);
    g_vtableCopy[0x84 / 4] = reinterpret_cast<void*>(&RecordStyle);
    g_vtableOf = vtable;
  }
  char panel[kStatRowValues + 4 * kStatRows] = {};
  for (int i = 0; i < kStatRows; ++i) {
    *reinterpret_cast<std::int32_t*>(panel + kStatRowLabels + 4 * i) = g_panel.big[0].handle;
    *reinterpret_cast<std::int32_t*>(panel + kStatRowValues + 4 * i) = g_panel.big[1].handle;
  }
  // The staging gadgets' help texts, which the fill overwrites, are put back after.
  const std::wstring labelTip = BStringText(static_cast<char*>(label) + kGadgetTip);
  const std::wstring valueTip = BStringText(static_cast<char*>(value) + kGadgetTip);
  g_stageLabel = label;
  g_stageValue = value;
  g_current = StatRow{};
  g_stat.clear();
  *static_cast<const void**>(label) = g_vtableCopy;
  *static_cast<const void**>(value) = g_vtableCopy;
  g_uhcMinUiForceFill = 1;
  kStatFill(panel, selection);
  g_uhcMinUiForceFill = 0;
  FinishRow();
  *static_cast<const void**>(label) = vtable;
  *static_cast<const void**>(value) = vtable;
  for (const auto& [object, tip] : {std::pair<void*, const std::wstring*>{label, &labelTip}, {value, &valueTip}}) {
    BString help{nullptr};
    kBStringFromWide(&help, tip->c_str());
    kBStringSet(reinterpret_cast<BString*>(static_cast<char*>(object) + kGadgetTip), &help);
    kBStringFree(&help);
  }
  g_stageLabel = g_stageValue = nullptr;
  return true;
}

struct KindStrings {
  std::wstring hitpoints, speed, resists, gatherers;
  bool loaded = false;
} g_strings;

void LoadKindStrings() {
  if (g_strings.loaded) {
    return;
  }
  g_strings.hitpoints = StringById(24320);  // "Hitpoints:" (0x4D750E)
  g_strings.speed = StringById(24323);      // "Speed:" (0x69B21C)
  g_strings.resists = StringById(35758);    // "Resists:" (0x69B3DF)
  g_strings.gatherers = StringById(34986);  // "Gatherers:" (0x69AED2)
  g_strings.loaded = !g_strings.hitpoints.empty();
}

std::uint32_t Classify(const StatRow& row, size_t index) {
  if (index == 0) {
    return kName;
  }
  if (row.labelStyle == kAttackStyle) {
    return kAttack;
  }
  if (row.label == g_strings.hitpoints) {
    return kHitpoints;
  }
  if (row.label == g_strings.speed) {
    return kSpeed;
  }
  if (row.label == g_strings.resists) {
    return kResists;
  }
  if (row.label == g_strings.gatherers) {
    return kGatherers;
  }
  if (row.label == L"Group Health") {  // a literal in the exe (0xC36838)
    return kGroupHealth;
  }
  if (row.value.size() >= 2 && row.value.compare(row.value.size() - 2, 2, L"/s") == 0) {
    return kRate;
  }
  if (row.label.find(L"<icon=\"(32)") != std::wstring::npos) {
    return kResource;  // "%s (<icon="(32)(%S)">):" with a held amount
  }
  return kOther;
}

// The stat panel fill stops at its 9th row (0x4D7957: cmp ebx,9 / jge): a unit with more attacks than rows left
// loses the last ones. They are added after the fill's last attack row, from the same list (0x487EEE, every action
// it gives, as the fill writes a row for each) and in the fill's own format (AttackRow).
void AddOverflowAttacks(const char* unit, std::vector<std::uint32_t>* kinds, size_t* lastAttack) {
  if (!g_attackReads || unit == nullptr || g_stat.size() < static_cast<size_t>(kStatRows)) {
    return;
  }
  size_t written = 0;
  for (const std::uint32_t kind : *kinds) {
    written += kind == kAttack ? 1 : 0;
  }
  const std::vector<const char*> actions = Attacks(unit, true, false);  // as the fill lists them; MarkAttacks filters
  size_t at = *lastAttack;
  for (size_t i = written; i < actions.size() && i < 32; ++i) {
    StatRow row;
    if (!AttackRow(unit, actions[i], &row.label, &row.value)) {
      break;
    }
    row.labelStyle = kAttackStyle;
    row.labelSet = row.valueSet = true;
    g_stat.insert(g_stat.begin() + static_cast<std::ptrdiff_t>(at), row);
    kinds->insert(kinds->begin() + static_cast<std::ptrdiff_t>(at), kAttack);
    *lastAttack = ++at;
  }
}

// The text without its markup (<icon=...> and the like).
std::wstring StripMarkup(const std::wstring& text) {
  std::wstring out;
  bool tag = false;
  for (const wchar_t c : text) {
    if (c == L'<') {
      tag = true;
    } else if (c == L'>') {
      tag = false;
    } else if (!tag) {
      out += c;
    }
  }
  return out;
}

// Characters on screen, an icon counting as two.
size_t VisibleLength(const std::wstring& text) {
  size_t icons = 0;
  for (size_t at = text.find(L"<icon"); at != std::wstring::npos; at = text.find(L"<icon", at + 1)) {
    ++icons;
  }
  return StripMarkup(text).size() + 2 * icons;
}

// About how many characters of the stat font fit one line of the gadget (CharPixels, with 10 % to spare).
size_t LineBudget(const Gadget& gadget) {
  Box box;
  if (!GadgetBox(gadget.handle, &box) || box.bottom <= box.top) {
    return 30;
  }
  return static_cast<size_t>(0.9f * static_cast<float>(box.right - box.left) / CharPixels(box));
}

// A row in short form, for the last gadget when the rows outnumber the gadgets: an attack's name and damage (its
// value up to the first icon), any other row's label and value.
std::wstring Compact(const StatRow& row) {
  if (row.labelStyle != kAttackStyle) {
    return row.value.empty() ? row.label : row.label + L" " + row.value;
  }
  const size_t icon = row.value.find(L'>');
  std::wstring name = row.label;
  if (!name.empty() && name.back() == L':') {
    name.pop_back();
  }
  return name + L" " + (icon == std::wstring::npos ? row.value : row.value.substr(0, icon + 1));
}

// Every icon of a row at the minimized panel's icon size: the stat panel fill writes "(16)" icons (0xBA2100), the
// minimized block "(10)" ones (0xC36508), and both kinds of rows share the panel.
std::wstring NormaliseIcons(const std::wstring& text) {
  static const std::wstring kOpen = L"<icon=\"(";
  std::wstring out = text;
  for (size_t at = out.find(kOpen); at != std::wstring::npos; at = out.find(kOpen, at + 1)) {
    const size_t start = at + kOpen.size();
    const size_t close = out.find(L')', start);
    if (close == std::wstring::npos) {
      break;
    }
    out.replace(start, close - start, std::to_wstring(kIconSize));
  }
  return out;
}

// The attack rows of the fill (and the ones AddOverflowAttacks added), matched in order with the attack list they
// come from (0x487EEE, every listed action, as the fill writes one row per action): a row of an ability action the
// unit cannot use is dropped (ActionEnabled), the others get the minimized panel's icon size and, with rofIcon,
// the action's ROF after the damage: "Ranged ATK:  23 <ranged> 3 <rof> 12 <range>, 3x <cavalry>", and with
// projectilesIcon the projectiles it fires before its reload after that, when above 1 ("4 <cylinder>"). The row's
// label must be the action's name; at the first that is not, the matching stops (rows left as written).
void MarkAttacks(const char* unit, std::vector<std::uint32_t>* kinds) {
  const std::vector<const char*> actions = Attacks(unit, true, false);
  size_t next = 0;
  for (size_t i = 0; i < g_stat.size(); ++i) {
    if ((*kinds)[i] != kAttack) {
      continue;
    }
    StatRow& row = g_stat[i];
    row.value = NormaliseIcons(row.value);
    const std::wstring shown = StripMarkup(row.label);
    if (shown.find_first_not_of(L" :") == std::wstring::npos) {
      (*kinds)[i] = kDropped;  // nothing to read: a blank line in the panel
    }
    if (next >= actions.size()) {
      break;
    }
    const char* action = actions[next++];
    const std::wstring name = ActionDisplayName(action);
    if (row.label != name + L":") {
      break;
    }
    if (name.empty() || !ActionEnabled(unit, action)) {  // a nameless action's row is a blank line
      (*kinds)[i] = kDropped;
      continue;
    }
    const float rof = static_cast<float>(Field<std::int32_t>(action, 0x34)) / 1000.0f;
    const size_t icon = row.value.find(L"\">");
    if (icon == std::wstring::npos) {
      continue;
    }
    wchar_t size[16];
    swprintf_s(size, L"(%d)", kIconSize);
    size_t at = icon + 2;  // after the damage and its icon
    if (!g_big.rofIcon.empty() && rof > 0.0f) {
      const std::wstring text = L" " + Number(rof) + L" <icon=\"" + size + L"(" + g_big.rofIcon + L")\">";
      row.value.insert(at, text);
      at += text.size();
    }
    const int projectiles = g_big.projectilesIcon.empty() ? 1 : ProjectilesPerReload(unit, action);
    if (projectiles > 1) {
      row.value.insert(at, L" " + std::to_wstring(projectiles) + L" <icon=\"" + size + L"(" + g_big.projectilesIcon +
                               L")\">");
    }
  }
}

// What the key writes into the original attack rows this fill (stockRows="take"), written again after each fill of
// the panel, which rewrites them, until the next selection change or refresh.
struct StockWrite {
  bool show = false;
  std::wstring text;
  std::uint32_t style = 0;
  std::wstring tip;
};
std::vector<StockWrite> g_stockPlan;

void ApplyStockPlan() {
  for (size_t i = 0; i < g_stockPlan.size() && i < g_panel.stock.size(); ++i) {
    Gadget& gadget = g_panel.stock[i];
    if (!gadget.valid) {
      continue;
    }
    if (g_stockPlan[i].show) {
      ForceText(&gadget, g_stockPlan[i].text, g_stockPlan[i].style, g_stockPlan[i].tip);
    } else {
      ForceHide(&gadget);
    }
  }
}

constexpr std::uint32_t kResistsValue = 0x2FC;  // the selection panel's unitResistsValue handle

// With multiarmor, a proto can have an armor per damage type, and the minimized block writes only the stock one
// ("%.2f %s", 0x698C41..): its resists value then lists them all, "0.30 <hand>  0.20 <ranged>".
void ApplyResists(const char* unit) {
  unsigned char types[8];
  float values[8];
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const int n = proto == nullptr ? 0 : uhc::unitinfo::Armors(proto, types, values, 8);
  const std::int32_t handle = Field<std::int32_t>(g_panel.panel, kResistsValue);
  if (n < 2 || !ValidHandle(handle) || !GadgetShown(handle)) {
    return;
  }
  std::vector<std::pair<unsigned char, float>> armors;
  for (int i = 0; i < n; ++i) {
    armors.emplace_back(types[i], values[i]);
  }
  std::sort(armors.begin(), armors.end());  // by damage type: hand, ranged, siege, then the mod's own
  std::wstring text;
  for (const auto& [type, armor] : armors) {
    wchar_t value[32];
    swprintf_s(value, L"%.2f", static_cast<double>(armor));
    text += (text.empty() ? L"" : L"  ") + std::wstring(value) + TypeIcon(type);
  }
  WriteLabel(handle, text, L"");
}

// <replace>: the original gadgets of a row the key shows are hidden again after the panel's own fill showed them.
void ApplyReplaces() {
  void* manager = Manager();
  if (manager == nullptr) {
    return;
  }
  for (const auto& state : g_panel.replaces) {
    if (state.active) {
      for (const std::int32_t handle : state.stock) {
        kGadgetHide(manager, handle);
      }
    }
  }
}

// The <stockLabel> texts, while the original panel shows those labels.
void ApplyStockLabels(const char* unit) {
  ApplyResists(unit);
  for (size_t i = 0; i < g_labels.size() && i < g_panel.labels.size(); ++i) {
    if (g_panel.labels[i] != 0 && GadgetShown(g_panel.labels[i])) {
      std::wstring tip = g_labels[i].tip;
      if (!tip.empty() && tip[0] == L'\x01') {
        tip = StringById(_wtoi(tip.c_str() + 1));
        while (!tip.empty() && (tip.back() == L':' || tip.back() == L' ')) {
          tip.pop_back();
        }
      }
      WriteLabel(g_panel.labels[i], ExpandStrings(g_labels[i].text), ExpandStrings(tip));
    }
  }
}

void FillBigRows(const char* selection, const char* unit, bool minimizedBlock, const Blockers& blockers,
                 std::wstring* blockedNames) {
  const bool take = g_big.takeStock && minimizedBlock && g_panel.stock.size() == 3;
  g_stockPlan.clear();
  if (!MirrorStatRows(selection)) {
    for (Gadget& gadget : g_panel.big) {
      Hide(&gadget);
    }
    return;  // the original attack rows stay as the panel wrote them
  }
  LoadKindStrings();
  std::uint32_t skip = g_big.skip;
  bool resourceShown = false;
  std::vector<std::uint32_t> kinds;
  size_t lastAttack = 0;
  for (size_t i = 0; i < g_stat.size(); ++i) {
    kinds.push_back(Classify(g_stat[i], i));
    resourceShown |= kinds.back() == kResource;
    if (kinds.back() == kAttack) {
      lastAttack = i + 1;
    }
  }
  AddOverflowAttacks(unit, &kinds, &lastAttack);
  MarkAttacks(unit, &kinds);
  if (skip & kAuto) {
    // What the minimized block shows itself (0x6987D7..0x69A60F): the owner, hit points, resists, the resource held,
    // the AutoGather rate, the special attacks inline, and the first three rows of attacks less the resource row.
    // With stockRows="take" the key writes those attack and special rows itself, from the first original row on.
    skip |= minimizedBlock ? (kName | kHitpoints | kResists | kResource | kRate | kShownAttack | kSpecial) : kName;
  }
  if (take) {
    skip &= ~(kShownAttack | kSpecial);
  }
  skip |= kDropped;
  int shownAttacks = (skip & kShownAttack) ? (resourceShown ? 2 : 3) : 0;
  // The rows to show, in order.
  std::vector<const StatRow*> rows;
  for (size_t i = 0; i < g_stat.size(); ++i) {
    std::uint32_t kind = kinds[i];
    if (kind == kOther && lastAttack != 0 && i >= lastAttack) {
      kind = kSpecial;
    }
    if (kind == kAttack && shownAttacks > 0) {
      --shownAttacks;
      continue;
    }
    const std::wstring visible = StripMarkup(g_stat[i].label + g_stat[i].value);
    if (!(skip & kind) && visible.find_first_not_of(L" :") != std::wstring::npos) {
      rows.push_back(&g_stat[i]);  // a row with nothing to read would be a blank line
    }
  }
  // The gadgets the rows go into, in order: with stockRows="take", the original attack rows the minimized block
  // used (StackLabel0..2, from StackLabel1 when it showed a resource row), then the bigPanelRows block. A block
  // gadget under a stack portrait or a shown <avoid> gadget is left empty, and the rows go on in the next one; the
  // original rows are never covered (they are the panel's own lines).
  struct Slot {
    Gadget* gadget;
    int stock;  // its StackLabel index, or -1
  };
  std::vector<Slot> free;
  if (take) {
    g_stockPlan.assign(3, StockWrite{});
    // The block's resource row (its own gadgets, on the first line) moved its attacks down one line; a shown but
    // empty resource label (seen on cavalry) does not count, so both tests.
    const bool resourceRow = resourceShown && GadgetShown(Field<std::int32_t>(g_panel.panel, kResourceLabel));    for (int i = resourceRow ? 1 : 0; i < 3; ++i) {
      if (g_panel.stock[i].valid) {
        free.push_back({&g_panel.stock[i], i});
      }
    }
  }
  // An original row too long for its column (a Villero's ranged row with five multipliers reaches x ~600) runs under
  // the block gadget on its line: that gadget is left empty, and the rows go on in the next one (CharPixels per
  // character, an icon counting as two).
  std::vector<std::pair<Box, size_t>> stockLines;
  for (size_t n = 0; n < free.size() && n < rows.size(); ++n) {
    Box box;
    if (GadgetBox(free[n].gadget->handle, &box)) {
      stockLines.emplace_back(box, VisibleLength(rows[n]->label + L"  " + rows[n]->value));
    }
  }
  auto runsUnder = [&](const Gadget& gadget) {
    Box box;
    if (!GadgetBox(gadget.handle, &box)) {
      return false;
    }
    const int middle = (box.top + box.bottom) / 2;
    for (const auto& [line, chars] : stockLines) {
      if (middle > line.top && middle < line.bottom && box.left > line.left &&
          static_cast<float>(chars) * CharPixels(line) > static_cast<float>(box.left - line.left)) {
        return true;
      }
    }
    return false;
  };
  for (size_t k = 0; k < g_panel.big.size(); ++k) {
    if (runsUnder(g_panel.big[k])) {
      Hide(&g_panel.big[k]);
      continue;
    }
    if (!g_big.keep && Blocked(g_panel.big[k], blockers)) {
      Hide(&g_panel.big[k]);
      wchar_t name[160];
      swprintf_s(name, g_big.pattern.c_str(), g_big.first + static_cast<int>(k));
      *blockedNames += L" " + std::wstring(name);
    } else {
      free.push_back({&g_panel.big[k], -1});
    }
  }
  auto write = [](const Slot& slot, const std::wstring& text, std::uint32_t style, const std::wstring& tip) {
    if (slot.stock >= 0) {
      g_stockPlan[slot.stock] = {true, text, style, tip};
    } else {
      SetText(slot.gadget, text, style, tip);
    }
  };
  for (size_t n = 0; n < free.size(); ++n) {
    if (n >= rows.size()) {
      if (free[n].stock < 0) {
        Hide(free[n].gadget);
      }
      continue;  // an original row left empty stays hidden (its plan entry)
    }
    const StatRow& row = *rows[n];
    const std::uint32_t style = row.labelStyle == kAttackStyle ? kAttackStyle : kLabelStyle;
    if (n + 1 == free.size() && rows.size() > free.size()) {
      // One line: as many short rows as fit the gadget (a formatText wraps a longer text and centres it, which
      // would show a middle line), then "+N more"; the help text lists them all.
      const size_t budget = LineBudget(*free[n].gadget);
      std::wstring text;
      std::wstring tip;
      size_t shown = 0;
      for (size_t r = n; r < rows.size(); ++r) {
        const std::wstring part = Compact(*rows[r]);
        const size_t left = rows.size() - r - 1;
        const std::wstring more = left == 0 ? L"" : L" +" + std::to_wstring(left) + L" more";
        if (shown == 0 || VisibleLength(text + L"   " + part + more) <= budget) {
          text += (text.empty() ? L"" : L"   ") + part;
          ++shown;
        } else {
          text += L" +" + std::to_wstring(rows.size() - r) + L" more";
          break;
        }
      }
      for (size_t r = n; r < rows.size(); ++r) {
        tip += (tip.empty() ? L"" : L"\n") + StripMarkup(rows[r]->label + L" " + rows[r]->value);
      }
      write(free[n], text, style, tip);
      continue;
    }
    std::wstring text = row.label;
    if (!row.value.empty()) {
      text += L"  " + row.value;
    }
    if (free[n].stock < 0 && VisibleLength(text) > LineBudget(*free[n].gadget)) {
      // Too long for its column ("Anti-artillery Crackshot Attack", a Spanish name): name and damage, the whole row
      // in the help text, rather than a row cut at the panel's edge.
      write(free[n], Compact(row), style, StripMarkup(row.label + L" " + row.value));
      continue;
    }
    write(free[n], text, style, row.tip);
  }
  ApplyStockPlan();
}

bool Applies(const Row& row, const char* proto) {
  if (row.types.empty()) {
    return true;
  }
  for (const TypeFilter* filter : row.types) {
    if (filter->id >= 0 && kProtoIsType(proto, filter->id)) {
      return true;
    }
  }
  return false;
}

std::wstring ResolveLabel(const std::wstring& label) {
  if (!label.empty() && label[0] == L'\x01') {
    return StringById(_wtoi(label.c_str() + 1));
  }
  return ExpandStrings(label);
}

// The last selection the rows were written for, and when.
std::int32_t g_lastUnitId = -1;
std::int32_t g_lastCount = -1;
std::int32_t g_lastStacks = -1;
std::int32_t g_lastBigIndex = -2;
ULONGLONG g_lastTick = 0;
constexpr ULONGLONG kRefreshMs = 250;
bool g_busy = false;

void __stdcall MinUiTail(char* panel, const char* selection, const char* unit, bool minimizedBlock) {
  if (g_busy) {
    return;
  }
  ResolvePanel(panel);
  if (!g_panel.any) {
    return;  // a layout without these gadgets: the normal interface, or one that does not use them
  }
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const std::int32_t unitId = unit == nullptr ? -1 : Field<std::int32_t>(unit, 0x10);
  const std::int32_t count = selection == nullptr ? 0 : Field<std::int32_t>(selection, 0x14);
  // The portraits move with the number of stacks and the current one.
  const std::int32_t stacks = g_stackReads ? Field<std::int32_t>(panel, kStackPlaced + 4) : 0;
  const std::int32_t bigIndex = g_stackReads ? Field<std::int32_t>(panel, kStackBigIndex) : 0;
  const ULONGLONG now = GetTickCount64();
  if (unitId == g_lastUnitId && count == g_lastCount && stacks == g_lastStacks && bigIndex == g_lastBigIndex &&
      now - g_lastTick < kRefreshMs) {
    // The panel's own fill wrote its original rows and labels again: the key's texts go back over them.
    if (minimizedBlock) {
      g_busy = true;
      ApplyStockPlan();
      ApplyStockLabels(unit);
      ApplyReplaces();
      g_busy = false;
    }
    return;
  }
  g_lastUnitId = unitId;
  g_lastCount = count;
  g_lastStacks = stacks;
  g_lastBigIndex = bigIndex;
  g_lastTick = now;
  g_busy = true;
  Blockers blockers;
  CollectBlockers(panel, &blockers);
  std::wstring blockedNames;
  for (size_t i = 0; i < g_rows.size(); ++i) {
    Gadget& gadget = g_panel.rows[i];
    if (!gadget.valid) {
      continue;
    }
    if (!g_rows[i].keep && Blocked(gadget, blockers)) {
      Hide(&gadget);
      blockedNames += L" " + g_rows[i].gadget;
      continue;
    }
    std::wstring value;
    const bool has = proto != nullptr && Applies(g_rows[i], proto) &&
                     (g_rows[i].item != nullptr ? g_rows[i].item->fn(unit, &value)
                                                : RenderTemplate(g_rows[i].text, unit, &value, g_rows[i].lines));
    if (!has) {
      Hide(&gadget);
      continue;
    }
    SetText(&gadget, ResolveLabel(g_rows[i].label) + value, 0, ResolveLabel(g_rows[i].tip));
  }
  if (!g_panel.big.empty()) {
    if (proto == nullptr || selection == nullptr || count <= 0) {
      for (Gadget& gadget : g_panel.big) {
        Hide(&gadget);
      }
      g_stockPlan.clear();
    } else {
      FillBigRows(selection, unit, minimizedBlock, blockers, &blockedNames);
    }
  }
  for (auto& state : g_panel.replaces) {
    state.active = minimizedBlock && state.row >= 0 && g_panel.rows[state.row].shown &&
                   !g_panel.rows[state.row].text.empty();
  }
  if (minimizedBlock && proto != nullptr) {
    ApplyStockLabels(unit);
    ApplyReplaces();
  }
  if (!blockedNames.empty() && !blockers.stack.empty()) {
    LogBlocked(blockers, blockedNames);
  }
  g_busy = false;
}

void OnDatabase(char*) {}

}  // namespace

namespace uhc {

Outcome ApplyMinUiStats(const Config& config) {
  const Config::Args* args = config.First("minUIStats");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (args->size() > 1) {
    Log(L"minUIStats: expected at most one argument, the rows file; feature not applied");
    return Outcome::kFailed;
  }
  if (!LoadRows(args->empty() ? std::string() : args->front())) {
    return Outcome::kFailed;
  }
  if (!VerifyAll("minUIStats",
                 {&sites::kStatFillHead, &sites::kStatFillMinGate, &sites::kMinResistsUnitGate, &sites::kMinBlockChoice,
                  &sites::kGadgetByName, &sites::kGadgetRef, &sites::kGadgetRelease, &sites::kGadgetShow,
                  &sites::kGadgetHide, &sites::kBStringFromWide, &sites::kBStringFromId, &sites::kBStringSet,
                  &sites::kBStringAssign, &sites::kBStringFree, &sites::kCurrentUnitRef, &sites::kMaxHitpointsGetter,
                  &sites::kLosGetterHead, &sites::kMaxContained, &sites::kIsA, &sites::kAttackListFill,
                  &sites::kResListGet, &sites::kResourceIconText, &sites::kHoldsResource, &sites::kMainResource,
                  &sites::kHeldAmount, &sites::kUnitCarryCapacity})) {
    return Outcome::kFailed;
  }
  // The build and regeneration items mirror stock code they never write to; they are checked apart, so another DLL
  // that changed that code turns off only these items (each checks its flag), not the key.
  g_buildReads = AllMatch({&sites::kBuildTickRateHead, &sites::kBuildTickScale, &sites::kBuildTickAdd,
                           &sites::kBuildPointsAddCall, &sites::kBuildPointsAdd, &sites::kBuilderFactor,
                           &sites::kRateLookupHead});
  g_regenReads = AllMatch({&sites::kRegenPlayerHead, &sites::kRegenRateRead});
  if (!g_buildReads || !g_regenReads) {
    Log(L"minUIStats: the stock %ls code is not what these items mirror; %ls left empty",
        !g_buildReads ? L"build tick" : L"regeneration", !g_buildReads ? L"buildTime, buildProgress, buildRate" : L"regen");
  }
  g_anyLookup = AllMatch({&sites::kGadgetLookupAny});
  // Where the stack portraits are is read from the panel after the fill placed them; checked apart too, so a
  // changed stack code only stops the rows from making room for the portraits.
  g_stackReads = AllMatch({&sites::kStackFillReset, &sites::kStackFillCurrent, &sites::kStackFillAppend,
                           &sites::kStackLayoutCall, &sites::kStackLayout, &sites::kGadgetLookupAny});
  if (!g_stackReads) {
    Log(L"minUIStats: the stock stack portrait code is not what the rows read; rows are not hidden under portraits");
  }
  g_attackReads = AllMatch({&sites::kStatFillRowCap, &sites::kAttackRowName, &sites::kAttackRowDamage,
                            &sites::kAttackRowTypeIcon, &sites::kAttackRowRange, &sites::kAttackRowSiege,
                            &sites::kAttackRowCold, &sites::kAttackRowModifier, &sites::kAttackRowTyped,
                            &sites::kActionRawName, &sites::kActionRangeEntry});
  if (!g_attackReads) {
    Log(L"minUIStats: the stock attack row code is not what the rows mirror; attacks past the 9th stat row left out");
  }
  g_abilityReads =
      AllMatch({&sites::kAbilityAvailableTest, &sites::kPowerUnitActionStore, &sites::kPowerUnitActionVtable});
  if (!g_abilityReads && g_filterAbilities) {
    Log(L"minUIStats: the stock ability code is not what the rows mirror; ability attacks shown on every unit");
  }
  // Building armor: the minimized block's resists show only for type Unit (0x698BF6). The gate goes only while the
  // armor test after it is stock: another DLL's armor there (a multiarmor of its own) writes a text made for units only
  // ("0 (null)" on a building), so then buildings keep the stock rule and show no resists row.
  const bool buildingArmor = AllMatch({&sites::kMinResistsArmorTest});
  g_armorOther = !buildingArmor;
  if (!buildingArmor) {
    Log(L"minUIStats: another DLL changed the resists armor test (0x698BFC); building armor not shown, unit armor as "
        L"that DLL writes it (the armor items answer nothing)");
  }
  // The projectiles per reload (projectilesIcon, the projectiles item): the tactics tags shots.cpp reads, without any
  // effect on combat. Another DLL on the shared action tag site only leaves the number out.
  const bool shotTags = uhc::unitinfo::RequestShotTags();
  if (!shotTags) {
    Log(L"minUIStats: the action tags cannot be read; projectiles per reload not shown");
  }
  for (TypeFilter* filter : g_filters) {
    if (!RequestAbstractUnitType(filter->name.c_str(), &filter->id)) {
      return Outcome::kFailed;
    }
  }
  if (!RequestAbstractUnitType("Unit", &g_unitTypeId)) {  // the trainPoints item
    return Outcome::kFailed;
  }
  static const std::uint8_t kNops[6] = {0x90, 0x90, 0x90, 0x90, 0x90, 0x90};
  if (!WriteJmp(sites::kStatFillMinGate.va + 0x41, reinterpret_cast<const void*>(&UhcStatFillMinGate), 11) ||
      (buildingArmor && !WriteBytes(sites::kMinResistsUnitGate.va + 0x14, kNops, sizeof(kNops))) ||
      !AddUnitPanelTail(&MinUiTail) ||
      // After the tail hook, which verifies these bytes too: the minimized block also runs for a minimized layout
      // loaded without the profile option.
      !WriteJmp(sites::kMinBlockChoice.va, reinterpret_cast<const void*>(&UhcMinBlockChoice), 11)) {
    return Outcome::kFailed;
  }
  int refs = 0;
  for (const ItemInfo& item : kItems) {
    refs += AddDataRef(item.ref, kDataRefString, item.provider) ? 1 : 0;
  }
  Log(L"minUIStats: %u rows and %ls from %ls; %ls; %d data refs {uhc...} (UI only); rows give way to the stack "
      L"portraits and %u avoid gadgets; %u stock labels; attack rows: %ls, %ls, %ls, ability attacks %ls",
      static_cast<unsigned>(g_rows.size()), g_big.on ? L"the normal interface's stat rows" : L"no stat rows",
      g_file.c_str(), buildingArmor ? L"building armor shown in the minimized panel's resists" : L"no building armor",
      refs, static_cast<unsigned>(g_avoid.size()), static_cast<unsigned>(g_labels.size()),
      g_big.takeStock ? L"the original ones written by the key" : L"the original ones kept",
      g_big.rofIcon.empty() ? L"no ROF" : L"ROF after the damage",
      g_big.projectilesIcon.empty() ? L"no projectiles"
      : shotTags                    ? L"projectiles per reload after it"
                                    : L"no projectiles (tags not read)",
      g_filterAbilities && g_abilityReads ? L"only when enabled" : L"all");
  (void)&OnDatabase;
  return Outcome::kApplied;
}

}  // namespace uhc
