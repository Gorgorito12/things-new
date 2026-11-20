// truckAttackResourceFix [log]: a TruckAttack no longer empties the buildings it hits.
//
// The stock TruckAttack action (BUnitTruckAttackAction, vtable 0xB98468; the tactics type `TruckAttack`, used by the
// stock monster truck and, in mods, by poison clouds, plagues, tornadoes and fires) hits
// every unit in its range a few times a second (0x9EC4E1, from its update 0x9EC6D4): for each target of another
// player that is alive, built and allowed, it first sets the target's whole resource inventory
// [[unit+0B4h]+94h] to 0 (0x58F070), then deals the damage. On a building that holds resources, a Mill (999 food), a
// plantation, a rice paddy, that leaves it empty for good: its <UnlimitedSupply> does not refill it, and villagers
// sent to it stand idle beside it. The key skips the reset when the target is a building (abstract index 2, the test
// the damage function uses); the damage is unchanged, and units (a hunt, a villager) are still emptied as before.
//
// The hook is at 0x9EC635 (hooks/truckattack_hooks.asm). Everything it reads is simulation state, on every machine.
#include <cstdint>
#include <set>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcTruckInventoryHook();

namespace {

using IsAbstractIndexFn = bool(__thiscall*)(const void* proto, std::int32_t index);
const auto kIsAbstractIndex = reinterpret_cast<IsAbstractIndexFn>(0x0044CAC4);
constexpr std::int32_t kBuildingIndex = 2;
constexpr std::size_t kMaxLogged = 200;

bool g_log = false;
std::set<std::int32_t> g_logged;  // log only: the buildings already named

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

const char* NameOf(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

std::int32_t PlayerOf(const char* unit) {
  const char* player = unit == nullptr ? nullptr : Field<const char*>(unit, 0x44);
  return player == nullptr ? -1 : Field<std::int32_t>(player, 0);
}

}  // namespace

// From the hook: true when the target keeps its resources (it is a building).
extern "C" bool __stdcall UhcTruckKeepsInventory(const char* action, const char* target) {
  const char* proto = target == nullptr ? nullptr : Field<const char*>(target, 0x5C);
  if (proto == nullptr || !kIsAbstractIndex(proto, kBuildingIndex)) {
    return false;
  }
  if (g_log && g_logged.size() < kMaxLogged && g_logged.insert(Field<std::int32_t>(target, 0x10)).second) {
    const char* attacker = action == nullptr ? nullptr : Field<const char*>(action, 0x10);
    uhc::Log(L"truckAttackResourceFix: unit %d (%hs, player %d) hit by unit %d (%hs, player %d): its resources kept",
             Field<std::int32_t>(target, 0x10), NameOf(target), PlayerOf(target),
             attacker == nullptr ? -1 : Field<std::int32_t>(attacker, 0x10), NameOf(attacker), PlayerOf(attacker));
  }
  return true;
}

namespace uhc {

Outcome ApplyTruckAttackResourceFix(const Config& config) {
  const Config::Args* args = config.First("truckAttackResourceFix");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"truckAttackResourceFix: unknown option %hs (expected [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("truckAttackResourceFix", {&sites::kTruckAttackInventoryReset, &sites::kIsAbstractIndex})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kTruckAttackInventoryReset.va, reinterpret_cast<const void*>(&UhcTruckInventoryHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"truckAttackResourceFix: a TruckAttack no longer empties the buildings it hits (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
