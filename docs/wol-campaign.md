# WoL campaign: why it does not work (status, 2026-11-13)

Private: not in `tools/export_public.py`'s INCLUDE list. The user reports that Wars of Liberty's
campaign does not work, and wants only WoL's own campaign in the menu (not Blood, Ice and Steel,
The WarChiefs or the tutorial). Evidence: `rea/evidence/age3y-b1a1dab7/wol-campaign-20261113/`
(gitignored): screenshots, the tracer logs `trace-loaderr*.log`, the compiled triggers
`trigtemp-mission*.xs`, `campaigncheck-wolreal3.txt`, `rea-evidence.json`, the profile backup.

**In one line:** every campaign mission fails to load with *"Scenario: wonders\first barbary war
failed to load."* (the font draws `_` as a space), with WoL's own DLL as with ours, because the
missions were saved with civs that WoL's `civs.xml` no longer has. It is a data bug, not a DLL
one. Fixed copies of the three missions are in `wol-fixes/campaign/`; with them the campaign
runs from the menu through all three missions to its end (each won by console, below), and
Laguna's removed units, its dead-at-start objective and its removed techs are repaired too.

## Results per mission

Beds: `C:\AoE3-UHC-WoLReal3` (our DLL) and `C:\WoL-Test` (WoL's DLL `c070d138`, with only the
`engine-ext` harness for `multipleInstances background`, `perfExecFile` and `xsErrorLog`).

| # | Mission | As shipped | Changed in `wol-fixes/campaign/` | Result with the fix (2026-11-13, our DLL, Easy) |
|---|---|---|---|---|
| 1 | Barbary Coast 1801 (`wonders\first_barbary_war`) | "failed to load", both DLLs | civ table; player civs (US Navy → UnitedStates, Barbary Pirates → Indians, Swedish Mining Operation → Swedish, Van Lesen → Dutch, Storage and Sunken Merchant Ship → British) | Starts from the campaign menu, runs (no XS error), first objectives discovered; won by `winScenario`, home city visit, node 2 unlocked |
| 2 | Laguna 1840 (`wonders\laguna`) | "failed to load", both DLLs | civ table; players 1–5 → Brazilians; 18 removed units and 6 `Army Deploy` parameters replaced; 3 removed techs mapped; `Age0Egyptian`'s Town Center effect made removable in `techtreey.xml` (objective unit 647) | Starts after node 1, intro text "Battle of Laguna, 1840", "Advance to the Capital Age" discovered, runs 5+ min (no XS error); won by `winScenario`, node 3 unlocked. With the final file and tech fix: Laguna's Town Center at 6 500 HP, no instant win or loss in 3 min |
| 3 | Hakodate 1869 (`wonders\battle_of_hakodate`) | "failed to load", both DLLs | civ table; player civs (Imperial Army → SPCJapanese, Ezo Republic and Matsumae → Japanese, Supply Ships → UnitedStates) | Starts after node 2, runs (no XS error, also with WoL's DLL); won by `winScenario`: back to the campaign screen with the three missions, no crash |

**Not done: the objectives were not played to their end.** Each mission was won with the console
command `winScenario` (it runs `trYouWin`, the same call the missions' own victory rules make), so
the victory, the home city visit between missions and the advance to the next node were tested,
but not each objective's trigger in order. The console cannot kill or convert an enemy unit, and
driving units there by console did not get far: `spawnUnits` and `uiWorkAtPointer` do move units
(30 spawned frigates sailed toward Barbary Coast's first storage, 25 mortars marched on Laguna's
Town Center), but they stopped out of reach of targets that the missions put inland or behind
water and fortifications. Playing the objectives needs a person at the mouse (about an hour per mission).
What fired on its own: the intros, the objectives' discovery, the AI's start, the trigger tech
and army parameters (in `Trigger3\trigtemp.xs`), and `_Obj6_Done` stays armed with its unit alive.
After the last mission the campaign ends on its screen with the three missions listed; the
definition has no closing cinematic or credits node, so there is none to play.

Videos (in the evidence folder; lossless masters in `rea/media-masters/wolcampaign-m*`):
`m1-barbary-start.mp4`, `m1-barbary-victory.mp4`, `m2-laguna-start.mp4`,
`m2-laguna-victory.mp4`, `m3-hakodate-start.mp4`, `m3-hakodate-victory.mp4` (a victory shows its
message, then the home city screen of the visit between missions).

### Laguna: the removed units

Laguna's players 1–3 were stored as civ 11 with the Italian home city, but every unit and
building they have belongs to WoL's Brazilian roster (`Age0Brazilian` enables `Volunteer`,
`Pasavolante`, `MountedCassador`, `Corvette`, `Housebrazil`), and the objectives speak of "the
Latin Americans" (age up with politicians, a post office, an immigrant colony). So players 1–5 are
set to **Brazilians**; Garibaldi keeps the Italian home city (his shipments, the Rome screen).

| Removed proto | Units | Replaced by | Why |
|---|---|---|---|
| `Carabinero` (mounted carbineer) | 15 placed (1 of player 1, 14 of São José do Norte) and 4 `Army Deploy` | `Jinete` | Brazilian roster's firearm maneuver cavalry (`AbstractGunpowderCavalry`, `AbstractRangedCavalry`): a carbine-armed horseman of the same era |
| `Bacamartero` (blunderbuss infantry) | 1 placed (player 1), 1 `Army Deploy` (player 1) | `WolJagunco` | Brazilian roster's "infantry armed with a blunderbuss" (*bacamarte* is the blunderbuss). The weapon matches, but a *jagunço* is a late-19th-century hired gunman of the Northeast, so it is an anachronism in 1839 southern Brazil; it is also an outlaw unit with pop 4. WoL has no regular blunderbuss infantry, so it stays |
| `RegimentalLancer` | unit 2676 and the `Army Deploy` (army `1,11`): player 1, Garibaldi's rebels | `Lancero` | The Farrapos' lancers were the *Lanceiros Negros*, light lance cavalry: WoL's `Lancero` |
| `RegimentalLancer` | unit 2787: player 3, São José do Norte (the Empire) | `Escolta` | An imperial regimental line lancer: "assault cavalry armed with a lance for killing standing units", 475 HP |

### Laguna: the objective unit 647

`_Obj6_Done` (*"Destroy Laguna's Town Center"*, objective 6) is active from the start and wins
the mission when unit 647 is dead. Unit 647 **is** Laguna's Town Center (live: `647 player 2
TownCenter`, at the objective's flag); an earlier offline reading paired each unit's ID with the
wrong record (the `EN` record with the ID comes before the `UN` record with the proto, inside one
`H1` chunk). As shipped, the Town Center loads with **0 HP** (player 2's copy of the `TownCenter`
proto: 0 maximum and initial hit points, against 6 500 for player 1), dies at once, and the
mission is won.

**Cause (tracer on the tech effect apply 0x94DAE1 and removal 0x94DCB2, `techtrace-laguna.log`;
REA `ev_6611243b…`).** While the scenario loads its players (FUN_00A09B47, from the scenario load
at 0x834FB3), each player N first has civ ID N, the N-th `<civ>` of `civs.xml`, and its age is
set: FUN_008D4E01 (set age) activates the age tech of each of the player's civs. Then the
scenario's own civ replaces it and that age tech is removed. Observed: player 1 gets and loses
`Age0Ethiopian`, player 2 `Age0Egyptian`, player 3 `Age0zulu`, player 4 `Age0American`, player 5
`Age0australian`, player 6 `Age0Canadian`; each then keeps `Age0Brazilian` (or its own). WoL put
the Egyptians second in `civs.xml`, and `Age0Egyptian` has `Hitpoints` `Assign` 0 on `TownCenter`
(Egyptians use another town center). An `Assign` is not undone on removal, so **in any scenario
player 2's `TownCenter` keeps 0 HP**, whatever civ the scenario gives player 2.

**Fix (data, `techtreey.xml`, one attribute):** that effect's `relativity ='Assign'` becomes
`relativity ='BasePercent'` (amount 0.00). While the tech is active the value is the base × 0, as
before; when it is removed the game recomputes from the base. Tested: unit 647 is a plain
`TownCenter` at **6 500 HP**, the objective's two `CinematicBlock`s (3196, 3197) are still there
after 3 minutes and `_Obj6_Done` does not fire (`m2-laguna-tc6500-3min.png`). The `IGCTownCenter`
swap of an earlier commit is dropped.

This is an **engine trap for every scenario**: player N always passes through civ N, so any
scenario where player 2 is not Egyptian loses player 2's `TownCenter` HP (and its
`PopulationCapAddition`, also an `Assign` 0 in `Age0Egyptian`, which this fix leaves as it is).

**The Egyptians keep working as before** (checked 2026-11-13, because the change reaches every
Egyptian game; Egyptians are meant to have no working Town Center and use `EGYtowncenterCARAVAN`):
- *Engine:* the effect value function 0x7F892A (REA `ev_3ce668d2…`): `Assign` writes the amount;
  `BasePercent` adds `base × amount − base`, i.e. `−base` for amount 0, and takes it back on
  removal. Applied to a `TownCenter` still at its base 6 500 it gives 0, the same as `Assign`; it
  differs only if something had raised the Town Center's HP before `Age0Egyptian`, the civ's
  first tech. Later Town Center HP techs add on top in both cases.
- *Skirmish, human Egyptians vs a German AI, original techtree then the patched one:* the
  Egyptian player's `TownCenter` proto has 0 maximum and 0 initial HP in both
  (`egypt-A-*-tcproto.txt`); the whole proto dumps differ in one word only, +70h, which varies
  between runs anyway (`egypt-A-*-p1tc-proto.txt`); the starting units are the same (Ali Pasha,
  5 villagers, `EGYtowncenterCARAVAN` at 6 500, the bazaar tent); the map's starting
  `TownCenter` dies at once in both (its `TownCenterObstruction` stays); `spawnUnits` gives an
  `Outpost` but no surviving `TownCenter` in both.
- *Skirmish, human Dutch vs the Egyptian AI (`wolAliPasha`), both techtrees, 4 minutes:* the AI's
  `TownCenter` proto 0/0 in both, its units the same in both (only its explorer's HP after a fight
  differs), no XS error in either. (In both runs the Egyptian AI had not grown past its 5
  villagers in 4 minutes: that is how WoL's AI plays them today, not an effect of the change.)

So the techtree change stays.

### Laguna: removed trigger techs

A trigger tech whose name is gone compiles to `trTechSetStatus(p, -1, 2)`, which does nothing
(no XS error). Mapped to WoL's current techs, by name in the saved tech table:
`VeteranMusketeersLA` → `VeteranMusketeers`, `GuardMusketeersLA` → `GuardMusketeers`,
`VeteranPikemenLA` → `VeteranPikemen` (São José do Norte's and Laguna's upgrades; they now compile
to 265, 267, 266). `Abolition0` has no equivalent (WoL's chain starts at `Abolition1`, which the
same trigger sets next) and stays a no-op.

### Barbary Coast: the pirates' civ

Barbary Pirates was saved with the Indians' home city, and its base is Indian: 66 `ypHouseIndian`,
4 `YPBarracksIndian`, Indian mercenaries (`ypThuggee`, `ypDacoit`, `ypMercArsonist`). The story
(the Barbary states, Ottoman vassals) would suggest Ottomans, and WoL has a `Pirate` civ, but that
one is a British copy (`Age0British`, Western European culture), and WoL has no Maghreb civ. The
civ decides what the AI can train in those Indian buildings, so **Indians**, the author's choice.

### Historical notes for the WoL team

- **Barbary Coast:** the pirates should be **Ottomans**: Tripoli, Algiers and Tunis were Ottoman
  regencies (Tripoli under the Karamanli). They stay Indians only because their base is built
  from Indian buildings; fixing it means rebuilding the base. This is the first thing to review.
- **Laguna:** dated 1840, but Laguna was taken (the Juliana Republic) in July 1839 and retaken
  by the Empire in November 1839; the attack on São José do Norte was in July 1840. The mission
  merges the two.
- **Hakodate 1869:** consistent with history.

`milazzo.age3Yscn` and `MISSION_3.age3Yscn` (no node uses them) have the same civ-table and
player problems; Milazzo also places 43 `BolivarGuard`, a removed proto.

## What the menu shows, and where the list comes from

- **WoL already shows only its campaign.** Its loose `data\uipregamenew.xml` (main menu) has one
  campaign button, *Single Player → Historical Scenarios* (string 60006), which runs
  `startCampaign("campaign\wonders\ChinaIndiaJapan.xml")`. The Blood, Ice and Steel and
  WarChiefs buttons are commented out. The campaign screen then lists the nodes of that file:
  "Wars of Liberty", then Barbary Coast (1801), Laguna (1840) and Hakodate (1869) as the
  progress unlocks them.
- **The tutorial is still there:** *Learn to Play* opens *Learn the Basics* and *Try a Game*
  (`loadTutorial("age 3 tutorial\age3tutorial1" / "2", …)`).
- **The exe** names the five definitions (`campaign\Wonders\ChinaIndiaJapan.xml`,
  `campaign\age 3 tutorial\tutorial1.xml` / `tutorial2.xml`, `campaign\war chief\WarChief.xml`,
  `campaign\blood ice steel\BloodIceSteel.xml`, UTF-16 at 0xBC00E0–0xBC0210), but which one runs
  is the menu's command, so no DLL key is needed.
- **The second definition `Campaign\chinaindiajapan.xml` is never used.** With it renamed away
  the game behaved the same. It is a stale copy (it names `wonders\first barbary war`, with
  spaces); WoL can delete it.

**Fix (data, tested):** `wol-fixes/campaign/`'s `data\uipregamenew.xml` hides *Learn to Play*
(the button gets `hidden=""`, the two tutorial buttons are commented out). The main menu then
shows Single Player, Multiplayer, Help and Tools, Exit (`menu-fix-no-learn-to-play.png`).

## How a scenario loads (REA and tracer)

Static analysis of the stock `age3y.exe` (snapshot `rea/snapshots/age3y-b1a1dab7.json`;
Evidence in `rea-evidence.json`), with `tools/re/trace_exec.py` on the running game:

| Address | Role | Status |
|---|---|---|
| 0x83479D | Scenario load (`loadScenario` / `loadCampaignScenario`); prepares string 19194 ("failed to load") | confirmed, `ev_c69ed0f8…`, hit by the tracer |
| 0x59AD7A | Logs an error code; the load's failures call it with 0x5FC–0x611 | confirmed (tracer, `args=`) |
| 0x82EAFD | Checks the file's CRC: zlib CRC-32 of the whole file with its last 4 bytes zeroed, stored in those 4 bytes | confirmed, `ev_5efffa75…`; matches the stock files |
| 0x831F90 | Reads the civ table: one record per civ (chunk `SH`), each by 0x85C249 | confirmed, `ev_7473a334…` |
| 0x85BA5E | Reads one civ record; looks the civ name up (0x58E71F, 0x405C2E); an unknown name returns 0 at 0x85BB47 and fails the whole load | confirmed, `ev_167ced58…`; tracer chain `0x85bb47 ← 0x83204a ← 0x834bef` |

Observed in game:
- **Saved name tables are re-mapped by name.** A scenario keeps the proto, unit-type and tech names
  of its save. Trigger tech parameters (stored as the old index) come out as the current index in
  `Trigger3\trigtemp.xs` (Barbary Coast: saved 7452 `WOLNAUnion1` → `trTechSetStatus(1, 6321, 2)`).
  So the 8 000 shifted tech indices are harmless; only names that are gone matter.
- **The civ table is not forgiving:** one civ name that is not in `civs.xml` fails the load. All
  WoL missions list `Habsburgs` (removed) and `XPAztec` (commented out in `civs.xml`); TAD's own
  missions list `XPAztec` too, so they fail the same way.
- **Player civs are not re-mapped.** A player's civ is a number in its `BP` record (17 bytes
  after the name): the civ's place in `civs.xml` when saved. ID 0 is Mother Nature; the `<civ>`
  entries count from 1 (inference from the flags: Hakodate's player 1, stored as 30, shows
  Chile's flag, the 30th entry; set to 58, `SPCJapanese`, it shows the Japanese look). WoL inserted
  civs since 2022, so every player has the wrong civ now: Barbary Coast's US Navy is `SPCCompany`,
  Laguna's Garibaldi `Austrohungarians`, Hakodate's Imperial Army `Chileans`, its Ezo Republic
  `Argentineans`. The player plays with that civ's techs, age names and cards.

## The fix in `wol-fixes/campaign/`

`WoL-campaign-fix.zip` (with `WoL-campaign-originals.zip` to undo; see its LEEME-README.txt):
- the three missions, rewritten by `tools/scnfix.py` (the exact commands: `mkfix2.py` in the
  evidence folder):
  - civ table: `Habsburgs` → `TheCircle`, `XPAztec` → `Afghans` (same length, both in
    `civs.xml` with a home city, not otherwise in the table);
  - player civs as in the table above; Wild Animals (Laguna) is left alone;
  - Laguna: the units and the techs as above (unit 647 stays a `TownCenter`);
- `data\techtreey.xml`: WoL's current file with the one `Age0Egyptian` attribute changed
  (`Assign` → `BasePercent` on its `TownCenter` `Hitpoints` effect). If WoL's own techtree is
  newer, make only that one change by hand instead of copying this file;
- `data\uipregamenew.xml` without *Learn to Play*.

`campaigncheck.py` on the fixed set (`campaigncheck-fixed-set.txt`): 5 misses, all deliberate:
Laguna's players 1–3 are Brazilians on the Italian home city, Wild Animals' civ, and `Abolition0`.

**For the WoL team**, the clean fix is still to open each mission in the editor (they load now),
check the players' civs and the replaced units, and save: the editor then writes tables that
match today's data.

## Tools

- `tools/campaigncheck.py <game folder>`: the static check of all of the above (civ table, player
  civs, placed protos, saved names, trigger parameters). On the bed as shipped: 46 misses, every
  one of them explained here. `--scn` alone checks a fixed set outside the game folder.
- `tools/scnfix.py`: writes a copy of a scenario with civ-table names, saved proto names, player
  civs, single units' protos (`unit:ID=PROTO`) or trigger parameters (`trigger:`, `tech:`, any
  length: the `TR` and `BG` chunk sizes follow) changed, and its CRC.
- `tools/re/trace_exec.py` also logs a breakpoint's first three stack arguments.

## Open

- The objectives were not played to their end (above): that needs a person at the mouse.
- `jumpToNextCampaignNode` and `campaignAdvance` do nothing from the console; `winScenario`
  works. On the campaign screen *Play* runs the current node (the farthest unlocked), not the
  one selected.
