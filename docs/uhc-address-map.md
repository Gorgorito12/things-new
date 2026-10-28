# UHC address map

Every site upstream AoE3UnHardcoded (v1.10, `reference/AoE3UnHardcoded/DLL`) patches in `age3y.exe`.
Target: stock Steam build `b1a1dab7…11d9d` (see [binaries.md](binaries.md)). Upstream checks only the
file size; the rows below record what was verified against this build on 2026-10-28.

## Conventions

- **Type** (semantics follow `PatchCodeCave`, `Utilities.cpp:50-217`)
  - `replace`: a 5-byte `jmp` at Site into DLL code that ends with a `jmp` to End. Only [Site, Site+5) is
    overwritten; [Site+5, End) stays intact but is skipped on this path.
  - `detour`: Site == End. Instructions starting at Site are relocated to a trampoline until ≥5 bytes
    are covered ("stolen"), and the hook runs first.
  - `redirect`: Site gets a `jmp` to a far End inside the game.
  - `case`: a 4-byte jump-table slot is overwritten.
  - `write32` / `bytes`: a raw data patch.
- **Status**: `unverified` → `confirmed` or `mismatch`. `confirmed` means:
  - Site (and End, where the cave falls through to it) is an instruction boundary in the stock exe;
  - the instructions there are the ones the upstream cave re-executes or replaces.
  - It says nothing about whether the cave's own logic is correct; cave defects are listed separately below.
- **Evidence**
  - `E1` = `ev_8c926efbad761e059e1481527b402bf332733a18a1facd63ab8ffd8bf7a27d4e`: REA `batch_decompile` of every site; gives the containing procedure.
  - `E1` was re-run as part of `E3` (`ev_c2186c76…`, see [engine-symbols.md](engine-symbols.md)); every site's containing procedure was identical.
  - `E2` = `ev_a75f4dbc0f32a99229e13cffcbc07942a0fdef1d56c4ec8119c1d93049ac7287`: REA `procedure_assembly` of FUN_00603ab7. Its record was not saved to disk; the same listing is in `cs` (`sites.txt`).
  - `cs` = capstone 5.0.6 disassembly of the file bytes, with two boundary checks:
    - a linear decode from the Ghidra entry, where the site lies in the entry's contiguous chunk;
    - decodes from Site−1…Site−48, which must land on Site.
  - Scripts and outputs are local evidence in `rea/evidence/age3y-b1a1dab7/` (not in the repository). The method, with a runnable example, is in [developer-guide.md](developer-guide.md#byte-level-checks-with-capstone).
- **Function**: the containing procedure from `E1`. "—" means the address lies in no Ghidra function (13 sites); those addresses resolve only through REA's file-offset fallback, so `E1`'s pseudocode for them is unrelated and must be ignored.
- **Source refs** are `file:line` in `reference/AoE3UnHardcoded/DLL`. The cfg key → patch dispatch is in `UHC.cpp:158-329` (parse) and `UHC.cpp:416-482` (apply).
- **Byte notation:** `NNh` = hex and `B` = bytes (`5 B` = 5 bytes). `[x]` = memory at x; `[C66234h]` is the game object pointer.

## Sites

| Patch | cfg key | Site VA | End VA | Type | Source | Status | Evidence | Function | Notes |
|---|---|---|---|---|---|---|---|---|---|
| AILimit | `noAILimit` | 0x603B0B | 0x603C4F | replace | Limits.asm:20 | confirmed | E1, E2, cs | 0x603AB7 | Stock fills a hard-coded personality table: 11 entries, or 14 when the TAD flag `[[C66234h]+C48h]&2` is set. It stores the count in `[esp+40h]` and the table in `[esp+50h]`; the cave writes both. **Cave defect**, see below. |
| DeckLimit | `deckCardCount` | 0x7EF026 | 0x7EF030 | replace | Limits.asm:36 | confirmed | E1, cs | 0x7EEFF7 | Stock `cmp eax,19h / jle / mov eax,19h`: a 25-card cap on the level's `maxdecksize` from `homecitylevels.xml`, which still applies (see [engine-symbols.md](engine-symbols.md), "Max deck size"). |
| PopLimit | `basePop`, `extraPop` | 0x4581F3 | 0x45823F | replace | Limits.asm:52 | confirmed | E1, cs | 0x4581A1 | Stock sequence (out-of-line clamps at 0x679618–0x67963B): extra ≤ 50; pop ≤ extra+200; pop ≤ extra+`[[[C66234h]+13Ch]+31Ch]`; `+[edx+4F4h]` if > 0; pop ≤ 250 (`FAh`). The cave keeps the `4F4h` add but **drops the world+31Ch clamp and the 250 cap**. |
| TeamLimit (SP) | `enableAllTeams` | 0x7A0709 | 0x7A0709 | detour | Limits.asm:82 | confirmed | E1, cs | 0x7A0628 | Stolen `push 8D31h` (5 B). The cave inserts the team 3/4 strings `8D2Fh`/`8D30h` first. |
| TeamLimit (MP) | `enableAllTeams` | 0x77674A | 0x77674A | detour | Limits.asm:158 | confirmed | cs | — | Stolen `jne 776780h` (rel8, first instruction, so it is relocated correctly) + `or ecx,-1`. |
| FameRestriction #1 | `removeFameRestriction` | 0x80E490 | 0x80E490 | detour | Limits.asm:200 | confirmed | E1, cs | 0x80E20A | Stolen `mov eax,[edi]; lea ecx,[esp+14h]` (6 B, no branches). |
| FameRestriction #2 | `removeFameRestriction` | 0x81943D | 0x81943D | detour | Limits.asm:310 | confirmed | E1, cs | 0x81922A | Stolen `mov edx,[esi]; lea eax,[esp+14h]` (6 B). |
| FameRestriction HC icons | `removeFameRestriction` | 0x5C1E1F | 0x5C1E37 | replace | Limits.asm:453 | confirmed | E1, cs | 0x5C1DEA | Stock `call 58E3EBh; push -1/0/0/BA96C4h; mov ecx,edi; mov [esi+168h],eax`. The cave reorders this and adds two icon loads. |
| FameRestriction icon slot (Fame) | `removeFameRestriction` | 0x9A218C | — | case | Limits.asm:481 | confirmed | E1, cs | 0x9A1DC9 | The jump table starts at 0x9A2180 (index×4); slot 3 holds the default 0x9A20A0, which sets no icon. The cave jumps to 0x9A2098 (`mov ecx,esi; push eax; call 593D42h`). |
| FameRestriction icon slot (XP) | `removeFameRestriction` | 0x9A2194 | — | case | Limits.asm:485 | confirmed | cs | 0x9A1DC9 | Slot 5; same default and target as the Fame slot. |
| FameTrickle | `removeFameRestriction` | 0x51B026 | — | write32 `0x00BD62F8` | Limits.asm:497 | confirmed | E1, cs | 0x51A5DC | This is the imm32 of `push 0BCD49Ch` at 0x51B025. The patch changes the key `"FavoriteUnit"` to `"Fame"` (0xBD62F8). |
| ConversionRestriction | `removeConversionRestriction` | 0x9D5B6C | — | bytes `90 90` | Limits.asm:512 | confirmed | cs | — | `74 3F` = `je 9D5BADh` after `push 37h; mov ecx,edi; call 44D863h; test al,al`. |
| RegistryPath | `ignoreRegistryPath` | 0x57CB54 | 0x6420A1 | redirect | RegistryPath.asm:13 | confirmed | E1, cs | 0x57CB0A | The site is `jl 6420A1h` (6 B); the patch makes it unconditional. |
| RevBanner | `customRevolutionBanners` | 0x81A7CC | 0x81A7EC | replace | RevBanner.asm:12 | confirmed | E1, cs | 0x81A2B8 | Stock: `jne 81A7F1h`, then a banner BString temp at ESP+44h, with the dtor at End. The cave uses ESP+28h instead. That slot is another branch's scope-local BString temp (0x81A666–0x81A67B) and is dead here, so this is benign (inference). |
| Cheat | `customCheats` | 0x551FE6 | 0x551FE6 | detour | Cheat.asm:10 | confirmed | E1, cs | 0x5515F1 | Stolen epilogue `pop edi/esi/ebx; add esp,10h` (6 B). The cave's locals, ESP+0Ch…1Bh, fit the frame. |
| Syscall AI | `customSyscalls` | 0x7294F4 | 0x7294F4 | detour | Syscall.asm:22 | confirmed | E1, cs | 0x7294E7 | Stolen `push 1; push 7286DFh` (7 B). This is the first registration in the group's function. |
| Syscall HC | `customSyscalls` | 0x5B5E08 | 0x5B5E08 | detour | Syscall.asm:27 | confirmed | E1, cs | 0x5B5DFB | Stolen `push 1; push 4011E6h`. |
| Syscall KB | `customSyscalls` | 0x885D14 | 0x885D14 | detour | Syscall.asm:32 | confirmed | E1, cs | 0x885D07 | Stolen `push 1; push 88112Ch`. |
| Syscall RM | `customSyscalls` | 0x60B8BF | 0x60B8BF | detour | Syscall.asm:37 | confirmed | E1, cs | 0x60B8B2 | Stolen `push 1; push 9017E5h`. |
| Syscall TR | `customSyscalls` | 0x988E03 | 0x988E03 | detour | Syscall.asm:42 | confirmed | E1, cs | 0x988DF0 | Stolen `push 1; push 4011E6h`. |
| Syscall UI | `customSyscalls` | 0x539542 | 0x539542 | detour | Syscall.asm:47 | confirmed | E1, cs | 0x539533 | Stolen `push 5D5E92h` (5 B). |
| Syscall UI2 | `customSyscalls` | 0x53575E | 0x53575E | detour | Syscall.asm:52 | confirmed | E1, cs | 0x535751 | Stolen `push 1; push 6F1E6Eh`. |
| Syscall XS | `customSyscalls` | 0x6257D9 | 0x6257D9 | detour | Syscall.asm:57 | confirmed | E1, cs | 0x6257CC | Stolen `push 1; push A5D578h`. |
| UnitCheck (shared) | farm/market/bigButton/explorer keys | 0x5EE78B | 0x5EE78B | detour | Units.asm:707 | confirmed | cs | — | Stolen `mov edi,[esi+140h]` (6 B). |
| CivCheck #1 (shared) | asian/native/bigButton/twoScout keys | 0x8D0318 | 0x8D031C | replace | Civs.asm:441 | confirmed | E1, cs | 0x8D0318 | The site is the function entry, `mov eax,[C66234h]` (5 B). End lies mid-instruction; the cave jumps to 0x8D031D itself. See the PatchCodeCave defect below. |
| CivCheck #2 (shared) | asian/native/bigButton/twoScout keys | 0x8DABA3 | 0x8DABA8 | replace | Civs.asm:455 | confirmed | E1, cs | 0x8DA07D | `mov edx,[C66234h]` (6 B). End lies mid-instruction; the cave jumps to 0x8DABA9. |
| FarmAnim #1 | `enableFarmAnim` | 0x4EDA85 | 0x4EDA8B | replace | Units.asm:268 | confirmed | cs | — | `mov edx,[ebp+140h]`, preceded by the jump/index tables of a switch (0x4EDA48–0x4EDA74). The cave reloads EBP from `[C66234h]`; whether EBP already holds that value here is **unverified**. |
| FarmAnim #2 | `enableFarmAnim` | 0x50DE33 | 0x50DF51 | replace | Units.asm:307 | confirmed | cs | — | `jne 4EDD6Ch; jmp 6A8E67h`. End is `mov ecx,esi; call 9DDADEh`, the rect-farm gather path. |
| FarmAnim #3 | `enableFarmAnim` | 0x73D41A | 0x73D422 | replace | Units.asm:342 | confirmed | E1, cs | 0x73D21E | `jne 73D427h; mov eax,[eax+5F4Ch]` (sacred field), then `jmp 73D264h`. |
| FarmAnim #4 | `enableFarmAnim` | 0x8CEC9F | 0x8CECA4 | replace | Units.asm:365 | confirmed | cs | — | `call 4E2C50h`, re-issued by the cave. |
| FarmAnim #5 | `enableFarmAnim` | 0x9DDB79 | 0x9DDB7F | replace | Units.asm:376 | confirmed | E1, cs | 0x9DDADE | `cmp ecx,[eax+5E58h]`, then `sete dl` at End. |
| FarmAnim #6 | `enableFarmAnim` | 0x4EE07F | 0x4EE085 | replace | Units.asm:391 | confirmed | cs | — | `je 586DFFh`. |
| FarmAnim #7 | `enableFarmAnim` | 0x4EE2FE | 0x4EE304 | replace | Units.asm:399 | confirmed | cs | — | `je 586E11h`. |
| FarmAnim #8 | `enableFarmAnim` | 0x6A8FE1 | 0x6A8FEA | replace | Units.asm:418 | confirmed | E1, cs | 0x586D70 | `call 44CB0Ah; cmp eax,ebx; jne 6A900Ch`. The cave adds `mov edx,eax`; whether EDX is live here is **unverified**. |
| RectFarmAnim #1 | `enableRectFarmAnim` | 0x9DDD80 | 0x9DDD92 | replace | Units.asm:429 | confirmed | E1, cs | 0x9DDADE | Four loads (db, proto ID), then `cmp ecx,[eax+607Ch]`. |
| RectFarmAnim #2 | `enableRectFarmAnim` | 0x4741F0 | 0x4741F6 | replace | Units.asm:444 | confirmed | E1, cs | 0x473F7F | `je 4743DDh`. |
| RectFarmAnim #3 | `enableRectFarmAnim` | 0x4EEDB4 | 0x4EEDBA | replace | Units.asm:465 | confirmed | cs | — | `mov ecx,[C66234h]`. |
| RectFarmAnim #4 | `enableRectFarmAnim` | 0x4EEE9E | 0x4EEEA4 | replace | Units.asm:483 | confirmed | cs | — | `mov ecx,[C66234h]`. |
| FarmRadius | `farmingRadius` | 0x9DE04D | 0x9DE053 | replace | Units.asm:507 | confirmed | E1, cs | 0x9DDADE | `mov ecx,[C0BBE0h]` (float 4.5). |
| MarketUnits | `marketUnits` | 0x7DEF70 | 0x7DEF75 | replace | Units.asm:578 | confirmed | cs | — | `mov edx,[C66234h]` (6 B). End lies mid-instruction; the cave jumps to 0x7DEF76. |
| TacticSwitching #1 | `tacticSwitching` | 0x5C161C | 0x5C1622 | replace | Units.asm:595 | confirmed | E1, cs | 0x5C13C5 | `je 5C10F1h`, then `cmp [esi+34h],59h` at End. |
| TacticSwitching #2 | `tacticSwitching` | 0x6949CD | 0x6949D2 | replace | Units.asm:602 | confirmed | E1, cs | 0x4C55E3 | `mov eax,[C66234h]` (5 B). |
| AttackTypeIcons #1 | `attackTypeIcons` | 0x51C945 | 0x51C945 | detour | Units.asm:618 | confirmed | E1, cs | 0x51BA38 | Stolen `pop edi; mov al,1; pop esi; pop ecx` before `ret`. |
| AttackTypeIcons #2 | `attackTypeIcons` | 0x5C2287 | 0x5C2287 | detour | Units.asm:624 | confirmed | E1, cs | 0x5C1DEA | Stolen `call 58E3EBh` (rel, first instruction, so it is relocated correctly). |
| AttackTypeIcons #3 | `attackTypeIcons` | 0x69B909 | 0x69B909 | detour | Units.asm:631 | confirmed | E1, cs | 0x4D7BD5 | Stolen `lea edx,[eax+11h]; cmp esi,edx`. The cave recomputes EAX via db+19B0h and clobbers ECX. |
| ExplorerUnits name | `explorerUnits` | 0x6A012A | 0x6A0132 | replace | Units.asm:664 | confirmed | E1, cs | 0x4702DC | `lea ecx,[eax+18h]; call 401F47h`. The cave reloads `EAX=[edi+84h]`. |
| ExplorerUnits KO msg | `explorerUnits` | 0x50B01F | 0x50B01F | detour | Units.asm:685 | confirmed | cs | — | Stolen `mov edx,[esi+10h]; mov eax,[edx+5Ch]`. |
| AsianCivs #1 | `asianCivs` | 0x454F1D | 0x454F22 | replace | Civs.asm:215 | confirmed | E1, cs | 0x454ED7 | `cmp eax,[C6FB88h]` inside a bool `isAsianCiv` (`ret 4`). End lies mid-instruction; the cave returns itself. |
| AsianCivs #2 | `asianCivs` | 0x8D6AC4 | 0x8D6AF7 | replace | Civs.asm:230 | confirmed | E1, cs | 0x8D6A7D | `cmp eax,[C6FB88h]; jne 8D6B0Ch; …`. Six branches into 0x8D6ACC land past the 5 patched bytes, which is fine. |
| AsianCivs #3 (wonder age-up) | `asianCivs` | 0x818284 | 0x8182A9 | replace | Civs.asm:239 | confirmed | E1, cs | 0x81807A | Stock `call 49A2D8h; test al,al; je 8182EBh; …BString compare…`. **Cave defect**, see below. |
| BigButton | `bigButtonCivs`, `noBigButtonBlds` | 0x461BD8 | 0x461BDE | replace | Civs.asm:255 | confirmed | E1, cs | 0x46188E | `jne 695955h`. |
| NativeCivs #1 | `nativeCivs` | 0x5126C1 | 0x5126C7 | replace | Civs.asm:292 | confirmed | E1, cs | 0x512651 | `mov ecx,[ecx+140h]`. |
| NativeCivs #2 | `nativeCivs` | 0x51271F | 0x512724 | replace | Civs.asm:300 | confirmed | E1, cs | 0x512651 | `cmp eax,[C6FB58h]` in a bool with no args (`ret`). End lies mid-instruction; the cave returns itself. |
| NativeCivs #3 | `nativeCivs` | 0x52B581 | 0x52B588 | replace | Civs.asm:315 | confirmed | E1, cs | 0x52A590 | `lea ecx,[esp+100h]`. |
| NativeCivs #4 | `nativeCivs` | 0x453D5E | 0x453D62 | replace | Civs.asm:322 | confirmed | E1, cs | 0x453D37 | `cmp byte ptr [esp+4],0` in `isNativeCiv(bool)`: C6FB50/54/58 always count, C6FB5C only with the flag. **Cave defect**, see below. |
| NativeCivs #5 | `nativeCivs` | 0x4904B5 | 0x4904BB | replace | Civs.asm:341 | confirmed | E1, cs | 0x490476 | `je 679E66h`. |
| NativeCivs #6 | `nativeCivs` | 0x4ECD6B | 0x4ECD73 | replace | Civs.asm:349 | confirmed | E1, cs | 0x4ECD39 | `cmp eax,[C6FB5Ch]; je 4ECD7Dh`. |
| NativeCivs #7 | `nativeCivs` | 0x67B0A5 | 0x67B0AD | replace | Civs.asm:358 | confirmed | E1, cs | 0x490960 | `cmp eax,[C6FB58h]; je 67B0BBh`. |
| NativeCivs #8 | `nativeCivs` | 0x8D47C9 | 0x8D47CF | replace | Civs.asm:367 | confirmed | E1, cs | 0x8D4790 | `jne 8D4894h`. |
| NativeCivs #9 | `nativeCivs` | 0x8D52AF | 0x8D52B5 | replace | Civs.asm:376 | confirmed | E1, cs | 0x8D51D0 | `je 8D53B4h`. |
| NativeCivs #10 (council age-up) | `nativeCivs` | 0x81ADEB | 0x81ADF3 | replace | Civs.asm:384 | confirmed | E1, cs | 0x81ABFC | `cmp [esp+10h],ebx; mov [esp+20h],eax`. The cave clobbers EAX; liveness on the `jne 81AE11h` path is **unverified**. |
| TwoScoutCivs #1 | `twoScoutCivs` | 0x77EBB2 | 0x77EBB2 | detour | Civs.asm:399 | confirmed | E1, cs | 0x77EB91 | Stolen `mov eax,[esi+1DCh]`. |
| TwoScoutCivs #2 | `twoScoutCivs` | 0x77EF29 | 0x77EF2F | replace | Civs.asm:412 | confirmed | cs | — | `push eax; call 8D0318h`, after `mov eax,[esp+10h]; push ebx`, so the cave's `[esp+14h]` equals EAX. |
| TwoScoutCivs #3 | `twoScoutCivs` | 0x77DDD2 | 0x77DDD2 | detour | Civs.asm:421 | confirmed | E1, cs | 0x77DBFE | Stolen `mov ecx,[esi+1DCh]`. |
| TwoScoutCivs #4 | `twoScoutCivs` | 0x77DFF4 | 0x77DFF4 | detour | Civs.asm:428 | confirmed | E1, cs | 0x77DBFE | Stolen `mov edx,[C66234h]`. |

No row is a `mismatch`: every upstream address is valid for this build.

## Beyond upstream

| Feature | cfg | Site | Type | Notes |
|---|---|---|---|---|
| hcShipmentPointFallback | `hcShipmentPointFallback <Proto> …` | 0x669E2E (exit of FUN_004C6CAE) | replace (5 B) | See below. |
| healNonIdle | `healNonIdle [UnitType]` (default `AbstractHealNonIdle`) | 0x9E0C79 (busy check in FUN_009E0B53); 0x9CD9C7 (idle test in the automatic search FUN_009CD865) | replace (5 B each) | For a healer whose proto is of the marker type: the search treats every candidate as idle (the hook returns AL = 1 instead of calling 0x44F1A7, then continues at 0x9CD9CC), and each heal tick skips the "target moving / fighting" test, continuing at 0x9E0C9F. Any other healer runs the stock code (0x44F1A7, 0x9E0C80). Is-a test: 0x44D7FA. |
| (extra abstract unit types) | requested by features, e.g. healNonIdle's marker | 0x51BA31 (epilogue of FUN_0051A5DC) | replace (5 B) | Registers each requested name after the stock abstract types, through 0x58E685 / 0x40295B (lookup) and 0x5E3549 (add, `id = [db+194h]`), and hands the ID to the feature. Stock drops unknown `<UnitType>` names, so without this a data-only marker does not exist. See [engine-symbols.md](engine-symbols.md), "Unit types and healing". |

User-facing descriptions of these features are in [modding-guide.md](modding-guide.md); their internals in [how-it-works.md](how-it-works.md).

**hcShipmentPointFallback, how it works.**
- The original exit is the "no valid gather unit" path: `pop ebp/edi/esi; xor eax,eax`, continuing at 0x669E33.
- The hook searches each configured proto with the stock unit query (0x453618 / 0x45356D / 0x4532B4 / 0x453484 / 0x453A36) and applies the same three checks as the stock blocks (verified copy: 0x6698B4..0x669963).
- On success it jumps to the stock store-and-return path, 0x4C6CB2.
- Proto names resolve on first use through 0x5A2346.
- Multiplayer is unverified.

**Stock behavior** (dynamic trace with `tools/re/trace_writes.py`; the original log, `hwbp-log.txt`, is local evidence): deleting the TC clears the point (0x6697FF). FUN_004C6CAE then moves it, but only to TC, FortFrontier, WarHut, Blockhouse, NoblesHut and three unresolved types.

**healNonIdle, how the sites were found.**
- **First version: tick only.** It patched only the heal tick. In game, surgeons still ignored a fighting explorer, and the tick hook was never reached.
- **Dynamic trace** (`tools/re/trace_exec.py`; the original log, `hwbp3-log.txt`, is local evidence): the action is started by the automatic search FUN_009CD865, which only takes idle targets (0x44F1A7).
- **Not this predicate.** FUN_004C6CD7 (codes 0x41/0x42) also tests "fighting", but the trace never reached it while healing.
- **Confirmed in game (2026-10-28):** with the second hook, a marked British surgeon heals the explorer while it fights.
- **Still unverified:** whether a direct order (right-click) on a fighting unit goes through any other filter, and the unmarked control (the British Explorer as healer). Multiplayer is also unverified.

## Known upstream defects (do not reproduce)

Found by reading upstream source (2026-10-27):
- **customSyscalls table overflow.** `customSyscalls` writes past its table: `TABLE_COUNT` is 11 while `Upls` is index 11 (`UHC.h:13,27`, `UHC.inc:58`). It clobbers BasePop/ExtraPop/DeckCardCount (`UHC.cpp:310`).
- **tacticSwitching IDs.** `tacticSwitching` alone never resolves its unit IDs, because UnitCheck only runs for other keys (`UHC.cpp:425` vs `Units.asm:718`).
- **Team-limit dtor.** The team-limit cave skips the BString destructor: it loads `0x4010CA` but never calls it (`Limits.asm:105,141`).
- **Plugin calling convention.** Plugins' `UHCPluginMain` is called as cdecl, though documented as stdcall (`UHC.cpp:385`).
- **Plugin loading.** `LoadLibraryW(fd.cFileName)` loads plugins by bare filename, so directory paths don't resolve.
- **Branch relocation offset.** `PatchCodeCave` reads `lpBuffer+1/+2` instead of `+dwSize` for rel32 branches (`Utilities.cpp:111,125`). That is only correct when the branch is the first stolen instruction. In this build every relocated branch is first (TeamLimit MP, AttackTypeIcons #2), so the bug is latent.
- **Config parser.** It has an operator-precedence bug (`Config.cpp:74`), and a single `/` aborts the parse (`:69-70`).

Found against the stock exe (2026-10-28; static inference, not observed at runtime):
- **AILimit leaves two locals uninitialized.** The replaced range also holds:
  - `mov dword [esp+28h],0` at 0x603B44. It runs after `push 2`, so it clears ESP+24h, the loaded-personality counter used as the array index at 0x5DE154/0x5DE2C1.
  - `mov byte [esp+1Fh],0` at 0x603B4C, which clears ESP+1Bh, the function's return flag (0x603DCD).

  The cave skips both, so they keep stale stack contents. A new implementation must zero them.
- **AsianCivs #3 tests EAX instead of AL.**
  - Stock uses `test al,al` after `call 49A2D8h`; the cave uses `test eax,eax`.
  - The callee returns false with `xor al,al`, which leaves EAX's upper bytes untouched. On the "civ has no entry" path (`or eax,-1` at 0x679D16) EAX becomes 0xFFFFFF00.
  - As a result, the cave takes the true branch for a false result.
- **NativeCivs #4 compares a dword where stock compares a byte.** Stock uses `cmp byte ptr [esp+4],0`; the cave uses `cmp dword ptr [esp+4],0`. Garbage in the upper bytes of the caller's bool argument would select the `[C6FB5Ch]` path.
- **PatchCodeCave relocates garbage when End − Site < 5.** For CivCheck #1 and NativeCivs #4, End lies inside an instruction. `PatchCodeCave` decodes from that mid-instruction byte and copies the result into a trampoline. The trampoline is unreachable, because the cave jumps or returns explicitly, but it is still built. A new implementation should take the real continuation address instead.
- **FameRestriction #2 passes the wrong owner.** In FUN_0081922A, stock passes **EDI** to 0x4539D3 for each cost line (ESI is the UI object there). The upstream cave at 0x81943D reuses the block from #1 and passes **ESI**.
  - Our DLL passes EDI.
  - In the stock functions, #1 already lists resources 2, 1, 0 and 7, and #2 lists 2, 1 and 0.
- **PopLimit misses the negative-extra path.** When `[edx+4F8h] < 0`, stock jumps from 0x679611 to 0x4581FC with ECX = 0. That address lies past the 5 patched bytes, so the stock 200/world/250 clamps still apply. Our DLL also hooks 0x4581FC.
- **PopLimit leaves shared team population alone.** In that mode (`[world+6913h] != 0`, out-of-line at 0x679641), each player is capped at 200 and at world+31Ch. This path is unpatched, both upstream and in our DLL.
- **PopLimit drops two clamps** besides lifting the 50/200 limits:
  - the clamp against `[[[C66234h]+13Ch]+31Ch]`, a world-level value, probably the game-setup pop cap (inference);
  - the final 250 cap.

## Known open problems (upstream issues / TODO.md)

- `asianCivs` breaks politician age-up (#10).
- UI/train-list corruption past some limit (#8).
- The Dojo and the Summer Palace count as a fire pit (#5).
- `eso.com` is a hardcoded host (#3); WoL patches the string to `age3.us`.
- In MP lobbies, Team 3/4 is visible only to the selecting player.
