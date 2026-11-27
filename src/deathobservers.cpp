#include "deathobservers.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

namespace {

constexpr std::size_t kMaxObservers = 8;

using KillFn = void(__thiscall*)(char* unit, std::uint32_t a, std::uint32_t b, std::uint32_t c);
const auto kKill = reinterpret_cast<KillFn>(0x004B4F70);

uhc::DeathObserver g_observers[kMaxObservers] = {};
std::size_t g_count = 0;
bool g_installed = false;

using RemoveFn = void(__thiscall*)(char* world, std::int32_t id, std::int32_t a, std::int32_t b);
const auto kRemove = reinterpret_cast<RemoveFn>(0x004726B2);
using UnitTestFn = bool(__thiscall*)(const char* unit);

uhc::DeathObserver g_destroyObservers[kMaxObservers] = {};
std::size_t g_destroyCount = 0;
bool g_destroyInstalled = false;

char* UnitById(const char* world, std::int32_t id) {
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= *reinterpret_cast<const std::int32_t*>(world + 0x10)) {
    return nullptr;
  }
  char* unit = (*reinterpret_cast<char* const* const*>(world + 0x0C))[id & 0x3FFFF];
  return unit != nullptr && *reinterpret_cast<const std::int32_t*>(unit + 0x10) == id ? unit : nullptr;
}

bool IsDead(const char* unit) {  // state bit 11
  const auto* bits = *reinterpret_cast<const std::uint8_t* const*>(unit + 4);
  return bits != nullptr && *reinterpret_cast<const std::uint32_t*>(unit + 8) > 11 && (bits[1] & 0x08) != 0;
}

// Replaces trUnitDestroy's call of the unit removal: thiscall(world, id, a, b), ret 0Ch.
void __fastcall Destroy(char* world, void*, std::int32_t id, std::int32_t a, std::int32_t b) {
  static bool traced = false;
  if (!traced) {
    traced = true;
    uhc::Log(L"hook reached: unit destroys (0x9828E7)");
  }
  char* unit = UnitById(world, id);
  if (unit != nullptr && !IsDead(unit) && (*reinterpret_cast<UnitTestFn const* const*>(unit))[0xA4 / 4](unit)) {
    for (std::size_t i = 0; i < g_destroyCount; ++i) {
      g_destroyObservers[i](unit, 0, 0, 0);
    }
  }
  kRemove(world, id, a, b);
}

// Replaces the drain's call of the kill handler: thiscall(unit, a, b, c), ret 0Ch, like the handler.
void __fastcall Kill(char* unit, void*, std::uint32_t a, std::uint32_t b, std::uint32_t c) {
  static bool traced = false;
  if (!traced) {
    traced = true;
    uhc::Log(L"hook reached: unit deaths (0x493D8F)");
  }
  for (std::size_t i = 0; i < g_count; ++i) {
    g_observers[i](unit, a, b, c);
  }
  kKill(unit, a, b, c);
}

}  // namespace

namespace uhc {

bool AddDeathObserver(DeathObserver observer) {
  if (g_count == kMaxObservers) {
    Log(L"unit deaths: more than %u observers", static_cast<unsigned>(kMaxObservers));
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("unit deaths", {&sites::kDetonationKillCall}) ||
        !WriteCall(sites::kDetonationKillCall.va, reinterpret_cast<const void*>(&Kill))) {
      return false;
    }
    g_installed = true;
  }
  g_observers[g_count++] = observer;
  return true;
}

bool AddDestroyObserver(DeathObserver observer) {
  if (g_destroyCount == kMaxObservers) {
    Log(L"unit destroys: more than %u observers", static_cast<unsigned>(kMaxObservers));
    return false;
  }
  if (!g_destroyInstalled) {
    if (!VerifyAll("unit destroys", {&sites::kDestroyRemoveCall, &sites::kUnitRemoveHead}) ||
        !WriteCall(sites::kDestroyRemoveCall.va, reinterpret_cast<const void*>(&Destroy))) {
      return false;
    }
    g_destroyInstalled = true;
  }
  g_destroyObservers[g_destroyCount++] = observer;
  return true;
}

}  // namespace uhc
