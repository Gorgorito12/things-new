#include "rofreads.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" {
void UhcRofWaitAHook();  // hooks/rofreads_hooks.asm
void UhcRofWaitBHook();
void UhcRofWaitCHook();
void UhcRofShotHook();
void UhcRofAnimHook();

// Above 0 while some filter's gate is on: the hooks skip the call otherwise.
std::int32_t g_uhcRofGate = 0;
}

namespace {

constexpr std::size_t kMaxFilters = 4;

struct Slot {
  uhc::RofFilter filter;
  bool gate;
};

Slot g_filters[kMaxFilters] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

extern "C" std::int32_t __stdcall UhcRofRead(const char* unitAction, std::int32_t rof, std::int32_t read) {
  if (unitAction == nullptr || rof <= 0) {
    return rof;
  }
  for (std::size_t i = 0; i < g_count; ++i) {
    if (g_filters[i].gate) {
      rof = g_filters[i].filter(unitAction, rof, static_cast<uhc::RofRead>(read));
      if (rof < 1) {
        rof = 1;
      }
    }
  }
  return rof;
}

namespace uhc {

void SetRofGate(RofFilter filter, bool on) {
  std::int32_t open = 0;
  for (std::size_t i = 0; i < g_count; ++i) {
    if (g_filters[i].filter == filter) {
      g_filters[i].gate = on;
    }
    open += g_filters[i].gate ? 1 : 0;
  }
  g_uhcRofGate = open;
}

bool AddRofFilter(RofFilter filter, const char* feature) {
  if (g_count == kMaxFilters) {
    Log(L"%hs: more than %u ROF filters", feature, static_cast<unsigned>(kMaxFilters));
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll(feature, {&sites::kRofWaitA, &sites::kRofWaitB, &sites::kRofWaitC, &sites::kRofShot,
                             &sites::kRofAnim, &sites::kRofDelay})) {
      return false;
    }
    // mov r,[r+34h] / test r,r (5 B) at 0x48A821, 0x48A99A and 0x48EA0C; mov eax,[eax+34h] / cmp eax,ebx (5 B)
    // at 0x48F8B5; mov ebx,[eax+34h] / mov eax,[esi+6Ch] (6 B) at 0x4A1189.
    if (!WriteJmp(0x0048A821, reinterpret_cast<const void*>(&UhcRofWaitAHook), 5) ||
        !WriteJmp(0x0048A99A, reinterpret_cast<const void*>(&UhcRofWaitBHook), 5) ||
        !WriteJmp(0x0048EA0C, reinterpret_cast<const void*>(&UhcRofWaitCHook), 5) ||
        !WriteJmp(0x0048F8B5, reinterpret_cast<const void*>(&UhcRofShotHook), 5) ||
        !WriteJmp(0x004A1189, reinterpret_cast<const void*>(&UhcRofAnimHook), 6)) {
      return false;
    }
    g_installed = true;
  }
  g_filters[g_count++] = Slot{filter, false};
  return true;
}

}  // namespace uhc
