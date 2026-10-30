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
| 0x443C10 | BString compare | `int __thiscall(BString*, const wchar_t*, int start, int len)`; 0 means equal | DLL/Civs.asm:91 | confirmed | E3, cs | Ghidra cuts the body at a terminal call. The signature comes from the call sites (`push -1; push 0; push str`). With 0 in the third argument it ends in CompareStringW (IAT 0xB84258) with NORM_IGNORECASE (scoping): case is ignored. `buildingWorkRateAuras` calls it for L"BuildingWorkRate" ("Building work rate auras"). |
| 0x58E71F | civ name → civ ID | `int __thiscall(Database*, const char* name)`, `ret 4`; −1 if not found or the name is null | DLL/Civs.asm:32 | confirmed | E3, cs | Iterates `[db+24h]`/`[db+28h]`; the name is at `civ+4`, compared with `_stricmp` (0x4028B4). The civ ID is the index in `[db+24h]`. FUN_00512651 resolves the native civ IDs with it; `danceBonusCivs` resolves its cfg names with it (confirmed in game). |
| 0x5A2346 | proto-unit name → proto ID | `int __thiscall(Database*, const char* name)`; −1 if not found | DLL/Units.asm:32 | confirmed | E3 | Iterates `[db+54h]`/`[db+58h]`; the name is at `proto+10h`. |
| 0x52D6FF | civ name → civ object | `Civ* __thiscall(Database*, const char* name)`; 0 if not found | DLL/Civs.asm:188 | confirmed | E3 | Same loop as 0x58E71F, but returns the pointer. |
| 0x44CB0A | unit → proto ID | `int __thiscall(Unit*)` | DLL/Units.asm:419 | confirmed | E3 | Returns `[[unit+5Ch]+8]`, or −1. |
| 0x58E3EB | load texture / icon handle | `int __thiscall(this, const wchar_t* path, bool, int, int)`; −1 on failure | DLL/Limits.asm:454 | confirmed | E3 | Callers push `-1, 0, 0, path`. |
| 0x58EA52 | localized string by ID | `void __thiscall(BString*, int stringId)` | DLL/Limits.asm:85 | confirmed | E3 | Zeroes `[this]`, then loads the string (0x447719). `showGatherRate` names resources with it ("Gathering and the stat panel"). |
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
| 0xC6FB50, 0xC6FB54 | native civ ID globals (always native): XPIroquois, XPSioux | — | confirmed | cs. Checked by `isNativeCiv` 0x453D37. Written by FUN_00512651 (0x51266C..0x5126BC) through 0x58E71F on each data load, which also writes 0xC6FB7C (`Japanese`). Not in upstream. |
| 0xC6FB58, 0xC6FB5C | native civ ID globals: XPAztec, XPSPC; 5Ch counts only when the bool arg is set | DLL/Civs.asm:301, 325 | confirmed | cs (0x453D37). The four dance readers compare all four ("Dances" below). |
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
| `+92Ch` | random map object (RM); byte `[rm+1A95h]` is the Nomad start (rmGetNomadStart 0x90B683) | confirmed (reads); observed | cs (0x90B683, objectDef::place 0x925936); in game it stayed allocated during the tested games, byte 0 ("Civ first town center") |
| `+C48h` | flags; bit 1 selects the 14-personality TAD table | observed | cs, AILimit |

Database (`[game+140h]`):

| Offset | Meaning | Status | Evidence |
|---|---|---|---|
| `+24h` / `+28h` | civs `{Civ*[], count}`; a civ's name is at `+4` | confirmed | E3 |
| `+54h` / `+58h` | proto units `{Proto*[], count}`; a proto's name is at `+10h` | new | E3 |
| `+80h` | resource count (the stat panel's AutoGather loop runs to it) | confirmed | cs, `showGatherRate` in game |
| `+180h` / `+184h` | resource name string IDs `[[db+180h]+4·r]`, count (getter 0x60782A) | confirmed | cs, `showGatherRate` in game |
| `+190h` | unit types | confirmed | cs; see "Unit types and healing" |
| `+1FF0h` | tactics | upstream, unverified | |
| `+3824h` | tech names: array of wide-string pointers by tech ID, count `[+3828h]` | confirmed | cs (getter 0x5C400B), `techPrereqRecheck` in game |
| `+335Ch` / `+3360h` | effect type name table / its count (the next effect type ID) | confirmed | cs, `techRenameEffect` in game |
| `+5D9Ch` | the database's tech tree (TT0) | confirmed | cs, `techRenameEffect` in game; see "Tech tree and tech effects" |
| `+19B0h` | proto count (read by AttackTypeIcons #3) | confirmed | cs; see "Unit types and healing" |
| `+5E08h` / `+5E0Ch` / `+5E14h` | proto IDs of `TownCenter` / `CoveredWagon` / `Outpost`, cached by name (0x5EE8ED, …) | confirmed (`+5E08h`); scoping (the others) | cs; see "Starting buildings" |
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
| `+0Ch` / `+10h` | units by ID: array, count (index = ID & 3FFFFh) | confirmed | cs, `damageOverTime` in game |
| `+58h` | player array | confirmed | cs (TakeDamage), `damageOverTime` in game |
| `+5Ch` | player count | confirmed | E3, 0x49A98A |
| `+7Ch` | tech status manager: the 16 per-player tech trees, `[+4·playerId]` | confirmed | cs, `techPrereqRecheck` and `techRenameEffect` in game |
| `+F8h` | step count: +1 per world update (0x481A87) | confirmed | cs, `damageOverTime` in game |
| `+104h` | length of the current step (seconds, inferred) | new | cs (Maintain and regeneration updates) |
| `+108h` | game time, ms (advanced by the world update FUN_00481A57) | confirmed | cs, `damageOverTime` in game |
| `+310h` | training rate (`trRateTrain`) | new | cs (Maintain update) |
| `+318h` | gather multiplier: multiplies every gather tick's rate (0x4ED01B) and the AutoGather rate (0x49EDEC, scoping); meaning of its source unknown | new | cs (`showGatherRate`) |
| `+31Ch` | pop-cap-like limit read by PopLimit | new | cs |
| `+330h` | dopple manager | new | cs; see "Dopples" |
| `+56Ch` | ability manager (`abilities.xml`) | confirmed | cs, `abilitySlots` and `wonderPanelSkipAuras` in game |
| `+5ACh` | global LOS multiplier (1.0) | new | cs (LOS getter 0x48206D) |
| `+6912h` | shared-resources flag | new | E3 |

Other objects:

| Object | Fields | Status | Evidence |
|---|---|---|---|
| Player data | `[player+80h]+0Ch`; civ at `[[pd]+20h]`; team at `[pd+10h]` | upstream, unverified | |
| Player | `+0` player ID; `+20h` pointer to the civ IDs, `+24h` their count (the dance readers take `[[player+20h]]`); `+50h` current age (compared by the ability code); `+80h` knowledge base (KB); `+84h` home city; `+E0h`/`+E4h` the player's proto copies; `+1D4h` stances toward each player, `[player+1D4h+4·id]` (2 = enemy, 0 or 1 = ally; 0x484D2D / 0x4707EC); `+338h` non-zero for a player the tech update and the gather tick skip (defeated, inferred); `+37Ch` a float that multiplies every gathered amount (0x4ED13A) and, when `0x485D2C(action, 16h)` is true, the Train update's rate (FUN_009EA28B); `+349h` bit 40h, player flag 14: the request for the town starting units, set through the flag setter 0x8D00E5 and cleared at 0x679B63; `+3E0h` the player's colony list (FUN_007C238E); `+4F0h` FirstTC, the unit ID of the first Town Center ("Starting town center"); `+507h` TC spawning allowed and `+50Ah` revolted (both inferred) | confirmed (reads), inferred where marked | cs; `danceBonusCivs`, `techPrereqRecheck`, `maintainWaitForPop`, `startingTC`, `civFirstTC` and `showGatherRate` in game |
| Unit | proto at `[unit+5Ch]`; proto ID at `proto+8` (confirmed, E3 0x44CB0A) and also at `proto+4` | partial | E3; `proto+4` per FarmAnim #5 and RectFarm #1. TakeDamage's callers pass `[[unit+5Ch]+4]` as the attacker proto ID, which FUN_0045311B maps back to the proto (`damageOverTime` relies on it, confirmed in game). More unit fields: "Damage and poison" below. |

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
| Max deck size | FUN_007EEFF7 | `int __thiscall(db, int level)`, `ret 4`. Returns 20 for a negative level, 25 past the end of the level table (`mov eax,19h` at 0x7EF005), otherwise the level's `maxdecksize` clamped to 20..25. The callers checked (0x852E45, 0x865D1A) pass `[hc+54h]`; 8 callers in all. `deckCardCount` patches both 25s. |
| HC level table | `[db+60D0h]`, count `[db+60D4h]` | Records of 12 B: `{xp, maxdecksize, -1}`, loaded from `homecitylevels.xml`. Read from a running game (2026-10-28): 132 levels, 20 cards at level 0, +1 every 10 levels, 25 from level 50. |

## Home city gather point (2026-10-28, for `hcShipmentPointFallback`)

Evidence: `cs` (capstone of the syscall bodies; they are not Ghidra functions).

| What | Where | Notes |
|---|---|---|
| Gather unit ID | `[hc+18Ch]`, with `hc = [player+84h]` | A **unit ID**, not a position. Initialized to 0 in the HC constructor (0x62C1F5). |
| Player by ID | 0x44CB21 | `thiscall(world = [[C66234h]+13Ch], int playerId)`, `ret 4` → `[world+58h][id]` for 0 ≤ id < `[world+5Ch]`, else 0 (0x4649E1). Sites `PlayerById`, `PlayerByIdNull` (`noTrainNearEnemyTC`). |
| Unit by ID | 0x44CC6D | `thiscall(world, int unitId)`, `ret 4` → `[[world+0Ch]+4·(id & 3FFFFh)]` if the index is below `[world+10h]` and that unit's `[unit+10h]` is the ID, else 0 (0x4E2A35). The position is at `unit+14h` (3 floats). Sites `UnitById`, `UnitByIdNull` (`noTrainNearEnemyTC`); `startingTC` and `showGatherRate` repeat the lookup in C++, as the FirstTC rule does inline (0x8CE597). |
| Get gather unit | FUN_004C6B9E | `Unit* __thiscall(hc, bool store)`, `ret 4` (cs, 2026-10-29). 10 callers: 0x4C6D38 (pushes EBX = 0), 0x63FD3E, 0x6966D4 (command panel FUN_0046188E), 0x7B4F31, **0x857F06** (FreeHomeCityUnit FUN_00857E77, store 1; bails at 0x857F3F on 0), **0x8584B5** (FUN_00858299, store 1; its water alternative is 0x855D71 at 0x8584AA), 0x8585FF, 0x9CEF2B, 0x9DA942, 0x9E656C; all others push 0. "FUN_004C6CAE" in older notes is only the label after `call 4C6CA0h` inside it. |
| Stored point check | 0x85302C | `bool __thiscall(hc, Unit*)`, `ret 4`: false for null; then the unit's vtbl+A4h (alive), 0x44DDB4, and 0x4802C6 != 1 (`setne al`). No owner and no type check. Called for the stored point at 0x6697D8; the stock blocks inline the same three calls. Site `GatherPointValid` (`hcShipmentPointFallback FirstTC` calls it; confirmed in game 2026-10-29). |
| Gather point setter | FUN_008527EC | `void __thiscall(hc, int unitId)`: `[hc+18Ch] = unitId` (the write is at 0x8527F0). Callers: 0x7D580B (the move-flag command; it checks only the owner) and 0x67AA3E (copies `[player+A4h]`). 0x85282F is the water twin. |
| `aiGetHCGatherPoint` | 0x728050 | The gather unit's position, or the invalid vector at 0xC665E4 when the unit is gone. A dead unit is therefore detectable: `0x44CC6D` returns 0. |
| `aiSetHCGatherPoint` | 0x726236 | Calls 0x82D9CB(game, playerId, unitId). |
| 0x82D9CB | thiscall on the game object | Builds and queues a **network command** (0x5695FC with type 4, then 0x5696E1). It does not write `[hc+18Ch]` itself, so simulation code must not call it on every client. |
| Current player | `[0xC66664]` | Used by the AI syscalls as "the calling player"; confirms the role in the globals table. |

| Water gather unit ID | `[hc+190h]` | The land/water pair is serialized together at 0x8D30C7..0x8D310E (player save/load). The player caches them at `[player+A4h]` / `[player+A8h]`, then writes them through 0xA3FEB8. |
| Command type 4 | factory 0x5695FC → jump table 0x5694E0, case 4 (0x568CE2) | `new(0xAC)`; ctor 0x7D549A, vtable 0xB87DB8. Fields: `+8Ch..+94h` = position (init −1.0f), `+98h..+A0h` = IDs (init −1), `+A8h` = 3. FUN_007D551B validates a position and shows string 0x8546 on failure. Slot 2 (0x7D54F7) is the destructor. Which slot executes is not established. |

**Dynamic trace (2026-10-28).** Captured with hardware read/write breakpoints on `hc+18Ch`/`hc+190h` of player 1. Reproduce it with `python -I tools/re/trace_writes.py gather.txt hc:1+0x18C hc:1+0x190 --rw` (the original log, `hwbp-log.txt`, is local evidence under `rea/`). The game starts with land = water = −1.

Hardware breakpoints report the EIP **after** the access, so the first column names the
instruction that made the access and the reported EIP is in the notes.

| Instruction | Role | Notes |
|---|---|---|
| 0x4C6BC0 | Frequent reader (444 hits; reported EIP 0x4C6BC6) | `mov eax,[ebx+18Ch]` in FUN_004C6B9E. The older note's 0x4C6D3D is the return address of its caller at 0x4C6D38; 0x4C61DC is not a caller. |
| 0x8527F0 | Setter, when the user moves the flag (reported EIP 0x8527F6) | In FUN_008527EC: `[hc+18Ch] = unitId`. Reached from the command path through 0x7D5810 → 0x64D31F → 0x481BC7. 0x85282F is the water twin. |
| 0x6697F5 | Cleared to −1 when the TC was deleted (reported EIP 0x6697FF) | Inside FUN_004C6B9E, on the store = 1 path, when the stored unit fails 0x85302C; not a separate unit-removal writer. The stack showed 0x8584BA (return of the call at 0x8584B5 in FUN_00858299) ← 0x511901 ← 0x66AEA5. |
| 0x669E3F | Immediately set again, to the other building (reported EIP 0x669E45) | Inside FUN_004C6B9E, the store path 0x669E38..0x669E45 that 0x4C6CB2 enters: `if (store) [hc+18Ch] = [unit+10h]`. |

**Stock fallback** (FUN_004C6B9E, cs 2026-10-29). When the stored unit fails 0x85302C, it takes
the first unit of the player, of these 10 types in this order, that passes the same three checks
(`vtbl+A4h`, `0x44DDB4`, `0x4802C6 != 1`). A building of any other type is never chosen.

| # | Type | Type ID read at | Read |
|---|---|---|---|
| 1 | TownCenter | 0x4C6BF1 (main body 0x4C6BCF..0x4C6CD2; inline checks 0x4C6C5E..0x4C6CB0) | `[db+5E08h]` |
| 2 | Outpost | 0x669824 | `[db+5E14h]` |
| 3 | FortFrontier | 0x6698D4 (block 0x6698B4, site `GatherFallbackBlock`) | `[db+6034h]` |
| 4 | WarHut | 0x669984 | `[db+6074h]` |
| 5 | Blockhouse | 0x669A34 | `[db+6044h]` |
| 6 | NoblesHut | 0x669AE4 | `[db+606Ch]` |
| 7 | AbstractAgraFort | 0x669B89 | `[[0DC139Ch]]` (a pointer to 0xDC13A0) |
| 8 | AbstractDaimyo | 0x669C3B | `[db+19B0h]+69h` (abstract type #69h) |
| 9 | ypCastle | 0x669CEE | `[db+5EBCh]` |
| 10 | ypVillage | 0x669D9E | `[db+5F6Ch]` |

db = `[[0C66234h]+140h]`. The cold chunk ends at 0x669E2C; the "nothing found" exit is
0x669E2E (`5D 5F 5E 33 C0 5B 59 C2 04 00`), and the store is 0x669E38..0x669E45. At that exit
`[esp+10h]` = hc, `[esp+18h]` = store, ESI = the query object, and EBX, EBP and EDI are free.
Ev: `ev_dc7644827b43…` (first list), cs (2026-10-29, full list).

Readers of the gather unit through `[player+84h]` (the HC-specific pattern): only 0x728089 (aiGetHCGatherPoint) and 0x8D30D1 (save/load). The shipment-arrival and flag-drawing code therefore read it some other way, probably through a cached HC pointer.

Answered (cs, 2026-10-29):
- the code that writes `[hc+18Ch]`: the setter FUN_008527EC (from the command at 0x7D580B, which
  checks only the owner, and from 0x67AA3E, a copy of `[player+A4h]`), and FUN_004C6B9E itself
  (0x6697F5 clears, 0x669E3F stores);
- the "unit-removal path" is FUN_004C6B9E's store = 1 path (0x6697F5), reached from 0x8584B5;
- shipment arrival resolves the drop point at 0x857F06 (FreeHomeCityUnit, store 1) and 0x8584B5
  (FUN_00858299, store 1).

The `+18Ch` offset is shared by many classes (67 writes).

## Unit types and healing (2026-10-28, for `healNonIdle`)

Evidence: `cs` (capstone of the stock exe), plus a runtime memory read of the test copy (see the end of this section). `db = [[C66234h]+140h]`.

**Unit types.**

| What | Where | Notes |
|---|---|---|
| Unittype name table | `db+190h` | Holds protos and abstract types. Name count `[db+194h]` = next free ID; the stock code asserts IDs are dense. |
| Proto count | `[db+19B0h]` | IDs `0..protoCount-1` are protos; abstract types follow. Written at 0x51A59E after the proto names are registered. |
| Name → bucket | 0x58E685 | `int __thiscall(table, const char* name)`: upper-cases the name, hashes it through the function pointer `[table+181Ch]`, masks with `[table+1818h]`, `ret 4`. **Not** a lookup by itself. |
| Find name | 0x40295B | `bool __thiscall(table, const char* name, int bucket, int* id)`, `ret 0Ch`. Callers set `*id = -1` first. The pair 0x58E685 + 0x40295B is the stock lookup pattern, e.g. in the logical-type cache at 0x51BA4E. |
| Add name | 0x5E3549 | `__thiscall(table, const char* name, const int* id)`, `ret 8`. Copies the name (0x467BAA) and stores `*id`; if the name already exists it takes another path (0x65951D). |
| Built-in abstract types | FUN_0051A5DC | `thiscall(db)`. Registers a **fixed list** of names compiled into the exe (`Unit`, `Ship`, `Building` … `AbstractJapaneseMonk`) with `id = protoCount + k`. It then registers the 75 names of the logical-type table at 0xDC10F0..0xDC121C (whose IDs are cached at 0xDC121C+). Epilogue at 0x51BA31. |
| Proto unittype bitset | `proto+30h` (bytes), `proto+34h` (bit count) | Sized at 0x5F769A to `[db+194h] - [db+19B0h]` through 0x4219EA, so the size follows the table and is not a constant. Bit = `id - protoCount`. |
| Is-a test | 0x44D7FA | `bool __thiscall(proto, int typeId)`, `ret 4`. A proto ID compares against `proto+8` (or `proto+4`); an abstract ID tests bit `id - protoCount`; a negative ID is false. Use this for IDs from the name table. True exit 0x44F139. Changes EAX/ECX/EDX and saves ESI (cs). Every marker key calls it. |
| Raw bit test | 0x44CAC4 | `bool __thiscall(proto, int bitIndex)`, `ret 4`. Takes the **abstract index** (already minus protoCount), not a table ID. Indices seen: 37h `Herdable` (the stat panel's AutoGather row), 58h `AbstractShrine` (the gather tick), 5Dh `AbstractMonk` (the Maintain spawn). Site `IsAbstractIndex` (`showGatherRate`). |

**Consequence.** Every abstract type that `protoy.xml` may use is in the exe: 153 of the 155 non-proto `<UnitType>` names in stock `protoy.xml` are strings in the exe. The other two are `AbstractTypeVictoryPointBuilding` (ignored by stock) and our own. A `<UnitType>` whose name is not registered is silently dropped. A new marker type must therefore be added to the table, which `src/unittypes.cpp` does at 0x51BA31.

**Healing.**

| What | Where | Notes |
|---|---|---|
| Hit points | `unit+64h` (float) | Found by polling unit memory for a float that dropped when hit and rose while an Indian monk healed, then confirmed with a hardware write breakpoint (local evidence `hwbp2-log.txt`; reproduce with `tools/re/trace_writes.py hp.txt unit:Explorer+0x64`). Writers 0x4820B7 (FUN_004820A1, which sets the value) and 0x4A17A9 (clamp to max). |
| Max hit points | 0x480408 | `float __thiscall(unit)` (st0). The per-unit override, else `[proto+98h]`: see "Hit points and their displays" below. |
| Add hit points | FUN_004823A3 | `thiscall(unit, amount, flag)`, `ret 8` (REA `ev_b83c97e4…`): when the unit's state bits allow it, calls the setter FUN_004820A1(HP + amount, flag) and adds an amount above 1e-6 to the healed total `[[unit+0B4h]+0E4h]`. 17 callers: heals and damage (negative); the list and what `overhealSources` does with each are in how-it-works.md, "overhealSources". Site `OverhealAddEntry`. |
| Set hit points | FUN_004820A1 | `thiscall(unit, value, flag)`, `ret 8`; the flag runs 0x482152, the death check (HP < 1e-6: kill or destroy, events; REA `ev_241c1390…`); no attack event (those come from TakeDamage). `overhealDecay` calls it with flag 0. Site `HpSetter`. stores `[unit+64h]`; with a per-unit max override clamps in 0x6A2CB3, else to [0, `[proto+98h]`]; updates the damage visuals of a damaged unit (0x48223F(22h), 0x9CB73E per stage); 0x48233B(7) → 0x487A21(0, 1); with `flag`, 0x482152. 32 callers (creation 0x49839B, transforms, the rescale 0x9C73xx, triggers…). |
| Regeneration adds | 0x490881 (FUN_004905E1), 0x67A03B (the Regeneration dance) | Confirmed, in game. `push 1 / push eax / mov ecx,esi / call 4823A3h`: the unit's own regeneration and the dance's add HP on every step of an idle unit. `overhealDecay` flags both (sites `RegenAddHp`, `DanceRegenAddHp`) so they do not restart its delay. |
| Heal tick end | 0x9E0BBB | In FUN_009E0B53 (REA `ev_e9a25933…`): `call 480408h` / `fcomp [edi+64h]` / `jnp 9E0D3Fh`: the tick heals only while HP < max, else the action ends (`vtbl+34h(10)`). The heal is added at 0x9E0CE9 (`0x487C45(target) × [world+318h] × [world+104h]`). Sites `HealTickMax`, `HealTickAdd` (`overhealSources`). |
| Heal tick | FUN_009E0B53 | The heal action applying one tick. EDI = target, ESI = heal action, `[esi+10h]` = healer, `[esi+14h]` = target ID. Action state byte at `action+61h` (0 start, 8 healing, 10 stop). |
| "Target busy" check | 0x9E0C79..0x9E0C9E | `[target+58h]` = the target's current action. If it exists and `0x4802D4(-1)` (moving) or `0x9CA5AC` (fighting) returns 1, the tick ends at 0x9E0D3F. Otherwise it heals from 0x9E0C9F. |
| Automatic heal search | FUN_009CD865 | `thiscall(owner)`, healer at `[owner+4]` (EBP in the body). It returns at once unless `[[healer+5Ch]+44h]` is set. It runs a unit query around the healer (world `+184h`, 0x49A098; result entries of 38h bytes). It takes the first candidate that passes every check: not the healer itself; HP ratio (0x45F295) in [1e-6, 1); `vtbl+A4h`; `[c+58h]` not null; **0x44F1A7 idle**; not abstract bit 6 (0x44CAC4); not flag 0x42 (0x44D863); 0x4EE797(player, healer, c, 5, …) for action type 5; 0x9C2E40(5, 8) ≤ 0; and the reach test 0x7FCF2D. Then it starts the action through 0x9CBDC4(id). Called from 0x68C14E with `ecx = [unit+58h]`. Loop (REA `ev_41afc083…`): the query is `[world+184h]` (set up by 0x492716 / 0x4DBFBB(3), centred on `[healer+14h]`, radius from 0x48206D, run by 0x49A098 → 0x499CE4); results `[query+0]`, 38h-byte entries with the unit ID at `+0`, count `[query+4]`, no cap in the loop; index `[esp+14h]`, offset `[esp+10h]`. The range test is 0x7FCF2D(healer, c, range from 0x470F5E) at 0x9CDA36; the first candidate in range jumps to 0x9CDA62 (healer `vtbl+64h(1)`, 0x9CBDC4(owner, `[c+10h]`)), which reads only ESI and EBP; the loop's end 0x9CDA58 returns AL = 0. Sites `SmartHealLoop`, `SmartHealRange`, `SmartHealLoopEnd` (`smartHealTargets`). |
| Target is idle | 0x44F1A7 | `bool __thiscall(actionManager)`. True when `[mgr+24h]` (current action) is null or has type byte `[action+60h]` = 7. Otherwise it returns false, except for a per-player case (`[player+4FCh] = 1`, 0x45FC1A). |
| Command predicate | FUN_004C6CD7 | `bool __thiscall(?, word code, target, result*, out*)`, `ret 10h`. `code - 8` indexes the byte table at 0x4C726C → jump table 0x4C7230 (15 cases); out-of-range codes return true. Code 0x41 (case 8, 0x4C6D58) requires: target fully built (0x44DDB4; an earlier version of this table called it "alive", see "Lifespan and construction"), `[target+68h] != 0`, HP < max, not fighting (0x9CA5AC), no action of type 0x35 (0x4C72E5), then 0x9C0B73. Code 0x42 (case 9) requires the same HP/fighting checks **and** an action of type 0x35. `this` is the **player**: case 11 reads `[this+84h]`, the home city. Case 8 overwrites it with the target. 12 callers, e.g. 0x695510 with code 0x41. The dynamic trace below never reached cases 8/9 while surgeons healed, so the predicate is not on the heal path. |

**Runtime check (2026-10-28).** The test copy has `AbstractHealNonIdle` added to `ypMonkIndian` and `ypMonkIndian2`. After the database loads, `UHC.log` shows `AbstractHealNonIdle -> 1666 (bit 203 of 204)`. Reading memory then gave protoCount 1463 and 1667 names. Every proto's bitset has 204 bits. Bit 203 is set on both Indian monks and clear on `ypMonkJapanese` and `Explorer`.

**Dynamic trace (2026-10-28).** Hardware execute breakpoints at 0x4C6D91, 0x4C6DDD and 0x9E0B53 while British surgeons stood next to a fighting explorer (local evidence `hwbp3-log.txt`). Reproduce it with `python -I tools/re/trace_exec.py heal.txt 0x4C6D91=pred-0x41@esi 0x4C6DDD=pred-0x42@esi 0x9E0B53=heal-tick@[ecx+0x10]`.
- The surgeons only healed after the fight ended. The predicate breakpoints never fired.
- The heal tick ran 31 times, through two chains:
  - `0x9E0DBD ← 0x4893AB ← 0x48979C ← 0x482F9A`: the action update.
  - `0x9E0DBD ← 0x494938 ← 0x9CBE7A ← 0x9CDA77`: the action's first tick, started by the automatic search FUN_009CD865.
- That search's idle test (0x44F1A7) is what kept the fighting explorer out.

## Damage and poison (2026-10-28, for `damageOverTime`)

Evidence:
- REA decompiles: `ev_6e351116…` (FUN_0049B3D9), `ev_2e667abc…` (FUN_0048649F), `ev_e08d032e…`
  (0x49AEE0, 0x49ACAA, 0x5A2346, 0x402733), `ev_1d03c0af…` (0x9C68C3, 0x9C276A, 0x485D2C,
  0x9DA019), `ev_a05f93de…` (0x471967, 0x4714A7, 0x470F76), `ev_10ac0c0d…` and `ev_45644a4a…`
  (action names), `ev_24390830…` and `ev_4138ea31…` (XML loader);
- `cs`: capstone, including functions Ghidra did not create (vtable-only methods such as
  0x484E3E, 0x48CED0, 0x9DA078), disassembled by recursive descent;
- in game: the `damageOverTime log` runs on `C:\AoE3-UHC-Poison` (2026-10-28).

This section replaces an earlier one, "Poison leftovers", that had two errors. The name table it
called "unit action types" is the **unit event** table. And the Poison flag does have a reader:
TakeDamage.

**The damage path.**

| What | Where | Notes |
|---|---|---|
| TakeDamage | FUN_0049B3D9 | `float __thiscall(unit, int attackerPlayer, int attackerProtoId, Action* action, int attackerUnitId, float multiplier, float damage, float cap, char p8, char p9, char p10, char p11, int p12, char p13)`, `ret 34h`; returns the damage dealt. With `damage` ≤ 0 it computes it from `action` (FUN_0048649F); with `cap` > 0 it caps it; it never exceeds the unit's HP. Returns 0 for a contained unit (`[unit+6Ch] != -1`) and, with p13 = 1, for some invulnerability flags of the unit's proto. HP is subtracted through FUN_004823A3 at 0x49B822. p8 = 0 runs the notification, XP and stats block; within it, p11 = 1 (with an attacker player) runs the hit reactions, gated at 0x49B926 (`cmp bl,1; jne 0x49BC00`): retaliation FUN_0049C0D4, the attack sounds and alerts (p9 = 0, `[game+950h]`), FUN_00484C72 (p10 ≠ 0), and the army attacker list (below). p12 = −2 skips FUN_0049AA03. 18 call sites: special damage (0x6A374C, 0x986237, 0x9871B8, …) passes p8..p13 = `0, 0, 1, 1, -2, 1`; the attack applier FUN_0049BE95 calls it at 0x49C087. |
| Attacker unit in TakeDamage | `[esp+28h]` in the body (piVar7) | Looked up from attackerUnitId in the world's unit table; null when that unit is gone. The Poison-event part checks it (0x49BB39), but the army part does not: for a living target with unit flag 37h, `[world+B8h]` set and p11 = 1, 0x6A3253 runs `mov ecx,[edi+5Ch]` with edi = the attacker unit, then FUN_008C264A with `[edi+10h]`. A null attacker crashes there (static reading, `ev_574ff798…` and `cs`; not reproduced in game). `damageOverTime` passes p11 = 0 for a tick whose attacking unit is gone. |
| Army membership | unit flag 37h (bit 7 of `[[unit+4]+6]`) | Set at 0x8C2F2D after FUN_008C2544 adds the unit to an army. FUN_009C0562 (`[[unit+B4h]+C8h]` → `+44h`, else −1) gives the unit's army ID; `[world+B8h]` is the army manager (FUN_004A9203 finds an army by ID); FUN_008C264A adds an attacker ID to an army's list and stamps `[army+34h]` with the game time. AI armies use them. Units sent by the scenario trigger `Army Deploy` (`trArmyDispatch`) do not get the flag nor an army record (`[[unit+B4h]+C8h]` null, bits read in a running game, 2026-10-29); nor do units a map adds with `rmCreateArmy(int playerID, string armyName)` / `rmAddUnitsToArmy(int playerID, int armyID, int objectDefID)`; nor the military units of two Hard AIs at minute 26 (army ID −1 through `+44h`). FUN_008C2544 has one direct caller, 0x8C2F20, in a function reached only indirectly (not traced). |
| Damage from an action | FUN_0048649F | `float __thiscall(unit, int player, int protoId, Action* action, int attackerUnitId, float multiplier)`. Base damage `*[action+24h]`; the diplomacy filter FUN_0049AEE0; the bonus against the unit's proto (0x49AD18, 0x49AD60); the armor of the damage type (0x49B323); the dodge (0x49ACAA, tech `ypDodge`) and the critical / divine strike powers. A missing attacker unit is allowed. |
| Damage info | `[action+24h]` → 8 B | `+0` float damage, `+4` byte DamageFlags, `+5` byte damage type. FUN_005FB14F (`<Damage>`) allocates it with flags FFh (all) and type FFh; FUN_005FB0C5 sets the flags. |
| DamageFlags | parsed at 0x5FAFD1 | Substrings of the tag text: `GAIA` 1, `Self` 2, `Ally` 4, `Enemy` 8; `GAIAEnemy` = 9. |
| Diplomacy filter | FUN_0049AEE0 | `bool(attackerUnit, unit)`, ECX = damage info. True without an attacker unit. Gaia units need GAIA, own units need Self. A unit of a player that the attacker's player rates 2 (`[player+1D4h+4*id]`, enemy) needs Enemy; any other player's unit needs Ally. |
| ROF | `[action+34h]` | int ms: `<ROF>` × 1000, truncated (0x5F8EB6). |
| Lifespan | `[proto+ACh]` | float seconds (handler 0x5FCF4B). |

**The stock poison: an Age of Mythology leftover that does nothing.**

| What | Where | Notes |
|---|---|---|
| Poison flag | bit 8 of the action's flag bytes `[action+64h]` | Set by the `Poison` handler 0xA11D4D of the 105-tag map (other bits: Active 0, Persistent 2, SingleUse 3, AddResourcesFasterWhenOwned 5, MuteDamage 6, ReflectDamage 7, Throw 14). FUN_005F98A0, which parses `<ProtoAction>`, has no `Poison` compare, so how data would set it is not established. No stock data uses it. |
| Flag reader | TakeDamage, 0x49BB4F → 0x6A3200 | When the attacker unit has an action manager, the action has bit 8, and the attacker's current action `[mgr+24h]` runs this action (`[cur+4] == action`), it calls `attacker->vtbl[10h](20h, [cur+8], unit ID, damage)`. |
| Unit `postEvent` | unit vtable slot 10h, 0x484E3E | `bool __thiscall(unit, int type, int actionId, int data1, float data2)`, `ret 10h`. Takes an event from the world pool (0x484D4D) and queues it on the unit's action manager `[unit+58h]` (0x484EDB). |
| Event | 30h B | `+10h` sender proto ID, `+14h` sender unit ID, `+18h` serial, `+1Ch` type, `+20h` game time, `+24h` data1, `+28h` float data2, `+2Ch` action ID. Queue: list at `[mgr+30h]`, tail `[mgr+38h]`, count `[mgr+60h]`. The type must be below `[db+2004h]`. |
| Event types | names registered at 0x5243CC..0x524A1F (`[db+2000h]`) | Damage 0, MoveDone 1, MoveFailed 2, UnderAttack 3, AnimationLooped 4, Attack 5, Idle 6, ProjectileHitUnit 7, ProjectileHitTerrain 8, SubActionDone 9, SubActionFailed 0Ah, Particles 0Bh, SpecificSound 0Ch, SpecificSoundSet 0Dh, TaskUnit 0Eh, SubActionSearchNeeded 0Fh, Retarget 10h, FootstepLeft 11h, FootstepRight 12h, TargetDied 13h, Move 14h, WaypointReached 15h, GoneIdle 16h, Return 17h, Goto 18h, ChangeState 19h, TargetGone 1Ah, Foundation 1Bh, Failure 1Ch, Success 1Dh, Train 1Eh, EjectUnit 1Fh, **Poison 20h**, MoveRetry 21h, TargetLost 22h, NuggetFound 23h, CameraShake 24h, DestroyUnitType 25h, BeginTurretRotation 26h, TargetDiedWall 27h. |
| Event handler | unit action vtable slot 44h | Base 0x48CF88; 21 action classes override it. Most switch on `type - k`. Only the attack class handles Poison. |
| Attack action | factory types 4, 0Ah, 0Fh, 28h: ctor 0x511AA4, vtable 0xB96278, handler 0x48CED0 | Its switch (0x48CF5A, on `type - 5`) sends Poison to 0x48F175. If the action's target `[action+14h]` is still the event's unit and alive (`vtbl+A4h`), it calls 0xB1BE43 on the unit's action manager with `(damage × −0.1, 3.0)` (0xC0C830 = −0.1f). |
| 0xB1BE43 | `mov al,1; ret 8` | Empty: the stock poison applies nothing. |
| Action type 20h | ctor 0x9D9D49 (`new(78h)`), vtable 0xB975D8 | Unrelated to the Poison event: action types and event types are separate enums. Its update (slot 3Ch, 0x9DA078) ejects the contained units (`[unit+70h]`/`[unit+74h]`, 0x9C68C3). |
| Protoaction type names | table at `[esi+19B8h]`, around 0x52280F | `Decay`, `Gather` 3, `HandAttack` 4, `Heal` 5, … (Heal = 5 matches 0x4EE797(…, 5, …) in the heal search). |

**Objects and functions that `damageOverTime` uses.**

| What | Where | Notes |
|---|---|---|
| Unit | vtable 0xB934B8 (ctor 0x9C4A8F; base ctor 0x4F6A70, vtable 0xB93190) | `+4` state bits (count `+8`), `+10h` ID, `+44h` player object (`[+0]` = player ID), `+58h` action manager, `+5Ch` proto, `+64h` HP (float), `+68h` building data (null for most units; "Building work rate" below), `+6Ch` container unit ID (−1 when not contained), `+70h`/`+74h` contained unit IDs and count, `+B4h` a sub-object (lifespan timers, base LOS, the resource inventory, the modifier record; see the WoL sections). |
| Unit alive | unit vtable slot A4h, 0x44D019 (pointer at 0xB9355C, site `UnitAliveSlot`) | `bool __thiscall(unit)`: state bit 8 of `[unit+4]` set, bit 12 clear, HP > 1e-6. Uses EAX/ECX/EDX only. The stock code tests it before special damage, in the Poison event handler and in the visibility update (0x4868FA, a virtual call). The base vtable 0xB93190 has 0x58EA6B in that slot. `startingTC` and `noTrainNearEnemyTC` call it on a first Town Center. |
| World | `[game+13Ch]` | Units by ID: `[world+0Ch]` array, `[world+10h]` count; index = ID & 3FFFFh, and `[unit+10h]` must equal the ID. Players: `[world+58h]` array, `[world+5Ch]` count. Game time: `[world+108h]`, ms. |
| World update | FUN_00481A57 | `bool __thiscall(world, int, int deltaMs)`, `ret 8`: raises the step count `[world+F8h]` by 1 (0x481A87), adds deltaMs to `[world+108h]`, then runs the world (the body the rendering section lists as 0x481B1C). Two flags at `[world+691Bh]` / `[world+691Eh]` branch to out-of-line blocks (0x6AE55F, 0x6AE845) before the step count; both come back to 0x481A7F, just before it. 0x481A87 is the only `add dword ptr [esi+0F8h],1` in the exe, and no branch after it leads back, so each call adds exactly 1. Called directly only from 0x482044 (FUN_0048202E), and also listed in the vtable at 0xB95730 (slot 6F4h). It runs for other worlds too: it compares `this` with `[game+13Ch]` at 0x481D01. Hooked once at its entry (5 B, site `DotWorldUpdateEntry`) by the shared wrapper of `worldtick.cpp` (`damageOverTime`, `overhealDecay`). |
| Player's proto | FUN_0045311B | `Proto* __thiscall(player, int protoId)`, `ret 4`: the player's copy `[player+E0h][id]` (count `[player+E4h]`), else the database proto. IDs at or above the count are per-player dynamic protos, `(player ID + 1) × 100000 + index`, from `[player+ECh]` (12-byte entries, count `[player+F0h]`). It only reads (`ev_7e87e1bc…`). |
| Proto ID by name | FUN_005A2346 | `int __thiscall(db, const char* name)`: a linear search of `[db+54h]`/`[db+58h]` comparing `[proto+10h]` with FUN_004028B4; −1 when not found. It only reads (`ev_78f40452…`). |
| Proto | | `+4` proto ID (the index in `[db+54h]`; TakeDamage's attacker proto ID is `[[unit+5Ch]+4]`), `+10h` name, `+44h` action set, `+98h` MaxHitpoints and `+9Ch` InitialHitpoints ("Hit points and their displays"), `+ACh` Lifespan, `+D0h` BuildingWorkRate, `+E0h` the resource object ("Resource inventories"). |
| Action set | `[proto+44h]` | Actions `[set+1Ch]`, count `[set+20h]`; lookup by name 0x5F8FDB. |
| Action (tactics `<action>` / `<ProtoAction>`) | | `+4` name index, `+8` type, `+24h` damage info, `+34h` ROF, `+64h`/`+68h` flag bytes and bit count. |
| Action names | `[db+1FD8h]` | One UTF-16 string per name index, count `[db+1FDCh]`, string IDs `[db+1FE4h]`. 0x5F8F9F: index → name; 0x5E0C64: name → index; FUN_005F9830: add. |
| Unit action (runtime) | base ctor 0x4EF1FC; factory 0x48D927 (pool) → 0x4EF2A0, jump table 0x4EF820 (4Ch types) | `+4` the tactics action, `+8` action ID, `+10h` owner unit, `+14h` target ID, `+18h` target position, `+30h`/`+34h` state bits, `+60h` type byte, `+61h` state. Vtable slots: 10h set target (0x471967), 34h set state, 3Ch update, 44h handle event, 5Ch/60h save/load. |

**Loading a data XML** (FUN_00599A7D, `(dir, name, ?, allowXmb)`). With both `name` and `name.xmb`
found, the game loads the XMB **unless the XML is newer**: FUN_00600DD1 compares the two file times
down to the millisecond. With only one of them, it uses that one: the XML is parsed with MSXML.
Both lookups go through FUN_00467991, which searches the data folders. Whether that includes the
`.bar` archives, and their stored times, was not traced. In the tests the game parsed the loose
`data\protoy.xml` when it was newer than the XMB (`perfFileLog` showed the whole file read).

**Parsers** (`ev_591176ac…`; the pseudocode is saved locally as `rea/evidence/age3y-b1a1dab7/pseudo_protoaction_parser_5f98a0.c`, not in the repository).

| What | Where | Notes |
|---|---|---|
| `<Unit>` tag map | FUN_0051CE1D, map at `this+0Ch`, filled through 0x59B738(name, handler) | Called from 0x51DB46 (a second map at `this+C2Ch` is initialized there too). 105 entries: the `protoy` unit tags (`DBID`, `Icon`, `AnimFile`, `MaxHitpoints`, `Flag`, `Lifespan` 0x5FCF4B, `ProtoAction` 0x5FA158, `Armor`, …), followed by action-style tags (`Rate` … `UseBuckets`, including `Poison`). Handler shape: `handler(?, node, target)`, `ret`. Attributes are read with 0x598F37(node, "attr", &out); text is converted with 0x59AC86 (float). |
| `<ProtoAction>` handler | 0x5FA158 | `edi = target = proto`, `ebx = node`. It looks up the action named by the node's `<Name>` in the proto's action set `[proto+44h]` (0x5F8FDB). If found: `FUN_005F98A0([proto+44h], proto, action, node)`. If the proto has no such action (e.g. no tactics entry), it goes to 0x5FC891 without parsing. |
| Action parser | FUN_005F98A0 | `thiscall(actionSet, proto, action, node)`. An if-chain of 87 compares `0x443C10(nameStr, L"Tag", 0, -1)` (0 = equal), shared by `.tactics` `<action>` and `protoy` `<ProtoAction>`. In the loop, EDI = child node and ESI = the **address** of its name BString, `[[node+4]+18h] + 4*[node+18h]` (lea at 0x5F993E; 0xD6FC90 when the index is out of range), so the UTF-16 name is `[esi]`; the text is `*(wchar_t**)(node+14h)`. `action[1]` = action name ID (from `<Name>`), `action[2]` = type, `[action+64h]` = flag bytes. The last compare is `ModifyExclusive` (0x5FA10F); an unknown tag falls through 0x5FA11E to the loop increment 0x5FA126 and is silently ignored. Handlers also return to 0x5FA126, so only 0x5FA11E is a safe "unknown tag" hook. At 0x5FA11E the stack holds the return address at `[esp+C0h]` (0x5FA213 when called by the `<ProtoAction>` handler), the proto at `[esp+C4h]` and the action at `[esp+C8h]`. `damageOverTime` hooks it for `<AttachProtoUnit>`. |

**Stock data.** No tactics file (209 checked) and no `protoy.xml` entry uses `Poison`, `MuteDamage` or `ReflectDamage`. The only "poison" in the data is `NatPoisonArrowFrogs`, an ordinary tech.

## XS compiler (2026-10-28, found while testing `damageOverTime`)

Evidence: REA `ev_59c97c7c…` (FUN_005B52FF, assembly), `ev_bffbf424…` (FUN_005B4E4C),
`ev_8b283564…` (FUN_00627796), `ev_9545d84f…` and `ev_75461769…` (error strings), `ev_88989736…`
(callers of 0x43A3A4); `cs` for the error reporters; in game, traces with the breakpoints of
`tools/re/trace_xs.py` on `C:\AoE3-UHC-Poison`.

| What | Where | Notes |
|---|---|---|
| Compile a file | FUN_005B52FF | `thiscall(compiler, …)`, `ret 14h`. Calls FUN_005B4FE7, then FUN_005B4E4C; when that fails, it logs `Error 0003: could not compile file '%S'.` (0xC3FC00, at 0x6C05CF) with the file name. That is the only line the game shows. |
| Compile one file | FUN_005B4E4C | Errors 0009, 0010 and 0011 (invalid source, circular include, no tokenizer), `Info 0001: Compiling file`, then the parse. Errors are counted in `[[compiler+118h]+14h]`; if the count is above 0 at the end, it logs `%d error(s) found in file '%s'.` and returns 0. An error counted before the file starts fails it too. |
| Parser errors | 0xA48EB4 `thiscall(fmt, arg)`, `ret 8`; 0xA48F61 `thiscall(fmt)`, `ret 4` | Both format the text (0xA5C70E) and pass it to FUN_0043A3A4(message log `[this+118h]`, current file name, text). 0x43A3A4 has 8 callers, all XS code. FUN_00A5667F, `cdecl(message log, fmt, ...)`, logs compiler-level messages such as Error 0003. |
| Variable declarations | FUN_00627796 | Parses `extern`, `export`, `static` and `const` declarations. `Error 0014: '%s' is already defined.` (0xC3E864) comes from 0x627C8A when the name exists. Extern variables are stored as `EXTERN$<name>`. |
| The game's declarations | compiled before each AI script, as a file named `EXTERN` | Constants the game generates from the data, among them `cTactic<name>` for each tactic name of the loaded tactics files. A repeated name fails with Error 0014 in `EXTERN`, and the script then fails with Error 0003. Where the text is generated was not traced. |

Observed in game:
- **A tactics XML with a line break after a tactic name.** The file was read as XML (no `.xmb`),
  had LF line endings, and had `<tactic>Normal` followed by a line break. Every later game start
  then logged `Error 0014: 'cTacticNormal' is already defined.` in `EXTERN`, then Error 0003 for
  `aiLoaderStandard.xs`, and no AI player acted. These variants all compiled cleanly:
  - the same file with CRLF line endings;
  - `<tactic>Normal<action …>` on one line;
  - the file compiled to `.xmb`.
- **Inference.** The XML path keeps the line feed and the indentation in the tactic name, while
  the stock `.xmb` files store their names trimmed. The name then differs from the stock
  `Normal` and makes a second constant. How CRLF avoids it was not traced.
- **When the AI compile runs.** A skirmish start compiles the AI scripts before it reloads the
  data, so a tactics file that one skirmish start loads shows up in the next game's AI compile.
  This is inferred from the order of the traces.

## Dodge and critical hits (2026-10-28, for `dodgeAnyUnit`, `dodgeSoundSet`, `criticalSoundSet`)

Evidence: REA pseudocode `ev_87814ff803bbe02e0635f58474888be710e1a027b1e570f0088ce2a25ad10007`
(FUN_0049ACAA); `cs` (capstone of the stock exe) for the cold chunks, the cache writers and the
call sites; in game on the test bed, with the `log` option (2026-10-28).

| What | Where | Notes |
|---|---|---|
| Dodge test | FUN_0049ACAA | `bool __thiscall(unit)`. True = the hit is dodged. Conditions: database, `[unit+44h]` player, world, `[world+7Ch]` non-null; proto ID `[[unit+5Ch]+4]` ∈ {`[db+5E88h]`, `[db+5E8Ch]`, `[db+5E90h]`}; tech `ypDodge` active for the player; `0x407CE7(2, 100)` in [0, 15). The visible case shows string 0xF9CE as floating text and plays the sound set `"PowerEvade"` (0xBD74E0). Cold chunk 0x6A248D..0x6A2650. |
| Caller | 0x49B023 in FUN_0048649F (damage from an action) | `mov ecx,esi / call 49ACAAh / test al,al / jne 4DD5B3h`; the only caller. ESI = the unit hit, EBX = the attacker unit (from the ID by an inline lookup at 0x49AFC2, 0 when gone). |
| Proto ID cache | `db+5E74h`…`db+5EA0h`, written at 0x5EEB75…0x5EEC7D through 0x5A2346 (proto ID by name) | `ypBerryBuilding`, `ypPotala`, `ypMonkChinese`, `ypMonkChinese2`, `ypMonkChinese3`, `ypMonkJapanese` (+5E88h), `ypMonkJapanese2`, `ypMonkJapanese3`, `ypMonkIndian` (+5E94h), `ypMonkIndian2`, `ypMonkIndian3`, `ypMonkDisciple` (+5EA0h). Other readers: 0x556E80 (cache reset), 0x6A0150 (monk-specific code, not identified) and 0x8F76C7, `bool __thiscall(proto)` "is a Japanese monk" (`[proto+8]` against the three IDs). Its only caller, 0x6AB049, picks string IDs 0x112C2..0x112C4 per monk family before jumping to 0x50B039, probably a rollover text (inference; not traced). |
| Tech by name | 0x600BE1 | `int __thiscall(db, const char* name)`, over the names at `[db+3824h]`; −1 when absent. (An earlier version of this row gave no `this`; `techRenameEffect` calls it as thiscall, confirmed in game.) All tech names exist before the effects are parsed, so forward references resolve. |
| Tech active for a player | 0x94AF27 | `bool __thiscall(techStatus = [world+7Ch], int playerId, int techId)`. |
| Sync RNG | 0x407CE7 on the object at 0xC66588 | `int __thiscall(rng, int a, int b)`; here (2, 100), compared as a float with 0.0 and 15.0 (0xBA1474). |
| Play a sound set by name | 0x4AA24C | `__thiscall(game, const float* position, const char* name, void* extra)`, `ret 0Ch`. Calls `[game+950h]`→0x4AA201. The names are sound sets of `Sound\soundsetsy.xml` (found in `SoundXML3.bar`). |
| Critical-hit sound | 0x6A2A73..0x6A2AA8 (damage function, cold chunk) | `push "PowerCriticalStrike"` (0xBD7518) at 0x6A2A9A, played at the attacker `[esp+44h]` = EBX. Reached when the attack's `HitPercentType` is `CriticalAttack` and its roll succeeds (stock: the Chinese monk's HandAttack, `HitPercent` 20). |
| Power name table | `db+2FE4h`, registered at 0x52430E… | Includes `PowerCriticalStrike` (22h), `PowerDivineStrike` (23h), `PowerConvertDisciple` (24h), `PowerEvade` (25h). Role not established. |

**Runtime check (2026-10-28).** A test map (two players, no AI) put an Explorer with
`AbstractDodge` and a `ypMonkJapanese` against four musketeers, with `YPDodge` (tech index 169)
set active by a trigger. With `dodgeAnyUnit AbstractDodge log`, the Explorer dodged 3 and then 5
hits in two runs, the monk 2 and 0. With `dodgeAnyUnit AbstractNoOne log` (a marker no unit
has), the Explorer never dodged and the monk dodged 6 times. A first run whose trigger did not
activate the tech had no dodge at all, monk included: the tech condition holds for both.

## Projectile accuracy and spread (2026-10-28, for WoL request #2)

Evidence: REA pseudocode `ev_7824a864a13fff8e6d0572f7a502352f6f7d2fb48216ff9d85ec96d84f94eda5`
(the launch fragment Ghidra calls FUN_004995c7) and
`ev_6476290bdc5072fe4d2758d1ac4b4e7b7e0da3592a03ff0a76e9b67e5a7b8b05` (0x4A5B7E, 0x4CEF8C,
0x4A5B02); `cs` for the instruction sequence; hardware read breakpoints on the action fields
while two groups fought on the test bed (`tools/re/trace_writes.py … --rw`, 2026-10-28).

| What | Where | Notes |
|---|---|---|
| Accuracy field | action `+38h` (float) | Written by the `Accuracy` handler 0x5F8CF0 (default 1.0). ROF is `+34h`. |
| Flags that skip the roll | action flag bytes `[+64h]` | `InstantBallistics` sets bit 22 (`or byte [flags+2],40h`, 0x5F8D2E): the projectile is a sure hit and accuracy is never read. `PerfectAccuracy` sets bit 28 (`or byte [flags+3],10h`, 0x5FCE28): sure hit, no roll. |
| Precalculated hit | 0x499807..0x499899, inside the projectile launch (`ballisticPrecalcHits`, cfg var `[0xCEFFD4]`, gates the block) | `ebx = 1`; unless bit 28 is set, `ebx = 0x4A5B7E(projectile, accuracy = [edi+38h])` (read at 0x49984E). After 0x4A5B02 (target leading, `TrackRating`), `cmp ebx,2 / je 4CEF7Bh` sends a miss to the offset, then `[projectile+20h] = ebx` at 0x499899. |
| The roll | FUN_004A5B7E | `int __thiscall(projectile, float accuracy)`: 1 = hit, 2 = miss. `chance = round(accuracy × 100 − 0.5 × d)`, d = 2D distance shooter→target; chance < 1 → miss, > 100 → hit, else uniform 0..100 ≤ chance → hit (RNG 2, `0x4228DF`). A target whose proto has abstract bit 2 always counts as hit on one path. |
| The spread (miss only) | FUN_004CEF8C, called from 0x4CEF82 | `r = min(0.25 × d, 5.0)`; the impact point's x and z each move by uniform(−r, r). **Hardcoded**: 0.25 and 5.0 are the stock tactics' `spreadfactor` and `maxspread` values, but those tags are not read. |
| Tags TAD does not parse | — | No string, no handler: `MaxSpread`, `SpreadFactor`, `AccuracyReductionFactor`, `AimBonus`, `UnintentionalDamageMultiplier`, `NumberProjectiles` (case-insensitive search of the exe, ASCII and UTF-16). They survive in tactics files from Age of Mythology. Parsed: `Accuracy`, `PerfectAccuracy`, `InstantBallistics`, `TrackRating`, `NumberBounces`, `Projectile`, `Throw`. |

**Runtime check (2026-10-28).** Musketeers (`InstantBallistics`) fighting: ROF read ~200 times,
accuracy never. Crossbowmen (projectile `Arrow`, no `InstantBallistics`): accuracy read at
0x49984E on every shot, call chain through 0x48F892 / 0x448C6D.

**Consequence for WoL's shotguns.** Their `VolleyRangedAttack` has `accuracy 0.3`,
`maxspread 5`, `spreadfactor 1.8`, `numberprojectiles 6` and no `InstantBallistics`. In TAD that
means one projectile per shot that misses most of the time, scattered by the stock
`min(0.25 × d, 5)`: their `spreadfactor` and the six projectiles do nothing. With accuracy 1 the
same unit almost never misses, hence "no spread".

## Starting buildings (2026-10-28, partial, for WoL request #3)

Evidence: `cs` and string references in the stock exe; WoL's binaries and data searched as files.
The exe's own "starting TC", the placement rules' `FirstTC`, is in "Starting town center" below.

| What | Where | Notes |
|---|---|---|
| TownCenter proto ID cache | `db+5E08h`, written at 0x5EE8ED through 0x5A2346("TownCenter") | 25 code references, each classified by the scoping of request #3 (2026-10-29): only 0x506B3B feeds FirstTC; the others are the shipment-point fallback (0x4C6BF1), the `trPlayerToggleAllowTCSpawning` gate on `Maintain` (0x492FD6), the town starting units (0x679AC8 in FUN_0049039A, which the scoping had filed under `startingResourceDelay`; `civFirstTC` hooks it, see "Civ first town center"), the `CoveredWagon` build limit (0x857FD5, 0x8D8ECC, 0x727FAA), the repair cost (0x9C0B95), `ConvertCoveredWagon` (0x4C6E9D), the AI (0x4D4ED8, 0x73D256) and interface code (age-up picker 0x7E6905 / 0x7E803F, age-up progress, music, a sort bias). A second "is a TownCenter" test, FUN_004CF222 (type cached at `[0xCF065C]`), serves the AI auto-bases and chats. `db+5E0Ch` caches `CoveredWagon`, `db+5E14h` `Outpost`. |
| `"TownCenter"` string 0xBCC600 | refs 0x5EE8E2 (the cache), 0x66FC0D/0x66FC27 (unit type lookup by name), 0x79DEBC (a UI table), 0x7DEEB1 (call 0x82FAD6), 0x82E481 | 0x82E45B is the **start camera**: it looks at the first of `camera start`, `TownCenter`, `CoveredWagon`, `Explorer`, `Settler`, `Unit` that the world has. |
| Who places the starting TC | the random map script | e.g. `great plains.xs`: `rmAddObjectDefItem(startingTCID, "TownCenter", 1, 0.0)` (a `CoveredWagon` for a nomad start); the civ's `<startingunit>` / `<townstartingunit>` come from `rmCreateStartingUnitsObjectDef` (`Special_StartingUnits`, 0x90D69A, 0x924921). |
| `StartingTC` | — | Not a string in the stock exe, WoL's `age3*.exe`, `uhc.dll`, `wol.dll`, or WoL's `protoy.xml` / `civs.xml` / `techtreey.xml`. |

## WoL features (2026-10-29)

The sections below back the 21 features built for WoL's requests
([wol-requests.md](wol-requests.md)): the 14 of Tier 2, then `startingTC`, `civFirstTC` and
`transformInventory` (Tier 1) and `noTrainNearEnemyTC`, `overhealHitpointBars`, `showGatherRate`
and `buildingWorkRateAuras` (Tier 3). Evidence, for every table:
- **confirmed:** capstone of the stock exe (`cs`) for the feature, re-read during its
  implementation; the ranges a feature relies on are also sites in `tools/gen_sites.py`, which
  `VerifyAll` checks on every start;
- **scoping:** read by the scoping pass of the request or by its adversarial verifier (also `cs`),
  not re-read byte by byte. Those scripts and listings were not exported to `rea/evidence`;
- **in game:** observed in the single-player tests of 2026-10-29 (see each feature in
  [modding-guide.md](modding-guide.md)).

No REA session was used for these sections.

### Building work rate (for `liveBuildingWorkRate`)

| What | Where | Status | Notes |
|---|---|---|---|
| Proto BuildingWorkRate | `[proto+D0h]` (float) | confirmed (reads); handler scoping | Tag `<BuildingWorkRate>` (handler 0x5F81E5); default 1.0. Read live by the getter's tail 0x9BFE41, the copy 0x6A208F and the stat panel 0x6F49FC. |
| Building data | `[unit+68h]`, 84h B (init 0x4E5E8F) | `+28h` confirmed; rest scoping | Created by setProto 0x4981F3 when the proto is a `Building` or has flag 57h `ForceBuildingData`; kept when the proto changes. `+4` build points, `+8` build fraction (≥ 1.0 = complete), `+28h` the BuildingWorkRate copy (1.0 at 0x4E5EB6). The lifespan section calls the same object "BuildInfo". |
| Completion routine | FUN_006A1F82 | confirmed (the two copies); rest scoping | `void __thiscall(unit, bool notify)`, `ret 4`, 18 callers. Copies BuildingWorkRate (0x6A2089..0x6A2095: `[[unit+68h]+28h] = [[unit+5Ch]+D0h]`) and the LOS (0x6A20B2..0x6A2105, between a visibility remove and add); sets the percent to 1.0 and the full build points; never calls setLifespan. Runs when a building completes, when a `ForceBuildingData` unit is created, and on load for completed buildings (0x9C54B4..0x9C54D3: `[bd+8]` ≥ 1.0, then `call 6A1F82h` with 0). |
| setProto | FUN_004981F3 | confirmed | `void __thiscall(unit, Proto*)`, `ret 4` (0x498265). Writes `[unit+5Ch]` (0x498212), the visual and the building data (cold 0x6A031B..0x6A0386); not the LOS. 4 callers: 0x49828E (creation), 0x8D1BF0, 0x9C500D (load), 0x9C763F (transform). |
| BuildingWorkRate getter | 0x9BFE33..0x9BFE47 | confirmed, in game | `float __thiscall(unit)`: `[unit+68h] ? [[unit+68h]+28h] : [[unit+5Ch]+D0h]`; writes only EAX and the flags. Four direct callers, no other reference. |
| Getter callers | Train 0x9EA413 (FUN_009EA28B), Research 0x9E65F7 (FUN_009E648B), CommandResearch 0x9D58D4 (FUN_009D5843), Maintain 0x6AB23F (cold chunk of FUN_00492F3E) | confirmed (call bytes, vtable slots) | Each is `mov ecx,[esi+10h] / call 9BFE33h` and multiplies the result into its progress. They are slot 3Ch (update) of the action vtables 0xB98388, 0xB98078, 0xB973A8, 0xB97B98. |
| Save / load of `+28h` | 0x7AE73D (FUN_007AE672), 0x7AEEAD (FUN_007AEDDD) | confirmed (the two instructions) | Through 0xA3FEB8 / 0x599121, from the unit save and load. |
| Tech effect case BuildingWorkRate | FUN_008F973F case 5Eh at 0x8FAE7D; the remove twin FUN_008FB01C at 0x8FC16F | 0x8FAE7D confirmed | Computes the new `[playerProto+D0h]` through 0x7F892A and returns; no unit is touched. The Data effect vtable is 0xB9E5A8 (slot 1 parse 0x6205F6, slot 9 apply 0x7F86C0, slot 10 remove 0x7F8705). |
| Stat panel | 0x6F49B1 (`currentUnitBuildingWorkRate`) | read confirmed | Reads the selected unit's `[[unit+5Ch]+D0h]`. |

### Tech prerequisites (for `techPrereqRecheck`)

| What | Where | Status | Notes |
|---|---|---|---|
| Tech status update | FUN_00491A40 | confirmed | `thiscall(root = [world+7Ch])`, called only from 0x481D51 in the world update, gated by `[world+7Ch]` and byte `[game+B3Ah]` = 0. For each player slot 0..15 with a tree and a live player (`[player+338h]` = 0): 0x4919CE(tree, player), then 0x4918A8(tree, player). |
| Per-player tree update | FUN_004919CE | confirmed, in game | `thiscall(tree, Player*)`, `ret 4`; EDI = tree, EBP = player. DynamicCost loop, then the dirty test at 0x491A18 (`cmp byte [edi+10h],0 / jne 5096D4h`); epilogue 0x491A22. Callers 0x491A30 and the forced update 0x852882. |
| Re-check pass | 0x5096D4 (cold chunk of FUN_004919CE) | confirmed | Clears `[tree+10h]`, then 0x5095A1..0x509616 over all entries: a null one gets the relevance test 0x4C5725 and is created (0x94CC2B); a non-null one goes through `call 5094D8h` at 0x5095EC. |
| Per-tech update | FUN_005094D8 | confirmed | `thiscall(entry, Player*)`, `ret 4`. Cached result = status bit 3, OrPrereqs = bit 21; evaluates `0x5094B4([entry]+1Ch, player, or)` and writes bit 3. On 0 → 1, with no research time and bits 5 and 18 clear, it activates the tech (0x94CF27); a Volatile tech (bit 2) is toggled; the KB tech list is updated (0x509646). Only caller 0x5095EC. |
| Prerequisite list evaluator | FUN_005094B4 | confirmed, in game | `bool thiscall(list = def+1Ch, Player*, bool or)`, `ret 8`. `[list]` = array, byte `[list+4]` = length, null slots skipped; each through vtable slot +8. AND (empty = true) or OR (empty = false). Only caller 0x509537. |
| Prerequisite base / TypeCount | base ctor 0x6201AA; TypeCount ctor 0x8EE860, vtable 0xBA533C | confirmed | Byte `[p+5]` = type (TypeCount = 0), byte `[p+4]` = operator bits (lt 1, e 2, gt 4). TypeCount: `+8` unit type, `+0Ch` count, `+10h` unique, `+11h` state mask. |
| TypeCount evaluate | 0x8EE8E7 | confirmed | `bool thiscall(p, Player*)`, `ret 4`. Count = `0x4C846D([player+80h], [player], type, mask, 0)` (the backend of XS `kbUnitCount`), or 0x86ACA2 when unique. The KB `[player+80h]` is not null-checked. |
| TypeCount XML handler | 0xA14125 | scoping | Attributes `unit`, `count` (`%d`), `operator` (substrings lt / e / gt), `state` (starts FFh; `noneState` = 0; `buildingState` / `aliveState` / `deadState` OR 1 / 2 / 4), all required. |
| Tree | ctor 0x94D816, 20h B | confirmed (uses) | `+0` player ID, `+4` array of status entries, `+8` count (`[db+3828h]`), `+10h` dirty byte (1 at creation), `+11h` a second flag set only by the forced update FUN_00852850. |
| Status entry | `[[tree+4]+4·id]` | confirmed | `+0` definition, `+4` pointer to the status bits, `+8` bit count, `+18h` ResearchPoints. Bits: 0 obtainable, 1 active, 2 Volatile, 3 prerequisites met (cache), 5 set by activation, 7 DynamicCost, 18 HomeCity, 21 OrPrereqs. |
| Entry getter | FUN_004804D1 | confirmed | `thiscall(root, playerId, techId)`, `ret 8`: the player's entry, or the template record `[[db+5D9Ch]+0Ch] + 24h·id` when the entry is null. |
| Template records | `[[db+5D9Ch]+0Ch]`, count `[[db+5D9Ch]+10h]` | confirmed, in game | 24h B each, the same layout as an entry; record `+0` is the definition, whose prerequisites are at def+1Ch (byte length def+20h). |
| setDirty | 0x506A41 | confirmed | `thiscall(root, playerId, bool)`, `ret 8`. 10 direct callers (status changes 0x94C433 / 0x94CE86 / 0x94CFFC, age 0x8D506A, home city level 0x66923E, pop cap 0x8D1480, tree creation 0x8D005A, world start 0x8D53AF / 0x8D7F23 / 0x94AC00), all with 1. An inline copy in the pop cap adder FUN_00506A5F covers units with `PopulationCapAddition`. No other unit event sets the byte. |
| Tech name getter | 0x5C400B | confirmed | `thiscall(db, id)` over `[db+3824h]` / `[db+3828h]`. |

**Measured in game:** with 2 TypeCount techs, the checks took about 4 ms per game minute.

### Maintain (automatic production) (for `maintainWaitForPop`)

| What | Where | Status | Notes |
|---|---|---|---|
| Action type `Maintain` | 22h (name at 0x522CCC) | confirmed | Factory case 0x4EF4EC: `new(7Ch)`, ctor 0x9E2510, vtable 0xB97B98 (slot 34h setState 0x9E2829, 3Ch update 0x492F3E, 50h progress 0x9D504E). |
| Maintain fields | | confirmed (reads) | `+10h` owner, `+64h` proto ID to spawn, `+68h` units per cycle, `+6Ch` train points of a cycle, `+70h` points accumulated, `+74h` fraction; state byte `+61h` (14h working, 0Ch at the build limit, 0Ah done). |
| Maintain update | FUN_00492F3E, cold chunk 0x6AB0E4..0x6AB314 | confirmed, in game | Accumulates at 0x6AB23C..0x6AB261 (`0x9BFE33(building) × [world+310h] × [world+104h]`); fraction 0x9E27E4; ≥ 1.0 → spawn `call 9E2DEFh` at 0x6AB285, whose outcome is ignored (0x6AB28A..0x6AB2D8: SingleUse → setState(0Ah), else setState(14h)). "Not complete" exit 0x6AB180 (`pop ebx / jmp 493039h`). Both callers (0x4893A6, 0x494933) ignore its return value. |
| Cycle restart | setState(14h) entry 0x9E28AB | confirmed (reset 0x9E2A42..0x9E2A47) | Zeroes `+70h` and `+74h`, recomputes `+6Ch`. |
| Maintain spawn | FUN_009E2DEF | confirmed (site ranges) | `thiscall(action, protoId, count)`, `ret 8`; only caller 0x6AB285. Revolution remap 0x9E2E35..0x9E2E7D; group call 0x9E2EA0; AbstractMonk test 0x9E2EAD. Population test before each unit 0x9E2F79..0x9E2FE2 and 0x9E3110..0x9E3125: `pop = [proto+D8h]`; ≤ 0 or flag A3h → no test; flag 9Fh → `cap - used > 0`; else `cap ≥ used + pop`. |
| Group spawn | FUN_009E2AC8 | confirmed (0x9E2B69..0x9E2BD5) | The same test once, through 0x45EE02. |
| Population getters | 0x45805C (population), 0x4581A1 (cap; contains the `basePop` site) | confirmed | `int thiscall(player)`; `used = [player+78h] + 0x45805C(player)`. |
| Proto flag test | 0x45EE02 | confirmed | `bool thiscall(proto, int bit)` on `[proto+50h]` (count `[proto+54h]`). Flags 9Fh `AllowOverPopCap`, A3h `AlwaysAllowOverPopCap` (handlers scoping); 9Bh: show the stat panel's AutoGather rate row, cleared by `<Flag>DoNotShowAutoGatherRate</Flag>` (handler 0x6B0BA7, scoping; that it is set by default is inferred). Site `ProtoFlag` (`showGatherRate`). |
| Database proto IDs | `[db+5E08h]` TownCenter, `[db+5E1Ch]` Settler, `[db+6050h]` SettlerWagon, `[db+6054h]` Coureur, `[db+6058h]` CoureurCree, `[db+609Ch]` xpColonialMilitia | scoping | Cached by name through 0x5A2346. |

### Line of sight and transforms (for `transformUpdatesLOS`)

| What | Where | Status | Notes |
|---|---|---|---|
| Transform in place | FUN_009C754C | confirmed, in game | `thiscall(unit, int newProtoId)`, `ret 4`. EBP = `0x45311B([unit+44h], id)` (null → exit); visibility remove 0x9C7570; setProto 0x9C763F; per-player LOS cache 0x483DA5 at 0x9C768D; visibility add 0x9C7730. Never writes the unit's LOS. 8 callers: 0x6A42C8, 0x7FBC79 (`TransformUnit`), 0x7FBEF2 and 0x8F05F5 (revolution), 0x8C2D08, 0x8EB78A, 0x9BB6D5, 0x9C7C16. The trigger effect "Change Unit Type" does not reach it (in game). |
| setLOS | FUN_00484518 | confirmed | `thiscall(unit, float los, bool updateVisibility, bool force)`, `ret 0Ch`. Writes the base LOS at 0x484553 between a visibility remove and add. 12 callers, among them creation 0x49833D, the Knockout action (6.0), the foundation 0x6A40F3 and the LOS tech 0xA009B0. |
| LOS getter | FUN_0048206D | confirmed | `[world+5ACh]` × (`[[unit+B4h]+C8h]` ? its `+1Ch` : 1.0) × `[[unit+B4h]+90h]`. |
| Visibility add / remove | FUN_00483262 | partly confirmed | `thiscall(unit, bool add, bool force)`, `ret 8` (scoping); calls the getter (0x4832E7, 0x483347), so the radius follows the current LOS. |
| `TransformUnit` effect apply | 0x7FBBAF (vtable 0xB96B60, slot 3Ch) | confirmed (0x7FBC32..0x7FBC8A) | For each of the player's units of `fromprotoid` that is alive and built, `0x9C754C(toprotoid)` at 0x7FBC79. |
| Owner change | 0x514529 in 0x514358 (from FUN_004E3334) | confirmed | Writes `[unit+5Ch]` with the new owner's copy of the same proto; does not touch the LOS. |
| Fields | `[unit+B4h]+90h` base LOS (float); `[proto+48h]` `<LOS>` | confirmed, in game | |

### Broadside attacks (for `broadsideMuzzleLimit`)

| What | Where | Status | Notes |
|---|---|---|---|
| `BroadsideAttack` protoaction | type 29h (name 0xBD7AB4 at 0x522DD7) | confirmed | Factory case 0x4EF566: `new(98h)`, ctor 0x9D2B23, vtable 0xB962E8 (slot 1 set-up 0x50339A). |
| Broadside set-up | FUN_0050339A | confirmed, in game | `thiscall(arg)`, `ret 4`; EDI = the action. Only for an owner whose proto has abstract bit 1 (`Ship`, 0x44CAC4). The limit `mov esi,6` at 0x5033D5, kept at `[esp+0Ch]`; `SingleUsePlayer` (flag bit 26 of the proto action, tested at 0x5033E0) → cold block 0x6A8236, limit 1. Clamps 0x503447 (MuzzleR, cold 0x6A8247) and 0x5034E2 (MuzzleL, cold 0x6A8252). `[edi+80h]` = MuzzleR slots. |
| Broadside fields | `+68h/+6Ch` muzzle index array; `+74h/+78h` fire time array; `+80h` MuzzleR slots; `+84h` ROF in ms | confirmed | BArray<int>, appended through 0x401113. |
| Attach points of a type | 0x484304 | confirmed (head) | `int thiscall(visual = [unit+60h], int attachType)`; −1 without a model, 0 for an absent type. MuzzleR / MuzzleL type IDs at 0xD6F6AC / 0xD6F6B4 (looked up by name at load). |
| Volley schedule | FUN_004CEE48 | confirmed (head); loop scoping | For each MuzzleR slot, t += sync RNG(0.25·ROF, 1.75·ROF); slot i and slot i + n1 get the same t. |
| Fire step | FUN_004C1290 | confirmed (call at 0x4CEA43) | Side from the target's direction; per due slot, the muzzle position (the index read as a byte at 0x4A98F8, which caps N at 255) and **one** projectile, `call 499422h`. Tekkousen in game: 10 slots per side, all fired. |
| Save / load | 0x9D2BAC / 0x9D2D87 | scoping | Each array with its count, resized on load; no maximum. |

### Abilities, the command panel and the wonder power panel (for `abilitySlots` and `wonderPanelSkipAuras`)

| What | Where | Status | Notes |
|---|---|---|---|
| Ability manager | `[world+56Ch]` | confirmed | Built by 0x9FF9A1 (from 0xA06788 with `L"abilities.xml"`); read by the wonder panel (0x45873E; the panel is skipped while it is 0), the command panel (0x696BFE) and the `ability` UI command (0x7DDCA0). Records `[mgr+0]`, count `[mgr+4]`. |
| abilities.xml loader | FUN_006EDF6A | scoping | `thiscall(mgr, name, dir)`, `ret 8`. One element per proto, one `<Ability>` per record (text = power name); a child that is not `<Ability>` fails the whole load. |
| Ability record | 20h B | partly confirmed | `+0` index, `+4` proto ID, `+8` power ID, `+0Ch` tech, `+10h` age (compared with `[player+50h]`), `+14h` ROF ms, `+1Ch` flags: 2 UseBigButton, 4 NeverShowInGrid, 10h CastOnSelf, 100h AlwaysDisabledInGrid (byte `+1Dh` bit 0, set at 0x6EE32E). 153 records in stock TAD (scoping). |
| GetNth visible ability | 0x6EE5CC | confirmed, in game | `bool __thiscall(mgr, int n, player, unit, cost*, icon*, rollover*, bool* usable, int* recIdx, int* powerId)`, `ret 24h`. Resets every output at entry (0x6EE623..0x6EE64C), then counts the records of the unit's proto without flag 4; at the n-th: false if its tech is inactive (0x94AF27) or its age differs; true with `*recIdx` and `*powerId` (0x6EEEBA), `*usable` forced to 0 for flag 100h. Past the list: false. Keeps EBX, ESI, EDI, EBP. Callers: 0x696C59 (command panel) and 0x69EE5D (wonder panel, n = 0 only). |
| Record by index | 0x44E702 | confirmed | `rec* __thiscall(mgr, int index)`, `ret 4`; 0 out of range. |
| Command panel refresh | FUN_0046188E (`commandpanel2`) | scoping, key ranges confirmed | Collects the proto's `<Command>` entries into the global array 0xCF05FC (`{ptr, count, capacity}`, grows by doubling), sorts them by column, then lays them out in the 6 × 6 grid (columns wrap at 6, 0x46266B; rows stop at 6, 0x6972C6). |
| Page-11 copy loop | 0x695BB6..0x695C02 | confirmed, in game | Entered only from 0x4C5AF6 (after `cmp byte [eax+esi+3],0Bh` at 0x4C5AEB). `mov edi,5` at 0x695BD2, do-while `sub edi,1 / je 461C3Fh`: 6 ability entries per `Abilities` command. |
| Ability counter | `[esp+34h]` in FUN_0046188E | confirmed | 0 once per refresh (0x461CD5); `n = [esp+34h]++` at 0x696C0B..0x696C1F; GetNth at 0x696C59, with the outputs at `[esp+0Ch]` (usable), `[esp+2Ch]` (record), `[esp+78h]` (power); true path 0x696C70 `call 45EE37h`. The button's command is `ability(record, unitId)` (0x696D87..0x696D9B). |
| Wonder power panel refresh | FUN_004586B1, cold chunk 0x69EC5E..0x69F35E | partly confirmed, in game | For the local player's `AbstractWonder` units and each page-11 command (type 2): GetNth with n = 0 at 0x69EE5D (`push 0` at 0x69EE5B), then `test al,al / je 69F31Bh`, the record re-check `0x44E702` and `test byte [eax+1Dh],1 / jne 69F31Bh`; a button with `ability(recIdx, unitId, true)`. Gadget `uiwonderpowerpanel` (ctor 0x9BCE92, five buttons; scoping). |
| `ability` UI command | 0x7DDC52 | partly confirmed | `ability(int record, int unitId, bool doWhenNotSelected)`: the record by index through 0x44E702 (0x7DDCCC); no slot limit. |
| Proto command entries | `[proto+E8h]`, 6-byte records | scoping | `{word id, byte kind (0 Train, 1 Tech, 2 Command), byte page, byte column}`, appended by 0x5F5F05, which skips its duplicate check for page 11. |

### Lifespan and construction (for `lifespanAfterConstruction`)

| What | Where | Status | Notes |
|---|---|---|---|
| Lifespan tick | FUN_00482BF6 | confirmed, in game | `void __thiscall(unit, float dt)`, `ret 4`. Hot part returns (0x482C20 `pop esi / pop ecx / ret 4`) unless `[game+B3Ah]` = 0 and state bit 3 is set; cold part 0x483EEC: dt ≤ 0 returns; less than dt left → expiry 0x4CBABC (state bit 11 set: only removes the corpse; else zeroes the countdown, clears bit 3 and queues the kill 0x4B4DC2); else `[sub+1Ch] -= dt`. Callers 0x483104 (full unit update), 0x51169E (light update). |
| Fade update | FUN_004829FA | confirmed | `float __thiscall(unit, float dt, bool commit)`, `ret 8`. `t = [sub+88h] − dt` into `[esp+10h]`, stored at 0x482A20 when commit; then bit 61 → 0x4E5F88, bit 4 (fade-in) → 0x6A1CE1, bit 5 → 0x4A174A, which returns while t > 0 and, when the alpha reaches 0, calls setLifespan(2e-6) (0x4CBB2E). (`docs/performance.md` calls this function "movement"; that label is wrong.) |
| setLifespan | FUN_0048DCB9 | confirmed | `void __thiscall(unit, float seconds, bool alphaFade)`, `ret 8`. `[sub+1Ch]` = seconds; > 0 → state bit 3 (`fcomp [0B84BE4h] / test ah,41h`, then `or byte ptr [[esi+4]],8` at 0x48DCDE; site `SetLifespanArm`); alphaFade → fade-out scheduled through 0x47B50C. Callers include unit init 0x498372 (with `[proto+ACh]` and flag `AlphaFadeLifespan`), the fade end 0x4CBB2E and the Lifespan tech effect 0xA005D9. `startingTC` reads bit 3 as "lifespan pending". |
| Schedule a fade-out | FUN_0047B50C | confirmed (body) | `__thiscall(unit, float duration, float delay)`: `[sub+84h]`, `[sub+88h]`, state bit 5 set, bit 61 cleared. Also used by the Death actions for the corpse fade. |
| Is built | FUN_0044DDB4 | confirmed, in game | `bool __thiscall(unit)`: `[unit+68h] == 0` or `[[unit+68h]+8] >= 1.0`. Changes EAX only; false exit 0x69F904. Earlier tables called it "alive"; it is "fully built". |
| Kill handler | FUN_004B4F70 | confirmed | Returns at once if state bit 11 is set; otherwise sets bit 11 (0x4B51F9) and clears bit 8 (0x4B520E). |
| Unit sub-object | `[unit+B4h]` | confirmed (as read above) | `+1Ch` lifespan left, `+84h` fade duration, `+88h` time before the fade, `+8Ch` alpha, `+90h` base LOS, `+94h` the resource inventory ("Resource inventories"), `+C8h` the modifier record (created with a unit's first stat modifier: `+4` max HP override, `+1Ch` LOS factor, `+24h` GatherRate, `+28h` AutoGatherRate, `+44h` army ID; the velocity too). State bits of `[unit+4]` used: 3 lifespan armed, 4 fade-in, 5 fade-out, 8 in the world, 11 dying, 12 not alive, 61 another fade. |
| `<Lifespan>` | `[proto+ACh]` (handler 0x5FCF4B) | confirmed (already in "Damage and poison") | Default 0. |

### Sockets and placement (for `gaiaSocketsOnly`)

| What | Where | Status | Notes |
|---|---|---|---|
| PLACE (placement check) | FUN_0050703D; slot `+14h` of the World vtables 0xB95E08 / 0xB9FB88 | confirmed (prologue, frame uses) | `bool __thiscall(world, protoId, player, pos*, …, a5 knowledge, a6 flags, a7 int* reason, …)`, `ret 2Ch`. In the body a1 (player) is at `[esp+1C0h]`, a5 at `[esp+1D0h]`. Callers: the build command (0x7D7EC7, a5 = 1, every machine), uiBuildAtPointer (0x7E6E9B, a5 = 1), the AI's checkPlacement (0x73D7E3), the in-place conversion command (0x7D65E0, a5 = 0). |
| Socket test in PLACE | 0x508C14..0x508CC6 | confirmed | A building already on the socket refuses; a unit that is not a matching socket (0x466C31) is ignored; a matching socket counts only when its xz distance² is below 1e-12; 0x508CC1 stores "socket found" `[esp+37h]`; ESI = unit + 14h, EDI = the building's proto. No read of `[unit+44h]`. |
| No socket found | 0x509215 | confirmed | `cmp byte [esp+37h],0 / jne … / mov byte [esp+13h],0`. |
| Matching socket | 0x466C31 | confirmed (entry) | `bool __thiscall(buildingProto, int protoId)`: is-a of the proto against `[buildingProto+12Ch]` (`<SocketUnitType>`, stored at 0x5FCC8E). |
| Snap to socket | FUN_00A036BB (callers 0x96E7A3 cursor ghost, 0x87DB30 AI) | confirmed (0xA0383B..0xA03855) | The only owner test on the placement paths: `mov edx,[esi+44h] / cmp dword [edx],0 / jne`. A socket a player owns is never snapped to; the ghost stays red. |
| ForceToGaia | flag 42, applied at unit creation (0x498865 → 0x506B0F) | scoping | Every stock socket has it except `ypTradingPostCapture` and `AIStart`. |

### Hotkey contexts (for `customHotkeyContexts`)

| What | Where | Status | Notes |
|---|---|---|---|
| Context manager | `[[[0xC66244]+74h]+34h]` | confirmed, in game | Built by FUN_0055BB99. `+18h` active set (255 bits), `+24h` saved sets, `+28h` their count, `+30h` name table: names `[+30h]`, count `[+34h]` = the next ID, `{id, layer}` records `[+3Ch]`. |
| Register a context | 0x628FC0 | confirmed, in game | `int __thiscall(manager, const char* name, int layer)`, `ret 8`; ID = `[manager+34h]`; 0 = registered, 2 = the name exists or is null. |
| Find a context by name | 0x5C16AB | confirmed, in game | `int __thiscall(manager, const BString* name, {int id, int layer}* out)`, `ret 8`; 0 found, 3 unknown. Callers 0x5C168A, 0x5C1778 (keymap), 0x79F9A9, 0xAB4087. |
| The stock contexts | FUN_005D7948 | scoping; count in game | 123 names; the 35 unit contexts `TownCenterAccel` … `WonderAccel` at layer 5, `BuildAccel` at layer 6. In game, `ypCaravanserai`'s stock context had ID 72 (`StableAccel`), and the first context the DLL added got ID 151: the game had registered 151 contexts before the keymap. |
| Apply the keymap | FUN_005BF3B8 → FUN_005C16EA | confirmed, in game | Per entry: `call 5C16ABh` at 0x5C1778, then `cmp eax,3 / je` drops the entry. A loose `data\DefaultKeyMapY.xml` replaced the archive copy (in game). |
| Proto → context table | FUN_005C13C5 | confirmed (writes) | Writes `[proto+178h]` at data load: about 40 protos by cached ID, AbstractShrine, AbstractWonder, else −1. |
| Turn the unit's context on | FUN_0079F851 | confirmed | `stdcall(bool on, Unit*)`, `ret 8`; ESI = the database proto; `mov edi,[esi+178h]` at 0x79F897; `jge 79F9BFh` → 0xAB3EE3(manager, edi, 0). Only caller 0x64A095. |
| Switch the unit contexts off | FUN_0079EF9C | confirmed | 35 × `0x4421F3(manager, name, 0)`, the last (`WonderAccel`) at 0x79F1A5. By ID: 0xAB397F; on by ID: 0xAB3EE3 (all `thiscall(manager, name or id, bool)`, `ret 8`). |
| Selection qualification | chunk 0x649FA4 (0x64A016..0x64A05C) | confirmed, in game | Local player's units only. A `<Train>` list and Building → BL = 1 (enters a context); a `<Train>` list and not Building → `mov byte [esp+13h],1` (BuildAccel) at 0x64A034; no `<Train>`: AbstractFirePit or the unit flag `EnterHotkeyContext` (0x44D063(unit, 0A1h)) → BL = 1. Any other unit enters no context. |
| Binding context set | ctor 0x5BC7D3; bit set at 0x5BC9AB | confirmed | 255 bits, set with no bounds check: context IDs must stay below 255. |

### Snare and group movement (for `snareOnlyHitUnit`)

| What | Where | Status | Notes |
|---|---|---|---|
| Snare trigger | FUN_0048FA07 → cold chunk 0x4DD1DE | confirmed | Tactics action flag bit 11 (`<SpeedBoost>`) → 0x4B3E31; bit 12 (`<TargetSpeedBoost>`) → `0x4DD22D(target, 0, 0.65f, -1f, -1f, 0, 2, 3000, -1, -1, 1)` when the target can move. |
| Apply / create a modifier | 0x4DD22D → 0x4B3D9E; init 0x4B3D44 | confirmed, in game | `int __thiscall(unit, stat, float value, -1f, -1f, 0, operation, int ms, -1, -1, exclusive)`, `ret 28h`; −1 without an action manager `[unit+58h]` (0x69FDBD); allocates the modifier record `[[unit+B4h]+C8h]` when missing (0x4AAC67). `damageOverTime`'s `AttachSnare` calls it with the data's factor (site `SnareApply`; a Hussar read 3.38 = 6.75 × 0.5 through slot 34h). Unit action type 2Ch: `[+64h]` stat (0 = velocity), `[+68h]` value, `[+78h]` operation (0 set, 1 add, 2 multiply), `[+88h]` ms; flag 15h when timed, 14h when not; flag 16h = exclusive. Only the snare is both timed and exclusive (`<SpeedBoost>` is timed, not exclusive; the auras pass 0 ms). Auras (FUN_009D033E), powers (0x8EE18E) and a second applier (0x9D7696) use the same call (scoping; "Building work rate auras"). |
| Action lists | `[actionManager+14h]`, `{count +0, data +8}`; children at `[action+40h]`; type byte `[+60h]`; flag bitset `{[+30h] bytes, [+34h] count}` | confirmed | Walked depth first, parent first, by the collector 0x49F1A0 / 0x49F397 / 0x49F34B. `src/modifiers.h` repeats that walk, read-only, for `snareOnlyHitUnit` and `buildingWorkRateAuras`. |
| Velocity modifier sum | 0x4B3C48 / 0x4B3C7D (cold 0x4E2A8E, 0x6A88D6) | confirmed | Starts from MaxVelocity `[proto+80h]`; applies each stat-0 modifier in order, rounded by `fstp`; stops after the first with flag 16h or whose tactics action has `<ModifyExclusive>` (bit 33). Stored in the record `[[unit+B4h]+C8h]` only if a modifier matched. The sum itself, 0x4B3C7D, serves every stat: `bool thiscall(unused ECX, float* v, {data +0, count +4}* list, int stat)`, `ret 0Ch`, true when a modifier of `stat` matched; no null check of the entries. |
| Unit max velocity | 0x487E27 (unit vtable slot 34h; cold 0x488612) | confirmed, in game | The record when it is above −1e-6, else MaxVelocity; times the cfg float `MovementMod` (0x44734C on 0xC66500 with the ID at `[[0xCEFFA0]]`; 1.0 when unset). |
| Group recompute | FUN_004FD289 | confirmed, in game | `[group+7Ch]` (pace) = the minimum of the members' `vtbl[34h]()` (0x4FD3FD..0x4FD411, store 0x4FD53A). Members `[group+98h]`, count `[group+9Ch]`. Triggered by group bit 13, set by 0x49F3D0 when a member's velocity changes. |
| Group speed | 0x4FAA5D | confirmed | Target speed = `[group+88h]` × pace; × 0.8333 when bit 7 ("a member is behind") is set (0x4FAAA5). |
| Straggler bit | 0x4FA17D (member step FUN_004FA03B), 0x6AA514 and 0x6AA56A (own-path branch of the member loop FUN_004F9E05) | confirmed, in game | Set when a member is more than 2.0 from its formation slot (0x4F9B69, scoping for the value). The member loop clears bit 7 first and looks units up by ID inline (0x4F9EB7). |
| Member speed | 0x4F9BCB | confirmed | `min(v·[group+88h], max(v, [group+84h]))`: a member never walks faster than its own velocity v. |

### Tech tree and tech effects (for `techRenameEffect`)

| What | Where | Status | Notes |
|---|---|---|---|
| Database tech tree TT0 | `[db+5D9Ch]` | confirmed, in game | `[TT0+0]` NodeData array (34h each), `[TT0+0Ch]` base node array (24h each); per tech set up at 0x6201E5 (`[base+0]` = NodeData). |
| BTechTreeNodeData | ctor 0x6236BE, 34h B | confirmed, in game | `+0` tech ID, `+4` DBID, `+8` DisplayNameID, `+0Ch` RolloverTextID, `+10h` LongRolloverTextID, `+14h` icon, `+1Ch` prerequisites, `+24h`/`+28h` effects. In game, Hunting Dogs read 23401 / 23400 here. |
| Player's tech node | 0x8D0005 (BPlayer::getLocalTechNode) | confirmed, in game | `BTechTreeNode* __thiscall(player, techId)`, `ret 4`; 0 without a tech manager. Creates the node on first use (0x94D88A → 0x94CC2B: `new(24h)`, a copy of the base node, so `[node+0]` is the shared NodeData). |
| Effect type names | `[db+335Ch]`, count `[db+3360h]` | confirmed, in game | Registered in FUN_0052277E (0x524A2E..0x524CB0): SetName 0, Sound 1, TextOutput 2, TextOutputAll 3, SetAge 4, TechStatus 5, Data 6, SharedLOS 7, Blockade 8, ShowHCView 9, ShowWorldView 10, ModifyProtoUnit 11, InitiateRevolution 12, TransformUnit 13, ResourceExchange 14, SetOnBuildingDeathTech 15, Data2 16. `SetTechName` became 17 in game. Add a name: 0x5375AC (`thiscall(table, name, const int* id)`, `ret 8`); by name: 0x61FF1B (`thiscall(db, name)`, −1 if absent). |
| Effect parse and factory | 0x620572; factory FUN_00620535 | confirmed | The parse looks the type up (−1: error 512h, dropped), calls the factory (`BEffect* cdecl(uchar)`, 0..10h through the jump table 0x621490, anything above to 0x62146F: error 51Fh, 0), then setData `[vtbl+4]`; false deletes the effect with no message (0x621ECA). |
| BEffect | ctor 0x620B8F; vtable 0xB965C0 (17 slots) | confirmed | `+4` = −1, `+8` type, `+9` = 28h (kind 8, "general", plus flag 20h, re-applied after a saved game loads). Slots: 0 dtor, 1 setData, 2 save, 3 load, 4 copyFrom, 15 generalApply (`ret 10h`), 16 generalUnapply (no-op). Stock SetName: vtable 0xB969F8. |
| Effect apply dispatcher | 0x7F7E97 | confirmed | Kind 8 calls `[vtbl+3Ch](player, sourceTech, unit, flags)` at 0x7F8111. Callers 0x94DBE6 (applyEffects: research, triggers, shipments; the whole team for a team tech) and 0x94DF10 (the post-load pass, effects with flag 20h). |
| Research message gate | 0x94D148 | confirmed | No "researched" message for a negative DisplayNameID. |
| Engine new / free | 0x401398 / 0x401548 | confirmed | `cdecl(size)` / `cdecl(void*)`. |
| XML attribute | 0x598F37 | confirmed | `bool __thiscall(node, const char* name, void** value)`, `ret 8`; `*value`'s first field is the UTF-16 text. |
| Help dialog | 0x70D128..0x70D13F | confirmed | Reads the base node: shows the database texts. |
| WoL SetTechName | WoL `uhc.dll` 0x100369C0 | scoping | Writes `[[node]+8]`, `[[node]+0Ch]`: the shared NodeData. |

### Dopples (for `noCorpseDopples`)

| What | Where | Status | Notes |
|---|---|---|---|
| Unit visibility update | FUN_0048679A | confirmed | `void __thiscall(unit, int forced)`, `ret 4`. Per player: EBX = index, EBP = `1 << EBX`, EDI = the player. |
| Loss branch | 0x49520B..0x49536C | confirmed, in game | The unit left player EBX's view. A dopple only if proto flag `Doppled` (2Eh, test at 0x49522B), state bit 8 (0x495276), not state bit 1Dh (0x4952BC), and for `DoppleOnlyWhenDead` (55h) a Gaia owner (0x4F1088 → `je 49534Dh`). Then `mov eax,[esp+2Ch] / mov ecx,[esp+54h] / call 4DB3D0h` (0x495367) / `jmp 486A30h`. No alive test. |
| Next-player exit | 0x486A30 | confirmed | EAX/ECX/EDX written before they are read. |
| Create dopples | 0x4DB3D0 | confirmed (entry) | `bool __thiscall(world, player, unitID, forced, mask)`, `ret 10h`; nothing for player 0 or without the manager `[world+330h]`; else 0x4E4899 for each player that shares the losing player's vision. |
| Dopple init | 0x4E46B5 | scoping | Stores the unit ID, proto ID, owner and HP ratio; a unit that is not alive takes the hold-pose path (death pose, inferred). Draws RNG stream 1 (0x4CFEA3). |
| Dopple removal | gain branch 0x5036C4 → 0x503685; manager update 0x491961 | confirmed (call site, entry); update scoping | When the unit is seen again, or when the player sees the dopple's spot again. destroyUnit 0x4726B2 leaves the dopples alone. |
| Deferred kill clears bit 8 | 0x4B520E | confirmed | A depleted carcass leaves the world before it decays, so it is never doppled. |
| Proto flag `Doppled` | bit 2Eh of `[proto+50h]` (set at 0x5F81DD) | confirmed, in game | Also (scoping): `DoppleOnlyWhenDead` 55h, `MutateDopples` 72h, `VisibleUnderFogOnlyAfterSeen` 79h. |
| `Huntable` | built-in abstract type (0x51B256 in FUN_0051A5DC) | confirmed | Usable as the marker with no data change. |

### Dances (for `danceBonusCivs`)

| What | Where | Status | Notes |
|---|---|---|---|
| Dance readers | Training FUN_008D4790 (`float thiscall(player, protoId)`, `ret 4`; caller 0x9EA4A2); XPTrickle FUN_004E0DE5 (callers 0x4E0DD7 and the dance tooltips 0x9D6D98, 0x9D793F); Gathering FUN_004ECD39 (caller 0x4ED02A); Regeneration FUN_00490476 (`this` in EDI; caller 0x490A59) | confirmed (bytes); callers scoping; Regeneration in game | Each: EAX = `[[player+20h]]` (or −1 through a separate path, 0x8D47A1 / 0x679D6A / 0x679DE4 / 0x679E5E), four compares with 0xC6FB50..0xC6FB5C (gates 0x8D47AB, 0x4E0DFF, 0x4ECD53, 0x49048B), native branch 0x8D47CF / 0x4E0E29 / 0x4ECD7D / 0x679E66. |
| getFirePit | 0x4819EF | confirmed | `unit* __thiscall(player)`: the player's first unit of `AbstractFirePit` (protoCount + 52h), else 0. |
| DanceBonus kind | byte `[action+0C1h]` | values 1/2/5/8 confirmed | Training 1, XPTrickle 2, UnitModification 3, UnitSpawn 4, Regeneration 5, PopCap 6, WarChiefRansom 7, Gathering 8 (enum scoping). DanceBonus is protoaction type 45h. |
| Dance strength | 0x9D665C | scoping | exp^n + mult·n − 1 + base, n = dancers on the `AbstractFirePit` building (a villager counts 1, any other unit 2). |
| Regeneration | 0x679EC6.. | confirmed (bytes) | Heals each unit of the action's type that has been idle ≥ 3.5 s (or is knocked out, bypass at 0x679FBA) by value × `[world+104h]` × max HP × 0.01. In game: a listed civ's damaged musketeers healed to 150 HP; without the key they stayed at 90. |

### Starting town center (for `startingTC`)

| What | Where | Status | Notes |
|---|---|---|---|
| FirstTC | `[player+4F0h]` | confirmed, in game | The unit ID of the player's first Town Center, -1 until set. Written during a game only by addUnit's store (0x67ABD4); ctor -1 (0x8DCC1D), init 0x8DA5C0, save/load 0x8D4088 (scoping; a scan of every `[reg+4F0h]` operand). Never cleared when the unit dies. In game, `startingTC` made it 3 (a marked Market) for a player without a Town Center. |
| Player::addUnit | FUN_0049874F | confirmed | `bool __thiscall(player, unit*, bool)`, `ret 8`; ESI = player, EDI = unit. Returns early (0x67ABBF) when the ID is already in `[player+F8h]` (count `[+FCh]`). Callers 0x498980 (`test al,al`), 0x51453E (conversion; result ignored), 0x9C7658 (transform; ignored). |
| FirstTC gate | 0x49880A | confirmed | `cmp dword ptr [esi+4F0h],0 / jl 506B2Ah`, then the exit 0x498817 (`pop ebx/ebp/edi`, `mov al,1`, `pop esi`, `ret 8`). Site `FirstTcGate`. |
| FirstTC proto test | 0x506B2A..0x506B4B | confirmed | `eax = [[edi+5Ch]+4]`, `ecx = [game+140h]` (database), `cmp eax,[ecx+5E08h] / jne 498817h / jmp 67ABD4h`. Only entry: the `jl` at 0x498811. Sites `FirstTcChunk`, `FirstTcProtoCheck`. |
| FirstTC store | 0x67ABD4 | confirmed | `mov ecx,[edi+10h] / mov [esi+4F0h],ecx / jmp 498817h`; only reached from 0x506B47. Site `FirstTcSet`. |
| `distanceatmostfromtype` evaluator | FUN_008CE515 (vtable 0xBA537C, slot 0xBA5380), `ret 2Ch` | confirmed (head and FirstTC lookup 0x8CE515..0x8CE5E3); rest scoping | Rule type -2 at `[rule+14h]` = FirstTC (0x8CE558). Players 1 .. `[world+5Ch]`-1 (0x44CB21). `[p+4F0h]` = -1 → 0x8CE609 ("satisfied" for the whole rule, scoping). Else the raw lookup `[world+0Ch][id & 3FFFFh]`, `[unit+10h]` = id, no alive test (site `FirstTcRuleLookup`), and the distance `[vtbl+B8h](pos)` at 0x8CE5D5 compared with `[rule+10h]`. noRushOnly byte `[rule+1Ch]`. |
| `distanceatleastfromtype` evaluator | FUN_008CE935 (slot 0xBA53A0) | confirmed (0x8CE9BE..0x8CEA26, 0x8CEB45..0x8CEB7C) | `FirstTC`: players 1 .. `[world+5Ch]`-1 through 0x44CB21; skips -1; the unit table lookup with no alive test; `[tc vtbl+B8h](point)` below the rule distance (plus the placed building's size); filter `[rule+18h]` on the owner `[tc+44h]`: 1 self (`[owner] == id`), 2 ally 0x4707EC, 3 enemy 0x484D2D. Sites `FirstTcRuleLoop`, `FirstTcRuleFilter` (`noTrainNearEnemyTC` mirrors them). A unit type instead of FirstTC: 0x8CEA69 calls 0x4A1C55(point, radius, 1, list) ("Units near a point" below) and filters the IDs by type (0x44D7FA), the same stance and `[rule+1Ch]` (0 position equal, 1 0x4883DD, 2 0x44DDB4 built); with `[rule+20h]` the radii are subtracted too (site `TypeRuleQuery`; `noTrainNearEnemyTC near` uses the query). |
| FirstTC keyword parse | FUN_005FDE94 / FUN_005FDFEA (vtables 0xBA5384 / 0xBA53A4), string 0xBCAE7C | scoping | `FirstTC` → `[rule+14h] = -2`. Stock rules: `distanceatleastfromtype player=enemy 65 FirstTC` and `distanceatmostfromtype player=team 75 norushonly FirstTC`. |
| Bitset test | 0x44D863 | confirmed | `bool __thiscall(bitset, int bit)`, `ret 4`; bits at `[this+4]`, count `[this+8]`. With ECX = a unit it tests a unit state bit; `startingTC` reads bit 3 (lifespan armed) the same way, inline. |
| Lifespan Data effect | FUN_008F973F (ProtoUnit Data effect apply, subtype switch 0x8F979D), case 0x8FA939 | confirmed (bytes) | Writes the proto's `[proto+ACh]` through 0x7F892A, then, when a main world exists, FUN_00A00505(world, playerID, protoID): a query of the player's units of that proto, each through setLifespan(`[proto+ACh]`, AlphaFadeLifespan bit 1Fh). So a Lifespan tech reaches live units at once (WoL's `Age0Maori`). |
| FreeHomeCityUnit | FUN_008D842B → 0x8D8FBC → FUN_00857E77 | scoping | Resolves the drop point with FUN_004C6B9E (TownCenter first) and creates the unit in the same call; nothing without a drop point (0x857F3F). |

### Civ first town center (for `civFirstTC`)

The ranges the feature relies on are the `civFirstTC` sites of `tools/gen_sites.py`, whose
comments hold the disassembly they were read from; FirstTC itself is in "Starting town center"
above, Player by ID and Unit by ID in "Home city gather point". "In game" means the single-player
tests of 2026-10-29 ([modding-guide.md](modding-guide.md#civfirsttc)).

| What | Where | Status | Notes |
|---|---|---|---|
| civs.xml parser | FUN_0052A590 | confirmed (the `<civ>` child loop around 0x52BAFA..0x52BB19 and 0x52B43D), in game | ESI = the child node, EBX = database, `[esp+10h]` = the civ being read. Each child tag is compared with the known names through 0x443C10; the last compare is `call 443C10h / test eax,eax / je 65A549h` at 0x52BAFA. A tag that matches none reaches 0x52BB07 (`xor edi,edi / cmp [ebx+80h],edi`), then `jle 52B43Dh / jmp 52C066h` (the resource names, then a silent skip), so stock ignores an unknown tag such as `<firstTC>`. Every handled tag continues at 0x52B43D (`mov eax,[esp+80h] / mov ebp,[esp+0B0h] / add eax,1 / cmp eax,[ebp+0Ch]`, the next child; reads only the stack). Sites `CivTagUnknown`, `CivTagNextNode`. In game, `<firstTC>` was read and logged. |
| XML node | the node in ESI | confirmed (the parser's compare chain), in game | Element name `[[node+4]+18h][[node+18h]]` (wide; the name table's count is `[[node+4]+1Ch]`), text `[node+14h]` (wide). |
| Civ object | `[civ+4]` name (`char*`), `[civ+8]` civ ID | confirmed, in game | The civ ID is the index in `[db+24h]` (see 0x58E71F). |
| Civ by ID | 0x405C2E | confirmed | `Civ* __thiscall(database, int id)`, `ret 4`: `[[db+24h]+4·id]` for 0 ≤ id < `[db+28h]`, else 0. Site `CivById`. |
| Player's civ ID | 0x4539D3 | confirmed | `int __thiscall(player)`: `[[player+20h]]` when `[player+24h]` > 0, else −1 (cold path). Site `CivOfPlayer`. |
| Proto by name / by ID | 0x5A2346 / 0x45316E | confirmed | 0x5A2346 (Functions table) scans `[db+54h]` (count `[db+58h]`) comparing `[proto+10h]` without case; −1 if none. 0x45316E: `Proto* __thiscall(database, int id)` = `[[db+54h]+4·id]`, `ret 4`. Sites `ProtoByName`, `ProtoById`. |
| RM placement step | FUN_00925F11 | confirmed (0x925F45..0x925F52) | Reached by every `rmPlaceObjectDef*`. `mov eax,[edi] / push ecx / mov ecx,[eax+esi*4]` (the object def) `/ push edx / call 925936h / mov ebx,eax`: the only call of objectDef::place, at 0x925F4C. Site `RmPlaceCall`. |
| objectDef::place | FUN_00925936 | confirmed (head 0x925936..0x9259A4), in game | `int __thiscall(def, int player, float x, float z, int count)`, `ret 10h`. Reads the world's terrain `[world+88h]` and the RM `[game+92Ch]` (none: an error string and 0). At 0x925988, `cmp byte [esi+55h],0`: a `Special_StartingUnits` def (`rmCreateStartingUnitsObjectDef`) rebuilds its items from the civ's `<startingunit>` list inside the call. Site `RmPlace`. |
| Object def | `[def+0]` ID, `[def+4]` name (`char*`), `[def+8]` items, `[def+0Ch]` item count, byte `[def+55h]` Special_StartingUnits | confirmed (+8, +0Ch, +55h); in game (+0, +4 in the log) | Items are 20 B: `+0` proto ID, `+0Ch` / `+10h` footprint (x, z); `+4` the count and `+8` the cluster distance of `rmAddObjectDefItem` (inferred from its arguments). In game, Mongolia's def named `startingTC` held the `TownCenter` item. |
| objectDef::addItem footprint | 0x924B1D | confirmed | When the proto has flag 2 (0x45EE02): `(int)([proto+88h] × [[world+88h]+1Ch] × 2 + 0.5)`, and the same with `[proto+8Ch]`; else 0 and 0. Stored at item `+0Ch` / `+10h`. Site `RmItemFootprint`. |
| rmGetNomadStart | 0x90B683 | confirmed (bytes); value 0 in game | `bool()`: byte `[[[0C66234h]+92Ch]+1A95h]`, false when `[game+92Ch]` is null. Site `RmNomadStart`. In the tested games the RM object stayed allocated during the game and the byte was 0. A Nomad start was not seen: TAD's skirmish setup offers none. |
| Town starting units | FUN_0049039A, out-of-line parts at 0x679AC1 and 0x679B50 | confirmed, in game | EDI = the player. `mov ecx,[eax+140h] / push ebx / mov ebx,[ecx+5E08h]` (TownCenter, 0x679AC8) `/ push ebp / push esi / mov esi,[edi+80h]`; the query after it takes the player's first built unit of proto EBX. At 0x679B50: `FUN_007C238E([player+3E0h], [unit+10h])`, then `and byte [player+349h],0BFh` (0x679B63), which clears the request whether or not anything spawned. Sites `TownStartQuery`, `TownStartSpawn`. The scoping had filed 0x679AC8 under `startingResourceDelay`. In game, with `civFirstTC` querying the Market instead, 6 Settlers spawned at the Market. |
| Colony spawn | FUN_007C238E | confirmed (loop 0x7C2407..0x7C2437), in game | `thiscall(colonies = [player+3E0h], int unitId)`: spawns the town starting units only if bit 0 of `[colonies]` is clear and a colony `[[colonies+8]+4·[[colonies+14h]+4k]]` (k < `[colonies+18h]`) has `[colony+28h]` = the unit. In game a colony started at a Market listed in `<starttypes>` of `placementrules\colonies.xml`; that a proto absent from that list gets no colony is an inference (the `no colony` log path was not seen). Site `TownStartColonyLoop`. |
| Town starting units request | `[player+349h]` bit 40h (player flag 14) | confirmed, in game | Set by the player flag setter 0x8D00E5, called at 0x6A214A when a unit is created whose proto has flag 136 (0x6A211F..0x6A214A, `[[proto+50h]+11h]` & 1); cleared at 0x679B63. In game, a Market without flag 136 that was FirstTC, with a colony at it, never got its settlers; with the flag it got 6. |
| Proto flag 136 | `StartingColonyBuilding` | confirmed | The `protoy` flag parser maps the name (0x5F7018) to `or byte [eax+11h],1` (0x5FD751), bit 136 of the bitset `[proto+50h]` (0x45EE02). Stock `TownCenter` has it, `Market` does not. Other flags `TownCenter` has and `Market` lacks (stock `protoy`): `ColonyPlacementCenter`, `HasGatherPoint`, `AllowAutoGarrison`, `ShowGarrisonButton`; what they do was not traced. |
| FirstTC proto hook | 0x506B3B | confirmed, in game | Shared by `startingTC` and `civFirstTC` (one `jmp`, written by whichever applies first). With `civFirstTC`, a unit of its civ's `<firstTC>` proto, added while the player has no FirstTC, outside a Nomad start, is stored as FirstTC by 0x67ABD4. In game `[player+4F0h]` held the Market's ID. |
| Out of scope | 0x4CF222, 0x7E6905 / 0x7E803F, 0x82E45B, 0x492FD6, `[hc+190h]` | scoping | Code that still looks for the `TownCenter` proto itself: the engine AI's automatic bases (FUN_004CF222), the age-up picker `uiPoliticianUI`, the start camera, the `Maintain` spawn gate, and the water shipment point. The AI scripts (XS) also expect a Town Center: in game a tagged AI got its Market and settlers, then stayed idle. |

### Resource inventories (for `transformInventory`)

| What | Where | Status | Notes |
|---|---|---|---|
| Proto resource object | `[proto+E0h]` | confirmed (0x5F8643, 0x67DE1C) | 14h B, created at parse time on the first resource tag (0x5F811B, scoping): `+0` `InitialResource` list (handler 0x5F8665 → 0x5F8643, which calls the list setter on `[proto+E0h]`), `+8` `CarryCapacity` list (0x5FB65F → 0x5FB63A, scoping), `+10h` `GathererLimit` byte (default FFh, scoping). Null for a proto with no resource tag (e.g. `Musketeer`). |
| Resource list (ResList) | 8 B | confirmed | `+0` array of `[0xC6DF38]` floats, entry r XORed with `[0xC6DF14 + 4r]`; `+4` the total XORed with `[0xC6DF10]`. The keys are in `.data` (8 non-zero dwords at 0xC6DF14..0xC6DF33); the count is set at runtime. |
| ResList get | 0x44EFFF | confirmed | `float thiscall(list, int r)`, `ret 4`; 0 out of range or without an array. |
| ResList set | 0x58EF83 | confirmed | `thiscall(list, int r, float v)`, `ret 8`; recomputes the total. |
| ResList total recompute | 0x58EF02 | confirmed | `thiscall(list)`; sums the decoded entries (x87) and stores the encoded total. Site `ResListTotal`. |
| ResList copy | 0x480A73 | confirmed | `thiscall(dst, src)`, `ret 4`, returns dst; copies the raw encoded entries and the total, only when both arrays exist. Site `ResListCopy`. |
| ResList scale | 0x480B94 | confirmed | `thiscall(list, float f)`, `ret 4`; multiplies each decoded entry (x87), then 0x58EF02. Site `ResListScale`. |
| ResList fill / setTotal | 0x4E2617 / 0x447191 | confirmed | `thiscall(list, float v)`, `ret 4`: every entry = v, total = count × v / the total only. |
| Resource names | 0x5381E0 | confirmed; in game for Food | Registers Gold 0, Wood 1, Food 2, Fame 3, SkillPoints 4, XP 5, Ships 6, Trade 7 in a name table at `[obj+7Ch]`. That these IDs are the list indices was seen in game for Food (a crate logged `{2: 100}` showed 100 food), for Gold (a trigger's 1234 gold) and XP (below); for the others it is an inference (8 names, 8 keys). |
| Player resources | `[player+230h]`, a ResList embedded in the player (its array pointer at +230h) | in game (2026-10-29) | Found by a memory scan after a trigger granted 1234 gold: entry 0 = 1234. A second list at `+240h` read the same values (its role is not known). Entry 5 (XP) rose by 4 about every 1.4 s of game time in a scenario with no other source (a steady XP trickle), and by the unit's `<Bounty>` on a kill (+10 for a musketeer, +20 for a Hussar), including a kill by a `damageOverTime` tick. |
| Unit inventory | `[[unit+B4h]+94h]` | confirmed (0x9BFE5A, 0x4729D0, 0x4EEACD), in game | 14h B pool object: `+0` unit ID, `+4` ResList, `+0Ch` / `+10h` −1 when fresh (`+10h`: forced gather type, read by 0x4EDCFE, scoping; both saved, 0x86A508, verifier). Null for a unit whose proto had no resource object at creation. |
| Inventory alloc | 0x86A865 | confirmed | `cdecl()`: takes an object from pool 0xCAFCA8 (0x86A747), sets `+0`, `+0Ch`, `+10h` = −1 and fills the list with 0. |
| Inventory free | 0x4BA757 | confirmed | `cdecl(inv)`: fills the list with 0, sets `+0` / `+0Ch` / `+10h` = −1 and pushes the object on the free list `[0xCAFCB8]` / count `[0xCAFCBC]`. The caller clears `[[unit+B4h]+94h]` (0x4BA7A7, 0x9BFE7C). Site `InventoryFree`. |
| Inventory recreate | 0x9BFE5A | confirmed | `inv thiscall(unit)`, plain `ret`: frees the existing inventory, allocates a new one, stores it and the unit ID. Callers 0x67DE0F (creation), 0x9C5596 (load, only when null). Site `InventoryRecreate`. |
| Inventory seed at creation | 0x4983A0 → 0x67DE0D | confirmed | In unit init FUN_00498274: if `[proto+E0h]`, `0x9BFE5A(unit)` then `0x480A73(inv+4, [proto+E0h])`. Site `InventorySeed`. |
| Change Unit Type's free | 0x4729D0 → 0x4BA74C → 0x4BA7A7 | confirmed | In the unit reset 0x4728E4 (vtable 0xB934B8 slot 114h, scoping): frees the inventory and clears `+94h`; the re-add 0x498C2D → 0x498274 seeds it again (scoping). |
| Inventory gate of an area search | 0x4EEACD..0x4EEB0C | confirmed | Skips a unit with no inventory or a total ≤ 1e-6 (`[0xBA1388]`). The verifier places it in a nearby-unit search around 0x4DC19A. |
| Main resource type | 0x4DBEC1 | scoping | Index of the largest inventory amount (> 1e-6), −1 without an inventory; 16 callers. |
| Gather set-target | 0x4EDC50 (vtable 0xB97880 slot 10h) | scoping | `[action+70h]` = `[inv+10h]` if not −1, else 0x4DBEC1(target). The gather work 0x4ECD87 ends the action (0x50E327, state 7) when that amount is ≤ 1e-6. |
| DieAtZeroResources | 0x4B436B..0x4B43B0 (checkState 0x482152) | scoping | Kills a unit with flag 14 whose inventory exists and totals ≤ 1e-6; a null inventory is never killed. |
| Owner change rescale | 0x5143CB..0x514418, 0x5146E4..0x5147A0 (in 0x514358, from 0x4E3334) | scoping (verifier confirmed) | `new[r] = min(cur[r], newInit[r]·cur[r]/oldInit[r])` if `abs(oldInit[r]) > 1e-6`, else 0, through 0x514AA1. setHP (0x5146DF) runs before it. |
| Transform in place, around the hook | FUN_009C754C 0x9C75CF..0x9C7691 | confirmed | Other players' KB remove loop (call 0x876D3B at 0x9C75FE), own player remove 0x472AFD (0x9C7620), action manager release at 0x9C762C (`call 4BA630h`, `[esi+58h] = 0`), setProto 0x9C763F, player add 0x49874F (0x9C7658), KB re-add loop (call 0x483DA5 at 0x9C768D), setHP 0x4820A1 (0x9C76F3). Sites `TransformKbRemove`, `TransformInvHook`, `TransformKbReAdd`. |

### Training near an enemy Town Center (for `noTrainNearEnemyTC`)

FirstTC and the two rule evaluators are in "Starting town center" above; Player by ID (0x44CB21)
and Unit by ID (0x44CC6D) in "Home city gather point".

| What | Where | Status | Notes |
|---|---|---|---|
| Train update | FUN_009EA28B (vtable 0xB98388 slot 3Ch) | confirmed (0x9EA28B..0x9EA4D6), in game | `void __thiscall(action)`. ESI = the action; `[action+10h]` the trainer, EDI = `[trainer+44h]` its player (0x9EA2B2, site `TrainUpdateTrainer`); `[action+61h]` state (14h = training); `[action+70h]` queue entries of 14h B, `[action+74h]` count. Rate at 0x9EA410: getter 0x9BFE33 × `[world+310h]` × (`[player+37Ch]` if 0x485D2C(action, 16h)) × `[world+104h]` × (100.0, `[0B9A828h]`, if `[world+334h]` is set and 0x452A5D(17h, player ID, …) is true) × FUN_008D4790(player, `[[action+70h]]`), added to `[action+68h]` (0x9EA4AD). Site `TrainRateScale` covers 0x9EA424..0x9EA436. The meaning of `[world+334h]` is not known. |
| Train progress | 0x9EA1FA | confirmed | `void __thiscall(action)`: `[+6Ch]` = `[+68h]` / `[+64h]`, clamped to 0..1.0 (1.0 when `[+64h]` is below `[0C3755Ch]` = 1e-6). The update completes the unit (setState 0Ah, 0x9EA4CC) when `[+6Ch]` ≥ `[0B856BCh]` = 1.0. In game, a rate of 0.0 held the progress. |
| isEnemy | 0x484D2D | confirmed | `bool __thiscall(player, id)`: `[player+1D4h+4·id] == 2` for 0 ≤ id < 10h, else false; `ret 4`. isAlly 0x4707EC: the same slot is 0 or 1. Site `PlayerIsEnemy`. |
| Unit distance to a point | unit vtable slot B8h: 0x485D68 (0xB934B8 and the base 0xB93190) | confirmed (static, 2026-10-29), in game | `float __thiscall(unit, const float* point)`, `ret 4`: slot B0h, 0x485D83, with `(unit+14h, point)`. That one asks slot 90h, 0x45EE55: when it is false, slot 108h, 0x4A0ED5, returns the distance from the point to the unit's obstruction outline (`[vtbl+1Ch]` → the obstruction, its shape at +10h; 0x485E26), 0 inside it; when it is true, slot F4h, 0x485DBC(from, to, 1), returns the centre distance in x and z minus `[vtbl+24h]` (0x48272C: the larger of `[proto+88h]` and `[proto+8Ch]`, read as the obstruction radii) × √2 (0xBA1384), at least 0 (0x485EDA). In game (`noTrainNearEnemyTC log`), from a Daimyo's centre: a Town Center (radii 4 × 4) 38 m away in x → 34.1 m, and 10.4 m → 6.4 m; a Barracks (4 × 4) 24 m in x and 4 in z → 20.0 m; a Stable (3 × 5) at the same place → 21.0 m. So for these buildings the distance is to the edge of the footprint. For a Hussar (a unit that can move) 18.4 m between centres gave 17.3 m, the radius branch. |
| Can move | 0x45EE55 (unit vtable slot 90h) | confirmed (head) | `bool __thiscall(unit)`, the stock snare's "target can move" test (0x4DD1EE, before 0x4DD22D) and the distance call's choice between radius and outline: false when bit 4 of the proto's flag bitset is set (`[[proto+50h]] & 10h`, with `[proto+54h]` > 4); otherwise it compares `[proto+80h]` with 1e-6 (0xB9FB64; the rest not read). The Town Center's first flag byte was 0xBE in game (bit 4 set). Which protos have bit 4 is not mapped. |
| Point to outline | 0x485E35 / 0x485E26 | confirmed (static) | 0x485E35: squared distance from a point to a 4-corner outline: 0 when 0x4858F0 finds the point inside, else the minimum of 0x423104 (point to segment) over the four edges. 0x485E26 returns its square root. |
| Units near a point | FUN_004A1C55 | confirmed (static), in game | `int __thiscall(world, const float* point, float radius, char precise, IdList* out)`, `ret 10h`. A box query (point ± radius in x and z) through 0x462DBA into the obstruction manager's scratch list `[[world+260h]+4ECh]` (count `+4F0h`); with `precise` the entries whose distance to the point (`[vtbl+B8h]`) is at most the radius are appended to `out` = {data, count, capacity}, whose count is reset first when the capacity is ≥ 0; it grows through 0x401113, and the placement rule frees it with 0x4014C3. Callers: the rule's type branch (0x8CEA86, site `TypeRuleQuery` 0x8CEA69..0x8CEA8B, point `[esp+30h]`, radius `[esp+10h]`), the aura scan 0x9CFF9A, `noTrainNearEnemyTC near` (site `UnitsNearPoint`). |
| Floating text | 0x8023AE | confirmed (static), in game | `int __thiscall(manager = [world+8A8h], BString* text, int time1, int time2, int unitId, const float motion[3], DWORD colour, float scale, char flag, int n)`, `ret 24h`. Returns −1 when `[game+0B39h]` ≠ 0 or `[game+0B3Bh]` = 0, when the unit ID is negative or the text is empty (0x4019FF); else it fills a 4Ch-byte entry (text copy 0x40196F, time1, time2, unit ID, motion, colour ARGB, scale, `flag` as bit 2 of its bitset 0x80214D, `n`) and appends it through 0x4D5450 to the manager's array (data `[manager]`, count `[manager+4]`), returning its index. Stock callers: the dodge 0x6A2604 (time1/time2 from the cfg, motion {0, 0.1, 0}), 0x9C039E (2000, 1000, {0, 0.1, 0}), and 0x6A2AEE, 0x6A2B84, 0x9CF787 (not read); colour `[player+0C8h]` (ARGB: 0xFF2D2DF5 blue, 0xFFD22828 red in game). The second motion component makes the text rise: at 0.1 it left the screen in about 0.3 s in the test bed; at 0 it stayed over the unit (`noTrainNearEnemyTC`). Site `FloatingTextAdd`. |
| Dodge text block | 0x6A24FC..0x6A2608 | confirmed | `[world+8A8h]` non-null and 0x4818F4(unit, `[game+3C0h]`); cfg ints 0x46A144 for the IDs `[[0CEFFF8h]]` (default 1000) and `[[0CF0000h]]` (2000), cfg floats 0x44734C for `[[0CEFFE8h]]` (0) and `[[0CEFFF0h]]` (0.1); string 63950 (0x447719); then 0x8023AE. In game the two ints read 2000 and 1000. Site `DodgeFloatingText`. |
| Visible to a player | 0x4818F4 | confirmed (head) | `bool __thiscall(unit, int playerId)`, `ret 4`; the dodge's test before its floating text. Site `UnitVisibleTo`. |
| Local player | `[game+3C0h]` | confirmed (reads), in game | The player ID of this machine (1 in the test bed). Read by the dodge text block; interface only. |
| Cfg int | 0x46A144 | confirmed | `bool __thiscall(0xC66500, int id, int* out)`, `ret 8`; leaves `*out` unchanged when the variable is not set. The float twin is 0x44734C (`float*`). Site `ConfigInt`. |
| Unit position | `[unit+14h]`, 3 floats | confirmed | `lea edx,[ecx+14h]` at 0x485D6F; x/y/z compared at 0x8CEB96..0x8CEBC4. |
| `trainInSelected` | console command, handler 0x7DFCCF, registered at 0x5400C5 | confirmed (registration) | `void trainInSelected(<stringProtoName>,<traincount>) : tries to train the selected unit type in any valid selected unit` (0xBDDE90). Also `trainInSelectedByID`, `trainByID`, `cancelTrainInSelected`. |
| Daimyo / Shogun | `[db+5EC8h]..[db+5ED8h]` proto IDs; abstract type `AbstractDaimyo` (index 69h) | scoping | The proto IDs are read only by the command panel (0x6960AA..0x696157); `AbstractDaimyo` only by the shipment-point fallback (0x669C41) and the interface (0x69D593). Stock has no training restriction. |

### Hit points and their displays (for `overhealHitpointBars`)

| What | Where | Status | Notes |
|---|---|---|---|
| MaxHitpoints | `[proto+98h]` (float) | confirmed | `<MaxHitpoints>` handler 0x5F5CED, `fstp [ecx+98h]` at 0x5F5D39 (tag string 0xBCDC6C). Site `MaxHitpointsTag`. |
| InitialHitpoints | `[proto+9Ch]` (float) | confirmed | `<InitialHitpoints>` handler 0x5F5C97, `fstp [ecx+9Ch]` at 0x5F5CE3 (0xBCDC58). Site `InitialHitpointsTag`. |
| Spawn HP | 0x498390 in FUN_00498274 | confirmed | `mov ecx,[ebp+9Ch] / push 1 / push ecx / call 4820A1h`: a new unit starts at InitialHitpoints, clamped to its max by the setter (0x4820F3 → 0x4A17A2, scoping). A second write, 0x9C5A53, sets `[unit+64h] = [proto+9Ch]` with no clamp (scoping; probably the load path). In game, a Musketeer with 150 / 165 spawned at 150. |
| Per-unit max override | `[[[unit+0B4h]+0C8h]+4]` (float) | confirmed (reads) | Used instead of `[proto+98h]` when the modifier record exists and the value is above −1e-6 (0xB9FB60). Written by the modifier sum 0x4B3A0E / 0x4B3C7D (scoping, not traced in detail). |
| Max hit points | 0x480408 | confirmed | `float __thiscall(unit)` (ST0): the override, else `[[unit+5Ch]+98h]`, else 0.0 (0x69FB00, constant 0xB84BE4). Cold 0x482403 / 0x69FAFC. Changes EAX, ECX, EDX. 45 direct callers (scoping); 8 inlined copies (0x490821, 0x49B63B, 0x4BEDAD, 0x4C353F, 0x4C3586, 0x4C6B51, 0x4D3404, 0x51469D, scoping: simulation) plus the stat row's 0x4D7575 (confirmed). Site `MaxHitpointsGetter`. |
| Health ratio | 0x45F295 | confirmed | `float __thiscall(unit)` (ST0): same max; 0.0 when max < 1e-6 (0xB9FB64, `test ah,5 / jnp` 0x45F2C5), 1.0 (0xB856BC) when HP ≥ max (`test ah,41h / jnp` 0x45F2D3 → 0x48036D), else `fdivr [ecx+64h]`. Cold 0x45FC30 / 0x69FBB2. Changes EAX, ECX, EDX. 25 callers (scoping), among them the heal search FUN_009CD865 (ratio in [1e-6, 1)). Site `HealthRatio`. |
| Hitpoints tech effect | FUN_008F973F case 0, 0x8F97A4 | confirmed | After the new max is computed (0x7F892A), 0x8F97CD..0x8F97DD adds new − old to `[proto+9Ch]`. Existing units are rescaled by new / old max (0xA0036E, scoping). |
| Ratio-preserving rescale | 0x9C738B | confirmed (head) | HP = ratio × (override or `[proto+98h]`) through 0x4820A1; used after the modifier recompute saves the ratio (0x49F1DB, scoping). |
| Floating HP bar fill | bar chunk 0x45FAA2..0x45FADC of the unit visual update | confirmed | `mov ecx,esi`; under construction (`[esp+15h]`) `call 9C0690h` at 0x6A1431, else `call 45F295h` at 0x45FAAF; `fstp [esp+10h]`; clamp < 0 → 0 (0x6A143B), > 1 → 1.0 (0x6A1448). Entries 0x45F790, 0x45F79B, 0x511D3A, 0x511D7B, 0x511D88 (scoping). Site `OverhealBarRatio`. |
| HP bar queue and renderer | FUN_0045FB71 (only caller 0x45FB67), `[world+8D0h]` / count `+8D4h`; renderer FUN_0045C4AF | confirmed, in game | Queue: `thiscall(world, pos*, scale, fill, player, colour byte)`, `ret 14h`; grows the array through 0x408308 (no fixed cap); 28-byte records: +0 position, +0Ch scale, +10h fill, +14h player, +18h colour byte. Renderer (ECX = world; REA `ev_0886c3a2…`): locks count × 6 vertices of 24h bytes through 0x40A6A2 (the device's dynamic vertex buffer `[[0C66044h]+660h]`, 2 MB in game; a request above its size `[vb+4]` returns null at 0x40A689: no bar that frame); render states 7 and 14 set to 0 and restored (0x4203AB; depth test and writes, inferred); shader `defaultcolored` (0xC38364) and texture `ui\hitpoint_bars\hpbar` (UTF-16 0xC38334, loaded once, 0x6AD775). Colour: palette 0x801542(byte)+8 when byte ≠ FFh and `[world+33Ch]`, else `[player+0C8h]`, else white. Quad: hw = scale/2, hh = scale × 0.0625 (0xB9A93C) along the camera's right `[[game+148h]+28h]` and up `+1Ch`; vertices +0 position, +0Ch constant 0xC66544, +18h colour, +1Ch u, +20h v; v0, v2, v3 left with u = 0.5 + fill/2, v1, v4, v5 right with u = fill/2. One draw call 0x45F96D; the count reset when `[world+8D8h]` ≥ 0. `hpbar.ddt` (art2.bar, 64 × 8): left half black, right half a white-grey gradient tinted by the vertex colour, so the floating bar is the player's colour. Hooks of `overhealHitpointBars segment`: 0x45FB6C, 0x45C4B9, 0x45CB72. |
| Selection group add | FUN_004C4FB5 (only caller 0x460C41) | confirmed | `bool __thiscall(group, unitId)`, `ret 4`. Running average of 0x45F295 at `[group+1Ch]`, count `[group+14h]`: `fild [esi+14h] / fmul [esi+1Ch]`, then `call 45F295h` (0x4C5014), `fadd [esi+1Ch]`, `fidiv [esi+14h]`. Site `OverhealGroupRatio`. |
| Group health readers | 0x4C82EA; 0x69AA75 | confirmed, in game | The panel bar: `[group+1Ch]` against 0.33 (0xBA1F80) and 0.66 (0xBA1F78), green `[panel+310h]` at ≥ 0.66, yellow `+314h`, red `+318h`; fill through 0x590772 (clamps to [0, 1]), then shown through 0x447F7B (`gadgetReal`) with `[panel+2E4h]`, `+2E8h`, `+2ECh`, `+31Ch`; the tail at 0x4C83DF (sites `OverhealPortraitTail`, `OverhealPortraitColours`). "Group Health": `[group+1Ch]` × 100.0 (0xB9A828), `L"%0.0f%%"` (0xC36828). The three colours are three gadgets of `uiunitselection.xml`, looked up by name at panel creation (0x9BAEE5, site `HealthBarGadgets`); `overhealHitpointBars segment` adds a fourth, `unitselectionpanel-unitHealthBarOverheal`, from the UI data. HP text colour: the UI markup `<color=r, g, b>…</color>` (0xBA1E44 / 0xBA1E30, 0xBA2538); the stat row's gadget draws it (seen in game); the `%d/%d` (0xBA2054) and `%d/%d (%d+%d)` (0xC34A54) formats go through swprintf 0x444EFB. |
| HP text formats | 0xBA2054 `L"%d/%d"`; 0xC34A54 `L"%d/%d (%d+%d)"` | confirmed | The split is shown when the unit's max (int) is above the database proto's `[+98h]` (int): cur, max, base, max − base. Both values pass `fistp` with `or ah,0Ch` (truncation). |
| unitHitPointsValue text (T1) | 0x698B11..0x698B6D | confirmed, in game | ECX = EBX = unit; HP `fistp [esp+88h]`; `call 480408h` at 0x698B35 (site `OverhealPanelMax`). Controls `[panel+2F0h]` / `[+2F4h]` (only in `uiunitselectionmin.xml`, the minimized UI, profile option `optionminimizedui` = 49h). In game it read `181/165` for a marked Musketeer under an aura; its gadget prints `<color>` markup as text. |
| 'Hit Points' stat row (T2) | 0x4D7550..0x4D7657, cold 0x69A9B0 | confirmed, in game | ECX = EDI = unit; HP `fistp [esp+30h]`; inlined getter 0x4D7575..0x4D75AC → `fistp [esp+18h]` (site `OverhealStatMax`); database proto `[[[game+140h]+54h]+[proto+8]*4]`, `fld [eax+98h]` at 0x4D7615 (site `OverhealStatBase`); `%d/%d` at 0x4D7651 or the split at 0x69A9C0. Controls `[panel+178h]` / `[+19Ch]` (scoping). In game it read `Ptos de resist.: 150/150` for a marked Musketeer. |
| ObjectInfo stats (T3) | FUN_009AF31A, 0x9AFA07..0x9AFAAB | confirmed (bytes); not reached in game | ESI = unit; database proto from 0x45316E(`[game+140h]`, 0x44CB0A(unit)) at `[esp+2Ch]` (0x9AF34A, site `OverhealInfoProto`; `[esp+30h]` after `push ebp`); base `fld [ecx+98h]` at 0x9AFA2A; max `call 480408h` at 0x9AFA4E; formats at 0x9AFA8B / 0x9AFAA5. Callers 0x9AFE40, 0x9AFED7 (scoping). The panel `ObjectInfoPanel` (`uiobjectinfopanel.xml`) is built by the scenario editor screen (FUN_006F8C19, `aeditorscreen.cpp`); selecting a unit in the editor did not show it. |
| Gadget by name | 0xAB7C2F | confirmed, in game | `int* thiscall(panel, int* handle, BString* name, int flag)`, `ret 0Ch`: 0x402733 narrows the name (it reads the BString header at text − 10h, so the name must be a real BString: 0x401A12), 0x433812 searches the panel's gadgets and writes the handle, or `[0C672C0h]` when none matches (valid handles are above it). Site `GadgetByName`. |
| Gadget show / hide | 0x447F7B / 0x448F13 | confirmed, in game | `void thiscall(manager = [[0C66244h]+44h], int handle)`, `ret 4`: the code behind the UI commands `gadgetReal` (0x7E2244) and `gadgetUnreal` (0x442BE7); the gadget's vtable +54h / +58h(0). Showing a hidden gadget puts it above its siblings; showing a visible one does not move it (seen in game). Sites `GadgetShow`, `GadgetHide`. |
| Progress bar | 0x44B8B8; fill 0x590772; parser 0x5CC7E0.. | confirmed, in game | 0x44B8B8(handle), cdecl: the progress bar gadget (0x40423C type 1Eh) or null; release the reference with 0x40431B(handle). Fill `thiscall(bar, float)`: clamps to [0, 1], `[bar+13Ch]`, then `[bar+144h]` (the mask drawable) vtable +50h. The parser sets the background (0x5CAF02) only with both `progressBarBackground` and `progressBarBackgroundSize`, the mask (0x5CD0F5) as its own drawable; with no background nothing is drawn (seen in game). Attributes: `progressBar{Background,BackgroundSize,Mask,LeftCap,LeftCapSize,RightCap,RightCapSize,Flare,FlareSize}`. Sites `ProgressGadget`, `GadgetRelease`, `ProgressFill`. |

### Gathering and the stat panel (for `showGatherRate`)

The proto flag test (0x45EE02, flag 9Bh), the raw bit test (0x44CAC4, indices 37h / 58h), the
world's `+318h`, the player's `+338h` / `+37Ch` and the BString functions are in the tables above;
the Gathering dance (FUN_004ECD39) in "Dances".

| What | Where | Status | Notes |
|---|---|---|---|
| Gather tick (BUnitGatherAction::collectStuff_2, WoL's symbol) | FUN_004ECD87 | confirmed, in game | `thiscall(action, float elapsed)`, `ret 4`. Frame: `sub esp,1Ch`, push esi/edi, push ebp (0x4ECDCF), push ebx (0x4ECE1F): elapsed at `[esp+30h]`, amount `[esp+14h]`, the target's holding `[esp+1Ch]`, the unit of ID `[action+64h]` at `[esp+24h]`, target `[esp+28h]`. Returns at once while byte `[game+B3Ah]` is set. R = ((cur − base) + k·base) · `[world+318h]` · dance (0x4ECFDA..0x4ED02F; k = `[[[unit+B4h]+C8h]+24h]` above 1e-6, else 1, cold 0x69FE53); R ≤ 1e-6 ends the action (0x6A8AEA); at 0x4ED044 ST0 = R, the only x87 value (site `GatherTickRate`). Then × elapsed, clamped to the target's holding, × `[player+37Ch]` (0x4ED13A), 0 for an `AbstractShrine` target (0x4ED14B) or `[player+338h]` ≠ 0 (0x4ED1AB), proto-action flag 4 → the gatherer's own inventory (0x4ED15D), add 0x49A98A (0x4ED1EE); resource 5 (XP, inferred) also goes through 0x9C02C0 (0x4ED1F3). Only caller 0x4ECCD8. In game, a Settler on a berry bush recorded 0.670/s. |
| doAnimationLooped (WoL's symbol) | 0x4ECC88, Gather action vtable 0xB97880 (slot 0xB978E8) | confirmed (head) | Only while byte `[action+61h]` = 5: adds `[world+104h]` to `[action+88h]`, then calls collectStuff_2 with elapsed = 0x4939BD(gatherer) (the animation loop's length), or collectStuff 0x9DD7B4 when action bit 22 is set (0x4ECCB1, cold 0x6A8CED; gathering into the unit's own inventory, scoping). |
| Gather action fields | — | confirmed (reads in 0x4ECD87) | `+4` proto action, `+10h` gatherer unit, `+14h` target unit ID, `+61h` state byte (5 = gathering), `+64h` a unit ID (looked up at 0x4ECDAB), `+70h` resource index, `+88h` animation time accumulator. |
| Current action | `[[unit+58h]+24h]` | scoping | Set by the action manager's add 0x494894 (verifier). Actions come from a per-type pool (0x48D927, `[world+1A4h]`). |
| Stat panel fill | FUN_004D70ED (EBP frame; hot part to ~0x4D82B4, cold part 0x698A00..0x69C800) | confirmed (0x4D76DB..0x4D783F, 0x69AF6D..0x69B187), in game | `[ebp+8]` = selection (`+14h` count; byte `+21h` must be 0 for the AutoGather row, meaning unknown); `[esp+2Ch]` = next row (2 after HP, 0x4D76E0); `[esp+38h]` = first selected unit; `[esp+50h]` = the panel. AutoGather gate 0x4D76FF..0x4D782E (site `StatPanelAutoGatherGate`); join point 0x4D7834 (site `StatPanelAfterAutoGather`; 16 branches land on it, scoping; none inside 0x4D7835..0x4D783A). |
| Stat panel rows | `[panel+174h+i*4]` labels, `[panel+198h+i*4]` values, i = 0..8 | scoping (bind 0x9BBAD1) | `StackLabel%d` / `StackValue%d` of `uiunitstatpanel3`; the row writer resolves them with 0x4C519C. |
| Row writer | 0x69AF7C..0x69AFDF | confirmed | Input EBX = row; ESI = label gadget, EDI = value gadget; a missing gadget jumps to 0x4D7834 (0x69AFD2, 0x69AFDA). Site `StatPanelRowWriter`. |
| Row after HP; Group Health row | 0x4D76DB; 0x69A9D3..0x69AB0F | confirmed, in game | `mov edi,2 / mov [esp+2Ch],edi`: the next row after the HP row (site `OverhealStatRow`, the `overhealHitpointBars stat` hook). Group Health writes row EDI: gadgets through 0x4C519C(`{handle, gadget}`, handle) and 0x40431B; label `L"Group Health"` (0xC36838, a literal) with style 0D6F5D0h and value with style 0C6657Ch (vtable +84h), text +80h, +54h; help texts `[gadget+68h]` set to `L""` (0x401A12, 0x40196F); then `add edi,1 / mov [esp+2Ch],edi`. Sites `GroupHealthRow`, `GadgetRef`, `BStringFromWide`, `BStringSet`. |
| BString from text / assign | 0x401A12 / 0x40196F (0x4013B0) | confirmed | `thiscall(BString*, const wchar_t*)` (clears the BString first) / `thiscall(BString* dst, const BString* src)`; 0x4013B0 assigns `(text, -1, -1)` to an existing BString. Free 0x4010CA. |
| Profile game options | `<Setting Name="option…">` of `NewProfile3.xml`, read through 0x402CE9(id, out) | confirmed (one) | The ID is the setting's index in the profile's `GameOptions` list: 49h = `optionminimizedui` (0x4C8233 for the portrait path, 0x661E03 when the panel is built, which then loads `uiunitselectionmin.xml`). |
| AutoGather resource loop | 0x69AFE0..0x69B028 | confirmed | EBX = 0..`[db+80h]`−1, rate = 0x49EBE4(`[esp+0Ch]` = the AutoGather action, EBX) stored with `fst [esp+1Ch]`; the first rate above 1e-6 goes to 0x69B02A; none: 0x4D7834. Site `StatPanelAgLoop`. |
| Row formatter | 0x69B02A..0x69B186 | confirmed, in game | Label `%s (<icon="(32)(%S)">):` (0xC36580) from 0x60782A / 0x58EA52 and the icon 0x706EFB; value `%.2f/s` (0xC36554), or `%d/s` (0xC36548, chop) when rate − floor(rate) ≤ 1e-6 (0x58F05D, 0xBA20B4), which writes `[esp+0Ch]` (0x69B0EF, 0x69B0FB); `add [esp+2Ch],1`; `jmp 4D7834h`. Site `StatPanelRowFormat`. In game it wrote `Alim. (icon): 0.67/s`. |
| Resource name | 0x60782A | confirmed | `int thiscall(db, resource)`, `ret 4`: the string ID `[[db+180h]+res*4]`, count `[db+184h]`; −1 out of range. Food is resource 2 (in game: `Alim.`, resource 2). Site `ResourceNameId`. |
| BString assign (forwarder) | 0x443BB8 | confirmed | `void thiscall(BString* this, const BString* src, int, int)`: forwards `[src]` to 0x4013B0 (assign from `wchar_t*`; −1, −1 = the whole string). Used by the string providers (0x6F5931). Site `BStringAssign`. |
| Data-ref registration | FUN_005CFA7C (ctor of the `{}` parser, vtable 0xB9EA48) | scoping (table), confirmed (0x5D2D38) | Entries `{id, type 1 float / 2 int / 3 string / 4 color, name, provider}`. Ids 19h / 1Ah share `mov ebx,5FDE49h` at 0x5D06E7 (imm32 0x5D06E8); id 68h `mov dword ptr [esp+2Ch],5FDE49h` at 0x5D2D38 (imm32 0x5D2D3C, site `GatherRateStringRef`). Ten more refs use the same stub. |
| Data-ref stub | 0x5FDE49 | confirmed | `xor al,al / ret 4` (WoL's symbol table calls it BCore::textureChanged: a folded stub; four direct callers elsewhere). Site `DataRefStub`. |
| Data-ref evaluators | vtable 0xB9EA48: +4 0xAB9544 (color), +8 0x44A25A (string), +0Ch 0xAB94A2 (int), +10h 0xAB9400 (float) | confirmed | `thiscall(this, id, arg, out*)`, `ret 0Ch`. The typed ones call `[entry+0Ch]` only when the registered type is theirs; the string one dispatches on it (jump table 0x44A40C: 1 → 0x44A31D, 2 → 0x44A2C8, 3 → 0x44A635, 4 → 0x44A391). Each sets `Value.type` to the registered type, `[0C6DF7Ch]` = arg during the call (0 after), and checks the vfunc `[[0C66244h]]+4Ch` first. Type 3: Value `{3, BString 0}`, copied out with 0x40196F on true (site `DataRefStringEval`). |
| Data refs' current unit | `[[[0C67310h]+920h]+13Ch]` | confirmed (0x6F49B1) | A unit ID, looked up in `[[0C66234h]+13Ch]` (ID & 3FFFFh, stored ID must match). Other providers use other notions (0x6F5931: 0x4051B6 / 0x930041). Site `CurrentUnitRef`. |

### Building work rate auras (for `buildingWorkRateAuras`)

The getter 0x9BFE33 and its four callers are in "Building work rate"; the modifier action, its
creation 0x4DD22D, the action lists, the collector and the sum 0x4B3C7D in "Snare and group
movement".

| What | Where | Status | Notes |
|---|---|---|---|
| ModifyType name → stat | FUN_005F5645, `int cdecl(BString*)` | tail and callers confirmed; name table scoping | Compares through 0x443C10 (case ignored); Speed 0, MaxHP 1, Damage 2, MovingDamage 3, Bounty 4, SiegeDamage 5, UnitDamage 6, LOS 7, Armor 8, GatherRate 0Bh, AbilityROF 0Ch, ROF 0Dh, AutoGatherRate 0Eh, else −1 (the cold returns of 3, 7, 8, 0Ch and 0Dh at 0x67D730..0x67D752 confirmed). Tail 0x5FE6C7..0x5FE6E1: `neg eax / sbb eax,eax / and al,0F1h / pop esi / add eax,0Eh / ret` (site `ModifyTypeNameTail`). ESI = the name throughout. With `buildingWorkRateAuras`, `BuildingWorkRate` → 40h (in game). |
| ModifyType callers | 0x5FC8AE (tactics tag, dispatch 0x5F9FD0); 0x5F3EFA (powers `<unitModify>`, FUN_005F3E97) | confirmed (call sites); rest scoping | Tactics: `mov [ebp+0B8h],al` with no check (default 0FFh at 0x5FA4E7). Powers: `mov ebp,eax / test ebp,ebp / jl` → error 1233h; stores {stat, op, amount} in `[obj+128h]`, applied by 0x8EE18E → 0x4DD22D. |
| Tactics ModifyType byte | `[tacticAction+B8h]` (signed byte) | scoping | Read by 0x9D064C (aura apply), 0x9D7696 (second applier), 0x9E3727 (init of class 0xB97C78) and 0x9D6F40 (aura tooltip: `stat − 1` ≤ 5, else default). `<ModifyMultiplier>` → `[+ACh]`, `<ModifyProtoID>` → `[+9Eh]`, `<ModifyAbstractType>` → `[+9Ch]`. |
| Aura apply | FUN_009D033E, call 0x4DD22D at 0x9D0670; filter 0x9D0238; scan 0x9CFF9A → 0x4A1C55 | scoping; in game for a completed building | `0x4DD22D(target, stat, mult, −1f, −1f, 0, 2, 0 ms, −1, −1, exclusive)`. Filter: not the owner, same player unless tactic flag 20h, alive, complete (0x44DDB4), ModifyProtoID / ModifyAbstractType. Runs only when the multiplier is > 1e-6 and the owner is complete. Keeps {target ID, modifier ID} at `[ua+68h]`. In game, an Explorer's aura reached a completed BloodFactory. |
| Modifier action classes | vtable 0xB97C08 (ctor 0x4DDA01, from 0x4B3D9E); vtable 0xB97C78 (ctor 0x9E36CC, factory case 46h) | scoping | Both carry runtime type 2Ch. WoL's ModifyActionFix retypes the second to 46h (0x9E36D0) and replaces the collector call 0x49F251. |
| Collector call | 0x49F23C..0x49F251 in FUN_0049F1BA | confirmed | Clears the count `[0CF071Ch]`, then `mov ecx,[edi+58h] / push 0CF0718h / push 1 / push 2Ch / add ecx,14h / call 49F1A0h`; then per-stat helpers from 0x49F26A. |
| GatherRate helper | 0x4B3B75 | confirmed | `[esp] = 1.0f`, `0x4B3C7D(&v, list, 0Bh)`; stores v only when it matched (cold 0x6A8972). The model for stat 40h. |
| GatherRate / AutoGatherRate readers | 0x4ECFE9 → 0x69FE53 (`+24h`); 0x49EDB8 → 0x69FE87 (`+28h`; another `+28h` reader at 0x69FE6F) | confirmed (0x4ECFE9, 0x69FE53, 0x49EDB8, 0x69FE6F); 0x69FE87 scoping | Record `[[unit+B4h]+C8h]` (no null check of `[unit+B4h]`); field used when `fcomp` with 0xB9FB64 (1e-6f) is not below and ordered-or-NaN (`test ah,5 / jnp`), else 1.0 (0xB856BC). Sites `BwrGatherRateRecord`, `BwrGatherRateRule`. |
| Getter callers' continuations | 0x9EA418 (Train), 0x9E65FC (Research), 0x9D58D9 (CommandResearch), 0x6AB244 (Maintain) | confirmed | Each writes EAX within two instructions and calls a function before reading the flags; ECX and EDX are rewritten before they are read. Sites `BwrTrainCallNext`, `WorkRate*Call`. |
| Getter tail | 0x9BFE38..0x9BFE47 | confirmed | The getter after its first two instructions (the part liveBuildingWorkRate does not write). Site `BwrGetterTail`. |
| `g_uhcBwrTrainGetter` | UHC.dll export (data, C linkage) | — | `void*`, default 0x9BFE33; set to the wrapper when `buildingWorkRateAuras` applies. noTrainNearEnemyTC's Train hook calls through it. |

### DE parity sites (for [de-parity.md](de-parity.md))

Sites for the WoL requests that DE already implements (2026-10-30). No feature uses them yet, and
nothing here was checked in game.
- REA bundle: `rea/evidence/age3y-b1a1dab7/de-parity-bundle.json`, 108 records.
- Snapshot: `rea/snapshots/age3y-b1a1dab7-de-parity.json`.
- The full notes, with every Evidence ID, are in `rea/evidence/aoe3de-31fad98f/parity/legacy-findings.md`.
- `cs` means a capstone listing.

| What | Where | Status | Notes |
|---|---|---|---|
| Snare skip site (#38) | 0x4DD201 in FUN_0048FA07's cold chunk; skip → 0x48FA49 | confirmed (`ev_0a1374…`) | At 0x4DD201, nothing is pushed yet. The registers: ESI = EDI = target unit; EBP = the attacker's unit action, `[ebp+10h]` the attacker unit, `[ebp+4]` its tactics action. The 6 bytes 0x4DD201..0x4DD206 are three 2-byte pushes (`6A 01 6A FF 6A FF`). FUN_0048FA07's only caller is 0x48F9F5 in FUN_004B7766. `damageOverTime`'s `AttachSnare` calls 0x4DD22D directly, so it does not pass here. |
| `<Bounty>` | handler 0x5F5D79, store 0x5F5DC5 → `[proto+168h]` (float) | confirmed (cs) | No `resourcetype` attribute. The wide `L"Bounty"` 0xBCB24C is the ModifyType name (stat 4). |
| Bounty value | 0x4D4DC5, `float __thiscall(Unit* victim, Unit* killer)` | confirmed (`ev_08304b…`) | `[proto+168h]` × build fraction (when < 1) × the killer's `Bounty` modifier record `[[[killer+B4h]+C8h]+18h]`. |
| Bounty payment | TakeDamage 0x49B715 → cold 0x4D4E0C; 0x49B73C `call 49BD52h`; FUN_0049BD52 → FUN_0049BDC0 → `0x49A98A(player, 5, amount)` at 0x49BE40 | confirmed (`ev_a580c3…`, `ev_3bdf2e…`) | At 0x49B73C: ESI = victim, EBX = killer player, EAX = bounty. FUN_0049BDC0 `thiscall(Team*, playerId, amount, int)`: with playerId < 0 it pays **every team member the full amount** (loop 0x68EA12, call 0x68EA46). `TeamKillBounty` site: 0x49BDAB..0x49BDB0 (push −1 instead of `[esi]`). A second path in the kill handler (cold 0x6A3A2E) splits the bounty among the enemy teams; its trigger is not traced. |
| Trickle subtypes | `ResourceTrickleRate` 1Ah, `MinimumResourceTrickleRate` 1Bh, `MaximumResourceTrickleRate` 1Ch (registered 0x52509D..0x5250E9) → FUN_008D842B cases 0x8D8527 / 0x8D85DF / 0x8D8652 | confirmed (cs) | Player fields `[player+248h]` rate, `+250h` min, `+258h` max (ResLists). Defaults rate 0, min 0, max 10.0 (0x8DA8EF..0x8DA912, `ev_70ef81…`). No range check on the amount. |
| Trickle update | FUN_00490447 (called at 0x490A10) | confirmed (`ev_d5ff59…`) | Every 2 s. Clamp to [min, max] at 0x4E0D66..0x4E0D82 (→ 0x67A6EA / 0x67A6F7); add `elapsed × rate × [player+37Ch]` through 0x49A98A at 0x4E0CF9. A negative rate is clamped to the default minimum 0. |
| Stockpile floor | 0x49A98A (add resource), 0x49A9BF..0x49A9CA → 0x679A0E | confirmed (`ev_14c2aa…`) | A result below 1e-6 becomes 0; the shared-resources path clamps each ally too (0x6799C7). A stockpile never goes negative. |
| Garrison action flags | parser FUN_005F98A0: `ActiveIfContainsUnits` → bit 17 (0x5FEDD3), `ScaleByContainedUnits` → bit 18 (0x5FEE1A) of the tactics action's bitset `{[+64h], [+68h]}`; `DamageFactorCap` → `[+48h]` [I] | confirmed (`ev_b2494f…`) | The tactics action, not the runtime unit action of "Snare and group movement". |
| `ActiveIfContainsUnits` readers | AutoGather update 0x48CC0C (vtable 0xB970F8 slot 3Ch): 0x48CFF1 → 0x6A7D61 `cmp [[esi+10h]+74h],0`; ModifyGather 0x9E3A01; generic queries 0x487F7A, 0x4EEA33, 0x4B2CC3 | confirmed (`ev_b671c7…`, `ev_1cf58d…`) | **AutoGather honours it**: no garrison, no gathering in that update. `[unit+74h]` = contained count. |
| `ScaleByContainedUnits` readers | projectile launch FUN_004995C7 at 0x4996C7; stat panel 0x4D7ADB | confirmed (`ev_117eaf…`) | Attack damage × contained count, capped by `[action+48h]`. No economy reader. |
| SwapUnit power | type 2 (0x526BF8); definition ctor 0x8F5449 (vtable 0xB85474, tag parser 0x8F5802, not a Ghidra function); runtime ctor 0x8EB392 (vtable 0xBA073C), update 0x8EC708, swap of one unit 0x8EB6F8 | confirmed (`ev_e6d4ef…`, `ev_b7d166…`); end of `ActiveTime` scoping | `mutate` (`[def+14Bh]`) → in-place transform 0x9C754C at 0x8EB78A (keeps ID and HP ratio). Otherwise destroy 0x4726B2 at 0x8EB876 and create 0x498ACC at 0x8EB89C (new ID, initial HP). Own tags: `AbstractType`/`swapTo`, `mutate`, `swapEnemyOnly`, `swapSelfOnly`, `global`, `swapDelay`, `SwapUsingMinMax`, `MinSwapAmount`, `MaxSwapAmount`, … **No `reversible`, and nothing swaps back** [I, strong]. `ActiveTime` is the common power tag `[def+24h]`. |
| Tech flag `DoNotQueue` | flag parser 0x620C2F (`_stricmp` chain) → 0x6B13ED `or byte [esi+3],4` (status bit 26); name → index 0x622B7D (→ 1Ah at 0x6B123D) | confirmed (`ev_9920c7…`, `ev_50db10…`) | No reader of bit 26 found (capstone pattern search). The proto flag parser (around 0x5F6800..0x5F7000) has no `DoNotQueue`. |
| Crate rank by civ | 0x4DBF40 `int __thiscall(db, resource, civId)`; tables 0x4DC4E0 (default: Gold 1, Wood 2, Food 3), 0x4DC4D0 (Dutch, test 0x4DBF5C: Gold 3, Wood 2, Food 1), 0x4DC4F0 (Ottomans, Indians: Wood 3) | confirmed (`ev_252889…`) | Used at 0x49A03C by the unit-query scorer when the query mode `[q+0Ch]` = 2 (set at 0x944AEF for Gather): score += rank × 1000. |
| Next crate | FUN_00501786 (only caller 0x50170B, loop 0x5016E5..0x50174E, search 0x4DBFD5 at 0x501738); Dutch test 0x50188E | scoping (cycle from pseudocode, `ev_e78008…`) | Large before small. Default Food → Wood → Coin; Dutch Coin → Wood → Food; Ottomans and Indians Wood → Food → Coin. Crate protos `[db+5E34h]`..`[db+5E48h]` (cached at 0x5EE9E9). |
| Train batch | FUN_009CE2BE (train order), `call 8D051Bh` at 0x9CE645 → EBP = units per Train action | confirmed (`ev_467532…`); merge loop scoping | 0x8D051B returns `[player+2ACh]` (subtype `PlayerSpecificTrainLimitPerAction` 64h, store 0x8D886E, default −1), else `[world+178h]` (value not found). The shift-click 5 is the UI string `trainInSelectedByID(%d, 5)` 0xC31A94 (formatted at 0x69601D..0x696036). |
| Build limit | limit 0x4C7B5F `int __thiscall(Player*, Proto*)`; count 0x4C7BC5 `int __thiscall(Proto*, playerId, alive, queued)` → 0x4C846D at 0x4C7CB4 | confirmed (`ev_305b06…`) | `<BuildLimit>` → `[proto+108h]` (0x5F8DA3); the player's copy `[[player+0E0h]+4·[proto+4]]+108h`. Train-queue check 0x9EACE1..0x9EAD1A (`count + n < limit`). 50 callers of the limit. A proto with `[proto+1D1h]` ≠ FFh takes a category path (0x67AA73, not traced). |
| Research payment | FUN_009E667A (called at 0x9CCBE1 when a research is queued): `call 8D946Ah` at 0x9E67E1 (cost = tech entry +10h), success → 0x9E6874, the paid cost copied to the action at 0x9E68A0 | confirmed (`ev_6b5f70…`) | 0x8D946A `bool __thiscall(Player*, ResList*)` = test and pay (26 callers). Second path 0x9D54CF (CommandResearch side). `NextResearchIsFree` site: 0x9E67DB..0x9E67E5. |

## Rendering, threads and timing (2026-10-28, for the performance investigation)

Full write-up and evidence: [performance.md](performance.md). REA bundles:
`rea/evidence/age3y-b1a1dab7/bundle-perf-20261028.json`, and `bundle-perf-20261028-d.json` for the frame
structure, world update and file reader rows. Those rows are static readings confirmed by stack sampling (§9 of
performance.md).

| VA | Role | Notes |
|---|---|---|
| 0x5AA825 | Timer setup | `timeBeginPeriod(1)`; the matching `timeEndPeriod(1)` is in the shutdown function FUN_0057D028. |
| 0x455D91 | Sim update length | Single-player step = real elapsed time, capped at 100 ms × game speed. `fixedUpdate` / `RunAsFastAsPossible` / `MinRandUpdate` branches. |
| 0x54EF1E | Renderer ctor | Sets PresentationInterval `[+638h]` = IMMEDIATE and calls 0x54EDAA. |
| 0x54E60B | Renderer init | `Direct3DCreate9(0x20)` → `[+488h]`; adapter `[+640h]` from cfg `d3dadapter`. |
| 0x545BB5 | Create/reset device | Present params at `+604h`: BackBufferCount 1, DISCARD. BehaviorFlags `(MIXED 80h or SOFTWARE 20h) \| MULTITHREADED 4`. CreateDevice at 0x545D78; device at `+4D0h`. |
| 0x54EDAA | Skinning MT gate | MT = `!singleThreadedBatcher && cpus > 1` → `[renderer+9290h]`, through 0x54ED40 on batchers at `+8EE4h` / `+9294h`. |
| 0x5D6B8A | Skinning worker start | Creates the single worker 0x4058BF (event 0xC674B8, CS 0xC674C8). Called once from 0x5D6B53 when `[renderer+9290h]` is set. |
| 0x40B65E | Deform (producer) | Queues a job (cap 0x100, scratch cap 0x5000 `__m128`) and calls `SetEvent`, or deforms synchronously. |
| 0x4058BF | Skinning worker | Takes jobs under the CS while `[0xC674C0]`; done count `[0xC67500]`; never told to quit. |
| 0x40599C | Queue flush | Drains on the calling thread with `[0xC674C0] = 0`, spins until the worker finishes, resets the queue. |
| 0x40B54F | Run one job | `thiscall(deformer, job*)` → `deformerdlly.dll` SSE exports by vertex format. |
| 0x5734E0 | Register cfg variable | `thiscall(0xC66500, name, desc, default?, 0)` → ID. |
| 0x4020C3 | Cfg "is defined" | `thiscall(0xC66500, id)`. |
| 0x404EE0 | Main loop (WinMain body) | Message pump 0x402EF7, then `[0xC66234]->vtable[74h]` through the `jmp eax` stub 0x406A01 (returns to 0x404FAD). Bundle `-d`, `ev_bbbe9b38…`. |
| 0x40542F / 0x405523 / 0x405574 | Per-frame function (game vtable+74h), cut by Ghidra at the `timeGetTime` stubs 0x405510 / 0x405561 | Update = mode manager 0x405248; render = `vtable[78h]` through 0x408FE4 (returns to 0x4056B1). The game's own per-frame ms averages are at `[game+CC0h]` (update) and `[game+CBCh]` (render), refreshed every second. `ev_0cf19746…`, `ev_66b6966f…`, `ev_fa2d724b…`. |
| 0x405248 | Mode manager update | Mode stack ("Mode to be terminated is: %d…"); updates each active mode through 0x405339. |
| 0x44E0CD (+0x44E183, 0x48FFD9, 0x48FFF3) | Game-mode update, in pieces | 0x44E183 is the only caller of 0x455D91. 0x48FFF3 calls the world update at 0x49000B. `ev_ee973830…`, `ev_ad8fe973…`. |
| 0x481B1C | World update | `this` = `[game+13Ch]`; assert `.\world.cpp`. Phases are counted in `[world+810h]` and separated by 0x491C94; the sim RNG is at `[0xC6658C]+18h`. `ev_dd5f48b8…`. |
| 0x4848BB | Unit update loop | Over `[world+D4h/D8h]`, `[+E0h/E4h]` and `[+ECh/F0h]`; per-unit update 0x482F50. `ev_4677dfc3…`. |
| 0x45084C / 0x450A4E / 0x44FC96 | Render pass dispatcher / main view pass / world draw | 0x44FC96 builds the visible-unit lists and draws each unit through 0x452392. Other passes call it from 0x4597A4. `ev_cf045b59…`. |
| 0x468450 | File stream open | Checks for the `l33t` compressed header (inflate stream, vtable 0xBA3318); otherwise uses a raw stream. `ev_bb0bb32c…`. |
| 0x4683F4 | Raw file stream read | One `ReadFile` per call, no buffering. 0x599121 reads 4 bytes through 0x5990D1; 0x43B8FF reads a 16-byte header as four such reads. `ev_1c4e2090…`. |
| 0x55A185 | Single-instance check | `CreateSemaphoreW(NULL, 1, 1, name)` → `[this+880h]`, then `WaitForSingleObject(h, 0)`; a timeout (0x102) jumps to 0x6D1039. The name is formatted as `Global\%s` (0xBE3768) when `[esp+18h]` is 2 (inferred: the NT platform ID), so it is shared by every copy of the game in every session. Observed 2026-10-28: the name is `Global\Age3` (logged by `multipleInstances`), and a second copy started from another folder stops at "Sólo puede ejecutarse una copia del juego al mismo tiempo"; that 0x6D1039 leads to that dialog is inferred. `multipleInstances` renames this one semaphore per folder. Capstone listing (not REA): `rea/evidence/age3y-b1a1dab7/single-instance/`. |

## IAT slots (from the loader stub and early patches)

LoadLibraryA 0xB84228 · GetProcAddress 0xB84354 · MessageBoxW 0xB8459C · ExitProcess 0xB8438C ·
HeapAlloc 0xB84180 · HeapReAlloc 0xB841B8 · MultiByteToWideChar 0xB841FC · lstrcpyW 0xB84290 ·
GetCurrentDirectoryW 0xB84348 · FindClose 0xB84380 · lstrlenW 0xB843A8 · lstrlenA 0xB843AC ·
lstrcpynW 0xB843B0 · FindNextFileW 0xB843D0 · FindFirstFileW 0xB843D4

All 15 are **confirmed** by parsing the stock exe's import table (2026-10-27, Python, not REA):
every slot resolves to the named KERNEL32/USER32 import.

Timing, threads and Direct3D (confirmed the same way, 2026-10-28): timeGetTime 0xB8400C ·
timeEndPeriod 0xB84010 · timeBeginPeriod 0xB84014 · Direct3DCreate9 0xB84164 · GetSystemInfo 0xB841D0 ·
QueryPerformanceCounter 0xB8426C · QueryPerformanceFrequency 0xB84270 · CreateEventW 0xB84274 ·
CreateThread 0xB84314 · Sleep 0xB84324 · WaitForSingleObject 0xB84328 · SleepEx 0xB84364 ·
GetTickCount 0xB843A4 · SetThreadPriority 0xB843E0 · SetPriorityClass 0xB843E4 · GetPriorityClass 0xB843E8 ·
GetThreadPriority 0xB843EC · CreateSemaphoreW 0xB843F0 (replaced by `multipleInstances`) · SetEvent 0xB84400

File I/O (confirmed the same way, 2026-10-28; `bufferedFileReads` replaces the first six): CreateFileA 0xB842A4 ·
CreateFileW 0xB84304 · ReadFile 0xB8424C · SetFilePointer 0xB84244 · CloseHandle 0xB84330 ·
DuplicateHandle 0xB843A0 · GetFileSize 0xB842A8 · GetFileType 0xB84218 · CreateFileMappingW 0xB8427C ·
MapViewOfFile 0xB84278. The exe imports no `msvcrt`: its C runtime is static and uses these slots too.
