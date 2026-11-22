// buildingGather [log]: a unit that cannot move (a building: MaxVelocity 0) gathers with its Gather action from a
// target within the action's range, as a villager does once it has walked there.
//
// The Gather action (vtable 0xB97880; state byte [action+61h], gatherer +10h, target ID +14h, range float +24h) is
// started by the start code, which calls setState(0) (0x4ED249, at 0x50DF3D) to walk the gatherer towards the target.
// The walk reports its end to the action as event 9 (the action's event handler, vtable +44h, 0x4EC904 → 0x4EDA75):
// when the gatherer is then in range (its vtable +CCh with the target and [action+24h]) and still in state 0, the
// action goes to state 5, gathering (0x4EDB7B). A building never walks, so no event 9 comes and its Gather action waits
// for ever, in state FFh (in game: a Market ordered to a Mine in range, 37,908 updates in a minute, no other state).
//
// The hook (hooks/buildgather_hooks.asm) sits where the Gather update 0x4EC4FA returns, at 0x4EC76B: for an action
// in state 0 or FFh whose gatherer's proto has MaxVelocity [proto+80h] at 0 or below, it asks the same range test as
// event 9 and sets state 5 when the target is in range; out of range it sets state 9 (the state the start code gives an
// order it refuses), so the building drops the order and is idle again instead of waiting for ever. The update has
// already dropped an order on a target the player cannot see (0x4EC753). A unit that moves is never touched.
// Simulation state only, the same on every machine.
#include <cmath>
#include <cstdint>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint8_t kStateApproach = 0;
constexpr std::uint8_t kStateGather = 5;
constexpr std::uint8_t kStateDone = 9;
constexpr std::uint8_t kStateWaiting = 0xFF;
constexpr int kMaxLogLines = 300;

using InRangeFn = bool(__thiscall*)(const char* unit, const char* target, float range);
using SetStateFn = void(__thiscall*)(char* action, std::int32_t state);

bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

const char* UnitById(std::int32_t id) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

const char* NameOf(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

}  // namespace

extern bool g_uhcBuildingGather;  // autogatherfrom.cpp: orders buildings only while this key is on

extern "C" {

void UhcBuildingGatherHook();

// From the Gather update's exit, for an action in state 0 (approach) or FFh (waiting).
void __stdcall UhcBuildingGatherApproach(char* action) {
  const std::uint8_t state = action == nullptr ? kStateGather : Field<std::uint8_t>(action, 0x61);
  if (state != kStateApproach && state != kStateWaiting) {
    return;
  }
  const char* gatherer = Field<const char*>(action, 0x10);
  const char* proto = gatherer == nullptr ? nullptr : Field<const char*>(gatherer, 0x5C);
  if (proto == nullptr || Field<float>(proto, 0x80) > 0.0f) {
    return;  // it can walk there: stock
  }
  const char* target = UnitById(Field<std::int32_t>(action, 0x14));
  if (target == nullptr) {
    return;  // the stock update ends an action whose target is gone
  }
  const auto inRange = Field<InRangeFn const*>(gatherer, 0)[0xCC / 4];
  const bool in = inRange(gatherer, target, Field<float>(action, 0x24));
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    const float dx = Field<float>(target, 0x14) - Field<float>(gatherer, 0x14);
    const float dz = Field<float>(target, 0x1C) - Field<float>(gatherer, 0x1C);
    uhc::Log(L"buildingGather: unit %d (%hs, state %d) -> unit %d (%hs), %.1f m between centres: %ls",
             Field<std::int32_t>(gatherer, 0x10), NameOf(gatherer), state, Field<std::int32_t>(target, 0x10), NameOf(target),
             static_cast<double>(std::sqrt(dx * dx + dz * dz)), in ? L"in range, gathers" : L"out of range, order dropped");
  }
  Field<SetStateFn const*>(action, 0)[0x34 / 4](action, in ? kStateGather : kStateDone);
}

}  // extern "C"

namespace uhc {

Outcome ApplyBuildingGather(const Config& config) {
  const Config::Args* args = config.First("buildingGather");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    Log(L"buildingGather: bad argument %hs (expected [log]); feature not applied", arg.c_str());
    return Outcome::kFailed;
  }
  if (!VerifyAll("buildingGather", {&sites::kGatherUpdateExit, &sites::kGatherVtableSlots, &sites::kGatherSetState,
                                    &sites::kGatherArrivedState}) ||
      !WriteJmp(sites::kGatherUpdateExit.va, reinterpret_cast<const void*>(&UhcBuildingGatherHook), 8)) {
    return Outcome::kFailed;
  }
  g_uhcBuildingGather = true;
  Log(L"buildingGather: a building with a Gather action gathers from a target within the action's range%ls "
      L"(multiplayer unverified)",
      g_log ? L"; each start logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
