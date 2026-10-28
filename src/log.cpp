#include "log.h"

#include <windows.h>

#include <cstdarg>
#include <cstdio>
#include <cwchar>

namespace uhc {

void Log(const wchar_t* format, ...) {
  wchar_t path[MAX_PATH];
  const DWORD len = GetModuleFileNameW(nullptr, path, MAX_PATH);
  if (len == 0 || len == MAX_PATH) {
    return;
  }
  wchar_t* slash = std::wcsrchr(path, L'\\');
  if (slash == nullptr) {
    return;
  }
  wcscpy_s(slash + 1, MAX_PATH - (slash + 1 - path), L"UHC.log");

  FILE* file = nullptr;
  if (_wfopen_s(&file, path, L"a, ccs=UTF-8") != 0 || file == nullptr) {
    return;
  }
  va_list args;
  va_start(args, format);
  std::vfwprintf(file, format, args);
  va_end(args);
  std::fputwc(L'\n', file);
  std::fclose(file);
}

}  // namespace uhc

// Called once per hook by TRACE_ONCE (hooks/common.inc), so a test run shows which patched
// code paths the game actually executed.
extern "C" void __stdcall UhcTraceHook(const char* hookName) {
  uhc::Log(L"hook reached: %hs", hookName);
}
