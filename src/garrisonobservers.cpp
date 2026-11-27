#include "garrisonobservers.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcGarrisonEnterHook();

namespace {

constexpr std::size_t kMaxObservers = 8;

uhc::GarrisonObserver g_observers[kMaxObservers] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

// From the hook at 0x9C26E1: EDI = the container, ESI = the unit that just entered it.
extern "C" void __stdcall UhcGarrisonDispatch(char* container, char* unit) {
  if (container == nullptr || unit == nullptr) {
    return;
  }
  for (std::size_t i = 0; i < g_count; ++i) {
    g_observers[i](container, unit);
  }
}

namespace uhc {

bool AddGarrisonObserver(GarrisonObserver observer, const char* key) {
  if (g_count == kMaxObservers) {
    Log(L"garrison entries: more than %u observers (%hs)", static_cast<unsigned>(kMaxObservers), key);
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("garrison entries", {&sites::kGarrisonEnterTail, &sites::kGarrisonLoadHead}) ||
        !WriteJmp(sites::kGarrisonEnterTail.va, reinterpret_cast<const void*>(&UhcGarrisonEnterHook), 7)) {
      return false;
    }
    g_installed = true;
  }
  g_observers[g_count++] = observer;
  return true;
}

}  // namespace uhc
