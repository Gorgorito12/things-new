// sharedBuildLimit: a proto's build limit may be shared with other units.
//
//   <SharedBuildLimitUnit>Name</SharedBuildLimitUnit>             whose limit applies (default: its own)
//   <SharedBuildLimitUnitType weight="N">Type</SharedBuildLimitUnitType>   what counts toward it: an
//                                                                 abstract type or a proto; repeatable
//   <TeamBuildLimit>1</TeamBuildLimit>                            the whole team counts
//   <UseSharedBuildLimit>1</UseSharedBuildLimit>                  accepted; the lists alone are enough
//   <SharedBuildLimitUnitTypes weight="N">Type</SharedBuildLimitUnitTypes>   the same list, plural
//   <SettlerBuildLimit>1</SettlerBuildLimit>                      the limit of the civ's settler, shared by
//                                                                 every unit of LogicalTypeSettlerBuildLimit;
//                                                                 the civ names it in civs.xml:
//                                                                 <SettlerProtoName>Settler</SettlerProtoName>
//
// Stock compares two numbers everywhere: a count of the proto, by many routes, and the limit, always
// from 0x4C7B5F (50 callers: the buttons, the train action, Maintain, cards, the AI). So the count stays
// and the hook changes only the limit: for a tagged proto it returns the room the other units leave,
// (limit - the others' weight) / its own weight, never below 0, because a negative limit means none.
// Every check then gives the right answer, and a batch that does not fit is cut as stock cuts it. The
// others are counted by 0x4C7BC5 with the arguments of the train check, so queued units count.
// The two tooltips that print "Build Limit: N out of M" are the exception: they get the group's total
// and the real limit, through their own count calls and the return address of their limit calls.
// The tags are read once and are the same for every player; the limit comes from the player's copy
// of the proto, so techs reach it. A tech effect type="Data" subtype="EnableSharedBuildLimit" with
// amount 0 turns the share off for that player's copy (the proto keeps its own limit), anything else
// on; base 1. The hook is in hooks/sharedlimit_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "../civtags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

extern "C" {
void UhcSharedLimitHook();
void UhcSharedLimitStock();  // the stock entry: thiscall(player, proto), ret 4
}

namespace {

constexpr std::uint32_t kLimitEntry = 0x004C7B5F;
constexpr std::uint32_t kTooltipCounts[] = {0x004C8B81, 0x0070F5EF};
// After the calls of the limit in the two tooltips.
constexpr std::uint32_t kTooltipLimits[] = {0x004C8B46, 0x004C8B9E, 0x004C8BC4, 0x0070F5D5, 0x0070F60C, 0x0070F628};
constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr int kMaxLogLines = 200;
constexpr int kMaxPlayers = 16;

using LimitFn = std::int32_t(__thiscall*)(const char* player, const char* proto);
using CountFn = std::int32_t(__thiscall*)(const char* proto, std::int32_t player, bool first, bool second);
using PlayerProtoFn = const char*(__thiscall*)(const char* player, std::int32_t id);
using ProtoByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);

const auto kCount = reinterpret_cast<CountFn>(0x004C7BC5);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kProtoById = reinterpret_cast<ProtoByIdFn>(0x0045316E);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);

struct Listed {
  std::string name;
  std::int32_t weight;
};

struct Share {
  std::string limitUnit;       // empty: the proto's own limit
  std::vector<Listed> listed;  // as the data has them
  bool team = false;
  bool use = false;            // <UseSharedBuildLimit>, read and kept for the log
  bool settler = false;        // <SettlerBuildLimit>
  bool built = false;
  std::int32_t limitProto = -1;
  std::int32_t ownWeight = 1;
  std::vector<std::pair<std::int32_t, std::int32_t>> members;  // proto ID, weight
  std::int32_t lastLogged = -2;
};

std::unordered_map<std::int32_t, Share> g_shares;  // by proto ID; the load fills it
std::vector<bool> g_tagged;                        // by proto ID, for the calls of every other proto
bool g_log = false;
int g_logLines = 0;

// <SettlerProtoName> per civ, from civs.xml; the proto is resolved by name on first use and again
// when the database's proto table changes (a data reload).
struct SettlerCiv {
  std::string name;
  const char* table = nullptr;
  std::int32_t proto = -1;
};
std::vector<SettlerCiv> g_settlerCivs;  // by civ ID
std::int32_t g_settlerType = -1;        // LogicalTypeSettlerBuildLimit

bool FlagOn(const char* text) { return text == nullptr || text[0] == 0 || std::atoi(text) != 0; }

using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
struct Enabled {
  std::int32_t id;  // the proto ID the copy had: a reused pointer with another ID is ignored
  float value;      // 0 turns the share off
};
std::unordered_map<const char*, Enabled> g_enabled;  // by the player's copy

void ChangeEnabled(char* proto, const char*, float amount, std::uint8_t relativity, bool unapply) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 4);
  Enabled& slot = g_enabled.emplace(proto, Enabled{id, 1.0f}).first->second;
  if (slot.id != id) {
    slot = Enabled{id, 1.0f};
  }
  float& value = slot.value;
  const float before = value;
  kEffectValue(relativity, &value, 1.0f, amount, unapply);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"sharedBuildLimit: proto %d, tech subtype EnableSharedBuildLimit, relativity %u, amount %g%ls: %g -> %g",
             *reinterpret_cast<const std::int32_t*>(proto + 4), relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"",
             static_cast<double>(before), static_cast<double>(value));
  }
}

void ForgetOnDataLoad(char*) { g_enabled.clear(); }

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

Share& ShareOf(const char* proto) {
  const std::int32_t id = Field<std::int32_t>(proto, 4);
  if (id >= 0) {
    if (g_tagged.size() <= static_cast<std::size_t>(id)) {
      g_tagged.resize(static_cast<std::size_t>(id) + 1, false);
    }
    g_tagged[static_cast<std::size_t>(id)] = true;
  }
  return g_shares[id];
}

const char* TagText(const char* node) { return kXmlText(node + 0x14); }

bool __cdecl ReadLimitUnit(void*, const char* node, char* proto) {
  const char* text = TagText(node);
  if (text != nullptr) {
    ShareOf(proto).limitUnit = text;
  }
  return true;
}

bool __cdecl ReadUnitType(void*, const char* node, char* proto) {
  const char* text = TagText(node);
  if (text == nullptr) {
    return true;
  }
  std::int32_t weight = 1;
  const void* value = nullptr;
  if (kXmlAttribute(node, "weight", &value) && value != nullptr) {
    const char* digits = kXmlText(value);
    if (digits != nullptr && std::atoi(digits) > 0) {
      weight = std::atoi(digits);
    }
  }
  ShareOf(proto).listed.push_back({text, weight});
  return true;
}

bool __cdecl ReadTeam(void*, const char* node, char* proto) {
  const char* text = TagText(node);
  ShareOf(proto).team = text == nullptr || std::atoi(text) != 0;
  return true;
}

bool __cdecl ReadUse(void*, const char* node, char* proto) {
  ShareOf(proto).use = FlagOn(TagText(node));
  return true;
}

bool __cdecl ReadSettler(void*, const char* node, char* proto) {
  ShareOf(proto).settler = FlagOn(TagText(node));
  return true;
}

void ReadSettlerProtoName(const char* civ, std::int32_t civId, const wchar_t* text) {
  if (civId >= static_cast<std::int32_t>(g_settlerCivs.size())) {
    g_settlerCivs.resize(civId + 1);
  }
  std::string name;
  for (const wchar_t* c = text; c != nullptr && *c != 0; ++c) {
    name.push_back(static_cast<char>(*c));
  }
  g_settlerCivs[civId] = SettlerCiv{name};
  const char* civName = civ == nullptr ? nullptr : Field<const char*>(civ, 0x04);
  uhc::Log(L"sharedBuildLimit: civ %d (%hs): its settler is %hs (SettlerProtoName)", civId,
           civName == nullptr ? "?" : civName, name.c_str());
}

const char* Database() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

const char* World() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

// A proto or an abstract type by name, through the table <UnitType> reads; -1 if absent.
std::int32_t NameId(const char* database, const std::string& name) {
  const char* table = database + 0x190;
  std::int32_t id = -1;
  const std::int32_t bucket = kNameBucket(table, name.c_str());
  return kNameFind(table, name.c_str(), bucket, &id) ? id : -1;
}

// A player's civ ID (0x4539D3): [[player+20h]] when [player+24h] > 0, else -1.
std::int32_t CivIdOf(const char* player) {
  return Field<std::int32_t>(player, 0x24) > 0 ? *Field<const std::int32_t*>(player, 0x20) : -1;
}

// The <SettlerProtoName> proto of the player's civ, or -1.
std::int32_t SettlerProtoOf(const char* player, const char* database) {
  const std::int32_t civ = CivIdOf(player);
  if (civ < 0 || civ >= static_cast<std::int32_t>(g_settlerCivs.size()) || g_settlerCivs[civ].name.empty()) {
    return -1;
  }
  SettlerCiv& entry = g_settlerCivs[civ];
  const char* table = Field<const char*>(database, 0x54);
  if (entry.table != table) {
    entry.table = table;
    entry.proto = NameId(database, entry.name);
    if (entry.proto < 0 || entry.proto >= Field<std::int32_t>(database, 0x19B0)) {
      uhc::Log(L"sharedBuildLimit: civ %d: %hs is no proto (SettlerProtoName); its settler limit is each proto's own",
               civ, entry.name.c_str());
      entry.proto = -1;
    }
  }
  return entry.proto;
}

// Built at the first use: the protos are not all read while the tags load.
void Build(std::int32_t ownId, Share& share, const char* database) {
  share.built = true;
  if (!share.limitUnit.empty()) {
    share.limitProto = NameId(database, share.limitUnit);
    if (share.limitProto < 0 || share.limitProto >= Field<std::int32_t>(database, 0x19B0)) {
      uhc::Log(L"sharedBuildLimit: proto %d: %hs is no proto: it keeps its own limit", ownId, share.limitUnit.c_str());
      share.limitProto = -1;
    }
  }
  const std::int32_t protos = Field<std::int32_t>(database, 0x19B0);
  if (share.settler && g_settlerType >= 0) {
    for (std::int32_t id = 0; id < protos; ++id) {
      const char* proto = kProtoById(database, id);
      if (proto != nullptr && kProtoIsType(proto, g_settlerType)) {
        share.members.emplace_back(id, 1);
      }
    }
  }
  for (const Listed& entry : share.listed) {
    const std::int32_t type = NameId(database, entry.name);
    if (type < 0) {
      uhc::Log(L"sharedBuildLimit: proto %d: unknown unit type %hs", ownId, entry.name.c_str());
      continue;
    }
    for (std::int32_t id = 0; id < protos; ++id) {
      const char* proto = kProtoById(database, id);
      if (proto == nullptr || !kProtoIsType(proto, type)) {
        continue;
      }
      bool known = false;
      for (const auto& member : share.members) {
        known = known || member.first == id;
      }
      if (known) {
        continue;  // the first entry that reaches a proto sets its weight, for the others and for itself
      }
      share.members.emplace_back(id, entry.weight);
      if (id == ownId) {
        share.ownWeight = entry.weight;
      }
    }
  }
  if (g_log) {
    uhc::Log(L"sharedBuildLimit: proto %d: limit of %d, %u protos count, own weight %d%ls%ls%ls", ownId,
             share.limitProto, static_cast<unsigned>(share.members.size()), share.ownWeight,
             share.team ? L", the team's" : L"", share.settler ? L", the civ's settler limit" : L"",
             share.use ? L", UseSharedBuildLimit" : L"");
  }
}

bool IsTagged(std::int32_t id) {
  return id >= 0 && static_cast<std::size_t>(id) < g_tagged.size() && g_tagged[static_cast<std::size_t>(id)];
}

bool ReadyShare(std::int32_t id, Share** out) {
  const char* database = Database();
  if (!IsTagged(id) || database == nullptr) {
    return false;
  }
  Share& share = g_shares[id];
  if (!share.built) {
    Build(id, share, database);
  }
  *out = &share;
  return true;
}

// What the other units weigh for this player: its own other protos, and with TeamBuildLimit every
// unit of the team's other players (the test the shared resources use, 0x67995B).
std::int64_t Others(const char* player, std::int32_t ownId, const Share& share) {
  const char* world = World();
  if (world == nullptr) {
    return 0;
  }
  const std::int32_t self = Field<std::int32_t>(player, 0);
  const auto players = Field<const char* const*>(world, 0x58);
  const std::int32_t count = Field<std::int32_t>(world, 0x5C);
  std::int64_t sum = 0;
  for (std::int32_t i = 0; i < count && i < kMaxPlayers; ++i) {
    if (i != self) {
      const std::int32_t relation = Field<std::int32_t>(player, 0x1D4 + 4 * i);
      if (!share.team || i == 0 || (relation != 0 && relation != 1)) {
        continue;
      }
    }
    const char* other = players[i];
    if (other == nullptr) {
      continue;
    }
    for (const auto& member : share.members) {
      if (i == self && member.first == ownId) {
        continue;  // the stock compare adds these
      }
      const char* proto = kPlayerProto(other, member.first);
      if (proto != nullptr) {
        sum += static_cast<std::int64_t>(kCount(proto, i, true, true)) * member.second;
      }
    }
  }
  return sum;
}

// Replaces the count calls of the tooltips: the group's total, in the proto's own weight.
std::int32_t __fastcall TooltipCount(const char* proto, void*, std::int32_t playerId, bool first, bool second) {
  const std::int32_t own = kCount(proto, playerId, first, second);
  Share* share = nullptr;
  const char* world = World();
  if (proto == nullptr || world == nullptr || !ReadyShare(Field<std::int32_t>(proto, 4), &share)) {
    return own;
  }
  const char* player = Field<const char* const*>(world, 0x58)[playerId];
  return own + static_cast<std::int32_t>(Others(player, Field<std::int32_t>(proto, 4), *share) / share->ownWeight);
}

bool FromTooltip(std::uint32_t returnAddress) {
  for (const std::uint32_t address : kTooltipLimits) {
    if (address == returnAddress) {
      return true;
    }
  }
  return false;
}

}  // namespace

// From the hook at the entry of the limit.
extern "C" std::int32_t __stdcall UhcSharedLimit(const char* player, const char* proto, std::uint32_t returnAddress) {
  const auto stockLimit = reinterpret_cast<LimitFn>(&UhcSharedLimitStock);
  const std::int32_t stock = stockLimit(player, proto);
  if (proto == nullptr) {
    return stock;
  }
  const std::int32_t id = Field<std::int32_t>(proto, 4);
  Share* found = nullptr;
  if (!ReadyShare(id, &found)) {
    return stock;
  }
  if (!g_enabled.empty()) {
    const auto enabled = g_enabled.find(proto);
    if (enabled != g_enabled.end() && enabled->second.id == id && enabled->second.value == 0.0f) {
      return stock;  // a tech turned the share off for this player
    }
  }
  Share& share = *found;
  std::int32_t limit = stock;
  std::int32_t limitId = share.limitProto;
  if (share.settler) {
    const char* database = Database();
    const std::int32_t settler = database == nullptr ? -1 : SettlerProtoOf(player, database);
    if (settler >= 0) {
      limitId = settler;
    }
  }
  if (limitId >= 0) {
    const char* limitProto = kPlayerProto(player, limitId);
    if (limitProto != nullptr) {
      limit = stockLimit(player, limitProto);
    }
  }
  if (limit < 0) {
    return stock;  // no limit to share
  }
  if (FromTooltip(returnAddress)) {
    return limit / share.ownWeight;
  }
  const std::int64_t room = (static_cast<std::int64_t>(limit) - Others(player, id, share)) / share.ownWeight;
  const std::int32_t result = room < 0 ? 0 : static_cast<std::int32_t>(room);
  if (g_log && result != share.lastLogged && g_logLines < kMaxLogLines) {
    ++g_logLines;
    share.lastLogged = result;
    uhc::Log(L"sharedBuildLimit: player %d, proto %d: room %d of %d (stock %d)", Field<std::int32_t>(player, 0), id, result,
             limit, stock);
  }
  return result;
}

namespace uhc {

Outcome ApplySharedBuildLimit(const Config& config) {
  const Config::Args* args = config.First("sharedBuildLimit");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"sharedBuildLimit: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("sharedBuildLimit", {&sites::kBuildLimitEntry, &sites::kBuildCountEntry, &sites::kPlayerProtoEntry,
                                      &sites::kBuildCountTooltip1, &sites::kBuildCountTooltip2, &sites::kProtoById, &sites::kXmlAttribute, &sites::kXmlText}) ||
      !AddProtoTagHandler("SharedBuildLimitUnit", &ReadLimitUnit) ||
      !AddProtoTagHandler("SharedBuildLimitUnitType", &ReadUnitType) ||
      !AddProtoTagHandler("TeamBuildLimit", &ReadTeam) ||
      !AddProtoTagHandler("UseSharedBuildLimit", &ReadUse) ||
      !AddProtoTagHandler("SharedBuildLimitUnitTypes", &ReadUnitType) ||
      !AddProtoTagHandler("SettlerBuildLimit", &ReadSettler) ||
      !AddCivTagHandler("SettlerProtoName", &ReadSettlerProtoName) ||
      !AddTechSubtype("EnableSharedBuildLimit", &ChangeEnabled) || !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !RequestAbstractUnitType("LogicalTypeSettlerBuildLimit", &g_settlerType) ||
      !WriteJmp(kLimitEntry, reinterpret_cast<const void*>(&UhcSharedLimitHook), 5)) {
    return Outcome::kFailed;
  }
  for (const std::uint32_t call : kTooltipCounts) {
    if (!WriteCall(call, reinterpret_cast<const void*>(&TooltipCount))) {
      return Outcome::kFailed;
    }
  }
  Log(L"sharedBuildLimit: the proto tags are on, the civ tag SettlerProtoName and the Data subtype "
      L"EnableSharedBuildLimit");
  return Outcome::kApplied;
}

}  // namespace uhc
