# Engine symbols

Functions, globals, and object offsets in the stock `age3y.exe` (`b1a1dab7…11d9d`) that upstream
AoE3UnHardcoded uses. Names and signatures are **upstream's inferences** until a row is `confirmed`
with REA evidence. Status and Evidence columns follow the conventions in
[uhc-address-map.md](uhc-address-map.md). Source refs are relative to `reference/AoE3UnHardcoded/`.

## Functions

| VA | Upstream name / role | Signature as used upstream | Source | Status | Evidence |
|---|---|---|---|---|---|
| 0x401234 | `operator new` | `__thiscall(int, size_t*)` | DLL/UHC.cpp:30 | unverified | |
| 0x401A12 | BString ctor | `this, const wchar_t*` | DLL/Cheat.asm:27, DLL/RevBanner.asm:16 | unverified | |
| 0x4010CA | BString dtor | `this` | DLL/Cheat.asm:56 | unverified | |
| 0x40196F | BString assign | `this, src` | DLL/Cheat.asm:49 | unverified | |
| 0x443C10 | BString compare | | DLL/Civs.asm:91 | unverified | |
| 0x58E71F | civ name → civ ID | | DLL/Civs.asm:32 | unverified | |
| 0x5A2346 | proto-unit name → proto ID | on `[db+140h]` | DLL/Units.asm:32 | unverified | |
| 0x52D6FF | civ name → civ object | | DLL/Civs.asm:188 | unverified | |
| 0x44CB0A | unit → proto ID | | DLL/Units.asm:419 | unverified | |
| 0x58E3EB | load texture / icon handle | | DLL/Limits.asm:454 | unverified | |
| 0x58EA52 | localized string by ID | | DLL/Limits.asm:85 | unverified | |
| 0x4676E7 | (team dropdown helper) | | DLL/Limits.asm:94 | unverified | |
| 0x422648 | RNG float | `ecx = 0xC66588` | DLL/Units.asm:519 | unverified | |
| 0xA26321 | set MP team | | DLL/Limits.asm:172 | unverified | |
| 0x5ACE63 | cheat array grow | | DLL/Cheat.asm:36 | unverified | |
| 0x49A98A | add resource to player | `__thiscall(playerData, int res, float amt, bool)` | DLL/UHC.cpp:37 | unverified | |
| 0x7B4F03 | spawn unit (cheat) | `(void*, const char*)` | DLL/UHC.cpp:15 | unverified | |
| 0x624F52 | syscall register | `BOOL __thiscall(this, LPCSTR name, LPCVOID fn, DWORD retType)` | DLL/Patch.cpp:25 | unverified | |
| 0x62505B | syscall param: int | `__thiscall(this, int default)` | DLL/Patch.cpp:29 | unverified | |
| 0x625079 | syscall param: float | `__thiscall(this, float default)` | DLL/Patch.cpp:30 | unverified | |
| 0x62506A | syscall param: bool | `__thiscall(this, BOOL default)` | DLL/Patch.cpp:31 | unverified | |
| 0x624E3F | syscall param: string | `__thiscall(this, LPCSTR default)` | DLL/Patch.cpp:32 | unverified | |
| 0x62734A | syscall param: vector | `__thiscall(this, const float* default)` | DLL/Patch.cpp:33 | unverified | |
| 0x624E56 | syscall comment | `__thiscall(this, LPCSTR)` | DLL/Patch.cpp:34 | unverified | |
| 0x6250B0 | syscall register end | `__thiscall(this)` | DLL/Patch.cpp:35 | unverified | |
| 0xA44B95 | syscall error printf | `(this, LPCSTR fmt, ...)` | DLL/Patch.cpp:26 | unverified | |
| 0xA44C0B | syscall free | `__thiscall(this)` | DLL/Patch.cpp:27 | unverified | |
| 0xA44BEE | syscall get name | `LPCSTR __thiscall(this)` | DLL/Patch.cpp:28 | unverified | |

Syscall return/param type codes (upstream): 1 void, 2 int, 4 float, 8 bool, 16 string, 32 vector
(a vector return goes through a hidden first argument). Groups: AI, HC, KB, RM, TR, UI, UI2, XS.
`DLL/syscalls.cpp` lists ~1,737 syscall entry points with help text (e.g. `resourceMarket` 0x7DEEC5).

## Globals and data

| VA | Role (upstream) | Source | Status | Evidence |
|---|---|---|---|---|
| 0xC66234 | main game object pointer | DLL/Civs.asm:295 | unverified | |
| 0xC66664 | current player index | DLL/syscalls.h:10951 | unverified | |
| 0xC6FB88 | Asian civ ID global | DLL/Civs.asm:216 | unverified | |
| 0xC6FB58, 0xC6FB5C | Native civ ID globals | DLL/Civs.asm:301, 325 | unverified | |
| 0xC66588 | RNG object | DLL/Units.asm:518 | unverified | |
| 0xD65600 / 0xD65604 | cheat array / count (16-byte entries) | DLL/Cheat.asm:33 | unverified | |
| 0xBE3A98 | `L"AI3\"` AI folder string | DLL/Patch.cpp:108 | unverified | |
| 0xC0B39C | `L".personality"` | DLL/Patch.cpp:109 | unverified | |
| 0xC0BBE0 | default farm radius (float 4.5) | DLL/Units.asm:525 | unverified | |
| 0xC0ECC8 | revolution banner path prefix | DLL/RevBanner.asm:14 | unverified | |
| 0xBD62F8 | fame-trickle operand target | DLL/Limits.asm:497 | unverified | |
| 0x9A2180 (≈) | icon jump table (index × 4; slots 0x9A218C Fame, 0x9A2194 XP; default 0x9A2098) | DLL/Limits.asm:481-488 | unverified | |
| 0xC65083 | UHC cfg path (written by the patcher) | DLL/UHC.cpp:48 | n/a (loader patch) | |

## Object layout (upstream, from plugin syscalls)

- `[0xC66234]` game object: `+0x140` database, `+0x13C` world.
- Database: `+0x24` civs `{civ*[], count}` (civ → `{res, char* Name}`), `+0x190` unit types,
  `+0x1FF0` tactics, `+0x3824` techs, `+0x5E58` mill-like proto ID, `+0x5F4C` sacred-field proto ID.
- World: `+0x58` player array, `+0x5C` player count.
- Player data: `[player+0x80]+0xC`; civ `[[pd]+0x20]`, team `[pd+0x10]`.
- Unit: proto at `[unit+0x5C]`; proto ID at proto `+4` or `+8` (both used upstream).

Source: `Documentation/Examples/UHCPluginDemo/syscalls.h` (~lines 11033-11088) and `DLL/syscalls.h`.

## IAT slots (from the loader stub and early patches)

LoadLibraryA 0xB84228 · GetProcAddress 0xB84354 · MessageBoxW 0xB8459C · ExitProcess 0xB8438C ·
HeapAlloc 0xB84180 · HeapReAlloc 0xB841B8 · MultiByteToWideChar 0xB841FC · lstrcpyW 0xB84290 ·
GetCurrentDirectoryW 0xB84348 · FindClose 0xB84380 · lstrlenW 0xB843A8 · lstrlenA 0xB843AC ·
lstrcpynW 0xB843B0 · FindNextFileW 0xB843D0 · FindFirstFileW 0xB843D4

All 15 are **confirmed** by parsing the stock exe's import table (2026-10-27, Python, not REA):
every slot resolves to the named KERNEL32/USER32 import.
