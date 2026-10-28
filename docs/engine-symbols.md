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

## Poison leftovers in the stock engine (2026-10-28, for the DE-style poison)

Evidence: `cs` scans of the stock exe and the tactics files extracted from `Data*.bar`.

| What | Where | Notes |
|---|---|---|
| Flag tags of the `<Unit>` tag map | registered at 0x51D000..0x51E400 through 0x59B738(name, handler); the map is described under "Parsers" below | 105 tags, `MaxHitpoints` … `UseBuckets`. Each flag handler sets a bit in the bytes that `[[target]+64h]` points to, the same flag bytes the action parser uses (`[action+64h]`). Bits: Active 0, Persistent 2, SingleUse 3, AddResourcesFasterWhenOwned 5, MuteDamage 6, ReflectDamage 7, **Poison 8** (0xA11D4D), Throw 14 (0xA11D5B). |
| Throw reader | 0x7F9DDA | `test byte [esi+9], 40h` in the attack rollover text (string 0xA43C). It matches the Throw bit if `esi+8` is that flag storage; the object in ESI was not identified (inference). |
| Poison reader | none found | No `test byte [reg+9], 1` on a tactic action and no dword-wide test of 100h. The one hit, 0x810EFA, is an unrelated UI object. Not exhaustive: an accessor with a computed mask would escape these scans. |
| Unit action type names | table at `[esi+2000h]`, around 0x5248C6 | … `EjectUnit` 1Fh, **`Poison` 20h**, `MoveRetry` 21h … The action type byte is at `action+60h`. Only types 2..0Ch and 38h are written as immediates by their constructors, so it is not established whether type 20h has a class. |
| Protoaction type names | table at `[esi+19B8h]`, around 0x52280F | `Decay`, `Gather` 3, `HandAttack` 4, `Heal` 5, … (Heal = 5 matches 0x4EE797(…, 5, …) in the heal search). |

**Parsers** (`ev_591176ac…`; the pseudocode is saved locally as `rea/evidence/age3y-b1a1dab7/pseudo_protoaction_parser_5f98a0.c`, not in the repository).

| What | Where | Notes |
|---|---|---|
| `<Unit>` tag map | FUN_0051CE1D, map at `this+0Ch`, filled through 0x59B738(name, handler) | Called from 0x51DB46 (a second map at `this+C2Ch` is initialized there too). 105 entries: the `protoy` unit tags (`DBID`, `Icon`, `AnimFile`, `MaxHitpoints`, `Flag`, `Lifespan` 0x5FCF4B, `ProtoAction` 0x5FA158, `Armor`, …), followed by action-style tags (`Rate` … `UseBuckets`, including `Poison`). Handler shape: `handler(?, node, target)`, `ret`. Attributes are read with 0x598F37(node, "attr", &out); text is converted with 0x59AC86 (float). |
| `<ProtoAction>` handler | 0x5FA158 | `edi = target = proto`, `ebx = node`. It looks up the action named by the node's `<Name>` in the proto's action set `[proto+44h]` (0x5F8FDB). If found: `FUN_005F98A0([proto+44h], proto, action, node)`. If the proto has no such action (e.g. no tactics entry), it goes to 0x5FC891 without parsing. |
| Action parser | FUN_005F98A0 | `thiscall(actionSet, proto, action, node)`. An if-chain of 87 compares `0x443C10(nameStr, L"Tag", 0, -1)` (0 = equal), shared by `.tactics` `<action>` and `protoy` `<ProtoAction>`. In the loop, EDI = child node and ESI = its name (the XMB element name `[[node+4]+18h][node+18h]`); the text is `*(wchar_t**)(node+14h)`. `action[1]` = action name ID (from `<Name>`), `action[2]` = type, `[action+64h]` = flag bytes. The last compare is `ModifyExclusive` (0x5FA10F); an unknown tag falls through 0x5FA11E to the loop increment 0x5FA126 and is silently ignored. Handlers also return to 0x5FA126, so only 0x5FA11E is a safe "unknown tag" hook. |

**Stock data.** No tactics file (209 checked) and no `protoy.xml` entry uses `Poison`, `MuteDamage` or `ReflectDamage`. The only "poison" in the data is `NatPoisonArrowFrogs`, an ordinary tech. So the flag parses, but no damage-over-time code was found behind it.

## Rendering, threads and timing (2026-10-28, for the performance investigation)

Full write-up and evidence: [performance.md](performance.md). REA bundle: `rea/evidence/age3y-b1a1dab7/bundle-perf-20261028.json`.

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
GetThreadPriority 0xB843EC · SetEvent 0xB84400
