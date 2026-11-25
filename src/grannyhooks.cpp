#include "grannyhooks.h"

#include <windows.h>

#include <cstdint>

#include "log.h"
#include "patch.h"

namespace uhc {
namespace {

// IAT slot of granny2!GrannySampleModelAnimations (docs/engine-symbols.md, "Turrets, facing and the Granny pose"). It
// holds a runtime address, so it is checked against GetProcAddress instead of generated/sites.h.
constexpr std::uint32_t kSlot = 0x00B847AC;
constexpr int kMaxObservers = 4;

using SampleFn = void(__stdcall*)(void* modelInstance, int first, int count, void* localPose);

SampleFn g_stock = nullptr;
bool g_wrapped = false;
GrannySampleObserver g_observers[kMaxObservers] = {};
int g_observerCount = 0;

std::uint32_t Address(const void* p) { return static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(p)); }

void __stdcall SampleHook(void* modelInstance, int first, int count, void* localPose) {
  g_stock(modelInstance, first, count, localPose);
  for (int i = 0; i < g_observerCount; ++i) {
    g_observers[i](modelInstance, first, count, localPose);
  }
}

}  // namespace

void* GrannyExport(const char* name, const char* who) {
  HMODULE granny = GetModuleHandleW(L"granny2.dll");
  void* p = granny != nullptr ? reinterpret_cast<void*>(GetProcAddress(granny, name)) : nullptr;
  if (p == nullptr) {
    Log(L"%hs: granny2.dll has no %hs", who, name);
  }
  return p;
}

bool AddGrannySampleObserver(GrannySampleObserver observer, const char* who) {
  if (g_observerCount == kMaxObservers) {
    Log(L"%hs: too many Granny sample observers", who);
    return false;
  }
  if (!g_wrapped) {
    void* real = GrannyExport("_GrannySampleModelAnimations@16", who);
    if (real == nullptr || *reinterpret_cast<void* const*>(kSlot) != real) {
      Log(L"%hs: IAT slot 0x%08X does not point at granny2!GrannySampleModelAnimations", who, kSlot);
      return false;
    }
    g_stock = reinterpret_cast<SampleFn>(real);
    if (!WriteDword(kSlot, Address(reinterpret_cast<void*>(&SampleHook)))) {
      return false;
    }
    g_wrapped = true;
  }
  g_observers[g_observerCount++] = observer;
  return true;
}

}  // namespace uhc
