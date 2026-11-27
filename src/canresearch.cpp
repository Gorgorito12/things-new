// The head of the can-research test 0x4C6968 (push ebp / mov ebp,[esp+8], 5 B) goes to UhcCanResearchHook
// (hooks/canresearch_hooks.asm), which asks UhcCanResearchRefused and either answers false or runs the stock test.
#include "canresearch.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" {
std::int32_t g_uhcCanResearchFilters = 0;  // the hook calls UhcCanResearchRefused only when there is a filter
void UhcCanResearchHook();
}

namespace {

constexpr std::size_t kMaxFilters = 4;

uhc::CanResearchFilter g_filters[kMaxFilters] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

extern "C" bool __stdcall UhcCanResearchRefused(const char* status, const char* unit) {
  if (status == nullptr) {
    return false;
  }
  for (std::size_t i = 0; i < g_count; ++i) {
    if (g_filters[i](status, unit)) {
      return true;
    }
  }
  return false;
}

namespace uhc {

bool AddCanResearchFilter(const char* feature, CanResearchFilter refuse) {
  if (g_count == kMaxFilters) {
    Log(L"can-research test: more than %u keys", static_cast<unsigned>(kMaxFilters));
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll(feature, {&sites::kCanResearchHead}) ||
        !WriteJmp(sites::kCanResearchHead.va, reinterpret_cast<const void*>(&UhcCanResearchHook), 5)) {
      return false;
    }
    g_installed = true;
  }
  g_filters[g_count++] = refuse;
  g_uhcCanResearchFilters = static_cast<std::int32_t>(g_count);
  return true;
}

}  // namespace uhc
