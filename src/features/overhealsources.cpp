// overhealSources [UnitType [cap=<percent>] ...] [log]: only heal actions with <CanOverheal>1</CanOverheal> heal
// marked units above their reference; every other heal stops there.
//
// "Marked" and "reference" are overhealHitpointBars' (overheal.cpp, OverhealUsesInitial and
// OverhealReference, called here through their public forms in overheal_hooks.asm): a unit whose
// proto is of one of its types with 1e-6 < InitialHitpoints < MaxHitpoints, and its reference
// InitialHitpoints (or max x Initial / Max when a modifier changed its max). Without that key no
// unit is marked, so this key needs it.
//
// Which heals overheal. The heal action itself says so, in its tactics <action> or its <ProtoAction>
// (both read through the shared action tag hook, actiontags.h):
// - <CanOverheal>1</CanOverheal> (default 0): this action heals a marked unit above its reference;
// - <OverhealCap>percent</OverhealCap> (100 to 1000): at most that % of the reference (never above the max);
//   without it, up to the max.
// Above the reference the action heals at its own <Rate>, as below it. The Data tech subtypes CanOverheal
// (1 on, 0 off) and OverhealCap, with action="<Name>" or allactions="1" (techsubtypes.h), change both on the
// player's copy of the action, so a tech can give, take away or move the overheal in a game; the values are
// kept by the copy's address and rebuilt when the techs are applied again (a load). Unit types named in the cfg
// are an explicit opt-in that still works: a healer of such a type overheals with every heal action, to its
// type's cap= (the cfg's old rate= is gone: the heal's own rate applies).
//
// Four hooks (hooks/overhealsources_hooks.asm):
// - the add-HP function FUN_004823A3, through which every heal of a unit goes (the heal action,
//   area heals, regeneration, dances, powers, self heals; damage too, as negative amounts): a
//   positive amount on a marked unit is lowered so that HP stops at the reference, unless the
//   heal comes from an overhealing heal action's tick (g_uhcOverhealAllow), which stops at its cap;
// - the heal tick FUN_009E0B53's "HP < max" test (0x9E0BBB): with the action that heals ([action+4], the
//   player's copy of the tactics action, the one whose <Rate> entries the tick reads at 0x9E0CCF), the
//   reference for a marked target and an action that does not overheal, its cap for one that does; the heal
//   action ends there (state 10) and the healer goes idle;
// - the tick's add (0x9E0CE9): sets g_uhcOverhealAllow (and the cap) for an overhealing action;
// - the automatic search FUN_009CD865's first ratio test (0x9CD984), which knows the healer only: a marked unit
//   is a candidate below the highest limit of the healer's heal actions (the reference when none overheals).
// The decisions read only the units' protos, actions and HP, the same on every machine.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

extern "C" {
float UhcOverhealReferenceOf(const char* unit);  // overheal_hooks.asm, cdecl
float UhcOverhealRatioOf(const char* unit);
std::int32_t UhcOverhealMarked(const char* proto);
}

namespace uhc {
extern void (*g_overhealGain)(const char* unit, bool restartDelay);  // set by overhealDecay
extern void (*g_hpLoss)(const char* unit, float amount);             // set by detonationDeath: every loss
}

namespace {

constexpr std::size_t kMaxTypes = 8;
constexpr int kMaxLogLines = 200;
constexpr std::int32_t kMinCap = 100;
constexpr std::int32_t kMaxCap = 1000;

using IsAFn = bool(__thiscall*)(const char* proto, std::int32_t type);
using UnitFloatFn = float(__thiscall*)(const char* unit);
const auto kIsA = reinterpret_cast<IsAFn>(0x0044D7FA);
const auto kMaxHitpoints = reinterpret_cast<UnitFloatFn>(0x00480408);
const auto kHealthRatio = reinterpret_cast<UnitFloatFn>(0x0045F295);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// An action of a proto: every player's copy keeps the proto ID [proto+4] and the action's name index [action+4].
struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

// The tags of an action, from the data: -1 when absent.
struct HealTag {
  std::int32_t canOverheal = -1;
  std::int32_t cap = -1;
};
std::map<ActionKey, HealTag> g_tags;  // filled while the data loads, cleared at each database load

// The tech values of one player's copy of an action, by its address; `key` guards a reused address.
struct TechHeal {
  ActionKey key;
  float canOverheal;
  float cap;
  bool hasCan = false;
  bool hasCap = false;
};
std::unordered_map<const char*, TechHeal> g_techs;

// What an action (or a healer) gives above the reference.
struct Overheal {
  bool on = false;
  std::int32_t cap = 0;  // % of the reference; 0: up to the max
};

std::int32_t g_typeCaps[kMaxTypes] = {};  // the cfg types' cap=, 0 for none
bool g_log = false;
bool g_cap = false;  // overhealSources is on
bool g_addHooked = false;
int g_logLines = 0;
std::set<std::string, std::less<>> g_loggedCaps;        // proto names, "log" only
std::set<std::string, std::less<>> g_loggedSources;     // healed proto names, "log" only
std::set<std::string, std::less<>> g_loggedSourceCaps;  // proto names, "log" only

const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

bool FirstLog(std::set<std::string, std::less<>>& logged, const char* name) {
  if (logged.find(std::string_view(name)) != logged.end()) {
    return false;
  }
  logged.emplace(name);
  return true;
}

bool LogLine() {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return false;
  }
  ++g_logLines;
  return true;
}

// The name of an action's name index, from the database's list (the one being loaded while the data loads).
const wchar_t* ActionName(std::int32_t index) {
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* db = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (db == nullptr || index < 0 || index >= Field<std::int32_t>(db, 0x1FDC)) {
    return nullptr;
  }
  return Field<const wchar_t* const*>(db, 0x1FD8)[index];
}

HealTag TagOf(const ActionKey& key) {
  const auto found = g_tags.find(key);
  return found == g_tags.end() ? HealTag{} : found->second;
}

// The 1 + index of the healer's first cfg type (cfg order), or 0.
std::int32_t TypeIndex(const char* healer);

// What one action of this healer gives: its tags, then its techs, then the healer's cfg type.
Overheal OfAction(const char* healer, const char* action) {
  Overheal out;
  const char* proto = healer == nullptr ? nullptr : Field<const char*>(healer, 0x5C);
  if (proto != nullptr && action != nullptr) {
    const ActionKey key{Field<std::int32_t>(proto, 4), Field<std::int32_t>(action, 4)};
    const HealTag tag = TagOf(key);
    out.on = tag.canOverheal == 1;
    out.cap = tag.cap > 0 ? tag.cap : 0;
    if (!g_techs.empty()) {
      const auto tech = g_techs.find(action);
      if (tech != g_techs.end() && tech->second.key == key) {
        if (tech->second.hasCan) {
          out.on = tech->second.canOverheal > 0.5f;
        }
        if (tech->second.hasCap) {
          const float cap = tech->second.cap;
          out.cap = !(cap >= 1.0f) ? 0 : cap > static_cast<float>(kMaxCap) ? kMaxCap : static_cast<std::int32_t>(cap + 0.5f);
        }
      }
    }
  }
  if (!out.on) {
    const std::int32_t index = TypeIndex(healer);
    if (index > 0) {
      out.on = true;
      out.cap = g_typeCaps[index - 1];
    }
  }
  return out;
}

// The most any heal action of this healer gives (the search knows the healer only).
Overheal OfHealer(const char* healer) {
  Overheal best;
  const char* proto = healer == nullptr ? nullptr : Field<const char*>(healer, 0x5C);
  const char* set = proto == nullptr ? nullptr : Field<const char*>(proto, 0x44);
  if (set != nullptr) {
    char* const* actions = Field<char* const*>(set, 0x1C);
    const std::int32_t count = Field<std::int32_t>(set, 0x20);
    for (std::int32_t i = 0; actions != nullptr && i < count; ++i) {
      const Overheal one = OfAction(healer, actions[i]);
      if (one.on && (!best.on || one.cap == 0 || (best.cap != 0 && one.cap > best.cap))) {
        best = one;
      }
    }
  }
  if (!best.on) {
    best = OfAction(healer, nullptr);  // the cfg type alone
  }
  return best;
}

// The most HP this overheal gives the target: cap % of the reference (at most the max), else the max.
float LimitOf(const char* target, const Overheal& overheal) {
  const float max = kMaxHitpoints(target);
  if (overheal.cap <= 0) {
    return max;
  }
  const float limit = UhcOverhealReferenceOf(target) * (static_cast<float>(overheal.cap) * 0.01f);
  return limit < max ? limit : max;
}

// --- the tags --------------------------------------------------------------------------------------------------

bool ParseCap(const wchar_t* text, std::int32_t* out) {
  if (text == nullptr) {
    return false;
  }
  std::wstring value = text;
  while (!value.empty() && (value.back() == L'%' || value.back() == L' ')) {
    value.pop_back();
  }
  wchar_t* end = nullptr;
  const double number = std::wcstod(value.c_str(), &end);
  if (value.empty() || end != value.c_str() + value.size() || !(number >= kMinCap) || !(number <= kMaxCap)) {
    return false;
  }
  *out = static_cast<std::int32_t>(number + 0.5);
  return true;
}

void OnActionTag(const uhc::ActionTag& tag) {
  const bool can = _wcsicmp(tag.name, L"CanOverheal") == 0;
  if (!can && _wcsicmp(tag.name, L"OverhealCap") != 0) {
    return;
  }
  const wchar_t* tagName = can ? L"CanOverheal" : L"OverhealCap";
  const ActionKey key{Field<std::int32_t>(tag.proto, 4), Field<std::int32_t>(tag.action, 4)};
  const char* protoName = Field<const char*>(tag.proto, 0x10);
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  const wchar_t* actionName = ActionName(key.name);
  if (key.name < 0) {
    uhc::Log(L"overhealSources: proto %hs: <%ls> before the action's <name>, ignored", protoName ? protoName : "?",
             tagName);
    return;
  }
  if (actionName != nullptr) {
    std::wstring lower = actionName;
    for (wchar_t& c : lower) {
      c = static_cast<wchar_t>(towlower(c));
    }
    if (lower.find(L"heal") == std::wstring::npos) {
      uhc::Log(L"overhealSources: proto %hs, action %ls: <%ls> is for heal actions only, ignored",
               protoName ? protoName : "?", actionName, tagName);
      return;
    }
  }
  HealTag& value = g_tags[key];
  if (can) {
    if (_wcsicmp(text, L"1") == 0 || _wcsicmp(text, L"true") == 0) {
      value.canOverheal = 1;
    } else if (_wcsicmp(text, L"0") == 0 || _wcsicmp(text, L"false") == 0) {
      value.canOverheal = 0;
    } else {
      uhc::Log(L"overhealSources: proto %hs, action %ls: <CanOverheal>%ls</CanOverheal> needs 1 or 0, ignored",
               protoName ? protoName : "?", actionName ? actionName : L"?", text);
      return;
    }
  } else if (!ParseCap(text, &value.cap)) {
    uhc::Log(L"overhealSources: proto %hs, action %ls: <OverhealCap>%ls</OverhealCap> needs a percent from %d to %d, "
             L"ignored",
             protoName ? protoName : "?", actionName ? actionName : L"?", text, kMinCap, kMaxCap);
    return;
  }
  if (g_log) {
    uhc::Log(L"overhealSources: proto %hs, action %ls (%ls): <%ls> %ls", protoName ? protoName : "?",
             actionName ? actionName : L"?", tag.source == uhc::ActionSource::kTactics ? L"tactics" : L"protoy", tagName,
             text);
  }
}

void Forget(char*) {
  g_tags.clear();
  g_techs.clear();
}

// --- the tech subtypes -----------------------------------------------------------------------------------------

TechHeal& TechOf(char* action, const char* proto) {
  const ActionKey key{Field<std::int32_t>(proto, 4), Field<std::int32_t>(action, 4)};
  auto inserted = g_techs.emplace(action, TechHeal{key, 0.0f, 0.0f});
  if (!(inserted.first->second.key == key)) {
    inserted.first->second = TechHeal{key, 0.0f, 0.0f};  // the address was another action's copy before
  }
  TechHeal& tech = inserted.first->second;
  const HealTag tag = TagOf(key);
  if (!tech.hasCan) {
    tech.canOverheal = tag.canOverheal == 1 ? 1.0f : 0.0f;
  }
  if (!tech.hasCap) {
    tech.cap = tag.cap > 0 ? static_cast<float>(tag.cap) : 0.0f;
  }
  return tech;
}

void LogTech(const wchar_t* subtype, const TechHeal& tech, std::uint8_t relativity, float amount, bool unapply,
             float before, float after) {
  if (LogLine()) {
    const wchar_t* name = ActionName(tech.key.name);
    uhc::Log(L"overhealSources: proto %d, action %ls, tech subtype %ls, relativity %u, amount %g%ls: %g -> %g",
             tech.key.proto, name ? name : L"?", subtype, relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", static_cast<double>(before), static_cast<double>(after));
  }
}

void ChangeCanOverheal(char* action, const char* baseAction, const char* proto, float amount, std::uint8_t relativity,
                       bool unapply) {
  TechHeal& tech = TechOf(action, proto);
  const HealTag base = baseAction == nullptr ? HealTag{} : TagOf({Field<std::int32_t>(proto, 4), Field<std::int32_t>(baseAction, 4)});
  const float before = tech.canOverheal;
  kEffectValue(relativity, &tech.canOverheal, base.canOverheal == 1 ? 1.0f : 0.0f, amount, unapply);
  tech.hasCan = true;
  LogTech(L"CanOverheal", tech, relativity, amount, unapply, before, tech.canOverheal);
}

void ChangeOverhealCap(char* action, const char* baseAction, const char* proto, float amount, std::uint8_t relativity,
                       bool unapply) {
  TechHeal& tech = TechOf(action, proto);
  const HealTag base = baseAction == nullptr ? HealTag{} : TagOf({Field<std::int32_t>(proto, 4), Field<std::int32_t>(baseAction, 4)});
  const float before = tech.cap;
  kEffectValue(relativity, &tech.cap, base.cap > 0 ? static_cast<float>(base.cap) : 0.0f, amount, unapply);
  tech.hasCap = true;
  LogTech(L"OverhealCap", tech, relativity, amount, unapply, before, tech.cap);
}

}  // namespace

extern "C" {
std::int32_t g_uhcOverhealSourceTypes[kMaxTypes] = {-1, -1, -1, -1, -1, -1, -1, -1};
std::int32_t g_uhcOverhealSourceTypeCount = 0;
std::int32_t g_uhcOverhealAllow = 0;  // set by the tick hook around an overhealing action's add
std::int32_t g_uhcOverhealRegen = 0;  // set by overhealDecay's hooks around a regeneration's add
std::int32_t g_uhcOverhealAllowCap = 0;  // that action's cap, % of the reference (0: the max)

void UhcOverhealAddHook();
void UhcOverhealTickMaxHook();
void UhcOverhealTickAddHook();
void UhcOverhealSearchRatioHook();

// The most HP this heal action ([action+4], its healer at [action+10h]) gives the target: the reference for a
// marked target and an action that does not overheal, else its cap or the stock max. From the tick hook
// (0x9E0BBB), in ST0.
float __stdcall UhcOverhealTickLimit(const char* target, const char* unitAction) {
  const char* proto = Field<const char*>(target, 0x5C);
  if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
    return kMaxHitpoints(target);
  }
  const Overheal overheal = OfAction(Field<const char*>(unitAction, 0x10), Field<const char*>(unitAction, 4));
  return overheal.on ? LimitOf(target, overheal) : UhcOverhealReferenceOf(target);
}

// Around the tick's add (0x9E0CE9): 1 for an overhealing action (its cap in g_uhcOverhealAllowCap), else 0.
std::int32_t __stdcall UhcOverhealTickSource(const char* unitAction) {
  const Overheal overheal = OfAction(Field<const char*>(unitAction, 0x10), Field<const char*>(unitAction, 4));
  g_uhcOverhealAllowCap = overheal.cap;
  return overheal.on ? 1 : 0;
}

// The automatic search's ratio of a candidate for this healer (0x9CD984), in ST0: HP over the limit of the
// healer's best heal action with the stock rules of 0x45F295 (0 below 1e-6, 1.0 from the limit on), so a unit
// at that limit is no candidate; the stock ratio for an unmarked unit or an overheal up to the max.
float __stdcall UhcOverhealSearchRatio(const char* candidate, const char* healer) {
  const char* proto = Field<const char*>(candidate, 0x5C);
  if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
    return kHealthRatio(candidate);
  }
  const Overheal overheal = OfHealer(healer);
  if (!overheal.on) {
    return UhcOverhealRatioOf(candidate);
  }
  if (overheal.cap <= 0) {
    return kHealthRatio(candidate);
  }
  const float limit = LimitOf(candidate, overheal);
  const float hp = Field<float>(candidate, 0x64);
  if (!(limit >= 1e-6f)) {
    return 0.0f;
  }
  return hp >= limit ? 1.0f : hp / limit;
}

// From the add-HP hook, before every HP addition: with overhealSources a positive amount on a marked
// unit is lowered so that HP does not pass the reference, unless an overhealing action's tick is adding
// it (then its cap); with overhealDecay a unit that still goes above its reference is noted.
void __stdcall UhcOverhealAddHp(const char* unit, float* amount) {
  if (!(*amount > 0.0f)) {
    if (*amount < 0.0f && uhc::g_hpLoss != nullptr) {
      uhc::g_hpLoss(unit, *amount);
    }
    return;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
    return;
  }
  const float reference = UhcOverhealReferenceOf(unit);
  const float hp = Field<float>(unit, 0x64);
  if (g_cap && g_uhcOverhealAllow != 0 && g_uhcOverhealAllowCap > 0) {
    const float limit = reference * (static_cast<float>(g_uhcOverhealAllowCap) * 0.01f);
    if (hp + *amount > limit) {
      if (g_log && FirstLog(g_loggedSourceCaps, ProtoName(unit))) {
        uhc::Log(L"overhealSources: an overheal of unit %d (%hs) stops at its cap %.1f, %d %% of its 100 %% %.1f "
                 L"(HP %.1f + %.2f); logged once per proto",
                 Field<std::int32_t>(unit, 0x10), ProtoName(unit), static_cast<double>(limit), g_uhcOverhealAllowCap,
                 static_cast<double>(reference), static_cast<double>(hp), static_cast<double>(*amount));
      }
      *amount = limit > hp ? limit - hp : 0.0f;
    }
  }
  if (!g_cap || g_uhcOverhealAllow != 0) {
    if (uhc::g_overhealGain != nullptr && hp + *amount > reference) {
      uhc::g_overhealGain(unit, g_uhcOverhealRegen == 0);
    }
    if (g_cap && g_log && hp + *amount > reference && FirstLog(g_loggedSources, ProtoName(unit))) {
      uhc::Log(L"overhealSources: unit %d (%hs) is healed above its 100 %% %.1f by an overhealing heal (HP %.1f + "
               L"%.2f); logged once per proto",
               Field<std::int32_t>(unit, 0x10), ProtoName(unit), static_cast<double>(reference),
               static_cast<double>(hp), static_cast<double>(*amount));
    }
    return;
  }
  if (hp + *amount <= reference) {
    return;
  }
  const float capped = reference > hp ? reference - hp : 0.0f;
  if (g_log && FirstLog(g_loggedCaps, ProtoName(unit))) {
    uhc::Log(L"overhealSources: a heal of unit %d (%hs) stops at its 100 %% %.1f (HP %.1f, +%.2f -> +%.2f; not "
             L"from an overhealing heal); logged once per proto",
             Field<std::int32_t>(unit, 0x10), ProtoName(unit), static_cast<double>(reference),
             static_cast<double>(hp), static_cast<double>(*amount), static_cast<double>(capped));
  }
  *amount = capped;
}
}

namespace {

std::int32_t TypeIndex(const char* healer) {
  const char* proto = healer == nullptr ? nullptr : Field<const char*>(healer, 0x5C);
  for (std::int32_t i = 0; proto != nullptr && i < g_uhcOverhealSourceTypeCount; ++i) {
    if (g_uhcOverhealSourceTypes[i] >= 0 && kIsA(proto, g_uhcOverhealSourceTypes[i])) {
      return i + 1;
    }
  }
  return 0;
}

}  // namespace

namespace uhc {

void (*g_overhealGain)(const char* unit, bool restartDelay) = nullptr;
void (*g_hpLoss)(const char* unit, float amount) = nullptr;

bool InstallOverhealAddHook() {
  if (!g_addHooked) {
    // Replaces push ecx / push esi / mov esi,ecx / cmp dword ptr [esi+8],8 at 0x4823A3.
    g_addHooked = WriteJmp(0x004823A3, reinterpret_cast<const void*>(&UhcOverhealAddHook), 8);
  }
  return g_addHooked;
}

bool OverhealAddHookInstalled() { return g_addHooked; }

Outcome ApplyOverhealSources(const Config& config) {
  const Config::Args* args = config.First("overhealSources");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (config.First("overhealHitpointBars") == nullptr) {
    Log(L"overhealSources: needs overhealHitpointBars, whose unit types mark the units with a reference below their "
        L"max; feature not applied");
    return Outcome::kFailed;
  }
  std::vector<std::string> typeNames;
  for (const std::string& arg : *args) {
    const bool cap = _strnicmp(arg.c_str(), "cap=", 4) == 0;
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_strnicmp(arg.c_str(), "rate=", 5) == 0) {
      Log(L"overhealSources: %hs: rate= is gone, an overhealing action heals at its own <Rate>; ignored", arg.c_str());
    } else if (cap) {
      std::string text = arg.substr(4);
      if (!text.empty() && text.back() == '%') {
        text.pop_back();
      }
      char* end = nullptr;
      const long value = std::strtol(text.c_str(), &end, 10);
      const bool valid = !text.empty() && end == text.c_str() + text.size() && value <= kMaxCap && value >= kMinCap;
      if (typeNames.empty() || !valid) {
        Log(L"overhealSources: %hs: expected <UnitType> [cap=<percent>, 100 to 1000] after each type; feature not "
            L"applied",
            arg.c_str());
        return Outcome::kFailed;
      }
      g_typeCaps[typeNames.size() - 1] = static_cast<std::int32_t>(value);
    } else if (arg.find('=') != std::string::npos) {
      Log(L"overhealSources: %hs: expected [<UnitType> [cap=<percent>] ...] [log]; feature not applied", arg.c_str());
      return Outcome::kFailed;
    } else if (typeNames.size() == kMaxTypes) {
      Log(L"overhealSources: more than %u unit types (expected: [UnitType ...] [log]); feature not applied",
          static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      typeNames.push_back(arg);
    }
  }
  if (!VerifyAll("overhealSources", {&sites::kOverhealAddEntry, &sites::kHealTickMax, &sites::kHealTickAdd,
                                     &sites::kHealSearchRatio, &sites::kMaxHitpointsGetter, &sites::kHealthRatio,
                                     &sites::kIsA})) {
    return Outcome::kFailed;
  }
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    if (!RequestAbstractUnitType(typeNames[i].c_str(), &g_uhcOverhealSourceTypes[i])) {
      return Outcome::kFailed;
    }
  }
  g_uhcOverhealSourceTypeCount = static_cast<std::int32_t>(typeNames.size());
  g_cap = true;
  if (!AddActionTagHandler(&OnActionTag) || !AddTechActionSubtype("CanOverheal", &ChangeCanOverheal) ||
      !AddTechActionSubtype("OverhealCap", &ChangeOverhealCap) || !OnDatabaseLoad(&Forget) || !InstallOverhealAddHook() ||
      !WriteJmp(0x009E0BBB, reinterpret_cast<const void*>(&UhcOverhealTickMaxHook), 5) ||
      !WriteJmp(0x009E0CE9, reinterpret_cast<const void*>(&UhcOverhealTickAddHook), 5) ||
      !WriteJmp(0x009CD984, reinterpret_cast<const void*>(&UhcOverhealSearchRatioHook), 5)) {
    return Outcome::kFailed;
  }
  std::string names;
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    names += (i == 0 ? "; and every heal of a healer of unittype " : ", ") + typeNames[i];
    if (g_typeCaps[i] > 0) {
      char text[32];
      std::snprintf(text, sizeof text, " (up to %d %%)", g_typeCaps[i]);
      names += text;
    }
  }
  Log(L"overhealSources: only heal actions with <CanOverheal>1</CanOverheal> (Data subtypes CanOverheal and "
      L"OverhealCap) heal marked units above their 100 %%%hs; every other heal stops there%ls (multiplayer unverified)",
      names.c_str(), g_log ? L"; the tags, techs, first cap and overheal of each proto logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
