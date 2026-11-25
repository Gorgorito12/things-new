// nurseryFactor [log]: a whole number per building or unit (a "factor", e.g. the minks of a mink nursery) that grows
// with game time up to a cap, is changed by techs, multiplies the unit's AutoGather rate, can multiply a home city
// shipment, and shows in the unit panel as current/max with a two-line rollover.
//
//   <NurseryFactorMax>10</NurseryFactorMax>              the cap, a whole number 0..100000; required: it marks the proto
//   <NurseryFactorInitial>0</NurseryFactorInitial>       the value of a new unit (default 0)
//   <NurseryFactorInterval>30</NurseryFactorInterval>    game seconds per growth step (default 0: no growth with time)
//   <NurseryFactorStep>1</NurseryFactorStep>             the size of a step (default 1)
//   <NurseryFactorGrowth>linear</NurseryFactorGrowth>    linear (default) or exponential
//   <NurseryFactorGrowthRate>0.25</NurseryFactorGrowthRate>  exponential: a step adds max(step, floor(factor x rate))
//   <NurseryFactorTrickle>1</NurseryFactorTrickle>       1 (default): the factor multiplies the unit's AutoGather rate
//   <NurseryFactorName>minks</NurseryFactorName>         string table ID or text (default "")
//   <NurseryFactorRolloverCount>...</...>                string ID or text, default "{current} out of {max} {name}."
//   <NurseryFactorRolloverRate>...</...>                 string ID or text, default "Produces {step} {name} every
//                                                        {seconds} seconds."; placeholders {current} {max} {name}
//                                                        {seconds} {step}
//
// The tags are read once per data load, by proto ID, the same for every player. Data subtypes on a ProtoUnit target
// change one player's copy of the proto: NurseryFactorMax, NurseryFactorInterval and NurseryFactorStep through the
// stock value function 0x7F892A (base: the tags); NurseryFactor changes the factor of each of the player's built units
// of that proto (Absolute adds, Assign sets; every relativity through the same function, the unit's factor as the
// value and the initial value as the base), once, at the next world tick. The Player subtype
// FreeHomeCityUnitByNurseryFactor (unittype = the proto shipped, nursery = a proto or abstract type, consume = all | N |
// none) becomes the stock FreeHomeCityUnit (37h) with amount x the factors it takes from the player's built units of
// that type: consume="all" takes each whole factor, consume="N" at most N from each, none (the default) counts them and
// takes nothing.
//
// The trickle: the AutoGather rate getter 0x49EBE4 is a shared hook (autogatherrate.h); this key's filter multiplies
// the rate of a unit of a tagged proto by its factor. The AutoGather update then pays the owner (or, with the stock
// tactics tag AddResourcesToInventory, adds to the unit's own inventory), and the panels show the multiplied rate.
//
// The factors: a table by unit ID (in ID order), filled by a sweep of the world's unit table (256 slots per world
// update; the whole table when a game starts or loads). After each world update (worldtick.h) each living, built unit
// adds the game time [world+108h] that passed to its timer and grows a step per interval, up to the player's cap; at
// the cap the timer waits at 0; a lowered cap cuts the factor at once. The factor and the timer are a saved marker on
// the unit (savedmarkers.h, stat 6Bh), written each tick, so a save keeps them and the unit's death loses them; a
// transform in place (which ends the markers) keeps the table's value when the new proto is tagged too, cut to its cap.
//
// Display only: the unit panel row (unitpanel.h, the minimized interface) "<Name> 3/10" with the rollover as its
// help text, and the data ref {uhcNurseryFactor} (the first selected unit's "3/10 minks").
#include <windows.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <cwctype>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>

#include "../autogatherrate.h"
#include "../datarefs.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../savedmarkers.h"
#include "../techsubtypes.h"
#include "../unitpanel.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::int32_t kStat = 0x6B;               // savedmarkers.h: no other key uses it
constexpr std::uint32_t kWord = 0x4E525346;        // word 0 of a unit's marker: 'NRSF'
constexpr std::int32_t kSweepSlots = 256;
constexpr std::int32_t kFreeHomeCityUnit = 0x37;
constexpr std::int32_t kMaxValue = 100000;
constexpr int kMaxLogLines = 400;
constexpr std::size_t kTypeNames = 0x190;       // in the database: the unit type name table
constexpr std::size_t kFirstAbstract = 0x19B0;  // in the database: the first abstract type's ID

using IsBuiltFn = bool(__thiscall*)(const char* unit);
using IsAliveFn = bool(__thiscall*)(const char* unit);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
using NameBucketFn = std::int32_t(__thiscall*)(const void* table, const char* name);
using NameFindFn = bool(__thiscall*)(const void* table, const char* name, std::int32_t bucket, std::int32_t* id);
using SelectionFn = const char*(__cdecl*)();
const auto kIsBuilt = reinterpret_cast<IsBuiltFn>(0x0044DDB4);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
const auto kSelection = reinterpret_cast<SelectionFn>(0x00453B28);

struct BString {
  wchar_t* text;
};
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t id);
using BStringFreeFn = void(__thiscall*)(BString* self);
using BStringAssignFn = void(__thiscall*)(wchar_t** self, const BString* source, std::int32_t, std::int32_t);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kBStringAssign = reinterpret_cast<BStringAssignFn>(0x00443BB8);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// A text of the data: a string table ID, or the text itself.
struct Text {
  std::int32_t id = -1;
  std::wstring text;
};

struct Tags {
  bool marked = false;  // <NurseryFactorMax> was read
  float max = 0.0f;
  float initial = 0.0f;
  float interval = 0.0f;  // seconds; 0: no growth with time
  float step = 1.0f;
  bool exponential = false;
  float rate = 0.25f;
  bool trickle = true;
  Text name;
  Text countLine;
  Text rateLine;
};
std::map<std::int32_t, Tags> g_tags;  // by proto ID; the data load fills it
std::vector<std::uint8_t> g_marked;   // by proto ID: 1 for a marked proto that trickles (the rate filter's test)

struct TechValues {
  std::int32_t id;  // the proto ID the copy had: a reused pointer with another ID is ignored
  float max;
  float interval;
  float step;
};
std::unordered_map<const char*, TechValues> g_tech;  // by the player's copy of the proto; lookups only

struct State {
  std::int32_t factor = 0;
  std::uint32_t progress = 0;  // ms of game time towards the next step
};
std::map<std::int32_t, State> g_units;  // by unit ID, in ID order: the same walk on every machine

struct PendingFactor {
  const char* copy;
  std::int32_t id;
  float amount;
  std::uint8_t relativity;
};
std::vector<PendingFactor> g_pending;  // NurseryFactor effects, for the next world tick

struct Shipment {
  std::int32_t shipped;  // the proto FreeHomeCityUnit ships
  std::int32_t nursery;  // a proto or abstract type ID
  std::int32_t consume;  // -1 all, 0 none, N: at most N per unit
};
std::vector<Shipment> g_shipments;  // the effects' field +10h is an index; the techtree read fills it

const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
std::int32_t g_cursor = 0;

bool g_log = false;
int g_logLines = 0;

bool LogOk() {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return false;
  }
  ++g_logLines;
  return true;
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* MainWorld() {
  const char* game = Game();
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

std::int32_t PlayerIdOf(const char* unit) {
  const char* player = Field<const char*>(unit, 0x44);
  return player == nullptr ? -1 : Field<std::int32_t>(player, 0);
}

const Tags* TagsOf(const char* proto) {
  if (proto == nullptr || g_tags.empty()) {
    return nullptr;
  }
  const auto found = g_tags.find(ProtoId(proto));
  return found != g_tags.end() && found->second.marked ? &found->second : nullptr;
}

const TechValues* TechOf(const char* copy) {
  if (g_tech.empty()) {
    return nullptr;
  }
  const auto found = g_tech.find(copy);
  return found != g_tech.end() && found->second.id == ProtoId(copy) ? &found->second : nullptr;
}

std::int32_t Whole(float value) {
  if (!(value > 0.0f)) {
    return 0;
  }
  return value >= static_cast<float>(kMaxValue) ? kMaxValue : static_cast<std::int32_t>(std::floor(value + 1e-4f));
}

// The player's values: the tags, as the techs left them.
std::int32_t Cap(const char* copy, const Tags& tags) {
  const TechValues* tech = TechOf(copy);
  return Whole(tech != nullptr ? tech->max : tags.max);
}

std::uint32_t IntervalMs(const char* copy, const Tags& tags) {
  const TechValues* tech = TechOf(copy);
  const float seconds = tech != nullptr ? tech->interval : tags.interval;
  if (!(seconds > 0.0f)) {
    return 0;  // no growth with time
  }
  return seconds < 0.1f ? 100u : static_cast<std::uint32_t>(std::lround(seconds * 1000.0f));
}

std::int32_t StepOf(const char* copy, const Tags& tags) {
  const TechValues* tech = TechOf(copy);
  const std::int32_t step = Whole(tech != nullptr ? tech->step : tags.step);
  return step < 1 ? 1 : step;
}

std::int32_t Grow(std::int32_t factor, std::int32_t step, const Tags& tags) {
  if (!tags.exponential) {
    return factor + step;
  }
  const std::int32_t share = Whole(static_cast<float>(factor) * tags.rate);
  return factor + (share > step ? share : step);
}

// --- Tags -----------------------------------------------------------------------------------------------------

const wchar_t* NodeText(const char* node) { return *reinterpret_cast<const wchar_t* const*>(node + 0x14); }

bool ReadNumber(const char* node, char* proto, const wchar_t* tag, float low, float high, float* out) {
  const wchar_t* text = NodeText(node);
  wchar_t* end = nullptr;
  const double value = text != nullptr ? std::wcstod(text, &end) : 0.0;
  if (text == nullptr || end == text || !(value >= low) || !(value <= high)) {
    uhc::Log(L"nurseryFactor: proto %d (%hs): <%ls> needs a number from %g to %g, not \"%ls\"; ignored",
             ProtoId(proto), ProtoName(proto), tag, static_cast<double>(low), static_cast<double>(high),
             text != nullptr ? text : L"");
    return false;
  }
  *out = static_cast<float>(value);
  if (g_log) {
    uhc::Log(L"nurseryFactor: proto %d (%hs): %ls %g", ProtoId(proto), ProtoName(proto), tag, value);
  }
  return true;
}

void ReadText(const char* node, char* proto, const wchar_t* tag, Text* out) {
  const wchar_t* text = NodeText(node);
  out->id = -1;
  out->text.clear();
  if (text == nullptr) {
    return;
  }
  wchar_t* end = nullptr;
  const long id = std::wcstol(text, &end, 10);
  if (end != text && *end == L'\0' && id >= 0) {
    out->id = static_cast<std::int32_t>(id);
  } else {
    out->text = text;
  }
  if (g_log) {
    uhc::Log(L"nurseryFactor: proto %d (%hs): %ls \"%ls\"", ProtoId(proto), ProtoName(proto), tag, text);
  }
}

void Remark(std::int32_t id) {
  const auto found = g_tags.find(id);
  const bool on = found != g_tags.end() && found->second.marked && found->second.trickle;
  if (id < 0 || id > 0xFFFFF) {
    return;
  }
  if (static_cast<std::size_t>(id) >= g_marked.size()) {
    g_marked.resize(static_cast<std::size_t>(id) + 1, 0);
  }
  g_marked[static_cast<std::size_t>(id)] = on ? 1 : 0;
}

bool __cdecl ReadMax(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"NurseryFactorMax", 0.0f, static_cast<float>(kMaxValue), &value)) {
    Tags& tags = g_tags[ProtoId(proto)];
    tags.max = std::floor(value);
    tags.marked = true;
    Remark(ProtoId(proto));
  }
  return true;
}

bool __cdecl ReadInitial(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"NurseryFactorInitial", 0.0f, static_cast<float>(kMaxValue), &value)) {
    g_tags[ProtoId(proto)].initial = std::floor(value);
  }
  return true;
}

bool __cdecl ReadInterval(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"NurseryFactorInterval", 0.0f, 36000.0f, &value)) {
    g_tags[ProtoId(proto)].interval = value;
  }
  return true;
}

bool __cdecl ReadStep(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"NurseryFactorStep", 1.0f, static_cast<float>(kMaxValue), &value)) {
    g_tags[ProtoId(proto)].step = std::floor(value);
  }
  return true;
}

bool __cdecl ReadGrowthRate(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"NurseryFactorGrowthRate", 0.0f, 100.0f, &value)) {
    g_tags[ProtoId(proto)].rate = value;
  }
  return true;
}

bool __cdecl ReadGrowth(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  if (text != nullptr && (_wcsicmp(text, L"linear") == 0 || _wcsicmp(text, L"exponential") == 0)) {
    g_tags[ProtoId(proto)].exponential = _wcsicmp(text, L"exponential") == 0;
    if (g_log) {
      uhc::Log(L"nurseryFactor: proto %d (%hs): NurseryFactorGrowth %ls", ProtoId(proto), ProtoName(proto), text);
    }
  } else {
    uhc::Log(L"nurseryFactor: proto %d (%hs): <NurseryFactorGrowth> is linear or exponential, not \"%ls\"; ignored",
             ProtoId(proto), ProtoName(proto), text != nullptr ? text : L"");
  }
  return true;
}

bool __cdecl ReadTrickle(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"NurseryFactorTrickle", 0.0f, 1.0f, &value)) {
    g_tags[ProtoId(proto)].trickle = value >= 0.5f;
    Remark(ProtoId(proto));
  }
  return true;
}

bool __cdecl ReadName(void*, const char* node, char* proto) {
  ReadText(node, proto, L"NurseryFactorName", &g_tags[ProtoId(proto)].name);
  return true;
}

bool __cdecl ReadCountLine(void*, const char* node, char* proto) {
  ReadText(node, proto, L"NurseryFactorRolloverCount", &g_tags[ProtoId(proto)].countLine);
  return true;
}

bool __cdecl ReadRateLine(void*, const char* node, char* proto) {
  ReadText(node, proto, L"NurseryFactorRolloverRate", &g_tags[ProtoId(proto)].rateLine);
  return true;
}

void ForgetOnDataLoad(char*) {
  g_tags.clear();
  g_marked.clear();
  g_tech.clear();
  g_pending.clear();
  g_units.clear();
  g_shipments.clear();
  g_world = nullptr;
  g_cursor = 0;
}

// --- Tech subtypes --------------------------------------------------------------------------------------------

TechValues* TechSlot(char* copy, const char* base) {
  const auto tag = g_tags.find(ProtoId(base));
  if (tag == g_tags.end() || !tag->second.marked) {
    return nullptr;
  }
  const TechValues fresh{ProtoId(copy), tag->second.max, tag->second.interval, tag->second.step};
  auto inserted = g_tech.emplace(copy, fresh);
  if (inserted.first->second.id != ProtoId(copy)) {
    inserted.first->second = fresh;
  }
  return &inserted.first->second;
}

enum class Value { kMax, kInterval, kStep };

void ChangeValue(char* copy, const char* base, float amount, std::uint8_t relativity, bool unapply, Value which) {
  static const wchar_t* const kNames[] = {L"NurseryFactorMax", L"NurseryFactorInterval", L"NurseryFactorStep"};
  const wchar_t* name = kNames[static_cast<int>(which)];
  TechValues* slot = TechSlot(copy, base);
  if (slot == nullptr) {
    uhc::Log(L"nurseryFactor: tech subtype %ls on proto %d (%hs), which has no <NurseryFactorMax>; ignored", name,
             ProtoId(copy), ProtoName(copy));
    return;
  }
  const Tags& tags = g_tags[ProtoId(base)];
  float* field = which == Value::kMax ? &slot->max : which == Value::kInterval ? &slot->interval : &slot->step;
  const float from = which == Value::kMax ? tags.max : which == Value::kInterval ? tags.interval : tags.step;
  const float before = *field;
  kEffectValue(relativity, field, from, amount, unapply);
  if (*field < 0.0f) {
    *field = 0.0f;  // never negative; the readers floor the step at 1
  }
  if (LogOk()) {
    uhc::Log(L"nurseryFactor: proto %d (%hs), player's copy %p, tech subtype %ls, relativity %u, amount %g%ls: %g -> %g",
             ProtoId(copy), ProtoName(copy), static_cast<const void*>(copy), name, relativity,
             static_cast<double>(amount), unapply ? L" (removed)" : L"", static_cast<double>(before),
             static_cast<double>(*field));
  }
}

void ChangeMax(char* copy, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  ChangeValue(copy, base, amount, relativity, unapply, Value::kMax);
}

void ChangeInterval(char* copy, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  ChangeValue(copy, base, amount, relativity, unapply, Value::kInterval);
}

void ChangeStep(char* copy, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  ChangeValue(copy, base, amount, relativity, unapply, Value::kStep);
}

void ChangeFactor(char* copy, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  if (unapply) {
    return;  // a change made is kept
  }
  const auto tag = g_tags.find(ProtoId(base));
  if (tag == g_tags.end() || !tag->second.marked) {
    uhc::Log(L"nurseryFactor: tech subtype NurseryFactor on proto %d (%hs), which has no <NurseryFactorMax>; ignored",
             ProtoId(copy), ProtoName(copy));
    return;
  }
  g_pending.push_back({copy, ProtoId(copy), amount, relativity});
  if (LogOk()) {
    uhc::Log(L"nurseryFactor: proto %d (%hs), tech subtype NurseryFactor, relativity %u, amount %g: queued for the next "
             L"world tick",
             ProtoId(copy), ProtoName(copy), relativity, static_cast<double>(amount));
  }
}

// --- The units ------------------------------------------------------------------------------------------------

char* MarkerOf(const char* unit) { return uhc::markers::Find(unit, kStat, kWord); }

void Consider(const char* unit, bool fromMarkers) {
  if (unit == nullptr) {
    return;
  }
  const char* copy = Field<const char*>(unit, 0x5C);
  const Tags* tags = TagsOf(copy);
  if (tags == nullptr || !IsAlive(unit)) {
    return;
  }
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (g_units.count(id) != 0) {
    return;
  }
  State state;
  const char* marker = fromMarkers ? MarkerOf(unit) : nullptr;
  if (marker != nullptr) {
    state.factor = static_cast<std::int32_t>(uhc::markers::Word(const_cast<char*>(marker), 1));
    state.progress = uhc::markers::Word(const_cast<char*>(marker), 2);
  } else {
    state.factor = Whole(tags->initial);
  }
  const std::int32_t cap = Cap(copy, *tags);
  state.factor = std::clamp(state.factor, 0, cap);
  g_units.emplace(id, state);
}

void SweepAll(const char* world, bool fromMarkers) {
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
    Consider(table[i], fromMarkers);
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
    Consider(table[g_cursor++], true);
  }
}

// A game that just started or loaded: its units and the factors their markers keep. One walk. NurseryFactor effects
// queued before the first tick of a loaded game (game time above 0) are dropped: a load must not apply them again.
void Rebuild(const char* world) {
  g_units.clear();
  g_cursor = 0;
  if (Field<std::uint32_t>(world, 0x108) > 0 && !g_pending.empty()) {
    if (LogOk()) {
      uhc::Log(L"nurseryFactor: a loaded game: %u NurseryFactor effect(s) queued during the load are not applied again",
               static_cast<unsigned>(g_pending.size()));
    }
    g_pending.clear();
  }
  SweepAll(world, true);
  if (!g_units.empty()) {
    std::int32_t total = 0;
    for (const auto& [id, state] : g_units) {
      total += state.factor;
    }
    uhc::Log(L"nurseryFactor: %u unit(s) with a factor in this game, %d in all (game time %u ms)",
             static_cast<unsigned>(g_units.size()), total, Field<std::uint32_t>(world, 0x108));
  }
}

// The game time since the last tick; a new game rebuilds the table and gives 0.
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

void ApplyPending(const char* world) {
  SweepAll(world, true);
  for (const PendingFactor& pending : g_pending) {
    for (auto& [id, state] : g_units) {
      char* unit = UnitById(world, id);
      if (unit == nullptr || Field<const char*>(unit, 0x5C) != pending.copy || ProtoId(pending.copy) != pending.id ||
          !kIsBuilt(unit)) {
        continue;
      }
      const Tags* tags = TagsOf(pending.copy);
      if (tags == nullptr) {
        continue;
      }
      float value = static_cast<float>(state.factor);
      kEffectValue(pending.relativity, &value, tags->initial, pending.amount, false);
      const std::int32_t before = state.factor;
      state.factor = std::clamp(static_cast<std::int32_t>(std::floor(value + 1e-4f)), 0, Cap(pending.copy, *tags));
      if (LogOk()) {
        uhc::Log(L"nurseryFactor: unit %d (%hs), NurseryFactor relativity %u amount %g: %d -> %d/%d", id,
                 ProtoName(pending.copy), pending.relativity, static_cast<double>(pending.amount), before,
                 state.factor, Cap(pending.copy, *tags));
      }
    }
  }
  g_pending.clear();
}

void WriteMarker(char* unit, const State& state) {
  char* marker = MarkerOf(unit);
  if (marker == nullptr) {
    marker = uhc::markers::Take(unit, kStat);
    if (marker == nullptr) {
      return;
    }
    uhc::markers::Word(marker, 0) = kWord;
  }
  uhc::markers::Word(marker, 1) = static_cast<std::uint32_t>(state.factor);
  uhc::markers::Word(marker, 2) = state.progress;
}

void Tick(char* world, std::int32_t) {
  if (world != MainWorld() || g_tags.empty()) {
    return;
  }
  const std::uint32_t elapsed = Sync(world);
  if (!g_pending.empty()) {
    ApplyPending(world);
  }
  SweepSlice(world);
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  for (auto it = g_units.begin(); it != g_units.end();) {
    char* unit = UnitById(world, it->first);
    const char* copy = unit != nullptr ? Field<const char*>(unit, 0x5C) : nullptr;
    const Tags* tags = TagsOf(copy);
    if (unit == nullptr || tags == nullptr || !IsAlive(unit)) {
      if (LogOk()) {
        uhc::Log(L"nurseryFactor: unit %d is gone or no longer has a factor (game time %u ms)", it->first, now);
      }
      it = g_units.erase(it);
      continue;
    }
    State& state = it->second;
    const std::int32_t cap = Cap(copy, *tags);
    if (state.factor > cap) {
      if (LogOk()) {
        uhc::Log(L"nurseryFactor: unit %d (%hs) is cut to its player's cap: %d -> %d", it->first, ProtoName(copy),
                 state.factor, cap);
      }
      state.factor = cap;
    }
    if (kIsBuilt(unit)) {
      const std::uint32_t interval = IntervalMs(copy, *tags);
      if (state.factor >= cap || interval == 0) {
        state.progress = 0;
      } else {
        state.progress += elapsed;
        const std::int32_t step = StepOf(copy, *tags);
        while (state.progress >= interval && state.factor < cap) {
          state.progress -= interval;
          state.factor = std::min(Grow(state.factor, step, *tags), cap);
          if (LogOk()) {
            uhc::Log(L"nurseryFactor: unit %d (%hs) of player %d grows to %d/%d (game time %u ms)", it->first,
                     ProtoName(copy), PlayerIdOf(unit), state.factor, cap, now);
          }
        }
        if (state.factor >= cap) {
          state.progress = 0;
        }
      }
    }
    WriteMarker(unit, state);
    ++it;
  }
}

// --- The trickle ----------------------------------------------------------------------------------------------

// The AutoGather rate getter's filter (autogatherrate.h): a unit of a marked proto that trickles multiplies its rate
// by its factor. Simulation state only; the table is written by the world tick.
bool NurseryRate(const char* unitAction, std::int32_t, float* factor) {
  if (g_marked.empty()) {
    return false;
  }
  const char* unit = Field<const char*>(unitAction, 0x10);
  const char* copy = unit != nullptr ? Field<const char*>(unit, 0x5C) : nullptr;
  if (copy == nullptr) {
    return false;
  }
  const std::int32_t protoId = ProtoId(copy);
  if (protoId < 0 || static_cast<std::size_t>(protoId) >= g_marked.size() ||
      g_marked[static_cast<std::size_t>(protoId)] == 0) {
    return false;
  }
  const char* world = MainWorld();
  if (world != nullptr && world != g_world) {
    Sync(world);  // the first update of a game, before its first tick: the factors its markers keep
  }
  const auto found = g_units.find(Field<std::int32_t>(unit, 0x10));
  std::int32_t value = 0;
  if (found != g_units.end()) {
    value = found->second.factor;
  } else if (const Tags* tags = TagsOf(copy)) {
    value = std::min(Whole(tags->initial), Cap(copy, *tags));
  }
  *factor *= static_cast<float>(value);
  return true;
}

// --- The shipment ---------------------------------------------------------------------------------------------

std::string Attribute(const char* node, const char* name) {
  const void* value = nullptr;
  if (node == nullptr || !kXmlAttribute(node, name, &value) || value == nullptr) {
    return {};
  }
  const char* text = kXmlText(value);
  return text == nullptr ? std::string() : std::string(text);
}

std::int32_t TypeId(void* db, const std::string& name) {
  const char* table = static_cast<const char*>(db) + kTypeNames;
  std::int32_t id = -1;
  if (name.empty() || !kNameFind(table, name.c_str(), kNameBucket(table, name.c_str()), &id)) {
    return -1;
  }
  return id;
}

bool ParseShipment(void* db, char* effect, const char* node) {
  const std::string shipped = Attribute(node, "unittype");
  const std::string nursery = Attribute(node, "nursery");
  const std::string consume = Attribute(node, "consume");
  const std::int32_t firstAbstract = Field<std::int32_t>(static_cast<const char*>(db), kFirstAbstract);
  Shipment shipment{TypeId(db, shipped), TypeId(db, nursery), 0};
  if (shipment.shipped < 0 || shipment.shipped >= firstAbstract) {
    uhc::Log(L"nurseryFactor: a FreeHomeCityUnitByNurseryFactor effect names %hs as unittype, which is not a proto; "
             L"effect dropped",
             shipped.empty() ? "nothing" : shipped.c_str());
    return false;
  }
  if (shipment.nursery < 0) {
    uhc::Log(L"nurseryFactor: a FreeHomeCityUnitByNurseryFactor effect names %hs as nursery, which is no proto or unit "
             L"type; effect dropped",
             nursery.empty() ? "nothing" : nursery.c_str());
    return false;
  }
  if (_stricmp(consume.c_str(), "all") == 0) {
    shipment.consume = -1;
  } else if (consume.empty() || _stricmp(consume.c_str(), "none") == 0) {
    shipment.consume = 0;
  } else {
    char* end = nullptr;
    const long n = std::strtol(consume.c_str(), &end, 10);
    if (end == consume.c_str() || *end != '\0' || n < 1 || n > kMaxValue) {
      uhc::Log(L"nurseryFactor: a FreeHomeCityUnitByNurseryFactor effect has consume=\"%hs\"; expected all, none or a "
               L"whole number from 1; effect dropped",
               consume.c_str());
      return false;
    }
    shipment.consume = static_cast<std::int32_t>(n);
  }
  *reinterpret_cast<std::int32_t*>(effect + 0x10) = static_cast<std::int32_t>(g_shipments.size());
  g_shipments.push_back(shipment);
  if (g_log) {
    uhc::Log(L"nurseryFactor: FreeHomeCityUnitByNurseryFactor %hs per factor of %hs, consume %hs", shipped.c_str(),
             nursery.c_str(), consume.empty() ? "none" : consume.c_str());
  }
  return true;
}

// When the effect applies: the stock FreeHomeCityUnit with amount x the factors taken (or counted).
std::int32_t RunShipment(char* player, std::int32_t* field, float* amount) {
  if (*field < 0 || static_cast<std::size_t>(*field) >= g_shipments.size()) {
    return uhc::kPlayerSubtypeFail;
  }
  const Shipment shipment = g_shipments[static_cast<std::size_t>(*field)];
  const std::int32_t playerId = Field<std::int32_t>(player, 0);
  const char* world = MainWorld();
  if (world == nullptr) {
    return uhc::kPlayerSubtypeFail;
  }
  if (world != g_world) {
    Sync(world);
  }
  SweepAll(world, true);
  std::int32_t total = 0;
  std::int32_t buildings = 0;
  for (auto& [id, state] : g_units) {
    char* unit = UnitById(world, id);
    if (unit == nullptr || PlayerIdOf(unit) != playerId || !IsAlive(unit) || !kIsBuilt(unit)) {
      continue;
    }
    const char* copy = Field<const char*>(unit, 0x5C);
    if (ProtoId(copy) != shipment.nursery && !kProtoIsType(copy, shipment.nursery)) {
      continue;
    }
    const std::int32_t take =
        shipment.consume < 0 ? state.factor : shipment.consume == 0 ? state.factor : std::min(state.factor, shipment.consume);
    total += take;
    ++buildings;
    if (shipment.consume != 0 && take > 0) {
      state.factor -= take;
      state.progress = 0;
    }
  }
  const float units = *amount * static_cast<float>(total);
  if (LogOk()) {
    uhc::Log(L"nurseryFactor: player %d, FreeHomeCityUnitByNurseryFactor proto %d: %d factor(s) from %d unit(s)%ls x "
             L"%.2f = %.2f unit(s)",
             playerId, shipment.shipped, total, buildings, shipment.consume != 0 ? L", taken" : L"",
             static_cast<double>(*amount), static_cast<double>(units));
  }
  if (!(units >= 1.0f)) {
    return uhc::kPlayerSubtypeDone;
  }
  *field = shipment.shipped;
  *amount = units;
  return kFreeHomeCityUnit;
}

// --- Display --------------------------------------------------------------------------------------------------

std::wstring Resolve(const Text& text) {
  if (text.id < 0) {
    return text.text;
  }
  BString value{nullptr};
  kBStringFromId(&value, text.id);
  std::wstring out = value.text != nullptr ? value.text : L"";
  kBStringFree(&value);
  return out;
}

void Replace(std::wstring* text, const wchar_t* key, const std::wstring& value) {
  const std::wstring token = key;
  for (std::size_t at = text->find(token); at != std::wstring::npos; at = text->find(token, at + value.size())) {
    text->replace(at, token.size(), value);
  }
}

struct Shown {
  const Tags* tags = nullptr;
  std::int32_t factor = 0;
  std::int32_t cap = 0;
  std::int32_t step = 1;
  std::uint32_t interval = 0;
  std::uint32_t progress = 0;
  bool built = false;
};

bool ShownOf(const char* unit, Shown* out) {
  const char* copy = unit != nullptr ? Field<const char*>(unit, 0x5C) : nullptr;
  out->tags = TagsOf(copy);
  if (out->tags == nullptr) {
    return false;
  }
  out->cap = Cap(copy, *out->tags);
  out->step = StepOf(copy, *out->tags);
  out->interval = IntervalMs(copy, *out->tags);
  out->built = kIsBuilt(unit);
  const auto found = g_units.find(Field<std::int32_t>(unit, 0x10));
  if (found != g_units.end() && MainWorld() == g_world) {
    out->factor = found->second.factor;
    out->progress = found->second.progress;
  } else {
    out->factor = std::min(Whole(out->tags->initial), out->cap);
  }
  return true;
}

std::wstring Line(const Text& text, const wchar_t* fallback, const Shown& shown, const std::wstring& name) {
  std::wstring line = text.id >= 0 || !text.text.empty() ? Resolve(text) : std::wstring(fallback);
  wchar_t number[32];
  swprintf_s(number, L"%d", shown.factor);
  Replace(&line, L"{current}", number);
  swprintf_s(number, L"%d", shown.cap);
  Replace(&line, L"{max}", number);
  swprintf_s(number, L"%d", shown.step);
  Replace(&line, L"{step}", number);
  const double seconds = shown.interval / 1000.0;
  if (std::fabs(seconds - std::round(seconds)) < 0.05) {
    swprintf_s(number, L"%d", static_cast<int>(std::lround(seconds)));
  } else {
    swprintf_s(number, L"%.1f", seconds);
  }
  Replace(&line, L"{seconds}", number);
  Replace(&line, L"{name}", name);
  return line;
}

std::wstring Fraction(const Shown& shown, const std::wstring& name) {
  wchar_t value[64];
  swprintf_s(value, L"%d/%d", shown.factor, shown.cap);
  std::wstring text = value;
  if (!name.empty()) {
    text += L" " + name;
  }
  return text;
}

bool __stdcall NurseryRow(const char* panel, const char* unit) {
  Shown shown;
  if (!ShownOf(unit, &shown)) {
    return false;
  }
  const std::wstring name = Resolve(shown.tags->name);
  std::wstring value = Fraction(shown, std::wstring());
  if (!shown.built) {
    value += L" once built";
  }
  std::wstring label = name;
  if (!label.empty()) {
    label[0] = static_cast<wchar_t>(std::towupper(label[0]));
  }
  if (!uhc::SetUnitPanelRow(panel, label.c_str(), value.c_str())) {
    return false;
  }
  std::wstring tip = L"\x2022 " + Line(shown.tags->countLine, L"{current} out of {max} {name}.", shown, name);
  if (shown.interval > 0) {
    tip += L"\n\x2022 " + Line(shown.tags->rateLine, L"Produces {step} {name} every {seconds} seconds.", shown, name);
  }
  uhc::SetUnitPanelRowTip(panel, tip.c_str());
  return true;
}

// {uhcNurseryFactor}: the first selected unit's "3/10 minks", or nothing.
bool __stdcall NurseryRef(uhc::DataRefValue* value) {
  if (value == nullptr || value->type != uhc::kDataRefString) {
    return false;
  }
  const char* world = MainWorld();
  const char* selection = world != nullptr ? kSelection() : nullptr;
  const std::int32_t count = selection == nullptr ? 0 : Field<std::int32_t>(selection, 0x14);
  const auto* ids = selection == nullptr ? nullptr : Field<const std::int32_t*>(selection, 0x10);
  if (count < 1 || ids == nullptr) {
    return false;
  }
  const char* unit = UnitById(world, ids[0]);
  Shown shown;
  if (unit == nullptr || !ShownOf(unit, &shown)) {
    return false;
  }
  const std::wstring text = Fraction(shown, Resolve(shown.tags->name));
  const BString source{const_cast<wchar_t*>(text.c_str())};
  kBStringAssign(&value->text, &source, -1, -1);
  return true;
}

}  // namespace

namespace uhc {

Outcome ApplyNurseryFactor(const Config& config) {
  const Config::Args* args = config.First("nurseryFactor");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"nurseryFactor: unknown option %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("nurseryFactor", {&sites::kIsBuilt, &sites::kUnitAliveSlot, &sites::kBStringAssign}) ||
      !AddProtoTagHandler("NurseryFactorMax", &ReadMax) || !AddProtoTagHandler("NurseryFactorInitial", &ReadInitial) ||
      !AddProtoTagHandler("NurseryFactorInterval", &ReadInterval) ||
      !AddProtoTagHandler("NurseryFactorStep", &ReadStep) || !AddProtoTagHandler("NurseryFactorGrowth", &ReadGrowth) ||
      !AddProtoTagHandler("NurseryFactorGrowthRate", &ReadGrowthRate) ||
      !AddProtoTagHandler("NurseryFactorTrickle", &ReadTrickle) ||
      !AddProtoTagHandler("NurseryFactorName", &ReadName) ||
      !AddProtoTagHandler("NurseryFactorRolloverCount", &ReadCountLine) ||
      !AddProtoTagHandler("NurseryFactorRolloverRate", &ReadRateLine) ||
      !AddTechSubtype("NurseryFactor", &ChangeFactor) || !AddTechSubtype("NurseryFactorMax", &ChangeMax) ||
      !AddTechSubtype("NurseryFactorInterval", &ChangeInterval) ||
      !AddTechSubtype("NurseryFactorStep", &ChangeStep) ||
      !AddTechPlayerSubtype("FreeHomeCityUnitByNurseryFactor", &ParseShipment, &RunShipment) ||
      !OnDatabaseLoad(&ForgetOnDataLoad) || !AddWorldTick(&Tick) ||
      !AddAutoGatherRateFilter("nurseryFactor", &NurseryRate)) {
    return Outcome::kFailed;
  }
  if (!AddUnitPanelRow(&NurseryRow)) {
    Log(L"nurseryFactor: no row in the unit panel");
  }
  if (!AddDataRef(L"uhcNurseryFactor", kDataRefString, &NurseryRef)) {
    Log(L"nurseryFactor: no data ref {uhcNurseryFactor}");
  }
  Log(L"nurseryFactor: the proto tags NurseryFactor*, the Data subtypes NurseryFactor, NurseryFactorMax, "
      L"NurseryFactorInterval, NurseryFactorStep and FreeHomeCityUnitByNurseryFactor, the AutoGather rate x the factor, "
      L"the unit panel row and {uhcNurseryFactor} are on%ls (multiplayer unverified)",
      g_log ? L"; logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
