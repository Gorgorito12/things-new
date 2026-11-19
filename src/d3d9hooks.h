// The game's Direct3D 9 entry points, owned here for every key that needs them: the IAT slot 0xB84164 of
// d3d9!Direct3DCreate9 (the exe's only d3d9 import, bound at load time, no delay load), then
// IDirect3D9::CreateDevice and IDirect3DDevice9::Reset / Present through their vtables. One owner, so two keys
// never write the same slot or vtable entry twice.
//
// rendererOption may first replace the Direct3DCreate9 the game gets (a D3D9 implementation loaded from another
// folder); the observers (perfStats, rendererOption's first-frame check) then see whichever device that creates.
// Neither changes the game's calls or their arguments.
#pragma once

#include <windows.h>

#include <d3d9.h>

namespace uhc {

using Direct3DCreate9Fn = IDirect3D9*(WINAPI*)(UINT);

// The Direct3DCreate9 the exe imports: what the IAT slot held when this was first called, checked against
// GetProcAddress of the d3d9.dll loaded with the exe. nullptr (logged with `who`) if another DLL changed the slot.
Direct3DCreate9Fn StockDirect3DCreate9(const char* who);

// The Direct3DCreate9 the game gets in the end, in place of the stock one. Once, before any AddD3D9Observer
// (rendererOption is before perfStats in kFeatures). False (logged) if the slot is not stock.
bool ReplaceDirect3DCreate9(Direct3DCreate9Fn create, const char* who);

// Each callback may be null. They run on the thread that makes the call (the game's main thread), in the order
// the observers were added.
struct D3D9Observer {
  void (*afterCreateDevice)(UINT adapter, D3DDEVTYPE type, DWORD flags, const D3DPRESENT_PARAMETERS* pp,
                            HRESULT hr, IDirect3DDevice9* device);
  void (*afterReset)(const D3DPRESENT_PARAMETERS* pp, HRESULT hr);
  void (*beforePresent)();
  void (*afterPresent)(HRESULT hr);
};

// Adds an observer. The first one points the IAT slot at the wrapper. False (logged with `who`) if the slot is
// neither stock nor what ReplaceDirect3DCreate9 wrote.
bool AddD3D9Observer(const D3D9Observer& observer, const char* who);

}  // namespace uhc
