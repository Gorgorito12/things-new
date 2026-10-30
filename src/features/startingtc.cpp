// startingTC [UnitType] [log]: buildings of a marker unittype (default AbstractStartingTC) can be
// a player's first town center, the unit the placement rules call FirstTC.
//
// Stock keeps one first town center per player, a unit ID at [player+4F0h] (-1 at first). The
// placement rules read it through the keyword FirstTC (stock placementrules: no building within
// 65 m of an enemy's FirstTC, and the "norushonly" rule within 75 m of a team FirstTC; rule
// evaluators FUN_008CE515 / FUN_008CE935). Player::addUnit FUN_0049874F sets it once, while it is
// still -1, to a unit whose exact proto ID is TownCenter's ([database+5E08h], 0x506B3B). Nothing
// clears it when that unit dies. A civ that starts with another building has no FirstTC, or a
// dead one: e.g. a start tech that gives TownCenter a Lifespan of 0.5 s and then a free
// replacement building in the same tech, so the replacement is added while the town center is
// still alive and FirstTC stays on it.
//
// Two hooks in addUnit (hooks/startingtc_hooks.asm), for a unit whose proto is of the marker type:
// - a player with no FirstTC yet takes it, as stock takes a TownCenter;
// - a player whose FirstTC is gone (not in the unit table), dead (unit vtable slot A4h) or has a
//   pending lifespan (state bit 3, set by setLifespan 0x48DCB9) gets it as the new FirstTC.
// A TownCenter keeps its stock behavior. The test reads only game state, the same on every machine.
#include <cstdint>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world

using IsAliveFn = bool(__thiscall*)(const char* unit);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// The world the FirstTC rules read ([game+13Ch], 0x8CE5A8).
const char* MainWorld() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

// Players: [world+58h] array, [world+5Ch] count; a player's ID is at [player+0].
const char* PlayerById(const char* world, std::int32_t id) {
  if (id < 0 || id >= Field<std::int32_t>(world, 0x5C)) {
    return nullptr;
  }
  return Field<const char* const*>(world, 0x58)[id];
}

// Units by ID, as the FirstTC rule looks them up (0x8CE5B5): [world+0Ch] array, [world+10h]
// count; the low 18 bits index the array and [unit+10h] must equal the full ID.
const char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

// Unit vtable slot A4h (0x44D019): state bit 8 set, bit 12 clear and HP > 0, the stock alive test.
bool IsAlive(const char* unit) { return (*reinterpret_cast<IsAliveFn const* const*>(unit))[0xA4 / 4](unit); }

// State bit 3 of the bitset [unit+4] (bit count [unit+8]): setLifespan sets it for a lifespan
// > 0, and the lifespan tick clears it when the countdown [[unit+B4h]+1Ch] ends and queues the kill.
bool LifespanPending(const char* unit) {
  return Field<std::uint32_t>(unit, 0x08) > 3 && (Field<const std::uint8_t*>(unit, 0x04)[0] & 0x08) != 0;
}

const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

}  // namespace

extern "C" {
std::int32_t g_uhcStartingTcType = -1;  // marker unittype ID, set on each database load
std::int32_t g_uhcStartingTcLog = 0;    // 1 with "startingTC ... log"

void UhcStartingTcGateHook();
void UhcStartingTcProtoHook();

// From the proto hook, only with "log": a marked unit is the first FirstTC of its player.
void __stdcall UhcStartingTcFirst(const char* player, const char* unit) {
  uhc::Log(L"startingTC: unit %d (%hs) is player %d's first town center (FirstTC)", Field<std::int32_t>(unit, 0x10),
           ProtoName(unit), Field<std::int32_t>(player, 0x00));
}

// From the gate hook, for a marked unit added to a player who has a FirstTC: true if that FirstTC
// no longer counts, so the unit replaces it.
bool __stdcall UhcStartingTcStale(const char* player, const char* unit) {
  const std::int32_t playerId = Field<std::int32_t>(player, 0x00);
  const std::int32_t old = Field<std::int32_t>(player, 0x4F0);
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const char* world = MainWorld();
  // A player of another world (the home city's) is left alone.
  if (old == id || world == nullptr || PlayerById(world, playerId) != player) {
    return false;
  }
  const char* tc = UnitById(world, old);
  if (tc == nullptr) {
    if (g_uhcStartingTcLog != 0) {
      uhc::Log(L"startingTC: unit %d (%hs) replaces player %d's first town center %d, which is gone", id,
               ProtoName(unit), playerId, old);
    }
    return true;
  }
  if (!IsAlive(tc)) {
    if (g_uhcStartingTcLog != 0) {
      uhc::Log(L"startingTC: unit %d (%hs) replaces player %d's first town center %d (%hs), which is dead", id,
               ProtoName(unit), playerId, old, ProtoName(tc));
    }
    return true;
  }
  if (LifespanPending(tc)) {
    if (g_uhcStartingTcLog != 0) {
      const char* sub = Field<const char*>(tc, 0xB4);
      uhc::Log(L"startingTC: unit %d (%hs) replaces player %d's first town center %d (%hs), whose lifespan ends in "
               L"%.2f s",
               id, ProtoName(unit), playerId, old, ProtoName(tc),
               sub == nullptr ? -1.0 : static_cast<double>(Field<float>(sub, 0x1C)));
    }
    return true;
  }
  return false;
}
}

namespace uhc {

namespace {
bool g_protoHookInstalled = false;
}  // namespace

// The hook at 0x506B3B serves startingTC and civFirstTC (features/civfirsttc.cpp): whichever key
// applies first writes it, after its own VerifyAll.
bool FirstTcProtoHookInstalled() { return g_protoHookInstalled; }

bool InstallFirstTcProtoHook() {
  if (!g_protoHookInstalled) {
    // Replaces cmp eax,[ecx+5E08h] at 0x506B3B; the hook re-executes it.
    g_protoHookInstalled =
        WriteJmp(sites::kFirstTcProtoCheck.va, reinterpret_cast<const void*>(&UhcStartingTcProtoHook), 6);
  }
  return g_protoHookInstalled;
}

Outcome ApplyStartingTc(const Config& config) {
  const Config::Args* args = config.First("startingTC");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::string typeName = "AbstractStartingTC";
  bool typeGiven = false;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (!typeGiven) {
      typeName = arg;
      typeGiven = true;
    } else {
      Log(L"startingTC: unexpected argument %hs (expected: [UnitType] [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("startingTC", {&sites::kFirstTcGate, &sites::kFirstTcChunk, &sites::kFirstTcProtoCheck,
                                &sites::kFirstTcSet, &sites::kFirstTcRuleLookup, &sites::kSetLifespanArm,
                                &sites::kUnitAliveSlot, &sites::kIsA})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(typeName.c_str(), &g_uhcStartingTcType)) {
    return Outcome::kFailed;
  }
  g_uhcStartingTcLog = log ? 1 : 0;
  if (!InstallFirstTcProtoHook()) {
    return Outcome::kFailed;
  }
  // Replaces cmp dword ptr [esi+4F0h],0 / jl 506B2Ah at 0x49880A; the hook re-executes both. Without
  // it the proto hook would run alone: put its stock bytes back rather than run half the feature.
  if (!WriteJmp(sites::kFirstTcGate.va, reinterpret_cast<const void*>(&UhcStartingTcGateHook), 13)) {
    if (WriteBytes(sites::kFirstTcProtoCheck.va, sites::kFirstTcProtoCheck.bytes, 6)) {
      g_protoHookInstalled = false;
    }
    return Outcome::kFailed;
  }
  Log(L"startingTC: units of unittype %hs can be a player's first town center (FirstTC) like TownCenter, and "
      L"replace one that is gone, dead or has a pending lifespan%ls (multiplayer unverified)",
      typeName.c_str(), log ? L", every new FirstTC logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
