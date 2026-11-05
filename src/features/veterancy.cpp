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
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
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
#include "../transformcalls.h"

extern "C" void UhcVeterancyHook();

namespace {

constexpr std::uint32_t kKillPath = 0x004D4F37;
constexpr std::int32_t kStatKills = 0x62;       // no stock stat or key uses it; transformSpan has 60h and 61h
constexpr std::int32_t kOperationSet = 0;
constexpr std::int32_t kOperationMultiply = 2;
constexpr std::uint32_t kRankColour = 0xFFFFD700;
constexpr int kMaxLogLines = 200;

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

struct Row {
  std::int32_t kills;
  std::int32_t stat;
  float total;
};

std::unordered_map<std::int32_t, std::vector<Row>> g_rows;  // by proto ID; the load fills it
bool g_log = false;
int g_logLines = 0;

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

// Around the transform in place, which ends the unit's modifiers.
float KillsBeforeTransform(const char* unit) {
  const char* count = g_rows.empty() ? nullptr : FindCount(unit);
  return count != nullptr ? Field<float>(count, 0x68) : 0.0f;
}

void RestoreAfterTransform(char* unit, float kills) {
  if (kills < 1.0f || FindCount(unit) != nullptr) {
    return;
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
    kModifier(unit, stat, total, -1.0f, -1.0f, 0, kOperationMultiply, 0, -1, -1, 0);
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
  if (found == g_rows.end()) {
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
    kModifier(attacker, row.stat, row.total / before, -1.0f, -1.0f, 0, kOperationMultiply, 0, -1, -1, 0);
  }
  if (reached) {
    wchar_t text[32];
    swprintf(text, 32, L"Rank %d", rank);
    uhc::ShowUnitText(attacker, text, -1, kRankColour);
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"veterancyBonus: unit %d, proto %d: %d kills%ls, rank %d", Field<std::int32_t>(attacker, 0x10),
             Field<std::int32_t>(proto, 8), kills, reached ? L", a new rank" : L"", rank);
  }
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
      !WriteJmp(kKillPath, reinterpret_cast<const void*>(&UhcVeterancyHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"veterancyBonus: the proto tag VeterancyBonus is on");
  return Outcome::kApplied;
}

}  // namespace uhc
