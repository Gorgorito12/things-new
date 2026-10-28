// UHC.dll entry point. A UHC-patched age3y.exe calls UHCMain from its entry-point stub,
// before the game's own startup code runs (see docs/binaries.md).
#include <windows.h>

#include <cstring>
#include <cwchar>
#include <string>

#include "config.h"
#include "features.h"
#include "log.h"

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

// The patched path is relative (default Startup\uhc.cfg). Resolve it against the executable's
// folder rather than the current directory, which a shortcut can point elsewhere.
std::wstring ResolveConfigPath() {
  std::wstring relative(kConfigPath, wcsnlen_s(kConfigPath, kConfigPathMax));
  if (relative.size() >= 2 && (relative[1] == L':' || relative[0] == L'\\')) {
    return relative;
  }
  wchar_t exe[MAX_PATH];
  const DWORD len = GetModuleFileNameW(nullptr, exe, MAX_PATH);
  if (len == 0 || len == MAX_PATH) {
    return relative;
  }
  std::wstring path(exe, len);
  path.resize(path.find_last_of(L'\\') + 1);
  return path + relative;
}

}  // namespace

// MSVC decorates this as _UHCMain@0, the exact name the loader stub passes to GetProcAddress.
extern "C" __declspec(dllexport) void __stdcall UHCMain() {
  if (!IsUhcPatchedAge3y()) {
    uhc::Log(L"UHCMain: host is not a UHC-patched age3y.exe; doing nothing");
    return;
  }
  const std::wstring path = ResolveConfigPath();
  uhc::Config config;
  if (!config.Load(path)) {
    uhc::Log(L"UHCMain: cannot read %ls (error %lu); no features applied", path.c_str(),
             GetLastError());
    return;
  }
  uhc::Log(L"UHCMain: %ls, %zu keys", path.c_str(), config.entries().size());

  int applied = 0;
  int failed = 0;
  for (const uhc::Feature& feature : uhc::kFeatures) {
    switch (feature.apply(config)) {
      case uhc::Outcome::kApplied:
        ++applied;
        uhc::Log(L"%hs: applied", feature.name);
        break;
      case uhc::Outcome::kFailed:
        ++failed;
        uhc::Log(L"%hs: FAILED", feature.name);
        break;
      case uhc::Outcome::kNotConfigured:
        break;
    }
  }
  for (const auto& [key, lines] : config.entries()) {
    bool handled = false;
    for (const char* known : uhc::kHandledKeys) {
      handled = handled || key == known;
    }
    if (!handled) {
      uhc::Log(L"%hs: not implemented yet; ignored", key.c_str());
    }
  }
  uhc::Log(L"UHCMain: %d applied, %d failed", applied, failed);
}

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID) {
  if (reason == DLL_PROCESS_ATTACH) {
    DisableThreadLibraryCalls(module);
  }
  return TRUE;
}
