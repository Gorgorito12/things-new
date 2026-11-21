# Code for WoL: Game files

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [bufferedFileReads](#bufferedfilereads)
- [fastVertexFill](#fastvertexfill)
- [fastLastInLine](#fastlastinline)
- [rendererOption](#rendereroption)
- [menuOptions](#menuoptions)
- [xsErrorLog](#xserrorlog)
- [lanAutoStart](#lanautostart)

## bufferedFileReads

Contract: [bufferedFileReads](../porting-to-another-dll.md#bufferedfilereads).

### src/features/fileio.cpp

```cpp
// bufferedFileReads [KB] [verify] [readahead]: serves the exe's small ReadFile calls from a
// read-ahead buffer per file. With `verify`, every buffered read is also made for real at the same
// offset and compared, and mismatches are logged; that is a correctness test, not a speed-up.
// With `readahead`, a worker thread of this DLL reads the block after the one the game is
// consuming, through a handle of its own (ReOpenFile), so that block is in memory when the game
// gets there. The worker never uses the game's handle, so the game's file pointer and its reads
// are untouched; a block is used only when it covers the position the game asks for.
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
#include <deque>
#include <new>
#include <string>
#include <unordered_map>
#include <utility>
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
bool g_readahead = false;
DWORD g_bufferSize = 64 * 1024;
volatile LONG g_verified = 0;
volatile LONG g_mismatches = 0;
bool g_logging = false;
LONGLONG g_logThresholdTicks = 0;
LONGLONG g_qpcFrequency = 1;

// `readahead` counters, logged at exit.
volatile LONG g_aheadIssued = 0;    // blocks the worker was asked to read
volatile LONG g_aheadRead = 0;      // blocks it read
volatile LONG g_aheadUsed = 0;      // blocks the game's thread took instead of reading
volatile LONG g_aheadWaits = 0;     // of those, how many it had to wait for
volatile LONG g_aheadNoHandle = 0;  // files whose second handle could not be opened
volatile LONG64 g_aheadWaitTicks = 0;
volatile LONG g_refills = 0;        // buffer refills made on the game's thread

// The block after the buffer, read by the worker thread. Guarded by FileState::lock, except that
// `buf` is written by the worker while `state` is kInFlight, and `handle` is used by it then.
struct ReadAhead {
  enum State : std::uint8_t { kIdle, kQueued, kInFlight, kReady };
  State state = kIdle;
  bool discard = false;   // set while in flight: drop the result
  bool disabled = false;  // no second handle; never tried again for this file
  HANDLE handle = nullptr;  // ours, from ReOpenFile; never the game's handle
  std::uint8_t* buf = nullptr;
  std::int64_t start = 0;
  DWORD len = 0;
};

struct FileState {
  CRITICAL_SECTION lock;
  CONDITION_VARIABLE aheadDone = CONDITION_VARIABLE_INIT;
  volatile LONG refs = 1;     // the handle table's, plus one while the worker has it queued
  std::wstring path;
  DWORD owner = 0;            // thread that opened it
  bool buffered = false;
  std::int64_t pos = 0;       // file position as the game sees it
  std::int64_t osPos = 0;     // the real file pointer; -1 after a failed read (unknown)
  std::int64_t bufStart = 0;  // file offset of buf[0]
  DWORD bufLen = 0;
  std::uint8_t* buf = nullptr;
  ReadAhead ahead;
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

// Drops the read-ahead block, queued, in flight or ready. Its buffer stays allocated until the
// state is freed, because the worker may still be writing into it. Needs s->lock.
void DropAhead(FileState* s) {
  ReadAhead& a = s->ahead;
  if (a.state == ReadAhead::kInFlight) {
    a.discard = true;
  } else {
    a.state = ReadAhead::kIdle;  // a queued request is skipped when the worker reaches it
  }
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
  DropAhead(s);
  SetLastError(error);
}

void Release(FileState* s) {
  if (InterlockedDecrement(&s->refs) != 0) {
    return;
  }
  std::free(s->buf);
  std::free(s->ahead.buf);
  if (s->ahead.handle != nullptr) {
    g_closeHandle(s->ahead.handle);
  }
  DeleteCriticalSection(&s->lock);
  delete s;
}

// The read-ahead worker: one thread, a queue of states with a kQueued block.
SRWLOCK g_queueLock = SRWLOCK_INIT;
CONDITION_VARIABLE g_queueReady = CONDITION_VARIABLE_INIT;
std::deque<FileState*>* g_queue = nullptr;

DWORD WINAPI AheadWorker(void*) {
  for (;;) {
    AcquireSRWLockExclusive(&g_queueLock);
    while (g_queue->empty()) {
      SleepConditionVariableSRW(&g_queueReady, &g_queueLock, INFINITE, 0);
    }
    FileState* s = g_queue->front();
    g_queue->pop_front();
    ReleaseSRWLockExclusive(&g_queueLock);

    ReadAhead& a = s->ahead;
    EnterCriticalSection(&s->lock);
    if (a.state != ReadAhead::kQueued) {  // taken back by the game's thread
      LeaveCriticalSection(&s->lock);
      Release(s);
      continue;
    }
    a.state = ReadAhead::kInFlight;
    a.discard = false;
    const std::int64_t at = a.start;
    LeaveCriticalSection(&s->lock);

    // A positioned read on our own synchronous handle: the game's handle and its file pointer
    // are never touched.
    OVERLAPPED where = {};
    where.Offset = static_cast<DWORD>(at & 0xFFFFFFFF);
    where.OffsetHigh = static_cast<DWORD>(at >> 32);
    DWORD read = 0;
    BOOL ok = g_readFile(a.handle, a.buf, g_bufferSize, &read, &where);
    if (!ok && GetLastError() == ERROR_HANDLE_EOF) {
      ok = TRUE;
      read = 0;
    }
    InterlockedIncrement(&g_aheadRead);

    EnterCriticalSection(&s->lock);
    if (ok && read != 0 && !a.discard) {
      a.state = ReadAhead::kReady;
      a.len = read;
    } else {
      a.state = ReadAhead::kIdle;
    }
    a.discard = false;
    WakeAllConditionVariable(&s->aheadDone);
    LeaveCriticalSection(&s->lock);
    Release(s);
  }
}

// Asks the worker for the block at `at`, unless it already has it or is busy with another one.
// Needs s->lock, on the thread that owns the buffered handle `h`.
void ScheduleAhead(FileState* s, HANDLE h, std::int64_t at) {
  ReadAhead& a = s->ahead;
  if (a.disabled || a.state == ReadAhead::kInFlight) {
    return;
  }
  if (a.state == ReadAhead::kReady && a.start == at) {
    return;
  }
  if (a.state == ReadAhead::kQueued) {
    a.start = at;  // still in the queue: it will read the new place
    return;
  }
  if (a.handle == nullptr) {
    // A second handle to the same file, with its own file pointer. It shares everything, so the
    // game can still open, write, rename or delete the file as before.
    const DWORD error = GetLastError();
    const HANDLE own = ReOpenFile(h, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, 0);
    SetLastError(error);
    if (own == INVALID_HANDLE_VALUE) {
      a.disabled = true;
      InterlockedIncrement(&g_aheadNoHandle);
      return;
    }
    a.handle = own;
  }
  if (a.buf == nullptr) {
    a.buf = static_cast<std::uint8_t*>(std::malloc(g_bufferSize));
    if (a.buf == nullptr) {
      a.disabled = true;
      return;
    }
  }
  a.start = at;
  a.state = ReadAhead::kQueued;
  InterlockedIncrement(&s->refs);
  InterlockedIncrement(&g_aheadIssued);
  AcquireSRWLockExclusive(&g_queueLock);
  g_queue->push_back(s);
  ReleaseSRWLockExclusive(&g_queueLock);
  WakeConditionVariable(&g_queueReady);
}

// If the read-ahead block holds s->pos, makes it the buffer (waiting for it if the worker is
// reading it right now) and returns true. Needs s->lock.
bool TakeAhead(FileState* s) {
  ReadAhead& a = s->ahead;
  const auto covers = [&](DWORD len) { return s->pos >= a.start && s->pos < a.start + len; };
  if (a.state == ReadAhead::kQueued && covers(g_bufferSize)) {
    a.state = ReadAhead::kIdle;  // not started: reading it here is faster than waiting in line
    return false;
  }
  if (a.state == ReadAhead::kInFlight && covers(g_bufferSize)) {
    const LONGLONG start = Now();
    InterlockedIncrement(&g_aheadWaits);
    while (a.state == ReadAhead::kInFlight) {
      SleepConditionVariableCS(&s->aheadDone, &s->lock, INFINITE);
    }
    InterlockedAdd64(&g_aheadWaitTicks, Now() - start);
  }
  if (a.state != ReadAhead::kReady) {
    return false;
  }
  if (!covers(a.len)) {
    a.state = ReadAhead::kIdle;  // the game went elsewhere
    return false;
  }
  std::swap(s->buf, a.buf);
  s->bufStart = a.start;
  s->bufLen = a.len;
  a.state = ReadAhead::kIdle;
  InterlockedIncrement(&g_aheadUsed);
  return true;
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
  // Nobody else holds it once it is out of the table, except the worker for a moment.
  if (TryEnterCriticalSection(&s->lock)) {
    DropAhead(s);
    LeaveCriticalSection(&s->lock);
  }
  Release(s);
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
    const DWORD rest = n - done;
    if (g_readahead && s->buf != nullptr && TakeAhead(s)) {
      if (s->bufLen == g_bufferSize) {
        ScheduleAhead(s, h, s->bufStart + s->bufLen);
      }
      continue;
    }
    if (!SyncPointer(s, h)) {
      *got = done;
      return done != 0;
    }
    if (!s->buffered) {
      // Another thread used the handle while this one waited for the worker (TakeAhead releases
      // the lock): from here on the handle is plain Win32, so the rest is read straight.
      DWORD read = 0;
      const BOOL ok = g_readFile(h, out + done, rest, &read, nullptr);
      ++s->syscalls;
      s->pos += read;
      s->osPos = ok ? s->pos : -1;
      *got = done + read;
      return ok || *got != 0;
    }
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
    InterlockedIncrement(&g_refills);
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
    if (g_readahead && read == g_bufferSize) {
      ScheduleAhead(s, h, s->bufStart + read);
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
  if (g_readahead) {
    Log(L"bufferedFileReads readahead: %ld blocks asked of the worker, %ld read, %ld used by the game "
        L"(%ld waited for, %.1f ms in all); %ld buffer refills read on the game's thread; %ld files without "
        L"a second handle",
        g_aheadIssued, g_aheadRead, g_aheadUsed, g_aheadWaits, Ms(g_aheadWaitTicks), g_refills, g_aheadNoHandle);
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
      } else if (_stricmp(arg.c_str(), "readahead") == 0) {
        g_readahead = true;
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
  if (g_readahead) {
    g_queue = new std::deque<FileState*>();
    const HANDLE worker = CreateThread(nullptr, 64 * 1024, &AheadWorker, nullptr, STACK_SIZE_PARAM_IS_A_RESERVATION, nullptr);
    if (worker == nullptr) {
      Log(L"bufferedFileReads: no read-ahead thread (error %lu); buffering without it", GetLastError());
      g_readahead = false;
    } else {
      CloseHandle(worker);
    }
  }

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
    Log(L"bufferedFileReads: read-only files get a %lu KB read-ahead buffer (multiplayer-safe: same bytes)%ls%ls",
        g_bufferSize / 1024,
        g_readahead ? L"; readahead: a worker thread reads the next block of each file" : L"",
        g_verify ? L"; verify mode: every buffered read is checked against a real one" : L"");
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

namespace {
bool g_active = false;  // the routine replaces the stock loops in this run (not `verify`)
}  // namespace

bool FastVertexFillActive() { return g_active; }

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
    g_active = true;
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

## fastLastInLine

Contract: [fastLastInLine](../porting-to-another-dll.md#fastlastinline).

Besides the core helpers, it needs: [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `TechTemplateFallback` `0x48050F` (27 B), `LastInLineHead` `0x4918A8` (26 B), `PlayerCanObtainTechHead` `0x4C5725` (22 B), `PrereqListGet` `0x4C5DBD` (29 B), `LastInLineScan` `0x68FB0C` (326 B), `ProtoTechHasActivePrereq` `0x94BC1D` (76 B).

### src/features/lastinline.cpp

```cpp
// fastLastInLine [log] [verify]: the "last in line" recompute of a player's tech tree through an index.
//
// FUN_004918A8 (thiscall(tree, Player*), ret 4; called by the tech status update 0x491A40 at 0x491A39 for each live
// player on every world update, and by the forced update 0x852850) runs when the tree's byte [tree+11h] is set. That
// byte is set when a HomeCity tech changes status (activation 0x94CF27, obtainable 0x94C33A, unobtainable 0x94CDB3,
// through 0x94AE8C): every home city shipment. The recompute, in its cold chunk 0x68FB0C, sets or clears status bit 16
// ("last in line") of every entry of the tree:
//   - a null entry is left alone;
//   - bit 22 (ForceLastInLine) set: bit 16 set;
//   - else, if some other entry j (the template record [[db+5D9Ch]+0Ch]+24h*j when j's entry is null) has in its
//     definition's prerequisites a "TechStatus active <this tech>" (0x94BC1D) and the player can obtain j (0x4C5725):
//     bit 16 cleared;
//   - else bit 16 cleared when bit 32 (YPNeverLastInLine) is set, set otherwise.
// Then, for the local player ([game+3C0h]), the UI object [game+920h] gets its vtable slot 1 with 0.
// Finding "some other entry j" is a scan of every entry and its prerequisites: entries x (entries + prerequisites)
// tests, 1.7e8 in a 10,552-tech tree, about 300 ms; the scan runs again after every shipment of any player.
//
// The key computes the same bits with an index built from the template records once per data load: for each tech ID
// t, the techs j whose definition has a TechStatus prerequisite of type 1, status 2 (active) and tech t. For entry i
// it tests only those j, in ascending order, with the stock 0x94BC1D and 0x4C5725, so the decision is the stock one;
// it only skips the j that cannot pass the first test. Both tests write no memory (docs/performance.md, §9), so
// testing fewer of them changes nothing else. The bits are the same, so players may set the key differently.
//
// The hook replaces the head of 0x4918A8 (hooks/lastinline_hooks.asm). When the index does not match the tree (a
// tree of another size, no database) it hands the call to the stock code.
// `verify` lets the stock loop run as well: the key computes its bits first without writing them, and a second hook
// at the loop's exit (0x68FC1B) compares them with what the stock loop wrote, entry by entry, and logs the times of
// both. `log` writes a line per recompute.
#include <windows.h>

#include <cstdint>
#include <cstdlib>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database, +3C0h local player ID, +920h a UI object
constexpr std::uint32_t kRecordStride = 0x24;      // template status records, [[db+5D9Ch]+0Ch]
constexpr int kMaxMismatchLines = 20;
constexpr std::uint32_t kLastInLineScanExit = 0x0068FC1B;  // mov eax,[0C66234h], inside sites::kLastInLineScan

// bool thiscall(entry, techId), ret 4: the entry's definition has a "TechStatus active techId" prerequisite.
using HasActivePrereqFn = bool(__thiscall*)(const void* entry, std::int32_t techId);
const auto kHasActivePrereq = reinterpret_cast<HasActivePrereqFn>(0x0094BC1D);
// bool thiscall(Player*, techId), ret 4: the player can obtain the tech.
using CanObtainFn = bool(__thiscall*)(void* player, std::int32_t techId);
const auto kCanObtain = reinterpret_cast<CanObtainFn>(0x004C5725);
// void thiscall(ui, 0): what the stock recompute tail-jumps to for the local player.
using UiRefreshFn = void(__thiscall*)(void* ui, std::int32_t);

template <typename T>
T& Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<T*>(const_cast<char*>(static_cast<const char*>(base)) + offset);
}

char* Game() { return *reinterpret_cast<char**>(kGameGlobal); }

bool g_log = false;
bool g_verify = false;

// The index: g_first[t]..g_first[t+1] in g_dependents are the template indices j whose definition requires tech ID t
// active; slot `count` stands for the ID -1 (a prerequisite whose tech was not found, and what the stock loop uses
// for an entry without a definition). Built for one database, template array and count.
std::vector<std::uint32_t> g_first;
std::vector<std::int32_t> g_dependents;
bool g_built = false;
const char* g_builtDatabase = nullptr;
const char* g_builtRecords = nullptr;
std::int32_t g_builtCount = -1;

// Counters for the log.
std::uint64_t g_recomputes = 0;
std::uint64_t g_fallbacks = 0;
std::uint64_t g_tests = 0;
double g_ticksPerMs = 0.0;
std::int64_t g_ticks = 0;

// `verify`: the bits the key computed for the recompute in progress (0 = entry left alone, 1 = set, 2 = cleared).
std::vector<std::uint8_t> g_expected;
const void* g_pendingTree = nullptr;
std::int32_t g_pendingPlayer = -1;
LARGE_INTEGER g_stockStart{};
std::int64_t g_fastTicks = 0;
std::uint64_t g_checked = 0;
std::uint64_t g_checkedEntries = 0;
std::uint64_t g_mismatches = 0;
int g_mismatchLines = 0;

std::int64_t Now() {
  LARGE_INTEGER t{};
  QueryPerformanceCounter(&t);
  return t.QuadPart;
}

double Ms(std::int64_t ticks) { return g_ticksPerMs > 0.0 ? static_cast<double>(ticks) / g_ticksPerMs : 0.0; }

// A definition's prerequisites: array at def+1Ch, its length in the byte def+20h (0x94BC1D, 0x4C5DBD). A TechStatus
// prerequisite has type byte +5 = 1, status byte +0Ch (2 = active) and the tech ID at +8.
void Build(const char* database, const char* records, std::int32_t count) {
  g_first.assign(static_cast<std::size_t>(count) + 2, 0);
  g_dependents.clear();
  g_built = true;
  g_builtDatabase = database;
  g_builtRecords = records;
  g_builtCount = count;
  std::vector<std::vector<std::int32_t>> lists(static_cast<std::size_t>(count) + 1);
  std::size_t total = 0;
  std::size_t outOfRange = 0;
  for (std::int32_t j = 0; j < count; ++j) {
    const char* def = Field<const char*>(records, kRecordStride * static_cast<std::uint32_t>(j));
    if (def == nullptr) {
      continue;
    }
    const char* const* list = Field<const char* const*>(def, 0x1C);
    const std::uint8_t length = Field<std::uint8_t>(def, 0x20);
    for (std::uint8_t k = 0; list != nullptr && k < length; ++k) {
      const char* p = list[k];
      if (p == nullptr || Field<std::uint8_t>(p, 0x05) != 1 || Field<std::uint8_t>(p, 0x0C) != 2) {
        continue;
      }
      const std::int32_t target = Field<std::int32_t>(p, 0x08);
      if (target < -1 || target >= count) {
        ++outOfRange;  // matches no entry: their IDs are 0..count-1, or -1
        continue;
      }
      auto& l = lists[static_cast<std::size_t>(target == -1 ? count : target)];
      if (l.empty() || l.back() != j) {  // one entry per (target, j)
        l.push_back(j);
        ++total;
      }
    }
  }
  g_dependents.reserve(total);
  std::size_t named = 0;
  for (std::int32_t t = 0; t <= count; ++t) {
    g_first[static_cast<std::size_t>(t)] = static_cast<std::uint32_t>(g_dependents.size());
    const auto& l = lists[static_cast<std::size_t>(t)];
    named += l.empty() ? 0 : 1;
    g_dependents.insert(g_dependents.end(), l.begin(), l.end());
  }
  g_first[static_cast<std::size_t>(count) + 1] = static_cast<std::uint32_t>(g_dependents.size());
  uhc::Log(L"fastLastInLine: index of %d techs: %u named in a TechStatus active prerequisite, %u (tech, dependent) "
           L"pairs%ls",
           count, static_cast<unsigned>(named), static_cast<unsigned>(total),
           outOfRange != 0 ? L"; some prerequisites name a tech outside the tree and are ignored" : L"");
}

// From the database load hook: the next recompute builds the index of the new techtree.
void ResetForDataLoad(char*) { g_built = false; }

// The tech ID a status entry or template record stands for: [[x]+0], or -1 for a null definition (as the stock loop).
std::int32_t TechId(const void* entry) {
  const std::int32_t* def = Field<const std::int32_t*>(entry, 0x00);
  return def == nullptr ? -1 : *def;
}

// Computes bit 16 of every entry as the stock loop does. With `write`, writes it; otherwise stores it in g_expected.
// Returns false when the index does not fit this tree (the caller then runs the stock code).
bool Compute(const char* tree, void* player, bool write) {
  char* game = Game();
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  const char* templates = database == nullptr ? nullptr : Field<const char*>(database, 0x5D9C);
  const char* records = templates == nullptr ? nullptr : Field<const char*>(templates, 0x0C);
  const std::int32_t templateCount = templates == nullptr ? -1 : Field<std::int32_t>(templates, 0x10);
  const char* const* entries = Field<const char* const*>(tree, 0x04);
  const std::int32_t count = Field<std::int32_t>(tree, 0x08);
  if (records == nullptr || templateCount <= 0 || count != templateCount || entries == nullptr) {
    return false;
  }
  if (!g_built || database != g_builtDatabase || records != g_builtRecords || templateCount != g_builtCount) {
    Build(database, records, templateCount);
  }
  if (!write) {
    g_expected.assign(static_cast<std::size_t>(count), 0);
  }
  for (std::int32_t i = 0; i < count; ++i) {
    const char* e = entries[i];
    if (e == nullptr) {
      continue;
    }
    const std::uint32_t bitCount = Field<std::uint32_t>(e, 0x08);
    std::uint8_t* bits = Field<std::uint8_t*>(e, 0x04);
    bool set;
    if (bitCount > 0x16 && (bits[2] & 0x40) != 0) {  // ForceLastInLine
      set = true;
    } else {
      bool found = false;
      const std::int32_t id = TechId(e);
      if (id >= -1 && id < count) {
        const std::size_t slot = static_cast<std::size_t>(id == -1 ? count : id);
        const std::uint32_t end = g_first[slot + 1];
        for (std::uint32_t k = g_first[slot]; k < end && !found; ++k) {
          const std::int32_t j = g_dependents[k];
          if (j == i) {
            continue;
          }
          const char* pj = entries[j];
          if (pj == nullptr) {
            pj = records + kRecordStride * static_cast<std::uint32_t>(j);
          }
          ++g_tests;
          found = kHasActivePrereq(pj, id) && kCanObtain(player, TechId(pj));
        }
      }
      set = !found && !(bitCount > 0x20 && (bits[4] & 0x01) != 0);  // YPNeverLastInLine keeps it clear
    }
    if (write) {
      bits[2] = static_cast<std::uint8_t>(set ? (bits[2] | 0x01) : (bits[2] & 0xFE));
    } else {
      g_expected[static_cast<std::size_t>(i)] = set ? 1 : 2;
    }
  }
  return true;
}

void AtExit() {
  if (g_verify) {
    uhc::Log(L"fastLastInLine verify: %llu recomputes checked against the stock loop (%llu entries), %llu bits "
             L"differ",
             g_checked, g_checkedEntries, g_mismatches);
  } else {
    uhc::Log(L"fastLastInLine: %llu recomputes (%llu dependency tests, %.1f ms in all), %llu handed to the stock code",
             g_recomputes, g_tests, Ms(g_ticks), g_fallbacks);
  }
}

}  // namespace

extern "C" {

void UhcLastInLineHook();
void UhcLastInLineVerifyEndHook();

// From the head of 0x4918A8 (the player is not null, [tree+11h] is set). Returns 0 when it did the recompute (the
// hook returns), 1 when the stock code must run (the hook re-executes the head and enters it).
std::uint32_t __stdcall UhcLastInLine(char* tree, char* player) {
  const std::int64_t start = Now();
  if (g_verify) {
    g_pendingTree = nullptr;
    if (Compute(tree, player, false)) {
      g_pendingTree = tree;
      g_pendingPlayer = Field<std::int32_t>(player, 0x00);
      g_fastTicks = Now() - start;
      QueryPerformanceCounter(&g_stockStart);
    } else {
      ++g_fallbacks;
    }
    return 1;
  }
  if (!Compute(tree, player, true)) {
    ++g_fallbacks;
    return 1;
  }
  Field<std::uint8_t>(tree, 0x11) = 0;
  const std::int64_t ticks = Now() - start;
  g_ticks += ticks;
  ++g_recomputes;
  if (g_log) {
    uhc::Log(L"fastLastInLine: player %d, %d entries, %.2f ms", Field<std::int32_t>(player, 0x00),
             Field<std::int32_t>(tree, 0x08), Ms(ticks));
  }
  char* game = Game();
  void* ui = game == nullptr ? nullptr : Field<void*>(game, 0x920);
  if (ui != nullptr && Field<std::int32_t>(player, 0x00) == Field<std::int32_t>(game, 0x3C0)) {
    UiRefreshFn refresh = (*reinterpret_cast<UiRefreshFn**>(ui))[1];
    refresh(ui, 0);
  }
  return 0;
}

// `verify`, at the stock loop's exit 0x68FC1B (EBP = the tree): compares its bits with the key's.
void __stdcall UhcLastInLineCompare(const char* tree) {
  const std::int64_t stockTicks = Now() - g_stockStart.QuadPart;
  if (tree == nullptr || tree != g_pendingTree) {
    return;
  }
  g_pendingTree = nullptr;
  const char* const* entries = Field<const char* const*>(tree, 0x04);
  const std::int32_t count = Field<std::int32_t>(tree, 0x08);
  std::uint64_t differ = 0;
  for (std::int32_t i = 0; i < count && static_cast<std::size_t>(i) < g_expected.size(); ++i) {
    const char* e = entries[i];
    const std::uint8_t want = g_expected[static_cast<std::size_t>(i)];
    if (e == nullptr || want == 0) {
      if ((e == nullptr) != (want == 0)) {
        ++differ;
      }
      continue;
    }
    const bool stockSet = (Field<const std::uint8_t*>(e, 0x04)[2] & 0x01) != 0;
    if (stockSet != (want == 1)) {
      ++differ;
      if (g_mismatchLines < kMaxMismatchLines) {
        ++g_mismatchLines;
        uhc::Log(L"fastLastInLine verify: MISMATCH, player %d, entry %d (tech %d): stock %ls bit 16, the key %ls it",
                 g_pendingPlayer, i, TechId(e), stockSet ? L"set" : L"cleared", want == 1 ? L"sets" : L"clears");
      }
    }
  }
  ++g_checked;
  g_checkedEntries += static_cast<std::uint64_t>(count);
  g_mismatches += differ;
  uhc::Log(L"fastLastInLine verify: player %d, %d entries: %llu bits differ; the key %.2f ms, the stock loop %.1f ms",
           g_pendingPlayer, count, differ, Ms(g_fastTicks), Ms(stockTicks));
}
}

namespace uhc {

Outcome ApplyFastLastInLine(const Config& config) {
  const auto* args = config.First("fastLastInLine");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "verify") == 0) {
      g_verify = true;
    } else {
      Log(L"fastLastInLine: unknown argument '%hs' (expected: [log] [verify]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("fastLastInLine", {&sites::kLastInLineHead, &sites::kLastInLineScan,
                                       &sites::kProtoTechHasActivePrereq, &sites::kPrereqListGet,
                                       &sites::kPlayerCanObtainTechHead, &sites::kTechTemplateFallback})) {
    return Outcome::kFailed;
  }
  LARGE_INTEGER frequency{};
  if (QueryPerformanceFrequency(&frequency) && frequency.QuadPart > 0) {
    g_ticksPerMs = static_cast<double>(frequency.QuadPart) / 1000.0;
  }
  if (!OnDatabaseLoad(&ResetForDataLoad)) {
    return Outcome::kFailed;
  }
  if (g_verify &&
      !WriteJmp(kLastInLineScanExit, reinterpret_cast<const void*>(&UhcLastInLineVerifyEndHook), 5)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kLastInLineHead.va, reinterpret_cast<const void*>(&UhcLastInLineHook), 9)) {
    return Outcome::kFailed;
  }
  std::atexit(AtExit);
  if (g_verify) {
    Log(L"fastLastInLine: verify mode: the stock loop recomputes \"last in line\" and every recompute is compared with "
        L"the key's");
  } else {
    Log(L"fastLastInLine: \"last in line\" is recomputed through an index of the TechStatus prerequisites%ls (same "
        L"bits as stock)",
        g_log ? L", log" : L"");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/lastinline_hooks.asm

```asm
; fastLastInLine (src/features/lastinline.cpp). Each hook is entered through a jmp written over the stock code,
; replaces or re-executes what it overwrote, and leaves through an explicit jmp to a verified continuation or a ret
; that the stock function would have made itself.
.686
.model flat, c
option casemap :none

include common.inc

UhcLastInLine PROTO STDCALL tree:DWORD, player:DWORD
UhcLastInLineCompare PROTO STDCALL tree:DWORD

.data
stockDirtyTest  dd 004918B3h    ; cmp byte ptr [ebp+11h],0 / jne 68FB0Ch, then pop ebp / pop ecx / ret 4
scanExitNext    dd 0068FC20h    ; mov ecx,[eax+920h]: after the mov eax,[0C66234h] the verify hook replaces

.code

; Replaces 0x4918A8..0x4918B0 (push ecx / cmp dword ptr [esp+8],0 / push ebp / mov ebp,ecx), the head of the
; LastInLine recompute, thiscall(tree = ECX, Player* = [esp+4]), ret 4. With no player or a clean tree it returns
; as the stock code does (the stock pushes and pops ECX and EBP and writes nothing). Otherwise the C++ recompute runs;
; when it returns 1 (verify, or an index that does not fit the tree) the head is re-executed and the stock dirty
; test at 0x4918B3 takes over, with the stack laid out as the stock code expects: EBP and ECX pushed, EBP = the tree.
; EAX, ECX and EDX are free in a thiscall; EBX, ESI, EDI and EBP are preserved by the stdcall.
UhcLastInLineHook PROC
    TRACE_ONCE "fastLastInLine (0x4918A8)"
    cmp dword ptr [esp+4], 0        ; the player, as the stolen cmp [esp+8],0 after push ecx
    je done
    cmp byte ptr [ecx+11h], 0       ; the dirty byte, as 0x4918B3
    je done
    push ecx                        ; keep the tree
    push dword ptr [esp+8]          ; Player*
    push ecx                        ; tree
    call UhcLastInLine
    pop ecx
    test eax, eax
    jnz stock
done:
    ret 4
stock:
    push ecx                        ; stolen 0x4918A8
    push ebp                        ; stolen 0x4918AE
    mov ebp, ecx                    ; stolen 0x4918AF
    jmp stockDirtyTest
UhcLastInLineHook ENDP

; `verify`: replaces mov eax,[0C66234h] at 0x68FC1B, where the stock loop ends (from its last iteration, and from
; jle 68FC1Bh at 0x68FB16 when the tree is empty). EBP = the tree. Compares, re-executes the instruction and goes on.
UhcLastInLineVerifyEndHook PROC
    TRACE_ONCE "fastLastInLine verify (0x68FC1B)"
    pushad
    pushfd
    push ebp
    call UhcLastInLineCompare
    popfd
    popad
    mov eax, dword ptr ds:[00C66234h]   ; stolen 0x68FC1B
    jmp scanExitNext
UhcLastInLineVerifyEndHook ENDP

END
```

## rendererOption

Contract: [rendererOption](../porting-to-another-dll.md#rendereroption).

### src/features/renderer.cpp

```cpp
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
```

## menuOptions

Contract: [menuOptions](../porting-to-another-dll.md#menuoptions).

Sites: `OptionIntGetter` `0x402E6A` (58 B), `OptionIntSetter` `0x518AE0` (77 B), `OptionTypeGetter` `0x553028` (28 B), `OptionIntGetRange` `0x6B7676` (5 B), `OptionTypeRange` `0x6B794B` (5 B), `OptionNameLookup` `0x932264` (70 B).

### src/menuoptions.h

```cpp
// Options of this DLL in the game's options menu, with nothing added to the game's option table or the profile.
//
// data\options.xml names an option variable per field; the screen resolves the name through 0x932264 on the
// "GameOptions" settings object, then reads the value through 0x553028 (type) and 0x402E6A (int) and writes it on
// Apply through 0x518AE0. That object holds a fixed list of 93 options. A name lookup that finds nothing answers a
// virtual ID for a registered option name (kFirstVirtualId upward, one per option, in the order they are added), and
// the three accessors' out-of-range paths serve those IDs from this module (src/hooks/menuoptions_hooks.asm). Each
// option is an int: the index of the dropdown's entry (0 = the first <value>). The choice is kept in kOptionsFile
// (uhc-options.cfg next to the log), one line `<store key> <value word>` per option, and is used at the next start.
//
// Two kinds of users:
// - a key that owns an option (rendererOption) calls AddMenuOption and reads the value itself;
// - an on/off key of kMenuSwitches (menuoptions.cpp) follows the menu when the cfg names it on a `menuOptions` line:
//   ApplyMenuSwitches decides it before any key applies. A key not named there follows its cfg line alone.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "config.h"

namespace uhc {

// Keep in step with FIRST_VIRTUAL_ID in hooks/menuoptions_hooks.asm.
inline constexpr std::int32_t kFirstVirtualId = 0x55480001;
inline constexpr int kMaxMenuOptions = 16;

struct MenuOption {
  const char* feature;                // the key, for the log
  const wchar_t* name;                // the field's <name> in data\options.xml, e.g. L"OptionRenderer"; any case
  const char* storeKey;               // the first word of its line in uhc-options.cfg, e.g. "renderer"
  std::vector<const char*> words;     // the stored word of each entry, by index (e.g. "dx9", "vulkan")
  std::vector<const wchar_t*> labels; // the same entries for the log (e.g. L"DirectX 9", L"Vulkan")
  bool log = false;                   // log every read and Apply, not only the first read
};

// Registers an option. The first call verifies and hooks the four menu sites. Returns the option's slot, or -1
// (logged) if the sites are not stock, the table is full or the name is taken.
int AddMenuOption(const MenuOption& option);

// The value stored in uhc-options.cfg for this option: an entry's index, or -1 if there is none or it is not one
// of the option's words.
int MenuOptionStored(int slot);

// What the menu shows from now on. With `store`, also writes it to uhc-options.cfg (false if that failed).
bool SetMenuOptionValue(int slot, int value, bool store);

// The full path of uhc-options.cfg.
std::wstring MenuOptionsPath();

// menuOptions <key> [<key> ...], before any key applies: each key named gets an entry, and is kept or added (on) or
// removed (off) in `config` by the player's stored choice. Until the player chooses, its own cfg line decides:
// present, on (with its arguments); absent, off. A chosen "on" without a cfg line applies the key with no arguments.
void ApplyMenuSwitches(Config& config);

}  // namespace uhc
```

### src/menuoptions.cpp

```cpp
// The options menu's registry (menuoptions.h). The hooks are in hooks/menuoptions_hooks.asm.
#include "menuoptions.h"

#include <windows.h>

#include <cctype>
#include <cwchar>

#include "generated/sites.h"
#include "hostfiles.h"
#include "log.h"
#include "patch.h"
#include "startup.h"

extern "C" {
void UhcMenuNameHook();
void UhcMenuTypeHook();
void UhcMenuGetHook();
void UhcMenuSetHook();

// Read by the hooks: the number of options, and each one's value (the dropdown's index), by slot. The count is
// raised only once the slot's value is in place.
std::int32_t g_uhcMenuOptionCount = 0;
std::int32_t g_uhcMenuOptionValues[uhc::kMaxMenuOptions] = {};
}

namespace uhc {
namespace {

// The on/off keys that menuOptions may hand to the menu. One line per key: the key, the field's <name> in
// data\options.xml. The stored line is `<key> on|off`. Only keys that change nothing of the simulation belong here,
// since each player chooses alone.
struct MenuSwitch {
  const char* key;
  const wchar_t* name;
};
constexpr MenuSwitch kMenuSwitches[] = {
    {"bufferedFileReads", L"OptionBufferedReads"},
    {"fastVertexFill", L"OptionFastVertexFill"},
    {"fastLastInLine", L"OptionFastLastInLine"},
};

constexpr std::uint32_t kSettingsKind = 0x24;  // [settings+24h]: 1 for the options settings (FUN_00518CC9)

struct Slot {
  MenuOption option;
  bool lookupLogged = false;
};

Slot g_slots[kMaxMenuOptions];
int g_hooks = 0;  // 0 not tried, 1 installed, -1 failed

std::string Lower(std::string s) {
  for (char& c : s) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  return s;
}

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

// Splits the file into lines without their line ends.
std::vector<std::string> Lines(const std::string& text) {
  std::vector<std::string> lines;
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
    lines.push_back(std::move(line));
  }
  return lines;
}

// True if the line is the option's: its store key, then a space.
bool IsLineOf(const std::string& line, const MenuOption& option) {
  const std::string prefix = Lower(option.storeKey) + " ";
  return Lower(line).rfind(prefix, 0) == 0;
}

const wchar_t* Label(const MenuOption& option, int value) {
  return value >= 0 && value < static_cast<int>(option.labels.size()) ? option.labels[value] : L"?";
}

bool Store(const MenuOption& option, int value) {
  const std::wstring path = MenuOptionsPath();
  std::string out;
  bool replaced = false;
  const std::string line = std::string(option.storeKey) + " " + option.words[value];
  for (const std::string& old : Lines(ReadText(path))) {
    if (IsLineOf(old, option)) {
      if (!replaced) {
        out += line + "\r\n";
        replaced = true;
      }
      continue;
    }
    out += old + "\r\n";
  }
  if (out.empty()) {
    out = "# The game's options menu writes this file: one option per line, used at the next start.\r\n";
  }
  if (!replaced) {
    out += line + "\r\n";
  }
  if (!WriteText(path, out)) {
    Log(L"%hs: cannot write %ls (error %lu)", option.feature, path.c_str(), GetLastError());
    return false;
  }
  return true;
}

bool InstallHooks() {
  if (g_hooks != 0) {
    return g_hooks > 0;
  }
  g_hooks = -1;
  if (!VerifyAll("menu options", {&sites::kOptionNameLookup, &sites::kOptionTypeGetter, &sites::kOptionTypeRange,
                                  &sites::kOptionIntGetter, &sites::kOptionIntGetRange, &sites::kOptionIntSetter})) {
    return false;
  }
  if (!WriteJmp(sites::kOptionNameLookup.va + 0x3D, reinterpret_cast<const void*>(&UhcMenuNameHook), 5) ||
      !WriteJmp(sites::kOptionTypeRange.va, reinterpret_cast<const void*>(&UhcMenuTypeHook), 5) ||
      !WriteJmp(sites::kOptionIntGetRange.va, reinterpret_cast<const void*>(&UhcMenuGetHook), 5) ||
      !WriteJmp(sites::kOptionIntSetter.va + 0x46, reinterpret_cast<const void*>(&UhcMenuSetHook), 5)) {
    return false;
  }
  g_hooks = 1;
  return true;
}

}  // namespace

std::wstring MenuOptionsPath() { return ExeFolder() + kOptionsFile; }

int AddMenuOption(const MenuOption& option) {
  const int slot = g_uhcMenuOptionCount;
  if (slot >= kMaxMenuOptions) {
    Log(L"%hs: no room for %ls in the options menu (%d options at most)", option.feature, option.name,
        kMaxMenuOptions);
    return -1;
  }
  for (int i = 0; i < slot; ++i) {
    if (_wcsicmp(g_slots[i].option.name, option.name) == 0) {
      Log(L"%hs: the options menu already has %ls (%hs)", option.feature, option.name, g_slots[i].option.feature);
      return -1;
    }
  }
  if (!InstallHooks()) {
    Log(L"%hs: the options menu's sites are not stock; no %ls entry", option.feature, option.name);
    return -1;
  }
  g_slots[slot].option = option;
  g_uhcMenuOptionValues[slot] = 0;
  g_uhcMenuOptionCount = slot + 1;
  return slot;
}

int MenuOptionStored(int slot) {
  const MenuOption& option = g_slots[slot].option;
  for (const std::string& line : Lines(ReadText(MenuOptionsPath()))) {
    if (!IsLineOf(line, option)) {
      continue;
    }
    std::string value = Lower(line.substr(std::char_traits<char>::length(option.storeKey) + 1));
    while (!value.empty() && (value.back() == ' ' || value.back() == '\t')) {
      value.pop_back();
    }
    for (std::size_t i = 0; i < option.words.size(); ++i) {
      if (value == option.words[i]) {
        return static_cast<int>(i);
      }
    }
  }
  return -1;
}

bool SetMenuOptionValue(int slot, int value, bool store) {
  g_uhcMenuOptionValues[slot] = value;
  return !store || Store(g_slots[slot].option, value);
}

extern "C" std::int32_t __stdcall UhcMenuOptionLookup(const wchar_t* name, const std::uint8_t* settings) {
  if (name == nullptr || *reinterpret_cast<const std::uint32_t*>(settings + kSettingsKind) != 1) {
    return -1;
  }
  for (int i = 0; i < g_uhcMenuOptionCount; ++i) {
    Slot& slot = g_slots[i];
    if (_wcsicmp(name, slot.option.name) != 0) {
      continue;
    }
    if (slot.option.log || !slot.lookupLogged) {
      slot.lookupLogged = true;
      Log(L"%hs: options screen field %ls (settings 0x%08X, %u options); shows %ls", slot.option.feature, name,
          static_cast<unsigned>(reinterpret_cast<std::uintptr_t>(settings)),
          *reinterpret_cast<const std::uint32_t*>(settings + 8), Label(slot.option, g_uhcMenuOptionValues[i]));
    }
    return kFirstVirtualId + i;
  }
  return -1;
}

extern "C" void __stdcall UhcMenuOptionSet(std::int32_t index, std::int32_t value) {
  const MenuOption& option = g_slots[index].option;
  if (value < 0 || value >= static_cast<int>(option.words.size())) {
    Log(L"%hs: the menu wrote %d to %ls; ignored (it has %zu entries)", option.feature, value, option.name,
        option.words.size());
    return;
  }
  if (value == g_uhcMenuOptionValues[index]) {
    if (option.log) {
      Log(L"%hs: Apply, still %ls", option.feature, Label(option, value));
    }
    return;
  }
  const bool stored = SetMenuOptionValue(index, value, true);
  Log(L"%hs: %ls chosen in the menu%ls; it takes effect at the next start", option.feature, Label(option, value),
      stored ? L"" : L" (NOT stored)");
}

void ApplyMenuSwitches(Config& config) {
  const std::vector<Config::Args>* lines = config.All("menuOptions");
  if (lines == nullptr) {
    return;
  }
  constexpr std::size_t kCount = sizeof(kMenuSwitches) / sizeof(kMenuSwitches[0]);
  int following = 0;
  bool failed = false;
  bool named[kCount] = {};
  for (const Config::Args& args : *lines) {
    for (const std::string& word : args) {
      bool found = false;
      for (std::size_t i = 0; i < kCount; ++i) {
        if (_stricmp(word.c_str(), kMenuSwitches[i].key) == 0) {
          named[i] = found = true;
        }
      }
      if (!found) {
        std::string known;
        for (const MenuSwitch& menuSwitch : kMenuSwitches) {
          known += known.empty() ? "" : ", ";
          known += menuSwitch.key;
        }
        Log(L"menuOptions: %hs cannot follow the options menu (these can: %hs); ignored", word.c_str(),
            known.c_str());
        failed = true;
      }
    }
  }
  for (std::size_t i = 0; i < kCount; ++i) {
    if (!named[i]) {
      continue;
    }
    const MenuSwitch& menuSwitch = kMenuSwitches[i];
    // Until the player chooses, the key's own line decides: present, on; absent, off.
    const bool inCfg = config.Has(menuSwitch.key);
    const int slot = AddMenuOption({menuSwitch.key, menuSwitch.name, menuSwitch.key, {"off", "on"}, {L"off", L"on"}});
    if (slot < 0) {
      Log(L"menuOptions: %hs: no menu entry; the cfg alone decides", menuSwitch.key);
      failed = true;
      continue;
    }
    ++following;
    const int stored = MenuOptionStored(slot);
    const int value = stored >= 0 ? stored : (inCfg ? 1 : 0);
    SetMenuOptionValue(slot, value, false);
    Log(L"menuOptions: %hs follows %ls: %ls (%ls)", menuSwitch.key, menuSwitch.name, value != 0 ? L"on" : L"off",
        stored >= 0         ? L"the player's choice"
        : inCfg             ? L"no choice stored yet: its cfg line"
                            : L"no choice stored yet: no cfg line");
    if (value == 0 && inCfg) {
      config.Erase(menuSwitch.key);
    } else if (value != 0 && !inCfg) {
      config.Add(menuSwitch.key);  // with its defaults
    }
  }
  Log(L"menuOptions: %hs (%d keys follow the options menu)", failed ? "FAILED" : "applied", following);
}

}  // namespace uhc
```

### src/hooks/menuoptions_hooks.asm

```asm
; The options menu's registry (src/menuoptions.h): virtual options such as OptionRenderer. The game's option values
; live in a settings object (vtable 0BA3854h) with a fixed list of 93 entries; every accessor checks the ID against
; [settings+8] and fails beyond it. These hooks take over that failure path for the IDs FIRST_VIRTUAL_ID to
; FIRST_VIRTUAL_ID + g_uhcMenuOptionCount - 1, which the game never uses and only the name lookup hook hands out.
; The game's own IDs never reach the new code but through the stock failure paths, which return as before.
.686
.model flat, c
option casemap :none

include common.inc

UhcMenuOptionLookup PROTO STDCALL optionName:DWORD, settings:DWORD
UhcMenuOptionSet PROTO STDCALL slot:DWORD, value:DWORD

EXTERNDEF g_uhcMenuOptionCount:DWORD
EXTERNDEF g_uhcMenuOptionValues:DWORD

; The first virtual option's ID: far beyond the 93 entries, and none of the IDs the options screen maps itself
; (9, 0Ah, 30h). Keep it in step with kFirstVirtualId in menuoptions.h.
FIRST_VIRTUAL_ID EQU 55480001h

.data
lookupNext  dd 009322A6h    ; pop ecx / ret 4: the end of the name lookup

.code

; The name lookup 0x932264 (thiscall(settings, const wchar_t* name), ret 4) found no entry; it would return -1.
; On entry EDI = the name (may be null), ESI = settings+234h (its name map); [esp] the saved EDI, [esp+4] the saved
; ESI. Replaces pop edi / or eax,-1 / pop esi. EAX = -1 or a virtual ID; ECX and EDX are free (the caller is told
; nothing of them: the function ends with pop ecx / ret 4).
UhcMenuNameHook PROC
    TRACE_ONCE "menu options: option name lookup miss (0x9322A1)"
    lea eax, [esi-234h]
    push eax
    push edi
    call UhcMenuOptionLookup
    pop edi
    pop esi
    jmp dword ptr [lookupNext]
UhcMenuNameHook ENDP

; The type getter 0x553028 (thiscall(settings, id) -> al, ret 4) was given an ID beyond the entries. On entry
; EAX = the ID, ECX = settings. Replaces xor al,al / ret 4. A virtual option is an int (type 2). Only EAX and the
; flags change, and on the stock path EAX keeps its upper bytes.
UhcMenuTypeHook PROC
    sub eax, FIRST_VIRTUAL_ID
    cmp eax, g_uhcMenuOptionCount
    jae notOurs
    TRACE_ONCE "menu options: option type (0x6B794B)"
    mov al, 2
    ret 4
notOurs:
    add eax, FIRST_VIRTUAL_ID
    xor al, al
    ret 4
UhcMenuTypeHook ENDP

; The int getter 0x402E6A (thiscall(settings, id, int* out) -> al, ret 8) was given an ID beyond the entries. On
; entry EAX = settings, ECX = the ID, [esp+8] = out. Replaces xor al,al / ret 8. On the stock path ECX is the ID
; again on return.
UhcMenuGetHook PROC
    sub ecx, FIRST_VIRTUAL_ID
    cmp ecx, g_uhcMenuOptionCount
    jae notOurs
    TRACE_ONCE "menu options: option read (0x6B7676)"
    mov eax, [esp+8]
    mov ecx, g_uhcMenuOptionValues[ecx*4]
    mov [eax], ecx
    mov al, 1
    ret 8
notOurs:
    add ecx, FIRST_VIRTUAL_ID
    xor al, al
    ret 8
UhcMenuGetHook ENDP

; The int setter 0x518AE0 (thiscall(settings, id, int value) -> al, ret 8) failed: an ID beyond the entries
; (0x518AEB) or not an int (0x518B15). On entry EDI = the ID; [esp] the saved EDI, [esp+4] the saved ESI, [esp+0Ch]
; the ID, [esp+10h] the value. Replaces pop edi / xor al,al / pop esi / ret 8. ECX and EDX are volatile across the
; call, as in stock. EDI is restored from the stack on both paths, so it holds the slot meanwhile.
UhcMenuSetHook PROC
    sub edi, FIRST_VIRTUAL_ID
    cmp edi, g_uhcMenuOptionCount
    jae notOurs
    TRACE_ONCE "menu options: option write (0x518B26)"
    push dword ptr [esp+10h]
    push edi
    call UhcMenuOptionSet
    pop edi
    mov al, 1
    pop esi
    ret 8
notOurs:
    pop edi
    xor al, al
    pop esi
    ret 8
UhcMenuSetHook ENDP

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

## lanAutoStart

Contract: [lanAutoStart](../porting-to-another-dll.md#lanautostart).

Sites: `BStringFree` `0x4010CA` (31 B), `BStringFromWide` `0x401A12` (40 B), `LanGameClock` `0x402DFF` (13 B), `LanGadgetLookup` `0x40423C` (10 B), `LanScreenResolve` `0x40439A` (28 B), `LanConsoleExecute` `0x433D0D` (7 B), `LanGadgetShownFlag` `0x447BBF` (8 B), `LanScreenLookup` `0x44BEDD` (33 B), `LanDropdownSelect` `0x5C36AE` (10 B), `LanDoMpSetupLan` `0x6F0C09` (36 B), `LanBrowserRulesFill` `0x8BA863` (11 B), `LanBrowserCountdown` `0x8BA87A` (17 B), `LanBrowserNameGadget` `0x8BB096` (6 B), `LanBrowserModeGadget` `0x8BB0B1` (6 B), `LanBrowserHostGadget` `0x8BB0E7` (6 B), `LanBrowserIpGadget` `0x8BB138` (6 B), `LanBrowserRulesGadget` `0x8BB1A4` (6 B), `LanBrowserJoinIp` `0x8BB710` (17 B), `LanBrowserJoinRequest` `0x8BB749` (14 B), `LanBrowserJoinStart` `0x8BB762` (6 B), `LanBrowserSession` `0x8BBAB3` (6 B), `LanBrowserSetText` `0x8BBB06` (15 B), `LanBrowserHost` `0x8BBD88` (22 B), `LanBrowserClickHost` `0x8BC555` (5 B), `LanBrowserClickHostNext` `0x8BC55E` (2 B), `LanBrowserClickJoinIp` `0x8BC569` (7 B), `LanLoginDescriptorHandle` `0x8BCEB5` (9 B), `LanLoginScreenBrowser` `0x8BD4DF` (3 B), `LanDropdownCurrent` `0xAC0D1B` (13 B), `LanLoginScreenInit` `0xB957D0` (4 B).

### src/features/lanautostart.cpp

```cpp
// lanAutoStart: takes the game from the main menu to a LAN game with no clicks, for a launcher that has already
// agreed with the other players on who hosts. Either it hosts a game, or it joins the host's game by Direct IP.
//
//   lanAutoStart                 the action comes from the game's command line (below); nothing without one
//   lanAutoStart host [rules=N]  host a LAN game, with that Game Rules entry (0 = the first)
//   lanAutoStart join <address>  join the game hosted at <address> (Direct IP)
//
// On the command line, `+uhcLanHost` hosts and `uhcLanJoin="<address>"` joins, the syntax of the stock
// `OverrideAddress="<address>"`; `uhcLanRules=N` picks the host's Game Rules entry. The command line wins over the cfg's arguments. For a VPN such as Radmin, the
// launcher passes OverrideAddress (the host's VPN address, so the game binds there) and gives the joiners that
// address in uhcLanJoin.
//
// Stock route (docs/how-it-works.md, lanAutoStart): the console command doMPSetup(false) sets the SkirmHomeCity
// screen's next screen to MPLoginScreen and opens it (FUN_006F0BEE); that screen's Play switches to it.
// MPLoginScreen keeps the handle of MPLanBrowserDialog (uimplanip.xml, "LAN / Direct IP") at [screen+54h]. The
// dialog's activation creates the LAN browser [dlg+1ACh]; its click switch calls 0x8BBD88(dlg, 0) for Host and
// 0x8BB710(dlg) for Join IP, which reads the MPLanIP-DirectIPEditBox gadget [dlg+17Ch]. This key does what the
// clicks do: the console command, the screen switch, the edit box's text through the gadget's set-text slot
// (vtable +80h, the call the activation makes for the game name), then the button's routine. It writes nothing
// in the exe; every address it calls is verified first.
#include <windows.h>

#include <cstdint>
#include <cstring>
#include <cwchar>
#include <cwctype>
#include <string>

#include "../d3d9hooks.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace uhc {
namespace {

constexpr std::uint32_t kUiGlobal = 0x00C66244;          // [+44h] gadget manager, [+60h] screen manager
constexpr std::uint32_t kConsoleObject = 0x00C672E4;
constexpr std::uint32_t kLoginScreenVtable = 0x00B95788;  // MPLoginScreen (slot 18: its init 0x8BD408)
constexpr std::uint32_t kLanBrowserVtable = 0x00B8CE10;   // MPLanBrowserDialog
constexpr std::int32_t kSkirmHomeCityScreen = 0x36;
constexpr std::int32_t kEditBoxType = 0x23;              // the type FUN_004420BA asks 0x40423C for
constexpr std::int32_t kDropdownType = 0x0D;             // the type FUN_0046AC10 asks 0x40423C for
// FUN_008BA62E adds exactly entries 0..7 to the Game Rules dropdown (Standard, Classic, four treaties, treaty with
// no blockade, King of the Hill). [dropdown+19Ch] counts per-entry data, which this list does not have.
constexpr std::int32_t kRulesEntries = 8;

struct BString {
  wchar_t* text;
};

using ExecuteCommandFn = int(__fastcall*)(void* console, void* edx, const char* command, const char* source);
using GadgetLookupFn = void*(__fastcall*)(void* manager, void* edx, std::int32_t handle, std::int32_t type);
using SwitchScreenFn = void(__fastcall*)(void* manager, void* edx, std::int32_t id, std::int32_t flag);
using SetTextFn = void(__fastcall*)(void* gadget, void* edx, const BString* text);
using HostFn = void(__fastcall*)(void* dialog, void* edx, std::int32_t flag);
using JoinIpFn = void(__fastcall*)(void* dialog, void* edx);
using BStringFromWideFn = BString*(__fastcall*)(BString* self, void* edx, const wchar_t* text);
using BStringFreeFn = void(__fastcall*)(BString* self, void* edx);
using ScreenResolveFn = void*(__cdecl*)(std::int32_t handle);
using DropdownSelectFn = void(__fastcall*)(void* dropdown, void* edx, std::int32_t index, std::int32_t flag);
using DropdownCurrentFn = std::int32_t(__fastcall*)(void* dropdown, void* edx);
using ClockFn = std::uint32_t(__cdecl*)();

const auto kExecuteCommand = reinterpret_cast<ExecuteCommandFn>(0x00433D0D);
const auto kGadgetLookup = reinterpret_cast<GadgetLookupFn>(0x0040423C);
const auto kHost = reinterpret_cast<HostFn>(0x008BBD88);
const auto kJoinIp = reinterpret_cast<JoinIpFn>(0x008BB710);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kScreenResolve = reinterpret_cast<ScreenResolveFn>(0x0040439A);
const auto kDropdownSelect = reinterpret_cast<DropdownSelectFn>(0x005C36AE);
const auto kDropdownCurrent = reinterpret_cast<DropdownCurrentFn>(0x00AC0D1B);
const auto kGameClock = reinterpret_cast<ClockFn>(0x00402DFF);

enum class Action { kNone, kHost, kJoin };
enum class Step { kWaitMenu, kAfterSetup, kWaitDialog, kSettle, kJoinRetry, kDone };

Action g_action = Action::kNone;
std::wstring g_address;
Step g_step = Step::kWaitMenu;
ULONGLONG g_firstFrame = 0;
ULONGLONG g_stepStart = 0;
int g_attempts = 0;
constexpr int kMaxAttempts = 3;
constexpr ULONGLONG kMenuDelayMs = 3000;      // after the first frame, so the main menu is up
constexpr ULONGLONG kSetupDelayMs = 1500;     // doMPSetup -> the home city screen
constexpr ULONGLONG kDialogTimeoutMs = 15000;
constexpr ULONGLONG kSettleMs = 750;          // the dialog's activation done and drawn once
constexpr ULONGLONG kGiveUpMs = 120000;
// Every copy is launched at once, so a joiner can press Connect before the host's game exists: the stock answer is
// "game not found" and the LAN screen stays. While it stays, Connect is pressed again, never while the game is still
// waiting for an answer to the last one (its countdown), for at most kJoinWindowMs.
constexpr ULONGLONG kJoinRetryMs = 3000;
// A joiner waits this much longer before its first Connect: the host loads the same game and hosts about a second
// after its own dialog opens, so the first Connect then usually finds the game. A Connect that times out shows the
// game's single message dialog ("No game was found"); a later one only rewrites it, it never stacks (0x5183C6).
constexpr ULONGLONG kJoinFirstDelayMs = 5000;
constexpr ULONGLONG kJoinWindowMs = 180000;
int g_joins = 0;
ULONGLONG g_firstJoin = 0;
// The host's Game Rules entry; -1 leaves the game's own choice.
std::int32_t g_rules = -1;

template <typename T>
T Read(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

char* Ui() { return *reinterpret_cast<char* const*>(kUiGlobal); }
void* ScreenManager() { return Ui() == nullptr ? nullptr : Read<void*>(Ui(), 0x60); }
void* GadgetManager() { return Ui() == nullptr ? nullptr : Read<void*>(Ui(), 0x44); }

std::uint32_t Vtable(const void* object) { return object == nullptr ? 0 : Read<std::uint32_t>(object, 0); }

// The screen manager's list, as FUN_0044BEDD walks it (count [+8], array [+4], ID [screen+0Ch]); read here so a
// missing screen is not the lookup's assert path.
void* FindScreen(bool (*match)(void* screen, std::int32_t id), std::int32_t id) {
  void* manager = ScreenManager();
  if (manager == nullptr) {
    return nullptr;
  }
  const std::int32_t count = Read<std::int32_t>(manager, 8);
  void* const* screens = Read<void* const*>(manager, 4);
  if (count <= 0 || count > 512 || screens == nullptr) {
    return nullptr;
  }
  for (std::int32_t i = 0; i < count; ++i) {
    if (screens[i] != nullptr && match(screens[i], id)) {
      return screens[i];
    }
  }
  return nullptr;
}

bool ById(void* screen, std::int32_t id) { return Read<std::int32_t>(screen, 0x0C) == id; }

// The screen doMPSetup(false) makes the home city screen's next one (mov [eax+3Ch],2Eh, site LanDoMpSetupLan).
constexpr std::int32_t kLoginScreen = 0x2E;

// The list holds descriptors; the screen is the handle at [descriptor+4], resolved by 0x40439A.
void* LoginScreen() {
  void* descriptor = FindScreen(&ById, kLoginScreen);
  if (descriptor == nullptr) {
    return nullptr;
  }
  void* screen = kScreenResolve(Read<std::int32_t>(descriptor, 4));
  return Vtable(screen) == kLoginScreenVtable ? screen : nullptr;
}

void LogScreens() {
  void* manager = ScreenManager();
  if (manager == nullptr) {
    return;
  }
  const std::int32_t count = Read<std::int32_t>(manager, 8);
  void* const* screens = Read<void* const*>(manager, 4);
  std::wstring text;
  for (std::int32_t i = 0; i < count && i < 128 && screens != nullptr; ++i) {
    wchar_t item[32];
    swprintf_s(item, L" %d:%08X", screens[i] != nullptr ? Read<std::int32_t>(screens[i], 0x0C) : -1,
               Vtable(screens[i]));
    text += item;
  }
  Log(L"lanAutoStart: %d screens (id:vtable):%ls", count, text.c_str());
}

// MPLanBrowserDialog, recognised. Stock its vtable is 0xB8CE10. A mod's own DLL can replace that pointer with a table of
// its own in which every entry forwards through its code, so a vtable comparison refuses the very dialog the game
// made. The object, its fields and the routines this key calls are still the stock class's, so a dialog with
// another vtable is taken when the gadgets its init bound are where the init put them: the game name and Direct IP
// edit boxes ([+164h], [+17Ch], type 23h) and the Game Type and Game Rules dropdowns ([+168h], [+190h], type 0Dh).
// It is reached from the login screen's own [+54h] (whose vtable is checked), so this is a second check, not the
// only one.
bool IsLanBrowser(void* dialog) {
  if (dialog == nullptr) {
    return false;
  }
  const std::uint32_t vtable = Vtable(dialog);
  if (vtable == kLanBrowserVtable) {
    return true;
  }
  void* gadgets = GadgetManager();
  auto has = [&](std::uint32_t offset, std::int32_t type) {
    return kGadgetLookup(gadgets, nullptr, Read<std::int32_t>(dialog, offset), type) != nullptr;
  };
  const bool shaped = has(0x164, kEditBoxType) && has(0x17C, kEditBoxType) && has(0x168, kDropdownType) &&
                      has(0x190, kDropdownType);
  static std::uint32_t told = 0;
  if (vtable != told) {
    told = vtable;
    Log(shaped ? L"lanAutoStart: the LAN dialog has another DLL's vtable (%08X); recognised by its gadgets"
               : L"lanAutoStart: the LAN dialog's vtable %08X is not the game's and its gadgets do not match; "
                 L"not the dialog",
        vtable);
  }
  return shaped;
}

void* LanBrowser() {
  void* screen = LoginScreen();
  void* gadgets = GadgetManager();
  if (screen == nullptr || gadgets == nullptr) {
    return nullptr;
  }
  void* dialog = kGadgetLookup(gadgets, nullptr, Read<std::int32_t>(screen, 0x54), 0);
  return IsLanBrowser(dialog) ? dialog : nullptr;
}

// The dialog is shown (bit 0 of [gadget+0A4h], the bit the base activation 0x447BBC tests) and its LAN browser
// exists: what its buttons need. [dlg+1ACh] alone is not enough: the deactivation releases the browser and leaves the
// pointer.
bool BrowserReady(void* dialog) {
  return dialog != nullptr && (Read<std::uint8_t>(dialog, 0xA4) & 1) != 0 && Read<void*>(dialog, 0x1AC) != nullptr;
}

void Execute(const char* command) {
  void* console = *reinterpret_cast<void* const*>(kConsoleObject);
  if (console == nullptr) {
    return;
  }
  kExecuteCommand(console, nullptr, command, "console");
}

void SwitchScreen(std::int32_t id) {
  void* manager = ScreenManager();
  const auto vtable = reinterpret_cast<void* const*>(Vtable(manager));
  reinterpret_cast<SwitchScreenFn>(vtable[0x14 / 4])(manager, nullptr, id, 0);
}

void* Dropdown(void* dialog, std::uint32_t offset) {
  return kGadgetLookup(GadgetManager(), nullptr, Read<std::int32_t>(dialog, offset), kDropdownType);
}

// Picks the host's Game Rules the way the dialog's own fill picks its first entry (0x5C36AE(index, 0)). The Game
// Type is left as the game opens it (Supremacy); its Deathmatch would force and hide the rules.
void SelectHostOptions(void* dialog) {
  if (g_rules >= 0) {
    void* rules = Dropdown(dialog, 0x190);
    if (rules == nullptr || g_rules >= kRulesEntries) {
      Log(L"lanAutoStart: Game Rules entry %d does not exist (%d entries); left as it is", g_rules, kRulesEntries);
    } else {
      kDropdownSelect(rules, nullptr, g_rules, 0);
      const std::int32_t now = kDropdownCurrent(rules, nullptr);
      if (now == g_rules) {
        Log(L"lanAutoStart: Game Rules entry %d", now);
      } else {
        Log(L"lanAutoStart: Game Rules entry %d asked, the dropdown shows %d", g_rules, now);
      }
    }
  }
}

// The game is still waiting for the answer to the last Connect: its countdown, [1B4h] + [1B0h] on the game clock.
bool JoinPending(void* dialog) {
  const std::uint32_t timeout = Read<std::uint32_t>(dialog, 0x1B0);
  const std::uint32_t started = Read<std::uint32_t>(dialog, 0x1B4);
  return timeout != 0 && kGameClock() - started < timeout;
}

// What the Host button's click calls: the call at 0x8BC559 (site LanBrowserClickHost). Stock that is 0x8BBD88;
// a mod's own DLL can point it at a wrapper that runs its code and then the stock routine, and calling 0x8BBD88 directly
// would skip it. Read when hosting, since another DLL may patch it after this one applied. Taken only when it is
// executable code of a loaded module; anything else is refused.
HostFn HostRoutine() {
  const auto next = reinterpret_cast<const BYTE*>(0x008BC55E);
  const auto target = reinterpret_cast<std::uintptr_t>(next) + *reinterpret_cast<const std::int32_t*>(0x008BC55A);
  if (target == reinterpret_cast<std::uintptr_t>(kHost)) {
    return kHost;
  }
  MEMORY_BASIC_INFORMATION info{};
  constexpr DWORD kExecutable = PAGE_EXECUTE | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY;
  if (VirtualQuery(reinterpret_cast<const void*>(target), &info, sizeof(info)) != sizeof(info) ||
      info.State != MEM_COMMIT || info.Type != MEM_IMAGE || (info.Protect & kExecutable) == 0) {
    Log(L"lanAutoStart: the Host button calls %08X, which is not code of a loaded module; not hosting",
        static_cast<unsigned>(target));
    return nullptr;
  }
  HMODULE module = nullptr;
  wchar_t path[MAX_PATH] = L"?";
  if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         reinterpret_cast<LPCWSTR>(target), &module)) {
    GetModuleFileNameW(module, path, MAX_PATH);
  }
  const wchar_t* name = wcsrchr(path, L'\\');
  Log(L"lanAutoStart: the Host button calls %ls+%X (another DLL's hook); calling it as the click does",
      name != nullptr ? name + 1 : path,
      static_cast<unsigned>(target - reinterpret_cast<std::uintptr_t>(module)));
  return reinterpret_cast<HostFn>(target);
}

bool Act(void* dialog) {
  if (g_action == Action::kHost) {
    const HostFn host = HostRoutine();
    if (host == nullptr) {
      return false;
    }
    SelectHostOptions(dialog);
    Log(L"lanAutoStart: hosting a LAN game");
    host(dialog, nullptr, 0);
    return true;
  }
  void* box = kGadgetLookup(GadgetManager(), nullptr, Read<std::int32_t>(dialog, 0x17C), kEditBoxType);
  if (box == nullptr) {
    Log(L"lanAutoStart: the Direct IP box was not found; not joining");
    return false;
  }
  BString text{nullptr};
  kBStringFromWide(&text, nullptr, g_address.c_str());
  const auto vtable = reinterpret_cast<void* const*>(Vtable(box));
  reinterpret_cast<SetTextFn>(vtable[0x80 / 4])(box, nullptr, &text);
  kBStringFree(&text, nullptr);
  Log(L"lanAutoStart: joining %ls by Direct IP", g_address.c_str());
  kJoinIp(dialog, nullptr);
  // 0 is the browser refusing at once, with a message box: pressing again would stack them.
  if (Read<std::uint32_t>(dialog, 0x1B0) == 0) {
    Log(L"lanAutoStart: Connect was refused at once; not pressed again");
    return false;
  }
  return true;
}

void Begin(ULONGLONG now) {
  if (++g_attempts > kMaxAttempts) {
    Log(L"lanAutoStart: the LAN screen did not open after %d attempts; stopped", kMaxAttempts);
    g_step = Step::kDone;
    return;
  }
  Log(L"lanAutoStart: attempt %d: doMPSetup(false)", g_attempts);
  Execute("doMPSetup(false)");
  g_step = Step::kAfterSetup;
  g_stepStart = now;
}

void AfterPresent(HRESULT) {
  if (g_step == Step::kDone) {
    return;
  }
  const ULONGLONG now = GetTickCount64();
  if (g_firstFrame == 0) {
    g_firstFrame = now;
    return;
  }
  if (now - g_firstFrame > kGiveUpMs && g_step != Step::kJoinRetry) {
    Log(L"lanAutoStart: gave up %llu s after the first frame", kGiveUpMs / 1000);
    g_step = Step::kDone;
    return;
  }
  void* dialog = LanBrowser();
  switch (g_step) {
    case Step::kWaitMenu:
      if (now - g_firstFrame >= kMenuDelayMs && Ui() != nullptr && ScreenManager() != nullptr &&
          *reinterpret_cast<void* const*>(kConsoleObject) != nullptr) {
        Begin(now);
      }
      break;
    case Step::kAfterSetup:
      if (now - g_stepStart >= kSetupDelayMs) {
        void* homeCity = FindScreen(&ById, kSkirmHomeCityScreen);
        const std::int32_t next = homeCity != nullptr ? Read<std::int32_t>(homeCity, 0x3C) : -1;
        if (next != kLoginScreen) {
          Log(L"lanAutoStart: doMPSetup did not take yet (home city next screen %d); retrying", next);
          --g_attempts;  // the menu was not ready: not a failed attempt
          g_step = Step::kWaitMenu;
          g_firstFrame = now - kMenuDelayMs + 2000;  // the next attempt in 2 s
          break;
        }
        Log(L"lanAutoStart: home city screen -> screen %d", kLoginScreen);
        SwitchScreen(kLoginScreen);
        g_step = Step::kWaitDialog;
        g_stepStart = now;
      }
      break;
    case Step::kWaitDialog:
      if (BrowserReady(dialog)) {
        Log(L"lanAutoStart: the LAN / Direct IP dialog is open");
        g_step = Step::kSettle;
        g_stepStart = now;
      } else if (now - g_stepStart >= kDialogTimeoutMs) {
        void* descriptor = FindScreen(&ById, kLoginScreen);
        const std::int32_t handle = descriptor != nullptr ? Read<std::int32_t>(descriptor, 4) : -1;
        void* screen = descriptor != nullptr ? kScreenResolve(handle) : nullptr;
        void* gadgets = GadgetManager();
        void* browser = screen != nullptr && gadgets != nullptr
                            ? kGadgetLookup(gadgets, nullptr, Read<std::int32_t>(screen, 0x54), 0)
                            : nullptr;
        Log(L"lanAutoStart: the LAN / Direct IP dialog did not open (descriptor %d: %p, handle %d, screen %p vtable "
            L"%08X, [+54h] %d -> %p vtable %08X); retrying",
            kLoginScreen, descriptor, handle, screen, Vtable(screen),
            screen != nullptr ? Read<std::int32_t>(screen, 0x54) : -1, browser, Vtable(browser));
        LogScreens();
        Begin(now);
      }
      break;
    case Step::kSettle:
      if (!BrowserReady(dialog)) {
        g_step = Step::kWaitDialog;
        g_stepStart = now;
      } else if (now - g_stepStart >= kSettleMs + (g_action == Action::kJoin ? kJoinFirstDelayMs : 0)) {
        // Before acting: the routines may show a dialog and present frames.
        g_step = g_action == Action::kJoin ? Step::kJoinRetry : Step::kDone;
        g_stepStart = now;
        g_firstJoin = now;
        ++g_joins;
        if (!Act(dialog)) {
          g_step = Step::kDone;
        }
      }
      break;
    case Step::kJoinRetry:
      if (dialog == nullptr || !BrowserReady(dialog)) {
        Log(L"lanAutoStart: left the LAN screen after %d Connect(s)", g_joins);
        g_step = Step::kDone;
      } else if (JoinPending(dialog)) {
        g_stepStart = now;  // the next press counts from the end of this wait
      } else if (now - g_stepStart >= kJoinRetryMs) {
        if (now - g_firstJoin >= kJoinWindowMs) {
          Log(L"lanAutoStart: still on the LAN screen after %d Connects in %llu s; stopped", g_joins,
              kJoinWindowMs / 1000);
          g_step = Step::kDone;
          break;
        }
        Log(L"lanAutoStart: still on the LAN screen; Connect again");
        g_stepStart = now;
        ++g_joins;
        if (!Act(dialog)) {
          g_step = Step::kDone;
        }
      }
      break;
    case Step::kDone:
      break;
  }
}

bool AddressCharsOk(const std::wstring& address) {
  if (address.empty() || address.size() > 64) {
    return false;
  }
  for (wchar_t c : address) {
    if (!(iswalnum(c) || c == L'.' || c == L'-' || c == L':')) {
      return false;
    }
  }
  return true;
}

// Finds `name` as a whole token of the command line, case-insensitive, optionally after '+'.
std::size_t FindToken(const std::wstring& line, const wchar_t* name) {
  const std::size_t length = wcslen(name);
  for (std::size_t i = 0; i + length <= line.size(); ++i) {
    if (_wcsnicmp(line.c_str() + i, name, length) != 0) {
      continue;
    }
    const bool startOk = i == 0 || line[i - 1] == L' ' || line[i - 1] == L'+' || line[i - 1] == L'\t' ||
                         line[i - 1] == L'"';
    const wchar_t after = i + length < line.size() ? line[i + length] : L'\0';
    const bool endOk = after == L'\0' || after == L' ' || after == L'\t' || after == L'=' || after == L'"';
    if (startOk && endOk) {
      return i + length;
    }
  }
  return std::wstring::npos;
}

// A small entry index, 0..63, or -1 for none or anything else.
std::int32_t ParseIndex(const std::wstring& text) {
  if (text.empty() || text.size() > 2) {
    return -1;
  }
  std::int32_t value = 0;
  for (wchar_t c : text) {
    if (c < L'0' || c > L'9') {
      return -1;
    }
    value = value * 10 + (c - L'0');
  }
  return value <= 63 ? value : -1;
}

// name=N, name="N" or name N on the command line; -1 when absent or not an index (logged).
std::int32_t ReadIndexToken(const std::wstring& line, const wchar_t* name) {
  std::size_t at = FindToken(line, name);
  if (at == std::wstring::npos) {
    return -1;
  }
  while (at < line.size() && (line[at] == L' ' || line[at] == L'=' || line[at] == L'\t' || line[at] == L'"')) {
    ++at;
  }
  std::wstring text;
  while (at < line.size() && line[at] != L'"' && line[at] != L' ' && line[at] != L'\t') {
    text += line[at++];
  }
  const std::int32_t value = ParseIndex(text);
  if (value < 0) {
    Log(L"lanAutoStart: %ls on the command line is not an entry number (0-63); ignored", name);
  }
  return value;
}

// uhcLanJoin="1.2.3.4", uhcLanJoin=1.2.3.4 or uhcLanJoin 1.2.3.4.
bool ReadCommandLine() {
  const std::wstring line = GetCommandLineW();
  g_rules = ReadIndexToken(line, L"uhcLanRules");
  std::size_t at = FindToken(line, L"uhcLanJoin");
  if (at != std::wstring::npos) {
    while (at < line.size() && (line[at] == L' ' || line[at] == L'=' || line[at] == L'\t')) {
      ++at;
    }
    if (at < line.size() && line[at] == L'"') {
      ++at;
    }
    std::wstring address;
    while (at < line.size() && line[at] != L'"' && line[at] != L' ' && line[at] != L'\t') {
      address += line[at++];
    }
    if (!AddressCharsOk(address)) {
      Log(L"lanAutoStart: uhcLanJoin on the command line has no valid address; ignored");
      return false;
    }
    g_action = Action::kJoin;
    g_address = address;
    return true;
  }
  if (FindToken(line, L"uhcLanHost") != std::wstring::npos) {
    g_action = Action::kHost;
    return true;
  }
  return false;
}

}  // namespace

Outcome ApplyLanAutoStart(const Config& config) {
  const auto* args = config.First("lanAutoStart");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!ReadCommandLine() && !args->empty()) {
    if (_stricmp((*args)[0].c_str(), "host") == 0) {
      g_action = Action::kHost;
      for (std::size_t i = 1; i < args->size(); ++i) {
        const std::string& word = (*args)[i];
        const std::wstring value(word.begin() + (word.find('=') == std::string::npos ? word.size() : word.find('=') + 1),
                                 word.end());
        if (_strnicmp(word.c_str(), "rules=", 6) == 0) {
          g_rules = ParseIndex(value);
        } else {
          Log(L"lanAutoStart: unknown host argument \"%hs\"; expected rules=N", word.c_str());
        }
      }
    } else if (_stricmp((*args)[0].c_str(), "join") == 0 && args->size() >= 2) {
      g_address.assign((*args)[1].begin(), (*args)[1].end());
      if (AddressCharsOk(g_address)) {
        g_action = Action::kJoin;
      } else {
        Log(L"lanAutoStart: \"%hs\" is not an address", (*args)[1].c_str());
      }
    } else {
      Log(L"lanAutoStart: unknown arguments; expected host or join <address>");
    }
  }
  if (g_action == Action::kNone) {
    Log(L"lanAutoStart: no action (no +uhcLanHost or uhcLanJoin=\"<address>\" on the command line)");
    return Outcome::kApplied;
  }
  if (!VerifyAll("lanAutoStart",
                 {&sites::kLanConsoleExecute, &sites::kLanDoMpSetupLan, &sites::kLanScreenLookup,
                  &sites::kLanLoginDescriptorHandle, &sites::kLanScreenResolve,
                  &sites::kLanLoginScreenInit, &sites::kLanLoginScreenBrowser, &sites::kLanGadgetLookup,
                  &sites::kLanGadgetShownFlag,
                  &sites::kLanBrowserHostGadget, &sites::kLanBrowserIpGadget, &sites::kLanBrowserSession,
                  &sites::kLanBrowserSetText, &sites::kLanBrowserClickHost, &sites::kLanBrowserClickHostNext,
                  &sites::kLanBrowserClickJoinIp,
                  &sites::kLanBrowserHost, &sites::kLanBrowserJoinIp, &sites::kBStringFromWide,
                  &sites::kBStringFree, &sites::kLanBrowserRulesGadget, &sites::kLanBrowserNameGadget,
                  &sites::kLanBrowserModeGadget, &sites::kLanDropdownSelect,
                  &sites::kLanBrowserRulesFill, &sites::kLanDropdownCurrent, &sites::kLanGameClock,
                  &sites::kLanBrowserJoinRequest, &sites::kLanBrowserJoinStart, &sites::kLanBrowserCountdown})) {
    return Outcome::kFailed;
  }
  if (!AddD3D9Observer({nullptr, nullptr, nullptr, &AfterPresent}, "lanAutoStart")) {
    return Outcome::kFailed;
  }
  Log(L"lanAutoStart: will %ls once the main menu is up", g_action == Action::kHost ? L"host a LAN game"
                                                                                    : (L"join " + g_address).c_str());
  if (g_action == Action::kHost && g_rules >= 0) {
    Log(L"lanAutoStart: Game Rules entry %d", g_rules);
  }
  return Outcome::kApplied;
}

}  // namespace uhc
```
