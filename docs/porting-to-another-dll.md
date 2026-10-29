# Porting features to another UHC DLL

For mods that ship **their own `uhc.dll`**, such as Wars of Liberty. The UHC loader loads one
`UHC.dll`, and this project has no plugin loader yet, so such a mod cannot run this DLL next to
its own. Replacing its DLL with this one would lose its own features. The way to use this
project's features is to rebuild them inside the mod's DLL.

This guide covers these features that are new in this DLL:
- `healNonIdle`, with the extra abstract unit types it relies on;
- `hcShipmentPointFallback`;
- `damageOverTime`;
- `dodgeAnyUnit`, `dodgeSoundSet` and `criticalSoundSet`;
- `multipleInstances`.

`bufferedFileReads` is not covered yet. Its design is in
[how-it-works.md](how-it-works.md#bufferedfilereads), and its code is
[`src/features/fileio.cpp`](../src/features/fileio.cpp).

The code is under the [MIT license](../LICENSE): copy it into your DLL, keeping the license
notice. For the user side of each feature (cfg syntax, data edits, log lines), see the
[modding guide](modding-guide.md#5-feature-reference). For the engine internals, see
[how-it-works.md](how-it-works.md).

Contents:
1. [Check that you can use the sites](#1-check-that-you-can-use-the-sites)
2. [What to copy](#2-what-to-copy)
3. [Building the hooks in your project](#3-building-the-hooks-in-your-project)
4. [Each feature's contract](#4-each-features-contract)
5. [Integration rules](#5-integration-rules)
6. [Data and testing](#6-data-and-testing)
7. [What is not verified](#7-what-is-not-verified)

## 1. Check that you can use the sites

All addresses are virtual addresses in the stock Steam `age3y.exe` (`b1a1dab7…`) plus the UHC
loader. They are only valid for that build, so any patched exe must be built from it.

**The exe.** The Wars of Liberty exe (`0a277f14…`) is the stock exe plus the loader, LAA and four
string patches ([binaries.md](binaries.md#extra-patches-in-the-wars-of-liberty-exe)). None of
those patches falls inside the ranges below.

**Your DLL.** Each hook writes a 5-byte `jmp` (NOP-padded where it covers more), and relies on
stock code around it: the instructions it re-executes, the code it jumps back to, and, for
`hcShipmentPointFallback`, the stock search block it mirrors. **Nothing else may patch these
ranges**, neither your DLL nor any other tool:

| Site | VA | Length | Written | Stock bytes at the written VA | Role |
|---|---|---|---|---|---|
| `GatherFallbackExit` | `0x669E2E` | 10 B | 5 B at `0x669E2E` | `5D 5F 5E 33 C0` (`pop ebp; pop edi; pop esi; xor eax,eax`) | "nothing found" exit of FUN_004C6CAE; hcShipmentPointFallback hook |
| `GatherFallbackStore` | `0x4C6CB2` | 12 B | — | — | store-and-return path the hook jumps to |
| `GatherFallbackBlock` | `0x6698B4` | `0xB0` B | — | — | stock FortFrontier search block; the hook repeats its logic, so it must be unchanged |
| `HealIdleCheck` | `0x9E0C79` | `0x2C` B | 5 B at `0x9E0C79` | `8B 4F 58 85 C9` (`mov ecx,[edi+58h]; test ecx,ecx`) | busy test of each heal tick (FUN_009E0B53) |
| `HealAutoSearchIdle` | `0x9CD9C0` | `0x15` B | 5 B at `0x9CD9C7` | `E8 DB 17 A8 FF` (`call 44F1A7h`) | idle test of the automatic heal search (FUN_009CD865) |
| `AbstractTypesEnd` | `0x51BA23` | `0x15` B | 5 B at `0x51BA31` | `5F 5E B0 01 5B` (`pop edi; pop esi; mov al,1; pop ebx`) | epilogue of the abstract unit type registration (FUN_0051A5DC) |
| `DotProtoActionTag` | `0x5FA10F` | `0x1B` B | 8 B at `0x5FA11E` | `85 C0 0F 84 C7 33 00 00` (`test eax,eax; je 5FD4EDh`) | unknown-tag fall-through of the action parser FUN_005F98A0; damageOverTime tag hook |
| `DotProtoActionCall` | `0x5FA20E` | 5 B | — | — | the `<ProtoAction>` handler's `call 5F98A0h`; the tag hook checks its return address 0x5FA213 |
| `DotTakeDamageEntry` | `0x49B3D9` | 14 B | 6 B at `0x49B3D9` | `81 EC 8C 00 00 00` (`sub esp,8Ch`) | entry of TakeDamage FUN_0049B3D9; damageOverTime hit hook |
| `DotWorldUpdateEntry` | `0x481A57` | 8 B | 5 B at `0x481A57` | `83 EC 0C 53 55` (`sub esp,0Ch; push ebx; push ebp`) | entry of the world update FUN_00481A57; damageOverTime tick hook |
| `DodgeProtoCheck` | `0x49ACE5` | 12 B | 6 B at `0x49ACE5` | `8B 46 5C 8B 40 04` (`mov eax,[esi+5Ch]; mov eax,[eax+4]`) | proto test of the dodge FUN_0049ACAA; dodgeAnyUnit hook |
| `DodgeTechCheck` | `0x6A249C` | 10 B | — | — | the stock dodge path the hook enters (`push "ypDodge"; call 600BE1h`) |
| `DodgeCall` | `0x49B023` | 7 B | 5 B at `0x49B023`, only with `log` | `E8 82 FC FF FF` (`call 49ACAAh`) | the damage function's call to the dodge; dodgeAnyUnit log wrapper |
| `DodgeSound` | `0x6A2628` | 8 B | 5 B at `0x6A2628` | `68 E0 74 BD 00` (`push "PowerEvade"`) | the dodge's sound set; dodgeSoundSet hook |
| `CriticalSound` | `0x6A2A9A` | 8 B | 5 B at `0x6A2A9A` | `68 18 75 BD 00` (`push "PowerCriticalStrike"`) | the critical hit's sound set; criticalSoundSet hook |
| `SingleInstanceSemaphore` | `0x55A185` | 6 B | — (the IAT slot `0xB843F0` instead) | `FF 15 F0 43 B8 00` (`call [CreateSemaphoreW]`) | the single-instance check; multipleInstances knows this call by its return address `0x55A18B` |

The full expected bytes of every range are in [`src/generated/sites.h`](../src/generated/sites.h),
generated from the stock exe by [`tools/gen_sites.py`](../tools/gen_sites.py).

**Status for Wars of Liberty: not checked.**
- None of these addresses appears among the WoL `uhc.dll` sites found so far
  ([wol-uhc-map.md](wol-uhc-map.md)). That map is a first pass, though: many WoL features have no
  traced sites.
- The only known WoL patch in the same functions is FameTrickle at `0x51B026`, inside
  FUN_0051A5DC. It is outside the `AbstractTypesEnd` range and only renames a built-in type, so
  the two are compatible.
- WoL's `ProtoUnitExtensionFeature` and `ExtendedDataSubtypesFeature` may touch unit type
  registration; check them first.
- `damageOverTime` hooks the entries of TakeDamage and of the world update, two places a mod
  DLL with its own combat or simulation features may also patch. Whether WoL does was not
  checked.
- The dodge sites (`Dodge*`, `CriticalSound`, and the continuations `0x49ACEB`, `0x49B028`,
  `0x6A262D`, `0x6A2A9F`): none of these addresses appears as a 32-bit value in WoL's `uhc.dll`
  or `wol.dll` (byte search, 2026-10-28). That rules out absolute references, not every patch.

**The reliable check is at runtime.** Port the `VerifyAll` step (below) and run it after your
DLL has applied all its own patches. A range that another patch changed then makes the feature
log a mismatch and refuse to apply, instead of corrupting the game.

## 2. What to copy

| Files | What they are | Needs |
|---|---|---|
| [`src/unittypes.h`](../src/unittypes.h), [`src/unittypes.cpp`](../src/unittypes.cpp), [`src/hooks/unittype_hooks.asm`](../src/hooks/unittype_hooks.asm) | Registers extra abstract unit type names on every data load. | site `AbstractTypesEnd`, `VerifyAll`, `WriteJmp`, `Log`, `TRACE_ONCE` |
| [`src/features/heal.cpp`](../src/features/heal.cpp), [`src/hooks/heal_hooks.asm`](../src/hooks/heal_hooks.asm) | `healNonIdle`. | unittypes, sites `HealIdleCheck` and `HealAutoSearchIdle`, your cfg reader |
| [`src/features/shipments.cpp`](../src/features/shipments.cpp), [`src/hooks/shipment_hooks.asm`](../src/hooks/shipment_hooks.asm) | `hcShipmentPointFallback`. | sites `GatherFallback*`, your cfg reader |
| [`src/features/damageovertime.cpp`](../src/features/damageovertime.cpp), [`src/hooks/dot_hooks.asm`](../src/hooks/dot_hooks.asm) | `damageOverTime`. | sites `Dot*`, your cfg reader |
| [`src/features/dodge.cpp`](../src/features/dodge.cpp), [`src/hooks/dodge_hooks.asm`](../src/hooks/dodge_hooks.asm) | `dodgeAnyUnit`, `dodgeSoundSet`, `criticalSoundSet`. | unittypes, sites `Dodge*` and `CriticalSound`, `WriteCall` (in `patch.cpp`), your cfg reader |
| [`src/features/instances.cpp`](../src/features/instances.cpp) (no `.asm`) | `multipleInstances`. | site `SingleInstanceSemaphore`, `VerifyAll`, `WriteDword`, `Log`, your cfg reader |

Support code they use, small enough to copy or to map onto your own helpers:
- [`src/site.h`](../src/site.h) and the matching `Site` entries of `src/generated/sites.h`.
- [`src/patch.h`](../src/patch.h), [`src/patch.cpp`](../src/patch.cpp):
  - `VerifyAll` compares live memory with the expected bytes;
  - `WriteJmp` writes `jmp rel32` and NOP-fills the rest, through `VirtualProtect` and
    `FlushInstructionCache`.

  If your DLL has its own patch library (WoL uses `remod`), keep the check before every write.
- [`src/log.h`](../src/log.h), [`src/log.cpp`](../src/log.cpp): `Log` (printf-style, wide) and
  `UhcTraceHook`, which `TRACE_ONCE` calls. Point them at your own logger if you like.
- [`src/hooks/common.inc`](../src/hooks/common.inc): the `TRACE_ONCE` macro. Optional: delete
  the `TRACE_ONCE` lines if you do not want the "hook reached" log lines.
- [`src/config.h`](../src/config.h): only `Config::First(key)` is used. It returns the key's
  arguments as a list of strings, or null when the key is absent. Replace those two calls with
  your own cfg reader.

The `Apply…` functions return `Outcome` from [`src/features.h`](../src/features.h). Replace it
with your own result type.

## 3. Building the hooks in your project

- **x86 only.** The game is a 32-bit process.
- **MASM.** The hooks are `.asm` files for `ml.exe`, with `.model flat, c`. The C++ side declares
  every shared symbol `extern "C"`:
  - the hook procedures, such as `UhcHealNonIdleHook`;
  - the globals, such as `g_uhcHealNonIdleType`;
  - the `__stdcall` callbacks, such as `UhcRegisterAbstractUnitTypes`;
  - for `damageOverTime`, the two `__fastcall` wrappers, which the hooks reach through the
    pointer variables `g_uhcDotTakeDamage` and `g_uhcDotWorldUpdate`, so MASM never needs their
    decorated names. The trampolines `UhcDotTakeDamageStock` and `UhcDotWorldUpdateStock` go the
    other way: C++ casts their addresses to function pointers.
- **Build setup:**
  - CMake: `project(... LANGUAGES CXX ASM_MASM)`, as in this repository's `CMakeLists.txt`.
  - A Visual Studio project: enable **Build Dependencies → Build Customizations → masm**, then
    add the `.asm` files.
  - With `/SAFESEH` (the x86 default), pass `/safeseh` to `ml.exe` too.
- **Object names.** Don't give a `.asm` file the same base name as a `.cpp`: CMake then puts the
  object in a subfolder that `ml.exe` doesn't create, and the build fails with A1000.
- **Inline assembly instead of MASM** also works (`__declspec(naked)` functions; MSVC x86 only).
  Keep two things:
  - continuations and engine calls go through absolute addresses stored in data
    (`jmp dword ptr [label]`, `call dword ptr [label]`);
  - each hook re-executes the stolen instructions exactly as the `.asm` comments say.
- **A relocatable DLL is fine** (WoL's uses DYNAMIC_BASE). The exe has no ASLR, so its addresses
  are fixed, and the DLL's own symbols are relocated by the loader.

## 4. Each feature's contract

What each hook expects and must preserve. The `.asm` files repeat this in their comments; the
reasoning is in [how-it-works.md](how-it-works.md#4-the-features).

### Extra abstract unit types

- **Why:** TAD registers a fixed list of abstract unit types, compiled into the exe. Any other
  `<UnitType>` in `protoy.xml` is dropped silently. `healNonIdle` needs its marker
  (`AbstractHealNonIdle` by default) to exist as a type.
- **API:** `RequestAbstractUnitType(name, &id)`. The first call installs the hook at `0x51BA31`.
  Call it from `UHCMain`, before the game loads its data.
- **The hook** runs at the end of FUN_0051A5DC, on every data load, with EDI = database:
  - for each requested name it looks the name up (`0x58E685` hash bucket, `0x40295B` find);
  - if the name is missing, it adds it with `0x5E3549(table, name, &id)`, where
    `table = database+190h` and `id = [database+194h]`. IDs must be dense;
  - it writes the ID to the caller's variable on every load;
  - it then re-executes `pop edi; pop esi; mov al,1; pop ebx` and jumps to `0x51BA36`.
- **If your DLL can already register unit types**, use your mechanism and skip this one. Two
  conditions:
  - the name must be registered before the protos load, so the proto loader sets its bit;
  - its ID must reach `g_uhcHealNonIdleType` on every data load.

### healNonIdle

- **Global:** `g_uhcHealNonIdleType`, the marker's unit type ID. It may also hold a proto ID.
  While it is -1, both hooks run the stock code.
- **Is-a test:** `0x44D7FA`, `bool thiscall(proto, typeId)`. The healer's proto is
  `[unit+5Ch]`. The result is in AL only.
- **Heal tick hook** at `0x9E0C79`, in FUN_009E0B53:
  - entry state: EDI = target, ESI = heal action, healer at `[esi+10h]`. ECX is free, since the
    stolen `mov ecx,[edi+58h]` overwrites it;
  - marked healer: jump to `0x9E0C9F`, the heal path;
  - any other healer: re-execute `mov ecx,[edi+58h]; test ecx,ecx`. Jump to `0x9E0C9F` if ECX is
    zero, else to `0x9E0C80`, the stock busy tests.
- **Automatic search hook** at `0x9CD9C7`, in FUN_009CD865. It replaces `call 44F1A7h`:
  - entry state: ECX = the candidate's action manager, ESI = candidate, healer at `[ebp+4]`;
  - marked healer: AL = 1;
  - any other healer: AL from the stock call, with ECX unchanged;
  - both continue at `0x9CD9CC` (`test al,al`).
  - **Both hooks are needed.** With the tick hook alone nothing changes: the search never starts a
    heal on a busy unit, so the tick hook is never reached.

### dodgeAnyUnit, dodgeSoundSet and criticalSoundSet

- **Global:** `g_uhcDodgeType`, the marker's unit type ID (or a proto ID). While it is -1 the
  proto hook runs the stock code.
- **Proto hook** at `0x49ACE5`, in FUN_0049ACAA (`bool thiscall(unit)`, the dodge test):
  - entry state: ESI = the unit hit, ECX = database, EBX = its player, EDI = `[world+7Ch]`;
  - marked unit (`0x44D7FA([esi+5Ch], type)`): restore ECX and jump to `0x6A249C`, the stock dodge
    path (tech `ypDodge`, 15 % roll, floating text, sound);
  - any other unit: re-execute `mov eax,[esi+5Ch]; mov eax,[eax+4]` and jump to `0x49ACEB`, the
    stock compares with the three `ypMonkJapanese` IDs. ECX must still hold the database.
- **Log wrapper** (only with `log`): the `call 49ACAAh` at `0x49B023` is redirected to a function
  that calls `0x49ACAA` with the same ECX, logs the unit when AL = 1 and returns AL. The caller
  continues at `0x49B028` (`test al,al`).
- **Sound hooks** replace a `push imm32` of a sound set name and push another name instead:
  - `0x6A2628`, ESI = the unit that dodged; continue at `0x6A262D`;
  - `0x6A2A9A`, EBX = the attacking unit (non-null there); continue at `0x6A2A9F`;
  - preserve ECX (the game object, used by the call `0x4AA24C` that follows); EAX and EDX are
    free. The pushed pointer must stay valid until the call returns; the rules' strings live as
    long as the DLL.
- **Marker registration:** through the abstract unit types above. The sound rules register
  their type names the same way, which returns the existing ID for a proto or stock type.

### hcShipmentPointFallback

- **Globals:** `g_uhcGatherFallbackTypes[64]` (proto IDs, -1 = skip) and
  `g_uhcGatherFallbackCount`.
- **Name resolution:** on the first call of the hook, through `0x5A2346`
  (`thiscall(database, name)` → proto ID), with database = `[[C66234h]+140h]`. This happens once
  per process, so every game in a run must use the same data.
- **The hook** at `0x669E2E` sits on the "nothing found" exit of FUN_004C6CAE, after the stock
  search of its eight fixed types.
  - Entry state: ESI = the unit query object, `[esp+10h]` = home city, `[esp+18h]` = store
    flag. EBX, EBP and EDI are free, because the epilogue pops them.
  - For each configured proto it repeats the stock block at `0x6698B4..0x669963`:
    - the same query calls (`0x453618`, `0x45356D`, `0x4532B4`, `0x453484`, `0x453A36`);
    - the same unit lookup in the world;
    - the same three checks: `vtbl+A4h`, `0x44DDB4`, `0x4802C6 != 1`.
  - Found: EDI = the unit, then jump to `0x4C6CB2`. That stock path stores the unit's ID in
    `[hc+18Ch]` when the store flag is 1, and returns the unit.
  - Nothing found: re-execute `pop ebp; pop edi; pop esi; xor eax,eax` and jump to `0x669E33`.

### damageOverTime

- **State, all in `damageovertime.cpp`:**
  - the attachments read from the data, keyed by (attacker proto ID, action name index);
  - the running poisons, keyed by (unit ID, attachment proto ID, attacker player);
  - the "Attaching" name index.

  The poisons live in a `std::map`, so every machine walks them in the same order.
- **Tag hook** at `0x5FA11E`, in FUN_005F98A0, over `test eax,eax; je 5FD4EDh`:
  - re-execute the test: on EAX = 0 (the `ModifyExclusive` compare matched), jump to `0x5FD4ED`;
  - otherwise, only when `[esp+C0h]` is `0x5FA213` (a `protoy` `<ProtoAction>`), call
    `UhcDotProtoActionTag(tagName = ESI, node = EDI, proto = [esp+C4h], action = [esp+C8h])`
    inside `pushad`/`popad`;
  - then jump to `0x5FA126`, the next child.
- **TakeDamage hook** at `0x49B3D9`, a `jmp` to the wrapper `UhcDotTakeDamage`:
  - `float __fastcall(unit, unused, 13 stock arguments)`, so it pops 34h bytes and returns in
    st0, exactly like the stock thiscall function;
  - it calls the stock function through `UhcDotTakeDamageStock` (`sub esp,8Ch; jmp 49B3DFh`);
  - when damage was dealt, it adds or renews a poison.
- **World update hook** at `0x481A57`, a `jmp` to `UhcDotWorldUpdate`:
  - `bool __fastcall(world, unused, int, int deltaMs)`, `ret 8`, result in AL;
  - it calls the stock update through `UhcDotWorldUpdateStock` (`sub esp,0Ch; push ebx;
    push ebp; jmp 481A5Ch`), then applies the due ticks when `world == [[C66234h]+13Ch]`;
  - each tick calls the **stock** TakeDamage (the trampoline, not the wrapper) with p8..p13 =
    `0, 0, 1, 1, -2, 1`, but with p11 = 0 when the attacking unit is gone. With p11 = 1,
    TakeDamage's army code (0x6A3253) reads the attacking unit with no null check, so a tick on
    an AI army unit would crash;
  - another game drops every poison: a jump of the world's step count `[world+F8h]` (normally +1
    per update), game time going back, another world pointer, or a new data load.
- **Engine calls:** `0x5A2346` (proto ID by name), `0x45311B` (a player's copy of a proto), unit
  `vtbl+A4h` (alive). The layouts read (unit, world, player, action set, action, the
  action-name table) are listed in [engine-symbols.md](engine-symbols.md), "Damage and poison".
- **If your DLL already hooks TakeDamage or the world update,** call this feature's logic from
  your own wrapper instead of installing a second `jmp` at the same entry: `VerifyAll` would
  refuse the second patch anyway.

### multipleInstances

- **IAT hook** on `CreateSemaphoreW`, slot `0xB843F0`. The slot must hold the `GetProcAddress`
  address when the feature applies; if your DLL also wraps that import, chain the two.
- **Only the call with return address `0x55A18B`** (the single-instance check, stock name
  `Global\Age3`) gets `-` and an FNV-1a hash of the exe's lowercase folder appended. Every other
  call passes through unchanged.
- **`background`** installs a `WH_CBT` hook for the calling thread. It must run on the game's main
  thread, before the game creates its first window: the UHC loader's `UHCMain` does. A DLL that
  initializes elsewhere must target the main thread's ID instead. The hook creates top-level windows
  with `hwndInsertAfter = HWND_BOTTOM`, wraps their window procedure to keep that z-order, and
  refuses every `HCBT_ACTIVATE`.

## 5. Integration rules

- **Keep the cfg keys and their syntax:**
  - `healNonIdle [UnitType]`, default `AbstractHealNonIdle`;
  - `hcShipmentPointFallback <Proto> …`, 1 to 64 names;
  - `damageOverTime [log]`, with `<AttachProtoUnit>` in `protoy.xml` and an `Attaching` action on
    the attachment proto;
  - `dodgeAnyUnit [UnitType] [log]`, default `AbstractDodge`, and any number of
    `dodgeSoundSet <UnitType> <SoundSet>` / `criticalSoundSet <UnitType> <SoundSet>` lines.

  The [modding guide](modding-guide.md#5-feature-reference) then applies to your mod as written.
- **Verify, then write.** Check all of a feature's ranges first, and write nothing if any range
  differs.
- **Apply from `UHCMain`.** Every hook is in code that runs later, during data load or in game.
- **Multiplayer determinism** ([how-it-works.md](how-it-works.md#5-rules-that-keep-multiplayer-deterministic)):
  - names are resolved inside the game, from its own database;
  - choices follow cfg order, then the stock unit query order;
  - poisons tick on the game time `[world+108h]`, in integer milliseconds and key order;
  - no hook sends a network command.

  Keep it that way if you change the code. In particular, never set the shipment point through
  `aiSetHCGatherPoint`'s setter (`0x82D9CB`): it sends a network command, which every machine
  would then send.
- **Saved games and replays:** `healNonIdle` and `dodgeAnyUnit` add a unit type, which changes the unit type count.
  Load saves and replays with the same DLL and cfg they were made with. `damageOverTime` keeps
  its poisons outside the game state, so a loaded game has none.

## 6. Data and testing

- **Data.** Mark each healer with `<UnitType>AbstractHealNonIdle</UnitType>` in both
  `data\protoy.xml` and `data\protoy.xml.XMB`. For the XMB, `tools/xmbedit.py add-unittype` does
  it ([modding guide, section 6](modding-guide.md#6-editing-the-game-data)).
- **Log.** If you kept `Log` and `TRACE_ONCE`, the lines to expect are listed per key in the
  [modding guide](modding-guide.md#5-feature-reference):
  - at startup, `applied`;
  - while the data loads, `hook reached: abstract unit types (0x51BA31)` and
    `unit types: AbstractHealNonIdle -> <ID> (…), added`;
  - in game, the `hook reached` line of each feature hook.
- **In game:**
  - **healNonIdle:** marked surgeons heal an explorer while it fights.
  - **hcShipmentPointFallback:** delete every Town Center (and every other stock fallback
    building) and send a shipment. It must arrive at the first listed building that still
    stands.
  - **damageOverTime:** with the data of the
    [modding guide](modding-guide.md#damageovertime) and `damageOverTime log`, hit a unit once
    and pull back. The log must show one `tick` line per ROF with the hitpoints falling. Then
    start a skirmish against an AI and check that the AI plays. A tactics file shipped as XML
    with a line break after a tactic name stops the AI scripts from compiling
    ([modding guide, "Tactics files"](modding-guide.md#tactics-files)).
  - **dodgeAnyUnit:** mark a non-monk unit, make `YPDodge` active for its player, and let enemies
    shoot it. With `dodgeAnyUnit … log`, about one hit in seven logs
    `dodgeAnyUnit: unit N (Proto) dodged a hit`; a Japanese monk still dodges as in stock.
    `tools/testbed.py` builds such a fight with no clicks
    ([developer guide](developer-guide.md#driving-the-game-unattended)).
- **Check the type table** with the game running: `python -I tools/re/inspect_unittypes.py
  AbstractHealNonIdle` lists the protos that carry the type.

## 7. What is not verified

- **Wars of Liberty:** no feature has been run with WoL's exe or next to WoL's DLL
  ([section 1](#1-check-that-you-can-use-the-sites)).
- **Multiplayer, saved games and replays:** untested for every feature.
- **hcShipmentPointFallback:**
  - three of the eight stock fallback types are not resolved yet;
  - water shipment points (`[hc+190h]`) were not tested.
- **healNonIdle:**
  - a direct order (right-click) on a fighting unit was not verified.
- **dodgeAnyUnit / dodgeSoundSet / criticalSoundSet:** confirmed in single player only; the
  sound sets were checked in the log, not by ear. The unit's rollover text about dodging (if any)
  still names only the Japanese monks (0x6AB049, not traced).
- **damageOverTime:** confirmed in single player only. The game loads `protoy.xml.XMB` unless
  `protoy.xml` is newer ([modding guide, section 6](modding-guide.md#6-editing-the-game-data)),
  so keep both in step. A tick on an AI army unit after the attacking unit is gone (the p11 = 0
  path) comes from the code and was not reproduced in game.
- **multipleInstances:** confirmed with two copies on one machine, in single player only.
