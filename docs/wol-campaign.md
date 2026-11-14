# WoL campaign: why it does not work (status, 2026-11-13)

Private: not in `tools/export_public.py`'s INCLUDE list. The user reports that Wars of Liberty's
campaign does not work, and wants only WoL's own campaign in the menu (not Blood, Ice and Steel,
The WarChiefs or the tutorial). Evidence: `rea/evidence/age3y-b1a1dab7/wol-campaign-20261113/`
(gitignored): screenshots, the tracer logs `trace-loaderr*.log`, the compiled triggers
`trigtemp-mission*.xs`, `campaigncheck-wolreal3.txt`, `rea-evidence.json`, the profile backup.

**In one line:** every campaign mission fails to load with *"Scenario: wonders\first barbary war
failed to load."* (the font draws `_` as a space), with WoL's own DLL as with ours, because the
missions were saved with civs that WoL's `civs.xml` no longer has. It is a data bug, not a DLL
one. Fixed copies of the three missions are in `wol-fixes/campaign/`.

## Results per mission

Beds: `C:\AoE3-UHC-WoLReal3` (our DLL) and `C:\WoL-Test` (WoL's DLL `c070d138`, with only the
`engine-ext` harness for `multipleInstances background`, `perfExecFile` and `xsErrorLog`).

| # | Node (file) | As shipped | Cause | With the fix | Whose fix |
|---|---|---|---|---|---|
| 1 | Barbary Coast 1801 (`wonders\first_barbary_war`) | "failed to load", both DLLs | civ table: `Habsburgs`, `XPAztec` | Runs (our DLL, 3+ min, score rises, no XS error); players' civs right | Data (WoL) |
| 2 | Laguna 1840 (`wonders\laguna`) | "failed to load", both DLLs | civ table, as above | Loads, but ends at once (below) | Data (WoL) |
| 3 | Hakodate 1869 (`wonders\battle_of_hakodate`) | "failed to load", both DLLs | civ table, as above | Runs with both DLLs (2+ min, no XS error); with only the civ-table fix player 1 is Chilean, with the player fix Japanese (SPC) | Data (WoL) |

Mission 2, Laguna, has two more problems, both in the data:
- **Its player starts with nothing.** 18 placed units of player 1 are protos WoL removed
  (`Carabinero` ×15, `Bacamartero`, `RegimentalLancer`), and six `Army Deploy` triggers deploy
  them too. The game drops such units, so the active rule `_PlayerLosesEverything`
  (`trPlayerUnitAndBuildingCount(1)==0`) fires at once: a defeat, back to the campaign screen.
- **With stand-in protos it wins at once instead.** With those three names renamed in the saved
  proto table (`scnfix.py proto:`, test only: `Skirmisher`, `NatRifleman`, `Guerillainfantry`),
  the mission opens its home city, then counts as won and goes on to node 3. The rule
  `_Obj6_Done` is active from the start and wins when unit 647 is dead; in the file, unit 647 is an
  `UnderbrushAmazon`. Not found: whether that ID was always wrong or the units were renumbered.
  WoL has to say what the removed units should be, then re-save the mission in the editor.

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
- the three missions, rewritten by `tools/scnfix.py`: civ table `Habsburgs` → `TheCircle` and
  `XPAztec` → `Afghans` (same length, both in `civs.xml` with a home city, not otherwise in the
  table), and each player whose home city file belongs to one civ set back to it (US Navy →
  UnitedStates, Barbary Pirates → Indians (their file's home city; WoL to confirm), Swedish Mining
  Operation → Swedish, Van Lesen → Dutch; Garibaldi, Laguna, São José do Norte → Italians;
  Brazilian Navy, Riograndese Republic → Brazilians; Imperial Army → SPCJapanese; Ezo Republic,
  Matsumae → Japanese; Supply Ships → UnitedStates). Players on `homecitybritish.xml` (Storage,
  Sunken Merchant Ship, Wild Animals) are left alone: five civs share that file;
- `data\uipregamenew.xml` without *Learn to Play*.

Tested: missions 1 and 3 run from these files (our DLL; mission 3 also with WoL's DLL with the
civ-table fix). Mission 2 still ends at once (above). **For the WoL team**, the real fix is to open
each mission in the editor once these load, check every player's civ, replace the removed units,
and save: the editor then writes tables that match today's data.

## Tools

- `tools/campaigncheck.py <game folder>`: the static check of all of the above (civ table, player
  civs, placed protos, saved names, trigger parameters). On the bed: 46 misses, every one of them
  explained here.
- `tools/scnfix.py`: rewrites a scenario's civ table names, saved proto names and player civs,
  and writes the CRC.
- `tools/re/trace_exec.py` now also logs a breakpoint's first three stack arguments.

## Open

- Laguna's instant win (`_Obj6_Done`, unit 647): needs WoL's scenario, or a session in the editor.
- `jumpToNextCampaignNode` and `campaignAdvance` did nothing from the console in a campaign
  game; advancing was tested with the `unlockAllSPCScenarios` config instead. On the campaign
  screen *Play* runs the current node (the farthest unlocked), not the one selected.
- The rest of each mission (objectives to the end) was not played.
- The removed trigger techs (Laguna: `Abolition0`, `VeteranMusketeersLA`, `GuardMusketeersLA`,
  `VeteranPikemenLA`; Milazzo: `WOLVeteranBersaglieri`): what the game writes for a tech name it
  cannot map was not observed.
