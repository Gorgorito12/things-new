#include "d3d9hooks.h"

#include <cstdint>

#include "log.h"
#include "patch.h"

namespace uhc {
namespace {

// IAT slot of d3d9!Direct3DCreate9 (docs/engine-symbols.md, "IAT slots"). It holds a runtime address, so it is
// checked against GetProcAddress instead of generated/sites.h.
constexpr std::uint32_t kSlot = 0x00B84164;
constexpr int kCreateDeviceIndex = 16;  // IDirect3D9
constexpr int kResetIndex = 16;         // IDirect3DDevice9
constexpr int kPresentIndex = 17;       // IDirect3DDevice9
constexpr int kMaxObservers = 4;

using CreateDeviceFn = HRESULT(STDMETHODCALLTYPE*)(IDirect3D9*, UINT, D3DDEVTYPE, HWND, DWORD,
                                                   D3DPRESENT_PARAMETERS*, IDirect3DDevice9**);
using ResetFn = HRESULT(STDMETHODCALLTYPE*)(IDirect3DDevice9*, D3DPRESENT_PARAMETERS*);
using PresentFn = HRESULT(STDMETHODCALLTYPE*)(IDirect3DDevice9*, const RECT*, const RECT*, HWND, const RGNDATA*);

bool g_stockChecked = false;
Direct3DCreate9Fn g_stock = nullptr;
Direct3DCreate9Fn g_create = nullptr;   // what the game gets in the end: stock, or the replacement
bool g_wrapped = false;                 // the slot holds Direct3DCreate9Hook

D3D9Observer g_observers[kMaxObservers] = {};
int g_observerCount = 0;

CreateDeviceFn g_createDevice = nullptr;
ResetFn g_reset = nullptr;
PresentFn g_present = nullptr;

std::uint32_t Address(const void* p) { return static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(p)); }

// Points vtable entry `index` of a COM object at `hook`, keeping the original. A d3d9 implementation shares one
// vtable between all objects of a class, so a second object finds the hook already in place.
template <typename Fn>
bool HookVtable(void* object, int index, Fn hook, Fn* original) {
  void** entry = *reinterpret_cast<void***>(object) + index;
  if (*entry == reinterpret_cast<void*>(hook)) {
    return true;
  }
  *original = reinterpret_cast<Fn>(*entry);
  return WriteDword(Address(entry), Address(reinterpret_cast<void*>(hook)));
}

HRESULT STDMETHODCALLTYPE PresentHook(IDirect3DDevice9* device, const RECT* source, const RECT* dest, HWND window,
                                      const RGNDATA* dirty) {
  for (int i = 0; i < g_observerCount; ++i) {
    if (g_observers[i].beforePresent != nullptr) {
      g_observers[i].beforePresent();
    }
  }
  const HRESULT hr = g_present(device, source, dest, window, dirty);
  for (int i = 0; i < g_observerCount; ++i) {
    if (g_observers[i].afterPresent != nullptr) {
      g_observers[i].afterPresent(hr);
    }
  }
  return hr;
}

HRESULT STDMETHODCALLTYPE ResetHook(IDirect3DDevice9* device, D3DPRESENT_PARAMETERS* pp) {
  const HRESULT hr = g_reset(device, pp);
  for (int i = 0; i < g_observerCount; ++i) {
    if (g_observers[i].afterReset != nullptr) {
      g_observers[i].afterReset(pp, hr);
    }
  }
  return hr;
}

HRESULT STDMETHODCALLTYPE CreateDeviceHook(IDirect3D9* d3d, UINT adapter, D3DDEVTYPE type, HWND focus, DWORD flags,
                                           D3DPRESENT_PARAMETERS* pp, IDirect3DDevice9** device) {
  const HRESULT hr = g_createDevice(d3d, adapter, type, focus, flags, pp, device);
  IDirect3DDevice9* created = SUCCEEDED(hr) && device != nullptr ? *device : nullptr;
  if (created != nullptr && (!HookVtable(created, kPresentIndex, &PresentHook, &g_present) ||
                             !HookVtable(created, kResetIndex, &ResetHook, &g_reset))) {
    Log(L"d3d9 hooks: could not hook the device vtable; no Present or Reset observers");
  }
  for (int i = 0; i < g_observerCount; ++i) {
    if (g_observers[i].afterCreateDevice != nullptr) {
      g_observers[i].afterCreateDevice(adapter, type, flags, pp, hr, created);
    }
  }
  return hr;
}

IDirect3D9* WINAPI Direct3DCreate9Hook(UINT sdkVersion) {
  IDirect3D9* d3d = g_create(sdkVersion);
  if (d3d != nullptr && !HookVtable(d3d, kCreateDeviceIndex, &CreateDeviceHook, &g_createDevice)) {
    Log(L"d3d9 hooks: could not hook IDirect3D9::CreateDevice");
  }
  return d3d;
}

}  // namespace

Direct3DCreate9Fn StockDirect3DCreate9(const char* who) {
  if (!g_stockChecked) {
    g_stockChecked = true;
    HMODULE d3d9 = GetModuleHandleW(L"d3d9.dll");
    void* real = d3d9 != nullptr ? reinterpret_cast<void*>(GetProcAddress(d3d9, "Direct3DCreate9")) : nullptr;
    if (real != nullptr && *reinterpret_cast<void* const*>(kSlot) == real) {
      g_stock = reinterpret_cast<Direct3DCreate9Fn>(real);
      g_create = g_stock;
    }
  }
  if (g_stock == nullptr) {
    Log(L"%hs: IAT slot 0x%08X does not point at d3d9!Direct3DCreate9", who, kSlot);
  }
  return g_stock;
}

bool ReplaceDirect3DCreate9(Direct3DCreate9Fn create, const char* who) {
  if (StockDirect3DCreate9(who) == nullptr) {
    return false;
  }
  if (g_wrapped || g_create != g_stock || create == nullptr) {
    Log(L"%hs: Direct3DCreate9 is already wrapped or replaced", who);
    return false;
  }
  if (!WriteDword(kSlot, Address(reinterpret_cast<void*>(create)))) {
    return false;
  }
  g_create = create;
  return true;
}

bool AddD3D9Observer(const D3D9Observer& observer, const char* who) {
  if (StockDirect3DCreate9(who) == nullptr) {
    return false;
  }
  if (g_observerCount == kMaxObservers) {
    Log(L"%hs: too many Direct3D observers", who);
    return false;
  }
  if (!g_wrapped) {
    if (*reinterpret_cast<void* const*>(kSlot) != reinterpret_cast<void*>(g_create)) {
      Log(L"%hs: IAT slot 0x%08X was changed by another DLL", who, kSlot);
      return false;
    }
    if (!WriteDword(kSlot, Address(reinterpret_cast<void*>(&Direct3DCreate9Hook)))) {
      return false;
    }
    g_wrapped = true;
  }
  g_observers[g_observerCount++] = observer;
  return true;
}

}  // namespace uhc
