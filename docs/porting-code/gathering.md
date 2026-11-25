# Code for WoL: Gathering

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [showGatherRate](#showgatherrate)
- [displayedRange](#displayedrange)
- [workRateByAbstractType](#workratebyabstracttype)
- [cratePriority](#cratepriority)
- [autoGatherScaleByContained](#autogatherscalebycontained)
- [nurseryFactor](#nurseryfactor)
- [unitResourceAuras](#unitresourceauras)
- [linkedResource](#linkedresource)
- [resourceGatherAuras](#resourcegatherauras)
- [resourceDebt](#resourcedebt)
- [truckAttackResourceFix](#truckattackresourcefix)
- [autoGatherFrom](#autogatherfrom)
- [buildingGather](#buildinggather)
- [herdWalkAwayFix](#herdwalkawayfix)
- [faithResource](#faithresource)
- [deadReplacementAtZeroInventory](#deadreplacementatzeroinventory)

## showGatherRate

Contract: [showGatherRate](../porting-to-another-dll.md#showgatherrate).

Besides the core helpers, it needs: [`unitinfo.h`](helpers.md#unit-info-for-the-panels), [`unitpanel.h`](helpers.md#unit-panel-row-the-minimized-interface), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `BStringFree` `0x4010CA` (31 B), `BStringAssign` `0x443BB8` (15 B), `BStringFormat` `0x444EFB` (20 B), `DataRefStringEval` `0x44A635` (100 B), `IsAbstractIndex` `0x44CAC4` (70 B), `IsA` `0x44D7FA` (105 B), `IsBuilt` `0x44DDB4` (31 B), `ProtoFlag` `0x45EE02` (53 B), `StatPanelAutoGatherGate` `0x4D76FF` (309 B), `StatPanelAfterAutoGather` `0x4D7834` (11 B), `GatherTickHead` `0x4ECD87` (20 B), `GatherTickPushEbp` `0x4ECDCC` (7 B), `GatherTickPushEbx` `0x4ECE16` (10 B), `GatherTickGatherer` `0x4ECE6D` (21 B), `GatherTickRate` `0x4ED02A` (38 B), `GatherTickPlayerRate` `0x4ED130` (42 B), `GatherTickPlayerBlock` `0x4ED1A4` (20 B), `GatherTickAddResource` `0x4ED1E1` (18 B), `BStringFromId` `0x58EA52` (25 B), `GatherRateStringRef` `0x5D2D38` (8 B), `DataRefStub` `0x5FDE49` (5 B), `ResourceNameId` `0x60782A` (34 B), `StatPanelRowWriter` `0x69AF7C` (100 B), `StatPanelAgLoop` `0x69AFE0` (74 B), `StatPanelRowFormat` `0x69B02A` (349 B), `CurrentUnitRef` `0x6F49B1` (65 B), `ResourceIconText` `0x706EFB` (16 B).

### src/features/gatherrate.cpp

```cpp
// showGatherRate: the gather rate per second of the selected unit, ("Food 0.84/s"),
// as a stat panel row and as the formatText data ref {currentUnitGatherRateString}. UI only.
//
// Stock: the stat panel (uiunitstatpanel3, rows StackLabel/StackValue 0..8, filled by
// FUN_004D70ED) has a per-second row only for AutoGather units (a Bank, ...): after the HP
// row it asks the unit's AutoGather action for its rate and writes "Food (icon): 0.67/s" with
// a row writer and formatter in the fill's cold part (0x69AF7C..0x69B182). A villager's rate
// exists only inside its gather tick FUN_004ECD87 (BUnitGatherAction::collectStuff_2, once per
// gather animation loop): R = ((cur - base) + k * base) * [world+318h] * the Gathering dance is
// the rate per second, multiplied by the elapsed time, then by [player+37Ch], and added to the
// stockpile. No getter returns it. The data refs currentUnitGatherRate / ...Float / ...String are
// registered (FUN_005CFA7C) with a stub provider that always fails (0x5FDE49).
//
// The record hook (0x4ED044, where ST0 still holds R) copies R * [player+37Ch], the resource,
// the target, the elapsed time and the game time into a DLL table indexed by the gatherer's ID.
// It writes nothing in the game and leaves the x87 stack as it found it, so the simulation is
// unchanged. The panel hook (0x4D7834, after the stock AutoGather row) has the stock row writer
// and formatter write one more row when the single selected unit's record is valid: the unit's
// current action is still the recorded Gather action, in its gathering state, and the record is
// fresh. The data ref currentUnitGatherRateString (id 68h) gets a provider that returns
// "Food 0.67/s", or an empty string when the current unit is not gathering. The int and float
// refs (ids 19h and 1Ah) keep the stub: mod UIs already use {currentUnitGatherRate(gold)}.
// With the minimized interface (optionminimizedui) the stat panel fill returns at its start, and the
// unit panel writes an AutoGather rate itself, in the gadgets unitResourceRateLabel / Value
// (0x69922D..0x699456, gadgets at [panel+33Ch] / [panel+340h]). A hook after that block
// (0x699456) writes the gatherer's rate there. The normal interface has no such gadgets.
// With several units selected, the minimized interface's row sums their rates per resource.
// The hooks are in hooks/gatherrate_hooks.asm.
#include <cmath>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <string>
#include <unordered_set>

#include "../features.h"
#include "../unitinfo.h"
#include "../generated/sites.h"
#include "../unitpanel.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
// One record per gatherer, written by the tick hook (REC_* in hooks/gatherrate_hooks.asm).
struct UhcGatherRecord {
  std::int32_t unit;      // +00 the gatherer's unit ID; written last
  const char* action;     // +04 the Gather action, the tick's this
  std::int32_t resource;  // +08 [action+70h]
  std::int32_t target;    // +0C [action+14h], the target's unit ID
  float rate;             // +10 per second, with the player's gather multiplier
  float elapsed;          // +14 the tick's elapsed seconds (one gather animation loop)
  std::uint32_t time;     // +18 game time in ms
  std::uint32_t unused;   // +1C
};
}

namespace {

// The hook indexes the table with ID & 3FFFh and ID << 5. The engine's unit IDs go up to 3FFFFh;
// two gatherers that share an index are told apart by the stored ID (the later one wins).
constexpr std::size_t kRecordCount = 0x4000;
static_assert(kRecordCount == 0x4000 && sizeof(UhcGatherRecord) == 0x20,
              "the hook addresses a record as (ID & 3FFFh) << 5");

}  // namespace

extern "C" {
UhcGatherRecord g_uhcGatherRecords[kRecordCount];
std::int32_t g_uhcGatherRowPending = 0;  // 1 between the panel hook's divert and its return
std::int32_t g_uhcGatherRowRes = 0;
float g_uhcGatherRowRate = 0.0f;

void UhcGatherRecordHook();
void UhcGatherPanelHook();
void UhcGatherRowValueHook();
void UhcGatherRateRefHook();
}

namespace {

// Engine layout (docs/engine-symbols.md, "Gathering and the stat panel").
constexpr std::uint32_t kGameGlobal = 0x00C66234;        // game; +13Ch world, +140h database
constexpr std::uint32_t kUiGlobal = 0x00C67310;          // [[+920h]+13Ch]: the data refs' current unit ID

constexpr std::uint8_t kGatheringState = 5;          // [action+61h] while the tick runs (0x4ECC8E)
constexpr std::uint32_t kTreeGatherVtable = 0x00B979D8;  // the current action of a villager on a tree
constexpr std::int32_t kMaxResources = 16;
constexpr std::int32_t kShowAutoGatherRate = 0x9B;   // proto flag; <Flag>DoNotShowAutoGatherRate clears it
constexpr std::int32_t kAbstractShrine = 0x58;       // abstract index: the tick adds nothing (0x4ED14B)
constexpr std::int32_t kStatPanelRows = 9;           // StackLabel/StackValue 0..8 (0x9BBAD1)
constexpr std::int32_t kStringValue = 3;             // data ref value type 3: a BString at +4
constexpr float kWholeEpsilon = 1e-6f;               // 0xBA20B4, the formatter's "%d/s" test

// A record stays valid for two gather animation loops, and at least this long.
constexpr float kMinFreshMs = 2500.0f;
constexpr float kMaxFreshMs = 60000.0f;

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using ProtoFlagFn = bool(__thiscall*)(const char* proto, std::int32_t bit);
using IsAbstractIndexFn = bool(__thiscall*)(const char* proto, std::int32_t index);
using IsBuiltFn = bool(__thiscall*)(const char* unit);
using ResourceNameIdFn = std::int32_t(__thiscall*)(const char* database, std::int32_t resource);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kProtoFlag = reinterpret_cast<ProtoFlagFn>(0x0045EE02);
const auto kIsAbstractIndex = reinterpret_cast<IsAbstractIndexFn>(0x0044CAC4);
const auto kIsBuilt = reinterpret_cast<IsBuiltFn>(0x0044DDB4);
const auto kResourceNameId = reinterpret_cast<ResourceNameIdFn>(0x0060782A);

// The engine's string: one pointer to a wide, reference-counted buffer; null is empty.
struct BString {
  wchar_t* text;
};

const wchar_t* const kRateLabelFormat = reinterpret_cast<const wchar_t*>(0x00C36580);  // "%s (<icon=...>):"
using BStringFormatFn = void(__cdecl*)(BString* out, const wchar_t* format, ...);
using ResourceIconFn = const wchar_t*(__thiscall*)(const char* database, std::int32_t resource);
const auto kBStringFormat = reinterpret_cast<BStringFormatFn>(0x00444EFB);
const auto kResourceIcon = reinterpret_cast<ResourceIconFn>(0x00706EFB);
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t stringId);
using BStringAssignFn = void(__thiscall*)(BString* self, const BString* source, std::int32_t, std::int32_t);
using BStringFreeFn = void(__thiscall*)(BString* self);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringAssign = reinterpret_cast<BStringAssignFn>(0x00443BB8);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);

// What a data ref provider fills: the evaluator sets type to the ref's registered type.
struct DataRefValue {
  std::int32_t type;
  BString text;  // type 3
};

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

// The unit with this ID in the world's table ([world+0Ch], count [world+10h]), as the engine
// looks it up (ID & 3FFFFh, then the stored ID must match); null if it is gone.
const char* UnitById(const char* world, std::int32_t id) {
  if (world == nullptr || id < 0) {
    return nullptr;
  }
  const std::int32_t index = id & 0x3FFFF;
  if (index >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[index];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

const char* ProtoName(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

bool g_log = false;          // "showGatherRate ... log"
bool g_useMarker = false;    // a unit type was given: only its units get the panel row
std::string g_markerName;
std::int32_t g_markerType = -1;  // set on each database load

struct Rate {
  std::int32_t resource;
  float perSecond;
  std::int32_t target;
};

// The unit's current gather rate from its record, or false. Valid while the unit's current
// action ([[unit+58h]+24h]) is the recorded Gather action (or, on a tree, the action over it),
// that action is in its gathering state and still belongs to the unit (actions come from a pool),
// and the record is younger than two of its animation loops (2.5 s at least) in game time. Two
// cases where the tick adds nothing although it computed a rate are left out: a target of type
// AbstractShrine (0x4ED14B) and a player with [player+338h] set (0x4ED1AB).
bool CurrentRate(const char* world, const char* database, const char* unit, Rate* rate) {
  if (world == nullptr || database == nullptr || unit == nullptr) {
    return false;
  }
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (id < 0) {
    return false;
  }
  const UhcGatherRecord& record = g_uhcGatherRecords[static_cast<std::size_t>(id) & (kRecordCount - 1)];
  const char* manager = Field<const char*>(unit, 0x58);
  const char* current = manager == nullptr ? nullptr : Field<const char*>(manager, 0x24);
  if (record.unit != id || record.action == nullptr || current == nullptr ||
      Field<std::uint8_t>(record.action, 0x61) != kGatheringState || Field<const char*>(record.action, 0x10) != unit) {
    return false;
  }
  // A villager on a tree: its current action is not the Gather action that ticks but another one (vtable 0xB979D8,
  // in its state 5 while the wood comes in; seen in game, 2026-11-21: the record written each loop, the current
  // action that one). The record's own action, state and owner, and its age, then decide.
  if (current != record.action &&
      (Field<std::uint32_t>(current, 0) != kTreeGatherVtable ||
       Field<std::uint8_t>(current, 0x61) != kGatheringState)) {
    return false;
  }
  if (record.resource < 0 || record.resource >= Field<std::int32_t>(database, 0x80) || !(record.rate > 0.0f)) {
    return false;
  }
  const std::int32_t age = static_cast<std::int32_t>(Field<std::uint32_t>(world, 0x108) - record.time);
  float window = record.elapsed > 0.0f ? 2000.0f * record.elapsed : 0.0f;
  window = window < kMinFreshMs ? kMinFreshMs : (window > kMaxFreshMs ? kMaxFreshMs : window);
  if (age < 0 || static_cast<float>(age) > window) {
    return false;
  }
  const char* player = Field<const char*>(unit, 0x44);
  if (player != nullptr && Field<std::int32_t>(player, 0x338) != 0) {
    return false;
  }
  const char* target = UnitById(world, record.target);
  const char* targetProto = target == nullptr ? nullptr : Field<const char*>(target, 0x5C);
  if (targetProto != nullptr && kIsAbstractIndex(targetProto, kAbstractShrine)) {
    return false;
  }
  rate->resource = record.resource;
  rate->perSecond = record.rate;
  rate->target = record.target;
  return true;
}

// What a unit counts for in a row: built, the proto flag, and the marker when one was given.
bool ShowsRow(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  return proto != nullptr && kIsBuilt(unit) && kProtoFlag(proto, kShowAutoGatherRate) &&
         (!g_useMarker || (g_markerType >= 0 && kProtoIsType(proto, g_markerType)));
}

// The sum of the selected units' rates per resource; false if none of them is gathering.
bool GroupRates(const char* world, const char* database, const char* selection, float* rates) {
  const std::int32_t count = Field<std::int32_t>(selection, 0x14);
  const auto* ids = Field<const std::int32_t*>(selection, 0x10);
  const std::int32_t resources = Field<std::int32_t>(database, 0x80);
  bool any = false;
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    const char* unit = UnitById(world, ids[i]);
    Rate rate{};
    if (unit != nullptr && ShowsRow(unit) && CurrentRate(world, database, unit, &rate) && rate.resource < resources &&
        rate.resource < kMaxResources) {
      rates[rate.resource] += rate.perSecond;
      any = true;
    }
  }
  return any;
}

// The resource's display name (string table), copied; "?" if it has none.
std::wstring ResourceName(const char* database, std::int32_t resource) {
  const std::int32_t stringId = kResourceNameId(database, resource);
  if (stringId < 0) {
    return L"?";
  }
  BString name;
  kBStringFromId(&name, stringId);
  std::wstring copy = name.text == nullptr ? L"?" : name.text;
  kBStringFree(&name);
  return copy;
}

// Logged (unit ID, resource, where) triples, for the world and game time they were logged in.
enum Where : std::uint64_t { kStatPanel = 0, kDataRef = 1 };
std::unordered_set<std::uint64_t> g_logged;
const char* g_logWorld = nullptr;
std::uint32_t g_logTime = 0;

// With "log": one line the first time a unit's rate for a resource is shown in the stat panel,
// and the first time the data ref returns it. A new world, or the game time going back (another
// game in the same world object), starts again.
void LogShown(const char* world, const char* database, const char* unit, const Rate& rate, Where where) {
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_logWorld || static_cast<std::int32_t>(now - g_logTime) < 0) {
    g_logged.clear();
    g_logWorld = world;
  }
  g_logTime = now;
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const std::uint64_t key = (static_cast<std::uint64_t>(static_cast<std::uint32_t>(id)) << 32) |
                            (static_cast<std::uint64_t>(static_cast<std::uint32_t>(rate.resource)) << 1) | where;
  if (!g_logged.insert(key).second) {
    return;
  }
  const char* player = Field<const char*>(unit, 0x44);
  const char* target = UnitById(world, rate.target);
  uhc::Log(L"showGatherRate: unit %d (%hs) of player %d gathers %ls (resource %d) at %.3f/s from unit %d "
           L"(%hs), shown in the %ls",
           id, ProtoName(unit), player == nullptr ? -1 : Field<std::int32_t>(player, 0x00),
           ResourceName(database, rate.resource).c_str(), rate.resource, static_cast<double>(rate.perSecond),
           rate.target, target == nullptr ? "gone" : ProtoName(target),
           where == kStatPanel ? L"stat panel" : L"data ref currentUnitGatherRateString");
}

}  // namespace

extern "C" {

// From the panel hook at 0x4D7834. True if the stat panel gets a gather row in `row` for `unit`,
// with g_uhcGatherRowRes / g_uhcGatherRowRate set for the row hook. Mirrors the stock AutoGather
// row's gate (0x4D7702..0x4D7809): a free row, one selected unit, byte [selection+21h] clear, a
// built unit and proto flag 9Bh (so <Flag>DoNotShowAutoGatherRate</Flag> hides this row too).
bool __stdcall UhcGatherPanelRow(const char* unit, const char* selection, std::int32_t row) {
  if (unit == nullptr || selection == nullptr || row < 0 || row >= kStatPanelRows ||
      Field<std::int32_t>(selection, 0x14) != 1 || Field<std::uint8_t>(selection, 0x21) != 0 || !ShowsRow(unit)) {
    return false;
  }
  const char* world = World();
  const char* database = Database();
  Rate rate{};
  if (!CurrentRate(world, database, unit, &rate)) {
    return false;
  }
  g_uhcGatherRowRes = rate.resource;
  g_uhcGatherRowRate = rate.perSecond;
  if (g_log) {
    LogShown(world, database, unit, rate, kStatPanel);
  }
  return true;
}

// The minimized interface's row for a group: one resource as the single unit's row, several as icon
// and number each, as they would not fit with their names.
bool __stdcall UhcGatherGroupPanel(const char* panel, const char* selection) {
  const char* world = World();
  const char* database = Database();
  float rates[kMaxResources] = {};
  if (world == nullptr || database == nullptr || !GroupRates(world, database, selection, rates)) {
    return false;
  }
  std::int32_t shown = 0;
  std::int32_t last = -1;
  for (std::int32_t r = 0; r < kMaxResources; ++r) {
    if (rates[r] > 0.0f) {
      ++shown;
      last = r;
    }
  }
  wchar_t number[32];
  if (shown == 1) {
    BString name{nullptr};
    const std::int32_t stringId = kResourceNameId(database, last);
    if (stringId >= 0) {
      kBStringFromId(&name, stringId);
    }
    BString label{nullptr};
    kBStringFormat(&label, kRateLabelFormat, name.text == nullptr ? L"?" : name.text, kResourceIcon(database, last));
    swprintf_s(number, L"%.2f/s", static_cast<double>(rates[last]));
    const bool written = uhc::SetUnitPanelRow(panel, label.text == nullptr ? L"" : label.text, number);
    kBStringFree(&label);
    kBStringFree(&name);
    return written;
  }
  std::wstring row;
  for (std::int32_t r = 0; r < kMaxResources; ++r) {
    if (rates[r] > 0.0f) {
      BString label{nullptr};
      kBStringFormat(&label, kRateLabelFormat, L"", kResourceIcon(database, r));
      if (label.text != nullptr) {
        row += label.text;
      }
      kBStringFree(&label);
      swprintf_s(number, L" %.2f ", static_cast<double>(rates[r]));
      row += number;
    }
  }
  return uhc::SetUnitPanelRow(panel, row.c_str(), L"");
}

// The minimized interface's row (unitpanel.cpp). Same gate as the stat panel row.
bool __stdcall UhcGatherUnitPanel(const char* panel, const char* unit) {
  if (!ShowsRow(unit)) {
    return false;
  }
  const char* world = World();
  const char* database = Database();
  Rate rate{};
  if (!CurrentRate(world, database, unit, &rate)) {
    return false;
  }
  BString name{nullptr};
  const std::int32_t stringId = kResourceNameId(database, rate.resource);
  if (stringId >= 0) {
    kBStringFromId(&name, stringId);
  }
  BString labelText{nullptr};
  kBStringFormat(&labelText, kRateLabelFormat, name.text == nullptr ? L"?" : name.text,
                 kResourceIcon(database, rate.resource));
  wchar_t text[32];
  const float whole = std::floor(rate.perSecond);
  if (rate.perSecond - whole <= kWholeEpsilon) {
    swprintf_s(text, L"%d/s", static_cast<int>(whole));
  } else {
    swprintf_s(text, L"%.2f/s", static_cast<double>(rate.perSecond));
  }
  const bool written = uhc::SetUnitPanelRow(panel, labelText.text == nullptr ? L"" : labelText.text, text);
  kBStringFree(&labelText);
  kBStringFree(&name);
  if (written && g_log) {
    LogShown(world, database, unit, rate, kStatPanel);
  }
  return written;
}

// The provider of currentUnitGatherRateString (id 68h, registered as a string), bool(Value*),
// ret 4. Reads the current unit as the stock providers do (FUN_006F49B1). Gathering:
// "<resource> 0.67/s" ("8/s" for a whole number, as the panel row). Not gathering: an empty
// string. Fails, as the stub did, for any other value type (the evaluators pass the ref's
// registered type, so none reaches it). An argument ({...(x)}, in [0C6DF7Ch]) is ignored: it is
// not known whether that global is 0 for a ref written without one.
bool __stdcall UhcGatherRateRef(DataRefValue* value) {
  if (value == nullptr || value->type != kStringValue) {
    return false;
  }
  const char* world = World();
  const char* database = Database();
  const char* ui = *reinterpret_cast<const char* const*>(kUiGlobal);
  const char* view = ui == nullptr ? nullptr : Field<const char*>(ui, 0x920);
  if (world == nullptr || database == nullptr || view == nullptr) {
    return false;
  }
  const char* unit = UnitById(world, Field<std::int32_t>(view, 0x13C));
  Rate rate{};
  if (!CurrentRate(world, database, unit, &rate)) {
    return true;  // the value stays the empty string the evaluator made
  }
  const std::wstring name = ResourceName(database, rate.resource);
  wchar_t text[128];
  const float whole = std::floor(rate.perSecond);
  if (rate.perSecond - whole <= kWholeEpsilon) {
    swprintf_s(text, L"%ls %d/s", name.c_str(), static_cast<int>(whole));
  } else {
    swprintf_s(text, L"%ls %.2f/s", name.c_str(), static_cast<double>(rate.perSecond));
  }
  const BString source{text};
  kBStringAssign(&value->text, &source, -1, -1);
  if (g_log) {
    LogShown(world, database, unit, rate, kDataRef);
  }
  return true;
}

}  // extern "C"

namespace {
bool g_unitInfoOn = false;  // the key applied: unitinfo.h answers
}  // namespace

namespace uhc {

Outcome ApplyShowGatherRate(const Config& config) {
  const Config::Args* args = config.First("showGatherRate");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (!g_useMarker) {
      g_markerName = arg;
      g_useMarker = true;
    } else {
      Log(L"showGatherRate: unexpected argument %hs (expected: [UnitType] [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  g_log = log;

  if (!VerifyAll("showGatherRate",
                 {&sites::kGatherTickHead, &sites::kGatherTickPushEbp, &sites::kGatherTickPushEbx,
                  &sites::kGatherTickGatherer, &sites::kGatherTickRate, &sites::kGatherTickPlayerRate,
                  &sites::kGatherTickPlayerBlock, &sites::kGatherTickAddResource, &sites::kStatPanelAutoGatherGate,
                  &sites::kStatPanelAfterAutoGather, &sites::kStatPanelRowWriter, &sites::kStatPanelAgLoop,
                  &sites::kStatPanelRowFormat, &sites::kGatherRateStringRef, &sites::kDataRefStub,
                  &sites::kDataRefStringEval, &sites::kCurrentUnitRef, &sites::kProtoFlag, &sites::kIsAbstractIndex,
                  &sites::kResourceNameId, &sites::kBStringFromId, &sites::kBStringAssign, &sites::kBStringFree,
                  &sites::kIsBuilt, &sites::kIsA, &sites::kBStringFormat, &sites::kResourceIconText})) {
    return Outcome::kFailed;
  }
  if (g_useMarker && !RequestAbstractUnitType(g_markerName.c_str(), &g_markerType)) {
    return Outcome::kFailed;
  }
  // The row hook first and the panel hook last: only the panel hook sets g_uhcGatherRowPending,
  // so a failure part-way leaves hooks that all take the stock path.
  const std::uint32_t provider = static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(&UhcGatherRateRefHook));
  if (!WriteJmp(sites::kStatPanelAgLoop.va, reinterpret_cast<const void*>(&UhcGatherRowValueHook), 6) ||
      !WriteJmp(sites::kGatherTickRate.va + 0x1A, reinterpret_cast<const void*>(&UhcGatherRecordHook), 8) ||
      !WriteDword(sites::kGatherRateStringRef.va + 4, provider) ||
      !WriteJmp(sites::kStatPanelAfterAutoGather.va, reinterpret_cast<const void*>(&UhcGatherPanelHook), 7) ||
      !AddUnitPanelRow(&UhcGatherUnitPanel)) {
    return Outcome::kFailed;
  }
  SetUnitPanelGroupRow(&UhcGatherGroupPanel);
  if (g_useMarker) {
    Log(L"showGatherRate: the stat panel shows the gather rate per second of a selected unit of unittype %hs, "
        L"and {currentUnitGatherRateString} returns it for any unit%ls (UI only)",
        g_markerName.c_str(), log ? L", each unit's first rate per resource logged" : L"");
  } else {
    Log(L"showGatherRate: the stat panel shows the gather rate per second of a selected gathering unit, and "
        L"{currentUnitGatherRateString} returns it%ls (UI only)",
        log ? L", each unit's first rate per resource logged" : L"");
  }
  g_unitInfoOn = true;
  return Outcome::kApplied;
}

}  // namespace uhc

namespace uhc::unitinfo {

bool GatherRate(const char* unit, std::wstring* out) {
  if (!g_unitInfoOn) {
    return false;
  }
  Rate rate{};
  if (!CurrentRate(World(), Database(), unit, &rate)) {
    return false;
  }
  wchar_t text[128];
  const float whole = std::floor(rate.perSecond);
  if (rate.perSecond - whole <= kWholeEpsilon) {
    swprintf_s(text, L"%ls %d/s", ResourceName(Database(), rate.resource).c_str(), static_cast<int>(whole));
  } else {
    swprintf_s(text, L"%ls %.2f/s", ResourceName(Database(), rate.resource).c_str(), static_cast<double>(rate.perSecond));
  }
  *out = text;
  return true;
}

}  // namespace uhc::unitinfo
```

### src/hooks/gatherrate_hooks.asm

```asm
; Hooks for showGatherRate. Each is entered through a jmp written over the stock code (or, for the
; data ref, through the provider pointer of the registration) and leaves through an explicit jmp
; to a verified continuation (docs/engine-symbols.md, "Gathering and the stat panel").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcGatherRecords:BYTE         ; 4000h records of 20h bytes, by unit ID & 3FFFh
EXTERNDEF g_uhcGatherRowPending:SDWORD    ; 1 while the stock row writer writes our row
EXTERNDEF g_uhcGatherRowRes:SDWORD        ; that row's resource
EXTERNDEF g_uhcGatherRowRate:DWORD        ; that row's rate per second (float)

UhcGatherPanelRow PROTO STDCALL unit:DWORD, selection:DWORD, row:DWORD
UhcGatherRateRef PROTO STDCALL value:DWORD

; Record layout, shared with features/gatherrate.cpp (GatherRecord).
REC_UNIT        EQU 00h     ; the gatherer's unit ID
REC_ACTION      EQU 04h     ; the Gather action (the tick's this)
REC_RESOURCE    EQU 08h     ; [action+70h]
REC_TARGET      EQU 0Ch     ; [action+14h], the target's unit ID
REC_RATE        EQU 10h     ; float: rate per second times [player+37Ch]
REC_ELAPSED     EQU 14h     ; float: the tick's elapsed seconds
REC_TIME        EQU 18h     ; game time in ms, [world+108h]

.data
gatherTickNext  dd 004ED04Ch    ; fcomp [esp+1Ch]: the amount against what the target holds
panelNext       dd 004D783Bh    ; test ecx,ecx / je 4D784Eh, after the stolen proto load
rowWriter       dd 0069AF7Ch    ; the stock row writer: the label and value gadgets of row EBX
agLoopNext      dd 0069AFE6h    ; mov edx,[ecx+140h]: the stock AutoGather resource loop
rowFormat       dd 0069B02Ah    ; the stock row formatter: ESI/EDI gadgets, EBX resource, [esp+1Ch] rate

.code

; Replaces 0x4ED044..0x4ED04B (fmul dword ptr [esp+30h] / fst dword ptr [esp+14h]) in the gather
; tick FUN_004ECD87, on the simulation path. ST0 = R, the rate per second (the x87 stack holds
; only R), before the elapsed time [esp+30h] (the tick's argument) is multiplied in. ESI = the
; Gather action, [esi+10h] = the gatherer (not null, 0x4ECE70), its player [+44h] (not null,
; 0x4ECE78). Writes the gatherer's record in DLL memory only: nothing in the game changes, ST0 and
; the x87 stack are as they were, and EAX/ECX/EDX are restored (the flags are dead: the fcomp /
; fnstsw / test after the continuation set them).
UhcGatherRecordHook PROC
    TRACE_ONCE "showGatherRate record (0x4ED044)"
    push eax
    push ecx
    push edx
    mov ecx, dword ptr [esi+10h]        ; the gatherer
    test ecx, ecx
    je done
    cmp dword ptr [ecx+44h], 0          ; its player
    je done
    cmp dword ptr [esi+70h], 0          ; the resource this tick adds to
    jl done
    mov edx, dword ptr [ecx+10h]        ; the gatherer's unit ID
    test edx, edx
    jl done
    and edx, 3FFFh
    shl edx, 5
    add edx, OFFSET g_uhcGatherRecords
    mov eax, dword ptr [esi+70h]
    mov dword ptr [edx+REC_RESOURCE], eax
    mov dword ptr [edx+REC_ACTION], esi
    mov eax, dword ptr [esi+14h]
    mov dword ptr [edx+REC_TARGET], eax
    mov eax, dword ptr [esp+3Ch]        ; elapsed, the tick's [esp+30h] (3 pushes deeper)
    mov dword ptr [edx+REC_ELAPSED], eax
    mov eax, dword ptr [ecx+44h]        ; the player
    fld st(0)                           ; a copy of R; R itself stays in ST1, untouched
    fmul dword ptr [eax+37Ch]           ; the player's gather multiplier, as 0x4ED13A applies it
    fstp dword ptr [edx+REC_RATE]
    mov eax, dword ptr ds:[0C66234h]    ; game
    mov eax, dword ptr [eax+13Ch]       ; world (the tick reads it with no null test)
    mov eax, dword ptr [eax+108h]       ; game time, ms
    mov dword ptr [edx+REC_TIME], eax
    mov eax, dword ptr [ecx+10h]
    mov dword ptr [edx+REC_UNIT], eax   ; last: the record is complete
done:
    pop edx
    pop ecx
    pop eax
    fmul dword ptr [esp+30h]            ; stolen 0x4ED044
    fst dword ptr [esp+14h]             ; stolen 0x4ED048
    jmp gatherTickNext
UhcGatherRecordHook ENDP

; Replaces 0x4D7834..0x4D783A (mov esi,[esp+38h] / mov ecx,[esi+5Ch]) in the stat panel fill
; FUN_004D70ED, the join point after the stock AutoGather row (EBP frame: [ebp+8] = the
; selection; [esp+2Ch] = the next free row, [esp+38h] = the first selected unit). When the
; selected unit is gathering, sends the stock row writer to write one more row with its rate; the
; writer comes back here (0x69AFD2, 0x69AFDA or 0x69B182), where g_uhcGatherRowPending makes this
; hook take the stock path. Every register the hook does not mean to set is preserved; the stock
; AutoGather path already arrives here with EAX, EBX, EDX and EDI changed, and the code after the
; continuation reloads them.
UhcGatherPanelHook PROC
    TRACE_ONCE "showGatherRate panel (0x4D7834)"
    cmp g_uhcGatherRowPending, 0
    jne written
    push eax
    push ecx
    push edx
    push dword ptr [esp+0Ch+2Ch]        ; the row
    push dword ptr [ebp+8]              ; the selection
    push dword ptr [esp+14h+38h]        ; the unit
    call UhcGatherPanelRow              ; -> 1 with g_uhcGatherRowRes / g_uhcGatherRowRate set
    test al, al
    pop edx
    pop ecx
    pop eax
    jne addRow
stock:
    mov esi, dword ptr [esp+38h]        ; stolen 0x4D7834
    mov ecx, dword ptr [esi+5Ch]        ; stolen 0x4D7838
    jmp panelNext
written:
    mov g_uhcGatherRowPending, 0        ; back from the row writer (row written or skipped)
    jmp stock
addRow:
    mov g_uhcGatherRowPending, 1
    mov ebx, dword ptr [esp+2Ch]        ; the row, as the stock path sets EBX for the writer
    jmp rowWriter
UhcGatherPanelHook ENDP

; Replaces 0x69AFE0 (mov ecx,[0C66234h]) in the stat panel fill's cold part, the start of the
; AutoGather resource loop, reached only by fall-through once the row's gadgets are resolved
; (ESI = label, EDI = value). For our row, skips the loop and enters the formatter with what the
; loop would leave: EBX = the resource and [esp+1Ch] = the rate (EAX is set again at 0x69B02A).
; Otherwise runs the stock loop.
UhcGatherRowValueHook PROC
    TRACE_ONCE "showGatherRate row value (0x69AFE0)"
    cmp g_uhcGatherRowPending, 0
    jne ours
    mov ecx, dword ptr ds:[0C66234h]    ; stolen 0x69AFE0
    jmp agLoopNext
ours:
    mov ebx, g_uhcGatherRowRes
    mov eax, g_uhcGatherRowRate
    mov dword ptr [esp+1Ch], eax
    jmp rowFormat
UhcGatherRowValueHook ENDP

; The provider of data ref id 68h (currentUnitGatherRateString): its pointer replaces the stub
; 0x5FDE49 in the registration (imm32 at 0x5D2D3C). Called as bool provider(Value*), ret 4, ECX
; unused; the C++ function has the same stdcall frame, so the hook only traces and jumps.
UhcGatherRateRefHook PROC
    TRACE_ONCE "showGatherRate data ref (0x5D2D3C)"
    jmp UhcGatherRateRef
UhcGatherRateRefHook ENDP

END
```

## displayedRange

Contract: [displayedRange](../porting-to-another-dll.md#displayedrange).

Besides the core helpers, it needs: [`ghostobservers.h`](helpers.md#placement-ghost-observers), [`prototags.h`](helpers.md#proto-tags), [`unitmodels.h`](helpers.md#models-on-a-unit), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `PlayerById` `0x44CB21` (30 B), `UnitById` `0x44CC6D` (58 B), `IsA` `0x44D7FA` (105 B), `AltQuery` `0x452EA0` (24 B), `PlayerProtoEntry` `0x45311B` (8 B), `CurrentSelectionGroup` `0x453B28` (33 B), `ActionRangeByKey` `0x4946D6` (10 B), `ProtoFlagLastCompare` `0x5F7269` (26 B).

### src/features/displayrange.cpp

```cpp
// displayedRange: a selected unit shows its range on the ground while Alt is held, one ring per ranged attack.
//
// Proto data:
//   <DisplayRange>1</DisplayRange>              the unit shows its rings when it is selected and Alt is held;
//   <AlwaysDisplayRange>1</AlwaysDisplayRange>  (or <Flag>AlwaysDisplayRange</Flag>) it shows them whenever it is
//                                               selected, without Alt;
//   <DisplayedRange>N</DisplayedRange>          a fixed radius instead of the attacks', repeatable.
// With no <DisplayedRange>, the rings are those of each active action of the unit's current tactic with the ranged
// flag 0Ah (<RangedLogic>), read from the player's copy, so range techs show at once. The radius is where an infantry
// unit's centre comes into that attack's range, as the game measures it (kRadii's comment): its MaxRange (0x4946D6 with
// key -1, the number the stat panel shows) plus the target's radius x sqrt(2), plus the attacker's own radius x
// sqrt(2), or for a building the half side of its rectangle. Each radius is drawn as the ring of tools/rings nearest to
// it (1 m apart up to 50); two attacks on one ring share it.
//
// Alt is the game's own query, the one the HP bar chunk makes (0x452EA0..0x452EB3: [[[0C66244h]+74h]+2Ch], vtable
// +34h with 2). The ring is a model of the table the tactics parser uses (0x58F68F, 0x58E506), hung on the unit as
// the stock aura update does. A world tick every 100 ms compares the local selection (0x453B28: IDs [group+10h],
// count [group+14h]) and the Alt state with the rings the units hold. Display only: a model is a visual of the unit,
// the selection and the keyboard are this machine's, and nothing here reaches the simulation.
//
// Placement: while a building is being placed, its ghost shows the rings of its proto's ranged attacks (every tactic's,
// from the local player's copy) or its <DisplayedRange>, with no tag needed (option noPlacement turns it off). The
// shared ghost update (ghostobservers.h, 0x96E4E7) hangs them on the ghost's model [[[0xC67300]+200h]+34h], of a unit
// visual's class, through the stock model functions, which read only a unit's visual (unitmodels.h); a new proto or a
// new model starts again, and the model takes its rings with it when the placement ends.
//
// Player colour: the rings are aoe3-blender-tools' range meshes (make_rings.py), whose texture marks player colour as a
// unit's does; the engine tints a model hung on a unit with the unit's owner's colour, and on the ghost with the local
// player's. The line needs nothing from here.
//
// Each ring has a fill, a transparent disc under its line graded from clear at the centre to the owner's colour at the
// edge (effects\uhc_rings\rangefill_<N>_p<player>.xml). The game's alphablend shader has no player colour, so there is
// one disc per player ID (0 to 8) and this key picks the owner's; the placement ghost gets no fill (a ghost that cannot
// be placed is tinted, and the tint draws the disc opaque). An attack that
// reaches no unit on land gets a dashed ring with no fill instead (range_<N>_ships.xml): only ships (each type of its
// <Rate> list is Ship or a type whose every proto is a Ship, such as AbstractWarShip), or only structures (each type's
// protos are Buildings or Ships, such as a torch's LogicalTypeShipsAndBuildings). A structures-only attack is left out
// when the unit has an attack on land units (the Grenzer's 6 m torch beside its musket). Two attacks on one ring size
// share it, filled if either reaches land units. The caps count models: a filled ring is two.
//
// <Flag>: the proto flag parser 0x5F640A (stdcall(proto, name)) compares the name with each flag it knows and
// returns with nothing for any other name. Its last compare, the call 0x5F726F of the string compare 0x4028B4, is
// redirected: the compare runs, and a name it does not match is offered to this key.
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../ghostobservers.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../unitmodels.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
void UhcProtoFlagCompareHook();
std::uint32_t g_uhcStringCompare = 0x004028B4;
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kUiGlobal = 0x00C67300;     // the placement ghost: +1FCh the proto ID, +200h its visual
constexpr std::uint32_t kInputGlobal = 0x00C66244;  // [[+74h]+2Ch]: the object the Alt query asks
constexpr std::uint32_t kTickMs = 100;
constexpr std::uint32_t kRangedFlag = 0x0A;  // <RangedLogic> (0x5FAC6D), the bit the stat panel tests for a range
// Measured (perfprobe, 2026-11-21, 50 selected units on screen, render time a frame): 100 rings 6.6 ms against 6.0
// with the key off, 200 rings 8.0 against 7.6, inside the noise of the runs (0.6 ms). The caps keep a big selection
// readable: at most 4 rings a unit and 60 models in all (a filled ring is two: its line and its fill), the units with
// the longest ranges first.
constexpr std::size_t kMaxRingsPerUnit = 4;
constexpr std::size_t kMaxRings = 60;
// The sizes aoe3-blender-tools' make_rings.py writes (RANGES): every metre from 4 to 50, then 55 to 100.
constexpr std::int32_t kRadii[] = {4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
                                   23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41,
                                   42, 43, 44, 45, 46, 47, 48, 49, 50, 55, 60, 65, 70, 80, 90, 100};
// How the game measures an attack's reach (the action's range test 0x48B6AA..0x48B779 compares the unit distance,
// unit vtable +0BCh -> +0B4h 0x487B81, with the action's MaxRange [action+24h]):
//   - attacker and target that can move (0x45EE55): centre distance - each one's radius x sqrt(2) (0x4889AF; the
//     radius is the larger of its proto's obstruction radii, 0x48272C);
//   - a building (cannot move) on a unit: the unit's centre to the building's obstruction rectangle, minus the unit's
//     radius x sqrt(2) (0x4945FE, 0x485E26);
//   - a unit on a building: its centre to the building's rectangle minus its own radius x sqrt(2) (0x4882FE).
// So a ring is drawn where an infantry unit's centre (radius 0.49 m, the common one) comes into range: MaxRange +
// 0.49 x sqrt(2), plus the attacker's own radius x sqrt(2) for a unit that moves, or the half side of a building's
// rectangle (the smaller one). Measured in game, 2026-11-24 (a mod's Fort, MaxRange 26, rectangle 12 x 12 m; Settlers,
// radius 0.49): Settlers whose centre was 26.08, 26.31 and 26.68 m from the rectangle were shot, 26.83, 26.9 and
// 27.2 m were not (the limit 26 + 0.69). Past a corner the zone reaches further than the ring (2.5 m for the Fort).
constexpr float kSqrt2 = 1.41421356f;
constexpr float kTargetRadius = 0.49f;  // an infantry unit's obstruction radius (Musketeer, Settler, Grenzer)

using SelectionFn = const char*(__cdecl*)();
using UnitByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);
using RangeFn = float(__thiscall*)(const char* action, std::int32_t key);
using KeyQueryFn = bool(__thiscall*)(void* input, std::int32_t key);
using PlayerByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);
using PlayerProtoFn = const char*(__thiscall*)(const char* player, std::int32_t id);
using IsAFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);

const auto kSelection = reinterpret_cast<SelectionFn>(0x00453B28);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kRange = reinterpret_cast<RangeFn>(0x004946D6);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kIsA = reinterpret_cast<IsAFn>(0x0044D7FA);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
constexpr std::int32_t kFillPlayers = 9;  // rangefill_<N>_p0 .. p8 (make_rings.py, RANGE_FILL_PLAYERS)

struct Range {
  bool show = false;    // <DisplayRange>
  bool always = false;  // <AlwaysDisplayRange>
  std::vector<float> fixed;  // <DisplayedRange>, each
};

std::unordered_map<std::int32_t, Range> g_protos;  // by proto ID; the load fills it
std::map<std::wstring, std::int32_t> g_models;     // by file
// What an attack reaches: land units (a filled ring), only ships, or only structures (buildings, or buildings and ships).
enum class Reach { kLand, kShips, kStructures };
std::unordered_map<std::int32_t, Reach> g_typeReach;  // by unittype ID
std::int32_t g_shipType = -2;                         // the unittype Ship; -2 until looked up
std::int32_t g_buildingType = -1;                     // the unittype Building
std::int32_t g_unitType = -1;                         // the unittype Unit
std::map<std::int32_t, std::vector<std::int32_t>> g_hung;  // by unit ID: the models on it
std::int32_t g_bone = -2;
const char* g_world = nullptr;
std::uint32_t g_nextTick = 0;
bool g_lastAlt = false;
bool g_log = false;
bool g_placement = true;      // the ghost's rings (option noPlacement: off)

struct Ghost {
  char* visual = nullptr;
  std::int32_t proto = -2;
  std::vector<std::int32_t> models;  // what the observer hung on this visual
};
Ghost g_ghost;
int g_logLines = 0;
constexpr int kMaxLogLines = 200;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

bool Bit(const char* object, std::uint32_t offset, std::uint32_t bit) {
  if (Field<std::uint32_t>(object, offset + 4) <= bit) {
    return false;
  }
  const auto* bytes = Field<const std::uint8_t*>(object, offset);
  return bytes != nullptr && (bytes[bit >> 3] & (1u << (bit & 7))) != 0;
}

const wchar_t* NodeText(const char* node) { return *reinterpret_cast<const wchar_t* const*>(node + 0x14); }

bool On(const wchar_t* text) { return text == nullptr || text[0] == L'\0' || _wtoi(text) != 0; }

bool __cdecl ReadShow(void*, const char* node, char* proto) {
  g_protos[Field<std::int32_t>(proto, 0x04)].show = On(NodeText(node));
  return true;
}

bool __cdecl ReadAlways(void*, const char* node, char* proto) {
  g_protos[Field<std::int32_t>(proto, 0x04)].always = On(NodeText(node));
  return true;
}

bool __cdecl ReadMetres(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  const float metres = text == nullptr ? 0.0f : std::wcstof(text, nullptr);
  if (metres > 0.0f) {
    g_protos[Field<std::int32_t>(proto, 0x04)].fixed.push_back(metres);
  } else {
    uhc::Log(L"displayedRange: proto %d: <DisplayedRange> needs a number above 0, ignored", Field<std::int32_t>(proto, 0x04));
  }
  return true;
}

void NewDatabase(char*) {
  g_protos.clear();
  g_models.clear();
  g_typeReach.clear();
  g_shipType = -2;
  g_buildingType = -1;
  g_unitType = -1;
  g_hung.clear();
  g_bone = -2;
  g_logLines = 0;
  g_ghost = Ghost{};
}

bool AltHeld() {
  const char* root = *reinterpret_cast<const char* const*>(kInputGlobal);
  const char* inner = root == nullptr ? nullptr : Field<const char*>(root, 0x74);
  char* input = inner == nullptr ? nullptr : Field<char*>(inner, 0x2C);
  if (input == nullptr || Field<const void*>(input, 0) == nullptr) {
    return false;
  }
  const auto query = Field<KeyQueryFn>(Field<const char*>(input, 0), 0x34);
  return query(input, 2);
}

std::int32_t RingRadius(float metres) {
  std::int32_t radius = kRadii[0];
  for (const std::int32_t candidate : kRadii) {
    if (std::abs(static_cast<float>(candidate) - metres) < std::abs(static_cast<float>(radius) - metres)) {
      radius = candidate;
    }
  }
  return radius;
}

// The model of a file of effects\uhc_rings: range_<N>.xml (a line), range_<N>_ships.xml (dashed), rangefill_<N>_p<k>.xml.
std::int32_t ModelOf(const wchar_t* path) {
  const auto found = g_models.find(path);
  if (found != g_models.end()) {
    return found->second;
  }
  const std::int32_t model = uhc::ModelOfPath(path);
  if (g_log) {
    uhc::Log(L"displayedRange: %ls is model %d", path, model);
  }
  if (model != -1) {  // -1: the table does not exist yet
    g_models[path] = model;
  }
  return model;
}

struct Ring {
  std::int32_t radius;
  bool dashed;  // no attack on this ring reaches a unit on land: only ships, or only buildings
};

// The models of one ring for an owner: its line (dashed when it reaches no land unit) and, unless dashed, the owner's
// fill.
std::vector<std::int32_t> RingModels(const Ring& ring, std::int32_t player) {
  std::vector<std::int32_t> models;
  wchar_t path[80];
  swprintf_s(path, ring.dashed ? L"effects\\uhc_rings\\range_%d_ships.xml" : L"effects\\uhc_rings\\range_%d.xml",
             ring.radius);
  const std::int32_t line = ModelOf(path);
  if (line == -1) {
    return models;
  }
  models.push_back(line);
  if (!ring.dashed && player >= 0 && player < kFillPlayers) {
    swprintf_s(path, L"effects\\uhc_rings\\rangefill_%d_p%d.xml", ring.radius, player);
    const std::int32_t fill = ModelOf(path);
    if (fill != -1) {
      models.push_back(fill);
    }
  }
  return models;
}

const char* Database() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

std::int32_t TypeId(const char* database, const char* name) {
  const char* table = database + 0x190;
  std::int32_t id = -1;
  return kNameFind(table, name, kNameBucket(table, name), &id) ? id : -1;
}

// What the protos of unittype `type` are: kLand when one of them is a Unit that is neither a Ship nor a Building (a unit
// on land), kShips when there are some and every one is a Ship (Ship itself, AbstractWarShip, a ship's proto), else
// kStructures (buildings, or buildings and ships: LogicalTypeShipsAndBuildings). "A Unit" matters: a mod's helper
// objects (an aura's carrier, a packed wagon) can carry LogicalTypeShipsAndBuildings without being Buildings. The protos
// of the database [db+54h] (count +58h), tested by the is-a test 0x44D7FA; the name table [db+190h] gives the IDs of
// Ship, Building and Unit. Each type is worked out once per database.
Reach TypeReach(std::int32_t type) {
  const char* database = Database();
  if (database == nullptr || type < 0) {
    return Reach::kLand;
  }
  if (g_shipType == -2) {
    g_shipType = TypeId(database, "Ship");
    g_buildingType = TypeId(database, "Building");
    g_unitType = TypeId(database, "Unit");
    if (g_log) {
      uhc::Log(L"displayedRange: unittype Ship is %d, Building %d, Unit %d", g_shipType, g_buildingType, g_unitType);
    }
  }
  const auto found = g_typeReach.find(type);
  if (found != g_typeReach.end()) {
    return found->second;
  }
  const auto* protos = Field<const char* const*>(database, 0x54);
  const std::int32_t count = Field<std::int32_t>(database, 0x58);
  bool any = false;
  bool land = false;
  bool ships = true;
  for (std::int32_t i = 0; protos != nullptr && i < count && !land; ++i) {
    const char* proto = protos[i];
    if (proto == nullptr || !kIsA(proto, type)) {
      continue;
    }
    any = true;
    const bool ship = g_shipType >= 0 && kIsA(proto, g_shipType);
    const bool building = g_buildingType >= 0 && kIsA(proto, g_buildingType);
    land = !ship && !building && g_unitType >= 0 && kIsA(proto, g_unitType);
    ships = ships && ship;
  }
  const Reach reach = !any || land ? Reach::kLand : ships ? Reach::kShips : Reach::kStructures;
  g_typeReach[type] = reach;
  return reach;
}

// What an attack reaches, from its <Rate> list ([action+0Ch], count +10h, 0Ch-byte entries, +0 the unittype): land
// units when one of its types has them (or the list is empty), ships when every type is a ship type, else structures.
Reach AttackReach(const char* action) {
  const char* rates = Field<const char*>(action, 0x0C);
  const std::int32_t count = Field<std::int32_t>(action, 0x10);
  if (rates == nullptr || count <= 0) {
    return Reach::kLand;
  }
  bool ships = true;
  for (std::int32_t i = 0; i < count; ++i) {
    const Reach reach = TypeReach(Field<std::int32_t>(rates, 12 * i));
    if (reach == Reach::kLand) {
      return Reach::kLand;
    }
    ships = ships && reach == Reach::kShips;
  }
  return ships ? Reach::kShips : Reach::kStructures;
}

// The proto's own share of an attack's reach, as the unit distance counts it: a unit that moves, its radius x sqrt(2)
// (the larger obstruction radius, [proto+88h] / [proto+8Ch], 0x48272C); a building, the half side of its rectangle
// (the smaller of the two, so that the ring stays inside the zone on every side). Can move is 0x45EE55: not when the
// first flag byte has bit 4 ([[proto+50h]], with [proto+54h] > 4), else when [proto+80h] is above 1e-6.
float OwnReach(const char* proto) {
  const float x = Field<float>(proto, 0x88);
  const float z = Field<float>(proto, 0x8C);
  const auto* flags = Field<const std::uint8_t*>(proto, 0x50);
  const bool fixed = Field<std::uint32_t>(proto, 0x54) > 4 && flags != nullptr && (flags[0] & 0x10) != 0;
  const bool moves = !fixed && Field<float>(proto, 0x80) > 1e-6f;
  return moves ? std::max(x, z) * kSqrt2 : std::min(x, z);
}

struct Attack {
  float metres;  // where an infantry unit's centre comes into range, or a building's wall for a structures-only attack
  Reach reach;
};

// The ranged attacks of one tactic, as the attack list 0x487EEE reads them: 12-byte entries at [tactic+44h] (count
// +48h), +4 the index of the action in the set [tactic+0] (actions [set+1Ch], count +20h); an action counts when it is
// active (bit 0 of [action+64h]), has the ranged flag and a range entry. `own` is the attacker's share (OwnReach).
void TacticAttacks(const char* tactic, float own, std::vector<Attack>& attacks) {
  const char* owner = Field<const char*>(tactic, 0x00);
  const char* entries = Field<const char*>(tactic, 0x44);
  const std::int32_t count = Field<std::int32_t>(tactic, 0x48);
  const auto* actions = owner == nullptr ? nullptr : Field<const char* const*>(owner, 0x1C);
  const std::int32_t actionCount = owner == nullptr ? 0 : Field<std::int32_t>(owner, 0x20);
  for (std::int32_t i = 0; i < count && entries != nullptr && actions != nullptr; ++i) {
    const std::int32_t which = Field<std::int32_t>(entries, 12 * i + 4);
    if (which < 0 || which >= actionCount) {
      continue;
    }
    const char* action = actions[which];
    if (action == nullptr || !Bit(action, 0x64, 0) || !Bit(action, 0x64, kRangedFlag) ||
        Field<std::int32_t>(action, 0x1C) <= 0) {
      continue;
    }
    const float range = kRange(action, -1);
    if (range > 0.5f) {
      const Reach reach = AttackReach(action);
      // On a building the distance runs to its wall, with no radius of the target's.
      attacks.push_back({range + own + (reach == Reach::kStructures ? 0.0f : kTargetRadius * kSqrt2), reach});
    }
  }
}

// Largest first, each size once (filled if any of its attacks reaches land units), at most kMaxRingsPerUnit. An attack
// that reaches only structures (a torch on buildings and ships) is left out when another attack reaches land units:
// its ring would read as a range on your army. Alone (a mortar) it gets its dashed ring.
std::vector<Ring> Rings(const std::vector<Attack>& attacks) {
  const bool land =
      std::any_of(attacks.begin(), attacks.end(), [](const Attack& a) { return a.reach == Reach::kLand; });
  std::vector<Ring> radii;
  for (const Attack& attack : attacks) {
    if (!(land && attack.reach == Reach::kStructures)) {
      radii.push_back({RingRadius(attack.metres), attack.reach != Reach::kLand});
    }
  }
  std::sort(radii.begin(), radii.end(), [](const Ring& a, const Ring& b) {
    return a.radius != b.radius ? a.radius > b.radius : a.dashed < b.dashed;
  });
  radii.erase(std::unique(radii.begin(), radii.end(), [](const Ring& a, const Ring& b) { return a.radius == b.radius; }),
              radii.end());
  if (radii.size() > kMaxRingsPerUnit) {
    radii.resize(kMaxRingsPerUnit);
  }
  return radii;
}

// <DisplayedRange>: radii from the unit's centre, as written.
std::vector<Ring> FixedRings(const Range& range) {
  std::vector<Attack> attacks;
  for (const float metres : range.fixed) {
    attacks.push_back({metres, Reach::kLand});
  }
  return Rings(attacks);
}

// The rings the unit wants, largest first, at most kMaxRingsPerUnit: the fixed <DisplayedRange> values, or the ranged
// attacks of its current tactic ([mgr+0A8h], an index into the player's proto's tactics [[proto+44h]+10h], count
// +14h); a tactic with none (an artillery piece limbered to move) takes those of all its tactics, the attacks it
// unlimbers to.
std::vector<Ring> WantedRadii(const char* unit, const Range& range) {
  if (!range.fixed.empty()) {
    return FixedRings(range);
  }
  std::vector<Attack> attacks;
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* manager = Field<const char*>(unit, 0x58);
  const char* set = proto == nullptr ? nullptr : Field<const char*>(proto, 0x44);
  const auto* tactics = set == nullptr ? nullptr : Field<const char* const*>(set, 0x10);
  const std::int32_t count = set == nullptr ? 0 : Field<std::int32_t>(set, 0x14);
  if (manager != nullptr && tactics != nullptr) {
    const float own = OwnReach(proto);
    const std::int32_t index = Field<std::int32_t>(manager, 0xA8);
    if (index >= 0 && index < count && tactics[index] != nullptr) {
      TacticAttacks(tactics[index], own, attacks);
    }
    for (std::int32_t i = 0; attacks.empty() && i < count; ++i) {
      if (tactics[i] != nullptr) {
        TacticAttacks(tactics[i], own, attacks);
      }
    }
  }
  return Rings(attacks);
}

// The rings of a proto with no unit (the placement ghost): its <DisplayedRange> values, or the ranged attacks of every
// tactic of the player's copy (a building has no current tactic before it stands).
std::vector<Ring> ProtoRadii(const char* proto, const Range* range) {
  if (range != nullptr && !range->fixed.empty()) {
    return FixedRings(*range);
  }
  std::vector<Attack> attacks;
  const char* set = Field<const char*>(proto, 0x44);
  const auto* tactics = set == nullptr ? nullptr : Field<const char* const*>(set, 0x10);
  const std::int32_t count = set == nullptr ? 0 : Field<std::int32_t>(set, 0x14);
  const float own = OwnReach(proto);
  for (std::int32_t i = 0; tactics != nullptr && i < count; ++i) {
    if (tactics[i] != nullptr) {
      TacticAttacks(tactics[i], own, attacks);
    }
  }
  return Rings(attacks);
}

void Release(const char* world, std::int32_t id, const std::vector<std::int32_t>& models) {
  if (char* unit = const_cast<char*>(kUnitById(world, id))) {
    for (const std::int32_t model : models) {
      uhc::RemoveUnitModel(unit, model);
    }
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"displayedRange: rings off unit %d", id);
  }
}

struct Want {
  std::int32_t id;
  char* unit;
  std::vector<std::int32_t> models;
  std::vector<Ring> rings;  // each model's ring
  std::vector<bool> fills;  // each model: the ring's fill
  std::int32_t largest;
};

void Tick(char* world, std::int32_t) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  if (game == nullptr || world != Field<const char*>(game, 0x13C)) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_world || now < g_nextTick - kTickMs) {
    g_hung.clear();  // another game: its unit IDs are not these
    g_world = world;
    g_nextTick = 0;
  }
  if (now < g_nextTick) {
    return;
  }
  g_nextTick = now + kTickMs;
  const bool alt = AltHeld();
  if (g_log && alt != g_lastAlt && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"displayedRange: Alt %ls", alt ? L"held" : L"released");
  }
  g_lastAlt = alt;

  std::vector<Want> wants;
  const char* selection = kSelection();
  const std::int32_t count = selection == nullptr ? 0 : Field<std::int32_t>(selection, 0x14);
  const auto* ids = selection == nullptr ? nullptr : Field<const std::int32_t*>(selection, 0x10);
  for (std::int32_t i = 0; i < count && ids != nullptr; ++i) {
    char* unit = const_cast<char*>(kUnitById(world, ids[i]));
    const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    if (proto == nullptr) {
      continue;
    }
    const auto found = g_protos.find(Field<std::int32_t>(proto, 0x04));
    if (found == g_protos.end() || !(found->second.always || (found->second.show && alt))) {
      continue;
    }
    Want want{ids[i], unit, {}, {}, {}, 0};
    const char* owner = Field<const char*>(unit, 0x44);
    const std::int32_t player = owner == nullptr ? -1 : Field<std::int32_t>(owner, 0);
    for (const Ring& ring : WantedRadii(unit, found->second)) {
      const std::vector<std::int32_t> models = RingModels(ring, player);
      for (std::size_t k = 0; k < models.size(); ++k) {
        want.models.push_back(models[k]);
        want.rings.push_back(ring);
        want.fills.push_back(k > 0);
        want.largest = std::max(want.largest, ring.radius);
      }
    }
    if (!want.models.empty()) {
      wants.push_back(std::move(want));
    }
  }
  std::stable_sort(wants.begin(), wants.end(), [](const Want& a, const Want& b) { return a.largest > b.largest; });
  std::size_t budget = kMaxRings;
  for (Want& want : wants) {  // each unit's rings are largest first
    const std::size_t keep = std::min(budget, want.models.size());
    want.models.resize(keep);
    want.rings.resize(keep);
    want.fills.resize(keep);
    budget -= keep;
  }
  std::erase_if(wants, [](const Want& want) { return want.models.empty(); });

  std::map<std::int32_t, const Want*> byId;
  for (const Want& want : wants) {
    byId[want.id] = &want;
  }
  for (auto it = g_hung.begin(); it != g_hung.end();) {
    const auto wanted = byId.find(it->first);
    if (wanted == byId.end()) {
      Release(world, it->first, it->second);
      it = g_hung.erase(it);
      continue;
    }
    // Rings the unit no longer wants (a tactic or a tech changed its attacks).
    std::vector<std::int32_t> keep;
    char* unit = wanted->second->unit;
    for (const std::int32_t model : it->second) {
      if (std::find(wanted->second->models.begin(), wanted->second->models.end(), model) !=
          wanted->second->models.end()) {
        keep.push_back(model);
      } else {
        uhc::RemoveUnitModel(unit, model);
      }
    }
    it->second = std::move(keep);
    ++it;
  }
  if (g_bone == -2 && !wants.empty()) {
    g_bone = uhc::NoBone();
  }
  for (const Want& want : wants) {
    std::vector<std::int32_t>& hung = g_hung[want.id];
    for (std::size_t k = 0; k < want.models.size(); ++k) {
      const std::int32_t model = want.models[k];
      if (std::find(hung.begin(), hung.end(), model) != hung.end()) {
        continue;
      }
      const uhc::ModelHang hang = uhc::HangUnitModel(want.unit, model, g_bone);
      if (hang == uhc::ModelHang::kHung || hang == uhc::ModelHang::kNotInGame) {
        hung.push_back(model);
        if (g_log && g_logLines < kMaxLogLines) {
          ++g_logLines;
          uhc::Log(L"displayedRange: %ls of %d m on unit %d (%hs)%ls%ls", want.fills[k] ? L"fill" : L"ring",
                   want.rings[k].radius, want.id, Field<const char*>(Field<const char*>(want.unit, 0x5C), 0x10),
                   want.rings[k].dashed ? L", no land unit (dashed)" : L"", alt ? L", Alt held" : L"");
        }
      }
    }
  }
}

// From the shared ghost update (ghostobservers.h), each frame while a building is placed: the rings of its proto on
// the ghost's model. The ghost object [[0xC67300]+200h] holds its transform; the model drawn is [ghost+34h], an object
// of the class of a unit's visual [unit+60h] (in game both start with the same word, and the ghost's code calls three
// of that class's functions on it: 0x40431B, 0xA3FEF8, 0xADA24B), so the stock model functions take it.
void __stdcall OnGhost(char* ghost) {
  const char* ui = *reinterpret_cast<const char* const*>(kUiGlobal);
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  if (ui == nullptr || game == nullptr || ghost == nullptr || Field<char*>(ui, 0x200) != ghost) {
    return;
  }
  char* visual = Field<char*>(ghost, 0x34);
  if (visual == nullptr || Field<const char*>(visual, 0xA8) == nullptr) {  // the model functions read its +0A8h
    return;
  }
  const std::int32_t protoId = Field<std::int32_t>(ui, 0x1FC);
  if (visual != g_ghost.visual) {
    g_ghost = Ghost{visual};  // another visual: what was hung on the old one went with it
  }
  if (protoId != g_ghost.proto) {
    for (const std::int32_t model : g_ghost.models) {
      uhc::RemoveVisualModel(visual, model);
    }
    g_ghost.models.clear();
    g_ghost.proto = protoId;
    const char* world = Field<const char*>(game, 0x13C);
    const std::int32_t playerId = Field<std::int32_t>(game, 0x3C0);
    const char* player = world == nullptr || protoId < 0 ? nullptr : kPlayerById(world, playerId);
    const char* proto = player == nullptr ? nullptr : kPlayerProto(player, protoId);
    if (proto != nullptr) {
      const auto found = g_protos.find(Field<std::int32_t>(proto, 0x04));
      for (const Ring& ring : ProtoRadii(proto, found == g_protos.end() ? nullptr : &found->second)) {
        // No fill on the ghost: a ghost that cannot be placed is drawn with the game's tint, and the alphablend
        // shader's tint technique draws the disc opaque (seen in game, 2026-11-23, a Fort's ghost).
        const std::vector<std::int32_t> models = RingModels(ring, -1);
        g_ghost.models.insert(g_ghost.models.end(), models.begin(), models.end());
        if (!models.empty() && g_log && g_logLines < kMaxLogLines) {
          ++g_logLines;
          uhc::Log(L"displayedRange: ring of %d m on the placement ghost (%hs)%ls", ring.radius,
                   Field<const char*>(proto, 0x10),
                   ring.dashed ? L", no land unit (dashed)" : L"");
        }
      }
    }
  }
  if (g_ghost.models.empty()) {
    return;
  }
  if (g_bone == -2) {
    g_bone = uhc::NoBone();
  }
  for (const std::int32_t model : g_ghost.models) {
    if (!uhc::VisualHasModel(visual, model)) {
      uhc::HangVisualModel(visual, model, g_bone);
    }
  }
}

}  // namespace

extern "C" {

// From the flag parser's last compare: a name no stock flag matched.
void __stdcall UhcUnknownProtoFlag(const char* proto, const char* name) {
  if (proto == nullptr || name == nullptr || _stricmp(name, "AlwaysDisplayRange") != 0) {
    return;
  }
  g_protos[Field<std::int32_t>(proto, 0x04)].always = true;
  if (g_log) {
    uhc::Log(L"displayedRange: proto %hs: <Flag>AlwaysDisplayRange</Flag>", Field<const char*>(proto, 0x10));
  }
}
}

namespace uhc {

Outcome ApplyDisplayedRange(const Config& config) {
  const Config::Args* args = config.First("displayedRange");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "noPlacement") == 0) {
      g_placement = false;
    } else {
      Log(L"displayedRange: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("displayedRange", {&sites::kCurrentSelectionGroup, &sites::kUnitById, &sites::kAltQuery,
                                    &sites::kActionRangeByKey, &sites::kProtoFlagLastCompare, &sites::kPlayerById,
                                    &sites::kPlayerProtoEntry, &sites::kIsA}) ||
      (g_placement && !AddGhostObserver(&OnGhost)) ||
      !VerifyUnitModels("displayedRange") || !AddProtoTagHandler("DisplayRange", &ReadShow) ||
      !AddProtoTagHandler("DisplayedRange", &ReadMetres) || !AddProtoTagHandler("AlwaysDisplayRange", &ReadAlways) ||
      !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&Tick) ||
      !WriteCall(sites::kProtoFlagLastCompare.va + 6, reinterpret_cast<const void*>(&UhcProtoFlagCompareHook))) {
    return Outcome::kFailed;
  }
  Log(L"displayedRange: rings while Alt is held (<DisplayRange>) or always (<AlwaysDisplayRange>), one per ranged "
      L"attack or <DisplayedRange>%ls", g_placement ? L"; on the placement ghost of a ranged building" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

## workRateByAbstractType

Contract: [workRateByAbstractType](../porting-to-another-dll.md#workratebyabstracttype).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `IsA` `0x44D7FA` (105 B), `ProtoById` `0x45316E` (30 B), `ActionById` `0x48D22E` (16 B), `ActionRateGet` `0x49EBB3` (16 B), `ActionRateSet` `0x5FA2FC` (16 B), `EffectValueApply` `0x7F892A` (16 B), `WorkRateApplyCase` `0x8F987C` (11 B), `WorkRateUnapplyCase` `0x8FB11A` (11 B).

### src/features/workratetype.cpp

```cpp
// workRateByAbstractType: a WorkRate effect on a listed abstract type also reaches the rates a
// unit has for the protos of that type.
//
// Stock: an action's rates are a list of {unittype ID, rate} ([action+0Ch], count [action+10h],
// 0Ch bytes each). The lookup 0x487C45 takes the rate of the target's own proto if the list has it,
// else the first abstract type the target carries. A WorkRate effect (Data subtype 3, case 0x8F987C
// of applyData, 0x8FB11A of unapplyData) changes the one entry it names. So a Settler, which has
// rates for both AbstractMine and Plantation, gets no mining bonus on a Plantation, although the
// Plantation carries AbstractMine.
//
// With the key, when such an effect names a listed type, the same change is made to every entry of
// that action whose key is a proto of the type: same relativity, same amount, the base value from
// the base proto, through the stock value function and setter. A unit with no entry for a proto is
// left alone: it already reads the abstract rate. The stock code then runs unchanged.
//
// A tech with one effect on AbstractMine and one on Plantation therefore counts twice on the
// Plantation while the Plantation carries the type. The hooks are in hooks/workratetype_hooks.asm.
#include <cstdint>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
void UhcWorkRateApplyHook();
void UhcWorkRateUnapplyHook();
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
constexpr std::size_t kMaxTypes = 8;
constexpr int kMaxLogLines = 2000;

using ActionByIdFn = const char*(__thiscall*)(const char* actions, std::int32_t id);
using RateGetFn = float(__thiscall*)(const char* action, std::int32_t key);
using RateSetFn = void(__thiscall*)(const char* action, std::int32_t key, float rate);
using EffectValueFn = void(__cdecl*)(std::uint32_t relativity, float* target, float base, float amount,
                                     std::uint32_t unapply);
using ProtoByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);

const auto kActionById = reinterpret_cast<ActionByIdFn>(0x0048D22E);
const auto kRateGet = reinterpret_cast<RateGetFn>(0x0049EBB3);
const auto kRateSet = reinterpret_cast<RateSetFn>(0x005FA2FC);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
const auto kProtoById = reinterpret_cast<ProtoByIdFn>(0x0045316E);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

struct TypeRule {
  std::string name;
  std::int32_t id = -1;              // filled on each database load
  std::vector<std::int32_t> protos;  // the protos of the type, in ID order
  bool built = false;
};

TypeRule g_rules[kMaxTypes];
std::size_t g_ruleCount = 0;
bool g_log = false;
std::string g_logProto;  // "log=<Proto>": only this unit's rates; a line per rate is slow with many units
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* Database() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

void NewDatabase(char*) {
  for (std::size_t i = 0; i < g_ruleCount; ++i) {
    g_rules[i].protos.clear();
    g_rules[i].built = false;
  }
  g_logLines = 0;
}

// Built at the first effect after a load: the protos' types are not read yet when the database load
// callback runs.
void Build(TypeRule& rule) {
  const char* database = Database();
  if (database == nullptr) {
    return;
  }
  rule.built = true;
  const std::int32_t count = Field<std::int32_t>(database, 0x19B0);
  if (rule.id < count) {
    uhc::Log(L"workRateByAbstractType: %hs is a proto, not an abstract type: ignored", rule.name.c_str());
    return;
  }
  for (std::int32_t id = 0; id < count; ++id) {
    const char* proto = kProtoById(database, id);
    if (proto != nullptr && kProtoIsType(proto, rule.id)) {
      rule.protos.push_back(id);
    }
  }
  uhc::Log(L"workRateByAbstractType: %hs has %u protos", rule.name.c_str(),
           static_cast<unsigned>(rule.protos.size()));
}

}  // namespace

// From the WorkRate case of applyData and unapplyData, before the stock change. `relativity` is a
// byte in a pushed dword (0x7F86E4). The stock case does nothing without both action sets or the
// target's action, and this does the same.
extern "C" void __stdcall UhcWorkRateByType(const char* proto, const char* baseProto, std::int32_t actionId,
                                            std::int32_t key, float amount, std::uint32_t relativity,
                                            std::uint32_t unapply) {
  TypeRule* rule = nullptr;
  for (std::size_t i = 0; i < g_ruleCount; ++i) {
    if (g_rules[i].id == key) {
      rule = &g_rules[i];
      break;
    }
  }
  if (rule == nullptr) {
    return;
  }
  const char* actions = Field<const char*>(proto, 0x44);
  const char* baseActions = Field<const char*>(baseProto, 0x44);
  if (actions == nullptr || baseActions == nullptr) {
    return;
  }
  const char* action = kActionById(actions, actionId);
  if (action == nullptr) {
    return;
  }
  if (!rule->built) {
    Build(*rule);
  }
  const char* baseAction = kActionById(baseActions, actionId);
  for (const std::int32_t target : rule->protos) {
    float rate = kRateGet(action, target);
    if (rate <= 0.0f) {
      continue;  // no entry of its own: this unit reads the abstract rate
    }
    const float before = rate;
    const float base = baseAction != nullptr ? kRateGet(baseAction, target) : 1.0f;
    kEffectValue(relativity & 0xFF, &rate, base, amount, unapply);
    kRateSet(action, target, rate);
    if (g_log && g_logLines < kMaxLogLines && (g_logProto.empty() || _stricmp(g_logProto.c_str(), ProtoName(proto)) == 0)) {
      ++g_logLines;
      uhc::Log(L"workRateByAbstractType: %hs, rate for %hs (through %hs): %.3f -> %.3f%ls", ProtoName(proto),
               ProtoName(kProtoById(Database(), target)), rule->name.c_str(), static_cast<double>(before),
               static_cast<double>(rate), unapply != 0 ? L" (effect removed)" : L"");
      if (g_logLines == kMaxLogLines) {
        uhc::Log(L"workRateByAbstractType: log limit reached");
      }
    }
  }
}

namespace uhc {

Outcome ApplyWorkRateByAbstractType(const Config& config) {
  const Config::Args* args = config.First("workRateByAbstractType");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }

  std::vector<std::string> names;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (_strnicmp(arg.c_str(), "log=", 4) == 0) {
      if (arg.size() == 4) {
        Log(L"workRateByAbstractType: log= needs a proto; feature not applied");
        return Outcome::kFailed;
      }
      log = true;
      g_logProto = arg.substr(4);
    } else if (names.size() == kMaxTypes) {
      Log(L"workRateByAbstractType: more than %u types; feature not applied", static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      names.push_back(arg);
    }
  }
  if (names.empty()) {
    names.push_back("AbstractMine");
  }

  if (!VerifyAll("workRateByAbstractType",
                 {&sites::kWorkRateApplyCase, &sites::kWorkRateUnapplyCase, &sites::kActionById,
                  &sites::kActionRateGet, &sites::kActionRateSet, &sites::kEffectValueApply, &sites::kProtoById, &sites::kIsA})) {
    return Outcome::kFailed;
  }
  std::string list;
  for (const std::string& name : names) {
    TypeRule& rule = g_rules[g_ruleCount++];
    rule.name = name;
    if (!RequestAbstractUnitType(rule.name.c_str(), &rule.id)) {
      return Outcome::kFailed;
    }
    list += (list.empty() ? "" : " ") + name;
  }
  if (!OnDatabaseLoad(&NewDatabase)) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!WriteJmp(sites::kWorkRateApplyCase.va, reinterpret_cast<const void*>(&UhcWorkRateApplyHook), 5) ||
      !WriteJmp(sites::kWorkRateUnapplyCase.va, reinterpret_cast<const void*>(&UhcWorkRateUnapplyHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"workRateByAbstractType: WorkRate effects on %hs also change the rates units have for the protos of "
      L"those types%ls (multiplayer unverified)",
      list.c_str(), log ? L", each change logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/workratetype_hooks.asm

```asm
; Hooks for workRateByAbstractType. Entered through a jmp written over the stock code; each leaves
; through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Action rates").
.686
.model flat, c
option casemap :none

include common.inc

UhcWorkRateByType PROTO STDCALL target:DWORD, base:DWORD, actionId:DWORD, key:DWORD, amount:DWORD, relativity:DWORD, unapply:DWORD

.data
applyNext   dd 008F9881h    ; je 8FAEF4h: the rest of the stock WorkRate case of applyData
unapplyNext dd 008FB11Fh    ; je 8FC19Ah: the same in unapplyData

.code

; Replaces 0x8F987C..0x8F9880 (mov edi,[edi+44h] / cmp edi,ebp), the head of case 3 (WorkRate) of
; applyData FUN_008F973F. EDI = target proto, ESI = its base proto, EBP = 0, FPU stack empty.
; Frame: action [esp+20h], rate key [esp+24h], amount [esp+28h], relativity [esp+2Ch].
UhcWorkRateApplyHook PROC
    TRACE_ONCE "workRateByAbstractType apply (0x8F987C)"
    pushad
    lea eax, [esp+20h]
    push 0
    push dword ptr [eax+2Ch]
    push dword ptr [eax+28h]
    push dword ptr [eax+24h]
    push dword ptr [eax+20h]
    push esi
    push edi
    call UhcWorkRateByType
    popad
    mov edi, dword ptr [edi+44h]    ; stolen 0x8F987C
    cmp edi, ebp                    ; stolen 0x8F987F
    jmp applyNext
UhcWorkRateApplyHook ENDP

; Replaces 0x8FB11A..0x8FB11E (mov esi,[esi+44h] / cmp esi,ebp), the same case of unapplyData
; FUN_008FB01C, which saves one register less and swaps these two. ESI = target proto, EDI = its
; base proto, EBP = 0, FPU stack empty. Frame: action [esp+1Ch], rate key [esp+20h], amount
; [esp+24h], relativity [esp+28h].
UhcWorkRateUnapplyHook PROC
    TRACE_ONCE "workRateByAbstractType unapply (0x8FB11A)"
    pushad
    lea eax, [esp+20h]
    push 1
    push dword ptr [eax+28h]
    push dword ptr [eax+24h]
    push dword ptr [eax+20h]
    push dword ptr [eax+1Ch]
    push edi
    push esi
    call UhcWorkRateByType
    popad
    mov esi, dword ptr [esi+44h]    ; stolen 0x8FB11A
    cmp esi, ebp                    ; stolen 0x8FB11D
    jmp unapplyNext
UhcWorkRateUnapplyHook ENDP

END
```

## cratePriority

Contract: [cratePriority](../porting-to-another-dll.md#cratepriority).

Sites: `CrateRankCall` `0x49A03C` (5 B), `CrateNextCall` `0x50170B` (5 B), `CrateNextCivRead` `0x50184A` (6 B).

### src/features/cratepriority.cpp

```cpp
// cratePriority: the order in which a civ's units gather crates, from uhc.cfg.
//
// Stock has it in two places, both by civ name. The gather target search adds 1000 x the rank of a
// crate's resource to its score (the only call 0x49A03C of FUN_004DBF40): Dutch Gold, Wood, Food;
// Ottomans and Indians Wood, Food, Gold; the rest Food, Wood, Gold. And when a unit runs out of crates of
// one kind FUN_00501786 (the only call 0x50170B) names the next one, in the same order, the large crate of
// a resource before the small one.
//
// Both calls go through a wrapper. For a civ with an order in the cfg the wrapper answers from that
// order; for any other civ the answer is stock's. The next crate still starts with the stock call, which
// checks the proto is a crate of the six and tells the wrapper whether to answer.
#include <cstdint>
#include <cstdlib>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr std::uint32_t kRankCall = 0x0049A03C;
constexpr std::uint32_t kNextCall = 0x0050170B;
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
constexpr int kMaxLogLines = 200;
constexpr std::int32_t kResources = 3;  // 0 Gold, 1 Wood, 2 Food, as the two functions number them

using RankFn = std::int32_t(__thiscall*)(void* database, std::int32_t resource, std::int32_t civ);
const auto kRank = reinterpret_cast<RankFn>(0x004DBF40);
using NextFn = bool(__thiscall*)(void* player, std::int32_t proto, std::int32_t* next, std::int32_t* resource);
const auto kNext = reinterpret_cast<NextFn>(0x00501786);
using CivIdByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
const auto kCivIdByName = reinterpret_cast<CivIdByNameFn>(0x0058E71F);

struct Order {
  std::string civ;  // as written in the cfg; "all" for every civ that has no line of its own
  std::int32_t civId = -1;
  std::int32_t resources[kResources] = {};  // first = gathered first
};

std::vector<Order> g_orders;
const Order* g_all = nullptr;
const char* g_resolvedDatabase = nullptr;  // civs.xml is read again when a game starts
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Database() { return Field<const char*>(*reinterpret_cast<const char**>(kGameGlobal), 0x140); }

void Resolve() {
  const char* database = Database();
  if (database == g_resolvedDatabase) {
    return;
  }
  g_resolvedDatabase = database;
  for (Order& order : g_orders) {
    if (&order == g_all) {
      continue;
    }
    order.civId = kCivIdByName(database, order.civ.c_str());
    uhc::Log(L"cratePriority: %hs -> civ %d", order.civ.c_str(), order.civId);
  }
}

const Order* Find(std::int32_t civ) {
  Resolve();
  for (const Order& order : g_orders) {
    if (order.civId == civ && &order != g_all) {
      return &order;
    }
  }
  return g_all;
}

void LogLine(const wchar_t* text, std::int32_t a, std::int32_t b, std::int32_t c) {
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(text, a, b, c);
  }
}

// Replaces the call at 0x49A03C: the higher the rank, the sooner.
std::int32_t __fastcall Rank(void* database, void*, std::int32_t resource, std::int32_t civ) {
  const Order* order = Find(civ);
  if (order == nullptr) {
    return kRank(database, resource, civ);
  }
  for (std::int32_t i = 0; i < kResources; ++i) {
    if (order->resources[i] == resource) {
      LogLine(L"cratePriority: civ %d, resource %d: rank %d", civ, resource, kResources - i);
      return kResources - i;
    }
  }
  return 0;  // what stock answers for any other resource
}

// [player+4] is the civ list's owner: [[player+4]+44h], with the array at +20h and the count at +24h.
std::int32_t CivOf(const char* player) {
  const char* list = Field<const char*>(Field<const char*>(player, 4), 0x44);
  return Field<std::int32_t>(list, 0x24) > 0 ? *Field<const std::int32_t*>(list, 0x20) : -1;
}

// Replaces the call at 0x50170B: proto is the crate just searched for, *next the one to look for now.
bool __fastcall Next(char* player, void*, std::int32_t proto, std::int32_t* next, std::int32_t* resource) {
  if (!kNext(player, proto, next, resource)) {
    return false;
  }
  const Order* order = Find(CivOf(player));
  if (order == nullptr) {
    return true;
  }
  const char* database = Database();
  std::int32_t cycle[kResources * 2];  // large and small of each resource, in the civ's order
  for (std::int32_t i = 0; i < kResources; ++i) {
    // Gold: 5E48h, 5E3Ch. Wood: 5E44h, 5E38h. Food: 5E40h, 5E34h.
    const std::uint32_t small = 0x5E3C - order->resources[i] * 4;
    cycle[i * 2] = Field<std::int32_t>(database, small + 0x0C);
    cycle[i * 2 + 1] = Field<std::int32_t>(database, small);
  }
  for (std::int32_t i = 0; i < kResources * 2; ++i) {
    if (cycle[i] == proto) {
      const std::int32_t after = (i + 1) % (kResources * 2);
      *next = cycle[after];
      *resource = order->resources[after / 2];
      LogLine(L"cratePriority: civ %d, after proto %d look for proto %d", CivOf(player), proto, *next);
      return true;
    }
  }
  return true;  // stock knew the proto and we did not: keep its answer
}

bool ParseResource(const std::string& text, std::int32_t* out) {
  const struct {
    const char* name;
    std::int32_t index;
  } names[] = {{"Gold", 0}, {"Coin", 0}, {"Wood", 1}, {"Food", 2}};
  for (const auto& name : names) {
    if (_stricmp(text.c_str(), name.name) == 0) {
      *out = name.index;
      return true;
    }
  }
  return false;
}

}  // namespace

namespace uhc {

Outcome ApplyCratePriority(const Config& config) {
  const std::vector<Config::Args>* lines = config.All("cratePriority");
  if (lines == nullptr) {
    return Outcome::kNotConfigured;
  }
  g_orders.reserve(lines->size());
  for (const Config::Args& line : *lines) {
    if (line.size() == 1 && _stricmp(line[0].c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    Order order;
    bool seen[kResources] = {};
    if (line.size() != 1 + kResources) {
      Log(L"cratePriority: a line needs a civ (or all) and the three resources, or log; feature not applied");
      return Outcome::kFailed;
    }
    order.civ = line[0];
    for (std::int32_t i = 0; i < kResources; ++i) {
      if (!ParseResource(line[1 + i], &order.resources[i]) || seen[order.resources[i]]) {
        Log(L"cratePriority: %hs: expected Gold, Wood and Food, each once; feature not applied", line[0].c_str());
        return Outcome::kFailed;
      }
      seen[order.resources[i]] = true;
    }
    g_orders.push_back(order);
    if (_stricmp(line[0].c_str(), "all") == 0) {
      g_all = &g_orders.back();
    }
  }
  if (g_orders.empty()) {
    Log(L"cratePriority: no civ listed; feature not applied");
    return Outcome::kFailed;
  }
  if (!VerifyAll("cratePriority", {&sites::kCrateRankCall, &sites::kCrateNextCall, &sites::kCrateNextCivRead}) ||
      !WriteCall(kRankCall, reinterpret_cast<const void*>(&Rank)) ||
      !WriteCall(kNextCall, reinterpret_cast<const void*>(&Next))) {
    return Outcome::kFailed;
  }
  Log(L"cratePriority: %u lines", static_cast<unsigned>(g_orders.size()));
  return Outcome::kApplied;
}

}  // namespace uhc
```

## autoGatherScaleByContained

Contract: [autoGatherScaleByContained](../porting-to-another-dll.md#autogatherscalebycontained).

Sites: `AutoGatherRateEntry` `0x49EBE4` (8 B).

### src/features/gatherscale.cpp

```cpp
// autoGatherScaleByContained: <ScaleByContainedUnits> also works on AutoGather actions.
//
// Stock: the tactics flag ScaleByContainedUnits (bit 18, set at 0x5FEE1A) is read by the attack
// code only (0x4996C7, and the stat panel): the damage is multiplied by the unit's contained count
// [unit+74h], at most DamageFactorCap ([tacticsAction+48h]) when that is above 0. An AutoGather
// action accepts the tag and ignores it. ActiveIfContainsUnits, which the AutoGather update does
// read, is on or off and no more.
//
// With the key, the AutoGather rate getter 0x49EBE4 multiplies its result in the same way, so the
// update (0x48D16E) and the rate rows of both panels (0x6992BD, 0x69B005) follow. An action without
// the flag runs the stock getter unchanged. With nobody inside the factor is 0, as in an attack.
// The getter's hook is shared (autogatherrate.h, with nurseryFactor); this key's filter is ScaleFilter.
#include <cstdint>

#include "../autogatherrate.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// The tactics flag ScaleByContainedUnits: bit 18 of the flag bytes [+64h], whose bit count is [+68h]. The factor
// follows the stock attack rule (0x4996C7..0x49970A): the contained count [unit+74h], or DamageFactorCap [+48h]
// when the count is at least the cap and the cap is above 0. Both are exact as floats, so the product is the one the
// hook of earlier builds computed on the x87 stack.
bool ScaleFilter(const char* unitAction, std::int32_t, float* factor) {
  const char* tactics = Field<const char*>(unitAction, 4);
  if (tactics == nullptr || Field<std::uint32_t>(tactics, 0x68) <= 0x12 ||
      (Field<const std::uint8_t*>(tactics, 0x64)[2] & 4) == 0) {
    return false;
  }
  const char* unit = Field<const char*>(unitAction, 0x10);
  const float count = static_cast<float>(Field<std::int32_t>(unit, 0x74));
  const float cap = Field<float>(tactics, 0x48);
  *factor *= (cap <= count && cap > 0.0f) ? cap : count;
  return true;
}

}  // namespace

namespace uhc {

Outcome ApplyAutoGatherScaleByContained(const Config& config) {
  const Config::Args* args = config.First("autoGatherScaleByContained");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!args->empty()) {
    Log(L"autoGatherScaleByContained: unexpected argument %hs (it takes none); feature not applied",
        args->front().c_str());
    return Outcome::kFailed;
  }
  if (!AddAutoGatherRateFilter("autoGatherScaleByContained", &ScaleFilter)) {
    return Outcome::kFailed;
  }
  Log(L"autoGatherScaleByContained: AutoGather actions with ScaleByContainedUnits multiply their rate by the units "
      L"inside (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/autogatherrate.h

```cpp
// One hook on the head of the AutoGather rate getter 0x49EBE4 (float thiscall(unitAction, resource), ret 4), shared
// by every key that multiplies an AutoGather rate (autoGatherScaleByContained, nurseryFactor): a single jmp,
// whichever of those keys are on. Every reader of the rate goes through the getter: the AutoGather update
// FUN_0048D13E (the pay) and the rate rows of both unit panels (0x6992BD, 0x69B005).
#pragma once

#include <cstdint>

namespace uhc {

// Asked before the stock body runs, in the order the keys added them (their kFeatures order). `unitAction` is the
// unit's AutoGather action ([+4] its tactics action, [+10h] the unit). Returns false to leave the rate alone, or
// true after multiplying *factor (1 on entry) by its own factor. When no filter returns true the stock getter runs
// unchanged, bit for bit; otherwise the hook runs the stock body and multiplies its result by the product.
using AutoGatherRateFilter = bool (*)(const char* unitAction, std::int32_t resource, float* factor);

// Writes the hook the first time (after checking the site's stock bytes) and adds filter.
bool AddAutoGatherRateFilter(const char* name, AutoGatherRateFilter filter);

}  // namespace uhc
```

### src/autogatherrate.cpp

```cpp
#include "autogatherrate.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" {
void UhcAutoGatherRateHook();  // hooks/autogatherrate_hooks.asm
float g_uhcAgFactor = 1.0f;    // the product the hook multiplies the stock rate by, when the asker returned 1
}

namespace {

constexpr std::size_t kMaxFilters = 4;

uhc::AutoGatherRateFilter g_filters[kMaxFilters] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

// From the hook, at the getter's entry: 1 when a filter changes this rate (the factor in g_uhcAgFactor), else 0.
extern "C" std::int32_t __stdcall UhcAutoGatherRateAsk(const char* unitAction, std::int32_t resource) {
  float factor = 1.0f;
  bool changed = false;
  for (std::size_t i = 0; i < g_count; ++i) {
    changed = g_filters[i](unitAction, resource, &factor) || changed;
  }
  if (!changed) {
    return 0;
  }
  g_uhcAgFactor = factor;
  return 1;
}

namespace uhc {

bool AddAutoGatherRateFilter(const char* name, AutoGatherRateFilter filter) {
  if (g_count == kMaxFilters) {
    Log(L"AutoGather rate: more than %u filters; %hs not added", static_cast<unsigned>(kMaxFilters), name);
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("AutoGather rate", {&sites::kAutoGatherRateEntry})) {
      return false;
    }
    // Replaces push ecx / push ebx / mov ebx,[esp+0Ch] at 0x49EBE4; the hook re-executes them.
    if (!WriteJmp(sites::kAutoGatherRateEntry.va, reinterpret_cast<const void*>(&UhcAutoGatherRateHook), 6)) {
      return false;
    }
    g_installed = true;
  }
  g_filters[g_count++] = filter;
  return true;
}

}  // namespace uhc
```

### src/hooks/autogatherrate_hooks.asm

```asm
; The shared hook of the AutoGather rate getter (autogatherrate.cpp): autoGatherScaleByContained and
; nurseryFactor. Entered through a jmp written over the stock code; it leaves through an explicit jmp to the
; verified continuation, or returns for the stock body it called (docs/how-it-works.md, "autoGatherScaleByContained").
.686
.model flat, c
option casemap :none

include common.inc

UhcAutoGatherRateAsk PROTO STDCALL unitAction:DWORD, resource:DWORD
EXTERN g_uhcAgFactor:DWORD

.data
rateBody    dd 0049EBEAh    ; test ebx,ebx: the AutoGather rate getter after its first three instructions

.code

; Replaces 0x49EBE4..0x49EBE9 (push ecx / push ebx / mov ebx,[esp+0Ch]), the entry of the AutoGather rate getter,
; float thiscall(unitAction, int resource), ret 4. ECX = the unit action; [esp+4] = the resource. EAX, ECX and EDX
; are free at a thiscall entry, and the x87 stack is empty. The asker (stdcall, C) keeps EBX, ESI, EDI and EBP.
; It returns 0: the stock getter runs as if nothing happened, bit for bit. 1: the stock body runs as a call, so that
; its ret 4 comes back here with the rate in ST0, which is multiplied by g_uhcAgFactor (a float).
UhcAutoGatherRateHook PROC
    TRACE_ONCE "AutoGather rate filters (0x49EBE4)"
    push ecx                        ; keep the unit action
    push dword ptr [esp+8]          ; the resource
    push ecx                        ; the unit action
    call UhcAutoGatherRateAsk
    pop ecx
    test eax, eax
    jne scaled
    push ecx                        ; stolen 0x49EBE4
    push ebx                        ; stolen 0x49EBE5
    mov ebx, dword ptr [esp+0Ch]    ; stolen 0x49EBE6
    jmp rateBody
scaled:
    push dword ptr [esp+4]          ; the resource, for the body's ret 4
    call body                       ; returns here with the rate in ST0
    fmul dword ptr g_uhcAgFactor
    ret 4
body:
    push ecx                        ; stolen 0x49EBE4
    push ebx                        ; stolen 0x49EBE5
    mov ebx, dword ptr [esp+0Ch]    ; stolen 0x49EBE6
    jmp rateBody
UhcAutoGatherRateHook ENDP

END
```

## nurseryFactor

Contract: [nurseryFactor](../porting-to-another-dll.md#nurseryfactor).

Besides the core helpers, it needs: [`datarefs.h`](helpers.md#data-refs), [`prototags.h`](helpers.md#proto-tags), [`savedmarkers.h`](helpers.md#state-kept-for-a-saved-game), [`techsubtypes.h`](helpers.md#tech-subtypes), [`unitpanel.h`](helpers.md#unit-panel-row-the-minimized-interface), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `BStringAssign` `0x443BB8` (15 B), `IsBuilt` `0x44DDB4` (31 B), `UnitAliveSlot` `0xB9355C` (4 B).

### src/features/nurseryfactor.cpp

```cpp
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
```

## unitResourceAuras

Contract: [unitResourceAuras](../porting-to-another-dll.md#unitresourceauras).

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`modifytypes.h`](helpers.md#modify-types), [`prototags.h`](helpers.md#proto-tags), [`techsubtypes.h`](helpers.md#tech-subtypes), [`unitinfo.h`](helpers.md#unit-info-for-the-panels), [`unitmodels.h`](helpers.md#models-on-a-unit), [`unitpanel.h`](helpers.md#unit-panel-row-the-minimized-interface), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `ModelById` `0x405E83` (6 B), `IsAbstractIndex` `0x44CAC4` (70 B), `UnitById` `0x44CC6D` (58 B), `IsA` `0x44D7FA` (105 B), `IsBuilt` `0x44DDB4` (31 B), `ResListGet` `0x44EFFF` (61 B), `ProtoFlag` `0x45EE02` (53 B), `UnitIsDead` `0x4802C6` (16 B), `CheckState` `0x482152` (16 B), `InventoryAdd` `0x49A5E6` (16 B), `PlayerAddResource` `0x49A98A` (16 B), `MainResource` `0x4DBEC1` (16 B), `UnitAttachModel` `0x9C04F3` (8 B), `UnitRemoveModel` `0x9C2885` (8 B), `UnitHasModel` `0x9C28DE` (8 B), `AuraScan` `0x9CFF9A` (16 B), `UnitResourceAuraEntry` `0x9D033E` (8 B), `AuraModelBlock` `0x9D053F` (9 B), `UnitAliveSlot` `0xB9355C` (4 B).

### src/features/unitresource.cpp

```cpp
// unitResourceAuras: an AutoRangedModify action with <ModifyType>UnitResource</ModifyType> gathers
// from the units around it, for its owner.
//
// Stock: an aura gives each unit in range a modifier (FUN_009D033E). UnitResource is not one of the
// names of the parser, and <ModifyAmount>, <ModifyTargetLimit> and <TargetGaia> are unknown tags.
//
// With the key, UnitResource is stat 41h (modifytypes.h), the action tags are read while the data
// loads, and the aura update of such an action runs this code instead of the stock update, so no
// modifier is ever made. For a built, living owner, on each update, the units the stock scan finds
// in range (0x9CFF9A, the action's MaxRange) are filtered: of <ModifyAbstractType> or
// <ModifyProtoID>; owned by the aura's player, or by Gaia with <TargetGaia>; with a resource
// inventory. Each of the first <ModifyTargetLimit> gives <ModifyAmount> per second of its main
// resource (0x4DBEC1), as the gather tick does: taken from its inventory (0x49A5E6, then the state
// check 0x482152, which removes an empty tree), and paid to the owner (0x49A98A), multiplied by the
// player's gather multiplier [player+37Ch]. The time comes from the game clock. A target whose
// proto has flag 24h (an endless resource) pays and is not drained, as in the gather tick.
//
// The stock update also hangs the action's <ModelAttachment> on each target (0x9D053F: the ring under
// units that an aura affects). Running instead of it, this code does the same, through the same
// functions, for the targets that gave resources in this update, and takes the model off the ones that
// stop. A target in two auras keeps its ring until the last one lets go. A model is only a visual of the
// unit: it does not reach the simulation.
//
// Also read: <IncludeGaia> (as <TargetGaia>), <DeadExclusive> and <DoNotIgnoreDead> (dead targets are skipped
// without them), <SingleUnit> (one target, kept until it is used up) and <ForbidUnitType>. The Data subtypes
// ModifyRate and ModifyAmount change the amount for one player's copy of the action, and
// <ShowUnitResourceActionRates> in a proto writes what its auras pay in the unit panel's rate row.
//
// The hook is in hooks/unitresource_hooks.asm. The time of each aura's last update and the rings it
// hung live here, so a saved game restarts that clock; nothing else is kept.
#include <algorithm>
#include <compare>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "../actiontags.h"
#include "../aurastacking.h"
#include "../features.h"
#include "../income.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifytypes.h"
#include "../patch.h"
#include "../unitinfo.h"
#include "../prototags.h"
#include "../techsubtypes.h"
#include "../unitpanel.h"
#include "../unitmodels.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
void UhcUnitResourceAuraHook();
}

namespace {

constexpr std::int32_t kStatUnitResource = 0x41;  // as in unitresource_hooks.asm
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr std::int32_t kFlagEndless = 0x24;        // proto flag tested at 0x4ED062
constexpr std::uint32_t kMaxStepMs = 5000;         // a longer gap (a load, a pause) pays this much
constexpr std::uint32_t kRingSweepMs = 1000;       // how often the auras that hung rings are checked
constexpr float kMinAmount = 1.0e-6f;
constexpr int kMaxLogLines = 200;
constexpr std::size_t kMaxResources = 8;           // rates kept per aura; the game has 7 (food to ships)
constexpr std::uint32_t kRateFreshMs = 8000;       // a rate older than this no longer shows: the aura stopped
constexpr std::int32_t kAutoGatherAction = 0x1D;   // the unit action type the stock panel asks for

// The list FUN_004A1C55 fills (the engine's dynamic array: data, count, capacity).
struct IdList {
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using UnitTestFn = bool(__thiscall*)(const char* unit);
using ScanFn = void(__thiscall*)(const char* action, IdList* list);
using UnitByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);
using MainResourceFn = std::int32_t(__thiscall*)(const char* unit);
using ListGetFn = float(__thiscall*)(const char* list, std::int32_t resource);
using InventoryAddFn = bool(__thiscall*)(char* inventory, std::int32_t resource, float amount);
using PlayerAddFn = bool(__thiscall*)(char* player, std::int32_t resource, float amount, bool flag);
using CheckStateFn = void(__thiscall*)(char* unit);
using ProtoBitFn = bool(__thiscall*)(const char* proto, std::int32_t bit);

const auto kIsBuilt = reinterpret_cast<UnitTestFn>(0x0044DDB4);
const auto kIsDead = reinterpret_cast<UnitTestFn>(0x004802C6);
const auto kScan = reinterpret_cast<ScanFn>(0x009CFF9A);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kMainResource = reinterpret_cast<MainResourceFn>(0x004DBEC1);
const auto kListGet = reinterpret_cast<ListGetFn>(0x0044EFFF);
const auto kInventoryAdd = reinterpret_cast<InventoryAddFn>(0x0049A5E6);
const auto kPlayerAdd = reinterpret_cast<PlayerAddFn>(0x0049A98A);
const auto kCheckState = reinterpret_cast<CheckStateFn>(0x00482152);
const auto kProtoFlag = reinterpret_cast<ProtoBitFn>(0x0045EE02);
const auto kIsAbstractIndex = reinterpret_cast<ProtoBitFn>(0x0044CAC4);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
using UnitActionFn = const char*(__thiscall*)(const char* manager, std::int32_t type);
using AutoGatherRateFn = float(__thiscall*)(const char* action, std::int32_t resource);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
const auto kUnitAction = reinterpret_cast<UnitActionFn>(0x00485CAC);
const auto kAutoGatherRate = reinterpret_cast<AutoGatherRateFn>(0x0049EBE4);

// The engine's string: one pointer to a wide, reference-counted buffer; null is empty.
struct BString {
  wchar_t* text;
};
const wchar_t* const kRateLabelFormat = reinterpret_cast<const wchar_t*>(0x00C36580);  // "%s (<icon=...>):"
using BStringFormatFn = void(__cdecl*)(BString* out, const wchar_t* format, ...);
using BStringFreeFn = void(__thiscall*)(BString* self);
using ResourceIconFn = const wchar_t*(__thiscall*)(const char* database, std::int32_t resource);
const auto kBStringFormat = reinterpret_cast<BStringFormatFn>(0x00444EFB);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kResourceIcon = reinterpret_cast<ResourceIconFn>(0x00706EFB);

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

enum class DeadTargets { kSkip, kInclude, kOnly };

struct Params {
  float amount = 0.0f;
  std::int32_t limit = -1;  // -1: every unit in range
  bool gaia = false;        // <TargetGaia> or <IncludeGaia>
  bool single = false;      // <SingleUnit>: one target, kept until it is used up
  DeadTargets dead = DeadTargets::kSkip;  // <DoNotIgnoreDead>, <DeadExclusive>
  std::wstring forbidName;                // <ForbidUnitType>, a unit type or a proto
  std::int32_t forbidId = -2;             // -2: not looked up yet, -1: none or unknown
};

// One aura of one unit: a building has several (a mine's, a tree's...), each with its own clock.
struct AuraKey {
  std::int32_t owner;
  std::int32_t name;
  auto operator<=>(const AuraKey&) const = default;
};

// One take of an update, for the panels: who gave what, per second.
struct Take {
  std::int32_t target;
  std::int32_t resource;
  float perSecond;
};

struct AuraState {
  std::uint32_t time = 0;                   // game time of the last update
  float perSecond[kMaxResources] = {};      // what that update paid, for the panel
  std::int32_t singleTarget = -1;           // <SingleUnit>: the unit it is working
  std::vector<Take> takes;                  // that update's takes, for the panel (minUIStats' auras item)
};

struct TechAmount {
  std::int32_t name;  // the action's name: a reused pointer with another name is ignored
  float value;
};

std::map<ActionKey, Params> g_params;
std::map<AuraKey, AuraState> g_auras;                    // in owner, then action order
std::unordered_map<const char*, TechAmount> g_techAmount;  // by the player's copy of the action
std::set<std::int32_t> g_showRates;                      // proto IDs with <ShowUnitResourceActionRates>
IdList g_list = {};

struct Rings {
  std::int32_t model = -1;
  std::vector<std::int32_t> targets;
};

struct RingUser {
  std::int32_t unit;
  std::int32_t model;
  auto operator<=>(const RingUser&) const = default;
};

std::map<AuraKey, Rings> g_rings;           // by aura
std::map<RingUser, std::int32_t> g_ringUsers;  // the auras holding a model on a unit
std::vector<std::int32_t> g_ringTargets;        // the targets of the update that is running
const char* g_ringWorld = nullptr;
std::uint32_t g_ringTime = 0;
std::uint32_t g_nextRingSweep = 0;
bool g_ringModelWarned = false;
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

void ForgetRings() {
  g_rings.clear();
  g_ringUsers.clear();
  g_nextRingSweep = 0;
}

void NewDatabase(char*) {
  g_params.clear();
  g_auras.clear();
  g_techAmount.clear();
  g_showRates.clear();
  ForgetRings();
  g_logLines = 0;
}

// Another game: its unit IDs are not the ones held here.
void CheckRingWorld(const char* world, std::uint32_t now) {
  if (world != g_ringWorld || now < g_ringTime) {
    ForgetRings();
    g_ringWorld = world;
  }
  g_ringTime = now;
}

// False: the unit has no visual yet, and the next update tries again. A model that is not in the game is
// taken as hung, or it would be hung again on every update: the engine accepts it and shows nothing.
bool HangRing(const char* world, std::int32_t id, std::int32_t model, std::int32_t bone, const char* tactics) {
  char* unit = const_cast<char*>(kUnitById(world, id));
  const uhc::ModelHang hang = uhc::HangUnitModel(unit, model, bone);
  if (hang == uhc::ModelHang::kRetry) {
    return false;
  }
  if (hang == uhc::ModelHang::kAlready) {
    return true;
  }
  if (hang == uhc::ModelHang::kNotInGame) {
    if (!g_ringModelWarned) {
      g_ringModelWarned = true;
      uhc::Log(L"unitResourceAuras: the action %d has a <ModelAttachment> that is not in the game: no ring shows",
               Field<std::int32_t>(tactics, 0x04));
    }
  } else if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"unitResourceAuras: ring on unit %d", id);
  }
  return true;
}

void ReleaseRing(const char* world, std::int32_t id, std::int32_t model) {
  const auto users = g_ringUsers.find({id, model});
  if (users == g_ringUsers.end() || --users->second > 0) {
    return;
  }
  g_ringUsers.erase(users);
  if (char* unit = const_cast<char*>(kUnitById(world, id))) {
    uhc::RemoveUnitModel(unit, model);
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"unitResourceAuras: ring off unit %d", id);
    }
  }
}

void UpdateRings(const char* world, const AuraKey& owner, const char* tactics, std::int32_t model, std::int32_t bone) {
  Rings& rings = g_rings[owner];
  rings.model = model;
  std::vector<std::int32_t> held;
  for (const std::int32_t id : g_ringTargets) {
    const bool had = std::find(rings.targets.begin(), rings.targets.end(), id) != rings.targets.end();
    if (had) {
      held.push_back(id);
    } else if (HangRing(world, id, model, bone, tactics)) {
      ++g_ringUsers[{id, model}];
      held.push_back(id);
    }
  }
  for (const std::int32_t id : rings.targets) {
    if (std::find(held.begin(), held.end(), id) == held.end()) {
      ReleaseRing(world, id, model);
    }
  }
  rings.targets = std::move(held);
  if (rings.targets.empty()) {
    g_rings.erase(owner);
  }
}

// An aura that dies has no more updates, so its rings are taken off from here.
void RingTick(char* world, std::int32_t) {
  if (g_rings.empty()) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  CheckRingWorld(world, now);
  if (now < g_nextRingSweep) {
    return;
  }
  g_nextRingSweep = now + kRingSweepMs;
  for (auto it = g_rings.begin(); it != g_rings.end();) {
    const char* owner = kUnitById(world, it->first.owner);
    if (owner != nullptr && kIsBuilt(owner) && !kIsDead(owner)) {
      ++it;
      continue;
    }
    for (const std::int32_t id : it->second.targets) {
      ReleaseRing(world, id, it->second.model);
    }
    it = g_rings.erase(it);
  }
}

void ActionTagRead(const uhc::ActionTag& tag) {
  const bool amount = _wcsicmp(tag.name, L"ModifyAmount") == 0;
  const bool limit = _wcsicmp(tag.name, L"ModifyTargetLimit") == 0;
  const bool gaia = _wcsicmp(tag.name, L"TargetGaia") == 0 || _wcsicmp(tag.name, L"IncludeGaia") == 0;
  const bool single = _wcsicmp(tag.name, L"SingleUnit") == 0;
  const bool ignoreDead = _wcsicmp(tag.name, L"DoNotIgnoreDead") == 0;
  const bool deadOnly = _wcsicmp(tag.name, L"DeadExclusive") == 0;
  const bool forbid = _wcsicmp(tag.name, L"ForbidUnitType") == 0 || _wcsicmp(tag.name, L"ForbidAbstractType") == 0;
  if (!amount && !limit && !gaia && !single && !ignoreDead && !deadOnly && !forbid) {
    return;  // <ForceUpdateMode> stays unread: the take already follows the game time between updates
  }
  Params& params = g_params[{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)}];
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  // These flags may be written empty.
  const bool on = text[0] == L'\0' || std::wcstol(text, nullptr, 10) != 0;
  if (amount) {
    params.amount = std::wcstof(text, nullptr);
  } else if (limit) {
    params.limit = std::wcstol(text, nullptr, 10);
  } else if (gaia) {
    params.gaia = params.gaia || on;
  } else if (single) {
    params.single = on;
  } else if (forbid) {
    params.forbidName = text;
  } else if (deadOnly) {
    params.dead = on ? DeadTargets::kOnly : params.dead;
  } else if (on && params.dead == DeadTargets::kSkip) {
    params.dead = DeadTargets::kInclude;
  }
}

// <ForbidUnitType>, through the table <UnitType> reads, on the first update: every name is known by then.
std::int32_t ForbiddenType(Params& params) {
  if (params.forbidId != -2) {
    return params.forbidId;
  }
  params.forbidId = -1;
  if (params.forbidName.empty()) {
    return -1;
  }
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (database == nullptr) {
    return -1;
  }
  std::string name;
  for (const wchar_t c : params.forbidName) {
    name.push_back(static_cast<char>(c));
  }
  const char* table = database + 0x190;
  std::int32_t id = -1;
  const std::int32_t bucket = kNameBucket(table, name.c_str());
  if (kNameFind(table, name.c_str(), bucket, &id)) {
    params.forbidId = id;
  } else {
    uhc::Log(L"unitResourceAuras: <ForbidUnitType>%hs names no unit type or proto; ignored", name.c_str());
  }
  return params.forbidId;
}

// ModifyAmount or ModifyRate on an action: the player's copy gets its own amount, from the tag's as base.
void ChangeAmount(char* action, const char*, const char* proto, float amount, std::uint8_t relativity, bool unapply) {
  const std::int32_t name = Field<std::int32_t>(action, 0x04);
  const auto params = g_params.find({Field<std::int32_t>(proto, 0x04), name});
  if (params == g_params.end()) {
    return;  // not an aura of this key
  }
  const float base = params->second.amount;
  TechAmount& slot = g_techAmount.emplace(action, TechAmount{name, base}).first->second;
  if (slot.name != name) {
    slot = TechAmount{name, base};
  }
  const float before = slot.value;
  kEffectValue(relativity, &slot.value, base, amount, unapply);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"unitResourceAuras: proto %d, action %d, relativity %u, amount %g%ls: %g -> %g",
             Field<std::int32_t>(proto, 0x04), name, relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", static_cast<double>(before), static_cast<double>(slot.value));
  }
}

bool __cdecl ReadShowRates(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  if (text == nullptr || text[0] == L'\0' || std::wcstol(text, nullptr, 10) != 0) {
    g_showRates.insert(Field<std::int32_t>(proto, 0x04));
  }
  return true;
}

// The minimized interface's row: what the unit's auras paid, per resource, on top of its own AutoGather,
// which the stock row just wrote in these two gadgets.
bool __stdcall UhcUnitResourceRow(const char* panel, const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (proto == nullptr || world == nullptr || database == nullptr || g_showRates.count(Field<std::int32_t>(proto, 0x04)) == 0 ||
      !kIsBuilt(unit)) {
    return false;
  }
  float rates[kMaxResources] = {};
  const std::int32_t owner = Field<std::int32_t>(unit, 0x10);
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  bool any = false;
  for (auto it = g_auras.lower_bound({owner, INT32_MIN}); it != g_auras.end() && it->first.owner == owner; ++it) {
    if (now - it->second.time > kRateFreshMs) {
      continue;
    }
    for (std::size_t r = 0; r < kMaxResources; ++r) {
      rates[r] += it->second.perSecond[r];
      any = any || it->second.perSecond[r] > kMinAmount;
    }
  }
  if (!any) {
    return false;  // the stock row stands
  }
  const char* manager = Field<const char*>(unit, 0x58);
  const char* autoGather = manager == nullptr ? nullptr : kUnitAction(manager, kAutoGatherAction);
  const std::int32_t resources = Field<std::int32_t>(database, 0x80);
  std::wstring row;
  for (std::int32_t r = 0; r < resources && r < static_cast<std::int32_t>(kMaxResources); ++r) {
    const float rate = rates[r] + (autoGather != nullptr ? kAutoGatherRate(autoGather, r) : 0.0f);
    if (rate <= kMinAmount) {
      continue;
    }
    // The stock label with no name: only the icon, so that the row is short.
    BString label{nullptr};
    kBStringFormat(&label, kRateLabelFormat, L"", kResourceIcon(database, r));
    wchar_t text[16];
    swprintf_s(text, L" %.2f ", static_cast<double>(rate));
    if (label.text != nullptr) {
      row += label.text;
    }
    row += text;
    kBStringFree(&label);
  }
  // All in the label: the value gadget holds one number, and a building can pay several resources.
  return uhc::SetUnitPanelRow(panel, row.c_str(), L"");
}

bool TypeMatches(const char* tactics, const char* proto) {
  const std::int32_t abstractIndex = Field<std::int16_t>(tactics, 0x9C);
  const std::int32_t protoId = Field<std::int16_t>(tactics, 0x9E);
  if (abstractIndex < 0 && protoId < 0) {
    return false;
  }
  return Field<std::int32_t>(proto, 0x04) == protoId || (abstractIndex >= 0 && kIsAbstractIndex(proto, abstractIndex));
}

}  // namespace

extern "C" void __stdcall UhcUnitResourceAura(const char* action) {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* owner = Field<const char*>(action, 0x10);
  const char* tactics = Field<const char*>(action, 0x04);
  if (world == nullptr || owner == nullptr || !kIsBuilt(owner) || kIsDead(owner)) {
    return;
  }
  const AuraKey auraKey{Field<std::int32_t>(owner, 0x10), Field<std::int32_t>(tactics, 0x04)};
  const std::int32_t model = Field<std::int32_t>(tactics, 0xA4);
  // An action a tech turned off (ActionEnable) still gets here: bit 0 of [tactics+64h] is <Active>.
  const auto* flags = Field<const std::uint8_t*>(tactics, 0x64);
  if (flags != nullptr && (flags[0] & 1) == 0) {
    if (model != -1 && g_rings.count(auraKey) != 0) {
      g_ringTargets.clear();
      UpdateRings(world, auraKey, tactics, model, Field<std::int32_t>(tactics, 0xA8));
    }
    g_auras.erase(auraKey);
    return;
  }
  const char* ownerProto = Field<const char*>(owner, 0x5C);
  char* player = Field<char*>(owner, 0x44);
  if (ownerProto == nullptr || player == nullptr) {
    return;
  }
  const auto found = g_params.find({Field<std::int32_t>(ownerProto, 0x04), Field<std::int32_t>(tactics, 0x04)});
  if (found == g_params.end() || found->second.amount <= kMinAmount) {
    return;
  }
  Params& params = found->second;
  float perSecondAmount = params.amount;
  const auto tech = g_techAmount.find(tactics);
  if (tech != g_techAmount.end() && tech->second.name == auraKey.name) {
    perSecondAmount = tech->second.value;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  CheckRingWorld(world, now);
  const auto [aura, isNew] = g_auras.try_emplace(auraKey);
  AuraState& state = aura->second;
  const std::uint32_t since = now - state.time;
  if (isNew || since == 0) {
    state.time = now;
    return;
  }
  state.time = now;
  const float seconds = static_cast<float>(since > kMaxStepMs ? kMaxStepMs : since) / 1000.0f;
  const float amount = perSecondAmount * seconds;
  float paid[kMaxResources] = {};
  const std::int32_t forbidden = ForbiddenType(params);

  const std::int32_t ownerPlayer = Field<std::int32_t>(player, 0x00);
  const float multiplier = Field<float>(player, 0x37C);
  g_list.count = 0;
  kScan(action, &g_list);
  g_ringTargets.clear();
  state.takes.clear();
  if (params.single && state.singleTarget >= 0) {
    // The unit it was working goes first, so it finishes one before the next.
    for (std::int32_t i = 1; i < g_list.count; ++i) {
      if (g_list.data[i] == state.singleTarget) {
        std::swap(g_list.data[0], g_list.data[i]);
        break;
      }
    }
  }
  const std::int32_t limit = params.single ? 1 : params.limit;
  std::int32_t gathered = 0;
  for (std::int32_t i = 0; i < g_list.count; ++i) {
    if (limit >= 0 && gathered >= limit) {
      break;
    }
    char* target = const_cast<char*>(kUnitById(world, g_list.data[i]));
    if (target == nullptr || target == owner) {
      continue;
    }
    const char* targetProto = Field<const char*>(target, 0x5C);
    const char* targetPlayer = Field<const char*>(target, 0x44);
    if (targetProto == nullptr || targetPlayer == nullptr || !TypeMatches(tactics, targetProto) ||
        (forbidden >= 0 && kProtoIsType(targetProto, forbidden))) {
      continue;
    }
    const std::int32_t targetOwner = Field<std::int32_t>(targetPlayer, 0x00);
    if (targetOwner != ownerPlayer && !(params.gaia && targetOwner == 0)) {
      continue;
    }
    // Not 0x4802C6, the owner's test above: a carcass does not pass it. As the game's own, slot A4h.
    const bool dead = !(*reinterpret_cast<UnitTestFn const* const*>(target))[0xA4 / 4](target);
    if ((dead && params.dead == DeadTargets::kSkip) || (!dead && params.dead == DeadTargets::kOnly)) {
      continue;
    }
    const char* record = Field<const char*>(target, 0xB4);
    char* inventory = record == nullptr ? nullptr : Field<char*>(record, 0x94);
    if (inventory == nullptr) {
      continue;
    }
    std::int32_t resource = Field<std::int32_t>(inventory, 0x10);
    if (resource == -1) {
      resource = kMainResource(target);
    }
    if (resource < 0) {
      continue;
    }
    const float have = kListGet(inventory + 4, resource);
    if (have <= kMinAmount) {
      continue;
    }
    if (!uhc::AuraClaim(world, tactics, Field<std::int32_t>(ownerProto, 0x04), auraKey.owner,
                        Field<std::int32_t>(target, 0x10), now)) {
      continue;
    }
    const float take = have < amount ? have : amount;
    ++gathered;
    state.singleTarget = Field<std::int32_t>(target, 0x10);
    if (static_cast<std::size_t>(resource) < kMaxResources) {
      paid[resource] += take * multiplier;
    }
    g_ringTargets.push_back(Field<std::int32_t>(target, 0x10));  // the state check below may remove it
    state.takes.push_back({Field<std::int32_t>(target, 0x10), resource, take / seconds});
    if (!kProtoFlag(targetProto, kFlagEndless)) {
      kInventoryAdd(inventory, resource, -take);
      kCheckState(target);
    }
    kPlayerAdd(player, resource, take * multiplier, false);
    uhc::CountIncome(player, resource, take * multiplier);
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"unitResourceAuras: unit %d (%hs) took %.3f of resource %d from unit %d (%hs), %.1f left",
               Field<std::int32_t>(owner, 0x10), Field<const char*>(ownerProto, 0x10), static_cast<double>(take),
               resource, Field<std::int32_t>(target, 0x10), Field<const char*>(targetProto, 0x10),
               static_cast<double>(have - take));
    }
  }
  for (std::size_t r = 0; r < kMaxResources; ++r) {
    state.perSecond[r] = paid[r] / seconds;
  }
  if (model != -1) {
    UpdateRings(world, auraKey, tactics, model, Field<std::int32_t>(tactics, 0xA8));
  }
}

namespace {
bool g_unitInfoOn = false;  // the key applied: unitinfo.h answers
}  // namespace

namespace uhc {

Outcome ApplyUnitResourceAuras(const Config& config) {
  const Config::Args* args = config.First("unitResourceAuras");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"unitResourceAuras: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("unitResourceAuras",
                 {&sites::kUnitResourceAuraEntry, &sites::kAuraScan, &sites::kInventoryAdd, &sites::kCheckState,
                  &sites::kMainResource, &sites::kUnitIsDead, &sites::kPlayerAddResource, &sites::kIsBuilt,
                  &sites::kUnitById, &sites::kProtoFlag, &sites::kIsAbstractIndex, &sites::kResListGet,
                  &sites::kAuraModelBlock, &sites::kModelById, &sites::kUnitHasModel, &sites::kUnitAttachModel,
                  &sites::kUnitRemoveModel, &sites::kIsA, &sites::kUnitAliveSlot})) {
    return Outcome::kFailed;
  }
  if (!AddModifyType(L"UnitResource", kStatUnitResource) || !AddActionTagHandler(&ActionTagRead) ||
      !AddProtoTagHandler("ShowUnitResourceActionRates", &ReadShowRates) ||
      !AddTechActionSubtype("ModifyAmount", &ChangeAmount) || !AddTechActionSubtype("ModifyRate", &ChangeAmount) ||
      !AddUnitPanelRow(&UhcUnitResourceRow) || !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&RingTick)) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!WriteJmp(sites::kUnitResourceAuraEntry.va, reinterpret_cast<const void*>(&UhcUnitResourceAuraHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"unitResourceAuras: AutoRangedModify actions with ModifyType UnitResource gather from units in range%ls "
      L"(multiplayer unverified)",
      log ? L", the first takes logged" : L"");
  g_unitInfoOn = true;
  return Outcome::kApplied;
}

}  // namespace uhc

namespace uhc::unitinfo {

// What this unit's UnitResource auras paid per second in their last update ("pays 0.10 <wood>/s"), and what the
// auras around it took from it ("-0.05 <wood>/s"): the state each update publishes, kept only while fresh
// (kRateFreshMs, the rule of the unit panel's row).
bool ResourceAura(const char* unit, std::wstring* out) {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (!g_unitInfoOn || unit == nullptr || world == nullptr || database == nullptr) {
    return false;
  }
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::int32_t resources = Field<std::int32_t>(database, 0x80);
  float paid[kMaxResources] = {};
  float taken[kMaxResources] = {};
  for (const auto& [key, state] : g_auras) {
    if (now - state.time > kRateFreshMs) {
      continue;
    }
    for (std::size_t r = 0; key.owner == id && r < kMaxResources; ++r) {
      paid[r] += state.perSecond[r];
    }
    for (const Take& take : state.takes) {
      if (take.target == id && take.resource >= 0 && static_cast<std::size_t>(take.resource) < kMaxResources) {
        taken[take.resource] += take.perSecond;
      }
    }
  }
  out->clear();
  for (std::int32_t r = 0; r < resources && r < static_cast<std::int32_t>(kMaxResources); ++r) {
    const auto* icon = reinterpret_cast<const char*>(kResourceIcon(database, r));
    for (const bool pays : {true, false}) {
      const float rate = pays ? paid[r] : taken[r];
      if (rate <= kMinAmount) {
        continue;
      }
      wchar_t text[160];
      swprintf_s(text, L"%ls%ls%.2f <icon=\"(16)(%hs)\">/s", out->empty() ? L"" : L" ", pays ? L"pays " : L"-",
                 static_cast<double>(rate), icon == nullptr ? "" : icon);
      *out += text;
    }
  }
  return !out->empty();
}

}  // namespace uhc::unitinfo
```

### src/hooks/unitresource_hooks.asm

```asm
; Hook for unitResourceAuras. Entered through a jmp written over the stock code; it leaves through
; an explicit jmp to a verified continuation, or returns for the stock function it replaces
; (docs/engine-symbols.md, "Resource auras").
.686
.model flat, c
option casemap :none

include common.inc

UhcUnitResourceAura PROTO STDCALL action:DWORD

kStatUnitResource EQU 41h           ; the new ModifyType stat; unitresource.cpp uses the same value

.data
auraNext    dd 009D0343h            ; sub esp,10h: the aura update after its first instruction

.code

; Replaces 0x9D033E (mov eax,[0C66234h]), the first instruction of the aura update FUN_009D033E,
; void thiscall(action), a plain ret. ECX = the unit action, [ecx+4] its tactics action, whose
; ModifyType is the byte [+B8h]. An aura of the new stat is handled by the helper and the stock
; update does not run: it would give each target a modifier. EAX, ECX and EDX are free here.
UhcUnitResourceAuraHook PROC
    mov eax, dword ptr [ecx+4]
    test eax, eax
    je stock
    cmp byte ptr [eax+0B8h], kStatUnitResource
    jne stock
    TRACE_ONCE "unitResourceAuras (0x9D033E)"
    push ecx
    call UhcUnitResourceAura
    ret
stock:
    mov eax, ds:[0C66234h]          ; stolen 0x9D033E
    jmp auraNext
UhcUnitResourceAuraHook ENDP

END
```

## linkedResource

Contract: [linkedResource](../porting-to-another-dll.md#linkedresource).

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`prototags.h`](helpers.md#proto-tags), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `UnitById` `0x44CC6D` (58 B), `IsA` `0x44D7FA` (105 B), `IsBuilt` `0x44DDB4` (31 B), `ResListGet` `0x44EFFF` (61 B), `CheckState` `0x482152` (16 B), `InventoryAddHead` `0x49A5E6` (5 B), `UnitsNearPoint` `0x4A1C55` (248 B), `AutoGatherPayPoint` `0x4C378A` (7 B), `MainResource` `0x4DBEC1` (16 B), `ResListSet` `0x58EF83` (10 B), `InventoryRecreateHead` `0x9BFE5A` (9 B), `UnitAliveSlot` `0xB9355C` (4 B).

### src/features/linkedresource.cpp

```cpp
// linkedResource: a resource building whose stock is that of a mine beside it.
//
//   <LinkedResourceType>AbstractMine</LinkedResourceType>   a unit type or a proto, in the building's proto
//   <LinkedResourceRange>8</LinkedResourceRange>            metres, default 8
//   <GatherLinkedResource>1</GatherLinkedResource>          in an AutoGather action
//
// Each tagged unit is linked to the nearest unit of the type in range, of any owner (FUN_004A1C55 and the
// distance slot B8h), looked for once a second while it has none. Its inventory then shows the mine's: the
// entry of the mine's main resource is copied in, so the panel reads it, the gather tick's clamp holds, and at 0
// villagers stop by the stock paths. Every take goes to the mine: the head of 0x49A5E6, which the gather tick
// calls at 0x4ED124, sends a negative add on a linked inventory to the mine's and runs the state check 0x482152
// there, so the mine ends as if it were mined. With no mine in range the building keeps its own stock.
//
// An AutoGather action pays from nothing (0x4C3798). With the tag, the amount is taken first from the same
// source, the mine or the building's own stock, and what is paid is what was there: the hook at 0x4C378A changes
// the amount and leaves the stock call of the add, whose return address resourceDebt reads.
//
// Links are by unit ID in an ordered map and looked up by game time, on every machine alike. A new game forgets
// them; a saved game finds them again, from the building's first take or update. Hooks: linkedresource_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <utility>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
void UhcLinkedRecreateHook();
void UhcLinkedInventoryHook();
void UhcLinkedAutoGatherHook();
void UhcLinkedInventoryStock();  // the stock entry of 0x49A5E6
std::int32_t g_uhcLinkedOn = 0;  // read by the inventory hook: 1 once the data has a tagged proto
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kResolveMs = 1000;
constexpr std::uint32_t kMirrorMs = 250;
constexpr float kDefaultRange = 8.0f;
constexpr float kMinAmount = 1.0e-6f;
constexpr int kMaxLogLines = 200;

// The list FUN_004A1C55 fills (the engine's dynamic array: data, count, capacity).
struct IdList {
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using UnitsNearFn = std::int32_t(__thiscall*)(char* world, const float* point, float radius, char precise, IdList* out);
using UnitByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using UnitTestFn = bool(__thiscall*)(const char* unit);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using MainResourceFn = std::int32_t(__thiscall*)(const char* unit);
using ListGetFn = float(__thiscall*)(const char* list, std::int32_t resource);
using ListSetFn = void(__thiscall*)(char* list, std::int32_t resource, float value);
using InventoryAddFn = bool(__thiscall*)(char* inventory, std::int32_t resource, float amount);
using CheckStateFn = void(__thiscall*)(char* unit);
using DistanceFn = float(__thiscall*)(const char* unit, const float* point);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);

const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kIsBuilt = reinterpret_cast<UnitTestFn>(0x0044DDB4);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kMainResource = reinterpret_cast<MainResourceFn>(0x004DBEC1);
const auto kListGet = reinterpret_cast<ListGetFn>(0x0044EFFF);
const auto kListSet = reinterpret_cast<ListSetFn>(0x0058EF83);
const auto kInventoryAdd = reinterpret_cast<InventoryAddFn>(&UhcLinkedInventoryStock);
const auto kCheckState = reinterpret_cast<CheckStateFn>(0x00482152);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);

struct ProtoLink {
  std::string typeName;
  std::int32_t type = -2;  // -2: not looked up yet, -1: unknown
  float range = kDefaultRange;
};

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Link {
  std::int32_t mine = -1;
  std::int32_t resource = -1;
  std::uint32_t nextResolve = 0;
};

std::unordered_map<std::int32_t, ProtoLink> g_protos;  // by proto ID; the load fills it
std::set<ActionKey> g_gatherActions;                   // AutoGather actions with the tag
std::map<std::int32_t, Link> g_links;                  // by the building's unit ID
const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_nextMirror = 0;
IdList g_found = {};
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* World() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<UnitTestFn const* const*>(unit))[0xA4 / 4](unit); }

char* InventoryOf(const char* unit) {
  const char* record = Field<const char*>(unit, 0xB4);
  return record == nullptr ? nullptr : Field<char*>(record, 0x94);
}

void LogLine(const wchar_t* format, std::int32_t a, std::int32_t b, double c) {
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(format, a, b, c);
  }
}

bool __cdecl ReadType(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  if (text == nullptr || text[0] == L'\0') {
    return true;
  }
  ProtoLink& link = g_protos[Field<std::int32_t>(proto, 0x04)];
  link.typeName.clear();
  for (const wchar_t* c = text; *c != 0; ++c) {
    link.typeName.push_back(static_cast<char>(*c));
  }
  g_uhcLinkedOn = 1;
  return true;
}

bool __cdecl ReadRange(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  const float range = text == nullptr ? 0.0f : std::wcstof(text, nullptr);
  if (range > 0.0f) {
    g_protos[Field<std::int32_t>(proto, 0x04)].range = range;
  } else {
    uhc::Log(L"linkedResource: proto %d: <LinkedResourceRange> needs a number above 0, ignored",
             Field<std::int32_t>(proto, 0x04));
  }
  return true;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  if (_wcsicmp(tag.name, L"GatherLinkedResource") != 0) {
    return;
  }
  if (tag.text == nullptr || tag.text[0] == L'\0' || std::wcstol(tag.text, nullptr, 10) != 0) {
    g_gatherActions.insert({Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)});
    g_uhcLinkedOn = 1;
  }
}

void NewDatabase(char*) {
  g_protos.clear();
  g_gatherActions.clear();
  g_links.clear();
  g_uhcLinkedOn = 0;
  g_logLines = 0;
}

std::int32_t TypeOf(ProtoLink& proto) {
  if (proto.type != -2) {
    return proto.type;
  }
  proto.type = -1;
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (database == nullptr) {
    return -1;
  }
  const char* table = database + 0x190;
  std::int32_t id = -1;
  const std::int32_t bucket = kNameBucket(table, proto.typeName.c_str());
  if (kNameFind(table, proto.typeName.c_str(), bucket, &id)) {
    proto.type = id;
  } else {
    uhc::Log(L"linkedResource: <LinkedResourceType>%hs names no unit type or proto; ignored", proto.typeName.c_str());
  }
  return proto.type;
}

// The inventory entry of the building follows the mine's.
void Mirror(const char* building, const char* mine, std::int32_t resource) {
  char* own = InventoryOf(building);
  char* source = InventoryOf(mine);
  if (own != nullptr && source != nullptr) {
    kListSet(own + 4, resource, kListGet(source + 4, resource));
  }
}

// The nearest unit of the type in range that holds something. A tagged building is never a mine.
void Resolve(char* world, char* building, std::int32_t id, ProtoLink& proto, Link& link) {
  const std::int32_t type = TypeOf(proto);
  if (type < 0) {
    return;
  }
  const auto* position = reinterpret_cast<const float*>(building + 0x14);
  g_found.count = 0;
  kUnitsNear(world, position, proto.range, 1, &g_found);
  float bestDistance = 0.0f;
  std::int32_t best = -1;
  std::int32_t bestResource = -1;
  for (std::int32_t i = 0; i < g_found.count; ++i) {
    const char* unit = kUnitById(world, g_found.data[i]);
    const char* unitProto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    if (unitProto == nullptr || unit == building || !kProtoIsType(unitProto, type) ||
        g_protos.count(Field<std::int32_t>(unitProto, 0x04)) != 0 || !IsAlive(unit)) {
      continue;
    }
    const char* inventory = InventoryOf(unit);
    const std::int32_t resource = inventory == nullptr ? -1 : kMainResource(unit);
    if (resource < 0 || kListGet(inventory + 4, resource) <= kMinAmount) {
      continue;
    }
    const auto distance = (*reinterpret_cast<DistanceFn const* const*>(unit))[0xB8 / 4](unit, position);
    const std::int32_t unitId = Field<std::int32_t>(unit, 0x10);
    if (best < 0 || distance < bestDistance || (distance == bestDistance && unitId < best)) {
      bestDistance = distance;
      best = unitId;
      bestResource = resource;
    }
  }
  if (best >= 0) {
    link.mine = best;
    link.resource = bestResource;
    LogLine(L"linkedResource: unit %d linked to unit %d, %.1f m", id, best, static_cast<double>(bestDistance));
    Mirror(building, kUnitById(world, best), bestResource);
  }
}

Link* LinkOf(char* world, char* unit) {
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const auto found = g_links.find(id);
  if (found != g_links.end()) {
    return &found->second;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  const auto tagged = proto == nullptr ? g_protos.end() : g_protos.find(Field<std::int32_t>(proto, 0x04));
  if (tagged == g_protos.end()) {
    return nullptr;
  }
  Link& link = g_links[id];  // a loaded game: found on its first take, which goes to the mine too
  Resolve(world, unit, id, tagged->second, link);
  return &link;
}

// The unit that holds the stock of this building now: the mine, or null for its own.
char* SourceOf(const char* world, Link& link) {
  if (link.mine < 0) {
    return nullptr;
  }
  char* mine = kUnitById(world, link.mine);
  return mine != nullptr && IsAlive(mine) ? mine : nullptr;
}

void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_world || now < g_lastTime) {
    g_links.clear();  // another game: its unit IDs are not these
    g_world = world;
    g_nextMirror = 0;
  }
  g_lastTime = now;
  if (g_links.empty() || now < g_nextMirror) {
    return;
  }
  g_nextMirror = now + kMirrorMs;
  for (auto it = g_links.begin(); it != g_links.end();) {
    char* building = kUnitById(world, it->first);
    const char* proto = building == nullptr ? nullptr : Field<const char*>(building, 0x5C);
    const auto tagged = proto == nullptr ? g_protos.end() : g_protos.find(Field<std::int32_t>(proto, 0x04));
    if (tagged == g_protos.end() || !IsAlive(building)) {
      it = g_links.erase(it);
      continue;
    }
    Link& link = it->second;
    if (const char* mine = SourceOf(world, link)) {
      if (kListGet(InventoryOf(mine) + 4, link.resource) > kMinAmount) {
        Mirror(building, mine, link.resource);
        ++it;
        continue;
      }
    }
    if (link.mine >= 0) {
      // The mine is gone or empty: its gold is over, and this building shows it.
      if (char* own = InventoryOf(building)) {
        kListSet(own + 4, link.resource, 0.0f);
      }
      LogLine(L"linkedResource: unit %d lost unit %d (%.0f left)", it->first, link.mine, 0.0);
      link.mine = -1;
    }
    if (now >= link.nextResolve && kIsBuilt(building)) {
      link.nextResolve = now + kResolveMs;
      Resolve(world, building, it->first, tagged->second, link);
    }
    ++it;
  }
}

}  // namespace

extern "C" {

// After the inventory of a unit is made: a tagged unit joins the links.
void __stdcall UhcLinkedRegister(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  if (g_uhcLinkedOn != 0 && proto != nullptr && g_protos.count(Field<std::int32_t>(proto, 0x04)) != 0) {
    g_links.try_emplace(Field<std::int32_t>(unit, 0x10));
  }
}

// From the head of 0x49A5E6. True: a take from a linked building went to its mine, and *result is what it gave.
std::int32_t __stdcall UhcLinkedInventory(char* inventory, std::int32_t resource, float amount, std::int32_t* result) {
  if (!(amount < 0.0f)) {
    return 0;
  }
  char* world = const_cast<char*>(World());
  char* building = world == nullptr ? nullptr : kUnitById(world, Field<std::int32_t>(inventory, 0));
  if (building == nullptr) {
    return 0;
  }
  Link* link = LinkOf(world, building);
  if (link == nullptr) {
    return 0;
  }
  char* mine = SourceOf(world, *link);
  if (mine == nullptr || resource != link->resource) {
    return 0;
  }
  *result = kInventoryAdd(InventoryOf(mine), link->resource, amount) ? 1 : 0;
  Mirror(building, mine, link->resource);
  kCheckState(mine);
  return 1;
}

// From the AutoGather update, before the add 0x4C3798. *amount is what it would pay, with the player's handicap in it:
// an action with the tag pays from what its source holds. As in the gather tick, the source loses the amount before the
// handicap and the player gets it after.
void __stdcall UhcLinkedAutoGather(const char* action, std::int32_t resource, float* amount) {
  if (g_uhcLinkedOn == 0 || !(*amount > 0.0f)) {
    return;
  }
  char* unit = Field<char*>(action, 0x10);
  const char* tactics = Field<const char*>(action, 0x04);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (proto == nullptr || tactics == nullptr ||
      g_gatherActions.count({Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(tactics, 0x04)}) == 0) {
    return;
  }
  char* world = const_cast<char*>(World());
  Link* link = world == nullptr ? nullptr : LinkOf(world, unit);
  char* mine = link == nullptr ? nullptr : SourceOf(world, *link);
  char* inventory = InventoryOf(mine != nullptr ? mine : unit);
  const float have = inventory == nullptr ? 0.0f : kListGet(inventory + 4, resource);
  const char* player = Field<const char*>(unit, 0x44);
  const float handicap = player == nullptr ? 1.0f : Field<float>(player, 0x37C);
  const float wanted = handicap > 0.0f ? *amount / handicap : *amount;
  const float take = have < wanted ? have : wanted;
  if (take > 0.0f) {
    kInventoryAdd(inventory, resource, -take);
    if (mine != nullptr) {
      Mirror(unit, mine, resource);
      kCheckState(mine);
    }
  }
  *amount = handicap > 0.0f ? take * handicap : take;
}
}

namespace uhc {

Outcome ApplyLinkedResource(const Config& config) {
  const Config::Args* args = config.First("linkedResource");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"linkedResource: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("linkedResource", {&sites::kInventoryAddHead, &sites::kInventoryRecreateHead, &sites::kAutoGatherPayPoint,
                                    &sites::kUnitsNearPoint, &sites::kUnitById, &sites::kIsA, &sites::kResListGet,
                                    &sites::kResListSet, &sites::kCheckState, &sites::kMainResource, &sites::kIsBuilt,
                                    &sites::kUnitAliveSlot}) ||
      !AddProtoTagHandler("LinkedResourceType", &ReadType) || !AddProtoTagHandler("LinkedResourceRange", &ReadRange) ||
      !AddActionTagHandler(&ActionTagRead) || !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&Tick) ||
      !WriteJmp(sites::kInventoryAddHead.va, reinterpret_cast<const void*>(&UhcLinkedInventoryHook), 5) ||
      !WriteJmp(sites::kInventoryRecreateHead.va, reinterpret_cast<const void*>(&UhcLinkedRecreateHook), 9) ||
      !WriteJmp(sites::kAutoGatherPayPoint.va, reinterpret_cast<const void*>(&UhcLinkedAutoGatherHook), 7)) {
    return Outcome::kFailed;
  }
  Log(L"linkedResource: the proto tags LinkedResourceType and LinkedResourceRange and the action tag GatherLinkedResource "
      L"are on (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/linkedresource_hooks.asm

```asm
; linkedResource (src/features/linkedresource.cpp). Each hook is entered through a jmp written over the stock code and
; leaves through an explicit jmp to a verified continuation, or returns for the function it replaces.
.686
.model flat, c
option casemap :none

include common.inc

UhcLinkedRegister PROTO STDCALL unit:DWORD
UhcLinkedInventory PROTO STDCALL inventory:DWORD, resource:DWORD, amount:DWORD, result:DWORD
UhcLinkedAutoGather PROTO STDCALL action:DWORD, resource:DWORD, amount:DWORD

EXTERNDEF g_uhcLinkedOn:DWORD

.data
inventoryNext   dd 0049A5EBh    ; push ebx: the rest of the stock add
recreateNext    dd 009BFE63h    ; mov eax,[eax+94h]
payNext         dd 004C3791h    ; mov ecx,[edx+44h] / push 0 / push edi / push ebx / call 49A98Ah

.code

; The stock add, for the C++ code, so that a call to it does not come back to the hook.
UhcLinkedInventoryStock PROC
    mov eax, dword ptr ds:[0C66234h]    ; replaced at 0x49A5E6
    jmp inventoryNext
UhcLinkedInventoryStock ENDP

; Replaces 0x49A5E6 (mov eax,[0xC66234]), the head of bool thiscall(inventory, resource, float), ret 8. ECX = the
; inventory. Nothing but ECX is an argument register, and the replaced line writes EAX.
UhcLinkedInventoryHook PROC
    cmp g_uhcLinkedOn, 0
    je stock
    TRACE_ONCE "linkedResource inventory (0x49A5E6)"
    push ecx
    sub esp, 4                      ; the result, written by the helper
    mov eax, esp
    push eax
    push dword ptr [esp+14h]        ; amount: [esp+8] at entry, +8 for the two above, +4 for this frame's push
    push dword ptr [esp+14h]        ; resource: [esp+4] at entry
    push ecx
    call UhcLinkedInventory
    test eax, eax
    pop eax                         ; the result
    pop ecx
    jne done
stock:
    jmp UhcLinkedInventoryStock
done:
    ret 8
UhcLinkedInventoryHook ENDP

; Runs the stock body of 0x9BFE5A, inventory recreate, up to its own ret: replaced push esi / mov esi,ecx /
; mov eax,[esi+0B4h].
recreateBody PROC
    push esi
    mov esi, ecx
    mov eax, dword ptr [esi+0B4h]
    jmp recreateNext
recreateBody ENDP

; Replaces those 9 bytes at 0x9BFE5A, thiscall(unit), plain ret, returns the inventory. After it a tagged unit joins
; the links; the helper keeps EBX, ESI, EDI and EBP, and the stock callers read only EAX of what is left.
UhcLinkedRecreateHook PROC
    TRACE_ONCE "linkedResource recreate (0x9BFE5A)"
    push ecx
    call recreateBody
    pop ecx
    push eax
    push ecx
    call UhcLinkedRegister
    pop eax
    ret
UhcLinkedRecreateHook ENDP

; Replaces 0x4C378A..0x4C3790 (mov edi,[esp+10h] / mov edx,[esi+10h]) before the AutoGather pay at 0x4C3798. ESI = the
; action, EBX = the resource, [esp+10h] = the amount. Nothing reads EAX or ECX before they are written.
UhcLinkedAutoGatherHook PROC
    TRACE_ONCE "linkedResource AutoGather (0x4C378A)"
    lea eax, [esp+10h]
    push eax
    push ebx
    push esi
    call UhcLinkedAutoGather
    mov edi, dword ptr [esp+10h]    ; replaced
    mov edx, dword ptr [esi+10h]    ; replaced
    jmp payNext
UhcLinkedAutoGatherHook ENDP

END
```

## resourceGatherAuras

Contract: [resourceGatherAuras](../porting-to-another-dll.md#resourcegatherauras).

Besides the core helpers, it needs: [`modifiers.h`](helpers.md#modifier-walk), [`modifytypes.h`](helpers.md#modify-types), [`unitinfo.h`](helpers.md#unit-info-for-the-panels), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `UnitById` `0x44CC6D` (58 B), `IsA` `0x44D7FA` (105 B), `SnareCollector` `0x49F34B` (121 B), `SnareModifierSum` `0x4B3C48` (183 B), `SnareModifierSumEnd` `0x4E2A8E` (27 B), `GatherDanceCall` `0x4ED02A` (5 B), `SnareModifierSumTactic` `0x6A88D6` (34 B), `UnitAttachModel` `0x9C04F3` (8 B), `UnitRemoveModel` `0x9C2885` (8 B), `UnitHasModel` `0x9C28DE` (8 B), `AuraHasModelCall` `0x9D0584` (5 B), `AuraHangModelCall` `0x9D06DC` (5 B).

### src/features/gatherauras.cpp

```cpp
// resourceGatherAuras: stat modifiers that change a unit's gather rate for one kind of target or one
// resource only.
//
// Stock: the modifier stat GatherRate (<ModifyType>GatherRate</ModifyType>) multiplies a unit's rate
// for everything it gathers (the record's +24h, read at 0x4ECFE9).
//
// With the key, seven more names are ModifyType stats (modifytypes.h): by what is gathered,
// MineGatherRate (AbstractMine), TreeGatherRate (Tree), FarmingGatherRate (AbstractFarm) and
// NaturalFoodGatherRate (food from anything else); and by resource, FoodGatherRate, WoodGatherRate
// and GoldGatherRate. The aura code needs no change: it gives the units in range a modifier of that
// stat, as for any stat, and the record recompute ignores it. The gather tick FUN_004ECD87 multiplies
// its rate by the dance factor of 0x4ECD39 (0x4ED02A). The call goes to a wrapper that multiplies in
// the stock sum 0x4B3C7D of the unit's modifiers of the stats that fit this target and resource,
// each from 1.0, with the GatherRate reader's rule: no modifier, or a sum below 1e-6, counts as 1.0.
// A unit with no modifier record pays one load.
//
// The aura update hangs the action's <ModelAttachment> on every unit in range, whatever it does, so a
// villager cutting wood under a MineGatherRate aura would wear a ring that means nothing. For these
// stats only, the two calls of the update that decide it (0x9D0584, has it; 0x9D06DC, a new target)
// go through wrappers that give the ring to the units gathering something the stat fits, and take it
// off the others, by the same rule as the factor. The hooks are in hooks/gatherauras_hooks.asm.
#include <bit>
#include <cstdint>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifiers.h"
#include "../modifytypes.h"
#include "../patch.h"
#include "../unitinfo.h"
#include "../unittypes.h"

extern "C" {
void UhcGatherAuraCall();
void UhcGatherAuraHasRingHook();
void UhcGatherAuraHangRingHook();
}

namespace {

constexpr std::int32_t kStatMine = 0x42;
constexpr std::int32_t kStatTree = 0x43;
constexpr std::int32_t kStatFarming = 0x44;
constexpr std::int32_t kStatNaturalFood = 0x45;
constexpr std::int32_t kStatFood = 0x46;
constexpr std::int32_t kStatWood = 0x47;
constexpr std::int32_t kStatGold = 0x48;
constexpr std::int32_t kResourceGold = 0;
constexpr std::int32_t kResourceWood = 1;
constexpr std::int32_t kResourceFood = 2;
constexpr float kMinFactor = 1.0e-6f;
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr std::uint32_t kGatherVtable = 0x00B97880;  // the Gather action
constexpr std::uint8_t kGatheringState = 5;          // [action+61h] while the tick runs (0x4ECC8E)

struct ModifierArray {
  const char* const* data;
  std::int32_t count;
};

using ModifierSumFn = bool(__thiscall*)(void* unused, float* value, const ModifierArray* list, std::int32_t stat);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using UnitByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);
const auto kModifierSum = reinterpret_cast<ModifierSumFn>(0x004B3C7D);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
using HasModelFn = bool(__thiscall*)(const char* unit, std::int32_t model);
using HangModelFn = bool(__thiscall*)(char* unit, const void* object, std::int32_t bone, std::int32_t flag);
using RemoveModelFn = void(__thiscall*)(char* unit, std::int32_t model);
const auto kHasModel = reinterpret_cast<HasModelFn>(0x009C28DE);
const auto kHangModel = reinterpret_cast<HangModelFn>(0x009C04F3);
const auto kRemoveModel = reinterpret_cast<RemoveModelFn>(0x009C2885);

std::int32_t g_mineType = -1;
std::int32_t g_treeType = -1;
std::int32_t g_farmType = -1;
bool g_log = false;
int g_logLines = 0;
constexpr int kMaxLogLines = 200;
std::vector<const char*> g_matched;  // only the game thread touches it

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// The stock sum over the unit's modifiers of one stat, from 1.0.
float StatFactor(const char* list, std::int32_t stat) {
  g_matched.clear();
  auto visit = [stat](const char* action) {
    if (Field<std::int32_t>(action, 0x64) == stat) {
      g_matched.push_back(action);
    }
    return true;
  };
  if (uhc::modifiers::WalkModifiers(list, visit, 0) != uhc::modifiers::Walk::kDone || g_matched.empty()) {
    return 1.0f;
  }
  const ModifierArray array{g_matched.data(), static_cast<std::int32_t>(g_matched.size())};
  float factor = 1.0f;
  if (!kModifierSum(nullptr, &factor, &array, stat) || factor < kMinFactor) {
    return 1.0f;
  }
  return factor;
}

// What a Gather action gathers, as the stats see it.
struct Gathers {
  const char* proto;
  std::int32_t resource;
};

Gathers WhatItGathers(const char* action) {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* target = kUnitById(Field<const char*>(game, 0x13C), Field<std::int32_t>(action, 0x14));
  return {target == nullptr ? nullptr : Field<const char*>(target, 0x5C), Field<std::int32_t>(action, 0x70)};
}

// True when the stat changes what this Gather action gathers: the rule of UhcGatherAuraFactor.
bool StatFits(std::int32_t stat, const Gathers& what) {
  switch (stat) {
    case kStatFood:
      return what.resource == kResourceFood;
    case kStatWood:
      return what.resource == kResourceWood;
    case kStatGold:
      return what.resource == kResourceGold;
    default:
      break;
  }
  if (what.proto == nullptr) {
    return false;
  }
  const bool mine = kProtoIsType(what.proto, g_mineType);
  const bool tree = !mine && kProtoIsType(what.proto, g_treeType);
  const bool farm = !mine && !tree && kProtoIsType(what.proto, g_farmType);
  switch (stat) {
    case kStatMine:
      return mine;
    case kStatTree:
      return tree;
    case kStatFarming:
      return farm;
    case kStatNaturalFood:
      return !mine && !tree && !farm && what.resource == kResourceFood;
    default:
      return false;
  }
}

bool IsGatherStat(const char* auraAction) {
  const std::int32_t stat = Field<std::int8_t>(Field<const char*>(auraAction, 0x04), 0xB8);
  return stat >= kStatMine && stat <= kStatGold;
}

// True when the unit is gathering, now, something the aura's stat changes.
bool GetsTheEffect(const char* auraAction, const char* unit) {
  const char* manager = Field<const char*>(unit, 0x58);
  const char* current = manager == nullptr ? nullptr : Field<const char*>(manager, 0x24);
  if (current == nullptr || Field<std::uint32_t>(current, 0) != kGatherVtable ||
      Field<std::uint8_t>(current, 0x61) != kGatheringState) {
    return false;
  }
  return StatFits(Field<std::int8_t>(Field<const char*>(auraAction, 0x04), 0xB8), WhatItGathers(current));
}

}  // namespace

// Replaces the has-it call in the aura update, for a unit that stays in range. True keeps the update
// from hanging the model, so it answers true for a unit that must not have it.
extern "C" bool __stdcall UhcGatherAuraHasRing(const char* auraAction, char* unit, std::int32_t model) {
  const bool has = kHasModel(unit, model);
  if (!IsGatherStat(auraAction) || GetsTheEffect(auraAction, unit)) {
    return has;
  }
  if (has) {
    kRemoveModel(unit, model);
  }
  return true;
}

// Replaces the hang call in the aura update, for a unit that has just come into range.
extern "C" bool __stdcall UhcGatherAuraHangRing(const char* auraAction, char* unit, const void* object,
                                                std::int32_t bone, std::int32_t flag) {
  if (IsGatherStat(auraAction) && !GetsTheEffect(auraAction, unit)) {
    return false;
  }
  return kHangModel(unit, object, bone, flag);
}

// From the wrapper of the dance factor's call in the gather tick. `action` is the Gather action:
// [+10h] the gatherer, [+14h] the target's ID, [+70h] the resource.
extern "C" float __stdcall UhcGatherAuraFactor(const char* action) {
  const char* unit = Field<const char*>(action, 0x10);
  const char* list = unit == nullptr ? nullptr : uhc::modifiers::ModifierList(unit);
  if (list == nullptr) {
    return 1.0f;
  }
  const Gathers what = WhatItGathers(action);
  const char* proto = what.proto;
  const std::int32_t resource = what.resource;
  float factor = 1.0f;
  if (proto != nullptr) {
    if (kProtoIsType(proto, g_mineType)) {
      factor *= StatFactor(list, kStatMine);
    } else if (kProtoIsType(proto, g_treeType)) {
      factor *= StatFactor(list, kStatTree);
    } else if (kProtoIsType(proto, g_farmType)) {
      factor *= StatFactor(list, kStatFarming);
    } else if (resource == kResourceFood) {
      factor *= StatFactor(list, kStatNaturalFood);
    }
  }
  if (resource == kResourceFood) {
    factor *= StatFactor(list, kStatFood);
  } else if (resource == kResourceWood) {
    factor *= StatFactor(list, kStatWood);
  } else if (resource == kResourceGold) {
    factor *= StatFactor(list, kStatGold);
  }
  if (g_log && factor != 1.0f && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"resourceGatherAuras: unit %d, resource %d, target %hs: x%.3f", Field<std::int32_t>(unit, 0x10), resource,
             proto == nullptr ? "?" : Field<const char*>(proto, 0x10), static_cast<double>(factor));
  }
  return factor;
}

namespace {
bool g_unitInfoOn = false;  // the key applied: unitinfo.h answers
}  // namespace

namespace uhc {

Outcome ApplyResourceGatherAuras(const Config& config) {
  const Config::Args* args = config.First("resourceGatherAuras");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"resourceGatherAuras: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("resourceGatherAuras", {&sites::kGatherDanceCall, &sites::kSnareCollector, &sites::kSnareModifierSum,
                                         &sites::kSnareModifierSumEnd, &sites::kSnareModifierSumTactic, &sites::kIsA,
                                         &sites::kUnitById, &sites::kAuraHasModelCall, &sites::kAuraHangModelCall,
                                         &sites::kUnitHasModel, &sites::kUnitAttachModel, &sites::kUnitRemoveModel})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType("AbstractMine", &g_mineType) || !RequestAbstractUnitType("Tree", &g_treeType) ||
      !RequestAbstractUnitType("AbstractFarm", &g_farmType) || !AddModifyType(L"MineGatherRate", kStatMine) ||
      !AddModifyType(L"TreeGatherRate", kStatTree) || !AddModifyType(L"FarmingGatherRate", kStatFarming) ||
      !AddModifyType(L"NaturalFoodGatherRate", kStatNaturalFood) || !AddModifyType(L"FoodGatherRate", kStatFood) ||
      !AddModifyType(L"WoodGatherRate", kStatWood) || !AddModifyType(L"GoldGatherRate", kStatGold)) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!WriteCall(sites::kGatherDanceCall.va, reinterpret_cast<const void*>(&UhcGatherAuraCall)) ||
      !WriteCall(sites::kAuraHasModelCall.va, reinterpret_cast<const void*>(&UhcGatherAuraHasRingHook)) ||
      !WriteCall(sites::kAuraHangModelCall.va, reinterpret_cast<const void*>(&UhcGatherAuraHangRingHook))) {
    return Outcome::kFailed;
  }
  Log(L"resourceGatherAuras: modifiers can change the gather rate of one kind of target or one resource%ls "
      L"(multiplayer unverified)",
      log ? L", the first factors logged" : L"");
  g_unitInfoOn = true;
  return Outcome::kApplied;
}

}  // namespace uhc

namespace uhc::unitinfo {

bool GatherAura(const char* unit, std::wstring* out) {
  const char* list = !g_unitInfoOn || unit == nullptr ? nullptr : uhc::modifiers::ModifierList(unit);
  if (list == nullptr) {
    return false;
  }
  static const wchar_t* const kNames[] = {L"mine", L"tree", L"farm", L"wild food", L"food", L"wood", L"gold"};
  out->clear();
  for (std::int32_t stat = kStatMine; stat <= kStatGold; ++stat) {
    const float factor = StatFactor(list, stat);
    if (factor != 1.0f) {
      wchar_t text[48];
      swprintf_s(text, L"%ls%+d%% %ls", out->empty() ? L"" : L" ",
                 static_cast<int>((factor - 1.0f) * 100.0f + (factor >= 1.0f ? 0.5f : -0.5f)), kNames[stat - kStatMine]);
      *out += text;
    }
  }
  return !out->empty();
}

}  // namespace uhc::unitinfo
```

### src/hooks/gatherauras_hooks.asm

```asm
; Wrapper for resourceGatherAuras: the target of the redirected call at 0x4ED02A
; (docs/engine-symbols.md, "Gathering and the stat panel").
.686
.model flat, c
option casemap :none

include common.inc

UhcGatherAuraFactor PROTO STDCALL action:DWORD
UhcGatherAuraHasRing PROTO STDCALL auraAction:DWORD, unit:DWORD, model:DWORD
UhcGatherAuraHangRing PROTO STDCALL auraAction:DWORD, unit:DWORD, object:DWORD, bone:DWORD, flag:DWORD

.data
danceFactor dd 004ECD39h    ; float thiscall(player): the Gathering dance factor

.code

; Replaces the target of call 4ECD39h at 0x4ED02A in the gather tick FUN_004ECD87. ECX = the
; gatherer's player, ESI = the Gather action, FPU stack empty. It returns the stock factor times the
; helper's, in ST0, as the stock call does; the tick reads no other register from it.
UhcGatherAuraCall PROC
    TRACE_ONCE "resourceGatherAuras (0x4ED02A)"
    call danceFactor
    sub esp, 4
    fstp dword ptr [esp]
    push esi
    call UhcGatherAuraFactor
    fmul dword ptr [esp]
    add esp, 4
    ret
UhcGatherAuraCall ENDP

; Replaces the target of call 9C28DEh at 0x9D0584 in the aura update FUN_009D033E, thiscall(unit,
; model), ret 4. ESI = the aura action. The update reads only AL after it.
UhcGatherAuraHasRingHook PROC
    TRACE_ONCE "resourceGatherAuras ring (0x9D0584)"
    invoke UhcGatherAuraHasRing, esi, ecx, dword ptr [esp+4]
    ret 4
UhcGatherAuraHasRingHook ENDP

; Replaces the target of call 9C04F3h at 0x9D06DC in the same update, thiscall(unit, object, bone,
; byte), ret 0Ch. ESI = the aura action. The update ignores the result.
UhcGatherAuraHangRingHook PROC
    TRACE_ONCE "resourceGatherAuras ring (0x9D06DC)"
    invoke UhcGatherAuraHangRing, esi, ecx, dword ptr [esp+4], dword ptr [esp+8], dword ptr [esp+0Ch]
    ret 0Ch
UhcGatherAuraHangRingHook ENDP

END
```

## resourceDebt

Contract: [resourceDebt](../porting-to-another-dll.md#resourcedebt).

Sites: `DebtAutoGate` `0x48D186` (6 B), `DebtAutoRate` `0x49EE07` (6 B), `DebtGatherGate` `0x4ED03E` (6 B), `DebtSetClamp` `0x6798F4` (13 B), `DebtShareClamp` `0x6799D4` (12 B), `DebtAddClamp` `0x679A0E` (13 B).

### src/features/resourcedebt.cpp

```cpp
// resourceDebt: only a player's trickles and the rates of its units may take a stockpile of the listed
// resources below 0.
//
// Stock: the add 0x49A98A clamps the sum at 0 at its cold part 0x679A0E, in its shared-resources path
// at 0x6799D4 (once per teammate), and the set 0x49A8C5 clamps its value at 0x6798F4.
// With the key each clamp asks UhcDebtFloor, by the return address of the add:
// - the global trickle (0x4E0CF9), unit AutoGather (0x4C3798) and the gather tick (0x4ED1EE) have no floor;
// - anything else (tech effects, triggers, costs, shipments) stops at 0, or at the debt the stockpile
//   already has: it neither digs a debt nor wipes one. An income on a debt keeps the rest of the debt.
// A set called by the add itself keeps what the add settled.
// Stock also stops negative rates before the add: the AutoGather getter returns 0 below 1e-6, its update
// skips an amount below 1e-6 and the gather tick ends the action at a rate of 1e-6 or less. The other
// three hooks let the negative rates of the listed resources through. A cost is compared with the
// stockpile, so a player in debt cannot pay until it is back above the cost. The hooks are in
// hooks/resourcedebt_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
std::uint8_t g_uhcDebtResources[16] = {};  // by resource index; 1: no floor at 0

void UhcDebtAddHook();
void UhcDebtSetHook();
void UhcDebtShareHook();
void UhcDebtAutoGateHook();
void UhcDebtAutoRateHook();
void UhcDebtGatherGateHook();
}

namespace {

struct ResourceName {
  const char* name;
  int index;
};
constexpr ResourceName kResources[] = {{"Gold", 0}, {"Coin", 0}, {"Wood", 1}, {"Food", 2}};
constexpr int kMaxLogLines = 200;
// Where the add returns to in the three callers that have no floor.
constexpr std::uint32_t kGlobalTrickle = 0x004E0CFE;
constexpr std::uint32_t kUnitAutoGather = 0x004C379D;
constexpr std::uint32_t kGatherTick = 0x004ED1F3;
constexpr std::size_t kStockpiles = 0x230;  // [player+230h], the stockpile array

using StockpileFn = float(__thiscall*)(const void* stockpiles, std::int32_t resource);
const auto kStockpile = reinterpret_cast<StockpileFn>(0x0044EFFF);

bool g_log = false;
int g_logLines = 0;

}  // namespace

// From the clamps, for a listed resource. `value` holds a sum or value below 1e-6; `caller` is where
// the add or the set returns to.
extern "C" void __stdcall UhcDebtFloor(const char* player, std::int32_t resource, float* value,
                                       std::uint32_t caller) {
  const bool source = caller == kGlobalTrickle || caller == kUnitAutoGather || caller == kGatherTick;
  const float before = *value;
  if (!source) {
    const float current = kStockpile(player + kStockpiles, resource);
    *value = current < 0.0f ? (before > current ? before : current) : 0.0f;
  }
  if (!g_log || g_logLines >= kMaxLogLines || before >= 0.0f) {
    return;
  }
  ++g_logLines;
  uhc::Log(L"resourceDebt: player %d, resource %d, from 0x%08X: %.1f%ls", *reinterpret_cast<const std::int32_t*>(player),
           resource, caller, static_cast<double>(*value), *value == before ? L"" : L" (held by the floor)");
}

namespace uhc {

Outcome ApplyResourceDebt(const Config& config) {
  const Config::Args* args = config.First("resourceDebt");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::string list;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    int index = -1;
    for (const ResourceName& resource : kResources) {
      if (_stricmp(arg.c_str(), resource.name) == 0) {
        index = resource.index;
      }
    }
    if (index < 0) {
      Log(L"resourceDebt: unknown resource %hs (expected: Food, Wood, Gold); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_uhcDebtResources[index] = 1;
    list += (list.empty() ? "" : " ") + arg;
  }
  if (list.empty()) {
    g_uhcDebtResources[0] = g_uhcDebtResources[1] = g_uhcDebtResources[2] = 1;
    list = "Food Wood Gold";
  }
  if (!VerifyAll("resourceDebt", {&sites::kDebtAddClamp, &sites::kDebtSetClamp, &sites::kDebtShareClamp,
                                  &sites::kDebtAutoGate, &sites::kDebtAutoRate, &sites::kDebtGatherGate})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kDebtAddClamp.va, reinterpret_cast<const void*>(&UhcDebtAddHook), 8) ||
      !WriteJmp(sites::kDebtSetClamp.va, reinterpret_cast<const void*>(&UhcDebtSetHook), 8) ||
      !WriteJmp(sites::kDebtShareClamp.va, reinterpret_cast<const void*>(&UhcDebtShareHook), 8) ||
      !WriteJmp(sites::kDebtAutoGate.va, reinterpret_cast<const void*>(&UhcDebtAutoGateHook), 6) ||
      !WriteJmp(sites::kDebtAutoRate.va, reinterpret_cast<const void*>(&UhcDebtAutoRateHook), 6) ||
      !WriteJmp(sites::kDebtGatherGate.va, reinterpret_cast<const void*>(&UhcDebtGatherGateHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"resourceDebt: trickles and unit rates may take %hs below 0 (multiplayer unverified)", list.c_str());
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/resourcedebt_hooks.asm

```asm
; Hooks for resourceDebt. Entered through a jmp written over the stock code; each leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Resource debt").
.686
.model flat, c
option casemap :none

include common.inc

EXTERN g_uhcDebtResources:BYTE
UhcDebtFloor PROTO STDCALL player:DWORD, resource:DWORD, value:DWORD, caller:DWORD

.data
addNext       dd 0049A9D0h    ; mov ecx,[esp+18h]: the add goes on to the set
setNext       dd 0049A8E3h    ; mov edi,[esp+70h]: the set goes on
shareNext     dd 006799DCh    ; mov ecx,[esp+20h]: the shared add goes on to the set
autoGo        dd 004C0F1Fh    ; mov ecx,[esi+4]: the AutoGather update books the amount
autoSkip      dd 0048D18Ch    ; the AutoGather update's next resource
rateGo        dd 004C0A34h    ; cmp dword ptr [edi],0: the getter returns the rate it computed
rateZero      dd 0049EE0Dh    ; fld 0: the getter returns 0
gatherGo      dd 004ED044h    ; fmul [esp+30h]: the gather tick goes on
gatherEnd     dd 006A8AEAh    ; the gather tick ends the action

.code

; Replaces 0x679A0E (mov dword ptr [esp+10h],0), the clamp of the add 0x49A98A, reached when the sum
; is below 1e-6. EBP = the player, ESI = the resource; [esp+0Ch] the add's return address, [esp+10h]
; the sum. EAX is free: the continuation reloads it. FPU stack empty.
UhcDebtAddHook PROC
    TRACE_ONCE "resourceDebt add (0x679A0E)"
    cmp esi, 16
    jae clamp
    cmp byte ptr g_uhcDebtResources[esi], 0
    je clamp
    lea eax, dword ptr [esp+10h]
    pushad
    push dword ptr [eax-4]
    push eax
    push esi
    push ebp
    call UhcDebtFloor
    popad
    jmp addNext
clamp:
    mov dword ptr [esp+10h], 0      ; stolen 0x679A0E
    jmp addNext
UhcDebtAddHook ENDP

; Replaces 0x6798F4 (mov dword ptr [esp+74h],0), the clamp of the set 0x49A8C5. ESI = the player,
; [esp+6Ch] the set's return address, [esp+70h] the resource, [esp+74h] the value. A value from the
; add's own two calls (returns 0x49A9E2 and 0x6799EE) was settled by the two hooks of the add. EAX is
; free: the continuation writes it before reading it. FPU stack empty.
UhcDebtSetHook PROC
    TRACE_ONCE "resourceDebt set (0x6798F4)"
    mov eax, dword ptr [esp+70h]
    cmp eax, 16
    jae clamp
    cmp byte ptr g_uhcDebtResources[eax], 0
    je clamp
    cmp dword ptr [esp+6Ch], 0049A9E2h
    je settled
    cmp dword ptr [esp+6Ch], 006799EEh
    je settled
    lea ecx, dword ptr [esp+74h]
    pushad
    push dword ptr [ecx-8]
    push ecx
    push eax
    push esi
    call UhcDebtFloor
    popad
settled:
    jmp setNext
clamp:
    mov dword ptr [esp+74h], 0      ; stolen 0x6798F4
    jmp setNext
UhcDebtSetHook ENDP

; Replaces 0x6799D4 (mov dword ptr [esp+18h],0), the clamp of the add's shared-resources path, once
; per teammate. EDI = the teammate, EBP = the resource; [esp+14h] the add's return address, [esp+18h]
; the sum. EAX is free: the continuation does not read it. FPU stack empty.
UhcDebtShareHook PROC
    TRACE_ONCE "resourceDebt shared add (0x6799D4)"
    cmp ebp, 16
    jae clamp
    cmp byte ptr g_uhcDebtResources[ebp], 0
    je clamp
    lea eax, dword ptr [esp+18h]
    pushad
    push dword ptr [eax-4]
    push eax
    push ebp
    push edi
    call UhcDebtFloor
    popad
    jmp shareNext
clamp:
    mov dword ptr [esp+18h], 0      ; stolen 0x6799D4
    jmp shareNext
UhcDebtShareHook ENDP

; Replaces 0x48D186 (jp 0x4C0F1F), in the AutoGather update: stock books an amount of 1e-6 or more
; (the flags come from its test) and skips the rest. Here a negative amount of a listed resource is
; booked too. EBX = the resource, [esp+10h] the amount.
UhcDebtAutoGateHook PROC
    jp book
    TRACE_ONCE "resourceDebt AutoGather gate (0x48D186)"
    cmp ebx, 16
    jae skip
    cmp byte ptr g_uhcDebtResources[ebx], 0
    je skip
    test dword ptr [esp+10h], 80000000h
    je skip
book:
    jmp autoGo
skip:
    jmp autoSkip
UhcDebtAutoGateHook ENDP

; Replaces 0x49EE07 (jp 0x4C0A34), at the end of the AutoGather rate getter 0x49EBE4: stock returns a
; rate of 1e-6 or more (the flags come from its test) and 0 for the rest. Here a negative rate of a
; listed resource is returned too. EBX = the resource, [esp+14h] the rate.
UhcDebtAutoRateHook PROC
    jp keep
    TRACE_ONCE "resourceDebt AutoGather rate (0x49EE07)"
    cmp ebx, 16
    jae zero
    cmp byte ptr g_uhcDebtResources[ebx], 0
    je zero
    test dword ptr [esp+14h], 80000000h
    je zero
keep:
    jmp rateGo
zero:
    jmp rateZero
UhcDebtAutoRateHook ENDP

; Replaces 0x4ED03E (jnp 0x6A8AEA), in the gather tick: stock ends the action at a rate of 1e-6 or
; less (the flags come from its test). Here a negative rate of a listed resource goes on. ST0 = the
; rate, kept; [esi+70h] the resource. EAX is free: fnstsw just wrote it.
UhcDebtGatherGateHook PROC
    jnp small
    jmp gatherGo
small:
    TRACE_ONCE "resourceDebt gather gate (0x4ED03E)"
    mov eax, dword ptr [esi+70h]
    cmp eax, 16
    jae stop
    cmp byte ptr g_uhcDebtResources[eax], 0
    je stop
    ftst
    fnstsw ax
    test ah, 1                      ; below 0?
    je stop
    jmp gatherGo
stop:
    jmp gatherEnd
UhcDebtGatherGateHook ENDP

END
```

## truckAttackResourceFix

Contract: [truckAttackResourceFix](../porting-to-another-dll.md#truckattackresourcefix).

Sites: `IsAbstractIndex` `0x44CAC4` (70 B), `TruckAttackInventoryReset` `0x9EC635` (24 B).

### src/features/truckattack.cpp

```cpp
// truckAttackResourceFix [log]: a TruckAttack no longer empties the buildings it hits.
//
// The stock TruckAttack action (BUnitTruckAttackAction, vtable 0xB98468; the tactics type `TruckAttack`, used by the
// stock monster truck and, in mods, by poison clouds, plagues, tornadoes and fires) hits
// every unit in its range a few times a second (0x9EC4E1, from its update 0x9EC6D4): for each target of another
// player that is alive, built and allowed, it first sets the target's whole resource inventory
// [[unit+0B4h]+94h] to 0 (0x58F070), then deals the damage. On a building that holds resources, a Mill (999 food), a
// plantation, a rice paddy, that leaves it empty for good: its <UnlimitedSupply> does not refill it, and villagers
// sent to it stand idle beside it. The key skips the reset when the target is a building (abstract index 2, the test
// the damage function uses); the damage is unchanged, and units (a hunt, a villager) are still emptied as before.
//
// The hook is at 0x9EC635 (hooks/truckattack_hooks.asm). Everything it reads is simulation state, on every machine.
#include <cstdint>
#include <set>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcTruckInventoryHook();

namespace {

using IsAbstractIndexFn = bool(__thiscall*)(const void* proto, std::int32_t index);
const auto kIsAbstractIndex = reinterpret_cast<IsAbstractIndexFn>(0x0044CAC4);
constexpr std::int32_t kBuildingIndex = 2;
constexpr std::size_t kMaxLogged = 200;

bool g_log = false;
std::set<std::int32_t> g_logged;  // log only: the buildings already named

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

const char* NameOf(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

std::int32_t PlayerOf(const char* unit) {
  const char* player = unit == nullptr ? nullptr : Field<const char*>(unit, 0x44);
  return player == nullptr ? -1 : Field<std::int32_t>(player, 0);
}

}  // namespace

// From the hook: true when the target keeps its resources (it is a building).
extern "C" bool __stdcall UhcTruckKeepsInventory(const char* action, const char* target) {
  const char* proto = target == nullptr ? nullptr : Field<const char*>(target, 0x5C);
  if (proto == nullptr || !kIsAbstractIndex(proto, kBuildingIndex)) {
    return false;
  }
  if (g_log && g_logged.size() < kMaxLogged && g_logged.insert(Field<std::int32_t>(target, 0x10)).second) {
    const char* attacker = action == nullptr ? nullptr : Field<const char*>(action, 0x10);
    uhc::Log(L"truckAttackResourceFix: unit %d (%hs, player %d) hit by unit %d (%hs, player %d): its resources kept",
             Field<std::int32_t>(target, 0x10), NameOf(target), PlayerOf(target),
             attacker == nullptr ? -1 : Field<std::int32_t>(attacker, 0x10), NameOf(attacker), PlayerOf(attacker));
  }
  return true;
}

namespace uhc {

Outcome ApplyTruckAttackResourceFix(const Config& config) {
  const Config::Args* args = config.First("truckAttackResourceFix");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"truckAttackResourceFix: unknown option %hs (expected [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("truckAttackResourceFix", {&sites::kTruckAttackInventoryReset, &sites::kIsAbstractIndex})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kTruckAttackInventoryReset.va, reinterpret_cast<const void*>(&UhcTruckInventoryHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"truckAttackResourceFix: a TruckAttack no longer empties the buildings it hits (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/truckattack_hooks.asm

```asm
; Hook for truckAttackResourceFix (src/features/truckattack.cpp). Replaces the inventory reset of the TruckAttack
; hit at 0x9EC635 (EBP = the action, EDI = the target, EBX = 0; EAX, ECX and EDX are written before they are read on
; both continuations). A building keeps its resources: the hook goes on at the damage, 0x9EC64D. Any other target
; re-executes mov edx,[edi+0B4h] and goes on at 0x9EC63B, the stock reset.
.686
.model flat, c
option casemap :none

include common.inc

UhcTruckKeepsInventory PROTO STDCALL action:DWORD, target:DWORD

.data
truckReset  dd 009EC63Bh   ; mov eax,[edx+94h] / ... / call 58F070h
truckDamage dd 009EC64Dh   ; mov ecx,[edi+5Ch]: the damage

.code

UhcTruckInventoryHook PROC
    TRACE_ONCE "truckAttackResourceFix (0x9EC635)"
    push edi
    push ebp
    call UhcTruckKeepsInventory
    test al, al
    jnz keep
    mov edx, dword ptr [edi+0B4h]
    jmp truckReset
keep:
    jmp truckDamage
UhcTruckInventoryHook ENDP

END
```

## autoGatherFrom

Contract: [autoGatherFrom](../porting-to-another-dll.md#autogatherfrom).

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `XmlText` `0x402733` (9 B), `UnitById` `0x44CC6D` (58 B), `IsA` `0x44D7FA` (105 B), `IsBuilt` `0x44DDB4` (31 B), `AutoScoutIdle` `0x44F1A7` (8 B), `PlayerIsEnemy` `0x484D2D` (32 B), `UnitIsSeeable` `0x48A9EF` (59 B), `UnitsNearPoint` `0x4A1C55` (248 B), `MainResource` `0x4DBEC1` (16 B), `HeldAmount` `0x4E5979` (20 B), `GatherWorkOrder` `0x4EFCB2` (14 B), `XmlAttribute` `0x598F37` (16 B), `UnitAliveSlot` `0xB9355C` (4 B).

### src/features/autogatherfrom.cpp

```cpp
// autoGatherFrom [log]: a unit idle for a few seconds gathers on its own from a unit of a type named in its action.
//
//   <action> <type>Gather</type> <maxrange>6</maxrange> ...
//     <AutogatherFrom delay="3">AbstractTypeHerdableMagnet</AutogatherFrom>   (a proto or a unit type; delay in
//   </action>                                                                    seconds, 3 when absent)
//
// The tag goes in any action of a .tactics file or a protoy.xml <ProtoAction> (the shared action tag hook,
// actiontags.h); an action may hold several. Its range is the longest of the action's ranges (maxrange and its
// typedmaxrange entries: [action+18h], 16-byte entries, count [action+1Ch], +8 the maximum).
//
// After each world update (worldtick.h), every 500 ms of game time, for every unit of every player (the player's unit
// list [player+F8h], in ID order) whose proto has a tagged action:
// - a unit that is busy (its current action [[unit+58h]+24h] is not null, 0x44F1A7) is left alone: a player's order,
//   a fight or a gather in progress always wins; while it gathers (Gather action, vtable 0xB97880) its leash anchor
//   [mgr+7Ch] follows it, so that a unit that followed a moving target does not walk back to where it started;
// - a unit idle for `delay` seconds of game time gets a work order (0x4EFCB2, the order the stock herdable search
//   0x4C31EE gives: thiscall(mgr, targetId, 0, -1, 0)) on the nearest unit of a tagged type within the action's range
//   (0x4A1C55; distance to the target's edge, its vtable +B8h), owned by the unit's player, an ally or Gaia, alive;
//   the stock order code then picks the action and walks the unit as a right-click would; a target the player cannot
//   see (0x48A9EF, the test the Gather update makes before it drops such an order, 0x4EC753) is not picked;
// - a unit that gained nothing (its held amount 0x4E5979 did not rise) from the last order to the same target is
//   not sent there again until its amount changes: a fattened herdable, for one, is refused by the gather tick.
// Inside a building or a transport ([unit+6Ch] != -1), not built (0x44DDB4), or without an inventory
// ([[unit+B4h]+94h], which the gather start requires of the gatherer, 0x50DE89), a unit is skipped.
// A unit that cannot move (MaxVelocity [proto+80h] at 0: a building) is ordered only while buildingGather is on, since
// its Gather action never starts otherwise; its target must pass the gather's own range test (its vtable +CCh with the
// action's range, which counts its size), as a building cannot walk closer.
//
// Everything read is simulation state (no local player, no clock but the game time [world+108h]); the per-unit table
// is only a cache (idle-since time, last target, held amount): a loaded game rebuilds it, and a unit idle at the load
// waits `delay` again.
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <cwctype>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kScanMs = 500;
constexpr std::uint32_t kGatherVtable = 0x00B97880;
constexpr std::int32_t kDefaultDelayMs = 3000;
constexpr float kSearchSlack = 12.0f;  // metres added to the search radius: the largest target's half size
constexpr int kMaxLogLines = 300;

struct IdList {
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using UnitsNearFn = std::int32_t(__thiscall*)(const char* world, const float* point, float radius, char precise, IdList* out);
using IdleFn = bool(__thiscall*)(const char* mgr);
using UnitTestFn = bool(__thiscall*)(const char* unit);
using IsEnemyFn = bool(__thiscall*)(const char* player, std::int32_t otherId);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using HeldAmountFn = float(__thiscall*)(const char* unit, std::int32_t resource);
using MainResourceFn = std::int32_t(__thiscall*)(const char* unit);
using DistanceFn = float(__thiscall*)(const char* unit, const float* point);
using WorkOrderFn = bool(__thiscall*)(char* mgr, std::int32_t target, std::int32_t a2, std::int32_t a3, std::int32_t a4);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);

const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);
const auto kIdle = reinterpret_cast<IdleFn>(0x0044F1A7);
const auto kIsBuilt = reinterpret_cast<UnitTestFn>(0x0044DDB4);
const auto kIsEnemy = reinterpret_cast<IsEnemyFn>(0x00484D2D);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kHeldAmount = reinterpret_cast<HeldAmountFn>(0x004E5979);
const auto kMainResource = reinterpret_cast<MainResourceFn>(0x004DBEC1);
const auto kWorkOrder = reinterpret_cast<WorkOrderFn>(0x004EFCB2);
using InRangeFn = bool(__thiscall*)(const char* unit, const char* target, float range);
using SeeableFn = bool(__thiscall*)(const char* unit, std::int32_t player);
const auto kIsSeeable = reinterpret_cast<SeeableFn>(0x0048A9EF);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

// One <AutogatherFrom> tag.
struct Source {
  std::string name;
  std::int32_t type = -2;  // unittype ID (proto or abstract type); -2 not looked up yet, -1 unknown
  std::int32_t delayMs = kDefaultDelayMs;
};

struct ActionKey {
  std::int32_t proto;  // [proto+4]
  std::int32_t name;   // [action+4]
  auto operator<=>(const ActionKey&) const = default;
};

std::map<ActionKey, std::vector<Source>> g_tags;
std::map<std::int32_t, std::vector<ActionKey>> g_byProto;  // proto ID -> its tagged actions

// What a unit's proto (the player's copy) gathers from: the sources of its tagged actions, each with that action's
// range. A cache by proto pointer, emptied with the data.
struct Want {
  const Source* source;
  float range;
};
std::unordered_map<const char*, std::vector<Want>> g_wants;

struct Unit {
  std::uint32_t idleSince = 0;  // game time, 0 while busy
  std::int32_t lastTarget = -1;
  float heldAtOrder = -1.0f;    // the held amount when it was last ordered to lastTarget
  bool refused = false;         // that order gained nothing: not again until the amount changes
};
std::map<std::int32_t, Unit> g_units;

bool g_log = false;
int g_logLines = 0;
std::set<std::string> g_badNames;  // bad values already logged since the data load
std::uint32_t g_lastScan = 0;
std::uint32_t g_lastTime = 0;
const char* g_lastWorld = nullptr;
IdList g_found = {nullptr, 0, 0};

}  // namespace

bool g_uhcBuildingGather = false;  // buildinggather.cpp sets it when that key is applied

namespace {

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* World() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

const char* Database() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

bool Alive(const char* unit) { return Field<UnitTestFn const*>(unit, 0)[0xA4 / 4](unit); }

std::int32_t OwnerId(const char* unit) {
  const char* player = Field<const char*>(unit, 0x44);
  return player == nullptr ? -1 : Field<std::int32_t>(player, 0);
}

const char* PlayerAt(const char* world, std::int32_t id) {
  return id < 0 || id >= Field<std::int32_t>(world, 0x5C) ? nullptr : Field<const char* const*>(world, 0x58)[id];
}

void Note(const wchar_t* format, ...) {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return;
  }
  ++g_logLines;
  wchar_t text[512];
  va_list args;
  va_start(args, format);
  _vsnwprintf_s(text, _TRUNCATE, format, args);
  va_end(args);
  uhc::Log(L"%ls", text);
}

// ---- the tag ---------------------------------------------------------------------------------------------------

std::int32_t DelayOf(const char* node) {
  for (const char* name : {"delay", "Delay", "DELAY"}) {
    const void* text = nullptr;
    if (node != nullptr && kXmlAttribute(node, name, &text) && text != nullptr) {
      const char* value = kXmlText(text);
      char* end = nullptr;
      const double seconds = value == nullptr ? -1.0 : std::strtod(value, &end);
      if (value == nullptr || end == value || !(seconds >= 0.0) || seconds > 3600.0) {
        const std::string bad = value == nullptr ? "" : value;
        if (g_badNames.insert("delay=" + bad).second) {  // once per load: every proto of a tactics file reads it
          uhc::Log(L"autoGatherFrom: delay=\"%hs\" is not a number of seconds from 0 to 3600; 3 s", bad.c_str());
        }
        return kDefaultDelayMs;
      }
      return static_cast<std::int32_t>(seconds * 1000.0 + 0.5);
    }
  }
  return kDefaultDelayMs;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  if (_wcsicmp(tag.name, L"AutogatherFrom") != 0) {
    return;
  }
  Source source;
  for (const wchar_t* c = tag.text; c != nullptr && *c != 0; ++c) {
    if (!std::iswspace(*c)) {
      source.name.push_back(static_cast<char>(*c));
    }
  }
  const ActionKey key{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)};
  if (source.name.empty()) {
    uhc::Log(L"autoGatherFrom: proto %d: an empty <AutogatherFrom> is ignored", key.proto);
    return;
  }
  source.delayMs = DelayOf(tag.node);
  auto& list = g_tags[key];
  if (list.empty()) {
    g_byProto[key.proto].push_back(key);
  }
  list.push_back(source);
}

void NewDatabase(char*) {
  g_tags.clear();
  g_byProto.clear();
  g_wants.clear();
  g_units.clear();
  g_badNames.clear();
  g_logLines = 0;
}

std::int32_t TypeOf(Source& source) {
  if (source.type != -2) {
    return source.type;
  }
  source.type = -1;
  const char* database = Database();
  if (database == nullptr) {
    return -1;
  }
  const char* table = database + 0x190;
  std::int32_t id = -1;
  const std::int32_t bucket = kNameBucket(table, source.name.c_str());
  if (kNameFind(table, source.name.c_str(), bucket, &id)) {
    source.type = id;
  } else {
    if (g_badNames.insert(source.name).second) {
      uhc::Log(L"autoGatherFrom: <AutogatherFrom>%hs names no proto or unit type; ignored", source.name.c_str());
    }
  }
  return source.type;
}

// The longest range of an action: its range entries [action+18h] (16 bytes each, count [action+1Ch], +8 the maximum).
float RangeOf(const char* action) {
  const char* ranges = Field<const char*>(action, 0x18);
  const std::int32_t count = Field<std::int32_t>(action, 0x1C);
  float longest = 0.0f;
  for (std::int32_t i = 0; ranges != nullptr && i < count && i < 64; ++i) {
    longest = std::max(longest, Field<float>(ranges, 16u * i + 8));
  }
  return longest;
}

const std::vector<Want>& WantsOf(const char* proto) {
  const auto found = g_wants.find(proto);
  if (found != g_wants.end()) {
    return found->second;
  }
  std::vector<Want>& wants = g_wants[proto];
  const auto tagged = g_byProto.find(Field<std::int32_t>(proto, 0x04));
  const char* set = Field<const char*>(proto, 0x44);
  if (tagged == g_byProto.end() || set == nullptr) {
    return wants;
  }
  const char* const* actions = Field<const char* const*>(set, 0x1C);
  const std::int32_t count = Field<std::int32_t>(set, 0x20);
  for (const ActionKey& key : tagged->second) {
    for (std::int32_t i = 0; actions != nullptr && i < count; ++i) {
      const char* action = actions[i];
      if (action == nullptr || Field<std::int32_t>(action, 0x04) != key.name) {
        continue;
      }
      const float range = RangeOf(action);
      for (Source& source : g_tags[key]) {
        if (TypeOf(source) >= 0) {
          wants.push_back({&source, range});
        }
      }
      break;
    }
  }
  return wants;
}

// ---- the scan --------------------------------------------------------------------------------------------------

float Held(const char* unit) {
  const std::int32_t resource = kMainResource(unit);
  return resource < 0 ? 0.0f : kHeldAmount(unit, resource);
}

void SetAnchor(char* unit) {
  char* mgr = Field<char*>(unit, 0x58);
  for (std::uint32_t i = 0; i < 3; ++i) {
    *reinterpret_cast<float*>(mgr + 0x7C + 4 * i) = Field<float>(unit, 0x14 + 4 * i);
  }
}

// The nearest unit of a wanted type within its action's range, that the unit's player may gather from.
std::int32_t PickTarget(const char* world, const char* unit, std::int32_t player, const std::vector<Want>& wants,
                        const Unit& state, bool immobile, float* outDistance, std::int32_t* outDelay) {
  const auto inRange = Field<InRangeFn const*>(unit, 0)[0xCC / 4];
  const float* position = reinterpret_cast<const float*>(unit + 0x14);
  float radius = 0.0f;
  for (const Want& want : wants) {
    radius = std::max(radius, want.range);
  }
  g_found.count = 0;
  kUnitsNear(world, position, radius + kSearchSlack, 1, &g_found);
  const char* me = PlayerAt(world, player);
  const std::int32_t selfId = Field<std::int32_t>(unit, 0x10);
  std::int32_t best = -1;
  float bestDistance = 0.0f;
  for (std::int32_t i = 0; g_found.data != nullptr && i < g_found.count; ++i) {
    const std::int32_t id = g_found.data[i];
    const char* other = id == selfId ? nullptr : UnitById(world, id);
    const char* proto = other == nullptr ? nullptr : Field<const char*>(other, 0x5C);
    if (proto == nullptr || !Alive(other) || (state.refused && id == state.lastTarget) || !kIsSeeable(other, player)) {
      continue;
    }
    const std::int32_t owner = OwnerId(other);
    if (owner != 0 && owner != player && (me == nullptr || kIsEnemy(me, owner))) {
      continue;
    }
    const float distance = Field<DistanceFn const*>(other, 0)[0xB8 / 4](other, position);
    for (const Want& want : wants) {
      if ((immobile ? inRange(unit, other, want.range) : distance <= want.range) &&
          kProtoIsType(proto, want.source->type) &&
          (best < 0 || distance < bestDistance || (distance == bestDistance && id < best))) {
        best = id;
        bestDistance = distance;
        *outDelay = want.source->delayMs;
      }
    }
  }
  *outDistance = bestDistance;
  return best;
}

std::int32_t DelayFor(const std::vector<Want>& wants) {
  std::int32_t delay = wants.empty() ? kDefaultDelayMs : wants.front().source->delayMs;
  for (const Want& want : wants) {
    delay = std::min(delay, want.source->delayMs);
  }
  return delay;
}

void Scan(char* world, std::uint32_t now) {
  if (g_byProto.empty()) {
    return;
  }
  const std::int32_t players = Field<std::int32_t>(world, 0x5C);
  std::map<std::int32_t, Unit> seen;
  for (std::int32_t p = 1; p < players; ++p) {
    const char* player = PlayerAt(world, p);
    if (player == nullptr) {
      continue;
    }
    const std::int32_t* ids = Field<const std::int32_t*>(player, 0xF8);
    const std::int32_t count = Field<std::int32_t>(player, 0xFC);
    std::vector<std::int32_t> sorted(ids == nullptr ? 0 : count);
    for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
      sorted[i] = ids[i];
    }
    std::sort(sorted.begin(), sorted.end());
    for (const std::int32_t id : sorted) {
      char* unit = UnitById(world, id);
      const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
      if (proto == nullptr || OwnerId(unit) != p || Field<std::int32_t>(unit, 0x6C) != -1 ||
          Field<const char*>(unit, 0x58) == nullptr) {
        continue;
      }
      const std::vector<Want>& wants = WantsOf(proto);
      if (wants.empty() || !Alive(unit) || !kIsBuilt(unit)) {
        continue;
      }
      const char* record = Field<const char*>(unit, 0xB4);
      if (record == nullptr || Field<const char*>(record, 0x94) == nullptr) {
        continue;  // no inventory: the gather start refuses such a gatherer (0x50DE89, setState 9)
      }
      const bool immobile = Field<float>(proto, 0x80) <= 0.0f;
      if (immobile && !g_uhcBuildingGather) {
        continue;  // a building's Gather action never starts without buildingGather
      }
      auto old = g_units.find(id);
      Unit state = old == g_units.end() ? Unit{} : old->second;
      char* mgr = Field<char*>(unit, 0x58);
      const float held = Held(unit);
      if (state.refused && held != state.heldAtOrder) {
        state.refused = false;  // its amount changed: it may be sent there again
      }
      if (!kIdle(mgr)) {
        state.idleSince = 0;
        const char* action = Field<const char*>(mgr, 0x24);
        if (action != nullptr && Field<std::uint32_t>(action, 0) == kGatherVtable) {
          SetAnchor(unit);
        }
        seen[id] = state;
        continue;
      }
      if (state.idleSince == 0) {
        state.idleSince = now;
        if (!immobile && state.lastTarget >= 0 && state.heldAtOrder >= 0.0f && held <= state.heldAtOrder) {
          state.refused = true;  // the last order gained nothing (a building's gather goes to the stockpile: never)
          state.heldAtOrder = held;
        }
      }
      if (now - state.idleSince < static_cast<std::uint32_t>(DelayFor(wants))) {
        seen[id] = state;
        continue;
      }
      float distance = 0.0f;
      std::int32_t delay = kDefaultDelayMs;
      const std::int32_t target = PickTarget(world, unit, p, wants, state, immobile, &distance, &delay);
      if (target >= 0 && now - state.idleSince >= static_cast<std::uint32_t>(delay)) {
        const bool ok = kWorkOrder(mgr, target, 0, -1, 0);
        Note(L"autoGatherFrom: unit %d (player %d, proto %d) idle %.1f s -> unit %d, %.1f m: %ls", id, p,
             Field<std::int32_t>(proto, 0x04), (now - state.idleSince) / 1000.0, target, static_cast<double>(distance),
             ok ? L"ordered" : L"refused");
        if (target != state.lastTarget) {
          state.refused = false;
        }
        state.lastTarget = target;
        state.heldAtOrder = held;
        state.idleSince = ok ? 0 : now;  // refused: try again after the delay
      }
      seen[id] = state;
    }
  }
  g_units.swap(seen);  // units gone or no longer tagged are forgotten
}

void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_lastWorld || now < g_lastTime) {
    g_units.clear();
    g_lastScan = 0;
    g_lastWorld = world;
  }
  g_lastTime = now;
  if (g_lastScan != 0 && now - g_lastScan < kScanMs) {
    return;
  }
  g_lastScan = now == 0 ? 1 : now;
  if (!g_log) {
    Scan(world, now);
    return;
  }
  // With log: the cost of the scans, every 240 of them (a real clock, for the log only: it feeds nothing back).
  static int scans = 0;
  static double total = 0.0, longest = 0.0;
  const auto start = std::chrono::steady_clock::now();
  Scan(world, now);
  const double us = std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - start).count();
  total += us;
  longest = std::max(longest, us);
  if (++scans == 240) {
    uhc::Log(L"autoGatherFrom: 240 scans, %.0f us on average, %.0f us the longest, %zu tagged unit(s)", total / scans,
             longest, g_units.size());
    scans = 0;
    total = longest = 0.0;
  }
}

}  // namespace

namespace uhc {

Outcome ApplyAutoGatherFrom(const Config& config) {
  const Config::Args* args = config.First("autoGatherFrom");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    Log(L"autoGatherFrom: bad argument %hs (expected [log]); feature not applied", arg.c_str());
    return Outcome::kFailed;
  }
  if (!VerifyAll("autoGatherFrom", {&sites::kGatherWorkOrder, &sites::kAutoScoutIdle, &sites::kUnitsNearPoint,
                                    &sites::kUnitById, &sites::kIsA, &sites::kIsBuilt, &sites::kPlayerIsEnemy,
                                    &sites::kHeldAmount, &sites::kMainResource, &sites::kUnitAliveSlot,
                                    &sites::kXmlAttribute, &sites::kXmlText, &sites::kUnitIsSeeable}) ||
      !AddActionTagHandler(&ActionTagRead) || !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  Log(L"autoGatherFrom: units with an <AutogatherFrom> action tag gather on their own once idle (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
```

## buildingGather

Contract: [buildingGather](../porting-to-another-dll.md#buildinggather).

Sites: `GatherUpdateExit` `0x4EC76B` (16 B), `GatherSetState` `0x4ED249` (11 B), `GatherArrivedState` `0x4EDB4F` (56 B), `GatherVtableSlots` `0xB978B4` (12 B).

### src/features/buildinggather.cpp

```cpp
// buildingGather [log]: a unit that cannot move (a building: MaxVelocity 0) gathers with its Gather action from a
// target within the action's range, as a villager does once it has walked there.
//
// The Gather action (vtable 0xB97880; state byte [action+61h], gatherer +10h, target ID +14h, range float +24h) is
// started by the start code, which calls setState(0) (0x4ED249, at 0x50DF3D) to walk the gatherer towards the target.
// The walk reports its end to the action as event 9 (the action's event handler, vtable +44h, 0x4EC904 → 0x4EDA75):
// when the gatherer is then in range (its vtable +CCh with the target and [action+24h]) and still in state 0, the
// action goes to state 5, gathering (0x4EDB7B). A building never walks, so no event 9 comes and its Gather action waits
// for ever, in state FFh (in game: a Market ordered to a Mine in range, 37,908 updates in a minute, no other state).
//
// The hook (hooks/buildgather_hooks.asm) sits where the Gather update 0x4EC4FA returns, at 0x4EC76B: for an action
// in state 0 or FFh whose gatherer's proto has MaxVelocity [proto+80h] at 0 or below, it asks the same range test as
// event 9 and sets state 5 when the target is in range; out of range it sets state 9 (the state the start code gives an
// order it refuses), so the building drops the order and is idle again instead of waiting for ever. The update has
// already dropped an order on a target the player cannot see (0x4EC753). A unit that moves is never touched.
// Simulation state only, the same on every machine.
#include <cmath>
#include <cstdint>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint8_t kStateApproach = 0;
constexpr std::uint8_t kStateGather = 5;
constexpr std::uint8_t kStateDone = 9;
constexpr std::uint8_t kStateWaiting = 0xFF;
constexpr int kMaxLogLines = 300;

using InRangeFn = bool(__thiscall*)(const char* unit, const char* target, float range);
using SetStateFn = void(__thiscall*)(char* action, std::int32_t state);

bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

const char* UnitById(std::int32_t id) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

const char* NameOf(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

}  // namespace

extern bool g_uhcBuildingGather;  // autogatherfrom.cpp: orders buildings only while this key is on

extern "C" {

void UhcBuildingGatherHook();

// From the Gather update's exit, for an action in state 0 (approach) or FFh (waiting).
void __stdcall UhcBuildingGatherApproach(char* action) {
  const std::uint8_t state = action == nullptr ? kStateGather : Field<std::uint8_t>(action, 0x61);
  if (state != kStateApproach && state != kStateWaiting) {
    return;
  }
  const char* gatherer = Field<const char*>(action, 0x10);
  const char* proto = gatherer == nullptr ? nullptr : Field<const char*>(gatherer, 0x5C);
  if (proto == nullptr || Field<float>(proto, 0x80) > 0.0f) {
    return;  // it can walk there: stock
  }
  const char* target = UnitById(Field<std::int32_t>(action, 0x14));
  if (target == nullptr) {
    return;  // the stock update ends an action whose target is gone
  }
  const auto inRange = Field<InRangeFn const*>(gatherer, 0)[0xCC / 4];
  const bool in = inRange(gatherer, target, Field<float>(action, 0x24));
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    const float dx = Field<float>(target, 0x14) - Field<float>(gatherer, 0x14);
    const float dz = Field<float>(target, 0x1C) - Field<float>(gatherer, 0x1C);
    uhc::Log(L"buildingGather: unit %d (%hs, state %d) -> unit %d (%hs), %.1f m between centres: %ls",
             Field<std::int32_t>(gatherer, 0x10), NameOf(gatherer), state, Field<std::int32_t>(target, 0x10), NameOf(target),
             static_cast<double>(std::sqrt(dx * dx + dz * dz)), in ? L"in range, gathers" : L"out of range, order dropped");
  }
  Field<SetStateFn const*>(action, 0)[0x34 / 4](action, in ? kStateGather : kStateDone);
}

}  // extern "C"

namespace uhc {

Outcome ApplyBuildingGather(const Config& config) {
  const Config::Args* args = config.First("buildingGather");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    Log(L"buildingGather: bad argument %hs (expected [log]); feature not applied", arg.c_str());
    return Outcome::kFailed;
  }
  if (!VerifyAll("buildingGather", {&sites::kGatherUpdateExit, &sites::kGatherVtableSlots, &sites::kGatherSetState,
                                    &sites::kGatherArrivedState}) ||
      !WriteJmp(sites::kGatherUpdateExit.va, reinterpret_cast<const void*>(&UhcBuildingGatherHook), 8)) {
    return Outcome::kFailed;
  }
  g_uhcBuildingGather = true;
  Log(L"buildingGather: a building with a Gather action gathers from a target within the action's range%ls "
      L"(multiplayer unverified)",
      g_log ? L"; each start logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/buildgather_hooks.asm

```asm
; Hook for buildingGather. Entered through a jmp written over the Gather update's exit test at 0x4EC76B; leaves
; through an explicit jmp to one of its two verified continuations (docs/engine-symbols.md, "Gather action").
.686
.model flat, c
option casemap :none

include common.inc

UhcBuildingGatherApproach PROTO STDCALL action:DWORD   ; state 0 of an immobile gatherer: state 5 or 9

.data
stateCNext      dd 00586D8Bh    ; the stock branch for state 0Ch (je 586D8Bh)
exitNext        dd 004EC773h    ; pop ebx / pop edi / pop esi / pop ebp / add esp,0Ch / ret

.code

; Replaces cmp al,0Ch / je 586D8Bh (8 bytes) at 0x4EC76B, in the Gather update FUN_004EC4FA (thiscall(action),
; plain ret; vtable 0xB97880 +3Ch). On entry AL = the action's state byte [esi+61h] (just read at 0x4EC760 and
; compared with 5), ESI = the action, EBX and EDI the update's saved registers on the stack. State 0Ch goes to the
; stock branch with the flags of the same compare. State 0 (approach) asks UhcBuildingGatherApproach, with every
; register kept; any other state leaves as stock. Both continuations only pop the saved registers (0x4EC773) or
; read the world (0x586D8B): nothing reads the flags or EAX before writing them, but EAX is kept anyway (the
; update's caller ignores it).
UhcBuildingGatherHook PROC
    TRACE_ONCE "buildingGather (0x4EC76B)"
    cmp al, 0Ch                     ; stolen 0x4EC76B
    jne notC
    jmp stateCNext                  ; stolen je 586D8Bh, taken
notC:
    test al, al
    je ask
    cmp al, 0FFh
    jne done
ask:
    pushad
    push esi                        ; the action
    call UhcBuildingGatherApproach
    popad
done:
    jmp exitNext                    ; stolen je 586D8Bh, not taken
UhcBuildingGatherHook ENDP

END
```

## herdWalkAwayFix

Contract: [herdWalkAwayFix](../porting-to-another-dll.md#herdwalkawayfix).

Sites: `HerdFleeHead` `0x4E3A37` (13 B), `HerdWalkAwayCall` `0x6A8C94` (13 B).

### src/features/herdwalkaway.cpp

```cpp
// herdWalkAwayFix: a herdable that walks away from its pen or magnet once fattened stays where it walked to.
//
// When a herdable that gathers into its own inventory is full and its target is a LivestockPen, the paddy or a unit
// of the abstract type AbstractTypeHerdableMagnet, the gather tick's cold path (0x6A8C47..0x6A8CA8) moves it away from
// the target: 0x4E3A37(mgr, targetId, 6.0f, 0), the flee move, called at 0x6A8C9C. Its action manager's leash anchor
// [mgr+7Ch] (x, y, z) is not touched there, and the manager's leash (0x489B15) walks an idle unit back to it. The
// anchor of a herdable the stock search pulled in (0x4C31EE) is where it stood before, so with a target that moves (a
// nomad), a fattened herdable walks back across the map to where the herd once was.
//
// The call at 0x6A8C9C is redirected to a wrapper that makes the stock call, then puts the anchor on the line from the
// target through the herdable, 6 m further out than the herdable stands: about where the flee takes it (its point
// carries a synced random part, so not exactly). Simulation state only; the same on every machine.
#include <cmath>
#include <cstdint>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr float kWalkAway = 6.0f;

using FleeFn = bool(__thiscall*)(char* mgr, std::int32_t target, float distance, std::int32_t flag);
const auto kFlee = reinterpret_cast<FleeFn>(0x004E3A37);

bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

const char* UnitById(std::int32_t id) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

// thiscall(mgr, target, distance, flag), ret 0Ch: __fastcall with an unused EDX has the same frame.
bool __fastcall WalkAway(char* mgr, void* /*edx*/, std::int32_t target, float distance, std::int32_t flag) {
  const bool moved = kFlee(mgr, target, distance, flag);
  const char* unit = mgr == nullptr ? nullptr : Field<const char*>(mgr, 0x04);
  const char* from = UnitById(target);
  if (unit == nullptr || from == nullptr) {
    return moved;
  }
  const float ux = Field<float>(unit, 0x14), uz = Field<float>(unit, 0x1C);
  const float tx = Field<float>(from, 0x14), tz = Field<float>(from, 0x1C);
  const float dx = ux - tx, dz = uz - tz;
  const float length = std::sqrt(dx * dx + dz * dz);
  float* anchor = reinterpret_cast<float*>(mgr + 0x7C);
  if (length > 0.01f) {
    anchor[0] = ux + dx / length * kWalkAway;
    anchor[2] = uz + dz / length * kWalkAway;
  } else {
    anchor[0] = ux;
    anchor[2] = uz;
  }
  anchor[1] = Field<float>(unit, 0x18);
  if (g_log && g_logLines < 200) {
    ++g_logLines;
    uhc::Log(L"herdWalkAwayFix: unit %d walks away from unit %d at (%.1f, %.1f): anchor (%.1f, %.1f)",
             Field<std::int32_t>(unit, 0x10), target, static_cast<double>(ux), static_cast<double>(uz),
             static_cast<double>(anchor[0]), static_cast<double>(anchor[2]));
  }
  return moved;
}

}  // namespace

namespace uhc {

Outcome ApplyHerdWalkAwayFix(const Config& config) {
  const Config::Args* args = config.First("herdWalkAwayFix");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    Log(L"herdWalkAwayFix: bad argument %hs (expected [log]); feature not applied", arg.c_str());
    return Outcome::kFailed;
  }
  if (!VerifyAll("herdWalkAwayFix", {&sites::kHerdWalkAwayCall, &sites::kHerdFleeHead}) ||
      !WriteCall(sites::kHerdWalkAwayCall.va + 8, reinterpret_cast<const void*>(&WalkAway))) {
    return Outcome::kFailed;
  }
  Log(L"herdWalkAwayFix: a herdable walked away from its pen or magnet keeps its leash anchor there");
  return Outcome::kApplied;
}

}  // namespace uhc
```

## faithResource

Contract: [faithResource](../porting-to-another-dll.md#faithresource).

Sites: `ShotsAnimVariant` `0x471D24` (11 B), `FaithGatherAnim` `0x4ED355` (9 B), `FaithGatherAnimNext` `0x4ED36B` (3 B), `FaithGatherAnimSet` `0x4ED3FA` (3 B), `FaithTotal` `0x501201` (9 B), `FaithBank` `0x852A3B` (15 B), `FaithBankClear` `0x852A4A` (15 B).

### src/features/faith.cpp

```cpp
// faithResource [log]: resource 4 ("SkillPoints") becomes an ordinary resource that a mod can gather and spend
// (a faith villagers gather by praying), cut from the home city's skill points it stands for in the stock game:
// - the skill point total 0x5011C6 returns int(resource 4) plus the home city's unspent skill points [HC+1F4h];
//   every read of resource 4 that is not the plain list entry goes through it (the KB getter behind
//   kbResourceGet 0x86B616, the AI's KB copy loops 0x86D8BD and 0x8767CA, the {resource()} text of the
//   interface, trPlayerResourceCount 0x988538 and the post-game statistics loop 0x500E2C). Its je 501209h becomes
//   a jmp (1 byte at 0x501201): it returns int(resource 4) alone, as the stock function does with no home city.
// - the home city bank FUN_00852924 (game end, its four callers) adds resource 4 to [HC+1F4h] and clears it. The
//   add is skipped by a hook (it can log the amount); the clear (call 49A8C5h with 4, 0, 0) is jumped over, so
//   faith stays in the game if the bank ever runs before its end. The XP half of the bank is not touched.
// - not changed: the setup FUN_006AED5E gives each AI player resource 4 = its home city level + 15 (0x6AEEDC,
//   0x6AF052): that is the AI's budget for the home city cards it buys at the start (measured: 20, then 6 after 14
//   cards), so the AI keeps what it has not spent. An AI script that read its card budget through
//   kbResourceGet(cResourceSkillPoints) adds kbGetHCLevel - 1, the home city's points the total used to add.
// - the praying animation: the Gather action's state change FUN_004ED254 picks the gather animation from the
//   target's unit types (mine, tree, farm, hunt, fish, crate, fire pit, else GatherBush or GatherFarm) and never
//   reads the tactics action's <anim>; at a church the villagers danced. A hook at the head of that chain
//   (0x4ED355) stores the action's own <anim> when the action gathers resource 4 and the gatherer's model has
//   that anim (0x471D24); every other gather keeps the stock choice.
#include <cstdint>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcFaithBankHook();
void UhcFaithGatherAnimHook();
// Read by the gather animation hook: nonzero plays a faith Gather action's own <anim>.
std::int32_t g_uhcFaithAnim = 0;
// Read by the hook: nonzero writes each skipped bank to the log.
std::int32_t g_uhcFaithLog = 0;
}

// Called by the hook (log only): faith = int(resource 4) that the stock code would add, skillPoints = the home
// city's skill points, left as they are.
extern "C" void __stdcall UhcFaithBankSkipped(std::int32_t faith, std::int32_t skillPoints) {
  uhc::Log(L"faithResource: home city bank: %d of resource 4 (faith) not added to the home city's skill points "
           L"(they stay %d)", faith, skillPoints);
}

namespace uhc {

Outcome ApplyFaithResource(const Config& config) {
  const Config::Args* args = config.First("faithResource");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"faithResource: unknown argument '%hs' (expected log); not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("faithResource", {&sites::kFaithTotal, &sites::kFaithBank, &sites::kFaithBankClear,
                                   &sites::kFaithGatherAnim,
                                   &sites::kFaithGatherAnimSet, &sites::kFaithGatherAnimNext,
                                   &sites::kShotsAnimVariant})) {
    return Outcome::kFailed;
  }
  g_uhcFaithLog = log ? 1 : 0;
  g_uhcFaithAnim = 1;
  const std::uint8_t jmpShort = 0xEB;                         // je 501209h -> jmp 501209h
  const std::uint8_t skipClear[] = {0xEB, 0x0C};              // jmp 852A58h over the clear of resource 4
  const bool ok = WriteBytes(sites::kFaithTotal.va, &jmpShort, 1) &&
                  WriteJmp(sites::kFaithBank.va, reinterpret_cast<const void*>(&UhcFaithBankHook), 6) &&
                  WriteBytes(sites::kFaithBankClear.va, skipClear, sizeof(skipClear)) &&
                  WriteJmp(sites::kFaithGatherAnim.va, reinterpret_cast<const void*>(&UhcFaithGatherAnimHook), 7);
  if (!ok) {
    return Outcome::kFailed;
  }
  Log(L"faithResource: resource 4 (SkillPoints) is a plain resource: no home city skill points in its reads, "
      L"not banked into the home city; a faith Gather action plays its own <anim>%ls "
      L"(multiplayer unverified)",
      log ? L" (each skipped bank logged)" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/faith_hooks.asm

```asm
; Hook for faithResource (src/features/faith.cpp). Entered through a jmp over add [esi+1F4h],edx (6 bytes) at
; 0x852A3B in the home city bank FUN_00852924: EDX = int(resource 4) that the stock code adds to the home city's
; skill points, ESI = the home city, ECX = its player (thiscall of the call at 0x852A45), the three arguments of
; that call already pushed, the x87 stack empty. The hook adds nothing, optionally logs EDX and [esi+1F4h], and
; leaves to 0x852A41 (fldcw [esp+1Ch] / call 49A8C5h) with every register and the flags as they came in (the
; stock add's flags are dead: fldcw and the call follow).
.686
.model flat, c
option casemap :none

include common.inc

UhcFaithBankSkipped PROTO STDCALL faith:DWORD, skillPoints:DWORD

EXTERN g_uhcFaithLog:DWORD

EXTERN g_uhcFaithAnim:DWORD

.data
faithBankContinue dd 00852A41h   ; fldcw [esp+1Ch] / call 49A8C5h (resource 5 = 0)
gatherAnimSet     dd 004ED3FAh   ; mov ecx,[edi+5Ch]: after the gather animation [esi+74h] is chosen
gatherAnimNext    dd 004ED36Bh   ; the stock chain's second test (je target of the first)
gatherAnimFirst   dd 004ED35Ch   ; push 8 / call 44CAC4h: the stock chain's first test
modelAnimIndex    dd 00471D24h   ; thiscall(unit, anim) -> the model's index of that anim, < 0 when it lacks it

.code

; Entered through a jmp over mov ecx,[edi+5Ch] / cmp ecx,ebx / je 4ED36Bh (7 bytes) at 0x4ED355 in the Gather
; action's state change FUN_004ED254, where the stock code picks the gather animation [esi+74h] from the target's
; unit types (a mine, a tree, a farm, a hunt, a fish, a crate, a fire pit, else GatherBush or GatherFarm) and
; never reads the tactics action's <anim>. ESI = the Gather action ([esi+4] its tactics action, whose <anim> is at
; +58h, -1 for none; [esi+10h] the gatherer; [esi+70h] the resource it gathers), EDI = the target unit (not null:
; 0x4ED34D tested it), EBX = 0. When the resource is 4 (faith) and the gatherer's model has the action's <anim>,
; that anim is stored and the hook leaves to 0x4ED3FA, where every stock case leaves after storing its own;
; otherwise it re-executes the three instructions. EAX, ECX and EDX are dead here (the stock cases overwrite
; ECX at once and never read EAX or EDX after 0x4ED3FA before setting them).
UhcFaithGatherAnimHook PROC
    TRACE_ONCE "faithResource gather animation (0x4ED355)"
    cmp g_uhcFaithAnim, 0
    je stock
    cmp dword ptr [esi+70h], 4
    jne stock
    mov eax, [esi+4]
    test eax, eax
    jz stock
    mov eax, [eax+58h]
    test eax, eax
    jl stock
    push eax                    ; keep the anim
    push eax
    mov ecx, [esi+10h]
    call modelAnimIndex         ; ret 4
    pop edx
    test eax, eax
    jl stock
    TRACE_ONCE "faithResource gather animation: the action's own <anim> played"
    mov [esi+74h], edx
    jmp gatherAnimSet
stock:
    mov ecx, [edi+5Ch]
    cmp ecx, ebx
    je next
    jmp gatherAnimFirst
next:
    jmp gatherAnimNext
UhcFaithGatherAnimHook ENDP

UhcFaithBankHook PROC
    TRACE_ONCE "faithResource home city bank (0x852A3B)"
    cmp g_uhcFaithLog, 0
    je done
    pushfd
    pushad
    push dword ptr [esi+1F4h]
    push edx
    call UhcFaithBankSkipped
    popad
    popfd
done:
    jmp faithBankContinue
UhcFaithBankHook ENDP

END
```

## deadReplacementAtZeroInventory

Contract: [deadReplacementAtZeroInventory](../porting-to-another-dll.md#deadreplacementatzeroinventory).

Sites: `RemovalNoticeHead` `0x495D6B` (7 B), `RemovalNoticeCall1` `0x495DEE` (5 B), `DeadReplacementHead` `0x4B4F2F` (15 B), `CorpseReplacementCall` `0x4F1680` (5 B), `RemovalNoticeCall2` `0x6A3FF0` (5 B).

### src/features/deadreplacement.cpp

```cpp
// deadReplacementAtZeroInventory [log]: a unit with DoNotDieAtZeroHitpoints and DieAtZeroResources (a hunt,
// a herdable, any unit that turns into a body to gather) leaves its <DeadReplacement> when its body is used
// up, not when it falls.
//
// The death replacement FUN_004B4F2F places the proto [proto+F8h] (<DeadReplacement>, handler 0x5FC33B) at the
// unit, once: it sets state bit 29h, and does nothing when that bit is set. It has four callers: the kill
// handler 0x4B4F70 (0x4B527E, skipped for a DeadReplacementWhenDestroyed proto, flag 4Ah), the two removal
// paths of such a proto (0x4E6FC6, 0x6A4013), and the state check FUN_00482152 at 0x4F1680. That last one runs
// when a unit with DieAtZeroResources (flag 0Eh) and without the default DieAtZeroHitpoints (flag 0Dh, cleared
// by DoNotDieAtZeroHitpoints) reaches 0 HP while in the world: the unit becomes a body (state bit 12, owner
// gaia), plays its death sound, and the replacement is placed at once, beside the body that is still there.
// When the body's inventory reaches 0, the state check asks the kill queue (0x4720BF), but the unit update
// FUN_00482F16 marks the body for removal (state bit 7) and the world removes it (0x4726B2 at 0x495D61) in the
// same update, before the queue's drain: the kill handler never runs for it. The two updates that remove a
// unit marked so (0x483155 → 0x495DEC, and 0x5116C2 → 0x6A3FEE) call the removal notice FUN_00495D6B first,
// then place the replacement of a DeadReplacementWhenDestroyed proto (flag 4Ah) only.
//
// Two hooks (hooks/deadrepl_hooks.asm):
// - the replacement's head returns at once when it is called from 0x4F1680 for a unit with those two flags and
//   a replacement, without setting bit 29h, so nothing is placed when the unit falls;
// - the removal notice's head (its only two callers are those removal paths) places the replacement of such a
//   body (state bit 12) through the stock function, at the moment and place a DeadReplacementWhenDestroyed
//   proto gets its own. A body killed by the kill handler (a trigger's Kill) gets it there, as stock does;
//   bit 29h keeps it to one.
// Every other unit is stock. Simulation only, on data the same on every machine.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr std::uint32_t kCorpseCallReturn = 0x004F1685;  // after call 4B4F2Fh at 0x4F1680
constexpr std::uint32_t kGameGlobal = 0x00C66234;         // game; +140h database
constexpr std::int32_t kFlagDieAtZeroHitpoints = 0x0D;
constexpr std::int32_t kFlagDieAtZeroResources = 0x0E;
constexpr std::int32_t kStateBody = 12;
constexpr std::int32_t kStateReplaced = 0x29;
constexpr unsigned kMaxLogLines = 300;

using ProtoByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
const auto kProtoById = reinterpret_cast<ProtoByIdFn>(0x0045316E);
using ReplaceFn = void(__thiscall*)(char* unit);
const auto kReplace = reinterpret_cast<ReplaceFn>(0x004B4F2F);

bool g_log = false;
unsigned g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// A bit of a bitset (pointer at +0, bit count at +4), as the stock tests read it.
bool Bit(const char* set, std::int32_t bit) {
  const auto* bits = Field<const std::uint8_t*>(set, 0);
  return bits != nullptr && bit < Field<std::int32_t>(set, 4) && (bits[bit >> 3] & (1u << (bit & 7))) != 0;
}

const char* NameOf(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* ReplacementName(std::int32_t id) {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  return database == nullptr ? "?" : NameOf(kProtoById(database, id));
}

// The proto keeps its body at 0 HP, dies when its inventory is empty, and has a replacement.
bool BodyWithReplacement(const char* proto) {
  return proto != nullptr && Field<std::int32_t>(proto, 0xF8) >= 0 && !Bit(proto + 0x50, kFlagDieAtZeroHitpoints) &&
         Bit(proto + 0x50, kFlagDieAtZeroResources);
}

void LogLine(const char* unit, const char* proto, const wchar_t* what) {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return;
  }
  ++g_logLines;
  const std::int32_t replacement = Field<std::int32_t>(proto, 0xF8);
  const auto* position = reinterpret_cast<const float*>(unit + 0x14);
  uhc::Log(L"deadReplacementAtZeroInventory: unit %d (%hs, at %.1f, %.1f) %ls: DeadReplacement %hs (%d)",
           Field<std::int32_t>(unit, 0x10), NameOf(proto), static_cast<double>(position[0]),
           static_cast<double>(position[2]), what, ReplacementName(replacement), replacement);
  if (g_logLines == kMaxLogLines) {
    uhc::Log(L"deadReplacementAtZeroInventory: %u lines logged; no more", kMaxLogLines);
  }
}

}  // namespace

extern "C" {

void UhcDeadReplacementHook();
void UhcDeadReplacementRemoveHook();

// From the replacement's head, with the caller's return address: 1 skips the call.
std::int32_t __stdcall UhcDeadReplacementSkip(const char* unit, std::uint32_t caller) {
  if (caller != kCorpseCallReturn || unit == nullptr) {
    return 0;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  if (!BodyWithReplacement(proto)) {
    return 0;
  }
  LogLine(unit, proto, L"fell and keeps its body; its replacement waits until the body is used up");
  return 1;
}

// From the removal notice's head: a body whose replacement waited gets it now.
void __stdcall UhcDeadReplacementOnRemove(char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (!BodyWithReplacement(proto) || !Bit(unit + 4, kStateBody) || Bit(unit + 4, kStateReplaced)) {
    return;
  }
  LogLine(unit, proto, L"is removed (its body used up): the replacement is placed now");
  kReplace(unit);
}

}  // extern "C"

namespace uhc {

Outcome ApplyDeadReplacementAtZeroInventory(const Config& config) {
  const Config::Args* args = config.First("deadReplacementAtZeroInventory");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"deadReplacementAtZeroInventory: unknown option %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("deadReplacementAtZeroInventory",
                 {&sites::kDeadReplacementHead, &sites::kCorpseReplacementCall, &sites::kRemovalNoticeHead,
                  &sites::kRemovalNoticeCall1, &sites::kRemovalNoticeCall2}) ||
      !WriteJmp(sites::kDeadReplacementHead.va, reinterpret_cast<const void*>(&UhcDeadReplacementHook), 7) ||
      !WriteJmp(sites::kRemovalNoticeHead.va, reinterpret_cast<const void*>(&UhcDeadReplacementRemoveHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"deadReplacementAtZeroInventory: a unit with DoNotDieAtZeroHitpoints and DieAtZeroResources leaves its "
      L"DeadReplacement when its body is used up, not when it falls%ls (multiplayer unverified)",
      g_log ? L"; each case logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/deadrepl_hooks.asm

```asm
; Hook for deadReplacementAtZeroInventory. Entered through a jmp written over the head of the death
; replacement FUN_004B4F2F; leaves through an explicit jmp to its verified continuation, or returns
; for it (docs/engine-symbols.md, "Death replacement").
.686
.model flat, c
option casemap :none

include common.inc

; EAX: 1 to skip this replacement, 0 for stock. `caller` is the return address.
UhcDeadReplacementSkip PROTO STDCALL unit:DWORD, caller:DWORD
UhcDeadReplacementOnRemove PROTO STDCALL unit:DWORD     ; places a body's waiting replacement

.data
headNext        dd 004B4F36h    ; test eax,eax / jne 4E6220h: the replacement after its stolen head
removeNext      dd 00495D70h    ; push esi / push edi: the removal notice after its stolen head

.code

; Replaces push ecx / push esi / mov esi,ecx / mov eax,[esi+68h] (7 bytes) at 0x4B4F2F, the head of
; the death replacement (thiscall(unit), plain ret; ECX = unit). Its four callers: the kill handler
; 0x4B527E, the two removal paths of a DeadReplacementWhenDestroyed proto 0x4E6FC6 and 0x6A4013, and
; 0x4F1680, where the state check 0x482152 has just turned a unit with DieAtZeroResources at 0 HP
; into a corpse (state bit 12, owner gaia). UhcDeadReplacementSkip, given the return address, says
; whether to leave the replacement for later (EAX = 1: return to the caller with nothing done, no
; state bit 29h set, no unit placed); it only says so for the corpse caller. Each caller reloads EAX
; before reading it, and EDX is not live across the call (thiscall, no arguments). Otherwise the
; stolen instructions run and the stock body follows.
UhcDeadReplacementHook PROC
    TRACE_ONCE "deadReplacementAtZeroInventory (0x4B4F2F)"
    push ecx
    push dword ptr [esp+4]          ; the caller's return address
    push ecx                        ; unit
    call UhcDeadReplacementSkip
    pop ecx
    test eax, eax
    je stock
    ret
stock:
    push ecx                        ; stolen 0x4B4F2F
    push esi                        ; stolen 0x4B4F30
    mov esi, ecx                    ; stolen 0x4B4F31
    mov eax, dword ptr [esi+68h]    ; stolen 0x4B4F33
    jmp headNext
UhcDeadReplacementHook ENDP

; Replaces mov eax,[0C66234h] (5 bytes) at 0x495D6B, the head of the removal notice (thiscall(unit),
; plain ret; ECX = unit), which the two updates call for a unit marked for removal (state bit 7) just
; before they remove it: 0x495DEE in the unit update 0x482F16, 0x6A3FF0 in 0x5116xx. Both then place
; the replacement only for a DeadReplacementWhenDestroyed proto. UhcDeadReplacementOnRemove places it
; for a body whose replacement waited (through the head above, which is then stock: the return
; address is ours). It keeps ECX; EAX is written by the stolen instruction, EDX is not an argument.
UhcDeadReplacementRemoveHook PROC
    TRACE_ONCE "deadReplacementAtZeroInventory removal (0x495D6B)"
    push ecx
    push ecx                        ; unit
    call UhcDeadReplacementOnRemove
    pop ecx
    mov eax, dword ptr ds:[0C66234h]   ; stolen 0x495D6B
    jmp removeNext
UhcDeadReplacementRemoveHook ENDP

END
```
