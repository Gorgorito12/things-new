# Code for WoL: Gathering

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

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
