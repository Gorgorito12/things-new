// veterancyBonus: a unit grows stronger with its kills.
//
//   <VeterancyBonus kills="1" modifytype="Damage">1.15</VeterancyBonus>          repeatable, in a proto
//   <VeterancyBonus kills="3" modifytype="Damage" op="add">2</VeterancyBonus>    adds instead (op="mul" is the default)
//
// Each row says: from that many kills on, this stat is multiplied by this much (or has this much added), in all
// (1.15 then 1.30 is ×1.30 at the second row, not 1.15 × 1.30; +2 then +3 is +3). modifytype takes every
// <ModifyType> name. Multiply and add rows of one stat are two separate series.
//
// The data file veterancy.xml (the build's data folder, hostfiles.h) holds what is not per proto:
//   <Veterancy>
//     <VeterancyDefault unittype="AbstractInfantry"> <VeterancyBonus .../> ... </VeterancyDefault>
//     <VeterancyRank rank="1" name="Veteran" color="CD7F32"/>
//   </Veterancy>
// A default's rows go to every proto of that unit type with no rows of its own (the first default in the file
// whose type the player's proto has); a proto's own rows replace the defaults entirely. A rank's name (a text,
// or a string ID) and colour (RRGGBB) are shown by the floating text and the unit panel's row; "Rank N" otherwise.
//
// Stock's flag ExperienceUnit has no reader in the exe, so nothing counts a unit's kills. The key observes
// TakeDamage's kill path (killobservers.h, shared with killSpawn), where the attacker unit is known. The count and the bonuses are all stat
// modifiers of the game (0x4DD22D, the call of snares and auras, with no time limit), so that the game
// saves them, the stat code reads them and a transformed unit keeps them:
// - the count is a modifier of a stat no code reads, kStatKills, whose value is the kills;
// - each row reached adds a multiply modifier (operation 2) for what its total adds to the row before it, or an
//   add modifier (operation 1) for the difference. The stat sum 0x4B3C7D applies a unit's modifiers of a stat
//   oldest first: set, add or multiply. Speed starts from the proto's velocity and MaxHP from its hit points, so
//   an add is in their units; every other stock stat starts from 1.0, so an add of 0.25 is +25% of the base.
// A transform in place (0x9C754C: TransformUnit, revolutions) ends the unit's modifiers, so its seven
// calls go through a wrapper that puts the count back, and the bonuses of the kills reached that the
// new proto's rows give. The rows are read once, by proto ID, and are the same for every player. The hook is in
// hooks/killobservers_hooks.asm.
//
// Two tech effects of type="Data" act on one player's copy of the proto: subtype="VeterancyEnable" (0 turns the
// rows off for that player, anything else on; base 1) and subtype="VeterancyBonus" (a factor on what every row
// adds: a row of 1.30 with factor 2 gives 1.60; base 1). Ranks already granted are game modifiers and stay.
//
// A unit with a rank carries a mark, tools/rings' rank_1 to rank_5, and the unit panel's row says its rank. Both only
// show: the mark is a visual of the unit. A kill and a transform name a unit for the world tick, which hangs the
// mark; the tick looks only at units with a mark; one walk over the world's units finds the ranks of a loaded game.
#include <windows.h>

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../floatingtext.h"
#include "../generated/sites.h"
#include "../killobservers.h"
#include "../log.h"
#include "../modifiers.h"
#include "../patch.h"
#include "../prototags.h"
#include "../techsubtypes.h"
#include "../transformcalls.h"
#include "../unitmodels.h"
#include "../unitpanel.h"
#include "../unittypes.h"
#include "../worldtick.h"
#include "../xmllist.h"

namespace {

constexpr std::int32_t kStatKills = 0x62;       // no stock stat or key uses it; transformSpan has 60h and 61h
constexpr std::int32_t kOperationSet = 0;
constexpr std::int32_t kOperationAdd = 1;
constexpr std::int32_t kOperationMultiply = 2;
constexpr std::uint32_t kRankColour = 0xFFFFD700;
constexpr int kMaxLogLines = 200;
constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kMarkTickMs = 250;
constexpr std::uint32_t kTimeJumpMs = 2000;  // more than a world update: a game was loaded
constexpr std::int32_t kMarkRanks = 5;       // tools/rings has this many; a higher rank keeps the last

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
using ModifyTypeFn = std::int32_t(__cdecl*)(const void* name);
using ModifierFn = std::int32_t(__thiscall*)(char* unit, std::int32_t stat, float value, float a, float b,
                                             std::int32_t c, std::int32_t operation, std::int32_t ms, std::int32_t d,
                                             std::int32_t e, std::int32_t exclusive);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
const auto kModifyType = reinterpret_cast<ModifyTypeFn>(0x005F5645);
const auto kModifier = reinterpret_cast<ModifierFn>(0x004DD22D);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
using UnitByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
using UnitTestFn = bool(__thiscall*)(const char* unit);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);

// The engine's string: one pointer to a wide, reference-counted buffer.
struct BString {
  wchar_t* text;
};
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t stringId);
using BStringFreeFn = void(__thiscall*)(BString* self);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);

struct Row {
  std::int32_t kills;
  std::int32_t stat;
  float total;
  bool add;  // op="add": total is what is added in all; else a multiplier in all
};

std::unordered_map<std::int32_t, std::vector<Row>> g_rows;  // by proto ID; the load fills it

// A row of veterancy.xml, before its modifytype is resolved at the first use in a game.
struct DefaultRow {
  std::int32_t kills;
  std::wstring stat;
  float total;
  bool add;
};
struct Default {
  std::string type;
  std::vector<DefaultRow> source;
  std::int32_t typeId = -1;
  std::vector<Row> rows;  // resolved, sorted by kills
};
std::vector<Default> g_defaults;  // in file order
bool g_resolved = false;          // the defaults' names are resolved against this database load

struct RankStyle {
  std::wstring name;            // empty: "Rank N"
  std::int32_t stringId = -1;   // a name made of digits is a string ID
  std::uint32_t colour = kRankColour;
};
std::map<std::int32_t, RankStyle> g_styles;  // by rank
std::wstring g_file;                         // veterancy.xml, for the log

struct TechOverride {
  std::int32_t id = -1;  // the proto ID the copy had: a reused pointer with another ID is ignored
  float enabled = 1.0f;
  float factor = 1.0f;
};
std::unordered_map<const char*, TechOverride> g_tech;  // by the player's copy of the proto
bool g_log = false;
int g_logLines = 0;

bool g_marks = false;                     // the sites of the marks are stock
std::int32_t g_rankModels[kMarkRanks + 1];  // by rank; -2: not looked up yet
std::int32_t g_noBone = -2;
std::map<std::int32_t, std::int32_t> g_marked;  // by unit ID: the rank it shows
std::vector<std::int32_t> g_pending;            // unit IDs whose mark may have changed
bool g_noArt = false;
bool g_scan = true;
const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_nextMark = 0;

const TechOverride* TechFor(const char* copy) {
  if (g_tech.empty()) {
    return nullptr;
  }
  const auto found = g_tech.find(copy);
  return found != g_tech.end() && found->second.id == *reinterpret_cast<const std::int32_t*>(copy + 8)
             ? &found->second
             : nullptr;
}

// The rows apply to this copy, and a row's total as the tech leaves it.
bool EnabledFor(const char* copy) {
  const TechOverride* tech = TechFor(copy);
  return tech == nullptr || tech->enabled != 0.0f;
}

float TotalFor(const char* copy, float total, bool add) {
  const TechOverride* tech = TechFor(copy);
  if (tech == nullptr || tech->factor == 1.0f) {
    return total;
  }
  if (add) {
    return total * tech->factor;
  }
  const float scaled = 1.0f + (total - 1.0f) * tech->factor;
  return scaled > 0.0f ? scaled : 0.0f;
}

TechOverride& TechSlot(char* proto) {
  TechOverride& slot = g_tech[proto];
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 8);
  if (slot.id != id) {
    slot = TechOverride{};
    slot.id = id;
  }
  return slot;
}

void ChangeTech(char* proto, float* field, float amount, std::uint8_t relativity, bool unapply, const wchar_t* name) {
  const float before = *field;
  kEffectValue(relativity, field, 1.0f, amount, unapply);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"veterancyBonus: proto %d, tech subtype %ls, relativity %u, amount %g%ls: %g -> %g",
             *reinterpret_cast<const std::int32_t*>(proto + 8), name, relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", static_cast<double>(before), static_cast<double>(*field));
  }
}

void ChangeEnable(char* proto, const char*, float amount, std::uint8_t relativity, bool unapply) {
  ChangeTech(proto, &TechSlot(proto).enabled, amount, relativity, unapply, L"VeterancyEnable");
}

void ChangeFactor(char* proto, const char*, float amount, std::uint8_t relativity, bool unapply) {
  ChangeTech(proto, &TechSlot(proto).factor, amount, relativity, unapply, L"VeterancyBonus");
}

void ForgetOnDataLoad(char*) {
  g_resolved = false;
  g_tech.clear();
  g_marked.clear();
  g_pending.clear();
  std::fill(std::begin(g_rankModels), std::end(g_rankModels), -2);
  g_noBone = -2;
  g_noArt = false;
  g_scan = true;
}

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// op: absent or "mul" multiplies, "add" adds; false for anything else.
bool ParseOp(const char* op, bool* add) {
  *add = op != nullptr && _stricmp(op, "add") == 0;
  return op == nullptr || *add || _stricmp(op, "mul") == 0;
}

// A multiplier must be positive; an amount added, not zero.
bool ValidRow(std::int32_t kills, std::int32_t stat, float total, bool add) {
  return kills >= 1 && stat >= 0 && (add ? total != 0.0f : total > 0.0f);
}

void SortRows(std::vector<Row>& rows) {
  std::stable_sort(rows.begin(), rows.end(), [](const Row& a, const Row& b) { return a.kills < b.kills; });
}

const char* Database() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

// The defaults' unit types and modifytypes, by name, once per database load: the protos and every <ModifyType>
// name (the keys' too) are known by the time a unit asks.
void ResolveDefaults() {
  const char* database = Database();
  if (g_resolved || database == nullptr) {
    return;
  }
  g_resolved = true;
  const char* table = database + 0x190;
  for (Default& entry : g_defaults) {
    entry.typeId = -1;
    entry.rows.clear();
    std::int32_t id = -1;
    if (!kNameFind(table, entry.type.c_str(), kNameBucket(table, entry.type.c_str()), &id)) {
      uhc::Log(L"veterancyBonus: %ls: unknown unit type %hs; its default rows are ignored", g_file.c_str(),
               entry.type.c_str());
      continue;
    }
    entry.typeId = id;
    for (const DefaultRow& row : entry.source) {
      BString name{nullptr};
      kBStringFromWide(&name, row.stat.c_str());
      const std::int32_t stat = kModifyType(&name);
      kBStringFree(&name);
      if (!ValidRow(row.kills, stat, row.total, row.add)) {
        uhc::Log(L"veterancyBonus: %ls: %hs: a row with kills %d, modifytype %ls, value %g is not valid; ignored",
                 g_file.c_str(), entry.type.c_str(), row.kills, row.stat.c_str(), static_cast<double>(row.total));
        continue;
      }
      entry.rows.push_back({row.kills, stat, row.total, row.add});
    }
    SortRows(entry.rows);
    if (g_log) {
      uhc::Log(L"veterancyBonus: %u default rows for unit type %hs (%d)", static_cast<unsigned>(entry.rows.size()),
               entry.type.c_str(), entry.typeId);
    }
  }
}

// The rows of a player's copy of a proto: its own, else the first default whose unit type it has; null if none.
const std::vector<Row>* RowsFor(const char* proto) {
  if (proto == nullptr) {
    return nullptr;
  }
  const auto found = g_rows.find(Field<std::int32_t>(proto, 8));
  if (found != g_rows.end()) {
    return &found->second;
  }
  if (g_defaults.empty()) {
    return nullptr;
  }
  ResolveDefaults();
  for (const Default& entry : g_defaults) {
    if (entry.typeId >= 0 && !entry.rows.empty() && kProtoIsType(proto, entry.typeId)) {
      return &entry.rows;
    }
  }
  return nullptr;
}

bool AnyRows() { return !g_rows.empty() || !g_defaults.empty(); }

std::wstring RankName(std::int32_t rank) {
  const auto found = g_styles.find(rank);
  if (found != g_styles.end()) {
    if (found->second.stringId >= 0) {
      BString text{nullptr};
      kBStringFromId(&text, found->second.stringId);
      std::wstring copy = text.text != nullptr ? text.text : L"";
      kBStringFree(&text);
      if (!copy.empty()) {
        return copy;
      }
    } else if (!found->second.name.empty()) {
      return found->second.name;
    }
  }
  wchar_t text[32];
  swprintf_s(text, L"Rank %d", rank);
  return text;
}

std::uint32_t RankColour(std::int32_t rank) {
  const auto found = g_styles.find(rank);
  return found != g_styles.end() ? found->second.colour : kRankColour;
}

bool __cdecl ReadVeterancyBonus(void*, const char* node, char* proto) {
  const std::int32_t id = Field<std::int32_t>(proto, 8);
  const void* killsText = nullptr;
  const void* typeText = nullptr;
  const char* amount = kXmlText(node + 0x14);
  if (!kXmlAttribute(node, "kills", &killsText) || killsText == nullptr ||
      !kXmlAttribute(node, "modifytype", &typeText) || typeText == nullptr || amount == nullptr) {
    uhc::Log(L"veterancyBonus: proto %d: a row needs kills, modifytype and a value; ignored", id);
    return true;
  }
  const char* digits = kXmlText(killsText);
  const std::int32_t kills = digits != nullptr ? std::atoi(digits) : 0;
  const std::int32_t stat = kModifyType(typeText);
  const float total = static_cast<float>(std::atof(amount));
  const void* opText = nullptr;
  const char* op = kXmlAttribute(node, "op", &opText) && opText != nullptr ? kXmlText(opText) : nullptr;
  bool add = false;
  if (!ParseOp(op, &add)) {
    uhc::Log(L"veterancyBonus: proto %d: op=\"%hs\" is neither mul nor add; the row is ignored", id, op);
    return true;
  }
  if (!ValidRow(kills, stat, total, add)) {
    uhc::Log(L"veterancyBonus: proto %d: a row with kills %d, stat %d, value %hs is not valid; ignored", id, kills, stat,
             amount);
    return true;
  }
  std::vector<Row>& rows = g_rows[id];
  rows.push_back({kills, stat, total, add});
  SortRows(rows);
  if (g_log) {
    uhc::Log(L"veterancyBonus: proto %d: from %d kills, stat %d %ls%g", id, kills, stat, add ? L"+" : L"x",
             static_cast<double>(total));
  }
  return true;
}

// The modifier that holds the count, or null.
char* FindCount(const char* unit) {
  const char* list = uhc::modifiers::ModifierList(unit);
  if (list == nullptr) {
    return nullptr;
  }
  char* found = nullptr;
  auto visit = [&found](const char* action) {
    if (Field<std::int32_t>(action, 0x64) != kStatKills) {
      return true;
    }
    found = const_cast<char*>(action);
    return false;
  };
  uhc::modifiers::WalkModifiers(list, visit, 0);
  return found;
}

float KillsOf(const char* unit) {
  const char* count = FindCount(unit);
  return count != nullptr ? Field<float>(count, 0x68) : 0.0f;
}

// Each distinct kills value is a rank.
std::int32_t RankOf(const std::vector<Row>& rows, float kills) {
  std::int32_t rank = 0;
  std::int32_t last = 0;
  for (const Row& row : rows) {
    if (static_cast<float>(row.kills) > kills) {
      break;
    }
    if (row.kills != last) {
      ++rank;
      last = row.kills;
    }
  }
  return rank;
}

std::int32_t RankOfUnit(const char* unit) {
  const std::vector<Row>* rows = RowsFor(Field<const char*>(unit, 0x5C));
  return rows == nullptr ? 0 : RankOf(*rows, KillsOf(unit));
}

std::int32_t RankModel(std::int32_t rank) {
  std::int32_t& model = g_rankModels[rank];
  if (model == -2) {
    wchar_t path[64];
    swprintf_s(path, L"effects\\uhc_rings\\rank_%d.xml", rank);
    model = uhc::ModelOfPath(path);
  }
  return model;
}

// False: try again at the next tick.
bool UpdateMark(const char* world, std::int32_t id) {
  char* unit = kUnitById(world, id);
  if (unit == nullptr) {
    return true;
  }
  const std::int32_t rank = (std::min)(RankOfUnit(unit), kMarkRanks);
  const auto marked = g_marked.find(id);
  const std::int32_t shown = marked != g_marked.end() ? marked->second : 0;
  if (shown != 0 && shown != rank) {
    uhc::RemoveUnitModel(unit, RankModel(shown));
    g_marked.erase(id);
  }
  if (rank == 0) {
    return true;
  }
  if (g_noBone == -2) {
    g_noBone = uhc::NoBone();
  }
  const std::int32_t model = RankModel(rank);
  if (model == -1) {
    return false;
  }
  const uhc::ModelHang hang = uhc::HangUnitModel(unit, model, g_noBone);
  if (hang == uhc::ModelHang::kRetry) {
    return false;
  }
  if (hang == uhc::ModelHang::kNotInGame) {
    g_noArt = true;
    uhc::RemoveUnitModel(unit, model);
    uhc::Log(L"veterancyBonus: effects\\uhc_rings\\rank_%d.xml is not in the game: no rank marks", rank);
    return true;
  }
  g_marked[id] = rank;
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"veterancyBonus: unit %d shows rank %d", id, rank);
  }
  return true;
}

void ScanWorld(const char* world) {
  const auto* table = Field<char* const*>(world, 0x0C);
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
    const char* unit = table[i];
    const char* proto = unit != nullptr ? Field<const char*>(unit, 0x5C) : nullptr;
    if (proto != nullptr && RowsFor(proto) != nullptr && FindCount(unit) != nullptr) {
      g_pending.push_back(Field<std::int32_t>(unit, 0x10));
    }
  }
}

void Tick(char* world, std::int32_t) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  if (game == nullptr || world != Field<const char*>(game, 0x13C) || !AnyRows() || g_noArt) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_world || now < g_lastTime || now > g_lastTime + kTimeJumpMs) {
    g_marked.clear();  // another game: its unit IDs are not these
    g_pending.clear();
    g_world = world;
    g_nextMark = 0;
    g_scan = true;
  }
  g_lastTime = now;
  if (now < g_nextMark) {
    return;
  }
  g_nextMark = now + kMarkTickMs;
  if (g_scan) {
    g_scan = false;
    ScanWorld(world);
  }
  for (auto it = g_marked.begin(); it != g_marked.end();) {
    char* unit = kUnitById(world, it->first);
    if (unit != nullptr && (*reinterpret_cast<UnitTestFn const* const*>(unit))[0xA4 / 4](unit)) {
      ++it;
      continue;
    }
    if (unit != nullptr) {
      uhc::RemoveUnitModel(unit, RankModel(it->second));  // the corpse does not keep it
    }
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"veterancyBonus: unit %d is gone, and its mark", it->first);
    }
    it = g_marked.erase(it);
  }
  std::vector<std::int32_t> waiting;
  waiting.swap(g_pending);
  for (const std::int32_t id : waiting) {
    if (!UpdateMark(world, id)) {
      g_pending.push_back(id);
    }
  }
}

// The modifier of one row: what its total adds to the row before it of the same stat and operation, so the
// total from that rank on is the row's. Returns the value given.
float ApplyRow(char* unit, const char* proto, const std::vector<Row>& rows, const Row& row) {
  float before = row.add ? 0.0f : 1.0f;
  for (const Row& earlier : rows) {
    if (earlier.kills < row.kills && earlier.stat == row.stat && earlier.add == row.add) {
      before = earlier.total;
    }
  }
  if (row.add) {
    const float amount = TotalFor(proto, row.total, true) - TotalFor(proto, before, true);
    if (amount != 0.0f) {
      kModifier(unit, row.stat, amount, -1.0f, -1.0f, 0, kOperationAdd, 0, -1, -1, 0);
    }
    return amount;
  }
  const float from = TotalFor(proto, before, false);
  if (from <= 0.0f) {
    return 1.0f;  // a factor took the row before to 0: nothing to scale
  }
  const float ratio = TotalFor(proto, row.total, false) / from;
  kModifier(unit, row.stat, ratio, -1.0f, -1.0f, 0, kOperationMultiply, 0, -1, -1, 0);
  return ratio;
}

// Around the transform in place, which ends the unit's modifiers.
float KillsBeforeTransform(const char* unit) {
  const char* count = AnyRows() ? FindCount(unit) : nullptr;
  return count != nullptr ? Field<float>(count, 0x68) : 0.0f;
}

void RestoreAfterTransform(char* unit, float kills) {
  if (kills < 1.0f || FindCount(unit) != nullptr) {
    return;
  }
  if (g_marks) {
    g_pending.push_back(Field<std::int32_t>(unit, 0x10));
  }
  kModifier(unit, kStatKills, kills, -1.0f, -1.0f, 0, kOperationSet, 0, -1, -1, 0);
  const char* now = Field<const char*>(unit, 0x5C);
  const std::vector<Row>* rows = RowsFor(now);
  if (rows == nullptr) {
    return;
  }
  // The same modifiers, in the same order, as the kills made them: the stat sum applies them one after the
  // other (0x4B3C7D), so a multiply and an add of one stat give another result in another order.
  for (const Row& row : *rows) {
    if (static_cast<float>(row.kills) > kills) {
      break;
    }
    ApplyRow(unit, now, *rows, row);
  }
  if (g_log) {
    uhc::Log(L"veterancyBonus: unit %d keeps %g kills as proto %d", Field<std::int32_t>(unit, 0x10),
             static_cast<double>(kills), Field<std::int32_t>(now, 8));
  }
}

// veterancy.xml: a small reader of elements with attributes, comments and the declaration skipped.
struct XmlElement {
  std::string tag;                               // lowercase
  std::map<std::string, std::string> attributes;  // names in lowercase
  std::string text;                              // the element's own text, untrimmed
  int parent = -1;
};

std::string Lower(std::string text) {
  for (char& c : text) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  return text;
}

std::string Trim(const std::string& text) {
  const size_t begin = text.find_first_not_of(" \t\r\n");
  return begin == std::string::npos ? std::string() : text.substr(begin, text.find_last_not_of(" \t\r\n") - begin + 1);
}

std::string Decode(const std::string& text) {
  static const std::pair<const char*, char> kEntities[] = {
      {"&lt;", '<'}, {"&gt;", '>'}, {"&quot;", '"'}, {"&apos;", '\''}, {"&amp;", '&'}};
  std::string out;
  for (size_t i = 0; i < text.size();) {
    bool done = false;
    for (const auto& [entity, c] : kEntities) {
      const size_t length = std::char_traits<char>::length(entity);
      if (text.compare(i, length, entity) == 0) {
        out += c;
        i += length;
        done = true;
        break;
      }
    }
    if (!done) {
      out += text[i++];
    }
  }
  return out;
}

bool IsNameChar(char c) {
  return std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == '-' || c == ':' || c == '.';
}

// False if the file is not well formed.
bool ParseElements(const std::string& text, std::vector<XmlElement>* out) {
  std::vector<int> open;
  size_t pos = 0;
  while (pos < text.size()) {
    const size_t lt = text.find('<', pos);
    if (!open.empty()) {
      (*out)[open.back()].text += text.substr(pos, lt == std::string::npos ? std::string::npos : lt - pos);
    }
    if (lt == std::string::npos) {
      break;
    }
    if (text.compare(lt, 4, "<!--") == 0) {
      const size_t end = text.find("-->", lt + 4);
      if (end == std::string::npos) {
        return false;
      }
      pos = end + 3;
      continue;
    }
    // The end of the tag, past any '>' inside a quoted value.
    size_t gt = lt + 1;
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
    pos = gt + 1;
    if (text[lt + 1] == '?' || text[lt + 1] == '!') {
      continue;
    }
    if (text[lt + 1] == '/') {
      const std::string name = Lower(Trim(text.substr(lt + 2, gt - lt - 2)));
      if (open.empty() || (*out)[open.back()].tag != name) {
        return false;
      }
      open.pop_back();
      continue;
    }
    XmlElement element;
    size_t i = lt + 1;
    while (i < gt && IsNameChar(text[i])) {
      ++i;
    }
    element.tag = Lower(text.substr(lt + 1, i - lt - 1));
    if (element.tag.empty()) {
      return false;
    }
    const bool closed = text[gt - 1] == '/';
    const size_t end = closed ? gt - 1 : gt;
    while (i < end) {
      if (std::isspace(static_cast<unsigned char>(text[i]))) {
        ++i;
        continue;
      }
      const size_t nameStart = i;
      while (i < end && IsNameChar(text[i])) {
        ++i;
      }
      const std::string name = Lower(text.substr(nameStart, i - nameStart));
      while (i < end && std::isspace(static_cast<unsigned char>(text[i]))) {
        ++i;
      }
      if (name.empty() || i >= end || text[i] != '=') {
        return false;
      }
      ++i;
      while (i < end && std::isspace(static_cast<unsigned char>(text[i]))) {
        ++i;
      }
      if (i >= end || (text[i] != '"' && text[i] != '\'')) {
        return false;
      }
      const size_t close = text.find(text[i], i + 1);
      if (close == std::string::npos || close >= end) {
        return false;
      }
      element.attributes[name] = Decode(text.substr(i + 1, close - i - 1));
      i = close + 1;
    }
    element.parent = open.empty() ? -1 : open.back();
    out->push_back(std::move(element));
    if (!closed) {
      open.push_back(static_cast<int>(out->size()) - 1);
    }
  }
  return open.empty();
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

const std::string* Attribute(const XmlElement& element, const char* name) {
  const auto found = element.attributes.find(name);
  return found == element.attributes.end() ? nullptr : &found->second;
}

bool AllDigits(const std::string& text) {
  return !text.empty() && std::all_of(text.begin(), text.end(), [](char c) { return c >= '0' && c <= '9'; });
}

// The file as UTF-8, whether it was saved as UTF-8 (with or without a BOM) or UTF-16 LE.
std::string AsUtf8(const std::string& raw) {
  if (raw.size() >= 2 && static_cast<unsigned char>(raw[0]) == 0xFF && static_cast<unsigned char>(raw[1]) == 0xFE) {
    const wchar_t* wide = reinterpret_cast<const wchar_t*>(raw.data() + 2);
    const int count = static_cast<int>((raw.size() - 2) / 2);
    const int length = WideCharToMultiByte(CP_UTF8, 0, wide, count, nullptr, 0, nullptr, nullptr);
    std::string out(static_cast<size_t>(length), '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide, count, out.data(), length, nullptr, nullptr);
    return out;
  }
  return raw.compare(0, 3, "\xEF\xBB\xBF") == 0 ? raw.substr(3) : raw;
}

// Reads veterancy.xml. A missing file is no error unless the cfg names it; a malformed one is.
bool LoadDataFile(const std::string& arg) {
  std::wstring path;
  std::string raw;
  const bool read = uhc::ReadDataListFile(arg, L"veterancy.xml", &path, &raw);
  g_file = path;
  if (!read) {
    if (!arg.empty()) {
      uhc::Log(L"veterancyBonus: cannot read %ls (error %lu); feature not applied", path.c_str(), GetLastError());
      return false;
    }
    return true;
  }
  std::vector<XmlElement> elements;
  if (!ParseElements(AsUtf8(raw), &elements)) {
    uhc::Log(L"veterancyBonus: %ls is not well-formed XML; feature not applied", path.c_str());
    return false;
  }
  std::map<int, size_t> defaults;  // element index -> g_defaults index
  for (size_t index = 0; index < elements.size(); ++index) {
    const XmlElement& element = elements[index];
    if (element.tag == "veterancy") {
      continue;
    }
    if (element.tag == "veterancydefault") {
      const std::string* type = Attribute(element, "unittype");
      if (type == nullptr || Trim(*type).empty()) {
        uhc::Log(L"veterancyBonus: %ls: a VeterancyDefault without unittype is ignored", path.c_str());
        continue;
      }
      defaults[static_cast<int>(index)] = g_defaults.size();
      g_defaults.push_back({Trim(*type), {}, -1, {}});
      continue;
    }
    if (element.tag == "veterancybonus") {
      const auto owner = defaults.find(element.parent);
      if (owner == defaults.end()) {
        uhc::Log(L"veterancyBonus: %ls: a VeterancyBonus outside a VeterancyDefault is ignored", path.c_str());
        continue;
      }
      Default& entry = g_defaults[owner->second];
      const std::string* kills = Attribute(element, "kills");
      const std::string* stat = Attribute(element, "modifytype");
      const std::string* op = Attribute(element, "op");
      const std::string value = Trim(element.text);
      bool add = false;
      if (kills == nullptr || stat == nullptr || value.empty() || !ParseOp(op == nullptr ? nullptr : op->c_str(), &add)) {
        uhc::Log(L"veterancyBonus: %ls: %hs: a row needs kills, modifytype, a value and op mul or add; ignored",
                 path.c_str(), entry.type.c_str());
        continue;
      }
      entry.source.push_back({std::atoi(kills->c_str()), Wide(Trim(*stat)), static_cast<float>(std::atof(value.c_str())), add});
      continue;
    }
    if (element.tag == "veterancyrank") {
      const std::string* rankText = Attribute(element, "rank");
      const std::int32_t rank = rankText != nullptr ? std::atoi(rankText->c_str()) : 0;
      if (rank < 1) {
        uhc::Log(L"veterancyBonus: %ls: a VeterancyRank needs rank 1 or more; ignored", path.c_str());
        continue;
      }
      RankStyle style;
      if (const std::string* name = Attribute(element, "name")) {
        const std::string trimmed = Trim(*name);
        if (AllDigits(trimmed)) {
          style.stringId = std::atoi(trimmed.c_str());
        } else {
          style.name = Wide(trimmed);
        }
      }
      if (const std::string* colour = Attribute(element, "color")) {
        std::string hex = Trim(*colour);
        if (!hex.empty() && hex[0] == '#') {
          hex.erase(0, 1);
        }
        char* stop = nullptr;
        const unsigned long rgb = std::strtoul(hex.c_str(), &stop, 16);
        if (hex.size() != 6 || stop != hex.c_str() + 6) {
          uhc::Log(L"veterancyBonus: %ls: rank %d: color \"%hs\" is not RRGGBB; the default is kept", path.c_str(), rank,
                   colour->c_str());
        } else {
          style.colour = 0xFF000000u | static_cast<std::uint32_t>(rgb);
        }
      }
      g_styles[rank] = style;
      continue;
    }
    uhc::Log(L"veterancyBonus: %ls: unknown element <%hs>; ignored", path.c_str(), element.tag.c_str());
  }
  return true;
}

}  // namespace

// The shared kill observer (killobservers.h), for every killing blow.
static void VeterancyKill(char* attacker, char*, std::int32_t, char* victim) {
  if (attacker == nullptr || victim == nullptr) {
    return;
  }
  const char* proto = Field<const char*>(attacker, 0x5C);
  const std::vector<Row>* rows = RowsFor(proto);
  if (rows == nullptr || !EnabledFor(proto)) {
    return;
  }
  const char* attackerPlayer = Field<const char*>(attacker, 0x44);
  const char* victimPlayer = Field<const char*>(victim, 0x44);
  if (attackerPlayer == nullptr || victimPlayer == nullptr) {
    return;
  }
  const std::int32_t victimOwner = Field<std::int32_t>(victimPlayer, 0);
  if (victimOwner == 0 || victimOwner == Field<std::int32_t>(attackerPlayer, 0)) {
    return;  // Gaia, which is hunted game too, or a unit of its own
  }
  std::int32_t kills = 1;
  if (char* count = FindCount(attacker)) {
    kills = static_cast<std::int32_t>(Field<float>(count, 0x68)) + 1;
    *reinterpret_cast<float*>(count + 0x68) = static_cast<float>(kills);
  } else if (kModifier(attacker, kStatKills, 1.0f, -1.0f, -1.0f, 0, kOperationSet, 0, -1, -1, 0) == -1) {
    return;  // no action manager
  }
  std::int32_t rank = 0;
  std::int32_t last = 0;
  bool reached = false;
  float applied = 1.0f;  // the last multiplier or amount given, for the log
  bool appliedAdd = false;
  for (const Row& row : *rows) {
    if (row.kills > kills) {
      break;
    }
    if (row.kills != last) {
      ++rank;
      last = row.kills;
    }
    if (row.kills != kills) {
      continue;
    }
    reached = true;
    appliedAdd = row.add;
    applied = ApplyRow(attacker, proto, *rows, row);
  }
  if (reached) {
    const auto style = g_styles.find(rank);
    if (style != g_styles.end() && style->second.stringId >= 0) {
      uhc::ShowUnitText(attacker, nullptr, style->second.stringId, style->second.colour);
    } else {
      uhc::ShowUnitText(attacker, RankName(rank).c_str(), -1, RankColour(rank));
    }
    if (g_marks) {
      g_pending.push_back(Field<std::int32_t>(attacker, 0x10));
    }
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    if (reached) {
      uhc::Log(L"veterancyBonus: unit %d, proto %d: %d kills, a new rank, rank %d, %ls%g",
               Field<std::int32_t>(attacker, 0x10), Field<std::int32_t>(proto, 8), kills, rank, appliedAdd ? L"+" : L"x",
               static_cast<double>(applied));
    } else {
      uhc::Log(L"veterancyBonus: unit %d, proto %d: %d kills, rank %d", Field<std::int32_t>(attacker, 0x10),
               Field<std::int32_t>(proto, 8), kills, rank);
    }
  }
}

// The unit panel's row, for a unit with kills.
bool __stdcall UhcVeterancyRow(const char* panel, const char* unit) {
  const std::vector<Row>* rows = RowsFor(Field<const char*>(unit, 0x5C));
  if (rows == nullptr) {
    return false;
  }
  const float kills = KillsOf(unit);
  if (kills < 1.0f) {
    return false;
  }
  const std::int32_t rank = RankOf(*rows, kills);
  std::wstring label = RankName(rank);
  if (g_styles.count(rank) != 0) {
    // The panel's text reads the markup of the string table: <color=r, g, b>...</color>.
    const std::uint32_t colour = RankColour(rank);
    wchar_t open[64];
    swprintf_s(open, L"<color=%.2f, %.2f, %.2f>", ((colour >> 16) & 0xFF) / 255.0, ((colour >> 8) & 0xFF) / 255.0,
               (colour & 0xFF) / 255.0);
    label = open + label + L"</color>";
  }
  wchar_t value[32];
  swprintf_s(value, L"%d kills", static_cast<int>(kills));
  return uhc::SetUnitPanelRow(panel, label.c_str(), value);
}

namespace uhc {

Outcome ApplyVeterancyBonus(const Config& config) {
  const Config::Args* args = config.First("veterancyBonus");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::string file;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (arg.size() > 4 && _stricmp(arg.c_str() + arg.size() - 4, ".xml") == 0 && file.empty()) {
      file = arg;
    } else {
      Log(L"veterancyBonus: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("veterancyBonus", {&sites::kSnareApply, &sites::kIsA}) ||
      !LoadDataFile(file) ||
      !AddTransformObserver({&KillsBeforeTransform, &RestoreAfterTransform}) ||
      !VerifyFloatingText("veterancyBonus") || !AddProtoTagHandler("VeterancyBonus", &ReadVeterancyBonus) ||
      !AddTechSubtype("VeterancyEnable", &ChangeEnable) || !AddTechSubtype("VeterancyBonus", &ChangeFactor) ||
      !OnDatabaseLoad(&ForgetOnDataLoad) || !AddKillObserver(&VeterancyKill)) {
    return Outcome::kFailed;
  }
  std::fill(std::begin(g_rankModels), std::end(g_rankModels), -2);
  g_marks = VerifyAll("veterancyBonus marks", {&sites::kUnitById}) && VerifyUnitModels("veterancyBonus marks") &&
            AddWorldTick(&Tick);
  if (!AddUnitPanelRow(&UhcVeterancyRow)) {
    Log(L"veterancyBonus: no rank row in the unit panel");
  }
  Log(L"veterancyBonus: the proto tag VeterancyBonus is on, and the Data subtypes VeterancyEnable and VeterancyBonus%ls",
      g_marks ? L"; rank marks on" : L"; no rank marks");
  if (g_defaults.empty() && g_styles.empty()) {
    Log(L"veterancyBonus: no default rows and no rank names (%ls)", g_file.c_str());
  } else {
    Log(L"veterancyBonus: %u unit types with default rows and %u rank names from %ls",
        static_cast<unsigned>(g_defaults.size()), static_cast<unsigned>(g_styles.size()), g_file.c_str());
  }
  return Outcome::kApplied;
}

}  // namespace uhc
