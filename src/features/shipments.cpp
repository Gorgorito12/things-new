// hcShipmentPointFallback <Proto|FirstTC> [...]: when the home city gather unit is gone and none of
// the 10 stock fallback types is left (TownCenter, then Outpost, FortFrontier, WarHut, Blockhouse,
// NoblesHut, AbstractAgraFort, AbstractDaimyo, ypCastle, ypVillage), try the entries listed in
// uhc.cfg, in order. An entry is a proto unit name, or the keyword FirstTC: the player's first town
// center, the unit ID at [player+4F0h] that the placement rules call FirstTC. Stock makes only a
// TownCenter FirstTC, which the stock list already tries first, so FirstTC is useful with
// startingTC (a marked building can be FirstTC). The hook is in hooks/shipment_hooks.asm.
#include <windows.h>

#include <cstdint>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr int kMaxFallbackTypes = 64;
// The entry of the keyword FirstTC; -1 is an unknown proto, >= 0 a proto ID.
constexpr std::int32_t kFirstTcEntry = -2;
constexpr char kFirstTcKeyword[] = "FirstTC";

// Engine layout (docs/engine-symbols.md, "Home city gather point").
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint32_t kHcPlayer = 0x08;          // home city: its player; [player+0] the player ID
constexpr std::uint32_t kPlayerFirstTc = 0x4F0;    // unit ID of the player's first town center; -1 none
constexpr std::uint32_t kUnitId = 0x10;
constexpr std::uint32_t kUnitOwner = 0x44;  // the owning Player*
constexpr std::uint32_t kUnitProto = 0x5C;  // proto; [proto+10h] its name
constexpr int kMaxLoggedPlayers = 32;

using PlayerByIdFn = const char*(__thiscall*)(char* world, std::int32_t id);
using UnitByIdFn = const char*(__thiscall*)(char* world, std::int32_t id);
using GatherPointValidFn = bool(__thiscall*)(const char* hc, const char* unit);

const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
// The check stock applies to the stored point and to every candidate: not null, alive (unit vtable
// slot A4h), 0x44DDB4 true, 0x4802C6 not 1.
const auto kGatherPointValid = reinterpret_cast<GatherPointValidFn>(0x0085302C);

// Proto names from uhc.cfg; resolved to IDs only once the game database exists.
std::vector<std::string> g_typeNames;

// Log only: the FirstTC unit last logged per player ID, and the world it was logged in. The game
// never reads them, so they cannot make two machines disagree.
const char* g_loggedWorld = nullptr;
std::int32_t g_loggedFirstTc[kMaxLoggedPlayers];

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

char* World() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<char*>(game, 0x13C);
}

const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, kUnitProto);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

bool IsFirstTcKeyword(const std::string& name) { return _stricmp(name.c_str(), kFirstTcKeyword) == 0; }

void LogFirstTcPick(const char* world, std::int32_t playerId, const char* unit) {
  if (playerId < 0 || playerId >= kMaxLoggedPlayers) {
    return;
  }
  if (world != g_loggedWorld) {
    g_loggedWorld = world;
    for (std::int32_t& id : g_loggedFirstTc) {
      id = -1;
    }
  }
  const std::int32_t id = Field<std::int32_t>(unit, kUnitId);
  if (g_loggedFirstTc[playerId] == id) {
    return;
  }
  g_loggedFirstTc[playerId] = id;
  uhc::Log(L"hcShipmentPointFallback: player %d's shipment point -> unit %d (%hs), its first town center (FirstTC)",
           playerId, id, ProtoName(unit));
}

}  // namespace

extern "C" {
std::int32_t g_uhcGatherFallbackTypes[kMaxFallbackTypes];
std::int32_t g_uhcGatherFallbackCount = 0;

void UhcHcGatherFallbackHook();

// Called once from the hook, inside the simulation, when the database is loaded.
void __stdcall UhcResolveGatherFallbackTypes() {
  using ProtoIdByName = int(__thiscall*)(void* database, const char* name);
  const auto protoIdByName = reinterpret_cast<ProtoIdByName>(0x005A2346);
  void* game = *reinterpret_cast<void**>(kGameGlobal);
  void* database = game == nullptr ? nullptr : *reinterpret_cast<void**>(static_cast<char*>(game) + 0x140);
  for (int i = 0; i < g_uhcGatherFallbackCount; ++i) {
    // The keyword comes first: the hook must never run a unit query for it.
    if (IsFirstTcKeyword(g_typeNames[i])) {
      g_uhcGatherFallbackTypes[i] = kFirstTcEntry;
      uhc::Log(L"hcShipmentPointFallback: FirstTC -> each player's first town center (FirstTC)");
      continue;
    }
    const int id = database == nullptr ? -1 : protoIdByName(database, g_typeNames[i].c_str());
    g_uhcGatherFallbackTypes[i] = id;
    uhc::Log(L"hcShipmentPointFallback: %hs -> proto %d%ls", g_typeNames[i].c_str(), id,
             id < 0 ? L" (unknown proto; skipped)" : L"");
  }
}

// Called from the hook for a FirstTC entry, [esp+10h] of FUN_004C6B9E = the home city. Returns the
// player's first town center if it still belongs to that player and passes the stock gather point
// check 0x85302C, else null. It writes no game state: the store=0 callers (the UI among them) may
// run it every frame, and the store=1 path stores the result in stock code (0x4C6CB2).
const char* __stdcall UhcGatherFirstTcUnit(const char* hc) {
  char* world = World();
  if (world == nullptr || hc == nullptr) {
    return nullptr;
  }
  const char* hcPlayer = Field<const char*>(hc, kHcPlayer);
  if (hcPlayer == nullptr) {
    return nullptr;
  }
  const std::int32_t playerId = Field<std::int32_t>(hcPlayer, 0x00);
  const char* player = kPlayerById(world, playerId);
  if (player == nullptr) {
    return nullptr;
  }
  const std::int32_t id = Field<std::int32_t>(player, kPlayerFirstTc);
  if (id < 0) {
    return nullptr;
  }
  const char* unit = kUnitById(world, id);
  if (unit == nullptr) {
    return nullptr;
  }
  // FirstTC is never cleared: a converted or captured one belongs to someone else now.
  const char* owner = Field<const char*>(unit, kUnitOwner);
  if (owner == nullptr || Field<std::int32_t>(owner, 0x00) != playerId) {
    return nullptr;
  }
  if (!kGatherPointValid(hc, unit)) {
    return nullptr;
  }
  LogFirstTcPick(world, playerId, unit);
  return unit;
}
}

namespace uhc {

// FUN_004C6B9E returns the unit shipments arrive at. When the stored one is gone it searches a
// fixed list of 10 unit types; this extends that list. Choice order is the cfg order, then the
// stock unit-query order, so every machine with the same cfg picks the same building.
Outcome ApplyHcShipmentPointFallback(const Config& config) {
  const Config::Args* names = config.First("hcShipmentPointFallback");
  if (names == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (names->empty() || names->size() > kMaxFallbackTypes) {
    Log(L"hcShipmentPointFallback: expected 1 to %d proto unit names or FirstTC", kMaxFallbackTypes);
    return Outcome::kFailed;
  }
  bool firstTc = false;
  for (const std::string& name : *names) {
    firstTc = firstTc || IsFirstTcKeyword(name);
  }
  // FirstTC also reads [player+4F0h] (set at 0x67ABD4), player and unit by ID and the stored point
  // check; no feature writes those sites.
  const bool verified =
      firstTc ? VerifyAll("hcShipmentPointFallback",
                          {&sites::kGatherFallbackExit, &sites::kGatherFallbackStore, &sites::kGatherFallbackBlock,
                           &sites::kFirstTcSet, &sites::kPlayerById, &sites::kPlayerByIdNull, &sites::kUnitById,
                           &sites::kUnitByIdNull, &sites::kGatherPointValid})
              : VerifyAll("hcShipmentPointFallback",
                          {&sites::kGatherFallbackExit, &sites::kGatherFallbackStore, &sites::kGatherFallbackBlock});
  if (!verified) {
    return Outcome::kFailed;
  }
  if (firstTc && config.First("startingTC") == nullptr && config.First("civFirstTC") == nullptr) {
    Log(L"hcShipmentPointFallback: FirstTC without startingTC: a first town center can only be a TownCenter, which "
        L"the stock list already tries first");
  }
  g_typeNames = *names;
  for (int& id : g_uhcGatherFallbackTypes) {
    id = -1;
  }
  g_uhcGatherFallbackCount = static_cast<std::int32_t>(g_typeNames.size());
  if (!WriteJmp(sites::kGatherFallbackExit.va, reinterpret_cast<const void*>(&UhcHcGatherFallbackHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"hcShipmentPointFallback: %d extra types after the stock list%ls (multiplayer unverified)",
      g_uhcGatherFallbackCount, firstTc ? L", including each player's first town center (FirstTC)" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
