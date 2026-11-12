// researchGrants: a building gathers "grant points" over game time, and each point makes one of its player's
// researches cheaper or free.
//
//   <ResearchGrantInterval>240</ResearchGrantInterval>   game seconds per point; the proto has grants with it
//   <ResearchGrantMax>3</ResearchGrantMax>               the cap of stored points (default 1)
//   <ResearchGrantCost>0</ResearchGrantCost>             the share of the cost paid with a point (default 0, free)
//   <ResearchGrantTime>1</ResearchGrantTime>             the research time factor with a point (default 1)
//   <ResearchGrantScope>all</ResearchGrantScope>         all: a research in any of the player's buildings;
//                                                        self: only one in this building (default all)
//   <ResearchGrantMinCost>0</ResearchGrantMinCost>       a point goes on a research the player can pay only
//                                                        when its total cost is at least this (default 0)
//
// The tags are read once, by proto ID, and are the same for every player. Three tech effects type="Data" act on
// one player's copy of the proto: subtype="ResearchGrantInterval" and "ResearchGrantMax" change the interval and
// the cap through the stock value function 0x7F892A (base: the tags), and "ResearchGrantPoints" gives that many
// points at once to the player's built units of the proto, up to the cap.
//
// Points: the units of a tagged proto are found by a sweep of the world's unit table (a slice per world update,
// the whole table when a game starts or loads, or when a ResearchGrantPoints effect needs them all). After each
// world update (worldtick.h), each living, built one advances its timer by the game time [world+108h] that
// passed and gains a point per interval, up to its cap; at the cap the timer waits at 0. The points and the timer
// are a saved marker on the unit (savedmarkers.h, stat 66h), so a save keeps them and the unit's death loses
// them. A transform in place ends the unit's markers: it starts again from 0.
//
// Spending, through the shared research payment (researchpay.h), after nextResearchFree: when a research is
// paid, the paying player's tagged units with a point, in scope (self: the unit that researches), are the
// candidates. A point goes on it when the tech's cost is above 0 (or its Time factor is not 1) and either the
// player cannot pay the full cost (the stock check 0x8D6BAE, or 0x8D6C1B with shared resources) or the total
// cost is at least ResearchGrantMinCost. The unit with most points pays (the lowest unit ID on a tie). The
// payment takes the Cost share; a cancel refunds what was paid and never the point. A Time factor other than 1
// divides each step of that research's progress (two hooks on the add of the step, hooks/researchgrant_hooks.asm),
// remembered by researching unit and tech ID, and saved as a second kind of marker on that unit.
//
// What the player sees (display only): the rule is one function, Choose, which the claim runs for a payment and,
// through PreviewResearchPay (researchpay.h, every key in the payment's order), for the command panel. A tech button
// whose research would get a share below 1 shows the free word or the price after it (its overlay text, the buffer the
// Buy buttons use), and its rollover the cost after the share and a green label; the hook of the panel's call of the
// rollover builder at 0x4622C5 and of the builder's copy of the cost at 0x4C73FD. A spent point shows the label as a
// floating text over the paying building, to its owner (floatingtext.h). Options: notext, text=, noprice, free=, log.
#include <windows.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "../features.h"
#include "../floatingtext.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../researchpay.h"
#include "../savedmarkers.h"
#include "../techsubtypes.h"
#include "../unitpanel.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
std::int32_t g_uhcGrantTimed = 0;  // researches with a Time factor in progress: the step hooks look only then
void UhcGrantResearchStepHook();
void UhcGrantCommandStepHook();
void UhcGrantTechButtonHook();
void UhcGrantTipCostHook();
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::int32_t kStat = 0x66;                  // savedmarkers.h: no other key uses it
constexpr std::uint32_t kGrantWord = 0x52474E54;      // word 0 of a unit's points marker: 'RGNT'
constexpr std::uint32_t kTimedWord = 0x52475449;      // word 0 of a research's Time factor marker: 'RGTI'
constexpr std::int32_t kSweepSlots = 256;             // world table slots looked at per world update
constexpr int kMaxLogLines = 300;

using IsBuiltFn = bool(__thiscall*)(const char* unit);
using IsAliveFn = bool(__thiscall*)(const char* unit);
using AffordFn = bool(__thiscall*)(const char* player, const void* cost);
using ResGetFn = float(__thiscall*)(const void* list, std::int32_t r);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kIsBuilt = reinterpret_cast<IsBuiltFn>(0x0044DDB4);
const auto kAfford = reinterpret_cast<AffordFn>(0x008D6BAE);
const auto kSharedAfford = reinterpret_cast<AffordFn>(0x008D6C1B);
const auto kResGet = reinterpret_cast<ResGetFn>(0x0044EFFF);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);

// The display (the tech button and its rollover)
constexpr std::uint32_t kResListCount = 0x00C6DF38;  // the entries of every ResList
using CostCopyFn = void*(__thiscall*)(void* cost, const void* from);
using CostFillFn = void(__thiscall*)(void* cost, float value);
using CostScaleFn = void(__thiscall*)(void* cost, float factor);
using AppendFn = void(__thiscall*)(void* text, const wchar_t* more, std::int32_t length, std::int32_t start);
const auto kCostCopy = reinterpret_cast<CostCopyFn>(0x00480A73);
const auto kCostFill = reinterpret_cast<CostFillFn>(0x004E2617);
const auto kCostScale = reinterpret_cast<CostScaleFn>(0x00480B94);
const auto kAppend = reinterpret_cast<AppendFn>(0x00443960);  // BString append; -1, -1: all of it, at the end

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Tags {
  float interval = 0.0f;  // seconds; 0: no grants
  float max = 1.0f;
  float cost = 0.0f;
  float time = 1.0f;
  bool self = false;
  float minCost = 0.0f;
};
std::map<std::int32_t, Tags> g_tags;  // by proto ID; the data load fills it

struct TechValues {
  std::int32_t id;  // the proto ID the copy had: a reused pointer with another ID is ignored
  float interval;
  float max;
};
std::unordered_map<const char*, TechValues> g_tech;  // by the player's copy of the proto; lookups only

struct PendingPoints {
  const char* copy;
  std::int32_t id;
  std::int32_t points;
};
std::vector<PendingPoints> g_pendingPoints;  // ResearchGrantPoints effects, for the next world tick

std::set<std::int32_t> g_units;  // unit IDs of tagged protos, in ID order: the same walk on every machine
std::map<std::pair<std::int32_t, std::int32_t>, float> g_timed;  // (researching unit ID, tech ID) -> factor
std::vector<std::pair<std::int32_t, std::int32_t>> g_timedChanged;  // whose marker the next tick writes

const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
std::int32_t g_cursor = 0;
bool g_checkTags = true;

struct Claim {
  std::int32_t unit = -1;  // the unit that pays a point
  float time = 1.0f;
  float cost = 0.0f;
};
Claim g_claim;

bool g_log = false;
int g_logLines = 0;

// What the local player sees (display only: none of it feeds the simulation).
constexpr std::uint32_t kTextColour = 0xFF60FF60;  // ARGB
constexpr float kTextLife = 3.0f;                  // three times the dodge text's life: a research is rarer
bool g_text = true;                // the floating text over the building that pays a point
std::wstring g_customText;         // text=<text>: instead of the label
std::int32_t g_textStringId = -1;  // text=<string table ID>
bool g_price = true;               // the price on the tech button and in its rollover
std::string g_freeWord = "Free";   // free=<text>: the button's word for a research that costs nothing

bool LogOk() {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return false;
  }
  ++g_logLines;
  return true;
}

const char* MainWorld() {
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

std::int32_t ProtoId(const char* proto) { return Field<std::int32_t>(proto, 8); }

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const Tags* TagsOf(const char* proto) {
  if (proto == nullptr) {
    return nullptr;
  }
  const auto found = g_tags.find(ProtoId(proto));
  return found != g_tags.end() && found->second.interval > 0.0f ? &found->second : nullptr;
}

const TechValues* TechOf(const char* copy) {
  if (g_tech.empty()) {
    return nullptr;
  }
  const auto found = g_tech.find(copy);
  return found != g_tech.end() && found->second.id == ProtoId(copy) ? &found->second : nullptr;
}

// The player's values: the tags, as the techs left them. At least 1 s, and a cap of at least 0.
std::uint32_t IntervalMs(const char* copy, const Tags& tags) {
  const TechValues* tech = TechOf(copy);
  const float seconds = tech != nullptr ? tech->interval : tags.interval;
  return seconds < 1.0f ? 1000u : static_cast<std::uint32_t>(std::lround(seconds * 1000.0f));
}

std::int32_t Cap(const char* copy, const Tags& tags) {
  const TechValues* tech = TechOf(copy);
  const long cap = std::lround(tech != nullptr ? tech->max : tags.max);
  return cap < 0 ? 0 : static_cast<std::int32_t>(cap);
}

// --- Tags -----------------------------------------------------------------------------------------------------

const wchar_t* NodeText(const char* node) { return *reinterpret_cast<const wchar_t* const*>(node + 0x14); }

bool ReadNumber(const char* node, char* proto, const wchar_t* tag, float low, float high, float* out) {
  const wchar_t* text = NodeText(node);
  wchar_t* end = nullptr;
  const double value = text != nullptr ? std::wcstod(text, &end) : 0.0;
  if (text == nullptr || end == text || !(value >= low) || !(value <= high)) {
    uhc::Log(L"researchGrants: proto %d (%hs): <%ls> needs a number from %g to %g, not \"%ls\"; ignored",
             ProtoId(proto), ProtoName(proto), tag, static_cast<double>(low), static_cast<double>(high),
             text != nullptr ? text : L"");
    return false;
  }
  *out = static_cast<float>(value);
  if (g_log) {
    uhc::Log(L"researchGrants: proto %d (%hs): %ls %g", ProtoId(proto), ProtoName(proto), tag, value);
  }
  return true;
}

bool __cdecl ReadInterval(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"ResearchGrantInterval", 1.0f, 36000.0f, &value)) {
    g_tags[ProtoId(proto)].interval = value;
  }
  return true;
}

bool __cdecl ReadMax(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"ResearchGrantMax", 1.0f, 1000.0f, &value)) {
    g_tags[ProtoId(proto)].max = std::floor(value);
  }
  return true;
}

bool __cdecl ReadCost(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"ResearchGrantCost", 0.0f, 1.0f, &value)) {
    g_tags[ProtoId(proto)].cost = value;
  }
  return true;
}

bool __cdecl ReadTime(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"ResearchGrantTime", 0.01f, 100.0f, &value)) {
    g_tags[ProtoId(proto)].time = value;
  }
  return true;
}

bool __cdecl ReadMinCost(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"ResearchGrantMinCost", 0.0f, 1.0e7f, &value)) {
    g_tags[ProtoId(proto)].minCost = value;
  }
  return true;
}

bool __cdecl ReadScope(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  if (text != nullptr && (_wcsicmp(text, L"all") == 0 || _wcsicmp(text, L"self") == 0)) {
    g_tags[ProtoId(proto)].self = _wcsicmp(text, L"self") == 0;
    if (g_log) {
      uhc::Log(L"researchGrants: proto %d (%hs): ResearchGrantScope %ls", ProtoId(proto), ProtoName(proto), text);
    }
  } else {
    uhc::Log(L"researchGrants: proto %d (%hs): <ResearchGrantScope> is all or self, not \"%ls\"; ignored",
             ProtoId(proto), ProtoName(proto), text != nullptr ? text : L"");
  }
  return true;
}

// --- Tech subtypes --------------------------------------------------------------------------------------------

TechValues* TechSlot(char* copy, const char* base) {
  const auto tag = g_tags.find(ProtoId(base));
  if (tag == g_tags.end() || tag->second.interval <= 0.0f) {
    return nullptr;
  }
  auto inserted = g_tech.emplace(copy, TechValues{ProtoId(copy), tag->second.interval, tag->second.max});
  if (inserted.first->second.id != ProtoId(copy)) {
    inserted.first->second = TechValues{ProtoId(copy), tag->second.interval, tag->second.max};
  }
  return &inserted.first->second;
}

void ChangeValue(char* copy, const char* base, float amount, std::uint8_t relativity, bool unapply, bool interval) {
  TechValues* slot = TechSlot(copy, base);
  const wchar_t* name = interval ? L"ResearchGrantInterval" : L"ResearchGrantMax";
  if (slot == nullptr) {
    uhc::Log(L"researchGrants: tech subtype %ls on proto %d (%hs), which has no <ResearchGrantInterval>; ignored",
             name, ProtoId(copy), ProtoName(copy));
    return;
  }
  const Tags& tags = g_tags[ProtoId(base)];
  float* field = interval ? &slot->interval : &slot->max;
  const float before = *field;
  kEffectValue(relativity, field, interval ? tags.interval : tags.max, amount, unapply);
  if (LogOk()) {
    uhc::Log(L"researchGrants: proto %d, tech subtype %ls, relativity %u, amount %g%ls: %g -> %g", ProtoId(copy), name,
             relativity, static_cast<double>(amount), unapply ? L" (removed)" : L"", static_cast<double>(before),
             static_cast<double>(*field));
  }
}

void ChangeInterval(char* copy, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  ChangeValue(copy, base, amount, relativity, unapply, true);
}

void ChangeMax(char* copy, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  ChangeValue(copy, base, amount, relativity, unapply, false);
}

void GivePoints(char* copy, const char* base, float amount, std::uint8_t, bool unapply) {
  const long points = std::lround(amount);
  if (unapply || points == 0) {
    return;  // points given are kept
  }
  const auto tag = g_tags.find(ProtoId(base));
  if (tag == g_tags.end() || tag->second.interval <= 0.0f) {
    uhc::Log(L"researchGrants: tech subtype ResearchGrantPoints on proto %d (%hs), which has no "
             L"<ResearchGrantInterval>; ignored",
             ProtoId(copy), ProtoName(copy));
    return;
  }
  g_pendingPoints.push_back({copy, ProtoId(copy), static_cast<std::int32_t>(points)});
}

void ForgetOnDataLoad(char*) {
  g_tech.clear();
  g_pendingPoints.clear();
  g_units.clear();
  g_timed.clear();
  g_timedChanged.clear();
  g_uhcGrantTimed = 0;
  g_world = nullptr;
  g_cursor = 0;
  g_checkTags = true;
  g_claim = Claim{};
}

// --- Markers --------------------------------------------------------------------------------------------------

char* GrantMarker(const char* unit) { return uhc::markers::Find(unit, kStat, kGrantWord); }

char* TakeGrantMarker(char* unit) {
  if (char* marker = GrantMarker(unit)) {
    return marker;
  }
  char* marker = uhc::markers::Take(unit, kStat);
  if (marker != nullptr) {
    uhc::markers::Word(marker, 0) = kGrantWord;
  }
  return marker;
}

std::int32_t PointsOf(const char* unit) {
  char* marker = GrantMarker(unit);
  return marker != nullptr ? static_cast<std::int32_t>(uhc::markers::Word(marker, 1)) : 0;
}

char* TimedMarker(const char* unit, std::int32_t tech) {
  char* found = nullptr;
  uhc::markers::ForEach(unit, kStat, [&](char* marker) {
    if (uhc::markers::Word(marker, 0) != kTimedWord || static_cast<std::int32_t>(uhc::markers::Word(marker, 1)) != tech) {
      return true;
    }
    found = marker;
    return false;
  });
  return found;
}

void SetTimed(std::int32_t unit, std::int32_t tech, float factor) {
  const auto key = std::make_pair(unit, tech);
  if (factor == 1.0f) {
    if (g_timed.erase(key) == 0) {
      return;
    }
  } else {
    g_timed[key] = factor;
  }
  g_uhcGrantTimed = static_cast<std::int32_t>(g_timed.size());
  g_timedChanged.push_back(key);
}

// The marker of each research whose factor changed: written, or freed once it is gone.
void WriteTimedMarkers(const char* world) {
  for (const auto& key : g_timedChanged) {
    char* unit = UnitById(world, key.first);
    if (unit == nullptr) {
      continue;
    }
    const auto timed = g_timed.find(key);
    char* marker = TimedMarker(unit, key.second);
    if (timed == g_timed.end()) {
      if (marker != nullptr) {
        uhc::markers::Free(marker);
      }
      continue;
    }
    if (marker == nullptr) {
      marker = uhc::markers::Take(unit, kStat);
    }
    if (marker != nullptr) {
      uhc::markers::Word(marker, 0) = kTimedWord;
      uhc::markers::Word(marker, 1) = static_cast<std::uint32_t>(key.second);
      std::memcpy(&uhc::markers::Word(marker, 2), &timed->second, sizeof(float));
    }
  }
  g_timedChanged.clear();
}

// --- The units ------------------------------------------------------------------------------------------------

void Consider(const char* unit) {
  if (unit != nullptr && TagsOf(Field<const char*>(unit, 0x5C)) != nullptr && IsAlive(unit)) {
    g_units.insert(Field<std::int32_t>(unit, 0x10));
  }
}

void SweepAll(const char* world) {
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
    Consider(table[i]);
  }
}

void SweepSlice(const char* world) {
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  if (table == nullptr || count <= 0) {
    return;
  }
  for (std::int32_t n = 0; n < kSweepSlots && n < count; ++n) {
    if (g_cursor >= count) {
      g_cursor = 0;
    }
    Consider(table[g_cursor++]);
  }
}

void CheckTags() {
  g_checkTags = false;
  for (const auto& [id, tags] : g_tags) {
    if (tags.interval <= 0.0f) {
      uhc::Log(L"researchGrants: proto %d has research grant tags but no valid <ResearchGrantInterval>: no grants", id);
    }
  }
}

// A game that just started or loaded: its units, and the Time factors its markers keep. One walk.
void Rebuild(const char* world) {
  g_units.clear();
  g_timed.clear();
  g_timedChanged.clear();
  g_cursor = 0;
  g_claim = Claim{};
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  std::int32_t points = 0;
  for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
    const char* unit = table[i];
    if (unit == nullptr) {
      continue;
    }
    Consider(unit);
    if (g_units.count(Field<std::int32_t>(unit, 0x10)) != 0) {
      points += PointsOf(unit);
    }
    const std::int32_t id = Field<std::int32_t>(unit, 0x10);
    uhc::markers::ForEach(unit, kStat, [&](char* marker) {
      if (uhc::markers::Word(marker, 0) == kTimedWord) {
        float factor = 1.0f;
        std::memcpy(&factor, &uhc::markers::Word(marker, 2), sizeof(float));
        g_timed[{id, static_cast<std::int32_t>(uhc::markers::Word(marker, 1))}] = factor;
      }
      return true;
    });
  }
  g_uhcGrantTimed = static_cast<std::int32_t>(g_timed.size());
  if (!g_units.empty() || !g_timed.empty()) {
    uhc::Log(L"researchGrants: %u unit(s) with grants, %d point(s) and %u research(es) with a Time factor in this game",
             static_cast<unsigned>(g_units.size()), points, static_cast<unsigned>(g_timed.size()));
  }
}

// The game time since the last tick; a new game rebuilds the tables and gives 0.
std::uint32_t Sync(const char* world) {
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
  return elapsed;
}

void ApplyPendingPoints(const char* world) {
  SweepAll(world);
  for (const PendingPoints& pending : g_pendingPoints) {
    for (const std::int32_t id : g_units) {
      char* unit = UnitById(world, id);
      if (unit == nullptr || Field<const char*>(unit, 0x5C) != pending.copy || ProtoId(pending.copy) != pending.id ||
          !kIsBuilt(unit)) {
        continue;
      }
      const Tags* tags = TagsOf(pending.copy);
      char* marker = tags != nullptr ? TakeGrantMarker(unit) : nullptr;
      if (marker == nullptr) {
        continue;
      }
      const std::int32_t cap = Cap(pending.copy, *tags);
      std::int32_t points = static_cast<std::int32_t>(uhc::markers::Word(marker, 1)) + pending.points;
      points = points < 0 ? 0 : (points > cap ? cap : points);
      uhc::markers::Word(marker, 1) = static_cast<std::uint32_t>(points);
      if (points >= cap) {
        uhc::markers::Word(marker, 2) = 0;
      }
      if (LogOk()) {
        uhc::Log(L"researchGrants: unit %d (%hs) gets %d point(s) from a tech: %d/%d", id, ProtoName(pending.copy),
                 pending.points, points, cap);
      }
    }
  }
  g_pendingPoints.clear();
}

void Tick(char* world, std::int32_t) {
  if (world != MainWorld() || g_tags.empty()) {
    return;
  }
  if (g_checkTags) {
    CheckTags();
  }
  const std::uint32_t elapsed = Sync(world);
  if (!g_pendingPoints.empty()) {
    ApplyPendingPoints(world);
  }
  if (!g_timedChanged.empty()) {
    WriteTimedMarkers(world);
  }
  SweepSlice(world);
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  for (auto it = g_units.begin(); it != g_units.end();) {
    char* unit = UnitById(world, *it);
    const char* copy = unit != nullptr ? Field<const char*>(unit, 0x5C) : nullptr;
    const Tags* tags = TagsOf(copy);
    if (unit == nullptr || tags == nullptr || !IsAlive(unit)) {
      if (LogOk()) {
        uhc::Log(L"researchGrants: unit %d is gone or no longer has grants (game time %u ms)", *it, now);
      }
      it = g_units.erase(it);
      continue;
    }
    if (!kIsBuilt(unit)) {
      ++it;
      continue;
    }
    char* marker = TakeGrantMarker(unit);
    if (marker == nullptr) {
      ++it;
      continue;
    }
    const std::int32_t cap = Cap(copy, *tags);
    const std::uint32_t interval = IntervalMs(copy, *tags);
    std::int32_t points = static_cast<std::int32_t>(uhc::markers::Word(marker, 1));
    std::uint32_t progress = uhc::markers::Word(marker, 2);
    if (points >= cap) {
      points = cap;
      progress = 0;
    } else {
      progress += elapsed;
      while (progress >= interval && points < cap) {
        progress -= interval;
        ++points;
        if (LogOk()) {
          uhc::Log(L"researchGrants: unit %d (%hs) has %d/%d point(s) (game time %u ms)", *it, ProtoName(copy), points,
                   cap, now);
        }
      }
      if (points >= cap) {
        progress = 0;
      }
    }
    uhc::markers::Word(marker, 1) = static_cast<std::uint32_t>(points);
    uhc::markers::Word(marker, 2) = progress;
    ++it;
  }
}

// --- Spending -------------------------------------------------------------------------------------------------

float TotalCost(const char* cost) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* database = game != nullptr ? Field<const char*>(game, 0x140) : nullptr;
  const std::int32_t count = database != nullptr ? Field<std::int32_t>(database, 0x80) : 0;
  float total = 0.0f;
  for (std::int32_t r = 0; r < count; ++r) {
    total += kResGet(cost, r);
  }
  return total;
}

bool CanPay(const char* world, const char* player, const char* cost) {
  return Field<std::uint8_t>(world, 0x6912) != 0 ? kSharedAfford(player, cost) : kAfford(player, cost);
}

struct Choice {
  std::int32_t unit = -1;  // the unit that would pay a point
  const Tags* tags = nullptr;
};
Choice g_preview;  // the last choice a preview found (display only)

// The rule of a point, for the payment and for the display alike: the paying player's candidates, in scope, and
// the one with most points (the lowest unit ID on a tie, as g_units is in ID order). Reads only.
Choice Choose(const char* world, const char* player, const char* researcher, const char* cost) {
  const std::int32_t playerId = Field<std::int32_t>(player, 0);
  const float total = TotalCost(cost);
  int canPay = -1;  // asked once, when a candidate needs it
  std::int32_t best = -1;
  std::int32_t bestPoints = 0;
  const Tags* bestTags = nullptr;
  for (const std::int32_t id : g_units) {
    const char* unit = UnitById(world, id);
    const char* owner = unit != nullptr ? Field<const char*>(unit, 0x44) : nullptr;
    if (owner == nullptr || Field<std::int32_t>(owner, 0) != playerId) {
      continue;
    }
    const Tags* tags = TagsOf(Field<const char*>(unit, 0x5C));
    if (tags == nullptr || (tags->self && unit != researcher) || !IsAlive(unit) || !kIsBuilt(unit)) {
      continue;
    }
    const std::int32_t points = PointsOf(unit);
    if (points < 1 || points <= bestPoints || (!(total > 0.0f) && tags->time == 1.0f)) {
      continue;
    }
    if (!(total >= tags->minCost)) {
      if (canPay < 0) {
        canPay = CanPay(world, player, cost) ? 1 : 0;
      }
      if (canPay == 1) {
        continue;
      }
    }
    best = id;
    bestPoints = points;
    bestTags = tags;
  }
  return Choice{bestTags != nullptr ? best : -1, bestTags};
}

bool ClaimGrant(const char* researcher, const char* player, const char* cost, float* share, bool preview) {
  if (!preview) {
    g_claim = Claim{};
  }
  const char* world = MainWorld();
  if (world == nullptr || g_tags.empty() || player == nullptr) {
    return false;
  }
  if (world != g_world) {
    if (preview) {
      return false;  // the first tick of this game has not run: the payment would rebuild the tables first
    }
    Sync(world);  // a research paid before the first tick of a loaded game
  }
  const Choice choice = Choose(world, player, researcher, cost);
  if (choice.tags == nullptr) {
    return false;
  }
  if (preview) {
    g_preview = choice;
  } else {
    g_claim.unit = choice.unit;
    g_claim.time = choice.tags->time;
    g_claim.cost = choice.tags->cost;
  }
  *share = choice.tags->cost;
  return true;
}

// --- What the local player sees ------------------------------------------------------------------------------

// "Free research", "Grant -50%" or "Research grant", and ", ×2 time" when the Time factor is not 1.
std::wstring Label(float cost, float time) {
  wchar_t text[64];
  if (cost <= 0.0f) {
    swprintf_s(text, L"Free research");
  } else if (cost < 1.0f) {
    swprintf_s(text, L"Grant -%d%%", static_cast<int>(std::lround((1.0f - cost) * 100.0f)));
  } else {
    swprintf_s(text, L"Research grant");
  }
  std::wstring label = text;
  if (time != 1.0f) {
    swprintf_s(text, L", ×%g time", static_cast<double>(time));
    label += text;
  }
  return label;
}

// The floating text over the building that paid a point, for its owner only (floatingtext.h).
void ShowGrantText(const char* unit, float cost, float time) {
  const char* owner = Field<const char*>(unit, 0x44);
  if (owner == nullptr || Field<std::int32_t>(owner, 0) != uhc::LocalPlayer() || !uhc::CanShowUnitText(unit)) {
    return;
  }
  const std::wstring label = g_customText.empty() ? Label(cost, time) : g_customText;
  const std::int32_t shown = uhc::ShowUnitText(unit, label.c_str(), g_textStringId, kTextColour, kTextLife);
  if (LogOk()) {
    uhc::Log(L"researchGrants: \"%ls\" shown over unit %d%ls", g_textStringId >= 0 ? L"(string)" : label.c_str(),
             Field<std::int32_t>(unit, 0x10), shown < 0 ? L": refused by the engine" : L"");
  }
}

struct Preview {
  const char* key = nullptr;  // the key whose claim it would be; nullptr: the full price
  float share = 1.0f;
  Choice grant;               // when it is this key's: the unit and its tags
};

// The payment the research of this tech entry ([entry+10h] its cost, as the payment reads it) would get now:
// the same question as the payment's, asked of every key in the same order (researchpay.h).
Preview PreviewOf(const char* entry, const char* player, const char* unit) {
  Preview preview;
  if (!g_price || entry == nullptr || player == nullptr || g_tags.empty()) {
    return preview;
  }
  g_preview = Choice{};
  preview.key = uhc::PreviewResearchPay(unit, player, entry + 0x10, &preview.share);
  if (preview.key != nullptr && std::strcmp(preview.key, "researchGrants") == 0) {
    preview.grant = g_preview;
  }
  return preview;
}

std::int32_t TechIdOf(const char* entry) {
  const char* node = Field<const char*>(entry, 0);
  return node != nullptr ? Field<std::int32_t>(node, 0) : -1;
}

// A ResList laid out as the game's (researchpay.cpp): +0 the encoded entries, +4 the encoded total.
struct ResList {
  std::uint32_t* entries;
  std::uint32_t total;
};

// The button's text: the free word, or the price after the share when it is one resource, else the discount.
void ButtonText(const char* cost, float share, char* out, std::size_t size) {
  if (share <= 0.0f) {
    strncpy_s(out, size, g_freeWord.c_str(), _TRUNCATE);
    return;
  }
  const auto* list = reinterpret_cast<const ResList*>(cost);
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(kResListCount);
  std::int32_t paid = 0;
  float amount = 0.0f;
  if (list != nullptr && list->entries != nullptr && count > 0) {
    std::vector<std::uint32_t> entries(list->entries, list->entries + count);
    ResList scaled{entries.data(), list->total};
    kCostScale(&scaled, share);
    for (std::int32_t r = 0; r < count; ++r) {
      const float value = kResGet(&scaled, r);
      if (value > 0.0f) {
        ++paid;
        amount = value;
      }
    }
  }
  if (paid == 1) {
    _snprintf_s(out, size, _TRUNCATE, "%d", static_cast<int>(std::lround(amount)));
  } else {
    _snprintf_s(out, size, _TRUNCATE, "-%d%%", static_cast<int>(std::lround((1.0f - share) * 100.0f)));
  }
}

std::map<std::int32_t, std::int32_t> g_shownPrice;  // tech ID -> share in % last logged; display only

void LogShown(std::int32_t tech, float share, const char* overlay) {
  if (!g_log) {
    return;
  }
  const std::int32_t percent = static_cast<std::int32_t>(std::lround(share * 100.0f));
  const auto [it, added] = g_shownPrice.try_emplace(tech, percent);
  if ((!added && it->second == percent) || !LogOk()) {
    return;
  }
  it->second = percent;
  uhc::Log(L"researchGrants: the button of tech %d shows %hs (cost x%.2f)", tech,
           percent >= 100 ? "the full price" : overlay, static_cast<double>(share));
}

// text=: "Grant_used" (at most 127 characters; UTF-8, else ANSI; '_' for a space) or "90001" (a string table ID).
bool ParseText(const std::string& text) {
  if (text.empty()) {
    return false;
  }
  if (text.find_first_not_of("0123456789") == std::string::npos) {
    return text.size() <= 9 && (g_textStringId = std::atoi(text.c_str())) >= 0;
  }
  wchar_t wide[128];  // with its terminator
  int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.c_str(), -1, wide, 128);
  if (length == 0) {
    length = MultiByteToWideChar(CP_ACP, 0, text.c_str(), -1, wide, 128);
  }
  if (length == 0) {
    return false;
  }
  std::replace(wide, wide + length, L'_', L' ');
  g_customText = wide;
  return true;
}

void GrantStarted(char* action, float share, bool claimed) {
  const char* world = MainWorld();
  const char* researcher = Field<const char*>(action, 0x10);
  if (world == nullptr || researcher == nullptr) {
    return;
  }
  const std::int32_t researcherId = Field<std::int32_t>(researcher, 0x10);
  const std::int32_t tech = Field<std::int32_t>(action, 0x68);
  if (!claimed) {
    SetTimed(researcherId, tech, 1.0f);  // the same tech again in this unit, without a point
    return;
  }
  const Claim claim = g_claim;
  g_claim = Claim{};
  char* unit = UnitById(world, claim.unit);
  char* marker = unit != nullptr ? GrantMarker(unit) : nullptr;
  std::int32_t points = 0;
  if (marker != nullptr) {
    points = static_cast<std::int32_t>(uhc::markers::Word(marker, 1)) - 1;
    uhc::markers::Word(marker, 1) = static_cast<std::uint32_t>(points < 0 ? 0 : points);
  }
  SetTimed(researcherId, tech, claim.time);
  if (g_text && unit != nullptr) {
    ShowGrantText(unit, claim.cost, claim.time);
  }
  if (LogOk()) {
    uhc::Log(L"researchGrants: unit %d spends a point on tech %d in unit %d: cost x%.2f, time x%.2f, %d left (game "
             L"time %u ms)",
             claim.unit, tech, researcherId, static_cast<double>(share), static_cast<double>(claim.time), points,
             Field<std::uint32_t>(world, 0x108));
  }
}

bool __stdcall GrantRow(const char* panel, const char* unit) {
  const char* copy = Field<const char*>(unit, 0x5C);
  const Tags* tags = TagsOf(copy);
  if (tags == nullptr) {
    return false;
  }
  const std::int32_t cap = Cap(copy, *tags);
  const std::uint32_t interval = IntervalMs(copy, *tags);
  const char* marker = GrantMarker(unit);
  const std::int32_t points = marker != nullptr ? static_cast<std::int32_t>(uhc::markers::Word(const_cast<char*>(marker), 1)) : 0;
  const std::uint32_t progress = marker != nullptr ? uhc::markers::Word(const_cast<char*>(marker), 2) : 0;
  wchar_t value[64];
  if (!kIsBuilt(unit)) {
    swprintf_s(value, L"%d/%d once built", points, cap);
  } else if (points >= cap) {
    swprintf_s(value, L"%d/%d (full)", points, cap);
  } else {
    const std::uint32_t left = progress < interval ? interval - progress : 0;
    swprintf_s(value, L"%d/%d, next in %u s", points, cap, (left + 999) / 1000);
  }
  return uhc::SetUnitPanelRow(panel, L"Research grants", value);
}

}  // namespace

// From the hook of the copy of a tech's cost into its rollover (0x4C73FD in the builder 0x4C737C): the cost the
// rollover shows. A copy of the tech entry's own cost gets the share the payment would take now.
extern "C" void* __stdcall UhcGrantTipCost(void* list, const void* from, const char* entry, const char* player,
                                           const char* unit) {
  void* result = kCostCopy(list, from);
  if (entry == nullptr || from != entry + 0x10) {
    return result;  // a cost the caller gave
  }
  const Preview preview = PreviewOf(entry, player, unit);
  if (preview.key == nullptr || preview.share >= 1.0f) {
    return result;
  }
  if (preview.share <= 0.0f) {
    kCostFill(list, 0.0f);
  } else {
    kCostScale(list, preview.share);
  }
  return result;
}

// From the hook of the panel's call of that builder for a tech button (0x4622C5), once the rollover is built:
// the button's overlay text (the panel's buffer, 256 chars, empty for a tech) and a line in the rollover.
extern "C" void __stdcall UhcGrantTechButton(const char* entry, const char* player, const char* unit, void* rollover,
                                             char* overlay) {
  const Preview preview = PreviewOf(entry, player, unit);
  if (preview.key == nullptr || (preview.share >= 1.0f && preview.grant.tags == nullptr)) {
    if (g_log && entry != nullptr && g_shownPrice.count(TechIdOf(entry)) != 0) {
      LogShown(TechIdOf(entry), 1.0f, "");
    }
    return;
  }
  if (preview.share < 1.0f && overlay != nullptr && overlay[0] == '\0') {
    ButtonText(entry + 0x10, preview.share, overlay, 256);
  }
  const Tags* tags = preview.grant.tags;
  const std::wstring line = L"\n<color=0.4, 1, 0.4>" +
                            (tags != nullptr ? Label(tags->cost, tags->time) : Label(preview.share, 1.0f)) +
                            L"</color>";
  if (rollover != nullptr && *static_cast<void**>(rollover) != nullptr) {
    kAppend(rollover, line.c_str(), -1, -1);
  }
  LogShown(TechIdOf(entry), preview.share, overlay != nullptr ? overlay : "");
}

// From the step hooks, while a research with a Time factor is in progress: the step of `action`, which adds to
// [action+offset]; `entry` is its tech's status entry ([entry+18h] the research points).
extern "C" float __stdcall UhcGrantResearchStep(const char* action, std::uint32_t offset, const char* entry, float step) {
  const char* unit = Field<const char*>(action, 0x10);
  if (unit == nullptr) {
    return step;
  }
  const auto key = std::make_pair(Field<std::int32_t>(unit, 0x10), Field<std::int32_t>(action, 0x68));
  const auto found = g_timed.find(key);
  if (found == g_timed.end()) {
    return step;
  }
  step /= found->second;
  if (entry != nullptr && Field<float>(action, offset) + step >= Field<float>(entry, 0x18)) {
    const char* world = MainWorld();
    if (LogOk()) {
      uhc::Log(L"researchGrants: tech %d in unit %d is done (game time %u ms)", key.second, key.first,
               world != nullptr ? Field<std::uint32_t>(world, 0x108) : 0u);
    }
    SetTimed(key.first, key.second, 1.0f);
  }
  return step;
}

namespace uhc {

Outcome ApplyResearchGrants(const Config& config) {
  const Config::Args* args = config.First("researchGrants");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    const char* text = arg.c_str();
    if (_stricmp(text, "log") == 0) {
      g_log = true;
    } else if (_stricmp(text, "notext") == 0) {
      g_text = false;
    } else if (_stricmp(text, "noprice") == 0) {
      g_price = false;
    } else if (_strnicmp(text, "text=", 5) == 0) {
      if (!ParseText(arg.substr(5))) {
        Log(L"researchGrants: %hs: expected text=<text> (at most 127 characters, '_' for a space) or "
            L"text=<string table ID>; feature not applied",
            text);
        return Outcome::kFailed;
      }
    } else if (_strnicmp(text, "free=", 5) == 0) {
      if (arg.size() == 5 || arg.size() > 5 + 31) {
        Log(L"researchGrants: %hs: expected free=<text> (1 to 31 characters, '_' for a space); feature not applied",
            text);
        return Outcome::kFailed;
      }
      g_freeWord = arg.substr(5);
      std::replace(g_freeWord.begin(), g_freeWord.end(), '_', ' ');
    } else {
      Log(L"researchGrants: unknown option %hs (expected: [notext | text=<text>] [noprice] [free=<text>] [log]); "
          L"feature not applied",
          text);
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("researchGrants",
                 {&sites::kResearchProgressAdd, &sites::kCommandResearchProgressAdd, &sites::kPayAffordCheck,
                  &sites::kPaySharedAffordCheck, &sites::kResListGet, &sites::kIsBuilt, &sites::kUnitAliveSlot}) ||
      (g_text && !VerifyFloatingText("researchGrants")) ||
      (g_price && !VerifyAll("researchGrants price",
                             {&sites::kTechButtonRollover, &sites::kButtonOverlayReset, &sites::kButtonOverlayRead,
                              &sites::kTechRolloverHead, &sites::kTechTipCostCopy, &sites::kBStringAppend,
                              &sites::kResListCopy, &sites::kResListScale, &sites::kResListFill})) ||
      !AddResearchPayer("researchGrants", &ClaimGrant, &GrantStarted) ||
      !AddProtoTagHandler("ResearchGrantInterval", &ReadInterval) || !AddProtoTagHandler("ResearchGrantMax", &ReadMax) ||
      !AddProtoTagHandler("ResearchGrantCost", &ReadCost) || !AddProtoTagHandler("ResearchGrantTime", &ReadTime) ||
      !AddProtoTagHandler("ResearchGrantScope", &ReadScope) ||
      !AddProtoTagHandler("ResearchGrantMinCost", &ReadMinCost) ||
      !AddTechSubtype("ResearchGrantInterval", &ChangeInterval) || !AddTechSubtype("ResearchGrantMax", &ChangeMax) ||
      !AddTechSubtype("ResearchGrantPoints", &GivePoints) || !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !AddWorldTick(&Tick) ||
      !WriteJmp(sites::kResearchProgressAdd.va, reinterpret_cast<const void*>(&UhcGrantResearchStepHook), 6) ||
      !WriteJmp(sites::kCommandResearchProgressAdd.va, reinterpret_cast<const void*>(&UhcGrantCommandStepHook), 6) ||
      (g_price &&
       (!WriteCall(sites::kTechButtonRollover.va + 0x10, reinterpret_cast<const void*>(&UhcGrantTechButtonHook)) ||
        !WriteCall(sites::kTechTipCostCopy.va + 4, reinterpret_cast<const void*>(&UhcGrantTipCostHook))))) {
    return Outcome::kFailed;
  }
  if (!AddUnitPanelRow(&GrantRow)) {
    Log(L"researchGrants: no grant row in the unit panel");
  }
  Log(L"researchGrants: the proto tags ResearchGrant* and the Data subtypes ResearchGrantInterval, ResearchGrantMax "
      L"and ResearchGrantPoints are on%ls%ls%ls (multiplayer unverified)",
      g_price ? L"; the tech buttons show the price with a point" : L"",
      g_text ? L"; a floating text over the building that pays a point" : L"", g_log ? L"; logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
