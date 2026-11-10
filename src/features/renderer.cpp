// rendererOption [vulkan|dx9] [folder=<dir>] [log] [conf=<DXVK options>]: a "Renderer" entry for the options menu.
// Choosing Vulkan makes the next start load DXVK's d3d9.dll from <dir> (default dxvk\ next to the exe) in place of
// the system's Direct3D 9. Display only: nothing of the simulation changes.
//
// The menu. data\options.xml names an option variable per field; the screen resolves the name through 0x932264 on
// the "GameOptions" settings object, then reads the value through 0x553028 (type) and 0x402E6A (int) and writes it on
// Apply through 0x518AE0. That object holds a fixed list of 93 options (0xD91778, stride 0x88), saved in the profile.
// The key adds a 94th without touching that list or the profile: a name lookup that finds nothing answers kVirtualId
// for OptionRenderer, and the three accessors' out-of-range paths serve that ID from this DLL
// (src/hooks/rendereroption_hooks.asm). The choice is kept in kOptionsFile (uhc-options.cfg next to the log). The
// value is the dropdown's index: 0 = the first <value> (DirectX 9), 1 = the second (Vulkan).
//
// The switch, at start (before the game's entry point, before Direct3DCreate9 is ever called): with Vulkan chosen,
// the key sets DXVK_CONFIG (default "d3d9.cachedWriteOnlyBuffers = True", or `conf=`) and DXVK_LOG_PATH, loads
// <dir>\d3d9.dll by its full path and gives the game its Direct3DCreate9 through the shared IAT slot owner
// (src/d3d9hooks.h). The exe's own d3d9 import (the system's, or whatever d3d9.dll sits next to the exe) stays
// loaded and unused.
//
// The safety net: a missing or unloadable DLL, a missing export, or a null from its Direct3DCreate9 fall back to the
// stock Direct3DCreate9. A start marker is written before Vulkan is used and deleted at the first Present; if it is
// still there at the next start, that start crashed or hung before its first frame, and the key stores and uses
// DirectX 9.
#include <windows.h>

#include <cctype>
#include <cstdint>
#include <cwchar>
#include <string>
#include <vector>

#include "../d3d9hooks.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../hostfiles.h"
#include "../log.h"
#include "../patch.h"
#include "../startup.h"

extern "C" {
void UhcRendererNameHook();
void UhcRendererTypeHook();
void UhcRendererGetHook();
void UhcRendererSetHook();

// The stored choice, as the dropdown's index (0 DirectX 9, 1 Vulkan). Read by UhcRendererGetHook.
std::int32_t g_uhcRendererChoice = 0;
}

namespace uhc {
namespace {

// Keep in step with VIRTUAL_ID in rendereroption_hooks.asm.
constexpr std::int32_t kVirtualId = 0x55480001;
constexpr wchar_t kOptionName[] = L"OptionRenderer";
constexpr int kDx9 = 0;
constexpr int kVulkan = 1;
constexpr char kDefaultConf[] = "d3d9.cachedWriteOnlyBuffers = True";
constexpr wchar_t kMarkerName[] = L"uhc-vulkan-start.tmp";
constexpr std::uint32_t kSettingsKind = 0x24;   // [settings+24h]: 1 for the options settings (FUN_00518CC9)

bool g_log = false;
bool g_lookupLogged = false;
std::wstring g_optionsPath;
std::wstring g_markerPath;
Direct3DCreate9Fn g_stockCreate = nullptr;
Direct3DCreate9Fn g_dxvkCreate = nullptr;
bool g_firstFrameSeen = false;

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

std::string ReadText(const std::wstring& path) {
  std::string text;
  HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return text;
  }
  char buffer[4096];
  DWORD read = 0;
  while (ReadFile(file, buffer, sizeof(buffer), &read, nullptr) && read != 0) {
    text.append(buffer, read);
  }
  CloseHandle(file);
  return text;
}

bool WriteText(const std::wstring& path, const std::string& text) {
  const std::wstring temp = path + L".new";
  HANDLE file = CreateFileW(temp.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }
  DWORD written = 0;
  const bool ok = WriteFile(file, text.data(), static_cast<DWORD>(text.size()), &written, nullptr) != 0 &&
                  written == text.size();
  CloseHandle(file);
  return ok && MoveFileExW(temp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != 0;
}

std::string Lower(std::string s) {
  for (char& c : s) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  return s;
}

// The `renderer` line of the options file: kVulkan, kDx9, or -1 if absent or unreadable.
int ReadStoredChoice() {
  const std::string text = ReadText(g_optionsPath);
  std::size_t pos = 0;
  while (pos < text.size()) {
    std::size_t end = text.find('\n', pos);
    if (end == std::string::npos) {
      end = text.size();
    }
    std::string line = Lower(text.substr(pos, end - pos));
    pos = end + 1;
    while (!line.empty() && (line.back() == '\r' || line.back() == ' ' || line.back() == '\t')) {
      line.pop_back();
    }
    if (line.rfind("renderer ", 0) == 0) {
      const std::string value = line.substr(9);
      if (value == "vulkan") {
        return kVulkan;
      }
      if (value == "dx9") {
        return kDx9;
      }
    }
  }
  return -1;
}

// Rewrites the options file with this choice, keeping its other lines.
bool StoreChoice(int choice) {
  const std::string text = ReadText(g_optionsPath);
  std::string out;
  bool replaced = false;
  std::size_t pos = 0;
  while (pos < text.size()) {
    std::size_t end = text.find('\n', pos);
    if (end == std::string::npos) {
      end = text.size();
    }
    std::string line = text.substr(pos, end - pos);
    pos = end + 1;
    if (!line.empty() && line.back() == '\r') {
      line.pop_back();
    }
    if (Lower(line).rfind("renderer ", 0) == 0) {
      if (replaced) {
        continue;
      }
      line = choice == kVulkan ? "renderer vulkan" : "renderer dx9";
      replaced = true;
    }
    out += line + "\r\n";
  }
  if (out.empty()) {
    out = "# The game's options menu writes this file (rendererOption). renderer: dx9 or vulkan, used at the next "
          "start.\r\n";
  }
  if (!replaced) {
    out += choice == kVulkan ? "renderer vulkan\r\n" : "renderer dx9\r\n";
  }
  if (!WriteText(g_optionsPath, out)) {
    Log(L"rendererOption: cannot write %ls (error %lu)", g_optionsPath.c_str(), GetLastError());
    return false;
  }
  return true;
}

// What the game gets in place of Direct3DCreate9 when Vulkan is used.
IDirect3D9* WINAPI RendererCreate9(UINT sdkVersion) {
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
bool UseVulkan(const std::wstring& folder, const std::string& conf) {
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
  if (GetEnvironmentVariableW(L"DXVK_CONFIG", existing, 2) == 0 && GetLastError() == ERROR_ENVVAR_NOT_FOUND) {
    SetEnvironmentVariableW(L"DXVK_CONFIG", Widen(conf).c_str());
    Log(L"rendererOption: DXVK_CONFIG=%hs", conf.c_str());
  } else {
    Log(L"rendererOption: DXVK_CONFIG is already set in the environment; left as it is");
  }
  if (GetEnvironmentVariableW(L"DXVK_LOG_PATH", existing, 2) == 0 && GetLastError() == ERROR_ENVVAR_NOT_FOUND) {
    std::wstring logPath = folder;
    if (!logPath.empty() && logPath.back() == L'\\') {
      logPath.pop_back();
    }
    SetEnvironmentVariableW(L"DXVK_LOG_PATH", logPath.c_str());
  }
  HMODULE module = LoadLibraryExW(dll.c_str(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
  if (module == nullptr) {
    Log(L"rendererOption: cannot load %ls (error %lu); using DirectX 9", dll.c_str(), GetLastError());
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

extern "C" std::int32_t __stdcall UhcRendererOptionLookup(const wchar_t* name, const std::uint8_t* settings) {
  if (name == nullptr || _wcsicmp(name, kOptionName) != 0 ||
      *reinterpret_cast<const std::uint32_t*>(settings + kSettingsKind) != 1) {
    return -1;
  }
  if (g_log || !g_lookupLogged) {
    g_lookupLogged = true;
    Log(L"rendererOption: options screen field %ls (settings 0x%08X, %u options); shows %ls", name,
        static_cast<unsigned>(reinterpret_cast<std::uintptr_t>(settings)),
        *reinterpret_cast<const std::uint32_t*>(settings + 8), ChoiceName(g_uhcRendererChoice));
  }
  return kVirtualId;
}

extern "C" void __stdcall UhcRendererOptionSet(std::int32_t value) {
  if (value != kDx9 && value != kVulkan) {
    Log(L"rendererOption: the menu wrote %d; ignored (only two entries: DirectX 9, Vulkan)", value);
    return;
  }
  if (value == g_uhcRendererChoice) {
    if (g_log) {
      Log(L"rendererOption: Apply, still %ls", ChoiceName(value));
    }
    return;
  }
  g_uhcRendererChoice = value;
  const bool stored = StoreChoice(value);
  Log(L"rendererOption: %ls chosen in the menu%ls; it takes effect at the next start", ChoiceName(value),
      stored ? L"" : L" (NOT stored)");
}

Outcome ApplyRendererOption(const Config& config) {
  const Config::Args* args = config.First("rendererOption");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  int initial = kDx9;
  std::wstring folder = L"dxvk";
  std::string conf = kDefaultConf;
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
      conf = arg.substr(5);  // the rest of the line: DXVK options may hold spaces
      for (std::size_t j = i + 1; j < args->size(); ++j) {
        conf += " " + (*args)[j];
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

  if (!VerifyAll("rendererOption", {&sites::kOptionNameLookup, &sites::kOptionTypeGetter, &sites::kOptionTypeRange,
                                    &sites::kOptionIntGetter, &sites::kOptionIntGetRange, &sites::kOptionIntSetter})) {
    return Outcome::kFailed;
  }
  g_optionsPath = ExeFolder() + kOptionsFile;
  g_markerPath = g_optionsPath.substr(0, g_optionsPath.find_last_of(L'\\') + 1) + kMarkerName;

  int choice = ReadStoredChoice();
  Log(L"rendererOption: %ls: %ls", g_optionsPath.c_str(),
      choice < 0 ? L"no choice stored yet" : ChoiceName(choice));
  if (choice < 0) {
    choice = initial;
  }
  if (Exists(g_markerPath)) {
    DeleteFileW(g_markerPath.c_str());
    Log(L"rendererOption: the last start with Vulkan did not present a frame (marker %ls); DirectX 9 stored and "
        L"used",
        g_markerPath.c_str());
    choice = kDx9;
    StoreChoice(kDx9);
  }
  g_uhcRendererChoice = choice;

  if (!WriteJmp(sites::kOptionNameLookup.va + 0x3D, reinterpret_cast<const void*>(&UhcRendererNameHook), 5) ||
      !WriteJmp(sites::kOptionTypeRange.va, reinterpret_cast<const void*>(&UhcRendererTypeHook), 5) ||
      !WriteJmp(sites::kOptionIntGetRange.va, reinterpret_cast<const void*>(&UhcRendererGetHook), 5) ||
      !WriteJmp(sites::kOptionIntSetter.va + 0x46, reinterpret_cast<const void*>(&UhcRendererSetHook), 5)) {
    return Outcome::kFailed;
  }

  if (choice == kVulkan) {
    UseVulkan(folder, conf);
  } else {
    Log(L"rendererOption: DirectX 9");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
