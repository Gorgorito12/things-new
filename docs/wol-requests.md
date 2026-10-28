# WoL feature requests, in priority order

Source: JTMaston (WoL), Discord, 2026-10-28. Three messages of requests, then his ordering rule:

1. First, everything that is a bug or has odd logic, above all: **dodge** (needed for ME), **shotguns**, the **TC hardcode**, and **conversion of units with a resource inventory**.
2. Then the new mechanics, in the order he listed them.

Their next patch is planned for **December 2026 – January 2027**; he is busy until the end of November. Tier 1 should land before December.

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
| 1 | Dodge only works for one Asian monk; make it work on any unit. | hardcode | strings `Dodge`, monk protos (`ypMonk*`); find the proto-ID compare. | Marker type via `unittypes.*`. Needed for ME. | open |
| 1b | Dodge and critical-hit sound sets are hardcoded (DE has the proto attribute `DodgeSoundSet`). | hardcode | same area as #1. | Do with #1 if the sound lookup is next to it. A cfg mapping avoids a new proto attribute. | open |
| 2 | Shotgun spread (`MaxSpread`) only happens when accuracy < 1; allow spread regardless of accuracy. | odd logic | strings `MaxSpread`, `Accuracy`; the `accuracy < 1` branch in projectile launch. | Probably a small branch patch, opt-in per unit by marker. | open |
| 3 | The TC is hardcoded as the starting building for every civ; choose it per civ. The building must still carry `StartingTC`. | hardcode | strings `TownCenter`, `StartingTC`; start-unit creation in game setup. | Per-civ cfg key, e.g. `startingBuilding <civ> <proto>`. Related: #27. | open |
| 4 | Converting a unit with a resource inventory into a unit with a different inventory breaks. | bug | convert / transform path, inventory copy. | Reproduce with and without our `removeConversionRestriction` first: is the bug stock or ours? | open |

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
| 11 | `AbstractMine` behaves oddly with gather-rate boosts: plantations have the tag, yet mining techs don't affect them. | odd logic | Probably gather type vs unit type; check before patching. | open |
| 12 | Unit-train hotkeys don't work in buildings added by the mod (forge, gunsmith). | hardcode | | open |
| 13 | Snare spreads to the whole group when one unit is hit. | odd logic | Related: #38. | open |
| 14 | Ceasefire is hardcoded to the Indian wonder. | hardcode | | open |
| 15 | Barrage-type ship attacks (floating battery, long range) have a capped projectile count. | hardcode | | open |
| 16 | A unit can have any number of powers (e.g. crackshot), but the UI shows only the first 6: a 7th power enabled for a civ, with the first 6 disabled, gets no button. | hardcode | | open |
| 17 | Tech rename / redescribe (WoL `enabletechrenameeffect`, effect `SetTechName`) applies globally, not per civ / player. | bug (WoL) | Our DLL does not implement this key yet; make it per player when we do. See [wol-uhc-map.md](wol-uhc-map.md). | open |
| 18 | Dopples (the fog-of-war copy) of hunted animals leave a static corpse; they should just vanish. | odd logic | To test, revert the dopple flags to legacy. | open |
| 19 | New dances with global (aura-like) effects can't be added. | hardcode | | open |
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
