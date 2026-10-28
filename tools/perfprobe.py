"""Sample how a running age3y.exe uses CPU, GPU and memory (docs/performance.md, "Next steps").

Usage: python -I tools/perfprobe.py <out.csv> [seconds (default 120)] [interval (default 1.0)]

Each sample writes one CSV row and one console line:
- CPU per thread, in % of one core:
  - main = the earliest-created thread of the process (simulation, AI, rendering, Direct3D);
  - worker = the skinning worker, whose handle the game keeps at [0xC674F8];
  - the busiest other threads are named by their Win32 start address.
- GPU 3D-engine use of the process (PDH "GPU Engine" counters, summed over its engines).
- Memory: working set, private bytes and used user address space.
- Skinning jobs per second, from the game's own counters [0xC692E0] (run on the calling thread)
  and [0xC692E4] (run by the worker).
- Frame statistics, when UHC.dll runs with the `perfStats` key: fps, the longest frame of the
  interval, and frames over 50 / 100 ms.

The game is only read (PROCESS_QUERY_INFORMATION, PROCESS_VM_READ, PROCESS_DUP_HANDLE). The one
write goes to UHC.dll's own statistics mapping, to reset the per-interval longest frame.
Stop early with Ctrl+C; a summary is printed at the end.
"""
import csv
import ctypes
import ctypes.wintypes as wt
import struct
import sys
import time

EXE = "age3y.exe"
WORKER_HANDLE_VA = 0xC674F8
JOB_COUNTERS_VA = 0xC692E0  # u32 jobs on the calling thread, u32 jobs on the worker

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
ntdll = ctypes.WinDLL("ntdll")
psapi = ctypes.WinDLL("psapi", use_last_error=True)
pdh = ctypes.WinDLL("pdh")

TH32CS_SNAPPROCESS, TH32CS_SNAPTHREAD = 0x2, 0x4
PROCESS_ACCESS = 0x0400 | 0x0010 | 0x0040  # QUERY_INFORMATION | VM_READ | DUP_HANDLE
THREAD_QUERY_INFORMATION = 0x0040
DUPLICATE_SAME_ACCESS = 0x2
MEM_FREE = 0x10000
PDH_FMT_DOUBLE = 0x200
PDH_MORE_DATA = 0x800007D2
FILE_MAP_ALL_ACCESS = 0xF001F


class PROCESSENTRY32W(ctypes.Structure):
    _fields_ = [("dwSize", wt.DWORD), ("cntUsage", wt.DWORD), ("th32ProcessID", wt.DWORD),
                ("th32DefaultHeapID", ctypes.c_size_t), ("th32ModuleID", wt.DWORD), ("cntThreads", wt.DWORD),
                ("th32ParentProcessID", wt.DWORD), ("pcPriClassBase", ctypes.c_long), ("dwFlags", wt.DWORD),
                ("szExeFile", ctypes.c_wchar * 260)]


class THREADENTRY32(ctypes.Structure):
    _fields_ = [("dwSize", wt.DWORD), ("cntUsage", wt.DWORD), ("th32ThreadID", wt.DWORD),
                ("th32OwnerProcessID", wt.DWORD), ("tpBasePri", ctypes.c_long), ("tpDeltaPri", ctypes.c_long),
                ("dwFlags", wt.DWORD)]


class MEMORY_BASIC_INFORMATION(ctypes.Structure):
    _fields_ = [("BaseAddress", ctypes.c_void_p), ("AllocationBase", ctypes.c_void_p),
                ("AllocationProtect", wt.DWORD), ("PartitionId", wt.WORD), ("RegionSize", ctypes.c_size_t),
                ("State", wt.DWORD), ("Protect", wt.DWORD), ("Type", wt.DWORD)]


class PROCESS_MEMORY_COUNTERS_EX(ctypes.Structure):
    _fields_ = [("cb", wt.DWORD), ("PageFaultCount", wt.DWORD), ("PeakWorkingSetSize", ctypes.c_size_t),
                ("WorkingSetSize", ctypes.c_size_t), ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPagedPoolUsage", ctypes.c_size_t), ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                ("QuotaNonPagedPoolUsage", ctypes.c_size_t), ("PagefileUsage", ctypes.c_size_t),
                ("PeakPagefileUsage", ctypes.c_size_t), ("PrivateUsage", ctypes.c_size_t)]


class MODULEINFO(ctypes.Structure):
    _fields_ = [("lpBaseOfDll", ctypes.c_void_p), ("SizeOfImage", wt.DWORD), ("EntryPoint", ctypes.c_void_p)]


class PDH_FMT_COUNTERVALUE(ctypes.Structure):
    _fields_ = [("CStatus", wt.DWORD), ("doubleValue", ctypes.c_double)]


class PDH_FMT_COUNTERVALUE_ITEM_W(ctypes.Structure):
    _fields_ = [("szName", ctypes.c_wchar_p), ("FmtValue", PDH_FMT_COUNTERVALUE)]


# Layout of PerfShared in src/features/perf.cpp (version 1).
SHARED_FORMAT = "<IIIIQIIIIIIIII"
SHARED_SIZE = struct.calcsize(SHARED_FORMAT)

for name, res, args in [
    ("CreateToolhelp32Snapshot", wt.HANDLE, [wt.DWORD, wt.DWORD]),
    ("Process32FirstW", wt.BOOL, [wt.HANDLE, ctypes.c_void_p]),
    ("Process32NextW", wt.BOOL, [wt.HANDLE, ctypes.c_void_p]),
    ("Thread32First", wt.BOOL, [wt.HANDLE, ctypes.c_void_p]),
    ("Thread32Next", wt.BOOL, [wt.HANDLE, ctypes.c_void_p]),
    ("OpenProcess", wt.HANDLE, [wt.DWORD, wt.BOOL, wt.DWORD]),
    ("OpenThread", wt.HANDLE, [wt.DWORD, wt.BOOL, wt.DWORD]),
    ("CloseHandle", wt.BOOL, [wt.HANDLE]),
    ("GetThreadTimes", wt.BOOL, [wt.HANDLE] + [ctypes.POINTER(ctypes.c_ulonglong)] * 4),
    ("GetProcessTimes", wt.BOOL, [wt.HANDLE] + [ctypes.POINTER(ctypes.c_ulonglong)] * 4),
    ("ReadProcessMemory", wt.BOOL, [wt.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                                    ctypes.POINTER(ctypes.c_size_t)]),
    ("VirtualQueryEx", ctypes.c_size_t, [wt.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t]),
    ("DuplicateHandle", wt.BOOL, [wt.HANDLE, wt.HANDLE, wt.HANDLE, ctypes.POINTER(wt.HANDLE), wt.DWORD,
                                  wt.BOOL, wt.DWORD]),
    ("GetCurrentProcess", wt.HANDLE, []),
    ("GetThreadId", wt.DWORD, [wt.HANDLE]),
    ("GetExitCodeProcess", wt.BOOL, [wt.HANDLE, ctypes.POINTER(wt.DWORD)]),
    ("OpenFileMappingW", wt.HANDLE, [wt.DWORD, wt.BOOL, wt.LPCWSTR]),
    ("MapViewOfFile", ctypes.c_void_p, [wt.HANDLE, wt.DWORD, wt.DWORD, wt.DWORD, ctypes.c_size_t]),
]:
    f = getattr(k32, name)
    f.restype, f.argtypes = res, args
ntdll.NtQueryInformationThread.restype = ctypes.c_long
ntdll.NtQueryInformationThread.argtypes = [wt.HANDLE, ctypes.c_int, ctypes.c_void_p, wt.ULONG,
                                           ctypes.POINTER(wt.ULONG)]
psapi.GetProcessMemoryInfo.restype = wt.BOOL
psapi.GetProcessMemoryInfo.argtypes = [wt.HANDLE, ctypes.c_void_p, wt.DWORD]
psapi.EnumProcessModulesEx.restype = wt.BOOL
psapi.EnumProcessModulesEx.argtypes = [wt.HANDLE, ctypes.POINTER(ctypes.c_void_p), wt.DWORD,
                                       ctypes.POINTER(wt.DWORD), wt.DWORD]
psapi.GetModuleBaseNameW.restype = wt.DWORD
psapi.GetModuleBaseNameW.argtypes = [wt.HANDLE, ctypes.c_void_p, wt.LPWSTR, wt.DWORD]
psapi.GetModuleInformation.restype = wt.BOOL
psapi.GetModuleInformation.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.POINTER(MODULEINFO), wt.DWORD]
pdh.PdhOpenQueryW.restype = wt.DWORD
pdh.PdhOpenQueryW.argtypes = [wt.LPCWSTR, ctypes.c_size_t, ctypes.POINTER(wt.HANDLE)]
pdh.PdhAddEnglishCounterW.restype = wt.DWORD
pdh.PdhAddEnglishCounterW.argtypes = [wt.HANDLE, wt.LPCWSTR, ctypes.c_size_t, ctypes.POINTER(wt.HANDLE)]
pdh.PdhCollectQueryData.restype = wt.DWORD
pdh.PdhCollectQueryData.argtypes = [wt.HANDLE]
pdh.PdhGetFormattedCounterArrayW.restype = wt.DWORD
pdh.PdhGetFormattedCounterArrayW.argtypes = [wt.HANDLE, wt.DWORD, ctypes.POINTER(wt.DWORD),
                                             ctypes.POINTER(wt.DWORD), ctypes.c_void_p]
pdh.PdhCloseQuery.restype = wt.DWORD
pdh.PdhCloseQuery.argtypes = [wt.HANDLE]


def find_pid():
    snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    entry = PROCESSENTRY32W()
    entry.dwSize = ctypes.sizeof(entry)
    pid = None
    ok = k32.Process32FirstW(snap, ctypes.byref(entry))
    while ok:
        if entry.szExeFile.lower() == EXE:
            pid = entry.th32ProcessID
        ok = k32.Process32NextW(snap, ctypes.byref(entry))
    k32.CloseHandle(snap)
    return pid


def thread_ids(pid):
    snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0)
    entry = THREADENTRY32()
    entry.dwSize = ctypes.sizeof(entry)
    out = []
    ok = k32.Thread32First(snap, ctypes.byref(entry))
    while ok:
        if entry.th32OwnerProcessID == pid:
            out.append(entry.th32ThreadID)
        ok = k32.Thread32Next(snap, ctypes.byref(entry))
    k32.CloseHandle(snap)
    return out


def read(process, va, size):
    buf = ctypes.create_string_buffer(size)
    got = ctypes.c_size_t()
    if not k32.ReadProcessMemory(process, ctypes.c_void_p(va), buf, size, ctypes.byref(got)) or got.value != size:
        return None
    return buf.raw


def modules(process):
    handles = (ctypes.c_void_p * 1024)()
    needed = wt.DWORD()
    if not psapi.EnumProcessModulesEx(process, handles, ctypes.sizeof(handles), ctypes.byref(needed), 0x1):
        return []
    out = []
    for h in handles[:needed.value // ctypes.sizeof(ctypes.c_void_p)]:
        name = ctypes.create_unicode_buffer(260)
        info = MODULEINFO()
        if psapi.GetModuleBaseNameW(process, h, name, 260) and \
                psapi.GetModuleInformation(process, h, ctypes.byref(info), ctypes.sizeof(info)):
            out.append((info.lpBaseOfDll or 0, info.SizeOfImage, name.value))
    return out


def symbolize(address, mods):
    for base, size, name in mods:
        if base <= address < base + size:
            return f"{name}+{address - base:#x}" if name.lower() != EXE else f"{address:#x}"
    return f"{address:#x}"


def thread_times(handle):
    creation, exit_, kernel, user = (ctypes.c_ulonglong() for _ in range(4))
    if not k32.GetThreadTimes(handle, ctypes.byref(creation), ctypes.byref(exit_), ctypes.byref(kernel),
                              ctypes.byref(user)):
        return None
    return creation.value, kernel.value + user.value


def start_address(handle):
    address = ctypes.c_void_p()
    if ntdll.NtQueryInformationThread(handle, 9, ctypes.byref(address), ctypes.sizeof(address), None) != 0:
        return 0
    return address.value or 0


def worker_tid(process):
    raw = read(process, WORKER_HANDLE_VA, 4)
    if raw is None:
        return None
    value = struct.unpack("<I", raw)[0]
    if value in (0, 0xFFFFFFFF):
        return None
    dup = wt.HANDLE()
    if not k32.DuplicateHandle(process, wt.HANDLE(value), k32.GetCurrentProcess(), ctypes.byref(dup), 0, False,
                               DUPLICATE_SAME_ACCESS):
        return None
    tid = k32.GetThreadId(dup)
    k32.CloseHandle(dup)
    return tid or None


def user_limit(process):
    """4 GB if the game's exe is Large-Address-Aware, else 2 GB. Above the limit, WOW64 keeps the
    space reserved, so it must not count as used."""
    dos = read(process, 0x400000, 0x40)
    if dos is None:
        return 0x80000000
    e_lfanew = struct.unpack_from("<I", dos, 0x3C)[0]
    characteristics = read(process, 0x400000 + e_lfanew + 0x16, 2)
    laa = characteristics is not None and struct.unpack("<H", characteristics)[0] & 0x20
    return 0x100000000 if laa else 0x80000000


def address_space_mb(process, limit):
    info = MEMORY_BASIC_INFORMATION()
    address, used = 0, 0
    while address < limit:
        if not k32.VirtualQueryEx(process, ctypes.c_void_p(address), ctypes.byref(info), ctypes.sizeof(info)):
            break
        base = info.BaseAddress or 0
        if info.State != MEM_FREE:
            used += min(base + info.RegionSize, limit) - base
        address = base + info.RegionSize
    return used / 2**20


class Gpu:
    """Sum of the process's 3D-engine utilisation over all its GPU engines."""

    def __init__(self, pid):
        self.query, self.counter = wt.HANDLE(), wt.HANDLE()
        path = f"\\GPU Engine(pid_{pid}_*engtype_3D)\\Utilization Percentage"
        self.ok = (pdh.PdhOpenQueryW(None, 0, ctypes.byref(self.query)) == 0 and
                   pdh.PdhAddEnglishCounterW(self.query, path, 0, ctypes.byref(self.counter)) == 0)
        if self.ok:
            pdh.PdhCollectQueryData(self.query)

    def sample(self):
        if not self.ok or pdh.PdhCollectQueryData(self.query) != 0:
            return None
        size, count = wt.DWORD(0), wt.DWORD(0)
        status = pdh.PdhGetFormattedCounterArrayW(self.counter, PDH_FMT_DOUBLE, ctypes.byref(size),
                                                  ctypes.byref(count), None)
        if status != PDH_MORE_DATA:
            return 0.0
        buf = ctypes.create_string_buffer(size.value)
        if pdh.PdhGetFormattedCounterArrayW(self.counter, PDH_FMT_DOUBLE, ctypes.byref(size),
                                            ctypes.byref(count), buf) != 0:
            return None
        items = ctypes.cast(buf, ctypes.POINTER(PDH_FMT_COUNTERVALUE_ITEM_W))
        return sum(items[i].FmtValue.doubleValue for i in range(count.value) if items[i].FmtValue.CStatus in (0, 1))


def open_stats(pid):
    mapping = k32.OpenFileMappingW(FILE_MAP_ALL_ACCESS, False, f"Local\\UHCPerfStats-{pid}")
    if not mapping:
        return None
    view = k32.MapViewOfFile(mapping, FILE_MAP_ALL_ACCESS, 0, 0, SHARED_SIZE)
    return view or None


def read_stats(view):
    fields = struct.unpack(SHARED_FORMAT, ctypes.string_at(view, SHARED_SIZE))
    if fields[0] != 0x50434855 or fields[1] != 1:
        return None
    ctypes.memmove(view + 12, b"\0\0\0\0", 4)  # clear maxFrameUs for the next interval
    return {"frames": fields[2], "max_us": fields[3], "over50": fields[6], "over100": fields[7]}


def main():
    out_path = sys.argv[1]
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 120.0
    interval = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0

    pid = find_pid()
    if pid is None:
        sys.exit(f"{EXE} is not running")
    process = k32.OpenProcess(PROCESS_ACCESS, False, pid)
    if not process:
        sys.exit(f"OpenProcess failed: {ctypes.get_last_error()}")
    mods = modules(process)
    gpu = Gpu(pid)
    stats = open_stats(pid)
    limit = user_limit(process)
    print(f"pid {pid}; user address space {limit >> 20} MB; GPU counters {'on' if gpu.ok else 'unavailable'}; "
          f"UHC frame stats {'on' if stats else 'off (add perfStats to uhc.cfg)'}")

    threads = {}  # tid -> {"handle", "created", "start", "last"}
    last_jobs, last_frames, last_t = None, None, time.perf_counter()
    rows, deadline = [], time.monotonic() + seconds
    columns = ["t", "fps", "max_frame_ms", "over50", "over100", "process_cpu", "main_cpu", "worker_cpu",
               "top_other", "gpu3d", "ws_mb", "private_mb", "va_mb", "jobs_main_ps", "jobs_worker_ps"]
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=columns)
        writer.writeheader()
        t0 = time.perf_counter()
        try:
            while time.monotonic() < deadline:
                code = wt.DWORD()
                if k32.GetExitCodeProcess(process, ctypes.byref(code)) and code.value != 259:
                    print("game exited")
                    break
                for tid in thread_ids(pid):
                    if tid not in threads:
                        handle = k32.OpenThread(THREAD_QUERY_INFORMATION, False, tid)
                        times = thread_times(handle) if handle else None
                        if times is None:
                            continue
                        start = start_address(handle)
                        name = symbolize(start, mods)
                        if name.startswith("0x") and not 0x400000 <= start < 0x1000000:
                            mods = modules(process)  # a DLL loaded after we started (e.g. the GPU driver)
                            name = symbolize(start, mods)
                        threads[tid] = {"handle": handle, "created": times[0], "start": name, "last": times[1]}
                time.sleep(interval)
                now = time.perf_counter()
                dt = now - last_t
                last_t = now
                usage = {}
                for tid, th in list(threads.items()):
                    times = thread_times(th["handle"])
                    if times is None:
                        continue
                    usage[tid] = (times[1] - th["last"]) / 1e7 / dt * 100
                    th["last"] = times[1]
                if not usage:
                    continue
                main = min(threads, key=lambda t: threads[t]["created"])
                worker = worker_tid(process)
                others = sorted(((u, tid) for tid, u in usage.items() if tid not in (main, worker)), reverse=True)
                top = "|".join(f"{threads[tid]['start']}:{u:.0f}" for u, tid in others[:3] if u >= 1)

                memory = PROCESS_MEMORY_COUNTERS_EX()
                memory.cb = ctypes.sizeof(memory)
                psapi.GetProcessMemoryInfo(process, ctypes.byref(memory), memory.cb)
                raw = read(process, JOB_COUNTERS_VA, 8)
                jobs = struct.unpack("<II", raw) if raw else (0, 0)
                jobs_ps = ((jobs[0] - last_jobs[0]) / dt, (jobs[1] - last_jobs[1]) / dt) if last_jobs else (0, 0)
                last_jobs = jobs

                row = {"t": f"{now - t0:.1f}", "process_cpu": f"{sum(usage.values()):.1f}",
                       "main_cpu": f"{usage.get(main, 0):.1f}", "worker_cpu": f"{usage.get(worker, 0):.1f}",
                       "top_other": top, "ws_mb": f"{memory.WorkingSetSize / 2**20:.0f}",
                       "private_mb": f"{memory.PrivateUsage / 2**20:.0f}", "va_mb": f"{address_space_mb(process, limit):.0f}",
                       "jobs_main_ps": f"{jobs_ps[0]:.0f}", "jobs_worker_ps": f"{jobs_ps[1]:.0f}"}
                g = gpu.sample()
                row["gpu3d"] = f"{g:.1f}" if g is not None else ""
                s = read_stats(stats) if stats else None
                if s:
                    if last_frames is not None:
                        row["fps"] = f"{(s['frames'] - last_frames['frames']) / dt:.1f}"
                        row["over50"] = s["over50"] - last_frames["over50"]
                        row["over100"] = s["over100"] - last_frames["over100"]
                    row["max_frame_ms"] = f"{s['max_us'] / 1000:.1f}"
                    last_frames = s
                writer.writerow(row)
                f.flush()
                rows.append(row)
                print(f"t={row['t']:>6} fps={row.get('fps', '-'):>6} max={row.get('max_frame_ms', '-'):>6}ms "
                      f"main={row['main_cpu']:>5}% worker={row['worker_cpu']:>5}% gpu={row['gpu3d']:>5}% "
                      f"va={row['va_mb']:>5}MB jobs={row['jobs_main_ps']}/{row['jobs_worker_ps']} {top}")
        except KeyboardInterrupt:
            pass
    summarize(rows)


def summarize(rows):
    def stat(key):
        values = [float(r[key]) for r in rows if r.get(key) not in (None, "")]
        return (sum(values) / len(values), max(values)) if values else (0.0, 0.0)

    if not rows:
        print("no samples")
        return
    print(f"\n{len(rows)} samples (mean / max)")
    for key in ("fps", "max_frame_ms", "main_cpu", "worker_cpu", "process_cpu", "gpu3d", "va_mb",
                "jobs_main_ps", "jobs_worker_ps"):
        mean, peak = stat(key)
        print(f"  {key:15s} {mean:8.1f} {peak:8.1f}")
    if any(r.get("over50") not in (None, "") for r in rows):
        print(f"  frames over 50 ms: {sum(int(r.get('over50') or 0) for r in rows)}, "
              f"over 100 ms: {sum(int(r.get('over100') or 0) for r in rows)}")


if __name__ == "__main__":
    main()
