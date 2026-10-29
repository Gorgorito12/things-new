# How UHC.dll works

The internals of every implemented feature, for modders who want to understand them or rebuild
them in their own DLL. Addresses are virtual addresses in the stock Steam `age3y.exe`
(`b1a1dab7…`, see [binaries.md](binaries.md)); they are only valid for that build. The verified
patch sites are in [uhc-address-map.md](uhc-address-map.md) and the engine functions and object
offsets in [engine-symbols.md](engine-symbols.md). The practical steps for copying a feature
into another DLL (sites to check, files, build) are in
[porting-to-another-dll.md](porting-to-another-dll.md).

Notation: `[x]` is the 32-bit value at address x, `NNh` is hexadecimal, `B` means bytes.

## 1. Startup

1. **The loader stub.** A UHC-patched exe starts at a 79-byte stub (VA `0xB836BE`) instead of
   the game's entry point. The stub calls `LoadLibraryA("UHC.dll")` and
   `GetProcAddress("_UHCMain@0")`, calls `UHCMain`, then jumps to the original entry point
   `0x5876AC`. The byte layout is in [binaries.md](binaries.md).
2. **UHCMain runs before the game initializes.** The C runtime and the game objects do not
   exist yet: the game object pointer `[0xC66234]` is still null. So at startup a feature only
   patches code and prepares its own data. Anything that needs game data is resolved later,
   from inside the game:
   - `hcShipmentPointFallback` resolves proto names the first time its hook runs (`FirstTC` is a
     keyword and needs no lookup);
   - `civFirstTC` reads `<firstTC>` while `civs.xml` is parsed, and resolves the proto name on
     its first use, and again whenever the database's proto table changes;
   - `healNonIdle` and every other key that takes a `<UnitType>` get the type's ID from a hook in
     the data loader;
   - `damageOverTime` records its tags while the data loads and resolves them on the first hit;
   - `techPrereqRecheck` lists its techs, and `danceBonusCivs` resolves its civ names, on their
     first use after each data load;
   - `techRenameEffect` registers its effect type from a hook in the database init.
3. **Host guard** (`src/dllmain.cpp`). Before touching any fixed address, the DLL checks that
   the exe is the stock build plus the loader:
   - module base `0x400000`;
   - PE TimeDateStamp `0x49EF86AC` and SizeOfImage `0xB22000`;
   - the string `"UHC.dll"` that the loader patch writes at `0xC65016`.

   Otherwise it logs `host is not a UHC-patched age3y.exe` and does nothing.
4. **Working directory.** Right after the host guard, before it reads the cfg, the DLL makes the
   exe's folder the working directory, as UHC 1.10 does (`UseExeFolderAsWorkingDirectory` in
   `src/dllmain.cpp`). A mod then
   starts the same way from a double-click, a shortcut or a launcher, and `ignoreRegistryPath`
   reads the mod folder.
5. **Configuration.** The loader patch stores the config path at `0xC65083` (at most 20 wide
   characters, default `Startup\uhc.cfg`). The DLL resolves it against the exe's folder and
   parses it (`src/config.cpp`). The parser accepts both `key value …` and UHC 1.10's
   `key=value` with `//` comments, which is the syntax the UHC 1.10 patcher writes. The DLL then
   runs every feature in the order of `kFeatures` in `src/features.h`. Each returns
   *not configured*, *applied* or *failed*.

## 2. Verify, then patch

Every byte the DLL writes is checked first:

1. `tools/gen_sites.py` lists each **site**: a name, a VA and a length. It reads those bytes from
   the stock exe and writes them into `src/generated/sites.h`. It refuses to run on any exe whose
   SHA-256 is not the stock one.
2. At runtime, a feature calls `VerifyAll(feature, {sites…})` (`src/patch.cpp`). It compares
   live memory with the expected bytes and, on any difference, logs
   `site X at 0x… does not hold the stock bytes` and writes nothing.
3. Then it writes with `WriteJmp` (a `jmp rel32`, NOP-filled to the given length),
   `WriteDword` or `WriteBytes`. Each write goes through `VirtualProtect` and
   `FlushInstructionCache`.

A site's range covers the bytes that are overwritten **and** the code the hook relies on: the
instructions it re-executes and the continuation it jumps to. A different build, or another
patch at the same place, therefore makes the feature refuse to apply instead of corrupting the
game.

## 3. Hook conventions

The hooks are MASM files in `src/hooks/`.

- **Entry and exit.** A hook is entered through a 5-byte `jmp` written over stock code. It
  re-executes (or deliberately replaces) the instructions it overwrote, then leaves with
  `jmp dword ptr [label]`, where `label` is a data dword holding the absolute continuation
  address.
- **No relocation.** Nothing is copied to a trampoline. The UHC 1.10 relocator mishandles some
  relative branches and decodes from the middle of instructions (see the defects in
  [uhc-address-map.md](uhc-address-map.md)); writing the re-executed instructions by hand
  avoids that whole class of bugs.
- **Choosing a site:**
  - it starts on an instruction boundary;
  - no branch elsewhere in the exe targets the inside of the 5 overwritten bytes (scan all
    `rel8`/`rel32` branches; see [developer-guide.md](developer-guide.md));
  - you know which registers and flags are live at the continuation.
- **Registers.** Keep ESP balanced, and keep EBX, ESI, EDI and EBP unless the replaced stock
  code set them. Change EAX, ECX or EDX only when the continuation overwrites them before reading
  them; each hook's comment says which applies. Preserve the flags when code after the hook
  branches on flags set before it: `customRevolutionBanners` is entered with the result of a
  string compare in the flags.
- **Calling engine functions.** They are `thiscall`: ECX holds `this`, arguments are pushed right
  to left, and the callee pops them (`ret N`). A `bool` result is in **AL only**: test AL, not
  EAX. The upper bytes of EAX are garbage, which is upstream's `asianCivs` defect.
- **Calling the DLL's C++ from a hook.** Declare the function `extern "C" __stdcall` and wrap the
  call in `pushad`/`popad` when the hook must preserve registers.
- **Wrapping a whole function** (`damageOverTime`). A `jmp` over the function's first instructions
  leads to a `__fastcall` C++ wrapper. Its frame is the thiscall frame: ECX = `this`, EDX unused,
  the stack arguments in place, and the wrapper pops them as the stock function would. The
  wrapper reaches the stock body through a small MASM trampoline that re-executes the stolen
  prologue and jumps past it. The prologue's instructions are written out by hand, never
  relocated.
- **Redirecting a call** (`customHotkeyContexts`, `wonderPanelSkipAuras`, the `dodgeAnyUnit log`
  wrapper, `civFirstTC`'s map placement). `WriteCall` rewrites a stock `call` (5 B, `E8` and a new
  rel32) so that it calls the DLL. The new target takes the callee's exact frame (thiscall, the
  same arguments, the same `ret N`) and returns to the stock return address; `civFirstTC`'s target
  is a `__fastcall` C++ function with the thiscall frame, as in the previous point.
- **Patching a constant** (`abilitySlots`). `WriteDword` replaces an immediate operand; no code
  runs in the DLL.
- **A C++ object with an engine vtable** (`techRenameEffect`). The DLL builds a copy of a stock
  vtable, verified in place, replaces some slots with `__fastcall` functions (ECX = `this`, EDX
  unused: the thiscall frame), and gives engine-allocated objects that vtable.
- **Data-load callbacks.** `OnDatabaseLoad` (`src/unittypes.h`) calls a feature on every data
  load, from the abstract-unit-type hook below; `damageOverTime`, `techPrereqRecheck`,
  `maintainWaitForPop` and `lifespanAfterConstruction` use it to drop state that belongs to the
  old data.
- **`TRACE_ONCE "text"`** (`src/hooks/common.inc`) writes `hook reached: text` to `UHC.log` the
  first time execution passes. It preserves every register, the flags and ESP, so it can sit at
  the top of any hook.

## 4. The features

### ignoreRegistryPath

At `0x57CB54` (FUN_0057CB0A), `jl 6420A1h` is taken when reading the install path from the
registry fails. The code at `0x6420A1` uses `GetCurrentDirectoryW` instead. The patch turns the
`jl` into an unconditional `jmp` (6 B). Since the DLL has already made the exe's folder the
working directory (section 1), the game reads the mod folder.

**Loose data files.** With the data read from the mod folder, a loose file in `data\` replaces
the copy inside the archives. This was verified with `homecitylevels.xml`: written loose, as
plain XML or as `.xml.xmb`, it set the level table read from the running game (`[db+60D0h]`).

### deckCardCount

FUN_007EEFF7 (`thiscall(database, level)`, `ret 4`) returns the maximum deck size of a home city
level:
- `20` when the level is negative;
- `25` when the level is past the end of the level table (`mov eax,19h` at `0x7EF005`);
- otherwise the level's `maxdecksize`, clamped to 20..25 (`0x7EF019`, `0x7EF026`).

The table is at `[database+60D0h]`, with its count at `[database+60D4h]`: records of 12 B,
`{xp, maxdecksize, -1}`, loaded from `homecitylevels.xml`. Read from a running game, the stock
table has 132 levels, with 20 cards at level 0 and 25 from level 50. The callers checked
(`0x852E45`, `0x865D1A`) pass the home city level `[hc+54h]`; FUN_007EEFF7 has 8 callers.

The patch writes N over the `19h` of `mov eax,19h`, and replaces the upper clamp
(`cmp eax,19h; jle; mov eax,19h`, 10 B) with a hook that clamps to N.

### basePop and extraPop

At `0x4581F3` (FUN_004581A1): ECX = extra population, EAX = population cap from buildings,
EDX = player data. Stock then:
1. limits extra to 50, out of line at `0x679618..0x67963B`;
2. limits the cap to extra + 200;
3. limits it to extra + `[[[C66234h]+13Ch]+31Ch]` (a world value, 200 in stock);
4. adds `[edx+4F4h]` if it is positive;
5. limits the result to 250.

The hook keeps steps 1, 2 and 4 with `extraPop` and `basePop`, and drops steps 3 and 5.

A second entry point covers `0x4581FC`: stock jumps there from `0x679611` with ECX = 0 when the
extra population is negative, and that path skips the first 5 patched bytes. Upstream misses it.

The shared-team-population path (`0x679641`) is not patched.

### noAILimit

FUN_00603AB7 builds, at `0x603B0B..0x603C4E`, a table of 11 (or 14 with TAD content)
personality names on the stack, storing its count at `[esp+40h]` and its address at
`[esp+50h]`. The game then loads `AI3\<name>.personality` for each entry.

At startup the DLL lists the folder, then sorts the names case-insensitively so every machine
gets the same order. The folder `L"AI3\"` (`0xBE3A98`) and the extension `L".personality"`
(`0xC0B39C`) are read from the exe.

The hook replaces the whole range. It stores the DLL's count and table, and also performs two
initializations that the range contained: `[esp+24h]` = 0 (the loaded-personality counter, used
as an array index) and `[esp+1Bh]` = 0 (the function's return flag). Upstream skips both.

### customRevolutionBanners

In FUN_0081A2B8, stock compares the revolution tech name with `"XPRevolutionOHiggins"`
(`repe cmpsb`) and, at `0x81A7CC`, skips the banner (`jne 81A7F1h`) for any other name. For
O'Higgins it builds a BString from `L"ui\ingame\politicians\REV_banner_chile"` at ESP+44h,
calls `0x638823` (set the texture, `this` = EBP) and destroys the BString at `0x81A7EC`.

The hook enters with the compare's flags:
- for O'Higgins it uses the stock path string;
- for any other name, `UhcRevBannerPath` returns `ui\ingame\politicians\REV_banner_<Name>`
  for `XPRevolution<Name>` (length-bounded), or nothing.

It then runs the same three stock steps, in the same stack slot.

### removeFameRestriction

Three independent parts:
1. **Politician cost lines.**
   - Detours at `0x80E490` (FUN_0080E20A) and `0x81943D` (FUN_0081922A) repeat the stock block
     that adds one cost line, once for each extra resource.
   - Resource indexes: 3 = Fame, 5 = XP, 6 = shipments, 7 = export; stock shows 0, 1, 2 and,
     in the first function, 7.
   - The block passes the line's owner to `0x4539D3`. Stock uses ESI in the first function and
     **EDI** in the second; upstream uses ESI in both.
2. **Home city icons.**
   - At `0x5C1E1F` the hook loads two extra textures through `0x58E3EB`:
     `ui\home_city\xp_hc_icon` and `ui\home_city\fame_hc_icon`.
   - It points slots 3 and 5 of the resource-icon jump table at `0x9A2180` to DLL cases that use
     those textures. Stock sends both slots to the default case, which shows no icon.
   - A texture that failed to load (`-1`) keeps the default case.
3. **"Fame trickle"** (upstream's name). At `0x51B026`, the imm32 of `push "FavoriteUnit"`
   inside the abstract-unit-type registration (see below) is replaced by the address of
   `"Fame"`. The built-in abstract type with that ID is therefore named `Fame`. How this leads
   to a Fame trickle has not been traced.

### removeConversionRestriction

At `0x9D5B6C`, stock tests a unit flag (`push 37h; mov ecx,edi; call 44D863h; test al,al`) that
restricts `ConvertGuardian` to treasure guardians, and skips the conversion with `je 9D5BADh`.
The patch writes two NOPs over the `je`.

### hcShipmentPointFallback

FUN_004C6B9E (`Unit* __thiscall(hc, bool store)`, `ret 4`) returns the unit that home city
shipments arrive at. The player's home city object is `[player+84h]`. It stores that unit's ID
at `[hc+18Ch]`; the water point `[hc+190h]` (0x855D71) and the consulate's drop point (0x855EC0)
are resolved elsewhere and the key does not change them.

What stock does:
1. **The stored point:** when `[hc+18Ch]` >= 0, it looks the unit up (`0x44CC6D`) and checks it
   with `0x85302C`: not null, alive (unit vtable slot A4h), `0x44DDB4` true, `0x4802C6` not 1.
   There is no owner and no type check. A unit that passes is returned. Otherwise, with
   store = 1, the ID is set to -1 (`0x6697F5`).
2. **The search** of 10 fixed types: `TownCenter` in the main body (`0x4C6BF1`, with inline
   copies of the same three checks), then nine types in the cold chunk `0x669804..0x669E2C`
   (Outpost, FortFrontier, WarHut, Blockhouse, NoblesHut, AbstractAgraFort, AbstractDaimyo,
   ypCastle, ypVillage). Each runs the stock unit query: `0x453618` (player), `0x45356D` (add
   type), `0x4532B4` (state 2, alive), `0x453484` (run), `0x453A36` (unit ID by index).
3. **Found:** `0x4C6CB2` writes the unit's ID to `[hc+18Ch]` when store = 1
   (`0x669E38..0x669E45`) and returns the unit.
4. **Nothing found:** the exit at `0x669E2E` returns 0.

Only two of the ten callers pass store = 1: FreeHomeCityUnit (FUN_00857E77, `0x857F06`), which
creates nothing when 0 comes back (`0x857F3F`), and FUN_00858299 (`0x8584B5`). The others, the
command panel among them (`0x6966D4`), only read, possibly every frame.

The hook sits on the "nothing found" exit at `0x669E2E`. It tries each cfg entry in order:
- **a proto:** the same query and the same three checks as the stock block `0x6698B4..0x669963`;
- **`FirstTC`** (entry -2, tested before -1 = unknown proto, so no query runs for it): the hook
  calls `UhcGatherFirstTcUnit(hc)`, which
  - reads the player ID `[[hc+8]]` and gets the player of the main world
    (`0x44CB21([[C66234h]+13Ch], id)`);
  - reads `FirstTC` at `[player+4F0h]` (set by Player::addUnit at `0x67ABD4`: stock for a
    `TownCenter`; `startingTC` for a marked building; `civFirstTC` for the civ's `<firstTC>`
    building) and looks the unit up (`0x44CC6D`);
  - requires the unit's owner `[unit+44h]` to be that player (`[[unit+44h]]` = the ID): the
    game never clears `FirstTC`, and `0x85302C` checks no owner, so a converted first town
    center would otherwise be accepted;
  - calls the stock stored-point check `0x85302C(hc, unit)` itself, so the unit passes exactly
    the checks stock applies to a stored point and to every candidate.

  It writes no game state; its only state is the log-only "last FirstTC logged per player".

On success the hook jumps to the stock store-and-return path at `0x4C6CB2` with EDI = the unit,
like a stock block, so the store = 1 callers keep it as the stored point. From then on stock
keeps it while it is alive and built, even after a Town Center is built. When nothing matches,
the hook re-executes the stolen `pop ebp / pop edi / pop esi / xor eax,eax` and continues at
`0x669E33`.

Proto names are resolved to IDs (`0x5A2346`, name → proto ID) the first time the hook runs, when
the database exists; `FirstTC` is mapped to -2 before any lookup. The hook never calls
`aiSetHCGatherPoint`'s setter: it issues a network command (`0x82D9CB`), which every machine
would then send.

**Observed in game** (2026-10-29, with `civFirstTC`): a player whose first town center was a
Market and who had no Town Center sent a card of food crates; the helper returned the Market
(unit 148), the store = 1 path wrote 148 to `[hc+18Ch]`, and the crates landed beside the Market.

### healNonIdle

Two filters stop a healer from healing a busy unit:
1. **The automatic search**, FUN_009CD865 (`this` in EBP, the healer at `[ebp+4]`), runs a unit
   query around the healer. It skips every candidate whose action manager `[c+58h]` is not
   idle: `0x44F1A7` is true only when the current action `[mgr+24h]` is null or of type 7.
   The hook replaces that `call 44F1A7h` at `0x9CD9C7`. For a healer of the marker type it
   returns AL = 1; otherwise it calls the stock function. It continues at `0x9CD9CC`.
2. **Each heal tick**, FUN_009E0B53 (target in EDI, heal action in ESI, healer at `[esi+10h]`),
   stops when the target's action manager reports moving (`0x4802D4(-1)`) or fighting
   (`0x9CA5AC`). The hook at `0x9E0C79` goes straight to the heal code at `0x9E0C9F` for a
   marked healer, and to the stock tests at `0x9E0C80` otherwise.

"Healer of the marker type" is `0x44D7FA(proto = [healer+5Ch], typeId)`, the engine's is-a
test. It accepts a proto ID as well as an abstract type ID.

How the sites were found:
- Patching only the tick did nothing in game: the tick hook never ran, because the search never
  started a heal on a fighting unit.
- A hardware-breakpoint trace (`tools/re/trace_exec.py`) showed that heal actions start from
  FUN_009CD865.

The trace is described in [engine-symbols.md](engine-symbols.md), "Unit types and healing".

### Extra abstract unit types (used by every key that takes a `<UnitType>`)

`healNonIdle`, `dodgeAnyUnit` (and its sound keys), `maintainWaitForPop`,
`broadsideMuzzleLimit`, `lifespanAfterConstruction`, `gaiaSocketsOnly`, `noCorpseDopples`,
`startingTC`, `noTrainNearEnemyTC`, `overhealHitpointBars` (each of its types), and
`transformInventory` and `showGatherRate` when given a type, request their type here. A name that
already exists, a stock type or a proto name, keeps its ID and adds nothing.

In TAD, abstract unit types are not read from data:
- FUN_0051A5DC (`thiscall(database)`) registers a fixed list compiled into the exe, `Unit`,
  `Ship`, `Building` … `AbstractJapaneseMonk`, with IDs `protoCount + k`;
- it then registers the 75 logical-type names of the table at `0xDC10F0`;
- a `<UnitType>` in `protoy.xml` whose name is not registered is silently dropped.

`src/unittypes.cpp` adds names to that table:
- A feature calls `RequestAbstractUnitType(name, &id)`. The first call installs a hook on the
  registration function's epilogue (`0x51BA31`, where EDI = database).
- On every data load, the hook looks each requested name up: `0x58E685` gives the hash bucket,
  then `0x40295B` searches it.
- If the name is missing, the hook adds it with `0x5E3549(table, name, &id)`, using
  `id = [database+194h]`, the next free ID (the stock code requires dense IDs).
- It stores the ID in the feature's variable and logs `unit types: name -> ID (bit B of N)`.
- The per-proto unit type bitset (`proto+30h` data, `proto+34h` bit count) is sized later
  (`0x5F769A`) from `[database+194h] - [database+19B0h]`, so it grows with the new name. The
  proto loader then sets the bit for every `<UnitType>` that names it.

`tools/re/inspect_unittypes.py` reads that table from a running game.

### dodgeAnyUnit, dodgeSoundSet and criticalSoundSet

**The stock dodge** is FUN_0049ACAA, `bool __thiscall(unit)`, called once per hit at `0x49B023`
by the damage function FUN_0048649F; a true result skips the damage. With ESI = the unit hit:
1. it needs the database, the unit's player `[esi+44h]`, the world and `[world+7Ch]` (the tech
   status object, kept in EDI);
2. **the hardcode:** the proto ID `[[esi+5Ch]+4]` must equal one of `[db+5E88h]`, `[db+5E8Ch]`,
   `[db+5E90h]`. Those are proto IDs cached by name at data load (`0x5EEBED`…): `ypMonkJapanese`,
   `ypMonkJapanese2`, `ypMonkJapanese3`. The same cache (`db+5E74h`…`5EA0h`) also holds the
   berry building, the Potala and the Chinese and Indian monks;
3. the cold path at `0x6A249C`: the tech `ypDodge` (`0x600BE1`, by name) must be active for the
   player (`0x94AF27`); then the sync RNG `0x407CE7(2, 100)` must give a value in [0, 15);
4. if `[world+8A8h]` exists and the unit is visible to the local player (`0x4818F4`), it shows a
   floating text (string 0xF9CE) and plays the sound set `"PowerEvade"` at the unit:
   `0x4AA24C(game, position = unit+14h, name, …)`, which plays a sound set by name.

**dodgeAnyUnit** jumps at `0x49ACE5` (`mov eax,[esi+5Ch]` / `mov eax,[eax+4]`). For a unit
whose proto is of the marker type (`0x44D7FA`), it continues at `0x6A249C`, the stock step 3,
with the stock frame and registers (EDI, EBX, ESI) untouched. Any other unit re-executes the two
instructions and continues with the stock compares at `0x49ACEB`. ECX holds the database there
and is saved around the is-a call. The tech, the roll and the feedback are therefore identical
for a marked unit and a monk.

**`log`** also rewrites the call at `0x49B023` to a wrapper that calls FUN_0049ACAA itself and
logs the unit when it returns true; the wrapper returns to `0x49B028`, so the caller sees the
same AL. A call does not preserve EAX/ECX/EDX in the stock code either.

**The sound sets.** Both pushes of the set's name are replaced by a jump to a hook that pushes
the configured name instead:
- `0x6A2628` `push "PowerEvade"` in the dodge, with ESI = the unit that dodged; it continues at
  `0x6A262D` (`add esi,14h`);
- `0x6A2A9A` `push "PowerCriticalStrike"` in the damage function's critical-hit block, with
  EBX = the attacker (looked up by ID at `0x49AFC2`, checked non-null at `0x6A2A8B`); it
  continues at `0x6A2A9F` (`lea eax,[ebx+14h]`).

ECX (the game, used by the call that follows) is saved around the C++ lookup. The lookup walks
the cfg rules in order with the same is-a test and returns the stock string when none matches.
The names are `std::string`s that live as long as the DLL. Choosing a sound set changes nothing
in the simulation.

### damageOverTime

**What stock has.** An Age of Mythology poison survives only as dead code:
- TakeDamage tests bit 8 (`Poison`) of the hitting action's flag bytes;
- it then posts unit event 20h (`Poison`) to the attacker;
- the attack action's event handler (0x48F175) passes `(damage × −0.1, 3.0)` to 0xB1BE43, which is
  `mov al,1; ret 8`.

Nothing is applied. The details are in [engine-symbols.md](engine-symbols.md), "Damage and poison".
The DLL ignores that path and adds its own, driven by data.

**Data.** At load time, the action parser FUN_005F98A0 ends every unknown `<ProtoAction>` child at
0x5FA11E.
- The tag hook there runs only when the return address `[esp+C0h]` is 0x5FA213, i.e. a `protoy`
  `<ProtoAction>`.
- For a tag named `AttachProtoUnit` (case-insensitive), it records the text X under the key
  (attacker proto ID `[proto+4]`, action name index `[action+4]`).
- That key also matches every player's copy of the proto and its actions, which keep both
  numbers.
- The data is parsed at startup and again when a skirmish starts, but not when a scenario loads
  (both observed in `UHC.log`). Every load starts from scratch: `uhc::OnDatabaseLoad`
  (`src/unittypes.h`) calls the feature from the abstract-unit-type hook at 0x51BA31. That hook
  runs on every load, before the protos' contents are read, and the call clears the records, the
  "Attaching" name index and the running poisons. So a tag removed from the data stops working
  at the next load, and IDs that shifted cannot match stale records.

**Hit.** The entry of TakeDamage (`0x49B3D9`) jumps to a C++ wrapper.
- The stock frame is unchanged: the wrapper is `__fastcall` with ECX = the unit, and the 13
  stack arguments are in place.
- It calls the stock function through a trampoline (`sub esp,8Ch; jmp 49B3DFh`).
- If damage was dealt by an action with a record, it looks up X once:
  - X's proto ID comes from 0x5A2346;
  - X must have an action named `Attaching`, found through the action-name table at
    `[db+1FD8h]`.
- It then reads, from the attacker player's copy of X (FUN_0045311B), the `Attaching` action, its
  ROF `[action+34h]` and the Lifespan `[proto+ACh]`.
- It adds a poison keyed (unit ID, X, attacker player):
  - a new poison ticks first one ROF after the hit;
  - a later hit by any unit of the same player moves the end to `now + Lifespan` (the current
    Lifespan) and makes that unit the attacker; the tick timer keeps running.
- A hit that kills the unit, or a unit that is not alive (unit `vtbl+A4h`), adds nothing.

**Tick.** The entry of the world update (`0x481A57`) jumps to a second wrapper.
- It calls the stock update through its trampoline (`sub esp,0Ch; push ebx; push ebp;
  jmp 481A5Ch`).
- It then, for the game world `[game+13Ch]` only, walks the poisons in key order with
  `now = [world+108h]`.
- Each due tick (`nextTick ≤ now` and `nextTick ≤ end`) calls the stock TakeDamage:
  - unit, attacker player, X's proto ID, X's `Attaching` action;
  - the attacker unit ID while that unit exists, else −1;
  - multiplier 1, damage 0 (computed), no cap;
  - p8..p13 = `0, 0, 1, 1, -2, 1`, as the stock special-damage callers pass them, except p11
    (the hit reactions), which is 0 when the attacking unit is gone.

  The engine therefore applies the damage type, the bonuses, the armor and the DamageFlags. Kills
  and XP go to the attacker's player.
- **Why p11 depends on the attacker.** With p11 = 1, TakeDamage runs the reactions to a hit:
  retaliation, attack alerts, and, for a unit in an army (AI armies), the army's list of
  attackers. That last part reads the attacking unit with no null check (0x6A3253). An army unit
  poisoned by a unit that is gone would crash the game, so such a tick passes 0 and skips the
  whole block (`jne 0x49BC00` at 0x49B929). The damage itself does not depend on it. This comes
  from the code; no AI army was poisoned in game.
- **Techs on X.** Each tick reads the player's copy of X's `Attaching` action again, so a tech
  that changes its damage applies from the next tick. A Lifespan change applies from the next
  hit, which sets the end time. TAD's tech effects have no ROF subtype: the table of `subtype`
  names at `[db+3500h]` has none, so the interval always comes from the data. Not tested in
  game.
- **When the attacking unit is gone,** the engine skips its diplomacy filter (FUN_0049AEE0 lets
  everything through without an attacking unit). The wrapper then applies the same filter
  itself, with the attacker's player: X's DamageFlags against the unit's owner and the player's
  relation to it (`[player+1D4h + 4*id]`, 2 = enemy). A unit converted to the attacker's side
  therefore stops taking the poison, as it would with the attacker alive.
- A poison ends when its end time passes, or when the unit dies or disappears.
- **Another game clears all poisons.** A new or loaded game can reuse the old world's address, so
  the test is the world's step count `[world+F8h]`. The world update raises it by exactly 1
  (0x481A87), and while poisons run every step reaches the wrapper. A jump of more than 1, game
  time going back, or another world pointer clears the poisons and logs `another game started`.
  A data load clears them too, and logs `the data was reloaded`.

**What it does not do.**
- X is never created in the world, so there is no model or effect.
- Poisons are not saved in saved games.
- The stock Poison flag stays unused.

### liveBuildingWorkRate

**The stock mechanism.**
- A proto's `BuildingWorkRate` is the float `[proto+D0h]`.
- A Building, or a unit whose proto has the flag `ForceBuildingData`, gets a building data object
  at `[unit+68h]` from setProto `0x4981F3`. Its init `0x4E5E8F` sets the copy `+28h` to 1.0.
- **The copy.** The completion routine FUN_006A1F82 (18 callers) runs
  `[[unit+68h]+28h] = [[unit+5Ch]+D0h]` at `0x6A2089..0x6A2095`, once: when a building completes,
  when a `ForceBuildingData` unit is created, and when a saved game loads, for completed buildings
  (`0x9C54B4..0x9C54D3`).
- **The getter** `0x9BFE33`, `float thiscall(unit)`, returns `[unit+68h] ? [[unit+68h]+28h] :
  [[unit+5Ch]+D0h]`. Its only callers are the per-tick updates of four actions, which multiply the
  result into their progress: Train (`0x9EA413`), Research (`0x9E65F7`), CommandResearch
  (`0x9D58D4`) and Maintain (`0x6AB23F`).
- **The tech.** The Data effect's case `0x5E` (BuildingWorkRate, `0x8FAE7D`; the removal twin
  `0x8FC16F`) only computes the new `[proto+D0h]` of the player's copy of the proto. Unlike the
  Hitpoints case, nothing walks the existing units.
- The stat panel (`currentUnitBuildingWorkRate`, `0x6F49B1`) reads the proto's value, so it showed
  the new rate while the building still used its copy.

**The hook.** A 5-byte `jmp` replaces the getter's first two instructions, `mov eax,[ecx+68h] /
test eax,eax`. The hook:
1. with `log`, calls `UhcBwrLogUnit(unit)` inside `pushad` / `popad`, which logs the unit when the
   copy's bits differ from the proto's;
2. re-executes the two stolen instructions, so EFLAGS are the ones stock returns with;
3. jumps to the getter's own tail `0x9BFE3E`, `mov eax,[ecx+5Ch] / fld [eax+0D0h] / ret`, the path
   stock already takes for a unit without building data.

The copy is still written at completion and saved and loaded with the unit; the getter was its
only other reader.

**Why it is safe.**
- The hook returns with the stock ECX, ESP, EBX, ESI, EDI, EBP, EDX and EFLAGS, and one value on
  the x87 stack, as stock does. Only EAX differs (the proto, where stock left the building data).
  Each of the four callers writes EAX before reading it; the four call sites are verified sites
  (`WorkRate*Call`), so a build where that is not so is not patched.
- The result depends only on `[proto+D0h]`, simulation state that is the same on every machine.
- Every stock proto has 1.0 and only two unobtainable stock techs change it, so with stock data the
  key changes nothing unless a trigger, a card or a mod changes the value.
- A building transformed in place (FUN_009C754C keeps its building data and copies nothing) now
  uses the new proto's rate.

### techPrereqRecheck

**The stock re-check.** Each world update calls FUN_00491A40 (call at `0x481D51`) when
`[world+7Ch]` exists and byte `[game+B3Ah]` is 0. For each player slot with a tech tree and a live
player, it calls FUN_004919CE(tree, player). The tree (20h bytes) holds the player ID, an array of
status entries (`+4`, count `+8`) and the dirty byte `+10h`. After its DynamicCost loop,
FUN_004919CE tests the dirty byte at `0x491A18`: `cmp byte [edi+10h],0 / jne 5096D4h`. The pass at
`0x5096D4` clears the byte, then for every tech:
- a null entry gets a relevance test and is created when relevant;
- every entry goes through FUN_005094D8. It reads the cached result (status bit 3) and the
  OrPrereqs flag (bit 21), evaluates FUN_005094B4(def+1Ch, player, or), and writes bit 3. On a
  0 → 1 change it activates the tech when it has no research time; a Volatile tech is toggled; the
  AI's tech list is updated.

**Who sets the dirty byte.** Only setDirty `0x506A41` and an inline copy in the pop cap adder
FUN_00506A5F, always with 1: tech status changes and activation, the age, the home city level, the
pop cap (including a unit with `PopulationCapAddition` that starts or stops counting), the tree's
creation and the world start. Creating or killing a unit without `PopulationCapAddition` reaches
none of them.

**TypeCount** is prerequisite type 0 (ctor `0x8EE860`). Its evaluator `0x8EE8E7` counts with
`0x4C846D([player+80h], player ID, type, state mask, 0)`, the backend of XS `kbUnitCount`, then
applies the operators. `[player+80h]` is the KB; it is used with no null check.

**The hook.** A `jmp` over the 10 bytes at `0x491A18` leads to `UhcTechPrereqHook`: `TRACE_ONCE`,
`pushad`, `UhcTechPrereqMaybeMark(tree = EDI, player = EBP)`, `popad`, the stolen
`cmp byte [edi+10h],0`, then `jmp 0x5096D4` when the byte is set and `jmp 0x491A22` otherwise.
`UhcTechPrereqMaybeMark`:
1. returns when the byte is already set, when the game, world or database is missing, or when the
   player's KB is null;
2. returns unless it is the player's turn: N = 1, or (`[world+F8h]` + player ID) % N = 0, with
   `[world+F8h]` the world's step count (+1 per world update);
3. once per data load, lists the techs whose definition has a TypeCount prerequisite, from the
   template status records `[[db+5D9Ch]+0Ch]` (24h bytes each, count `[+10h]`);
4. for each listed tech with an entry in this tree that has more than 3 status bits, computes the
   result with `0x5094B4`, with the arguments `0x5094EB` uses. On a difference from bit 3 it sets
   `[tree+10h]` = 1 and returns; the re-executed test then enters the stock pass in the same call.

`full` sets the byte on every turn instead and does not scan.

**Why it is safe.**
- The stock pass runs in the same call frame and state as when a house sets the byte; the hook only
  sets it sooner. It never writes `[tree+11h]`, whose pass is a nested loop over all techs.
- The evaluation is the stock evaluator with the stock arguments. TypeCount writes the KB's shared
  count query and a scratch vector and resets both, as any `kbUnitCount` call does.
- After a pass, bit 3 equals the evaluation for every non-null entry, so the byte cannot stay set
  for no reason: a new difference needs a new change of the counts. Entries with 3 bits or fewer
  are skipped, because stock reads their bit 3 as 0 but writes it anyway.
- The choice reads only game state (status bits, KB counts, the step count, the player ID), walks
  the techs in ID order and stops at the first difference. The time measured for the `log`
  summary is only logged.
- **Measured:** with 2 TypeCount techs, the checks took about 4 ms per game minute.

### maintainWaitForPop

**The stock mechanism.** `Maintain` is unit action type 22h (ctor `0x9E2510`, vtable `0xB97B98`).
Its fields: `+10h` the owner (the building), `+64h` the proto ID to spawn, `+68h` units per cycle,
`+6Ch` the train points of a cycle, `+70h` the points accumulated, `+74h` the fraction. The update
(FUN_00492F3E, cold chunk `0x6AB0E4`) runs while the action is active and the building complete
and alive. Each update:
1. adds `0x9BFE33(building) × [world+310h] (training rate) × [world+104h] (step)` to `+70h`;
2. sets `+74h` = clamp(`+70h` / `+6Ch`, 0, 1) (`0x9E27E4`);
3. leaves through `0x6AB180` while `+74h` < 1.0;
4. otherwise calls the spawn `0x9E2DEF(this, [+64h], [+68h])` at `0x6AB285`, then **ignores its
   outcome**: a `SingleUse` action ends (setState(0Ah)), any other restarts (setState(14h), which
   zeroes `+70h` and `+74h`).

The spawn tests the population before each unit (`0x9E2F79..0x9E2FDC`, `0x9E3110..0x9E311F`):
`pop = [proto+D8h]`; pop ≤ 0 or flag A3h (`AlwaysAllowOverPopCap`) skips the test; with flag 9Fh
(`AllowOverPopCap`) the unit needs `cap - used > 0`, otherwise `cap ≥ used + pop`, with
`used = [player+78h] + 0x45805C(player)` and `cap = 0x4581A1(player)`. A failure on the first unit
creates nothing. The group variant `0x9E2AC8` runs the same test once.

**The hook.** A 6-byte patch at `0x6AB27D` (`jmp` + NOP over `mov edx,[esi+68h] /
mov eax,[esi+64h]`), reached only by the fall-through of the ≥ 1.0 test. With ESI = the action, it
calls `UhcMaintainPopBlocked(action)` inside `pushad` / `popad` and branches on AL:
- **not blocked:** it re-executes the two `mov`s and jumps to `0x6AB283` (`push edx / push eax /
  call 9E2DEFh`): the stock spawn and restart run unchanged;
- **blocked:** it writes `[esi+70h] = [esi+6Ch]` (the progress stays exactly complete) and jumps to
  `0x6AB180`, the stock "cycle not complete" exit. The next update finds the cycle complete and
  asks again.

**The predicate** repeats the spawn's first-unit test with the engine's own functions, in the
engine's order and 32-bit arithmetic: owner and player non-null and `[a+68h]` ≥ 1; the building's
proto is of the marker type (`0x44D7FA`); the proto ID remapped to `xpColonialMilitia` after a
revolution, like the spawn; the player's proto (`0x45311B`), not `AbstractMonk` (the spawn may
reuse a unit without testing); then the population test above. Any step that fails answers "not
blocked", so the stock call runs.

**Why it is safe.**
- When the predicate says "blocked", the stock call would have created no unit; when it says "not
  blocked", the stock code runs as is. The engine code it mirrors is verified too
  (`MaintainSpawnSetup`, `MaintainSpawnPopTest`, `MaintainSpawnPopTest2`, `MaintainGroupPopTest`):
  if another DLL changes that test, the feature refuses to apply instead of disagreeing with it.
- The held path is the stock "not complete" exit of the same frame; both callers of the update
  ignore its return value.
- The predicate reads only simulation state, and the hook's only write is `+70h`, a field the
  update writes every tick.

### transformUpdatesLOS

**The per-unit LOS.** A unit's base LOS is the float `[[unit+B4h]+90h]`; the proto's `<LOS>` is
`[proto+48h]`. The getter FUN_0048206D returns `[world+5ACh]` × a per-unit multiplier ×
`[[unit+B4h]+90h]` and never reads the proto. FUN_00483262 (`thiscall(unit, bool add, bool
force)`) takes the unit off the world's visibility map or puts it back, with the radius from the
getter. Four instructions write the base LOS: the default 10.0 of a new unit object, setLOS
FUN_00484518 (called at creation with the proto's LOS, and by a tech that changes a proto's LOS),
build completion FUN_006A1F82, and the savegame loader. setLOS and build completion write it
between a visibility remove and a visibility add.

**The stock bug.** FUN_009C754C, `thiscall(unit, int newProtoId)`, changes a live unit into
another proto in place. It is called by the `TransformUnit` tech effect (`0x7FBC79`), the
revolution (`0x7FBEF2`, `0x8F05F5`) and a few other callers. It:
1. looks up the player's copy of the new proto (`0x45311B`, into EBP);
2. takes the unit off the visibility map with its current LOS (`0x9C7570`);
3. calls setProto FUN_004981F3 at `0x9C763F`, which writes `[unit+5Ch]` but not the LOS;
4. rebuilds HP, build points and obstruction, caches the LOS for each player (`0x9C768D`), and puts
   the unit back on the map (`0x9C7730`) with the LOS it had before.

The trigger effect "Change Unit Type" (`trUnitChangeProtoUnit`) does not go through this function.
Observed in game: it never reached the hook, the unit kept its ID, and its LOS already matched the
new proto in stock. How that path sets the LOS was not traced.

**The hook** replaces the `call 4981F3h` at `0x9C763F`. There, ESI = ECX = the unit, `[esp]` = the
new proto, and `[unit+5Ch]` still holds the old one. The hook calls `UhcTransformLos(unit,
newProto)` inside `pushad` / `popad`, re-executes `call 4981F3h` with the argument still at
`[esp]`, and jumps to `0x9C7644`. The helper compares the unit's base LOS with the old proto's
`[proto+48h]` as raw dwords; when they are equal it copies the new proto's dword, otherwise it
leaves the field alone.

**Why it is safe.**
- The write lands between the stock visibility remove (old radius) and add (new radius), as setLOS
  and build completion do it, so the map never holds a radius it did not add. The per-player cache
  at `0x9C768D` runs after the write and sees the new value.
- The new proto is the argument setProto receives, so the LOS comes from exactly the proto the unit
  becomes, LOS techs of that player included.
- After the hook, EAX, ECX, EDX and the flags are what setProto leaves, as in stock; the other
  registers are unchanged.
- Only an integer copy of the dword changes the simulation: no float operation, RNG, local player
  or clock.
- The equality guard keeps a value the game set on purpose (a foundation's LOS, a knocked-out
  hero's 6.0). It also keeps the stock gap of a converted unit, which carries its former owner's
  LOS (the owner change at `0x514529` swaps the proto copy without touching the LOS).

### broadsideMuzzleLimit

**The stock broadside.** `BroadsideAttack` is protoaction type 29h (ctor `0x9D2B23`, vtable
`0xB962E8`). The action keeps two parallel arrays: `+68h` (count `+6Ch`), the muzzle index of each
slot, and `+74h` (count `+78h`), its fire time. Its set-up, FUN_0050339A (vtable slot 1):
1. requires an owner unit `[edi+10h]` whose proto is of the built-in type `Ship`;
2. **the hardcode:** `mov esi,6` at `0x5033D5`, kept in a local;
3. if the proto action has `<SingleUsePlayer>` (flag bit 26), the cold block `0x6A8236` sets the
   limit to 1;
4. counts the model's MuzzleR attach points (`0x484304`), clamps the count to the limit
   (`0x503447`), appends one slot per point, and stores the count in `[edi+80h]`;
5. does the same for MuzzleL (`0x5034E2`), appended after the right side.

The fire step (FUN_004C1290) picks the side from the target's direction and, for each due slot on
that side, launches **one projectile** (`call 499422h` at `0x4CEA43`). The schedule `0x4CEE48`
draws one sync-RNG interval per right-side slot and gives slot i and slot i + n1 the same time, so
the left side never fires more than the right side has slots.

**The hook.** A `jmp` replaces `mov esi,6` at `0x5033D5`. It sets ESI = 6, then N when no UnitType
was given or when the owner's proto is of the configured type (`0x44D7FA`; the marker ID is -1 until
the data loads, and then the stock 6 is kept). It re-creates ZF with `test ecx,ecx`, the stock test
at `0x5033D2`, and continues at `0x5033DA`. ECX, the proto action, is saved around the call, since
the code after the continuation reads it. The `SingleUsePlayer` test runs after the continuation,
so it still lowers the limit to 1, and both clamps still read ESI.

**The log hook** (only with `log`) replaces the MuzzleL clamp's `cmp eax,esi / mov [esp+1Ch],eax`
at `0x5034E2`. For the action the first hook matched, it calls the C++ logger with the action, the
MuzzleL count (EAX) and the limit (ESI) inside `pushad` / `popad`, then re-executes both
instructions and jumps to the `jg` at `0x5034E8`, which reads the flags of that `cmp`.

**Why it is safe.**
- The arrays have no other bound: save and load write each count and resize on load, the fire step
  walks the count, and the muzzle index is read as a byte, which caps N at 255. A larger N needs
  no save-format change.
- Nothing else reads the hardcoded 6.
- The limit depends only on the cfg and the owner proto's unit types, decided once per action
  set-up. It adds projectiles (each with its accuracy roll) and sync-RNG draws, so every machine
  needs the same cfg.

### abilitySlots

**Abilities.** `data\abilities\abilities.xml` is loaded into the ability manager `[world+56Ch]`,
one 20h-byte record per `<ability>`, in file order: `+4` proto ID, `+8` power ID, `+0Ch` tech,
`+10h` age, `+1Ch` flags (4 NeverShowInGrid, 100h AlwaysDisabledInGrid, …).

**GetNth** (`0x6EE5CC`, `bool thiscall(mgr, n, player, unit, …outputs)`, `ret 24h`) counts the
records of the unit's proto that are not NeverShowInGrid, and at the n-th one returns false when
its tech is not active or its age is not the player's; otherwise it fills the outputs (record
index, power ID, an "enabled" byte forced to 0 for AlwaysDisabledInGrid) and returns true. Past the
end of the unit's list it returns false. Nothing in it bounds n.

**The command panel** (refresh FUN_0046188E) builds its entries in two passes:
1. **Collection.** A page-11 `Abilities` command entry is appended once (`0x4C5ACA`), then
   `0x4C5AEB` sends it to a cold block that appends it again in a do-while:
   `0x695BD2 mov edi,5` … `sub edi,1 / je 461C3Fh / jmp 695BD7h`. 1 + 5 = **6 ability entries per
   `Abilities` command: this is the cap.**
2. **Layout.** The counter `[esp+34h]`, reset once per refresh, gives each ability entry its n
   (`0x696C0B..0x696C1F`); the entry calls GetNth at `0x696C59`. False takes no column; true
   places a button whose command is `ability(record, unit)`. Columns wrap at 6 and the layout stops
   at row 6.

**The patch** writes N − 1 over the `5` of `mov edi,5` (imm32 at `0x695BD3`): the panel then gets N
ability entries and asks GetNth for n = 0..N − 1. N stays within 6..36: below 6 it would hide stock
abilities, N − 1 must never be 0 (the do-while tests after the first append and would run about
4 billion times), and 36 is the size of the button grid.

**Why it is safe:**
- the entry array `0xCF05FC` grows by doubling, so more entries cannot overflow it;
- the grid bounds are unchanged: rows stop at 6, so no button index passes 35;
- the per-button state is indexed by grid position and reset on every refresh;
- a click runs the stock `ability` UI command (`0x7DDC52`), which looks the record up by index
  with no slot limit. The panel is built from the local selection only.

**`log`** jumps at `0x696C70` (`call 45EE37h`, the first instruction of GetNth's true path). When
n + 1 = `[esp+34h]` ≥ 7 it calls the C++ logger with the unit (EDI) and GetNth's outputs inside
`pushad` / `popad`, before the stock call (which returns a float in ST0), then makes the stock call
itself and jumps to `0x696C75`.

### wonderPanelSkipAuras

**The stock panel.** The wonder power panel (gadget `uiwonderpowerpanel`, five buttons) refreshes
through FUN_004586B1 and a cold chunk at `0x69EC5E..0x69F35E`. For each `AbstractWonder` of the
local player, and each page-11 command of its proto, it calls GetNth (`0x6EE5CC`, see
abilitySlots) with **n = 0** at `0x69EE5D`, and skips the command when that returns false or when
the record `0x44E702(mgr, recIdx)` has AlwaysDisabledInGrid (byte `+1Dh` bit 0, tested at
`0x69EE80`). Otherwise it builds a button whose command is `ability(recIdx, unitId, true)`. The
command panel asks for n = 0, 1, … and shows every ability, passive ones greyed; the wonder panel
only ever sees n = 0, so an aura listed first hides any power after it.

**The hook.** `WriteCall` turns the `call 6EE5CCh` at `0x69EE5D` into a call to
`UhcWonderPanelAbilityHook`, a drop-in for `0x6EE5CC` (thiscall, nine stack arguments, `ret 24h`)
that returns to `0x69EE62` like the stock call. For n = 0..7 it re-pushes the caller's eight other
arguments, calls `0x6EE5CC`, and on success looks the record up with `0x44E702` and tests the flag
the stock code tests next. It returns AL = 1 at the first record that is not AlwaysDisabledInGrid,
with that call's outputs in the caller's locals; the caller's own re-check then passes and it builds
the button as in stock. When no n qualifies it returns AL = 0, and the caller skips the command, as
stock does for an aura. With `log`, a success at n > 0 calls the C++ logger.

**Why it is safe.**
- Only the call's target changes; the hook leaves through `ret 24h` to the verified `test al,al`.
- The hook saves EBX and ESI; `0x6EE5CC`, `0x44E702` and the logger keep EDI and EBP. The caller
  reads only AL and reloads everything else from its frame.
- Repeated calls are what the command panel already does: `0x6EE5CC` resets every output at entry
  and writes nothing else through the caller's pointers.
- A first ability that qualifies returns at once, so a wonder with a single ability (every stock
  wonder) shows the same button.
- UI only: the refresh runs for the local player's units, and the button sends the same `ability`
  UI command a command panel button sends.

### lifespanAfterConstruction

**The stock lifespan.** `<Lifespan>` is a float in seconds at `[proto+ACh]`. It is armed once, in
unit init FUN_00498274, which calls setLifespan `0x48DCB9(unit, [proto+ACh], AlphaFadeLifespan)` at
`0x498372`. setLifespan writes the countdown `[[unit+B4h]+1Ch]`, sets state bit 3 ("lifespan
armed") when it is above 0, and, with `AlphaFadeLifespan`, schedules a fade-out (`0x47B50C`):
duration `[sub+84h]` (1.0), time before the fade `[sub+88h]` = Lifespan − duration, state bit 5.
Two per-step functions then count down, for every unit, foundations included:
1. **The tick**, FUN_00482BF6 (`void thiscall(unit, float dt)`). For a unit with bit 3, its cold
   part at `0x483EEC` subtracts dt from the countdown, or, when less than dt is left, takes the
   expiry: if state bit 11 (dying) is set it only removes the corpse; otherwise it queues the
   kill.
2. **The fade update**, FUN_004829FA (`float thiscall(unit, float dt, bool commit)`). It computes
   `t = [sub+88h] − dt` into its argument slot and stores it at `0x482A20` when commit is set. The
   bit-5 branch returns while t > 0; afterwards it fades the unit and, when alpha reaches 0, calls
   setLifespan(2e-6) so the next tick expires the unit.

Construction never touches either timer: the completion handler FUN_006A1F82 does not call
setLifespan. So a foundation counts down from its placement.

**The hooks.** Both test the same predicate, cheap tests first: the marker ID is resolved, the unit
is alive (state bit 11 clear, the test the stock expiry makes), not built (`0x44DDB4`: construction
data present and percent < 1.0), and its proto is of the marker type (`0x44D7FA`).
- **Tick hook** at `0x483EEC` (10 bytes: `fld [esp+0Ch] / fcomp [0B84BE4h]`). A held unit leaves
  through `0x482C20` (`pop esi / pop ecx / ret 4`), the exit stock takes for dt ≤ 0: no countdown,
  no expiry. Any other unit re-executes the two instructions and continues at `0x483EF6`.
- **Fade hook** at `0x482A1A` (6 bytes: `jne 482A26h / mov ecx,[esp+10h]`), entered with the flags
  of `cmp bl,1` (the commit flag), which `TRACE_ONCE` keeps. It also requires bit 5 (a fade-out
  pending), bit 3 (the lifespan armed) and bits 4 and 61 clear (those fades take priority and use
  the same timer). A held unit does not store t: it writes the stored timer into the argument slot,
  so the bit-5 branch sees no time pass, and continues at `0x482A26`. Any other unit re-executes
  `mov ecx,[esp+10h]` and continues at the store `0x482A20`.

Both hooks are needed: with the tick hook alone, an `AlphaFadeLifespan` foundation would fade out
during construction and die at completion. If the second jump cannot be written, the first one is
put back.

**Why it is safe.**
- The hooks only skip the stores the stock code makes at those points; they write no other state.
  Holding is decided again every step from the unit's state, so nothing is kept between steps and
  saved games need nothing extra.
- A dying unit is never held: the corpse fade uses the same bit 5 and the same 2e-6 lifespan, and
  the kill handler leaves the construction percent below 100 %, so without the alive test a
  destroyed marked foundation would never leave the world.
- Every site is checked byte for byte first (11 sites, including isBuilt and the is-a test the
  hooks call).
- The predicate reads only simulation state; the `log` lines change nothing.

### gaiaSocketsOnly

**The stock rule.** `<SocketUnitType>` stores a unit type ID at `proto+12Ch`. `0x466C31`
(`bool thiscall(buildingProto, int protoId)`) says whether a proto is a matching socket. It never
reads an owner.

**Where the owner is read.** Only in the snap to a socket, FUN_00A036BB (the cursor ghost, and the
AI's placement helper): a candidate needs `[[unit+44h]] == 0` (`0xA0383B`), so a socket a player
owns is never snapped to, and the ghost stays red.

**The check that decides** is FUN_0050703D, "PLACE" (World vtable `+14h`, `ret 2Ch`; a1 the player
at `[esp+1C0h]` and a5, "use the player's knowledge", at `[esp+1D0h]` in the body). The build
command calls it on every machine, and so do the UI's pre-check and the AI's placement check. In
its obstruction loop, a matching socket counts only when it stands exactly at the position (xz
distance² below 1e-12), and `0x508CC1 mov byte [esp+37h],1` records "socket found". After the loop,
a socketed building with no socket found fails (`0x509215`). No step reads the socket's owner.
Every stock socket has `ForceToGaia`, so stock never meets a player's socket.

**The hook** replaces the 5 bytes at `0x508CC1`, reached only by falling through from the
exact-position test (ESI = socket + 14h, EDI = the building's proto).
- a5 = 0 (no player's knowledge: the editor, the engine, the in-place conversion): set the flag as
  in stock;
- else call `UhcGaiaSocketAllowed(socket, building, player)`. It returns true (stock) when the
  marker mode is on and the socket is not of the marker type, when `[unit+44h]` is null, or when
  the owner is player 0. Otherwise it logs (with `log`) and returns false;
- true: `mov byte [esp+37h],1`; false: nothing;
- both leave through `jmp 0x508CC6`, the stock `jmp 50757Eh`, where EAX, ECX, EDX and the flags are
  overwritten before they are read.

**Why it is safe.**
- A refused socket takes the stock "no socket found" path: no new failure mode, no state change.
- The rule reads the socket's owner, the placing player, a5 and the data. PLACE runs inside the
  build command on every machine with the same arguments, so every machine refuses alike.
- The UI pre-check and the AI's placement check call the same PLACE, so they agree with the
  command.
- **Not observed in game:** in the test, the stock interface already refused a Trading Post on a
  player-owned socket, and triggers cannot give build orders, so the order path WoL reports was not
  driven.

### customHotkeyContexts

**The stock mechanism.** Hotkeys live in a context manager, `[[[0xC66244]+74h]+34h]`. Each context
has a dense ID and a layer; the name count `[manager+34h]` is the next ID, and the active contexts
are a 255-bit set.
1. **The list of contexts.** At startup the game registers 123 names through
   `0x628FC0(manager, name, layer)`. The 35 unit contexts (`TownCenterAccel` … `WonderAccel`) are at
   layer 5.
2. **The keymap.** FUN_005C16EA applies `DefaultKeyMapY.xml`. For each entry, the call at
   `0x5C1778` looks its `<context>` up by name (`0x5C16AB`: 0 found, 3 unknown); on 3 the entry is
   skipped.
3. **The proto → context table.** FUN_005C13C5 writes `[proto+178h]` for every proto at data load:
   about 40 protos by cached ID, shrines, wonders, and −1 for anything else.
4. **The selection.** When the selection changes (chunk `0x649FA4`), a selected unit of the local
   player enters a context (BL = 1, EDI = the unit) if it is a Building with a `<Train>` list, a
   fire pit, or has the flag `EnterHotkeyContext`; a non-building with a `<Train>` list only sets the
   "BuildAccel" byte (`0x64A034`). FUN_0079EF9C then switches off the 35 stock unit contexts by name,
   and FUN_0079F851 reads `[proto+178h]` (`0x79F897`) and turns that context on.

**The hooks.**
- **`0x5C1778`, the keymap find (call target).** The wrapper calls `0x5C16AB`. When it returns 3,
  the name ends in `Accel` and fewer than 223 contexts exist, it registers the name with
  `0x628FC0(manager, name, 5)`, finds it again and returns that result, so the stock code binds the
  entry. The new ID and the proto name (the context name without `Accel`) go into a list owned by
  the DLL, tied to that manager.
- **`0x79F897`, the unit's context (jmp, 6 B).** ESI = the database proto. A proto whose name
  matches an added context gets EDI = that ID; any other proto re-executes `mov edi,[esi+178h]`.
  Both continue at `0x79F89D`, which turns EDI on.
- **`0x79F1A5`, the switch-off (call target).** The last `call 4421F3h` (`WonderAccel`) goes to a
  wrapper that makes the same call, then switches off every added ID (`0xAB397F`), and returns to
  `0x79F1AA`.
- **`0x64A034`, trainers that are not buildings (jmp, 5 B).** If the unit's proto has an added
  context, the stub jumps to `0x64A05A`, the Building path, without the BuildAccel byte; otherwise
  it re-executes `mov byte [esp+13h],1` and continues at `0x64A05C`.

Units that enter no context (a soldier, a hero) never reach `0x79F897`, so an added context for
them stays off; the flag `EnterHotkeyContext` makes them enter one.

**Why it is safe.**
- With the stock keymap every context is known, so the find never returns 3, the list stays empty
  and the selection hooks run the stock code.
- Only names the exe does not know are added, and only those IDs are redirected or switched off.
- IDs must stay below 255 (every context set is 255 bits, set without a bounds check); the DLL
  stops at 222 to leave the game room for contexts it registers later. In the test the game had
  registered 151 contexts before the keymap pass.
- The list is written during the keymap pass and read by the selection hooks, all on the UI thread.
  If the manager changes, the list is rebuilt on the next keymap pass, and until then the selection
  hooks do nothing.
- UI only: a context decides which keys are live; the command a key runs is the one a click runs.

### snareOnlyHitUnit

**The stock snare.** When an attack's tactics action has `<TargetSpeedBoost>` and the target can
move, the cold chunk `0x4DD1DE` calls `0x4DD22D(target, 0, 0.65f, …, 2, 3000, …, 1)`. That creates
on the target's action manager a unit action of type 2Ch (init `0x4B3D44`): stat `[+64h]` = 0
(velocity), value `[+68h]` = 0.65, operation `[+78h]` = 2 (multiply), 3000 ms with flag 15h
("timed"), and flag 16h ("exclusive").

**From one unit to the group.** The per-unit recompute collects the unit's type-2Ch actions and
sums the velocity modifiers (`0x4B3C48` / `0x4B3C7D`): start from the proto's MaxVelocity, apply each
velocity modifier in order (0 set, 1 add, 2 multiply), and stop after the first exclusive one. The
max-velocity getter `0x487E27` (unit vtable slot 34h) returns the result times the cfg float
`MovementMod`. A grouped unit only marks its group dirty; the group recompute FUN_004FD289 then sets
the group's pace `[group+7Ch]` to the minimum of its members' velocities (`0x4FD3FD..0x4FD411`,
store at `0x4FD53A`), snare included. That is the spread.

**The straggler rule.** When a member is more than 2.0 from its formation slot, the member step
sets group bit 7 (`0x4FA17D`; `0x6AA514` and `0x6AA56A` for a member with its own path), and the
group then moves at 0.8333× its pace (`0x4FAAA5`). Without a second change, a snared member left
out of the pace would fall behind and trigger this rule, and the group would still slow.

**The hooks.**
1. **Group pace, `0x4FD3FD`** (26 bytes, up to `0x4FD417`). For a member with an active snare, the
   helper computes the member's velocity without the snares and lowers `[group+7Ch]` to it when it
   is smaller, as the stock compare does; the hook continues at `0x4FD417`. Any other member
   re-executes the stock instructions and leaves through `jnp` to the stock store at `0x4FD53A` or
   to `0x4FD417`, so an unsnared group is computed bit for bit as in stock.
2. **Straggler bit, `0x4FA17D`, `0x6AA514`, `0x6AA56A`** (6 bytes each, `mov eax,[reg+4] / or byte
   ptr [eax],80h`). For a snared member the hook skips the `or`; otherwise it re-executes both. At
   `0x6AA56A` only the member's ID is left, so the helper looks the unit up as the member loop does.

**What counts as a snare:** a type-2Ch action with stat 0, operation 2, and both flags 15h and 16h.
The only other timed creator, `<SpeedBoost>`, is not exclusive, and the auras (exclusive or not)
have no duration flag, so WoL's exclusive speed auras are not taken for snares.

**The velocity without the snares** replays the stock sum over the same actions in the same order,
skipping the snares: the same operations, the same stop on the first exclusive modifier, the same
`MovementMod`. Each step is rounded to a float, as the stock `fstp` does.

**Why it is safe.** One `VerifyAll` checks the written ranges, the continuations and the stock code
the helpers mirror (14 sites). A nested action tree deeper than 16 levels makes the helper answer
"not snared", which runs the stock code. The helpers read only simulation state and the game's cfg
value, in a fixed order, with IEEE single precision.

### techRenameEffect

**How a tech is stored.** The database's tech tree TT0 (`[db+5D9Ch]`) holds, per tech, a
`BTechTreeNodeData` (34h bytes: `+8` DisplayNameID, `+0Ch` RolloverTextID, `+10h`
LongRolloverTextID, `+14h` icon, then the prerequisite and effect arrays) and a base node. Each
player has a tech tree in the tech manager `[world+7Ch]`; its nodes are created on first use as a
copy of the base node, `[node+0]` included. So **every player's node points at the same
NodeData**; only status, cost and research points are per player. The interface reads a tech's texts
through the player's node.

**WoL's bug.** WoL's `SetTechName` apply writes `[[node]+8]` and `[[node]+0Ch]`: the shared
NodeData, hence a global rename.

**The fix.** The effect's apply gives the player a private copy of the NodeData and points that
player's node at it:
1. `node = 0x8D0005(player, tech)` (the player's node, created if needed);
2. the copy for (player ID, tech ID) lives in the DLL (a `std::map`, never freed or moved);
3. if `[node]` is not the copy yet, the 34h bytes are copied from `[node]` (the node is new: first
   rename, a new or loaded game, a data reload);
4. the configured IDs are written into the copy, then `[node+0] = copy`, last.

The copy is shallow: the prerequisite and effect arrays and the icon stay shared with the database,
so research, effects and prerequisites run as before.

**Registering the effect type.** The 17 stock effect type names (`SetName` 0 … `Data2` 16) are
registered once, in the database init FUN_0052277E, into the table `[db+335Ch]` (count `[db+3360h]`
= the next ID). The hook at `0x524CB5` replaces `cmp dword ptr [esi+3504h],0`, right after Data2's
registration. Inside `pushad` / `popad` it adds `SetTechName` with ID 17 unless the name exists,
then re-executes the `cmp` last (its flags feed the `jne` at `0x524CC4`) and jumps to `0x524CBC`.

**Creating the effect.** The parse `0x620572` looks the type up by name, then calls the factory
FUN_00620535, which handles 0..10h and sends anything above to its default case `0x62146F` (error
51Fh, return 0). The hook there compares the type with SetTechName's ID: for it, it calls
`UhcTechRenameCreate()` and returns through the factory's own epilogue (`pop esi; ret`); any other
type re-executes `push 51Fh` and continues at `0x621474`. The effect is allocated with the engine's
`operator new` (`0x401398`), built by `BEffect::BEffect(type)` (`0x620B8F`, which sets kind 8, a
"general" effect applied per player, and flag 20h, re-applied after a saved game loads), and given
the DLL vtable.

**The DLL vtable** is a copy of the stock BEffect's 17 slots (verified in place) with: the
destructor; setData (reads `tech`, `newName`, `newRolloverTextID`, `newLongRolloverTextID`, and logs
every refusal, since a false return makes the parse drop the effect without a message); save and
load (the base, then the four ints, as the stock SetName); copyFrom; and generalApply (the rename
above), which the effect dispatcher calls at `0x7F8111` when the carrier becomes active for a
player (the whole team for a team tech) and after a saved game loads. generalUnapply stays the stock
no-op, as for the stock SetName.

**Why it is safe.**
- Only string IDs change, in memory the database does not own. The one simulation-side reader, the
  "researched" message, tests `DisplayNameID >= 0`; the DLL refuses negative IDs other than -1
  (keep), so that message is never suppressed.
- The engine never frees or saves `[node+0]`: a loaded game rebuilds its nodes from the base, and
  the post-load pass re-applies the rename with a fresh copy.
- The apply depends only on the effect, the player and its tech tree, never on the local player.
- **Observed in game:** the database's NodeData kept the stock IDs (23401 / 23400) while player 1's
  copy held the new ones (11070 / 10670).

### noCorpseDopples

**Stock dopples.** FUN_0048679A (`void thiscall(unit, int forced)`) is the per-unit visibility
update. It loops over the players (EBX = player index, EDI = the player). When a unit leaves player
EBX's view (`0x49520B`), stock makes a dopple if the proto has the flag `Doppled`, the unit is in
the world (state bit 8), state bit 1Dh is clear, and, for a `DoppleOnlyWhenDead` proto, the owner
is Gaia. It then runs `mov eax,[esp+2Ch] / mov ecx,[esp+54h]` at `0x49534D` and calls `0x4DB3D0`,
which creates the dopple for every player that shares the losing player's vision. Nothing on this
path asks whether the unit is alive; a dead unit's dopple shows its death pose.

**The hunt flow.** A hunt at 0 HP stays in the world as a carcass (state bit 8 kept, bit 12 set:
not alive). If it leaves a player's view while it still holds food, it gets a corpse dopple, which
stays until the player sees the spot again. A depleted carcass is taken out of the world (bit 8
cleared at `0x4B520E`) before it decays, so it is never doppled.

**The hook.** A `jmp` over the 8 bytes at `0x49534D` (two paths reach it: the fall-through and the
`DoppleOnlyWhenDead` test's `je` at `0x4F108E`). The hook runs the stock code when the marker ID is
-1, EBX = 0 (Gaia; `0x4DB3D0` makes nothing for it), the proto is null, the is-a test fails, or the
unit is alive (unit vtable slot A4h, called as the stock code does at `0x4868FA`). A marked unit
that is not alive is logged (with `log`) and leaves through `jmp 486A30h`, the exit the stock code
takes after a creation. Any other unit re-executes the two `mov`s and continues at `0x495355`.

**Why it is safe.**
- EAX, ECX, EDX and the flags are dead at both continuations; the is-a test and isAlive keep the
  other registers, and the stack is balanced.
- The skip path is the path after a stock creation, so the rest of the player loop runs as in
  stock.
- The hook's inputs are the proto's types, the unit's HP and state bits, and the player index; the
  visibility update runs inside the simulation, for every player, on every machine. Skipping a
  creation also skips its draw on RNG stream 1, which is probably a local stream (inference, not
  verified).
- **Not covered:** the `MutateDopples` refresh (no stock or WoL proto uses it), the dopples a saved
  game already holds, and the dopple of a live unit that later dies out of sight.

### danceBonusCivs

**The stock dances.** A `DanceBonus` action (protoaction type 45h) stores its kind as a byte at
`[action+0C1h]` (Training 1, XPTrickle 2, Regeneration 5, Gathering 8, …). The action's own update
handles UnitModification, UnitSpawn, PopCap and WarChiefRansom, with no civ test. The other four
kinds are read by the engine in four `thiscall(player)` readers:

| Kind | Reader | Native branch |
|---|---|---|
| Training | FUN_008D4790 (train rate, `ret 4`) | `0x8D47CF` |
| XPTrickle | FUN_004E0DE5 (XP trickle; also the dance tooltips) | `0x4E0E29` |
| Gathering | FUN_004ECD39 (gather rate) | `0x4ECD7D` |
| Regeneration | FUN_00490476 (`this` in EDI) | `0x679E66` |

Each one loads the player's first civ ID (`[[player+20h]]`, or -1 through a separate path that
jumps back to the same compare), then compares it with the four native civ IDs that FUN_00512651
caches by name on each data load: `[0C6FB50h]` XPIroquois, `[0C6FB54h]` XPSioux, `[0C6FB58h]`
XPAztec, `[0C6FB5Ch]` XPSPC. A match goes to the native branch: getFirePit (`0x4819EF`, the player's
first `AbstractFirePit` unit), then the product of the strength `0x9D665C` over that unit's dance
actions of the kind. Any other civ gets 1.0 (Regeneration: no healing).

**The hooks.** Each one replaces the first compare, `cmp eax,[0C6FB50h]` (6 bytes), with a `jmp`
(+1 NOP); both paths into the compare reach it. It saves EAX, ECX and EDX and calls
`UhcDanceCivAllowed(kind, player, civ)`:
- listed civ: jump to the native branch, with the registers and the stack as the stock code has
  them there;
- any other civ, or -1: re-execute the compare and continue at the stock `je` right after it, which
  reads its flags; the three other native compares then run unchanged.

`UhcDanceCivAllowed` resolves the cfg names with the engine's own lookup, `0x58E71F(database, name)`
(case-insensitive), into a table by civ ID. When `[game+140h]` or its civ count changes (the data is
read again when a skirmish starts), the names are resolved again on the next call. While the civ
count is 0 it answers "not listed".

**Why it is safe.**
- The written bytes are one whole instruction, nothing branches into its last 5 bytes, and the NOP
  is never executed.
- EAX, ECX and EDX are restored on both exits, ESP is unchanged, and no x87 value is live at any of
  the four sites.
- The answer depends only on the cfg list and the data's civ table, so every machine with the same
  cfg decides the same.
- The native civs pass the stock compares as before, and an unlisted civ runs exactly the stock
  bytes. Upstream's `nativeCivs` patches the later compares (0x4904B5, 0x4ECD6B, 0x8D47C9), outside
  these ranges, so a `nativeCivs` port can share these functions.

### startingTC

**The stock first town center.** A player keeps one unit ID at `[player+4F0h]`: -1 from the
player's constructor (0x8DCC1D), saved and loaded with the player (0x8D4088). Player::addUnit
FUN_0049874F (`bool thiscall(player, unit*, bool)`, `ret 8`) adds a unit to the player's list; at
its end (0x49880A) `cmp dword ptr [esi+4F0h],0 / jl 506B2Ah` enters a cold chunk only while the
value is negative. The chunk loads the unit's exact proto ID (`[[edi+5Ch]+4]`) and compares it with
the cached `TownCenter` ID `[database+5E08h]` (0x506B3B); if equal it jumps to 0x67ABD4, which
stores `[edi+10h]` (the unit ID) into `[esi+4F0h]`. Nothing else writes the field during a game, so
a dead first town center stays. The placement rules parse the keyword `FirstTC` as type -2
(FUN_005FDE94 / FUN_005FDFEA). Their evaluators FUN_008CE515 (`distanceatmostfromtype`, the no-rush
rule) and FUN_008CE935 (`distanceatleastfromtype`, the 65 m rule) loop over the players, read
`[p+4F0h]`, look the unit up in the world's table with no alive test, and measure with the unit's
`vtbl+B8h`. AtLeast skips a player with -1; AtMost returns "satisfied" as soon as any player has -1.

**WoL's Maori start** (static reading). `Age0Maori` applies `Data Lifespan 0.5 Assign` to
`TownCenter`, then `FreeHomeCityUnit MaoriPa`. The Lifespan case of the Data effect (FUN_008F973F,
case 0x8FA939) writes `[proto+ACh]` and calls FUN_00A00505, which runs setLifespan (0x48DCB9) on
each of the player's units of that proto: the live town center gets state bit 3 (lifespan armed) at
once. FreeHomeCityUnit then creates the Pa at the shipment point, the town center, in the same tech
application. The Pa's addUnit sees a first town center that is still a live unit, so stock keeps
it, and the town center dies 0.5 s later.

**The hooks** (`hooks/startingtc_hooks.asm`):
- **Proto hook**, a `jmp` over `cmp eax,[ecx+5E08h]` at 0x506B3B (6 B), in the cold chunk, so only
  for a player with no first town center. It re-executes the compare: equal → 0x67ABD4, as in
  stock. Otherwise, with `civFirstTC` on, a unit of the exact proto its player's civ names in
  `<firstTC>` goes to 0x67ABD4 ([civFirstTC](#civfirsttc)); then a unit whose proto is of the
  marker type (is-a 0x44D7FA) also goes to 0x67ABD4 (logged first, with `log`); any other unit
  leaves through 0x498817, the stock `jne` target. Its trace line is `FirstTC proto check
  (0x506B3B)`, since both keys use it.
- **Gate hook**, a `jmp` over `cmp dword ptr [esi+4F0h],0 / jl 506B2Ah` at 0x49880A (13 B). It
  re-executes both: a negative value goes to the cold chunk 0x506B2A (and the proto hook). For a
  player who has a first town center, a unit of the marker type calls
  `UhcStartingTcStale(player, unit)`; true → 0x67ABD4 (the unit becomes the first town center),
  false → 0x498817. Every other unit leaves through 0x498817, as in stock. The is-a test comes
  first, so the lookup runs only for marked units.
- **`UhcStartingTcStale`** returns false when the old ID is the unit's own, when there is no main
  world, or when the player is not `[world+58h][id]` of the main world (a home city world's
  player). It looks the old ID up as the rule does (`[world+0Ch]`, count `[world+10h]`, full ID at
  `[unit+10h]`), and returns true when the unit is not there (gone), when unit vtable slot A4h
  (0x44D019, the stock alive test) is false (dead), or when state bit 3 of `[unit+4]` (bit count
  `[unit+8]`) is set (pending lifespan). Otherwise false: a live first town center is never
  replaced.
- The proto hook is written first; if the gate hook cannot be written, the proto hook's stock bytes
  are put back, so the feature is never half installed.
- **One proto hook for two keys.** `startingTC` and `civFirstTC` share the hook at 0x506B3B. A
  single installer, `InstallFirstTcProtoHook` (`features/startingtc.cpp`), writes it once for
  whichever key applies first; `startingTC` comes before `civFirstTC` in `features.h`. When the
  `jmp` is already there, `civFirstTC` verifies the chunk before it (`FirstTcChunk`) instead of
  the stock compare (`FirstTcProtoCheck`). Each key's branch is off while its own global is unset
  (`g_uhcCivFirstTcOn`, the marker ID).

**Why it is safe.**
- Both exits are stock code: 0x67ABD4 reads EDI (unit) and ESI (player) and writes ECX; 0x498817
  pops EBX, EBP, EDI and ESI and returns with `mov al,1`, reading no other register and no flag.
  The hooks keep EBX, EBP, ESI, EDI and the stack (the C++ helpers are `__stdcall`); EAX, ECX and
  EDX are free on both paths. The three callers of addUnit (0x498980, 0x51453E, 0x9C7658) test
  only AL or ignore the result.
- Nothing branches into the replaced ranges (0x49880B..0x498816, 0x506B3C..0x506B40); the
  continuation 0x498817 and the store 0x67ABD4 lie outside them. The `jne`/`jmp` after the replaced
  compare at 0x506B41 stay, unreachable.
- With the marker ID -1 (before the data loads) both hooks behave as stock.
- The decision reads only game state (proto types, the unit table, state bits, HP); addUnit runs in
  the simulation on every machine, in the same order.
- **Observed in game:** a marked Market created for a player without a Town Center became his first
  town center; `[player+4F0h]` held its ID (3), where stock leaves -1.
- **Not covered:** the other `TownCenter` checks ([modding guide](modding-guide.md#startingtc)); a
  captured first town center; a hook on unit removal (a dead first town center is replaced only
  when a marked building is added afterwards).

### civFirstTC

WoL's design (request #3, by WoL's developer Mandos): a civ names its first building in
`civs.xml`, `<firstTC>Proto</firstTC>`; wherever map code places `TownCenter` for its players,
that proto is placed instead, except in a Nomad start, and it is the `FirstTC` the placement rules
read.

**The stock start.**
- **Map placement.** A random map script places the starting buildings through object defs:
  `rmAddObjectDefItem(def, "TownCenter", 1, 0.0)`, then an `rmPlaceObjectDef*` call. Every
  `rmPlaceObjectDef*` reaches FUN_00925F11, which calls objectDef::place FUN_00925936
  (`int thiscall(def, player, float x, float z, count)`, `ret 10h`) at 0x925F4C, its only call
  of place. A def holds its items at `[def+8]` (count `[def+0Ch]`), 20 B each: `+0` the proto ID,
  `+0Ch` / `+10h` a footprint that objectDef::addItem computes at 0x924B1D: when the proto has
  flag 2 (0x45EE02), `(int)([proto+88h] × [[world+88h]+1Ch] × 2 + 0.5)` and the same with
  `[proto+8Ch]`, else 0. A def made by `rmCreateStartingUnitsObjectDef` has the byte `[def+55h]`
  set (`Special_StartingUnits`): place tests it at 0x925988 and rebuilds such a def's items from
  the civ's `<startingunit>` list. The random map object is `[game+92Ch]`; rmGetNomadStart
  (0x90B683) returns its byte `+1A95h`, or false without one.
- **civs.xml.** The parser FUN_0052A590 compares each child tag of a `<civ>` with the names it
  knows (BString compare 0x443C10; the last compare is at 0x52BAFA). A tag that matches none
  reaches 0x52BB07: `xor edi,edi / cmp [ebx+80h],edi`, then `jle 52B43Dh / jmp 52C066h` (the
  resource names, then a silent skip). Every handled tag goes on at 0x52B43D, the next child.
  There ESI = the node (element name `[[node+4]+18h][[node+18h]]`, text `[node+14h]`, both wide),
  EBX = the database and `[esp+10h]` = the civ (`[civ+4]` its name, `[civ+8]` its ID).
- **FirstTC.** Player::addUnit makes a unit the player's first town center only while there is
  none, and only for the exact proto `TownCenter` (0x506B3B; see [startingTC](#startingtc)).
- **The town starting units.** FUN_0049039A (EDI = the player) hands the civ's
  `<townstartingunit>` units (settlers, crates) to a building. At 0x679AC8 it loads the
  `TownCenter` proto ID (`mov ebx,[ecx+5E08h]`), and the query after it takes the player's first
  built unit of proto EBX. FUN_007C238E(`[player+3E0h]`, that unit's ID) then spawns them, but
  only when bit 0 of the colony list `[player+3E0h]` is clear and one of its colonies has
  `[colony+28h]` = that unit (loop 0x7C2407). In game, a colony started at a building whose proto
  is listed in `<starttypes>` of `placementrules\colonies.xml`. After the call,
  `and byte [player+349h],0BFh` (0x679B63) clears the request, player flag 14, whether or not
  anything spawned. While no built `TownCenter` exists, nothing reaches the spawn and the request
  stays, so the units come with the first Town Center (static reading).
- **Who asks for them.** The request bit is set by the player flag setter 0x8D00E5, called at
  0x6A214A when a unit is created whose proto has flag 136 (0x6A211F..0x6A214A,
  `[[proto+50h]+11h]` & 1). Flag 136 is `StartingColonyBuilding`: the `protoy` flag parser maps
  that name (0x5F7018) to `or byte [eax+11h],1` (0x5FD751). Stock `TownCenter` has the flag,
  `Market` does not. This was found in game: a Market that was the first town center, with a
  colony started at it, got no settlers until it had the flag.

**The hooks** (`features/civfirsttc.cpp`, `hooks/civfirsttc_hooks.asm`):
1. **civs.xml**, a `jmp` over 0x52BB07 (8 B, `jmp` + 3 NOP). Inside `pushad`/`popad` it calls
   `UhcCivFirstTcTag(node, civ)`, which compares the element name with `firstTC`, ignoring case.
   For that tag it keeps the text, trimmed (non-ASCII characters become `?`), by civ ID together
   with the civ object, logs it and returns true; a later tag of the same civ replaces it. True →
   `jmp 52B43Dh`, the next child. False → re-execute `xor edi,edi / cmp [ebx+80h],edi` and
   `jmp 52BB0Fh`, which branches on those flags. The parse runs after `UHCMain`, so every parse
   is seen, including the one at each skirmish start.
2. **Map placement**, `WriteCall` at 0x925F4C to `UhcRmPlaceObjectDef`, a `__fastcall(def, unused,
   player, x, z, count)` function with the thiscall frame, which returns place's result. It calls
   the stock place unchanged unless a `<firstTC>` was read, the world and database exist, the def
   has items, `[def+55h]` is 0, an item holds the `TownCenter` proto ID `[db+5E08h]`, and the
   owner (`[world+58h][player]`) has a civ (`[[player+20h]]` when `[player+24h]` > 0, as 0x4539D3)
   whose `<firstTC>` resolves to a proto other than `TownCenter`. In a Nomad start it then calls
   place unchanged (and logs, with `log`). Otherwise it saves each `TownCenter` item, gives it the `<firstTC>` proto ID
   and the larger of the two footprints (the new proto's computed as addItem does), calls place,
   and puts back each saved item that is still below the count and still holds the substituted
   proto. The same def therefore places a `TownCenter` for the next player.
3. **FirstTC**, in the proto hook it shares with `startingTC` (0x506B3B): when the unit is not a
   `TownCenter`, `UhcCivFirstTcMatches(player, protoId, unit)` (stdcall) returns true when the
   player's civ names the unit's exact proto ID (the EAX the cold chunk loaded) and the Nomad byte
   is 0; the hook then jumps to the stock store 0x67ABD4. This is also what makes a building
   loaded from a scenario or a saved game the first town center again.
4. **Town starting units**, a `jmp` over 0x679AC8 (6 B, `jmp` + 1 NOP). It re-executes
   `mov ebx,[ecx+5E08h]`, calls `UhcCivFirstTcTownProto(player = EDI)` and puts the result in EBX
   when it is ≥ 0, then continues at 0x679ACE. The helper returns the `<firstTC>` proto only when
   the player's FirstTC `[player+4F0h]` is in the unit table (looked up as 0x44CC6D does), of that
   exact proto, owned by the player (`[unit+44h]`), alive (unit vtable slot A4h), and a colony
   starts at it (the test of 0x7C2407, repeated). Otherwise it returns -1, and logs once per game
   when only the colony is missing: EBX stays `TownCenter`, so the request is never spent on a
   spawn that would create nothing.

**Name resolution.** `CivFirstTcProto(player)` takes the civ ID as 0x4539D3 does and checks that
the civ by ID (0x405C2E) is still the object the tag was read for, so a tag from an older parse
never applies to a new civ table. It resolves the name with 0x5A2346 on first use and again
whenever the database's proto array `[db+54h]` is another one (a data reload); an unknown name
gives -1 and is logged once per resolution.

**Why it is safe.**
- Every exit is stock code: 0x52B43D reads only the stack and 0x52BB0F the flags the hook
  rebuilt; the placement wrapper returns to 0x925F51 with place's result in EAX and the stack as
  `ret 10h` leaves it; 0x67ABD4 and 0x498817 read only EDI and ESI (see [startingTC](#startingtc));
  after 0x679ACE, EAX, ECX and EDX are written before they are read. The C++ helpers are
  `__stdcall` and keep EBX, ESI, EDI and EBP.
- The object def is changed only for the length of one place call, and only its `TownCenter`
  items; a `Special_StartingUnits` def is never touched, since place rebuilds its items itself.
  Nothing else in the game changes: the map script, the database and the civ are read only.
- Every decision reads only game state: the player's civ, the database, the random map's Nomad
  byte, the unit table and the colonies. The footprint is addItem's formula computed in single
  precision in the DLL, the same on every machine with this build.
- The town hook changes only which proto the stock query looks for; the spawn, its units and the
  request are stock. Because it repeats FUN_007C238E's colony test, a request it redirects is
  always one the spawn can serve.
- The once-per-game log tables reset when the world pointer changes or its step count goes back;
  they decide only what is written.

**Observed in game** (2026-10-29, single player): a `TownCenter` item of a test map and of the
stock map Mongolia's own def `startingTC` became a Market for the tagged players only; the
Market's ID was in `[player+4F0h]`; with `StartingColonyBuilding` on the Market, 6 Settlers
spawned at it; an untagged AI kept its Town Center. In those games `[game+92Ch]` stayed allocated
during the game and its byte `+1A95h` was 0.

**Not covered:** a Nomad start was not driven (TAD's skirmish setup has no Nomad option); a
`TownCenter` from `<startingunit>`; the AI scripts, which expect a Town Center (a tagged AI got
its Market and settlers, then stayed idle), and the engine's AI auto-base FUN_004CF222; the age-up
picker `uiPoliticianUI` (0x7E6905, 0x7E803F), the start camera (0x82E45B), the `Maintain` spawn
gate (0x492FD6) and the water shipment point `[hc+190h]`, which all look for `TownCenter` itself.

### transformInventory

**Where a unit's resources live.**
- Each proto with a resource tag (`InitialResource`, `CarryCapacity`, `GathererLimit`) has a
  resource object at `[proto+E0h]` (14h bytes): `+0` the `InitialResource` list, `+8` the
  `CarryCapacity` list, `+10h` the `GathererLimit` byte. The `<InitialResource>` handler 0x5F8643
  writes the list at `+0` through the list setter 0x58EF83.
- A resource list is 8 bytes: `+0` an array of `[0xC6DF38]` floats, entry r XORed with the dword
  at `0xC6DF14 + 4r`; `+4` the total, XORed with `[0xC6DF10]`. Every setter recomputes the total
  (0x58EF83 → 0x58EF02). The exe registers 8 resource names, Gold to Trade, at 0x5381E0, and holds
  8 keys in `.data`.
- Each unit that holds resources has its own inventory at `[[unit+B4h]+94h]`, a 14h-byte pool
  object (pool 0xCAFCA8): `+0` the unit ID, `+4` a resource list, `+0Ch` and `+10h` −1 when fresh.
  `+10h`, when not −1, is the resource type a gatherer takes (Gather set-target 0x4EDC50,
  scoping).
- Unit creation seeds it only when the proto has a resource object (0x4983A0 → cold 0x67DE0D):
  `0x9BFE5A(unit)` (free any old inventory, allocate a fresh one, store the unit ID), then
  `0x480A73(inv+4, [proto+E0h])`, a raw copy of the encoded entries and the total.
- Gathering, the AI knowledge bases and death at zero resources read the inventory, never the proto
  (scoping): the gather target's type comes from the inventory (0x4DBEC1); a target with no
  inventory or an empty one is skipped; `DieAtZeroResources` kills a unit whose inventory exists
  and totals ≤ 1e-6.

**The stock bug.** FUN_009C754C, the in-place transform (`TransformUnit` 0x7FBC79, revolution
0x7FBEF2 / 0x8F05F5, and 0x6A42C8, 0x8C2D08, 0x8EB78A, 0x9BB6D5, 0x9C7C16), calls setProto and
rebuilds HP, build points, obstruction and visibility, but has no operand on `+94h` or `+E0h`, and
none of its callees reaches the inventory except through a read (scoping, re-checked by the
verifier). The unit keeps its old proto's inventory, or none. A conversion then zeroes it: the
owner change 0x514358 keeps the proto ID and sets each resource to
`min(cur[r], newInit[r] × cur[r] / oldInit[r])`, or 0 when `oldInit[r]` is 0 (scoping). The trigger
"Change Unit Type" is right in stock: the unit reset frees the inventory (0x4729D0 → 0x4BA74C) and
the re-add seeds it from the new proto. In game, with the key on, a Musketeer turned into a
`CrateofXP` was logged `inventory created: none -> {5: 100}`: it reached the transform with no
inventory. That the rest of the transform never creates one is static analysis; no run with the
key off was made.

**The hook** replaces `mov eax,[esi+58h] / test eax,eax / je 9C763Ch` at 0x9C7625 (7 bytes: `jmp`
+ 2 NOP). There, ESI = the unit, EBP = the player's copy of the new proto (from 0x9C7560, unchanged
until 0x9C764D) and `[esi+5Ch]` is still the old proto. Inside `pushad` / `popad` it calls
`UhcTransformInventory(unit, newProto)`, then re-executes the three stolen instructions and jumps
to 0x9C762C (`push eax / call 4BA630h`, which needs EAX = `[esi+58h]`) or 0x9C763C (`push ebp /
mov ecx,esi`, then setProto, or transformUpdatesLOS's hook). The helper:
1. returns if `[unit+B4h]` or the new proto is null, if a type is configured and the new proto is
   not of it (is-a 0x44D7FA), or if `[0xC6DF38]` is outside 0..64;
2. new proto without a resource object: keeps the inventory (stock), or with `all` frees it like
   0x4BA74C / 0x4BA7A7: cdecl `0x4BA757(inv)`, then `[[unit+B4h]+94h] = 0`;
3. without `all`, keeps the inventory when it exists, the old proto has a resource object and both
   `InitialResource` lists hold the same types (decoded value > 1e-6 per index);
4. otherwise rebuilds: a missing inventory comes from `0x9BFE5A(unit)`; an existing one is reused
   with `+0Ch` / `+10h` set to −1; then `0x480A73(inv+4, [newProto+E0h])`. With `scale`, the factor
   `clamp(total(inv) / total(oldInit), 0, 1)` is computed before the copy and applied after it with
   the list's own scale 0x480B94.

**Why it is safe.**
- The point lies after the other players' knowledge bases dropped the unit (0x9C75FE, which reads
  its old resource type) and the own player's removal (0x9C7620), and before the player add
  (0x9C7658), the knowledge base re-add (0x9C768D, which reads the new amounts) and setHP's
  checkState (0x9C76F3), so every reader sees one consistent inventory.
- The rebuild repeats creation's own recipe with the engine's own functions, and the free repeats
  "Change Unit Type"'s. An existing inventory is reused, not freed, so a pointer held elsewhere
  cannot dangle.
- The amounts are copied as raw encoded dwords, as stock copies them. The only float arithmetic in
  the DLL is the `scale` factor: one single-precision SSE division of two game values, the same on
  every machine with this build. No RNG, local player, UI state or clock. The pool allocation is
  the one creation makes, in step on every machine.
- All registers are preserved for the stolen code; the flags are dead after its `je`; the x87 stack
  is empty at the site (the transform stored its values with `fstp`).
- It is independent of transformUpdatesLOS (0x9C763F): the verified ranges do not overlap, and this
  feature does not verify `TransformSetProto`, where that feature writes.

**Not changed:** gatherers already working the target keep their `[action+70h]` type and stop at
their next gather tick after a cross-type rebuild (0x4ECEA6 → 0x50E327, verifier). Units with a
mismatched inventory from an older save are not repaired; that would need a hook in the owner
change or the load path.

### noTrainNearEnemyTC

**FirstTC.** See [startingTC](#startingtc): `[player+4F0h]` holds the unit ID of the player's first
Town Center, set once by Player::addUnit and never cleared. The rule `distanceAtLeastFromType`
FUN_008CE935 loops over the players 1 .. `[world+5Ch]`-1 (0x44CB21), looks each FirstTC up in the
unit table with an ID check, calls the Town Center's vtable slot B8h with the placement point
(distance from the Town Center to a point), keeps the ones closer than the rule distance, then
filters them by `player=` on the owner `[tc+44h]`: 3 (enemy) is `0x484D2D(owner, builder's player
ID)`, `[owner+1D4h+4*id] == 2`.

**The Train update.** FUN_009EA28B (`thiscall(action)`, vtable 0xB98388 slot 3Ch) runs every tick
of a Train action: ESI = the action, `[action+10h]` = the trainer, EDI = its player. With a queue in
progress it calls the work-rate getter at 0x9EA410 (`mov ecx,[esi+10h] / call 9BFE33h`), multiplies
the rate by `[world+310h]`, `[world+104h]`, two optional factors and the civ's train rate
(FUN_008D4790), and adds the result to the progress `[action+68h]`; 0x9EA1FA turns it into the
fraction `[action+6Ch]` = `[+68h]` / `[+64h]`, and a fraction of 1.0 completes the unit. Stock never
asks where the trainer stands.

**The hook.** An 8-byte `jmp` (+3 NOP) over `mov ecx,[esi+10h] / call 9BFE33h`:
1. with the marker resolved, it calls `UhcNoTrainBlocked(trainer)` (stdcall; the x87 stack is empty
   there, as no x87 code runs in the function before);
2. blocked: `fldz` (rate 0.0) and `jmp 9EA418h`;
3. otherwise: `mov ecx,[esi+10h]`, then `call [g_uhcBwrTrainGetter]` and `jmp 9EA418h`. The pointer
   holds 0x9BFE33, the stock getter (so `liveBuildingWorkRate`'s getter hook still applies), or
   `buildingWorkRateAuras`' wrapper when that key is on.

`UhcNoTrainBlocked`: false unless the trainer's proto is of the marker type (0x44D7FA). Then, for
players 1 .. `[world+5Ch]`-1 in order: FirstTC `[p+4F0h]` ≥ 0, the unit 0x44CC6D(world, id)
exists, its owner `[tc+44h]` is not the trainer's player and `0x484D2D(owner, trainer's player ID)`
is true, it is alive (unit vtable slot A4h), and its distance `[vtbl+B8h](tc, trainer+14h)` is the
smallest so far. Blocked when that smallest distance is below `<meters>`.

**Why it is safe.**
- Both paths leave one value on the x87 stack, as the getter does. After `0x9EA418`, EBX and EAX
  are loaded before they are read, ECX at `0x9EA42C`; EDX is not read (0x485D2C, called at
  0x9EA432, starts with `mov edx,ecx`), nor are the flags. The helper keeps ESI, EDI, EBP and EBX
  (stdcall); the stack is balanced. `WorkRateTrainCall` and `TrainRateScale` are verified sites.
- A rate of 0.0 is a state the update already handles: `[+68h]` does not move and 0x9EA1FA keeps
  the fraction below 1.0. The queue, its resources and its population stay as stock left them.
- The answer depends only on simulation state (unit types, FirstTC, stances, alive state,
  positions), read in player order with the engine's own functions and the placement rule's
  distance call; the comparison with `<meters>` is a single-precision compare. No local player,
  clock or interface state is read.
- `liveBuildingWorkRate` verifies `WorkRateTrainCall` before this feature writes it, and
  `buildingWorkRateAuras` is applied after it (the order in `features.h`).
- **Observed in game:** a Daimyo 34.1 m from an enemy Town Center made no progress, and trained
  both queued units once that Town Center was killed. The distance's reference point (the Town
  Center's center or its edge) is not known.
- **Not covered:** players whose FirstTC is dead or never set; refusing the order instead of
  pausing it.

### overhealHitpointBars

**The stock numbers.** The `<MaxHitpoints>` tag handler (0x5F5CED) stores `[proto+98h]` (`fstp
[ecx+98h]` at 0x5F5D39), `<InitialHitpoints>` (0x5F5C97) `[proto+9Ch]` (0x5F5CE3). Unit creation
FUN_00498274 starts the unit at `[proto+9Ch]` (`mov ecx,[ebp+9Ch] / push 1 / push ecx / call
4820A1h` at 0x498390; the setter clamps to the max). The max HP getter `0x480408`,
`float thiscall(unit)`, returns the per-unit override `[[[unit+0B4h]+0C8h]+4]` when that record
exists and its value is above −1e-6, else `[[unit+5Ch]+98h]`, else 0. The health ratio `0x45F295`,
`float thiscall(unit)`, takes the same max and returns 0 below 1e-6 (constant 0xB9FB64), 1.0 when
HP `[unit+64h]` reaches it, else HP / max. The `Hitpoints` tech effect (case 0 of FUN_008F973F) adds
the max's change to `[proto+9Ch]` too (0x8F97CD..0x8F97DD).

**The displays.**
- Floating bars: the unit visual update's bar chunk 0x45FAA2 takes the fill from `call 45F295h`
  (0x45FAAF; under construction the build fraction, 0x6A1431, instead), clamps it to [0, 1]
  (0x45FAB8..0x45FADC) and queues the bar (0x45FB71). The renderer (0x45C5xx, scoping) draws
  0.5 + 0.5 × fill of the `hpbar` texture, so a fill above 1 cannot simply overflow the bar.
- Selection groups: FUN_004C4FB5 adds a unit to a group and keeps the running average of 0x45F295
  at `[group+1Ch]` (`call 45F295h` at 0x4C5014). Readers: the selection panel's bar, green / yellow
  / red by the thresholds 0.33 / 0.66 (doubles 0xBA1F80 / 0xBA1F78, 0x4C82EA), and "Group Health",
  `[group+1Ch]` × 100 with `%0.0f%%` (0x69AA75).
- HP texts, `%d/%d` (0xBA2054) or `%d/%d (%d+%d)` (0xC34A54) when the unit's max is above the
  database proto's `[+98h]`; HP and max go through `fistp` with RC = 11b (truncation):
  - T1, the selection panel's `unitHitPointsValue`: `call 480408h` at 0x698B35;
  - T2, the selection panel's 'Hit Points' stat row: the getter inlined at 0x4D7575..0x4D75AC, the
    base `fld [eax+98h]` at 0x4D7615 (EAX = database proto), the split in cold 0x69A9B0;
  - T3, the ObjectInfo_singleUnitStats panel FUN_009AF31A: base `fld [ecx+98h]` at 0x9AFA2A (ECX =
    database proto from 0x45316E), max `call 480408h` at 0x9AFA4E.

**The reference.** For a unit whose proto (`[unit+5Ch]`, its player's copy) is of a configured type
(is-a 0x44D7FA) and has 1e-6 < `[+9Ch]` < `[+98h]`, the reference is `[+9Ch]` when the unit's max
equals `[+98h]` (no override), else max × `[+9Ch]` / `[+98h]`. The proportional form follows the
stock ratio-preserving rescale 0x9C738B (HP = ratio × new max, used after a modifier recompute,
0x49F1DB): a unit at its reference before an aura is at its reference after it. `[+9Ch]` is
returned as it is, not through the product: 165 × 150 / 165 rounded at single precision could give
149.99998, which the truncating `fistp` prints as 149.

**The hooks** (`hooks/overheal_hooks.asm`), each a 5- or 6-byte `jmp` (NOP-padded) that redoes the
stolen instruction with the reference and jumps to the next one:

| Site | Stolen | Hook does | Continues at |
|---|---|---|---|
| 0x45FAAF | `call 45F295h` (ECX = ESI = unit) | `call OverhealRatio` | 0x45FAB4 `fstp [esp+10h]` |
| 0x4C5014 | `call 45F295h` (ECX = EBP = unit) | `call OverhealRatio` | 0x4C5019 `fadd [esi+1Ch]` |
| 0x698B35 | `call 480408h` (ECX = EBX = unit) | `call OverhealReference` | 0x698B3A `fnstcw` |
| 0x4D7575 | `mov eax,[ecx+0B4h]` (6 B; ECX = EDI = unit) | `call OverhealReference`, replacing the whole inlined getter | 0x4D75AD `fnstcw` |
| 0x4D7615 | `fld [eax+98h]` (6 B) | `mov ecx,eax / call OverhealBase` | 0x4D761B `fnstcw` |
| 0x9AFA2A | `fld [ecx+98h]` (6 B) | `call OverhealBase` | 0x9AFA30 `fnstcw` |
| 0x9AFA4E | `call 480408h` (ECX = ESI = unit) | `call OverhealReference` | 0x9AFA53 `fnstcw` |

`OverhealReference` calls the stock `0x480408` first, so an unmarked unit gets exactly the stock
max. `OverhealRatio` applies the stock rules of 0x45F295 to HP / reference (same compares, `jnp` on
the same status bits; `fldz` / `fld1` for the stock 0.0 / 1.0). `OverhealBase` returns the database
proto's `[+9Ch]` under the same condition, else `[+98h]`. With `log`, the reference path stores its
two values, calls `UhcOverhealLogReference(unit, reference, max)` with an empty FPU stack and
reloads the reference.

**Why it is safe.**
- Only display code is patched: the floating bar queue, the selection grouping (the local
  selection, which differs per machine, so stock cannot feed it into the simulation) and three text
  panels. `0x45F295` and `0x480408` keep their 25 and 45 callers (heal search, transforms, the
  modifier recompute, AI queries, triggers) unchanged, and no hook reads the local player.
- The sites decode at instruction boundaries and nothing branches into the stolen bytes; at
  0x4D7575 the getter's own branches (0x4D7583, 0x4D7596, 0x4D75A6) and cold blocks (0x69FB66,
  0x69FB6E) only rejoin at 0x4D75AD, which the hook jumps to.
- At every site the FPU stack is empty (the HP was just stored with `fistp`, or it is a call site),
  and the hooks leave exactly one value in ST0, as the stolen instruction did.
- EAX, ECX, EDX and the flags are written before they are read after each continuation; the
  helpers keep EBX, ESI, EDI and EBP (0x4C501C pops EDI and EBX; 0x45FAE2 reads ESI). The is-a test
  changes only EAX, ECX and EDX and uses no FPU register.
- **Observed in game:** a marked Musketeer at 150 HP with `MaxHitpoints` 165 showed `150/150` and a
  full bar in its panel; an unmarked Pikeman (120/132) kept the stock display.

### showGatherRate

**The stock rate rows.** The stat panel (`uiunitstatpanel3`; 9 label/value rows `StackLabel%d` /
`StackValue%d`, bound to `[panel+174h+i*4]` / `[panel+198h+i*4]` by 0x9BBAD1) is filled by
FUN_004D70ED, split into a hot part and a cold part (0x698A00..0x69C800). The row counter is
`[esp+2Ch]` (2 after the HP row), the first selected unit `[esp+38h]`, and `[ebp+8]` the selection
(`+14h` count). After the HP row, the AutoGather block (0x4D76FF..0x4D7834) checks: byte `[sel+21h]`
= 0, the row < 9, one selected unit, the unit built (`[unit+68h]` null or complete), an action
manager `[unit+58h]`, proto flag 9Bh (cleared by `DoNotShowAutoGatherRate`), not `Herdable`, and an
AutoGather action (0x485CAC(mgr, 1Dh)). The cold part then runs a row writer (0x69AF7C: the two
gadgets of row EBX; a missing one jumps back to 0x4D7834), a loop over the resources that asks the
AutoGather getter 0x49EBE4 for each rate and stops at the first non-zero one (0x69AFE0..0x69B028:
EBX = resource, `[esp+1Ch]` = rate), and a formatter (0x69B02A..0x69B182): label
`%s (<icon="(32)(%S)">):` with the resource's name and icon, value `%.2f/s`, or `%d/s` when the
rate is a whole number, then `add [esp+2Ch],1` and `jmp 4D7834h`. Every way out of the block lands
on 0x4D7834.

**The villager's rate.** BUnitGatherAction::doAnimationLooped (0x4ECC88, Gather action vtable
0xB97880) calls collectStuff_2 (FUN_004ECD87, `thiscall(action, float elapsed)`, `ret 4`) once per
gather animation loop while the action's state byte `[action+61h]` is 5, with elapsed = the loop's
length (0x4939BD). The tick reads the gatherer `[action+10h]`, the target's ID `[action+14h]` and
the resource `[action+70h]`, and computes R = ((cur − base) + k·base) · `[world+318h]` · Gathering
dance (0x4ECD39 at 0x4ED02A). If R ≤ 1e-6 the action ends; otherwise, at 0x4ED044, `fmul
[esp+30h]` multiplies R by elapsed. The amount is clamped to what the target holds, multiplied by
`[player+37Ch]` (0x4ED13A), set to 0 for an `AbstractShrine` target (0x4ED14B) or a player with
`[player+338h]` set (0x4ED1AB), and added to the stockpile by 0x49A98A (0x4ED1EE). No function
returns R.

**The data refs.** FUN_005CFA7C registers the `formatText` data refs `{id, type, name,
provider}`. `currentUnitGatherRate` (19h, int), `…Float` (1Ah, float) and `…String` (68h, string)
point to 0x5FDE49 (`xor al,al / ret 4`), which always fails. A provider is `bool provider(Value*)`,
`ret 4`; the evaluators (vtable 0xB9EA48: 0xAB9544 color, 0x44A25A string, 0xAB94A2 int, 0xAB9400
float) only call a ref whose registered type matches theirs, or, for the string evaluator, dispatch
on the registered type (jump table 0x44A40C), and set `Value.type` to that type first. A type-3
Value is `{3, BString}` with an empty BString (0x44A635).

**The hooks.**
- **Record** (0x4ED044, 8 bytes: `jmp` + 3 NOP over `fmul [esp+30h] / fst [esp+14h]`). ST0 = R
  there, the only value on the x87 stack. The hook saves EAX, ECX and EDX, and fills the record
  `(ID & 3FFFh)` of a 4000h-entry DLL table (32 bytes each, 512 KB): gatherer ID, the action, the
  resource, the target's ID, R × `[player+37Ch]` (computed on a copy: `fld st(0) / fmul / fstp`),
  elapsed (`[esp+3Ch]` after the three pushes) and the game time `[world+108h]`; the ID last. It
  restores the registers, re-executes the two stolen instructions and jumps to 0x4ED04C.
- **Panel** (0x4D7834, 7 bytes over `mov esi,[esp+38h] / mov ecx,[esi+5Ch]`, the join point after
  the AutoGather block). If `g_uhcGatherRowPending` is set, the row writer has just come back: the
  hook clears it and takes the stock path. Otherwise `UhcGatherPanelRow(unit, selection, row)`
  checks the stock gate (except Herdable and the AutoGather action), the optional unit type and the
  record. The record is valid when the unit's ID matches, `[[unit+58h]+24h]` (the current action) is
  the recorded action, that action's state is 5 and its `[+10h]` is the unit, the resource is below
  `[db+80h]`, the rate is above 0, the record is at most max(2.5 s, 2 × elapsed) old in game time
  (capped at 60 s), the player's `[+338h]` is 0 and the target (if it still exists) is not an
  `AbstractShrine`. On success the hook sets the pending flag, EBX = the row, and jumps to the
  stock row writer 0x69AF7C. The stock path re-executes the two stolen instructions and jumps to
  0x4D783B.
- **Row value** (0x69AFE0, 6 bytes over `mov ecx,[0C66234h]`, the start of the AutoGather loop,
  reached only by fall-through). With the pending flag, it sets EBX = the resource and `[esp+1Ch]`
  = the rate, exactly what the loop leaves, and jumps to the formatter 0x69B02A; otherwise it
  re-executes the `mov` and continues at 0x69AFE6. The formatter writes the row in the stock style,
  adds 1 to the row counter and jumps back to 0x4D7834, where the panel hook clears the flag.
- **Data ref** (the imm32 at 0x5D2D3C, `mov dword ptr [esp+2Ch],5FDE49h`): the provider of id 68h
  becomes `UhcGatherRateRefHook`, which traces and jumps to the stdcall `UhcGatherRateRef(Value*)`.
  For a type-3 Value it reads the current unit as FUN_006F49B1 does (`[[[0C67310h]+920h]+13Ch]` in
  the world), applies the same record test, and assigns `"<name> 0.67/s"` (`%d/s` for a whole
  number) to the Value's BString with 0x443BB8; otherwise it leaves the empty string and returns
  true. The resource's name is `0x58EA52(0x60782A(db, res))`, freed with 0x4010CA. Ids 19h and 1Ah
  keep the stub (their shared imm32 at 0x5D06E8 is not written): WoL's UI uses
  `{currentUnitGatherRate(gold)}`.

**Why it is safe.**
- The simulation is unchanged: the record hook only reads game memory and writes the DLL's table.
  R stays in ST0 untouched (the multiplication runs on a copy that is popped), the x87 stack has
  the same depth on exit, the control word is not touched, and the flags are dead at 0x4ED044 (the
  `fcomp / fnstsw / test` after the continuation set them).
- The row writer is entered with the state the stock AutoGather path gives it: the same frame
  (0x4D782E and 0x4D7834 are adjacent, with nothing constructed or destroyed between them) and
  EBX = the row; it reloads every other register. The formatter needs only ESI/EDI (set by the
  writer), EBX and `[esp+1Ch]`; it overwrites `[esp+0Ch]` in its `%d/s` branch, so the re-entry
  guard is a DLL global, not a stack slot. All three exits of the writer go back to 0x4D7834.
- If a write fails part-way, nothing diverts: the row value hook is written first and the panel
  hook, the only one that sets the pending flag, last.
- The record is checked against the unit's live state on every read (current action, state 5,
  owner, game time), so a stale or colliding entry shows nothing rather than a wrong rate; actions
  come from a pool, which is why the owner and the time are checked too.
- The data ref keeps the stub's answer for any other value type, and the int and float refs keep
  the stub itself.
- **Observed in game:** a Settler on a berry bush got the row `Alim. (icon): 0.67/s` right under
  its HP row, with the rate the log reported (0.670/s; the stock `Settler` gathers `BerryBush` at
  0.67).

### buildingWorkRateAuras

**The stock mechanism.**
- **Names.** FUN_005F5645, `int cdecl(BString* name)`, turns a ModifyType name into a stat with a
  chain of compares through 0x443C10 (`thiscall(BString*, const wchar_t*, flag, n)`, `ret 0Ch`,
  0 = equal; flag 0 makes CompareStringW ignore case). The last compare is `AutoGatherRate`; its
  tail `neg eax / sbb eax,eax / and al,0F1h / pop esi / add eax,0Eh / ret` (0x5FE6D7..0x5FE6E1)
  returns 0Eh on a match and -1 otherwise. Two callers: the tactics `<ModifyType>` handler 0x5FC8AE
  stores the result unchecked in the byte `[action+B8h]`, and the powers' `<unitModify>` parser
  0x5F3EFA rejects a negative stat.
- **Modifiers.** An `AutoRangedModify` aura (FUN_009D033E) calls 0x4DD22D for each unit in range,
  which creates the unit's modifier record `[[unit+B4h]+C8h]` when it is missing and adds a unit
  action of type 2Ch: stat `[+64h]`, value `[+68h]` (the multiplier), operation `[+78h]` = 2
  (multiply). Powers and the second applier 0x9D7696 use the same call.
- **Readers.** The lazy recompute FUN_0049F1BA collects the unit's type-2Ch actions (0x49F1A0,
  depth first) and sums 13 stats with 0x4B3C7D into the record; any other stat is ignored. A reader
  such as the gather rate (0x4ECFE9 → 0x69FE53) uses the record's field when it is at least 1e-6,
  else 1.0.
- **BuildingWorkRate** is not a modifier stat. The getter 0x9BFE33 returns the building's copy
  `[[unit+68h]+28h]`, or the proto's `[proto+D0h]` for a unit without building data
  ([liveBuildingWorkRate](#livebuildingworkrate)), and is called by the per-tick updates of Train
  (0x9EA413), Research (0x9E65F7), CommandResearch (0x9D58D4) and Maintain (0x6AB23F).

**The hooks** (`hooks/bwraura_hooks.asm`).
1. **Name, 0x5FE6D7** (6 bytes, `jmp` + 1 NOP over `neg / sbb / and`). EAX = the `AutoGatherRate`
   compare, ESI = the name. On a match EAX stays 0. Otherwise the hook compares the name with
   L"BuildingWorkRate" through the same 0x443C10 call (`push -1 / push 0 / push name / mov
   ecx,esi`): a match gives EAX = 40h − 0Eh, anything else −0Fh. It continues at 0x5FE6DD, so the
   tail returns 0Eh, 40h or −1. Stat 40h is new: no stock code produces it, the recompute skips
   it, the save writes `[+64h]` as an int, and the aura tooltip (switch on stat − 1, cases 0..5)
   takes its default case.
2. **Rate, the calls of 0x9BFE33** (their rel32 points to `UhcBwrAuraCall`). The wrapper has the
   getter's contract, `float thiscall(unit)`:
   - a unit without a modifier record (`[[ecx+B4h]+C8h]` null) tail-calls the getter: the stock
     call, bit for bit;
   - otherwise it calls the getter (ST0 = the rate, through liveBuildingWorkRate's hook when that
     key is on), stores it as a float and calls `UhcBwrAuraRate(base, unit, return address)`. The
     helper walks the unit's type-2Ch actions in the collector's order (`src/modifiers.h`, the walk
     `snareOnlyHitUnit` also uses), keeps those with stat 40h, and calls the stock sum 0x4B3C7D on
     them from 1.0. With no match, or a sum below 1e-6, the factor is 1.0 and the helper returns the
     base unchanged; otherwise base × factor. The wrapper restores ECX and EDX and returns.
3. **The Train call and noTrainNearEnemyTC.** That key replaces `mov ecx,[esi+10h] / call 9BFE33h`
   at 0x9EA410 with its own hook, which calls the getter through the exported pointer
   `g_uhcBwrTrainGetter` (default 0x9BFE33). This key sets the pointer to its wrapper and writes the
   Train call's rel32 only when 0x9EA410..0x9EA417 are still stock; the other three calls are
   redirected either way.

**Why it is safe.**
- One `VerifyAll` checks 13 sites before the first write: the name tail and its continuation, the
  compare's head, three call sites with the code after them up to the first write of EAX, the
  Train call's continuation, the getter's tail, the collector, the sum with its two cold chunks,
  and the GatherRate reader whose rule the factor mirrors. The getter's first 5 bytes must be stock
  or liveBuildingWorkRate's `jmp`, and the Train call is checked on its own.
- The name hook keeps EBX, ESI, EDI and EBP; ECX, EDX and the flags are free at the tail, whose two
  callers read only EAX.
- The wrapper returns with ECX, EDX, EBX, ESI, EDI, EBP and ESP as the getter does, and one value on
  the x87 stack. EAX and the flags differ, which each caller allows: it writes EAX before reading it
  and calls a function before it reads the flags.
- **Determinism:** the factor depends only on the unit's modifiers, which every machine has in the
  same order, and comes from the stock sum (x87, rounded to a float at each step). The product
  base × factor is one IEEE single multiplication. A unit with no stat-40h modifier gets the stock
  value. The log table only decides whether to write a line.
- It is the last WoL key in `features.h`, so the keys that verify the call sites as stock bytes
  (liveBuildingWorkRate, noTrainNearEnemyTC) check them before this key rewrites them.
- **Observed in game:** a BloodFactory inside an Explorer's 4.0 aura logged `works at x4.000` and
  spawned 11 musketeers while a factory without the aura spawned 2.

### bufferedFileReads

**Why it exists.** The game's raw file stream reads with one `ReadFile` per request
([performance.md](performance.md), §9):
- 0x4683F4 is the read method;
- 0x599121 reads 4 bytes;
- 0x43B8FF reads a 16-byte header as four such reads.

The archives (`art\Art*.bar`, `data\Data*.bar`, `sound\*.bar`, `render\*.bar`) are opened at startup
and stay open, and everything is read through their handles. In a session that is about 10 million
`ReadFile` calls, 93 % of them for 16 bytes or less. When a model or animation is loaded during a
match, those calls run on the main thread inside the world update.

**How it hooks.** `src/features/fileio.cpp` replaces six of the exe's KERNEL32 IAT entries:
- `CreateFileA` 0xB842A4 and `CreateFileW` 0xB84304;
- `ReadFile` 0xB8424C and `SetFilePointer` 0xB84244;
- `CloseHandle` 0xB84330 and `DuplicateHandle` 0xB843A0.

Each slot must still hold the address `GetProcAddress` gives for that function, or nothing is
written. The exe links its C runtime statically and imports no `msvcrt`, so its `fopen`/`fread`
also go through these slots. Granny reads through the game's own callbacks
(`GrannyInitializeFileReader`), so it does too.

**What is buffered.** A handle gets a buffer when it was opened:
- for reading only (no write, delete or ACL rights);
- without `FILE_FLAG_OVERLAPPED` or `FILE_FLAG_NO_BUFFERING`;
- on a disk file (`GetFileType`).

Its state is the file position the game sees, the real file pointer, and a buffer (64 KB by
default) with its file offset.
- **`ReadFile`:**
  - serves what the buffer holds;
  - otherwise moves the real pointer to the game's position if needed and refills the buffer
    with one real read;
  - reads of a buffer's size or more go straight to the file.

  End of file returns `TRUE` with fewer bytes, as Windows does.
- **`SetFilePointer`** only computes the new position: `FILE_BEGIN`, `FILE_CURRENT`, and
  `FILE_END` through `GetFileSizeEx`. Anything unusual (a result that does not fit 32 bits
  without a high part, an unknown method) is handed to Windows after the real pointer is synced.
- **Fallbacks.** A handle stops being buffered, after its real pointer has been moved to the
  game's position, when:
  - a thread other than the one that opened it uses it;
  - a read passes an `OVERLAPPED`;
  - it is duplicated, because a duplicate shares the file pointer.
- **`CloseHandle`** drops the state. The handle table takes a shared SRW lock for each operation
  on a tracked handle; `CloseHandle` and `CreateFile` take it exclusively, so a state is never
  freed while in use.
- Each hook keeps `GetLastError` as Windows would leave it.

**Checks.**
- `bufferedFileReads verify` reads every buffered request again with a real positioned
  `ReadFile` and compares the bytes. A full late-game session checked 7.5 million reads with no
  mismatch.
- `perfFileLog` counts the game's calls against the ones made to Windows. A session with the
  buffer made 10.2 million `ReadFile` calls by the game and 17,797 to Windows.

### multipleInstances

**Why it exists.** The game allows one running copy per machine
([engine-symbols.md](engine-symbols.md), 0x55A185). At startup it calls
`CreateSemaphoreW(NULL, 1, 1, name)` and then `WaitForSingleObject(h, 0)`. A timeout means another
copy holds the semaphore, and the game stops with "Only one copy of the game can run at a time". The
name is `Global\Age3`, so copies in different folders, and even in different sessions, share it. Tests
that run in several copies at once need that check gone.

**How it hooks.** `src/features/instances.cpp` replaces the exe's KERNEL32 IAT entry for
`CreateSemaphoreW` (0xB843F0), after checking that it holds the `GetProcAddress` address. The call
at 0x55A185 is the only one whose return address is 0x55A18B; site `SingleInstanceSemaphore` checks
its stock bytes. For that call alone the hook appends `-XXXXXXXX`, an FNV-1a hash of the exe's folder
(lowercase), to the name. Every other call goes to Windows unchanged.
- Copies in different folders get different semaphores.
- Two copies from the same folder still get the same one, so they still refuse each other.

**`background`.** The windows must stay behind every other window from the moment they exist.
Moving them after they appear would leave a moment in which another session's real click could hit
them. `UHCMain` runs on the game's main thread, which creates the game's windows, so the feature
installs a `WH_CBT` hook for that thread only:
- **`HCBT_CREATEWND`:** a top-level window (not a child, not message-only, not the system's IME
  windows) is created with `hwndInsertAfter = HWND_BOTTOM`. Its window procedure is wrapped through
  `SetWindowLongPtrW` (the old one is kept in a window property). The wrapper adds `SWP_NOZORDER`
  and `SWP_NOACTIVATE` to every `WM_WINDOWPOSCHANGING` and answers `WM_MOUSEACTIVATE` with
  `MA_NOACTIVATE`, so the game cannot raise its own window later.
- **`HCBT_ACTIVATE`:** refused, so the window never becomes the active or foreground window.

A window that cannot be activated gets no keyboard input. The game is driven through `perfExecFile`
and watched with `PrintWindow`, and both work without focus.

## 5. Rules that keep multiplayer deterministic

- **Same inputs, same choices** on every machine: sorted file lists, cfg order, then the stock
  unit query order. No timers, random numbers or per-machine state in simulation code.
- **Resolve names inside the game**, on the first hook call or during the data load, so every
  machine uses its identical database.
- **Never issue network commands** from code that runs on every machine, such as the setter
  behind `aiSetHCGatherPoint` (`0x82D9CB`).
- **Change only state** that the stock code at that point reads or writes anyway.
- **Time and order from the simulation** (`damageOverTime`): poisons tick on the game time
  `[world+108h]`, in integer milliseconds, in the order of their keys, from inside the world
  update. The damage itself is the stock TakeDamage.
- **Schedules on the step count** (`techPrereqRecheck`): "every N updates" is
  (`[world+F8h]` + player ID) % N, stateless, so every machine checks the same players on the same
  update.
- **Decide with the engine's own test** (`maintainWaitForPop`, `snareOnlyHitUnit`, `startingTC`,
  `civFirstTC`, `noTrainNearEnemyTC`, `buildingWorkRateAuras`): a predicate that mirrors stock
  code calls the same engine functions in the same order, with the same 32-bit or
  single-precision arithmetic, and the mirrored code is verified byte for byte.
  `noTrainNearEnemyTC` measures with the placement rule's own distance call;
  `buildingWorkRateAuras` sums with the stock modifier sum; `civFirstTC` repeats the colony test of
  the town starting units' spawn, and computes a footprint with addItem's formula in single
  precision, the same on every machine with this build.
- **Data read with the game's data** (`civFirstTC`): `<firstTC>` is read while `civs.xml` is
  parsed, on every machine; the substitution then depends only on each player's civ and the
  random map's Nomad byte, and the object def is restored after each placement.
- **Copy, don't compute** (`transformUpdatesLOS`, `liveBuildingWorkRate`, `transformInventory`): a
  value is copied or read as the stock code would, with no new float operation. The one exception
  is `transformInventory scale`: a single-precision division of two game values, the same on every
  machine with the same build.
- **Outside the simulation** (`bufferedFileReads`): change only how data reaches the game, never
  what it receives.
- **Interface only** (`abilitySlots`, `wonderPanelSkipAuras`, `customHotkeyContexts`,
  `overhealHitpointBars`, `showGatherRate`): change only what the local player sees or which keys
  work; every button or key sends the same command as stock. `showGatherRate`'s record hook runs in
  the gather code on every machine, but only copies values into the DLL's own memory.
- **Logs never feed back:** every `log` option only writes `UHC.log`; its dedupe tables decide
  whether to write a line, never what the game does.

None of this has been tested over a real network yet.

## 6. Differences from UHC 1.10

The upstream features implemented here follow the same idea and sites, with these defects
fixed:
- **noAILimit:** two uninitialized locals.
- **basePop/extraPop:** the missed negative-extra path.
- **removeFameRestriction:** the wrong owner on the second politician screen.
- **customRevolutionBanners:** an unbounded banner path.
- **Hooks:** they no longer depend on the instruction relocator.

The full list of upstream defects, including those in features not implemented yet, is in
[uhc-address-map.md](uhc-address-map.md).
