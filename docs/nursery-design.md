# Nursery mechanic: design (draft, waiting for approval)

Request #107 in [wol-requests.md](wol-requests.md), JTMaston, 2026-11-25, thread "Nursery mechanic". Provisional key name
`nurseryFactor`. Nothing is built yet: this page is the design and the questions, for the user to approve before the
prototype. Private doc.

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
- The per-player values (max, interval, step) live in the DLL, so they must come back after a load. **Open, to settle
  in the prototype:** the docs disagree on whether the load runs Data effects again. REA today: the pass after a load
  0x94DDEA (one caller, 0x94CCB5) runs only effects with flag 20h in `[effect+9]` (REA `ev_1fbf0dc8…`), and no stock
  code sets that flag on a Data effect (byte scan: the stock constructors write 28h, kind 8 "general"); the guide says
  of `researchGrants` and `costEscalationTechs` that "the load applies the techs again", the second one seen in a log.
  The prototype logs a save and a load. If the handlers do not run, these subtypes set flag 20h, as `unitTypeTechs`
  does, so the pass re-runs them on the fresh table. **The same question applies to `researchGrants`' Interval and Max
  techs today** (a possible bug there, to check with the same test).

### 3.7 Order, determinism, cost

- `kFeatures`: after `autoGatherScaleByContained` (shared getter filter) and after `incomeRates`.
- Everything is simulation state read on every machine: unit IDs in ID order, game time, the techs. The UI is display
  only.
- Cost: per world update, the sweep's 256 slots and one marker write per building that changed; one compare per
  AutoGather rate call. An A/B with `perfprobe.py` and many nurseries is part of the test plan.

### 3.8 Not covered by the first version

- Transform and owner change: the factor stays on a converted building (same unit ID); a transform in place keeps it
  if the new proto is a nursery too, clamped to its max, else it is dropped (Q5).
- XS calls (`xsGetUnitNurseryFactor(unitID)`, a setter) for the AI or triggers: easy with `AddSyscall`; only if asked.

## 4. Test plan (after approval)

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
