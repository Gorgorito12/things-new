// dinput8.dll: this DLL for a game whose loader runs another UHC.dll, or for the stock exe with no loader at all
// (hooked at its entry point instead of the boot stub; see DllMain). The exe imports DINPUT8.dll and
// Windows looks next to the exe first, so it loads with no change to the exe, to that DLL or to their
// files. Every export goes on to the system's dinput8.dll (engineext_forward.cpp). Not VERSION.dll: the
// exe imports it too, but the game was seen to load the one in System32 with a copy next to the exe.
//
// The exe's boot stub (0xB836BE) loads UHC.dll, runs its UHCMain and jumps to the game's entry point.
// DllMain only moves that jump to EngineExtEntry, so this code runs after UHCMain and before the game.
// Coming second is what keeps the two apart: every key checks the stock bytes of its sites (VerifyAll),
// so a key that needs a site the other DLL patched fails, and logs it, instead of overwriting the hook.
//
// Its files are in engine-ext\ next to the exe; it reads neither the loader's cfg path 0xC65083, nor
// the loader's cfg, nor data\uhc.
//
// preloadDll: another mod's own dinput8.dll proxy cannot sit beside this file, which has its name. The key
// loads that mod's DLLs from the exe's folder where such a proxy would, in DllMain, before the boot stub and
// UHCMain, so one dinput8.dll serves both. That is a LoadLibrary under the loader lock: safe only for a
// DLL whose own DllMain does the same kind of work (file reads, patches, starting a thread without waiting
// for it). It is kept to the plain call; the results are logged later, by EngineExtMain.
#include <windows.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include "config.h"
#include "hostfiles.h"
#include "log.h"
#include "patch.h"
#include "startup.h"
#include "version.h"

namespace uhc {
const wchar_t kLogFile[] = L"engine-ext\\engine-ext.log";
const wchar_t kDataFolder[] = L"engine-ext\\";
const wchar_t kOptionsFile[] = L"engine-ext\\uhc-options.cfg";
}  // namespace uhc

namespace {

const auto kImageBase = reinterpret_cast<const BYTE*>(0x00400000);
constexpr DWORD kTimeDateStamp = 0x49EF86AC;  // the stock Steam build; the loader patch keeps it
constexpr DWORD kSizeOfImage = 0x00B22000;
constexpr std::uint32_t kStubEnd = 0x00B836E7;  // after UHCMain's call: mov eax,[0C66228h] / jmp 5876ACh
constexpr std::uint32_t kStubJump = 0x00B836EC;
constexpr BYTE kStubEndBytes[] = {0xA1, 0x28, 0x62, 0xC6, 0x00, 0xE9, 0xBB, 0x3F, 0xA0, 0xFF};
const std::uint32_t g_gameEntry = 0x005876AC;
const wchar_t kConfigFile[] = L"engine-ext\\engine-ext.cfg";

std::vector<std::wstring> g_preloadLog;  // written in DllMain, logged by EngineExtMain

// Any other program that loads this file, such as another exe of the folder, stays as it is.
bool IsPatchedAge3y() {
  const BYTE* exe = reinterpret_cast<const BYTE*>(GetModuleHandleW(nullptr));
  if (exe != kImageBase) {
    return false;
  }
  const auto* dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(exe);
  const auto* nt = reinterpret_cast<const IMAGE_NT_HEADERS32*>(exe + dos->e_lfanew);
  return nt->FileHeader.TimeDateStamp == kTimeDateStamp && nt->OptionalHeader.SizeOfImage == kSizeOfImage &&
         nt->OptionalHeader.AddressOfEntryPoint == 0x007836BE &&
         std::memcmp(reinterpret_cast<const void*>(kStubEnd), kStubEndBytes, sizeof(kStubEndBytes)) == 0;
}

// The stock exe, with no loader: its entry point 0x5876AC starts push 60h / push 0BEB228h (7 bytes), then a call.
constexpr std::uint32_t kStockEntryNext = 0x005876B3;
constexpr BYTE kStockEntryBytes[] = {0x6A, 0x60, 0x68, 0x28, 0xB2, 0xBE, 0x00, 0xE8};
const std::uint32_t g_stockEntryNext = kStockEntryNext;

bool IsStockAge3y() {
  const BYTE* exe = reinterpret_cast<const BYTE*>(GetModuleHandleW(nullptr));
  if (exe != kImageBase) {
    return false;
  }
  const auto* dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(exe);
  const auto* nt = reinterpret_cast<const IMAGE_NT_HEADERS32*>(exe + dos->e_lfanew);
  return nt->FileHeader.TimeDateStamp == kTimeDateStamp && nt->OptionalHeader.SizeOfImage == kSizeOfImage &&
         nt->OptionalHeader.AddressOfEntryPoint == g_gameEntry - 0x00400000 &&
         std::memcmp(reinterpret_cast<const void*>(g_gameEntry), kStockEntryBytes, sizeof(kStockEntryBytes)) == 0;
}

bool SameName(const std::wstring& a, const wchar_t* b) {
  return CompareStringOrdinal(a.c_str(), -1, b, -1, TRUE) == CSTR_EQUAL;
}

// preloadDll <file> [<file> ...]: plain file names in the exe's folder, loaded by full path, in cfg order.
void PreloadDlls() {
  const std::wstring folder = uhc::ExeFolder();
  uhc::Config config;
  if (folder.empty() || !config.Load(folder + kConfigFile)) {
    return;
  }
  const auto* lines = config.All("preloaddll");
  if (lines == nullptr) {
    return;
  }
  for (const uhc::Config::Args& args : *lines) {
    for (const std::string& arg : args) {
      const int size = MultiByteToWideChar(CP_ACP, 0, arg.c_str(), static_cast<int>(arg.size()), nullptr, 0);
      std::wstring name(static_cast<size_t>(size), L'\0');
      MultiByteToWideChar(CP_ACP, 0, arg.c_str(), static_cast<int>(arg.size()), name.data(), size);
      std::wstring line = L"preloadDll: " + name;
      if (name.empty() || name.find_first_of(L"\\/:") != std::wstring::npos || name == L"." || name == L"..") {
        line += L": refused, only a file name in the exe's folder";
      } else if (SameName(name, L"dinput8.dll") || SameName(name, L"UHC.dll")) {
        line += L": refused, that DLL is loaded already (this one, or the loader's by its boot stub)";
      } else {
        const HMODULE module = LoadLibraryW((folder + name).c_str());
        wchar_t result[96];
        if (module != nullptr) {
          swprintf_s(result, L": loaded at %p, before the game's entry point", static_cast<void*>(module));
        } else {
          swprintf_s(result, L": cannot load (error %lu)", GetLastError());
        }
        line += result;
      }
      g_preloadLog.push_back(std::move(line));
    }
  }
}

}  // namespace

extern "C" void __stdcall EngineExtMain() {
  CreateDirectoryW((uhc::ExeFolder() + L"engine-ext").c_str(), nullptr);
  uhc::Log(L"dinput8.dll " UHC_VERSION);
  for (const std::wstring& line : g_preloadLog) {
    uhc::Log(L"%ls", line.c_str());
  }
  uhc::ApplyFeatures(uhc::ExeFolder() + kConfigFile);
}

// Where the boot stub's last jmp goes. EAX and the rest stay as the stub left them, for the game's entry.
extern "C" __declspec(naked) void EngineExtEntry() {
  __asm {
    pushad
    pushfd
    call EngineExtMain
    popfd
    popad
    jmp g_gameEntry
  }
}

// The same for the stock exe, hooked at its entry point: the two pushes the jmp replaced, then the entry's call.
extern "C" __declspec(naked) void EngineExtStockEntry() {
  __asm {
    pushad
    pushfd
    call EngineExtMain
    popfd
    popad
    push 60h
    push 0BEB228h
    jmp g_stockEntryNext
  }
}

// Moves the jmp and runs preloadDll; with the loader lock held, the rest waits for EngineExtMain.
// preloadDll stays with the loader's exe: it stands in for a mod's own dinput8.dll proxy, and a mod
// whose DLLs need that runs the loader.
BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID) {
  if (reason == DLL_PROCESS_ATTACH) {
    DisableThreadLibraryCalls(module);
    if (IsPatchedAge3y()) {
      uhc::WriteJmp(kStubJump, reinterpret_cast<const void*>(&EngineExtEntry), 5);
      PreloadDlls();
    } else if (IsStockAge3y()) {
      // No loader: the exe imports this DLL, so this runs before its entry point 0x5876AC.
      uhc::WriteJmp(g_gameEntry, reinterpret_cast<const void*>(&EngineExtStockEntry), 7);
    }
  }
  return TRUE;
}
