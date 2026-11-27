# How it works

The internals of every implemented feature, for modders who want to understand them or rebuild
them in their own DLL. Addresses are virtual addresses in the stock Steam `age3y.exe`
<!-- public: (`b1a1dab7…`); they are only valid for that build. -->
(`b1a1dab7…`, see [binaries.md](binaries.md)); they are only valid for that build. The verified <!-- private -->
patch sites are in [uhc-address-map.md](uhc-address-map.md) and the engine functions and object <!-- private -->
offsets in [engine-symbols.md](engine-symbols.md). The practical steps for copying a feature <!-- private -->
into another DLL (sites to check, files, build) are in <!-- private -->
[porting-to-another-dll.md](porting-to-another-dll.md). <!-- private -->

Notation: `[x]` is the 32-bit value at address x, `NNh` is hexadecimal, `B` means bytes.

## 1. Startup

1. **The loader stub.** A UHC-patched exe starts at a 79-byte stub (VA `0xB836BE`) instead of
   the game's entry point. The stub calls `LoadLibraryA("UHC.dll")` and
   `GetProcAddress("_UHCMain@0")`, calls `UHCMain`, then jumps to the original entry point
   `0x5876AC`.
   The byte layout is in [binaries.md](binaries.md). <!-- private -->
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
   exe's folder the working directory (`UseExeFolderAsWorkingDirectory` in `src/startup.cpp`).
   The original DLL does the same. <!-- private -->
   A mod then starts the same way from a double-click, a shortcut or a launcher, and `ignoreRegistryPath`
   reads the mod folder.
5. **Configuration.** The loader patch stores the config path at `0xC65083` (at most 20 wide
   characters, default `Startup\uhc.cfg`). The DLL resolves it against the exe's folder and
   parses it (`src/config.cpp`). The parser accepts both `key value …` and the older
   `key=value` syntax with `//` comments.
   That older syntax is the original DLL's, which its patcher writes. <!-- private -->
   `ApplyFeatures` (`src/startup.cpp`) first applies `menuOptions`, which keeps, adds or removes the lines of the
   keys it names by the player's stored choice, then runs every feature in the order of `kFeatures` in
   `src/features.h`. Each returns *not configured*, *applied* or *failed*.

### Beside another DLL

The same sources also build `dinput8.dll` (`src/engineext.cpp`), for a game whose loader runs another `UHC.dll` that must stay
as it is. The exe imports `DINPUT8.dll` and Windows looks next to the exe first, so it loads with no change to any file.
Its six exports go on to the system's DLL by full path, resolved on the first call, so nothing is loaded under the loader lock.

`DllMain` checks the exe and only moves the last `jmp` of the boot stub, at 0xB836EC. So the order is: the stub runs the other
DLL's `UHCMain`, the `jmp` goes to `EngineExtMain`, which loads `engine-ext\engine-ext.cfg` and applies the keys through the same
feature loop as `UHC.dll`, and then to the game's entry point. All its files are in `engine-ext\`.

Coming second is what keeps the two apart: `VerifyAll` sees the other DLL's patches, so a key that needs one of those sites
logs `FAILED` and writes nothing.

**`preloadDll`.** A mod may load a DLL of its own through its own `dinput8.dll` proxy, which cannot sit beside this one.
After moving the `jmp`, `DllMain` reads `engine-ext\engine-ext.cfg` with the cfg parser and, for each file name of
`preloadDll`, calls `LoadLibraryW` on `<exe folder>\<name>`: the moment such a proxy loads it, before the boot stub. That
call runs under the loader lock, like the proxy's: the loaded DLL's `DllMain` must not wait for another thread. Paths,
`dinput8.dll` and `UHC.dll` are refused. The results are kept in memory and written to the log by `EngineExtMain`, once
the lock is released. So the order is: the preloaded DLL, the stub's `UHCMain`, `EngineExtMain`, the game; our keys,
coming last, verify the preloaded DLL's patches like the other DLL's.
<!-- private:begin -->
Tested with WoL's `WoL.dll` v1.33 (`wol-uhc-map.md`, "WoL.dll v1.33 with its real load order").
<!-- private:end -->

**With the stock exe, no loader at all.** The stock `age3y.exe` imports `DINPUT8.dll` too, so the same file loads there.
`DllMain` then finds the stock entry point (0x5876AC, `push 60h / push 0BEB228h`, 7 bytes, then a call) and replaces those
7 bytes with a `jmp` to a stub that runs `EngineExtMain`, executes the two pushes itself and continues at 0x5876B3. The keys
that need the loader's own files are not available this way; a key that only calls the game (`lanAutoStart`) is. Confirmed
in game 2026-11-15: host with treaty rules, Connect, and no action without the command line.

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
- **No relocation.** Nothing is copied to a trampoline. An automatic relocator can mishandle
  relative branches or decode from the middle of an instruction; writing the re-executed
  instructions by hand avoids that whole class of bugs.
  <!-- private:begin -->
  The original DLL's relocator does both (see the defects in [uhc-address-map.md](uhc-address-map.md)).
  <!-- private:end -->
- **Choosing a site:**
  - it starts on an instruction boundary;
  - no branch elsewhere in the exe targets the inside of the 5 overwritten bytes (scan all
    `rel8`/`rel32` branches);
    see [developer-guide.md](developer-guide.md) for the scan. <!-- private -->
  - you know which registers and flags are live at the continuation.
- **Registers.** Keep ESP balanced, and keep EBX, ESI, EDI and EBP unless the replaced stock
  code set them. Change EAX, ECX or EDX only when the continuation overwrites them before reading
  them; each hook's comment says which applies. Preserve the flags when code after the hook
  branches on flags set before it: `customRevolutionBanners` is entered with the result of a
  string compare in the flags.
- **Calling engine functions.** They are `thiscall`: ECX holds `this`, arguments are pushed right
  to left, and the callee pops them (`ret N`). A `bool` result is in **AL only**: test AL, not
  EAX. The upper bytes of EAX are garbage.
  Testing EAX is upstream's `asianCivs` defect. <!-- private -->
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
  load, from the abstract-unit-type hook below; `damageOverTime`, `spreadAnyAccuracy`,
  `techPrereqRecheck`, `maintainWaitForPop` and `lifespanAfterConstruction` use it to drop state
  that belongs to the old data.
- **Shared hooks.** A site that two keys need is hooked once by a shared module that calls each key's
  function in `kFeatures` order. A key adds to these and never writes a second `jmp` at their sites:
  - `worldtick.*`, `AddWorldTick`: the world update (0x481A57);
  - `actiontags.*`, `AddActionTagHandler`: the unknown tags of an action (0x5FA11E);
  - `prototags.*`, `AddProtoTagHandler`: new tags of a proto (0x51DB0F);
  - `civtags.*`, `AddCivTagHandler`: the unknown tags of a civ in `civs.xml` (0x52BB07);
  - `cardtags.*`, `AddCardTagHandler`: new child tags of a home city card (the call 0x630017);
  - `techtags.*`, `OnTechNode` and `AddTechTagHandler`: each `<Tech>` node of the tech parser (0x61FDB8);
  - `techflags.*`, `AddTechFlagHandler`: new `<Flag>` names of a tech (the flag reader's head 0x620C2F);
  - `techsubtypes.*`, `AddTechSubtype`, `AddTechActionSubtype`, `AddTechTypeSubtype`: new `Data` subtypes (the name
    lookup 0x61FF5D, the call 0x6206B2, the switches 0x8F978D and 0x8FB051), and `AddTechPlayerSubtype` (0x8D843E);
  - `modifytypes.*`, `AddModifyType`: new `<ModifyType>` names (0x5FE6D7);
  - `syscalls.*`, `AddSyscall`: extra XS syscalls, at the first registration of each syscall module;
  - `deathobservers.*`, `AddDeathObserver`: every unit's death (the drain's call 0x493D8F), with a second list,
    `AddDestroyObserver`, for the trigger `Destroy` (its call 0x9828E7 of the unit removal);
  - `killobservers.*`, `AddKillObserver`: the killing blow, with the attacker (TakeDamage's kill path 0x4D4F37);
  - `transformcalls.*`, `AddTransformObserver`: the seven calls of the in-place transform 0x9C754C (a key's own
    transform calls `TransformUnit`);
  - `garrisonobservers.*`, `AddGarrisonObserver`: each unit that enters another (the success tail 0x9C26E1 of the load
    0x9C24B5); an observer only queues, and acts after the world update;
  - `researchpay.*`, `AddResearchPayer` and `AddResearchRefundObserver`: the payment of a research (0x9E67E1,
    0x9D54CF), the copies of its cost for a refund (0x9E68A0, 0x9D5548) and the refund of a cancel (0x9E6167, 0x9D56B5);
  - `canresearch.*`, `AddCanResearchFilter`: the can-research test's head (0x4C6968);
  - `techrollover.*`, `AddTechRolloverLine`: the only exit of the tech rollover builder 0x4C737C (0x4C78F3), for the
    command, native and trade route panels;
  - `panelbuttons.*`, `AddPanelButtonFilter`: each button the command panel lays out (0x462317);
  - `rofreads.*`, `AddRofFilter`: the five reads of an attack's tactics ROF (0x48A821, 0x48A99A, 0x48EA0C, 0x48F8B5,
    0x4A1189);
  - `ghostobservers.*`, `AddGhostObserver`: the update of a building's placement ghost (0x96E4E7);
  - `unitpanel.*`, `AddUnitPanelRow` and `AddUnitPanelTail`: the unit panel's rate row (0x699456) and the selection
    panel fill's tail (0x4C8281);
  - `floatingbars.*`, `AddFloatingBarQueued` and `AddFloatingBarKind`: the HP bar queue (0x45FB6C) and its renderer
    (0x45C4B9, 0x45CB72);
  - `datarefs.*`, `AddDataRef`: new `{name}` texts for `formatText` gadgets (the registration's call 0x5D3229);
  - `menuoptions.*`, `AddMenuOption`: options of this DLL in the options menu (0x9322A1, 0x6B794B, 0x6B7676,
    0x518B26);
  - `d3d9hooks.*`, `ReplaceDirect3DCreate9` and `AddD3D9Observer`: the IAT slot 0xB84164 of `Direct3DCreate9` and the
    device's CreateDevice, Reset and Present;
  - `progresspie.*`, `AddProgressPieSource`: not a hook of its own; an observer of the panel tail that draws the
    engine's pie chart filling (a train button's overlay) over the unit portrait for the keys that give a source;
  - `income.h`, `CountIncome`: not a hook; a key that pays a player from the DLL calls it so that `incomeRates`
    counts that income too.
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
extra population is negative, and that path skips the first 5 patched bytes.
Upstream misses it. <!-- private -->

The shared-team-population path (`0x679641`) is not patched.

[decimalPopulation](#decimalpopulation) installs the same hook when neither key is set, keeping
steps 3 and 5 (`g_uhcPopStockClamps` = 1), and multiplies every limit by its scale
(`g_uhcPopScale`, 1 otherwise).

### decimalPopulation

**Stock.** `<PopulationCount>` (handler FUN_005FB8FA) and `<PopulationCapAddition>`
(FUN_005FD6E5) parse an ANSI copy of the tag's text (0x402733, WideCharToMultiByte) with
0x59A71D (`sscanf "%d"`) into `[proto+0D8h]` / `[proto+0D4h]`. A player's population
`[player+70h]` and raw cap `[player+74h]` are XOR-encoded sums of them (getPop 0x45805C, getCap
0x4581A1, which clamps the raw cap: see [basePop](#basepop-and-extrapop)); `[player+78h]` is the
population the queues reserve. Every consumer compares those sums: the Train add FUN_009EAC35
(`getPop + reserved + n × pop ≤ getCap`), the spawns FUN_009E2AC8 / FUN_009E2DEF, the command
predicate FUN_004C6968, the Maintain update, `trPlayerAtPopCap`, … (44 calls of the two getters;
all compares except the outputs below).

**The change: fixed point.** Every population quantity is stored K times larger, so the compares
stay as they are, and only the places where a population enters or leaves change.
- **Inputs:**
  - the two tag calls of 0x59A71D (0x5FB92E, 0x5FD719) go to `UhcPopCountParse` /
    `UhcPopCapAddParse` (cdecl `(const char*, int*)`, bool): strtod, × K, rounded. The `int*` is
    the handler's own argument slot (`lea eax,[esp+0Ch]`); the next slot is the proto, which the
    log reads for its name (`[proto+10h]`);
  - the proto effects (switch 0x8F978D, cases 0x8FA814 / 0x8FA8AB) call the int effect
    FUN_007F899B(rel, int* out, base, float amount, negate), cdecl, at 0x8FA835 / 0x8FA8CF; both
    calls go to wrappers. Relativity 1 (Absolute; stock truncates `amount`) gets
    `round(amount × K)`; 3 (Assign; stock `(int)(amount + 0.5)`) gets `amount × K`; 2
    (BasePercent; stock `(int)(base × amount − base + 0.5)`, truncated toward zero) is computed as
    `lround(base × amount − base)` and applied as Absolute; 0 (Percent, `× (int)(amount + 0.5)`)
    is passed through. PopulationCount's floor (`result ≤ 0 → 1`, `mov eax,1` at 0x8FA849) gets
    K in its imm32. After the change the stock code recounts the player's population
    (FUN_00A00470) or cap from the scaled values;
  - the player effect PopulationCap (FUN_008D842B case 14h, and its removal at 0x8D2099):
    `fld [esp+X] / fnstcw [esp+X]` (8 bytes at 0x8D87AB and 0x8D20AB) become `fld / fimul K /
    frndint / fnstcw`, so the truncating `fistp` that follows gets an exact integer.
    PopulationCapBonus (56h) and PopulationCapExtra (57h) store `[player+4F4h]` / `[player+4F8h]`
    in whole population, scaled where getCap reads them;
  - getCap's limits: the cap hook of [basePop](#basepop-and-extrapop) multiplies base + extra,
    the bonus and, when decimalPopulation installs it alone (`g_uhcPopStockClamps` = 1), the
    world's `[world+31Ch]` + extra and the 250 by `g_uhcPopScale`. The shared-team path
    (0x679694..0x6796B7) gets the same for its 200 and `[world+31Ch]`. The game-start bonus
    (0xA0D2D1: `setCap(getCap() + [player+7Ch] + [world+320h])`) gets K for the two bonuses;
  - the XS setters (below) multiply their value.
- **Outputs:**
  - **XS:** the registration `push impl / push name` of 19 syscalls (sites `Xs*`) gets a
    wrapper's address. The wrappers are cdecl and read two arguments in place (no declared
    parameters, so the compiler never reuses a slot the caller did not push), call the stock impl
    with them, and divide (getters: rounded half away from zero; `kbGetPopSlots` up;
    `kbUnitPickGet*` keep negatives) or multiply the value (setters: `aiSetEconomyPop`,
    `aiSetMilitaryPop` → `[ai+24h]` / `[ai+28h]`, `kbUnitPickSet*Pop` → `[pick+78h]` /
    `[pick+7Ch]`; negatives kept, the picks' default is −1). C++ callers of the same impls are
    untouched: they work on scaled values;
  - **data refs:** pop (22h), popcap (23h), futurepop (24h) and totalpop (25h) are registered as
    ints (type 2). Their registration's `mov eax,[esp+1Ch]` (the type) becomes `push 3 / pop eax
    / nop` (text), and their provider imm32 a stdcall wrapper that calls the stock provider with
    an int Value `{2, 0}` and assigns the formatted number (0x443BB8);
  - **colorizePop** (6Ch, 0x6F5736): its argument parse 0x6F2A1D (strtok `()`, atoi of the second
    token) becomes `UhcColorizePopArg(BString*)`: the number after the first `(`, × K; its
    `"%s%d%s"` call (0x6F580C) prints the number with its decimals;
  - **printed populations:** the calls of the BString sprintf 0x444EFB that print one (0x63F98D,
    0x70FF3A: str 11725 with `[proto+0D8h]`; 0x63FEC5, 0x70F58F, 0x710651: `{colorizePop(%d)}`;
    0x6F2DB5: `%d %s = %d`; 0x6F2E34: str 18963 with getCap) go to `PopFormat<i>`, which replaces
    the i-th conversion of the format with `%s` and passes the text (`12`, `12.5`, up to three
    decimals) in the same 4-byte slot.

**Why it is safe.**
- Integer data is unchanged in meaning: every value is a multiple of K and every compare is
  between scaled values. Any consumer not listed reads a relative quantity (checked for the 44
  getter calls).
  The sites are in `src/features/decimalpop.cpp`.
- The parse wrappers keep the stock contract: same arguments, bool in AL, the out int written on
  success. The effect wrappers call the stock function with its five arguments. The PopulationCap
  hooks leave the x87 stack as stock does (one value, then the stock `fistp`), and the control
  word is set by the stock `fnstcw / fldcw` right after; `frndint` rounds with the game's mode,
  round to nearest.
- The cap hook keeps every stock clamp when decimalPopulation runs without basePop/extraPop; with
  them, their semantics, in whole population. `g_uhcPopScale` is 1 otherwise, so basePop/extraPop
  alone behave as before (tested: 6 / 300).
- The text refs are used only as text by the stock UI (`formatText`); the int evaluator
  now refuses them, which no UI asks for.
  WoL's UI uses them only as text too. <!-- private -->
- The format wrappers pass the arguments in the same slots (all 4 bytes), so a format whose
  conversion is missing (a translation) is printed by the stock call unchanged.
- **Not covered** (scaled values shown as they are): the post-game timeline's population curves
  (seen in game: 9 population drawn at 90) and the AI's debug text (0x7167EB). Saved games store
  the scaled values.

### noAILimit

FUN_00603AB7 builds, at `0x603B0B..0x603C4E`, a table of 11 (or 14 with TAD content)
personality names on the stack, storing its count at `[esp+40h]` and its address at
`[esp+50h]`. The game then loads `AI3\<name>.personality` for each entry.

At startup the DLL lists the folder, then sorts the names case-insensitively so every machine
gets the same order. The folder `L"AI3\"` (`0xBE3A98`) and the extension `L".personality"`
(`0xC0B39C`) are read from the exe.

The hook replaces the whole range. It stores the DLL's count and table, and also performs two
initializations that the range contained: `[esp+24h]` = 0 (the loaded-personality counter, used
as an array index) and `[esp+1Bh]` = 0 (the function's return flag).
Upstream skips both. <!-- private -->

### noAILimitV2

The same list as `noAILimit`, installed at `0x603C34..0x603C4E` instead: the TAD-flag test
(`test al,al / je 658900h`), the 14-entry address (`lea eax,[esp+0BCh]`) and the stores of the
count (14 at `[esp+40h]`) and the table (`[esp+50h]`). The stock range before it runs unchanged,
so both initializations above happen in stock code. The stack is the same as at `0x603C4F` (the
`push 2` at `0x603B42` is popped by `add esp,8` at `0x603C31`). The hook stores the count and
table and jumps to `0x603C4F` (`xor eax,eax`); EAX is the only register the replaced range sets,
and the continuation clears it.

<!-- private:begin -->
Wars of Liberty's DLL patches the same 27 bytes with `lea eax,[esp+40h] / lea edx,[esp+50h] /
push eax / push edx / call <its DLL>` and NOPs (its memory diff, `wol-memdiff.txt`); a hardware
breakpoint at `0x603C4F` read the same 52 names in the same order with its DLL and with ours.
<!-- private:end -->

### customAbstractTypes

A thin reader over `unittypes.*`: it parses the `<AbstractType>` elements of the file (tag
names in any case, comments skipped, names limited to letters, digits and `_`, duplicates
dropped) and calls `RequestAbstractUnitType` for each name, in file order. It is the first entry
of `kFeatures`, so these names get the first IDs after the stock list on every database load;
the hook at the end of FUN_0051A5DC (`0x51BA31`) registers them before the per-proto bitsets are
sized, so `<UnitType>` entries, tech targets and XS `cUnitType<Name>` constants see them. The IDs
live in a `std::deque`, which never moves an element (the registration keeps a pointer to each).

### rofFix, stunMovingTargetFix, noDamageOnUnbuiltFoundations and fallenHeroTacticsFix

- **rofFix:** FUN_009CEB5C (an ability or command order on a unit) stores 0 to the unit AI's
  `[+B8h]` at `0x9CECB4` (10 B) before issuing the order; the key turns that store into NOPs.
- **stunMovingTargetFix:** in BUnitStunAction's update, state 8 calls the unit's `[vtbl+CCh]`
  (a target check) and `jne 9E90F9h` (`0x9E909E`) skips `setState(0Ah)` only when it passes; the
  key makes it `jmp`.
- **noDamageOnUnbuiltFoundations:** the damage function FUN_0049B3D9 tests the proto flag 9Ch
  (Invulnerable) at `0x49B3F3` (22 B) and leaves to `0x4CA52B` (no damage). The hook calls a C
  test: that flag, or a building (abstract index 2) whose `[[unit+68h]+8]` (construction) is at
  most 1e-6 while the attacking player's byte `[+505h]` is 0 (set by the effect at
  `0x7FB7E5..0x7FB85B`, which changes that player's diplomacy with every player through
  `0xA0410F`). Then `0x4CA52B` or the next test at `0x49B40F` (ECX = the proto).
- **fallenHeroTacticsFix:** `0x4F7389` (thiscall(ai, int tactic), `ret 4`) sets the unit AI's
  tactic `[ai+A8h]`; four places call it with 0 when the tactic is not 0 already (`0x6AAE6D`,
  `0x7D8F07`, `0x9D6BE7`, `0x9EBB0B`); the key turns each `push` + `call` into NOPs.

### gatherFix

BUnitGatherAction's update adds the elapsed time `[world+104h]` to `[action+88h]` at `0x4EC8DE`, and
`doAnimationLooped` (`0x4ECC88`, run when the gather animation loops) adds it again and collects
the animation's length (`0x4939BD`, the unit's visual `[unit+60h]`) through `collectStuff`
`0x9DD7B4` or `collectStuff_2` `0x4ECD87` (bit 22 of the action's flags `[+30h]`/`[+34h]`), then
clears `[action+88h]`. The key jumps over that block (`0x4ECC8E` → `0x4ECCE7`) and replaces the
update's addition with a C tick: add the time; past the interval `[protoAction+78h]` (0.5 s when it
is 0), collect the interval through the same function and clear the time; then the update's own
`pop ebx / pop edi` and its epilogue at `0x4EC8FE`.

### betterfreedynamicunit

A `FreeHomeCityUnit` amount below −1e-6 (`[0xB9FB60]`) is a dynamic count, `-amount ×
min([world+134h], 15)`, computed in two copies (`0x7FA6D5`, `0x8D8C6F`; the second is the tech
path, after the home city test `[player+84h]` at `0x8D8C62`). `[world+134h]` is the 2-minute step
rounded up (4 at 452 s, 5 at 491 s, in game). The hooks at `0x7FA6ED` (61 B, result in
`[esp+24h]`) and `0x8D8C88` (53 B, result in `[esp+38h]`) replace the computation with
`-amount × min([world+108h] / 120000, 15)`.

### truckAttackResourceFix

**The stock action.** A tactics action of type `TruckAttack` (action type 42h, name at 0xBD7AC4, registered at
0x522DB0) is BUnitTruckAttackAction, vtable 0xB98468. Its update (slot 3Ch, 0x9EC6D4) waits for the game time
`[action+64h]`, sets the next one 195–205 ms later (0x9EC4B0, the synced RNG stream 2) and runs the hit 0x9EC4E1:
the units within `[action+24h]` (the action's `maxrange`) of its owner `[action+10h]` (0x4A1C55), and for each one
of another player that is alive, has hit points, is not dead (0x4802C6), is built (0x44DDB4), passes 0x482865 and
0x48E237, it first resets the target's resource inventory `[[unit+0B4h]+94h]` (0x58F070 on `+4`: every resource of
the obfuscated array, `[0C6DF38h]` of them, set to 0 xor its key at 0xC6DF14), then deals the damage (0x49B3D9, or
0x499422 for a proto without abstract index 12h). The reset is what a trample of a hunt needs; on a building that
holds resources (a Mill, a plantation, a rice paddy: food or gold 999 with `UnlimitedSupply`) it leaves it at 0 for
good, and the gather action refuses an empty target. Observed in game with the inventory read from memory: a Mill
next to an enemy monster truck, or under an enemy mustard gas, went from 999 to 0.

**The hook.** At 0x9EC635 (`mov edx,[edi+0B4h]`, 6 bytes; EBP = the action, EDI = the target, EBX = 0),
`UhcTruckInventoryHook` calls `UhcTruckKeepsInventory(action, target)`: true for a proto of abstract index 2 (a
building, 0x44CAC4). Then it goes on at the damage, 0x9EC64D; otherwise it re-executes the `mov` and goes on at
0x9EC63B, the stock reset.

**Why it is safe.** EAX, ECX and EDX are written before they are read on both continuations (0x9EC63B loads EAX
and ECX; 0x9EC64D loads ECX, and its branches load EAX and EDX); EBX, ESI, EDI and EBP are kept by the stdcall
callee. The test reads only the target's proto, the same on every machine. Units are reset as in stock.

### deadReplacementAtZeroInventory

**The stock replacement.** `<DeadReplacement>` (handler 0x5FC33B) stores a proto ID at `[proto+F8h]`. The death
replacement FUN_004B4F2F places it once per unit (state bit 29h) through 0x506F61 (the placement test, the creation
0x498ACC). It has four callers: the kill handler 0x4B4F70 (0x4B527E; not for a `DeadReplacementWhenDestroyed` proto,
flag 4Ah), the two removal paths of a flag-4Ah proto (0x4E6FC6 and 0x6A4013) and the state check FUN_00482152
(0x4F1680). A unit with `DieAtZeroResources` (flag 0Eh) and `DoNotDieAtZeroHitpoints` (which clears the default flag
0Dh) is never killed at 0 HP: the state check turns it into a body (state bit 12, owner gaia, the death sound) and
calls the replacement at once, so a hunt or a herdable leaves it beside the body it has just become. When the body is
used up, the same check asks the kill queue, but the unit update marks the body for removal (state bit 7) and the
world removes it in the same update (0x495D61 → 0x4726B2), before the queue's drain: the kill handler never sees it.
Observed with hardware breakpoints on a cow emptied by settlers: the inventory test 0x4B43B0 and the kill queue ask
ran, then the removal, and no kill handler for it. The two updates that remove a unit marked so call the removal
notice FUN_00495D6B first (0x495DEE in FUN_00482F16, 0x6A3FF0 in 0x5116xx), then place the replacement of a flag-4Ah
proto.

**The hooks** (`hooks/deadrepl_hooks.asm`).
- The replacement's head 0x4B4F2F (7 bytes, `push ecx / push esi / mov esi,ecx / mov eax,[esi+68h]`, continuation
  0x4B4F36): `UhcDeadReplacementSkip(unit, return address)` is true only for the return address 0x4F1685 and a proto
  with flag 0Eh, without flag 0Dh, and a replacement; the hook then returns with nothing done (bit 29h stays clear).
- The removal notice's head 0x495D6B (5 bytes, `mov eax,[0C66234h]`, continuation 0x495D70):
  `UhcDeadReplacementOnRemove(unit)` calls FUN_004B4F2F for a body (state bit 12) of such a proto whose bit 29h is
  clear. The call goes through the first hook with a return address in the DLL, so it is stock. The replacement then
  comes at the moment and through the same code as for a `DeadReplacementWhenDestroyed` proto.

A body killed by the kill handler (a trigger's `Kill`) gets the replacement there, as in stock; bit 29h keeps it to one
either way. The trigger `Destroy` removes a unit without the notice, so a body destroyed that way leaves nothing, as a
flag-4Ah proto does in stock.

**Why it is safe.** At the head, EAX and EDX are not inputs (thiscall with no argument) and each caller reloads EAX
before reading it; ECX is pushed and restored around the stdcall callee, which keeps EBX, ESI, EDI and EBP. A skipped
call returns as the stock function does when bit 29h is set. At the notice, ECX is restored and EAX is written by the
stolen instruction. The decisions read only the unit's proto and state bits, the same on every machine. Evidence:
`rea/evidence/age3y-b1a1dab7/r1121-b-deadrepl-detonation-heal.json` (`ev_df5ab456…`, FUN_00482152), capstone over the
exe for FUN_004B4F2F, its callers, 0x506F61, 0x495D6B and 0x4B4D80.

### nowalkfarm

The gather action calls `0x9DDADE` (the spot picker that `farmingRadius` hooks) at `0x6A9067` each
time the game time passes `[action+A0h]`; the key turns that call into five NOPs. The first spot
still comes from the other callers (`0x4ED5E8`, `0x4ED6F4`, `0x50DF53`, `0x6A8E7C`).

### repairWallGlobal

A UI syscall through the registry (`src/syscalls.*`): for each unit in the world table of the local
player (`[game+3C0h]`) whose proto has abstract index 36h (`AbstractWall`, bit 54), it calls
`BGame::commandAutoRepair` `0x830AC4(game, player, unitId)`, the call the single-wall repair makes
at `0x7DEDC3`.

### compatMode

FUN_0054D663 adds each adapter display mode (16 B: width, height, ..., Direct3D format at `+0Ch`)
with `0x54D605` at `0x54D6D1`. The key redirects that call to a wrapper that also adds an
X8R8G8B8 (16h) mode as R5G6B5 (17h); `0x545A10` maps the formats to bit depths.

### modelCacheLimit

The game keeps the Granny files of its models in a cache with a budget of 30,000,000 bytes. FUN_0041CA8F, called
every frame at `0x4056EA` on `[0C66240h]+60A0h` (the model manager), runs when `[mgr+60F9h]` is set: while the
loaded bytes `[mgr+306Ch]` are above the budget (`cmp dword [esi+306Ch],1C9C380h` at `0x46C03D`, then `ja`) and the
least-recently-used list `[mgr+304Ch]` is not empty, it unloads the list's tail `[mgr+3068h]` through FUN_00AD9FD8
→ FUN_0046C210, which calls `GrannyFreeFile` (`0x588B30`), and compares again at `0x6E0174` (`jbe` out). Those two
are the only compares with the budget in the exe.

**The bug:** an unloaded model can still be in use. A visual keeps its Granny model instance (`[visual+24h]`) made
from the freed file; the next draw finds the cache entry empty and loads the file again (FUN_00405C49 with load = 1)
into new memory, but the instance still points into the old one. The draw then reads freed memory:
`GrannyGetSourceSkeleton` returns 0 or garbage at `0x40C07C` and `0x40CC7B`, or the animation lookup at `0x4B6F1F`
falls inside `granny2.dll`. Stock data rarely goes over the budget; a mod with much more art is over it all game.
<!-- private:begin -->
In WoL's 6-player "NEW" Levant, 584 unloads in 9.4 minutes, and 4 crashes in 7 click sweeps (#78,
`wol-fixes/maps/levant-clicks-20261122.txt`).
<!-- private:end -->

**The key** rewrites the imm32 of both compares (`0x46C043` and `0x6E017A`) after `VerifyAll`: `MB × 1,000,000`,
or `0FFFFFFFFh` for 0 / no number, which the unsigned compares never exceed, so the loop never unloads. No hook.
With `log`, a world tick reads `[[0C66240h]+910Ch]` and logs each new 50 MB step of the loaded bytes.

**Why it is safe:** only the budget changes; the unload path, the loader and the least-recently-used list run as
before. Models are then freed only by the other callers of FUN_0046C210: traced with the key on, the loader's
reload (`0x46D80D`) during play and FUN_00589000 (`0x589003`) when the game closes. The cost is memory: every model
drawn in a session stays loaded (in 13-minute click sweeps of a large mod, 90-120 MB of models instead of 30).

**Not covered: the part declaration's reload.** FUN_004F0187 reads a damage template's part; when its bone name is
not yet in the global bone name table `0D6F478h` (lookup `0x58E506` at `0x4F0217`), it adds the name (`0x59C213`,
`bl` = 1); when the model then has no bone of that id (`0x4F010C`), it writes "Invalid bone name ... in part
declaration for model ..." and, with `bl` set, calls the loader on the loaded model (`0x658C35`), which frees the
file under the units that draw it: the same fault, once per bone name new to the session. The names come from
`<definebone>` lines of the anim files, so it is a data error: a part bone that the anim file does not define, or
that the model lacks. aoe3-blender-tools' `tools/dmg_bones.py` lists such templates; [dmgPartBoneFix](#dmgpartbonefix)
removes the reload.

### dmgPartBoneFix

**The path (FUN_004F0187, a damage template's `<part>`):** the bone attribute is looked up in the global bone name
table `0D6F478h` (`0x58E506` at `0x4F0217`); a name not there yet is added (`0x59C213` at `0x658B6A`, `bl` = 1).
The model's own map from those ids to its skeleton (`0x4F010C` → `[model+10h]`, `0x484329`) is built when the model
is loaded, so a model loaded before its bone names were in the table has no entry for them: `0x4F0240` (`jle
658BA4h`) writes "Invalid bone name \"%s\" in part declaration for model \"%s\"" (`0xC0B878`). Then, only when `bl`
is set (`0x658C18`: `test bl,bl / je 658C3Ah`), it calls the loader FUN_0046D7C3 on the loaded cache entry
(`0x658C35`); the loader's branch for a loaded entry (`0x46E7ED`) unloads the Granny file (FUN_00AD5DCF) and loads it
again, so the new map has the name. Units that draw the model keep instances of the freed file, and the next draw can
crash (`granny2.dll+0x2C8CD`). Either way the code continues at `0x658C3A` → `0x4F0246` and keeps the part with its
bone id. With `bl` clear (the name was already in the table, e.g. the second model that meets it) there is no reload:
the part stays, and in that model it matches no bone. REA `ev_5cd8bb32…` (FUN_004F0187), `ev_82ec70b4…` (FUN_0046D7C3);
capstone for `0x658B2F..0x658C9D`.

**The key** makes every case take the `bl` = 0 path: `je 658C3Ah` (`74 1E` at `0x658C1A`) becomes `jmp` (`EB 1E`),
after `VerifyAll` of the 34 bytes `0x658C18..0x658C39` (the test, the jump, the reload call). With `log`, a 5-byte
`jmp` at `0x658C18` goes to `UhcPartBoneReloadHook` (`dmgpartbone_hooks.asm`), which, when `bl` is set, logs the bone
(`[[esp+44h]+4]`) and the model (`[edi+4]`) and leaves through `jmp 658C3Ah`.

**Why it is safe:** the instructions skipped are the reload and its argument setup (`ebx` is reloaded at `0x4F0246`,
`ebp` cleared there); what follows is the stock path the game already takes for every `bl` = 0 case. Only the
model's bone map is not rebuilt, so that part has no bone in that model until the model is loaded again (with
[modelCacheLimit](#modelcachelimit) 0, not during the game): a debris piece or a falling-tree part is missing, the
rest of the damage and destruction is unchanged. The other caller of `0x59C213` in this area (`0x658D70`, from
FUN_004F0540's bone lookup) does not reload. Traced (2026-11-23, `tools/re/trace_frees.py --parts`): with the key
the same invalid parts are met and no model is unloaded or reloaded for them; every other unload is the same.
Simulation: none expected (inferred, not traced): a model's bone map is drawing state, and which models are loaded,
and in which order the bone names are met, already differs between players.

### multiarmor

A proto's armor is the damage type byte `[proto+1D3h]` and the value `[proto+C4h]`; the `<Armor>`
handler `0x5F5E62` (cdecl `(ctx, node, proto)`, the type name through `0x5F562D` on `ctx`, whose
damage type list is `[ctx+44h]`/`[+48h]`) writes both at `0x5F5EB7`, and the getter `0x49B323`
(`unit`, damage type byte) returns the value only for that type (then adds the tactic armor). The
Data effect subtype Armor is 5Ch: `applyData` (`0x8F973F`) case `0x8FAE52` and `unapplyData`
(`0x8FB01C`) case `0x8FC144` call `0x7F892A(relativity, &target[C4h], base[C4h], amount, unapply)`.

The key keeps a table per proto pointer (damage type → value, up to 8):

| Site | What it does |
|---|---|
| `0x5F5EB7` (12 B) | records each `<Armor>` (and the parse context), then the stock stores |
| `0x49B32F` (22 B) | `UhcArmorFor(proto, type)`: `[C4h]` for the stock type, else the table's value or 0 |
| `0x67E011` head (8 B) | the proto copy (per-player clone): copies the table |
| `0x58633D` head (9 B) | the proto destructor: drops the table |
| vtable `0xB9E5AC` | `BDataEffect::setData` wrapper: reads `damagetype` (`0x598F37`, `0x402733`, `0x5F55EA`) and keeps it per effect |
| vtable `0xB9E5C4`, `C8`, `CC`, `D0` | `playerApply` / `playerUnapply` / `protoUnitApply` / `protoUnitUnapply` wrappers: make the effect's damage type current during the stock call |
| `0x8FAE52`, `0x8FC144` (10 B each) | the Armor cases: for a current type other than the target's stock type, apply `0x7F892A` to the table entry (base value from the base proto) and skip the stock change |

Techs reach `applyData` through `protoUnitApply` (`0x7F86C0`, a ProtoUnit target) or `playerApply` → `0x8D842B`
(a Player target), without the effect pointer, so the type travels in a global that the wrappers set and restore
(effects apply on one thread). (Corrected 2026-11-27: this said `playerApply` for every tech; a trace shows the
ProtoUnit path, see [perCivEffects](#perciveffects).)

### customProtoUnitCommands

`FUN_0052277E` builds the database's name tables. The command types are 129 calls of
`0x537683(db, id, name)` (thiscall, `ret 8`), from `MarketBuy1` (0) to `RansomExplorerAsian`
(80h, the call at `0x5269FB`); that function appends to the hashed name list `[db+2648h]` only
when `id` equals its count `[db+264Ch]`. Every reader goes through that list: the lookup
`0x5274AB(db, name)` (-1 if absent) for `protounitcommands.xml`, the protos' `<Command>` tags
(`0x5F60AB`, stored as 6-byte entries `{word id, byte kind 2, byte page, byte column, ...}` in
`[proto+E8h]`, count `[+ECh]`) and the UI, or the count (`0x97EFFE`).

The `protounitcommands.xml` loader (`FUN_00527090`) keeps one 4Ch-byte record per command type ID
in `[db+2968h]`, sized at `0x52711D` with a constant (`push 82h / mov ecx,ebx / call 5276EAh`), and
fills `record[id]` with no bound check; readers stop at that array's count `[+4]`. The key:

- redirects the call at `0x5269FB` to a wrapper that makes it, then registers each listed name
  not already known with the next ID (`[db+264Ch]`);
- writes `82h + N` (N listed names) into that `push`, so the records of the new IDs exist.

### customSyscalls

**The registry** (`src/syscalls.*`). Each syscall module (AI, HC, KB, RM, TR, UI, UI2, XS) is
built by one function that registers its stock syscalls in sequence; the hook sits on the first
one, where ESI is the module, and replaces its pushes (`push 1 / push <fn>`, 7 B; the UI
module's `push 1` comes before its site, so 5 B there). Inside `pushfd/pushad`, it calls
`UhcRegisterSyscallGroup(group, module)`, then re-executes the pushes and jumps to the
`push <name>` that follows. For each queued syscall of the group: register (`0x624F52`, thiscall
`(name, fn, retType)`), one setter per parameter (`0x62505B` int, `0x625079` float, `0x62506A`
bool, `0x624E3F` string, `0x62734A` vector), the comment (`0x624E56`) and end (`0x6250B0`).

**Why a failure skips only one syscall:** `0x624F52` refuses a name the module already has
(`0x624ED8`) or a bad type before it allocates the pending entry `[module+18h]`, so nothing is
pending after a refusal; a later failure leaves a pending entry, which `0xA44C0B` frees (it
tests `[module+18h]` for null first), as the stock error paths do. The next registration then
starts clean. Upstream stops the whole group at the first refusal. <!-- private -->

**The loader** (`features/plugins.cpp`). Each listed file or pattern is resolved against the exe
folder and loaded by full path (`LoadLibraryExW`, `LOAD_WITH_ALTERED_SEARCH_PATH`).
`UHCPluginMain` is called with a static `UHCPluginInfo` (plugins may keep the pointer: some
store it for their cheats) inside `__try/__except`. The call is cdecl: the plugins checked
end `UHCPluginMain` with a plain `ret`, and call the table's functions with the caller cleaning
the stack (`add esp,…` after each call). `RegisterSyscall` returns a pointer into the registry's
`std::deque` (stable), or to a dummy entry for a refused call, so a plugin that passes the result
to `SyscallSetParam` without checking cannot crash; defaults are copied when `SyscallSetParam`
is called. `CheatAddResource` forwards to the thiscall `0x49A98A`; `CheatSpawnUnit` is the
engine function `0x7B4F03` itself. Plugins load last in `kFeatures`, after every other hook.

### customCheats

FUN_005515F1 builds the cheat table `0xD65600` (`{entries, count, capacity}`, 16-byte entries
`{id, enabled, BString text, fn}`) for each game: 23 stock entries, each text an encrypted
literal. The chat check (FUN_00513FA7) narrows the typed text (`0x402733`), encrypts it with
`0x513F73` (`void cdecl(const char* text, char* out, int size)`) and compares it with each entry's
text; a match sends the entry's index as a game command (`0x7B4E63`, type 2Ch), which calls the
entry's function with the player data on every machine. The hook replaces the build's epilogue
(`pop edi/esi/ebx; add esp,10h` at `0x551FE6`), and `UhcAppendCheats` appends one entry per plugin
cheat: the text encrypted with `0x513F73` itself (so no cipher table is copied), widened byte by
byte into a BString (`0x401A12`), the table grown with `0x5ACE63`, the text assigned (`0x40196F`),
the temporary destroyed (`0x4010CA`), ID 24 + k (after the stock IDs, as other DLLs for this loader number
them), then the epilogue runs and the hook jumps to the `ret` at `0x551FEC`.

### asianCivs

The game caches civ IDs by name in globals `0xC6FB48..0xC6FB8C` (FUN_008D0318). Three functions
compare a player's first civ (`[[player+20h]]`, or −1) with them; each hook replaces the last
compare with `[0C6FB88h]` and its branch, re-executes the compare, and otherwise calls
`UhcIsListedAsianCiv(civ)` with ECX and EDX saved:
- `0x454F1D` in isAsianCiv `0x454ED7` (`bool thiscall(player, bool extended)`; the site is only
  reached with `extended` set): true continues at `0x454F2A` (`mov al,1`), false at `0x454F25`.
- `0x8D6AC4` in FUN_008D6A7D: true at `0x8D6ACC` (it tests EDX, the civ count, and reloads EAX),
  false at `0x8D6B0C`.
- `0x818284` in the wonder age-up list FUN_0081807A, after `push 1 / mov ecx,ebp`: the hook calls
  `0x49A2D8` itself (is Indian, `ret 4`) and tests AL; an Indian player continues at `0x81828D`
  (the stock "Indians" compare). For any other player, inside `pushad`,
  `UhcAsianWonderOption(player = EBP, &option civ name = [esi+18Ch]+edi+8)` compares the
  option's civ name BString with the cfg name of the player's civ through `0x443C10` (flag 0,
  case ignored): a match adds the option (`0x8182A9`), anything else skips it (`0x8182EB`).

Names resolve through `CivIdList` (`src/namelists.*`), with `0x58E71F` (civ ID by name), on the
first call after `civs.xml` is read and again when the database pointer or `[database+28h]`
changes, so no hook on the caching functions FUN_008D0318 and FUN_008DABA3 is needed.

### selectionLimit

The 50-unit cap is the immediate of `mov eax,32h` at eight places: the getter `0x4E0BEE`
(`mov eax,32h / ret`) and seven compares of a selection list's count (`[list+24h]`, a growable
array) with it before a unit is added (`0x4E0F5F`, `0x4E0F7E`, `0x4E10A5`, `0x4FC457`, `0x4FE663`,
`0x4FEB94`, `0x503DCE`). The DLL rewrites each imm32 after `VerifyAll`; there is no hook. No
fixed-size buffer was found next to these compares. <!-- private -->Wars of Liberty's DLL patches the same eight bytes to 75 (its memory diff), so 75 is proven by its players.

### enableAllTeams

FUN_007A0628 fills the single-player team list as pairs: a string loaded with `0x58EA52` into a
temporary BString at `[esp+10h]`, copied (`0x40196F`) into a BString array at `[esp+14h]` grown by
one (`0x4676E7`), the temporary destroyed (`0x4010CA`), and a team value appended to an int array
at `[esp+20h]` (`0x401113`): `8D2Dh` → 0, `8D2Eh` → 1, then `8D31h` ("?") → −1. The hook replaces
`push 8D31h` at `0x7A0709`; inside `pushfd/pushad` it adds `8D2Fh` → 2 and `8D30h` → 3 in the same
steps (`UhcAddTeamEntries`, given ESP at the site), then re-executes the push and continues at
`0x7A070E`. The site `TeamDropdownBlock` (the Team 2 entry, verify only) pins the frame offsets.
The multiplayer slot (a method of another class, FUN_00776702, reached through a vtable) maps
the list index to a team itself and is not changed.

### twoScoutCivs

Four tests in the hero interface read a civ (`[esi+1DCh]`, or the value at `[esp+10h]`) and ask
`0x8D0318` (which caches the civ IDs by name and tells whether the civ is Asian) and whether it is
the Chinese: Asian and not Chinese means two heroes (Japanese, Indians). Each hook replaces one
instruction (6 B), asks `UhcIsTwoScoutCiv`, and for a listed civ takes the two-hero branch:
`0x77EBB2` sets BL = 1 and the frame flags `[esp+0Fh]` = 1, `[esp+0Eh]` = 0 as the stock code
would, then `0x77EBF6`; `0x77EF29` (after `push ebx`) jumps to `0x77EF68` (`push 1`); `0x77DDD2`
to `0x77DE16`; `0x77DFF4` to `0x77E039`. Otherwise each re-executes its instruction (the second
reloads the civ from `[esp+14h]`, pushes it and calls `0x8D0318`) and continues.

### marketUnits

The market trade function checks, before a purchase or sale, that the player owns a `Market`
(`[db+5E30h]`) or the second market type (`[db+5E60h]`): `0x4C846D` (`int thiscall(kb, player,
proto, 2, 0)`, a unit count) with ECX = the player's kb `[esi+80h]` and the player ID at
`[esp+10h]`. The hook replaces `mov edx,[0C66234h]` at `0x7DEF70`; `UhcHasMarketUnit(kb, player)`
counts each listed proto the same way, and any count above 0 continues at `0x7DEFC3` (trade);
otherwise the instruction is re-executed and the stock tests run (`0x7DEF76`). Names resolve
through `ProtoIdList` (`src/namelists.*`, with `0x5A2346`), again when the database or
`[db+58h]` changes.

### explorerUnits

**Names.** FUN_004702DC builds a unit's display name. At `0x6A012A` (`lea ecx,[eax+18h] / call
401F47h`, EAX = the home city, `[ebp+8]` = the proto ID, ESI = the database) the hook asks
`UhcExplorerType(proto)`: -1 re-executes both instructions and continues at `0x6A0132`; Type 1
jumps to `0x6A0179` (the home city's explorer name, `[hc+18h]`), Type 0 to `0x6A0203` (the path for
other units), any other Type to `0x6A01B8` (`push 0`: the first hero name, `0x853954`).

**Knockout message.** At `0x50B01F` (`mov edx,[esi+10h] / mov eax,[edx+5Ch]`: the unit, then its
proto, whose ID is `[proto+4]`) the hook re-executes both loads and asks `UhcExplorerString`; a
listed proto's string ID is pushed and the code continues at `0x50B039`, where the stock Explorer
case loads its pushed string (`0x447719`); otherwise it continues at `0x50B025`.

### nativeCivs

- **Civ flag.** At the end of the `civs.xml` loader (`0x52B581`, `lea ecx,[esp+100h]`), stock has
  just set `[civ+10h] = EBX` for the Iroquois, Sioux and Aztecs (civ object by name `0x52D6FF`);
  the hook does the same for each listed name, then re-executes the `lea`.
- **Tests.** `0x51271F` (FUN_00512651, `bool cdecl(civ)`), `0x453D5E` (isNativeCiv's `extended`
  branch; the hook compares the byte argument as a byte), `0x67B0A5` and `0x8D52AF` re-execute their
  stock compare with the cached native civ ID and otherwise ask `UhcIsNativeCiv`; a listed civ
  takes the native branch.
- **Dances.** The three dance readers that compare the native civ IDs (`0x4904B5`, `0x4ECD6B`,
  `0x8D47C9`) are the functions `danceBonusCivs` gates at their first compare; `nativeCivs` adds
  its names to that key's list through `AddDanceCivs` (installing the gates if `danceBonusCivs`
  is not set), so the XPTrickle dance (`0x4E0DFF`) is covered too.
- **Council.** In FUN_0081ABFC, at `0x81ADEB` (`cmp [esp+10h],ebx / mov [esp+20h],eax`), the
  hook stores EAX, asks `UhcNativeCouncilOption(civ = [esp+10h], option civ name = [esi+18Ch]+edi+8)`
  (`0x443C10`, case ignored): a match adds the option (`0x81AE59`); otherwise EAX is restored, the
  compare re-executed, and the code continues at `0x81ADF3` with its flags.

### bigButtonCivs and noBigButtonBlds

In FUN_0046188E, `jne 695955h` at `0x461BD8` follows `isNativeCiv(player, true)`: a native player
goes to `0x695955`, which shows the big button on a unit of abstract type 2; others go to
`0x461BDE` (none). The hook passes AL, the player (EDI) and the unit (ESI) to `UhcBigButtonPath`:
neither native nor listed means none; a unit whose proto (`[[unit+5Ch]+8]`) is in
`noBigButtonBlds` means none; anything else takes the native path.

### enableFarmAnim, enableRectFarmAnim and farmingRadius

The gather code compares a target's proto ID with cached IDs in chains: Mill `[db+5E58h]`, Farm
`[db+5E5Ch]`, Plantation `[db+5E60h]`, Rice Paddy `[db+607Ch]` and others, each `je` going to the
branch for that kind. A null proto goes to a cold stub (`or eax,-1`) that jumps back **to the
compare**, so the compares themselves cannot be hooked; the sites are before or after them:

| Site | Replaced | Listed Mill-like | Listed Rice Paddy-like |
|---|---|---|---|
| 1 `0x4EDA85` | `mov edx,[ebp+140h]` | `0x4E3069` with EDX = db, EBX = Mill ID, ECX = ESI, EAX = proto | `0x6A8A55`, EBX = Rice Paddy ID |
| 2 `0x50DE33` | `jne 4EDD6Ch` | `0x6A8E67` (the equal path) | `0x50DF51`, EBX = Rice Paddy ID, ECX = EDI, EDX = game |
| 3 `0x73D41A` | `jne 73D427h; mov eax,[eax+5F4Ch]` | `0x73D49B` (both kinds) | same |
| 4 `0x8CEC9F` | `call 4E2C50h` | `0x8CED20` (both kinds) | same |
| 5 `0x9DDB79` | `cmp ecx,[eax+5E58h]` | the compare made equal (`cmp eax,eax`), so `sete dl` sets the Mill flag | — |
| 6 `0x4EE07F`, 7 `0x4EE2FE` | `je 586DFFh` / `je 586E11h` | the `je` target | — |
| 8 `0x6A8FE1` | `call 44CB0Ah; cmp eax,ebx; jne 6A900Ch` | `0x6A8FEA` | — |
| R1 `0x9DDD80` | four loads, `cmp ecx,[eax+607Ch]` | — | `0x9DDD9E` (the equal path) |
| R2 `0x4741F0` | `je 4743DDh` (after `test esi,esi`) | — | `0x689BBE` with `[esp+14h]` = `[ebx+18h]`, EBP = Rice Paddy ID, ECX = EBX, EAX = proto |
| R3 `0x4EEDB4`, R4 `0x4EEE9E` | `mov ecx,[0C66234h]` | — | `0x4EEE18` / `0x4ED756`, EDX = db, EBP = Rice Paddy ID, ECX = EDI |

The registers listed are the ones stock has on its own branch for a Mill or a Rice Paddy (traced
from each chain's `je`), so the code after sees what it would see for those buildings. Every other
proto re-executes the replaced instructions. `UhcFarmKind` answers 1, 2 or 0 through
`ProtoIdList` (`src/namelists.*`).

**farmingRadius.** At `0x9DE04D` (`mov ecx,[0C0BBE0h]`, the stock 4.5) the gather action draws the
gatherer's offset twice with the synced random 0x422648 (stream 2, from EBP to X, then to Z, pushed
at `0x9DE06B` from EDX). For a farm proto with a radius (`[[edi+5Ch]+4]`), the hook makes the
first draw with its X, stores it at `[esp+14h]` like stock, loads Z into EDX and continues at
`0x9DE06B`; EAX, ECX and EDX are free there (the draws overwrite them).

### trainSingleAbstractType

The unit-creation function `0x9CE2BE` (thiscall on the unit manager, seven arguments; reached from
the Train action at `0x9EBF03` and from three other callers) tests the new unit's proto with
`0x44CAC4` for abstract types 16h, 1, the TownCenter proto, 5Ch and 5Dh (`AbstractMonk`); any of
them clears BL, which makes the count 1 (`mov edi,1`) instead of the requested count. The key
redirects the two 5Dh calls (`0x9CE573`, `0x9CE767`) to a wrapper that returns the stock answer or
the marker type. `0x44CAC4` takes a **bit index** in the proto's abstract-type bitset
`[proto+30h]`: the unittype ID minus the proto count `[database+19B0h]`, computed at each call.
(A first build passed the unittype ID; the bound check at `0x44CADE` then always failed.)

### wonderCivUnitType

Two functions decide whether a selected unit may start the age-up: FUN_007E686E (from the age-up
command) and FUN_007E7A50. For a civ for which isAsianCiv (`0x454ED7`, extended) is true they test
the unit's proto with `0x44CAC4` for abstract type 16h (`push 16h / mov ecx,proto / call
44CAC4h` at `0x7E6919` and `0x7E8050`); for other civs they require the TownCenter proto. The key
redirects those two calls to a wrapper that returns the stock answer or whether the proto ID
(`[proto+4]`) is listed (`ProtoIdList`).

### ageUpBuildings

**The pickers.** The age-up button's command is `uiPoliticianUI(%d, %d, %s)` (string 0xC31A78, built
for a tech with flag 4 `AgeUpgrade` or 1Ch `RevoltTech` on any unit), the syscall 0x7E686E; the hotkey
path is `uiPoliticianUIInSelected` 0x7E7EC1, which walks the selection. Both hold the tests
[wonderCivUnitType](#wondercivunittype) widens: after isAsianCiv(player,
true) they test the proto against abstract type 16h for an Asian civ, else compare the TownCenter ID
`[db+5E08h]` with the player's proto `[proto+4]`, and leave on a failure. The key replaces only that compare
(0x7E6905, 16 bytes: `mov eax,[edi+5E08h] / cmp eax,[esi+4] / je / jmp`; 0x7E803F, 13 bytes:
`mov edx,[ecx+5E08h] / cmp edx,[edi+4] / je / jmp`): the hook re-executes it and, when it fails, asks
`UhcAgeUpListed(proto)`, then jumps to the stock accepted continuation (0x7E6926, 0x7E8059) or the
rejected one (0x7E6A2E, 0x7E8092). The Asian path and its call (0x7E6919, 0x7E8050), which
wonderCivUnitType redirects, are not touched, so the two keys apply in any order.

**The list.** The dialog (European: FUN_0081A2B8; FUN_00818EE5 is its twin) walks the player's tech
statuses and keeps each one of the next age (0x94C7E3) that `0x4C6968(status, unit)` accepts, up to five
(`[dlg+26Ch]`). 0x4C6968 checks the tech's flags, status and prerequisites and some of the unit's proto
flags (REA `ev_90be3ff9…`), not whether the proto lists the tech: stock, a Market would offer every
politician. The key redirects the two calls (0x81A44D, 0x819052) to `CanResearchHere`, which keeps the
stock answer and, when the unit's proto (`[unit+5Ch]`) is listed, also requires that the proto's command
list (`[proto+E8h]`, 6-byte entries `{word id, byte kind}`, kind 1 a tech, count `[proto+ECh]`) holds the
tech (`[[status]]`). The Town Center, unlisted, keeps the stock list. The dialog keeps the unit ID
(`[dlg+140h]`, set by 0x818E8D) and researches the choice there.

**Why it is safe.**
- Registers: at 0x7E6905 ESI is the player's proto (tested non-null at 0x7E68F0) and EDI the database; at
  0x7E803F ECX is the database and EDI the proto. EAX, ECX and EDX are dead at both continuations of each
  site (0x7E6926 loads ECX from 0xC67310 and EDX, EAX after it; 0x7E8059 loads ECX; the rejected paths
  only pop). `UhcAgeUpListed` is stdcall and keeps EBX, ESI, EDI and EBP; the flags are not live.
- Branches into the sites: only 0x7E6903 → 0x7E6915 and 0x7E8032 → 0x7E804C, both outside the replaced
  bytes (capstone scan of `.text`).
- The list wrapper has the frame of the stock call (thiscall, one argument, `ret 4`) as `__fastcall` with an
  unused EDX, and only reads.
- Not for the Asian civs: their dialog is the wonder list, and a building cannot place a wonder.
- Interface only: the pickers and the list run on the local player's clicks; the research the dialog sends is
  a normal research command, so every machine runs the same thing. Not on a hot path (a click, a dialog).

### politicianPlacesFix

**The dialog in the stock exe.** The European politician dialog binds its places when it is built (FUN_0081892B,
REA `ev_c919cd4e…`): for n = 0 to 4 (loop end `cmp edi,5` at 0x818DBA) it looks up `PoliticianDlg-Politician%d` into
`[dlg+198h+4n]`, `PoliticianButton%d` (+1ACh), `Poli%dPortrait` (+1C0h), `PoliticianHilightPositive%d` (+1D4h),
`Poli%dName` (+1E8h), `Poli%dCost` (+1FCh) and `Poli%dDescription` (+210h). Each is a gadget handle; a name the
layout lacks gives a handle that resolves to nothing. The list builder FUN_0081A2B8 (REA `ev_3a5f7096…`, the dialog's
virtual at 0xB8BD3C) walks the player's tech statuses, keeps a politician of the next age (or a revolution) that
0x4C6968 accepts, and fills place `[dlg+26Ch]` for it: tech ID at `[dlg+270h+4n]`, the portrait, then the name gadget
(EBP, looked up at 0x81A4FF and null-checked once at 0x81A527), cost and description. Then it calls the name gadget's
virtual with `mov eax,[ebp]` at 0x81A80C (age-up) or 0x81A63C (revolution) without a check, and counts up to 5
(0x81A82A). With a four-place `uipoliticianEuropeandlg.xml`, as the stock one, the fifth politician's name gadget is null: access
violation at 0x81A80C, seen in the Windows log as offset 0x41A80C.

**The hook.** At 0x81A45A (`mov ecx,edi` / `call 58EA03h`, 7 bytes, re-executed), the point where an accepted
politician is about to take place `[ebx+26Ch]`, `UhcPoliticianNoPlace(dlg, status)` counts the leading places whose
`PoliticianDlg-Politician%d` and `Poli%dName` both resolve, through the UI manager's lookup 0x40423C
(`thiscall(manager, handle, type)`, `ret 8`, manager `[[0xC66244]+44h]`, type 0 any or 10h text, the type the name's
own lookup 0x44900A asks for; REA `ev_7c3b79e8…`). When the count has reached them, the builder leaves through its own
exit 0x81A848 (`mov eax,[ebx+26Ch]` / pops / `ret`), the path it takes after the fifth. The rest of the dialog reads
`[dlg+26Ch]` and null-checks its gadgets (the layout 0x81A069.., the hide loop 0x818DF1, the cost refresh 0x81A8C3),
so it shows that many places. The other list builder, FUN_00818EE5, null-checks every gadget it fills.

**Why it is safe.**
- Registers: EBX is the dialog and EDI the tech status, both kept by the stdcall wrapper; EAX, ECX and EDX are dead
  (the re-executed call returns EAX, and ECX at 0x81A466 and EDX at 0x81A487 are written before they are read).
- The stack at 0x81A45A is the loop's own: the call 0x4C6968 before it popped its argument, and the per-entry local is
  built only at 0x81A559, so the exit 0x81A848 finds what it finds after the fifth politician.
- Branches into the replaced bytes: none (capstone scan of `.text` for rel8 / rel32 targets in 0x81A45A..0x81A460).
- `ageUpBuildings` replaces the call at 0x81A44D, five bytes before: the two sites do not overlap and both verify
  their own bytes; tested together.
- Interface only, not on a hot path: the lookups run when the dialog is filled (a click), at most ten per politician.
- The hook is shared (`InstallPoliticianPlaceHook`, `AddPoliticianPlaceObserver` in `features.h`): whichever of
  `politicianPlacesFix` and `politicianEnablesTech` applies first writes it; the place check runs first, then each
  observer with the place the politician is about to fill.

### politicianEnablesTech

**Data.** Through [tech tags](#tech-tags): each `<PoliticianEnablesTech>` text by politician, and every tech's `<Icon>`
text, since the tech record keeps only the texture handle (`[NodeData+14h]`, from 0x621143 → 0x58E3EB) and a gadget's
texture is set by path. The names become tech IDs at the first dialog after a data load (0x600BE1, `thiscall(db,
name)`); a name with no tech is logged and left out, and a politician keeps at most four. `OnDatabaseLoad` clears it all.

**The builder.** FUN_0081A2B8 fills place n = `[dlg+26Ch]` after the hook at 0x81A45A (capstone of 0x81A487..0x81A5F4;
REA `ev_46886807`): the portrait gadget `[dlg+1C0h+4n]` gets the politiciandata record's path (`[dlg+18Ch]`, 14h-byte
records, `+0` tech ID, `+4` path, count `[dlg+190h]`) through 0x638823 and then the texture coordinates (0, 0, 0.75,
0.7734375) through its vtable `+D8h`, whatever the layout says; the name `[dlg+1E8h+4n]` the DisplayNameID; the
description `[dlg+210h+4n]` the RolloverTextID (a DLL beside ours may replace that text at 0x81A5CB).

**The observer** (`PlaceFilled`, before the fill): the place's gadgets by name, `kGadgetByName` (0xAB7C2F) on the
dialog's root gadget (`[dlg+148h]` through 0x404296, as the bind FUN_0081892B does). Without this key's gadgets in the
layout, nothing. A politician without tags: this key's gadgets hidden, the stock portrait and description shown, the
stock description handle (by name) back in `[dlg+210h+4n]`. A tagged one:
- the stock portrait and description hidden (0x448F13); the builder still fills them, unseen;
- `EnablesTechPortrait` gets the record's path (0x638823) and the texture coordinates (0, 0, `flag`) through the same
  vtable `+D8h`, so it shows the top of the same picture;
- `[dlg+210h+4n]` = the `EnablesTechDescription` handle: the builder (or the DLL beside it) fills the shorter box;
- per tech: the name gadget gets the DisplayNameID text (0x58EA52, vtable `+80h`) and, in its help text `[gadget+68h]`,
  the tech's research rollover: 0x4C737C(text, status, player, unit, 1, 0, 1, 1), as the command panel's call 0x4622C5;
  the status is the player's (0x4C5394(`[world+7Ch]`, player ID), entry 0x4804B3(list, tech ID), checked by its tech
  ID, else a search), the player `[dlg+13Ch]` through 0x44CB21, the unit `[dlg+140h]` through 0x44CC6D. With no status
  or an empty result, the RolloverTextID. The icon gadget gets the `<Icon>` path (0x638823) and the same help text.
  One or two techs use the `EnablesTech%d` row gadgets, three or four the `EnablesTechGrid%d` ones.

The help text shows on hover (a posted mouse move in a `background` copy was enough), and a click on an icon or a
name reaches the place's button: the politician is selected (seen in game).

**Why it is safe.**
- Registers and stack: the observer runs inside `UhcPoliticianNoPlace` (stdcall), see politicianPlacesFix.
- The only write outside this key's gadgets is the description handle `[dlg+210h+4n]`, read by the builder at 0x81A596
  for this place and by nothing else found in the builder (capstone); every fill sets it again, from a name lookup.
- The gadget objects come from 0x404296 with the reference released at once (0x40431B), as the stock code does.
- Interface only, on a click: the dialog is the local player's; the politician chosen is the stock research command.
- Beside another DLL (our `dinput8.dll`): a patch at 0x81A5CB is after the handle read, so its text fills our box;
  the site `PoliticianDescriptionRead` (0x81A590, 0x39 bytes) stops before it.

### kbUnitSyscalls

Five syscalls added to the KB group through the syscall registry (`src/syscalls.*`, the hook on
the group's first registration at `0x885D14`); no game code is patched. Each is a cdecl function
that calls engine functions, with "the player" read from `[0xC66664]` as the stock KB syscalls
do (their common head, for example `0x881CC6`: world, player `0x44CB21`, kb `[player+80h]`):

| Syscall | How |
|---|---|
| `kbUnitGetCurrentInventory` | Unit by ID `0x44CC6D`, inventory `[[unit+B4h]+94h]`, ResList get `0x44EFFF` on its `+4` list. |
| `kbUnitGetInventoryCapacity` | `0x494503` (the unit's proto carry capacity). |
| `kbUnitIsInventoryFull` | `0x4DC520` on the inventory. |
| `kbUnitGetNumberWorkersIfSeeable` | The stock kb method `0x86C647` returns the worker count `[unit+98h]` for the player's own units only. This one tests the unit with isSeeable `0x48A9EF` (the visibility mask `[[unit+B4h]+ACh]`, else the explored mask and the proto's under-fog flags), then counts the entries of the worker array `[unit+94h]` (18h bytes, worker ID first) whose worker passes the same test. |
| `kbUnitGetNumberTargeters` | Walks the player's units (`[player+F8h]`, count `[+FCh]`); for each of abstract index 16h that is not in the unit's worker array, the squad (`0x4E2A03`) `[+1Ch]` object's order list (`+28h`/`+2Ch`), and in each order the target entries (`+1Ch`/`+20h`, 18h bytes, unit ID first). |

Every pointer and count is checked before use (counts above 100,000 are treated as invalid);
nothing is written.

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
     **EDI** in the second.
     Upstream uses ESI in both. <!-- private -->
2. **Home city icons.**
   - At `0x5C1E1F` the hook loads two extra textures through `0x58E3EB`:
     `ui\home_city\xp_hc_icon` and `ui\home_city\fame_hc_icon`.
   - It points slots 3 and 5 of the resource-icon jump table at `0x9A2180` to DLL cases that use
     those textures. Stock sends both slots to the default case, which shows no icon.
   - A texture that failed to load (`-1`) keeps the default case.
3. **"Fame trickle".** At `0x51B026`, the imm32 of `push "FavoriteUnit"`
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

`LastResort`: the helper walks the IDs at `[player+F8h]`, count `+FCh`, with the stock check 0x85302C, and writes no game state. The
list is the simulation's, so every machine picks the same unit, and the walk runs only for a player with no point. With no point
the game cancels the queue and refunds the ship, seen in game; the code that does it was not read.

`replace`: a jmp at 0x4C6BCF, 7 bytes, goes to the same search as the exit 0x669E2E, with the stack the same after a push of EBP. `warn` runs
at "nothing found", on the local player's real clock, through the game's chat, vtable +5Ch as `trChatSend`. The search that stores never
comes with no point, so the test is a queued card.

`firstTC`: a jmp at 0x6A2130 re-executes the read of flag 136 and sets the bit for the player's FirstTC of its civ's `<firstTC>` proto.
Nothing is written to the proto, which every civ shares.

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

**`moving`, `fighting` and `busyRate`.** The two busy tests are thiscall functions of the target's action
manager `[t+58h]`: `0x4802D4(-1)` (`ret 4`; the current action `[mgr+24h]` is a move) and `0x9CA5AC` (fighting).
Both only read. With one state alone, or a busyRate other than 100, the tick hook at `0x9E0C79` runs them for a
marked healer: an excluded state jumps to the tick's end path `0x9E0D3F` (state 10, as stock does), an allowed busy
state notes the action (`g_uhcHealBusyAction = ESI`) and goes on to `0x9E0C9F`. With both states and busyRate 100 no
test runs, as before. The search hook at `0x9CD9C7` runs the excluded state's test on the candidate's manager (the ECX
of the stolen call) and answers AL = 0 for it, 1 otherwise. For the rate, a third hook replaces `mov [esp+0Ch],edx /
mov [esp+14h],eax` (8 B at `0x9E0CC7`), where the heal path stores `[world+104h]` and `[world+318h]`; `0x9E0CD4` and
`0x9E0CDA` multiply the rate `0x487C45` by them, and the product is both the HP added at `0x9E0CE9` and the action's
total `[action+68h]` (`0x9E0CEE`). For the noted action the hook multiplies the stored `[world+318h]` by busyRate / 100
(`fld / fmul / fstp` on the stack copy; the FPU stack is empty there) and clears the note, then jumps to `0x9E0CCF`.
`0x9E0C9F..0x9E0CCF` has no exit, so the note is always consumed in the tick that set it, and the busy hook clears it
on entry. The site sits between the ones `healNonIdle` (`HealIdleCheck`, to `0x9E0CA4`) and `overhealSources`
(`HealTickAdd`, from `0x9E0CCF`) verify, so the keys' order does not matter. Sites `HealTickFactors`,
`HealTargetMoving`, `HealTargetFighting`.

How the sites were found:
- Patching only the tick did nothing in game: the tick hook never ran, because the search never
  started a heal on a fighting unit.
- A hardware-breakpoint trace (`tools/re/trace_exec.py`) showed that heal actions start from
  FUN_009CD865.

The trace is described in [engine-symbols.md](engine-symbols.md), "Unit types and healing". <!-- private -->

### smartHealTargets

**The stock search** FUN_009CD865 (`thiscall(owner)`, healer at `[owner+4]`; called from 0x68C14E
for an idle healer; REA Evidence `ev_41afc083…`) fills the shared query `[world+184h]` around the
healer (0x49A098 → 0x499CE4) and walks its results, `[query+0]` (38h-byte entries, the unit ID at
`+0`), count `[query+4]`, with no cap of its own. For each candidate: the unit table lookup, not
the healer, HP ratio (0x45F295) below 1.0 and at least 1e-6, alive (`vtbl+A4h`), an action manager
`[c+58h]`, idle (0x44F1A7, the call `healNonIdle` hooks at 0x9CD9C7), not abstract bit 6, not flag
42h, a heal action of type 5 (0x4EE797), 0x9C2E40(5, 8) ≤ 0, and in range (0x7FCF2D with the
action's range from 0x470F5E). The first one in range is healed at once (0x9CDA62: the healer's
`vtbl+64h(1)`, then 0x9CBDC4(owner, `[esi+10h]`)); with none, 0x9CDA58 returns AL = 0.

**The hooks** (`hooks/smartheal_hooks.asm`):

| Site | Stolen | Hook does | Continues at |
|---|---|---|---|
| 0x9CDA36 | `call 7FCF2Dh` (5 B; ECX = healer, the candidate and the range pushed, ESI = candidate) | the stolen call; in range: `UhcSmartHealConsider(healer, candidate)` | 0x9CDA3F, the next candidate |
| 0x9CDA58 | `pop esi / pop ebx / pop edi / xor al,al` (5 B) | `UhcSmartHealPick(healer)`; a unit: ESI = it | 0x9CDA62 (accept); none: the stolen bytes, 0x9CDA5D |

`UhcSmartHealConsider` scores the candidate: the index of the first listed type it is of (is-a
0x44D7FA; none: after them), the stock ratio 0x45F295, the squared ground distance (x `+14h`,
z `+1Ch`) to the healer, and the unit ID; it keeps the smallest tuple, and the first candidate for
the log. `UhcSmartHealPick` returns it and clears the state, so the next search starts empty. The
accept path reads only ESI and EBP and the stack at 0x9CDA58 is the one it pops at 0x9CDA77.

**Why it is safe.** Every stock test still runs for every candidate and in the same order; only
the choice among the ones that pass changes. The score uses no address and no query order (the
unit ID breaks ties), and the ratio is the stock function, so every machine picks the same unit.
The search does not re-enter and the simulation is single-threaded, so one state is enough. The
range hook keeps EBX, ESI, EDI and EBP (pushad); 0x9CDA3F writes EAX before reading it. The sites
decode at instruction boundaries and nothing branches into the stolen bytes (0x9CDA58 is entered
at its first byte from 0x9CD92A and the loop's end). `healNonIdle`'s hook at 0x9CD9C7 is a
different site in the same loop, and both work together.

**`switch=<percent>`.** The search is only called for an idle healer (0x68C14E), so nothing looks again while a heal
runs. The option adds a hook at the start of the healing state (8) of the heal tick FUN_009E0B53: `mov ecx,[esi+24h] /
push 8 / mov [esp+14h],ecx` (9 B at 0x9E0C3A, after `cmp al,8 / jne`; nothing branches into it). `UhcSmartHealRecheck
(healer, target)` acts only on a heal this search started: the pick hook notes, per healer ID, the target it returned
and the second of game time (`[world+108h]` / 1000). Once per new second it calls the stock search itself,
`0x9CD865(owner = [healer+58h])` (the call 0x68C14E makes; it checks `[owner+4]` = healer), as a dry run: the range
hook records only candidates whose rank is at most the target's and whose stock ratio is below the target's minus the
margin, and the pick hook, seeing the dry run, returns null, so the search leaves through its no-target exit and starts
nothing (the search writes only the shared query `[world+184h]`, which every search refills). The target itself is no
candidate (0x9C2E40(5, 8) counts its healer). With a candidate the hook jumps to the tick's end path 0x9E0D3F
(`vtbl+34h(10)`, the stack as for the stock jumps there); the healer is idle, and its next stock search picks the best
unit, which beats the old target. Otherwise the stolen bytes run and it goes on at 0x9E0C43. The re-check is in the
heal tick, inside the healer's own update, the same context as the stock idle search; it uses only game time, unit
IDs, ratios and the stock tests. The notes live in the DLL (an `unordered_map` looked up by ID, never walked), cleared
on each data load; a loaded game has none, so a heal started before the save is not checked. Sites `HealTickHealing`,
`HealTickEnd`, `HealSearchHead`.

**No healer marker.** The search is the same function for every healer type, and the change only
reorders units the stock rules already accept, so a global key is enough; a mod that wants a
healer to prefer some units lists their types.

**Observed in game:** four units hit at once (90, 45, 70, 33 %) were healed in the order 33, 45, 70,
90 % (stock: the 90 % settler first); with `Pikeman` listed, the pikeman came first.

### Extra abstract unit types (used by every key that takes a `<UnitType>`)

`healNonIdle`, `dodgeAnyUnit` (and its sound keys), `maintainWaitForPop`,
`broadsideMuzzleLimit`, `lifespanAfterConstruction`, `gaiaSocketsOnly`, `noCorpseDopples`,
`startingTC`, `noTrainNearEnemyTC` (and each `near` type), `overhealHitpointBars` (each of its types), and
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

**dodgeChance** shares that hook. The hook now calls `UhcDodgeDecide(unit, damageInfo)` and
takes one of four ways out:
- the stock compares (the two loads redone, `0x49ACEB`): no rule matched and the unit has no
  marker;
- the stock dodge path `0x6A249C`, with ECX restored to the database and EDI = `[world+7Ch]` as it
  expects: no rule matched and the unit has `dodgeAnyUnit`'s marker;
- `0x6A24FC`, the end of that path after its roll: a rule dodged the hit. From there the path
  reads only ESI (the unit), EBX (its player, `[esi+44h]` from 0x49ACC4) and its own locals:
  floating text, sound set (`dodgeSoundSet`'s hook included), `mov al,1`, `ret`;
- `0x49AD0F`, the stock "not dodged" exit: a rule matched and the hit lands.

The inputs:
- **The damage type of the hit.** At the hook, `[esp]` is the caller's EDI, saved by
  `push edi` at 0x49ACDD. FUN_0049ACAA has one caller, `0x49B023` in FUN_0048649F, where EDI =
  `[ebp+24h]` (0x49AF98), the action's damage info: `+0` damage, `+4` flags, `+5` the damage type,
  an index into `damagetypes.xml`. Traced at 0x49B021 in game: a Pikeman's hit 0 (`Hand`), a
  Musketeer's and an Explorer's 1 (`Ranged`); `[action+10h]` was 1 for all three, so it is not the
  type. The names are resolved in the database's list `[db+44h]` (count `[db+48h]`; entries of
  10h bytes with the name at `+4`, written by 0x5FFC55), filled from `damagetypes.xml` by
  FUN_0052D454, which the database load calls at 0x526DD0.
- **The tech.** `0x600BE1(db, name)` once per data load, then `0x94AF27([world+7Ch], player ID
  [[unit+44h]], tech)` per hit, as the stock path does.
- **The roll.** `0x407CE7(rng = 0C66588h, stream, max)` is a per-stream LCG, seed × 343FDh +
  269EC3h, returning `((seed >> 16) & 7FFFh) mod (max + 1)`, so values 0..max. Stock draws
  (2, 100) and dodges below 15.0: 15 of 101 values, 14.85 %. A rule draws (2, 999) on the same
  stream and dodges below percent × 10; the 768 lowest values of 1000 come up once more in 32768
  draws, so 15 % is 15.1 %. 0 % and 100 % do not draw.
- **Resolution.** Rule types are marker or proto IDs from the abstract unit type registration;
  tech and damage type names are resolved on the first test after each data load (a counter
  raised by `OnDatabaseLoad`), from that machine's database. In a process, scenarios do not reload
  the data (seen in game: one resolution for two games); a skirmish start does.

**Why it is safe.** The hook keeps the stock frame: it pushes ECX around the C++ call and
restores it, and the FPU stack is empty at 0x49ACE5 and at each exit. EAX and EDX are written
before they are read on every way out (the compares load EAX; 0x6A249C pushes and calls; 0x6A24FC
loads EAX and EDX; 0x49AD0F sets AL). The decision reads only the unit's proto, the hit's damage
type, the synced tech status and the synced RNG, on the stream and in the order every machine
uses; the rules are fixed after startup. It runs once per hit, over the few rules, with no
allocation.

**Observed in game:** 50 % against ranged hits gave 18 of 46 and 28 of 50 dodges, 0 % against
melee 0 of 57; 30 % `notech` without `YPDodge` 20 of 71; 100 % with `HCExplorerFrench` active
49 of 49; a rule whose tech was not active let all 15 hits land. Without `dodgeChance`,
`dodgeAnyUnit` and `dodgeSoundSet` behaved as before.

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

### detonationDeath

**The three other tags (2026-11-05).** The delete: the stock Delete button and key run the console command
`uiDeleteSelectedUnit`, whose handler builds the synced command of type 7 for the selected unit; its executor
FUN_007CCF7F (slot 21 of the command's vtable 0xB87E30) kills the unit in one of two ways, both wrapped by a call
rewrite: `0x4820A1(0, 1)` at 0x7CD0CF for most protos (the wrapper fires the blast first, while the unit is whole, with
kill flags 1 0 0 for the log) and `0x4B4DC2(1, 0, 0)` at 0x7CD0DC for a proto with flag 0Dh (the wrapper notes the unit
ID, and the kill handler's wrapper reads it to tell a delete from a trigger's kill, which has the same flags). A proto
without `<DetonationCommand>` gets no blast on a delete; the stock `uiDeleteSelectedUnit` from `exec` crashes on a null
UI pointer before the selection, so the test used the real Delete key. The threshold: `overhealsources.cpp`'s hook at
0x4823A3 now reports every loss (`g_hpLoss`) before it is applied, and `detonationDeath` compares the HP after it with
the max HP of 0x480408 (modifiers counted); at or under the threshold it asks the kill queue with the combat flags once
(a set of unit IDs until the handler runs), so the drain fires the blast exactly as for a killing blow; with a decay it
only arms the unit. The decay: a `std::map` by unit ID walked after each world update (`AddWorldTick`, now 8 slots),
by game time; the HP setter with flag 0 applies each step, the kill queue the end; a unit back over the threshold, dead,
gone or inside another is dropped; a new game or a data load forgets everything. `detonationDeath` moved after
`overhealDecay` in `kFeatures`, because `overhealSources` verifies the raw bytes of the add-HP entry.

Every death goes through one queue. TakeDamage, a lifespan, a trigger's kill and the rest ask 0x4B4DC2, which appends the unit and
three flag bytes to the world's list at `[world+8DCh]`, and the drain 0x493D46 calls the kill handler 0x4B4F70 from one single
call, 0x493D8F. `Destroy` does not pass there. The key wraps that call, so it runs before the handler sets the dead bit,
with the unit still valid as an attacker. Since `annexFacing` (2026-11-08) the call is the shared death observer
(`deathobservers.cpp`, `AddDeathObserver`): one call written there, each key's observer run in `kFeatures` order before the
stock handler, and the site verified once by the shared module instead of by this key.

The blast is the stock area damage 0x4C9D89, `thiscall(world, unitId, action, point, multiplier, 0, 0, -1, int* out, bool, Vector*
offset)`, `ret 28h`, in the same call a unit makes for an attack around itself at 0x6A4A6B: its own position, multiplier 1, the
action's bit 6, and the zero vector at 0xCF0618.

**The blast on screen (2026-11-13).** The area damage draws nothing. A shot that lands on the ground (a mortar shell, a
missed cannon ball) is drawn by the terrain impact FUN_004CB11C, `thiscall(projectile, point)`, `ret 4`, called by the
projectile's update at 0x4C4818 and 0x4CB459 in every mode. It returns at once when the point is not visible to the
local player (FUN_004601B8), takes the terrain's impact type at the point (water 7, the type of the terrain there, or 9),
reads the projectile's action `[proj+10h]` and that action's impact effect ID `[action+70h]` (written by the tactics
`<impacteffect>` handler 0x5FAFB2 through the effect manager `[[0C66234h]+0BB8h]`, FUN_0058F017), and calls the impact
spawn FUN_0049C1E5(point, direction, 0, type, 1, `[proj+28h]` == 0, 0, 0). The direction is the point minus
`[proj+64h]` on the ground plane, or the default vector at 0xC6655C when that is zero. The sixth argument picks the
entry's `particleSet` (1) or its `secondaryParticleSet` (0, when it has one); the spawn plays the particle set and the
entry's sound sets at the point.

After the area damage, the key calls FUN_004CB11C with a zeroed record of 70h bytes that has only those fields: the
action at `+10h`, the point at `+64h` (so the default direction) and `+28h` = 0 (the `particleSet`). The point is the
unit's position, copied before the area damage. **Since 2026-11-21 (#86)** a unit whose obstruction radius
(`<ObstructionRadiusX>` `[proto+88h]`, handler 0x5F5972; `<ObstructionRadiusZ>` `[proto+8Ch]`, 0x5F59C8) is 1.5 m or more
on either side gets one call per point of a grid over its footprint: `round(2r / 3)` points per side (at least 2, at most
3), from −0.75 r to +0.75 r along its right vector `[unit+38h]` and its forward vector `[unit+20h]`, at the unit's
height; a `TownCenter` (4.5 × 4.5) gets 3 × 3, a `House` (2 × 2) 2 × 2. Each call is the stock visual of a shot landing
there, with its own visibility test. The victims: the area damage hands each one to TakeDamage 0x49B3D9 with the
impact argument −2 (no impact effect) and the bool the stock caller takes from the action's flag bit 6, which TakeDamage
reads only to skip the hit and pain sounds (0x484136 types 3 and 2, 0x49BC87). The key passes 1, so the victims only
flinch (0x49C0D4, played either way) and the only effect and sound is the blast on the dying unit. The damage path does
not read the bool (REA `ev_32be21bf…`, FUN_0049B3D9; `ev_71ba0bc4…`, FUN_004C9D89; `ev_22c85aa1…`, FUN_0049C0D4). By default the action is the detonating one, so its own
`<impacteffect>` plays (nothing when it has none: `[action+70h]` < 0). `<DetonationImpactEffect>path</DetonationImpactEffect>`
names another impact effect: its handler, during the proto load, passes the node's text field `[node+14h]` to
FUN_0058F017 as the tactics handler does, which finds the file or loads it and returns its ID (< 0 on failure, logged
and ignored); the blast then uses a stand-in action of 74h zeroed bytes with that ID at `+70h`. `none` stores −1 and
nothing is drawn.

**Observed in game (2026-11-13):** hardware breakpoints on 0x4CB11C, 0x4CB266 and 0x49C1E5 during two blasts, both
called from the death observer (return 0x493D94): one in the black map reached 0x4CB11C and returned at the visibility
test; one on the player's own ship reached 0x4CB266 with EBX = 7 (water) and called the spawn once.

**Knockouts and the trigger `Kill` (2026-11-13).**
- **A knockout is not a death.** The kill handler 0x4B4F70 sets the unit's HP to 0 (`0x4820A1(0, 0)`), then tests proto
  flag 123 (`cmp [proto+54h],7Bh / mov ecx,[proto+50h] / mov dl,[ecx+0Fh] / and edx,8 / ja 50AAADh` at 0x4B51CB): set,
  the unit is knocked out (FUN_0050AB6F) and skips the code that marks it dead (bit 11 of the unit's state). Flag 123
  is `KnockoutDeath`: the proto parser's `KnockoutDeath` branch is `or byte [[proto+50h]+0Fh],8` at 0x5FCEBE. The death
  observer runs before the handler, so the key tests the same bit on the unit's proto (`[unit+5Ch]`): set, and the
  proto has no `<DetonationOnKnockout>1</DetonationOnKnockout>`, there is no blast. Read from memory in game: set on
  the `Engineer`, clear on a Settler and an archer. A delete with `<DetonationCommand>` is not filtered.
- **The trigger `Kill` is not a delete.** `trUnitDelete(remove)` (handler 0x982771, registered at 0x98A64E) calls
  FUN_0082F923(player, ids, count, remove, 1, 1), which builds the delete command (type 7, FUN_005695FC) and, for its
  fifth and sixth arguments, sets bit 3 (`[[cmd+58h]] |= 8`) and bit 16 of the command's flag bits; `remove` goes to
  `[cmd+8Ch]`, which the executor sends to the removal 0x4726B2 instead (that is `Destroy`). The Delete button's
  builder FUN_0082F1E3 sets neither bit, nor do the AI's calls of FUN_0082F923 (0x724FC2 and 0x73E668 pass 0, 0). The
  executor FUN_007CCF7F keeps the command in EDI (`mov edi,ecx` at 0x7CCF8A) and reads the same flag bits itself
  (bit 16 at 0x7CD002). The two calls the key rewrites (0x7CD0CF, the HP setter; 0x7CD0DC, the kill queue) now go to
  asm hooks (`hooks/detonation_hooks.asm`) that hand the unit and EDI to the C helper, then jump to the stock callee
  with the arguments and the return address untouched. A command with bit 3 is a trigger's `Kill`: the HP-setter
  path fires the blast at once as a death, and the kill-queue path notes the unit so the death observer treats the
  kill as a death; the log line ends in `(a trigger's Kill)`. Without bit 3 it stays a delete.
- **Observed in game:** the knockout without the tag (`knocked out (KnockoutDeath), no blast`), with it (a blast at each
  of two knockouts), the trigger `Kill` of an archer and a Settler (blasts), the Delete button on both (no blast). All
  of these deletes went through 0x7CD0DC: every unit seen there has proto flag 13 (`0x44D063(0Dh)`), and the
  HP-setter call 0x7CD0CF was not reached.

Evidence (`rea/evidence/age3y-b1a1dab7/detonation52b.json`, and capstone over the exe for 0x982771, 0x5FCEBE, 0x4B51CB,
0x7CCF7F): `ev_17f7f172…` (FUN_004B4F70), `ev_edf31a0a…` (FUN_0082F923), `ev_dfdd9ca3…` (FUN_0082F1E3). Sites
`DeleteCommandRegister` (0x7CCF89), `DeleteCommandFlags` (0x7CD002) and `KnockoutTest` (0x4B51CB), verify only.

**Why it is safe:** drawing and sound only, as in the stock landing: FUN_004CB11C already depends on what the local
player sees, so nothing in it can reach the simulation, and the key calls it after the damage is applied. The two
records live on the stack for the length of the call. Evidence (`rea/evidence/age3y-b1a1dab7/detonation52.json`,
and capstone over the exe's bytes for the callers and the out-of-line blocks 0x4DD628 and 0x64A32F): `ev_ca755380…` (FUN_004CB11C), `ev_204bff62…`
(FUN_0049C1E5), `ev_eaca0080…` (FUN_005FE922, the entry's two particle sets), `ev_6061959a…` (FUN_0058F017).

A unit killed by the blast only joins the queue, and the drain reads the count again on each turn, so a chain runs in order
and does not recurse. A proto's action is found by comparing the names of the database's list `[db+1FD8h]` for the IDs its action set
has, and the ID is kept. The action is the one in the player's copy of the proto.

- **Observed in game:** see the tests in the modding guide. The kill flags were 1 0 0 for a trigger's kill, 0 0 0 for combat, a
  lifespan and a chain.

### damageOverTime

**What stock has.** An Age of Mythology poison survives only as dead code:
- TakeDamage tests bit 8 (`Poison`) of the hitting action's flag bytes;
- it then posts unit event 20h (`Poison`) to the attacker;
- the attack action's event handler (0x48F175) passes `(damage × −0.1, 3.0)` to 0xB1BE43, which is
  `mov al,1; ret 8`.

Nothing is applied.
The details are in [engine-symbols.md](engine-symbols.md), "Damage and poison". <!-- private -->
The DLL ignores that path and adds its own, driven by data.

**Data.** At load time, the action parser FUN_005F98A0 ends every unknown `<ProtoAction>` child at
0x5FA11E.
- The shared action tag hook (`src/actiontags.cpp`, see [spreadAnyAccuracy](#spreadanyaccuracy))
  passes it every unknown tag; this key reads only those of a `protoy` `<ProtoAction>` (return
  address `[esp+C0h]` = 0x5FA213).
- For a tag named `AttachProtoUnit` (case-insensitive), it records the text X under the key
  (attacker proto ID `[proto+4]`, action name index `[action+4]`). `AttachMaxStacks`,
  `AttachSnare` and `AttachTickText` set the record's options under the same key, in any order;
  a value that does not parse is logged and dropped.
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
  - each hit makes its unit the attacker, takes its action's options (stack limit, snare, tick
    colour) and adds a **stack** that ends `now + Lifespan` (the current Lifespan). The stacks are
    the end times, kept in expiry order; stacks already expired are dropped first, and at the
    limit the oldest goes. The poison's end is the last stack's. With the default limit of 1 a
    hit just moves the end, as before stacks existed; the tick timer keeps running either way.
- A hit that kills the unit, or a unit that is not alive (unit `vtbl+A4h`), adds nothing.
- The hit sees the attacking proto and action of every kind of attack tested: hand attacks,
  instant shots, flying arrows, grenades and cannon balls (the projectile's damage arrives with
  the launcher's proto ID and action), and each unit of an area attack (one call per unit).
  With `log`, the first damage of each (proto, action) without a record is logged, so a modder
  can see the names the game uses.

**Tick.** The entry of the world update (`0x481A57`) jumps to a second wrapper.
- It calls the stock update through its trampoline (`sub esp,0Ch; push ebx; push ebp;
  jmp 481A5Ch`).
- It then, for the game world `[game+13Ch]` only, walks the poisons in key order with
  `now = [world+108h]`.
- Each due tick (`nextTick ≤ now` and `nextTick ≤ end`) calls the stock TakeDamage:
  - unit, attacker player, X's proto ID, X's `Attaching` action;
  - the attacker unit ID while that unit exists, else −1;
  - multiplier = the stacks alive at the tick's time (1 without `AttachMaxStacks`): TakeDamage
    passes it to the damage-from-action function FUN_0048649F, which scales the computed damage
    (in game, 5 Siege gave 5, 10 and 15 for 1, 2 and 3 stacks);
  - damage 0 (computed), no cap;
  - p8..p13 = `0, 0, 1, 1, -2, 1`, as the stock special-damage callers pass them, except p11
    (the hit reactions), which is 0 when the attacking unit is gone.

  The engine therefore applies the damage type, the bonuses, the armor and the DamageFlags. Kills
  and XP go to the attacker's player. All seen in game (2026-10-29): a `DamageBonus` against
  cavalry tripled the ticks on a Hussar, the musketeers' hand armor took 20 % off, a unit
  converted to the attacker's side took 0.00 per tick from X's `Enemy` flags, and a musketeer
  killed by a tick gave its 10 XP bounty to the attacker's player (the XP in `[player+230h]`,
  entry 5).
- **Why p11 depends on the attacker.** With p11 = 1, TakeDamage runs the reactions to a hit:
  retaliation, attack alerts, and, for a unit in an army (AI armies), the army's list of
  attackers. That last part reads the attacking unit with no null check (0x6A3253). An army unit
  poisoned by a unit that is gone would crash the game, so such a tick passes 0 and skips the
  whole block (`jne 0x49BC00` at 0x49B929). The damage itself does not depend on it. The
  attacker-gone path ran in game (an attacker removed by the trigger `Destroy`: the ticks went on
  and killed the target), but not on an army unit: units sent by the scenario trigger
  `Army Deploy` (`trArmyDispatch`) do not get the army flag (bits read in memory), nor do units a
  map adds with `rmCreateArmy` / `rmAddUnitsToArmy`, nor the two AIs' military units read at
  minute 26 of a skirmish (902 attacker-gone ticks in that game, none on an army unit). The only
  writer of the flag is 0x8C2F2D, right after FUN_008C2544 (its one caller); what reaches it was
  not traced. With `log`, such a tick line ends with `, army unit`.
- **With snareOnlyHitUnit:** the poison's slow is a timed, exclusive velocity multiply, so that
  key takes it for a snare: in game it logged the poisoned Hussar of a charging group as snared
  (`counts 6.750 instead of 3.375 toward its group's pace`, `lags behind its formation slot`).
- **An attacker is "gone"** only when its ID no longer gives a unit. A killed unit keeps its ID
  while its body lies on the ground (trigger `Kill`), so its poisons keep it as the attacker
  until the body disappears; a removed unit (trigger `Destroy`) is gone at once.
- **Techs on X.** Each tick reads the player's copy of X's `Attaching` action again, so a tech
  that changes its damage applies from the next tick. A Lifespan change applies from the next
  hit, which sets the end time. TAD's tech effects have no ROF subtype: the table of `subtype`
  names at `[db+3500h]` has none, so the interval always comes from the data. In game, a tech
  doubling the `Attaching` damage, turned on in the middle of a poison, doubled the next tick.
- **When the attacking unit is gone,** the engine skips its diplomacy filter (FUN_0049AEE0 lets
  everything through without an attacking unit). The wrapper then applies the same filter
  itself, with the attacker's player: X's DamageFlags against the unit's owner and the player's
  relation to it (`[player+1D4h + 4*id]`, 2 = enemy). A unit converted to the attacker's side
  therefore stops taking the poison, as it would with the attacker alive.
- A poison ends when its end time passes, or when the unit dies or disappears.
- **The snare** (`AttachSnare F`): when a poison starts, and after each tick that is not the
  last, the wrapper calls the stock snare's creator 0x4DD22D(unit, 0, F, -1, -1, 0, 2, ROF +
  250 ms, -1, -1, 1), as the `<TargetSpeedBoost>` path does with 0.65 for 3000 ms
  (0x4DD201..0x4DD223), and only for a unit whose `vtbl+90h` (0x45EE55) says it can move, the
  same test as there. That creates a timed, exclusive multiply modifier of the velocity (unit
  action type 2Ch), which the speed getter `vtbl+34h` (0x487E27) and the group pace already
  take into account (see [snareOnlyHitUnit](#snareonlyhitunit)). Each modifier outlives the next
  tick by 250 ms, so the slow is continuous and ends 250 ms after the last tick; at most two of
  the poison's modifiers exist at a time, and only the first exclusive one counts. In game a
  Hussar's speed read 3.38 (6.75 × 0.5) at every tick.
- **The tick text** (`AttachTickText`): after a tick that dealt damage, `ShowTick` writes `-N`
  (the damage, rounded) over the unit with the shared floating-text helper
  (`src/floatingtext.cpp`, the stock dodge text 0x8023AE without its rise, see
  [noTrainNearEnemyTC](#notrainnearenemytc)). It shows only when the text manager exists and the
  unit is visible to the local player; `damageOverTime noticktext` turns it off. It is
  interface only: it reads the local player and writes the text manager, which nothing in the
  simulation reads.
- **Another game clears all poisons.** A new or loaded game can reuse the old world's address, so
  the test is the world's step count `[world+F8h]`. The world update raises it by exactly 1
  (0x481A87), and while poisons run every step reaches the wrapper. A jump of more than 1, game
  time going back, or another world pointer clears the poisons and logs `another game started`.
  A data load clears them too, and logs `the data was reloaded`.

**Determinism of the new parts.** The stacks are game times in a vector inside the ordered map's
value, added and dropped by game time only; the multiplier is their count. The snare is a
simulation call made in the same order on every machine (the map's order, after the tick). The
tick text depends on the local player and touches nothing the simulation reads, so
`noticktext` may differ between players.

**What it does not do.**
- X is never created in the world, so there is no model or effect (the tick text is the only
  marker).
- Poisons are not saved in saved games. Loading one reloads the data, which drops the running
  poisons (seen in game: `the data was reloaded; 1 running poison(s) dropped`, and the unit took
  no more ticks).
- The stock Poison flag stays unused.

**Saved games.** `savedmarkers.h`: the modifier's save 0x9E3423 and load 0x9E355E copy `+68h`, `+6Ch`, `+70h` and `+74h` as raw dwords,
and its update reads none of the last three, so a modifier of an unread stat holds four words. `damageOverTime` keeps a header
(63h) and the stacks (64h) per poison, `overhealDecay` the last gain (65h). They are written in the simulation on every machine,
reused when free, and read once when another game is running. A transform ends them until the key's next write.

### spreadAnyAccuracy

**What stock does.** A projectile's fate is decided when it is launched.
The code is mapped in [engine-symbols.md](engine-symbols.md), "Projectile accuracy and spread". <!-- private -->
With the cfg var `ballisticPrecalcHits` (on in the game's own `Startup\gamey.cfg`) and a target unit, the launch
rolls the action's accuracy: a hit flies to its target and damages it; a miss is moved by
uniform(-r, r) on x and z, with a hardcoded `r = min(0.25 × d, 5)`, and **deals no damage at all**
where it lands. `PerfectAccuracy` skips the roll (a hit). `InstantBallistics` and `TargetGround`
shots never reach that code: an `InstantBallistics` shot is a sure hit (mode 1), whose tracer flies to the
impact point and whose target takes the attack when it arrives. The tactics tags `<MaxSpread>` and
`<SpreadFactor>` (Age of Mythology leftovers) are not read.

**Data.** The key adds a handler to the shared action tag hook (`src/actiontags.cpp`, below). For a
child named `MaxSpread` or `SpreadFactor` (case-insensitive) of a `.tactics` `<action>` or a `protoy`
`<ProtoAction>`, it parses the text as a float (spaces around it allowed). It stores the value under
the key (proto ID `[proto+4]`, action name index `[action+4]`), the key `damageOverTime` uses.
- The tactics loader FUN_005FAA4F loads each proto's tactics file into that proto's own action set, so
  the key is per proto even when several protos share a file. A proto's `<ProtoAction>` is read after
  its `<Tactics>` line, so its values override the file's (seen in game: a Longbowman's tactics
  `20 / 2` and its `<ProtoAction>` `3 / 1.5` gave 3 / 1.5).
- A missing tag keeps the stock value (5.0, 0.25). A value that is not a number from 0 to 100
  (`MaxSpread`) or from 0 to 10 (`SpreadFactor`) is logged and ignored. So is a tag that comes
  before the action's `<name>` in a tactics file (the action has no name index yet); every stock
  file has `<name>` first.
  So does every WoL file. <!-- private -->
- The table is cleared on every data load (`OnDatabaseLoad`), before the protos are read again.
  Every player's copy of a proto and of its actions keeps both numbers of the key.

**The shared action tag hook.** The jmp at 0x5FA11E (unknown-tag fall-through of the action parser
FUN_005F98A0) used to belong to `damageOverTime`. It is now written once by `actiontags.cpp`,
whichever of the two keys are on, and calls each key's handler in `kFeatures` order. It passes the
tags of both callers, told apart by the return address `[esp+0C0h]`: 0x5FA213 (`<ProtoAction>`) and
0x5FA623 (a tactics `<action>`, FUN_005FA5B3). Any other caller goes straight on to the next child.
`damageOverTime`'s handler keeps reading only `<ProtoAction>` tags.

**Shots: seven hooks.**
1. **Hit roll** (0x499890, over `cmp ebx,2 / je 4CEF7Bh`, 9 B). EBX holds the roll's result. A miss
   goes on to the miss hook, as in stock. For any other result, a C++ call checks the shooting unit
   `[esp+0E8h]`: if its proto (the player's copy, `[unit+5Ch]`) has the marker type (is-a 0x44D7FA),
   EBX becomes 2 and the shot goes to the miss hook too; otherwise it continues at 0x499899 unchanged.
   This covers accuracy 1.0 and `PerfectAccuracy` (whose EBX stays 1).
2. **Miss** (0x4CEF7B, over the stub's `lea eax,[esp+28h] / push eax / mov ecx,esi`, 7 B). Every miss
   reaches the stub: from 0x499893 (now the hit hook) and from 0x6A4BCA, where a failed target lead
   makes a miss. The hook:
   - looks up the shooting action's values from the unit action `[esp+18h]` (its `+4` is the
     player's copy of the action) and the shooting unit's proto, and puts them in two globals;
   - calls FUN_004CEF8C itself, as the stub did;
   - puts the stock 0.25 and 5.0 back, writes the `log` line and, for a marked shooter, sets EBX to 3;
   - continues at 0x499899, which stores EBX in `[projectile+20h]`.

   3 is the mode of a `TargetGround` shot: the projectile flies to the (offset) point and, where it
   lands, the attack applier FUN_0049BE95 is called with no target, so the action's `DamageArea`
   damages the units around that point. A miss (2) never calls it; that is why a marked unit's shots
   are ground shots and not misses. Unmarked units keep 2: their misses still deal no damage, only
   their offset changes.
3. **Radius** (0x4CF00B in FUN_004CEF8C, over `fmul [0.25] / fst [esp+0Ch] / fcomp [5.0] / fnstsw ax
   / test ah,41h / je 4E2CE3h`, 27 B). With ST0 = d it computes `r = d × SpreadFactor`, clamps it to
   `MaxSpread` and stores it where the stock code does. It then continues at the stock `r > 1e-6` test
   0x4CF026, so the two random draws 0x422648(sync RNG, stream 2, -r, r) are the stock code's.
   FUN_004CEF8C has no other caller, and outside the miss hook the globals hold 0.25 and 5.0.

4. **Instant shot** (0x4A9455, over `mov [esi+20h],1`, 7 B, before the stock `jmp 4998A0h`). An
   `InstantBallistics` shot leaves the precalculated block there (the `jne` at 0x499801 is the only
   branch to it), in the launch's frame. For a marked shooter with a target unit and a projectile unit,
   the hook selects the action's values and calls FUN_004CEF8C on the impact point `[esp+28h]`, as the
   miss hook does. The instant launch 0x4A958F then copies that point to `[projectile+70h]`, so the
   tracer flies there. The mode stays 1. An offset shot (r > 1e-6, so the two draws ran) is remembered
   by its projectile unit's ID until its arrival.
5. **Applier** (0x49BE95, over `sub esp,1D8h`, 6 B: the head of FUN_0049BE95(projectile, targetId,
   point), which every hit and landing of every projectile calls). A C++ call may rewrite the two
   arguments in place, and the mode, before the stock body runs:
   - a remembered instant shot of a marked shooter (still alive), mode 1: the point `[projectile+70h]`
     inside the target's obstruction (distance 0 by the unit's vtable slot B8h, the engine's own
     distance to an obstruction) is a stock hit. Otherwise, with `<DamageArea>` the mode becomes 3, the
     target −1 and the point a copy of `[projectile+70h]`, so the stock area path damages around that
     point; without, the target becomes the unit at the point, or −1, for which the stock body returns
     at once (no damage);
   - a ground shot (mode 3) of a marked shooter, with no live target and no `<DamageArea>`: the target
     becomes the unit at the landing point (the point argument), if any. The stock body then damages it
     through TakeDamage, as for any hit.

   **The unit at a point:** FUN_004A1C55 (the spatial query `noTrainNearEnemyTC` uses) with a radius of
   0.01 and `precise`, then the units whose obstruction distance to the point is 0; not the shooter or
   the projectile unit, alive (vtable slot A4h), not of proto flag 0Ah `Projectile` (the area damage
   skips those too), and not a Gaia unit of the abstract type `Resource` (trees, mines, hunts, crates).
   Of several, the nearest centre in x and z, then the lowest ID.
6. **Ground shot** (0x4C4DEC, over `mov [esi+20h],3`, 7 B, before the stock `jmp 4998A7h` it continues at). A
   `TargetGround` shot leaves its lead there with no roll, in the launch's frame. For a marked shooter the hook runs the
   miss offset FUN_004CEF8C on the point at `[esp+28h]` with the action's values, as the miss hook does, and leaves the
   mode at 3. Everything is saved around the call. Unmarked shooters take the stock path.
7. **Precalc gate** (0x4997AE, over `test al,al / je 4998A7h`, 8 B: the test of the cfg var `ballisticPrecalcHits`).
   With the var on, or for a marked shooter with it off, the launch goes on into the precalculated block at 0x4997B6;
   any other unit skips the block at 0x4998A7, as in stock.

**What it does not cover.**
- Shots with no target unit: the block is skipped and the flight physics decide. With
  `ballisticPrecalcHits` off, a marked shooter still goes through the block (hook 7).
- A stray shot whose shooter died before it arrived keeps the stock result (the marker is read from the
  live shooter).
- Saved games do not keep the set of offset instant shots in flight: one fired just before a save hits
  its target after the load. The set is cleared on every data load and on another game (the world tick:
  a step count that jumps, or the game time going back).
- `NumberProjectiles` (one projectile per shot, as in stock); dynamic per-player protos that techs
  create (IDs from 100000 up) do not match the base proto's key and keep the stock values.

**Why it is safe.**
- Registers: the hit hook keeps EBX/ESI/EDI/EBP except EBX on purpose. EAX, ECX, EDX and the flags are
  dead at both continuations: 0x499899 stores EBX and overwrites them before reading them (`mov
  ebx,[esp+18h] / mov edi,[esp+0ECh] / mov ecx,[esp+10h] / … / test eax,eax`), and the stub's call
  clobbered them anyway. The C++ calls sit inside `pushad`/`popad`; `popad` keeps the flags the
  hook tests. The miss hook writes the new EBX into `popad`'s slot.
- Stack: the hooks push and pop symmetrically; the miss hook's frame at 0x4CEF7B is the launch's
  (`[esp+18h]`, `[esp+28h]`, `[esp+0E8h]` read as the stock code and the stub read them). Both stub
  entries come from the launch's frame (0x499893 and 0x6A4BCA, the only branches there, `cs`).
- x87: the launch and the stub have an empty x87 stack (each is right after a call). The radius hook
  leaves it empty, as the stock `fcomp` does, and its `TRACE_ONCE` runs after the `fcomp`, so the
  log call never sees a loaded stack. AX is overwritten by `fnstsw` in both versions.
- The overwritten bytes are instruction-aligned and no branch lands inside them; the only branches
  to the sites target their first byte: 0x499893 and 0x6A4BCA → 0x4CEF7B, 0x4E2CFD → 0x4CF00B
  (`rea/evidence/age3y-b1a1dab7/spread_sitecheck.txt`). `SpreadDraws` checks the stock draws the radius
  hook continues into.
- Mode 3 is a stock mode: FUN_0049539B and FUN_0049BE95 handle it for every projectile type
  (`TargetGround` grenades and mortars), and the lead was already computed by FUN_004A5B02 with the
  same fields (`+94h`, `+9Ch`) FUN_004C4DF8 sets for ground shots. In game, arrows of marked units
  landed and damaged with area, and no test run crashed.

**Determinism.** The values come from the data and the marker from the proto, the same on every
machine. The random draws are the stock code's, on the sync RNG, in the same order; a marked shot
draws the same two numbers a stock miss would (or none when r ≤ 1e-6, as in stock). The roll still
runs for marked units, so the RNG stream advances as in stock. A marked instant shot adds those two
draws (stock instant shots draw nothing), on every machine alike. The table is a `std::map` read by key;
the set of offset instant shots is keyed by projectile unit ID (the same on every machine), read by key
and trimmed from its lowest ID past 512 entries. The unit at a point comes from the simulation's own
query and obstruction distance, and ties go to the nearest centre, then the lowest ID, never to an
address or a list order. The log reads the simulation and never writes it.

**Performance.** Per shot through the block: one C++ call with an is-a bit test (hits); per miss, one
`std::map` lookup (about 600 entries with the stock data) and the stock function. The applier hook runs
on every projectile hit or landing of the game: a mode and flag test, then, only for ground shots
without area or remembered instant shots, a unit lookup and the is-a test; the spatial query only for a
marked shot that strays. No allocation per shot. Measured in game (2026-11-08, `perfprobe.py`, 60 s of
four marked Skirmishers shooting nine Mortars): key on 590 fps, world update 0.16 ms per frame, main
thread 76 %, no frame over 50 ms; key off 595 fps, 0.17 ms, 78 %, one frame over 50 ms.

**Why the instant and applier hooks are safe.**
- The instant hook runs in the launch's frame (0x499801 → 0x4A9455 with no push in between), saves every
  register around both calls and leaves through `jmp 4998A0h`, the stock continuation, which writes EDI,
  ECX and EAX before reading them and reads no flag first. FUN_004CEF8C keeps EBX, ESI, EDI and EBP and
  leaves the x87 stack empty.
- The applier hook sits at a function head (no branch lands inside the 6 bytes, `cs` scan); it saves
  every register and only writes the two stack arguments, which belong to the callee (thiscall), and
  the projectile's mode, which the stock body reads next (0x4CB80C) exactly as for a stock ground shot.
- The spatial query writes the obstruction manager's scratch list `[[world+260h]+4ECh]`; the stock
  area path inside the same function runs its own query on that list (0x462E95 → 0x462DBA), so no
  caller of the applier relies on it. The projectile update keeps its in-flight hits in a list of its
  own (`[esp+0B0h]`).
- Mode 3 with target −1 is the stock state of a landing ground shot (0x50B131); a mode-1 shot with no
  live target is the stock state of a shot whose target died (the body returns at 0x4CB80F).
- The instant arrival (0x49C151, state 3 of the projectile) passes the target `[esi+8]` and a zero vector:
  for the area case the hook passes its own copy of the point instead. Sites `SpreadInstantMode`,
  `SpreadInstantLaunch`, `SpreadApplierHead` and `SpreadInstantArrival` check those bytes.
- In game (2026-11-08) every one of 162 logged instant arrivals reached the applier with the very point the
  launch had drawn.

### liveBuildingWorkRate

**The stock mechanism** (BuildingWorkRate).
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

**TrainPoints, the stock mechanism** (`engine-symbols.md`, "Train
points").
- Every queued unit or batch is its own Train action (the train command FUN_009CE2BE creates one per
  queue entry). The enqueue FUN_009EAC35 stores the trained proto's TrainPoints in the action,
  `[action+64h]` = `[playerProto+6Ch]`, once, for its first entry (0x9EB19F..0x9EB1DB). With the
  trainer's flag `YPForceTrainAtBaseTrainPoints` (9Eh) it takes the database's base proto instead.
- The update adds `rate × dt` to the progress `[action+68h]` (in points) and calls the fraction
  function 0x9EA1FA, `[action+6Ch]` = progress / `[action+64h]`; at 1.0 the unit spawns.
- So a TrainPoints tech reaches only the units queued after it, on any building; the unit in
  training and the queued ones keep the old points (measured: a settler queued before the tech and
  started after it still took 25 s).
- `Maintain` is the same at the scale of a cycle: its start (FUN_009E2829) stores
  `[action+6Ch]` = count × TrainPoints (base proto's, not multiplied, with flag 9Eh), and the
  fraction 0x9E27E4 divides `[action+70h]` by it.
- Research is already live: its fraction 0x9E5F19 divides by the tech's `[entry+18h]` on every tick.

**The TrainPoints hooks.** A 9-byte `jmp` (+ 4 NOP) replaces the head of each fraction function,
`fld [ecx+64h] / fcomp [0C3755Ch]` (Train) and `fld [ecx+6Ch] / fcomp [0C37468h]` (Maintain). Each
hook calls `UhcTrainPointsRefresh` / `UhcMaintainPointsRefresh` (stdcall, the action) inside
`pushad` / `popad`, re-executes the two instructions and continues at 0x9EA203 / 0x9E27ED. The C++
computes the points with the stock rule (the trainer's player's proto by 0x45311B; the flag test
0x44D063; the base proto by 0x45316E) and writes them into the action when their bits differ.
Progress stays in points, so a unit with more progress than the new points is done at once, as a
research is in stock.

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
- **The TrainPoints hooks** keep every register (`pushad` / `popad`) and run the stolen `fld` /
  `fcomp` after the call, so the x87 stack and FPU status are the stock ones at the continuation,
  whose `fnstsw` / `test` set the flags again. The x87 stack is empty on entry (each function's only
  caller, 0x9EA4B3 / 0x6AB264, pops its sum first), so the C++ may use it. Both callers rely on
  ECX surviving the call (the Train update's setState call at 0x9EA4CC, the Maintain spawn call at
  0x6AB285); it does. No branch targets the 9 replaced bytes (capstone scan; the one rel8 candidate,
  0x9E278D, is inside `add edi,78h`).
- One `VerifyAll` checks the getter, its four callers, both fraction functions whole, and the four
  pieces of stock code whose rule the C++ repeats (`TrainPointsProto`, `TrainPointsSet`,
  `MaintainPointsProto`, `MaintainPointsSet`, which also pin the three engine calls).
- The points come from the player's proto (or the base proto), simulation state that is the same on
  every machine, and are written into the action, which the game saves as in stock. Per tick it is
  one proto lookup and one flag test per training or `Maintain` action, with no allocation (the log
  table only with `log`).
- `maintainWaitForPop` verifies `MaintainCycleDone`, which holds the Maintain call 0x6AB264: the hook
  is in the callee, so that site stays stock. A cycle it holds at 1.0 can drop below 1.0 when the
  points grow, and then simply runs on.

### hcTargetTechs

A team tech keeps its list of players inside three routines, each with its own copy of the loop over the team:
applyEffects 0x94DAE1 (one caller, 0x94D0AE), removeEffects 0x94DCB2 (six callers) and the pass after a load 0x94DDEA. The
team is the routine's third or fourth argument, from the tech's status bit 13h. Rewriting three lists is more work than
calling each routine once per target, so the key wraps the three: for a marked tech it calls the stock routine for
each target, with the team flag clear. applyEffects goes through its `call`; the other two through a `jmp` at the head, to
a function with the same arguments and `ret`, and an asm stub re-executes the replaced head for the stock call.

The flag name is read by FUN_00620C2F, a chain of string compares called once, at 0x620C23, which ignores what it does not
know. The key reads its two flags through the shared hook on the head of that reader ("Tech flags", below; since
2026-11-23, before that its own hook on the same head), so it still works when another DLL wraps the call, and keeps the
tech's definition, the routines' `this`, in a set. The set is only written during the load, so the game's lookups are lock-free.

The enemies come from 0x484D2D, the check the placement rules use, over the players of the world without Gaia.

- **Observed in game:** see the tests in the modding guide. After a load the log shows one `load` line per tech.

### perCivEffects

`onlyciv="<Civ>"` on any tech `<Effect>` makes that effect work only for a receiving player of that civ.

**Where an effect is made.** Every tech effect comes from one parse, 0x620572, called only by the `<Effect>` tag
handler 0x620472(node, tech definition), which appends the effect to the tech's `[def+24h]`. The parse looks the type
up, calls the factory 0x620535, then setData `[vtbl+4]`; on success it ends at 0x6205EF (`mov eax,esi / pop esi / pop
edi / ret`) with the effect in ESI and its node in EDI, for every effect type (Data, Data2, TechStatus, SetName, ...).
The key replaces those five bytes with a `jmp` to a hook that reads `onlyciv` (0x598F37, then 0x402733 for the narrow
text, as `multiarmor` reads `damagetype`), keeps it in a table effect -> civ name, and re-executes the four
instructions. The tech's ID, for the log, is `[def]`, with `def` at `[esp+18h]` there; the hook reads it only when the
return address `[esp+8]` is 0x6204BB, the handler's. An effect parsed again at the same address without the attribute
loses its entry; the data is parsed once per launch.

**Where it is applied and removed.** A tech's effects reach a player through one dispatcher, 0x7F7E97(effect, player,
unit, techId, a, b), and leave through one removal, 0x7F8168(effect, player, a, b). Their only callers are applyEffects
0x94DAE1 (research, cards, triggers; a team tech calls it once per member), the pass after a load 0x94DDEA, and
removeEffects 0x94DCB2. The player argument is the one that **receives** the effect, so a shared tech, a team tech and
`hcTargetTechs`' targets are each checked on their own. The dispatcher sends the effect to its kind: protos
(protoUnitApply, `[vtbl+24h]`), the player (`[vtbl+1Ch]`, the player Data switch 0x8D842B), the player's tech nodes, or
the general apply. The two heads (`mov eax,fs:[0]`, 6 bytes each) get a `jmp` to a hook that, with an empty table, only
compares a counter with 0 and re-executes the instruction. With entries it asks the table; for a listed effect whose
civ is not the player's first civ (`[[player+20h]]`, `uhc::FirstCivOfPlayer`) it returns 1 without calling the effect,
as the dispatcher does for an effect with nothing to do.

**A civ can change.** The player Data subtype `SetCivilization` (and five other callers of 0x8D53EE) rewrites the first
civ during a game, so the decision taken at an apply is kept per (effect, player ID) and the removal follows it: what
was applied is removed, what was skipped stays skipped. A removal with no apply seen in this session (none in practice:
the pass after a load re-applies first) decides by the civ at that moment. Seen in game: a Spanish player turned German by a test tech with
`SetCivilization`; the game then removed that player's `HuntingDogs` effects, and the hook let through the three
Spanish ones it had applied and held back the German one it had skipped.

**Saved games.** Not saved: the table comes back with the data, and the pass after a load re-runs the ProtoUnit effects
(Data effects carry flag 20h from their constructor) through the dispatcher, where the same filter applies. Player and
tech-level effects are not re-run on a load (the dispatcher returns at `a` = 1), with or without the key.

**Earlier text corrected.** `multiarmor` above says normal techs reach `applyData` through `playerApply` -> 0x8D842B;
that is the path of a Player target. A ProtoUnit target goes through protoUnitApply 0x7F86C0 (trace of 2026-11-27, see
`engine-symbols.md`, "Tech effects: parse, apply, removal and the load"), as `AddTechProtoSubtype` says.

**Why it is safe.**
- The parse hook runs where the stock code returns: it preserves ESI/EDI and sets EAX as stock does; ECX and EDX are
  scratch at a `ret`. The heads are entered by `call` with the arguments on the stack and ECX = the effect; the hook
  saves ECX around its C call and touches nothing else before the stock instruction.
<!-- private:begin -->
- No WoL DLL site is touched: its `uhc.dll` patches 0x6205C9 (the factory call) and the Data effect's vtable slots, and
  its `WoL.dll` patches 0x7F8114, inside the dispatcher after these heads.
<!-- private:end -->
<!-- public:begin
- Hooks above the effect classes: the Data effect's vtable slots, which `multiarmor` and other DLLs replace, are left
  alone.
public:end -->
- `techRenameEffect` verifies 0x6205C7..0x6205F3, so it applies first; `dataLint` writes 0x6205E9 and jumps to
  0x6205EF, which now holds this `jmp`.
- Deterministic: the decision reads only the receiving player and the data; the tables are keyed by pointer but only
  looked up, never walked.
- Cost: one compare per effect applied or removed with no `onlyciv` in the data; a hash lookup under a lock with some.
  Effects are applied when a tech activates, not per frame.

| Site | What it does |
|---|---|
| `0x6205EF` (5 B) | parse success: reads `onlyciv` into the table, then `mov eax,esi / pop esi / pop edi / ret` |
| `0x6204B1` (verify only) | the parse's call in the `<Effect>` handler: the frame the hook reads the tech from |
| `0x7F7E97` (6 B) | apply dispatcher head: skip a listed effect for a player of another civ |
| `0x7F8168` (6 B) | removal head: remove only what the last apply to that player applied |

- **Observed in game:** see the tests in the modding guide.

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

### orPrereqsQty

**The stock OR.** `<Flag>OrPrereqs</Flag>` sets bit 21 of the tech's status bits (the flag setter's case `0x62237E`,
`or byte [esi+2],20h` on `[record+4]`). The per-tech update FUN_005094D8 passes that bit to the prerequisite list
evaluator FUN_005094B4, `bool thiscall(list = def+1Ch, Player*, bool or)`, `ret 8`: it walks `[list]` (length byte
`[list+4]`, null slots skipped) and asks each prerequisite through vtable slot +8 (the thunk `jmp eax` at `0x4C5F02`).
With `or` set, the first prerequisite met returns true (`0x67C412`); with none met, false. Its stock callers are
`0x509537` only; `techPrereqRecheck` calls it too.

**Reading `qty`.** The tech parser FUN_006201E5 makes, for tech ID *i*, the definition `[[loader+4]] + 34h·i` (its
`+0` = *i*) and the status record `[[loader+4]+0Ch] + 24h·i` (its `+0` = the definition), then hands each child node to
the handler of its tag. `<Flag>` is handled by FUN_00620BF1, `cdecl(node, record)`, registered in the tag table by
`mov dword ptr [esp+10h], 620BF1h` at `0x6237E4`. The key writes the address of `UhcOrQtyFlag` over that immediate:
it calls the stock handler, then, when the node has a `qty` attribute and its text is `OrPrereqs`, stores
{definition, N} at the tech's ID. Any other flag, or a value outside 1..255, is logged and left alone.

**The hook.** A `jmp` over the evaluator's first 5 bytes (`push ebx / mov bl,[esp+0Ch]`) leads to
`UhcOrQtyEvalHook`: `TRACE_ONCE`, then `UhcOrQtyEval(list, player, or)`. For `or` set and a tech whose stored
definition is `list − 1Ch` with N ≥ 2, it asks each prerequisite through the same vtable slot, stops at the N-th one
met, and returns 0 or 1; the hook then returns from the evaluator with `ret 8`, as the stock exits do. Otherwise it
returns −1, and the hook restores ECX, re-executes the two stolen instructions and jumps to `0x5094B9`.

**Why it is safe.**
- The evaluator's contract is kept: same arguments, same `ret 8`, the result in AL; EBX, ESI, EDI and EBP are kept
  by the C++ code, and EAX/ECX/EDX are free in a thiscall. Its callers cache the result in bit 3 as before, so
  activation, `Volatile`, the AI's tech list and the UI follow it.
- Each prerequisite is asked through the same slot, with the same player, as stock does; the count only replaces
  "any" by "N".
- An entry is used only when its stored definition is the one being evaluated, so a table from another data load is
  never applied.
- The result depends only on game state (the player's units, techs, age), so every machine computes the same.
- `techPrereqRecheck` verifies the evaluator's stock bytes before this key writes them (it applies first).

### kothTimer

**The stock time.** When a team takes the hill (`ypKingsHill`, proto ID `[db+5F88h]`; the hill's update, 0x4C9BBD,
counts the units around it and, in a King of the Hill game, byte `[0xCF07BD]` = game setting 27h, reaches 0x6A7AEE),
FUN_00948F32 (thiscall on the team) starts the team's timer: `0x9F02DD() − [team+84h]` seconds, the end at now + 1000 ×
that (0x948A1F), and the "KOTHVictoryTimer" panel. FUN_009F02DD reads the victory settings of `DefaultVP.xml`
(`[world+0A8h]`, loaded by 0x9F0B90): `+104h` + (`[world+5Ch]` − 1) × `+108h` when `+108h` > 0, − (`[world+18Ch]` −
`+10Ch`) × `+110h`, with `[world+5Ch]` the player slots (Gaia included) and `[world+18Ch]` the teams (Gaia's too). Its
only caller is 0x948F95.

**The hook.** A `jmp` over its first instruction, `mov eax,[0C66234h]`, leads to `UhcKothTimeHook`: `TRACE_ONCE`,
`UhcKothTime(settings)`. It counts the players 1 .. `[world+5Ch]` − 1 of the world's player array `[world+58h]` and the
distinct teams `[player+10h]` among them, takes the time of the table's entry, logs it with the stock value, and the hook
returns it with `ret`. With no table it returns 80000000h, and the hook restores ECX, re-executes the load and jumps to
0x9F02E2.

**Why it is safe.** The function keeps its contract (thiscall, no arguments, EAX); EAX, ECX and EDX are free. The counts
come from the game's player array, the same on every machine, and the time is an integer as stock's.

### shipmentCounts

**Where a card is sent.** The send FUN_0085A724 (`thiscall(hc, …, cardIndex)`, from the command at 0x7D4C9B) checks the
card (Blockade `[hc+4DCh]`, the card's age against the player's `[player+50h]`, a ship, the cost), pays, and appends an
entry to the home city's shipment queue `[hc+288h]` (count `+28Ch`, entries of 18h: `+0` card index, `+4` tech ID, `+8`
the tech's research points, `+0Ch` progress, `+10h` a cost list) with FUN_00857204, `thiscall(queue, entry*)`, `ret 4`,
the queue's only add (REA `ev_085f3a08…`; the load 0x85E44E fills the queue directly, `ev_530bdbb8…`). A queued card can
be cancelled, by the player or by a Blockade: FUN_0085ADD9 refunds it and removes the entry with FUN_00857257(index, 1),
`thiscall(queue, index, bool shift)`, `ret 8` (`ev_3d75e6c9…`). The queue update FUN_004BF86F advances only entry 0 and
removes it with FUN_00857257(0, 1) once shipped; those are its two callers (`ev_1ddddf42…`).

**Where a card is shipped.** The update's cold part calls FUN_00858299 at `0x66AEA0`, `thiscall(hc, queue entry*)`,
when the first card's transit ends. It checks the player (alive, a KB, no blockade), resolves the drop point, then
activates the card's tech: `call 94CF27h` at `0x8584FF`, `thiscall(entry = EDI, player = [esi+8], unit, 0, &ok,
flags)`, `ret 14h`, with ESI the home city and its argument, the queue entry, at `[esp+24h]` in that frame (`mov
ecx,[esp+24h]` at 0x85856A; `ev_86fde4e0…`). The activation applies the tech's effects there and then, so a card's
`FreeHomeCityUnit` creates its units inside that call. Then the card index is added to the home city's list of used
cards `[hc+260h]` through 0x444FD3, which adds an index only once: a card sent again is not listed twice, so the list
is not a count of shipments.

**The age of the card.** A card counts in its own age, the `<age>` of the card in the home city file (the age that
enables it), not the age it was sent or shipped in, and only once it ships, since a sent card can still be cancelled.
The card is found as the send and the shipment find it: FUN_0085FFCE, `thiscall(list = hc+228h, index)`, `ret 4`,
answers `[list+1Ch] + index × 28h` for an index from 0 to `[list+20h]` − 1, else 0 (capstone; its seven callers, REA
`ev_ebf467d4…`: the queue update, 0x85650A, the shipment FUN_00858299 at 0x85830B, 0x859CFE, 0x85A24D, the send at
0x85A853 and the cancel 0x85ADD9). The send compares the card's `[card+18h]` with `[player+50h]` (0x85A90A: a negative
age, no `<age>`, passes; a higher one is refused with string 8FFCh), so `[card+18h]` has the scale of `kbGetAge`
(cAge1 = 0). None of the four of those callers decompiled (REA `ev_784ac21f…`: 0x85650A, 0x859CFE, 0x85A24D,
0x85ADD9) nor the send writes `[card+18h]`; a writer elsewhere was not searched for (inferred: only the home city's load
sets it). A card with no `<age>` (−1) counts in Age I.

**The count.** The key redirects the activation call to `UhcShipActivateHook`: `TRACE_ONCE`, `UhcShipBegin(entry,
player, hc, queue entry)` notes the player ID, reads the queue entry's card index (`+0`), finds the card with
FUN_0085FFCE (verified as `ShipCardLookup`) and takes its age, and marks a shipment as in progress; then the stock
activation runs with its five arguments as they were pushed, then `UhcShipEnd()` adds one to the count of that player
and card age and clears the mark. The return address is kept in a global while the activation runs, and the hook leaves
with `jmp` to it. The counts are a 16 × 5 table (an age past cAge5 counts in the last). The queue entry is checked to lie
in the player's queue before its card index is read.

Until 2026-11-21 a card counted in the age it was sent in, which took two more hooks (the heads of the queue's add
0x857204 and removal 0x857257) to note each queued card's send age; both are gone.

**Saved games.** The counts live in the DLL, so they are written into the game as saved markers (`savedmarkers.h`, stat
67h): stat modifiers that no code reads, whose save and load copy four dwords. Per player with anything to keep, one
marker holds the five counts (16 bits each, word 0 `'SC' << 16 | player << 8 | 1`). All of them sit on one unit, the
carrier: the first living unit of a player (then of anyone) that takes a marker. A world tick (`AddWorldTick`) rewrites
them after a change and moves them when the carrier is gone, dead, or lost its markers (a transform in place ends a
unit's modifiers); old markers are freed. So at a save, which happens between world updates, the markers are on a living
unit. A save of an older build may also hold a marker `| 2` (the send ages of the queued cards): it is ignored, and the
next write drops it.

A game is told apart as `researchGrants` does: the world `[game+13Ch]`, its time `[world+108h]` not going back and its
step `[world+F8h]` advancing by at most one. A new or loaded game (seen by the tick, or by a hook or a syscall that runs
first) rebuilds the table in one walk over the units, from the count markers.

**The tech subtype.** `FreeHomeCityUnitByShipmentCount` is a Data subtype on a Player target, which the shared tech
subtype code did not have: stock applies a Player target through 0x7F874A, which pushes the effect's fields and calls the
player Data apply FUN_008D842B, `thiscall(player, a1, a2, subtype, [effect+10h], [effect+14h], amount, relativity)`,
`ret 1Ch`, a switch on `subtype − 0Ah` (`cmp eax,5Ah / ja 8D878Fh`, the jump tables 0x8D93D8 and 0x8D9330).
`techsubtypes.*` gained `AddTechPlayerSubtype`: the `ja` at `0x8D843E` jumps to `UhcTechPlayerSubtypeHook`, which sends
a stock ID back to the table (`0x8D8444`), and an ID from 100h to the key's handler with the player and the addresses of
the field `[esp+2Ch]` and the amount `[esp+34h]`. The handler returns done (AL = 1, the exit `0x8D8D23`), failed
(`0x8D878F`), or the ID of a stock case to run with the arguments it rewrote.

While the techs are read, the subtype's name lookup (the shared head 0x61FF5D) calls the key's parser with the effect
and its node: `unittype` must name a proto (an ID below the first abstract type, `[db+19B0h]`), `age` one digit 0 to 4
(Age I to V, the scale of a card's `<age>`) or two digits `NM` for the ages N to M, N <= M (`13`: Ages II to IV; since
2026-11-22, #76: before, 1 to 5 and `N-M`, now refused), and `includeself` true or 1. They are packed into the
effect's field `+10h`: the proto ID in the low 24 bits, the first age + 1 in bits 24-26 (0: every age),
`includeself` in bit 28, the last age + 1 in bits 29-31. A bad one drops the effect
(the lookup answers −1, as for a name nobody knows). When the effect applies, the handler adds the counts of those ages
(or of every age), adds one when `includeself` is set and the effect runs inside the activation of a shipment of the
same player whose card's age is in the range, writes the proto ID into the field and `amount × count` into the amount,
and answers 37h: the stock `FreeHomeCityUnit` case (0x8D8C62) then creates the units at the home city gather point
through 0x857E77, with its checks. A count of zero answers done, and nothing is created.

**The syscalls.** `xsGetShipmentCount(int playerID, int age)` and `xsGetShipmentCountRange(int playerID, int firstAge,
int lastAge)` in the XS group (every script: the AI, triggers), through `AddSyscall`: the same table, -1 for every age,
0 for an age or range out of bounds.

**Why it is safe.**
- The activation gets the same `this`, the same five arguments and the same return address; EAX, its result, is kept,
  and the code at 0x858504 reloads ECX from EDI, which the C code keeps. Only one card ships at a time, and the
  activation never ships another, so one global return address is enough.
- `ShipEntryArg` verifies the frame the hook reads the queue entry from, and `ShipCardLookup` the bytes of the card
  lookup the C code calls; the card is read, never written.
- The player switch hook re-executes the stolen `ja` with the flags of the stock `cmp`, so every stock subtype runs as
  before; the success and failure exits are the stock ones, with the stack as the cases leave it.
- The counts read only simulation events (shipments) and data (the cards' ages), the same on every machine; the table is
  ordered by player ID and age, and the carrier is picked in unit order, so the markers are the same on every machine.
- A marker is a modifier of a stat no code reads; a game loaded without the key ignores it.

### ageFiveShipments

`src/features/agefiveshipments.cpp`, `hooks/agefive_hooks.asm`.

**Stock (#83, 2026-11-21).** A card's `<age>` is read by the home city card loader (FUN_0062E6C9; the `Age` tag,
string 0xBA38C0, handled at 0x66B6FC) and kept as `[card+18h]`, from 0 (Age I) up; nothing caps it there. Three places
stop at four ages (REA `ev_4c5c5b11…`, `ev_cb7f901b…`; capstone):
- the game's card list of a player, `hc+228h` (the list FUN_0085FFCE indexes), is built from the chosen deck by
  FUN_006301DE (callers 0x62FA64, 0x857BF1, 0x857C8E, 0x857D6E, 0x85A63E): one pass over the home city's cards per age,
  keeping those of the deck, so the list is in age order; the passes end after age 3 (`cmp eax,4` at 0x63022E). A card
  of age 4 (or with no `<age>`, −1) never reaches the game: in a test a deck of 25 with one such card played with 23
  cards;
- the in-game shipment panel, the gadget type `homeCityCardPanel` (`uihomecitycommandpanel.xml`), fills its buttons in
  FUN_009A5658: a card of age below 0 or above 3 is skipped (0x9A5A25..0x9A5A30), the others go to row = age, column =
  their rank in that age (at most 11, counted in `[panel+4D0h + 4 × age]`). Its gadgets are looked up once
  (FUN_009A4E50, rows below 4, columns below 11; capstone, 2026-11-22) into four arrays of 44 slots, slot = row × 11 +
  column: `+140h` the buttons `homeCityCardPanel-button<row><column>`, `+2A0h` `shipCostOverlay-button%d%d`, `+354h`
  `shipmentsLeftOverlay-button%d%d`, `+40Ch` `resourceCostOverlay-button%d%d` (the init loop writes them at
  `[ebx-160h]`, `[ebx]`, `[ebx+B4h]` and `[ebx+16Ch]` with EBX stepping 4 from `+2A0h`). A fifth array of 44, `+1F0h`,
  holds no gadget: the fill sets it to −1 (`rep stosd`, 2Ch dwords) and writes each placed card's link there
  (0x9A5AD2, the value of 0x58EA03 for the card's tech). The per-age counts are at `+4D0h..+4DCh`, the init flag at
  `+4F4h`. (Until 2026-11-22 this page listed `+140h`, `+2A0h`, `+354h`, `+40Ch` as four button arrays packed one
  after another; `engine-symbols.md`'s five offsets were the right ones, `+1F0h` being the link array.) Once the row
  and column are known the fill computes the slot (0x9A5A84..0x9A5A8D), takes that slot's button, writes the link,
  hands the button the card (vtable `+104h` at 0x9A5D99 with the tech's `+14h`; inferred from the arguments) and calls
  FUN_009A5205(row, column, card), which sets the three overlays of the same slot; its only caller is the fill.
  Before any card it hides the 44 buttons and their overlays (0x9A56A0..0x9A5757);
- the deck builder of the home city screen ("Build a Deck", `uihcdeckbuilder.xml`, buttons `hcDeck-button<row><column>`)
  fills its rows the same way at 0x9A0489 and stops at the first card whose age is 4 or more (0x9A04A7); in a test the
  Age V card of a 25-card deck was missing from its Age IV row while the counter read 25/25. Its buttons are at
  `+178h` (44, slot = row × 11 + column), its card links at `+228h` (reset to −1 at 0x9A0350, written at 0x9A04F6), and
  it hides every button and overlay before the fill (0x9A028C..0x9A0343). A click on one of its deck cards (the card
  leaves the deck) finds the slot of the clicked button in `+178h` and reads the card from `+228h` at that slot
  (FUN_009A003F, 0x9A0074..0x9A0099);
- the `homeCityDeck` dialog (`uihomecitydeck.xml`, loaded at 0x9A737B, FUN_009A7670) has the same fill (0x9A77BE,
  stop at 0x9A77DC; buttons at `+154h`, hidden first at 0x9A76AC..0x9A76EB); it did not open in the tests (inferred:
  another deck dialog of the same screen).

The panel greys a card whose age is above the player's (`[card+18h]` against `[player+50h]`; its disabled reason is 8FA6h, and the rollover says *This Card cannot be sent until Age %d*, 9012h),
and the send FUN_0085A724 refuses it (0x85A90A, string 8FFCh); neither stops at 3.

**What the key does.** The immediate of `cmp eax,4` at 0x63022E becomes 5 (`CardListAgePasses`), so the game's list
takes the cards of age 4 too, after those of age 3. The three fills get a 5-byte `jmp` over `mov eax,[esi+18h]` and the
`cmp` after it (`CardPanelAgeRow` 0x9A5A22, `DeckBuilderAgeRow` 0x9A0489, `DeckEditorAgeRow` 0x9A77BE): the hook reads
the card's age, turns 4 into 3, re-runs the `cmp` and jumps back (0x9A5A27, 0x9A048E, 0x9A77C3). So an Age V card sits in
the Age IV row while `[card+18h]` stays 4: greyed with its reason until the Imperial Age, refused by the send before it,
and counted in Age V by `shipmentCounts`.

**Age V at the right (#83, 2026-11-22).** JTMaston asked for the Age V cards in a line at the right of that row, the
Age IV cards staying at the left. Each fill gets a second jump once the card's row and column are set and before the
slot is computed: `CardPanelColumn` 0x9A5A7C (8 bytes, `mov ecx,[esp+28h]` / `mov edx,[esp+14h]`), `DeckBuilderColumn`
0x9A04B0 (8 bytes, `mov edx,[esp+14h]` / `mov eax,[esp+28h]`), `DeckEditorColumn` 0x9A77E5 (7 bytes, `mov ecx,[esp+30h]`
/ `lea eax,[ebx+ebx*2]`). The hook passes the card list (panel `[esp+2Ch]`, the others EBP), the card (ESI) and the
column (panel and builder `[esp+28h]` / `[esp+14h]`, editor `[esp+1Ch]`) to `UhcAgeFiveColumn`, which, when the list
holds an Age V card, counts the list's Age IV and Age V cards (`[list+1Ch]`, entries of 28h, `[list+20h]` of them) and
returns: for an Age V card 11 − (Age V cards) + its rank among them; for an Age IV card its rank among the Age IV
cards, or −1 when that column belongs to the Age V cards. With no Age V card the stock column is kept. The hook writes
the column back to the fill's variable, re-runs the replaced instructions and continues (0x9A5A84, 0x9A04B8,
0x9A77EC); −1 goes to the fill's "next card" (0x9A620B, 0x9A076C, 0x9A7A73, where a twelfth card of a row goes), and the
panel's per-row count `[panel+4D0h+4×row]`, which the fill raised before the hook, is lowered again, so the Age V cards
that come after are not cut by the panel's cap of 11. The column then goes everywhere the fill uses it: the slot of
the button, of the link (`+1F0h` / `+228h`) and of the overlays (FUN_009A5205), and the button's own command. The
column counter the fill raises after each card placed (0x9A61F9, 0x9A0756) only matters to the stock check of a
twelfth card, which still holds. A log line gives the layout once per change of the two counts.

Overflow: when the Age IV and Age V cards together are more than 11, the Age V cards keep the last columns and the
last Age IV cards are not shown (logged), instead of the Age V cards being cut as a twelfth card is. More than 11 Age V
cards: the first 11 are shown.

**Why not a fifth row.** The row index is the card's age, and each panel object holds exactly 4 × 11 buttons in arrays
that touch each other (the deck builder's at `+178h`); the card inventory's "By Age" view has four tabs too; a fifth row would need a larger gadget object and every reader of those arrays (the fill, the
click and rollover handlers, the refresh at 0x9A5205) moved to new storage, plus 11 more named buttons in the layout.
That is a reimplementation of both gadgets, not a patch.

**Why it is safe.** The row hooks keep every register but EAX, which the replaced `mov` loads anyway, and re-run the
replaced `cmp` for the branch after it. The column hooks save every register around the call (`pushad`/`popad`); the
result goes to EAX, which the code after each continuation overwrites (`lea eax`, `mov eax`), and the replaced
instructions are re-run with the new column; the flags are not read after them. A card keeps one slot for its
button, its link and its overlays, since the fill computes all three from the column the hook returns, so a click,
a rollover or a send reaches the card shown (tested: rollovers of every Age IV row card, sends from the right-aligned
slots, removal from the deck builder). The slots between the two groups stay hidden: the fill hides all 44 buttons
and their overlays and resets the links before it places a card. The counts are read from the same list the fill
walks, so they cannot disagree with it. Not in the hot path: the fills run when a panel is opened or changes, and the
count is one pass over the list (25 cards in the decks tested) per card of the Age IV row.

### resendableCards

`src/features/resendcards.cpp`, `hooks/resendcards_hooks.asm`; the tag through the shared card tag hook (`cardtags.*`).

**Stock (#97, 2026-11-23; REA `ev_d08f643f…`, `ev_8b93b70f…`, `ev_d2f7d77e…`; capstone).** A player's card list
`hc+228h` holds copies (28h B) of the home city's cards, made by FUN_006301DE from the deck, each with its sends left in
`[card+20h]`, set to `<maxcount>` `[card+4]` when the list is built. The send FUN_0085A724 refuses a card with a
`<maxcount>` of 0 or more and no sends left (0x85A9B9, *You have already sent %s*, 8FFDh) and takes one with
FUN_0085FBEA(card, −1) at 0x85ACF8 (`+20h` += delta, clamped to 0 .. `+4`); a cancel gives it back (+1, 0x85AE98). The
in-game panel greys such a card (0x9A5AFC). The card's tech has the HomeCity flag, which the tech activation 0x94CF27
never refuses as already active, so a card sent again runs its effects again. `<infiniteinlastage>` is the byte
`[card+24h]`: when the age setter FUN_008D4E01 sets an age above 3, it calls FUN_0085650A(hc) (0x8D5053), which sets
`+20h` = `+4` for each card whose byte is 1. So the stock feature is one refill of the card when the player reaches the
Imperial Age, not unlimited sends. The field and the byte are in the saved game (the card's save 0x85FC40 and load
0x8607C5).

**The tag.** `<resendeveryage>` reaches the key through `AddCardTagHandler` (below, "Card tags"), once the card is in the
home city's array: `1` or `true` sets bit 1 (02h) of the card's byte `+24h`, `0` or `false` clears it, anything else is
logged. The deck build (10 dwords), the save and the load copy the byte whole, so every copy of the card carries the
bit, in every player's list and in saved games, with no state in the DLL.

**The reset.** A 5-byte `jmp` over `mov eax,[0C66234h]` at 0x8D502F, the join of the age setter after the new age is
written: `UhcResendAgeUp(player = ESI, flag = byte [esp+13h])`, then the replaced load and `jmp 0x8D5034`. The setter's
flag is 1 when the old age was the same or higher; on an advance, each card of the player's list (`[hc+244h]`, count
`[hc+248h]`) with the bit, a `<maxcount>` of 0 or more and fewer sends than its `<maxcount>` gets `+20h` = `+4`. One
reset per age-up, never added: an age with no send does not stack (sent in Age II, not in Age III: one send in Age IV).
An `<infiniteinlastage>` card with the bit is refilled the same way when the Imperial Age comes, before the stock refill,
whose `== 1` no longer matches it.

**The rollover's cost.** The card rollover builder hides the card's cost line once its tech has been researched (the
research count against `ResearchLimit`), unless the card is `<infiniteinlastage>` in age 4 with sends left. A 6-byte
`jmp` over `cmp dword ptr [eax+50h],4 / jne 710863h` at 0x710804 (EAX = the player, EBP = the card, reached only when the
byte `+24h` is not 0) keeps age 4 as stock and lets a card with the bit go on to the sends-left test (0x71080A) in any
age; any other card goes to 0x710863 as stock. A card that costs only one shipment shows no cost line, so for such a card
this changes nothing visible.

**Why it is safe.**
- The join is reached on every path once the age is written (0x8D4F49, 0x8D4F54, 0x8D4F5F and the fall-through after
  the age-up message, no push outstanding); EAX, ECX and EDX are written there before they are read; the stdcall keeps
  EBX, ESI, EDI and EBP. The setter's early return (nothing changed) does not reach it.
- The reset writes only `+20h` of cards in the player's own list, as the stock refill and the cancel do, within
  0 .. `<maxcount>`; the send, the panel, the AI (whose card checks read the same list) and the save see the same field.
- Simulation: the age setter runs in the simulation (a tech effect, a trigger), the cards are the same on every machine,
  and nothing depends on the local player. `CardRolloverAgeCheck` is display only.
- The bit: no reader of the byte `+24h` other than the stock refill (`== 1`) and the rollover (`!= 0`) was found near
  the card lookups (capstone over the callers of 0x85FFCE, 0x85FFEC, 0x8563EA and 0x860020). A save made with the key
  and loaded without it keeps the bit: the cards are then neither reset each age nor refilled at the Imperial Age when
  they also have `<infiniteinlastage>`.

### quickArrivalCards

`src/features/quickarrival.cpp`, `hooks/quickarrival_hooks.asm`; the flag through the shared flag hook (`techflags.*`).

**Stock (#99, 2026-11-23; REA `ev_8b93b70f…`).** The rollover of a home city card is built by FUN_007103CE(out, hc,
tech, …, list, pop) for the in-game shipment panel (0x9A61B7), "Build a Deck" (0x9A0714) and the deck dialog
(0x9A7A1E), all in list mode. Its lines: the name, the population, the unit's text when the tech has no rollover text,
*cannot be sent until Age N* (9012h), the cost, the tech's rollover text, the send limit (9001h / 9002h / 9003h), then,
with the detailed help option on, the advanced info FUN_0071006D. Each line is added by FUN_004C5076(out, line, 1, 0),
which appends `<ttf><ttb>` (a bullet) and the line.

**The card tree (2026-11-26; REA `ev_e6e27ab5…`, `ev_ce27eca8…`, `ev_6d9b0cca…`, `ev_4fdc4c46…`, `ev_c32aac08…`).** The
home city's card tree ("View All Cards", and the inventory pane under the deck in "Build a Deck") does not call that
builder: its button setup FUN_009A21A0 (`uihcskilltree.cpp`) calls a second one, FUN_00710991(out, hc, tech, 1, 0,
list = 1), its only caller. The push of 9001h / 9003h appears only in these two functions. Its lines: the name, *This
Card can be sent in Age N* (901Eh, cyan) and the level and age lines 901Bh / B7CFh / 901Ch where they apply, then the
cost, the tech's rollover text and the send limit (9001h / 9002h / 9003h), each through FUN_004C5076 in list mode, then
the same advanced info FUN_0071006D at the join 0x710F24. The report of 2026-11-26 (no line in "View All Cards")
came from this second builder, which the first version of the key did not hook.

**The flag.** `<Flag>QuickArrival</Flag>` reaches the key through `AddTechFlagHandler` (below, "Tech flags"): it keeps
the tech's ID (`[[record]+0]`) in a table and takes the flag, which stock would ignore.

**The line.** A 6-byte `jmp` over `mov ecx,[0D6F6F0h]` at 0x710909, the join before the advanced info (reached from
0x7108C3, 0x7108DB and the fall-through after the send-limit line, no push outstanding):
`UhcQuickArrivalLine(out = [esp+44h], tech = [esp+4Ch], list = [esp+58h])`, then the replaced load and `jmp 0x71090F`.
For a flagged tech it appends `<ttf><ttb>` and the text with the BString append 0x443960, as FUN_004C5076 does (a `\n`
instead of the bullet in string mode). The text is *This is a QUICK-ARRIVAL card.*, or string N of the string table
with `stringid N` (read at each rollover, so a language change follows; an empty string falls back to the English).
So the line comes right after the send-limit line: after *This Card may be sent INFINITE times* for an infinite card,
and between the card's rollover text (and its send limit) and the advanced info for the others.

The card tree gets the same line from a second 6-byte `jmp` over `mov ecx,[0D6F6F0h]` at 0x710F24 in FUN_00710991
(frame: `sub esp,28h` and four pushes; reached from 0x710EDE, 0x710EF6 and the fall-through after the send-limit line,
no push outstanding): `UhcQuickArrivalTreeHook` calls the same `UhcQuickArrivalLine(out = [esp+3Ch], tech = [esp+44h],
list = [esp+50h])`, then the replaced load and `jmp 0x710F2A`. The builder overwrites its `hc` slot `[esp+40h]` with
the card entry at 0x7109D6 but never the tech slot.

**Why it is safe.** Display only. The stdcall keeps EBX, ESI, EDI and EBP; ECX is reloaded by the replaced instruction,
EDX at 0x71090F and EAX by the call at 0x710917 (in the card tree: EDX at 0x710F2A, EAX by the call at 0x710F32; ESI,
the card entry, and EBP, the output, are arguments of the advanced info at 0x710F3C and are kept).
`CardRolloverHead` and `CardTreeRolloverHead` verify the builders' frames (the offsets of their arguments, and in the
second the write of 0x7109D6), `CardBulletLine` the bullet helper the key copies. No other key patches FUN_00710991.

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

### accuracyTechs

Stock's `TrackRating` (Data subtype 26h, 0x8FAA45) shows the shape of an effect on an action: `[proto+44h]` is the action
set, 0x48D22E finds the action by the ID in `[effect+10h]`, and the base proto's set gives the base value. Accuracy is the
action's `+38h`, the same object: a tech on one proto reached neither another proto that uses the same tactics file nor
another player.

`techsubtypes.*` gained `AddTechActionSubtype`. setData reads the `action` attribute only for the subtypes it knows, so
the lookup's hook does it, for a subtype on actions, with the effect and the node the attribute read at 0x6206B2 kept.
`allactions` needs nothing: setData has already set bit 40h of `[effect+9]`, and protoUnitApply passes it as
applyData's 8th argument. With it the key's handler runs for every action in the set, `[set+1Ch]`, count `[set+20h]`.

- **Observed in game:** see the tests in the modding guide.

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

**More projectiles than muzzles (2026-11-21).** [O] An ability's volley (a power whose `<unitaction>` is a
`BroadsideAttack`, such as a mod's long-range bombardment) is one pass of the fire step: FUN_004C1290 fires each due slot of the
facing side once, and for an action whose launch object `[ua+94h]` has the power bit (byte `[[obj+2Ch]]` & 4, `[obj+30h]`
≥ 3) it ends the action with setState(0Ah) instead of scheduling another volley (0x4CEE48), REA `ev_695172b8…`. The
schedule gives each right slot a time `now` (+1000 ms for such an action) plus a sync-RNG step of 0.25 to 1.75 ×
`[ua+84h]`, and slot i + n1 the same time (`ev_cb848273…`). So a volley has one projectile per slot, at most the model's
muzzles per side; `<numberprojectiles>` is no tag of the exe. The key reads `<NumberProjectiles>` (and
`<NumberOfProjectiles>`) through the shared action tag hook, per `{proto ID, action name index}`, cleared on every data
load, and replaces BroadsideAttack's vtable slot 1 (0xB962EC, the only reference to 0x50339A) with a wrapper: the stock
set-up, then, for an action of a ship the key applies to (every ship, or its type through 0x44D7FA, as the limit hook
decides) whose side has fewer slots than P, it resizes
both arrays with their own resize 0x401113 to P per side, writes the muzzle indices in turn (slot i of a side = the
side's stock slot i mod its count) and zero times, and sets `[ua+80h]` to P. The left side is capped at the right
side's count, which is what the schedule can time.

**Why it is safe.**
- The arrays have no other bound: save and load write each count and resize on load, the fire step
  walks the count, and the muzzle index is read as a byte, which caps N at 255. A larger N needs
  no save-format change. The extra slots name muzzles the model has, so the muzzle lookup 0x4A98C2 succeeds for each.
- Nothing else reads the hardcoded 6.
- The limit depends only on the cfg and the owner proto's unit types, decided once per action
  set-up. It adds projectiles (each with its accuracy roll) and sync-RNG draws, so every machine
  needs the same cfg.

### broadsideSoundSet

**Stock.** The broadside fire step (FUN_004C1290's step, the action type `BroadsideAttack`) calls FUN_004CEB37 at 0x4CEA02,
its only caller (an `E8` scan of `.text`), just before each launch `call 499422h` (0x4CEA43). FUN_004CEB37,
`thiscall(unitAction, ...)`, `ret 14h`, with EDI = the unit action and `[edi+10h]` the unit (checked at its head): it
places the muzzle effect `L"NavelCannon"` (0xBA1D6C) through 0x4828E6 on `[[0C66240h]+0C1A0h]`, then at 0x4CECAF..0x4CECC6
loads EDX = the unit, pushes a local, loads ECX = the game `[0C66234h]`, pushes `0BA1D5Ch` (`"ShipCannonShoot"`), adds 14h to
EDX (the unit's position) and pushes it, and calls 0x4AA24C, the play of a sound set by name. 0xBA1D5C is pushed nowhere
else (an `imm32` scan), so every broadside shot of every ship plays that set. An action of type `Attack` plays its shot
sound from its animation's `SpecificSoundSet` tags.

**The hook** (`hooks/broadsidesound_hooks.asm`) replaces the 5-byte push at 0x4CECBD with a jmp: it saves ECX and EDX, calls
`UhcBroadsideSoundName(EDI)`, restores them, pushes the returned name and goes on at 0x4CECC2 (`add edx,14h`). The name is
the action's `<BroadsideSoundSet>` (the shared action tag hook, keyed by `{[[ua+10h]+5Ch]+4, [[ua+4]+4]}`, the proto ID and
the action's name index, which every player's copy keeps), or the stock pointer. The first shot of each tagged action checks
the name as 0x597C56 looks a set up: the manager `[game+950h]`, its table `[+4]`, a `BString` of the name (0x401ECA,
`thiscall(this, const char*)`, `ret 4`; freed by 0x4010CA) and 0x468E7D (`thiscall(table, const BString*)`, `ret 4`: the set,
or 0). A name the table lacks is logged once and its shots push the stock name.

**Why it is safe.** No branch lands in 0x4CECBE..0x4CECC1 (scan). At 0x4CECBD EAX is dead (written by the call before it is
read), no x87 value is live (the angle was stored at 0x4CEC0D, the coordinates at 0x4CEBFF), and ECX and EDX are restored;
EBX, ESI and EDI are callee-saved in the C function. The names are `std::string`s that only change during a data load. The
hook chooses a sound only: nothing in the simulation reads it.

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

### displayedRange

The ring is a model of the table the tactics parser fills: 0x58F68F gives the ID of `effects\uhc_rings\range_<N>.xml`, as
0x5FC91C does for `<ModelAttachment>`, and 0x58E506 the ID of the bone `bonethatdoesntexist`, as 0x5FC8EE does, which puts
it at the unit's feet. A world tick, ten times a second of game time, compares the selection of 0x453B28 and the Alt state
with the units that hold rings, and hangs or removes them through the functions of the stock aura update.

**Ring size:** a range ring is a mesh since 2026-11-22, its outer edge at N in `range_<N>.gr2`'s own vertices. The game
takes a model's vertices as metres and does not apply the file's `UnitsPerMeter`: until 2026-11-24 the files were written
in the stock basis (0.615 units a metre), and every ring showed 0.615 of its radius (in game, the 26 m ring passed a Settler
16 m from the Fort's centre, the 55 m ring passed between Settlers 32 and 34 m out). They are now written with one unit a
metre: the 17, 31 and 35 m rings pass between Settlers at 16 and 18, 30 and 32, 34 and 36 m. Before, with the white particle rings (`make_rings.py --range-particles`), the model's flat particle is drawn `<scale>` metres wide in all, not twice that: `range_<N>.particle` has
a scale of 2 × N / 0.97, the texture's line ending at 0.97 of its half width (measured in game, 2026-11-21: with the
half width as the scale every ring showed half its radius).

**Alt** is the game's own query, the one the HP bar chunk makes at 0x452EA0..0x452EB3: `[[[0C66244h]+74h]+2Ch]`, its vtable
+34h with 2 (0 is Shift, 1 Ctrl). A posted `WM_KEYDOWN` of `VK_MENU` sets it, so a copy in the background can be tested.

**The radii** come from the unit's current tactic, `[[unit+58h]+0A8h]`, an index into the tactics `[[proto+44h]+10h]` of the
player's proto: its action entries are 12 bytes at `[tactic+44h]` (count `+48h`), `+4` the index of the action in
`[[tactic]+1Ch]`, as the attack list 0x487EEE reads them. An action counts when bit 0 (active) and bit 0Ah (`<RangedLogic>`,
set by its handler 0x5FAC6D) of `[action+64h]` are set; its range is 0x4946D6(action, −1), the entry the stat panel shows. The
player's copy is read every tick, so a range tech shows at once. A tactic with no ranged attack (a cannon limbered to move)
takes the ranged attacks of all the unit's tactics. Each radius goes to the nearest ring size (every metre from 4 to 50,
then 55, 60, 65, 70, 80, 90, 100); equal sizes share a ring; at most 4 rings a unit, the largest first, and 60 models in
all (`kMaxRings`; a filled ring is two models, its line and its fill), the units with the longest ranges first.

**Where the ring goes (2026-11-24).** `MaxRange` is not measured from the unit's centre. The action's range test
(0x48B6AA..0x48B779; the function is referenced from the table at 0xB97D94) compares the unit distance (unit vtable `+0BCh`,
which calls `+0B4h`, 0x487B81, with the target) with the action's `[action+24h]`. That distance depends on who can move
(0x45EE55: not when bit 4 of the proto's first flag byte is set, else when `[proto+80h]` is above 1e-6):
- both move (0x4889AF): the centre distance minus each one's radius × √2, the radius being the larger of the proto's
  obstruction radii `[proto+88h]` / `[proto+8Ch]` (0x48272C, ×√2 at 0x488A06 with the constant 0xBA1384);
- a building on a unit (0x4945FE): the distance from the unit's centre to the building's obstruction rectangle (0x485E26,
  0 inside), minus the unit's radius × √2 (0x494666);
- a unit on a building (0x4882FE): its centre to the building's rectangle, minus its own radius × √2.

So the key draws each ring where an infantry unit's centre (radius 0.49 m, the Musketeer's, the Settler's) comes into
range: `MaxRange` + 0.69 m, plus 0.69 m more for an infantry attacker (its own radius × √2), or the half side of a
building's rectangle (the smaller one, so the ring stays inside the zone on every side). An attack that reaches only
structures (below) goes to their wall, with no target radius. Measured in game (2026-11-24, a mod's Fort, `MaxRange` 26 and
a 12 × 12 m rectangle, Settlers of 5 HP created on the 2 m grid so that one shot kills, the two players turned enemies by
a trigger after the units stood): Settlers whose centre was 26.08, 26.31 and 26.68 m from the rectangle were shot, 26.83,
26.9 and 27.2 m were not. The limit is 26 + 0.69. Their centres were up to 34.4 m from the Fort's: the old ring, meant to be 26 m from
the centre, was 6.7 m short (and drawn at 16 m: "Ring size" above). A first scene with the Outpost (`MaxRange` 24, 4 × 4 m) and the Blockhouse (24, 8 × 8 m)
agreed: shot at 23.6 and 21.3 m from the rectangle less 0.69, not at 24.9 and 26.0. The zone is the rectangle grown by that
reach, so past a corner it goes further than the circle: (√2 − 1) × the half side, 2.5 m for the Fort, 0.8 m for the
Outpost.

**Line of sight is separate.** A building only shoots at what its player sees, and sight is measured from the centre, on
a grid. With the Fort's own `LOS` of 26 (no age tech) it shot Settlers 24 and 26 m from its centre along its sides and
none at 25.5 m on a diagonal or at 26.9 to 30 m, though all were in range; with `LOS` 50 in the test data it shot every
one in range. The age techs `Colonialize` (+7) and `Fortressize` (+4) give buildings 37 m and more.

**The placement ghost.** The shared ghost update (`ghostobservers.*`: the jump at 0x96E4E7 in FUN_0096E062, before the
ghost's placement test, `AddGhostObserver`; `annexFacing` turns the ghost there too) runs each frame of a placement, the
game paused too. The ghost object `[[0xC67300]+200h]` holds the transform (`+4` position, `+10h` forward, `+28h` right,
`+7Dh` changed) and draws the model `[ghost+34h]`: an object of the class of a unit's visual `[unit+60h]`. Seen in game,
both start with the same word, and the ghost's code calls three of that class's functions on `[ghost+34h]` (0x40431B,
0xA3FEF8, 0xADA24B, each also called on `[unit+60h]`). The stock model functions 0x9C04F3, 0x9C28DE and 0x9C2885 read nothing
of their unit but `[unit+60h]`, so `unitmodels.cpp` runs them on a stand-in block whose `+60h` is `[ghost+34h]`. The rings
are the proto's (`[ui+1FCh]`, the local player's copy through 0x45311B, its `<DisplayedRange>` or the ranged attacks of
all its tactics) and are worked out once per proto; each frame only checks that the model still has them. A new proto
takes the old rings off first; a new model object means the old one went with its rings. When the placement ends, the
ghost's model goes, rings included (tested: Escape, a placed Outpost, `uiSetProtoCursorID(-1)`).

**The options menu (2026-11-25).** With `menuOptions displayedRange` the key is a live switch of the options menu
([menuOptions](#menuoptions)): it applies whatever the choice, asks it once (`FollowMenuSwitch`) and is told each new
one on Apply. The observer sets `g_enabled` only. The tick reads it after its world check: off, it takes the models of
`g_hung` off their units and clears it, and returns; on, it goes on as before, within 100 ms of game time. The ghost
update reads it first: off, it takes its models off the ghost's model (when it is still the one they were hung on) and
forgets the ghost, so turned on again the rings are worked out anew. Tested in a match: the Fort's rings went and came
back with the game resumed, and an Outpost's ghost lost and got its rings with the placement still going on.

**Player colour.** A particle's colour fields are `UsePalette`, `NumPaletteColors`, `PaletteColors`, `ColorStages`,
`fWorldLightingInfluence` and the fixed `Color` (the exe's particle tag names, 0xBA41D0): nothing takes the owner's
colour. So a range ring is a mesh (aoe3-blender-tools' `make_rings.py`): a flat annulus whose cut-out is the geometry,
on an alpha-1 texture with the units' shader `bumpspec_mask_pixelxform` (`pixelxformColor = playerColor`). Its texels of
alpha 0 take the colour of the player of the visual the model hangs on: measured 2026-11-22 with a half-and-half test
texture, blue on player 1's Skirmisher, red on player 2's Outpost, and the local player's blue on a placement ghost. The
key needs nothing for it.

**The look (2026-11-23).** The game's selection decal (`shadows_selections\selection_circle_64x64.ddt`) is a white line,
2 texels of a 32-texel half width, alpha 255 on the line and 0 elsewhere, which the game draws flat in the owner's
colour: about (48, 44, 213) for player 1's (45, 45, 245), 3 to 4 px wide at the default zoom. The range ring now matches
it: `range_line.ddt` is white with alpha 0 across the whole line (until 2026-11-23 a 150-grey core between white edges of
alpha 255), so the shader's `diffuse *= lerp(pixelxformColor, 1, diffuse.a)` gives the owner's colour itself. The line is
0.31 m wide, or 0.005 m per metre of radius where that is more (past 62 m; written as 0.5 and 0.008 in the old basis,
the same on screen). The ring used to look pale (in game a core of (195, 178, 250) for blue and
(255, 179, 162) for red) because of its bump map. `BumpPS` in the game's `sm3_shaders.hlsl` reads the bump as
(x, y, z, shine) = (A, G, B, R), and adds the sun's shine, scaled by R, over the colour. The old flat bump was
(R 128, G 128, B 255, A 255): half shine on a normal tilted 45° along the ring. `range_line_bump.ddt` is now
(0, 128, 255, 128), as the game's own `flat_normal_black_spec.ddt`. Measured after the change: the ring's core is
(72, 66, 255) for blue, next to the selected Skirmisher's own decal.

**Fills and dashed rings (2026-11-23).** Each ring is one or two models of `effects\uhc_rings`:
- `range_<N>.xml`: the line.
- `rangefill_<N>_p<player>.xml`: its fill.
- `range_<N>_ships.xml`: a dashed line with no fill, for an attack that reaches no unit on land (only ships, or only
  structures).

The fill:
- It is a flat disc 0.135 m over the feet, under the line (0.15 m), reaching the middle of the line.
- It uses the game's `alphablend` effect, which blends by the texture's alpha.
- Engine tests in game, 2026-11-23:
  - the selection decal effect `decalselection` on a mesh drew nothing;
  - `pixelxform` (with `pixelxformColor = playerColor`) drew the owner's colour, but opaque;
  - `alphablend` blended, but with no player colour.
- So each player ID 0 to 8 has its own texture, `rangefill_p<player>.ddt` (the game's `playercolors.xml` `color1`), and the
  key hangs the owner's disc, `[[unit+44h]+0]`. The placement ghost gets none: a ghost that cannot be placed is drawn with the tint technique, and `alphablend`'s tint draws the disc opaque (seen in game on a Fort's ghost, 2026-11-23).
- Measured with an alpha-banded test disc: the blend follows the texture's alpha, and the sun about doubles the
  texture's colour. So the texture holds 0.6 of the colour.
- Its alpha (DXT5, smooth at these low values) is 0 up to 20 % of the radius, then rises as t^1.2 to the colour's edge
  value: 0.38 for blue, 0.36 purple, 0.32 red, 0.30 the others.

**What an attack reaches.** Each type of its `<Rate>` list (`[action+0Ch]`, count `+10h`, 0Ch-byte entries, `+0` the
unittype) is sorted by its protos in the database (`[db+54h]`, count `+58h`, tested with the is-a test 0x44D7FA):
- land units: one of its protos is neither a `Ship` nor a `Building` (`Unit`, `AbstractInfantry`);
- ships: every one is a `Ship` (`AbstractWarShip`, a ship's own proto);
- structures: the rest, buildings or buildings and ships (`LogicalTypeShipsAndBuildings`, a torch).

An attack reaches land units when one of its types does (or its list is empty): a filled ring. Otherwise it gets the
dashed ring. A structures-only attack is left out when the unit has another attack on land units (2026-11-24, after a question on
the Grenzer's second ring: it was the 6 m torch, `BuildingAttack` on `LogicalTypeShipsAndBuildings`); alone, as on a
mortar, it keeps its dashed ring. The IDs of `Ship` and `Building` come from the unittype name table `[db+190h]`
(0x58E685 / 0x40295B). Each type is worked out once per database.

**Caps.** The caps count models: 60 in all, so a filled ring is two.

**`<Flag>AlwaysDisplayRange</Flag>`.** The proto flag parser 0x5F640A (`stdcall(proto, name)`) compares the name with each
flag it knows, through the string compare 0x4028B4, and returns with nothing for any other name. The key replaces the call of
its last compare, 0x5F726F, with a hook that runs the compare and, when it does not match, hands the name to the key.

**Why it is safe.** Nothing here reaches the simulation: the selection and the keyboard are local and only read, and a model is
a visual of the unit. The tick walks the selection and its own map, never the world's units. The flag hook returns the
compare's own result, so the parser goes on exactly as before.

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

### nativePreview

**The stock panels.** Two pieces of the bottom bar decide what a selected native socket shows.
1. **The chooser**, FUN_00454270 (it runs many times a second): it looks at the first selected unit, and for a Socket
   (unit type 4Bh, not the proto `[db+5FD0h]`) it jumps to `0x645FE7`, which sets "socket" (`[esp+15h]`), and then shows
   the settlement panel instead of the command grid (`[ui+58h]`, whose byte `[+342h]` = 1 stops its refresh). A unit no
   test claims leaves `[esp+12h]` = 1, and the grid stays as `0x45447D` left it (`[+342h]` = 0).
2. **The command panel refresh**, FUN_0046188E: it leaves at `0x46194D` unless the selection's player `[sel+0Ch]` is the
   local player `[game+3C0h]`. It collects the entries of the selected unit's proto (`[proto+E8h]`, 6-byte records
   `{word id, kind 0 Train / 1 Tech / 2 Command, page, column}`) in a first loop, whose body is the cold chunk at
   `0x4C58AD`: a Train entry only if the player's proto is available (`0x8F7AA5` / `0x8D66AB`), a Tech entry only through
   `0x4C5725` and `0x4C5B17`, and any of them only if the unit has actions (`[unit+58h]`). A second loop lays the buttons
   out: a tech passes "can this unit research it" (`0x4C6968`) and the prerequisite test (`0x4C7330`, then `0x4C5DDA`:
   -1 hides it, an age index puts the age mark on it), then is built at `0x462172` (rollover `0x4C737C`, icon, cost); a
   unit is built at `0x695C7B` (rollover `0x70F25D`, the age mark from `0x8D6806` when it is not available). Every grid
   button joins at `0x462317`, with its state in `[esp+24h]` (0 enabled, 1 disabled), its age mark in `[esp+6Ch]` and
   its click and shift-click commands in the strings at `[esp+1C0h]` and `[esp+3C0h]`.

A socket proto has no entries and no actions. A Trading Post proto has one list for every native, and the panel shows
the entries the player's alliance made available.

**The preview.** A socket gets one when its proto has `NativeSocket` (and, with `tagged`, `<NativePreview/>`), a
`<SubCiv>` (`[proto+1D1h]`, a civ ID, 0xFF for none; read at `0x5FCD50`), and no building of its socket type stands on
it: `0xA01A20(world, &unit+14h, socketProto)`, the lookup `trPlayerControlsSocket` uses, returns the building's ID or -1.
The native's sets are read once per civ and database from its age techs (`[civ+50h]`, 8-byte entries whose first dword is
the tech ID, count `[civ+54h]`): each tech's effects (`[NodeData+24h]`, count `[+28h]`); a `TechStatus` effect (vtable
`0xB969B0`: target `[+0Ch]`, status byte `[+10h]`, 1 obtainable, 2 active, the latter followed) adds a tech, and a `Data`
effect (vtable `0xB9E5A8`) of subtype `Enable` (`[+0Ch]` = 10h) with an amount `[+18h]` above 0 adds its target proto
(`[+4]`). Seven hooks:
- `0x645FE7` (chooser): a previewed socket jumps to `0x454354`, as a unit no test claims, so the command grid stays and
  refreshes. The answer is kept for one simulation step of one unit, since the chooser runs hundreds of times a second.
- `0x646124` (chooser, the mode where `[ui+3CCh]` is not 0): a previewed socket skips the test that hides the command
  panel for a socket with a `<SubCiv>`.
- `0x46193E` (refresh): the gate compares the local player with itself for a previewed socket, and turns the preview on
  for this refresh (it is cleared at every gate).
- `0x461BBD`: the entries are the local player's copy (`0x45311B`) of the building, `TradingPost` by default.
- `0x4C58AD`: in a preview the collection decides itself: a Train entry of an enabled unit, or a Tech entry of a tech
  in the set, goes straight to the stock append at `0x4C59F5`; any other entry, every command and every tech the layout
  would put in a big-button slot (tech flags 27, 36, 37, 39) go to the next entry.
- `0x4620B9`: a tech skips "can research here" and the status tests, keeps the prerequisite test (so a tech that waits
  for another tech stays hidden and an age prerequisite gives the age mark), and goes to the build-up as disabled.
- `0x462317` (the shared button hook, `panelbuttons.*`, also used by `transformChecks`): every button of a preview is
  disabled and its two command strings are emptied.

**Why it is safe.**
- Nothing writes game state: the hooks change which panel the chooser keeps, which entries the refresh collects and how
  it draws them. The functions called (`0xA01A20`, `0x45311B`, `0x44D7FA`, `0x5A2346`, `0x4C7330`, `0x4C5DDA`) only read.
- No command is sent: a button with an empty command does nothing when clicked, and the socket enters no hotkey context
  (the selection qualification takes the local player's units only).
- The rest of the refresh with a Gaia unit: after the refresh, FUN_004614A2 compares `[sel+0Ch]` with the local player
  again and takes its non-own branch (`0x69789E`), the one for allies. The rollover builders read the unit only for
  `[unit+5Ch]` (`0x4C737C`) or not at all (`0x70F25D`); `[unit+58h]` = 0 skips the action reads; `[unit+B4h]` exists.
- Registers: the gate keeps EAX (the selection) and reloads ECX as in stock; the entries hook writes only EBX and the
  flags before the next write; the collection hook's targets reload EAX and do not read ECX or EDX; the tech hook
  re-executes the stolen `mov edi,[esp+28h]`, and its two calls are thiscall on the tech entry, `ret 4` and `ret 8`,
  keeping EBX, ESI, EDI and EBP; the button hook re-executes the stolen `mov ebx,[esp+1Ch] / cmp ebx,6`, whose flags
  reach the `jge`. The chooser hooks call a C++ function that keeps EBX, ESI, EDI and EBP, and re-execute the stolen
  loads (and the stolen `call 4BC54Ah`) on the stock path; at both of their targets EAX, ECX and EDX are reloaded.
- No branch lands inside any overwritten range (checked over the whole `.text`); `0x461BBD` and `0x4620B9` are branch
  targets, which land on the hooks' own start.
- The preview flag is set at every gate and only read by hooks inside the same refresh, after the gate.
- Performance: the chooser asks once per simulation step while a Socket is selected; the button hook adds one compare
  per button. Measured with `perfprobe.py`, 60 s each: 0.23 ms of update a frame with the preview, 0.13 ms with the
  stock settlement panel, 0.2 ms with an own Settler's command panel, and no frame over 50 ms: the preview costs what
  any command panel costs.

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
  player-owned socket, and triggers cannot give build orders, so the order path that bypasses that
  check was not driven.
  That is the path WoL reports. <!-- private -->

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

### veterancyBonus

Stock's flag `ExperienceUnit` (bit 7Dh of the proto's flags, set at the cold 0x6B0AE4) has no reader: no call of the getter
0x44CAC4 passes it, and no direct `test`. So nothing counts a unit's kills.

TakeDamage marks the killing blow in `[esp+1Fh]` (0x4D484B, when the unit had hit points and the damage takes them), and a `je`
at 0x49B746 goes to the cold path 0x4D4F37. The hook sits there: ESI is the unit killed, and `[esp+28h]` the attacker unit, null
when it is gone. Gaia and the attacker's own units do not count. Since 2026-11-13 the hook is shared ([the killing
blows](#the-killing-blows-shared)): the key is one observer of it, with `killSpawn`.

The state lives in the game, not in the DLL: everything is a stat modifier made by 0x4DD22D, the call of snares and auras, with
0 ms, so no time limit. The count is a modifier of stat 62h, which no code reads, with the kills in `[+68h]`; it is read back
by the walk of `modifiers.h`. Each row reached adds a multiply modifier (operation 2) of its total divided by the total of the
row before, or for `op="add"` an add modifier (operation 1) of the difference, so the total from that rank on is the row's.
So the save, the stat code and the panel need nothing more, and nothing is left to clean up.

**The stat sum.** FUN_004B3C7D(float* value, list, stat) walks the unit's modifiers of that stat oldest first: operation 0
sets, 1 adds, 2 multiplies, and an exclusive one (flag 16h) stops the walk. Its callers start Speed (0) from the proto's
velocity `[proto+80h]` (0x4B3C48) and MaxHP (1) from `[proto+98h]` (0x4B3A0E); every other stock stat (2..8, 0Bh, 0Dh, 0Eh,
0x4B3A41..0x4B3C1C) from 1.0, a factor. So an add row is in hit points or speed for those two and a fraction of the base
for the rest, and a multiply and an add of one stat depend on their order. The creator 0x4DD22D → 0x4B3D9E → init 0x4B3D44
stores the operation as given (`[+78h]`), with no check. A transform replays the rows reached one by one, as the kills made
them, so it gives the same order and result.

The modifier of `MaxHP` scales the current hit points. A transform in place, 0x9C754C, ends the unit's modifiers, so its seven
calls go through a wrapper that reads the count before and, after it, adds the count back and one multiply modifier per stat
for the rows of the new proto. The new proto's rows decide, so a proto with none keeps only the count. `trUnitChangeProtoUnit`
does not come through 0x9C754C.

Rows: `<VeterancyBonus>`, through `prototags.*`; `modifytype` goes through the stock parser 0x5F5645, so the names of
`AddModifyType` work too. The rows are kept by proto ID in a map that only the load writes.

**Default rows and rank names.** `veterancy.xml` (`hostfiles.h`'s data folder) is read at the key's start with the
`xmllist.h` file reader and a small element parser of the key's own. Its unit types and `modifytype` names are resolved at the
first lookup after each database load, through the table `[database+190h]` (0x58E685 bucket, 0x40295B find) and 0x5F5645 on
a BString: by then the protos and every key's `<ModifyType>` names exist. A unit's rows are its proto's own, else the first
default whose type its player's copy has (0x44D7FA); no list per proto is kept, so a type a tech adds counts at once. The
lookup runs on a kill, at a transform, in the one walk after a load and in the panel row of one selected unit. Names made of
digits are string IDs, read with 0x58EA52 when shown; the panel row's colour is the string table's `<color=r, g, b>` markup.

**Rows with a tech, blocks by civilization (2026-11-21).** A row's `tech` name is kept in a list of names and resolved
with 0x600BE1 (tech by name, `thiscall(database, char*)`) at the same first lookup after a database load; an unknown name
gets −3 and its rows never count. A row counts for a unit when it names no tech or when 0x94AF27(`[world+7Ch]`, player ID,
tech) says the tech is active for the unit's player. `<Civilization name>` blocks are resolved with 0x52D6FF (civ by
name, `thiscall(database, char*)`, null when none) and compared with the player's civ, 0x405C2E(database,
`[[player+20h]]`) when `[player+24h]` > 0; the lookup tries the civ's blocks, then the global ones.

Rows with a tech can be given out of kills order, so the rows given are no longer a function of the kills. They are kept
on the unit in a saved marker (`savedmarkers.h`, stat 6Ah: word 0 the tag `VETG`, words 1 to 3 one bit per row of the
unit's rows in kills order, 96 rows), written only when the unit's rows name a tech. A unit without the marker was given
every row without a tech up to its kills (before the current kill), which is what the key always did, so old saves and
protos without tech rows behave as before. Giving a row adds the modifier of its series' total after the row against
before it: the total is that of the series' given row with the most kills. A world tick (every 500 ms of game time, only
while some row names a tech) looks at each player's named techs (`[world+5Ch]` players) and, on one that became active
(or on the first look of a game, which also covers a loaded game), walks the world's units once and gives each unit of
that player with kills the rows it now reaches; giving is idempotent. A tech that goes inactive takes nothing back. The
transform wrapper gives the new proto's rows afresh (the transform ended the marker).

The proto rows' map is now cleared on each database load (`OnDatabaseLoad`, which runs at the end of the abstract
types' registration, before the protos are read); before, a second data load in one run (a skirmish start) added every
proto row again, and a row of the same kills applied twice.

**`notext` (2026-11-21).** The option only skips the two calls of `floatingtext.*` at a new rank, for a mod whose own upgrades
show their text there. The count, the rows, the mark and the panel row are the same; the string sites stay verified, as the
rank names and the panel row read them too.

- **Observed in game:** see the tests in the modding guide.

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
have no duration flag, so exclusive speed auras (some mods have them) are not taken for snares.
WoL has such auras. <!-- private -->

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

<!-- public:begin
**The trap.** Writing `[[node]+8]` and `[[node]+0Ch]` changes the shared NodeData, hence renames
the tech for every player.
public:end -->
<!-- private:begin -->
**WoL's bug.** WoL's `SetTechName` apply writes `[[node]+8]` and `[[node]+0Ch]`: the shared
NodeData, hence a global rename.
<!-- private:end -->

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
- **Not covered:** the `MutateDopples` refresh (no stock proto uses it), the dopples a saved
  game already holds, and the dopple of a live unit that later dies out of sight.
  No WoL proto uses `MutateDopples` either. <!-- private -->

`expire=` wraps the call 0x49198B of the manager update; past the age it answers true and 0x5038E0 removes the dopple. `[dopple+0]` is the time it was made, kept in the save, and only simulation data decides, so every machine ends the same dopples.

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
  bytes.
  <!-- private:begin -->
  Upstream's `nativeCivs` patches the later compares (0x4904B5, 0x4ECD6B, 0x8D47C9), outside
  these ranges, so a `nativeCivs` port can share these functions.
  <!-- private:end -->

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

<!-- public:begin
**A dying first town center.** A tech can give `TownCenter` a `Lifespan` and then ship a
replacement building in the same application. The replacement's addUnit then sees a first town
center that is still a live unit, so stock keeps it, and it dies a moment later.
public:end -->
<!-- private:begin -->
**WoL's Maori start** (static reading). `Age0Maori` applies `Data Lifespan 0.5 Assign` to
`TownCenter`, then `FreeHomeCityUnit MaoriPa`. The Lifespan case of the Data effect (FUN_008F973F,
case 0x8FA939) writes `[proto+ACh]` and calls FUN_00A00505, which runs setLifespan (0x48DCB9) on
each of the player's units of that proto: the live town center gets state bit 3 (lifespan armed) at
once. FreeHomeCityUnit then creates the Pa at the shipment point, the town center, in the same tech
application. The Pa's addUnit sees a first town center that is still a live unit, so stock keeps
it, and the town center dies 0.5 s later.
<!-- private:end -->

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

WoL's design (request #3, by WoL's developer Mandos). <!-- private -->
A civ names its first building in
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
picker `uiPoliticianUI` (0x7E6905, 0x7E803F), the start camera (0x82E45B) and the `Maintain` spawn
gate (0x492FD6), which all look for `TownCenter` itself.

### scenarioCivs

WoL's request #95 (JTMaston, 2026-11-22). <!-- private -->
A second civ file, `data\scenariocivs.xml`, read right after `civs.xml`; its civs are appended to the same list and are
visible in the scenario editor only.

**The stock loader.** FUN_0052A590 (`thiscall`, ECX = the civ database, kept in EDI and at `[esp+1Ch]`):
- creates civ 0, `Nature`, through the civ append FUN_0052A4DB;
- builds an XML reader on its stack at `[esp+100h]` and loads the file into it: FUN_00599A7D(reader, `[0D6F510h]` (the
  directory), `L"civs.xml"` (0xBD1124), 0, 1), `bool thiscall`, `ret 10h`. The load finds the loose file or the archive's,
  XML or XMB. Its head releases a document the reader already holds (`cmp byte [esi+1864h],0 / call 598E2Bh`);
- reads the root `[esp+108h]` (the reader's `+8`), checks its name against `Civs` (the compare 0x443C10 ignores case: a
  root `<civs>` passes), and walks its elements (`[node+8]`, count `[node+0Ch]`, index `[esp+90h]`). Each `<civ>` becomes a civ
  object appended by FUN_0052A4DB: it grows `[db+24h]` (count `[db+28h]`) by one, so a civ's ID is its position. Other
  elements (`<subcivalliancecost>` …) set the database's values;
- when the walk ends, 0x52B485 (`push 0BCEE80h`, reached from 0x52B480 after the last element and from 0x52A68C when the root
  has none) goes on with the database's other values and the native civ marks (0x52B54F..0x52B581, by name), then destroys
  the reader (0x52B588) and returns. Nothing after 0x52B485 reads the reader's document.

**The hook** replaces the `push` at 0x52B485 (5 bytes; `hooks/scenariocivs_hooks.asm`). At the end of the walk over
`civs.xml`, `UhcScenarioCivsNext` (`features/scenariocivs.cpp`):
1. returns at once when `data\scenariocivs.xml` (or `.xmb`) does not exist;
2. loads it into the loader's reader with FUN_00599A7D, the arguments of the stock call; a file that does not load is
   logged and dropped;
3. checks the document, since the stock walk cannot skip an element: the root is `<civs>`, every element under it is a
   `<civ>`, and each civ's `<name>` is an identifier that no civ has yet (XS gets `cCiv<name>=<id>` for every civ, format
   string 0xBF702A, and a second constant of one name stops the AI scripts from compiling);
4. records the civ count and returns true. The hook then sets EDI to `[esp+1Ch]` and jumps to 0x52A62B, where the stock code
   reads the root of the document just loaded, checks its name and walks it like the first. The civ tag handlers of the
   shared hook 0x52BB07 (`civtags.h`) run on these civs too.

When the second walk ends at 0x52B485, the function sees the count past the recorded one: it sets the flags of the new civs and
returns false, and the hook re-executes the `push` and continues at 0x52B48A. A walk that stopped half-way (a stock error path)
never comes back to the hook; the next load's first end then finds no new civ and is treated as a first end.

**The flags.** The `<Visible>` handler (0x52D302) and the `<VisibleInEditor>` handler (0x52BE78) set bit 0 and bit 1 of the
civ's flag bitset `[civ+128h]` (a pointer; bit count `[civ+12Ch]`). The hook clears bit 0 and sets bit 1. Readers found by a
scan of `.text` for `mov r32,[r32+128h]` followed by a test of the byte (capstone; REA was in use by another agent):
- bit 0 (Visible): 0x777BAC (in FUN_00777B20, called from many places around 0x8B87DA), 0x77D942 (in FUN_0077D90B, called
  just before the hero UI test 0x77EBB2), 0x92966F (in FUN_0092944F, which fills a list gadget with the visible civs that also
  pass FUN_006EF1CA(2));
- bit 1 (VisibleInEditor): 0x9B2518 (in FUN_009B24C3, which fills a list with the display names of those civs: the editor's
  Player Data list, seen in game).

**Why it is safe:**
- The stock walk does all the work: the scenario civs are built, appended and parsed by the code that builds the others, in
  one call of the loader, before anything after 0x52B485 runs (the native civ marks, then whatever caches civ IDs later).
- The civs of `civs.xml` keep their positions, so their IDs and every cache by name stay as they were.
- The reader is the loader's own: FUN_00599A7D frees the first document before it loads the second, and the destructor at
  0x52B588 frees the second.
- At 0x52A62B the stock code depends only on the stack frame (the same at 0x52B485) and on EDI = the database, which the hook
  sets. EAX is the compare result the code writes before it reads it.
- Nothing runs during the game.

**Observed in game** (2026-11-22, a test copy with a mod's data): two civs added as 169 and 170; the first 169 entries of the
list identical with the key off; the editor's list showed them, the skirmish's personality list did not; a scenario with players
on them loaded, fought, was saved as a game and reloaded; an AI skirmish compiled and played; bad files logged and dropped.
`civs.xml` was read once per launch: with `log`, neither a scenario load nor a skirmish start logged a second read.

**Not covered:** the lobby; multiplayer; beside another DLL that hooks the loader; which screen FUN_00777B20 and FUN_0092944F fill (inferred from the
bit they test, not seen); a civ of this file in a campaign.

### transformSpan

The seven calls of the transform 0x9C754C belong to `transformcalls.*`: `veterancyBonus` and `transformSpan` both need them,
and a second `WriteCall` would fail the first one's check. A key adds an observer, called around the transform, or takes
the effect's call 0x7FBC79; its own transform calls `TransformUnit`, so a timed unit coming back runs the observers too.
Stats 60h and 61h are `transformSpan`'s markers and 62h is the kill count of `veterancyBonus`.

The effect's vtable is 0xB96B60. Slot 1, setData 0x622822, is wrapped to read `transformspan` from the node, by effect in a
map. Slot 0Fh, apply 0x7FBBAF, is wrapped to know which effect runs. Its call of the in-place transform at 0x7FBC79
goes to a function that records the unit: ID, the proto it had, the proto it gets, and the end in game time `[world+108h]`.

A world tick turns the due units back with the same 0x9C754C. It runs after the stock update, so no action list is being
walked. Each entry is checked again then: the unit by ID (`[unit+10h]` must match), alive, and of the proto the key gave
it. With nothing due the tick is one compare with the nearest end.

The table is in the DLL, so a saved game keeps a copy on the units: two stat modifiers (0x4DD22D, stats 60h and 61h, which
no getter reads), one with the proto to return to and one with the end in tenths of a second. A value that changes is
written in place, at `[modifier+68h]`; a finished entry writes -1. The modifier outlives the entry by 5 s, and stock removes
it. As poisons do, the tick compares the step count `[world+F8h]`: when it jumps, or the time goes back, or the world
changes, another game is running, and the table is rebuilt by walking every unit's modifiers once.

TransformUnit is not applied again on load: a saved game loaded after the end left the units as they were.

- **Observed in game:** see the cases in the modding guide. A unit can turn back into a proto its building does not take:
  stock does not check, and the unit left the building normally.

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

`UhcNoTrainBlocked`: false unless the trainer's proto is of the marker type (0x44D7FA). Then it
takes each `near` entry in order (only `FirstTC` without one) and keeps the nearest blocker:
- `FirstTC`: for players 1 .. `[world+5Ch]`-1 in order, FirstTC `[p+4F0h]` ≥ 0, the unit
  0x44CC6D(world, id) exists, its owner `[tc+44h]` is not the trainer's player and
  `0x484D2D(owner, trainer's player ID)` is true, it is alive (unit vtable slot A4h); its distance
  is `[vtbl+B8h](tc, trainer+14h)`.
- a unit type: the placement rule's type branch (0x8CEA69) asks the world for the units near a
  point, FUN_004A1C55(world, point, radius, 1, list), instead of walking every unit; the key makes
  the same call with the trainer's position `[trainer+14h]` and `<meters>`. The function fills
  the obstruction manager's scratch list from a box query (0x462DBA), keeps the units whose
  distance to the point (`[vtbl+B8h]`) is at most the radius and appends their IDs to the
  caller's list {data, count, capacity}, resetting its count first. The DLL keeps one list for the
  session, so once it has grown no tick allocates. Each ID must give a unit (0x44CC6D) whose owner is not null, not
  the trainer's player and not player 0 (Gaia, as the FirstTC loop starts at player 1), whose proto
  is of the type (0x44D7FA), whose owner is an enemy (0x484D2D), that is alive (slot A4h) and
  built (0x44DDB4: no construction record, or its progress at 1.0, so a foundation does not block
  and a unit always counts).

Blocked when the smallest distance is below `<meters>`.

**The distance.** Slot B8h (0x485D68) is not a centre-to-centre distance. It calls slot B0h
(0x485D83) with the unit's own position and the point, which asks slot 90h (0x45EE55): for a proto
with bit 4 of its flag bitset set (the Town Center has it), slot 108h (0x4A0ED5) measures from the
point to the unit's obstruction outline, the nearest of its four edges, 0 inside it (0x485E35);
otherwise slot F4h (0x485DBC) takes the centre distance in x and z minus the larger obstruction
radius times √2, at least 0. The trainer counts by its centre. In game: a Stable (half-sizes 3 × 5)
whose centre was 24 m from the Daimyo in x and 4 m in z gave 21.0 m; a Barracks (4 × 4) at the same
place 20.0 m; a Town Center (4 × 4) 10.4 m away in x gave 6.4 m. The placement rule uses the same
call, so `65` here is the stock rule's 65 m.

**The warning.** After a blocked decision, `Warn(trainer)` runs only when the trainer's player is
the local player `[game+3C0h]`, the text manager `[world+8A8h]` exists and 0x4818F4(trainer, local
player) is true, as the stock dodge text checks (0x6A24FC..0x6A2525). A map from the trainer's ID
to the game time `[world+108h]` of its last warning keeps one per 8000 ms per unit; it is cleared on
each data load, when the world changes and when the game time goes back (a new game). The text is a
BString from the cfg text (0x401A12) or from a string ID (0x58EA52), freed with 0x4010CA. The two
times come from the dodge's cfg variables (0x46A144 with the IDs `[[0CEFFF8h]]` and `[[0CF0000h]]`;
2000 and 1000 in game, the values of the stock caller 0x9C039E). Then 0x8023AE(manager, &text,
time1, time2, unit ID, motion, 0xFFFF4040, 1.0, 0, -1), the dodge's call with a red colour and a
motion of {0, 0, 0}: the dodge's {0, 0.1, 0} makes the text rise, and in the test bed it left the
screen in about 0.3 s, while at 0 it stays over the unit. 0x8023AE refuses a text when
`[game+0B39h]` ≠ 0 or `[game+0B3Bh]` = 0, for a negative unit ID or an empty text (−1, logged as
"refused by the engine"); otherwise it appends the text to the manager's list and returns its index.

**Why it is safe.**
- Both paths leave one value on the x87 stack, as the getter does. After `0x9EA418`, EBX and EAX
  are loaded before they are read, ECX at `0x9EA42C`; EDX is not read (0x485D2C, called at
  0x9EA432, starts with `mov edx,ecx`), nor are the flags. The helper keeps ESI, EDI, EBP and EBX
  (stdcall); the stack is balanced. `WorkRateTrainCall` and `TrainRateScale` are verified sites.
- A rate of 0.0 is a state the update already handles: `[+68h]` does not move and 0x9EA1FA keeps
  the fraction below 1.0. The queue, its resources and its population stay as stock left them.
- The answer depends only on simulation state (unit types, FirstTC, stances, alive and built
  state, positions), read with the engine's own functions, the placement rule's spatial query and
  its distance call; the comparison with `<meters>` is a single-precision compare. The order of the
  query's list can change which blocker the log names, not whether one is near. No local player,
  clock or interface state takes part in the decision.
- The warning reads the local player and writes only the text manager, which stock fills from the
  same simulation code under the same local-player test (the dodge). It never feeds back into the
  decision, so `nowarn` and `warn=` may differ between players.
- `liveBuildingWorkRate` verifies `WorkRateTrainCall` before this feature writes it, and
  `buildingWorkRateAuras` is applied after it (the order in `features.h`).
- **Observed in game:** a Daimyo 34.1 m from an enemy Town Center made no progress, and trained
  both queued units once that Town Center was killed. With `near Stable near FirstTC` (40 m), a
  Daimyo 21.0 m from a Stable's edge made no progress, the warning appeared over it every 8 s, and
  it trained 5 Ashigaru once the Stable was destroyed; walked to the enemy Town Center, it paused
  again at 6.4 m. `warn=` with a UTF-8 text and with a string ID showed that text.
- **Stock: a trainer with a queue stands still.** With units queued, the Daimyo ignored a
  trigger's attack-move and `uiMoveAllMilitaryAtPointer`, and a right-click on the ground placed its
  gather point; with the queue empty the same command moved it. So a held trainer leaves only when
  its queue is cancelled; the key does not change that.
- **Not covered:** players whose FirstTC is dead or never set; refusing the order instead of
  pausing it; a foundation near the trainer. A `near` type of moving units (a Hussar: 17.3 m for
  18.4 m between centres, the radius branch of the distance), a Town Center that is not the first
  (`near AbstractTownCenter`) and a saved game loaded with a held trainer were seen in game.

With `refuse`, the head of the enqueue 0x9EAC35 answers false before the cost at 0x9EAF86, for the train command and 0x8D60EA. **Why it is safe:** all four callers take a false, and the trainer `[ecx+10h]` is set before the call.

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
  (0x45FAB8..0x45FADC) and queues the bar (0x45FB71). The renderer FUN_0045C4AF draws each bar
  as one textured quad whose fill is a texture window (below, "The segment"), so a fill above 1
  cannot simply overflow the bar.
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

**The segment** (`segment[=RRGGBB]`, Overwatch style). The HP above the reference is drawn over the
right end of the full floating bar, (HP − reference) / reference of its width (all of it from twice
the reference), in the segment colour (default `FF8C00`); the stat row's HP text above the
reference is coloured the same.

- *The stock bar.* The queue FUN_0045FB71, `thiscall(world, pos*, scale, fill, player, colour
  byte)`, `ret 14h`, grows `[world+8D0h]` (count `[world+8D4h]`, through 0x408308: no fixed cap)
  by a 28-byte record: `+0` position, `+0Ch` scale, `+10h` fill, `+14h` player, `+18h` colour byte.
  The bar chunk passes the position `[esp+18h]`, scale 1.0, the fill, `[[unit+44h]]` and
  `[unit+88h]`, then `jmp 4516B3h` (0x45FB6C). The renderer FUN_0045C4AF (ECX = world; REA
  Evidence `ev_0886c3a2…`) locks count × 6 vertices of 24h bytes in the device's dynamic vertex
  buffer (0x40A6A2; `[[0C66044h]+660h]`, 2 MB in game; a request larger than its size `[vb+4]`
  returns null at 0x40A689, and then no bar is drawn that frame), sets render states 7 and 14 to 0
  (inference: depth test and depth writes off), and binds once the shader `defaultcolored` with the
  texture `ui\hitpoint_bars\hpbar`. Per record: the colour is the palette entry of the byte when
  the byte is not FFh and `[world+33Ch]` is set, else the player's `[player+0C8h]`, else white;
  hw = scale / 2 and hh = scale / 16 along the camera's right (B, `[[game+148h]+28h]`) and up
  (A, `+1Ch`) vectors, a camera-facing quad of six vertices (`+0` position, `+0Ch` a constant,
  `+18h` colour, `+1Ch` u, `+20h` v): v0, v2, v3 on the left (P − hw·B ± hh·A) with
  u = 0.5 + fill / 2, v1, v4, v5 on the right with u = fill / 2. The texture (64 × 8, art2.bar) is
  black on its left half and a white-grey vertical gradient on its right half, so the fill is the
  left part of the bar, tinted by the vertex colour: the floating bar is the player's colour, not
  green (the green / yellow / red bar is the selection panel's). Every queued bar goes out in one
  draw call (0x45F96D), and the count is reset.
- *The hooks*, only with `segment`: the three floating bar sites are the shared hooks of `floatingbars.h`
  (`hooks/floatingbars_hooks.asm`, shared with [`inventoryBars`](#inventorybars)), the texts are in
  `hooks/overheal_hooks.asm`:

  | Site | Stolen | Hook does | Continues at |
  |---|---|---|---|
  | 0x45FB6C | `jmp 4516B3h` (5 B; ESI = unit) | `UhcFloatingBarQueued(unit, &pos, [esp+15h] (under construction), BL (Alt))`: each key's observer; this key's, unless under construction, queues the segment against the reference | 0x4516B3 |
  | 0x45C4B9 | `mov ebx,[ebp+8D4h]` (6 B; EBP = world) | `UhcFloatingBarFit(world)`, then the stolen load | 0x45C4BF |
  | 0x45CB72 | `add eax,1 / add ecx,1Ch` (6 B; ECX = the record's offset, EDI = its sixth vertex, ESI = camera) | for a record with a negative player, `UhcFloatingBarVertices`: the writer of its kind (the player ID without its low byte) | 0x45CB78 |
  | 0x4D7651, 0x69A9C0 | `push` of `%d/%d` / `%d/%d (%d+%d)` (5 B; `[esp]` = HP, `[esp+4]` = 100 %) | pushes the coloured copy when HP > 100 % | 0x4D7656, 0x69A9C5 |

  The observer queues a second record when HP > reference (for an unmarked unit the
  reference is the stock max, so never): same position, scale 1.0, fill = min((HP − reference) /
  reference, 1), player 804F5648h (no player has it; negative, so the renderer colours it white)
  and byte FFh. Its kind's writer moves the left vertices right by
  scale × (1 − fill) × B, gives all six u = 1.0 (left) / 0.5 (right), the fill part of the texture,
  and the segment colour; every other record keeps the stock vertices. `UhcFloatingBarFit`
  removes every added record (negative player) before the lock when count × 216 bytes would not fit in the buffer,
  so the added bars never cost a stock bar. The coloured formats are the stock ones wrapped in the
  UI markup the game uses itself (`<color=1, 0, 0>` at 0xBA1E44, `</color>` at 0xBA1E30):
  `<color=1.00, 0.55, 0.00>%d/%d</color>`; the stat row's gadget draws it.
- *Choices.* Over the right end, not past it: the bar keeps its width and the segment never leaves
  the bar's area. A tint, not a mod texture such as `hpbar_overheal`: the queue is one draw call
  with one texture bound, and a second texture would need a second pass inside the renderer;
  `segment=RRGGBB` lets a mod choose the colour. The selection panel's bar is not changed: its
  three colours are three UI gadgets (`[panel+310h]`, `+314h`, `+318h`), and the overheal shows on the
  green one ("The portrait bar", below). The minimized UI's `unitHitPointsValue`
  (0x698B63) is formatted the same way, but its gadget prints the markup as text (seen in game:
  `<color=1.00, 0.55, 0.00>181/165</color>`), so it is left plain; so is ObjectInfo (0x9AFA8B,
  0x9AFAA5), the scenario editor's panel.
- *Why it is safe.* The sites decode at instruction boundaries and nothing branches into the
  stolen bytes; the x87 stack is empty at 0x45CB72 (checked over one loop iteration) and at
  0x45FB6C; the queue hook keeps every register for 0x4516B3; the text hooks change only the
  flags, which the next instruction does not read. Display only, like the rest of the key.
- *Observed in game:* healed to 165, marked Musketeers showed a full bar with the orange segment
  over its right tenth and `165/150` in orange; a Musketeer damaged to 92 showed a partial bar and
  a white `92/150`; the unmarked Pikeman healed to 132/132 kept the stock bar. The vertex buffer
  was 2 MB (9,709 bars), so the fit guard never ran. With `segment=40C0FF`, a `Hitpoints` tech
  (+15 %) gave `189/174 (150+24)` in light blue through the cold split format (0x69A9C0), and an
  allied player 2's Musketeer had its yellow bar with the light-blue segment.

**The portrait bar** (with `segment`).
- *Stock.* At panel creation (0x9BAEE5..0x9BAF6C) the panel looks up its gadgets by name with
  0xAB7C2F, `thiscall(panel, int* handle, BString* name, 1)`, `ret 0Ch` (0x402733 narrows the name,
  0x433812 searches the panel's gadgets; no match writes `[0C672C0h]`, the "no gadget" handle;
  valid handles are above it): `unitselectionpanel-unitHealthBarGreen` → `[panel+310h]`, `Yellow`
  → `+314h`, `Red` → `+318h`. Each refresh (0x4C82E6, `[esp+50h]` = panel, `[esp+78h]` = group)
  picks one by `[group+1Ch]` (≥ 0.66 green, else ≥ 0.33 yellow, else red; the cold choices at
  0x69A614 / 0x69A61F), gets it as a progress bar (0x44B8B8, cdecl), fills it (0x590772,
  `thiscall(bar, float)`, clamped to [0, 1]: `[bar+13Ch]`, then the mask drawable `[bar+144h]`
  vtable +50h) and shows it, with `[panel+2E4h]`, `+2E8h`, `+2ECh` and `+31Ch` (the help button),
  through 0x447F7B, the code behind the UI command `gadgetReal` (0x7E2244): `thiscall(manager =
  [[0C66244h]+44h], handle)`, `ret 4`, the gadget's vtable +54h. Its pair 0x448F13 is
  `gadgetUnreal` (0x442BE7; vtable +58h(0)). The progress bar parser (0x5CC7E0..) sets the
  background (0x5CAF02) only when both `progressBarBackground` and `progressBarBackgroundSize` are
  given, and the mask (0x5CD0F5) as a second drawable; with no background nothing is drawn (seen
  in game).
- *The hook* at 0x4C83DF (`lea ecx,[esp+70h] / call 4010CAh`, 9 B, after the colour bar was shown; same
  stack level as 0x4C82E6): `UhcOverhealPortrait(panel, group)` works on the game's green bar
  `[panel+310h]`, adding no gadget. If `[group+1Ch]` is ≥ 0.999 (every unit at or above its 100 %) and the
  average of min((HP − reference) / reference, 1) over the group's units (IDs `[group+10h]`, count
  `[group+14h]`; 0 for an unmarked unit) is above 0, it fills the bar with 1 − that share, and the right end
  shows the bar's background drawable `[bar+140h]`. The first time, it gives that drawable the overheal
  texture through its vtable +7Ch, `thiscall(drawable, BString* name, -1)`, as the setter 0x5CAF02 does. It
  must not call 0x5CAF02 itself: that creates a new drawable, with no size, and nothing shows. When the
  overheal ends it puts `ui\ingame\ui_health_bar` back, the texture of the three bars in the UI data.
  Then the stolen free, → 0x4C83E8.
- *The texture:* `bar=<texture>`; else, when `art\ui\uhc\health_overheal.ddt` is in the game folder at
  startup (a `GetFileAttributesW` relative to the working directory, the exe's folder), `ui\uhc\health_overheal`,
  the orange bar of `tools/make_bar.py` of aoe3-blender-tools (16×8 texels, DXT1, the layout of the stock
  `ingame_ui_health_yellow`, shaded from the segment's default `FF8C00`); else the stock
  `ui\ingame\ingame_ui_health_yellow`, with a log line. A file packed in an archive is not seen by that check: such
  a mod names it with `bar=`. A texture the game cannot find (tried with `bar=ui\uhc\nonexistent`, 2026-11-12)
  draws nothing: the bar's right end stays empty, with no error and no crash. The texture does not follow
  `segment=RRGGBB`: the DLL writes no file. The minimized UI (`optionminimizedui`, profile option 49h, read through
  0x402CE9 at 0x4C8233 and 0x661E03) has these bars too, and a later pass raises the colour bar, so a
  gadget added in the UI data stays under it.
- *Observed in game:* a Musketeer at 165/150 had the bar 90 % green, 10 % orange; damaged, the
  stock bar showed; healed back, the orange end returned; selecting the Surgeon, a Pavilion, a
  mine or a tree after it showed their stock bar.

**The Overheal row** (`stat[=Label]`).
- *Stock.* The stat panel fill FUN_004D70ED writes the HP row, then sets the next row
  (`mov edi,2 / mov [esp+2Ch],edi` at 0x4D76DB). For a multi-selection the Group Health branch
  (0x69A9D3..0x69AB0F) writes row EDI: the label and value gadgets from `[panel+174h+row*4]` /
  `[panel+198h+row*4]` through 0x4C519C (a `{handle, gadget}` reference, released with 0x40431B),
  the label `L"Group Health"` (0xC36838, a literal) with style 0D6F5D0h, the value with style
  0C6657Ch (vtable +84h), the text (+80h), +54h, the help texts `[gadget+68h]` cleared (0x401A12
  from `L""`, 0x40196F), then `add edi,1 / mov [esp+2Ch],edi`.
- *The hook* at 0x4D76DB (9 B) is shared since 2026-11-26 (`statpanelrows.*`, `AddStatPanelRow`, with
  [`nurseryFactor`](#nurseryfactor)'s row after this one): the two stolen moves, then `UhcStatPanelRows(panel =
  [esp+50h], unit = [esp+38h], row = EDI)`, which asks each key's row in `kFeatures` order while rows are free. This
  key's, `UhcOverhealStatRow`, writes the row for a marked unit with the same calls (label `Overheal`, the cfg text, or
  a string table entry through 0x58EA52; value `overheal/capacity`, coloured with `segment` while above 0) and returns
  true; the hook adds the rows written to EDI and `[esp+2Ch]`, so the Group Health row and the rows after it move
  down. → 0x4D76E4 (EAX, ECX, EDX and the flags are written there before they are read).
- *Observed in game:* `Overheal 15/15` (orange) at 165/150, `0/15` when damaged, `16/16` under a
  MaxHP aura, `0/40` for a marked Explorer at its 100 % in a skirmish.

`MaxHPOnly`: an `AddTechSubtype` handler writes `[proto+98h]` through 0x7F892A and skips the rescale 0xA0036E.

### overhealSources

**Marked and reference** are `overhealHitpointBars`': `overheal_hooks.asm` exposes its helpers as
cdecl functions (`UhcOverhealMarked(proto)`, `UhcOverhealReferenceOf(unit)`,
`UhcOverhealRatioOf(unit)`), so both keys share one definition.

**How HP is gained.** Every heal of a unit adds HP through FUN_004823A3 (`thiscall(unit, amount,
flag)`, `ret 8`): when the unit's state allows it, it calls the setter FUN_004820A1(HP + amount,
flag) and, for an amount above 1e-6, adds it to a "healed" total `[[unit+0B4h]+0E4h]`. The setter
stores HP `[unit+64h]`, clamps it to [0, max] (the per-unit override through 0x6A2CB3, else
`[proto+98h]`), updates the damage visuals (0x9CB73E) and, with `flag`, calls 0x482152. REA
Evidence `ev_b83c97e4…` (both). The heal action's tick FUN_009E0B53 (`ev_e9a25933…`) heals only
while HP < max (`call 480408h` at 0x9E0BBB, then `jnp 9E0D3Fh`, which ends the action with state
10) and adds `0x487C45(target) × [world+318h] × [world+104h]` at 0x9E0CE9. The callers of the
adder:

| Caller of 0x4823A3 | Function | What it is (static reading unless marked) | With `overhealSources` |
|---|---|---|---|
| 0x9E0CE9 | FUN_009E0B53, the heal tick | the heal action (surgeons, monks, priests…), automatic or ordered (seen in game) | a source healer: up to the max, as in stock; any other healer: up to the reference, and the action ends there (seen in game) |
| 0x9D3BFD, 0x9D3C10, 0x9D3E2F, 0x9D3E42 | FUN_009D35CE | heals of max × rate / `[proto+0CCh]`; the function is slot 15 of the vtable 0xB97330, whose constructor 0x9D302B passes action type 15h, registered as `Trade` (0x522ADC); what makes it heal in play is not known | reference |
| 0x67A03B | FUN_00490476 | the fire pit's Regeneration dance (idle units, `[world+104h]` × max × 0.01) | reference (seen in game: marked Musketeers healed from 90 to 150 only) |
| 0x490881 | FUN_004905E1 | per-unit regeneration (inferred: `CanAutoHeal` / `UnitRegenRate`) | reference |
| 0x9CFA77, 0x9D0C16 | FUN_009CF93B, FUN_009D0A4D | heals of the action's own unit `[esi+10h]`, proportional to its max (inferred: self heals) | reference |
| 0x7C378C, 0x8CCA6F | FUN_007C369B, FUN_008CC89F | heals proportional to the max (inferred: powers and effects such as `PowerHeal`) | reference |
| 0x9E594D, 0x9E5AEB | FUN_009E5583 | repair, which pays its cost first (0x8D946A) | reference (stock data repairs buildings, which are not marked) |
| 0x9E03C0, 0x8EDCC5 | a chunk filed under 0x9E0D4E, FUN_008EDAFD | additions capped at a total (`[esi+6Ch]`, `[ebp+12Ch]`; inferred: build or repair progress) | reference |
| 0x49B822 | FUN_0049B3D9, TakeDamage | damage, a negative amount | not touched |
| 0x6A4AF5 | FUN_004DCFE2 | damage that leaves at least 1 HP, negative | not touched |

The 32 direct callers of the setter FUN_004820A1 (unit creation 0x49839B, transforms, the modifier
rescale 0x9C73xx, triggers, the dance's 1-HP floor 0x67A02B, …) set HP rather than add it and are
not touched: creation starts a unit at `InitialHitpoints` (its reference), and the rescale keeps the
HP ratio. A `Hitpoints` tech adds the same amount to `InitialHitpoints` and the max (0x8F97CD), so
the reference follows it; an aura that changes the max rescales the reference (overhealHitpointBars).
A source counts only through the heal tick: a marked area healer or regeneration does not
overheal (only the single-target heal action knows its healer).

**The hooks** (`hooks/overhealsources_hooks.asm`):

| Site | Stolen | Hook does | Continues at |
|---|---|---|---|
| 0x4823A3 | `push ecx / push esi / mov esi,ecx / cmp [esi+8],8` (8 B; ECX = unit, `[esp+4]` = amount) | `UhcOverhealAddHp(unit, &amount)`: a positive amount on a marked unit is lowered to reach at most the reference, unless `g_uhcOverhealAllow`; then the stolen bytes | 0x4823AB (`jbe`, on the stolen `cmp`) |
| 0x9E0BBB | `call 480408h` (ECX = EDI = target, ESI = the unit's heal action: healer `[esi+10h]`, the player's copy of its tactics action `[esi+4]`) | `UhcOverhealTickLimit(target, action)` in ST0: for a marked target, the reference when the action does not overheal, min(reference × cap %, max) when it does with a cap; else the stock max | 0x9E0BC0 |
| 0x9E0CE9 | `call 4823A3h` (the tick's heal; ESI the unit's action) | `g_uhcOverhealAllow` = 1 for an overhealing action (its cap in `g_uhcOverhealAllowCap`), the stolen call, then 0 | 0x9E0CEE |
| 0x9CD984 | `call 45F295h` (ECX = ESI = candidate, healer `[ebp+4]`) | `UhcOverhealSearchRatio` in ST0: for a marked candidate, HP / reference when none of the healer's actions overheals, HP / the highest limit of those that do (stock rules: 0 below 1e-6, 1.0 from the limit: no candidate); else the stock ratio | 0x9CD989 |

**Which action overheals (2026-11-21, JTMaston's #85).** The heal tick's action ESI is the unit's action; `[esi+4]` is
the player's copy of the tactics action, the same object whose `<rate>` entries the tick reads (`mov ecx,[esi+4]` /
`call 487C45h` at 0x9E0CC3, REA `ev_d240f09a…`, `ev_5be39379…`: the rate list `[action+0Ch]`, count `[+10h]`, 0Ch-byte
entries). `<CanOverheal>` and `<OverhealCap>` (percent, 100 to 1000) come through the shared action tag hook
(`actiontags.h`), from a tactics `<action>` or a `<ProtoAction>`, and are kept by (proto ID `[proto+4]`, action name index
`[action+4]`), which every player's copy keeps; a tactics file read for several protos gives each its own entry. A tag on
an action whose name has no "heal" is logged and dropped (the heal tick would never read it). The Data subtypes
`CanOverheal` and `OverhealCap` (`AddTechActionSubtype`, `action=`/`allactions=`) keep a value per copy of an action (its
address, guarded by the same key) through the stock value function 0x7F892A, from the tag's value (or 0, none): `Assign`
1 or 0 turns it on or off, `Absolute` adds. A value above 0.5 is on. Both maps are cleared at each database load; the
techs apply again on a load. The search knows only the healer, so it takes the best of the healer's actions (its proto
copy's action set `[proto+44h]`, `[set+1Ch]`, count `[set+20h]`): one without a cap wins, else the highest cap. A cfg
type is an explicit opt-in: a healer of it overheals with every action, to its `cap=`. In the add-HP hook, with
`g_uhcOverhealAllow` set (only the heal tick of an overhealing action sets it), the amount is lowered so that HP stops at
reference × cap / 100; it is not scaled any more (the cfg's `rate=` is gone: above the reference the action heals at
its own `<rate>`, as below it). The tick's limit and the search's ratio use the same limit, so the heal action ends when
the unit reaches it (state 10) and a unit at its cap is no candidate; without that a capped healer would heal 0 HP
forever. The C functions return a float in ST0 (x86 `__stdcall`), and change only EAX, ECX and EDX, as the stolen
calls do.

**Why it is safe.** The decisions read only protos and HP (the same on every machine) and the cap
only lowers a positive amount; damage (negative amounts) and the setter's other callers are
untouched. At 0x9E0BBB the FPU stack is empty and ECX/EDX are written again after 0x9E0BC0; the
add hook keeps every register (pushad) and redoes the stolen `cmp`, whose flags the `jbe` reads.
The tick hook's flag is set and cleared around one call (no re-entry: the adder does not call the
heal tick). The direct heal order (command predicate code 41h, FUN_004C6CD7, "HP < max") still
accepts a marked unit at its reference; its action then ends on its first tick.

**Observed in game:** a marked Musketeer hit to 90 was healed by a surgeon to 150 and stayed there
with the surgeon idle; an Indian monk marked as a source healed it to 165; the unmarked Pikeman went
back to its max. A Manor healing with `HCXPFlorenceNightingale` (the same heal action) stopped at
150 too. A direct order on a marked unit at its reference: the healer took the order (action type
9), walked to the unit and went idle on arrival. A marked unit's own regeneration (an Indian monk
marked 250 / 275 for the test) stopped at 250; without the key it reached 275. A knocked-out hero
(action type 2Bh, the `'+'` that 0x482152 tests) regenerates and gets up at about 40 % of its HP
in stock, below its reference, so the cap does not keep it down. The Regeneration dance, an area
heal that is not a building, healed marked Musketeers from 90 to 150 and unmarked Pikemen to their
max.

### overhealDecay

**One world update wrapper.** `damageOverTime` used to own the `jmp` at the world update's entry
(0x481A57). It is now `worldtick.cpp` / `hooks/worldtick_hooks.asm`: the first key that needs a
per-step tick checks the site and writes the `jmp` to a `__fastcall` wrapper with the stock thiscall
frame (`bool(world, -, int, deltaMs)`, `ret 8`), which calls the stock body through a trampoline
that re-executes `sub esp,0Ch / push ebx / push ebp` and jumps to 0x481A5C, then calls each
registered tick in order (`AddWorldTick`). `damageOverTime` and `overhealDecay` register in their
`kFeatures` order, so with both on, poison ticks run before the decay on every machine.

**One add-HP hook.** The hook at the entry of FUN_004823A3 (see overhealSources) is written by
whichever of `overhealSources` and `overhealDecay` applies first. With `overhealDecay`, a positive
amount that still takes a marked unit above its reference (after the `overhealSources` cap, if that
key is on) notes the unit with the game time `[world+108h]`.

**Regeneration is not a gain that waits.** The unit's own regeneration (FUN_004905E1, `call
4823A3h` at 0x490881) and the Regeneration dance (0x67A03B) add a little HP on every step of an
idle unit. Counted as gains, they restarted the delay on every step, so an idle unit that
regenerates never decayed (found in a skirmish: a marked Explorer regenerated from 180 to 220).
Both calls are replaced (5 B each, → 0x490886 / 0x67A040) by a stub that sets
`g_uhcOverhealRegen` around the stolen call; a gain made with it set notes the unit only if it was
not noted, with a time `delay` in the past, and never restarts the delay. Heals restart it as
before.

**The decay tick.** The noted units are a `std::map` keyed by unit ID, so every machine walks them in
the same order. The world update also runs for other worlds (the home city's; it compares `this`
with `[game+13Ch]` at 0x481D01), so the tick returns at once unless `world` is `[game+13Ch]`:
another world must not decay or look like a new game. After each update of the game world: the elapsed game time since the last tick (`[world+108h]`,
never the real clock; another world, the time going back or a jump of the step count `[world+F8h]`
forgets every unit, and so does a data reload); for each unit, the unit table lookup
(`[world+0Ch]`, `[unit+10h]` = the ID), alive (`vtbl+A4h`), still marked (and of a listed type);
gone, dead or unmarked units are forgotten. A unit at or below its reference is forgotten; one whose
last gain is less than `delay` ago waits; otherwise HP = max(HP − rate × elapsed, reference)
through the stock setter FUN_004820A1(unit, value, 0).

**The rate and delay per proto (2026-11-21, JTMaston's #85).** `<OverhealDecay delay="S">R</OverhealDecay>` comes through
the shared proto tag hook (`prototags.h`; the attribute through the XML attribute reader 0x598F37 and 0x402733) and is
kept by proto ID `[proto+8]`: R % of the reference per second, S seconds. The Data subtypes `OverhealDecay` and
`OverhealDecayDelay` (`AddTechSubtype`) keep a value per player's copy of a proto (its address, guarded by its ID), from
the tag's (or the default's) through 0x7F892A; a target that names a unit type reaches every proto of the type, as the
stock subtypes do. At each gain and each tick the unit's proto copy `[unit+5Ch]` gives the rate and delay: its tech value,
else its tag, else the cfg line's values, else 2 % and 0 s. A rate of 0 does not note the unit, and stops a noted one.
Both maps are cleared at each database load. The saved marker (stat 65h) still holds only the last gain; the rate is
read again after a load.

**`holdNear`.** For a unit past its delay, before the decay, each `holdNear` entry runs the world's spatial query
FUN_004A1C55(world, &[unit+14h], metres, 1, list) (`noTrainNearEnemyTC`'s: the IDs of the units whose distance to the
point, their vtable slot B8h, to their edge, is at most the radius; it fills the obstruction manager's scratch list
and copies it out). Any listed unit that is not the unit, has the same owner `[u+44h]`, is of the type (is-a
0x44D7FA), alive (`vtbl+A4h`) and built (0x44DDB4) holds it: the unit is skipped for this tick. Only whether one exists
decides, not the query's order (the logged one is the first found). The query runs in the world tick, after the stock
update, outside any loop over units, and only for units past their delay, so its cost follows the number of
overhealed units. The list is the DLL's and is reused. Sites `UnitsNearPoint`, `IsBuilt` (verified only with
`holdNear`).

**The setter's effects** (REA `ev_b83c97e4…`, `ev_241c1390…`): it stores HP, clamps it to [0, max]
(the per-unit override through 0x6A2CB3), updates the damage visuals of a unit with damage stages
(0x48223F(22h), 0x9CB73E per stage) and the animation state (0x48233B(7) → 0x487A21); with a
non-zero flag it also runs 0x482152, the death check (HP < 1e-6 kills or destroys the unit and sends
its events). The decay passes 0: a HP above the reference never needs the death check. Nothing in
the setter is an attack: the "under attack" alerts and events come from TakeDamage (FUN_0049B3D9),
which the decay does not call.

**Why it is safe.** The decay reads only game state (unit HP, protos, game time) and walks units in
ID order; it never sets HP below the reference (which is above 0) and never kills. The tick runs
after the stock update, outside any stock loop over units. The map holds only units that gained
overheal and drops them when they are back at the reference, so the cost is small.

**Observed in game:** with `overhealDecay 2 3`, a marked Musketeer at 165 went 160.2, 154.1, 150.0
in about six seconds of game time once its source healer was gone, and stayed at 150; with the
healer alive, the decay started 3 s after each heal and the healer healed it back. `2% 1
Musketeer` decayed 3 HP/s (2 % of 150); `2% 1 Pikeman` left the Musketeer at 165. In a skirmish
against the AI (home city world present), a marked Explorer stayed at its 100 % (180) while
regenerating; without the key it reached 220.

### steadyHitpointBars

**The stock position.** The bar chunk of the unit visual update (0x45FAA2..0x45FB6C; ESI = unit) places the floating
bar before it queues it (0x45FB71):
- with a visual (`[unit+60h]`), v = the vector at 0xC66550 (`[esp+2Ch]`), then `call 45F22Dh` (ECX = unit; arguments
  `[[0C6DF88h]]`, inferred to be the `HITPOINTBAR` tag's ID, 0, &v, 0, 0). FUN_0045F22D, `bool thiscall(unit, tag, byte,
  vec3* out, byte world, int)`, `ret 14h`, asks the visual (0x45F1DC) for the tag's position in model space and copies it
  to `out` (with `world` = 1 it would go through the unit's own matrix, 0x4843DA). 0x45F1DC takes the animation file of
  the visual's current animation (0x45F01C: the file index `[[visual]+54h][[[visual+18h]+10h]]`, the file
  `[[[0C66240h]+0C13Ch]+index*4]`) and 0x45F072 looks the tag up in its name table (`[file+8]`, 0x407405) and
  interpolates its track (`[file+34h]`, 12-byte keys) at the visual's clock `[visual+8]` over the duration `[file+58h]`;
  a file of duration 0 returns its first key. AL = 0 when the file has no such tag;
- `test al,al / jz 460633h` (0x45FB24); with the tag, 0x406BDB(&v, &out) takes v to the world with the unit's matrix
  `[esp+74h]` into `[esp+18h]`, the bar's position;
- without a visual or the tag, the cold block 0x460633 copies the unit's position `[[esp+48h]]` and adds
  (`[0x4605C1(unit, &tmp)+4]` + `[[unit+0B4h]+24h]`) x `[unit+0A8h]` + 1.0 to its y, then rejoins at 0x45FB3F.

The tag is a sampled track per animation file, with no rest pose: an animation without it puts the bar at the other
height. The tag table comes from the animation's tag file, `<animation>.gr2.precomp`: FUN_0059DDCE reads its "MS" block
(the track count, a rotation and a position track per tag bone, the name-to-track map, the duration) into that table;
an animation whose tag file has no `HITPOINTBAR` gets the stock fallback above (0x460633). Adding the tag to those files fixes the
data itself, with the key off. Observed with a trace: a Hussar's idle file has the tag at 4.07..4.15 (model y), its gallop has none (2000 of
4698 calls without it in one charge); a Settler's stays at 2.97, a Caravel's at 9.86; a Barracks never had it.

**The hook** (`hooks/steadybar_hooks.asm`):

| Site | Stolen | Hook does | Continues at |
|---|---|---|---|
| 0x45FB24 | `test al,al / jz 460633h` (8 B; AL = tag found, v at `[esp+2Ch]`, ESI = unit) | `UhcSteadyBarLocal(unit, &v, AL)`: AL = 1, v holds the steady position | 0x45FB2C (AL = 1) or 0x460633 (AL = 0) |

`UhcSteadyBarLocal` keeps, per unit pointer (checked against the unit ID `[unit+10h]` and the proto `[unit+5Ch]`, so a
reused pointer or a transform starts over), two buckets of 3 s of "tag time" (time counted only while the tag is found,
at most 100 ms per call): the lowest and highest x, y and z of v. The target is the highest y and the middle of x and z
over both buckets, and the output moves toward it by at most 1.5 model units a second of real time. With the tag, v is
replaced by the output; without it, v is set to the output (AL = 1) once the unit's tag was seen, else AL = 0 and the
stock fallback runs. A static tag gives lo = hi = v, so the output is v itself: a building or a ship whose tag does not
move keeps its exact place. Units that are not of a listed type (is-a 0x44D7FA, cached per proto) return the stock AL
untouched. The map is cleared when the world `[[0C66234h]+13Ch]` changes and purged of units unseen for 10 s.

The `overhealHitpointBars` segment is queued at 0x45FB6C from `[esp+18h]`, after 0x406BDB, so it follows the bar. The
rank marks of `veterancyBonus` hang on the bone `bonethatdoesntexist` (the unit's origin) at a fixed height per class,
so they never followed the tag.

**Why it is safe.**
- The site decodes at instruction boundaries (0x45FB24 `test al,al`, 0x45FB26 `jz` rel32) and no reference lands at
  0x45FB25..0x45FB2B (REA: no xref to 0x45FB2C); both continuations are the stock targets of the `jz`.
- On both paths EAX, ECX, EDX and the flags are written before they are read (0x45FB2C: `lea ecx` / `push ecx` / `lea
  edx`; 0x460633: `mov eax,[esp+48h]` / `mov ecx,[eax]` / `mov edx,[eax+4]`); the helper keeps EBX, ESI, EDI and EBP,
  and the x87 stack is empty at the site and after the helper.
- Display only: the chunk only places what is drawn this frame (one caller of the queue, 0x45FB67); the clock is the
  real one, which only this machine's drawing reads. A map lookup per bar per frame; no allocation once a unit is in it.

### inventoryBars

**Stock: Alt shows the HP bars.** FUN_00451F9D, the unit visual update, decides each unit's floating HP bar (REA
`ev_d87e8471…`, `ev_4e0af08b…`, 2026-11-12). At 0x452EA0 it asks the input object `[[[0C66244h]+74h]+2Ch]` for modifier 2
through its vtable +34h (`call 473E37h`, a `jmp eax`; the same query with 0 and 1 is Shift and Ctrl at 0x436434) and
keeps the answer in BL (0x452EBD). Then: the unit's vtable +A4h test (0x452ECF, false for a corpse), proto flag 5 (the
HP bar flag, the inlined bit test 0x452ED8..0x452F1D), and in 0x45F78B the bar's conditions; the last one is profile
option 57h (`[esp+28h]`, read from the option list FUN_00450FDA) and BL (0x511D80). [O, in game] A posted `WM_KEYDOWN`
of `VK_MENU` sets it: with it every unit with the flag shows its bar; a mine and a corpse have none.

**The inventory.** `[[unit+B4h]+94h]+4` is the unit's resource list, `[[unit+5Ch]+E0h]` its proto's resource object,
whose `+0` is `InitialResource` (the lists of [`transformInventory`](#transforminventory): entry r XORed with
`[0C6DF14h + 4r]`, the total at `+4` XORed with `[0C6DF10h]`, the count `[0C6DF38h]`).

**The bar.** The fill is the inventory's total / the `InitialResource` total, clamped to [0, 1]; the colour is that of
the resource the unit holds most of (an empty one: the one it was created with most of): gold `FFD23C`, wood `B4783C`,
food `E8503C`, any other `other=` (default `50B4FF`). It is a record of the shared floating bar queue (`floatingbars.h`)
of kind 80494E00h, the low byte the resource: the writer moves its six vertices down the camera's up vector A
(`[camera+1Ch]`) by 0.17 × scale (the quad is scale / 8 high) and gives them the colour. Two ways in:

| Site | Stolen | Hook does | Continues at |
|---|---|---|---|
| 0x45FB6C (shared, `floatingbars_hooks.asm`) | `jmp 4516B3h` | the observer: unless the bar is a foundation's, with BL or `always`, the bar at the HP bar's position | 0x4516B3 |
| 0x452F1B (`inventorybars_hooks.asm`) | `test al,al / jne 45F78Bh` (8 B) | a unit with the flag: 0x45F78B as in stock; without (a mine, a bush), with BL or `always`, `UhcInventoryNoHpBar(unit, [esp+48h], BL)` | 0x45F78B or 0x452F23 |
| 0x452ED4 (`inventorybars_hooks.asm`) | `test al,al / je 452F23h / push 5 / mov ecx,esi` (8 B) | a live unit: the stolen push and mov; a corpse (a hunted animal), the same call | 0x452EDC or 0x452F23 |

`UhcInventoryNoHpBar` draws only what the local player (`[game+3C0h]`) sees now: bit `local` of the visibility mask
`[[unit+B4h]+ACh]` (0x486A60), since the update also runs under the black map and the fog. Trees (the built-in unit
type `Tree`) are left out unless `trees` is given. Its position is that of the stock fallback (0x460633): the unit's
position (its `y` from `[unit+18h]` when the fallback's base `[[esp+48h]]` holds 0) raised by the visual's height
(FUN_004605C1, `thiscall(unit, vec3* out)`) plus `[[unit+B4h]+24h]`, times the scale `[unit+A8h]`, plus 2 (1 more than
the fallback, so a low model does not cover it).

**Why it is safe.**
- Display only: it reads the inventory, the mask and the camera, and queues bars, which only this machine draws. Alt is
  this machine's key.
- 0x452ED4: no branch lands in 0x452ED5..0x452EDC (`cs` scan; 0x452EC5 is the nearest target). 0x452F1B: the only
  branch to it is the `jmp` at 0x452F14, to its start. At both, ESP is the one of the bar chunk, whose fallback reads
  `[esp+48h]` (the pushes of the inlined bit test are popped at 0x452F11 / 0x452F18), and EAX, ECX, EDX and the flags are
  written before they are read at every continuation. The hooks keep every register (`pushad`).
- BL is not written between 0x452EBD and 0x45FB6C (the bar chunk, its cold blocks 0x6A1431 and 0x460633, and the callees
  keep EBX).
- Cost: with Alt up, a compare and a jump per unit and frame; with Alt down, one inventory read per unit drawn.
  Measured below in the modding guide.

### playerIcon

**Stock: the lobby icon.** Read with REA and capstone (2026-11-13; bundles `lobby-avatar-59-20261113.json` and
`player-icon-59-20261113.json` in `rea/evidence/age3y-b1a1dab7/`). Each of the 8 slots of the LAN setup page is an object
with `[+0Ch]` the lobby settings, `[+14h]` "this is the local player's slot" (written by FUN_0077649C, which enables the
slot's own controls with it), `[+18h]` the slot's index, `[+1Ch]` "an AI's slot" (the host may edit it) and `[+28h]` the
icon gadget `mpsetup-PlayerN-Avatar`. A player field's setting ID is 3Ah + (index + 1) × 18h + field; AvatarID is field
10 (string), Civ field 4. The slot's handler 0x776BED(settings, id, flags) (`ret 0Ch`, flag 10h) dispatches the field:
- Civ (case 0x776F73) and AI personality (case 0x7772D3) end in FUN_00774D56, through the calls 0x776FFC and 0x7773DD
  (its only callers): it puts the civ's `<portraittexture>` on the icon;
- AvatarID (case 0x776DEA), for a slot that is not an AI's: reads the string, looks it up in the avatar table
  (`[[0xC66234]+140h]` → 0x7EEEE7 → 0x7A77EF; an empty name gives the table's first entry) and puts the record's image on
  the icon (0x638823). An unknown name leaves the icon alone.

The lobby settings: string get 0xA263C7(id, string*) on `[settings+20h]` (0x518B57), string set 0xA26361(id, string*),
which stores the value and sends it to the host, which sends it to every peer (FUN_00A2B475). The game string is one
pointer to the characters (header 10h bytes before; constructor 0x401A12, destructor 0x4010CA).

**The hook.** The two calls of FUN_00774D56 call `UhcPlayerIconHook` (`playericon_hooks.asm`), which runs FUN_00774D56,
then `UhcPlayerIconAfterPortrait(slot)`:
- returns at once for an AI's slot, a slot index out of 0..7, or lobby settings with no session;
- on the local player's slot, if its AvatarID is not the cfg's value, writes it with 0xA26361 (that runs the handler's
  AvatarID case once by itself);
- if the slot's AvatarID is not empty, calls the slot handler with that field's ID and flag 10h: the stock AvatarID case
  puts the avatar back over the civ portrait, or leaves the portrait when the name is not in the table.

| Site | Stolen | Hook does | Continues at |
|---|---|---|---|
| 0x776FFC (civ change) | `call 774D56h` | `call UhcPlayerIconHook` | the caller's next line, 0x777001 |
| 0x7773DD (AI personality change) | `call 774D56h` | the same | 0x7773E2 |

**Why it is safe.**
- Lobby only: the icon is drawn by this machine; the value written goes through the game's own setter into a field the
  game already sends and that nothing in the simulation reads.
- FUN_00774D56 takes ECX alone and returns with a plain `ret`; neither caller reads EAX, EDX or the flags after it
  (0x777001 compares `[esi+10h]` with EBX, 0x7773E2 is `lea ecx,[esp+84h]`). The hook keeps ECX for the helper and
  every register and the flags around it (`pushfd`/`pushad`).
- The handler call from the helper is the same call the settings would make for that field; the slot handler checks
  that the ID belongs to this slot. Re-entering it from the setter is what stock does when any field changes.
- The verified bytes: both calls, the heads of FUN_00774D56, the handler and its AvatarID case, the getter, the setter
  and the string functions (sites `PlayerIcon*`).

### workRateByAbstractType

An action's rates are a list of `{unittype ID, rate, -1}` (`[action+0Ch]`, count `[action+10h]`, 0Ch bytes
each). The lookup 0x487C45(target) returns the entry of the target's own proto (`[[target+5Ch]+8]`) if there
is one, else the first entry whose abstract type the target carries. The Data effect subtype WorkRate (3) is
case 0x8F987C of applyData and 0x8FB11A of unapplyData: it reads the one entry the effect names with
0x49EBB3, computes it with 0x7F892A, using the base proto's entry as the base, and writes it with 0x5FA2FC.

The hooks sit at the head of both cases and call `UhcWorkRateByType(proto, baseProto, actionId, key, amount,
relativity, unapply)`. If `key` is a listed type, the function looks up the action in both protos' sets
(0x48D22E) and repeats the stock computation for each proto of the type that has an entry of its own. The
protos of a type are found once per database, with 0x44D7FA, at the first such effect: their types are not
read yet at the database load callback.

**Why it is safe.**
- The head of each case is `mov r32,[r32+44h] / cmp r32,ebp` (5 B). The jump table is the only way in: no
  branch lands in those bytes. The hook re-executes them, so the flags are the stock ones at the continuation,
  the `je` at 0x8F9881 / 0x8FB11F. The registers are saved around the call and the x87 stack is empty there.
- An entry with no rate is skipped, so no entry is ever added.
- The order of the list of protos is by ID, and nothing depends on the local player, so the result is the
  same on every machine.
- Tech effects are re-applied through applyData when a game loads, on protos rebuilt from the base, so the
  rates are correct after a load and nothing is stored in the DLL.

### autoGatherScaleByContained

The tactics flag `ScaleByContainedUnits` is bit 18 of the action's flag bytes (`[+64h]`, bit count `[+68h]`, set
at 0x5FEE1A). The attack code reads it at 0x4996C7: the multiplier is the unit's contained count `[unit+74h]`
(0x6A4B83), and if it is above DamageFactorCap `[+48h]` and that is above 0, the cap (0x4996E8..0x49970A). The stat
panel reads it too. The AutoGather rate getter 0x49EBE4, `float thiscall(action, resource)`, does not.

The hook replaces the getter's first three instructions. Since 2026-11-25 it is shared (`autogatherrate.*`,
`hooks/autogatherrate_hooks.asm`, `AddAutoGatherRateFilter`) with [`nurseryFactor`](#nurseryfactor): it asks
`UhcAutoGatherRateAsk(action, resource)` (stdcall, C), which runs each key's filter in `kFeatures` order. When none
applies, the hook re-executes the three instructions and goes on at 0x49EBEA, so the stock getter runs bit for bit.
Otherwise it calls the getter's body, so that the body's `ret 4` comes back to the hook, and multiplies ST0 by the
product of the factors, a float in `g_uhcAgFactor`. This key's filter follows the attack code's rule: the contained
count, or the cap when the count is at least the cap and the cap is above 0. Both are exact as floats, so the product
is the one the earlier hook computed on the x87 stack.

**Why it is safe.** The hook sits at a function entry, so EAX, ECX and EDX are free and the x87 stack is empty; the
asker is a C function that keeps EBX, ESI, EDI and EBP, and the hook keeps ECX around it. No branch lands in the six
bytes. Every caller gets the same rate: the update 0x48D16E, both panels (0x6992BD, 0x69B005), and the two that
look for a resource with a rate (0x69D232, 0x9CFE1E). The factor comes from simulation state only.

### nurseryFactor

`src/features/nurseryfactor.cpp`, `hooks/nurserycmd_hooks.asm`; the shared `autogatherrate.*` (above),
`garrisonobservers.*`, `statpanelrows.*`, `progresspie.*`, `panelbuttons.*`, `syscalls.*`, `prototags.*`,
`techsubtypes.*`, `worldtick.*`, `unitpanel.*`, `datarefs.*` and `savedmarkers.h`. The design and the questions behind
it are in [nursery-design.md](nursery-design.md). <!-- private -->

- **Tags** (`AddProtoTagHandler`): the fourteen `NurseryFactor*` tags, by proto ID, each checked for its range; a bad
  value is logged and the tag skipped. Any of them makes the proto a nursery; the cap is 10 unless `NurseryFactorMax`
  says otherwise. Two per-proto-ID byte tables say which protos have a factor and trickle (for the rate filter) and
  which take garrisoned units (for the garrison observer). `NurseryFactorGarrisonUnit` and `NurseryFactorCommand` read
  attributes through the XML getter 0x598F37; their names (units, types, resources) are resolved against the database
  once per data load (the proto array `[db+54h]` tells a new load), with the type table `[db+190h]`, the proto lookup
  0x5A2346 and the resource lookup 0x44709C. Each command name gets an index, the same on every machine (the order
  the protos are read).
- **The factor of each unit** is a table by unit ID, in ID order, filled as `researchGrants`' set is: 256 slots of the
  world's unit table `[world+0Ch]` per world update, round robin, and the whole table on a new game, a loaded one (another
  world, the time going back or the step count jumping) or before a `NurseryFactor` effect. A unit found with no marker
  gets `NurseryFactorInitial` (at most the cap). After each world update (`AddWorldTick`), a built unit (0x44DDB4)
  under its player's cap adds the game time `[world+108h]` since the last tick to its timer and grows a step per
  interval, up to the cap: linear, the step; exponential, the step of `t`, where **`t` follows the factor** (third
  version, 2026-11-26): with `S(t) = b^0 + ... + b^(t-1)`, `t` is the largest t with `floor(S(t)) <= factor` and the step
  adds `floor(S(t+1)) - floor(S(t))` (b^t for a whole b). `ExpGrowth(b, factor)` works it out each time it is needed
  (a step, the log, the panel's `{step}`): a loop over t in doubles, about log_b(factor) turns, with b 1 (t = factor)
  and b at most 0 or below 1 (every t once the factor reaches the whole part of `1 / (1 - b)`: t 65535, +0) handled
  first, so it ends. Nothing about `t` is stored: a sale, a shipment, a garrisoned unit, a tech, a capture or a new b
  moves it with the factor. At or above the cap, or with no interval, the timer is 0. Nothing cuts a unit above its
  cap: growth and the additions stop there, so a lowered cap leaves the extra until the unit spends it. Factor and
  timer are words 1 and 2 of a saved marker (`savedmarkers.h`, stat 6Bh, word 0 `NRSF`; word 3, `t` and a fraction
  in the second version, is written 0 and not read), written each tick, so a transform in place, which ends the
  unit's modifiers, has it written again at the next tick. A unit gone, dead or of a proto without a factor leaves
  the table.
- **The trickle:** the filter of the shared AutoGather rate getter multiplies a marked proto's rate by the unit's factor
  (the initial value while the unit is not in the table yet). The AutoGather update FUN_0048D13E then pays as stock: to
  the player through the add 0x49A98A (return 0x4C379D, which `incomeRates` counts), or, with the tactics flag
  `AddResourcesToInventory` (bit 4 of `[action+64h]`, handler 0x5FC84D), into the unit's own resource list through
  0x49A5E6, cut at its carry capacity 0x494503 when the proto asks for it. The first call of a game before its first
  tick builds the table from the markers first.
- **Data subtypes** (`AddTechSubtype`): `NurseryFactorMax`, `NurseryFactorInterval`, `NurseryFactorStep` and
  `NurseryFactorGrowthBase` keep a value per player's copy of the proto (looked up by pointer, checked against the copy's
  ID), computed by the stock value function 0x7F892A from the tag's value. `NurseryFactor` queues `(copy, amount,
  relativity)` for the next world tick, which runs 0x7F892A on each of the player's built units of that copy, with the
  unit's factor as the value and the initial value as the base, and clamps it to 0..max(cap, the unit's factor).
- **The load runs the Data effects again** (seen in game, 2026-11-25): after `loadGame`, each tech effect of these
  subtypes came through the handlers again, before the first world tick, in the order of the techs in the techtree
  (not the order they were researched): `NurseryFactorMax` +5 then `Assign` 4 gave a cap of 4 after the load where the
  game had 9. The per-copy values come back that way. A `NurseryFactor` effect must not run twice, so a queue found
  at the first tick of a loaded game (game time above 0) is dropped and logged. This is not the pass after a load
  0x94DDEA, which runs only flag-20h effects (see `unitTypeTechs`).
- **The shipment** (`AddTechPlayerSubtype`, as `shipmentCounts`): the techtree read stores `{unittype, nursery,
  consume}` in a list and the list index in the effect's field `+10h`. The list is never cleared: a loaded game reads
  the protos again (the data-load callback empties the other tables) but not the techtree, whose effects keep their
  indices (as `garrisonConvert`'s effect list). Until 2026-11-27 the data-load callback emptied it too, so a
  shipment researched after a load found no entry and shipped nothing (checked in game before and after the fix).
  When it applies, it takes (or counts) the factors
  of the player's living, built units whose proto is `nursery` or of that abstract type (0x44D7FA), in ID order, and
  returns the stock `FreeHomeCityUnit` (37h) with the proto and `amount x total`; nothing under 1 unit. A taken factor
  restarts its timer.
- **The garrison** (`AddGarrisonObserver`, the success tail of the load of a unit into another, 0x9C26E1): the
  observer runs inside the load, so it only queues `{container ID, unit ID}` when the container's proto has a garrison
  rule. The next world tick takes each entry whose unit is alive and still inside it (`[unit+6Ch]` the container's ID):
  the first rule whose type is the unit's proto or one of its types (0x44D7FA); a container at or above its cap keeps
  the unit; else the factor goes up by the amount, at most to the cap, the marker is written, and the unit is removed
  with the world's unit removal 0x4726B2 `(world, id, 0, 1)`, the call of the trigger `Destroy` (no death, no corpse).
- **The commands.** The UI syscall `nurseryFactorCommand(name)` (`AddSyscall`, group UI, so a `protounitcommands.xml`
  `<command>` can run it) looks the name up and sends the network command `uiTransformSelectedUnit` sends (0x7E7193,
  read with capstone, REA had no function there): `0x5695FC(player, 17h, 0, -1)`, the player list `0x5683B9(cmd, 1,
  &player)`, `[cmd+2Ch] = 3`, `[cmd+3Ch] = 0`, the units `0x5696E1(cmd, count, ids)` (the local selection group
  0x453B28's units of the local player whose proto has that command), then `[cmd+8Ch]`, where the transform keeps the
  target proto ID, gets `'NR' << 16 | index`, and `0x568A1A([world+8], cmd, 0, 0)` queues it. Every machine runs it in
  the world update: the command loop 0x7C86A4 calls the type's per-unit execute FUN_007D64F7 (vtable 0xB86F28 +54h,
  `thiscall(cmd, unit)`, `ret 4`, AL) for each unit its player owns. The hook at its head (5 bytes, `sub esp,1Ch / push
  ebx / push ebp`) sends a command with the magic to `UhcNurseryCommand(cmd, unit)` and returns its AL with `ret 4`;
  any other command takes the stock code (re-executed, then 0x7D64FC). A proto ID never has the magic: the stock
  execute itself refuses an ID out of the player's proto range (0x45311B, `cmp edx,[ecx+0E4h]`). The run, for a built
  unit of the command's player with that command: a negative factor needs that many, a positive one room under the
  cap; the units need room (PLACE, world vtable +14h, flags 2, on rings of 16 points from the building's edge, the
  units found before counting, as `killSpawn` places its animals) and under the population cap, with the stock
  maintain spawn's test (0x9E2F79) for all of them: the player's copy of the proto (0x45311B), its `PopulationCount`
  `[proto+0D8h]`; none (0 or less) or the flag `AlwaysAllowOverPopCap` (A3h, 0x45EE02) never stops them; with
  `AllowOverPopCap` (9Fh) the cap 0x4581A1 needs one free slot over the population `[player+78h] + 0x45805C`; else
  the cap must hold the population plus count x PopulationCount (sites `PlayerPopulation`, `PlayerPopCap`; this runs
  on every machine, from simulation state); then the cost: a ResList of the game's size
  `[0C6DF38h]`, filled with 0 (0x4E2617) and set per resource (0x58EF83), paid with the stock payment 0x8D946A (which
  tests the player's or the team's stock first). Any refusal changes nothing. Then the factor (as an addition, up to
  the cap), the marker, and the units, created by 0x498ACC at the spots found.
- **The buttons** (`AddPanelButtonFilter`): a button whose click is `nurseryFactorCommand("...")` asks, for the local
  selection's units with that command, the same tests (the factor, the cap, the population cap above, the cost through
  0x8D6BAE, or 0x8D6C1B with `[world+6912h]` set); with none that passes it is greyed (state 1: the panel darkens its
  icon; the hover highlight shows it bright while the cursor is on it), its click and shift-click emptied, and its
  rollover gets the last reason in red (0x443960): `2/10 minks: 4 needed`, `10/10 minks: full`, `Population cap
  reached`, or string 41543 "Not enough resources". The filter runs at every refresh, so the button is normal again
  as soon as a unit passes (seen when a House came). Interface only.
- **Panels:** `AddUnitPanelRow` (the minimized interface's AutoGather row, `[panel+33Ch]` / `+340h`) writes
  `3/10 minks` as the label (`(once built)` on a foundation), and `SetUnitPanelRowTip` puts the two rollover lines in
  the help text `[gadget+68h]` of both gadgets; the shared hook clears it before the next refresh's rows, so the stock
  row and the other keys' rows never show it. In the normal interface, the shared stat panel row hook
  (`statpanelrows.*`, 0x4D76DB, after the HP row; `overhealHitpointBars`' row moved there) writes the same text in the
  value gadget of the next free row, with the same help text; the stock AutoGather row comes after it. While the unit
  grows (built, under its cap, with an interval), both rows end with a small progress pie: an inline icon
  ` <icon="(N)(ui\uhc\pie\pie_KK)">`, frame KK = 32 x the share of the interval done (rounded down), one of the 32
  pictures of `art\ui\uhc\pie\` (aoe3-blender-tools' `make_pie.py`: 32 x 32 BGRA, the train overlay's blue at half
  alpha over grey, a gold frame, a clockwise wedge from 12 o'clock). The text layout puts an inline icon after the
  text on the same line, N + 1 px wide and as tall as the line, so N is the line minus 1, measured in game: the
  minimized row 17 px at a screen 960 px tall or more and 14 px below (N 16 / 13, as `minUIStats`), the stat panel 22
  and 17 px (N 21 / 16); the screen height is `[[0C66044h]+608h]`. No gadget is added and nothing can overlap: the
  icon moves with the text. The frames are looked for once, at startup (`GetFileAttributesW` of `pie_00.ddt` and
  `pie_31.ddt` relative to the game folder); without them the key gives the portrait's progress pie
  (`AddProgressPieSource`) instead, as the second version did. `{uhcNurseryFactor}`
  (`AddDataRef`, string) gives the first selected unit's `3/10 minks`. Text IDs resolve through 0x58EA52.

**Why it is safe.** Markers are made (0x4DD22D) only by the world tick and the commands, which run in the world update.
The garrison observer only queues; the unit is removed after the update, by the call the trigger `Destroy` makes. The
rate filter reads the table; the shipment and the commands write the table and the markers in the simulation, on every
machine, in the order the commands come. Deterministic: the table is keyed by unit ID, the copy map by pointer is only
looked up, the time is game time, the placement tests run in a fixed order, the command's index comes from the data.
The syscall, the buttons and the panels only read. The command hook returns exactly as the stock execute does (`ret
4`, AL; EBX, ESI, EDI and EBP kept by the stdcall C function). Cost: per update, 256 slot reads and one marker walk per
unit with a factor; per AutoGather rate call, one C call and a byte lookup for a proto without a factor; per transform
command, three compares.

### garrisonConvert

`src/features/garrisonconvert.cpp`; the shared `garrisonobservers.*` (new with this key), `transformcalls.*`,
`prototags.*`, `techsubtypes.*` (`AddTechProtoSubtype`, new with version 2), `worldtick.*`, `progresspie.*` and
`savedmarkers.h`.

- **Where a unit enters another:** FUN_009C24B5, `bool __thiscall(container, int unitId, int flag)`, `ret 8`, the load
  every way in goes through (eleven direct callers: the garrison and load actions, the triggers, the random map
  placement, the scenario load). It refuses a unit already inside one (`[unit+6Ch]` ≠ −1), a dead one, a full container
  (`[c+74h]` against the proto's maximum, 0x49EB5A) or one whose rules refuse it (0x4C2EC8); on success it writes
  `[unit+6Ch]` = the container's ID (0x9C25C2), appends the unit's ID to the list `[c+70h]` (0x401F74 at 0x9C26DC) and
  returns 1 at 0x9C2701. The shared hook replaces the 7 bytes at 0x9C26E1 (`mov edi,[edi+58h]` / `test` / `je`), after
  the append, with EDI = the container and ESI = the unit; it calls each observer, replays the three instructions and
  jumps to 0x9C26E8 or 0x9C26FF. The function's head is verified too, so a detour of it fails the key instead of
  leaving the hook unreached.
- **Tags** (`AddProtoTagHandler`): every `<GarrisonConvertTo delay="S" eject="B" from="Name">Name</GarrisonConvertTo>`,
  by proto ID, in order (32 at most): the names kept as text and resolved against each database once (the target with
  0x5A2346; `from` in the unit type name table `[db+190h]` through 0x58E685 / 0x40295B, the lookup `unittype=` uses,
  so a proto or an abstract type), the delay in seconds (0 to 3600; a bad one is 0), eject from `true`, `1` or an empty
  value. The XML attribute getter 0x598F37 returns true for `eject=""`.
- **The entries** (`AddGarrisonObserver`): the observer runs inside the load, so it only adds the container's ID to a
  set (in ID order) when its proto has tags. The conversions run after the world update (`AddWorldTick`).
- **The queue is the container's own list** `[c+70h]`, in entry order: the units still inside (`[unit+6Ch]` = the
  container), alive, of the container's owner, not of a proto that is a target of the building's tags (the player's
  copy's or the data's), and matched by at least one tag (no `from`, the same proto ID, or 0x44D7FA is-a). Nothing else
  is kept per unit, so a unit that leaves drops out by itself, and a captured building converts its new owner's units.
  The head is found again on each step (no allocation per tick).
- **The tag for the head:** the first tag from the building's cursor (wrapping) whose `from` matches it; the cursor then
  moves past that tag. The head's delay is that tag's.
- **The timer:** the game time `[world+108h]` since the last tick is added once per tick; when it reaches the delay the
  head converts and the rest carries over to the next one; when the head leaves before its turn, the next starts from 0.
- **The population** (before each conversion, the Maintain spawn's test 0x9E2F79 on the difference): `delta` = the
  player's copy of the target's `[proto+D8h]` minus the unit's; `delta ≤ 0` or flag A3h (`AlwaysAllowOverPopCap`)
  passes; flag 9Fh (`AllowOverPopCap`) needs `cap − used > 0`; else `cap ≥ used + delta`, with `used = [player+78h] +
  0x45805C(player)` and `cap = 0x4581A1(player)` (which includes `basePop` / `extraPop`). A failed test holds the timer
  at the delay and sets the building's pause; the first time it is set, the owner's screen gets the train's message.
- **The message** is the train action's own (0x9EB0D6, after a population test fails): only when `[game+3C0h]` is the
  owner's ID; the format is string 17996 (`cStringNoPopcapRoom`, through the BString 0x58EA52 / 0x4010CA), the name the
  target's `[proto+140h]` string, shown by the game's vtable `+68h` (`cdecl(game, 2000, 0xC6657C, format, name)`), then
  the sound 0x50547A(game, 4, 0). The train's third call, `[[game+920h]] +B4h`, is not made (its meaning is not
  known). Interface only: nothing reaches the simulation.
- **The transform in place** (`TransformUnit`: 0x9C754C with the transform observers around it) keeps the unit's ID,
  owner, container and share of hit points, and changes its population to the new proto's. A unit whose proto did not
  change (the transform refused it) stays the head, logged (20 lines at most), and the building stops for the tick.
- **Eject:** the unload of one unit, FUN_009C68C3, `bool __thiscall(container, unitId, pos*, usePos, keepOrders, force,
  a6, goTo*, a8, a9)`, `ret 24h` (REA `ev_6ba459b1…`, 2026-11-26), with pos (−1, −1, −1) at 0xC665E4 and `usePos` 0
  (the place is found around the container by 0x9C65D8), as the unit command handler FUN_009CBEA1 calls it for one unit
  (`ev_4d4c00e4…`), and `force` 1 as the death eject FUN_009C6C79 does (`ev_ef4a8702…`: without it the unload needs
  `[world+6920h]`), `goTo` (0, 0, 0) at 0xC66550 (no point to walk to), `a6` −1. It runs in the world tick, after the
  load has returned, like the trigger `Ungarrison`. A failed unload (no room) leaves the unit inside, logged.
- **Saved state** (`savedmarkers.h`, stat 6Ch, on the building): word 0 `GCNV`: the timer, the head and the game time of
  the write (written each tick, cleared when nobody qualifies); word 0 `GCRR`: the cursor and the pause (written when
  they change). A game that starts or loads (another world, the time going back or the step count jumping) walks the
  world's unit table once and puts back every container with tags and units inside, with its timer plus the game time
  since the write (the update the save was made in), its cursor and its pause.
- **Techs** (`AddTechProtoSubtype`, six subtypes): the lookup hook of `techsubtypes.*` calls the key's parse with the
  effect and its XML node while the techs are read: `unittype` (in the unit type table; a proto where the subtype needs
  one) and `tag` go into the key's table, and the effect's field `+10h` becomes the index (the applyData switch passes
  it to the handler as its "action ID"). The handler gets the player's copy of the proto, the base proto, that index,
  the amount and the relativity, and works on the copy's tags: a map by the copy's pointer (with its proto ID, so a
  reused pointer starts again), made from the data's tags at the first change, cleared on a data load. Delay and eject
  go through the stock value function 0x7F892A (every relativity, and the removal), with the tag's own data value as
  the base; target and from are set; Add appends a tag (its removal takes it back); Remove drops tags. A change marks the
  world for one walk at the next tick, so units already inside a building that now has tags start converting.
  **A load:** the game reads the protos again (the data-load callback, so the tags) but not the techtree, then runs every
  ProtoUnit `Data` effect of the active techs again before the first tick (seen in game: the six effects of the test
  tech came through the handlers after `loadGame`), so the key's table of effects is never cleared: the effects keep the
  indices they were given when the techtree was read.
- **Panels:** `GarrisonConvertProgress(building, &fraction, &waiting)` (`features.h`) gives the progress of the head
  (full during a pause) and the number of units that qualify; the pie source (`AddProgressPieSource`) shows it for a
  head whose tag has a delay.

**Why it is safe:** the hook is the shared one (above). Every engine function called is verified first: the unload's
head 0x9C68C3, the population getters' heads, the train's message call and its sound (0x9EB0D6, 0x9EB137), the is-a
test, the value function, the player's proto 0x45311B, the flag test, the BString pair. The unload, the transform and
the message run in the world tick, the same place the trigger effects run, after every load has returned. The
simulation only uses game time, the step count, the unit table in ID order and maps by building ID; the tech table is
keyed by pointer but only looked up. The message depends on the local player but changes nothing. Cost: per tick, for
each active building, one walk of its contained list per conversion; nothing for a building with no units inside.

### containedUnitsROF

**The tag.** The stock handler of `<ScaleByContainedUnits>` (0x5FEDFC) reads the text as an integer into `[esp+10h]`
(0 when it is empty or not a number) and sets bit 18 only for 1. The hook replaces `cmp dword ptr [esp+10h],1 / mov
eax,[ebp+64h]` at 0x5FEE0C (8 bytes). For an action read from a tactics file or a `<ProtoAction>` (the parser's return
address `[esp+0C0h]` is 0x5FA623 or 0x5FA213), it calls `UhcContainedRofTag(node, proto, action, value, return)`, which
reads the attribute `target` with the XML attribute getter 0x598F37:
- none, or `Damage`: the hook re-executes the two instructions and goes on at 0x5FEE14, the stock test;
- `ROF`, on (an empty text, or 1): bit 18 is cleared (no damage multiplier), bit 17 (`ActiveIfContainsUnits`) is set,
  and `{proto ID, action name index}` goes in a table; the hook jumps to the parser's next child 0x5FA126. Off (`0`): bit
  18 is cleared, the entry dropped.

A later tag of the same action replaces the entry (and clears bit 17 if the entry had set it). The table is cleared on
every data load (`OnDatabaseLoad`), and the tags are read again, a saved game's load included.

**The interval.** Every attack (vtable 0xB96278: `HandAttack`, `RangedAttack` and the other types of the class) waits
through 0x48FA69(action manager, ms), which applies the ROF modifiers. Five reads of the tactics ROF `[action+34h]` feed it
or the attack's animation rate, and each is replaced by a jmp to a hook that re-executes it, passes the value through
`UhcRofRead(unitAction, rof, read)` and re-executes what follows. These five hooks are shared (`rofreads.h`,
`hooks/rofreads_hooks.asm`, with [`numberOfShots`](#numberofshots)): `UhcRofRead` runs the filter of each key whose gate is
open, in `kFeatures` order, each on the previous result; this key's filter is `ContainedRofScale`:

| Site | Bytes | What it is | Unit action in |
|---|---|---|---|
| 0x4A1189 | `mov ebx,[eax+34h] / mov eax,[esi+6Ch]` | an attack begins: the animation's rate `[unit+0B0h]` | ESI |
| 0x48F8B5 | `mov eax,[eax+34h] / cmp eax,ebx` | after a shot, melee or ranged: the wait | EBP |
| 0x48A821, 0x48A99A | `mov edi,[edi+34h] / test edi,edi` | the update, after an attack that did not fire | ESI |
| 0x48EA0C | `mov esi,[esi+34h] / test esi,esi` | the attack step, the same case | EBP |

`ContainedRofScale` finds the table entry of `{[[unit+5Ch]+4], [[ua+4]+4]}`, the proto ID and action name index that
every player's copy keeps. Without one it returns the value. Otherwise the factor follows the stock damage rule
(0x4996C7..0x49970A): the count `[unit+74h]`, or `DamageFactorCap` `[action+48h]` when the count is above it and it is
above 0; the interval is ROF / factor, rounded down, at least 1 ms. A factor of 0 returns the ROF: that is only reached
when the modder cleared bit 17 again, because the target search 0x487F7A skips an action with bit 17 and no unit inside.
An override ROF (`[[ua+6Ch]+28h]`) is not divided: the stock code uses it in place of the value the hook returns
(0x4A1191) or never reads the tactics ROF (0x48F8A8, 0x48A7FC, 0x48A88B, 0x48E9E0).

**Why it is safe.**
- No branch lands inside the replaced bytes (a `cs` scan of every rel8/rel32 branch). Each hook re-executes the instruction
  that sets the flags its continuation tests (`test` / `cmp` before `jbe`), so the branches see the stock flags. At
  0x4A1189 the next instruction is `test eax,eax`; at 0x5FEE0C the stock test or the next-child code sets EAX and the flags.
- `pushad` / `popad` keep every register but the one the hook writes. The C function returns an integer; no x87 value is
  live at any of the five sites.
- With no action carrying the attribute, this key's gate is closed (`SetRofGate`); with every gate closed,
  `g_uhcRofGate` is 0 and the hooks skip the call: a compare and a branch per attack.
- Deterministic: the count, the cap and the ROF are simulation state, the table is keyed by IDs, the division is the same
  code on every machine, and the log never feeds back.
- Not covered: the panel's ROF text and the AI's own damage estimate read the data's ROF.

### numberOfShots

**Stock.** An attack (vtable 0xB96278) fires one shot per cycle. A cycle begins at 0x4A1185: `[ua+78h]` = now, and the
attack animation's rate `[unit+0B0h]` from the ROF (0x4A1189). The shot is the attack step's block 0x48F7F0..0x48F8E9:
tactics flag bit 9 picks the launch 0x499422 (a projectile) or 0x4DCFE2 (none); both join at 0x48F892, which counts the
shot (`add dword [ebp+68h],1` at 0x48F8A0) and waits ROF minus the time since `[ebp+78h]` when that is smaller
(0x48F8B5..0x48F8E9, through 0x48FA69). [O] The launch 0x499422 is `thiscall(unitAction, unit, target,
[[frame+2CCh]+28h], byte, [ua+6Ch])`, `ret 14h` (0x4999DA, 0x6A4C65): the attack step pushes `[ebp+6Ch]` at 0x48F83B and
the four others from 0x48F87D; the broadside fire step calls it with five arguments too (0x4CEA3A..0x4CEA43). It
creates one projectile, with its own accuracy roll and spread. `NumberProjectiles` (and `NumberOfShots`) is no tag of
this exe: no string, no handler (engine-symbols.md, "Projectile accuracy and spread").

**The burst** (the shared ROF reads, `rofreads.h`): for an action with `<NumberOfShots>` N > 1 the filter
`ShotsRof` reads the shot count `[ua+68h]`:

| Read | When | Value |
|---|---|---|
| 0x4A1189, a cycle begins | count mod N < N − 1 (the next shot is not the burst's last) | the interval, else the ROF |
| 0x48F8B5, after a shot | count mod N ≠ 0 (the count includes this shot: the burst goes on) | the interval, else the ROF |

So the burst's first N − 1 shots play the attack animation at the interval's pace and wait the interval; the last one
plays it at the ROF's pace and waits the ROF minus that cycle's time, the reload. [O, in game, Skirmishers with N 3 and
0.4 s, ROF 3 s] shots at 29.73, 30.13 and 30.80 s, the next burst at 33.53 s. The three other reads (after an attack
that did not fire) keep the ROF. The count belongs to the unit action, and a new target is a new unit action, so it
starts a new burst. A filter's result goes through the next one: after `containedUnitsROF` the burst's last shot waits the
divided ROF, and the interval is not divided.

**No reload between the burst's shots (2026-11-21).** [O] An attack with a `<reloadanim>` keeps two animations on its unit
action: the attack animation `[ua+7Ch]` (its model index `[ua+80h]`) and the reload animation `[ua+84h]` / `[ua+88h]`,
looked up from the tactics action's `[+58h]` and `[+5Ch]` (the parser's `Anim` and `ReloadAnim` cases, 0x5FB28D and
0x5FB238) by FUN_00471CAC when a cycle begins. The cycle paces the attack animation so that both last the ROF (the rate
`[unit+0B0h]` = (attack length + reload length) / ROF, 0x4A1197..0x4A1234). Once the attack animation has played,
FUN_004976CB (thiscall(ua), AL 1 = started, 0 without a reload animation) starts the reload animation through 0x486E40,
paced to end with the wait (`[[unit+58h]+0B8h] + [+0BCh]` − now). Its callers are setState(15h)'s case 0x497807 (on 0 it
sets state 0Ch, the idle animation `[tactics action+60h]`, case 0x4A4EE6) and the update in state 19h (0x49A3E6, vtable slot
0x48D519; on 0 it sets state 0Ah). So with a burst the quick shots still showed the reload, squeezed into the interval.
The hook replaces the function's head (`sub esp,8 / push esi / mov esi,ecx`, 6 B at 0x4976CB). After a shot that does
not end its burst (`[ua+68h]` mod N ≠ 0, the after-shot read's test) it swaps `[ua+84h]` / `[ua+88h]` for the idle
animation and its model index (0x471D24 on the unit), runs the stock function on them, and puts the two words back: the
unit holds its aiming pose instead of reloading, and the states, the waits and the next cycle are the stock ones, so the
shot times do not move. Without an idle animation, or a model without it, the reload plays. The burst's last shot reloads.
Tried first and dropped: returning 1 at once (a Falconet then waited for an animation that never played and stopped
firing), returning 0 (the callers' state changes, not the stock path of an attack with a reload animation), and pacing the
attack animation alone over the interval (it moved the quick shots later in their cycle: 0.52 s instead of 0.67 s between
a Skirmisher's second and third shot). [O] A Falconet against Settlers starts a new burst after one or two shots with the
reload fix and without it alike (a new target, a new unit action): that is the stock retargeting, not the hook.

**The firing pose between the shots (`<BurstPose>`, 2026-11-22).** [O, frames at 30 fps] the idle animation of a mod's ranged
infantry (`Volley_standing_idle`, the granny file `idle_rifleman_A`) is the rifle at rest, so the 2026-11-21 fix lowered the
rifle after every quick shot. The tag now picks the reload slot's animation per action: `reload` (the stock path, hook not
taken), `idle` (the swap above) or `hold`, the default:
1. At a quick shot, the after-shot ROF read (0x48F8B5, which runs at the attack animation's Attack tag) also slows the rest
   of the attack animation (`StretchTail` in `shots.cpp`): with the unit showing `[ua+7Ch]` (`[[[unit+60h]]+14h]`, as
   0x482771 reads it) and a reload animation in `[ua+84h]`, the time left is the animation's length (0x4939BD,
   `float thiscall(unit)`, seconds) minus (now − `[ua+78h]`) × the rate `[unit+0B0h]`; the rate becomes that over the interval
   minus the elapsed time minus a 30 ms lead. [O] Writing `[unit+0B0h]` mid-animation takes effect at once (a Skirmisher: 1000 ms
   animation at rate 11.25, 528 ms left, rate 1.61 over 328 ms).
2. The animation then ends 30 ms before the wait, and FUN_004976CB runs from the hook with `[ua+84h]` / `[ua+88h]` = the
   attack animation. The unit still shows it, so 0x497767 / 0x6A78D0 do not restart it: the function sets its owner (0x4A2320)
   and paces it over the lead, and returns 1. [ua+70h] is set to −1 after the call: the update in state 19h (0x49A3DB) calls
   the function while the visual shows `[ua+70h]`, which is the case after a stock reload start no more (the reload animation
   shows) but would be after this one; [O] without the write the function ran at every update, the lead shrank to 0 and below,
   and the cycles came early (0.388 s). The next cycle copies `[ua+7Ch]` into `[ua+70h]` again (0x4A115C).
3. `UhcShotsHoldLead` then checks the wait left (`[[unit+58h]+0B8h] + [+0BCh]` − now): under 10 ms (a reload start that came
   late), the rate becomes the animation's length / 10 ms. The stock function paces over a wait of 0 at rate 1 (the whole
   animation) and over a negative one read unsigned (0x4B92E9 adds 2³², so it never ends): either holds the next cycle.
   [O] It fired once in a test where the target died (`came -658 ms before the wait's end`).
[O] The next cycle begins when the reload slot's animation ends, not at the wait alone: a reload animation frozen at rate 0.001
stopped the unit after its first shot, and an animation ended 10 ms early began the next cycle 10 ms early. So every pose keeps
an animation that ends with the wait. The shot times stay stock within one update (0.403 / 0.665 / 2.735 s against 0.402 /
0.665 / 2.734 s). What shows: the attack animation's last pose (the aim) from the shot to the lead, then the start of the next
attack animation (about 40 ms, the raise from frame 0 at the quick pace). An attack without a reload animation keeps the stock
path for every pose (state 0Ch, its idle animation), as the hook returns to the stock head when `[ua+84h]` < 0.

**The projectiles** (option `projectiles`): `hooks/shots_hooks.asm` replaces the attack step's `call 499422h` (5 B at
0x48F88D, ECX = EBP = the unit action, the five arguments pushed) with a jmp. While some action has
`<NumberProjectiles>` above 1 (`g_uhcShotsProjectiles`), `UhcShotsProjectiles(ua)` gives N, and the hook calls the
launch N − 1 times with copies of the five arguments, then once on the stock ones, and goes on at 0x48F892. The shot
count goes up once. The launch keeps EBX, ESI, EDI and EBP; 0x48F892 reloads EAX from `[ebp+6Ch]` and writes ECX and EDX
before reading them. The broadside fire step (0x4CEA43) and melee (0x4DCFE2) are not changed.

**Tags.** Read through the shared action tag hook (`actiontags.h`), per `{proto ID, action name index}` as for
`spreadAnyAccuracy`, from a tactics `<action>` or a `<ProtoAction>` (the later one wins); cleared on every data load.
`NumberOfShots` 1..50, `ShotInterval` seconds above 0 and up to 60 (default 0.25 s, rounded to ms), `NumberProjectiles` or
`NumberOfProjectiles` 1..32 (only with `projectiles`).

**Why it is safe.**
- The ROF sites are those of `containedUnitsROF` (above). The launch site: no branch lands in 0x48F88E..0x48F891 (`cs`
  scan); the stack is the stock one at 0x48F892, since each extra launch pops its own copies (`ret 14h`).
- Deterministic: the count, the tags and the interval are simulation state or data; the extra launches use the stock
  launch and its synced random draws, the same on every machine. Every player needs the same line and data. `hold` writes
  the unit's animation rate from game time, the data's animation length and the stock rate: the same on every machine, as
  the stock cycle's rate is; that the cycle waits for the animation's end makes it simulation state.
- Cost: one map lookup per ROF read of an action with a burst while some action has one, one per shot with projectiles;
  with no tag in the data, the gates are closed and the hooks only compare. `hold` adds a call of 0x4939BD per quick shot.

### retargetInAction

**What the attack does when its target dies (2026-11-23, capstone on the stock exe, REA `ev_c3f18d0017…` for the unit
query FUN_00499CE4, hardware write breakpoints and the key's own log in game).** The attack unit action (vtable 0xB96278)
keeps its target's ID in `[ua+14h]`, its range in the float `[ua+24h]` and its state in the byte `[ua+61h]`.
- **A shot per Attack tag.** The event handler (vtable `+44h`, 0x48CED0) resolves `[ua+14h]` (EDI, 0 when it is no unit)
  and switches on the event type − 5 (0x48CF65): event 5, an animation's `Attack` tag, goes to 0x48F739, which fires the
  shot block (0x48F7F0..0x48F8E9: launch, `[ua+68h]` + 1, the wait 0x48FA69) when the attack is in state 1 or its tactic
  has flag bit 4 (0x48F75F..0x48F7DE). The shot changes no state, so every Attack tag of the animation fires while the
  state stays 1: [O] a machine gun with six Attack tags fired six shots a cycle, 0.10 to 0.24 s apart. The other events the attack does not
  take (TargetDied 13h among them) go to the base handler 0x48CF88, which ignores 13h (0x48CFC4).
- **The update finds the dead target.** The update (vtable `+3Ch`, FUN_0048A330) reads `[ua+14h]` at 0x48A359; no unit
  (0x48A3D3 by way of 0x48782F, unless the ID is below 0, a point attack), not alive (vtable `+A4h`, 0x48A3EA) or inside
  another unit (0x48A3F9, the current action of type 2Bh; 0x48A409) all go to 0x487838: in state 19h it goes on (0x48A40F,
  where state 19h returns at once, 0x48A413); with `[ua+0Ch]` ≥ 0 its own branch (0x4F6F6E); in state 1 or 15h
  setState(19h) (0x487854); otherwise setState(0Ah) (0x497863). In state 19h the Attack tags fire nothing, so the rest of
  the animation is lost. [O, trace] When the wait is over the unit reuses the same unit action for its next target:
  `[ua+14h]` = −1 (0x4719F3) and `[ua+68h]` = 0 (0x472CE8) under 0x472CCD (vtable `+8`), then the new target, and a new
  cycle from the start of the animation.
- **What the update checks on a live target** (each update): the attack the tactic gives for it, 0x489ECC(tactic, unit,
  target, 1, !flag 0Dh, 0, 0, `[ua+24h]`) at 0x48A570, against the tactics action's ID `[[ua+4]+0]` (another one →
  0x4E5346); the range, the unit's vtable `+CCh(target, [ua+24h])` (0x48A5C8); the visibility, 0x48A9EF(target, player)
  (0x48A605); then `[ua+18h]` = the target's position. The tactic is the unit's current one: `[[[unit+5Ch]+44h]+10h]`
  indexed by `[[unit+58h]+0A8h]` (0x48A533..0x48A56E).

**The hook.** `hooks/retarget_hooks.asm` replaces `mov al,[esi+61h] / cmp al,19h` (5 B at 0x487838; reached only by the
three jumps above, `cs` scan) with a jmp. ESI = the unit action, EBX = 0, the update's saved EDI on top of the stack. While
some action has the tag (`g_uhcRetargetOn`), `UhcRetargetAction(ua)` runs with EAX, ECX and EDX saved. For a tagged
action (`{proto ID, action name index}` of the unit's proto and `[ua+4]`) in state 1 with a target ID ≥ 0, it searches:
the units within `[ua+24h]` + 12 m of the unit (FUN_004A1C55, the world's spatial query), each one not the unit or the
lost target, alive, not inside another unit, of the tactic's `<autoattacktype>` `[tactic+174h]` when it has one
(0x44D7FA, the test of the automatic search 0x4A1A0E), given this attack by 0x489ECC with the update's arguments, in
range by vtable `+CCh` and seen (0x48A9EF); the nearest by vtable `+BCh` (the distance the update reads at 0x48A59B), then
the lowest ID. It writes the ID to `[ua+14h]` and returns 1; the hook pops EDI and jumps to 0x48A359, so the update
reads the new target and runs all its own checks on it, as at any update. Otherwise (no tag, another state, no target)
the hook redoes the compare and goes on at 0x48783D (`je 48A40Fh`), the stock path. A second call for the same action
in the same game time returns 0, so a target the update refuses cannot loop. The shot count, the cycle start `[ua+78h]`,
the wait and the animation are the action's own and stay: the next Attack tag fires at the new target.

**An attack launched by a power (2026-11-26).** An ability whose `<unitaction>` is an attack (the explorers'
sharpshooter abilities) runs the same attack unit action with its power use at `[ua+6Ch]` (0 otherwise). The update does
not ask the tactic for it (0x48A4C2 → 0x4F6F61 → 0x48A58D), and the tactic would not give it: [O] a guardian gets the
explorer's normal ranged attack (0x489ECC answered 4), so the search above refused every guardian. For such an attack the
search replaces 0x489ECC and the `<autoattacktype>` by the action's own data: the rate lookup 0x487C45(`[ua+4]`,
candidate) above 0 (its `<rate type>`s: `Guardian`, `LogicalTypeValidSharpshoot`), not an ally (0x484E01 on the unit's
player, as 0x489ECC at 0x489F33) and, unless flag 0Dh, an enemy (the diplomacy `[player+1D4h+4×ID]` = 2, as 0x489F86);
range, visibility and the choice are unchanged. Without `powerShots` it changes nothing visible: the next tags of a power's
attack fire no shot.

**numberOfShots.** A burst's quick shots wait the interval in state 1 with `<BurstPose>` hold (the attack animation's
tail is stretched to the wait), so a kill by a quick shot is seen in state 1 and the burst goes on. [O] A target swapped in
state 19h (an earlier version did it while a burst had shots left) did not keep the burst: the action was reset at the
wait's end as above and the count started again, so the key leaves state 19h alone.

**Tags.** Read through the shared action tag hook (`actiontags.h`) from a tactics `<action>` or a `<ProtoAction>`:
`RetargetInAction` 1 (retarget) or 0 (stock, logged with `log`); cleared on every data load. With `log` a third ROF filter
(`rofreads.h`, after numberOfShots') logs each shot and cycle start of a tagged action; it changes no value.

**Why it is safe.**
- The site: no branch lands in 0x487839..0x48783C; 0x48783D is the stock `je`, entered with the flags of the re-executed
  `cmp`. 0x48A359 is the head the update reaches from its own start (and 0x49E056), with the stack the hook leaves after
  `pop edi`, EBX = 0 and the update's locals already written (0x48A34F). Both sites are verified (`RetargetNoTarget`,
  `RetargetUpdateTarget`).
- Deterministic: the search reads simulation state only (positions, the spatial query, the attack's data, the player's
  visibility, which is simulation state), picks by distance then unit ID, and runs in the update on every machine. No
  container keyed by pointer decides anything. Every player needs the same line and data.
- Cost: with no tag in the data the hook compares one global. A tagged action pays one map lookup when its target is lost,
  and one spatial query over its range when that happens in its animation: once per kill, not per frame (the state is 19h
  right after a search that found nothing).

### powerShots

**What a power's attack does (2026-11-26, capstone on the stock exe, hardware breakpoints and the key's log in game).** An ability whose `<unitaction>` is an attack starts the attack
unit action with its power use at `[ua+6Ch]` (its `[+1Ch]` the ability record). Each `Attack` tag of its animation
(event 5 → 0x48F739, state 1) reaches 0x48F7E4 with ESI = the use, not 0, and goes to 0x48EA3D: when bit 2 of the use's
bitset is set (0x48BB7E), `[use+1Ch]` ≥ 0 and the world has its power manager `[world+56Ch]`, it calls
0x6EDB7E(unit ID, record, &a, &b), "is this ability ready" (its recharge entry, 0x6ED7F6: none → 1), and jumps to
0x4B7766: `test al,al / jne 48F7F1h` (the shot block) / `jmp 48CF7Bh` (the handler's exit, no shot). [O] A mod's Explorer
(`RangedAttackSharpshoot`, three tags at 0.35, 0.50 and 0.65 of a 0.90 s clip, played at (0.90 + 2.0) / 4.5 = 0.644):
the first tag came 489 ms into the cycle, the next ones 208 to 212 ms apart, and 0x6EDB7E answered 1, 0, 0, so one shot a use: the first shot starts
the recharge. After it the action gets flag 6 (0x48F12B) and ends with its animation.

**The hook.** `hooks/powershots_hooks.asm` replaces those 8 bytes (only 0x48EA9D jumps there; no branch lands in
0x4B7767..0x4B776D, capstone scan of the stock exe) with a jmp. AL = the answer, EBP = the unit action, EBX = 0. Ready:
`jmp 48F7F1h`, as stock. Not ready, while some action has `<PowerShots>` above 1: `UhcPowerShotsAllow(ebp)` (EAX, ECX
and EDX saved) answers 1 for an action of the unit's proto with the tag (`{proto ID, action name index}`), a power use,
state 1, and a shot count `[ua+68h]` of at least 1 (the use's first shot was the stock, ready one) and below N; then the
shot block, else the stock exit. [O] `[ua+68h]` is 0 at each use's first tag (three uses traced). The shot is the stock
one: the launch, the after-shot ROF read (so `numberOfShots`' filters and `retargetInAction`'s shot log see it), the
wait 0x48FA69 and the flag 6 path again, which change nothing for a power's attack (it has no next cycle).

**Tags.** Read through the shared action tag hook (`actiontags.h`) from a `<ProtoAction>` or a tactics `<action>` (the
later one wins): `PowerShots` 1..50; cleared on every data load.

**Why it is safe.**
- The site and both continuations are verified (`PowerShotsReady`, `PowerShotsFire`, `PowerShotsNoShot`, and the path
  that reaches it, `PowerShotsGate`); the hook relocates nothing: it re-does the test and leaves through the stock
  branches' own targets, with the handler's frame and registers as the stock jumps leave them (ESI, the record, is
  dead at both: 0x48F7F1 reloads ECX and EAX, the shot block clears ESI at 0x48F8A4).
- Deterministic: the decision reads simulation state (the action, its shot count and state, the data's tag) and runs in
  the event handler on every machine. The power manager is still asked first, so a use still needs the ability ready
  and starts its recharge as before. Every player needs the same line and data.
- Cost: one compare of a global at each Attack tag of a power's attack after its first shot; a map lookup when some
  action has the tag. Nothing for ordinary attacks (they never reach 0x4B7766).

### turretArc

**What the engine has (2026-11-24, REA on the stock exe, capstone sweeps, read breakpoints and the key's own log in
game; `docs/engine-symbols.md`, "Turrets, facing and the Granny pose", REA evidence `gcamel-turret-20261124.json` and
`gcamel-turret-launch-20261124.json`).**
- **The `<Turret>` tag is parsed and never read.** Its handler 0x68E0AF stores the number (the arc each side, degrees) at
  `[tacticsAction+94h]`, `maxTurnAnglePerSecond` at `[+98h]` (radians a second) and `tracking="always"` as bit 25 of the
  action's flags (`[[action+64h]+3] & 2`). In game, with the tag on the gatling camel's attack, the values were in
  memory, the camel still turned whole to each target, and read breakpoints on `+94h` and `+98h` saw no read in 45 s
  (the ROF `+34h` was read 79 times); no instruction tests bit 25. Dead data.
- **Facing.** FUN_0048AA9F, `thiscall(unit, Vector* point)`, `ret 4`, turns the unit toward a point (0x48AA5D is the form
  for a unit target): it writes the wanted forward at `[[unit+4Ch]+18h]` (0x48AB4A) and returns 1. The attack calls it
  every update (by 0x48A6CA and 0x4B333A) and never waits for the facing: it fires whatever the angle. A turn under way
  goes on in the movement code, so once the body starts turning it turns until it faces the target.
- **The shot's start.** FUN_00499422 builds a projectile's launch; every way it finds the start (the launch tag, a
  bone, the unit's position) meets at 0x4995D5, with EBX = the unit action, EDI = the unit, the start (world) at
  `[esp+1Ch]` and the aim point at `[esp+28h]`. Seen in the key's log: the gatling camel's stock start sat 0.24 m from
  its centre and turned about the centre with the direction to the target, not at the muzzle, so the key replaces it
  rather than turning it.
- **The pose.** The unit's visual `[unit+60h]`: `+1Ch` the model part (vtable 0xB964A0, its Granny model instance at
  `+24h`), `+24h` / `+28h` the attachments (the gun and the rider are attachments of the camel; the hat, of the rider).
  The game samples each model's pose with `GrannySampleModelAnimations`, called through the import slot 0xB847AC.
  Granny skeletons: `+4` the bone count, `+8` the bones, 156 bytes each, the name at `+0` (measured in memory);
  `GrannyFindBoneByName` can return true with an index past the skeleton for a missing name, so the key checks both.

**The key.**
- **Facing hook** (`hooks/turretarc_hooks.asm`, `UhcTurretFaceHook`): the head of FUN_0048AA9F (6 bytes, `sub esp,18h /
  push esi / mov esi,ecx`, re-executed; continues at 0x48AAA5). `UhcTurretFace(unit, point)` returns 1 when the unit's
  proto is listed, its attack with the tag is in its action list (`[unit+58h]+14h`, children at `[action+40h]`: the attack
  asks for the facing before it is the current action) and the point is within the arc (+ 0.5 degree) of the unit's
  forward `[unit+20h]`, the angle `atan2(right, forward)` in the ground plane; the hook then returns 1 (`mov al,1 / ret 4`)
  without writing the wanted forward. Otherwise the stock function runs. The arc is the tag's number each side of the
  gun's rest yaw (the aim file's, 0 before its version 2), no farther than the aim file's yaws go (`max(rest - arc,
  first yaw)` to `min(rest + arc, last yaw)`; the angle is taken about the rest yaw, so an arc that does not hold ahead
  is not cut where the angle wraps): a table of -30..+90 at rest 0 under `90` gives -30..+90, a table of -90..+90
  keeps the tag's symmetric arc, and a table of +30..+150 at rest +90 under `60` gives +30..+150.
- **Beyond an arc about a rest yaw that is not ahead** (round 6, 2026-11-26), the stock turn would bring the target
  ahead, outside the arc. `UhcTurretFace` returns 2 and the hook writes `&g_uhcTurretPoint` over the stock argument
  (`[esp+4]`, the caller's slot, dead after the call: the function is `ret 4`) before the stock code runs: the point
  turned by minus the rest yaw about the unit (in its forward/right/up axes), so the wanted forward FUN_0048AB4A
  stores puts the target at the rest yaw. Only while the unit's current action `[[unit+58h]+24h]` is the turret attack
  (or holds it among its children `[action+40h]`): the other callers of the turn (10 direct, 21 through 0x48AA5D) keep
  the stock behaviour. The turn under way goes on in the movement code after the target enters the arc (the hook
  then keeps the facing), so the unit ends with the target at the rest yaw. Seen in game: a House at 180 degrees,
  `the unit turns until it sits at the rest yaw` from 180 down to 151, then `the gun turns` while the camel turned on to
  bring it to +90.
- **That turn, shown at a walking pace** (2026-11-27). The simulation turns the body at the proto's `TurnRate`, in
  radians a second and with no easing (measured: 18 turns a camel 90 degrees in about 95 ms, so a deployed camel slid
  round in a blink). When a turn beyond the arc begins, `UhcTurretFace` notes it per unit (`g_turns`: the game time,
  the heading it starts from, the signed turn, its length): a rise, the turn at the aim file's rate, a settling (its
  `TURN` section, else 0.3 s, 90 degrees a second, 0.3 s); the point in a step is the angle turned so far over the
  step's angle, so a planted foot stays put whatever the turn (one that ends mid-step sets the lifted feet down as it
  settles). The same
  call during that turn changes nothing; a new target during it turns on from the shown heading. On screen, the body's
  model turns its root bone (the first with no parent) about the model's up by the shown heading less the
  simulation's `[unit+20h]`, so the model and its attachments (the gun, the gunner) turn at the shown pace about the
  unit's origin; the `TURN` poses (below) lift the body and step its feet and the gunner's, blended in and out over the
  rise and the settling; the gun rests. A death clip on the body or the gunner keeps its own pose.
- **No shot while it turns.** No stock check does this: a tracer saw the slow turner's wait 0x48BFC7 (taken at 0x4B3382
  when the turning byte `[[unit+4Ch]+24h]` is set and `[proto+94h]` is under 5.0) run at most once per attack cycle,
  while the shots come from the attack's animation (the launch at 0x48F88D); camels set to `TurnRate` 1.75 and 3.0 fired
  mid-turn. **State hook** (`UhcTurretStateHook`, 0x48A65A, 7 bytes `movzx eax,byte [esi+61h] / cmp eax,16h`
  re-executed; continues at the `ja` 0x48A661 on the cmp's flags; the one branch to it lands on its head): the attack
  update's state switch, passed on every update. In state 1 (firing), while the unit's turn runs, `UhcTurretHold`
  returns 1 and the update leaves through 0x48BFC7 (`[ua]` vtable +34h with 0, back to state 0, then the same epilogue
  as the switch's frame, verified as a site), as the stock update does for a slow turner. The turn is game state (the
  unit ID, game time and the facing's numbers, cleared by the world tick when it ends or the unit is gone), the same on
  every machine; a saved game does not keep a turn under way. In game (two camels, Houses created and destroyed round
  them every 20 s): 0 shots in 12 turns of 90 and 180 degrees, the first shot 0.4 to 1.3 s after each.
- **Launch hook** (`UhcTurretLaunchHook`, 0x4995D5, 9 bytes `fld [esp+28h] / push 40A00000h` re-executed; continues at
  0x4995DE): for a listed unit whose current attack is the tagged one, the start becomes the aim file's pivot plus its
  muzzle (given at the rest yaw) turned by the angle to the aim point clamped to the arc, less the rest yaw, in the
  unit's axes (`[unit+14h]` position, `+20h` forward, `+2Ch` up, `+38h` right; the model's +x is the unit's right).
- Both use only the unit, its action list, its tactics and the aim point: game state, the same on every machine. The
  key keeps no game state between updates.
- **Display** (`grannyhooks.*`, the shared owner of the import slot 0xB847AC: `AddGrannySampleObserver`; the slot is
  checked against `GetProcAddress("_GrannySampleModelAnimations@16")` before it is written). After the stock sample,
  for the instances the key mapped (each world tick, `AddWorldTick`, from the units that aimed, through their visual and
  its attachments), the shown yaw moves toward the last aim at the turn rate in real time, and goes home half a second
  after the last aim or at once while the gun or the gunner plays a clip named for a reload, a death or a deploy; home
  is the rest yaw. The clips show the gun (and the camel's turret bone) at the rest yaw, so the gun's yaw bone and the
  camel's turret bone turn by the shown yaw less the rest yaw (a quaternion about their local y): nothing at rest, and
  nothing while a deploy clip swings the gun itself. The gunner's bones take the
  aim table's local transforms for the clip that weighs most among the instance's controls and its clock, blended
  between the two nearest frames and yaws (`granny2.dll`'s own exports). A gunner on foot steps round the post as the
  gun turns (his feet are part of the table); when the shown yaw stops, a step under way finishes in 0.2 s: the pose
  blends to the aim file's settled table for the way the gun last turned (his feet down at the end of the band, his
  hands still on the grips at the shown yaw), and back to the stepping table when the gun turns again, so the gun rests
  exactly on its target and no foot is left in the air. Display only: nothing of it reaches the game.
- **Aim file** (`UHCA`, version 1 or 2): the gun's yaw bone and the turret bone (32 B names), the pivot and the muzzle (3
  floats each, the camel's model space at the fire clip's first frame), in version 2 the rest yaw (a float, degrees,
  the unit's right positive; version 1 rests ahead), the yaws, the gunner's bones, then per clip its
  rider animation's name, length and frames, `[frame][yaw][bone]` position and rotation. Optional sections follow, each
  a 4-byte tag and a count: `BAND`, the (from, to) yaw bands in which a gunner's foot is in the air (logged), and
  `SETL`, per clip its name, length and frames and two tables like the clip's (the step finished toward a growing yaw,
  then toward a shrinking one); and `TURN` (a version, 1, instead of a count): the step in degrees, the rise and the
  settling in seconds, the rate in degrees a second, the points per step, then two parts, the body's model and the
  gunner's, each its bone names and `[way][point][bone]` local position and rotation, the way 0 for a turn toward a
  growing heading (the unit's right), 1 the other. A point's pose is the risen body (or the gunner) at that share of
  one step, its planted feet turned back by that share of the step's angle in the model's space, so they stay put on
  the ground while the root turns on; the last point runs into the first. `RISE` may follow `TURN` (version 2, then
  the count K): per part, `[way][k][bone]` poses at lift (k+1)/K, the last being the step's first point, in `TURN`'s
  bones and order. With it the rise and the settling run through those poses (from the clip's pose to the first, and
  so on), each taking the lift's share of the step point's offset from the step's first, so folded legs unfold as
  the body rises instead of through the ground; without it they blend straight. A reader without them stops after the
  clips, and a DLL older than the `TURN` section stops there too, so it shows the turn as before.
<!-- private:begin -->
- **A gun its own clips swing (the zamburak cannon, 2026-11-26).** Its reload turns the gun from
  +90 round through its back to 270 and back, inside the clip (the gun's `bone_yaw` and the camel's `bone_turret`
  keyed in the clip). The key adds only `aim − rest`, and `IsHomeClip` returns the shown yaw to the rest at the turn
  rate while a clip whose animation name holds `reload`, `death` or `deploy` plays. So the reload's swing shows as
  animated, with no offset once the gun is home: from an aim of 140 that takes 0.5 s at 100 degrees a second, while he
  plants his linstock. The pack names its unlimber and limber clips `…_deploy` and `…_undeploy`, so they are home
  clips too. No DLL change was needed. Its aim table holds the artillerist's arm and head for the idle and the shot
  at every 2 degrees, standing at his rest station; there is no `BAND` and no `SETL`, because he does not step.
- **The camels' round 7 (2026-11-26: the kush, the gatling post centred, the hump).** Art only: the key reads the
  pivot and the muzzle from the aim files, which the tools write again from the moved post and the lowered, levelled
  lying body, so the gun turns about the new post and the shots leave its turned muzzle with no DLL change. The humped
  camel's mesh is in the plain skinned vertex layout: the game drew nothing of the packed stream edited in place.
<!-- private:end -->

### unitResourceAuras

An `AutoRangedModify` action's update is FUN_009D033E, `void thiscall(action)`, a vtable slot with no direct caller.
It gives each unit the scan 0x9CFF9A finds a modifier. The scan uses the action's range `[action+24h]` and fills a
dynamic list `{data, count, capacity}`; the filter 0x9D0238 then keeps the owner's units (or allies, with a tactic flag)
that are alive, built and of the wanted type.

`AddModifyType` makes `UnitResource` stat 41h, stored in the tactics action's byte `[+B8h]`. The hook replaces the
update's first instruction: with another stat it re-executes it and goes on at 0x9D0343; with 41h it calls
`UhcUnitResourceAura(action)` and returns, so no modifier is made.

The stock update also hangs the action's model on each target, at 0x9D053F: the model `[protoAction+A4h]` (-1: none), the
bone `[+A8h]`, the object through `0x405E83(table [0xC66240], model)`, then `0x9C28DE(unit, model)`, whether the unit has it,
and `0x9C04F3(unit, object, bone, 0)`, which hangs it. `0x9C2885(unit, model)` takes it off. All three work on the unit's
visual `[unit+60h]`, not on the simulation. Skipping the stock update skips this too, so the helper repeats it for the
targets that paid, and keeps per owner what it hung and per target how many auras hold it. A world tick checks the owners
once a second, because a dead owner has no more updates. A model that is not in the game is accepted by 0x9C04F3, returns
true and is never found by 0x9C28DE: the helper treats it as hung and logs it once, or it would hang it on every update.

The private pack `wol-fixes/aura-rings` (`make_aura_rings.py`) gives the same file names the game's own ring instead: the Indian economic aura's texture recoloured per colour, and per colour and size a copy of its mesh (`effects\ypack_auras\aura_econ`, a 2.79 m alpha-tested quad 0.5 m over the bone) scaled and naming its own texture, its stored texture name rewritten at the same length; with no `<replacetexture>`, a Town Center in the scene changes nothing (tested 2026-11-22). <!-- private -->
The rings of `tools/rings` (drawn by `tools/make_rings.py` of aoe3-blender-tools) need no code. A ring's `.xml` hangs one flat particle, chosen by `<logic type="UnitType">`:
`appearancetype` 2 lies on the ground, 0 faces the camera, and `materialtype` 0 with `material` 0 honours the texture's alpha;
`scale` is the full width of the square in metres (measured on the range rings, 2026-11-21). The particle lives 2 s, `emissionrate` 100 with `maxparticles` 1 replaces it
within a frame, and `startfull` has it there at once: 0x9C2885 takes the model off but leaves its particles to die out, so a
ring with an hour's life stayed on the unit. The stock mesh is out for two reasons: at 2 m on anything it stays under a
building, and in a scene with a Town Center its `<replacetexture>` falls back to the stock texture. The cause of that is
unknown: it is not the Town Center's active aura, and a Barracks does not do it.
The texture is a `.ddt`: `RTS3`, usage 0, alpha 1, format 8 (DXT3), a mip per halving down to 4x4, then an offset and a size per
mip. The script draws two bands in alpha, at 70%, and gives each block two colours and a 2-bit shade per texel. A building has
its own texture, so that a line of 0.5 m stays 0.5 m on a ring ten times as wide.

The helper:

- reads `<ModifyAmount>`, `<ModifyTargetLimit>` and `<TargetGaia>`, unknown to the exe, through `AddActionTagHandler`,
  by `{proto ID, action name}`;
- computes the seconds since the owner's last update from `[world+108h]`, at most 5;
- runs the stock scan, with its own filter: `[tactics+9Ch]` abstract index or `[tactics+9Eh]` proto ID, owner or Gaia,
  an inventory `[[unit+B4h]+94h]` with a resource: `[inventory+10h]`, else the largest (0x4DBEC1);
- takes `min(amount, have)` as the gather tick does: 0x49A5E6(inventory, resource, −take), then the state check
  0x482152, which kills a unit with `DieAtZeroResources` at zero, unless the proto has flag 24h;
- pays 0x49A98A(player, resource, take × `[player+37Ch]`, 0).

**The Torp's tags (2026-11-06).** The clock, the rates and the rings are kept per `{owner, action name}`: per owner, a
second aura found the clock already at `now` and paid nothing. The model count is per `{target, model}`. The dead test is
the alive slot `+A4h`, not 0x4802C6: that one reads the action manager, and a carcass passes it as alive. `<SingleUnit>`
moves the last target to the head of the scan's list and takes one. An action with bit 0 of `[tactics+64h]` clear
(`ActionEnable` 0) still reaches this code, so it lets its rings go and leaves. `ModifyRate` keeps a value by the player's
copy of the action, with the name beside it against a reused pointer; `AddTechActionSubtype`'s handlers now get the
player's proto, for the base value. The panel row runs in `AddUnitPanelRow`, after the stock AutoGather row has written the
same gadgets, so it adds `0x49EBE4(0x485CAC(manager, 1Dh), resource)`; it is display only.

**Why it is safe.** The hook sits at a function entry and reads only the action. Targets are looked up by ID on each
step, so one that dies in the loop is not touched again; the list belongs to the helper. The order of the scan, the
game clock and an ID-ordered map make the result the same on every machine. Stat 41h reaches no stock reader in an
aura: the update does not run; in a power's `<unitModify>` the name is accepted and has no effect.

### veterancyBonus: the rank marks

A kill that reaches a rank and a transform queue the unit's ID. A world tick every 250 ms of game time hangs `rank_N.xml` through
`unitmodels.*`, walks only the units with a mark, and removes the mark of a dead unit. One walk over the world's units
`[world+0Ch]` runs on a new world or a jump of the clock, which finds the ranks of a loaded game. The mark is a particle of the
model, a sprite that faces the camera; a model attachment's particle hangs at the unit's position (it ignores the
`HITPOINTBAR` bone) at a height over the ground, while the game draws the HP bar at that tag. A point higher than the bar
drifts sideways in perspective, so the sprite's centre is at the bar's own height by kind of unit (`RANK_BAR_HEIGHTS` in
aoe3-blender-tools' `tools/make_rings.py`) and the mark is drawn high inside the sprite, which moves it straight up on screen:
it stays centred on the bar, its lowest point the same height over the bar for every rank, and the bar and the mark scale
alike with the camera, so the gap holds at every zoom. The images are the team's approved soutache knots, traced from their
sheet into smooth symmetric curves and rendered with its colours and a dark border widened inward, so that it still reads at
the 64-texel level the game samples at the default camera (private), then placed by `make_rings.py --rank-shapes`. **Why it is safe:** a model is a
visual of the unit, so nothing reaches the simulation, and no tick walks the whole world.

### auraStacking

The aura update FUN_009D033E sends each unit it does not hold through the filter 0x9D0238, at one call, 0x9D0633, which the key wraps:
`<ForbidUnitType>` (or `<ForbidAbstractType>`) refuses a target of that type. A refused target stays out of the action's list, so every
update asks again.

That several carriers of one aura do not multiply is stock: `<ModifyExclusive>` is action flag 21h, passed to the creator 0x4DD22D and
kept as the modifier's state bit 16h, and the stat sum 0x4B3C7D stops after an exclusive modifier. Each carrier still gives each target
its modifier, so when one carrier dies the others' modifiers are already there. Measured in game (2026-11-21): five carriers of a ×1.5
Speed aura with the tag gave villagers 6.0 m/s from 4.0 (×1.5), five without it gave the Explorer 34.17 from 4.5 (×1.5⁵);
`buildingWorkRateAuras` and `resourceGatherAuras` sum with 0x4B3C7D, so the tag holds there too (×2 against ×32). The key's first
version had its own `<NoStack>`, with a mark in `[modifier+84h]` written by a hook at 0x9D0675; both are gone, and the tag is logged
as retired. `unitResourceAuras` makes no modifier: its take asks `AuraClaim`, which gives each target one payer when the aura's action
has flag 21h, with the key on or off.

**Why it is safe.** The filter runs only for targets the action does not hold yet and reads only data and the target's proto, the
same on every machine. `AuraClaim` decides by unit IDs and game time.

### snareValues

A jmp at 0x4DD207, after what `cantBeSlowed` writes, pushes the action's values and calls the creator 0x4DD22D. EBP is the attacker's unit
action; `[ebp+4]` the player's copy of the tactics action. **Why it is safe:** the values are data and tech effects, the same on every machine.

`strongest`: the unit's recompute 0x49F1BA has the one call of the velocity sum, 0x49F26A, with the list 0xCF0718 it has just built, oldest
first. A `WriteCall` there swaps the slowest snare into the first snare's place and runs the sum. **Why it is safe:** nothing is kept, the
list is rebuilt for each recompute, and both swapped entries are velocity modifiers, so the other stats read the same list.

### danceBonusCivs: the fire pit

The head of getFirePit 0x4819EF keeps, per player, the place of the first unit of the type, keyed by the list's count, its last ID and a
counter of transforms. The stock lookup 0x48195C then starts at that place. **Why it is safe:** the memory is a fact about the list, not of
a step, so a UI call between updates cannot change a result. The dancer count is hooked at 0x9C1604, after its stale workers.

### unitTypeTechs

The proto clone 0x67E011 builds its own bit buffer `[proto+30h]`, so a write to a player's copy reaches that player alone, and the is-a
test 0x44D7FA reads it at once. `AddTechTypeSubtype` reads `unittype` into `[effect+10h]`, the field the action variant uses. A proto's
bits are not in a saved game, so the same code sets flag 20h in `[effect+9]`: the pass after a load 0x94DDEA runs only flagged effects.

**Why it is safe.** Counts decide the bit, so an end of effect never clears what the base proto has or another tech still adds. The
pass after a load starts them from zero, as a new world clears them. Stock's table behind 0x453326 is left alone: it is shared by
all players, and KB counts stay as the data says.

### customHotkeyContexts: the tooltip letter

FUN_008F8F5E writes a proto's key by looking its `tis("X")` up in a list of 37 names written in the code, once per proto (FUN_007EF89E, the
cache `[db+5D28h]`). A jmp at 0x8F9696 adds the added contexts to that list after the stock names, and one at 0x8F90FC tries them when a
building has no key in `BuildAccel`. **Why it is safe:** it is UI text, read on the UI thread, and the cache is reset with the keymap.

### linkedResource

Three hooks and a tick. The head of the inventory recreate 0x9BFE5A adds a tagged unit to an ID-ordered map. The tick, four
times a second, looks for a mine for the ones with none (FUN_004A1C55 around the unit, the is-a test, the distance slot
`+B8h`) and copies the mine's entry into the building's inventory with 0x58EF83. The head of 0x49A5E6, the add every take goes
through (0x4ED124 in the gather tick), sends a negative add on a linked inventory to the mine's and runs 0x482152 on the
mine, whichever of the eight callers it comes from. A positive add stays on the building and the next copy overwrites it.
In the AutoGather update, 0x4C378A hands the amount to the C++ code. That amount has the player's handicap `[player+37Ch]` in it, so
the code takes it divided by the handicap from the source, as the gather tick takes before it multiplies, and writes back what
that pays; the add at 0x4C3798 stays, because `resourceDebt` reads its return address. Two paths of that update are not
hooked: a `SingleUse` action pays the unit's whole inventory at 0x6A7E85, and `AddResourcesToInventory` adds to it at
0x4C0F7B.

**Why it is safe.** The building's inventory is only a copy, so the stock clamp in the gather tick and the stock stop at 0 need
no hook. The map is keyed by unit ID and read by game time, so every machine walks it alike. A take looks a unit up by ID,
so a mine that dies in the state check is not touched again. With no tagged proto in the data, the inventory hook is one
compare.

### resourceGatherAuras

The stat GatherRate (0Bh) is summed into the record's `+24h` and read at 0x4ECFE9, for every target. Seven new names go
through `AddModifyType` (stats 42h..48h), so an aura gives its units modifiers of those stats; the record recompute skips
them, as it skips 40h. The gather tick multiplies its rate by the Gathering dance factor, `call 4ECD39h` at 0x4ED02A, with
ESI = the Gather action. The call goes to a wrapper that calls the stock function and multiplies by
`UhcGatherAuraFactor(action)`: it classifies the target, `[action+14h]`, by proto type and the resource `[action+70h]`, and
runs the stock sum 0x4B3C7D over the unit's modifiers of the stats that fit, as `buildingWorkRateAuras` does.

**The ring.** The stock update hangs the action's model on everything it reaches: a miner's ring would be on the lumberjack
too. Two `call`s of that update go through wrappers instead: the has at 0x9D0584, for those already in range, and the hang at
0x9D06DC, for new targets. Both have ESI = the aura action. For a stat in 42h..48h, `[protoAction+B8h]`, the wrappers read what
the target gathers: its current action `[[unit+58h]+24h]`, a Gather action (vtable 0xB97880) in state `[+61h]` = 5, its target
`[+14h]` and resource `[+70h]`. The hang skips a unit whose stat does not fit; the has takes the model off that unit with
0x9C2885 and answers true, so the update hangs nothing. A unit on the way to its resource is in no such state and has no ring.
The modifier is left alone: it does nothing on a unit that does not gather what fits.

**Why it is safe.** A unit with no modifier record returns 1.0 after one load, and the tick reads no register from the
call but ST0. `showGatherRate`'s record hook, at 0x4ED044, comes after the call and so sees the factor. That key verifies
the call's bytes, so this one is applied after it.

### resourceDebt

The add 0x49A98A clamps a sum below 1e-6 at its cold part 0x679A0E, and in its shared-resources path, once per teammate, at
0x6799D4; the set 0x49A8C5 clamps its value at 0x6798F4. Each is a single `mov dword ptr [esp+N],0`. The hooks replace that
instruction for a listed resource (a byte table by index): ESI in the add, EBP in the shared path, `[esp+70h]` in the set.

**The sources.** Only three callers of the add may go below 0, told apart by the add's return address: the global trickle
(call 0x4E0CF9, returns to 0x4E0CFE), unit AutoGather (0x4C3798, 0x4C379D) and the gather tick (0x4ED1EE, 0x4ED1F3).
No call site is rewritten, so the check costs nothing on the normal path and the sites stay as `showGatherRate` verifies them.

**The floor of the others.** For any other caller the helper reads the stockpile through 0x44EFFF on `[player+230h]`. At 0 or
above it does what stock does, write 0. In debt it keeps the larger of the sum and the stockpile: a reduction leaves the
debt where it was, and an income pays part of it. Writing 0 there, as stock would, would wipe the debt. A set the add itself
called (returns 0x49A9E2 and 0x6799EE) was settled by the add's hook; any other set goes through the same helper.

**Negative rates.** Three gates stop them before the add, each a jump on the compare with 1e-6: the end of the AutoGather
getter (0x49EE07, returns 0), the AutoGather update (0x48D186, skips the amount) and the gather tick (0x4ED03E, ends the action
at a rate of 1e-6 or less). Each hook keeps the stock branch and adds a case: a listed resource with a value below 0 goes on. The
getter's four other callers ask for a rate above 1e-6, so the panel and the aura code see no change. The gather gate writes
inside what `showGatherRate` and `resourceGatherAuras` verify, hence its place after them in `kFeatures`.

**Why it is safe.** Costs are compared with the stockpile, so a negative one simply cannot pay. The set's other work, the
total `+240h` and the listeners, takes the delta whatever its sign. The list comes from the cfg only.

### cratePriority

Stock orders crates in two functions, both by comparing the civ's ID with those of the names Dutch, Ottomans and Indians.
FUN_004DBF40 `(db, resource, civ)`, called once at 0x49A03C, gives a rank of 1 to 3 that the gather target search adds to a
crate's score × 1000. FUN_00501786 `(player, proto, int* next, int* resource)`, called once at 0x50170B in a loop of 6, gives
the next of the six crate protos (`[db+5E34h..5E48h]`) in a cycle.

Both calls go through a wrapper, so the functions stay as they are. The rank wrapper answers `3 - position` for a civ with
an order. The next wrapper calls stock first, which checks the proto is one of the six, then replaces the answer by
walking the same cycle built from the order: large, small, for each resource. For stock's three orders that gives stock's
answers. The names are looked up again for each database, as civs.xml is read again when a game starts.

- **Observed in game:** see the tests in the modding guide.

### showGatherRate

With the minimized interface (`optionminimizedui`) the stat panel fill returns at its start. The hook
at 0x699456, after the unit panel's own AutoGather rate block, then writes the same label and value
in that block's gadgets, `[panel+33Ch]` and `[panel+340h]`, through their vtable (+84h style, +80h
text, +54h refresh). The panel hides them again when it is refilled. The normal interface has no
such gadgets, so the hook writes nothing there.

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
  the recorded action (or, for a villager on a tree, an action of vtable 0xB979D8 in its state 5: there
  the Gather action that ticks is not the current one; seen in game 2026-11-21, where the strict test
  hid every wood rate), that action's state is 5 and its `[+10h]` is the unit, the resource is below
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
  keep the stub (their shared imm32 at 0x5D06E8 is not written), so a UI that uses
  `{currentUnitGatherRate(gold)}` gets the stock result.
  WoL's UI uses it. <!-- private -->

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

### minUIStats

How the game fills the two places that describe the selected unit, and how the key makes the
minimized interface show what the normal one shows. The catalog of what could be shown and the
plan are in [unit-panel-catalog.md](unit-panel-catalog.md). <!-- private -->

**Two panel objects, two layout files each.** The selection panel (`uiunitselection.xml`, or
`uiunitselectionmin.xml` with profile option 49h `optionminimizedui`) and the stat panel
(`uiunitstatpanel3.xml`, or `uiunitstatpanel3min.xml`). Each binds its gadgets by name when it is
built (0x9BAD00.., 0x9BBAFC..): the stat panel nine rows `unitstatpanel3-StackLabel%d` /
`StackValue%d` at `[panel+174h+i*4]` / `[panel+198h+i*4]`; the selection panel its named gadgets
at `+2E4h..+340h` and three rows `unitselectionpanel-StackLabel%d` / `StackValue%d` at
`+344h` / `+350h`. A name missing from the file gets the "none" handle, and every writer skips it.

**The normal interface** fills the stat panel (FUN_004D70ED): the name and owner, the hit points,
then from row 2 a group's health (behind a config flag), the resource a unit holds, the gatherers
of a workplace, the AutoGather rate, the speed, the armor, one row per attack (damage and its type,
range, bonus multipliers, area in the help text) and the special attacks (behind profile option
45h), and hides the rows left over.

**The minimized interface** makes that function return at once (0x4D7261). The selection panel's
fill (FUN_004C7E52) instead runs its own block (0x6987D7..0x69A60F): owner, hit points, armor, the
resource held, the AutoGather rate, and up to three attack rows, each a single label. There is no
speed, gatherer or group row, and the attacks beyond the third are lost.

**Why buildings show no armor.** Both panels show the armor row only for a proto of abstract type
0, `Unit`, whose armor `[proto+0C4h]` is above 0 (0x698BED, 0x69B34C). Buildings are not `Unit`,
so their armor is never shown, and a gadget a layout nests inside the armor value (to place a
speed text, say) is hidden with it.

**The `{…}` texts.** A `formatText` gadget's `{name}` is looked up, by name, in one table of
16-byte entries `{id, type, name, provider}` (`[parser+0Ch]`, count `+10h`) that FUN_005CFA7C
fills once; its check (0x5D3263) wants each id to equal its index and a type of 1 to 4, and the
evaluators index the table by id. An entry added at the end with the next id therefore works like
a stock one. Seven `currentUnit…` names point to a stub that always fails (`AttackRange`,
`MinAttackRange`, `BuildRate`, `GatherRate`, `AttackList`, `AttackString`, `GatherRateString`),
and `currentUnitMaxVelocity` reads the proto's base speed `[proto+80h]`, not the live one the stat
panel shows.

**The key.** Five writes, each checked against the stock bytes first:
- **The tail of the selection panel fill** (0x4C8281, 10 bytes, `AddUnitPanelTail` in `unitpanel.*`): both
  interfaces pass there, the minimized one after its own block, which jumps back to it. The hook passes the panel
  `[esp+50h]`, the selection `[esp+78h]`, its first unit `[esp+54h]` and the byte `[esp+5Eh]`, the profile option
  the block was chosen by, then re-executes `mov esi,[esp+50h] / mov edi,[esi+308h]` and goes on at 0x4C828B.
- **The choice of the minimized block** (0x4C8276, 11 bytes, written after the tail hook, which verifies those bytes
  too): `cmp byte [esp+5Eh],1 / je 6987D7h` runs the block with the option on; the hook also runs it when the
  panel's `unitHitPointsLabel` handle `[panel+2F0h]` is a real gadget, which only the minimized layouts have, and
  sets the byte to 1. A minimized layout loaded with the option off (the layout's choice can be patched apart from
  the option) is then filled in full; the normal layout goes on to 0x4C8281 as before.
- **The stat panel fill's gate** (0x4D725C, 11 bytes): `cmp byte [esp+63h],1 / je 4D81A1h` returns with the option
  on; the hook returns too, unless the DLL set `g_uhcMinUiForceFill`, and then goes on to the rows at 0x4D7267.
- **The resists gate** of the minimized block: the `jne 698E7Ah` after the `Unit` type test (0x698BF6, 6 bytes) is
  NOPed, so the armor test alone decides; only while that armor test (0x698BFC..) holds the stock bytes ("Coexistence").
- **The data refs** (`AddDataRef` in `datarefs.*`): the parser constructor's call of the registration (0x5D3229) goes
  to a hook that calls it, then appends one entry per `{uhc...}` name through the table's own grow (0x5ACE63), with
  the next id, type 3 and the DLL's provider.

**The rows.** At the tail the DLL finds its gadgets by name in the panel (0xAB7C2F), once per panel; a layout
without them gets nothing. Each `<row>` of the data file is one gadget: its item's text, or the gadget hidden
through the manager's hide (0x448F13) when the item does not apply. The texts are set through the gadget's vtable
(+80h text, +54h refresh) only when they change, at most every 250 ms unless the selection changed.

**The normal interface's rows.** The fill (FUN_004D70ED, `thiscall(panel, selection)`) reads nothing of its panel
but the 18 row handles. The DLL calls it with a panel of its own whose rows all name the first two gadgets of the
`bigPanelRows` block, after giving those two gadget objects a copy of their vtable whose +84h (style), +80h (text),
+54h and +58h record instead of drawing. So the fill writes its rows as the normal interface would, one after the
other, into a list: label style, label, value, and the help text the fill leaves in the label's `+68h`. The real
vtables and help texts are put back, and the rows are written into the block's gadgets, in order, less the kinds
the data file skips. A row's kind comes from its label: the localized `Hitpoints:` (24320), `Speed:` (24323),
`Resists:` (35758) and `Gatherers:` (34986), the literal `Group Health`, the attack style 0xCF05A4, a value ending
in `/s` (a rate) and a `(32)` icon in the label (a resource held); the first row is the name, and the rows after the
last attack are special attacks. `auto` skips what the minimized block wrote itself: the owner, hit points, resists,
the resource, the rate, the special attacks and its first attack rows (three, two with a resource row).

**More items (batch 2).** All are reads:
- the attacks are listed as the stat panel lists them (0x4D7892..0x4D79A1): the unit's current tactic,
  `[[[proto+44h]+10h] + [[unit+58h]+0A8h]*4]`, fills the fill's own list 0xCF05B0 through 0x487EEE (`thiscall(tactic,
  unit, 0, -1, 1, list)`, `ret 14h`; the list is constructed on first use, guard bit 0 of 0xCF05BC, as the fill does),
  and each entry's `+4` indexes the proto's actions `[[proto+44h]+1Ch]`; actions without damage (`[action+24h]`) are
  left out. ROF is `[action+34h]` (ms), the ranges are `[[action+18h]+4]` (min) and `+8` (max), the area the byte
  `[[action+24h]+6]`, the damage type `+5`;
- cost: the player's proto cost list `[proto+70h]` through 0x44EFFF, which unmasks it; population `[proto+0D8h]`
  (the `PopulationCount` Data subtype 1Fh writes it, case 0x8FA814), build limit `[proto+108h]` (subtype 25h, case
  0x8FA9D0), bounty `[proto+168h]` (the `<Bounty>` handler 0x5F5D79);
- what a unit holds: 0x45EE8B, the resource 0x4DBEC1, the amount 0x4E5979 and the capacity 0x494503, as the stock
  row; the lifespan's countdown `[[unit+0B4h]+1Ch]` while state bit 3 is set;
- the other keys answer through `unitinfo.h` from their own state, and only when they applied: the overheal is the
  HP above `[proto+9Ch]` of a marked proto, the rank and kills come from the veterancy counter, the poison from the
  key's map of running stacks, the price range from the `<RandomCost>` tags, the cards per age from
  `shipmentCounts`' counts, the gather rate from `showGatherRate`'s records.
A `text=` row is a template: each `|`-separated part is shown only when every `{item}` in it has a value.

**More items (batch 3).** All are reads, from the same panel tail and data refs:
- *Building.* A unit builds through its Build action (vtable 0xB97330, type byte `[action+60h]` 0, working state
  `[action+61h]` 8, target ID `[action+14h]`). Each tick (0x9D3D6B..0x9D3DF0) it adds to the target's building data
  `[unit+68h]` (through 0x9C4BE3 and 0x7ADE95, `[data+4]` += amount, capped at the proto's build points
  `[proto+0CCh]`; `[data+8]` is the fraction): the rate of its tactics action for the target (0x487C45) × the builder
  factor 0x9C4C0C(target, builder ID, action ID) × `[world+318h]` × the builder's player's `[player+37Ch]` × the frame
  time `[world+104h]`. The builder factor reads the site's worker list `[unit+94h]` (count `+98h`, 18h-byte entries:
  `+0` the worker's ID, `+8` the action ID, `+0Ch` the order it came in): 1.0 for the first worker, the civ's figure
  (`+3Ch` of its record) for the others, 0 for a unit not in the list; for a proto of abstract type 59h, the civ's
  per-count table `[civ+154h]` instead. The item `buildRate` is that product without the frame time, for the selected
  unit and its target; `buildTime` sums it over the site's worker list and divides the points left by it;
  `buildProgress` is `[data+8]`. The engine's own functions are called, so a WorkRate change, a civ's figure or a
  modifier counts as it does in the tick. Measured on a 300-point site: one builder 1.50 pts/s shown and 1.500
  measured, three builders 1.50 + 0.45 + 0.45 shown and 2.40 measured; the time to finish within a second.
- *Regeneration* is per player (FUN_004905E1, from the player update 0x490A52), not a tactic action: for each civ ID
  of the list `[player+20h]` (count `+24h`) that the database's civ table knows, the records `[player+44h] + ID*0Ch`
  (`{data, count}`, 14h-byte entries: `+0` the unit type healed, `+8` the rate in % of max HP per second, `+0Ch` the
  idle time it needs) heal each unit of that type by rate × max HP × 0.01 per second, while idle that long when the
  record asks for it. `regen` sums the records whose type the unit is. The fire pit's Regeneration dance (0x679E66) is
  a separate source and is not added.
- *Auras.* Only the keys' own stats are named, from their state, through `unitinfo.h`: the work factor that
  `buildingWorkRateAuras` multiplies a rate by (its `Factor`, the stock modifier sum over the unit's stat-40h
  modifiers, used only when its hook would use it: the key applied and the unit has a modifier record), the gather
  factors of `resourceGatherAuras` (one per stat 42h..48h, as its tick computes them), and what `unitResourceAuras`'
  last update paid the unit's owner per second, or took from the unit, while fresh (the rule of that key's own panel
  row). That update now keeps its takes (target, resource, amount per second) beside the per-second sums it already
  kept for its row. The game's own auras (`GatherRate`, `Damage`...) are not told apart: their effect is already in
  the values the panel shows.

**Mixed groups: the stack portraits (2026-11-17).** A selection of several unit types shows one portrait per type
in the panel's top band. The selection fill places them itself, each time, before the minimized block and the panel
tail:
it hides every button, then gives the current type the big portrait `unitStackButtonBig0` and each other type, up to
nine types in all, the small button of its index, lists their handles at `[panel+2CCh]` (count `+2D0h`), and the layout
0x4C8F49 centres that list in `buttonArea`, 2 px apart, shows each one and puts the big background around the current
one (`[panel+36Ch]`, its index in the list). A tenth type gets no portrait (no paging, no "+"). Seen at 1920 x 1080
with the proposed minimized layout: one type puts the big portrait at 885..945 px, five types span
791..1039, nine types 697..1133.

The first proposed layout put rows in that band (`uhcCostPop`, `uhcRow1`, `uhcTrainPoints`, 638..668 in layout units);
the current one keeps the band for the portraits (below, "The layout"), and the rule stays for layouts that do put a row
there. At the panel tail, which runs after the layout, the key reads
the placed buttons from the list, their rectangles from the gadgets (`[+30h]`, `[+34h]`, `[+40h]`, `[+44h]`, client
pixels), the big background's when `[panel+36Ch]` is in the list, and its own gadgets' rectangles the same way. The
buttons are found with the any-type lookup 0x404296 (and released by 0x40431B), as the layout does: the text-gadget
lookup 0x44900A the key uses for its own rows asks for type mask 10h and finds no button. A row (or a `bigPanelRows`
gadget) with any pixel under a portrait is hidden for that fill; a `bigPanelRows` gadget is skipped and its row goes to
the next one. The fill is redone when the stack count or the current stack changes, as when the unit does, so the rows
come back as soon as the portraits leave room. In game, with the first layout: one type changed nothing; from two
types on Cost/Pop and ROF/Range gave way; at 9, 10 and 12 types Train Points too; a click on a portrait makes it the
current type, and the rows (Regen, the attack rows) follow it.

The same rule, data-driven: `<avoid gadget="..."/>` names a stock gadget; while it is shown (flags `[gadget+0A4h]`
bits 0 and 1 set, bit 7 clear, the base show's own test) and covers more than half of a row's height (stock text
gadgets are padded and overlap by a few pixels), that row gives way too. The default data file avoids
`unitResourceValue` and `unitResourceRateLabel`, the resource held and the AutoGather rate, which share their line with
`uhcRow5`. `overlap="show"` on a `<row>` or `<bigPanelRows>` opts out. Checked in game with a test file that avoids
`unitHitPointsLabel` (always shown): `uhcRow0` (LOS, Speed), under it, was hidden, and `uhcRow5` stayed shown for a unit
that holds no resource.

Why hide rather than move the row's text elsewhere: the default layout has no free row in a mixed group (the
rectangles of the stock panel already overlap each other; nothing in the band is free once the portraits spread),
the portraits are what a mixed group needs (one click selects a type), and what the hidden rows say is either in the
attack rows (each range) or comes back on a one-type selection. A layout that wants a row kept can move it out of the
band or mark it `overlap="show"`.

**More attacks than rows (2026-11-17).** The stat panel fill writes at most 9 rows (0x4D7957, `cmp ebx,9`): the name,
hit points, the optional rows (speed, resists, ...), then one per listed action until the 9th. Menelik II (an
explorer of the mod tested) lists 8 actions; the fill wrote 5 (rows 4..8), and the big interface shows those 5. When the
fill reached its 9th row and the attack list (0x487EEE, the same call and list as the fill) has more actions than it
wrote, the key writes the rest in the fill's own format: the name from the action's string ID, the damage with the
same factors (contained-unit scale with flag 12h, the modifier record's +8 and +14h or +10h), the damage type's icon,
and the range with its icon when flag 0Ah is set (engine-symbols.md, "Stat panel fill: attack row"). Compared in game
row by row with what the fill wrote for the same 5 attacks: the same text, less the bonus multipliers (`, 3x <icon>`),
which the added rows leave out (the ability attacks that land there in the test, Sharpshooter, Crack Shot, Swashbuckler,
Counter-Intelligence, have none). These rows join `bigPanelRows` after the fill's last attack. When there are more rows
than gadgets, the last free gadget gets the rest in short form: each attack's name and damage, as many as fit one line
(about 0.24 × the gadget's height per character; a formatText wraps a longer text and centres it vertically, which shows
its middle line), then `+N more`; its help text lists them all. With the first layout, before the ability filter
below, Menelik II showed Ranged, Siege, Hand, Sharpshooter, Crack Shot and `Anti-artillery Crackshot Attack 0 +2`;
with the filter it shows the four attacks it can use, and no short form.

**The layout (2026-11-17, third proposal, after Dr.Maxy's and JTMaston's feedback).** The game centres the stack
portraits in `buttonArea` (0x4C8F49): the first proposal took the original `369 632 607 666` (centre x 488) where the mod's
file has `369 697 669 666` (centre 519, the panel's centre is 521), so its portraits sat left of the centre. The file now
keeps the mod's value for every original gadget but the two names, and keeps the top band (y 631..667) for the
portraits only. Mirrored around x 521: two blocks of two lines on the same baselines, over the portrait (344..410: cost,
then population) and right of the player's name (632..698: line of sight and speed, then train time and garrison), and
the unit's name (412..516) and the player's name (526..630). Under the unit's name, `uhcRow2`; under the player's name
nothing, because a long name wraps to a second line there (seen in an AI skirmish: "Otto Von Bismarck (Germans)"). The
stats keep the panel's two columns (x 410: hit points, the three original attack rows; x 583: resists, `uhcRow5`,
`uhcRow3`, `uhcRow4`, on the same lines and with the same attributes as `StackLabel0..2`). An original attack row too
long for its column (a Villero's ranged row with five multipliers reaches x ~600) leaves the second-column gadget of its
line empty, and the rows go on in the next one; a second-column row too long for its gadget (a Spanish name, "Anti-
artillery Crackshot Attack") shows its name and damage, the whole row in its help text. Both widths are estimated from
the font, which follows the screen's height (4.9 px a character at 1080, the screen height read from a gadget's top in
pixels and as a fraction, `[gadget+34h]` / `[gadget+2Ch]`). `uhcRow5` shares its line with the resource value and rate
rows, which can show at x 583: those two are `<avoid>`ed. The previews (`tools/ui_preview.py --vline` in
aoe3-blender-tools) draw both centre lines.

**The health bars.** The minimized block never shows `unitHealthBarGreen`/`Yellow`/`Red` itself: in game, bars declared
in the panel (as the big layout declares them) or inside the portrait stay hidden, while the mod's file, where they are
children of `unitTypeName` through its missing `/>`, shows them, the right colour and length. A child gadget is shown
with its parent; the bars' own state then picks which one draws. The proposed file nests the three bars in
`unitTypeName` on purpose, and nothing else.

**The attack rows, ROF and usable attacks.** With `stockRows="take"` on `<bigPanelRows>`, the key writes the three
original attack rows (`StackLabel0..2`, from `StackLabel1` when the block showed a resource row) from the same mirrored
fill as the extra rows: the minimized block writes them each fill, then the panel tail writes them again (also on the
fills the 250 ms refresh skips, from the last plan), with the attack style and help text of the fill's rows. Each
attack row of the fill is matched, in order, with the action list it comes from (0x487EEE, every listed action) and its
name checked against the action's (`[db+1FE4h]`); then:
- the icons are written square (since 2026-11-23): in the markup `<icon="(N)(texture)">` N sets the icon's **width**
  (N + 1 px, at every resolution) and its **height** is always the text line's, which the font gives (`fonts3.xml`,
  "Arial 12": a 17 px line on a screen 960 px tall or more, its `ResolutionOverride ResX="1280"` sizes, 14 px below;
  measured at 1024 x 768, 1600 x 900, 1280 x 960, 1280 x 1024, 1920 x 1080 and 2560 x 1440). The game's minimized rows
  write `(10)` (0xC36508): 11 x 17 at 1080p, every square icon squeezed to 0.65 of its width; the stat panel's `(16)`
  (0xBA2100) is 17 x 22 in its 22 px line. The key writes N = line - 1 (`IconSize`: 16, or 13 below 960 lines, the
  height `[[0C66044h]+608h]`), in the rows, the resists row and the top blocks, so every icon shows at its true aspect;
  the pack's own icons are made for that (no pre-widening). The big interface is not the key's and keeps `(16)`;
- with `rofIcon`, the action's ROF (`[action+34h]` ms) and that icon go right after the damage icon;
- with `projectilesIcon`, the projectiles the action fires before its reload go after the ROF, when above 1: its
  `<NumberOfShots>` times its `<NumberProjectiles>` (or `<NumberOfProjectiles>`) as the data writes them
  (`projectiles="data"`, the default since version 5), or, with `projectiles="combat"`, as combat fires them: the shots
  while `numberOfShots` is on, the projectiles only with its `projectiles` option. Neither tag is parsed by the exe,
  which launches one projectile a shot (traced 2026-11-19: the launch 0x499422 runs once per shot, always from the
  shot's call 0x48F88D, also beside another DLL). `shots.cpp` reads them through the shared action tag hook (`AddActionTagHandler`, the unknown-child
  path 0x5FA11E of the tactics and `<ProtoAction>` parsers) into a map keyed by the proto ID `[proto+4]` and the
  action name index `[action+4]`, which every player's copy keeps; `unitinfo::Shots` reads that map and applies the
  key's state. `projectiles="data"` asks it for the tags as written (`asData`), and `unitinfo::RequestShotTags` then
  registers the reader even with the key off: that changes nothing in combat, since the ROF filter gate and the
  launch hook stay with `numberOfShots` (and its `projectiles` option). The reader is on the shared action tag hook,
  so beside another DLL it works as long as 0x5FA11E is stock (tested: applied and reached);
- the help text: the fill builds one per attack row, each line after `<ttf><ttb>` (0x4C5076 with its third argument
  1, 0x4C50B0; the fourth argument picks `<ttf><ttr>`, a red line, 0x4C8F35), the row's name, then the damage, the
  range (and area), one line per multiplier (string 42229 or 42230). The key inserts after the damage line a line for
  the ROF and one for the projectiles (`rofTip`, `projectilesTip`, `%s` the number), each with its icon, and a row
  shown in short form (too long for its column, or the `+N more` gadget) carries that whole help text instead of its
  text without icons; in that help text the parentheses around an icon, or around the name right after one (the game's
  `%1s (%2s) Damage`, `... against %2s (%3s)`), are removed unless `tipParentheses="keep"`, and the key's own lines end
  with their icon, without parentheses;
- the multipliers lose the zeros that end their decimals (`, 1.50x` is `, 1.5x`, `1.50X Bonus` is `1.5X Bonus`: a
  number with a decimal point right before an `x` or `X` that ends a word), unless `multiplierZeros="keep"`;
- an original attack row (its gadget spans the panel to the right edge) longer than that width over the font's
  character width drops its last multipliers (`, <n>x <icon>` parts, last first) and ends with ` (+N)`. The font does
  not shrink below 1080 lines (at 1024 x 768 a row is as wide in pixels as at 1920 x 1080), so the character width is
  taken at 1080 lines at least; an icon counts as the characters its width takes (N + 1 px over that width: about 3.5
  at 1080p);
  A row too long for its column keeps the damage, ROF and projectiles in its short form when they fit (the explorers'
  `Sharpshooter ATK 750 <ranged> 4.50 <rof> 3 <cylinder>`);
- an **ability attack the unit cannot use** is dropped. Such an action is listed active by its tactic on every unit of
  the tactics file (the mod's Presidial and Menelik II list Crack Shot, Anti-artillery Crackshot, Swashbuckler,
  Counter-Intelligence), and the stock big panel lists them all. A power of `powers.xml` names its action in
  `<unitAction>`: the handler 0x5F2231 (the `+24h` slot of the UnitAction power class, vtable 0xB855D0) stores the
  action name's index (0x5E0C64, the index space of `[action+4]`) in a 4-byte block at `[power+12Ch]`, which the
  class's constructor (0x5F2CB7) zeroes and its destructor frees; other power classes keep other data at `+12Ch`, so
  the vtable is checked first. An action some ability record's power names is an ability attack; it is shown when one of
  the unit's records is available as the command panel's GetNth tests it (0x6EE68C..0x6EE701): the player's proto
  (0x45311B) is the record's `+4`, its tech `+0Ch` is active (0x94AF27) and its age `+10h` is `[player+50h]`. In game: a
  Presidial shows Sharpshooter (its own record) and no Crack Shot; Menelik II only Sharpshooter (Crack Shot needs
  `Industrialize`); the Chief (`WOLcartographer`) shows Anti-artillery Crackshot only after `HCSteelCrown`.
A row with nothing to read (a nameless action) is left out rather than written as a blank line.

**Hit points and resists with icons, and the panel without the key.** The layout keeps the original hit points and
resists gadgets where the mod has them and lays the key's own gadgets (`uhcHitpoints`, `uhcResists`, with `textmarkup`)
over them. `<replace row="..." stock="..."/>`: while the key's row shows, the original gadgets named are hidden through
the manager's hide (0x448F13), again after each fill of the panel (which shows them), also on the fills the 250 ms
refresh skips. Without the key nothing hides them, and the panel reads as the mod's. The `hitpoints` item is the
minimized block's `%d/%d` (0x698B63), or, with `overhealHitpointBars`, that key's max (its 100 % value, 0x698B35) and its
colour above it (`unitinfo::HitpointsText`; the stock gadget prints the colour markup as text, the key's gadget draws
it). The `armor` item is the stock armor as a percent stuck to the value, to a tenth (`30%`, `12.5%`), with its damage
type's icon, or with `multiarmor` every armor above 0 by damage type (`unitinfo::Armors`, multiarmor's own records);
the original resists value (the exe's `%.2f %s`, 0x698C41..) is rewritten the same way at each fill. Both answer
nothing when another DLL changed the block's armor test
(0x698BFC..): that DLL's own resists row then shows. `<stockLabel>` (an original label's text written over the game's
while it shows) stays for layouts that want it. `[icon:path]` in the data file is the icon markup at the panel's size.
`[string:ID]` in a text, label or tip is that string of the string table (0x58EA52), resolved when the row is shown,
since the tables load after the DLL starts, and kept once read: the version 4 hit points row is
`<color=1, 1, 0>[string:68852]:</color>  {hitpoints}`, the word in the panel labels' yellow.

**The tooltips under the hit points.** A gadget higher than its text catches the pointer over its whole
rectangle. The layout's `uhcHitpoints` had the original label's rectangle (680..734 in 1024 x 768 units), which covers
the left part of the first attack row (714..734) and is drawn above it, so that row's help text never showed there;
it is now one line high (700..714), its text centred on the same 707.

**Spill to the next line.** `spill="<gadget>"` on a row: the rows' texts are made first, then a row whose text is too
wide for its gadget (VisibleLength, an icon counting as two characters, against LineBudget: 90 % of the gadget's width
over the font's character width, which follows the screen's height) is cut at a space outside markup, at the cut that
makes the two lines most even, when the row of the named gadget has nothing to show this fill; the second line goes
there, with the first row's help text. The cost row spills into the population row: in the mod's data a unit with four
costs (the Palace Caravan, 600 / 600 / 200 / 200) has no population, and every unit with population has at most three
costs, which fit one line.

#### Coexistence

The key writes five places (above) and adds no hook site in batch 3: the build, regeneration and aura items are
reads made from the panel tail (`AddUnitPanelTail`, 0x4C8281) and the data ref providers (`AddDataRef`), on the
game's thread, while the panel is filled. No pointer is kept from one fill to the next: a unit is found again from
its ID (the world's table, as the engine does), its action from `[[unit+58h]+24h]`, its site from the action's target
ID. No simulation state is written. The stack portrait rule (2026-11-17) adds no write either: it reads the panel
from the same tail, after the fill placed the portraits.

**What batch 3 reads and who else is there.** Each stock range the items mirror is a verify-only site
(`tools/gen_sites.py`), checked apart from the key's own sites: a mismatch turns off those items, logged, not the key.

| Read (verify-only site) | Other keys at or next to it | Another DLL | How they coexist |
|---|---|---|---|
| Build tick, 0x9D3D6B..0x9D3D7A and 0x9D3D80..0x9D3DC6 (`BuildTickRateHead`, `BuildTickScale`), its add 0x9D3DE9 (`BuildTickAdd`) | `buildingWorkRateAuras` redirects the call 0x9D3D7B..0x9D3D7F (`BwrRateCallBuild`) | none (runtime patch list, 287 ranges) | The two ranges leave those 5 bytes out, so either order of applying works. The mirror calls the stock callee 0x487C45, not the call site, and multiplies by `unitinfo::BuildWorkFactor`, which is that key's `Factor` under the same two conditions as its hook; 1.0 when the key is off |
| Rate lookup 0x487C45 (`RateLookupHead`) | none hooks it (22 callers; heal and build calls redirected by `buildingWorkRateAuras`) | none | Pure: it reads the action's rate records and calls the type test 0x44D7FA. `workRateByAbstractType` changes those records through effects, so its changes are read as the tick reads them |
| Builder factor 0x9C4C0C (`BuilderFactor`), BuildInfo add 0x9C4BE3 / 0x7ADE95 (`BuildPointsAddCall`, `BuildPointsAdd`) | none | none | 0x9C4C0C reads the worker list and the civ records; for type-59h protos it calls 0x4EC7B4, which rebuilds its own static list 0xD6F6F8 (count reset to 0 on each call, read only inside it): scratch of that function, not state another step reads. Same thread as the tick, never nested in it |
| BuildingWorkRate getter 0x9BFE33 | `liveBuildingWorkRate` (head), `buildingWorkRateAuras` (four calls), `noTrainNearEnemyTC` (the Train call) | — | Not read: it is the train and research rate, not the build rate |
| Regeneration FUN_004905E1: head 0x4905E1 and the rate read 0x4907FF..0x49081D (`RegenPlayerHead`, `RegenRateRead`) | `overhealDecay` replaces the add's call 0x49087C (`RegenAddHp`), after the read; `danceBonusCivs` hooks the dance getter 0x49048B, another function | none | No shared byte. `overhealDecay` changes what the add does above max HP, not the rate. The dance's regeneration is a separate source, not shown |
| `buildingWorkRateAuras`' `Factor`, `resourceGatherAuras`' `StatFactor` | `auraStacking`'s filter decides which modifiers a unit gets | — | They walk the unit's modifiers read-only (`modifiers.h`) and sum them with the stock 0x4B3C7D, as the keys' hooks do, so stacking is already in what they read. Their scratch vector is the key's own, used on the same thread, never during a walk |
| `unitResourceAuras`' aura states | `AuraClaim` (asked before each take) | — | The update writes its takes after the claim; the panel only reads the map. The aura update and `AuraClaim` are never called from the panel |
| Data refs `uhcBuildTime`, `uhcBuildProgress`, `uhcBuildRate`, `uhcRegen`, `uhcAuras` | `AddDataRef` has no other user | — | Appended after the 116 stock names, none of which starts with `uhc`; the five are new in the key's own list |
| Stack portraits (2026-11-17): the fill's head 0x4C9458..0x4C9481, its Big0 choice 0x4C9587..0x4C95C7, the list append 0x4C979A..0x4C97B4, the layout call 0x4C7DB3..0x4C7DC0 and the layout 0x4C8F49..0x4C91EB (`StackFillReset`, `StackFillCurrent`, `StackFillAppend`, `StackLayoutCall`, `StackLayout`); the any-type gadget lookup 0x404296 (`GadgetLookupAny`, called, not hooked) | none of our sites is in these ranges; the shared tail hook 0x4C8281 (`AddUnitPanelTail`) and `overhealHitpointBars`' 0x4C83DF come after the layout in the same fill and only read | none: the other DLL's runtime patch list (287 ranges) and a second DLL's patches (0x761BF0, 0x661E15, 0x9AC7E8, 0x9B6655, 0x69920E..0x69922C) have no byte there | Read only, at the tail of the same fill that placed the buttons: the list `[panel+2CCh]`, `[panel+36Ch]`, `[panel+324h]` and the gadgets' rectangles and flags. Nothing is moved, shown or hidden but the key's own gadgets. A mismatch turns off only the portrait rule (logged); `<avoid>` keeps working |
| `<avoid>` of `unitResourceValue` and `unitResourceRateLabel` (the default data file) | `AddUnitPanelRow` (0x699456): `showGatherRate`, `lifespan`, the overheal stat row, `researchGrants`, `veterancyBonus`, `unitResourceAuras` write the rate gadget pair | a trickle display patch can show the stock rate for an inactive AutoGather action too | The shown flag is read at the panel tail, after the minimized block and its 0x699456 hook ran, so whichever key (or other DLL) showed the row, `uhcRow5` stays empty and the rows end at `uhcRow4`, as before `uhcRow5` existed |
| Attacks past the fill's 9th row: the row cap 0x4D7944..0x4D795F, the attack row's name, damage, type icon and range code 0x4D7A2E..0x4D7AA1, 0x4D7AC8..0x4D7C56, 0x4D7D2A..0x4D7DA1, 0x4D8265..0x4D82B3, cold 0x69B617..0x69B696, 0x69FDDC..0x69FDF7, 0x69FE1F..0x69FE37, the raw name 0x5F8FC3 and the range entry 0x4946D6 (`StatFillRowCap`, `AttackRow*`, `ActionRawName`, `ActionRangeEntry`, verify only) | keys that add a row to the big panel before the attacks (`showGatherRate` at 0x4D7834; with them on, the fill has fewer of its 9 rows for attacks, and the added attack rows make up for it); no key writes in these ranges (`tools/gen_sites.py`, every range checked) | none in these ranges (same lists as above) | Read only: the attack list is filled by the stock 0x487EEE into the fill's own static list 0xCF05B0 right after the fill used it, on the same thread; the factors are read from the unit's modifier record as the fill reads them. A mismatch turns off only the added rows (logged) |
| Ability attacks (third layout): GetNth's test 0x6EE68C..0x6EE701, the `<unitAction>` handler 0x5F22CA..0x5F22FF and its vtable slot 0xB855F4 (`AbilityAvailableTest`, `PowerUnitActionStore`, `PowerUnitActionVtable`, verify only); calls 0x45311B, 0x94AF27, 0x6076E9 | `abilitySlots` writes the `5` of 0x695BD3 and hooks 0x696C70 in the command panel, not GetNth; `wonderPanelSkipAuras` calls GetNth itself | none in these ranges | Read only, from the panel tail: the ability manager `[world+56Ch]`, the records and the powers, as GetNth reads them; the set of ability actions is rebuilt when the manager or its record count changes. A mismatch turns off only the filter (logged: every attack shown, as the stock panels) |
| The original attack rows, labels and values (`stockRows="take"`, `<replace>`, `<stockLabel>`) | `overhealHitpointBars` writes the HP value (0x698B35): the key's `hitpoints` asks that key for the same text (`unitinfo::HitpointsText`) and hides the original value only while its own row shows; `AddUnitPanelRow` (0x699456) writes the rate pair, not `StackLabel0..2` | a second DLL's trickle display patches 0x69920E (the rate row); tested with the mod's second DLL loaded by `preloadDll` (its patches seen in memory) | The key writes after the minimized block, at the tail of the same fill, through the gadgets' own vtable (+80h text, +84h style, +54h refresh) and help text; it shows or hides only `StackLabel0..2` (as the block does with them) and hides the `<replace>` gadgets while its rows show. Nothing is kept across fills but the texts |
| Building armor gate 0x698BF6 (written) and the armor test after it 0x698BFC..0x698C15 (`MinResistsArmorTest`, verify only) | `multiarmor` (ours) does not touch the minimized block; with it on, the key rewrites the resists value from `unitinfo::Armors` | the mod's own `uhc.dll` replaces the armor read at 0x698BFF (its multiarmor): its text for a building was `0 (null)` | When 0x698BFC.. is not stock the gate is not written and the `armor` items answer nothing (logged): the key's resists row stays hidden, so the original one shows that DLL's text, and buildings keep the stock rule (no resists row). Tested with that `uhc.dll` and our `dinput8.dll`: a Factory with no resists row, a Wachtmeester with that DLL's `Resists: 0.30, 0.20, 0.10` |

**Found with every key on** (the cfg template's 124 keys, one scene): `decimalPopulation` stores population
quantities times K, `[proto+0D8h]` included, so the `population` item showed `Pop: 10` for a settler; it now divides by
that key's K (`unitinfo::PopulationScale`, 1 without it), as that key's own panels do. And the shared proto tag table
(`prototags.cpp`) had room for 32 tags while the keys ask for 33, so `linkedResource` logged FAILED; it holds 64 now.
After both: 113 applied, 0 failed, 126 hooks reached.

Batch 1 and 2: the key's sites do not touch the AutoGather row block (0x6991BF..0x699456), where another DLL may
redirect the rate's call and NOP its gate, nor the unit panel row hook at 0x699456. The minimized interface can be
forced by patching the screen's copy of the option (0x761BF0) and the file choices, without the two profile reads at
0x4C8235 and 0x4D721B: the block choice above makes the selection panel behave as with the option on.

**Shown equals applied.** Tested in one scene with the related keys on and off (`buildingWorkRateAuras`,
`resourceGatherAuras`, `unitResourceAuras`, `liveBuildingWorkRate`, `noTrainNearEnemyTC`): with them, a builder under
a x1.5 `BuildingWorkRate` aura shows 1.50 pts/s and builds 1.500; without them, 1.00 and 1.000, and a second builder
0.30 (the civ's figure), 1.60 for three, measured 1.60. A gold miner under a x1.25 `GoldGatherRate` aura shows
`+25% gold` with the stock rate row at 0.75/s, against 0.60/s with the keys off.

### multiplierDecimals

**The format.** The stat panel fill (cold part, 0x4D7F4D..0x4D7F98) and the minimized block's attack rows
(0x699DEF..0x699E2D) loop over the damage record's bonus list (`[rec+28h]`, count `[rec+2Ch]`, 8 bytes each: the
unittype, then the factor), skip a factor within 1e-6 of 1.0 and any type without an icon (below), and append
`, %.1fx %s` (wide, 0xBA2060, `.rdata`) with the factor and its icon, or `, %dx %s` (0xC364A8) when the factor is
whole (`factor - floor(factor)` at most 1e-6, 0xBA20B4 / 0xC35C18). So 1.25 is written `1.3x`. Byte search of the
exe (2026-11-19): the format's address is pushed twice, `68 60 20 BA 00` at 0x4D7F7D and 0x699E1F, and is not read
otherwise; the plain `%.1fx` at 0xBF1AD0 is pushed at 0x69BC28 (the special attacks' rollover, with string 18631
`Bonus Damage: %s`) and 0x6EEC97 (an ability's rollover), not changed by the key. The key checks the whole string
(site `MultiplierFormat`, 22 bytes) and writes N over the digit at 0xBA2068 through `WriteBytes` (which lifts the
page's protection). When every byte but the digit is stock and the digit is already N (another DLL wrote it), it
logs that and writes nothing, and the key counts as applied.

**The help text.** Each multiplier adds a line to the row's help text: string 42229 (`%1.1fX Bonus Damage against %2s
(%3s)`), or 42230 (`%1dX ...`) for a whole one, loaded by `push 0A4F5h / call 447719h` (BString from a string ID,
`thiscall`, `ret 4`) at 0x4D7FB6 and 0x699E95 and formatted with the factor. The key redirects those two calls to a
loader that calls 0x447719 and, when the copy holds `%1.1f`, writes it back with `%1.Nf` (0x401A12, 0x40196F,
0x4010CA); the string table itself is not touched. The two sites and the callee are checked apart: another DLL there
leaves the help text as it is, logged.

### attackTypeIcons

**The type chain.** For each bonus, both panels compare its unittype (ESI) with fixed abstract types,
`[db+19B0h]` (the proto count) plus an index, each with its own texture `[[game+920h]+off]` and name string: in the
fill +47h, +14h, +4Eh, +56h, +2, +13h, +16h, +1, +55h, +49h, +7, +4Fh, +50h, +51h, +4Dh, +75h, +11h, +54h, the
minimized block the same list (0x699A95..). A type that is none of them jumps past the multiplier (0x4D800B,
0x699F43): no text, no help line. A type with an icon formats it into the icon BString (`[esp+28h]` in the fill,
`[esp+24h]` in the block, `<icon="(16)(TextureID(%d))">`), pushes its string ID and joins the shared path (0x4D7F44,
0x699DE6), which loads the name and writes the row part and the help line.

**The hooks** (`hooks/attacktypeicons_hooks.asm`) replace the test of +11h, `lea edx,[eax+11h] / cmp esi,edx` (5
bytes), at 0x69B909 (fill, cold part) and 0x699D31 (block). Under `pushad` they ask the DLL for the type: a listed one
gets `<icon="(16)(path)">` (fill) or `(10)` (block) written into the icon BString with the BString format 0x444EFB,
and the hook pushes its string ID and jumps to the shared path, as a stock branch does (it leaves EAX, ECX and EDX
dead there). Any other type gets every register back, the two instructions re-executed and a jump to the `jne` that
follows (0x69B90E, 0x699D36), so the last two stock types and the skip are unchanged. The icon is a texture path in
the markup, so nothing is loaded at startup; the types' IDs are found at each database load
(`RequestAbstractUnitType`, which also registers a name the data does not define, harmlessly). The cfg line is
triples of type, string ID and path.

**Coexistence.** No other key writes in 0x69B909..0x69B90F or 0x699D31..0x699D37; `minUIStats` mirrors the rows
these sites write. Another DLL that hooks the same chain holds those bytes, so the key fails `VerifyAll` there and
leaves the rows to it.

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
1. **Name, 0x5FE6D7** (6 bytes, `jmp` + 1 NOP over `neg / sbb / and`; `hooks/modifytype_hooks.asm`,
   shared through `AddModifyType`). EAX = the `AutoGatherRate` compare, ESI = the name. On a match
   EAX stays 0. Otherwise the helper compares the name with each registered one through the same
   0x443C10 call (flag 0, n −1): a match gives EAX = stat − 0Eh, anything else −0Fh. It continues at
   0x5FE6DD, so the tail returns 0Eh, 40h or −1. Stat 40h is new: no stock code produces it, the recompute skips
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
- It comes after liveBuildingWorkRate and noTrainNearEnemyTC in `features.h`, so those keys,
  which verify the call sites as stock bytes, check them before this key rewrites them.
  It is the last WoL key there. <!-- private -->
- **Observed in game:** a BloodFactory inside an Explorer's 4.0 aura logged `works at x4.000` and
  spawned 11 musketeers while a factory without the aura spawned 2.

The rate lookup 0x487C45 has 22 callers, so only the heal tick's 0x9E0CCF and the build tick's 0x9D3D7B go to `UhcBwrRateCall`, with the worker in `[esi+10h]`. Calls that only test the rate above 0 stay stock.
Repair does not go through that lookup: the command `repairUnit`, type 3Ah, runs the building's own AutoRepair action, type 35h, vtable 0xB971D8, whose update 0x9D0A4D adds `[action+64h]` × time × max HP / build points. The hook at 0x9D0BF2 multiplies that by the building's factor.

### sharedBuildLimit

Stock compares a count with a limit in about 30 places. The count has many routes: 0x4C7BC5 (6 callers) and 0x4C846D (60
callers, with several flags). The limit has one: 0x4C7B5F, `int thiscall(player, proto)`, 50 callers, which reads the player's
copy's `[proto+108h]`. So the key leaves every count alone and changes only the limit: for a tagged proto it returns the room
the others leave, `(limit - others) / own weight`, never below 0, because a negative limit means no limit. The buttons, the
train action, Maintain, cards and the AI all give the right answer at once, and the stock cut of a batch (0x9EAD32, limit
minus count) works too.

The others are counted by 0x4C7BC5 with `(1, 1)`, the arguments of the train check at 0x9EAD04, so queued units count. With
`TeamBuildLimit` the loop goes over the players whose `[player+1D4h+4i]` is 0 or 1, the test of the shared resources at
0x67995B, skipping Gaia.

The hook replaces the 5 bytes at the entry (`sub esp,10h / mov edx,ecx`); a small stub re-executes them and jumps to 0x4C7B64,
which is how the helper reads the stock limit. A proto that is not tagged costs a bit test by ID.

Only the tooltips must not see the room: "9 out of 7" says nothing to a player. So their count calls (0x4C8B81, 0x70F5EF) go
through a wrapper that adds the others, and the hook returns the real limit to the return addresses of their limit calls.

Names resolve at the first use through the table `<UnitType>` reads, `[db+190h]` (0x58E685, 0x40295B), which holds protos and
abstract types, and the members through the is-a test 0x44D7FA, which takes both.
### annexFacing

**[O] What the build command carries.** The command of type 3 (sender 0x82F548) holds the unit IDs of its builders at
`[cmd+40h]` (count `+44h`), the proto at `+8Ch`, the position at `+90h` and the forward at `+A8h`. Its executor
FUN_007D79D6 (`ECX` = the command, the player at `[arg+4]`) computes the right vector at 0x7D7CF1..0x7D7D0C as
`0x423792(world up 0xC66544, &right, &forward)`, i.e. up × forward, tests the placement at 0x7D7EC7 with
`PLACE(proto, player, &pos, &forward, &right, 1, 7, 0, 0, 0, 0)` (world vtable +14h, FUN_0050703D), and creates the
foundation at 0x7D80CF with `0x498ACC(world, proto, player, pos, forward, 0, -1, 0, -1)`; the new unit's ID goes to
`[cmd+B8h]`, which also makes a second run of the same command return at once.

**[O] Obstruction and placement turn.** PLACE builds the footprint with FUN_00506B60(proto, pos, forward, right): the
corners are `pos ± forward × ObstructionRadiusZ ± right × ObstructionRadiusX` when the proto's flag bit 27 is set, and
the world axes otherwise. Bit 27 is set by default and cleared by `<Flag>DontRotateObstruction</Flag>` (0x5F66D1 →
0x5F63AB); a unit's own obstruction comes from the same function with its axes `[unit+20h]` and `[unit+38h]`
(0x9C0CE3, 0x9C2A58). In game a Torp (3 × 4) turned 90° was refused on the east of a Barracks where the unturned one
fitted, and fitted on its north where the unturned one overlapped: the obstruction and the placement test turn with
it. `distanceatmostfromtype` measures from the ghost's centre to the parent's footprint (unit slot B8h): 3.5 m passed
and 4.3 m failed against distance 4.

**The hook.** At 0x7D7CF1 (`lea eax,[edi+0A8h]`), before the right vector is computed, the helper reads the proto's
`<AnnexOf>`. The parent is the command's unit of that type (is-a 0x44D7FA), of the same player, alive, whose footprint
distance (slot B8h) to the position is within `<AnnexRange>` (default 12 m), the nearest if several; with none of them
(a villager built it), the nearest such unit of the player found by the world's query 0x4A1C55 with `precise` 1. The
forward becomes the parent's axis among ±forward and ±right (x and z, normalised) whose dot product with the
direction annex → parent is the largest. Then the stock code computes the right vector from it, tests the placement
and creates the foundation, so obstruction, placement and model all use the turned axes. No parent: stock forward.
Every machine runs the same command on the same state (`DistanceTo`, the query and the is-a test read game state
only), so all reach the same forward.

**The ghost.** FUN_0096E062 updates the placement ghost (`ESI` = its visual, `[0xC67300]+200h`): it moves it and tests
the placement at 0x96E531 with the visual's position `+4`, forward `+10h` and right `+28h`. The shared hook at 0x96E4E7 (`ghostobservers.*`, `mov
eax,[0C66234h]`, the first line of that test's arguments) turns the visual of a tagged proto (`[0xC67300]+1FCh`) the
same way, for the local player (`[game+3C0h]`) and the nearest parent (the UI's selection is not read), and sets
`[visual+7Dh]`, as the stock rotation 0x9BC546 does. The green or red test, and the forward that `uiBuildAtPointer`
(0x7E6DE8) copies through 0x96DF2F into the command, are then the turned ones. It writes only the local UI object.

**The link.** The executor's creation call 0x7D80CF is rewritten to a wrapper that calls 0x498ACC and, when its forward
pointer is the command whose forward the hook set, keeps `annex ID → parent ID` in a `std::map`. Unit deaths reach the
shared death observer: an annex that dies leaves the map; for a unit whose proto is the parent type of some tag, the
query around it (its larger obstruction radius × 2 + range + 8 m, `precise` 0) lists the units of the same player with
a tagged proto of that parent type, and each one whose parent is the dying unit is asked to die through 0x4B4DC2
`(0, 0, 0)`, a trigger's kill. The drain reads its count again, so they die in the same drain, after the parent. The
parent of an annex not in the map (a loaded game: the map is not saved) is found by a rule: the units of the type, of
its player, within range, that it faces (its forward parallel to one of their axes, `|cos| ≥ 0.999`, and pointing to
their side); the nearest. A new world, time going back or a missed step clears the map (a world tick and the same
check at each use).

**Why it is safe.** The hooks keep every register and the flags (pushfd/pushad) and re-execute the replaced line; the
forward hook's continuation 0x7D7CF7 pushes `EAX`, which the replayed `lea` writes; the ghost hook's 0x96E4EC reads
`EAX`, which the replayed `mov` writes. No branch lands inside either write, 6 B at 0x7D7CF1 and 5 B at 0x96E4E7 (checked over the whole `.text`).
The creation wrapper has the stock frame (thiscall, 8 arguments, `ret 20h`). A proto without the tag costs a hash
lookup at each build command, at each ghost update, and at each death a loop of is-a tests over the tags.

**[O] The AI (2026-11-08).** An AI build plan chooses its spot in two steps, both with the world's axes: the scan of
candidate spots (PLACE at 0x87DBA5, after the axes are stored on the stack up to 0x87DBA1) and the plan's own test
FUN_0073D62B (PLACE at 0x73D7E3, the forward at `lea ebx,[esp+38h]`, the right pushed before it, the plan's position
`[plan+50h]`, its proto `[plan+ACh]`, the player in `EAX`); the build command it then sends (0x73DA17) carries the
forward of that test. With the plan's test turned but the scan not, the scan kept a spot that fitted only unturned (east of
the Barracks, where the turned Torp overlaps it), and the plan tested that spot again and again (188 times in 150 s, until
the log's cap; 3 of 4 annexes placed). Both tests now face the annex, writing the caller's two vectors (never a vector inside
the exe image), so the scan keeps only spots where the turned annex fits: 4 of 4 placed, each tested once. The plan runs where the AI runs; the
executor still turns the annex on every machine.

**[O] Destroy (2026-11-08).** The trigger effect `Destroy` runs `trUnitDestroy` (0x98282F), which calls the world's unit
removal 0x4726B2(id, 0, 1) for each selected unit from one call, 0x9828E7, and never reaches the kill queue. The removal has
62 other callers (a corpse's end, a replaced unit, the editor, the end of a game), so only that call is wrapped: the shared
module's second list (`AddDestroyObserver`) is called there for a unit alive and not dead, before the removal. `annexFacing`
registers the same observer in both lists, and its annexes are asked to die through the kill queue. `detonationDeath` is not
in the second list: a destroyed unit gave no blast before and gives none now.

**Several parents.** `<AnnexOf>` is repeatable: a unit of any of the listed types or protos can be the parent.

**[I]/unknown.** Multiplayer and recorded games: not played; the turn rides on the command's own execution. A converted
parent keeps its annexes only by the link of the session: its death does not reach them, since the annex's owner differs
(the rule wants the same player).

### doNotQueue

A unit's action list `[manager+14h]` (`+0` count, `+8` pointers) holds all its actions: in a Barracks 16 fixed ones (idle,
types 29, 68 and 34) and then the Train actions. `[manager+24h]`, the current action, was the idle one while a Train action
ran, so a building's queue is not the current action: the list order is. The first Train or Research in the list has the
state 14h and advances. The action add 0x494894 appends, and the queue routine calls it at 0x9CE81A. The hook calls it and
then moves the new action before the first Train or Research of the list, behind those of a tagged proto.

The action that was first keeps its state and progress: it no longer advances until the tagged one leaves the list, as the
two timings of the guide show. The list is saved in order.

The tech flag of the same name is bit 1Ah. Its reader is the Research action's slot 58h, 0x9E5EAD (slot 58h of the Train
action just returns 1), called only from 0x9CA1F0 when the world byte `[world+6910h]` is set.

Shipments have no such list, as far as a static reading goes: the send (0x8577D2, 0x858299) pays and starts the card.
`[hc+4D8h]`, with the count at `+4DCh`, refuses a card while it is not empty (0x858301, 0x85A7C7; 0x855F8F for the AI), but
it is the `Blockade` effect's: 0x85C09C adds the IDs, called at 0x7FBA2D for the other players.

The card queue is `[hc+288h]`, and only entry 0 advances. A `WriteCall` at 0x85AD38, the send's call of the add 0x857204, moves a
flagged entry after the stock add. Entries move as bytes, as each owns its cost list and nothing points into one. Progress lives
in the entry, so a card that waits keeps it, and a saved game needs nothing more. The wrapper returns the new place, which the
send gives to the shipment's models.

### researchOnTheMove

`src/features/researchmove.cpp`, no asm. Found with traces and capstone reading.
The rows: [engine-symbols](engine-symbols.md#wol-requests-7073-research-for-batch-2-2026-11-20), "Research actions and moving". <!-- private -->

**Why a unit with research stands still.** The research itself never holds the unit: the queue routine 0x9CCB39 adds
the Research action with `immediate` 0, so it sits in the action list `[mgr+14h]` beside the current action
`[mgr+24h]`, and the list update 0x485C44 calls every action's update (vtable `+3Ch`, then `+40h`) each tick, current or
not. What holds the unit is the question the game asks before it gives a unit a new current action: the unit's vtable
`+8Ch` (0x487E74: speed above zero, a completed building data if any, then 0x487DED). "Can take a move" 0x487DED answers
false for a current action with flag 9 or of type 2Ah, and otherwise asks 0x487D8B, "the queue holds the unit": true
when the current action is a Train (0Dh) or a Research (0Ch), or the list holds one (0x487D49 counts a type, with and
without flag 0). The order code 0x4FA0A5..0x4FA0B7 takes a false as a refusal: the order's action is left in state FFh
and replaced by idle about 5 s later.

**The change.** One call: 0x487E1B, 0x487DED's call of 0x487D8B, goes to `QueueHoldsUnit(mgr)`, which calls 0x487D8B
first and returns its answer, except when it is true for a unit (`[mgr+4]`) whose proto has the abstract type and whose
current action and list hold no Train action: then false. The unit then takes an order as a unit with an empty queue
does, the Research actions stay in the list, and the list update keeps advancing the first of them (0x9CA1F0) at the
rate of 0x9BFE33, whatever the current action is.

**Callers.** 0x487DED is asked for every unit every tick: a trace of 18 s in a scenario counted 44,042 calls, 33,024 from
the leash 0x489B15 (through 0x489B81) and 10,995 from the order code 0x4FA0B5, the rest from 0x49179E and other order
paths. The wrapper costs a call when the stock answer is false (every unit with an empty queue), and a type test and a
walk of one list for a unit with a queue. 0x487D8B's other callers keep the stock answer, as they ask whether the unit has
a queue: a unit filter's option byte `+53h` (0x672427, through 0x4537B4), a test by unit ID (0x898A7B), the repair button
of the command panel (0x9AD19C: `AutoRepairUnit` or its cancel) and the train command 0x9CE3BC. With the leash asking too,
a marked unit with research is leashed as an idle unit is.

**What the game does with the rest.** Death and knockout drop the list and refund every queued research (seen: three
ships back for three techs); the cancel of a queue icon refunds as before; a garrisoned unit (`[unit+6Ch]` ≥ 0) skips
every action of its list, so the research pauses and goes on when the unit is out; the list is saved with the unit, and
the wrapper keeps no state, so a loaded game behaves the same.

**Why it is safe.** 0x487DED continues after the call with `cmp al,1 / setne al / pop ecx / ret`: only AL is read. The
wrapper is `__fastcall(mgr, edx)`, so it takes ECX as stock's `thiscall` does, returns `bool` in AL, and keeps EBX, ESI,
EDI and EBP; the x87 stack is not used. Deterministic: the answer depends on the unit's proto and its actions only; the
log (once per unit ID) never feeds back.

### The research payment (shared)

`src/researchpay.*`, `hooks/researchpay_hooks.asm`, used by `nextResearchFree` and `researchGrants` through
`AddResearchPayer(feature, claim, started)`.

A research is paid when its action is set up, which is when it is queued: the queue routine FUN_009CCB39 (Research,
callers 0x7D47D2, 0x7D7810, 0x9E6E45) makes the action (0x48D927(0xC)) and calls its start 0x9E667A, which pays with
0x8D946A(player, cost) at 0x9E67E1, ECX the player looked up from its first argument (0x44CB21), EBP the action, the cost
`[techStatus+10h]`. On success it writes `[action+64h]` = the player ID and `[action+68h]` = the tech ID, then copies the
cost for a cancel's refund, 0x480A73 at 0x9E68A0 to `+74h`. The CommandResearch path is a research asked for by a command
of `protounitcommands.xml` (its record in `[db+2968h]`, `+20h` the tech): the command class 0xB87978 (type 3Eh) calls
FUN_009CCAAF, which makes an action of type 38h and calls 0x9D543F; that pays at 0x9D54CF (ECX the player, ESI the
action), writes `[esi+68h]` = the tech and copies the cost at 0x9D5548 to `+7Ch` (REA `ev_13bfd5e0…`, `ev_55d37da8…`,
`ev_d0df1de1…`, `ev_78a96c1c…`, 2026-11-11). 0x8D946A itself checks with 0x8D6BAE (each resource of the player at
`[player+230h]` against the cost), or 0x8D6C1B when the world byte `[world+6912h]` is set (the team's resources), then
subtracts (0x7E844B).

- **The two payment calls** go to `UhcResearchPay(action, player, cost)`, which asks each key's claim in their
  `kFeatures` order. No claim: the stock payment. A claim gives a share: 0 skips the payment; between 0 and 1 the cost is
  copied as raw encoded entries into a local list (`[0xC6DF38]` entries, the total at `+4`), scaled by 0x480B94 and paid,
  so the tech's own cost is never written; 1 pays as stock. A failed payment returns false, so the research does not
  start and nothing is spent.
- **The two copy calls** go to a wrapper that copies as stock, then, when the action is the one just claimed, fills the
  copy with 0 (0x4E2617) or scales it (0x480B94) by the same share, so a cancel refunds what was paid. Then every key's
  `started(action, share, claimed)` runs, the claiming key with `claimed` set: by then `[action+68h]` is the tech.

- **The preview,** `PreviewResearchPay(researcher, player, cost, &share)`: the same claims, in the same order, with
  `preview` set, for a display of the price (`researchGrants`' buttons). A claim answers as for a payment and changes
  nothing; the preview returns the name of the key that would claim, and its share. A claim receives the action's unit
  (`[action+10h]`), not the action, so the payment and the preview ask the same question.

**Why it is safe.** Each call keeps its stock frame: the hook reads the cost from its own argument and returns with
`ret 4` and AL, as 0x8D946A does; the copy wrapper is a `__fastcall` with the stock `thiscall` frame. Nothing between the
payment and the copy starts another research, so one pending claim is enough; it is cleared at the next payment, and
the copy acts only for the action that was claimed. A preview writes nothing the payment reads.

### nextResearchFree

The effect is a subtype through `AddTechSubtype`, which adds its amount to a count kept by the player's copy of the proto.
Its claim reads the proto from the action's unit (`[[action+10h]+5Ch]`): with a count above 0 it claims with a share of
0, so the shared payment skips the payment and empties the action's copy of the cost, and a cancel refunds nothing. Its
`started` takes one from the count. The count is forgotten when a database loads (`OnDatabaseLoad`), because a new game
can reuse the address of a proto. It is not saved, and a load applies the effects again.

- **Observed in game:** see the tests in the modding guide.

### researchGrants

`src/features/researchgrants.cpp`, `hooks/researchgrant_hooks.asm`.

- **Tags** (`AddProtoTagHandler`): the six `ResearchGrant*` tags, by proto ID, each checked for its range; a bad value
  is logged and the tag skipped. A proto has grants only with a valid `ResearchGrantInterval`.
- **Data subtypes** (`AddTechSubtype`): `ResearchGrantInterval` and `ResearchGrantMax` keep a value per player's copy of
  the proto (looked up by pointer, checked against the copy's ID), computed by the stock value function 0x7F892A from the
  tag's value; `ResearchGrantPoints` queues the points for the next world tick.
- **The units** are a set of unit IDs, in ID order. The world tick (`AddWorldTick`) looks at 256 slots of the world's
  unit table `[world+0Ch]` per update, round robin, and adds the living units of a tagged proto; a new game (another
  world, the time going back or the step count jumping) walks the whole table once, and so does a `ResearchGrantPoints`
  effect before it gives its points. A unit that is gone, dead or of another proto leaves the set.
- **Points:** for each unit of the set that is built (0x44DDB4), the tick adds the game time `[world+108h]` since the last
  tick to its timer and turns each interval into a point, up to the cap; at the cap the timer is 0. Points and timer are
  words 1 and 2 of a saved marker (`savedmarkers.h`, stat 66h, word 0 `RGNT`).
- **Spending:** the claim (after `nextResearchFree`'s) walks the set for the paying player's built, living units with a
  point, in scope, and applies the rule of the modding guide: the total cost is the sum of 0x44EFFF over
  `[[game+140h]+80h]` resources, and "can pay" is 0x8D6BAE, or 0x8D6C1B with `[world+6912h]` set. The unit with most
  points wins, the first in ID order on a tie. Its `started` takes the point from the marker and, for a Time factor
  other than 1, keeps (researching unit ID, tech ID) to factor; the next tick writes it as a second marker of stat 66h
  (word 0 `RGTI`, word 1 the tech, word 2 the factor), and a new game reads those markers back. A research of the same
  tech in that unit without a point (any key's `started` with `claimed` clear) drops the entry.
- **Research time:** a Research update (FUN_009E648B, slot 3Ch of 0xB98078) adds `BuildingWorkRate x [world+30Ch] x
  [player+37Ch] x [world+104h]` to its progress `[action+6Ch]` at 0x9E6622 (`fadd` / `fstp`), then calls the fraction
  0x9E5F19 with the tech's status entry, which divides by the research points `[entry+18h]`; the update ends the research
  when the fraction `[action+70h]` reaches 1.0 (0x9E662D). The CommandResearch update FUN_009D5843 does the same with
  `[esi+70h]` at 0x9D58FF and the fraction 0x9D539B (`[esi+74h]`). Each hook replaces those 6 bytes: while
  `g_uhcGrantTimed` (the number of entries) is 0 it adds the step as stock; otherwise it stores ST0, calls
  `UhcGrantResearchStep(action, offset, entry, step)` inside `pushad` / `popad` and adds the result, the step divided by
  the factor of (`[[action+10h]+10h]`, `[action+68h]`). The step that reaches the research points drops the entry, and
  the next tick frees its marker. Both continue at the call of the fraction (0x9E6628, 0x9D5905), whose argument is
  already pushed. A research in the other branch of the update (0x9E65A5..0x9E65F2: tech flag 4 with 0x454ED7) does not
  pass the add and keeps its stock time.
- **Panel:** `AddUnitPanelRow`, from the unit's marker and its player's copy of the proto.
- **The price shown** (display only; `noprice` leaves both sites alone). The rule is one function, `Choose`, which the
  claim calls for a payment and, through `PreviewResearchPay`, for the display, so they cannot disagree. A preview
  before the first tick of a game returns nothing, where the payment would rebuild the tables first.
  - The tech rollover builder 0x4C737C (`cdecl(text, techEntry, player, unit, a5, costOverride, a7, a8)`; REA
    `ev_8774d6a5…`) copies the tech's cost `[techEntry+10h]` (or `costOverride`) into a local list with 0x480A73 at
    0x4C73FD (`ev_06317089…`; 0x4C78FA joins there with the override pushed) and writes the cost line from that list,
    none when its total is at most 1e-6. A `WriteCall` there (`UhcGrantTipCostHook`) copies as stock, then, for the
    entry's own cost, fills the list with 0 (0x4E2617) or scales it (0x480B94) by the previewed share. Its callers
    (`ev_913c6a4f…`): the command panel 0x4622C5, the native command panel 0x9AD7F1 and the trade route panel 0x9B7637
    (identified 2026-11-28), and 0x703FAF (no player, no unit: nothing changes).
  - The command panel FUN_0046188E calls the builder for a tech button at 0x4622C5 (`ev_afcebe91…`) with ESI the entry,
    EBX the player, EDI the unit and `[esp+30h]` the rollover; the button's overlay text, the narrow buffer
    `[esp+2C0h]` (256 chars) that the Buy buttons use for their price, is emptied for each button at 0x461DBC and set on
    the button at 0x4625E2 (`ev_9abdeb84…`) when not empty. The native command panel FUN_009ACAF4 and the trade route
    panel FUN_009B687E (a trading post on a native or a trade route socket) build their tech buttons the same way:
    the same eight pushes at 0x9AD7F1 / 0x9B7637, and their own overlay buffer, `[esp+248h]` / `[esp+230h]`, emptied
    per button (0x9AD2D1 / 0x9B719C) and set on the button when not empty (0x9AE08C / 0x9B7ECE).
  - The shared tech rollover (`techrollover.*`; a `WriteCall` at 0x4622C5 from 2026-11-20, which missed the native and
    trade route panels; since 2026-11-28 a 5-byte `jmp` over `pop ebp / pop ebx / add esp,40h` at 0x4C78F3, the
    builder's only exit, whose early exits jump to 0x4C78F3 itself): the hook replays the three instructions, so
    `[esp]` is the return address and `[esp+4]`.. the arguments, calls each key's line, and jumps to the stock `ret`
    0x4C78F8. The return address tells the panel: 0x4622CA, 0x9AD7F6 and 0x9B763C give the overlay buffer at ESP +
    2E4h, + 284h and + 26Ch (each panel's buffer offset plus its call depth, 24h or 3Ch); any other game caller gets
    the lines with no overlay, and a call from DLL code (`politicianEnablesTech`'s dialog) gets none. Here the line is
    `GrantTechButton`: with a preview below the full price it writes the word or price into the empty buffer and
    appends the green line to the rollover with the BString append 0x443960 (`thiscall(text, wchar*, -1, -1)`,
    `ret 0Ch`).
  - The floating text: `started` with `claimed` shows the label over the paying unit through `floatingtext.h` when its
    owner is the local player and it is visible to them, with both stock times three times as long.

**Why it is safe.**
- The step hooks: ST0 is the only value on the x87 stack there (the getter's result and three `fmul`), so the C function
  has the whole stack; it returns its float in ST0, which the stock `fadd` / `fstp` then use. `pushad` / `popad` keep ECX
  = ESI, which the fraction call takes, and EBX / EDI; the fraction's pushed argument stays where it is. The `cmp`
  changes only the flags, which the next instructions do not read. No branch lands inside either site, and both are
  instruction boundaries (capstone over `.text`, `rea/evidence/age3y-b1a1dab7/researchgrants_cs.txt`).
- Markers are made (0x4DD22D) only by the world tick, after the world update, never inside a unit's action update; the
  claim and `started` only write the words of a marker that exists.
- Deterministic: the set and the tables are keyed by unit ID, the copy map by pointer is only looked up, the time is
  game time, and the order is the set's. The sweep's cursor is not saved: a loaded game walks the whole table, so a unit
  created in the few updates before the save starts its timer at the load instead of a few updates after its creation.
- Cost: per update, one modifier walk per unit of the set and 256 slot reads; the step hooks are one compare while no
  research has a Time factor.
- The display hooks: the exit hook replays `pop ebp / pop ebx / add esp,40h`, keeps every register (`pushad` /
  `popad`, EAX too, which 0x703F99 returns) and leaves through the stock `ret` 0x4C78F8; nothing jumps into
  0x4C78F4..0x4C78F8 (capstone over `.text`; the builder's chunks 0x63FCE3, 0x679513, 0x68F902 only jump back into
  its body, REA `ev_d4726e8c…`). An overlay buffer is written only for a known return address whose call, reset and
  read are the stock bytes. The cost hook returns the list in
  EAX with `ret 4`, as 0x480A73, and the builder keeps nothing in EAX, ECX or EDX across that call. Both are display
  only: the preview reads the units' markers and the player's resources, the overlay buffer and the rollover belong to
  the UI, and the floating text is the UI's text manager; none of it reaches the simulation, so machines that show
  different things stay in sync. Per refresh of the panel, a preview per tech button: a walk of the set (the player's
  tagged buildings) and at most one afford check.

**A/B (2026-11-11),** the test scenario of the modding guide (Ethiopians, two tagged markets), 90 s of
`tools/perfprobe.py` from the load, two researches at 50 s, two other test games running on the machine:

| | key off | key on |
|---|---|---|
| frames over 50 ms | 0 | 0 |
| main-thread CPU, mean | 89.1 % | 89.0 % |
| longest frame, median of the seconds | 2.2 ms | 2.2 ms |
| fps, median (uncapped) | 724 | 672 |

The fps differ by 7 % at about 1.4 ms per frame with the GPU busy by the other games; the main thread did the same work.
That run's second research was paid by the Market (a tie), so it had no Time factor.

**A/B of the shared tech rollover at the builder's exit (2026-11-28),** a British skirmish on a test map against a German
AI, normal UI, a trading post on a Cree socket selected with the pointer resting on a tech button (so the native
panel rebuilds its rollover), 60 s of `tools/perfprobe.py` each (first sample dropped); key on = `researchGrants log`
and `shipTechLimit log`, so the hook is written; key off = neither key, so the builder is stock. Another test game ran
on the machine during the key-off take.

| | key off | key on |
|---|---|---|
| frames over 50 ms | 0 | 0 |
| main-thread CPU, mean | 89.0 % | 92.1 % |
| longest frame, median of the seconds | 3.5 ms | 2.6 ms |
| fps, median (uncapped) | 495 | 549 |
| update / render per frame, mean | 0.64 / 1.42 ms | 0.54 / 1.28 ms |

No rise: the key-on take drew more frames (the main thread's share follows the uncapped fps) at a lower per-frame cost.
The same take in the minimised UI: 535 fps, 2.6 ms, 0 frames over 50 ms.

### shipTechLimit

`src/features/shiptechlimit.cpp`; the shared `researchpay.*`, `canresearch.*` (`hooks/canresearch_hooks.asm`) and
`techrollover.*` (`hooks/techrollover_hooks.asm`).

- **The tag** (`AddCivTagHandler`): `<ShipTechLimit>` gives a number per civ ID (0 to 100000; anything else is logged and
  skipped). A player's civ is `[[player+20h]]` when `[player+24h]` > 0 (0x4539D3).
- **A shipment tech:** the player's status entry of the tech has Ships (resource 6) above 0 in its cost list
  `[status+10h]` (0x44EFFF), the list the research pays and the rollover shows. The status of a research is found by
  0x94ADAA(`[world+7Ch]`, player ID, tech ID). A repeatable tech is not one (#91, 2026-11-21): the flag
  `YPInfiniteTech` is bit 29 of the status's bitset (`[status+4]` bytes, `[status+8]` bit count; the bit index the flag
  parser 0x622B7D gives it, read as stock's 0x44D863 reads a status bit), so the payment, the refund, the refusal, the
  rollover line and the load fallback all skip it.
- **Counting** (per player, 16): the shared payment (`AddResearchPayer`) with a claim that never claims: its `started`
  runs for every research once its action is set up, with `[action+64h]` the player and `[action+68h]` the tech; a
  shipment tech of a limited player adds 1. `AddResearchRefundObserver` (new in `researchpay.*`) redirects the two calls
  of the refund 0x8D7004: 0x9E6167 in the Research action's state 13h handler 0x9E60B4 (the cancel: it clears "being
  researched" with 0x94B85C(…,0,0), refunds `[action+74h]`, then 0x94C285(0)) and 0x9D56B5 in the CommandResearch one
  (`[action+7Ch]`); a refunded shipment tech takes 1 off. These are the only two refunds of a research action (a capstone
  scan of `call 8D7004h` over `.text`: the other nine are trains, cards and foundations). A research that completes
  (state 0Ah) or loses its unit is never refunded, so it keeps its count.
- **The refusal:** the shared head of the can-research test 0x4C6968 (`bool thiscall(status, unit)`): a 5-byte `jmp`
  over `push ebp / mov ebp,[esp+8]` to `UhcCanResearchHook`, which asks each filter and returns 0 (`ret 4`) for a refused
  tech, else replays the two instructions and goes on at 0x4C696D. This key refuses a shipment tech for a unit whose
  owner `[unit+44h]` has reached his limit. Callers with no unit (the home city's 0x857810 and 0x8579B9) are never
  refused. The research start 0x9E667A asks it at 0x9E670B before the payment, inside the execution of the research
  command, so a refused research fails on every machine (0x9E6718: nothing is paid). The command panel asks it at
  0x4620C0: false takes the button down the stock path that marks it disabled (`[esp+24h]` = 1 at 0x46216A).
- **The display:** the shared tech rollover (the exit of the builder 0x4C737C, for the command, native and trade
  route panels): a green or red line
  `Shipment techs: n/N` appended with 0x443960, and, at the limit, `n/N` in the button's empty overlay text (the panel's
  256-char buffer `[esp+2C0h]`).
- **Saved games:** a saved marker per limited player (`savedmarkers.h`, stat 69h, word 0 `'ST' << 16 | player << 8 | 2`,
  word 1 the count) on one of his living units; the world tick writes it when the count changes and moves it when that
  unit dies or loses it. A new game (another world, the time going back or the step count jumping, as in
  `shipmentCounts`) walks the unit table once and reads the markers; a limited player with none gets the sum of the
  research count bytes `[status+21h]` (bumped by the activation 0x94CF27 at 0x94D02F) over his shipment techs. A marker
  of kind 1 comes from a build before #91, whose count held the repeatable techs: on load it loses the sum of the count
  bytes of the player's repeatable techs that cost Ships, is rewritten in place as kind 2, and the change is logged. A
  repeatable research paid but still queued at that save was not activated yet, so it stays in the count (a slot too
  many, until the game ends).

**Why it is safe.**
- The head hook keeps ECX for the stock test and uses only EAX and EDX, which a `thiscall`'s caller does not expect kept;
  no branch lands at 0x4C6969..0x4C696C (capstone). The refund replacements are `__fastcall` with an unused EDX: the
  same frame as the `thiscall`, `ret 4`, and they return the refund's result.
- Deterministic: the count changes only in the research command's execution and the action's state change, on every
  machine; the filter reads it, and the display only reads.
- Cost: the filter is a map lookup by civ and one cost read for a limited player's tech; nothing walks a list per call.
  The world tick does nothing while no count changed; a marker move walks the unit table once.
- Videos (`record --perf`, other games on the machine, not a perfprobe A/B): key on 490 fps, longest frame 46 ms, none
  over 50 ms; key off 424 fps, 24 ms, none over 50 ms.

### homeCityTechsInUnits

`src/features/hctechsinunits.cpp`, `hooks/hctechsinunits_hooks.asm`; the shared `canresearch.*`.

- **Stock:** the research start 0x9E667A, after the can-research test (0x9E670B), refuses a tech with status bit 18 (the
  HomeCity flag) at 0x9E67CE (`push 12h / mov ecx,esi / call 44D863h / cmp al,1 / je 9E67C5h`) and returns false with
  nothing paid. 0x4C6968 does not refuse HomeCity techs (it skips its "already active" and ResearchLimit tests for bits 18
  and 29), so the panel shows the button of an obtainable one.
- **Start hook** (13 bytes at 0x9E67CE): the bit test as stock; a HomeCity tech goes on at 0x9E67DB (the payment) when
  the researching unit `[action+10h]`'s proto lists it in its command entries `[proto+0E8h]` (6-byte records: word ID,
  byte kind, 1 a tech; count `[proto+0ECh]`), else to 0x9E67C5 as stock.
- **Once active:** a filter of the can-research test refuses a HomeCity tech whose status has bit 1 (active) for a unit
  whose proto lists it, so its button goes away as a normal tech's does.
- **Gather hook** (9 bytes at 0x9E6553, the Research update's `push 1Eh / mov ecx,ebx / call 44D863h`): AL = the
  `CheckLandHCGatherPoint` flag as stock; when it is clear, a HomeCity tech without `CheckWaterHCGatherPoint` gets AL = 1,
  so 0x9E6560..0x9E657B cancel it (state 13h, full refund) while the player has a home city and 0x4C6B9E finds no gather
  point. `nogathercheck` turns that off (`g_uhcHcGatherCheck`).

**Why it is safe.** Both hooks use EAX, ECX and EDX, which every continuation reloads (the payment loads ECX from EDI;
0x9E655C tests AL only, and both of its paths reload ECX); EBX, ESI, EDI and EBP are kept. No branch lands inside either
site (capstone). Only a Research action reaches them, and a HomeCity tech reaches the update only through this key. The
decision reads the proto and the status: the same on every machine.

### killBountyTechs, resourceBounty and teamKillBounty

`<Bounty>` is stored by the handler 0x5F5D79 in the proto's `+168h`. On a kill, TakeDamage takes its branch 0x4D4E0C,
reads the value through 0x4D4DC5 from `[victim+5Ch]`, the copy of the victim's owner, times the attacker's `Bounty`
modifiers, and shows the text. Then 0x49B73C calls FUN_0049BD52, on every hit, with an amount of 0 unless the hit kills;
it finds the killer's team and calls 0x49BDC0(player, amount, 0), which pays resource 5 to that player, or to every
member, the whole amount, when the player is below 0 (cold 0x68EA12).

- **The subtype:** `KillBounty` and `Bounty` go through `AddTechSubtype` and the value function 0x7F892A.
- **The team:** the hook replaces `mov ecx,[esp+14h] / mov edx,[esi]` at 0x49BDAB. FUN_0049BD52 saved its caller's ESI,
  the victim, at `[esp]`. It skips an amount of 0 first, so a hit costs one compare, and passes -1 for a marked victim.
- **The resources:** a tag cannot be registered twice: 0x59B738 returns when the name exists. So the key changes the
  immediate at 0x51D669, the handler the builder registers. Its handler keeps the stock one for a `<Bounty>` without
  `resourcetype`, reads the attribute with 0x598F37, the name with 0x44709C, and stores by proto ID. The payment is a hook
  on the head of the kill branch, not on FUN_0049BD52, because a proto with no XP bounty reaches that one with 0.

- **Observed in game:** see the tests in the modding guide.

### The killing blows (shared)

`killobservers.*` owns the `jmp` at 0x4D4F37, the head of TakeDamage's cold kill path ([veterancyBonus](#veterancybonus)),
and calls each observer added with `AddKillObserver`, in `kFeatures` order: `veterancyBonus`, then `killSpawn`. The hook
reads `[esp+28h]` (the attacker unit, null when it is gone), `[esp+20h]` (the attacking player, also in EBX: loaded at
0x49B732, kept across the call 0x49BD52), `[esp+0A4h]` (TakeDamage's attacker proto ID argument; at 0x49B72B `[esp+0ACh]` is
the attacker unit ID, the argument after the action) and ESI (the victim) into registers before it pushes, replays
`mov ecx,[0C66234h]` and jumps to 0x4D4F3D. The code there reads neither EAX nor EDX before writing them. The only way to
0x4D4F37 is the `je` at 0x49B746, on `[esp+1Fh]` = 1. A death that does not come through TakeDamage (a lifespan, a delete, a
trigger's `Kill`, `Damage Unit` without a player) is not a killing blow: [`deathobservers.*`](#annexfacing) sees those.

### killSpawn

A civ's `<killSpawn>` in civs.xml lists protos and weights; a killing blow of one of its players on an enemy unit may give
an animal where the victim stood.

**[O] The tags.** `<killSpawn>`, `<killSpawnChance>` and `<killSpawnVictims>` go through `AddCivTagHandler` (civs.xml's
unknown-tag path 0x52BB07). They are kept by civ ID with the civ object they were read for; the protos (0x5A2346), the
victim types and the exclusions `Building`, `Ship` and `Herdable` (the name table `[db+190h]`, 0x58E685 / 0x40295B) are
resolved at the first kill after each database load, keyed by the proto array `[db+54h]`, as `civFirstTC` does. A player's
civ is `[[player+20h]]` when `[player+24h]` > 0 (0x4539D3). `<killSpawnKillers>` is read and resolved the same way.

**[O] The kill.** From the shared kill observer: the killer's player (`[esp+20h]`, so a shot whose shooter has died since
still counts) and its civ's list; the victim's owner `[[victim+44h]]` must not be 0 (Gaia), the killer's player or of its
team (`[player+10h]`); its proto copy `[victim+5Ch]` must not be of the three exclusions (is-a 0x44D7FA) and, with
`<killSpawnVictims>`, must be one of those types. The killer's proto copy (below) must be one of the `<killSpawnKillers>`
types, or without that tag must not be a `Building` (decided 2026-11-13: a Town Center or a tower would farm herds; a ship
counts). The chance is the civ's, run through the `KillSpawnChance` effects of the
killer's proto copy (`[attacker+5Ch]`, or `0x45311B(player, attackerProto)` for a dead shooter), rounded to a whole percent;
below 100 it rolls `0x407CE7(0xC66588, 2, 99)` (0..99) against it. With more than one animal a second roll
`0x407CE7(…, 2, total − 1)` picks by weight. The RNG is the synced one the stock dodge uses (stream 2): every machine runs
the same kills in the same order, so the rolls agree. **[O]** 0x407CE7 (capstone, 2026-11-13): `max` ≤ 0 returns 0
(0x44BD68); else the stream's 12-byte entry `[[rng+4] + stream × 12]` gets seed × 343FDh + 269EC3h, and the result is
`(seed >> 16) & 7FFFh` modulo `max + 1` (`idiv` at 0x407D1B): `max` is inclusive and the map is a plain modulo, so
`(seed >> 16 & 7FFFh) mod (max + 1)` favours the low values when
32768 is not a multiple of `max + 1`: by under 0.5 % for a 0..99 roll and under 3 % for a total of 1000, the cap.

**[O] Why the animal is not created at the kill.** TakeDamage runs inside the attack applier FUN_0049BE95, which calls it
for each unit an area attack hits (FUN_004C9D89), and the victim is still whole: alive, in the world, with its
obstruction. The stock code that does make a unit on a death, the death replacement FUN_004B4F2F → 0x506F61 (the proto
`[proto+F8h]`), runs inside the kill handler 0x4B4F70, after the unit's HP are set to 0 (0x4820A1) and 0x483262(0, 1), and
it tests the spot first with PLACE (world vtable `+14h`, FUN_0050703D, flags 2) and creates with
`0x498ACC(world, proto, player, pos, forward, 0, -1, 0, -1)`. So the kill queues the animal (proto, killer's player, the
victim's ID, position `+14h`, forward `+20h`, right `+38h`, the world and its game time), and the world tick
(`worldtick.h`, after the stock world update, outside every unit loop) places it the same way: it waits while the
victim still stands (in the world with state bit 11 clear: its kill handler has not run; at most 10 updates), then PLACE
with flags 6 at the victim's spot and, when it refuses, at 8 points 2 m around it and 8 at 4 m, in a fixed order, then
0x498ACC at the first spot that passed. PLACE refuses water, cliffs and buildings for a land animal, and the animals of the
kills before: where many die together the spot is taken. With no spot the animal is dropped with a `no room` line.
**[O]** In game the victim had always fallen by the next tick (every animal came on update 1).

**[O] PLACE's flags.** Its seventh argument (`[esp+1CCh]`/`[esp+1D4h]` in the body) is a bit set: 8 or 10h skip the terrain
block at 0x5071F1; 4 clears bit 1 of the obstruction mask (0x16F at 0x5073BB, cleared at 0x508A45) that the query 0x485652
uses at 0x507505; 8 and 10h clear 140h and 180h. The death replacement passes 2, `annexFacing`'s executor 7. The key passes
6. **[I]** What each obstruction class is was not traced. **[O]** With flags 2, and with 6 alone, a crowd of 110 dying
settlers refused about one camel in four at the spot itself; with the rings, 1 in 69.

**The tech.** `KillSpawnChance` (`AddTechSubtype`) keeps, per player's proto copy (keyed by pointer, with the proto ID
checked), the list of its effects (relativity, amount, removal) in the order they came. The chance replays them through the
stock value function 0x7F892A from the civ's chance, so `Absolute`, `Percent` and `Assign` act on that player's civ value,
which the subtype's own base (the cloned proto) cannot hold. A data load clears it; a load re-applies the effects.

**Why it is safe.**
- The hook keeps the stock frame: it re-executes the replaced `mov` and clobbers only EAX, ECX and EDX, which the
  continuation writes before reading. No branch lands inside its 6 bytes (the cold path's only entry is 0x49B746).
- No unit is created inside TakeDamage, so the applier's loop and its list of hit units are untouched; the creation runs
  where the world update has returned, as the other ticks' creations do.
- The queue is emptied within 10 updates, and an entry of another world, or of a game time that went back (a loaded game),
  is dropped. An animal still waiting when a game is saved is not saved (at most 10 updates after its kill).
- Simulation only, in kill order, on synced rolls: no local player, no real clock, no pointer order.
- Cost: one civ lookup per killing blow for a player whose civ has no tag; the rest only for tagged civs, and per animal
  one PLACE (up to 17 when its spot is taken) and one creation. The first animal of a proto in a game loads its model and
  animations, as any first unit of a proto does.
- **[I] Determinism:** the kill observers run on every machine in the same order (kFeatures), and the queue is drained in
  kill order. The world tick's position offsets are constants.

- **Observed in game:** see the tests in the modding guide.

### partisans

The stock guerrilla (the `Partisans` tags, docs/engine-symbols.md, "Partisans") per civ, changed by techs, and spawned by
the owner's nearby buildings.

**[O] Stock.** `<Partisans>` in civs.xml is an on/off flag (bit 4 of `[[civ+128h]]`, 0x659A14; a text that is not a
number reads as 1). A proto has one `PartisanType` (`+160h`, handler 0xA129D3; a second line overwrites the first) and
one `PartisanCount` (`+164h`, 0xA114C1); the proto copy 0x67E011 copies both into each player's copy. The kill handler
0x4B4F70 tests at 0x4B532F the owner's civs (FUN_004B4EBD), then in the cold block 0x6A3F04 the copy's count > 0, its first
byte argument (`[esp+0A0h]`, set for a trigger's `Kill`, `trUnitDelete`, and for the owner's delete, seen in game) clear and the build (0x44DDB4: no build record, or
its progress complete), and calls the spawn FUN_009C07D6 (one caller). The spawn takes the type from the owner's copies
(0x45311B) and makes `count` units with 0x498ACC(world, ID, player, pos, forward, 1, -1, 1, -1), each at a random point of
the dying unit's footprint (two draws of the synced random 0x422648 on 0xC66588, stream 2), with no placement test.

**The hook.** One jmp over the 16 bytes at 0x4B532F (`mov ecx,[esi+44h] / call 4B4EBDh / cmp al,1 / je 6A3F04h`; no branch
lands inside, the cold block's only entry is that `je`). `UhcPartisansOnDeath(unit, flag)` makes the stock tests with the
key's data and returns to 0x4B533F, where the stock code goes on (the proto flag 44h test, the death replacement).

**The type and the count.** The proto tags `<CivPartisan civ count>` and `<PartisanFromNearby>` go through
`AddProtoTagHandler`, kept by proto ID (`[proto+8]`), the civ and unit names resolved against each database (civ by name
0x58E71F, proto by name 0x5A2346, keyed by the proto array `[db+54h]`). At a death: the dying unit's copy `[unit+5Ch]`;
the line of the owner's civ (`[[player+20h]]`) if there is one, which also turns the guerrilla on; else the copy's own
`+160h` / `+164h`, on only when the stock civ test 0x4B4EBD says so. Then the effects of that copy: `PartisanType`
(`AddTechProtoSubtype`; the effect's `unittype` resolved to a proto ID when the techs are read, in its field `+10h`)
replaces the type, its removal gives back the type before it; `PartisanCount` (`AddTechSubtype`) replays relativity and
amount through the stock value function 0x7F892A from the count above, so `Absolute` and `Percent` act on the civ's count.
Effects are kept per copy pointer with the proto ID checked, as `killSpawn` does; a data load clears them and a saved
game's load applies them again. The count is capped at 100.

**The spawn.** With the stock type and count the stock spawn runs. With others, the copy's `+160h` and `+164h` hold them
for the call to 0x9C07D6 and get their values back after it, so the units come out where and as the stock ones do (the
same random draws). With `<PartisanFromNearby>R</PartisanFromNearby>`: the units near the dying one (0x4A1C55, radius R,
to the unit's edge), kept if the owner's, not the dying unit, of the abstract type `Building` (is-a 0x44D7FA), alive (unit
vtable `+A4h`) and built (0x44DDB4); sorted by distance (vtable `+B8h`), then by ID. Unit *i* goes beside building
*i mod n*: the first of 48 points (4 rings, at the building's larger obstruction value `[proto+88h]` / `[proto+8Ch]` plus
1, 2.5, 4 and 6 m, 12 points each, in a fixed order) that PLACE (world vtable `+14h`, flags 6, as `killSpawn`) accepts,
then 0x498ACC(world, ID, player, point, the building's forward, 1, -1, 1, -1), the stock spawn's arguments, inside the
kill handler as the stock spawn. No building in range: the stock spawn. **[O]** In game the units of one death, once made
beside their buildings, walk over to the nearest group of the same unit and stand in a line; the same with 0, -1, 0, -1,
and when a world tick made them one per update. **[O]** It is stock: with the key off, 3 Rodeleros walked 20 m to the 4 a
Barracks' stock guerrilla had just made. **[U]** Which code orders that walk was not traced.

**Why it is safe.**
- The hook reads the kill handler's argument before any push, keeps EBX, ESI, EDI and EBP (stdcall), and clobbers EAX,
  ECX and EDX: the continuation 0x4B533F loads ECX, and every path after it writes EAX before reading it (0x4B5348,
  0x4B5362).
- The tests are the stock ones in another order; none has a side effect. A copy's two fields are changed only during the
  call to the stock spawn, which reads them and nothing else changes them meanwhile (the simulation runs on one thread).
- The spawn runs where the stock one runs, inside the kill handler, as the death replacement creates its unit there too.
- No new random draw, no real clock, no local player: the nearby order is by distance and unit ID.
- Cost per death: a hash lookup by proto ID and, for a copy with effects, a second one; the stock civ test otherwise.
  The nearby query runs only for a dying unit with `<PartisanFromNearby>` and a guerrilla.

### cantBeSlowed

0x4DD1DE, the `TargetSpeedBoost` path, tests that the target can move, and 0x4DD201 pushes the arguments of the
modifier's creator 0x4DD22D. The hook replaces the first three pushes, and leaves through 0x48FA49, the path's exit, for a
marked target. The poison of `damageOverTime` calls the creator itself, so it asks the same function. The site is in the
ranges `damageOverTime` and `snareOnlyHitUnit` verify, so this key comes after them in `kFeatures`.

**No type on the attacker (since 2026-11-21).** From 2026-11-05 to 2026-11-20 the key also read a second type,
`CannotSnare`, on the attacking unit (`[ebp+10h]` at 0x4DD201, `docs/engine-symbols.md`, "Snare attacker"), and the
poison read it on the unit that attached it. It was retired: an attack that should not snare loses its
`<TargetSpeedBoost>` in the attacker's tactics, which needs no code. The key no longer registers the name, so a proto
that still lists `<UnitType>CannotSnare</UnitType>` loads as with any unknown type: the line is dropped (or, with
`customAbstractTypes` naming it, it is a plain type that nothing reads).

### stealthTargeting

**Stealth in the stock exe.** The tactics action type `Stealth` (47h; factory case 0x4EF7DF, vtable 0xB982A8) runs while
the unit is in its stealth tactic. Its update 0x9E8A26 sets unit state bit 42h (`or byte [[unit+4]+8], 4` at 0x9E8AE5)
and queues the unit's visibility update (0x482B8A); its end 0x9E890D clears the bit (0x9E892F). Every few seconds the
update queries the units in the action's range and, for an enemy of `AbstractCanSeeStealth` (the abstract type at
protoCount + 53h, 0x9E8C12) that has the unit within its own LOS, sends the owner a command (type 35h, 0x82FD72) that
takes the unit out of the tactic. The tactic tag `CheckIfCanStealth` is bit 10h of the tactic's flags (0x68DC87).

**Where it failed.** The per-unit visibility update 0x48679A passes the bit (inlined at 0x486888) as the 14th argument
of the per-player visibility 0x486B1A (`thiscall(proto, ...)`, `ret 38h`), which builds the mask of the players that see
the unit, written to `[[unit+B4h]+ACh]` at 0x486A60. In its small-unit branch, a non-allied player is skipped for a
stealthed unit (0x486CD0 → 0x4E0B12 → 0x486E11), before its LOS test. A proto whose `[proto+88h]` or `[proto+8Ch]`
(the obstruction radii X and Z) is over 1.0 takes the footprint branch instead (`jp 0x493040` at 0x486C0D and
0x486C24), which tests the LOS on every tile of the unit's rectangle: its player loop (0x493150..0x493321) reads only
`[esp+38h]`, the "only allies see it" byte (set by proto flags 8 and 9), and the stack slot of the stealth argument is
overwritten by its next instruction (`fnstcw [esp+68h]`, 0x493048) and later used as a loop counter (0x49312D). So
enemies saw a large stealthed unit, found it as a target and attacked it; the AI saw it too. A write breakpoint on the
mask of a stealthed submarine (obstruction Z 2.5) caught 0x486A60 writing 2 → 6 (player 2 added) when enemy ships came in
range.

**The hooks.** At 0x493040 (`fld [esp+4Ch]` / `movzx edx, byte [esi+0Dh]`, 8 bytes, re-executed; reached only by the two
`jp`), a set stealth byte `[esp+68h]` sets `[esp+38h]` to 1: the footprint branch then skips non-allied players (0x493201
→ 0x4E0B1F → 0x493154) and lets allies go on to their LOS test, as the small-unit branch does for stealth. The local
byte was already written on the way in (0x486BF6 or 0x4841F5), and no other reader of it follows in that branch.
The second hook is the head of 0x489ECC, `int thiscall(tactic, attacker, target, ...)`, `ret 1Ch`: the attack action the
attacker would use on the target, -1 for none. Its callers include the unit queries that keep only attackable units
(0x499CE4) and the auto-attack scoring (0x4A893B); the other call sites (12 by capstone, REA `ev_3e7fba22…`) were not
each identified. In the AI test it refused one try of an AI ship at a submarine it had seen before. For a target with state bit 42h set, `UhcStealthHidden` returns -1 unless the attacker's player's bit
is in the target's mask; every caller already handles -1. The test on the bit is inline, so other targets cost a
few instructions.

**Why it is safe.** The first hook changes only a local byte the branch already honours; flags and registers after it are
as the two re-executed instructions leave them, and the code after 0x493048 does not read the flags. The second runs
before the function's own pushes: ESP, EBX, ESI, EDI and EBP are untouched on both paths, and -1 leaves through the same
`ret 1Ch` as the stock failure path 0x4974C1. The mask and the state bit are simulation state, computed for every player
on every machine; the key reads no local player and no clock.

### autoScout

**Who scouts.** The data decides: a unit scouts while its current tactic is the key's (`AutoScout` by default). The
current tactic is `[[unit+58h]+0A8h]`, an index into the proto's tactics `[[proto+44h]+10h]`; a tactic's `+8` is its
name ID, an index into the database's tactic names `[db+1FF0h]`, which the key searches once per data load for its
name. A unit is born in its first tactic, so a file with `AutoScout` first scouts from birth; the buttons run
`unitSetTactic`, the game's own set-tactic command (type 19h), which every machine runs and saved games keep.

**The scan.** `AddWorldTick`, every 500 ms of game time `[world+108h]`. Each player's unit list `[player+F8h]` (count
`+FCh`), validated through the unit table and its owner, gives the scouts, sorted by ID. For each player with scouts,
the visibility grid of the world (`[world+250h]`: width `+14h`, height `+18h`, one dword per 2 m cell at `+20h`; the
player's mask `[[world+2D8h]+4·id]`, its low half explored, its high half visible) is summed in blocks of 8 × 8 cells:
which blocks are visible now, and per movement type an unexplored cell to stand on. The water of each cell comes once
per map from the terrain's tile lookup (vtable `+194h` of `[world+88h]`, 0FFh for land); the movement type is
`[proto+1D2h]` (1 land, 2 water, 4 air).

**The orders.** A scout that is idle (0x44F1A7), or still on the move this key gave it (the current action's ID
`[[mgr+24h]+8]` is the one it got), is given a target when it has none or its target was explored: the block whose
unexplored cell is nearest, weighted against cells behind its heading, not held by another scout of the player and not
given up by this one; then the nearest unexplored cell of that block. The order is the action manager's own move,
0x50E36A, with the arguments of the unit order code (0x9444D3), but `a4` = 1, which sets action flag 17h: the leash
0x489B15 skips a Move with that flag (0x4B95E4). A scout that stops (idle, not interrupted by another action) with its
target unexplored, or that takes 90 s, gives the block up. When no unexplored cell is in reach, the target is the block
not visible now with the oldest last-seen time (this key's own stamps, game time), the nearest first. Any other action
(a fight, a flee) is left alone, and the scout goes on when it is idle again.

**Danger** (2026-11-20; `noAvoid` and `noBack` turn the two parts off). *Avoid:* for each player with scouts, each
scan walks the unit lists of the players whose stance toward it is enemy (0x484D2D on their player) and keeps, by
unit ID, the buildings (abstract index 2, 0x44CAC4) that are built (0x44DDB4), alive, and have an action with ranged or
siege damage (the proto's actions `[[proto+44h]+1Ch]`, count `+20h`; the damage record `[action+24h]`, its type byte
`+5`; the longest maximum `+8` of the 16-byte range entries `[action+18h]`, count `[action+1Ch]`), once the cell they
stand on is visible to the player (the high half of its bits), or explored on the first scan after the tables were
built (a loaded game). A dead one is forgotten. Each is a circle of its range + 12 m. *Back:* the scan keeps each
scout's hit points `[unit+64h]`; a drop is a hit. The units within 40 m (0x4A1C55) that are alive, have a damage action
and belong to Gaia or to a player whose stance toward the scout's is enemy give the attacker, the nearest (the lower ID
on a tie); a circle of its reach (at least 6 m) + 16 m around it, or of 24 m around the scout when there is none, is
kept 120 s of game time (32 at most per player, the oldest dropped first; a hit within 6 m of a circle refreshes it).
The scout gives its target up and gets the same move order (taking over a stock flee or fight, which would leave it
in range) to a point out of the attacker's reach + 10 m, 24 to 60 m away (the first of seven headings, from straight
away to 105° off, that is on the map, standable for its movement type and outside every circle), and keeps it for 8 s
or until it stops; a hit during a back-off less than 3 s old orders no new one. *Both:* a block whose centre is within a
circle's radius plus half a block is never a target (unexplored or revisited). The target is, in this order: the
nearest unexplored one whose straight line from the scout crosses no circle (for a circle the scout is in: comes no
nearer its centre than the scout is); the seen block
visited longest ago by such a line; the nearest unexplored one whose line crosses; the oldest seen one whose line
crosses. A scout whose target block becomes unsafe gets another target (the block is not given up). The circles and the per-proto reach cache are the key's own tables, keyed by unit ID and proto, walked in
ID and insertion order, rebuilt after a load.

**The leash.** The action manager walks a unit back to its anchor `[mgr+7Ch]` (x, y, z) when its current action has no
order ID and it strays past a range (0x489B15 → 0x50E50E, a move with tolerance 1.0). That is what makes a flying pet
circle its start when it has no orders; the animal wander `BUGA::doWander` runs only for a unit in a herd (`[mgr+ACh]`
≥ 0). Each scan writes a scout's position into its anchor, so that a unit that stops scouting stays where it is.

**The switch-off.** The command execute FUN_007C8E49 runs once per command, inside the world update (0x481BC2 →
0x490015 → 0x64D31A), on every machine. Its head (`push ecx / push esi / mov esi,ecx / cmp dword [esi+5Ch],5`, 8
bytes) is replaced by a `jmp` to `UhcAutoScoutCmdHook`, which calls `UhcAutoScoutCommand(cmd)` with EAX, ECX and EDX
saved, re-executes the four instructions and jumps to the `jbe` at 0x7C8E51 with their flags. For a work command (type
`[cmd+81h]` 0: move, attack, gather, garrison) or a stop (9), each listed unit `[cmd+40h]` owned by the command's
player `[cmd+20h]`, not inside another unit (`[unit+6Ch]` = -1) and in the scouting tactic, gets its anchor set to its
position and its return tactic through setTactic 0x4F7ECD(mgr, player, index, -1, 1, -1.0f, 1, 0), as the set-tactic
command does per unit (0x7D107C). The order then applies to a unit in its normal tactic.

**Why it is safe.** Everything read is simulation state: the unit and player tables, the tactic, the grid (the display
switch of `blackmap` is not read), the terrain, game time. The containers are keyed by unit ID and player, and walked
in that order. The orders and the tactic change are the game's own simulation functions, the same ones its unit orders
and commands call, in the world update, so every machine makes the same calls in the same order; nothing goes to the
network, and nothing reads the local player. The tables are only a cache: a loaded game (or another game) starts them
again from the units' tactics and the grid, and the tactic itself is saved with the unit. The hook keeps every register
the stock head needs (ECX, the flags of its `cmp`), and the stdcall callee keeps EBX, ESI, EDI and EBP. The real clock
of the `log` timing line only goes to the log. The danger tables read only simulation state (the player's own grid
bits, stances, units, hit points); the attacker search does not depend on the order of the spatial query's list
(nearest, then lowest ID); the reach cache keyed by proto pointer is a memo of data, emptied when the data changes.

<!-- private:begin -->
**What was measured.** Two ravens of the Romanians on Great Lakes, the rest of the player idle: 9.4 % / 9.7 % of the
map explored at 3 / 6 minutes without the key, 63.7 % / 100 % with it (2026-11-19, without the danger parts; with the
default key on 2026-11-21: 64.6 % / 97.8 %, the ground around the enemy Town Center left out). The Dutch envoy alone on the same map: 50.1 % /
71.1 %. A scan: about 50 µs with two scouts on 155 × 155 cells (with `log`, the order lines make the first scans cost
milliseconds). Danger (2026-11-20, a 260 m map with four enemy outposts and seven Musketeers, an Explorer and an Envoy):
61.5 % / 70.5 % at 3 / 6 minutes and the Envoy killed with `noAvoid noBack`; 68.7 % / 79.4 % and both alive with the
default; about 90 µs a scan.
<!-- private:end -->

### autoGatherFrom

**The tag.** `<AutogatherFrom delay="s">Name</AutogatherFrom>` in an action is read by the shared action tag hook
(`actiontags.*`, 0x5FA11E), keyed by the proto ID `[proto+4]` and the action's name index `[action+4]`; the `delay`
attribute through the XML attribute reader 0x598F37 (the tag's node is passed to the handlers since this key). The name
is looked up lazily in the unittype table `[db+190h]` (0x58E685, 0x40295B): a proto or an abstract type, tested later
with the is-a test 0x44D7FA. The tables are emptied at each data load (`OnDatabaseLoad`).

**The scan.** `AddWorldTick`, every 500 ms of game time `[world+108h]`. For each player from 1, its unit list
`[player+F8h]` (count `+FCh`), sorted by ID; a unit whose proto (the player's copy) holds a tagged action, alive,
built (0x44DDB4), not inside another unit (`[unit+6Ch]` = -1) and with an inventory `[[unit+B4h]+94h]` (the Gather
start sends a gatherer without one to state 9, 0x50DE80..0x50DE90). Per proto pointer the key caches the sources and the
action's range: the longest maximum `+8` of its 16-byte range entries `[action+18h]` (count `[action+1Ch]`), which hold
`<maxrange>` and the `<typedmaxrange>` lines. A busy unit (0x44F1A7 false) only gets its leash anchor `[mgr+7Ch]` set to
its position while its current action `[mgr+24h]` is a Gather (vtable 0xB97880). An idle one starts a timer; after the
shortest `delay` of its sources the nearest unit within range + 12 m (0x4A1C55) that is alive, of a named type, owned
by Gaia, the unit's player or a player that is not its enemy (0x484D2D), that the player can see (0x48A9EF, the test
the Gather update makes at 0x4EC753 before it drops an order with state 9), and within the source's range measured to
its edge (the target's vtable `+B8h`, a distance from its obstruction to a point) is the target (the lower ID on a
tie). A unit that cannot move (MaxVelocity `[proto+80h]` ≤ 0) is scanned only while `buildingGather` is applied
(`g_uhcBuildingGather`), and its range test is the gather's own: the gatherer's vtable `+CCh(target, range)`, which
counts the building's size.

**The order.** FUN_004EFCB2, `thiscall(mgr, targetId, 0, -1, 0)`, `ret 10h`: the action manager's work order, the one
the stock idle-herdable search FUN_004C31EE gives a pen or a magnet within 10 m (the call at 0x4C31E4 passes the radius
10.0 and -1), and the one the command execute's unit-order path calls (0x944D3F, 0x944E0D). It sets `[mgr+94h]` = -1,
picks the action for the target and walks the unit there; the trigger `trUnitDoWorkOnUnit` reaches the same code
through a network command (0x833681). The held amount of the unit's main resource (0x4DBEC1, 0x4E5979) is kept at the
order: if the unit is idle again with no more than that, the target is refused until the amount changes. A building is
exempt: what it gathers goes to the stockpile, so its held amount never rises.

**What stock already does.** A Gather action's range (`<maxrange>`, `<typedmaxrange>`) is respected for every target
kind tried: mine, Mill, Plantation, hunt (Hunting), a nomad. The Gather action follows a target that moves. A building
ordered to gather gets a Gather action that never starts: see [buildingGather](#buildinggather).

**Why it is safe.** Everything read is simulation state; units are walked by player and ID, the containers are keyed by
ID, and the order is the simulation's own function, called in the world update on every machine; nothing goes to the
network or reads the local player. The per-unit table (idle-since time, last target, held amount) is a cache: a loaded
game rebuilds it and an idle unit waits `delay` again. The real clock of the `log` timing line only goes to the log.

### buildingGather

**How a Gather action starts (2026-11-22, capstone over the chunks Ghidra has no function for, and hardware
breakpoints in game).** The Gather action (vtable 0xB97880: `+34h` setState 0x4ED249, `+3Ch` the update 0x4EC4FA,
`+44h` the event handler 0x4EC904) keeps its state in the byte `[action+61h]`, its gatherer in `[action+10h]`, its
target's ID in `[action+14h]` and its range in the float `[action+24h]` (15.0 for `<maxrange>15`, read in game). A new
order sets bit 1 of the action's flags (`[action+30h]`, count `+34h`); the next update runs the start code 0x50DE3E
(`ja` at 0x4EC6BD). It refuses a gatherer without an inventory `[[unit+B4h]+94h]` (0x50DE89, setState 9: a Market
without `<CarryCapacity>`, traced) and otherwise calls setState(0) at 0x50DF3D (a target of the proto `[db+6098h]` goes
to 5 at once, 0x6A8ECF). The state-0 handler 0x4EECED sets the walk up; for a building the state byte stays FFh. The walk
reports its end as event 9 to the event handler (`[event+1Ch]` = 9 → 0x4EDA75): after some target kinds of their own,
the gatherer's vtable `+CCh(target, [action+24h])` (0x48C3E1, a `jmp eax` trampoline) says whether it is in range, and
with state 0 the action goes to 5 at 0x4EDB7B (traced for a Settler: setState(5) from 0x4EDB87 ← 0x48CEAE ← the unit
update 0x482F9A). A building never walks, so no event 9: its Gather action stayed at FFh, updated 37,908 times in a
minute with one setState in all. While it waits, the update still drops the order (setState 9 at 0x6A8F32) for a
target its player cannot see (0x48A9EF at 0x4EC753), so a building only gathers what it sees.

**The hook.** At the update's exit test 0x4EC76B (`cmp al,0Ch / je 586D8Bh`, 8 bytes; AL = the state byte read at
0x4EC760, ESI = the action, EBX and EDI the saved registers still on the stack) a jump to
`UhcBuildingGatherHook` (`hooks/buildgather_hooks.asm`), which redoes the compare (0Ch → 0x586D8B) and, for state 0 or
FFh, calls `UhcBuildingGatherApproach(action)` with every register saved (`pushad`), then continues at 0x4EC773
(`pop ebx / pop edi / pop esi / pop ebp / add esp,0Ch / ret`). That function returns at once unless the gatherer's
proto (the player's copy `[unit+5Ch]`) has MaxVelocity `[proto+80h]` ≤ 0 and the target is alive in the unit table; then
it makes the event 9 test, `vtbl[+CCh](gatherer, target, [action+24h])`, and calls the action's own setState
(`vtbl[+34h]`) with 5 when in range, 9 when not.

**What follows is stock.** In state 5 the gather tick runs as for a villager: the resources go to the stockpile at the
action's rate (a Market's held amount stayed 0; the player's gold rose 1 a second from a Mine at rate 1), a used-up
target is replaced by the next of its kind nearby (three crates in a row), and a standing tree gives wood with no chop.
Saved games keep the state byte (the Gather save, vtable `+5Ch` 0x9DD0B6); after a load the Market kept gathering.

**Why it is safe.** Only an action that waits for a walk, of a gatherer that cannot walk, changes; units that move
never do (the MaxVelocity test comes first). The change is the game's own transition with its own range test, made in
the world update on every machine; nothing reads the local player or a clock. No branch lands inside the 8 bytes
(checked over the whole `.text`), every register is restored (`popad`), neither continuation reads the flags before
setting them, and both are the ones the stolen `je` had. Cost: a byte compare in every Gather update. A/B (60 s, 30 settlers and two Markets gathering): 576 / 551 fps, main
thread 83.6 / 79.3 %, update 0.19 / 0.18 ms, no frame over 50 ms either way (other games ran beside it).

### herdWalkAwayFix

**The walk-away.** In the gather tick's cold path, a herdable gathering into its own inventory that is full and whose
target is the LivestockPen proto (`[db+6030h]`), the paddy (`[db+607Ch]`) or of the abstract type 5Bh
(`AbstractTypeHerdableMagnet`, 0x44CAC4) is sent away: 0x6A8C8B..0x6A8C9C `push 0 / push 6.0f / push targetId / call
4E3A37h`, the flee move (`thiscall(mgr, targetId, distance, flag)`, `ret 0Ch`, a point away from the unit with the
synced RNG), then the tick returns; any other full herdable ends its action (state 0Ah, 0x6A8CAB).

**The fault.** The flee leaves the action manager's anchor `[mgr+7Ch]` as it was, and the leash 0x489B15 walks an idle
unit back to its anchor. A herdable drawn by the idle search 0x4C31EE keeps the anchor it had before (its spawn point),
so with a magnet that moves, the fattened herdable walked back to where the herd had been (observed: two sheep 33 m
back, anchors at their spawn points; ordered camels keep an anchor near their gather).

**The fix.** The call at 0x6A8C9C is redirected (site `HerdWalkAwayCall`, 0x6A8C94..0x6A8CA0 verified) to a
`__fastcall` wrapper with the same frame (ECX = the manager, three stack arguments popped). It makes the stock call,
then writes the anchor: the herdable's position plus 6 m along the line from the target through it (its height kept).
The return value is passed on (the caller ignores it).

**Why it is safe.** One call site, no other caller changed; the anchor is simulation state that the game saves and
the leash already uses; the point depends only on the two units' positions. The flee keeps its own random point.

### faithResource

An optional key: resource 4 (`SkillPoints`) made a plain resource for a mod to gather and spend (a faith that
villagers gather by praying, with the mod's data). In the stock game resource 4 stands for the home city's skill points
in three places (two of them changed), and a Gather action never plays its own animation; the key changes the
reads, the bank and the animation.

**The reads.** The skill point total `0x5011C6` (`int thiscall(player)`) returns int(resource 4) plus the home city's
unspent skill points `[[player+84h]+1F4h]`. Six places call it instead of reading the list entry: the KB getter
behind `kbResourceGet` (`0x86B637`), the AI's KB copy loops (`0x86D8C5`, `0x8767D2`), the `{resource()}` text of the
interface (`0x63C8C6`, from `0x453EA9`), `trPlayerResourceCount` (`0x98859E`, a tail jump) and the per-player
statistics snapshot (`0x501211`). The key turns its `je 501209h` (`0x501201`) into `jmp`: the function returns
int(resource 4) alone, as it does for a player with no home city, so every caller reads the plain amount. The home
city's own uses of its skill points (buying a card, `0x857DB2`: `[HC+1F4h]` ≥ 1, decrement) never went through it.
REA `ev_ab8acb45…`.

**The bank.** At the end of a game FUN_00852924 (`thiscall(homecity)`, four callers: `0x7074D7`, `0x862C41` before the
home city is written, `0x865579`, `0x980344`) adds resource 5 to the home city's XP and resource 4 to its skill points,
then sets both resources to 0. A 6-byte `jmp` at `0x852A3B` replaces `add [esi+1F4h],edx` with `UhcFaithBankHook`,
which adds nothing (with `log` it writes EDX, the amount, and the skill points) and returns to `0x852A41`; `EB 0C` at
`0x852A4A` jumps over the clear of resource 4 (`mov ecx,[esi+8]` / three pushes / `call 49A8C5h`, a balanced call), so
the amount stays in the game if a caller ever runs before its end. The XP half, the x87 sequence around the add and
the clear of resource 5 are untouched. REA `ev_b5972f48…`.

**Not changed: the AI's card budget.** FUN_006AED5E gives each AI player with a home city a level from the human
players (`[HC+54h]`), sets its resource 4 to that level + 15 (`0x6AEEDC`, `0x6AF052`, two branches) and resets its
home city (`0x85A63E`, skill points level − 1). The AI buys its home city cards at the start from resource 4: in a
stock skirmish its resource 4 went 20 → 6 (14 cards) while its home city's points stayed 9. Zeroing that seed (the
key's first version) left the AI with no cards, so the key keeps it, and an AI starts with what it did not spend (6
there) as faith. An AI script that reads its budget through `kbResourceGet(cResourceSkillPoints)` (the stock
`buyCards` rule does) now gets resource 4 alone; adding `kbGetHCLevel(cMyID) - 1` gives back the stock total (with
it the same 14 cards were bought with the key on).

**The animation.** The Gather action's state change FUN_004ED254 stores the animation to play in `[action+74h]` from
the target's unit types only: a mine, a tree, a farm, a hunt, a fish, a crate, a fire pit (DanceActive), else
GatherBush when the model has it, else GatherFarm; the chain starts at `0x4ED355` and every case leaves to `0x4ED3FA`.
The tactics action's `<anim>` (`[[action+4]+58h]`) is never read, so villagers sent to a church that holds faith
danced, whatever the `<anim>`. A 7-byte `jmp` at `0x4ED355` goes to `UhcFaithGatherAnimHook`: when `[action+70h]` (the
resource gathered) is 4, the tactics action has an anim (≥ 0) and the gatherer's model has it (`0x471D24(unit,
anim)` ≥ 0, the lookup the attack code uses), it stores that anim and leaves to `0x4ED3FA`; otherwise it redoes
`mov ecx,[edi+5Ch] / cmp ecx,ebx / je 4ED36Bh` and continues at `0x4ED35C` or `0x4ED36B`.

**Why it is safe.** Every write is a few bytes checked by `VerifyAll` (`FaithTotal`, `FaithBank`, `FaithBankClear`,
`FaithGatherAnim` and the two continuations, and `0x471D24`). Only resource 4 and its home city
link change: a mod that uses resource 4 for skill points must not turn the key on. At `0x852A3B` the flags of the
skipped `add` are dead (`fldcw` and a call follow). At `0x4ED355` EAX, ECX and EDX are dead (every stock case sets
ECX at once; EAX and EDX are set before they are read after `0x4ED3FA`), ESI/EDI/EBX/EBP are kept, and a gather of
food, wood, gold, XP or oil takes the stock chain unchanged. Simulation: the amounts are simulation state, the same
on every machine with the key, so every player needs it (multiplayer not tested). Saved games keep resource 4 as
any resource (tested).

### transformChecks

**The stock transform.** `uiTransformSelectedUnit("Proto")` (UI command 0x7E7193) looks the proto up and sends a
network command, type 17h, for the selection; every machine runs it in the world update. Its per-unit execute
FUN_007D64F7 (`thiscall(cmd, unit)`, vtable `+54h`), for each selected unit on its own: the player (0x44CB21) and its
copy of the target (0x45311B, kept at `[esp+14h]`), the target's cost (0x480B1E into a cost list at `[esp+18h]`), the
unit alive and owned by the command's player, then **PLACE**, world vtable `+14h` (FUN_0050703D), with `(protoId,
playerId, &unit+14h, &unit+20h, &unit+38h, 0, 2, int* reason, 0, 0, 0)`; then, with the command's payment flag
`[cmd+90h]`, the payment 0x8D946A (or the "not enough resources" message 42A8h to the local player); then the target,
created by 0x498ACC at the unit's position and completed by 0x6A1F82 when the unit was built, and the unit removed.
PLACE applies the target's placement rules and its allowed age (in game: a youth 6 m and 18 m from a gunpowder kraal
became an Askari maturing, one 32 m away did not); its eighth argument receives the failing rule's `errorstringid`
(72617 for the gunpowder kraal rule, read in game). The unit itself is an obstruction for the target unless the target
is `NonCollideable`. Nothing tests the target's build limit.

**The build limit.** The hook at 0x7D65E3 replaces `test al,al / je 7D6762h`, right after PLACE. A refusal of PLACE
goes to the stock refusal 0x7D6762 (the cost list's destructor, `xor al,al`, `ret 4`). An acceptance calls
`UhcXformAllowed(player, playerProto, unit)` inside `pushad`: the limit is 0x4C7B5F on the player's copy (−1: none),
the count the player's living units of the proto ID, from its unit list `[player+F8h]` (count `+FCh`) through the
unit table. At the limit, the refusal; else the stock continuation 0x7D65EB (the payment). A command for six units
runs the execute six times in a row, and each new unit is in the list at once, so the sixth sees five.

**The button.** The command panel's button hook (`panelbuttons.*`, at 0x462317, where every grid button joins with its
state `[esp+24h]`, its click and shift-click commands `[esp+1C0h]` / `[esp+3C0h]` and its rollover BString
`[esp+18h]`, filled by the command layout at 0x695D60..0x695D82) runs the key's filter. For a click command
`uiTransformSelectedUnit("Name")` it asks, for the local selection (0x453B28; only when its player `[sel+0Ch]` is the
local player), for each selected unit in the command's own order: PLACE with the same arguments as the command, the
limit (as above, counting the units already accepted in this selection), then the cost of one more unit (0x480B1E,
then 0x8D6BAE or 0x8D6C1B with shared resources, `[world+6912h]`). No unit passes: state 1 (grey), both commands
emptied, and a red line appended to the rollover (0x443960): the string of PLACE's reason, or 25528 or 36198 (with the
target's display name `[proto+140h]`, read in game). The exception is a refusal for the cost alone (every refused unit
passed PLACE and the limit): the button keeps its state and its commands and gets only the red 41543 ("Not enough
resources"), so the click reaches the execute, whose payment fails at 0x7D6610 and calls the stock "can't pay" message
0x8D271A (string 42A8h = 17064, the missing resources, 2000 ms, and sound entry 4 when the message call returns true),
the routine the train enqueue (0x9EB132) and the research (0x9E6824) call. A group of three youths gave one message.
A button whose click is `commandResearch(ID, unit)` (a command with an `<associatedtech>`, the fireship) runs the
command as a one-shot research of that unit, and a failed transform still took the button off that boat (seen in
game), so in that case the click and shift-click are rewritten to `uiTransformSelectedUnit("Name")`, the command the
record runs. Some pass: a yellow "N / M:" line with the
first reason. The answer is kept 250 ms of real time per target name and selection.

**What a transformed maturing shows (data, not the key).** The kraal maturings' anim files (`maturing2.xml` to
`maturing4.xml`) pick their submodel with `<logic type="BuildingCompletion">`: the dancing youth (`lvl1`..`lvl6`,
the youth model with the dance, the chant sound set and particles) from 1 % to 99 % built, and `finished` (only the
soil decal) at 100 %. A placed maturing dances while the youth builds it; the transform creates the target already
built (0x498ACC, then 0x6A1F82 when the old unit was built), so it shows `finished` from its first frame: no dancer.
Their final unit comes from a single-use `Spawn` action in the tactics, which fires when the maturing unit is
complete, so after a transform it comes out at once, and the maturing unit only lingers until its `<Lifespan>` ends
(seen in game: the Askari next to the maturing ground within a second of the click, the ground gone 20 s later). The
fix is in the data: give `finished` the `lvl6` dancer, without its Death anim (the maturing dies at the end of its
lifespan, and a falling youth would show then); the youth then dances beside the new unit for that lifespan, and a
placed maturing does the same after it is built.

**Why it is safe.** The hook keeps every register but EAX, which neither continuation reads before loading it again
(AL only fed the test it replaces); the frame (`[esp+14h]`, `[esp+30h]`) is the execute's own, checked by the site
`XformExecBody`. The count reads simulation state only, walks a list in its own order and decides the same on every
machine; the log never feeds back. The button filter is interface only: it reads the local selection and calls PLACE
and the cost getter, which only read (PLACE is what the AI calls to test build spots), and changes only the button.
`nativePreview` and this key add their filters to the one hook.

### customWalls

**Walls in the stock exe.** A proto with the flag `wallBuild` (bit 3Ah of `[proto+50h]`, tested with 0x45EE02) enters the
edit mode `buildWall` when its button is pressed (0x7E4762), whose clicks run `uiBuildWallAtPointer` (0x7DFE31 →
0x84B5B3 → 0x847DBF on the world UI `[game+91Ch]`; the proto on the cursor is `[ui+4A4h]`). The wall layout 0x9F66D9,
`thiscall(store, player, points, count, -1)`, splits each stretch between two clicked points into posts and pieces with
four protos: the post, the 5-long and 2-long straights and the gate (the gate only to join an existing one, through
0x9F5703). It takes them from the player's civ: `[civ+1E4h]` (Straight2), `[civ+1E8h]`, `[civ+1ECh]` (Straight3, 4, used
by the AI's walls only), `[civ+1F0h]` (Straight5), `[civ+1F4h]` (Gate), `[civ+1F8h]` (Connector), all -1 in the
civ's constructor (0x52A2C3); they come from the stock `civs.xml` tag `<wall type="...">proto</wall>` (the parser at
0x65A354 keeps the names at `[civ+1CCh..1E0h]`). A civ without them gets the names `WallConnector`, `WallStraight5`,
`WallStraight2` and `CWallGate` through BPlayer's proto by name 0x8D1998. So every `wallBuild` proto lays the civ's
stone wall. The layout has three callers: the drag preview 0x6659FC, the click that orders the wall 0x847E0C (which then
sends one build order per post and piece, 0x84786F → 0x82F548, each with its proto) and 0x741299, of another object; the
AI's walls use another builder, 0x9F71A5, with the same civ fields.

**The hooks.** At 0x9F677A (after the civ lookup; EAX = the civ, ESI = the player, EBP = 0) `UhcCustomWallPieces(player,
return address, out[4])` decides: only for the two UI callers (return address `[esp+100h]` = 0x665A01 or 0x847E11) and
a cursor proto with `<WallPiece>` tags (read with `AddProtoTagHandler`). The names are resolved to proto IDs once
(0x8D1998 on the first player that lays such a wall; IDs are the same for every player) and each call takes the
player's copies with 0x45311B. The hook then leaves at the merge 0x9F6815 with the registers and stack slots both stock
branches leave there: EBP the post, EDI and `[esp+44h]` the 5-long piece, `[esp+48h]` the 2-long one, `[esp+4Ch]` and
EAX the gate; otherwise it re-executes `mov edi,eax / cmp edi,ebp / je 9F67D5h` and goes on at 0x9F6780. The placement
test lets a `wallBuild` proto stand on its owner's unit of the same proto only when it is the player's `WallConnector`
(0x508DD4..0x508DED); the second hook, at its first instruction, accepts a custom wall's post too (0x508DF3), so a line
can start on the post of another.

**Why it is safe.** The layout hook keeps EBX, ESI and EBP on the stock path (the C function is stdcall), and the code at
0x9F6780 and 0x9F67D5 sets EAX, ECX and EDX before reading them; the custom path fills exactly what 0x9F6815 and later
read (checked by capstone on both stock branches). The overlap hook clobbers only ECX, which the re-executed `mov`
writes, and EAX/EDX, which the stock path overwrites with its calls before reading. The decision reads the local UI,
so it is not simulation: it only chooses the protos of the build orders the click sends, which every machine receives
as for the stock wall. The AI's walls (0x9F71A5) and the caller 0x741299 keep the civ's pieces.

### directionalAttack

**The launch.** FUN_004995C7 picks the projectile's mode (`[projectile+20h]`: 1 a sure hit, 2 a miss, 3 a ground shot) and
its impact point (`[esp+28h]`) on four paths: the precalculated roll, the `InstantBallistics` branch, the `TargetGround`
store and the skipped block. All four meet at 0x4998A7 (`mov ecx,[esp+10h]` / `mov [esi+14h],ecx`; no branch lands
inside its 7 bytes), and every launch call after it reads the point at `[esp+28h]`. The hook there re-executes the two
instructions and, for an action in the key's table (by the proto ID `[proto+4]` and the action's name index
`[action+4]`, the same in every player's copy) that is not `InstantBallistics`, has a target and a projectile unit
`[projectile+0]`: moves the point along the line from the shooter through it to the landing distance (never short of the
target), sets its height with the terrain query the ground lead uses (the world's `[+88h]` object, vtable slot 18h), and
sets the mode to 3. The projectile then flies there, and its landing applies the attack as a `TargetGround` shot's does
(the applier FUN_0049BE95 with no target: area damage at the point with `DamageArea`, nothing without).

**The flight.** The shot is kept by the projectile unit's ID, with the shooter, its player and proto ID, the action, the
damage multiplier the launch stores at `[projectile+14h]`, and the arguments the applier passes to TakeDamage
(0x49C05A: MuteDamage, the projectile flag bit 14, `[projectile+0C0h]`). After each world update (the shared wrapper of
0x481A57), each shot's projectile unit has moved: the 2D segment from its last position to the new one is tested against
the units the spatial query 0x4A1C55 finds around it. A unit is hit when the point of the segment nearest its centre is
within `DirectionalWidth` of its obstruction (vtable slot B8h), it is alive, not contained, not a projectile, not a Gaia
resource, not the shooter, not hit by this shot before, and the action's `DamageFlags` allow it (the diplomacy filter
0x49AEE0, read from the shooter's player). Hits go in order along the segment, then by ID, each through TakeDamage
0x49B3D9 with the action and the multiplier times `DirectionalDamageFactor`, as the applier's direct hit (p11 = 0 when the
shooter is gone: the army code reads the attacking unit without a null check). Past the landing distance (a bounce) the
line stops at the landing point; when the projectile unit is gone, the rest of the line is flown if it ended within three
steps (or 3 m) of the landing point, and dropped otherwise (it hit a cliff, or the map's edge).

**`<DirectionalFiringRange>`.** The action parser's `MaxRange` handler calls the setter 0x5FA709 at 0x5F8A51
(`thiscall(action, value)`: entry 0 `+8` of the range array `[action+18h]`). The call is redirected: for an action with
the tag, the value read is kept as the landing distance and the setter gets the firing range, so the game targets and
fires at it. A tag that comes after `MaxRange` does the same at once. At the launch the landing is the data's `MaxRange`
plus what the player's copy has gained since (range techs).

**Why it is safe.** The launch hook saves every register around its call and re-executes the two instructions it
replaces; the next one sets the flags before reading them (`test eax,eax` at 0x4998B4). Mode 3 with a target is a stock
state (a `TargetGround` unit attack). The shots are walked in ID order after the world update, with game positions only;
TakeDamage kills through the kill queue, so a hit never removes a unit during the walk (the query's IDs are copied
first, and each unit is looked up again before its hit). A data load and a new game clear the table; a saved game does
not keep the shots in flight, which then land as plain ground shots. Nothing reads the local player or a clock.

### Tech subtypes on the built tags: a value per player's copy

A `Data` subtype's handler gets the player's copy of the proto and the base it was cloned from (`techsubtypes.h`),
while the tag values of `trainBatchSize`, `veterancyBonus`, `sharedBuildLimit` and `dodgeAnyUnit` are maps by proto
ID that every player reads. So each of those keys keeps a second map, by the copy's pointer (as `nextResearchFree`
does), holding what the techs made of the base value through the stock value function 0x7F892A, and its readers
look there first: the kill path has `[attacker+5Ch]`, the dodge test `[unit+5Ch]`, the limit hook `(player, copy)`,
and the batch hook now forwards ECX, the player at 0x9CE645, so `UhcTrainBatchLimit` finds the copy with 0x45311B
(`PlayerProtoEntry`); the queue wrapper takes it from its action manager (`[this+4]` the unit, `[unit+44h]` the
player, 0x9CE63F). A scenario loaded without a data reload reuses copy pointers, so every entry keeps the proto ID
it was made for and is ignored when the copy's ID differs; a data load clears the maps (`OnDatabaseLoad`). The
base of each subtype is the tag's value (or the stock default), so `Absolute` adds to it and `Assign` sets it.

### Civ tags (civtags.*)

A `<civ>` child that civs.xml's parser FUN_0052A590 does not know reaches 0x52BB07, where `civFirstTC` used to read
`<firstTC>` alone. `civtags.cpp` owns that hook now: `AddCivTagHandler(name, handler)` writes it once (checking
`CivTagUnknown` and `CivTagNextNode`) and keeps a table of up to 8 names; the asm proc (`UhcCivTagsHook`, in
`civfirsttc_hooks.asm`) calls `UhcCivTagDispatch(node, civ)`, which compares the element name with each registered one,
case ignored, calls the handler with the civ, its ID and the text, and goes to the next child; an unknown name runs
the stock path. `civFirstTC` registers `firstTC` and `sharedBuildLimit` registers `SettlerProtoName`, in `kFeatures`
order, so whichever comes first installs the hook and the other only adds its name.

### Tech tags

`techtags.cpp` owns the tech parser's loop over the techtree's nodes at 0x61FDB8 (`mov esi,eax / mov ecx,esi / mov
edx,[ecx+18h]`, 7 bytes, re-executed; EAX = the node; continue at 0x61FDBF, `cmp edx,-1`). `OnTechNode(observer)`
calls each observer with every node (dataLint keeps it to name the tech of an effect it reports), and
`AddTechTagHandler(name, handler)` walks the children of each `<Tech>` node (`[node+8]` an array of nodes, `[node+0Ch]`
their count; a child's name `[[child+4]+18h][[child+18h]]`, case ignored) and calls the handler with the `<Tech>`'s
`name` attribute (0x598F37) and the child's text, the BString `[child+14h]`, before the parser reads that tech.
`politicianEnablesTech` registers `PoliticianEnablesTech` and `Icon`.

The parser itself dispatches a tech's children through two tag tables built by FUN_00623702 and ignores a name in
neither, with no message (REA, `docs/engine-symbols.md`): an added tag is read only by its
handler here. Adding the name to the parser's own definition table (its tail 0x62391D, as `prototags` does for protos)
would also accept it inside `<Prereqs>` and `<Effects>` (0x6203A2), which is why the walk is done at the loop instead.

**Why it is safe.** `pushad` / `popad` keep every register around the stdcall dispatch; the flags are written by the
`cmp` that follows. No branch lands in the 7 bytes (they were dataLint's site; capstone scan). Data load only: once per
`<Tech>`, a walk over its 10 to 30 children with a name compare each.

### Tech flags (techflags.*)

The tech parser reads each `<Flag>` through FUN_00620C2F `cdecl(record, name)`, a chain of string compares called once
(0x620C23) that ignores a name it does not know. `techflags.cpp` owns a 5-byte `jmp` over its head (`push esi / mov
esi,[esp+8]`, re-executed before `jmp 0x620C34`): `UhcTechFlagDispatch(record, name)` asks each handler added by
`AddTechFlagHandler`, in `kFeatures` order, and returns for a flag one of them took; any other flag goes on to stock.
The head, not the call, so a DLL that wraps the call still reaches it for the flags it does not know.
`hcTargetTechs` (HCTargetEnemy, HCTargetAll) and `quickArrivalCards` (QuickArrival) use it; whichever applies first
verifies the head and writes the jump. Data load only.

### Card tags (cardtags.*)

The home city loader FUN_0062E6C9 reads each `<card>`'s children in a loop over the card node (EBX, 0x62FD1D: children
`[node+8]`, count `[node+0Ch]`), compares each name with its tags and reads past one it does not know (0x66B720), then
commits the card built on its stack with `call 62FBC7h` at 0x630017 (ECX = the home city's card array `hc+204h`).
`cardtags.cpp` redirects that call to `UhcCardCommitHook`: it calls the append with the same `this` and argument, then
`UhcCardTagsDispatch(node = EBX, array, index = EAX)`, which walks the node's children (a child's name
`[[child+4]+18h][[child+18h]]`, case ignored, its text the BString `[child+14h]`) and calls the handler added for that
name by `AddCardTagHandler` with the home city, the card now in the array, and the text; it returns the index with
`ret 4`, as the append does. The loader overwrites ECX and EDX after the call and does not read EAX again.
`resendableCards` uses it for `<resendeveryage>`. Data load only, once per card.

### trainBatchSize

The routine that queues units in a building reads its limit from one call, 0x8D051B at 0x9CE645: the player's `[+2ACh]`
when set, else the database's `[+178h]`. It then walks the Train actions and fills the last one of that proto up to the
limit (0x9CE6C7..0x9CE6E7). The hook keeps the call and replaces its result for a proto with the tag. The proto ID is the
routine's `[esp+30h]`, the same value it pushes at 0x9CE6DE.

That limit only fills an existing action: a new action takes all that remains, so a Shift+click of 5 stays one action of
5 at any limit. So the four calls of the routine (0x7560B5, 0x7CAF6E, 0x7D797A, 0x9EBF03) go through a wrapper that
asks for more than the tag allows in pieces of that size. Each piece runs the stock routine, which charges it.

New proto tags go through `prototags.*`, shared by the keys that add one. The builder FUN_0051CE1D fills two tables with
0x59B738(name, &handler): the protos' at its object's `+0Ch`, and from 0x51D807 a second one at `+0C2Ch`. So at its tail
ESI is the second: the hook takes the first from EDI. It runs at startup, after `UHCMain`, so the keys only have to
list their tags. A handler gets `(context, node, proto)`, and the node's text is the BString at `+14h`.

The values are kept by proto ID in a map that only the load writes, so a proto's copy for each player reads the same
number and there is nothing to save.

- **Observed in game:** five clicks with 2 logged `queues up to 2 per action (stock 5)` five times and showed a queue
  of 2, 2 and 1.

### pillageGold

TakeDamage FUN_0049B3D9 calls FUN_0049BD52 at 0x49B73C on every hit with an attacking player, whether it kills or not.
`damageOverTime` holds the entry of TakeDamage, and this call needs no second hook there: its frame has it all. `[esp+20h]`
the attacker's player, also in EBX by then, `[esp+28h]` its unit, null when it has died, `[esp+0A8h]` the action, and ESI the
unit hit. The hook replaces the call: it runs the steal with the registers saved, then jumps to the stock function, so
the return address of the original call is the one that function sees.

`[action+4]` is the index of the action's name, the same for a proto action and a tactics action, so `(proto [proto+4],
name)` is the key of the map of `<PillageAmount>`, which the load fills through `AddActionTagHandler`. That index is -1
until `<Name>` is read, so the tag must come after it. A map that only the load writes, with nothing to save. It is
cleared on a new database, since the data is read again when a game loads.

The test order goes from cheap to dear: the map, the is-a test 0x44D7FA with `AbstractCanPillage`, the victim's is-a test
with `Building`, the relation `[player+1D4h+4*id]`, where 2 is enemy, as the filter 0x49AEE0 reads it. The stockpile is read
through 0x44EFFF on `player+230h`, then two calls of the add 0x49A98A, one with `-take` and one with `+take`. The add
applies no multiplier: `[player+37Ch]` belongs to its gather caller. Reading first keeps the victim from going below 0 by
itself, and a victim in debt gives nothing, with `resourceDebt` too.

- **Observed in game:** 66 hits of 5 from 3 Pikemen. Each line's before and after chain exactly, and the two stockpiles
  always add up to the 1000 of the start.
- **Not tested:** shared resources, where the add takes its path 0x67993B: amount / teammates, to each.

### costEscalationTechs

`<CostEscalation>` is stored by the handler 0xA1119D in the proto's `+78h`, default 1 (the proto's cost container is at
`+70h`). The cost getter 0x480B1E (`bool thiscall(player, protoId, cost*, count)`) takes the player's copy, copies the
costs, and compares the field with 1. Equal: the costs are multiplied by `count`. Different (cold part 0x67A1A0): a
query counts that player's units of the proto, and the costs are multiplied by the field `N + count - 1` times, and
not by `count`. That does not undercharge a batch: in game a Shift+click of 5 charged 5 times the unit's price. No Data
subtype reaches the field.

New subtypes go through `techsubtypes.*`, shared by the keys that add one:

- The stock name lookup 0x61FF5D is hash based and its table is sized at startup, so its head is hooked: a name stock does
  not know is looked up in our list and gets an ID from 100h. The rest of setData treats an unknown ID as a plain subtype.
  The hook is on the lookup, not on the call at 0x6206D7, so it still works when another DLL replaces that call. The
  `call` at 0x6206B2 keeps the effect and its node, ESI and EBP, for the lookup. The other caller, 0x621C29, gets stock's answer.
- The two switches, `cmp eax,63h / ja` at 0x8F978D in applyData and `cmp eax,5Eh / ja` at 0x8FB051 in unapplyData, send
  an ID from 100h to the key's handler, then to the exit of the case: 0x8FAE9E and 0x8FC191. Any other ID continues as
  stock.

The handler calls the stock value function 0x7F892A on `+78h`, with the base proto's `+78h`, which gives it every
relativity and the removal. A tech reaches a proto through protoUnitApply 0x7F86C0; the player path 0x8D842B is not
involved, as with Armor.

- A subtype on a Player target (`AddTechPlayerSubtype`, since `shipmentCounts`) goes through that player path: the
  `ja` of its switch at 0x8D843E sends an ID from 100h to the key's handler (see shipmentCounts). A Player subtype on a
  ProtoUnit target, or the reverse, fails as stock fails an unknown subtype.

- **Observed in game:** see the tests in the modding guide. After a load the log shows the effects applied again in
  order, from the data's value.

### randomCost

`<RandomCost resourcetype="Gold" min="80" max="120"/>` makes a proto's price a whole number rolled in the range, one per
purchase. The design goal: what the button shows is what is paid, on every machine and after a load.

**Who reads a cost.** Everything that prices a unit goes through the cost getter 0x480B1E (`bool thiscall(player,
protoId, cost*, count)`, `ret 0Ch`; 35 calls in 26 functions, REA `ev_d783602b…`): the command panel's button
(0x695B33), the unit rollover (0x4C6FB3), the build and afford checks, the AI's cost queries (0x73D085, 0x841548,
0x8479A9, 0x891B80), the repair cost, and the Train enqueue FUN_009EAC35 (`ev_315d0a42…`). The getter fills the result
with 0, takes the player's copy of the proto (0x45311B), copies its cost list `[proto+70h]` with 0x480A73 at
0x480B5B, then applies `<CostEscalation>` or the count. The hook replaces that copy: after the stock copy, each tagged
resource gets the rolled price, and the getter's own escalation and count run on top of it.

**The roll.** Price n = `hash(seed, player, proto ID, n, resource) mod (max - min + 1) + min` (splitmix64 rounds), n
being the player's purchases of that proto that were not refunded. A tech that changed the cost scales it by the
player's copy's cost over the base proto's (0x45316E on the database) for that resource, or adds the difference when the
base cost is 0, and the result is rounded. The seed is the state of the synced random streams 0..2 (`[[0xC66588+4] +
12·s]`, the LCG of 0x407CE7) read at the game's first world update: a read, so the stock draws are unchanged.

**The purchase.** FUN_009EAC35 (`thiscall(action, protoId, count, …)`) has two ways to pay, chosen by the action's flag
14h (0x485D2C): one getter call for `count` units and one payment 0x8D946A (call at 0x9EAF9A, EBP the count), or a loop
that calls the getter and the payment once per unit (0x9EB053). Action flag 15h skips the payment (free units). It then
writes one 14h-byte entry per paid unit and fills its cost record `[entry+8]` by calling the getter again (0x9EB291) and
copying the result; with flag 15h that record is skipped. The two payment calls go to the key: after a successful
payment the player's count moves on by the units paid and each unit's index is noted in a queue; the record call takes
the next noted index of the same player and proto and asks the getter for that index, so each entry holds what it paid.
The world tick clears the queue, so an enqueue that wrote fewer entries than it paid leaves nothing behind.

**Refunds.** The Train action refunds an entry's record through 0x8D7004 (`thiscall(player, cost)`) in three places: the
cancel FUN_009EB363 (0x9EB43E, `ev_192bf1ba…`), the loop of a state change that empties the queue (0x9EB60D), and a
failed spawn (0x9EBA5D). Each refunds the record as stock does, then the player's count goes back by one. So buying
and cancelling gives the same price again; cancelling an older unit while newer ones wait makes the newest price come
again. The spawn path FUN_009EA5F8 refunds `[proto+70h]`, the proto's own cost, when a unit of a list fails to spawn: that
path is not this queue, and a tagged proto there gets its `<Cost>` back.

**Saved games.** The seed and every non-zero count are saved markers (`savedmarkers.h`, stat 68h): word 0 `'RC' << 16 |
kind`, kind 0 the seed (word 2 a fixed tag), kind 1 a count (words 1–3: player, proto ID, count). The world tick writes
them on one living unit, a player's first, when they change or their unit is gone. A new world (a game, a load, a
scenario) reads them in one walk over the units; a world with none takes a new seed at its first update.

**Why it is safe.**
- 0x480B5B: the getter loads ECX and EAX again before using them (0x480B81, 0x67A1A0), and the hook keeps EBX, ESI, EDI
  and EBP; the escalation path reads ESI, set at 0x480B30.
- 0x9EAF9A and 0x9EB053: the stock code tests AL, which the hook returns, and loads EBP and ECX again (0x9EAFA7,
  0x9EB05C); ECX and EDX are not read after.
- 0x9EB291: the getter's own contract (`ret 0Ch`, AL); the copy that follows reads EBP and EDI, which the hook keeps.
- The refunds: AL = 1 as 0x8D7004 returns it; the code after reloads ECX.
- Determinism: the price depends only on the saved seed, the player, the proto and a count that changes only in the
  payment and refund paths of the simulation. The UI's calls of the getter read it and change nothing.
- Performance: one bounds-checked array read by proto ID per getter call; the hash runs only for a tagged proto.

**Pending:** a tagged building is priced by the getter too, but its placement (0x7D6610) does not move the count and its
foundation refund (0x9D321F) asks the getter again: put the tag on trained units.

### bufferedFileReads

**Why it exists.** The game's raw file stream reads with one `ReadFile` per request:
- 0x4683F4 is the read method;
- 0x599121 reads 4 bytes;
- 0x43B8FF reads a 16-byte header as four such reads.

The profile is in [performance.md](performance.md), §9. <!-- private -->

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

**`readahead`** (2026-11-11). One worker thread of the DLL reads the block after the buffer:
- **When.** After the game's thread fills the buffer with a whole block (one real read of the
  buffer's size), it queues the next block's offset. A queued request whose block the game reaches
  first is taken back, and the game's thread reads it as before.
- **Its own handle.** The first request of a file opens a second handle with
  `ReOpenFile(GENERIC_READ, FILE_SHARE_READ | WRITE | DELETE)`. The worker reads with a positioned
  `ReadFile` (an `OVERLAPPED` offset on that synchronous handle), so the game's handle, its file
  pointer and the real-pointer bookkeeping above are never touched. If the second handle cannot be
  opened, that file simply gets no read-ahead.
- **Use.** On a buffer miss, before any real read, the game's thread checks the read-ahead block:
  - if it holds the requested position, the two buffers are swapped and the next block is queued;
  - if the worker is reading exactly that block right now, the game's thread waits for it (the
    log counts these waits and their time);
  - otherwise the block is dropped and the game's thread reads.

  The block is used only for the position it was read at, so the bytes are the file's bytes at
  that offset, as with the plain buffer. A short read (end of file) or an error leaves the block
  unused.
- **Lifetime.** A file's state is reference-counted: the handle table holds one reference, and a
  queued or in-flight block another. Closing the game's handle, a read from another thread or
  `DuplicateHandle` drop the block (an in-flight one is discarded when it lands); the buffers and
  the second handle are freed with the last reference, on whichever thread releases it.
- **Locks.** The worker holds the file's critical section only to take and to publish a block,
  never during its read; the game's thread waits for a block with `SleepConditionVariableCS`
  on that section. The worker never takes the handle-table lock.
- **Log at exit:** blocks asked of the worker, read, used by the game, waited for (and the time),
  the buffer refills still read on the game's thread, and the files with no second handle.

**Checks.**
- `bufferedFileReads verify` reads every buffered request again with a real positioned
  `ReadFile` and compares the bytes. A full late-game session checked 7.5 million reads with no
  mismatch.
- `perfFileLog` counts the game's calls against the ones made to Windows. A session with the
  buffer made 10.2 million `ReadFile` calls by the game and 17,797 to Windows. The worker's reads
  go through its own handle and are not in those counts.
- `bufferedFileReads 64 readahead verify` on the stock game's 25-minute save checked 6.9 million
  buffered reads, 0 mismatches.

### fastVertexFill

**The stock code.** FUN_0040D25B draws the cloth flags (the flags that wave on buildings and ships): `thiscall(flag
manager [0xC67364], byte frontOnly, byte lowDetail)`, `ret 8`, called by the world draw at 0x450684 and by 0x42922A at
0x429429. For each visible flag (`[mgr+68h]`, 34h bytes each) whose grid differs from the one before it, it:
- takes `columns × rows × 2` vertices of 32 bytes (one side only with `frontOnly`) from the renderer's shared dynamic
  vertex buffer, 0x40A6A2(renderer, count, 20h, &first) → 0x40A5B1. That buffer (`[renderer+660h]`: `{buffer, size,
  used, byte}`) is created at 0x5AE7D5 with `CreateVertexBuffer(0x200000, D3DUSAGE_DYNAMIC | D3DUSAGE_WRITEONLY, 0,
  D3DPOOL_DEFAULT)` and locked with `D3DLOCK_NOOVERWRITE | D3DLOCK_NOSYSLOCK` (0x1800), or with `D3DLOCK_DISCARD`
  (0x2800) when the piece does not fit;
- fills it in two loops (0x40D523..0x40D654) from the simulated cloth, `[mgr+3Ch+index*4]`, 32 bytes per vertex with
  `[mgr+14h]` vertices in a row: position (3 floats), normal (3 floats), U, V. Per vertex it writes the front side
  (position and normal copied, U × `[flag+1Ch]`, V × `[flag+20h]` − `[flag+24h]`), and then the back side, half the lock
  further: the same vertex with the normal × −1.0 (`[0xB856B8]`);
- unlocks (0x40D67A) and draws.

The back vertex is built from the front vertex the loop has just written (0x40D5C0..0x40D5FD): three `fld [eax+k]` and
five `mov ecx,[eax+k]`, where EAX points into the lock. A dynamic write-only buffer is write-combined memory: writes
are batched, and a read is not cached. At runtime the lock points into a region with protection `PAGE_READWRITE |
PAGE_WRITECOMBINE` (0x404), and in a late game 99 % of the function's main-thread samples sit on the eight instructions
that follow those reads: 5.5 to 7.8 % of the main thread with a flag in view, against 0.1 % for everything else the
function does.
The measurements are in [performance.md](performance.md), §11, "fastVertexFill". <!-- private -->

**The hook** (`hooks/clothfill_hooks.asm`):

| Site | Stolen | Hook does | Continues at |
|---|---|---|---|
| 0x40D523 | `mov ecx,[esp+18h]` / `mov edx,[esp+4Ch]` (8 B), and the loops after them | `UhcClothFillRecords(front, back, source, pitch, columns, rows, &uv, frontOnly)` | 0x40D655 (`mov ebp,[esp+34h]`, the loops' exit) |
| 0x40D659, `verify` only | `mov ecx,[0C66044h]` (6 B) | `UhcClothFillCompare()`, then the stolen line | 0x40D65F |

`UhcClothFillRecords` writes what the two loops write, in the same row and column order, but takes the back vertex
from the source vertex again. Its float operations are the stock ones, on the x87 stack and in the stock order (`fld
uv[0]` / `fmul source U`; `fld uv[1]` / `fmul source V` / `fsub uv[2]`; `fld normal` / `fmul [0B856B8h]`), so the
rounding is the same whatever the control word is. The U and V results are stored twice from the same register (`fst`,
`fstp`) where stock stores once and copies the dword; the normal is loaded from the source, whose dword stock had
copied to the front vertex unchanged.

**`verify`** leaves the stock loops in place: the hook at 0x40D523 first fills a buffer of the DLL with the same
arguments (`UhcClothFillShadow`, laid out as the lock is, pre-filled with 0xCD and with a guard after it), re-executes
the two stolen lines and jumps to the stock loop at 0x40D52B. Before the Unlock, `UhcClothFillCompare` compares the
lock with that buffer, vertex by vertex, and checks that nothing else in it was written. The first fill also logs
where the lock points (`VirtualQuery`) and the buffer's usage and pool (`GetDesc`).

**Why it is safe.**
- No branch or pointer from outside lands in 0x40D523..0x40D654 (every direct branch of `.text` and every dword of the
  image was checked); 0x40D523 is reached only by falling through the row test `jle 40D659h` at 0x40D51D. 0x40D659 is a
  branch target (of that `jle`), so the `verify` hook starts exactly there.
- At 0x40D655 and after it, EAX, ECX, EDX and EBP are loaded before they are read (0x40D655 EBP, 0x40D659 ECX, 0x40D65F
  EAX, 0x40D682 EDX). EBX must be `[esp+60h]`, which is what it holds at 0x40D523 and what stock reloads at 0x40D617; the
  routine keeps EBX, ESI and EDI. The stack slots the stock loops use as counters and pointers (`[esp+28h]`, `[esp+2Ch]`,
  `[esp+30h]`, `[esp+5Ch]`) are written again at 0x40D68A before anything reads them. The x87 stack is empty at the site
  and after the routine.
- Display only: the routine reads the cloth vertices and writes the locked vertex buffer, nothing else. No clock, no
  random number, no game state; the bytes are the stock ones, so the picture is the same.
- Nothing is kept between calls, so a new game, a loaded game and a device reset need nothing: the routine gets the
  pointer of each lock from the game. Tested with the device created again twice (`res(1920, 1200)` and back) and the
  window minimized and restored.

**Checks.**
- `fastVertexFill verify` compared 76,365 fills (10.5 million vertices) of a 60 s late-game run with the stock loops,
  and 105,340 fills (15.6 million vertices) of a five-player skirmish in a large mod: no mismatch, and no write outside
  the vertices.
- With the key the function leaves the main thread's samples (0.00 % against 5.5 to 7.8 %), and the DLL as a whole
  takes 0.1 % of them.

### fastLastInLine

**The stock code.** Every player has a tech tree (`[world+7Ch]`, one per player slot): one status entry per tech, each
a bitset whose bit numbers are the tech flags (HomeCity 18, ForceLastInLine 22, YPNeverLastInLine 32, …). Bit 16 is not
a flag: it is "last in line", which the command panels read to pick the upgrade of a line they show. FUN_004918A8,
`thiscall(tree, Player*)`, `ret 4`, recomputes it when the tree's byte `+11h` is set. The tech status update 0x491A40
calls it for each live player on every world update (at 0x491A39), and the forced update 0x852850 calls it too. The
byte is set by 0x94AE8C, which tech activation (0x94CF27), "set obtainable" (0x94C33A) and "set unobtainable"
(0x94CDB3) call only for a HomeCity tech: a home city shipment, or a card that becomes available again.

The recompute, in the cold chunk 0x68FB0C..0x68FC51, does for each non-null entry i:
- bit 22 set: set bit 16;
- otherwise scan every other entry j (the template record `[[db+5D9Ch]+0Ch] + 24h·j` when j's entry is null): if j's
  definition has a prerequisite "TechStatus active i" (0x94BC1D: type byte `+5` = 1, status byte `+0Ch` = 2, tech
  `+8`) and the player can obtain j (0x4C5725), clear bit 16 and stop;
- no such j: clear bit 16 when bit 32 is set, set it otherwise.

Then, for the local player (`[game+3C0h]`), it calls slot 1 of the UI object `[game+920h]` with 0. The scan is
entries × (entries + prerequisites) tests. A tree of 2,500 techs takes 15–20 ms; one of 10,500 techs, 340–590 ms,
after every shipment of every player.

**The hook** (`hooks/lastinline_hooks.asm`):

| Site | Stolen | Hook does | Continues at |
|---|---|---|---|
| 0x4918A8, the function's head | `push ecx` / `cmp dword ptr [esp+8],0` / `push ebp` / `mov ebp,ecx` (9 B) | No player or a clean tree: `ret 4`, as stock. Otherwise `UhcLastInLine(tree, player)`; 0 → `ret 4`; 1 → the stolen lines | `ret 4`, or 0x4918B3 (the stock dirty test) |
| 0x68FC1B, `verify` only | `mov eax,[0C66234h]` (5 B) | `UhcLastInLineCompare(tree = EBP)`, then the stolen line | 0x68FC20 |

`UhcLastInLine` builds an index once per data load (and again when the database, the template array or the tech count
changes): for each tech ID t, the techs j whose definition has a "TechStatus active t" prerequisite, from the template
records' definitions (the same definitions every player's entries point to). For entry i it tests only those j, in
ascending order, with the stock 0x94BC1D and 0x4C5725, and writes bit 16 as the stock loop does; it clears `+11h` and
makes the UI call for the local player. A j outside the index fails 0x94BC1D in the stock loop anyway, so the result is
the same with fewer tests: about 10,500 + 5,300 instead of 1.7 × 10⁸, 0.4–1.6 ms. A tree whose count differs from the
template count, or a missing database, goes to the stock code.

**`verify`** computes the bits without writing them, returns 1 so that the stock loop runs, and at its exit compares
bit 16 of every entry with the key's. Each recompute logs the player, the entries, the bits that differ and both times.

**Why it is safe.**
- The two tests and everything they call (0x4804D1, 0x447F3C, 0x4C5DA9, 0x4C5D86, 0x4C5CA1, 0x4C5D2E, 0x4C5AFB,
  0x44D063, 0x8F7816, 0x94DC8C, 0x4C5DBD) write no memory but the stack (a walk of every instruction of each), so testing
  fewer j changes nothing but the time. The bits written are the stock ones, so players may set the key differently.
- The prerequisite lists belong to the definitions, which are read with the data and not changed during a game (no key
  of this DLL adds techs at runtime). A data load clears the index.
- `VerifyAll` checks the whole function, its cold chunk, 0x94BC1D, 0x4C5DBD and the head of 0x4C5725 against the stock
  bytes: beside another DLL that patched any of them, the key logs FAILED and writes nothing.

**Checks.** `fastLastInLine verify`, 0 bits differ in every recompute:
- a 32-minute five-player save of a mod with 10,542 techs (index: 1,371 techs named in a TechStatus active
  prerequisite, 5,325 pairs): 14 recomputes, 147,588 entries; the key 0.42–1.59 ms, the stock loop 335–585 ms;
- a new 1v1 skirmish of the same mod: 7 recomputes, 73,794 entries; the first call, which builds the index, 8 ms;
- the same save with the `dinput8.dll` build beside the mod's own DLL: 6 recomputes, 63,252 entries;
- the stock game's 25-minute save (2,549 techs, 906 pairs): 4 recomputes, 10,196 entries; 0.05–0.37 ms against
  16.4–16.8 ms.

With the key, two interleaved 150 s A/B pairs on the mod's save went from 12 and 15 frames over 50 ms (longest
382 and 384 ms) to 3 and 3 (longest 191 and 243 ms, none of them the recompute).

### menuOptions

`menuOptions <key> …` hands on/off keys to the player, through the options menu's registry (see
[rendererOption](#rendereroption), "The virtual options"). The keys that may be named are a table in `menuoptions.cpp`
(`kMenuSwitches`: the key, its field's `<name>` and whether it is live), today `bufferedFileReads`
(`OptionBufferedReads`), `fastVertexFill` (`OptionFastVertexFill`), `fastLastInLine` (`OptionFastLastInLine`) and the
live `displayedRange` (`OptionDisplayedRange`); another key that changes nothing of the simulation takes one line there.

It runs in `ApplyFeatures` after the cfg is read and before the first key of `kFeatures`, and edits the cfg those keys
then see:
1. each named key gets an option (`AddMenuOption`), with the stored line `<key> on|off`;
2. the value: the player's stored choice; with none stored, the key's own cfg line (present: on, absent: off);
3. a switch that is not live: off with a cfg line, every line of the key is removed, so the key does not apply; on
   without one, an empty line is added, so the key applies with its defaults; otherwise the cfg is left as it is,
   arguments included;
4. a live switch: the key always applies (an empty line is added when there is none), whatever the value.

So a key not named on a `menuOptions` line behaves as before. For the others, a choice is used from the next start,
but for a live one. An unknown name, or the menu sites not being stock, logs `menuOptions: FAILED` and leaves those
keys to the cfg.

**A live switch** (`displayedRange`). Its option is registered with `live` and an `onSet`. The key, when it applies,
calls `FollowMenuSwitch(key, observer, &on)`: true if the menu follows it, with the current choice in `on`, and the
observer kept. On Apply, `UhcMenuOptionSet` stores the choice, logs `it takes effect at once` and calls `onSet`, which
calls the observer on the game's thread. `displayedRange`'s observer only sets a flag: its world tick (every 100 ms of
game time) and the ghost update read it first, and off they take down the models they hung (`g_hung`,
`g_ghost.models`) and hang none; on, the next tick hangs what the selection wants. Its next-tick time is left alone:
0 would read as a new game and forget the hung models without taking them down. The option's entry flags hold 0x40
(below), so a screen that greys rows during a match leaves this one enabled.

A field of `options.xml` whose name is not registered gets -1 from the lookup, as in stock, and the screen
shows it as an empty list or an unticked check box that stores nothing (checked with and without the hooks), so a mod
adds fields only for the keys it names. A field must keep the file's line ends: a DropDown written with LF line ends
into a mod's CRLF `options.xml` was not built at all, with no lookup (seen 2026-11-25; the same field with CRLF showed).

### rendererOption

Two parts: an entry of the options menu that the exe has no room for, and a switch at start that gives the game
another Direct3D 9 implementation (DXVK, Direct3D 9 on Vulkan).

**The options menu (stock).** `data\options.xml` lists groups, sections and fields; each field names an option variable
in `<name>`. The screen (FUN_0078E87D for a section, FUN_0078E67F per field type) works on one settings object,
`[screen+E4h]`, looked up by name ("GameOptions", `[0xC672BC]`) in the settings manager 0xC66688 (0x78EE54). That object
(vtable 0xBA3854, built by FUN_00518E3B) has a fixed list of entries: its type-1 table 0xD91778 has 93 of them, 0x88
bytes each (`u32 id`, 64 wide characters of name, `u32 flags`); `[obj+4]` holds 5 bytes per entry (low nibble the type:
1 float, 2 int, 5 bool, 9 string; then the value), `[obj+8]` the count, `[obj+24h]` the kind (1 for options), `[obj+234h]`
a name → ID map. The profile reads and writes the same entries as `<Setting Name="…">` (FUN_00553044). Per field:
- the DropDown builder FUN_0078D66A resolves `<name>` with 0x932264 (`thiscall(obj, const wchar_t*)`, -1 if not found;
  called only by the four field builders), reads the type with 0x553028 and the value with 0x402E6A (int) or 0x9325C4
  (string), and maps the value to the selected entry (0x78C8BC; only IDs 9, 0Ah and 30h are mapped through lists, any
  other int is the entry's index);
- a CheckBox field (FUN_0078BE95 region, the builder at 0x78BEC5) reads its value with the bool getter 0x402CE9 and
  no type check; Apply (FUN_0078D052) switches on the type from 0x553028: an int goes through 0x518AE0 (a dropdown's
  selection mapped back by 0x78C76A), a bool through 0x518C7C;
- each field builder then asks `[0xC67314]` (vtable `+6Ch`, 0x404E91: `[obj+38h] != 0`); only when that holds, the
  field is enabled if the entry's flags hold 0x40 (the test 0xA41707 with mask 40h), else greyed. `[obj+38h]` was 0
  in a scenario and in a skirmish (read in game, 2026-11-25), so in single player every field is enabled during a
  match. That it is the multiplayer session is an inference;
- on Apply, FUN_0078D052 maps the selection back (0x78C76A) and writes it with 0x518AE0 (int).

Every accessor compares the ID with `[obj+8]` and fails beyond it: 0x553028, 0x402E6A and 0x402CE9 through cold blocks
that only they reach (0x6B794B `xor al,al / ret 4`, 0x6B7676 and 0x6B77B6 `xor al,al / ret 8`), 0x518AE0 and 0x518C7C
through their own failure returns 0x518B26 and 0x518CC2 (`pop edi / xor al,al / pop esi / ret 8`), and the flag test
0xA41707 (`thiscall(obj, id, mask)`) by falling through to `xor al,al / ret 8` at 0xA41710.

**The virtual options (`menuoptions.*`, `hooks/menuoptions_hooks.asm`).** The options menu's registry, shared by
`rendererOption` and [`menuOptions`](#menuoptions): more options, with nothing added to the table, the settings object
or the profile. `AddMenuOption` registers a name (`OptionRenderer`, `OptionBufferedReads`, …) and gives it the ID
0x55480001 + its slot (up to 16, in the order they are added; the IDs live only in memory); the first call verifies the
six sites and writes the four hooks:

| Site | Replaced | Hook does | Continues at |
|---|---|---|---|
| 0x9322A1, the name lookup's not-found return | `pop edi / or eax,-1 / pop esi` (5 B) | `UhcMenuOptionLookup(name, obj)`: a registered name (any case) on an options object (`[obj+24h]` = 1) gives its ID, anything else -1 | 0x9322A6 (`pop ecx / ret 4`) |
| 0x6B794B, the type getter's out-of-range return | `xor al,al / ret 4` | one of the IDs: type 2 (int); any other: as stock (EAX restored first) | its own `ret 4` |
| 0x6B7676, the int getter's out-of-range return | `xor al,al / ret 8` | one of the IDs: writes the option's value to `*out`, returns 1 | its own `ret 8` |
| 0x518B26, the int setter's failure return | `pop edi / xor al,al / pop esi / ret 8` | one of the IDs: `UhcMenuOptionSet(slot, value)` stores the choice, returns 1 | its own `ret 8` |

A second group (2026-11-25), verified and written once by the first `AddMenuOption` too, but on its own: if its sites
are not stock, the log says so and the options stay dropdowns, with no flag 0x40.

| Site | Replaced | Hook does | Continues at |
|---|---|---|---|
| 0x6B77B6, the bool getter's out-of-range return (from 0x402CF2 only) | `xor al,al / ret 8` | one of the IDs: marks the option as read by a CheckBox, writes 0 or 1 to the byte `*out`, returns 1 | its own `ret 8` |
| 0x518CC2, the bool setter's failure return (from 0x518C87 and 0x518CB1 only) | `pop edi / xor al,al / pop esi / ret 8` | one of the IDs: `UhcMenuOptionSet(slot, low byte of the value != 0)`, returns 1 | its own `ret 8` |
| 0xA41710, the flag test's out-of-range return (fall-through of the `jb` at 0xA4170E) | `xor al,al / ret 8` | one of the IDs: `(flags & mask) & F0h != 0`, the flags 40h for a live option and 0 for the others, as an entry of the table would answer | its own `ret 8` |

The type getter hook answers 5 (bool) for an option a CheckBox has read, 2 (int) for the others, so Apply writes each
through the setter its field uses. Every hook tests `ID - 0x55480001 < count` as one unsigned compare, so the game's own
IDs (below 93) never pass, and on the stock path the registers are as the stock code left them. The value is the
dropdown's index, or 0/1 for a check box: for `OptionRenderer`, 0 is the first `<value>` (DirectX 9), 1 the second
(Vulkan). A new value is written at once to `uhc-options.cfg` next to the log, one line per option (`renderer
dx9|vulkan`, `bufferedFileReads on|off`, `displayedRange on|off`, …), to a temporary file moved over the old one,
keeping the other lines. In single player every row of the screen can be changed during a match (the flag test is not
asked, above); where it is asked, a live option answers 0x40, as the game's own rows that may change in a match, and
the others do not, as those that need a restart.

**The switch.** Everything happens in the DLL's start function, before the game's entry point, so before the game calls
`Direct3DCreate9`:
1. the stored choice (or the key's `vulkan` / `dx9` when none is stored yet);
2. if `uhc-vulkan-start.tmp` is still there, the last start with Vulkan presented no frame: the key stores and uses
   DirectX 9;
3. with Vulkan: `DXVK_LOG_PATH` = the folder, unless the player's environment sets it; `LoadLibraryExW(<folder>\d3d9.dll,
   LOAD_WITH_ALTERED_SEARCH_PATH)` by full path, with `SEM_FAILCRITICALERRORS` so a broken file gives an error code
   and no Windows dialog; `GetProcAddress("Direct3DCreate9")`, then the shared IAT slot owner (`d3d9hooks.*`) puts a
   wrapper of it in the import slot 0xB84164. The start marker is written, and an observer of the first `Present`
   deletes it.

DXVK reads `DXVK_CONFIG` when its `Direct3DCreate9` builds its instance (`Config::getUserConfig`, after a `dxvk.conf`,
whose keys it overrides; options split on `;`), and logs `Found config env: …`. So the wrapper sets it just before it
calls DXVK, when every key has applied:
- `fastVertexFill` on (applied, not `verify`): no `DXVK_CONFIG`. The option `d3d9.cachedWriteOnlyBuffers` makes DXVK
  keep a copy of write-only buffers, which only pays off when the game reads them back; with `fastVertexFill` the
  game's one such loop (the cloth flags) no longer reads them;
- `fastVertexFill` off, FAILED or in `verify` mode: `d3d9.cachedWriteOnlyBuffers = True`;
- `conf=` on the key's line overrides both (empty: no options), and a `DXVK_CONFIG` already in the player's environment
  is left alone.

The exe's own d3d9 import, bound at load time, stays loaded and unused.

**The shared Direct3D hooks (`d3d9hooks.*`).** The exe imports one d3d9 function, `Direct3DCreate9`, through 0xB84164
(no delay load). The module checks once that the slot holds what `GetProcAddress` gives for the loaded `d3d9.dll`,
accepts one replacement (`ReplaceDirect3DCreate9`) and then observers (`AddD3D9Observer`): the slot points at a wrapper
that hooks `IDirect3D9::CreateDevice` (vtable 16) of the object it returns, and CreateDevice hooks `Present` (17) and
`Reset` (16) of the device. Each vtable entry is written by this module only, once; observers run in the order they were
added (`rendererOption`, then `perfStats`).

**The safety net.**
- No `d3d9.dll` in the folder, a DLL that does not load, or no `Direct3DCreate9` in it: logged, DirectX 9 for this
  start, the choice kept.
- DXVK's `Direct3DCreate9` returns null (it does when Vulkan cannot start): the wrapper logs it and calls the stock one.
- A start that crashes or hangs before its first frame leaves the marker: the next start uses and stores DirectX 9.
- The slot is not the stock one (another DLL took it): Vulkan is not used, logged.

**Why it is safe.**
- The four sites are reached only from their own functions (every direct branch of `.text` was checked), and the
  game's own IDs (0 to 92, and -1) take the stock instructions in the hooks. No caller can see a difference: the not-found
  path returns the stock -1 for every other name, and the replaced returns give `al` = 0 as stock.
- 0x932264 is called only by the options screen's four field builders, so the extra name exists only there. The
  profile's reader has its own lookup and never sees it.
- What is live: at 0x9322A6 the stock code pops ECX and returns, so the hook may use ECX and EDX; in the accessor
  hooks EAX is the result and ECX / EDX are volatile across a call, as in stock. The x87 stack is not touched.
- Display only: the choice decides which library draws; no game value, clock or random number is read or changed. The
  x87 control word of the main thread stays as with stock Direct3D 9 (see the checks).
- Nothing is kept per game: a new or loaded game, a device reset or a resolution change need nothing.

**Checks.**
- At runtime the options object is the one the code expects: the lookup hook logs `settings 0x…, 93 options` and
  `[obj+24h]` = 1; the four hooks are reached when the Graphics page opens and on OK.
- A profile written after Options → OK with the key is byte for byte the profile written by the same steps without it.
- DXVK's log shows `Found config env: d3d9.cachedWriteOnlyBuffers = True` when the option is passed and no config line
  when `fastVertexFill` is on; the x87 control word after CreateDevice is 0x007F with either renderer.

### xsErrorLog

Both XS reporters, 0x43A3A4 and 0xA5667F, print through a callback at `[log]` that the shipped game leaves empty. A jmp over the
6 bytes of each head hands the stack to C++, which formats with the stock 0x435D99 and writes to the log; the stub replays
`sub esp,804h`. **Why it is safe:** both are cdecl, so EAX, ECX and EDX are free at the head, the formatter is stock, and neither runs
in a clean game.

### dataLint

Reads the exe's own failure exits while the data loads: the `<UnitType>` handler's 0x5FCB61, the proto tag find at 0x5F62A2, the
`<ProtoAction>` look-up at 0x5FA202, and in the effect parse the false setData at 0x6205E9 and the unknown type at 0x65BC56, plus the
shared action tag, ModifyType and Data subtype hooks. The shared `<Tech>` node hook (`OnTechNode`, [tech tags](#tech-tags)) keeps the current `<Tech>` node to name it,
and the summary is written when the call 0x61FE4A returns.

**Why it is safe.** Each hook re-executes what it replaces and only records a name, and all of that code runs while the data loads.

### multipleInstances

**Why it exists.** The game allows one running copy per machine (0x55A185).
[engine-symbols.md](engine-symbols.md) has the details. <!-- private -->
At startup it calls
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

### lanAutoStart

**Why it exists.** A launcher that has already agreed on a host (a lobby, Radmin VPN) starts every
player's game, and each player then clicks Multiplayer, LAN, and Host or types the host's address.
The command line cannot do it: `+name` sets config variables only, and the LAN screen is reached
through the command `doMPSetup(false)` that the menu's XML runs. There is no command for hosting or
joining at all: those are the LAN dialog's buttons.

**What it does.** It writes nothing in the exe. After the first frame it does what the clicks do,
calling the game's own routines, from an `AfterPresent` observer of `d3d9hooks.*`:
1. 3 s after the first frame, with the UI object `[0xC66244]`, its screen manager `[+60h]` and the
   console `[0xC672E4]` present, it runs `doMPSetup(false)` through the console's execute 0x433D0D
   (thiscall, console, command, source). That sets the SkirmHomeCity screen's (ID 36h) next screen
   `[+3Ch]` to 2Eh, MPLoginScreen (site `LanDoMpSetupLan`, 0x6F0C09).
2. 1.5 s later, if `[+3Ch]` is 2Eh, it switches to screen 2Eh (the screen manager's vtable +14h,
   `(id, 0)`). If not, the menu was not ready: it tries again in 2 s without counting an attempt.
3. It waits for MPLanBrowserDialog (`uimplanip.xml`): the screen list holds descriptors (count `[+8]`,
   array `[+4]`, ID `[+0Ch]`, as 0x44BEDD walks it), the screen is the handle `[descriptor+4]`
   resolved by 0x40439A, and must have vtable 0xB95788; the dialog is the gadget `[screen+54h]`
   looked up through 0x40423C and must have vtable 0xB8CE10. It is ready when it is shown (bit 0 of
   `[+0A4h]`, the bit the base activation 0x447BBC tests) and its LAN browser `[+1ACh]` exists. The
   deactivation releases the browser and leaves the pointer, so the pointer alone is not enough.
   15 s without it is an attempt; after 3, it stops.
4. 750 ms later it acts (a joiner 5 s more: the host needs a moment to host). Host: with rules
   asked, the Game Rules dropdown (`MPLanIP-HostXtraRulesDropdown`, gadget `[dlg+190h]`, type 0Dh)
   gets that entry through 0x5C36AE(index, 0), the call its own fill makes for the first entry
   (0x8BA863), read back with 0xAC0D1B; Host reads the rules from that dropdown. The fill always adds
   entries 0..7, so that is the range ([dropdown+19Ch] counts per-entry data, which this list does
   not have). Then 0x8BBD88(dlg, 0), the routine the click switch (0x8BC555) calls for
   the Host button. Join: the Direct IP edit box (gadget `[dlg+17Ch]`, type 23h) gets the address
   through its set-text slot (vtable +80h, the call the activation makes for the game name) with a
   string built by 0x401A12 and freed by 0x4010CA, then 0x8BB710(dlg), the routine of the Join IP
   button (0x8BC569), which reads that box.
5. Joining: every copy is launched at once, so a joiner can press Connect before the host's game
   exists. Join IP stores the browser's answer in `[dlg+1B0h]` (a wait in ms, 15000 for an unknown
   address; 0 when it refuses at once with a message) and the game clock 0x402DFF in `[dlg+1B4h]`;
   the dialog's countdown shows their sum minus the clock. While that wait runs nothing is pressed;
   3 s after it ends, if the dialog is still shown, Connect is pressed again, for up to 3 minutes. A
   0 stops it, since another press would show the message again. A wait that ends unanswered shows
   "No game was found" in the pre-game message dialog, a single gadget whose text each message
   rewrites (0x5183C6), so the messages never stack. Leaving the screen ends it.

It gives up 120 s after the first frame unless it is retrying Connect.

**Beside another DLL** (`dinput8.dll` next to a mod's own `uhc.dll`, measured with a mod's own 2026 DLL):
- That DLL points the Host button's call (0x8BC559, rel32 at 0x8BC55A) at a wrapper of its own. The key
  verifies the bytes around the rel32 (sites `LanBrowserClickHost`, `LanBrowserClickHostNext`) and, when hosting,
  calls whatever that call targets, as the click does; a target that is not executable code of a loaded module is
  refused. The log names the module (`UHC.dll+43180` for that mod).
- It also replaces the dialog's vtable pointer with a table whose every entry forwards through its code, so the
  dialog is recognised by the gadgets its init bound (`[+164h]`, `[+17Ch]` edit boxes, `[+168h]`, `[+190h]`
  dropdowns) when its vtable is not 0xB8CE10.

**The action.** The cfg line alone reads it from the command line, so a mod can ship the line and
the game starts as stock unless a launcher passes `+uhcLanHost` or `uhcLanJoin="<address>"` (the
syntax of the stock `OverrideAddress`), and for the host `uhcLanRules=N` (0..63, checked against the
eight entries).

**Record Game is not part of the key.** The lobby's box is game setting 17h (`GameRecordGame`, the
24th entry of the settings table at 0xD840E4, entries 88h bytes), a host setting sent to every player
(bool set 0xA26341). When the game hosts, 0x704D7E copies it from the last lobby's settings, which
the profile keeps as `gamerecordgame` in its `MultiplayerGameSettings` block; the box is ticked when
that says `true` (seen in game). So a launcher writes that line before the match and the DLL does
nothing. The address may hold letters, digits, `.`, `-` and `:`, at
most 64 characters; anything else is ignored and logged.

**Why it is safe.**
- It writes no byte of the exe: `VerifyAll` checks the 25 `Lan*` sites and the two string routines,
  and every object it touches is checked by its vtable before it is used, so a mod whose UI or exe
  differs gets `FAILED` or a log line, never a call into the wrong code.
- It calls only what the menu's own clicks call, in the order they call it, on the main thread
  (the D3D9 present runs there), so the game sees an ordinary click.
- It does not change the simulation: it acts before any game exists, and a player without the key
  joins the same game through the normal menus.
- It runs once per start; nothing is kept for a saved game or the next game.

### editorSearch

**Why it exists.** The scenario editor's Objects palette, the Allowed list of its Forbidden Units/Techs dialog and its
trigger editor's lists (218 effect types, a unit parameter's 3,634 protos, a tech parameter's 10,542 techs in a big
mod; a campaign scenario's dozens of triggers) list everything, sorted by name, with no way to find an entry but
scrolling.

**The lists** (`docs/engine-symbols.md`, "Scenario editor lists"):
- The Objects palette is the `palette` gadget `EditorProtoPalette` (`uieditorpalettes.xml`; class vtable 0xB92768,
  type mask 18h). The editor gives it the fill callback FUN_007F501E (`[palette+17Ch]`, 0x7F5C51), which adds one
  entry per proto of the current player through `0xAD0056(palette, entry*, categories*)` at 0x7F537D, ESI = the proto.
  The palette's refresh slot (vtable +20h, FUN_00AD01FD, what `refreshonreal` runs) empties the entries (0xAD0189),
  calls the refill slot (+0F0h, which calls `[+17Ch]`), lays its button list out and shows the buttons of the current
  category `[+168h]` through FUN_00ACF80E. The category dropdown only calls FUN_00ACF80E, over the same entries.
- The Forbidden Units/Techs dialog (class vtable 0xB8D690, `uiforbiddenunitstechs.xml`) keeps its Allowed list's
  handle at `[dlg+144h]` and its display mode at `[dlg+160h]` (0 units, 1 techs). FUN_0099912F (units) and FUN_00999493
  (techs), `thiscall(dialog, list)`, empty the list and add each name through the list's `0xAC9228(list, BString*)`
  (0x9991D0, ESI = the proto; 0x999547, ESI = the tech's index); after them the dialog's refresh calls the list's layout
  slot (+100h) and selects the first item (0xAC8A43(0)).
- A `textField` (gadfield.cpp, vtable 0xB91D60, type mask 0Dh) keeps its typed text in an `editBox` it makes for it:
  the handle at `[field+160h]` (0x62BDD5), type mask 23h, the text a BString at `[edit+170h]` (its set-text slot
  0x5C2C20). Typing changes that text and nothing else; no event reaches the dialog.
- The trigger editor's condition/effect panel is filled by FUN_00825757 (thiscall(editor), what its Triggers /
  Conditions / Effects buttons run after setting the mode `[editor+1C0h]`, 0x8264F0; 1 conditions, 2 effects). It
  builds the type names and, in step, each entry's data (the type's index), and sets both on the `Type:` textField
  `[editor+194h]` (0x5BECAA names, 0xAC19D9 data, at 0x8258A0); picking a type uses the entry's data. It then fills
  the list of the trigger's conditions or effects and builds the selected one's parameters. Each parameter is a
  textField (gadtrigparam.cpp, 0x82888A) given its list by 0x5BECAA from an array the trigger system keeps: units
  `[[game+97Ch]+84h]` (0x828A27), unit types `+90h` (0x828A4E), techs `+6Ch` (0x8289D5). A pick gives the parameter
  the entry's text (event 10: 0x829E29, 0x829F2F), not an index.
- The trigger editor's list of triggers, `trEdit-Trigger-list` (`[editor+178h]`, bound at 0x824347), is filled by
  FUN_0082481C (thiscall(editor)): it empties the list, takes the current group (`[sys+0Ch][[sys+18h]]`, sys =
  `[game+97Ch]`), and for each position in the group adds the trigger's name (`[trig+3Ch]`) through `0xAC9228` at
  0x8248C3, then gives the row the add returned the **position as its data** (`0xAC6CC0(list, data, row)`). It then
  selects the row whose data is the group's current position `[group+4]` (0x97B7C4, 0xAC7BB0) and shows that trigger's
  name, priority and Active / Loop / Run Immediately. A click in the list (the list handler FUN_00825933, event 0Fh)
  reads the clicked row's data (0xAC6CFE) and makes that position current (0x97B79B); a row is never read as a
  position (the list is `alphasort` anyway). The group change, Insert, Delete, the panel fill and the editor's
  refresh (0x825CE8) all refill the list through FUN_0082481C (REA, `ev_2242487d…`, `ev_336e9911…`).

**What it does.**
- The three add calls of the palette and the dialog are redirected (`hooks/editorsearch_hooks.asm`). Each asks `UhcEditorPaletteKeep` or
  `UhcEditorForbidKeep` whether the entry matches the current text; a match goes on to the stock add with a `jmp`
  (the return address is the fill's own), anything else returns with the add's own stack cleanup (`ret 8` / `ret 4`).
  The fills free their own strings either way. The palette or dialog that called last is remembered by its handle.
- A Present observer (`d3d9hooks.*`) reads each field once a frame: the remembered owner through 0x40423C (null once
  it is destroyed, since a handle carries a generation), its field by name among the owner's descendants (0x433812,
  once per owner) and the field's text. When the words of the text change and the typing has paused for 250 ms, it
  refills: the palette through its
  refresh slot (checked: vtable 0xB92768 and fill callback 0x7F501E), the dialog through the fill of its display mode
  plus the layout and selection its refresh does.
- The trigger editor: the type list's two sets at 0x8258A0 are replaced (a `jmp` there; `pushad`, a C++ function that
  sets the names and data, filtered together, `popad`, back at 0x8258B8), and the three parameter list sets are
  redirected to a stub that hands 0x5BECAA a filtered copy of the array. A list where nothing matches keeps all its
  entries, since one field serves every list of the panel; a parameter's current value (`[[param+13Ch]+8]`, entry 0,
  as 0x992D36 reads it) stays in its list. A new text runs FUN_00825757 again, which rebuilds the type list and the
  open condition's or effect's parameters through the same hooks.
- The trigger list has its own field, `trEdit-Trigger-search` in `trEditor`. The add at 0x8248C3 is redirected
  (`UhcEditorTriggerAddHook`): `UhcEditorTriggerKeep(editor, group, position, name)` keeps a trigger whose name holds
  every word, and always the group's current trigger (`[group+4]`), so the list keeps showing the one the panels edit.
  A dropped trigger returns row -1, which the data setter 0xAC6CC0 ignores (`test esi,esi / jl`). Since a row carries
  its trigger's position, a shorter list edits the trigger it shows. A new text runs FUN_00825757's own call,
  FUN_0082481C, again, in any mode (the list shows beside all three panels). Its field matches only the list:
  nothing found leaves only the current trigger.
- The match: the text is split on spaces and lowered (`towlower`); every word must appear in the text the list shows,
  or, for a proto, in its internal name (`[proto+10h]`) or its display name (the string ID `[proto+144h]`, read through
  0x58EA52 only when a word is not found otherwise).

**Why it is safe.**
- UI only: the fills run in the editor, the entries are what the stock fill would add minus some, and nothing is
  saved or sent. The DLL's state is four handles and the texts, cleared when the owner's handle goes stale.
- The trigger lists keep the game's own mapping: a type's entry data is filtered with its name, and a parameter's
  value is the text picked, so a value picked from a filtered list is the one the full list gives (saved and loaded
  again: the same). The type list hook keeps every register (`pushad`/`popad`); the continuation 0x8258B8 reads no
  flag, and no branch lands inside the 24 replaced bytes.
- The trigger list keeps the game's mapping too: each row carries its trigger's position as data, a click reads that
  data, and the hook drops an entry before it has a row. After the redirected add the fill reads EDI, EBP, EBX and ESI
  (kept) and the add's EAX (-1 for a dropped trigger); the editor at `[esp+1Ch]` is pinned by the verified head
  `EditorTriggerListFill` (the frame `sub esp,48h` / `mov [esp+4],ecx` and four pushes).
- After each redirected call the fill reads no register the add sets (0x7F5382 reloads ECX; 0x9991D5 and 0x99954C
  free the BString), and the hooks keep ECX for the jump.
- The refills are the game's own: the refresh slot the palette runs when shown, and the fill and layout calls the
  dialog's refresh makes, on the main thread (Present runs there), between frames.
- A layout without a field leaves the list stock (found missing once per owner, logged with `log`). Every address is
  verified (`UiFindChild`, `UiFieldEditBox`, `UiEditBoxText`, the `EditorPalette*`, `EditorForbid*` and `EditorList*`
  sites, `EditorProtoDisplayName`, the `EditorTrigger*` sites and `EditorListSetData`).
- Cost: nothing outside the editor (two null checks a frame); in the editor, two handle lookups and a string compare
  a frame. A refill is the stock fill (see the table).

**Tests** (2026-11-21, a mod's editor, 3,211 palette entries for player 1, 3,634 protos and 10,542 techs in the
dialog; text typed with posted `WM_CHAR`, `testbed.py chars`, erased with posted Backspace, `testbed.py key back`):

| Test | Result |
|---|---|
| Palette, "musk" | pass: 9 shown, 3,202 hidden; the buttons are the 9 |
| Palette, "INF musk" (two words, display-name prefix) | pass: 4 shown |
| Palette, "prowler" (display name only) | pass: 2 shown |
| Palette, text erased | pass: 3,211 shown, the stock list |
| Palette, category Nature with "musk" | pass: Musk Deer and Musk Ox |
| Palette, an entry of a filtered list placed | pass: the unit is on the map |
| Palette, editor left and opened again | pass: empty field, stock list |
| Dialog, units, "musket" | pass: 7 shown |
| Dialog, Add from the filtered list | pass: the unit moves to Forbidden |
| Dialog, Display Techs with the text kept | pass: the matching techs |
| Dialog, text erased | pass: the full list, without the forbidden unit |
| Key on, layouts without the fields | pass: stock lists, `has no textField` logged |
| Key off, layouts with the fields | pass: the fields take text, the lists stay stock |
| Dialog, a filtered tech added, OK, dialog opened again | pass: the tech stays forbidden; the dialog object is kept, so the field still holds the text and the list is filtered |
| Typed letters with posted key presses | pass: they go to the field (doubled with an extra `WM_CHAR`, as a real key makes its own); no editor command ran |
| A word typed at once (`chars musk`) | pass: one refill, after the 250 ms pause |
| Cost of a refill | palette 180–290 ms (the stock refresh: 188–227 ms with an empty text, the stock list), dialog units 10–26 ms, techs 15–146 ms |
| Cost of the per-frame check in the editor | 1.1–2.2 µs a frame (5000 frames with no refill) |
| Triggers, effect, "create" | pass: the Type list keeps 10 of 218 (Unit Create, Unit Create at Location…) |
| Triggers, Unit Create picked from the filtered Type list | pass: its parameters show |
| Triggers, "musket" with Unit Create | pass: no type matches, the Type list stays whole; ProtoName keeps 6 of 3,634 |
| Triggers, Musketeer picked from the filtered ProtoName list | pass: the value is Musketeer |
| Triggers, condition, "tech", then "guard musket" | pass: 3 of 61 condition types; the Tech list keeps 2 of 10,542 (GuardMusketeers, GuardMusketMarauders) |
| Triggers, "create unittype", then "cavalry" | pass: 1 type (Unit Create at Unittype); Target Protounit keeps 25 of 3,884 unit types |
| Triggers, a set value under a text it does not match (Musketeer, "cavalry") | pass: the value stays in the list and in the field (14 of 3,634) |
| Triggers, values picked from filtered lists, scenario saved, editor left, scenario loaded | pass: Unit Create / CavalryArcher and Tech Status Equals / GuardMusketeers |
| Triggers, key on, stock `uitriggereditor.xml` | pass: stock lists, `has no textField trEdit-CondEffPanel-search` logged |
| Triggers, key off, the layout with the field | pass: the field takes text, every list stays full (filmed) |
| Cost of a trigger refill | 0.1–13 ms (the type list and the parameters), 66 ms once with the tech list |
| Trigger list (2026-11-25, a mod's campaign scenario, 27 triggers in Ungrouped), "captain" | pass: 4 shown, 23 hidden; with a current trigger elsewhere, 5 (it stays) |
| Trigger list, "training", the second row (P2_LandTrainingKicker) clicked | pass: its name, 4 Units in Area and 5 Fire Event show, the same as when it is picked from the full list (where row 2 is Captain02) (filmed) |
| Trigger list, Loop ticked on a trigger picked from a filtered list | pass: the full list shows Loop on that trigger and off on its neighbour |
| Trigger list, a filtered trigger, then Effects | pass: its own effects (CaptainReact: Disable Trigger ×2, Move To Point, AI Create Defend Plan, Destroy) |
| Trigger list, Insert and Del with "captain" | pass: the new Trigger_233 shows (current); after Del the next current (Win_02) shows |
| Trigger list, another group with the text kept | pass: the group's matches (none for "captain" in Opening Scene); erased, its 5 triggers |
| Trigger list, the condition/effect field still | pass: "create" keeps 10 of 218 effect types |
| Trigger list, key on, the layout without `trEdit-Trigger-search` | pass: stock list, `the trigger list has no textField trEdit-Trigger-search` logged |
| Trigger list, key off | pass: the field takes text, the list stays full (filmed) |
| Cost of a trigger list refill | 0.1–0.2 ms (27 triggers) |

The palette's refill is slow because the stock refresh is: it rebuilds every entry of the current player, and FUN_00ACF80E
the buttons. That is why a refill waits for a pause in the typing. A/B with `perfprobe.py` (60 s, the editor with the
palette open and the field empty, seven other games running on the machine): 279 fps key off, 181 fps key on, main
thread 29 % against 19 %; the difference follows the other games' load (render time 3.8 against 5.3 ms), not this key,
whose check measured 1–2 µs a frame.

Not tested: a real keyboard (posted messages only), another resolution than 1920 × 1080, IME input.

### editorAutosave

**Why it exists.** The scenario editor has no autosave: a crash loses everything since the last File > Save.

**The save** (`docs/engine-symbols.md`, "Scenario editor save"):
- The console command `saveScenario(name)` (handler 0x7D9798) returns at once unless the editor gate `[game+0B3Ah]` is
  set, then calls the game's vtable +0C0h (the thunk 0x703ED3 to FUN_00834583) with the directory `[0xD6FDB4]`, the
  name and 1, and afterwards puts the name first in the editor's recent scenarios list (FUN_008338F4).
- FUN_00834583 refuses while `[game+0AB0h]` (a save running) is set, shows the "Saving" message, **sets the open
  scenario's name** `[game+958h]` (a BString) to the name it saves under, and `[game+95Ch]` to its flag, copies an
  existing file to `.bak`, and writes the scenario (`.tmp`, then the file). The editor's File > Save writes to
  `[game+958h]` without asking once it is set: after a plain `saveScenario("autosave-1")`, File > Save wrote
  `autosave-1` (seen in game).
- The editor gate is 1 in the editor, 0 in the menu and during a playtest. The undo manager `[game+928h]` keeps the
  undo entries `{[um+0], count [um+4]}` and the redo entries `{[um+0Ch], count [um+10h]}`. No "modified" flag was found.

**What it does.**
- A Present observer (`d3d9hooks.*`, after the Present, on the main thread): while the gate is 0 it does nothing but
  forget the editor. When the gate turns on, the clock starts (GetTickCount64) and it notes the editor's undo state
  (the undo manager, its undo count and last undo entry, its redo count). Each frame it also notes whether
  GetLastInputInfo's time moved while a window of the game had the focus (input to the game, not to another program).
- When the interval is up: if a save is running or a mouse button is held (GetAsyncKeyState), it waits for the next
  frame. If the undo state is unchanged and the game got no input, it skips this round. Otherwise it picks
  the slot (the first `autosave-K.age3Yscn` missing in `Documents\<string 42265>\Scenario\`, else the oldest by its
  write time), copies the open scenario's name and flag, calls the save through the game object's own vtable +0C0h
  (checked to be the stock 0x703ED3) with `autosave-K`, puts the name and the flag back (`BStringSet` 0x40196F with a
  BString made by 0x401A12, then the byte), and deletes `autosave-K.bak`.
- The notice: the editor has no chat (a chat line sent there never showed), so it reuses the editor's message dialog,
  the one the save shows while it writes: the handle `[[game+920h]+12Ch]`, its child `ingame-messagedialog3-prompt`
  given the text through the child's vtable +80h (as 0x83A2B8 does), shown with gadgetReal (0x447F7B) and hidden 2 s
  later with gadgetUnreal (0x448F13, as 0x838CE8 does).
- The save may draw a frame of its own (0x83A2B8 calls the game's vtable +78h after showing "Saving"): the observer
  ignores any Present made during the save.

**Why it is safe.**
- The save is the game's own, called as the console command calls it, between two frames on the main thread, only in
  the editor and never during a save of the game's own (`[game+0AB0h]`), so the file is the one File > Save would write.
- The name and flag are put back with the game's own BString calls; nothing else the save sets is read by the editor
  afterwards. The recent scenarios list is not touched, since the handler's call of 0x8338F4 is skipped.
- Every address is verified: the gate (`EditorGate`), the undo manager and its counts (`EditorUndoManager`,
  `EditorUndoCounts`), the handler's call (`EditorSaveCall`), the vtable slot (`EditorSaveSlot`), the thunk, the head and
  the name write of the save (`EditorSaveThunk`, `EditorSaveHead`, `EditorSaveSetsName`), the directory getter
  (`EditorSaveDir`), the message dialog's hide and its prompt's name (`EditorMessageHide`, `EditorMessagePromptName`),
  the BString calls and the gadget calls (`uigadgets.*`).
- Cost: outside the editor one byte read a frame; in the editor a tick compare a frame. A save pauses the editor for as
  long as the game takes to write the file (see the tests).

**Tests** (2026-11-25, a mod's editor with this DLL, a game copy with its own profile, `editorAutosave 1 keep 3 log`;
the editor opened with `startRandomGame(true)`, units placed from the Objects palette with posted clicks, the game's
memory read with ReadProcessMemory):

| Test | Result |
|---|---|
| A minute after the editor opened, units placed | pass: `autosave-1.age3Yscn` written with a new time, notice shown 2 s, then hidden |
| The open scenario's name `[game+958h]` after the autosave | pass: still `e2-base` (and the flag byte 1) |
| File > Save (`uiSaveScenarioBrowser`) after autosaves | pass: wrote `e2-base.age3Yscn`, not an autosave |
| Before the key, the same with a plain `saveScenario("autosave-1")` | the bug the key avoids: File > Save then wrote `autosave-1` |
| A scenario never saved (empty name), autosaved, then File > Save | pass: the name stays empty, Save opens the Save File dialog with no name |
| Rotation, keep 3, six saves | pass: autosave-1, 2, 3, then 1 and 2 overwritten (the oldest); 3 files, no `.bak` |
| An autosave loaded in the editor (`loadScenario("autosave-2")`), `testbed.py units` | pass: the same 12 units at the same places as when it was saved |
| A round with no placement and no input to the game | pass: `nothing changed since the last autosave; skipped`, no file written |
| Playtest, main menu | the gate is 0 there (seen in memory); the key does nothing |
| Key off, the same steps (filmed) | pass: no notice, no autosave file |
| Bad arguments `editorAutosave 0 keep 99 keep x foo 2.5` | pass: each logged as ignored, applied with 2.5 min and keep 3 |
| Pause of a save (the log's time of the save call) | 186–274 ms for a 180 KB scenario (9 runs); 1,020 ms for an 8-player random map, 2,499 objects, 657 KB |

The recent scenarios list was not checked in game; the code path (0x8338F4) is only in the console handler, which the
key does not call. Not tested: a real keyboard and mouse (posted messages only; the input watch was checked only in
that it skipped a round when there was none), a save that fails (a read-only file, a full disk).

### techGadgets

**Why it exists.** Nothing in the stock interface depends on a tech: a layout can only show what its gadgets always
show. A mod whose fourth resource appears with a late tech (a resource row painted in the panel's background) needs
two versions of a panel and something to switch them.

**What it does.** Each cfg line names a tech and one or two gadgets. In the world update (`worldtick.*`), every 100 ms
of game time and at once in a new world or for another shown player, it reads the tech's state for the player the
interface shows: `[game+3C0h]`, the player `{resource()}` reads, through `0x94AF27` (`bool thiscall([world+7Ch],
player, tech)`); the tech's ID comes from `0x600BE1` on the database `[game+140h]`, again after each data load. The
gadgets are set from Direct3D's Present (`d3d9hooks.*`), every frame, so also while the game is paused: each is found
by name in any panel through `0x433A2C` (`thiscall(manager, int* out, const char* name)`, what the UI commands
`gadgetReal` and `gadgetUnreal` use, `uigadgets.*` `FindAnywhere`), and its handle is kept. A gadget is shown or
hidden (`0x447F7B` / `0x448F13`, `uigadgets.*` `Show`) only when its flags `[gadget+0A4h]` say it is in the other
state (bits 0 and 1 set and bit 7 clear: shown; none of 0, 1, 7: hidden; the tests of the base show 0x447BBC and hide
0x447CEA). Without the Present observer (another DLL took the Direct3D import) the update sets them itself.

**Why it is safe.**
- Interface only: it reads a tech's state and calls the game's own show and hide, as the console's `gadgetReal` does.
  Nothing reaches the simulation.
- A handle carries a generation (`uigadgets.h`), so a rebuilt interface resolves the old handle to no gadget and the
  name is looked up again (at most every 2 s while it is missing, since the lookup walks every panel). A missing
  gadget or tech leaves the layout as it is.
- Before the first tech check of a world (a game starting or a save loading) it writes nothing: the layout's
  defaults show. Its state is not saved; a loaded game reads the tech again.
- The engine's own choice of panel variant (the 12 `SettlerCountDialog-*` panels, chosen by civ type and by the full
  or minimized interface) shows or hides the variant, never its children, so the children keep what the key set; a
  gadget the game showed or hid again would be set back on the next frame (logged with `log`).
- Cost: per frame, two handle lookups and a flag read per gadget; per 100 ms, one tech test per line.

### incomeRates

**Why it exists.** The stock resource panel shows stockpiles only: how fast each resource comes in is not shown
anywhere.
<!-- private:begin -->
DE's resource panel can show it (its option "Resource Gather Per Minute", `OptionResourceGatherRate`; see "What DE
does" below).
<!-- private:end -->

**Where income comes in.** Every change of a player's stockpile through the game goes through one add, `0x49A98A`
(`bool thiscall(player, resource, float amount, bool)`, `ret 0Ch`); with shared resources (`[world+6912h]`) it divides
the amount among the player and its allies (`0x67993B`). Income is told apart by the caller, as `resourceDebt` does:
the global trickle returns to `0x4E0CFE`, unit AutoGather to `0x4C379D`, the gather tick to `0x4ED1F3`. Costs,
tributes, the market, shipments, treasures and triggers come from other callers.

**What it does.**
- A 6-byte `jmp` at the add's head (`push ecx / mov eax,[0C66234h]`, `hooks/incomerates_hooks.asm`) compares the
  return address with the three callers; on a match it calls `UhcIncomeCount` (`pushad` around it) with the player,
  the resource, a positive amount and the caller. Then it runs the two stolen instructions and jumps to `0x49A990`.
- The keys that pay a player from the DLL through the same add (`unitResourceAuras`, `resourceBounty` and
  `killBountyTechs`, `pillageGold`) count their payment with `CountIncome` (`income.h`).
- The amounts go into buckets of one second of game time, per player and resource (16 × 16), filled in the world
  update; the rate is the sum of the last N seconds (default 20) over the time they cover. A new world clears them.
- The data ref `{uhcIncome(<resource>)}` (`datarefs.*`, a string) gives the rate with one decimal, per second (or
  per minute, whole, with `perMinute`). Its argument is read as the stock refs read theirs: the argument BString at
  `[0C6DF7Ch]` holds the whole token, `{uhcincome(food)}`, and the stock helper `0x453F8F` takes the text between the
  first `(` and the next `)`; the name becomes a resource through `0x44709C` (`int thiscall(db, const char*)`). The
  player is the one the interface shows (`[game+3C0h]`); with shared resources `{resource()}` shows the sum of the
  stockpiles of every player the shown one counts as itself or an ally (`0x63C807`, `0x4707EC`), so the rate is that
  sum of rates.

**Why it is safe.**
- It reads the add's arguments and writes only its own buckets; the add runs as before. EAX is free at the head (the
  stolen `mov` writes it); the flags are not read before the next compare.
- Cost: three compares on every add; a counted add is a few float adds. No unit is walked. The ref reads up to 16 ×
  21 floats when a gadget refreshes. Measured in an 8-player game with 7 AIs (`log`): up to 14,200 adds a minute by
  the eighth minute, 0.3 to 0.8 ms a minute inside the count (about 13 µs per second of game time); an A/B of two
  runs each (`perfprobe.py`) showed no difference in frames over 50 ms (8 and 6 on, 7 and 9 off) or update time per
  second (modding guide, "incomeRates").
- The rates are not saved: after a load they build up again over the window.
- Interface only: the numbers never reach the simulation, so players may set it differently.

<!-- private:begin -->
**What DE does** (`AoE3DE_s.exe`, read-only): its interface layout (`UI.bar`, `uimainnew.xaml`) has a collapsed
`<res>_gatherpermin` text "(+999)" beside each amount (food, wood, gold, fame; dance, trade, influence for the other
civs), and the options page the check box `OptionResourceGatherRate`, "Resource Gather Per Minute: additional
information in the resources panel, displaying resources gather per minute". The code that binds those texts is
FUN 0xE473D0 (it finds each by name, `food_gatherpermin` at 0xE474FB); the code that fills them, and so whether it
counts gross or net income and over which window, was not found: a full REA analysis of that exe does not finish
(4 h, 2026-11-05), the byte search found no reference to `kbGetResourceIncome` or to the "1 Minute Income" debug
strings, and about 42 % of its functions are encrypted on disk. So DE's per-minute display is confirmed; how DE
computes it is not.
<!-- private:end -->

### selectFattened

**Why it exists.** The stock interface has buttons that select idle villagers or every unit of a type, but none that
selects the livestock that has stopped fattening: a player looks for it by hand. <!-- private -->WoL request #106.

**How the stock selects many units** (REA, 2026-11-25: `ev_17025585…` 0x79F534, `ev_0a14fa33…` 0x930245,
`ev_3023002d…` 0x9301D3; the UI command handlers by capstone). The UI command `uiFindAllOfType("Type")` (0x7E7AB9,
registered at 0x530D50):
- gets the local selection with `0x4051B6` (`thiscall(game)`: `[[game+91Ch]+4]`, 0 without the world UI) and empties
  it with `0x9301D3(selection, 0)` (it removes the entries from index 0 on, clears their bits in the selection's
  bitset `[sel+10h]`, and sets the "changed" byte `[sel+28h]`);
- walks the local player (`0x407E8A`, the player `[game+3C0h]`) unit list `[player+F8h]` / count `+FCh` (`0x8D1CFB`),
  skipping a unit whose state byte `[unit+88h]` is below 8 (`0x44DE2A`), one its vtable `+0A4h` refuses, and one inside
  another (`[unit+6Ch] >= 0`), then tests the type (`0x44D7FA`);
- adds each with the selection's vtable `+4` and a stack handle `{0B9E444h, 0, unit ID}`. The selection's vtable is
  0xB9F8C4 (read in game), and `+4` is FUN_0079F534: it checks the handle (the unit exists, its ID matches), refuses
  a unit of another player than `[game+3C0h]` once the selection is not empty (except in the mode `[game+0B3Ah]`),
  compares a value of the new unit with the first one's (the selection's vtable `+18h`; read as a selection
  priority, not traced): a smaller one empties the selection first, a larger one is refused but for some same-player
  cases), refuses a unit whose state byte differs from the first one's, adds the
  members of a unit's squad together, and ends in FUN_00930245(handle, 0): nothing past the cap `0x4E0BEE` (the
  getter `selectionLimit` rewrites), nothing already in, then the add and `[sel+28h] = 1`.
`uiLookAtAndSelectUnit` (0x7E5DFD) is the same clear and add for one unit, then a camera move.

**What it does.**
- `uhcSelectFattened()`, a UI syscall (`syscalls.*`, group UI), runs the same calls: the selection, its clear, the
  same per-unit tests, and the add through the selection's vtable `+4` (checked to be 0x79F534 before the call; any
  other and nothing is selected) with the same stack handle. The unit test is a herdable (abstract index 37h,
  `0x44CAC4`) whose inventory `[[unit+0B4h]+94h]` is full by the engine's own test `0x4DC520` (`bool
  thiscall(inventory)`: some resource held at or above its carry capacity `0x494503`, a capacity above 0). That is the
  "full" the gather tick stops a herdable's fattening at (`bl` from 0x49A5E6, herdWalkAwayFix above).
- Over the cap, it sorts the herdables by their distance to the camera's line of sight (`[game+148h]`: position
  `+4`, forward `+10h`, read in game: the line through a unit `uiLookAtUnit` centred) and adds the nearest first, the
  cap's number of them; the add would refuse the rest anyway. With no fattened herdable it changes nothing.
- The count: in the world update (`worldtick.*`), every 100 ms of game time and at once in a new world or for another
  player, the same walk; `{uhcFattened}` (`datarefs.*`, a string) gives the last count. The gadgets of the cfg line
  (default `uhcFattened`) are shown while it is above 0 and hidden at 0 from Direct3D's Present, as techGadgets does
  (`uigadgets.*`: found by name, shown or hidden only when their flags say the other state).
<!-- private:begin -->
- The button that was tested is a top-level gadget at the end of `uimainnew.xml`, at 249 594 270 623 (size1024): right
  of the home city flag (`uimain-homeCityToggle`, 194 605 246 645, in
  `uiminimappanelnew*.xml`, which a mock-up from a scenario with no home city did not show) and above the art of the
  resource panel's 12 variants (from y 625). It is outside the panel's block, so the oil and faith panel packs, which
  replace that block, do not touch it.
<!-- private:end -->

**Why it is safe.**
- Interface only: it calls the stock clear and add on the local selection, as the stock command does from a button
  or a hotkey; no command goes to the network and nothing of the simulation is written. A later order to the
  selection is an ordinary command.
- The add is the game's own, with its checks (owner, cap, duplicates, mixed states), so the key cannot build a
  selection the game itself would refuse.
- Cost: per 100 ms of game time, a walk of the player's units (a lookup, a byte test, a bit test and the full test
  each). Measured over 249 units: 18 to 19 µs per count on average, 257 µs at most: about 0.2 ms per second of game
  time.

### cultureUI

**Why it exists.** The stock game has one in-game interface for every civ, but for the resource panel, which has
three hardcoded looks chosen by the native and Asian civ tests. A mod that wants a look per group of civs, and
another look once a tech is researched, would need a copy of every layout per look.
JTMaston's "Culture UI" request (2026-11-25/26): nine families, a second look from the Great War. <!-- private -->

**What it does.** A data file (`cultureui.xml`) lists styles: a suffix, civ names and optional stages (a tech and
another suffix). At startup the key lists the loose textures under `art\ui\ingame` (subfolders too) and, per style
and stage, pairs each texture `ui\ingame\X` with its variant `X_<suffix>` (a stage falls back to an earlier stage's
variant, then to the style's). Two hooks:
- The head of the in-game interface build FUN_0076166A (`mov eax,[0C672C0h]`, 5 bytes; it runs at each game start and
  each load, with the world and the local player already there): it chooses the style before any gadget of the
  interface exists.
- The head of the texture bind 0x407D27 (`bool thiscall(texMgr, stage, handle)`, 8 bytes), which every textured draw
  calls with the texture's handle (the UI drawable's draw at 0x41E1D8, and the terrain, model and effect draws): when
  a table is active and the game's world is the one it was made for, the handle argument is replaced by
  `table[handle]`. With no table it is one compare; a game that ended (another world, or none) switches the table off
  in the hook itself.

The table maps each texture's handle to its variant's, both from the texture manager's lookup by name 0x58E3EB, which
makes an entry for a new name without reading its file: a variant is read at its first draw. The style is chosen at
the interface build and checked again every 100 ms of game time in the world update (`worldtick.*`): the local
player `[game+3C0h]`, its first civ (`namelists.*`), the stage techs through 0x94AF27 (IDs by name 0x600BE1, again
after each data load), the minimised-interface option 49h (0x402C76 on `[0xC672BC]`, then 0x402CE9) and an observer
rule: a trigger named `StartInsertion` exists (0x90DFB0) and the local player is at or above the first observer, the
slot (3, 5 or 7) where a player's team differs from the previous one (0x88396E), else past the last player.
That is WoL's DLL's rule (0x1005B710, 0x1005BA00; it also counts a state of its own that the key does not see). <!-- private -->
No style for an observer, the normal interface, a civ in no style, or a style with no variant.

**Why a remap at the bind.** The names are fixed when the interface is built and the texture data is kept by name for
the whole launch, so a style per game could rename at the lookup; but the Great War comes during the game. Read with
REA and tried in game (docs/engine-symbols.md, "Culture UI: the style switch during a game"):
- a rename at the lookup during the build misses textures the game sets later by name (the minimap filter button);
- the UI drawable's own setter (vtable 0xB988B0 `+78h`) keeps the layout's texture coordinates, but walking the
  gadgets reaches only `[gadget+58h]` and the button states, not foregrounds or progress bars;
- the texture manager's entry `+1Ch` is an alias the bind follows, but the same index is the memory bookkeeping's;
- the minimised-interface switch 0x760547 rebuilds four panels, not the main layout.

**Why it is safe.**
- Display only: it changes which texture a draw binds, nothing the simulation reads. Players may differ.
- The bind's argument is replaced, never the texture manager: the entries, their memory count and the LRU unload stay
  the game's own. A handle out of the table, or negative, is left alone.
- Cost: one compare per textured draw with no style; with one, a world check and a table load. `perfprobe.py` with a
  style active against the key off, the same skirmish: no change beyond the run-to-run spread (795 / 748 fps; UHC.dll
  0.2 % / 0.1 % of the main thread's samples).

### impactBoneFix

A hit on a unit with a damage template picks one of its impact points (FUN_0049ABA1) and plays the projectile's
impact effect for that point's type through the spawn FUN_0049C1E5. When the chosen entry's `particleSet` names an
`.xml` (stock `cannon.impacteffect`'s `<wood>`: `effects\impacts\cannonball_impact_wood.xml`), the spawn loads that
visual and hangs it on the target's visual as an attachment to the impact point's dummy (FUN_004CA908: dummy type
`[[0D6F678h]]`, 35 in the tested game, and the point's index); a plain particle set is placed at the hit point instead
(FUN_004828E6). Every frame the visual's dummy attachment update (two paths, from `0x4BE1EE` and `0x4BE863`) looks the
dummy up in the current model (FUN_00407402) and reads its frame with FUN_00407272, which copies the rows of Granny's
world pose matrix (`GrannyGetWorldPose4x4`) as they are: position and three axes, scale included. A model whose impact
bones are scaled by 100 gives axes of length 100, and the attached particles are drawn a hundred times too big, over
the whole view. Measured by a hardware breakpoint after the call (`0x4BE89A`): axes (100, 0, 0), (0, 99.995, 1.01),
(0, −1.01, 99.995) on the scaled model, unit axes on a stock House.

The key replaces the two calls of FUN_00407272 (`0x4BE21E` and `0x4BE88D`, 5 B each): the hook makes the call itself
with the arguments the stock code pushed, and when it returned true and the dummy type (EDI on the first path, EBX on
the second) is the impact type, scales the three axes to unit length (left alone within 0.01 of 1); then it continues
at the stock `test al,al / je` (`0x4BE223`, `0x4BE892`). With `all`, every dummy type. EAX, ECX and EDX are kept for the
continuation.

**Why it is safe:** drawing only, after the frame is read; the position is not touched, a bone of length 1 is
unchanged, and the getter's other callers (the damage template's part positions, FUN_0045F0D2) are not hooked.
Evidence: `ev_a040ef98…` (FUN_00407272, FUN_0049C18C), `ev_79c38552…` (FUN_0049C1E5), `ev_6c015823…`
(FUN_004CA908), `ev_0bcda0ab…` (FUN_0049ABA1); traces in `rea/evidence/age3y-b1a1dab7/impact49-50.json`'s folder.

### customImpactTypes

The impact types are 15 `wchar[32]` names at `0xBA4D70` (Wood … Metal); FUN_0059F436 compares a name with each
(FUN_00443C10, not case-sensitive) and returns its index or −1. Its four callers: the damage template parser
(FUN_004F04FE, `impacttype`), a proto's `<ImpactType>` (FUN_005F7F7C, `[proto+1B8h]`), the terrain types'
`ImpactType` (FUN_0051E1DF) and the `.impacteffect` loader FUN_005FEABF (each element's name). An impact effect object
holds one entry list per type at `[effect + 4 + type × 12]` (pointer, count, capacity; 15 of them, FUN_005FE8CD turns the
entries' weights `[+20h]` into running sums), and the spawn FUN_0049C1E5 and the pick FUN_0049C18C refuse a type
above 14.

- **Names** (`0x59F464`, 7 B): the not-found end of FUN_0059F436 asks the DLL, which compares the name with the cfg's
  names the same way and returns 15 + its index, then does the stock `pop edi / pop esi / pop ebx / ret`.
- **Entries** (`0x5FEC74`, 21 B): for a stock type the hook runs the stock add (FUN_00401F74 on the type's list); for a
  custom one it adds the entry, with the same function, to a list the DLL keeps for that effect object. The first
  custom entry of a read starts the effect's lists empty, so an effect read again does not keep old entries.
- **Weights** (`0x5FEC99`, 7 B; `0x5FEBE1` jumps there when the file has no element): after the stock FUN_005FE8CD,
  the DLL makes the same running sums in its lists.
- **Spawn** (`0x49D86E`, the projectile hit, and `0x4CB30D`, the terrain impact; 5 B each): for a type of 15 or more,
  the DLL puts that type's list in the effect's slot 14 (Metal), calls FUN_0049C1E5 with type 14 and the other seven
  arguments as pushed, puts slot 14 back, and drops the eight arguments as the callee would. The stock code then picks
  the entry (FUN_0049C18C), plays its particle set, sound sets and fire, and keeps the effect's own rate limit
  (`[effect+C8h..]`). A type with no entry returns −1 as in stock.

**Why it is safe:** drawing and sound only. The lists are built at data load (an `std::map` keyed by the effect
object), and the spawn looks one up per impact. Slot 14 is lent only for the length of one synchronous call. After the
spawn, the caller reads the chosen entry again by type (`0x49D884`, `cmp eax,0Fh`) for the `ExitBuilding` values; for a
custom type that read gives nothing, so no units are thrown out, as for a type with no entry. Evidence:
`ev_89da6b7d…` (FUN_004F04FE, FUN_0059F436), `ev_7d29d565…` (FUN_005FE922, FUN_005FEABF), `ev_107075e1…`
(FUN_005FE875, FUN_005FE8CD), `ev_a040ef98…` (FUN_0049C18C, FUN_00401F74, FUN_0051E1DF), `ev_79c38552…` (FUN_0049C1E5).

### The progress pie (`progresspie.*`) and progressPieDemo

A shared piece, not a key: a key that has a timed process on a unit (a growth step, a conversion) shows how far it
has gone as the overlay a train button shows while its unit trains, drawn over the unit's portrait in the selection
panel, in the minimized interface and the normal one. The dev key `progressPieDemo` is its test bed.

**The engine's pie** (REA `ev_18d1be98…` FUN_00629A7A, `ev_0ba07671…` 0xAB6C63, `ev_0ef63318…` 0x4C51FA,
`ev_b5dcc5c5…` 0xAB5C34, `ev_bdb706ee…` 0xAB5BAA, `ev_6cb3ea96…` FUN_0070ADE9; capstone for the callers):
- Every gadget can hold one: the base layout parser FUN_00629A7A reads a `<pieChartFilling color="R G B A"
  rotation="cw|ccw" fill="true|false" texture="...">` child into a 20h-byte record at `[gadget+130h]`: the fraction
  `+0`, the colour `+4` (ARGB, packed by 0x404DF6), the texture `+8` (-1: none), `+0Ch` 1.0, the rotation `+1Ch`
  (1 = cw), the fill flag `+1Dh`, on `+1Eh`; and a material `[gadget+12Ch]` (`defaultcolored_alphablend`, diffuse =
  the texture). The layouts tested put one on each command panel button and on the training panel's buttons.
- Every gadget vtable has the same fill at +6Ch, 0xAB6C63 (`thiscall(gadget, float)`, `ret 4`): with no record it
  makes one (colour 88FFFFFFh, no texture, cw, fill false, on), then stores the fraction clamped to [0, 1].
  0x4C51FA (`thiscall(gadget, bool)`, `ret 4`) turns the record on or off (`+1Eh`). 0xAB5C34
  (`thiscall(gadget, r, g, b, a)` floats, `ret 10h`) sets the colour. 0xAB5BAA (`thiscall`, plain `ret`) makes the
  material when there is none and gives it the record's texture.
- The command panel fills its train buttons every refresh: `+6Ch(progress)`, `0x4C51FA(1)`, then the colour
  `0xAB5C34(0, 0, 1, 0.5)`, blue at half alpha (0x69D9BC); other buttons of that panel use green (0x69D99F),
  magenta (0x69C383), yellow (0x69C572) or blue (0x69C92B) the same way. The unit stack buttons (FUN_009B85C7) call
  0xAB5BAA first when the button has no material, since their layout has no `<pieChartFilling>`. The special
  powers panel (FUN_0070ADE9) adds a mask texture, `ui\core_ui\default_piechart_mask`, for its round buttons.
- Seen in game (the train button of a Town Center's queue): the covered part is the part not done; the uncovered
  wedge starts at 12 o'clock and grows clockwise. The pie covers the whole square of the gadget (no texture, no mask).

**The module** adds no hook and no gadget. `AddProgressPieSource` verifies the four functions above, the portrait's
bind (0x9BAE5E: `unitselectionpanel-unitPortrait` → `[panel+2E4h]`, the same field in both layouts) and the gadget
lookup, then adds an observer to the shared panel tail (`AddUnitPanelTail`, 0x4C8281), which both interfaces reach. On
each refresh the observer takes the portrait gadget from its handle; with one unit selected (the group's count
`[+14h]` = 1) it asks the sources in the order added; the first that answers sets the pie as the command panel does
(fill through the gadget's own slot +6Ch, which must be 0xAB6C63, else nothing is drawn and the log says so once;
the material through 0xAB5BAA if missing; the colour through 0xAB5C34 when it changed; on through 0x4C51FA). When no
source answers, or for a group, an on pie is turned off. `ShowGadgetPie` / `HideGadgetPie` do the same on any gadget
handle, for a key that wants the pie elsewhere.

**Why it is safe:** display only, on the main thread, from the panel fill. The record is the engine's own, made by the
engine's function, and freed with the gadget as every button's is; nothing is written to the portrait but its record
and material. The portrait has no `<pieChartFilling>` in the layouts tested and no stock code fills it, so no stock pie is
overwritten. A stale handle gives no gadget (the lookup checks its generation).

**progressPieDemo** `[seconds] [RRGGBBAA]` (dev key, not in `uhc.cfg`): a source that answers for every unit with
the game time `[world+108h]` modulo the period (default 10 s, 1 to 600), in the train button's blue or the colour
given. Bad values are logged and the key is not applied.

**Tested** (2026-11-26, a modded copy, scenario, a Musketeer and a Town Center; `progressPieDemo 8`):
(The WoL copy `C:\AoE3-UHC-WoLReal3`, Ethiopians.) <!-- private -->
- minimized interface: the pie over the Musketeer's and the Town Center's portrait, filling clockwise from 12 o'clock
  as the Town Center's queue button does next to it (the same colour and direction);
- normal interface: the same over the big portrait; three villagers selected: no pie;
- the key absent (control): the stock portrait;
- the panel refreshes it with the frame: 16 changes in 40 frames of a 10 fps capture of a background copy.

**Performance**, `perfprobe.py` 60 s each, the Musketeer selected, minimized interface, other agents' games running:

| Run | fps | main thread CPU | frames over 50 ms |
|---|---|---|---|
| key absent | 714 (median 721) | 83.8 % | 0 |
| `progressPieDemo 8` | 662 (median 689) | 79.7 % | 0 |

The render time per frame went from 1.2 to 1.4 ms with the pie on (one more alpha-blended pie, the cost of a train
button's); the main thread and the frames over 50 ms did not rise.
Films: [with the pie](media/progressPie-wol.gif), [control, key absent](media/progressPie-wol-control.gif). <!-- private -->

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
  `noTrainNearEnemyTC` measures with the placement rule's own distance call and spatial query;
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
- **Outside the simulation** (`bufferedFileReads`, `fastVertexFill`, `rendererOption`): change only how data reaches
  the game or the video card, or which library draws, never what the game computes.
- **The same result, fewer steps** (`fastLastInLine`): computes the bits the stock loop writes, with the stock tests,
  skipping only tests that cannot pass; the tests write nothing. `verify` compares every bit with the stock loop.
- **Interface only** (`abilitySlots`, `wonderPanelSkipAuras`, `customHotkeyContexts`,
  `overhealHitpointBars`, `showGatherRate`, `nativePreview`, `displayedRange`): change only what the local player sees or which keys
  work; every button or key sends the same command as stock. `showGatherRate`'s record hook runs in
  the gather code on every machine, but only copies values into the DLL's own memory.
- **Logs never feed back:** every `log` option only writes `UHC.log`; its dedupe tables decide
  whether to write a line, never what the game does.

None of this has been tested over a real network yet.

<!-- private:begin -->
## 6. Differences from the original DLL

The upstream features implemented here follow the same idea and sites, with these defects
fixed:
- **noAILimit:** two uninitialized locals.
- **basePop/extraPop:** the missed negative-extra path.
- **removeFameRestriction:** the wrong owner on the second politician screen.
- **customRevolutionBanners:** an unbounded banner path.
- **Hooks:** they no longer depend on the instruction relocator.

The full list of upstream defects, including those in features not implemented yet, is in
[uhc-address-map.md](uhc-address-map.md).
<!-- private:end -->
