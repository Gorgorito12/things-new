# Code for WoL: Game files

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [bufferedFileReads](#bufferedfilereads)
- [fastVertexFill](#fastvertexfill)
- [xsErrorLog](#xserrorlog)

## bufferedFileReads

Contract: [bufferedFileReads](../porting-to-another-dll.md#bufferedfilereads).

### src/features/fileio.cpp

```cpp
// bufferedFileReads [KB] [verify]: serves the exe's small ReadFile calls from a read-ahead buffer
// per file. With `verify`, every buffered read is also made for real at the same offset and
// compared, and mismatches are logged; that is a correctness test, not a speed-up.
// The game's raw file stream (0x4683F4) issues one ReadFile per call, often for 4 bytes, so a
// model or animation loaded during a match costs thousands of syscalls on the main thread
// (docs/performance.md, section 9). The bytes returned are the same; only the syscalls change.
//
// perfFileLog [ms]: at exit, logs every file the exe spent at least [ms] (default 1) in ReadFile on,
// with its read count, bytes and timing, plus totals. The lines are kept in memory until then, so
// logging never touches the disk during a match.
//
// Both wrap the exe's IAT entries for CreateFileA/W, ReadFile, SetFilePointer, CloseHandle and
// DuplicateHandle. Only files opened for reading alone, without OVERLAPPED or NO_BUFFERING, are
// buffered, and only for the thread that opened them. Any other use of such a handle (another
// thread, an OVERLAPPED read, DuplicateHandle) first moves the real file pointer to where the game
// thinks it is and turns buffering off for that handle.
#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <new>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../log.h"
#include "../patch.h"

namespace uhc {
namespace {

// IAT slots of the exe's KERNEL32 imports (docs/engine-symbols.md, "IAT slots"). They hold
// runtime addresses, so each is checked against GetProcAddress instead of generated/sites.h.
constexpr std::uint32_t kCreateFileASlot = 0x00B842A4;
constexpr std::uint32_t kCreateFileWSlot = 0x00B84304;
constexpr std::uint32_t kReadFileSlot = 0x00B8424C;
constexpr std::uint32_t kSetFilePointerSlot = 0x00B84244;
constexpr std::uint32_t kCloseHandleSlot = 0x00B84330;
constexpr std::uint32_t kDuplicateHandleSlot = 0x00B843A0;

using CreateFileAFn = HANDLE(WINAPI*)(LPCSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE);
using CreateFileWFn = HANDLE(WINAPI*)(LPCWSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE);
using ReadFileFn = BOOL(WINAPI*)(HANDLE, LPVOID, DWORD, LPDWORD, LPOVERLAPPED);
using SetFilePointerFn = DWORD(WINAPI*)(HANDLE, LONG, PLONG, DWORD);
using CloseHandleFn = BOOL(WINAPI*)(HANDLE);
using DuplicateHandleFn = BOOL(WINAPI*)(HANDLE, HANDLE, HANDLE, LPHANDLE, DWORD, BOOL, DWORD);

CreateFileAFn g_createFileA = nullptr;
CreateFileWFn g_createFileW = nullptr;
ReadFileFn g_readFile = nullptr;
SetFilePointerFn g_setFilePointer = nullptr;
CloseHandleFn g_closeHandle = nullptr;
DuplicateHandleFn g_duplicateHandle = nullptr;

bool g_buffering = false;
bool g_verify = false;
DWORD g_bufferSize = 64 * 1024;
volatile LONG g_verified = 0;
volatile LONG g_mismatches = 0;
bool g_logging = false;
LONGLONG g_logThresholdTicks = 0;
LONGLONG g_qpcFrequency = 1;

struct FileState {
  CRITICAL_SECTION lock;
  std::wstring path;
  DWORD owner = 0;            // thread that opened it
  bool buffered = false;
  std::int64_t pos = 0;       // file position as the game sees it
  std::int64_t osPos = 0;     // the real file pointer; -1 after a failed read (unknown)
  std::int64_t bufStart = 0;  // file offset of buf[0]
  DWORD bufLen = 0;
  std::uint8_t* buf = nullptr;
  // statistics
  std::uint32_t reads = 0;       // ReadFile calls by the game
  std::uint32_t smallReads = 0;  // of which 16 bytes or less
  std::uint32_t syscalls = 0;    // ReadFile calls actually made
  std::uint64_t bytes = 0;
  LONGLONG readTicks = 0;
  LONGLONG openedAt = 0;
};

// Tracked handles. Readers hold the lock shared for the whole operation on a tracked handle;
// CreateFile and CloseHandle take it exclusively, so a state is never freed while in use.
SRWLOCK g_filesLock = SRWLOCK_INIT;
std::unordered_map<HANDLE, FileState*>* g_files = nullptr;

CRITICAL_SECTION g_logLock;
std::vector<std::wstring>* g_logLines = nullptr;
struct Totals {
  std::uint64_t files = 0, reads = 0, smallReads = 0, syscalls = 0, bytes = 0;
  LONGLONG readTicks = 0;
} g_totals;

LONGLONG Now() {
  LARGE_INTEGER t;
  QueryPerformanceCounter(&t);
  return t.QuadPart;
}

double Ms(LONGLONG ticks) { return ticks * 1000.0 / g_qpcFrequency; }

bool IsReadOnly(DWORD access) {
  constexpr DWORD kWrite = GENERIC_WRITE | GENERIC_ALL | FILE_WRITE_DATA | FILE_APPEND_DATA |
                           FILE_WRITE_EA | FILE_WRITE_ATTRIBUTES | DELETE | WRITE_DAC | WRITE_OWNER;
  return (access & kWrite) == 0 && (access & (GENERIC_READ | FILE_READ_DATA)) != 0;
}

// Moves the real file pointer to the game's position. Needs s->lock.
bool SyncPointer(FileState* s, HANDLE h) {
  if (s->osPos == s->pos) {
    return true;
  }
  LONG high = static_cast<LONG>(s->pos >> 32);
  const DWORD low = g_setFilePointer(h, static_cast<LONG>(s->pos & 0xFFFFFFFF), &high, FILE_BEGIN);
  if (low == INVALID_SET_FILE_POINTER && GetLastError() != NO_ERROR) {
    return false;
  }
  s->osPos = s->pos;
  return true;
}

// Hands the handle back to the plain Win32 behavior. Needs s->lock.
void StopBuffering(FileState* s, HANDLE h) {
  if (!s->buffered) {
    return;
  }
  const DWORD error = GetLastError();
  SyncPointer(s, h);
  s->buffered = false;
  s->bufLen = 0;
  std::free(s->buf);
  s->buf = nullptr;
  SetLastError(error);
}

void Retire(FileState* s) {
  if (g_logging) {
    EnterCriticalSection(&g_logLock);
    ++g_totals.files;
    g_totals.reads += s->reads;
    g_totals.smallReads += s->smallReads;
    g_totals.syscalls += s->syscalls;
    g_totals.bytes += s->bytes;
    g_totals.readTicks += s->readTicks;
    if (s->readTicks >= g_logThresholdTicks && s->reads != 0 && g_logLines->size() < 20000) {
      wchar_t line[512];
      _snwprintf_s(line, _TRUNCATE,
                   L"%u reads (%u of 16 B or less), %llu B, %u ReadFile calls, %.1f ms reading; "
                   L"opened at t=%.3f s, for %.1f ms: ",
                   s->reads, s->smallReads, static_cast<unsigned long long>(s->bytes), s->syscalls,
                   Ms(s->readTicks), Ms(s->openedAt) / 1000.0, Ms(Now() - s->openedAt));
      g_logLines->push_back(std::wstring(L"perfFileLog: ") + line + s->path);
    }
    LeaveCriticalSection(&g_logLock);
  }
  std::free(s->buf);
  DeleteCriticalSection(&s->lock);
  delete s;
}

void Track(HANDLE h, const wchar_t* path, DWORD access, DWORD flags) {
  if (h == INVALID_HANDLE_VALUE || h == nullptr) {
    return;
  }
  const bool eligible = g_buffering && IsReadOnly(access) &&
                        (flags & (FILE_FLAG_OVERLAPPED | FILE_FLAG_NO_BUFFERING)) == 0 &&
                        GetFileType(h) == FILE_TYPE_DISK;
  if (!eligible && !g_logging) {
    return;
  }
  auto* s = new (std::nothrow) FileState;
  if (s == nullptr) {
    return;
  }
  InitializeCriticalSection(&s->lock);
  if (path != nullptr) {
    s->path = path;
  }
  s->owner = GetCurrentThreadId();
  s->buffered = eligible;
  s->openedAt = Now();
  FileState* stale = nullptr;
  AcquireSRWLockExclusive(&g_filesLock);
  auto [it, inserted] = g_files->try_emplace(h, s);
  if (!inserted) {
    stale = it->second;  // closed behind our back; the handle value was reused
    it->second = s;
  }
  ReleaseSRWLockExclusive(&g_filesLock);
  if (stale != nullptr) {
    Retire(stale);
  }
}

// Reads for a buffered handle. Needs s->lock.
BOOL BufferedRead(FileState* s, HANDLE h, std::uint8_t* out, DWORD n, LPDWORD got) {
  DWORD done = 0;
  while (done < n) {
    if (s->bufLen != 0 && s->pos >= s->bufStart && s->pos < s->bufStart + s->bufLen) {
      const DWORD take = std::min(static_cast<DWORD>(s->bufStart + s->bufLen - s->pos), n - done);
      std::memcpy(out + done, s->buf + (s->pos - s->bufStart), take);
      done += take;
      s->pos += take;
      continue;
    }
    if (!SyncPointer(s, h)) {
      *got = done;
      return done != 0;
    }
    const DWORD rest = n - done;
    if (rest >= g_bufferSize) {  // large reads go straight to the file
      DWORD read = 0;
      const BOOL ok = g_readFile(h, out + done, rest, &read, nullptr);
      ++s->syscalls;
      s->pos += read;
      s->osPos = ok ? s->pos : -1;
      done += read;
      *got = done;
      return ok || done != 0;
    }
    if (s->buf == nullptr) {
      s->buf = static_cast<std::uint8_t*>(std::malloc(g_bufferSize));
      if (s->buf == nullptr) {
        s->buffered = false;
        DWORD read = 0;
        const BOOL ok = g_readFile(h, out + done, rest, &read, nullptr);
        ++s->syscalls;
        s->pos += read;
        s->osPos = s->pos;
        *got = done + read;
        return ok || *got != 0;
      }
    }
    DWORD read = 0;
    const BOOL ok = g_readFile(h, s->buf, g_bufferSize, &read, nullptr);
    ++s->syscalls;
    if (!ok) {
      s->bufLen = 0;
      s->osPos = -1;
      *got = done;
      return done != 0;
    }
    s->bufStart = s->pos;
    s->bufLen = read;
    s->osPos = s->pos + read;
    if (read == 0) {
      break;  // end of file
    }
  }
  *got = done;
  return TRUE;
}

// `verify` mode: reads the same bytes for real and compares. Needs s->lock.
void Verify(FileState* s, HANDLE h, std::int64_t at, const std::uint8_t* data, DWORD size) {
  std::uint8_t* real = static_cast<std::uint8_t*>(std::malloc(size));
  if (real == nullptr) {
    return;
  }
  OVERLAPPED where = {};
  where.Offset = static_cast<DWORD>(at & 0xFFFFFFFF);
  where.OffsetHigh = static_cast<DWORD>(at >> 32);
  DWORD read = 0;
  const DWORD error = GetLastError();
  const BOOL ok = g_readFile(h, real, size, &read, &where);  // synchronous handle: moves the pointer
  s->osPos = at + read;
  InterlockedIncrement(&g_verified);
  if (!ok || read != size || std::memcmp(real, data, size) != 0) {
    if (InterlockedIncrement(&g_mismatches) <= 5) {
      Log(L"bufferedFileReads verify: MISMATCH at offset %lld, %lu bytes (real read %lu, ok %d): %ls",
          at, size, read, ok, s->path.c_str());
    }
  }
  std::free(real);
  SetLastError(error);
}

BOOL WINAPI ReadFileHook(HANDLE h, LPVOID buffer, DWORD n, LPDWORD got, LPOVERLAPPED overlapped) {
  AcquireSRWLockShared(&g_filesLock);
  const auto it = g_files->find(h);
  if (it == g_files->end()) {
    ReleaseSRWLockShared(&g_filesLock);
    return g_readFile(h, buffer, n, got, overlapped);
  }
  FileState* s = it->second;
  EnterCriticalSection(&s->lock);
  const LONGLONG start = Now();
  if (s->buffered && (overlapped != nullptr || got == nullptr || s->owner != GetCurrentThreadId())) {
    StopBuffering(s, h);
  }
  BOOL ok;
  if (s->buffered) {
    const DWORD error = GetLastError();
    const std::int64_t at = s->pos;
    ok = BufferedRead(s, h, static_cast<std::uint8_t*>(buffer), n, got);
    if (ok && g_verify && *got != 0) {
      Verify(s, h, at, static_cast<const std::uint8_t*>(buffer), *got);
    }
    if (ok) {
      SetLastError(error);
    }
  } else {
    ok = g_readFile(h, buffer, n, got, overlapped);
    ++s->syscalls;
  }
  ++s->reads;
  s->smallReads += n <= 16 ? 1 : 0;
  s->bytes += got != nullptr && overlapped == nullptr ? *got : 0;
  s->readTicks += Now() - start;
  LeaveCriticalSection(&s->lock);
  ReleaseSRWLockShared(&g_filesLock);
  return ok;
}

DWORD WINAPI SetFilePointerHook(HANDLE h, LONG distance, PLONG distanceHigh, DWORD method) {
  AcquireSRWLockShared(&g_filesLock);
  const auto it = g_files->find(h);
  if (it == g_files->end()) {
    ReleaseSRWLockShared(&g_filesLock);
    return g_setFilePointer(h, distance, distanceHigh, method);
  }
  FileState* s = it->second;
  EnterCriticalSection(&s->lock);
  if (s->buffered && s->owner != GetCurrentThreadId()) {
    StopBuffering(s, h);
  }
  DWORD result = 0;
  bool done = false;
  if (s->buffered) {
    const std::int64_t delta =
        distanceHigh != nullptr
            ? static_cast<std::int64_t>((static_cast<std::uint64_t>(static_cast<DWORD>(*distanceHigh)) << 32) |
                                        static_cast<DWORD>(distance))
            : static_cast<std::int64_t>(distance);
    std::int64_t base = -1;
    if (method == FILE_BEGIN) {
      base = 0;
    } else if (method == FILE_CURRENT) {
      base = s->pos;
    } else if (method == FILE_END) {
      LARGE_INTEGER size;
      if (GetFileSizeEx(h, &size)) {
        base = size.QuadPart;
      }
    }
    const std::int64_t target = base + delta;
    if (base >= 0 && target < 0) {
      SetLastError(ERROR_NEGATIVE_SEEK);
      result = INVALID_SET_FILE_POINTER;
      done = true;
    } else if (base >= 0 && (distanceHigh != nullptr || target < 0xFFFFFFFF)) {
      s->pos = target;
      if (distanceHigh != nullptr) {
        *distanceHigh = static_cast<LONG>(target >> 32);
      }
      SetLastError(NO_ERROR);
      result = static_cast<DWORD>(target & 0xFFFFFFFF);
      done = true;
    } else {
      StopBuffering(s, h);  // an unusual request: let Windows answer it
    }
  }
  if (!done) {
    result = g_setFilePointer(h, distance, distanceHigh, method);
    const DWORD error = GetLastError();
    if (result != INVALID_SET_FILE_POINTER || error == NO_ERROR) {
      const std::uint64_t high = distanceHigh != nullptr ? static_cast<DWORD>(*distanceHigh) : 0;
      s->pos = s->osPos = static_cast<std::int64_t>(high << 32 | result);
    }
    SetLastError(error);
  }
  LeaveCriticalSection(&s->lock);
  ReleaseSRWLockShared(&g_filesLock);
  return result;
}

FileState* Untrack(HANDLE h) {
  AcquireSRWLockExclusive(&g_filesLock);
  FileState* s = nullptr;
  const auto it = g_files->find(h);
  if (it != g_files->end()) {
    s = it->second;
    g_files->erase(it);
  }
  ReleaseSRWLockExclusive(&g_filesLock);
  return s;
}

BOOL WINAPI CloseHandleHook(HANDLE h) {
  if (FileState* s = Untrack(h)) {
    Retire(s);
  }
  return g_closeHandle(h);
}

BOOL WINAPI DuplicateHandleHook(HANDLE sourceProcess, HANDLE source, HANDLE targetProcess,
                                LPHANDLE target, DWORD access, BOOL inherit, DWORD options) {
  const bool ours = sourceProcess == GetCurrentProcess() ||
                    GetProcessId(sourceProcess) == GetCurrentProcessId();
  if (ours) {
    // The copy shares the file pointer, so the real pointer must be right before it exists.
    AcquireSRWLockShared(&g_filesLock);
    const auto it = g_files->find(source);
    if (it != g_files->end()) {
      EnterCriticalSection(&it->second->lock);
      StopBuffering(it->second, source);
      LeaveCriticalSection(&it->second->lock);
    }
    ReleaseSRWLockShared(&g_filesLock);
  }
  const BOOL ok = g_duplicateHandle(sourceProcess, source, targetProcess, target, access, inherit, options);
  if (ours && (options & DUPLICATE_CLOSE_SOURCE) != 0) {
    if (FileState* s = Untrack(source)) {
      Retire(s);
    }
  }
  return ok;
}

HANDLE WINAPI CreateFileWHook(LPCWSTR name, DWORD access, DWORD share, LPSECURITY_ATTRIBUTES security,
                              DWORD disposition, DWORD flags, HANDLE templateFile) {
  const HANDLE h = g_createFileW(name, access, share, security, disposition, flags, templateFile);
  const DWORD error = GetLastError();
  Track(h, name, access, flags);
  SetLastError(error);
  return h;
}

HANDLE WINAPI CreateFileAHook(LPCSTR name, DWORD access, DWORD share, LPSECURITY_ATTRIBUTES security,
                              DWORD disposition, DWORD flags, HANDLE templateFile) {
  const HANDLE h = g_createFileA(name, access, share, security, disposition, flags, templateFile);
  const DWORD error = GetLastError();
  if (h != INVALID_HANDLE_VALUE) {
    wchar_t wide[MAX_PATH] = L"";
    if (name != nullptr) {
      MultiByteToWideChar(CP_ACP, 0, name, -1, wide, MAX_PATH);
    }
    Track(h, wide, access, flags);
  }
  SetLastError(error);
  return h;
}

void AtExit() {
  if (g_verify) {
    Log(L"bufferedFileReads verify: %ld buffered reads checked, %ld mismatches", g_verified, g_mismatches);
  }
  if (!g_logging) {
    return;
  }
  // Runs at process exit, after Windows has stopped the other threads. One of them may have died
  // holding a lock, so the waits are bounded.
  bool locked = false;
  for (int i = 0; i < 200 && !(locked = TryAcquireSRWLockExclusive(&g_filesLock)); ++i) {
    Sleep(1);
  }
  if (locked) {
    // Files still open at exit (archives stay open for the whole session) count too.
    std::vector<FileState*> open;
    for (const auto& entry : *g_files) {
      open.push_back(entry.second);
    }
    g_files->clear();
    ReleaseSRWLockExclusive(&g_filesLock);
    for (FileState* s : open) {
      Retire(s);
    }
  }
  bool logLocked = false;
  for (int i = 0; i < 200 && !(logLocked = TryEnterCriticalSection(&g_logLock)); ++i) {
    Sleep(1);
  }
  if (!logLocked) {
    Log(L"perfFileLog: busy at exit; no report");
    return;
  }
  Log(L"perfFileLog: %llu files read; %llu ReadFile calls by the game (%llu of 16 B or less), %llu made "
      L"to Windows, %llu MB, %.0f ms in ReadFile; %zu files over the threshold:",
      g_totals.files, g_totals.reads, g_totals.smallReads, g_totals.syscalls, g_totals.bytes >> 20,
      Ms(g_totals.readTicks), g_logLines->size());
  for (const std::wstring& line : *g_logLines) {
    Log(L"%ls", line.c_str());
  }
  g_logLines->clear();
  LeaveCriticalSection(&g_logLock);
}

// Checks that `slot` still holds the real `name` and keeps that address in `original`.
template <typename Fn>
bool CheckImport(std::uint32_t slot, HMODULE module, const char* name, Fn* original) {
  void* real = reinterpret_cast<void*>(GetProcAddress(module, name));
  if (real == nullptr || *reinterpret_cast<void* const*>(slot) != real) {
    Log(L"bufferedFileReads/perfFileLog: IAT slot 0x%08X does not point at %hs", slot, name);
    return false;
  }
  *original = reinterpret_cast<Fn>(real);
  return true;
}

}  // namespace

Outcome ApplyFileIo(const Config& config) {
  g_buffering = config.Has("bufferedFileReads");
  g_logging = config.Has("perfFileLog");
  if (!g_buffering && !g_logging) {
    return Outcome::kNotConfigured;
  }
  if (const auto* args = config.First("bufferedFileReads"); args != nullptr) {
    for (const std::string& arg : *args) {
      if (_stricmp(arg.c_str(), "verify") == 0) {
        g_verify = true;
      } else if (const unsigned long kb = std::strtoul(arg.c_str(), nullptr, 10); kb != 0) {
        g_bufferSize = std::clamp<unsigned long>(kb, 4, 1024) * 1024;
      }
    }
  }
  LARGE_INTEGER frequency;
  QueryPerformanceFrequency(&frequency);
  g_qpcFrequency = frequency.QuadPart;
  double thresholdMs = 1.0;
  if (const auto* args = config.First("perfFileLog"); args != nullptr && !args->empty()) {
    thresholdMs = std::strtod((*args)[0].c_str(), nullptr);
  }
  g_logThresholdTicks = static_cast<LONGLONG>(thresholdMs * g_qpcFrequency / 1000.0);

  HMODULE kernel32 = GetModuleHandleW(L"kernel32.dll");
  if (kernel32 == nullptr ||
      !CheckImport(kCreateFileASlot, kernel32, "CreateFileA", &g_createFileA) ||
      !CheckImport(kCreateFileWSlot, kernel32, "CreateFileW", &g_createFileW) ||
      !CheckImport(kReadFileSlot, kernel32, "ReadFile", &g_readFile) ||
      !CheckImport(kSetFilePointerSlot, kernel32, "SetFilePointer", &g_setFilePointer) ||
      !CheckImport(kCloseHandleSlot, kernel32, "CloseHandle", &g_closeHandle) ||
      !CheckImport(kDuplicateHandleSlot, kernel32, "DuplicateHandle", &g_duplicateHandle)) {
    return Outcome::kFailed;
  }
  g_files = new std::unordered_map<HANDLE, FileState*>();
  g_logLines = new std::vector<std::wstring>();
  InitializeCriticalSection(&g_logLock);

  // Every slot was verified above; write them only now, so a failure leaves the IAT untouched.
  // The close and duplicate hooks go in first, so no tracked handle can be closed unseen.
  const std::pair<std::uint32_t, void*> writes[] = {
      {kCloseHandleSlot, reinterpret_cast<void*>(&CloseHandleHook)},
      {kDuplicateHandleSlot, reinterpret_cast<void*>(&DuplicateHandleHook)},
      {kReadFileSlot, reinterpret_cast<void*>(&ReadFileHook)},
      {kSetFilePointerSlot, reinterpret_cast<void*>(&SetFilePointerHook)},
      {kCreateFileASlot, reinterpret_cast<void*>(&CreateFileAHook)},
      {kCreateFileWSlot, reinterpret_cast<void*>(&CreateFileWHook)},
  };
  for (const auto& [slot, hook] : writes) {
    if (!WriteDword(slot, static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(hook)))) {
      return Outcome::kFailed;
    }
  }
  if (g_buffering) {
    Log(L"bufferedFileReads: read-only files get a %lu KB read-ahead buffer (multiplayer-safe: same bytes)%ls",
        g_bufferSize / 1024, g_verify ? L"; verify mode: every buffered read is checked against a real one" : L"");
  }
  if (g_logging) {
    Log(L"perfFileLog: logging files with %.1f ms or more in ReadFile, at exit", thresholdMs);
  }
  std::atexit(AtExit);
  return Outcome::kApplied;
}

}  // namespace uhc
```

## fastVertexFill

Contract: [fastVertexFill](../porting-to-another-dll.md#fastvertexfill).

Sites: `ClothFillSetup` `0x40D4EB` (56 B), `ClothFillLoop` `0x40D523` (310 B), `ClothFillUnlock` `0x40D659` (36 B), `ClothFillBackScale` `0xB856B8` (4 B).

### src/features/vertexfill.cpp

```cpp
// fastVertexFill [log] [verify]: the cloth flags' vertices are built without reading the locked vertex buffer.
//
// The cloth flag draw 0x40D25B (flag manager [0xC67364], called by the world draw at 0x450684 and by 0x42922A at
// 0x429429) takes, per flag, a piece of the renderer's shared dynamic vertex buffer ([renderer+660h]: created at
// 0x5AE7D5 with usage DYNAMIC | WRITEONLY in the default pool, locked by 0x40A5B1 with NOOVERWRITE or DISCARD) and
// fills it with two copies of the flag's grid of 32-byte vertices: the front side, and the back side with the normal
// times -1.0. The stock loops write a front vertex from the simulated cloth and then build the back vertex from the
// front one they have just written: eight reads of the locked buffer per vertex. That memory is write-combined; a read
// from it is not cached and costs far more than the rest of the loop (99 % of the function's samples sit on those
// eight instructions).
//
// The key replaces the loops with a routine that reads only the source vertex and writes the same bytes
// (src/hooks/clothfill_hooks.asm). Display only: the routine writes vertex data and nothing else, takes no clock and
// no random number, and the bytes it writes are the stock ones, so players may set it differently.
//
// `verify` keeps the stock loops on the locked buffer and checks the routine against them: before the stock loops run
// it fills a buffer of the DLL from the same arguments, and before the Unlock it compares the two, byte for byte.
// `log` writes the session's counts to the log at exit.
#include <windows.h>

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcClothFillHook();
void UhcClothFillVerifyHook();
void UhcClothFillUnlockHook();
void __stdcall UhcClothFillRecords(void* front, void* back, const void* src, std::int32_t pitch, std::int32_t w,
                                   std::int32_t h, const float* uv, std::uint32_t oneSided);

// Counted by the hook, once per lock.
std::uint32_t g_uhcClothFills = 0;
std::uint32_t g_uhcClothVertices = 0;  // per side
}

namespace {

constexpr std::size_t kVertex = 32;
constexpr std::int32_t kMaxSide = 4096;           // far above any flag grid; a sanity limit for `verify`
constexpr std::size_t kGuard = 64;
constexpr std::uint8_t kUnwritten = 0xCD;
constexpr int kMaxMismatchLines = 10;
constexpr std::uint32_t kRenderer = 0x00C66044;   // renderer; +660h the dynamic vertex buffer's record {buffer, size, used}
constexpr DWORD kWindowMs = 10000;                // `verify` logs its counts this often

bool g_log = false;
bool g_verify = false;

// What UhcClothFillShadow filled and UhcClothFillCompare checks.
struct Pending {
  bool active = false;
  const std::uint8_t* front = nullptr;
  std::size_t backOffset = 0;
  std::size_t side = 0;  // bytes of one side
  bool both = false;
  std::int32_t w = 0;
  std::int32_t h = 0;
};
Pending g_pending;
std::vector<std::uint8_t>* g_shadow = nullptr;
std::uint64_t g_checkedFills = 0;
std::uint64_t g_checkedVertices = 0;
std::uint64_t g_mismatchedVertices = 0;
std::uint64_t g_overruns = 0;
std::uint64_t g_skipped = 0;
int g_mismatchLines = 0;
DWORD g_windowStart = 0;
std::uint32_t g_windowFills = 0;
std::uint64_t g_windowVertices = 0;

// Usage, pool and size of a vertex buffer, as Direct3D reports them (IDirect3DVertexBuffer9::GetDesc, slot 13).
struct BufferDesc {
  std::uint32_t format, type, usage, pool, size, fvf;
};

// `verify`, once: where the lock points and what the buffer is, for the log.
void LogBuffer(const std::uint8_t* front) {
  MEMORY_BASIC_INFORMATION info{};
  const bool queried = VirtualQuery(front, &info, sizeof(info)) != 0;
  BufferDesc desc{};
  long hr = -1;
  const char* renderer = *reinterpret_cast<const char* const*>(kRenderer);
  void** record = renderer == nullptr ? nullptr : *reinterpret_cast<void** const*>(renderer + 0x660);
  void* buffer = record == nullptr ? nullptr : record[0];
  if (buffer != nullptr) {
    using GetDescFn = long(__stdcall*)(void* self, BufferDesc* out);
    hr = (*reinterpret_cast<GetDescFn**>(buffer))[13](buffer, &desc);
  }
  uhc::Log(L"fastVertexFill verify: the lock points at 0x%08X: protection 0x%X (0x400 = write-combined), type 0x%X, "
           L"allocation base 0x%08X, region %u KB; the buffer (GetDesc hr 0x%08X): usage 0x%X (0x200 dynamic, 0x8 "
           L"write-only), pool %u, %u bytes",
           static_cast<unsigned>(reinterpret_cast<std::uintptr_t>(front)), queried ? info.Protect : 0u,
           queried ? info.Type : 0u,
           static_cast<unsigned>(reinterpret_cast<std::uintptr_t>(queried ? info.AllocationBase : nullptr)),
           queried ? static_cast<unsigned>(info.RegionSize / 1024) : 0u, static_cast<unsigned>(hr), desc.usage,
           desc.pool, desc.size);
}

void LogVertex(const wchar_t* which, std::size_t index, const std::uint8_t* stock, const std::uint8_t* ours) {
  std::uint32_t a[8];
  std::uint32_t b[8];
  std::memcpy(a, stock, sizeof(a));
  std::memcpy(b, ours, sizeof(b));
  uhc::Log(L"fastVertexFill verify: MISMATCH, %ls vertex %u: stock %08X %08X %08X %08X %08X %08X %08X %08X, "
           L"ours %08X %08X %08X %08X %08X %08X %08X %08X",
           which, static_cast<unsigned>(index), a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], b[0], b[1], b[2],
           b[3], b[4], b[5], b[6], b[7]);
}

// Compares `bytes` of the locked buffer with the shadow, vertex by vertex.
void CompareSide(const wchar_t* which, const std::uint8_t* stock, const std::uint8_t* ours, std::size_t bytes) {
  if (std::memcmp(stock, ours, bytes) == 0) {
    return;
  }
  for (std::size_t i = 0; i < bytes; i += kVertex) {
    if (std::memcmp(stock + i, ours + i, kVertex) != 0) {
      ++g_mismatchedVertices;
      if (g_mismatchLines < kMaxMismatchLines) {
        ++g_mismatchLines;
        LogVertex(which, i / kVertex, stock + i, ours + i);
      }
    }
  }
}

void AtExit() {
  if (g_verify) {
    uhc::Log(L"fastVertexFill verify: %llu fills checked against the stock loops (%llu vertices), %llu mismatches, "
             L"%llu writes outside the vertices, %llu fills skipped",
             g_checkedFills, g_checkedVertices, g_mismatchedVertices, g_overruns, g_skipped);
  } else if (g_log) {
    uhc::Log(L"fastVertexFill: %u fills, %u vertices per side", g_uhcClothFills, g_uhcClothVertices);
  }
}

}  // namespace

// `verify`, before the stock loops: runs the routine on a buffer of the DLL laid out as the lock is.
extern "C" void __stdcall UhcClothFillShadow(std::uint8_t* front, std::uint8_t* back, const void* src,
                                             std::int32_t pitch, std::int32_t w, std::int32_t h, const float* uv,
                                             std::uint32_t oneSided) {
  g_pending.active = false;
  if (w <= 0 || h <= 0 || w > kMaxSide || h > kMaxSide || back < front || src == nullptr) {
    ++g_skipped;
    return;
  }
  const std::size_t side = static_cast<std::size_t>(w) * static_cast<std::size_t>(h) * kVertex;
  const std::size_t backOffset = static_cast<std::size_t>(back - front);
  const bool both = oneSided == 0;
  if (both && backOffset < side) {  // the two sides would overlap: not what 0x40D506 computes
    ++g_skipped;
    return;
  }
  const std::size_t total = both ? backOffset + side : side;
  if (g_shadow == nullptr) {
    g_shadow = new std::vector<std::uint8_t>();
  }
  g_shadow->assign(total + kGuard, kUnwritten);
  UhcClothFillRecords(g_shadow->data(), g_shadow->data() + backOffset, src, pitch, w, h, uv, oneSided);
  g_pending = {true, front, backOffset, side, both, w, h};
}

// `verify`, before the Unlock: the stock loops have filled the locked buffer.
extern "C" void __stdcall UhcClothFillCompare() {
  if (!g_pending.active) {
    return;
  }
  g_pending.active = false;
  const std::uint8_t* ours = g_shadow->data();
  const std::uint64_t before = g_mismatchedVertices;
  CompareSide(L"front", g_pending.front, ours, g_pending.side);
  if (g_pending.both) {
    CompareSide(L"back", g_pending.front + g_pending.backOffset, ours + g_pending.backOffset, g_pending.side);
  }
  // Nothing but the vertices may have been written: the gap between the sides and the guard keep their fill.
  const std::size_t end = g_shadow->size();
  const std::size_t gapEnd = g_pending.both ? g_pending.backOffset : g_pending.side;
  const std::size_t tail = g_pending.both ? g_pending.backOffset + g_pending.side : g_pending.side;
  bool overrun = false;
  for (std::size_t i = g_pending.side; i < gapEnd && !overrun; ++i) {
    overrun = ours[i] != kUnwritten;
  }
  for (std::size_t i = tail; i < end && !overrun; ++i) {
    overrun = ours[i] != kUnwritten;
  }
  if (overrun) {
    ++g_overruns;
    if (g_mismatchLines < kMaxMismatchLines) {
      ++g_mismatchLines;
      uhc::Log(L"fastVertexFill verify: the routine wrote outside its vertices (%d x %d, %ls)", g_pending.w,
               g_pending.h, g_pending.both ? L"two sides" : L"one side");
    }
  }
  const std::uint64_t vertices =
      static_cast<std::uint64_t>(g_pending.w) * static_cast<std::uint64_t>(g_pending.h) * (g_pending.both ? 2 : 1);
  if (g_checkedFills == 0) {
    LogBuffer(g_pending.front);
    uhc::Log(L"fastVertexFill verify: first fill checked, %d x %d vertices, %ls: %llu mismatches", g_pending.w,
             g_pending.h, g_pending.both ? L"two sides" : L"one side", g_mismatchedVertices - before);
  }
  ++g_checkedFills;
  g_checkedVertices += vertices;
  const DWORD now = GetTickCount();
  if (g_windowStart == 0) {
    g_windowStart = now;
  }
  ++g_windowFills;
  g_windowVertices += vertices;
  if (now - g_windowStart >= kWindowMs) {
    uhc::Log(L"fastVertexFill verify: %u fills and %llu vertices in %.1f s; %llu mismatches so far", g_windowFills,
             g_windowVertices, (now - g_windowStart) / 1000.0, g_mismatchedVertices);
    g_windowStart = now;
    g_windowFills = 0;
    g_windowVertices = 0;
  }
}

namespace uhc {

Outcome ApplyFastVertexFill(const Config& config) {
  const auto* args = config.First("fastVertexFill");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "verify") == 0) {
      g_verify = true;
    } else {
      Log(L"fastVertexFill: unknown argument '%hs' (expected: [log] [verify]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("fastVertexFill", {&sites::kClothFillSetup, &sites::kClothFillLoop, &sites::kClothFillUnlock,
                                       &sites::kClothFillBackScale})) {
    return Outcome::kFailed;
  }
  if (g_verify) {
    // The compare goes in first, so the first shadow fill already has it.
    if (!WriteJmp(sites::kClothFillUnlock.va, reinterpret_cast<const void*>(&UhcClothFillUnlockHook), 6) ||
        !WriteJmp(sites::kClothFillLoop.va, reinterpret_cast<const void*>(&UhcClothFillVerifyHook), 8)) {
      return Outcome::kFailed;
    }
    Log(L"fastVertexFill: verify mode: the stock loops fill the cloth flags, and every fill is compared with the "
        L"routine's (display only)");
  } else {
    if (!WriteJmp(sites::kClothFillLoop.va, reinterpret_cast<const void*>(&UhcClothFillHook), 8)) {
      return Outcome::kFailed;
    }
    Log(L"fastVertexFill: the cloth flags' vertices are built without reading the locked vertex buffer%ls (display "
        L"only: same bytes)",
        g_log ? L", log" : L"");
  }
  if (g_log || g_verify) {
    std::atexit(AtExit);
  }
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/clothfill_hooks.asm

```asm
; fastVertexFill (src/features/vertexfill.cpp). Each hook is entered through a jmp written over the stock code,
; replaces or re-executes what it overwrote, and leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcClothFillShadow PROTO STDCALL front:DWORD, back:DWORD, src:DWORD, pitch:DWORD, w:DWORD, h:DWORD, uv:DWORD, oneSided:DWORD
UhcClothFillCompare PROTO STDCALL

EXTERNDEF g_uhcClothFills:DWORD
EXTERNDEF g_uhcClothVertices:DWORD

.data
fillNext    dd 0040D655h    ; mov ebp,[esp+34h]: the loops' exit
stockLoop   dd 0040D52Bh    ; shl ecx,5: the stock loops, after the two instructions the jmp replaced
unlockNext  dd 0040D65Fh    ; mov eax,[ecx+660h]

.code

; The eight arguments of UhcClothFillRecords, pushed from the frame of the cloth flag draw 0x40D25B as it is at
; 0x40D523. `bias` is what the hook has pushed since then. On entry EAX = half the vertex count of the lock (the stock
; cdq / sub / sar at 0x40D50E), ESI = the flag manager, EDI = the index of the source buffer. Uses EAX, ECX, EDX, EBP.
;   [esp+14h] rows, [esp+18h] columns, [esp+4Ch] the locked pointer, [esp+50h] three floats (U scale, V scale,
;   V offset), [esp+70h] the byte "front side only".
CLOTH_ARGS MACRO bias:REQ
    mov edx, [esp+4Ch+bias]             ; front side: the locked pointer
    shl eax, 5
    add eax, edx                        ; back side: half the lock further
    movzx ecx, byte ptr [esp+70h+bias]
    lea ebp, [esp+50h+bias]
    push ecx                            ; front side only
    push ebp                            ; the three floats
    push dword ptr [esp+14h+bias+8]     ; rows
    push dword ptr [esp+18h+bias+0Ch]   ; columns
    push dword ptr [esi+14h]            ; columns in a row of the source buffer
    push dword ptr [esi+edi*4+3Ch]      ; the source buffer
    push eax
    push edx
ENDM

; void stdcall UhcClothFillRecords(front, back, src, pitch, w, h, uv, oneSided)
; Writes what the stock loops 0x40D523..0x40D654 write, byte for byte: per row and column one 32-byte vertex at `front`
; (position and normal copied, U = uv[0] * source U, V = uv[1] * source V - uv[2]) and, unless `oneSided`, the same
; vertex at `back` with its normal times -1.0. The stock code builds the back vertex from the front one it has just
; written, i.e. it reads the locked buffer; this reads the source vertex again instead. The float operations are the
; stock ones, on the x87 stack and in the stock order, so the rounding is the same under any control word: the U and V
; products are stored twice from the same register (fst, fstp) where stock stores once and copies the dword.
UhcClothFillRecords PROC STDCALL USES ebx esi edi, front:DWORD, back:DWORD, src:DWORD, pitch:DWORD, w:DWORD, h:DWORD, uv:DWORD, oneSided:DWORD
    LOCAL rowEnd:DWORD
    mov eax, front
    mov edx, back
    mov esi, uv
    xor edi, edi                        ; row
    cmp w, 0
    jle done
    cmp h, 0
    jle done
row:
    mov ecx, pitch
    imul ecx, edi
    shl ecx, 5
    add ecx, src                        ; the row's first source vertex
    mov ebx, w
    shl ebx, 5
    add ebx, ecx
    mov rowEnd, ebx
    cmp byte ptr oneSided, 0
    jne single
both:
    mov ebx, [ecx]
    mov [eax], ebx
    mov [edx], ebx
    mov ebx, [ecx+4]
    mov [eax+4], ebx
    mov [edx+4], ebx
    mov ebx, [ecx+8]
    mov [eax+8], ebx
    mov [edx+8], ebx
    mov ebx, [ecx+0Ch]
    mov [eax+0Ch], ebx
    mov ebx, [ecx+10h]
    mov [eax+10h], ebx
    mov ebx, [ecx+14h]
    mov [eax+14h], ebx
    fld dword ptr [ecx+0Ch]
    fmul dword ptr ds:[0B856B8h]
    fstp dword ptr [edx+0Ch]
    fld dword ptr [ecx+10h]
    fmul dword ptr ds:[0B856B8h]
    fstp dword ptr [edx+10h]
    fld dword ptr [ecx+14h]
    fmul dword ptr ds:[0B856B8h]
    fstp dword ptr [edx+14h]
    fld dword ptr [esi]
    fmul dword ptr [ecx+18h]
    fst dword ptr [eax+18h]
    fstp dword ptr [edx+18h]
    fld dword ptr [esi+4]
    fmul dword ptr [ecx+1Ch]
    fsub dword ptr [esi+8]
    fst dword ptr [eax+1Ch]
    fstp dword ptr [edx+1Ch]
    add ecx, 20h
    add eax, 20h
    add edx, 20h
    cmp ecx, rowEnd
    jb both
    jmp nextRow
single:
    mov ebx, [ecx]
    mov [eax], ebx
    mov ebx, [ecx+4]
    mov [eax+4], ebx
    mov ebx, [ecx+8]
    mov [eax+8], ebx
    mov ebx, [ecx+0Ch]
    mov [eax+0Ch], ebx
    mov ebx, [ecx+10h]
    mov [eax+10h], ebx
    mov ebx, [ecx+14h]
    mov [eax+14h], ebx
    fld dword ptr [esi]
    fmul dword ptr [ecx+18h]
    fstp dword ptr [eax+18h]
    fld dword ptr [esi+4]
    fmul dword ptr [ecx+1Ch]
    fsub dword ptr [esi+8]
    fstp dword ptr [eax+1Ch]
    add ecx, 20h
    add eax, 20h
    cmp ecx, rowEnd
    jb single
nextRow:
    inc edi
    cmp edi, h
    jl row
done:
    ret
UhcClothFillRecords ENDP

; Replaces 0x40D523 (mov ecx,[esp+18h] / mov edx,[esp+4Ch]) and the two loops after it, up to their exit 0x40D655.
; Entered once per lock, after the stock test of the row count ([esp+14h] > 0). There, EAX, ECX, EDX and EBP are dead
; (0x40D655 loads EBP, 0x40D659 ECX, 0x40D65F EAX, 0x40D682 EDX), EBX is the value stock reloads from [esp+60h] at
; 0x40D617 (the callee keeps it), and the slots the stock loops use as counters ([esp+28h], [esp+2Ch], [esp+30h],
; [esp+5Ch]) are written again at 0x40D68A before anything reads them. The x87 stack is empty on both sides.
UhcClothFillHook PROC
    TRACE_ONCE "fastVertexFill cloth flag fill (0x40D523)"
    inc g_uhcClothFills
    mov ecx, [esp+18h]
    imul ecx, [esp+14h]
    add g_uhcClothVertices, ecx
    CLOTH_ARGS 0
    call UhcClothFillRecords
    jmp fillNext
UhcClothFillHook ENDP

; `verify`, at the same site: fills a buffer of the DLL with the arguments the hook above would use, then runs the
; stock loops themselves on the locked buffer. Every register is kept for them.
UhcClothFillVerifyHook PROC
    TRACE_ONCE "fastVertexFill verify, before the stock fill (0x40D523)"
    pushad
    CLOTH_ARGS 20h
    call UhcClothFillShadow
    popad
    mov ecx, [esp+18h]
    mov edx, [esp+4Ch]
    jmp stockLoop
UhcClothFillVerifyHook ENDP

; `verify`: replaces 0x40D659 (mov ecx,[0C66044h]), which the loops' exit falls into and the "no rows" branch 0x40D51D
; jumps to, before the Unlock. The helper compares what the stock loops wrote with the DLL's buffer. Every register is
; kept (EBX, ESI, EDI and EBP are live); the flags are dead (test eax,eax at 0x40D665).
UhcClothFillUnlockHook PROC
    TRACE_ONCE "fastVertexFill verify, after the stock fill (0x40D659)"
    pushad
    call UhcClothFillCompare
    popad
    mov ecx, dword ptr ds:[0C66044h]
    jmp unlockNext
UhcClothFillUnlockHook ENDP

END
```

## xsErrorLog

Contract: [xsErrorLog](../porting-to-another-dll.md#xserrorlog).

Sites: `XsFormat` `0x435D99` (6 B), `XsReportHead` `0x43A3A4` (6 B), `XsMessageHead` `0xA5667F` (6 B).

### src/features/xslog.cpp

```cpp
// xsErrorLog [maxLines]: writes the XS compiler's and runtime's messages to the log.
//
// The game shows only the last message, "XS: Error 0003: could not compile file 'aiLoaderStandard.xs'",
// and the cause goes to a callback that the shipped game leaves empty: both reporters format and
// print only when [log] is set, so the text is lost. The heads of the two reporters take the same
// arguments as the stock formatter 0x435D99 needs, so the key formats them itself and leaves the stock
// code as it is:
// - FUN_0043A3A4, void cdecl(int* log, char* file, int line, char* format, ...), with 8 callers;
// - FUN_00A5667F, void cdecl(int* log, char* format, ...), which carries Error 0003.
// Neither runs in a clean game, so the key costs nothing there. Nothing here changes the game.
#include <windows.h>

#include <cstdarg>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcXsReportHook();
void UhcXsMessageHook();
}

namespace {

constexpr std::size_t kBuffer = 0x400;
constexpr long kDefaultLines = 200;

using FormatFn = int(__cdecl*)(char* buffer, std::size_t size, const char* format, va_list args);
const auto kFormat = reinterpret_cast<FormatFn>(0x00435D99);

long g_maxLines = kDefaultLines;
volatile long g_lines = 0;

void Write(const char* file, std::int32_t line, const char* format, va_list args) {
  if (format == nullptr) {
    return;
  }
  char text[kBuffer] = {};
  kFormat(text, kBuffer, format, args);
  text[kBuffer - 1] = '\0';
  std::size_t length = std::strlen(text);
  while (length > 0 && (text[length - 1] == '\n' || text[length - 1] == '\r')) {
    text[--length] = '\0';
  }
  const long number = InterlockedIncrement(&g_lines);
  if (number > g_maxLines) {
    if (number == g_maxLines + 1) {
      uhc::Log(L"xsErrorLog: stopped at %ld lines", g_maxLines);
    }
    return;
  }
  if (file != nullptr && line > 0) {
    uhc::Log(L"xsErrorLog: %hs(%d): %hs", file, line, text);
  } else if (file != nullptr) {
    uhc::Log(L"xsErrorLog: %hs: %hs", file, text);
  } else {
    uhc::Log(L"xsErrorLog: %hs", text);
  }
}

}  // namespace

extern "C" {

// args points at the reporter's first argument.
void __stdcall UhcXsReport(void** args) {
  Write(static_cast<const char*>(args[1]), static_cast<std::int32_t>(reinterpret_cast<std::intptr_t>(args[2])),
        static_cast<const char*>(args[3]), reinterpret_cast<va_list>(args + 4));
}

void __stdcall UhcXsMessage(void** args) {
  Write(nullptr, 0, static_cast<const char*>(args[1]), reinterpret_cast<va_list>(args + 2));
}
}

namespace uhc {

Outcome ApplyXsErrorLog(const Config& config) {
  const Config::Args* args = config.First("xsErrorLog");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    char* end = nullptr;
    const long lines = std::strtol(arg.c_str(), &end, 10);
    if (end == arg.c_str() || *end != '\0' || lines <= 0) {
      Log(L"xsErrorLog: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_maxLines = lines;
  }
  if (!VerifyAll("xsErrorLog", {&sites::kXsReportHead, &sites::kXsMessageHead, &sites::kXsFormat}) ||
      !WriteJmp(sites::kXsReportHead.va, reinterpret_cast<const void*>(&UhcXsReportHook), 6) ||
      !WriteJmp(sites::kXsMessageHead.va, reinterpret_cast<const void*>(&UhcXsMessageHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"xsErrorLog: the XS messages go to this log, at most %ld lines", g_maxLines);
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/xslog_hooks.asm

```asm
; Hooks for xsErrorLog. Entered through a jmp written over the first 6 bytes of each reporter, both
; cdecl with their arguments on the stack, so EAX, ECX and EDX are free. Each one replays
; sub esp,804h and leaves through an explicit jmp to the verified next instruction.
.686
.model flat, c
option casemap :none

include common.inc

UhcXsReport PROTO STDCALL args:DWORD
UhcXsMessage PROTO STDCALL args:DWORD

.data
reportNext  dd 0043A3AAh    ; mov eax,[0C66228h]
messageNext dd 00A56685h    ; mov eax,[0C66228h]

.code

UhcXsReportHook PROC
    TRACE_ONCE "xsErrorLog report (0x43A3A4)"
    lea eax, [esp+4]
    push eax
    call UhcXsReport
    sub esp, 804h           ; replaced
    jmp reportNext
UhcXsReportHook ENDP

UhcXsMessageHook PROC
    TRACE_ONCE "xsErrorLog message (0xA5667F)"
    lea eax, [esp+4]
    push eax
    call UhcXsMessage
    sub esp, 804h           ; replaced
    jmp messageNext
UhcXsMessageHook ENDP

END
```
