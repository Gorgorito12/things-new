// overhealDecay [<rate>[%] [delay]] [UnitType ...] [log]: the HP of marked units above their reference
// goes back down to it over time, Overwatch style.
//
// How fast, per unit: <OverhealDecay delay="S">R</OverhealDecay> in the proto (read through the shared proto
// tag hook, prototags.h) loses R % of the reference per second, S seconds after the last gain; a marked proto
// without the tag takes the cfg's rate and delay, or 2 % of the reference per second and no delay when the
// line gives none. 0 keeps the overheal. The Data tech subtypes OverhealDecay and OverhealDecayDelay
// (seconds) change them on the player's copy of the proto, or of every proto of a unit type that the effect
// targets (techsubtypes.h); the values are kept by the copy's address and rebuilt when the techs are applied
// again (a load).
//
// "Marked" and "reference" are overhealHitpointBars' (through the public helpers of
// overheal_hooks.asm), so this key needs it. A unit is noted when a heal takes it above its
// reference: the add-HP hook (shared with overhealSources, overhealsources.cpp) calls Note with the
// game time (a heal restarts the delay; a regeneration, flagged by two call-site hooks, does not:
// an idle unit regenerates every step and would otherwise never decay). After each world update (the shared wrapper of worldtick.cpp), every noted unit, in
// unit ID order, loses rate HP per second (or rate % of its reference per second) of game time,
// once <delay> seconds have passed since its last gain, down to the reference and never below it.
// A unit that is gone, dead, unmarked or back at its reference is forgotten. HP is set through the
// stock setter FUN_004820A1 with flag 0: it clamps and updates the damage visuals, and skips its
// death check 0x482152, which a HP above the reference never needs. The setter raises no attack
// event (those come from TakeDamage), so the decay is not seen as an attack.
//
// Saved games: a noted unit carries a marker of stat 65h (savedmarkers.h) with the time of its last gain. The
// add-HP hook can run inside an update over the unit's own actions, so it only names the unit: the world tick
// writes the marker. When another game is running the table is rebuilt from the markers.
//
// "holdNear <UnitType> <metres>" (up to 4): a unit due to decay keeps its HP on any tick where a
// unit of that type owned by the same player (not allies), alive and built, other than itself, is
// within <metres>: the world's spatial query FUN_004A1C55 (noTrainNearEnemyTC's), which measures
// to the other unit's edge. Only whether one exists counts, not the query's order. A held tick is
// skipped, not saved up: the decay goes on at the same rate once no such unit is near.
#include <cstdint>
#include <cstdio>
#include <cctype>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../savedmarkers.h"
#include "../techsubtypes.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
float UhcOverhealReferenceOf(const char* unit);  // overheal_hooks.asm, cdecl
std::int32_t UhcOverhealMarked(const char* proto);
}

namespace uhc {
extern void (*g_overhealGain)(const char* unit, bool restartDelay);  // overhealsources.cpp
bool InstallOverhealAddHook();
bool OverhealAddHookInstalled();
}  // namespace uhc

extern "C" {
void UhcOverhealRegenAddHook();       // overhealsources_hooks.asm: the unit's own regeneration
void UhcOverhealDanceRegenAddHook();  // the Regeneration dance
}

namespace {

constexpr std::size_t kMaxTypes = 8;
constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::int32_t kStatNoted = 0x65;  // words: 1, the game time of the last gain

constexpr std::size_t kMaxHolds = 4;

// The list FUN_004A1C55 fills (the engine's dynamic array: data, count, capacity).
struct IdList {
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using SetHpFn = void(__thiscall*)(char* unit, float value, std::int32_t flag);
using IsAFn = bool(__thiscall*)(const char* proto, std::int32_t type);
using IsAliveFn = bool(__thiscall*)(const char* unit);
using IsBuiltFn = bool(__thiscall*)(const char* unit);
using UnitsNearFn = std::int32_t(__thiscall*)(char* world, const float* point, float radius, char precise, IdList* out);
const auto kSetHp = reinterpret_cast<SetHpFn>(0x004820A1);
const auto kIsA = reinterpret_cast<IsAFn>(0x0044D7FA);
const auto kIsBuilt = reinterpret_cast<IsBuiltFn>(0x0044DDB4);
const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);

bool ParseSeconds(const std::string& arg, std::uint32_t* ms);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// A decay: HP per second, or % of the reference per second, after a delay.
struct Decay {
  float rate = 2.0f;
  bool percent = true;
  std::uint32_t delayMs = 0;
};
Decay g_default;  // the cfg's, else 2 % per second and no delay
std::unordered_map<std::int32_t, Decay> g_tags;  // <OverhealDecay>, by proto ID; cleared at each database load
// The tech values of one player's copy of a proto, by its address; `id` guards a reused address.
struct TechDecay {
  std::int32_t id;
  Decay decay;
  float delaySeconds;
};
std::unordered_map<const char*, TechDecay> g_techs;
int g_techLines = 0;
std::int32_t g_types[kMaxTypes] = {-1, -1, -1, -1, -1, -1, -1, -1};
std::int32_t g_typeCount = 0;
bool g_log = false;

// "holdNear <UnitType> <metres>": the types (IDs set on each data load) and their distances.
struct Hold {
  std::int32_t type = -1;
  float metres = 0.0f;
  std::string name;
};
Hold g_holds[kMaxHolds];
std::size_t g_holdCount = 0;
IdList g_found = {nullptr, 0, 0};  // FUN_004A1C55's output, reused
std::set<std::int32_t> g_heldUnits;  // "log" only: the units held now, so each start and end is one line
int g_holdLines = 0;
constexpr int kMaxHoldLines = 200;

// Noted units by unit ID (so every machine walks them in the same order): the game time of their
// last gain above the reference.
std::map<std::int32_t, std::uint32_t> g_units;
std::vector<std::int32_t> g_changed;  // units whose marker the next tick writes
const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
std::set<std::string, std::less<>> g_loggedStart;  // proto names, "log" only
std::set<std::string, std::less<>> g_loggedEnd;

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<IsAliveFn const* const*>(unit))[0xA4 / 4](unit); }

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

// The unit decays: marked, and of one of the listed types when types were given.
bool Decays(const char* proto) {
  if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
    return false;
  }
  if (g_typeCount == 0) {
    return true;
  }
  for (std::int32_t i = 0; i < g_typeCount; ++i) {
    if (g_types[i] >= 0 && kIsA(proto, g_types[i])) {
      return true;
    }
  }
  return false;
}

// The decay of a unit's proto (the player's copy): its techs', else its tag's, else the default.
Decay DecayOf(const char* proto) {
  const std::int32_t id = Field<std::int32_t>(proto, 8);
  if (!g_techs.empty()) {
    const auto tech = g_techs.find(proto);
    if (tech != g_techs.end() && tech->second.id == id) {
      return tech->second.decay;
    }
  }
  const auto tag = g_tags.find(id);
  return tag == g_tags.end() ? g_default : tag->second;
}

// From the add-HP hook: a gain takes this marked unit above its reference. A heal restarts the
// delay; a regeneration (the unit's own, or the Regeneration dance) does not: it only notes a unit
// that was not noted yet, as if its delay had passed, so regenerating every step cannot hold the
// overheal. A unit whose decay is 0 is not noted.
void Note(const char* unit, bool restartDelay) {
  const char* world = World();
  const char* proto = Field<const char*>(unit, 0x5C);
  if (world == nullptr || !Decays(proto)) {
    return;
  }
  const Decay decay = DecayOf(proto);
  if (!(decay.rate > 0.0f)) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (restartDelay) {
    g_units[id] = now;
  } else if (!g_units.emplace(id, now - decay.delayMs).second) {
    return;
  }
  if (g_changed.empty() || g_changed.back() != id) {
    g_changed.push_back(id);
  }
}

void Reset(char*) {
  g_units.clear();
  g_changed.clear();
  g_heldUnits.clear();
  g_tags.clear();
  g_techs.clear();
}

// <OverhealDecay delay="S">R</OverhealDecay>: R % of the reference per second (0 keeps the overheal), S seconds
// after the last gain (default 0).
bool __cdecl ReadOverhealDecay(void*, const char* node, char* proto) {
  const std::int32_t id = Field<std::int32_t>(proto, 8);
  const char* protoName = Field<const char*>(proto, 0x10);
  const wchar_t* text = Field<const wchar_t*>(node, 0x14);
  std::wstring value = text == nullptr ? L"" : text;
  while (!value.empty() && (value.back() == L'%' || value.back() == L' ')) {
    value.pop_back();
  }
  wchar_t* end = nullptr;
  const double rate = std::wcstod(value.c_str(), &end);
  if (value.empty() || end != value.c_str() + value.size() || !(rate >= 0.0) || rate > 1000.0) {
    uhc::Log(L"overhealDecay: proto %hs: <OverhealDecay> needs a percent of the reference per second from 0 to 1000, "
             L"ignored",
             protoName ? protoName : "?");
    return true;
  }
  Decay decay{static_cast<float>(rate), true, 0};
  const void* attribute = nullptr;
  if (kXmlAttribute(node, "delay", &attribute) && attribute != nullptr) {
    const char* delay = kXmlText(attribute);
    if (delay == nullptr || !ParseSeconds(delay, &decay.delayMs)) {
      uhc::Log(L"overhealDecay: proto %hs: <OverhealDecay delay=\"%hs\"> needs seconds from 0 to 3600, ignored",
               protoName ? protoName : "?", delay ? delay : "");
      return true;
    }
  }
  g_tags[id] = decay;
  if (g_log) {
    uhc::Log(L"overhealDecay: proto %hs loses %.2f %% of its 100 %% per second, %.1f s after its last gain", protoName ? protoName : "?",
             static_cast<double>(decay.rate), decay.delayMs / 1000.0);
  }
  return true;
}

TechDecay& TechOf(char* proto, const char* base) {
  const std::int32_t id = Field<std::int32_t>(proto, 8);
  const auto tag = g_tags.find(Field<std::int32_t>(base, 8));
  const Decay start = tag == g_tags.end() ? g_default : tag->second;
  auto inserted = g_techs.emplace(proto, TechDecay{id, start, start.delayMs / 1000.0f});
  if (inserted.first->second.id != id) {
    inserted.first->second = TechDecay{id, start, start.delayMs / 1000.0f};  // another proto's copy before
  }
  return inserted.first->second;
}

void LogTech(const char* proto, const wchar_t* subtype, std::uint8_t relativity, float amount, bool unapply,
             float before, float after) {
  if (g_log && g_techLines < 200) {
    ++g_techLines;
    const char* name = Field<const char*>(proto, 0x10);
    uhc::Log(L"overhealDecay: proto %hs, tech subtype %ls, relativity %u, amount %g%ls: %g -> %g", name ? name : "?",
             subtype, relativity, static_cast<double>(amount), unapply ? L" (removed)" : L"", static_cast<double>(before),
             static_cast<double>(after));
  }
}

void ChangeDecay(char* proto, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  TechDecay& tech = TechOf(proto, base);
  const auto tag = g_tags.find(Field<std::int32_t>(base, 8));
  const float baseRate = (tag == g_tags.end() ? g_default : tag->second).rate;
  const float before = tech.decay.rate;
  kEffectValue(relativity, &tech.decay.rate, baseRate, amount, unapply);
  if (!(tech.decay.rate >= 0.0f)) {
    tech.decay.rate = 0.0f;
  }
  LogTech(proto, L"OverhealDecay", relativity, amount, unapply, before, tech.decay.rate);
}

void ChangeDecayDelay(char* proto, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  TechDecay& tech = TechOf(proto, base);
  const auto tag = g_tags.find(Field<std::int32_t>(base, 8));
  const float baseDelay = (tag == g_tags.end() ? g_default : tag->second).delayMs / 1000.0f;
  const float before = tech.delaySeconds;
  kEffectValue(relativity, &tech.delaySeconds, baseDelay, amount, unapply);
  const float seconds = tech.delaySeconds < 0.0f ? 0.0f : tech.delaySeconds > 3600.0f ? 3600.0f : tech.delaySeconds;
  tech.decay.delayMs = static_cast<std::uint32_t>(seconds * 1000.0f + 0.5f);
  LogTech(proto, L"OverhealDecayDelay", relativity, amount, unapply, before, tech.delaySeconds);
}

// "holdNear": a unit of a hold type owned by the unit's player, alive and built, other than the
// unit, within that hold's distance (the spatial query's own test, to that unit's edge). Only
// whether one exists decides; *by is the first found, for the log.
bool Held(char* world, const char* unit, const char** by, const Hold** hold) {
  const char* owner = Field<const char*>(unit, 0x44);
  if (owner == nullptr) {
    return false;
  }
  const auto* position = reinterpret_cast<const float*>(unit + 0x14);
  for (std::size_t h = 0; h < g_holdCount; ++h) {
    if (g_holds[h].type < 0) {
      continue;
    }
    kUnitsNear(world, position, g_holds[h].metres, 1, &g_found);
    for (std::int32_t i = 0; i < g_found.count && g_found.data != nullptr; ++i) {
      const char* other = UnitById(world, g_found.data[i]);
      const char* proto = other == nullptr ? nullptr : Field<const char*>(other, 0x5C);
      if (proto == nullptr || other == unit || Field<const char*>(other, 0x44) != owner ||
          !kIsA(proto, g_holds[h].type) || !IsAlive(other) || !kIsBuilt(other)) {
        continue;
      }
      *by = other;
      *hold = &g_holds[h];
      return true;
    }
  }
  return false;
}

// "log": one line when a unit starts or stops being held (at most kMaxHoldLines).
void LogHold(std::int32_t id, const char* unit, bool held, const char* by, const Hold* hold) {
  if (!g_log || g_holdLines >= kMaxHoldLines) {
    return;
  }
  const bool was = g_heldUnits.count(id) != 0;
  if (held == was) {
    return;
  }
  ++g_holdLines;
  if (held) {
    g_heldUnits.insert(id);
    uhc::Log(L"overhealDecay: unit %d (%hs) holds its overheal at HP %.1f: unit %d (%hs) of %hs is within %.1f m%ls",
             id, ProtoName(unit), static_cast<double>(Field<float>(unit, 0x64)), Field<std::int32_t>(by, 0x10),
             ProtoName(by), hold->name.c_str(), static_cast<double>(hold->metres),
             g_holdLines == kMaxHoldLines ? L" (further holds not logged)" : L"");
  } else {
    g_heldUnits.erase(id);
    uhc::Log(L"overhealDecay: unit %d (%hs) decays again from HP %.1f: no unit that holds it is near%ls", id,
             ProtoName(unit), static_cast<double>(Field<float>(unit, 0x64)),
             g_holdLines == kMaxHoldLines ? L" (further holds not logged)" : L"");
  }
}

void WriteMarker(char* unit, std::uint32_t lastGain) {
  namespace markers = uhc::markers;
  char* marker = markers::Find(unit, kStatNoted, 1);
  if (marker == nullptr) {
    marker = markers::Take(unit, kStatNoted);
  }
  if (marker != nullptr) {
    markers::Word(marker, 0) = 1;
    markers::Word(marker, 1) = lastGain;
  }
}

void ClearMarker(char* unit) {
  if (char* marker = uhc::markers::Find(unit, kStatNoted, 1)) {
    uhc::markers::Free(marker);
  }
}

// The table from the markers of a game that just started or loaded: one walk over the world's units.
void Rebuild(const char* world) {
  namespace markers = uhc::markers;
  g_units.clear();
  g_changed.clear();
  g_heldUnits.clear();
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* units = Field<char* const*>(world, 0x0C);
  for (std::int32_t i = 0; i < count; ++i) {
    const char* unit = units[i];
    if (unit == nullptr) {
      continue;
    }
    if (char* marker = markers::Find(unit, kStatNoted, 1)) {
      g_units[Field<std::int32_t>(unit, 0x10)] = markers::Word(marker, 1);
    }
  }
  if (!g_units.empty()) {
    uhc::Log(L"overhealDecay: %u noted unit(s) found in the saved game", static_cast<unsigned>(g_units.size()));
  }
}

// After each world update: game time [world+108h] since the last tick, never the real clock. A new
// game (another game world, the time going back or the step count jumping) takes the units its markers say.
void DecayTick(char* world, std::int32_t) {
  // The world update also runs for other worlds (the home city's; 0x481D01 compares this with
  // [game+13Ch]): only the game world's units decay, and another world must not look like a new game.
  if (world != World()) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const bool sameGame = world == g_world && now >= g_lastTime && step - g_lastStep <= 1;
  const std::uint32_t elapsed = sameGame ? now - g_lastTime : 0;
  if (!sameGame) {
    g_world = world;
    Rebuild(world);
  }
  g_lastTime = now;
  g_lastStep = step;
  for (const std::int32_t id : g_changed) {
    const auto noted = g_units.find(id);
    char* unit = noted == g_units.end() ? nullptr : UnitById(world, id);
    if (unit != nullptr) {
      WriteMarker(unit, noted->second);
    }
  }
  g_changed.clear();
  if (elapsed == 0) {
    return;
  }
  for (auto it = g_units.begin(); it != g_units.end();) {
    char* unit = UnitById(world, it->first);
    if (unit == nullptr || !IsAlive(unit) || !Decays(Field<const char*>(unit, 0x5C))) {
      if (unit != nullptr) {
        ClearMarker(unit);
      }
      g_heldUnits.erase(it->first);
      it = g_units.erase(it);
      continue;
    }
    const float reference = UhcOverhealReferenceOf(unit);
    const float hp = Field<float>(unit, 0x64);
    if (!(hp > reference)) {
      if (g_log && FirstLog(g_loggedEnd, ProtoName(unit))) {
        uhc::Log(L"overhealDecay: unit %d (%hs) is back at its 100 %% %.1f; logged once per proto", it->first,
                 ProtoName(unit), static_cast<double>(reference));
      }
      ClearMarker(unit);
      g_heldUnits.erase(it->first);
      it = g_units.erase(it);
      continue;
    }
    const Decay decay = DecayOf(Field<const char*>(unit, 0x5C));
    if (now - it->second < decay.delayMs || !(decay.rate > 0.0f)) {
      ++it;
      continue;
    }
    if (g_holdCount > 0) {
      const char* by = nullptr;
      const Hold* hold = nullptr;
      const bool held = Held(world, unit, &by, &hold);
      LogHold(it->first, unit, held, by, hold);
      if (held) {
        ++it;
        continue;
      }
    }
    const float perSecond = decay.percent ? reference * decay.rate * 0.01f : decay.rate;
    float value = hp - perSecond * static_cast<float>(elapsed) * 0.001f;
    if (g_log && FirstLog(g_loggedStart, ProtoName(unit))) {
      uhc::Log(L"overhealDecay: unit %d (%hs) decays from %.1f toward its 100 %% %.1f at %.2f HP/s; logged once "
               L"per proto",
               it->first, ProtoName(unit), static_cast<double>(hp), static_cast<double>(reference),
               static_cast<double>(perSecond));
    }
    const bool reached = !(value > reference);
    if (reached) {
      value = reference;
    }
    kSetHp(unit, value, 0);
    ++it;  // forgotten on the next tick once it is at its reference
  }
}

// "2", "1.5", "3%": a positive number, with an optional % sign.
bool ParseRate(const std::string& arg, float* rate, bool* percent) {
  std::string text = arg;
  *percent = !text.empty() && text.back() == '%';
  if (*percent) {
    text.pop_back();
  }
  char* end = nullptr;
  const double value = std::strtod(text.c_str(), &end);
  if (text.empty() || end != text.c_str() + text.size() || !(value > 0.0) || value > 1.0e6) {
    return false;
  }
  *rate = static_cast<float>(value);
  return true;
}

bool ParseSeconds(const std::string& arg, std::uint32_t* ms) {
  char* end = nullptr;
  const double value = std::strtod(arg.c_str(), &end);
  if (arg.empty() || end != arg.c_str() + arg.size() || value < 0.0 || value > 3600.0) {
    return false;
  }
  *ms = static_cast<std::uint32_t>(value * 1000.0 + 0.5);
  return true;
}

}  // namespace

namespace uhc {

Outcome ApplyOverhealDecay(const Config& config) {
  const Config::Args* args = config.First("overhealDecay");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (config.First("overhealHitpointBars") == nullptr) {
    Log(L"overhealDecay: needs overhealHitpointBars, whose unit types mark the units with a reference below their "
        L"max; feature not applied");
    return Outcome::kFailed;
  }
  // An optional default for the protos without <OverhealDecay>: a rate (HP, or % of the reference with %), then
  // optionally its delay. A first argument that is a number but not a valid rate is an error, not a type.
  std::size_t first = 0;
  if (!args->empty() && !args->front().empty() &&
      (std::isdigit(static_cast<unsigned char>(args->front()[0])) || args->front()[0] == '.' || args->front()[0] == '-')) {
    if (!ParseRate(args->front(), &g_default.rate, &g_default.percent)) {
      Log(L"overhealDecay: %hs: expected [<HP per second>[%%] [delay seconds]] [UnitType ...] [log], e.g. overhealDecay "
          L"2%% 3; feature not applied",
          args->front().c_str());
      return Outcome::kFailed;
    }
    first = 1;
  }
  std::vector<std::string> typeNames;
  for (std::size_t i = first; i < args->size(); ++i) {
    const std::string& arg = (*args)[i];
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "holdNear") == 0) {
      char* end = nullptr;
      const std::string* metres = i + 2 < args->size() ? &(*args)[i + 2] : nullptr;
      const double value = metres == nullptr ? 0.0 : std::strtod(metres->c_str(), &end);
      if (metres == nullptr || g_holdCount == kMaxHolds || end != metres->c_str() + metres->size() ||
          metres->empty() || !(value > 0.0) || value > 200.0) {
        Log(L"overhealDecay: expected holdNear <UnitType> <metres> (more than 0, at most 200; up to %u); feature not "
            L"applied",
            static_cast<unsigned>(kMaxHolds));
        return Outcome::kFailed;
      }
      g_holds[g_holdCount].name = (*args)[i + 1];
      g_holds[g_holdCount].metres = static_cast<float>(value);
      ++g_holdCount;
      i += 2;
    } else if (first == 1 && i == 1 && ParseSeconds(arg, &g_default.delayMs)) {
      // the delay
    } else if (typeNames.size() == kMaxTypes) {
      Log(L"overhealDecay: more than %u unit types; feature not applied", static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      typeNames.push_back(arg);
    }
  }
  const Site* addEntry = OverhealAddHookInstalled() ? &sites::kHpSetter : &sites::kOverhealAddEntry;
  if (!VerifyAll("overhealDecay", {addEntry, &sites::kHpSetter, &sites::kMaxHitpointsGetter, &sites::kUnitAliveSlot,
                                   &sites::kIsA, &sites::kRegenAddHp, &sites::kDanceRegenAddHp}) ||
      (g_holdCount > 0 && !VerifyAll("overhealDecay holdNear", {&sites::kUnitsNearPoint, &sites::kIsBuilt})) ||
      !OnDatabaseLoad(&Reset) || !AddProtoTagHandler("OverhealDecay", &ReadOverhealDecay) ||
      !AddTechSubtype("OverhealDecay", &ChangeDecay) || !AddTechSubtype("OverhealDecayDelay", &ChangeDecayDelay)) {
    return Outcome::kFailed;
  }
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    if (!RequestAbstractUnitType(typeNames[i].c_str(), &g_types[i])) {
      return Outcome::kFailed;
    }
  }
  for (std::size_t i = 0; i < g_holdCount; ++i) {
    if (!RequestAbstractUnitType(g_holds[i].name.c_str(), &g_holds[i].type)) {
      return Outcome::kFailed;
    }
  }
  g_typeCount = static_cast<std::int32_t>(typeNames.size());
  g_overhealGain = &Note;
  // The adder's two regeneration calls (call 4823A3h) are flagged, so they do not restart the delay.
  if (!InstallOverhealAddHook() || !WriteJmp(0x00490881, reinterpret_cast<const void*>(&UhcOverhealRegenAddHook), 5) ||
      !WriteJmp(0x0067A03B, reinterpret_cast<const void*>(&UhcOverhealDanceRegenAddHook), 5) ||
      !AddWorldTick(&DecayTick)) {
    g_overhealGain = nullptr;
    return Outcome::kFailed;
  }
  std::string names;
  for (const std::string& name : typeNames) {
    names += ", " + name;
  }
  std::string holds;
  for (std::size_t i = 0; i < g_holdCount; ++i) {
    char text[32];
    std::snprintf(text, sizeof text, " %.1f m", static_cast<double>(g_holds[i].metres));
    holds += (holds.empty() ? "; held while their player has a unit of " : ", or of ") + g_holds[i].name + " within" +
             text;
  }
  Log(L"overhealDecay: marked units above their 100 %% lose their <OverhealDecay> (%% of it per second, after its "
      L"delay; Data subtypes OverhealDecay and OverhealDecayDelay), or %.2f %ls per second of game time %.1f s after "
      L"their last gain, down to it%hs%hs%ls (multiplayer unverified)",
      static_cast<double>(g_default.rate), g_default.percent ? L"% of it" : L"HP", g_default.delayMs / 1000.0,
      names.empty() ? "" : (" (units of" + names.substr(1) + " only)").c_str(), holds.c_str(),
      g_log ? L"; logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
