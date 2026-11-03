// customSyscalls [file or pattern...]: loads UHC plugins (.upl files: ordinary 32-bit DLLs that
// export UHCPluginMain) and adds the syscalls they register to the game (syscalls.h). Without
// arguments it loads every *.upl next to the exe. Paths are relative to the exe's folder.
//
// The plugin contract (the one plugins built for the community UHC DLL expect):
//   int UHCPluginMain(UHCPluginInfo* info);   // cdecl; the return value is only logged
//   struct UHCPluginInfo {                    // five cdecl function pointers, in this order
//     void (*RegisterCheat)(const char* text, BOOL enabled, void(__stdcall* fn)(void* playerData));
//     Syscall& (*RegisterSyscall)(DWORD group, DWORD retType, const char* name, const void* fn,
//                                 DWORD paramCount, const char* comment);
//     void (*SyscallSetParam)(Syscall& syscall, DWORD index, DWORD type, const void* defaultValue);
//     bool (*CheatAddResource)(void* playerData, int resource, float amount, bool unknown);
//     void (*CheatSpawnUnit)(void* playerData, const char* protoName);
//   };
// Groups: 0 AI, 1 HC, 2 KB, 3 RM, 4 TR, 5 UI, 6 UI2, 7 XS. Types: 1 void, 2 int, 4 float,
// 8 bool, 16 string, 32 vector. The default value is read when SyscallSetParam is called (int,
// float and bool by value, string and vector through the pointer). The Syscall reference is
// opaque to plugins; a plugin may keep `info` for later calls, so it lives as long as the game.
//
// Cheats are collected here for customCheats, which is not implemented yet.
#include <windows.h>

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../log.h"
#include "../syscalls.h"

namespace {

struct PluginCheat {
  std::string text;
  bool enabled;
  void(__stdcall* fn)(void*);
  std::string source;
};

std::vector<PluginCheat> g_cheats;
std::string g_currentPlugin;   // the plugin whose UHCPluginMain is running, for the log
uhc::SyscallDef g_rejected;    // the reference handed out for a refused registration
int g_pluginErrors = 0;

void __cdecl PluginRegisterCheat(const char* text, BOOL enabled, void(__stdcall* fn)(void*)) {
  if (text == nullptr || fn == nullptr) {
    ++g_pluginErrors;
    return;
  }
  g_cheats.push_back({text, enabled != FALSE, fn, g_currentPlugin});
}

uhc::SyscallDef* __cdecl PluginRegisterSyscall(DWORD group, DWORD retType, const char* name, const void* fn,
                                               DWORD paramCount, const char* comment) {
  if (group >= static_cast<DWORD>(uhc::SyscallGroup::kCount) || !uhc::IsSyscallType(retType, true) ||
      name == nullptr || *name == '\0' || fn == nullptr || paramCount > 32) {
    uhc::Log(L"customSyscalls: %hs: syscall %hs refused (group %lu, type %lu, %lu parameters)",
             g_currentPlugin.c_str(), name != nullptr ? name : "(null)", group, retType, paramCount);
    ++g_pluginErrors;
    g_rejected = uhc::SyscallDef();
    return &g_rejected;
  }
  uhc::SyscallDef def;
  def.group = static_cast<uhc::SyscallGroup>(group);
  def.retType = retType;
  def.name = name;
  def.fn = fn;
  def.comment = comment != nullptr ? comment : "";
  def.params.resize(paramCount);
  def.source = g_currentPlugin;
  return uhc::AddSyscall(std::move(def));
}

void __cdecl PluginSyscallSetParam(uhc::SyscallDef* syscall, DWORD index, DWORD type, const void* value) {
  if (syscall == nullptr || syscall == &g_rejected) {
    return;
  }
  if (index >= syscall->params.size() || !uhc::IsSyscallType(type, false) || value == nullptr) {
    uhc::Log(L"customSyscalls: %hs: parameter %lu of %hs refused (type %lu)", g_currentPlugin.c_str(), index,
             syscall->name.c_str(), type);
    ++g_pluginErrors;
    return;
  }
  uhc::SyscallParam& p = syscall->params[index];
  p.type = type;
  switch (type) {
    case uhc::kSyscallInt:
    case uhc::kSyscallBool:
      std::memcpy(&p.intValue, value, 4);
      break;
    case uhc::kSyscallFloat:
      std::memcpy(&p.floatValue, value, 4);
      break;
    case uhc::kSyscallString:
      p.stringValue = static_cast<const char*>(value);
      break;
    case uhc::kSyscallVector:
      std::memcpy(p.vectorValue, value, sizeof(p.vectorValue));
      break;
  }
}

bool __cdecl PluginCheatAddResource(void* playerData, int resource, float amount, bool unknown) {
  using AddResource = bool(__thiscall*)(void*, int, float, bool);
  return reinterpret_cast<AddResource>(0x0049A98A)(playerData, resource, amount, unknown);
}

struct PluginInfo {
  void(__cdecl* registerCheat)(const char*, BOOL, void(__stdcall*)(void*));
  uhc::SyscallDef*(__cdecl* registerSyscall)(DWORD, DWORD, const char*, const void*, DWORD, const char*);
  void(__cdecl* syscallSetParam)(uhc::SyscallDef*, DWORD, DWORD, const void*);
  bool(__cdecl* cheatAddResource)(void*, int, float, bool);
  const void* cheatSpawnUnit;
};
static_assert(sizeof(PluginInfo) == 20, "plugins index this table by 4-byte slots");

const PluginInfo g_info = {PluginRegisterCheat, PluginRegisterSyscall, PluginSyscallSetParam,
                           PluginCheatAddResource, reinterpret_cast<const void*>(0x007B4F03)};

using PluginMain = int(__cdecl*)(const PluginInfo*);

// No C++ objects here, so a fault in a plugin can be caught with SEH.
bool CallPluginMain(PluginMain main, int* result, DWORD* code) {
  __try {
    *result = main(&g_info);
    return true;
  } __except (*code = GetExceptionCode(), EXCEPTION_EXECUTE_HANDLER) {
    return false;
  }
}

std::wstring ExeDirectory() {
  wchar_t exe[MAX_PATH];
  const DWORD len = GetModuleFileNameW(nullptr, exe, MAX_PATH);
  if (len == 0 || len == MAX_PATH) {
    return {};
  }
  std::wstring path(exe, len);
  path.resize(path.find_last_of(L'\\') + 1);
  return path;
}

std::string Narrow(const std::wstring& s) {
  std::string out;
  for (wchar_t c : s) {
    out += c < 128 ? static_cast<char>(c) : '?';
  }
  return out;
}

// Loads one plugin by full path; false if it could not run.
bool LoadPlugin(const std::wstring& path, const std::wstring& fileName) {
  HMODULE module = LoadLibraryExW(path.c_str(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
  if (module == nullptr) {
    uhc::Log(L"customSyscalls: cannot load %ls (error %lu)", path.c_str(), GetLastError());
    return false;
  }
  const auto main = reinterpret_cast<PluginMain>(GetProcAddress(module, "UHCPluginMain"));
  if (main == nullptr) {
    uhc::Log(L"customSyscalls: %ls has no UHCPluginMain; not a UHC plugin", fileName.c_str());
    FreeLibrary(module);
    return false;
  }
  g_currentPlugin = Narrow(fileName);
  const std::size_t syscallsBefore = uhc::SyscallCount();
  const std::size_t cheatsBefore = g_cheats.size();
  const int errorsBefore = g_pluginErrors;
  int result = 0;
  DWORD code = 0;
  // The stack pointer is restored by the call itself (cdecl); a plugin built as stdcall would
  // pop its argument, which MSVC's frame-pointer epilogue here also tolerates.
  const bool ran = CallPluginMain(main, &result, &code);
  g_currentPlugin.clear();
  if (!ran) {
    uhc::Log(L"customSyscalls: %ls crashed in UHCPluginMain (exception 0x%08lX); what it registered "
             L"before is kept",
             fileName.c_str(), code);
    return false;
  }
  uhc::Log(L"customSyscalls: %ls: %zu syscalls, %zu cheats%ls (UHCPluginMain returned %d)", fileName.c_str(),
           uhc::SyscallCount() - syscallsBefore, g_cheats.size() - cheatsBefore,
           g_pluginErrors > errorsBefore ? L", some refused (see above)" : L"", result);
  return true;
}

}  // namespace

namespace uhc {

Outcome ApplyPlugins(const Config& config) {
  const Config::Args* args = config.First("customSyscalls");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!InstallSyscallHooks("customSyscalls")) {
    return Outcome::kFailed;
  }
  std::vector<std::wstring> patterns;
  for (const std::string& a : *args) {
    patterns.emplace_back(a.begin(), a.end());
  }
  if (patterns.empty()) {
    patterns.push_back(L"*.upl");
  }
  const std::wstring dir = ExeDirectory();
  int loaded = 0;
  int found = 0;
  for (const std::wstring& pattern : patterns) {
    const bool absolute = pattern.size() > 1 && (pattern[1] == L':' || pattern[0] == L'\\');
    const std::wstring full = absolute ? pattern : dir + pattern;
    const std::wstring folder = full.substr(0, full.find_last_of(L'\\') + 1);
    WIN32_FIND_DATAW fd;
    HANDLE find = FindFirstFileW(full.c_str(), &fd);
    if (find == INVALID_HANDLE_VALUE) {
      Log(L"customSyscalls: no file matches %ls", full.c_str());
      continue;
    }
    do {
      if ((fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
        continue;
      }
      ++found;
      loaded += LoadPlugin(folder + fd.cFileName, fd.cFileName) ? 1 : 0;
    } while (FindNextFileW(find, &fd));
    FindClose(find);
  }
  if (loaded == 0) {
    Log(L"customSyscalls: no plugin loaded (%d file(s) found)", found);
    return Outcome::kFailed;
  }
  Log(L"customSyscalls: %d of %d plugin(s) loaded, %zu syscalls queued, %zu cheats collected (cheats need "
      L"customCheats, not implemented yet)",
      loaded, found, SyscallCount(), g_cheats.size());
  return Outcome::kApplied;
}

}  // namespace uhc
