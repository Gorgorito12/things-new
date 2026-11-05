// dinput8.dll: this DLL for a game whose loader runs another UHC.dll. The exe imports DINPUT8.dll and
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
#include <windows.h>

#include <cstdint>
#include <cstring>
#include <string>

#include "hostfiles.h"
#include "log.h"
#include "patch.h"
#include "startup.h"
#include "version.h"

namespace uhc {
const wchar_t kLogFile[] = L"engine-ext\\engine-ext.log";
const wchar_t kDataFolder[] = L"engine-ext\\";
}  // namespace uhc

namespace {

const auto kImageBase = reinterpret_cast<const BYTE*>(0x00400000);
constexpr DWORD kTimeDateStamp = 0x49EF86AC;  // the stock Steam build; the loader patch keeps it
constexpr DWORD kSizeOfImage = 0x00B22000;
constexpr std::uint32_t kStubEnd = 0x00B836E7;  // after UHCMain's call: mov eax,[0C66228h] / jmp 5876ACh
constexpr std::uint32_t kStubJump = 0x00B836EC;
constexpr BYTE kStubEndBytes[] = {0xA1, 0x28, 0x62, 0xC6, 0x00, 0xE9, 0xBB, 0x3F, 0xA0, 0xFF};
const std::uint32_t g_gameEntry = 0x005876AC;

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

}  // namespace

extern "C" void __stdcall EngineExtMain() {
  CreateDirectoryW((uhc::ExeFolder() + L"engine-ext").c_str(), nullptr);
  uhc::Log(L"dinput8.dll " UHC_VERSION);
  uhc::ApplyFeatures(uhc::ExeFolder() + L"engine-ext\\engine-ext.cfg");
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

// Only moves the jmp: with the loader lock held, the rest waits for EngineExtMain.
BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID) {
  if (reason == DLL_PROCESS_ATTACH) {
    DisableThreadLibraryCalls(module);
    if (IsPatchedAge3y()) {
      uhc::WriteJmp(kStubJump, reinterpret_cast<const void*>(&EngineExtEntry), 5);
    }
  }
  return TRUE;
}
