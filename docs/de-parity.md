# What AoE3 DE does for WoL's requests

WoL's requests ([wol-requests.md](wol-requests.md)) include many mechanics that the Definitive Edition
already has (Tier 4 is "DE parity"). This page records, for each one, how DE does it: the data
interface, its meaning, how DE's own data uses it, what the legacy exe knows today, and what a
version in this DLL would cost. The threading and loading study of DE is a separate page,
[de-architecture.md](de-architecture.md).

**Target.** `AoE3DE\AoE3DE_s.exe`, Steam build 25969874, SHA-256 `31fad98f…` (the build of
de-architecture.md; checked again on 2026-10-30). Legacy is the stock `age3y.exe` (`b1a1dab7…`).

**Rules followed.** The same as de-architecture.md:
- the DE install was only read;
- the code protection was not studied or bypassed, so encrypted functions stay unknown;
- no DE code or data is copied into this DLL or into this repository. This page paraphrases, and
  quotes only tag names, page numbers, counts and short values.

Every statement is **[O]** observed (a file, a listing, a byte search) or **[I]** inferred.

## Sources

1. **DE's official modding guide**, `AoE3DE\ModDocumentation\AoE3DE_Comprehensive_Core_Data_Guide.pdf`
   (114 pages, by Daniel Pereira, 2026-09-24). Its attribute and flag lists separate "Legacy" entries
   from "Definitive Edition" ones. Cited below as **guide pN**.
2. **DE's data**, `Game\Data\Data.bar` (BAR v6, LZ4 entries). The `.XMB` files are the same format as
   legacy's (X1/XR version 8), so `tools/xmbedit.py to-xml` decodes them. Used: `protoy`,
   `techtreey`, `civs`, `protounitcommands`, `veterancydata`, `tactics\*`, `abilities\*`.
3. **Name searches** in three binaries: the legacy exe, WoL's `uhc.dll`, and the DE exe. Each is a
   whole-word, case-insensitive match, ASCII and UTF-16, written `a/u`.
   - Legacy's XML loaders compare tag names as strings, so a name with `0/0` in the legacy exe is
     not parsed by stock legacy.
   - Short common words (Range, Snare, global) can hit by accident.
4. **DE's proto flag name table** (.data RVA 0x3354DC0, 262 names) and DE's proto parsers. Those
   parsers are plaintext, for example the one for `DodgeChance` (fn 0x101D9F0), `TrainBatchSize`
   (fn 0x102E830), `SharedBuildLimitUnit` (fn 0x102AAD0) and the `Detonation*` attributes
   (fn 0x101C840 … 0x101CD70). They were checked against the list of encrypted functions in
   de-architecture.md.
   - [O] Each is a one-tag function of `xmldataloader.cpp` that parses the text and stores the raw
     value in the proto, with no scaling or range check:
     - `DodgeChance`: a float at +0x578, so DE's 25 means 25 %;
     - `TrainBatchSize`: an int at +0x4D0;
     - `SharedBuildLimitUnit`: +0x614, and `DeadTransform`: +0x600;
     - `DetonationCommand`: +0xFEC, `DetonationHitpointThreshold`: a float at +0xFF0,
       `DetonationHitpointDecay`: a float at +0xFF4;
     - `TransformCommand`: +0xFFC.
   - [O] The listings are in `parity/fn_*.txt`.
   - The code that reads these fields was not searched for.
   - [I] Most simulation code is encrypted (de-architecture.md), so the guide and the data remain
     the spec.
   - [O] Ghidra (through REA) did not finish analysing the 59 MB exe within REA's 30-minute startup
     limit (`REA_GHIDRA_STARTUP_TIMEOUT_MS`), twice. The listings above come from
     `tools/re/pe64.py` with capstone 5.0.6.
   - [O] On 2026-11-05 a third run with a 4-hour limit was cut off too, with no result and nothing
     saved. Its log showed RTTI work at 12:49 and decompiler work until 13:39, after a start at 10:26,
     then nothing more until the limit.
   - [O] `mBuildingForwardOrientation` is in `.rdata` (RVA 0x27C6D10), with no code reference and no
     data pointer in the file (`pe64.py xrefs`, a byte scan). [I] What reads it is probably in the
     42 % of functions encrypted on disk: a finished Ghidra analysis of the file would not show it either.

**Evidence.** Everything is in `rea/evidence/aoe3de-31fad98f/parity/` (gitignored):
- `pdf/`: the guide's text per page and `inventory.tsv`, its 996 entries;
- `data/`: DE's decoded XML;
- `presence.tsv`: the name searches;
- `requests-findings.md`: the full per-request notes, with every count;
- `de-name-tables.txt`: the flag table;
- `scripts/`: the scripts behind them.

**Counts.**
- [O] The guide marks about 480 entries as added by DE. About 450 of them appear nowhere in the
  legacy exe.
- [O] Of the 484 entries it marks as legacy, 478 are in the legacy exe. This check validates the
  search.

## Summary

Sizes, following the Design rule in wol-requests.md:
- **S**: a marker unit type through `src/unittypes.*` and a hook at a known site.
- **M**: a new value in a parser legacy already has, or a cfg mapping, plus a hook.
- **L**: new XML parsing with numbers or lists, or a new subsystem.

| # | Request | What DE has | Legacy today | DLL fit |
|---|---|---|---|---|
| 2 | Shotgun spread | No spread. A shotgun is one `InstantBallistics` hit on an `InvisibleProjectile` with `DamageArea` and `DamageCap` | Reads all those tags already | **data only** (see #2); spread itself: built as `spreadAnyAccuracy` (2026-10-30) |
| 23 | Decimal population | Nothing; pop counts are integers | — | L, no DE spec |
| 24 | Negative trickles, debt | `ResourceTrickleRate` with negative amounts, clamped by `Minimum/MaximumResourceTrickleRate`; no debt rule | Has those subtypes; default min 0, max 10; a stockpile never goes below 0 | negative trickle: **data only** (lower the minimum); debt: S–M |
| 25 | Garrison-scaled trickle / ROF | Garrison scaling only on attacks (`ScaleByContainedUnits`, `ScaleByContainedUnitType`); economy scales with population (`PopulationScaling`) | `ActiveIfContainsUnits` already gates AutoGather; `ScaleByContainedUnits` is read only by attacks | gate: **data only**; scaling: M; built as `autoGatherScaleByContained` (2026-11-04) and `containedUnitsROF` (2026-11-08) |
| 26 | Buildings that gather | Modify type `UnitResource` on an `AutoRangedModify` aura (the Swedish Torp) | Built: `unitResourceAuras` | M |
| 29 | Shared / team build limits | `UseSharedBuildLimit` + `SharedBuildLimitUnit` + `SharedBuildLimitUnitTypes` (with `weight`); `TeamBuildLimit` | Absent (`TCBuildLimit` only); every check goes through one limit and one count function | flags S, lists L; all five names read as elements (2026-11-05) ; `EnableSharedBuildLimit` built (2026-11-05), the two subtypes with a name not |
| 30 | Shared settler limit | Flag `SettlerBuildLimit` + type `LogicalTypeSettlerBuildLimit` + civ `SettlerProtoName` | Absent | S–M; the three names built in `sharedBuildLimit` (2026-11-05) |
| 31 | Per-unit batch size | `TrainBatchSize`; flags `DontTrainInBatches`, `ForceBatchTrain` | Absent (global `PlayerSpecificTrainLimitPerAction` only); the batch comes from one call | flags S, size M; the three names read as elements (2026-11-05) ; the subtype `TrainBatchSize` built too (2026-11-05) |
| 32 | Economic aura per resource | Modify types `NaturalFoodGatherRate`, `TreeGatherRate`, `MineGatherRate`, `FarmingGatherRate` (by target class) | Absent (`GatherRate` only) | M |
| 33 | Crate gather priority | Nothing; auto-crate-gather by flag only | Hardcoded per civ in two places (Dutch: coin first; Ottomans and Indians: wood first) | M (a per-civ cfg order) |
| 34 | Kill bounty by techs | Subtype `KillBounty`; `Bounty resourcetype`; `BountyResourceOverride` / `BountyResourceExtra` / `BountySpecificBonus` | Absent; WoL's DLL has a `KillBounty` string | M |
| 35 | `TeamKillBounty` | Flag on the victim: its bounty goes to the killer's whole team (used by no DE unit) | Absent, but the stock payment already has a "whole team" mode | **S** |
| 36 | Cards that hit enemies / all | No tech flag. `CreatePower` → a timed power of type `EnemyEffect` / `TeamEffect` | Absent (`GeneralEffect` exists) | L |
| 37 | `NextResearchIsFree` | Flag on a building proto, set by subtype `SetNextResearchFree` | Absent; a research is paid at one site when it is queued | M |
| 38 | `CantBeSlowed` | Flags `CantBeSlowed` (immune to snares) and `CannotSnare` (its attacks do not snare) | Absent; the snare site is mapped, with both units in registers | **S**; both built as types (`cantBeSlowed`, 2026-11-05) |
| 39 | `DetonationDeath` | Flag + `DetonationProtoAction`, `DetonationCommand`, `DetonationHitpointThreshold`, `DetonationHitpointDecay` | Absent | L ; the flag's four tags built in `detonationDeath` (2026-11-05) |
| 40 | Train ahead of the queue | Proto flag `DoNotQueue` (builders and wagons); nothing for shipments | `DoNotQueue` is a tech flag, read by the Research action; legacy has a shipment queue `[hc+288h]`, whose flag `YPRecalcHCTrainQueuePointsWhenShipped` (bit 39h) is read at 0x858508. DE's shipments not checked | S–M |
| 41 | Reversible timed transform | Power `SwapUnit` with `<reversible/>` and `<activetime>` | Has `SwapUnit`, which never swaps back; `reversible` absent | M |
| 42 | Veterancy bonus | `VeterancyBonus` ranks per proto + flag `ExperienceUnit` + `veterancydata.xml` (3 ranks at 1, 2, 3 kills) | Has `ExperienceUnit` (counts kills, no effect) | L ; the two subtypes built in `veterancyBonus` (2026-11-05), the icons as chevrons of our own (2026-11-06); DE's are HUD images in its selection panel |
| 43 | `NativePreview` | Flag on native sockets: shows the settlement's units before a TP stands | Absent | L, UI; built as `nativePreview` (2026-11-08) |
| 44 | Building rotated / annexed by its builder | Nothing by the builder; in-place building upgrades (`ForceMutate`, `RevertUpgrade`). The player can turn a building while placing it (see below) | Placement rotation: stock, only the key binding is missing | by the builder: needs a design; built with JTMaston's design as `annexFacing` (2026-11-08) |
| 54 | Resource yield (Tier 5) | `yield` per `<Rate>` entry; subtypes `Yield`, `YieldSpecific`, `YieldBonus`; modify type `ResourceYield` | One `<Yield>` per action, on all resources, but trees only for the `Indians`/`SPCIndians` civs (gather tick 0x4ED0A6); no subtype | M (attribute + subtypes) |
| 56, 57 | `UseBigHugeButton` (Tier 5) | Command flag, unused in DE's data; the tech flag only on `ypPickConsulateTech` | Tech flag 27h → big slot 3 for any unit (0x462067); the "Consulate only" check not found | S if data, M for the command flag |
| 58 | "Random" cost per unit (Tier 5) | Nothing | Nothing; `CostEscalation`, `DynamicCost`, `FreeHomeCityMerc` are the nearest | M, meaning to agree |
| 62 | 5 age-up choices; politicians outside the TC (Tier 5) | XAML dialog, `uiShowAgeUpDialogInSelected` | Dialog already holds 5 (0x8191FE); the picker wants the TownCenter (0x7E6905, 0x7E803F) | S outside the TC; the 5 limit not located |

**Where to start** [I] (historical, 2026-10-30: every item of this table has since been built, the DE subtypes
`SharedBuildLimitUnit` and `AddSharedBuildLimitUnitType` of #29 excepted; see wol-requests.md):
- **S:** #38 (the snare code is mapped), #35 (the payment already has a team mode), #30, and the flag parts of #29 and #31.
- **M:** #41, #37, #33 and #26.
- **Data only, today:** #2, the negative trickle of #24, and the garrison gate of #25.

The legacy sites are in "What legacy does today" below and in engine-symbols.md, "DE parity sites".

## The requests

### #2 Shotgun spread

- [O] DE has no `MaxSpread`, `SpreadFactor` or `NumberProjectiles`: not in the guide, not in DE's
  data, not in the DE exe. The only related tag is `DisplayedNumberProjectiles` (guide p26), which
  only sets the number the UI shows (34 actions; 7 on the Cannon's `CaseShotAttack`).
- [O] DE's shotguns are one hit with area damage: `InvisibleProjectile` + `InstantBallistics` +
  `DamageArea` + `DamageCap`. The Cannon's `CaseShotAttack` has damage 20, area 6, cap 40; the
  saloon outlaw rifleman's buckshot has 3, area 2, cap 18.
- [O] Legacy reads `DamageArea`, `DamageCap` and `InstantBallistics` (legacy 1/1, 1/1, 0/1), and
  the stock data has `InvisibleProjectile`.
- [O] WoL's tactics carry `maxspread` 644 times, `spreadfactor` 647 times and `numberprojectiles`
  94 times. Almost all are 5 and 0.25, which are exactly the stock miss-offset constants
  (engine-symbols.md, "Projectile accuracy and spread"). The shotguns differ: spread factor
  1.5–1.8, maxspread 3–5, 3–6 projectiles. The other outliers belong to artillery and the
  Schwarzlose machine gun: spread factor up to 7.0, maxspread 10, 12 projectiles.
- [I] **So the DE way is data only in legacy:** give each shotgun action an area hit with a damage
  cap, as DE does. Option (c) or (d) of question Q1 would have no DE name to follow; WoL's own
  spelling is already in their data.
- **Built (2026-10-30)** with WoL's spelling, as JTMaston chose: `spreadAnyAccuracy` reads
  `MaxSpread` and `SpreadFactor` and scatters every shot of marked units
  ([wol-requests.md](wol-requests.md), #2).

### #23 Decimal population

- [O] Nothing in DE. All 710 `PopulationCount` values and all 113 `PopulationCount` effects are
  integers.
- [O] DE's only refinements are on garrisons (`Contain` `popDiscount` / `popException`, guide p6)
  and an undocumented tech flag `DEAllowZeroPopCount` (2 techs).
- [I] A legacy version has no DE spec to follow and needs the pop storage (int or float), the train
  check and the UI text mapped first.

### #24 Negative resource trickles, with debt

- [O] `ResourceTrickleRate` (target Player, `resource`) is a legacy subtype, clamped by
  `MinimumResourceTrickleRate` and `MaximumResourceTrickleRate` (guide p77–78). DE's data uses
  negative amounts only to cancel a consulate trickle (4 effects, e.g. −0.80 Gold).
- [O] DE adds trickle sources, all absent from legacy: `DamageTimeoutTrickle` (p100), Data2
  `TrickleByUnitType` (p112) and the effect `AddTrickleByResource` (p69).
- [O] Nothing in the guide or the data mentions debt or a negative stockpile.
- [I] A data test may already answer part of it: set `MinimumResourceTrickleRate` below 0 and see
  whether the stockpile goes down. See "Legacy findings" below.
- Built as [`resourceDebt`](modding-guide.md#resourcedebt) (2026-11-04; reworked on 2026-11-05 to JTMaston's rule: only trickles and the rates of units go below 0).

### #25 Garrison-scaled attack, extended to trickles or rate of fire

- [O] Legacy has `ScaleByContainedUnits`, `ActiveIfContainsUnits` and `DamageFactorCap`. DE adds
  `ScaleByContainedUnitType`, a rate per garrisoned type (guide p26), and the subtype
  `GarrisonBonusDamage` (7 tech effects).
- [O] In DE's data **all of these are on attacks**: `ScaleByContainedUnits` on 10 actions,
  `ActiveIfContainsUnits` on 9, `ScaleByContainedUnitType` on 14, `DamageFactorCap` on 24.
- [O] DE scales economy actions with a count through `PopulationScaling` on AutoGather and
  Maintain: the rate follows the population, or the unit count, of a type (guide p29; capitol,
  sejm). There is also `PopulationScalingCap` and the dance kind `AutoGathering`.
- [O] WoL's `barn.tactics` already puts `ActiveIfContainsUnits` on an AutoGather action.
- [I] If legacy honours that flag on AutoGather, a garrison-gated trickle already works; scaling
  it by the count would be new.
- Built as [`autoGatherScaleByContained`](modding-guide.md#autogatherscalebycontained) (2026-11-04, AutoGather) and [`containedUnitsROF`](modding-guide.md#containedunitsrof) (2026-11-08, rate of fire with `target="ROF"`).

### #26 Buildings that gather

- [O] DE's Torp gathers through auras: an `AutoRangedModify` with modify type `UnitResource`
  drains nearby resources at a linear rate set by `ModifyAmount` (guide p35): mines 0.27, trees 0.05 on up
  to 5 trees (`ModifyTargetLimit`), hunts 0.42, berries 0.3, crates 4.0. 19 such actions
  (Torp, folwark, hacienda). The flag `ShowUnitResourceActionRates` shows the rates.
- [O] DE's `DisplayRange` + `DisplayedRange` (a decal on selection; `deTorp` has 5.9) are built as `displayedRange`
  (2026-11-06), with a ring of our own, centred on the unit.
- [O] Built as `unitResourceAuras` (2026-11-04), with the rest of the Torp's tags on 2026-11-06: `IncludeGaia`,
  `DeadExclusive`, `DoNotIgnoreDead`, `SingleUnit`, `ForbidUnitType`, `ModifyRate`, `ShowUnitResourceActionRates`.
  DE's marker `torpgatherpower.xml` is a ring model plus a particle on the bone `HITPOINTBAR`; ours is `aura_<colour>.xml`,
  own art.
- [O] WoL's `sawmill.tactics` already contains DE's `AreaGatherTree` aura; stock legacy drops
  those tags (`UnitResource` 0/0), so only its AutoGather works.
- [I] The same method as `buildingWorkRateAuras` applies: make `UnitResource` a valid modify type
  and give it its effect (drain the target, pay the owner).

### #29 Shared and team build limits

- [O] Proto flag `UseSharedBuildLimit` (guide p17) with:
  - `SharedBuildLimitUnit`: the proto whose limit applies;
  - `SharedBuildLimitUnitTypes`: the types that count toward it, each with an optional `weight`
    (p8).
- [O] Proto flag `TeamBuildLimit`: count the units of the whole team (p20).
- [O] Subtypes: `EnableSharedBuildLimit`, `SharedBuildLimitUnit`, `AddSharedBuildLimitUnitType`
  (p89).
- [O] DE data: 69 protos have the flag. Livestock (`Cow` 20 for `AbstractBovine`, `Sheep` 30),
  wagons (`OutpostWagon` counts against `Outpost`), the Asian wonders. `weight` only on the Sami
  reindeer (a herd counts 4). `TeamBuildLimit` is on no proto.
- [O] DE's parser for `SharedBuildLimitUnit` is plaintext (fn 0x102AAD0).
- [I] The flags fit marker types. The lists (`SharedBuildLimitUnitTypes`, `weight`) need proto
  parsing or a cfg mapping.
- Built as [`sharedBuildLimit`](modding-guide.md#sharedbuildlimit) (2026-11-05), with DE's tag names and `EnableSharedBuildLimit`; `SharedBuildLimitUnit` and `AddSharedBuildLimitUnitType` are not built.

### #30 Settler build limit shared by a unit type

- [O] DE's design is the request under other names (guide p17, p46, p90):
  - the proto flag `SettlerBuildLimit` makes a unit use the limit of the civ's settler;
  - every unit of type `LogicalTypeSettlerBuildLimit` counts toward it;
  - the civ tag `SettlerProtoName` names that settler.
- [O] 17 protos have the flag (Settler, Coureur, `ypSettlerAsian`, `deSettlerAfrican`…), and 19
  have the type. 26 civs set `SettlerProtoName`. The Coureur keeps its own `BuildLimit` 80, which
  the flag overrides.
- [I] For this DLL:
  - `LogicalTypeSettlerBuildLimit` can be an abstract type registered by `unittypes.*`;
  - the flag can be a marker;
  - `SettlerProtoName` can be read from `civs.xml` the way `civFirstTC` reads `<firstTC>`.
- Built in [`sharedBuildLimit`](modding-guide.md#sharedbuildlimit) (2026-11-05), DE's three names included.

### #31 Per-unit military batch limit

- [O] Proto attribute `TrainBatchSize` replaces the default batch of 5 (guide p9). Subtype
  `TrainBatchSize` (p95). Flags:
  - `DontTrainInBatches`: batch of 1;
  - `ForceBatchTrain`: batch training for multiple-block trains and banner armies (p17–18).
- [O] DE data: `TrainBatchSize` 10 on `NatClubman` and `deInsurgente`; `DontTrainInBatches` on 9
  protos (Cannon, Minuteman…).
- [O] DE's parser is plaintext (fn 0x102E830). Legacy has only the player-wide
  `PlayerSpecificTrainLimitPerAction`.
- Built as [`trainBatchSize`](modding-guide.md#trainbatchsize) (2026-11-05), with the subtype and both flags read (`ForceBatchTrain` with no effect).

### #32 Economic aura per resource

- [O] DE adds aura modify types by target class (guide p35):
  - `NaturalFoodGatherRate`, `TreeGatherRate` and `MineGatherRate`: 14 actions each, on outpost-like
    buildings;
  - `FarmingGatherRate`;
  - `ResourceGatherRate` / `ResourceYield`, which act on the gather site rather than on the
    gatherer.
- [I] DE splits by what is gathered, not by resource. A plantation is not a `MineGatherRate`
  target unless it is a mined resource; this is the plantation question Q4 again.
- Built as [`resourceGatherAuras`](modding-guide.md#resourcegatherauras) (2026-11-04): DE's four target classes and one modify type per resource.

### #33 Crate gather priority

- [O] DE has no priority interface: only `DrawnToCrates` (gather nearby crates automatically,
  guide p17) and the subtype `EnableAutoCrateGather`.
- [O] DE's strings name crate types (`AbstractCoinCrate`, `AbstractFoodCrate`,
  `AbstractWoodCrate`) and log `doAutoCrateGather`. [I] DE probably still orders crates in code.
- Built as [`cratePriority`](modding-guide.md#cratepriority) (2026-11-05), one cfg line per civ.

### #34 Kill bounty modifiable by techs

- [O] Proto `Bounty` takes `resourcetype` in DE (guide p5): 47 bounty entries pay XP, Gold, Food or
  Wood.
- [O] Tech subtypes:
  - `KillBounty` on a proto (p87): 44 effects, e.g. ×0.9 on `Unit`, 14 on `deMinuteman`;
  - `BountyResourceOverride`: kills of a type also pay another resource, optionally as a share of
    the XP bounty (p87, p107);
  - `BountyResourceExtra`, with a priority (p111);
  - `BountySpecificBonus` (p99).
- [O] Legacy has the aura modify type `Bounty` (on the torii gates and the Aztec war chief; DE adds
  it to its fort). WoL's data uses
  `subtype='Bounty'` 10 times. WoL's DLL contains the string `KillBounty`. [I] It may already
  parse that subtype.
- Built as [`killBountyTechs` and `resourceBounty`](modding-guide.md#killbountytechs-resourcebounty-and-teamkillbounty) (2026-11-05); not `BountyResourceOverride`, as agreed.

### #35 `TeamKillBounty`

- [O] A flag on the **victim**: the bounty for killing it goes to the killer's whole team (guide
  p20). It is in DE's flag table but on no DE proto.
- [I] A marker type and one hook where the bounty is paid. Unknown in DE: whether each teammate
  gets the full amount.
- Built as [`teamKillBounty`](modding-guide.md#killbountytechs-resourcebounty-and-teamkillbounty) (2026-11-05): each teammate gets the full amount.

### #36 Cards that target enemies or all players

- [O] `HCTargetEnemy` and `HCTargetAll` exist nowhere (guide, DE data, all three binaries).
- [O] DE's route is the effect `CreatePower` (guide p67), which starts a timed power whose type
  decides who is hit: `GeneralEffect` (legacy), `TeamEffect` or `EnemyEffect` (DE, in
  `powers.xml`).
  - `DESPCScorchedEarth` gives every enemy ×0.8 gather rates for 60 s.
  - `DEMariachiShadow` gives the team +10 % speed and ×5 `BuildingWorkRate` for 30 s.
- [O] DE also adds direct subtypes: `EnemyShipmentDelay` and `BlockRandomCard` (p102).
- [I] A DE-compatible design is `CreatePower` plus an enemy or team target set for legacy's
  `GeneralEffect`. That is larger than a tech flag. A tech flag would be WoL's own interface.
- Built as [`hcTargetTechs`](modding-guide.md#hctargettechs) (2026-11-05), WoL's tech flags, not `CreatePower`.

### #37 `NextResearchIsFree`

- [O] Flag on a building proto: the next research queued there is free (guide p18). The subtype
  `SetNextResearchFree` sets it (p90).
- [O] DE data: no proto has it in XML; 6 techs set it (e.g. on the Arsenal, with an Arsenal
  wagon).
- [I] Per proto or per building, and cleared after one use, are not documented: the code that reads
  the flag is the research path.
- Built as [`nextResearchFree`](modding-guide.md#nextresearchfree) (2026-11-05), also under DE's subtype name `SetNextResearchFree`.

### #38 `CantBeSlowed`

- [O] Two proto flags (guide p17, p19):
  - `CantBeSlowed`: the unit ignores snares (`TargetSpeedBoost`);
  - `CannotSnare`: the unit's own attacks no longer snare.
- [O] Powers can switch either on for a while (`<effect type="CantBeSlowed">`).
- [O] DE data: `CantBeSlowed` on 4 protos (`deChasqui`, `deTank`…). As power effects,
  `CantBeSlowed` appears in 1 power and `CannotSnare` in 2.
- [O] Legacy creates the snare at one known site: 0x4DD1DE → 0x4DD22D (engine-symbols.md, "Snare and
  group movement").
- [I] Both flags are markers, with one test at that site. This is the cheapest item.
- Built as [`cantBeSlowed`](modding-guide.md#cantbeslowed) (2026-11-05), both flags as unit types.

### #39 `DetonationDeath`

- [O] The flag and four attributes (guide p10, p20):
  - `DetonationDeath`: the unit fires a protoaction when it dies;
  - `DetonationProtoAction`: that protoaction;
  - `DetonationCommand`: a command that replaces delete;
  - `DetonationHitpointThreshold`: the HP ratio at which the command fires by itself;
  - `DetonationHitpointDecay`: HP decay after the threshold.
- [O] DE data: `deDepot` (110 Siege in 14 m, ×9 against buildings, threshold 0.25) and
  `deMercBattleship`, whose card sets flag id 241 through `ProtoUnitFlag`.
- [O] DE's parsers for the four attributes are plaintext (fn 0x101C840, 0x101CAF0, 0x101CD70).
- [O] Legacy already has the tactics flag `SelfDestruct`.
- Built as [`detonationDeath`](modding-guide.md#detonationdeath) (2026-11-05), the four attributes.

### #40 Train a unit ahead of the queue

- [O] DE's proto flag `DoNotQueue`: the unit is not held by the building's queue (guide p18).
  19 protos have it: 17 builders or wagons, and the two Yoruba riders (cavalry with no build
  action). Legacy has a tech flag of the same name, which WoL uses on 16 techs, read by the Research action's
  slot 58h, 0x9E5EAD, only under the world byte `[world+6910h]`.
- [I] Nothing found in DE's guide orders shipments; DE's code was not checked.
- Built as [`doNotQueue`](modding-guide.md#donotqueue) (units 2026-11-05, shipments 2026-11-06).

### #41 Reversible transformation on a timer

- [O] DE's power type `SwapUnit` takes `<activetime>` and `<reversible/>`, plus `<mutate/>`, `<global/>`
  and `<forcefullhp/>`. `deScanianResistance` turns villagers into Minutemen for 90 s.
- [O] Legacy has `SwapUnit` (WoL has 5 such powers, all one way). `reversible` and `forcefullhp` are
  absent (0/0).
- [I] The smallest port is `<reversible/>` on legacy's own `SwapUnit`. It depends on what legacy does
  when `activetime` ends.
- Built as [`transformSpan`](modding-guide.md#transformspan) (2026-11-05), JTMaston's `transformspan` on `TransformUnit`, not DE's `SwapUnit`.

### #42 Veterancy bonus

- [O] Proto `VeterancyBonus` with three `Rank` children of `VeterancyModify modifyType=…`
  multipliers, which need the flag `ExperienceUnit` (guide p10–11). Subtypes `VeterancyEnable` and
  `VeterancyBonus` (p97).
- [O] 36 DE protos have it. Typical: MaxHP and Damage ×1.15 / 1.30 / 1.45, ROF ×0.9 / 0.8 / 0.7,
  `RangeAbsolute` +1 / +2.
- [O] `Data\veterancydata.xml` defines the ranks: `numkills` 1, 2 and 3, with an icon (bronze,
  silver, gold), a string and a colour. [I] What counts as one kill is not established.
- [O] Legacy has `ExperienceUnit`, which counts kills with no effect (guide p16).
- Built as [`veterancyBonus`](modding-guide.md#veterancybonus) (2026-11-05), with DE's two subtypes; rank marks of our own (2026-11-06).
- 2026-11-11: rows by unit type (`veterancy.xml`, so the 36 protos need no copy), `op="add"` rows (DE's `RangeAbsolute`
  has no legacy stat: legacy has no `Range` modifier), rank names and colours as in `veterancydata.xml`, and five marks.

### #43 `NativePreview`

- [O] A flag on the 45 native sockets: while no trading post stands, it enables a preview of the
  native settlement (guide p21). What the preview shows is not described. It works with DE's socket-build command chain
  (`SocketBuildProtoUnit`, `SocketBuildCommandID`, `SocketSubCivAlliance`), all absent from legacy.
- Built in legacy on 2026-11-08 as `nativePreview` ([modding guide](modding-guide.md#nativepreview)): the tag is read
  with `tagged`; the preview is the Trading Post's own panel, filtered by the native's age tech, read-only.

### #44 Building rotated or annexed by its builder

- [O] DE has no such tag. The nearest DE mechanisms are socket buildings (`SocketBuildProtoUnit`) and
  in-place upgrades through commands (`Transform` + `ForceMutate`, `RevertUpgrade`; the folwark).
- [O] **Rotation by the player, at placement** (found 2026-11-05, after this page said "nothing"): DE's
  `Startup\gamey.con` has `map("shift-mousez", "building", "uiWheelRotatePlacedUnit")`, and the exe has the field name
  `mBuildingForwardOrientation` beside `mBuildingPosition`. Nothing turns a standing building. This rests on the keymap
  and strings: the code was not read with REA, whose analysis of the DE exe does not finish.
- [O] **Legacy has all of it** (2026-11-06): the same console command, the forward direction in the build command and
  `NotRotateable`. Only the key binding is missing: modding guide, "Rotating a building while placing it".

## Tier 5 questions (2026-11-12)

JTMaston's second list ([wol-requests.md](wol-requests.md#tier-5-jtmastons-second-list-2026-11-12)) has four items
that depend on DE. **DE** was read through its guide, its decoded data and `tools/re/pe64.py` (strings and xrefs). DE's
code that uses these names was not reached: their strings have no code xref, and most of DE's code is encrypted on disk
(de-architecture.md). **Legacy** was read with capstone, a linear sweep of `.text` (listings in
`rea/evidence/age3y-b1a1dab7/tier5-de-parity-cs.txt`), then with REA (Ghidra 12.1.4, snapshot `age3y-b1a1dab7-rea68`),
bundle `rea/evidence/age3y-b1a1dab7/tier5-de-parity-20261112.json`:
- `ev_3d68330a…` pseudocode of the gather tick FUN_004ECD87 (#54);
- `ev_8c0b34fa…` 0x4ED10A is in FUN_004ECD87; `ev_3f262aea…` Ghidra files the cold chunk 0x6A8AEA..0x6A8CEC (with
  0x6A8B11 and 0x6A8B27) under FUN_0068DD0B, a boundary artifact: only the gather tick jumps there;
- `ev_db72e459…` 0x462067 is in the command panel refresh FUN_0046188E (#56);
- `ev_7605c6e9…` pseudocode of the politician list builder FUN_00818EE5, and `ev_727c1786…` 0x8191FE in it (#62);
- `ev_057d53a7…` Ghidra has no function at 0x7E6905 (the age-up picker is read in capstone only);
- 2026-11-13, bundle `tier5-56-62-20261113.json`: `ev_90be3ff9…` assembly of 0x4C6968 (no proto-list test),
  `ev_c4c40df9…` pseudocode of the command panel refresh FUN_0046188E (the slot drawing, slot 3 = `[ui+2FCh]`).

**[?]** marks what is unknown.

### #54 Resource yield, "unlocked as in DE"

**What yield is.** It sets how long a resource lasts: the gatherer gets the full amount, and the target loses
amount / yield. With 1.5 a tree lasts 1.5 times longer for the same income.

**DE.**
- [O] DE has four interfaces. Pages are the guide's; every name is also in the exe's strings (`pe64.py strings`):
  - a `yield` attribute on any `<Rate>` entry of a gather action, so the yield is per target type:
    `<Rate type='Tree' yield='1.2'>0.5</Rate>` (p23, "from the original AoE3DE release onwards");
  - the Data subtype `Yield` (`action`, `unittype`, relativity) and `YieldSpecific` (which adds `resource`), both under
    the guide's "Definitive Edition" heading (p85–86, p106);
  - the player subtype `YieldBonus`, a global multiplier on all gathering (p103), and the trigger
    `trPlayerSetGlobalYield`;
  - the modify type `ResourceYield` for an aura, applied to the gather site (p35). No DE tactics file uses it.
- [O] The guide calls the legacy tactics tag `<Yield>` (one value per action) "deprecated from the AoE3DE original
  release onwards", and says that legacy hardcodes it "to be only applied for wood gathering" for Indian villagers (p24).
- [O] DE's data:
  - no `<Yield>` tag is left, and `yield=` is on 8 `deFurTrade` rate entries in `protoy`;
  - `techtreey` has 138 `subtype="Yield"` effects: 102 on `Gather` (by `unittype`: `Gold` 21,
    `AbstractMountainMonastery` 18, `Tree` 13, `AbstractMine` 13, `Huntable` 12, `deFishingHole` 12, berry bushes, ...),
    the others on AutoGather actions;
  - DE's `ypSettlerIndian` has no yield any more. The bonus moved into techs such as `ypMarketGangsaw` (`Yield` 1.5
    on `Tree`).

**Legacy.**
- [O] Legacy has one float per action, `[protoaction+50h]`. It is read from `<Yield>` in tactics and in the `protoy`
  `<ProtoAction>` overrides (handler 0x5FE6E2, from the name compare at 0x5F9D91 with string 0xBCA8A0; 1.0 when the
  text does not parse).
  - [I] The 1.0 written at 0x91A3CB, in what looks like the action's constructor, is the default when the tag is absent.
- [O] Legacy has no Data subtype for it. The only other `Yield` string (0xBCD8C8) is a tag of the second `<Unit>` tag
  table (0x51D920). The subtype names in `[db+3500h]` have no such entry. Nothing reads a `yield` attribute on `<Rate>`.
- [O] **The hardcode** is in the gather tick FUN_004ECD87, at the take (0x4ED05B..0x4ED124, `ev_3d68330a…`):
  - a target whose proto has flag 24h is not drained at all (0x4ED05F);
  - a yield below 1e-6 takes another path (0x6A8B11: 0x514AA1 with 0, 0). [?] What that path does was not read.
  - When the first civ of the gatherer's player (`[[action+10h]+44h]`) is `Indians` or `SPCIndians`, the yield counts
    only if the target has the abstract type `Tree`; any other target uses 1.0 (0x6A8B27..0x6A8B3D).
    - The civ IDs are cached at `[0xC6FB48]` / `[0xC6FB4C]` by 0x8D03C3 / 0x8D0433.
    - `Tree` is abstract index 12h, registered at 0x51A8B5, and tested with `push 12h / call 44CAC4h` at 0x6A8B2E.
  - Every other civ: the yield applies to **every resource** that action gathers (0x4ED10A).
  - Then the target loses amount / yield (`fdiv` at 0x4ED115; the inventory add 0x49A5E6 at 0x4ED124). The
    player's payment (0x4ED13A onward) does not use the yield.
- [O] So the stock "Indian wood" rule tests the civ, not the unit, and this is the only read of the yield in the gather
  tick.
- [O] WoL already uses `<Yield>`: `WOLJornalero` 2.0 (twice) and `JavaneseLabourer` 1.5, each placed right after
  `<Rate type="Tree">`. [I] It reads as if meant for trees only. In legacy it applies to everything that action
  gathers, except for a player whose civ is `Indians`, who gets it on trees only.

**What a key needs** (`yieldTargets` is a working name):
- the `yield` attribute on `<Rate>`: a side table per (tactics action, rate index), filled by a hook in the stock `Rate`
  handler (`AddActionTagHandler` does not apply, because `Rate` is a tag stock already knows);
- the gather tick: a hook at 0x4ED0A6 (up to 0x4ED10A) that finds the rate entry the target matched (the rule of the
  rate lookup 0x487C45). It uses that entry's yield when set, else the action's `<Yield>` with the stock rules;
- the Data subtypes `Yield` and `YieldSpecific` through `AddTechActionSubtype`, applied and unapplied as `WorkRate`;
- optional: `YieldBonus` (one float per player, a factor in the same hook), `ResourceYield` as a modify type
  (`AddModifyType`, read on the target in the same hook), and an option that drops the civ rule;
- hot path: the gather tick runs for every gatherer, so A/B it with `perfprobe.py`.
- **Size:** M for the attribute and the hook, M for the two subtypes, S each for `ResourceYield` and `YieldBonus` on
  top.
- **Answer to the question:** no, legacy is not "unlocked". It has one yield per action, applied to all resources
  (trees only for the two Indian civs), and no tech can change it.

### #58 A "random" cost per unit

- [O] DE has no proto attribute for a random or varying cost. Bounded searches found none: DE's strings (`random`,
  `cost`, `price`, `variance`, `variation`), the guide's 996 entries, and DE's decoded `protoy`, `techtreey`, `civs` and
  `protounitcommands`.
- [O] What DE and legacy have near it:
  - `CostEscalation` (legacy proto tag, p3): the cost grows with every instance alive or queued. #46 already made it a
    tech target (`costEscalationTechs`);
  - `DynamicCost` (legacy tech flag, p51): a tech's cost scales with the number of enemy units. DE adds
    `DynamicCostKBStat` and `KBStatFactorCap` (p50);
  - `FreeHomeCityMerc` (legacy subtype, p82–83): a card ships a random count, between amount/2 and amount, of one
    random proto of a type;
  - `FreeHomeCityUnitRandom` (DE, p89; 29 effects, the outlaw and mercenary cards) ships `amount` units picked at
    random from a type or a list. `SendRandomCard` and `BlockRandomCard` are DE too (p100, p102). Legacy has none of
    these three;
  - `RandomTech` is in WoL's DLL (`BUHCRandomTechEffect`), not in stock legacy.
- [?] What the request means. Readings to put to JTMaston:
  1. each unit trained costs a random amount in a range set on its proto (for example
     `<RandomCost resourcetype="Gold" min="80" max="120"/>`), drawn when it is queued;
  2. a cost per player, drawn once at the start of the game;
  3. a weight per unit for random shipments (how much of a `FreeHomeCityUnitRandom` amount one unit uses).
- **What a key needs** (reading 1): the Train action keeps a cost record per queued entry (`+8`, engine-symbols.md,
  "Train action"). So the hook goes where the cost is computed for the payment, and the refund uses the copied record.
  The draw must use the synced random (0x422648) so multiplayer stays in step, and the UI shows the base cost or the
  range. **Size:** M. Readings 2 and 3: S–M. There is no DE behaviour to copy.

### #56, #57 `UseBigHugeButton`

- [O] DE: `UseBigHugeButton` is a `protounitcommands.xml` flag (guide p40, "Definitive Edition"): a command takes "the
  Big Huge/Consulate option button".
  - No DE command uses it. DE's only tech with the legacy tech flag `YPUseBigHugeButton` is `ypPickConsulateTech`, as
    in legacy.
  - DE's other button flags there: `UseBigButton`, `UseBigButton2`/`3`, `UseMediumButton`/`2`/`3`, and the tech flag
    `DEUseMediumButton`.
  - [?] Whether DE lifted a restriction of the tech flag: DE's code was not reached (`UseBigHugeButton` has no code
    xref in `pe64.py`).
- [O] Legacy: the tech flag `YPUseBigHugeButton` is bit 27h (its parser returns 27h at 0x6B1298).
  - In the tech layout of the command panel (FUN_0046188E, `ev_db72e459…`) four flags send a tech to a big-button slot
    instead of the grid (0x461F90..0x4620A7; slots set at 0x69660D..0x696639): 1Bh `NativeDance` slot 0, 24h slot 1
    and 25h slot 2 (the `YPUseBigButton2`/`3` flags), 27h slot 3.
  - The loop 0x4626D2 → 0x6972E0 draws the slots; slot 3 is the gadget `[ui+2FCh]`.
- [O] No proto, civ or culture test was found on that path: a tech with the flag goes to slot 3 on whatever unit lists
  it.
- [?] Where "Consulate only" comes from was not found. The candidates are the UI layout (which panels define the slot-3
  gadget), the click (`ypPickConsulateTech` opens the Consulate's choice), and the Consulate's own panel. One test in
  game would decide it: the flag on a WoL tech of another building.
- **What a key needs:** if that test shows the button working elsewhere, #56 is data only. Otherwise a hook at the
  failing check. For #57 (DE's command flag), the command collection (0x4C5A50) sends a tagged command to a big-button
  slot, and its click sends the command. **Size:** S if data only, M for the command flag.
- **Result (2026-11-13, in game):** data only. `HuntingDogs` with the flag showed as the big button on a
  Market (Ethiopians in a scenario, Dutch in a skirmish), and a click researched it. "Consulate only" is the
  layout: the gadget `commandpanel2-bighugebutton` (slot 3, bound at 0x9969C7) lies over the command grid in
  WoL's `uicommandpanelnew*.xml`, so the building's other buttons are hidden while it shows; moving it in those
  files is enough ([modding guide](modding-guide.md#a-big-huge-button-on-any-building)). #57 not built: legacy's
  `protounitcommands.xml` has no flags, so it needs a loader tag and a command path into slot 3 (M).

### #62 Five age-up choices; politicians outside the Town Center

- [O] DE has:
  - `uiPoliticianUI(%d, %d, %s, %s)`, one argument more than legacy's;
  - `uiShowAgeUpDialogInSelected` and a XAML dialog (`uipoliticiandlg.xaml`);
  - the civ tag `PoliticianBaseStringID` (p46), and the tech flags `FakeAgeUpgrade` and `DEAllegianceUnlock`
    (p53–54).
  - [?] DE's limit on choices, and the code that opens the dialog from another building, were not reached.
- [O] Legacy's European dialog already holds five:
  - gadgets `PoliticianDlg-Size1Politicians` .. `Size5Politicians`, bound at 0x818ABE..0x818B86 into
    `[dlg+224h]`..`[dlg+234h]`, and five politician slots (loop to 5 at 0x818DBA);
  - the list builder FUN_00818EE5 (`ev_7605c6e9…`) walks the player's politician list. It keeps each entry of the next
    age that the selected unit can research (0x4C6968, the command panel's "can research here" test) and stops at
    five (0x8191FE).
  - [?] So the limit JTMaston meets is elsewhere: the Asian and native dialogs, the home city's politician unlocks, or
    WoL's data. To ask: which civ and which age shows fewer.
- [O] Legacy outside the Town Center:
  - the command panel builds the age-up button `uiPoliticianUI(%d, %d, %s)` (string 0xC31A78) for a tech with flag 4
    `AgeUpgrade` (0x461EF5 → 0x6962B5 → 0x6962E5) or flag 1Ch `RevoltTech` (0x461F4A → 0x69642B → 0x69646B), on any
    unit;
  - but the picker that opens the dialog requires the selected unit's proto to be the TownCenter (`[db+5E08h]`) for a
    civ that is not Asian, or the abstract type 16h for an Asian civ (0x454ED7(player, 1) is isAsianCiv, not a native
    test; corrected 2026-11-13). The tests are
    at 0x7E68F8..0x7E6920 and 0x7E8025..0x7E8057 (engine-symbols.md lists them under "Out of scope").
- **What a key needs:** a cfg list of protos, or a proto tag, accepted at those two compares; the list builder already
  filters by the selected unit. **Size:** S for outside the Town Center. For more than five, [?] until the limit is
  located.
- **Result (2026-11-13, in game):**
  - Fewer than five: WoL's `uipoliticianEuropeandlg.xml` (as the stock one) has four places; the Asian and native
    dialogs have five. A fifth politician with four places crashes at 0x81A80C (a null place gadget). With a fifth
    place added to that file, the Dutch with six obtainable politicians saw five: data only
    ([modding guide](modding-guide.md#five-politicians-in-the-european-age-up)).
    The crash itself is the null name gadget `Poli4Name`, dereferenced at 0x81A80C by FUN_0081A2B8 (`ev_3a5f7096…`);
    [`politicianPlacesFix`](bug-fixes.md#politicianplacesfix) ends the list at the last place the layout has (2026-11-13).
  - More than five: the dialog keeps five entries (`[dlg+270h]`, `+284h`, `+2ACh`, count `+26Ch` compared with 5 at
    0x8191FE / 0x81A82A) and binds five places (0x818DBA): it needs a larger dialog object. Not built.
  - The list builder does **not** filter by the unit's proto: 0x4C6968 checks status, flags and prerequisites only
    (`ev_90be3ff9…`). Built: [`ageUpBuildings`](modding-guide.md#ageupbuildings), which widens the TownCenter
    compare and, on a listed building, keeps the politicians its proto lists.

## What legacy does today

Read with REA (Ghidra) in the stock exe. The addresses, registers and Evidence IDs are in
engine-symbols.md, "DE parity sites". All of this is static reading; nothing was checked in game.

- **#38 snare.** [O] The snare is created in one place, FUN_0048FA07's cold chunk. At 0x4DD201,
  before any argument is pushed:
  - ESI is the target;
  - `[ebp+10h]` is the attacker unit.

  [I] A marker test on either unit, then a jump to 0x48FA49, skips the snare. `damageOverTime`'s
  `AttachSnare` calls the modifier itself, so it needs its own test.
- **#34, #35 bounty.**
  - [O] `<Bounty>` is a float at `[proto+168h]`. The killing hit pays it from TakeDamage
    (0x49B73C) through FUN_0049BD52 and FUN_0049BDC0.
  - [O] FUN_0049BDC0 already pays **every member of the team the full amount** when it is given
    player −1.
  - [I] `TeamKillBounty` is then one test at 0x49BDAB that passes −1. Each teammate would get the
    full bounty; DE's split is not documented.
  - [I] A tech-scaled bounty (`KillBounty`) fits the value getter 0x4D4DC5, which already multiplies
    in the killer's `Bounty` aura.
- **#24 trickles.**
  - [O] The rate, minimum and maximum are per player and per resource, with defaults 0, 0 and 10.0.
  - [O] Every 2 s the rate is clamped to [min, max], then added.
  - [O] The stockpile is clamped at 0 on every add.
  - [I] So a negative `ResourceTrickleRate` alone does nothing (the minimum 0 clamps it). With
    `MinimumResourceTrickleRate` also lowered below 0, the stockpile **drains, but stops at 0**. That
    much is data only. A debt needs a hook at the floor (0x49A9BF).
- **#25 garrison.** [O] `ActiveIfContainsUnits` is tested by the AutoGather update itself:
  - with no unit inside, the action gathers nothing that update;
  - with any unit inside, it gathers at its full rate.

  [O] `ScaleByContainedUnits` is read only by the projectile launch and the stat panel.

  [I] So WoL's `barn.tactics` works as a garrison gate in stock. Scaling a trickle by the count is new
  code in the AutoGather rate.
- **#41 SwapUnit.**
  - [O] With `mutate` the swap is the in-place transform (unit ID and HP ratio kept). Without it, the
    unit is destroyed and a new one is created.
  - [O] The parser has no `reversible`, and the runtime keeps neither the old protos nor the new IDs.
  - [I, strong] Legacy never swaps back. A port has to record `{unit, old proto}` at the swap and
    transform back when `ActiveTime` ends.
  - Unknown: the end of `ActiveTime` in the base power class (0x8E1445) was only skimmed.
- **#40 `DoNotQueue`.**
  - [O] It is a tech flag (status bit 26), read by the Research action's slot 58h 0x9E5EAD. Legacy has a shipment queue, and `doNotQueue` reorders it.
  - [O] The proto flag parser does not know the name.
  - [I] A proto version needs a marker and a hook in the train queue.
- **#33 crates.** [O] The order is hardcoded twice, both keyed on the civ:
  - a per-civ rank in the gather target search (0x4DBF40): food first by default, coin for the
    Dutch, wood for the Ottomans and Indians;
  - a per-civ "next crate" cycle (FUN_00501786).

  [I] A per-civ cfg order would replace both.
- **#31 batch.** [O] The units per Train action come from one call (0x9CE645), which returns the
  player's `PlayerSpecificTrainLimitPerAction`, or else a world default. The shift-click 5 is a
  literal in the UI command string.
- **#29, #30 build limits.** [O] Every check (train queue, Maintain, build, AI, UI: 50 calls) goes
  through one limit getter (0x4C7B5F) and one count function (0x4C7BC5). [I] A shared or team
  limit belongs there.
- **#39 the delete (2026-11-05).** [O] The stock Delete button and the Delete key run the console command
  `uiDeleteSelectedUnit` (handler 0x7E5197, registered at 0x52F5C6; the `exec` crash at 0x7E51C8 is a null UI
  pointer `[0xC66244]+74h→+34h→+1874h`, read before the selection, so the console route only works with the
  interface up). With one unit selected it calls FUN_0082F1E3, which builds the synced command of type 7 (constructor
  FUN_007D5949, vtable 0xB87E30) with the unit's ID and sends it; several units go through a confirmation dialog
  first. The executor is slot 21 of that vtable, FUN_007CCF7F: for a proto with flag 0Dh it asks the kill queue
  0x4B4DC2 with flags 1 0 0 (0x7CD0DC); for any other it sets the HP to 0 through 0x4820A1 with flag 1 (0x7CD0CF),
  whose death check 0x482152 goes to FUN_004B4F2F, not through the queue; a command with byte `+8Ch` set goes to
  0x4726B2 instead. [I] So a delete reaches the kill handler's wrapper only for flag-0Dh protos; `detonationDeath`
  wraps the two calls.
- **#37 research cost.** [O] A research is paid once, when it is queued (0x9E67E1; a second path at
  0x9D54CF). The paid cost is copied to the action, [I] for the refund on cancel. [I] "Next
  research is free" skips that payment and copies a zero cost.

## DE names for the items already built

So the cfg keys and markers can keep DE's names where DE has one:

| # | Our key | DE counterpart | Note |
|---|---|---|---|
| 1 | `dodgeAnyUnit` (`AbstractDodge`) | flag `CanDodgeAttacks` + `DodgeChance` (guide p8, p18); subtypes `EnableDodge`, `DodgeChance` | DE keeps the Japanese-monk path and adds the flag for other units. Both names read as proto elements since 2026-11-05 , and the two subtypes (2026-11-05) |
| 1b | `dodgeSoundSet`, `criticalSoundSet` | proto `DodgeSoundSet`, `DodgeMessageID`; tactics `HitPercentSoundSet` | DE's parser: fn 0x101DEF0 |
| 3 | `startingTC`, `civFirstTC` | tactics flag `FirstTC` (an aura only on the first TC); no per-civ start tag | |
| 5, 22 | `liveBuildingWorkRate`, `buildingWorkRateAuras` | modify type `BuildingWorkRate` (guide p35), the same spelling as ours; also `TrainingRate`, `ResearchRate` | |
| 6 | `techPrereqRecheck` | flags `ForceFullTechUpdate`, `ForceFullTechUpdateTeam` | The guide says DE added them for the same legacy limitation. DE also changed the default `state` of `TypeCount` (guide p58) |
| 12 | `customHotkeyContexts` | proto `LegacyHotkeyContext` (145 protos) | DE's parser: fn 0x1022A40 |
| 17 | `techRenameEffect` | effect `SetName` with `tech=` (227 effects), per player | |
| 19 | `danceBonusCivs` | flags `UseDanceActions`, `DanceActionNoWorkers` | The guide mentions no civ gate |
| 28 | `showGatherRate` | flags `ShowUnitResourceActionRates`, `TotalAutoGatherRates` | DE's per-villager display is not a data tag |

## Undocumented DE flags

- [O] DE's proto flag table at .data 0x3354DC0 has 261 names. The walk also reached a 262nd slot, a
  UTF-16 `PlaySFX`, which is probably not part of the table.
- [O] 28 of the names appear nowhere in the guide's text. Most are internal positive forms of
  documented flags: `Searchable` for `NotSearchable`, `Rotateable`, `Deleteable`, and
  `ShowAutoGatherRate` for `DoNotShowAutoGatherRate`.
- [O] `ForceTrainAtBaseTrainPoints` and `UsesExtraWorkerSlot` are the internal names of the
  documented `YP…` flags (guide p17).
- [O] `UniqueInstance` is described as a behaviour (guide p73, p101), not as a flag entry.
- [O] Only `DamageTrees` and `HasContinuousParticles` have no documented counterpart.
- [O] 130 of the names are absent from the legacy exe.

## Other DE additions worth porting

Not requested, all absent from legacy unless noted. Pages are the guide's. The full list, with use
counts, is in `requests-findings.md`, Appendix A.

| Name | Page | What it does | Why it matters for legacy [I] |
|---|---|---|---|
| `ProtoUnitFlag`, `SetActionFlag` (effects) | 98, 105 | A tech sets any proto or action flag by name | Lets techs switch on most flags on this page |
| `NoStack`, `ForbidAbstractType` / `ForbidUnitType`, `ModifyTargetLimit` (auras) | 26, 31 | An aura does not stack with itself; excludes types; caps the units it reaches | Fixes the "every aura stacks" problem (`NoStack` is on 185 DE actions) |
| `DeadTransform` | 9 | The unit turns into another proto at 0 HP | "Wounded" units without triggers |
| `UnitRegen` per proto | 11 | Regeneration with idle and damage timeouts; negative = decay | Legacy has it only per civ |
| `ResourceReturn`, `ResourceReturnRate` | 8 | Refund on destruction | Salvage designs |
| `GatherRateMultiplier` | 9 | Multiplies the gather rate on a resource | Rich mines without editing every gatherer |
| `ConversionResistance`, `KillIfConverted` | 8, 17 | Per-unit conversion time; death on capture | WoL's priests and captures |
| `ContainedHitPointBonus` | 7 | Garrisoned units add HP | Garrison-strengthened buildings and ships |
| `NotContain`, `SharedGarrison` | 9, 20 | Forbid one type from garrisoning; one garrison shared by all instances | Clean exceptions; tunnel networks |
| `InvulnerableToAreaDamage`, `InflictsNoDamage` | 17–18 | Immune to splash; attacks that deal nothing | Decoys and VIPs |
| `GatherFromTrees`, `AllowTrainingOnWater`, `GatherableByAllies` | 17–18 | Non-villagers chop; ships train; allies gather | Removes villager-only and land-only hardcodes |
| `FreeRepair`, `NotRepairable` | 19–20 | Free repair; no repair | Balance knobs |
| `ArmorOverride` + `UseTacticArmorOverride` | 37, 18 | Armor per tactic | Stance-dependent armor |
| `AttackPriorityType` | 38 | Target priority per tactic | Better auto-targeting for counters |
| `TargetLock`, `DirectionalDamage`, `PassThrough` | 33–34 | Keep the target beyond range; directional damage; piercing shots | New weapon types |
| `BuildLimitSuspend`, `SpawnIgnoreBuildLimit` | 32–33 | Maintain pauses at the limit and keeps progress | DE's data fix for the problem behind `maintainWaitForPop` (#8) |
| `DEUnobtainableAfterActive` | 55 | A tech that reverts and re-applies with its prerequisites | "While you have X" bonuses |
| `TechType` + the Data target `techType` | 51, 73 | Edit a group of techs in one effect (legacy already has the targets `techWithFlag` and `techAll`) | Hundreds of WoL effects become one |
| `DECheckBuildLimit` | 54 | Blocks a card whose units would exceed a build limit | No wasted cards |
| Civ `StartingResourcesMultiplier` | 46 | Starting resources per civ | Civ balance without map edits |

## The Ethiopian Mountain Monastery

- [O] DE's `deMountainMonastery` (data, not code): a Gold `Resource` building, `gathererlimit` 20, no `UnitResource` aura. Its
  tactics have `ResourceProxy` on `AbstractMine` (range 8, `gatherlinkedresource`, `dontkillwhenexpired`), `AutoGather`
  actions with `gatherlinkedresource` and `autogatherinventoryifnotsocketed`, `InfluenceRate` auras and `AreaHeal`.
- [O] Legacy has neither `AreaHeal` nor `HealRate`, nor a `Yield` subtype: `WorkRate` on the AutoGather action does that.
- [O] Built as `linkedResource` (2026-11-06) without Influence, sockets or the heal: the data is a recipe in the modding guide.

## Questions for JTMaston

1. **#2.** *Answered (2026-10-30):* DE's model is not relevant to WoL. He wants `maxspread` respected
   whatever the accuracy; see wol-requests.md, Q1.
2. **#29, #30, #31.** Should the keys use DE's names? Those are `UseSharedBuildLimit`,
   `SharedBuildLimitUnit`, `SharedBuildLimitUnitTypes` (with `weight`), `TeamBuildLimit`,
   `SettlerBuildLimit` + `LogicalTypeSettlerBuildLimit` + civ `SettlerProtoName`, `TrainBatchSize`
   and `DontTrainInBatches`. Data written for DE would then work unchanged. *Answered (2026-10-30, second batch in
   wol-requests.md):* use DE's names, without a "DE" prefix; built that way in `sharedBuildLimit` and `trainBatchSize`.
3. **#32.** DE splits gather auras by target class (natural food, trees, mines, farms), not by
   resource. Is that what you need, given the plantation case (Q4)? *No recorded answer:* `resourceGatherAuras` built
   both, DE's target classes and a rate per resource.
4. **#34.** Which part of DE's bounty system do you need? The options are a tech that scales a
   unit's bounty (`KillBounty`), bounties in other resources (`resourcetype`), or extra resources for
   killing a type (`BountyResourceOverride`). Does your DLL already parse `KillBounty`? *Answered (2026-10-30):*
   `KillBounty` techs and `resourcetype` bounties, plus `TeamKillBounty`, not `BountyResourceOverride`; built as
   `killBountyTechs`, `resourceBounty` and `teamKillBounty`.
5. **#36.** DE does this with a power, not a tech flag: `CreatePower`, then a timed `EnemyEffect` or
   `TeamEffect` power. Would that work for your cards? *Answered (2026-10-30):* he did not understand the comparison,
   so his original request was built: the tech flags `HCTargetEnemy` and `HCTargetAll` (`hcTargetTechs`).
6. **#24.** A negative trickle already works in data, but the stockpile stops at 0: lower
   `MinimumResourceTrickleRate` below 0 together with the negative `ResourceTrickleRate`. Is that
   enough? If you need real debt, what should it do: block training and building, show the stockpile
   in red, or something else? *Answered (2026-11-05):* a stockpile goes below 0 only through the global trickle, unit
   AutoGather and gathering, a tech never leaves a player negative, and there are no penalties; built that way as
   `resourceDebt`.
7. **#25.** By the code, your `barn.tactics` works already: its AutoGather runs only while a unit is
   inside. Do you also need the rate to grow with the number of units inside? *Answered (2026-10-30):* yes, built as
   `autoGatherScaleByContained`; *2026-11-08:* rate of fire too, with `target="ROF"` on any attack.
8. **#33.** Stock legacy orders crates by civ: coin first for the Dutch, wood first for the Ottomans
   and Indians, food first for everyone else. What should the setting be: an order per civ, or a
   priority per crate unit type? *Answered (2026-10-30):* he did not understand the question, so the design is an order
   per civ (`cratePriority`).
9. **#40, #44.** For #40: is the request for units, for shipments, or for both? For #44: which
   building, and what should the builder decide? *Answered:* #40 both (2026-10-30); #44 (2026-11-08): an annex faces
   its builder in steps of 90 degrees, fixed at placement, and falls with it; WoL's four cases are only tests.

## Verification

- **DE side.** An independent agent re-derived the page's claims from the primary files (the guide's
  text, DE's XML, the three binaries, WoL's data), without REA. Its table is
  `rea/evidence/aoe3de-31fad98f/parity/verification.md`.
  - It confirmed the counts, the presence numbers, the veterancy ranks and almost every page
    citation.
  - It refuted seven details, all corrected here: the #2 outliers, where legacy's `Bounty` aura sits,
    the two `DoNotQueue` cavalry, WoL's 5 `SwapUnit` powers, `NoStack` 185, `techWithFlag` /
    `techAll` being legacy, and the undocumented-flag list.
  - It flagged three readings that went beyond the guide ("per second", "units and techs", "cone"),
    now reworded.
- **Legacy side.** Every site marked `confirmed` in engine-symbols.md, "DE parity sites", was read in
  assembly (REA listing or capstone). The pseudocode-only parts are marked `scoping`.
- **Not done.** Nothing was tested in game, in DE or in legacy. The DE exe did not open in REA within
  its 30-minute limit, so DE's code was read only through `pe64.py`.
