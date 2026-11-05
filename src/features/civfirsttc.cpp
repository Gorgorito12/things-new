// civFirstTC [log]: a civ's <firstTC>Proto</firstTC> in civs.xml replaces the TownCenter that a
// random map places for its players, and that building is the player's first town center
// (FirstTC), the unit the placement rules read. A Nomad start (rmGetNomadStart()) keeps the
// map's units.
//
// Four hooks, all simulation-side:
// - civs.xml: the parser FUN_0052A590 skips a <civ> child tag it does not know at 0x52BB07; the
//   hook reads <firstTC> there (hooks/civfirsttc_hooks.asm). Stock ignores the tag.
// - Map placement: every rmPlaceObjectDef* reaches objectDef::place FUN_00925936 through one call,
//   0x925F4C. The wrapper below gives the def's TownCenter items the player's <firstTC> proto (and
//   its footprint, when larger) for that call only, so the same def still places a TownCenter for
//   the next player. The Special_StartingUnits def (rmCreateStartingUnitsObjectDef) is left alone:
//   place() rebuilds its items from the civ's <startingunit> list.
// - FirstTC: Player::addUnit takes only a TownCenter as FirstTC (0x506B3B); the hook shared with
//   startingTC (hooks/startingtc_hooks.asm) also takes the civ's <firstTC> proto, outside a Nomad
//   start, so a reloaded scenario or save finds the same FirstTC.
// - Town starting units: FUN_0049039A gives the civ's <townstartingunit> units (settlers, crates)
//   to the first built TownCenter, through FUN_007C238E, which spawns them only at a colony that
//   starts at that unit (placementrules\colonies.xml <starttypes>), then clears the request. The
//   hook queries the <firstTC> proto instead when the player's FirstTC is such a building with a
//   colony; otherwise the stock wait for a TownCenter stays, and no unit is lost.
#include <windows.h>

#include <cstdint>
#include <cstring>
#include <cwchar>
#include <set>
#include <string>
#include <tuple>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

#include "../civtags.h"

namespace uhc {
bool FirstTcProtoHookInstalled();  // features/startingtc.cpp
bool InstallFirstTcProtoHook();
}  // namespace uhc

extern "C" void __stdcall UhcTraceHook(const char* hookName);

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database, +92Ch RM

using CivByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
using ProtoByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using ProtoByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
using ProtoFlagFn = bool(__thiscall*)(const char* proto, std::int32_t flag);
using IsAliveFn = bool(__thiscall*)(const char* unit);
using PlaceFn = std::int32_t(__fastcall*)(char* def, void* unused, std::int32_t player, std::uint32_t x,
                                         std::uint32_t z, std::uint32_t count);

const auto kCivById = reinterpret_cast<CivByIdFn>(0x00405C2E);
const auto kProtoByName = reinterpret_cast<ProtoByNameFn>(0x005A2346);
const auto kProtoById = reinterpret_cast<ProtoByIdFn>(0x0045316E);
const auto kProtoFlag = reinterpret_cast<ProtoFlagFn>(0x0045EE02);
const auto kPlace = reinterpret_cast<PlaceFn>(0x00925936);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* GameField(std::uint32_t offset) {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, offset);
}

// rmGetNomadStart (0x90B683): byte [RM+1A95h], false when there is no RM.
bool NomadStart() {
  const char* rm = GameField(0x92C);
  return rm != nullptr && Field<std::uint8_t>(rm, 0x1A95) != 0;
}

// Players: [world+58h] array, [world+5Ch] count (0x44CB21).
const char* PlayerById(const char* world, std::int32_t id) {
  if (id < 0 || id >= Field<std::int32_t>(world, 0x5C)) {
    return nullptr;
  }
  return Field<const char* const*>(world, 0x58)[id];
}

// Units by ID: [world+0Ch] array, [world+10h] count; the low 18 bits index it and [unit+10h] must
// equal the full ID (0x44CC6D).
const char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<IsAliveFn const* const*>(unit))[0xA4 / 4](unit); }

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* UnitName(const char* unit) { return ProtoName(Field<const char*>(unit, 0x5C)); }

std::int32_t UnitProto(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  return proto == nullptr ? -1 : Field<std::int32_t>(proto, 0x04);
}

const char* CivName(const char* civ) {
  const char* name = civ == nullptr ? nullptr : Field<const char*>(civ, 0x04);
  return name == nullptr ? "?" : name;
}

// A player's civ ID (0x4539D3): [[player+20h]] when [player+24h] > 0, else -1.
std::int32_t CivIdOf(const char* player) {
  return Field<std::int32_t>(player, 0x24) > 0 ? *Field<const std::int32_t*>(player, 0x20) : -1;
}

struct CivTag {
  const char* civ = nullptr;  // the civ object it was read for; a new parse makes new ones
  std::string name;           // the text of <firstTC>
  const char* table = nullptr;  // the database's proto array [db+54h] when proto was resolved
  std::int32_t proto = -1;
};

std::vector<CivTag> g_tags;  // by civ ID
bool g_log = false;

// Log lines that a state repeats every update are written once per game.
std::set<std::tuple<int, std::int32_t, std::int32_t>> g_logged;  // kind, player, unit or civ
const char* g_logWorld = nullptr;
std::uint32_t g_logStep = 0;

bool FirstTime(int kind, std::int32_t player, std::int32_t what) {
  const char* world = GameField(0x13C);
  const std::uint32_t step = world == nullptr ? 0 : Field<std::uint32_t>(world, 0xF8);
  if (world != g_logWorld || step < g_logStep) {
    g_logged.clear();
  }
  g_logWorld = world;
  g_logStep = step;
  return g_logged.emplace(kind, player, what).second;
}

std::string Narrow(const wchar_t* text) {
  std::string out;
  for (; *text != L'\0'; ++text) {
    out += *text < 0x80 ? static_cast<char>(*text) : '?';
  }
  const auto first = out.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) {
    return {};
  }
  return out.substr(first, out.find_last_not_of(" \t\r\n") - first + 1);
}

// The <firstTC> proto ID of the player's civ, or -1. Resolved by name on first use and again when
// the database's proto array changes; an unknown name is logged once and gives -1.
std::int32_t CivFirstTcProto(const char* player) {
  const char* db = GameField(0x140);
  const std::int32_t civId = CivIdOf(player);
  if (db == nullptr || civId < 0 || civId >= static_cast<std::int32_t>(g_tags.size())) {
    return -1;
  }
  CivTag& tag = g_tags[civId];
  if (tag.name.empty() || kCivById(db, civId) != tag.civ) {
    return -1;
  }
  const char* table = Field<const char*>(db, 0x54);
  if (tag.table != table) {
    tag.table = table;
    tag.proto = kProtoByName(db, tag.name.c_str());
    if (tag.proto < 0) {
      uhc::Log(L"civFirstTC: civ %d (%hs): <firstTC> names no proto unit (%hs); its players keep TownCenter", civId,
               CivName(tag.civ), tag.name.c_str());
    }
  }
  return tag.proto;
}

// Item footprint (+0Ch, +10h) as objectDef::addItem computes it (0x924B1D).
void Footprint(const char* db, const char* world, std::int32_t protoId, std::int32_t* x, std::int32_t* z) {
  *x = 0;
  *z = 0;
  const char* proto = kProtoById(db, protoId);
  const char* terrain = Field<const char*>(world, 0x88);
  if (proto == nullptr || terrain == nullptr || !kProtoFlag(proto, 2)) {
    return;
  }
  const float scale = Field<float>(terrain, 0x1C);
  *x = static_cast<std::int32_t>(Field<float>(proto, 0x88) * scale * 2.0f + 0.5f);
  *z = static_cast<std::int32_t>(Field<float>(proto, 0x8C) * scale * 2.0f + 0.5f);
}

struct Item {
  std::int32_t proto;
  std::int32_t count;
  std::int32_t cluster;
  std::int32_t footprintX;
  std::int32_t footprintZ;
};
static_assert(sizeof(Item) == 20);

struct Saved {
  std::int32_t index;
  Item item;
};

}  // namespace

extern "C" {
std::int32_t g_uhcCivFirstTcOn = 0;  // 1 with civFirstTC; read by the shared FirstTC proto hook

// From the civ tags registry (civtags.cpp), for a <firstTC> child of a <civ>.
void ReadFirstTc(const char* civ, std::int32_t civId, const wchar_t* text) {
  const std::string name = text == nullptr ? std::string() : Narrow(text);
  if (civId >= static_cast<std::int32_t>(g_tags.size())) {
    g_tags.resize(civId + 1);
  }
  g_tags[civId] = CivTag{civ, name};
  if (name.empty()) {
    uhc::Log(L"civFirstTC: civ %d (%hs): empty <firstTC>; its players keep TownCenter", civId, CivName(civ));
  } else {
    uhc::Log(L"civFirstTC: civ %d (%hs) starts with %hs instead of TownCenter", civId, CivName(civ), name.c_str());
  }
}

// From the shared FirstTC proto hook, for a unit added to a player with no FirstTC: true if its
// proto is the <firstTC> proto of the player's civ, outside a Nomad start.
bool __stdcall UhcCivFirstTcMatches(const char* player, std::int32_t protoId, const char* unit) {
  if (g_tags.empty() || CivFirstTcProto(player) != protoId || protoId < 0 || NomadStart()) {
    return false;
  }
  if (g_log) {
    uhc::Log(L"civFirstTC: unit %d (%hs) is player %d's first town center (FirstTC)", Field<std::int32_t>(unit, 0x10),
             UnitName(unit), Field<std::int32_t>(player, 0x00));
  }
  return true;
}

// From the town starting units hook (EDI = player): the proto to query instead of TownCenter, or
// -1. Only when the player's FirstTC is alive, of the civ's <firstTC> proto, its own, and a colony
// starts at it, the same test as FUN_007C238E (0x7C2407).
std::int32_t __stdcall UhcCivFirstTcTownProto(const char* player) {
  if (g_tags.empty()) {
    return -1;
  }
  const std::int32_t proto = CivFirstTcProto(player);
  const char* world = GameField(0x13C);
  if (proto < 0 || world == nullptr) {
    return -1;
  }
  const std::int32_t playerId = Field<std::int32_t>(player, 0x00);
  const std::int32_t id = Field<std::int32_t>(player, 0x4F0);
  const char* unit = UnitById(world, id);
  if (unit == nullptr || UnitProto(unit) != proto || Field<const char*>(unit, 0x44) != player || !IsAlive(unit)) {
    return -1;
  }
  const char* colonies = Field<const char*>(player, 0x3E0);
  bool found = false;
  if (colonies != nullptr && (Field<std::uint8_t>(colonies, 0x00) & 1) == 0) {
    const std::int32_t* indices = Field<const std::int32_t*>(colonies, 0x14);
    const char* const* list = Field<const char* const*>(colonies, 0x08);
    for (std::int32_t k = 0; k < Field<std::int32_t>(colonies, 0x18) && !found; ++k) {
      const char* colony = list[indices[k]];
      found = colony != nullptr && Field<std::int32_t>(colony, 0x28) == id;
    }
  }
  if (!found) {
    if (FirstTime(0, playerId, id)) {
      uhc::Log(L"civFirstTC: no colony starts at player %d's first town center %d (%hs): its town starting units "
               L"wait for a TownCenter (add the proto to placementrules\\colonies.xml <starttypes>)",
               playerId, id, UnitName(unit));
    }
    return -1;
  }
  if (g_log && FirstTime(1, playerId, id)) {
    uhc::Log(L"civFirstTC: player %d's town starting units go to its first town center %d (%hs)", playerId, id,
             UnitName(unit));
  }
  return proto;
}

// Replaces the call of objectDef::place at 0x925F4C (thiscall(def, player, x, z, count), ret 10h;
// x and z are floats, passed through as they are).
std::int32_t __fastcall UhcRmPlaceObjectDef(char* def, void*, std::int32_t player, std::uint32_t x, std::uint32_t z,
                                            std::uint32_t count) {
  static bool traced = false;
  if (!traced) {
    traced = true;
    UhcTraceHook("civFirstTC map placement (0x925F4C)");
  }
  const char* world = GameField(0x13C);
  const char* db = GameField(0x140);
  const std::int32_t items = def == nullptr ? 0 : Field<std::int32_t>(def, 0x0C);
  if (g_tags.empty() || world == nullptr || db == nullptr || items <= 0 || Field<std::uint8_t>(def, 0x55) != 0) {
    return kPlace(def, nullptr, player, x, z, count);
  }
  const std::int32_t townCenter = Field<std::int32_t>(db, 0x5E08);
  Item* list = Field<Item*>(def, 0x08);
  bool hasTownCenter = false;
  for (std::int32_t i = 0; i < items && !hasTownCenter; ++i) {
    hasTownCenter = list[i].proto == townCenter;
  }
  const char* owner = hasTownCenter ? PlayerById(world, player) : nullptr;
  const std::int32_t proto = owner == nullptr ? -1 : CivFirstTcProto(owner);
  if (proto < 0 || proto == townCenter) {
    return kPlace(def, nullptr, player, x, z, count);
  }
  const char* defName = Field<const char*>(def, 0x04);
  if (NomadStart()) {
    if (g_log) {
      uhc::Log(L"civFirstTC: player %d keeps TownCenter in object def %d '%hs' (Nomad start)", player,
               Field<std::int32_t>(def, 0x00), defName == nullptr ? "" : defName);
    }
    return kPlace(def, nullptr, player, x, z, count);
  }
  std::int32_t footprintX = 0;
  std::int32_t footprintZ = 0;
  Footprint(db, world, proto, &footprintX, &footprintZ);
  std::vector<Saved> saved;
  for (std::int32_t i = 0; i < items; ++i) {
    if (list[i].proto == townCenter) {
      saved.push_back({i, list[i]});
      list[i].proto = proto;
      list[i].footprintX = list[i].footprintX > footprintX ? list[i].footprintX : footprintX;
      list[i].footprintZ = list[i].footprintZ > footprintZ ? list[i].footprintZ : footprintZ;
    }
  }
  if (g_log) {
    uhc::Log(L"civFirstTC: player %d gets %hs instead of TownCenter in object def %d '%hs'", player,
             ProtoName(kProtoById(db, proto)), Field<std::int32_t>(def, 0x00), defName == nullptr ? "" : defName);
  }
  const std::int32_t placed = kPlace(def, nullptr, player, x, z, count);
  // Put the def back for the next player; place() does not add or remove items of such a def.
  list = Field<Item*>(def, 0x08);
  const std::int32_t after = Field<std::int32_t>(def, 0x0C);
  for (const Saved& entry : saved) {
    if (entry.index < after && list[entry.index].proto == proto) {
      list[entry.index] = entry.item;
    }
  }
  return placed;
}

void UhcCivFirstTcTownHook();
}

namespace uhc {

Outcome ApplyCivFirstTc(const Config& config) {
  const Config::Args* args = config.First("civFirstTC");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"civFirstTC: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  // startingTC, applied first, may already have written 0x506B3B: its bytes are then ours.
  const Site* protoCheck = FirstTcProtoHookInstalled() ? &sites::kFirstTcChunk : &sites::kFirstTcProtoCheck;
  if (!VerifyAll("civFirstTC",
                 {&sites::kCivById, &sites::kCivOfPlayer,
                  &sites::kProtoByName, &sites::kProtoById, &sites::kProtoFlag, &sites::kRmPlaceCall,
                  &sites::kRmPlace, &sites::kRmItemFootprint, &sites::kRmNomadStart, &sites::kTownStartQuery,
                  &sites::kTownStartSpawn, &sites::kTownStartColonyLoop, &sites::kFirstTcChunk, protoCheck,
                  &sites::kFirstTcSet, &sites::kPlayerById, &sites::kUnitById, &sites::kUnitAliveSlot})) {
    return Outcome::kFailed;
  }
  g_log = log;
  g_uhcCivFirstTcOn = 1;
  if (!InstallFirstTcProtoHook()) {
    g_uhcCivFirstTcOn = 0;
    return Outcome::kFailed;
  }
  // The civs.xml hook (civtags.cpp) runs after UHCMain, so every tag is seen.
  if (!AddCivTagHandler("firstTC", &ReadFirstTc)) {
    return Outcome::kFailed;
  }
  if (!WriteCall(0x00925F4C, reinterpret_cast<const void*>(&UhcRmPlaceObjectDef))) {
    return Outcome::kFailed;
  }
  // Replaces mov ebx,[ecx+5E08h] at 0x679AC8; the hook re-executes it.
  if (!WriteJmp(0x00679AC8, reinterpret_cast<const void*>(&UhcCivFirstTcTownHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"civFirstTC: a civ's <firstTC> proto in civs.xml replaces the TownCenter random maps place for its players "
      L"(not in a Nomad start) and is their first town center (FirstTC)%ls (multiplayer unverified)",
      log ? L", every substitution logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
