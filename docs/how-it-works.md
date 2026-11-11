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
   exe's folder the working directory (`UseExeFolderAsWorkingDirectory` in `src/dllmain.cpp`).
   The original DLL does the same. <!-- private -->
   A mod then starts the same way from a double-click, a shortcut or a launcher, and `ignoreRegistryPath`
   reads the mod folder.
5. **Configuration.** The loader patch stores the config path at `0xC65083` (at most 20 wide
   characters, default `Startup\uhc.cfg`). The DLL resolves it against the exe's folder and
   parses it (`src/config.cpp`). The parser accepts both `key value …` and the older
   `key=value` syntax with `//` comments.
   That older syntax is the original DLL's, which its patcher writes. <!-- private -->
   The DLL then runs every feature in the order of `kFeatures` in `src/features.h`. Each returns
   *not configured*, *applied* or *failed*.

### Beside another DLL

The same sources also build `dinput8.dll` (`src/engineext.cpp`), for a game whose loader runs another `UHC.dll` that must stay
as it is. The exe imports `DINPUT8.dll` and Windows looks next to the exe first, so it loads with no change to any file.
Its six exports go on to the system's DLL by full path, resolved on the first call, so nothing is loaded under the loader lock.

`DllMain` checks the exe and only moves the last `jmp` of the boot stub, at 0xB836EC. So the order is: the stub runs the other
DLL's `UHCMain`, the `jmp` goes to `EngineExtMain`, which loads `engine-ext\engine-ext.cfg` and applies the keys through the same
feature loop as `UHC.dll`, and then to the game's entry point. All its files are in `engine-ext\`.

Coming second is what keeps the two apart: `VerifyAll` sees the other DLL's patches, so a key that needs one of those sites
logs `FAILED` and writes nothing.

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
  function in `kFeatures` order: the world update (`worldtick.cpp`, `AddWorldTick`), the unknown
  tags of an action (`actiontags.cpp`, `AddActionTagHandler`, at 0x5FA11E) and every unit's death
  (`deathobservers.cpp`, `AddDeathObserver`, the drain's call 0x493D8F; `detonationDeath`, `annexFacing`), with a
  second list for the trigger `Destroy` (`AddDestroyObserver`, its call 0x9828E7 of the unit removal; `annexFacing`).
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

Normal techs reach `applyData` through `playerApply` → `0x8D842B`, without the effect pointer, so
the type travels in a global that the wrappers set and restore (effects apply on one thread).

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
know. The key hooks the head of that reader, not its call, so it still works when another DLL wraps the call, and keeps the
tech's definition, the routines' `this`, in a set. The set is only written during the load, so the game's lookups are lock-free.

The enemies come from 0x484D2D, the check the placement rules use, over the players of the world without Gaia.

- **Observed in game:** see the tests in the modding guide. After a load the log shows one `load` line per tech.

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

### displayedRange

The ring is a model of the table the tactics parser fills: 0x58F68F gives the ID of `effects\uhc_rings\range_<N>.xml`, as
0x5FC91C does for `<ModelAttachment>`, and 0x58E506 the ID of the bone `bonethatdoesntexist`, as 0x5FC8EE does, which puts
it at the unit's feet. A world tick, four times a second of game time, compares the selection of 0x453B28 with the units
that hold a ring, and hangs or removes it through the functions of the stock aura update.

**Why it is safe.** Nothing here reaches the simulation: the selection is local and is only read, and a model is a visual
of the unit. The tick walks the selection and its own map, never the world's units.

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
- `0x462317`: every button of a preview is disabled and its two command strings are emptied.

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
when it is gone. Gaia and the attacker's own units do not count.

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
- *The hooks* (`hooks/overheal_hooks.asm`, only with `segment`):

  | Site | Stolen | Hook does | Continues at |
  |---|---|---|---|
  | 0x45FB6C | `jmp 4516B3h` (5 B; ESI = unit) | unless under construction (`[esp+15h]`): reference, then `UhcOverhealQueueSegment(unit, pos, reference)` | 0x4516B3 |
  | 0x45C4B9 | `mov ebx,[ebp+8D4h]` (6 B; EBP = world) | `UhcOverhealSegmentFit(world)`, then the stolen load | 0x45C4BF |
  | 0x45CB72 | `add eax,1 / add ecx,1Ch` (6 B; ECX = the record's offset, EDI = its sixth vertex, ESI = camera) | for a segment record, `UhcOverhealSegmentVertices` | 0x45CB78 |
  | 0x4D7651, 0x69A9C0 | `push` of `%d/%d` / `%d/%d (%d+%d)` (5 B; `[esp]` = HP, `[esp+4]` = 100 %) | pushes the coloured copy when HP > 100 % | 0x4D7656, 0x69A9C5 |

  `UhcOverhealQueueSegment` queues a second record when HP > reference (for an unmarked unit the
  reference is the stock max, so never): same position, scale 1.0, fill = min((HP − reference) /
  reference, 1), player 804F5648h (no player has it; negative, so the renderer colours it white)
  and byte FFh. The vertex hook, for that player ID only, moves the left vertices right by
  scale × (1 − fill) × B, gives all six u = 1.0 (left) / 0.5 (right), the fill part of the texture,
  and the segment colour; every other record keeps the stock vertices. `UhcOverhealSegmentFit`
  removes the segment records before the lock when count × 216 bytes would not fit in the buffer,
  so the segments never cost a stock bar. The coloured formats are the stock ones wrapped in the
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
  Then the stolen free, → 0x4C83E8. The minimized UI (`optionminimizedui`, profile option 49h, read through
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
- *The hook* at 0x4D76DB (9 B): the two stolen moves, then `UhcOverhealStatRow(panel =
  [esp+50h], unit = [esp+38h], row = EDI)`; for a marked unit it writes the row with the same calls
  (label `Overheal`, the cfg text, or a string table entry through 0x58EA52; value
  `overheal/capacity`, coloured with `segment` while above 0) and returns true, and the hook adds
  1 to EDI and `[esp+2Ch]`, so the Group Health row and the rows after it move down. → 0x4D76E4
  (EAX, ECX, EDX and the flags are written there before they are read).
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
| 0x9E0BBB | `call 480408h` (ECX = EDI = target, healer `[esi+10h]`) | for a marked target and a healer of no source type: the reference; else the stock max | 0x9E0BC0 |
| 0x9E0CE9 | `call 4823A3h` (the tick's heal) | `g_uhcOverhealAllow` = healer is a source, the stolen call, then 0 | 0x9E0CEE |
| 0x9CD984 | `call 45F295h` (ECX = ESI = candidate, healer `[ebp+4]`) | for a marked candidate and a normal healer: HP / reference (1.0 at the reference: no candidate); else the stock ratio | 0x9CD989 |

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
height. Observed with a trace: a Hussar's idle file has the tag at 4.07..4.15 (model y), its gallop has none (2000 of
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

The hook replaces the getter's first three instructions. Without the flag it re-executes them and goes on at
0x49EBEA. With it, it calls the getter's body, so that the body's `ret 4` comes back to the hook, and multiplies
ST0 by the factor, with the attack code's rule.

**Why it is safe.** The hook sits at a function entry, so EAX, ECX and EDX are free. No branch lands in the six
bytes. Every caller gets the same rate: the update 0x48D16E, both panels (0x6992BD, 0x69B005), and the two that
look for a resource with a rate (0x69D232, 0x9CFE1E). The factor comes from simulation state only.

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
`UhcContainedRofScale(unitAction, rof)` and re-executes what follows:

| Site | Bytes | What it is | Unit action in |
|---|---|---|---|
| 0x4A1189 | `mov ebx,[eax+34h] / mov eax,[esi+6Ch]` | an attack begins: the animation's rate `[unit+0B0h]` | ESI |
| 0x48F8B5 | `mov eax,[eax+34h] / cmp eax,ebx` | after a shot, melee or ranged: the wait | EBP |
| 0x48A821, 0x48A99A | `mov edi,[edi+34h] / test edi,edi` | the update, after an attack that did not fire | ESI |
| 0x48EA0C | `mov esi,[esi+34h] / test esi,esi` | the attack step, the same case | EBP |

`UhcContainedRofScale` finds the table entry of `{[[unit+5Ch]+4], [[ua+4]+4]}`, the proto ID and action name index that
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
- With no action carrying the attribute, `g_uhcContainedRofCount` is 0 and the hooks skip the call: a compare and a branch
  per attack.
- Deterministic: the count, the cap and the ROF are simulation state, the table is keyed by IDs, the division is the same
  code on every machine, and the log never feeds back.
- Not covered: the panel's ROF text and the AI's own damage estimate read the data's ROF.

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

The rings of `tools/make_rings.py` need no code. A ring's `.xml` hangs one flat particle, chosen by `<logic type="UnitType">`:
`appearancetype` 2 lies on the ground, 0 faces the camera, and `materialtype` 0 with `material` 0 honours the texture's alpha;
`scale` is half the width of the square in metres. The particle lives 2 s, `emissionrate` 100 with `maxparticles` 1 replaces it
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
`[world+0Ch]` runs on a new world or a jump of the clock, which finds the ranks of a loaded game. The mark hangs on the bone
`HITPOINTBAR`, as a sprite that faces the camera, 1.15 m over the aura icons' height (`tools/make_rings.py`, `RANK_LIFT`): the HP
bar scales with the camera like the world, so the gap stays at every zoom. Ranks 4 and 5 add stars over rank 3's chevrons: their
sprite is larger around the same centre, with the glyph scaled down by as much, so the chevrons land where rank 3's do. **Why it is safe:** a model is a
visual of the unit, so nothing reaches the simulation, and no tick walks the whole world.

### auraStacking

The aura update FUN_009D033E sends each unit it does not hold through the filter 0x9D0238, at one call, 0x9D0633, which the key wraps.
A modifier does not say which aura made it, so right after the apply, at 0x9D0675, the key writes the aura's mark in `[modifier+84h]`,
a field stock saves and loads and does not read. `<NoStack>` refuses a target that holds that mark. A refused target stays out of the
action's list, so every update of every carrier asks again, and a dead carrier's modifier goes with it. `unitResourceAuras` makes no
modifier: its take asks `AuraClaim`.

**Why it is safe.** The mark lives in game state, so every machine and a saved game see the same thing, and the filter runs only for
targets the action does not hold yet.

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
the placement at 0x96E531 with the visual's position `+4`, forward `+10h` and right `+28h`. The hook at 0x96E4E7 (`mov
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

### nextResearchFree

A research is paid when its action starts: 0x8D946A at 0x9E67E1 (the Research action, EBP) and at 0x9D54CF (CommandResearch,
ESI). Each action then copies the cost for a cancel's refund (0x480A73 at 0x9E68A0, to `+74h`, and at 0x9D5548, to `+7Ch`).

The effect is a subtype through `AddTechSubtype`, which adds its amount to a count kept by the player's copy of the proto.
Both payment calls go to a helper that reads the proto from the action's unit (`[[action+10h]+5Ch]`). With a count above 0 it
takes one, returns true and leaves a mark, and the wrapper of the copy that follows empties the action's cost with
0x4E2617, so a cancel refunds nothing. The count is forgotten when a database loads (`OnDatabaseLoad`), because a new game
can reuse the address of a proto. It is not saved, and a load applies the effects again.

- **Observed in game:** see the tests in the modding guide.

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

### cantBeSlowed

0x4DD1DE, the `TargetSpeedBoost` path, tests that the target can move, and 0x4DD201 pushes the arguments of the
modifier's creator 0x4DD22D. The hook replaces the first three pushes, and leaves through 0x48FA49, the path's exit, for a
marked target or a marked attacker. The poison of `damageOverTime` calls the creator itself, so it asks the same two
functions, with the unit whose hit attached the poison as the attacker (none once it is gone). The site is in the
ranges `damageOverTime` and `snareOnlyHitUnit` verify, so this key comes after them in `kFeatures`.

**The attacker at 0x4DD201.** FUN_0048FA07 (`thiscall(unitAction, target)`) has one caller, 0x48F9F5 in FUN_004B7766,
which keeps the attacker's unit action in EBP for its whole body (`[ebp+10h]` is used as `this` with no null test at
0x48F0EF and 0x48EAE1, so it is the attacking unit; `[ebp+4]` its tactics action). FUN_0048FA07 and its cold chunk
0x4DD1DE..0x4DD228 write ESI, EAX, ECX and EDX but never EBP, so at 0x4DD201 `[ebp+10h]` is still the attacker. The
hook reads it after the target test, and a null there (never seen; a guard only) means no CannotSnare test. Observed
in the listings (REA `ev_683538e5…`, `ev_dfeff76d…`, `ev_71e9bf8d…`, 2026-11-05).

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

- **Observed in game:** see the tests in the modding guide. After a load the log shows the effects applied again in
  order, from the data's value.

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

**Checks.**
- `bufferedFileReads verify` reads every buffered request again with a real positioned
  `ReadFile` and compares the bytes. A full late-game session checked 7.5 million reads with no
  mismatch.
- `perfFileLog` counts the game's calls against the ones made to Windows. A session with the
  buffer made 10.2 million `ReadFile` calls by the game and 17,797 to Windows.

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
- in a running game the field is enabled only if the entry's flags hold 0x40 (0xA41707);
- on Apply, FUN_0078D052 maps the selection back (0x78C76A) and writes it with 0x518AE0 (int).

Every accessor compares the ID with `[obj+8]` and fails beyond it: 0x553028 and 0x402E6A through cold blocks that only
they reach (0x6B794B `xor al,al / ret 4`, 0x6B7676 `xor al,al / ret 8`), 0x518AE0 through its own failure return
0x518B26.

**The virtual option (`hooks/rendereroption_hooks.asm`).** One more option, `OptionRenderer`, with nothing added to the
table, the settings object or the profile:

| Site | Replaced | Hook does | Continues at |
|---|---|---|---|
| 0x9322A1, the name lookup's not-found return | `pop edi / or eax,-1 / pop esi` (5 B) | `UhcRendererOptionLookup(name, obj)`: `OptionRenderer` (any case) on an options object (`[obj+24h]` = 1) gives the ID 0x55480001, anything else -1 | 0x9322A6 (`pop ecx / ret 4`) |
| 0x6B794B, the type getter's out-of-range return | `xor al,al / ret 4` | that ID: type 2 (int); any other: as stock | its own `ret 4` |
| 0x6B7676, the int getter's out-of-range return | `xor al,al / ret 8` | that ID: writes the stored choice to `*out`, returns 1 | its own `ret 8` |
| 0x518B26, the int setter's failure return | `pop edi / xor al,al / pop esi / ret 8` | that ID: `UhcRendererOptionSet(value)` stores the choice, returns 1 | its own `ret 8` |

The value is the dropdown's index: 0 is the first `<value>` (DirectX 9), 1 the second (Vulkan). A new value is written
at once to `uhc-options.cfg` next to the log (a line `renderer dx9|vulkan`, written to a temporary file and moved over the
old one). The entry has no flag 0x40, so it is greyed out during a match, as the stock options that need a restart are.

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
shared action tag, ModifyType and Data subtype hooks. The tech parser's loop 0x61FDB8 keeps the current `<Tech>` node to name it,
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
