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

## Historical version: Laguna

Proposal (2026-11-13, research only, nothing built or played) for an optional pack
`wol-fixes/campaign-historical/` that sits on top of the base fix and does not replace it. The
inventory comes from `python -I tools/campaigncheck.py C:\AoE3-UHC-WoLReal3 --inventory --scn
<laguna.age3Yscn>` on the fixed copy in `WoL-campaign-fix.zip`; the data from WoL's `data\` of that
bed. The flag images were decoded from WoL's `.ddt` files with aoe3-blender-tools' `ddt.py`.

### Inventory (the fixed file)

| # | Player | Civ (base fix) | Flag shown now | Placed (main protos) | Its triggers |
|---|---|---|---|---|---|
| 1 | Giuseppe Garibaldi (human) | Brazilians, Italian home city | Empire of Brazil | Town Center, 5 houses, mill, pen; 5 Musketeer, 4 Pikeman ("Partisan"), 4 Corvette; a group near (107,130) of one each: Dragoon, Hussar, MountedCassador, Volunteer, Jinete, Lancero, WolJagunco, IMFarrapo, IMredshirt; 2 SPCXPChayton (Chayton Black: unit 4484 renamed "Giuseppe Garibaldi", and a cinematic actor); 1 WOLConsulateHatamoto (a Tokugawa samurai, no trigger names it); 28 cinematic blocks | Age 1; `IMMIGRANTgerman` and `IMMIGRANTcsa` off, `Abolition1–3` on; unit 3060 (the Redshirt) destroyed at start; armies 1,10 = 8 WolJagunco, 1,11 = 7 Lancero, 1,12 = 6 Pedrero, 1,13 = 20 Jinete; 1,14 = 1 ShipWagon (redeployed when lost); the Riograndense caravel converted to player 1 |
| 2 | Laguna (AI, `AIStart`) | Brazilians, Italian home city | Empire of Brazil | Town Center 647 (objective 6), 33 houses, 24 `SPCPort` props, barracks (one turned into a stable), stable, church, market, artillery depot, 3 docks, 5 outposts, 2 Hussar | Age 3; `Abolition0–5`, outpost upgrades, `VeteranVolunteers`, `VeteranHussarsLA`, `VeteranPikemen`; neutral with 4 |
| 3 | São José do Norte | Brazilians, Italian home city | Empire of Brazil | `FortFrontier` (renamed "Sao Jose do Norte"), walls and 2 gates, 21 outposts, 2 docks; 131 Musketeer, 15 Pasavolante, 14 Jinete, 12 Hussar, 5 Dragoon, 4 MountedCassador, 1 Escolta | Age 3; fort, wall and outpost upgrades, Veteran/Guard Musketeers and Hussars; 9 armies of 6 Musketeer (3,13–3,21) and patrol 3,22 (up to 4 Hussar + 7 Jinete) |
| 4 | Brazilian Navy | Brazilians | Empire of Brazil | 3 Caravel, 2 Galleon | neutral with 2 and 3 (sic) |
| 5 | Riograndese Republic | Brazilians | Empire of Brazil | 1 cinematic block | army 5,10 = 1 Caravel, sailed up then converted to player 1 |
| 6 | Wild Animals | Italians (left alone) | Italy | 5 PetJaguar | – |

Texts. Overlay *"Battle of Laguna, 1840"*; campaign node string 76596 *"Laguna (1840)"*, intro
76597. Objectives (ID, name: text): 1 AgeUp (Capital Age), 2 PostOfficeAndAlly (post office, ally
with the Italians), 3 BoatTrain (Ship Wagon from the immigrant colony), 4 BoatTransport (two
Corvettes overland to the flag near the ocean), 5 BeatNavy (*"Defeat the Brazilian navy by the
port of Laguna"*), 6 TCRush (*"Destroy Laguna's Town Center"*), 7 TatterCav (12 `IMFarrapo`),
9 ImmigrantTown, 11 ShipsMustLive, 12 ShipsAreImportant (two Corvettes survive), 13
HaveAllShipsLive. The objectives chunk ends with the scenario's own description, *"Fuck up Laguna
real serious"* (a placeholder). Six of the eight chat lines are placeholders too (*"good now build
mail house i wanna write to mom k?"*, *"we fucked up, almost all aquatic-based vehicles died"*);
only 76600 and 76601 (string table) are written text.

### Facts, with sources

- **Overland haul (July 1839).** Garibaldi and John Griggs moved two *lanchões*, the *Seival*
  and the *Farroupilha* (Garibaldi's memoir calls his *Rio Pardo*: the name differs between
  sources), from the Lagoa dos Patos at the Capivari to the mouth of the Tramandaí on wheeled
  carriages; the memoir gives about two hundred oxen and about fifty-four miles. They put to sea
  because the Empire held the lagoon's only outlet, at Rio Grande and **São José do Norte**. A
  storm wrecked Garibaldi's boat near the Araranguá (16 lost); the *Seival* arrived.
  [pt.wikipedia República Juliana](https://pt.wikipedia.org/wiki/Rep%C3%BAblica_Juliana),
  [en.wikipedia Capture of Laguna](https://en.wikipedia.org/wiki/Capture_of_Laguna), Garibaldi's
  memoir as quoted in [The Life of General Garibaldi](https://litres.com/book/garibaldi-giuseppe/the-life-of-general-garibaldi-24858979/read/page-3).
- **Capture of Laguna, 22 July 1839.** David Canabarro (land) with Garibaldi and Griggs (the two
  launches), about 1 000 men, against Vicente Vilas-Boas with 2 schooners and 3 launches; attacked
  at night from the south; one imperial ship burned, one captured; only the *Cometa* escaped.
  The **Juliana (Catarinense) Republic** was proclaimed on 29 July 1839.
  [Capture of Laguna](https://en.wikipedia.org/wiki/Capture_of_Laguna),
  [Juliana Republic](https://en.wikipedia.org/wiki/Juliana_Republic).
- **Recapture, 15 November 1839.** About 3 000 imperials with 14 warships and 31 guns (5
  gunboats, 4 launches, the pataches *São José* and *Desterro*, the brigs *Eolo* and *Cometa*, the
  schooner *Bela Americana*; Frederico Mariath at sea, Col. José Fernandes dos Santos Pereira on
  land) against about 1 200 republicans with the schooners *Rio Pardo*, *Caçapava* and
  *Itaparica*, the gunboat *Lagunense* and the launch *Santana*. Imperial victory; the
  republican flotilla was sunk, burned or taken. [Recapture of Laguna](https://en.wikipedia.org/wiki/Recapture_of_Laguna).
- **São José do Norte, 16 July 1840.** Bento Gonçalves, with Garibaldi, about 1 200 men,
  assaulted the town held by 599 National Guardsmen under Col. Antônio Soares de Paiva and was
  repulsed after the Rio Grande garrison and the launch *Torres* reinforced it.
  [Battle of São José do Norte](https://en.wikipedia.org/wiki/Battle_of_S%C3%A3o_Jos%C3%A9_do_Norte)
  (casualty figures disagree inside the article).
- **Troops.** The Riograndense army was cavalry above all: gaucho militia and the **Lanceiros
  Negros**, about 400 freed or enslaved Black men, formed 12 September 1836, lances longer than
  usual, chiripá, poncho, red headband; Joaquim Teixeira Nunes's lancers went on the Laguna
  expedition; destroyed at Porongos, 14 November 1844.
  [pt.wikipedia Lanceiros Negros](https://pt.wikipedia.org/wiki/Lanceiros_Negros),
  [Ragamuffin War](https://en.wikipedia.org/wiki/Ragamuffin_War). The Empire fought with line and
  National Guard troops and the Imperial Navy's small craft (above). *Inference, not checked:*
  imperial infantry of the period was organised in *caçadores* battalions.
- **Not of 1839–40.** Garibaldi's **red shirts** and the **black flag with a volcano** are those of
  the Italian Legion of Montevideo, formed in 1843 ([Redshirts (Italy)](https://en.wikipedia.org/wiki/Redshirts_(Italy))).
  The *jagunço* is a late-19th-century hired gunman of the Northeast.
- **Flags.** Riograndense Republic: the green-red-yellow tricolour, divided diagonally; it
  began about 1835 without arms, which were added later (pt.wikipedia [Bandeira do Rio Grande do Sul](https://pt.wikipedia.org/wiki/Bandeira_do_Rio_Grande_do_Sul);
  an automated summary of that page called the stripes horizontal, which contradicts the flag as
  drawn everywhere, WoL's texture included: the diagonal is taken as right, the summary as wrong).
  Juliana Republic: green-white-yellow horizontal tricolour, adopted 10 August or 10 September
  1839 ([FOTW](https://crwflags.com/FOTW/FLAGS/br_jul.html), the date is disputed). Empire of
  Brazil: green field, yellow rhombus, imperial arms.

**Date and title.** The mission plays July 1839: the overland boats, the imperial navy beaten at
Laguna's port, the town taken (*"We've liberated Laguna!"*), with São José do Norte as the fort that
blocks the river, which is why the boats went overland. Nothing of the July 1840 assault (a
republican defeat) is in it. Proposed: overlay *"Capture of Laguna, July 1839"*, node *"Laguna
(1839)"*, and a note in the intro or the victory text: *"On 29 July 1839 the Juliana Republic
was proclaimed in Laguna. The Empire retook the town on 15 November 1839."*

### Replacements

| Current | Proposed | Reason |
|---|---|---|
| Players 1 and 5: civ Brazilians | hidden civ `WOLCampFarrapos` (below) | Today Garibaldi and the Riograndense Republic fly the Empire's flag |
| Players 2, 3, 4: civ Brazilians | keep Brazilians | Its flag (`War of the Triple Alliance\Flags\brazil`) **is** the Empire of Brazil's |
| Army 1,11 (7) and unit 2676: `Lancero` | `MercLanceiroNegro` | WoL has the Lanceiros Negros (600 HP, pop 4, mercenary); Teixeira Nunes's lancers were on this expedition |
| Army 1,10 (8) and unit 2530: `WolJagunco` | `MercBacamarteer` | Keeps the blunderbuss (*bacamarte*) of the removed `Bacamartero` without the 1890s outlaw; regular-looking, pop 3. Check the model first (render list) |
| Army 1,13 (20): `Jinete` | keep | Gaucho carbine cavalry fits |
| Unit 2764 `WOLConsulateHatamoto` (player 1) | remove, or `MercLanceiroNegro` | A Tokugawa samurai, named by no trigger: a leftover |
| Unit 3060 `IMredshirt` | `IMFarrapo` (or leave: it is destroyed at start) | Red shirts are 1843 |
| Unit 4484 `SPCXPChayton` (Garibaldi) | keep for now | WoL has no Garibaldi model; Chayton Black is the stand-in. A Garibaldi model is art work (aoe3-blender-tools) |
| Player 4: 2 `Galleon` | `Schooner` or `Privateer` (brig) | Galleons are 17th century; the imperial ships were brigs, a schooner, pataches and gunboats |
| Player 4: 3 `Caravel` | `WOLGunboat` | The imperial gunboats and launches |
| Army 5,10: `Caravel` (converted to player 1) | `WOLGunboat` or `Schooner` | A republican launch/schooner; not a Corvette, so it does not change objectives 12 and 13 |
| Player 1: 4 `Corvette` | keep (phase 1); `Schooner` later | The launches were far smaller, but objectives 4, 12, 13 and two conditions count `Corvette`, and their texts say Corvette |
| Player 3: `Musketeer` (131 + armies) | keep; optionally some `Cacadore` | Imperial line and National Guard |
| Player 3: `Pasavolante`, `Escolta`, `Hussar`, `Dragoon`, `MountedCassador`, `Jinete` | keep | Fit the imperial army |
| `IMFarrapo` (objective 7) | keep | WoL's "Tatterdemallion" (*farrapo*), an Italian lancer for South American independence: the mission's mechanic |
| Placeholder chat lines and the scenario description | rewritten (proposal: *"The boats are on the water. Now for the fort's guns."*, etc.) | Profanity and joke text in a released campaign |

No building is swapped, so no footprint changes: the buildings (`Housebrazil`, Town Center,
`FortFrontier`, walls, outposts, docks) are Brazilian and fit both sides.

### Hidden civs and flags

- **`WOLCampFarrapos`**: a copy of the `Brazilians` `<civ>` (same age techs `Age0Brazilian`,
  `WOLColonializeBrazilians` …, same post-age techs, units and blocks), appended at the end of
  `civs.xml`, with `<visible>0</visible>`, `<visibleineditor>1</visibleineditor>` (so the editor
  can set it), no `<statsid>`, `displaynameid` 444433 (*"Farrapos"*, already in the string
  table), `homecityflagtexture` `War of the Triple Alliance\Flags\piratini`,
  `homecityflagbuttonset` `PiratiniFlagBtn`, `postgameflagtexture`
  `War of the Triple Alliance\Flags\ingame_ui_postgame_flag_piratini`. **All exist** in WoL's art
  (the Riograndense tricolour, diagonal, without arms; also `WoL\objects\flags\rev_piratini`, the
  player-coloured one of WoL's `WOLPiratini` revolution). Garibaldi keeps the Italian home city.
  It would be civ 169 in the bed's `civs.xml` (168 entries today); `scnfix.py player:` sets it.
- **The Empire**: no new civ needed: `Brazilians` already shows the imperial flag. A copy
  `WOLCampImperio` (flag `War of the Triple Alliance\Flags\brazil`, exists) only if the score
  screen must say *Empire of Brazil*; that needs a new string. Keeping `Brazilians` also keeps
  WoL's AI, which tests `cCivBrazilians` 50 times in `AI4\aiWoLMain.xs`, for Laguna's AI player.
- **Juliana Republic** (green-white-yellow horizontal): **no texture; needs drawing** (128×128
  BGRA like `piratini.ddt`, a 128×32 post-game strip, a button set). Only needed if the victory
  shows the new republic (for example a flag raised on Laguna's Town Center site).
- Existing but **not** for 1839: `rev_garibaldine` / `rev_flag_garibaldi` (the Italian Legion's
  black flag with Vesuvius, 1843).

### Risks

- **Civ IDs are stored as numbers.** A civ appended at the end keeps every existing ID; inserting
  one anywhere else moves every later civ in every scenario. The scenario's civ table (44 names)
  does not list `WOLCampFarrapos`: untested whether a player whose civ is not in that table loads
  (the base fix only used civs the table has). Test first with player 5.
- A hidden `main 1` civ with `visible 0` is untested in WoL; WoL's other hidden civs are
  revolutions (`main 0`). The pack also ships `civs.xml`, so it must be redone on each WoL update.
- `WOLCampFarrapos` has no AI branch: fine for the human and the scripted player 5, not for an AI.
- **Tool limits:** `scnfix.py` changes protos, civs and trigger protos/techs; it cannot yet change
  trigger texts (the type-22 text parameters) or the objectives chunk (`OM`). The title, chat and
  description need that (sizes of `TR`/`OM` and the root `BG` change). The node title is string
  76596 of `stringtabley.xml`: a new string, or the campaign XML pointing to another, is the
  cleaner way than editing WoL's table.
- Swapping `Corvette` would need trigger, objective and text edits together; left for later.
- `MercBacamarteer` (280 HP) and `MercLanceiroNegro` (600 HP) are mercenaries, stronger than the
  units they replace (150 and 335 HP): balance on Easy and Hard to be checked in play.
- Side finding in WoL's data: `techtreey.xml` still names `MercJagunco` (4 lines) and
  `Carabinero` (25, among them the Venezuela revolution's army), protos `protoy.xml` no longer has.

### Models to render

The list (also in the scratchpad as `sheets\m2-list.txt`), `caption | proto`:

```
Lanceiro Negro, proposed for army 1,11 and unit 2676 | MercLanceiroNegro
Lancer, the base fix's Lanceiro Negro stand-in | Lancero
Bacamarteer, proposed blunderbuss man | MercBacamarteer
Jagunço, the base fix's blunderbuss man | WolJagunco
Jinete, gaucho carbine cavalry (base fix for Carabinero) | Jinete
Tatterdemallion, objective 7 (12 needed) | IMFarrapo
Partisan, Farrapo irregular infantry | Pikeman
Musketeer, Farrapo line infantry | Musketeer
Pedrero, the rebel siege guns (army 1,12) | Pedrero
Chayton Black, Garibaldi's stand-in | SPCXPChayton
Hatamoto Samurai, stray unit 2764 to remove | WOLConsulateHatamoto
Redshirt, unit 3060 (destroyed at start; 1843) | IMredshirt
Corvette, Garibaldi's boats (objectives 4, 12, 13) | Corvette
Ship Wagon, the overland haul | ShipWagon
Schooner, candidate for the Seival and the rebel schooners | Schooner
Gunboat, candidate for the Riograndense launch (army 5,10) | WOLGunboat
Escolta, imperial lancer (unit 2787) | Escolta
Musketeer, São José do Norte's 131 and armies 3,13-3,21 | Musketeer
Caçador, candidate imperial light infantry | Cacadore
Hussar | Hussar
Dragoon | Dragoon
Caçador Montado | MountedCassador
Jinete, imperial carbine cavalry (base fix for Carabinero) | Jinete
Volante, São José do Norte's artillery | Pasavolante
Caravel, the Brazilian Navy now (3) | Caravel
Galleon, the Brazilian Navy now (2) | Galleon
Privateer, candidate for the imperial brigs | Privateer
Fort, São José do Norte | FortFrontier
Town Center, Laguna (objective 6) | TownCenter
```

### Open

- Whether a civ outside the scenario's civ table loads (above).
- The Riograndense flag's centre arms: WoL's texture has none, which fits 1836–1840 (*inference*).
- Rio Pardo or Farroupilha: the wrecked launch's name differs between the memoir and Brazilian
  sources.

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

## Historical version: Barbary Coast

Status 2026-11-13: **proposal only**, nothing built or tested. It is for an optional pack,
`wol-fixes/campaign-historical/`, installed on top of the base fix (`wol-fixes/campaign/`), which
it does not replace. Source: the fixed `first_barbary_war.age3Yscn` of `WoL-campaign-fix.zip`,
read with `python -I tools/campaigncheck.py C:\AoE3-UHC-WoLReal3 --inventory --scn <file>`; data
of `C:\AoE3-UHC-WoLReal3\data` (read only). "Observed" below is read from the files; "inference" and
"uncertain" are marked.

### Inventory per player

**Unit IDs.** A placed unit has two numbers: its in-game ID (the EN record) and its editor ID
(the UN record's name). The scenario's triggers store the editor ID and the game compiles it into
the in-game one (observed: storage hut 2624 is `trUnitSelectByID(2112)` in
`trigtemp-mission1.xs`; Laguna's Town Center is editor 1168, in game 647). The tables use the
editor ID; `scnfix.py unit:` takes the in-game ID.

| # | Player | Civ (fixed file) | Flag shown | Home city / AI | Placed units and buildings | What its triggers add |
|---|---|---|---|---|---|---|
| 1 | United States Navy | 4 UnitedStates | `War of the Triple Alliance\Flags\american` (34 stars, Civil War era) | americans / human | Steamboat ×3 (1679, 1684, 1685), Dock (2635, hidden as a CinematicBlock at start), CinematicBlock ×11, SPCPopBlock | Age 1, then 2; HC access off; `NAtinclad` forbidden; techs `WOLNAUnion1/2` (enable `NAmarine`, `NAmountedrifle`), marine, light cavalry, militia and spontooner upgrades, dock attack/defence; Steamboat count < 1 turns 2635 back into a Dock; at the end 3734 → `FieldHospital`, 3539 → `NAnapoleon`; the captain converts to player 1 |
| 2 | Barbary Pirates | 8 Indians | `objects\flags\india` | indians / AI `first_barbary_war_p2` (max age 1, no building, no navy, rush) | 349: WallConnector 67, ypHouseIndian 66, SPCTentLarge 61, WallStraight5 36, WallStraight2 18, Outpost 17, HouseMed 12, WOLRuca 7 (the storage huts 2624–2631), SPCWeaponsCache 6 (the caches 1687, 1708, 1721, 1876, 2275, 2488), CWallGate 6, YPBarracksIndian 4, Barracks 3, Lookout 3, ypCaravanserai 2, Dock 2 (1705, 2332), Arsenal 2, ArtilleryDepot 2, Stable, FortFrontier 2497 renamed "Fort Tripoli", SPCStockades 2254 (the prison), and 18 single units (AFRICANcamelrider 5, WOTTANatPirate 4, one each of AFRICANmehariste, AbusGun, Akinci, Falconet, ypDacoit, MercMameluke, WOTTANatMercPirate, ypMahout, AfricanNaffatun, ypNatMercTigerClaw, ypThuggee, Seimen, AFRICANfellah, Cannon, MercBarbaryCorsair, ypMercArsonist, Rodelero) | Age 1; **Override Culture for Art = Mediterranean**; `FrontierOutpost`; 33 `Army Deploy`: Seimen (renamed "Barbary Musketeer") 21, Rodelero ("Barbary Swordsman") 13, WOTTANatMercPirate 10, AFRICANfellah 33, ypNatMercTigerClaw 15, MercBarbaryCorsair 12, Akinci 4, AFRICANcamelrider 3, AFRICANmehariste 1, Cannon 3, Falconet 1, AbusGun 2, AfricanNaffatun 3; fleet (army 2,29): Privateer ×5 (one with count 0), Galley ×2 |
| 3 | Barbary Pirates | 8 Indians | `objects\flags\india` | indians / inactive | 216: Seimen 45, WOTTANatMercPirate 26, Rodelero 21, ypThuggee 19, MercBarbaryCorsair 19, AFRICANmehariste 11, Akinci 10, ypMercArsonist 9, ypNatMercTigerClaw 8, ypDacoit 8, FishingBoat 8, AbusGun 8, AfricanNaffatun 7, AFRICANcamelrider 6, MercMameluke 4, Galley 2, Privateer, NAkingsmousquetaire 2841 renamed "Barbary Pirate Captain" | 20 `Army Deploy`: Seimen 33, AFRICANfellah 39, AFRICANcamelrider 17, AFRICANmehariste 6, Rodelero 10, ypMercArsonist 8, MercBarbaryCorsair 4, WOTTANatMercPirate 4, Akinci 3, ypDacoit 2, Cannon 1; the merchant ships: Caravel ×2 (armies 3,38 and 3,39, renamed "Barbary Merchant Ship") |
| 4 | Swedish Mining Operation | 23 Swedish | `War of the Triple Alliance\Flags\swedish` (Sweden–Norway union ensign, 1844–1905) | swedish / inactive | CinematicBlock ×2, CinematicBlockCube 3466 (becomes an invulnerable Caravel) | Settler ×5 (they mine gold mine 2816 and tribute 1 000 gold to player 1), WOLBevaring ×12, OutpostWagon that builds Outposts; `WOLVeteranBevaringar`, `FrontierOutpost`, `GreatCoat`; neutral to player 1 |
| 5 | Van Lesen | 15 Dutch | `objects\flags\dutch` (tricolour) | dutch / human slot, no AI | WOLMercBlueGuard 3447 renamed "Captain Van Lesen", CinematicBlock (→ MapObjective), CinematicBlockCube 2637 (→ `SPCFlagKevin`, the flag on the neutral island) | Neutral to all; converted to player 1 when freed, back to 5 at the flag; +2 000/+1 000/+500 HP for the captain |
| 6 | Storage | 13 British | `…\Flags\unitedkingdom` | british | none | Only the source of 15 tributes to player 1 (food, wood, gold) when a storage hut dies |
| 7 | Sunken Merchant Ship | 13 British | `…\Flags\unitedkingdom` | british | none | Only the source of 18 tributes to player 1 when a merchant Caravel sinks |
| 0 | Mother Nature | — | — | — | 2 223 props and trees; MineGold 2816, ypFishTuna (2666…2710) used by triggers | — |

Texts (all literal in the scenario except the load text):
- **Load text** (string 76595): "Piracy in the Mediterranean has been in effect for hundreds of
  years, and as of yet nobody has dared face the fierce Algerians and Tripolitan pirates roaming
  the waters. However, upon seizing American sailors and merchants, president Thomas Jefferson,
  rather than paying tribute, has sent the United States navy to attack the Barbary Coast and
  blockade the pirates." Node name 76594 "Barbary Coast (1801)".
- **Scenario text:** "Put a stop to the piracy in the Mediterranean by invading the Barbary coast."
- **Objectives** (name: text / hint):
  - Blockade: "Blockade the Barbary coast by destroying enough pirate Merchant Ships (Caravels) or
    by destroying the docks." / ships travel between the open sea and the docks; each ship sunk
    gives its supplies.
  - Caches: "Destroy all Weapon Caches." / six caches on the mainland and islands; they supply the
    pirates' gunpowder.
  - Prisoner: "Rescue the Dutch Captain." / a Dutch naval captain is held by the pirates; free him
    and escort him.
  - Prisoner 2: "Bring the Dutch Captain to the flag on the neutral island." / guard him, prepare
    a ship.
  - Storages: "Raid Barbary storage buildings to claim additional resources." / spoils of earlier
    raids in "ramshackle huts and sheds".
  - Swedes: "Protect the Swedish Miners." / the Swedes tribute the coin they dig while alive;
    their force is weak.
- Counters: "Weapons Caches Destroyed: n/6", "Trade Routes Blocked: n/2"; victory "You are
  Victorious!".

What each civ lets the player 2 AI train in the buildings it has (static reading of the civ's
Age0 and Colonial techs and the techs they set active, against each building's `<Train>` list;
to confirm in game):

| Civ | Barracks | YPBarracksIndian | Stable | ypCaravanserai | ArtilleryDepot | FortFrontier |
|---|---|---|---|---|---|---|
| Indians (now) | — | ypRajput, ypSepoy, ypNatMercGurkha | — | ypMahout, ypHowdah, ypSowar, ypZamburak | — | the same Indian units |
| Ottomans | Janissary, Nizam | — | WOLDeli, CavalryArcher | — | AbusGun, Humbaraci, Falconet, Mortar, xpPetard | Nizam, Janissary, Humbaraci, AbusGun, NAmarine, WOLDeli, CavalryArcher |
| Egyptians | — | — | — | — | — | — (they use caravans) |
| Saudis | WOLLineInfantry | — | — | — | MEZamburak, Midfa, MEMortar | WOLLineInfantry |
| Pirate (hidden, British copy) | Redcoat, GreenJacket, ArtistsRifle | — | CuloCereza, HouseholdBlue, WOLScotsGrey | — | Falconet, Mortar, xpPetard | British units |

So today the Tripolitan AI, when it has resources, can field Sepoys, Rajputs, Gurkhas and war
elephants. The look of player 2's buildings does not depend on its civ: the trigger *Override
Culture for Art = Mediterranean* picks the Mediterranean branch of every building set (barracks,
stables, foundry, arsenal, outpost, fort, dock, walls and `HouseMed` all have one; walls have no
Ottoman branch).

### The history (with sources)

- **War and dates.** Tripoli (Ottoman Tripolitania, autonomous under Yusuf Karamanli, pasha
  since 1795) declared war on the United States on 10 May 1801 by cutting down the flagstaff of
  the US consulate; the treaty ended it in June 1805 (4 or 10 June, sources differ).
  **Algiers and Tunis did not join**; Morocco was briefly hostile in 1802.
  ([First Barbary War](https://en.wikipedia.org/wiki/First_Barbary_War),
  [Yusuf Karamanli](https://en.wikipedia.org/wiki/Yusuf_Karamanli))
  The load text's "fierce Algerians and Tripolitan pirates" is therefore half right: the enemy
  of 1801 is Tripoli alone.
- **US Navy.** Squadrons of frigates (*Constitution*, *Philadelphia*, *President*, *Chesapeake*,
  *Constellation*, *Congress*, *Essex*, *John Adams*), schooners (*Enterprise*, *Vixen*,
  *Nautilus*), brigs (*Argus*, *Syren*, *Scourge*), the ketch *Intrepid*, the sloop *Hornet*, and
  gunboats and mortar boats lent by the Kingdom of Naples and Sicily. First squadron (Dale, 1801):
  3–4 frigates and 1 schooner. No steam: the first commercial steamboat sailed in 1807.
  First action, 1 August 1801: schooner *Enterprise* (12 guns) against the polacca *Tripoli*
  (14 guns, two masts, lateen sails).
  ([First Barbary War](https://en.wikipedia.org/wiki/First_Barbary_War),
  [Action of 1 August 1801](https://en.wikipedia.org/wiki/Action_of_1_August_1801))
- **Land fighting.** Derna, April–May 1805: 7–8 US Marines under Lt. Presley O'Bannon, a few
  navy men, about 70 Greek mercenaries and several hundred Arab and Berber horse and foot of
  Hamet Karamanli, two field guns landed from the ships; the brig *Argus*, sloop *Hornet* and
  schooner *Nautilus* shelled the batteries. Derna's garrison about 800, a relief force of 1 200
  under Hassan Bey. ([Battle of Derna](https://en.wikipedia.org/wiki/Battle_of_Derna_(1805)))
- **Tripoli's forces.** A walled city with about 150 heavy guns; "25,000 soldiers" in the body of
  the article against 4 000 in its infobox (uncertain); 10 brigs of ten guns, 2 schooners, 2 large
  galleys, 19 gunboats; Rais Mahomet Rous commanded at sea in 1801
  ([First Barbary War](https://en.wikipedia.org/wiki/First_Barbary_War)). The regency's army had
  a janissary corps and the *kouloughlis* (men of part-Turkish descent)
  ([Ottoman Tripolitania](https://en.wikipedia.org/wiki/Ottoman_Tripolitania)); tribal Arab and
  Berber horse fought on both sides at Derna. The admiral Murad Rais was a Scottish renegade,
  Peter Lyle, in Tripoli from 1794 (one footnote of a consular edition, [Cambridge](https://www.cambridge.org/core/journals/royal-historical-society-camden-fifth-series/article/consular-and-diplomatic-correspondence-from-tripoli/BFC2C7A10DBA7043B62DC30C0044AF6B); his rank in 1801–05 is uncertain).
- **Flags.** US: 15 stars and 15 stripes (1795–1818). Tripoli: no official flag; sources show
  red flags with one to three crescents, a green flag with three crescents (dated 1711–1835) and
  horizontal red/green/white stripes; which one flew in 1801 is **uncertain**
  ([List of Libyan flags](https://en.wikipedia.org/wiki/List_of_Libyan_flags),
  [FOTW, Tripoli](https://www.crwflags.com/fotw/flags/ly_trip.html)).
- **Sweden.** Sweden fought Tripoli in 1796–1802 over tribute (20 ships and 160 sailors taken in
  1798; a peace of 1798 broke down and Tripoli declared war again in 1800). In 1802 a Swedish
  squadron under Rudolf Cederström (frigates *Thetis*, *Fröja*, *Camilla*, *Sprengporten*, brig
  *Husaren*) blockaded Tripoli with the Americans and escorted convoys; the two fought Tripolitan
  corsairs on 16 May 1802; Sweden made its own peace in October 1802 and paid tribute.
  ([Swedish–Tripolitanian war](https://en.wikipedia.org/wiki/Swedish%E2%80%93Tripolitanian_war_(1796%E2%80%931802)))
  **No source mentions Swedish miners or a gold mine in Tripolitania: the mining camp is fiction.**
  A Swedish *naval* ally is history, in 1802.
- **The Dutch.** No source found for Dutch (Batavian Republic) involvement in 1801–05; "Captain
  Van Lesen" is fiction. The historical prisoners were the 307 men of the frigate *Philadelphia*,
  run aground and taken in October 1803 and held until 1805 (Capt. William Bainbridge).
  ([First Barbary War](https://en.wikipedia.org/wiki/First_Barbary_War))

### Replacements

The mission keeps its map, triggers and objectives; only protos, civs and trigger proto names
change. Every replacement keeps or shrinks the footprint (obstruction radii from `protoy.xml`), so
nothing new overlaps. HP and pop are shown where the balance moves.

| Current → proposed | Where | Reason |
|---|---|---|
| Civ Indians → **Ottomans** (players 2 and 3) | `player:` | Tripoli was an Ottoman regency; the AI then trains Janissary, Nizam, Deli, Abus guns, Humbaraci instead of Sepoys and elephants |
| ypHouseIndian (2×2) → **HouseMed** (2×2) | 66 placed, player 2 | the Ottoman/Mediterranean house; same footprint and pop |
| YPBarracksIndian (4×4) → **Barracks** (4×4) | 4 placed (1877, 1878, 1940, 2265) | same footprint; the Ottomans can train in it; with the culture override it looks like the other three barracks |
| ypCaravanserai (3×5) → **Stable** (3×5) | 2 placed (1699, 1879) | same footprint and axes |
| WOLRuca (4×4, Mapuche *ruka*) → **africanGranary** (3×3) or **SPCXPAmmoStorehouse** (2×2) | 7 storage huts 2624–2631 | a Chilean hut in Tripoli; the granary is a North-African-style store (render to choose; the storehouse looks like the weapon caches, which may confuse the two objectives) |
| Seimen ("Recruit", HP 130) → **Janissary** (HP 250) or **WOLMercBashiBazouk** (HP 100) | 46 placed, 54 deployed, renamed "Barbary Musketeer" | Tripoli's musketeers were janissaries and irregulars; Janissary doubles the HP (harder), Bashi-bazouk keeps it |
| Rodelero (16th-c. Spanish sword and buckler, HP 135) → **MercBarbaryCorsair** (HP 315, pop 2) or **Azap** (HP 160) | 22 placed, 23 deployed, "Barbary Swordsman" | a Barbary swordsman should look like one; Azap keeps the stats but is a 15th–16th-c. Ottoman type |
| WOTTANatMercPirate / WOTTANatPirate (Caribbean pirate) → **MercBarbaryCorsair** | 31 placed, 14 deployed | corsair crews |
| ypThuggee, ypDacoit (Indian outlaws) → **WOLMercBashiBazouk** | 29 placed, 2 deployed | irregular musketeers of the Ottoman world |
| ypNatMercTigerClaw (Indian) → **MercBarbaryCorsair** (placed) / **NatDervish** (deploys) | 9 placed, 15 deployed | hand infantry; NatDervish is not in the saved proto table, so only trigger deploys can use it (or rename an unused 10-letter table entry, e.g. `Carabinero`) |
| ypMercArsonist (fire bombs) → **WOLAURKouloughli** ("Maghrebi warrior of Turkish descent that throws fire bombs") | 10 placed, 8 deployed | same role; the kouloughlis were part of Tripoli's army |
| ypMahout (war elephant) → **MercMameluke** or **WOLMercSpahi** ("Berber mercenary cavalry") | 1 placed | no elephants in Libya |
| Akinci (14th–16th-c. raider) → **WOLMercSpahi** or **WOLDeli** | 11 placed, 7 deployed | tribal or Ottoman horse; Sipahi's text says "Berber" |
| AFRICANfellah, AFRICANcamelrider, AFRICANmehariste, AfricanNaffatun, MercMameluke, AbusGun, Falconet | — | **keep**: levies, camel riders and light guns fit; *méhariste* is a later French name, the look is a camel gunman (uncertain fit) |
| Cannon ("Steel Gun", 1870s Schneider) → **Falconet** or **Mortar** | 1 placed, 4 deployed | period field gun; the city's batteries were heavy guns |
| NAkingsmousquetaire 2841 "Barbary Pirate Captain" → **AFRICANalipasha** or **MercBarbaryCorsair** | 1 | a Tripolitan *rais*, not a French royal musketeer (Ali Pasha's model is a Turkish officer; render to choose) |
| Privateer (army 2,29) → keep, or **AFRICANxebec** | 5 deploy effects (4 ships, one has count 0) | Tripoli's cruisers were polaccas, brigs, xebecs; WoL has no polacca. Not `CorsairGalley`/`GRD*`: they are treasure guardians (`Guardian` type) |
| Galley | 4 | keep: Tripoli had galleys |
| Caravel "Barbary Merchant Ship" → **AFRICANxebec** | 2 deployed (3,38, 3,39) | a 15th-c. ship; the xebec was the Mediterranean's coaster. Check that the route triggers work with it (they track the army, not the proto) |
| Steamboat (player 1) → **Schooner** (trains `NAmarine`, carries 15) or **Frigate** (carries 50, trains nothing) | 3 placed + trigger `Player Unit Count Steamboat` (→ `trigger:Steamboat=…`) | no steam in 1801. Schooner keeps the mechanic of landing troops from the ships, but then player 1 trains only marines there (the historical force); Frigate needs the Dock to supply troops. Possible mix: 1679 → Frigate, 1684 and 1685 → Schooner |
| NAnapoleon (1857 gun), end reward 3539 → **Falconet** | Change Unit Type | period gun |
| `NAtinclad` forbid → retarget to `PaddleSteamer` or `xpIronclad` | trigger | the US Dock offers Schooner, PaddleSteamer, xpIronclad: one steam ship can be forbidden this way (scnfix changes values, it cannot add effects) |
| WOLBevaring (Swedish conscript, from 1812) → keep, or **Grenadier** / **Musketeer** | 12 deployed | closest Swedish line infantry in WoL; the *beväring* is about ten years late |
| Caravel 3466 (Swedish) → **Frigate** | Change Unit Type | Cederström's squadron were frigates |
| WOLMercBlueGuard "Captain Van Lesen" → keep, or **Explorer** | 1 | a 17th-c. Dutch guard; Explorer is an officer figure. Making him American (Bainbridge) needs new texts, see below |

Player names and texts ("Swedish Mining Operation", "Dutch Captain", the Algerians of the load
text) stay: `scnfix.py` cannot yet rewrite a player name or an objective text (length-prefixed
UTF-16 inside chunks whose sizes would change). Suggested if the tool learns it: player 3 "Tripolitan
Corsairs", player 4 "Swedish Squadron", load text "…the Tripolitan corsairs…".

### Hidden civs and flags

Flags come from the civ (`<homecityflagtexture>`). Found in the art (loose files win over the
archives; inference from the load order, to see in game):

| Side | Now | Best existing texture | Note |
|---|---|---|---|
| United States | `War of the Triple Alliance\Flags\american` (34 stars) | `objects\flags\USA` (loose: 13 stars in a circle, 1777–1795) | the 1801 flag (15/15) does not exist; make it with aoe3-blender-tools if wanted |
| Tripoli | `objects\flags\india` | `objects\flags\ottomans` (archive: red, white crescent and star) | the crescent-and-star design is of 1844; a period Tripoli flag (red/green/white stripes or green with three crescents) would be a new texture |
| Sweden | union ensign 1844–1905 (both WoL files) | `objects\flags\swedish` (archive: plain blue with yellow cross) | right for 1801 |
| Dutch | `objects\flags\dutch` (tricolour) | keep | the Batavian Republic flew the tricolour (its naval ensign details uncertain) |

`objects\flags\pirate` is WoL's loose East India Company flag, not a Jolly Roger
(`pirate_slant` in the archive is one), so the hidden `Pirate` civ is no help.

Hidden civs needed, each `visible 0`, appended **after the last `<civ>`** of `civs.xml` so no
existing civ ID moves (players are stored as numbers):
- **Tripolitans:** a copy of Ottomans with `objects\flags\ottomans` (or a new Tripoli texture);
  only needed if the flag must differ from the Ottomans'. With plain Ottomans the flag is already
  the red crescent.
- **United States 1801:** a copy of UnitedStates with `objects\flags\USA`.
- **Sweden 1802:** a copy of Swedish with `objects\flags\swedish`.
- The display names can reuse the originals' string IDs (no "Tripoli" civ string exists; 76594 is
  the node name).

A player whose civ is not in the scenario's own civ table still loads (observed: Hakodate's
`SPCJapanese`), so the hidden civs need no change of that table. The player's home city file stays
as saved (Laguna's Brazilians on the Italian home city work); player 2 is an AI without shipments.

### Risks

- **The saved proto table.** `unit:ID=PROTO` only takes protos the scenario's table has. Of the
  candidates, `NatDervish`, `CorsairDhow`, `Ghazi`, `Jundi`, `Faris`, `Jamal`, `FrenchZouave`,
  `Agayl` are missing: trigger deploys can name them (any length), placed units only after renaming
  an unused table entry of the same length (`proto:`; 171 dead entries, e.g. `Carabinero` (10),
  `Bacamartero` (11)).
- **Balance.** Janissary (250 HP) for Recruit (130) and Corsair (315 HP, pop 2) for Rodelero (135)
  make the mission harder; Schooners for Steamboats change how player 1 gets an army. Play it.
- **The AI with Ottomans** (or a hidden civ the AI scripts do not know): the AI must still compile
  and play; check `XS: Error` in the log and a few minutes of play. A hidden civ has no
  `cCiv…` constant in the AI, so civ-specific code takes its default path (inference).
- **Player N passes through civ N** while loading (see Laguna): players 2–7 get and lose
  `Age0Egyptian`, `Age0zulu`, `Age0American`, `Age0australian`, `Age0Canadian` and the 7th civ's
  age tech. Their `Assign` effects hit only TownCenter, CoveredWagon, Zulu units, WOLPioneer and
  FurTrader, none of which this mission uses (checked); `civs.xml` additions at the end do not
  change it.
- **Data files in the pack.** Hidden civs mean shipping `civs.xml`; a WoL update overwrites it
  (same as the base fix's `techtreey.xml`). Ship the additions as a snippet to paste too.
- **Look.** Every replacement must be rendered and seen in game with the Mediterranean override
  (the list below), and the flags on the buildings checked.
- **`GRD*` and `CorsairGalley`** are treasure guardians (`Guardian`, `WaterGuardian`): not for
  armies.

### Models to render

Saved as `m1-list.txt` (scratchpad `sheets\`) in the `caption | proto` format of
`model_sheets.py --models`. Current first, then candidates:

```
# Barbary Coast 1801 - current
US steamboat | Steamboat
US dock | Dock
US Napoleon gun (end reward) | NAnapoleon
US marine | NAmarine
US spontooner | NAspontooner
US rifleman | NArifleman
US light cavalry | NAlightcavalry
US mounted rifle | NAmountedrifle
Indian house | ypHouseIndian
Indian barracks | YPBarracksIndian
Caravanserai | ypCaravanserai
Storage hut (Ruca) | WOLRuca
Large tent | SPCTentLarge
Mediterranean house | HouseMed
Barracks | Barracks
Stable | Stable
Artillery foundry | ArtilleryDepot
Arsenal | Arsenal
Redoubt | Outpost
Lookout | Lookout
Fort Tripoli | FortFrontier
Weapon cache | SPCWeaponsCache
Prison stockade | SPCStockades
Barbary Musketeer (Recruit) | Seimen
Barbary Swordsman (Rodelero) | Rodelero
Pirate | WOTTANatMercPirate
Barbary corsair | MercBarbaryCorsair
Thuggee | ypThuggee
Dacoit | ypDacoit
Tiger claw | ypNatMercTigerClaw
Arsonist | ypMercArsonist
Mahout | ypMahout
Camel rider | AFRICANcamelrider
Mehariste | AFRICANmehariste
Fellah | AFRICANfellah
Naffatun | AfricanNaffatun
Akinci | Akinci
Abus gun | AbusGun
Falconet | Falconet
Steel gun | Cannon
Cairo Mamluk | MercMameluke
Pirate captain (Mousquetaire du Roi) | NAkingsmousquetaire
Privateer | Privateer
Galley | Galley
Merchant ship (Caravel) | Caravel
Fishing boat | FishingBoat
Swedish settler | Settler
Bevaring | WOLBevaring
Frontier wagon | OutpostWagon
Captain Van Lesen (Blue Guard) | WOLMercBlueGuard
# candidates
Janissary | Janissary
Nizam-i Cedid | Nizam
Bashi-bazouk | WOLMercBashiBazouk
Kouloughli | WOLAURKouloughli
Azap | Azap
Dervish | NatDervish
Sipahi (Berber) | WOLMercSpahi
Spahi | Spahi
Deli | WOLDeli
Humbaraci | Humbaraci
Mortar | Mortar
Tuareg | GRDTuareg
Ali Pasha | AFRICANalipasha
Explorer | Explorer
Xebec | AFRICANxebec
Corsair galley | CorsairGalley
Corsair dhow | CorsairDhow
Frigate | Frigate
Schooner | Schooner
Gunboat | WOLGunboat
Granary | africanGranary
Ammunition storehouse | SPCXPAmmoStorehouse
Swedish grenadier | Grenadier
Musketeer | Musketeer
```

### Open questions

- Schooners only, or one Frigate and two Schooners, for player 1 (how the player gets troops)?
- Janissary (harder) or Bashi-bazouk (same strength) for the 100 "Barbary Musketeers"?
- Keep the Swedish miners and the Dutch captain as the story's fiction, or extend `scnfix.py` to
  rewrite player names and objective texts (Swedish squadron; an American prisoner)?
- New flag textures (US 15/15, Tripoli) through aoe3-blender-tools, or the existing stand-ins?
- Plain Ottomans for the Tripolitans (no `civs.xml` change for them) or a hidden copy?

## Tools

- `tools/campaigncheck.py <game folder>`: the static check of all of the above (civ table, player
  civs, placed protos, saved names, trigger parameters). On the bed as shipped: 46 misses, every
  one of them explained here. `--scn` alone checks a fixed set outside the game folder.
  `--inventory --scn <file>` (or `--units`, the same option) prints, per player, civ, flag,
  culture, home city, AI, placed units, the units triggers name (editor and in-game IDs), what the
  triggers deploy or change, then the objectives (ID, name, text, hint) and the trigger texts (a
  text parameter, type 22, keeps its text after an empty value: the parser now skips it, so
  effects after such a parameter, like *Overlay Text*'s, are no longer lost).
- `tools/scnfix.py`: writes a copy of a scenario with civ-table names, saved proto names, player
  civs, single units' protos (`unit:ID=PROTO`) or trigger parameters (`trigger:`, `tech:`, any
  length: the `TR` and `BG` chunk sizes follow) changed, and its CRC.
- `tools/re/trace_exec.py` also logs a breakpoint's first three stack arguments.

## Open

- The objectives were not played to their end (above): that needs a person at the mouse.
- `jumpToNextCampaignNode` and `campaignAdvance` do nothing from the console; `winScenario`
  works. On the campaign screen *Play* runs the current node (the farthest unlocked), not the
  one selected.
