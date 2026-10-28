# UHC address map

Every site upstream AoE3UnHardcoded (v1.10, `reference/AoE3UnHardcoded/DLL`) patches in `age3y.exe`.
Target: stock Steam build `b1a1dab7…11d9d` (see [binaries.md](binaries.md)). Upstream checks only the
file size, so every VA below is a claim to verify, not a fact.

## Conventions

- **Type**
  - `replace`: `jmp` at Site into DLL code that returns to End; bytes in [Site, End) are dead.
  - `detour`: Site == End; ≥5 stolen bytes are relocated to a trampoline and the hook runs first.
  - `redirect`: Site gets a `jmp` to a far End inside the game.
  - `case`: a 4-byte jump-table slot is overwritten.
  - `write32` / `bytes`: a raw data patch.
- **Status**: `unverified` → `confirmed` (instructions at Site/End match what the upstream asm expects to
  replace) or `mismatch` (they don't; explain in Notes).
- **Evidence**: the REA Evidence ID that backs the status. **Function**: containing procedure from
  `resolve_containing_procedure`.
- Source refs are `file:line` in `reference/AoE3UnHardcoded/DLL`. The cfg key → patch dispatch is in
  `UHC.cpp:158-329` (parse) and `UHC.cpp:416-482` (apply).

## Sites

| Patch | cfg key | Site VA | End VA | Type | Source | Status | Evidence | Function |
|---|---|---|---|---|---|---|---|---|
| AILimit | `noAILimit` | 0x603B0B | 0x603C4F | replace | Limits.asm:20 | unverified | | |
| DeckLimit | `deckCardCount` | 0x7EF026 | 0x7EF030 | replace | Limits.asm:36 | unverified | | |
| PopLimit | `basePop`, `extraPop` | 0x4581F3 | 0x45823F | replace | Limits.asm:52 | unverified | | |
| TeamLimit (SP) | `enableAllTeams` | 0x7A0709 | 0x7A0709 | detour | Limits.asm:82 | unverified | | |
| TeamLimit (MP) | `enableAllTeams` | 0x77674A | 0x77674A | detour | Limits.asm:158 | unverified | | |
| FameRestriction #1 | `removeFameRestriction` | 0x80E490 | 0x80E490 | detour | Limits.asm:200 | unverified | | |
| FameRestriction #2 | `removeFameRestriction` | 0x81943D | 0x81943D | detour | Limits.asm:310 | unverified | | |
| FameRestriction HC icons | `removeFameRestriction` | 0x5C1E1F | 0x5C1E37 | replace | Limits.asm:453 | unverified | | |
| FameRestriction icon slot (Fame) | `removeFameRestriction` | 0x9A218C | — | case | Limits.asm:481 | unverified | | |
| FameRestriction icon slot (XP) | `removeFameRestriction` | 0x9A2194 | — | case | Limits.asm:485 | unverified | | |
| FameTrickle | `removeFameRestriction` | 0x51B026 | — | write32 `0x00BD62F8` | Limits.asm:497 | unverified | | |
| ConversionRestriction | `removeConversionRestriction` | 0x9D5B6C | — | bytes `90 90` | Limits.asm:512 | unverified | | |
| RegistryPath | `ignoreRegistryPath` | 0x57CB54 | 0x6420A1 | redirect | RegistryPath.asm:13 | unverified | | |
| RevBanner | `customRevolutionBanners` | 0x81A7CC | 0x81A7EC | replace | RevBanner.asm:12 | unverified | | |
| Cheat | `customCheats` | 0x551FE6 | 0x551FE6 | detour | Cheat.asm:10 | unverified | | |
| Syscall AI | `customSyscalls` | 0x7294F4 | 0x7294F4 | detour | Syscall.asm:22 | unverified | | |
| Syscall HC | `customSyscalls` | 0x5B5E08 | 0x5B5E08 | detour | Syscall.asm:27 | unverified | | |
| Syscall KB | `customSyscalls` | 0x885D14 | 0x885D14 | detour | Syscall.asm:32 | unverified | | |
| Syscall RM | `customSyscalls` | 0x60B8BF | 0x60B8BF | detour | Syscall.asm:37 | unverified | | |
| Syscall TR | `customSyscalls` | 0x988E03 | 0x988E03 | detour | Syscall.asm:42 | unverified | | |
| Syscall UI | `customSyscalls` | 0x539542 | 0x539542 | detour | Syscall.asm:47 | unverified | | |
| Syscall UI2 | `customSyscalls` | 0x53575E | 0x53575E | detour | Syscall.asm:52 | unverified | | |
| Syscall XS | `customSyscalls` | 0x6257D9 | 0x6257D9 | detour | Syscall.asm:57 | unverified | | |
| UnitCheck (shared) | farm/market/bigButton/explorer keys | 0x5EE78B | 0x5EE78B | detour | Units.asm:707 | unverified | | |
| CivCheck #1 (shared) | asian/native/bigButton/twoScout keys | 0x8D0318 | 0x8D031C | replace | Civs.asm:441 | unverified | | |
| CivCheck #2 (shared) | asian/native/bigButton/twoScout keys | 0x8DABA3 | 0x8DABA8 | replace | Civs.asm:455 | unverified | | |
| FarmAnim #1 | `enableFarmAnim` | 0x4EDA85 | 0x4EDA8B | replace | Units.asm:268 | unverified | | |
| FarmAnim #2 | `enableFarmAnim` | 0x50DE33 | 0x50DF51 | replace | Units.asm:307 | unverified | | |
| FarmAnim #3 | `enableFarmAnim` | 0x73D41A | 0x73D422 | replace | Units.asm:342 | unverified | | |
| FarmAnim #4 | `enableFarmAnim` | 0x8CEC9F | 0x8CECA4 | replace | Units.asm:365 | unverified | | |
| FarmAnim #5 | `enableFarmAnim` | 0x9DDB79 | 0x9DDB7F | replace | Units.asm:376 | unverified | | |
| FarmAnim #6 | `enableFarmAnim` | 0x4EE07F | 0x4EE085 | replace | Units.asm:391 | unverified | | |
| FarmAnim #7 | `enableFarmAnim` | 0x4EE2FE | 0x4EE304 | replace | Units.asm:399 | unverified | | |
| FarmAnim #8 | `enableFarmAnim` | 0x6A8FE1 | 0x6A8FEA | replace | Units.asm:418 | unverified | | |
| RectFarmAnim #1 | `enableRectFarmAnim` | 0x9DDD80 | 0x9DDD92 | replace | Units.asm:429 | unverified | | |
| RectFarmAnim #2 | `enableRectFarmAnim` | 0x4741F0 | 0x4741F6 | replace | Units.asm:444 | unverified | | |
| RectFarmAnim #3 | `enableRectFarmAnim` | 0x4EEDB4 | 0x4EEDBA | replace | Units.asm:465 | unverified | | |
| RectFarmAnim #4 | `enableRectFarmAnim` | 0x4EEE9E | 0x4EEEA4 | replace | Units.asm:483 | unverified | | |
| FarmRadius | `farmingRadius` | 0x9DE04D | 0x9DE053 | replace | Units.asm:507 | unverified | | |
| MarketUnits | `marketUnits` | 0x7DEF70 | 0x7DEF75 | replace | Units.asm:578 | unverified | | |
| TacticSwitching #1 | `tacticSwitching` | 0x5C161C | 0x5C1622 | replace | Units.asm:595 | unverified | | |
| TacticSwitching #2 | `tacticSwitching` | 0x6949CD | 0x6949D2 | replace | Units.asm:602 | unverified | | |
| AttackTypeIcons #1 | `attackTypeIcons` | 0x51C945 | 0x51C945 | detour | Units.asm:618 | unverified | | |
| AttackTypeIcons #2 | `attackTypeIcons` | 0x5C2287 | 0x5C2287 | detour | Units.asm:624 | unverified | | |
| AttackTypeIcons #3 | `attackTypeIcons` | 0x69B909 | 0x69B909 | detour | Units.asm:631 | unverified | | |
| ExplorerUnits name | `explorerUnits` | 0x6A012A | 0x6A0132 | replace | Units.asm:664 | unverified | | |
| ExplorerUnits KO msg | `explorerUnits` | 0x50B01F | 0x50B01F | detour | Units.asm:685 | unverified | | |
| AsianCivs #1 | `asianCivs` | 0x454F1D | 0x454F22 | replace | Civs.asm:215 | unverified | | |
| AsianCivs #2 | `asianCivs` | 0x8D6AC4 | 0x8D6AF7 | replace | Civs.asm:230 | unverified | | |
| AsianCivs #3 (wonder age-up) | `asianCivs` | 0x818284 | 0x8182A9 | replace | Civs.asm:239 | unverified | | |
| BigButton | `bigButtonCivs`, `noBigButtonBlds` | 0x461BD8 | 0x461BDE | replace | Civs.asm:255 | unverified | | |
| NativeCivs #1 | `nativeCivs` | 0x5126C1 | 0x5126C7 | replace | Civs.asm:292 | unverified | | |
| NativeCivs #2 | `nativeCivs` | 0x51271F | 0x512724 | replace | Civs.asm:300 | unverified | | |
| NativeCivs #3 | `nativeCivs` | 0x52B581 | 0x52B588 | replace | Civs.asm:315 | unverified | | |
| NativeCivs #4 | `nativeCivs` | 0x453D5E | 0x453D62 | replace | Civs.asm:322 | unverified | | |
| NativeCivs #5 | `nativeCivs` | 0x4904B5 | 0x4904BB | replace | Civs.asm:341 | unverified | | |
| NativeCivs #6 | `nativeCivs` | 0x4ECD6B | 0x4ECD73 | replace | Civs.asm:349 | unverified | | |
| NativeCivs #7 | `nativeCivs` | 0x67B0A5 | 0x67B0AD | replace | Civs.asm:358 | unverified | | |
| NativeCivs #8 | `nativeCivs` | 0x8D47C9 | 0x8D47CF | replace | Civs.asm:367 | unverified | | |
| NativeCivs #9 | `nativeCivs` | 0x8D52AF | 0x8D52B5 | replace | Civs.asm:376 | unverified | | |
| NativeCivs #10 (council age-up) | `nativeCivs` | 0x81ADEB | 0x81ADF3 | replace | Civs.asm:384 | unverified | | |
| TwoScoutCivs #1 | `twoScoutCivs` | 0x77EBB2 | 0x77EBB2 | detour | Civs.asm:399 | unverified | | |
| TwoScoutCivs #2 | `twoScoutCivs` | 0x77EF29 | 0x77EF2F | replace | Civs.asm:412 | unverified | | |
| TwoScoutCivs #3 | `twoScoutCivs` | 0x77DDD2 | 0x77DDD2 | detour | Civs.asm:421 | unverified | | |
| TwoScoutCivs #4 | `twoScoutCivs` | 0x77DFF4 | 0x77DFF4 | detour | Civs.asm:428 | unverified | | |

## Known upstream defects (do not reproduce)

- `customSyscalls` writes past its table: `TABLE_COUNT` is 11 while `Upls` is index 11
  (`UHC.h:13,27`, `UHC.inc:58`), so it clobbers BasePop/ExtraPop/DeckCardCount (`UHC.cpp:310`).
- `tacticSwitching` alone never resolves its unit IDs; UnitCheck only runs for other keys
  (`UHC.cpp:425` vs `Units.asm:718`).
- The team-limit cave skips the BString destructor (`Limits.asm:105,141`).
- Plugins' `UHCPluginMain` is called as cdecl though documented as stdcall (`UHC.cpp:385`).
- `LoadLibraryW(fd.cFileName)` loads plugins by bare filename, so directory paths don't resolve.
- `PatchCodeCave` reads `lpBuffer+1/+2` instead of `+dwSize` for rel32 branches (`Utilities.cpp:111,125`),
  which is only correct when the branch is the first stolen instruction.
- Config parser: operator-precedence bug (`Config.cpp:74`); a single `/` aborts the parse (`:69-70`).

## Known open problems (upstream issues / TODO.md)

`asianCivs` breaks politician age-up (#10); UI/train-list corruption past some limit (#8); Dojo and
Summer Palace count as a fire pit (#5); hardcoded `eso.com` host (#3, WoL patches the string to
`age3.us`); Team 3/4 visible only to the selecting player in MP lobbies.
