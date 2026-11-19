// kbUnitSyscalls: adds five KB syscalls about resource units that AI scripts may call:
//
//   float kbUnitGetCurrentInventory(int unitID, int resourceID)
//   float kbUnitGetInventoryCapacity(int unitID, int resourceID)
//   bool  kbUnitIsInventoryFull(int unitID)
//   int   kbUnitGetNumberWorkersIfSeeable(int unitID)
//   int   kbUnitGetNumberTargeters(int unitID)
//
// "The player" is the one whose script runs ([0xC66664], as the stock kb syscalls use it).
// - Inventory: the unit's resource inventory [[unit+B4h]+94h] (a ResList at +4, read with
//   0x44EFFF) and its carry capacity (0x494503); isFull is the engine's own test (0x4DC520).
// - Workers: the stock kbUnitGetNumberWorkers returns the worker count [unit+98h] only for the
//   player's own units. This one counts, for a unit the player can see (0x48A9EF), the entries of
//   its worker array ([unit+94h], 18h-byte entries whose first dword is the worker's ID) whose
//   worker the player can see too. -1 for an unknown unit, 0 for one the player cannot see.
// - Targeters: the player's units of abstract index 16h (the one the wonder age-up tests) that
//   are not already working the unit, but whose squad (0x4E2A03) has an order on it: squad
//   [+1Ch] -> object with an array of pointers [+28h], count [+2Ch]; each pointed object has an
//   array [+1Ch], count [+20h], of 18h-byte entries whose first dword is a target unit ID.
//   -1 for an unknown unit.
//
// Every read checks for null and for counts out of range; nothing is written.
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../syscalls.h"

namespace {

using UnitById = char*(__thiscall*)(void* world, std::int32_t id);
using PlayerById = char*(__thiscall*)(void* world, std::int32_t id);
using IsSeeable = bool(__thiscall*)(void* unit, std::int32_t player);
using GetSquad = char*(__thiscall*)(void* unit);
using IsFull = bool(__thiscall*)(void* inventory);
using CarryCapacity = float(__thiscall*)(void* unit, std::int32_t resource);
using ResListGet = float(__thiscall*)(void* list, std::int32_t resource);
using IsAbstractIndex = bool(__thiscall*)(const void* proto, std::int32_t index);

const auto kUnitById = reinterpret_cast<UnitById>(0x0044CC6D);
const auto kPlayerById = reinterpret_cast<PlayerById>(0x0044CB21);
const auto kIsSeeable = reinterpret_cast<IsSeeable>(0x0048A9EF);
const auto kGetSquad = reinterpret_cast<GetSquad>(0x004E2A03);
const auto kIsFull = reinterpret_cast<IsFull>(0x004DC520);
const auto kCarryCapacity = reinterpret_cast<CarryCapacity>(0x00494503);
const auto kResListGet = reinterpret_cast<ResListGet>(0x0044EFFF);
const auto kIsAbstractIndex = reinterpret_cast<IsAbstractIndex>(0x0044CAC4);

constexpr std::int32_t kGathererIndex = 0x16;
constexpr std::int32_t kMaxListed = 100000;  // sanity bound on the engine arrays walked here

bool g_logged[5] = {};

template <typename T>
T At(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

void TraceOnce(int index, const char* name) {
  if (!g_logged[index]) {
    g_logged[index] = true;
    uhc::Log(L"hook reached: kbUnitSyscalls %hs", name);
  }
}

void* World() {
  const char* game = *reinterpret_cast<char* const*>(0x00C66234);
  return game == nullptr ? nullptr : *reinterpret_cast<void* const*>(game + 0x13C);
}

std::int32_t CurrentPlayer() { return *reinterpret_cast<const std::int32_t*>(0x00C66664); }

char* Unit(std::int32_t id) {
  void* world = World();
  return world == nullptr || id < 0 ? nullptr : kUnitById(world, id);
}

void* Inventory(const char* unit) {
  const char* data = At<const char*>(unit, 0xB4);
  return data == nullptr ? nullptr : At<void*>(data, 0x94);
}

bool Seeable(char* unit, std::int32_t player) { return player >= 0 && player < 32 && kIsSeeable(unit, player); }

float __cdecl KbUnitGetCurrentInventory(std::int32_t unitId, std::int32_t resource) {
  TraceOnce(0, "kbUnitGetCurrentInventory");
  char* unit = Unit(unitId);
  char* inventory = unit == nullptr ? nullptr : static_cast<char*>(Inventory(unit));
  return inventory == nullptr ? 0.0f : kResListGet(inventory + 4, resource);
}

float __cdecl KbUnitGetInventoryCapacity(std::int32_t unitId, std::int32_t resource) {
  TraceOnce(1, "kbUnitGetInventoryCapacity");
  char* unit = Unit(unitId);
  return unit == nullptr || At<void*>(unit, 0x5C) == nullptr ? 0.0f : kCarryCapacity(unit, resource);
}

bool __cdecl KbUnitIsInventoryFull(std::int32_t unitId) {
  TraceOnce(2, "kbUnitIsInventoryFull");
  char* unit = Unit(unitId);
  void* inventory = unit == nullptr ? nullptr : Inventory(unit);
  return inventory != nullptr && kIsFull(inventory);
}

std::int32_t __cdecl KbUnitGetNumberWorkersIfSeeable(std::int32_t unitId) {
  TraceOnce(3, "kbUnitGetNumberWorkersIfSeeable");
  char* unit = Unit(unitId);
  if (unit == nullptr) {
    return -1;
  }
  const std::int32_t player = CurrentPlayer();
  if (!Seeable(unit, player)) {
    return 0;
  }
  const char* workers = At<const char*>(unit, 0x94);
  const std::int32_t count = At<std::int32_t>(unit, 0x98);
  if (workers == nullptr || count <= 0 || count > kMaxListed) {
    return 0;
  }
  std::int32_t seen = 0;
  for (std::int32_t i = 0; i < count; ++i) {
    char* worker = Unit(At<std::int32_t>(workers, 0x18 * i));
    if (worker != nullptr && Seeable(worker, player)) {
      ++seen;
    }
  }
  return seen;
}

bool IsWorkerOf(const char* resource, std::int32_t unitId) {
  const char* workers = At<const char*>(resource, 0x94);
  const std::int32_t count = At<std::int32_t>(resource, 0x98);
  if (workers == nullptr || count <= 0 || count > kMaxListed) {
    return false;
  }
  for (std::int32_t i = 0; i < count; ++i) {
    if (At<std::int32_t>(workers, 0x18 * i) == unitId) {
      return true;
    }
  }
  return false;
}

bool SquadTargets(char* unit, std::int32_t targetId) {
  const char* squad = kGetSquad(unit);
  const char* plan = squad == nullptr ? nullptr : At<const char*>(squad, 0x1C);
  if (plan == nullptr) {
    return false;
  }
  const char* const* orders = At<const char* const*>(plan, 0x28);
  const std::int32_t orderCount = At<std::int32_t>(plan, 0x2C);
  if (orders == nullptr || orderCount <= 0 || orderCount > kMaxListed) {
    return false;
  }
  for (std::int32_t i = 0; i < orderCount; ++i) {
    const char* order = orders[i];
    if (order == nullptr) {
      continue;
    }
    const char* targets = At<const char*>(order, 0x1C);
    const std::int32_t targetCount = At<std::int32_t>(order, 0x20);
    if (targets == nullptr || targetCount <= 0 || targetCount > kMaxListed) {
      continue;
    }
    for (std::int32_t k = 0; k < targetCount; ++k) {
      if (At<std::int32_t>(targets, 0x18 * k) == targetId) {
        return true;
      }
    }
  }
  return false;
}

std::int32_t __cdecl KbUnitGetNumberTargeters(std::int32_t unitId) {
  TraceOnce(4, "kbUnitGetNumberTargeters");
  void* world = World();
  char* resource = Unit(unitId);
  const std::int32_t playerId = CurrentPlayer();
  const char* player = world == nullptr || playerId < 0 ? nullptr : kPlayerById(world, playerId);
  if (resource == nullptr || player == nullptr) {
    return -1;
  }
  const std::int32_t* ids = At<const std::int32_t*>(player, 0xF8);
  const std::int32_t count = At<std::int32_t>(player, 0xFC);
  if (ids == nullptr || count <= 0 || count > kMaxListed) {
    return 0;
  }
  std::int32_t targeters = 0;
  for (std::int32_t i = 0; i < count; ++i) {
    char* unit = Unit(ids[i]);
    const void* proto = unit == nullptr ? nullptr : At<const void*>(unit, 0x5C);
    if (proto == nullptr || !kIsAbstractIndex(proto, kGathererIndex)) {
      continue;
    }
    if (!IsWorkerOf(resource, At<std::int32_t>(unit, 0x10)) && SquadTargets(unit, unitId)) {
      ++targeters;
    }
  }
  return targeters;
}

uhc::SyscallParam IntParam() {
  uhc::SyscallParam p;
  p.type = uhc::kSyscallInt;
  p.intValue = -1;
  return p;
}

void Add(std::uint32_t retType, const char* name, const void* fn, int params, const char* comment) {
  uhc::SyscallDef def;
  def.group = uhc::SyscallGroup::kKb;
  def.retType = retType;
  def.name = name;
  def.fn = fn;
  def.comment = comment;
  for (int i = 0; i < params; ++i) {
    def.params.push_back(IntParam());
  }
  def.source = "kbUnitSyscalls";
  uhc::AddSyscall(std::move(def));
}

}  // namespace

namespace uhc {

Outcome ApplyKbUnitSyscalls(const Config& config) {
  if (config.First("kbUnitSyscalls") == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("kbUnitSyscalls", {&sites::kUnitById, &sites::kPlayerById, &sites::kUnitIsSeeable,
                                    &sites::kUnitGetSquad, &sites::kInventoryIsFull, &sites::kUnitCarryCapacity,
                                    &sites::kResListGet, &sites::kIsAbstractIndex})) {
    return Outcome::kFailed;
  }
  if (!InstallSyscallHooks("kbUnitSyscalls")) {
    return Outcome::kFailed;
  }
  Add(kSyscallFloat, "kbUnitGetCurrentInventory", reinterpret_cast<const void*>(&KbUnitGetCurrentInventory), 2,
      "Returns the amount of the resource the unit holds.");
  Add(kSyscallFloat, "kbUnitGetInventoryCapacity", reinterpret_cast<const void*>(&KbUnitGetInventoryCapacity), 2,
      "Returns how much of the resource the unit can hold.");
  Add(kSyscallBool, "kbUnitIsInventoryFull", reinterpret_cast<const void*>(&KbUnitIsInventoryFull), 1,
      "Returns true if the unit's inventory is full.");
  Add(kSyscallInt, "kbUnitGetNumberWorkersIfSeeable",
      reinterpret_cast<const void*>(&KbUnitGetNumberWorkersIfSeeable), 1,
      "Returns the number of visible workers on a visible unit, -1 if the unit is unknown.");
  Add(kSyscallInt, "kbUnitGetNumberTargeters", reinterpret_cast<const void*>(&KbUnitGetNumberTargeters), 1,
      "Returns the number of the player's gatherers on their way to the unit, -1 if it is unknown.");
  Log(L"kbUnitSyscalls: 5 kb syscalls added");
  return Outcome::kApplied;
}

}  // namespace uhc
