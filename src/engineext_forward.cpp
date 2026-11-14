// The exports of dinput8.dll, for engineext.cpp: each one looks up the system's function on its first
// call and goes on to it, so nothing is loaded under the loader lock. engineext.def gives them their names.
#include <windows.h>

#include <string>

namespace {

constexpr const char* kNames[] = {"DirectInput8Create", "DllCanUnloadNow", "DllGetClassObject", "DllRegisterServer", "DllUnregisterServer", "GetdfDIJoystick"};

FARPROC g_functions[sizeof(kNames) / sizeof(kNames[0])] = {};

}  // namespace

// By full path: this file is the dinput8.dll a plain name would find.
extern "C" FARPROC __stdcall EngineExtForward(int index) {
  if (g_functions[index] == nullptr) {
    wchar_t folder[MAX_PATH];
    const UINT length = GetSystemDirectoryW(folder, MAX_PATH);
    const std::wstring path = std::wstring(folder, length) + L"\\dinput8.dll";
    HMODULE real = LoadLibraryW(path.c_str());
    FARPROC function = real != nullptr ? GetProcAddress(real, kNames[index]) : nullptr;
    if (function == nullptr) {
      ExitProcess(1);
    }
    g_functions[index] = function;
  }
  return g_functions[index];
}

#define FORWARD(index, name)                                   \
  extern "C" __declspec(naked) void Forward##name() {          \
    __asm push index __asm call EngineExtForward __asm jmp eax \
  }

FORWARD(0, DirectInput8Create)
FORWARD(1, DllCanUnloadNow)
FORWARD(2, DllGetClassObject)
FORWARD(3, DllRegisterServer)
FORWARD(4, DllUnregisterServer)
FORWARD(5, GetdfDIJoystick)
