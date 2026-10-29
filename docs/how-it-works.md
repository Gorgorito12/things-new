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
   - `hcShipmentPointFallback` resolves proto names the first time its hook runs;
   - `healNonIdle` gets its unit type ID from a hook in the data loader;
   - `damageOverTime` records its tags while the data loads and resolves them on the first hit.
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

FUN_004C6CAE returns the unit that home city shipments arrive at. The player's home city object
is `[player+84h]`, and it stores that unit's ID at `[hc+18Ch]` (land) and `[hc+190h]` (water).

When the stored unit is gone, stock clears the ID (`0x6697FF`, on unit removal). FUN_004C6CAE
then searches fixed type lists:
- the search uses the stock unit query: `0x453618` (player), `0x45356D` (add type), `0x4532B4`
  (state), `0x453484` (run) and `0x453A36` (unit ID by index);
- each candidate must pass `vtbl+A4h`, `0x44DDB4` and `0x4802C6 != 1`.

The hook sits on the "nothing found" exit at `0x669E2E`. It runs the same query and the same
three checks for each proto named in the cfg, in order. On success it jumps to the stock
store-and-return path at `0x4C6CB2`, which writes the new ID back.

Proto names are resolved to IDs (`0x5A2346`, name → proto ID) the first time the hook runs, when
the database exists. The hook never calls `aiSetHCGatherPoint`'s setter: it issues a network
command (`0x82D9CB`), which every machine would then send.

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

### Extra abstract unit types (used by healNonIdle and dodgeAnyUnit)

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
- **Outside the simulation** (`bufferedFileReads`): change only how data reaches the game, never
  what it receives.

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
