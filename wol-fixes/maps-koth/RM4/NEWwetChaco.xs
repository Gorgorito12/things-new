include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";

float status = 0.0;

int classPlayer = -1;

int constPlayerLong = -1;
int constNugget = -1;
int constCircle = -1;
int constAll = -1;
int constGoldLong = -1;
int constImpassableLandShort = -1;
int constStartingUnits = -1;
int constImportantItemShort = -1;
int constHuntable = -1;
int constTownCenter = -1;
int constImpassableLand = -1;
int constForest = -1;
int constFish = -1;
int constLand = -1;


void defineClasses( void )
{
    classPlayer=rmDefineClass("player");
    rmDefineClass("importantItem");
    rmDefineClass("startingUnit");
    rmDefineClass("classForest");
}


void defineConstraints( void )
{
    constAll=rmCreateTypeDistanceConstraint("All", "All", 6.0);
    constCircle=rmCreatePieConstraint("Circle", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
    constNugget=rmCreateTypeDistanceConstraint("Nugget", "AbstractNugget", 50.0);
    constImportantItemShort=rmCreateClassDistanceConstraint("ShortImportant", rmClassID("importantItem"), 8.0);
    constPlayerLong=rmCreateClassDistanceConstraint("LongPlayer", classPlayer, 24.0);
    constGoldLong=rmCreateTypeDistanceConstraint("LongGold", "Gold", 45.0);
    constImpassableLandShort=rmCreateTerrainDistanceConstraint("ShortImpassableLand", "Land", false, 1.0);
    constImpassableLand=rmCreateTerrainDistanceConstraint("ImpassableLand", "Land", false, 5.0);
    constStartingUnits=rmCreateClassDistanceConstraint("StartingUnits", rmClassID("startingUnit"), 8.0);
    constHuntable=rmCreateTypeDistanceConstraint("Huntable", "Huntable", 10.0);
    constTownCenter=rmCreateTypeDistanceConstraint("TownCenter", "TownCenter", 30.0);
    constForest=rmCreateClassDistanceConstraint("Forest", rmClassID("classForest"), 3.0);
    constFish=rmCreateTypeDistanceConstraint("Fish", "Fish", 12.0);
    constLand=rmCreateTerrainDistanceConstraint("Land", "Land", true, 5.0);
}


void buildLake( float m = 0.0, float n = 1.0, float x = 0.5, float z = 0.5 )
{
    static int lake = 0;
    int lakeArea = rmCreateArea( "Lake "+lake );
    rmSetAreaWaterType( lakeArea, "great lakes" );
    rmSetAreaSmoothDistance( lakeArea, 10.0 );
    rmSetAreaLocation( lakeArea, x, z );
    rmSetAreaSize( lakeArea, m, n );
    rmSetAreaBaseHeight( lakeArea, 1.0 );
    rmSetAreaCoherence( lakeArea, 0.5 );
    rmSetAreaObeyWorldCircleConstraint( lakeArea, false );
    rmBuildArea( lakeArea );
    lake++;
}


void placeGrouping( string name = "", float x = 0.0, float z = 0.0 )
{
    static int grp = 0;
    int grpng = rmCreateGrouping( "Grpng "+grp, name );
    rmSetGroupingMinDistance( grpng, 0.0 );
    rmSetGroupingMaxDistance( grpng, 0.0 );
    rmPlaceGroupingAtLoc( grpng, 0, x, z );
    grp++;
}


void placeFish( string fishProto = "", float x = 0.0, float z = 0.0, int n = 1 )
{
    static int fish = 0;
    int fishID=rmCreateObjectDef("Fish"+fish);
    rmAddObjectDefItem(fishID, fishProto, 3, 12.0);
    rmSetObjectDefMinDistance(fishID, 0.0);
    rmSetObjectDefMaxDistance(fishID, 50.0);
    rmAddObjectDefConstraint(fishID, constFish);
    rmAddObjectDefConstraint(fishID, constLand);
    rmPlaceObjectDefAtLoc(fishID, 0, x, z, n );
    fish++;
}


void placeNugget( int minLevel = 0, int maxLevel = 1 )
{
    static int nugget = 0;
    int treasure= rmCreateObjectDef("Nugget "+nugget); 
    rmAddObjectDefItem(treasure, "Nugget", 1, 0.0);
    rmSetNuggetDifficulty(minLevel, maxLevel);
    rmSetObjectDefMinDistance(treasure, 0.0);
    rmSetObjectDefMaxDistance(treasure, rmXFractionToMeters(0.5));
    rmAddObjectDefConstraint(treasure, constPlayerLong);
    rmAddObjectDefConstraint(treasure, constImportantItemShort);
    rmAddObjectDefConstraint(treasure, constNugget);
    rmAddObjectDefConstraint(treasure, constCircle);
    rmAddObjectDefConstraint(treasure, constAll);
    rmSetObjectDefMinDistance(treasure, 80.0);
    rmSetObjectDefMaxDistance(treasure, 120.0);
    rmPlaceObjectDefPerPlayer(treasure, false, 1);
    nugget++;
}


void main( void )
{
    wotta_triggers();
    rmSetStatusText( "", 0.01 );
    
    int playerTiles = 18000;
    if ( cNumberNonGaiaPlayers >= 5 )
        playerTiles = 11000;
    if ( cNumberNonGaiaPlayers >= 7 )
        playerTiles = 9000;
    int size = 1.8 * sqrt( cNumberNonGaiaPlayers * playerTiles );
    rmSetMapSize( size, size );
    
    rmSetLightingSet( "309a_summoned" );
    
    rmSetSeaLevel( 1.0 );
    rmSetSeaType( "Chaco" );
    rmEnableLocalWater( false );
    
    rmSetBaseTerrainMix( "araucania_north_grass_a" );
    rmTerrainInitialize( "water" );
    rmSetMapType( "brazil" );
    rmSetMapType( "amazonia" );
    rmSetMapType( "water" );
    rmSetWorldCircleConstraint( true );
    
    rmSetStatusText( "", 0.05 );
    
    defineClasses();
    defineConstraints();
    
    int mainArea = rmCreateArea( "Main Area" );
    rmSetAreaMix( mainArea, "araucania_north_grass_b" );
    rmSetAreaBaseHeight( mainArea, 4.0 );
    rmSetAreaSize( mainArea, 1.0, 1.0 );
    rmSetAreaCoherence( mainArea, 1.0 );
    rmSetAreaSmoothDistance( mainArea, 0 );
    rmSetAreaElevationType( mainArea, cElevTurbulence );
    rmSetAreaElevationVariation( mainArea, 5.0 );
    rmSetAreaObeyWorldCircleConstraint( mainArea, false );
    rmBuildArea( mainArea );
    
    buildLake( 0.06, 0.08, 0.15, 0.15 );
    rmSetStatusText( "", 0.10 );
    buildLake( 0.06, 0.08, 0.85, 0.85 );
    rmSetStatusText( "", 0.15 );
    buildLake( 0.06, 0.08, 0.85, 0.15 );
    rmSetStatusText( "", 0.20 );
    buildLake( 0.06, 0.08, 0.15, 0.85 );
    rmSetStatusText( "", 0.25 );
    placeFish( "FishBass", 0.15, 0.15, 3*cNumberNonGaiaPlayers );
    placeFish( "FishBass", 0.85, 0.85, 3*cNumberNonGaiaPlayers );
    placeFish( "FishBass", 0.85, 0.15, 3*cNumberNonGaiaPlayers );
    placeFish( "FishBass", 0.15, 0.85, 3*cNumberNonGaiaPlayers );
    
    rmAllocateSubCivs( 4 );
    rmSetSubCiv( 0, "Guarani" );
    rmSetSubCiv( 1, "Guarani" );
    rmSetSubCiv( 2, "Guaicuru" );
    rmSetSubCiv( 3, "Guaicuru" );
    
    placeGrouping( "native guarani village "+rmRandInt( 1, 3 ), 0.85, 0.5 );
    placeGrouping( "native guarani village "+rmRandInt( 1, 3 ), 0.5, 0.85 );
    placeGrouping( "native guaicuru village "+rmRandInt( 1, 3 ), 0.5, 0.15 );
    placeGrouping( "native guaicuru village "+rmRandInt( 1, 3 ), 0.15, 0.5 );
    rmSetStatusText( "", 0.30 );
    
    int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
    rmSetObjectDefMinDistance(startingUnits, 4.0);
    rmSetObjectDefMaxDistance(startingUnits, 8.0);
    rmAddObjectDefToClass(startingUnits, rmClassID("startingUnit"));
    rmAddObjectDefToClass(startingUnits, classPlayer);

    int townCenter = rmCreateObjectDef("player TC");
    if ( rmGetNomadStart() ==true )
        rmAddObjectDefItem(townCenter, "CoveredWagon", 1, 0.0);
    else
        rmAddObjectDefItem(townCenter, "townCenter", 1, 0.0);
    rmSetObjectDefMinDistance(townCenter, 0.0);
    rmSetObjectDefMaxDistance(townCenter, 10.0);
	rmAddObjectDefToClass(townCenter, rmClassID("startingUnit"));
	rmAddObjectDefToClass(townCenter, classPlayer);

    int playerSilverID = rmCreateObjectDef("player silver");
    rmAddObjectDefItem(playerSilverID, "mine", 1, 0);
    rmSetObjectDefMinDistance(playerSilverID, 12.0);
    rmSetObjectDefMaxDistance(playerSilverID, 20.0);
	rmAddObjectDefToClass(playerSilverID, rmClassID("startingUnit"));
    rmAddObjectDefConstraint(playerSilverID, constStartingUnits);

    int StartAreaTreeID=rmCreateObjectDef("starting trees");
    rmAddObjectDefItem(StartAreaTreeID, "TreeChaco", rmRandInt(15,28), 4.0);
    rmSetObjectDefMinDistance(StartAreaTreeID, 4);
    rmSetObjectDefMaxDistance(StartAreaTreeID, 15);
	rmAddObjectDefToClass(StartAreaTreeID, rmClassID("startingUnit"));
    rmAddObjectDefConstraint(StartAreaTreeID, constStartingUnits);

    int startBerryID=rmCreateObjectDef("starting Berries");
    rmAddObjectDefItem(startBerryID, "berrybush", 4, 5.0);
    rmSetObjectDefCreateHerd(startBerryID, true);
    rmSetObjectDefMinDistance(startBerryID, 8);
    rmSetObjectDefMaxDistance(startBerryID, 15);
	rmAddObjectDefToClass(startBerryID, rmClassID("startingUnit"));
    rmAddObjectDefConstraint(startBerryID, constStartingUnits);

    int startHuntID=rmCreateObjectDef("starting hunt");
    rmAddObjectDefItem(startHuntID, "tuiuiu", 5, 5.0);
    rmSetObjectDefCreateHerd(startHuntID, true);
    rmSetObjectDefMinDistance(startHuntID, 8);
    rmSetObjectDefMaxDistance(startHuntID, 12);
	rmAddObjectDefToClass(startHuntID, rmClassID("startingUnit"));
    rmAddObjectDefConstraint(startHuntID, constStartingUnits);
    
    rmSetTeamSpacingModifier( 0.8 );
    rmPlacePlayersCircular( 0.185, 0.2, 0.0 );
    
    float playerFraction=rmAreaTilesToFraction(800);
    for( player = 1; < cNumberPlayers )
    {
        int playerArea = rmCreateArea( "Player" + player );
        rmSetPlayerArea( player, playerArea );
        rmSetAreaLocPlayer( playerArea, player );
        rmSetAreaSize( playerArea, playerFraction * 2, playerFraction );
        rmSetAreaBaseHeight( playerArea, 4.0 );
        rmSetAreaCoherence( playerArea, 0.8 );
        rmSetAreaElevationType( playerArea, cElevTurbulence );
        rmSetAreaElevationVariation( playerArea, 5.0 );
        rmSetAreaMix( playerArea, "araucania_north_grass_c" );
    }
    rmBuildAllAreas();
    rmSetStatusText( "", 0.35 );
    
    for( player = 1; < cNumberPlayers)
    {
        rmPlaceObjectDefAtLoc( townCenter, player, rmPlayerLocXFraction(player), rmPlayerLocZFraction(player) );
        rmPlaceObjectDefAtLoc( startingUnits, player, rmPlayerLocXFraction(player), rmPlayerLocZFraction(player) );
        rmPlaceObjectDefAtLoc( playerSilverID, 0, rmPlayerLocXFraction(player), rmPlayerLocZFraction(player) );
        rmPlaceObjectDefAtLoc( startBerryID, 0, rmPlayerLocXFraction(player), rmPlayerLocZFraction(player) );
        rmPlaceObjectDefAtLoc( startHuntID, 0, rmPlayerLocXFraction(player), rmPlayerLocZFraction(player) );
        rmPlaceObjectDefAtLoc( StartAreaTreeID, 0, rmPlayerLocXFraction(player), rmPlayerLocZFraction(player) );
    }
    rmSetStatusText( "", 0.40 );
    status = 0.40;
    
    for( nuggetLevel = 1; < 5 )
        placeNugget( nuggetLevel, nuggetLevel );
    
    for( mine = 0; < cNumberNonGaiaPlayers * 5 )
    {
        int silverMine = rmCreateObjectDef( "Silver"+mine );
        rmAddObjectDefItem( silverMine, "Mine", 1, 0 );
        rmSetObjectDefMinDistance( silverMine, 0.0 );
        rmSetObjectDefMaxDistance( silverMine, rmXFractionToMeters( 0.45 ) );
        rmAddObjectDefConstraint( silverMine, constGoldLong );
        rmAddObjectDefConstraint( silverMine, constAll );
        rmAddObjectDefConstraint( silverMine, constImpassableLandShort );
        rmAddObjectDefConstraint( silverMine, constStartingUnits );
        rmAddObjectDefConstraint( silverMine, constImportantItemShort );
        rmPlaceObjectDefAtLoc( silverMine, 0, 0.5, 0.5);
        status = status + 0.005;
        rmSetStatusText( "", status );
    }
    
    int armadillo=rmCreateObjectDef("Armadillo herd");
	rmAddObjectDefItem(armadillo, "Armadillo", rmRandInt(8,10), 10.0);
	rmSetObjectDefMinDistance(armadillo, 0.0);
	rmSetObjectDefMaxDistance(armadillo, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(armadillo, constHuntable);
	rmAddObjectDefConstraint(armadillo, constAll);
	rmAddObjectDefConstraint(armadillo, constImpassableLandShort);
	rmAddObjectDefConstraint(armadillo, constTownCenter);
	rmSetObjectDefCreateHerd(armadillo, true);
	rmPlaceObjectDefAtLoc(armadillo, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);

	int tuiuiu=rmCreateObjectDef("Tuiuiu herd");
	rmAddObjectDefItem(tuiuiu, "Tuiuiu", rmRandInt(10,14), 10.0);
	rmSetObjectDefMinDistance(tuiuiu, 0.0);
	rmSetObjectDefMaxDistance(tuiuiu, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(tuiuiu, constHuntable);
	rmAddObjectDefConstraint(tuiuiu, constAll);
	rmAddObjectDefConstraint(tuiuiu, constImpassableLandShort);
	rmAddObjectDefConstraint(tuiuiu, constTownCenter);
	rmSetObjectDefCreateHerd(tuiuiu, true);
	rmPlaceObjectDefAtLoc(tuiuiu, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);
    
    rmSetStatusText( "", 0.65 );
    
    int forestTreeID = 0;
    int numTries=15*cNumberNonGaiaPlayers;
    int failCount=0;
    for( i = 0; < numTries )
    {   
        int forest=rmCreateArea("forest "+i );
        rmSetAreaWarnFailure( forest, false );
        rmSetAreaSize( forest, rmAreaTilesToFraction(200), rmAreaTilesToFraction(400) );
        rmSetAreaForestType( forest, "Chaco Forest" );
        rmSetAreaForestDensity( forest, 0.7 );
        rmSetAreaForestClumpiness( forest, 0.2 );
        rmSetAreaForestUnderbrush( forest, 0.5 );
        rmSetAreaMinBlobs( forest, 30 );
        rmSetAreaMaxBlobs( forest, 60 );
        rmSetAreaMinBlobDistance( forest, 5.0 );
        rmSetAreaMaxBlobDistance( forest, 10.0 );
        rmSetAreaCoherence( forest, 1.0 );
        rmSetAreaSmoothDistance( forest, 10 );
        rmAddAreaToClass( forest, rmClassID("classForest") );
        rmAddAreaConstraint( forest, constForest );
        rmAddAreaConstraint( forest, constAll );
        rmAddAreaConstraint( forest, constImpassableLand );
        rmAddAreaConstraint( forest, constTownCenter );
        if ( rmBuildArea( forest ) == false )
        {
            failCount++;
            if ( failCount == 5 )
                break;
        }
        else
        {
            failCount = 0;
            status = status + 0.023;
            rmSetStatusText( "", status );
        }
    }
    
    rmSetStatusText( "", 1.0 );

  // King of the Hill (added 2026-11 for WoL): the middle of all start positions (the map centre), on open land
  if(rmGetIsKOTH()) {
    // the start point: the middle of all player starts (the map centre when they are spread evenly)
    float kothX = 0.5;
    float kothZ = 0.5;
    float kothN = 0.0;
    float kothSumX = 0.0;
    float kothSumZ = 0.0;
    for (kothP = 1; < cNumberPlayers) {
      kothSumX = kothSumX + rmPlayerLocXFraction(kothP);
      kothSumZ = kothSumZ + rmPlayerLocZFraction(kothP);
      kothN = kothN + 1.0;
    }
    if (kothN > 0.0) {
      kothX = kothSumX / kothN;
      kothZ = kothSumZ / kothN;
    }
    // the hill on the open land nearest to it: within 0.04 of the map side, then 1.5 times farther each
    // try, with the include's placer constraints, 40 m from every Town Center and 10 m from every tree
    int kothAvoidLand = rmCreateTerrainDistanceConstraint("koth hill avoids impassable land", "Land", false, 6.0);
    int kothAvoidAll = rmCreateTypeDistanceConstraint("koth hill avoids all", "all", 4.0);
    int kothAvoidTC = rmCreateTypeDistanceConstraint("koth hill avoids TCs", "TownCenter", 40.0);
    int kothAvoidTrees = rmCreateTypeDistanceConstraint("koth hill avoids trees", "Tree", 10.0);
    int kothAvoidSocket = rmCreateTypeDistanceConstraint("koth hill avoids trade sockets", "socketTradeRoute", 6.0);
    int kothAvoidRoute = rmCreateTradeRouteDistanceConstraint("koth hill avoids trade route", 6.0);
    int kothAvoidFlag = rmCreateTypeDistanceConstraint("koth hill avoids water flags", "HomeCityWaterSpawnFlag", 4.0);
    float kothRadius = 0.04;
    for (kothRound = 0; < 7) {
      int kothHill = rmCreateObjectDef("koth hill " + kothRound);
      rmAddObjectDefItem(kothHill, "ypKingsHill", 1, 0);
      rmSetObjectDefMinDistance(kothHill, 0.0);
      rmSetObjectDefMaxDistance(kothHill, rmXFractionToMeters(kothRadius));
      rmAddObjectDefConstraint(kothHill, kothAvoidLand);
      rmAddObjectDefConstraint(kothHill, kothAvoidAll);
      rmAddObjectDefConstraint(kothHill, kothAvoidTC);
      rmAddObjectDefConstraint(kothHill, kothAvoidTrees);
      rmAddObjectDefConstraint(kothHill, kothAvoidSocket);
      rmAddObjectDefConstraint(kothHill, kothAvoidRoute);
      rmAddObjectDefConstraint(kothHill, kothAvoidFlag);
      rmPlaceObjectDefAtLoc(kothHill, 0, kothX, kothZ, 1);
      if (rmGetNumberUnitsPlaced(kothHill) > 0)
        break;
      kothRadius = kothRadius * 1.5;
    }
  }

}

