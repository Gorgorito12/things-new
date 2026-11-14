// rendererOption [vulkan|dx9] [folder=<dir>] [log] [conf=<DXVK options>]: a "Renderer" entry for the options menu.
// Choosing Vulkan makes the next start load DXVK's d3d9.dll from <dir> (default dxvk\ next to the exe) in place of
// the system's Direct3D 9. Display only: nothing of the simulation changes.
//
// The menu: the option OptionRenderer of the options menu's registry (src/menuoptions.h), with nothing added to the
// game's option table or the profile. The choice is kept in kOptionsFile (uhc-options.cfg next to the log) as the line
// `renderer dx9|vulkan`. The value is the dropdown's index: 0 = the first <value> (DirectX 9), 1 = the second
// (Vulkan).
//
// The switch, at start (before the game's entry point, before Direct3DCreate9 is ever called): with Vulkan chosen,
// the key sets DXVK_LOG_PATH, loads
// <dir>\d3d9.dll by its full path and gives the game its Direct3DCreate9 through the shared IAT slot owner
// (src/d3d9hooks.h). When the game calls it, after every key has applied, the wrapper sets DXVK_CONFIG: nothing with
// fastVertexFill on (it removes the read-back the option works around), "d3d9.cachedWriteOnlyBuffers = True" without
// it; `conf=` overrides both. The exe's own d3d9 import (the system's, or whatever d3d9.dll sits next to the exe) stays
// loaded and unused.
//
// The safety net: a missing or unloadable DLL, a missing export, or a null from its Direct3DCreate9 fall back to the
// stock Direct3DCreate9. A start marker is written before Vulkan is used and deleted at the first Present; if it is
// still there at the next start, that start crashed or hung before its first frame, and the key stores and uses
// DirectX 9.
#include <windows.h>

#include <cctype>
#include <cstdint>
#include <string>
#include <vector>

#include "../d3d9hooks.h"
#include "../features.h"
#include "../log.h"
#include "../menuoptions.h"
#include "../startup.h"

namespace uhc {
namespace {

constexpr wchar_t kOptionName[] = L"OptionRenderer";
constexpr int kDx9 = 0;
constexpr int kVulkan = 1;
constexpr char kDefaultConf[] = "d3d9.cachedWriteOnlyBuffers = True";
constexpr wchar_t kMarkerName[] = L"uhc-vulkan-start.tmp";

bool g_log = false;
std::wstring g_markerPath;
Direct3DCreate9Fn g_stockCreate = nullptr;
Direct3DCreate9Fn g_dxvkCreate = nullptr;
bool g_firstFrameSeen = false;
bool g_confGiven = false;     // conf= on the key's line
std::string g_conf;           // its text
bool g_envPreset = false;     // DXVK_CONFIG was in the environment before the game started
bool g_confDecided = false;

const wchar_t* ChoiceName(int choice) { return choice == kVulkan ? L"Vulkan" : L"DirectX 9"; }

std::wstring Widen(const std::string& text) {
  if (text.empty()) {
    return {};
  }
  const int size = MultiByteToWideChar(CP_ACP, 0, text.data(), static_cast<int>(text.size()), nullptr, 0);
  std::wstring out(size, L'\0');
  MultiByteToWideChar(CP_ACP, 0, text.data(), static_cast<int>(text.size()), out.data(), size);
  return out;
}

bool Exists(const std::wstring& path) { return GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES; }

std::string Lower(std::string s) {
  for (char& c : s) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  return s;
}

// DXVK reads DXVK_CONFIG when its Direct3DCreate9 builds its instance (Config::getUserConfig), so the options are
// chosen here, after every key has applied: with fastVertexFill on, the read-back loop that
// d3d9.cachedWriteOnlyBuffers works around no longer runs, and DXVK gets no options; without it (off, failed or
// `verify`), it gets the option. `conf=` overrides both; a DXVK_CONFIG of the player's environment is left alone.
void DecideDxvkConfig() {
  if (g_confDecided) {
    return;
  }
  g_confDecided = true;
  if (g_envPreset) {
    Log(L"rendererOption: DXVK_CONFIG is already set in the environment; left as it is");
    return;
  }
  std::string conf;
  const wchar_t* why;
  if (g_confGiven) {
    conf = g_conf;
    why = L"conf= of the key";
  } else if (FastVertexFillActive()) {
    why = L"fastVertexFill is on, so the read-back that d3d9.cachedWriteOnlyBuffers avoids does not run";
  } else {
    conf = kDefaultConf;
    why = L"fastVertexFill is off, failed or in verify mode";
  }
  if (conf.empty()) {
    SetEnvironmentVariableW(L"DXVK_CONFIG", nullptr);
    Log(L"rendererOption: no DXVK options (%ls)", why);
  } else {
    SetEnvironmentVariableW(L"DXVK_CONFIG", Widen(conf).c_str());
    Log(L"rendererOption: DXVK_CONFIG=%hs (%ls)", conf.c_str(), why);
  }
}

// What the game gets in place of Direct3DCreate9 when Vulkan is used.
IDirect3D9* WINAPI RendererCreate9(UINT sdkVersion) {
  DecideDxvkConfig();
  IDirect3D9* d3d = g_dxvkCreate(sdkVersion);
  if (d3d != nullptr) {
    Log(L"rendererOption: Direct3DCreate9(0x%X) answered by DXVK", sdkVersion);
    return d3d;
  }
  Log(L"rendererOption: DXVK's Direct3DCreate9 returned null (no Vulkan device? see its log); falling back to "
      L"DirectX 9");
  return g_stockCreate(sdkVersion);
}

void AfterCreateDevice(UINT, D3DDEVTYPE, DWORD, const D3DPRESENT_PARAMETERS*, HRESULT hr, IDirect3DDevice9*) {
  Log(L"rendererOption: CreateDevice -> hr 0x%08lX", static_cast<unsigned long>(hr));
}

void AfterPresent(HRESULT hr) {
  if (g_firstFrameSeen) {
    return;
  }
  g_firstFrameSeen = true;
  const BOOL deleted = DeleteFileW(g_markerPath.c_str());
  Log(L"rendererOption: first frame presented (hr 0x%08lX); start marker %ls", static_cast<unsigned long>(hr),
      deleted ? L"removed" : L"was not there");
}

// Loads DXVK and makes it the game's Direct3DCreate9. False (logged) if the game stays on DirectX 9.
bool UseVulkan(const std::wstring& folder) {
  g_stockCreate = StockDirect3DCreate9("rendererOption");
  if (g_stockCreate == nullptr) {
    Log(L"rendererOption: Vulkan not used (another DLL holds the Direct3DCreate9 import)");
    return false;
  }
  const std::wstring dll = folder + L"d3d9.dll";
  if (!Exists(dll)) {
    Log(L"rendererOption: %ls not found; using DirectX 9", dll.c_str());
    return false;
  }
  wchar_t existing[2];
  g_envPreset = !(GetEnvironmentVariableW(L"DXVK_CONFIG", existing, 2) == 0 && GetLastError() == ERROR_ENVVAR_NOT_FOUND);
  if (GetEnvironmentVariableW(L"DXVK_LOG_PATH", existing, 2) == 0 && GetLastError() == ERROR_ENVVAR_NOT_FOUND) {
    std::wstring logPath = folder;
    if (!logPath.empty() && logPath.back() == L'\\') {
      logPath.pop_back();
    }
    SetEnvironmentVariableW(L"DXVK_LOG_PATH", logPath.c_str());
  }
  // A broken DLL or a missing dependency fails here with an error code, never with a Windows dialog.
  DWORD oldMode = 0;
  SetThreadErrorMode(SEM_FAILCRITICALERRORS | SEM_NOOPENFILEERRORBOX, &oldMode);
  HMODULE module = LoadLibraryExW(dll.c_str(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
  const DWORD loadError = GetLastError();
  SetThreadErrorMode(oldMode, nullptr);
  if (module == nullptr) {
    Log(L"rendererOption: cannot load %ls (error %lu); using DirectX 9", dll.c_str(), loadError);
    return false;
  }
  g_dxvkCreate = reinterpret_cast<Direct3DCreate9Fn>(GetProcAddress(module, "Direct3DCreate9"));
  if (g_dxvkCreate == nullptr) {
    Log(L"rendererOption: %ls has no Direct3DCreate9; using DirectX 9", dll.c_str());
    FreeLibrary(module);
    return false;
  }
  if (!ReplaceDirect3DCreate9(&RendererCreate9, "rendererOption")) {
    FreeLibrary(module);
    return false;
  }
  HANDLE marker = CreateFileW(g_markerPath.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL,
                              nullptr);
  if (marker != INVALID_HANDLE_VALUE) {
    CloseHandle(marker);
  }
  if (!AddD3D9Observer({&AfterCreateDevice, nullptr, nullptr, &AfterPresent}, "rendererOption")) {
    Log(L"rendererOption: no first-frame check; the start marker stays");
  }

  const auto* dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(GetModuleHandleW(nullptr));
  const auto* nt = reinterpret_cast<const IMAGE_NT_HEADERS32*>(reinterpret_cast<const BYTE*>(dos) + dos->e_lfanew);
  const bool laa = (nt->FileHeader.Characteristics & IMAGE_FILE_LARGE_ADDRESS_AWARE) != 0;
  Log(L"rendererOption: Vulkan: %ls loaded at 0x%08X; the game's Direct3DCreate9 is DXVK's%ls", dll.c_str(),
      static_cast<unsigned>(reinterpret_cast<std::uintptr_t>(module)),
      laa ? L"" : L" (the exe is not large-address-aware: DXVK adds about 250 MB of address space)");
  return true;
}

}  // namespace

Outcome ApplyRendererOption(const Config& config) {
  const Config::Args* args = config.First("rendererOption");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  int initial = kDx9;
  std::wstring folder = L"dxvk";
  for (std::size_t i = 0; i < args->size(); ++i) {
    const std::string& arg = (*args)[i];
    const std::string lower = Lower(arg);
    if (lower == "vulkan") {
      initial = kVulkan;
    } else if (lower == "dx9") {
      initial = kDx9;
    } else if (lower == "log") {
      g_log = true;
    } else if (lower.rfind("folder=", 0) == 0 && arg.size() > 7) {
      folder = Widen(arg.substr(7));
    } else if (lower.rfind("conf=", 0) == 0) {
      g_confGiven = true;
      g_conf = arg.substr(5);  // the rest of the line: DXVK options may hold spaces; empty: none
      for (std::size_t j = i + 1; j < args->size(); ++j) {
        g_conf += " " + (*args)[j];
      }
      break;
    } else {
      Log(L"rendererOption: unknown argument %hs (expected vulkan, dx9, folder=<dir>, log, conf=<options>)",
          arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!folder.empty() && folder.back() != L'\\' && folder.back() != L'/') {
    folder += L'\\';
  }
  if (folder.size() < 2 || (folder[1] != L':' && folder[0] != L'\\')) {
    folder = ExeFolder() + folder;
  }

  const int slot = AddMenuOption({"rendererOption", kOptionName, "renderer", {"dx9", "vulkan"},
                                  {L"DirectX 9", L"Vulkan"}, g_log});
  if (slot < 0) {
    return Outcome::kFailed;
  }
  const std::wstring optionsPath = MenuOptionsPath();
  g_markerPath = optionsPath.substr(0, optionsPath.find_last_of(L'\\') + 1) + kMarkerName;

  int choice = MenuOptionStored(slot);
  Log(L"rendererOption: %ls: %ls", optionsPath.c_str(), choice < 0 ? L"no choice stored yet" : ChoiceName(choice));
  if (choice < 0) {
    choice = initial;
  }
  bool store = false;
  if (Exists(g_markerPath)) {
    DeleteFileW(g_markerPath.c_str());
    Log(L"rendererOption: the last start with Vulkan did not present a frame (marker %ls); DirectX 9 stored and "
        L"used",
        g_markerPath.c_str());
    choice = kDx9;
    store = true;
  }
  SetMenuOptionValue(slot, choice, store);

  if (choice == kVulkan) {
    UseVulkan(folder);
  } else {
    Log(L"rendererOption: DirectX 9");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
