// Easter Island by Tahattus
// Main entry point for random map script    

include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";

void main(void)
{
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.10);


// --------------- MAP DESCRIPTION ------------------------------------


	// Set size of map
	int playerTiles=23500;
	if (cNumberNonGaiaPlayers >4)   // If more than 4 players...
		playerTiles = 18000;		// ...give this many tiles per player.
	if (cNumberNonGaiaPlayers >7)	// If more than 7 players...
		playerTiles = 20000;		// ...give this many tiles per player.	
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Set up default water type.
	rmSetSeaLevel(3.0);          
	rmSetSeaType("easter island");
	rmSetBaseTerrainMix("galapagos");
	rmSetMapType("easterisland");
	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetLightingSet("308b_caribbeanlight");

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
	rmDefineClass("classVolcano");

	rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.7, 5.0);  // Like Texas for the moment.
	rmSetMapElevationHeightBlend(0.2);

// --------------- MAP CONTRAINTS ------------------------------------

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

	// Volcano area constraint.  
	int volcanoConstraint=rmCreateClassDistanceConstraint("stay away from volcano", rmClassID("classVolcano"), 20.0);
	int cliffConstraint=rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 20.0);
        int nearShore=rmCreateTerrainMaxDistanceConstraint("near shore", "Water", true, 6.0);
  int avoidNuggetWater=rmCreateTypeDistanceConstraint("nugget vs. nugget water", "AbstractNugget", 80.0);

	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fishMahi", 25.0);			// was 50.0
	// int fishVsFishTarponID=rmCreateTypeDistanceConstraint("fish v fish2", "fishTarpon", 20.0);  // was 40.0 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 30.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "HumpbackWhale", 40.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 17.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int avoidCoin=-1;
	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "Abstractmine", 75.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "Abstractmine", 85.0);	// 85.0 seems the best for event minegold distribution.  This number tells minegolds how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random turkeys", "lizard", 50.0);	//Attempting to spread them out more evenly.
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 30.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
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
	int flagEdgeConstraint=rmCreatePieConstraint("flag edge of map", 0.5, 0.5, 0, rmGetMapXSize()-25, 0, 0, 0);
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
	int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("classSocket"), 10.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);

	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  (It excludes the west bay, where I do not want the flags.)
	int circleConstraint=rmCreatePieConstraint("semi-circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(50), rmDegreesToRadians(290));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

	// int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);



// --------------- CREATE ISLAND ------------------------------------





  int IslandLoc = 1;								

	// Make one big island.  
	int bigIslandID=rmCreateArea("largest island");
	rmSetAreaSize(bigIslandID, 0.238, 0.238);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(bigIslandID, 0.77);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(bigIslandID, 5.0);
	rmSetAreaSmoothDistance(bigIslandID, 20);
	rmSetAreaMix(bigIslandID, "newengland_grass");
	rmAddAreaToClass(bigIslandID, classIsland);
	rmAddAreaConstraint(bigIslandID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 4.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmSetAreaElevationOctaves(bigIslandID, 3);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);
	rmAddAreaInfluenceSegment(bigIslandID, 0.16, 0.57, 0.19, 0.52);  
	rmAddAreaInfluenceSegment(bigIslandID, 0.24, 0.5, 0.29, 0.52); 
	rmAddAreaInfluenceSegment(bigIslandID, 0.35, 0.5, 0.4, 0.44);  
	rmAddAreaInfluenceSegment(bigIslandID, 0.52, 0.42, 0.6, 0.36);   
	rmAddAreaInfluenceSegment(bigIslandID, 0.68, 0.36, 0.76, 0.29); 
	rmAddAreaInfluenceSegment(bigIslandID, 0.81, 0.3, 0.83, 0.35);   
	rmAddAreaInfluenceSegment(bigIslandID, 0.74, 0.43, 0.71, 0.5);  
	rmAddAreaInfluenceSegment(bigIslandID, 0.69, 0.63, 0.6, 0.75); 
	rmAddAreaInfluenceSegment(bigIslandID, 0.45, 0.7, 0.32, 0.64);   
	rmAddAreaInfluenceSegment(bigIslandID, 0.28, 0.66, 0.24, 0.63);  
	rmAddAreaInfluenceSegment(bigIslandID, 0.2, 0.6, 0.17, 0.58);  

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);

	rmSetAreaWarnFailure(bigIslandID, false);

	if (IslandLoc == 1)
	rmSetAreaLocation(bigIslandID, .557, .557);		//Put the big island in exact middle of map.
	rmBuildArea(bigIslandID);



// --------------- PLAYERS -------------------------------


	   // Set up player areas.  -- Each team always placed along a line.  One team in NE, other in SW.
	
	float teamStartLoc = rmRandFloat(0.0, 1.0);  //This chooses a number randomly between 0 and 1, used to pick whether team 1 is on top or bottom.

		if (cNumberTeams == 2 )
		{
			//Team 0 starts on top
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.35, 0.45, 0.35, 0.70, 0.0, 0.2); //Team 0 is in the south 
			
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.8, 0.25, 0.75, 0.5, 0.0, 0.2); //Team 1 is in the north
			}


			else
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.8, 0.25, 0.75, 0.5, 0.0, 0.2);  //Team 0 is in the north
						
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.35, 0.45, 0.35, 0.70, 0.0, 0.2); //Team 1 is in the south
			}
		}

	// otherwise it's a Free-For-All, so just place everyone in one big arc around the center island.
	else
	{
  		rmSetPlacementSection(0.04, 0.82);
		rmPlacePlayersCircular(0.22, 0.23, 0.0);
	}

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
	
	

// --------------- MOUNTAIN  ------------------------------------

	
   // Always create a mountain in center of island.
   // Really big mountain for 8 players, big mountain for 6 or 7 players, and small mountain for 5 or less players.

		int smallCliffHeight=rmRandInt(0,10);
		int smallMesaID=rmCreateArea("small mesa"+i);
		rmSetAreaSize(smallMesaID, 0.00, 0.00);  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
		rmSetAreaWarnFailure(smallMesaID, false);
		rmSetAreaCliffType(smallMesaID, "New England");
		rmAddAreaToClass(smallMesaID, rmClassID("canyon"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(smallMesaID, 1, 1.0, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(smallMesaID, rmRandInt(6, 8), 1.0, 1.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(smallMesaID, 0.88);
		rmSetAreaLocation(smallMesaID, 0.5, 0.5); 
		rmAddAreaInfluenceSegment(smallMesaID, 0.42, 0.62, .4, 0.56); //Bottom - Original segment
		rmAddAreaInfluenceSegment(smallMesaID, 0.46, 0.54, 0.55, 0.55); //Right
		rmAddAreaInfluenceSegment(smallMesaID, 0.6, 0.6, 0.62, 0.78); //Top - Original segment
		rmAddAreaInfluenceSegment(smallMesaID, 0.54, 0.68, 0.48, 0.65); //Left
		rmBuildArea(smallMesaID);
     



	// Special AREA CONSTRAINTS and use it to make resources avoid the mountain in center:
		int smallMesaConstraint = rmCreateAreaDistanceConstraint("avoid Small Mesa", smallMesaID, 4.0);

		


// --------------- RANO KAU  ------------------------------------




		int hanokauCliffHeight=rmRandInt(0,10);
		int RanoKauID=rmCreateArea("ranokau"+i);
		rmSetAreaSize(RanoKauID, 0.01, 0.01);  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
		rmSetAreaWarnFailure(RanoKauID, false);
		rmSetAreaCliffType(RanoKauID, "New England");
		rmAddAreaToClass(RanoKauID, rmClassID("ClassVolcano"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(RanoKauID, 1, 1.0, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(RanoKauID, rmRandInt(-8, -6), 1.0, 1.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(RanoKauID, 0.88);
		rmSetAreaLocation(RanoKauID, 0.2, 0.55); 
 	        rmSetAreaTerrainType(RanoKauID, "wotta\galapagos\galapagos1");
		rmBuildArea(RanoKauID);

		int pondClass=rmDefineClass("pond");
 		int pondConstraint=rmCreateClassDistanceConstraint("things avoid the pond", rmClassID("pond"), 20.0);
   		int smallPond1=rmCreateArea("small pond");
   		int smallPond2=rmCreateArea("small pond 2");

		rmSetAreaSize(smallPond1, 0.002, 0.002);
		rmSetAreaWaterType(smallPond1, "Easter Island Crater");
		rmSetAreaBaseHeight(smallPond1, 1);
		rmAddAreaToClass(smallPond1, pondClass);
		rmSetAreaCoherence(smallPond1, 0.3);
		rmSetAreaSmoothDistance(smallPond1, 5);
		rmSetAreaWarnFailure(smallPond1, false);
		rmSetAreaLocation(smallPond1, 0.2, 0.55); 
		rmBuildArea(smallPond1);




		int hanorarakuCliffHeight=rmRandInt(0,10);
		int RanoRarakuID=rmCreateArea("RanoRaraku"+i);
		rmSetAreaSize(RanoRarakuID, 0.007, 0.007);  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
		rmSetAreaWarnFailure(RanoRarakuID, false);
		rmSetAreaCliffType(RanoRarakuID, "New England");
		rmAddAreaToClass(RanoRarakuID, rmClassID("ClassVolcano"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(RanoRarakuID, 1, 1.0, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(RanoRarakuID, rmRandInt(-8, -6), 1.0, 1.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(RanoRarakuID, 0.88);
		rmSetAreaLocation(RanoRarakuID, 0.64, 0.4);
	        rmSetAreaTerrainType(RanoRarakuID, "wotta\galapagos\galapagos1"); 
		rmBuildArea(RanoRarakuID);

		rmSetAreaSize(smallPond2, 0.002, 0.002);
		rmSetAreaWaterType(smallPond2, "Easter Island Crater");
		rmSetAreaBaseHeight(smallPond2, 0);
		rmAddAreaToClass(smallPond2, pondClass);
		rmSetAreaCoherence(smallPond2, 0.3);
		rmSetAreaSmoothDistance(smallPond2, 5);
		rmSetAreaWarnFailure(smallPond2, false);
		rmSetAreaLocation(smallPond2, 0.64, 0.4); 
		rmBuildArea(smallPond2);


   int numTries0=cNumberNonGaiaPlayers+2;

   for(i=0; <numTries0)
   {
      int cliffID=rmCreateArea("cliff"+i);
      //rmSetAreaSize(cliffID, rmAreaTilesToFraction(500), rmAreaTilesToFraction(1000));
	  rmSetAreaSize(cliffID, rmAreaTilesToFraction(900), rmAreaTilesToFraction(1800));
      rmSetAreaWarnFailure(cliffID, false);
	  rmSetAreaCliffType(cliffID, "New England");
	  rmSetAreaCliffEdge(cliffID, 1, 0.6, 0.8, 1.0, 0);
      //rmSetAreaCliffEdge(cliffID, 1, 0.6, 0.1, 1.0, 0);
	  //rmSetAreaCliffEdge(cliffID, 1, 1);
      rmSetAreaCliffPainting(cliffID, false, true, true, 1.5, true);
      rmSetAreaCliffHeight(cliffID, 5, 2.0, 0.5);
      rmSetAreaHeightBlend(cliffID, 1);
      rmSetAreaMinBlobs(cliffID, 4);
      rmSetAreaMaxBlobs(cliffID, 6);
      rmSetAreaMinBlobDistance(cliffID, 16.0);
      rmSetAreaMaxBlobDistance(cliffID, 30.0);
      rmSetAreaSmoothDistance(cliffID, 10);
      rmSetAreaCoherence(cliffID, 0.75);
      rmAddAreaConstraint(cliffID, longAvoidImpassableLand);
      rmAddAreaConstraint(cliffID, cliffConstraint);
	  rmAddAreaConstraint(cliffID, playerConstraint);
      rmAddAreaConstraint(cliffID, avoidImportantItem);
	  rmAddAreaConstraint(cliffID, avoidCoin);
      rmBuildArea(cliffID);
}



// --------------- PLAYER STUFF ------------------------------------



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
	rmAddObjectDefItem(playerGoldID, "SPCSpanishShipRuins", 1, 0);
	rmSetObjectDefMinDistance(playerGoldID, 12.0);
	rmSetObjectDefMaxDistance(playerGoldID, 20.0);
	rmAddObjectDefConstraint(playerGoldID, avoidAll);
    rmAddObjectDefConstraint(playerGoldID, avoidImpassableLand);

	//Prepare to place player starting Crates (mostly food)
	int playerCrateID=rmCreateObjectDef("starting crates");
	rmAddObjectDefItem(playerCrateID, "crateOfWood", rmRandInt(1,2), 4.0);
	rmSetObjectDefMinDistance(playerCrateID, 6);
	rmSetObjectDefMaxDistance(playerCrateID, 10);
	rmAddObjectDefConstraint(playerCrateID, avoidAll);
	rmAddObjectDefConstraint(playerCrateID, shortAvoidImpassableLand);

	//Prepare to place player starting Berries
	int playerBerriesID=rmCreateObjectDef("player berries");
	rmAddObjectDefItem(playerBerriesID, "berrybush", rmRandInt(4,6), 4.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerBerriesID, 21);
    rmSetObjectDefMaxDistance(playerBerriesID, 26);		
	rmAddObjectDefConstraint(playerBerriesID, avoidAll);
    rmAddObjectDefConstraint(playerBerriesID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerBerriesID, true);

	//Prepare to place player starting Turkeys
	int playerTurkeyID=rmCreateObjectDef("player turkeys");
    rmAddObjectDefItem(playerTurkeyID, "lizard", rmRandInt(6,7), 4.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerTurkeyID, 14);
	rmSetObjectDefMaxDistance(playerTurkeyID, 19);	
	rmAddObjectDefConstraint(playerTurkeyID, avoidAll);
    rmAddObjectDefConstraint(playerTurkeyID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerTurkeyID, true);


	int waterSpawnPointID = 0;

	// --------------- Make load bar move. ----------------------------------------------------------------------------`
	rmSetStatusText("",0.70);
   
	// *********** Place Home City Water Spawn Flag ***************************************************

	for(i=0; <cNumberPlayers)
   {
	    // Place TC and starting units
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));   
		rmPlaceObjectDefAtLoc(playerBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 
		rmPlaceObjectDefAtLoc(playerTurkeyID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));  										
		rmPlaceObjectDefAtLoc(playerCrateID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));



    // Place water spawn points for the players
		waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 10.0);
		rmAddObjectDefItem(waterSpawnPointID, "Fishingboat", 2, 10.0);
		rmAddClosestPointConstraint(flagVsFlag);
		rmAddClosestPointConstraint(flagLand);
 		rmAddClosestPointConstraint(flagEdgeConstraint);
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
		rmClearClosestPointConstraints();
   }
	



	// ***************** SCATTERED RESOURCES **************************************
	// Scattered FORESTS
   int forestTreeID = 0;
   numTries=10*cNumberNonGaiaPlayers;
   int failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest, "Easter Island Forest");
         rmSetAreaForestDensity(forest, 0.6);
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
	rmAddAreaConstraint(forest, volcanoConstraint);
         rmAddAreaConstraint(forest, avoidAll);
         rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(forest, smallMesaConstraint); 
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



   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.75);

	//rmClearClosestPointConstraints();




	// Scattered MINES
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "minegold", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(goldID, avoidTC);
	rmAddObjectDefConstraint(goldID, avoidCW);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidCoin);
	rmAddObjectDefConstraint(goldID, volcanoConstraint);
    rmAddObjectDefConstraint(goldID, avoidImpassableLand);
	rmAddObjectDefConstraint(goldID, smallMesaConstraint);
	rmPlaceObjectDefInArea(goldID, 0, bigIslandID, cNumberNonGaiaPlayers*2);


	// Scattered BERRRIES		
	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "berrybush", rmRandInt(5,8), 6.0);  // (3,5) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(berriesID, avoidTC);
	rmAddObjectDefConstraint(berriesID, avoidTP);   //Just added this, to make sure berries don't stomp on Trade Post sockets
	rmAddObjectDefConstraint(berriesID, avoidCW);
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, volcanoConstraint);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
	rmAddObjectDefConstraint(berriesID, smallMesaConstraint);
	rmPlaceObjectDefInArea(berriesID, 0, bigIslandID, cNumberNonGaiaPlayers*4);   //was *4

	// Just a FEW scattered TURKEYS
	int turkeyID=rmCreateObjectDef("random turkeys");
	rmAddObjectDefItem(turkeyID, "lizard", rmRandInt(3,5), 5.0);  // (2,4) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(turkeyID, 0.0);
	rmSetObjectDefMaxDistance(turkeyID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(turkeyID, avoidTC);
	rmAddObjectDefConstraint(turkeyID, avoidCW);
	rmAddObjectDefConstraint(turkeyID, avoidRandomTurkeys);
	//rmAddObjectDefConstraint(turkeyID, avoidAll);
	rmAddObjectDefConstraint(turkeyID, volcanoConstraint);
	//rmAddObjectDefConstraint(turkeyID, avoidRandomBerries);
	rmAddObjectDefConstraint(turkeyID, avoidImpassableLand);
	rmAddObjectDefConstraint(turkeyID, smallMesaConstraint);
	rmPlaceObjectDefInArea(turkeyID, 0, bigIslandID, cNumberNonGaiaPlayers*3);   //Was *2 scattered Turkeys for awhile, but players wanted more fast food.



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
	rmAddObjectDefConstraint(nugget1, volcanoConstraint);
	rmAddObjectDefConstraint(nugget1, avoidAll);
	rmAddObjectDefConstraint(nugget1, avoidWater20);
	rmAddObjectDefConstraint(nugget1, smallMesaConstraint);
	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget1, 0, bigIslandID, cNumberNonGaiaPlayers*rmRandInt(1,2));

	// Tougher nuggets
	int nugget2= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget2, 0.0);
	rmSetNuggetDifficulty(2, 3);
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNugget);
	rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget2, avoidTC);
	rmAddObjectDefConstraint(nugget2, avoidCW);
	rmAddObjectDefConstraint(nugget2, volcanoConstraint);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidWater20);
	rmAddObjectDefConstraint(nugget2, smallMesaConstraint);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget2, 0, bigIslandID, cNumberNonGaiaPlayers*rmRandInt(1,2));


	// Moai nuggets
	int moai= rmCreateObjectDef("moai"); 
	rmAddObjectDefItem(moai, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(moai, 0.0);
	rmSetNuggetDifficulty(6);
	rmSetObjectDefMaxDistance(moai, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(moai, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(moai, avoidNugget);
	rmAddObjectDefConstraint(moai, avoidTradeRoute);
	rmAddObjectDefConstraint(moai, avoidTC);
	rmAddObjectDefConstraint(moai, avoidCW);
	rmAddObjectDefConstraint(moai, avoidAll);
	rmAddObjectDefConstraint(moai, smallMesaConstraint);
	rmAddObjectDefConstraint(moai, playerEdgeConstraint);
  	rmAddObjectDefConstraint(moai, nearShore);
	rmAddObjectDefConstraint(moai, volcanoConstraint);
	rmPlaceObjectDefInArea(moai, 0, bigIslandID, cNumberNonGaiaPlayers*3);


	//Place Sheep -- added Sheep 11-28-05
	int sheepID=rmCreateObjectDef("sheep");
	rmAddObjectDefItem(sheepID, "sheep", 2, 4.0);
	rmSetObjectDefMinDistance(sheepID, 0.0);
	rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(sheepID, avoidSheep);
	rmAddObjectDefConstraint(sheepID, avoidAll);
	rmAddObjectDefConstraint(sheepID, avoidSocket);
	rmAddObjectDefConstraint(sheepID, avoidTradeRoute);
	rmAddObjectDefConstraint(sheepID, avoidTC);
	rmAddObjectDefConstraint(sheepID, avoidCW);
	rmAddObjectDefConstraint(sheepID, longPlayerConstraint);
	rmAddObjectDefConstraint(sheepID, smallMesaConstraint);
	rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
	rmAddObjectDefConstraint(sheepID, volcanoConstraint);
	rmPlaceObjectDefAtLoc(sheepID, 0, 0.46, 0.48, cNumberNonGaiaPlayers*1);

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);


  // Water nuggets
  
  int nuggetW= rmCreateObjectDef("nugget water"); 
  rmAddObjectDefItem(nuggetW, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(5, 5);
  rmSetObjectDefMinDistance(nuggetW, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(nuggetW, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(nuggetW, avoidLand);
  rmAddObjectDefConstraint(nuggetW, avoidNuggetWater);
  rmPlaceObjectDefAtLoc(nuggetW, 0, 0.5, 0.5, cNumberNonGaiaPlayers*4);



	// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------
	//Place Whales as much in big west bay only as possible --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));		//Distance whales will be placed from the starting spot (below)
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);  //Was .43, .67 // .37, .66 -- The whales will be placed from this spot.


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


// --------------- RANDOM TREES ------------------------------------






	int randomGrassID=rmCreateObjectDef("random grass");
	rmAddObjectDefItem(randomGrassID, "TreeGreatPlainsGrassGreen", 1, 0.0);
	rmSetObjectDefMinDistance(randomGrassID, 0.0);
	rmSetObjectDefMaxDistance(randomGrassID, rmXFractionToMeters(0.5));
	rmPlaceObjectDefInArea(randomGrassID, 0, bigIslandID, 60*cNumberNonGaiaPlayers);   //Scatter 8 random trees per player.



	int shipID=rmCreateObjectDef("random SPCSpanishShipRuins");
	rmAddObjectDefItem(shipID, "SPCSpanishShipRuins", 1, 0.0);
	rmSetObjectDefMinDistance(shipID, 0.0);
  	rmAddObjectDefConstraint(shipID, nearShore);
	rmAddObjectDefConstraint(shipID, avoidNugget);
	rmAddObjectDefConstraint(shipID, avoidCoin);
	rmAddObjectDefConstraint(shipID, avoidAll);
	rmAddObjectDefConstraint(shipID, volcanoConstraint);
	rmSetObjectDefMaxDistance(shipID, rmXFractionToMeters(0.5));
	rmPlaceObjectDefInArea(shipID, 0, bigIslandID, 2*cNumberNonGaiaPlayers);   //Scatter 8 random trees per player.


	int moaiID=rmCreateObjectDef("random moai");
	rmAddObjectDefItem(moaiID, "WOLmoai", 1, 0.0);
	rmSetObjectDefMinDistance(moaiID, 0.0);
	rmAddObjectDefConstraint(moaiID, avoidNugget);
	rmAddObjectDefConstraint(moaiID, avoidAll);
	rmAddObjectDefConstraint(moaiID, playerConstraint);
	rmAddObjectDefConstraint(moaiID, volcanoConstraint);
	rmSetObjectDefMaxDistance(moaiID, rmXFractionToMeters(0.5));
	rmPlaceObjectDefInArea(moaiID, 0, bigIslandID, 5*cNumberNonGaiaPlayers);   //Scatter 8 random trees per player.


	// Just a FEW scattered crab
	int crabID=rmCreateObjectDef("random crab");
	rmAddObjectDefItem(crabID, "crab", rmRandInt(6,9), 5.0);  // (2,4) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	//rmAddObjectDefConstraint(crabID, avoidAll);
  	rmAddObjectDefConstraint(crabID, nearShore);
	rmAddObjectDefConstraint(crabID, volcanoConstraint);
	rmPlaceObjectDefInArea(crabID, 0, bigIslandID, cNumberNonGaiaPlayers*2);   //Was *2 scattered crab for awhile, but players wanted more fast food.



	//  ----------------------------------- Make it rain

	rmCreateTrigger("Day");
   rmSwitchToTrigger(rmTriggerID("Day"));
   rmSetTriggerActive(true);
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1", 2);
   rmAddTriggerEffect("Set Lighting");
   rmSetTriggerEffectParam("SetName", "borneo");
   rmSetTriggerEffectParamInt("FadeTime", 120);




	rmSetGlobalRain( 1.0 );
	rmSetGlobalStormLength(1.0, 0.0);

	// Sets up the rain triggers - rain hard for 20 seconds, then lightly, then hard again, then medium, then off.
	rmCreateTrigger("ChangeRain1");
	rmSwitchToTrigger(rmTriggerID("ChangeRain1"));
	rmSetTriggerActive(true);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1", 20);
	rmAddTriggerEffect("Render Rain");
	rmSetTriggerEffectParamFloat("Percent", 0.3);

	rmCreateTrigger("ChangeRain2");
	rmSwitchToTrigger(rmTriggerID("ChangeRain2"));
	rmSetTriggerActive(true);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1", 40);
	rmAddTriggerEffect("Render Rain");
	rmSetTriggerEffectParamFloat("Percent", 1.0);

	rmCreateTrigger("ChangeRain3");
	rmSwitchToTrigger(rmTriggerID("ChangeRain3"));
	rmSetTriggerActive(true);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1", 60);
	rmAddTriggerEffect("Render Rain");
	rmSetTriggerEffectParamFloat("Percent", 0.3);

	rmCreateTrigger("ChangeRain4");
	rmSwitchToTrigger(rmTriggerID("ChangeRain4"));
	rmSetTriggerActive(true);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1", 75);
	rmAddTriggerEffect("Render Rain");
	rmSetTriggerEffectParamFloat("Percent", 0.0);

  // King of the Hill (added 2026-11 for WoL): the open land of the island farthest from every Town Center (the centre favours some starts)
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