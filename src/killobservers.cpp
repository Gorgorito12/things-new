#include "killobservers.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcKillObserversHook();  // hooks/killobservers_hooks.asm

namespace {

constexpr std::size_t kMaxObservers = 8;

uhc::KillObserver g_observers[kMaxObservers] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

// From the hook, for every killing blow.
extern "C" void __stdcall UhcKillDispatch(char* attacker, char* attackerPlayer, std::int32_t attackerProto,
                                          char* victim) {
  if (victim == nullptr) {
    return;
  }
  for (std::size_t i = 0; i < g_count; ++i) {
    g_observers[i](attacker, attackerPlayer, attackerProto, victim);
  }
}

namespace uhc {

bool AddKillObserver(KillObserver observer) {
  if (g_count == kMaxObservers) {
    Log(L"killing blows: more than %u observers", static_cast<unsigned>(kMaxObservers));
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("killing blows", {&sites::kVeterancyKillPath}) ||
        !WriteJmp(sites::kVeterancyKillPath.va, reinterpret_cast<const void*>(&UhcKillObserversHook), 6)) {
      return false;
    }
    g_installed = true;
  }
  g_observers[g_count++] = observer;
  return true;
}

}  // namespace uhc
