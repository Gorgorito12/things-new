THE MAPUCHE COUNCIL FOR WARS OF LIBERTY (request #72)
=====================================================

What it does
------------
Two DLL keys, set up for the Mapuche (WallMapu) by this pack:

1. shipTechLimit: a civ can research only so many "shipment techs" per game. A shipment tech is any tech whose
   cost has Ships, researched on a unit or a building: the council members' techs. Cards sent from the home city
   deck never count.
     - A research counts when it is paid, that is when it is queued. Cancelling it gives the slot back.
     - A repeatable tech (YPInfiniteTech, the crates) counts every time it is researched.
     - At the limit, every other shipment tech is refused: the research does not start (on every machine), and
       nothing is paid. Each shipment tech button shows "3/3" and its tooltip ends with a red line
       "Shipment techs: 3/3, the limit is reached". Below the limit the line is green: "Shipment techs: 2/3".
     - Saved games keep the counts.
   The data: one line in the civ, in data\civs.xml:
       <civ>
           <name>WallMapu</name>
           <ShipTechLimit>10</ShipTechLimit>
   A civ without the line has no limit.

2. homeCityTechsInUnits: a home city card's tech (one with <Flag>HomeCity</Flag>) listed in a unit's or a
   building's <Tech> rows is researched there like a normal tech: it pays its own cost, takes its ResearchPoints,
   and its effects apply when it is done. It is the same tech as the card, so it becomes active either way, and
   the council button goes away once it is researched. Without the key, the game shows the button but a click
   does nothing.
     - Such a research also waits for a land gather point, as the council techs with CheckLandHCGatherPoint do:
       while the player has no Town Center and no other drop point, it is cancelled and refunded, so a card that
       ships units does not lose them. (Note: the Warchief is a drop point, since it has AbstractDaimyo.)
     - A card that is not in the player's deck is unobtainable, so the button would never show: make it
       obtainable for the civ, as Age0Mapuche does for the council techs.
     - It counts towards ShipTechLimit when it costs Ships.

This pack, as an example of the cleanup you asked for:
  - WallMapu gets <ShipTechLimit>10</ShipTechLimit> (or the number you give with --limit);
  - the Wise Woman (MapucheWiseWoman) researches HCNativeLore where she had MapucheNativeLore;
  - Age0Mapuche makes HCNativeLore obtainable instead of MapucheNativeLore.
MapucheNativeLore stays in the techtree, unused. HCNativeLore has neither the Colonialize prerequisite nor the
CheckLandHCGatherPoint flag of MapucheNativeLore: the first means the council can research it in Age I, the second
does not matter (the key checks the gather point). Add a <Prereqs> to the card if you want the same age gate, but it
then applies to the card in every deck too.

Installing
----------
  python apply_fix.py "<WoL folder>" [--limit N]   applies it, with a backup in <WoL folder>\mapuche-backup
  python apply_fix.py "<WoL folder>" --check       says what is applied
  python apply_fix.py "<WoL folder>" --restore     puts everything back

It adds the lines `shipTechLimit` and `homeCityTechsInUnits` to Startup\wol.cfg when the file has none. The keys
come with our UHC.dll, or with our dinput8.dll beside WoL's own DLL (in that case the lines go in
engine-ext\engine-ext.cfg instead, which the script picks when that folder exists).

Files it changes:
  data\civs.xml          the WallMapu civ: <ShipTechLimit>
  data\protoy.xml        MapucheWiseWoman: HCNativeLore in place of MapucheNativeLore
  data\techtreey.xml     Age0Mapuche: HCNativeLore obtainable in place of MapucheNativeLore
  Startup\wol.cfg        the two keys

Options of the keys
-------------------
  shipTechLimit [notext] [log]               notext: no count on the buttons or in the tooltip
  homeCityTechsInUnits [nogathercheck] [log] nogathercheck: only the tech's own gather point flags are checked

Questions for you
-----------------
  - Should a repeatable tech (the crates) count every time (as now), or only the first time?
  - Should a research count while it is queued (as now, so the limit cannot be passed by queueing), and should a
    cancelled one give its slot back (as now)?
  - Should a card on a council member be researchable when the card is not in the deck (then the key would make it
    obtainable for you), or only when it is in the deck?
  - What is the "black town center"? See the report.
