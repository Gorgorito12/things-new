// Alps

include "mercenaries.xs";
include "triggers\triggerLoader.xs";
//include "GWevent.xs";
//include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.10);

	// Define Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;

    if (rmAllocateSubCivs(3) == true)
    {
		subCiv0=rmGetCivID("LoggingCamp");
		rmEchoInfo("subCiv0 is LoggingCamp "+subCiv0);
		if (subCiv0 >= 0)
		rmSetSubCiv(0, "LoggingCamp");

		subCiv1=rmGetCivID("FurTrapper");
		rmEchoInfo("subCiv1 is FurTrapper "+subCiv1);
		if (subCiv1 >= 0)
		rmSetSubCiv(1, "FurTrapper");

		subCiv2=rmGetCivID("MiningCamp");
		rmEchoInfo("subCiv2 is MiningCamp "+subCiv2);
		if (subCiv2 >= 0)
		rmSetSubCiv(2, "MiningCamp");
	}

		// Randomizes the GAIA civ.

		
			//rmSetGaiaCiv(cCivFAKEalps1);
		
		
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	


	int whichVariation=-1;
	whichVariation = rmRandInt(1,3);
	// The line below can be uncommented to force the variation to the number indicated, for testing.
	// whichVariation = 3; 

	rmEchoInfo("Map Variation: "+whichVariation);
	
	chooseMercs();
	//gwevent();

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
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

    // Picks default terrain and water
	rmSetMapElevationParameters(cElevTurbulence, 0.02, 10, 0.2, -20.0);  //1-frequency of turb; 2-?  4-height
	rmSetBaseTerrainMix("rockies_grass_snowa");
	rmTerrainInitialize("yukon\ground1_yuk", 1);
	rmSetLightingSet("great lakes winter");
	rmSetMapType("rockies");
	rmSetMapType("land");
	rmSetWorldCircleConstraint(true);
	rmSetMapType("grass");
   rmSetSeaLevel(-1.0);
   
	// Misc variables for use later
	int numTries = -1;
	int numTries2 = -1;
   int failCount=0;
   
	// Misc variables for use later

  int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
  bool weird = false;

  // FFA and imbalanced teams
  if ( cNumberTeams > 2 || ((teamZeroCount - teamOneCount) > 2) || ((teamOneCount - teamZeroCount) > 2) )
    weird = true;
  
  rmEchoInfo("weird = "+weird);

	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
	rmDefineClass("classCenterForest");
	rmDefineClass("classForest");
	rmDefineClass("classMountain");
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("classSocket");
	rmDefineClass("canyon");

  string herdableType = "ypWaterBuffalo";
  string huntable1 = "deer";
  string huntable2 = "Elk";
  string huntable3 = "Rabbit";
  string fish1 = "FishCod";
  string fish2 = "ypFishTuna";
  string whale1 = "HumpbackWhale";
  string startTreeType = "TreeGreatPlains";

   // -------------Define constraints----------------------------------------

    // Create an edge of map constraint.
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Player area constraint.
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 25.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("long stay away from players", rmClassID("player"), 60.0);
	int hugePlayerConstraint=rmCreateClassDistanceConstraint("huge stay away from players", rmClassID("player"), 150.0);
	int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 20.0);
	int nearWater10 = rmCreateTerrainDistanceConstraint("near water", "Water", true, 10.0);
	int nearWaterDock = rmCreateTerrainDistanceConstraint("near water for Dock", "Water", true, 0.0);
	int avoidTC=rmCreateTypeDistanceConstraint("stay away from TC", "TownCenter", 26.0);    //Originally 20.0 -- This adjustment, as well as changing the rmSetObjectDefMaxDistance to 12.0, has corrected the problem of nomad sometimes not placing CW for each player.
	int avoidTP=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets", "SocketTradeRoute", 14.0);  // JSB 1-11-05 - Just added, to try to prevent things from stomping on TPs.
	int avoidCW=rmCreateTypeDistanceConstraint("stay away from CW", "CoveredWagon", 24.0);
	int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);



	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fishMahi", 25.0);			// was 50.0
	// int fishVsFishTarponID=rmCreateTypeDistanceConstraint("fish v fish2", "fishTarpon", 20.0);  // was 40.0 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 2.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "HumpbackWhale", 40.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 17.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 10.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int avoidCoin=-1;




	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minegold", 75.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minegold", 85.0);	// 85.0 seems the best for event minegold distribution.  This number tells minegolds how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "GrapeBush", 50.0);	//Attempting to spread them out more evenly.
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
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);  //Added this one too.
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 18.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25); //Was 15, but made larger so ships don't sometimes stomp each other when arriving from HC.
	rmAddClosestPointConstraint(avoidWater8);  //was originally 8
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("short trade route", 3.0);
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 10.0);
	int avoidWaterTradeRoute = rmCreateClassDistanceConstraint("avoid WTR", rmClassID("classWaterTradeRoute"), 10.0);
	int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("classSocket"), 5.0);
	int avoidSocketfar = rmCreateClassDistanceConstraint("avoid socket far", rmClassID("classSocket"), 15.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);
	int avoidRiver = rmCreateTerrainDistanceConstraint("avoid river", "Land", false, 5.0);
	int avoidRiverFar = rmCreateTerrainDistanceConstraint("avoid river far", "Land", false, 35.0);
	
	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  (It excludes the west bay, where I do not want the flags.)
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

	// int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);
	int mountainvsmountain = rmCreateClassDistanceConstraint("mountain vs mountain", rmClassID("classMountain"), 10.0);	
	int avoidmountain = rmCreateClassDistanceConstraint("all vs mountain", rmClassID("classMountain"), 5.0);
  int playerConstraintNugget=rmCreateClassDistanceConstraint("stay away from players far", classPlayer, 55.0);
  int avoidNuggetsShort=rmCreateTypeDistanceConstraint("vs nugget short", "AbstractNugget", 10.0);
  int avoidNuggets=rmCreateTypeDistanceConstraint("nugget vs. nugget", "AbstractNugget", 40.0);
	int avoidNuggetFar=rmCreateTypeDistanceConstraint("nugget vs. nugget far", "AbstractNugget", 70.0);
	int shortAvoidTradeRouteMines = rmCreateTradeRouteDistanceConstraint("trees and mines short trade route", 12.0);
  int avoidMines=rmCreateTypeDistanceConstraint("vs mines", "mine", 10.0);
  
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);

/////////////////////////////// MAP VARIATION ////////////////////////////////////
	
	int	MapVariation = rmRandInt(1,3);
	
	//1: river goes east.
	//2: river goest west.
	//3: river is vertical.

	
	/////////////////////////////// DEFINE AREA ////////////////////////////////////

	
   int AreaID = rmCreateArea("area");
   rmSetAreaWarnFailure(AreaID, false);
   rmSetAreaSize(AreaID, 1, 1);
   rmBuildArea(AreaID);
   
   
/////////////////////////////// BIG RIVER ////////////////////////////////////

	if (MapVariation == 1)  // RIVER STARTS NORTH, GOES EAST
	{	
	int bigriverID = rmRiverCreate(-1, "Yukon River", 10, 15, 10, 9);    //3: width
	rmRiverAddWaypoint(bigriverID, 1.0, 0.4+rmRandFloat(-0.1, 0.1));
	rmRiverAddWaypoint(bigriverID, 0.7, 0.4);
	rmRiverAddWaypoint(bigriverID, 0.4, 0.7);
	rmRiverAddWaypoint(bigriverID, 0.4+rmRandFloat(-0.1, 0.1), 1.0);	
	rmRiverSetBankNoiseParams(bigriverID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	
	int afluent1ID = rmRiverCreate(-1, "Yukon River", 20, 15, 5, 9);    //3: width
	rmRiverAddWaypoint(afluent1ID, 0.7, 0.4);
	rmRiverAddWaypoint(afluent1ID, 0.2+rmRandFloat(-0.1, 0.1), 0.0);
	rmRiverSetBankNoiseParams(afluent1ID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	
	int afluent2ID = rmRiverCreate(-1, "Yukon River", 5, 15, 5, 9);    //3: width
	rmRiverAddWaypoint(afluent2ID, 0.4, 0.7);
	rmRiverAddWaypoint(afluent2ID, 0.0, 1.0+rmRandFloat(-0.1, 0.0));
	rmRiverSetBankNoiseParams(afluent2ID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);	
	}
	if (MapVariation == 2)  // RIVER STARTS NORTH, GOES WEST
	{	
	bigriverID = rmRiverCreate(-1, "Yukon River", 10, 15, 10, 9);    //3: width
	rmRiverAddWaypoint(bigriverID, 1.0, 0.6+rmRandFloat(-0.1, 0.1));
	rmRiverAddWaypoint(bigriverID, 0.7, 0.7);
	rmRiverAddWaypoint(bigriverID, 0.4, 0.4);
	rmRiverAddWaypoint(bigriverID, 0.4+rmRandFloat(-0.1, 0.1), 0.0);	
	rmRiverSetBankNoiseParams(bigriverID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	
	afluent1ID = rmRiverCreate(-1, "Yukon River", 20, 15, 5, 9);    //3: width
	rmRiverAddWaypoint(afluent1ID, 0.7, 0.7);
	rmRiverAddWaypoint(afluent1ID, 0.2+rmRandFloat(-0.1, 0.1), 1.0);
	rmRiverSetBankNoiseParams(afluent1ID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	
	afluent2ID = rmRiverCreate(-1, "Yukon River", 5, 15, 5, 9);    //3: width
	rmRiverAddWaypoint(afluent2ID, 0.4, 0.4);
	rmRiverAddWaypoint(afluent2ID, 0.0, 0.0+rmRandFloat(-0.1, 0.0));
	rmRiverSetBankNoiseParams(afluent2ID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);	
	}	
	if (MapVariation ==3)  // RIVER STARTS NORTH, GOES SOUTH
	{	
	bigriverID = rmRiverCreate(-1, "Yukon River", 10, 15, 10, 9);    //3: width
	rmRiverAddWaypoint(bigriverID, 1.0, 0.5+rmRandFloat(-0.1, 0.1));
	rmRiverAddWaypoint(bigriverID, 0.7, 0.5);
	rmRiverAddWaypoint(bigriverID, 0.4, 0.5);
	rmRiverAddWaypoint(bigriverID, 0.0, 0.5+rmRandFloat(-0.1, 0.1));	
	rmRiverSetBankNoiseParams(bigriverID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	
	int AfluentDirection = rmRandInt(0,1);
	afluent1ID = rmRiverCreate(-1, "Yukon River", 20, 15, 5, 9);    //3: width
	rmRiverAddWaypoint(afluent1ID, 0.7, 0.5);
	rmRiverAddWaypoint(afluent1ID, 0.2+rmRandFloat(-0.1, 0.1), 0+AfluentDirection);
	rmRiverSetBankNoiseParams(afluent1ID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	
	afluent2ID = rmRiverCreate(-1, "Yukon River", 5, 15, 5, 9);    //3: width
	rmRiverAddWaypoint(afluent2ID, 0.4, 0.5);
	rmRiverAddWaypoint(afluent2ID, 0, 1-AfluentDirection);
	rmRiverSetBankNoiseParams(afluent2ID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);	
	}		
	
	rmRiverSetShallowRadius(bigriverID, 10+cNumberNonGaiaPlayers);	
	rmRiverSetShallowRadius(afluent1ID, 10+cNumberNonGaiaPlayers);	
	rmRiverSetShallowRadius(afluent2ID, 10+cNumberNonGaiaPlayers);		
	rmRiverAddShallow(bigriverID, rmRandFloat(0.4, 0.6));	
	rmRiverAddShallow(bigriverID, rmRandFloat(0.1, 0.2));	
	rmRiverAddShallow(bigriverID, rmRandFloat(0.4, 0.6));	
	rmRiverAddShallow(bigriverID, rmRandFloat(0.7, 0.8));
	rmRiverAddShallow(afluent1ID, rmRandFloat(0.3, 0.4));
	rmRiverAddShallow(afluent1ID, rmRandFloat(0.7, 0.8));
	rmRiverAddShallow(afluent2ID, 0.5);			
	rmRiverBuild(bigriverID);
	rmRiverBuild(afluent1ID);
	rmRiverBuild(afluent2ID);	
	
	
/////////////////////////////// FROST AT THE END OF THE RIVER ////////////////////////////////////

	rmDefineClass("frost");
	
   int FrostID = rmCreateArea("Frost");
   rmSetAreaWarnFailure(FrostID, false);
   rmSetAreaSize(FrostID, 0.03, 0.03);
   	rmSetAreaElevationVariation(FrostID, 0.0);
	rmSetAreaBaseHeight(FrostID, -0.4);
   rmSetAreaCoherence(FrostID, 0.7);
	rmSetAreaMinBlobs(FrostID, 4);
	rmSetAreaMaxBlobs(FrostID, 6);
	         rmAddAreaToClass(FrostID, rmClassID("classMountain")); 
	rmSetAreaMinBlobDistance(FrostID, 40);
	rmSetAreaMaxBlobDistance(FrostID, 80);
	rmSetAreaSmoothDistance(FrostID, 8);
   rmSetAreaObeyWorldCircleConstraint(FrostID, false);
   rmSetAreaMix(FrostID, "great_lakes_ice");
	rmAddAreaToClass(FrostID, rmClassID("frost"));
		if (MapVariation ==1)
		{  	rmSetAreaLocation(FrostID, 0.4, 1); }
		if (MapVariation ==2)
		{  	rmSetAreaLocation(FrostID, 0.4, 0); }
		if (MapVariation ==3)
		{  	rmSetAreaLocation(FrostID, 0, 0.5); }
   rmBuildArea(FrostID);





/////////////////////////////// DEFINE STARTING OBJECTS ////////////////////////////////////

  int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 60.0);
	int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 60.0);
	int avoidTradeRouteSockets=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 12.0);
	int avoidTradeRouteSocketsShort=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 8.0);
	int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other short", rmClassID("importantItem"), 8.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("short stay away from players", classPlayer, 5.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);



  int food1ID=rmCreateObjectDef("huntable1");
	rmAddObjectDefItem(food1ID, huntable1, rmRandInt(8,10), 6.0);
	rmSetObjectDefCreateHerd(food1ID, true);
	rmSetObjectDefMinDistance(food1ID, 10.0);
	rmSetObjectDefMaxDistance(food1ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food1ID, avoidResource);
	rmAddObjectDefConstraint(food1ID, playerConstraint);
	rmAddObjectDefConstraint(food1ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food1ID, avoidHuntable1);
	rmAddObjectDefConstraint(food1ID, avoidHuntable2);
	rmAddObjectDefConstraint(food1ID, avoidmountain);
	rmAddObjectDefConstraint(food1ID, avoidTradeRoute);
  rmAddObjectDefConstraint(food1ID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(food1ID, avoidTradeRouteSocketsShort);
  
  int food2ID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(food2ID, huntable2, rmRandInt(8,10), 6.0);
	rmSetObjectDefCreateHerd(food2ID, true);
	rmSetObjectDefMinDistance(food2ID, 10.0);
	rmSetObjectDefMaxDistance(food2ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food2ID, avoidResource);
	rmAddObjectDefConstraint(food2ID, playerConstraint);
	rmAddObjectDefConstraint(food2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food2ID, avoidHuntable1);
	rmAddObjectDefConstraint(food2ID, avoidmountain);
	rmAddObjectDefConstraint(food2ID, avoidHuntable2);
	rmAddObjectDefConstraint(food2ID, avoidTradeRoute);
	rmAddObjectDefConstraint(food2ID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(food2ID, avoidTradeRouteSocketsShort);
 
  int food3ID=rmCreateObjectDef("huntable3");
	rmAddObjectDefItem(food3ID, huntable3, rmRandInt(7,9), 6.0);
	rmSetObjectDefCreateHerd(food3ID, true);
	rmSetObjectDefMinDistance(food3ID, 10.0);
	rmSetObjectDefMaxDistance(food3ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food3ID, avoidResource);
	rmAddObjectDefConstraint(food3ID, playerConstraint);
	rmAddObjectDefConstraint(food3ID, avoidmountain);
	rmAddObjectDefConstraint(food3ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food3ID, avoidHuntable1);
	rmAddObjectDefConstraint(food3ID, avoidHuntable2);
	rmAddObjectDefConstraint(food3ID, avoidTradeRoute);
	rmAddObjectDefConstraint(food3ID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(food3ID, avoidTradeRouteSocketsShort);
	
  int startFoodID=rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(startFoodID, huntable3, 6, 4.0);
	rmSetObjectDefMinDistance(startFoodID, 12.0);
	rmSetObjectDefMaxDistance(startFoodID, 18.0);
	rmSetObjectDefCreateHerd(startFoodID, false);
	rmAddObjectDefConstraint(startFoodID, avoidAll);
	rmAddObjectDefConstraint(startFoodID, avoidStartResource);
	rmAddObjectDefConstraint(startFoodID, avoidHuntable1);    
	rmAddObjectDefConstraint(startFoodID, avoidHuntable2);    
  rmAddObjectDefConstraint(startFoodID, avoidTradeRoute);
  
  int startFood2ID=rmCreateObjectDef("starting hunt");
	rmAddObjectDefItem(startFood2ID, huntable2, 5, 4.0);
	rmSetObjectDefMinDistance(startFood2ID, 18.0);
	rmSetObjectDefMaxDistance(startFood2ID, 25.0);
	rmSetObjectDefCreateHerd(startFood2ID, false);
	rmAddObjectDefConstraint(startFood2ID, avoidAll);
	rmAddObjectDefConstraint(startFood2ID, avoidStartResource);
	rmAddObjectDefConstraint(startFood2ID, avoidHuntable1);    
	rmAddObjectDefConstraint(startFood2ID, avoidHuntable2);    
  rmAddObjectDefConstraint(startFood2ID, avoidTradeRoute);
  
  int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 6, 6.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 16);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 22);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartResource);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRouteSocketsShort);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRoute);

	int StartBerriesID=rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(StartBerriesID, "GrapeBush", 6, 5.0);
	rmSetObjectDefMinDistance(StartBerriesID, 10);
	rmSetObjectDefMaxDistance(StartBerriesID, 15);
	rmAddObjectDefConstraint(StartBerriesID, avoidAll);
	rmAddObjectDefConstraint(StartBerriesID, avoidStartResource);
	rmAddObjectDefConstraint(StartBerriesID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(StartBerriesID, shortPlayerConstraint);
  rmAddObjectDefConstraint(StartBerriesID, avoidTradeRoute);

  int startSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(startSilverID, "minegold", 1, 0);
	rmSetObjectDefMinDistance(startSilverID, 18.0);
	rmSetObjectDefMaxDistance(startSilverID, 23.0);
	rmAddObjectDefConstraint(startSilverID, avoidAll);
	rmAddObjectDefConstraint(startSilverID, avoidImpassableLand);
  rmAddObjectDefConstraint(startSilverID, avoidTradeRoute);
  
  int startSilver2ID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(startSilver2ID, "mine", 1, 0);
	rmSetObjectDefMinDistance(startSilver2ID, 23.0);
	rmSetObjectDefMaxDistance(startSilver2ID, 35.0);
	rmAddObjectDefConstraint(startSilver2ID, avoidAll);
	rmAddObjectDefConstraint(startSilver2ID, avoidImpassableLand);
  rmAddObjectDefConstraint(startSilver2ID, avoidTradeRoute);
  
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


  
  

  
     
  
		
			
/////////////////////////////// PLACE PLAYERS ////////////////////////////////////

  // starting resources

  int startingTCID= rmCreateObjectDef("startingTC");
	if (rmGetNomadStart()) {
			rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 0.0);
  }
		
  else {
    rmAddObjectDefItem(startingTCID, "townCenter", 1, 0.0);
  }

  rmSetObjectDefMinDistance(startingTCID, 10);
	rmSetObjectDefMaxDistance(startingTCID, 40);
	rmAddObjectDefConstraint(startingTCID, avoidImpassableLand);
  rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);
    rmAddObjectDefConstraint(startingTCID, avoidTradeRouteSockets); 
    rmAddObjectDefConstraint(startingTCID, shortAvoidTradeRoute); 
    rmAddObjectDefConstraint(startingTCID, shortAvoidImportantItem); 
    rmAddObjectDefConstraint(startingTCID, hugePlayerConstraint); 
    rmAddObjectDefConstraint(startingTCID, playerEdgeConstraint);  
    rmAddObjectDefConstraint(startingTCID, avoidRiverFar);
    rmAddObjectDefConstraint(startingTCID, avoidmountain);   	   	
  rmAddObjectDefToClass(startingTCID, rmClassID("player"));

   // Text
   rmSetStatusText("",0.35);
  
  rmClearClosestPointConstraints();

	for(i=1; < cNumberPlayers) {
		int placedTC = rmPlaceObjectDefInArea(startingTCID, i, AreaID);
		vector TCLocation=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(startSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(startSilver2ID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
//		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));

    // Food
//		rmPlaceObjectDefAtLoc(StartBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    rmPlaceObjectDefAtLoc(startFoodID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    rmPlaceObjectDefAtLoc(startFood2ID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));

    // Place a nugget for the player
    rmSetNuggetDifficulty(21, 21);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    
    rmClearClosestPointConstraints();
  }

  

		int avoidNativesVeryLong = rmCreateClassDistanceConstraint("avoid natives long ", rmClassID("natives"), 100.0);
	int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 5.0);
	


		
			
			  	/////////////////////////////// PLACE EUROPEAN VILLAGES ////////////////////////////////////   


	
	        // Native settlements defined and placed
 
		int whichNative = 0;
      int nativeVillage = 0;
		string nativeName = "";
	  




	int nativeNumber = rmRandInt(3,4);
	if(rmRandFloat(0,1) < 0.25)
		nativeNumber = rmRandInt(5,6);
	else if(rmRandFloat(0,1) < 0.15)
		nativeNumber = rmRandInt(1,2);
	
	for(i = 0; <nativeNumber)
	{	
	if (cNumberTeams <= 2)
	{
		      whichNative = rmRandInt(1,3);
      if(whichNative == 1)
      {
         rmSetSubCiv(1, "FurTrapper");
         nativeName = "EURNShunters med";
      }
	   if(whichNative == 2)
      {
         rmSetSubCiv(2, "MiningCamp");
         nativeName = "EURNSstonemasons east";
      }
	   if(whichNative == 3)
      {
         rmSetSubCiv(0, "LoggingCamp");
         nativeName = "EURNSlumberjacks med";
      }
	  
	  
      nativeVillage = rmCreateGrouping("European "+i, nativeName);
      rmSetGroupingMinDistance(nativeVillage, 20.0);
      rmSetGroupingMaxDistance(nativeVillage, 40.0);
      rmAddGroupingToClass(nativeVillage, longPlayerConstraint);
      rmAddGroupingConstraint(nativeVillage, avoidAll);
      rmAddGroupingConstraint(nativeVillage, playerEdgeConstraint);
      rmAddGroupingConstraint(nativeVillage, avoidTradeRoute);
      rmAddGroupingConstraint(nativeVillage, longPlayerConstraint);
      rmAddGroupingConstraint(nativeVillage, avoidRiver);
      rmAddGroupingConstraint(nativeVillage, avoidmountain);
	  	rmAddGroupingConstraint(nativeVillage, avoidNativesVeryLong);
		  	rmAddGroupingConstraint(nativeVillage, avoidTradeRouteFar);
		rmAddGroupingToClass(nativeVillage, rmClassID("natives"));
	 	rmAddGroupingConstraint(nativeVillage, avoidImpassableLand);
	rmPlaceGroupingInArea(nativeVillage, i, AreaID);
	}
	else
	{

			
	
	}
		}





 
 
   



/////////////////////////////// MINES ////////////////////////////////////


	// Silver

	int silverID = -1;
	int silverType = -1;
	int silverCount = (cNumberNonGaiaPlayers*3)+6;
	rmEchoInfo("silver count = "+silverCount);

		int avoidFastCoin=-1;
	if (cNumberNonGaiaPlayers >6)
	{
		avoidFastCoin=rmCreateTypeDistanceConstraint("fast coin avoids coin", "mine", rmXFractionToMeters(0.14));
	}
	else if (cNumberNonGaiaPlayers >4)
	{
		avoidFastCoin=rmCreateTypeDistanceConstraint("fast coin avoids coin", "mine", rmXFractionToMeters(0.16));
	}
	else
	{
		avoidFastCoin=rmCreateTypeDistanceConstraint("fast coin avoids coin", "mine", rmXFractionToMeters(0.18));
	}
	
	for(i=0; < silverCount)
	{
		silverType = rmRandInt(1,10);
		silverID = rmCreateObjectDef("silver "+i);
		rmAddObjectDefItem(silverID, "mine", 1, 0.0);
		rmSetObjectDefMinDistance(silverID, 0.0);
		rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(silverID, avoidFastCoin);
		rmAddObjectDefConstraint(silverID, avoidAll);
		rmAddObjectDefConstraint(silverID, avoidImpassableLand);
		rmAddObjectDefConstraint(silverID, avoidTradeRoute);
		rmAddObjectDefConstraint(silverID, avoidSocket);
		rmAddObjectDefConstraint(silverID, avoidRiver);
		rmAddObjectDefConstraint(silverID, avoidmountain);
//		rmAddObjectDefConstraint(silverID, coinForestConstraint);
		rmAddObjectDefConstraint(silverID, playerConstraint);
//		rmAddObjectDefConstraint(silverID, avoidNuggetSmall);
		int result = rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
		if(result == 0)
			break;
   }
   
   

   /////////////////////////////// MOUNTAINS ////////////////////////////////////   
  
   
      numTries2=30;	  
   for (i=0; <numTries2)
      {   
         int mountainsID=rmCreateArea("mountain "+i);
         rmSetAreaWarnFailure(mountainsID, false);
         rmSetAreaSize(mountainsID, 0.01, 0.01);
			rmSetAreaCliffType(mountainsID, "rocky mountain edge");
			rmSetAreaCliffEdge(mountainsID, 1, 1.0, 0.0, 0.0, 0);
			rmSetAreaCliffHeight(mountainsID, 8, 1.0, 0.3);
			rmSetAreaCliffPainting(mountainsID, false, false, true);
         rmSetAreaMinBlobs(mountainsID, 5);
         rmSetAreaMaxBlobs(mountainsID, 15);
         rmSetAreaMinBlobDistance(mountainsID, 20.0);
         rmSetAreaMaxBlobDistance(mountainsID, 60.0);
         rmSetAreaCoherence(mountainsID, 0.9);
         rmSetAreaSmoothDistance(mountainsID, 10);
         rmAddAreaToClass(mountainsID, rmClassID("classMountain")); 
        rmAddAreaConstraint(mountainsID, mountainvsmountain);
        rmAddAreaConstraint(mountainsID, avoidRiverFar);
         rmAddAreaConstraint(mountainsID, avoidAll);
         rmAddAreaConstraint(mountainsID, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(mountainsID, playerConstraint);
		 rmAddAreaConstraint(mountainsID, avoidSocket);
		 rmAddAreaConstraint(mountainsID, avoidCW);
		  rmAddAreaConstraint(mountainsID, avoidMines);
			rmAddAreaConstraint(mountainsID, avoidNatives);
         rmAddAreaConstraint(mountainsID, shortAvoidTradeRoute); 
         rmAddAreaConstraint(mountainsID, avoidTradeRouteSockets); 
         if(rmBuildArea(mountainsID)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount++;
            if(failCount==5)
               break;
         }
         else
            failCount=0; 
      } 
	  
	  
/////////////////////////////// TREASURES ////////////////////////////////////




 int nugget4= rmCreateObjectDef("nugget nuts"); 
  rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(4, 4);
  rmSetObjectDefMinDistance(nugget4, 0.0);
  rmSetObjectDefMaxDistance(nugget4, rmXFractionToMeters(0.2));
  rmAddObjectDefConstraint(nugget4, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget4, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget4, avoidResource);
  rmAddObjectDefConstraint(nugget4, avoidNuggets);
   rmAddObjectDefConstraint(nugget4, avoidNatives);
     rmAddObjectDefConstraint(nugget4, avoidmountain);
  rmAddObjectDefConstraint(nugget4, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget4, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget4, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget4, circleConstraint);
  rmPlaceObjectDefAtLoc(nugget4, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);

  int nugget3= rmCreateObjectDef("nugget hard"); 
  rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(3, 3);
  rmSetObjectDefMinDistance(nugget3, 0.0);
  rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.2));
  rmAddObjectDefConstraint(nugget3, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget3, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget3, avoidResource);
  rmAddObjectDefConstraint(nugget3, avoidNuggets);
       rmAddObjectDefConstraint(nugget3, avoidmountain);
     rmAddObjectDefConstraint(nugget3, avoidNatives);
  rmAddObjectDefConstraint(nugget3, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget3, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget3, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget3, circleConstraint);
  rmPlaceObjectDefAtLoc(nugget3, 0, 0.5, 0.5, cNumberNonGaiaPlayers+rmRandInt(1,1));

  int nugget2= rmCreateObjectDef("nugget medium"); 
  rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(2, 2);
  rmAddObjectDefConstraint(nugget2, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget2, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget2, avoidResource);
  rmAddObjectDefConstraint(nugget2, avoidNuggetFar);
       rmAddObjectDefConstraint(nugget2, avoidmountain);
     rmAddObjectDefConstraint(nugget2, avoidNatives);
  rmAddObjectDefConstraint(nugget2, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget2, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget2, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget2, circleConstraint);
  rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.25));
  rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.3));
  rmPlaceObjectDefAtLoc(nugget2, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

  int nugget1= rmCreateObjectDef("nugget easy"); 
  rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(1, 1);
  rmAddObjectDefConstraint(nugget1, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget1, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget1, avoidNuggetFar);
     rmAddObjectDefConstraint(nugget1, avoidNatives);
	      rmAddObjectDefConstraint(nugget1, avoidmountain);
  rmAddObjectDefConstraint(nugget1, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget1, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget1, playerConstraint);
  rmAddObjectDefConstraint(nugget1, circleConstraint);
  rmSetObjectDefMinDistance(nugget1, rmXFractionToMeters(0.3));
  rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.4));
  rmPlaceObjectDefAtLoc(nugget1, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

 



  

	
 
  /////////////////////////////// FORESTS ////////////////////////////////////





   numTries2=20*cNumberNonGaiaPlayers;	  
   for (i=0; <numTries2)
      {   
         int forest2=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest2, false);
         rmSetAreaSize(forest2, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest2, "rockies forest");
         rmSetAreaForestDensity(forest2, 0.4);
         rmSetAreaForestClumpiness(forest2, 0.2);
         rmSetAreaForestUnderbrush(forest2, 0.0);
         rmSetAreaMinBlobs(forest2, 3);
         rmSetAreaMaxBlobs(forest2, 7);
         rmSetAreaMinBlobDistance(forest2, 16.0);
         rmSetAreaMaxBlobDistance(forest2, 40.0);
         rmSetAreaCoherence(forest2, 0.9);
         rmSetAreaSmoothDistance(forest2, 10);
         rmAddAreaToClass(forest2, rmClassID("classForest")); 
        rmAddAreaConstraint(forest2, forestConstraint);
        rmAddAreaConstraint(forest2, avoidAll);
        rmAddAreaConstraint(forest2, shortAvoidImpassableLand); 
		rmAddAreaConstraint(forest2, avoidTC);
		rmAddAreaConstraint(forest2, avoidSocket);
		rmAddAreaConstraint(forest2, avoidCW);
		rmAddAreaConstraint(forest2, avoidmountain);
		rmAddAreaConstraint(forest2, avoidMines);
		rmAddAreaConstraint(forest2, avoidNatives);
        rmAddAreaConstraint(forest2, shortAvoidTradeRoute); 
        rmAddAreaConstraint(forest2, avoidTradeRouteSockets); 
         if(rmBuildArea(forest2)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount++;
            if(failCount==5)
               break;
         }
         else
            failCount=0; 
      } 

	  
	  /////////////////////////////// SHEEP ////////////////////////////////////
  
  	int sheepID=rmCreateObjectDef("sheep");
	rmAddObjectDefItem(sheepID, "sheep", 2, 4.0);
	rmSetObjectDefMinDistance(sheepID, 0.0);
	rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(sheepID, avoidSheep);
	rmAddObjectDefConstraint(sheepID, avoidAll);
	rmAddObjectDefConstraint(sheepID, playerConstraint);
	rmAddObjectDefConstraint(sheepID, avoidmountain);
	rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);
	
/////////////////////////////// HUNTABLES ////////////////////////////////////

  rmPlaceObjectDefAtLoc(food1ID, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
  rmPlaceObjectDefAtLoc(food2ID, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
  rmPlaceObjectDefAtLoc(food3ID, 0, 0.5, 0.5, 4.0*cNumberNonGaiaPlayers);
  
  
    	int ChamoisID=rmCreateObjectDef("Chamois");
	rmAddObjectDefItem(ChamoisID, "Chamois", rmRandInt(2,5), 4.0);
	rmSetObjectDefMinDistance(ChamoisID, 0.0);
	rmSetObjectDefMaxDistance(ChamoisID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(ChamoisID, avoidSheep);
	rmAddObjectDefConstraint(ChamoisID, avoidAll);
	rmAddObjectDefConstraint(ChamoisID, playerConstraint);
	rmAddObjectDefConstraint(ChamoisID, avoidmountain);
	rmAddObjectDefConstraint(ChamoisID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(ChamoisID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);
  

  // King of the Hill (added 2026-11 for WoL): the middle is on the mountain rivers; first open land on the line that splits the teams
  if(rmGetIsKOTH()) {
    // the middle of each team's starts (player 1's team, and everybody else)
    float kothAX = 0.0;
    float kothAZ = 0.0;
    float kothAN = 0.0;
    float kothBX = 0.0;
    float kothBZ = 0.0;
    float kothBN = 0.0;
    for (kothP = 1; < cNumberPlayers) {
      if (rmGetPlayerTeam(kothP) == rmGetPlayerTeam(1)) {
        kothAX = kothAX + rmPlayerLocXFraction(kothP);
        kothAZ = kothAZ + rmPlayerLocZFraction(kothP);
        kothAN = kothAN + 1.0;
      }
      else {
        kothBX = kothBX + rmPlayerLocXFraction(kothP);
        kothBZ = kothBZ + rmPlayerLocZFraction(kothP);
        kothBN = kothBN + 1.0;
      }
    }
    // from the point between them, along the line square to the one joining them
    float kothX = 0.5;
    float kothZ = 0.5;
    float kothDirX = 1.0;
    float kothDirZ = 0.0;
    if (kothBN > 0.0) {
      kothAX = kothAX / kothAN;
      kothAZ = kothAZ / kothAN;
      kothBX = kothBX / kothBN;
      kothBZ = kothBZ / kothBN;
      kothX = (kothAX + kothBX) / 2.0;
      kothZ = (kothAZ + kothBZ) / 2.0;
      float kothLen = sqrt((kothBX - kothAX) * (kothBX - kothAX) + (kothBZ - kothAZ) * (kothBZ - kothAZ));
      if (kothLen > 0.01) {
        kothDirX = 0.0 - (kothBZ - kothAZ) / kothLen;
        kothDirZ = (kothBX - kothAX) / kothLen;
      }
    }
    // the hill on the first open land along that line, from the middle outwards, one side then the other
    // (0.04 of the map side per step), with the include's placer constraints, 40 m from every Town Center
    // and 10 m from every tree
    int kothAvoidLand = rmCreateTerrainDistanceConstraint("koth hill avoids impassable land", "Land", false, 6.0);
    int kothAvoidAll = rmCreateTypeDistanceConstraint("koth hill avoids all", "all", 4.0);
    int kothAvoidTC = rmCreateTypeDistanceConstraint("koth hill avoids TCs", "TownCenter", 40.0);
    int kothAvoidTrees = rmCreateTypeDistanceConstraint("koth hill avoids trees", "Tree", 10.0);
    int kothAvoidSocket = rmCreateTypeDistanceConstraint("koth hill avoids trade sockets", "socketTradeRoute", 6.0);
    int kothAvoidRoute = rmCreateTradeRouteDistanceConstraint("koth hill avoids trade route", 6.0);
    int kothAvoidFlag = rmCreateTypeDistanceConstraint("koth hill avoids water flags", "HomeCityWaterSpawnFlag", 4.0);
    float kothDist = 0.0;
    for (kothRound = 0; < 17) {
      int kothHill = rmCreateObjectDef("koth hill " + kothRound);
      rmAddObjectDefItem(kothHill, "ypKingsHill", 1, 0);
      rmSetObjectDefMinDistance(kothHill, 0.0);
      rmSetObjectDefMaxDistance(kothHill, rmXFractionToMeters(0.05));
      rmAddObjectDefConstraint(kothHill, kothAvoidLand);
      rmAddObjectDefConstraint(kothHill, kothAvoidAll);
      rmAddObjectDefConstraint(kothHill, kothAvoidTC);
      rmAddObjectDefConstraint(kothHill, kothAvoidTrees);
      rmAddObjectDefConstraint(kothHill, kothAvoidSocket);
      rmAddObjectDefConstraint(kothHill, kothAvoidRoute);
      rmAddObjectDefConstraint(kothHill, kothAvoidFlag);
      rmPlaceObjectDefAtLoc(kothHill, 0, kothX + kothDirX * kothDist, kothZ + kothDirZ * kothDist, 1);
      if (rmGetNumberUnitsPlaced(kothHill) > 0)
        break;
      // 0, +1, -1, +2, -2, ... steps
      if (kothDist > 0.0)
        kothDist = 0.0 - kothDist;
      else
        kothDist = 0.04 - kothDist;
    }
  }

}
