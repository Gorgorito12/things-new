GUERRILLA PER CIV FOR WARS OF LIBERTY (request #114)
=====================================================

What the game does today
------------------------
- <Partisans> in civs.xml is only on or off. 1 turns it on, any other number turns it off. A text that is not a
  number counts as 1: the Tupinamba's <partisans>UybassyArcher</partisans> just means "on"; the unit name is not read.
- A building has ONE PartisanType and ONE PartisanCount, the same for every civ. A second <PartisanType> line replaces
  the first. So TownCenter, ArtilleryDepot and Market, which list UybassyArcher and then SerbianInferno, give
  SerbianInferno to every civ with <Partisans>, the Tupinamba too. Seen in game: a Serbian Town Center gave 6
  SerbianInferno.
- When a finished unit of such a civ dies (not by a trigger's Kill), PartisanCount units of PartisanType appear inside
  its footprint, owned by its player.

What the DLL key `partisans` adds
----------------------------------
In the building's proto (protoy.xml):

  <CivPartisan civ="Spanish" count="3">Rodelero</CivPartisan>
      One line per civ. That civ gets this unit and count from this building, even without <Partisans> in civs.xml.
      count is 0 to 100; left out, the building's PartisanCount counts. A civ with no line keeps PartisanType /
      PartisanCount, as today.

  <PartisanFromNearby>30</PartisanFromNearby>
      The units come out beside the owner's living, finished buildings within 30 m, one at a time to each, the closest
      first, instead of out of the destroyed one. The unit and the count are the destroyed building's, so the total does
      not change. With no building in range they come out of the destroyed one, as today. It holds for every civ that
      has a guerrilla on that building.

In techtreey.xml, for the player who gets the tech:

  <Effect type ='Data' amount ='0' subtype ='PartisanType' relativity ='Assign' unittype ='Pikeman'>
      <Target type ='ProtoUnit'>Barracks</Target></Effect>
  <Effect type ='Data' amount ='5' subtype ='PartisanCount' relativity ='Assign'>
      <Target type ='ProtoUnit'>Barracks</Target></Effect>

  PartisanCount: Assign sets it, Absolute adds to it, Percent multiplies it. Each player has their own copy of the
  building, so a tech changes only its player. A saved game applies the techs again when it loads.

This pack
---------
apply_fix.py gives the Spanish a guerrilla of their own on three buildings, as an example of the format:
  TownCenter 4, Barracks 2, Stable 2, unit Rodelero (--unit names another), and adds `partisans` to Startup\wol.cfg
  (or engine-ext\engine-ext.cfg). --nearby 30 also adds <PartisanFromNearby>30</PartisanFromNearby> to those three.
The Serbians and the Tupinamba keep what they have.

    python apply_fix.py "<WoL folder>"                 apply (backup in <WoL folder>\guerrilla-backup\)
    python apply_fix.py "<WoL folder>" --nearby 30     the same, from the nearby buildings
    python apply_fix.py "<WoL folder>" --check         what is applied
    python apply_fix.py "<WoL folder>" --restore       put the backed-up files back

Tested in WoL (2026-11-27), skirmishes against the Serbian AI
---------------------------------------------------------------
- A Spanish Barracks with the Spanish line gave 3 Rodeleros; the Serbian Barracks still gave its 2 SerbianInferno.
- A tech (PartisanType Pikeman, PartisanCount 5): the next Spanish Barracks gave 5 Pikemen, also after a save and load.
- From nearby: a Spanish Stable's 4 Rodeleros came out beside two Houses and an Outpost; with no building in range,
  out of the Stable.
- A trigger's Kill gives no guerrilla (the game's own rule).
- Afterwards the new units walk over to the nearest group of the same unit and stand in a line. The game does that
  without the key too: a building's stock guerrilla drew 3 Rodeleros standing 20 m away.
- Key off: nothing from the Spanish buildings.
Not tested: a foundation in range (it should not count; the test map's foundations came finished).
