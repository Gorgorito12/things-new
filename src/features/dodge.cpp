// dodgeAnyUnit / dodgeSoundSet / criticalSoundSet.
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
#include <cstdint>
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
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

// The stock sound set names the two pushes replace (0xBD74E0, 0xBD7518).
const char* const kStockDodgeSound = reinterpret_cast<const char*>(0x00BD74E0);
const char* const kStockCriticalSound = reinterpret_cast<const char*>(0x00BD7518);

struct SoundRule {
  std::string type;   // unittype or proto name, as written in uhc.cfg
  std::string sound;  // sound set name
  std::int32_t id = -1;
};

// Never resized after the features are applied: the hooks read them from the game thread.
std::vector<SoundRule> g_dodgeSounds;
std::vector<SoundRule> g_criticalSounds;
bool g_log = false;  // "dodgeAnyUnit ... log": also log which sound set each dodge or critical plays

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
  if (dodge == nullptr && !sounds) {
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
      !ParseSoundRules(config, "criticalSoundSet", &g_criticalSounds)) {
    return Outcome::kFailed;
  }

  if (!VerifyAll("dodgeAnyUnit", {&sites::kDodgeProtoCheck, &sites::kDodgeTechCheck, &sites::kDodgeCall,
                                  &sites::kDodgeSound, &sites::kCriticalSound})) {
    return Outcome::kFailed;
  }

  if (dodge != nullptr) {
    if (!RequestAbstractUnitType(typeName.c_str(), &g_uhcDodgeType) ||
        !WriteJmp(sites::kDodgeProtoCheck.va, reinterpret_cast<const void*>(&UhcDodgeProtoHook), 6)) {
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
