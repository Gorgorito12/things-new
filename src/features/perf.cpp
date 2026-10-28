// perfStats: passive diagnostics for the performance work (docs/performance.md). It wraps
// Direct3DCreate9 through its IAT slot, then IDirect3D9::CreateDevice and
// IDirect3DDevice9::Reset/Present through their vtables. It logs how the device is created and
// the main thread's FPU state after it, and publishes frame-time counters in shared memory for
// tools/perfprobe.py. The game's own calls and arguments pass through unchanged.
//
// perfAutoExec <frame> <command>: test harness for unattended benchmarks. After the given
// Present, it runs a console command on the main thread, as if typed into the console.
// perfExecFile <path>: every 30 frames, if <path> exists, runs each of its lines the same way
// and deletes it, so a script can drive the game without keyboard focus.
#include <windows.h>

#include <d3d9.h>
#include <psapi.h>
#include <xmmintrin.h>

#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <string>
#include <vector>

#include "../features.h"
#include "../log.h"
#include "../patch.h"

namespace uhc {
namespace {

// IAT slot of d3d9!Direct3DCreate9 (docs/engine-symbols.md, "IAT slots"). It holds a runtime
// address, so it is checked against GetProcAddress instead of generated/sites.h.
constexpr std::uint32_t kDirect3DCreate9Slot = 0x00B84164;
constexpr int kCreateDeviceIndex = 16;  // IDirect3D9
constexpr int kResetIndex = 16;         // IDirect3DDevice9
constexpr int kPresentIndex = 17;       // IDirect3DDevice9

// Shared with tools/perfprobe.py (mapping "Local\UHCPerfStats-<pid>"); bump kVersion on change.
struct PerfShared {
  std::uint32_t magic;          // 'UHCP'
  std::uint32_t version;
  std::uint32_t frames;         // Present calls
  std::uint32_t maxFrameUs;     // longest frame since the reader last cleared it
  std::uint64_t totalFrameUs;   // sum of all frame times
  std::uint32_t over33ms;       // frames longer than 33.3 / 50 / 100 ms
  std::uint32_t over50ms;
  std::uint32_t over100ms;
  std::uint32_t behaviorFlags;  // last CreateDevice
  std::uint32_t backBufferCount;
  std::uint32_t presentationInterval;
  std::uint32_t windowed;
  std::uint32_t width;
  std::uint32_t height;
};
constexpr std::uint32_t kMagic = 0x50434855;  // "UHCP"
constexpr std::uint32_t kVersion = 1;

using Direct3DCreate9Fn = IDirect3D9*(WINAPI*)(UINT);
using CreateDeviceFn = HRESULT(STDMETHODCALLTYPE*)(IDirect3D9*, UINT, D3DDEVTYPE, HWND, DWORD,
                                                   D3DPRESENT_PARAMETERS*, IDirect3DDevice9**);
using ResetFn = HRESULT(STDMETHODCALLTYPE*)(IDirect3DDevice9*, D3DPRESENT_PARAMETERS*);
using PresentFn = HRESULT(STDMETHODCALLTYPE*)(IDirect3DDevice9*, const RECT*, const RECT*, HWND,
                                              const RGNDATA*);

Direct3DCreate9Fn g_direct3DCreate9 = nullptr;
CreateDeviceFn g_createDevice = nullptr;
ResetFn g_reset = nullptr;
PresentFn g_present = nullptr;

PerfShared* g_shared = nullptr;
LONGLONG g_qpcFrequency = 0;
LONGLONG g_lastPresent = 0;  // 0 = no previous frame (start, or after a Reset)
std::uint32_t g_presents = 0;

// Console command execution (docs/performance.md, "Benchmark harness"): thiscall
// 0x433D0D(console = [0xC672E4], const char* command, const char* source), ret 8. The game
// itself calls it with source "console", e.g. uiOpenScenarioBrowser() at 0x7E279D.
constexpr std::uint32_t kConsoleObject = 0x00C672E4;
using ExecuteCommandFn = int(__fastcall*)(void* console, void* unusedEdx, const char* command,
                                          const char* source);
const auto kExecuteCommand = reinterpret_cast<ExecuteCommandFn>(0x00433D0D);

struct AutoExec {
  std::uint32_t frame;
  std::string command;
  bool done;
};
std::vector<AutoExec> g_autoExec;
std::wstring g_execFile;

void Execute(const std::string& command) {
  void* console = *reinterpret_cast<void* const*>(kConsoleObject);
  if (console == nullptr) {
    Log(L"perfAutoExec: no console object at frame %u; skipped %hs", g_presents, command.c_str());
    return;
  }
  Log(L"perfAutoExec: frame %u: %hs", g_presents, command.c_str());
  kExecuteCommand(console, nullptr, command.c_str(), "console");
}

void RunExecFile() {
  if (GetFileAttributesW(g_execFile.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return;
  }
  std::string text;
  HANDLE file = CreateFileW(g_execFile.c_str(), GENERIC_READ, 0, nullptr, OPEN_EXISTING, 0, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return;  // still being written; try again later
  }
  char buffer[4096];
  DWORD read = 0;
  while (ReadFile(file, buffer, sizeof(buffer), &read, nullptr) && read != 0) {
    text.append(buffer, read);
  }
  CloseHandle(file);
  DeleteFileW(g_execFile.c_str());
  std::size_t start = 0;
  while (start < text.size()) {
    std::size_t end = text.find('\n', start);
    if (end == std::string::npos) {
      end = text.size();
    }
    std::string line = text.substr(start, end - start);
    while (!line.empty() && (line.back() == '\r' || line.back() == ' ')) {
      line.pop_back();
    }
    if (!line.empty()) {
      Execute(line);
    }
    start = end + 1;
  }
}

void RunAutoExec() {
  for (AutoExec& entry : g_autoExec) {
    if (!entry.done && g_presents >= entry.frame) {
      entry.done = true;
      Execute(entry.command);
    }
  }
  if (!g_execFile.empty() && g_presents % 30 == 0) {
    RunExecFile();
  }
}

// Points vtable slot `index` of a COM object at `hook`, keeping the original. d3d9 shares one
// vtable between all objects of a class, so a second call finds the hook already in place.
template <typename Fn>
bool HookVtable(void* object, int index, Fn hook, Fn* original) {
  void** slot = *reinterpret_cast<void***>(object) + index;
  if (*slot == reinterpret_cast<void*>(hook)) {
    return true;
  }
  *original = reinterpret_cast<Fn>(*slot);
  return WriteDword(static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(slot)),
                    static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(hook)));
}

void Publish(DWORD flags, const D3DPRESENT_PARAMETERS* pp) {
  if (g_shared == nullptr || pp == nullptr) {
    return;
  }
  g_shared->behaviorFlags = flags;
  g_shared->backBufferCount = pp->BackBufferCount;
  g_shared->presentationInterval = pp->PresentationInterval;
  g_shared->windowed = static_cast<std::uint32_t>(pp->Windowed);
  g_shared->width = pp->BackBufferWidth;
  g_shared->height = pp->BackBufferHeight;
}

void LogPresentParameters(const wchar_t* what, const D3DPRESENT_PARAMETERS* pp, HRESULT hr) {
  if (pp == nullptr) {
    return;
  }
  Log(L"perfStats: %ls %ux%u fmt %d, %u back buffer(s), swap %d, interval 0x%08X, windowed %d, "
      L"refresh %u -> hr 0x%08lX",
      what, pp->BackBufferWidth, pp->BackBufferHeight, pp->BackBufferFormat, pp->BackBufferCount,
      pp->SwapEffect, pp->PresentationInterval, pp->Windowed, pp->FullScreen_RefreshRateInHz,
      static_cast<unsigned long>(hr));
}

HRESULT STDMETHODCALLTYPE PresentHook(IDirect3DDevice9* device, const RECT* source,
                                      const RECT* dest, HWND window, const RGNDATA* dirty) {
  LARGE_INTEGER now;
  QueryPerformanceCounter(&now);
  if (g_lastPresent != 0) {
    const auto us = static_cast<std::uint32_t>((now.QuadPart - g_lastPresent) * 1000000 /
                                               g_qpcFrequency);
    ++g_shared->frames;
    g_shared->totalFrameUs += us;
    if (us > g_shared->maxFrameUs) {
      g_shared->maxFrameUs = us;
    }
    g_shared->over33ms += us > 33333 ? 1 : 0;
    g_shared->over50ms += us > 50000 ? 1 : 0;
    g_shared->over100ms += us > 100000 ? 1 : 0;
  }
  g_lastPresent = now.QuadPart;
  const HRESULT hr = g_present(device, source, dest, window, dirty);
  ++g_presents;
  if (!g_autoExec.empty() || !g_execFile.empty()) {
    RunAutoExec();
  }
  return hr;
}

HRESULT STDMETHODCALLTYPE ResetHook(IDirect3DDevice9* device, D3DPRESENT_PARAMETERS* pp) {
  const HRESULT hr = g_reset(device, pp);
  LogPresentParameters(L"Reset", pp, hr);
  if (SUCCEEDED(hr) && pp != nullptr) {
    Publish(g_shared->behaviorFlags, pp);
  }
  g_lastPresent = 0;  // the reset itself is not a frame
  return hr;
}

HRESULT STDMETHODCALLTYPE CreateDeviceHook(IDirect3D9* d3d, UINT adapter, D3DDEVTYPE type,
                                           HWND focus, DWORD flags, D3DPRESENT_PARAMETERS* pp,
                                           IDirect3DDevice9** device) {
  const HRESULT hr = g_createDevice(d3d, adapter, type, focus, flags, pp, device);
  // Without D3DCREATE_FPU_PRESERVE, d3d9 switches this (the main, simulation) thread's x87 unit
  // to single precision. A replacement d3d9 (DXVK) must leave the same control word, or
  // multiplayer games can go out of sync.
  unsigned short x87 = 0;
  __asm fnstcw x87
  Log(L"perfStats: CreateDevice adapter %u, type %d, behavior flags 0x%08lX; after it x87 "
      L"control word 0x%04X, MXCSR 0x%08X",
      adapter, type, static_cast<unsigned long>(flags), x87, _mm_getcsr());
  LogPresentParameters(L"CreateDevice", pp, hr);
  if (SUCCEEDED(hr) && device != nullptr && *device != nullptr) {
    Publish(flags, pp);
    if (!HookVtable(*device, kPresentIndex, &PresentHook, &g_present) ||
        !HookVtable(*device, kResetIndex, &ResetHook, &g_reset)) {
      Log(L"perfStats: could not hook the device vtable; no frame statistics");
    }
  }
  g_lastPresent = 0;
  return hr;
}

IDirect3D9* WINAPI Direct3DCreate9Hook(UINT sdkVersion) {
  IDirect3D9* d3d = g_direct3DCreate9(sdkVersion);
  if (d3d != nullptr && !HookVtable(d3d, kCreateDeviceIndex, &CreateDeviceHook, &g_createDevice)) {
    Log(L"perfStats: could not hook IDirect3D9::CreateDevice");
  }
  return d3d;
}

void LogSystem() {
  const auto* dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(GetModuleHandleW(nullptr));
  const auto* nt = reinterpret_cast<const IMAGE_NT_HEADERS32*>(
      reinterpret_cast<const BYTE*>(dos) + dos->e_lfanew);
  const bool laa = (nt->FileHeader.Characteristics & IMAGE_FILE_LARGE_ADDRESS_AWARE) != 0;

  MEMORYSTATUSEX memory = {sizeof(memory)};
  GlobalMemoryStatusEx(&memory);

  DWORD cores = 0;
  DWORD bytes = 0;
  GetLogicalProcessorInformation(nullptr, &bytes);
  if (bytes != 0) {
    auto* info = static_cast<SYSTEM_LOGICAL_PROCESSOR_INFORMATION*>(std::malloc(bytes));
    if (info != nullptr && GetLogicalProcessorInformation(info, &bytes)) {
      for (DWORD i = 0; i < bytes / sizeof(*info); ++i) {
        cores += info[i].Relationship == RelationProcessorCore ? 1 : 0;
      }
    }
    std::free(info);
  }
  SYSTEM_INFO system = {};
  GetSystemInfo(&system);
  Log(L"perfStats: large-address-aware %ls, user address space %llu MB, %lu logical CPUs, "
      L"%lu cores",
      laa ? L"yes" : L"no", memory.ullTotalVirtual >> 20, system.dwNumberOfProcessors, cores);
}

void LogAtExit() {
  PROCESS_MEMORY_COUNTERS_EX memory = {};
  GetProcessMemoryInfo(GetCurrentProcess(), reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&memory),
                       sizeof(memory));
  const std::uint32_t frames = g_shared != nullptr ? g_shared->frames : 0;
  Log(L"perfStats: exit, peak working set %zu MB, private %zu MB, %u frames, %u over 50 ms, "
      L"%u over 100 ms",
      memory.PeakWorkingSetSize >> 20, memory.PrivateUsage >> 20, frames,
      g_shared != nullptr ? g_shared->over50ms : 0, g_shared != nullptr ? g_shared->over100ms : 0);
}

}  // namespace

Outcome ApplyPerfStats(const Config& config) {
  if (!config.Has("perfStats") && !config.Has("perfAutoExec") && !config.Has("perfExecFile")) {
    return Outcome::kNotConfigured;
  }
  if (const auto* args = config.First("perfExecFile"); args != nullptr && !args->empty()) {
    std::string path;
    for (const std::string& part : *args) {
      path += (path.empty() ? "" : " ") + part;
    }
    g_execFile.assign(path.begin(), path.end());  // ASCII paths only
    Log(L"perfExecFile: polling %ls", g_execFile.c_str());
  }
  if (const auto* lines = config.All("perfAutoExec")) {
    for (const Config::Args& args : *lines) {
      if (args.size() < 2) {
        continue;
      }
      std::string command;
      for (std::size_t i = 1; i < args.size(); ++i) {
        command += (i > 1 ? " " : "") + args[i];
      }
      g_autoExec.push_back({static_cast<std::uint32_t>(std::strtoul(args[0].c_str(), nullptr, 10)),
                            command, false});
      Log(L"perfAutoExec: after frame %hs: %hs", args[0].c_str(), command.c_str());
    }
  }
  LogSystem();

  HMODULE d3d9 = GetModuleHandleW(L"d3d9.dll");
  void* real = d3d9 != nullptr ? reinterpret_cast<void*>(GetProcAddress(d3d9, "Direct3DCreate9"))
                               : nullptr;
  auto* const slot = reinterpret_cast<void* const*>(kDirect3DCreate9Slot);
  if (real == nullptr || *slot != real) {
    Log(L"perfStats: IAT slot 0x%08X does not point at d3d9!Direct3DCreate9", kDirect3DCreate9Slot);
    return Outcome::kFailed;
  }

  wchar_t name[64];
  swprintf_s(name, L"Local\\UHCPerfStats-%lu", GetCurrentProcessId());
  HANDLE mapping = CreateFileMappingW(INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE, 0,
                                      sizeof(PerfShared), name);
  if (mapping == nullptr) {
    Log(L"perfStats: CreateFileMapping failed (error %lu)", GetLastError());
    return Outcome::kFailed;
  }
  g_shared = static_cast<PerfShared*>(MapViewOfFile(mapping, FILE_MAP_ALL_ACCESS, 0, 0, 0));
  if (g_shared == nullptr) {
    Log(L"perfStats: MapViewOfFile failed (error %lu)", GetLastError());
    return Outcome::kFailed;
  }
  g_shared->magic = kMagic;
  g_shared->version = kVersion;

  LARGE_INTEGER frequency;
  QueryPerformanceFrequency(&frequency);
  g_qpcFrequency = frequency.QuadPart;

  g_direct3DCreate9 = reinterpret_cast<Direct3DCreate9Fn>(real);
  if (!WriteDword(kDirect3DCreate9Slot, static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(
                                            &Direct3DCreate9Hook)))) {
    return Outcome::kFailed;
  }
  std::atexit(LogAtExit);
  return Outcome::kApplied;
}

}  // namespace uhc
