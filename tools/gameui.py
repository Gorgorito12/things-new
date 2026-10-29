"""Drive a game window for unattended tests: screenshots, clicks, keys and text, in the window's
client coordinates. Used for the AoE3 legacy test bed and AoE3 DE runs (docs/performance.md,
docs/de-architecture.md). It moves the real cursor and takes focus, so use it only when the
machine's owner has allowed it.

Usage: python -I tools/gameui.py [--title REGEX] [--process EXE] <command> [arguments]

  list                      visible windows: owning process, title and client size
  wait [SECONDS]            wait until a visible window matching --title / --process exists
  info                      title, client size and position of that window
  shot OUT.png [SCALE]      screenshot of the client area, downscaled by SCALE (default 2).
                            PrintWindow first; when that comes back black (Direct3D 11 flip
                            model), the window is brought to the front and copied from the screen.
  click X Y [right]         a real mouse click at client coordinates
  move X Y                  move the cursor there (edge scrolling moves an RTS camera)
  key NAME [NAME ...]       key presses by scan code; NAME is a letter, digit or one of
                            escape enter space tab back up down left right home end f1..f12,
                            and combos such as alt+enter or ctrl+shift+c
  type TEXT                 type text as Unicode characters
  focus                     bring the window to the front

The default title is "^Age of Empires (3|III)", which matches both the legacy game and DE. Titles
are localized and other windows (an Explorer folder named after the game) can match, so prefer
--process age3y.exe or --process AoE3DE_s.exe, which picks the largest window of that process.
"""
import argparse
import ctypes
import ctypes.wintypes as wt
import re
import struct
import sys
import time
import zlib

user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32")
try:
    user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))  # per-monitor v2: real pixels
except Exception:
    pass

WNDENUMPROC = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
user32.EnumWindows.argtypes = [WNDENUMPROC, wt.LPARAM]
user32.GetWindowThreadProcessId.argtypes = [wt.HWND, ctypes.POINTER(wt.DWORD)]
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
kernel32.OpenProcess.restype = wt.HANDLE
kernel32.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
kernel32.QueryFullProcessImageNameW.argtypes = [wt.HANDLE, wt.DWORD, wt.LPWSTR, ctypes.POINTER(wt.DWORD)]
kernel32.CloseHandle.argtypes = [wt.HANDLE]
user32.GetWindowTextW.argtypes = [wt.HWND, wt.LPWSTR, ctypes.c_int]
user32.IsWindowVisible.argtypes = [wt.HWND]
user32.GetClientRect.argtypes = [wt.HWND, ctypes.c_void_p]
user32.ClientToScreen.argtypes = [wt.HWND, ctypes.c_void_p]
user32.SetForegroundWindow.argtypes = [wt.HWND]
user32.ShowWindow.argtypes = [wt.HWND, ctypes.c_int]
user32.GetDC.restype = wt.HDC
user32.GetDC.argtypes = [wt.HWND]
user32.ReleaseDC.argtypes = [wt.HWND, wt.HDC]
user32.PrintWindow.argtypes = [wt.HWND, wt.HDC, wt.UINT]
user32.MapVirtualKeyW.argtypes = [wt.UINT, wt.UINT]
user32.SetCursorPos.argtypes = [ctypes.c_int, ctypes.c_int]
gdi32.CreateCompatibleDC.restype = wt.HDC
gdi32.CreateCompatibleDC.argtypes = [wt.HDC]
gdi32.CreateCompatibleBitmap.restype = wt.HBITMAP
gdi32.CreateCompatibleBitmap.argtypes = [wt.HDC, ctypes.c_int, ctypes.c_int]
gdi32.SelectObject.restype = wt.HGDIOBJ
gdi32.SelectObject.argtypes = [wt.HDC, wt.HGDIOBJ]
gdi32.BitBlt.argtypes = [wt.HDC, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wt.HDC, ctypes.c_int,
                         ctypes.c_int, wt.DWORD]
gdi32.GetDIBits.argtypes = [wt.HDC, wt.HBITMAP, wt.UINT, wt.UINT, ctypes.c_void_p, ctypes.c_void_p, wt.UINT]
gdi32.DeleteObject.argtypes = [wt.HGDIOBJ]
gdi32.DeleteDC.argtypes = [wt.HDC]

SRCCOPY, PW_RENDERFULLCONTENT = 0x00CC0020, 2
VK = {"escape": 0x1B, "enter": 0x0D, "return": 0x0D, "space": 0x20, "tab": 0x09, "back": 0x08,
      "up": 0x26, "down": 0x28, "left": 0x25, "right": 0x27, "home": 0x24, "end": 0x23, "grave": 0xC0,
      "shift": 0x10, "ctrl": 0x11, "control": 0x11, "alt": 0x12, "delete": 0x2E, "pageup": 0x21,
      "pagedown": 0x22}
VK.update({f"f{i}": 0x6F + i for i in range(1, 13)})
EXTENDED = {0x25, 0x26, 0x27, 0x28, 0x24, 0x23, 0x2E, 0x21, 0x22}


class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long), ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", wt.WORD), ("wScan", wt.WORD), ("dwFlags", wt.DWORD), ("time", wt.DWORD),
                ("dwExtraInfo", ctypes.c_size_t)]


class MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", ctypes.c_long), ("dy", ctypes.c_long), ("mouseData", wt.DWORD), ("dwFlags", wt.DWORD),
                ("time", wt.DWORD), ("dwExtraInfo", ctypes.c_size_t)]


class _U(ctypes.Union):
    _fields_ = [("ki", KEYBDINPUT), ("mi", MOUSEINPUT), ("pad", ctypes.c_byte * 32)]


class INPUT(ctypes.Structure):
    _fields_ = [("type", wt.DWORD), ("u", _U)]


def process_name(hwnd):
    pid = wt.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    handle = kernel32.OpenProcess(0x1000, False, pid.value)  # PROCESS_QUERY_LIMITED_INFORMATION
    if not handle:
        return "?"
    buf, size = ctypes.create_unicode_buffer(1024), wt.DWORD(1024)
    ok = kernel32.QueryFullProcessImageNameW(handle, 0, buf, ctypes.byref(size))
    kernel32.CloseHandle(handle)
    return buf.value.rsplit("\\", 1)[-1] if ok else "?"


def windows():
    """[(client area, hwnd, title, process)] of the visible, titled windows."""
    found = []

    def callback(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            buf = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(hwnd, buf, 256)
            if buf.value:
                rc = RECT()
                user32.GetClientRect(hwnd, ctypes.byref(rc))
                found.append((rc.right * rc.bottom, hwnd, buf.value, process_name(hwnd)))
        return True

    user32.EnumWindows(WNDENUMPROC(callback), 0)
    return found


def find(title, process=None):
    rx = re.compile(title)
    found = [w for w in windows() if (process.lower() == w[3].lower() if process else rx.search(w[2]))]
    return max(found)[1:3] if found else (None, None)  # the largest one, not a splash or a tool window


def window(title, process=None):
    hwnd, _ = find(title, process)
    if not hwnd:
        sys.exit(f"no visible window matches {process or title!r}")
    return hwnd


def client_rect(hwnd):
    rc, origin = RECT(), POINT(0, 0)
    user32.GetClientRect(hwnd, ctypes.byref(rc))
    user32.ClientToScreen(hwnd, ctypes.byref(origin))
    return origin.x, origin.y, rc.right, rc.bottom


def focus(hwnd):
    user32.ShowWindow(hwnd, 9)  # SW_RESTORE
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.3)


def grab(hwnd, from_screen):
    x, y, w, h = client_rect(hwnd)
    screen = user32.GetDC(None)
    mem = gdi32.CreateCompatibleDC(screen)
    bmp = gdi32.CreateCompatibleBitmap(screen, w, h)
    gdi32.SelectObject(mem, bmp)
    if from_screen:
        gdi32.BitBlt(mem, 0, 0, w, h, screen, x, y, SRCCOPY)
    else:
        # PW_CLIENTONLY (1) | PW_RENDERFULLCONTENT (2)
        user32.PrintWindow(hwnd, mem, 1 | PW_RENDERFULLCONTENT)
    header = struct.pack("<IiiHHIIiiII", 40, w, -h, 1, 32, 0, 0, 0, 0, 0, 0)
    bmi = ctypes.create_string_buffer(header + b"\0" * 16)
    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(mem, bmp, 0, h, buf, bmi, 0)
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mem)
    user32.ReleaseDC(None, screen)
    return w, h, buf.raw


def write_png(path, w, h, data, scale):
    rows = []
    for yy in range(0, h, scale):
        line = data[yy * w * 4:(yy + 1) * w * 4]
        px = bytearray()
        for xx in range(0, w, scale):
            px += bytes((line[xx * 4 + 2], line[xx * 4 + 1], line[xx * 4]))
        rows.append(b"\0" + bytes(px))

    def chunk(kind, payload):
        c = struct.pack(">I", len(payload)) + kind + payload
        return c + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    width = (w + scale - 1) // scale
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, len(rows), 8, 2, 0, 0, 0)) +
                chunk(b"IDAT", zlib.compress(b"".join(rows), 6)) + chunk(b"IEND", b""))


def mostly_black(w, h, data):
    step = max(1, (w * h) // 2000)
    dark = sum(1 for i in range(0, w * h, step) if max(data[4 * i:4 * i + 3]) < 8)
    return dark > 0.97 * ((w * h + step - 1) // step)


def send(*inputs):
    arr = (INPUT * len(inputs))(*inputs)
    user32.SendInput(len(inputs), arr, ctypes.sizeof(INPUT))


def mouse(flags):
    i = INPUT(type=0)
    i.u.mi = MOUSEINPUT(0, 0, 0, flags, 0, 0)
    return i


def to_screen(hwnd, cx, cy):
    x, y, _, _ = client_rect(hwnd)
    return x + cx, y + cy


def key_input(vk, up):
    scan = user32.MapVirtualKeyW(vk, 0)
    flags = 0x0008 | (0x0002 if up else 0) | (0x0001 if vk in EXTENDED else 0)  # SCANCODE, KEYUP, EXTENDED
    i = INPUT(type=1)
    i.u.ki = KEYBDINPUT(vk, scan, flags, 0, 0)
    return i


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # window titles can hold any character
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--title", default=r"^Age of Empires (3|III)")
    parser.add_argument("--process", help="pick the window by its process's exe name")
    parser.add_argument("command", choices=["list", "wait", "info", "shot", "click", "move", "key", "type",
                                            "focus"])
    parser.add_argument("args", nargs="*")
    a = parser.parse_args()
    if a.command == "list":
        for area, hwnd, title, process in sorted(windows(), reverse=True):
            x, y, w, h = client_rect(hwnd)
            print(f"  {process:28s} {w:5d}x{h:<5d} {title}")
        return
    if a.command == "wait":
        limit = time.monotonic() + (float(a.args[0]) if a.args else 300)
        while time.monotonic() < limit:
            hwnd, title = find(a.title, a.process)
            if hwnd and client_rect(hwnd)[2] > 640:
                print(f"window {title!r}")
                return
            time.sleep(2)
        sys.exit("timed out")
    hwnd = window(a.title, a.process)
    if a.command == "info":
        _, title = find(a.title, a.process)
        x, y, w, h = client_rect(hwnd)
        print(f"{title!r}: client {w}x{h} at screen {x},{y}")
    elif a.command == "focus":
        focus(hwnd)
    elif a.command == "shot":
        scale = int(a.args[1]) if len(a.args) > 1 else 2
        w, h, data = grab(hwnd, from_screen=False)
        source = "PrintWindow"
        if mostly_black(w, h, data):
            focus(hwnd)
            w, h, data = grab(hwnd, from_screen=True)
            source = "screen"
        write_png(a.args[0], w, h, data, scale)
        print(f"{a.args[0]}: {w}x{h} client area from {source}, saved at 1/{scale}")
    elif a.command in ("click", "move"):
        focus(hwnd)
        x, y = to_screen(hwnd, int(a.args[0]), int(a.args[1]))
        user32.SetCursorPos(x, y)
        time.sleep(0.15)
        if a.command == "click":
            right = len(a.args) > 2 and a.args[2] == "right"
            down, up = (0x0008, 0x0010) if right else (0x0002, 0x0004)
            send(mouse(down))
            time.sleep(0.08)
            send(mouse(up))
            time.sleep(0.2)
    elif a.command == "key":
        focus(hwnd)
        for name in a.args:
            parts = name.lower().split("+")
            vks = [VK.get(p) or ord(p.upper()) for p in parts]
            send(*(key_input(v, False) for v in vks))
            time.sleep(0.06)
            send(*(key_input(v, True) for v in reversed(vks)))
            time.sleep(0.15)
    elif a.command == "type":
        focus(hwnd)
        for ch in " ".join(a.args):
            down, up = INPUT(type=1), INPUT(type=1)
            down.u.ki = KEYBDINPUT(0, ord(ch), 0x0004, 0, 0)  # KEYEVENTF_UNICODE
            up.u.ki = KEYBDINPUT(0, ord(ch), 0x0004 | 0x0002, 0, 0)
            send(down, up)
            time.sleep(0.02)


if __name__ == "__main__":
    main()
