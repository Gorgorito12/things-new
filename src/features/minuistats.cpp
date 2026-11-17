// minUIStats: the minimized in-game interface shows what the normal one shows, and more, in rows a data file lists.
//
//   minUIStats [file]      (default minuirows.xml in the build's data folder; without it, the rows below)
//
// The minimized selection panel (uiunitselectionmin.xml) gets top-level formatText gadgets the DLL fills:
// - <row gadget="..." item="speed" label="Speed: " types="Unit"/>: one catalog item (kItems) per gadget;
// - <bigPanelRows gadget="unitselectionpanel-uhcRow%d" first="3" skip="auto,speed"/>: the rows the normal
//   interface's stat panel shows (FUN_004D70ED), mirrored: the fill runs for these gadgets and its rows are kept
//   in order, less the ones the minimized panel already shows ("auto") and the kinds `skip` names.
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

bool ItemHitpoints(const char* unit, std::wstring* out) {
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

// The armor as the stock resists value: "0.20" and the icon of its damage type ([proto+1D3h]: 0 hand, 1 ranged,
// 2 siege, icons [[game+920h]+1CCh/1D0h/1D4h]).
bool ArmorText(const char* unit, bool icon, std::wstring* out) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const float armor = Field<float>(proto, 0xC4);
  if (!(armor > 0.0f)) {
    return false;
  }
  *out = Number(armor);
  const std::uint8_t type = Field<std::uint8_t>(proto, 0x1D3);
  const char* view = Field<const char*>(Game(), 0x920);
  if (icon && view != nullptr && type <= 2) {
    wchar_t tag[64];
    swprintf_s(tag, L" <icon=\"(16)(TextureID(%d))\">", Field<std::int32_t>(view, 0x1CC + 4u * type));
    *out += tag;
  }
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

bool ItemTrainPoints(const char* unit, std::wstring* out) { return ProtoPoints(unit, 0x6C, out); }
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

// The unit's attacks, as the stat panel lists them (0x4D7892..0x4D79A1): its current tactic
// [[[proto+44h]+10h] + [[unit+58h]+0A8h]*4] fills the list through 0x487EEE, each entry's +4 an index into the
// proto's actions [[proto+44h]+1Ch]; only actions with damage ([action+24h]) are kept.
// withoutDamage: also the listed actions with no damage record, as the stat panel fill writes a row for each.
std::vector<const char*> Attacks(const char* unit, bool withoutDamage = false) {
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
    if (action != nullptr && (withoutDamage || Field<const char*>(action, 0x24) != nullptr)) {
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
  swprintf_s(tag, L" <icon=\"(16)(TextureID(%d))\">", Field<std::int32_t>(view, 0x1CC + 4u * type));
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
bool AttackRow(const char* unit, const char* action, std::wstring* label, std::wstring* value) {
  const char* database = Database();
  const char* view = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x920);
  if (database == nullptr || view == nullptr) {
    return false;
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
  *label = name + L":";
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
  swprintf_s(text, L"%d <icon=\"(16)(TextureID(%d))\">", static_cast<int>(typed * scale * base),
             type <= 2 ? Field<std::int32_t>(view, 0x1CC + 4u * type) : 0);
  *value = text;
  if (ActionFlag(action, 0x0A)) {
    const char* ranges = Field<const char*>(action, 0x18);
    const std::int32_t count = Field<std::int32_t>(action, 0x1C);
    for (std::int32_t i = 0; ranges != nullptr && i < count; ++i) {
      if (Field<std::int32_t>(ranges, 16u * i) == -1) {
        swprintf_s(text, L" %d <icon=\"(16)(TextureID(%d))\">", static_cast<int>(Field<float>(ranges, 16u * i + 8)),
                   Field<std::int32_t>(view, 0x218));
        *value += text;
        break;
      }
    }
  }
  return true;
}

// The player's proto cost list [proto+70h] (with its techs; read through 0x44EFFF, which unmasks it).
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
      swprintf_s(text, L"%ls%d <icon=\"(16)(%hs)\">", out->empty() ? L"" : L"  ", static_cast<int>(cost + 0.5f),
                 kResourceIcon(database, r));
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
};

// A text= row: each '|'-separated segment with its {item}s replaced; a segment with an item that has nothing for
// the unit is left out, the rest are joined by three spaces. False when no segment is left.
bool RenderTemplate(const std::wstring& text, const char* unit, std::wstring* out) {
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
        rendered += segment.substr(pos);
        break;
      }
      rendered += segment.substr(pos, open - pos);
      const std::wstring name = segment.substr(open + 1, close - open - 1);
      std::string narrow(name.begin(), name.end());
      const ItemInfo* item = FindItem(narrow);
      std::wstring value;
      ok = item != nullptr && item->fn(unit, &value);
      rendered += value;
      pos = close + 1;
    }
    if (ok && !rendered.empty()) {
      *out += (out->empty() ? L"" : L"   ") + rendered;
    }
    start = bar + 1;
  }
  return !out->empty();
}

// Kinds of mirrored stat rows.
enum Kind : std::uint32_t {
  kName = 1u << 0, kHitpoints = 1u << 1, kGroupHealth = 1u << 2, kResource = 1u << 3, kGatherers = 1u << 4,
  kRate = 1u << 5, kSpeed = 1u << 6, kResists = 1u << 7, kAttack = 1u << 8, kShownAttack = 1u << 9,
  kSpecial = 1u << 10, kOther = 1u << 11, kAuto = 1u << 31,
};

struct BigPanel {
  bool on = false;
  std::wstring pattern;  // with one %d
  int first = 0;
  int count = 16;
  std::uint32_t skip = kAuto;
  bool keep = false;  // overlap="show"
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
    "<row gadget='unitselectionpanel-uhcTrainPoints' item='trainPoints' label='Train Points: ' types='Unit'/>"
    "<row gadget='unitselectionpanel-uhcRow0' text='LOS: {los}|Speed: {speed}|Garrison: {garrison}'/>"
    "<row gadget='unitselectionpanel-uhcRow1' text='ROF: {rof}|Range: {range}'/>"
    "<row gadget='unitselectionpanel-uhcCostPop' text='Cost: {cost}|Pop: {population}'/>"
    "<row gadget='unitselectionpanel-uhcRow2' text='Done in {buildTime}|Builds {buildRate}/s|Regen {regen}/s|"
    "Overheal {overheal}|Poison {poison}|Aura {auras}'/>"
    "<bigPanelRows gadget='unitselectionpanel-uhcRow%d' first='3' skip='auto,speed'/>"
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
  return label == nullptr ? std::wstring() : Wide(*label);
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
        g_rows.push_back({Wide(Trim(*gadget)), nullptr, L"", wide, typeList(element), keepOnOverlap(element)});
      } else {
        g_rows.push_back({Wide(Trim(*gadget)), info, Label(element), L"", typeList(element), keepOnOverlap(element)});
      }
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

struct PanelGadgets {
  char* panel = nullptr;
  std::int32_t typeNameHandle = 0;
  std::vector<Gadget> rows;  // g_rows order
  std::vector<Gadget> big;   // the bigPanelRows block, consecutive gadgets
  std::vector<std::int32_t> avoid;  // the <avoid> gadgets this layout has
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

// ---- The stack portraits and the <avoid> gadgets: where a row must not be drawn ----

// A gadget's rectangle in screen pixels: its top left point at +28h ({x, y} as fractions of the screen, then
// {x, y} in pixels at +30h / +34h) and its bottom right one at +38h (+40h / +44h), as 0x44B9D8 and the stack
// layout 0x4C8F49 read them. Every gadget of the screen uses the same space, whatever its parent.
struct Box {
  std::int32_t left = 0, top = 0, right = 0, bottom = 0;
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
  return out->right > out->left && out->bottom > out->top;
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
  const std::vector<const char*> actions = Attacks(unit, true);
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

// About how many characters of the stat font fit one line of the gadget: a character is about 0.24 times the
// gadget's height wide (measured in game at 1920 x 1080: a 16-unit high uhcRow5, 23 px, holds 38 characters and
// two icons in 210 of its 225 px).
size_t LineBudget(const Gadget& gadget) {
  Box box;
  if (!GadgetBox(gadget.handle, &box) || box.bottom <= box.top) {
    return 30;
  }
  return static_cast<size_t>(static_cast<float>(box.right - box.left) / (0.24f * static_cast<float>(box.bottom - box.top)));
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

void FillBigRows(const char* selection, const char* unit, bool minimizedBlock, const Blockers& blockers,
                 std::wstring* blockedNames) {
  if (!MirrorStatRows(selection)) {
    for (Gadget& gadget : g_panel.big) {
      Hide(&gadget);
    }
    return;
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
  if (skip & kAuto) {
    // What the minimized block shows itself (0x6987D7..0x69A60F): the owner, hit points, resists, the resource held,
    // the AutoGather rate, the special attacks inline, and the first three rows of attacks less the resource row.
    skip |= minimizedBlock ? (kName | kHitpoints | kResists | kResource | kRate | kShownAttack | kSpecial) : kName;
  }
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
    if (!(skip & kind)) {
      rows.push_back(&g_stat[i]);
    }
  }
  // A gadget under a stack portrait or a shown <avoid> gadget is left empty, and the rows go on in the next one.
  std::vector<size_t> free;
  for (size_t k = 0; k < g_panel.big.size(); ++k) {
    if (!g_big.keep && Blocked(g_panel.big[k], blockers)) {
      Hide(&g_panel.big[k]);
      wchar_t name[160];
      swprintf_s(name, g_big.pattern.c_str(), g_big.first + static_cast<int>(k));
      *blockedNames += L" " + std::wstring(name);
    } else {
      free.push_back(k);
    }
  }
  for (size_t n = 0; n < free.size(); ++n) {
    Gadget* gadget = &g_panel.big[free[n]];
    if (n >= rows.size()) {
      Hide(gadget);
      continue;
    }
    const StatRow& row = *rows[n];
    const std::uint32_t style = row.labelStyle == kAttackStyle ? kAttackStyle : kLabelStyle;
    if (n + 1 == free.size() && rows.size() > free.size()) {
      // One line: as many short rows as fit the gadget (a formatText wraps a longer text and centres it, which
      // would show a middle line), then "+N"; the help text lists them all.
      const size_t budget = LineBudget(*gadget);
      std::wstring text;
      std::wstring tip;
      size_t shown = 0;
      for (size_t r = n; r < rows.size(); ++r) {
        const std::wstring part = Compact(*rows[r]);
        const size_t left = rows.size() - r - 1;
        const std::wstring more = left == 0 ? L"" : L" +" + std::to_wstring(left);
        if (shown == 0 || VisibleLength(text + L"   " + part + more) <= budget) {
          text += (text.empty() ? L"" : L"   ") + part;
          ++shown;
        } else {
          text += L" +" + std::to_wstring(rows.size() - r);
          break;
        }
      }
      for (size_t r = n; r < rows.size(); ++r) {
        tip += (tip.empty() ? L"" : L"\n") + StripMarkup(rows[r]->label + L" " + rows[r]->value);
      }
      SetText(gadget, text, style, tip);
      continue;
    }
    std::wstring text = row.label;
    if (!row.value.empty()) {
      text += L"  " + row.value;
    }
    SetText(gadget, text, style, row.tip);
  }
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
  return label;
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
                                                : RenderTemplate(g_rows[i].text, unit, &value));
    if (!has) {
      Hide(&gadget);
      continue;
    }
    SetText(&gadget, ResolveLabel(g_rows[i].label) + value, 0, L"");
  }
  if (!g_panel.big.empty()) {
    if (proto == nullptr || selection == nullptr || count <= 0) {
      for (Gadget& gadget : g_panel.big) {
        Hide(&gadget);
      }
    } else {
      FillBigRows(selection, unit, minimizedBlock, blockers, &blockedNames);
    }
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
  for (TypeFilter* filter : g_filters) {
    if (!RequestAbstractUnitType(filter->name.c_str(), &filter->id)) {
      return Outcome::kFailed;
    }
  }
  static const std::uint8_t kNops[6] = {0x90, 0x90, 0x90, 0x90, 0x90, 0x90};
  if (!WriteJmp(sites::kStatFillMinGate.va + 0x41, reinterpret_cast<const void*>(&UhcStatFillMinGate), 11) ||
      !WriteBytes(sites::kMinResistsUnitGate.va + 0x14, kNops, sizeof(kNops)) || !AddUnitPanelTail(&MinUiTail) ||
      // After the tail hook, which verifies these bytes too: the minimized block also runs for a minimized layout
      // loaded without the profile option.
      !WriteJmp(sites::kMinBlockChoice.va, reinterpret_cast<const void*>(&UhcMinBlockChoice), 11)) {
    return Outcome::kFailed;
  }
  int refs = 0;
  for (const ItemInfo& item : kItems) {
    refs += AddDataRef(item.ref, kDataRefString, item.provider) ? 1 : 0;
  }
  Log(L"minUIStats: %u rows and %ls from %ls; building armor shown in the minimized panel's resists; %d data refs "
      L"{uhc...} (UI only); rows give way to the stack portraits and %u avoid gadgets",
      static_cast<unsigned>(g_rows.size()), g_big.on ? L"the normal interface's stat rows" : L"no stat rows",
      g_file.c_str(), refs, static_cast<unsigned>(g_avoid.size()));
  (void)&OnDatabase;
  return Outcome::kApplied;
}

}  // namespace uhc
