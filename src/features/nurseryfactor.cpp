// nurseryFactor [log]: a whole number per building or unit (a "factor", e.g. the minks of a mink nursery) that grows
// with game time up to a cap, is changed by techs, by units that enter the building and by its command buttons,
// multiplies the unit's AutoGather rate, can multiply a home city shipment, and shows in the unit panels as
// "3/10 minks" with a two-line rollover.
//
//   <NurseryFactorMax>10</NurseryFactorMax>              the cap, a whole number 0..100000 (default 10)
//   <NurseryFactorInitial>0</NurseryFactorInitial>       the value of a new unit (default 0)
//   <NurseryFactorInterval>30</NurseryFactorInterval>    game seconds per growth step (default 0: no growth with time)
//   <NurseryFactorStep>1</NurseryFactorStep>             linear: the size of a step (default 1)
//   <NurseryFactorGrowth>linear</NurseryFactorGrowth>    linear (default) or exponential
//   <NurseryFactorGrowthBase>2</NurseryFactorGrowthBase> exponential: step t (0, 1, 2...) adds b^t (default 2)
//   <NurseryFactorTrickle>1</NurseryFactorTrickle>       1 (default): the factor multiplies the unit's AutoGather rate
//   <NurseryFactorName>minks</NurseryFactorName>         string table ID or text (default "")
//   <NurseryFactorRolloverCount>...</...>                string ID or text, default "{current} out of {max} {name}."
//   <NurseryFactorRolloverRate>...</...>                 string ID or text, default "Produces {step} {name} every
//                                                        {seconds} seconds."; placeholders {current} {max} {name}
//                                                        {seconds} {step}
//   <NurseryFactorGarrisonUnit amount="3">ypGoat</NurseryFactorGarrisonUnit>
//                                                        a unit of that proto or type that enters is removed and adds
//                                                        amount (several tags: several rules, the first match wins)
//   <NurseryFactorCommand factor="-5" unit="CrateofCoin" count="1" cost="Gold 100, Wood 50">SellMinks</...>
//                                                        the command nurseryFactorCommand("SellMinks") of a button:
//                                                        changes the factor by `factor` (a negative one needs that many),
//                                                        pays `cost`, makes `count` units of `unit` at the building
//
// Any NurseryFactor tag marks the proto. The tags are read once per data load, by proto ID, the same for every player.
// Data subtypes on a ProtoUnit target change one player's copy of the proto: NurseryFactorMax, NurseryFactorInterval,
// NurseryFactorStep and NurseryFactorGrowthBase through the stock value function 0x7F892A (base: the tags);
// NurseryFactor changes the factor of each of the player's built units of that proto (Absolute adds, Assign sets;
// every relativity through the same function, the unit's factor as the value and the initial value as the base),
// once, at the next world tick. The Player subtype FreeHomeCityUnitByNurseryFactor (unittype = the proto shipped,
// nursery = a proto or abstract type, consume = all | N | none) becomes the stock FreeHomeCityUnit (37h) with amount x
// the factors it takes from the player's built units of that type: consume="all" takes each whole factor, consume="N"
// at most N from each, none (the default) counts them and takes nothing.
//
// The cap stops growth and the additions (a tech's, a garrisoned unit's, a command's); it never takes away what a unit
// already has, so a lowered cap leaves the extra until the unit loses it.
//
// The trickle: the AutoGather rate getter 0x49EBE4 is a shared hook (autogatherrate.h); this key's filter multiplies
// the rate of a unit of a tagged proto by its factor. The AutoGather update then pays the owner (or, with the stock
// tactics tag AddResourcesToInventory, adds to the unit's own inventory), and the panels show the multiplied rate.
//
// The factors: a table by unit ID (in ID order), filled by a sweep of the world's unit table (256 slots per world
// update; the whole table when a game starts or loads). After each world update (worldtick.h) each living, built unit
// adds the game time [world+108h] that passed to its timer and grows a step per interval, up to the player's cap; at
// the cap the timer waits at 0. The factor and the timer are a saved marker on the unit (savedmarkers.h, stat 6Bh),
// written each tick, so a save keeps them and the unit's death loses them; a transform in place (which ends the
// markers) keeps the table's value when the new proto is tagged too.
//
// Exponential growth: t follows the factor. With S(t) = b^0 + ... + b^(t-1) (S(0) = 0), t is the largest t with
// floor(S(t)) <= factor, and the next step adds floor(S(t+1)) - floor(S(t)) (b^t for a whole b). So t is a function
// of the factor and the player's b, never stored: a sale, a shipment, a garrisoned unit, a command, a tech or a
// capture moves t with the factor. b 2: S = 0, 1, 3, 7, 15...; 0 -> t 0, 2 -> t 1 (next +2), 3 -> t 2 (next +4).
//
// The garrison: the shared observer of the load of a unit into another (garrisonobservers.h) queues the entries into a
// tagged building; the world tick after them removes each unit that is still inside and matches a rule (0x4726B2, the
// trigger Destroy's removal: no death, no corpse) and adds its amount, up to the cap. A full building keeps the unit.
//
// The commands: the UI syscall nurseryFactorCommand("Name") sends the network command uiTransformSelectedUnit sends
// (type 17h, 0x5695FC), for the local player's selected units, with 'NR' << 16 | the command's index in [cmd+8Ch]
// where that command carries a proto ID. Every machine runs it in the world update; the hook at the head of the
// type's per-unit execute 0x7D64F7 (hooks/nurserycmd_hooks.asm) takes those and runs the unit's rule: the factor
// (enough of it, or room under the cap), room for the units (PLACE around the building, as killSpawn places its
// animals) and under the population cap (the stock maintain spawn's test, for all of them), the cost (0x8D946A, the
// stock payment), then the units (0x498ACC). Each test that fails leaves everything as it was.
//
// Display only: the unit panel row (unitpanel.h, the minimized interface) and the stat panel row (statpanelrows.h, the
// normal one) "3/10 minks" with the rollover as their help text, a small progress pie toward the next step after that
// text (an inline icon, art\ui\uhc\pie; without those files the portrait's pie, progresspie.h), the command buttons
// greyed with their reason (panelbuttons.h), and the data ref {uhcNurseryFactor}
// (the first selected unit's "3/10 minks").
#include <windows.h>

#include <algorithm>
#include <cctype>
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
#include "../garrisonobservers.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../panelbuttons.h"
#include "../patch.h"
#include "../progresspie.h"
#include "../prototags.h"
#include "../savedmarkers.h"
#include "../statpanelrows.h"
#include "../syscalls.h"
#include "../techsubtypes.h"
#include "../unitpanel.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" void UhcNurseryCmdHook();

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database, +3C0h the local player
constexpr std::int32_t kStat = 0x6B;               // savedmarkers.h: no other key uses it
constexpr std::uint32_t kWord = 0x4E525346;        // word 0 of a unit's marker: 'NRSF'
constexpr std::int32_t kSweepSlots = 256;
constexpr std::int32_t kFreeHomeCityUnit = 0x37;
constexpr std::int32_t kMaxValue = 100000;
constexpr float kDefaultMax = 10.0f;
constexpr int kMaxLogLines = 400;
constexpr std::size_t kTypeNames = 0x190;       // in the database: the unit type name table
constexpr std::size_t kFirstAbstract = 0x19B0;  // in the database: the first abstract type's ID
constexpr std::size_t kProtoTable = 0x54;       // in the database: the proto array (a new one for each data load)
constexpr std::int32_t kTransformCommand = 0x17;    // the network command uiTransformSelectedUnit sends
constexpr std::uint32_t kCommandMagic = 0x4E520000;  // 'NR' << 16: [cmd+8Ch] of a nursery command
constexpr std::int32_t kMaxCommands = 0x10000;
constexpr std::uint32_t kPlaceSlot = 0x14;           // the world's placement test PLACE, FUN_0050703D
constexpr std::int32_t kPlaceFlags = 2;              // as the stock death replacement: the units made count
constexpr std::int32_t kMaxSpawn = 50;

using IsBuiltFn = bool(__thiscall*)(const char* unit);
using IsAliveFn = bool(__thiscall*)(const char* unit);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
using NameBucketFn = std::int32_t(__thiscall*)(const void* table, const char* name);
using NameFindFn = bool(__thiscall*)(const void* table, const char* name, std::int32_t bucket, std::int32_t* id);
using SelectionFn = const char*(__cdecl*)();
using ResourceByNameFn = std::int32_t(__thiscall*)(const void* database, const char* name);
using ProtoByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using PlayerByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using PlayerProtoFn = char*(__thiscall*)(const char* player, std::int32_t protoId);
using ResListGetFn = float(__thiscall*)(const void* list, std::int32_t resource);
using ResListSetFn = void(__thiscall*)(void* list, std::int32_t resource, float value);
using ResListFillFn = void(__thiscall*)(void* list, float value);
using PayFn = bool(__thiscall*)(char* player, const void* cost);
using RemoveFn = void(__thiscall*)(char* world, std::int32_t id, std::int32_t a, std::int32_t b);
using PlaceFn = bool(__thiscall*)(char* world, std::int32_t proto, std::int32_t player, const float* position,
                                  const float* forward, const float* right, std::int32_t a, std::int32_t b,
                                  std::int32_t c, std::int32_t d, std::int32_t e, std::int32_t f);
using CreateFn = char*(__thiscall*)(char* world, std::int32_t proto, std::int32_t player, const float* position,
                                    const float* forward, std::int32_t a, std::int32_t b, std::int32_t c, std::int32_t d);
using CommandCreateFn = char*(__cdecl*)(std::int32_t player, std::int32_t type, std::int32_t a, std::int32_t b);
using CommandPlayersFn = void(__thiscall*)(char* command, std::int32_t count, const std::int32_t* players);
using CommandUnitsFn = bool(__thiscall*)(char* command, std::int32_t count, const std::int32_t* ids);
using CommandQueueFn = void(__thiscall*)(void* queue, char* command, std::int32_t a, std::int32_t b);
using CommandDestroyFn = void(__thiscall*)(char* command, std::int32_t flags);
const auto kIsBuilt = reinterpret_cast<IsBuiltFn>(0x0044DDB4);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
const auto kSelection = reinterpret_cast<SelectionFn>(0x00453B28);
const auto kResourceByName = reinterpret_cast<ResourceByNameFn>(0x0044709C);
const auto kProtoByName = reinterpret_cast<ProtoByNameFn>(0x005A2346);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kResListGet = reinterpret_cast<ResListGetFn>(0x0044EFFF);
const auto kResListSet = reinterpret_cast<ResListSetFn>(0x0058EF83);
const auto kResListFill = reinterpret_cast<ResListFillFn>(0x004E2617);
const auto kPay = reinterpret_cast<PayFn>(0x008D946A);
// The population test of the stock maintain spawn (docs/engine-symbols.md, "Maintain spawn"): the player's copy of
// the proto (0x45311B), its PopulationCount [proto+0D8h], the flags AllowOverPopCap 9Fh and AlwaysAllowOverPopCap
// A3h (0x45EE02), the population (0x45805C, plus [player+78h]) and the cap (0x4581A1).
using PlayerCountFn = std::int32_t(__thiscall*)(const char* player);
using ProtoFlagFn = bool(__thiscall*)(const char* proto, std::int32_t bit);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kProtoFlag = reinterpret_cast<ProtoFlagFn>(0x0045EE02);
const auto kPlayerPop = reinterpret_cast<PlayerCountFn>(0x0045805C);
const auto kPlayerPopCap = reinterpret_cast<PlayerCountFn>(0x004581A1);
constexpr std::int32_t kAllowOverPopCap = 0x9F;
constexpr std::int32_t kAlwaysAllowOverPopCap = 0xA3;
using AffordFn = bool(__thiscall*)(const char* player, const void* cost);
const auto kAfford = reinterpret_cast<AffordFn>(0x008D6BAE);        // the payment's test of the player's stock
const auto kSharedAfford = reinterpret_cast<AffordFn>(0x008D6C1B);  // ... of the team's, with [world+6912h] set
using AppendFn = void(__thiscall*)(void* text, const wchar_t* more, std::int32_t length, std::int32_t start);
const auto kAppend = reinterpret_cast<AppendFn>(0x00443960);
constexpr std::int32_t kStringResources = 41543;  // "Not enough resources"
const auto kRemove = reinterpret_cast<RemoveFn>(0x004726B2);
const auto kCreate = reinterpret_cast<CreateFn>(0x00498ACC);
const auto kCommandCreate = reinterpret_cast<CommandCreateFn>(0x005695FC);
const auto kCommandPlayers = reinterpret_cast<CommandPlayersFn>(0x005683B9);
const auto kCommandUnits = reinterpret_cast<CommandUnitsFn>(0x005696E1);
const auto kCommandQueue = reinterpret_cast<CommandQueueFn>(0x00568A1A);
constexpr std::uint32_t kResListCount = 0x00C6DF38;  // the entries of every ResList

struct BString {
  wchar_t* text;
};
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t id);
using BStringFreeFn = void(__thiscall*)(BString* self);
using BStringAssignFn = void(__thiscall*)(wchar_t** self, const BString* source, std::int32_t, std::int32_t);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kBStringAssign = reinterpret_cast<BStringAssignFn>(0x00443BB8);

// A ResList laid out as the game's: +0 the encoded entries, +4 the encoded total.
struct ResList {
  std::uint32_t* entries;
  std::uint32_t total;
};

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// A text of the data: a string table ID, or the text itself.
struct Text {
  std::int32_t id = -1;
  std::wstring text;
};

struct GarrisonRule {
  std::string name;  // a proto or an abstract type
  std::int32_t amount = 1;
  std::int32_t type = -1;  // resolved for the current database
};

struct CostPart {
  std::string name;
  float amount = 0.0f;
  std::int32_t resource = -1;  // resolved for the current database
};

struct CommandRule {
  std::int32_t index = -1;  // in g_commandNames
  std::string name;
  std::int32_t factor = 0;
  std::string unitName;
  std::int32_t count = 1;
  std::vector<CostPart> cost;
  std::int32_t unitProto = -1;  // resolved for the current database
};

struct Tags {
  bool marked = false;  // a NurseryFactor tag was read
  float max = kDefaultMax;
  float initial = 0.0f;
  float interval = 0.0f;  // seconds; 0: no growth with time
  float step = 1.0f;
  bool exponential = false;
  float base = 2.0f;
  bool trickle = true;
  Text name;
  Text countLine;
  Text rateLine;
  std::vector<GarrisonRule> garrison;
  std::vector<CommandRule> commands;
};
std::map<std::int32_t, Tags> g_tags;  // by proto ID; the data load fills it
std::vector<std::uint8_t> g_marked;   // by proto ID: 1 for a marked proto that trickles (the rate filter's test)
std::vector<std::uint8_t> g_garrisoned;  // by proto ID: 1 for a marked proto with a garrison rule
std::vector<std::string> g_commandNames;  // lowercase; the index is the command's number in the network command
const char* g_resolvedFor = nullptr;      // the proto array the names were resolved against

struct TechValues {
  std::int32_t id;  // the proto ID the copy had: a reused pointer with another ID is ignored
  float max;
  float interval;
  float step;
  float base;
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

struct Entry {
  std::int32_t container;
  std::int32_t unit;
};
std::vector<Entry> g_entries;  // garrison entries into a tagged building, for the next world tick
const char* g_entriesWorld = nullptr;

struct Shipment {
  std::int32_t shipped;  // the proto FreeHomeCityUnit ships
  std::int32_t nursery;  // a proto or abstract type ID
  std::int32_t consume;  // -1 all, 0 none, N: at most N per unit
};
std::vector<Shipment> g_shipments;  // the effects' field +10h is an index; each techtree read appends to it
// It is never cleared: a loaded game reads the protos again (ForgetOnDataLoad) but not the techtree, whose effects
// keep their indices (as garrisonConvert's g_effects).

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

std::string Lower(std::string text) {
  for (char& c : text) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  return text;
}

std::string Trim(const std::string& text) {
  const auto first = text.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) {
    return {};
  }
  return text.substr(first, text.find_last_not_of(" \t\r\n") - first + 1);
}

std::string Narrow(const wchar_t* text) {
  std::string out;
  for (; text != nullptr && *text != L'\0'; ++text) {
    out += *text < 0x80 ? static_cast<char>(*text) : '?';
  }
  return out;
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

float BaseOf(const char* copy, const Tags& tags) {
  const TechValues* tech = TechOf(copy);
  const float base = tech != nullptr ? tech->base : tags.base;
  return base > 0.0f ? base : 0.0f;
}

// Exponential growth, t following the factor: with S(t) = b^0 + ... + b^(t-1), t is the largest t with
// floor(S(t)) <= factor (at most kMaxT), and the next step adds floor(S(t+1)) - floor(S(t)). A pure function of the
// factor and b, so every change of the factor moves t with it. b 1: t = factor, +1. b below 1: S stops growing, and
// once floor(S) is reached every t qualifies (t = kMaxT, +0).
constexpr std::uint32_t kMaxT = 0xFFFF;

struct Growth {
  std::uint32_t t = 0;
  std::int32_t next = 0;  // what the next step adds
};

Growth ExpGrowth(float base, std::int32_t factor) {
  const double b = base;
  const double f = factor;
  if (b == 1.0) {
    return {static_cast<std::uint32_t>(std::min<std::int32_t>(factor, static_cast<std::int32_t>(kMaxT))), 1};
  }
  // b 0: S is 1 from t 1 on. 0 < b < 1: S rises towards 1 / (1 - b) without reaching it, so every t qualifies once
  // the factor is at least the whole part of that limit (b 0.5: 2 is never reached, 1 is the most there is).
  if (b <= 0.0 ? factor >= 1 : b < 1.0 && std::floor(1.0 / (1.0 - b) - 1e-9) <= f) {
    return {kMaxT, 0};
  }
  double s = 0.0;  // S(t)
  double p = 1.0;  // b^t
  std::uint32_t t = 0;
  while (t < kMaxT && std::floor(s + p + 1e-9) <= f) {
    s += p;
    p *= b;
    ++t;
  }
  if (t >= kMaxT) {
    return {kMaxT, 0};
  }
  const double add = std::floor(s + p + 1e-9) - std::floor(s + 1e-9);
  return {t, add >= static_cast<double>(kMaxValue) ? kMaxValue : static_cast<std::int32_t>(add)};
}

// What one growth step adds: the step (linear), or the exponential step of the unit's t.
std::int32_t StepAmount(const char* copy, const Tags& tags, std::int32_t factor) {
  return tags.exponential ? ExpGrowth(BaseOf(copy, tags), factor).next : StepOf(copy, tags);
}

// The unit's t for the log: exponential only, else -1.
std::int32_t TOf(const char* copy, const Tags& tags, std::int32_t factor) {
  return tags.exponential ? static_cast<std::int32_t>(ExpGrowth(BaseOf(copy, tags), factor).t) : -1;
}

void SetFactor(State* state, std::int32_t factor) { state->factor = std::clamp(factor, 0, kMaxValue); }

// An addition, up to the cap; a unit already above it keeps what it has.
std::int32_t AddUpToCap(std::int32_t factor, std::int32_t amount, std::int32_t cap) {
  if (amount <= 0) {
    return std::max(0, factor + amount);
  }
  if (factor >= cap) {
    return factor;
  }
  return std::min(factor + amount, cap);
}

// --- Tags -----------------------------------------------------------------------------------------------------

const wchar_t* NodeText(const char* node) { return *reinterpret_cast<const wchar_t* const*>(node + 0x14); }

void Remark(std::int32_t id) {
  if (id < 0 || id > 0xFFFFF) {
    return;
  }
  const auto found = g_tags.find(id);
  const bool marked = found != g_tags.end() && found->second.marked;
  if (static_cast<std::size_t>(id) >= g_marked.size()) {
    g_marked.resize(static_cast<std::size_t>(id) + 1, 0);
    g_garrisoned.resize(static_cast<std::size_t>(id) + 1, 0);
  }
  g_marked[static_cast<std::size_t>(id)] = marked && found->second.trickle ? 1 : 0;
  g_garrisoned[static_cast<std::size_t>(id)] = marked && !found->second.garrison.empty() ? 1 : 0;
}

// The proto's tags, marked: any NurseryFactor tag makes it a nursery.
Tags& Mark(const char* proto) {
  Tags& tags = g_tags[ProtoId(proto)];
  tags.marked = true;
  return tags;
}

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

std::string Attribute(const char* node, const char* name, bool* present) {
  const void* value = nullptr;
  *present = node != nullptr && kXmlAttribute(node, name, &value) && value != nullptr;
  if (!*present) {
    return {};
  }
  const char* text = kXmlText(value);
  return text != nullptr ? text : "";
}

bool ParseInt(const std::string& text, long low, long high, std::int32_t* out) {
  const std::string trimmed = Trim(text);
  char* end = nullptr;
  const long value = std::strtol(trimmed.c_str(), &end, 10);
  if (trimmed.empty() || *end != '\0' || value < low || value > high) {
    return false;
  }
  *out = static_cast<std::int32_t>(value);
  return true;
}

bool __cdecl ReadMax(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"NurseryFactorMax", 0.0f, static_cast<float>(kMaxValue), &value)) {
    Mark(proto).max = std::floor(value);
    Remark(ProtoId(proto));
  }
  return true;
}

bool __cdecl ReadInitial(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"NurseryFactorInitial", 0.0f, static_cast<float>(kMaxValue), &value)) {
    Mark(proto).initial = std::floor(value);
    Remark(ProtoId(proto));
  }
  return true;
}

bool __cdecl ReadInterval(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"NurseryFactorInterval", 0.0f, 36000.0f, &value)) {
    Mark(proto).interval = value;
    Remark(ProtoId(proto));
  }
  return true;
}

bool __cdecl ReadStep(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"NurseryFactorStep", 1.0f, static_cast<float>(kMaxValue), &value)) {
    Mark(proto).step = std::floor(value);
    Remark(ProtoId(proto));
  }
  return true;
}

bool __cdecl ReadGrowthBase(void*, const char* node, char* proto) {
  float value = 0.0f;
  if (ReadNumber(node, proto, L"NurseryFactorGrowthBase", 0.0f, 100.0f, &value)) {
    Mark(proto).base = value;
    Remark(ProtoId(proto));
  }
  return true;
}

bool __cdecl ReadGrowth(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  if (text != nullptr && (_wcsicmp(text, L"linear") == 0 || _wcsicmp(text, L"exponential") == 0)) {
    Mark(proto).exponential = _wcsicmp(text, L"exponential") == 0;
    Remark(ProtoId(proto));
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
    Mark(proto).trickle = value >= 0.5f;
    Remark(ProtoId(proto));
  }
  return true;
}

bool __cdecl ReadName(void*, const char* node, char* proto) {
  ReadText(node, proto, L"NurseryFactorName", &Mark(proto).name);
  Remark(ProtoId(proto));
  return true;
}

bool __cdecl ReadCountLine(void*, const char* node, char* proto) {
  ReadText(node, proto, L"NurseryFactorRolloverCount", &Mark(proto).countLine);
  Remark(ProtoId(proto));
  return true;
}

bool __cdecl ReadRateLine(void*, const char* node, char* proto) {
  ReadText(node, proto, L"NurseryFactorRolloverRate", &Mark(proto).rateLine);
  Remark(ProtoId(proto));
  return true;
}

// <NurseryFactorGarrisonUnit amount="3">ypGoat</NurseryFactorGarrisonUnit>
bool __cdecl ReadGarrisonUnit(void*, const char* node, char* proto) {
  GarrisonRule rule;
  rule.name = Trim(Narrow(NodeText(node)));
  bool present = false;
  const std::string amount = Attribute(node, "amount", &present);
  if (rule.name.empty() || (present && !ParseInt(amount, 1, kMaxValue, &rule.amount))) {
    uhc::Log(L"nurseryFactor: proto %d (%hs): <NurseryFactorGarrisonUnit amount=\"%hs\">%hs</...> needs a unit name and "
             L"a whole amount from 1; ignored",
             ProtoId(proto), ProtoName(proto), amount.c_str(), rule.name.c_str());
    return true;
  }
  Tags& tags = Mark(proto);
  tags.garrison.push_back(rule);
  Remark(ProtoId(proto));
  if (g_log) {
    uhc::Log(L"nurseryFactor: proto %d (%hs): a %hs that enters adds %d", ProtoId(proto), ProtoName(proto),
             rule.name.c_str(), rule.amount);
  }
  return true;
}

// "Gold 100, Wood 50"
bool ParseCost(const std::string& text, std::vector<CostPart>* out) {
  std::size_t start = 0;
  while (start <= text.size()) {
    const std::size_t comma = text.find(',', start);
    const std::string part = Trim(text.substr(start, comma == std::string::npos ? std::string::npos : comma - start));
    if (!part.empty()) {
      const std::size_t space = part.find_last_of(" \t");
      if (space == std::string::npos) {
        return false;
      }
      CostPart cost;
      cost.name = Trim(part.substr(0, space));
      const std::string number = Trim(part.substr(space + 1));
      char* end = nullptr;
      const double amount = std::strtod(number.c_str(), &end);
      if (cost.name.empty() || number.empty() || *end != '\0' || !(amount >= 0.0) || amount > 1e7) {
        return false;
      }
      cost.amount = static_cast<float>(amount);
      out->push_back(cost);
    }
    if (comma == std::string::npos) {
      break;
    }
    start = comma + 1;
  }
  return true;
}

// <NurseryFactorCommand factor="-5" unit="CrateofCoin" count="1" cost="Gold 100">SellMinks</NurseryFactorCommand>
bool __cdecl ReadCommand(void*, const char* node, char* proto) {
  CommandRule rule;
  rule.name = Trim(Narrow(NodeText(node)));
  bool present = false;
  bool ok = !rule.name.empty();
  const std::string factor = Attribute(node, "factor", &present);
  ok = ok && (!present || ParseInt(factor, -kMaxValue, kMaxValue, &rule.factor));
  rule.unitName = Trim(Attribute(node, "unit", &present));
  const std::string count = Attribute(node, "count", &present);
  ok = ok && (!present || ParseInt(count, 0, kMaxSpawn, &rule.count));
  if (rule.unitName.empty()) {
    rule.count = 0;
  }
  const std::string cost = Attribute(node, "cost", &present);
  ok = ok && (!present || ParseCost(cost, &rule.cost));
  if (!ok) {
    uhc::Log(L"nurseryFactor: proto %d (%hs): <NurseryFactorCommand factor=\"%hs\" unit=\"%hs\" count=\"%hs\" "
             L"cost=\"%hs\">%hs</...>: needs a name, a whole factor, a count from 0 to %d and a cost such as "
             L"\"Gold 100, Wood 50\"; ignored",
             ProtoId(proto), ProtoName(proto), factor.c_str(), rule.unitName.c_str(), count.c_str(), cost.c_str(),
             rule.name.c_str(), kMaxSpawn);
    return true;
  }
  const std::string key = Lower(rule.name);
  const auto known = std::find(g_commandNames.begin(), g_commandNames.end(), key);
  rule.index = static_cast<std::int32_t>(known - g_commandNames.begin());
  if (known == g_commandNames.end()) {
    if (g_commandNames.size() >= static_cast<std::size_t>(kMaxCommands)) {
      return true;
    }
    g_commandNames.push_back(key);
  }
  Tags& tags = Mark(proto);
  for (CommandRule& existing : tags.commands) {
    if (existing.index == rule.index) {
      uhc::Log(L"nurseryFactor: proto %d (%hs): command %hs is given twice; the second is kept", ProtoId(proto),
               ProtoName(proto), rule.name.c_str());
      existing = rule;
      return true;
    }
  }
  tags.commands.push_back(rule);
  Remark(ProtoId(proto));
  if (g_log) {
    uhc::Log(L"nurseryFactor: proto %d (%hs): command %hs (%d): factor %+d, %d x %hs, cost \"%hs\"", ProtoId(proto),
             ProtoName(proto), rule.name.c_str(), rule.index, rule.factor, rule.count,
             rule.unitName.empty() ? "nothing" : rule.unitName.c_str(), cost.c_str());
  }
  return true;
}

// g_shipments stays (see its declaration). g_tech is filled again by the load, which runs every ProtoUnit Data
// effect of the researched techs after the protos are read.
void ForgetOnDataLoad(char*) {
  g_tags.clear();
  g_marked.clear();
  g_garrisoned.clear();
  g_commandNames.clear();
  g_resolvedFor = nullptr;
  g_tech.clear();
  g_pending.clear();
  g_entries.clear();
  g_units.clear();
  g_world = nullptr;
  g_cursor = 0;
}

std::int32_t TypeId(const void* db, const std::string& name) {
  const char* table = static_cast<const char*>(db) + kTypeNames;
  std::int32_t id = -1;
  if (name.empty() || !kNameFind(table, name.c_str(), kNameBucket(table, name.c_str()), &id)) {
    return -1;
  }
  return id;
}

// The names of the rules (units, types, resources), against the current database, once per data load.
void Resolve() {
  const char* database = Database();
  if (database == nullptr || Field<const char*>(database, kProtoTable) == g_resolvedFor) {
    return;
  }
  g_resolvedFor = Field<const char*>(database, kProtoTable);
  const std::int32_t firstAbstract = Field<std::int32_t>(database, kFirstAbstract);
  for (auto& [id, tags] : g_tags) {
    for (GarrisonRule& rule : tags.garrison) {
      rule.type = TypeId(database, rule.name);
      if (rule.type < 0) {
        uhc::Log(L"nurseryFactor: proto %d: <NurseryFactorGarrisonUnit> names %hs, no proto or unit type; ignored", id,
                 rule.name.c_str());
      }
    }
    for (CommandRule& rule : tags.commands) {
      rule.unitProto = rule.count > 0 ? kProtoByName(database, rule.unitName.c_str()) : -1;
      if (rule.count > 0 && (rule.unitProto < 0 || rule.unitProto >= firstAbstract)) {
        uhc::Log(L"nurseryFactor: proto %d: command %hs names %hs as its unit, which is no proto; the command makes "
                 L"no unit",
                 id, rule.name.c_str(), rule.unitName.c_str());
        rule.unitProto = -1;
      }
      for (CostPart& part : rule.cost) {
        part.resource = kResourceByName(database, part.name.c_str());
        if (part.resource < 0) {
          uhc::Log(L"nurseryFactor: proto %d: command %hs: %hs is no resource; that part of the cost is ignored", id,
                   rule.name.c_str(), part.name.c_str());
        }
      }
    }
  }
}

// --- Tech subtypes --------------------------------------------------------------------------------------------

TechValues* TechSlot(char* copy, const char* base) {
  const auto tag = g_tags.find(ProtoId(base));
  if (tag == g_tags.end() || !tag->second.marked) {
    return nullptr;
  }
  const TechValues fresh{ProtoId(copy), tag->second.max, tag->second.interval, tag->second.step, tag->second.base};
  auto inserted = g_tech.emplace(copy, fresh);
  if (inserted.first->second.id != ProtoId(copy)) {
    inserted.first->second = fresh;
  }
  return &inserted.first->second;
}

enum class Value { kMax, kInterval, kStep, kBase };

void ChangeValue(char* copy, const char* base, float amount, std::uint8_t relativity, bool unapply, Value which) {
  static const wchar_t* const kNames[] = {L"NurseryFactorMax", L"NurseryFactorInterval", L"NurseryFactorStep",
                                          L"NurseryFactorGrowthBase"};
  const wchar_t* name = kNames[static_cast<int>(which)];
  TechValues* slot = TechSlot(copy, base);
  if (slot == nullptr) {
    uhc::Log(L"nurseryFactor: tech subtype %ls on proto %d (%hs), which has no NurseryFactor tag; ignored", name,
             ProtoId(copy), ProtoName(copy));
    return;
  }
  const Tags& tags = g_tags[ProtoId(base)];
  float* fields[] = {&slot->max, &slot->interval, &slot->step, &slot->base};
  const float froms[] = {tags.max, tags.interval, tags.step, tags.base};
  float* field = fields[static_cast<int>(which)];
  const float before = *field;
  kEffectValue(relativity, field, froms[static_cast<int>(which)], amount, unapply);
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

void ChangeBase(char* copy, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  ChangeValue(copy, base, amount, relativity, unapply, Value::kBase);
}

void ChangeFactor(char* copy, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  if (unapply) {
    return;  // a change made is kept
  }
  const auto tag = g_tags.find(ProtoId(base));
  if (tag == g_tags.end() || !tag->second.marked) {
    uhc::Log(L"nurseryFactor: tech subtype NurseryFactor on proto %d (%hs), which has no NurseryFactor tag; ignored",
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
    state.progress = uhc::markers::Word(const_cast<char*>(marker), 2);  // word 3: t before 2026-11-26, unread
    state.factor = std::clamp(state.factor, 0, kMaxValue);
  } else {
    state.factor = std::min(Whole(tags->initial), Cap(copy, *tags));
  }
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

// The table's state of a living unit with a factor (made from its marker or its tags when the sweep has not reached
// it yet); null for any other unit.
State* StateOf(const char* world, const char* unit) {
  if (world != g_world) {
    Sync(world);
  }
  Consider(unit, true);
  const auto found = g_units.find(Field<std::int32_t>(unit, 0x10));
  return found != g_units.end() ? &found->second : nullptr;
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
      const std::int32_t cap = Cap(pending.copy, *tags);
      // Up to the cap, or what the unit had when it was already above it; never below 0.
      const std::int32_t upper = std::max(cap, before);
      SetFactor(&state, std::clamp(static_cast<std::int32_t>(std::floor(value + 1e-4f)), 0, upper));
      if (LogOk()) {
        uhc::Log(L"nurseryFactor: unit %d (%hs), NurseryFactor relativity %u amount %g: %d -> %d/%d, t %d -> %d", id,
                 ProtoName(pending.copy), pending.relativity, static_cast<double>(pending.amount), before,
                 state.factor, cap, TOf(pending.copy, *tags, before), TOf(pending.copy, *tags, state.factor));
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
  uhc::markers::Word(marker, 3) = 0;
}

// --- The garrison ---------------------------------------------------------------------------------------------

// From the shared garrison observer, inside the load: only queues (garrisonobservers.h).
void OnGarrison(char* container, char* unit) {
  if (g_garrisoned.empty()) {
    return;
  }
  const char* copy = Field<const char*>(container, 0x5C);
  const std::int32_t protoId = copy != nullptr ? ProtoId(copy) : -1;
  if (protoId < 0 || static_cast<std::size_t>(protoId) >= g_garrisoned.size() ||
      g_garrisoned[static_cast<std::size_t>(protoId)] == 0) {
    return;
  }
  const char* world = MainWorld();
  if (world != g_entriesWorld) {
    g_entries.clear();
    g_entriesWorld = world;
  }
  g_entries.push_back({Field<std::int32_t>(container, 0x10), Field<std::int32_t>(unit, 0x10)});
}

const GarrisonRule* RuleFor(const Tags& tags, const char* unitCopy) {
  for (const GarrisonRule& rule : tags.garrison) {
    if (rule.type >= 0 && (ProtoId(unitCopy) == rule.type || kProtoIsType(unitCopy, rule.type))) {
      return &rule;
    }
  }
  return nullptr;
}

void TakeGarrisoned(char* world) {
  if (g_entriesWorld != world) {
    g_entries.clear();
    return;
  }
  Resolve();
  const std::vector<Entry> entries = std::move(g_entries);
  g_entries.clear();
  for (const Entry& entry : entries) {
    char* container = UnitById(world, entry.container);
    char* unit = UnitById(world, entry.unit);
    if (container == nullptr || unit == nullptr || !IsAlive(container) || !IsAlive(unit) ||
        Field<std::int32_t>(unit, 0x6C) != entry.container) {
      continue;  // gone, or already out again
    }
    const char* copy = Field<const char*>(container, 0x5C);
    const Tags* tags = TagsOf(copy);
    const char* unitCopy = Field<const char*>(unit, 0x5C);
    const GarrisonRule* rule = tags != nullptr && unitCopy != nullptr ? RuleFor(*tags, unitCopy) : nullptr;
    State* state = rule != nullptr ? StateOf(world, container) : nullptr;
    if (state == nullptr) {
      continue;
    }
    const std::int32_t cap = Cap(copy, *tags);
    if (state->factor >= cap) {
      if (LogOk()) {
        uhc::Log(L"nurseryFactor: unit %d (%hs) entered unit %d (%hs), which is full (%d/%d): it stays inside",
                 entry.unit, ProtoName(unitCopy), entry.container, ProtoName(copy), state->factor, cap);
      }
      continue;
    }
    const std::int32_t before = state->factor;
    SetFactor(state, AddUpToCap(state->factor, rule->amount, cap));
    WriteMarker(container, *state);
    kRemove(world, entry.unit, 0, 1);
    if (LogOk()) {
      uhc::Log(L"nurseryFactor: unit %d (%hs) entered unit %d (%hs) of player %d and was taken: %d -> %d/%d, t %d -> %d",
               entry.unit, ProtoName(unitCopy), entry.container, ProtoName(copy), PlayerIdOf(container), before,
               state->factor, cap, TOf(copy, *tags, before), TOf(copy, *tags, state->factor));
    }
  }
}

void Tick(char* world, std::int32_t) {
  if (world != MainWorld() || g_tags.empty()) {
    return;
  }
  const std::uint32_t elapsed = Sync(world);
  if (!g_pending.empty()) {
    ApplyPending(world);
  }
  if (!g_entries.empty()) {
    TakeGarrisoned(world);
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
    if (kIsBuilt(unit)) {
      const std::uint32_t interval = IntervalMs(copy, *tags);
      if (state.factor >= cap || interval == 0) {
        state.progress = 0;
      } else {
        state.progress += elapsed;
        while (state.progress >= interval && state.factor < cap) {
          state.progress -= interval;
          const std::int32_t before = state.factor;
          const std::int32_t add = StepAmount(copy, *tags, before);
          state.factor = std::min(before + add, cap);
          if (LogOk()) {
            uhc::Log(L"nurseryFactor: unit %d (%hs) of player %d grows by %d to %d/%d (t %d -> %d, game time %u ms)",
                     it->first, ProtoName(copy), PlayerIdOf(unit), add, state.factor, cap, TOf(copy, *tags, before),
                     TOf(copy, *tags, state.factor), now);
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

// --- The commands ---------------------------------------------------------------------------------------------

const CommandRule* CommandOf(const Tags& tags, std::int32_t index) {
  for (const CommandRule& rule : tags.commands) {
    if (rule.index == index) {
      return &rule;
    }
  }
  return nullptr;
}

// Where `count` units of `proto` can stand around the building: rings of 16 points from its edge out, in a fixed
// order, so every machine finds the same ones. Fewer than `count` found: false.
bool FindSpots(char* world, const char* building, std::int32_t proto, std::int32_t player, std::int32_t count,
               std::vector<float>* spots) {
  const char* buildingProto = Field<const char*>(building, 0x5C);
  const float radius = std::max(Field<float>(buildingProto, 0x88), Field<float>(buildingProto, 0x8C)) * 1.42f + 1.0f;
  const float* center = reinterpret_cast<const float*>(building + 0x14);
  const float* forward = reinterpret_cast<const float*>(building + 0x20);
  const float* right = reinterpret_cast<const float*>(building + 0x38);
  const auto place = (*reinterpret_cast<PlaceFn const* const*>(world))[kPlaceSlot / 4];
  // A spot is tested with the units found before it as if they stood there already: at least 2 m apart.
  for (int ring = 0; ring < 4 && static_cast<std::int32_t>(spots->size() / 3) < count; ++ring) {
    const float distance = radius + 2.0f * static_cast<float>(ring);
    for (int k = 0; k < 16 && static_cast<std::int32_t>(spots->size() / 3) < count; ++k) {
      const float angle = static_cast<float>(k) * 0.39269908f;  // 22.5 degrees, from the building's front
      const float c = std::cos(angle);
      const float s = std::sin(angle);
      float at[3] = {center[0] + distance * (c * forward[0] + s * right[0]), center[1],
                     center[2] + distance * (c * forward[2] + s * right[2])};
      bool clear = true;
      for (std::size_t i = 0; i + 2 < spots->size() && clear; i += 3) {
        const float dx = (*spots)[i] - at[0];
        const float dz = (*spots)[i + 2] - at[2];
        clear = dx * dx + dz * dz >= 4.0f;
      }
      if (clear && place(world, proto, player, at, forward, right, 0, kPlaceFlags, 0, 0, 0, 0)) {
        spots->insert(spots->end(), at, at + 3);
      }
    }
  }
  return static_cast<std::int32_t>(spots->size() / 3) >= count;
}

// True when `count` units of `proto` would pass the player's population cap, as the stock maintain spawn tests one:
// a unit with no population (or AlwaysAllowOverPopCap) never does; with AllowOverPopCap the cap needs only one free
// slot; else the cap must hold the population and all of them.
bool PopBlocked(const char* player, std::int32_t proto, std::int32_t count) {
  const char* copy = player != nullptr && proto >= 0 && count > 0 ? kPlayerProto(player, proto) : nullptr;
  if (copy == nullptr) {
    return false;
  }
  const std::int32_t pop = Field<std::int32_t>(copy, 0xD8);
  if (pop <= 0 || kProtoFlag(copy, kAlwaysAllowOverPopCap)) {
    return false;
  }
  const std::int64_t used = static_cast<std::int64_t>(Field<std::int32_t>(player, 0x78)) + kPlayerPop(player);
  const std::int64_t cap = kPlayerPopCap(player);
  if (kProtoFlag(copy, kAllowOverPopCap)) {
    return cap - used <= 0;
  }
  return cap < used + static_cast<std::int64_t>(pop) * count;
}

// The cost as a ResList (the game's encoding through its setter); false when it has nothing to pay.
bool BuildCost(const CommandRule& rule, std::vector<std::uint32_t>* storage, ResList* list) {
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(kResListCount);
  bool any = false;
  for (const CostPart& part : rule.cost) {
    any = any || (part.resource >= 0 && part.resource < count && part.amount > 0.0f);
  }
  if (!any || count <= 0) {
    return false;
  }
  storage->assign(static_cast<std::size_t>(count), 0);
  list->entries = storage->data();
  list->total = 0;
  kResListFill(list, 0.0f);
  for (const CostPart& part : rule.cost) {
    if (part.resource >= 0 && part.resource < count && part.amount > 0.0f) {
      kResListSet(list, part.resource, kResListGet(list, part.resource) + part.amount);
    }
  }
  return true;
}

// One unit's run of a command: the factor, the cost, the units, in that order of tests; nothing changes on a refusal.
bool RunCommand(char* world, char* unit, std::int32_t playerId, std::int32_t index) {
  const char* copy = Field<const char*>(unit, 0x5C);
  const Tags* tags = TagsOf(copy);
  const CommandRule* rule = tags != nullptr ? CommandOf(*tags, index) : nullptr;
  const std::int32_t unitId = Field<std::int32_t>(unit, 0x10);
  if (rule == nullptr || !IsAlive(unit) || !kIsBuilt(unit) || PlayerIdOf(unit) != playerId) {
    return false;
  }
  State* state = StateOf(world, unit);
  if (state == nullptr) {
    return false;
  }
  const std::int32_t cap = Cap(copy, *tags);
  const char* why = nullptr;
  if (rule->factor < 0 && state->factor < -rule->factor) {
    why = "not enough factor";
  } else if (rule->factor > 0 && state->factor >= cap) {
    why = "full";
  }
  std::vector<float> spots;
  if (why == nullptr && rule->unitProto >= 0 && rule->count > 0 &&
      !FindSpots(world, unit, rule->unitProto, playerId, rule->count, &spots)) {
    why = "no room for the units";
  }
  char* player = kPlayerById(world, playerId);
  if (why == nullptr && rule->unitProto >= 0 && PopBlocked(player, rule->unitProto, rule->count)) {
    why = "population cap reached";
  }
  std::vector<std::uint32_t> storage;
  ResList cost{nullptr, 0};
  if (why == nullptr && player != nullptr && BuildCost(*rule, &storage, &cost) && !kPay(player, &cost)) {
    why = "not enough resources";
  }
  if (why != nullptr) {
    if (LogOk()) {
      uhc::Log(L"nurseryFactor: player %d, command %hs on unit %d (%hs) at %d/%d: refused, %hs", playerId,
               rule->name.c_str(), unitId, ProtoName(copy), state->factor, cap, why);
    }
    return false;
  }
  const std::int32_t before = state->factor;
  SetFactor(state, AddUpToCap(state->factor, rule->factor, cap));
  WriteMarker(unit, *state);
  std::int32_t made = 0;
  const float* forward = reinterpret_cast<const float*>(unit + 0x20);
  for (std::size_t i = 0; i + 2 < spots.size(); i += 3) {
    if (kCreate(world, rule->unitProto, playerId, &spots[i], forward, 0, -1, 0, -1) != nullptr) {
      ++made;
    }
  }
  if (LogOk()) {
    uhc::Log(L"nurseryFactor: player %d, command %hs on unit %d (%hs): %d -> %d/%d, t %d -> %d, %d unit(s) of proto %d "
             L"made",
             playerId, rule->name.c_str(), unitId, ProtoName(copy), before, state->factor, cap,
             TOf(copy, *tags, before), TOf(copy, *tags, state->factor), made, rule->unitProto);
  }
  return true;
}

}  // namespace

// From the hook at the head of the type 17h command's per-unit execute (hooks/nurserycmd_hooks.asm), on every machine,
// for a command whose [cmd+8Ch] has the magic: the unit's run of the command whose index is the low half.
extern "C" bool __stdcall UhcNurseryCommand(const char* command, char* unit) {
  char* world = const_cast<char*>(MainWorld());
  if (command == nullptr || unit == nullptr || world == nullptr || g_tags.empty()) {
    return false;
  }
  Resolve();
  const std::int32_t index = static_cast<std::int32_t>(Field<std::uint32_t>(command, 0x8C) & 0xFFFF);
  return RunCommand(world, unit, Field<std::int32_t>(command, 0x20), index);
}

namespace {

// The UI syscall nurseryFactorCommand("Name"): the network command for the local player's selected units that have
// the command. Interface only: what it changes happens when every machine runs the command.
void __cdecl NurseryFactorCommandSyscall(const char* name) {
  const char* game = Game();
  const char* world = MainWorld();
  if (name == nullptr || game == nullptr || world == nullptr) {
    return;
  }
  const std::string key = Lower(Trim(name));
  const auto known = std::find(g_commandNames.begin(), g_commandNames.end(), key);
  if (known == g_commandNames.end()) {
    uhc::Log(L"nurseryFactor: nurseryFactorCommand(\"%hs\"): no proto has that command", name);
    return;
  }
  const std::int32_t index = static_cast<std::int32_t>(known - g_commandNames.begin());
  std::int32_t player = Field<std::int32_t>(game, 0x3C0);
  const char* selection = kSelection();  // the local selection group: IDs [+10h], count [+14h]
  const std::int32_t count = selection == nullptr ? 0 : Field<std::int32_t>(selection, 0x14);
  const auto* ids = selection == nullptr ? nullptr : Field<const std::int32_t*>(selection, 0x10);
  std::vector<std::int32_t> units;
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    const char* unit = UnitById(world, ids[i]);
    const Tags* tags = unit != nullptr ? TagsOf(Field<const char*>(unit, 0x5C)) : nullptr;
    if (tags != nullptr && PlayerIdOf(unit) == player && CommandOf(*tags, index) != nullptr) {
      units.push_back(ids[i]);
    }
  }
  if (units.empty()) {
    return;
  }
  char* command = kCommandCreate(player, kTransformCommand, 0, -1);
  if (command == nullptr) {
    return;
  }
  kCommandPlayers(command, 1, &player);
  *reinterpret_cast<std::int32_t*>(command + 0x2C) = 3;
  *reinterpret_cast<std::int32_t*>(command + 0x3C) = 0;
  if (!kCommandUnits(command, static_cast<std::int32_t>(units.size()), units.data())) {
    (*reinterpret_cast<CommandDestroyFn const* const*>(command))[8 / 4](command, 1);
    return;
  }
  *reinterpret_cast<std::uint32_t*>(command + 0x8C) = kCommandMagic | static_cast<std::uint32_t>(index);
  kCommandQueue(Field<void*>(world, 8), command, 0, 0);
  if (LogOk()) {
    uhc::Log(L"nurseryFactor: player %d sends command %hs (%d) for %u unit(s)", player, key.c_str(), index,
             static_cast<unsigned>(units.size()));
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

std::string NodeAttribute(const char* node, const char* name) {
  bool present = false;
  return Attribute(node, name, &present);
}

bool ParseShipment(void* db, char* effect, const char* node) {
  const std::string shipped = NodeAttribute(node, "unittype");
  const std::string nursery = NodeAttribute(node, "nursery");
  const std::string consume = NodeAttribute(node, "consume");
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
    std::int32_t n = 0;
    if (!ParseInt(consume, 1, kMaxValue, &n)) {
      uhc::Log(L"nurseryFactor: a FreeHomeCityUnitByNurseryFactor effect has consume=\"%hs\"; expected all, none or a "
               L"whole number from 1; effect dropped",
               consume.c_str());
      return false;
    }
    shipment.consume = n;
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
      const std::int32_t before = state.factor;
      SetFactor(&state, state.factor - take);
      state.progress = 0;
      if (const Tags* tags = TagsOf(copy); tags != nullptr && LogOk()) {
        uhc::Log(L"nurseryFactor: player %d, FreeHomeCityUnitByNurseryFactor takes %d from unit %d (%hs): %d -> %d, "
                 L"t %d -> %d",
                 playerId, take, id, ProtoName(copy), before, state.factor, TOf(copy, *tags, before),
                 TOf(copy, *tags, state.factor));
      }
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

std::wstring ResolveText(const Text& text) {
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
  out->interval = IntervalMs(copy, *out->tags);
  out->built = kIsBuilt(unit);
  const auto found = g_units.find(Field<std::int32_t>(unit, 0x10));
  if (found != g_units.end() && MainWorld() == g_world) {
    out->factor = found->second.factor;
    out->progress = found->second.progress;
  } else {
    out->factor = std::min(Whole(out->tags->initial), out->cap);
  }
  out->step = StepAmount(copy, *out->tags, out->factor);  // what the next step adds
  return true;
}

std::wstring Line(const Text& text, const wchar_t* fallback, const Shown& shown, const std::wstring& name) {
  std::wstring line = text.id >= 0 || !text.text.empty() ? ResolveText(text) : std::wstring(fallback);
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

// The small progress pie after the row's text: one of kPieFrames pictures (art\ui\uhc\pie\pie_00 to pie_31, the
// share of the interval done towards the next step), as an inline icon, so the text layout puts it after the text, on
// the row's line and as tall as it. Shown while the unit grows (built, under its cap, with an interval). Only when
// the pictures are in the game folder; without them the pie is the portrait's (progresspie.h).
constexpr int kPieFrames = 32;
constexpr wchar_t kPieFirstFile[] = L"art\\ui\\uhc\\pie\\pie_00.ddt";
constexpr wchar_t kPieLastFile[] = L"art\\ui\\uhc\\pie\\pie_31.ddt";
bool g_pieInRow = false;

// An inline icon <icon="(N)(texture)"> is drawn N + 1 pixels wide and as tall as its text line, so N = the line - 1
// draws the square picture square. The lines, measured in game (2026-11-26; minuistats.cpp, IconSize, for the font
// switch at 960): the minimized row 17 px on a screen 960 px tall or more (1920 x 1080) and 14 px below (1366 x 768);
// the normal interface's stat panel 22 and 17 px. The screen's height: [[0C66044h]+608h].
int PieIconSize(bool statPanel) {
  const char* ui = *reinterpret_cast<const char* const*>(0x00C66044);
  const int height = ui == nullptr ? 0 : Field<std::int32_t>(ui, 0x608);
  const bool small = height > 0 && height < 960;
  return statPanel ? (small ? 16 : 21) : (small ? 13 : 16);
}

std::wstring PieTag(const Shown& shown, bool statPanel) {
  if (!g_pieInRow || !shown.built || shown.interval == 0 || shown.factor >= shown.cap) {
    return {};
  }
  const int frame = static_cast<int>(std::min<std::uint64_t>(
      static_cast<std::uint64_t>(shown.progress) * kPieFrames / shown.interval, kPieFrames - 1));
  wchar_t tag[80];
  swprintf_s(tag, L" <icon=\"(%d)(ui\\uhc\\pie\\pie_%02d)\">", PieIconSize(statPanel), frame);
  return tag;
}

// "3/10 minks", and "(once built)" on a foundation.
std::wstring Fraction(const Shown& shown, const std::wstring& name, bool foundation) {
  wchar_t value[64];
  swprintf_s(value, L"%d/%d", shown.factor, shown.cap);
  std::wstring text = value;
  if (!name.empty()) {
    text += L" " + name;
  }
  if (foundation && !shown.built) {
    text += L" (once built)";
  }
  return text;
}

std::wstring Tip(const Shown& shown, const std::wstring& name) {
  std::wstring tip = L"\x2022 " + Line(shown.tags->countLine, L"{current} out of {max} {name}.", shown, name);
  if (shown.interval > 0) {
    tip += L"\n\x2022 " + Line(shown.tags->rateLine, L"Produces {step} {name} every {seconds} seconds.", shown, name);
  }
  return tip;
}

// The minimized interface's row: "3/10 minks" in the label gadget, the rollover as its help text.
bool __stdcall NurseryRow(const char* panel, const char* unit) {
  Shown shown;
  if (!ShownOf(unit, &shown)) {
    return false;
  }
  const std::wstring name = ResolveText(shown.tags->name);
  if (!uhc::SetUnitPanelRow(panel, (Fraction(shown, name, true) + PieTag(shown, false)).c_str(), L"")) {
    return false;
  }
  uhc::SetUnitPanelRowTip(panel, Tip(shown, name).c_str());
  return true;
}

// The normal interface's stat panel row (after the HP row): the same text and rollover.
bool __stdcall NurseryStatRow(const char* panel, const char* unit, std::int32_t row) {
  Shown shown;
  if (!ShownOf(unit, &shown)) {
    return false;
  }
  const std::wstring name = ResolveText(shown.tags->name);
  const std::wstring tip = Tip(shown, name);
  return uhc::SetStatPanelRow(panel, row, L"", (Fraction(shown, name, true) + PieTag(shown, true)).c_str(), tip.c_str());
}

// The command panel's buttons (panelbuttons.h): a button whose click is nurseryFactorCommand("Name") is greyed, with
// the reason in red in its rollover, while none of the local player's selected units could run that command (the
// factor, the room under the cap, the population cap for its units, the cost); the units' placement is left to the
// command. Interface only.
void NurseryButton(const uhc::PanelButton& button) {
  static const char kPrefix[] = "nurseryFactorCommand(\"";
  const char* click = button.Click();
  if (_strnicmp(click, kPrefix, sizeof(kPrefix) - 1) != 0) {
    return;
  }
  const char* start = click + sizeof(kPrefix) - 1;
  const char* end = std::strchr(start, '"');
  const std::string key = Lower(std::string(start, end != nullptr ? end : start + std::strlen(start)));
  const auto known = std::find(g_commandNames.begin(), g_commandNames.end(), key);
  const char* game = Game();
  const char* world = MainWorld();
  const char* selection = kSelection();
  if (known == g_commandNames.end() || game == nullptr || world == nullptr || selection == nullptr) {
    return;
  }
  Resolve();
  const std::int32_t index = static_cast<std::int32_t>(known - g_commandNames.begin());
  const std::int32_t playerId = Field<std::int32_t>(game, 0x3C0);
  const char* player = kPlayerById(world, playerId);
  const std::int32_t count = Field<std::int32_t>(selection, 0x14);
  const auto* ids = Field<const std::int32_t*>(selection, 0x10);
  std::wstring reason;
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    char* unit = UnitById(world, ids[i]);
    const char* copy = unit != nullptr ? Field<const char*>(unit, 0x5C) : nullptr;
    const Tags* tags = TagsOf(copy);
    const CommandRule* rule = tags != nullptr ? CommandOf(*tags, index) : nullptr;
    if (rule == nullptr || PlayerIdOf(unit) != playerId || !kIsBuilt(unit)) {
      continue;
    }
    Shown shown;
    ShownOf(unit, &shown);
    const std::wstring name = ResolveText(tags->name);
    wchar_t text[160];
    if (rule->factor < 0 && shown.factor < -rule->factor) {
      swprintf_s(text, L"%d/%d %ls: %d needed", shown.factor, shown.cap, name.c_str(), -rule->factor);
      reason = text;
      continue;
    }
    if (rule->factor > 0 && shown.factor >= shown.cap) {
      swprintf_s(text, L"%d/%d %ls: full", shown.factor, shown.cap, name.c_str());
      reason = text;
      continue;
    }
    if (rule->unitProto >= 0 && PopBlocked(player, rule->unitProto, rule->count)) {
      reason = L"Population cap reached";
      continue;
    }
    std::vector<std::uint32_t> storage;
    ResList cost{nullptr, 0};
    if (player != nullptr && BuildCost(*rule, &storage, &cost) &&
        !(Field<std::uint8_t>(world, 0x6912) != 0 ? kSharedAfford(player, &cost) : kAfford(player, &cost))) {
      BString text41543{nullptr};
      kBStringFromId(&text41543, kStringResources);
      reason = text41543.text != nullptr ? text41543.text : L"Not enough resources";
      kBStringFree(&text41543);
      continue;
    }
    return;  // this unit can: the button stays as it is
  }
  if (reason.empty()) {
    return;  // no selected unit has the command
  }
  button.State() = 1;
  button.Click()[0] = 0;
  button.ShiftClick()[0] = 0;
  const std::wstring line = L"\n<color=1, 0.35, 0.35>" + reason + L"</color>";
  kAppend(button.Rollover(), line.c_str(), -1, -1);
}

// Without the pie pictures, the portrait's progress pie (progresspie.h): the share of the interval done towards the
// next step, while the unit grows (built, under its cap, with an interval); none at the cap.
bool __stdcall NurseryPie(const char* unit, float* fraction, std::uint32_t*) {
  Shown shown;
  if (!ShownOf(unit, &shown) || !shown.built || shown.interval == 0 || shown.factor >= shown.cap) {
    return false;
  }
  *fraction = static_cast<float>(shown.progress) / static_cast<float>(shown.interval);
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
  const std::wstring text = Fraction(shown, ResolveText(shown.tags->name), false);
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
      !AddProtoTagHandler("NurseryFactorGrowthBase", &ReadGrowthBase) ||
      !AddProtoTagHandler("NurseryFactorTrickle", &ReadTrickle) ||
      !AddProtoTagHandler("NurseryFactorName", &ReadName) ||
      !AddProtoTagHandler("NurseryFactorRolloverCount", &ReadCountLine) ||
      !AddProtoTagHandler("NurseryFactorRolloverRate", &ReadRateLine) ||
      !AddProtoTagHandler("NurseryFactorGarrisonUnit", &ReadGarrisonUnit) ||
      !AddProtoTagHandler("NurseryFactorCommand", &ReadCommand) ||
      !AddTechSubtype("NurseryFactor", &ChangeFactor) || !AddTechSubtype("NurseryFactorMax", &ChangeMax) ||
      !AddTechSubtype("NurseryFactorInterval", &ChangeInterval) ||
      !AddTechSubtype("NurseryFactorStep", &ChangeStep) ||
      !AddTechSubtype("NurseryFactorGrowthBase", &ChangeBase) ||
      !AddTechPlayerSubtype("FreeHomeCityUnitByNurseryFactor", &ParseShipment, &RunShipment) ||
      !OnDatabaseLoad(&ForgetOnDataLoad) || !AddWorldTick(&Tick) ||
      !AddAutoGatherRateFilter("nurseryFactor", &NurseryRate)) {
    return Outcome::kFailed;
  }
  // The garrison rule and the commands: each its own sites, so another DLL's patch there costs only that part.
  const bool garrison = AddGarrisonObserver(&OnGarrison, "nurseryFactor");
  if (!garrison) {
    Log(L"nurseryFactor: no <NurseryFactorGarrisonUnit> (the garrison entry hook is not available)");
  }
  bool commands = VerifyAll("nurseryFactor commands",
                            {&sites::kNurseryCmdExecute, &sites::kNetCommandCreate, &sites::kNetCommandPlayers,
                             &sites::kNetCommandUnits, &sites::kNetCommandQueue,
                             &sites::kPlayerById, &sites::kProtoByName, &sites::kResourceByName, &sites::kResListGet,
                             &sites::kResListSet, &sites::kResListFill, &sites::kUnitCreate, &sites::kKillSpawnPlace,
                             &sites::kUnitRemoveHead, &sites::kPlayerProtoEntry, &sites::kProtoFlag,
                             &sites::kPlayerPopulation, &sites::kPlayerPopCap}) &&
                  InstallSyscallHooks("nurseryFactor") &&
                  WriteJmp(sites::kNurseryCmdExecute.va, reinterpret_cast<const void*>(&UhcNurseryCmdHook), 5);
  if (commands) {
    SyscallDef def;
    def.group = SyscallGroup::kUi;
    def.retType = kSyscallVoid;
    def.name = "nurseryFactorCommand";
    def.fn = reinterpret_cast<const void*>(&NurseryFactorCommandSyscall);
    def.comment = "Runs the <NurseryFactorCommand> of that name on the local player's selected units.";
    def.source = "nurseryFactor";
    SyscallParam name;
    name.type = kSyscallString;
    def.params.push_back(name);
    AddSyscall(std::move(def));
    if (!VerifyAll("nurseryFactor buttons", {&sites::kBStringAppend, &sites::kPayAffordCheck,
                                                    &sites::kPaySharedAffordCheck, &sites::kCurrentSelectionGroup}) || !AddPanelButtonFilter(&NurseryButton)) {
      Log(L"nurseryFactor: the command buttons are not greyed when they cannot run");
    }
  } else {
    Log(L"nurseryFactor: no <NurseryFactorCommand> (its sites are not stock)");
  }
  if (!AddUnitPanelRow(&NurseryRow)) {
    Log(L"nurseryFactor: no row in the unit panel");
  }
  if (!AddStatPanelRow(&NurseryStatRow, "nurseryFactor")) {
    Log(L"nurseryFactor: no row in the stat panel");
  }
  g_pieInRow = GetFileAttributesW(kPieFirstFile) != INVALID_FILE_ATTRIBUTES &&
               GetFileAttributesW(kPieLastFile) != INVALID_FILE_ATTRIBUTES;
  if (g_pieInRow) {
    Log(L"nurseryFactor: the progress pie goes after the panel row's text (art\\ui\\uhc\\pie)");
  } else if (AddProgressPieSource(&NurseryPie)) {
    Log(L"nurseryFactor: art\\ui\\uhc\\pie\\pie_00.ddt to pie_31.ddt are not in the game folder: the progress pie goes "
        L"over the portrait");
  } else {
    Log(L"nurseryFactor: no progress pie");
  }
  if (!AddDataRef(L"uhcNurseryFactor", kDataRefString, &NurseryRef)) {
    Log(L"nurseryFactor: no data ref {uhcNurseryFactor}");
  }
  Log(L"nurseryFactor: the proto tags NurseryFactor*, the Data subtypes NurseryFactor, NurseryFactorMax, "
      L"NurseryFactorInterval, NurseryFactorStep, NurseryFactorGrowthBase and FreeHomeCityUnitByNurseryFactor, the "
      L"AutoGather rate x the factor, %ls%lsthe panel rows and {uhcNurseryFactor} are on%ls (multiplayer unverified)",
      garrison ? L"the garrison rule, " : L"", commands ? L"the UI syscall nurseryFactorCommand, " : L"",
      g_log ? L"; logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
