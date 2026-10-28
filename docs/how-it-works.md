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
   - `healNonIdle` gets its unit type ID from a hook in the data loader.
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

### Extra abstract unit types (used by healNonIdle)

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

## 5. Rules that keep multiplayer deterministic

- **Same inputs, same choices** on every machine: sorted file lists, cfg order, then the stock
  unit query order. No timers, random numbers or per-machine state in simulation code.
- **Resolve names inside the game**, on the first hook call or during the data load, so every
  machine uses its identical database.
- **Never issue network commands** from code that runs on every machine, such as the setter
  behind `aiSetHCGatherPoint` (`0x82D9CB`).
- **Change only state** that the stock code at that point reads or writes anyway.
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
