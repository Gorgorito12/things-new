// veterancyBonus: a unit grows stronger with its kills.
//
//   <VeterancyBonus kills="1" modifytype="Damage">1.15</VeterancyBonus>   repeatable, in a proto
//
// Each row says: from that many kills on, this stat is multiplied by this much, in all (1.15 then 1.30
// is ×1.30 at the second row, not 1.15 × 1.30). modifytype takes every <ModifyType> name.
//
// Stock's flag ExperienceUnit has no reader in the exe, so nothing counts a unit's kills. The hook sits
// on TakeDamage's kill path, where the attacker unit is known. The count and the bonuses are all stat
// modifiers of the game (0x4DD22D, the call of snares and auras, with no time limit), so that the game
// saves them, the stat code reads them and a transformed unit keeps them:
// - the count is a modifier of a stat no code reads, kStatKills, whose value is the kills;
// - each row reached adds a multiply modifier for what its total adds to the row before it.
// A transform in place (0x9C754C: TransformUnit, revolutions) ends the unit's modifiers, so its seven
// calls go through a wrapper that puts the count back, and the bonuses of the kills reached that the
// new proto's rows give. The rows are read once, by proto ID, and are the same for every player. The hook is in
// hooks/veterancy_hooks.asm.
//
// Two tech effects of type="Data" act on one player's copy of the proto: subtype="VeterancyEnable" (0 turns the
// rows off for that player, anything else on; base 1) and subtype="VeterancyBonus" (a factor on what every row
// adds: a row of 1.30 with factor 2 gives 1.60; base 1). Ranks already granted are game modifiers and stay.
//
// A unit with a rank carries a mark, tools/rings' rank_1 to rank_3, and the unit panel's row says its rank. Both only
// show: the mark is a visual of the unit. A kill and a transform name a unit for the world tick, which hangs the
// mark; the tick looks only at units with a mark; one walk over the world's units finds the ranks of a loaded game.
#include <algorithm>
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

extern "C" void UhcVeterancyHook();

namespace {

constexpr std::uint32_t kKillPath = 0x004D4F37;
constexpr std::int32_t kStatKills = 0x62;       // no stock stat or key uses it; transformSpan has 60h and 61h
constexpr std::int32_t kOperationSet = 0;
constexpr std::int32_t kOperationMultiply = 2;
constexpr std::uint32_t kRankColour = 0xFFFFD700;
constexpr int kMaxLogLines = 200;
constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kMarkTickMs = 250;
constexpr std::uint32_t kTimeJumpMs = 2000;  // more than a world update: a game was loaded
constexpr std::int32_t kMarkRanks = 3;       // tools/rings has this many; a higher rank keeps the last

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

struct Row {
  std::int32_t kills;
  std::int32_t stat;
  float total;
};

std::unordered_map<std::int32_t, std::vector<Row>> g_rows;  // by proto ID; the load fills it

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

float TotalFor(const char* copy, float total) {
  const TechOverride* tech = TechFor(copy);
  if (tech == nullptr || tech->factor == 1.0f) {
    return total;
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
  if (kills < 1 || stat < 0 || total <= 0.0f) {
    uhc::Log(L"veterancyBonus: proto %d: a row with kills %d, stat %d, value %hs is not valid; ignored", id, kills, stat,
             amount);
    return true;
  }
  std::vector<Row>& rows = g_rows[id];
  rows.push_back({kills, stat, total});
  std::stable_sort(rows.begin(), rows.end(), [](const Row& a, const Row& b) { return a.kills < b.kills; });
  if (g_log) {
    uhc::Log(L"veterancyBonus: proto %d: from %d kills, stat %d x%g", id, kills, stat, static_cast<double>(total));
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
  const char* proto = Field<const char*>(unit, 0x5C);
  const auto found = proto != nullptr ? g_rows.find(Field<std::int32_t>(proto, 8)) : g_rows.end();
  return found == g_rows.end() ? 0 : RankOf(found->second, KillsOf(unit));
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
    if (proto != nullptr && g_rows.count(Field<std::int32_t>(proto, 8)) != 0 && FindCount(unit) != nullptr) {
      g_pending.push_back(Field<std::int32_t>(unit, 0x10));
    }
  }
}

void Tick(char* world, std::int32_t) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  if (game == nullptr || world != Field<const char*>(game, 0x13C) || g_rows.empty() || g_noArt) {
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

// Around the transform in place, which ends the unit's modifiers.
float KillsBeforeTransform(const char* unit) {
  const char* count = g_rows.empty() ? nullptr : FindCount(unit);
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
  const auto found = now != nullptr ? g_rows.find(Field<std::int32_t>(now, 8)) : g_rows.end();
  if (found == g_rows.end()) {
    return;
  }
  // The total of each stat is its last row reached.
  std::unordered_map<std::int32_t, float> totals;
  for (const Row& row : found->second) {
    if (static_cast<float>(row.kills) <= kills) {
      totals[row.stat] = row.total;
    }
  }
  for (const auto& [stat, total] : totals) {
    kModifier(unit, stat, TotalFor(now, total), -1.0f, -1.0f, 0, kOperationMultiply, 0, -1, -1, 0);
  }
  if (g_log) {
    uhc::Log(L"veterancyBonus: unit %d keeps %g kills as proto %d", Field<std::int32_t>(unit, 0x10),
             static_cast<double>(kills), Field<std::int32_t>(now, 8));
  }
}

}  // namespace

// From the hook, for every killing blow.
extern "C" void __stdcall UhcVeterancyKill(char* attacker, const char* victim) {
  if (attacker == nullptr || victim == nullptr) {
    return;
  }
  const char* proto = Field<const char*>(attacker, 0x5C);
  if (proto == nullptr) {
    return;
  }
  const auto found = g_rows.find(Field<std::int32_t>(proto, 8));
  if (found == g_rows.end() || !EnabledFor(proto)) {
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
  float applied = 1.0f;  // the last multiplier given, for the log
  for (const Row& row : found->second) {
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
    float before = 1.0f;
    for (const Row& earlier : found->second) {
      if (earlier.kills < row.kills && earlier.stat == row.stat) {
        before = earlier.total;
      }
    }
    applied = TotalFor(proto, row.total) / TotalFor(proto, before);
    kModifier(attacker, row.stat, applied, -1.0f, -1.0f, 0, kOperationMultiply, 0, -1, -1, 0);
  }
  if (reached) {
    wchar_t text[32];
    swprintf(text, 32, L"Rank %d", rank);
    uhc::ShowUnitText(attacker, text, -1, kRankColour);
    if (g_marks) {
      g_pending.push_back(Field<std::int32_t>(attacker, 0x10));
    }
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"veterancyBonus: unit %d, proto %d: %d kills%ls, rank %d%ls%g", Field<std::int32_t>(attacker, 0x10),
             Field<std::int32_t>(proto, 8), kills, reached ? L", a new rank" : L"", rank, reached ? L", x" : L"",
             reached ? static_cast<double>(applied) : 0.0);
  }
}

// The unit panel's row, for a unit with kills.
bool __stdcall UhcVeterancyRow(const char* panel, const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  if (proto == nullptr || g_rows.count(Field<std::int32_t>(proto, 8)) == 0) {
    return false;
  }
  const float kills = KillsOf(unit);
  if (kills < 1.0f) {
    return false;
  }
  wchar_t label[32];
  wchar_t value[32];
  swprintf_s(label, L"Rank %d", RankOfUnit(unit));
  swprintf_s(value, L"%d kills", static_cast<int>(kills));
  return uhc::SetUnitPanelRow(panel, label, value);
}

namespace uhc {

Outcome ApplyVeterancyBonus(const Config& config) {
  const Config::Args* args = config.First("veterancyBonus");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"veterancyBonus: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("veterancyBonus", {&sites::kVeterancyKillPath, &sites::kSnareApply}) ||
      !AddTransformObserver({&KillsBeforeTransform, &RestoreAfterTransform}) ||
      !VerifyFloatingText("veterancyBonus") || !AddProtoTagHandler("VeterancyBonus", &ReadVeterancyBonus) ||
      !AddTechSubtype("VeterancyEnable", &ChangeEnable) || !AddTechSubtype("VeterancyBonus", &ChangeFactor) ||
      !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !WriteJmp(kKillPath, reinterpret_cast<const void*>(&UhcVeterancyHook), 6)) {
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
  return Outcome::kApplied;
}

}  // namespace uhc
