// noCorpseDopples [UnitType] [expire=<seconds>] [log]: a dead unit of the marker type leaves no dopple.
//
// A dopple is the copy of a unit that a player keeps seeing under the fog of war after the unit
// left his view. The per-unit visibility update FUN_0048679A creates one when a unit leaves a
// player's view (0x49520B) and its proto is Doppled, the unit is in the world (state bit 8) and
// state bit 1Dh is clear; a DoppleOnlyWhenDead proto only while gaia owns it. The creation call
// 0x4DB3D0 makes the dopple for that player and for the players who share his vision. Nothing
// asks whether the unit is alive: a hunt's carcass that still holds food gets a dopple in its
// death pose, and the dopple stays until the player sees the spot again, long after the carcass
// was eaten (by other players' hunters, or allies') or abandoned. A depleted carcass is never
// doppled, because the game takes it out of the world (bit 8) before it decays. Stock hunts use
// VisibleUnderFogOnlyAfterSeen instead and are never doppled; a mod that makes its hunts Doppled
// keeps a live herd stays where it was last seen.
//
// The hook runs just before the creation call: a unit whose proto is of the marker type (default
// AbstractNoCorpseDopple; "Huntable" covers every hunt with no data change) and that is not alive
// (unit vtable slot A4h, the stock test) gets no dopple, for any player. It simply disappears
// into the fog. A live marked unit is still doppled. The hook is in hooks/dopple_hooks.asm.
//
// A dopple made while the unit lived stays when it dies out of sight. expire= ends every dopple of a marked
// proto that many seconds after it was made, live or dead, so its going says nothing about the unit. The
// world update's manager update 0x491961 asks 0x49192B of each dopple whether it ends (true: 0x5038E0 takes it
// out); the call at 0x49198B goes to a wrapper that also says true past that age. [dopple+0] is the game time
// it was made and [dopple+12Ch] its proto ID. Simulation time and data only, in the simulation update, so
// every machine ends the same dopples.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

// One line per skipped dopple; a long game with many hunts stops logging after this many.
constexpr unsigned kMaxLogLines = 1000;
unsigned g_logged = 0;

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr float kMaxExpireSeconds = 3600.0f;

using DoppleUpdateFn = bool(__thiscall*)(char* dopple, std::int32_t a, std::int32_t b, std::int32_t c);
using ProtoByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kDoppleUpdate = reinterpret_cast<DoppleUpdateFn>(0x0049192B);
const auto kProtoById = reinterpret_cast<ProtoByIdFn>(0x0045316E);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

std::uint32_t g_expireMs = 0;
// By proto ID: 0 not asked yet, 1 marked, 2 not. Cleared on each database load.
std::vector<std::uint8_t> g_marked;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// A unit's proto is at [unit+5Ch]; its name, for the log, at [proto+10h].
const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

}  // namespace

extern "C" {
extern std::int32_t g_uhcNoCorpseDoppleType;
extern std::int32_t g_uhcNoCorpseDoppleLog;
}

namespace {

void NewDatabase(char*) { g_marked.clear(); }

bool IsMarked(const char* database, std::int32_t protoId) {
  if (protoId < 0 || g_uhcNoCorpseDoppleType < 0) {
    return false;
  }
  if (static_cast<std::size_t>(protoId) >= g_marked.size()) {
    g_marked.resize(static_cast<std::size_t>(protoId) + 1, 0);
  }
  std::uint8_t& known = g_marked[protoId];
  if (known == 0) {
    const char* proto = kProtoById(database, protoId);
    known = proto != nullptr && kProtoIsType(proto, g_uhcNoCorpseDoppleType) ? 1 : 2;
  }
  return known == 1;
}

// In place of the call at 0x49198B. Runs the stock update, and ends a marked dopple past its age.
bool __fastcall DoppleUpdate(char* dopple, void*, std::int32_t a, std::int32_t b, std::int32_t c) {
  if (kDoppleUpdate(dopple, a, b, c)) {
    return true;
  }
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (world == nullptr || database == nullptr) {
    return false;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::uint32_t made = Field<std::uint32_t>(dopple, 0x00);
  if (static_cast<std::int32_t>(now - made) < static_cast<std::int32_t>(g_expireMs) ||
      !IsMarked(database, Field<std::int32_t>(dopple, 0x12C))) {
    return false;
  }
  if (g_uhcNoCorpseDoppleLog != 0 && g_logged < kMaxLogLines) {
    ++g_logged;
    uhc::Log(L"noCorpseDopples: the dopple of unit %d, made at %.1f s, ends at %.1f s (player %d)",
             Field<std::int32_t>(dopple, 0x0C), made / 1000.0, now / 1000.0, b);
  }
  return true;
}

}  // namespace

extern "C" {
std::int32_t g_uhcNoCorpseDoppleType = -1;  // marker unittype ID, set on each database load
std::int32_t g_uhcNoCorpseDoppleLog = 0;    // 1 with "noCorpseDopples ... log"

void UhcNoCorpseDoppleHook();

// Called by the hook for every dopple it skips (only with "log"). `player` lost sight of `unit`.
void __stdcall UhcNoCorpseDoppleLog(const char* unit, std::int32_t player) {
  if (g_logged >= kMaxLogLines) {
    return;
  }
  ++g_logged;
  uhc::Log(L"noCorpseDopples: unit %d (%hs, hp %.1f) left player %d's view dead; no dopple",
           Field<std::int32_t>(unit, 0x10), ProtoName(unit), static_cast<double>(Field<float>(unit, 0x64)), player);
  if (g_logged == kMaxLogLines) {
    uhc::Log(L"noCorpseDopples: %u dopples logged; the next ones are skipped without a log line", kMaxLogLines);
  }
}
}

namespace uhc {

Outcome ApplyNoCorpseDopples(const Config& config) {
  const Config::Args* args = config.First("noCorpseDopples");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }

  std::string typeName = "AbstractNoCorpseDopple";
  bool typeGiven = false;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (_strnicmp(arg.c_str(), "expire=", 7) == 0) {
      const float seconds = static_cast<float>(std::atof(arg.c_str() + 7));
      if (!(seconds > 0.0f) || seconds > kMaxExpireSeconds) {
        Log(L"noCorpseDopples: %hs: expected seconds above 0 and at most %.0f; feature not applied", arg.c_str(),
            static_cast<double>(kMaxExpireSeconds));
        return Outcome::kFailed;
      }
      g_expireMs = static_cast<std::uint32_t>(seconds * 1000.0f);
    } else if (!typeGiven) {
      typeName = arg;
      typeGiven = true;
    } else {
      Log(L"noCorpseDopples: unexpected argument %hs (expected: [UnitType] [expire=<seconds>] [log]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("noCorpseDopples", {&sites::kNoCorpseDoppleCreate, &sites::kNoCorpseDoppleGaiaCheck,
                                     &sites::kNoCorpseDoppleSkip, &sites::kNoCorpseDoppleAliveCall})) {
    return Outcome::kFailed;
  }
  if (g_expireMs != 0 && !VerifyAll("noCorpseDopples expire", {&sites::kDoppleUpdateCall, &sites::kDoppleInitProto})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(typeName.c_str(), &g_uhcNoCorpseDoppleType)) {
    return Outcome::kFailed;
  }
  g_uhcNoCorpseDoppleLog = log ? 1 : 0;
  // Replaces mov eax,[esp+2Ch] / mov ecx,[esp+54h] at 0x49534D; the hook re-executes them.
  if (!WriteJmp(sites::kNoCorpseDoppleCreate.va, reinterpret_cast<const void*>(&UhcNoCorpseDoppleHook), 8)) {
    return Outcome::kFailed;
  }
  if (g_expireMs != 0 && (!OnDatabaseLoad(&NewDatabase) ||
                          !WriteCall(sites::kDoppleUpdateCall.va, reinterpret_cast<const void*>(&DoppleUpdate)))) {
    return Outcome::kFailed;
  }
  Log(L"noCorpseDopples: dead units of unittype %hs leave no dopple in the fog of war%ls (multiplayer unverified)",
      typeName.c_str(), log ? L", every skipped dopple logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
