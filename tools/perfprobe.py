"""Sample how a running age3y.exe uses CPU, GPU and memory (docs/performance.md, "Next steps").

Usage: python -I tools/perfprobe.py <out.csv> [seconds (default 120)] [interval (default 1.0)]
                                   [--wait] [--pid N] [--sample-hz N] [--functions PATH]
       python -I tools/perfprobe.py --analyze <out.csv.stacks.gz> [--functions PATH]

--wait waits for the game to start and records until it exits, ignoring `seconds`.
--pid N records that process. Without it, the probe takes the last age3y.exe it finds, which can be
another test copy's game when several run at once.
--sample-hz N also profiles the main thread N times a second: it suspends the thread, reads EIP and
its stack, and resumes it. The raw samples go to <out.csv>.stacks.gz and the report to
<out.csv>.samples.txt: time per module, the call tree under the main loop, exclusive and inclusive
time per function, and what ran during the frames over 50 ms (those need UHC.dll's perfStats).
--analyze rebuilds the report from a saved .stacks.gz, e.g. after the function table improved.
--functions is the table of function entries exported from Ghidra (docs/performance.md,
"Stack sampling"); default rea/evidence/age3y-b1a1dab7/functions.txt.

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
- The game's own update and render time per frame, averaged by the game over its last second
  (update = the mode manager, which runs the simulation; render = the render call, Present included).
- Simulation speed: game seconds per real second. In single player it drops below the game
  speed when frames take longer than 100 ms; that is the late-game "lag".

The game is only read (PROCESS_QUERY_INFORMATION, PROCESS_VM_READ, PROCESS_DUP_HANDLE). The one
write goes to UHC.dll's own statistics mapping, to reset the per-interval longest frame.
Stop early with Ctrl+C; a summary is printed at the end.
"""
import argparse
import array
import bisect
import csv
import ctypes
import ctypes.wintypes as wt
import gzip
import os
import re
import struct
import sys
import threading
import time
from collections import Counter

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
THREAD_SAMPLE_ACCESS = 0x0002 | 0x0008 | 0x0040  # SUSPEND_RESUME | GET_CONTEXT | QUERY_INFORMATION
WOW64_CONTEXT_SIZE, WOW64_CONTEXT_CONTROL, WOW64_EIP, WOW64_ESP = 0x2CC, 0x00010001, 0xB8, 0xC4
STACK_LIMIT = 256 * 1024  # bytes of stack read per sample, from ESP up
DUPLICATE_SAME_ACCESS = 0x2
MEM_FREE = 0x10000
PDH_FMT_DOUBLE = 0x200
PDH_MORE_DATA = 0x800007D2
FILE_MAP_ALL_ACCESS = 0xF001F
DEFAULT_FUNCTIONS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "rea", "evidence",
                                 "age3y-b1a1dab7", "functions.txt")

# Return addresses into the main loop FUN_00404EE0 (docs/engine-symbols.md): the per-frame call
# through the `jmp eax` stub at 0x406A01 (game object vtable+74h), and the message pump.
MAIN_LOOP_CALLS = {0x404FAD: "frame", 0x404F7F: "message pump"}
# Functions named in docs/engine-symbols.md.
LABELS = {
    0x404EE0: "main loop",
    0x402EF7: "message pump",
    0x40542F: "frame, start",
    0x405523: "frame, update part",
    0x405574: "frame, render part",
    0x405248: "mode manager update",
    0x408399: "render (calls Present)",
    0x44E0CD: "game update",
    0x44E183: "game update, world part",
    0x455D91: "sim update length",
    0x41CA31: "Present wrapper",
    0x40B65E: "deform (skinning producer)",
    0x40599C: "skinning queue flush",
    0x40B54F: "skinning job",
}


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


# Layout of PerfShared in src/features/perf.cpp: version 1, then the version 2 fields.
SHARED_FORMAT = "<IIIIQIIIIIIIII"
SHARED_SIZE = struct.calcsize(SHARED_FORMAT)
SLOW_OFFSET, SLOW_RING = 60, 64  # u32 slowFrames, i64 qpcFrequency, then the ring of (start, end) at 72

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
    ("SuspendThread", wt.DWORD, [wt.HANDLE]),
    ("ResumeThread", wt.DWORD, [wt.HANDLE]),
    ("Wow64GetThreadContext", wt.BOOL, [wt.HANDLE, ctypes.c_void_p]),
    ("MapViewOfFile", ctypes.c_void_p, [wt.HANDLE, wt.DWORD, wt.DWORD, wt.DWORD, ctypes.c_size_t]),
    ("QueryPerformanceCounter", wt.BOOL, [ctypes.POINTER(ctypes.c_longlong)]),
    ("QueryPerformanceFrequency", wt.BOOL, [ctypes.POINTER(ctypes.c_longlong)]),
    ("QueryFullProcessImageNameW", wt.BOOL, [wt.HANDLE, wt.DWORD, wt.LPWSTR, ctypes.POINTER(wt.DWORD)]),
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


def region_end(process, va):
    """End of the run of committed pages that contains `va`: for a stack, its top."""
    info = MEMORY_BASIC_INFORMATION()
    if not k32.VirtualQueryEx(process, ctypes.c_void_p(va), ctypes.byref(info), ctypes.sizeof(info)):
        return 0
    return (info.BaseAddress or 0) + info.RegionSize


def exe_path(process):
    buf = ctypes.create_unicode_buffer(1024)
    size = wt.DWORD(len(buf))
    return buf.value if k32.QueryFullProcessImageNameW(process, 0, buf, ctypes.byref(size)) else None


def qpc_frequency():
    value = ctypes.c_longlong()
    k32.QueryPerformanceFrequency(ctypes.byref(value))
    return value.value


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
    view = k32.MapViewOfFile(mapping, FILE_MAP_ALL_ACCESS, 0, 0, 0)  # the whole mapping, any version
    return view or None


def read_stats(view):
    fields = struct.unpack(SHARED_FORMAT, ctypes.string_at(view, SHARED_SIZE))
    if fields[0] != 0x50434855 or fields[1] < 1:
        return None
    ctypes.memmove(view + 12, b"\0\0\0\0", 4)  # clear maxFrameUs for the next interval
    return {"version": fields[1], "frames": fields[2], "max_us": fields[3], "over50": fields[6],
            "over100": fields[7]}


def read_slow_frames(view, seen):
    """Version 2: frames over 50 ms recorded since `seen`, as (new count, [(start, end) QPC])."""
    count = struct.unpack("<I", ctypes.string_at(view + SLOW_OFFSET, 4))[0]
    windows = [struct.unpack("<qq", ctypes.string_at(view + 72 + i % SLOW_RING * 16, 16))
               for i in range(max(seen, count - SLOW_RING), count)]
    return count, windows


class CallSites:
    """Every address of the exe's code that follows a call instruction, i.e. every possible return
    address, mapped to the call's target: an address for a direct call, None for an indirect one.
    Built from the exe file, so it also serves --analyze after the game has exited."""

    def __init__(self, path):
        with open(path, "rb") as f:
            data = f.read()
        nt = struct.unpack_from("<I", data, 0x3C)[0]
        count, optional_size = struct.unpack_from("<H", data, nt + 6)[0], struct.unpack_from("<H", data, nt + 0x14)[0]
        image_base = struct.unpack_from("<I", data, nt + 0x34)[0]
        self.lo, self.code = 0, b""
        for i in range(count):
            header = nt + 0x18 + optional_size + 40 * i
            vsize, va, raw_size, raw_offset = struct.unpack_from("<IIII", data, header + 8)
            if struct.unpack_from("<I", data, header + 36)[0] & 0x20000000:  # IMAGE_SCN_MEM_EXECUTE
                self.lo, self.code = image_base + va, data[raw_offset:raw_offset + min(vsize, raw_size)]
                break
        self.hi = self.lo + len(self.code)
        code, lo, targets = self.code, self.lo, {}
        for m in re.finditer(b"\xE8", code):  # call rel32
            i = m.start()
            if i + 5 <= len(code):
                target = lo + i + 5 + int.from_bytes(code[i + 1:i + 5], "little", signed=True)
                if lo <= target < self.hi:
                    targets[lo + i + 5] = target
        for m in re.finditer(b"\xFF[\x10-\x17\x50-\x57\x90-\x97\xD0-\xD7]", code):  # FF /2: call r/m32
            i, modrm = m.start(), code[m.start() + 1]
            mod, rm, size = modrm >> 6, modrm & 7, 2
            if mod != 3:
                if rm == 4:
                    size += 1
                    if mod == 0 and i + 2 < len(code) and code[i + 2] & 7 == 5:
                        size += 4
                elif mod == 0 and rm == 5:
                    size += 4
                size += (0, 1, 4, 0)[mod]
            targets[lo + i + size] = None  # wins when the bytes also decode as a direct call: unchecked
        self.targets = targets

    def callee(self, ret):
        """Function that the call before `ret` enters, through incremental-link jumps; None if unknown."""
        target = self.targets.get(ret)
        for _ in range(4):
            if target is None or not self.lo <= target < self.hi - 6:
                return None
            at = target - self.lo
            op, modrm = self.code[at], self.code[at + 1]
            if op == 0xE9:
                target += 5 + int.from_bytes(self.code[at + 1:at + 5], "little", signed=True)
            elif op == 0xFF and (modrm == 0x25 or 0xE0 <= modrm <= 0xE7):
                return None  # jmp [import] or jmp reg
            else:
                return target
        return None


class Functions:
    """Function entries from the Ghidra export: an address belongs to the closest entry below it.
    Ghidra splits some functions into separate chunks of cold code; those get attributed to the
    function that precedes them."""

    def __init__(self, path):
        self.starts, self.names = [], {}
        with open(path, encoding="utf-8") as f:
            for line in f:
                if line.startswith("#") or not line.strip():
                    continue
                va, name = line.split(None, 1)
                self.starts.append(int(va, 16))
                self.names[self.starts[-1]] = name.strip()
        self.starts.sort()

    def entry(self, va):
        k = bisect.bisect_right(self.starts, va) - 1
        return self.starts[k] if k >= 0 else None

    def name(self, key):
        if key is None:
            return "?"
        if isinstance(key, str):
            return key
        label = LABELS.get(key) or self.names.get(key, "")
        return f"{key:#x} {label}" if label and not label.startswith("FUN_") else f"{key:#x}"


class Sampler(threading.Thread):
    """Statistical profile of one thread, `hz` times a second: suspend it, read EIP, ESP and its
    stack, resume it. Of the stack, only the values that are return addresses into the exe are kept.
    The thread is stopped for some tens of microseconds per sample; nothing in the game is written."""

    def __init__(self, process, tid, hz, sites):
        super().__init__(daemon=True)
        self.process, self.targets = process, sites.targets
        self.handle = k32.OpenThread(THREAD_SAMPLE_ACCESS, False, tid)
        self.period = 1.0 / hz
        self.samples, self.stop = [], threading.Event()

    def run(self):
        ctx = (ctypes.c_ubyte * WOW64_CONTEXT_SIZE)()
        stack = ctypes.create_string_buffer(STACK_LIMIT)
        got, stamp, top, targets = ctypes.c_size_t(), ctypes.c_longlong(), 0, self.targets
        while self.handle and not self.stop.is_set():
            struct.pack_into("<I", ctx, 0, WOW64_CONTEXT_CONTROL)
            if k32.SuspendThread(self.handle) == 0xFFFFFFFF:
                break
            size = 0
            try:
                if k32.Wow64GetThreadContext(self.handle, ctx):
                    k32.QueryPerformanceCounter(ctypes.byref(stamp))
                    eip = struct.unpack_from("<I", ctx, WOW64_EIP)[0]
                    esp = struct.unpack_from("<I", ctx, WOW64_ESP)[0]
                    if not top - STACK_LIMIT <= esp < top:
                        top = region_end(self.process, esp)
                    size = max(0, min(top - esp, STACK_LIMIT)) & ~3
                    if size and not k32.ReadProcessMemory(self.process, ctypes.c_void_p(esp), stack, size,
                                                          ctypes.byref(got)):
                        size = 0
            finally:
                k32.ResumeThread(self.handle)
            if size:
                words = memoryview(stack).cast("B")[:got.value & ~3].cast("I")
                self.samples.append((stamp.value, eip, array.array("I", [v for v in words if v in targets])))
            time.sleep(self.period)


def save_stacks(path, run):
    with gzip.open(path, "wt", encoding="utf-8") as f:
        f.write("# tools/perfprobe.py main-thread samples: s <qpc> <eip> <return addresses, innermost first>\n")
        f.write(f"exe {run['exe']}\nqpcfreq {run['qpcfreq']}\n")
        for base, size, name in run["modules"]:
            f.write(f"module {base:x} {size:x} {name}\n")
        for start, end in run["hitches"]:
            f.write(f"hitch {start} {end}\n")
        for stamp, eip, cands in run["samples"]:
            f.write(f"s {stamp} {eip:x} {' '.join(f'{v:x}' for v in cands)}\n")


def load_stacks(path):
    run = {"exe": None, "qpcfreq": 0, "modules": [], "hitches": [], "samples": []}
    with gzip.open(path, "rt", encoding="utf-8") as f:
        for line in f:
            kind, _, rest = line.rstrip("\n").partition(" ")
            if kind == "s":
                fields = rest.split()
                run["samples"].append((int(fields[0]), int(fields[1], 16), [int(v, 16) for v in fields[2:]]))
            elif kind == "hitch":
                run["hitches"].append(tuple(int(v) for v in rest.split()))
            elif kind == "module":
                base, size, name = rest.split(None, 2)
                run["modules"].append((int(base, 16), int(size, 16), name))
            elif kind == "exe":
                run["exe"] = rest
            elif kind == "qpcfreq":
                run["qpcfreq"] = int(rest)
    return run


def walk(eip, cands, sites, funcs):
    """Call chain of one sample, from its return-address candidates (innermost first).

    It starts at the outermost return address into the main loop and goes inwards. After a direct
    call it takes the outermost candidate inside the called function. After an indirect call, or
    when the callee is not on the stack (a tail call), it takes the outermost candidate whose own
    call is consistent with what lies below it. Most values left on the stack by earlier calls are
    skipped this way, but not all of them.
    Returns (main-loop call, [function entries, outermost first], [the return address picked in
    each], leaf entry), or None outside the main loop."""
    anchor = next((k for k in range(len(cands) - 1, -1, -1) if cands[k] in MAIN_LOOP_CALLS), None)
    if anchor is None:
        return None
    leaf = funcs.entry(eip) if sites.lo <= eip < sites.hi else None
    main_loop = funcs.entry(cands[anchor])
    entries = [None if funcs.entry(r) == main_loop else funcs.entry(r) for r in cands]  # not re-entered
    innermost = {}  # function entry -> lowest candidate index inside it
    for j in range(len(entries) - 1, -1, -1):
        innermost[entries[j]] = j

    def consistent(j):
        if entries[j] is None:
            return False
        callee = sites.callee(cands[j])
        return callee is None or callee == leaf or innermost.get(callee, j) < j

    chain, rets, expected, k = [], [], sites.callee(cands[anchor]), anchor - 1
    while k >= 0 and not (expected is not None and expected == leaf):
        pick = None
        if expected is not None:
            pick = next((j for j in range(k, -1, -1) if entries[j] == expected), None)
        if pick is None:
            pick = next((j for j in range(k, -1, -1) if consistent(j)), None)
        if pick is None:
            break
        chain.append(entries[pick])
        rets.append(cands[pick])
        expected, k = sites.callee(cands[pick]), pick - 1
    return cands[anchor], chain, rets, leaf


def report(run, funcs):
    """Text report of a sampled run: modules, call tree, functions, and the frames over 50 ms."""
    sites = CallSites(run["exe"])
    samples, freq = run["samples"], run["qpcfreq"] or 1
    hitches = sorted(run["hitches"])
    starts = [start for start, _ in hitches]

    def hitch_of(stamp):
        k = bisect.bisect_right(starts, stamp) - 1
        return k if k >= 0 and stamp <= hitches[k][1] else None

    def module_of(eip):
        return next((name for base, size, name in run["modules"] if base <= eip < base + size), "?")

    tree, hitch_tree, per_hitch = {}, {}, {}
    by_module, exclusive, inclusive, hitch_exclusive = Counter(), Counter(), Counter(), Counter()
    for stamp, eip, cands in samples:
        in_exe = sites.lo <= eip < sites.hi
        leaf_key = funcs.entry(eip) if in_exe else module_of(eip)
        by_module[EXE if in_exe else leaf_key] += 1
        exclusive[leaf_key] += 1
        walked = walk(eip, cands, sites, funcs)
        if walked is None:
            path = [("(outside the main loop)", None), (leaf_key, None)]
        else:
            call, chain, rets, _ = walked
            # each function with the return address it was called from (in its caller)
            path = [(MAIN_LOOP_CALLS[call], None)] + list(zip(chain, [call] + rets))
            if not chain or chain[-1] != leaf_key:
                path.append((leaf_key, rets[-1] if rets else call))
        for key in {key for key, _ in path[1:]}:
            inclusive[key] += 1
        h = hitch_of(stamp) if hitches else None
        for root in ([tree, hitch_tree] if h is not None else [tree]):
            node = root
            for key, site in path:
                node = node.setdefault(key, [0, {}, Counter()])
                node[0] += 1
                node[2][site] += 1
                node = node[1]
        if h is not None:
            hitch_exclusive[leaf_key] += 1
            per_hitch.setdefault(h, Counter())[leaf_key] += 1

    def tree_lines(node, total, depth, min_share, out):
        for key, (count, children, sites_seen) in sorted(node.items(), key=lambda kv: -kv[1][0]):
            if count / total >= min_share:
                site = sites_seen.most_common(1)[0][0]
                via = f"  <- {site:#x}" if site is not None else ""
                out.append(f"{'  ' * depth}{count / total * 100:5.1f}%  {funcs.name(key)}{via}")
                tree_lines(children, total, depth + 1, min_share, out)

    total = len(samples)
    span = (samples[-1][0] - samples[0][0]) / freq if total > 1 else 0
    lines = [f"main-thread samples: {total} over {span:.0f} s; return-address candidates per sample: "
             f"{sum(len(c) for _, _, c in samples) / max(total, 1):.0f}", "", "by module (EIP):"]
    lines += [f"  {n / total * 100:5.1f}%  {name}" for name, n in by_module.most_common()]
    lines += ["", "call tree (inclusive, nodes >= 0.5%):"]
    tree_lines(tree, total, 1, 0.005, lines)
    lines += ["", "exclusive by function (top 40):"]
    lines += [f"  {n / total * 100:5.1f}%  {funcs.name(key)}" for key, n in exclusive.most_common(40)]
    lines += ["", "inclusive by function (top 40):"]
    lines += [f"  {n / total * 100:5.1f}%  {funcs.name(key)}" for key, n in inclusive.most_common(40)]
    if hitches:
        inside = sum(counter.total() for counter in per_hitch.values())
        durations = sorted(((end - start) / freq * 1000 for start, end in hitches), reverse=True)
        lines += ["", f"frames over 50 ms: {len(hitches)} ({sum(durations) / 1000:.1f} s); longest "
                  + ", ".join(f"{d:.0f}" for d in durations[:10]) + f" ms; samples inside: {inside}"]
        if inside:
            lines += ["", "call tree inside those frames (nodes >= 2%):"]
            tree_lines(hitch_tree, inside, 1, 0.02, lines)
            lines += ["", "exclusive inside those frames vs overall (top 25):"]
            lines += [f"  {n / inside * 100:5.1f}% vs {exclusive[key] / total * 100:5.1f}%  {funcs.name(key)}"
                      for key, n in hitch_exclusive.most_common(25)]
            lines += ["", "each slow frame (longest 30): QPC start in s (same clock as perfFileLog's t=), ms, "
                      "samples, top leaves:"]
            for h in sorted(per_hitch, key=lambda k: hitches[k][1] - hitches[k][0], reverse=True)[:30]:
                start, end = hitches[h]
                lines.append(f"  t={start / freq:.3f}  {(end - start) / freq * 1000:6.0f}  {per_hitch[h].total():3d}  "
                             + "; ".join(f"{funcs.name(key)} x{n}" for key, n in per_hitch[h].most_common(3)))
    return lines


def write_report(run, functions_path, out_path):
    if not os.path.exists(functions_path):
        print(f"no function table at {functions_path}; samples kept, run --analyze later")
        return
    lines = report(run, Functions(functions_path))
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines[:40]))
    print(f"... report: {out_path}")


def wait_for_game():
    print(f"waiting for {EXE} ...")
    while (pid := find_pid()) is None:
        time.sleep(2)
    time.sleep(5)  # let the loader and UHC.dll finish
    return pid


def sim_clock(process):
    """Game time in ms ([[0xC66234]+13Ch]+FCh, read by FUN_00455d91), or None outside a game."""
    raw = read(process, 0xC66234, 4)
    game = struct.unpack("<I", raw)[0] if raw else 0
    raw = read(process, game + 0x13C, 4) if game else None
    world = struct.unpack("<I", raw)[0] if raw else 0
    raw = read(process, world + 0xFC, 4) if world else None
    return struct.unpack("<I", raw)[0] if raw else None


def game_timers(process):
    """The game's own per-frame averages over its last second, in ms, as (update, render): the
    frame function times the mode manager update into [game+CB4h] and the render call (vtable+78h)
    into [game+CACh], and every second stores the averages at [game+CC0h] and [game+CBCh]
    (docs/performance.md, "Frame structure"). None before the game object exists."""
    raw = read(process, 0xC66234, 4)
    game = struct.unpack("<I", raw)[0] if raw else 0
    raw = read(process, game + 0xCBC, 8) if game else None
    if raw is None:
        return None
    render, update = struct.unpack("<ff", raw)
    return update, render


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("out_csv", nargs="?")
    parser.add_argument("seconds", nargs="?", type=float, default=120.0)
    parser.add_argument("interval", nargs="?", type=float, default=1.0)
    parser.add_argument("--wait", action="store_true", help="wait for the game to start, record until it exits")
    parser.add_argument("--pid", type=int, help="the game process to record (default: the last age3y.exe found)")
    parser.add_argument("--sample-hz", type=float, default=0.0, help="also profile the main thread (e.g. 200)")
    parser.add_argument("--functions", default=DEFAULT_FUNCTIONS, help="function entry table (Ghidra export)")
    parser.add_argument("--analyze", metavar="STACKS_GZ", help="rebuild the report of a saved run")
    args = parser.parse_args()
    if args.analyze:
        base = args.analyze[:-len(".stacks.gz")] if args.analyze.endswith(".stacks.gz") else args.analyze
        write_report(load_stacks(args.analyze), args.functions, base + ".samples.txt")
        return
    if not args.out_csv:
        parser.error("out_csv is required")
    out_path, seconds, interval = args.out_csv, args.seconds, args.interval

    pid = args.pid or (wait_for_game() if args.wait else find_pid())
    if pid is None:
        sys.exit(f"{EXE} is not running")
    process = k32.OpenProcess(PROCESS_ACCESS, False, pid)
    if not process:
        sys.exit(f"OpenProcess failed: {ctypes.get_last_error()}")
    mods = modules(process)
    gpu = Gpu(pid)
    stats = open_stats(pid)
    limit = user_limit(process)
    exe = exe_path(process)
    sites = CallSites(exe) if args.sample_hz > 0 else None
    print(f"pid {pid}; user address space {limit >> 20} MB; GPU counters {'on' if gpu.ok else 'unavailable'}; "
          f"UHC frame stats {'on' if stats else 'off (add perfStats to uhc.cfg)'}"
          + (f"; {len(sites.targets)} possible return addresses in the exe" if sites else ""))

    threads = {}  # tid -> {"handle", "created", "start", "last"}
    last_jobs, last_frames, last_t, last_sim = None, None, time.perf_counter(), None
    sampler, slow_seen, hitches = None, None, []
    rows, deadline = [], time.monotonic() + seconds
    columns = ["t", "fps", "max_frame_ms", "over50", "over100", "update_ms", "render_ms", "sim_speed",
               "process_cpu", "main_cpu",
               "worker_cpu", "top_other", "gpu3d", "ws_mb", "private_mb", "va_mb", "jobs_main_ps",
               "jobs_worker_ps"]
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
                if sites is not None and sampler is None:
                    sampler = Sampler(process, main, args.sample_hz, sites)
                    sampler.start()
                worker = worker_tid(process)
                if stats is None:
                    stats = open_stats(pid)  # UHC.dll may map it after we attached
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
                timers = game_timers(process)
                if timers is not None:
                    row["update_ms"], row["render_ms"] = f"{timers[0]:.2f}", f"{timers[1]:.2f}"
                sim = sim_clock(process)
                if sim is not None and last_sim is not None and sim >= last_sim:
                    row["sim_speed"] = f"{(sim - last_sim) / 1000 / dt:.2f}"  # game seconds per real second
                last_sim = sim
                s = read_stats(stats) if stats else None
                if s:
                    if last_frames is not None:
                        row["fps"] = f"{(s['frames'] - last_frames['frames']) / dt:.1f}"
                        row["over50"] = s["over50"] - last_frames["over50"]
                        row["over100"] = s["over100"] - last_frames["over100"]
                    row["max_frame_ms"] = f"{s['max_us'] / 1000:.1f}"
                    last_frames = s
                    if s["version"] >= 2:
                        if slow_seen is None:
                            slow_seen = read_slow_frames(stats, 0)[0]  # only the frames from now on
                        slow_seen, windows = read_slow_frames(stats, slow_seen)
                        hitches += windows
                if args.wait and time.monotonic() >= deadline:
                    deadline = time.monotonic() + interval  # --wait: keep going until the game exits
                writer.writerow(row)
                f.flush()
                rows.append(row)
                print(f"t={row['t']:>6} fps={row.get('fps', '-'):>6} max={row.get('max_frame_ms', '-'):>6}ms "
                      f"upd={row.get('update_ms', '-'):>6} ren={row.get('render_ms', '-'):>6} "
                      f"sim={row.get('sim_speed', '-'):>5}x main={row['main_cpu']:>5}% "
                      f"worker={row['worker_cpu']:>5}% gpu={row['gpu3d']:>5}% va={row['va_mb']:>5}MB "
                      f"jobs={row['jobs_main_ps']}/{row['jobs_worker_ps']} {top}", flush=True)
        except KeyboardInterrupt:
            pass
    summarize(rows)
    if sampler is not None:
        sampler.stop.set()
        sampler.join(2)
        if sampler.samples:
            run = {"exe": exe, "qpcfreq": qpc_frequency(),
                   "modules": modules(process) or mods, "hitches": hitches, "samples": sampler.samples}
            save_stacks(out_path + ".stacks.gz", run)
            write_report(run, args.functions, out_path + ".samples.txt")


def summarize(rows):
    def stat(key):
        values = [float(r[key]) for r in rows if r.get(key) not in (None, "")]
        return (sum(values) / len(values), max(values)) if values else (0.0, 0.0)

    if not rows:
        print("no samples")
        return
    print(f"\n{len(rows)} samples (mean / max)")
    for key in ("fps", "max_frame_ms", "update_ms", "render_ms", "sim_speed", "main_cpu", "worker_cpu",
                "process_cpu", "gpu3d", "va_mb",
                "jobs_main_ps", "jobs_worker_ps"):
        mean, peak = stat(key)
        print(f"  {key:15s} {mean:8.1f} {peak:8.1f}")
    if any(r.get("over50") not in (None, "") for r in rows):
        print(f"  frames over 50 ms: {sum(int(r.get('over50') or 0) for r in rows)}, "
              f"over 100 ms: {sum(int(r.get('over100') or 0) for r in rows)}")


if __name__ == "__main__":
    main()
