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

In the civ (civs.xml), since 2026-11-27:

  <PartisanNearby>30</PartisanNearby>
      The nearby mode for that civ, radius 30 m. When any finished building of a player of that civ is destroyed (with a
      guerrilla or not; not a wall, not by a trigger's Kill or the owner's delete), each of that player's finished
      buildings within 30 m that has a guerrilla for the civ (its <CivPartisan> line, or PartisanType/PartisanCount with
      <Partisans>) gives ITS OWN unit and count beside itself, with the techs applied, and those units walk to that
      building's gather point (no gather point: they stay beside it). Walls, foundations and buildings without a
      guerrilla give nothing. The destroyed building gives nothing then; when no building with a guerrilla is in range,
      it gives its own, as today.

  <PartisanFromNearby> on a building (0.7.0) is no longer read: the log says so if the data still has it.

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
  (or engine-ext\engine-ext.cfg). --nearby 30 also writes <PartisanNearby>30</PartisanNearby> in the Spanish civ in
  civs.xml (without --nearby a <PartisanNearby> line there is taken out, and so is an old <PartisanFromNearby> line on
  the three buildings).
The Tupinamba get UybassyArcher back: <CivPartisan civ="Tupinamba">UybassyArcher</CivPartisan> on TownCenter,
  ArtilleryDepot and Market, with each building's own PartisanCount (6, 3 and 1). Checked with --check only, not in a
  game: the Tupinamba are not a civ we test with. The mechanism is the one tested with the Spanish.
The Serbians keep what they have: <partisans>1</partisans>, and the last PartisanType of those buildings,
  SerbianInferno.

    python apply_fix.py "<WoL folder>"                 apply (backup in <WoL folder>\guerrilla-backup\)
    python apply_fix.py "<WoL folder>" --nearby 30     the same, with the nearby mode for the Spanish
    python apply_fix.py "<WoL folder>" --check         what is applied
    python apply_fix.py "<WoL folder>" --restore       put the backed-up files back (protoy.xml, civs.xml, the cfg),
                                                       then delete the backup

Tested in WoL (2026-11-27), skirmishes against the Serbian AI
---------------------------------------------------------------
- A Spanish Barracks with the Spanish line gave 3 Rodeleros; the Serbian Barracks still gave its 2 SerbianInferno.
- A tech (PartisanType Pikeman, PartisanCount 5): the next Spanish Barracks gave 5 Pikemen, also after a save and load.
- (0.7.0's nearby mode, replaced on 2026-11-27, see below.)
- A trigger's Kill gives no guerrilla (the game's own rule).
- Afterwards the new units walk over to the nearest group of the same unit and stand in a line. The game does that
  without the key too: a building's stock guerrilla drew 3 Rodeleros standing 20 m away.
- Key off: nothing from the Spanish buildings.
- A foundation destroyed at 4 % gives no guerrilla, and does not count as a nearby building.
- The owner's delete gives no guerrilla (the game's own rule). A building that changed owner gives the guerrilla of its
  owner when it dies.

Tested in WoL (2026-11-27), the nearby mode v2, skirmishes against the Serbian AI, --nearby 30
-----------------------------------------------------------------------------------------------
- A House destroyed with a Barracks, a Stable and a Market (test data: 3 Rodeleros) within 30 m: 2 Rodeleros beside
  the Barracks and 2 beside the Stable walked to their gather points; the Market's 3 (no gather point) stayed beside it.
  Two more Houses, an Outpost foundation and a wall in range, and a Barracks 50 m away, gave nothing.
- A wall destroyed: nothing. A Stable with no building with a guerrilla in range: its own 2 Rodeleros.
- A tech (PartisanType Pikeman, PartisanCount 5 on Barracks), then a save and a load: a House destroyed beside a
  Barracks gave 5 Pikemen.
- A trigger's Kill: nothing. The Serbians: their Barracks gave its 2 SerbianInferno, the Stable beside it nothing.
- After the move, idle units of the same type near each other may come together (the game's own behaviour, also with
  the key off).
- --check and --restore gave protoy.xml, civs.xml and the cfg back byte for byte.
