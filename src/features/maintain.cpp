// maintainWaitForPop: a building's automatic production (the Maintain action: factory cannons,
// the Ottoman Town Center's settlers, dock boats, native warriors, ...) keeps a finished unit while
// its player has no population room, instead of losing it.
//
// Stock: the Maintain update FUN_00492F3E adds train points to [action+70h] every tick; when the
// fraction [action+74h] reaches 1.0 it calls the spawn FUN_009E2DEF(this, [+64h] proto ID, [+68h]
// units per cycle), whose population test stops before the first unit when it does not fit. The
// update never looks at the result: a persistent action restarts its cycle from zero
// (setState(14h)), a SingleUse one ends (setState(0Ah)), so a cycle that ends while the player is
// housed produces nothing.
//
// The change: a hook just before the spawn call asks UhcMaintainPopBlocked, which repeats the
// spawn's first-unit test with the engine's own getters. When that unit would not fit and the
// building's proto has the marker unittype (default AbstractMaintainWaitForPop), the call and the
// restart are skipped and the cycle stays complete; every later update comes back to the same
// test, and the unit spawns on the first update with room. The hook is in hooks/maintain_hooks.asm.
#include <cstdint>
#include <cstring>
#include <map>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" void UhcMaintainSpawnHook();

namespace {

// Engine layout (docs/engine-symbols.md, "Maintain (automatic production)").
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using PlayerProtoFn = char*(__thiscall*)(char* player, std::int32_t protoId);
using ProtoBitFn = bool(__thiscall*)(const char* proto, std::int32_t bit);
using PlayerCountFn = std::int32_t(__thiscall*)(char* player);

const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kProtoHasAbstractBit = reinterpret_cast<ProtoBitFn>(0x0044CAC4);  // raw bitset [proto+30h]
const auto kProtoHasFlag = reinterpret_cast<ProtoBitFn>(0x0045EE02);         // flags [proto+50h]
const auto kPlayerPop = reinterpret_cast<PlayerCountFn>(0x0045805C);
const auto kPlayerPopCap = reinterpret_cast<PlayerCountFn>(0x004581A1);  // includes basePop/extraPop

constexpr std::int32_t kAbstractMonk = 0x5D;           // may reuse a unit with no population test
constexpr std::int32_t kAllowOverPopCap = 0x9F;        // needs only cap - used > 0
constexpr std::int32_t kAlwaysAllowOverPopCap = 0xA3;  // no population test

// Database offsets of the proto IDs the spawn replaces with xpColonialMilitia ([db+609Ch]) once
// the player has revolted: Settler, Coureur, SettlerWagon, CoureurCree.
constexpr std::uint32_t kRevoltedIds[] = {0x5E1C, 0x6054, 0x6050, 0x6058};
constexpr std::uint32_t kMilitiaId = 0x609C;

std::int32_t g_markerType = -1;  // marker unittype ID, set on each database load; -1 before

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

char* Database() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<char*>(game, 0x140);
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

struct PopCheck {
  bool blocked = false;
  bool measured = false;        // pop, used and cap below were read
  const char* proto = nullptr;  // the player's proto of the unit to spawn
  std::int32_t pop = 0;
  std::int32_t used = 0;
  std::int32_t cap = 0;
};

// The first-unit test of FUN_009E2DEF (0x9E2E35..0x9E2EE9, 0x9E2F79..0x9E2FE2, 0x9E3110..0x9E311F)
// and of the group spawn FUN_009E2AC8 (0x9E2B69..0x9E2BD5), in the engine's order and with its
// 32-bit arithmetic. Every step that lets the stock call create a unit, or that the test does not
// cover (AbstractMonk reuse, an empty cycle), answers "not blocked", so the stock call runs.
PopCheck CheckFirstUnit(char* action) {
  PopCheck check;
  char* owner = Field<char*>(action, 0x10);
  char* player = owner == nullptr ? nullptr : Field<char*>(owner, 0x44);
  if (player == nullptr || Field<std::int32_t>(action, 0x68) < 1) {
    return check;
  }
  const char* ownerProto = Field<const char*>(owner, 0x5C);
  if (g_markerType < 0 || ownerProto == nullptr || !kProtoIsType(ownerProto, g_markerType)) {
    return check;
  }
  std::int32_t protoId = Field<std::int32_t>(action, 0x64);
  const char* database = Database();
  if (Field<std::uint8_t>(player, 0x50A) != 0 && database != nullptr) {
    for (std::uint32_t offset : kRevoltedIds) {
      if (protoId == Field<std::int32_t>(database, offset)) {
        protoId = Field<std::int32_t>(database, kMilitiaId);
        break;
      }
    }
  }
  check.proto = kPlayerProto(player, protoId);
  if (check.proto == nullptr || kProtoHasAbstractBit(check.proto, kAbstractMonk)) {
    return check;
  }
  check.pop = Field<std::int32_t>(check.proto, 0xD8);
  if (check.pop <= 0 || kProtoHasFlag(check.proto, kAlwaysAllowOverPopCap)) {
    return check;
  }
  const std::uint32_t used = Field<std::uint32_t>(player, 0x78) + static_cast<std::uint32_t>(kPlayerPop(player));
  const std::uint32_t cap = static_cast<std::uint32_t>(kPlayerPopCap(player));
  check.used = static_cast<std::int32_t>(used);
  check.cap = static_cast<std::int32_t>(cap);
  check.measured = true;
  if (kProtoHasFlag(check.proto, kAllowOverPopCap)) {
    check.blocked = static_cast<std::int32_t>(cap - used) <= 0;
  } else {
    check.blocked = check.cap < static_cast<std::int32_t>(used + static_cast<std::uint32_t>(check.pop));
  }
  return check;
}

// "maintainWaitForPop ... log": the actions holding a unit, with their building's unit ID (an
// action freed with its building may be reused at the same address). Logging only; cleared on
// each database load.
bool g_log = false;
std::map<const char*, std::int32_t> g_held;

void ClearHeld(char*) { g_held.clear(); }

void LogTransition(const char* action, const PopCheck& check) {
  const char* owner = Field<const char*>(action, 0x10);
  const std::int32_t ownerId = owner == nullptr ? -1 : Field<std::int32_t>(owner, 0x10);
  const char* ownerName = owner == nullptr ? "?" : ProtoName(Field<const char*>(owner, 0x5C));
  const auto held = g_held.find(action);
  const bool wasHeld = held != g_held.end() && held->second == ownerId;
  if (check.blocked && !wasHeld) {
    g_held[action] = ownerId;
    uhc::Log(L"maintainWaitForPop: unit %d (%hs) holds a finished %hs (pop %d, %d of %d used)", ownerId, ownerName,
             ProtoName(check.proto), check.pop, check.used, check.cap);
  } else if (!check.blocked && wasHeld) {
    g_held.erase(held);
    if (check.measured) {
      uhc::Log(L"maintainWaitForPop: unit %d (%hs) releases its %hs (pop %d, %d of %d used)", ownerId, ownerName,
               ProtoName(check.proto), check.pop, check.used, check.cap);
    } else {
      uhc::Log(L"maintainWaitForPop: unit %d (%hs) releases its %hs", ownerId, ownerName, ProtoName(check.proto));
    }
  }
}

}  // namespace

extern "C" {
// Called from the hook with the Maintain action whose cycle is complete. True: the first unit
// does not fit, so the hook keeps the cycle complete instead of calling the spawn. Reads only
// simulation state.
bool __stdcall UhcMaintainPopBlocked(char* action) {
  const PopCheck check = CheckFirstUnit(action);
  if (g_log) {
    LogTransition(action, check);
  }
  return check.blocked;
}
}

namespace uhc {

Outcome ApplyMaintainWaitForPop(const Config& config) {
  const Config::Args* args = config.First("maintainWaitForPop");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::string typeName = "AbstractMaintainWaitForPop";
  bool typeGiven = false;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (!typeGiven) {
      typeName = arg;
      typeGiven = true;
    } else {
      Log(L"maintainWaitForPop: unexpected argument %hs (expected: [UnitType] [log]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("maintainWaitForPop",
                 {&sites::kMaintainCycleDone, &sites::kMaintainSpawn, &sites::kMaintainRestart,
                  &sites::kMaintainNotDone, &sites::kMaintainEpilogue, &sites::kMaintainSpawnSetup,
                  &sites::kMaintainSpawnPopTest, &sites::kMaintainSpawnPopTest2, &sites::kMaintainGroupPopTest})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(typeName.c_str(), &g_markerType)) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (log && !OnDatabaseLoad(&ClearHeld)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kMaintainSpawn.va, reinterpret_cast<const void*>(&UhcMaintainSpawnHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"maintainWaitForPop: buildings of unittype %hs keep a finished Maintain unit until there is "
      L"population room%ls (multiplayer unverified)",
      typeName.c_str(), log ? L", holds and releases logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
