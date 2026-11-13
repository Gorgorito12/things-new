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
| 0xC65083 | cfg path (written by the patcher) | DLL/UHC.cpp:48 | n/a (loader patch) | |

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
| Per-hit call in TakeDamage | 0x49B73C, `call 0x49BD52` | On every hit with an attacking player. At that point `[esp+20h]` is the attacker's player (also EBX), `[esp+28h]` its unit, `[esp+0A4h]` the attacker's proto ID, `[esp+0A8h]` the action, `[esp+0ACh]` the attacker's unit ID, and ESI the unit hit. `[action+4]` is the action's name index. Confirmed in game (`pillageGold`). |
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
| Poison flag | bit 8 of the action's flag bytes `[action+64h]` | Set by the `Poison` handler 0xA11D4D of the 105-tag map (other bits: Active 0, Persistent 2, SingleUse 3, AddResourcesToInventory 4, AddResourcesFasterWhenOwned 5, MuteDamage 6, ReflectDamage 7, Throw 14). FUN_005F98A0, which parses `<ProtoAction>`, has no `Poison` compare, so how data would set it is not established. No stock data uses it. |
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
| Action parser | FUN_005F98A0 | `thiscall(actionSet, proto, action, node)`. An if-chain of 87 compares `0x443C10(nameStr, L"Tag", 0, -1)` (0 = equal), shared by `.tactics` `<action>` and `protoy` `<ProtoAction>`. In the loop, EDI = child node and ESI = the **address** of its name BString, `[[node+4]+18h] + 4*[node+18h]` (lea at 0x5F993E; 0xD6FC90 when the index is out of range), so the UTF-16 name is `[esi]`; the text is `*(wchar_t**)(node+14h)`. `action[1]` = action name ID (from `<Name>`), `action[2]` = type, `[action+64h]` = flag bytes. The last compare is `ModifyExclusive` (0x5FA10F); an unknown tag falls through 0x5FA11E to the loop increment 0x5FA126 and is silently ignored. Handlers also return to 0x5FA126, so only 0x5FA11E is a safe "unknown tag" hook. At 0x5FA11E the stack holds the return address at `[esp+C0h]` (0x5FA213 when called by the `<ProtoAction>` handler, 0x5FA623 for a tactics `<action>`), the proto at `[esp+C4h]`, the action at `[esp+C8h]` and the action's node at `[esp+CCh]`. The shared action tag hook (`actiontags.cpp`) hooks it for `damageOverTime` (`<AttachProtoUnit>`) and `spreadAnyAccuracy` (`<MaxSpread>`, `<SpreadFactor>`). |
| Tactics loader | FUN_005FAA4F, called at 0x5FAD1C by the `<Tactics>` tag handler of a `protoy` unit | `thiscall(actionSet, proto, fileName)`: loads the `.tactics` file into the proto's own action set `[proto+44h]` (created there, 28h B, ctor 0x5F89E2), so every proto that names a file gets its own actions. Each `<action>` goes to FUN_005FA5B3 (`thiscall(actionSet, proto, node, ?)`, `ret 0Ch`): a new 0C4h-byte action with name -1 (0x5FA3EF), appended to `[set+1Ch]`, then parsed by FUN_005F98A0(proto, action, node) at 0x5FA61E (return 0x5FA623). `<Name>` is a child like any other, so `action[1]` is set only when that child is reached; every stock and WoL tactics file has it first. `DBAction` and `Tactic` children are handled in the same loop (`ev_9f259ec8…`, `ev_4013f493…`, `ev_21b51932…`). |

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
| XS reporters | FUN_0043A3A4 `void cdecl(int* log, char* file, int line, char* format, ...)`; FUN_00A5667F `void cdecl(int* log, char* format, ...)` | confirmed (REA `ev_0b3bc25b…`, `ev_3e9963ff…`, callers `ev_71e2e5ad…`, `ev_fb5fcc00…`) | Both format through 0x435D99(buffer, 0x400, format, va_list), and print only when `[log]`, a callback, is set; `[log+14h]` counts. The first prefixes `file(line) : XS: `, the second `XS: `. Callers of the first, as function heads: 0x42CEED, 0x4327A4, 0x432D81, 0x6BF24C, 0xA48EB4, 0xA48F08, 0xA48F61, 0xA4A9F7. The second has 25 known callers, and Ghidra omits the sources of 15 more call references. |
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
| Sync RNG | 0x407CE7 on the object at 0xC66588 | `int __thiscall(rng, int stream, int max)`, `ret 8`: an LCG per stream (12-byte entries at `[rng+4]`), seed = seed × 343FDh + 269EC3h, result `((seed >> 16) & 7FFFh) mod (max + 1)`, so 0..max; also stored at `[0C6663Ch]`. The dodge draws (2, 100) and compares as a float with 0.0 and 15.0 (0xBA1474): 15 values of 101. `dodgeChance` draws (2, 999). Site `SyncRandom`. |
| Dodge shown | 0x6A24FC..0x6A2650 | After the roll: if `[world+8A8h]` and the unit is visible to the local player (0x4818F4), the floating text 0xF9CE in the player's colour `[ebx+0C8h]` and the sound set (0x6A2628); then `mov al,1`, `ret`. Reads ESI, EBX and its locals only. `dodgeChance` enters here for a rule's dodge. Site `DodgeRollPath` (0x6A249C..0x6A2650). |
| Damage type of a hit | byte `[[action+24h]+5]`; at 0x49B023 the caller's EDI | Confirmed in game (traced at 0x49B021): a Pikeman's hit 0, a Musketeer's and an Explorer's 1; `[action+10h]` is 1 for all. The index into the damage type list below. Site `DodgeCaller` (0x49AF98..0x49B02A). |
| Damage type list | `[db+44h]`, count `[db+48h]` | Entries of 10h bytes, the name at `+4` (0x5FFC55 copies it); filled from `damagetypes.xml` (`Hand`, `Ranged`, `Siege` in stock) by FUN_0052D454, called from the database load at 0x526DD0. Confirmed in game: `dodgeChance` resolved `Hand` 0 and `Ranged` 1. Site `DamageTypeLoad`. |
| Play a sound set by name | 0x4AA24C | `__thiscall(game, const float* position, const char* name, void* extra)`, `ret 0Ch`. Calls `[game+950h]`→0x4AA201. The names are sound sets of `Sound\soundsetsy.xml` (found in `SoundXML3.bar`). |
| Critical-hit sound | 0x6A2A73..0x6A2AA8 (damage function, cold chunk) | `push "PowerCriticalStrike"` (0xBD7518) at 0x6A2A9A, played at the attacker `[esp+44h]` = EBX. Reached when the attack's `HitPercentType` is `CriticalAttack` and its roll succeeds (stock: the Chinese monk's HandAttack, `HitPercent` 20). |
| Power name table | `db+2FE4h`, registered at 0x52430E… | Includes `PowerCriticalStrike` (22h), `PowerDivineStrike` (23h), `PowerConvertDisciple` (24h), `PowerEvade` (25h). Role not established. |

**Runtime check (2026-10-28).** A test map (two players, no AI) put an Explorer with
`AbstractDodge` and a `ypMonkJapanese` against four musketeers, with `YPDodge` (tech index 169)
set active by a trigger. With `dodgeAnyUnit AbstractDodge log`, the Explorer dodged 3 and then 5
hits in two runs, the monk 2 and 0. With `dodgeAnyUnit AbstractNoOne log` (a marker no unit
has), the Explorer never dodged and the monk dodged 6 times. A first run whose trigger did not
activate the tech had no dodge at all, monk included: the tech condition holds for both.

## Projectile accuracy and spread (2026-10-28, for WoL request #2; completed 2026-10-30 for `spreadAnyAccuracy`)

Evidence: REA pseudocode `ev_7824a864a13fff8e6d0572f7a502352f6f7d2fb48216ff9d85ec96d84f94eda5`
(the launch fragment Ghidra calls FUN_004995c7) and
`ev_6476290bdc5072fe4d2758d1ac4b4e7b7e0da3592a03ff0a76e9b67e5a7b8b05` (0x4A5B7E, 0x4CEF8C,
0x4A5B02). For `spreadAnyAccuracy` (2026-10-30, bundle
`rea/evidence/age3y-b1a1dab7/spread-bundle.json`): `ev_ddf1e34f…` (FUN_004995C7 again),
`ev_2ec57333…` (the projectile update FUN_0049539B), `ev_6d340e7a…` (FUN_0049BE95),
`ev_741d2ae8…` (FUN_004C4DF8), `ev_75c27083…` (FUN_004A5B02), `ev_43d5ed66…` (FUN_004CB11C),
`ev_4a79e238…` (the `ballisticPrecalcHits` name). `cs` for the instruction sequences
(`spread_dis.txt`, `spread_sitecheck.txt` in the same folder). Hardware read breakpoints on the
action fields while two groups fought on the test bed (`tools/re/trace_writes.py … --rw`,
2026-10-28). In game with `spreadAnyAccuracy log` (2026-10-30).

**The launch.** FUN_004995C7 is a fragment. In it, `[esp+18h]` is the unit action, whose `+4` is the
tactics action (EDI in the block); `[esp+0E8h]` is the shooting unit, `[esp+0ECh]` the target unit
or 0, ESI the new projectile and `[esp+28h]` the impact point. It picks one of four modes and stores
it in `[projectile+20h]`:

| Mode | When | What the projectile does (FUN_0049539B) |
|---|---|---|
| 3, ground shot | The action has `<TargetGround>` (byte `[action+0C0h]`, written at 0x5FCD9E) and `[esp+44h]` < 0 (its meaning not traced): 0x4C4DD9 calls the ground lead FUN_004C4DF8 and stores 3. | It flies to the point and hits no unit in flight. Where it lands, FUN_0049BE95(-1, point) applies the attack: area damage with `DamageArea`, nothing without. Seen in game: Grenadier shots never reached the precalculated block. |
| 1, sure hit | `InstantBallistics` (bit 22): `jne 4A9455h` at 0x499801 stores 1 and jumps to 0x4998A0, past the roll and the offset. | It hits only its target, which takes the attack (FUN_0049BE95(target)). |
| 1 or 2, precalculated | `ballisticPrecalcHits` is set and there is a target unit: the block 0x499807..0x499899. | 1: as above. 2: it lands at the offset point and deals **no damage at all**: FUN_0049539B never calls FUN_0049BE95 for mode 2, it only plays the terrain impact FUN_004CB11C. Seen in game: five Longbowmen whose shots were all turned into misses left five musketeers at full HP, and a unit with `DamageArea` 2.5 did no damage either while its shots were misses. |
| left unset | No target unit, or `ballisticPrecalcHits` off. | The block is skipped (`je 4998A7h` at 0x4997B0 / 0x4997B8) and the flight physics decide (static reading, not tested). |

| What | Where | Notes |
|---|---|---|
| Accuracy field | action `+38h` (float) | Written by the `Accuracy` handler 0x5F8CF0 (default 1.0). ROF is `+34h`. |
| Flags that skip the roll | action flag bytes `[+64h]` | `InstantBallistics` sets bit 22 (`or byte [flags+2],40h`, 0x5F8D2E): a sure hit, accuracy is never read, and the shot never enters the precalculated block. `PerfectAccuracy` sets bit 28 (`or byte [flags+3],10h`, 0x5FCE28): inside the block, `ebx` stays 1 and the roll is skipped. |
| `ballisticPrecalcHits` | cfg var; name at 0xBE8158 (description "Determines if we precalculate whether or not a projectile hits its target"), registered at 0x573E2B through 0x5734E0; ID at `[0xCEFFD4]`, `[0xCEFFD0]` points to it | Read at 0x49979C: `0x4020C3(0xC66500, id)`, "is the var defined". **On by default:** the game's own `Startup\gamey.cfg` (also `game.cfg` and `gamex.cfg`) has the line `ballisticPrecalcHits` under "Ballistics settings". It is off only if a mod's startup cfg drops that line or a user cfg undefines it. |
| Precalculated hit | 0x499807..0x499899, inside the projectile launch | `ebx = 1`; unless bit 28 is set, `ebx = 0x4A5B7E(projectile, accuracy = [edi+38h])` (read at 0x49984E); `[projectile+30h] |= 20h`. Then the target lead 0x4A5B02 (`TrackRating` at `[[action+4Ch]]`); if it fails, 0x6A4BC5 sets `ebx = 2` and jumps to the miss stub 0x4CEF7B. Otherwise `cmp ebx,2 / je 4CEF7Bh` (0x499890) sends a miss there. Then `[projectile+20h] = ebx` at 0x499899. |
| The miss stub | 0x4CEF7B | `lea eax,[esp+28h] / push eax / mov ecx,esi / call 4CEF8Ch / jmp 499899h`. Reached only from 0x499893 and 0x6A4BCA (`cs` scan of every rel8/rel32 branch). |
| The roll | FUN_004A5B7E | `int __thiscall(projectile, float accuracy)`: 1 = hit, 2 = miss (it also writes 2 to `[projectile+20h]` at 0x4CEF6B). `chance = round(accuracy × 100 − 0.5 × d)`, d = 2D distance shooter→target; chance < 1 → miss, > 100 → hit, else uniform 0..100 ≤ chance → hit (RNG 2, `0x4228DF`). So accuracy 1.0 still misses at range, 8 % of the shots at 16 m; in game some accuracy-1 units logged misses. A target whose proto has abstract bit 2 always counts as hit on one path. |
| The lead | FUN_004A5B02 (unit target), FUN_004C4DF8 (ground target) | `bool thiscall(projectile, Vector* point, float* time, float trackRating)`. Both move the point to where the target will be, and set `[projectile+94h]` (the 2D distance to it) and `[projectile+9Ch]`. |
| Projectile | created by 0x4999E3 | `+0` the projectile unit (its `+14h` is the position), `+4` the shooting unit's ID, `+8` the target ID, `+10h` the action, `+20h` the mode above, `+30h` flags, `+70h..+78h` the point it flies to, `+94h` the distance to it, `+0C0h` the launch's `[esp+44h]`. |
| The spread | FUN_004CEF8C, `bool thiscall(projectile, Vector* point)`, `ret 4`; called only from 0x4CEF82 (no other call, jump or pointer to it, `cs`) | It returns 0 without an offset unless the shooting unit `[projectile+4]` still exists and `[projectile+10h]` is set. d is the 2D distance from the projectile unit to the point, or 1.0 (`[0xB856BC]`) without a projectile unit (0x4E2CF7 → 0x4CF00B). `r = d × 0.25` (`fmul [0BA0AECh]` at 0x4CF00B), clamped to 5.0 (`fcomp [0BA0AF8h]`, then 0x4E2CE3 writes 40A00000h). If r > 1e-6 (0x4CF026), x and z each move by `0x422648(rng 0xC66588, stream 2, -r, r)` (0x4CF054, 0x4CF066). **Hardcoded:** 0.25 and 5.0 are the stock tactics' `spreadfactor` and `maxspread` values, but those tags are not read. `spreadAnyAccuracy` replaces 0x4CF00B..0x4CF025 with the action's values and leaves the draws to the stock code. |
| The attack applier | FUN_0049BE95, `void thiscall(projectile, int targetId, Vector* point)` | Without a live target it returns at once unless the mode is 3; then it works at the point. With `DamageArea` (byte `[[action+24h]+6]`) > 0, FUN_004C9D89 damages the units around the point; without area it damages only the live target, through TakeDamage (0x49B3D9). The projectile update calls it with the target for a mode-1 hit and with -1 when a mode-3 shot lands. |
| InstantBallistics branch | 0x4A9455: `mov [esi+20h],1 / jmp 4998A0h`; only branch to it the `jne` at 0x499801 (`cs` scan) | [O] Reached in the launch's frame (no push between 0x499801 and it), so `[esp+18h]`, `[esp+28h]`, `[esp+0E8h]`, `[esp+0ECh]` are those of the table above. Site `SpreadInstantMode` (`spreadAnyAccuracy` hooks it, 2026-11-08). |
| Instant launch | 0x499931 tests `InstantBallistics` again → 0x4A958F: `push -1.0 / lea edx,[esp+2Ch] / push edx / mov ecx,esi / call 4A95A5h / jmp 4999BEh`; FUN_004A95A5 `thiscall(projectile, Vector* point, float)`, `ret 8` | [O] It returns at once without a world, without `[projectile+30h]` bit 0 or without a projectile unit `[projectile+0]`. Else `+64h` = the projectile unit's position, `+70h` = the point (the launch's `[esp+28h]`), `+94h` the distance, `+9Ch` a speed from the unit's vtable `+34h`, `+34h` the velocity, and `[projectile+1Ch]` = 3. [O, in game] A point moved before 0x4998A0 is where the tracer flies and what `[projectile+70h]` holds at the arrival (162 shots compared, 2026-11-08). Site `SpreadInstantLaunch`. |
| Instant arrival | FUN_0049539B: `cmp [esi+1Ch],3 / je 495C59h` (0x49542A); 0x495C59: `fld [esi+0B0h] / fcomp [1.0] / test ah,1 / je 49C151h`; 0x49C151: FUN_0049BE95(`[esi+8]`, a zero vector) | [O] The target ID `[projectile+8]`, whatever the mode. [I] `[esi+0B0h]` is the flight's progress (0 to 1). Site `SpreadInstantArrival`. |
| Applier, in detail | FUN_0049BE95 | [O] No live shooter `[projectile+4]` → the projectile unit stands in (0x4B742B). A live target: EDI = it, the local point = its position. Else (0x4CB80A) EDI = 0 and, unless the mode is 3, return; with mode 3 the local point = the point argument. The area path (0x4CA25A) passes that local point (`lea ecx,[esp+40h]` after 7 pushes, 0x4CA31E) to FUN_004C9D89, with the attacker's ID; without area, TakeDamage on EDI (0x49C087). [O] Callers: 0x495C3D (an in-flight hit, target `[esi+0BCh]`), 0x49C174 (instant arrival), 0x4B943D, 0x4CB83E (mode 3, −1), 0x4CFDC6, 0x4DD6E7, 0x50B144 (mode 3, −1, the projectile unit's position), 0x64AAFA (target `[esi+8]`), and one pointer at 0x617422. Site `SpreadApplierHead` (`spreadAnyAccuracy` hooks the head, 2026-11-08). |
| Area damage's unit filter | FUN_004C9D89, loop from 0x4C9F21 | [O] Units from the query 0x462E95 (which runs 0x462DBA into `[[world+260h]+4ECh]`, the list FUN_004A1C55 uses too); it skips the attacker and units of proto flag 0Ah (0x4C9F70), then tests unit state bit 3Ah and the action's flags. |
| Proto flag 0Ah | `Projectile` (name 0xBC9464; parser 0x5F6779 → `or byte [eax+1],4` at 0x5FEE5A) | [O] Read by the area damage's filter. `spreadAnyAccuracy` skips such units as stray targets. |
| Projectile unit IDs | `[[projectile+0]+10h]` | [O, in game] One per shot, with a generation in the high bits (0x4000D, 0x8000D for slot 0Dh). [I] So an ID does not come back while its shot is in flight. |
| Tags TAD does not parse | — | No string, no handler: `MaxSpread`, `SpreadFactor`, `AccuracyReductionFactor`, `AimBonus`, `UnintentionalDamageMultiplier`, `NumberProjectiles` (case-insensitive search of the exe, ASCII and UTF-16). They survive in tactics files from Age of Mythology. Parsed: `Accuracy`, `PerfectAccuracy`, `InstantBallistics`, `TrackRating`, `NumberBounces`, `Projectile`, `Throw`, `TargetGround`. `spreadAnyAccuracy` reads `MaxSpread` and `SpreadFactor` through the unknown-tag fall-through. |
| Launch join | 0x4998A7, in FUN_004995C7 | [O] Every launch path meets here: the precalculated roll (0x49989C), the InstantBallistics branch (0x4998A0), the TargetGround store (`jmp` at 0x4C4DF3) and the skipped block (`jcc` at 0x4997B0, 0x4997B8); no branch lands in 0x4998A8..0x4998AD (`cs` scan, 2026-11-12). There, `[esp+28h]` and `[esi+20h]` are final; the launch calls after it (0x4A5725 at 0x4999B9, 0x7A8CDF via 0x6A4BE7, the instant 0x4A95A5) all read the point at `[esp+28h]`, and 0x4A5725 writes `+94h` and `+9Ch` itself. `[esp+10h]` is the damage multiplier the code copies to `[projectile+14h]` (0x4998A7) before reusing the slot. Site `DirectionalLaunch` (`directionalAttack`). |
| Terrain height | the world's `[+88h]` object, vtable slot 18h | [O] `bool thiscall(terrain, Vector* point, float* height, 0, 0)`, as the ground lead calls it at 0x4C4E62 (`cs`). `directionalAttack` puts its landing point on the ground with it; confirmed in game (the shots land). |
| Action range array | `[action+18h]`, 16-byte entries | [O] The `MaxRange` handler 0x5F8A3A reads the float (0x59AD61) and calls FUN_005FA709 (`thiscall(action, float)`, `ret 4`) at 0x5F8A51: entry 0 `+8` = the value, and `+0Ch` too while that one is unset. `directionalAttack` redirects that call for `<DirectionalFiringRange>` and reads entry 0 `+8` as the player's copy's `MaxRange`; [O, in game] the Falconet's 26 reads back. The readers of the array by the attack's range test were not traced. |

**Runtime check (2026-10-28).** Musketeers (`InstantBallistics`) fighting: ROF read ~200 times,
accuracy never. Crossbowmen (projectile `Arrow`, no `InstantBallistics`): accuracy read at
0x49984E on every shot, call chain through 0x48F892 / 0x448C6D.

**InstantBallistics in `spreadAnyAccuracy` (2026-11-08).** No REA session: `cs` of the stock exe for the rows
above (InstantBallistics branch to Projectile unit IDs), and in game in WoL with `spreadAnyAccuracy log`. [I] The
instant shot's damage is decided only at its arrival, by FUN_0049BE95 on `[projectile+8]`; moving
`[esp+28h]` at 0x4A9455 changes where the tracer flies and nothing else, which is why the key also rewrites the
applier's arguments.

**Consequence for WoL's shotguns.** WoL's tactics files (`C:\WoL-Test\data\tactics`, 622 files,
counted 2026-10-30) have 647 actions with `maxspread` or `spreadfactor`. 304 of them have
`InstantBallistics` and 122 `TargetGround` (one has both); the other 222 go through the
precalculated roll. The current shotgun files are among those 222:
`wolinfantryrangedescopetero.tactics`, `wolinfantryrangedbacamarteer.tactics`, and the
`VolleyRangedAttack` of `gw_trenchfighter.tactics`. The older `escopetero.tactics` and
`trenchsoldier.tactics` use `InstantBallistics`. In stock TAD each shot is one projectile, which
misses only when the roll fails; a miss is scattered by `min(0.25 × d, 5)` and does no damage.
Their `spreadfactor` and `numberprojectiles` do nothing.

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
| Getter callers | Train 0x9EA413 (FUN_009EA28B), Research 0x9E65F7 (FUN_009E648B), CommandResearch 0x9D58D4 (FUN_009D5843), Maintain 0x6AB23F (cold chunk of FUN_00492F3E) | confirmed (call bytes, vtable slots); in game for Train, Research (2026-10-30) and Maintain | Each is `mov ecx,[esi+10h] / call 9BFE33h` and multiplies the result into its progress. They are slot 3Ch (update) of the action vtables 0xB98388, 0xB98078, 0xB973A8, 0xB97B98. |
| Save / load of `+28h` | 0x7AE73D (FUN_007AE672), 0x7AEEAD (FUN_007AEDDD) | confirmed (the two instructions) | Through 0xA3FEB8 / 0x599121, from the unit save and load. |
| Tech effect case BuildingWorkRate | FUN_008F973F case 5Eh at 0x8FAE7D; the remove twin FUN_008FB01C at 0x8FC16F | 0x8FAE7D confirmed | Computes the new `[playerProto+D0h]` through 0x7F892A and returns; no unit is touched. The Data effect vtable is 0xB9E5A8 (slot 1 parse 0x6205F6, slot 9 apply 0x7F86C0, slot 10 remove 0x7F8705). |
| Stat panel | 0x6F49B1 (`currentUnitBuildingWorkRate`) | read confirmed | Reads the selected unit's `[[unit+5Ch]+D0h]`. |

### Train points (for `liveBuildingWorkRate`, WoL #5, 2026-10-30)

| What | Where | Status | Notes |
|---|---|---|---|
| Proto TrainPoints | `[proto+6Ch]` (float) | confirmed, in game | Tag `<TrainPoints>`; Settler 25. A `type='Data' subtype='TrainPoints'` effect changes the player's copy (a tech ×0.25 read 6.25 there). |
| Train action | factory type 0Dh (0x48D927(0xD)), vtable 0xB98388 | confirmed, in game | `+10h` trainer unit, `+61h` state, `+64h` the batch's points, `+68h` progress (points), `+6Ch` fraction, `+70h`/`+74h` entries (14h B: `+0` proto ID, `+4`, `+8` cost record, `+10h..+12h` flags) and their count. Slot 34h setState 0x9EB491 (case 0Ah spawns every entry), 3Ch update 0x9EA28B, 5Ch save 0x9EA4D7 (`+64h` at 0x9EA539), load 0x9EC131 (default 100.0 at 0x9EC067). The building's action list is `[[unit+58h]+1Ch]`, count `[[unit+58h]+14h]` (read in game). |
| Train command | FUN_009CE2BE | confirmed (pseudocode; in game, the points below) | One new Train action per queued unit or batch: 0x48D927(0xD), the enqueue (0x9CE805), the action-manager add 0x494894. A batch-trained proto puts several entries in one action (0x9CE6E7, 0x9CE849). The other caller of the enqueue is 0x8D60EA (FUN_008D5E09). In game, units queued before a TrainPoints tech kept the old points when they started after it, and units queued after it on the same building got the new ones. |
| Enqueue | FUN_009EAC35, `bool thiscall(action, protoId, count, …)`, `ret 0Ch` | confirmed, in game | Looks up the trainer's player's proto (0x9EAC5F, `call 45311Bh`). For the first entry of an empty action (`cmp [esi+74h],0 / jg`, 0x9EB19F) it stores `[edi+6Ch]` in `[esi+64h]` (0x9EB1B0), or with the trainer's flag 9Eh the base proto's (0x45316E(db, `[edi+8]`), 0x9EB1DB); nothing writes `+64h` again. Sites `TrainPointsProto`, `TrainPointsSet`. |
| Train fraction | 0x9EA1FA..0x9EA23E, `void thiscall(action)` | confirmed | `[+6Ch]` = `[+68h]` / `[+64h]`, clamped to [0, 1]; 1.0 when the points are below 1e-6 (0xC3755C). Only caller: the update, 0x9EA4B3, after `[+68h]` += rate. Site `TrainFrac`. |
| Unit flag 9Eh | `YPForceTrainAtBaseTrainPoints` (name 0xBC94D4, parser 0x5F71E6 → `or byte [eax+13h],40h` at 0x5FE5D4) | confirmed | Tested on the trainer with 0x44D063 (`bool thiscall(unit, flag)` on `[[unit+5Ch]+50h]`). The Train enqueue and the Maintain cycle start then take the database's base proto's TrainPoints, which no tech changes. |
| Maintain cycle start | FUN_009E2829 (Maintain setState), 0x9E28BD..0x9E2A42 | confirmed, in game | Stores the proto ID in `[esi+64h]` (0x9E28C0), the player's proto (0x9E28C7), the count in `[esi+68h]`, then `[esi+6Ch]` = count × `[edi+6Ch]` (0x9E2A05..0x9E2A13), or with flag 9Eh the base proto's `[eax+6Ch]`, not multiplied (0x9E2A3F). Sites `MaintainPointsProto`, `MaintainPointsSet`. |
| Maintain fraction | 0x9E27E4..0x9E2828 | confirmed | `[+74h]` = `[+70h]` / `[+6Ch]`, as the Train fraction (1e-6 at 0xC37468). Only caller 0x6AB264 (inside site `MaintainCycleDone`). Site `MaintainFrac`. |
| Research points | status entry `+18h`; research fraction 0x9E5F19 | confirmed, in game | `[action+70h]` = `[action+6Ch]` / `[entry+18h]` on every tick (0x9E5F37): read live, so a ResearchPoints tech reaches a research in progress (stock: one at 17 of 30 points finished when the tech set 7.5). |
| Console `trainByID` | 0x7DF6AF, registered at 0x540036 with three int parameters | confirmed (code, in game) | The function reads four stack parameters (proto, a byte, unit, player), so a call with the documented three arguments takes the player from beyond them and trained nothing in game. `researchByID` (0x7DF3F9: tech, unit, player) works; `trainInSelected("<Proto>", n)` (0x7DFCCF) works on the selection. |

Evidence (REA, `rea/evidence/age3y-b1a1dab7/workrate5-bundle.json`): the Train update
`ev_c7977d98…`, its setState `ev_8fb3bc79…`, the train command `ev_5484bbdd…`, `trainByID`
`ev_f9685330…`, `researchByID` `ev_f9203e82…`; byte checks `cs` in `workrate5_cs.py` / `.txt` there.
The in-game measurements read the actions from memory once a second (`docs/modding-guide.md`,
"liveBuildingWorkRate").

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
| Tree | ctor 0x94D816, 20h B | confirmed (uses) | `+0` player ID, `+4` array of status entries, `+8` count (`[db+3828h]`), `+10h` dirty byte (1 at creation), `+11h` the LastInLine dirty byte: set by 0x94AE8C when a HomeCity tech changes status, and by the forced update FUN_00852850 (corrected 2026-11-11, [Last in line](#last-in-line-and-the-xs-runtime-2026-11-11-wols-stutters)). |
| Status entry | `[[tree+4]+4·id]` | confirmed | `+0` definition, `+4` pointer to the status bits, `+8` bit count, `+18h` ResearchPoints. Bits: 0 obtainable, 1 active, 2 Volatile, 3 prerequisites met (cache), 5 set by activation, 7 DynamicCost, 18 HomeCity, 21 OrPrereqs. |
| Entry getter | FUN_004804D1 | confirmed | `thiscall(root, playerId, techId)`, `ret 8`: the player's entry, or the template record `[[db+5D9Ch]+0Ch] + 24h·id` when the entry is null. |
| Template records | `[[db+5D9Ch]+0Ch]`, count `[[db+5D9Ch]+10h]` | confirmed, in game | 24h B each, the same layout as an entry; record `+0` is the definition, whose prerequisites are at def+1Ch (byte length def+20h). |
| setDirty | 0x506A41 | confirmed | `thiscall(root, playerId, bool)`, `ret 8`. 10 direct callers (status changes 0x94C433 / 0x94CE86 / 0x94CFFC, age 0x8D506A, home city level 0x66923E, pop cap 0x8D1480, tree creation 0x8D005A, world start 0x8D53AF / 0x8D7F23 / 0x94AC00), all with 1. An inline copy in the pop cap adder FUN_00506A5F covers units with `PopulationCapAddition`. No other unit event sets the byte. |
| Tech name getter | 0x5C400B | confirmed | `thiscall(db, id)` over `[db+3824h]` / `[db+3828h]`. |
| Tech tag table, `<Flag>` | handler FUN_00620BF1 `cdecl(node, record)`, registered at 0x6237E4 (`mov dword ptr [esp+10h], 620BF1h`); flag setter 0x620C2F(record, text); OrPrereqs case 0x62237E | confirmed (`cs`; REA `ev_f5bd19dd…`), in game (`orPrereqsQty`) | The per-tech parser FUN_006201E5 sends each child to the handler of its tag: `<Flag>` and `Status` to the record table (0x620BEF, `jmp eax`), the others (`Prereqs`, `Effects`, …) to the definition one (0x6203A0). Definition = `[[loader+4]] + 34h·id`, `[def+0]` = id; record = `[[loader+4]+0Ch] + 24h·id`, `[record+0]` = def (0x620277..0x6202B1). |
| King of the Hill time | FUN_009F02DD on the victory settings `[world+0A8h]` (DefaultVP.xml, 13Ch B, ctor 0x9F0466, loader 0x9F0B90: `KOTHVictoryTime` +104h, `KOTHVictoryTimePerPlayer` +108h, `AdjustKOTHTotalTimeByTeams` +10Ch, its Factor +110h; also `RelicCaptureTime` +0FCh, `RelicVictoryTimePerPlayer` +100h); only caller 0x948F95 in the team's timer start FUN_00948F32 | confirmed (REA `ev_e218f91f…`, `ev_0a451f55…`, `ev_90128a02…`), in game (`kothTimer`) | `[world+5Ch]` player slots with Gaia, `[world+18Ch]` teams with Gaia's (3 in a 2-player game). The timer: `[team+80h]` end in ms (0x948A1F: now + 1000 × s), `[team+84h]` subtracted. The hill's update 0x4C9BBD takes the King of the Hill path only when byte `[0xCF07BD]` (game setting 27h, 0x709D9C) is set, and the team's player must be in age ≥ 1. |
| Card shipment | FUN_00858299 `thiscall(hc, queue entry*)`, one caller 0x66AEA0 (the queue update); the activation `call 94CF27h` at 0x8584FF, `thiscall(entry, player, unit, 0, &ok, flags)`, `ret 14h`, with ESI = hc and the queue entry at `[esp+24h]` before its pushes (read at 0x85856A; `ev_86fde4e0…`); the used-card list `[hc+260h]` (add-unique 0x444FD3 at 0x85857F) | confirmed (`cs`; REA `ev_b85d9847…`), in game (`shipmentCounts`) | The card's effects run inside the activation. The used-card list holds each card index once, so it does not count a card sent twice. |
| Player Data apply | FUN_008D842B `thiscall(player, a1, a2, subtype, [effect+10h], [effect+14h], amount, relativity)`, `ret 1Ch`; caller 0x7F874A; switch `subtype − 0Ah` (`cmp eax,5Ah / ja 8D878Fh` at 0x8D8438, tables 0x8D93D8 / 0x8D9330); FreeHomeCityUnit = 37h, case 0x8D8C62 → 0x857E77(hc, proto, count, 0, −1, 0, flag) | confirmed (`cs`), in game | In the cases the field is `[esp+2Ch]`, the amount `[esp+34h]`. Exits: failure 0x8D878F, success 0x8D8D23. |
| Player age | `[player+50h]`, cAge1 = 0 (`kbGetAge` 0x881246 → 0x86A9DB) | confirmed (`cs`), in game | `SetAge` `Age1` is the Colonial age: the politicians of Age II use it. |
| Prerequisite list evaluator, OR exit | 0x67C412 | confirmed (`cs`) | `pop edi/esi/ebp / mov al,1 / pop ebx / ret 8`: the first prerequisite met with `or` set. Each prerequisite is asked through 0x509481 → `[[p]+8]` via the thunk `jmp eax` at 0x4C5F02. |

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
| `TransformUnit` effect | vtable 0xB96B60: slot 1 setData 0x622822 (`thiscall(effect, node)`), slot 0Fh apply 0x7FBBAF (`ret 10h`) | confirmed (`cs`), in game | `[effect+0Ch]` fromprotoid, `+10h` toprotoid. Not applied again when a saved game loads, in game. |
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

### Native socket preview (for `nativePreview`, WoL #43, 2026-11-08)

Static reading with REA (Ghidra) and capstone; evidence `rea/evidence/age3y-b1a1dab7/nativepreview-impl-20261108.json`
(`ev_f6b79952…` assembly of FUN_0046188E, `ev_d4287893…` its tech filters, `ev_071a32ee…` the chooser chunk FUN_006460CE,
`ev_1d58b897…` the two rollover builders) and the main session's `nativepreview-20261108.json` (`ev_77fc4050…`); runtime
traces (`trace_exec.py`) and memory reads in WoL. [O] observed, [I] inferred.

| What | Where | Status | Notes |
|---|---|---|---|
| Bottom panel chooser | FUN_00454270 (+ chunks 0x4BC55C, 0x645FE7.., 0x6460CE..0x6464DF) | confirmed, in game | [O] Runs hundreds of times a second (8780 calls in 13 s, traced). `this` = the in-game UI; `[ui+58h]` the command grid (its byte `[+342h]` = 1 stops the grid refresh at 0x4614C4; set through 0x454245 / 0x45447D), `[ui+78h]` and `[ui+1A0h]`, `[ui+1A4h]` (a unit's info panel, `[panel+178h]` = unit ID), `[ui+1A8h]` SocketPanel2, `[ui+1B8h]` the nugget panel; show 0x447F7B, hide 0x448F13 (`thiscall([[0xC66244]+44h], handle)`). Mode `[ui+3CCh]` (0 in the tests). |
| Chooser: Socket | 0x4BC5E6 (`push 4Bh / call 44CAC4h`) → 0x645FE7 | confirmed, in game | [O] A Socket that is not proto `[db+5FD0h]` sets `[esp+15h]` = 1 → the settlement panel. `[esp+16h]` = AbstractNugget (type by name 0xB9F478). A unit no test claims jumps to 0x454354 with `[esp+12h]` = 1 and keeps the grid. |
| Chooser: native socket, mode not 0 | 0x646124 | scoping | [O] `<SubCiv>` (0x4BC54A) and type 4Bh → hide `[ui+78h]`, `[esp+17h]` = 1. Not reached in the tests. |
| Panel update | FUN_004614A2 (vtable slot 20h of the grid gadget, called from 0x460D8E while visible) | confirmed, in game | [O] Calls the refresh 0x46188E unless `[grid+342h]`; afterwards `cmp [sel+0Ch], local` at 0x4615BA, the non-own branch 0x69789E (allies only). |
| Refresh gate | 0x46193E..0x46194D | confirmed, in game | [O] `mov edx,[eax+0Ch] / mov ecx,[0C66234h] / cmp edx,[ecx+3C0h] / jne 4627E8h`; EAX = the selection (0x453B28: `+0Ch` player, `+10h` IDs, `+14h` count). |
| Entries | 0x461BBD | confirmed | [O] `mov ebx,[esi+5Ch] / add ebx,0E8h`; `[esp+8Ch]` keeps it. 0x461BD8 (bigButtonCivs) is 2 instructions later. |
| Collection body | cold chunk 0x4C58AD (from 0x461C39), append 0x4C59F5, next 0x461C3F | confirmed | [O] Kind byte `[esi+eax+2]`; Train 0x6959D1, Tech 0x4C58C2 (0x4C5725 and 0x4C5B17 on the player `[esp+20h]`), Command 0x4C5A50; each needs `[unit+58h]` (the unit `[esp+28h]`). Append: `{index [esp+40h], column, -1, -1}` to 0xCF05FC (0x4C6048), page to 0xCF05F0 (0x444FD3). |
| Layout, tech | 0x461E2C; 0x4620B9 `call 4C6968h` (can research here); 0x462115..0x462136 prerequisites; build-up 0x462172 | confirmed, in game | [O] 0x4C7330 `bool thiscall(techEntry, unit)`, `ret 4`: 1 with no prerequisite. 0x4C5DDA `int thiscall(techEntry, player, unit)`, `ret 8`: -1 when a non-age prerequisite is unmet (skip, 0x46268A), else the age index → `[esp+6Ch]`. Rollover 0x4C737C (reads only `[unit+5Ch]` of the unit). |
| Layout, train | 0x695C7B | scoping | [O] 0x8F7AA5(age) false → disabled, age mark 0x8D6806(protoId); rollover 0x70F25D (no unit). |
| Button join | 0x462317 | confirmed, in game | [O] `[esp+24h]` state (0 enabled, 1 disabled, 2 red, 3), `[esp+6Ch]` age mark (0x4C5574 draws it for state 1), `[esp+1C0h]` click and `[esp+3C0h]` shift-click commands (strings), `[esp+2C0h]` overlay text. The big-button slots (tech flags 27, 36, 37, 39; 0x696652) bypass it. |
| Building on a socket | 0xA01A20 | confirmed, in game | [O] `int thiscall(world, const float* pos, Proto* socketProto)`, `ret 8`: a point query (0x462E95, 256 units) for a unit whose `<SocketUnitType>` matches (0x466C31); its ID or -1. Used by `trPlayerControlsSocket` (0x982203). A built Trading Post counted in game. |
| `<SubCiv>` | `[proto+1D1h]` byte, 0xFF none; handler 0x5FCD00 | confirmed, in game | [O] Civ ID through 0x58E71F. Read by 0x4BC54A. SocketCaribs 62, SocketCree 65 in WoL. |
| Civ age techs | `[civ+50h]` 8-byte entries (first dword the tech ID), count `[civ+54h]` | confirmed, in game | [O] Parsed at 0x52C526 (`<AgeTech>`, string 0xBCF598), stored by 0x52C5F5. Caribs: tech 19 (NativeCarib). Read by 0x4C5725 and 0x4C5B17. |
| Tech effects | NodeData `+24h` array of `BEffect*`, count `+28h` | confirmed, in game | [O] Appended by 0x6204DB. |
| TechStatus effect | vtable 0xB969B0, ctor 0x620B4D, 14h B, setData 0x6211B5 | confirmed, in game | [O] `+0Ch` tech ID, `+10h` status: 0 unobtainable, 1 obtainable, 2 active (0x6210E4). |
| Data effect | vtable 0xB9E5A8, ctor 0x620BAC, 20h B, setData 0x6205F6 | confirmed, in game | [O] `+4` the target unittype ID, `+0Ch` subtype (`Enable` = 10h, registered at 0x524F2B), `+18h` amount, `+1Ch` relativity. NativeCarib's three Enable effects target 421, 347 and 363 (NatBlowgunWarrior). |
| Socket unit | `[unit+58h]` 0, `[unit+88h]` 255, `[proto+E8h]` none | confirmed (memory) | [O] A socket has no action list. |
| Trading Post placement | needs the map's sub-civs | confirmed, in game | [O] On a test map without `rmAllocateSubCivs`/`rmSetSubCiv` a Trading Post ghost snapped to the socket but stayed invalid ("must be built near a Native settlement"); with them it was built and the Cree alliance applied. [I] PLACE checks the socket's native against the game's sub-civs. |

### The price on a tech button (for `researchGrants`, 2026-11-12)

REA (Ghidra) with evidence `rea/evidence/age3y-b1a1dab7/researchgrants-price-20261112.json`, capstone, and the game (WoL).

| What | Where | Status | Notes |
|---|---|---|---|
| Tech rollover builder | FUN_004C737C, `cdecl(BString* text, techEntry*, player*, unit*, a5, ResList* costOverride, char a7, char a8)` | confirmed (REA `ev_8774d6a5…`, in game) | Clears the text (0x443910); the cost: `costOverride` or `[techEntry+10h]` copied by 0x480A73 at 0x4C73FD into a local list (`ev_06317089…`), whose cost line (0x4C8EE5) is left out when the total is at most 1e-6; then lines `\n*  %s` (prerequisite age in red, etc.). Callers (`ev_913c6a4f…`): 0x4622C5 (command panel), 0x703FAF (no player, no unit), 0x9AD7F1 and 0x9B7637 (other research panels, not identified; each builds a `researchByID(%d, %d, %d)` command first). |
| Tech button call | 0x4622B5..0x4622CF in FUN_0046188E | confirmed (`ev_afcebe91…`, in game) | `push 1/1/0/1, edi (unit), ebx (player), esi (tech entry), lea ecx,[esp+30h]; call 4C737Ch; add esp,20h`. |
| Button overlay text | `[esp+2C0h]` in FUN_0046188E, 256-char narrow buffer | confirmed (`ev_9abdeb84…`, in game) | Emptied per button at 0x461DBC (with `[esp+1C0h]` click and `[esp+3C0h]` shift-click commands); at 0x4625E2 its length, and when not empty 0x697233 sets it as the text of the button's overlay gadget (the Buy buttons' `125`). Empty for a stock tech. |
| BString append | 0x443960, `thiscall(BString*, const wchar_t*, int len, int start)`, `ret 0Ch` | confirmed (bytes, in game) | `len` -1: to the end; `start` below 0: 0. The builder appends `</color>` this way. |
| ResList fill | 0x4E2617, `thiscall(ResList*, float)`, `ret 4` | confirmed (bytes) | Every entry set to the value, encoded. |

### Player powers and the ceasefire (WoL #14, 2026-10-30)

A power is cast per player, not per unit: the button of any unit only spends the player's charge of
that power. Evidence: `rea/evidence/age3y-b1a1dab7/ceasefire14-bundle.json` (`ev_87a250ac…` for
FUN_006ED5F6, `ev_3ffa4dd0…` and `ev_b14fb3f1…` for the two strings), capstone listings, and memory
reads in game (`ceasefire14/powers.py`).

| What | Where | Status | Notes |
|---|---|---|---|
| Power type `CeaseFire` | 19h, registered at 0x526D3A (string 0xBD6344) | confirmed | Next to `GoodFortune` (18h) and `stun` (1Ah). Nothing in the exe compares the caster's proto with the Taj Mahal. The only Taj Mahal reads are the proto name `ypTajMahal` into `[db+5FC4h]` (0x5EF2D1), compared at 0x694A5B with other wonder age-up protos (UI), and the tech names `YPWonderIndianTajMahal…`. |
| `<alwaysaddtoplayer>` | powers.xml parser FUN_005F230D, 0x5F385C | confirmed | `or dword ptr [power+6Ch], 8` (0x5F3887). Its only reader is the grant below (0x6ED68D). |
| Grant at game start | FUN_006ED5F6, `bool thiscall(abilityMgr, player*)`, `ret 4` | confirmed (static and in game) | Run once per player from the game start loop (0x6AED32..0x6AED9C, through 0x8D017B). For each ability record: the power is granted when the record has no tech, or its tech is already active (0x94AEF4), or the power has flag 8. Grant = `0x8D43B1(power, rof, now + rof)` and `0x8D75F5(power, 1)`. A record whose tech becomes active later grants nothing, and no tech effect grants it then (`PowerBalloon`, given by HC cards, carries `alwaysaddtoplayer` for this reason). |
| Recharge list | `[player+3F0h]`, count `[player+3F4h]`, 12-byte entries `{power, rof ms, time ms}` | confirmed (memory) | One entry per power ID: a second record of the same power overwrites the ROF, so the last granted record sets the period of every caster (450 s for `ypPowerCeaseFire`, from the Taj Mahal records). After a cast, `time` = cast time + that ROF. |
| Charge list | `[player+3E4h]`, count `[player+3E8h]`, 12-byte entries `{power, charges, recharging}` | confirmed (memory) | Found by 0x8D4306 (`entry* thiscall(player, power)`, `ret 4`). Granted with 1 charge; a cast sets `{0, 1}` until the recharge ends. |
| Use a power | FUN_008D99D1, called from 0x8D9E0B and 0x8D9E6A | partly confirmed | Fails (0x8D9C20) when the player has no charge entry for the power or `charges` ≤ 0 (0x8D9A1D..0x8D9A30). In game the UI then prints string "This ability is not available" and nothing starts. |
| Ceasefire state | the treaty (no-rush) object; `[obj+4]` end time, `[obj+9]` one-minute warning shown, `[obj+11h]` 1 for a ceasefire | partly confirmed | Its update (cold chunk 0x6776A8..) picks "one minute to the end of the Ceasefire" (69388) or string 46616, and "Ceasefire over" (69391) or 46617, from `[obj+11h]`, with the alert `ui\alerts\treatyend.xml`; the timer text is 69387 (0x8C1671). Sharing the treaty object is the likely reason a ceasefire cast in a Treaty game ends the treaty early (inference). |

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
| Snap to socket | FUN_00A036BB (callers 0x96E7A3 cursor ghost, 0x87DB30 AI; in game, a Trading Post plan on an AI-owned socket built nothing and never reached 0x508CC1) | confirmed (0xA0383B..0xA03855) | The only owner test on the placement paths: `mov edx,[esi+44h] / cmp dword [edx],0 / jne`. A socket a player owns is never snapped to; the ghost stays red. |
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
| A proto's tooltip key | FUN_008F8F5E, `bool thiscall(proto, BString* out)`, `ret 4` | confirmed (REA `ev_69a9f5e6…`, in game) | Looks the proto's commands up and writes the key. Bit 2 of `[proto+30h]`: `trainInSelected("X")`, then `tis("X")`, in `BuildAccel` only. Bit 0: `tis("X")` in a list of 37 names written in the code (35 `...Accel`, `BuildAccel`, `MonasteryAccel`), built to 0x8F9696, loop at 0x8F96CA; `tis("X",5)` does not count. |
| Key lookup | FUN_00AB481D, `int thiscall(manager, char* command, char* context, list* out, bool first)`, `ret 10h` | confirmed (REA `ev_ead909a1…`, in game) | FUN_00AB4798 lists the context's keys and commands; a substring test 0x58F8EE picks the command. |
| Tooltip key cache | FUN_007EF89E; getter 0x7F0224; `[db+5D28h]` by `[proto+8]`, built flag `[db+61D8h]` | confirmed (REA `ev_366c6847…`, memory in game) | Built once, on first use, and reset with the keymap at 0x5C11D9. A second cache like it at `[db+5D40h]`, FUN_007EF712: not read. |
| Selection qualification | chunk 0x649FA4 (0x64A016..0x64A05C) | confirmed, in game | Local player's units only. A `<Train>` list and Building → BL = 1 (enters a context); a `<Train>` list and not Building → `mov byte [esp+13h],1` (BuildAccel) at 0x64A034; no `<Train>`: AbstractFirePit or the unit flag `EnterHotkeyContext` (0x44D063(unit, 0A1h)) → BL = 1. Any other unit enters no context. |
| Binding context set | ctor 0x5BC7D3; bit set at 0x5BC9AB | confirmed | 255 bits, set with no bounds check: context IDs must stay below 255. |

### Snare and group movement (for `snareOnlyHitUnit`)

| What | Where | Status | Notes |
|---|---|---|---|
| Snare trigger | FUN_0048FA07 → cold chunk 0x4DD1DE | confirmed | Tactics action flag bit 11 (`<SpeedBoost>`) → 0x4B3E31; bit 12 (`<TargetSpeedBoost>`) → `0x4DD22D(target, 0, 0.65f, -1f, -1f, 0, 2, 3000, -1, -1, 1)` when the target can move. |
| Apply / create a modifier | 0x4DD22D → 0x4B3D9E; init 0x4B3D44 | confirmed, in game | `int __thiscall(unit, stat, float value, -1f, -1f, 0, operation, int ms, -1, -1, exclusive)`, `ret 28h`; −1 without an action manager `[unit+58h]` (0x69FDBD); allocates the modifier record `[[unit+B4h]+C8h]` when missing (0x4AAC67). `damageOverTime`'s `AttachSnare` calls it with the data's factor (site `SnareApply`; a Hussar read 3.38 = 6.75 × 0.5 through slot 34h). Unit action type 2Ch: `[+64h]` stat (0 = velocity), `[+68h]` value, `[+78h]` operation (0 set, 1 add, 2 multiply), `[+88h]` ms; flag 15h when timed, 14h when not; flag 16h = exclusive. Only the snare is both timed and exclusive (`<SpeedBoost>` is timed, not exclusive; the auras pass 0 ms). Auras (FUN_009D033E), powers (0x8EE18E) and a second applier (0x9D7696) use the same call (scoping; "Building work rate auras"). |
| Action lists | `[actionManager+14h]`, `{count +0, data +8}`; children at `[action+40h]`; type byte `[+60h]`; flag bitset `{[+30h] bytes, [+34h] count}` | confirmed | Walked depth first, parent first, by the collector 0x49F1A0 / 0x49F397 / 0x49F34B. `src/modifiers.h` repeats that walk, read-only, for `snareOnlyHitUnit` and `buildingWorkRateAuras`. |
| Velocity recompute | FUN_0049F1BA, the one call of 0x4B3C48 at 0x49F26A | confirmed (`cs`, in game) | The list 0xCF0718 ({data, count, capacity}) is built by the collector call 0x49F251 for each recompute, oldest modifier first, so stock's first exclusive snare is the oldest (in game: a 0.8 first hides a 0.3 after it, speed 3.20). `snareValues strongest` swaps the slowest into the first snare's place there. Add 0x48D975: appends unless its second argument is set. |
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
| Out of scope | 0x4CF222, 0x7E6905 / 0x7E803F, 0x82E45B, 0x492FD6 | scoping | Code that still looks for the `TownCenter` proto itself: the engine AI's automatic bases (FUN_004CF222), the age-up picker `uiPoliticianUI` (since 2026-11-13 widened by `ageUpBuildings`), the start camera and the `Maintain` spawn gate. The water shipment point does not belong here: 0x855D71 reads `[hc+190h]`, then `[db+6028h]`, `HomeCityWaterSpawnFlag` (0x855E0B), and never `[db+5E08h]`. The AI scripts (XS) also expect a Town Center: in game a tagged AI got its Market and settlers, then stayed idle. |

### Age-up dialog (for `ageUpBuildings`, WoL #56 and #62, 2026-11-13)

capstone and REA (Ghidra, bundle `rea/evidence/age3y-b1a1dab7/tier5-56-62-20261113.json`), and the game (WoL). [O]
observed, [I] inferred.

| What | Where | Status | Notes |
|---|---|---|---|
| `uiPoliticianUI(unit, player, revolt)` | 0x7E686E (registered at 0x534456) | confirmed, in game | [O] Player = local player; unit by ID 0x44CC6D owned by it; player's proto 0x45311B; isAsianCiv(player, true) 0x454ED7 → type 16h test at 0x7E6919, else `[db+5E08h]` = `[proto+4]` at 0x7E6905; the dialog from `[[[0xC67310]+920h]+234h]` (0x40439A, 0x75CFF4); 0x818E8D(dlg, unit, player) stores `[dlg+140h]` unit ID, `[dlg+13Ch]` player; `[dlg+144h]` = revolt; then the builder (vtable `+54h`). The earlier "native civ" reading of 0x454ED7 was wrong: it is isAsianCiv. |
| `uiPoliticianUIInSelected` | 0x7E7EC1 (registered at 0x5344E7) | confirmed (`cs`) | [O] The first selected unit of the player that passes the same tests (0x7E8025..0x7E8057), then 0x7E686E with revolt = not `AgeUpgrade` (flag 4). |
| Politician list builders | FUN_0081A2B8 (European; revolution banners), FUN_00818EE5 | confirmed, in game | [O] Walk the player's tech statuses (`[world+7Ch]` → 0x4C5394(player)); keep those of the next age (0x94C7E3 = `[player+50h]`+1), or flag 1Ch for a revolt, that 0x4C6968(status, unit) accepts, up to 5 (`cmp [dlg+26Ch],5` at 0x8191FE and 0x81A82A). Per entry: tech ID `[dlg+270h+4n]`, cost `[dlg+284h+8n]`, a byte `[dlg+2ACh+n]`. |
| Can research (dialog) | 0x4C6968, `bool thiscall(techStatus, unit)`, `ret 4` | confirmed (REA `ev_90be3ff9…`) | [O] Status and flag checks (0x4C5D86, 0x480476, 0x481A26, 0x4C6AE1, flag 23h, the unit proto's flag 8Ch); not whether the unit's proto lists the tech. Tech ID `[[status]]` (0x58EA03). |
| Dialog places | 0x818C5B..0x818DBD in FUN_0081892B | confirmed (`cs`, REA `ev_c919cd4e…`), in game | [O] Binds, for n = 0..4 (`cmp edi,5` at 0x818DBA), `PoliticianDlg-Politician%d` → `[dlg+198h+4n]`, `PoliticianButton%d` → +1ACh, `Poli%dPortrait` → +1C0h, `PoliticianHilightPositive%d` → +1D4h, `Poli%dName` → +1E8h, `Poli%dCost` → +1FCh, `Poli%dDescription` → +210h (gadget handles), and `OrigPositionPolitician0` → +224h, `Size1..5Politicians` → +228h..+238h (0x818A80..0x818BBB). A name the layout lacks resolves to no gadget. The European builder FUN_0081A2B8 (REA `ev_3a5f7096…`, virtual at 0xB8BD3C) null-checks the name gadget once (0x81A527) and then dereferences it at 0x81A80C (age-up) and 0x81A63C (revolution): the crash with a 5th politician and WoL's 4-place `uipoliticianEuropeandlg.xml` (Windows log: offset 0x41A80C). Fixed by `politicianPlacesFix` (0x81A45A). |
| UI gadget lookup | 0x40423C, `gadget* thiscall(manager, handle, type)`, `ret 8` | confirmed (`cs`, REA `ev_7c3b79e8…`) | [O] Manager `[[0xC66244]+44h]`; null for the invalid handle `[0xC672C0]`, an index out of range or a type the gadget's virtual +CCh refuses; an empty or stale slot goes to 0x560B03 (not read, [I] null); no reference taken. 0x404296 (type 0) and 0x44900A (type 10h, text) wrap it and take a reference (`[gadget+5Ch]`+1), released by 0x40431B. |
| European dialog sizing | 0x81A069..0x81A099 | confirmed (`cs`), in game | [O] One politician → `Size1` (+228h), two → `Size2`, three → `Size3`, any other count → `Size4` (+234h): five politicians use `Size4` too, so it must keep the full width. |
| Command panel slots | `[ui+2F0h]`..`[ui+2FCh]`, bound at 0x996940..0x9969C7 | confirmed (`cs`), in game | [O] By name: `commandpanel2nativepanel-Button0` (slot 0), `commandpanel2-bigbutton2`, `commandpanel2-bigbutton3`, `commandpanel2-bighugebutton` (slot 3, tech flag 27h `YPUseBigHugeButton`). In WoL's `uicommandpanelnew*.xml` the big huge button is 212 × 108 at 804, 633 (1024 scale), over the grid: while it shows, the grid's buttons under it are hidden. Moved out of `commandpanel2-main` (a child of `commandpanel2`) at 804 486 1016 594 it shows above the panel and takes clicks; left inside `commandpanel2-main` at 804 519 1016 627 it showed but a click went to the map (2026-11-13). |

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
| Hitpoints rescale | 0xA0036E | confirmed (`cs`, in game with `Percent` and `BasePercent`) | Over the player's units of the proto: a built unit (0x44DDB4) gets HP + new max - old max, an unbuilt one HP x new / old, at least 1.0, written through 0x4820A1. So a unit at InitialHitpoints stays at it after a Hitpoints tech. |
| Ratio-preserving rescale | 0x9C738B | confirmed (head) | HP = ratio × (override or `[proto+98h]`) through 0x4820A1; used after the modifier recompute saves the ratio (0x49F1DB, scoping). |
| Floating HP bar fill | bar chunk 0x45FAA2..0x45FADC of the unit visual update | confirmed | `mov ecx,esi`; under construction (`[esp+15h]`) `call 9C0690h` at 0x6A1431, else `call 45F295h` at 0x45FAAF; `fstp [esp+10h]`; clamp < 0 → 0 (0x6A143B), > 1 → 1.0 (0x6A1448). Entries 0x45F790, 0x45F79B, 0x511D3A, 0x511D7B, 0x511D88 (scoping). Site `OverhealBarRatio`. |
| HP bar queue and renderer | FUN_0045FB71 (only caller 0x45FB67), `[world+8D0h]` / count `+8D4h`; renderer FUN_0045C4AF | confirmed, in game | Queue: `thiscall(world, pos*, scale, fill, player, colour byte)`, `ret 14h`; grows the array through 0x408308 (no fixed cap); 28-byte records: +0 position, +0Ch scale, +10h fill, +14h player, +18h colour byte. Renderer (ECX = world; REA `ev_0886c3a2…`): locks count × 6 vertices of 24h bytes through 0x40A6A2 (the device's dynamic vertex buffer `[[0C66044h]+660h]`, 2 MB in game; a request above its size `[vb+4]` returns null at 0x40A689: no bar that frame); render states 7 and 14 set to 0 and restored (0x4203AB; depth test and writes, inferred); shader `defaultcolored` (0xC38364) and texture `ui\hitpoint_bars\hpbar` (UTF-16 0xC38334, loaded once, 0x6AD775). Colour: palette 0x801542(byte)+8 when byte ≠ FFh and `[world+33Ch]`, else `[player+0C8h]`, else white. Quad: hw = scale/2, hh = scale × 0.0625 (0xB9A93C) along the camera's right `[[game+148h]+28h]` and up `+1Ch`; vertices +0 position, +0Ch constant 0xC66544, +18h colour, +1Ch u, +20h v; v0, v2, v3 left with u = 0.5 + fill/2, v1, v4, v5 right with u = fill/2. One draw call 0x45F96D; the count reset when `[world+8D8h]` ≥ 0. `hpbar.ddt` (art2.bar, 64 × 8): left half black, right half a white-grey gradient tinted by the vertex colour, so the floating bar is the player's colour. Hooks of `overhealHitpointBars segment`: 0x45FB6C, 0x45C4B9, 0x45CB72. |
| Floating HP bar position | bar chunk 0x45FAE2..0x45FB3F, cold 0x460633..0x46067B | confirmed (REA `ev_6588c8c3…`), in game | With a visual (`[unit+60h]`): v = `[0C66550h..58h]` at `[esp+2Ch]`, `call 45F22Dh` (ECX = unit; `[[0C6DF88h]]` the tag ID, inferred HITPOINTBAR, 0, &v, 0, 0); `test al,al / jz 460633h` at 0x45FB24 (hooked by `steadyHitpointBars`); 0x406BDB(&v, &out) through the unit's matrix `[esp+74h]` to `[esp+18h]`. Without the tag: the unit's position `[[esp+48h]]`, y + (`[0x4605C1(unit, &tmp)+4]` + `[[unit+0B4h]+24h]`) x `[unit+0A8h]` + 1.0 (0xB856BC), then 0x45FB3F. Sites `SteadyBarBone`, `SteadyBarFallback`. |
| Tag position in model space | FUN_0045F22D | confirmed (REA `ev_4c8ac724…`) | `bool thiscall(unit, tag, byte, vec3* out, byte world, int)`, `ret 14h`: AL = 0 without `[unit+60h]` or the tag; with `world` = 1 the position goes through a matrix of `[unit+20h]`, `+2Ch`, `+38h` (0x406C35) and `[unit+14h..1Ch]` (0x4843DA). Site `BoneLocalPosition`. |
| Visual tag lookup | 0x45F1DC; 0x45F01C; 0x45F072 | confirmed (REA `ev_ad0812a3…`, `ev_8d8ed37e…`, `ev_c9756d1d…`) | 0x45F1DC `thiscall(visual, tag, byte, vec3*, int)`, `ret 10h`: the animation file of the current animation, 0x45F01C(`[[visual+18h]+10h]`) = `[[[0C66240h]+0C13Ch]+[[visual]+54h][index]*4]` (count `[[visual]+58h]`); then 0x45F072(file, `[visual+8]` the clock, tag, byte, out), `ret 10h`: the tag's index in `[file+8]` (0x407405), its track `[file+34h]` (12-byte keys), interpolated between two keys over the duration `[file+58h]`; duration 0: the first key. A trace in game: a Hussar's idle file has the tag (model y 4.07..4.15), its gallop none. |
| Selection group add | FUN_004C4FB5 (only caller 0x460C41) | confirmed | `bool __thiscall(group, unitId)`, `ret 4`. Running average of 0x45F295 at `[group+1Ch]`, count `[group+14h]`: `fild [esi+14h] / fmul [esi+1Ch]`, then `call 45F295h` (0x4C5014), `fadd [esi+1Ch]`, `fidiv [esi+14h]`. Site `OverhealGroupRatio`. |
| Group health readers | 0x4C82EA; 0x69AA75 | confirmed, in game | The panel bar: `[group+1Ch]` against 0.33 (0xBA1F80) and 0.66 (0xBA1F78), green `[panel+310h]` at ≥ 0.66, yellow `+314h`, red `+318h`; fill through 0x590772 (clamps to [0, 1]), then shown through 0x447F7B (`gadgetReal`) with `[panel+2E4h]`, `+2E8h`, `+2ECh`, `+31Ch`; the tail at 0x4C83DF (sites `OverhealPortraitTail`, `OverhealPortraitColours`). "Group Health": `[group+1Ch]` × 100.0 (0xB9A828), `L"%0.0f%%"` (0xC36828). The three colours are three gadgets of `uiunitselection.xml`, looked up by name at panel creation (0x9BAEE5, site `HealthBarGadgets`); `overhealHitpointBars segment` shows the overheal on the green one: it fills it short and changes the texture of its background drawable `[bar+140h]` (vtable +7Ch, as 0x5CAF02 does). HP text colour: the UI markup `<color=r, g, b>…</color>` (0xBA1E44 / 0xBA1E30, 0xBA2538); the stat row's gadget draws it (seen in game); the `%d/%d` (0xBA2054) and `%d/%d (%d+%d)` (0xC34A54) formats go through swprintf 0x444EFB. |
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
| Minimized interface | stat panel fill 0x4D721B..0x4D7261; unit panel 0x69922D..0x699456 | confirmed, in game | Profile option 49h `optionminimizedui` on: the stat panel fill returns at 0x4D7261 (`je 4D81A1h`). The unit panel (entered from 0x4911D1, `[esp+50h]` = panel, `[esp+54h]` = unit) then writes the AutoGather rate itself, in `[panel+33Ch]` `unitResourceRateLabel` and `[panel+340h]` `unitResourceRateValue` (bound at 0x9BB0D4, 0x9BB101). Only the `uiunitselectionmin*.xml` files have these gadgets. `showGatherRate` hooks the join point 0x699456. |
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

### Action rates (for `workRateByAbstractType`, WoL #11, 2026-11-04)

| What | Where | Status | Notes |
|---|---|---|---|
| Rate list | `[action+0Ch]`, count `[action+10h]`, entries of 0Ch B | confirmed (`cs`, in game) | `+0` unittype ID (proto or abstract), `+4` float rate, `+8` −1 when added by the setter. |
| Rate lookup | 0x487C45, `float thiscall(action, target unit)`, `ret 4` | confirmed (`cs`) | The entry of `[[target+5Ch]+8]` returns at once (0x67C93A); else the first entry whose type the target carries (0x44D7FA); none: 0. Called by the gather tick (0x4ECEDD, 0x4ECFD1) and the heal tick. |
| Rate getter / setter | 0x49EBB3 `float thiscall(action, key)`, `ret 4`; 0x5FA2FC `thiscall(action, key, float)`, `ret 8` | confirmed (`cs`, in game) | Exact key only. The getter returns 0 for no entry; the setter adds an entry when the rate is above 1e-6. |
| Action by ID | 0x48D22E, `thiscall(action set [proto+44h], id)` | confirmed (`cs`) | Returns 0 for none. |
| WorkRate effect | applyData case 3, 0x8F987C; unapplyData 0x8FB11A | confirmed (`cs`, in game) | Subtype 3 (registered at 0x524D38). Frame in applyData: action `[esp+20h]`, key `[esp+24h]`, amount `[esp+28h]`, relativity `[esp+2Ch]`, EDI target proto, ESI base proto, EBP 0. In unapplyData −4 each, ESI and EDI swapped. |
| Effect removal | FUN_0094DCB2 (a tech's effects, every entry) → FUN_007F8168 → vtable +28h | confirmed (`cs`), in game | Two callers: the TechStatus effect's general unapply 0x7F8D8E, and 0x8EA9FA. `trTechSetStatus` does not remove effects. At a scenario's start `Age0Egyptian`'s `WorkRate` on `All` (×0.8) is applied and removed for each player. |

### Garrison scaling (for `autoGatherScaleByContained`, WoL #25, 2026-11-04)

| What | Where | Status | Notes |
|---|---|---|---|
| ActiveIfContainsUnits / ScaleByContainedUnits | parser 0x5F9A7B / 0x5F9ABB; bits 17 / 18 of the flag bytes, set at 0x5FEDD3 / 0x5FEE1A | confirmed (`cs`) | Read through `[tacticsAction+64h]`, bit count `[+68h]`. |
| DamageFactorCap | `[tacticsAction+48h]`, set at 0x5FEDF4 | confirmed (`cs`) | |
| Attack multiplier | 0x4996C7, 0x6A4B83..0x6A4B91, 0x4996E8..0x49970A | confirmed (`cs`) | `fild [unit+74h]`, then the cap when above the cap and the cap is above 0. |
| Contained count | `[unit+74h]` | confirmed, in game | 2, 4 and 6 units inside gave those factors. Not to be confused with the worker array `[unit+98h]`. |
| AutoGather rate getter | 0x49EBE4, `float thiscall(action, int resource)`, `ret 4` | confirmed (`cs`, in game) | `[action+4]` tactics action, `[action+10h]` unit. Five callers: 0x48D16E (the update, × elapsed), 0x6992BD and 0x69B005 (panels), 0x69D232, 0x9CFE1E. Adds the rate of units on a shrine (`AbstractShrine`, 0x58) to its result. |

**Rate of fire (for `containedUnitsROF`, WoL #25, 2026-11-08).** Evidence: `cs` on the stock exe (no REA: another session
owned it), hardware read breakpoints on a Blockhouse's ROF `[tacticsAction+34h]` while it fought (`trace_writes.py --rw`), an
execute trace of 0x48F8A0, and the action manager's timer polled from memory, in WoL (`C:\AoE3-UHC-WoLReal3`).

| What | Where | Status | Notes |
|---|---|---|---|
| ScaleByContainedUnits handler | 0x5FEDFC (reached by `je 5FEDFCh` at 0x5F9AED) | confirmed (`cs`, in game) | `[esp+10h]` = EBX (0, the compare call's third argument), then 0x59B526(node, &out): the text through 0x402733 (BString → `char*`) and `sscanf("%d")` (0x59A71D, format 0xBA282C); `cmp [esp+10h],1` → `or byte [eax+2],4`, else `and byte [eax+2],0FBh` (0x5FE713). **[O]** An empty tag or a non-number leaves 0, so it clears bit 18; only the text `1` sets it. EBP = the action, EDI = the tag's node; same frame as 0x5FA11E (`[esp+0C0h]` return address, `[esp+0C4h]` proto). No attribute is read. |
| Attack unit actions | vtable 0xB96278 for factory types 4 (`HandAttack`), 0Ah, 0Fh (`RangedAttack`), 28h | confirmed (memory) | One class for melee and ranged. `[ua+4]` tactics action, `[ua+10h]` unit, `[ua+68h]` shots so far, `[ua+6Ch]` an override object (its `+28h` an ROF in ms, its `+8` a count), `[ua+78h]` the time the attack began. The tactics action is shared by every unit of the player's proto; a unit's attack is a new unit action each time (the list `[[unit+58h]+14h]` holds another). |
| Attack begins | 0x4A1185..0x4A1234 | confirmed (`cs`, in game: one read per attack) | `[esi+78h]` = now (0x4A1175); EBX = ROF `[[esi+4]+34h]` (0x4A1189), replaced by `[[esi+6Ch]+28h]` when that is above 0 (cold 0x6A79C3); `[unit+0B0h]` = (anim length × 1000 + …) / ROF (0x4A1234), the attack animation's rate. |
| Shot | 0x48F7F0..0x48F8E9, in the attack step (frame 2B0h) | confirmed (`cs`, in game) | Tactics flag bit 9 picks 0x4DCFE2 (no projectile, `je 4DD167h` at 0x48F832) or the launch 0x499422 (0x48F88D); both reach 0x48F892. `[ebp+68h]` += 1 (0x48F8A0); without an override, ESI = ROF (0x48F8B5); minus the time since `[ebp+78h]` when that is smaller (0x48F8D4..0x48F8E0); then 0x48FA69(`[unit+58h]`, ESI). **[O]** Melee (a Pikeman's `MeleeHandAttack`) and ranged (a Blockhouse) both ran 0x48F8B5. |
| Projectile launch | 0x499422, `bool thiscall(unitAction, unit, target, [[frame+2CCh]+28h], byte, [ua+6Ch])`, `ret 14h` | confirmed (`cs`, in game) | Five arguments: the attack step pushes `[ebp+6Ch]` at 0x48F83B, then the byte of tactics flag 18h, `[[esp+2CCh]+28h]`, the target EDI and the unit `[ebp+10h]` (0x48F87D..0x48F88A); returns at 0x4999DA / 0x6A4C65 (`ret 14h`). The broadside step passes `[esi+94h]`, 0, 0, EBX, `[esi+10h]` (0x4CEA3A). **[O]** Called 4 times in a row for one shot (`numberOfShots projectiles`, 2026-11-12): 4 tracers, 4 hits. |
| Alt state of the bar decision | FUN_00451F9D: `[[[0C66244h]+74h]+2Ch]` vtable +34h(2) through `call 473E37h` (a `jmp eax`) at 0x452EB3, kept in BL (0x452EBD) | confirmed (REA `ev_d87e8471…`, in game) | 0 is Shift and 1 Ctrl (0x436434, the selection's extend / toggle). With profile option 57h (`[esp+28h]`) and BL, every unit with proto flag 5 queues its HP bar (0x511D80). **[O]** A posted `WM_KEYDOWN` of `VK_MENU` sets it (2026-11-12). |
| Attack wait | 0x48FA69, `thiscall(actionManager, int ms)`, `ret 4` | confirmed (`cs`, in game) | `[mgr+0B8h]` = now `[world+108h]`, `[mgr+0BCh]` = ms × the unit's ROF modifier (`[[[unit+0B4h]+0C8h]+34h]`, 1.0 without a record; rounded down). `rofFix` keeps orders from clearing `[+0B8h]`. Seven callers, all in the attack class: 0x48A80C, 0x48A8A3, 0x48E9F0 (the override ROF), 0x48A833, 0x48A9AC, 0x48EA1E (tactics ROF after an attack that did not fire; tactics flag bit 15 decides, 0x4A8539 / 0x4A8680 / 0x4B338F), 0x48F8E9 (after a shot). **[O]** In game only 0x4A1189 and 0x48F8B5 read the ROF while a Blockhouse fought; the three others were not seen. |
| ActiveIfContainsUnits readers | 0x487F7A (target search: `[unit+74h]` ≤ 0 skips the action, 0x4A19AB), 0x4B2CC3 (cold 0x68D8B6), 0x947B3B, 0x9E3A01 | confirmed (`cs`; in game: a Blockhouse with bit 17 and nobody inside did not attack, a Pikeman neither) | |
| Stock damage form with nobody inside | 0x4996C7 | confirmed in game | The attack still fires every ROF (20 a minute for a 3 s Blockhouse) and the factor 0 makes its damage 0. |

### Resource auras (for `unitResourceAuras`, WoL #26, 2026-11-04)

| What | Where | Status | Notes |
|---|---|---|---|
| Aura model | `[protoAction+A4h]` model, -1 none (tag `ModelAttachment`, 0x5FC90C); `[+A8h]` bone (`ModelAttachmentBone`, 0x5FC8EE) | confirmed, in game | Read at 0x9D053F. The object: 0x405E83, `thiscall(table [0xC66240], model)`. |
| Stock aura update, its model | in FUN_009D033E, ESI = the action: those in range 0x9D053C..0x9D059C, the has call at 0x9D0584; new targets 0x9D0640..0x9D06DC, the hang call at 0x9D06DC; leaving 0x9D04B5, 0x9C2885 | confirmed, in game | Model `[protoAction+A4h]`, bone `+A8h`, stat byte `+B8h`. |
| Gather action | vtable 0xB97880; state `[+61h]` = 5 while gathering; target ID `[+14h]`; resource `[+70h]`; the unit's current action `[[unit+58h]+24h]` | confirmed, in game | |
| Model on a unit | has 0x9C28DE, `bool thiscall(unit, model)`, `ret 4`; hang 0x9C04F3, `bool thiscall(unit, object, bone, byte)`, `ret 0Ch`; take off 0x9C2885, `thiscall(unit, model)`, `ret 4` | confirmed, in game | On the visual `[unit+60h]`. A model not in the game hangs with true and is never found. |
| Aura update | FUN_009D033E, `void thiscall(action)`, plain `ret` (0x9D06FF) | confirmed (`cs`, in game) | No direct caller: a vtable slot. In WoL's Sawmill it runs about every 3 s (a take of 0.05/s measured 0.14–0.16). |
| Aura scan | 0x9CFF9A, `thiscall(action, IdList*)`, `ret 4` | confirmed (`cs`, in game) | Range `[action+24h]` from the unit's position (0x4A1C55), else a contained-unit path. |
| Aura filter | 0x9D0238, `bool thiscall(action, target)`, `ret 4` | confirmed (`cs`) | Not the owner; the same player, or allies with tactic flag bit 32; alive (vtable +A4h), not dead (0x4802C6), built; `[tactics+9Ch]` abstract index, `[tactics+9Eh]` proto ID; neither: abstract 10h. |
| Inventory add | 0x49A5E6, `bool thiscall(inventory, resource, float)`, `ret 8` | confirmed (`cs`, in game) | The gather tick passes −amount / the action's ratio (0x4ED124). |
| Handicap | `[player+37Ch]` float, read by `kbGetPlayerHandicap` 0x883B44, written by `kbSetPlayerHandicap` 0x883B6C | confirmed (`cs`, in game) | Multiplies the gather pay 0x4ED13A (after the take 0x4ED124), the AutoGather rate 0x49EDF2 and the global trickle 0x4E0CEF. `GamePlayer1Handicap` 100 in the profile with `GameHandicapMode` 1 gave 2.0, and 0 gave 1.0 (in game; the conversion was not read). `aiWoLMain.xs` multiplies an AI's by 0.65 at Moderate. |
| Gather payment | 0x49A98A(player, resource, amount, 0) | confirmed (`cs`, in game) | After `× [player+37Ch]`. Zero when `[player+338h]` is set. Resource 5 also calls 0x9C02C0. |
| Endless resource | proto flag 24h, tested at 0x4ED062 | confirmed (`cs`) | The tick skips the drain and 0x482152. |

### Resource debt (for `resourceDebt`, WoL #24, 2026-11-04)

| What | Where | Status | Notes |
|---|---|---|---|
| Add resource | 0x49A98A, `bool thiscall(player, res, float, bool)`, `ret 0Ch` | confirmed (`cs`, in game) | Sum compared with 1e-6 (0xB9FD78) at 0x49A9BF; below: 0x679A0E writes 0. Shared resources `[world+6912h]`, 0x67993B: divides the amount among the player and those with relation 0 or 1 in `[player+1D4h]`, and clamps each sum at 0x6799D4 before its set. |
| Set resource | 0x49A8C5, `thiscall(player, res, float, bool)`, `ret 0Ch` | confirmed (`cs`, in game) | Below 1e-6: 0x6798F4 writes 0. Stores through 0x58EF83 into `[player+230h]`; `[player+238h]` a per-resource cap; the delta goes to `[player+240h]`. |
| Stockpile read | 0x44EFFF, `float thiscall(array, res)`, `ret 4` on `[player+230h]` | confirmed (`cs`, in game) | Also the caps `+238h` and the totals `+240h`. |
| Global trickle | Caller 0x4E0CF9 of the add, in the player's 2 s update | confirmed (`cs`, in game: log `from 0x004E0CFE`) | Elapsed ms × 0.001 × rate × `[player+37Ch]`; `[player+26Ch]` next update, `[player+270h]` last one. |
| Callers of the add | 33 sites | classified 2026-11-05 (`cs`) | **May go below 0 with the key:** 0x4E0CF9 global trickle, 0x4C3798 AutoGather, 0x4ED1EE gather tick. **Stop at the floor:** 0x9886B8 `trPlayerGrantResources` (in game), 0x8D6B9B array add (costs and refunds pass here; called on load with 0, in game), 0x4ED690 gather with a bool, 0x6A7E85 AutoGather of the state 3 branch, positive only, 0x7CD38D, 0x7D8920 (negated), 0x7D894C, 0x852AD5, 0x8F00E1, 0x8F0102, 0x69419C, 0x9702DA, 0x9E6BAA (negated), 0x9E6D94. **Not listed resources:** the rest pass resource 5 or 6 (XP, shipments): 0x49BE40, 0x4B4587, 0x68EA46, 0x6A226C, 0x8C82C8, 0x8C91AC, 0x9EBDFC. 0x7B4FFF..0x7B509C are the cheats, +10000. |
| Callers of the set | 22 sites | classified 2026-11-05 (`cs`) | 0x49A9DD and 0x6799E9 are the add's. 0x8D8745: Data subtype Resource, the tech path (in game, log `from 0x008D874A`). 0x8D6B53: array set. 0x9068C5: XS, by name. 0x9B1DB4..0x9B1E31: the three stockpiles. All but the add's go through the floor. |
| Personality and civ | `gameplayer2aipersonality` in the profile; `<forcedciv>` of `AI4\*.personality` | in game | The personality wins over `gameplayer2civ`: 17 (Germans) in the profile gave a Mapuche AI. `tools/ai_personality.py` leaves one. |

### Building work rate auras (for `buildingWorkRateAuras`)

The getter 0x9BFE33 and its four callers are in "Building work rate"; the modifier action, its
creation 0x4DD22D, the action lists, the collector and the sum 0x4B3C7D in "Snare and group
movement".

| What | Where | Status | Notes |
|---|---|---|---|
| ModifyType name → stat | FUN_005F5645, `int cdecl(BString*)` | tail and callers confirmed; name table scoping | Compares through 0x443C10 (case ignored); Speed 0, MaxHP 1, Damage 2, MovingDamage 3, Bounty 4, SiegeDamage 5, UnitDamage 6, LOS 7, Armor 8, GatherRate 0Bh, AbilityROF 0Ch, ROF 0Dh, AutoGatherRate 0Eh, else −1 (the cold returns of 3, 7, 8, 0Ch and 0Dh at 0x67D730..0x67D752 confirmed). Tail 0x5FE6C7..0x5FE6E1: `neg eax / sbb eax,eax / and al,0F1h / pop esi / add eax,0Eh / ret` (site `ModifyTypeNameTail`). ESI = the name throughout. With `buildingWorkRateAuras`, `BuildingWorkRate` → 40h (in game). |
| Stat sum | FUN_004B3C7D, `bool cdecl(float* value, list, int stat)` | confirmed (static, 2026-11-11; the add path in game) | Walks the unit's type-2Ch modifiers in list order (oldest first): `[+78h]` 0 sets `[+68h]`, 1 adds it, 2 multiplies; stops after the first with flag 16h. Callers: 0x4B3C48 Speed from `[proto+80h]`, 0x4B3A0E MaxHP from `[proto+98h]`; 0x4B3A41 (2), 0x4B3A6D (3), 0x4B3AF1 (4), 0x4B3A99 (5), 0x4B3AC5 (6), 0x4B3B1D (7), 0x4B3B49 (8), 0x4B3B75 (0Bh), 0x4B3C1C (0Dh), 0x4B3BA1 (0Eh) from 1.0. The init 0x4B3D44 stores stat `[+64h]`, value `[+68h]`, operation `[+78h]` unchecked. In game (`veterancyBonus` op add): Damage ×1.5, +0.5, ×4/3 gave ×2.667; MaxHP +100 raised 352 to 452. Evidence: `rea/evidence/age3y-b1a1dab7/veterancy-add-op.json` (ev_8f89bc2e…, ev_c42b6079…, ev_4c2204d2…, ev_3096f165…). |
| ModifyType callers | 0x5FC8AE (tactics tag, dispatch 0x5F9FD0); 0x5F3EFA (powers `<unitModify>`, FUN_005F3E97) | confirmed (call sites); rest scoping | Tactics: `mov [ebp+0B8h],al` with no check (default 0FFh at 0x5FA4E7). Powers: `mov ebp,eax / test ebp,ebp / jl` → error 1233h; stores {stat, op, amount} in `[obj+128h]`, applied by 0x8EE18E → 0x4DD22D. |
| Tactics ModifyType byte | `[tacticAction+B8h]` (signed byte) | scoping | Read by 0x9D064C (aura apply), 0x9D7696 (second applier), 0x9E3727 (init of class 0xB97C78) and 0x9D6F40 (aura tooltip: `stat − 1` ≤ 5, else default). `<ModifyMultiplier>` → `[+ACh]`, `<ModifyProtoID>` → `[+9Eh]`, `<ModifyAbstractType>` → `[+9Ch]`. |
| Aura apply | FUN_009D033E, call 0x4DD22D at 0x9D0670; filter 0x9D0238; scan 0x9CFF9A → 0x4A1C55 ("Resource auras", below in this file's order, has their signatures) | confirmed for a completed building, in game | `0x4DD22D(target, stat, mult, −1f, −1f, 0, 2, 0 ms, −1, −1, exclusive)`. Filter: not the owner, same player unless tactic flag 20h, alive, complete (0x44DDB4), ModifyProtoID / ModifyAbstractType. Runs only when the multiplier is > 1e-6 and the owner is complete. Keeps {target ID, modifier ID} at `[ua+68h]`. In game, an Explorer's aura reached a completed BloodFactory. |
| Aura update's steps | FUN_009D033E | confirmed (REA `ev_7ffb6afa…`), in game | Each update scans, keeps the targets in `[ua+68h]` still in the scan, removes the modifier of those that left (0x9C05B8), and sends each new target through the filter 0x9D0238 (one call, 0x9D0633) to 0x4DD22D. A target the filter refused is not kept, so every update asks again. The modifier of a dead carrier is gone at once (20.06 s; the next carrier's at 20.67 s, in game). |
| Modifier fields | `+64h` stat, `+68h` value, `+6Ch`..`+74h` ramp, `+78h` op, `+7Ch`/`+80h` the two −1 arguments, `+84h` −1, `+88h` duration; saved by 0x9E3423, loaded by 0x9E355E | confirmed (REA `ev_fad68dd5…`, `ev_726c449d…`), in game | `+84h` is read by nothing but the save: `auraStacking` keeps its mark there. Nothing on a modifier says which aura made it: `[+4]` is null on the 0x4DD22D path. `<ModifyExclusive>` is action flag 21h, passed as the last argument and stored as state bit 16h. |
| Second aura applier | FUN_009D7328 (`[ua+6Ch]`, no range, no filter) | scoping | Same steps with a query by proto or abstract type. No direct caller in Ghidra; a vtable slot. Not covered by `auraStacking`. |
| Modifier action classes | vtable 0xB97C08 (ctor 0x4DDA01, from 0x4B3D9E); vtable 0xB97C78 (ctor 0x9E36CC, factory case 46h) | scoping | Both carry runtime type 2Ch. WoL's ModifyActionFix retypes the second to 46h (0x9E36D0) and replaces the collector call 0x49F251. |
| Collector call | 0x49F23C..0x49F251 in FUN_0049F1BA | confirmed | Clears the count `[0CF071Ch]`, then `mov ecx,[edi+58h] / push 0CF0718h / push 1 / push 2Ch / add ecx,14h / call 49F1A0h`; then per-stat helpers from 0x49F26A. |
| GatherRate helper | 0x4B3B75 | confirmed | `[esp] = 1.0f`, `0x4B3C7D(&v, list, 0Bh)`; stores v only when it matched (cold 0x6A8972). The model for stat 40h. |
| GatherRate / AutoGatherRate readers | 0x4ECFE9 → 0x69FE53 (`+24h`); 0x49EDB8 → 0x69FE87 (`+28h`; another `+28h` reader at 0x69FE6F) | confirmed (0x4ECFE9, 0x69FE53, 0x49EDB8, 0x69FE6F); 0x69FE87 scoping | Record `[[unit+B4h]+C8h]` (no null check of `[unit+B4h]`); field used when `fcomp` with 0xB9FB64 (1e-6f) is not below and ordered-or-NaN (`test ah,5 / jnp`), else 1.0 (0xB856BC). Sites `BwrGatherRateRecord`, `BwrGatherRateRule`. |
| Getter callers' continuations | 0x9EA418 (Train), 0x9E65FC (Research), 0x9D58D9 (CommandResearch), 0x6AB244 (Maintain) | confirmed | Each writes EAX within two instructions and calls a function before reading the flags; ECX and EDX are rewritten before they are read. Sites `BwrTrainCallNext`, `WorkRate*Call`. |
| Getter tail | 0x9BFE38..0x9BFE47 | confirmed | The getter after its first two instructions (the part liveBuildingWorkRate does not write). Site `BwrGetterTail`. |
| `g_uhcBwrTrainGetter` | UHC.dll export (data, C linkage) | — | `void*`, default 0x9BFE33; set to the wrapper when `buildingWorkRateAuras` applies. noTrainNearEnemyTC's Train hook calls through it. |


### Free units, farms, walls and display modes (2026-11-03)

| What | Where | Status | Notes |
|---|---|---|---|
| Dynamic free unit count | 0x7FA6D5, 0x8D8C6F | confirmed (`cs`) | `amount < -1e-6` → `-amount × min([world+134h], 15)`; 0x8D8C62 skips a player without a home city `[player+84h]`. |
| Dynamic step | `[world+134h]` | in game | The 2-minute step rounded up: 4 at 452 s, 5 at 491 s. |
| Farm spot picker | 0x9DDADE, `thiscall(action)` | confirmed (`cs`) | Callers 0x4ED5E8, 0x4ED6F4, 0x50DF53, 0x6A8E7C (first spot) and 0x6A9067 (periodic, when the time passes `[action+A0h]`). |
| commandAutoRepair | 0x830AC4, `bool thiscall(game, int player, int unitId)`, `ret 8` | confirmed (`cs`; name from another DLL's symbol table) | `player < 0` → `[game+3C0h]` (local player). Single-wall caller 0x7DEDC3. |
| Display mode add | 0x54D605, `thiscall(renderer, Mode*)`, `ret 4` | confirmed (`cs`) | Called per adapter mode from FUN_0054D663 at 0x54D6D1; the mode's D3D format at `+0Ch`. |
| Format bit depth | 0x545A10 | confirmed (decompiled) | 14h/15h/16h/1Fh/23h → 32; 17h..1Ah, 1Dh, 1Eh → 16; 1Bh → 8. |
| AbstractWall | abstract type bit 54 (36h) | in game (`inspect_unittypes.py`) | 39 protos. |
| Proto flag `wallBuild` | bit 3Ah of `[proto+50h]` (0x45EE02) | confirmed (`cs`, in game) | Its button enters the edit mode `buildWall` (0x7E4762). Stock `WallConnector` and the `WallStraight*` have it. |
| Wall layout | FUN_009F66D9, `thiscall(store, player, points, count, -1)` | confirmed (REA `ev_98aa33f0…`, in game) | Posts and pieces between clicked points. Pieces from `[civ+1E4h]` (Straight2), `[civ+1F0h]` (Straight5), `[civ+1F4h]` (Gate), `[civ+1F8h]` (Connector), or the stock names when `[civ+1E4h]` = -1. Callers: drag preview 0x6659FC, ordering click 0x847E0C, 0x741299 (not identified). `customWalls` hooks 0x9F677A. |
| Civ wall pieces | `<wall type="Straight2\|Straight3\|Straight4\|Straight5\|Gate\|Connector">` in `civs.xml` | confirmed (`cs`) | Parser 0x65A354 (attribute `type`, values at 0xC0BC54..0xC0BCB0) → names at `[civ+1CCh..1E0h]`, IDs at `[civ+1E4h..1F8h]` (-1 in the constructor, 0x52A2C3). WoL's `civs.xml` does not use it. |
| World UI cursor proto | `[[game+91Ch]+4A4h]` | in game (`customWalls`) | The proto `uiBuildWallAtPointer` (0x7DFE31 → 0x84B5B3) builds. |
| BPlayer proto by name | 0x8D1998, `thiscall(player, const char*)`, `ret 4` | confirmed (`cs`) | Linear search; the layout's stock names use it. |
| AI wall builder | FUN_009F71A5 | confirmed (`cs`) | Reads the same civ fields (also Straight3/4 and `WallStraight1`, `tower`). |
| Wall post overlap | 0x508D95..0x508E11 in the placement test | confirmed (`cs`, in game) | A `wallBuild` proto may stand on its owner's unit of the same proto only when it is the player's `WallConnector` (0x508DD4); `customWalls` extends it. |

### Armor (for `multiarmor`, 2026-11-03)

| What | Where | Status | Notes |
|---|---|---|---|
| Proto armor | `[proto+1D3h]` (damage type byte), `[proto+C4h]` (float) | confirmed (`cs`, in game) | One per proto. |
| `<Armor>` handler | 0x5F5E62, cdecl `(ctx, node, proto)` | confirmed (`cs`) | Reads `type` and `value`; the type through 0x5F562D (thiscall on ctx); stores at 0x5F5EB7. |
| Damage type lookup | 0x5F55EA, `thiscall(ctx, name)` → entry, ID at `+8` | confirmed (`cs`) | List `[ctx+44h]`, count `[+48h]`; 0x5F562D returns the ID. |
| Armor getter | 0x49B323, `float thiscall(unit, byte damageType, ...)`, `ret 8` | confirmed (`cs`) | Value only for the stock type; then the tactic armor of `[unit+58h]` (0x69FEA3). |
| Proto copy | 0x67E011, `bool thiscall(dst, src, bool)`, `ret 8` | confirmed (`cs`) | Called when a player's proto is cloned (0x8D1B60, 0x8D6576). Named `BProtoUnit` ctor 0x5F7394, dtor 0x58633D in another DLL's symbol table. |
| BDataEffect | vtable slots 0xB9E5AC `setData` (0x6205F6), 0xB9E5C4 `playerApply` (0x7F874A), 0xB9E5C8 `playerUnapply` (0x7F877F), 0xB9E5CC `protoUnitApply` (0x7F86C0), 0xB9E5D0 `protoUnitUnapply` (0x7F8705) | confirmed (`cs`; names from another DLL's symbol table) | Fields: `+0Ch` subtype, `+18h` amount, `+1Ch` relativity byte. |
| applyData / unapplyData | 0x8F973F / 0x8FB01C, thiscall on the target proto, `ret 20h` | confirmed (`cs`) | Switch on the subtype (tables 0x8FAFB8/0x8FAF00, 0x8FC23C/0x8FC1A8); Armor = 5Ch at 0x8FAE52 / 0x8FC144. |
### DE parity sites (for WoL's requests #29–#42, 2026-10-30 and after)

The legacy sites behind [de-parity.md](de-parity.md), "What legacy does today". Read with REA, then `cs`; the rows that
say "in game" were driven by the feature's test.

| What | Where | Status | Notes |
|---|---|---|---|
| Delete console command | `uiDeleteSelectedUnit` (0xBDE3B4) → handler 0x7E5197, registered at 0x52F5C6 (`push 1 / push handler / push name / call 0x624F52`); `uiDeleteSelectedUnit2` 0xBDE36C | confirmed (REA `ev_d1a8bdcf…`, `ev_65a369ff…`, `cs`) | The handler reads the UI `[0xC66244]+74h→+34h→+1874h` first (null from `exec`: the crash at 0x7E51C8), walks the selection `[game+91Ch]`, and with one deletable unit calls FUN_0082F1E3(game, 0); more go through a dialog (strings 0xA2A7 / 0x8CB4). |
| Delete command | FUN_0082F1E3 `thiscall(game, char)`: per selected unit, 0x82D4BC(unit) then `0x5695FC(game+3C0h, 7, 0, -1)` (type 7 → FUN_007D5949, 0x90 B, vtable 0xB87E30), `[cmd+2Ch]=3`, `[cmd+3Ch]=0`, 0x5696E1 adds the unit ID, 0x568A1A sends it | confirmed (REA `ev_dfdd9ca3…`, `ev_a385ff71…`, `ev_971a72b7…`) | 0x5695FC is the switch of every command type (0..46h) with its constructor and size. |
| Delete executor | FUN_007CCF7F, slot 21 (+54h) of 0xB87E30, `(unit)`: proto flag 0Dh → `0x4B4DC2(1, 0, 0)` at 0x7CD0DC; else `0x4820A1(0, 1)` at 0x7CD0CF; `[cmd+8Ch]` set → `0x4726B2(id, 1, 1)` at 0x7CD0B5. ESI = the unit | confirmed (REA `ev_76737a10…`, `ev_2573b7bd…`, `cs`) | 0x4B4DC2 is `thiscall(unit, a, b, c)`, `ret 0Ch`: it pushes `[unit+10h]` for 0x4B4D80(world, id, a, b, c) (`ev_baffa46a…`). The HP setter 0x4820A1 `(float, char)` with the char set calls the death check 0x482152, whose HP ≤ 0 path ends in FUN_004B4F2F, not the queue (`ev_c17d64f1…`, `ev_22a9dab3…`). `detonationDeath`. |
| Model and bone names | 0x58F68F, `int thiscall(table [0xC66240], wchar* path, 1, 0, 0)`, called at 0x5FC94C for `<ModelAttachment>`; 0x58E506, `int thiscall(0xD6F478, char* name)`, at 0x5FC8FC for `<ModelAttachmentBone>` | confirmed (`cs`), in game | The model "ID" is a large number in practice (1118132992); it is only passed back to 0x405E83. |
| Aura reach | 0x9CFF9A → FUN_004A1C55(owner+14h, `[action+24h]` MaxRange, 1, list) | confirmed, in game (2026-11-06) | From the owner's centre to the target's edge: 6.2 m reached trees at 6.0, 6.3 and 7.2 m, not 8.9 m. |
| AutoGather pay | FUN at 0x48D150: rate 0x49EBE4 × elapsed; `[esp+10h]` amount, EBX resource, ESI action; action flag 4 `AddResourcesToInventory` → 0x4C0F7B adds to the unit's own inventory; else, a unit with stock and action flag 3 `SingleUse` → 0x6A7E30 pays its whole inventory (0x6A7E85) and clears it (0x58F070); else 0x4C378A → 0x4C3798 pays the player | flags confirmed (`cs`: the parser's handlers 0x5FC84D, 0x5FB8D4); the pay in game; the two other paths not run | |
| AI build plan | vtable 0xB942C8; `setState` 0x73DB7A; notification 0x73CF01 (`+88h`); failure reason in variable 1Eh: 2 placement (0x73F23C), 4 no units (0x73E8F8), 5 command failed, 8 no resources | confirmed (REA `ev_30009edc…`, `ev_1aef1d91…`, `ev_8c0c503d…`; tracers, in game) | `aiPlanGetState` 0x723633 gives −1 for a plan no longer in the list, finished ones too. The executor's PLACE failure is 0x7D7ED1 → 0x7D7F75, its build limit 0x7D7D48. |
| Data load failure exits | proto tag find 0x5F629D in 0x5F611D; `<UnitType>` handler 0x5F62D4, miss 0x5FCB61; tech parser 0x61FD02, called at 0x61FE4A; effect deleted at 0x6205E9 | confirmed (`cs`, in game with `dataLint`) | |
| XS reporters | FUN_0043A3A4 `void cdecl(int* log, char* file, int line, char* format, ...)`; FUN_00A5667F `void cdecl(int* log, char* format, ...)` | confirmed (REA `ev_0b3bc25b…`, `ev_3e9963ff…`, in game) | Both print only if the callback `[log]` is set. Formatter 0x435D99. |
| Modifier class | vtable 0xB97C08, ctor 0x4DDA01, 90h bytes; save 0x9E3423; load 0x9E355E (`+6Ch..+74h` from version 1, `+80h` from 2); update 0x48C21C reads `+7Ch` when it is 0 or more | confirmed (`cs`, in game with `savedmarkers.h`) | Stats 63h and 64h `damageOverTime`, 65h `overhealDecay`. Free: 66h and 67h. |
| Unit of type lookup | 0x48195C | confirmed (`cs`) | `int thiscall(player, type, startId, bool, other)`, ret 10h: walks `[player+F8h]` after startId; state byte `[unit+88h]` below 8 skips; more filters from 0x679800. |
| Dancer count | 0x9C1577 | confirmed (`cs`), in game | Villager +1, other +2 and +1 in `[esp+14h]`; 10 callers. |
| Proto type bits | `[proto+30h]` buffer, `[proto+34h]` bits, `+38h` bytes | confirmed (`cs`, in game) | The clone 0x67E011 clears its own buffer and copies bit by bit at 0x67E0F9, so each player's copy owns its buffer. Live readers: 0x44D7FA, 0x44CAC4, the damage bonus, `<Target>` by abstract type through 0x8D6327 (in game). |
| Protos by type | 0x453326, `thiscall(table, type, list)`: a proto ID gives itself, an abstract one the table's list | confirmed (REA `ev_ef435f41…`) | Built from the data and shared by all players. Callers 0x4533D6 (KB counts, from 0x4C846D `ev_38a27e86…`), 0x71DFB3, 0x86F519, 0x870145, 0x890AF7, 0x890B8B, 0x890C3F, 0x890DB8. A type added to a player's copy is not in it. |
| Effect flag 20h | `[effect+9]` bit 20h, read only at 0x94DEEF | confirmed (`cs`, in game) | The pass after a load 0x94DDEA (`ev_445c8e8c…`) runs flagged effects through 0x7F7E97 (`ev_cd2cf40e…`). Kind is `[effect+9]` & 0Fh: 1 proto effect, 8 general. A proto's type bits are not in a saved game: the copy is rebuilt with the base's. |
| Build tick rate | call 0x9D3D7B of 0x487C45 | confirmed (`trace_exec`, in game) | 0x9D3B30, 0x9E033C, 0x9E5885, 0x9E59BB: same pattern, not reached by building, nor by a repair (traced). |
| AutoRepair action | type 35h, name 0xBD7A50 at 0x522F9E; factory case 0x4EF5E3, `new(70h)`, ctor 0x9D0700, vtable 0xB971D8; update 0x9D0A4D | confirmed (`cs`, REA, in game: 0x9D0BCB hit 8910 times with `repairUnit`) | Started by the command type 3Ah (`commandAutoRepair`, console `repairUnit(id)`), on the building itself. HP added at 0x9D0BCB..0x9D0C16: `[world+318h]` × `[world+104h]` × `[action+64h]` × max HP / `[proto+CCh]`. 83 HP/s on a Barracks. `uiRepairAtPointer` on a villager does not start it. |
| Dopple | `+0` time made, `+0Ch` unit, `+12Ch` proto, `+130h` owner, `+134h` flags, `+140h` HP ratio; manager `[world+330h]`: `[0]` players, `[4]` lists of 0Ch {data, count, cap}; update 0x491961 calls 0x49192B at 0x49198B, true removes through 0x5038E0 | confirmed (`cs`, in game) | |
| Second aura applier | FUN_009D7328, one caller 0x9D7FFF, not in a Ghidra function | confirmed (REA `ev_76e6d312…`) | Applies a modifier to every unit of a type `[action+9Ch]`/`[+9Eh]` of the player, with no range; a proto with flag 52h takes the value from the dancers. Call of 0x4DD22D after 0x9D769D. `auraStacking` does not cover it. |
| Inventory add callers | 0x49A5E6: 0x4C0F7B, 0x4ED124 (gather tick), 0x6A34B2, 0x6A8BB2, 0x8F9D43, 0x9C737B, 0x9DD90F, 0x9DD973 | confirmed (`cs`) | Eight callers. 0x9DD90F negates its amount, 0x9DD973 does not, and the others pass a value through. Only the gather tick was driven in game with `linkedResource`. |
| Unit axes | `[unit+14h]` position, `+20h` forward, `+2Ch` up, `+38h` right, 3 floats each | confirmed, in game (2026-11-06) | Unrotated forward is (0, 0, −1); `trUnitCreate` with heading 90 gave (−1, 0, 0). |
| Placed unit (ghost) | UI object `[0xC67300]`: `+1FCh` proto ID or −1, `+200h` the ghost's visual (its axes from `+4`), `+22Ch` placement valid | confirmed (`cs`), in game | 0x96DF2F copies the 12 dwords of `[+200h]+4` (position, forward, up, right). The mode's proto is also `[[game+91Ch]+D4h]`. |
| Ghost rotation | `uiWheelRotatePlacedUnit` 0x7E0677: the proto's flag 25h (`NotRotateable`) stops it; an argument above 0 calls 0x96DE98 → 0x9BC546 with π/8, one below 0 with −π/8, and 0 does nothing | confirmed (`cs`), in game (arguments 1, −1, 0) | 0x9BC546 rotates through 0x4811BD and sets `[+7Dh]`. Flag confirmed in game: `<Flag>NotRotateable</Flag>` kept the ghost's yaw. |
| Build mode | `uiBuildMode(protoID)` 0x7E48E0 → 0x7E4426 (cost and train-list checks); `uiSetProtoCursor` 0x7E00F5 sets the proto with no check | confirmed (`cs`), in game | The in-game proto ID is the index in `[db+54h]`, not the `id` of protoy.xml. `tis` does not enter the mode for a building out of the builder's list. |
| Build command | Sender 0x82F548 (`thiscall(game, player, proto, transform*, …)`, `ret 2Ch`): type 3 of 0x5695FC; `[cmd+8Ch]` proto, `[cmd+90h]` position, `[cmd+A8h]` forward | confirmed (`cs`, REA `ev_9f71cc03…`, in game) | The legacy form of DE's `mBuildingForwardOrientation`. uiBuildAtPointer is 0x7E6DE8 (registered at 0x52D97B). |
| Build executor | PLACE at 0x7D7EC7 gets `[cmd+90h]` and `[cmd+A8h]`; 0x7D80CF calls `0x498ACC(world, proto, player, pos, forward, 0, -1, 0, -1)` | confirmed (`cs`), in game | A foundation placed from a ghost at yaw −112.5° had that yaw, kept by the finished building and a saved game. Stock needs only the key binding. |
| Build executor, details (2026-11-08, `annexFacing`) | FUN_007D79D6 (`ECX` = the command, player `[arg+4]`); builders `[cmd+40h]`, count `+44h`; right = 0x423792(up 0xC66544, &right, &forward) at 0x7D7CF1..0x7D7D0C; PLACE = world vtable +14h, FUN_0050703D(proto, player, &pos, &forward, &right, 1, 7, 0, 0, 0, 0); created ID → `[cmd+B8h]` | confirmed (`cs`), in game (`trace_exec`, the hook's log) | The unit loop: 0x9C2C67(unit, proto) takes the first action of the unit's tactic that targets the proto and needs its active bit (`[action+64h]` bit 3): WoL's Barracks matched `SpawnSpawner` (inactive) before `BuildAnnex`, so it could not place its Torp until `BuildAnnex` came first in the tactic. A builder whose `[[unit+58h]+C4h]` is 0 or more (the foundation it builds, written at 0x7D8199) is refused: a Barracks that built one Torp was refused a second. |
| Footprint of a unit | FUN_00506B60(proto, pos, forward, right, out, −1, −1): corners `pos ± forward·[proto+8Ch] ± right·[proto+88h]`; with the proto's flag bit 27 clear (`DontRotateObstruction`, which clears it at 0x5F63AB), the world axes 0xC6655C.. (0x67DD4B) | confirmed (`cs`), in game | Callers: PLACE 0x5071BA, the unit's obstruction 0x9C0CE3 / 0x9C2A58 (with `[unit+20h]`, `[unit+38h]`), 0x7C3977, 0x7C445E, 0x7C477B, 0x8CED46, 0x8CEF22. A Torp turned 90° fitted where the unturned one overlapped a Barracks, and the reverse. |
| Placement ghost update | FUN_0096E062: moves the visual (`ESI`) to the pointer (0x422F1E), snaps, then PLACE at 0x96E531 with the visual's `+4`, `+10h`, `+28h` and the local player `[game+3C0h]` | confirmed (`cs`), in game (`annexFacing`'s hook at 0x96E4E7) | Callers 0x7EAD42, 0x692567. `uiBuildAtPointer` 0x7E6DE8: needs `[ui+22Ch]`, the mode's proto, a selection (0x4051B6), then PLACE again at 0x7E6E9B with the transform of 0x96DF2F; a refusal only plays a sound. `uiDeleteSelectedUnit` from the console crashed at 0x7E51C8 (`[[[0xC66244]+74h]+34h]+1874h` null) in a background bed. |
| Placement rule distance | `distanceatmostfromtype` measures from the ghost's centre to the target's footprint | confirmed, in game (2026-11-08) | Torp east of a Barracks, rule distance 4: centre 3.5 m from the footprint fitted, 4.3 m did not, with the outlines 0.5 and 0.3 m apart. |
| AI build plan placement (2026-11-08) | FUN_0073D62B, the plan's test: world axes (or `[plan+2Ch]` for a proto of type 18h), PLACE at 0x73D7E3 with `[plan+50h]` position, `[plan+ACh]` proto, `EAX` player; its command at 0x73DA17 carries that forward. The scan of candidate spots: PLACE at 0x87DBA5 with the world axes stored just before | confirmed (`cs`), in game (`annexFacing`'s hooks at 0x73D7D2 and 0x87DB9F) | One caller of 0x73D62B: 0x73F1F1. The other build command senders: 0x74048F, 0x847D86, 0x986D76. |
| Trigger Destroy | `trUnitDestroy` 0x98282F → 0x4726B2(world, id, 0, 1) at 0x9828E7; `trUnitDelete` 0x982771 sends the delete command through 0x82F923 | confirmed (`cs`), in game | 0x4726B2, the world's unit removal, `thiscall(world, id, a, b)`, `ret 0Ch`, has 63 callers (also `trPlayerKillAllUnits` 0x98798E, `trPlayerKillAllBuildings` 0x987A8B, `trUnitChangeProtoUnit` 0x983153, the delete executor 0x7CD0B5 for a foundation). |
| Black map | console `blackmap(int)` 0x7D96EE: 0 reveals the explored mask, −1 toggles | in game | Used to place annexes in unexplored ground of a test. |
| Snare attacker | `[ebp+10h]` at 0x4DD201, EBP = the attacker's unit action; `[ebp+4]` its tactics action | confirmed (REA `ev_683538e5…`, `ev_dfeff76d…`, `ev_71e9bf8d…`) | FUN_0048FA07 has one caller, 0x48F9F5 in FUN_004B7766, which keeps the unit action in EBP and uses `[ebp+10h]` as `this` without a null test; FUN_0048FA07 and the chunk 0x4DD1DE..0x4DD228 never write EBP. `cantBeSlowed`'s `CannotSnare`. |
| Action list | `[manager+14h]`: `+0` count, `+4` capacity, `+8` pointers | confirmed, in game | Holds the unit's fixed actions too. 16 in a Barracks; `[manager+24h]` stayed the idle action (type 7) while a Train action ran (state 14h, `[action+61h]`). Append and front through 0x48D975(item, bool front). |
| Action add | 0x494894, `bool thiscall(manager, action, immediate, a, b)`, `ret 10h` | confirmed (`cs`), in game | With `immediate` 0 it appends; with 1 it stops the current action and makes the new one current. The queue routine calls it at 0x9CE81A. |
| Research payment | 0x9E67E1 (Research, thiscall(action, playerId, techId), ret 8) and 0x9D54CF (CommandResearch), 0x8D946A(player, cost*) | confirmed, in game for the first | The action keeps the cost for the refund: `+74h` (0x9E68A0), `+7Ch` (0x9D5548). 0x4E2617(cost, float) fills a cost. |
| Research start and queue (2026-11-11) | Research start 0x9E667A, its only caller the queue routine FUN_009CCB39 (callers 0x7D47D2, 0x7D7810, 0x9E6E45: makes the action 0x48D927(0xC), start, add 0x494894); CommandResearch start 0x9D543F, its only caller FUN_009CCAAF (action type 38h), called by the command class 0xB87978 (type 3Eh, the function at 0x7D44A5) | confirmed (REA `ev_55d37da8…`, `ev_78a96c1c…`, `ev_13bfd5e0…`, `ev_d0df1de1…`; in game for Research) | Paid when queued. In both starts ECX at the payment is the player from the start's first argument (0x44CB21), not the unit's owner. On success Research writes `[action+64h]` player ID, `[+68h]` tech ID; CommandResearch `[+64h]` player, `[+68h]` the tech `[record+20h]` of the command record in `[db+2968h]` (4Ch B), `[+6Ch]` the command index. |
| Research affordability | 0x8D6BAE `bool thiscall(player, cost)`, ret 4; 0x8D6C1B the same for the team's resources | confirmed (`cs`) | 0x8D946A: with `[world+6912h]` set, 0x8D6CF3 (0x8D6C1B, then the team's payment); else 0x8D6BAE, then 0x7E844B(`player+230h`, cost) subtracts. Both checks only read: each resource r below `[[game+140h]+80h]`, 0x44EFFF of the stockpile minus the cost. |
| Research progress | Research update FUN_009E648B (slot 3Ch of 0xB98078): 0x9E65F4..0x9E6625 `[action+6Ch]` += BuildingWorkRate × `[world+30Ch]` × `[player+37Ch]` × `[world+104h]`, then 0x9E5F19(entry) at 0x9E6628, and the end at 0x9E662D when `[+70h]` ≥ 1.0 (0xB856BC); CommandResearch FUN_009D5843: `[esi+70h]` at 0x9D58FF, fraction 0x9D539B → `[esi+74h]` | confirmed (`cs`, `rea/evidence/age3y-b1a1dab7/researchgrants_cs.txt`), in game for Research | ST0 holds only the step at 0x9E6622 / 0x9D58FF. EBX (Research) / EDI (CommandResearch) is the tech's status entry from 0x94ADAA(playerId, techId), `[entry+18h]` the research points. A branch 0x9E65A5..0x9E65F2 (tech flag 4 and 0x454ED7(player, 1)) sets `[+70h]` from another object and skips the add. Sites `ResearchProgressAdd`, `CommandResearchProgressAdd`. |
| Shipment queue | `[hc+288h]` data, `+28Ch` count, `+290h` capacity; entries of 18h: `+0` card index, `+4` tech ID, `+8` the tech's research points, `+0Ch` progress, `+10h` its cost list | confirmed (REA `ev_50f3d85d…`, `ev_12f83a18…`, `ev_28ed5e9b…`; in game) | FIFO: the update FUN_004BF86F (cold 0x66ABD3) advances only entry 0, and ships it with FUN_00858299 when `+0Ch` reaches `+8h`, then removes it with FUN_00857257(0, 1) and gives the next one the same tick. The UI's "Queued Pop" icons above the minimap show it in order, the progress on the first. Writers: the send FUN_0085A724 through FUN_00857204 at 0x85AD38 (from the command at 0x7D4C9B), the cancel FUN_0085ADD9 (0x66AC97, 0x66AE35, 0x66AF80, 0x7D63B5, the Blockade loop 0x7FC0F5, 0x85C0B4), the load 0x85E44E; save 0x8555E5, each entry 0x8522A6, load 0x852360. The add FUN_00857204 `thiscall(queue, entry*)`, `ret 4`, has one caller, the send (`ev_085f3a08…`); the removal FUN_00857257 `thiscall(queue, index, bool shift)`, `ret 8` (shift: move the rest up; else the last entry fills the hole), two: the update and the cancel (`ev_1ddddf42…`); the load does not go through the add (`ev_530bdbb8…`). The send checks the card's age `[card+18h]` against `[player+50h]` (`ev_43887acf…`). Readers: panel FUN_0069C1E0 (0x69C3AC), flag 39h at 0x85851D. A card needs a ship (resource 6), so a second one queues only with a ship left. Flag 39h is `YPRecalcHCTrainQueuePointsWhenShipped`. |
| Shipment models | `[scene+134h]`, count `+138h`, scene = `[hc+A4h]` or the hc; `[model+2Ch]` = place in the queue | confirmed (REA `ev_cd087b83…`, `ev_1f6c46e4…`) | FUN_00859CFE(place, 1) spawns `shipmentUnit` models for the local player's home city only; FUN_0085A24D deletes those of a cancelled place. Stock does not renumber them when the queue moves up. |
| Tech flag DoNotQueue | bit 1Ah (0x6B13ED); reader 0x9E5EAD | confirmed (`cs`) | Slot 58h of the Research action, vtable 0xB98078: false for a tech with the flag. Slot 58h of Train is 0x4474C9, true. One caller of interest, 0x9CA1F0, only when the byte `[world+6910h]` is set. Its purpose is not known. |
| Ability button recharge | 0x695202..0x695440, in the command panel's refresh | confirmed (`cs`, on screen for the first ability) | Loops over the 36 cells: 0x6EDB7E gives a cell's {start, end}, the ratio (now − start) / (end − start), clamped, goes to `vtbl+6Ch`, the sweep over the red button. A cell of a charge-based power takes charges / max. |
| Selection group | IDs `[group+10h]`, count `[group+14h]` | confirmed, in game | The sum of every selected Settler's rate equalled the player's gold rate (3.60 and +3.617/s). |
| Ground shot store | 0x4C4DEC, in the launch's frame | confirmed, in game | `[esp+28h]` is the impact point, as at the miss stub. A Catapult's action with `<TargetGround>` reaches it against units; against a building it took the precalculated block. |
| Blockade list | `[hc+4D8h]`, count `+4DCh` | inferred (`cs`) | IDs, unique, added by 0x85C09C, called at 0x7FBA2D for the other players, which fits the `Blockade` effect. A card is refused while it is not empty: 0x858301, 0x85A7C7, and 0x855F8F for `aiHCDeckCanPlayCard`. |
| Proto Bounty | `[proto+168h]`, float; tag handler 0x5F5D79, registered at 0x51D665 | confirmed, in game | No Data subtype reaches it: `Bounty` is a proto tag only. `BuildBounty` (`+16Ch`) has both, subtype 55h. |
| Kill bounty | Value 0x4D4DC5, `float thiscall(victim, attacker)`; TakeDamage's kill branch 0x4D4E0C | confirmed, in game | The branch is taken at 0x49B71A when `[esp+1Fh]` = 1. `[esp+20h]` the killer's player. |
| Team XP | FUN_0049BD52, one caller 0x49B73C, every hit; 0x49BDC0 `thiscall(team, playerId, amount, 0)`, `ret 0Ch` | confirmed, in game | Amount 0 unless the hit kills. Below 0: every member of `[team+8]` / `[team+0Ch]` gets the whole amount (0x68EA12). Team: `[[world+188h]+4·[player+10h]]`. |
| Proto tag table | builder FUN_0051CE1D, singleton `[0xD65444]`; 0x59B738 `thiscall(table, const char* name, handler*)` | confirmed (`cs`), in game | Protos' table at the object's `+0Ch`; second table at `+0C2Ch` from 0x51D807. Handler `bool cdecl(context, node, target)`; node text BString at `+14h`. |
| Build limit | 0x4C7B5F, `int thiscall(player, proto)`, `ret 4` | confirmed (`cs`), in game | `[proto+108h]` of the player's copy; −1 no limit; `[proto+1D1h]` other than FFh goes to a count of its own at 0x67AA73. 50 callers. |
| Build count | 0x4C7BC5, `int thiscall(proto, playerId, bool, bool)`, `ret 0Ch` | confirmed (`cs`), in game | 6 callers; the train check 0x9EAD04 passes (1, 1), which counts queued units. Through 0x4C846D `thiscall(kb, player, proto, flags, bool)`, 60 callers, on `[player+80h]`. |
| Player's proto | 0x45311B, `proto* thiscall(player, id)`, `ret 4` | confirmed (`cs`) | `[player+0E0h]`, count `[player+0E4h]`. |
| Relation to a player | `[player+1D4h+4*i]` | confirmed, in game | 0 or 1: self or ally, as the shared resources test it at 0x67995B. |
| Limit per Train action | 0x8D051B, `int thiscall(player)` | confirmed (`cs`), in game | `[player+2ACh]` if not negative, else `[db+178h]` (5). One caller, 0x9CE645, in the queue routine with `ret 1Ch`; proto ID `[esp+30h]` there. |
| Tech flag reader | FUN_00620C2F, `void cdecl(entry, const char* name)` | confirmed (`cs`), in game | Called once, 0x620C23. `[entry+0]` is the tech's definition, the `this` of the routines below; `[entry+4]` the flag bits. An unknown name is ignored. TeamTech is status bit 13h. |
| applyEffects / removeEffects / after a load | 0x94DAE1 (`thiscall(tech, player, unit, team, a, b)`, `ret 14h`, one caller 0x94D0AE); 0x94DCB2 (`thiscall(tech, player, a, team)`, `ret 0Ch`, 6 callers); 0x94DDEA (same shape) | confirmed (`cs`), in game | Each builds its own list of players: the team's when the byte `team` is 1, else the player. `[tech+0]` tech ID, `[tech+24h]` effects, `[tech+28h]` count. |
| Kill queue | 0x4B4DC2 asks, list `[world+8DCh]` (8 B entries: unit ID, three flags), count `[world+8E0h]`; drain 0x493D46 | confirmed (`cs`), in game | The kill handler 0x4B4F70 has one caller, 0x493D8F. The drain reads the count again each turn. Flags 1 0 0: a trigger's kill. |
| Area damage | FUN_004C9D89, `thiscall(world, unitId, action, point, multiplier, 0, 0, -1, int* out, bool, Vector* offset)`, `ret 28h` | confirmed (`cs`), in game | Callers 0x4CA329, 0x4DD581, 0x6A4A6B (around the unit). The bool is the action's flag bit 6; offset the zero vector 0xCF0618. |
| Data subtype lookup | 0x61FF5D, `int thiscall(db, const char* name)`, `ret 4`; table `[db+3500h]` | confirmed (`cs`), in game | Callers 0x6206D7 (setData) and 0x621C29. −1 if absent. `techsubtypes.*` adds IDs from 100h at the first. |
| Proto CostEscalation | `[proto+78h]`, float, default 1; tag handler 0xA1119D | confirmed, in game | Cost container at `+70h`, set by 0x58EF83. Read at 0x480B66 and 0x67A1DD. |
| Cost getter | 0x480B1E, `bool thiscall(player, protoId, cost*, count)`, `ret 0Ch` | confirmed (`cs`), in game | 35 callers, nearly all with count 1; variable count at 0x9EAF86 (train). Cold part 0x67A1A0: the query counts alive units only, in game. The costs are XOR-masked with `0xC6DF14`, count `[0xC6DF38]`. |
| Data effect on an action | subtype TrackRating 26h, case 0x8FAA45; `action` read at 0x65BDE2 | confirmed (`cs`), in game | `[effect+10h]` the action's ID through 0x5E0C64(db, attribute). `allactions`: bit 40h of `[effect+9]`, 8th argument of applyData and unapplyData. Action set: `[proto+44h]`, array `[set+1Ch]`, count `[set+20h]`, ID at `[action+4]`; each proto and player has its own. |
| Crate rank | FUN_004DBF40, `int thiscall(db, resource, civ)`, `ret 8` | confirmed (`cs`), in game | One caller, 0x49A03C: score += rank × 1000. Resource 0 Gold, 1 Wood, 2 Food. Dutch 3, 2, 1; Ottomans and Indians 1, 3, 2; others 1, 2, 3. |
| Next crate | FUN_00501786, `bool thiscall(player, proto, int* next, int* resource)`, `ret 0Ch` | confirmed (`cs`), in game | One caller, 0x50170B, a loop of 6. Crate protos `[db+5E34h]` Food, `+5E38h` Wood, `+5E3Ch` Coin, `+5E40h..+5E48h` the large ones. |
| ExperienceUnit | proto flag 7Dh, `[[proto+50h]+0Fh]` bit 20h, set at 0x6B0AE4 | confirmed (`cs`) | No reader: none of the 642 calls of the flag getter 0x44CAC4 passes it, and no `test` of that byte. WoL uses it on no proto. |
| Killing blow | `[esp+1Fh]` in TakeDamage, set at 0x4D484B; `je` at 0x49B746 to 0x4D4F37 | confirmed, in game | ESI the unit killed, `[esp+28h]` the attacker unit (null when gone), `[esp+20h]` the attacker's player. |
| Transform in place | 0x9C754C, `thiscall(unit, proto)`, `ret 4` | confirmed, in game | Seven calls: 0x7FBC79, 0x7FBEF2, 0x8C2D08, 0x8EB78A, 0x8F05F5, 0x9BB6D5, 0x9C7C16. It keeps the unit ID and ends its stat modifiers. |
| Effect value | 0x7F892A, cdecl `(byte relativity, float* target, float base, float amount, bool unapply)` | confirmed (`cs`) | 0 Percent (×, ÷), 2 BasePercent, 3 Assign, else Absolute. |

### Command types (for `customProtoUnitCommands`, 2026-11-03)

| What | Where | Status | Notes |
|---|---|---|---|
| Name tables builder | FUN_0052277E (0x52277E..0x526E38) | confirmed (`cs`, command part) | Registers the database's enum names; command types 0..128 at 0x5262F2..0x5269FB. |
| Register a command type name | 0x537683, `bool thiscall(db, int id, const char* name)`, `ret 8` | confirmed (`cs`) | Only when `id == [db+264Ch]`; appends through 0x59F915 to the hashed list `[db+2648h]`. Its neighbours 0x5376BA, 0x5376F1 do the same for other tables (`+5130h`, `+5454h`). |
| Command type by name | 0x5274AB, `int thiscall(db, const char* name)`, `ret 4` | confirmed (`cs`) | Hash lookup (0x421B73, 0x40295B); -1 if absent. Callers: the protounitcommands.xml loader 0x5274A2 / 0x65A9A2, 0x7D8AFD, 0x7DF0E3, 0x7F03C7, 0x94808F, 0x9AD1C8. |
| protounitcommands.xml loader | FUN_00527090 | partial (`cs`) | Reserves the record array `[db+2968h]` with `0x5276EA(arr, 82h, 0)` at 0x52711D; 4Ch-byte records indexed by command type ID (the `<name>` lookup gives the index; `+24h` written at 0x65A9B2). |
| Command records | `[db+2968h]` (array), `[db+296Ch]` (count) | confirmed (readers) | Readers (0x4619F3, 0x695D30, 0x69CAEA, 0x8D283E, 0x9B6E19, ...) compare the ID with the count first. |
| Proto command list | `[proto+E8h]` (6-byte entries), `[proto+ECh]` (count) | in game (2026-11-03) | `{word id, byte kind (2 = command, 1 = tech), byte page, byte column, byte}`; read at 0x7D8ACD. |
| Tactic buttons gate | 0x5C161C (FUN_005C13C5), 0x6949CD (FUN_004C55E3) | from the address map (`tacticSwitching`) | The tactics page shows only for the Factory `[db+5E68h]`, Rice Paddy `[db+5E70h]` and a few other cached protos. |

### KB unit queries (for `kbUnitSyscalls`, 2026-11-03)

The stock KB syscalls share one head (for example `kbUnitGetNumberWorkers` 0x881CC6, registered
at 0x8879E6 with `push 2 / push fn / push name / mov ecx,esi / call 624F52h`): world
`[[C66234h]+13Ch]` non-null, player `0x44CB21([C66664h])`, its kb `[player+80h]`, then a kb method
with the unit ID. Player by ID and Unit by ID are in "Home city gather point"; the inventory and
ResList get in "Resource inventories".

| What | Where | Status | Notes |
|---|---|---|---|
| kb getNumberWorkers | 0x86C647, `thiscall(kb, int unitId)` | confirmed (`cs`) | Returns `[unit+98h]` only when the unit's owner `[[unit+44h]]` is the kb's player `[kb+10h]`; else 0. |
| Unit worker array | `[unit+94h]` (pointer), `[unit+98h]` (count) | confirmed (0x86C647); entry layout inference | 18h-byte entries whose first dword is a worker's unit ID (the layout another DLL's code walks; not traced in the exe). |
| kb unit record | 0x470CC4, `thiscall(kb, int unitId)` | confirmed (`cs`) | `[kb+18h][[[unit+B4h]+8]]` if that index is below `[kb+1Ch]`: the AI's record of the unit, null if it never knew it. |
| `kbUnitVisible` | 0x88596E (registered at 0x88E79C) | confirmed (`cs`) | True when `[[unit+B4h]+ACh] & (1 << [C66664h])`: the per-player visibility mask. |
| Unit isSeeable | 0x48A9EF, `bool thiscall(unit, int player)`, `ret 4` | confirmed (head, `cs`); cold path scoping | The visibility mask above; else (0x55F5B2) the explored mask `[+B0h]` and the proto's under-fog flags `[[proto+50h]+1] & 1` (proto `[unit+5Ch]`). Site `UnitIsSeeable`. |
| Unit getSquad | 0x4E2A03, `thiscall(unit)` | confirmed (`cs`) | `[[world+148h]][[unit+B4h]+14h]` if that index is below `[world+14Ch]`, else 0 (0x470CB5). Site `UnitGetSquad`. |
| Squad orders | `[squad+1Ch]` → `+28h` pointer array, `+2Ch` count; each element `+1Ch` array of 18h-byte entries, `+20h` count | inference | The path `kbUnitGetNumberTargeters` walks; the first dword of an entry is a target unit ID. Seen in another DLL's code, not traced in the exe. |
| Resource inventory isFull | 0x4DC520, `bool thiscall(inventory)` | head confirmed | Inventory `[[unit+B4h]+94h]`; starts with the unit lookup of its `+0` unit ID. Site `InventoryIsFull`. |
| Unit getCarryCapacity | 0x494503, `float thiscall(unit, int r)`, `ret 4` | confirmed (`cs`) | `0x4944E5([unit+5Ch], r)`: the proto's capacity. Site `UnitCarryCapacity`. |
| Player unit list | `[player+F8h]` (unit IDs), `[player+FCh]` (count) | inference; in game (counts) | The list `kbUnitGetNumberTargeters` walks. |

### Settings objects and the options screen (for `rendererOption`, 2026-11-10)

REA (Ghidra 12.1.4) on the stock exe, records in `rea/evidence/age3y-b1a1dab7/renderer-20261110.json`; `cs` = capstone
over the file bytes. The profile's game options are one of these settings objects.

| What | Where | Status | Notes |
|---|---|---|---|
| Settings object | vtable 0xBA3854, 0xE54 bytes; ctor FUN_00518E3B(index, name, table, count) | confirmed (`ev_d5d3621f…`) | `[+4]` 5-byte entries (byte: low nibble type 1 float, 2 int, 3 ?, 5 bool, 9 string, high nibble flags; then 4 bytes value or pointer), `[+8]` count, `[+20h]` index, `[+24h]` kind, `[+2Ch]` name (0x104 wchar), `[+234h]` name → ID map (insert 0x598DEF, find 0x401D10 / 0x401DB3). |
| Settings factory | FUN_00518CC9(name, kind, …) on the manager 0xC66688 | confirmed (`ev_ec20813d…`) | kind 0: the game settings table 0xD840E0, 0x172 entries; kind 1: the option table 0xD91778, 0x5D (93) entries (the only reference to it, 0x55093C). The object goes in the manager's list `[+C20h]`; lookup by name 0x402C76 (`thiscall(0xC66688, name)`). |
| Option table | 0xD91778, 93 × 0x88 bytes | confirmed (bytes) | `u32 id; wchar name[64]; u32 flags` (e.g. 0x49 `OptionMinimizedUI`, 0x5C `OptionWonderPowerUI`). Flag 0x40 (in the entry byte's high nibble): the field may change during a match. |
| Option name → ID | 0x932264, `thiscall(obj, const wchar_t*)`, `ret 4` | confirmed (`ev_0d116bfb…`, `cs`) | -1 if not found (0x9322A1, reached from 0x93227B and 0x932295). Called only by the options screen's field builders (0x78BEC5 CheckBox, 0x78C0C0 Slider, 0x78C417 Edit, 0x78D722 DropDown). The options menu's registry (`menuoptions.*`: `rendererOption`, `menuOptions`) hooks the not-found return (site `OptionNameLookup`). |
| Option type | 0x553028, `thiscall(obj, id) -> al`, `ret 4` | confirmed (`cs`) | Out of range → 0x6B794B `xor al,al / ret 4`, reached only from 0x55302F (sites `OptionTypeGetter`, `OptionTypeRange`). |
| Option int get / set | 0x402E6A `(id, int* out)`, 0x518AE0 `(id, int value)`, both `ret 8` | confirmed (`cs`) | Get out of range → 0x6B7676 (`xor al,al / ret 8`, only from 0x402E73); set fails through 0x518B26 (range 0x518AEB, type 0x518B15). Sites `OptionIntGetter`, `OptionIntGetRange`, `OptionIntSetter`. Other accessors with the same range check: bool 0x402CE9, float 0x44738A, string 0x9325C4 / 0x518B57, flag test 0xA41707. |
| Options screen | options.xml loader at 0x78EC63; section FUN_0078E87D; field type FUN_0078E67F; DropDown FUN_0078D66A; apply FUN_0078D052 (from 0x78E1F4); change check FUN_0078D1E4 | confirmed (`ev_f384e120…`, `ev_bcf44188…`, `ev_d8c8392b…`) | `[screen+E4h]` = the "GameOptions" settings (0x78EE59). Field vtable +30h set ID, +34h get ID, +24h enable. Value ↔ entry: 0x78C8BC / 0x78C76A map IDs 9 (resolution), 0Ah (bit depth) and 30h (refresh rate) through lists, any other int is the entry's index (`ev_340d304f…`). |
| Profile settings reader | FUN_00553044 | partial (`cs`) | Reads `<Settings>` / `<Setting>` (strings 0xBE29B0, 0xBE2BF8) with its own lookup, not 0x932264. |


### Stealth and per-player visibility (for `stealthTargeting`, 2026-11-12)

Evidence: REA `ev_bad9f213…` (strings), `ev_390e4491…` (`CheckIfCanStealth`), `ev_db33d956…` (`AbstractCanSeeStealth`),
`ev_b3b3cbe0…` (action name `Stealth`), `ev_5a41a7e3…` (`unitToggleStealth`), `ev_9fc9c2ff…` (0x489ECC),
`ev_3e7fba22…` (its callers), `ev_c9a4cfb6…` (0x4A1A0E); bundle `rea/evidence/age3y-b1a1dab7/stealth-60-61.json`. The rest
by capstone (`cs`) and in game.

| Name | Address | Status | Notes |
|---|---|---|---|
| Action type `Stealth` | 47h (name 0xBD7980 at 0x52324A) | confirmed (`cs`) | Factory case 0x4EF7DF: `new(68h)`, ctor 0x9E877F, vtable 0xB982A8 (slot 0Ch end 0x9E890D, 3Ch update 0x9E8A26). |
| Stealth state | unit state bit 42h (`[[unit+4]+8]` & 4, count `[unit+8]`) | confirmed (`cs`, in game) | Set by the update at 0x9E8AE5 (with a 0.6 modifier 0x4CD8FF and the visibility queue 0x482B8A), cleared by the end at 0x9E892F. Readers (`push 42h` + 0x44D863, or inline): the heal search 0x9CD9E2, the heal tick 0x9E0A9E / 0x9E0BFF, the visibility update 0x486888, the render 0x4CDB70, the UI 0x6EDBF2, 0x4C71FA, the saved-game load 0x9C5526. No target search reads it. |
| Stealth detection | 0x9E8BB5..0x9E8CC7 | confirmed (`cs`) | Query 0x4A1C55 in the action's range `[action+24h]`; an enemy unit with `AbstractCanSeeStealth` (protoCount + 53h, 0x9E8C12), alive, built, with the unit within its LOS (0x48206D), makes 0x82FD72 send the owner a type-35h command (0x5695FC) that ends the tactic; the local player gets string 0xBF76. |
| `CheckIfCanStealth` | tactic flag `[[tactic+14h]]` bit 10h (0x68DC87) | confirmed (`cs`) | Wide tag 0xBCA264. Tactic tags are wide strings: `AutoAttackType` 0xBCA2F4 → `[tactic+174h]` (0x5FBF45), `AttackType` 0xBCA314, `AutoRetarget` 0xBCA2A0. |
| `unitToggleStealth` | UI syscall 0x7DD792 (registered at 0x53A22C) | in game | Toggles the selected units: `uiLookAtAndSelectUnit(id)` + `unitToggleStealth()` from the console. |
| Visibility update | FUN_0048679A | confirmed (`cs`, write breakpoint) | Passes the stealth bit (0x486888) and 13 more arguments to 0x486B1A; writes the new mask `[[unit+B4h]+ACh]` at 0x486A60 and `+B0h` at 0x486A70. |
| Per-player visibility | 0x486B1A, `thiscall(proto, ...)`, `ret 38h` | confirmed (`cs`) | Arg 14 (`[esp+68h]` in the loop) = stealthed. Small-unit branch: ally → 0x486A87; `[esp+38h]` set (proto flag 8, or 9 with arg 6 zero) → 0x4E0B05, stealth → 0x4E0B12: a non-ally is skipped (0x486E11). Footprint branch 0x493040, for `[proto+88h]` or `[proto+8Ch]` (obstruction radii) over 1.0 (0x486C0D, 0x486C24): LOS on every tile; tests only `[esp+38h]` (0x493201 → 0x4E0B1F); the stealth slot is overwritten at 0x493048 and used as a counter at 0x49312D. The bug of WoL #60/#61. |
| Visibility mask | `[[unit+B4h]+ACh]` (players that see the unit), `+B0h` | in game | A stealthed spy (radius 0.49) kept 0x2; a stealthed submarine (Z 2.5) went 0x2 → 0x6 when enemy ships came in range (stock). |
| Visible to a player (UI) | 0x4818F4 | confirmed (`cs`) | Reads the mask when `[world+6921h]`; its cold path 0x6A05CD uses the local player: not for simulation code. |
| Attack action for a target | FUN_00489ECC, `int thiscall(tactic, attacker, target, ...)`, `ret 1Ch` | confirmed (REA `ev_9fc9c2ff…`) | -1 for none (0x4974C1). Checks the attacker, alliance (0x484E01), the relation when arg 4 is 1, proto bit 0Eh, both units built; no visibility. Callers include the unit query 0x499CE4 and the auto-attack scoring 0x4A893B (12 call sites). Site of `stealthTargeting`. |
| Auto-attack range test | FUN_004A1A0E | confirmed (REA `ev_c9a4cfb6…`) | `thiscall(tactic, attacker, target, float)`: the target is of `[tactic+174h]` (AutoAttackType, 0x44D7FA), both built, and within range. Callers 0x4A8969, 0x94174E. |

### LAN lobby slots and avatars (for `playerIcon`, 2026-11-13)

REA (Ghidra 12.1.4) and capstone (`cs`) on the stock exe; bundles `rea/evidence/age3y-b1a1dab7/lobby-avatar-59-20261113.json` and `player-icon-59-20261113.json`. The study is in [de-parity.md](de-parity.md#59-player-icons-in-lan-lobbies-two-copies-on-one-pc).

| Name | Address | Status | Notes |
|---|---|---|---|
| Lobby slot | 8 per setup page (FUN_00775DA0); `[+0Ch]` lobby settings, `[+14h]` local player's slot, `[+15h]` ?, `[+18h]` index, `[+1Ch]` AI slot, `[+28h]` icon gadget | confirmed (`ev_e29055de…`, `ev_de710dab…`; `[+14h]` and `[+1Ch]` in game 2026-11-13) | FUN_0077649C(local) writes `[+14h]` and enables the slot's own controls; FUN_0077539F enables a control when `[+14h]` (not ready) or when the host edits an AI slot (`[+1Ch]`). |
| Slot setting handler | 0x776BED `thiscall(slot, settings, id, flags)`, `ret 0Ch`; acts when flags & 10h | confirmed (`cs`) | Field = (id − 3Ah) mod 18h, slot = quotient − 1; jump table 0x777558 / 0x777590: Civ 0x776F73 and AIPersonality 0x7772D3 end in the civ portrait, AvatarID 0x776DEA. |
| Civ portrait | FUN_00774D56 `thiscall(slot)`, plain `ret`; called only at 0x776FFC and 0x7773DD | confirmed (`cs`) | `[civ+D0h]` on `[slot+28h]`, or the random civ's `[db+5D78h]`. |
| Lobby settings strings | get 0xA263C7(id, string*) → 0x518B57 on `[obj+20h]`; set 0xA26361(id, string*), `ret 8` | confirmed (`cs`, in game) | The setter sends through FUN_00A2B475; int get 0xA2639F, bool get 0xA263B3. |
| Avatar table | `[[0xC66234]+140h]` → 0x7EEEE7 → lookup 0x7A77EF(string*) | confirmed (`cs`) | An empty name gives the first entry. Loaded from `avatar_*.xml` (FUN_007A7875: `<avatar id>` with `image`, `portrait`, `tier`, `minLevel`, `type`, `civ`). |
| Game string | one pointer to the characters, header 10h bytes before; ctor 0x401A12(const wchar_t*) `ret 4`, dtor 0x4010CA, empty ctor 0x40133F | confirmed (`cs`) | |

### Impact types and impact effects (for `impactBoneFix` and `customImpactTypes`, 2026-11-12)

REA (Ghidra 12.1.4) on the stock exe, records in `rea/evidence/age3y-b1a1dab7/impact49-50.json`; `cs` = capstone over
the file bytes; traces with `tools/re` hardware breakpoints in a WoL copy.<!-- private -->

| What | Where | Status | Notes |
|---|---|---|---|
| Impact type names | 0xBA4D70, 15 × `wchar[32]` | confirmed (bytes) | Wood, Stone, Flesh, Animal, TerrainGrass, Snow, Dirt, TerrainWater, TerrainDirt, TerrainStone, TerrainSnow, TerrainSand, RoofTile, ExitBuilding, Metal (14). |
| Impact type by name | FUN_0059F436 (cdecl, the name's string object) | confirmed (`ev_89da6b7d…`, `cs`) | FUN_00443C10 compare, not case-sensitive; -1 at 0x59F464. Callers: FUN_004F04FE (`.dmg`), FUN_005F7F7C (`[proto+1B8h]`), FUN_0051E1DF (terrain types), FUN_005FEABF (`.impacteffect`). |
| Damage template impact point | FUN_004F04FE | confirmed (`ev_89da6b7d…`) | `+10h` the bone's index among the damaged model's impact dummies, `+14h` the type, `+18h` prereq, `+1Ch` `mode="linked"`, `+0Ch` `impactEffectOffset`. |
| `.impacteffect` loader | FUN_005FEABF; entry parser FUN_005FE922; entry init FUN_005FE875 (0x38 B) | confirmed (`ev_7d29d565…`, `ev_107075e1…`) | Lists at `[effect + 4 + type × 12]`, 15 of them; FUN_005FE8CD makes the weights `[entry+20h]` running sums. `meterCount` `[+C8h]`. Loaded through the manager `[[0C66234h]+0BB8h]` (FUN_0058F017). The archive's `.xmb` is read before a loose `.xml`. |
| Impact spawn | FUN_0049C1E5 (thiscall(effect, pos, dir, ?, type, …), 8 args) | confirmed (`ev_79c38552…`) | -1 for a type above 14; the entry by FUN_0049C18C (weighted). A `particleSet` that is not a particle set is loaded as a visual and attached to the target's visual at the impact dummy (FUN_004CA908); else placed at the point (FUN_004828E6). Called at 0x49D86E (projectile hit) and 0x4CB30D (terrain). |
| Impact point pick | FUN_0049ABA1 | confirmed (`ev_0bcda0ab…`) | Picks the template's point near the hit, throws its parts (FUN_004D3393), returns `[point+14h]`. |
| Dummy attachment | FUN_004CA908(0, 0, dummy type, index, visual) | confirmed (`ev_6c015823…`) | A type 4 attachment record; the update resolves the dummy in the current model (FUN_00407402) and reads its frame with FUN_00407272 at 0x4BE21E and 0x4BE88D. |
| Bone frame | FUN_00407272(bone, pos*, axis*, axis*, axis*, …), `ret 1Ch` | confirmed (`ev_a040ef98…`) | Copies rows of `GrannyGetWorldPose4x4` (or the sampled pose), scale included. |
| Terrain impact (a shot landing on the ground) | FUN_004CB11C, `thiscall(projectile, float point[3])`, `ret 4`; called at 0x4C4818 and 0x4CB459 by the projectile update | confirmed (`ev_ca755380…`, `cs`), in game 2026-11-13 (`detonationDeath`) | Returns when the point is not visible to the local player (FUN_004601B8 on `[world+58h][[game+3C0h]]`). Type: 7 on water (FUN_004CB5B0 ≠ −1, block 0x4DD628), 9 (block 0x64A32F), else the terrain type's `[+70h]` (−1: nothing). Reads only `[proj+10h]` (the action), `[proj+28h]` and `[proj+64h..6Ch]` (the origin, for the direction on the ground plane; the default vector 0xC6655C when zero). Spawn: FUN_0049C1E5(point, dir, 0, type, 1, `[proj+28h]` == 0, 0, 0). |
| Action impact effect | tactics action `[+70h]`, the ID in the effect manager `[[0C66234h]+0BB8h]` (array `[mgr]`, count `[mgr+4]`) | confirmed (`cs`: handler 0x5FAFB2, from the tag compare at 0x5F9D63; `ev_6061959a…`) | Written by `<impacteffect>` through FUN_0058F017 `thiscall(manager, &name)` (the node's text field `[node+14h]`): the ID of a loaded effect (FUN_0058EFD5), else a new one read by FUN_005FEABF; −1 when it cannot be made. |
| Impact spawn arguments | FUN_0049C1E5's fifth (byte) and sixth (byte) | confirmed (`ev_204bff62…`, `ev_eaca0080…`) | Fifth 0: sound only. Sixth 0: the entry's `secondaryParticleSet` (`[entry+4]`) when it has one; 1: its `particleSet` (`[entry+0]`). The seventh is the hit unit (a visual one attaches to it), the eighth the impact point's index. |


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
| 0x408399 | Render (game `vtable[78h]`) | Particles 0x408AAB, world 0x40B9BA, UI 0x41C6D3, Present wrapper 0x41CA31, then `_control87(0x9001F, 0xFFFFF)`. Probe times per call site in [performance.md](performance.md) §11. `ev_91eb3a47…` (perf-20261110). |
| 0x40B9BA (+0x40BAFE) | World render | 0x40BAFE is its tail (`jmp` at 0x40BAB3). Calls 0x40BCF0(0) and 0x40BCF0(1): `vtable[14h]` of each view with the pass index; the world view is 0x45084C (pass 0 → 0x459719 → 0x4597A4, pass 1 → 0x450A4E). `ev_89f7c631…`, `ev_13da66a1…`, `ev_faaa8ead…`. |
| 0x408AAB | Particle update | Walks the emitters, updates them (0x408E36 → 0x425018 → 0x424A9B / 0x424E33) and sorts them by distance (0x4087F3). Visual state only. `ev_084ed1cb…`, `ev_d8d52214…`. |
| 0x40D25B | Cloth flag draw | `thiscall(flag manager [0xC67364], byte frontOnly, byte lowDetail)`, `ret 8`; callers 0x450684 (world draw 0x44FC96, after the batch flushes) and 0x429429 (0x42922A), both after the cfg test of `[0xC67338]`. Sets render state 16h (`D3DRS_CULLMODE`) through 0x4203AB to 3 (CCW), or to 1 (none) with `frontOnly`, and restores it at the end. Then per queued flag (`[mgr+68h]`: count, `+10h` data, 34h bytes each: `+0` the index of its record in `[mgr+24h]`, `+4` passed to 0x40BEA5; the record: `+0Ch` source buffer index, `+10h` columns, `+14h` rows, `+1Ch/+20h/+24h` U scale, V scale, V offset, `+2Ch` a byte that picks the shader `[mgr+7Ch]` with `pixelxformColor` (0xBE0974) or `[mgr+80h]` with `blendColor` (0xB9A914), set from `+30h` through 0x405C87) it fills vertices when the grid or the source buffer differs from the previous flag's, and draws through 0x40D039 (indices from 0x42042E). The queue's count is zeroed at the end. It is the cloth flags' draw, not "shader/material parameters" (the reading of [performance.md](performance.md) §8, from those two strings). REA `ev_20b69500…`, `ev_f342b619…` (fastvertexfill-20261110). |
| 0x40D523..0x40D654 | Cloth flag vertex fill | Two loops over rows `[esp+14h]` and columns `[esp+18h]`: source vertex `[mgr+3Ch+index*4] + ([mgr+14h]*row + column)*20h` (position, normal, U, V) → front vertex at EAX−10h (U × `[esp+50h]`, V × `[esp+54h]` − `[esp+58h]`), then at 0x40D5C0..0x40D5FD the back vertex at EDX−10h, read back from the front one, normal × −1.0 (`[0xB856B8]`); skipped with `frontOnly` (`[esp+70h]`). `fastVertexFill` replaces them. |
| 0x40A6A2 / 0x40A5B1 | Dynamic vertex buffer: take a piece | 0x40A6A2 `thiscall(renderer, count, stride, int* first)`, `ret 0Ch`: aligns `used` to the stride and calls 0x40A5B1(`[renderer+660h]`, bytes, &offset), which locks `{buffer, size, used, byte reset}` at `used` with flags 0x1800 (`NOOVERWRITE \| NOSYSLOCK`), or from 0 with 0x2800 (`DISCARD \| NOSYSLOCK`) when the piece does not fit or `reset` is set, and writes a zero to the first and last byte under SEH. Returns the pointer; the caller unlocks (`[buffer]->vtable[30h]`). `cs`; REA `ev_9e4dad98…`. |
| 0x5AE756 | Dynamic vertex buffer: create | When `[renderer+660h]` is null: size 0x200000 (or a cfg value, the lookup 0x46A144 of the ID at `[[0xD6FBC8]]`), `device->CreateVertexBuffer(size, 0x208, 0, 0, &record[0], 0)` at 0x5AE7D5: `D3DUSAGE_DYNAMIC \| D3DUSAGE_WRITEONLY`, FVF 0, `D3DPOOL_DEFAULT`. `cs`; REA `ev_4b205dae…`. At runtime (2026-11-10, `fastVertexFill verify`): `GetDesc` gives usage 0x208, pool 0, 2,097,152 bytes, and the lock points into private memory with protection 0x404 (`PAGE_READWRITE \| PAGE_WRITECOMBINE`). |
| 0x48241C | Unit bounding box | `thiscall(unit)`: rebuilds `[unit+B4h]+34h…+74h` from the model bounds and orientation through 0x422DC6; calls `_control87(0x9001F)`. Reached by the simulation and, through 0x4592FE (which clears dirty bit `[[unit+4]+5]` & 8 and sets bit 5 of `[[unit+4]+1]`), by the render. `ev_de03df52…`; writes seen with `trace_writes.py` (2026-11-10). |
| 0x452D7B…0x452DC5 | Per-unit spring (render) | In 0x452B8E under the per-unit draw: damped spring on `[unit+B4h]+DCh/+E0h` with the frame time. Zeroed by the simulation at 0x47253F (0x4722E6). Hardware write breakpoint, 2026-11-10. |
| 0x468450 | File stream open | Checks for the `l33t` compressed header (inflate stream, vtable 0xBA3318); otherwise uses a raw stream. `ev_bb0bb32c…`. |
| 0x4683F4 | Raw file stream read | One `ReadFile` per call, no buffering. 0x599121 reads 4 bytes through 0x5990D1; 0x43B8FF reads a 16-byte header as four such reads. `ev_1c4e2090…`. |
| 0x55A185 | Single-instance check | `CreateSemaphoreW(NULL, 1, 1, name)` → `[this+880h]`, then `WaitForSingleObject(h, 0)`; a timeout (0x102) jumps to 0x6D1039. The name is formatted as `Global\%s` (0xBE3768) when `[esp+18h]` is 2 (inferred: the NT platform ID), so it is shared by every copy of the game in every session. Observed 2026-10-28: the name is `Global\Age3` (logged by `multipleInstances`), and a second copy started from another folder stops at "Sólo puede ejecutarse una copia del juego al mismo tiempo"; that 0x6D1039 leads to that dialog is inferred. `multipleInstances` renames this one semaphore per folder. Capstone listing (not REA): `rea/evidence/age3y-b1a1dab7/single-instance/`. |

### Last in line and the XS runtime (2026-11-11, WoL's stutters)

What runs in WoL's long frames ([performance.md](performance.md) §9, "What WoL's stutters are"). REA bundle
`rea/evidence/age3y-b1a1dab7/wol-stutter-20261111.json` (Ghidra 12.1.4, read only: no names written to the
database); capstone listings for the rest.

| VA | Role | Status | Notes |
|---|---|---|---|
| 0x4918A8 (+ cold chunk 0x68FB0C…0x68FC51, which Ghidra lists as FUN_0068FB04) | **LastInLine recompute** | confirmed | `thiscall(tree, Player*)`, `ret 4`. Runs only when the player is not null and `[tree+11h]` is set; clears it. For each entry i of the tree: bit 22 (ForceLastInLine) set → set bit 16; else scan every other entry j (0…count−1, the template record when j's entry is null) for one whose definition has a prerequisite "TechStatus active i" (0x94BC1D) and that the player can obtain (0x4C5725); found → clear bit 16, none → set bit 16 unless bit 32 (YPNeverLastInLine). Then, for the local player (`[game+3C0h]`), `[[game+920h]]->vtable[4]` (a UI refresh). Cost: count × (count + prerequisite entries) checks. `ev_011dfe82…`. Callers 0x491A39 (in the per-player loop of 0x491A40) and the forced update 0x852850 (`ev_47eb4e7d…`). |
| 0x94BC1D | Definition has "TechStatus active <id>" | confirmed | `bool thiscall(entry, techId)`, `ret 4`: over the definition's prerequisites (`[def+1Ch]`, byte length `[def+20h]`, item getter 0x4C5DBD): type byte `+5` = 1, status byte `+0Ch` = 2 (active), `+8` = the tech ID. Read only. `ev_011dfe82…`. |
| 0x4C5725 | Can the player obtain the tech | confirmed | `bool thiscall(Player*, techId)`, `ret 4`. Reads the entry's bits 4 and 28 with `[player+50Ah]` and `[player+50h]`, the list `[player+3B4h]` (0x447F3C), then the civ lists through 0x4C5DA9 / 0x4C5CA1 / 0x4C5D2E / 0x4C5AFB. A capstone walk of it and of every callee down to the leaves finds **no memory write** except the stack. `ev_22d59ab1…`. |
| 0x94AE8C | Set LastInLine dirty | confirmed | `thiscall(root = [world+7Ch], playerId, bool)`, `ret 8`: writes `[tree+11h]`. Callers (`ev_d652dac7…`): 0x94CF27 (activate), 0x94C33A (set obtainable), 0x94CDB3 (set unobtainable), each only for a tech with bit 18 (HomeCity); and 0x8D002C, 0x8D554F, 0x8DCFC0 (not read). |
| 0x506A41 | Set the tree's `+10h` dirty byte | confirmed | Same shape as 0x94AE8C (`ev_2f47b251…`); see "Tech prerequisites" above. |
| 0x94CF27 | Activate a tech for a player | confirmed | `thiscall(entry, Player*, …, bool* out, …)`. Unless already active (bits 18/29 and the research count `[entry+21h]` against `[def+32h]` decide), sets bits 0, 1, 5, 6, the time `[entry+1Ch]`, 0x94C285(1.0), 0x506A41, 0x94AE8C for a HomeCity tech, bumps `[entry+21h]`, applies the effects through 0x94DAE1 → 0x7F7E97, sends the "researched" message unless the tech is Shadow (bit 11) or HomeCity (bit 18). This is the "recursive evaluator" §9 named in 2026-10: a tech's effects reach other techs and units, so it nests. `ev_91f91cee…`. |
| 0x94C33A / 0x94CDB3 | Set a tech obtainable / unobtainable | confirmed | Write bit 0, clear bits 1 and 3, set bit 6, then 0x506A41, and 0x94AE8C for a HomeCity tech. `ev_d6296011…`. |
| 0x852850 | Forced tree update | confirmed | Sets `[tree+10h]` and `[tree+11h]`, then 0x4919CE and 0x4918A8. `ev_d6296011…`. |
| Tech flag bits | parser 0x622B7D (returns at 0x6B11DB…, 0x622F80, 0x6232CE/DC) | confirmed (capstone) | The flag name gives the bit index in the entry's bitset: Volatile 2, AgeUpgrade 4, DynamicCost 7, AlwaysShowButton 8, HideFromDetailHelp 10, Shadow 11, UniqueProtoUnitInstance 13, UpgradeTech 17, HomeCity 18, TeamTech 19, OrPrereqs 21, ForceLastInLine 22, UniqueTech 23, CountsTowardEconomicScore 24, CountsTowardMilitaryScore 25, DoNotQueue 26, NativeDance 27, RevoltTech 28, YPInfiniteTech 29, CheckLandHCGatherPoint 30, CheckWaterHCGatherPoint 31, YPNeverLastInLine 32, YPConsulateTech 40. Bit 16 is not a flag: it is the computed LastInLine. |
| Readers of bit 16 | 0x69672C, 0x9AD72F, 0x9B757A | confirmed (capstone), not complete | Each `push 10h; call 0x44D863` (the entry's bit test) inside the command-panel builders 0x695BB6, 0x9ACAF4, 0x9B687E (strings `trainInSelectedByID`, `researchByID`, `uiBuildMode`). No `cmp [r+8],10h` + byte test of bit 16 elsewhere in `.text`. **Inference:** a UI flag (which upgrade button to show); other access patterns were not searched. |
| 0x67A1FD | Player update | confirmed | Asserts `.\player.cpp`; calls the AI update at 0x67A6D4. Reached from the world update 0x481CE9 → 0x490360 → 0x490960. |
| 0x720CA7 | AI update (`BAI::update`) | confirmed | String `P#%d (%s) BAI::update:`; calls `BXSRuntime::interpretRules` at 0x721203. |
| 0x428E1F | `BXSRuntime::interpretRules` | confirmed | `thiscall(runtime, int context, int currentTime, int timeLimit, …)`; data = `[[runtime+30h]+4·context]`; logs `BXSRuntime::interpretRules: currentTime=%d, timeLimit=%d:` when the byte `[[runtime+10h]+1Fh]` is 1; sets the global 0xC665F0 = `[runtime+4]` while it runs; runs 0x423B3D(`[runtime+20h]`, data, time, limit, &out) until the rules are done. `ev_8dc255be…`. |
| 0x42CF3F / 0x42CEED / 0x42B496 | XS call a function / evaluate loop / one evaluation step | confirmed | 0x42CF3F sets up a function on the data's stack (errors "invalid function entry", "failed to setup function on stack"); 0x42CEED steps 0x42B496 while `[data+E0h]` > 0. The data's XS call stack: `[data+DCh]` entries of 18h bytes, count `[data+E0h]`, entry `+0` the function ID. The interpreter's strings ("evaluateCode PC=%d", "Enter '%s' function.", "Infinite recursion limit") are in the chunks around 0x42B990…0x42CBCA. `ev_8dc255be…`. |
| 0x42B45A | XS function name | confirmed | `thiscall(program, id)`: `*[[program+30h]+4·id]`, count `[program+34h]`. `ev_2b868d6a…`. |

## IAT slots (from the loader stub and early patches)

LoadLibraryA 0xB84228 · GetProcAddress 0xB84354 · MessageBoxW 0xB8459C · ExitProcess 0xB8438C ·
HeapAlloc 0xB84180 · HeapReAlloc 0xB841B8 · MultiByteToWideChar 0xB841FC · lstrcpyW 0xB84290 ·
GetCurrentDirectoryW 0xB84348 · FindClose 0xB84380 · lstrlenW 0xB843A8 · lstrlenA 0xB843AC ·
lstrcpynW 0xB843B0 · FindNextFileW 0xB843D0 · FindFirstFileW 0xB843D4

All 15 are **confirmed** by parsing the stock exe's import table (2026-10-27, Python, not REA):
every slot resolves to the named KERNEL32/USER32 import.

Timing, threads and Direct3D (confirmed the same way, 2026-10-28): timeGetTime 0xB8400C ·
timeEndPeriod 0xB84010 · timeBeginPeriod 0xB84014 · Direct3DCreate9 0xB84164 (the exe's only d3d9 import, bound at
load, no delay load; written only by `src/d3d9hooks.cpp`, for `rendererOption` and `perfStats`) · GetSystemInfo 0xB841D0 ·
QueryPerformanceCounter 0xB8426C · QueryPerformanceFrequency 0xB84270 · CreateEventW 0xB84274 ·
CreateThread 0xB84314 · Sleep 0xB84324 · WaitForSingleObject 0xB84328 · SleepEx 0xB84364 ·
GetTickCount 0xB843A4 · SetThreadPriority 0xB843E0 · SetPriorityClass 0xB843E4 · GetPriorityClass 0xB843E8 ·
GetThreadPriority 0xB843EC · CreateSemaphoreW 0xB843F0 (replaced by `multipleInstances`) · SetEvent 0xB84400

File I/O (confirmed the same way, 2026-10-28; `bufferedFileReads` replaces the first six): CreateFileA 0xB842A4 ·
CreateFileW 0xB84304 · ReadFile 0xB8424C · SetFilePointer 0xB84244 · CloseHandle 0xB84330 ·
DuplicateHandle 0xB843A0 · GetFileSize 0xB842A8 · GetFileType 0xB84218 · CreateFileMappingW 0xB8427C ·
MapViewOfFile 0xB84278. The exe imports no `msvcrt`: its C runtime is static and uses these slots too.
