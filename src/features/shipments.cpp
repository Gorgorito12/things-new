// hcShipmentPointFallback <Proto|FirstTC> [...]: when the home city gather unit is gone and none of
// the 10 stock fallback types is left (TownCenter, then Outpost, FortFrontier, WarHut, Blockhouse,
// NoblesHut, AbstractAgraFort, AbstractDaimyo, ypCastle, ypVillage), try the entries listed in
// uhc.cfg, in order. An entry is a proto unit name, or the keyword FirstTC: the player's first town
// center, the unit ID at [player+4F0h] that the placement rules call FirstTC. Stock makes only a
// TownCenter FirstTC, which the stock list already tries first, so FirstTC is useful with
// startingTC (a marked building can be FirstTC). The keyword LastResort, best listed last, takes any
// building of the player, else a hero (the Explorer), so that a shipment always has somewhere to go.
// The keyword replace makes the list run instead of the ten stock types, not after them; warn tells the
// local player, through the chat, when a card is queued and there is no point at all; warn=<text> sets its text.
// The hook is in hooks/shipment_hooks.asm.
#include <windows.h>

#include <cstdint>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr int kMaxFallbackTypes = 64;
// The entry of the keyword FirstTC; -1 is an unknown proto, >= 0 a proto ID.
constexpr std::int32_t kFirstTcEntry = -2;
constexpr char kFirstTcKeyword[] = "FirstTC";
constexpr std::int32_t kLastResortEntry = -3;
constexpr char kLastResortKeyword[] = "LastResort";
constexpr char kReplaceKeyword[] = "replace";
constexpr char kWarnKeyword[] = "warn";
constexpr char kWarnPrefix[] = "warn=";
constexpr std::uint32_t kLocalPlayer = 0x3C0;       // game: the local player's ID
constexpr std::uint32_t kHcQueueCount = 0x28C;      // home city: cards in the shipment queue
constexpr std::uint32_t kChatSlot = 0x5C;           // game's vtable: cdecl(game, from, to, format, text), as trChatSend
constexpr std::uint32_t kChatFormat = 0x00BE2DD0;   // the stock L"%s"
constexpr DWORD kWarnEveryMs = 30000;

// Engine layout (docs/engine-symbols.md, "Home city gather point").
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint32_t kHcPlayer = 0x08;          // home city: its player; [player+0] the player ID
constexpr std::uint32_t kPlayerFirstTc = 0x4F0;    // unit ID of the player's first town center; -1 none
constexpr std::uint32_t kPlayerUnits = 0xF8;       // the IDs of the player's units; +4 their count
constexpr std::uint32_t kUnitId = 0x10;
constexpr std::uint32_t kUnitOwner = 0x44;  // the owning Player*
constexpr std::uint32_t kUnitProto = 0x5C;  // proto; [proto+10h] its name
constexpr int kMaxLoggedPlayers = 32;

using PlayerByIdFn = const char*(__thiscall*)(char* world, std::int32_t id);
using UnitByIdFn = const char*(__thiscall*)(char* world, std::int32_t id);
using GatherPointValidFn = bool(__thiscall*)(const char* hc, const char* unit);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);

const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
// The check stock applies to the stored point and to every candidate: not null, alive (unit vtable
// slot A4h), 0x44DDB4 true, 0x4802C6 not 1.
const auto kGatherPointValid = reinterpret_cast<GatherPointValidFn>(0x0085302C);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

bool g_installed = false;
bool g_warn = false;
std::wstring g_warnText = L"No shipment point: cards on their way are refunded.";
DWORD g_lastWarn = 0;

// Proto names from uhc.cfg; resolved to IDs only once the game database exists.
std::vector<std::string> g_typeNames;

// Log only: the FirstTC unit last logged per player ID, and the world it was logged in. The game
// never reads them, so they cannot make two machines disagree.
const char* g_loggedWorld = nullptr;
std::int32_t g_loggedFirstTc[kMaxLoggedPlayers];
std::int32_t g_loggedLastResort[kMaxLoggedPlayers];

std::int32_t g_buildingType = -1;
std::int32_t g_heroType = -1;

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
bool IsLastResortKeyword(const std::string& name) { return _stricmp(name.c_str(), kLastResortKeyword) == 0; }

void LogFirstTcPick(const char* world, std::int32_t playerId, const char* unit) {
  if (playerId < 0 || playerId >= kMaxLoggedPlayers) {
    return;
  }
  if (world != g_loggedWorld) {
    g_loggedWorld = world;
    for (std::int32_t& id : g_loggedFirstTc) {
      id = -1;
    }
    for (std::int32_t& id : g_loggedLastResort) {
      id = -2;
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

// The same for LastResort, with -1 for nothing left. Log only.
void LogLastResort(const char* world, std::int32_t playerId, const char* unit) {
  if (playerId < 0 || playerId >= kMaxLoggedPlayers) {
    return;
  }
  if (world != g_loggedWorld) {
    g_loggedWorld = world;
    for (std::int32_t& id : g_loggedFirstTc) {
      id = -1;
    }
    for (std::int32_t& id : g_loggedLastResort) {
      id = -2;
    }
  }
  const std::int32_t id = unit == nullptr ? -1 : Field<std::int32_t>(unit, kUnitId);
  if (g_loggedLastResort[playerId] == id) {
    return;
  }
  g_loggedLastResort[playerId] = id;
  if (unit == nullptr) {
    uhc::Log(L"hcShipmentPointFallback: player %d has no building and no hero: shipments have no point", playerId);
  } else {
    uhc::Log(L"hcShipmentPointFallback: player %d's shipment point -> unit %d (%hs), the last resort", playerId, id,
             ProtoName(unit));
  }
}

}  // namespace

extern "C" {
void UhcHcGatherReplaceHook();

// From the hook, at "nothing found". Interface only: the local player's message, on the real clock, so it
// reaches no game state.
void __stdcall UhcGatherNoPoint(const char* hc, std::uint32_t store) {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  // The search that stores a point (store 1) never comes with no point: the game cancels the queue first, after a
  // search with store 0. So the test is that a card is queued, [hc+28Ch].
  (void)store;
  if (!g_warn || game == nullptr || hc == nullptr || *reinterpret_cast<const std::int32_t*>(hc + kHcQueueCount) <= 0) {
    return;
  }
  const char* player = *reinterpret_cast<char* const*>(hc + kHcPlayer);
  if (player == nullptr ||
      *reinterpret_cast<const std::int32_t*>(player) != *reinterpret_cast<const std::int32_t*>(game + kLocalPlayer)) {
    return;
  }
  const DWORD now = GetTickCount();
  if (g_lastWarn != 0 && now - g_lastWarn < kWarnEveryMs) {
    return;
  }
  g_lastWarn = now;
  uhc::Log(L"hcShipmentPointFallback: player %d has no shipment point; warned",
           *reinterpret_cast<const std::int32_t*>(player));
  using ChatFn = void(__cdecl*)(const char* game, std::int32_t from, std::int32_t to, const void* format, const wchar_t* text);
  const auto vtable = *reinterpret_cast<const char* const*>(game);
  const auto chat = *reinterpret_cast<ChatFn const*>(vtable + kChatSlot);
  chat(game, 0, *reinterpret_cast<const std::int32_t*>(game + kLocalPlayer), reinterpret_cast<const void*>(kChatFormat),
       g_warnText.c_str());
}

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
    if (IsLastResortKeyword(g_typeNames[i])) {
      g_uhcGatherFallbackTypes[i] = kLastResortEntry;
      uhc::Log(L"hcShipmentPointFallback: LastResort -> any building of the player, then a hero");
      continue;
    }
    const int id = database == nullptr ? -1 : protoIdByName(database, g_typeNames[i].c_str());
    g_uhcGatherFallbackTypes[i] = id;
    uhc::Log(L"hcShipmentPointFallback: %hs -> proto %d%ls", g_typeNames[i].c_str(), id,
             id < 0 ? L" (unknown proto; skipped)" : L"");
  }
}

// Called from the hook for a LastResort entry. The first of the player's units, in the order of the player's
// list, that is a building and passes the stock check 0x85302C, else the first such hero, else null. The list is
// the simulation's, so every machine picks the same unit. It writes no game state, as a FirstTC entry; the walk
// runs only for a player with no point at all.
const char* __stdcall UhcGatherLastResortUnit(const char* hc) {
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
  const auto* ids = Field<const std::int32_t*>(player, kPlayerUnits);
  const std::int32_t count = Field<std::int32_t>(player, kPlayerUnits + 4);
  const char* hero = nullptr;
  for (std::int32_t i = 0; i < count; ++i) {
    const char* unit = kUnitById(world, ids[i]);
    const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, kUnitProto);
    if (proto == nullptr || !kGatherPointValid(hc, unit)) {
      continue;
    }
    if (kProtoIsType(proto, g_buildingType)) {
      LogLastResort(world, playerId, unit);
      return unit;
    }
    if (hero == nullptr && kProtoIsType(proto, g_heroType)) {
      hero = unit;
    }
  }
  LogLastResort(world, playerId, hero);
  return hero;
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
bool AddFirstTcShipmentPoint() {
  for (const std::string& name : g_typeNames) {
    if (IsFirstTcKeyword(name)) {
      return true;
    }
  }
  if (g_uhcGatherFallbackCount >= kMaxFallbackTypes) {
    Log(L"hcShipmentPointFallback: no room for FirstTC");
    return false;
  }
  if (!VerifyAll("firstTC shipment point",
                 {&sites::kFirstTcSet, &sites::kPlayerById, &sites::kPlayerByIdNull, &sites::kUnitById,
                  &sites::kUnitByIdNull, &sites::kGatherPointValid})) {
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("firstTC shipment point", {&sites::kGatherFallbackExit, &sites::kGatherFallbackStore,
                                              &sites::kGatherFallbackBlock}) ||
        !WriteJmp(sites::kGatherFallbackExit.va, reinterpret_cast<const void*>(&UhcHcGatherFallbackHook), 5)) {
      return false;
    }
    g_installed = true;
  }
  g_typeNames.insert(g_typeNames.begin(), kFirstTcKeyword);
  g_uhcGatherFallbackCount = static_cast<std::int32_t>(g_typeNames.size());
  return true;
}

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
  bool lastResort = false;
  bool replace = false;
  std::vector<std::string> entries;
  for (const std::string& name : *names) {
    if (_stricmp(name.c_str(), kReplaceKeyword) == 0) {
      replace = true;
    } else if (_stricmp(name.c_str(), kWarnKeyword) == 0) {
      g_warn = true;
    } else if (_strnicmp(name.c_str(), kWarnPrefix, sizeof(kWarnPrefix) - 1) == 0) {
      std::string text = name.substr(sizeof(kWarnPrefix) - 1);
      if (text.empty() || text.size() > 127) {
        Log(L"hcShipmentPointFallback: %hs: expected warn=<text>, at most 127 characters, '_' for a space; feature not "
            L"applied",
            name.c_str());
        return Outcome::kFailed;
      }
      for (char& ch : text) {
        ch = ch == '_' ? ' ' : ch;
      }
      g_warn = true;
      g_warnText.assign(text.begin(), text.end());
    } else {
      entries.push_back(name);
    }
    firstTc = firstTc || IsFirstTcKeyword(name);
    lastResort = lastResort || IsLastResortKeyword(name);
  }
  if (entries.empty() && (replace || !g_warn)) {
    Log(L"hcShipmentPointFallback: expected a proto unit name, FirstTC or LastResort; feature not applied");
    return Outcome::kFailed;
  }
  if (replace && !VerifyAll("hcShipmentPointFallback replace", {&sites::kGatherSearchStart})) {
    return Outcome::kFailed;
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
  if (!verified || (lastResort && !VerifyAll("hcShipmentPointFallback LastResort",
                                             {&sites::kPlayerById, &sites::kPlayerByIdNull, &sites::kUnitById,
                                              &sites::kUnitByIdNull, &sites::kGatherPointValid, &sites::kIsA}))) {
    return Outcome::kFailed;
  }
  if (lastResort && (!RequestAbstractUnitType("Building", &g_buildingType) ||
                     !RequestAbstractUnitType("Hero", &g_heroType))) {
    return Outcome::kFailed;
  }
  if (firstTc && config.First("firstTC") == nullptr && config.First("startingTC") == nullptr && config.First("civFirstTC") == nullptr) {
    Log(L"hcShipmentPointFallback: FirstTC without startingTC: a first town center can only be a TownCenter, which "
        L"the stock list already tries first");
  }
  g_typeNames = entries;
  for (int& id : g_uhcGatherFallbackTypes) {
    id = -1;
  }
  g_uhcGatherFallbackCount = static_cast<std::int32_t>(g_typeNames.size());
  if (!WriteJmp(sites::kGatherFallbackExit.va, reinterpret_cast<const void*>(&UhcHcGatherFallbackHook), 5) ||
      (replace && !WriteJmp(sites::kGatherSearchStart.va, reinterpret_cast<const void*>(&UhcHcGatherReplaceHook), 7))) {
    return Outcome::kFailed;
  }
  g_installed = true;
  Log(L"hcShipmentPointFallback: %d extra types %ls%ls%ls%ls (multiplayer unverified)", g_uhcGatherFallbackCount,
      replace ? L"instead of the stock list" : L"after the stock list",
      firstTc ? L", including each player's first town center (FirstTC)" : L"", lastResort ? L", and a last resort" : L"",
      g_warn ? L", with a warning" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
