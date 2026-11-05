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
| 25 | Garrison-scaled trickle / ROF | Garrison scaling only on attacks (`ScaleByContainedUnits`, `ScaleByContainedUnitType`); economy scales with population (`PopulationScaling`) | `ActiveIfContainsUnits` already gates AutoGather; `ScaleByContainedUnits` is read only by attacks | gate: **data only**; scaling: M |
| 26 | Buildings that gather | Modify type `UnitResource` on an `AutoRangedModify` aura (the Polish Torp) | Absent; WoL's `sawmill.tactics` already carries DE's aura | M |
| 29 | Shared / team build limits | `UseSharedBuildLimit` + `SharedBuildLimitUnit` + `SharedBuildLimitUnitTypes` (with `weight`); `TeamBuildLimit` | Absent (`TCBuildLimit` only); every check goes through one limit and one count function | flags S, lists L; all five names read as elements (2026-11-05) |
| 30 | Shared settler limit | Flag `SettlerBuildLimit` + type `LogicalTypeSettlerBuildLimit` + civ `SettlerProtoName` | Absent | S–M; the three names built in `sharedBuildLimit` (2026-11-05) |
| 31 | Per-unit batch size | `TrainBatchSize`; flags `DontTrainInBatches`, `ForceBatchTrain` | Absent (global `PlayerSpecificTrainLimitPerAction` only); the batch comes from one call | flags S, size M; the three names read as elements (2026-11-05) |
| 32 | Economic aura per resource | Modify types `NaturalFoodGatherRate`, `TreeGatherRate`, `MineGatherRate`, `FarmingGatherRate` (by target class) | Absent (`GatherRate` only) | M |
| 33 | Crate gather priority | Nothing; auto-crate-gather by flag only | Hardcoded per civ in two places (Dutch: coin first; Ottomans and Indians: wood first) | M (a per-civ cfg order) |
| 34 | Kill bounty by techs | Subtype `KillBounty`; `Bounty resourcetype`; `BountyResourceOverride` / `BountyResourceExtra` / `BountySpecificBonus` | Absent; WoL's DLL has a `KillBounty` string | M |
| 35 | `TeamKillBounty` | Flag on the victim: its bounty goes to the killer's whole team (used by no DE unit) | Absent, but the stock payment already has a "whole team" mode | **S** |
| 36 | Cards that hit enemies / all | No tech flag. `CreatePower` → a timed power of type `EnemyEffect` / `TeamEffect` | Absent (`GeneralEffect` exists) | L |
| 37 | `NextResearchIsFree` | Flag on a building proto, set by subtype `SetNextResearchFree` | Absent; a research is paid at one site when it is queued | M |
| 38 | `CantBeSlowed` | Flags `CantBeSlowed` (immune to snares) and `CannotSnare` (its attacks do not snare) | Absent; the snare site is mapped, with both units in registers | **S**; both built as types (`cantBeSlowed`, 2026-11-05) |
| 39 | `DetonationDeath` | Flag + `DetonationProtoAction`, `DetonationCommand`, `DetonationHitpointThreshold`, `DetonationHitpointDecay` | Absent | L |
| 40 | Train ahead of the queue | Proto flag `DoNotQueue` (builders and wagons); nothing for shipments | `DoNotQueue` exists only as a tech flag, and no code reading it was found | S–M |
| 41 | Reversible timed transform | Power `SwapUnit` with `<reversible/>` and `<activetime>` | Has `SwapUnit`, which never swaps back; `reversible` absent | M |
| 42 | Veterancy bonus | `VeterancyBonus` ranks per proto + flag `ExperienceUnit` + `veterancydata.xml` (3 ranks at 1, 2, 3 kills) | Has `ExperienceUnit` (counts kills, no effect) | L |
| 43 | `NativePreview` | Flag on native sockets: shows the settlement's units before a TP stands | Absent | L, UI |
| 44 | Building rotated / annexed by its builder | Nothing for rotation; in-place building upgrades (`ForceMutate`, `RevertUpgrade`) | — | needs a design |

**Where to start** [I]:
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

### #26 Buildings that gather

- [O] DE's Torp gathers through auras: an `AutoRangedModify` with modify type `UnitResource`
  drains nearby resources at a linear rate set by `ModifyAmount` (guide p35): mines 0.27, trees 0.05 on up
  to 5 trees (`ModifyTargetLimit`), hunts 0.42, berries 0.3, crates 4.0. 19 such actions
  (Torp, folwark, hacienda). The flag `ShowUnitResourceActionRates` shows the rates.
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

### #31 Per-unit military batch limit

- [O] Proto attribute `TrainBatchSize` replaces the default batch of 5 (guide p9). Subtype
  `TrainBatchSize` (p95). Flags:
  - `DontTrainInBatches`: batch of 1;
  - `ForceBatchTrain`: batch training for multiple-block trains and banner armies (p17–18).
- [O] DE data: `TrainBatchSize` 10 on `NatClubman` and `deInsurgente`; `DontTrainInBatches` on 9
  protos (Cannon, Minuteman…).
- [O] DE's parser is plaintext (fn 0x102E830). Legacy has only the player-wide
  `PlayerSpecificTrainLimitPerAction`.

### #32 Economic aura per resource

- [O] DE adds aura modify types by target class (guide p35):
  - `NaturalFoodGatherRate`, `TreeGatherRate` and `MineGatherRate`: 14 actions each, on outpost-like
    buildings;
  - `FarmingGatherRate`;
  - `ResourceGatherRate` / `ResourceYield`, which act on the gather site rather than on the
    gatherer.
- [I] DE splits by what is gathered, not by resource. A plantation is not a `MineGatherRate`
  target unless it is a mined resource; this is the plantation question Q4 again.

### #33 Crate gather priority

- [O] DE has no priority interface: only `DrawnToCrates` (gather nearby crates automatically,
  guide p17) and the subtype `EnableAutoCrateGather`.
- [O] DE's strings name crate types (`AbstractCoinCrate`, `AbstractFoodCrate`,
  `AbstractWoodCrate`) and log `doAutoCrateGather`. [I] DE probably still orders crates in code.

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

### #35 `TeamKillBounty`

- [O] A flag on the **victim**: the bounty for killing it goes to the killer's whole team (guide
  p20). It is in DE's flag table but on no DE proto.
- [I] A marker type and one hook where the bounty is paid. Unknown in DE: whether each teammate
  gets the full amount.

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

### #37 `NextResearchIsFree`

- [O] Flag on a building proto: the next research queued there is free (guide p18). The subtype
  `SetNextResearchFree` sets it (p90).
- [O] DE data: no proto has it in XML; 6 techs set it (e.g. on the Arsenal, with an Arsenal
  wagon).
- [I] Per proto or per building, and cleared after one use, are not documented: the code that reads
  the flag is the research path.

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

### #40 Train a unit ahead of the queue

- [O] DE's proto flag `DoNotQueue`: the unit is not held by the building's queue (guide p18).
  19 protos have it: 17 builders or wagons, and the two Yoruba riders (cavalry with no build
  action). Legacy has a tech flag of the same name, which WoL uses on 16 techs, read by the Research action's
  slot 58h, 0x9E5EAD, only under the world byte `[world+6910h]`.
- [O] Nothing in DE orders shipments.

### #41 Reversible transformation on a timer

- [O] DE's power type `SwapUnit` takes `<activetime>` and `<reversible/>`, plus `<mutate/>`, `<global/>`
  and `<forcefullhp/>`. `deScanianResistance` turns villagers into Minutemen for 90 s.
- [O] Legacy has `SwapUnit` (WoL has 5 such powers, all one way). `reversible` and `forcefullhp` are
  absent (0/0).
- [I] The smallest port is `<reversible/>` on legacy's own `SwapUnit`. It depends on what legacy does
  when `activetime` ends.

### #42 Veterancy bonus

- [O] Proto `VeterancyBonus` with three `Rank` children of `VeterancyModify modifyType=…`
  multipliers, which need the flag `ExperienceUnit` (guide p10–11). Subtypes `VeterancyEnable` and
  `VeterancyBonus` (p97).
- [O] 36 DE protos have it. Typical: MaxHP and Damage ×1.15 / 1.30 / 1.45, ROF ×0.9 / 0.8 / 0.7,
  `RangeAbsolute` +1 / +2.
- [O] `Data\veterancydata.xml` defines the ranks: `numkills` 1, 2 and 3, with an icon (bronze,
  silver, gold), a string and a colour. [I] What counts as one kill is not established.
- [O] Legacy has `ExperienceUnit`, which counts kills with no effect (guide p16).

### #43 `NativePreview`

- [O] A flag on the 45 native sockets: while no trading post stands, it enables a preview of the
  native settlement (guide p21). What the preview shows is not described. It works with DE's socket-build command chain
  (`SocketBuildProtoUnit`, `SocketBuildCommandID`, `SocketSubCivAlliance`), all absent from legacy.

### #44 Building rotated or annexed by its builder

- [O] DE has no such tag. The nearest DE mechanisms are socket buildings (`SocketBuildProtoUnit`) and
  in-place upgrades through commands (`Transform` + `ForceMutate`, `RevertUpgrade`; the folwark).

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
  - [O] It is only a tech flag (status bit 26). No code reading it was found.
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
- **#37 research cost.** [O] A research is paid once, when it is queued (0x9E67E1; a second path at
  0x9D54CF). The paid cost is copied to the action, [I] for the refund on cancel. [I] "Next
  research is free" skips that payment and copies a zero cost.

## DE names for the items already built

So the cfg keys and markers can keep DE's names where DE has one:

| # | Our key | DE counterpart | Note |
|---|---|---|---|
| 1 | `dodgeAnyUnit` (`AbstractDodge`) | flag `CanDodgeAttacks` + `DodgeChance` (guide p8, p18); subtypes `EnableDodge`, `DodgeChance` | DE keeps the Japanese-monk path and adds the flag for other units. Both names read as proto elements since 2026-11-05 |
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

## Questions for JTMaston

1. **#2.** *Answered (2026-10-30):* DE's model is not relevant to WoL. He wants `maxspread` respected
   whatever the accuracy; see wol-requests.md, Q1.
2. **#29, #30, #31.** Should the keys use DE's names? Those are `UseSharedBuildLimit`,
   `SharedBuildLimitUnit`, `SharedBuildLimitUnitTypes` (with `weight`), `TeamBuildLimit`,
   `SettlerBuildLimit` + `LogicalTypeSettlerBuildLimit` + civ `SettlerProtoName`, `TrainBatchSize`
   and `DontTrainInBatches`. Data written for DE would then work unchanged.
3. **#32.** DE splits gather auras by target class (natural food, trees, mines, farms), not by
   resource. Is that what you need, given the plantation case (Q4)?
4. **#34.** Which part of DE's bounty system do you need? The options are a tech that scales a
   unit's bounty (`KillBounty`), bounties in other resources (`resourcetype`), or extra resources for
   killing a type (`BountyResourceOverride`). Does your DLL already parse `KillBounty`?
5. **#36.** DE does this with a power, not a tech flag: `CreatePower`, then a timed `EnemyEffect` or
   `TeamEffect` power. Would that work for your cards?
6. **#24.** A negative trickle already works in data, but the stockpile stops at 0: lower
   `MinimumResourceTrickleRate` below 0 together with the negative `ResourceTrickleRate`. Is that
   enough? If you need real debt, what should it do: block training and building, show the stockpile
   in red, or something else?
7. **#25.** By the code, your `barn.tactics` works already: its AutoGather runs only while a unit is
   inside. Do you also need the rate to grow with the number of units inside?
8. **#33.** Stock legacy orders crates by civ: coin first for the Dutch, wood first for the Ottomans
   and Indians, food first for everyone else. What should the setting be: an order per civ, or a
   priority per crate unit type?
9. **#40, #44.** For #40: is the request for units, for shipments, or for both? For #44: which
   building, and what should the builder decide?

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
