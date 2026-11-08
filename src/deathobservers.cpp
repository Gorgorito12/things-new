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

// Replaces the drain's call of the kill handler: thiscall(unit, a, b, c), ret 0Ch, like the handler.
void __fastcall Kill(char* unit, void*, std::uint32_t a, std::uint32_t b, std::uint32_t c) {
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

}  // namespace uhc
