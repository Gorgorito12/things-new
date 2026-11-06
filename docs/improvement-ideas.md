# Improvement ideas for the implemented features

Working notes, 2026-11-02. One section per feature key, written when the question "can X be
improved?" came up, from the limits recorded in `modding-guide.md`, the sites in
`engine-symbols.md` and the DE comparison in `de-parity.md`. None of it was built when written, and it
was not revisited after: check the modding guide first. Each section ends with what to do first. This file is private (it names WoL and upstream) and is not in the
public export allowlist.

Status words: **data** = no DLL change; **small / medium / large** = DLL work; **RE** = needs
reverse engineering first; **verify** = an in-game check before deciding.

## Checked on 2026-11-06

The notes below date from 2026-11-02. A review of the code and the exe (static, not played) changed these:

- **Wrong:** the water shipment point looks for `HomeCityWaterSpawnFlag`, never for a Town Center. `damageOverTime` wraps
  TakeDamage, not death. `AbilityButtonRecharge` was misnamed: 0x45EE37 reads the cost, now site `AbilityButtonCost`.
- **Already done:** `cantBeSlowed` covers `AttachSnare`; the Maori age up; `techPrereqRecheck` has its KB null guard and
  rechecks once per update; `hcShipmentPointFallback` has the keyword `FirstTC`.
- **Smaller than it looks:** of WoL's actions that never reach `spreadAnyAccuracy`, most are unread tags. Only 7 referenced
  actions have values of their own: 5 `InstantBallistics` and 2 `TargetGround`. A trainer held with a queue cannot move in
  stock either. `abilitySlots 8` already shows every WoL ability. Whether a button lacks a recharge is unproven: stock
  computes a ratio at 0x6952D7.
- **Not to do unless WoL asks,** with the reason:
  - `NumberProjectiles`: JTMaston does not need it.
  - The `Poison` flag: stock's event does nothing (0xB1BE43), and no data reaches the bit.
  - The engine AI's base, the start camera and a Nomad start: JTMaston said only the Pa needs FirstTC, and nothing starts a Nomad
    game in a normal setup.
  - `trPlayerToggleAllowTCSpawning`: nothing in WoL's data uses it.
  - `InstantBallistics` spread: waits for JTMaston (#2).
  - `techPrereqRecheck` by events, `Volatile` hysteresis and team counts: polling already answers in the same update, and
    none of WoL's 9 `<TypeCount>` techs is `Volatile`.
  - Hotkey contexts for mixed selections: that is stock's rule.
  - `abilitySlots` by buttons and the wonder panel's 8: no WoL case.
  - Transforming at expiry and hold conditions in `lifespanAfterConstruction`: WoL's `*Maturing` already end in a unit.

## Cross-cutting

These come up in several sections below. Building them once makes the later items cheaper.

- **Three registries.** Each new feature so far re-implemented the same two hooks to add a name
  the stock parser does not know. Extract them as shared APIs, like `AddActionTagHandler` and
  `AddWorldTick` already are:
  - `AddTechSubtype`: a new `Data` subtype name for tech effects (the exe registers 193 names at
    0x524800..0x526200). Needed by #45 accuracy, `KillBounty` (#34), snare factor, overheal
    capacity, `MaxSpread`.
  - `AddTechEffectType`: a new `<Effect type=…>`, as `techRenameEffect` did for `SetTechName`
    (register hook 0x524CB5, factory 0x62146F). Needed by #37 `SetNextResearchFree`, DE's
    `ProtoUnitFlag` / `SetActionFlag`, #41 timed transforms, `AddUnitType` below.
  - `AddModifyType` (built 2026-11-04, `modifytypes.*`): a new aura `<ModifyType>`, as `buildingWorkRateAuras` did for
    `BuildingWorkRate` (stat 0x40). Needed by `UnitResource` (#26, the Torp), `Lifespan`,
    accuracy, snare resistance, cost discounts, heal rate, conversion resistance.
- **`AddUnitType` / `RemoveUnitType` tech effect.** Adds or removes an abstract type on a
  player's protos. Every marker-based feature (dodge, poison, spread, `healNonIdle`,
  `overhealSources`, …) then becomes unlockable by a card or tech without one proto per state.
  RE: whether type membership lives in the per-player proto copy or in the shared one.
- **Aura safety tags from DE:** `NoStack` (same action does not stack), `ForbidUnitType`,
  `ModifyTargetLimit`. Without `NoStack`, five carriers of a ×4 aura give ×4⁵. Serves every aura,
  stock ones included.
- **Saved games.** State that lives in the DLL is lost on load: poisons (tested), `overhealDecay`
  delays, the future `transformspan`. Either persist it or document it per key; prefer stateless
  designs (`lifespanAfterConstruction` reads stock state and survives a load).
- **Multiplayer.** Almost every row of the README says "multiplayer unverified". With
  `multipleInstances background` and `testbed.py`, a LAN game between two copies on one machine,
  with the key on one side only, turns those rows into results. Log a hash of the
  simulation-affecting cfg keys to diagnose mismatches.
- **XS compiler errors in `UHC.log`.** The game shows only "Error 0003"; the real line needs
  `trace_xs.py` and a debugger today. The eight callers of the error reporter (0x43A3A4) are
  known: a key `xsErrorLog` that captures them helps every modder, and every AI item below.
- **Data linter at load.** Log the `<UnitType>` names stock drops and effects such as
  `type='Data' subtype='WorkRateSpecific'` that stock reads as nothing.
- **Unit tests without the game:** the cfg parser, `xmbedit.py from-xml` (already byte-exact),
  `gen_sites.py`.
- **Key families.** Merge `overhealHitpointBars` / `overhealSources` / `overhealDecay` into
  `overheal`, `startingTC` / `civFirstTC` into `firstTC`, and `transformUpdatesLOS` /
  `transformInventory` (+ #41) into `transformRefresh`. Easier to document and to port to WoL's
  DLL.

## Snare (`<TargetSpeedBoost>`) and `snareOnlyHitUnit`

Stock: the tactics flag calls the modifier creator with two literals, factor 0.65 and 3000 ms, as
an exclusive velocity multiply (0x4DD201..0x4DD223). `damageOverTime`'s `AttachSnare` already
calls the same creator with data values.

- **Factor and duration per action** (`<SnareFactor>`, `<SnareDuration>`), read by the shared
  action-tag hook at 0x5FA11E, with a hook at the literals; stock values when absent. *small*
- **Modifiable by techs and auras:** `Data` subtypes for factor and duration (registry). *small*
- **Resistance on the target:** `cantBeSlowed` (#38, site 0x4DD201, skip → 0x48FA49) as full
  immunity; a partial resistance per type later. `AttachSnare` needs its own test. *small*
- **Strongest wins:** the sum stops at the first exclusive modifier, so a strong snare over an
  active weak one is ignored until it expires. Option to replace or refresh. *small*
- **Target filter** by type on the action (no snare on ships or artillery). *small*
- **Verify:** does a dodge avoid the snare, or only the damage?
- **Generalize to timed on-hit debuffs:** the creator takes any stat ID; a `<TargetStatBoost>`
  with stat, factor and duration gives armor shred, damage or ROF reduction, blind (LOS), and timed
  self-buffs. RE: inventory the stat IDs the sum understands (velocity and 0x40 confirmed).
- **Visible:** a floating text or icon while snared; effective speed in the stat panel.
- `snareOnlyHitUnit`: an alternative group mode (the group waits only for some types, or the
  unit leaves the formation cleanly); an option to count WoL's exclusive speed auras; an A/B video
  with a stock control run (confirmation is from the log only).

First: factor and duration per action.

## `danceBonusCivs`

- **Several dance buildings per player.** `getFirePit` (0x4819EF) returns the first
  `AbstractFirePit` only. Either sum the dancers of all buildings into one dance, or one dance per
  building with the strengths multiplied. *medium*
- **Dance buildings that are not fire pits:** an own marker instead of `AbstractFirePit`. *small*
- **Dancer weights:** the strength is `exp^n + mult·n − 1 + base` with a villager 1 and any other
  unit 2 (0x9D665C). Weights per type and a cap on counted dancers. *small*
- **New dance kinds.** `UnitModification` already works for any civ and any `ModifyType`
  (`BuildingWorkRate` included with `buildingWorkRateAuras`): document it with an example, it is
  data. Code is needed for kinds that are not a unit stat: a flat resource trickle, cost
  reduction, conversion resistance, `Gathering` per resource (#32). *medium*
- **Regeneration:** the 3.5 s idle wait is a literal; make it configurable or reuse the
  `healNonIdle` marker. *small*
- **Strength in the tooltips** of all four kinds (only XPTrickle reads it today). *small*
- **Switch delay or cost** to stop dance micro. *small*
- **Local dances with a radius** through the aura machinery. *large*
- **Outside the DLL:** the AI dances only in its native-civ XS logic; a listed civ needs its
  personality to dance. Upstream's `nativeCivs` patches the later compares of the same functions
  and can share these hooks.

First: several buildings, weights, then new kinds.

## `noAILimit`

- **Sort by displayed name** (the `nameID` string) or a `<sortkey>`, not by file name. *small*
- **`append` mode:** keep the 14 stock personalities in stock order, add the files after. Likely
  what WoL's `noAILimitV2` does (it hooks 0x603C34). *small*
- **Subfolders** (`AI3\<mod>\*.personality`) and **hidden** files (`_` prefix or `<hidden>`). *small*
- **Filter by the civ chosen** in setup (`forcedciv`). Touches the setup UI. *medium*
- **A "Random" entry** over the folder, if stock has none for personalities. *verify*
- **Validate at startup:** `<script>` exists, `nameID` / `tooltipID` resolve, `forcedciv` is a
  civ; log the broken ones. *small*
- **Test a long list** (40–50 files): dropdown scrolling, any stock cap (the stock table had 14
  slots on the stack). *verify*
- **Hash of the list in the log** for multiplayer mismatches. *small*
- Scripts per personality already work (`<script>`); subfolders for them and the XS error log
  are the missing pieces. The AI player count and difficulty levels are other functions.

First: validation and `append` with display-name order.

## `spreadAnyAccuracy`

- **Cover `InstantBallistics` and `TargetGround`:** 304 and 122 of WoL's 647 spread actions never
  reach the hook; today the key serves only shotguns. *medium, RE*
- **Remove the `ballisticPrecalcHits` dependency** and cover shots with no target unit. *medium*
- **Warn at load** for a marked action without `<DamageArea>` (it deals no damage); a default
  impact radius so a pellet landing on a unit hits it. *small*
- **`NumberProjectiles`:** N projectiles per shot, each with its own landing point and area,
  damage split. Real pellets, visible. *medium*
- **Spread shape:** stock draws a square (per-axis); `<SpreadShape>` circle, gaussian, or a cone
  along the firing line with lateral and depth values. *small*
- **Damage falloff** with distance from the landing point; `<MinSpread>`. *small*
- **Modifiable by techs:** `MaxSpread`, `SpreadFactor`, accuracy as `Data` subtypes (#45). *small
  with the registry*
- **Per-action flag** `<SpreadAlways>` instead of a per-unit marker (a unit with a shotgun and a
  grenade is marked whole). *small*
- **UI:** spread range and pellets in the stat panel through the `showGatherRate` row hook.
- **Pending tests:** multiplayer, saved games, area damage of ground shots near allies.

First: `InstantBallistics`.

## `techPrereqRecheck`

- **Event-driven instead of polling.** Hook unit creation (site known from `ForceToGaia`) and
  death (`damageOverTime` wraps it) and call the stock `setDirty` (0x506A41) for the owner only
  when the unit's type is named by some `<TypeCount>`. Zero cost when nothing happens, same
  update reaction, no `N` parameter. Build a watched-type bitset at tree load. *medium*
- **Other prerequisite kinds:** the type byte says `TypeCount` is 0 and there are more; inventory
  them and find which depend on inputs that never mark the tree. *RE*
- **Team or enemy counts:** `player='team|enemy'` on `<TypeCount>`, hooks in the evaluator
  (0x8EE8E7) and the XML handler (0xA14125). "When the rival has 5 cannons…". *medium*
- **Weighted counts** (infantry 1, cavalry 2) for "army size" thresholds. *small*
- **Hysteresis for `Volatile` techs:** instant rechecks make a tech flap when a count oscillates
  at its threshold; a minimum interval per tech or an exit threshold. A new risk the key
  introduces. *small*
- **KB null guard:** the TypeCount evaluator does not check `[player+80h]`; make sure the check
  never reaches a player without a KB (Gaia, resigned). *small*
- **One recheck per player and update** when several techs change (free with the event version).
- **Player message** when such a tech activates; **validation** of `<TypeCount>` attributes at
  load (stock drops them silently); retire `full` from releases; re-measure with WoL's full tree.

First: the event-driven version and the hysteresis.

## `abilitySlots`

- **Count buttons, not records.** A disabled ability still uses a slot, so N must be at least the
  longest list. Loop until N *visible* abilities are collected; N becomes "max buttons". *small*
- **Recharge on the button** or "ready in 12 s" in the tooltip; the per-player charge and period
  were located for the ceasefire. *medium*
- **Locked abilities greyed** with the requirement in the tooltip, instead of hidden. *small*
- **Order:** a position tag in the record, or "enabled first". *small*
- **A second page** ("more" button): the grid stays 6×6 and what does not fit is not drawn. *large*
- **Wonder panel** reads only the first 8 abilities (noted in `wonderPanelSkipAuras`). *small*
- **Hotkeys** for abilities past the 6th (keymap goes by grid position); let
  `customHotkeyContexts` assign them. *verify*
- **Mechanics, if WoL wants them:** per-unit charges instead of per-player (simulation; the same
  piece the White House "state points" need); auto-cast toggle (local, sends the same command).
- **Tests:** the monk's `AlwaysDisabledInGrid` aura at position 7 (WoL's real case); two players
  with different N (should be harmless, UI only).

First: count buttons, then recharge on the button.

## `lifespanAfterConstruction`

- **Transform at expiry instead of dying:** `<LifespanTransformProto>`, applied through the
  in-place transform (0x9C754C, keeps the unit ID). What WoL's `*Maturing` buildings want; DE's
  `DeadTransform`. *medium*
- **Refund or spawn at expiry** (DE `ResourceReturn`; a camp that dissolves into units). *small*
- **Reset on transform:** verify what the countdown does when a tech changes the proto; take the
  new proto's `Lifespan` or drop it. *verify*
- **More hold conditions** by cfg: while garrisoned, while a villager works on it, while a type is
  nearby, while repaired; restart on repair or tech. "Buildings that live while tended". *small*
- **Auras on remaining life** (`ModifyType` through the registry); a "feed" ability that adds
  seconds through a `Lifespan` tech effect (data). *small*
- **Countdown in the stat panel** and a floating warning at 10 s. *small*
- The `FadeInOnCreation` + `AlphaFadeLifespan` stock limitation could be lifted if WoL hits it.
- Keep it stateless (it reads stock state, so it survives a load); store new values in proto
  tags, not DLL memory.
- **Tests:** multiplayer, a building transformed mid-countdown.

First: transform at expiry, countdown, hold conditions.

## `techRenameEffect`

- **Undo on deactivation:** store the original IDs per player and tech, restore when the carrier
  deactivates ("while you have X" renames). *small*
- **Cover the in-game help (F1)**; home city and out-of-game screens stay stock. *medium*
- **Saved games:** the re-apply on load is a static reading; test it. *verify*
- **`newIcon`:** the entry holds the icon next to the three texts; a full per-civ retheme. *small*
- **`SetProtoText`:** name, description and icon of a proto per player (stock `SetName` renames
  one unit only). Same hook pattern on another table. *medium*
- **Priority between carriers** instead of "last applied wins". *small*
- **Extract `AddTechEffectType`** (cross-cutting) before adding more effects.
- **Tests:** multiplayer (rename rides on tech activation, deterministic), an observer.

First: the generic effect registry, then undo and icon.

## `noCorpseDopples`

- **Expiry instead of instant removal.** The noted limit (a live animal doppled, then killed out
  of sight, shows alive until the spot is seen) is best fixed with `expire N`: dopples of marked
  types fade N seconds after creation. Removing on death would leak that someone killed it. Not
  for enemy buildings. *small*
- **`removed` option** for resources that leave the world (depleted mines, cut trees), with the
  same information caveat. *small*
- **Cleanup on load** of corpse dopples from saves made without the key (dopple manager
  `[world+330h]`, update 0x491961: scoping only). *RE*
- **`MutateDopples`** path: not used by stock or WoL; leave noted.
- **Expiry per type as a general rule** (mobile units fade, buildings stay), with the alpha fade
  scheduler `lifespanAfterConstruction` knows. *small*
- **Tests:** multiplayer with the key on one side (dopples are game state), shared vision between
  allies, an animal converted out of sight.

First: expiry.

## `startingTC`

The guide lists what still looks for the `TownCenter` proto; close that list:

- **Age-up** (`uiPoliticianUI` and the progress display): without it a civ with a Pa or Presidio
  cannot age from its building. *medium*
- **Start camera.** *small*
- **Engine AI main base** (0x4CF222); the XS scripts are WoL's part (a tagged AI got its Market
  and settlers, then stayed idle). *small*
- **`trPlayerToggleAllowTCSpawning`** gate on `Maintain`. *small*
- `CoveredWagon` build limit, Town Center repair cost. *minor*
- **Better replacement rule:** when the first town center dies, pick among the live marked
  buildings (oldest or nearest) at once instead of waiting for the next one added; option for a
  later `TownCenter` to replace a provisional marked building. *small*
- **Merge with `civFirstTC`** into `firstTC`, with a table "which TownCenter check follows what".
- **Tests:** multiplayer, a converted Town Center, `FirstTC` in `hcShipmentPointFallback` with
  `startingTC`, a Nomad start through the editor.

First: age-up and the camera.

## `civFirstTC`

- **One tag does it all:** derive from `<firstTC>` the `StartingColonyBuilding` flag, the
  `colonies.xml` start type and the shipment point, instead of three data edits plus a cfg line.
  *small*
- **Test the `TownCenter` flags** a Market lacks (`ColonyPlacementCenter`, `HasGatherPoint`,
  `AllowAutoGarrison`, `ShowGarrisonButton`) and grant the needed ones. *verify*
- **Nomad start:** a built `<firstTC>` proto becomes FirstTC; better, the civ's wagon offers its
  building instead of the Town Center. *medium*
- **`replaceAll="1"`:** substitute the proto wherever a Town Center is created for the civ's
  players (cards, techs, triggers), through the creation hook. Opt-in. *small*
- **`<firstTC map="water">`** per map type. *small*
- **Footprint:** warn in the log when placement fails because the building is larger than a Town
  Center. *small*
- **A bridge to XS:** expose each civ's FirstTC proto as a constant or function to the AI scripts
  (the game generates XS constants from data). *RE*
- The same out-of-scope list as `startingTC`.
- **Tests:** multiplayer, a real Nomad, recorded games, a building other than the Market.

First: derive the three data steps from the tag, then Nomad.

## `transformInventory`

- **Re-task the gatherer:** a villager on a crate whose type changes stops at its next tick and
  must be re-tasked; reassign it to the new type or re-issue the order. *small*
- **Decide in the data:** `inventory='rebuild|keep|scale|free'` on the `TransformUnit` effect,
  cfg as default (WoL has 64 such effects with different intents). *small*
- **`transformRefresh`:** one key that refreshes everything derived on an in-place transform:
  LOS, inventory, population count, build limits, garrison capacity, abilities, hotkey context,
  `Lifespan`, plus #41's timer. One code path for `TransformUnit`, revolutions, the trigger and
  `uiTransformSelectedUnit`. *medium*
- **`keepOnCapture`:** the owner-change path rescales each resource by `InitialResource` and
  zeroes unlisted types (a captured fattened cow loses its fattening). A stock oddity worth an
  option for livestock-stealing mods. *small*
- **Tests:** multiplayer, saved games, `scale` on a unit fattened above its initial.

First: re-task the gatherer, then the per-effect attribute.

## `noTrainNearEnemyTC`

- **Let a held trainer move.** Stock ignores move orders while a unit has a queue, so a held
  Daimyo can only wait or cancel. Lift that for marked units while held, keeping the queue. *small*
- **`refuse` mode:** reject the train order at once with the warning (like placement errors): no
  resources spent, and the AI's failed order makes its planner move on. *small*
- **Panel signal:** greyed train buttons or a tooltip line while held. *small*
- **Distance per type** (`near Stable=30 near FirstTC=65`), more than 4 `near` entries,
  foundations as blockers, centre-to-centre option, warning interval. *small*
- **Inverse rule `trainOnlyNearFriendly`:** units train only within X of an own building type
  (forward bases, supply lines). Same hook, inverted test. *small*
- **Performance:** the spatial query runs per train tick per marked unit; measure with WoL's
  marker set and cache the nearest blocker if needed.
- **Tests:** a foundation near the trainer, `FirstTC` with `startingTC`, a converted Town
  Center, multiplayer.

First: moving while held and `refuse`.

## `overhealHitpointBars`

- **Percentage techs leave a full unit at 99 %:** scale the reference by the same factor, as the
  key already does for auras. *small*
- **Minimized UI text stays white** (the gadget prints markup as text): colour by property. *small*
- **Group Health above 100 %** as an option. *small*
- **Techs that raise only the max** (`MaxHitpointsOnly` / `OverhealCapacity` subtype): today
  `Hitpoints` raises initial and max together, so no tech can widen the overheal room. *small with
  the registry*
- **`<DisplayHitpoints>`** as an explicit reference. *small*
- **Visual on the unit** (glow or particles above 100 %). *medium*
- **Hide the segment from enemies** (owner and allies only). *small*
- **Buildings and ships:** untested whether their bars use the same gadgets. *verify*
- **Cost:** the bar hook runs per unit per frame; measure with `perfStats` on `uhcbench25`.
- Merge the three keys into `overheal`.

First: percentage techs and the max-only subtype.

## `overhealSources`

- **Sources of any heal kind:** buildings, dances, powers, regeneration auras, matched by the
  source unit's type on every add-HP path, with per-path opt-ins (`area`, `regen`, `power`). *small*
- **Cap per source** (`AbstractMonk=100% Surgeon=105%`). *small*
- **Rate above 100 %** (half speed, or a cfg value). *small*
- **Own regeneration exceptions** (heroes regenerate to max). *small*
- **With `smartHealTargets`:** units below 100 % first, overheal after. *small*
- **`AddUnitType` effect** (cross-cutting): "your surgeons now overheal" as a card.
- **Tests:** multiplayer (simulation), the knocked-out hero case confirmed in the bed.

First: cap and rate per source, then the ordering with `smartHealTargets`.

## `overhealDecay`

- **Hold conditions:** no decay in combat, while garrisoned, or while a source healer is within X
  m (`holdNear <type> <m>`). Removes the "the monk re-heals it" micro. *small*
- **Curve and rate per type:** percent of the remaining overheal, accelerating, `Musketeer=2
  Hussar=4`. *small*
- **Floor other than 100 %** (100 % + N). *small*
- **Start decaying on transform** (today it waits for the next gain). *small*
- **Saved games:** the delay since the last gain lives in the DLL; persist or document. *small*
- **Tests:** multiplayer (game-time, deterministic).

First: hold conditions.

## `showGatherRate`

- **Groups:** the sum per resource of the selection ("12 settlers: Food 8.0/s"). *small*
- **Immediate rate:** compute from the proto and modifiers (what the gather tick does) instead of
  waiting 1–2 s for the first loop; also show an idle villager's rates per resource (DE tooltip).
  *small*
- **Player income:** `{playerGatherRate(food)}` with gatherers plus trickles, for an income per
  minute tooltip. *medium*
- **Fix the stock data refs** `{currentUnitGatherRate}` / `Float` (WoL's UI already uses
  `{currentUnitGatherRate(gold)}`). *small*
- **Row position** configurable (WoL's panel has 5 rows). *small*
- **Buildings:** show the effective `BuildingWorkRate` with auras and techs (limit noted in
  `buildingWorkRateAuras`). *small*
- **RE:** the stock selection byte the row depends on.
- **Tests:** whole-number rates, `<UnitType>`, `DoNotShowAutoGatherRate`, the editor's ObjectInfo
  panel.

First: groups and the immediate rate.

## `buildingWorkRateAuras`

- **Build, repair and heal speed** (action rates), overlapping #11. *medium*
- **UI:** effective rate in the stat panel; a tooltip line for the new `ModifyType`. *small*
- **`AddModifyType` registry** (cross-cutting). *small*
- **`NoStack`** (+ `ForbidUnitType`, `ModifyTargetLimit`): without it, several carriers of the
  same aura multiply (×4⁵). *medium*
- **Slowing auras on enemies:** a 0.5 multiplier is a siege aura, 0 halts production. Check the
  getter for division by zero and infinite queue times; document as a mechanic. *verify*
- **Powers:** `unitModify` with `BuildingWorkRate` works by static reading only; confirm (it is
  the path for timed "decrees"). *verify*
- **Cost:** the getter walks the modifiers at four call sites; measure with many buildings, cache
  per unit and update if needed.
- **Tests:** multiplayer.

First: `NoStack`, then the registry.

## `bufferedFileReads`

The key does its job; these are the next steps of the performance plan.

- **Zero-code A/B first:** `-demandLoadMeshes`, `megaPostLoadForceTextures` (does the game discard
  and rebuild meshes?). *verify*
- **Find the granny call** that takes the remaining slow-frame samples (resolve `granny2.dll`
  exports as for `ntdll`). *RE*
- **`preloadList <file>`:** load at the loading screen what `perfFileLog` saw opened mid-match.
  Costs memory; needs `set_laa.py` first. *medium*
- **Read-ahead on a worker thread:** the 17,797 remaining Windows reads still fall inside frames.
  *small*
- **Buffer size per extension**, with per-file statistics in the log at exit (buffered vs real
  reads). *small*
- **Memory-mapped `.bar`** as an alternative, only with LAA. *medium*
- **Thread safety:** the sound mixer reads on another thread; a lock per handle, and `verify`
  run with sound on. *verify*
- **Loose files edited while running** may be served stale: document or invalidate by mtime.
- **Pending:** a multiplayer game with the key on one side; a timed load with and without.

First: the cfg A/B and the worker-thread read-ahead.

## `hcShipmentPointFallback`

- **Entries before the stock list, or `replace`.** *small*
- **Abstract types in the list** (`AbstractTownCenter`, markers). *small*
- **Selection criterion** among candidates: nearest to the previous point, or most recently
  built (both deterministic). *small*
- **`prefer` mode:** re-evaluate when a better-ranked building is finished, respecting a flag the
  player moved. *small*
- **Last resort when nothing qualifies** (today the shipment is lost silently): any live
  building, the Explorer, or the start position, plus an on-screen warning. Default: the
  Explorer. *small*
- **Water shipment point and consulate drop point:** same design, other sites. *medium*
- **`<shipmentPoints>` per civ in `civs.xml`**, like `<firstTC>`. *small*
- **Tests:** the no-stock-building case in game (read from code only), water, a converted
  centre, multiplayer.

First: the last resort with a warning, and `replace`.

## `healNonIdle`

- **`moving` / `fighting` separately** (both tests sit in the same block). *small*
- **Reduced rate on busy targets** (`busyRate=50%`), the balance knob. *small*
- **"In combat" as a `smartHealTargets` criterion.** *small*
- **Regeneration in combat:** the own regeneration and the dance require 3.5 s idle; the site is
  known. A marker for heroes or beasts. *small*
- **Building area heals:** check whether they require idle targets; if so, the "field hospital"
  is the same change on another path. *verify*
- **Follow the target** (escort mode) when it walks out of range; healing while the healer itself
  moves is the larger version. *medium / large*
- **`AddUnitType` effect:** "your surgeons now heal in combat" as a card.
- **RE:** the per-player case `[player+4FCh]` in the idle test.
- **Tests:** multiplayer.

First: the reduced rate and the moving / fighting split, then regeneration in combat.

## `smartHealTargets`

- **Weighted score** instead of strict lexicographic order (type, HP ratio, missing HP,
  distance, in combat), defaults reproducing today's order. *small*
- **Missing HP** option for artillery or building healers. *small*
- **Start threshold** (only targets below 90 %), per listed type. *small*
- **Exclude types** (`-Settler`). *small*
- **Safety:** prefer targets without enemies nearby (the spatial query `noTrainNearEnemyTC`
  uses). *small*
- **Switch target mid-heal** when another candidate is much worse, with hysteresis. *small*
- **Per-healer lists** (`Surgeon: AbstractInfantry`, `AbstractMonk: AbstractHero`); a `range`
  option. *small*
- **Tests:** multiplayer (deterministic by design); measure with many healers.
- Doc: the guide section repeats the "New in this DLL" line twice.

First: switching with hysteresis and the safety weight.
