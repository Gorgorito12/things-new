# Engine symbols

Functions, globals, and object offsets in the stock `age3y.exe` (`b1a1dab7…11d9d`) that upstream
AoE3UnHardcoded uses. Status and Evidence columns follow the conventions in
[uhc-address-map.md](uhc-address-map.md). Source refs are relative to `reference/AoE3UnHardcoded/`.
Signatures below are inferred from Ghidra pseudocode and call sites. They are analysis output, not source.

Evidence:
- `E3` = `ev_c2186c76709ade4d96e6ddb026967a0add15fa1cf376fc893b0aaa9c04d0bf6e`: REA `batch_decompile` of every function below, plus the 65 address-map sites. All 29 functions resolve to a Ghidra function whose entry is exactly that address.
  - The record is saved in `rea/evidence/age3y-b1a1dab7/batch_decompile_symbols_and_sites.json` and in `bundle.json`.
  - The snapshot is `rea/snapshots/age3y-b1a1dab7.json`.
  - It replaces the first run, `ev_003a0865…`, whose record was lost when that REA session ended. Both runs gave the same results.
- `E1` / `cs`: see the address map.
- `refs`: count of the 4-byte little-endian address in `.text`. It covers immediates and displacements and is a lower bound for usage.

Notation: `this` is passed in ECX (`__thiscall`); `NNh` is hex.

## Functions

| VA | Role | Signature (inferred) | Source | Status | Evidence | Notes |
|---|---|---|---|---|---|---|
| 0x401234 | allocator call (upstream: `operator new`) | `void* __thiscall(Allocator*, size_t* size)` | DLL/UHC.cpp:30 | confirmed | E3 | Calls `vtbl+14h`. On failure it reports "Unable to allocate memory" and exits. |
| 0x401A12 | BString ctor | `void __thiscall(BString*, const wchar_t*)` | DLL/Cheat.asm:27, DLL/RevBanner.asm:16 | confirmed | E3 | A null or empty source allocates an empty buffer. |
| 0x4010CA | BString dtor | `void __thiscall(BString*)` | DLL/Cheat.asm:56 | confirmed | E3 | Frees `[this]-10h` and zeroes `[this]`. |
| 0x40196F | BString assign | `void __thiscall(BString*, const BString* src)` | DLL/Cheat.asm:49 | confirmed | E3 | The argument is a BString pointer, not a raw string. |
| 0x443C10 | BString compare | `int __thiscall(BString*, const wchar_t*, int start, int len)`; 0 means equal | DLL/Civs.asm:91 | confirmed | E3, cs | Ghidra cuts the body at a terminal call. The signature comes from the call sites (`push -1; push 0; push str`). |
| 0x58E71F | civ name → civ ID | `int __thiscall(Database*, const char* name)`; −1 if not found | DLL/Civs.asm:32 | confirmed | E3 | Iterates `[db+24h]`/`[db+28h]`; the name is at `civ+4`. |
| 0x5A2346 | proto-unit name → proto ID | `int __thiscall(Database*, const char* name)`; −1 if not found | DLL/Units.asm:32 | confirmed | E3 | Iterates `[db+54h]`/`[db+58h]`; the name is at `proto+10h`. |
| 0x52D6FF | civ name → civ object | `Civ* __thiscall(Database*, const char* name)`; 0 if not found | DLL/Civs.asm:188 | confirmed | E3 | Same loop as 0x58E71F, but returns the pointer. |
| 0x44CB0A | unit → proto ID | `int __thiscall(Unit*)` | DLL/Units.asm:419 | confirmed | E3 | Returns `[[unit+5Ch]+8]`, or −1. |
| 0x58E3EB | load texture / icon handle | `int __thiscall(this, const wchar_t* path, bool, int, int)`; −1 on failure | DLL/Limits.asm:454 | confirmed | E3 | Callers push `-1, 0, 0, path`. |
| 0x58EA52 | localized string by ID | `void __thiscall(BString*, int stringId)` | DLL/Limits.asm:85 | confirmed | E3 | |
| 0x4676E7 | BString array setCount (upstream: "team dropdown helper") | `bool __thiscall(BArray<BString>*, int n, bool exact)` | DLL/Limits.asm:94 | confirmed | E3 | Generic resize: it destroys the elements when clearing. Upstream's label was a guess. |
| 0x401113 | int array setCount | `bool __thiscall(BArray<int>*, int n, bool exact)` | DLL/Limits.asm:112 | confirmed | E3 | Not in the original table. Used by the team-limit cave. |
| 0x422648 | RNG float | `float __thiscall(Rng*, int stream, float min, float max)` | DLL/Units.asm:519 | confirmed | E3 | MSVC LCG (`*343FDh + 269EC3h`). The stream state is 12 bytes at `[this+4]`. |
| 0xA26321 | set MP team (upstream) | `bool __thiscall(this, int value)` | DLL/Limits.asm:172 | partial | E3 | Forwards a 4-byte value to 0xA2B475 when `[this+8] != 0`. The team role is not confirmed. |
| 0x5ACE63 | cheat array grow | `bool __thiscall(BArray<Cheat>*, int n, bool exact)` | DLL/Cheat.asm:36 | confirmed | E3 | Array of 16-byte entries; new entries are set to `{-1, -1, 0, 0}`. |
| 0x49A98A | add resource to player | `bool __thiscall(PlayerData*, int res, float amount, bool)` | DLL/UHC.cpp:37 | confirmed | E3 | Splits the amount among teammates when `[[C66234h]+13Ch]+6912h == 1` (shared resources). |
| 0x7B4F03 | spawn unit (cheat) | `void (Player*, const char* protoName)` | DLL/UHC.cpp:15 | confirmed | E3 | Resolves the name through 0x5A2346. |
| 0x624F52 | syscall register | `bool __thiscall(SyscallModule*, const char* name, void* fn, char retType)` | DLL/Patch.cpp:25 | confirmed | E3 | Rejects any retType not in {1, 2, 4, 8, 16, 32}. Errors include "unfinished syscall addition". |
| 0x62505B | syscall param: int | `bool __thiscall(this, int default)` → `0x624DC9(2, &v)` | DLL/Patch.cpp:29 | confirmed | E3 | |
| 0x625079 | syscall param: float | `bool __thiscall(this, float default)` → `0x624DC9(4, &v)` | DLL/Patch.cpp:30 | confirmed | E3 | |
| 0x62506A | syscall param: bool | `bool __thiscall(this, BOOL default)` → `0x624DC9(8, &v)` | DLL/Patch.cpp:31 | confirmed | E3 | |
| 0x624E3F | syscall param: string | `bool __thiscall(this, const char* default)` → `0x624DC9(10h, s)` | DLL/Patch.cpp:32 | confirmed | E3 | Rejects null. |
| 0x62734A | syscall param: vector | `bool __thiscall(this, const float* default)` → `0x624DC9(20h, p)` | DLL/Patch.cpp:33 | confirmed | E3 | |
| 0x624E56 | syscall comment | `bool __thiscall(this, const char*)` | DLL/Patch.cpp:34 | confirmed | E3 | |
| 0x6250B0 | syscall register end | `bool __thiscall(this)` | DLL/Patch.cpp:35 | confirmed | E3 | |
| 0xA44B95 | syscall error printf | `void (this, const char* fmt, ...)` (cdecl) | DLL/Patch.cpp:26 | confirmed | E3 | Formats into a 1 KB buffer. |
| 0xA44C0B | syscall free | `void __thiscall(this)` | DLL/Patch.cpp:27 | confirmed | E3 | |
| 0xA44BEE | syscall get name | `const char* __thiscall(this)` | DLL/Patch.cpp:28 | confirmed | E3 | Falls back to `"NoNewSyscallDefined"`. |

Syscall return/param type codes: 1 void, 2 int, 4 float, 8 bool, 16 string, 32 vector. 0x624F52's
check confirms the set. A vector return goes through a hidden first argument (upstream; unverified).
Groups: AI, HC, KB, RM, TR, UI, UI2, XS. `DLL/syscalls.cpp` lists ~1,737 syscall entry points with
help text (e.g. `resourceMarket` 0x7DEEC5).

## Globals and data

| VA | Role | Source | Status | Evidence |
|---|---|---|---|---|
| 0xC66234 | main game object pointer | DLL/Civs.asm:295 | confirmed | cs. 12,458 refs; every site reads `+13Ch` (world) or `+140h` (database) from it. |
| 0xC66664 | current player index | DLL/syscalls.h:10951 | unverified | 538 refs; role not checked. |
| 0xC6FB88 | Asian civ ID global | DLL/Civs.asm:216 | confirmed | cs. Compared in `isAsianCiv` 0x454ED7 and in 0x8D6AC4. 5 refs. |
| 0xC6FB48, 0xC6FB4C | civ ID globals used by the wonder-civ check 0x49A2D8 | — | confirmed (role: civ IDs) | cs. Not in upstream. |
| 0xC6FB50, 0xC6FB54 | native civ ID globals (always native) | — | confirmed | cs. Checked by `isNativeCiv` 0x453D37. Not in upstream. |
| 0xC6FB58, 0xC6FB5C | native civ ID globals; 5Ch counts only when the bool arg is set | DLL/Civs.asm:301, 325 | confirmed | cs (0x453D37) |
| 0xC66588 | RNG object | DLL/Units.asm:518 | confirmed | E3 (0x422648 layout), 483 refs |
| 0xD65600 / 0xD65604 | cheat array / count (16-byte entries) | DLL/Cheat.asm:33 | partial | E3 (0x5ACE63 is a 16-byte-entry array). 50 / 29 refs. The cheat role is not checked. |
| 0xBE3A98 | `L"AI3\"` AI folder string | DLL/Patch.cpp:108 | confirmed | cs. WoL patches it to `AI4`. |
| 0xC0B39C | `L".personality"` | DLL/Patch.cpp:109 | confirmed | cs |
| 0xC0BBE0 | default farm radius (float 4.5) | DLL/Units.asm:525 | confirmed | cs. 2 refs, one of them the FarmRadius site. |
| 0xC0ECC8 | revolution banner path prefix | DLL/RevBanner.asm:14 | confirmed | cs. Wide string starting `ui\ingame\politician`. |
| 0xBD62F8 | `"Fame"` (fame-trickle key) | DLL/Limits.asm:497 | confirmed | cs. Replaces `"FavoriteUnit"` (0xBCD49C) at 0x51B026. |
| 0x9A2180 | icon jump table (index × 4); slots 0x9A218C Fame and 0x9A2194 XP; set-icon target 0x9A2098; default 0x9A20A0 | DLL/Limits.asm:481-488 | confirmed | cs |
| 0xC65083 | UHC cfg path (written by the patcher) | DLL/UHC.cpp:48 | n/a (loader patch) | |

## Object layout

`[0xC66234]` game object:

| Offset | Meaning | Status | Evidence |
|---|---|---|---|
| `+13Ch` | world | confirmed | cs |
| `+140h` | database | confirmed | cs |
| `+C48h` | flags; bit 1 selects the 14-personality TAD table | observed | cs, AILimit |

Database (`[game+140h]`):

| Offset | Meaning | Status | Evidence |
|---|---|---|---|
| `+24h` / `+28h` | civs `{Civ*[], count}`; a civ's name is at `+4` | confirmed | E3 |
| `+54h` / `+58h` | proto units `{Proto*[], count}`; a proto's name is at `+10h` | new | E3 |
| `+190h` | unit types | upstream, unverified | |
| `+1FF0h` | tactics | upstream, unverified | |
| `+3824h` | techs | upstream, unverified | |
| `+19B0h` | read by AttackTypeIcons #3 | new | cs |
| `+5E30h` | read by MarketUnits | new | cs |
| `+5E58h` | mill-like proto ID | confirmed | cs, FarmAnim #1/#5 |
| `+5E5Ch` | read next to `+5E58h`, after the FarmAnim #5 site | new | cs |
| `+5E64h` | farm check at 0x73D427 | new | cs |
| `+5E68h` | read by TacticSwitching #2 | new | cs |
| `+5F4Ch` | sacred-field proto ID | confirmed | cs, FarmAnim #3 |
| `+607Ch` | rect-farm proto ID | new | cs, RectFarm #1/#3/#4 |
| `+6098h` | read by FarmAnim #2 | new | cs |

The "new" rows are offsets observed in stock code next to the patch sites. Their exact meaning is unverified unless stated.

World (`[game+13Ch]`):

| Offset | Meaning | Status | Evidence |
|---|---|---|---|
| `+58h` | player array | upstream, unverified | |
| `+5Ch` | player count | confirmed | E3, 0x49A98A |
| `+31Ch` | pop-cap-like limit read by PopLimit | new | cs |
| `+6912h` | shared-resources flag | new | E3 |

Other objects:

| Object | Fields | Status | Evidence |
|---|---|---|---|
| Player data | `[player+80h]+0Ch`; civ at `[[pd]+20h]`; team at `[pd+10h]` | upstream, unverified | |
| Unit | proto at `[unit+5Ch]`; proto ID at `proto+8` (confirmed, E3 0x44CB0A) and also at `proto+4` | partial | E3; `proto+4` per FarmAnim #5 and RectFarm #1, meaning unverified |

Sources: `Documentation/Examples/UHCPluginDemo/syscalls.h` (~lines 11033-11088), `DLL/syscalls.h`, and the stock-code observations above.

## Home city and cards (2026-10-28, for `unlockAllCards`)

Evidence:
- `ev_977142568e81aac9…`: the home city loader;
- `ev_fa97cb67f81f913e…`: xrefs to the HC-level getter;
- `ev_5121fec2865f49fc…`: the getter's callers;
- `cs`: capstone scans.

| What | Where | Notes |
|---|---|---|
| Home city loader | FUN_0062E6C9 | A chain of BString compares on the XML tag names (`Name`, `Level` L"…"@0xBA3298, `PrereqTech`@0xBA7248, `Tier`, `SPCAct`, `DisplayUnitCount`, `InfiniteInLastAge`, …). Keys are compared case-insensitively against the lowercase XML tags. |
| HC level | `[hc+54h]` | Written by the loader's first `Level` tag. |
| Player → HC level | 0x8CFBB1 | `[[player+84h]+54h]`, or `[player+88h]` when there is no HC object. Its 8 callers are kbGetHCLevel (0x883350), team min/max/average helpers (0xA0276A, 0xA02855, 0xA02896, 0x6AED5E) and a UI label (0x92CCDF). None is a card-unlock check. |
| HC card array | `hc+204h` | `{data, count, capacity}`; FUN_0062FBC7 appends to it. |
| Card record | 10 dwords (0x28) | `+0` tech ID, `+0Ch` **required level**, … (built at FUN_0062E6C9 lines ~766-778). |
| Card-level check | not found | Not near any `+204h` access. Probably behind an accessor or a virtual call; still open. |

## Home city gather point (2026-10-28, for `hcShipmentPointFallback`)

Evidence: `cs` (capstone of the syscall bodies; they are not Ghidra functions).

| What | Where | Notes |
|---|---|---|
| Gather unit ID | `[hc+18Ch]`, with `hc = [player+84h]` | A **unit ID**, not a position. Initialized to 0 in the HC constructor (0x62C1F5). |
| Player by ID | 0x44CB21 | `thiscall(world = [[C66234h]+13Ch], int playerId)` → player or 0. |
| Unit by ID | 0x44CC6D | `thiscall(world, int unitId)` → unit or 0; the position is at `unit+14h` (3 floats). |
| `aiGetHCGatherPoint` | 0x728050 | The gather unit's position, or the invalid vector at 0xC665E4 when the unit is gone. A dead unit is therefore detectable: `0x44CC6D` returns 0. |
| `aiSetHCGatherPoint` | 0x726236 | Calls 0x82D9CB(game, playerId, unitId). |
| 0x82D9CB | thiscall on the game object | Builds and queues a **network command** (0x5695FC with type 4, then 0x5696E1). It does not write `[hc+18Ch]` itself, so simulation code must not call it on every client. |
| Current player | `[0xC66664]` | Used by the AI syscalls as "the calling player"; confirms the role in the globals table. |

| Water gather unit ID | `[hc+190h]` | The land/water pair is serialized together at 0x8D30C7..0x8D310E (player save/load). The player caches them at `[player+A4h]` / `[player+A8h]`, then writes them through 0xA3FEB8. |
| Command type 4 | factory 0x5695FC → jump table 0x5694E0, case 4 (0x568CE2) | `new(0xAC)`; ctor 0x7D549A, vtable 0xB87DB8. Fields: `+8Ch..+94h` = position (init −1.0f), `+98h..+A0h` = IDs (init −1), `+A8h` = 3. FUN_007D551B validates a position and shows string 0x8546 on failure. Slot 2 (0x7D54F7) is the destructor. Which slot executes is not established. |

Readers of the gather unit through `[player+84h]` (the HC-specific pattern): only 0x728089 (aiGetHCGatherPoint) and 0x8D30D1 (save/load). The shipment-arrival and flag-drawing code therefore read it some other way, probably through a cached HC pointer.

Still open:
- the code that writes `[hc+18Ch]` when the point is set;
- the unit-removal path;
- where shipment arrival resolves the spawn point.

The `+18Ch` offset is shared by many classes (67 writes).

## IAT slots (from the loader stub and early patches)

LoadLibraryA 0xB84228 · GetProcAddress 0xB84354 · MessageBoxW 0xB8459C · ExitProcess 0xB8438C ·
HeapAlloc 0xB84180 · HeapReAlloc 0xB841B8 · MultiByteToWideChar 0xB841FC · lstrcpyW 0xB84290 ·
GetCurrentDirectoryW 0xB84348 · FindClose 0xB84380 · lstrlenW 0xB843A8 · lstrlenA 0xB843AC ·
lstrcpynW 0xB843B0 · FindNextFileW 0xB843D0 · FindFirstFileW 0xB843D4

All 15 are **confirmed** by parsing the stock exe's import table (2026-10-27, Python, not REA):
every slot resolves to the named KERNEL32/USER32 import.
