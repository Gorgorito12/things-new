# Code for WoL: Gathering

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [showGatherRate](#showgatherrate)
- [workRateByAbstractType](#workratebyabstracttype)
- [cratePriority](#cratepriority)
- [autoGatherScaleByContained](#autogatherscalebycontained)
- [unitResourceAuras](#unitresourceauras)
- [resourceGatherAuras](#resourcegatherauras)
- [resourceDebt](#resourcedebt)

## showGatherRate

Contract: [showGatherRate](../porting-to-another-dll.md#showgatherrate).

Besides the core helpers, it needs: [`unitpanel.h`](helpers.md#unit-panel-row-the-minimized-interface), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

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
// The hooks are in hooks/gatherrate_hooks.asm.
#include <cmath>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <string>
#include <unordered_set>

#include "../features.h"
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
// action ([[unit+58h]+24h]) is the recorded Gather action, that action is in its gathering state
// and still belongs to the unit (actions come from a pool), and the record is younger than two
// of its animation loops (2.5 s at least) in game time. Two cases where the tick adds nothing
// although it computed a rate are left out: a target of type AbstractShrine (0x4ED14B) and a
// player with [player+338h] set (0x4ED1AB).
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
  if (record.unit != id || record.action == nullptr || manager == nullptr ||
      Field<const char*>(manager, 0x24) != record.action ||
      Field<std::uint8_t>(record.action, 0x61) != kGatheringState || Field<const char*>(record.action, 0x10) != unit) {
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
      Field<std::int32_t>(selection, 0x14) != 1 || Field<std::uint8_t>(selection, 0x21) != 0) {
    return false;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  if (proto == nullptr || !kIsBuilt(unit) || !kProtoFlag(proto, kShowAutoGatherRate)) {
    return false;
  }
  if (g_useMarker && (g_markerType < 0 || !kProtoIsType(proto, g_markerType))) {
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

// The minimized interface's row (unitpanel.cpp). Same gate as the stat panel row.
bool __stdcall UhcGatherUnitPanel(const char* panel, const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  if (proto == nullptr || !kIsBuilt(unit) || !kProtoFlag(proto, kShowAutoGatherRate)) {
    return false;
  }
  if (g_useMarker && (g_markerType < 0 || !kProtoIsType(proto, g_markerType))) {
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
  if (g_useMarker) {
    Log(L"showGatherRate: the stat panel shows the gather rate per second of a selected unit of unittype %hs, "
        L"and {currentUnitGatherRateString} returns it for any unit%ls (UI only)",
        g_markerName.c_str(), log ? L", each unit's first rate per resource logged" : L"");
  } else {
    Log(L"showGatherRate: the stat panel shows the gather rate per second of a selected gathering unit, and "
        L"{currentUnitGatherRateString} returns it%ls (UI only)",
        log ? L", each unit's first rate per resource logged" : L"");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
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
// The hook is in hooks/gatherscale_hooks.asm.
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcAutoGatherRateHook();
}

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
  if (!VerifyAll("autoGatherScaleByContained", {&sites::kAutoGatherRateEntry})) {
    return Outcome::kFailed;
  }
  // Replaces push ecx / push ebx / mov ebx,[esp+0Ch] at 0x49EBE4; the hook re-executes them.
  if (!WriteJmp(sites::kAutoGatherRateEntry.va, reinterpret_cast<const void*>(&UhcAutoGatherRateHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"autoGatherScaleByContained: AutoGather actions with ScaleByContainedUnits multiply their rate by the units "
      L"inside (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/gatherscale_hooks.asm

```asm
; Hook for autoGatherScaleByContained. Entered through a jmp written over the stock code; it leaves
; through an explicit jmp to a verified continuation, or returns for the stock body it called
; (docs/engine-symbols.md, "Garrison scaling").
.686
.model flat, c
option casemap :none

include common.inc

.data
rateBody    dd 0049EBEAh    ; test ebx,ebx: the AutoGather rate getter after its first three instructions
capFloor    dd 0.0          ; the value of 0xB84BE4, which the stock attack code compares the cap with

.code

; Replaces 0x49EBE4..0x49EBE9 (push ecx / push ebx / mov ebx,[esp+0Ch]), the entry of the AutoGather
; rate getter, float thiscall(action, int resource), ret 4. ECX = the unit action, whose [ecx+4] is
; the tactics action. Without the tactics flag ScaleByContainedUnits (bit 18 of the flag bytes
; [+64h], count of bits [+68h]) the stock body runs as if nothing happened. With it, the stock body
; runs as a call, and the rate is multiplied as the stock attack multiplies its damage (0x4996C7,
; 0x6A4B83): by the unit's contained count [unit+74h], at most DamageFactorCap [+48h] when that is
; above 0. EAX, ECX and EDX are free at a thiscall entry; ST0 holds the result on return.
UhcAutoGatherRateHook PROC
    TRACE_ONCE "autoGatherScaleByContained (0x49EBE4)"
    mov eax, dword ptr [ecx+4]
    cmp dword ptr [eax+68h], 12h
    jbe stock
    mov eax, dword ptr [eax+64h]
    test byte ptr [eax+2], 4
    jne scaled
stock:
    push ecx                        ; stolen 0x49EBE4
    push ebx                        ; stolen 0x49EBE5
    mov ebx, dword ptr [esp+0Ch]    ; stolen 0x49EBE6
    jmp rateBody
scaled:
    push esi
    mov esi, ecx
    push dword ptr [esp+8]          ; the resource
    call body                       ; returns here with its ret 4 done, the rate in ST0
    mov ecx, dword ptr [esi+10h]
    mov eax, dword ptr [esi+4]
    pop esi
    fild dword ptr [ecx+74h]        ; ST0 = factor, ST1 = rate
    fld dword ptr [eax+48h]         ; ST0 = cap
    fcom st(1)                      ; cap against factor
    fnstsw ax
    test ah, 41h                    ; cap <= factor?
    je keep                         ; no: the factor stands
    fcom capFloor
    fnstsw ax
    test ah, 41h                    ; cap <= 0?
    jne keep                        ; yes: no cap
    fxch st(1)
keep:
    fstp st(0)                      ; drop the one not used
    fmulp st(1), st(0)
    ret 4
body:
    push ecx                        ; stolen 0x49EBE4
    push ebx                        ; stolen 0x49EBE5
    mov ebx, dword ptr [esp+0Ch]    ; stolen 0x49EBE6
    jmp rateBody
UhcAutoGatherRateHook ENDP

END
```

## unitResourceAuras

Contract: [unitResourceAuras](../porting-to-another-dll.md#unitresourceauras).

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`modifytypes.h`](helpers.md#modify-types), [`unittypes.h`](helpers.md#extra-abstract-unit-types), [`worldtick.h`](helpers.md#world-tick).

Sites: `ModelById` `0x405E83` (6 B), `IsAbstractIndex` `0x44CAC4` (70 B), `UnitById` `0x44CC6D` (58 B), `IsBuilt` `0x44DDB4` (31 B), `ResListGet` `0x44EFFF` (61 B), `ProtoFlag` `0x45EE02` (53 B), `UnitIsDead` `0x4802C6` (16 B), `CheckState` `0x482152` (16 B), `InventoryAdd` `0x49A5E6` (16 B), `PlayerAddResource` `0x49A98A` (16 B), `MainResource` `0x4DBEC1` (16 B), `UnitAttachModel` `0x9C04F3` (8 B), `UnitRemoveModel` `0x9C2885` (8 B), `UnitHasModel` `0x9C28DE` (8 B), `AuraScan` `0x9CFF9A` (16 B), `UnitResourceAuraEntry` `0x9D033E` (8 B), `AuraModelBlock` `0x9D053F` (9 B).

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
// The hook is in hooks/unitresource_hooks.asm. The time of each aura's last update and the rings it
// hung live here, so a saved game restarts that clock; nothing else is kept.
#include <algorithm>
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <utility>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifytypes.h"
#include "../patch.h"
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
constexpr std::uint32_t kModelTable = 0x00C66240;  // the table of models; read as at 0x9D054A
constexpr std::uint32_t kRingSweepMs = 1000;       // how often the auras that hung rings are checked
constexpr float kMinAmount = 1.0e-6f;
constexpr int kMaxLogLines = 200;

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
using ModelByIdFn = const void*(__thiscall*)(void* table, std::int32_t model);
using HasModelFn = bool(__thiscall*)(const char* unit, std::int32_t model);
using AttachModelFn = bool(__thiscall*)(char* unit, const void* object, std::int32_t bone, std::int32_t flag);
using RemoveModelFn = void(__thiscall*)(char* unit, std::int32_t model);

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
const auto kModelById = reinterpret_cast<ModelByIdFn>(0x00405E83);
const auto kHasModel = reinterpret_cast<HasModelFn>(0x009C28DE);
const auto kAttachModel = reinterpret_cast<AttachModelFn>(0x009C04F3);
const auto kRemoveModel = reinterpret_cast<RemoveModelFn>(0x009C2885);

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Params {
  float amount = 0.0f;
  std::int32_t limit = -1;  // -1: every unit in range
  bool gaia = false;
};

std::map<ActionKey, Params> g_params;
std::map<std::int32_t, std::uint32_t> g_lastUpdate;  // by the owner's unit ID: in ID order, game time
IdList g_list = {};

struct Rings {
  std::int32_t model = -1;
  std::vector<std::int32_t> targets;
};

std::map<std::int32_t, Rings> g_rings;          // by the owner's unit ID
std::map<std::int32_t, std::int32_t> g_ringUsers;  // by the target's unit ID: the auras holding its ring
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
  g_lastUpdate.clear();
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

// As the stock update does at 0x9D054A..0x9D059C. False: the unit has no visual yet, and the next
// update tries again. A model that is not in the game is taken as hung, or it would be hung again on
// every update: the engine accepts it and shows nothing.
bool HangRing(const char* world, std::int32_t id, std::int32_t model, std::int32_t bone, const char* tactics) {
  char* unit = const_cast<char*>(kUnitById(world, id));
  void* table = *reinterpret_cast<void**>(kModelTable);
  if (unit == nullptr || table == nullptr) {
    return false;
  }
  if (kHasModel(unit, model)) {
    return true;
  }
  const void* object = kModelById(table, model);
  if (object == nullptr || !kAttachModel(unit, object, bone, 0)) {
    return false;
  }
  if (!kHasModel(unit, model)) {
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
  const auto users = g_ringUsers.find(id);
  if (users == g_ringUsers.end() || --users->second > 0) {
    return;
  }
  g_ringUsers.erase(users);
  if (char* unit = const_cast<char*>(kUnitById(world, id))) {
    kRemoveModel(unit, model);
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"unitResourceAuras: ring off unit %d", id);
    }
  }
}

void UpdateRings(const char* world, std::int32_t owner, const char* tactics, std::int32_t model, std::int32_t bone) {
  Rings& rings = g_rings[owner];
  rings.model = model;
  std::vector<std::int32_t> held;
  for (const std::int32_t id : g_ringTargets) {
    const bool had = std::find(rings.targets.begin(), rings.targets.end(), id) != rings.targets.end();
    if (had) {
      held.push_back(id);
    } else if (HangRing(world, id, model, bone, tactics)) {
      ++g_ringUsers[id];
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
    const char* owner = kUnitById(world, it->first);
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
  const bool gaia = _wcsicmp(tag.name, L"TargetGaia") == 0;
  if (!amount && !limit && !gaia) {
    return;
  }
  Params& params = g_params[{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)}];
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  if (amount) {
    params.amount = std::wcstof(text, nullptr);
  } else if (limit) {
    params.limit = std::wcstol(text, nullptr, 10);
  } else {
    params.gaia = std::wcstol(text, nullptr, 10) != 0;
  }
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
  const char* ownerProto = Field<const char*>(owner, 0x5C);
  char* player = Field<char*>(owner, 0x44);
  if (ownerProto == nullptr || player == nullptr) {
    return;
  }
  const auto found = g_params.find({Field<std::int32_t>(ownerProto, 0x04), Field<std::int32_t>(tactics, 0x04)});
  if (found == g_params.end() || found->second.amount <= kMinAmount) {
    return;
  }
  const Params& params = found->second;
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  CheckRingWorld(world, now);
  const auto [last, isNew] = g_lastUpdate.try_emplace(Field<std::int32_t>(owner, 0x10), now);
  const std::uint32_t since = now - last->second;
  if (isNew || since == 0) {
    return;
  }
  last->second = now;
  const float seconds = static_cast<float>(since > kMaxStepMs ? kMaxStepMs : since) / 1000.0f;
  const float amount = params.amount * seconds;

  const std::int32_t ownerPlayer = Field<std::int32_t>(player, 0x00);
  const float multiplier = Field<float>(player, 0x37C);
  g_list.count = 0;
  kScan(action, &g_list);
  g_ringTargets.clear();
  std::int32_t gathered = 0;
  for (std::int32_t i = 0; i < g_list.count; ++i) {
    if (params.limit >= 0 && gathered >= params.limit) {
      break;
    }
    char* target = const_cast<char*>(kUnitById(world, g_list.data[i]));
    if (target == nullptr || target == owner) {
      continue;
    }
    const char* targetProto = Field<const char*>(target, 0x5C);
    const char* targetPlayer = Field<const char*>(target, 0x44);
    if (targetProto == nullptr || targetPlayer == nullptr || !TypeMatches(tactics, targetProto)) {
      continue;
    }
    const std::int32_t targetOwner = Field<std::int32_t>(targetPlayer, 0x00);
    if (targetOwner != ownerPlayer && !(params.gaia && targetOwner == 0)) {
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
    const float take = have < amount ? have : amount;
    ++gathered;
    g_ringTargets.push_back(Field<std::int32_t>(target, 0x10));  // the state check below may remove it
    if (!kProtoFlag(targetProto, kFlagEndless)) {
      kInventoryAdd(inventory, resource, -take);
      kCheckState(target);
    }
    kPlayerAdd(player, resource, take * multiplier, false);
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"unitResourceAuras: unit %d (%hs) took %.3f of resource %d from unit %d (%hs), %.1f left",
               Field<std::int32_t>(owner, 0x10), Field<const char*>(ownerProto, 0x10), static_cast<double>(take),
               resource, Field<std::int32_t>(target, 0x10), Field<const char*>(targetProto, 0x10),
               static_cast<double>(have - take));
    }
  }
  const std::int32_t model = Field<std::int32_t>(tactics, 0xA4);
  if (model != -1) {
    UpdateRings(world, Field<std::int32_t>(owner, 0x10), tactics, model, Field<std::int32_t>(tactics, 0xA8));
  }
}

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
                  &sites::kUnitRemoveModel})) {
    return Outcome::kFailed;
  }
  if (!AddModifyType(L"UnitResource", kStatUnitResource) || !AddActionTagHandler(&ActionTagRead) ||
      !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&RingTick)) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!WriteJmp(sites::kUnitResourceAuraEntry.va, reinterpret_cast<const void*>(&UhcUnitResourceAuraHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"unitResourceAuras: AutoRangedModify actions with ModifyType UnitResource gather from units in range%ls "
      L"(multiplayer unverified)",
      log ? L", the first takes logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
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

## resourceGatherAuras

Contract: [resourceGatherAuras](../porting-to-another-dll.md#resourcegatherauras).

Besides the core helpers, it needs: [`modifiers.h`](helpers.md#modifier-walk), [`modifytypes.h`](helpers.md#modify-types), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

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
  return Outcome::kApplied;
}

}  // namespace uhc
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
