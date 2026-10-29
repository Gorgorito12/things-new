// multipleInstances [background]: lets this copy of the game run while another copy runs.
// The game allows one running copy per machine: at startup it creates a semaphore named
// "Global\<name>" with a count of 1 (0x55A185) and stops with "only one copy of the game can run
// at a time" when another copy holds it (docs/engine-symbols.md). The exe's IAT entry for
// CreateSemaphoreW is wrapped, and the call from that site gets the name plus a hash of the exe's
// folder: copies in different folders no longer collide, two copies of the same folder still do
// (they would share UHC.log and the other files of the folder).
//
// background: every top-level window of the main thread is created at the bottom of the z-order,
// stays there, and is never activated, so this copy can neither cover another program's window
// nor take its clicks and keys. The game keeps rendering behind the other windows. It is meant for
// test copies driven through perfExecFile; the game also needs config("DontPauseWhenLosingFocus")
// to keep running without focus.
#include <windows.h>

#include <intrin.h>

#include <cstdint>
#include <cstring>
#include <cwchar>
#include <cwctype>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace uhc {
namespace {

// KERNEL32 IAT slot, confirmed by parsing the stock exe's import table (2026-10-28). It holds a
// runtime address, so it is checked against GetProcAddress instead of generated/sites.h.
constexpr std::uint32_t kCreateSemaphoreWSlot = 0x00B843F0;
// Return address of `call [CreateSemaphoreW]` at 0x55A185 (sites::kSingleInstanceSemaphore).
constexpr std::uint32_t kSingleInstanceReturn = 0x0055A18B;
constexpr wchar_t kOldProcProp[] = L"UHC.multipleInstances.WndProc";

using CreateSemaphoreWFn = HANDLE(WINAPI*)(LPSECURITY_ATTRIBUTES, LONG, LONG, LPCWSTR);
CreateSemaphoreWFn g_createSemaphoreW = nullptr;
std::wstring g_suffix;  // "-" + 8 hex digits of the exe folder's hash
HHOOK g_cbtHook = nullptr;

HANDLE WINAPI CreateSemaphoreWHook(LPSECURITY_ATTRIBUTES attributes, LONG initial, LONG maximum,
                                   LPCWSTR name) {
  if (reinterpret_cast<std::uintptr_t>(_ReturnAddress()) == kSingleInstanceReturn && name != nullptr &&
      name[0] != L'\0') {
    const std::wstring renamed = name + g_suffix;
    Log(L"multipleInstances: single-instance semaphore \"%ls\" renamed to \"%ls\"", name, renamed.c_str());
    return g_createSemaphoreW(attributes, initial, maximum, renamed.c_str());
  }
  return g_createSemaphoreW(attributes, initial, maximum, name);
}

// FNV-1a of the lowercase folder of the exe, as 8 hex digits.
std::wstring FolderSuffix() {
  wchar_t exe[MAX_PATH];
  const DWORD len = GetModuleFileNameW(nullptr, exe, MAX_PATH);
  if (len == 0 || len == MAX_PATH) {
    return {};
  }
  std::wstring folder(exe, len);
  folder.resize(folder.find_last_of(L'\\') + 1);
  std::uint32_t hash = 0x811C9DC5;
  for (wchar_t c : folder) {
    hash = (hash ^ static_cast<std::uint32_t>(towlower(c))) * 0x01000193;
  }
  wchar_t suffix[16];
  swprintf_s(suffix, L"-%08X", hash);
  return suffix;
}

// Keeps the window where it was created in the z-order and never activates it.
LRESULT CALLBACK BackgroundWndProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
  const auto old = reinterpret_cast<WNDPROC>(GetPropW(window, kOldProcProp));
  if (message == WM_WINDOWPOSCHANGING) {
    reinterpret_cast<WINDOWPOS*>(lParam)->flags |= SWP_NOZORDER | SWP_NOACTIVATE;
  } else if (message == WM_MOUSEACTIVATE) {
    return MA_NOACTIVATE;
  } else if (message == WM_NCDESTROY) {
    RemovePropW(window, kOldProcProp);
    SetWindowLongPtrW(window, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(old));
  }
  return CallWindowProcW(old, window, message, wParam, lParam);
}

LRESULT CALLBACK CbtHook(int code, WPARAM wParam, LPARAM lParam) {
  if (code == HCBT_CREATEWND) {
    const auto window = reinterpret_cast<HWND>(wParam);
    auto* const create = reinterpret_cast<CBT_CREATEWNDW*>(lParam);
    wchar_t className[64] = L"";
    GetClassNameW(window, className, 64);
    // The system's hidden IME windows are left alone.
    const bool ime = wcscmp(className, L"IME") == 0 || wcsncmp(className, L"MSCTFIME", 8) == 0;
    if ((create->lpcs->style & WS_CHILD) == 0 && create->lpcs->hwndParent != HWND_MESSAGE && !ime) {
      create->hwndInsertAfter = HWND_BOTTOM;
      const LONG_PTR old = GetWindowLongPtrW(window, GWLP_WNDPROC);
      if (old != 0 && SetPropW(window, kOldProcProp, reinterpret_cast<HANDLE>(old))) {
        SetWindowLongPtrW(window, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(&BackgroundWndProc));
      }
      Log(L"multipleInstances background: window of class %ls placed at the bottom, never activated", className);
    }
  } else if (code == HCBT_ACTIVATE) {
    return 1;  // nonzero prevents the activation
  }
  return CallNextHookEx(g_cbtHook, code, wParam, lParam);
}

}  // namespace

Outcome ApplyMultipleInstances(const Config& config) {
  const auto* args = config.First("multipleInstances");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool background = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "background") == 0) {
      background = true;
    } else {
      Log(L"multipleInstances: unknown option \"%hs\" ignored", arg.c_str());
    }
  }
  if (!VerifyAll("multipleInstances", {&sites::kSingleInstanceSemaphore})) {
    return Outcome::kFailed;
  }
  HMODULE kernel32 = GetModuleHandleW(L"kernel32.dll");
  void* real = kernel32 != nullptr ? reinterpret_cast<void*>(GetProcAddress(kernel32, "CreateSemaphoreW"))
                                   : nullptr;
  if (real == nullptr || *reinterpret_cast<void* const*>(kCreateSemaphoreWSlot) != real) {
    Log(L"multipleInstances: IAT slot 0x%08X does not point at CreateSemaphoreW", kCreateSemaphoreWSlot);
    return Outcome::kFailed;
  }
  g_suffix = FolderSuffix();
  if (g_suffix.empty()) {
    Log(L"multipleInstances: could not read the exe path");
    return Outcome::kFailed;
  }
  if (background) {
    // UHCMain runs on the game's main thread, which creates the game's windows.
    g_cbtHook = SetWindowsHookExW(WH_CBT, &CbtHook, nullptr, GetCurrentThreadId());
    if (g_cbtHook == nullptr) {
      Log(L"multipleInstances: SetWindowsHookEx failed (error %lu)", GetLastError());
      return Outcome::kFailed;
    }
  }
  g_createSemaphoreW = reinterpret_cast<CreateSemaphoreWFn>(real);
  if (!WriteDword(kCreateSemaphoreWSlot,
                  static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(&CreateSemaphoreWHook)))) {
    if (g_cbtHook != nullptr) {
      UnhookWindowsHookEx(g_cbtHook);
      g_cbtHook = nullptr;
    }
    return Outcome::kFailed;
  }
  Log(L"multipleInstances: this copy may run beside copies in other folders (semaphore suffix %ls)%ls",
      g_suffix.c_str(), background ? L"; background: windows stay at the bottom and are never activated" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
