// Tahiti
// Started over Hispaniola 

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
		subCiv0=rmGetCivID("Fale");
		rmEchoInfo("subCiv0 is Fale "+subCiv0);
		if (subCiv0 >= 0)
		rmSetSubCiv(0, "Fale");

		subCiv1=rmGetCivID("Fale");
		rmEchoInfo("subCiv1 is Fale "+subCiv1);
		if (subCiv1 >= 0)
		rmSetSubCiv(1, "Fale");

		subCiv2=rmGetCivID("Fale");
		rmEchoInfo("subCiv2 is Fale "+subCiv2);
		if (subCiv2 >= 0)
		rmSetSubCiv(2, "Fale");
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
	int playerTiles=29500;
	if (cNumberNonGaiaPlayers >4)   // If more than 4 players...
		playerTiles = 24000;		// ...give this many tiles per player.
	if (cNumberNonGaiaPlayers >7)	// If more than 7 players...
		playerTiles = 27000;		// ...give this many tiles per player.	
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(0.79*size, size);

	// Set up default water type.
	rmSetSeaLevel(1.0);          
	rmSetSeaType("Tahiti Coast");
	rmSetBaseTerrainMix("tahiti");
	rmSetMapType("polynesia");
	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetLightingSet("caribbean");

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
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 20.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "HumpbackWhale", 30.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 19.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 30.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int avoidCoin=-1;
	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "mine", 55.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "mine", 65.0);	// 85.0 seems the best for event minegold distribution.  This number tells minegolds how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "Breadfruit", 28.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random turkeys", "BerryBush", 50.0);	//Attempting to spread them out more evenly.
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 54.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
	int avoidNuggetWater=rmCreateTypeDistanceConstraint("nugget vs. nugget water", "AbstractNugget", 30.0);
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
	rmSetAreaSize(bigIslandID, 0.22, 0.22);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(bigIslandID, 0.77);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(bigIslandID, 1.0);
	rmSetAreaSmoothDistance(bigIslandID, 50);
	rmSetAreaMix(bigIslandID, "tahiti");
	rmAddAreaToClass(bigIslandID, classIsland);
	rmAddAreaConstraint(bigIslandID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 3.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmSetAreaElevationOctaves(bigIslandID, 3);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);
	rmAddAreaTerrainLayer(bigIslandID, "tahiti\groundshore2_tah", 0, 3);
	rmAddAreaTerrainLayer(bigIslandID, "tahiti\groundshore3_tah", 4, 6);
	rmAddAreaTerrainLayer(bigIslandID, "tahiti\ground4_tah", 7, 9);
		
	int bigIsland2ID=rmCreateArea("big lone island 2");
	rmSetAreaSize(bigIsland2ID, 0.11, 0.11);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(bigIsland2ID, 0.77);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(bigIsland2ID, 1.0);
	rmSetAreaSmoothDistance(bigIsland2ID, 50);
	rmSetAreaMix(bigIsland2ID, "tahiti");
//	rmAddAreaToClass(bigIsland2ID, classIsland);
//	rmAddAreaConstraint(bigIsland2ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIsland2ID, false);
	rmSetAreaElevationType(bigIsland2ID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIsland2ID, 3.0);
	rmSetAreaElevationMinFrequency(bigIsland2ID, 0.09);
	rmSetAreaElevationOctaves(bigIsland2ID, 3);
	rmSetAreaElevationPersistence(bigIsland2ID, 0.2);
	rmSetAreaElevationNoiseBias(bigIsland2ID, 1);
	rmAddAreaInfluenceSegment(bigIsland2ID, 0.50, 0.34, 0.50, 0.19);
	rmAddAreaTerrainLayer(bigIsland2ID, "tahiti\groundshore2_tah", 0, 3);
	rmAddAreaTerrainLayer(bigIsland2ID, "tahiti\groundshore3_tah", 4, 6);
	rmAddAreaTerrainLayer(bigIsland2ID, "tahiti\ground4_tah", 7, 9);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);

	rmSetAreaWarnFailure(bigIslandID, false);

	if (IslandLoc == 1)
	rmSetAreaLocation(bigIslandID, .5, .7);		//Put the big island in exact middle of map.
	rmSetAreaLocation(bigIsland2ID, .5, .27);		//Put the big island in exact middle of map.
	rmBuildArea(bigIslandID);
	rmBuildArea(bigIsland2ID);
	
    // Set up player areas.  -- Each team always placed along a line.  One team in NE, other in SW.
	
	float teamStartLoc = rmRandFloat(0.0, 1.0);  //This chooses a number randomly between 0 and 1, used to pick whether team 1 is on top or bottom.
	//float teamStartLoc = rmRandFloat(0.2, 0.4);    //Temporarily force float to be .4 or lower, so Team 0 will be in the North.

		if (cNumberTeams == 2 )
	{
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.63, 0.82);
    if(cNumberNonGaiaPlayers == 2)
		rmSetPlacementSection(0.75, 0.80);
		rmPlacePlayersCircular(0.20, 0.21, 0.0);
			
		rmSetPlacementTeam(1);
		rmSetPlacementSection(0.18, 0.37);
    if(cNumberNonGaiaPlayers == 2)
		rmSetPlacementSection(0.20, 0.25); 
		rmPlacePlayersCircular(0.20, 0.21, 0.0);
	}
	else
	{
  		rmSetPlacementSection(0.63, 0.37);
		rmPlacePlayersCircular(0.20, 0.21, 0.0);
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

   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);

	// Clear out constraints for good measure.
    rmClearClosestPointConstraints();   //This was in the Caribbean script I started with.  Not sure what it does so afraid to axe it.

	// *****************NATIVES****************************************************************************
  
	//-------- ALWAYS: 2 CARIB VILLAGES at ends of the 2 long peninsulas ----------------------------------------------
		
	if (whichVariation == 1 || whichVariation == 2 || whichVariation == 3) 
	{
		if (subCiv1 == rmGetCivID("caribs"))
		{  
			int caribsVillageID = -1;
			int caribsVillageType = rmRandInt(1,5);
			if (caribsVillageType == 3)   
				caribsVillageType = rmRandInt(1,2);
			caribsVillageID = rmCreateGrouping("caribs city", "native carib village 0"+caribsVillageType);
			rmSetGroupingMinDistance(caribsVillageID, 0.0);
			rmSetGroupingMaxDistance(caribsVillageID, 10.0);
			rmAddGroupingConstraint(caribsVillageID, avoidImpassableLand);
//			rmPlaceGroupingAtLoc(caribsVillageID, 0, 0.59, 0.80);	// JSB - end of north long peninsula.
		}	

		if (subCiv2 == rmGetCivID("caribs"))
		{  
			int caribs2VillageID = -1;
			int caribs2VillageType = rmRandInt(1,5);
			caribs2VillageID = rmCreateGrouping("caribs2 city", "native carib village 0"+caribs2VillageType);
			rmAddGroupingConstraint(caribs2VillageID, avoidImpassableLand);
//			rmPlaceGroupingAtLoc(caribs2VillageID, 0, 0.22, 0.70);  // JSB - end of south long peninsula.
		} 
	}

	//-------- VARIATION 1 AND 3: 2 CARIB VILLAGES: left and right of the big mountain in center of island -----------------------------------

	if (whichVariation == 1 || whichVariation == 3)  
	{
		if (subCiv1 == rmGetCivID("caribs"))
		{  
			int caribs3VillageID = -1;
			int caribs3VillageType = rmRandInt(1,5);
			if (caribs3VillageType == 3)   //Note: Changed from carib to carib2 
				caribs3VillageType = rmRandInt(1,2);
			caribs3VillageID = rmCreateGrouping("caribs3 city", "native carib village 0"+caribs3VillageType);
			rmSetGroupingMinDistance(caribs3VillageID, 0.0);
			rmSetGroupingMaxDistance(caribs3VillageID, 4.0);
			rmAddGroupingConstraint(caribs3VillageID, avoidImpassableLand);
//			rmPlaceGroupingAtLoc(caribs3VillageID, 0, 0.48, 0.54);	// JSB - NW Village in NW-center, next to mtn.
		}	

		if (subCiv2 == rmGetCivID("caribs"))
		{  
			int caribs4VillageID = -1;
			int caribs4VillageType = rmRandInt(1,5);
			caribs4VillageID = rmCreateGrouping("caribs4 city", "native carib village 0"+caribs4VillageType);
			rmAddGroupingConstraint(caribs4VillageID, avoidImpassableLand);
//			rmPlaceGroupingAtLoc(caribs4VillageID, 0, 0.57, 0.27);  // JSB - SE Village in SE-center, next to mtn.
		} 
	}

	//-------- VARIATION 2 AND 3: 2 CARIB VILLAGES at NE and SE ends of the island  ---------------------------------------
		
	if (whichVariation == 2 || whichVariation == 3) 
	{
		if (subCiv1 == rmGetCivID("caribs"))
		{  
			int caribs5VillageID = -1;
			int caribs5VillageType = rmRandInt(1,5);
			if (caribs5VillageType == 3)   
				caribs5VillageType = rmRandInt(1,2);
			caribs5VillageID = rmCreateGrouping("caribs5 city", "native carib village 0"+caribs5VillageType);
			rmSetGroupingMinDistance(caribs5VillageID, 0.0);
			rmSetGroupingMaxDistance(caribs5VillageID, 7.0);
			rmAddGroupingConstraint(caribs5VillageID, avoidImpassableLand);
//			rmPlaceGroupingAtLoc(caribs5VillageID, 0, 0.73, 0.26);	// Place near NE end of island.  //.73, .25
		}	

		if (subCiv2 == rmGetCivID("caribs"))
		{  
			int caribs6VillageID = -1;
			int caribs6VillageType = rmRandInt(1,5);
			caribs6VillageID = rmCreateGrouping("caribs6 city", "native carib village 0"+caribs6VillageType);
			rmSetGroupingMinDistance(caribs6VillageID, 0.0);
			rmSetGroupingMaxDistance(caribs6VillageID, 7.0);
			rmAddGroupingConstraint(caribs6VillageID, avoidImpassableLand);
//			rmPlaceGroupingAtLoc(caribs6VillageID, 0, 0.40, 0.21);  // Place near SE end of island.  .40, 18
		} 
	}

   // *****************MOUNTAIN IN CENTER**************************************
   // Always create a mountain in center of island.
   // Really big mountain for 8 players, big mountain for 6 or 7 players, and small mountain for 5 or less players.

		int HighMesaID=rmCreateArea("highzone");
		if ( cNumberNonGaiaPlayers < 6 )
		{
			rmSetAreaSize(HighMesaID, rmAreaTilesToFraction(1100), rmAreaTilesToFraction(1100));  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
		}
		else if ( cNumberNonGaiaPlayers < 8 )
		{
			rmSetAreaSize(HighMesaID, rmAreaTilesToFraction(1400), rmAreaTilesToFraction(1400));  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
		}
		else
		{
			rmSetAreaSize(HighMesaID, rmAreaTilesToFraction(1600), rmAreaTilesToFraction(1600));  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
		}
		rmSetAreaWarnFailure(HighMesaID, false);
		rmSetAreaCoherence(HighMesaID, 0.88);
		rmSetAreaBaseHeight(HighMesaID, 4.0);
		rmSetAreaSmoothDistance(HighMesaID, 40);
		rmSetAreaElevationType(HighMesaID, cElevTurbulence);
		rmSetAreaElevationVariation(HighMesaID, 3.0);
		rmSetAreaElevationMinFrequency(HighMesaID, 0.09);
		rmSetAreaElevationOctaves(HighMesaID, 3);
		rmSetAreaElevationPersistence(HighMesaID, 0.2);
		rmSetAreaElevationNoiseBias(HighMesaID, 1);
		rmSetAreaLocation(HighMesaID, 0.50, 0.72); 
//		rmAddAreaInfluenceSegment(HighMesaID, 0.48, 0.68, 0.5, 0.65);  
//		rmAddAreaInfluenceSegment(HighMesaID, 0.46, 0.65, 0.53, 0.63); 
//		rmAddAreaInfluenceSegment(HighMesaID, 0.53, 0.70, 0.53, 0.63); 
//		rmAddAreaInfluenceSegment(HighMesaID, 0.53, 0.70, 0.48, 0.68); 
		rmBuildArea(HighMesaID);

		int smallCliffHeight=rmRandInt(0,10);
		int smallMesaID=rmCreateArea("small mesa"+i);
		if ( cNumberNonGaiaPlayers < 6 )
		{
			rmSetAreaSize(smallMesaID, rmAreaTilesToFraction(1100), rmAreaTilesToFraction(1100));  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
		}
		else if ( cNumberNonGaiaPlayers < 8 )
		{
			rmSetAreaSize(smallMesaID, rmAreaTilesToFraction(1400), rmAreaTilesToFraction(1400));  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
		}
		else
		{
			rmSetAreaSize(smallMesaID, rmAreaTilesToFraction(1600), rmAreaTilesToFraction(1600));  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
		}
		rmSetAreaWarnFailure(smallMesaID, false);
		rmSetAreaCliffType(smallMesaID, "AfricanRainforest2");
		rmAddAreaToClass(smallMesaID, rmClassID("canyon"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(smallMesaID, 1, 1.0, 0.1, 1.0, 0);
		rmSetAreaCliffEdge(smallMesaID, 6, .14, 0, 1.0, 0);
//		rmSetAreaCliffHeight(smallMesaID, 5, 1.0, 1.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(smallMesaID, 0.88);
         rmSetAreaForestType(smallMesaID, "Tahiti Forest");
         rmSetAreaForestDensity(smallMesaID, 0.9);
         rmSetAreaForestClumpiness(smallMesaID, 0.4);
         rmSetAreaForestUnderbrush(smallMesaID, 0.5);
		rmSetAreaLocation(smallMesaID, 0.55, 0.64); 
		rmAddAreaInfluenceSegment(smallMesaID, 0.48, 0.68, 0.5, 0.65);  
		rmAddAreaInfluenceSegment(smallMesaID, 0.46, 0.65, 0.53, 0.63); 
		rmAddAreaInfluenceSegment(smallMesaID, 0.53, 0.70, 0.53, 0.63); 
		rmAddAreaInfluenceSegment(smallMesaID, 0.53, 0.70, 0.48, 0.68); 
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
	rmAddObjectDefItem(playerGoldID, "mine", 1, 0);
	rmSetObjectDefMinDistance(playerGoldID, 12.0);
	rmSetObjectDefMaxDistance(playerGoldID, 20.0);
	rmAddObjectDefConstraint(playerGoldID, avoidAll);
    rmAddObjectDefConstraint(playerGoldID, avoidImpassableLand);

	//Prepare to place player starting Crates (mostly food)
	int playerCrateID=rmCreateObjectDef("starting crates");
	rmAddObjectDefItem(playerCrateID, "crateOfWood", 2, 6.0);
	rmSetObjectDefMinDistance(playerCrateID, 6);
	rmSetObjectDefMaxDistance(playerCrateID, 10);
	rmAddObjectDefConstraint(playerCrateID, avoidAll);
	rmAddObjectDefConstraint(playerCrateID, shortAvoidImpassableLand);

	//Prepare to place player starting Berries
	int playerBerriesID=rmCreateObjectDef("player berries");
	rmAddObjectDefItem(playerBerriesID, "Breadfruit", rmRandInt(3,4), 4.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerBerriesID, 21);
    rmSetObjectDefMaxDistance(playerBerriesID, 26);		
	rmAddObjectDefConstraint(playerBerriesID, avoidAll);
    rmAddObjectDefConstraint(playerBerriesID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerBerriesID, true);

	//Prepare to place player starting Turkeys
	int playerTurkeyID=rmCreateObjectDef("player turkeys");
    rmAddObjectDefItem(playerTurkeyID, "CoconutCrab", rmRandInt(8,9), 5.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerTurkeyID, 14);
	rmSetObjectDefMaxDistance(playerTurkeyID, 19);	
	rmAddObjectDefConstraint(playerTurkeyID, avoidAll);
    rmAddObjectDefConstraint(playerTurkeyID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerTurkeyID, true);

	//Prepare to place player starting trees
	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "TreeCaribbean", 1, 0.0);
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
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i)+0.2);
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));   
	rmSetObjectDefMinDistance(playerGoldID, 33.0);
	rmSetObjectDefMaxDistance(playerGoldID, 38.0);
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

	// ***************** SCATTERED RESOURCES **************************************
	// Scattered FORESTS
   int forestTreeID = 0;
   numTries=12*cNumberNonGaiaPlayers;
   int failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest, "Tahiti Forest");
         rmSetAreaForestDensity(forest, 0.7);
         rmSetAreaForestClumpiness(forest, 0.4);
         rmSetAreaForestUnderbrush(forest, 0.5);
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
	rmSetStatusText("",0.80);

	// Scattered MINES
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "mine", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(goldID, avoidTC);
	rmAddObjectDefConstraint(goldID, avoidCW);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidCoin);
    rmAddObjectDefConstraint(goldID, avoidImpassableLand);
	rmAddObjectDefConstraint(goldID, smallMesaConstraint);
	rmPlaceObjectDefInArea(goldID, 0, bigIslandID, cNumberNonGaiaPlayers*3);
	rmPlaceObjectDefInArea(goldID, 0, bigIsland2ID, cNumberNonGaiaPlayers*2);

	// Scattered BERRRIES		
	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "Breadfruit", rmRandInt(4,6), 6.0);  // (3,5) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(berriesID, avoidTC);
	rmAddObjectDefConstraint(berriesID, avoidTP);   //Just added this, to make sure berries don't stomp on Trade Post sockets
	rmAddObjectDefConstraint(berriesID, avoidCW);
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
	rmAddObjectDefConstraint(berriesID, smallMesaConstraint);
	rmPlaceObjectDefInArea(berriesID, 0, bigIslandID, cNumberNonGaiaPlayers*4);   //was *4
	rmPlaceObjectDefInArea(berriesID, 0, bigIsland2ID, cNumberNonGaiaPlayers*3);   //was *4

	// Just a FEW scattered TURKEYS
	int turkeyID=rmCreateObjectDef("random turkeys");
	rmAddObjectDefItem(turkeyID, "BerryBush", rmRandInt(2,3), 6.0);  // (2,4) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(turkeyID, 0.0);
	rmSetObjectDefMaxDistance(turkeyID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(turkeyID, avoidTC);
	rmAddObjectDefConstraint(turkeyID, avoidCW);
	rmAddObjectDefConstraint(turkeyID, avoidRandomTurkeys);
	//rmAddObjectDefConstraint(turkeyID, avoidAll);
	//rmAddObjectDefConstraint(turkeyID, avoidRandomBerries);
	rmAddObjectDefConstraint(turkeyID, avoidImpassableLand);
	rmAddObjectDefConstraint(turkeyID, smallMesaConstraint);
	rmPlaceObjectDefInArea(turkeyID, 0, bigIslandID, cNumberNonGaiaPlayers*4);   //Was *2 scattered Turkeys for awhile, but players wanted more fast food.
	rmPlaceObjectDefInArea(turkeyID, 0, bigIsland2ID, cNumberNonGaiaPlayers*3);   //Was *2 scattered Turkeys for awhile, but players wanted more fast food.

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
	rmPlaceObjectDefInArea(nugget1, 0, bigIslandID, cNumberNonGaiaPlayers*rmRandInt(3,4));
	rmPlaceObjectDefInArea(nugget1, 0, bigIsland2ID, cNumberNonGaiaPlayers*1);

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
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidWater20);
	rmAddObjectDefConstraint(nugget2, smallMesaConstraint);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget2, 0, bigIslandID, cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(nugget2, 0, bigIsland2ID, cNumberNonGaiaPlayers+2);

	//Place Sheep -- added Sheep 11-28-05
	int sheepID=rmCreateObjectDef("sheep");
	rmAddObjectDefItem(sheepID, "pig", 2, 4.0);
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
	rmPlaceObjectDefAtLoc(sheepID, 0, 0.46, 0.48, cNumberNonGaiaPlayers*1);

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place Whales as much in big west bay only as possible --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));		//Distance whales will be placed from the starting spot (below)
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3 + rmRandInt(2,3));  //Was .43, .67 // .37, .66 -- The whales will be placed from this spot. 1 per player, plus 1 or 2 more.

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
 
  int nuggetW= rmCreateObjectDef("nugget water"); 
  rmAddObjectDefItem(nuggetW, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(5, 5);
  rmSetObjectDefMinDistance(nuggetW, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(nuggetW, rmXFractionToMeters(0.25));
  rmAddObjectDefConstraint(nuggetW, avoidLand);
  rmAddObjectDefConstraint(nuggetW, avoidNuggetWater);
//rmAddObjectDefConstraint(nuggetW, avoidLagoon);
//rmAddObjectDefConstraint(nuggetW, avoidFish);
		rmPlaceObjectDefAtLoc(nuggetW, 0, 0.3, 0.5, 4*cNumberNonGaiaPlayers);	
		rmPlaceObjectDefAtLoc(nuggetW, 0, 0.7, 0.5, 4*cNumberNonGaiaPlayers);	
 

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.99);

	// RANDOM FALE

	int FalevsFaleID=rmCreateTypeDistanceConstraint("fale v fale", "Fale", 25.0);	//Was 8.0
   int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 30.0);
    int faleCount = cNumberNonGaiaPlayers+2;
	int randomFaleID= -1;

for(i =0; <faleCount)
{
		randomFaleID = rmCreateGrouping("native "+i, "Atoll Fale " + rmRandInt(1,4));
		rmSetGroupingMinDistance(randomFaleID, 0.0);
		rmSetGroupingMaxDistance(randomFaleID, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(randomFaleID, avoidImpassableLand);
		rmAddGroupingToClass(randomFaleID, rmClassID("natives"));
		rmAddGroupingConstraint(randomFaleID, avoidTC);
		rmAddGroupingConstraint(randomFaleID, avoidCW);
		rmAddGroupingConstraint(randomFaleID, avoidAll); 
		rmAddGroupingConstraint(randomFaleID, FalevsFaleID); 
		rmAddGroupingConstraint(randomFaleID, avoidNatives); 
		rmAddGroupingConstraint(randomFaleID, smallMesaConstraint);	
		rmPlaceGroupingInArea(randomFaleID, 0, bigIsland2ID, 1);
}

  // King of the Hill (added 2026-11 for WoL): centre, on the land between the two parts of the island
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




