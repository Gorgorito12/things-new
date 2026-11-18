// Ecruteak
// This time is personal

include "mercenaries.xs";
//include "GWevent.xs";
include "ypAsianInclude.xs";
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
	int size=2.5*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Set up default water type.
	rmSetSeaLevel(1.0);          
	rmSetSeaType("Coastal Japan Ecruteak");
	rmSetBaseTerrainMix("caribbean grass");
	rmSetMapType("ecruteak");
//	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetLightingSet("pampas");

	// Initialize map.
	rmTerrainInitialize("water");

	// Misc variables for use later
	int numTries = -1;
		int numTries2 = -1;
			int numTries3 = -1;

	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
	int classIslandSmall=rmDefineClass("islandsmall");
	int classStartingUnits = rmDefineClass("Starting Units");
	rmDefineClass("classForest");
	rmDefineClass("classColors");
	rmDefineClass("classCenter");
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("classSocket");
	rmDefineClass("canyon");
	rmDefineClass("classWaterTradeRoute");

  string herdableType = "ypWaterBuffalo";
  string huntable1 = "ypSerow";
  string huntable2 = "BerryBush";
  string huntable3 = "Rabbit";
  string fish1 = "ypFishCatfish";
  string fish2 = "ypSquid";
  string whale1 = "HumpbackWhale";
  string startTreeType = "TreeRedForest";
    string startTreeType2 = "TreeNewEnglandSnow";
  
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
	int avoidTCfar=rmCreateTypeDistanceConstraint("stay away from TC by a lot", "TownCenter", 60.0);
	int avoidTCshort=rmCreateTypeDistanceConstraint("stay away from TC by a little bit", "TownCenter", 8.0);
	int avoidTP=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets", "SocketTradeRoute", 14.0);  // JSB 1-11-05 - Just added, to try to prevent things from stomping on TPs.
	int avoidCW=rmCreateTypeDistanceConstraint("stay away from CW", "CoveredWagon", 24.0);
	int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);



	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "Fish", 25.0);			// was 50.0
	// int fishVsFishTarponID=rmCreateTypeDistanceConstraint("fish v fish2", "fishTarpon", 20.0);  // was 40.0 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 8.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "HumpbackWhale", 40.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 17.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int avoidCoin=-1;

  int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 60.0);
	int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 60.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);
	int avoidTradeRouteSockets=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 8.0);
	int avoidTradeRouteSocketsShort=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 8.0);
	int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other short", rmClassID("importantItem"), 8.0);
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route short", 4.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("short stay away from players", classPlayer, 5.0);
	
	
	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minegold", 75.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minegold", 85.0);	// 85.0 seems the best for event minegold distribution.  This number tells minegolds how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random turkeys", "turkey", 50.0);	//Attempting to spread them out more evenly.
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 54.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 120.0);  //Added sheep 11-28-05 JSB
	int avoidBellTower=rmCreateTypeDistanceConstraint("avoid bell tower", "DLCbelltower", 30.0);  //Added sheep 11-28-05 JSB
	
	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 14.0);  //This one is used in one place: for helping place FFA TC's better.

	// Constraint to avoid water.
	int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);   //I added this one so I could experiment with it.
	int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 8.0);
		int avoidWater15 = rmCreateTerrainDistanceConstraint("avoid water medium 2", "Land", false, 15.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);  //Added this one too.
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 18.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25); //Was 15, but made larger so ships don't sometimes stomp each other when arriving from HC.
	rmAddClosestPointConstraint(avoidWater8);  //was originally 8
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
	int avoidWaterTradeRoute = rmCreateClassDistanceConstraint("avoid water socket", rmClassID("classWaterTradeRoute"), 10.0);
	int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("classSocket"), 10.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);

	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  (It excludes the west bay, where I do not want the flags.)
	int circleConstraint=rmCreatePieConstraint("semi-circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(50), rmDegreesToRadians(290));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

  int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);

	int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 50.0);
	int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives by a bit", rmClassID("natives"), 20.0);



/////////////////////////////// ISLANDS ////////////////////////////////////

	// Bonus area constraint.  
	int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 28.0);
	int islandConstraint2=rmCreateClassDistanceConstraint("islands avoid each other 2", classIsland, 10.0);
	int islandConstraintSmall=rmCreateClassDistanceConstraint("islands avoid each other 3", classIslandSmall, 10.0);
	
	int pokeballConstraint=rmCreateClassDistanceConstraint("pokeballconstraint", classIsland, 10.0);
	int pokeballEdgeConstraint=rmCreatePieConstraint("areas edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int redConstraint=rmCreatePieConstraint("red edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(-45), rmDegreesToRadians(135));
	int whiteConstraint=rmCreatePieConstraint("white edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(135), rmDegreesToRadians(-45));
	int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("classCenter"), 10.0);
	int avoidColors = rmCreateClassDistanceConstraint("avoid colors", rmClassID("classColors"), 10.0);		
	
   int IslandLoc = 1;								

   
   

	
	
	// Make GREEN AREA

	int GreenID=rmCreateArea("Green Area");
	rmSetAreaSize(GreenID, 0.07, 0.07);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(GreenID, 1.0);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(GreenID, 2.0);
	rmSetAreaSmoothDistance(GreenID, 10);
	rmSetAreaMix(GreenID, "ecruteak_white_grass");
	rmAddAreaToClass(GreenID, classIsland);
	rmAddAreaConstraint(GreenID, islandConstraint);
	rmAddAreaConstraint(GreenID, islandConstraintSmall);
	rmAddAreaConstraint(GreenID, avoidTradeRoute);
	rmSetAreaObeyWorldCircleConstraint(GreenID, false);
	rmSetAreaElevationType(GreenID, cElevTurbulence);
	rmSetAreaElevationVariation(GreenID, 4.0);
	rmAddAreaToClass(GreenID, rmClassID("classCenter")); 
	rmSetAreaElevationMinFrequency(GreenID, 0.09);
	rmSetAreaElevationOctaves(GreenID, 3);
	rmSetAreaElevationPersistence(GreenID, 0.2);
	rmSetAreaElevationNoiseBias(GreenID, 1); 
	rmSetAreaWarnFailure(GreenID, false);

		// Make RED AREA

	int RedID=rmCreateArea("Red Area");
	rmSetAreaSize(RedID, 0.3, 0.3);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(RedID, 1.0);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(RedID, 2.0);
	rmSetAreaSmoothDistance(RedID, 10);
	rmSetAreaMix(RedID, "ecruteak_red_grass");
	rmAddAreaToClass(RedID, classIsland);
	rmAddAreaConstraint(RedID, islandConstraint);
	rmAddAreaConstraint(RedID, islandConstraintSmall);
	rmAddAreaConstraint(RedID, avoidTradeRoute);
	rmSetAreaObeyWorldCircleConstraint(RedID, false);
	rmSetAreaElevationType(RedID, cElevTurbulence);
	rmAddAreaToClass(RedID, rmClassID("classColors")); 
	rmSetAreaElevationVariation(RedID, 4.0);
	rmSetAreaElevationMinFrequency(RedID, 0.09);
	rmSetAreaElevationOctaves(RedID, 3);
	rmSetAreaElevationPersistence(RedID, 0.2);
	rmSetAreaElevationNoiseBias(RedID, 1); 
	rmSetAreaWarnFailure(RedID, false);
    rmAddAreaConstraint(RedID, pokeballConstraint); 
	rmAddAreaConstraint(RedID, redConstraint); 
    rmAddAreaConstraint(RedID, playerEdgeConstraint);

		// Make WHITE AREA

	int WhiteID=rmCreateArea("White Area");
	rmSetAreaSize(WhiteID, 0.3, 0.3);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(WhiteID, 1.0);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(WhiteID, 2.0);
	rmSetAreaSmoothDistance(WhiteID, 10);
	rmSetAreaMix(WhiteID, "ecruteak_white_grass");
	rmAddAreaToClass(WhiteID, classIsland);
	rmAddAreaConstraint(WhiteID, islandConstraint);
	rmAddAreaConstraint(WhiteID, islandConstraintSmall);
	rmAddAreaConstraint(WhiteID, avoidTradeRoute);
	rmSetAreaObeyWorldCircleConstraint(WhiteID, false);
	rmSetAreaElevationType(WhiteID, cElevTurbulence);
	rmAddAreaToClass(WhiteID, rmClassID("classColors")); 
	rmSetAreaElevationVariation(WhiteID, 4.0);
	rmSetAreaElevationMinFrequency(WhiteID, 0.09);
	rmSetAreaElevationOctaves(WhiteID, 3);
	rmSetAreaElevationPersistence(WhiteID, 0.2);
	rmSetAreaElevationNoiseBias(WhiteID, 1); 
	rmSetAreaWarnFailure(WhiteID, false);
    rmAddAreaConstraint(WhiteID, pokeballConstraint); 
	rmAddAreaConstraint(WhiteID, whiteConstraint); 
    rmAddAreaConstraint(WhiteID, playerEdgeConstraint);

	

   	// Make BRIDGE 1

	int BridgeLeftID=rmCreateArea("Left Bridge");
		rmSetAreaWaterType(BridgeLeftID, "Coastal Japan Ecruteak");
	rmSetAreaSize(BridgeLeftID, 0.02, 0.02);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(BridgeLeftID, 1.0);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(BridgeLeftID, 2.0);
	rmSetAreaSmoothDistance(BridgeLeftID, 10);
	rmSetAreaMix(BridgeLeftID, "ecruteak_white_grass");
	rmSetAreaObeyWorldCircleConstraint(BridgeLeftID, false);
	rmSetAreaElevationType(BridgeLeftID, cElevTurbulence);
	rmSetAreaElevationVariation(BridgeLeftID, -1.0);
	rmAddAreaToClass(BridgeLeftID, rmClassID("classCenter")); 
	rmSetAreaElevationMinFrequency(BridgeLeftID, 0.09);
	rmSetAreaElevationOctaves(BridgeLeftID, 3);
	rmSetAreaElevationPersistence(BridgeLeftID, 0.2);
	rmSetAreaElevationNoiseBias(BridgeLeftID, 1); 
	rmSetAreaWarnFailure(BridgeLeftID, false);
	rmSetAreaLocation(BridgeLeftID, .28, .72);
	rmAddAreaConstraint(BridgeLeftID, avoidColors); 	
	rmBuildArea(BridgeLeftID);	

   	// Make BRIDGE 2

	int BridgeRightID=rmCreateArea("Right Bridge");
		rmSetAreaWaterType(BridgeRightID, "Coastal Japan Ecruteak");
	rmSetAreaSize(BridgeRightID, 0.02, 0.02);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(BridgeRightID, 1.0);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(BridgeRightID, 2.0);
	rmSetAreaSmoothDistance(BridgeRightID, 10);
	rmSetAreaMix(BridgeRightID, "ecruteak_white_grass");
	rmSetAreaObeyWorldCircleConstraint(BridgeRightID, false);
	rmSetAreaElevationType(BridgeRightID, cElevTurbulence);
	rmSetAreaElevationVariation(BridgeRightID, -1.0);
	rmAddAreaToClass(BridgeRightID, rmClassID("classCenter")); 
	rmSetAreaElevationMinFrequency(BridgeRightID, 0.09);
	rmSetAreaElevationOctaves(BridgeRightID, 3);
	rmSetAreaElevationPersistence(BridgeRightID, 0.2);
	rmSetAreaElevationNoiseBias(BridgeRightID, 1); 
	rmSetAreaWarnFailure(BridgeRightID, false);
	rmSetAreaLocation(BridgeRightID, .72, .28);
	rmAddAreaConstraint(BridgeRightID, avoidColors); 	
	rmBuildArea(BridgeRightID);	

   	// Make BRIDGE NORTH

	int BridgeNorthID=rmCreateArea("North Bridge");
		rmSetAreaWaterType(BridgeNorthID, "Coastal Japan Ecruteak");
	rmSetAreaSize(BridgeNorthID, 0.02, 0.02);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(BridgeNorthID, 1.0);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(BridgeNorthID, 2.0);
	rmSetAreaSmoothDistance(BridgeNorthID, 10);
	rmSetAreaMix(BridgeNorthID, "ecruteak_white_grass");
	rmSetAreaObeyWorldCircleConstraint(BridgeNorthID, false);
	rmSetAreaElevationType(BridgeNorthID, cElevTurbulence);
	rmSetAreaElevationVariation(BridgeNorthID, -1.0);
	rmAddAreaToClass(BridgeNorthID, rmClassID("classCenter")); 
	rmSetAreaElevationMinFrequency(BridgeNorthID, 0.09);
	rmSetAreaElevationOctaves(BridgeNorthID, 3);
	rmSetAreaElevationPersistence(BridgeNorthID, 0.2);
	rmSetAreaElevationNoiseBias(BridgeNorthID, 1); 
	rmSetAreaWarnFailure(BridgeNorthID, false);
	rmSetAreaLocation(BridgeNorthID, .39, .39);
	rmAddAreaConstraint(BridgeNorthID, avoidColors); 	
	rmBuildArea(BridgeNorthID);		

	   	// Make BRIDGE SOUTH

	int BridgeSouthID=rmCreateArea("South Bridge");
		rmSetAreaWaterType(BridgeSouthID, "Coastal Japan Ecruteak");
	rmSetAreaSize(BridgeSouthID, 0.02, 0.02);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(BridgeSouthID, 1.0);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(BridgeSouthID, 2.0);
	rmSetAreaSmoothDistance(BridgeSouthID, 10);
	rmSetAreaMix(BridgeSouthID, "ecruteak_white_grass");
	rmSetAreaObeyWorldCircleConstraint(BridgeSouthID, false);
	rmSetAreaElevationType(BridgeSouthID, cElevTurbulence);
	rmSetAreaElevationVariation(BridgeSouthID, -1.0);
	rmAddAreaToClass(BridgeSouthID, rmClassID("classCenter")); 
	rmSetAreaElevationMinFrequency(BridgeSouthID, 0.09);
	rmSetAreaElevationOctaves(BridgeSouthID, 3);
	rmSetAreaElevationPersistence(BridgeSouthID, 0.2);
	rmSetAreaElevationNoiseBias(BridgeSouthID, 1); 
	rmSetAreaWarnFailure(BridgeSouthID, false);
	rmSetAreaLocation(BridgeSouthID, .61, .61);
	rmAddAreaConstraint(BridgeSouthID, avoidColors); 	
	rmBuildArea(BridgeSouthID);	
	
	/////////////////////////////// CENTRAL MOUNTAIN ////////////////////////////////////
	
	
	
		// Make CLIFF 1

	int Cliff1ID=rmCreateArea("Cliff 1");
	rmSetAreaSize(Cliff1ID, 0.025, 0.025);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(Cliff1ID, 1.0);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaSmoothDistance(Cliff1ID, 10);
		rmSetAreaCliffType(Cliff1ID, "Coastal Japan");
		rmAddAreaToClass(Cliff1ID, rmClassID("classCliff"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(Cliff1ID, 2, 0.4, 0.1, 1.0, 0);
		rmSetAreaCliffPainting(Cliff1ID, true, true, true, 1.5, true);
		rmSetAreaCliffHeight(Cliff1ID, 7, 1.0, 1.0);
		rmSetAreaHeightBlend(Cliff1ID, 1);
	rmSetAreaObeyWorldCircleConstraint(Cliff1ID, false);
	rmSetAreaElevationType(Cliff1ID, cElevTurbulence);
	rmSetAreaElevationVariation(Cliff1ID, 2.0);
	rmSetAreaElevationMinFrequency(Cliff1ID, 0.09);
	rmSetAreaElevationOctaves(Cliff1ID, 3);
	rmSetAreaElevationPersistence(Cliff1ID, 0.2);
	rmSetAreaElevationNoiseBias(Cliff1ID, 1); 
	rmSetAreaWarnFailure(Cliff1ID, false);
	
			// Make CLIFF 2

	int Cliff2ID=rmCreateArea("Cliff 2");
	rmSetAreaSize(Cliff2ID, 0.015, 0.015);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(Cliff2ID, 1.0);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaSmoothDistance(Cliff2ID, 10);
		rmSetAreaCliffType(Cliff2ID, "Coastal Japan");
		rmAddAreaToClass(Cliff2ID, rmClassID("classCliff"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(Cliff2ID, 2, 0.4, 0.1, 1.0, 0);
		rmSetAreaCliffPainting(Cliff2ID, true, true, true, 1.5, true);
		rmSetAreaCliffHeight(Cliff2ID, 5, 1.0, 1.0);
		rmSetAreaHeightBlend(Cliff2ID, 1);
	rmSetAreaObeyWorldCircleConstraint(Cliff2ID, false);
	rmSetAreaElevationType(Cliff2ID, cElevTurbulence);
	rmSetAreaElevationVariation(Cliff2ID, 1.0);
	rmSetAreaElevationMinFrequency(Cliff2ID, 0.09);
	rmSetAreaElevationOctaves(Cliff2ID, 3);
	rmSetAreaElevationPersistence(Cliff2ID, 0.2);
	rmSetAreaElevationNoiseBias(Cliff2ID, 1); 
	rmSetAreaWarnFailure(Cliff2ID, false);
	
				// Make CLIFF 3

	int Cliff3ID=rmCreateArea("Cliff 3");
	rmSetAreaSize(Cliff3ID, 0.005, 0.005);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(Cliff3ID, 1.0);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaSmoothDistance(Cliff3ID, 10);
		rmSetAreaCliffType(Cliff3ID, "Coastal Japan");
		rmAddAreaToClass(Cliff3ID, rmClassID("classCliff"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(Cliff3ID, 2, 0.4, 0.1, 1.0, 0);
		rmSetAreaCliffPainting(Cliff3ID, true, true, true, 1.5, true);
		rmSetAreaCliffHeight(Cliff3ID, 5, 1.0, 1.0);
		rmSetAreaHeightBlend(Cliff3ID, 1);
	rmSetAreaObeyWorldCircleConstraint(Cliff3ID, false);
	rmSetAreaElevationType(Cliff3ID, cElevTurbulence);
	rmSetAreaElevationVariation(Cliff3ID, 1.0);
	rmSetAreaElevationMinFrequency(Cliff3ID, 0.09);
	rmSetAreaElevationOctaves(Cliff3ID, 3);
	rmSetAreaElevationPersistence(Cliff3ID, 0.2);
	rmSetAreaElevationNoiseBias(Cliff3ID, 1); 
	rmSetAreaWarnFailure(Cliff3ID, false);
	
		if (IslandLoc == 1)
	
	rmSetAreaLocation(GreenID, .5, .5);		
	rmBuildArea(GreenID);
	
	rmSetAreaLocation(RedID, .7, .7);		
	rmBuildArea(RedID);

 	rmSetAreaLocation(WhiteID, .3, .3);		
	rmBuildArea(WhiteID);
	
	rmSetAreaLocation(Cliff1ID, .5, .5);		
	rmBuildArea(Cliff1ID);

	rmSetAreaLocation(Cliff2ID, .5, .5);		
	rmBuildArea(Cliff2ID);
	
		rmSetAreaLocation(Cliff3ID, .5, .5);		
	rmBuildArea(Cliff3ID);
	
	
	
	/////////////////////////////// THE BELL TOWER ////////////////////////////////////	
	
	
	  int belltowerID = rmCreateObjectDef("bell tower");
	rmAddObjectDefItem(belltowerID, "DLCbelltower", 1, 0);
//	rmSetObjectDefMinDistance(belltowerID, 5.0);
//	rmSetObjectDefMaxDistance(belltowerID, 10.0);
		rmPlaceObjectDefAtLoc(belltowerID, 0, 0.5,0.5);
		
	  int legendarybeast1ID = rmCreateObjectDef("beast1");
	rmAddObjectDefItem(legendarybeast1ID, "DLClegendarybeast1", 1, 0);
	rmSetObjectDefMinDistance(legendarybeast1ID, 5.0);
	rmSetObjectDefMaxDistance(legendarybeast1ID, 10.0);
		rmPlaceObjectDefAtLoc(legendarybeast1ID, 0, 0.5,0.5);
		
	  int legendarybeast2ID = rmCreateObjectDef("beast2");
	rmAddObjectDefItem(legendarybeast2ID, "DLClegendarybeast2", 1, 0);
	rmSetObjectDefMinDistance(legendarybeast2ID, 5.0);
	rmSetObjectDefMaxDistance(legendarybeast2ID, 10.0);
		rmPlaceObjectDefAtLoc(legendarybeast2ID, 0, 0.5,0.5);
		
	  int legendarybeast3ID = rmCreateObjectDef("beast3");
	rmAddObjectDefItem(legendarybeast3ID, "DLClegendarybeast3", 1, 0);
	rmSetObjectDefMinDistance(legendarybeast3ID, 5.0);
	rmSetObjectDefMaxDistance(legendarybeast3ID, 10.0);
		rmPlaceObjectDefAtLoc(legendarybeast3ID, 0, 0.5,0.5);
		
	  int monksID = rmCreateObjectDef("beast4");
	rmAddObjectDefItem(monksID, "ypWokouBlindMonk", cNumberNonGaiaPlayers*2, 5.0);
	rmSetObjectDefMinDistance(monksID, 5.0);
	rmSetObjectDefMaxDistance(monksID, 10.0);
		rmPlaceObjectDefAtLoc(monksID, 0, 0.5,0.5);

  int triggerCounter = 0; 
  int tempCounter = 0;
  string guardian1Type = "";  
  string guardian2Type = "";  
  string guardian3Type = "";
  string guardian4Type = "";  
  guardian1Type = "DLClegendarybeast1";
  guardian2Type = "DLClegendarybeast2";
  guardian3Type = "DLClegendarybeast3";
  guardian4Type = "ypWokouBlindMonk";
  string guardianDistance = "45.0";	
	

	
	      rmCreateTrigger("GuardianDeath"+triggerCounter);
      rmSwitchToTrigger(rmTriggerID("GuardianDeath"+triggerCounter));
      rmSetTriggerPriority(3); 
      rmSetTriggerActive(true);
      rmSetTriggerRunImmediately(true);
      rmSetTriggerLoop(false);
        
      rmAddTriggerCondition("Units In Area");
      rmSetTriggerConditionParamInt("DstObject", rmGetUnitPlaced(belltowerID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian1Type, false);
      rmSetTriggerConditionParam("Dist", guardianDistance, false);
      rmSetTriggerConditionParam("Op", "<=", false);
      rmSetTriggerConditionParam("Count", "0", false);
	  
      rmAddTriggerCondition("Units In Area");
      rmSetTriggerConditionParamInt("DstObject", rmGetUnitPlaced(belltowerID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian2Type, false);
      rmSetTriggerConditionParam("Dist", guardianDistance, false);
      rmSetTriggerConditionParam("Op", "<=", false);
      rmSetTriggerConditionParam("Count", "0", false);  
	  
      rmAddTriggerCondition("Units In Area");
      rmSetTriggerConditionParamInt("DstObject", rmGetUnitPlaced(belltowerID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian3Type, false);
      rmSetTriggerConditionParam("Dist", guardianDistance, false);
      rmSetTriggerConditionParam("Op", "<=", false);
      rmSetTriggerConditionParam("Count", "0", false);
	  
      rmAddTriggerCondition("Units In Area");
      rmSetTriggerConditionParamInt("DstObject", rmGetUnitPlaced(belltowerID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian4Type, false);
      rmSetTriggerConditionParam("Dist", guardianDistance, false);
      rmSetTriggerConditionParam("Op", "<=", false);
      rmSetTriggerConditionParam("Count", "0", false);  
      
      rmAddTriggerEffect("Unit Action Suspend");
      rmSetTriggerEffectParamInt("SrcObject", rmGetUnitPlaced(belltowerID, triggerCounter), false);
      rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
      rmSetTriggerEffectParam("Suspend", "False", false);
	        rmAddTriggerEffect("Music Play");
      
      rmCreateTrigger("DisableAutoconvert"+triggerCounter);
      rmSwitchToTrigger(rmTriggerID("DisableAutoconvert"+triggerCounter));
      rmSetTriggerPriority(3); 
      rmSetTriggerActive(true);
      rmSetTriggerRunImmediately(true);
      rmSetTriggerLoop(false);
        
      rmAddTriggerCondition("Always");
      
      rmAddTriggerEffect("Unit Action Suspend");
      
      rmSetTriggerEffectParamInt("SrcObject", rmGetUnitPlaced(belltowerID, triggerCounter), false);
      
      rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
      rmSetTriggerEffectParam("Suspend", "True", false);
 
      rmCreateTrigger("PlayThemeMusic");
      rmSwitchToTrigger(rmTriggerID("PlayThemeMusic"));
      rmSetTriggerPriority(3); 
      rmSetTriggerActive(true);
      rmSetTriggerRunImmediately(true);
      rmSetTriggerLoop(false);       
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1", 50);  
		rmAddTriggerEffect("Music Filename"); 
		rmSetTriggerEffectParam("Music", "Wotta\Delta\DLC\EcruteakTheme.mp3"); //Music
        rmSetTriggerEffectParam("Duration", "0", false);
		
		
      rmCreateTrigger("PlayBattleMusicA");
      rmSwitchToTrigger(rmTriggerID("PlayBattleMusicA"));
      rmSetTriggerPriority(3); 
      rmSetTriggerActive(true);
      rmSetTriggerRunImmediately(true);
      rmSetTriggerLoop(false);       

	  rmAddTriggerCondition("Percent Damaged");
      rmSetTriggerConditionParamInt("SrcObject", rmGetUnitPlaced(legendarybeast1ID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian1Type, false);
      rmSetTriggerConditionParam("Op", ">=", false);
      rmSetTriggerConditionParam("Percent", "1", false);
	  
	  rmAddTriggerCondition("Percent Damaged");
      rmSetTriggerConditionParamInt("SrcObject", rmGetUnitPlaced(legendarybeast2ID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian2Type, false);
      rmSetTriggerConditionParam("Op", "==", false);
      rmSetTriggerConditionParam("Percent", "0", false);
	  
	  rmAddTriggerCondition("Percent Damaged");
      rmSetTriggerConditionParamInt("SrcObject", rmGetUnitPlaced(legendarybeast3ID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian3Type, false);
      rmSetTriggerConditionParam("Op", "==", false);
      rmSetTriggerConditionParam("Percent", "0", false);
	  
		rmAddTriggerEffect("Music Filename"); 
		rmSetTriggerEffectParam("Music", "Wotta\Delta\DLC\EcruteakBattleTheme.mp3"); //Music
        rmSetTriggerEffectParam("Duration", "0", false);
		
	      rmCreateTrigger("PlayBattleMusicB");
      rmSwitchToTrigger(rmTriggerID("PlayBattleMusicB"));
      rmSetTriggerPriority(3); 
      rmSetTriggerActive(true);
      rmSetTriggerRunImmediately(true);
      rmSetTriggerLoop(false);       

	  	  rmAddTriggerCondition("Percent Damaged");
      rmSetTriggerConditionParamInt("SrcObject", rmGetUnitPlaced(legendarybeast1ID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian1Type, false);
      rmSetTriggerConditionParam("Op", "==", false);
      rmSetTriggerConditionParam("Percent", "0", false);
	  
	  rmAddTriggerCondition("Percent Damaged");
      rmSetTriggerConditionParamInt("SrcObject", rmGetUnitPlaced(legendarybeast2ID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian2Type, false);
      rmSetTriggerConditionParam("Op", ">=", false);
      rmSetTriggerConditionParam("Percent", "1", false);
	  
	  rmAddTriggerCondition("Percent Damaged");
      rmSetTriggerConditionParamInt("SrcObject", rmGetUnitPlaced(legendarybeast3ID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian3Type, false);
      rmSetTriggerConditionParam("Op", "==", false);
      rmSetTriggerConditionParam("Percent", "0", false);
	  
		rmAddTriggerEffect("Music Filename"); 
		rmSetTriggerEffectParam("Music", "Wotta\Delta\DLC\EcruteakBattleTheme.mp3"); //Music
        rmSetTriggerEffectParam("Duration", "0", false);
		
	      rmCreateTrigger("PlayBattleMusicC");
      rmSwitchToTrigger(rmTriggerID("PlayBattleMusicC"));
      rmSetTriggerPriority(3); 
      rmSetTriggerActive(true);
      rmSetTriggerRunImmediately(true);
      rmSetTriggerLoop(false);       

	  	  rmAddTriggerCondition("Percent Damaged");
      rmSetTriggerConditionParamInt("SrcObject", rmGetUnitPlaced(legendarybeast1ID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian1Type, false);
      rmSetTriggerConditionParam("Op", "==", false);
      rmSetTriggerConditionParam("Percent", "0", false);
	  
	  rmAddTriggerCondition("Percent Damaged");
      rmSetTriggerConditionParamInt("SrcObject", rmGetUnitPlaced(legendarybeast2ID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian2Type, false);
      rmSetTriggerConditionParam("Op", "==", false);
      rmSetTriggerConditionParam("Percent", "0", false);
	  
	  rmAddTriggerCondition("Percent Damaged");
      rmSetTriggerConditionParamInt("SrcObject", rmGetUnitPlaced(legendarybeast3ID, triggerCounter), false);
      rmSetTriggerConditionParam("Player", "0", false);
      rmSetTriggerConditionParam("UnitType", guardian3Type, false);
      rmSetTriggerConditionParam("Op", ">=", false);
      rmSetTriggerConditionParam("Percent", "1", false);
	  
		rmAddTriggerEffect("Music Filename"); 
		rmSetTriggerEffectParam("Music", "Wotta\Delta\DLC\EcruteakBattleTheme.mp3"); //Music
        rmSetTriggerEffectParam("Duration", "0", false);
		

	  
      tempCounter = tempCounter + 2;
	  
	  
	  
	  
	/////////////////////////////// DEFINE STARTING OBJECTS ////////////////////////////////////

   	int craterEdgeConstraint=rmCreatePieConstraint("crater edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.39), rmDegreesToRadians(0), rmDegreesToRadians(360));



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
	rmAddObjectDefConstraint(food1ID, avoidTradeRoute);
  rmAddObjectDefConstraint(food1ID, shortAvoidImportantItem);
  			rmAddObjectDefConstraint(food1ID, avoidBellTower);
	rmAddObjectDefConstraint(food1ID, avoidTradeRouteSocketsShort);
  
  int food2ID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(food2ID, huntable2, rmRandInt(5,8), 5.0);
	rmSetObjectDefCreateHerd(food2ID, true);
	rmSetObjectDefMinDistance(food2ID, 0.0);
	rmSetObjectDefMaxDistance(food2ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food2ID, avoidResource);
	rmAddObjectDefConstraint(food2ID, playerConstraint);
	rmAddObjectDefConstraint(food2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food2ID, avoidHuntable1);
	rmAddObjectDefConstraint(food2ID, avoidHuntable2);
	rmAddObjectDefConstraint(food2ID, avoidTradeRoute);
			rmAddObjectDefConstraint(food2ID, avoidBellTower);
	rmAddObjectDefConstraint(food2ID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(food2ID, avoidTradeRouteSocketsShort);
  
  int startFoodID=rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(startFoodID, huntable3, 6, 4.0);
	rmSetObjectDefMinDistance(startFoodID, 12.0);
	rmSetObjectDefMaxDistance(startFoodID, 18.0);
	rmSetObjectDefCreateHerd(startFoodID, false);
	rmAddObjectDefConstraint(startFoodID, avoidAll);
	rmAddObjectDefConstraint(startFoodID, avoidStartResource);
//	rmAddObjectDefConstraint(startFoodID, avoidHuntable1);    
//	rmAddObjectDefConstraint(startFoodID, avoidHuntable2);    
  rmAddObjectDefConstraint(startFoodID, avoidTradeRoute);
  
  int StartAreaTreeID=rmCreateObjectDef("starting trees red");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 6, 6.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 16);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 22);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartResource);
			rmAddObjectDefConstraint(StartAreaTreeID, redConstraint);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRouteSocketsShort);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRoute);
  
    int StartAreaTree2ID=rmCreateObjectDef("starting trees white");
	rmAddObjectDefItem(StartAreaTree2ID, startTreeType2, 6, 6.0);
	rmSetObjectDefMinDistance(StartAreaTree2ID, 16);
	rmSetObjectDefMaxDistance(StartAreaTree2ID, 22);
	rmAddObjectDefConstraint(StartAreaTree2ID, avoidAll);
		rmAddObjectDefConstraint(StartAreaTree2ID, whiteConstraint);
	rmAddObjectDefConstraint(StartAreaTree2ID, avoidStartResource);
	rmAddObjectDefConstraint(StartAreaTree2ID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(StartAreaTree2ID, avoidTradeRouteSocketsShort);
  rmAddObjectDefConstraint(StartAreaTree2ID, avoidTradeRoute);

	int StartBerriesID=rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(StartBerriesID, "BerryBush", 6, 5.0);
	rmSetObjectDefMinDistance(StartBerriesID, 10);
	rmSetObjectDefMaxDistance(StartBerriesID, 15);
	rmAddObjectDefConstraint(StartBerriesID, avoidAll);
	rmAddObjectDefConstraint(StartBerriesID, avoidStartResource);
	rmAddObjectDefConstraint(StartBerriesID, shortAvoidImpassableLand);
//	rmAddObjectDefConstraint(StartBerriesID, shortPlayerConstraint);
//  rmAddObjectDefConstraint(StartBerriesID, avoidTradeRoute);

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
		rmAddAreaConstraint(startingUnits, craterEdgeConstraint);

		
 
   
/////////////////////////////// DEFINE PLAYERS ////////////////////////////////////


  // Players
    
		// Misc variables for use later

  int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
  bool weird = false;

  // FFA and imbalanced teams
  if ( cNumberTeams > 2 || ((teamZeroCount - teamOneCount) > 2) || ((teamOneCount - teamZeroCount) > 2) )
    weird = true;
  
  rmEchoInfo("weird = "+weird);
  
  
  float teamSide = rmRandFloat(0, 1);
  // teamSide = 0;
  
  if (weird == false) {
    
    if(teamSide > .5) {
      if(cNumberNonGaiaPlayers > 7) { 
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.45, .8);
        rmPlacePlayersCircular(.32, .32, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.95, .3);
        rmPlacePlayersCircular(.32, .32, 0);
      }
      
      else if(cNumberNonGaiaPlayers > 5) {
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.50, .75);
        rmPlacePlayersCircular(.32, .32, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.00, .25);
        rmPlacePlayersCircular(.32, .32, 0);
      }
      
      else if(cNumberNonGaiaPlayers > 2) {
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.5, .75);
        rmPlacePlayersCircular(.32, .32, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.0, .25);
        rmPlacePlayersCircular(.32, .32, 0);
        
      }
      
      else {
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.61, .62);
        rmPlacePlayersCircular(.32, .32, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.12, .13);
        rmPlacePlayersCircular(.32, .32, 0);
      }
    }
   



   
    else {
      if(cNumberNonGaiaPlayers > 7) { 
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.45, .8);
        rmPlacePlayersCircular(.32, .32, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.95, .3);
        rmPlacePlayersCircular(.32, .32, 0);
      }
      
      else if(cNumberNonGaiaPlayers > 5) {
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.5, .75);
        rmPlacePlayersCircular(.32, .32, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(1, .25);
        rmPlacePlayersCircular(.32, .32, 0);
      }
      
      else if(cNumberNonGaiaPlayers > 2) {
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.5, .75);
        rmPlacePlayersCircular(.32, .32, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.0, .25);
        rmPlacePlayersCircular(.32, .32, 0);
        
      }
      
      else {
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.61, .62);
        rmPlacePlayersCircular(.32, .32, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.12, .13);
        rmPlacePlayersCircular(.32, .32, 0);
      }
    }
  }
  
  // ffa
  else {
    rmSetTeamSpacingModifier(0.5);
    rmPlacePlayersCircular(.32, .32, 0.1);
  }
  
  
  // Set up player areas.
	float playerFraction=rmAreaTilesToFraction(500 + cNumberNonGaiaPlayers*150);
  for(i=1; <cNumberPlayers) {
	  
	  
	  
	      int BridgeToCenter=rmCreateArea("Circles"+i);
    rmSetPlayerArea(i, BridgeToCenter);
    rmSetAreaSize(BridgeToCenter, playerFraction*2, playerFraction*2);
	rmAddAreaToClass(BridgeToCenter, rmClassID("classPath"));
	
	
    int id=rmCreateArea("Player"+i);
    rmSetPlayerArea(i, id);
    rmSetAreaSize(id, playerFraction, playerFraction);
    rmAddAreaToClass(id, classPlayer);
    rmSetAreaCoherence(id, 1);
    rmAddAreaConstraint(id, avoidTradeRouteSockets); 
    rmAddAreaConstraint(id, shortAvoidTradeRoute); 
    rmAddAreaConstraint(id, shortAvoidImportantItem); 
//    rmAddAreaConstraint(id, playerConstraint); 
    rmAddAreaConstraint(id, playerEdgeConstraint); 
	
    rmSetAreaLocPlayer(id, i);
    rmSetAreaWarnFailure(id, true);
 
 }



  
 

		// Build the areas.
  rmBuildAllAreas();
  
/////////////////////////////// PLACE PLAYERS ////////////////////////////////////

  // starting resources

  int startingTCID= rmCreateObjectDef("startingTC");
	if (rmGetNomadStart()) {
			rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 0.0);
  }
		
  else {
    rmAddObjectDefItem(startingTCID, "townCenter", 1, 0.0);
  }

  rmSetObjectDefMinDistance(startingTCID, 5);
	rmSetObjectDefMaxDistance(startingTCID, 10);
	rmAddObjectDefConstraint(startingTCID, avoidImpassableLand);
  rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);
	rmAddObjectDefToClass(startingTCID, rmClassID("player"));

   // Text
   rmSetStatusText("",0.35);
  
  rmClearClosestPointConstraints();

	for(i=1; < cNumberPlayers) {
		int placedTC = rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLocation=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(startSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
				rmPlaceObjectDefAtLoc(StartAreaTree2ID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));

    // Food
		rmPlaceObjectDefAtLoc(StartBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    rmPlaceObjectDefAtLoc(startFoodID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    
    // Place a nugget for the player
    rmSetNuggetDifficulty(1, 1);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
 
		// Place water spawn points for the players along with a canoe
		
	int waterSpawnPointID = 0;
	
		waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 10.0);
		rmAddClosestPointConstraint(flagVsFlag);
		rmAddClosestPointConstraint(flagLand);
//    rmAddClosestPointConstraint(flagEdgeConstraint);
		vector closestPoint = rmFindClosestPointVector(TCLocation, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
     
//    int catamaranID=rmCreateObjectDef("Catamaran"+i);
//    rmAddObjectDefItem(catamaranID, "fishingboat", 2, 0.0);
//    rmPlaceObjectDefAtLoc(catamaranID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
	
    rmClearClosestPointConstraints();
  }
	

	
	/////////////////////////////// FORESTS ////////////////////////////////////


	// Scattered FORESTS
   int forestTreeID = 0;
   numTries=6*cNumberNonGaiaPlayers;
   int failCount=0;

   for (i=0; <numTries)
      {   
         int whiteforest=rmCreateArea("whiteforest "+i);
         rmSetAreaWarnFailure(whiteforest, false);
         rmSetAreaSize(whiteforest, rmAreaTilesToFraction(500), rmAreaTilesToFraction(500));
         rmSetAreaForestType(whiteforest, "Ecruteak White Forest");
         rmSetAreaForestDensity(whiteforest, 0.8);
         rmSetAreaForestClumpiness(whiteforest, 0.4);
         rmSetAreaForestUnderbrush(whiteforest, 0.3);
         rmSetAreaMinBlobs(whiteforest, 2);
         rmSetAreaMaxBlobs(whiteforest, 4);
         rmSetAreaMinBlobDistance(whiteforest, 16.0);
         rmSetAreaMaxBlobDistance(whiteforest, 40.0);
         rmSetAreaCoherence(whiteforest, 0.7);
         rmSetAreaSmoothDistance(whiteforest, 10);
         rmAddAreaToClass(whiteforest, rmClassID("classForest")); 
        rmAddAreaConstraint(whiteforest, forestConstraint);
         rmAddAreaConstraint(whiteforest, avoidAll);
//         rmAddAreaConstraint(whiteforest, avoidWater2); 
		 rmAddAreaConstraint(whiteforest, avoidTC);
		 		 rmAddAreaConstraint(whiteforest, whiteConstraint);
		 		 rmAddAreaConstraint(whiteforest, avoidCenter);
		 rmAddAreaConstraint(whiteforest, playerConstraint);
		 rmAddAreaConstraint(whiteforest, avoidCW);
         rmAddAreaConstraint(whiteforest, shortAvoidTradeRoute); 
         rmAddAreaConstraint(whiteforest, avoidTradeRouteSocketsShort); 
         if(rmBuildArea(whiteforest)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount++;
            if(failCount==5)
               break;
         }
         else
            failCount=0; 
      } 
	
   for (i=0; <numTries)
      {   
         int redforest=rmCreateArea("redforest "+i);
         rmSetAreaWarnFailure(redforest, false);
         rmSetAreaSize(redforest, rmAreaTilesToFraction(500), rmAreaTilesToFraction(500));
         rmSetAreaForestType(redforest, "Ecruteak red Forest");
         rmSetAreaForestDensity(redforest, 0.8);
         rmSetAreaForestClumpiness(redforest, 0.4);
         rmSetAreaForestUnderbrush(redforest, 0.1);
         rmSetAreaMinBlobs(redforest, 2);
         rmSetAreaMaxBlobs(redforest, 4);
         rmSetAreaMinBlobDistance(redforest, 16.0);
         rmSetAreaMaxBlobDistance(redforest, 40.0);
         rmSetAreaCoherence(redforest, 0.7);
         rmSetAreaSmoothDistance(redforest, 10);
         rmAddAreaToClass(redforest, rmClassID("classForest")); 
        rmAddAreaConstraint(redforest, forestConstraint);
         rmAddAreaConstraint(redforest, avoidAll);
//         rmAddAreaConstraint(redforest, avoidWater2); 
		 rmAddAreaConstraint(redforest, avoidTC);
		 		 rmAddAreaConstraint(redforest, redConstraint);
		 		 rmAddAreaConstraint(redforest, avoidCenter);
		 rmAddAreaConstraint(redforest, playerConstraint);
		 rmAddAreaConstraint(redforest, avoidCW);
         rmAddAreaConstraint(redforest, shortAvoidTradeRoute); 
         rmAddAreaConstraint(redforest, avoidTradeRouteSocketsShort); 
         if(rmBuildArea(redforest)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount++;
            if(failCount==5)
               break;
         }
         else
            failCount=0; 
      } 

   for (i=0; <numTries)
      {   
         int greenforest=rmCreateArea("greenforest "+i);
         rmSetAreaWarnFailure(greenforest, false);
         rmSetAreaSize(greenforest, rmAreaTilesToFraction(500), rmAreaTilesToFraction(500));
         rmSetAreaForestType(greenforest, "Ecruteak green Forest");
         rmSetAreaForestDensity(greenforest, 0.4);
         rmSetAreaForestClumpiness(greenforest, 0.4);
         rmSetAreaForestUnderbrush(greenforest, 0.1);
         rmSetAreaMinBlobs(greenforest, 2);
         rmSetAreaMaxBlobs(greenforest, 4);
         rmSetAreaMinBlobDistance(greenforest, 16.0);
         rmSetAreaMaxBlobDistance(greenforest, 40.0);
         rmSetAreaCoherence(greenforest, 0.7);
         rmSetAreaSmoothDistance(greenforest, 10);
         rmAddAreaToClass(greenforest, rmClassID("classForest")); 
        rmAddAreaConstraint(greenforest, forestConstraint);
         rmAddAreaConstraint(greenforest, avoidAll);
//         rmAddAreaConstraint(greenforest, avoidWater2); 
		 rmAddAreaConstraint(greenforest, avoidTC);
		 		 rmAddAreaConstraint(greenforest, avoidColors);
		 rmAddAreaConstraint(greenforest, playerConstraint);
		 rmAddAreaConstraint(greenforest, avoidCW);
		 rmAddAreaConstraint(greenforest, avoidBellTower);		 
         rmAddAreaConstraint(greenforest, shortAvoidTradeRoute); 
         rmAddAreaConstraint(greenforest, avoidTradeRouteSocketsShort); 
         if(rmBuildArea(greenforest)==false)
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

  int playerConstraintNugget=rmCreateClassDistanceConstraint("stay away from players far", classPlayer, 55.0);
  int avoidNuggetsShort=rmCreateTypeDistanceConstraint("vs nugget short", "AbstractNugget", 10.0);
    int avoidNuggets=rmCreateTypeDistanceConstraint("nugget vs. nugget", "AbstractNugget", 50.0);
	int avoidNuggetFar=rmCreateTypeDistanceConstraint("nugget vs. nugget far", "AbstractNugget", 70.0);
	
  int nugget4= rmCreateObjectDef("nugget nuts"); 
  rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(4, 4);
  rmSetObjectDefMinDistance(nugget4, 0.0);
  rmSetObjectDefMaxDistance(nugget4, rmXFractionToMeters(0.2));
  rmAddObjectDefConstraint(nugget4, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget4, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget4, avoidResource);
  rmAddObjectDefConstraint(nugget4, avoidNuggets);
  rmAddObjectDefConstraint(nugget4, avoidBellTower);
  rmAddObjectDefConstraint(nugget4, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget4, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget4, playerConstraintNugget);
//  rmAddObjectDefConstraint(nugget4, circleConstraint);
  rmPlaceObjectDefAtLoc(nugget4, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

  int nugget3= rmCreateObjectDef("nugget hard"); 
  rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(3, 3);
  rmSetObjectDefMinDistance(nugget3, 0.0);
  rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.2));
  rmAddObjectDefConstraint(nugget3, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget3, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget3, avoidResource);
  rmAddObjectDefConstraint(nugget3, avoidBellTower);
  rmAddObjectDefConstraint(nugget3, avoidNuggets);
  rmAddObjectDefConstraint(nugget3, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget3, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget3, playerConstraintNugget);
//  rmAddObjectDefConstraint(nugget3, circleConstraint);
  rmPlaceObjectDefAtLoc(nugget3, 0, 0.5, 0.5, cNumberNonGaiaPlayers+rmRandInt(1,1));

  int nugget2= rmCreateObjectDef("nugget medium"); 
  rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(2, 2);
  rmAddObjectDefConstraint(nugget2, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget2, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget2, avoidResource);
  rmAddObjectDefConstraint(nugget2, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget2, avoidBellTower);
  rmAddObjectDefConstraint(nugget2, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget2, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget2, playerConstraintNugget);
//  rmAddObjectDefConstraint(nugget2, circleConstraint);
  rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.25));
  rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.3));
  rmPlaceObjectDefAtLoc(nugget2, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

  int nugget1= rmCreateObjectDef("nugget easy"); 
  rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(1, 1);
  rmAddObjectDefConstraint(nugget1, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget1, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget1, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget1, avoidBellTower);
  rmAddObjectDefConstraint(nugget1, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget1, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget1, playerConstraint);
//  rmAddObjectDefConstraint(nugget1, circleConstraint);
  rmSetObjectDefMinDistance(nugget1, rmXFractionToMeters(0.3));
  rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.4));
  rmPlaceObjectDefAtLoc(nugget1, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);


  
	
		/////////////////////////////// PLACE FISH ////////////////////////////////////	
	
	int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 20.0);	
	int avoidFish2=rmCreateTypeDistanceConstraint("fish v fish2", fish2, 15.0);

	
	// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------

	int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, fish1, 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, fishVsWhaleID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers);

	int fish2ID=rmCreateObjectDef("fish 2");
	rmAddObjectDefItem(fish2ID, fish2, 1, 0.0);
	rmSetObjectDefMinDistance(fish2ID, 0.0);
	rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fish2ID, avoidFish2);
	rmAddObjectDefConstraint(fish2ID, fishVsWhaleID);
	rmAddObjectDefConstraint(fish2ID, fishLand);
	rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 12*cNumberNonGaiaPlayers);

	if (cNumberNonGaiaPlayers <5)		// If less than 5 players, place extra fish.
	{
		rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);	
	}
	
	/////////////////////////////// MINES ////////////////////////////////////


	// Silver

	int silverID = -1;
 	int silverID2 = -1;
 	int silverID3 = -1;
	
	int avoidSilver=rmCreateTypeDistanceConstraint("avoid silver", "mine", 75.0);
	int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "minegold", 75.0);
	int shortAvoidTradeRouteMines = rmCreateTradeRouteDistanceConstraint("short trade route", 6.0);

  int silverCount = 0;
  
  silverCount = cNumberNonGaiaPlayers*1.5;
  
	rmEchoInfo("silver count = "+silverCount);


  // mines on red
  silverID2 = rmCreateObjectDef("red mines"+i);
  rmAddObjectDefItem(silverID2, "minegold", 1, 0.0);
  rmSetObjectDefMinDistance(silverID2, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(silverID2, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(silverID2, avoidImpassableLand);
  rmAddObjectDefConstraint(silverID2, avoidSilver);
  rmAddObjectDefConstraint(silverID2, avoidGold);
  rmAddObjectDefConstraint(silverID2, playerConstraint);
  rmAddObjectDefConstraint(silverID2, redConstraint);
  rmAddObjectDefConstraint(silverID2, avoidCenter);
  rmAddObjectDefConstraint(silverID2, shortAvoidTradeRouteMines);
  rmAddObjectDefConstraint(silverID2, shortAvoidImportantItem);
  rmAddObjectDefConstraint(silverID2, avoidTradeRouteSocketsShort);
  rmPlaceObjectDefAtLoc(silverID2, 0, 0.5, 0.5, silverCount);
  
  // mines on white
  silverID = rmCreateObjectDef("white mines"+i);
  rmAddObjectDefItem(silverID, "minegold", 1, 0.0);
  rmSetObjectDefMinDistance(silverID, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(silverID, avoidImpassableLand);
  rmAddObjectDefConstraint(silverID, avoidSilver);
  rmAddObjectDefConstraint(silverID, avoidGold);
  rmAddObjectDefConstraint(silverID, playerConstraint);
  rmAddObjectDefConstraint(silverID, whiteConstraint);
  rmAddObjectDefConstraint(silverID, avoidCenter);
  rmAddObjectDefConstraint(silverID, shortAvoidTradeRouteMines);
  rmAddObjectDefConstraint(silverID, shortAvoidImportantItem);
  rmAddObjectDefConstraint(silverID, avoidTradeRouteSocketsShort);
  rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5, silverCount);
  
    // mines on green
  silverID3 = rmCreateObjectDef("green mines"+i);
  rmAddObjectDefItem(silverID3, "minegold", 1, 0.0);
  rmSetObjectDefMinDistance(silverID3, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(silverID3, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(silverID3, avoidImpassableLand);
  rmAddObjectDefConstraint(silverID3, avoidSilver);
  rmAddObjectDefConstraint(silverID3, avoidResource);
  rmAddObjectDefConstraint(silverID3, playerConstraint);
  rmAddObjectDefConstraint(silverID3, avoidColors);
  rmAddObjectDefConstraint(silverID3, avoidAll);
  rmAddObjectDefConstraint(silverID3, shortAvoidImportantItem);
  rmAddObjectDefConstraint(silverID3, avoidTradeRouteSocketsShort);
  rmPlaceObjectDefAtLoc(silverID3, 0, 0.5, 0.5, 5);

	  /////////////////////////////// HUNTABLES ////////////////////////////////////

  rmPlaceObjectDefAtLoc(food1ID, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
  rmPlaceObjectDefAtLoc(food2ID, 0, 0.5, 0.5, 3.0*cNumberNonGaiaPlayers);


  // King of the Hill (added 2026-11 for WoL): the land farthest from every Town Center (the centre button of the map is an island)
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
