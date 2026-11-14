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
  `--units` adds each scenario's inventory: per player its civ, flag and home city, the placed
  units by proto, what the triggers give it, and the objectives' texts.
- `tools/scnfix.py`: writes a copy of a scenario with civ-table names, saved proto names, player
  civs, single units' protos (`unit:ID=PROTO`) or trigger parameters (`trigger:`, `tech:`, any
  length: the `TR` and `BG` chunk sizes follow) changed, and its CRC.
- `tools/re/trace_exec.py` also logs a breakpoint's first three stack arguments.

## Open

- The objectives were not played to their end (above): that needs a person at the mouse.
- `jumpToNextCampaignNode` and `campaignAdvance` do nothing from the console; `winScenario`
  works. On the campaign screen *Play* runs the current node (the farthest unlocked), not the
  one selected.

## Historical version: Hakodate

A proposal, 2026-11-13; nothing below is built or tested. It is for an optional pack,
`wol-fixes/campaign-historical/`, that sits beside the base fix and does not replace it. The
inventory comes from `python -I tools/campaigncheck.py C:\AoE3-UHC-WoLReal3 --units --scn
<fixed battle_of_hakodate.age3Yscn>`, run on the copy in `WoL-campaign-fix.zip`. The data
lookups (protos, techs, flags) were run on `C:\AoE3-UHC-WoLReal3\data` and `art`.

**Unit IDs.** A saved trigger names a unit by its *editor ID*, the string in the unit's `UN`
record. The game loads the unit with the `EN` ID instead and compiles the trigger with that
one. For example, the saved parameter 2874 becomes `trUnitSelectByID(1615)` in
`trigtemp-mission3.xs`. The two IDs differ for every unit of the three missions. `scnfix.py
unit:ID` takes the `EN` ID, which is the one the console and `trigtemp.xs` show (Laguna's 647, its
Town Center, is an `EN` ID). `--units` maps the trigger parameters through the editor ID.

### Inventory (the base fix's file)

| Player | Civ now (base fix) | Flag that civ shows | Home city | Placed |
|---|---|---|---|---|
| 1 Imperial Army (human, team 0) | 58 `SPCJapanese` | `objects\flags\japan`: WoL's loose texture, the **Tokugawa hollyhock crest** (gold on black) | `homecitySPC_JC.xml` (TAD's 1600 Japanese campaign deck: Yumi, Ashigaru, Samurai, Naginata, Yabusame, Flaming Arrow, the daimyos Tadaoki, Kiyomasa and Masamune) | 10: Steamboat 3793 (the intro's landing ship, moved and then destroyed by `_A06`/`_A07`), CoveredWagon, YPMilitaryRickshaw, 6 CinematicBlock, MonsterTruckT 1932 (an easter egg; rule `_Misc` destroys it at the start) |
| 2 Ezo Republic (AI, team 1) | 9 `Japanese` | `War of the Triple Alliance\Flags\japan`: Hinomaru | `homecityjapanese.xml` | 390, nearly all buildings: 124 WallConnector, 75 WallStraight5, 40 WallStraight2 (the European walls: Goryōkaku's outline), 24 ypShrineJapanese, 22 tents, 17+12+3+2 `ypSPCJapaneseFort*`, 14 YPOutpostAsian, 10 ypBarracksJapanese, 9 ypCastle, 8 SPCStockades (the prisoners), 7 ypStableJapanese, 3 CWallGate, 3 ypBerryBuilding, 2 YPDockAsian, ypConsulate 1368 (objective "Consulate"), ypMonastery, ypSPCIshidaCastle 1411 (the "Ezo Headquarters", objective "DestroyEzo"), 2 ypShinobiHorse, 2 ypYabusame |
| 3 Ezo Republic (AI, team 1) | 9 `Japanese` | Hinomaru | `homecityjapanese.xml` | 216: 41 ypYumi, 31 ypKensei, 30 ypAshigaru, 19 villagers, 14 ypNaginataRider, 9 ypShinobiHorse, 8 MercRonin, 8 ypNatSohei, 8 ypYabusame, 6 ypWokouPirate, 5 ypFune, 4 Steamboat, 4 ypMercYojimbo, 4 ypYamabushi, 3 ypConsulateYoungGarde, 3 ypFlamingArrow, 2 ypNatMercSohei, 2 ypRicePaddy, 1 ypCastle, 1 ypConsulateGendarmes, 1 WOLConsulateHatamoto (made a ypKensei by `_Misc`) |
| 4 Matsumae (captives, team 0) | 9 `Japanese` | Hinomaru | `homecityjapanese.xml` | 50: 14 villagers, 9 ypYamabushi, 8 ypYumi, 7 MercRonin, 5 ypNaginataRider, 4 ypAshigaru, 3 ypKensei. Freed by destroying the stockades; they become player 1's |
| 5 Supply Ships (team 1 in the record, converted to player 1) | 4 `UnitedStates` | `War of the Triple Alliance\Flags\american` | `homecityamericans.xml` | 50: 8 NAmarine, 3 ypRepentantRonin, 2 NAnurse, xpGatlingGun 1164 (made a ConsulateGatlingGun), crates, casualties, 22 cinematic blocks |

The team column is the byte 8 after the player record's name (0 or 1). From the pairing, it is
the team.

What the triggers give each player:
- **Player 1:** `Army Deploy` of 5 ypSettlerJapanese, 10 `Shaguma` and 1 ConsulateGatlingGun
  (the landing). Then 500 food, wood and gold, Age 1, the `NAtechUSAmarine01`–`05` techs and
  `WOLHakodateScenario` ("Corporal Leathernecks", for the marines it inherits). Its monks, the
  monastery techs and the big consulate are forbidden.
- **Player 2:** `ypBigConsulateSPCFrench`, `ypFrontierCastle`, `ypFortifiedCastle`, `Bastion`,
  the `YPDisciplined*` upgrades, and the HQ at +3 000 then +6 000 HP. About 45 `Army Deploy`s:
  - ypAshigaru, ypYumi, ypKensei, ypNaginataRider, ypYabusame;
  - ypNatSohei, MercRonin, ypMorutaru and ypFlamingArrow, each with a `Player Unit Count`
    respawn loop;
  - ypConsulateGendarmes and ypConsulateYoungGarde;
  - 2 `WOLConsulateShinsengumi`, and `WOLConsulateOnnaBushi` in waves of 5, 7, 9 and 11.

  Three captured berry buildings are converted to player 1.
- **Player 3:** the `YPDisciplined*` upgrades, then deploys of ypKensei and
  `WOLConsulateHatamoto` (4 and 8). There is an ambush party (army 3,33: ypShinobiHorse and
  MercNinja) and the pirates besieging the Americans (army 3,32: ypWokouPirate and ypYumi).
- **Player 5:** the marine techs; 3 Steamboats, 9 NAmarine, 2 NAmountedrifle and 3
  ConsulateGatlingGun; crates. Everything goes to player 1 (`Army Convert`).

Texts:
- *Intro* (LoadTextID 76599): "The Shougun has fallen from grace… the Republic of Ezo… the
  fortress of Goryokaku."
- *Objectives* (name, then text):

  | Name | Text |
  |---|---|
  | Stranded | "Rescue the stranded Americans." (an American supply ship aground, "besieged by Ezo pirates") |
  | BuildTC | "Gain a foothold on the island and build a Town Center." |
  | DestroyEzo | "Build up your army and destroy the Ezo Headquarters within Goryokaku fortress." |
  | Prisoners | "Free the captive Matsumae warriors." |
  | Consulate | "Find and destroy the Ezo Consulate." ("…support of French officers and troops") |
  | (none) | "Defeat the Republic of Ezo." |

- Campaign-wide, not this mission: HCNoteText 43314 still says "This is Malta, Morgan's Home
  City", left over from TAD's Act 1.

### The facts, with sources

Calendars: the English articles mix the lunar dates of the time with Gregorian ones. Where
both are known they are given as lunar (Gregorian). A date marked *conversion* is my
conversion and needs a check.

- **The occupation.** Enomoto Takeaki's fleet (8 steamships, with the flagship Kaiyō Maru)
  landed about 3 000 men at Washinoki and took Hakodate and Goryōkaku: lunar 10/20–26 (3–9
  December 1868). Matsumae Castle fell on lunar 11/5 (18 December 1868), and Esashi fell next.
  **Kaiyō Maru and the transport Shinsoku were wrecked in a storm off Esashi** in the same
  operation, so Kaiyō Maru was gone before the 1869 battle. The government was elected (Enomoto
  as *sōsai*) and proclaimed on 27 January 1869.
  [Battle of Hakodate](https://en.wikipedia.org/wiki/Battle_of_Hakodate),
  [Republic of Ezo](https://en.wikipedia.org/wiki/Republic_of_Ezo).
- **The Ezo army** was organized by Jules Brunet, a French artillery officer who resigned to
  stay. He was second to commander-in-chief Ōtori Keisuke. There were four brigades under the
  Frenchmen Fortant, Marlin, Cazeneuve and Bouffier, each split into half-brigades under
  Japanese officers.
  - The core was the **Denshūtai**, the shogunate's elite infantry trained by the 1867 French
    mission. It came with Chassepot rifles and French artillery. Most other shogunate troops
    had smoothbores, and their officers often wore French or British uniforms.
  - The French left on the corvette Coëtlogon in June 1869 (Brunet surrendered aboard her on
    8 June).
  - [Jules Brunet](https://en.wikipedia.org/wiki/Jules_Brunet),
    [Boshin War](https://en.wikipedia.org/wiki/Boshin_War),
    [Denshūtai](https://en.wikipedia.org/wiki/Densh%C5%ABtai).
- **The Shinsengumi:** Hijikata Toshizō was the republic's vice-minister of the army. He was
  shot leading troops near the Ippongi gate on lunar 5/11 (20 June 1869). The last Shinsengumi
  surrendered at **Benten Daiba**, the harbour battery, on lunar 5/14 (23 June 1869).
  [Hijikata Toshizō](https://en.wikipedia.org/wiki/Hijikata_Toshiz%C5%8D).
- **The Imperial army** had about 7 000 men, mainly from Chōshū and Satsuma, under Kuroda
  Kiyotaka (Satsuma) and Yamada Akiyoshi among others.
  - It landed unopposed at Ōtobe on lunar 4/9 (20 May 1869, *conversion*).
  - Satsuma and Chōshū were fully modernized: Minié rifles, Snider breech-loaders (Chōshū at
    Ueno), Spencer repeaters (Tosa), Armstrong guns (Satsuma and Saga) and a Gatling gun.
  - The troops wore dark Western-style uniforms; some Imperial officers wore bear-hair wigs
    (*shaguma*), whose colour marked their domain.
  - [Boshin War](https://en.wikipedia.org/wiki/Boshin_War),
    [Battle of Hakodate](https://en.wikipedia.org/wiki/Battle_of_Hakodate).
- **The navies.** The Imperial fleet was Kōtetsu, Kasuga, Hiryū, Teibō, Yōshun, Mōshun and Chōyō.
  - **Kōtetsu** was the French-built ex-CSS Stonewall. The shogunate bought it, the US held
    back the delivery, and it went to the new government in early 1869. Its guns were Armstrong
    guns (one 300-pounder and two 70-pounders), later with a Gatling.
  - At **Miyako Bay** on lunar 3/25 (6 May 1869, *conversion*), Kaiten tried to board Kōtetsu.
    It came in under an American flag, raised the Ezo colours before boarding, and was driven
    off by the Gatling.
  - In the **naval battle of Hakodate Bay** (May–June 1869), Banryū sank Chōyō, and Kaiten was
    put out of action. The Ezo fleet was lost.
  - [Kōtetsu](https://en.wikipedia.org/wiki/Japanese_ironclad_K%C5%8Dtetsu),
    [Naval Battle of Hakodate Bay](https://en.wikipedia.org/wiki/Naval_Battle_of_Hakodate_Bay).
    *Uncertain:* the English article dates the naval battle 4–10 May, which look like lunar
    dates; Chōyō sank on lunar 5/11 (20 June 1869).
- **The end:** Enomoto surrendered Goryōkaku to Kuroda on 27 June 1869 (lunar 5/18).
  Goryōkaku is a European-style star fort around the Hakodate magistrate's office. It has no
  castle keep. [Republic of Ezo](https://en.wikipedia.org/wiki/Republic_of_Ezo).
- **Matsumae:** at first in the northern alliance. Its loyalist samurai (the Seigi-tai) took the
  domain over to the new government in 1868. The Ezo forces drove it out, and it fought them
  from Tate Castle. Its crest is the Maru ni Takedabishi.
  [Matsumae Domain](https://en.wikipedia.org/wiki/Matsumae_Domain).
- **Flags:**
  - *Imperial side:* the **Nishiki no mihata**, a red brocade banner with a gold sun (and a
    silver moon on its pair), first raised at Toba–Fushimi and carried by Satsuma and Chōshū on
    many fields ([japanese-wiki-corpus](https://japanese-wiki-corpus.github.io/history/Nishiki%20no%20mihata%20(The%20Imperial%20Standard).html),
    [FOTW](https://www.fotw.info/flags/jp_ezo-i.html)). FOTW also says the government forces
    used a white flag with a black-outlined 16-petal chrysanthemum at Hakodate. That rests on
    one contributor's note, without a source.
  - The **Hinomaru** was the shogunate's ship ensign from 1854. It became the merchant flag by
    Proclamation 57 of 27 February 1870, and the Rising Sun war flag dates from 15 May 1870:
    after the battle ([Flag of Japan](https://en.wikipedia.org/wiki/Flag_of_Japan)).
  - *Ezo:* FOTW says Enomoto **used the Hinomaru** as the former shogunate forces' ensign. The
    well-known Ezo flag (a blue field, a yellow chrysanthemum and a red seven-pointed star) has
    no document or image source. FOTW and a Hokkaido flag paper think it is invented: the star
    appeared only in 1872, with the Colonization Office. Using the Imperial chrysanthemum would
    make no sense for Ezo ([FOTW](https://www.fotw.info/flags/jp-ezorp.html),
    [FIAV paper](https://fiav.org/wp-content/uploads/2021/06/ICV23-21-Takano-FlagsofHokkaidoChargedwiththeShiningPolarStar.pdf)).
- **Not historical in the mission:**
  - the "American supply ship" and its US Marines: the US was neutral, and the only American
    flag in the story is Kaiten's ruse at Miyako;
  - the Ezo army of bowmen, naginata riders, warrior monks, ninja and *onna-bushi* (the women's
    corps fought at Aizu in 1868, not at Hakodate);
  - a castle keep as the HQ;
  - the Imperial player flying the Tokugawa crest, with 1600 shipments.

  The mission's dates, places and sides (Goryōkaku, the French consulate, the Matsumae
  captives, the Ezo republic) are right.

### Replacements

Placed units: `unit:EN_ID=PROTO` per unit, on that player's units only. Deployed units:
`trigger:OLD=NEW`, which renames a proto in every trigger. That keeps each respawn loop working
(`Player Unit Count` and `Army Deploy` both change), and it acts on every player: each proto
below is deployed only by Ezo. Every proposed proto is in the scenario's saved proto table. For
units, the HP and pop are those of the unit replaced, or close (WoL built its Japanese roster
to mirror TAD's).

| Current | Proposed | Reason |
|---|---|---|
| P1 civ `SPCJapanese` (Tokugawa flag, 1600 deck) | hidden civ `HistImperialJapan` (below) | Its flag is the enemy's crest; its shipments are Sekigahara-era |
| P2/P3 civ `Japanese` | hidden civ `HistEzoRepublic` (below), or keep `Japanese` | The Hinomaru is right for Ezo; the hidden civ only adds the name and a modern-only roster |
| P4, P5 civs | keep | P4's units become the player's; P5 is the fiction of the objectives |
| ypYumi (P3 41, P4 8; deploys) | `Kihei` | Bows were long obsolete; Ezo infantry carried rifles and fought in the French skirmish drill |
| ypAshigaru (P3 30; deploys) | `IMShotai` ("Shishi", pending its render; fallback `WOLLineInfantry`) | Matchlock to rifle line infantry; `Shaguma` stays Imperial |
| ypNatSohei, ypNatMercSohei (P3 10; deploys with count conditions) | `IMShotai` | No warrior monks at Hakodate |
| WOLConsulateOnnaBushi (deploy waves 5–11) | `IMShotai` | Women's corps: Aizu 1868, not Hakodate; same pop 1 |
| ypYamabushi (P3 4, P4 9) | `Kihei` | Mountain ascetics; riflemen instead |
| ypShinobiHorse (P2 2, P3 9; deploys), MercNinja (deploys) | `Kihei` | The ambush party stays, as riflemen |
| ypNaginataRider (P3 14, P4 5; deploys), ypYabusame (P2 2, P3 8; deploys) | `GuntoRider` | Japanese sabre cavalry; same 300 HP as the naginata rider |
| ypConsulateGendarmes (P3 1; deploys) | `GuntoRider` | No French cavalry; the French were officers |
| ypConsulateYoungGarde (P3 3; deploys) | `WOLLineInfantry` | French-drilled line around the consulate, not a Napoleonic grenadier |
| ypFlamingArrow (P3 3; deploys, count condition) | `Kanouhou` | Ezo artillery was Western (Brunet was a gunner); same 175 HP, pop 4 |
| 2 of the 4 P3 Steamboats (838, 3785; no trigger uses them) | `Joukisen` | Kaiten and Banryū, steam warships; the other two and the 5 Fune stay (Fune 1225 etc. are moved by triggers) |
| ypKensei, WOLConsulateHatamoto, WOLConsulateShinsengumi, MercRonin, ypMercYojimbo, ypMorutaru | keep | Sword retainers of the Tokugawa (Hatamoto), Hijikata's Shinsengumi, masterless samurai, a mortar: all present |
| ypWokouPirate (P3 6; deploys) | keep | The objective's text calls them "Ezo pirates" |
| P1 `Shaguma` x10, ConsulateGatlingGun, Steamboat 3793 | keep | Shaguma: the Imperial officers' bear-hair wigs; the Gatling: Satsuma's and Kōtetsu's; the transport: the Ōtobe landing |
| ypSPCIshidaCastle 1411 (HQ, 6×6) | keep; option `FortFrontier` (6×6, 8 500 HP) with `trigger:ypSPCIshidaCastle=FortFrontier` for the two `Modify Protounit` | Goryōkaku had no keep, but the European walls already draw the star fort. The option makes the HQ 17 500 HP instead of 15 000 |
| ypCastle (P2 9, P3 1, 4×4), YPOutpostAsian, the walls, ypConsulate | keep | Footprints fit; the consulate is the French mission. Idea: name the castle by the docks (x 390–460, z 130–260) "Benten Daiba" with a `Change Name`, which needs a new effect |

### Hidden civs and flags

Append them at the end of `civs.xml` with `<visible>0</visible>`. Civ IDs are positions, so
appending moves no existing civ. The new ones are 169 and up in today's file. The base fix shows
that a player's civ does not have to be in the scenario's civ table: `SPCJapanese` is not in
Hakodate's table, and the mission runs.

| Civ | Copy of | Flag texture | Exists? | Home city |
|---|---|---|---|---|
| `HistImperialJapan` | `SPCJapanese` | the Nishiki no mihata: red brocade, gold disc (`objects\flags\hist_nishiki`) | **needs drawing** (no chrysanthemum or brocade texture in WoL's art) | new `homecitySPC_MJ.xml` (same length as `homecitySPC_JC.xml`, so the player record can be renamed in place): SPC_JC with the 1600 cards swapped for WoL's `YPHCShipShaguma1`–`4`, `YPHCShipKihei1`–`4`, `YPHCShipGuntoRider1`–`3`, `YPHCShipKanouhou1`–`3` and `WOLHCShipGensuiOyama` (from `homecityjapanese.xml`) |
| `HistEzoRepublic` | `Japanese` | Hinomaru, `War of the Triple Alliance\Flags\japan` | **exists** | `homecityjapanese.xml` |
| (Matsumae, optional) | `Japanese` | Maru ni Takedabishi | needs drawing; not worth it (they are captives) | — |

Flags checked in the bed's art (loose files and `Art*.bar`, decoded with aoe3-blender-tools'
`ddt.py`):
- `objects\flags\japan`: the Tokugawa crest on black. WoL's loose file overrides TAD's in
  `Art5.bar`, which is the same crest.
- `japan_spc_enemy` (`Art5.bar`): the Tokugawa crest on yellow.
- `War of the Triple Alliance\Flags\japan` and `colonyjapan`: the Hinomaru.
- `france`, `CONGRESSfrench` and `objects\flags\french`.

Nothing shows a chrysanthemum, a brocade banner or the Ezo star. Without a drawn flag,
`HistImperialJapan` could use the Hinomaru for now (both sides then fly it, which is
historical for ships but confusing in game). **Do not use the Tokugawa crest for the Imperial
side.**

A hidden civ also brings an age-0 tech of its own, which can enable only the modern roster:
- Imperial: Shaguma, Kihei, GuntoRider, Kanouhou, Joukisen, Gatling;
- Ezo: the same plus Hatamoto, Shinsengumi and the consulate.

Without it both sides keep `YPAge0JapaneseUnits` (ypYumi, ypKensei, ypYabusame… next to
Shaguma), and the player can still train archers. A trigger `Forbid` would also do it, but
`scnfix.py` cannot add effects.

### Risks

- **The order of the appended civs is shared** by the three historical missions (other agents
  propose civs for missions 1 and 2): fix one order before saving any scenario.
- The engine's limit on the number of civs is not checked: 168 now. Check it with REA before
  appending.
- The `trigger:` renames act on every player. Each one above is deployed only by Ezo; a new
  rename needs the same check.
- `unit:` swaps need a loop over EN IDs per player. A `units:PLAYER:OLD=NEW` option for
  `scnfix.py` would be cleaner (not written).
- Balance:
  - Kihei and IMShotai are ranged, where the samurai roster had melee units, so the Ezo AI's
    armies gain range;
  - 2 Joukisen are stronger at sea than Steamboats;
  - the `FortFrontier` HQ option raises its HP.

  Play the mission through (an hour, by hand) before shipping.
- The Ezo AI trains from its civ: with `Japanese` it can still build archers and samurai;
  only a hidden civ stops that.
- The objective texts ("Ezo pirates", "American supply ship") stay. Changing them means
  rewriting the `OM` chunk, whose strings change length (not supported by `scnfix.py`).
- Flags and any new texture go through `aoe3-blender-tools` (the art rule).
- `IMShotai` ("Shishi") is named after the Imperial loyalist activists. If its model reads as
  Imperial, use `WOLLineInfantry`; the renders decide.

### Models to render

Saved as `m3-list.txt` in the scratch `sheets` folder, `caption | proto`:

```
Imperial line infantry (Shaguma) | Shaguma
Imperial / Ezo skirmisher (Kihei) | Kihei
Ezo rifleman candidate (Shishi) | IMShotai
Ezo rifleman fallback (Line Infantry) | WOLLineInfantry
Japanese sabre cavalry (Gunto Rider) | GuntoRider
Western field gun (Kanonhou) | Kanouhou
Gatling gun | ConsulateGatlingGun
Ezo steam warship (Joukisen) | Joukisen
Kotetsu candidate (Ironclad) | xpIronclad
Landing transport (Steamboat) | Steamboat
Shinsengumi | WOLConsulateShinsengumi
Hatamoto Samurai | WOLConsulateHatamoto
Samurai (kept) | ypKensei
Onna-Bushi (replaced) | WOLConsulateOnnaBushi
Yumi Archer (replaced) | ypYumi
Ashigaru Musketeer (replaced) | ypAshigaru
Flaming Arrow (replaced) | ypFlamingArrow
Young Garde (replaced) | ypConsulateYoungGarde
Ezo HQ now (Ishida's Castle) | ypSPCIshidaCastle
Ezo HQ option (Fort) | FortFrontier
Ezo castle / Benten Daiba stand-in | ypCastle
Ezo consulate (French mission) | ypConsulate
```

### Open questions

- Which flag for the Imperial side: the Nishiki no mihata (well sourced as an Imperial banner)
  or FOTW's white chrysanthemum flag (one unsourced note)? Either has to be drawn.
- Keep the American supply ship (fiction, needed by the first objective) or replace it in a
  later, deeper edit?
- Do the Ezo get a hidden civ, or only the unit swaps on `Japanese`?
- Kuroda Kiyotaka led the Imperial land forces, and WoL has no Kuroda. Its Japanese field
  marshals are Ōyama Iwao, Saigō Takamori, Yamagata Aritomo, Itō Hirobumi and Nagaoka Gaishi.
  Should the deck ship Ōyama, an artillery officer of the Boshin War, as a stand-in?
