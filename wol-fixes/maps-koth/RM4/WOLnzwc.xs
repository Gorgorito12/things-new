// New Zealand West Coast
// Started with modified Hispanola
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
		subCiv0=rmGetCivID("Wharenui");
		rmEchoInfo("subCiv0 is Wharenui "+subCiv0);
		if (subCiv0 >= 0)
		rmSetSubCiv(0, "Wharenui");

		subCiv1=rmGetCivID("Wharenui");
		rmEchoInfo("subCiv1 is Wharenui "+subCiv1);
		if (subCiv1 >= 0)
		rmSetSubCiv(1, "Wharenui");

		subCiv2=rmGetCivID("Wharenui");
		rmEchoInfo("subCiv2 is Wharenui "+subCiv2);
		if (subCiv2 >= 0)
		rmSetSubCiv(2, "Wharenui");
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
	int playerTiles=35500;
	if (cNumberNonGaiaPlayers >4)   // If more than 4 players...
		playerTiles = 28000;		// ...give this many tiles per player.
	if (cNumberNonGaiaPlayers >7)	// If more than 7 players...
		playerTiles = 22000;		// ...give this many tiles per player.	
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, 300); //fixed size of the z axis to 300

	// Set up default water type.
	rmSetSeaLevel(-1.0);          
	rmSetSeaType("Araucania Central Coast");
	rmSetBaseTerrainMix("araucania_grass_a");
	rmSetMapType("newzealand");
	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetLightingSet("greatplainstest");

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
	rmDefineClass("classCliff");
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
	int IceConstraint=rmCreateClassDistanceConstraint("avoid ice", rmClassID("canyon"), 10.0);


	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fishSalmon", 25.0);	
	
	int shortCliffConstraint=rmCreateClassDistanceConstraint("short cliff vs. cliff", rmClassID("classCliff"), 22.0);
			// was 50.0
	// int fishVsFishTarponID=rmCreateTypeDistanceConstraint("fish v fish2", "fishTarpon", 20.0);  // was 40.0 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 20.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "HumpbackWhale", 30.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 25.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 30.0);
	int shortForestConstraint=rmCreateClassDistanceConstraint("forest vs. forest short", rmClassID("classForest"), 19.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int avoidCoin=-1;
	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "MineGreenstone", 55.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "MineGreenstone", 65.0);	// 85.0 seems the best for event minegold distribution.  This number tells minegolds how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "BerryBush", 40.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random kiwis", "Kiwi", 35.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys2=rmCreateTypeDistanceConstraint("avoid random kakapos", "Kakapo", 35.0);	//Attempting to spread them out more evenly.
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 54.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 40.0);  //Added sheep 11-28-05 JSB
	int avoidNuggetWater=rmCreateTypeDistanceConstraint("nugget vs. nugget water", "abstractNugget", 60.0);

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

	// land 0, for consistency in the water
	int bigIsland0ID=rmCreateArea("Coast0");
	rmSetAreaSize(bigIsland0ID, 0.75, 0.75);	
	rmSetAreaCoherence(bigIsland0ID, 0.99);
	rmSetAreaBaseHeight(bigIsland0ID, -0.9);
	rmSetAreaSmoothDistance(bigIsland0ID, 20);
	rmSetAreaMix(bigIsland0ID, "araucania_grass_b");
//	rmSetAreaTerrainType(bigIsland0ID, "yukon\ground1_yuk");
//	rmAddAreaToClass(bigIsland0ID, classIsland);
//	rmAddAreaConstraint(bigIsland0ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIsland0ID, false);
	rmSetAreaElevationType(bigIsland0ID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIsland0ID, 3.0);
	rmSetAreaElevationMinFrequency(bigIsland0ID, 0.09);
	rmSetAreaElevationOctaves(bigIsland0ID, 3);
	rmSetAreaElevationPersistence(bigIsland0ID, 0.2);
	rmSetAreaElevationNoiseBias(bigIsland0ID, 1);
	rmAddAreaInfluenceSegment(bigIsland0ID, 0.99, 0.25, 0.01, 0.25);   
	    	
	// Make one big coast.  
	int bigIslandID=rmCreateArea("Coast");
	rmSetAreaSize(bigIslandID, 0.31, 0.31);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(bigIslandID, 0.7);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(bigIslandID, -0.9);
	rmSetAreaSmoothDistance(bigIslandID, 20);
	rmSetAreaMix(bigIslandID, "araucania_grass_b");
//	rmSetAreaTerrainType(bigIslandID, "yukon\ground1_yuk");
	rmAddAreaToClass(bigIslandID, classIsland);
	rmAddAreaConstraint(bigIslandID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 4.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmSetAreaElevationOctaves(bigIslandID, 3);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);
	rmAddAreaInfluenceSegment(bigIslandID, 0.99, 0.60, 0.01, 0.60);  
//	rmAddAreaInfluenceSegment(bigIslandID, 0.65, 0.72, 0.55, 0.55);  
//	rmAddAreaInfluenceSegment(bigIslandID, 0.45, 0.45, 0.35, 0.28);  
//	rmAddAreaInfluenceSegment(bigIslandID, 0.25, 0.15, 0.10, 0.00);  

	int rampID=rmCreateArea("central ramp");
	rmSetAreaSize(rampID, 0.024, 0.024);				
	rmSetAreaCoherence(rampID, 0.89);	
	rmSetAreaBaseHeight(rampID, 3.0);
	rmSetAreaSmoothDistance(rampID, 25);
	rmSetAreaMix(rampID, "patagonia_dirt");
	rmSetAreaTerrainType(rampID, "patagonia\ground_grass1_pat");
	rmSetAreaObeyWorldCircleConstraint(rampID, false);
	rmSetAreaElevationType(rampID, cElevTurbulence);
	rmSetAreaElevationVariation(rampID, 0.2);
	rmSetAreaElevationMinFrequency(rampID, 0.22);
	rmSetAreaElevationOctaves(rampID, 2);
	rmSetAreaElevationPersistence(rampID, 0.32);
	rmSetAreaElevationNoiseBias(rampID, 1);
	rmSetAreaLocation(rampID, .50, .40);
	rmAddAreaInfluenceSegment(rampID, 0.55, 0.40, 0.45, 0.40);

   	int ramp2ID=rmCreateArea("ramp 2");
	rmSetAreaSize(ramp2ID, 0.018, 0.018);				
	rmSetAreaCoherence(ramp2ID, 0.89);	
	rmSetAreaBaseHeight(ramp2ID, 3.0);
	rmSetAreaSmoothDistance(ramp2ID, 25);
	rmSetAreaMix(ramp2ID, "patagonia_dirt");
	rmSetAreaTerrainType(ramp2ID, "patagonia\ground_grass1_pat");
	rmSetAreaObeyWorldCircleConstraint(ramp2ID, false);
	rmSetAreaElevationType(ramp2ID, cElevTurbulence);
	rmSetAreaElevationVariation(ramp2ID, 0.2);
	rmSetAreaElevationMinFrequency(ramp2ID, 0.22);
	rmSetAreaElevationOctaves(ramp2ID, 2);
	rmSetAreaElevationPersistence(ramp2ID, 0.32);
	rmSetAreaElevationNoiseBias(ramp2ID, 1);
	rmSetAreaLocation(ramp2ID, .05, .40);
	rmAddAreaInfluenceSegment(ramp2ID, 0.06, 0.40, 0.01, 0.40);    

	int ramp3ID=rmCreateArea("ramp 3");
	rmSetAreaSize(ramp3ID, 0.018, 0.018);				
	rmSetAreaCoherence(ramp3ID, 0.89);	
	rmSetAreaBaseHeight(ramp3ID, 3.0);
	rmSetAreaSmoothDistance(ramp3ID, 25);
	rmSetAreaMix(ramp3ID, "patagonia_dirt");
	rmSetAreaTerrainType(ramp3ID, "patagonia\ground_grass1_pat");
	rmSetAreaObeyWorldCircleConstraint(ramp3ID, false);
	rmSetAreaElevationType(ramp3ID, cElevTurbulence);
	rmSetAreaElevationVariation(ramp3ID, 0.2);
	rmSetAreaElevationMinFrequency(ramp3ID, 0.22);
	rmSetAreaElevationOctaves(ramp3ID, 2);
	rmSetAreaElevationPersistence(ramp3ID, 0.32);
	rmSetAreaElevationNoiseBias(ramp3ID, 1);
	rmSetAreaLocation(ramp3ID, .95, .40);
	rmAddAreaInfluenceSegment(ramp3ID, 0.94, 0.40, 0.99, 0.40); 

	// Make one big ice cap.  
	int bigIsland2ID=rmCreateArea("Mountains1");
	rmSetAreaSize(bigIsland2ID, 0.43, 0.43);				
	rmSetAreaCoherence(bigIsland2ID, 0.94);	
	rmSetAreaCliffType(bigIsland2ID, "Patagonia");			
	rmSetAreaCliffEdge(bigIsland2ID, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(bigIsland2ID, 4.9, 1.0, 1.0);  //was rmRandInt(6, 8)
//	rmSetAreaBaseHeight(bigIsland2ID, 4.0);
//	rmSetAreaSmoothDistance(bigIsland2ID, 65);
	rmSetAreaMix(bigIsland2ID, "patagonia_grass");
	rmSetAreaTerrainType(bigIsland2ID, "patagonia\ground_grass1_pat");
	rmAddAreaToClass(bigIsland2ID, rmClassID("canyon"));
//	rmAddAreaConstraint(bigIsland2ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIsland2ID, false);
	rmSetAreaElevationType(bigIsland2ID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIsland2ID, 0.6);
	rmSetAreaElevationMinFrequency(bigIsland2ID, 0.22);
	rmSetAreaElevationOctaves(bigIsland2ID, 2);
	rmSetAreaElevationPersistence(bigIsland2ID, 0.32);
	rmSetAreaElevationNoiseBias(bigIsland2ID, 1);
	rmSetAreaLocation(bigIsland2ID, .50, .10);
	rmAddAreaInfluenceSegment(bigIsland2ID, 0.99, 0.10, 0.01, 0.10);    
		
		int inMts = rmCreateAreaConstraint("in mountains", bigIsland2ID);
		
	int bigIsland3ID=rmCreateArea("Mountain2");
	rmSetAreaSize(bigIsland3ID, 0.14, 0.14);				
	rmSetAreaCoherence(bigIsland3ID, 0.90);	
	rmSetAreaCliffType(bigIsland3ID, "Araucania Southern Coast");			
	rmSetAreaCliffEdge(bigIsland3ID, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(bigIsland3ID, rmRandInt(4, 4), 1.0, 1.0);  //was rmRandInt(6, 8)
	rmSetAreaBaseHeight(bigIsland3ID, 7.0);
//	rmSetAreaSmoothDistance(bigIsland2ID, 65);
	rmSetAreaMix(bigIsland3ID, "araucania_snow_a");
	rmSetAreaTerrainType(bigIsland3ID, "araucania\ground_snow2_ara");
	rmAddAreaToClass(bigIsland3ID, rmClassID("canyon"));
//	rmAddAreaConstraint(bigIsland2ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIsland3ID, false);
	rmSetAreaElevationType(bigIsland3ID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIsland3ID, 0.6);
	rmSetAreaElevationMinFrequency(bigIsland3ID, 0.22);
	rmSetAreaElevationOctaves(bigIsland3ID, 2);
	rmSetAreaElevationPersistence(bigIsland3ID, 0.32);
	rmSetAreaElevationNoiseBias(bigIsland3ID, 1);
	rmSetAreaLocation(bigIsland3ID, .50, .04);
	rmAddAreaInfluenceSegment(bigIsland3ID, 0.95, 0.04, 0.05, 0.04);
		
/*	int bigIsland4ID=rmCreateArea("Mountain3");
	rmSetAreaSize(bigIsland4ID, 0.31, 0.31);				
	rmSetAreaCoherence(bigIsland4ID, 0.95);	
	rmSetAreaCliffType(bigIsland4ID, "Araucania South");			
	rmSetAreaCliffEdge(bigIsland4ID, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(bigIsland4ID, rmRandInt(4, 4), 1.0, 1.0);  //was rmRandInt(6, 8)
	rmSetAreaBaseHeight(bigIsland4ID, 7.0);
//	rmSetAreaSmoothDistance(bigIsland2ID, 65);
//	rmSetAreaMix(bigIsland2ID, "rockies_snow");
	rmSetAreaTerrainType(bigIsland4ID, "araucania\ground_snow2_ara");
	rmAddAreaToClass(bigIsland4ID, rmClassID("canyon"));
//	rmAddAreaConstraint(bigIsland2ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIsland4ID, false);
	rmSetAreaElevationType(bigIsland4ID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIsland4ID, 0.6);
	rmSetAreaElevationMinFrequency(bigIsland4ID, 0.22);
	rmSetAreaElevationOctaves(bigIsland4ID, 2);
	rmSetAreaElevationPersistence(bigIsland4ID, 0.32);
	rmSetAreaElevationNoiseBias(bigIsland4ID, 1);
	rmSetAreaLocation(bigIsland4ID, .50, .04);
	rmAddAreaInfluenceSegment(bigIsland4ID, 0.95, 0.04, 0.05, 0.04);    */
		
		int inHills = rmCreateAreaConstraint("in Hills", bigIsland3ID);
		int avoidHills = rmCreateAreaDistanceConstraint("avoid hills", bigIsland3ID, 5.0);

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);

	rmSetAreaWarnFailure(bigIslandID, false);

	if (IslandLoc == 1)
	rmSetAreaLocation(bigIsland0ID, .5, .25);	
	rmSetAreaLocation(bigIslandID, .5, .5);		//Put the big island in exact middle of map.
	rmBuildArea(bigIsland0ID);
	rmBuildArea(bigIslandID);
	rmBuildArea(bigIsland2ID);
	rmBuildArea(bigIsland3ID);
	rmBuildArea(rampID);
    rmBuildArea(ramp2ID);
    rmBuildArea(ramp3ID);	
	   int numTriess=18 + 6*cNumberNonGaiaPlayers;
   
   for(i=0; <numTriess)
   {
      int cliffID=rmCreateArea("cliff"+i);
      //rmSetAreaSize(cliffID, rmAreaTilesToFraction(500), rmAreaTilesToFraction(1000));
	  rmSetAreaSize(cliffID, rmAreaTilesToFraction(60), rmAreaTilesToFraction(70));
      rmSetAreaWarnFailure(cliffID, false);
//	  rmSetAreaCliffType(cliffID, "Araucania South");
//	  rmSetAreaCliffEdge(cliffID, 1, 0.0, 0.1, 1.0, 0);
//     rmSetAreaCliffPainting(cliffID, true, true, true, 1.5, true);
//      rmSetAreaCliffHeight(cliffID, 12.5, 2.0, 0.5);
      	rmSetAreaBaseHeight(cliffID, rmRandFloat(22.0,28.0));
      rmSetAreaHeightBlend(cliffID, 2);
      rmAddAreaToClass(cliffID, rmClassID("classCliff")); 
      rmAddAreaConstraint(cliffID, inHills);
      rmAddAreaConstraint(cliffID, shortCliffConstraint);
      rmAddAreaConstraint(cliffID, avoidWater8);
   	rmSetAreaMix(cliffID, "yukon snow");
	rmSetAreaTerrainType(cliffID, "araucania\ground_snow4_ara");
      
//	  rmAddAreaConstraint(cliffID, avoidCliffEdge10);
//      rmAddAreaConstraint(cliffID, avoidImportantItem);
//      rmAddAreaConstraint(cliffID, avoidTradeRoute);
//	  rmAddAreaConstraint(cliffID, CentralHillConstraint);
//	  rmAddAreaConstraint(cliffID, avoidCoin);
      rmSetAreaMinBlobs(cliffID, 4);
      rmSetAreaMaxBlobs(cliffID, 6);
      rmSetAreaMinBlobDistance(cliffID, 16.0);
      rmSetAreaMaxBlobDistance(cliffID, 30.0);
      rmSetAreaSmoothDistance(cliffID, 5);
      rmSetAreaCoherence(cliffID, 0.45);
	rmSetAreaObeyWorldCircleConstraint(cliffID, false);
      rmBuildArea(cliffID);
   } 

	
    // Set up player areas.  -- Each team always placed along a line.  One team in NE, other in SW.
	
	float teamStartLoc = rmRandFloat(0.0, 1.0);

		if (cNumberTeams == 2 )
		{
			if (cNumberNonGaiaPlayers < 5)
			{
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.25, 0.57, 0.35, 0.57, 0.0, 0.1); //Team 0 is in the south 
			
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.75, 0.57, 0.65, 0.57, 0.0, 0.1); //Team 1 is in the north
			}
			else
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.25, 0.57, 0.65, 0.57, 0.0, 0.1); //Team 0 is in the north
						
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.75, 0.57, 0.35, 0.57, 0.0, 0.1); //Team 1 is in the south
			}
			}
			else
			{
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.15, 0.57, 0.43, 0.57, 0.0, 0.1); //Team 0 is in the south 
			
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.85, 0.57, 0.57, 0.57, 0.0, 0.1); //Team 1 is in the north
			}
			else
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.15, 0.57, 0.57, 0.57, 0.0, 0.1); //Team 0 is in the north
						
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.85, 0.57, 0.43, 0.57, 0.0, 0.1); //Team 1 is in the south
			}
		}
		}

	else
	{
		rmPlacePlayersLine(0.25, 0.57, 0.75, 0.57, 0.0, 0.3);
	}

	float playerFraction=rmAreaTilesToFraction(400);
	for(i=1; <cNumberPlayers)
	{
      // Create the Player's area.
      int id=rmCreateArea("Player"+i);
      rmSetPlayerArea(i, id);
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaLocPlayer(id, i);
      rmSetAreaMinBlobs(id, 1);
      	  rmSetAreaCoherence(id, 0.5);
//	  rmSetAreaMix(id, "greenland_snow");
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
			rmAddGroupingConstraint(caribsVillageID, IceConstraint);
//			rmPlaceGroupingAtLoc(caribsVillageID, 0, 0.69, 0.74);
		}	

		if (subCiv2 == rmGetCivID("caribs"))
		{  
			int caribs2VillageID = -1;
			int caribs2VillageType = rmRandInt(1,5);
			caribs2VillageID = rmCreateGrouping("caribs2 city", "native carib village 0"+caribs2VillageType);
			rmAddGroupingConstraint(caribs2VillageID, avoidImpassableLand);
			rmAddGroupingConstraint(caribs2VillageID, IceConstraint);
//			rmPlaceGroupingAtLoc(caribs2VillageID, 0, 0.31, 0.26);
		} 
	

	if (cNumberNonGaiaPlayers >4)  
	{
		if (subCiv1 == rmGetCivID("caribs"))
		{  
			int caribs3VillageID = -1;
			int caribs3VillageType = rmRandInt(1,5);
			if (caribs3VillageType == 3)
				caribs3VillageType = rmRandInt(1,2);
			caribs3VillageID = rmCreateGrouping("caribs3 city", "native carib village 0"+caribs3VillageType);
			rmSetGroupingMinDistance(caribs3VillageID, 0.0);
			rmSetGroupingMaxDistance(caribs3VillageID, 4.0);
			rmAddGroupingConstraint(caribs3VillageID, avoidImpassableLand);
			rmAddGroupingConstraint(caribs3VillageID, IceConstraint);
//			rmPlaceGroupingAtLoc(caribs3VillageID, 0, 0.58, 0.60);
		}	

		if (subCiv2 == rmGetCivID("caribs"))
		{  
			int caribs4VillageID = -1;
			int caribs4VillageType = rmRandInt(1,5);
			caribs4VillageID = rmCreateGrouping("caribs4 city", "native carib village 0"+caribs4VillageType);
			rmAddGroupingConstraint(caribs4VillageID, avoidImpassableLand);
			rmAddGroupingConstraint(caribs4VillageID, IceConstraint);
//			rmPlaceGroupingAtLoc(caribs4VillageID, 0, 0.42, 0.40);
		} 
	}		
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
			rmAddGroupingConstraint(caribs5VillageID, IceConstraint);
//			rmPlaceGroupingAtLoc(caribs5VillageID, 0, 0.50, 0.50);
		}	
		
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
	rmAddObjectDefConstraint(TCID, IceConstraint);
	rmAddObjectDefConstraint(TCID, avoidTC);
	rmAddObjectDefConstraint(TCID, avoidCW);
    	
	//Prepare to place Explorers, Explorer's dog, Explorer's Taun Taun, etc.
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 9.0);
	rmSetObjectDefMaxDistance(startingUnits, 18.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, IceConstraint);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);

	//Prepare to place player starting Mines 
	int playerGoldID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(playerGoldID, "MineGreenstone", 1, 0);
	rmSetObjectDefMinDistance(playerGoldID, 12.0);
	rmSetObjectDefMaxDistance(playerGoldID, 20.0);
	rmAddObjectDefConstraint(playerGoldID, avoidAll);
    rmAddObjectDefConstraint(playerGoldID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerGoldID, IceConstraint);

	//Prepare to place player starting Berries
	int playerBerriesID=rmCreateObjectDef("player berries");
	rmAddObjectDefItem(playerBerriesID, "berrybush", rmRandInt(4,6), 4.0);	
	rmSetObjectDefMinDistance(playerBerriesID, 21);
    rmSetObjectDefMaxDistance(playerBerriesID, 26);		
	rmAddObjectDefConstraint(playerBerriesID, avoidAll);
    rmAddObjectDefConstraint(playerBerriesID, avoidImpassableLand);
    rmAddObjectDefConstraint(playerBerriesID, IceConstraint);
    rmSetObjectDefCreateHerd(playerBerriesID, true);

	//Prepare to place player starting Turkeys
	int playerTurkeyID=rmCreateObjectDef("player Kiwi");
    rmAddObjectDefItem(playerTurkeyID, "Kiwi", rmRandInt(11,12), 6.0);
    rmSetObjectDefMinDistance(playerTurkeyID, 14);
	rmSetObjectDefMaxDistance(playerTurkeyID, 19);	
	rmAddObjectDefConstraint(playerTurkeyID, avoidAll);
	rmAddObjectDefConstraint(playerTurkeyID, IceConstraint);
    rmAddObjectDefConstraint(playerTurkeyID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerTurkeyID, true);

	//Prepare to place player starting trees
	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "TreeBayou", 1, 0.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
	rmSetObjectDefMinDistance(StartAreaTreeID, 13.0);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 20.0);
	
	int waterSpawnPointID = 0;
   	int playerWharenuiID = 0;

	// --------------- Make load bar move. ----------------------------------------------------------------------------`
	rmSetStatusText("",0.70);
   
	// *********** Place Home City Water Spawn Flag ***************************************************

	for(i=1; <cNumberPlayers)
   {
//rmCreateGrouping
    //Player Wharenui, in montanious zone
   	playerWharenuiID=rmCreateGrouping("player Wharenui"+i, "NZ Wharenui "+rmRandInt(1,5));
//    rmAddObjectDefItem(playerWharenuiID, "Wharenui", 1, 0.0);
	rmAddGroupingToClass(playerWharenuiID, rmClassID("classSocket")); 
//	rmSetGroupingMinDistance(playerWharenuiID, rmXFractionToMeters(0.02));
//	rmSetGroupingMaxDistance(playerWharenuiID, rmXFractionToMeters(0.15));	
	rmSetGroupingMinDistance(playerWharenuiID, 1.0);
	rmSetGroupingMaxDistance(playerWharenuiID, 10.0);	
//	rmAddGroupingConstraint(playerWharenuiID, avoidAll);
//	rmAddGroupingConstraint(playerWharenuiID, inMts);
//	rmAddGroupingConstraint(playerWharenuiID, avoidHills);
//	rmAddGroupingConstraint(playerWharenuiID, avoidWater8);
	rmAddGroupingConstraint(playerWharenuiID, avoidImpassableLand);
	  	
	if (cNumberTeams > 2) //ffa
	{
	int placedTC = rmPlaceObjectDefInArea(TCID, i, bigIslandID);
}
	else
	{
	rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
}
	    // Place TC and starting units
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));   
		rmPlaceObjectDefAtLoc(playerBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 
		rmPlaceObjectDefAtLoc(playerTurkeyID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));  										
		rmPlaceObjectDefAtLoc(playerTurkeyID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));  										
		rmPlaceGroupingAtLoc(playerWharenuiID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)) - 0.25);

		// Place player starting trees
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		// Place water spawn points for the players
		waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 10.0);  // ...Flag", 1, 1.0); - the first number is the number of flags.  The next number is the float distance.
		rmAddClosestPointConstraint(flagVsFlag);
		rmAddClosestPointConstraint(flagLand);
//		rmAddClosestPointConstraint(circleConstraint);
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
   numTries=8*cNumberNonGaiaPlayers;
   int failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(130), rmAreaTilesToFraction(300));
         rmSetAreaForestType(forest, "NZ Forest");
         rmSetAreaForestDensity(forest, 0.95);
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
         rmAddAreaConstraint(forest, IceConstraint); 
		 rmAddAreaConstraint(forest, avoidTC);
		 rmAddAreaConstraint(forest, avoidCW);
		 rmAddAreaConstraint(forest, avoidSocket);
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
          
   // mts trees
   int forestTree2ID = 0;
   int failCount2=0;
   for (i=0; <numTries)
      {   
         int forest2=rmCreateArea("forest2 "+i);
         rmSetAreaWarnFailure(forest2, false);
         rmSetAreaSize(forest2, rmAreaTilesToFraction(190), rmAreaTilesToFraction(330));
         rmSetAreaForestType(forest2, "NZ Forest 2");
         rmSetAreaForestDensity(forest2, 1.55);
         rmSetAreaForestClumpiness(forest2, 0.4);
         rmSetAreaForestUnderbrush(forest2, 0.0);
         rmSetAreaMinBlobs(forest2, 1);
         rmSetAreaMaxBlobs(forest2, 5);
         rmSetAreaMinBlobDistance(forest2, 16.0);
         rmSetAreaMaxBlobDistance(forest2, 40.0);
         rmSetAreaCoherence(forest2, 0.4);
         rmSetAreaSmoothDistance(forest2, 10);
         rmAddAreaToClass(forest2, rmClassID("classForest")); 
         rmAddAreaConstraint(forest2, shortForestConstraint);
         rmAddAreaConstraint(forest2, avoidAll);
         rmAddAreaConstraint(forest2, shortAvoidImpassableLand); 
         rmAddAreaConstraint(forest2, inMts); 
         rmAddAreaConstraint(forest2, avoidHills); 
		 rmAddAreaConstraint(forest2, avoidTC);
		 rmAddAreaConstraint(forest2, avoidCW);
		 rmAddAreaConstraint(forest2, avoidSocket);
         rmAddAreaConstraint(forest2, avoidTradeRoute); 
         if(rmBuildArea(forest2)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount2++;
            if(failCount2==5)
               break;
         }
         else
            failCount2=0; 
      } 
      
    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);

	// Scattered MINES
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "MineGreenstone", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(goldID, avoidTC);
	rmAddObjectDefConstraint(goldID, avoidHills);
	rmAddObjectDefConstraint(goldID, avoidCW);
	rmAddObjectDefConstraint(goldID, avoidSocket);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidCoin);
    rmAddObjectDefConstraint(goldID, avoidImpassableLand);
	rmPlaceObjectDefInArea(goldID, 0, bigIslandID, cNumberNonGaiaPlayers*3);

	int gold2ID = rmCreateObjectDef("random gold 2");
	rmAddObjectDefItem(gold2ID, "MineGreenstone", 1, 0);
	rmSetObjectDefMinDistance(gold2ID, 0.0);
	rmSetObjectDefMaxDistance(gold2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(gold2ID, avoidTC);
	rmAddObjectDefConstraint(gold2ID, avoidHills);
	rmAddObjectDefConstraint(gold2ID, avoidCW);
	rmAddObjectDefConstraint(gold2ID, avoidSocket);
	rmAddObjectDefConstraint(gold2ID, avoidAll);
	rmAddObjectDefConstraint(gold2ID, avoidCoin);
    rmAddObjectDefConstraint(gold2ID, avoidImpassableLand);
	rmPlaceObjectDefInArea(gold2ID, 0, bigIsland2ID, cNumberNonGaiaPlayers*3);
	
	// Berries
	int berriesID=rmCreateObjectDef("berries");
	rmAddObjectDefItem(berriesID, "berrybush", 5, 5.0); 
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(berriesID, avoidTC);
	rmAddObjectDefConstraint(berriesID, avoidTP);
	rmAddObjectDefConstraint(berriesID, avoidCW);
	rmAddObjectDefConstraint(berriesID, avoidSocket);
	rmAddObjectDefConstraint(berriesID, IceConstraint);
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
	rmPlaceObjectDefInArea(berriesID, 0, bigIslandID, cNumberNonGaiaPlayers);

	// Just a FEW scattered KIWIS
	int turkeyID=rmCreateObjectDef("random kiwi");
	rmAddObjectDefItem(turkeyID, "Kiwi", rmRandInt(11,12), 6.0);  // (2,4) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(turkeyID, 0.0);
	rmSetObjectDefMaxDistance(turkeyID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(turkeyID, avoidTC);
	rmAddObjectDefConstraint(turkeyID, IceConstraint);
	rmAddObjectDefConstraint(turkeyID, avoidCW);
	rmAddObjectDefConstraint(turkeyID, avoidRandomTurkeys);
	//rmAddObjectDefConstraint(turkeyID, avoidAll);
	//rmAddObjectDefConstraint(turkeyID, avoidRandomBerries);
	rmAddObjectDefConstraint(turkeyID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(turkeyID, true);
	rmPlaceObjectDefInArea(turkeyID, 0, bigIslandID, cNumberNonGaiaPlayers*5);   //Was *2 scattered Turkeys for awhile, but players wanted more fast food.

	// Just a FEW scattered KAKAPOS
	int turkey2ID=rmCreateObjectDef("random kakapo");
	rmAddObjectDefItem(turkey2ID, "Kakapo", rmRandInt(7,8), 4.0);
	rmSetObjectDefMinDistance(turkey2ID, 0.0);
	rmSetObjectDefMaxDistance(turkey2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(turkey2ID, avoidTC);
	rmAddObjectDefConstraint(turkey2ID, avoidHills);
	rmAddObjectDefConstraint(turkey2ID, inMts);
	rmAddObjectDefConstraint(turkey2ID, avoidCW);
	rmAddObjectDefConstraint(turkey2ID, avoidRandomTurkeys2);
	rmAddObjectDefConstraint(turkey2ID, avoidSocket);
	//rmAddObjectDefConstraint(turkeyID, avoidRandomBerries);
	rmAddObjectDefConstraint(turkey2ID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(turkey2ID, true);
	rmPlaceObjectDefInArea(turkey2ID, 0, bigIsland2ID, cNumberNonGaiaPlayers*5);   //Was *2 scattered Turkeys for awhile, but players wanted more fast food.

	// Define and place Nuggets
	// Easier nuggets
	int nugget1= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNugget);
	rmAddObjectDefConstraint(nugget1, IceConstraint);
	rmAddObjectDefConstraint(nugget1, avoidTradeRoute);
	//rmAddObjectDefConstraint(nugget1, avoidCW);
	rmAddObjectDefConstraint(nugget1, avoidAll);
	rmAddObjectDefConstraint(nugget1, avoidWater8);
	rmAddObjectDefConstraint(nugget1, avoidSocket);
//	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget1, 0, bigIslandID, cNumberNonGaiaPlayers*rmRandInt(3,4));

	// Tougher nuggets
	int nugget2= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget2, 0.0);
	rmSetNuggetDifficulty(2, 2);
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNugget);
	rmAddObjectDefConstraint(nugget2, avoidHills);
	rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget2, avoidTC);
	rmAddObjectDefConstraint(nugget2, avoidCW);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidSocket);
	rmAddObjectDefConstraint(nugget2, avoidWater8);
//	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget2, 0, bigIslandID, cNumberNonGaiaPlayers);

	int nugget3= rmCreateObjectDef("nugget special"); 
	rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget3, 0.0);
	rmSetNuggetDifficulty(3, 3);
	rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget3, avoidNugget);
	rmAddObjectDefConstraint(nugget3, avoidHills);
	rmAddObjectDefConstraint(nugget3, inMts);
	rmAddObjectDefConstraint(nugget3, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget3, avoidTC);
	rmAddObjectDefConstraint(nugget3, avoidCW);
	rmAddObjectDefConstraint(nugget3, avoidAll);
	rmAddObjectDefConstraint(nugget3, avoidSocket);
	rmAddObjectDefConstraint(nugget3, avoidWater8);
//	rmAddObjectDefConstraint(nugget3, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget3, 0, bigIsland2ID, 2*cNumberNonGaiaPlayers + 1);

	//Place Sheep
	int sheepID=rmCreateObjectDef("sheep");
	rmAddObjectDefItem(sheepID, "sheep", 3, 6.0);
	rmSetObjectDefMinDistance(sheepID, 0.0);
	rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(sheepID, avoidSheep);
	rmAddObjectDefConstraint(sheepID, avoidAll);
	rmAddObjectDefConstraint(sheepID, avoidSocket);
	rmAddObjectDefConstraint(sheepID, IceConstraint);
	rmAddObjectDefConstraint(sheepID, avoidTradeRoute);
	rmAddObjectDefConstraint(sheepID, avoidTC);
	rmAddObjectDefConstraint(sheepID, avoidCW);
	rmAddObjectDefConstraint(sheepID, longPlayerConstraint);
	rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(sheepID, 0, 0.46, 0.48, cNumberNonGaiaPlayers*4);

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place Whales as much in big west bay only as possible --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));		//Distance whales will be placed from the starting spot (below)
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3 + rmRandInt(1,2));  //Was .43, .67 // .37, .66 -- The whales will be placed from this spot. 1 per player, plus 1 or 2 more.

	// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------

	int fishID=rmCreateObjectDef("fish mahi");
	rmAddObjectDefItem(fishID, "FishMahi", 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
//	rmAddObjectDefConstraint(fishID, fishVsWhaleID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 12*cNumberNonGaiaPlayers); 

/*	
	int fish2ID=rmCreateObjectDef("fish Tarpon");
	rmAddObjectDefItem(fish2ID, "ypFishTuna", 1, 0.0);
	rmSetObjectDefMinDistance(fish2ID, 0.0);
	rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
//	rmAddObjectDefConstraint(fish2ID, fishVsFishTarponID);
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
  rmSetObjectDefMaxDistance(nuggetW, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(nuggetW, avoidLand);
  rmAddObjectDefConstraint(nuggetW, avoidNuggetWater);
  rmPlaceObjectDefAtLoc(nuggetW, 0, 0.5, 0.5, cNumberNonGaiaPlayers*4);
  
    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.99);

	// RANDOM TREES

	int randomTreeID=rmCreateObjectDef("random tree");
	rmAddObjectDefItem(randomTreeID, "TreeBayou", 1, 0.0);
	rmSetObjectDefMinDistance(randomTreeID, 0.0);
	rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
	rmAddObjectDefConstraint(randomTreeID, avoidTC);
	rmAddObjectDefConstraint(randomTreeID, IceConstraint);
	rmAddObjectDefConstraint(randomTreeID, avoidCW);
	rmAddObjectDefConstraint(randomTreeID, avoidAll); 
	rmAddObjectDefConstraint(randomTreeID, avoidSocket);
	rmPlaceObjectDefInArea(randomTreeID, 0, bigIslandID, 8*cNumberNonGaiaPlayers);   //Scatter 8 random trees per player.


  // King of the Hill (added 2026-11 for WoL): a long strip; first open land on the line that splits the teams
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
