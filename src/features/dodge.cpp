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
#include "../unittypes.h"

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
  std::int32_t roll = -1;
  bool dodged = rule.permille >= 1000;
  if (rule.permille > 0 && rule.permille < 1000) {
    roll = kSyncRandom(kSyncRng, 2, 999);
    dodged = roll < rule.permille;
  }
  if (g_chanceLog) {
    uhc::Log(L"dodgeChance: unit %d (%hs), rule %u (%.1f %%): roll %d -> %ls", Field<std::int32_t>(unit, 0x10),
             ProtoName(unit), static_cast<unsigned>(index + 1), rule.permille / 10.0, roll,
             dodged ? L"dodged" : L"hit");
  }
  return dodged ? kDodged : kNotDodged;
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
  if (chance && !VerifyAll("dodgeChance", {&sites::kDodgeTest, &sites::kDodgeRollPath, &sites::kDodgeCaller,
                                           &sites::kSyncRandom, &sites::kTechActive, &sites::kTechByName,
                                           &sites::kDamageTypeLoad, &sites::kIsA})) {
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
