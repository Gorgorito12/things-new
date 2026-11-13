# Code for WoL: Combat

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [dodgeAnyUnit, dodgeSoundSet and criticalSoundSet](#dodgeanyunit-dodgesoundset-and-criticalsoundset)
- [damageOverTime](#damageovertime)
- [spreadAnyAccuracy](#spreadanyaccuracy)
- [containedUnitsROF](#containedunitsrof)
- [accuracyTechs](#accuracytechs)
- [broadsideMuzzleLimit](#broadsidemuzzlelimit)
- [snareOnlyHitUnit](#snareonlyhitunit)
- [cantBeSlowed](#cantbeslowed)
- [snareValues](#snarevalues)
- [stealthTargeting](#stealthtargeting)
- [directionalAttack](#directionalattack)
- [killBountyTechs, resourceBounty and teamKillBounty](#killbountytechs-resourcebounty-and-teamkillbounty)
- [pillageGold](#pillagegold)
- [auraStacking](#aurastacking)
- [veterancyBonus](#veterancybonus)
- [detonationDeath](#detonationdeath)
- [impactBoneFix](#impactbonefix)
- [customImpactTypes](#customimpacttypes)

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

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`floatingtext.h`](helpers.md#floating-text), [`savedmarkers.h`](helpers.md#state-kept-for-a-saved-game), [`unitmodels.h`](helpers.md#models-on-a-unit), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

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
// - <AttachModel>path.xml</AttachModel>: the unit carries that model while poisoned, as an aura's
//   <modelattachment> (unitmodels.h). A visual: nothing reaches the simulation.
//
// Saved games: a copy of each running poison lives on the poisoned unit, in markers (savedmarkers.h): a
// header of stat 63h and the stacks' ends in markers of stat 64h. They are written at each change, in the
// simulation, so on every machine, and the table is rebuilt from them when another game is running (SyncWorld).
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
#include <utility>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../floatingtext.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../savedmarkers.h"
#include "../unitmodels.h"
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
constexpr std::int32_t kStatDot = 0x63;       // words: tag, next tick, attacker, source (proto << 16 | action name)
constexpr std::int32_t kStatDotStacks = 0x64; // words: tag, three stacks' ends, 0 when unused

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
  std::wstring modelPath;        // <AttachModel>; empty none
  std::int32_t model = kUnresolved;
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
  ActionKey source = {-1, -1};
  std::int32_t maxStacks = 1;
  float snare = -1.0f;
  std::uint32_t tickColour = 0;
  std::int32_t model = -1;  // <AttachModel> of the first hit, -1 none
  bool hung = false;        // this poison counts in g_modelUsers
};

// Ordered by key, so every machine applies the ticks in the same order.
std::map<DotKey, Dot> g_dots;
const char* g_dotWorld = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
std::map<std::pair<std::int32_t, std::int32_t>, std::int32_t> g_modelUsers;  // {unit, model}: the poisons showing it
std::int32_t g_noBone = -1;
bool g_models = false;  // the sites of unitmodels.h are as in stock
bool g_loggedNoModel = false;

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
  g_modelUsers.clear();
  g_dotWorld = nullptr;
}

std::uint32_t Tag(const DotKey& key) {
  return static_cast<std::uint32_t>(key.attachment) << 8 | static_cast<std::uint32_t>(key.player);
}

// The model of <AttachModel>, -1 for none. The path table exists once a game runs.
std::int32_t ModelOf(Attachment& attachment) {
  if (!g_models || attachment.modelPath.empty()) {
    return -1;
  }
  if (attachment.model == kUnresolved) {
    attachment.model = uhc::ModelOfPath(attachment.modelPath.c_str());
    if (attachment.model < 0) {
      uhc::Log(L"damageOverTime: <AttachModel>%ls is not in the game; no model shown", attachment.modelPath.c_str());
    }
  }
  return attachment.model;
}

// The copy of a poison on its unit. Only words change in place; a marker is made only when the unit lacks one.
void SaveDot(char* unit, const DotKey& key, const Dot& dot) {
  namespace markers = uhc::markers;
  const std::uint32_t tag = Tag(key);
  char* header = markers::Find(unit, kStatDot, tag);
  if (header == nullptr) {
    header = markers::Take(unit, kStatDot);
  }
  if (header == nullptr) {
    return;
  }
  markers::Word(header, 0) = tag;
  markers::Word(header, 1) = dot.nextTick;
  markers::Word(header, 2) = static_cast<std::uint32_t>(dot.attacker);
  markers::Word(header, 3) =
      static_cast<std::uint32_t>(dot.source.proto) << 16 | (static_cast<std::uint32_t>(dot.source.name) & 0xFFFF);
  std::size_t next = 0;
  auto fill = [&](char* marker) {
    for (int word = 1; word < markers::kWords; ++word) {
      markers::Word(marker, word) = next < dot.stacks.size() ? dot.stacks[next++] : 0;
    }
  };
  markers::ForEach(unit, kStatDotStacks, [&](char* marker) {
    if (markers::Word(marker, 0) == tag) {
      if (next < dot.stacks.size()) {
        fill(marker);
      } else {
        markers::Free(marker);
      }
    }
    return true;
  });
  while (next < dot.stacks.size()) {
    char* marker = markers::Take(unit, kStatDotStacks);
    if (marker == nullptr) {
      return;
    }
    markers::Word(marker, 0) = tag;
    fill(marker);
  }
}

// The poison ended on a unit that is still there.
void ClearSavedDot(char* unit, const DotKey& key) {
  namespace markers = uhc::markers;
  const std::uint32_t tag = Tag(key);
  auto freeOwn = [tag](char* marker) {
    if (markers::Word(marker, 0) == tag) {
      markers::Free(marker);
    }
    return true;
  };
  markers::ForEach(unit, kStatDot, freeOwn);
  markers::ForEach(unit, kStatDotStacks, freeOwn);
}

// The table from the markers of a game that just started or loaded: the walk over the world's units runs once.
void Rebuild(const char* world) {
  namespace markers = uhc::markers;
  g_dots.clear();
  g_modelUsers.clear();
  if (g_attachingName == kUnresolved) {
    g_attachingName = ActionNameIndex(L"Attaching");
  }
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* units = Field<char* const*>(world, 0x0C);
  for (std::int32_t i = 0; i < count; ++i) {
    const char* unit = units[i];
    if (unit == nullptr) {
      continue;
    }
    markers::ForEach(unit, kStatDot, [&](char* header) {
      const std::uint32_t tag = markers::Word(header, 0);
      if (tag == markers::kFree) {
        return true;
      }
      Dot dot;
      dot.nextTick = markers::Word(header, 1);
      dot.attacker = static_cast<std::int32_t>(markers::Word(header, 2));
      const std::uint32_t source = markers::Word(header, 3);
      dot.source = {static_cast<std::int32_t>(source >> 16), static_cast<std::int32_t>(source & 0xFFFF)};
      markers::ForEach(unit, kStatDotStacks, [&](char* marker) {
        if (markers::Word(marker, 0) == tag) {
          for (int word = 1; word < markers::kWords; ++word) {
            if (markers::Word(marker, word) != 0) {
              dot.stacks.push_back(markers::Word(marker, word));
            }
          }
        }
        return true;
      });
      if (dot.stacks.empty()) {
        return true;
      }
      std::sort(dot.stacks.begin(), dot.stacks.end(),
                [](std::uint32_t a, std::uint32_t b) { return static_cast<std::int32_t>(a - b) < 0; });
      dot.end = dot.stacks.back();
      const auto found = g_attachments.find(dot.source);
      if (found != g_attachments.end()) {
        dot.maxStacks = found->second.maxStacks;
        dot.snare = found->second.snare;
        dot.tickColour = found->second.tickColour;
        dot.model = ModelOf(found->second);
      }
      g_dots[DotKey{Field<std::int32_t>(unit, 0x10), static_cast<std::int32_t>(tag >> 8),
                    static_cast<std::int32_t>(tag & 0xFF)}] = std::move(dot);
      return true;
    });
  }
  if (!g_dots.empty()) {
    uhc::Log(L"damageOverTime: %u running poison(s) found in the saved game", static_cast<unsigned>(g_dots.size()));
  }
}

// Another game is running: a new or loaded game can reuse the old world's address, so the test is
// the world's step count [world+F8h], which the world update raises by exactly 1 per step (0x481A87), and
// the game time going back. The world tick sees every step of the main world.
void SyncWorld(const char* world, std::uint32_t now) {
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  if (world != g_dotWorld || !Reached(now, g_lastTime) || step - g_lastStep > 1) {
    g_dotWorld = world;
    Rebuild(world);
  }
  g_lastTime = now;
  g_lastStep = step;
}

// Hangs the poison's model, from the world tick: a unit can have no visual yet, so it tries again.
void ShowModel(char* target, std::int32_t targetId, Dot& dot) {
  if (dot.model < 0 || dot.hung) {
    return;
  }
  if (g_noBone < 0) {
    g_noBone = uhc::NoBone();
  }
  const uhc::ModelHang hang = uhc::HangUnitModel(target, dot.model, g_noBone);
  if (hang == uhc::ModelHang::kRetry) {
    return;
  }
  if (hang == uhc::ModelHang::kNotInGame) {
    uhc::RemoveUnitModel(target, dot.model);
    if (!g_loggedNoModel) {
      g_loggedNoModel = true;
      uhc::Log(L"damageOverTime: an <AttachModel> is not in the game; no model shown");
    }
    dot.model = -1;
    return;
  }
  dot.hung = true;
  ++g_modelUsers[{targetId, dot.model}];
}

// The poison ends. target is null when the unit is gone.
void ReleaseModel(char* target, std::int32_t targetId, const Dot& dot) {
  if (!dot.hung) {
    return;
  }
  const auto users = g_modelUsers.find({targetId, dot.model});
  if (users != g_modelUsers.end() && --users->second > 0) {
    return;
  }
  if (users != g_modelUsers.end()) {
    g_modelUsers.erase(users);
  }
  if (target != nullptr) {
    uhc::RemoveUnitModel(target, dot.model);  // the corpse does not keep it
  }
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

void Attach(char* target, std::int32_t player, std::int32_t attacker, const ActionKey& sourceKey,
            Attachment& source) {
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
    dot.model = ModelOf(source);
  }
  // A new hit by the player's units makes that unit the attacker and takes its action's options.
  // It adds a stack that ends Lifespan (the current one) from now; at the stack limit it renews the
  // oldest stack instead. With one stack this restarts the duration. The tick timer keeps running.
  // Capped so the end stays within the 2^31 ms window that Reached() compares.
  dot.attacker = attacker;
  dot.source = sourceKey;
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
  SaveDot(target, key, dot);
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

void Tick(char* world, std::uint32_t now) {
  for (auto it = g_dots.begin(); it != g_dots.end();) {
    const DotKey& key = it->first;
    Dot& dot = it->second;
    char* target = UnitById(world, key.target);
    bool alive = target != nullptr && IsAlive(target);
    if (alive) {
      ShowModel(target, key.target, dot);
    }
    bool ticked = false;
    while (alive && Reached(now, dot.nextTick) && Reached(dot.end, dot.nextTick)) {
      ticked = true;
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
      ReleaseModel(target, key.target, dot);
      if (target != nullptr) {
        ClearSavedDot(target, key);
      }
      it = g_dots.erase(it);
    } else {
      if (ticked) {
        SaveDot(target, key, dot);
      }
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
  const bool model = _wcsicmp(name, L"AttachModel") == 0;
  if (!attach && !stacks && !snare && !tickText && !model) {
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
  if (model) {
    if (text == nullptr || *text == L'\0') {
      uhc::Log(L"damageOverTime: %hs/%ls: empty <AttachModel>; ignored", protoName, ActionName(key.name));
      return;
    }
    g_attachments[key].modelPath = text;
    uhc::Log(L"damageOverTime: %hs/%ls: poisoned units carry %ls", protoName, ActionName(key.name), text);
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
      Attach(unit, player, attacker, key, it->second);
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
  if (world != MainWorld()) {
    return;  // other worlds run the same update; the function itself compares this with [game+13Ch]
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  SyncWorld(world, now);
  if (!g_dots.empty()) {
    Tick(world, now);
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
  g_models = VerifyUnitModels("damageOverTime models");
  if (!g_models) {
    Log(L"damageOverTime: <AttachModel> shows nothing: its sites are not stock");
  }
  if (!AddActionTagHandler(&DotActionTag) ||
      !WriteJmp(sites::kDotTakeDamageEntry.va, reinterpret_cast<const void*>(&UhcDotTakeDamageHook), 6) ||
      !uhc::AddWorldTick(&DotWorldTick)) {
    return Outcome::kFailed;
  }
  Log(L"damageOverTime: <AttachProtoUnit> in protoy.xml ProtoActions attaches damage over time, with "
      L"<AttachMaxStacks>, <AttachSnare>, <AttachTickText> and <AttachModel>%ls (multiplayer unverified)",
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

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `UnitById` `0x44CC6D` (58 B), `IsA` `0x44D7FA` (105 B), `ProtoFlag` `0x45EE02` (53 B), `SpreadPrecalcGate` `0x4997AE` (8 B), `SpreadHitRoll` `0x499890` (23 B), `SpreadApplierHead` `0x49BE95` (12 B), `SpreadInstantArrival` `0x49C151` (40 B), `UnitsNearPoint` `0x4A1C55` (248 B), `SpreadInstantMode` `0x4A9455` (12 B), `SpreadInstantLaunch` `0x4A958F` (22 B), `SpreadGroundStore` `0x4C4DEC` (12 B), `SpreadMissStub` `0x4CEF7B` (17 B), `SpreadRadius` `0x4CF00B` (44 B), `SpreadDraws` `0x4CF037` (64 B).

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
// - a marked unit's TargetGround shot, which never rolls, lands at such an offset point too, and a marked
//   unit goes through the roll even with the cfg var ballisticPrecalcHits off.
// - a marked unit's InstantBallistics shot (a sure hit that skips the roll) is aimed at such an offset
//   point too. At its arrival, in the attack applier: a point inside the target's obstruction hits the
//   target as in stock; otherwise the attack's area damage lands at the point (with <DamageArea>), or
//   the shot hits the unit whose obstruction holds the point, or nothing.
// - a marked unit's ground shot without <DamageArea>, which stock lands with nothing to hit, hits the
//   unit whose obstruction holds the point where it lands, if any.
// Shots with no target unit never reach that code (docs/how-it-works.md). The hooks are in
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
#include <set>
#include <string>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"
#include "../worldtick.h"

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

constexpr unsigned kStrayLinesPerAction = 5;  // "log": stray shots per (proto, action)
constexpr unsigned kMaxStrayLines = 100;

// The list FUN_004A1C55 fills (the engine's dynamic array: data, count, capacity).
struct IdList {
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using ProtoFlagFn = bool(__thiscall*)(const char* proto, std::int32_t flag);
using UnitByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using UnitsNearFn = std::int32_t(__thiscall*)(const char* world, const float* point, float radius, char precise,
                                              IdList* out);
using UnitTestFn = bool(__thiscall*)(const char* unit);
using DistanceFn = float(__thiscall*)(const char* unit, const float* point);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kProtoFlag = reinterpret_cast<ProtoFlagFn>(0x0045EE02);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);

constexpr std::int32_t kFlagProjectile = 0x0A;  // proto flag "Projectile": the area damage skips these
constexpr std::int32_t kInstantBallistics = 22;  // action flag bit (0x5F8D2E)
// The box around the point for the spatial query; a unit is kept only when its obstruction holds
// the point (distance 0, vtable slot B8h).
constexpr float kQueryRadius = 0.01f;
constexpr std::size_t kMaxPendingInstant = 512;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Database() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<UnitTestFn const* const*>(unit))[0xA4 / 4](unit); }

// The distance from a point to the unit's obstruction, 0 inside it (vtable slot B8h).
float ObstructionDistance(const char* unit, const float* point) {
  return (*reinterpret_cast<DistanceFn const* const*>(unit))[0xB8 / 4](unit, point);
}

// A bit of an action's flag bitset ([action+64h], its size in bits at [action+68h]), as the launch
// reads InstantBallistics at 0x4997BE.
bool ActionFlag(const char* action, std::int32_t bit) {
  if (Field<std::uint32_t>(action, 0x68) <= static_cast<std::uint32_t>(bit)) {
    return false;
  }
  return (Field<const std::uint8_t*>(action, 0x64)[bit >> 3] & (1u << (bit & 7))) != 0;
}

// The applier's area test (0x49BF92): the byte [[action+24h]+6] above 0.
bool HasDamageArea(const char* action) {
  const char* damage = Field<const char*>(action, 0x24);
  return damage != nullptr && Field<std::uint8_t>(damage, 6) > 0;
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
bool g_ground = false;  // a TargetGround shot of a marked unit
bool g_tagged = false;
const char* g_shooter = nullptr;
ActionKey g_shotKey{-1, -1};
bool g_instant = false;          // the shot being offset is an InstantBallistics shot
const float* g_aim = nullptr;    // its offset point, for the log

// InstantBallistics shots of marked units that were offset, by their projectile unit's ID, until
// their arrival reaches the applier. Unit IDs are the same on every machine, and the set is only
// read by key and trimmed from its lowest ID, so it stays in step. A shot whose arrival never comes
// (its target died first) is trimmed once more than kMaxPendingInstant are pending.
std::set<std::int32_t> g_instantShots;
const char* g_tickWorld = nullptr;  // the world tick's last world, step and time
std::uint32_t g_tickStep = 0;
std::uint32_t g_tickTime = 0;
std::int32_t g_resourceType = -1;  // Gaia units of this type (trees, mines, hunts) do not stop a stray shot
IdList g_found = {nullptr, 0, 0};  // FUN_004A1C55's output, reused
float g_point[3] = {};             // the point an instant shot's area damage lands at
std::map<ActionKey, unsigned> g_strayLines;
unsigned g_strayLinesTotal = 0;
// "log": what marked units' shots hit, counted per game and reported at 25, 50, 100, ... shots.
struct StrayCounts {
  unsigned target = 0;  // instant, inside the target's obstruction
  unsigned area = 0;    // instant, area damage at the point
  unsigned unit = 0;    // instant, another unit at the point
  unsigned none = 0;    // instant, nothing at the point
  unsigned groundUnit = 0;
  unsigned groundNone = 0;
  unsigned next = 25;
};
StrayCounts g_counts;

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
  g_instantShots.clear();
  g_strayLines.clear();
  g_strayLinesTotal = 0;
  g_counts = {};
}

// After each world update: in another game (a new or loaded one can reuse the world's address, so
// the test is the step count [world+F8h] going up by more than 1, or the game time going back, as
// damageOverTime's), the pending instant shots are forgotten (their IDs are not that game's) and the
// "log" counts start again.
void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_tickWorld || step - g_tickStep > 1 || now < g_tickTime) {
    g_instantShots.clear();
    g_counts = {};
  }
  g_tickWorld = world;
  g_tickStep = step;
  g_tickTime = now;
}

// The unit whose obstruction holds the point and that a stray shot hits: any player's, alive, not
// the shooter or the projectile, not a projectile (the area damage skips those too), and not a Gaia
// resource (a tree, a mine, a hunt). Of several, the nearest centre in x and z, then the lowest ID,
// so every machine picks the same one. nullptr if none.
char* UnitAt(const char* world, const float* point, std::int32_t shooterId, std::int32_t projectileUnitId) {
  kUnitsNear(world, point, kQueryRadius, 1, &g_found);
  char* best = nullptr;
  float bestDistance = 0.0f;
  for (std::int32_t i = 0; i < g_found.count; ++i) {
    const std::int32_t id = g_found.data[i];
    if (id == shooterId || id == projectileUnitId) {
      continue;
    }
    char* unit = kUnitById(world, id);
    const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    if (proto == nullptr || !IsAlive(unit) || kProtoFlag(proto, kFlagProjectile)) {
      continue;
    }
    const char* player = Field<const char*>(unit, 0x44);
    if (player != nullptr && Field<std::int32_t>(player, 0) == 0 && g_resourceType >= 0 &&
        kProtoIsType(proto, g_resourceType)) {
      continue;
    }
    if (ObstructionDistance(unit, point) > 0.0f) {
      continue;
    }
    const float dx = Field<float>(unit, 0x14) - point[0];
    const float dz = Field<float>(unit, 0x1C) - point[2];
    const float distance = dx * dx + dz * dz;
    if (best == nullptr || distance < bestDistance ||
        (distance == bestDistance && id < Field<std::int32_t>(best, 0x10))) {
      best = unit;
      bestDistance = distance;
    }
  }
  return best;
}

enum class Stray { kTarget, kArea, kUnit };

// "log": what a marked unit's stray shot hit. targetDistance < 0: a ground shot (no target).
void LogStray(const char* shooter, const char* action, Stray kind, const char* hit, const float* point,
              float targetDistance) {
  if (!g_log) {
    return;
  }
  const bool ground = targetDistance < 0.0f;
  unsigned& count = kind == Stray::kTarget ? g_counts.target
                    : kind == Stray::kArea ? g_counts.area
                    : ground               ? (hit != nullptr ? g_counts.groundUnit : g_counts.groundNone)
                    : hit != nullptr       ? g_counts.unit
                                           : g_counts.none;
  ++count;
  const unsigned total = g_counts.target + g_counts.area + g_counts.unit + g_counts.none + g_counts.groundUnit +
                         g_counts.groundNone;
  if (total >= g_counts.next) {
    g_counts.next *= 2;
    uhc::Log(L"spreadAnyAccuracy: %u marked shots so far: InstantBallistics %u on the target, %u area damage at "
             L"the point, %u on another unit, %u on nothing; ground shots without DamageArea %u on a unit, %u on "
             L"nothing",
             total, g_counts.target, g_counts.area, g_counts.unit, g_counts.none, g_counts.groundUnit,
             g_counts.groundNone);
  }
  if (g_strayLinesTotal >= kMaxStrayLines) {
    return;
  }
  const char* proto = Field<const char*>(shooter, 0x5C);
  const ActionKey key{proto == nullptr ? -1 : Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)};
  unsigned& lines = g_strayLines[key];
  if (lines >= kStrayLinesPerAction) {
    return;
  }
  ++lines;
  ++g_strayLinesTotal;
  wchar_t what[144] = L"it hits nothing";
  if (kind == Stray::kTarget) {
    swprintf_s(what, L"inside its target's obstruction, the target takes the hit");
  } else if (kind == Stray::kArea) {
    swprintf_s(what, L"the area damage lands there");
  } else if (hit != nullptr) {
    const char* owner = Field<const char*>(hit, 0x44);
    swprintf_s(what, L"it hits unit %d (%hs, player %d, at %.1f, %.1f)", Field<std::int32_t>(hit, 0x10),
               ProtoName(Field<const char*>(hit, 0x5C)), owner == nullptr ? -1 : Field<std::int32_t>(owner, 0),
               static_cast<double>(Field<float>(hit, 0x14)), static_cast<double>(Field<float>(hit, 0x1C)));
  }
  wchar_t off[56] = L" (a ground shot)";
  if (targetDistance >= 0.0f) {
    swprintf_s(off, L" (instant, %.2f m from its target's obstruction)", static_cast<double>(targetDistance));
  }
  uhc::Log(L"spreadAnyAccuracy: shot by unit %d (%hs/%ls) lands at (%.1f, %.1f)%ls: %ls",
           Field<std::int32_t>(shooter, 0x10), ProtoName(proto), ActionName(key.name),
           static_cast<double>(point[0]), static_cast<double>(point[2]), off, what);
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
void UhcSpreadGroundHook();
void UhcSpreadPrecalcHook();
void UhcSpreadInstantHook();
void UhcSpreadApplyHook();

// The precalc hook and the ground hook.
bool __stdcall UhcSpreadIsMarked(const char* shooter) { return IsMarked(shooter); }

bool __stdcall UhcSpreadMarkedGround(const char* shooter) {
  g_ground = IsMarked(shooter);
  return g_ground;
}

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
      wchar_t radius[80] = L"no offset (FUN_004CEF8C found no target)";
      if (g_uhcSpreadRadius >= 0.0f && g_instant && g_aim != nullptr) {
        swprintf_s(radius, L"at (%.1f, %.1f), r = %.2f m", static_cast<double>(g_aim[0]), static_cast<double>(g_aim[2]),
                   static_cast<double>(g_uhcSpreadRadius));
      } else if (g_uhcSpreadRadius >= 0.0f) {
        swprintf_s(radius, L"r = %.2f m", static_cast<double>(g_uhcSpreadRadius));
      }
      uhc::Log(L"spreadAnyAccuracy: shot by unit %d (%hs/%ls): %ls, %ls (SpreadFactor %.2f, MaxSpread %.2f%ls)",
               g_shooter == nullptr ? -1 : Field<std::int32_t>(g_shooter, 0x10), ProtoName(proto),
               ActionName(g_shotKey.name),
               !g_marked   ? L"a miss"
               : g_instant ? L"marked unit, an InstantBallistics shot aimed at the offset point"
               : g_ground  ? L"marked unit, its shot lands at the offset point"
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
  g_ground = false;
  g_instant = false;
  g_aim = nullptr;
  return marked ? kGroundShot : kMiss;
}

// The instant hook, before the offset: true for a marked shooter with a target unit and a
// projectile unit (the instant launch flies only with one); the shooting action's values are
// then selected as for a miss.
bool __stdcall UhcSpreadInstantSelect(const char* projectile, const char* unitAction, const char* shooter,
                                      const char* target) {
  if (target == nullptr || Field<const char*>(projectile, 0x00) == nullptr || !IsMarked(shooter)) {
    return false;
  }
  UhcSpreadSelect(unitAction, shooter);
  g_instant = true;
  return true;
}

// The instant hook, after the offset: an offset shot (r above the stock 1e-6, so the draws ran) is
// remembered for its arrival; then the log and the stock values, as for a miss. The hit result
// stays 1.
void __stdcall UhcSpreadInstantDone(const char* projectile, const float* aim) {
  g_aim = aim;
  if (g_uhcSpreadRadius > 1.0e-6f) {
    g_instantShots.insert(Field<std::int32_t>(Field<const char*>(projectile, 0x00), 0x10));
    while (g_instantShots.size() > kMaxPendingInstant) {
      g_instantShots.erase(g_instantShots.begin());
    }
  }
  UhcSpreadDone();
}

// The applier hook, at the head of FUN_0049BE95(projectile, targetId, point), on every hit or
// landing of every projectile. It changes nothing unless the shooter (still alive) is marked:
// - an InstantBallistics shot (mode 1) that the instant hook offset: the point it flew to
//   [projectile+70h] inside the target's obstruction hits the target as in stock; otherwise, with
//   <DamageArea>, the shot becomes a ground shot (mode 3) at that point, which deals the area
//   damage there; without, it hits the unit at that point, or nothing (a mode-1 shot with no live
//   target deals nothing);
// - a ground shot (mode 3, no target unit) without <DamageArea>: it hits the unit at the point where
//   it lands. With <DamageArea> it stays as it is.
void __stdcall UhcSpreadApply(char* projectile, std::int32_t* targetId, const float** point) {
  if (g_markerType < 0) {
    return;
  }
  const char* action = Field<const char*>(projectile, 0x10);
  if (action == nullptr) {
    return;
  }
  const std::int32_t mode = Field<std::int32_t>(projectile, 0x20);
  const bool instant = ActionFlag(action, kInstantBallistics);
  if (instant ? mode != 1 || g_instantShots.empty() : mode != kGroundShot) {
    return;
  }
  const char* world = World();
  if (world == nullptr) {
    return;
  }
  const char* projectileUnit = Field<const char*>(projectile, 0x00);
  const std::int32_t projectileUnitId = projectileUnit == nullptr ? -1 : Field<std::int32_t>(projectileUnit, 0x10);
  if (instant) {
    const auto pending = g_instantShots.find(projectileUnitId);
    if (projectileUnit == nullptr || pending == g_instantShots.end()) {
      return;
    }
    g_instantShots.erase(pending);
  } else if (*targetId >= 0 && kUnitById(world, *targetId) != nullptr) {
    return;  // a ground shot that hits a unit: as in stock
  } else if (HasDamageArea(action)) {
    return;
  }
  const std::int32_t shooterId = Field<std::int32_t>(projectile, 0x04);
  const char* shooter = kUnitById(world, shooterId);
  if (shooter == nullptr || !IsAlive(shooter) || !IsMarked(shooter)) {
    return;
  }
  if (!instant) {
    const float* landing = *point != nullptr ? *point : reinterpret_cast<const float*>(projectile + 0x70);
    char* hit = UnitAt(world, landing, shooterId, projectileUnitId);
    if (hit != nullptr) {
      *targetId = Field<std::int32_t>(hit, 0x10);
    }
    LogStray(shooter, action, Stray::kUnit, hit, landing, -1.0f);
    return;
  }
  const char* target = *targetId >= 0 ? kUnitById(world, *targetId) : nullptr;
  if (target == nullptr || !IsAlive(target)) {
    return;  // stock: no damage
  }
  const float* aim = reinterpret_cast<const float*>(projectile + 0x70);
  const float distance = ObstructionDistance(target, aim);
  if (distance <= 0.0f) {
    LogStray(shooter, action, Stray::kTarget, target, aim, distance);
    return;
  }
  if (HasDamageArea(action)) {
    g_point[0] = aim[0];
    g_point[1] = aim[1];
    g_point[2] = aim[2];
    *reinterpret_cast<std::int32_t*>(projectile + 0x20) = kGroundShot;
    *targetId = -1;
    *point = g_point;
    LogStray(shooter, action, Stray::kArea, nullptr, aim, distance);
    return;
  }
  char* hit = UnitAt(world, aim, shooterId, projectileUnitId);
  *targetId = hit == nullptr ? -1 : Field<std::int32_t>(hit, 0x10);
  LogStray(shooter, action, Stray::kUnit, hit, aim, distance);
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
                                       &sites::kSpreadDraws, &sites::kIsA, &sites::kSpreadPrecalcGate,
                                       &sites::kSpreadGroundStore, &sites::kSpreadInstantMode,
                                       &sites::kSpreadInstantLaunch, &sites::kSpreadApplierHead,
                                       &sites::kSpreadInstantArrival, &sites::kUnitsNearPoint, &sites::kUnitById,
                                       &sites::kProtoFlag}) ||
      !RequestAbstractUnitType(g_markerName.c_str(), &g_markerType) ||
      !RequestAbstractUnitType("Resource", &g_resourceType) || !OnDatabaseLoad(&ResetForDataLoad) ||
      !AddActionTagHandler(&OnActionTag) || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kSpreadRadius.va, reinterpret_cast<const void*>(&UhcSpreadRadiusHook), 27) ||
      !WriteJmp(sites::kSpreadMissStub.va, reinterpret_cast<const void*>(&UhcSpreadMissHook), 7) ||
      !WriteJmp(sites::kSpreadHitRoll.va, reinterpret_cast<const void*>(&UhcSpreadHitHook), 9) ||
      !WriteJmp(sites::kSpreadGroundStore.va, reinterpret_cast<const void*>(&UhcSpreadGroundHook), 7) ||
      !WriteJmp(sites::kSpreadPrecalcGate.va, reinterpret_cast<const void*>(&UhcSpreadPrecalcHook), 8) ||
      !WriteJmp(sites::kSpreadApplierHead.va, reinterpret_cast<const void*>(&UhcSpreadApplyHook), 6) ||
      !WriteJmp(sites::kSpreadInstantMode.va, reinterpret_cast<const void*>(&UhcSpreadInstantHook), 7)) {
    return Outcome::kFailed;
  }
  Log(L"spreadAnyAccuracy: <MaxSpread> and <SpreadFactor> are read per action (stock 5.0 and 0.25) and every "
      L"miss uses them; units of unittype %hs scatter every precalculated and InstantBallistics shot, and a "
      L"stray shot hits what it lands on%ls (multiplayer unverified)",
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
UhcSpreadIsMarked PROTO STDCALL :DWORD
UhcSpreadMarkedGround PROTO STDCALL :DWORD
UhcSpreadInstantSelect PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD
UhcSpreadInstantDone PROTO STDCALL :DWORD, :DWORD
UhcSpreadApply PROTO STDCALL :DWORD, :DWORD, :DWORD

EXTERNDEF g_uhcSpreadFactor:DWORD       ; float: SpreadFactor of the shot being offset (stock 0.25)
EXTERNDEF g_uhcSpreadMax:DWORD          ; float: MaxSpread of the shot being offset (stock 5.0)
EXTERNDEF g_uhcSpreadRadius:DWORD       ; float: the radius the offset used, for the log

.data
afterRoll           dd 00499899h    ; mov [esi+20h],ebx: the projectile's hit result
missOffsetFn        dd 004CEF8Ch    ; FUN_004CEF8C, bool thiscall(projectile, Vector* point), ret 4
radiusCheck         dd 004CF026h    ; fld [esp+0Ch] / fcomp [1e-6]: the stock "r > 0" test
afterGround         dd 004C4DF3h    ; jmp 4998A7h, after the store of the ground shot
precalcGo           dd 004997B6h    ; test edi,edi: the precalculated block's next test
precalcSkip         dd 004998A7h    ; past the block
instantGo           dd 004998A0h    ; mov edi,[esp+0ECh]: the launch after the mode store
applierGo           dd 0049BE9Bh    ; mov edx,[0C66234h]: the applier after its sub esp,1D8h

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

; Replaces mov [esi+20h],3 (7 bytes) at 0x4C4DEC, where a TargetGround shot leaves its ground lead, in
; the launch's frame (see the hit hook): [esp+28h] = the impact point. A marked shooter's point moves
; as a miss's does, by FUN_004CEF8C with the action's values; the shot stays a ground shot. Everything
; is saved around the call, so the continuation sees what it sees in stock.
UhcSpreadGroundHook PROC
    TRACE_ONCE "spreadAnyAccuracy ground shot (0x4C4DEC)"
    mov dword ptr [esi+20h], 3          ; stolen
    pushad
    push dword ptr [esp+20h+0E8h]       ; the shooting unit
    call UhcSpreadMarkedGround
    test al, al
    popad
    je done
    pushad
    push dword ptr [esp+20h+0E8h]       ; the shooting unit
    push dword ptr [esp+24h+18h]        ; the unit action
    call UhcSpreadSelect
    lea eax, dword ptr [esp+20h+28h]    ; the impact point
    push eax
    mov ecx, esi                        ; the projectile
    call missOffsetFn
    call UhcSpreadDone
    popad
done:
    jmp afterGround
UhcSpreadGroundHook ENDP

; Replaces test al,al / je 4998A7h (8 bytes) at 0x4997AE, the test of the cfg var ballisticPrecalcHits,
; with EBX = the unit action and the frame of the hit hook. With the var off, a marked shooter still
; goes through the precalculated block, so its shots scatter. EAX, ECX and EDX are free: the block
; writes them first.
UhcSpreadPrecalcHook PROC
    test al, al                         ; stolen
    jne go
    TRACE_ONCE "spreadAnyAccuracy precalc off (0x4997AE)"
    pushad
    push dword ptr [esp+20h+0E8h]       ; the shooting unit
    call UhcSpreadIsMarked
    test al, al
    popad
    jne go
    jmp precalcSkip
go:
    jmp precalcGo
UhcSpreadPrecalcHook ENDP

; Replaces mov [esi+20h],1 (7 bytes) at 0x4A9455, where an InstantBallistics shot leaves the
; precalculated block (the jne at 0x499801, its only branch) before the stock jmp 4998A0h, in the
; launch's frame (see the hit hook: [esp+18h] the unit action, [esp+0E8h] the shooting unit,
; [esp+0ECh] the target unit, [esp+28h] the impact point). For a marked shooter with a target, the
; point moves as a miss's does, by FUN_004CEF8C with the action's values; the instant launch
; 0x4A958F then copies it to [projectile+70h], where the shot flies. The mode stays 1: the
; applier hook decides at the arrival what the shot hits. Everything is saved around the calls,
; and the continuation 0x4998A0 reads no flag before writing them.
UhcSpreadInstantHook PROC
    TRACE_ONCE "spreadAnyAccuracy instant shot (0x4A9455)"
    mov dword ptr [esi+20h], 1          ; stolen
    pushad
    push dword ptr [esp+20h+0ECh]       ; the target unit (or 0)
    push dword ptr [esp+24h+0E8h]       ; the shooting unit
    push dword ptr [esp+28h+18h]        ; the unit action
    push esi                            ; the projectile
    call UhcSpreadInstantSelect         ; AL = 1: offset this shot (the values are selected)
    test al, al
    popad
    je done
    pushad
    lea eax, dword ptr [esp+20h+28h]    ; the impact point
    push eax
    mov ecx, esi                        ; the projectile
    call missOffsetFn
    lea eax, dword ptr [esp+20h+28h]    ; the impact point, now offset
    push eax
    push esi
    call UhcSpreadInstantDone           ; the log, the shot remembered, the stock values back
    popad
done:
    jmp instantGo
UhcSpreadInstantHook ENDP

; Replaces sub esp,1D8h (6 bytes) at 0x49BE95, the head of the attack applier FUN_0049BE95
; (thiscall(projectile, targetId, point), ret 8; every caller enters at its head). ECX = the
; projectile, [esp+4] the target ID, [esp+8] the point. The C++ call may rewrite those two
; arguments and the projectile's mode [ecx+20h], so that a marked unit's stray shot hits what it
; lands on; the stock body then runs on them. The flags are free at a function's head.
UhcSpreadApplyHook PROC
    TRACE_ONCE "spreadAnyAccuracy attack applier (0x49BE95)"
    pushad
    lea eax, dword ptr [esp+20h+8]      ; the point argument
    push eax
    lea eax, dword ptr [esp+24h+4]      ; the target ID argument
    push eax
    push ecx                            ; the projectile
    call UhcSpreadApply
    popad
    sub esp, 1D8h                       ; stolen
    jmp applierGo
UhcSpreadApplyHook ENDP

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

## containedUnitsROF

Contract: [containedUnitsROF](../porting-to-another-dll.md#containedunitsrof).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `XmlText` `0x402733` (9 B), `RofWaitA` `0x48A821` (23 B), `RofWaitB` `0x48A99A` (23 B), `RofWaitC` `0x48EA0C` (23 B), `RofShot` `0x48F8AE` (64 B), `RofDelay` `0x48FA69` (42 B), `RofAnim` `0x4A1185` (26 B), `XmlAttribute` `0x598F37` (16 B), `RofNextChild` `0x5FA126` (4 B), `DotProtoActionCall` `0x5FA20E` (5 B), `TacticsActionCall` `0x5FA60A` (25 B), `RofScaleTag` `0x5FEDFC` (39 B).

### src/features/containedrof.cpp

```cpp
// containedUnitsROF: <ScaleByContainedUnits target="ROF"> makes an attack fire faster with the units inside.
//
// Stock: the tactics tag ScaleByContainedUnits (handler 0x5FEDFC, bit 18 of the action's flag bytes) multiplies
// an attack's DAMAGE by the unit's contained count [unit+74h], at most DamageFactorCap [action+48h] when that is
// above 0 (the projectile launch, 0x4996C7). Its text is read as an integer and only 1 sets the bit: an empty tag
// clears it. The XML attribute "target" is not read.
//
// With this key, the handler reads the attribute. target="ROF" (any case): the action's interval is divided by
// the units inside, at most DamageFactorCap when the action has one; the damage is the stock one (bit 18 is
// cleared), and the action is active only with someone inside (bit 17, ActiveIfContainsUnits, is set), so an
// empty building does not fire. An empty tag with the attribute turns it on; a text of 0 turns it off. No
// attribute, or target="Damage": stock. Gather actions are autoGatherScaleByContained's.
//
// The interval: every attack action (HandAttack, RangedAttack and the other types of the class, vtable 0xB96278)
// waits through 0x48FA69(action manager, ms), which also applies ROF modifiers. Five reads of the tactics ROF
// [action+34h] feed it or the attack's animation rate; the hooks in hooks/containedrof_hooks.asm pass each one
// through UhcContainedRofScale. An override ROF ([unitAction+6Ch]+28h, set by something other than the tactics)
// is not scaled.
#include <windows.h>

#include <compare>
#include <cstdint>
#include <cstring>
#include <cwctype>
#include <map>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
void UhcContainedRofTagHook();
void UhcContainedRofWaitAHook();
void UhcContainedRofWaitBHook();
void UhcContainedRofWaitCHook();
void UhcContainedRofShotHook();
void UhcContainedRofAnimHook();
}

// Entries in the table, read by the hooks to skip the call when no action has the attribute.
extern "C" std::int32_t g_uhcContainedRofCount = 0;

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
constexpr std::uint32_t kFromProtoAction = 0x005FA213;
constexpr unsigned kMaxTagLines = 200;
constexpr unsigned kMaxInvalidLines = 50;
constexpr unsigned kMaxIntervalLines = 100;

// Flag bits of an action, in its bytes [+64h] (count of bits [+68h]).
constexpr std::int32_t kActiveIfContains = 17;  // <ActiveIfContainsUnits>, set at 0x5FEDD3
constexpr std::int32_t kScaleByContained = 18;  // <ScaleByContainedUnits>, set at 0x5FEE1A

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);

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

bool FlagBit(const char* action, std::int32_t bit) {
  if (Field<std::int32_t>(action, 0x68) <= bit) {
    return false;
  }
  const auto* bytes = Field<const std::uint8_t*>(action, 0x64);
  return (bytes[bit >> 3] & (1u << (bit & 7))) != 0;
}

void SetFlagBit(const char* action, std::int32_t bit, bool on) {
  auto* bytes = Field<std::uint8_t*>(action, 0x64);
  if (on) {
    bytes[bit >> 3] = static_cast<std::uint8_t>(bytes[bit >> 3] | (1u << (bit & 7)));
  } else {
    bytes[bit >> 3] = static_cast<std::uint8_t>(bytes[bit >> 3] & ~(1u << (bit & 7)));
  }
}

// Every player's copy of a proto and of its actions keeps the proto ID [proto+4] and the action's name index
// [action+4] (as for spreadAnyAccuracy), so the key finds the entry from the copy a unit attacks with.
struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Entry {
  bool setActive = false;  // bit 17 was clear and this key set it
  std::int32_t lastInterval = -1;  // "log": the last interval logged; only a change is logged
};

// Filled while the data loads and read on the game thread at each attack; cleared on every data load.
std::map<ActionKey, Entry> g_entries;
bool g_log = false;
unsigned g_tagLines = 0;
unsigned g_invalidLines = 0;
unsigned g_intervalLines = 0;

void SyncCount() { g_uhcContainedRofCount = static_cast<std::int32_t>(g_entries.size()); }

// A ROF entry of this action is dropped by a later tag of the same action (a protoy <ProtoAction> after its
// tactics <action>): the last tag wins, as for the stock bit.
void Drop(const ActionKey& key, const char* action) {
  const auto found = g_entries.find(key);
  if (found == g_entries.end()) {
    return;
  }
  if (found->second.setActive) {
    SetFlagBit(action, kActiveIfContains, false);
  }
  g_entries.erase(found);
  SyncCount();
}

bool IsBlank(const wchar_t* text) {
  if (text == nullptr) {
    return true;
  }
  while (*text != L'\0') {
    if (!std::iswspace(*text)) {
      return false;
    }
    ++text;
  }
  return true;
}

// The attribute's value, or nullptr without one. The name is tried as written in the request and capitalised.
const char* TargetAttribute(const char* node) {
  for (const char* name : {"target", "Target", "TARGET"}) {
    const void* text = nullptr;
    if (kXmlAttribute(node, name, &text) && text != nullptr) {
      const char* value = kXmlText(text);
      return value != nullptr ? value : "";
    }
  }
  return nullptr;
}

void ResetForDataLoad(char*) {
  g_entries.clear();
  SyncCount();
  g_tagLines = 0;
  g_invalidLines = 0;
  g_intervalLines = 0;
}

}  // namespace

extern "C" {

// From the hook in the ScaleByContainedUnits handler (0x5FEE0C), after the stock read of the text into value
// (0 when it is not a number). node is the tag, proto and action the parser's arguments, returnAddress the
// parser's caller. Returns 1 when the tag is handled here (the hook goes on to the next child), 0 for the stock
// code (bit 18 from value).
std::int32_t __stdcall UhcContainedRofTag(const char* node, const char* proto, char* action, std::int32_t value,
                                          std::uint32_t returnAddress) {
  if (node == nullptr || proto == nullptr || action == nullptr) {
    return 0;
  }
  const ActionKey key{Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)};
  const wchar_t* source = returnAddress == kFromProtoAction ? L"protoy" : L"tactics";
  const char* target = TargetAttribute(node);
  if (target == nullptr || _stricmp(target, "Damage") == 0) {
    Drop(key, action);
    return 0;
  }
  if (_stricmp(target, "ROF") != 0) {
    Drop(key, action);
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"containedUnitsROF: %hs/%ls (%ls): target=\"%hs\" is neither ROF nor Damage; the stock tag",
               ProtoName(proto), ActionName(key.name), source, target);
    }
    return 0;
  }
  if (Field<std::int32_t>(action, 0x68) <= kScaleByContained) {
    return 0;  // not an action's flag set: never seen
  }
  const wchar_t* text = Field<const wchar_t*>(node, 0x14);
  const bool on = IsBlank(text) || value == 1;
  if (!on) {
    Drop(key, action);
    SetFlagBit(action, kScaleByContained, false);
    return 1;
  }
  if (key.name < 0) {
    // Only possible in a tactics <action> whose <name> comes later.
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"containedUnitsROF: %hs (%ls): <ScaleByContainedUnits target=\"ROF\"> before the action's <name>; "
               L"the stock tag (put <name> first)",
               ProtoName(proto), source);
    }
    return 0;
  }
  SetFlagBit(action, kScaleByContained, false);
  auto [entry, added] = g_entries.try_emplace(key);
  if (added) {
    entry->second.setActive = !FlagBit(action, kActiveIfContains);
    SyncCount();
  }
  SetFlagBit(action, kActiveIfContains, true);
  if (g_log && g_tagLines < kMaxTagLines) {
    ++g_tagLines;
    uhc::Log(L"containedUnitsROF: %hs/%ls (%ls): the interval is divided by the units inside", ProtoName(proto),
             ActionName(key.name), source);
  }
  return 1;
}

// From the five ROF reads: unitAction is the attack's unit action ([+4] its tactics action, [+10h] its unit),
// rof the tactics ROF in ms (above 0). Returns the interval to use.
std::int32_t __stdcall UhcContainedRofScale(const char* unitAction, std::int32_t rof) {
  if (unitAction == nullptr || rof <= 0) {
    return rof;
  }
  const char* action = Field<const char*>(unitAction, 0x04);
  const char* unit = Field<const char*>(unitAction, 0x10);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (action == nullptr || proto == nullptr) {
    return rof;
  }
  const auto found = g_entries.find(ActionKey{Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)});
  if (found == g_entries.end()) {
    return rof;
  }
  // The stock damage factor's rule (0x4996C7..0x49970A): the count, or the cap when the count is above it and
  // the cap is above 0. Nobody inside: the action is inactive (bit 17), unless a later <ActiveIfContainsUnits>0
  // cleared it; then the stock interval.
  const std::int32_t inside = Field<std::int32_t>(unit, 0x74);
  const float cap = Field<float>(action, 0x48);
  double factor = static_cast<double>(inside);
  if (cap > 0.0f && factor > static_cast<double>(cap)) {
    factor = static_cast<double>(cap);
  }
  if (!(factor > 0.0)) {
    return rof;
  }
  double scaled = static_cast<double>(rof) / factor;
  if (scaled > 2.0e9) {
    scaled = 2.0e9;
  }
  std::int32_t interval = static_cast<std::int32_t>(scaled);
  if (interval < 1) {
    interval = 1;
  }
  if (g_log && found->second.lastInterval != interval && g_intervalLines < kMaxIntervalLines) {
    found->second.lastInterval = interval;
    ++g_intervalLines;
    uhc::Log(L"containedUnitsROF: %hs/%ls (unit %d, player %d): %d inside, cap %.2f, ROF %d -> %d ms",
             ProtoName(proto), ActionName(Field<std::int32_t>(action, 0x04)), Field<std::int32_t>(unit, 0x10),
             Field<std::int32_t>(Field<const char*>(unit, 0x44), 0), inside, static_cast<double>(cap), rof, interval);
  }
  return interval;
}
}

namespace uhc {

Outcome ApplyContainedUnitsROF(const Config& config) {
  const Config::Args* args = config.First("containedUnitsROF");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"containedUnitsROF: unexpected argument %hs (only \"log\"); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("containedUnitsROF",
                 {&sites::kRofScaleTag, &sites::kRofNextChild, &sites::kDotProtoActionCall, &sites::kTacticsActionCall,
                  &sites::kXmlAttribute, &sites::kXmlText, &sites::kRofWaitA, &sites::kRofWaitB, &sites::kRofWaitC,
                  &sites::kRofShot, &sites::kRofAnim, &sites::kRofDelay}) ||
      !OnDatabaseLoad(&ResetForDataLoad)) {
    return Outcome::kFailed;
  }
  // cmp dword ptr [esp+10h],1 / mov eax,[ebp+64h] at 0x5FEE0C (8 B); the hook re-executes them for the stock tag.
  // The ROF reads: mov r,[r+34h] / test r,r (5 B) at 0x48A821, 0x48A99A and 0x48EA0C; mov eax,[eax+34h] /
  // cmp eax,ebx (5 B) at 0x48F8B5; mov ebx,[eax+34h] / mov eax,[esi+6Ch] (6 B) at 0x4A1189.
  if (!WriteJmp(0x005FEE0C, reinterpret_cast<const void*>(&UhcContainedRofTagHook), 8) ||
      !WriteJmp(0x0048A821, reinterpret_cast<const void*>(&UhcContainedRofWaitAHook), 5) ||
      !WriteJmp(0x0048A99A, reinterpret_cast<const void*>(&UhcContainedRofWaitBHook), 5) ||
      !WriteJmp(0x0048EA0C, reinterpret_cast<const void*>(&UhcContainedRofWaitCHook), 5) ||
      !WriteJmp(0x0048F8B5, reinterpret_cast<const void*>(&UhcContainedRofShotHook), 5) ||
      !WriteJmp(0x004A1189, reinterpret_cast<const void*>(&UhcContainedRofAnimHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"containedUnitsROF: attacks with <ScaleByContainedUnits target=\"ROF\"> fire faster with the units inside "
      L"(multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/containedrof_hooks.asm

```asm
; Hooks for containedUnitsROF (features/containedrof.cpp). Each is entered through a jmp written over the
; stock code and leaves through an explicit jmp to a verified continuation (docs/engine-symbols.md,
; "Garrison scaling").
.686
.model flat, c
option casemap :none

include common.inc

UhcContainedRofTag PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
UhcContainedRofScale PROTO STDCALL :DWORD, :DWORD

EXTERNDEF g_uhcContainedRofCount:DWORD     ; actions with target="ROF"; 0: the hooks skip the call

.data
tagStock        dd 005FEE14h    ; jne 5FE713h: the stock handler's test of the value
tagNext         dd 005FA126h    ; mov eax,[esp+1Ch]: the parser's next child
waitA           dd 0048A826h    ; jbe 4A86C6h
waitB           dd 0048A99Fh    ; jbe 4B33D5h
waitC           dd 0048EA11h    ; jbe 4A857Fh
shotNext        dd 0048F8BAh    ; jbe 48F8BEh
animNext        dd 004A118Fh    ; test eax,eax (the override ROF [[esi+6Ch]+28h])

.code

; Replaces cmp dword ptr [esp+10h],1 / mov eax,[ebp+64h] (8 bytes) at 0x5FEE0C, in the ScaleByContainedUnits
; handler of the action parser FUN_005F98A0, after the stock read of the text into [esp+10h] (0 when it is not a
; number). EDI = the tag's node, EBP = the action; the parser's arguments are at [esp+0C4h] (proto) and
; [esp+0C8h] (action), its return address at [esp+0C0h] (0x5FA213 a protoy <ProtoAction>, 0x5FA623 a tactics
; <action>; the frame of the action tag hook at 0x5FA11E, same depth). EAX and the flags are free at both
; continuations: the stock test sets them, and the next-child code overwrites them.
UhcContainedRofTagHook PROC
    TRACE_ONCE "containedUnitsROF tag (0x5FEE0C)"
    mov eax, dword ptr [esp+0C0h]
    cmp eax, 005FA213h
    je dispatch
    cmp eax, 005FA623h
    jne stock
dispatch:
    pushad
    push eax                            ; return address
    push dword ptr [esp+24h+10h]        ; the stock value
    push ebp                            ; action (the handler's own, also [esp+0C8h])
    push dword ptr [esp+2Ch+0C4h]       ; proto
    push edi                            ; the tag's node
    call UhcContainedRofTag
    mov dword ptr [esp+1Ch], eax        ; popad's EAX
    popad
    test eax, eax
    jne handled
stock:
    cmp dword ptr [esp+10h], 1          ; stolen 0x5FEE0C
    mov eax, dword ptr [ebp+64h]        ; stolen 0x5FEE11
    jmp tagStock
handled:
    jmp tagNext
UhcContainedRofTagHook ENDP

; The three waits after an attack that did not fire (the attack update FUN_0048A330 and the attack step at
; 0x48E9DB), each `mov r,[r+34h] / test r,r` (5 bytes) before `jbe` and the delay call 0x48FA69(action
; manager, ms). The hook re-executes the read, passes the value through UhcContainedRofScale and re-executes the
; test, so the jbe sees the stock flags. Nothing else changes: pushad/popad keep every other register.

; 0x48A821: EDI = the tactics action ([esi+4]), ESI = the unit action.
UhcContainedRofWaitAHook PROC
    TRACE_ONCE "containedUnitsROF wait (0x48A821)"
    mov edi, dword ptr [edi+34h]        ; stolen 0x48A821
    cmp g_uhcContainedRofCount, 0
    je done
    pushad
    push edi
    push esi
    call UhcContainedRofScale
    mov dword ptr [esp], eax            ; popad's EDI
    popad
done:
    test edi, edi                       ; stolen 0x48A824
    jmp waitA
UhcContainedRofWaitAHook ENDP

; 0x48A99A: EDI = the tactics action ([esi+4]), ESI = the unit action.
UhcContainedRofWaitBHook PROC
    TRACE_ONCE "containedUnitsROF wait (0x48A99A)"
    mov edi, dword ptr [edi+34h]        ; stolen 0x48A99A
    cmp g_uhcContainedRofCount, 0
    je done
    pushad
    push edi
    push esi
    call UhcContainedRofScale
    mov dword ptr [esp], eax            ; popad's EDI
    popad
done:
    test edi, edi                       ; stolen 0x48A99D
    jmp waitB
UhcContainedRofWaitBHook ENDP

; 0x48EA0C: ESI = the tactics action ([ebp+4]), EBP = the unit action.
UhcContainedRofWaitCHook PROC
    TRACE_ONCE "containedUnitsROF wait (0x48EA0C)"
    mov esi, dword ptr [esi+34h]        ; stolen 0x48EA0C
    cmp g_uhcContainedRofCount, 0
    je done
    pushad
    push esi
    push ebp
    call UhcContainedRofScale
    mov dword ptr [esp+4], eax          ; popad's ESI
    popad
done:
    test esi, esi                       ; stolen 0x48EA0F
    jmp waitC
UhcContainedRofWaitCHook ENDP

; Replaces mov eax,[eax+34h] / cmp eax,ebx (5 bytes) at 0x48F8B5, the wait after a shot (ranged, through the
; launch 0x499422, and melee, through 0x4DCFE2, join at 0x48F892): EAX = the tactics action ([ebp+4]), EBP = the
; unit action, EBX = 0. The stock code then waits ROF minus the time since the attack began ([ebp+78h]).
UhcContainedRofShotHook PROC
    TRACE_ONCE "containedUnitsROF shot (0x48F8B5)"
    mov eax, dword ptr [eax+34h]        ; stolen 0x48F8B5
    cmp g_uhcContainedRofCount, 0
    je done
    pushad
    push eax
    push ebp
    call UhcContainedRofScale
    mov dword ptr [esp+1Ch], eax        ; popad's EAX
    popad
done:
    cmp eax, ebx                        ; stolen 0x48F8B8
    jmp shotNext
UhcContainedRofShotHook ENDP

; Replaces mov ebx,[eax+34h] / mov eax,[esi+6Ch] (6 bytes) at 0x4A1189, where an attack begins
; ([esi+78h] = now) and sets its animation rate [unit+0B0h] from the ROF: EAX = the tactics action ([esi+4]),
; ESI = the unit action. The flags are free: test eax,eax follows.
UhcContainedRofAnimHook PROC
    TRACE_ONCE "containedUnitsROF attack start (0x4A1189)"
    mov ebx, dword ptr [eax+34h]        ; stolen 0x4A1189
    cmp g_uhcContainedRofCount, 0
    je done
    pushad
    push ebx
    push esi
    call UhcContainedRofScale
    mov dword ptr [esp+10h], eax        ; popad's EBX
    popad
done:
    mov eax, dword ptr [esi+6Ch]        ; stolen 0x4A118C
    jmp animNext
UhcContainedRofAnimHook ENDP

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

void ChangeAccuracy(char* action, const char* baseAction, const char*, float amount, std::uint8_t relativity,
                    bool unapply) {
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

// For snareValues: a modifier that is a snare, by the same test.
extern "C" bool __stdcall UhcIsSnareModifier(const char* action) { return IsSnare(action); }

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

## snareValues

Contract: [snareValues](../porting-to-another-dll.md#snarevalues).

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`techsubtypes.h`](helpers.md#tech-subtypes), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `SnareStatsSumCall` `0x49F26A` (5 B), `SnareDurationPush` `0x4DD207` (5 B), `SnareCreateTail` `0x4DD20C` (33 B).

### src/features/snarevalues.cpp

```cpp
// snareValues: the slowdown of <TargetSpeedBoost> by action and by tech.
//
// Stock has two literals, 0.65 and 3000 ms, in the arguments of the creator 0x4DD22D at 0x4DD201. The key
// takes over from 0x4DD207, after the part cantBeSlowed writes, and pushes the action's values:
//   <SnareFactor>0.3</SnareFactor>       the speed factor, from 0 to 10
//   <SnareDuration>6</SnareDuration>     seconds, above 0
// in a <ProtoAction> or a tactics <action> that has <TargetSpeedBoost>. The Data subtypes SnareFactor and
// SnareDuration change them for one player's copy of the action, through the stock value function, from
// the tag's value as base. A tech that leaves a duration of 0 or less means no snare: the creator takes a
// duration of 0 as a modifier with no end.
//
// With `strongest`, of the snares on a unit the slowest counts. The sum stops at the first exclusive modifier, so
// stock lets the oldest snare hide a stronger one. The unit's recompute has one call of the velocity sum, 0x49F26A,
// with the list of its modifiers, which it builds each time. The key puts the strongest snare in the place of the
// first one, then runs the sum. Nothing is kept: when a snare ends, the next recompute finds the next strongest, so
// durations need no care, and <AttachSnare> counts too, as it is the same modifier.
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <unordered_map>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

extern "C" void UhcSnareValuesHook();
extern "C" bool __stdcall UhcIsSnareModifier(const char* action);  // snare.cpp

namespace {

constexpr float kStockFactor = 0.65f;
constexpr float kStockSeconds = 3.0f;
constexpr int kMaxLogLines = 200;

using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);

struct ModifierArray {
  char** data;
  std::int32_t count;
};

using VelocitySumFn = void(__thiscall*)(void* record, const char* unit, ModifierArray* list);
const auto kVelocitySum = reinterpret_cast<VelocitySumFn>(0x004B3C48);

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Values {
  float factor = kStockFactor;
  float seconds = kStockSeconds;
};

struct TechValues {
  std::int32_t name;
  Values values;
};

std::map<ActionKey, Values> g_values;                   // by proto and action, from the data
std::unordered_map<const char*, TechValues> g_tech;     // by the player's copy of the action
bool g_log = false;
int g_logLines = 0;
int g_strongestLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

Values BaseValues(std::int32_t proto, std::int32_t name) {
  const auto found = g_values.find({proto, name});
  return found == g_values.end() ? Values{} : found->second;
}

void NewDatabase(char*) {
  g_values.clear();
  g_tech.clear();
  g_logLines = 0;
  g_strongestLines = 0;
}

// Takes the call at 0x49F26A.
void __fastcall StrongestSnare(void* record, void*, const char* unit, ModifierArray* list) {
  std::int32_t first = -1;
  std::int32_t best = -1;
  for (std::int32_t i = 0; i < list->count; ++i) {
    if (!UhcIsSnareModifier(list->data[i])) {
      continue;
    }
    if (first < 0) {
      first = i;
      best = i;
    } else if (Field<float>(list->data[i], 0x68) < Field<float>(list->data[best], 0x68)) {
      best = i;
    }
  }
  if (best != first) {
    if (g_log && g_strongestLines < kMaxLogLines) {
      ++g_strongestLines;
      uhc::Log(L"snareValues: unit %d: the strongest snare, %g, over the first, %g", Field<std::int32_t>(unit, 0x10),
               static_cast<double>(Field<float>(list->data[best], 0x68)),
               static_cast<double>(Field<float>(list->data[first], 0x68)));
    }
    char* swap = list->data[first];
    list->data[first] = list->data[best];
    list->data[best] = swap;
  }
  kVelocitySum(record, unit, list);
}

void ActionTagRead(const uhc::ActionTag& tag) {
  const bool factor = _wcsicmp(tag.name, L"SnareFactor") == 0;
  if (!factor && _wcsicmp(tag.name, L"SnareDuration") != 0) {
    return;
  }
  wchar_t* end = nullptr;
  const float value = tag.text == nullptr ? -1.0f : std::wcstof(tag.text, &end);
  const std::int32_t name = Field<std::int32_t>(tag.action, 0x04);
  const bool good = tag.text != nullptr && end != tag.text && (factor ? value >= 0.0f && value <= 10.0f : value > 0.0f);
  if (!good || name < 0) {
    uhc::Log(L"snareValues: proto %hs: <%ls> needs %ls, after the action's <Name>; ignored",
             Field<const char*>(tag.proto, 0x10), tag.name, factor ? L"a factor from 0 to 10" : L"seconds above 0");
    return;
  }
  Values& values = g_values[{Field<std::int32_t>(tag.proto, 0x04), name}];
  (factor ? values.factor : values.seconds) = value;
  if (g_log) {
    uhc::Log(L"snareValues: proto %hs, action %d: factor %g, %g s", Field<const char*>(tag.proto, 0x10), name,
             static_cast<double>(values.factor), static_cast<double>(values.seconds));
  }
}

template <bool kFactor>
void Change(char* action, const char*, const char* proto, float amount, std::uint8_t relativity, bool unapply) {
  const std::int32_t name = Field<std::int32_t>(action, 0x04);
  const Values base = BaseValues(Field<std::int32_t>(proto, 0x04), name);
  TechValues& slot = g_tech.emplace(action, TechValues{name, base}).first->second;
  if (slot.name != name) {
    slot = TechValues{name, base};
  }
  float& value = kFactor ? slot.values.factor : slot.values.seconds;
  kEffectValue(relativity, &value, kFactor ? base.factor : base.seconds, amount, unapply);
  if (g_log) {
    uhc::Log(L"snareValues: action %d of proto %d: %ls %g%ls", name, Field<std::int32_t>(proto, 0x04),
             kFactor ? L"factor" : L"duration", static_cast<double>(value), unapply ? L" (removed)" : L"");
  }
}

}  // namespace

// From the hook: the values of the attacker's unit action. *ms 0: no snare.
extern "C" void __stdcall UhcSnareValues(const char* unitAction, float* factor, std::int32_t* ms) {
  Values values;
  const char* tactics = unitAction == nullptr ? nullptr : Field<const char*>(unitAction, 0x04);
  const char* unit = unitAction == nullptr ? nullptr : Field<const char*>(unitAction, 0x10);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (tactics != nullptr && proto != nullptr) {
    const std::int32_t name = Field<std::int32_t>(tactics, 0x04);
    values = BaseValues(Field<std::int32_t>(proto, 0x04), name);
    const auto tech = g_tech.find(tactics);
    if (tech != g_tech.end() && tech->second.name == name) {
      values = tech->second.values;
    }
  }
  *factor = values.factor;
  *ms = values.seconds > 0.0f ? static_cast<std::int32_t>(values.seconds * 1000.0f + 0.5f) : 0;
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"snareValues: a snare of factor %g for %d ms", static_cast<double>(*factor), *ms);
  }
}

namespace uhc {

Outcome ApplySnareValues(const Config& config) {
  const Config::Args* args = config.First("snareValues");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool strongest = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "strongest") == 0) {
      strongest = true;
    } else {
      Log(L"snareValues: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("snareValues", {&sites::kSnareDurationPush, &sites::kSnareCreateTail}) ||
      (strongest && !VerifyAll("snareValues", {&sites::kSnareStatsSumCall})) ||
      !AddActionTagHandler(&ActionTagRead) || !OnDatabaseLoad(&NewDatabase) ||
      !AddTechActionSubtype("SnareFactor", &Change<true>) || !AddTechActionSubtype("SnareDuration", &Change<false>) ||
      !WriteJmp(sites::kSnareDurationPush.va, reinterpret_cast<const void*>(&UhcSnareValuesHook), 5) ||
      (strongest && !WriteCall(sites::kSnareStatsSumCall.va, reinterpret_cast<const void*>(&StrongestSnare)))) {
    return Outcome::kFailed;
  }
  Log(L"snareValues: <SnareFactor>, <SnareDuration> and their Data subtypes are on%ls (multiplayer unverified)",
      strongest ? L", and the strongest snare counts" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/snarevalues_hooks.asm

```asm
; snareValues (src/features/snarevalues.cpp). Entered through a jmp written over the stock code, left
; through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcSnareValues PROTO STDCALL unitAction:DWORD, factor:DWORD, ms:DWORD

.data
snareCreate     dd 004DD22Dh    ; thiscall(unit, stat, value, -1f, -1f, 0, operation, ms, -1, -1, exclusive)
snareExit       dd 0048FA49h    ; pop esi / pop ecx ..., where the snare ends

.code

; Replaces 0x4DD207, push 0BB8h. The stack already has the creator's last three arguments, from stock or
; cantBeSlowed, whose hook continues here. ESI = the target; EBP = the attacker's unit action. The stock
; code from here to the creator is only pushes, so it is done here with the action's values, and the
; flow ends at the exit, as stock's jmp 48FA49h does.
UhcSnareValuesHook PROC
    TRACE_ONCE "snareValues (0x4DD207)"
    sub esp, 8                      ; [esp] the factor, [esp+4] the ms
    lea eax, [esp+4]
    push eax
    lea eax, [esp+4]
    push eax
    push ebp
    call UhcSnareValues
    pop ecx
    pop edx
    test edx, edx
    je none
    push edx
    push 2
    push 0
    push 0BF800000h
    push 0BF800000h
    push ecx
    push 0
    mov ecx, esi
    call snareCreate
    jmp snareExit
none:
    add esp, 0Ch
    jmp snareExit
UhcSnareValuesHook ENDP

END
```

## stealthTargeting

Contract: [stealthTargeting](../porting-to-another-dll.md#stealthtargeting).

Sites: `AttackActionForTarget` `0x489ECC` (14 B), `FootprintVisibility` `0x493040` (16 B), `FootprintHiddenTest` `0x493201` (11 B), `AttackActionNone` `0x4974C1` (11 B), `FootprintHiddenSkip` `0x4E0B1F` (13 B).

### src/features/stealthtarget.cpp

```cpp
// stealthTargeting: a unit in stealth stays hidden from enemies, large units too, and is no target for a
// player that does not see it.
//
// The stock Stealth action (protoaction type 47h, vtable 0xB982A8) sets unit state bit 42h while the unit
// is in its stealth tactic (0x9E8AE5) and clears it when the action ends (0x9E892F); a unit of
// AbstractCanSeeStealth in its LOS forces it out of the tactic (0x9E8C12..0x9E8CC7). The per-unit
// visibility update 0x48679A passes the bit (0x486888) to the per-player visibility 0x486B1A, which writes
// the mask of the players that see the unit, [[unit+B4h]+ACh] (0x486A60). Its small-unit branch skips every
// non-allied player for a stealthed unit (0x486CD0 -> 0x4E0B12). Its footprint branch (0x493040), taken
// when an obstruction radius is over 1.0 (ships, a submarine), never reads the argument: the next
// instruction reuses its stack slot. So every enemy whose LOS covers a large stealthed unit sees it, its
// units attack it on their own, and the AI finds it and sends units.
//
// Two hooks (hooks/stealthtarget_hooks.asm):
// - at 0x493040, a stealthed unit sets the branch's own "only allies see it" byte, so the branch hides it
//   from non-allied players as the small-unit branch does;
// - at the head of 0x489ECC, which the auto-attack search, the unit queries that filter on "attackable"
//   (0x499CE4) and the work orders ask for the attack action an attacker would use on a target, a
//   stealthed target that the attacker's player does not see gets -1, "no attack action". That covers an
//   order on a unit the player saw before it went into stealth (the AI's ships tried it in the test).
// Both read only simulation state (the unit's state bits and the visibility mask), the same on every machine.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcStealthTargetHook();
extern "C" void UhcStealthFootprintHook();

namespace {

constexpr int kMaxLogLines = 200;

bool g_log = false;
int g_logLines = 0;

std::int32_t UnitId(const char* unit) { return *reinterpret_cast<const std::int32_t*>(unit + 0x10); }

std::int32_t PlayerId(const char* unit) {
  const char* player = *reinterpret_cast<const char* const*>(unit + 0x44);
  return player == nullptr ? -1 : *reinterpret_cast<const std::int32_t*>(player);
}

std::int32_t ProtoId(const char* unit) {
  const char* proto = *reinterpret_cast<const char* const*>(unit + 0x5C);
  return proto == nullptr ? -1 : *reinterpret_cast<const std::int32_t*>(proto + 8);
}

}  // namespace

// From the hook, only for a target whose stealth bit is set. True: the attacker's player does not see the
// target, so it gets no attack action.
extern "C" bool __stdcall UhcStealthHidden(const char* attacker, const char* target) {
  if (attacker == nullptr || target == nullptr) {
    return false;
  }
  const std::int32_t player = PlayerId(attacker);
  if (player < 0 || player >= 32 || player == PlayerId(target)) {
    return false;
  }
  const char* visual = *reinterpret_cast<const char* const*>(target + 0xB4);
  if (visual == nullptr) {
    return false;
  }
  const std::uint32_t seenBy = *reinterpret_cast<const std::uint32_t*>(visual + 0xAC);
  if ((seenBy & (1u << player)) != 0) {
    return false;
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"stealthTargeting: unit %d (proto %d, player %d) cannot target stealthed unit %d (proto %d, player %d)",
             UnitId(attacker), ProtoId(attacker), player, UnitId(target), ProtoId(target), PlayerId(target));
  }
  return true;
}

namespace uhc {

Outcome ApplyStealthTargeting(const Config& config) {
  const Config::Args* args = config.First("stealthTargeting");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"stealthTargeting: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("stealthTargeting", {&sites::kAttackActionForTarget, &sites::kAttackActionNone,
                                      &sites::kFootprintVisibility, &sites::kFootprintHiddenTest,
                                      &sites::kFootprintHiddenSkip}) ||
      !WriteJmp(sites::kFootprintVisibility.va, reinterpret_cast<const void*>(&UhcStealthFootprintHook), 8) ||
      !WriteJmp(sites::kAttackActionForTarget.va, reinterpret_cast<const void*>(&UhcStealthTargetHook), 7)) {
    return Outcome::kFailed;
  }
  Log(L"stealthTargeting: stealthed units, large ones too, are hidden from enemies and no target for a player that "
      L"does not see them (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/stealthtarget_hooks.asm

```asm
; stealthTargeting (src/features/stealthtarget.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to a verified continuation, or returns -1 as the stock failure path does.
.686
.model flat, c
option casemap :none

include common.inc

UhcStealthHidden PROTO STDCALL attacker:DWORD, target:DWORD

.data
attackActionNext dd 00489ED3h   ; push esi, after the four instructions this hook re-executes
footprintNext    dd 00493048h   ; fnstcw [esp+68h], after the two instructions this hook re-executes

.code

; Replaces 0x493040..0x493047 (fld dword [esp+4Ch] / movzx edx, byte [esi+0Dh]), the start of the footprint
; branch of the per-player visibility 0x486B1A, taken for a proto whose obstruction radius is over 1.0 (a ship,
; a large unit). That branch never reads the stealth argument [esp+68h] (the next instruction overwrites its
; slot), so enemies saw a large stealthed unit. Here a set stealth byte sets the local [esp+38h], the "only
; allies see it" byte that the branch's player loop already honours (0x493201 -> 0x4E0B1F: a non-allied
; player is skipped; an ally goes on to its LOS test), the same outcome as the stealth test of the small-unit
; branch (0x486CD0 -> 0x4E0B12). Flags and registers are as the re-executed instructions leave them.
UhcStealthFootprintHook PROC
    TRACE_ONCE "stealthTargeting footprint (0x493040)"
    cmp byte ptr [esp+68h], 0
    je go
    mov byte ptr [esp+38h], 1
go:
    fld dword ptr [esp+4Ch]
    movzx edx, byte ptr [esi+0Dh]
    jmp footprintNext
UhcStealthFootprintHook ENDP

; Replaces 0x489ECC..0x489ED2 (push ecx / push ebx / push ebp / mov ebp,[esp+10h]), the head of
; int __thiscall(tactic, attacker, target, ...), ret 1Ch: the attack action the attacker would use on the
; target, -1 for none. On entry [esp+4] = attacker, [esp+8] = target, ECX = this. A target whose unit state
; bit 42h (stealth, set by the Stealth action's update 0x9E8AE5) is clear goes on at once. For a stealthed
; one, UhcStealthHidden decides; when it is hidden from the attacker's player, the function returns -1 as
; its own failure path 0x4974C1 does (or eax,-1 / ret 1Ch), and EBX, ESI, EDI, EBP are untouched.
UhcStealthTargetHook PROC
    TRACE_ONCE "stealthTargeting (0x489ECC)"
    mov eax, [esp+8]
    test eax, eax
    je stock
    cmp dword ptr [eax+8], 42h      ; the state bitset's bit count
    jbe stock
    mov edx, [eax+4]
    test byte ptr [edx+8], 4        ; bit 42h
    je stock
    push ecx
    push eax                        ; target
    push dword ptr [esp+0Ch]        ; attacker ([esp+4] on entry)
    call UhcStealthHidden
    pop ecx
    test al, al
    jne refuse
stock:
    push ecx
    push ebx
    push ebp
    mov ebp, [esp+10h]
    jmp attackActionNext
refuse:
    or eax, -1
    ret 1Ch
UhcStealthTargetHook ENDP

END
```

## directionalAttack

Contract: [directionalAttack](../porting-to-another-dll.md#directionalattack).

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `UnitById` `0x44CC6D` (58 B), `ProtoFlag` `0x45EE02` (53 B), `DirectionalLaunch` `0x4998A7` (10 B), `DirectionalLaunchCall` `0x49999E` (32 B), `DirectionalTakeDamage` `0x49C05A` (50 B), `UnitsNearPoint` `0x4A1C55` (248 B), `DirectionalTerrainHeight` `0x4C4E62` (56 B), `DirectionalMaxRangeCall` `0x5F8A4A` (12 B).

### src/features/directional.cpp

```cpp
// directionalAttack: a projectile that flies on past its target and hits every unit it flies over, before
// and after the target (a "monster truck" attack, like a Scorpion bolt).
//
// An action (a .tactics <action> or a protoy.xml <ProtoAction>) becomes directional with one of two tags, the
// two variants:
// - <DirectionalAttack>D</DirectionalAttack>: the unit targets and fires at its MaxRange as in stock, and the
//   projectile lands D metres from the shooter (at the target if the target is farther);
// - <DirectionalFiringRange>F</DirectionalFiringRange>: the unit fires at F metres, and the projectile lands
//   at the MaxRange the data gives the action. The action's MaxRange becomes F when the data loads (the call
//   0x5F8A51 of the MaxRange setter in the action parser, or the tag itself when MaxRange came first), so
//   the game targets and fires at F; the landing is the data's MaxRange plus what techs added to the
//   player's copy since (a range tech moves both by the same amount).
// Optional: <DirectionalWidth>W</DirectionalWidth>, metres either side of the flight line that still count as
// flown over (default 0.25), and <DirectionalDamageFactor>X</DirectionalDamageFactor>, the share of the
// attack each unit flown over takes (default 1).
//
// The launch: one hook at 0x4998A7, where every launch path of FUN_004995C7 meets with the impact point and
// the mode final. For a directional action with a target and a projectile unit, the point moves along the
// line from the shooter through it, to the landing distance (its height from the terrain), and the mode
// becomes 3, the ground shot: the projectile flies there and the stock landing applies the attack at the
// point (area damage with <DamageArea>, as a TargetGround shot does). InstantBallistics shots are left alone
// (the instant arrival hits only [projectile+8]).
// The flight: after each world update, each tracked shot's projectile unit (by ID) has moved; the 2D segment
// it flew since the last update is tested against the units near it, and each unit whose obstruction it
// passes within W is hit once, through the stock TakeDamage with the shot's action (damage, bonuses, armor and
// the DamageFlags as for a direct hit). When the projectile unit is gone, the rest of the line to the landing
// point is flown, unless the shot ended far from it (it hit a cliff). Shots are kept by projectile unit ID
// and walked in ID order, so every machine hits the same units in the same order.
#include <windows.h>

#include <algorithm>
#include <cmath>
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <cwctype>
#include <map>
#include <set>
#include <string>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr float kDefaultWidth = 0.25f;
constexpr float kMaxDistance = 300.0f;  // a landing farther than this would leave most maps
constexpr float kMaxWidth = 10.0f;
constexpr float kMaxFactor = 100.0f;
constexpr std::size_t kMaxShots = 512;  // shots in flight; the oldest is dropped beyond
constexpr unsigned kMaxInvalidLines = 50;
constexpr unsigned kMaxLaunchLines = 60;
constexpr unsigned kMaxHitLines = 200;

constexpr std::int32_t kGroundShot = 3;          // [projectile+20h]: lands at the point, the attack applied there
constexpr std::int32_t kInstantBallistics = 22;  // action flag bit (0x5F8D2E)
constexpr std::int32_t kMuteDamage = 6;          // action flag bit, TakeDamage's 10th argument (0x49BFEF)
constexpr std::int32_t kFlagProjectile = 0x0A;   // proto flag "Projectile": the area damage skips these too

struct IdList {
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using ProtoFlagFn = bool(__thiscall*)(const char* proto, std::int32_t flag);
using UnitByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using UnitsNearFn = std::int32_t(__thiscall*)(const char* world, const float* point, float radius, char precise,
                                              IdList* out);
using UnitTestFn = bool(__thiscall*)(const char* unit);
using DistanceFn = float(__thiscall*)(const char* unit, const float* point);
using HeightFn = bool(__thiscall*)(void* terrain, const float* point, float* out, std::int32_t, std::int32_t);
// TakeDamage FUN_0049B3D9 (docs/engine-symbols.md, "Damage and poison"), ret 34h.
using TakeDamageFn = float(__thiscall*)(char* unit, std::int32_t player, std::int32_t proto, char* action,
                                        std::int32_t attacker, float multiplier, float damage, float cap, char p8,
                                        char p9, char p10, char p11, std::int32_t p12, char p13);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kProtoFlag = reinterpret_cast<ProtoFlagFn>(0x0045EE02);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);
const auto kTakeDamage = reinterpret_cast<TakeDamageFn>(0x0049B3D9);
// The MaxRange setter FUN_005FA709 (thiscall(action, float), ret 4): data[0]+8 of the range array
// [action+18h], and data[0]+0Ch too while that one is unset.
using SetMaxRangeFn = void(__thiscall*)(char* action, float value);
const auto kSetMaxRange = reinterpret_cast<SetMaxRangeFn>(0x005FA709);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* World() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

const char* Database() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<UnitTestFn const* const*>(unit))[0xA4 / 4](unit); }

float ObstructionDistance(const char* unit, const float* point) {
  return (*reinterpret_cast<DistanceFn const* const*>(unit))[0xB8 / 4](unit, point);
}

bool ActionFlag(const char* action, std::int32_t bit) {
  if (Field<std::uint32_t>(action, 0x68) <= static_cast<std::uint32_t>(bit)) {
    return false;
  }
  return (Field<const std::uint8_t*>(action, 0x64)[bit >> 3] & (1u << (bit & 7))) != 0;
}

// The action's MaxRange: the first entry of the range array [action+18h] (the setter 0x5FA709 writes its
// +8). 0 without one.
float MaxRange(const char* action) {
  const char* ranges = Field<const char*>(action, 0x18);
  return ranges == nullptr ? 0.0f : Field<float>(ranges, 0x08);
}

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

char* PlayerById(const char* world, std::int32_t id) {
  if (id < 0 || id >= Field<std::int32_t>(world, 0x5C)) {
    return nullptr;
  }
  return Field<char**>(world, 0x58)[id];
}

// The terrain height under (x, z), as the ground lead FUN_004C4DF8 asks it (0x4C4E62: the world's
// [+88h] object, vtable slot 18h). False without terrain.
bool TerrainHeight(const char* world, float* point) {
  void* terrain = Field<void*>(world, 0x88);
  if (terrain == nullptr) {
    return false;
  }
  float height = point[1];
  const auto fn = (*reinterpret_cast<HeightFn const* const*>(terrain))[0x18 / 4];
  if (!fn(terrain, point, &height, 0, 0)) {
    return false;
  }
  point[1] = height;
  return true;
}

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Directional {
  float distance = -1.0f;     // <DirectionalAttack>: the landing distance (variant 1)
  float firingRange = -1.0f;  // <DirectionalFiringRange> (variant 2): the landing is the data's MaxRange
  float dataMaxRange = -1.0f; // variant 2: the MaxRange the data gave, before it became firingRange
  float width = kDefaultWidth;
  float factor = 1.0f;
  bool Enabled() const { return distance >= 0.0f || firingRange >= 0.0f; }
};

// Filled while the data loads, by the action's proto ID and name index (the same in every player's copy).
std::map<ActionKey, Directional> g_actions;
bool g_anyEnabled = false;
// Variant 2: the database actions with <DirectionalFiringRange>, for the MaxRange setter call.
std::map<char*, ActionKey> g_firingActions;
bool g_log = false;
unsigned g_invalidLines = 0;
unsigned g_launchLines = 0;
unsigned g_hitLines = 0;

// One shot in flight.
struct Shot {
  float last[2];         // where the projectile unit was at the last update (x, z); its position at the launch first
  float landing[3];      // the point it lands at
  float dir[2];          // the unit vector from the shooter to the landing point
  float origin[2];       // the shooter's position at the launch
  float landingDistance; // from origin along dir
  float lastStep = 0.0f;
  float width;
  float multiplier;
  std::int32_t shooter;
  std::int32_t player;
  std::int32_t protoId;
  char* action;
  char muted;
  char p10;
  std::int32_t p12;
  std::int32_t target;
  std::set<std::int32_t> hit;  // the units already hit by this shot
};

std::map<std::int32_t, Shot> g_shots;  // by projectile unit ID
std::int32_t g_resourceType = -1;
IdList g_found = {nullptr, 0, 0};
const char* g_tickWorld = nullptr;
std::uint32_t g_tickStep = 0;
std::uint32_t g_tickTime = 0;

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
  *out = value == 0.0f ? 0.0f : value;
  return true;
}

void OnActionTag(const uhc::ActionTag& tag) {
  enum { kDistance, kFiringRange, kWidth, kFactor } which;
  if (_wcsicmp(tag.name, L"DirectionalAttack") == 0) {
    which = kDistance;
  } else if (_wcsicmp(tag.name, L"DirectionalFiringRange") == 0) {
    which = kFiringRange;
  } else if (_wcsicmp(tag.name, L"DirectionalWidth") == 0) {
    which = kWidth;
  } else if (_wcsicmp(tag.name, L"DirectionalDamageFactor") == 0) {
    which = kFactor;
  } else {
    return;
  }
  const wchar_t* source = tag.source == uhc::ActionSource::kTactics ? L"tactics" : L"protoy";
  const ActionKey key{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)};
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  if (key.name < 0) {
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"directionalAttack: %hs (%ls): <%ls> before the action's <name>; ignored (put <name> first)",
               ProtoName(tag.proto), source, tag.name);
    }
    return;
  }
  const float limit = which == kWidth ? kMaxWidth : which == kFactor ? kMaxFactor : kMaxDistance;
  float value = 0.0f;
  if (!ParseValue(tag.text, limit, &value)) {
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"directionalAttack: %hs/%ls (%ls): <%ls>%ls</%ls> is not a number from 0 to %.0f; ignored",
               ProtoName(tag.proto), ActionName(key.name), source, tag.name, text, tag.name,
               static_cast<double>(limit));
    }
    return;
  }
  Directional& entry = g_actions[key];
  switch (which) {
    case kDistance:
      entry.distance = value;
      break;
    case kFiringRange: {
      entry.firingRange = value;
      char* action = const_cast<char*>(tag.action);
      g_firingActions[action] = key;
      // MaxRange read before this tag (it comes later in most data, through the setter call below).
      const char* ranges = Field<const char*>(action, 0x18);
      if (ranges != nullptr && Field<float>(ranges, 0x08) > 0.0f) {
        entry.dataMaxRange = Field<float>(ranges, 0x08);
        kSetMaxRange(action, value);
      }
      break;
    }
    case kWidth:
      entry.width = value;
      break;
    case kFactor:
      entry.factor = value;
      break;
  }
  g_anyEnabled = g_anyEnabled || entry.Enabled();
  if (g_log) {
    uhc::Log(L"directionalAttack: %hs/%ls (%ls): %ls %.2f", ProtoName(tag.proto), ActionName(key.name), source,
             tag.name, static_cast<double>(value));
  }
}

void ResetForDataLoad(char*) {
  g_actions.clear();
  g_firingActions.clear();
  g_anyEnabled = false;
  g_shots.clear();
  g_invalidLines = 0;
  g_launchLines = 0;
  g_hitLines = 0;
}

const Directional* Find(const char* proto, const char* action) {
  if (!g_anyEnabled || proto == nullptr || action == nullptr) {
    return nullptr;
  }
  const auto it = g_actions.find({Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)});
  return it == g_actions.end() || !it->second.Enabled() ? nullptr : &it->second;
}

// The engine's diplomacy filter FUN_0049AEE0, from the shooter's player: DamageFlags at [[action+24h]+4]
// (GAIA 1, Self 2, Ally 4, Enemy 8; FFh when the data sets none), relations at [player+1D4h + 4*id],
// 2 = enemy. It is applied here too so that a unit the attack cannot damage is not hit at all (a hit
// of 0 damage would still make it react).
bool DamageAllowed(const char* world, const Shot& shot, const char* unit) {
  const char* info = Field<const char*>(shot.action, 0x24);
  const char* owner = Field<const char*>(unit, 0x44);
  const char* attacker = PlayerById(world, shot.player);
  if (info == nullptr || owner == nullptr || attacker == nullptr) {
    return false;
  }
  const std::uint8_t flags = Field<std::uint8_t>(info, 0x04);
  const std::int32_t unitPlayer = Field<std::int32_t>(owner, 0x00);
  if (unitPlayer == 0) {
    return (flags & 1) != 0;
  }
  if (unitPlayer == shot.player) {
    return (flags & 2) != 0;
  }
  const bool enemy = unitPlayer > 0 && unitPlayer < 32 &&
                     Field<std::int32_t>(attacker, 0x1D4 + 4 * static_cast<std::uint32_t>(unitPlayer)) == 2;
  return (flags & (enemy ? 8 : 4)) != 0;
}

struct Candidate {
  float along;  // distance along the segment, for the order
  std::int32_t id;
  char* unit;
};

// Hits every unit the segment a -> b passes within the shot's width, once per shot.
void FlySegment(const char* world, std::int32_t projectileId, Shot& shot, const float* a, const float* b) {
  const float sx = b[0] - a[0];
  const float sz = b[1] - a[1];
  const float length2 = sx * sx + sz * sz;
  const float length = std::sqrt(length2);
  float mid[3] = {(a[0] + b[0]) * 0.5f, shot.landing[1], (a[1] + b[1]) * 0.5f};
  kUnitsNear(world, mid, length * 0.5f + shot.width + 0.5f, 1, &g_found);
  std::vector<std::int32_t> ids(g_found.data, g_found.data + g_found.count);
  std::vector<Candidate> hits;
  for (const std::int32_t id : ids) {
    if (id == shot.shooter || id == projectileId || shot.hit.count(id) != 0) {
      continue;
    }
    char* unit = kUnitById(world, id);
    const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    if (proto == nullptr || !IsAlive(unit) || Field<std::int32_t>(unit, 0x6C) != -1 ||
        kProtoFlag(proto, kFlagProjectile)) {
      continue;
    }
    const char* owner = Field<const char*>(unit, 0x44);
    if (owner != nullptr && Field<std::int32_t>(owner, 0) == 0 && g_resourceType >= 0 &&
        kProtoIsType(proto, g_resourceType)) {
      continue;  // a tree, a mine, a hunt
    }
    // The point of the segment nearest the unit's centre.
    const float cx = Field<float>(unit, 0x14);
    const float cz = Field<float>(unit, 0x1C);
    float t = length2 > 0.0f ? ((cx - a[0]) * sx + (cz - a[1]) * sz) / length2 : 0.0f;
    t = std::clamp(t, 0.0f, 1.0f);
    const float q[3] = {a[0] + sx * t, Field<float>(unit, 0x18), a[1] + sz * t};
    if (ObstructionDistance(unit, q) > shot.width || !DamageAllowed(world, shot, unit)) {
      continue;
    }
    hits.push_back({t * length, id, unit});
  }
  std::sort(hits.begin(), hits.end(), [](const Candidate& l, const Candidate& r) {
    return l.along != r.along ? l.along < r.along : l.id < r.id;
  });
  for (const Candidate& c : hits) {
    char* unit = kUnitById(world, c.id);
    if (unit == nullptr || !IsAlive(unit)) {
      continue;  // killed by an earlier hit of this segment
    }
    shot.hit.insert(c.id);
    const bool shooterThere = kUnitById(world, shot.shooter) != nullptr;
    const float dealt = kTakeDamage(unit, shot.player, shot.protoId, shot.action, shot.shooter, shot.multiplier, 0.0f,
                                    0.0f, 0, shot.muted, shot.p10, shooterThere ? 1 : 0, shot.p12, 1);
    if (g_log && g_hitLines < kMaxHitLines) {
      ++g_hitLines;
      const char* owner = Field<const char*>(unit, 0x44);
      uhc::Log(L"directionalAttack: shot %d of unit %d hits unit %d (%hs, player %d%ls) at (%.1f, %.1f): %.1f damage",
               projectileId, shot.shooter, c.id, ProtoName(Field<const char*>(unit, 0x5C)),
               owner == nullptr ? -1 : Field<std::int32_t>(owner, 0), c.id == shot.target ? L", its target" : L"",
               static_cast<double>(Field<float>(unit, 0x14)), static_cast<double>(Field<float>(unit, 0x1C)),
               static_cast<double>(dealt));
    }
  }
}

// After each world update: every shot in flight flies the segment since the last update.
void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_tickWorld || step - g_tickStep > 1 || now < g_tickTime) {
    g_shots.clear();  // another game: these IDs are not its units
  }
  g_tickWorld = world;
  g_tickStep = step;
  g_tickTime = now;
  for (auto it = g_shots.begin(); it != g_shots.end();) {
    Shot& shot = it->second;
    const char* projectile = kUnitById(world, it->first);
    float next[2];
    bool done = false;
    if (projectile == nullptr) {
      // Landed (or ended) during the update: fly on to the landing point if it ended near it.
      const float dx = shot.landing[0] - shot.last[0];
      const float dz = shot.landing[2] - shot.last[1];
      const float remaining = std::sqrt(dx * dx + dz * dz);
      done = true;
      if (remaining > std::max(3.0f * shot.lastStep, 3.0f)) {
        if (g_log && g_launchLines < kMaxLaunchLines) {
          ++g_launchLines;
          uhc::Log(L"directionalAttack: shot %d ended at (%.1f, %.1f), %.1f m short of its landing point (%.1f, %.1f), "
                   L"last step %.2f m; %u unit(s) hit",
                   it->first, static_cast<double>(shot.last[0]), static_cast<double>(shot.last[1]),
                   static_cast<double>(remaining), static_cast<double>(shot.landing[0]),
                   static_cast<double>(shot.landing[2]), static_cast<double>(shot.lastStep),
                   static_cast<unsigned>(shot.hit.size()));
        }
        it = g_shots.erase(it);
        continue;
      }
      next[0] = shot.landing[0];
      next[1] = shot.landing[2];
    } else {
      next[0] = Field<float>(projectile, 0x14);
      next[1] = Field<float>(projectile, 0x1C);
      const float along = (next[0] - shot.origin[0]) * shot.dir[0] + (next[1] - shot.origin[1]) * shot.dir[1];
      if (along >= shot.landingDistance) {
        next[0] = shot.landing[0];  // past the landing point (a bounce): the line ends there
        next[1] = shot.landing[2];
        done = true;
      }
    }
    const float sx = next[0] - shot.last[0];
    const float sz = next[1] - shot.last[1];
    const float stepLength = std::sqrt(sx * sx + sz * sz);
    if (stepLength > 0.0f || done) {
      FlySegment(world, it->first, shot, shot.last, next);
    }
    if (stepLength > 0.0f) {
      shot.lastStep = stepLength;
    }
    shot.last[0] = next[0];
    shot.last[1] = next[1];
    if (done) {
      if (g_log && g_launchLines < kMaxLaunchLines) {
        ++g_launchLines;
        uhc::Log(L"directionalAttack: shot %d reached its landing point (%.1f, %.1f); %u unit(s) hit", it->first,
                 static_cast<double>(shot.landing[0]), static_cast<double>(shot.landing[2]),
                 static_cast<unsigned>(shot.hit.size()));
      }
      it = g_shots.erase(it);
    } else {
      ++it;
    }
  }
}

}  // namespace

extern "C" {
void UhcDirLaunchHook();

// Replaces the action parser's call 0x5F8A51 of the MaxRange setter (ECX = the action, the value on the
// stack): an action with <DirectionalFiringRange> keeps the data's value as its landing distance and gets
// the firing range as its MaxRange.
void __fastcall UhcDirSetMaxRange(char* action, void*, float value) {
  const auto it = g_firingActions.find(action);
  if (it != g_firingActions.end()) {
    const auto entry = g_actions.find(it->second);
    if (entry != g_actions.end() && entry->second.firingRange >= 0.0f) {
      entry->second.dataMaxRange = value;
      if (g_log) {
        uhc::Log(L"directionalAttack: %ls: MaxRange %.2f is the landing distance; the unit fires at %.2f",
                 ActionName(it->second.name), static_cast<double>(value),
                 static_cast<double>(entry->second.firingRange));
      }
      value = entry->second.firingRange;
    }
  }
  kSetMaxRange(action, value);
}

// The launch hook (hooks/directional_hooks.asm), for every projectile launched.
void __stdcall UhcDirLaunch(char* projectile, const char* unitAction, const char* shooter, const char* target,
                            std::int32_t p12, float multiplier, float* point) {
  if (!g_anyEnabled || unitAction == nullptr || shooter == nullptr || target == nullptr) {
    return;
  }
  char* action = Field<char*>(unitAction, 0x04);
  const char* proto = Field<const char*>(shooter, 0x5C);
  const Directional* entry = Find(proto, action);
  if (entry == nullptr || ActionFlag(action, kInstantBallistics)) {
    return;
  }
  const char* projectileUnit = Field<const char*>(projectile, 0x00);
  const char* world = World();
  if (projectileUnit == nullptr || world == nullptr) {
    return;
  }
  const float ox = Field<float>(shooter, 0x14);
  const float oz = Field<float>(shooter, 0x1C);
  const float dx = point[0] - ox;
  const float dz = point[2] - oz;
  const float targetDistance = std::sqrt(dx * dx + dz * dz);
  if (targetDistance < 0.1f) {
    return;
  }
  // Variant 2: the data's MaxRange, moved by what techs added to this player's copy since the load.
  const float wanted = entry->distance >= 0.0f ? entry->distance
                       : entry->dataMaxRange >= 0.0f ? entry->dataMaxRange + MaxRange(action) - entry->firingRange
                                                     : MaxRange(action);
  const float landingDistance = std::max(wanted, targetDistance);
  Shot shot{};
  shot.dir[0] = dx / targetDistance;
  shot.dir[1] = dz / targetDistance;
  shot.origin[0] = ox;
  shot.origin[1] = oz;
  shot.landingDistance = landingDistance;
  shot.landing[0] = ox + shot.dir[0] * landingDistance;
  shot.landing[1] = point[1];
  shot.landing[2] = oz + shot.dir[1] * landingDistance;
  TerrainHeight(world, shot.landing);
  shot.last[0] = Field<float>(projectileUnit, 0x14);
  shot.last[1] = Field<float>(projectileUnit, 0x1C);
  shot.width = entry->width;
  shot.multiplier = multiplier * entry->factor;
  shot.shooter = Field<std::int32_t>(shooter, 0x10);
  const char* owner = Field<const char*>(shooter, 0x44);
  shot.player = owner == nullptr ? 0 : Field<std::int32_t>(owner, 0x00);
  shot.protoId = Field<std::int32_t>(proto, 0x04);
  shot.action = action;
  shot.muted = ActionFlag(action, kMuteDamage) ? 1 : 0;
  shot.p10 = (Field<std::uint32_t>(projectile, 0x30) >> 14 & 1) == 0 ? 1 : 0;
  shot.p12 = p12;
  shot.target = Field<std::int32_t>(target, 0x10);
  point[0] = shot.landing[0];
  point[1] = shot.landing[1];
  point[2] = shot.landing[2];
  *reinterpret_cast<std::int32_t*>(projectile + 0x20) = kGroundShot;
  const std::int32_t projectileId = Field<std::int32_t>(projectileUnit, 0x10);
  if (g_log && g_launchLines < kMaxLaunchLines) {
    ++g_launchLines;
    uhc::Log(L"directionalAttack: unit %d (%hs/%ls) fires shot %d at unit %d %.1f m away; it lands %.1f m away at "
             L"(%.1f, %.1f)",
             shot.shooter, ProtoName(proto), ActionName(Field<std::int32_t>(action, 0x04)), projectileId, shot.target,
             static_cast<double>(targetDistance), static_cast<double>(landingDistance),
             static_cast<double>(shot.landing[0]), static_cast<double>(shot.landing[2]));
  }
  g_shots[projectileId] = std::move(shot);
  while (g_shots.size() > kMaxShots) {
    g_shots.erase(g_shots.begin());
  }
}
}

namespace uhc {

Outcome ApplyDirectionalAttack(const Config& config) {
  const Config::Args* args = config.First("directionalAttack");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"directionalAttack: unknown option %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("directionalAttack", {&sites::kDirectionalLaunch, &sites::kDirectionalLaunchCall,
                                       &sites::kDirectionalTerrainHeight, &sites::kDirectionalTakeDamage,
                                       &sites::kDirectionalMaxRangeCall,
                                       &sites::kUnitsNearPoint, &sites::kUnitById, &sites::kProtoFlag}) ||
      !RequestAbstractUnitType("Resource", &g_resourceType) || !OnDatabaseLoad(&ResetForDataLoad) ||
      !AddActionTagHandler(&OnActionTag) || !AddWorldTick(&Tick) ||
      !WriteJmp(sites::kDirectionalLaunch.va, reinterpret_cast<const void*>(&UhcDirLaunchHook), 7) ||
      !WriteCall(sites::kDirectionalMaxRangeCall.va + 7, reinterpret_cast<const void*>(&UhcDirSetMaxRange))) {
    return Outcome::kFailed;
  }
  Log(L"directionalAttack: actions with <DirectionalAttack> or <DirectionalFiringRange> fly past their target and "
      L"hit what they fly over%ls (multiplayer unverified)",
      g_log ? L"; shots and hits logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/directional_hooks.asm

```asm
; directionalAttack (src/features/directional.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcDirLaunch PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD

.data
launchNext dd 004998AEh     ; mov ecx,[ebx+4], after the two instructions this hook re-executes

.code

; Replaces mov ecx,[esp+10h] / mov [esi+14h],ecx (7 bytes) at 0x4998A7 in the projectile launch FUN_004995C7,
; where every launch path meets once the mode [esi+20h] and the impact point [esp+28h] are final: the
; precalculated roll (0x49989C), the InstantBallistics branch (0x4998A0), the TargetGround store (0x4C4DF3)
; and the skipped block (0x4997B0, 0x4997B8). Nothing branches inside the 7 bytes. ESI = the projectile,
; [esp+18h] the unit action, [esp+0E8h] the shooting unit, [esp+0ECh] the target unit or 0, [esp+10h] the
; damage multiplier the stolen code copies to [projectile+14h], [esp+44h] the value the launch keeps at
; [projectile+0C0h]. Every launch call after it (0x4A5725, 0x7A8CDF, the instant 0x4A95A5) reads the point at
; [esp+28h], so a point and a mode rewritten here are where the shot flies and how it lands. Registers are
; saved around the call; the continuation sets the flags before it reads them (test eax,eax at 0x4998B4).
UhcDirLaunchHook PROC
    TRACE_ONCE "directionalAttack launch (0x4998A7)"
    pushad
    lea eax, dword ptr [esp+20h+28h]    ; the impact point
    push eax
    push dword ptr [esp+24h+10h]        ; the damage multiplier (float)
    push dword ptr [esp+28h+44h]        ; [projectile+0C0h] to be
    push dword ptr [esp+2Ch+0ECh]       ; the target unit (or 0)
    push dword ptr [esp+30h+0E8h]       ; the shooting unit
    push dword ptr [esp+34h+18h]        ; the unit action
    push esi                            ; the projectile
    call UhcDirLaunch
    popad
    mov ecx, dword ptr [esp+10h]        ; stolen
    mov dword ptr [esi+14h], ecx        ; stolen
    jmp launchNext
UhcDirLaunchHook ENDP

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
// CoverBuildingAttack is the same torch in another stance: with no tag of its own it uses BuildingAttack's.
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
constexpr std::size_t kGameGlobal = 0xC66234;
constexpr std::size_t kActionNames = 0x1FD8;  // in the database: the action names, then +4 their count
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
std::int32_t g_coverName = -2;     // name indices of the two actions; -2: not looked up yet
std::int32_t g_buildingName = -1;
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

void NewDatabase(char*) {
  g_amounts.clear();
  g_coverName = -2;
  g_buildingName = -1;
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

// The two names, once per database.
void LookUpNames() {
  if (g_coverName != -2) {
    return;
  }
  g_coverName = -1;
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* db = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (db == nullptr) {
    return;
  }
  const auto* names = Field<const wchar_t* const*>(db, kActionNames);
  const std::int32_t count = Field<std::int32_t>(db, kActionNames + 4);
  for (std::int32_t i = 0; i < count; ++i) {
    if (names[i] == nullptr) {
      continue;
    }
    if (_wcsicmp(names[i], L"CoverBuildingAttack") == 0) {
      g_coverName = i;
    } else if (_wcsicmp(names[i], L"BuildingAttack") == 0) {
      g_buildingName = i;
    }
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
  const std::int32_t protoId = Field<std::int32_t>(attackerProto, 0x04);
  const std::int32_t actionName = Field<std::int32_t>(action, 0x04);
  auto found = g_amounts.find({protoId, actionName});
  if (found == g_amounts.end()) {
    LookUpNames();
    if (actionName == g_coverName && g_buildingName >= 0) {
      found = g_amounts.find({protoId, g_buildingName});
    }
  }
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

## auraStacking

Contract: [auraStacking](../porting-to-another-dll.md#aurastacking).

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`modifiers.h`](helpers.md#modifier-walk), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `AuraFilter` `0x9D0238` (6 B), `AuraFilterCall` `0x9D0633` (5 B), `AuraAppliedNext` `0x9D0675` (5 B).

### src/features/aurastacking.cpp

```cpp
// auraStacking: <NoStack> and <ForbidUnitType> on an AutoRangedModify action, for any aura.
//
// In the aura update FUN_009D033E, a unit in range that the action does not hold yet goes through the
// filter 0x9D0238, once (call 0x9D0633), and gets its modifier from 0x4DD22D. The key wraps that call.
//   <ForbidUnitType> refuses a target of the type.
//   <NoStack> refuses a target that holds a modifier of the same aura, from another carrier.
// A modifier does not say which aura made it: [modifier+4] is null on this path, so nothing links it to
// the action. So the key marks it: right after the apply (0x9D0675) it writes the aura's mark in
// [modifier+84h], a field that stock saves and loads and nothing reads (0x9E34E8, 0x9E366C). The mark is
// in the game state, so the key keeps no list, a saved game needs nothing, and every machine sees the
// same thing. A refused target stays out of [action+68h], so each update of each carrier asks again: when
// the holder dies or the target leaves its range, its modifier goes and the next carrier to update takes it.
//
// unitResourceAuras makes no modifier and its take does not go through the filter: AuraClaim holds a
// target per aura for it. That state is not saved, and a load only makes a carrier take the claim again.
//
// The second applier FUN_009D7328, for actions with no range, has no filter and is not covered.
#include "../aurastacking.h"

#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifiers.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
void UhcAuraFilterHook();
void UhcAuraAppliedHook();
std::uint32_t g_uhcAuraAppliedNext = 0x009D067A;
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint32_t kModifierMark = 0x84;      // saved, and read by nothing else
constexpr std::uint32_t kClaimExpiryMs = 7000;     // the take comes back at most every few seconds
constexpr std::size_t kMaxClaims = 4096;           // beyond it, the old ones are swept
constexpr int kMaxLogLines = 200;
constexpr int kMaxRefusalLines = 20;               // they repeat at every update

using FilterFn = bool(__thiscall*)(const char* action, const char* target);
using UnitByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);

const auto kFilter = reinterpret_cast<FilterFn>(0x009D0238);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Forbidden {
  std::string name;
  std::int32_t id = -2;  // -2: not looked up yet, -1: unknown
};

struct Aura {
  bool noStack = false;
  std::vector<Forbidden> forbidden;
};

struct Claim {
  std::int32_t owner;
  std::uint32_t time;
};

std::map<ActionKey, Aura> g_auras;  // filled while the data loads, read-only after, but for the IDs
std::unordered_map<std::uint64_t, Claim> g_claims;
const char* g_claimWorld = nullptr;
bool g_on = false;
bool g_log = false;
int g_logLines = 0;
int g_refusalLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// Above 0, so that no field that was never set is a mark.
std::int32_t MarkOf(std::int32_t proto, std::int32_t name) { return ((proto + 1) << 14) | (name & 0x3FFF); }

void NewDatabase(char*) {
  g_auras.clear();
  g_claims.clear();
  g_logLines = 0;
  g_refusalLines = 0;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  const bool noStack = _wcsicmp(tag.name, L"NoStack") == 0;
  const bool forbid = _wcsicmp(tag.name, L"ForbidUnitType") == 0 || _wcsicmp(tag.name, L"ForbidAbstractType") == 0;
  if (!noStack && !forbid) {
    return;
  }
  const std::int32_t name = Field<std::int32_t>(tag.action, 0x04);
  if (name < 0) {
    uhc::Log(L"auraStacking: proto %hs: <%ls> goes after the action's <Name>; ignored",
             Field<const char*>(tag.proto, 0x10), tag.name);
    return;
  }
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  Aura& aura = g_auras[{Field<std::int32_t>(tag.proto, 0x04), name}];
  if (noStack) {
    aura.noStack = text[0] == L'\0' || std::wcstol(text, nullptr, 10) != 0;
  } else {
    Forbidden entry;
    for (const wchar_t* c = text; *c != L'\0'; ++c) {
      entry.name.push_back(static_cast<char>(*c));
    }
    if (entry.name.empty()) {
      uhc::Log(L"auraStacking: proto %hs: an empty <%ls>; ignored", Field<const char*>(tag.proto, 0x10), tag.name);
      return;
    }
    aura.forbidden.push_back(entry);
  }
  if (g_log) {
    uhc::Log(L"auraStacking: proto %hs, action %d: %ls %ls", Field<const char*>(tag.proto, 0x10), name, tag.name, text);
  }
}

// By the table <UnitType> reads, on the first update: every name is known by then.
std::int32_t ForbiddenType(Forbidden& entry) {
  if (entry.id != -2) {
    return entry.id;
  }
  entry.id = -1;
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (database == nullptr) {
    return -1;
  }
  const char* table = database + 0x190;
  std::int32_t id = -1;
  const std::int32_t bucket = kNameBucket(table, entry.name.c_str());
  if (kNameFind(table, entry.name.c_str(), bucket, &id)) {
    entry.id = id;
  } else {
    uhc::Log(L"auraStacking: <ForbidUnitType>%hs names no unit type or proto; ignored", entry.name.c_str());
  }
  return entry.id;
}

// The target holds a modifier with this mark.
bool HoldsMark(const char* target, std::int32_t mark) {
  const char* list = uhc::modifiers::ModifierList(target);
  if (list == nullptr) {
    return false;
  }
  auto different = [mark](const char* modifier) { return Field<std::int32_t>(modifier, kModifierMark) != mark; };
  return uhc::modifiers::WalkModifiers(list, different, 0) == uhc::modifiers::Walk::kStopped;
}

Aura* AuraOf(const char* action, ActionKey* key) {
  const char* tactics = Field<const char*>(action, 0x04);
  const char* owner = Field<const char*>(action, 0x10);
  const char* proto = owner == nullptr ? nullptr : Field<const char*>(owner, 0x5C);
  if (tactics == nullptr || proto == nullptr) {
    return nullptr;
  }
  *key = {Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(tactics, 0x04)};
  const auto found = g_auras.find(*key);
  return found == g_auras.end() ? nullptr : &found->second;
}

void LogRefusal(const char* action, const char* target, const wchar_t* why) {
  if (g_log && g_refusalLines < kMaxRefusalLines) {
    ++g_refusalLines;
    uhc::Log(L"auraStacking: unit %d leaves unit %d alone: %ls", Field<std::int32_t>(Field<const char*>(action, 0x10), 0x10),
             Field<std::int32_t>(target, 0x10), why);
  }
}

}  // namespace

extern "C" {

// Instead of the filter 0x9D0238, at its one call 0x9D0633.
bool __stdcall UhcAuraFilter(const char* action, const char* target) {
  if (!kFilter(action, target)) {
    return false;
  }
  ActionKey key{};
  Aura* aura = AuraOf(action, &key);
  if (aura == nullptr) {
    return true;
  }
  const char* proto = Field<const char*>(target, 0x5C);
  for (Forbidden& entry : aura->forbidden) {
    const std::int32_t type = ForbiddenType(entry);
    if (type >= 0 && proto != nullptr && kProtoIsType(proto, type)) {
      LogRefusal(action, target, L"a forbidden type");
      return false;
    }
  }
  if (aura->noStack && HoldsMark(target, MarkOf(key.proto, key.name))) {
    LogRefusal(action, target, L"it holds this aura");
    return false;
  }
  return true;
}

// After the apply: EAX of 0x4DD22D, the ID of the new modifier.
void __stdcall UhcAuraApplied(const char* action, char* target, std::int32_t modifier) {
  if (modifier == -1) {
    return;
  }
  ActionKey key{};
  const Aura* aura = AuraOf(action, &key);
  if (aura == nullptr || !aura->noStack) {
    return;
  }
  const char* list = uhc::modifiers::ModifierList(target);
  if (list == nullptr) {
    return;
  }
  const std::int32_t mark = MarkOf(key.proto, key.name);
  auto write = [modifier, mark](const char* action2) {
    if (Field<std::int32_t>(action2, 0x08) != modifier) {
      return true;
    }
    *reinterpret_cast<std::int32_t*>(const_cast<char*>(action2) + kModifierMark) = mark;
    return false;
  };
  if (uhc::modifiers::WalkModifiers(list, write, 0) != uhc::modifiers::Walk::kStopped) {
    uhc::Log(L"auraStacking: the modifier %d of unit %d was not found", modifier, Field<std::int32_t>(target, 0x10));
  } else if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"auraStacking: unit %d holds unit %d", Field<std::int32_t>(Field<const char*>(action, 0x10), 0x10),
             Field<std::int32_t>(target, 0x10));
  }
}
}

namespace uhc {

bool AuraClaim(const char* world, std::int32_t proto, std::int32_t name, std::int32_t owner, std::int32_t target,
               std::uint32_t now) {
  if (!g_on) {
    return true;
  }
  const auto aura = g_auras.find({proto, name});
  if (aura == g_auras.end() || !aura->second.noStack) {
    return true;
  }
  if (world != g_claimWorld) {
    g_claimWorld = world;
    g_claims.clear();
  }
  const std::uint64_t id = (static_cast<std::uint64_t>(static_cast<std::uint32_t>(MarkOf(proto, name))) << 32) |
                           static_cast<std::uint32_t>(target);
  if (g_claims.size() > kMaxClaims) {
    std::erase_if(g_claims, [now](const auto& claim) { return now - claim.second.time > kClaimExpiryMs; });
  }
  const auto [claim, isNew] = g_claims.try_emplace(id, Claim{owner, now});
  if (isNew || claim->second.owner == owner) {
    claim->second.time = now;
    return true;
  }
  if (now - claim->second.time <= kClaimExpiryMs && now >= claim->second.time &&
      kUnitById(world, claim->second.owner) != nullptr) {
    return false;
  }
  claim->second = {owner, now};
  return true;
}

Outcome ApplyAuraStacking(const Config& config) {
  const Config::Args* args = config.First("auraStacking");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"auraStacking: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("auraStacking", {&sites::kAuraFilterCall, &sites::kAuraAppliedNext, &sites::kAuraFilter}) ||
      !AddActionTagHandler(&ActionTagRead) || !OnDatabaseLoad(&NewDatabase) ||
      !WriteCall(sites::kAuraFilterCall.va, reinterpret_cast<const void*>(&UhcAuraFilterHook)) ||
      !WriteJmp(sites::kAuraAppliedNext.va, reinterpret_cast<const void*>(&UhcAuraAppliedHook), 5)) {
    return Outcome::kFailed;
  }
  g_on = true;
  Log(L"auraStacking: auras read <NoStack> and <ForbidUnitType> (changes the simulation)");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/aurastacking.h

```cpp
// The part of auraStacking that unitResourceAuras uses: its take runs instead of the stock update, so
// the filter of the aura update never sees it.
#pragma once

#include <cstdint>

namespace uhc {

// True if this owner may take from this target now. With <NoStack> on the aura, one carrier holds each
// target; it keeps it while it comes back within a few seconds and is alive. True for any other aura and
// with the key off.
bool AuraClaim(const char* world, std::int32_t proto, std::int32_t name, std::int32_t owner, std::int32_t target,
               std::uint32_t now);

}  // namespace uhc
```

### src/hooks/aurastacking_hooks.asm

```asm
; auraStacking (src/features/aurastacking.cpp). Two hooks in the aura update FUN_009D033E.
.686
.model flat, c
option casemap :none

include common.inc

UhcAuraFilter PROTO STDCALL action:DWORD, target:DWORD
UhcAuraApplied PROTO STDCALL action:DWORD, target:DWORD, modifier:DWORD

EXTERNDEF C g_uhcAuraAppliedNext:DWORD

.code

; Replaces the target of the call at 0x9D0633: the filter 0x9D0238, thiscall(action, target), ret 4.
; The update reads AL. The C++ code calls the filter itself.
UhcAuraFilterHook PROC
    TRACE_ONCE "auraStacking filter (0x9D0633)"
    mov eax, dword ptr [esp+4]
    invoke UhcAuraFilter, ecx, eax
    ret 4
UhcAuraFilterHook ENDP

; Replaces, at 0x9D0675 right after the call of 0x4DD22D, mov ebx,eax / cmp ebx,-1. EAX = the modifier's
; ID, EBX = the target, ESI = the action. ECX and EDX hold nothing, as 0x4DD22D has just run.
UhcAuraAppliedHook PROC
    TRACE_ONCE "auraStacking applied (0x9D0675)"
    push eax
    invoke UhcAuraApplied, esi, ebx, eax
    pop eax
    mov ebx, eax
    cmp ebx, -1
    jmp g_uhcAuraAppliedNext
UhcAuraAppliedHook ENDP

END
```

## veterancyBonus

Contract: [veterancyBonus](../porting-to-another-dll.md#veterancybonus).

Besides the core helpers, it needs: [`floatingtext.h`](helpers.md#floating-text), [`modifiers.h`](helpers.md#modifier-walk), [`prototags.h`](helpers.md#proto-tags), [`techsubtypes.h`](helpers.md#tech-subtypes), [`transformcalls.h`](helpers.md#transform-calls), [`unitmodels.h`](helpers.md#models-on-a-unit), [`unitpanel.h`](helpers.md#unit-panel-row-the-minimized-interface), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `UnitById` `0x44CC6D` (58 B), `IsA` `0x44D7FA` (105 B), `VeterancyKillPath` `0x4D4F37` (6 B), `SnareApply` `0x4DD22D` (130 B).

### src/features/veterancy.cpp

```cpp
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
// Stock's flag ExperienceUnit has no reader in the exe, so nothing counts a unit's kills. The hook sits
// on TakeDamage's kill path, where the attacker unit is known. The count and the bonuses are all stat
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
// hooks/veterancy_hooks.asm.
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

extern "C" void UhcVeterancyHook();

namespace {

constexpr std::uint32_t kKillPath = 0x004D4F37;
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

// From the hook, for every killing blow.
extern "C" void __stdcall UhcVeterancyKill(char* attacker, const char* victim) {
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
  if (!VerifyAll("veterancyBonus", {&sites::kVeterancyKillPath, &sites::kSnareApply, &sites::kIsA}) ||
      !LoadDataFile(file) ||
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
  if (g_defaults.empty() && g_styles.empty()) {
    Log(L"veterancyBonus: no default rows and no rank names (%ls)", g_file.c_str());
  } else {
    Log(L"veterancyBonus: %u unit types with default rows and %u rank names from %ls",
        static_cast<unsigned>(g_defaults.size()), static_cast<unsigned>(g_styles.size()), g_file.c_str());
  }
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

Besides the core helpers, it needs: [`deathobservers.h`](helpers.md#death-observers), [`prototags.h`](helpers.md#proto-tags), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `MaxHitpointsGetter` `0x480408` (38 B), `HpSetter` `0x4820A1` (34 B), `OverhealAddEntry` `0x4823A3` (10 B), `DetonationTakeDamageHp` `0x49B822` (5 B), `KillQueueAsk` `0x4B4DC2` (8 B), `DetonationAreaHead` `0x4C9D89` (10 B), `DeleteSetHpCall` `0x7CD0CF` (5 B), `DeleteKillCall` `0x7CD0DC` (5 B), `UnitAliveSlot` `0xB9355C` (4 B).

### src/features/detonation.cpp

```cpp
// detonationDeath: <DetonationProtoAction>Name</DetonationProtoAction> in a proto fires that action around
// the unit when it dies.
//
// Every death goes through one queue: TakeDamage, a lifespan, a delete and the rest ask 0x4B4DC2, and the
// queue's drain 0x493D46 calls the kill handler 0x4B4F70 for each, from a single call, 0x493D8F. The key
// observes that call through the shared wrapper (deathobservers.h). Before the stock handler runs, the unit still exists, so the stock area damage
// 0x4C9D89 gets it as the attacker, in the same call the game makes for a unit that hits around
// itself (0x6A4A6B). Units that die from the blast join the queue, and the drain reads its count again,
// so a chain runs one by one and does not recurse.
//
// The action is the player's copy, so a tech that changes its damage counts. The names are read once and
// are the same for every player.
//
// The three other tags (the names of another edition of the game):
// - <DetonationCommand>Name</DetonationCommand>: the unit detonates when it is deleted. The modder gives
//   the proto a command of that name wired to the console command uiDeleteSelectedUnit (the stock Delete
//   does the same), so the button and the Delete key both send the synced delete command (type 7),
//   whose executor FUN_007CCF7F sets the unit's HP to 0 through 0x4820A1 (flag 1) for most protos, or
//   asks the kill queue with flags 1 0 0 for a proto with flag 0Dh. The two calls are wrapped: the first
//   fires the blast before the setter, the second marks the unit as deleted so the kill handler's wrapper
//   knows the kill is a delete. Without the tag a delete gives no blast.
// - <DetonationHitpointThreshold>Ratio</DetonationHitpointThreshold>: when a loss of HP leaves the unit
//   at or under that share of its max HP, it detonates by itself: the shared add-HP hook of
//   overhealSources (0x4823A3, which TakeDamage's subtraction 0x49B822 reaches) reports every loss, and
//   the unit's kill is asked from the queue with the combat flags, so the drain fires the blast.
// - <DetonationHitpointDecay>HP per second</DetonationHitpointDecay>: with a threshold, the unit does
//   not die at once but loses that many HP per second of game time from the threshold on, through the
//   HP setter, and detonates when it reaches 0 (or when anything else kills it). Healed back over the
//   threshold, it stops decaying until the next loss. The decaying units are kept by unit ID (the same
//   order on every machine) and forgotten on a new game and a data load; a saved game does not keep them.
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <unordered_map>

#include "../deathobservers.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace uhc {
extern void (*g_hpLoss)(const char* unit, float amount);  // overhealsources.cpp
bool InstallOverhealAddHook();
bool OverhealAddHookInstalled();
}  // namespace uhc

namespace {

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

using AreaFn = void(__thiscall*)(const char* world, std::int32_t unit, char* action, const void* point, float multiplier,
                                 std::int32_t a, std::int32_t b, std::int32_t c, std::int32_t* hit, std::uint32_t flag,
                                 const void* offset);
const auto kArea = reinterpret_cast<AreaFn>(0x004C9D89);
using KillAskFn = void(__thiscall*)(char* unit, std::int32_t a, std::int32_t b, std::int32_t c);
const auto kKillAsk = reinterpret_cast<KillAskFn>(0x004B4DC2);
using SetHpFn = void(__thiscall*)(char* unit, float value, std::int32_t flag);
const auto kSetHp = reinterpret_cast<SetHpFn>(0x004820A1);
using MaxHpFn = float(__thiscall*)(const char* unit);
const auto kMaxHp = reinterpret_cast<MaxHpFn>(0x00480408);
using IsAliveFn = bool(__thiscall*)(const char* unit);
constexpr std::uint32_t kDeleteSetHpCall = 0x007CD0CF;
constexpr std::uint32_t kDeleteKillCall = 0x007CD0DC;
constexpr std::size_t kUnitContainer = 0x6C;  // -1 when the unit is not inside another

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

struct Decay {
  float perSecond;
  std::uint32_t lastMs;  // game time of the last step applied
};
std::set<std::int32_t> g_deleting;    // unit IDs the delete executor sent to the kill queue
std::set<std::int32_t> g_asked;       // unit IDs whose kill the threshold asked, until the handler runs
std::map<std::int32_t, Decay> g_decay;  // by unit ID
const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;

bool IsAlive(const char* unit) { return (*reinterpret_cast<IsAliveFn const* const*>(unit))[0xA4 / 4](unit); }

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  return game == nullptr ? nullptr : *reinterpret_cast<const char* const*>(game + 0x13C);
}

char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= *reinterpret_cast<const std::int32_t*>(world + 0x10)) {
    return nullptr;
  }
  char* unit = (*reinterpret_cast<char* const* const*>(world + 0x0C))[id & 0x3FFFF];
  return unit != nullptr && *reinterpret_cast<const std::int32_t*>(unit + 0x10) == id ? unit : nullptr;
}

void Forget(char*) {
  g_deleting.clear();
  g_asked.clear();
  g_decay.clear();
}

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

void Detonate(char* unit, std::uint32_t a, std::uint32_t b, std::uint32_t c, bool deleted) {
  const char* proto = *reinterpret_cast<const char* const*>(unit + kUnitProto);
  if (proto == nullptr) {
    return;
  }
  const std::int32_t protoId = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  const auto found = g_protos.find(protoId);
  if (found == g_protos.end() || found->second.action == -1 || Bit(unit, kUnitState, kDeadBit)) {
    return;
  }
  if (deleted && found->second.command.empty()) {
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"detonationDeath: unit %d, proto %d: deleted without a DetonationCommand, no blast",
               *reinterpret_cast<std::int32_t*>(unit + kUnitId), protoId);
    }
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
    uhc::Log(L"detonationDeath: unit %d, proto %d, at %.1f, %.1f, kill flags %u %u %u%ls", *reinterpret_cast<std::int32_t*>(unit + kUnitId),
             protoId, static_cast<double>(position[0]), static_cast<double>(position[2]), a & 0xFF, b & 0xFF, c & 0xFF,
             deleted ? L" (a delete)" : L"");
  }
}

// Before the drain's call of the kill handler (the shared death observer).
void Kill(char* unit, std::uint32_t a, std::uint32_t b, std::uint32_t c) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(unit + kUnitId);
  const bool deleted = g_deleting.erase(id) > 0;
  g_asked.erase(id);
  g_decay.erase(id);
  Detonate(unit, a, b, c, deleted);
}

// Replaces the delete executor's call of the HP setter (a proto without flag 0Dh): the blast first,
// while the unit is whole.
void __fastcall DeleteSetHp(char* unit, void*, float value, std::int32_t flag) {
  Detonate(unit, 1, 0, 0, true);
  kSetHp(unit, value, flag);
}

// Replaces the delete executor's ask of the kill queue (a proto with flag 0Dh): the handler's wrapper
// then knows the kill is a delete.
void __fastcall DeleteKill(char* unit, void*, std::int32_t a, std::int32_t b, std::int32_t c) {
  g_deleting.insert(*reinterpret_cast<const std::int32_t*>(unit + kUnitId));
  kKillAsk(unit, a, b, c);
}

// The threshold: from the shared add-HP hook, for every loss, before it is applied.
void HpLoss(const char* unit, float amount) {
  const char* proto = *reinterpret_cast<const char* const*>(unit + kUnitProto);
  if (proto == nullptr || g_protos.empty()) {
    return;
  }
  const auto found = g_protos.find(*reinterpret_cast<const std::int32_t*>(proto + kProtoId));
  if (found == g_protos.end() || found->second.threshold < 0.0f || found->second.action == -1) {
    return;
  }
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(unit + kUnitId);
  if (Bit(unit, kUnitState, kDeadBit) || !IsAlive(unit) ||
      *reinterpret_cast<const std::int32_t*>(unit + kUnitContainer) >= 0 || g_asked.count(id) != 0) {
    return;
  }
  const float after = *reinterpret_cast<const float*>(unit + 0x64) + amount;
  const float max = kMaxHp(unit);
  if (after < 1e-6f || !(max > 0.0f) || after / max > found->second.threshold) {
    return;  // the killing blow's own path, or still above the threshold
  }
  if (found->second.decay > 0.0f) {
    const char* world = World();
    if (world == nullptr || g_decay.count(id) != 0) {
      return;
    }
    g_decay[id] = Decay{found->second.decay, *reinterpret_cast<const std::uint32_t*>(world + 0x108)};
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"detonationDeath: unit %d, proto %d: HP %.1f of %.1f (%.0f %%) under the threshold %.0f %%: loses %.2f HP a "
               L"second from here",
               id, found->first, static_cast<double>(after), static_cast<double>(max),
               static_cast<double>(after / max * 100.0f), static_cast<double>(found->second.threshold * 100.0f),
               static_cast<double>(found->second.decay));
    }
    return;
  }
  g_asked.insert(id);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"detonationDeath: unit %d, proto %d: HP %.1f of %.1f (%.0f %%) under the threshold %.0f %%: kill queued", id,
             found->first, static_cast<double>(after), static_cast<double>(max),
             static_cast<double>(after / max * 100.0f), static_cast<double>(found->second.threshold * 100.0f));
  }
  kKillAsk(const_cast<char*>(unit), 0, 0, 0);
}

// The decay: after each world update of the game world, by game time; a new game forgets every unit.
void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  const std::uint32_t now = *reinterpret_cast<const std::uint32_t*>(world + 0x108);
  const std::uint32_t step = *reinterpret_cast<const std::uint32_t*>(world + 0xF8);
  const bool sameGame = world == g_world && now >= g_lastTime && step - g_lastStep <= 1;
  if (!sameGame) {
    Forget(nullptr);
    g_world = world;
  }
  g_lastTime = now;
  g_lastStep = step;
  for (auto it = g_decay.begin(); it != g_decay.end();) {
    char* unit = UnitById(world, it->first);
    if (unit == nullptr || !IsAlive(unit) || Bit(unit, kUnitState, kDeadBit)) {
      it = g_decay.erase(it);
      continue;
    }
    const char* proto = *reinterpret_cast<const char* const*>(unit + kUnitProto);
    const auto found = proto == nullptr ? g_protos.end() : g_protos.find(*reinterpret_cast<const std::int32_t*>(proto + kProtoId));
    const float hp = *reinterpret_cast<const float*>(unit + 0x64);
    const float max = kMaxHp(unit);
    if (found == g_protos.end() || found->second.threshold < 0.0f || !(max > 0.0f) || hp / max > found->second.threshold) {
      if (g_log && g_logLines < kMaxLogLines && found != g_protos.end()) {
        ++g_logLines;
        uhc::Log(L"detonationDeath: unit %d is back over its threshold (HP %.1f): the decay stops", it->first,
                 static_cast<double>(hp));
      }
      it = g_decay.erase(it);
      continue;
    }
    const std::uint32_t elapsed = now - it->second.lastMs;
    it->second.lastMs = now;
    if (elapsed == 0) {
      ++it;
      continue;
    }
    const float value = hp - it->second.perSecond * static_cast<float>(elapsed) * 0.001f;
    if (value < 1e-6f) {
      if (g_log && g_logLines < kMaxLogLines) {
        ++g_logLines;
        uhc::Log(L"detonationDeath: unit %d decayed to 0: kill queued", it->first);
      }
      g_asked.insert(it->first);
      it = g_decay.erase(it);
      kKillAsk(unit, 0, 0, 0);
      continue;
    }
    kSetHp(unit, value, 0);
    ++it;
  }
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
  // overhealSources or overhealDecay may already have written the add-HP hook: its bytes are then ours.
  const Site* addEntry = OverhealAddHookInstalled() ? &sites::kHpSetter : &sites::kOverhealAddEntry;
  if (!VerifyAll("detonationDeath", {&sites::kDetonationAreaHead, addEntry, &sites::kHpSetter,
                                     &sites::kMaxHitpointsGetter, &sites::kUnitAliveSlot, &sites::kKillQueueAsk,
                                     &sites::kDeleteSetHpCall, &sites::kDeleteKillCall, &sites::kDetonationTakeDamageHp}) ||
      !AddProtoTagHandler("DetonationProtoAction", &ReadDetonation) ||
      !AddProtoTagHandler("DetonationCommand", &ReadCommand) ||
      !AddProtoTagHandler("DetonationHitpointThreshold", &ReadThreshold) ||
      !AddProtoTagHandler("DetonationHitpointDecay", &ReadDecay) || !OnDatabaseLoad(&Forget) ||
      !AddDeathObserver(&Kill) ||
      !WriteCall(kDeleteSetHpCall, reinterpret_cast<const void*>(&DeleteSetHp)) ||
      !WriteCall(kDeleteKillCall, reinterpret_cast<const void*>(&DeleteKill)) || !InstallOverhealAddHook() ||
      !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  g_hpLoss = &HpLoss;
  Log(L"detonationDeath: the proto tags DetonationProtoAction, DetonationCommand, DetonationHitpointThreshold and "
      L"DetonationHitpointDecay are on (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
```

## impactBoneFix

Contract: [impactBoneFix](../porting-to-another-dll.md#impactbonefix).

Sites: `BoneFrameGetter` `0x407272` (8 B), `ImpactBoneFrame1` `0x4BE21E` (13 B), `ImpactBoneFrame2` `0x4BE88D` (13 B).

### src/features/impactbones.cpp

```cpp
// impactBoneFix [all] [log]: an impact effect that is a visual (an impacteffect particleSet naming an .xml, as
// cannon.impacteffect's <wood> does) is attached to the dummy bone of the impact point it hit (FUN_004CA908 from
// the impact spawn FUN_0049C1E5), and the visual's attachment update takes the bone's frame from the model
// (FUN_00407272) with its scale. A model exported with its bones scaled by 100 (centimetres, as some mods'
// buildings are) gives the attached effect axes of length 100, and its splinters cover the screen. Particle set
// impacts (<stone>) are placed at the hit point and never read the bone, so only the visual ones break.
//
// The key scales the three axes the getter returns to unit length for the impact dummies (the type the damage
// templates use, [[0D6F678h]]); with "all", for every dummy a visual is attached to. The position is kept.
#include <cmath>
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcImpactBoneFrame1();
extern "C" void UhcImpactBoneFrame2();

namespace {

bool g_allDummies = false;
bool g_log = false;
bool g_loggedScale = false;

constexpr float kTolerance = 0.01f;  // a bone this close to unit length is left as it is

std::int32_t ImpactDummyType() {
  const auto* holder = *reinterpret_cast<const std::int32_t* const*>(0x00D6F678);
  return holder == nullptr ? -1 : *holder;
}

}  // namespace

// Called after a successful FUN_00407272 in the dummy attachment update. frame is ESP after the call; the axes
// are at frame+firstAxis, frame+30h and frame+40h, three floats each.
extern "C" void __stdcall UhcFixDummyAxes(std::int32_t dummyType, char* frame, std::int32_t firstAxis) {
  if (!g_allDummies && dummyType != ImpactDummyType()) {
    return;
  }
  float* axes[3] = {reinterpret_cast<float*>(frame + firstAxis), reinterpret_cast<float*>(frame + 0x30),
                    reinterpret_cast<float*>(frame + 0x40)};
  for (float* axis : axes) {
    const float length = std::sqrt(axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2]);
    if (!(length > 1e-6f) || std::fabs(length - 1.0f) <= kTolerance) {
      continue;
    }
    if (g_log && !g_loggedScale) {
      g_loggedScale = true;
      uhc::Log(L"impactBoneFix: a dummy bone of type %d had an axis of length %.3f; scaled to 1", dummyType,
               static_cast<double>(length));
    }
    axis[0] /= length;
    axis[1] /= length;
    axis[2] /= length;
  }
}

namespace uhc {

Outcome ApplyImpactBoneFix(const Config& config) {
  const Config::Args* args = config.First("impactBoneFix");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "all") == 0) {
      g_allDummies = true;
    } else if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"impactBoneFix: unknown argument '%hs' (expected all, log); not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("impactBoneFix", {&sites::kImpactBoneFrame1, &sites::kImpactBoneFrame2, &sites::kBoneFrameGetter})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kImpactBoneFrame1.va, reinterpret_cast<const void*>(&UhcImpactBoneFrame1), 5) ||
      !WriteJmp(sites::kImpactBoneFrame2.va, reinterpret_cast<const void*>(&UhcImpactBoneFrame2), 5)) {
    return Outcome::kFailed;
  }
  Log(L"impactBoneFix: effects attached to %ls bones get unit-length axes", g_allDummies ? L"any dummy" : L"impact");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/impactbone_hooks.asm

```asm
; Hooks for impactBoneFix (src/features/impactbones.cpp). Each replaces a call of the model's bone frame
; getter FUN_00407272 in the visual's dummy attachment update (5 B), makes that call itself with the
; arguments the stock code pushed, and, when it succeeded, lets UhcFixDummyAxes scale the three axis vectors
; it wrote back to unit length. EAX (the getter's bool), ECX and EDX are kept; the stock test al,al / je
; follows at the continuation. ESP after the call is the frame both paths read the axes from.
.686
.model flat, c
option casemap :none

include common.inc

UhcFixDummyAxes PROTO STDCALL dummyType:DWORD, frame:DWORD, firstAxis:DWORD

.data
boneFrameGetter dd 00407272h
continue1       dd 004BE223h   ; test al,al / je 4E3B3Ah
continue2       dd 004BE892h   ; test al,al / je 4BEA2Bh

.code

; 0x4BE21E: EDI = the dummy type, the axes at [esp+24h], [esp+30h], [esp+40h] after the call.
UhcImpactBoneFrame1 PROC
    TRACE_ONCE "impactBoneFix dummy frame, path 1 (0x4BE21E)"
    call boneFrameGetter
    test al, al
    jz done
    push eax
    push ecx
    push edx
    lea eax, [esp+0Ch]
    push 24h
    push eax
    push edi
    call UhcFixDummyAxes
    pop edx
    pop ecx
    pop eax
done:
    jmp continue1
UhcImpactBoneFrame1 ENDP

; 0x4BE88D: EBX = the dummy type, the axes at [esp+20h], [esp+30h], [esp+40h] after the call.
UhcImpactBoneFrame2 PROC
    TRACE_ONCE "impactBoneFix dummy frame, path 2 (0x4BE88D)"
    call boneFrameGetter
    test al, al
    jz done
    push eax
    push ecx
    push edx
    lea eax, [esp+0Ch]
    push 20h
    push eax
    push ebx
    call UhcFixDummyAxes
    pop edx
    pop ecx
    pop eax
done:
    jmp continue2
UhcImpactBoneFrame2 ENDP

END
```

## customImpactTypes

Contract: [customImpactTypes](../porting-to-another-dll.md#customimpacttypes).

Sites: `StringCompareW` `0x443C10` (7 B), `ImpactSpawn` `0x49C1E5` (12 B), `ImpactSpawnUnit` `0x49D86E` (6 B), `ImpactSpawnTerrain` `0x4CB30D` (6 B), `ImpactTypeNotFound` `0x59F464` (7 B), `ImpactEffectAdd` `0x5FEC74` (24 B), `ImpactEffectWeights` `0x5FEC99` (11 B).

### src/features/impacttypes.cpp

```cpp
// customImpactTypes <Name> [<Name> ...] [log]: impact types beyond the game's 15 (Wood, Stone, Flesh, Animal,
// TerrainGrass, Snow, Dirt, TerrainWater, TerrainDirt, TerrainStone, TerrainSnow, TerrainSand, RoofTile,
// ExitBuilding, Metal; the wchar[32] table at 0xBA4D70, read by FUN_0059F436).
//
// A type name is read in four places, all through FUN_0059F436: a damage template's impacttype (.dmg), a proto's
// <ImpactType>, a terrain type's ImpactType, and the element names of an .impacteffect file. The key makes that
// lookup answer 15 + the name's index for the names given here. An impact effect keeps one list of entries per
// stock type inside its object ([effect + 4 + type * 12], 15 lists, FUN_005FE8CD); the entries of a custom type
// go to a list the DLL keeps for that effect instead, built with the same list add (FUN_00401F74) and the same
// cumulative weights. The spawn FUN_0049C1E5 refuses a type above 14, so at its two calls (the projectile hit and
// the terrain impact) a custom type is played by lending its list to the effect's Metal slot for the stock call,
// which then picks an entry and plays its particle set, sounds and fire as for any type, and giving the slot
// back. Rendering and sound only: nothing here changes the simulation.
#include <cstdint>
#include <cstring>
#include <map>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcImpactTypeNotFoundHook();
extern "C" void UhcImpactEffectAddHook();
extern "C" void UhcImpactEffectWeightsHook();
extern "C" void UhcImpactSpawnUnitHook();
extern "C" void UhcImpactSpawnTerrainHook();

namespace {

constexpr std::int32_t kStockTypes = 15;
constexpr std::int32_t kLentSlot = 14;  // Metal: its list is lent to a custom type for one spawn
constexpr std::size_t kMaxCustom = 64;

// The game's dynamic array of entry pointers, as at [effect + 4 + type * 12].
struct EntryList {
  void** data;
  std::int32_t count;
  std::int32_t capacity;
};

using StringCompare = std::int32_t(__thiscall*)(const void* string, const wchar_t* text, std::int32_t, std::int32_t);
using ListAdd = std::int32_t(__thiscall*)(EntryList* list, void* const* entry);
using Spawn = std::int32_t(__thiscall*)(void* effect, std::uint32_t, std::uint32_t, std::uint32_t, std::uint32_t,
                                        std::uint32_t, std::uint32_t, std::uint32_t, std::uint32_t);
const auto kStringCompare = reinterpret_cast<StringCompare>(0x00443C10);
const auto kListAdd = reinterpret_cast<ListAdd>(0x00401F74);
const auto kSpawn = reinterpret_cast<Spawn>(0x0049C1E5);

std::vector<std::wstring> g_names;
bool g_log = false;
// The custom lists of each impact effect, one per custom name. Data load only; an effect read again (or a
// new one at a freed effect's address) starts from empty lists (g_parsing).
std::map<const void*, std::vector<EntryList>> g_lists;
const void* g_parsing = nullptr;
std::vector<bool> g_loggedSpawn;

}  // namespace

extern "C" std::int32_t __stdcall UhcCustomImpactType(const void* name) {
  for (std::size_t i = 0; i < g_names.size(); ++i) {
    if (kStringCompare(name, g_names[i].c_str(), 0, -1) == 0) {
      return kStockTypes + static_cast<std::int32_t>(i);
    }
  }
  return -1;
}

extern "C" void __stdcall UhcAddCustomImpact(const void* effect, std::int32_t type, void* entry) {
  const std::int32_t index = type - kStockTypes;
  if (index < 0 || index >= static_cast<std::int32_t>(g_names.size())) {
    return;  // cannot happen: only the lookup above makes such types
  }
  std::vector<EntryList>& lists = g_lists[effect];
  if (g_parsing != effect) {
    g_parsing = effect;
    lists.assign(g_names.size(), EntryList{nullptr, 0, 0});  // a new read of this effect
  }
  kListAdd(&lists[static_cast<std::size_t>(index)], &entry);
}

extern "C" void __stdcall UhcFinishImpactEffect(const void* effect) {
  if (g_parsing != effect) {
    g_lists.erase(effect);  // read again with no custom entry
  }
  g_parsing = nullptr;
  const auto found = g_lists.find(effect);
  if (found == g_lists.end()) {
    return;
  }
  // As FUN_005FE8CD does for the stock lists: each entry's weight [+20h] (0 counts as 1) becomes the running sum.
  for (EntryList& list : found->second) {
    std::int32_t sum = 0;
    for (std::int32_t i = 0; i < list.count; ++i) {
      char* entry = static_cast<char*>(list.data[i]);
      if (entry == nullptr) {
        continue;
      }
      std::int32_t& weight = *reinterpret_cast<std::int32_t*>(entry + 0x20);
      sum += weight == 0 ? 1 : weight;
      weight = sum;
    }
  }
}

extern "C" std::int32_t __stdcall UhcSpawnCustomImpact(char* effect, const std::uint32_t* args) {
  const std::int32_t index = static_cast<std::int32_t>(args[3]) - kStockTypes;
  const auto found = g_lists.find(effect);
  if (effect == nullptr || index < 0 || index >= static_cast<std::int32_t>(g_names.size()) ||
      found == g_lists.end() || found->second[static_cast<std::size_t>(index)].count <= 0) {
    return -1;  // as the stock spawn does for a type with no entry
  }
  if (g_log && !g_loggedSpawn[static_cast<std::size_t>(index)]) {
    g_loggedSpawn[static_cast<std::size_t>(index)] = true;
    uhc::Log(L"customImpactTypes: first impact of type %ls (%d)", g_names[static_cast<std::size_t>(index)].c_str(),
             kStockTypes + index);
  }
  EntryList* slot = reinterpret_cast<EntryList*>(effect + 4 + kLentSlot * 12);
  const EntryList saved = *slot;
  *slot = found->second[static_cast<std::size_t>(index)];
  const std::int32_t result =
      kSpawn(effect, args[0], args[1], args[2], kLentSlot, args[4], args[5], args[6], args[7]);
  found->second[static_cast<std::size_t>(index)] = *slot;  // the spawn does not change a list; kept in step anyway
  *slot = saved;
  return result;
}

namespace uhc {

Outcome ApplyCustomImpactTypes(const Config& config) {
  const Config::Args* args = config.First("customImpactTypes");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  static const wchar_t* const kStock[] = {L"Wood",        L"Stone",        L"Flesh",       L"Animal",
                                          L"TerrainGrass", L"Snow",         L"Dirt",        L"TerrainWater",
                                          L"TerrainDirt", L"TerrainStone", L"TerrainSnow", L"TerrainSand",
                                          L"RoofTile",    L"ExitBuilding", L"Metal"};
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    std::wstring name(arg.begin(), arg.end());
    bool clash = name.empty() || name.size() >= 32;
    for (const wchar_t* stock : kStock) {
      clash = clash || _wcsicmp(stock, name.c_str()) == 0;
    }
    for (const std::wstring& other : g_names) {
      clash = clash || _wcsicmp(other.c_str(), name.c_str()) == 0;
    }
    if (clash || g_names.size() >= kMaxCustom) {
      Log(L"customImpactTypes: '%hs' is a stock or repeated name, too long (31 at most) or one too many (%u at most); "
          L"not applied",
          arg.c_str(), static_cast<unsigned>(kMaxCustom));
      g_names.clear();
      return Outcome::kFailed;
    }
    g_names.push_back(name);
  }
  if (g_names.empty()) {
    Log(L"customImpactTypes: no type name given; not applied");
    return Outcome::kFailed;
  }
  g_loggedSpawn.assign(g_names.size(), false);
  if (!VerifyAll("customImpactTypes",
                 {&sites::kImpactTypeNotFound, &sites::kImpactEffectAdd, &sites::kImpactEffectWeights,
                  &sites::kImpactSpawnUnit, &sites::kImpactSpawnTerrain, &sites::kStringCompareW, &sites::kImpactSpawn})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kImpactTypeNotFound.va, reinterpret_cast<const void*>(&UhcImpactTypeNotFoundHook), 7) ||
      !WriteJmp(sites::kImpactEffectAdd.va, reinterpret_cast<const void*>(&UhcImpactEffectAddHook), 0x15) ||
      !WriteJmp(sites::kImpactEffectWeights.va, reinterpret_cast<const void*>(&UhcImpactEffectWeightsHook), 7) ||
      !WriteJmp(sites::kImpactSpawnUnit.va, reinterpret_cast<const void*>(&UhcImpactSpawnUnitHook), 5) ||
      !WriteJmp(sites::kImpactSpawnTerrain.va, reinterpret_cast<const void*>(&UhcImpactSpawnTerrainHook), 5)) {
    return Outcome::kFailed;
  }
  std::wstring list;
  for (std::size_t i = 0; i < g_names.size(); ++i) {
    list += (i == 0 ? L"" : L", ") + g_names[i] + L" (" + std::to_wstring(kStockTypes + static_cast<int>(i)) + L")";
  }
  Log(L"customImpactTypes: %ls", list.c_str());
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/impacttype_hooks.asm

```asm
; Hooks for customImpactTypes (src/features/impacttypes.cpp).
.686
.model flat, c
option casemap :none

include common.inc

UhcCustomImpactType   PROTO STDCALL nameString:DWORD
UhcAddCustomImpact    PROTO STDCALL effect:DWORD, impactType:DWORD, entry:DWORD
UhcFinishImpactEffect PROTO STDCALL effect:DWORD
UhcSpawnCustomImpact  PROTO STDCALL effect:DWORD, args:DWORD

.data
listAdd       dd 00401F74h
weights       dd 005FE8CDh
spawn         dd 0049C1E5h
addContinue   dd 005FEC89h   ; add ebp,1
weightsCont   dd 005FECA0h   ; lea ecx,[esp+24h]
unitContinue  dd 0049D873h   ; push eax
terrainCont   dd 004CB312h   ; pop edi

.code

; 0x59F464, the not-found end of the impact type by name (EBX = the name's string object, EDI/ESI/EBX
; still pushed). Replaces pop edi / pop esi / or eax,-1 / pop ebx / ret: EAX = 15 + the custom type's
; index, or -1.
UhcImpactTypeNotFoundHook PROC
    TRACE_ONCE "customImpactTypes name lookup (0x59F464)"
    push ebx
    call UhcCustomImpactType
    pop edi
    pop esi
    pop ebx
    ret
UhcImpactTypeNotFoundHook ENDP

; 0x5FEC74, the add of a parsed entry to its type's list (EBX = the type, [esp+20h] = the impact effect,
; [esp+14h] = the entry). Stock types run the stock add; custom ones go to the DLL's lists.
UhcImpactEffectAddHook PROC
    TRACE_ONCE "customImpactTypes impact effect entry (0x5FEC74)"
    cmp ebx, 15
    jge custom
    mov edx, dword ptr [esp+20h]
    lea eax, dword ptr [esp+14h]
    lea ecx, dword ptr [ebx+ebx*2]
    push eax
    lea ecx, dword ptr [edx+ecx*4+4]
    call listAdd
    jmp addContinue
custom:
    push dword ptr [esp+14h]
    push ebx
    push dword ptr [esp+28h]      ; [esp+20h] before the two pushes
    call UhcAddCustomImpact
    jmp addContinue
UhcImpactEffectAddHook ENDP

; 0x5FEC99, the cumulative weights of the 15 stock lists (EBX = the impact effect); the custom lists get
; theirs too.
UhcImpactEffectWeightsHook PROC
    TRACE_ONCE "customImpactTypes impact effect weights (0x5FEC99)"
    mov ecx, ebx
    call weights
    push ebx
    call UhcFinishImpactEffect
    jmp weightsCont
UhcImpactEffectWeightsHook ENDP

; The two calls of the spawn FUN_0049C1E5: ECX = the impact effect, its 8 arguments on the stack, the type
; 4th ([esp+0Ch]). A custom type is spawned by the DLL, which lends it a stock list for the stock call; the
; 8 arguments are then dropped as the callee would have.
SPAWN_HOOK MACRO hookName:REQ, traceText:REQ, continueAt:REQ
hookName PROC
    TRACE_ONCE traceText
    cmp dword ptr [esp+0Ch], 15
    jge custom
    call spawn
    jmp continueAt
custom:
    mov eax, esp
    push eax
    push ecx
    call UhcSpawnCustomImpact
    add esp, 20h
    jmp continueAt
hookName ENDP
ENDM

SPAWN_HOOK UhcImpactSpawnUnitHook, "customImpactTypes impact spawn, projectile hit (0x49D86E)", unitContinue
SPAWN_HOOK UhcImpactSpawnTerrainHook, "customImpactTypes impact spawn, terrain (0x4CB30D)", terrainCont

END
```
