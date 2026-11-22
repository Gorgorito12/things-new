#include "ghostobservers.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcGhostUpdateHook();

namespace {

constexpr std::size_t kMaxObservers = 8;

uhc::GhostObserver g_observers[kMaxObservers] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

extern "C" void __stdcall UhcGhostUpdate(char* visual) {
  for (std::size_t i = 0; i < g_count; ++i) {
    g_observers[i](visual);
  }
}

namespace uhc {

bool AddGhostObserver(GhostObserver observer) {
  if (g_count == kMaxObservers) {
    Log(L"placement ghost: more than %u observers", static_cast<unsigned>(kMaxObservers));
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("placement ghost", {&sites::kAnnexGhostSite}) ||
        !WriteJmp(sites::kAnnexGhostSite.va, reinterpret_cast<const void*>(&UhcGhostUpdateHook), 5)) {
      return false;
    }
    g_installed = true;
  }
  g_observers[g_count++] = observer;
  return true;
}

}  // namespace uhc
