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
| `+0Ch` / `+10h` | units by ID: array, count (index = ID & 3FFFFh) | confirmed | cs, `damageOverTime` in game |
| `+58h` | player array | confirmed | cs (TakeDamage), `damageOverTime` in game |
| `+5Ch` | player count | confirmed | E3, 0x49A98A |
| `+F8h` | step count: +1 per world update (0x481A87) | confirmed | cs, `damageOverTime` in game |
| `+108h` | game time, ms (advanced by the world update FUN_00481A57) | confirmed | cs, `damageOverTime` in game |
| `+31Ch` | pop-cap-like limit read by PopLimit | new | cs |
| `+6912h` | shared-resources flag | new | E3 |

Other objects:

| Object | Fields | Status | Evidence |
|---|---|---|---|
| Player data | `[player+80h]+0Ch`; civ at `[[pd]+20h]`; team at `[pd+10h]` | upstream, unverified | |
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
| Player by ID | 0x44CB21 | `thiscall(world = [[C66234h]+13Ch], int playerId)` → player or 0. |
| Unit by ID | 0x44CC6D | `thiscall(world, int unitId)` → unit or 0; the position is at `unit+14h` (3 floats). |
| `aiGetHCGatherPoint` | 0x728050 | The gather unit's position, or the invalid vector at 0xC665E4 when the unit is gone. A dead unit is therefore detectable: `0x44CC6D` returns 0. |
| `aiSetHCGatherPoint` | 0x726236 | Calls 0x82D9CB(game, playerId, unitId). |
| 0x82D9CB | thiscall on the game object | Builds and queues a **network command** (0x5695FC with type 4, then 0x5696E1). It does not write `[hc+18Ch]` itself, so simulation code must not call it on every client. |
| Current player | `[0xC66664]` | Used by the AI syscalls as "the calling player"; confirms the role in the globals table. |

| Water gather unit ID | `[hc+190h]` | The land/water pair is serialized together at 0x8D30C7..0x8D310E (player save/load). The player caches them at `[player+A4h]` / `[player+A8h]`, then writes them through 0xA3FEB8. |
| Command type 4 | factory 0x5695FC → jump table 0x5694E0, case 4 (0x568CE2) | `new(0xAC)`; ctor 0x7D549A, vtable 0xB87DB8. Fields: `+8Ch..+94h` = position (init −1.0f), `+98h..+A0h` = IDs (init −1), `+A8h` = 3. FUN_007D551B validates a position and shows string 0x8546 on failure. Slot 2 (0x7D54F7) is the destructor. Which slot executes is not established. |

**Dynamic trace (2026-10-28).** Captured with hardware read/write breakpoints on `hc+18Ch`/`hc+190h` of player 1. Reproduce it with `python -I tools/re/trace_writes.py gather.txt hc:1+0x18C hc:1+0x190 --rw` (the original log, `hwbp-log.txt`, is local evidence under `rea/`). The game starts with land = water = −1.

| Instruction | Role | Notes |
|---|---|---|
| 0x4C6BC6 | Frequent reader (444 hits) | Called from 0x4C6D3D / 0x4C61DC, i.e. FUN_004C6CAE: "get a valid gather unit". |
| 0x8527F6 | Setter, when the user moves the flag | In FUN_008527EC: `void __thiscall(hc, int unitId) { [hc+18Ch] = unitId; }`. Reached from the command path through 0x7D5810 → 0x64D31F → 0x481BC7. 0x85282F is the water twin. |
| 0x6697FF | Cleared to −1 when the TC was deleted | Unit-removal path, via 0x8584BA ← 0x511901 ← 0x66AEA5. |
| 0x669E45 | Immediately set again, to the other building | Inside FUN_004C6CAE, at `LAB_004c6cb2`, `if (store) [hc+18Ch] = unit[4]`. |

**Stock already has a fallback** (FUN_004C6CAE). When the gather unit is gone it takes the first alive, valid unit of the player from these type lists, in this order: `db+5E14h` (probably TownCenter) → FortFrontier (`+6034h`) → WarHut (`+6074h`) → Blockhouse (`+6044h`) → NoblesHut (`+606Ch`) → `+19B0h` → `+5EBCh` → `+5F6Ch` (names not resolved).

Each candidate must pass `vtbl+A4h`, `0x44DDB4` and `0x4802C6 != 1`. A building outside these lists is never chosen. Ev: `ev_dc7644827b43…`.

Readers of the gather unit through `[player+84h]` (the HC-specific pattern): only 0x728089 (aiGetHCGatherPoint) and 0x8D30D1 (save/load). The shipment-arrival and flag-drawing code therefore read it some other way, probably through a cached HC pointer.

Still open:
- the code that writes `[hc+18Ch]` when the point is set;
- the unit-removal path;
- where shipment arrival resolves the spawn point.

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
| Is-a test | 0x44D7FA | `bool __thiscall(proto, int typeId)`, `ret 4`. A proto ID compares against `proto+8` (or `proto+4`); an abstract ID tests bit `id - protoCount`. Use this for IDs from the name table. |
| Raw bit test | 0x44CAC4 | `bool __thiscall(proto, int bitIndex)`, `ret 4`. Takes the **abstract index** (already minus protoCount), not a table ID. |

**Consequence.** Every abstract type that `protoy.xml` may use is in the exe: 153 of the 155 non-proto `<UnitType>` names in stock `protoy.xml` are strings in the exe. The other two are `AbstractTypeVictoryPointBuilding` (ignored by stock) and our own. A `<UnitType>` whose name is not registered is silently dropped. A new marker type must therefore be added to the table, which `src/unittypes.cpp` does at 0x51BA31.

**Healing.**

| What | Where | Notes |
|---|---|---|
| Hit points | `unit+64h` (float) | Found by polling unit memory for a float that dropped when hit and rose while an Indian monk healed, then confirmed with a hardware write breakpoint (local evidence `hwbp2-log.txt`; reproduce with `tools/re/trace_writes.py hp.txt unit:Explorer+0x64`). Writers 0x4820B7 (FUN_004820A1, which sets the value) and 0x4A17A9 (clamp to max). |
| Max hit points | 0x480408 | `float __thiscall(unit)` (st0). |
| Add hit points | FUN_004823A3 | `(amount, 1)`, a wrapper over FUN_004820A1. |
| Heal tick | FUN_009E0B53 | The heal action applying one tick. EDI = target, ESI = heal action, `[esi+10h]` = healer, `[esi+14h]` = target ID. Action state byte at `action+61h` (0 start, 8 healing, 10 stop). |
| "Target busy" check | 0x9E0C79..0x9E0C9E | `[target+58h]` = the target's current action. If it exists and `0x4802D4(-1)` (moving) or `0x9CA5AC` (fighting) returns 1, the tick ends at 0x9E0D3F. Otherwise it heals from 0x9E0C9F. |
| Automatic heal search | FUN_009CD865 | `thiscall(owner)`, healer at `[owner+4]` (EBP in the body). It returns at once unless `[[healer+5Ch]+44h]` is set. It runs a unit query around the healer (world `+184h`, 0x49A098; result entries of 38h bytes). It takes the first candidate that passes every check: not the healer itself; HP ratio (0x45F295) in [1e-6, 1); `vtbl+A4h`; `[c+58h]` not null; **0x44F1A7 idle**; not abstract bit 6 (0x44CAC4); not flag 0x42 (0x44D863); 0x4EE797(player, healer, c, 5, …) for action type 5; 0x9C2E40(5, 8) ≤ 0; and the reach test 0x7FCF2D. Then it starts the action through 0x9CBDC4(id). Called from 0x68C14E with `ecx = [unit+58h]`. |
| Target is idle | 0x44F1A7 | `bool __thiscall(actionManager)`. True when `[mgr+24h]` (current action) is null or has type byte `[action+60h]` = 7. Otherwise it returns false, except for a per-player case (`[player+4FCh] = 1`, 0x45FC1A). |
| Command predicate | FUN_004C6CD7 | `bool __thiscall(?, word code, target, result*, out*)`, `ret 10h`. `code - 8` indexes the byte table at 0x4C726C → jump table 0x4C7230 (15 cases); out-of-range codes return true. Code 0x41 (case 8, 0x4C6D58) requires: target alive (0x44DDB4), `[target+68h] != 0`, HP < max, not fighting (0x9CA5AC), no action of type 0x35 (0x4C72E5), then 0x9C0B73. Code 0x42 (case 9) requires the same HP/fighting checks **and** an action of type 0x35. `this` is the **player**: case 11 reads `[this+84h]`, the home city. Case 8 overwrites it with the target. 12 callers, e.g. 0x695510 with code 0x41. The dynamic trace below never reached cases 8/9 while surgeons healed, so the predicate is not on the heal path. |

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
| Army membership | unit flag 37h (bit 7 of `[[unit+4]+6]`) | Set at 0x8C2F2D after FUN_008C2544 adds the unit to an army. FUN_009C0562 (`[[unit+B4h]+C8h]` → `+44h`, else −1) gives the unit's army ID; `[world+B8h]` is the army manager (FUN_004A9203 finds an army by ID); FUN_008C264A adds an attacker ID to an army's list and stamps `[army+34h]` with the game time. AI armies use them. |
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
| Unit | vtable 0xB934B8 (ctor 0x9C4A8F; base ctor 0x4F6A70, vtable 0xB93190) | `+10h` ID, `+44h` player object (`[+0]` = player ID), `+58h` action manager, `+5Ch` proto, `+64h` HP (float), `+6Ch` container unit ID (−1 when not contained), `+70h`/`+74h` contained unit IDs and count. |
| Unit alive | unit vtable slot A4h, 0x44D019 | `bool __thiscall(unit)`: state bit 8 of `[unit+4]` set, bit 12 clear, HP > 1e-6. The stock code tests it before special damage and in the Poison event handler. |
| World | `[game+13Ch]` | Units by ID: `[world+0Ch]` array, `[world+10h]` count; index = ID & 3FFFFh, and `[unit+10h]` must equal the ID. Players: `[world+58h]` array, `[world+5Ch]` count. Game time: `[world+108h]`, ms. |
| World update | FUN_00481A57 | `bool __thiscall(world, int, int deltaMs)`, `ret 8`: raises the step count `[world+F8h]` by 1 (0x481A87), adds deltaMs to `[world+108h]`, then runs the world (the body the rendering section lists as 0x481B1C). Two flags at `[world+691Bh]` / `[world+691Eh]` branch to out-of-line blocks (0x6AE55F, 0x6AE845) before the step count; both come back to 0x481A7F, just before it. 0x481A87 is the only `add dword ptr [esi+0F8h],1` in the exe, and no branch after it leads back, so each call adds exactly 1. Called directly only from 0x482044 (FUN_0048202E), and also listed in the vtable at 0xB95730 (slot 6F4h). It runs for other worlds too: it compares `this` with `[game+13Ch]` at 0x481D01. |
| Player's proto | FUN_0045311B | `Proto* __thiscall(player, int protoId)`, `ret 4`: the player's copy `[player+E0h][id]` (count `[player+E4h]`), else the database proto. IDs at or above the count are per-player dynamic protos, `(player ID + 1) × 100000 + index`, from `[player+ECh]` (12-byte entries, count `[player+F0h]`). It only reads (`ev_7e87e1bc…`). |
| Proto ID by name | FUN_005A2346 | `int __thiscall(db, const char* name)`: a linear search of `[db+54h]`/`[db+58h]` comparing `[proto+10h]` with FUN_004028B4; −1 when not found. It only reads (`ev_78f40452…`). |
| Proto | | `+4` proto ID (the index in `[db+54h]`; TakeDamage's attacker proto ID is `[[unit+5Ch]+4]`), `+10h` name, `+44h` action set, `+ACh` Lifespan. |
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
| Tech by name | 0x600BE1 | `int(const char* name)`; −1 when absent. |
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

| What | Where | Notes |
|---|---|---|
| TownCenter proto ID cache | `db+5E08h`, written at 0x5EE8ED through 0x5A2346("TownCenter") | 25 code references (e.g. 0x46481C, 0x4C6BF3 in the shipment-point fallback); not reviewed one by one. `db+5E0Ch` caches `CoveredWagon`. |
| `"TownCenter"` string 0xBCC600 | refs 0x5EE8E2 (the cache), 0x66FC0D/0x66FC27 (unit type lookup by name), 0x79DEBC (a UI table), 0x7DEEB1 (call 0x82FAD6), 0x82E481 | 0x82E45B is the **start camera**: it looks at the first of `camera start`, `TownCenter`, `CoveredWagon`, `Explorer`, `Settler`, `Unit` that the world has. |
| Who places the starting TC | the random map script | e.g. `great plains.xs`: `rmAddObjectDefItem(startingTCID, "TownCenter", 1, 0.0)` (a `CoveredWagon` for a nomad start); the civ's `<startingunit>` / `<townstartingunit>` come from `rmCreateStartingUnitsObjectDef` (`Special_StartingUnits`, 0x90D69A, 0x924921). |
| `StartingTC` | — | Not a string in the stock exe, WoL's `age3*.exe`, `uhc.dll`, `wol.dll`, or WoL's `protoy.xml` / `civs.xml` / `techtreey.xml`. |

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
