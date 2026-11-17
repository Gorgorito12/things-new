// Hispaniola -- JSB
// March 2006
// Main entry point for random map script    

include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";

void main(void)
{
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.10);

	// Define Carib Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;

    if (rmAllocateSubCivs(3) == true)
    {
		subCiv0=rmGetCivID("caribs");
		rmEchoInfo("subCiv0 is caribs "+subCiv0);
		if (subCiv0 >= 0)
		rmSetSubCiv(0, "caribs");

		subCiv1=rmGetCivID("caribs");
		rmEchoInfo("subCiv1 is caribs "+subCiv1);
		if (subCiv1 >= 0)
		rmSetSubCiv(1, "caribs");

		subCiv2=rmGetCivID("caribs");
		rmEchoInfo("subCiv2 is caribs "+subCiv2);
		if (subCiv2 >= 0)
		rmSetSubCiv(2, "caribs");
	}

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	// 1 - Four Caribs, next to the big mountain and at the ends of the 2 long peninsulas. 
	// 2 - Four Caribs, at the ends of the 2 long peninsulas, and 2 on SE end of island.
    // 3 - Six Caribs, next to the mountain, 2 on the long peninsula, and 2 on SE end of island. 

	int whichVariation=-1;
	whichVariation = rmRandInt(1,3);
	// The line below can be uncommented to force the variation to the number indicated, for testing.
	// whichVariation = 3; 

	rmEchoInfo("Map Variation: "+whichVariation);
	
	chooseMercs();
	wotta_triggers();

	if ( cNumberNonGaiaPlayers > 7 )	//If 8 player game, use only variation #2 so map builds more quickly.
	{
		whichVariation = 2;
	}
	
	// Set size of map
	int playerTiles=23500;
	if (cNumberNonGaiaPlayers >4)   // If more than 4 players...
		playerTiles = 18000;		// ...give this many tiles per player.
	if (cNumberNonGaiaPlayers >7)	// If more than 7 players...
		playerTiles = 20000;		// ...give this many tiles per player.	
	int size=2.5*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Set up default water type.
	rmSetSeaLevel(1.0);          
	rmSetSeaType("Aegean Sea");
	rmSetBaseTerrainMix("caribbean grass");
	rmSetMapType("mediterranean");
	rmSetMapType("grass"); 
	rmSetMapType("water");
	rmSetLightingSet("caribbean");

	// Initialize map.
	rmTerrainInitialize("water");
//	rmSetGaiaCiv(cCivBritish);
		
	// Misc variables for use later
	int numTries = -1;
		int failCount = -1;

		
	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
	int classMajorIsland=rmDefineClass("major island");
	int classCliffIsland=rmDefineClass("cliff island");
	int classIslandSmall=rmDefineClass("islandsmall");
		int classIslandSocket=rmDefineClass("socketisland");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("classSocket");
	int classCrete=rmDefineClass("classcrete");
	rmDefineClass("center");
	int continent=rmDefineClass("continent");
	rmDefineClass("isles");
	rmDefineClass("classWaterTradeRoute");
	rmDefineClass("classCliff");
	int classStartingUnits = rmDefineClass("Starting Units");
	
	string herdableType = "ypWaterBuffalo";
  string huntable1 = "ypIbex";
  string huntable2 = "Deer";
  string fish1 = "FishSardine";
  string fish2 = "FishBass";
  string whale1 = "HumpbackWhale";
  string startTreeType = "TreeNorthwestTerritory";
  
   // -------------Define constraints----------------------------------------

    // Create an edge of map constraint.
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Player area constraint.
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 25.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("long stay away from players", classPlayer, 60.0);
	int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 20.0);
	int nearWater10 = rmCreateTerrainDistanceConstraint("near water", "Water", true, 10.0);
	int nearWaterDock = rmCreateTerrainDistanceConstraint("near water for Dock", "Water", true, 0.0);
	int avoidTC=rmCreateTypeDistanceConstraint("stay away from TC", "TownCenter", 26.0);    //Originally 20.0 -- This adjustment, as well as changing the rmSetObjectDefMaxDistance to 12.0, has corrected the problem of nomad sometimes not placing CW for each player.
	int avoidTP=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets", "SocketTradeRoute", 14.0);  // JSB 1-11-05 - Just added, to try to prevent things from stomping on TPs.
	int avoidCW=rmCreateTypeDistanceConstraint("stay away from CW", "CoveredWagon", 24.0);
	int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);



	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish2", fish1, 25.0);			// was 50.0
	// int fishVsFishTarponID=rmCreateTypeDistanceConstraint("fish v fish2", "fishTarpon", 20.0);  // was 40.0 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 2.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "HumpbackWhale", 40.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 17.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int avoidCoin=-1;

	int creteConstraint=rmCreateClassDistanceConstraint("avoid crete", rmClassID("classCrete"), 20.0);
	int continentConstraint=rmCreateClassDistanceConstraint("avoid continent", rmClassID("continent"), 20.0);
	int islesConstraint=rmCreateClassDistanceConstraint("avoid isles", rmClassID("isles"), 10.0);
	int CliffIslandConstraint=rmCreateClassDistanceConstraint("avoid isles2", rmClassID("classCliffIsland"), 5.0);

	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minesalt", 75.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minesalt", 85.0);	// 85.0 seems the best for event minegold distribution.  This number tells minegolds how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random turkeys", "turkey", 50.0);	//Attempting to spread them out more evenly.
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 54.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 120.0);  //Added sheep 11-28-05 JSB

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 14.0);  //This one is used in one place: for helping place FFA TC's better.

	// Constraint to avoid water.
	int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);   //I added this one so I could experiment with it.
	int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 8.0);
	int avoidWater5 = rmCreateTerrainDistanceConstraint("avoid water long 5", "Land", false, 5.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);  //Added this one too.
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 18.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25); //Was 15, but made larger so ships don't sometimes stomp each other when arriving from HC.
	rmAddClosestPointConstraint(avoidWater8);  //was originally 8
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
	int avoidWaterTradeRoute = rmCreateClassDistanceConstraint("avoid water socket", rmClassID("classWaterTradeRoute"), 10.0);
	int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("classSocket"), 15.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);

	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  (It excludes the west bay, where I do not want the flags.)
	int circleConstraint=rmCreatePieConstraint("semi-circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(50), rmDegreesToRadians(290));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

	int avoidCliffs=rmCreateClassDistanceConstraint("stuff vs. cliff", rmClassID("classCliff"), 14.0);
	int cliffsAvoidCliffs=rmCreateClassDistanceConstraint("cliffs vs. cliffs", rmClassID("classCliff"), 30.0);
  int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 60.0);
	int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 60.0);

		int avoidTradeRouteSockets=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 8.0);
	int avoidTradeRouteSocketsShort=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 8.0);
	int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other short", rmClassID("importantItem"), 8.0);
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route short", 2.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("short stay away from players", classPlayer, 5.0);
		int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);
		
	int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);




/////////////////////////////// THE CENTER ////////////////////////////////////

	// Create a center area.
   int centerID=rmCreateArea("center");
   rmSetAreaSize(centerID, 0.05, 0.05);
   rmSetAreaLocation(centerID, 0.4, 0.4);
   rmAddAreaToClass(centerID, rmClassID("center"));
   rmBuildArea(centerID);

/////////////////////////////// DEFINE PLAYERS ////////////////////////////////////
   
	int verylongPlayerConstraint=rmCreateClassDistanceConstraint("very long stay away from players", classPlayer, 75.0);
	   int avoidStartingUnits = rmCreateClassDistanceConstraint("Avoid starting units", classStartingUnits, 10.0);
	   
	int TCID = rmCreateObjectDef("player TC");
	if ( rmGetNomadStart())
		rmAddObjectDefItem(TCID, "coveredWagon", 1, 0);
	else
		rmAddObjectDefItem(TCID, "townCenter", 1, 0);
    
	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, 3);
	rmAddObjectDefToClass(TCID, classPlayer);
	rmAddObjectDefConstraint(TCID, avoidImpassableLand);
	rmAddObjectDefConstraint(TCID, verylongPlayerConstraint);
	rmAddObjectDefConstraint(TCID, nearWater10);
	rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, shortAvoidTradeRoute);	   
	
	
	   
/////////////////////////////// DEFINE STARTING OBJECTS ////////////////////////////////////



  int food1ID=rmCreateObjectDef("huntable1");
	rmAddObjectDefItem(food1ID, huntable1, rmRandInt(8,10), 6.0);
	rmSetObjectDefCreateHerd(food1ID, true);
	rmSetObjectDefMinDistance(food1ID, 0.0);
	rmSetObjectDefMaxDistance(food1ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food1ID, avoidResource);
	rmAddObjectDefConstraint(food1ID, playerConstraint);
	rmAddObjectDefConstraint(food1ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food1ID, avoidHuntable1);
	rmAddObjectDefConstraint(food1ID, avoidHuntable2);
	rmAddObjectDefConstraint(food1ID, avoidTradeRouteSocketsShort);
  
  int food2ID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(food2ID, huntable2, rmRandInt(6,10), 6.0);
	rmSetObjectDefCreateHerd(food2ID, true);
	rmSetObjectDefMinDistance(food2ID, 0.0);
	rmSetObjectDefMaxDistance(food2ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food2ID, avoidResource);
	rmAddObjectDefConstraint(food2ID, playerConstraint);
	rmAddObjectDefConstraint(food2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food2ID, avoidHuntable1);
	rmAddObjectDefConstraint(food2ID, avoidHuntable2);
	rmAddObjectDefConstraint(food2ID, avoidTradeRouteSocketsShort);
  
  int startFoodID=rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(startFoodID, huntable2, 6, 4.0);
	rmSetObjectDefMinDistance(startFoodID, 12.0);
	rmSetObjectDefMaxDistance(startFoodID, 18.0);
	rmSetObjectDefCreateHerd(startFoodID, false);
	rmAddObjectDefConstraint(startFoodID, avoidAll);
	rmAddObjectDefConstraint(startFoodID, avoidStartResource);
	rmAddObjectDefConstraint(startFoodID, avoidHuntable1);    
	rmAddObjectDefConstraint(startFoodID, avoidHuntable2);    
  rmAddObjectDefConstraint(startFoodID, avoidTradeRoute);
  
  int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 10, 6.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 16);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 22);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartResource);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRouteSocketsShort);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRoute);

	int StartBerriesID=rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(StartBerriesID, "GrapeBush", 4, 5.0);
	rmSetObjectDefMinDistance(StartBerriesID, 10);
	rmSetObjectDefMaxDistance(StartBerriesID, 15);
	rmAddObjectDefConstraint(StartBerriesID, avoidAll);
	rmAddObjectDefConstraint(StartBerriesID, avoidStartResource);
	rmAddObjectDefConstraint(StartBerriesID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(StartBerriesID, shortPlayerConstraint);
  rmAddObjectDefConstraint(StartBerriesID, avoidTradeRoute);

  int startSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(startSilverID, "mine", 1, 0);
	rmSetObjectDefMinDistance(startSilverID, 18.0);
	rmSetObjectDefMaxDistance(startSilverID, 23.0);
	rmAddObjectDefConstraint(startSilverID, avoidAll);
	rmAddObjectDefConstraint(startSilverID, avoidImpassableLand);
  rmAddObjectDefConstraint(startSilverID, avoidTradeRoute);
  
  int playerNuggetID=rmCreateObjectDef("player nugget");
  rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
  rmSetObjectDefMinDistance(playerNuggetID, 15.0);
  rmSetObjectDefMaxDistance(playerNuggetID, 20.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);
  rmAddObjectDefConstraint(playerNuggetID, avoidTradeRoute);

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 5.0);
  rmSetObjectDefMaxDistance(startingUnits, 10.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);
  rmAddObjectDefConstraint(startingUnits, avoidTradeRoute);
  
  

/////////////////////////////// BIG ISLANDS ////////////////////////////////////

	// Bonus area constraint.  
	int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 30.0);
	int islandConstraint2=rmCreateClassDistanceConstraint("islands avoid each other 2", classIsland, 10.0);
	int islandConstraintSmall=rmCreateClassDistanceConstraint("islands avoid each other 3", classIslandSmall, 10.0);
	int islandConstraintSocket=rmCreateClassDistanceConstraint(" Socket islands avoided", classIslandSocket, 5.0);
	
	int IslandLoc = 1;								

		
		
	// Make CRETE

	int CreteID=rmCreateArea("Crete");
	rmSetAreaSize(CreteID, 0.06, 0.06);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(CreteID, 0.65);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(CreteID, 2.0);
	rmSetAreaSmoothDistance(CreteID, 10);
	rmSetAreaMix(CreteID, "verdondirt");
	rmAddAreaToClass(CreteID, classIsland);
	rmAddAreaToClass(CreteID, classCrete);
	rmAddAreaConstraint(CreteID, islandConstraint);
	rmAddAreaConstraint(CreteID, islandConstraintSmall);
	rmAddAreaConstraint(CreteID, avoidTradeRoute);
	rmAddAreaConstraint(CreteID, continentConstraint);
	rmSetAreaObeyWorldCircleConstraint(CreteID, false);
	rmSetAreaElevationType(CreteID, cElevTurbulence);
	rmSetAreaElevationVariation(CreteID, 5.0);
	rmSetAreaElevationMinFrequency(CreteID, 0.09);
	rmSetAreaElevationOctaves(CreteID, 3);
	rmSetAreaElevationPersistence(CreteID, 0.2);
	rmSetAreaElevationNoiseBias(CreteID, 1);
	rmAddAreaInfluenceSegment(CreteID, 0.15, 0.35, 0.35, 0.15);  

	rmSetAreaWarnFailure(CreteID, false);

	// Make CONTINENT

	int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), size/5);

	int ContinentID=rmCreateArea("Continent");
	rmSetAreaSize(ContinentID, 0.15, 0.15);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(ContinentID, 0.25);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(ContinentID, 5.0);
	rmSetAreaSmoothDistance(ContinentID, 20);
	  rmSetAreaMinBlobs(ContinentID, 30);
      rmSetAreaMaxBlobs(ContinentID, 45);
      rmSetAreaMinBlobDistance(ContinentID, 20.0);
      rmSetAreaMaxBlobDistance(ContinentID, 40.0);
	rmSetAreaMix(ContinentID, "verdongrass");
	rmAddAreaToClass(ContinentID, classIsland);
	rmAddAreaToClass(ContinentID, continent);
	rmAddAreaConstraint(ContinentID, islandConstraint);
//	rmAddAreaConstraint(ContinentID, centerConstraintFar);
	rmAddAreaConstraint(ContinentID, islandConstraintSmall);
	rmAddAreaConstraint(ContinentID, avoidTradeRoute);
	rmSetAreaObeyWorldCircleConstraint(ContinentID, false);
	rmSetAreaElevationType(ContinentID, cElevTurbulence);
	rmSetAreaElevationVariation(ContinentID, 4.0);
	rmSetAreaElevationMinFrequency(ContinentID, 0.09);
	rmSetAreaElevationOctaves(ContinentID, 3);
	rmSetAreaElevationPersistence(ContinentID, 0.2);
	rmSetAreaElevationNoiseBias(ContinentID, 1);
	   rmSetAreaEdgeFilling(ContinentID, 5);
//	rmAddAreaInfluenceSegment(ContinentID, 0.5, 0.9, 0.9, 0.5); 
//	rmAddAreaInfluenceSegment(ContinentID, 0.9, 0.5, 1, 1); 
//	rmAddAreaInfluenceSegment(ContinentID, 1, 1, 0.5, 0.9); 

	rmSetAreaWarnFailure(ContinentID, false);


	if (IslandLoc == 1)

	rmSetAreaLocation(CreteID, .25, .25);		
	rmBuildArea(CreteID);
	rmSetAreaLocation(ContinentID, 0.5, 1);		
	rmBuildArea(ContinentID);


/////////////////////////////// PLACE WATER TRADE ROUTE ////////////////////////////////////


   int watersocketID=rmCreateObjectDef("sockets to dock Water Posts");
	rmAddObjectDefItem(watersocketID, "SocketTradeRoute", 1, 0.0);
		rmAddObjectDefItem(watersocketID, "classSocket", 1, 0.0);
	rmSetObjectDefAllowOverlap(watersocketID, true);
	rmSetObjectDefMinDistance(watersocketID, 0.0);
	rmSetObjectDefMaxDistance(watersocketID, 6.0);


	int watertradeRouteID = rmCreateTradeRoute();
	rmAddObjectDefToClass(watertradeRouteID, rmClassID("classWaterTradeRoute"));

	rmSetObjectDefTradeRouteID(watersocketID, watertradeRouteID);

	rmAddTradeRouteWaypoint(watertradeRouteID, 0, .7);
	rmAddTradeRouteWaypoint(watertradeRouteID, .2, .55);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.45, .4);
	rmAddTradeRouteWaypoint(watertradeRouteID, .6, .25);
	rmAddTradeRouteWaypoint(watertradeRouteID, .8, .3);
	rmAddTradeRouteWaypoint(watertradeRouteID, .85, .55);
	rmAddTradeRouteWaypoint(watertradeRouteID, 1.0, .6);

	bool placedTradeRouteB = rmBuildTradeRoute(watertradeRouteID, "WATERdirt");
	if(placedTradeRouteB == false)
		rmEchoError("Failed to place trade route 2");
	
	
/////////////////////////////// PLACE WATER TRADE ROUTE VARIABLE ISLANDS ////////////////////////////////////

	int TRisland1=rmCreateArea("TRroute1");
	rmSetAreaSize(TRisland1, 0.006, 0.006);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(TRisland1, 0.65);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(TRisland1, 1.0);
	rmSetAreaSmoothDistance(TRisland1, 10);
	rmSetAreaMix(TRisland1, "verdongrass");
	rmAddAreaToClass(TRisland1, classIsland);
	rmAddAreaConstraint(TRisland1, islandConstraint);
	rmAddAreaConstraint(TRisland1, islandConstraintSmall);
	rmAddAreaConstraint(TRisland1, shortAvoidTradeRoute);
	rmAddAreaConstraint(TRisland1, continentConstraint);
	rmAddAreaToClass(TRisland1, classIslandSocket);
	rmSetAreaObeyWorldCircleConstraint(TRisland1, false);
	rmSetAreaElevationType(TRisland1, cElevTurbulence);
	rmSetAreaElevationVariation(TRisland1, 2.0);
	rmSetAreaElevationMinFrequency(TRisland1, 0.09);
	rmSetAreaElevationOctaves(TRisland1, 3);
	rmSetAreaElevationPersistence(TRisland1, 0.2);
	rmSetAreaElevationNoiseBias(TRisland1, 1); 
	rmSetAreaWarnFailure(TRisland1, false);
	
		int TRisland2=rmCreateArea("TRroute2");
	rmSetAreaSize(TRisland2, 0.005, 0.005);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(TRisland2, 0.65);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(TRisland2, 1.0);
	rmSetAreaSmoothDistance(TRisland2, 10);
	rmSetAreaMix(TRisland2, "verdongrass");
	rmAddAreaToClass(TRisland2, classIsland);
	rmAddAreaConstraint(TRisland2, islandConstraint);
		rmAddAreaToClass(TRisland2, classIslandSocket);
	rmAddAreaConstraint(TRisland2, islandConstraintSmall);
	rmAddAreaConstraint(TRisland2, shortAvoidTradeRoute);
	rmAddAreaConstraint(TRisland2, continentConstraint);
	rmSetAreaObeyWorldCircleConstraint(TRisland2, false);
	rmSetAreaElevationType(TRisland2, cElevTurbulence);
	rmSetAreaElevationVariation(TRisland2, 2.0);
	rmSetAreaElevationMinFrequency(TRisland2, 0.09);
	rmSetAreaElevationOctaves(TRisland2, 3);
	rmSetAreaElevationPersistence(TRisland2, 0.2);
	rmSetAreaElevationNoiseBias(TRisland2, 1); 
	rmSetAreaWarnFailure(TRisland2, false);
	
		int TRisland3=rmCreateArea("TRroute3");
	rmSetAreaSize(TRisland3, 0.005, 0.005);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(TRisland3, 0.65);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(TRisland3, 1.0);
	rmSetAreaSmoothDistance(TRisland3, 10);
	rmSetAreaMix(TRisland3, "verdongrass");
	rmAddAreaToClass(TRisland3, classIsland);
	rmAddAreaToClass(TRisland3, classIslandSocket);
	rmAddAreaConstraint(TRisland3, islandConstraint);
	rmAddAreaConstraint(TRisland3, islandConstraintSmall);
	rmAddAreaConstraint(TRisland3, shortAvoidTradeRoute);
	rmAddAreaConstraint(TRisland3, continentConstraint);
	rmSetAreaObeyWorldCircleConstraint(TRisland3, false);
	rmSetAreaElevationType(TRisland3, cElevTurbulence);
	rmSetAreaElevationVariation(TRisland3, 2.0);
	rmSetAreaElevationMinFrequency(TRisland3, 0.09);
	rmSetAreaElevationOctaves(TRisland3, 3);
	rmSetAreaElevationPersistence(TRisland3, 0.2);
	rmSetAreaElevationNoiseBias(TRisland3, 1); 
	rmSetAreaWarnFailure(TRisland3, false);
	
		int TRisland4=rmCreateArea("TRroute4");
	rmSetAreaSize(TRisland4, 0.005, 0.005);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(TRisland4, 0.65);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(TRisland4, 1.0);
	rmSetAreaSmoothDistance(TRisland4, 10);
	rmSetAreaMix(TRisland4, "verdongrass");
	rmAddAreaToClass(TRisland4, classIsland);
		rmAddAreaToClass(TRisland4, classIslandSocket);
	rmAddAreaConstraint(TRisland4, islandConstraint);
	rmAddAreaConstraint(TRisland4, islandConstraintSmall);
	rmAddAreaConstraint(TRisland4, shortAvoidTradeRoute);
	rmAddAreaConstraint(TRisland4, continentConstraint);
	rmSetAreaObeyWorldCircleConstraint(TRisland4, false);
	rmSetAreaElevationType(TRisland4, cElevTurbulence);
	rmSetAreaElevationVariation(TRisland4, 2.0);
	rmSetAreaElevationMinFrequency(TRisland4, 0.09);
	rmSetAreaElevationOctaves(TRisland4, 3);
	rmSetAreaElevationPersistence(TRisland4, 0.2);
	rmSetAreaElevationNoiseBias(TRisland4, 1); 
	rmSetAreaWarnFailure(TRisland4, false);
	
		int TRisland5=rmCreateArea("TRroute5");
	rmSetAreaSize(TRisland5, 0.005, 0.005);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(TRisland5, 0.65);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(TRisland5, 1.0);
	rmSetAreaSmoothDistance(TRisland5, 10);
	rmSetAreaMix(TRisland5, "verdongrass");
	rmAddAreaToClass(TRisland5, classIsland);
		rmAddAreaToClass(TRisland5, classIslandSocket);
	rmAddAreaConstraint(TRisland5, islandConstraint);
	rmAddAreaConstraint(TRisland5, islandConstraintSmall);
	rmAddAreaConstraint(TRisland5, shortAvoidTradeRoute);
	rmAddAreaConstraint(TRisland5, continentConstraint);
	rmSetAreaObeyWorldCircleConstraint(TRisland5, false);
	rmSetAreaElevationType(TRisland5, cElevTurbulence);
	rmSetAreaElevationVariation(TRisland5, 2.0);
	rmSetAreaElevationMinFrequency(TRisland5, 0.09);
	rmSetAreaElevationOctaves(TRisland5, 3);
	rmSetAreaElevationPersistence(TRisland5, 0.2);
	rmSetAreaElevationNoiseBias(TRisland5, 1); 
	rmSetAreaWarnFailure(TRisland5, false);
	
	rmSetAreaLocation(TRisland1, .25, .55);
	rmSetAreaLocation(TRisland2, 0.45, .45);
	rmSetAreaLocation(TRisland3, .57, .27);
	rmSetAreaLocation(TRisland4, .8, .27);
	rmSetAreaLocation(TRisland5, .82, .55);
		
		
	//////// TR RANDOMIZER //////////
	
	int SocketIslandRandomizer = (rmRandInt(1,3));
	
	   if ( cNumberNonGaiaPlayers <5)
	   {
			if (SocketIslandRandomizer ==1)
				   {
						rmBuildArea(TRisland1);
						rmBuildArea(TRisland2);	
						rmBuildArea(TRisland4);
						rmPlaceObjectDefAtLoc(watersocketID, 0, .25, .55);
						rmPlaceObjectDefAtLoc(watersocketID, 0, 0.45, .45);
						rmPlaceObjectDefAtLoc(watersocketID, 0, .8, .27);
				   }
			else if (SocketIslandRandomizer ==2)
				   {
						rmBuildArea(TRisland2);	
						rmBuildArea(TRisland4);
						rmBuildArea(TRisland5);	
						rmPlaceObjectDefAtLoc(watersocketID, 0, 0.45, .45);
						rmPlaceObjectDefAtLoc(watersocketID, 0, .8, .27);
						rmPlaceObjectDefAtLoc(watersocketID, 0, .82, .55);
				   }   
			else if (SocketIslandRandomizer ==3)
				   {
						rmBuildArea(TRisland1);
						rmBuildArea(TRisland3);	
						rmBuildArea(TRisland5);	
						rmPlaceObjectDefAtLoc(watersocketID, 0, .25, .55);
						rmPlaceObjectDefAtLoc(watersocketID, 0, .57, .27);
						rmPlaceObjectDefAtLoc(watersocketID, 0, .82, .55);
				   }  
	   }
	   else
	   {
		rmBuildArea(TRisland1);
		rmBuildArea(TRisland2);	
		rmBuildArea(TRisland3);	
		rmBuildArea(TRisland4);
		rmBuildArea(TRisland5);	
	
		rmPlaceObjectDefAtLoc(watersocketID, 0, .25, .55);
		rmPlaceObjectDefAtLoc(watersocketID, 0, 0.45, .45);
		rmPlaceObjectDefAtLoc(watersocketID, 0, .57, .27);
		rmPlaceObjectDefAtLoc(watersocketID, 0, .8, .27);
		rmPlaceObjectDefAtLoc(watersocketID, 0, .82, .55);
	   }		
		



 /////////////////////////////// ISLANDS ////////////////////////////////////


	// Islands
   int numIslands=cNumberNonGaiaPlayers*1.5;
   if (cNumberNonGaiaPlayers<7)
	numIslands=10;
   for(i=0; <numIslands)
   {
      // Create the area.
      int islandID=rmCreateArea("island "+i);
 //     rmSetAreaSize(islandID, 0.1/numIslands, 0.1/numIslands);
      rmSetAreaSize(islandID, 0.01,0.01);	  
      rmSetAreaMinBlobs(islandID, 3);
      rmSetAreaMaxBlobs(islandID, 5);
      rmSetAreaMinBlobDistance(islandID, 20.0);
      rmSetAreaMaxBlobDistance(islandID, 40.0);
      rmSetAreaCoherence(islandID, 0.35);
      rmSetAreaBaseHeight(islandID, 2.0);
      rmSetAreaSmoothDistance(islandID, 20);
      rmSetAreaMix(islandID, "verdondirt");
      rmAddAreaToClass(islandID, classIsland);
	        rmAddAreaToClass(islandID, classIslandSmall);
		rmAddAreaConstraint(islandID, avoidTradeRoute);
      rmAddAreaConstraint(islandID, islandConstraint);
	  		rmAddAreaConstraint(islandID, avoidSocket);
      rmAddAreaConstraint(islandID, playerEdgeConstraint);
      rmSetAreaElevationType(islandID, cElevTurbulence);
      rmSetAreaElevationVariation(islandID, 3.0);
      rmSetAreaElevationMinFrequency(islandID, 0.09);
      rmSetAreaElevationOctaves(islandID, 3);
      rmSetAreaElevationPersistence(islandID, 0.2);
      rmSetAreaElevationNoiseBias(islandID, 1);
      rmSetAreaWarnFailure(islandID, false);
      rmEchoInfo("Island area"+i);
      int fail=0;
      for (j=2; >fail*1000) // Make sure island gets made somewhere
	{fail=rmBuildArea(islandID);}
   }


	
	/////////////////////////////// PLACE PLAYERS, HOLY MOTHER OF GOD. ////////////////////////////////////
	
    // Picks which Team is on Crete, Team 0 or Team 1
    // The variable will just be ignored if there's more teams
    int CretianTeam = rmRandInt(0,1); 

    for(i=1; <cNumberPlayers) {
        
        // Place TCs
        if (cNumberTeams > 2) {
            // More than 2 teams, place on an island
            fail=0;
            for(j=5; >fail*1000){// Make sure the TC gets added somewhere. Tries more times, in case multiple players roll the same randInt
                fail=rmPlaceObjectDefInArea(TCID, i, rmAreaID("island "+rmRandInt(0, numIslands)), 1);
            }

        } else{

            if (rmGetPlayerTeam(i) == CretianTeam) {
                // Player i is on Crete's team
                fail=0;
                for(j=2; >fail*1000){ // Make sure the TC gets added somewhere
                    fail=rmPlaceObjectDefInArea(TCID, i, rmAreaID("Crete"), 1);
                }

            } else {
                // Player i is on Continent's team
                fail=0;
                for(j=2; >fail*1000){ // Make sure the TC gets added somewhere
                    fail=rmPlaceObjectDefInArea(TCID, i, rmAreaID("Continent"), 1);
                }
            }
        }

        // Place starting objects
        vector TCLocation=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
        rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
        rmPlaceObjectDefAtLoc(startSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
        rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
        rmPlaceObjectDefAtLoc(StartBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
        rmPlaceObjectDefAtLoc(startFoodID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));                            
        rmSetNuggetDifficulty(21, 21);
        rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
        
        // Place water spawn points for the players
        rmClearClosestPointConstraints();
        int waterSpawnPointID=rmCreateObjectDef("WaterSpawnFlag "+i);
        rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 10.0);
        rmAddClosestPointConstraint(flagVsFlag);
        rmAddClosestPointConstraint(flagLand);
        rmAddClosestPointConstraint(flagEdgeConstraint);
        vector closestPoint = rmFindClosestPointVector(TCLocation, rmXFractionToMeters(1.0));
        rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
    }

  /////////////////////////////// MINES ////////////////////////////////////

	int avoidSilver=rmCreateTypeDistanceConstraint("avoid coal mines", "minesalt", 60.0);
		int avoidSilverShort=rmCreateTypeDistanceConstraint("avoid coal mines short", "minesalt", 10.0);
	
	// Silver

	int silverID = -1;
 	int silverID2 = -1;

  int silverCount = 0;
  
  silverCount = cNumberNonGaiaPlayers*2;
  
	rmEchoInfo("silver count = "+silverCount);


  // silver mines over the entirety of the island
  silverID2 = rmCreateObjectDef("closer silver mines"+i);
  rmAddObjectDefItem(silverID2, "minesalt", 1, 0.0);
  rmSetObjectDefMinDistance(silverID2, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(silverID2, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(silverID2, avoidImpassableLand);
  rmAddObjectDefConstraint(silverID2, avoidSilver);
  rmAddObjectDefConstraint(silverID2, longPlayerConstraint);
  rmAddObjectDefConstraint(silverID2, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(silverID2, shortAvoidImportantItem);
  rmAddObjectDefConstraint(silverID2, avoidTradeRouteSocketsShort);
  rmPlaceObjectDefAtLoc(silverID2, 0, 0.5, 0.5, silverCount);


  
  
    /////////////////////////////// TREASURES ////////////////////////////////////

  int playerConstraintNugget=rmCreateClassDistanceConstraint("stay away from players far", classPlayer, 55.0);
  int avoidNuggetsShort=rmCreateTypeDistanceConstraint("vs nugget short", "AbstractNugget", 10.0);
    int avoidNuggets=rmCreateTypeDistanceConstraint("nugget vs. nugget", "AbstractNugget", 40.0);
	int avoidNuggetFar=rmCreateTypeDistanceConstraint("nugget vs. nugget far", "AbstractNugget", 70.0);
	
  int nugget4= rmCreateObjectDef("nugget nuts"); 
  rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(24, 24);
  rmSetObjectDefMinDistance(nugget4, 0.0);
  rmSetObjectDefMaxDistance(nugget4, rmXFractionToMeters(0.2));
  rmAddObjectDefConstraint(nugget4, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget4, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget4, avoidResource);
  rmAddObjectDefConstraint(nugget4, avoidNuggets);
  rmAddObjectDefConstraint(nugget4, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget4, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget4, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget4, circleConstraint);
  rmPlaceObjectDefAtLoc(nugget4, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

  int nugget3= rmCreateObjectDef("nugget hard"); 
  rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(23, 23);
  rmSetObjectDefMinDistance(nugget3, 0.0);
  rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.2));
  rmAddObjectDefConstraint(nugget3, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget3, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget3, avoidResource);
  rmAddObjectDefConstraint(nugget3, avoidNuggets);
  rmAddObjectDefConstraint(nugget3, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget3, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget3, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget3, circleConstraint);
  rmPlaceObjectDefAtLoc(nugget3, 0, 0.5, 0.5, cNumberNonGaiaPlayers+rmRandInt(1,1));

  int nugget2= rmCreateObjectDef("nugget medium"); 
  rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(22, 22);
  rmAddObjectDefConstraint(nugget2, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget2, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget2, avoidResource);
  rmAddObjectDefConstraint(nugget2, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget2, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget2, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget2, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget2, circleConstraint);
  rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.25));
  rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.3));
  rmPlaceObjectDefAtLoc(nugget2, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

  int nugget1= rmCreateObjectDef("nugget easy"); 
  rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(21, 21);
  rmAddObjectDefConstraint(nugget1, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget1, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget1, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget1, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget1, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget1, playerConstraint);
  rmAddObjectDefConstraint(nugget1, circleConstraint);
  rmSetObjectDefMinDistance(nugget1, rmXFractionToMeters(0.3));
  rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.4));
  rmPlaceObjectDefAtLoc(nugget1, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);


    int nuggetSea= rmCreateObjectDef("nugget sea"); 
  rmAddObjectDefItem(nuggetSea, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(25, 25);
  rmSetObjectDefMinDistance(nuggetSea, rmXFractionToMeters(0.3));
  rmAddObjectDefConstraint(nuggetSea, fishLand);
  rmSetObjectDefMaxDistance(nuggetSea, rmXFractionToMeters(0.4));
  rmPlaceObjectDefAtLoc(nuggetSea, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);


   
   	/////////////////////////////// CONTINENT CLIFFS ////////////////////////////////////
	

	
		// Define and place cliffs
	numTries=cNumberNonGaiaPlayers*4;
	failCount=0;
	for(i=0; <numTries)
	{
		int cliffContinentID=rmCreateArea("cliff continent"+i);
	   rmSetAreaSize(cliffContinentID, rmAreaTilesToFraction(350), rmAreaTilesToFraction(400));  // DAL - larger cliffs?
		rmSetAreaWarnFailure(cliffContinentID, false);
		rmSetAreaCliffType(cliffContinentID, "Verdon Gorge Grass");
		rmAddAreaToClass(cliffContinentID, rmClassID("classCliff"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(cliffContinentID, 2, 0.4, 0.1, 1.0, 0);
		rmSetAreaCliffPainting(cliffContinentID, true, true, true, 1.5, true);
		rmSetAreaCliffHeight(cliffContinentID, 7, 1.0, 1.0);
		rmSetAreaHeightBlend(cliffContinentID, 1);
		rmAddAreaTerrainLayer(cliffContinentID, "texas\ground2_tex", 0, 2);
		rmAddAreaConstraint(cliffContinentID, islandConstraintSmall);
		rmAddAreaConstraint(cliffContinentID, avoidWater8);
		rmAddAreaConstraint(cliffContinentID, CliffIslandConstraint);
		rmSetAreaObeyWorldCircleConstraint(cliffContinentID, false);
		rmAddAreaConstraint(cliffContinentID, cliffsAvoidCliffs);				// Avoid cliffs, please!
		rmAddAreaConstraint(cliffContinentID, playerConstraint);		// Keep cliffs away from the player.
		rmAddAreaConstraint(cliffContinentID, avoidImportantItem);
		  	    rmAddAreaConstraint(cliffContinentID, avoidSilverShort);
		rmAddAreaConstraint(cliffContinentID, avoidSocket);		
		rmSetAreaMinBlobs(cliffContinentID, 2);
		rmSetAreaMaxBlobs(cliffContinentID, 4);
		rmSetAreaMinBlobDistance(cliffContinentID, 10.0);
		rmSetAreaMaxBlobDistance(cliffContinentID, 20.0);
		rmSetAreaCoherence(cliffContinentID, 0.2);
		rmSetAreaSmoothDistance(cliffContinentID, 30);						// DAL - used to be 10
		rmSetAreaCoherence(cliffContinentID, 0.25);

		if(rmBuildArea(cliffContinentID)==false)
		{
			// Stop trying once we fail 3 times in a row
			failCount++;
			if(failCount==3)
				break;
		}
		else
			failCount=0;
	}
 	

	

	// Cliffs

   int numCliffIslands=cNumberNonGaiaPlayers*3;
   
   for(i=0; <numCliffIslands)
   {
		int smallCliffHeight=rmRandInt(0,10);
		int CliffIsland=rmCreateArea("cliffisland "+i);
    		  rmSetAreaSize(CliffIsland, 0.09/numCliffIslands, 0.09/numCliffIslands);
		rmSetAreaWarnFailure(CliffIsland, false);
		rmSetAreaCliffType(CliffIsland, "Verdon Gorge Grass");
		rmAddAreaToClass(CliffIsland, classCliffIsland);	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(CliffIsland, 2, 0.9, 0.9, 1.0, 0);
		rmSetAreaCliffHeight(CliffIsland, rmRandInt(6, 8), 3.0, 4.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(CliffIsland, 0.90);
		      rmSetAreaMinBlobs(CliffIsland, 3);
      rmSetAreaMaxBlobs(CliffIsland, 20);
      rmSetAreaMinBlobDistance(CliffIsland, 10.0);
      rmSetAreaMaxBlobDistance(CliffIsland, 30.0);
		rmSetAreaHeightBlend(CliffIsland, 0);
  	    rmAddAreaConstraint(CliffIsland, creteConstraint);
		  	    rmAddAreaConstraint(CliffIsland, avoidSilverShort);
  	    rmAddAreaConstraint(CliffIsland, CliffIslandConstraint);
		rmAddAreaConstraint(CliffIsland, avoidSocket);
				rmAddAreaConstraint(CliffIsland, islandConstraintSocket);
  	    rmAddAreaConstraint(CliffIsland, continentConstraint);
		rmAddAreaConstraint(CliffIsland, avoidTradeRoute);	
				rmAddAreaConstraint(CliffIsland, playerConstraint);
		rmBuildArea(CliffIsland);
      int fail2=0;
      for (j=2; >fail2*1000) // Make sure island gets made somewhere
	{fail=rmBuildArea(CliffIsland);}
   }

 


  
  /////////////////////////////// FORESTS ////////////////////////////////////

	// Scattered FORESTS
   int forestTreeID = 0;
   numTries=6*cNumberNonGaiaPlayers;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest, "Verdon forest");
         rmSetAreaForestDensity(forest, 0.3);
         rmSetAreaForestClumpiness(forest, 0.4);
         rmSetAreaForestUnderbrush(forest, 0.0);
         rmSetAreaMinBlobs(forest, 1);
         rmSetAreaMaxBlobs(forest, 5);
         rmSetAreaMinBlobDistance(forest, 16.0);
         rmSetAreaMaxBlobDistance(forest, 40.0);
         rmSetAreaCoherence(forest, 0.4);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
         rmAddAreaConstraint(forest, forestConstraint);
         rmAddAreaConstraint(forest, avoidAll);
         rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(forest, avoidTC);
		 rmAddAreaConstraint(forest, avoidCW);
         rmAddAreaConstraint(forest, avoidTradeRoute); 
         if(rmBuildArea(forest)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount++;
            if(failCount==5)
               break;
         }
         else
            failCount=0; 
      } 
	  
	  /////////////////////////////// HUNTABLES ////////////////////////////////////

  rmPlaceObjectDefAtLoc(food1ID, 0, 0.5, 0.5, 1.5*cNumberNonGaiaPlayers);
  rmPlaceObjectDefAtLoc(food2ID, 0, 0.5, 0.5, 2.0*cNumberNonGaiaPlayers);

  
		
			///////////////////////////////  FISH ////////////////////////////////////
		
		
			int fishVsFish2ID=rmCreateTypeDistanceConstraint("fish v fish2", fish2, 15.0); 

  int fishID=rmCreateObjectDef("fish 1");
  rmAddObjectDefItem(fishID, fish1, 1, 0.0);
  rmSetObjectDefMinDistance(fishID, 0.0);
  rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(fishID, fishVsFishID);
  rmAddObjectDefConstraint(fishID, fishLand);
  rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);
    
  int fish2ID=rmCreateObjectDef("fish 2");
  rmAddObjectDefItem(fish2ID, fish2, 1, 0.0);
  rmSetObjectDefMinDistance(fish2ID, 0.0);
  rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(fish2ID, fishVsFish2ID);
  rmAddObjectDefConstraint(fish2ID, fishVsFishID);
  rmAddObjectDefConstraint(fish2ID, fishLand);
  rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);

  // King of the Hill (added 2026-11 for WoL): the land farthest from every Town Center among the peninsulas
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
    // try, with the include's placer constraints (and 40 m from every Town Center)
    int kothAvoidLand = rmCreateTerrainDistanceConstraint("koth hill avoids impassable land", "Land", false, 6.0);
    int kothAvoidAll = rmCreateTypeDistanceConstraint("koth hill avoids all", "all", 4.0);
    int kothAvoidTC = rmCreateTypeDistanceConstraint("koth hill avoids TCs", "TownCenter", 40.0);
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






