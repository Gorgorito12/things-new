// gaiaSocketsOnly: a socketed building (one whose proto has <SocketUnitType>, e.g. TradingPost)
// may only be placed on a socket that Gaia owns.
//
// Stock tests the owner in one place only: the UI's snap to a socket (FUN_00A036BB, 0xA0383B)
// takes only Gaia sockets as candidates, so the placement preview shows a socket a player owns in
// red. The check that decides, FUN_0050703D ("PLACE", World vtable +14h: run by the build
// command on every machine, by uiBuildAtPointer's pre-check and by the AI's checkPlacement),
// accepts any socket of the right type at exactly the building's position and never reads its
// owner. Stock data never shows it, because every stock socket has ForceToGaia; a mod socket that
// a player owns (e.g. a mine socket) is red in the preview, but an order that carries its exact
// position (AI, triggers) builds on it anyway.
//
// The hook (hooks/socket_hooks.asm) sits where PLACE records "socket found" (0x508CC1). When the
// check uses a player's knowledge (its a5 != 0: the build commands, the UI and the AI) and the
// socket's owner is not Gaia, the socket does not count, and PLACE fails through its stock "no
// socket here" path. Without a unittype the rule covers every socket; with one, only sockets of
// that type (or proto name; an extra abstract type, unittypes.h), and every other socket keeps
// the stock rule. Placement with a5 = 0 (the editor, the engine, the in-place conversion
// command 13h) is left alone. The rule reads only the socket's owner, the placing player and the
// data, so every machine decides alike.
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <set>
#include <string>
#include <tuple>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

// An AI build plan that picked a refused socket retries its checkPlacement, maybe on every update
// (0x73E273 takes the first socket of the right type), so each refusal is logged once per socket,
// owner, player and building, and at most this many in all.
constexpr std::size_t kMaxLogged = 1000;

bool g_markerOnly = false;       // "gaiaSocketsOnly <UnitType>": only sockets of that unittype
std::int32_t g_markerType = -1;  // its ID, set on each database load; -1 before
bool g_log = false;              // "gaiaSocketsOnly ... log": log the refusals
std::set<std::tuple<std::int32_t, std::int32_t, std::int32_t, std::int32_t>> g_logged;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Name(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* g_logWorld = nullptr;  // the game g_logged belongs to
std::uint32_t g_logStep = 0;

void LogRefusal(const char* socket, std::int32_t owner, const char* building, std::int32_t player) {
  // Unit IDs start again in every game: a new world, or a step count [world+F8h] that went back,
  // forgets the refusals logged so far.
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const std::uint32_t step = world == nullptr ? 0 : Field<std::uint32_t>(world, 0xF8);
  if (world != g_logWorld || step < g_logStep) {
    g_logged.clear();
  }
  g_logWorld = world;
  g_logStep = step;
  const std::int32_t socketId = Field<std::int32_t>(socket, 0x10);
  const std::int32_t buildingId = Field<std::int32_t>(building, 0x04);
  if (g_logged.size() >= kMaxLogged || !g_logged.insert({socketId, owner, player, buildingId}).second) {
    return;
  }
  uhc::Log(L"gaiaSocketsOnly: refused %hs for player %d on socket %d (%hs), owned by player %d", Name(building), player,
           socketId, Name(Field<const char*>(socket, 0x5C)), owner);
  if (g_logged.size() == kMaxLogged) {
    uhc::Log(L"gaiaSocketsOnly: %u refusals logged; further ones are not", static_cast<unsigned>(kMaxLogged));
  }
}

}  // namespace

extern "C" {
void UhcGaiaSocketFoundHook();

// From the hook, for a socket of the building's type at exactly its position, in a check that uses
// the player's knowledge. False: the socket does not count. `socket` is the socket unit, `building`
// the proto being placed, `player` the placing player (PLACE's a1).
bool __stdcall UhcGaiaSocketAllowed(const char* socket, const char* building, std::int32_t player) {
  if (g_markerOnly) {
    const char* proto = Field<const char*>(socket, 0x5C);
    if (g_markerType < 0 || proto == nullptr || !kProtoIsType(proto, g_markerType)) {
      return true;  // not a marked socket: stock rule
    }
  }
  const char* owner = Field<const char*>(socket, 0x44);
  if (owner == nullptr) {
    return true;  // never seen; the stock snap would read through it
  }
  const std::int32_t ownerId = Field<std::int32_t>(owner, 0x00);
  if (ownerId == 0) {
    return true;
  }
  if (g_log) {
    LogRefusal(socket, ownerId, building, player);
  }
  return false;
}
}

namespace uhc {

Outcome ApplyGaiaSocketsOnly(const Config& config) {
  const Config::Args* args = config.First("gaiaSocketsOnly");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }

  std::string typeName;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (typeName.empty()) {
      typeName = arg;
    } else {
      Log(L"gaiaSocketsOnly: unexpected argument %hs (expected: [UnitType] [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("gaiaSocketsOnly", {&sites::kGaiaSocketMatch, &sites::kGaiaSocketFound, &sites::kGaiaSocketLoopNext,
                                     &sites::kGaiaSocketMissing})) {
    return Outcome::kFailed;
  }
  g_log = log;
  g_markerOnly = !typeName.empty();
  if (g_markerOnly && !RequestAbstractUnitType(typeName.c_str(), &g_markerType)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kGaiaSocketFound.va, reinterpret_cast<const void*>(&UhcGaiaSocketFoundHook), 5)) {
    return Outcome::kFailed;
  }
  if (g_markerOnly) {
    Log(L"gaiaSocketsOnly: sockets of unittype %hs take a socketed building only while Gaia owns them%ls "
        L"(multiplayer unverified)",
        typeName.c_str(), log ? L", refusals logged" : L"");
  } else {
    Log(L"gaiaSocketsOnly: socketed buildings take only sockets owned by Gaia%ls (multiplayer unverified)",
        log ? L", refusals logged" : L"");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
