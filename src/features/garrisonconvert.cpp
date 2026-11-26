// garrisonConvert [log]: the units that enter a building become another unit. In a proto's <Unit>, one tag or more:
//
//   <GarrisonConvertTo>Musketeer</GarrisonConvertTo>                each unit becomes a Musketeer as it enters
//   <GarrisonConvertTo delay="10">Musketeer</GarrisonConvertTo>     one at a time, each after 10 seconds inside
//   <GarrisonConvertTo eject="true">Musketeer</GarrisonConvertTo>   and is put out of the building once converted
//   <GarrisonConvertTo from="Settler">Pikeman</GarrisonConvertTo>   only Settlers (a proto or an abstract type)
//
// Only the units of the building's owner are converted, and never a unit that already is the target of one of the
// building's tags, as the data or the techs have them (so a converted unit is not converted again). The unit is changed in place by the shared transform
// (transformcalls.h, so the transform observers such as veterancyBonus see it): it keeps its ID, its owner and its
// share of hit points; it stays inside, or with eject the unload of one unit 0x9C68C3 puts it out as the building's
// eject command does. The tags are read once per data load, by proto ID, in their order.
//
// Several tags: round robin. For each conversion the building takes, from its cursor, the first tag (in order,
// wrapping) whose from matches the unit in progress; the cursor then moves past that tag. With A (from Settler) and
// B (no from), Settler, Settler -> A, B; Musketeer, Settler -> B, A.
//
// The population: a conversion that would put the owner over his cap (the target's population minus the unit's, the
// test the Maintain spawn makes, with AllowOverPopCap and AlwaysAllowOverPopCap) waits, with its timer held full,
// and the owner's screen gets the train's own message once per pause (string 17996, "No population room for %s;
// training will be suspended.", and its sound: 0x9EB0D6). It goes on by itself once there is room.
//
// The entries come from the shared garrison observer (garrisonobservers.h), which only marks the building active; the
// conversions happen after the world update (worldtick.h). The queue is the building's own list of contained units
// [unit+70h] (count [+74h]), which is in entry order: the first unit of it that qualifies is the one in progress, so
// a unit that leaves simply drops out of it. State, kept on the building as saved markers (savedmarkers.h, stat 6Ch):
// 'GCNV' the time the unit in progress has spent, its ID and the game time of the write; 'GCRR' the round robin
// cursor and the pause. A game that starts or loads finds its active buildings with one walk of the world's units.
//
// Techs: Data subtypes on a ProtoUnit target change one player's copy of the building's tags (GarrisonConvertDelay,
// GarrisonConvertEject, GarrisonConvertTarget, GarrisonConvertFrom, GarrisonConvertAdd, GarrisonConvertRemove; the
// optional effect attribute tag="N" picks the N-th tag). A load applies the effects again, so nothing is saved.
//
// GarrisonConvertProgress (features.h) gives the panels the progress of a building; with a delay, the progress pie
// (progresspie.h, the train button's pie) fills over the portrait of a selected building while a unit converts.
#include <windows.h>

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../garrisonobservers.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../progresspie.h"
#include "../prototags.h"
#include "../savedmarkers.h"
#include "../techsubtypes.h"
#include "../transformcalls.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database, +3C0h the local player
constexpr std::int32_t kStat = 0x6C;               // savedmarkers.h: no other key uses it
constexpr std::uint32_t kWord = 0x564E4347;        // word 0 of the progress marker: 'GCNV'
constexpr std::uint32_t kCursorWord = 0x52524347;  // word 0 of the round robin marker: 'GCRR'
constexpr float kMaxDelay = 3600.0f;
constexpr std::size_t kMaxTags = 32;
constexpr int kMaxLogLines = 400;
constexpr std::size_t kTypeNames = 0x190;       // in the database: the unit type name table
constexpr std::size_t kFirstAbstract = 0x19B0;  // in the database: the first abstract type's ID
constexpr std::size_t kProtoTable = 0x54;       // in the database: the proto array (a new one for each data load)
constexpr std::uint32_t kProtoPop = 0xD8;       // the proto's population count
constexpr std::uint32_t kProtoDisplayName = 0x140;
constexpr std::int32_t kAllowOverPopCap = 0x9F;        // proto flags: needs only cap - used > 0
constexpr std::int32_t kAlwaysAllowOverPopCap = 0xA3;  // no population test
constexpr std::int32_t kStringNoPopRoom = 17996;       // cStringNoPopcapRoom, the train's message
constexpr std::uint32_t kMessageStyle = 0x00C6657C;    // the train's message: its style
constexpr std::uint32_t kNoPosition = 0x00C665E4;      // (-1, -1, -1): the unload finds the place
constexpr std::uint32_t kZeroVector = 0x00C66550;      // (0, 0, 0): no point to walk to

using IsAliveFn = bool(__thiscall*)(const char* unit);
using ProtoByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
using NameBucketFn = std::int32_t(__thiscall*)(const void* table, const char* name);
using NameFindFn = bool(__thiscall*)(const void* table, const char* name, std::int32_t bucket, std::int32_t* id);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
using PlayerProtoFn = char*(__thiscall*)(const char* player, std::int32_t protoId);
using PlayerCountFn = std::int32_t(__thiscall*)(const char* player);
using ProtoFlagFn = bool(__thiscall*)(const char* proto, std::int32_t bit);
using UnloadFn = bool(__thiscall*)(char* container, std::int32_t unitId, const void* position, bool usePosition,
                                   bool keepOrders, bool force, std::int32_t a6, const void* goTo, std::int32_t a8,
                                   std::int32_t a9);
using BStringFromIdFn = void*(__thiscall*)(void* string, std::int32_t id);
using BStringFreeFn = void(__thiscall*)(void* string);
using MessageFn = bool(__cdecl*)(const char* game, std::int32_t ms, const void* style, const wchar_t* format, ...);
using SoundFn = void(__thiscall*)(const char* game, std::int32_t sound, std::int32_t a);
const auto kProtoByName = reinterpret_cast<ProtoByNameFn>(0x005A2346);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kPlayerPop = reinterpret_cast<PlayerCountFn>(0x0045805C);
const auto kPlayerPopCap = reinterpret_cast<PlayerCountFn>(0x004581A1);  // with basePop / extraPop
const auto kProtoHasFlag = reinterpret_cast<ProtoFlagFn>(0x0045EE02);
const auto kUnload = reinterpret_cast<UnloadFn>(0x009C68C3);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kPlaySound = reinterpret_cast<SoundFn>(0x0050547A);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Tag {
  std::string target;      // the proto's name, as read or as a tech set it
  std::string from;        // empty: any unit
  float delay = 0.0f;      // seconds
  float baseDelay = 0.0f;  // the value the tag was made with (BasePercent's base)
  float eject = 0.0f;      // 1: put out once converted
  float baseEject = 0.0f;
  std::int32_t targetId = -1;  // resolved against the current database; -1: converts nothing
  std::int32_t fromId = -1;    // a proto's or an abstract type's ID; -1: any
  bool fromBad = false;        // a from that names nothing: the tag converts nothing

  std::uint32_t DelayMs() const { return static_cast<std::uint32_t>(delay * 1000.0f + 0.5f); }
  bool Ejects() const { return eject > 0.5f; }
};
using Tags = std::vector<Tag>;
std::map<std::int32_t, Tags> g_tags;  // by the building's proto ID; the data load fills it
const char* g_resolvedFor = nullptr;  // the proto array the names were resolved against

struct TechTags {
  std::int32_t id;  // the proto ID the copy had: a reused pointer with another ID starts again
  Tags tags;
};
std::unordered_map<const char*, TechTags> g_tech;  // by the player's copy of the proto; lookups only

struct EffectArgs {
  std::int32_t type = -1;  // unittype: an ID in the unit type table, -1 when the effect names none
  std::string typeName;
  std::uint32_t tag = 0;  // tag="N": the N-th tag; 0 every tag
};
std::vector<EffectArgs> g_effects;  // an effect's field +10h is its index; each techtree read appends to it

struct State {
  std::uint32_t elapsed = 0;  // ms of game time the unit in progress has spent
  std::int32_t head = -1;     // the unit in progress; -1: the next one that qualifies takes `elapsed` over
  std::uint32_t cursor = 0;   // the next tag to try first
  bool paused = false;        // waiting for population room (the message was shown)
  bool loaded = false;        // cursor and pause read from the building's marker
};
std::map<std::int32_t, State> g_active;  // by building ID, in ID order: the same walk on every machine

const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
bool g_rescan = false;  // a tech changed some tags: look again for buildings with units inside
int g_failures = 0;

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
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<IsAliveFn const* const*>(unit))[0xA4 / 4](unit); }

std::int32_t ProtoId(const char* proto) { return proto == nullptr ? -1 : Field<std::int32_t>(proto, 8); }

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* PlayerOf(const char* unit) { return Field<const char*>(unit, 0x44); }

std::int32_t UnitId(const char* unit) { return Field<std::int32_t>(unit, 0x10); }

const char* BuildingName(const char* building) { return ProtoName(Field<const char*>(building, 0x5C)); }

std::int32_t TypeId(const void* db, const char* name) {
  const char* table = static_cast<const char*>(db) + kTypeNames;
  std::int32_t id = -1;
  if (name == nullptr || *name == '\0' || !kNameFind(table, name, kNameBucket(table, name), &id)) {
    return -1;
  }
  return id;
}

// The tags read from the data, resolved against the current database once per data load.
void ResolveAll() {
  const char* database = Database();
  const char* table = database == nullptr ? nullptr : Field<const char*>(database, kProtoTable);
  if (table == nullptr || table == g_resolvedFor) {
    return;
  }
  g_resolvedFor = table;
  for (auto& [id, tags] : g_tags) {
    for (std::size_t i = 0; i < tags.size(); ++i) {
      Tag& tag = tags[i];
      tag.targetId = kProtoByName(database, tag.target.c_str());
      if (tag.targetId < 0) {
        uhc::Log(L"garrisonConvert: proto %d: <GarrisonConvertTo> %u, %hs, is not a proto; it converts nothing", id,
                 static_cast<unsigned>(i + 1), tag.target.c_str());
      }
      tag.fromId = -1;
      tag.fromBad = false;
      if (!tag.from.empty()) {
        tag.fromId = TypeId(database, tag.from.c_str());
        if (tag.fromId < 0) {
          tag.fromBad = true;
          uhc::Log(L"garrisonConvert: proto %d: <GarrisonConvertTo> %u: from=\"%hs\" is neither a proto nor a unit "
                   L"type; it converts nothing",
                   id, static_cast<unsigned>(i + 1), tag.from.c_str());
        }
      }
    }
  }
}

// The tags of the player's copy of a proto, as the data and the player's techs left them; null when it has none.
const Tags* TagsOfProto(const char* copy) {
  if (copy == nullptr || (g_tags.empty() && g_tech.empty())) {
    return nullptr;
  }
  ResolveAll();
  if (!g_tech.empty()) {
    const auto found = g_tech.find(copy);
    if (found != g_tech.end() && found->second.id == ProtoId(copy)) {
      return found->second.tags.empty() ? nullptr : &found->second.tags;
    }
  }
  const auto found = g_tags.find(ProtoId(copy));
  return found == g_tags.end() || found->second.empty() ? nullptr : &found->second;
}

const Tags* TagsOf(const char* unit) { return unit == nullptr ? nullptr : TagsOfProto(Field<const char*>(unit, 0x5C)); }

bool Matches(const Tag& tag, const char* copy) {
  if (tag.targetId < 0 || tag.fromBad) {
    return false;
  }
  return tag.fromId < 0 || ProtoId(copy) == tag.fromId || kProtoIsType(copy, tag.fromId);
}

bool IsTarget(const Tags& tags, std::int32_t protoId) {
  for (const Tag& tag : tags) {
    if (tag.targetId == protoId) {
      return true;
    }
  }
  return false;
}

// The tag a unit takes, from the cursor on; -1 when none of them takes it.
int ChooseTag(const Tags& tags, const char* copy, std::uint32_t cursor) {
  const std::size_t count = tags.size();
  for (std::size_t k = 0; k < count; ++k) {
    const std::size_t i = (cursor + k) % count;
    if (Matches(tags[i], copy)) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

// A target of the building's tags, as the techs left them or as the data has them (so that a tech that changes a
// target does not convert again the units the old target made).
bool IsBuildingTarget(const char* building, const Tags& tags, std::int32_t protoId) {
  if (IsTarget(tags, protoId)) {
    return true;
  }
  const auto data = g_tags.find(ProtoId(Field<const char*>(building, 0x5C)));
  return data != g_tags.end() && &data->second != &tags && IsTarget(data->second, protoId);
}

// A contained unit that qualifies: still inside, alive, the owner's, not a target of the building, and taken by a tag.
bool Qualifies(const char* unit, const char* building, const Tags& tags) {
  if (unit == nullptr || Field<std::int32_t>(unit, 0x6C) != UnitId(building) || PlayerOf(unit) != PlayerOf(building)) {
    return false;
  }
  const char* copy = Field<const char*>(unit, 0x5C);
  if (copy == nullptr || IsBuildingTarget(building, tags, ProtoId(copy)) || !IsAlive(unit)) {
    return false;
  }
  for (const Tag& tag : tags) {
    if (Matches(tag, copy)) {
      return true;
    }
  }
  return false;
}

// The first contained unit that qualifies, in entry order, and (if asked) how many do.
char* Head(const char* world, const char* building, const Tags& tags, std::int32_t* waiting) {
  const std::int32_t count = Field<std::int32_t>(building, 0x74);
  const std::int32_t* ids = Field<const std::int32_t*>(building, 0x70);
  char* head = nullptr;
  std::int32_t total = 0;
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    char* unit = UnitById(world, ids[i]);
    if (Qualifies(unit, building, tags)) {
      if (head == nullptr) {
        head = unit;
        if (waiting == nullptr) {
          break;
        }
      }
      ++total;
    }
  }
  if (waiting != nullptr) {
    *waiting = total;
  }
  return head;
}

// --- The tags --------------------------------------------------------------------------------------------------

std::string Trim(std::string text) {
  const auto first = text.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) {
    return {};
  }
  return text.substr(first, text.find_last_not_of(" \t\r\n") - first + 1);
}

std::string NarrowWide(const wchar_t* text) {
  std::string out;
  for (; text != nullptr && *text != L'\0'; ++text) {
    out += *text < 0x80 ? static_cast<char>(*text) : '?';
  }
  return Trim(out);
}

// True when the attribute is there; its text (maybe empty) in *out.
bool Attribute(const char* node, const char* name, std::string* out) {
  const void* value = nullptr;
  out->clear();
  if (node == nullptr || !kXmlAttribute(node, name, &value) || value == nullptr) {
    return false;
  }
  const char* text = kXmlText(value);
  *out = Trim(text == nullptr ? std::string() : std::string(text));
  return true;
}

bool __cdecl ReadConvertTo(void*, const char* node, char* proto) {
  const std::int32_t id = ProtoId(proto);
  Tag tag;
  tag.target = NarrowWide(*reinterpret_cast<const wchar_t* const*>(node + 0x14));
  if (tag.target.empty()) {
    uhc::Log(L"garrisonConvert: proto %d (%hs): <GarrisonConvertTo> is empty; ignored", id, ProtoName(proto));
    return true;
  }
  Tags& tags = g_tags[id];
  if (tags.size() >= kMaxTags) {
    uhc::Log(L"garrisonConvert: proto %d (%hs): more than %u <GarrisonConvertTo>; %hs ignored", id, ProtoName(proto),
             static_cast<unsigned>(kMaxTags), tag.target.c_str());
    return true;
  }
  std::string text;
  if (Attribute(node, "delay", &text)) {
    char* end = nullptr;
    const double seconds = std::strtod(text.c_str(), &end);
    if (text.empty() || *end != '\0' || !(seconds >= 0.0) || !(seconds <= kMaxDelay)) {
      uhc::Log(L"garrisonConvert: proto %d (%hs): delay=\"%hs\" is not a number of seconds from 0 to %g; 0 is used",
               id, ProtoName(proto), text.c_str(), static_cast<double>(kMaxDelay));
    } else {
      tag.delay = static_cast<float>(seconds);
    }
  }
  if (Attribute(node, "eject", &text)) {
    if (text.empty() || _stricmp(text.c_str(), "true") == 0 || text == "1") {
      tag.eject = 1.0f;
    } else if (_stricmp(text.c_str(), "false") != 0 && text != "0") {
      uhc::Log(L"garrisonConvert: proto %d (%hs): eject=\"%hs\" is not true, 1, false or 0; the units stay inside", id,
               ProtoName(proto), text.c_str());
    }
  }
  Attribute(node, "from", &tag.from);
  tag.baseDelay = tag.delay;
  tag.baseEject = tag.eject;
  tags.push_back(tag);
  g_resolvedFor = nullptr;
  if (g_log) {
    uhc::Log(L"garrisonConvert: proto %d (%hs), tag %u: %hs%hs become %hs, %ls %u ms%ls", id, ProtoName(proto),
             static_cast<unsigned>(tags.size()), tag.from.empty() ? "the units that enter" : "the units of ",
             tag.from.c_str(), tag.target.c_str(), tag.delay == 0.0f ? L"at once," : L"one at a time, each after",
             tag.DelayMs(), tag.Ejects() ? L", put out" : L"");
  }
  return true;
}

// g_effects stays: a loaded game reads the protos again but not the techtree, whose effects keep their indices.
void ForgetOnDataLoad(char*) {
  g_tags.clear();
  g_tech.clear();
  g_active.clear();
  g_resolvedFor = nullptr;
  g_world = nullptr;
  g_rescan = false;
}

// --- Tech subtypes ----------------------------------------------------------------------------------------------

enum class Unit { kProto, kProtoOrType, kProtoOptional };

// unittype and tag="N", into g_effects; the effect's field +10h is the index.
bool ParseEffect(void* db, char* effect, const char* node, const char* name, Unit rule) {
  EffectArgs args;
  std::string text;
  if (Attribute(node, "unittype", &text) && !text.empty()) {
    args.type = TypeId(db, text.c_str());
    args.typeName = text;
    if (args.type < 0) {
      uhc::Log(L"garrisonConvert: a %hs effect names the unknown unit %hs; effect dropped", name, text.c_str());
      return false;
    }
    const std::int32_t firstAbstract =
        *reinterpret_cast<const std::int32_t*>(static_cast<const char*>(db) + kFirstAbstract);
    if (rule != Unit::kProtoOrType && args.type >= firstAbstract) {
      uhc::Log(L"garrisonConvert: a %hs effect names %hs, an abstract type and not a proto; effect dropped", name,
               text.c_str());
      return false;
    }
  } else if (rule == Unit::kProto) {
    uhc::Log(L"garrisonConvert: a %hs effect names no unittype; effect dropped", name);
    return false;
  }
  if (Attribute(node, "tag", &text)) {
    char* end = nullptr;
    const long n = std::strtol(text.c_str(), &end, 10);
    if (text.empty() || *end != '\0' || n < 1 || n > static_cast<long>(kMaxTags)) {
      uhc::Log(L"garrisonConvert: a %hs effect has tag=\"%hs\", not a tag number from 1 to %u; effect dropped", name,
               text.c_str(), static_cast<unsigned>(kMaxTags));
      return false;
    }
    args.tag = static_cast<std::uint32_t>(n);
  }
  *reinterpret_cast<std::int32_t*>(effect + 0x10) = static_cast<std::int32_t>(g_effects.size());
  g_effects.push_back(args);
  return true;
}

bool ParseDelay(void* db, char* effect, const char* node) {
  return ParseEffect(db, effect, node, "GarrisonConvertDelay", Unit::kProtoOptional);
}
bool ParseEject(void* db, char* effect, const char* node) {
  return ParseEffect(db, effect, node, "GarrisonConvertEject", Unit::kProtoOptional);
}
bool ParseTarget(void* db, char* effect, const char* node) {
  return ParseEffect(db, effect, node, "GarrisonConvertTarget", Unit::kProto);
}
bool ParseFrom(void* db, char* effect, const char* node) {
  return ParseEffect(db, effect, node, "GarrisonConvertFrom", Unit::kProtoOrType);
}
bool ParseAdd(void* db, char* effect, const char* node) {
  return ParseEffect(db, effect, node, "GarrisonConvertAdd", Unit::kProto);
}
bool ParseRemove(void* db, char* effect, const char* node) {
  return ParseEffect(db, effect, node, "GarrisonConvertRemove", Unit::kProtoOptional);
}

// The player's copy of the tags, made from the data's the first time a tech changes them.
Tags* Slot(char* copy, const char* base) {
  ResolveAll();
  const auto data = g_tags.find(ProtoId(base));
  TechTags fresh{ProtoId(copy), data != g_tags.end() ? data->second : Tags()};
  auto inserted = g_tech.emplace(copy, fresh);
  if (inserted.first->second.id != ProtoId(copy)) {
    inserted.first->second = fresh;
  }
  return &inserted.first->second.tags;
}

const EffectArgs* ArgsOf(std::int32_t field) {
  return field >= 0 && static_cast<std::size_t>(field) < g_effects.size() ? &g_effects[field] : nullptr;
}

// The tags an effect picks: tag="N" if it has one, and with `byTarget`, the tags converting to its unittype.
bool Picks(const EffectArgs& args, const Tag& tag, std::size_t index, bool byTarget) {
  if (args.tag != 0 && index + 1 != args.tag) {
    return false;
  }
  return !byTarget || args.type < 0 || tag.targetId == args.type;
}

void Changed(const char* copy, const wchar_t* subtype, float amount, bool unapply, int changed) {
  g_rescan = true;
  if (LogOk()) {
    uhc::Log(L"garrisonConvert: proto %d (%hs), player's copy %p, tech subtype %ls, amount %g%ls: %d tag(s) changed",
             ProtoId(copy), ProtoName(copy), static_cast<const void*>(copy), subtype, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", changed);
  }
}

void NotUndone(const char* copy, const wchar_t* subtype) {
  if (LogOk()) {
    uhc::Log(L"garrisonConvert: proto %d (%hs): the removal of a %ls effect keeps the change", ProtoId(copy),
             ProtoName(copy), subtype);
  }
}

float ClampDelay(float seconds) { return seconds < 0.0f ? 0.0f : (seconds > kMaxDelay ? kMaxDelay : seconds); }

void ChangeDelay(char* copy, const char* base, std::int32_t field, float amount, std::uint8_t relativity,
                 bool unapply) {
  const EffectArgs* args = ArgsOf(field);
  if (args == nullptr) {
    return;
  }
  Tags& tags = *Slot(copy, base);
  int changed = 0;
  for (std::size_t i = 0; i < tags.size(); ++i) {
    if (Picks(*args, tags[i], i, true)) {
      kEffectValue(relativity, &tags[i].delay, tags[i].baseDelay, amount, unapply);
      tags[i].delay = ClampDelay(tags[i].delay);
      ++changed;
    }
  }
  Changed(copy, L"GarrisonConvertDelay", amount, unapply, changed);
}

void ChangeEject(char* copy, const char* base, std::int32_t field, float amount, std::uint8_t relativity,
                 bool unapply) {
  const EffectArgs* args = ArgsOf(field);
  if (args == nullptr) {
    return;
  }
  Tags& tags = *Slot(copy, base);
  int changed = 0;
  for (std::size_t i = 0; i < tags.size(); ++i) {
    if (Picks(*args, tags[i], i, true)) {
      kEffectValue(relativity, &tags[i].eject, tags[i].baseEject, amount, unapply);
      ++changed;
    }
  }
  Changed(copy, L"GarrisonConvertEject", amount, unapply, changed);
}

void ChangeTarget(char* copy, const char* base, std::int32_t field, float amount, std::uint8_t, bool unapply) {
  const EffectArgs* args = ArgsOf(field);
  if (args == nullptr) {
    return;
  }
  if (unapply) {
    NotUndone(copy, L"GarrisonConvertTarget");
    return;
  }
  Tags& tags = *Slot(copy, base);
  int changed = 0;
  for (std::size_t i = 0; i < tags.size(); ++i) {
    if (Picks(*args, tags[i], i, false)) {
      tags[i].target = args->typeName;
      tags[i].targetId = args->type;
      ++changed;
    }
  }
  Changed(copy, L"GarrisonConvertTarget", amount, unapply, changed);
}

void ChangeFrom(char* copy, const char* base, std::int32_t field, float amount, std::uint8_t, bool unapply) {
  const EffectArgs* args = ArgsOf(field);
  if (args == nullptr) {
    return;
  }
  if (unapply) {
    NotUndone(copy, L"GarrisonConvertFrom");
    return;
  }
  Tags& tags = *Slot(copy, base);
  int changed = 0;
  for (std::size_t i = 0; i < tags.size(); ++i) {
    if (Picks(*args, tags[i], i, false)) {
      tags[i].from = args->typeName;
      tags[i].fromId = args->type;
      tags[i].fromBad = false;
      ++changed;
    }
  }
  Changed(copy, L"GarrisonConvertFrom", amount, unapply, changed);
}

void ChangeAdd(char* copy, const char* base, std::int32_t field, float amount, std::uint8_t, bool unapply) {
  const EffectArgs* args = ArgsOf(field);
  if (args == nullptr) {
    return;
  }
  Tags& tags = *Slot(copy, base);
  if (unapply) {
    // The last tag with that target and no from goes, as the effect made it.
    for (std::size_t i = tags.size(); i-- > 0;) {
      if (tags[i].targetId == args->type && tags[i].from.empty()) {
        tags.erase(tags.begin() + static_cast<std::ptrdiff_t>(i));
        Changed(copy, L"GarrisonConvertAdd", amount, unapply, 1);
        return;
      }
    }
    Changed(copy, L"GarrisonConvertAdd", amount, unapply, 0);
    return;
  }
  if (tags.size() >= kMaxTags) {
    uhc::Log(L"garrisonConvert: proto %d (%hs): a GarrisonConvertAdd effect finds %u tags already; nothing added",
             ProtoId(copy), ProtoName(copy), static_cast<unsigned>(kMaxTags));
    return;
  }
  Tag tag;
  tag.target = args->typeName;
  tag.targetId = args->type;
  tag.delay = ClampDelay(amount);
  tag.baseDelay = tag.delay;
  tags.push_back(tag);
  Changed(copy, L"GarrisonConvertAdd", amount, unapply, 1);
}

void ChangeRemove(char* copy, const char* base, std::int32_t field, float amount, std::uint8_t, bool unapply) {
  const EffectArgs* args = ArgsOf(field);
  if (args == nullptr) {
    return;
  }
  if (unapply) {
    NotUndone(copy, L"GarrisonConvertRemove");
    return;
  }
  Tags& tags = *Slot(copy, base);
  int changed = 0;
  Tags kept;
  for (std::size_t i = 0; i < tags.size(); ++i) {
    if (Picks(*args, tags[i], i, true)) {
      ++changed;
    } else {
      kept.push_back(tags[i]);
    }
  }
  tags.swap(kept);
  Changed(copy, L"GarrisonConvertRemove", amount, unapply, changed);
}

// --- The buildings ----------------------------------------------------------------------------------------------

// Words 1 to 3 of 'GCNV': the time spent, the unit in progress, the game time of the write (so a loaded game adds
// the time of the update the save was made in, which the first tick after the load does not see).
void WriteProgress(char* building, const State& state, std::uint32_t now) {
  char* marker = uhc::markers::Find(building, kStat, kWord);
  if (marker == nullptr) {
    marker = uhc::markers::Take(building, kStat);
    if (marker == nullptr) {
      return;
    }
    uhc::markers::Word(marker, 0) = kWord;
  }
  uhc::markers::Word(marker, 1) = state.elapsed;
  uhc::markers::Word(marker, 2) = static_cast<std::uint32_t>(state.head);
  uhc::markers::Word(marker, 3) = now;
}

void ClearProgress(char* building) {
  if (char* marker = uhc::markers::Find(building, kStat, kWord)) {
    uhc::markers::Free(marker);
  }
}

// Words 1 and 2 of 'GCRR': the cursor and the pause. Written when they change; a building with both at 0 has none.
void WriteCursor(char* building, const State& state) {
  char* marker = uhc::markers::Find(building, kStat, kCursorWord);
  if (marker == nullptr) {
    if (state.cursor == 0 && !state.paused) {
      return;
    }
    marker = uhc::markers::Take(building, kStat);
    if (marker == nullptr) {
      return;
    }
    uhc::markers::Word(marker, 0) = kCursorWord;
  }
  uhc::markers::Word(marker, 1) = state.cursor;
  uhc::markers::Word(marker, 2) = state.paused ? 1u : 0u;
}

void ReadCursor(const char* building, State* state) {
  if (char* marker = uhc::markers::Find(building, kStat, kCursorWord)) {
    state->cursor = uhc::markers::Word(marker, 1);
    state->paused = uhc::markers::Word(marker, 2) != 0;
  }
  state->loaded = true;
}

std::wstring StringById(std::int32_t id) {
  struct BString {
    const wchar_t* text;
  } text{nullptr};
  kBStringFromId(&text, id);
  std::wstring copy = text.text == nullptr ? L"" : text.text;
  kBStringFree(&text);
  return copy;
}

// Room in the owner's population for the unit to become the target: the Maintain spawn's test, on the difference.
bool PopRoom(const char* player, const char* unitCopy, std::int32_t targetId) {
  const char* target = kPlayerProto(player, targetId);
  if (target == nullptr) {
    return true;
  }
  const std::int32_t delta = Field<std::int32_t>(target, kProtoPop) - Field<std::int32_t>(unitCopy, kProtoPop);
  if (delta <= 0 || kProtoHasFlag(target, kAlwaysAllowOverPopCap)) {
    return true;
  }
  const std::int32_t used = Field<std::int32_t>(player, 0x78) + kPlayerPop(player);
  const std::int32_t cap = kPlayerPopCap(player);
  if (kProtoHasFlag(target, kAllowOverPopCap)) {
    return cap - used > 0;
  }
  return cap >= used + delta;
}

// The train's own message and sound, on the owner's screen only (0x9EB0D6): interface, nothing reaches the game.
void ShowPopMessage(const char* player, std::int32_t targetId) {
  const char* game = Game();
  if (game == nullptr || player == nullptr || Field<std::int32_t>(game, 0x3C0) != Field<std::int32_t>(player, 0)) {
    return;
  }
  const char* target = kPlayerProto(player, targetId);
  const std::wstring format = StringById(kStringNoPopRoom);
  const std::wstring name = target == nullptr ? L"?" : StringById(Field<std::int32_t>(target, kProtoDisplayName));
  if (format.empty()) {
    return;
  }
  const auto message = (*reinterpret_cast<MessageFn const* const*>(game))[0x68 / 4];
  message(game, 2000, reinterpret_cast<const void*>(kMessageStyle), format.c_str(), name.c_str());
  kPlaySound(game, 4, 0);
}

bool Convert(char* unit, const char* building, const Tag& tag, std::size_t index, std::uint32_t now) {
  const std::int32_t id = UnitId(unit);
  const char* before = Field<const char*>(unit, 0x5C);
  const std::int32_t fromId = ProtoId(before);
  const char* fromName = ProtoName(before);
  uhc::TransformUnit(unit, tag.targetId);
  const char* after = Field<const char*>(unit, 0x5C);
  const bool done = ProtoId(after) == tag.targetId;
  if (!done) {
    if (++g_failures <= 20) {
      uhc::Log(L"garrisonConvert: unit %d (%hs) in %hs %d did not become %hs (proto %d); it waits", id, fromName,
               BuildingName(building), UnitId(building), tag.target.c_str(), tag.targetId);
    }
  } else if (LogOk()) {
    uhc::Log(L"garrisonConvert: unit %d (%hs) in %hs %d became %hs (tag %u, proto %d -> %d, game time %u ms)", id,
             fromName, BuildingName(building), UnitId(building), ProtoName(after), static_cast<unsigned>(index + 1),
             fromId, tag.targetId, now);
  }
  return done;
}

// The building's eject of one unit: the unload 0x9C68C3 as the command handler FUN_009CBEA1 calls it (the place found
// around the building, no point to walk to), forced as the death eject FUN_009C6C79 does.
void Eject(char* building, const char* unit, std::uint32_t now) {
  const std::int32_t id = UnitId(unit);
  const bool out = kUnload(building, id, reinterpret_cast<const void*>(kNoPosition), false, false, true, -1,
                           reinterpret_cast<const void*>(kZeroVector), 0, 0);
  if (!out) {
    uhc::Log(L"garrisonConvert: unit %d could not be put out of %hs %d (no room around it?); it stays inside", id,
             BuildingName(building), UnitId(building));
  } else if (LogOk()) {
    uhc::Log(L"garrisonConvert: unit %d put out of %hs %d (game time %u ms)", id, BuildingName(building),
             UnitId(building), now);
  }
}

void Consider(char* unit, std::uint32_t now) {
  if (unit == nullptr || Field<std::int32_t>(unit, 0x74) <= 0 || TagsOf(unit) == nullptr || !IsAlive(unit)) {
    return;
  }
  const std::int32_t id = UnitId(unit);
  if (g_active.count(id) != 0) {
    return;
  }
  State state;
  if (char* marker = uhc::markers::Find(unit, kStat, kWord)) {
    const std::uint32_t written = uhc::markers::Word(marker, 3);
    state.elapsed = uhc::markers::Word(marker, 1) + (now > written && now - written < 60000 ? now - written : 0);
    state.head = static_cast<std::int32_t>(uhc::markers::Word(marker, 2));
  }
  ReadCursor(unit, &state);
  g_active.emplace(id, state);
}

// The buildings with units inside, after a game started or loaded (`clear`) or after a tech changed some tags. One walk.
void Walk(const char* world, bool clear) {
  if (clear) {
    g_active.clear();
  }
  const std::size_t before = g_active.size();
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
    Consider(table[i], now);
  }
  if (g_active.size() != before) {
    uhc::Log(L"garrisonConvert: %u building(s) with units inside %ls (game time %u ms)",
             static_cast<unsigned>(g_active.size() - before), clear ? L"in this game" : L"after a tech", now);
  }
}

// The game time since the last tick; a new game rebuilds the list and gives 0.
std::uint32_t Sync(const char* world) {
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const bool sameGame = world == g_world && now >= g_lastTime && step - g_lastStep <= 1;
  const std::uint32_t elapsed = sameGame ? now - g_lastTime : 0;
  if (!sameGame) {
    g_world = world;
    g_rescan = false;
    Walk(world, true);
  }
  g_lastTime = now;
  g_lastStep = step;
  return elapsed;
}

// From the shared garrison observer, inside the load: only marks the building.
void OnEnter(char* container, char*) {
  if ((g_tags.empty() && g_tech.empty()) || TagsOf(container) == nullptr) {
    return;
  }
  g_active.emplace(UnitId(container), State{});
}

// One building's conversions for this tick; false when it has nothing left to do.
bool Step(const char* world, char* building, State& state, std::uint32_t elapsed, std::uint32_t now) {
  const Tags* tags = TagsOf(building);
  if (tags == nullptr || !IsAlive(building)) {
    return false;
  }
  if (!state.loaded) {
    ReadCursor(building, &state);
  }
  const char* owner = PlayerOf(building);
  bool added = false;
  const std::int32_t rounds = Field<std::int32_t>(building, 0x74) + 1;
  for (std::int32_t round = 0; round < rounds; ++round) {
    char* head = Head(world, building, *tags, nullptr);
    if (head == nullptr) {
      ClearProgress(building);
      if (state.paused) {
        state.paused = false;
        WriteCursor(building, state);
      }
      return false;
    }
    const std::int32_t headId = UnitId(head);
    if (state.head != headId) {
      if (state.head >= 0) {
        state.elapsed = 0;  // the unit in progress left: the next one starts again
      }
      state.head = headId;
    }
    if (!added) {
      state.elapsed += elapsed;
      added = true;
    }
    const char* copy = Field<const char*>(head, 0x5C);
    const int index = ChooseTag(*tags, copy, state.cursor);
    if (index < 0) {
      return false;  // not reached: Qualifies found a tag that takes it
    }
    const Tag tag = (*tags)[static_cast<std::size_t>(index)];  // a copy: the transform may run tech code
    const std::uint32_t delay = tag.DelayMs();
    if (state.elapsed < delay) {
      break;
    }
    if (owner != nullptr && !PopRoom(owner, copy, tag.targetId)) {
      state.elapsed = delay;  // held full until there is room
      if (!state.paused) {
        state.paused = true;
        WriteCursor(building, state);
        if (LogOk()) {
          uhc::Log(L"garrisonConvert: %hs %d waits: no population room for unit %d to become %hs (population %d + "
                   L"%d of %d, game time %u ms)",
                   BuildingName(building), UnitId(building), headId, tag.target.c_str(),
                   Field<std::int32_t>(owner, 0x78) + kPlayerPop(owner),
                   kPlayerProto(owner, tag.targetId) == nullptr
                       ? 0
                       : Field<std::int32_t>(kPlayerProto(owner, tag.targetId), kProtoPop) -
                             Field<std::int32_t>(copy, kProtoPop),
                   kPlayerPopCap(owner), now);
        }
        ShowPopMessage(owner, tag.targetId);
      }
      break;
    }
    if (state.paused) {
      state.paused = false;
      if (LogOk()) {
        uhc::Log(L"garrisonConvert: %hs %d goes on: population room (game time %u ms)", BuildingName(building),
                 UnitId(building), now);
      }
    }
    if (!Convert(head, building, tag, static_cast<std::size_t>(index), now)) {
      WriteCursor(building, state);
      break;
    }
    state.elapsed -= delay;
    state.head = -1;
    state.cursor = static_cast<std::uint32_t>((static_cast<std::size_t>(index) + 1) % tags->size());
    WriteCursor(building, state);
    if (tag.Ejects()) {
      Eject(building, head, now);
    }
    tags = TagsOf(building);
    if (tags == nullptr) {
      return false;
    }
  }
  WriteProgress(building, state, now);
  return true;
}

void Tick(char* world, std::int32_t) {
  if (world != MainWorld() || (g_tags.empty() && g_tech.empty())) {
    return;
  }
  const std::uint32_t elapsed = Sync(world);
  if (g_rescan) {
    g_rescan = false;
    Walk(world, false);
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  for (auto it = g_active.begin(); it != g_active.end();) {
    char* building = UnitById(world, it->first);
    if (building == nullptr || !Step(world, building, it->second, elapsed, now)) {
      it = g_active.erase(it);
    } else {
      ++it;
    }
  }
}

}  // namespace

namespace uhc {

bool GarrisonConvertProgress(const char* building, float* fraction, std::int32_t* waiting) {
  if (building == nullptr || (g_tags.empty() && g_tech.empty()) || MainWorld() != g_world) {
    return false;
  }
  const Tags* tags = TagsOf(building);
  if (tags == nullptr) {
    return false;
  }
  std::int32_t count = 0;
  const char* head = Head(g_world, building, *tags, &count);
  if (head == nullptr) {
    return false;
  }
  const auto found = g_active.find(UnitId(building));
  const State* state = found != g_active.end() ? &found->second : nullptr;
  const int index = ChooseTag(*tags, Field<const char*>(head, 0x5C), state != nullptr ? state->cursor : 0);
  if (index < 0) {
    return false;
  }
  const std::uint32_t delay = (*tags)[static_cast<std::size_t>(index)].DelayMs();
  const std::uint32_t spent = state != nullptr && state->head == UnitId(head) ? state->elapsed : 0;
  if (fraction != nullptr) {
    *fraction = delay == 0 || (state != nullptr && state->paused)
                    ? 1.0f
                    : static_cast<float>(spent < delay ? spent : delay) / static_cast<float>(delay);
  }
  if (waiting != nullptr) {
    *waiting = count;
  }
  return true;
}

namespace {

// The progress pie over the portrait (progresspie.h): a selected building whose unit in progress has a delay.
bool __stdcall PieSource(const char* unit, float* fraction, std::uint32_t*) {
  if ((g_tags.empty() && g_tech.empty()) || MainWorld() != g_world) {
    return false;
  }
  const Tags* tags = TagsOf(unit);
  if (tags == nullptr) {
    return false;
  }
  const char* head = Head(g_world, unit, *tags, nullptr);
  if (head == nullptr) {
    return false;
  }
  const auto found = g_active.find(UnitId(unit));
  const int index =
      ChooseTag(*tags, Field<const char*>(head, 0x5C), found != g_active.end() ? found->second.cursor : 0);
  return index >= 0 && (*tags)[static_cast<std::size_t>(index)].DelayMs() != 0 &&
         GarrisonConvertProgress(unit, fraction, nullptr);
}

}  // namespace

Outcome ApplyGarrisonConvert(const Config& config) {
  const Config::Args* args = config.First("garrisonConvert");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"garrisonConvert: unknown option %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("garrisonConvert",
                 {&sites::kUnitAliveSlot, &sites::kProtoByName, &sites::kXmlAttribute, &sites::kIsA,
                  &sites::kEffectValueApply, &sites::kPlayerProtoEntry, &sites::kProtoFlag, &sites::kPlayerPopHead,
                  &sites::kPlayerPopCapHead, &sites::kGarrisonUnloadHead, &sites::kPopCapToast,
                  &sites::kPopCapToastSound, &sites::kBStringFromId, &sites::kBStringFree}) ||
      !AddProtoTagHandler("GarrisonConvertTo", &ReadConvertTo) || !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !AddTechProtoSubtype("GarrisonConvertDelay", &ParseDelay, &ChangeDelay) ||
      !AddTechProtoSubtype("GarrisonConvertEject", &ParseEject, &ChangeEject) ||
      !AddTechProtoSubtype("GarrisonConvertTarget", &ParseTarget, &ChangeTarget) ||
      !AddTechProtoSubtype("GarrisonConvertFrom", &ParseFrom, &ChangeFrom) ||
      !AddTechProtoSubtype("GarrisonConvertAdd", &ParseAdd, &ChangeAdd) ||
      !AddTechProtoSubtype("GarrisonConvertRemove", &ParseRemove, &ChangeRemove) || !AddWorldTick(&Tick) ||
      !AddGarrisonObserver(&OnEnter, "garrisonConvert")) {
    return Outcome::kFailed;
  }
  const bool pie = AddProgressPieSource(&PieSource);
  Log(L"garrisonConvert: <GarrisonConvertTo> converts the units that enter a building (several tags in turn, eject, "
      L"from, the population cap, six tech subtypes)%ls%ls",
      pie ? L"; the progress pie over the portrait" : L"; no progress pie", g_log ? L"; logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
