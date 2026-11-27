# Nursery mechanic: design and prototype

Request #107 in [wol-requests.md](wol-requests.md), JTMaston, 2026-11-25, thread "Nursery mechanic". Provisional key name
`nurseryFactor`. The user approved this design on 2026-11-25; the prototype follows it with the simplest reading of
each open question (section 6). Private doc.

## 1. The request, in short

A building or unit trickles resources, into its own inventory or to its owner, and the trickle is multiplied by a
**factor**:

- the factor is never negative and starts at 0 (or the proto's initial value); it may have a maximum;
- techs raise or lower it by whole steps, and it grows by itself with time, linearly or exponentially;
- techs change the maximum (time does not), and the seconds a step of growth takes;
- the defaults are in the unit's proto; the current value belongs to each building, the maximum and the initial value
  are shared (per player);
- the UI shows `current/max` and a name ("minks"), with a two-line rollover, both strings set by the modder:
  "X out of Y minks." and "Produces one mink every Z seconds.";
- a tech can ship `FreeHomeCityUnit` units multiplied by the factor, and may then empty it.

Example: a mink nursery trickles 0.5 gold per mink, up to 10 minks (0 to 5 gold/s). A tech ships a crate of gold per
mink and resets the factor to 0; another takes minks 2 by 2 and ships units for them.

## 2. What already exists (observed, with evidence)

| Need | What the engine or the DLL already has |
|---|---|
| The trickle itself | The stock **AutoGather** action. Its update (FUN at 0x48D13E) asks the rate getter **0x49EBE4** `float thiscall(unitAction, resource)` for each resource and multiplies by the elapsed time (REA `ev_5139cd96…`). |
| Trickle to the owner | The same update pays the player with the add 0x49A98A (return 0x4C379D), which `incomeRates` already counts (docs/engine-symbols.md, "AutoGather pay"). |
| Trickle into its own inventory | Stock too: the tactics tag `<AddResourcesToInventory>1</AddResourcesToInventory>` sets bit 4 of the action's flags (handler 0x5FC84D, `or byte [eax],10h`), and the update then adds to the unit's own resource list with 0x49A5E6, capped by the carry capacity 0x494503 when the proto asks for it (REA `ev_758c1502…`; capstone). Not run in game yet. |
| A multiplier on the AutoGather rate | `autoGatherScaleByContained` already hooks the head of 0x49EBE4 (`hooks/gatherscale_hooks.asm`). Every reader goes through it: the update and both unit panels (0x6992BD, 0x69B005), so the panel's rate row shows the multiplied rate. |
| Per-unit number that survives a save | `savedmarkers.h`: four raw dwords on an unread stat modifier, saved and loaded by the modifier class. Stats 60h..6Ah are taken; **6Bh is free**. `researchGrants` keeps points and a timer per building exactly this way. |
| Proto tags | `AddProtoTagHandler` (`prototags.*`). |
| Per-step tick | `AddWorldTick` (`worldtick.*`), game time `[world+108h]`. |
| Tech values per player's proto copy | `AddTechSubtype`, as `researchGrants`' `ResearchGrantInterval` / `ResearchGrantMax` (value function 0x7F892A, every relativity and the removal). |
| Shipment multiplied by a number | `shipmentCounts`' `FreeHomeCityUnitByShipmentCount`: a Player-target subtype (`AddTechPlayerSubtype`) that becomes the stock `FreeHomeCityUnit` (37h) with amount x count. |
| UI | `AddUnitPanelRow` (minimized interface), the stat panel row of the normal interface as `showGatherRate` does it, `AddDataRef` for a `{uhc…}` text in WoL's own layouts, `minUIStats`. A gadget's help text `[gadget+68h]` shows on hover (how-it-works, `politicianEnablesTech`). |

**Closest existing key: `researchGrants`** (a building gains points over time up to a cap, techs change the interval
and the cap, a tech gives points, a panel row, saved markers). `nurseryFactor` follows it.

**How DE does it (read-only; leads only).** A full REA analysis of `AoE3DE_s.exe` does not finish (2026-11-05) and much
of it is encrypted, so this is a byte search of its strings, not a code reading. It names `TrickleByUnitType` (a Data2
trickle per unit of a type, already in de-parity #24), `ActionTrickle`, `InventoryRate`, `AutoGatherInventoryIfNotSocketed`,
`DEAccumulateUnitCount` and `TransformPropagateChargeState` (ability charges). Nothing there names a per-building
factor with a cap and growth; that is not proof DE lacks one. Nothing of DE goes into the repo or the DLL.

## 3. Design

### 3.1 The proto block

Flat tags, as the other keys' (`ResearchGrant*`). Only `NurseryFactorMax` is required: it marks the proto.

```xml
<Unit name='MinkNursery'>
  ...
  <NurseryFactorMax>10</NurseryFactorMax>              <!-- the cap, a whole number >= 0 (0: no cap? see Q8) -->
  <NurseryFactorInitial>0</NurseryFactorInitial>       <!-- the value of a new building (default 0) -->
  <NurseryFactorInterval>30</NurseryFactorInterval>    <!-- game seconds per growth step (0 or absent: no growth with time) -->
  <NurseryFactorStep>1</NurseryFactorStep>             <!-- the size of a step (default 1) -->
  <NurseryFactorGrowth>linear</NurseryFactorGrowth>    <!-- linear or exponential (see Q1) -->
  <NurseryFactorName>90001</NurseryFactorName>         <!-- string ID, or plain text: "minks" -->
  <NurseryFactorRolloverCount>90002</NurseryFactorRolloverCount>  <!-- "{current} out of {max} minks." -->
  <NurseryFactorRolloverRate>90003</NurseryFactorRolloverRate>    <!-- "Produces one mink every {seconds} seconds." -->
  <NurseryFactorTrickle>1</NurseryFactorTrickle>       <!-- 1: the factor multiplies the proto's AutoGather (default); 0: a counter only -->
</Unit>
```

- The trickle is the proto's own **AutoGather** action (`<Rate type='Gold'>0.5</Rate>` in its tactics), so the rate,
  its techs (`WorkRate` on AutoGather) and the destination stay stock:
  - **to the owner:** a plain AutoGather;
  - **into its own inventory:** the same action with the stock tactics tag `<AddResourcesToInventory>1</AddResourcesToInventory>`.
  No new tag is needed for either. The factor multiplies what the rate getter returns, so 0 minks pay nothing.
- The rollover strings take named placeholders: `{current}`, `{max}`, `{name}`, `{seconds}`, `{step}`. A number is a
  string table ID (so WoL can translate them); anything else is the text itself. Defaults:
  `{current} out of {max} {name}.` and `Produces {step} {name} every {seconds} seconds.` (the second line is left out when the
  factor does not grow with time, or is full: see Q9).
- Tags are read once per data load, by proto ID, the same for every player (as `researchGrants`).

### 3.2 Each building's factor

- A whole number from 0 to the player's max, per unit, kept in a DLL table by unit ID and mirrored in a saved marker
  (stat 6Bh: word 0 a tag, word 1 the factor, word 2 the growth timer in ms, word 3 spare). A loaded game reads the
  markers back once; a building that dies loses its factor.
- **Growth with time:** after each world update, each living, **built** unit of a tagged proto adds the game time that
  passed to its timer; each full interval adds one step, up to the max. At the max the timer waits at 0. A foundation
  does not grow and shows `0/10 once built`.
- **Linear:** `factor += step`. **Exponential:** waits for JTMaston's answer (Q1); the simplest reading is
  `factor += max(step, floor(factor x rate))`, so it can leave 0.
- Units are found by the sweep `researchGrants` uses (256 slots of the world table per update; the whole table once on a
  new or loaded game), so the cost does not grow with the map.

### 3.3 The trickle

- The AutoGather rate getter 0x49EBE4 already has one hook (`autoGatherScaleByContained`). It becomes a **shared
  filter list** (`AddAutoGatherRateFilter`, new `autogatherrate.*`; no second `jmp` at the site): that key's
  contained-count rule first, then `nurseryFactor`'s multiplication by the unit's factor. Both keys' order goes in
  `kFeatures`.
- The check in the hook is one look-up in a per-proto-ID bit table, so an AutoGather unit without the tag (every Market,
  Bank, Factory) pays one compare.
- `incomeRates`: an owner trickle already goes through the add it counts, so it shows in the global income with no extra
  code. A trickle into the building's inventory is not income (it is still in the building) and is not counted.
- `resourceDebt` hooks the end of the same getter (0x49EE07), a different site: no conflict.

### 3.4 Tech effects

All `type='Data'`, relativities as stock (`Absolute`, `Assign`, `Percent`, `BasePercent`).

| Subtype | Target | What it does |
|---|---|---|
| `NurseryFactor` | ProtoUnit | Adds `amount` (Absolute, may be negative) to, or sets it (Assign) on, the factor of each of the player's built units of the proto, clamped to 0..max. Applied at the next world tick. Once: a load never applies it again. |
| `NurseryFactorMax` | ProtoUnit | The player's max. A building above a lowered max is cut to it (Q7). |
| `NurseryFactorInterval` | ProtoUnit | The player's seconds per step. |
| `NurseryFactorStep` | ProtoUnit | The player's step (optional; JTMaston named only the interval). |
| `FreeHomeCityUnitByNurseryFactor` | Player | The stock `FreeHomeCityUnit` with `amount x` the factors of the player's units of `nursery='<proto or type>'`. Option `consume='all'` empties those factors; `consume='2'` takes 2 per building and ships for what it took (Q2, Q3). |

```xml
<Effect type='Data' amount='1.00' subtype='FreeHomeCityUnitByNurseryFactor' unittype='CrateofCoin'
        nursery='MinkNursery' consume='all' relativity='Absolute'>
    <Target type='Player'/></Effect>
<Effect type='Data' amount='5.00' subtype='NurseryFactorMax' relativity='Absolute'>
    <Target type='ProtoUnit'>MinkNursery</Target></Effect>
```

- The units come the stock way (the home city gather point, the same checks), as `FreeHomeCityUnitByShipmentCount`.
  At the nursery instead would be new work (Q4).
- The AI gets and spends factors as players do: the effects run for whoever researches them.

### 3.5 UI

- **Unit panel:** a row `Minks` `3/10` (the name as label, the fraction as value), in both interfaces: the minimized
  one through `AddUnitPanelRow`, the normal one in the stat panel as `showGatherRate`. While the building grows:
  `3/10, next in 14s`? (Q9). Full: `10/10`. A foundation: `0/10 once built`.
- **Rollover** of that row: the two lines of §3.1, one per line. Bullets ("•") only if the game's font has the glyph;
  else a dash. To check in the prototype: that the stat panel's row gadget shows a help text on hover.
- **Data ref** `{uhcNurseryFactor}` (the fraction and the name of the selected unit) for WoL's own layouts and
  `minUIStats`.
- **Rollover of the proto** (the train button, the unit's info): a third place JTMaston may want ("used for rollovers
  and in the unit UI"); not in the first version unless he says so (Q10).

### 3.6 Saved games

- The factor and the timer of each building: the marker (stat 6Bh), as `researchGrants`.
- One-shot effects (`NurseryFactor`, the shipment) must never run again on a load: they are queued and applied by the
  world tick, and the first tick of a loaded game drops a queue built before it.
- The per-player values (max, interval, step) live in the DLL, so they must come back after a load. **Settled in game
  (2026-11-25):** the load runs every ProtoUnit Data effect of the active techs through the handlers again, before the
  first world tick, so the values come back with no flag 20h. That replay is not the pass 0x94DDEA (REA `ev_1fbf0dc8…`,
  flag-20h effects only); its caller is not identified. It goes in the order of the techs in the techtree, not the
  order they were researched: `Assign 4` researched before `+5` came back as 4 instead of 9. `researchGrants`'
  `ResearchGrantMax` came back the same way (2 -> 6 in the replay): **no loss there.** A Player-target effect (the
  shipment) did not run again. The `NurseryFactor` effect did, and the first tick dropped it, as planned.

### 3.7 Order, determinism, cost

- `kFeatures`: after `autoGatherScaleByContained` (shared getter filter) and after `incomeRates`.
- Everything is simulation state read on every machine: unit IDs in ID order, game time, the techs. The UI is display
  only.
- Cost: per world update, the sweep's 256 slots and one marker write per unit with a factor; one C call and a byte
  lookup per AutoGather rate call. An A/B with `perfprobe.py` and many nurseries is part of the test plan.

### 3.8 Not covered by the first version

- Transform and owner change: the factor stays on a converted building (same unit ID); a transform in place keeps it
  if the new proto is a nursery too, clamped to its max, else it is dropped (Q5).
- XS calls (`xsGetUnitNurseryFactor(unitID)`, a setter) for the AI or triggers: easy with `AddSyscall`; only if asked.

## 4. Test plan

WoLReal5, a test nursery on a public civ: the factor grows and stops at the max; the gold matches the hand count
(rate x factor x time); two buildings with different factors; each tech changes what it should; the shipment ships
factor x amount and empties the factor; a save and a load keep each factor and each tech value; the key off: stock
AutoGather; A/B with `perfprobe.py` and 30 nurseries; the AI still compiles; GIF and a control.

## 5. Questions for JTMaston

The English text sent to him is in `_share/maston-20261125/N/` and `wol-fixes/reply-to-maston-20261125-N.txt`.

1. **"Exponential":** does each step add a share of the current factor (more minks breed faster: 4 → 5 → 6 → 8 → 10),
   does the step itself grow (1, 2, 4, 8…), or does the time between steps shorten? And from 0, should it start (one
   first step) or stay at 0 until a tech adds one?
2. **The shipment with several nurseries:** does it ship for the sum of all the player's nurseries' factors? Does
   "reset to 0" empty all of them?
3. **"Decrease 2 by 2":** per building (each nursery gives 2 minks and ships 2 crates) or 2 in total? A nursery with 1
   mink left: does it give 1, or nothing?
4. **Where do the shipped units appear:** at the home city gather point (as every shipment), or at the nursery?
5. **Owner change and transform:** does a captured nursery keep its minks? A nursery that transforms into another
   nursery proto: keep them (cut to the new max)?
6. **A tech that changes the factor:** all the player's nurseries of that proto, or only the one that researched it?
7. **A lowered max** (a tech): cut the buildings above it at once, or let them keep the extra until they lose it?
8. **No max:** should a nursery without a cap exist (`NurseryFactorMax` 0 or absent)?
9. **The panel while it grows:** just `3/10 minks`, or also the time to the next one (`3/10, next in 14s`)? And when
   full, is the second rollover line still shown?
10. **Rollovers elsewhere:** should the train/build button's rollover of the nursery also show the max and the rate?
11. **Global income:** a trickle to the owner shows in the global income rates (it already would). A trickle into the
    building's own inventory does not, as it is not in the stockpile yet. Is that what you want?
12. **Whole numbers:** the factor is always a whole number (minks), with `Percent` techs rounded down. Right?

## 6. The prototype (2026-11-25)

Key `nurseryFactor [log]`, [modding guide](modding-guide.md#nurseryfactor), [how it works](how-it-works.md#nurseryfactor).
Built as sections 3.1 to 3.6, with these readings of the open questions until JTMaston answers:

| Question | Reading in the prototype |
|---|---|
| 1 Exponential | a step adds `max(step, floor(factor x NurseryFactorGrowthRate))` (default rate 0.25), so it leaves 0 |
| 2 Shipment, several nurseries | the sum over the player's living, built units of `nursery` (a proto or an abstract type); `consume='all'` empties all |
| 3 "2 by 2" | per unit, at most N: one with 1 left gives 1 |
| 4 Where units appear | the home city gather point (stock `FreeHomeCityUnit`) |
| 5 Capture, transform | kept (same unit ID); a transform into a tagged proto keeps it, cut to the cap; into another, dropped |
| 6 Which buildings a factor tech hits | all the player's built units of the proto |
| 7 Lowered max | cut at once |
| 8 No max | not possible: `NurseryFactorMax` 0 is a cap of 0 |
| 9 Panel | `Minks 3/10`; the second rollover line whenever the interval is above 0 |
| 10 Other rollovers | none |
| 11 Global income | the owner's trickle is counted (stock add), the inventory's is not |
| 12 Whole numbers | yes, `Percent` rounds down |

Seen in game (WoLReal5, single player): growth and cap; the three value techs and the add; two units with their own
factors; gold 9.06/s against 9.0 expected; save and load (21 minks and the timers kept); the load's replay of the Data
effects (3.6); the shipment in a skirmish (4 and 14 crates); the panel row and its rollover; 40 units A/B (update
0.1 ms both); the trickle into the unit's own inventory (4.96 gold/s held at 10 minks, with a gold `<CarryCapacity>`
of 500; without one the Bank stored nothing, the stock cut at the capacity); exponential growth (1, 2, 3, 4, 6, 9, 10
with rate 0.5); a German AI played on (a Manor and 10 settlers at 2 min).

Departures from the design: the panel row is only in the minimized interface (the normal stat panel needs its own hook,
as `showGatherRate` has), and it replaces the stock AutoGather rate row for a single selected unit with a factor.


## 7. JTMaston's answers and the second version (2026-11-26)

His answers to section 5, and what the second version does with them (agent N2, plan `ronda-20261126`, part 3):

| Question | Answer | Second version |
|---|---|---|
| 1 Exponential | "a basic f(t)=b^t, where t increases by 1 with each iteration of NurseryFactorInterval, starting at 0; b is an attribute we can set in the proto; the result is added up to the building's current factor" | `<NurseryFactorGrowthBase>` (default 2) and the Data subtype of the same name; step t adds b^t, the fraction carried to the next step; t per unit, saved (marker word 3), back to 0 when the factor is emptied. `NurseryFactorGrowthRate` is gone. |
| 2 Shipment, several nurseries | yes and yes | as built |
| 3 "2 by 2" | a command like a market's buy and sell buttons: spend factor for units at the nursery, or resources for factor | `<NurseryFactorCommand factor cost unit count>Name</...>` and the UI syscall `nurseryFactorCommand("Name")` (below); `consume` of the shipment stays |
| 4 Where units appear | cards at the gather point, the commands' at the nursery | as built; the command's units on rings around the building |
| 5 Capture, transform | keeps the factor | as built; a transform no longer cuts to the new cap |
| 6 Which buildings a tech hits | all | as built |
| 7 Lowered max | "keeps the extra until they lose it" | no cut; growth and additions stop at the cap |
| 8 No max | "no, add a default value of 10" | default 10; any NurseryFactor tag marks the proto |
| 9 Panel | "Just X/Y \<string\>, dont add a 'next in Xs', we should generate a loading piechart" | `3/10 minks` in both interfaces; agent P's pie (`progresspie.*`) on the portrait while it grows |
| 10 Other rollovers | no | none |
| 11 Global income | yes | as built |
| 12 Whole numbers | yes | as built |

Added by him: `<NurseryFactorGarrisonUnit amount="X">ypGoat</NurseryFactorGarrisonUnit>`, a garrisoned unit of that
type removed at once for X. Built on the shared observer of the load of a unit into another (agent GC's
`garrisonobservers.*`, 0x9C26E1, also used by `garrisonConvert`): the observer queues, the world tick removes (0x4726B2,
the trigger `Destroy`'s call) and adds, up to the cap.

**How a button reaches the simulation.** A `protounitcommands.xml` command runs a console string on the local machine
only. The UI syscall sends the network command `uiTransformSelectedUnit` sends (type 17h, read with capstone at
0x7E7193: factory 0x5695FC, players 0x5683B9, units 0x5696E1, queue 0x568A1A), with `'NR' << 16 | index` where that
command carries the target proto ID (`[cmd+8Ch]`). Every machine runs its per-unit execute FUN_007D64F7 (vtable
0xB86F28 +54h) in the world update, after the command loop 0x7C86A4 checked that the command's player owns the unit; a
hook at its head takes the commands with the magic and runs the nursery's rule. No new network command type, no
cheat path. The buttons grey out with the reason (`AddPanelButtonFilter`).

**The normal interface's stat panel.** The row after the HP row, 0x4D76DB, is now a shared hook (`statpanelrows.*`),
first `overhealHitpointBars`' row, then this key's.

**Readings still open** (in the English reply, `wol-fixes/reply-to-maston-20261126-N2.txt`):
- t back to 0 only when the factor is emptied (a sale to 2 keeps t, so the next step can fill the nursery at once);
- a full nursery keeps a garrisoned unit inside instead of taking it for nothing; an addition is cut at the cap;
- the units of a command ignore the population cap, and a command with no room for all its units does nothing;
- the panel shows `3/10 minks` as one text (the stock rows are `Label: value`); the second rollover line stays while
  the nursery grows with time;
- a lowered cap: a tech that adds factor to a unit above the cap adds nothing.
- a matching unit of another player (an ally) that enters counts too.

Seen in game (WoLReal5, single player, 2026-11-26): all of the above; the stat panel row of the normal interface; a save
and a load keep `8/5` and t; 16 Banks A/B update 0.15 ms with and without; a skirmish AI ran.


## 8. The third version (2026-11-26)

JTMaston's answers to the six questions of the second version (`wol-fixes/reply-to-maston-20261126-N2.txt` and `-P.txt`),
and what agent N3 built (plan of 2026-11-26, part N3):

| Question | Answer | Third version |
|---|---|---|
| 1 `t` back to 0 only when emptied? | "make it follow the factor" | `t` is the largest t with `floor(S(t)) <= factor`, `S(t) = b^0 + ... + b^(t-1)`; the step adds `floor(S(t+1)) - floor(S(t))`. Worked out each time from the factor and the player's b, never stored (marker word 3 no longer read), so every change of the factor moves it. b 2: 0 -> t 0, 1-2 -> t 1, 3-6 -> t 2, 7-14 -> t 3. b 1: t = factor. b below 1: growth stops at the whole part of `1 / (1 - b)`. |
| 2 A full nursery keeps the unit; a partial fill is cut at the cap | "right" | as built |
| 3 Should a button's units respect the population cap? | "What units are we talking about?" | The units a `<NurseryFactorCommand unit count>` makes (crates have no population, but Settlers do). Read as `GarrisonConvertTo`'s new rule: refused when the cap would not hold them all (the stock maintain spawn's test), the button greyed with "Population cap reached", normal again when there is room. The clarified question is in the English reply. |
| 4 Hide the second rollover line when full? | "no" | as built |
| 5 An ally's goat counts? | "counts too" | as built; an ally's Settler was taken in game. A goat changes owner by itself to the nearest player's units, so an ally's goat at your nursery is usually yours already. |
| 6 The pie: A over the portrait, or B after the row? | "B" | An inline icon after `3/10 minks`, in both interfaces: 32 frames (`art\ui\uhc\pie\`, aoe3-blender-tools' `make_pie.py`, approved by the user 2026-11-26), square at the row's height (17 / 22 px at 1920 x 1080, 14 / 17 px at 1366 x 768). Without the frames, the portrait's pie (A). `garrisonConvert` keeps A. |

Seen in game (WoLReal5, single player, 2026-11-26): the log's `t` after a sale, a `consume='2'` shipment, a goat and the
Settlers button; the greyed Settlers button and its recovery with a House; an ally's Settler taken (a 3-player
scenario); the pie in both interfaces and at both sizes; a save and a load; 16 Banks A/B (update 0.2 ms both); a German
AI on a real map (20 Settlers, 3 Manors at 404 s), `trace_xs.py` with no error. Review pictures:
`_share/maston-20261127/N3/`.
