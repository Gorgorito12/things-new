# Code for WoL: Game files

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

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
