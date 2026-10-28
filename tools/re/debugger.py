"""A minimal Windows debugger for tracing the 32-bit age3y.exe from 64-bit Python.

Only kernel32 through ctypes, no third-party packages. The trace_*.py scripts in this folder
build on it. It attaches to a running game, sets up to four hardware breakpoints (DR0..DR3) on
every thread, reports each hit to a callback, and detaches without killing the game.

Engine helpers at the bottom read game objects. Their addresses and offsets are documented in
docs/engine-symbols.md and are only valid for the stock Steam build of age3y.exe
(SHA-256 b1a1dab7...11d9d) and UHC-patched copies of it.
"""
import ctypes
import ctypes.wintypes as wt
import struct
import time

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
for _name, _res, _args in [
    ("OpenProcess", wt.HANDLE, [wt.DWORD, wt.BOOL, wt.DWORD]),
    ("OpenThread", wt.HANDLE, [wt.DWORD, wt.BOOL, wt.DWORD]),
    ("ReadProcessMemory", wt.BOOL, [wt.HANDLE, wt.LPCVOID, wt.LPVOID, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]),
    ("DebugActiveProcess", wt.BOOL, [wt.DWORD]),
    ("DebugActiveProcessStop", wt.BOOL, [wt.DWORD]),
    ("DebugSetProcessKillOnExit", wt.BOOL, [wt.BOOL]),
    ("WaitForDebugEvent", wt.BOOL, [wt.LPVOID, wt.DWORD]),
    ("ContinueDebugEvent", wt.BOOL, [wt.DWORD, wt.DWORD, wt.DWORD]),
    ("Wow64GetThreadContext", wt.BOOL, [wt.HANDLE, wt.LPVOID]),
    ("Wow64SetThreadContext", wt.BOOL, [wt.HANDLE, wt.LPVOID]),
    ("SuspendThread", wt.DWORD, [wt.HANDLE]),
    ("ResumeThread", wt.DWORD, [wt.HANDLE]),
    ("CloseHandle", wt.BOOL, [wt.HANDLE]),
    ("CreateToolhelp32Snapshot", wt.HANDLE, [wt.DWORD, wt.DWORD]),
    ("Process32FirstW", wt.BOOL, [wt.HANDLE, wt.LPVOID]),
    ("Process32NextW", wt.BOOL, [wt.HANDLE, wt.LPVOID]),
    ("Thread32First", wt.BOOL, [wt.HANDLE, wt.LPVOID]),
    ("Thread32Next", wt.BOOL, [wt.HANDLE, wt.LPVOID]),
]:
    _f = getattr(k32, _name)
    _f.restype, _f.argtypes = _res, _args

PROCESS_READ = 0x0010 | 0x0400  # VM_READ | QUERY_INFORMATION
THREAD_ACCESS = 0x0002 | 0x0008 | 0x0010 | 0x0040  # suspend/resume, get/set context, query
DBG_CONTINUE, DBG_NOT_HANDLED = 0x00010002, 0x80010001

# WOW64_CONTEXT (the 32-bit CONTEXT) as seen from a 64-bit debugger.
CTX_SIZE = 0x2CC
CTX_FLAGS = 0x00010000 | 0x01 | 0x02 | 0x10  # i386 | CONTROL | INTEGER | DEBUG_REGISTERS
OFF_DR = {0: 0x04, 1: 0x08, 2: 0x0C, 3: 0x10, 6: 0x14, 7: 0x18}
OFF_REG = {"edi": 0x9C, "esi": 0xA0, "ebx": 0xA4, "edx": 0xA8, "ecx": 0xAC, "eax": 0xB0,
           "ebp": 0xB4, "eip": 0xB8, "eflags": 0xC0, "esp": 0xC4}
EFLAGS_RF = 1 << 16  # resume flag: run the instruction an execute breakpoint stopped on

# The .text section of age3y.exe, for the return-address heuristic.
TEXT_START, TEXT_END = 0x401000, 0xB84000


class Breakpoint:
    """A hardware breakpoint: kind is "exec", "write" or "rw"; size 1, 2 or 4 (exec: 1)."""

    def __init__(self, address, kind="exec", size=1, label=""):
        if kind not in ("exec", "write", "rw") or size not in (1, 2, 4) or (kind == "exec" and size != 1):
            raise ValueError(f"bad breakpoint {kind}/{size}")
        if address % size:
            raise ValueError(f"a {size}-byte breakpoint needs an address aligned to {size}: {address:#x}")
        self.address, self.kind, self.size = address, kind, size
        self.label = label or f"{address:#x}"


def dr7_value(breakpoints):
    value = 0
    for slot, bp in enumerate(breakpoints):
        rw = {"exec": 0, "write": 1, "rw": 3}[bp.kind]
        length = {1: 0, 2: 1, 4: 3}[bp.size]
        value |= (1 << (2 * slot)) | (rw << (16 + 4 * slot)) | (length << (18 + 4 * slot))
    return value


class _ProcessEntry(ctypes.Structure):
    _fields_ = [("dwSize", wt.DWORD), ("cntUsage", wt.DWORD), ("th32ProcessID", wt.DWORD),
                ("th32DefaultHeapID", ctypes.c_size_t), ("th32ModuleID", wt.DWORD), ("cntThreads", wt.DWORD),
                ("th32ParentProcessID", wt.DWORD), ("pcPriClassBase", ctypes.c_long), ("dwFlags", wt.DWORD),
                ("szExeFile", ctypes.c_wchar * 260)]


class _ThreadEntry(ctypes.Structure):
    _fields_ = [("dwSize", wt.DWORD), ("cntUsage", wt.DWORD), ("th32ThreadID", wt.DWORD),
                ("th32OwnerProcessID", wt.DWORD), ("tpBasePri", ctypes.c_long), ("tpDeltaPri", ctypes.c_long),
                ("dwFlags", wt.DWORD)]


def find_pid(exe_name="age3y.exe"):
    snap = k32.CreateToolhelp32Snapshot(0x2, 0)
    entry = _ProcessEntry()
    entry.dwSize = ctypes.sizeof(entry)
    pid = None
    ok = k32.Process32FirstW(snap, ctypes.byref(entry))
    while ok:
        if entry.szExeFile.lower() == exe_name.lower():
            pid = entry.th32ProcessID
        ok = k32.Process32NextW(snap, ctypes.byref(entry))
    k32.CloseHandle(snap)
    return pid


def wait_for_pid(deadline, exe_name="age3y.exe"):
    while time.time() < deadline:
        pid = find_pid(exe_name)
        if pid is not None:
            return pid
        time.sleep(1)
    return None


def thread_ids(pid):
    snap = k32.CreateToolhelp32Snapshot(0x4, 0)
    entry = _ThreadEntry()
    entry.dwSize = ctypes.sizeof(entry)
    out = []
    ok = k32.Thread32First(snap, ctypes.byref(entry))
    while ok:
        if entry.th32OwnerProcessID == pid:
            out.append(entry.th32ThreadID)
        ok = k32.Thread32Next(snap, ctypes.byref(entry))
    k32.CloseHandle(snap)
    return out


class Process:
    """Read-only access to the game's memory."""

    def __init__(self, pid):
        self.pid = pid
        self.handle = k32.OpenProcess(PROCESS_READ, False, pid)
        if not self.handle:
            raise OSError(f"OpenProcess({pid}) failed: {ctypes.get_last_error()}")
        self._text = None

    def read(self, address, size):
        buf = (ctypes.c_ubyte * size)()
        got = ctypes.c_size_t()
        if not address or not k32.ReadProcessMemory(self.handle, address, buf, size, ctypes.byref(got)) \
                or got.value != size:
            return None
        return bytes(buf)

    def u32(self, address):
        raw = self.read(address, 4)
        return struct.unpack("<I", raw)[0] if raw else 0

    def i32(self, address):
        raw = self.read(address, 4)
        return struct.unpack("<i", raw)[0] if raw else 0

    def f32(self, address):
        raw = self.read(address, 4)
        return struct.unpack("<f", raw)[0] if raw else 0.0

    def cstr(self, address, limit=80):
        raw = self.read(address, limit) or b""
        return raw.split(b"\0")[0].decode("latin-1")

    def wstr(self, address, limit_chars=80):
        raw = self.read(address, 2 * limit_chars) or b""
        return raw.decode("utf-16-le", "replace").split("\0")[0]

    def is_return_site(self, value):
        """True if value looks like a return address: inside .text, right after a call."""
        if not TEXT_START + 8 <= value < TEXT_END:
            return False
        if self._text is None:
            self._text = self.read(TEXT_START, TEXT_END - TEXT_START) or b""
        o = value - TEXT_START
        if o >= len(self._text):
            return False
        t = self._text
        return (t[o - 5] == 0xE8                                                # call rel32
                or (t[o - 6] == 0xFF and t[o - 5] in (0x15, 0x90, 0x91, 0x92, 0x93, 0x95, 0x96, 0x97))
                or (t[o - 3] == 0xFF and 0x50 <= t[o - 2] <= 0x57)              # call [reg+disp8]
                or (t[o - 2] == 0xFF and 0xD0 <= t[o - 1] <= 0xD7))             # call reg

    def call_chain(self, esp, depth=8, scan=0x600):
        """Return addresses found on the stack, innermost first. A heuristic: stale return
        addresses left in unused stack slots can appear too."""
        raw = self.read(esp, scan) or b""
        out = []
        for (value,) in struct.iter_unpack("<I", raw[:len(raw) // 4 * 4]):
            if self.is_return_site(value):
                out.append(value)
                if len(out) == depth:
                    break
        return out


def reg(ctx, name):
    return struct.unpack_from("<I", ctx, OFF_REG[name])[0]


class Debugger:
    """Attach, set hardware breakpoints, and report hits until the game exits or time runs out.

    on_hit(tid, ctx, slots) is called for every breakpoint hit, where ctx is the thread's
    WOW64_CONTEXT (a ctypes byte array; read registers with reg()) and slots lists the
    breakpoint indexes that fired. on_idle() is called about every idle_ms while no debug
    event arrives; it may call set_breakpoints().
    """

    def __init__(self, pid, log):
        self.pid, self.log = pid, log
        self.threads = {}
        self.breakpoints = []
        self.attached = False

    def attach(self):
        if not k32.DebugActiveProcess(self.pid):
            raise OSError(f"DebugActiveProcess({self.pid}) failed: {ctypes.get_last_error()} "
                          "(another debugger attached, or not run as the same user?)")
        k32.DebugSetProcessKillOnExit(False)
        self.attached = True
        for tid in thread_ids(self.pid):
            handle = k32.OpenThread(THREAD_ACCESS, False, tid)
            if handle:
                self.threads[tid] = handle
        self.log(f"attached to pid {self.pid} ({len(self.threads)} threads)")

    def _apply(self, handle, suspend):
        ctx = (ctypes.c_ubyte * CTX_SIZE)()
        struct.pack_into("<I", ctx, 0, CTX_FLAGS)
        if suspend:
            k32.SuspendThread(handle)
        try:
            if not k32.Wow64GetThreadContext(handle, ctx):
                return False
            for slot in range(4):
                address = self.breakpoints[slot].address if slot < len(self.breakpoints) else 0
                struct.pack_into("<I", ctx, OFF_DR[slot], address)
            struct.pack_into("<I", ctx, OFF_DR[6], 0)
            struct.pack_into("<I", ctx, OFF_DR[7], dr7_value(self.breakpoints))
            return bool(k32.Wow64SetThreadContext(handle, ctx))
        finally:
            if suspend:
                k32.ResumeThread(handle)

    def set_breakpoints(self, breakpoints):
        if len(breakpoints) > 4:
            raise ValueError("x86 has four hardware breakpoints")
        self.breakpoints = list(breakpoints)
        for handle in self.threads.values():
            self._apply(handle, True)

    def run(self, deadline, on_hit, on_idle=None, idle_ms=400):
        """Returns "exited" when the game exits, "deadline" when time runs out."""
        event = (ctypes.c_ubyte * 192)()  # DEBUG_EVENT, 64-bit layout
        while time.time() < deadline:
            if not k32.WaitForDebugEvent(event, idle_ms):
                if on_idle is not None:
                    on_idle()
                continue
            code, pid, tid = struct.unpack_from("<III", event, 0)
            status = DBG_CONTINUE
            try:  # every received event is continued, even on Ctrl+C, or the thread stays stopped
                if code == 1:  # EXCEPTION_DEBUG_EVENT
                    exc = struct.unpack_from("<I", event, 16)[0]
                    address = struct.unpack_from("<Q", event, 32)[0]
                    first_chance = struct.unpack_from("<I", event, 168)[0]
                    if exc in (0x80000004, 0x4000001E):  # single step: hardware breakpoint
                        status = self._on_single_step(tid, on_hit)
                    elif exc in (0x80000003, 0x4000001F):  # int3, e.g. the attach break-in
                        status = DBG_CONTINUE
                    else:
                        status = DBG_NOT_HANDLED  # the game's own exception handlers decide
                        if not first_chance:
                            self.log(f"second-chance exception {exc:#010x} at {address:#x}: "
                                     "the game is crashing (not caused by a breakpoint)")
                elif code == 2:  # CREATE_THREAD: the new thread starts suspended
                    handle = struct.unpack_from("<Q", event, 16)[0]
                    self.threads[tid] = handle
                    if self.breakpoints:
                        self._apply(handle, False)
                elif code in (3, 6):  # CREATE_PROCESS / LOAD_DLL: close the image file handle
                    k32.CloseHandle(struct.unpack_from("<Q", event, 16)[0])
                elif code == 4:  # EXIT_THREAD
                    self.threads.pop(tid, None)
                elif code == 5:  # EXIT_PROCESS
                    self.log("game exited")
                    self.attached = False
                    return "exited"
            finally:
                k32.ContinueDebugEvent(pid, tid, status)
        return "deadline"

    def _on_single_step(self, tid, on_hit):
        handle = self.threads.get(tid)
        ctx = (ctypes.c_ubyte * CTX_SIZE)()
        struct.pack_into("<I", ctx, 0, CTX_FLAGS)
        if not handle or not k32.Wow64GetThreadContext(handle, ctx):
            return DBG_NOT_HANDLED
        dr6 = struct.unpack_from("<I", ctx, OFF_DR[6])[0]
        slots = [s for s in range(len(self.breakpoints)) if dr6 & (1 << s)]
        if not slots:
            return DBG_NOT_HANDLED  # a real single step of the game's own
        try:
            on_hit(tid, ctx, slots)
        except Exception as error:  # a broken callback must not leave the game stopped
            self.log(f"breakpoint callback failed: {error!r}")
        struct.pack_into("<I", ctx, OFF_DR[6], 0)
        if any(self.breakpoints[s].kind == "exec" for s in slots):
            flags = struct.unpack_from("<I", ctx, OFF_REG["eflags"])[0]
            struct.pack_into("<I", ctx, OFF_REG["eflags"], flags | EFLAGS_RF)
        k32.Wow64SetThreadContext(handle, ctx)
        return DBG_CONTINUE

    def detach(self):
        # Clear the debug registers before anything that could fail: a breakpoint left set
        # after the debugger is gone raises an exception nobody handles, and the game dies.
        # For the same reason, stop a tracer with Ctrl+C, never by killing its process.
        if self.attached:
            self.breakpoints = []
            for handle in self.threads.values():
                self._apply(handle, True)
            k32.DebugActiveProcessStop(self.pid)
            self.attached = False
            self.log("detached; the game keeps running")


class Logger:
    """Appends timestamped lines to a file and echoes them to the console. Never raises: the
    tracers log from inside the debug loop, where an exception would skip the detach."""

    def __init__(self, path):
        self.path = path
        self.console = True

    def __call__(self, line):
        stamped = time.strftime("%H:%M:%S ") + line
        try:
            with open(self.path, "a", encoding="utf-8") as f:
                f.write(stamped + "\n")
        except OSError:
            pass
        if self.console:
            try:
                print(stamped, flush=True)
            except (OSError, ValueError):
                self.console = False  # the console went away (e.g. a closed pipe); keep the file


# --- Engine helpers (docs/engine-symbols.md) ---------------------------------------------------

GAME = 0xC66234  # pointer to the game object


def world(proc):
    game = proc.u32(GAME)
    return proc.u32(game + 0x13C) if game else 0


def database(proc):
    game = proc.u32(GAME)
    return proc.u32(game + 0x140) if game else 0


def units(proc):
    """Every unit pointer in the world's unit table (world+0Ch, count at world+10h)."""
    w = world(proc)
    if not w:
        return []
    table, count = proc.u32(w + 0xC), proc.u32(w + 0x10)
    if not table or not 0 < count < 300000:
        return []
    raw = proc.read(table, 4 * count) or b""
    return [u for (u,) in struct.iter_unpack("<I", raw) if u]


def unit_player(proc, unit):
    owner = proc.u32(unit + 0x44)
    return proc.i32(owner) if owner else -1


def proto_name(proc, proto):
    name = proc.u32(proto + 0x10) if proto else 0
    return proc.cstr(name, 64) if name else "?"


def unit_info(proc, unit):
    if not unit:
        return "none"
    name = proto_name(proc, proc.u32(unit + 0x5C))
    return f"{name}(player {unit_player(proc, unit)}, hp {proc.f32(unit + 0x64):.1f})"


def home_city(proc, player):
    """The home city object of a player (world+58h player table, count at world+5Ch)."""
    w = world(proc)
    if not w or player >= proc.u32(w + 0x5C):
        return 0
    p = proc.u32(proc.u32(w + 0x58) + 4 * player)
    return proc.u32(p + 0x84) if p else 0
