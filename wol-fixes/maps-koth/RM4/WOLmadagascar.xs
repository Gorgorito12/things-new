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
	int playerTiles=22000;
	if (cNumberNonGaiaPlayers >4)   // If more than 4 players...
		playerTiles = 18000;		// ...give this many tiles per player.
	if (cNumberNonGaiaPlayers >7)	// If more than 7 players...
		playerTiles = 20000;		// ...give this many tiles per player.	
	int size=2.7*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Set up default water type.
	rmSetSeaLevel(1.0);          
	rmSetSeaType("Yucatan Coast");
	rmSetBaseTerrainMix("andes_dirt_a");
	rmSetMapType("madagascar");
	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetLightingSet("paris_day");

	// Initialize map.
	rmTerrainInitialize("water");

	// Misc variables for use later
	int numTries = -1;

	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("classSocket");
	rmDefineClass("canyon");

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);

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

	// Bonus area constraint.  
	int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 55.0);

	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fishMahi", 25.0);			// was 50.0
	// int fishVsFishTarponID=rmCreateTypeDistanceConstraint("fish v fish2", "fishTarpon", 20.0);  // was 40.0 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 2.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "HumpbackWhale", 40.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 17.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
int avoidNuggetWater=rmCreateTypeDistanceConstraint("nugget vs. nugget water", "AbstractNugget", 80.0);
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
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random turkeys", "turkey", 50.0);	//Attempting to spread them out more evenly.
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 54.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 120.0);  //Added sheep 11-28-05 JSB

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 14.0);  //This one is used in one place: for helping place FFA TC's better.

  // Cardinal Directions Constraints (handy!)
   int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));
   int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
   int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
   int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));

	// Constraint to avoid water.
	int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);   //I added this one so I could experiment with it.
	int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 8.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);  //Added this one too.
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 18.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25); //Was 15, but made larger so ships don't sometimes stomp each other when arriving from HC.
	rmAddClosestPointConstraint(avoidWater8);  //was originally 8
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
	int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("classSocket"), 10.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);

	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  (It excludes the west bay, where I do not want the flags.)
	int circleConstraint=rmCreatePieConstraint("semi-circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(50), rmDegreesToRadians(290));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

	// int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);

   int IslandLoc = 1;								

	// Make one big island.  
	int bigIslandID=rmCreateArea("big lone island");
	rmSetAreaSize(bigIslandID, 0.33, 0.33);
	rmSetAreaLocation(bigIslandID, 0.5, 0.5);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(bigIslandID, 0.8);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(bigIslandID, 2.0);
	rmSetAreaSmoothDistance(bigIslandID, 20);
	rmSetAreaMix(bigIslandID, "andes_grass_b");
	rmAddAreaToClass(bigIslandID, classIsland);
	rmAddAreaConstraint(bigIslandID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID, true);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 4.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmSetAreaElevationOctaves(bigIslandID, 3);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);
	rmAddAreaInfluenceSegment(bigIslandID, 0.78, 0.68, 0.23, 0.33);  //Segment 1 - short top, left, right. // .69, .68, .76, .51
	rmAddAreaInfluenceSegment(bigIslandID, 0.45, 0.7, 0.5, 0.4);  //Segment 2 - long top  // last # was .56, .78, .75, .285 // -- Changed 3-10-06
	rmAddAreaInfluenceSegment(bigIslandID, 0.35, 0.5, 0.45, 0.35);  //Segment 3 - long lower // last # was .22, .67, .58, .20 // -- Changed 3-10-06
	rmAddAreaInfluenceSegment(bigIslandID, 0.17, 0.47, 0.35, 0.25);  //Segment 4 - short lower bit // last was .20, .44, .36, .21
	rmSetStatusText("",0.40);
	rmSetAreaWarnFailure(bigIslandID, false);
	rmBuildArea(bigIslandID);

	int gulfID=rmCreateArea("gulf");
rmSetAreaSize(gulfID, 0.13, 0.13);
rmSetAreaCoherence(gulfID, 0.9);
rmSetAreaWaterType(gulfID, "Yucatan Coast");
rmSetAreaLocation(gulfID, 0.75, 0.96);
rmSetAreaWarnFailure(gulfID, false);
rmBuildArea(gulfID);


    // Set up player areas.  -- Each team always placed along a line.  One team in NE, other in SW.
	
	float teamStartLoc = rmRandFloat(0.0, 1.0);  //This chooses a number randomly between 0 and 1, used to pick whether team 1 is on top or bottom.
	//float teamStartLoc = rmRandFloat(0.2, 0.4);    //Temporarily force float to be .4 or lower, so Team 0 will be in the North.

// Players

if (cNumberTeams == 2 )
{  
  float teamSide = rmRandInt(0, 1);
if(teamSide > .5) 
{
        rmSetPlacementTeam(1);
rmPlacePlayersLine(0.55, 0.7, 0.15, 0.4, 0.05, 0.1);
        rmSetPlacementTeam(0);
rmPlacePlayersLine(0.85, 0.65, 0.35, 0.2, 0.05, 0.1);
}

else
        rmSetPlacementTeam(0);
rmPlacePlayersLine(0.55, 0.7, 0.15, 0.4, 0.05, 0.1);
        rmSetPlacementTeam(1);
rmPlacePlayersLine(0.85, 0.65, 0.35, 0.2, 0.05, 0.1);
}
		else
rmPlacePlayersLine(0.85, 0.65, 0.15, 0.4, 0.05, 0.1);



	float playerFraction=rmAreaTilesToFraction(100);
	for(i=1; <cNumberPlayers)
	{
      // Create the Player's area.
      int id=rmCreateArea("Player"+i);
      rmSetPlayerArea(i, id);
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 1);
      rmSetAreaLocPlayer(id, i);
      rmSetAreaWarnFailure(id, false);
	}

	// Build the areas. 
	rmBuildAllAreas();

   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);

	// Clear out constraints for good measure.
    rmClearClosestPointConstraints();   //This was in the Caribbean script I started with.  Not sure what it does so afraid to axe it.

	// *****************NATIVES****************************************************************************
 

  // choose AURs - use for Tribal Theme
    string aur_type = "tribal";
    int resourcesarray = xsArrayCreateString(16, "", "");

    xsArraySetString(resourcesarray, 1, "cattle");
    xsArraySetString(resourcesarray, 2, "cocoa");
    xsArraySetString(resourcesarray, 3, "diamonds");
    xsArraySetString(resourcesarray, 4, "timber");
    xsArraySetString(resourcesarray, 5, "gems");
    xsArraySetString(resourcesarray, 6, "gold");
    xsArraySetString(resourcesarray, 7, "manioc");
    xsArraySetString(resourcesarray, 8, "palmoil");
    xsArraySetString(resourcesarray, 9, "rubber");
    xsArraySetString(resourcesarray, 10, "slaves");
    xsArraySetString(resourcesarray, 11, "figurines");
    xsArraySetString(resourcesarray, 12, "textiles");
    xsArraySetString(resourcesarray, 13, "treasures");
    xsArraySetString(resourcesarray, 14, "vanilla");
    xsArraySetString(resourcesarray, 15, "gems");
    xsArraySetString(resourcesarray, 16, "timber");

    rmAllocateSubCivs(3);

    string subCiv0Name = "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 14));
    int subCiv0 = rmGetCivID(subCiv0Name);
    rmSetSubCiv(0, subCiv0Name); 

    string subCiv1Name = "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 14));
    int subCiv1 = rmGetCivID(subCiv1Name);
    rmSetSubCiv(1, subCiv1Name); 

    string subCiv2Name = "AUR"+xsArrayGetString(resourcesarray, rmRandInt(14, 16));
    int subCiv2 = rmGetCivID(subCiv2Name);
    rmSetSubCiv(2, subCiv2Name); 

    string subCiv3Name = "AUR"+xsArrayGetString(resourcesarray, rmRandInt(12, 16));
    int subCiv3 = rmGetCivID(subCiv3Name);
    rmSetSubCiv(3, subCiv3Name); 

    //int classNatives = rmDefineClass("natives"); // Pierre Jean: the debugger sees this as error
    int avoidNatives = rmCreateClassDistanceConstraint("avoid Natives", rmClassID("natives"), 30.0);



   // *****************MOUNTAIN IN CENTER**************************************
   // Always create a mountain in center of island.
   // Really big mountain for 8 players, big mountain for 6 or 7 players, and small mountain for 5 or less players.

		int smallCliffHeight=rmRandInt(0,10);
		int smallMesaID=rmCreateArea("small mesa"+i);
		rmSetAreaSize(smallMesaID, 0.04, 0.04);
		rmSetAreaWarnFailure(smallMesaID, false);
		rmSetAreaCliffType(smallMesaID, "Amazon");
		rmAddAreaToClass(smallMesaID, rmClassID("canyon"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(smallMesaID, 2, 0.3, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(smallMesaID, rmRandInt(6, 8), 1.0, 1.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(smallMesaID, 0.6);
		rmSetAreaLocation(smallMesaID, 0.55, 0.39); 
		rmAddAreaInfluenceSegment(smallMesaID, 0.75, 0.65, 0.20, 0.27);
		rmBuildArea(smallMesaID);


	// Special AREA CONSTRAINTS and use it to make resources avoid the mountain in center:
		int smallMesaConstraint = rmCreateAreaDistanceConstraint("avoid Small Mesa", smallMesaID, 4.0);
		
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.60);

	//***************** PLAYER STARTING STUFF **********************************
	//Place player TCs and starting Gold Mines. 

	int TCID = rmCreateObjectDef("player TC");
	if ( rmGetNomadStart())
		rmAddObjectDefItem(TCID, "coveredWagon", 1, 0);
	else
		rmAddObjectDefItem(TCID, "townCenter", 1, 0);

	//Prepare to place TCs
	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, 12.0);  // Originally 10.0 -- JSB -- Allows TC placement spot to float a bit along the lines I tell them to place. 
	rmAddObjectDefConstraint(TCID, avoidImpassableLand);
	rmAddObjectDefConstraint(TCID, avoidTC);
	rmAddObjectDefConstraint(TCID, avoidCW);
    	
	//Prepare to place Explorers, Explorer's dog, Explorer's Taun Taun, etc.
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 9.0);
	rmSetObjectDefMaxDistance(startingUnits, 18.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);

	//Prepare to place player starting Mines 
	int playerGoldID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(playerGoldID, "MineSapphire", 1, 0);
	rmSetObjectDefMinDistance(playerGoldID, 12.0);
	rmSetObjectDefMaxDistance(playerGoldID, 20.0);
	rmAddObjectDefConstraint(playerGoldID, avoidAll);
    rmAddObjectDefConstraint(playerGoldID, avoidImpassableLand);

	//Prepare to place player starting Crates (mostly food)
	int playerCrateID=rmCreateObjectDef("starting crates");
	rmAddObjectDefItem(playerCrateID, "crateOfFood", rmRandInt(3,4), 4.0);
	rmAddObjectDefItem(playerCrateID, "crateOfWood", 1, 6.0);
	rmAddObjectDefItem(playerCrateID, "crateOfCoin", 1, 7.0);
	rmSetObjectDefMinDistance(playerCrateID, 6);
	rmSetObjectDefMaxDistance(playerCrateID, 10);
	rmAddObjectDefConstraint(playerCrateID, avoidAll);
	rmAddObjectDefConstraint(playerCrateID, shortAvoidImpassableLand);

	//Prepare to place player starting Berries
	int playerBerriesID=rmCreateObjectDef("player berries");
	rmAddObjectDefItem(playerBerriesID, "BananaBush", rmRandInt(4,6), 4.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerBerriesID, 21);
    rmSetObjectDefMaxDistance(playerBerriesID, 26);		
	rmAddObjectDefConstraint(playerBerriesID, avoidAll);
    rmAddObjectDefConstraint(playerBerriesID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerBerriesID, true);

	//Prepare to place player starting Turkeys
	int playerTurkeyID=rmCreateObjectDef("player turkeys");
    rmAddObjectDefItem(playerTurkeyID, "ElephantBird", rmRandInt(1,4), 10.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerTurkeyID, 14);
	rmSetObjectDefMaxDistance(playerTurkeyID, 19);	
	rmAddObjectDefConstraint(playerTurkeyID, avoidAll);
    rmAddObjectDefConstraint(playerTurkeyID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerTurkeyID, true);

	//Prepare to place player starting trees
	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "ypTreeCeylon", 1, 0.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);    //This was just added to try to keep these trees from stomping on CW's.
	rmSetObjectDefMinDistance(StartAreaTreeID, 13.0);	//changed from 12.0 
	rmSetObjectDefMaxDistance(StartAreaTreeID, 20.0);	//Changed from 19.0

	int waterSpawnPointID = 0;

	// --------------- Make load bar move. ----------------------------------------------------------------------------`
	rmSetStatusText("",0.70);
   
	// *********** Place Home City Water Spawn Flag ***************************************************

	for(i=1; <cNumberPlayers)
   {
	    // Place TC and starting units
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));   
		rmPlaceObjectDefAtLoc(playerBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 
		rmPlaceObjectDefAtLoc(playerTurkeyID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));  										
		rmPlaceObjectDefAtLoc(playerCrateID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		// Place player starting trees
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		// Place water spawn points for the players
		waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 10.0);  // ...Flag", 1, 1.0); - the first number is the number of flags.  The next number is the float distance.
		rmAddClosestPointConstraint(flagVsFlag);
		rmAddClosestPointConstraint(flagLand);
		rmAddClosestPointConstraint(circleConstraint);
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
		rmClearClosestPointConstraints();
   }
	
   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.75);

	//rmClearClosestPointConstraints();

 int aurSettlementA = rmCreateGrouping("aur village A", subCiv0Name+" "+aur_type+" "+rmRandInt(1, 3));
    rmSetGroupingMinDistance(aurSettlementA, 0.0);
    rmSetGroupingMaxDistance(aurSettlementA, rmXFractionToMeters(0.1));
    rmAddGroupingConstraint(aurSettlementA, avoidImpassableLand);
    rmAddGroupingToClass(aurSettlementA, rmClassID("importantItem"));
    rmAddGroupingToClass(aurSettlementA, rmClassID("natives"));
    rmAddGroupingConstraint(aurSettlementA, avoidSocket);
    rmAddGroupingConstraint(aurSettlementA, avoidTradeRoute);
    rmAddGroupingConstraint(aurSettlementA, avoidImportantItem);
    rmAddGroupingConstraint(aurSettlementA, avoidNatives);
rmPlaceGroupingInArea(aurSettlementA, 0, bigIslandID, 1);


    int aurSettlementB = rmCreateGrouping("aur village B", subCiv1Name+" "+aur_type+" "+rmRandInt(1, 3));
    rmSetGroupingMinDistance(aurSettlementB, 0.0);
    rmSetGroupingMaxDistance(aurSettlementB, rmXFractionToMeters(0.1));
    rmAddGroupingConstraint(aurSettlementB, avoidImpassableLand);
    rmAddGroupingToClass(aurSettlementB, rmClassID("importantItem"));
    rmAddGroupingToClass(aurSettlementB, rmClassID("natives"));
    rmAddGroupingConstraint(aurSettlementB, avoidSocket);
    rmAddGroupingConstraint(aurSettlementB, avoidTradeRoute);
    rmAddGroupingConstraint(aurSettlementB, avoidImportantItem);
    rmAddGroupingConstraint(aurSettlementB, avoidNatives);
rmPlaceGroupingInArea(aurSettlementB, 0, bigIslandID, 1);

    int aurSettlementC = rmCreateGrouping("aur village C", subCiv2Name+" "+aur_type+" "+rmRandInt(1, 3));
    rmSetGroupingMinDistance(aurSettlementC, 0.0);
    rmSetGroupingMaxDistance(aurSettlementC, rmXFractionToMeters(0.1));
    rmAddGroupingToClass(aurSettlementC, rmClassID("importantItem"));
    rmAddGroupingToClass(aurSettlementC, rmClassID("natives"));
    rmAddGroupingConstraint(aurSettlementC, avoidSocket);
    rmAddGroupingConstraint(aurSettlementC, avoidTradeRoute);
    rmAddGroupingConstraint(aurSettlementC, avoidImportantItem);
    rmAddGroupingConstraint(aurSettlementC, avoidNatives);
rmPlaceGroupingInArea(aurSettlementC, 0, bigIslandID, 1);

    /*
	Strangely, the debugger sees this as error. Cannot determine why though
	int aurSettlementD = rmCreateGrouping("aur village D", subCiv3Name+" "+aur_type+" "+rmRandInt(1, 3));
    rmSetGroupingMinDistance(aurSettlementD, 0.0);
    rmSetGroupingMaxDistance(aurSettlementD, rmXFractionToMeters(0.1));
    rmAddGroupingToClass(aurSettlementD, rmClassID("importantItem"));
    rmAddGroupingToClass(aurSettlementD, rmClassID("natives"));
    rmAddGroupingConstraint(aurSettlementD, avoidSocket);
    rmAddGroupingConstraint(aurSettlementD, avoidTradeRoute);
    rmAddGroupingConstraint(aurSettlementD, avoidImportantItem);
    rmAddGroupingConstraint(aurSettlementD, avoidNatives);
rmPlaceGroupingInArea(aurSettlementD, 0, bigIslandID, 1);*/

    int Tsingy = rmCreateGrouping("Tsingy", "Tsingy "+rmRandInt(1, 4));
    rmSetGroupingMinDistance(Tsingy, 0.0);
    rmSetGroupingMaxDistance(Tsingy, rmXFractionToMeters(0.1));
    rmAddGroupingConstraint(Tsingy, avoidImpassableLand);
    rmAddGroupingToClass(Tsingy, rmClassID("importantItem"));
    rmAddGroupingToClass(Tsingy, rmClassID("natives"));
    rmAddGroupingConstraint(Tsingy, avoidSocket);
    rmAddGroupingConstraint(Tsingy, avoidTradeRoute);
    rmAddGroupingConstraint(Tsingy, avoidImportantItem);
    rmAddGroupingConstraint(Tsingy, avoidNatives);
    rmPlaceGroupingInArea(Tsingy, 0, bigIslandID, cNumberNonGaiaPlayers);	


	// ***************** SCATTERED RESOURCES **************************************
	// Scattered FORESTS
   int forestTreeID = 0;
   numTries=10*cNumberNonGaiaPlayers;
   int failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(450), rmAreaTilesToFraction(550));
         rmSetAreaForestType(forest, "Madagascar Rainforest");
         rmSetAreaForestDensity(forest, 0.9);
         rmSetAreaForestClumpiness(forest, 0.2);
         rmSetAreaForestUnderbrush(forest, 0.6);
         rmSetAreaMinBlobs(forest, 1);
         rmSetAreaMaxBlobs(forest, 7);
         rmSetAreaMinBlobDistance(forest, 16.0);
         rmSetAreaMaxBlobDistance(forest, 40.0);
         rmSetAreaCoherence(forest, 0.4);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
         rmAddAreaConstraint(forest, forestConstraint);
         rmAddAreaConstraint(forest, avoidAll);
         rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(forest, smallMesaConstraint); 
		 rmAddAreaConstraint(forest, avoidTC);
		 rmAddAreaConstraint(forest, avoidCW);
		rmAddAreaConstraint(forest, Eastward); 
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

  failCount=0; 
  for (i=0; <numTries)	{   
    int forest2ID=rmCreateArea("forestb"+i);
    rmSetAreaWarnFailure(forest2ID, false);
    rmSetAreaSize(forest2ID, rmAreaTilesToFraction(150), rmAreaTilesToFraction(200));
    rmSetAreaForestType(forest2ID, "Madagascar Dry Forest");
    rmSetAreaForestDensity(forest2ID, 0.4);
    rmSetAreaForestClumpiness(forest2ID, 0.2);
    rmSetAreaForestUnderbrush(forest2ID, 0.2);
    rmSetAreaMinBlobs(forest2ID, 4);
    rmSetAreaMaxBlobs(forest2ID, 7);	
    rmSetAreaMinBlobDistance(forest2ID, 3.0);
    rmSetAreaMaxBlobDistance(forest2ID, 5.0);
    rmSetAreaCoherence(forest2ID, 0.4);
    rmSetAreaSmoothDistance(forest2ID, 10);
         rmAddAreaToClass(forest2ID, rmClassID("classForest")); 
         rmAddAreaConstraint(forest2ID, forestConstraint);
         rmAddAreaConstraint(forest2ID, avoidAll);
         rmAddAreaConstraint(forest2ID, longAvoidImpassableLand); 
		 rmAddAreaConstraint(forest2ID, smallMesaConstraint); 
		 rmAddAreaConstraint(forest2ID, avoidTC);
		 rmAddAreaConstraint(forest2ID, avoidCW);
         //rmAddAreaConstraint(forest, avoidTradeRoute); // Pierre Jean: The debugger sees this as error
		 rmAddAreaConstraint(forest2ID, avoidTradeRoute); // Pierre Jean: Fix (?)
    if(rmBuildArea(forest2ID)==false)
    {
      // Stop trying once we fail 5 times in a row.  
      failCount++;
      if(failCount==5)
        break;
    }
    else
      failCount=0; 
  } 
  
  failCount=0; 

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);

	// Scattered MINES
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "MineSapphire", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(goldID, avoidTC);
	rmAddObjectDefConstraint(goldID, avoidCW);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidCoin);
    rmAddObjectDefConstraint(goldID, avoidImpassableLand);
	rmAddObjectDefConstraint(goldID, smallMesaConstraint);
	rmPlaceObjectDefInArea(goldID, 0, bigIslandID, cNumberNonGaiaPlayers*3);

	// Scattered BERRRIES		
	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "BananaBush", rmRandInt(3,4), 4.0);  // (3,5) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(berriesID, avoidTC);
	rmAddObjectDefConstraint(berriesID, avoidTP);   //Just added this, to make sure berries don't stomp on Trade Post sockets
	rmAddObjectDefConstraint(berriesID, avoidCW);
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
	rmAddObjectDefConstraint(berriesID, smallMesaConstraint);
	rmPlaceObjectDefInArea(berriesID, 0, bigIslandID, cNumberNonGaiaPlayers);   //was *4

	// Just a FEW scattered TURKEYS
	int turkeyID=rmCreateObjectDef("random turkeys");
	rmAddObjectDefItem(turkeyID, "ElephantBird", rmRandInt(2,4), 10.0);  // (2,4) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(turkeyID, 0.0);
	rmSetObjectDefMaxDistance(turkeyID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(turkeyID, avoidTC);
	rmAddObjectDefConstraint(turkeyID, avoidCW);
	rmAddObjectDefConstraint(turkeyID, avoidRandomTurkeys);
	//rmAddObjectDefConstraint(turkeyID, avoidAll);
	//rmAddObjectDefConstraint(turkeyID, avoidRandomBerries);
	rmAddObjectDefConstraint(turkeyID, avoidImpassableLand);
	rmAddObjectDefConstraint(turkeyID, smallMesaConstraint);
	rmPlaceObjectDefInArea(turkeyID, 0, bigIslandID, cNumberNonGaiaPlayers*rmRandInt(1,3));   //Was *2 scattered Turkeys for awhile, but players wanted more fast food.

	// Define and place Nuggets
	// Easier nuggets
	int nugget1= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNugget);
	rmAddObjectDefConstraint(nugget1, avoidTradeRoute);
	//rmAddObjectDefConstraint(nugget1, avoidCW);
	rmAddObjectDefConstraint(nugget1, avoidAll);
	rmAddObjectDefConstraint(nugget1, avoidWater20);
	rmAddObjectDefConstraint(nugget1, smallMesaConstraint);
	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget1, 0, bigIslandID, cNumberNonGaiaPlayers*rmRandInt(7,8));

	// Tougher nuggets
	int nugget2= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget2, 0.0);
	rmSetNuggetDifficulty(2, 3);
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget2, avoidTC);
	rmAddObjectDefConstraint(nugget2, avoidCW);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidWater20);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget2, 0, bigIslandID, cNumberNonGaiaPlayers*rmRandInt(2,3));
	rmPlaceObjectDefInArea(nugget2, 0, smallMesaID, cNumberNonGaiaPlayers+1);

	//Place Sheep -- added Sheep 11-28-05
	int sheepID=rmCreateObjectDef("sheep");
	rmAddObjectDefItem(sheepID, "ypGoat", 2, 4.0);
	rmSetObjectDefMinDistance(sheepID, 0.0);
	rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(sheepID, avoidSheep);
	rmAddObjectDefConstraint(sheepID, avoidAll);
	rmAddObjectDefConstraint(sheepID, avoidSocket);
	rmAddObjectDefConstraint(sheepID, avoidTradeRoute);
	rmAddObjectDefConstraint(sheepID, avoidTC);
	rmAddObjectDefConstraint(sheepID, avoidCW);
	rmAddObjectDefConstraint(sheepID, longPlayerConstraint);
	rmPlaceObjectDefInArea(sheepID, 0, smallMesaID, cNumberNonGaiaPlayers+2);

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place Whales as much in big west bay only as possible --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.4));		//Distance whales will be placed from the starting spot (below)
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3 + rmRandInt(1,2));  //Was .43, .67 // .37, .66 -- The whales will be placed from this spot. 1 per player, plus 1 or 2 more.

	// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------

	int fishID=rmCreateObjectDef("fish Mahi");
	rmAddObjectDefItem(fishID, "FishMahi", 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishVsWhaleID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers); 

	/*
	int fish2ID=rmCreateObjectDef("fish Tarpon");
	rmAddObjectDefItem(fish2ID, "FishTarpon", 1, 0.0);
	rmSetObjectDefMinDistance(fish2ID, 0.0);
	rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fish2ID, fishVsFishTarponID);
	rmAddObjectDefConstraint(fish2ID, fishVsWhaleID);
	rmAddObjectDefConstraint(fish2ID, fishLand);
	rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);  //Was 9*.  Too many.
	*/

	if (cNumberNonGaiaPlayers <5)		// If less than 5 players, place extra fish.
	{
		rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);	
	}

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.99);

	// RANDOM TREES

	int randomTreeID=rmCreateObjectDef("random tree");
	rmAddObjectDefItem(randomTreeID, "TreeBaobab", rmRandInt(4,5), 3.0);
	rmSetObjectDefMinDistance(randomTreeID, 0.0);
	rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
	rmAddObjectDefConstraint(randomTreeID, avoidTC);
	rmAddObjectDefConstraint(randomTreeID, avoidCW);
	rmAddObjectDefConstraint(randomTreeID, avoidAll); 
	rmAddObjectDefConstraint(randomTreeID, smallMesaConstraint);
	rmPlaceObjectDefInArea(randomTreeID, 0, bigIslandID, 3*cNumberNonGaiaPlayers);   //Scatter 8 random trees per player.

	int randomTree2ID=rmCreateObjectDef("random tree 2");
	rmAddObjectDefItem(randomTree2ID, "TreeSonora", rmRandInt(6,7), 0.0);
	rmSetObjectDefMinDistance(randomTree2ID, 0.0);
	rmSetObjectDefMaxDistance(randomTree2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomTree2ID, avoidTC);
	rmAddObjectDefConstraint(randomTree2ID, avoidCW);
	rmAddObjectDefConstraint(randomTree2ID, avoidAll); 
	rmPlaceObjectDefInArea(randomTree2ID, 0, smallMesaID, 15*cNumberNonGaiaPlayers);  

	int randomTree3ID=rmCreateObjectDef("random tree 3");
	rmAddObjectDefItem(randomTree3ID, "ypTreeCeylon", rmRandInt(6,7), 0.0);
	rmSetObjectDefMinDistance(randomTree3ID, 0.0);
	rmSetObjectDefMaxDistance(randomTree3ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomTree3ID, avoidTC);
	rmAddObjectDefConstraint(randomTree3ID, avoidCW);
	rmAddObjectDefConstraint(randomTree3ID, avoidAll); 
	rmAddObjectDefConstraint(randomTree3ID, Eastward); 
	rmPlaceObjectDefInArea(randomTree3ID, 0, bigIslandID, 15*cNumberNonGaiaPlayers);  

  int nuggetW= rmCreateObjectDef("nugget water"); 
  rmAddObjectDefItem(nuggetW, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(5, 5);
  rmSetObjectDefMinDistance(nuggetW, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(nuggetW, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(nuggetW, avoidLand);
  rmAddObjectDefConstraint(nuggetW, avoidNuggetWater);
  rmPlaceObjectDefAtLoc(nuggetW, 0, 0.5, 0.5, cNumberNonGaiaPlayers*4);




  // King of the Hill (added 2026-11 for WoL): centre of the island, where every player starts
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




