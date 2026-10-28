// UHC.dll entry point. A UHC-patched age3y.exe calls UHCMain from its entry-point stub,
// before the game's own startup code runs (see docs/binaries.md).
#include <windows.h>

#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <cwchar>

namespace {

const auto kImageBase = reinterpret_cast<const BYTE*>(0x00400000);
// Stock Steam build header values; the UHC patch leaves both untouched.
constexpr DWORD kTimeDateStamp = 0x49EF86AC;
constexpr DWORD kSizeOfImage = 0x00B22000;
// Strings the UHC patcher writes into .rdata slack.
const auto kLoaderDllName = reinterpret_cast<const char*>(0x00C65016);
const auto kConfigPath = reinterpret_cast<const wchar_t*>(0x00C65083);
constexpr size_t kConfigPathMax = 21;

// The fixed addresses above are only valid inside the patched stock build. Identify the build
// from the PE header first: other 32-bit hosts also load at 0x400000 but don't map 0xC65016.
bool IsUhcPatchedAge3y() {
  if (reinterpret_cast<const BYTE*>(GetModuleHandleW(nullptr)) != kImageBase) {
    return false;
  }
  const auto* dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(kImageBase);
  const auto* nt = reinterpret_cast<const IMAGE_NT_HEADERS32*>(kImageBase + dos->e_lfanew);
  if (nt->FileHeader.TimeDateStamp != kTimeDateStamp ||
      nt->OptionalHeader.SizeOfImage != kSizeOfImage) {
    return false;
  }
  return std::memcmp(kLoaderDllName, "UHC.dll", sizeof("UHC.dll")) == 0;
}

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

}  // namespace

// MSVC decorates this as _UHCMain@0, the exact name the loader stub passes to GetProcAddress.
extern "C" __declspec(dllexport) void __stdcall UHCMain() {
  if (!IsUhcPatchedAge3y()) {
    Log(L"UHCMain: host is not a UHC-patched age3y.exe; doing nothing");
    return;
  }
  const size_t len = wcsnlen_s(kConfigPath, kConfigPathMax);
  Log(L"UHCMain: config path \"%.*s\"", static_cast<int>(len), kConfigPath);
}

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID) {
  if (reason == DLL_PROCESS_ATTACH) {
    DisableThreadLibraryCalls(module);
  }
  return TRUE;
}
