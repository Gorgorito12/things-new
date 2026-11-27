// Socotra Island
// Need Trees

include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";

// Trigos, to put the resources in their site
float PI = 3.141592;

float _pow(float n = 0,int x = 0) {
	float r = n;
	for(i = 1; < x) {
		r = r * n;
	}
	return (r);
}

float _atan(float n = 0) {
	float m = n;
	if(n > 1) m = 1.0 / n;
	if(n < -1) m = -1.0 / n;
	float r = m;
	for(i = 1; < 100) {
		int j = i * 2 + 1;
		float k = _pow(m,j) / j;
		if(k == 0) break;
		if(i % 2 == 0) r = r + k;
		if(i % 2 == 1) r = r - k;
	}
	if(n > 1 || n < -1) r = PI / 2.0 - r;
	if(n < -1) r = 0.0 - r;
	return (r);
}

float _atan2(float z = 0,float x = 0) {
	if(x > 0) return (_atan(z / x));
	if(x < 0) {
		if(z < 0) return (_atan(z / x) - PI);
		if(z > 0) return (_atan(z / x) + PI);
		return (PI);
	}
	if(z > 0) return (PI / 2.0);
	if(z < 0) return (0.0 - (PI / 2.0));
	return (0);
}

float _fact(float n = 0) {
	float r = 1;
	for(i = 1; <= n) {
		r = r * i;
	}
	return (r);
}

float _cos(float n = 0) {
	float r = 1;
	for(i = 1; < 100) {
		int j = i * 2;
		float k = _pow(n,j) / _fact(j);
		if(k == 0) break;
		if(i % 2 == 0) r = r + k;
		if(i % 2 == 1) r = r - k;
	}
	return (r);
}

float _sin(float n = 0) {
	float r = n;
	for(i = 1; < 100) {
		int j = i * 2 + 1;
		float k = _pow(n,j) / _fact(j);
		if(k == 0) break;
		if(i % 2 == 0) r = r + k;
		if(i % 2 == 1) r = r - k;
	}
	return (r);
}

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

	int whichVariation=-1;
	whichVariation = rmRandInt(1,3);

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
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Set up default water type.
	rmSetSeaLevel(-3.0);          
	rmSetSeaType("Maltese Coast");
	rmSetBaseTerrainMix("caribbean grass");
	rmSetMapType("AFRICANsavannah");
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
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 2.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "HumpbackWhale", 40.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 17.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
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
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "SugarCaneBush", 50.0);	//Attempting to spread them out more evenly.
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
	int bigIsland0ID=rmCreateArea("no big lone island");
	rmSetAreaSize(bigIsland0ID, 0.34, 0.34);
	rmSetAreaCoherence(bigIsland0ID, 0.90);
	rmSetAreaBaseHeight(bigIsland0ID, -2.0);
	rmSetAreaSmoothDistance(bigIsland0ID, 20);
	rmSetAreaMix(bigIsland0ID, "texas_dirt");
//	rmAddAreaToClass(bigIsland0ID, classIsland);
//	rmSetAreaCliffType(bigIsland0ID, "Caribbean");
//	rmSetAreaCliffEdge(bigIsland0ID, 1, 1.0, 0.1, 1.0, 0);
//	rmSetAreaCliffHeight(bigIsland0ID, rmRandInt(2, 2.1), 1.0, 1.0);  //was rmRandInt(6, 8)
//	rmAddAreaConstraint(bigIsland0ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIsland0ID, false);
	rmSetAreaElevationType(bigIsland0ID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIsland0ID, 2.0);
	rmSetAreaElevationMinFrequency(bigIsland0ID, 0.09);
	rmSetAreaElevationOctaves(bigIsland0ID, 3);
	rmSetAreaElevationPersistence(bigIsland0ID, 0.2);
	rmSetAreaElevationNoiseBias(bigIsland0ID, 1);
	rmAddAreaInfluenceSegment(bigIsland0ID, 0.75, 0.30, 0.50, 0.40);  
	rmAddAreaInfluenceSegment(bigIsland0ID, 0.50, 0.40, 0.35, 0.45);  
	rmAddAreaInfluenceSegment(bigIsland0ID, 0.35, 0.45, 0.25, 0.65);  
	rmAddAreaInfluenceSegment(bigIsland0ID, 0.25, 0.65, 0.35, 0.85);  
	rmAddAreaInfluenceSegment(bigIsland0ID, 0.35, 0.85, 0.40, 0.70);  
	rmAddAreaInfluenceSegment(bigIsland0ID, 0.40, 0.70, 0.70, 0.50);  
	rmAddAreaInfluenceSegment(bigIsland0ID, 0.70, 0.50, 0.75, 0.30);  

	// Make another big island.  
	int bigIslandID=rmCreateArea("big lone island");
	rmSetAreaSize(bigIslandID, 0.22, 0.22);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(bigIslandID, 0.90);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(bigIslandID, 3.0);
	rmSetAreaSmoothDistance(bigIslandID, 20);
	rmSetAreaMix(bigIslandID, "texas_dirt");
	rmAddAreaToClass(bigIslandID, classIsland);
	rmSetAreaCliffType(bigIslandID, "Levant");
	rmSetAreaCliffEdge(bigIslandID, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(bigIslandID, rmRandInt(4, 4), 1.0, 1.0);  //was rmRandInt(6, 8)
//	rmAddAreaConstraint(bigIslandID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 2.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmSetAreaElevationOctaves(bigIslandID, 1);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);
	
	if (IslandLoc == 1)
	rmSetAreaLocation(bigIsland0ID, .5, .5);		//Put the big island in exact middle of map.
	rmSetAreaLocation(bigIslandID, .5, .5);		//Put the big island in exact middle of map.
	rmBuildArea(bigIsland0ID);
	rmBuildArea(bigIslandID);

	float island2size = -1;
	if(cNumberNonGaiaPlayers > 3)
	island2size = 0.05;
	else if (cNumberNonGaiaPlayers > 5)
	island2size = 0.075;
	else if (cNumberNonGaiaPlayers > 7)
	island2size = 0.1;
	else
	island2size = 0.025;

 	// Make another another big island.  
	int bigIsland2ID=rmCreateArea("big lone island 2");
	rmSetAreaSize(bigIsland2ID, island2size, island2size);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(bigIsland2ID, 0.99);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(bigIsland2ID, 3.0);
//	rmSetAreaSmoothDistance(bigIsland2ID, 20);
	rmSetAreaMix(bigIsland2ID, "texas_dirt");
//	rmAddAreaToClass(bigIsland2ID, rmClassID("canyon"));
	rmSetAreaCliffType(bigIsland2ID, "Levant");
	rmSetAreaCliffEdge(bigIsland2ID, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(bigIsland2ID, rmRandInt(11, 12), 1.0, 1.0);  //was rmRandInt(6, 8)
//	rmAddAreaConstraint(bigIsland2ID, islandConstraint);
//	rmSetAreaObeyWorldCircleConstraint(bigIsland2ID, false);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);

	rmSetAreaWarnFailure(bigIslandID, false);

	rmSetAreaLocation(bigIsland2ID, .5, .5);		//Put the big island in exact middle of map.
	rmBuildArea(bigIsland2ID);
	
    // Set up player areas.  -- Each team always placed along a line.  One team in NE, other in SW.
	
//	float teamStartLoc = rmRandFloat(0.0, 1.0);  
	float aValue = 1.0/cNumberNonGaiaPlayers;

		if (cNumberTeams == 2 )
		{
		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.01, 0.00);
		   rmPlacePlayersCircular(0.20, 0.20, 0);
			
			rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.01+aValue, 0.00+aValue);
		   rmPlacePlayersCircular(0.20, 0.20, 0);
		}
/*		else if (cNumberTeams == 3)
		{
		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.01, 0.00);
		   rmPlacePlayersCircular(0.20, 0.20, 0);
			
			rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.01+aValue, 0.00+aValue);
		   rmPlacePlayersCircular(0.20, 0.20, 0);
		   
			rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.01+2*aValue, 0.00+2*aValue);
		   rmPlacePlayersCircular(0.20, 0.20, 0);
		}
		else if (cNumberTeams == 4)
		{
		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.01, 0.00);
		   rmPlacePlayersCircular(0.20, 0.20, 0);
			
			rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.01+aValue, 0.00+aValue);
		   rmPlacePlayersCircular(0.20, 0.20, 0);
		   
			rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.01+2*aValue, 0.00+2*aValue);
		   rmPlacePlayersCircular(0.20, 0.20, 0);
		   
			rmSetPlacementTeam(3);
		   rmSetPlacementSection(0.01+3*aValue, 0.00+3*aValue);
		   rmPlacePlayersCircular(0.20, 0.20, 0);
		}
*/
	else //ffa
	{
//  		rmSetPlacementSection(0.04, 0.82);
		rmPlacePlayersCircular(0.20, 0.20, 0.0);
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
	float cliffSize = cNumberNonGaiaPlayers*cNumberNonGaiaPlayers*0.0019;
		int smallCliffHeight=rmRandInt(0,10);
		int smallMesaID=rmCreateArea("small mesa"+i);
		rmSetAreaSize(smallMesaID, cliffSize, cliffSize);
		rmSetAreaWarnFailure(smallMesaID, false);
		rmSetAreaCliffType(smallMesaID, "Texas");
		rmAddAreaToClass(smallMesaID, rmClassID("canyon"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(smallMesaID, 1, 1.0, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(smallMesaID, rmRandInt(9, 11), 1.0, 1.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(smallMesaID, 0.65);
		rmSetAreaLocation(smallMesaID, 0.5, 0.5); 
		rmBuildArea(smallMesaID);


	// Special AREA CONSTRAINTS and use it to make resources avoid the mountain in center:
		int smallMesaConstraint = rmCreateAreaDistanceConstraint("avoid Small Mesa", bigIsland2ID, 4.0);
		int bigMesaConstraint = rmCreateAreaDistanceConstraint("avoid Big Mesa", bigIslandID, 4.0);
		
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
	rmSetObjectDefMinDistance(playerGoldID, 0.0);
	rmSetObjectDefMaxDistance(playerGoldID, 2.0 + cNumberNonGaiaPlayers);
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
	rmAddObjectDefItem(playerBerriesID, "DatePalm", rmRandInt(3,4), 4.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerBerriesID, 10);
    rmSetObjectDefMaxDistance(playerBerriesID, 15);		
	rmAddObjectDefConstraint(playerBerriesID, avoidAll);
    rmAddObjectDefConstraint(playerBerriesID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerBerriesID, true);

	//Prepare to place player starting Turkeys
	int playerTurkeyID=rmCreateObjectDef("player turkeys");
    rmAddObjectDefItem(playerTurkeyID, "Camel", rmRandInt(6,7), 4.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerTurkeyID, 0);
	rmSetObjectDefMaxDistance(playerTurkeyID, 2.0 + cNumberNonGaiaPlayers);	
	rmAddObjectDefConstraint(playerTurkeyID, avoidAll);
    rmAddObjectDefConstraint(playerTurkeyID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerTurkeyID, true);

	//Prepare to place player starting trees
	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "TreeSonora", 2, 2.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);    //This was just added to try to keep these trees from stomping on CW's.
	rmSetObjectDefMinDistance(StartAreaTreeID, 13.0);	//changed from 12.0 
	rmSetObjectDefMaxDistance(StartAreaTreeID, 20.0);	//Changed from 19.0	//Prepare to place player starting trees

	int StartTree2ID=rmCreateObjectDef("starting trees 2");
	rmAddObjectDefItem(StartTree2ID, "TreeSonora", rmRandInt(11,13), 9.0);
	rmAddObjectDefConstraint(StartTree2ID, avoidAll);    //This was just added to try to keep these trees from stomping on CW's.
	rmSetObjectDefMinDistance(StartTree2ID, 0.0);	//changed from 12.0 
	rmSetObjectDefMaxDistance(StartTree2ID, 4.0);	//Changed from 19.0

	int waterSpawnPointID = 0;

	// --------------- Make load bar move. ----------------------------------------------------------------------------`
	rmSetStatusText("",0.70);
   
	// *********** Place Home City Water Spawn Flag ***************************************************

//	************************* Useful Trigonometric Identities *************************************************
// 	r*sin(a+b) = r*[sin(a)*cos(b) + cos(a)*sin(b)]
// 	r*cos(a+b) = r*[cos(a)*cos(b) - sin(a)*sin(b)]
// 	r = 0.20	
//	r*cos(a) = rmPlayerLocXFraction(i) - 0.5	
//	r*sin(a) = rmPlayerLocZFraction(i) - 0.5
// 	R*sin(a+b) = (R/r)*[(rmPlayerLocZFraction(i) - 0.5)*cos(b) + (rmPlayerLocXFraction(i) - 0,5)*sin(b)]
// 	R*cos(a+b) = (R/r)*[(rmPlayerLocXFraction(i) - 0.5)*cos(b) - (rmPlayerLocZFraction(i) - 0.5)*sin(b)]
// 	***********************************************************************************************************

	float angle1ID = 180/cNumberNonGaiaPlayers; 	// middle point between the players
	float angle2ID = 120/cNumberNonGaiaPlayers; 	// one third of distance between the players
	float angle3ID = 90/cNumberNonGaiaPlayers;  	// one fourth of distance between the players

	for(i=1; <cNumberPlayers)
   {
	    // Place TC and starting units
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
//		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));   
		rmPlaceObjectDefAtLoc(playerBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 
//		rmPlaceObjectDefAtLoc(playerTurkeyID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));  										
//		rmPlaceObjectDefAtLoc(playerCrateID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

 		// Object's position defined by trigos
		rmPlaceObjectDefAtLoc(playerTurkeyID, 0, 0.5 + (rmPlayerLocXFraction(i) - 0.5)*_cos(rmDegreesToRadians(angle2ID)) - (rmPlayerLocZFraction(i) - 0.5)*_sin(rmDegreesToRadians(angle2ID)), 0.5 + (rmPlayerLocZFraction(i) - 0.5)*_cos(rmDegreesToRadians(angle2ID)) + (rmPlayerLocXFraction(i) - 0.5)*_sin(rmDegreesToRadians(angle2ID)));  					// left hunt
		rmPlaceObjectDefAtLoc(playerTurkeyID, 0, 0.5 + (rmPlayerLocXFraction(i) - 0.5)*_cos(rmDegreesToRadians(2*angle2ID)) - (rmPlayerLocZFraction(i) - 0.5)*_sin(rmDegreesToRadians(2*angle2ID)), 0.5 + (rmPlayerLocZFraction(i) - 0.5)*_cos(rmDegreesToRadians(2*angle2ID)) + (rmPlayerLocXFraction(i) - 0.5)*_sin(rmDegreesToRadians(2*angle2ID)));  			// right hunt
		rmPlaceObjectDefAtLoc(playerGoldID, 0, 0.5 + (rmPlayerLocXFraction(i) - 0.5)*_cos(rmDegreesToRadians(angle1ID)) - (rmPlayerLocZFraction(i) - 0.5)*_sin(rmDegreesToRadians(angle1ID)), 0.5 + (rmPlayerLocZFraction(i) - 0.5)*_cos(rmDegreesToRadians(angle1ID)) + (rmPlayerLocXFraction(i) - 0.5)*_sin(rmDegreesToRadians(angle1ID)));  						// mine in the side							
		rmPlaceObjectDefAtLoc(playerGoldID, 0, 0.5 + 0.8*(rmPlayerLocXFraction(i) - 0.5), 0.5 + 0.8*(rmPlayerLocZFraction(i) - 0.5));  																																																								// mine	in the front
		rmPlaceObjectDefAtLoc(playerTurkeyID, 0, 0.5 + 1.2*(rmPlayerLocXFraction(i) - 0.5), 0.5 + 1.2*(rmPlayerLocZFraction(i) - 0.5));  																																																								// mine	in the front
		rmPlaceObjectDefAtLoc(StartTree2ID, 0, 0.5 + 1.2*((rmPlayerLocXFraction(i) - 0.5)*_cos(rmDegreesToRadians(angle3ID)) - (rmPlayerLocZFraction(i) - 0.5)*_sin(rmDegreesToRadians(angle3ID))), 0.5 + 1.2*((rmPlayerLocZFraction(i) - 0.5)*_cos(rmDegreesToRadians(angle3ID)) + (rmPlayerLocXFraction(i) - 0.5)*_sin(rmDegreesToRadians(angle3ID))));			// left trees
		rmPlaceObjectDefAtLoc(StartTree2ID, 0, 0.5 + 1.2*((rmPlayerLocXFraction(i) - 0.5)*_cos(rmDegreesToRadians(3*angle3ID)) - (rmPlayerLocZFraction(i) - 0.5)*_sin(rmDegreesToRadians(3*angle3ID))), 0.5 + 1.2*((rmPlayerLocZFraction(i) - 0.5)*_cos(rmDegreesToRadians(3*angle3ID)) + (rmPlayerLocXFraction(i) - 0.5)*_sin(rmDegreesToRadians(3*angle3ID))));  	// right trees									
		rmPlaceObjectDefAtLoc(StartTree2ID, 0, 0.5 + 1.2*(rmPlayerLocXFraction(i) - 0.5), 0.5 + 1.2*(rmPlayerLocZFraction(i) - 0.5));  																																																								// back trees			

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
//		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
		rmClearClosestPointConstraints();
   }
	
   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.75);

	//rmClearClosestPointConstraints();
/*
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
         rmSetAreaForestType(forest, "caribbean palm forest");
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
      } */

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);

/*	// Scattered MINES
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "minegold", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(goldID, avoidTC);
	rmAddObjectDefConstraint(goldID, avoidCW);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidCoin);
    rmAddObjectDefConstraint(goldID, avoidImpassableLand);
	rmAddObjectDefConstraint(goldID, smallMesaConstraint);
	rmPlaceObjectDefInArea(goldID, 0, bigIslandID, cNumberNonGaiaPlayers*3);
*/
	// Scattered BERRRIES		
/*	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "SugarCaneBush", rmRandInt(5,8), 6.0);  // (3,5) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
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
*/
	// Just a FEW scattered TURKEYS
/*	int turkeyID=rmCreateObjectDef("random turkeys");
	rmAddObjectDefItem(turkeyID, "turkey", rmRandInt(3,5), 5.0);  // (2,4) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(turkeyID, 0.0);
	rmSetObjectDefMaxDistance(turkeyID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(turkeyID, avoidTC);
	rmAddObjectDefConstraint(turkeyID, avoidCW);
	rmAddObjectDefConstraint(turkeyID, avoidRandomTurkeys);
	//rmAddObjectDefConstraint(turkeyID, avoidAll);
	//rmAddObjectDefConstraint(turkeyID, avoidRandomBerries);
	rmAddObjectDefConstraint(turkeyID, avoidImpassableLand);
	rmAddObjectDefConstraint(turkeyID, smallMesaConstraint);
	rmPlaceObjectDefInArea(turkeyID, 0, bigIslandID, cNumberNonGaiaPlayers*5);   //Was *2 scattered Turkeys for awhile, but players wanted more fast food.
*/

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
	rmPlaceObjectDefInArea(nugget1, 0, bigIslandID, 2*cNumberNonGaiaPlayers + rmRandInt(1,2));
/*
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
	rmPlaceObjectDefAtLoc(sheepID, 0, 0.46, 0.48, cNumberNonGaiaPlayers*1);
*/
    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place Whales as much in big west bay only as possible --------------------------------------------------------
/*	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.28));		//Distance whales will be placed from the starting spot (below)
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.46, 0.60, cNumberNonGaiaPlayers*3 + rmRandInt(1,2));  //Was .43, .67 // .37, .66 -- The whales will be placed from this spot. 1 per player, plus 1 or 2 more.
*/
	// Place Random Fish everywhere, just as eyecandies

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
	rmAddObjectDefItem(randomTreeID, "treeSonora", 1, 0.0);
	rmSetObjectDefMinDistance(randomTreeID, 0.0);
	rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
	rmAddObjectDefConstraint(randomTreeID, avoidTC);
	rmAddObjectDefConstraint(randomTreeID, avoidCW);
	rmAddObjectDefConstraint(randomTreeID, avoidAll); 
	rmAddObjectDefConstraint(randomTreeID, smallMesaConstraint);
	rmPlaceObjectDefInArea(randomTreeID, 0, bigIslandID, 14*cNumberNonGaiaPlayers);   //Scatter 14 random trees per player.

	int randomTree2ID=rmCreateObjectDef("random tree 2");
	rmAddObjectDefItem(randomTree2ID, "treeSonora", rmRandInt(3,5), 3.0);
	rmSetObjectDefMinDistance(randomTree2ID, 0.0);
	rmSetObjectDefMaxDistance(randomTree2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomTree2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(randomTree2ID, avoidTC);
	rmAddObjectDefConstraint(randomTree2ID, avoidCW);
	rmAddObjectDefConstraint(randomTree2ID, avoidAll); 
	rmAddObjectDefConstraint(randomTree2ID, bigMesaConstraint);
	rmPlaceObjectDefInArea(randomTree2ID, 0, bigIsland0ID, 7*cNumberNonGaiaPlayers);   //Scatter 14 random trees per player.


  // King of the Hill (added 2026-11 for WoL): the open land around the middle of the island, off the central mesa (its cliffs have no ramp)
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
    // (0.025 of the map side per step), with the include's placer constraints, 40 m from every Town Center
    // and 10 m from every tree
    int kothAvoidLand = rmCreateTerrainDistanceConstraint("koth hill avoids impassable land", "Land", false, 6.0);
    int kothAvoidAll = rmCreateTypeDistanceConstraint("koth hill avoids all", "all", 4.0);
    int kothAvoidTC = rmCreateTypeDistanceConstraint("koth hill avoids TCs", "TownCenter", 40.0);
    int kothAvoidTrees = rmCreateTypeDistanceConstraint("koth hill avoids trees", "Tree", 10.0);
    int kothAvoidTreesNear = rmCreateTypeDistanceConstraint("koth hill avoids trees near", "Tree", 5.0);
    int kothAvoidSocket = rmCreateTypeDistanceConstraint("koth hill avoids trade sockets", "socketTradeRoute", 6.0);
    int kothAvoidRoute = rmCreateTradeRouteDistanceConstraint("koth hill avoids trade route", 6.0);
    int kothAvoidClass0 = rmCreateAreaDistanceConstraint("koth hill avoids bigIsland2ID", bigIsland2ID, 20.0);
    int kothAvoidFlag = rmCreateTypeDistanceConstraint("koth hill avoids water flags", "HomeCityWaterSpawnFlag", 4.0);
    int kothDone = 0;
    float kothDist = 0.0;
    for (kothRound = 0; < 41) {
      int kothHill = rmCreateObjectDef("koth hill " + kothRound);
      rmAddObjectDefItem(kothHill, "ypKingsHill", 1, 0);
      rmSetObjectDefMinDistance(kothHill, 0.0);
      rmSetObjectDefMaxDistance(kothHill, rmXFractionToMeters(0.025));
      rmAddObjectDefConstraint(kothHill, kothAvoidLand);
      rmAddObjectDefConstraint(kothHill, kothAvoidAll);
      rmAddObjectDefConstraint(kothHill, kothAvoidTC);
      rmAddObjectDefConstraint(kothHill, kothAvoidTrees);
      rmAddObjectDefConstraint(kothHill, kothAvoidSocket);
      rmAddObjectDefConstraint(kothHill, kothAvoidRoute);
      rmAddObjectDefConstraint(kothHill, kothAvoidFlag);
      rmAddObjectDefConstraint(kothHill, kothAvoidClass0);
      rmPlaceObjectDefAtLoc(kothHill, 0, kothX + kothDirX * kothDist, kothZ + kothDirZ * kothDist, 1);
      if (rmGetNumberUnitsPlaced(kothHill) > 0) {
        kothDone = 1;
        break;
      }
      // 0, +1, -1, +2, -2, ... steps
      if (kothDist > 0.0)
        kothDist = 0.0 - kothDist;
      else
        kothDist = 0.025 - kothDist;
    }
    // no room on that line: the open land nearest to the middle, trees allowed closer (5 m)
    if (kothDone == 0) {
      float kothRadius = 0.04;
      for (kothNear = 0; < 8) {
        int kothHillNear = rmCreateObjectDef("koth hill near " + kothNear);
        rmAddObjectDefItem(kothHillNear, "ypKingsHill", 1, 0);
        rmSetObjectDefMinDistance(kothHillNear, 0.0);
        rmSetObjectDefMaxDistance(kothHillNear, rmXFractionToMeters(kothRadius));
        rmAddObjectDefConstraint(kothHillNear, kothAvoidLand);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidAll);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidTC);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidTreesNear);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidSocket);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidRoute);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidFlag);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidClass0);
        rmPlaceObjectDefAtLoc(kothHillNear, 0, kothX, kothZ, 1);
        if (rmGetNumberUnitsPlaced(kothHillNear) > 0)
          break;
        kothRadius = kothRadius * 1.5;
      }
    }
  }

}  




