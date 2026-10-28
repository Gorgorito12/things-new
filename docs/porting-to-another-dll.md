# Porting features to another UHC DLL

For mods that ship **their own `uhc.dll`**, such as Wars of Liberty. The UHC loader loads one
`UHC.dll`, and this project has no plugin loader yet, so such a mod cannot run this DLL next to
its own. Replacing its DLL with this one would lose its own features. The way to use this
project's features is to rebuild them inside the mod's DLL.

This guide covers the features that are new in this DLL:
- `healNonIdle`, with the extra abstract unit types it relies on;
- `hcShipmentPointFallback`.

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

**Your DLL.** Each feature writes a 5-byte `jmp` at one place, and relies on stock code around
it: the instructions it re-executes, the code it jumps back to, and, for
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

**The reliable check is at runtime.** Port the `VerifyAll` step (below) and run it after your
DLL has applied all its own patches. A range that another patch changed then makes the feature
log a mismatch and refuse to apply, instead of corrupting the game.

## 2. What to copy

| Files | What they are | Needs |
|---|---|---|
| [`src/unittypes.h`](../src/unittypes.h), [`src/unittypes.cpp`](../src/unittypes.cpp), [`src/hooks/unittype_hooks.asm`](../src/hooks/unittype_hooks.asm) | Registers extra abstract unit type names on every data load. | site `AbstractTypesEnd`, `VerifyAll`, `WriteJmp`, `Log`, `TRACE_ONCE` |
| [`src/features/heal.cpp`](../src/features/heal.cpp), [`src/hooks/heal_hooks.asm`](../src/hooks/heal_hooks.asm) | `healNonIdle`. | unittypes, sites `HealIdleCheck` and `HealAutoSearchIdle`, your cfg reader |
| [`src/features/shipments.cpp`](../src/features/shipments.cpp), [`src/hooks/shipment_hooks.asm`](../src/hooks/shipment_hooks.asm) | `hcShipmentPointFallback`. | sites `GatherFallback*`, your cfg reader |

Support code they use, small enough to copy or to map onto your own helpers:
- [`src/site.h`](../src/site.h) and the six `Site` entries of `src/generated/sites.h`.
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
  - the `__stdcall` callbacks, such as `UhcRegisterAbstractUnitTypes`.
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

## 5. Integration rules

- **Keep the cfg keys and their syntax:**
  - `healNonIdle [UnitType]`, default `AbstractHealNonIdle`;
  - `hcShipmentPointFallback <Proto> …`, 1 to 64 names.

  The [modding guide](modding-guide.md#5-feature-reference) then applies to your mod as written.
- **Verify, then write.** Check all of a feature's ranges first, and write nothing if any range
  differs.
- **Apply from `UHCMain`.** All three hooks are in code that runs later, during data load or in
  game.
- **Multiplayer determinism** ([how-it-works.md](how-it-works.md#5-rules-that-keep-multiplayer-deterministic)):
  - names are resolved inside the game, from its own database;
  - choices follow cfg order, then the stock unit query order;
  - no hook sends a network command.

  Keep it that way if you change the code. In particular, never set the shipment point through
  `aiSetHCGatherPoint`'s setter (`0x82D9CB`): it sends a network command, which every machine
  would then send.
- **Saved games and replays:** `healNonIdle` adds a unit type, which changes the unit type count.
  Load saves and replays with the same DLL and cfg they were made with.

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
- **Check the type table** with the game running: `python -I tools/re/inspect_unittypes.py
  AbstractHealNonIdle` lists the protos that carry the type.

## 7. What is not verified

- **Wars of Liberty:** neither feature has been run with WoL's exe or next to WoL's DLL
  ([section 1](#1-check-that-you-can-use-the-sites)).
- **Multiplayer, saved games and replays:** untested for both features.
- **hcShipmentPointFallback:**
  - three of the eight stock fallback types are not resolved yet;
  - water shipment points (`[hc+190h]`) were not tested.
- **healNonIdle:**
  - a direct order (right-click) on a fighting unit was not verified;
  - whether the game prefers `protoy.xml` or `protoy.xml.XMB` is not established, so edit both.
