# Code for WoL: Combat

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [dodgeAnyUnit, dodgeSoundSet and criticalSoundSet](#dodgeanyunit-dodgesoundset-and-criticalsoundset)
- [damageOverTime](#damageovertime)
- [spreadAnyAccuracy](#spreadanyaccuracy)
- [accuracyTechs](#accuracytechs)
- [broadsideMuzzleLimit](#broadsidemuzzlelimit)
- [snareOnlyHitUnit](#snareonlyhitunit)
- [cantBeSlowed](#cantbeslowed)
- [killBountyTechs, resourceBounty and teamKillBounty](#killbountytechs-resourcebounty-and-teamkillbounty)
- [pillageGold](#pillagegold)
- [veterancyBonus](#veterancybonus)
- [detonationDeath](#detonationdeath)

## dodgeAnyUnit, dodgeSoundSet and criticalSoundSet

Contract: [dodgeAnyUnit, dodgeSoundSet and criticalSoundSet](../porting-to-another-dll.md#dodgeanyunit-dodgesoundset-and-criticalsoundset).

Besides the core helpers, it needs: [`prototags.h`](helpers.md#proto-tags), [`techsubtypes.h`](helpers.md#tech-subtypes), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `SyncRandom` `0x407CE7` (64 B), `IsA` `0x44D7FA` (105 B), `DodgeTest` `0x49ACAA` (110 B), `DodgeProtoCheck` `0x49ACE5` (12 B), `DodgeCaller` `0x49AF98` (146 B), `DodgeCall` `0x49B023` (7 B), `DamageTypeLoad` `0x52D454` (81 B), `TechByName` `0x600BE1` (16 B), `DodgeRollPath` `0x6A249C` (437 B), `DodgeTechCheck` `0x6A249C` (10 B), `DodgeSound` `0x6A2628` (8 B), `CriticalSound` `0x6A2A9A` (8 B), `TechActive` `0x94AF27` (51 B).

### src/features/dodge.cpp

```cpp
// dodgeAnyUnit / dodgeChance / dodgeSoundSet / criticalSoundSet.
//
// Stock lets a hit be dodged (no damage, 15 % of the time, while the target's player has the tech
// ypDodge active) only when the target is one of the three ypMonkJapanese protos: FUN_0049ACAA
// compares the proto ID with IDs cached at database+5E88h..5E90h. dodgeAnyUnit adds a marker
// unittype (default AbstractDodge): a unit whose proto has it takes the same stock path, so the
// tech, the roll, the floating text and the sound are unchanged.
//
// The dodge plays the sound set "PowerEvade" and a critical hit "PowerCriticalStrike" (both in
// soundsetsy.xml), whatever the unit. dodgeSoundSet <UnitType> <SoundSet> and criticalSoundSet
// <UnitType> <SoundSet> choose another set per unit type (or proto name): the first matching
// line wins, a unit that matches none keeps the stock set. A dodge sound belongs to the unit
// that dodged; a critical sound to the attacker. The hooks are in hooks/dodge_hooks.asm.
//
// dodgeChance <UnitType> <percent> [tech <TechName> | notech] [ranged | melee | all] [log], one
// rule per line, in cfg order; the first rule whose type the hit unit has, and whose filter the
// hit's damage type passes, decides: the tech (default ypDodge, as stock) must be active for the
// unit's player, then the stock synced roll 0x407CE7 on stream 2, here over [0, 999], dodges when
// it is below percent x 10. A dodge takes the stock path's end (0x6A24FC): the floating text, the
// sound and "true". A rule's units dodge with or without the dodgeAnyUnit marker; a unit no rule
// matches keeps the behaviour of the other keys (the marker's stock path, or the Japanese monks).
// The damage type of the hit is the byte +5 of the action's damage info ([action+24h]), the
// caller's EDI (FUN_0048649F, 0x49AF98..0x49B023): its index in damagetypes.xml. Tech and damage
// type names are resolved on the first test after each data load, so every machine resolves the
// same names from the same data; an unknown name is logged and disables its rule.
//
// The proto tags <CanDodgeAttacks>1</CanDodgeAttacks> and <DodgeChance>percent</DodgeChance> (the
// names another edition of the game uses) mark a proto in the data instead of the cfg: with the
// first, the unit dodges every hit type with the percent of the second (15 if absent), no tech
// needed; they are read with dodgeAnyUnit on and come before the cfg rules. Two tech effects of
// type="Data" change that for one player's copy of the proto: subtype="EnableDodge" (0 off, else on;
// base: the tag) and subtype="DodgeChance" (the percent; base: the tag's, or 15).
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

#include <unordered_map>

namespace {

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using TechByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using TechActiveFn = bool(__thiscall*)(const char* techStatus, std::int32_t playerId, std::int32_t techId);
using SyncRandomFn = std::int32_t(__thiscall*)(void* rng, std::int32_t stream, std::int32_t max);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kTechByName = reinterpret_cast<TechByNameFn>(0x00600BE1);
const auto kTechActive = reinterpret_cast<TechActiveFn>(0x0094AF27);
const auto kSyncRandom = reinterpret_cast<SyncRandomFn>(0x00407CE7);
void* const kSyncRng = reinterpret_cast<void*>(0x00C66588);  // the stock dodge rolls stream 2 of it
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
constexpr std::uint32_t kGameGlobal = 0x00C66234;             // game; +13Ch world, +140h database

// What UhcDodgeDecide tells the hook at 0x49ACE5 (hooks/dodge_hooks.asm).
enum Decision : std::int32_t {
  kStockCompares = 0,  // stock: only the three ypMonkJapanese protos go on
  kStockPath = 1,      // the dodgeAnyUnit marker: the stock path (ypDodge, 15 %)
  kDodged = 2,         // the end of the stock path: floating text, sound, true
  kNotDodged = 3,      // false
};

// The stock sound set names the two pushes replace (0xBD74E0, 0xBD7518).
const char* const kStockDodgeSound = reinterpret_cast<const char*>(0x00BD74E0);
const char* const kStockCriticalSound = reinterpret_cast<const char*>(0x00BD7518);

struct SoundRule {
  std::string type;   // unittype or proto name, as written in uhc.cfg
  std::string sound;  // sound set name
  std::int32_t id = -1;
};

struct ChanceRule {
  std::string type;              // unittype or proto name, as written in uhc.cfg
  std::int32_t permille = 0;     // the percent x 10, 0..1000
  std::string tech = "ypDodge";  // empty with notech
  std::string damage;            // "Hand" (melee), "Ranged" (ranged) or empty (all)
  std::int32_t typeId = -1;      // set on each data load
  // Resolved on the first test after each data load (g_generation).
  std::uint32_t generation = 0;
  std::int32_t techId = -1;
  std::int32_t damageType = -1;
  bool disabled = false;
};

struct ProtoDodge {
  bool enabled = false;         // <CanDodgeAttacks>
  std::int32_t permille = 150;  // <DodgeChance>, percent x 10
};
std::unordered_map<std::int32_t, ProtoDodge> g_protoDodge;  // by proto ID; the load writes it

struct TechDodge {
  std::int32_t id = -1;   // the proto ID the copy had: a reused pointer with another ID is ignored
  float enabled = -1.0f;  // -1: no tech touched it
  float percent = -1.0f;
};
std::unordered_map<const char*, TechDodge> g_techDodge;  // by the player's copy of the proto

// Never resized after the features are applied: the hooks read them from the game thread.
std::vector<SoundRule> g_dodgeSounds;
std::vector<SoundRule> g_criticalSounds;
std::vector<ChanceRule> g_chanceRules;
std::uint32_t g_generation = 1;  // raised on each data load
bool g_log = false;        // "dodgeAnyUnit ... log": also log which sound set each dodge or critical plays
bool g_chanceLog = false;  // "dodgeChance ... log": every roll

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* ProtoName(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* PickSound(const std::vector<SoundRule>& rules, const char* unit, const char* stock, const wchar_t* what) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* sound = stock;
  if (proto != nullptr) {
    for (const SoundRule& rule : rules) {
      if (rule.id >= 0 && kProtoIsType(proto, rule.id)) {
        sound = rule.sound.c_str();
        break;
      }
    }
  }
  if (g_log) {
    uhc::Log(L"%ls: unit %d (%hs) plays sound set %hs", what, unit == nullptr ? -1 : Field<std::int32_t>(unit, 0x10),
             ProtoName(unit), sound);
  }
  return sound;
}

// Reads every "<key> <UnitType> <SoundSet>" line; false if a line is malformed.
bool ParseSoundRules(const uhc::Config& config, const char* key, std::vector<SoundRule>* rules) {
  const auto* lines = config.All(key);
  if (lines == nullptr) {
    return true;
  }
  for (const uhc::Config::Args& args : *lines) {
    if (args.size() != 2) {
      uhc::Log(L"%hs: expected \"%hs <UnitType> <SoundSet>\", got %u argument(s); feature not applied", key, key,
               static_cast<unsigned>(args.size()));
      return false;
    }
    rules->push_back({args[0], args[1]});
  }
  return true;
}

// "15", "2.5", "0", "100": a percent with at most one decimal.
bool ParsePercent(const std::string& text, std::int32_t* permille) {
  char* end = nullptr;
  const double value = std::strtod(text.c_str(), &end);
  if (text.empty() || end != text.c_str() + text.size() || !(value >= 0.0) || value > 100.0) {
    return false;
  }
  const double tenths = value * 10.0;
  if (std::fabs(tenths - std::floor(tenths + 0.5)) > 1e-6) {
    return false;
  }
  *permille = static_cast<std::int32_t>(std::floor(tenths + 0.5));
  return true;
}

// Reads every "dodgeChance <UnitType> <percent> [tech <TechName> | notech] [ranged | melee | all]
// [log]" line; false (logged) if one is malformed.
bool ParseChanceRules(const uhc::Config& config) {
  const auto* lines = config.All("dodgeChance");
  if (lines == nullptr) {
    return true;
  }
  for (const uhc::Config::Args& args : *lines) {
    ChanceRule rule;
    if (args.size() < 2 || !ParsePercent(args[1], &rule.permille)) {
      const std::string why = args.empty() ? "no argument" : args.size() < 2 ? "no percent" : "bad percent " + args[1];
      uhc::Log(L"dodgeChance: expected \"dodgeChance <UnitType> <percent 0-100> [tech <TechName> | notech] [ranged | "
               L"melee | all] [log]\" (%hs); feature not applied",
               why.c_str());
      return false;
    }
    rule.type = args[0];
    bool techGiven = false;
    bool filterGiven = false;
    for (std::size_t i = 2; i < args.size(); ++i) {
      const char* arg = args[i].c_str();
      if (_stricmp(arg, "log") == 0) {
        g_chanceLog = true;
      } else if (!techGiven && _stricmp(arg, "notech") == 0) {
        rule.tech.clear();
        techGiven = true;
      } else if (!techGiven && _stricmp(arg, "tech") == 0 && i + 1 < args.size()) {
        rule.tech = args[++i];
        techGiven = true;
      } else if (!filterGiven && (_stricmp(arg, "ranged") == 0 || _stricmp(arg, "melee") == 0 ||
                                  _stricmp(arg, "all") == 0)) {
        rule.damage = _stricmp(arg, "ranged") == 0 ? "Ranged" : _stricmp(arg, "melee") == 0 ? "Hand" : "";
        filterGiven = true;
      } else {
        uhc::Log(L"dodgeChance %hs: unexpected argument %hs (expected: [tech <TechName> | notech] [ranged | melee | "
                 L"all] [log]); feature not applied",
                 rule.type.c_str(), arg);
        return false;
      }
    }
    g_chanceRules.push_back(rule);
  }
  return true;
}

void NewDatabase(char*) { ++g_generation; }

const char* Database() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

// The index of a damage type in the database's list [db+44h] (count [db+48h]; entries of 10h bytes,
// the name at +4, from damagetypes.xml), -1 if absent.
std::int32_t DamageTypeIndex(const char* database, const char* name) {
  const auto* entries = Field<const char* const*>(database, 0x44);
  const std::int32_t count = Field<std::int32_t>(database, 0x48);
  for (std::int32_t i = 0; entries != nullptr && i < count; ++i) {
    const char* entry = entries[i];
    const char* entryName = entry == nullptr ? nullptr : Field<const char*>(entry, 4);
    if (entryName != nullptr && _stricmp(entryName, name) == 0) {
      return i;
    }
  }
  return -1;
}

// On the first test after a data load: the rule's tech and damage type IDs; an unknown name is
// logged and disables the rule until the next load.
void Resolve(ChanceRule& rule, std::size_t index) {
  rule.generation = g_generation;
  rule.disabled = false;
  rule.techId = -1;
  rule.damageType = -1;
  const char* database = Database();
  if (database == nullptr) {
    rule.disabled = true;
    return;
  }
  if (!rule.tech.empty()) {
    rule.techId = kTechByName(database, rule.tech.c_str());
    if (rule.techId < 0) {
      uhc::Log(L"dodgeChance: rule %u (%hs): no tech named %hs; rule disabled", static_cast<unsigned>(index + 1),
               rule.type.c_str(), rule.tech.c_str());
      rule.disabled = true;
    }
  }
  if (!rule.damage.empty()) {
    rule.damageType = DamageTypeIndex(database, rule.damage.c_str());
    if (rule.damageType < 0) {
      uhc::Log(L"dodgeChance: rule %u (%hs): no damage type %hs in damagetypes.xml; rule disabled",
               static_cast<unsigned>(index + 1), rule.type.c_str(), rule.damage.c_str());
      rule.disabled = true;
    }
  }
  if (g_chanceLog && !rule.disabled) {
    uhc::Log(L"dodgeChance: rule %u (%hs): %.1f %%, tech %hs (ID %d), damage type %hs (index %d)",
             static_cast<unsigned>(index + 1), rule.type.c_str(), rule.permille / 10.0,
             rule.tech.empty() ? "none" : rule.tech.c_str(), rule.techId,
             rule.damage.empty() ? "any" : rule.damage.c_str(), rule.damageType);
  }
}

// The synced roll over [0, 999], below permille: dodged. 0 % and 100 % roll nothing.
std::int32_t Roll(const char* unit, std::int32_t permille, const wchar_t* label, bool log) {
  std::int32_t roll = -1;
  bool dodged = permille >= 1000;
  if (permille > 0 && permille < 1000) {
    roll = kSyncRandom(kSyncRng, 2, 999);
    dodged = roll < permille;
  }
  if (log) {
    uhc::Log(L"dodgeChance: unit %d (%hs), %ls (%.1f %%): roll %d -> %ls", Field<std::int32_t>(unit, 0x10),
             ProtoName(unit), label, permille / 10.0, roll, dodged ? L"dodged" : L"hit");
  }
  return dodged ? kDodged : kNotDodged;
}

bool __cdecl ReadCanDodgeAttacks(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  const std::int32_t id = Field<std::int32_t>(proto, 8);
  g_protoDodge[id].enabled = text == nullptr || text[0] == L'\0' || _wtoi(text) != 0;
  if (g_log) {
    uhc::Log(L"dodgeAnyUnit: proto %d %ls (CanDodgeAttacks)", id, g_protoDodge[id].enabled ? L"can dodge" : L"cannot dodge");
  }
  return true;
}

bool __cdecl ReadDodgeChance(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  const std::int32_t id = Field<std::int32_t>(proto, 8);
  wchar_t* end = nullptr;
  const double percent = text == nullptr ? -1.0 : std::wcstod(text, &end);
  if (text == nullptr || end == text || !(percent >= 0.0) || !(percent <= 100.0)) {
    uhc::Log(L"dodgeAnyUnit: proto %d: <DodgeChance> needs a percent from 0 to 100, ignored", id);
    return true;
  }
  g_protoDodge[id].permille = static_cast<std::int32_t>(std::lround(percent * 10.0));
  if (g_log) {
    uhc::Log(L"dodgeAnyUnit: proto %d dodges %.1f %% (DodgeChance)", id, percent);
  }
  return true;
}

// The tag's values for a proto ID, as the base of the tech subtypes.
ProtoDodge TagOf(const char* proto) {
  const auto found = g_protoDodge.find(Field<std::int32_t>(proto, 8));
  return found == g_protoDodge.end() ? ProtoDodge{} : found->second;
}

void ChangeDodgeTech(char* proto, float* field, float base, float amount, std::uint8_t relativity, bool unapply,
                     const wchar_t* name) {
  if (*field < 0.0f) {
    *field = base;
  }
  const float before = *field;
  kEffectValue(relativity, field, base, amount, unapply);
  if (g_log || g_chanceLog) {
    uhc::Log(L"dodgeAnyUnit: proto %d, tech subtype %ls, relativity %u, amount %g%ls: %g -> %g",
             Field<std::int32_t>(proto, 8), name, relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", static_cast<double>(before), static_cast<double>(*field));
  }
}

TechDodge& TechSlot(char* proto) {
  TechDodge& slot = g_techDodge[proto];
  const std::int32_t id = Field<std::int32_t>(proto, 8);
  if (slot.id != id) {
    slot = TechDodge{};
    slot.id = id;
  }
  return slot;
}

void ChangeEnableDodge(char* proto, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  ChangeDodgeTech(proto, &TechSlot(proto).enabled, TagOf(base).enabled ? 1.0f : 0.0f, amount, relativity, unapply,
                  L"EnableDodge");
}

void ChangeDodgeChance(char* proto, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  ChangeDodgeTech(proto, &TechSlot(proto).percent, static_cast<float>(TagOf(base).permille) / 10.0f, amount,
                  relativity, unapply, L"DodgeChance");
}

void ForgetTechDodge(char*) { g_techDodge.clear(); }

// The matched rule decides: its tech, then the synced roll over [0, 999]. 0 % and 100 % roll
// nothing.
std::int32_t RollRule(const char* unit, const ChanceRule& rule, std::size_t index) {
  if (rule.techId >= 0) {
    const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
    const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
    const char* techStatus = world == nullptr ? nullptr : Field<const char*>(world, 0x7C);
    const char* player = Field<const char*>(unit, 0x44);
    if (techStatus == nullptr || player == nullptr ||
        !kTechActive(techStatus, Field<std::int32_t>(player, 0), rule.techId)) {
      if (g_chanceLog) {
        uhc::Log(L"dodgeChance: unit %d (%hs), rule %u: tech %hs not active -> hit", Field<std::int32_t>(unit, 0x10),
                 ProtoName(unit), static_cast<unsigned>(index + 1), rule.tech.c_str());
      }
      return kNotDodged;
    }
  }
  wchar_t label[24];
  swprintf_s(label, L"rule %u", static_cast<unsigned>(index + 1));
  return Roll(unit, rule.permille, label, g_chanceLog);
}

bool RequestRuleTypes(std::vector<SoundRule>* rules) {
  for (SoundRule& rule : *rules) {
    if (!uhc::RequestAbstractUnitType(rule.type.c_str(), &rule.id)) {
      return false;
    }
  }
  return true;
}

}  // namespace

extern "C" {
std::int32_t g_uhcDodgeType = -1;

void UhcDodgeProtoHook();
void UhcDodgeCallHook();
void UhcDodgeSoundHook();
void UhcCriticalSoundHook();

// From the hook at 0x49ACE5, for every hit that reaches the proto test of FUN_0049ACAA (database,
// player and world present). damageInfo: the caller's [action+24h], or null.
std::int32_t __stdcall UhcDodgeDecide(const char* unit, const char* damageInfo) {
  const char* proto = Field<const char*>(unit, 0x5C);
  if (proto == nullptr) {
    return kStockCompares;
  }
  const std::int32_t damageType = damageInfo == nullptr ? -1 : Field<std::uint8_t>(damageInfo, 5);
  if (!g_protoDodge.empty() || !g_techDodge.empty()) {
    const auto tagged = g_protoDodge.find(Field<std::int32_t>(proto, 8));
    bool enabled = tagged != g_protoDodge.end() && tagged->second.enabled;
    std::int32_t permille = tagged != g_protoDodge.end() ? tagged->second.permille : 150;
    auto tech = g_techDodge.find(proto);  // the copy of this player
    if (tech != g_techDodge.end() && tech->second.id != Field<std::int32_t>(proto, 8)) {
      tech = g_techDodge.end();  // the pointer was another proto's copy
    }
    if (tech != g_techDodge.end()) {
      if (tech->second.enabled >= 0.0f) {
        enabled = tech->second.enabled != 0.0f;
      }
      if (tech->second.percent >= 0.0f) {
        const long value = std::lround(tech->second.percent * 10.0f);
        permille = value < 0 ? 0 : value > 1000 ? 1000 : static_cast<std::int32_t>(value);
      }
    }
    if (enabled) {
      return Roll(unit, permille, tech != g_techDodge.end() ? L"CanDodgeAttacks, by tech" : L"CanDodgeAttacks",
                  g_chanceLog || g_log);
    }
  }
  for (std::size_t i = 0; i < g_chanceRules.size(); ++i) {
    ChanceRule& rule = g_chanceRules[i];
    if (rule.generation != g_generation) {
      Resolve(rule, i);
    }
    if (rule.disabled || rule.typeId < 0 || !kProtoIsType(proto, rule.typeId)) {
      continue;
    }
    if (rule.damageType >= 0 && damageType != rule.damageType) {
      continue;
    }
    return RollRule(unit, rule, i);
  }
  if (g_uhcDodgeType >= 0 && kProtoIsType(proto, g_uhcDodgeType)) {
    return kStockPath;
  }
  return kStockCompares;
}

void __stdcall UhcDodgeLogHit(const char* unit) {
  uhc::Log(L"dodgeAnyUnit: unit %d (%hs) dodged a hit", Field<std::int32_t>(unit, 0x10), ProtoName(unit));
}

const char* __stdcall UhcDodgeSoundFor(const char* unit) {
  return PickSound(g_dodgeSounds, unit, kStockDodgeSound, L"dodgeSoundSet");
}

const char* __stdcall UhcCriticalSoundFor(const char* unit) {
  return PickSound(g_criticalSounds, unit, kStockCriticalSound, L"criticalSoundSet");
}
}

namespace uhc {

Outcome ApplyDodge(const Config& config) {
  const Config::Args* dodge = config.First("dodgeAnyUnit");
  const bool sounds = config.Has("dodgeSoundSet") || config.Has("criticalSoundSet");
  const bool chance = config.Has("dodgeChance");
  if (dodge == nullptr && !sounds && !chance) {
    return Outcome::kNotConfigured;
  }

  std::string typeName = "AbstractDodge";
  bool typeGiven = false;
  bool log = false;
  if (dodge != nullptr) {
    for (const std::string& arg : *dodge) {
      if (_stricmp(arg.c_str(), "log") == 0) {
        log = true;
      } else if (!typeGiven) {
        typeName = arg;
        typeGiven = true;
      } else {
        Log(L"dodgeAnyUnit: unexpected argument %hs (expected: [UnitType] [log]); feature not applied", arg.c_str());
        return Outcome::kFailed;
      }
    }
  }
  g_log = log;
  if (!ParseSoundRules(config, "dodgeSoundSet", &g_dodgeSounds) ||
      !ParseSoundRules(config, "criticalSoundSet", &g_criticalSounds) || !ParseChanceRules(config)) {
    return Outcome::kFailed;
  }

  if (!VerifyAll("dodgeAnyUnit", {&sites::kDodgeProtoCheck, &sites::kDodgeTechCheck, &sites::kDodgeCall,
                                  &sites::kDodgeSound, &sites::kCriticalSound})) {
    return Outcome::kFailed;
  }
  // The cfg rules and the proto tags both roll: the roll's sites are checked for either.
  if ((chance || dodge != nullptr) &&
      !VerifyAll("dodgeChance", {&sites::kDodgeTest, &sites::kDodgeRollPath, &sites::kDodgeCaller,
                                 &sites::kSyncRandom, &sites::kTechActive, &sites::kTechByName,
                                 &sites::kDamageTypeLoad, &sites::kIsA})) {
    return Outcome::kFailed;
  }
  if (dodge != nullptr && (!AddProtoTagHandler("CanDodgeAttacks", &ReadCanDodgeAttacks) ||
                           !AddProtoTagHandler("DodgeChance", &ReadDodgeChance) ||
                           !AddTechSubtype("EnableDodge", &ChangeEnableDodge) ||
                           !AddTechSubtype("DodgeChance", &ChangeDodgeChance) || !OnDatabaseLoad(&ForgetTechDodge))) {
    return Outcome::kFailed;
  }

  // The proto test hook serves dodgeAnyUnit and dodgeChance.
  if ((dodge != nullptr || chance) &&
      !WriteJmp(sites::kDodgeProtoCheck.va, reinterpret_cast<const void*>(&UhcDodgeProtoHook), 6)) {
    return Outcome::kFailed;
  }
  if (chance) {
    for (ChanceRule& rule : g_chanceRules) {
      if (!RequestAbstractUnitType(rule.type.c_str(), &rule.typeId)) {
        return Outcome::kFailed;
      }
    }
    if (!OnDatabaseLoad(&NewDatabase)) {
      return Outcome::kFailed;
    }
    for (std::size_t i = 0; i < g_chanceRules.size(); ++i) {
      const ChanceRule& rule = g_chanceRules[i];
      Log(L"dodgeChance: rule %u: units of %hs dodge %.1f %% of %hs hits%hs%hs (multiplayer unverified)",
          static_cast<unsigned>(i + 1), rule.type.c_str(), rule.permille / 10.0,
          rule.damage.empty() ? "all" : rule.damage == "Hand" ? "melee" : "ranged",
          rule.tech.empty() ? ", no tech needed" : ", with tech ", rule.tech.c_str());
    }
    if (g_chanceLog) {
      Log(L"dodgeChance: every roll logged");
    }
  }

  if (dodge != nullptr) {
    if (!RequestAbstractUnitType(typeName.c_str(), &g_uhcDodgeType)) {
      return Outcome::kFailed;
    }
    if (log && !WriteCall(sites::kDodgeCall.va, reinterpret_cast<const void*>(&UhcDodgeCallHook))) {
      return Outcome::kFailed;
    }
    Log(L"dodgeAnyUnit: units of unittype %hs can dodge like ypMonkJapanese (tech ypDodge, 15 %%)%ls "
        L"(multiplayer unverified)",
        typeName.c_str(), log ? L", every dodge logged" : L"");
  }
  if (!g_dodgeSounds.empty()) {
    if (!RequestRuleTypes(&g_dodgeSounds) ||
        !WriteJmp(sites::kDodgeSound.va, reinterpret_cast<const void*>(&UhcDodgeSoundHook), 5)) {
      return Outcome::kFailed;
    }
    for (const SoundRule& rule : g_dodgeSounds) {
      Log(L"dodgeSoundSet: units of %hs play sound set %hs when they dodge", rule.type.c_str(), rule.sound.c_str());
    }
  }
  if (!g_criticalSounds.empty()) {
    if (!RequestRuleTypes(&g_criticalSounds) ||
        !WriteJmp(sites::kCriticalSound.va, reinterpret_cast<const void*>(&UhcCriticalSoundHook), 5)) {
      return Outcome::kFailed;
    }
    for (const SoundRule& rule : g_criticalSounds) {
      Log(L"criticalSoundSet: units of %hs play sound set %hs when they land a critical hit", rule.type.c_str(),
          rule.sound.c_str());
    }
  }
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/dodge_hooks.asm

```asm
; Hooks for dodgeAnyUnit, dodgeChance, dodgeSoundSet and criticalSoundSet. Entered through a jmp (or, for the
; log wrapper, a call) written over the stock code; each leaves through an explicit jmp to a
; verified continuation (docs/engine-symbols.md, "Dodge and critical hits").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcDodgeType:SDWORD      ; marker unittype ID, set on each database load; -1 before

UhcDodgeLogHit PROTO STDCALL unit:DWORD
UhcDodgeDecide PROTO STDCALL unit:DWORD, damageInfo:DWORD   ; EAX: DECIDE_*
UhcDodgeSoundFor PROTO STDCALL unit:DWORD
UhcCriticalSoundFor PROTO STDCALL unit:DWORD

.data
dodgePath       dd 006A249Ch    ; the dodge: push "ypDodge" / tech lookup / 15 % roll
protoCompares   dd 0049ACEBh    ; stock: cmp eax,[ecx+5E88h] ... the three Japanese monk IDs
dodgeStock      dd 0049ACAAh    ; bool thiscall(unit): the dodge test the damage function calls
dodgeShown      dd 006A24FCh    ; after the stock roll: floating text, sound set, mov al,1 / ret
dodgeNone       dd 0049AD0Fh    ; pop edi / pop ebx / xor al,al / pop esi / add esp,78h / ret

DECIDE_STOCK_COMPARES EQU 0     ; UhcDodgeDecide's answers (dodge.cpp, Decision)
DECIDE_STOCK_PATH     EQU 1
DECIDE_DODGED         EQU 2
DECIDE_NOT_DODGED     EQU 3
dodgeSoundNext  dd 006A262Dh    ; add esi,14h / push esi / call 4AA24Ch (play sound set)
critSoundNext   dd 006A2A9Fh    ; lea eax,[ebx+14h] / push eax / call 4AA24Ch (play sound set)

.code

; Replaces 0x49ACE5..0x49ACEA (mov eax,[esi+5Ch] / mov eax,[eax+4]) in FUN_0049ACAA, where only
; the three ypMonkJapanese protos may dodge. ESI = the unit being hit, ECX = database, EBX = its
; player, EDI = [world+7Ch]; [esp] = the caller's EDI, saved at 0x49ACDD: the hit's damage info
; [action+24h] at the only call, 0x49B023 (dodge.cpp). The frame is the stock one and the FPU stack
; is empty. UhcDodgeDecide (dodgeChance's rules, then dodgeAnyUnit's marker) picks the way out:
; the stock compares (the stolen loads redone), the stock dodge path (tech ypDodge, 15 % roll; ECX
; = database and EDI = [world+7Ch] as it expects), the end of that path after its roll (0x6A24FC:
; ESI and EBX are all it reads), or the stock "not dodged" exit. EAX and EDX are written there
; before they are read.
UhcDodgeProtoHook PROC
    TRACE_ONCE "dodge test (0x49ACE5)"
    push ecx                        ; the database
    push dword ptr [esp+4]          ; the damage info (the caller's EDI)
    push esi                        ; the unit being hit
    call UhcDodgeDecide
    pop ecx
    cmp eax, DECIDE_DODGED
    je dodged
    cmp eax, DECIDE_NOT_DODGED
    je notDodged
    cmp eax, DECIDE_STOCK_PATH
    je stockPath
    mov eax, dword ptr [esi+5Ch]    ; stolen 0x49ACE5
    mov eax, dword ptr [eax+4]      ; stolen 0x49ACE8
    jmp protoCompares
stockPath:
    jmp dodgePath
dodged:
    jmp dodgeShown
notDodged:
    jmp dodgeNone
UhcDodgeProtoHook ENDP

; Called instead of 0x49ACAA by the call at 0x49B023 (only with "dodgeAnyUnit … log"), so it
; returns to 0x49B028 (test al,al). ECX = the unit being hit. Logs every dodge; EAX, ECX and EDX
; are not preserved by a call in the stock code either.
UhcDodgeCallHook PROC
    TRACE_ONCE "dodgeAnyUnit log (0x49B023)"
    push ecx
    call dodgeStock
    pop ecx
    test al, al
    je done
    push eax
    push ecx
    call UhcDodgeLogHit
    pop eax
done:
    ret
UhcDodgeCallHook ENDP

; Replaces 0x6A2628 (push "PowerEvade") in FUN_0049ACAA, the sound set a dodge plays. ESI = the
; unit that dodged, ECX = game (used by the call that follows), EAX already pushed.
UhcDodgeSoundHook PROC
    TRACE_ONCE "dodgeSoundSet (0x6A2628)"
    push ecx
    push esi
    call UhcDodgeSoundFor           ; -> the configured sound set, or "PowerEvade"
    pop ecx
    push eax
    jmp dodgeSoundNext
UhcDodgeSoundHook ENDP

; Replaces 0x6A2A9A (push "PowerCriticalStrike") in the damage function's critical-hit path.
; EBX = the attacking unit (non-null here), ECX = game, EDX already pushed.
UhcCriticalSoundHook PROC
    TRACE_ONCE "criticalSoundSet (0x6A2A9A)"
    push ecx
    push ebx
    call UhcCriticalSoundFor        ; -> the configured sound set, or "PowerCriticalStrike"
    pop ecx
    push eax
    jmp critSoundNext
UhcCriticalSoundHook ENDP

END
```

## damageOverTime

Contract: [damageOverTime](../porting-to-another-dll.md#damageovertime).

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`floatingtext.h`](helpers.md#floating-text), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `DotTakeDamageEntry` `0x49B3D9` (14 B), `SnareTargetCheck` `0x4DD1DE` (35 B), `SnareCreate` `0x4DD201` (44 B), `SnareApply` `0x4DD22D` (130 B).

### src/features/damageovertime.cpp

```cpp
// damageOverTime: poison. A <ProtoAction> in protoy.xml that lists
// <AttachProtoUnit>X</AttachProtoUnit> attaches proto unit X to every unit it damages. For X's
// <Lifespan> seconds the damaged unit then takes, every ROF seconds, the damage of X's
// ProtoAction "Attaching", computed by the stock TakeDamage (damage type, damage bonuses,
// armor) and credited to the attacker's player. X is a data definition only: it is never
// created in the world. The hooks are in hooks/dot_hooks.asm; the tags are read through the shared
// action tag hook (actiontags.h) and the tick through the shared world update wrapper (worldtick.h).
//
// Optional tags next to <AttachProtoUnit>, in the same attacker <ProtoAction>:
// - <AttachMaxStacks>N</AttachMaxStacks>: each hit adds a stack, up to N; a tick deals the damage
//   times the stacks alive at its time (TakeDamage's multiplier). Each stack expires Lifespan
//   after its own hit; a hit at N stacks renews the oldest. N = 1 (no tag) is the single poison.
// - <AttachSnare>F</AttachSnare>: while poisoned, a unit that can move is slowed to F times its
//   speed, by the stock snare's call (0x4DD22D, the <TargetSpeedBoost> modifier, F instead of
//   0.65), renewed at each tick for one interval and a quarter second.
// - <AttachTickText>RRGGBB</AttachTickText>: each tick shows the damage dealt over the unit in
//   that colour, for the local player only (floatingtext.h); "damageOverTime noticktext" in
//   uhc.cfg turns it off on that machine.
#include <windows.h>

#include <algorithm>
#include <cmath>
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <map>
#include <string>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../floatingtext.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" bool __stdcall UhcCantBeSlowed(const char* unit);     // cantslow.cpp; false when that key is off
extern "C" bool __stdcall UhcCannotSnare(const char* attacker);  // cantslow.cpp; the attacking unit, or null

namespace {

// Engine layout (docs/engine-symbols.md, "Damage and poison").
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::int32_t kUnresolved = -2;

using TakeDamageFn = float(__fastcall*)(char* unit, void* unused, std::int32_t player, std::int32_t proto,
                                        char* action, std::int32_t attacker, float multiplier, float damage,
                                        float cap, std::int32_t, std::int32_t, std::int32_t, std::int32_t,
                                        std::int32_t, std::int32_t);
using PlayerProtoFn = char*(__thiscall*)(char* player, std::int32_t protoId);
using ProtoIdByNameFn = std::int32_t(__thiscall*)(char* database, const char* name);
using IsAliveFn = bool(__thiscall*)(char* unit);
using SnareFn = std::int32_t(__thiscall*)(char* unit, std::int32_t stat, float value, float, float, std::int32_t,
                                          std::int32_t operation, std::int32_t ms, std::int32_t, std::int32_t,
                                          std::int32_t exclusive);

const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kProtoIdByName = reinterpret_cast<ProtoIdByNameFn>(0x005A2346);
const auto kSnare = reinterpret_cast<SnareFn>(0x004DD22D);

constexpr std::int32_t kMaxStacks = 100;
constexpr std::uint32_t kSnareSlackMs = 250;  // the snare outlasts the next tick by this much
constexpr std::uint32_t kDefaultTickColour = 0xFF40FF40;

template <typename T>
T& Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<T*>(const_cast<char*>(base) + offset);
}

char* Game() { return *reinterpret_cast<char**>(kGameGlobal); }
char* MainWorld() { return Game() == nullptr ? nullptr : Field<char*>(Game(), 0x13C); }
char* Database() { return Game() == nullptr ? nullptr : Field<char*>(Game(), 0x140); }

// Units by ID: [world+0Ch] array, [world+10h] count; the low 18 bits index the array and
// [unit+10h] must equal the full ID.
char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char**>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

char* PlayerById(const char* world, std::int32_t id) {
  if (id < 0 || id >= Field<std::int32_t>(world, 0x5C)) {
    return nullptr;
  }
  return Field<char**>(world, 0x58)[id];
}

// A unit's proto is at [unit+5Ch]; its name, for the log, at [proto+10h].
const char* UnitProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name != nullptr ? name : "?";
}

// Unit vtable slot 0A4h (0x44D019 for units): alive and damageable, as the stock code tests
// before applying special damage.
bool IsAlive(char* unit) {
  return (*reinterpret_cast<IsAliveFn**>(unit))[0xA4 / 4](unit);
}

// Unit vtable slot 90h (0x45EE55): true for a unit that can move, the stock snare's test (0x4DD1EE).
bool CanMove(char* unit) {
  return (*reinterpret_cast<IsAliveFn**>(unit))[0x90 / 4](unit);
}

// Unit vtable slot 34h (0x487E27): the unit's current max velocity, modifiers (the snare) included.
// For the log only.
float Speed(char* unit) {
  using SpeedFn = float(__thiscall*)(char* unit);
  return (*reinterpret_cast<SpeedFn**>(unit))[0x34 / 4](unit);
}

// Unit flag 37h (bit 7 of [[unit+4]+6], bit count [unit+8]): the unit is in an army (AI armies;
// engine-symbols.md). For the log only.
bool InArmy(const char* unit) {
  const auto* bits = Field<const std::uint8_t*>(unit, 0x04);
  return bits != nullptr && Field<std::int32_t>(unit, 0x08) > 0x37 && (bits[6] & 0x80) != 0;
}

// ProtoAction names: [database+1FD8h] holds one UTF-16 string per name index, [+1FDCh] the
// count. An action keeps its name index at +4.
const wchar_t* ActionName(std::int32_t index) {
  const char* database = Database();
  if (database == nullptr || index < 0 || index >= Field<std::int32_t>(database, 0x1FDC)) {
    return L"?";
  }
  const wchar_t* name = Field<const wchar_t**>(database, 0x1FD8)[index];
  return name != nullptr ? name : L"?";
}

std::int32_t ActionNameIndex(const wchar_t* wanted) {
  const char* database = Database();
  if (database == nullptr) {
    return -1;
  }
  const auto names = Field<const wchar_t**>(database, 0x1FD8);
  for (std::int32_t i = 0; i < Field<std::int32_t>(database, 0x1FDC); ++i) {
    if (names[i] != nullptr && _wcsicmp(names[i], wanted) == 0) {
      return i;
    }
  }
  return -1;
}

// A proto's actions: tactics object at [proto+44h], actions at [tactics+1Ch], count [+20h].
char* FindAction(const char* proto, std::int32_t nameIndex) {
  const char* tactics = proto == nullptr ? nullptr : Field<char*>(proto, 0x44);
  if (tactics == nullptr || nameIndex < 0) {
    return nullptr;
  }
  char** actions = Field<char**>(tactics, 0x1C);
  for (std::int32_t i = 0; i < Field<std::int32_t>(tactics, 0x20); ++i) {
    if (actions[i] != nullptr && Field<std::int32_t>(actions[i], 0x04) == nameIndex) {
      return actions[i];
    }
  }
  return nullptr;
}

std::string Narrow(const wchar_t* text) {
  const int size = WideCharToMultiByte(CP_ACP, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) {
    return {};
  }
  std::string out(static_cast<std::size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_ACP, 0, text, -1, out.data(), size, nullptr, nullptr);
  return out;
}

// Game time in ms, [world+108h]; compared with wraparound in mind.
bool Reached(std::uint32_t now, std::uint32_t time) {
  return static_cast<std::int32_t>(now - time) >= 0;
}

struct ActionKey {
  std::int32_t proto;  // the attacker's proto ID
  std::int32_t name;   // the ProtoAction's name index
  auto operator<=>(const ActionKey&) const = default;
};

struct Attachment {
  std::string protoName;  // X, as written in protoy.xml; empty: only the optional tags were given
  std::int32_t proto = kUnresolved;
  std::int32_t maxStacks = 1;    // <AttachMaxStacks>
  float snare = -1.0f;           // <AttachSnare>: the speed factor while poisoned; < 0 none
  std::uint32_t tickColour = 0;  // <AttachTickText>: ARGB of the tick text; 0 none
};

// Filled while protoy.xml is parsed, keyed by proto ID and action name, since every player's
// copy of a proto keeps both.
std::map<ActionKey, Attachment> g_attachments;
// With "log": the (proto, action) pairs already reported as dealing damage without a record.
std::map<ActionKey, bool> g_loggedUntagged;
std::int32_t g_attachingName = kUnresolved;

struct DotKey {
  std::int32_t target;
  std::int32_t attachment;  // X's proto ID
  std::int32_t player;      // the attacker's player, who owns the damage
  auto operator<=>(const DotKey&) const = default;
};

struct Dot {
  std::int32_t attacker = -1;  // unit ID, -1 once it is gone
  std::uint32_t nextTick = 0;
  std::uint32_t end = 0;                 // the last stack's end
  std::vector<std::uint32_t> stacks;     // each stack's end, in game time order of expiry
  // From the latest hit's action.
  std::int32_t maxStacks = 1;
  float snare = -1.0f;
  std::uint32_t tickColour = 0;
};

// Ordered by key, so every machine applies the ticks in the same order.
std::map<DotKey, Dot> g_dots;
const char* g_dotWorld = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;

extern "C" void UhcDotTakeDamageStock();
const auto kTakeDamageStock = reinterpret_cast<TakeDamageFn>(&UhcDotTakeDamageStock);

// Resolves X's proto ID and the "Attaching" name index once, logging what a modder needs to
// fix. False if this attachment cannot work.
bool Resolve(Attachment& attachment) {
  if (attachment.proto == kUnresolved && attachment.protoName.empty()) {
    uhc::Log(L"damageOverTime: an attack has <AttachMaxStacks>, <AttachSnare> or <AttachTickText> but no "
             L"<AttachProtoUnit>; ignored");
    attachment.proto = -1;
  }
  if (attachment.proto == kUnresolved) {
    char* database = Database();
    attachment.proto = database == nullptr ? -1 : kProtoIdByName(database, attachment.protoName.c_str());
    if (g_attachingName == kUnresolved) {
      g_attachingName = ActionNameIndex(L"Attaching");
    }
    // Base protos: [database+54h] array, [database+58h] count.
    const char* proto = attachment.proto < 0 || attachment.proto >= Field<std::int32_t>(database, 0x58)
                            ? nullptr
                            : Field<char**>(database, 0x54)[attachment.proto];
    const char* attaching = FindAction(proto, g_attachingName);
    if (proto == nullptr) {
      uhc::Log(L"damageOverTime: %hs is not a proto unit; its attachments are ignored",
               attachment.protoName.c_str());
      attachment.proto = -1;
    } else if (attaching == nullptr) {
      uhc::Log(L"damageOverTime: %hs has no ProtoAction named Attaching (its tactics file must "
               L"define the action); its attachments are ignored",
               attachment.protoName.c_str());
      attachment.proto = -1;
    } else {
      uhc::Log(L"damageOverTime: %hs -> proto %d: Lifespan %.2f s, Attaching every %d ms",
               attachment.protoName.c_str(), attachment.proto, Field<float>(proto, 0xAC),
               Field<std::int32_t>(attaching, 0x34));
    }
  }
  return attachment.proto >= 0;
}

// X's Attaching action in the player's copy of X, so techs that change X apply.
char* PlayerAttaching(const char* world, std::int32_t player, std::int32_t attachment, const char** proto) {
  char* owner = PlayerById(world, player);
  *proto = owner == nullptr ? nullptr : kPlayerProto(owner, attachment);
  return FindAction(*proto, g_attachingName);
}

// The engine's diplomacy filter (FUN_0049AEE0) for a tick whose attacking unit is gone: without
// an attacking unit the engine lets every unit through, so the poison applies it with the
// attacker's player instead. DamageFlags are at [[action+24h]+4] (GAIA 1, Self 2, Ally 4,
// Enemy 8; FFh when the data sets none); a player's relations at [player+1D4h + 4*id], 2 = enemy.
bool DamageAllowed(const char* world, const char* attaching, std::int32_t player, const char* unit) {
  const char* info = Field<const char*>(attaching, 0x24);
  const char* owner = Field<const char*>(unit, 0x44);
  const char* attackerPlayer = PlayerById(world, player);
  if (info == nullptr || owner == nullptr || attackerPlayer == nullptr) {
    return true;
  }
  const std::uint8_t flags = Field<std::uint8_t>(info, 0x04);
  const std::int32_t unitPlayer = Field<std::int32_t>(owner, 0x00);
  if ((unitPlayer == 0 && !(flags & 1)) || (unitPlayer == player && !(flags & 2))) {
    return false;
  }
  const bool enemy = unitPlayer >= 0 && unitPlayer <= 15 &&
                     Field<std::int32_t>(attackerPlayer, 0x1D4 + 4 * static_cast<std::uint32_t>(unitPlayer)) == 2;
  return (flags & (enemy ? 8 : 4)) != 0;
}

// The Attaching ROF, stored in ms at [action+34h]; one second if it is missing.
std::uint32_t TickInterval(const char* attaching) {
  const std::int32_t rof = Field<std::int32_t>(attaching, 0x34);
  return static_cast<std::uint32_t>(rof > 0 ? rof : 1000);
}

// The stock snare's modifier (snareOnlyHitUnit in how-it-works.md): stat 0 (velocity), operation 2
// (multiply), timed, exclusive, with the data's factor instead of 0.65 and the given duration. The
// attacker is the unit whose hit attached the poison, or -1 once it is gone (then nothing stops the snare
// on its side, as cantBeSlowed's CannotSnare needs the unit).
void Snare(char* unit, std::int32_t attacker, float factor, std::uint32_t ms) {
  const char* world = MainWorld();
  const char* attackerUnit = world == nullptr || attacker < 0 ? nullptr : UnitById(world, attacker);
  if (factor >= 0.0f && CanMove(unit) && !UhcCantBeSlowed(unit) && !UhcCannotSnare(attackerUnit)) {
    kSnare(unit, 0, factor, -1.0f, -1.0f, 0, 2, static_cast<std::int32_t>(ms), -1, -1, 1);
  }
}

// "damageOverTime noticktext" in uhc.cfg: no tick text on this machine.
bool g_noTickText = false;

// The damage of a tick over the unit, for the local player (interface only).
void ShowTick(const char* unit, float dealt, std::uint32_t colour) {
  if (colour == 0 || g_noTickText || !(dealt > 0.0f) || !uhc::CanShowUnitText(unit)) {
    return;
  }
  wchar_t text[16];
  swprintf_s(text, L"-%ld", std::lround(dealt));
  uhc::ShowUnitText(unit, text, -1, colour);
}

// Drops the stacks whose end is before time (a tick at time counts the stacks with end >= time).
void DropExpired(Dot& dot, std::uint32_t time) {
  const auto alive = std::find_if(dot.stacks.begin(), dot.stacks.end(),
                                  [time](std::uint32_t end) { return Reached(end, time); });
  dot.stacks.erase(dot.stacks.begin(), alive);
}

// From the database load hook (unittypes.h), before the protos' contents are read: the data
// is loaded at startup and again when a skirmish starts (not when a scenario loads). Each load
// reads the tags again, and running poisons belong to the previous game.
void ResetForDataLoad(char*) {
  if (!g_dots.empty()) {
    uhc::Log(L"damageOverTime: the data was reloaded; %u running poison(s) dropped",
             static_cast<unsigned>(g_dots.size()));
  }
  g_attachments.clear();
  g_loggedUntagged.clear();
  g_attachingName = kUnresolved;
  g_dots.clear();
  g_dotWorld = nullptr;
}

// Drops every poison when another game is running: a new or loaded game can reuse the old
// world's address, so the test is the world's step count [world+F8h], which the world update
// raises by exactly 1 per step (0x481A87), and the game time going back. While poisons run, Tick
// sees every step; with none running, a jump only clears an empty map.
void SyncWorld(const char* world, std::uint32_t now) {
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  if (world != g_dotWorld || !Reached(now, g_lastTime) || step - g_lastStep > 1) {
    if (!g_dots.empty()) {
      uhc::Log(L"damageOverTime: another game started; %u running poison(s) dropped",
               static_cast<unsigned>(g_dots.size()));
    }
    g_dots.clear();
    g_dotWorld = world;
  }
  g_lastTime = now;
  g_lastStep = step;
}

// One-time diagnostics: each reason is logged the first time it happens, so a modder can see
// why a poison did not start or did no damage without the log growing in long games.
bool g_loggedNoAttaching = false;
bool g_loggedNotAlive = false;
bool g_loggedNoLifespan = false;
bool g_loggedFirstPoison = false;
bool g_loggedFirstTick = false;
// "damageOverTime log" in uhc.cfg: every poison start, refresh, tick and end, for tuning data.
bool g_logEvery = false;

void Attach(char* target, std::int32_t player, std::int32_t attacker, const Attachment& source) {
  const std::int32_t attachment = source.proto;
  const char* world = MainWorld();
  const char* proto = nullptr;
  const char* attaching = world == nullptr ? nullptr : PlayerAttaching(world, player, attachment, &proto);
  const std::int32_t targetId = Field<std::int32_t>(target, 0x10);
  if (attaching == nullptr) {
    if (!g_loggedNoAttaching) {
      g_loggedNoAttaching = true;
      uhc::Log(L"damageOverTime: player %d's copy of proto %d has no Attaching action; unit %d not poisoned", player,
               attachment, targetId);
    }
    return;
  }
  if (!IsAlive(target)) {
    if (!g_loggedNotAlive) {
      g_loggedNotAlive = true;
      uhc::Log(L"damageOverTime: unit %d is no longer alive and damageable; not poisoned", targetId);
    }
    return;
  }
  const float lifespan = Field<float>(proto, 0xAC);
  if (!(lifespan > 0.0f)) {
    if (!g_loggedNoLifespan) {
      g_loggedNoLifespan = true;
      uhc::Log(L"damageOverTime: player %d's copy of proto %d has Lifespan %.2f; unit %d not poisoned", player,
               attachment, lifespan, targetId);
    }
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  SyncWorld(world, now);
  const DotKey key{targetId, attachment, player};
  const auto [it, added] = g_dots.try_emplace(key);
  Dot& dot = it->second;
  if (added) {
    dot.nextTick = now + TickInterval(attaching);
  }
  // A new hit by the player's units makes that unit the attacker and takes its action's options.
  // It adds a stack that ends Lifespan (the current one) from now; at the stack limit it renews the
  // oldest stack instead. With one stack this restarts the duration. The tick timer keeps running.
  // Capped so the end stays within the 2^31 ms window that Reached() compares.
  dot.attacker = attacker;
  dot.maxStacks = source.maxStacks;
  dot.snare = source.snare;
  dot.tickColour = source.tickColour;
  const std::uint32_t stackEnd =
      now + static_cast<std::uint32_t>(
                std::min(static_cast<double>(lifespan) * 1000.0, 2147483647.0 - TickInterval(attaching)));
  DropExpired(dot, now);
  while (static_cast<std::int32_t>(dot.stacks.size()) >= dot.maxStacks) {
    dot.stacks.erase(dot.stacks.begin());  // the oldest, the first to expire
  }
  const auto before = [](std::uint32_t a, std::uint32_t b) { return static_cast<std::int32_t>(a - b) < 0; };
  dot.stacks.insert(std::upper_bound(dot.stacks.begin(), dot.stacks.end(), stackEnd, before), stackEnd);
  dot.end = dot.stacks.back();
  if (added) {
    Snare(target, attacker, dot.snare, TickInterval(attaching) + kSnareSlackMs);
  }
  if (!g_loggedFirstPoison || g_logEvery) {
    g_loggedFirstPoison = true;
    uhc::Log(L"damageOverTime: %ls: unit %d (%hs) by player %d, proto %d, stack %u/%d, every %u ms until game time "
             L"%u (now %u, %u active)",
             added ? L"poison" : L"poison renewed", targetId, UnitProtoName(target), player, attachment,
             static_cast<unsigned>(dot.stacks.size()), dot.maxStacks, TickInterval(attaching), dot.end, now,
             static_cast<unsigned>(g_dots.size()));
  }
}

// One tick: the stock TakeDamage with X's Attaching action, called the way the stock
// special-damage callers call it (0x986237 and others): multiplier = the live stacks (1 without
// <AttachMaxStacks>), damage computed from the action, no stats slot. Returns the damage dealt.
// The 11th argument turns on the hit notifications (retaliation, attack alerts, the army's
// attacker list). The army code (0x6A3253) reads the attacking unit without a null check, so an
// army unit (AI armies) poisoned by a unit that is gone would crash the game: with no attacking
// unit the tick passes 0 and skips them (the jne at 0x49B929).
float ApplyTick(char* target, char* attaching, const DotKey& key, const Dot& dot) {
  const std::int32_t notify = dot.attacker >= 0 ? 1 : 0;
  const float multiplier = static_cast<float>(dot.stacks.size());
  return kTakeDamageStock(target, nullptr, key.player, key.attachment, attaching, dot.attacker, multiplier, 0.0f, 0.0f,
                          0, 0, 1, notify, -2, 1);
}

void Tick(char* world) {
  if (world != MainWorld()) {
    return;  // other worlds run the same update; the function itself compares this with [game+13Ch]
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  SyncWorld(world, now);
  for (auto it = g_dots.begin(); it != g_dots.end();) {
    const DotKey& key = it->first;
    Dot& dot = it->second;
    char* target = UnitById(world, key.target);
    bool alive = target != nullptr && IsAlive(target);
    while (alive && Reached(now, dot.nextTick) && Reached(dot.end, dot.nextTick)) {
      const char* proto = nullptr;
      char* attaching = PlayerAttaching(world, key.player, key.attachment, &proto);
      if (attaching == nullptr) {
        alive = false;  // cannot happen once resolved; drop the poison rather than loop
        break;
      }
      if (UnitById(world, dot.attacker) == nullptr) {
        dot.attacker = -1;
      }
      DropExpired(dot, dot.nextTick);
      const float dealt =
          dot.attacker >= 0 || DamageAllowed(world, attaching, key.player, target) ? ApplyTick(target, attaching, key, dot)
                                                                                   : 0.0f;
      if (!g_loggedFirstTick || g_logEvery) {
        g_loggedFirstTick = true;
        wchar_t speed[32] = L"";
        if (dot.snare >= 0.0f) {
          swprintf_s(speed, L", speed %.2f", static_cast<double>(Speed(target)));
        }
        uhc::Log(L"damageOverTime: tick: unit %d (%hs) took %.2f damage (x%u), %.1f hitpoints left (tick due %u, game "
                 L"time %u)%ls%ls%ls",
                 key.target, UnitProtoName(target), dealt, static_cast<unsigned>(dot.stacks.size()),
                 Field<float>(target, 0x64), dot.nextTick, now, dot.attacker < 0 ? L", attacker gone" : L"",
                 dot.attacker < 0 && InArmy(target) ? L", army unit" : L"", speed);
      }
      dot.nextTick += TickInterval(attaching);
      alive = IsAlive(target);
      ShowTick(target, dealt, dot.tickColour);
      if (alive && Reached(dot.end, dot.nextTick)) {
        Snare(target, dot.attacker, dot.snare, TickInterval(attaching) + kSnareSlackMs);
      }
    }
    if (!alive || Reached(now, dot.end)) {
      if (g_logEvery) {
        uhc::Log(L"damageOverTime: poison on unit %d ended at game time %u: %ls", key.target, now,
                 !alive ? (target == nullptr ? L"unit gone" : L"unit dead or not damageable") : L"expired");
      }
      it = g_dots.erase(it);
    } else {
      ++it;
    }
  }
}

// From the shared action tag hook (actiontags.h), for each child of an action the stock parser does
// not know; only those of a protoy.xml <ProtoAction> are read. [proto+4] is the proto ID,
// [proto+10h] its name.
void DotActionTag(const uhc::ActionTag& tag) {
  if (tag.source != uhc::ActionSource::kProtoAction) {
    return;
  }
  const wchar_t* name = tag.name;
  const char* proto = tag.proto;
  const char* action = tag.action;
  const bool attach = _wcsicmp(name, L"AttachProtoUnit") == 0;
  const bool stacks = _wcsicmp(name, L"AttachMaxStacks") == 0;
  const bool snare = _wcsicmp(name, L"AttachSnare") == 0;
  const bool tickText = _wcsicmp(name, L"AttachTickText") == 0;
  if (!attach && !stacks && !snare && !tickText) {
    return;
  }
  const char* protoName = Field<const char*>(proto, 0x10);
  const ActionKey key{Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)};
  const wchar_t* text = tag.text;
  if (attach) {
    if (text == nullptr || *text == L'\0') {
      uhc::Log(L"damageOverTime: %hs/%ls: empty <AttachProtoUnit>; ignored", protoName, ActionName(key.name));
      return;
    }
    g_attachments[key].protoName = Narrow(text);
    uhc::Log(L"damageOverTime: %hs/%ls attaches %ls", protoName, ActionName(key.name), text);
    return;
  }
  wchar_t* end = nullptr;
  if (stacks) {
    const long value = text == nullptr ? 0 : std::wcstol(text, &end, 10);
    if (text == nullptr || end == text || *end != L'\0' || value < 1 || value > kMaxStacks) {
      uhc::Log(L"damageOverTime: %hs/%ls: <AttachMaxStacks>%ls</AttachMaxStacks> is not a whole number from 1 to %d; "
               L"ignored",
               protoName, ActionName(key.name), text == nullptr ? L"" : text, kMaxStacks);
      return;
    }
    g_attachments[key].maxStacks = static_cast<std::int32_t>(value);
    uhc::Log(L"damageOverTime: %hs/%ls: up to %ld stacks", protoName, ActionName(key.name), value);
  } else if (snare) {
    const float value = text == nullptr ? -1.0f : std::wcstof(text, &end);
    if (text == nullptr || end == text || *end != L'\0' || !(value >= 0.0f) || value > 10.0f) {
      uhc::Log(L"damageOverTime: %hs/%ls: <AttachSnare>%ls</AttachSnare> is not a speed factor from 0 to 10; ignored",
               protoName, ActionName(key.name), text == nullptr ? L"" : text);
      return;
    }
    g_attachments[key].snare = value;
    uhc::Log(L"damageOverTime: %hs/%ls: poisoned units move at %.2f times their speed", protoName,
             ActionName(key.name), static_cast<double>(value));
  } else {
    unsigned long rgb = kDefaultTickColour & 0xFFFFFFu;
    if (text != nullptr && *text != L'\0') {
      rgb = std::wcstoul(text, &end, 16);
      if (end == text || *end != L'\0' || end - text != 6) {
        uhc::Log(L"damageOverTime: %hs/%ls: <AttachTickText>%ls</AttachTickText> is not a colour RRGGBB; ignored",
                 protoName, ActionName(key.name), text);
        return;
      }
    }
    g_attachments[key].tickColour = 0xFF000000u | static_cast<std::uint32_t>(rgb);
    uhc::Log(L"damageOverTime: %hs/%ls: ticks shown in colour %06lX", protoName, ActionName(key.name), rgb);
  }
}

}  // namespace

extern "C" {

float __fastcall UhcDotTakeDamage(char* unit, void*, std::int32_t player, std::int32_t proto, char* action,
                                  std::int32_t attacker, float multiplier, float damage, float cap, std::int32_t a8,
                                  std::int32_t a9, std::int32_t a10, std::int32_t a11, std::int32_t a12,
                                  std::int32_t a13) {
  const float dealt = kTakeDamageStock(unit, nullptr, player, proto, action, attacker, multiplier, damage, cap, a8, a9,
                                       a10, a11, a12, a13);
  if (dealt > 0.0f && action != nullptr && !g_attachments.empty()) {
    const ActionKey key{proto, Field<std::int32_t>(action, 0x04)};
    const auto it = g_attachments.find(key);
    if (it != g_attachments.end() && Resolve(it->second)) {
      Attach(unit, player, attacker, it->second);
    } else if (g_logEvery && it == g_attachments.end() && g_loggedUntagged.size() < 200 &&
               g_loggedUntagged.try_emplace(key, true).second) {
      const char* database = Database();
      const char* attackerProto = database == nullptr || proto < 0 || proto >= Field<std::int32_t>(database, 0x58)
                                      ? nullptr
                                      : Field<char**>(database, 0x54)[proto];
      uhc::Log(L"damageOverTime: damage by proto %d (%hs), action %ls, attacker unit %d: no <AttachProtoUnit> there",
               proto, attackerProto == nullptr ? "?" : Field<const char*>(attackerProto, 0x10), ActionName(key.name),
               attacker);
    }
  }
  return dealt;
}

// After each world update (the shared wrapper of worldtick.cpp).
void DotWorldTick(char* world, std::int32_t) {
  if (!g_dots.empty()) {
    Tick(world);
  }
}

void* g_uhcDotTakeDamage = reinterpret_cast<void*>(&UhcDotTakeDamage);

void UhcDotTakeDamageHook();
}

namespace uhc {

Outcome ApplyDamageOverTime(const Config& config) {
  const Config::Args* args = config.First("damageOverTime");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_logEvery = true;
    } else if (_stricmp(arg.c_str(), "noticktext") == 0) {
      g_noTickText = true;
    } else {
      Log(L"damageOverTime: unknown argument %hs (expected: log, noticktext)", arg.c_str());
      return Outcome::kFailed;
    }
  }
  // The snare and the tick text sites are checked here too, though data decides whether they run.
  if (!VerifyAll("damageOverTime", {&sites::kDotTakeDamageEntry, &sites::kSnareTargetCheck, &sites::kSnareCreate,
                                    &sites::kSnareApply}) ||
      !uhc::VerifyFloatingText("damageOverTime") || !OnDatabaseLoad(&ResetForDataLoad)) {
    return Outcome::kFailed;
  }
  if (!AddActionTagHandler(&DotActionTag) ||
      !WriteJmp(sites::kDotTakeDamageEntry.va, reinterpret_cast<const void*>(&UhcDotTakeDamageHook), 6) ||
      !uhc::AddWorldTick(&DotWorldTick)) {
    return Outcome::kFailed;
  }
  Log(L"damageOverTime: <AttachProtoUnit> in protoy.xml ProtoActions attaches damage over time, with "
      L"<AttachMaxStacks>, <AttachSnare> and <AttachTickText>%ls (multiplayer unverified)",
      g_noTickText ? L"; tick texts off on this machine" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/dot_hooks.asm

```asm
; Hooks for damageOverTime (features/damageovertime.cpp). Each is entered through a jmp written
; over the stock code and leaves through an explicit jmp to a verified continuation
; (docs/engine-symbols.md, "Damage and poison").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcDotTakeDamage:DWORD      ; float fastcall(target, -, the 13 stock arguments)

.data
takeDamageBody      dd 0049B3DFh    ; cmp byte ptr [esp+0C0h],1, after the stolen sub esp,8Ch

.code

; Replaces sub esp,8Ch at 0x49B3D9, the entry of TakeDamage (float thiscall(unit, 13 arguments),
; ret 34h). The frame is unchanged, so the fastcall wrapper receives it as its own: ECX = the
; damaged unit, the stack arguments in place.
UhcDotTakeDamageHook PROC
    TRACE_ONCE "damageOverTime TakeDamage (0x49B3D9)"
    jmp g_uhcDotTakeDamage
UhcDotTakeDamageHook ENDP

; The stock TakeDamage for the wrapper: the stolen instruction, then the rest of the function.
UhcDotTakeDamageStock PROC
    sub esp, 8Ch
    jmp takeDamageBody
UhcDotTakeDamageStock ENDP

; The world update's tick goes through the shared wrapper of worldtick.cpp (AddWorldTick), and the
; <ProtoAction> tags through the shared action tag hook of actiontags.cpp (AddActionTagHandler).

END
```

## spreadAnyAccuracy

Contract: [spreadAnyAccuracy](../porting-to-another-dll.md#spreadanyaccuracy).

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `IsA` `0x44D7FA` (105 B), `SpreadHitRoll` `0x499890` (23 B), `SpreadMissStub` `0x4CEF7B` (17 B), `SpreadRadius` `0x4CF00B` (44 B), `SpreadDraws` `0x4CF037` (64 B).

### src/features/spread.cpp

```cpp
// spreadAnyAccuracy: per-action <MaxSpread> and <SpreadFactor>, and shots that scatter whatever the
// accuracy.
//
// Stock TAD scatters a projectile only when its precalculated accuracy roll misses: FUN_004CEF8C
// moves the impact point by uniform(-r, r) on x and z with a hardcoded r = min(0.25 * d, 5.0), d being
// the 2D distance from the projectile to the impact point. The <MaxSpread> and <SpreadFactor> tags of
// the tactics files (Age of Mythology leftovers) are not read at all. With this key:
// - every action (a .tactics <action> or a protoy.xml <ProtoAction>) accepts <MaxSpread> and
//   <SpreadFactor>, floats from 0 (no tag: the stock 5.0 and 0.25);
// - every miss uses the shooting action's values: r = min(SpreadFactor * d, MaxSpread), with the
//   stock random draws;
// - a unit whose proto has the marker type (default AbstractSpreadAnyAccuracy) scatters every shot
//   that goes through the precalculated roll, PerfectAccuracy and accuracy 1 included: the projectile
//   lands at the offset point as a ground shot (the TargetGround mode, 3), which deals the attack's
//   area damage where it lands. A stock miss (mode 2) deals no damage at all, area included.
// InstantBallistics and TargetGround shots, shots with no target unit and every shot while the cfg
// var ballisticPrecalcHits is off never reach that code (docs/how-it-works.md). The hooks are in
// hooks/spread_hooks.asm; the tags come through the shared action tag hook (actiontags.h).
#include <windows.h>

#include <cmath>
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <cwctype>
#include <map>
#include <string>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
constexpr float kStockFactor = 0.25f;              // [0xBA0AEC], read at 0x4CF00B
constexpr float kStockMax = 5.0f;                  // [0xBA0AF8] and the clamp at 0x4E2CE3
// Upper limits of the tags: a bigger offset could send a shot far off the map.
constexpr float kMaxFactor = 10.0f;
constexpr float kMaxSpread = 100.0f;
// Log limits.
constexpr unsigned kMaxValueLines = 200;     // "log": parsed values other than the stock ones
constexpr unsigned kMaxInvalidLines = 50;    // invalid values (always logged)
constexpr unsigned kShotLinesPerAction = 5;  // "log": offset shots per (proto, action)
constexpr unsigned kMaxShotLines = 100;

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Database() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

// ProtoAction names: [database+1FD8h] holds one UTF-16 string per name index, [+1FDCh] the count.
const wchar_t* ActionName(std::int32_t index) {
  const char* database = Database();
  if (database == nullptr || index < 0 || index >= Field<std::int32_t>(database, 0x1FDC)) {
    return L"?";
  }
  const wchar_t* name = Field<const wchar_t* const*>(database, 0x1FD8)[index];
  return name != nullptr ? name : L"?";
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name != nullptr ? name : "?";
}

// Every player's copy of a proto and of its actions keeps the proto ID [proto+4] and the action's
// name index [action+4], so this key finds the values from the copy a unit shoots with.
struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Spread {
  float factor = kStockFactor;
  float max = kStockMax;
};

// Filled while the data loads, read on the game thread at each miss; cleared on every data load.
std::map<ActionKey, Spread> g_spreads;
std::map<ActionKey, unsigned> g_shotLines;
std::string g_markerName = "AbstractSpreadAnyAccuracy";
std::int32_t g_markerType = -1;
bool g_log = false;
unsigned g_valueLines = 0;
unsigned g_valuesNotLogged = 0;
unsigned g_invalidLines = 0;
unsigned g_shotLinesTotal = 0;
bool g_loadReported = false;

// The projectile's hit result [projectile+20h] (written at 0x499899): 1 a sure hit on the target, 2 a
// miss (no damage at all), 3 a ground shot (the TargetGround mode: the attack is applied where the
// projectile lands, FUN_0049BE95 with no target).
constexpr std::int32_t kMiss = 2;
constexpr std::int32_t kGroundShot = 3;

// The shot being offset, between the hit hook or UhcSpreadSelect and UhcSpreadDone.
bool g_forced = false;  // a hit (the roll, or PerfectAccuracy without one); the shooter is marked
bool g_marked = false;  // the shooter is marked
bool g_tagged = false;
const char* g_shooter = nullptr;
ActionKey g_shotKey{-1, -1};

// The shooting unit's proto (the player's copy, [unit+5Ch]) has the marker type.
bool IsMarked(const char* shooter) {
  const char* proto = shooter == nullptr ? nullptr : Field<const char*>(shooter, 0x5C);
  return g_markerType >= 0 && proto != nullptr && kProtoIsType(proto, g_markerType);
}

// A float from 0 to limit, spaces around it allowed.
bool ParseValue(const wchar_t* text, float limit, float* out) {
  if (text == nullptr) {
    return false;
  }
  while (std::iswspace(*text)) {
    ++text;
  }
  wchar_t* end = nullptr;
  const float value = std::wcstof(text, &end);
  if (end == text) {
    return false;
  }
  while (std::iswspace(*end)) {
    ++end;
  }
  if (*end != L'\0' || !std::isfinite(value) || value < 0.0f || value > limit) {
    return false;
  }
  *out = value == 0.0f ? 0.0f : value;  // no -0
  return true;
}

void OnActionTag(const uhc::ActionTag& tag) {
  const bool isMax = _wcsicmp(tag.name, L"MaxSpread") == 0;
  if (!isMax && _wcsicmp(tag.name, L"SpreadFactor") != 0) {
    return;
  }
  const wchar_t* tagName = isMax ? L"MaxSpread" : L"SpreadFactor";
  const wchar_t* source = tag.source == uhc::ActionSource::kTactics ? L"tactics" : L"protoy";
  const ActionKey key{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)};
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  if (key.name < 0) {
    // Only possible in a tactics <action> whose <name> comes later; every known file has it
    // first, and the action has no name to key the value by yet.
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"spreadAnyAccuracy: %hs (%ls): <%ls> before the action's <name>; ignored (put <name> first)",
               ProtoName(tag.proto), source, tagName);
    }
    return;
  }
  float value = 0.0f;
  if (!ParseValue(tag.text, isMax ? kMaxSpread : kMaxFactor, &value)) {
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"spreadAnyAccuracy: %hs/%ls (%ls): <%ls>%ls</%ls> is not a number from 0 to %.0f; ignored",
               ProtoName(tag.proto), ActionName(key.name), source, tagName, text, tagName,
               static_cast<double>(isMax ? kMaxSpread : kMaxFactor));
    }
    return;
  }
  Spread& spread = g_spreads[key];
  (isMax ? spread.max : spread.factor) = value;
  // Most stock tactics files carry the stock values: "log" lists only the others.
  if (g_log && value != (isMax ? kStockMax : kStockFactor)) {
    if (g_valueLines < kMaxValueLines) {
      ++g_valueLines;
      uhc::Log(L"spreadAnyAccuracy: %hs/%ls (%ls): %ls %.2f", ProtoName(tag.proto), ActionName(key.name), source,
               tagName, static_cast<double>(value));
    } else {
      ++g_valuesNotLogged;
    }
  }
}

// From the database load hook (unittypes.h), before the protos' contents (their tactics files and
// <ProtoAction> children) are read: every load reads the tags again.
void ResetForDataLoad(char*) {
  g_spreads.clear();
  g_shotLines.clear();
  g_valueLines = 0;
  g_valuesNotLogged = 0;
  g_invalidLines = 0;
  g_shotLinesTotal = 0;
  g_loadReported = false;
}

// Once per data load, at the first miss: how many actions carry the tags.
void ReportLoad() {
  if (g_loadReported) {
    return;
  }
  g_loadReported = true;
  unsigned changed = 0;
  for (const auto& [key, spread] : g_spreads) {
    changed += spread.factor != kStockFactor || spread.max != kStockMax ? 1 : 0;
  }
  wchar_t more[64] = L"";
  if (g_valuesNotLogged > 0) {
    swprintf_s(more, L"; %u more values not logged", g_valuesNotLogged);
  }
  uhc::Log(L"spreadAnyAccuracy: %u action(s) of this data carry <MaxSpread> or <SpreadFactor>, %u of them with "
           L"values other than the stock 5.0 and 0.25%ls",
           static_cast<unsigned>(g_spreads.size()), changed, more);
}

}  // namespace

extern "C" {
// Read by the radius hook inside FUN_004CEF8C; the stock values except during a miss hook's call.
float g_uhcSpreadFactor = kStockFactor;
float g_uhcSpreadMax = kStockMax;
float g_uhcSpreadRadius = -1.0f;

void UhcSpreadHitHook();
void UhcSpreadMissHook();
void UhcSpreadRadiusHook();

// The hit hook, for a shot the roll did not make a miss: true if the shooting unit is marked, so
// that the shot takes the miss stub too.
bool __stdcall UhcSpreadForceMiss(const char* shooter, const char*) {
  g_forced = IsMarked(shooter);
  return g_forced;
}

// The miss hook, before the stock offset: the shooting action's values, from the unit action
// [unitAction+4] (the player's copy of the action) and the shooting unit's proto.
void __stdcall UhcSpreadSelect(const char* unitAction, const char* shooter) {
  g_uhcSpreadFactor = kStockFactor;
  g_uhcSpreadMax = kStockMax;
  g_uhcSpreadRadius = -1.0f;
  g_tagged = false;
  g_shooter = shooter;
  g_marked = g_forced || IsMarked(shooter);
  ReportLoad();
  const char* action = unitAction == nullptr ? nullptr : Field<const char*>(unitAction, 0x04);
  const char* proto = shooter == nullptr ? nullptr : Field<const char*>(shooter, 0x5C);
  g_shotKey = {proto == nullptr ? -1 : Field<std::int32_t>(proto, 0x04),
               action == nullptr ? -1 : Field<std::int32_t>(action, 0x04)};
  if (proto == nullptr || action == nullptr || g_spreads.empty()) {
    return;
  }
  const auto it = g_spreads.find(g_shotKey);
  if (it != g_spreads.end()) {
    g_uhcSpreadFactor = it->second.factor;
    g_uhcSpreadMax = it->second.max;
    g_tagged = true;
  }
}

// The miss hook, after the stock offset: the log, then the stock values back. Returns the hit result
// the launch stores in [projectile+20h]: 2, a miss, which deals no damage; 3 for a marked unit, a
// ground shot (the TargetGround mode), which deals the attack where it lands.
std::int32_t __stdcall UhcSpreadDone() {
  if (g_log && g_shotLinesTotal < kMaxShotLines) {
    unsigned& lines = g_shotLines[g_shotKey];
    if (lines < kShotLinesPerAction) {
      ++lines;
      ++g_shotLinesTotal;
      const char* proto = g_shooter == nullptr ? nullptr : Field<const char*>(g_shooter, 0x5C);
      wchar_t radius[48] = L"no offset (FUN_004CEF8C found no target)";
      if (g_uhcSpreadRadius >= 0.0f) {
        swprintf_s(radius, L"r = %.2f m", static_cast<double>(g_uhcSpreadRadius));
      }
      uhc::Log(L"spreadAnyAccuracy: shot by unit %d (%hs/%ls): %ls, %ls (SpreadFactor %.2f, MaxSpread %.2f%ls)",
               g_shooter == nullptr ? -1 : Field<std::int32_t>(g_shooter, 0x10), ProtoName(proto),
               ActionName(g_shotKey.name),
               !g_marked  ? L"a miss"
               : g_forced ? L"marked unit, a hit made a ground shot at the offset point"
                          : L"marked unit, a miss made a ground shot at the offset point",
               radius, static_cast<double>(g_uhcSpreadFactor), static_cast<double>(g_uhcSpreadMax),
               g_tagged ? L"" : L", stock values");
    }
  }
  g_uhcSpreadFactor = kStockFactor;
  g_uhcSpreadMax = kStockMax;
  const bool marked = g_marked;
  g_forced = false;
  g_marked = false;
  return marked ? kGroundShot : kMiss;
}
}

namespace uhc {

Outcome ApplySpreadAnyAccuracy(const Config& config) {
  const Config::Args* args = config.First("spreadAnyAccuracy");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool typeGiven = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (!typeGiven) {
      g_markerName = arg;
      typeGiven = true;
    } else {
      Log(L"spreadAnyAccuracy: unexpected argument %hs (expected: [UnitType] [log]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }
  // The hit hook jumps straight to the miss hook, and the miss hook relies on the radius hook: all
  // three are written, or none.
  if (!VerifyAll("spreadAnyAccuracy", {&sites::kSpreadHitRoll, &sites::kSpreadMissStub, &sites::kSpreadRadius,
                                       &sites::kSpreadDraws, &sites::kIsA}) ||
      !RequestAbstractUnitType(g_markerName.c_str(), &g_markerType) || !OnDatabaseLoad(&ResetForDataLoad) ||
      !AddActionTagHandler(&OnActionTag)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kSpreadRadius.va, reinterpret_cast<const void*>(&UhcSpreadRadiusHook), 27) ||
      !WriteJmp(sites::kSpreadMissStub.va, reinterpret_cast<const void*>(&UhcSpreadMissHook), 7) ||
      !WriteJmp(sites::kSpreadHitRoll.va, reinterpret_cast<const void*>(&UhcSpreadHitHook), 9)) {
    return Outcome::kFailed;
  }
  Log(L"spreadAnyAccuracy: <MaxSpread> and <SpreadFactor> are read per action (stock 5.0 and 0.25) and every "
      L"miss uses them; units of unittype %hs scatter every precalculated shot%ls (multiplayer unverified)",
      g_markerName.c_str(), g_log ? L"; values and shots logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/spread_hooks.asm

```asm
; Hooks for spreadAnyAccuracy (features/spread.cpp). Each is entered through a jmp written over the
; stock code and leaves through an explicit jmp to a verified continuation (docs/engine-symbols.md,
; "Projectile accuracy and spread"). The tags are read through the shared action tag hook
; (actiontag_hooks.asm).
.686
.model flat, c
option casemap :none

include common.inc

UhcSpreadForceMiss PROTO STDCALL :DWORD, :DWORD
UhcSpreadSelect PROTO STDCALL :DWORD, :DWORD
UhcSpreadDone PROTO STDCALL            ; returns the hit result to store: 2 or 3

EXTERNDEF g_uhcSpreadFactor:DWORD       ; float: SpreadFactor of the shot being offset (stock 0.25)
EXTERNDEF g_uhcSpreadMax:DWORD          ; float: MaxSpread of the shot being offset (stock 5.0)
EXTERNDEF g_uhcSpreadRadius:DWORD       ; float: the radius the offset used, for the log

.data
afterRoll           dd 00499899h    ; mov [esi+20h],ebx: the projectile's hit result
missOffsetFn        dd 004CEF8Ch    ; FUN_004CEF8C, bool thiscall(projectile, Vector* point), ret 4
radiusCheck         dd 004CF026h    ; fld [esp+0Ch] / fcomp [1e-6]: the stock "r > 0" test

.code

; Replaces cmp ebx,2 / je 4CEF7Bh (9 bytes) at 0x499890 in the projectile launch, after the
; precalculated roll (EBX = 1 hit, 2 miss) and the target leading 0x4A5B02. ESI = the projectile,
; EDI = the shooting (tactics) action, [esp+18h] = the unit action, [esp+0E8h] = the shooting unit,
; [esp+28h] = the impact point. A miss goes on to the miss stub as in stock; any other result
; (a hit, or PerfectAccuracy's 1) of a unit whose proto has the marker type goes there too with
; EBX = 2, and the miss hook then makes it a ground shot. EAX, ECX, EDX and the flags are free on
; both continuations: 0x499899 stores EBX and overwrites them before reading them
; (mov [esi+20h],ebx / mov ebx,[esp+18h] / mov edi,[esp+0ECh] / mov ecx,[esp+10h] / ... /
; test eax,eax), and the miss stub calls FUN_004CEF8C, which clobbers them.
UhcSpreadHitHook PROC
    TRACE_ONCE "spreadAnyAccuracy hit roll (0x499890)"
    cmp ebx, 2                          ; stolen 0x499890
    je UhcSpreadMissHook                ; stolen 0x499893: je 4CEF7Bh (the stub this file replaces)
    pushad
    push edi                            ; the shooting action
    push dword ptr [esp+24h+0E8h]       ; the shooting unit
    call UhcSpreadForceMiss             ; AL = 1: scatter this shot
    test al, al
    popad                               ; keeps the flags
    jne forced
    jmp afterRoll
forced:
    mov ebx, 2                          ; a miss: [projectile+20h] = 2 at 0x499899
    jmp UhcSpreadMissHook
UhcSpreadHitHook ENDP

; Replaces lea eax,[esp+28h] / push eax / mov ecx,esi (7 bytes) at 0x4CEF7B, the stub every miss
; reaches (from 0x499893, now this file's hit hook, and from the failed lead at 0x6A4BCA, both with
; EBX = 2). The stub's stock code is call 4CEF8Ch / jmp 499899h; the hook makes that call itself,
; with the shooting action's SpreadFactor and MaxSpread in the two globals the radius hook reads,
; then puts the stock values back. For a marked shooter EBX becomes 3, the TargetGround mode, so the
; projectile deals its attack where it lands (a miss, 2, deals none). Same frame as the hit hook.
; FUN_004CEF8C keeps EBX, ESI, EDI and EBP (it saves them), and the stock call already clobbered
; EAX, ECX and EDX.
UhcSpreadMissHook PROC
    TRACE_ONCE "spreadAnyAccuracy miss offset (0x4CEF7B)"
    pushad
    push dword ptr [esp+20h+0E8h]       ; the shooting unit
    push dword ptr [esp+24h+18h]        ; the unit action
    call UhcSpreadSelect
    popad
    lea eax, dword ptr [esp+28h]        ; stolen 0x4CEF7B: the impact point
    push eax
    mov ecx, esi                        ; the projectile
    call missOffsetFn                   ; stock 0x4CEF82
    pushad
    call UhcSpreadDone                  ; the log; the stock values back; EAX = the hit result
    mov dword ptr [esp+10h], eax        ; popad's EBX: 2, or 3 (a ground shot) for a marked unit
    popad
    jmp afterRoll                       ; stock 0x4CEF87: jmp 499899h
UhcSpreadMissHook ENDP

; Replaces fmul [0BA0AECh] (0.25) / fst [esp+0Ch] / fcomp [0BA0AF8h] (5.0) / fnstsw ax / test ah,41h /
; je 4E2CE3h (27 bytes) at 0x4CF00B in FUN_004CEF8C, with ST0 = d, the 2D distance from the
; projectile to the impact point (or 1.0 without a projectile unit, from 0x4E2CFD). It computes
; r = min(d * g_uhcSpreadFactor, g_uhcSpreadMax) into [esp+0Ch] as the stock code does with 0.25 and
; 5.0, and continues at the stock "r > 1e-6" test, so the two random draws uniform(-r, r) stay the
; stock code's. The stock clamp at 0x4E2CE3 skipped that test, which only matters for a MaxSpread
; of 0: then nothing is drawn, as for a stock r of 0. The x87 stack is empty on leaving, as after the
; stock fcomp; EAX is free (the test overwrites AX with fnstsw).
UhcSpreadRadiusHook PROC
    fmul dword ptr [g_uhcSpreadFactor]
    fst dword ptr [esp+0Ch]
    fcomp dword ptr [g_uhcSpreadMax]
    fnstsw ax
    TRACE_ONCE "spreadAnyAccuracy miss radius (0x4CF00B)" ; after the fcomp: the x87 stack is empty
    test ah, 41h
    jne notAbove                        ; r <= MaxSpread (or unordered)
    mov eax, g_uhcSpreadMax
    mov dword ptr [esp+0Ch], eax
notAbove:
    mov eax, dword ptr [esp+0Ch]
    mov g_uhcSpreadRadius, eax
    jmp radiusCheck
UhcSpreadRadiusHook ENDP

END
```

## accuracyTechs

Contract: [accuracyTechs](../porting-to-another-dll.md#accuracytechs).

Besides the core helpers, it needs: [`techsubtypes.h`](helpers.md#tech-subtypes).

### src/features/accuracy.cpp

```cpp
// accuracyTechs: a tech effect type="Data" subtype="Accuracy" changes an action's <Accuracy>.
//
// Stock keeps the tag in the action's [+38h], default 1, and reads it at the projectile launch: the
// hit chance is accuracy x 100 - d / 2, d the distance. No Data subtype reaches the field, so the
// effect is a new one on the action (techsubtypes.h), applied through the stock value function 0x7F892A,
// which gives it every relativity and its removal.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../log.h"
#include "../techsubtypes.h"

namespace {

constexpr std::size_t kAccuracy = 0x38;
constexpr int kMaxLogLines = 200;

using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);

bool g_log = false;
int g_logLines = 0;

void ChangeAccuracy(char* action, const char* baseAction, float amount, std::uint8_t relativity, bool unapply) {
  auto* value = reinterpret_cast<float*>(action + kAccuracy);
  const float before = *value;
  const float base = baseAction != nullptr ? *reinterpret_cast<const float*>(baseAction + kAccuracy) : 1.0f;
  kEffectValue(relativity, value, base, amount, unapply);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"accuracyTechs: action %d, relativity %u, amount %g%ls: %g -> %g",
             *reinterpret_cast<const std::int32_t*>(action + 4), relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", static_cast<double>(before), static_cast<double>(*value));
  }
}

}  // namespace

namespace uhc {

Outcome ApplyAccuracyTechs(const Config& config) {
  const Config::Args* args = config.First("accuracyTechs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"accuracyTechs: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!AddTechActionSubtype("Accuracy", &ChangeAccuracy)) {
    return Outcome::kFailed;
  }
  Log(L"accuracyTechs: the Data subtype Accuracy is on");
  return Outcome::kApplied;
}

}  // namespace uhc
```

## broadsideMuzzleLimit

Contract: [broadsideMuzzleLimit](../porting-to-another-dll.md#broadsidemuzzlelimit).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `BroadsideInitHead` `0x50339A` (53 B), `BroadsideMuzzleCap` `0x5033CF` (17 B), `BroadsideMuzzleClampR` `0x503447` (12 B), `BroadsideMuzzleReload` `0x5034B3` (13 B), `BroadsideMuzzleClampL` `0x5034E2` (12 B), `BroadsideSingleUseCap` `0x6A8236` (17 B), `BroadsideClampCold` `0x6A8247` (22 B).

### src/features/broadside.cpp

```cpp
// broadsideMuzzleLimit: more cannons per side in a ship's broadside.
//
// A BroadsideAttack action (protoaction type 29h: the normal ranged attack of most ships, and the
// actions of PowerBroadside and the ironclad's long-range power) gives each muzzle of its owner's
// model a firing slot when the action is set up, in FUN_0050339A: one slot per MuzzleR attach
// point, then one per MuzzleL point. Each group is clamped to 6 (`mov esi,6` at 0x5033D5), or to
// 1 when the action has <SingleUsePlayer> (cold block 0x6A8236). A volley fires one projectile per
// slot, so a stock ship fires at most 6 per side whatever its model has (the Tekkousen's has 10).
//
// broadsideMuzzleLimit <N> [<UnitType>] [log] replaces the 6 with N (1..255: the muzzle index is
// passed on as a byte) for ships whose proto has <UnitType> (a marker, a stock type or a proto
// name), or for every ship when no type is given. The model still decides how many muzzles there
// are, and <SingleUsePlayer> actions keep 1. The hooks are in hooks/broadside_hooks.asm.
#include <charconv>
#include <cstdint>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr int kMinLimit = 1;
constexpr int kMaxLimit = 255;  // 0x4A98F8 reads the muzzle index of a slot as a byte
constexpr int kMaxLogLines = 500;

int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* ProtoName(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

bool ParseLimit(const std::string& text, std::int32_t* limit) {
  int value = 0;
  const auto [end, ec] = std::from_chars(text.data(), text.data() + text.size(), value);
  if (ec != std::errc() || end != text.data() + text.size() || value < kMinLimit || value > kMaxLimit) {
    return false;
  }
  *limit = value;
  return true;
}

}  // namespace

extern "C" {
std::int32_t g_uhcBroadsideType = -1;    // marker unittype ID, set on each database load
std::int32_t g_uhcBroadsideAll = 0;      // 1 when no UnitType is given: every ship
std::int32_t g_uhcBroadsideLimit = 6;    // muzzles per side
const char* g_uhcBroadsideAction = nullptr;  // the action whose limit the hook set last (for "log")

void UhcBroadsideLimitHook();
void UhcBroadsideLogHook();

// Called by the log hook at the MuzzleL clamp of an action whose limit the first hook set:
// [action+80h] already holds its MuzzleR slots; leftMuzzles is the model's MuzzleL count (0 or -1
// without a model) and limit the clamp it is about to get. An action is set up when it is created,
// but the lines are capped in case something sets actions up far more often.
void __stdcall UhcBroadsideLogSetup(const char* action, std::int32_t leftMuzzles, std::int32_t limit) {
  if (g_logLines > kMaxLogLines) {
    return;
  }
  if (++g_logLines > kMaxLogLines) {
    uhc::Log(L"broadsideMuzzleLimit: %d broadside set-ups logged; the next ones are not", kMaxLogLines);
    return;
  }
  const char* unit = Field<const char*>(action, 0x10);
  const std::int32_t left = leftMuzzles <= 0 ? 0 : (leftMuzzles < limit ? leftMuzzles : limit);
  uhc::Log(L"broadsideMuzzleLimit: unit %d (%hs) has %d right and %d left muzzle slots (limit %d per side)",
           unit == nullptr ? -1 : Field<std::int32_t>(unit, 0x10), ProtoName(unit), Field<std::int32_t>(action, 0x80),
           left, limit);
}
}

namespace uhc {

Outcome ApplyBroadsideMuzzleLimit(const Config& config) {
  const auto* lines = config.All("broadsideMuzzleLimit");
  if (lines == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (lines->size() != 1) {
    Log(L"broadsideMuzzleLimit: %u lines, expected one; feature not applied", static_cast<unsigned>(lines->size()));
    return Outcome::kFailed;
  }
  const Config::Args& args = lines->front();
  std::int32_t limit = 0;
  if (args.empty() || !ParseLimit(args.front(), &limit)) {
    Log(L"broadsideMuzzleLimit: expected \"broadsideMuzzleLimit <N> [UnitType] [log]\" with N from %d to %d, "
        L"got \"%hs\"; feature not applied",
        kMinLimit, kMaxLimit, args.empty() ? "" : args.front().c_str());
    return Outcome::kFailed;
  }
  std::string typeName;
  bool log = false;
  for (std::size_t i = 1; i < args.size(); ++i) {
    if (_stricmp(args[i].c_str(), "log") == 0) {
      log = true;
    } else if (typeName.empty()) {
      typeName = args[i];
    } else {
      Log(L"broadsideMuzzleLimit: unexpected argument %hs (expected: <N> [UnitType] [log]); feature not applied",
          args[i].c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("broadsideMuzzleLimit",
                 {&sites::kBroadsideInitHead, &sites::kBroadsideMuzzleCap, &sites::kBroadsideMuzzleClampR,
                  &sites::kBroadsideMuzzleReload, &sites::kBroadsideMuzzleClampL, &sites::kBroadsideSingleUseCap,
                  &sites::kBroadsideClampCold})) {
    return Outcome::kFailed;
  }

  g_uhcBroadsideLimit = limit;
  g_uhcBroadsideAll = typeName.empty() ? 1 : 0;
  if (!typeName.empty() && !RequestAbstractUnitType(typeName.c_str(), &g_uhcBroadsideType)) {
    return Outcome::kFailed;
  }
  // mov esi,6 at 0x5033D5, six bytes into the site.
  if (!WriteJmp(sites::kBroadsideMuzzleCap.va + 6, reinterpret_cast<const void*>(&UhcBroadsideLimitHook), 5)) {
    return Outcome::kFailed;
  }
  // The MuzzleL clamp, cmp eax,esi / mov [esp+1Ch],eax (6 bytes) before the jg at 0x5034E8.
  if (log && !WriteJmp(sites::kBroadsideMuzzleClampL.va, reinterpret_cast<const void*>(&UhcBroadsideLogHook), 6)) {
    return Outcome::kFailed;
  }
  if (typeName.empty()) {
    Log(L"broadsideMuzzleLimit: every ship uses up to %d muzzles per side in a broadside (stock 6; "
        L"SingleUsePlayer attacks keep 1)%ls (multiplayer unverified)",
        limit, log ? L", every set-up logged" : L"");
  } else {
    Log(L"broadsideMuzzleLimit: ships of unittype %hs use up to %d muzzles per side in a broadside (stock 6; "
        L"SingleUsePlayer attacks keep 1)%ls (multiplayer unverified)",
        typeName.c_str(), limit, log ? L", every set-up logged" : L"");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/broadside_hooks.asm

```asm
; Hooks for broadsideMuzzleLimit. Entered through a jmp written over the stock code; each leaves
; through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Broadside attacks").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcBroadsideType:SDWORD     ; marker unittype ID, set on each database load; -1 before
EXTERNDEF g_uhcBroadsideAll:DWORD       ; 1 when no UnitType is given: every ship gets the limit
EXTERNDEF g_uhcBroadsideLimit:DWORD     ; muzzles per side, 1..255
EXTERNDEF g_uhcBroadsideAction:DWORD    ; the action whose limit the hook set last, else 0

UhcBroadsideLogSetup PROTO STDCALL action:DWORD, leftMuzzles:DWORD, limit:DWORD

.data
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): proto IDs and abstract types
limitNext       dd 005033DAh    ; mov [esp+0Ch],esi (the limit, kept in a local) / je 503424h
clampLNext      dd 005034E8h    ; jg 6A8252h: more MuzzleL points than the limit -> count = limit

.code

; Replaces 0x5033D5 (mov esi,6) in FUN_0050339A, the set-up of a BroadsideAttack action, where ESI
; becomes the most muzzles per side that get a firing slot. EDI = the action; its owner unit
; [edi+10h] and the owner's proto were tested non-null, and the proto is a Ship (0x5033AA..0x5033C9).
; ECX = [edi+4], the proto action, and ZF comes from its test at 0x5033D2: the je at 0x5033DE and
; the mov edx,ecx at 0x5033E9 read them. The caller's ESI is already pushed (0x5033D4); EAX and EDX
; are written before they are read on both paths. A marked owner (or any ship, without a UnitType)
; gets the configured limit; any other owner keeps the stock 6. A <SingleUsePlayer> action still
; drops it to 1 after the continuation (0x5033E0 / 0x6A8236).
UhcBroadsideLimitHook PROC
    TRACE_ONCE "broadsideMuzzleLimit (0x5033D5)"
    mov esi, 6                      ; stolen 0x5033D5: the stock limit
    mov g_uhcBroadsideAction, 0
    cmp g_uhcBroadsideAll, 0
    jne setLimit
    cmp g_uhcBroadsideType, 0
    jl done                         ; marker not resolved yet: stock
    push ecx                        ; the proto action, read again after the continuation
    mov ecx, dword ptr [edi+10h]    ; owner unit
    test ecx, ecx
    je restore
    mov ecx, dword ptr [ecx+5Ch]    ; owner proto
    test ecx, ecx
    je restore
    push g_uhcBroadsideType
    call protoIsType                ; saves ESI; clobbers only EAX, ECX, EDX
    test al, al
    je restore
    pop ecx
setLimit:
    mov esi, g_uhcBroadsideLimit
    mov g_uhcBroadsideAction, edi
    jmp done
restore:
    pop ecx
done:
    test ecx, ecx                   ; the stock ZF of 0x5033D2, for the je at 0x5033DE
    jmp limitNext
UhcBroadsideLimitHook ENDP

; Replaces 0x5034E2..0x5034E7 (cmp eax,esi / mov [esp+1Ch],eax) in the same function, only with
; "log": the MuzzleL clamp. EAX = the MuzzleL points of the owner's model, ESI = the limit (1 for a
; <SingleUsePlayer> action), EDI = the action, whose MuzzleR slots are already counted in
; [edi+80h] (0x5034BA). For the action the hook above gave the configured limit, logs the set-up,
; then re-executes both instructions: the jg at 0x5034E8 reads the flags of the compare.
UhcBroadsideLogHook PROC
    TRACE_ONCE "broadsideMuzzleLimit log (0x5034E2)"
    cmp edi, g_uhcBroadsideAction
    jne stock
    pushad
    push esi                        ; the limit
    push eax                        ; MuzzleL points
    push edi                        ; the action
    call UhcBroadsideLogSetup
    popad
    mov g_uhcBroadsideAction, 0
stock:
    cmp eax, esi                    ; stolen 0x5034E2
    mov dword ptr [esp+1Ch], eax    ; stolen 0x5034E4: the MuzzleL count, in the argument slot
    jmp clampLNext
UhcBroadsideLogHook ENDP

END
```

## snareOnlyHitUnit

Contract: [snareOnlyHitUnit](../porting-to-another-dll.md#snareonlyhitunit).

Besides the core helpers, it needs: [`modifiers.h`](helpers.md#modifier-walk).

Sites: `SnareVelocityGetter` `0x487E27` (77 B), `SnareVelocityRecord` `0x488612` (30 B), `SnareCollector` `0x49F34B` (121 B), `SnareModifierSum` `0x4B3C48` (183 B), `SnareModifierInit` `0x4B3D44` (90 B), `SnareCreate` `0x4DD201` (44 B), `SnareModifierSumEnd` `0x4E2A8E` (27 B), `SnareUnitById` `0x4F9EB7` (68 B), `SnareSlotWait` `0x4FA172` (21 B), `SnareGroupPace` `0x4FD3FD` (29 B), `SnareGroupPaceStore` `0x4FD53A` (20 B), `SnareModifierSumTactic` `0x6A88D6` (34 B), `SnarePathWait` `0x6AA510` (13 B), `SnarePathCheck` `0x6AA537` (62 B).

### src/features/snare.cpp

```cpp
// snareOnlyHitUnit: a snared unit no longer slows the group it moves with.
//
// Stock: an attack whose tactics action has <TargetSpeedBoost> gives its target a velocity
// modifier (0x48FA07 -> 0x4DD1DE -> 0x4DD22D -> 0x4B3D9E): a unit action of type 2Ch that
// multiplies the velocity by 0.65 for 3000 ms and is exclusive. The target's max velocity (unit
// vtable slot 34h, 0x487E27) drops to 0.65x. A unit in a group does not set its own speed:
// 0x49F3D0 only marks the group dirty, and the group recompute FUN_004FD289 sets the group's pace
// [group+7Ch] to the slowest member's velocity, the snared one included. The group, and every
// member with it, then moves at 0.65x for 3 s. A member that falls more than 2.0 behind its
// formation slot also sets group bit 7 (0x4FA17D; 0x6AA514 and 0x6AA56A for a member with its own
// path), and the group then moves at 0.8333x its pace (0x4FAAA5) until the member is back.
//
// snareOnlyHitUnit: in the group recompute, a member with an active snare counts with its
// velocity without the snare (the stock modifier sum replayed with the snares left out); and
// while the snare lasts, the member does not set bit 7. The snared unit keeps its own 0.65x: a
// member never walks faster than its own velocity (0x4F9BCB). When the snare ends, the stock rule
// applies again: a unit still more than 2.0 behind its slot makes the group wait for it at
// 0.8333x. The hooks are in hooks/snare_hooks.asm.
#include <cstdint>
#include <cstring>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifiers.h"
#include "../patch.h"

namespace {

using uhc::modifiers::ModifierList;
using uhc::modifiers::Walk;
using uhc::modifiers::WalkModifiers;

// Engine layout (docs/engine-symbols.md, "Snare and group movement").
constexpr std::uint32_t kGameGlobal = 0x00C66234;      // game; +13Ch world
constexpr std::uint32_t kMovementModIdPtr = 0x00CEFFA0;  // -> the ID of the cfg float MovementMod
constexpr std::uint32_t kGameConfig = 0x00C66500;       // the game's cfg values

constexpr std::int32_t kStatVelocity = 0;
constexpr std::int32_t kOpSet = 0;
constexpr std::int32_t kOpAdd = 1;
constexpr std::int32_t kOpMultiply = 2;
constexpr std::uint32_t kFlagTimed = 0x15;      // the modifier has a duration (0x4B3D6D)
constexpr std::uint32_t kFlagExclusive = 0x16;  // the modifier sum stops after it (0x4B3CDA)
constexpr std::uint32_t kTacticModifyExclusive = 33;  // the same, from <ModifyExclusive> (0x6A88D6)
constexpr float kNoVelocityRecord = -1.0e-6f;   // 0xB9FB60: the per-unit velocity is unset

using GetVelocityFn = float(__thiscall*)(const char* unit);
using CfgFloatFn = bool(__thiscall*)(void* config, std::int32_t id, float* value);
const auto kCfgFloat = reinterpret_cast<CfgFloatFn>(0x0044734C);

bool g_log = false;  // "snareOnlyHitUnit log": log each snared member once per snare
// Unit ID -> the snare last logged for it, one map per log line.
std::unordered_map<std::int32_t, const char*> g_loggedPace;
std::unordered_map<std::int32_t, const char*> g_loggedWait;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// A bitset {bytes at +0, bit count at +4} at `offset` in an object, read like 0x4B3CDA does.
bool Bit(const char* object, std::uint32_t offset, std::uint32_t bit) {
  if (Field<std::uint32_t>(object, offset + 4) <= bit) {
    return false;
  }
  const auto* bytes = Field<const std::uint8_t*>(object, offset);
  return bytes != nullptr && (bytes[bit >> 3] & (1u << (bit & 7))) != 0;
}

// The snare of 0x4DD1DE: a velocity modifier that multiplies, has a duration and is exclusive.
// The only other timed creator, <SpeedBoost> (0x4B3E31), is not exclusive; the untimed ones
// (auras, <ModifyExclusive> auras included) have no duration flag.
bool IsSnare(const char* action) {
  return Field<std::int32_t>(action, 0x64) == kStatVelocity && Field<std::int32_t>(action, 0x78) == kOpMultiply &&
         Bit(action, 0x30, kFlagTimed) && Bit(action, 0x30, kFlagExclusive);
}

// The first active snare on the unit, or nullptr. A tree deeper than modifiers::kMaxDepth counts
// as "not snared", which runs the stock code.
const char* FindSnare(const char* unit) {
  const char* list = unit == nullptr ? nullptr : ModifierList(unit);
  if (list == nullptr || Field<const char*>(unit, 0x5C) == nullptr) {
    return nullptr;
  }
  const char* snare = nullptr;
  auto visit = [&snare](const char* action) {
    if (IsSnare(action)) {
      snare = action;
      return false;
    }
    return true;
  };
  return WalkModifiers(list, visit, 0) == Walk::kStopped ? snare : nullptr;
}

// The unit's max velocity as 0x487E27 returns it, with the snares left out of the modifier sum
// 0x4B3C48 / 0x4B3C7D. False if the action tree is deeper than modifiers::kMaxDepth.
bool VelocityWithoutSnares(const char* unit, float* velocity) {
  const float base = Field<float>(Field<const char*>(unit, 0x5C), 0x80);  // proto MaxVelocity
  float sum = base;
  bool matched = false;
  auto visit = [&sum, &matched](const char* action) {
    if (Field<std::int32_t>(action, 0x64) != kStatVelocity || IsSnare(action)) {
      return true;
    }
    matched = true;
    const float value = Field<float>(action, 0x68);
    switch (Field<std::int32_t>(action, 0x78)) {
      case kOpSet:
        sum = value;
        break;
      case kOpAdd:
        sum = value + sum;
        break;
      case kOpMultiply:
        sum = value * sum;
        break;
      default:  // 0x4E2AA2: any other operation is ignored
        break;
    }
    if (Bit(action, 0x30, kFlagExclusive)) {
      return false;
    }
    const char* tactic = Field<const char*>(action, 0x04);
    return tactic == nullptr || !Bit(tactic, 0x64, kTacticModifyExclusive);
  };
  if (WalkModifiers(ModifierList(unit), visit, 0) == Walk::kTooDeep) {
    return false;
  }
  // 0x4B3C48 stores the sum in the unit's record [[unit+B4h]+C8h] only when a modifier matched;
  // 0x487E27 reads the record when it is above -1e-6, the proto's MaxVelocity otherwise, and
  // multiplies by the cfg float MovementMod (1.0 when it is not set).
  const char* ext = Field<const char*>(unit, 0xB4);
  const bool hasRecord = ext != nullptr && Field<const char*>(ext, 0xC8) != nullptr;
  const float own = hasRecord && matched && sum > kNoVelocityRecord ? sum : base;
  float movementMod = 1.0f;
  kCfgFloat(reinterpret_cast<void*>(kGameConfig), **reinterpret_cast<const std::int32_t* const*>(kMovementModIdPtr),
            &movementMod);
  *velocity = movementMod * own;
  return true;
}

float StockVelocity(const char* unit) {
  return (*reinterpret_cast<GetVelocityFn* const*>(unit))[0x34 / 4](unit);
}

std::int32_t UnitId(const char* unit) { return Field<std::int32_t>(unit, 0x10); }

// A unit's proto is at [unit+5Ch]; its name, for the log, at [proto+10h].
const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

// True the first time this snare is seen for this unit.
bool FirstForSnare(std::unordered_map<std::int32_t, const char*>* seen, const char* unit, const char* snare) {
  auto [it, inserted] = seen->try_emplace(UnitId(unit), snare);
  if (!inserted && it->second == snare) {
    return false;
  }
  it->second = snare;
  return true;
}

// Units by ID: [world+0Ch] array, [world+10h] count; the low 18 bits index the array and
// [unit+10h] must equal the full ID (the lookup at 0x4F9EB7).
const char* UnitById(std::int32_t id) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && UnitId(unit) == id ? unit : nullptr;
}

// "log": a unit seen without a snare forgets the one it had, so a later snare is logged even when
// the engine allocates it at the same address.
void ForgetSnare(const char* unit) {
  g_loggedPace.erase(UnitId(unit));
  g_loggedWait.erase(UnitId(unit));
}

bool SkipsWait(const char* member, std::uint32_t site) {
  const char* snare = FindSnare(member);
  if (snare == nullptr) {
    if (g_log) {
      ForgetSnare(member);
    }
    return false;
  }
  if (g_log && FirstForSnare(&g_loggedWait, member, snare)) {
    uhc::Log(L"snareOnlyHitUnit: unit %d (%hs) is snared and lags behind its formation slot; its group does not "
             L"wait for it (0x%06X)",
             UnitId(member), ProtoName(member), site);
  }
  return true;
}

}  // namespace

extern "C" {
void UhcSnareGroupPaceHook();
void UhcSnareSlotWaitHook();
void UhcSnarePathWaitHook();
void UhcSnarePathCheckHook();

// Group recompute (0x4FD3FD): for a member with an active snare, lowers the group's pace
// [group+7Ch] to the member's velocity without the snare, as the stock code does with its
// velocity, and returns true. False: the hook runs the stock compare.
bool __stdcall UhcSnareGroupPace(const char* member, char* group) {
  const char* snare = FindSnare(member);
  float velocity = 0.0f;
  if (snare == nullptr && g_log) {
    ForgetSnare(member);
  }
  if (snare == nullptr || !VelocityWithoutSnares(member, &velocity)) {
    return false;
  }
  // A float compare of the rounded value gives the stock result (an extended-precision fcomp,
  // then fstp): the same decision and the same stored float.
  float* pace = reinterpret_cast<float*>(group + 0x7C);
  if (velocity < *pace) {
    *pace = velocity;
  }
  if (g_log && FirstForSnare(&g_loggedPace, member, snare)) {
    uhc::Log(L"snareOnlyHitUnit: unit %d (%hs) is snared; it counts %.3f instead of %.3f toward its group's pace",
             UnitId(member), ProtoName(member), velocity, StockVelocity(member));
  }
  return true;
}

// Straggler checks 0x4FA17D and 0x6AA514: true if the member is snared, so the group must not
// wait for it.
bool __stdcall UhcSnareSkipsWait(const char* member, std::uint32_t site) { return SkipsWait(member, site); }

// Straggler check 0x6AA56A, where only the member's ID is left in a register.
bool __stdcall UhcSnareSkipsWaitById(std::int32_t memberId) {
  const char* member = UnitById(memberId);
  return member != nullptr && SkipsWait(member, 0x6AA56A);
}
}

namespace uhc {

Outcome ApplySnareOnlyHitUnit(const Config& config) {
  const Config::Args* args = config.First("snareOnlyHitUnit");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"snareOnlyHitUnit: unknown argument %hs (expected: log); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  // The hook sites and their continuations, then the stock code the helpers mirror.
  if (!VerifyAll("snareOnlyHitUnit",
                 {&sites::kSnareGroupPace, &sites::kSnareGroupPaceStore, &sites::kSnareSlotWait,
                  &sites::kSnarePathWait, &sites::kSnarePathCheck, &sites::kSnareCreate, &sites::kSnareModifierInit,
                  &sites::kSnareCollector, &sites::kSnareModifierSum, &sites::kSnareModifierSumEnd,
                  &sites::kSnareModifierSumTactic, &sites::kSnareVelocityGetter, &sites::kSnareVelocityRecord,
                  &sites::kSnareUnitById})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kSnareGroupPace.va, reinterpret_cast<const void*>(&UhcSnareGroupPaceHook), 0x1A) ||
      !WriteJmp(0x004FA17D, reinterpret_cast<const void*>(&UhcSnareSlotWaitHook), 6) ||
      !WriteJmp(0x006AA514, reinterpret_cast<const void*>(&UhcSnarePathWaitHook), 6) ||
      !WriteJmp(0x006AA56A, reinterpret_cast<const void*>(&UhcSnarePathCheckHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"snareOnlyHitUnit: a snared unit (TargetSpeedBoost) no longer slows its group; the group neither paces at "
      L"nor waits for it while the snare lasts%ls (multiplayer unverified)",
      g_log ? L", every snared member logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/snare_hooks.asm

```asm
; Hooks for snareOnlyHitUnit. Entered through a jmp written over the stock code; each leaves
; through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Snare and group
; movement").
.686
.model flat, c
option casemap :none

include common.inc

UhcSnareGroupPace PROTO STDCALL member:DWORD, grp:DWORD
UhcSnareSkipsWait PROTO STDCALL member:DWORD, site:DWORD
UhcSnareSkipsWaitById PROTO STDCALL memberId:DWORD

.data
paceNext        dd 004FD417h    ; mov ecx,[edi+5Ch]: the rest of the member loop body
paceStore       dd 004FD53Ah    ; stock: call the member's vtbl[34h] again, fstp [esi+7Ch], jmp 4FD417h
slotWaitNext    dd 004FA183h    ; fld dword ptr [esp+18h]: the member step goes on
pathWaitNext    dd 006AA51Ah    ; mov eax,[esi+10h]: the member's slot distance check
pathCheckNext   dd 006AA570h    ; jmp 4F9F99h: the next member

.code

; Replaces 0x4FD3FD..0x4FD416 in FUN_004FD289 (group recompute): the member's max velocity
; (vtbl[34h]) compared with the group's pace [esi+7Ch], stored by 0x4FD53A when it is lower.
; ESI = group, EDI = member, EBP/EBX = loop index/count, FPU stack empty. EAX, ECX, EDX and the
; flags are dead on both continuations. A member with an active snare is handled by the helper
; (its velocity without the snare); any other member runs the stock compare unchanged.
UhcSnareGroupPaceHook PROC
    TRACE_ONCE "snareOnlyHitUnit (0x4FD3FD)"
    push esi
    push edi
    call UhcSnareGroupPace          ; -> al = 1: the helper did the compare and the store
    test al, al
    jne done
    mov edx, dword ptr [edi]        ; stolen 0x4FD3FD
    mov ecx, edi                    ; stolen 0x4FD3FF
    mov eax, dword ptr [edx+34h]    ; stolen 0x4FD401
    call eax                        ; stolen 0x4FD404: call 4A974Ah, which is jmp eax
    fcomp dword ptr [esi+7Ch]       ; stolen 0x4FD409
    fnstsw ax                       ; stolen 0x4FD40C
    test ah, 5                      ; stolen 0x4FD40E
    jnp store                       ; stolen 0x4FD411: jnp 4FD53Ah (velocity < pace)
done:
    jmp paceNext
store:
    jmp paceStore
UhcSnareGroupPaceHook ENDP

; Replaces 0x4FA17D..0x4FA182 (mov eax,[esi+4] / or byte ptr [eax],80h) in the member step
; FUN_004FA03B, reached when the member is farther from its formation slot than 0x4F9B69 allows:
; group bit 7 makes the group move at 0.8333x its pace (0x4FAAA5). ESI = group, EBP = member,
; FPU stack empty. EAX and the flags are dead at 0x4FA183; ECX and EDX are kept anyway.
UhcSnareSlotWaitHook PROC
    TRACE_ONCE "snareOnlyHitUnit (0x4FA17D)"
    push ecx
    push edx
    push 004FA17Dh
    push ebp
    call UhcSnareSkipsWait          ; -> al = 1: snared member, the group does not wait
    pop edx
    pop ecx
    test al, al
    jne skip
    mov eax, dword ptr [esi+4]      ; stolen 0x4FA17D
    or byte ptr [eax], 80h          ; stolen 0x4FA180
skip:
    jmp slotWaitNext
UhcSnareSlotWaitHook ENDP

; Replaces 0x6AA514..0x6AA519 (mov eax,[ebx+4] / or byte ptr [eax],80h), where a member that
; got its own path to its slot (FUN_004F9E05's member loop, from 0x6AA408) makes its group wait.
; EBX = group, ESI = member, EDI = member+14h. EAX and the flags are dead at 0x6AA51A; ECX and
; EDX are kept anyway.
UhcSnarePathWaitHook PROC
    TRACE_ONCE "snareOnlyHitUnit (0x6AA514)"
    push ecx
    push edx
    push 006AA514h
    push esi
    call UhcSnareSkipsWait          ; -> al = 1: snared member, the group does not wait
    pop edx
    pop ecx
    test al, al
    jne skip
    mov eax, dword ptr [ebx+4]      ; stolen 0x6AA514
    or byte ptr [eax], 80h          ; stolen 0x6AA517
skip:
    jmp pathWaitNext
UhcSnarePathWaitHook ENDP

; Replaces 0x6AA56A..0x6AA56F (mov eax,[eax+4] / or byte ptr [eax],80h), the same path's slot
; distance check, which sets the bit again. EAX = EBX = EBP = group, ESI = the member's ID
; (0x6AA537 loaded it over the pointer). EAX and the flags are dead after the jmp 4F9F99h.
UhcSnarePathCheckHook PROC
    TRACE_ONCE "snareOnlyHitUnit (0x6AA56A)"
    push ecx
    push edx
    push eax                        ; the group, for the stolen code
    push esi
    call UhcSnareSkipsWaitById      ; -> al = 1: snared member, the group does not wait
    test al, al
    pop eax                         ; pop leaves the flags alone
    pop edx
    pop ecx
    jne skip
    mov eax, dword ptr [eax+4]      ; stolen 0x6AA56A
    or byte ptr [eax], 80h          ; stolen 0x6AA56D
skip:
    jmp pathCheckNext
UhcSnarePathCheckHook ENDP

END
```

## cantBeSlowed

Contract: [cantBeSlowed](../porting-to-another-dll.md#cantbeslowed).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `SnareCreate` `0x4DD201` (44 B).

### src/features/cantslow.cpp

```cpp
// cantBeSlowed: a unit whose proto has the abstract type CantBeSlowed ignores <TargetSpeedBoost>, and a
// unit whose proto has CannotSnare does not snare with its own attacks.
//
// Stock snares a target at one place: 0x4DD1DE tests that it can move, and 0x4DD201 pushes the arguments
// of the modifier's creator 0x4DD22D. There EBP is still the attacker's unit action, whose unit is at
// [ebp+10h] (the one caller, 0x48F9F5 in FUN_004B7766, keeps it in EBP and FUN_0048FA07 never writes it).
// The hook leaves through the snare's exit for a marked target or a marked attacker. damageOverTime's
// snare asks UhcCantBeSlowed and UhcCannotSnare too. The hook is in hooks/cantslow_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" void UhcCantBeSlowedHook();

namespace {

constexpr int kMaxLogLines = 200;

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

bool g_log = false;
int g_logLines = 0;
std::int32_t g_type = -1;
std::int32_t g_attackerType = -1;

bool HasType(const char* unit, std::int32_t type) {
  if (unit == nullptr || type < 0) {
    return false;
  }
  const char* proto = *reinterpret_cast<const char* const*>(unit + 0x5C);
  return proto != nullptr && kProtoIsType(proto, type);
}

std::int32_t ProtoId(const char* unit) {
  return *reinterpret_cast<const std::int32_t*>(*reinterpret_cast<const char* const*>(unit + 0x5C) + 8);
}

}  // namespace

// From the hook and from damageOverTime, with the target. True: no snare.
extern "C" bool __stdcall UhcCantBeSlowed(const char* unit) {
  if (!HasType(unit, g_type)) {
    return false;
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"cantBeSlowed: proto %d ignores a snare", ProtoId(unit));
  }
  return true;
}

// From the hook and from damageOverTime, with the attacking unit (null when it is gone: then the snare
// is as stock). True: no snare.
extern "C" bool __stdcall UhcCannotSnare(const char* attacker) {
  if (!HasType(attacker, g_attackerType)) {
    return false;
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"cantBeSlowed: proto %d does not snare (CannotSnare)", ProtoId(attacker));
  }
  return true;
}

namespace uhc {

Outcome ApplyCantBeSlowed(const Config& config) {
  const Config::Args* args = config.First("cantBeSlowed");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"cantBeSlowed: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("cantBeSlowed", {&sites::kSnareCreate}) || !RequestAbstractUnitType("CantBeSlowed", &g_type) ||
      !RequestAbstractUnitType("CannotSnare", &g_attackerType) ||
      !WriteJmp(sites::kSnareCreate.va, reinterpret_cast<const void*>(&UhcCantBeSlowedHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"cantBeSlowed: the abstract types CantBeSlowed (on the target) and CannotSnare (on the attacker) are on");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/cantslow_hooks.asm

```asm
; cantBeSlowed (src/features/cantslow.cpp). Entered through a jmp written over the stock code; it leaves
; through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcCantBeSlowed PROTO STDCALL unit:DWORD
UhcCannotSnare PROTO STDCALL attacker:DWORD

.data
snareNext       dd 004DD207h    ; push 0BB8h: the rest of the creator's arguments
snareExit       dd 0048FA49h    ; pop esi / pop ecx ..., where the snare ends

.code

; Replaces 0x4DD201..0x4DD206 (push 1 / push -1 / push -1), the creator's last arguments, re-executed
; here. ESI = the target; EBP = the attacker's unit action, [ebp+10h] its unit (FUN_004B7766 keeps it in
; EBP, and FUN_0048FA07 does not write it). The code after it sets ECX itself and reads neither EAX nor EDX.
UhcCantBeSlowedHook PROC
    TRACE_ONCE "cantBeSlowed (0x4DD201)"
    invoke UhcCantBeSlowed, esi
    test al, al
    jne skip
    mov eax, [ebp+10h]
    invoke UhcCannotSnare, eax
    test al, al
    jne skip
    push 1
    push -1
    push -1
    jmp snareNext
skip:
    jmp snareExit
UhcCantBeSlowedHook ENDP

END
```

## killBountyTechs, resourceBounty and teamKillBounty

Contract: [killBountyTechs, resourceBounty and teamKillBounty](../porting-to-another-dll.md#killbountytechs-resourcebounty-and-teamkillbounty).

Besides the core helpers, it needs: [`techsubtypes.h`](helpers.md#tech-subtypes), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `TeamBountyPay` `0x49BDAB` (6 B), `BountyKillBranch` `0x4D4E0C` (5 B), `BountyTagHandler` `0x51D669` (4 B).

### src/features/bounty.cpp

```cpp
// killBountyTechs: a tech effect type="Data" subtype="KillBounty" (or "Bounty") changes a proto's
// <Bounty>, the XP its killer gets. teamKillBounty: that XP goes to the killer's whole team when the
// victim's proto has the abstract type TeamKillBounty.
//
// Stock keeps the tag in the proto's [+168h]. The value function 0x4D4DC5 reads it from the victim's
// proto, the copy of the victim's owner, at the kill. No Data subtype reaches the field, so the effect
// is a new one (techsubtypes.h), applied through the stock value function 0x7F892A, which gives it
// every relativity and its removal.
//
// The kill reaches FUN_0049BD52 (killer's player), which calls the team's XP routine 0x49BDC0 with the
// killer's ID. That routine pays every member the whole amount when the ID is below 0, so the hook
// passes -1 for a marked victim.
//
// resourceBounty: <Bounty resourcetype="Gold">N</Bounty> pays that resource at the kill. The stock handler
// 0x5F5D79 ignores the attribute and takes the number as XP. A tag cannot be registered twice, so the key
// changes the handler the builder registers, which keeps the stock one for a <Bounty> without the
// attribute. The payment is a hook on the kill branch of TakeDamage (0x4D4E0C), which runs for any bounty
// or none. A TeamKillBounty victim pays the team here too. The hooks are in hooks/bounty_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

extern "C" void UhcTeamBountyHook();
extern "C" void UhcResourceBountyHook();

namespace {

constexpr std::size_t kBounty = 0x168;
constexpr std::size_t kUnitProto = 0x5C;
constexpr int kMaxLogLines = 200;

using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
using ResourceByNameFn = std::int32_t(__thiscall*)(void* context, const char* name);
const auto kResourceByName = reinterpret_cast<ResourceByNameFn>(0x0044709C);
using PlayerAddFn = bool(__thiscall*)(char* player, std::int32_t resource, float amount, bool flag);
const auto kPlayerAdd = reinterpret_cast<PlayerAddFn>(0x0049A98A);
using PlayerByIdFn = char*(__thiscall*)(char* world, std::int32_t id);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
using BountyHandlerFn = bool(__cdecl*)(void* context, const char* node, char* proto);
const auto kStockBountyTag = reinterpret_cast<BountyHandlerFn>(0x005F5D79);

struct ResourceBounty {
  std::int32_t resource;
  float amount;
};

// By proto ID. Written while protos load and read at a kill, on the same thread.
std::unordered_map<std::int32_t, std::vector<ResourceBounty>> g_resourceBounties;
bool g_logResource = false;
int g_resourceLines = 0;

bool g_logTech = false;
bool g_logTeam = false;
int g_techLines = 0;
int g_teamLines = 0;
std::int32_t g_teamType = -1;

void ChangeBounty(char* proto, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  auto* value = reinterpret_cast<float*>(proto + kBounty);
  const float before = *value;
  kEffectValue(relativity, value, *reinterpret_cast<const float*>(base + kBounty), amount, unapply);
  if (g_logTech && g_techLines < kMaxLogLines) {
    ++g_techLines;
    uhc::Log(L"killBountyTechs: proto %d, relativity %u, amount %g%ls: %g -> %g",
             *reinterpret_cast<const std::int32_t*>(proto + 8), relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", static_cast<double>(before), static_cast<double>(*value));
  }
}

void ForgetResourceBounties(char*) { g_resourceBounties.clear(); }

// Replaces the handler of <Bounty> in the tag table.
bool __cdecl ReadBounty(void* context, const char* node, char* proto) {
  const void* text = nullptr;
  if (!kXmlAttribute(node, "resourcetype", &text) || text == nullptr) {
    return kStockBountyTag(context, node, proto);
  }
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 8);
  const char* name = kXmlText(text);
  const std::int32_t resource = name != nullptr ? kResourceByName(context, name) : -1;
  const wchar_t* value = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  const float amount = value != nullptr ? static_cast<float>(_wtof(value)) : 0.0f;
  if (resource < 0 || amount <= 0.0f) {
    uhc::Log(L"resourceBounty: proto %d: <Bounty resourcetype=\"%hs\"> needs a resource and a number above 0, ignored", id,
             name != nullptr ? name : "");
    return true;
  }
  g_resourceBounties[id].push_back({resource, amount});
  if (g_logResource) {
    uhc::Log(L"resourceBounty: proto %d pays %g of resource %d", id, static_cast<double>(amount), resource);
  }
  return true;
}

bool LogOption(const uhc::Config::Args& args, const char* key, bool* log) {
  for (const std::string& arg : args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      uhc::Log(L"%hs: unknown option %hs; feature not applied", key, arg.c_str());
      return false;
    }
    *log = true;
  }
  return true;
}

}  // namespace

// From the hook, with the victim. True: the whole team gets the XP.
extern "C" bool __stdcall UhcIsTeamBounty(const char* victim, float amount) {
  if (victim == nullptr || g_teamType < 0) {
    return false;
  }
  const char* proto = *reinterpret_cast<const char* const*>(victim + kUnitProto);
  if (proto == nullptr || !kProtoIsType(proto, g_teamType)) {
    return false;
  }
  if (g_logTeam && g_teamLines < kMaxLogLines) {
    ++g_teamLines;
    uhc::Log(L"teamKillBounty: proto %d: %g XP to the killer's whole team", *reinterpret_cast<const std::int32_t*>(proto + 8),
             static_cast<double>(amount));
  }
  return true;
}

// From the hook on the kill branch, with the victim and the killer's player, which can be null.
extern "C" void __stdcall UhcPayResourceBounty(const char* victim, char* killer) {
  if (victim == nullptr || killer == nullptr) {
    return;
  }
  const char* proto = *reinterpret_cast<const char* const*>(victim + kUnitProto);
  if (proto == nullptr) {
    return;
  }
  const auto found = g_resourceBounties.find(*reinterpret_cast<const std::int32_t*>(proto + 8));
  if (found == g_resourceBounties.end() || killer == *reinterpret_cast<char* const*>(victim + 0x44)) {
    return;
  }
  char* world = *reinterpret_cast<char**>(*reinterpret_cast<char**>(0x00C66234) + 0x13C);
  const bool team = g_teamType >= 0 && kProtoIsType(proto, g_teamType);
  for (const ResourceBounty& bounty : found->second) {
    int paid = 1;
    if (team) {
      paid = 0;
      const std::int32_t teamId = *reinterpret_cast<const std::int32_t*>(killer + 0x10);
      const auto teams = *reinterpret_cast<char* const* const*>(world + 0x188);
      const char* members = teamId >= 0 && teamId < *reinterpret_cast<const std::int32_t*>(world + 0x18C) ? teams[teamId] : nullptr;
      if (members != nullptr) {
        const auto* ids = *reinterpret_cast<const std::int32_t* const*>(members + 8);
        const std::int32_t count = *reinterpret_cast<const std::int32_t*>(members + 0xC);
        for (std::int32_t i = 0; i < count; ++i) {
          if (char* player = kPlayerById(world, ids[i])) {
            kPlayerAdd(player, bounty.resource, bounty.amount, false);
            ++paid;
          }
        }
      }
    } else {
      kPlayerAdd(killer, bounty.resource, bounty.amount, false);
    }
    if (g_logResource && g_resourceLines < kMaxLogLines) {
      ++g_resourceLines;
      uhc::Log(L"resourceBounty: proto %d killed: %g of resource %d to %d player(s)",
               *reinterpret_cast<const std::int32_t*>(proto + 8), static_cast<double>(bounty.amount), bounty.resource, paid);
    }
  }
}

namespace uhc {

Outcome ApplyKillBountyTechs(const Config& config) {
  const Config::Args* args = config.First("killBountyTechs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!LogOption(*args, "killBountyTechs", &g_logTech) || !AddTechSubtype("KillBounty", &ChangeBounty) ||
      !AddTechSubtype("Bounty", &ChangeBounty)) {
    return Outcome::kFailed;
  }
  Log(L"killBountyTechs: the Data subtypes KillBounty and Bounty are on");
  return Outcome::kApplied;
}

Outcome ApplyResourceBounty(const Config& config) {
  const Config::Args* args = config.First("resourceBounty");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!LogOption(*args, "resourceBounty", &g_logResource) ||
      !VerifyAll("resourceBounty", {&sites::kBountyTagHandler, &sites::kBountyKillBranch}) ||
      !OnDatabaseLoad(&ForgetResourceBounties) ||
      !WriteDword(sites::kBountyTagHandler.va, static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(&ReadBounty))) ||
      !WriteJmp(sites::kBountyKillBranch.va, reinterpret_cast<const void*>(&UhcResourceBountyHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"resourceBounty: <Bounty resourcetype> is on");
  return Outcome::kApplied;
}

Outcome ApplyTeamKillBounty(const Config& config) {
  const Config::Args* args = config.First("teamKillBounty");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!LogOption(*args, "teamKillBounty", &g_logTeam) || !VerifyAll("teamKillBounty", {&sites::kTeamBountyPay}) ||
      !RequestAbstractUnitType("TeamKillBounty", &g_teamType) ||
      !WriteJmp(sites::kTeamBountyPay.va, reinterpret_cast<const void*>(&UhcTeamBountyHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"teamKillBounty: the abstract type TeamKillBounty is on");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/bounty_hooks.asm

```asm
; teamKillBounty and resourceBounty (src/features/bounty.cpp). Entered through a jmp written over the stock code; it leaves
; through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcIsTeamBounty PROTO STDCALL victim:DWORD, amount:DWORD
UhcPayResourceBounty PROTO STDCALL victim:DWORD, killer:DWORD

.data
teamPayNext     dd 0049BDB1h    ; push 0 / push ecx / push edx / mov ecx,eax / call 0x49BDC0
killBranchNext  dd 004D4E11h    ; mov ecx,esi / call 0x4D4DC5

.code

; Replaces 0x49BDAB..0x49BDB0 (mov ecx,[esp+14h] / mov edx,[esi]) in FUN_0049BD52, its only caller being
; TakeDamage at 0x49B73C. EAX = the killer's team, ESI = the killer's player, [esp] = the ESI the function
; saved: the caller's, the victim. EDX and ECX go to the XP routine: the player ID, -1 for the whole
; team, and the amount. The routine runs on every hit, with an amount of 0 unless the hit kills, so the
; helper only runs for a bounty.
UhcTeamBountyHook PROC
    TRACE_ONCE "teamKillBounty (0x49BDAB)"
    cmp dword ptr [esp+14h], 0
    je killer
    push eax
    mov ecx, dword ptr [esp+4]
    mov edx, dword ptr [esp+18h]
    invoke UhcIsTeamBounty, ecx, edx
    test al, al
    pop eax
    je killer
    mov ecx, dword ptr [esp+14h]
    or edx, -1
    jmp teamPayNext
killer:
    mov ecx, dword ptr [esp+14h]
    mov edx, dword ptr [esi]
    jmp teamPayNext
UhcTeamBountyHook ENDP

; Replaces 0x4D4E0C..0x4D4E10 (mov ecx,[esp+28h] / push ecx), re-executed here, on the kill branch of
; TakeDamage. ESI = the victim, [esp+20h] = the killer's player. The next call overwrites EAX, ECX and EDX.
UhcResourceBountyHook PROC
    TRACE_ONCE "resourceBounty (0x4D4E0C)"
    mov ecx, dword ptr [esp+20h]
    invoke UhcPayResourceBounty, esi, ecx
    mov ecx, dword ptr [esp+28h]
    push ecx
    jmp killBranchNext
UhcResourceBountyHook ENDP

END
```

## pillageGold

Contract: [pillageGold](../porting-to-another-dll.md#pillagegold).

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `ResListGet` `0x44EFFF` (61 B), `PlayerAddResource` `0x49A98A` (16 B), `PillageHitCall` `0x49B72B` (22 B).

### src/features/pillage.cpp

```cpp
// pillageGold: a unit of the abstract type AbstractCanPillage steals gold with each hit of an action
// that has <PillageAmount>, normally its BuildingAttack, from the owner of the building it hits.
//
// Stock has no such thing. TakeDamage FUN_0049B3D9 calls 0x49BD52 on every hit that has an attacking
// player (0x49B73C), and that call has all the key needs in its frame. The key replaces the call: it
// runs the steal, then the stock function. Only gold, resource 0, and a real transfer: the attacker
// gets what the victim loses, with no gather multiplier. If the victim has less than the amount, the
// hit takes what there is; if it has none, nothing. The victim's stockpile is read before the add
// 0x49A98A, so a victim in debt gives nothing and is never taken below 0. The hook is in
// hooks/pillage_hooks.asm.
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" void UhcPillageHook();

namespace {

constexpr std::uint32_t kHitCall = 0x0049B73C;  // call 0x49BD52 in TakeDamage
constexpr std::int32_t kGold = 0;
constexpr std::int32_t kEnemy = 2;              // [player+1D4h+4*id], as the diplomacy filter 0x49AEE0 reads it
constexpr float kMinAmount = 1.0e-6f;
constexpr int kMaxLogLines = 200;

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using ListGetFn = float(__thiscall*)(const char* list, std::int32_t resource);
using PlayerAddFn = bool(__thiscall*)(char* player, std::int32_t resource, float amount, bool flag);

const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kListGet = reinterpret_cast<ListGetFn>(0x0044EFFF);
const auto kPlayerAdd = reinterpret_cast<PlayerAddFn>(0x0049A98A);

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

std::map<ActionKey, float> g_amounts;  // filled while the data loads, read-only after
std::int32_t g_canPillage = -1;
std::int32_t g_building = -1;
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

void NewDatabase(char*) {
  g_amounts.clear();
  g_logLines = 0;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  if (_wcsicmp(tag.name, L"PillageAmount") != 0) {
    return;
  }
  const float amount = tag.text == nullptr ? 0.0f : std::wcstof(tag.text, nullptr);
  const std::int32_t name = Field<std::int32_t>(tag.action, 0x04);
  if (amount <= kMinAmount || name < 0) {
    uhc::Log(L"pillageGold: proto %hs: <PillageAmount> needs a number above 0, after the action's <Name>; ignored",
             Field<const char*>(tag.proto, 0x10));
    return;
  }
  g_amounts[{Field<std::int32_t>(tag.proto, 0x04), name}] = amount;
  if (g_log) {
    uhc::Log(L"pillageGold: proto %hs, action %d: %g gold a hit", Field<const char*>(tag.proto, 0x10), name,
             static_cast<double>(amount));
  }
}

}  // namespace

// From the hook, on every hit with an attacking player, before the stock call. The attacker is null
// when it died before its projectile landed.
extern "C" void __stdcall UhcPillageHit(const char* attacker, char* attackerPlayer, const char* action, const char* victim) {
  if (g_amounts.empty() || attacker == nullptr || attackerPlayer == nullptr || action == nullptr) {
    return;
  }
  const char* attackerProto = Field<const char*>(attacker, 0x5C);
  if (attackerProto == nullptr) {
    return;
  }
  const auto found = g_amounts.find({Field<std::int32_t>(attackerProto, 0x04), Field<std::int32_t>(action, 0x04)});
  if (found == g_amounts.end() || g_canPillage < 0 || !kProtoIsType(attackerProto, g_canPillage)) {
    return;
  }
  const char* victimProto = Field<const char*>(victim, 0x5C);
  char* victimPlayer = Field<char*>(victim, 0x44);
  if (victimProto == nullptr || victimPlayer == nullptr || g_building < 0 || !kProtoIsType(victimProto, g_building)) {
    return;
  }
  const std::int32_t victimId = Field<std::int32_t>(victimPlayer, 0x00);
  if (victimId <= 0 || Field<std::int32_t>(attackerPlayer, 0x1D4 + 4 * victimId) != kEnemy) {
    return;
  }
  const float have = kListGet(victimPlayer + 0x230, kGold);
  const float take = have < found->second ? have : found->second;
  if (take <= kMinAmount) {
    return;
  }
  kPlayerAdd(victimPlayer, kGold, -take, false);
  kPlayerAdd(attackerPlayer, kGold, take, false);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"pillageGold: unit %d of player %d took %g gold from player %d (%hs): %g -> %g, the attacker has %g",
             Field<std::int32_t>(attacker, 0x10), Field<std::int32_t>(attackerPlayer, 0x00), static_cast<double>(take),
             victimId, Field<const char*>(victimProto, 0x10), static_cast<double>(have),
             static_cast<double>(kListGet(victimPlayer + 0x230, kGold)),
             static_cast<double>(kListGet(attackerPlayer + 0x230, kGold)));
  }
}

namespace uhc {

Outcome ApplyPillageGold(const Config& config) {
  const Config::Args* args = config.First("pillageGold");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"pillageGold: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("pillageGold", {&sites::kPillageHitCall, &sites::kPlayerAddResource, &sites::kResListGet}) ||
      !RequestAbstractUnitType("AbstractCanPillage", &g_canPillage) || !RequestAbstractUnitType("Building", &g_building) ||
      !AddActionTagHandler(&ActionTagRead) || !OnDatabaseLoad(&NewDatabase) ||
      !WriteCall(kHitCall, reinterpret_cast<const void*>(&UhcPillageHook))) {
    return Outcome::kFailed;
  }
  Log(L"pillageGold: AbstractCanPillage units steal gold with an action's <PillageAmount>");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/pillage_hooks.asm

```asm
; pillageGold (src/features/pillage.cpp). Reached through a call retargeted in TakeDamage; it runs the
; stock function it replaces and leaves through an explicit jmp to it.
.686
.model flat, c
option casemap :none

include common.inc

UhcPillageHit PROTO STDCALL attacker:DWORD, attackerPlayer:DWORD, action:DWORD, victim:DWORD

.data
teamXpFn    dd 0049BD52h    ; the stock function of the call at 0x49B73C, thiscall with 3 stack arguments and more

.code

; Replaces the target of the call at 0x49B73C in TakeDamage FUN_0049B3D9. The call pushed four
; arguments, so on entry the frame of TakeDamage starts at [esp+14h]. ESI = the unit hit, EBX = the
; attacking player ([frame+20h]), [frame+28h] the attacking unit, [frame+A8h] the action, TakeDamage's
; third argument. No register survives the helper unless pushed, so all are saved.
UhcPillageHook PROC
    TRACE_ONCE "pillageGold hit (0x49B73C)"
    pushad
    mov eax, dword ptr [esp+20h+14h+28h]
    mov edx, dword ptr [esp+20h+14h+0A8h]
    invoke UhcPillageHit, eax, ebx, edx, esi
    popad
    jmp teamXpFn
UhcPillageHook ENDP

END
```

## veterancyBonus

Contract: [veterancyBonus](../porting-to-another-dll.md#veterancybonus).

Besides the core helpers, it needs: [`floatingtext.h`](helpers.md#floating-text), [`modifiers.h`](helpers.md#modifier-walk), [`prototags.h`](helpers.md#proto-tags), [`techsubtypes.h`](helpers.md#tech-subtypes), [`transformcalls.h`](helpers.md#transform-calls), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `VeterancyKillPath` `0x4D4F37` (6 B), `SnareApply` `0x4DD22D` (130 B).

### src/features/veterancy.cpp

```cpp
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
#include "../techsubtypes.h"
#include "../transformcalls.h"
#include "../unittypes.h"

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
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);

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

void ForgetOnDataLoad(char*) { g_tech.clear(); }

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
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"veterancyBonus: unit %d, proto %d: %d kills%ls, rank %d%ls%g", Field<std::int32_t>(attacker, 0x10),
             Field<std::int32_t>(proto, 8), kills, reached ? L", a new rank" : L"", rank, reached ? L", x" : L"",
             reached ? static_cast<double>(applied) : 0.0);
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
      !AddTechSubtype("VeterancyEnable", &ChangeEnable) || !AddTechSubtype("VeterancyBonus", &ChangeFactor) ||
      !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !WriteJmp(kKillPath, reinterpret_cast<const void*>(&UhcVeterancyHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"veterancyBonus: the proto tag VeterancyBonus is on, and the Data subtypes VeterancyEnable and VeterancyBonus");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/veterancy_hooks.asm

```asm
; veterancyBonus (src/features/veterancy.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcVeterancyKill PROTO STDCALL attacker:DWORD, victim:DWORD

.data
killPathNext    dd 004D4F3Dh    ; call 0x4D520C

.code

; Replaces 0x4D4F37 (mov ecx,[0xC66234]), the head of TakeDamage's cold kill path: the only way here
; is the je at 0x49B746 on [esp+1Fh] = 1, set at 0x4D484B for the blow that takes the unit from alive
; to no hit points. ESI = the unit killed, [esp+28h] = the attacker unit, null when it is gone. The code
; that follows reads neither EAX nor EDX before writing them.
UhcVeterancyHook PROC
    TRACE_ONCE "veterancyBonus kill (0x4D4F37)"
    mov eax, dword ptr [esp+28h]
    invoke UhcVeterancyKill, eax, esi
    mov ecx, dword ptr ds:[00C66234h]
    jmp killPathNext
UhcVeterancyHook ENDP

END
```

## detonationDeath

Contract: [detonationDeath](../porting-to-another-dll.md#detonationdeath).

Besides the core helpers, it needs: [`prototags.h`](helpers.md#proto-tags).

Sites: `DetonationKillCall` `0x493D8F` (5 B), `DetonationAreaHead` `0x4C9D89` (10 B).

### src/features/detonation.cpp

```cpp
// detonationDeath: <DetonationProtoAction>Name</DetonationProtoAction> in a proto fires that action around
// the unit when it dies.
//
// Every death goes through one queue: TakeDamage, a lifespan, a delete and the rest ask 0x4B4DC2, and the
// queue's drain 0x493D46 calls the kill handler 0x4B4F70 for each, from a single call, 0x493D8F. The key
// wraps that call. Before the stock handler runs, the unit still exists, so the stock area damage
// 0x4C9D89 gets it as the attacker, in the same call the game makes for a unit that hits around
// itself (0x6A4A6B). Units that die from the blast join the queue, and the drain reads its count again,
// so a chain runs one by one and does not recurse.
//
// The action is the player's copy, so a tech that changes its damage counts. The names are read once and
// are the same for every player.
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"

namespace {

constexpr std::uint32_t kKillCall = 0x00493D8F;
constexpr std::size_t kUnitState = 4;       // bit array; +8h its size in bits
constexpr std::size_t kUnitId = 0x10;
constexpr std::size_t kUnitPosition = 0x14;
constexpr std::size_t kUnitProto = 0x5C;
constexpr std::size_t kProtoId = 8;
constexpr std::size_t kProtoActions = 0x44;  // the action set
constexpr std::size_t kActionList = 0x1C;    // in the set: the array of actions, its count at +20h
constexpr std::size_t kActionId = 4;
constexpr std::size_t kActionFlags = 0x64;   // bit array; +68h its size in bits
constexpr std::size_t kActionNames = 0x1FD8; // in the database: the names by action ID, the count at +1FDCh
constexpr std::uint32_t kDeadBit = 11;       // the kill handler returns at once when it is set
constexpr std::uint32_t kAreaFlagBit = 6;    // what the stock caller reads and passes on
constexpr std::uint32_t kZeroVector = 0x00CF0618;
constexpr int kMaxLogLines = 200;

using KillFn = void(__thiscall*)(char* unit, std::uint32_t a, std::uint32_t b, std::uint32_t c);
const auto kKill = reinterpret_cast<KillFn>(0x004B4F70);
using AreaFn = void(__thiscall*)(const char* world, std::int32_t unit, char* action, const void* point, float multiplier,
                                 std::int32_t a, std::int32_t b, std::int32_t c, std::int32_t* hit, std::uint32_t flag,
                                 const void* offset);
const auto kArea = reinterpret_cast<AreaFn>(0x004C9D89);

struct Detonation {
  std::wstring name;
  std::int32_t action = -2;  // -2: not looked up yet, -1: the proto has no action of that name
  std::wstring command;      // <DetonationCommand>: the proto command that detonates (a delete)
  float threshold = -1.0f;   // <DetonationHitpointThreshold>: the HP ratio that detonates by itself
  float decay = -1.0f;       // <DetonationHitpointDecay>: HP lost per second under the threshold
};

std::unordered_map<std::int32_t, Detonation> g_protos;  // by proto ID; the map's shape is fixed after the load
bool g_log = false;
int g_logLines = 0;

bool Bit(const char* owner, std::size_t array, std::uint32_t bit) {
  const auto* bits = *reinterpret_cast<const std::uint8_t* const*>(owner + array);
  const std::uint32_t size = *reinterpret_cast<const std::uint32_t*>(owner + array + 4);
  return bits != nullptr && bit < size && (bits[bit / 8] & (1u << (bit % 8))) != 0;
}

const char* Game() { return *reinterpret_cast<const char* const*>(0x00C66234); }

// The action of the player's copy with that name, by its ID in the database's list of names.
char* FindAction(const char* proto, Detonation& detonation) {
  const char* game = Game();
  const char* db = *reinterpret_cast<const char* const*>(game + 0x140);
  const char* set = *reinterpret_cast<const char* const*>(proto + kProtoActions);
  if (set == nullptr) {
    return nullptr;
  }
  const auto* names = *reinterpret_cast<const wchar_t* const* const*>(db + kActionNames);
  const std::int32_t nameCount = *reinterpret_cast<const std::int32_t*>(db + kActionNames + 4);
  char* const* actions = *reinterpret_cast<char* const* const*>(set + kActionList);
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(set + kActionList + 4);
  for (std::int32_t i = 0; i < count; ++i) {
    const std::int32_t id = *reinterpret_cast<const std::int32_t*>(actions[i] + kActionId);
    if (detonation.action >= 0) {
      if (id == detonation.action) {
        return actions[i];
      }
      continue;
    }
    if (id >= 0 && id < nameCount && names[id] != nullptr && _wcsicmp(names[id], detonation.name.c_str()) == 0) {
      detonation.action = id;
      return actions[i];
    }
  }
  if (detonation.action == -2) {
    detonation.action = -1;
    uhc::Log(L"detonationDeath: proto %d has no action %ls", *reinterpret_cast<const std::int32_t*>(proto + kProtoId),
             detonation.name.c_str());
  }
  return nullptr;
}

bool __cdecl ReadDetonation(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  if (text == nullptr || text[0] == L'\0') {
    uhc::Log(L"detonationDeath: proto %d: <DetonationProtoAction> names no action, ignored", id);
    return true;
  }
  g_protos[id].name = text;
  if (g_log) {
    uhc::Log(L"detonationDeath: proto %d fires %ls", id, text);
  }
  return true;
}

const wchar_t* NodeText(const char* node) { return *reinterpret_cast<const wchar_t* const*>(node + 0x14); }

bool __cdecl ReadCommand(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  if (text == nullptr || text[0] == L'\0') {
    uhc::Log(L"detonationDeath: proto %d: <DetonationCommand> names no command, ignored", id);
    return true;
  }
  g_protos[id].command = text;
  if (g_log) {
    uhc::Log(L"detonationDeath: proto %d detonates on its command %ls (a delete)", id, text);
  }
  return true;
}

bool ReadRatio(const char* node, char* proto, const wchar_t* tag, float* out, float low, float high) {
  const wchar_t* text = NodeText(node);
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  wchar_t* end = nullptr;
  const double value = text == nullptr ? -1.0 : std::wcstod(text, &end);
  if (text == nullptr || end == text || !(value >= low) || !(value <= high)) {
    uhc::Log(L"detonationDeath: proto %d: <%ls> needs a number from %g to %g, ignored", id, tag, static_cast<double>(low),
             static_cast<double>(high));
    return true;
  }
  *out = static_cast<float>(value);
  return true;
}

bool __cdecl ReadThreshold(void*, const char* node, char* proto) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  float value = -1.0f;
  ReadRatio(node, proto, L"DetonationHitpointThreshold", &value, 0.0f, 1.0f);
  if (value >= 0.0f) {
    g_protos[id].threshold = value;
    if (g_log) {
      uhc::Log(L"detonationDeath: proto %d detonates at %.0f %% of its hit points", id, static_cast<double>(value * 100.0f));
    }
  }
  return true;
}

bool __cdecl ReadDecay(void*, const char* node, char* proto) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  float value = -1.0f;
  ReadRatio(node, proto, L"DetonationHitpointDecay", &value, 0.0f, 1.0e6f);
  if (value >= 0.0f) {
    g_protos[id].decay = value;
    if (g_log) {
      uhc::Log(L"detonationDeath: proto %d loses %.2f hit points a second under its threshold", id,
               static_cast<double>(value));
    }
  }
  return true;
}

void Detonate(char* unit, std::uint32_t a, std::uint32_t b, std::uint32_t c) {
  const char* proto = *reinterpret_cast<const char* const*>(unit + kUnitProto);
  if (proto == nullptr) {
    return;
  }
  const std::int32_t protoId = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  const auto found = g_protos.find(protoId);
  if (found == g_protos.end() || found->second.action == -1 || Bit(unit, kUnitState, kDeadBit)) {
    return;
  }
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : *reinterpret_cast<const char* const*>(game + 0x13C);
  if (world == nullptr) {
    return;
  }
  char* action = FindAction(proto, found->second);
  if (action == nullptr) {
    return;
  }
  const auto* position = reinterpret_cast<const float*>(unit + kUnitPosition);
  std::int32_t hit = 0;
  kArea(world, *reinterpret_cast<const std::int32_t*>(unit + kUnitId), action, position, 1.0f, 0, 0, -1, &hit,
        Bit(action, kActionFlags, kAreaFlagBit) ? 1 : 0, reinterpret_cast<const void*>(kZeroVector));
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"detonationDeath: unit %d, proto %d, at %.1f, %.1f, kill flags %u %u %u", *reinterpret_cast<std::int32_t*>(unit + kUnitId),
             protoId, static_cast<double>(position[0]), static_cast<double>(position[2]), a & 0xFF, b & 0xFF, c & 0xFF);
  }
}

// Replaces the drain's call of the kill handler.
void __fastcall Kill(char* unit, void*, std::uint32_t a, std::uint32_t b, std::uint32_t c) {
  Detonate(unit, a, b, c);
  kKill(unit, a, b, c);
}

}  // namespace

namespace uhc {

Outcome ApplyDetonationDeath(const Config& config) {
  const Config::Args* args = config.First("detonationDeath");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"detonationDeath: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("detonationDeath", {&sites::kDetonationKillCall, &sites::kDetonationAreaHead}) ||
      !AddProtoTagHandler("DetonationProtoAction", &ReadDetonation) ||
      !AddProtoTagHandler("DetonationCommand", &ReadCommand) ||
      !AddProtoTagHandler("DetonationHitpointThreshold", &ReadThreshold) ||
      !AddProtoTagHandler("DetonationHitpointDecay", &ReadDecay) ||
      !WriteCall(kKillCall, reinterpret_cast<const void*>(&Kill))) {
    return Outcome::kFailed;
  }
  Log(L"detonationDeath: the proto tag DetonationProtoAction is on");
  return Outcome::kApplied;
}

}  // namespace uhc
```
