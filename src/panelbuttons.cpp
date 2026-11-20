#include "panelbuttons.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcPanelButtonHook();

namespace {

constexpr std::size_t kMaxFilters = 4;
uhc::PanelButtonFilter g_filters[kMaxFilters] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

extern "C" void __stdcall UhcPanelButton(char* frame) {
  const uhc::PanelButton button{frame};
  for (std::size_t i = 0; i < g_count; ++i) {
    g_filters[i](button);
  }
}

namespace uhc {

bool AddPanelButtonFilter(PanelButtonFilter filter) {
  if (g_count == kMaxFilters) {
    Log(L"command panel buttons: no room for another filter");
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("command panel buttons", {&sites::kNpButton}) ||
        !WriteJmp(sites::kNpButton.va, reinterpret_cast<const void*>(&UhcPanelButtonHook), 7)) {
      return false;
    }
    g_installed = true;
  }
  g_filters[g_count++] = filter;
  return true;
}

}  // namespace uhc
