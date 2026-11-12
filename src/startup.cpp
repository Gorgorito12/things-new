#include "startup.h"

#include <windows.h>

#include "config.h"
#include "features.h"
#include "log.h"
#include "menuoptions.h"

namespace uhc {

std::wstring ExeFolder() {
  wchar_t exe[MAX_PATH];
  const DWORD len = GetModuleFileNameW(nullptr, exe, MAX_PATH);
  if (len == 0 || len == MAX_PATH) {
    return {};
  }
  std::wstring path(exe, len);
  path.resize(path.find_last_of(L'\\') + 1);
  return path;
}

namespace {

// Make the exe's folder the working directory before anything else, so a mod starts
// the same way from any shortcut or launcher (with ignoreRegistryPath, the game then reads its
// data from that folder). Mods rely on this, so keep it.
void UseExeFolderAsWorkingDirectory() {
  const std::wstring folder = ExeFolder();
  if (!folder.empty() && SetCurrentDirectoryW(folder.c_str())) {
    Log(L"UHCMain: working directory %ls", folder.c_str());
  } else {
    Log(L"UHCMain: cannot make the exe's folder the working directory (error %lu)", GetLastError());
  }
}

}  // namespace

void ApplyFeatures(const std::wstring& path) {
  UseExeFolderAsWorkingDirectory();
  Config config;
  if (!config.Load(path)) {
    Log(L"UHCMain: cannot read %ls (error %lu); no features applied", path.c_str(), GetLastError());
    return;
  }
  Log(L"UHCMain: %ls, %zu keys", path.c_str(), config.entries().size());
  // menuOptions: the keys that follow the options menu are kept, added or removed by the stored choice first, so
  // every key below sees only the cfg it applies with.
  ApplyMenuSwitches(config);

  int applied = 0;
  int failed = 0;
  for (const Feature& feature : kFeatures) {
    switch (feature.apply(config)) {
      case Outcome::kApplied:
        ++applied;
        Log(L"%hs: applied", feature.name);
        break;
      case Outcome::kFailed:
        ++failed;
        Log(L"%hs: FAILED", feature.name);
        break;
      case Outcome::kNotConfigured:
        break;
    }
  }
  for (const auto& [key, lines] : config.entries()) {
    bool handled = false;
    for (const char* known : kHandledKeys) {
      handled = handled || key == known;
    }
    if (!handled) {
      Log(L"%hs: not implemented yet; ignored", key.c_str());
    }
  }
  Log(L"UHCMain: %d applied, %d failed", applied, failed);
}

}  // namespace uhc
