# WoL feature requests, in priority order

Source: JTMaston (WoL), Discord, 2026-10-28. Three messages of requests, then his ordering rule:

1. First, everything that is a bug or has odd logic, above all: **dodge** (needed for ME), **shotguns**, the **TC hardcode**, and **conversion of units with a resource inventory**.
2. Then the new mechanics, in the order he listed them.

Their next patch is planned for **December 2026 – January 2027**. Tier 1 should land before December.

**Missing items.** The top of the 1:44 p.m. message was cut off in the screenshot. Ask for the items above "workrate modifiable by auras".

Every row starts as `open`. Update the Status column as work progresses (`open` → `RE` → `implemented` → `confirmed in game`).

## How to work an item

1. **RE first.** Load the `reverse-engineer-anything` skill, open the stock exe with REA, and start from the "First lead" column (`search_strings`, then `xrefs`). Record every site in `docs/uhc-address-map.md`, "Beyond upstream", and any new names in `docs/engine-symbols.md`.
2. **Sites.** Add each site to `SITES` in `tools/gen_sites.py` and regenerate `src/generated/sites.h`.
3. **Feature.** One apply function in `src/features/*.cpp`, hooks in `src/hooks/*.asm` with `TRACE_ONCE`.
4. **Docs and release.** README feature table, `docs/modding-guide.md`, `docs/how-it-works.md`, `examples/Startup/uhc.cfg`, and the key list of `README.txt` in `tools/package_release.py`.

**Design rule.** Stock drops unknown proto tags. Prefer an abstract unit type as a per-unit marker, registered through `src/unittypes.*` the way `healNonIdle` does (`AbstractHealNonIdle`). A new numeric proto attribute (`DodgeSoundSet`, a per-unit batch limit, …) needs work in the proto XML loader; treat that as a bigger item and say so before starting.

## Tier 1: his explicit priority (before December)

| # | Request | Kind | First lead | Notes | Status |
|---|---|---|---|---|---|
| 1 | Dodge only works for one Asian monk; make it work on any unit. | hardcode | strings `Dodge`, monk protos (`ypMonk*`); find the proto-ID compare. | Done: `dodgeAnyUnit [UnitType]` (default `AbstractDodge`). Stock limits it to the three `ypMonkJapanese` protos (FUN_0049ACAA); marked units take the same path (tech `YPDodge`, 15 %). Needed for ME. | confirmed in game (single player) |
| 1b | Dodge and critical-hit sound sets are hardcoded (DE has the proto attribute `DodgeSoundSet`). | hardcode | same area as #1. | Done as cfg mappings: `dodgeSoundSet <UnitType> <SoundSet>`, `criticalSoundSet <UnitType> <SoundSet>` (stock `PowerEvade` / `PowerCriticalStrike`). | confirmed in game from the log (single player; not listened to) |
| 2 | Shotgun spread (`MaxSpread`) only happens when accuracy < 1; allow spread regardless of accuracy. | odd logic | strings `MaxSpread`, `Accuracy`; the `accuracy < 1` branch in projectile launch. | RE done ([engine-symbols.md](engine-symbols.md), "Projectile accuracy and spread"): the spread is the stock **miss** offset, `min(0.25 × distance, 5)`, applied only when the precalculated accuracy roll misses; `MaxSpread`, `SpreadFactor` and `NumberProjectiles` are **not read by TAD at all**. Needs a decision (question Q1 below). | RE |
| 3 | The TC is hardcoded as the starting building for every civ; choose it per civ. The building must still carry `StartingTC`. | hardcode | strings `TownCenter`, `StartingTC`; start-unit creation in game setup. | Partial RE: the random map scripts place `TownCenter` themselves (`rmAddObjectDefItem(startingTCID, "TownCenter", …)`), the exe caches its proto ID at `db+5E08h` (25 readers), and `StartingTC` exists nowhere (exe, WoL DLLs, WoL data). 0x82E46A is only the start camera. Which stock behavior breaks is not known yet (question Q2). Related: #27. | RE |
| 4 | Converting a unit with a resource inventory into a unit with a different inventory breaks. | bug | convert / transform path, inventory copy. | Not reproduced yet: the conversion and the units involved are not known (question Q3). Then reproduce with and without `removeConversionRestriction`: is the bug stock or ours? | open |

**Open questions for JTMaston** (2026-10-28; the answers decide the work):
- **Q1 (#2):** in TAD a shot's spread exists only as the miss offset, with fixed values (0.25 × distance, at most 5 m); `maxspread`, `spreadfactor` and `numberprojectiles` in the tactics are ignored, so the shotgun fires one projectile per shot. Which do you want?
  (a) marked units scatter **every** shot with the stock offset, hits included (the target still takes the damage; the projectile just lands around it);
  (b) every shot of a marked unit becomes a miss-with-offset, so it damages whatever is at the landing point;
  (c) the tactics' own `maxspread` / `spreadfactor` per action instead of the fixed 0.25 / 5 (needs parsing new tags: a bigger item);
  (d) `numberprojectiles` working, several pellets per shot (the biggest).
- **Q2 (#3):** what is `StartingTC`: a unit type, a flag, a name in your data or DLL? The random maps already choose the starting building per civ if their script does; what goes wrong when a civ starts with another building (shipments, AI, Nomad, age-up, defeat, something else)?
- **Q3 (#4):** which conversion is it (`ConvertGuardian`, a trigger, a tech, livestock capture) and between which protos? What "breaks": a crash, lost or duplicated resources, a stuck unit? A save or a minimal data set to reproduce it would settle whether it is stock or `removeConversionRestriction`.
- **Q4 (#11):** stock works the same way. A `WorkRate` effect on `AbstractMine` changes only the gatherers' `AbstractMine` rate; a gatherer that has its own `Plantation` rate uses that one, so mining techs never reach plantations. Do you want mining techs to boost plantation-like buildings at all?
  - If yes, the data fix is to add, next to each such effect, the same effect with `unittype='Plantation'` (and `OlivePlantation`, `WOLPlantationIroquois`, `Beehive`, …), as stock does for `HCRoyalMint`. We can send the list of mining-only techs and the gatherers that lack a rate for one of these buildings.
  - A DLL option (`workRateInherit`: a marker on the building makes its rate follow the mining boosts) is possible, but the WoL techs that already pair the two effects would then apply twice, so those lines would have to go anyway.
  - Side finding: some WoL effects use `type='Data' subtype='WorkRateSpecific'`, which stock accepts only as `Data2`. Your DLL replaces that parser, so it may handle them; with our DLL alone they would do nothing.
- **Q5 (#14):** any unit can cast a `CeaseFire` power: nothing checks the Taj Mahal. But every caster of `ypPowerCeaseFire` shares one charge per player, with the period of the last ability record granted at game start (the Taj Mahal's 450 s in practice). What exactly fails for you?
  (a) no button; (b) "This ability is not available"; (c) it works but shares the Taj Mahal's charge and 450 s recharge; (d) the effect should not hit everyone; (e) you want a ceasefire with extra effects.
  For (c), the fix is data only: a copy of `ypPowerCeaseFire` per caster, with its own name and `activetime`, plus `<alwaysaddtoplayer>1</alwaysaddtoplayer>` when its ability record has a `<tech>`. Do not add `allowduringnorush`: a ceasefire cast during a Treaty game ends the treaty early.
- **Q6 (#19):** which dance failed? Its kind (`Training`, `XPTrickle`, `Gathering`, `Regeneration`, `UnitModification` with which ModifyType, or a new kind), the civ, the building (with or without `AbstractFirePit`), and what failed (no effect, a blank tooltip, no button).
  - The four global kinds apply only to `XPIroquois`, `XPSioux`, `XPAztec` and `XPSPC`: for any other civ they silently do nothing, although the tooltip shows the bonus. A fix is verified and can be built now, as `danceBonusCivs <Civ>…`.
  - Only the first `AbstractFirePit` of a player counts, and a dance building needs `AbstractFirePit` to dance at all. Lifting either is more work.

Done when:
- **#1:** a non-monk unit with the marker dodges in game, and `UHC.log` shows the hook reached.
- **#1b:** a configured unit plays its own dodge / critical sound.
- **#2:** a marked unit with accuracy 1 and `MaxSpread` > 0 visibly spreads its shots.
- **#3:** a civ configured with another building starts with it, and every `StartingTC` check (e.g. shipments, AI) still works.
- **#4:** the reported conversion no longer breaks; the cause (stock or ours) is written down.

## Tier 2: other bugs and odd logic

Ordered by gameplay impact, then expected effort.

| # | Request | Kind | Notes | Status |
|---|---|---|---|---|
| 5 | Workrate techs only affect units / buildings created after the tech; they should be global. | bug | Same field as #22; do them together. | open |
| 6 | Tech `kb` prereqs on living / dead unit counts are only re-checked when max pop changes (e.g. building houses). Re-check every 1–2 s if it is cheap. | odd logic | Measure the cost first (`docs/performance.md`). | open |
| 7 | A building's `Lifespan` starts when the foundation is placed instead of when construction finishes. | bug | | open |
| 8 | Auto-produced units (factory cannons) restart their train timer when pop-capped, even though nothing was trained. | bug | | open |
| 9 | Building over a socket unit owned by a player (not Gaia) shows red but is allowed anyway (saltpeter / saltpeter mines in their next patch). It should be blocked. | bug | | open |
| 10 | Transformed units keep the LoS of the source unit instead of the target's. | bug | | open |
| 11 | `AbstractMine` behaves oddly with gather-rate boosts: plantations have the tag, yet mining techs don't affect them. | odd logic | RE done (static): stock behaves the same. A `WorkRate` effect changes one exact rate key, and a gatherer that has its own rate for `Plantation` never reads its `AbstractMine` rate. Data fix: pair each mining tech with the same effect on `Plantation` (and the other plantation-like buildings), as stock does for `HCRoyalMint`. A DLL option is possible but makes the 100 WoL techs that already pair them apply twice. Question Q4. | RE |
| 12 | Unit-train hotkeys don't work in buildings added by the mod (forge, gunsmith). | hardcode | | open |
| 13 | Snare spreads to the whole group when one unit is hit. | odd logic | Related: #38. | open |
| 14 | Ceasefire is hardcoded to the Indian wonder. | hardcode | RE done (static): nothing in the exe ties `CeaseFire` to the Taj Mahal. Every caster of `ypPowerCeaseFire` shares one charge per player, made at game start from the ability records; the Taj Mahal records give it a 450 s period. Data fix, no DLL: give each other caster its own `CeaseFire` power, with `<alwaysaddtoplayer>1</alwaysaddtoplayer>` when its ability record has a `<tech>`. Question Q5. | RE |
| 15 | Barrage-type ship attacks (floating battery, long range) have a capped projectile count. | hardcode | | open |
| 16 | A unit can have any number of powers (e.g. crackshot), but the UI shows only the first 6: a 7th power enabled for a civ, with the first 6 disabled, gets no button. | hardcode | | open |
| 17 | Tech rename / redescribe (WoL `enabletechrenameeffect`, effect `SetTechName`) applies globally, not per civ / player. | bug (WoL) | Our DLL does not implement this key yet; make it per player when we do. See [wol-uhc-map.md](wol-uhc-map.md). | open |
| 18 | Dopples (the fog-of-war copy) of hunted animals leave a static corpse; they should just vanish. | odd logic | To test, revert the dopple flags to legacy. | open |
| 19 | New dances with global (aura-like) effects can't be added. | hardcode | RE done (static): the fire pit's four global dance kinds (`Training`, `XPTrickle`, `Gathering`, `Regeneration`) apply only to `XPIroquois`, `XPSioux`, `XPAztec` and `XPSPC`; the exe compares the civ ID, silently (the tooltip still shows the bonus). Fix ready to build as `danceBonusCivs <Civ>…` (WoL's DLL already has a UI-only `danceCiv`). `UnitModification` dances should already work in data. Question Q6. | RE |
| 20 | Global powers can't be added to buildings with auras, like the Japanese wonder. | hardcode | | open |

## Tier 3: new mechanics, in his order

| # | Request | Notes | Status |
|---|---|---|---|
| 21 | Overheal: UI and floating HP bars should use initial HP instead of max HP. | WoL currently sets max HP = 1.1 × initial HP on infantry and cavalry. | open |
| 22 | `Workrate` modifiable by auras. | Do with #5. | open |
| 23 | Decimal population. | | open |
| 24 | Negative resource trickles, with debt allowed. | | open |
| 25 | The tactic tag that scales a building's attack with its garrison: also allow it to scale trickles or rate of fire. | | open |
| 26 | Buildings that gather resources. | | open |
| 27 | Prevent enemy units from training near your StartingTC (like Daimyos). | Related: #3. | open |
| 28 | Show gather rate per second, like DE. | | open |

## Tier 4: remaining requests

DE parity and extras, in rough order.

| # | Request | Notes | Status |
|---|---|---|---|
| 29 | Shared build limits (team-wide, DE): e.g. a livestock limit per team, or no more wagons for building X once all X are built. | Do with #30: same mechanism. | open |
| 30 | Settler build limit: a civ XML tag setting one shared limit for all units with `AbstractWoLSettler`. | | open |
| 31 | Per-unit military batch limit as a proto attribute, instead of only a global tech. | New proto attribute. | open |
| 32 | Economic aura per resource, instead of all resources. | | open |
| 33 | Customizable gather priority on crates (Dutch gold is hardcoded). | | open |
| 34 | Kill bounty modifiable by techs. | | open |
| 35 | `TeamKillBounty` flag (DE). | Do with #34. | open |
| 36 | `HCTargetEnemy` and `HCTargetAll` tech flags, like team techs. | | open |
| 37 | `NextResearchIsFree` tech effect (DE). | | open |
| 38 | `CantBeSlowed` tag (DE). | Marker via `unittypes.*`; related: #13. | open |
| 39 | `DetonationDeath` (DE). | | open |
| 40 | Flag for units and shipments to be trained ahead of the queue. | | open |
| 41 | Reversible transformations on a timer. | | open |
| 42 | DE veterancy bonus. | | open |
| 43 | `NativePreview` (DE). | | open |
| 44 | Rotate buildings by the unit that builds them (AoE4-style visual upgrades / annexes). | | open |
