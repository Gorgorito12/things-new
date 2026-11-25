#include "autogatherrate.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" {
void UhcAutoGatherRateHook();  // hooks/autogatherrate_hooks.asm
float g_uhcAgFactor = 1.0f;    // the product the hook multiplies the stock rate by, when the asker returned 1
}

namespace {

constexpr std::size_t kMaxFilters = 4;

uhc::AutoGatherRateFilter g_filters[kMaxFilters] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

// From the hook, at the getter's entry: 1 when a filter changes this rate (the factor in g_uhcAgFactor), else 0.
extern "C" std::int32_t __stdcall UhcAutoGatherRateAsk(const char* unitAction, std::int32_t resource) {
  float factor = 1.0f;
  bool changed = false;
  for (std::size_t i = 0; i < g_count; ++i) {
    changed = g_filters[i](unitAction, resource, &factor) || changed;
  }
  if (!changed) {
    return 0;
  }
  g_uhcAgFactor = factor;
  return 1;
}

namespace uhc {

bool AddAutoGatherRateFilter(const char* name, AutoGatherRateFilter filter) {
  if (g_count == kMaxFilters) {
    Log(L"AutoGather rate: more than %u filters; %hs not added", static_cast<unsigned>(kMaxFilters), name);
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("AutoGather rate", {&sites::kAutoGatherRateEntry})) {
      return false;
    }
    // Replaces push ecx / push ebx / mov ebx,[esp+0Ch] at 0x49EBE4; the hook re-executes them.
    if (!WriteJmp(sites::kAutoGatherRateEntry.va, reinterpret_cast<const void*>(&UhcAutoGatherRateHook), 6)) {
      return false;
    }
    g_installed = true;
  }
  g_filters[g_count++] = filter;
  return true;
}

}  // namespace uhc
