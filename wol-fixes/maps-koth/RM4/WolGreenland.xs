// Another Greenland
// this time with fjords

include "mercenaries.xs";
include "triggers\triggerLoader.xs";
//include "GWevent.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

//// Trigonometric functions to make the map rotate


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

// make the map rotate, the sea never looking to the north
	float phase = rmRandFloat(0,225);
//	float phase = 0; // test
	
	// Define Carib Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;

    if (rmAllocateSubCivs(3) == true)
    {
		subCiv0=rmGetCivID("Inuit");
		rmEchoInfo("subCiv0 is Inuit "+subCiv0);
		if (subCiv0 >= 0)
		rmSetSubCiv(0, "Inuit");

		subCiv1=rmGetCivID("Inuit");
		rmEchoInfo("subCiv1 is Inuit "+subCiv1);
		if (subCiv1 >= 0)
		rmSetSubCiv(1, "Inuit");

		subCiv2=rmGetCivID("Inuit");
		rmEchoInfo("subCiv2 is Inuit "+subCiv2);
		if (subCiv2 >= 0)
		rmSetSubCiv(2, "Inuit");
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
	int playerTiles=18500;
	if (cNumberNonGaiaPlayers >4)   // If more than 4 players...
		playerTiles = 18000;		// ...give this many tiles per player.
	if (cNumberNonGaiaPlayers >7)	// If more than 7 players...
		playerTiles = 16000;		// ...give this many tiles per player.	
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Set up default water type.
	rmSetMapElevationParameters(cElevTurbulence, 0.02, 3, 0.5, 3.0);
	rmSetSeaLevel(-2.0);          
	rmSetSeaType("greenland sea");
	rmSetBaseTerrainMix("greenland");
	rmSetMapType("yukon");
	rmSetMapType("snow");
	rmSetMapType("water");
	rmSetLightingSet("araucaniasouth");

	// Initialize map.
    rmTerrainInitialize("carolinas\ground_grass1_car", 1.2);

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
	int IceConstraint=rmCreateClassDistanceConstraint("avoid ice", rmClassID("canyon"), 10.0);


	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fishSalmon", 25.0);			// was 50.0
	// int fishVsFishTarponID=rmCreateTypeDistanceConstraint("fish v fish2", "fishTarpon", 20.0);  // was 40.0 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 25.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "HumpbackWhale", 40.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 20.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int avoidCoin=-1;
	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "mine", 45.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "mine", 55.0);	
	}
	
	int	avoidCoinLarge = rmCreateTypeDistanceConstraint("avoid coin ++", "mine", 115.0 - 10*cNumberNonGaiaPlayers);	
	int avoidInuksuk=rmCreateTypeDistanceConstraint("avoid Inuksuk", "Inuksuk", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random turkeys", "muskOx", 50.0);	//Attempting to spread them out more evenly.
	int avoidOxLarge=rmCreateTypeDistanceConstraint("avoid random oxes +", "muskOx", 115.0 -10*cNumberNonGaiaPlayers);	
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 54.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 120.0);  //Added sheep 11-28-05 JSB
	int avoidTreesLarge=rmCreateTypeDistanceConstraint("tree vs tree", "TreeYukon", 80.0 - 8*cNumberNonGaiaPlayers);	


	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 14.0);  //This one is used in one place: for helping place FFA TC's better.

	// Constraint to avoid water.
	int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);   //I added this one so I could experiment with it.
	int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 8.0);
	int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water medium+", "Land", false, 10.0);
	int avoidWater12 = rmCreateTerrainDistanceConstraint("avoid water medium++", "Land", false, 12.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 20.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);  //Added this one too.
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 18.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25); //Was 15, but made larger so ships don't sometimes stomp each other when arriving from HC.
	rmAddClosestPointConstraint(avoidWater8);  //was originally 8
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
	int avoidNatives = rmCreateClassDistanceConstraint("native v native", rmClassID("natives"), 50.0);
	int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("classSocket"), 10.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);

	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  (It excludes the west bay, where I do not want the flags.)
	int circleConstraint=rmCreatePieConstraint("semi-circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(50), rmDegreesToRadians(290));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

	// int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);
   
   int AreaID = rmCreateArea("area");
   rmSetAreaWarnFailure(AreaID, false);
   rmSetAreaSize(AreaID, 1, 1);
   rmBuildArea(AreaID);
   
// SEA
   int bay1ID=rmCreateArea("Bay 1");
   rmSetAreaSize(bay1ID, 0.18, 0.18);
	rmSetAreaLocation(bay1ID, 0.49*_cos(rmDegreesToRadians(135 + phase))+0.5, 0.49*_sin(rmDegreesToRadians(135 + phase))+0.5);
	rmSetAreaWaterType(bay1ID, "greenland sea");
   rmSetAreaBaseHeight(bay1ID, -2.0);
//   rmSetAreaMinBlobs(bay1ID, 4);
//   rmSetAreaMaxBlobs(bay1ID, 6);
//   rmSetAreaMinBlobDistance(bay1ID, 5);
//   rmSetAreaMaxBlobDistance(bay1ID, 30);
   rmSetAreaSmoothDistance(bay1ID, 50);
   rmSetAreaCoherence(bay1ID, 0.8);
	rmAddAreaInfluenceSegment(bay1ID, 0.50*_cos(rmDegreesToRadians(160 + phase))+0.5, 0.50*_sin(rmDegreesToRadians(160 + phase))+0.5, 0.48*_cos(rmDegreesToRadians(135 + phase))+0.5, 0.48*_sin(rmDegreesToRadians(135 + phase))+0.5);
	rmAddAreaInfluenceSegment(bay1ID, 0.48*_cos(rmDegreesToRadians(135 + phase))+0.5, 0.48*_sin(rmDegreesToRadians(135 + phase))+0.5, 0.50*_cos(rmDegreesToRadians(110 + phase))+0.5, 0.50*_sin(rmDegreesToRadians(110 + phase))+0.5);
   rmSetAreaObeyWorldCircleConstraint(bay1ID, false);
	rmBuildArea(bay1ID); 
 
//	int	MapVariation = rmRandInt(1,3);
	int	MapVariation = 3;
	int randValI = rmRandInt(1,2);
//	int randValI = 2;	

	int bigriverID = rmRiverCreate(-1, "greenland sea", 10, 2, 14 + 2*cNumberNonGaiaPlayers, 15 + 2*cNumberNonGaiaPlayers);
	rmRiverAddWaypoint(bigriverID, 0.5, 0.5);
	rmRiverAddWaypoint(bigriverID, 0.26*_cos(rmDegreesToRadians(135 + phase))+0.5, 0.26*_sin(rmDegreesToRadians(135 + phase))+0.5);
//	rmRiverSetBankNoiseParams(bigriverID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	
	int coast1ID = rmRiverCreate(-1, "greenland sea", 10, 2, 10, 10);
	rmRiverAddWaypoint(coast1ID, 0.49*_cos(rmDegreesToRadians(90 + phase))+0.5, 0.49*_sin(rmDegreesToRadians(90 + phase))+0.5);
	rmRiverAddWaypoint(coast1ID, 0.40*_cos(rmDegreesToRadians(100 + phase))+0.5, 0.40*_sin(rmDegreesToRadians(100 + phase))+0.5);
	rmRiverAddWaypoint(coast1ID, 0.32*_cos(rmDegreesToRadians(110 + phase))+0.5, 0.32*_sin(rmDegreesToRadians(110 + phase))+0.5);
	rmRiverAddWaypoint(coast1ID, 0.22*_cos(rmDegreesToRadians(130 + phase))+0.5, 0.22*_sin(rmDegreesToRadians(130 + phase))+0.5);
//	rmRiverSetBankNoiseParams(coast1ID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	
	int coast2ID = rmRiverCreate(-1, "greenland sea", 10, 2, 10, 10);
	rmRiverAddWaypoint(coast2ID, 0.49*_cos(rmDegreesToRadians(180 + phase))+0.5, 0.49*_sin(rmDegreesToRadians(180 + phase))+0.5);
	rmRiverAddWaypoint(coast2ID, 0.40*_cos(rmDegreesToRadians(170 + phase))+0.5, 0.40*_sin(rmDegreesToRadians(170 + phase))+0.5);
	rmRiverAddWaypoint(coast2ID, 0.32*_cos(rmDegreesToRadians(160 + phase))+0.5, 0.32*_sin(rmDegreesToRadians(160 + phase))+0.5);
	rmRiverAddWaypoint(coast2ID, 0.22*_cos(rmDegreesToRadians(140 + phase))+0.5, 0.22*_sin(rmDegreesToRadians(140 + phase))+0.5);
//	rmRiverSetBankNoiseParams(coast2ID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	
	rmRiverBuild(bigriverID);
	rmRiverBuild(coast1ID);
	rmRiverBuild(coast2ID);

/*	int glacierID=rmCreateArea("glacier");
	rmSetAreaSize(glacierID, 0.01, 0.01);
	rmSetAreaLocation(glacierID, 0.05*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.05*_sin(rmDegreesToRadians(-45 + phase))+0.5);
	rmSetAreaWarnFailure(glacierID, false);
	rmSetAreaBaseHeight(glacierID, -1.4);
//	rmSetAreaMix(glacierID, "greenland_snow");
	rmSetAreaSmoothDistance(glacierID, 10);
	rmSetAreaCoherence(glacierID, .92);
	rmSetAreaCliffType(glacierID, "glacier");
	rmSetAreaCliffEdge(glacierID, 6, 0.4, 0, 1.0, 0);
	rmSetAreaCliffHeight(glacierID, 0, 0, 0.0);
	rmSetAreaCliffPainting(glacierID, true, true, true, 0, true);
	rmSetAreaObeyWorldCircleConstraint(glacierID, false);
//	rmAddAreaConstraint(glacierID, avoidWater2);
//	rmAddAreaInfluenceSegment(glacierID, 0.35*_cos(rmDegreesToRadians(135 + phase))+0.5, 0.35*_sin(rmDegreesToRadians(135 + phase))+0.5, 0.11*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.11*_sin(rmDegreesToRadians(-45 + phase))+0.5); 
//	rmBuildArea(glacierID);*/

	int bumpID=rmCreateArea("bump");
	rmSetAreaSize(bumpID, 0.85, 0.85);
	rmSetAreaLocation(bumpID, 0.23*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.23*_sin(rmDegreesToRadians(-45 + phase))+0.5);
	rmSetAreaWarnFailure(bumpID, false);
	rmSetAreaBaseHeight(bumpID, 2.5);
//	rmSetAreaMix(bumpID, "greenland");
	rmSetAreaSmoothDistance(bumpID, 20);
	rmSetAreaCoherence(bumpID, .85);
	rmSetAreaObeyWorldCircleConstraint(bumpID, false);
	rmAddAreaConstraint(bumpID, avoidWater12);
	rmBuildArea(bumpID);
	
	int bump2ID=rmCreateArea("bump2");
	rmSetAreaSize(bump2ID, 0.85, 0.85);
	rmSetAreaLocation(bump2ID, 0.23*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.23*_sin(rmDegreesToRadians(-45 + phase))+0.5);
	rmSetAreaWarnFailure(bump2ID, false);
	rmSetAreaBaseHeight(bump2ID, 3.6);
//	rmSetAreaMix(bump2ID, "greenland");
	rmSetAreaSmoothDistance(bump2ID, 20);
	rmSetAreaCoherence(bump2ID, .88);
      rmSetAreaElevationVariation(bump2ID, 3.0);
      rmSetAreaElevationMinFrequency(bump2ID, 0.09);
      rmSetAreaElevationOctaves(bump2ID, 3);
	rmSetAreaObeyWorldCircleConstraint(bump2ID, false);
	rmAddAreaConstraint(bump2ID, avoidWater20);
	rmBuildArea(bump2ID);

	int bump3ID=rmCreateArea("bump3");
	rmSetAreaSize(bump3ID, 0.13, 0.13);
	rmSetAreaLocation(bump3ID, 0.19*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.19*_sin(rmDegreesToRadians(-45 + phase))+0.5);
	rmSetAreaWarnFailure(bump3ID, false);
	rmSetAreaBaseHeight(bump3ID, 5.4);
	rmSetAreaMix(bump3ID, "greenland_snow");
	rmSetAreaSmoothDistance(bump3ID, 20);
	rmSetAreaCoherence(bump3ID, .95);
//	rmSetAreaCliffType(bump3ID, "Rocky Mountain2");
//	rmSetAreaCliffEdge(bump3ID, 6, 0.4, 0, 1.0, 0);
//	rmSetAreaCliffHeight(bump3ID, 2, 0, 0.0);
//	rmSetAreaCliffPainting(bump3ID, true, true, true, 3.0, true);
	rmSetAreaObeyWorldCircleConstraint(bump3ID, false);
	rmAddAreaConstraint(bump3ID, avoidWater12);
	rmAddAreaInfluenceSegment(bump3ID, 0.35*_cos(rmDegreesToRadians(135 + phase))+0.5, 0.35*_sin(rmDegreesToRadians(135 + phase))+0.5, 0.11*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.11*_sin(rmDegreesToRadians(-45 + phase))+0.5); 
	rmBuildArea(bump3ID);
	
	int snow0ID=rmCreateArea("snow0");
	rmSetAreaSize(snow0ID, 0.145, 0.145);
	rmSetAreaLocation(snow0ID, 0.19*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.19*_sin(rmDegreesToRadians(-45 + phase))+0.5);
	rmSetAreaWarnFailure(snow0ID, false);
//	rmSetAreaBaseHeight(snow0ID, 5.4);
	rmSetAreaMix(snow0ID, "greenland_snow");
	rmSetAreaSmoothDistance(snow0ID, 20);
	rmSetAreaCoherence(snow0ID, .95);
	rmSetAreaObeyWorldCircleConstraint(snow0ID, false);
	rmAddAreaConstraint(snow0ID, avoidWater2);
	rmAddAreaInfluenceSegment(snow0ID, 0.35*_cos(rmDegreesToRadians(135 + phase))+0.5, 0.35*_sin(rmDegreesToRadians(135 + phase))+0.5, 0.11*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.11*_sin(rmDegreesToRadians(-45 + phase))+0.5); 
	rmBuildArea(snow0ID);

	int cliffID=rmCreateArea("cliff");
	rmSetAreaSize(cliffID, 0.1, 0.1);
	rmSetAreaLocation(cliffID, 0.16*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.16*_sin(rmDegreesToRadians(-45 + phase))+0.5);
	rmSetAreaWarnFailure(cliffID, false);
	rmSetAreaBaseHeight(cliffID, 4.2);
//	rmSetAreaMix(cliffID, "greenland_snow");
	rmSetAreaSmoothDistance(cliffID, 10);
	rmSetAreaCoherence(cliffID, .92);
	rmSetAreaCliffType(cliffID, "Rocky Mountain2");
	rmSetAreaCliffEdge(cliffID, 6, 0.4, 0, 1.0, 0);
	rmSetAreaCliffHeight(cliffID, 2, 0, 0.0);
	rmSetAreaCliffPainting(cliffID, true, true, true, 1.5, true);
	rmSetAreaObeyWorldCircleConstraint(cliffID, false);
	rmAddAreaConstraint(cliffID, avoidWater8);
	rmAddAreaInfluenceSegment(cliffID, 0.35*_cos(rmDegreesToRadians(135 + phase))+0.5, 0.35*_sin(rmDegreesToRadians(135 + phase))+0.5, 0.11*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.11*_sin(rmDegreesToRadians(-45 + phase))+0.5); 
	rmBuildArea(cliffID);

	int SnowID=rmCreateArea("snow");
	rmSetAreaSize(SnowID, 0.25, 0.25);
	rmSetAreaLocation(SnowID, 0.49*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.49*_sin(rmDegreesToRadians(-45 + phase))+0.5);
	rmSetAreaWarnFailure(SnowID, false);
	rmSetAreaBaseHeight(SnowID, 5.5);
	rmSetAreaMix(SnowID, "greenland_snow");
	rmSetAreaSmoothDistance(SnowID, 30);
	rmSetAreaCoherence(SnowID, .85);
//	rmSetAreaCliffType(SnowID, "Rocky Mountain2");
//	rmSetAreaCliffEdge(SnowID, 1, 0.8, 0, 1.0, 0);
//	rmSetAreaCliffHeight(SnowID, 0, 0, 0.0);
//	rmSetAreaCliffPainting(SnowID, false, false, false, 0, true);
      rmSetAreaElevationVariation(SnowID, 3.0);
      rmSetAreaElevationMinFrequency(SnowID, 0.09);
      rmSetAreaElevationOctaves(SnowID, 3);
	rmSetAreaObeyWorldCircleConstraint(SnowID, false);
	rmAddAreaConstraint(SnowID, avoidWater12);
	rmAddAreaInfluenceSegment(SnowID, 0.49*_cos(rmDegreesToRadians(0 + phase))+0.5, 0.49*_sin(rmDegreesToRadians(0 + phase))+0.5, 0.11*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.11*_sin(rmDegreesToRadians(-45 + phase))+0.5); 
	rmAddAreaInfluenceSegment(SnowID, 0.11*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.11*_sin(rmDegreesToRadians(-45 + phase))+0.5, 0.49*_cos(rmDegreesToRadians(-90 + phase))+0.5, 0.49*_sin(rmDegreesToRadians(-90 + phase))+0.5); 
	rmAddAreaInfluenceSegment(SnowID, 0.49*_cos(rmDegreesToRadians(-90 + phase))+0.5, 0.49*_sin(rmDegreesToRadians(-90 + phase))+0.5, 0.49*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.49*_sin(rmDegreesToRadians(-45 + phase))+0.5); 
	rmAddAreaInfluenceSegment(SnowID, 0.49*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.49*_sin(rmDegreesToRadians(-45 + phase))+0.5, 0.49*_cos(rmDegreesToRadians(0 + phase))+0.5, 0.49*_sin(rmDegreesToRadians(0 + phase))+0.5); 
	rmBuildArea(SnowID);

//	Snow Constraints
	int avoidSnow = rmCreateAreaDistanceConstraint("avoid snow", SnowID, 5.0);
	int inSnow = rmCreateAreaConstraint("stay in snow", SnowID);

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);

	float teamStartLoc = rmRandInt(0.0, 1.0);
	int teamOne = -1;
	int teamTwo = -1;
	if(teamStartLoc < 0.5)
	{
		teamOne = 0;
		teamTwo = 1;
		}
	else
	{
		teamOne = 1;
		teamTwo = 0;
		}

		if (cNumberTeams == 2 )
		{
		if (MapVariation == 1)
			{
			rmSetPlacementTeam(teamOne);
			rmPlacePlayersLine(0.30*_cos(rmDegreesToRadians(80 + phase))+0.5, 0.30*_sin(rmDegreesToRadians(80 + phase))+0.5, 0.41*_cos(rmDegreesToRadians(30 + phase))+0.5, 0.41*_sin(rmDegreesToRadians(30 + phase))+0.5, 0.0, 0.3); //Team 0 is in the south 

			rmSetPlacementTeam(teamTwo);
			rmPlacePlayersLine(0.30*_cos(rmDegreesToRadians(190 + phase))+0.5, 0.30*_sin(rmDegreesToRadians(190 + phase))+0.5, 0.41*_cos(rmDegreesToRadians(240 + phase))+0.5, 0.41*_sin(rmDegreesToRadians(240 + phase))+0.5, 0.0, 0.3); //Team 1 is in the north
			}
		if (MapVariation == 2)
			{
			rmSetPlacementTeam(teamOne);
			rmPlacePlayersLine(0.22*_cos(rmDegreesToRadians(90 + phase))+0.5, 0.22*_sin(rmDegreesToRadians(90 + phase))+0.5,0.29*_cos(rmDegreesToRadians(25 + phase))+0.5, 0.29*_sin(rmDegreesToRadians(25 + phase))+0.5, 0.0, 0.3); //Team 0 is in the south 

			rmSetPlacementTeam(teamTwo);
			rmPlacePlayersLine(0.22*_cos(rmDegreesToRadians(180 + phase))+0.5, 0.22*_sin(rmDegreesToRadians(180 + phase))+0.5,0.29*_cos(rmDegreesToRadians(245 + phase))+0.5, 0.29*_sin(rmDegreesToRadians(245 + phase))+0.5, 0.0, 0.3); //Team 1 is in the north
			}
		if (MapVariation == 3)
			{
			rmSetPlacementTeam(teamOne);
			rmPlacePlayersLine(0.44*_cos(rmDegreesToRadians(70 + phase))+0.5, 0.44*_sin(rmDegreesToRadians(70 + phase))+0.5,0.44*_cos(rmDegreesToRadians(30 + phase))+0.5, 0.44*_sin(rmDegreesToRadians(30 + phase))+0.5, 0.0, 0.3); //Team 0 is in the south 

			rmSetPlacementTeam(teamTwo);
			rmPlacePlayersLine(0.44*_cos(rmDegreesToRadians(200 + phase))+0.5, 0.44*_sin(rmDegreesToRadians(200 + phase))+0.5,0.44*_cos(rmDegreesToRadians(240 + phase))+0.5, 0.44*_sin(rmDegreesToRadians(240 + phase))+0.5, 0.0, 0.3); //Team 1 is in the north
			}
		}

	else
	{
//  		rmSetPlacementSection(0.04, 0.82);
//		rmPlacePlayersCircular(0.22, 0.23, 0.0);
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
//	  rmSetAreaMix(id, "bayou_grass");
      rmSetAreaMaxBlobs(id, 1);
      rmSetAreaLocPlayer(id, i);
      rmSetAreaWarnFailure(id, false);
	}

	// Build the areas. 
	rmBuildAllAreas();

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.60);
 
	// Clear out constraints for good measure.
    rmClearClosestPointConstraints();   //This was in the Caribbean script I started with.  Not sure what it does so afraid to axe it.

	// *****************NATIVES****************************************************************************	

		if (subCiv1 == rmGetCivID("Inuit"))
		{  
			int caribsVillageID = -1;
			int caribsVillageType = rmRandInt(1,3);
			if (caribsVillageType == 3)   
				caribsVillageType = rmRandInt(1,3);
			caribsVillageID = rmCreateGrouping("caribs city", "native inuit 0"+caribsVillageType);
			rmAddGroupingToClass(caribsVillageID, rmClassID("natives"));
			rmSetGroupingMinDistance(caribsVillageID, 0.0);
			rmSetGroupingMaxDistance(caribsVillageID, 20.0);
			rmAddGroupingConstraint(caribsVillageID, avoidImpassableLand);
			rmAddGroupingConstraint(caribsVillageID, playerConstraint);
			rmAddGroupingConstraint(caribsVillageID, inSnow);
			rmAddGroupingConstraint(caribsVillageID, avoidWater20);
			rmAddGroupingConstraint(caribsVillageID, avoidNatives);
			rmPlaceGroupingAtLoc(caribsVillageID, 0, 0.40*_cos(rmDegreesToRadians(-45 + phase))+0.5, 0.40*_sin(rmDegreesToRadians(-45 + phase))+0.5, 1);
		}	

		if (subCiv2 == rmGetCivID("Inuit"))
		{  
			int caribs2VillageID = -1;
			int caribs2VillageType = rmRandInt(1,3);
			caribs2VillageID = rmCreateGrouping("caribs2 city", "native inuit 0"+caribs2VillageType);
			rmAddGroupingToClass(caribs2VillageID, rmClassID("natives"));
			rmAddGroupingConstraint(caribs2VillageID, playerConstraint);
			rmSetGroupingMinDistance(caribs2VillageID, 0.0);
			rmSetGroupingMaxDistance(caribs2VillageID, 20.0);
			rmAddGroupingConstraint(caribs2VillageID, avoidWater20);
			rmAddGroupingConstraint(caribs2VillageID, avoidImpassableLand);
			rmAddGroupingConstraint(caribs2VillageID, inSnow);
//			rmAddGroupingConstraint(caribs2VillageID, avoidNatives);
			rmPlaceGroupingAtLoc(caribs2VillageID, 0, 0.32*_cos(rmDegreesToRadians(-82 + phase))+0.5, 0.32*_sin(rmDegreesToRadians(-82 + phase))+0.5, 1);
		} 
	

	if (cNumberNonGaiaPlayers >4)  
	{
		if (subCiv1 == rmGetCivID("Inuit"))
		{  
			int caribs3VillageID = -1;
			int caribs3VillageType = rmRandInt(1,3);
			if (caribs3VillageType == 3)
				caribs3VillageType = rmRandInt(1,2);
			caribs3VillageID = rmCreateGrouping("caribs3 city", "native inuit 0"+caribs3VillageType);
			rmAddGroupingToClass(caribs3VillageID, rmClassID("natives"));
			rmSetGroupingMinDistance(caribs3VillageID, 0.0);
			rmSetGroupingMaxDistance(caribs3VillageID, 4.0);
			rmAddGroupingConstraint(caribs3VillageID, playerConstraint);
			rmAddGroupingConstraint(caribs3VillageID, avoidWater20);
			rmAddGroupingConstraint(caribs3VillageID, inSnow);
			rmAddGroupingConstraint(caribs3VillageID, avoidImpassableLand);
			rmAddGroupingConstraint(caribs3VillageID, avoidNatives);
			rmPlaceGroupingInArea(caribs3VillageID, 0, AreaID, 1);
		}	

		if (subCiv2 == rmGetCivID("Inuit"))
		{  
			int caribs4VillageID = -1;
			int caribs4VillageType = rmRandInt(1,3);
			caribs4VillageID = rmCreateGrouping("caribs4 city", "native inuit 0"+caribs4VillageType);
			rmAddGroupingToClass(caribs4VillageID, rmClassID("natives"));
			rmAddGroupingConstraint(caribs4VillageID, playerConstraint);
			rmAddGroupingConstraint(caribs4VillageID, avoidWater20);
			rmAddGroupingConstraint(caribs4VillageID, avoidImpassableLand);
			rmAddGroupingConstraint(caribs4VillageID, inSnow);
			rmAddGroupingConstraint(caribs4VillageID, avoidNatives);
			rmPlaceGroupingInArea(caribs4VillageID, 0, AreaID, 1);
		} 
	}		
		if (subCiv1 == rmGetCivID("Inuit"))
		{  
			int caribs5VillageID = -1;
			int caribs5VillageType = rmRandInt(1,3);
			if (caribs5VillageType == 3)   
				caribs5VillageType = rmRandInt(1,3);
			caribs5VillageID = rmCreateGrouping("caribs5 city", "native inuit 0"+caribs5VillageType);
			rmAddGroupingToClass(caribs5VillageID, rmClassID("natives"));
			rmSetGroupingMinDistance(caribs5VillageID, 0.0);
			rmSetGroupingMaxDistance(caribs5VillageID, 20.0);
			rmAddGroupingConstraint(caribs5VillageID, playerConstraint);
			rmAddGroupingConstraint(caribs5VillageID, avoidWater20);
			rmAddGroupingConstraint(caribs5VillageID, avoidImpassableLand);
			rmAddGroupingConstraint(caribs5VillageID, inSnow);
//			rmAddGroupingConstraint(caribs5VillageID, avoidNatives);
			rmPlaceGroupingAtLoc(caribs5VillageID, 0, 0.32*_cos(rmDegreesToRadians(-08 + phase))+0.5, 0.32*_sin(rmDegreesToRadians(-08+ phase))+0.5, 1);
		}

	// --------------- Make load bar move. ----------------------------------------------------------------------------`
	rmSetStatusText("",0.70);

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

	//Prepare to place player starting Berries
	int playerBerriesID=rmCreateObjectDef("player berries");
	rmAddObjectDefItem(playerBerriesID, "berrybush", rmRandInt(4,6), 4.0);	
	rmSetObjectDefMinDistance(playerBerriesID, 21);
    rmSetObjectDefMaxDistance(playerBerriesID, 26);		
	rmAddObjectDefConstraint(playerBerriesID, avoidAll);
    rmAddObjectDefConstraint(playerBerriesID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerBerriesID, true);
    
   	//A bit of extra wood
	int playerCratesID=rmCreateObjectDef("player wood");
	rmAddObjectDefItem(playerCratesID, "CrateofWood", 2, 4.0);	
	rmSetObjectDefMinDistance(playerCratesID, 8.0);
    rmSetObjectDefMaxDistance(playerCratesID, 9.0);		
	rmAddObjectDefConstraint(playerCratesID, avoidAll);
    rmAddObjectDefConstraint(playerCratesID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerCratesID, true);

	//Prepare to place player starting Turkeys
	int playerTurkeyID=rmCreateObjectDef("player Ox");
    rmAddObjectDefItem(playerTurkeyID, "muskOx", rmRandInt(6,7), 4.0);
    rmSetObjectDefMinDistance(playerTurkeyID, 14);
	rmSetObjectDefMaxDistance(playerTurkeyID, 19);	
	rmAddObjectDefConstraint(playerTurkeyID, avoidAll);
    rmAddObjectDefConstraint(playerTurkeyID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerTurkeyID, true);

	//Prepare to place player starting trees
	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "TreeYukon", 2, 3.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
	rmSetObjectDefMinDistance(StartAreaTreeID, 13.0);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 20.0);
	
	int waterSpawnPointID = 0;
   
	// *********** Place Home City Water Spawn Flag ***************************************************

	for(i=1; <cNumberPlayers)
   {	
	if (cNumberTeams > 2) //ffa
	{
	int placedTC = rmPlaceObjectDefInArea(TCID, i, AreaID);
}
	else
	{
	rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
}
	    // Place TC and starting units
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerCratesID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));   
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));   
		rmPlaceObjectDefAtLoc(playerBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 
		rmPlaceObjectDefAtLoc(playerTurkeyID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));  										
//		rmPlaceObjectDefAtLoc(playerCrateID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		// Place player starting trees
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		// Place water spawn points for the players
		waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 20.0);  // ...Flag", 1, 1.0); - the first number is the number of flags.  The next number is the float distance.
		rmAddClosestPointConstraint(flagVsFlag);
		rmAddClosestPointConstraint(flagLand);
		rmAddClosestPointConstraint(circleConstraint);
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(13.0));
		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
		rmClearClosestPointConstraints();
   }

   int forestTreeID = 0;
   numTries=8*cNumberNonGaiaPlayers;
   int failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(130), rmAreaTilesToFraction(300));
         rmSetAreaForestType(forest, "rockies snow forest");
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
         rmAddAreaConstraint(forest, avoidSnow);
         rmAddAreaConstraint(forest, avoidWater8);
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

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);

	// Scattered MINES
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "mine", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.25));
	rmAddObjectDefConstraint(goldID, avoidTC);
	rmAddObjectDefConstraint(goldID, avoidCW);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidCoin);
	rmAddObjectDefConstraint(goldID, avoidSnow);
	rmAddObjectDefConstraint(goldID, avoidWater20);
    rmAddObjectDefConstraint(goldID, avoidImpassableLand);
	rmPlaceObjectDefInArea(goldID, 0, AreaID);	
	
	rmPlaceObjectDefAtLoc(goldID, 0, 0.30*_cos(rmDegreesToRadians(50 + phase))+0.5, 0.30*_sin(rmDegreesToRadians(50 + phase))+0.5, cNumberNonGaiaPlayers);
	rmPlaceObjectDefAtLoc(goldID, 0, 0.30*_cos(rmDegreesToRadians(-140 + phase))+0.5, 0.30*_sin(rmDegreesToRadians(-140 + phase))+0.5, cNumberNonGaiaPlayers);
	
	int gold2ID = rmCreateObjectDef("random gold Snow");
	rmAddObjectDefItem(gold2ID, "mine", 1, 0);
	rmSetObjectDefMinDistance(gold2ID, 0.0);
	rmSetObjectDefMaxDistance(gold2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(gold2ID, avoidTC);
	rmAddObjectDefConstraint(gold2ID, avoidCW);
	rmAddObjectDefConstraint(gold2ID, avoidAll);
	rmAddObjectDefConstraint(gold2ID, avoidCoinLarge);
	rmAddObjectDefConstraint(gold2ID, inSnow);
	rmAddObjectDefConstraint(gold2ID, avoidWater20);
    rmAddObjectDefConstraint(gold2ID, avoidImpassableLand);
	rmPlaceObjectDefInArea(gold2ID, 0, AreaID, cNumberNonGaiaPlayers + 1);

	// Inuksuk
	int InuksukID=rmCreateObjectDef("Inuksuk");
	rmAddObjectDefItem(InuksukID, "Inuksuk", 1, 0.0); 
	rmSetObjectDefMinDistance(InuksukID, 0.0);
	rmSetObjectDefMaxDistance(InuksukID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(InuksukID, avoidTC);
	rmAddObjectDefConstraint(InuksukID, avoidTP);
	rmAddObjectDefConstraint(InuksukID, avoidCW);
	rmAddObjectDefConstraint(InuksukID, avoidAll);
	rmAddObjectDefConstraint(InuksukID, inSnow);
	rmAddObjectDefConstraint(InuksukID, avoidInuksuk);
	rmAddObjectDefConstraint(InuksukID, avoidImpassableLand);
	rmPlaceObjectDefInArea(InuksukID, 0, AreaID, cNumberNonGaiaPlayers + 1);

	// Just a FEW scattered Oxes
	int oxesID=rmCreateObjectDef("random oxes");
	rmAddObjectDefItem(oxesID, "muskOx", rmRandInt(8,10), 5.0); 
	rmSetObjectDefMinDistance(oxesID, 0.0);
	rmSetObjectDefMaxDistance(oxesID, rmXFractionToMeters(0.20));
	rmAddObjectDefConstraint(oxesID, avoidTC);
	rmAddObjectDefConstraint(oxesID, avoidCW);
	rmAddObjectDefConstraint(oxesID, avoidSnow);
	rmAddObjectDefConstraint(oxesID, avoidRandomTurkeys);
	//rmAddObjectDefConstraint(oxesID, avoidAll);
	rmAddObjectDefConstraint(oxesID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(oxesID, true);

	rmPlaceObjectDefAtLoc(oxesID, 0, 0.30*_cos(rmDegreesToRadians(50 + phase))+0.5, 0.30*_sin(rmDegreesToRadians(50 + phase))+0.5, cNumberNonGaiaPlayers);
	rmPlaceObjectDefAtLoc(oxesID, 0, 0.30*_cos(rmDegreesToRadians(-140 + phase))+0.5, 0.30*_sin(rmDegreesToRadians(-140 + phase))+0.5, cNumberNonGaiaPlayers);
	
	int oxes2ID=rmCreateObjectDef("random snow oxes");
	rmAddObjectDefItem(oxes2ID, "muskOx", rmRandInt(4,6), 5.0);
	rmSetObjectDefMinDistance(oxes2ID, 0.0);
	rmSetObjectDefMaxDistance(oxes2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(oxes2ID, avoidTC);
	rmAddObjectDefConstraint(oxes2ID, avoidCW);
	rmAddObjectDefConstraint(oxes2ID, inSnow);
	rmAddObjectDefConstraint(oxes2ID, avoidRandomTurkeys);
	rmAddObjectDefConstraint(oxes2ID, avoidOxLarge);
	//rmAddObjectDefConstraint(oxes2ID, avoidAll);
	rmAddObjectDefConstraint(oxes2ID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(oxes2ID, true);

	rmPlaceObjectDefInArea(oxes2ID, 0, AreaID, cNumberNonGaiaPlayers + 1);
	
	int snowTree=rmCreateObjectDef("random trees");
	rmAddObjectDefItem(snowTree, "TreeYukon", rmRandInt(9,12), 6.0);
	rmSetObjectDefMinDistance(snowTree, 0.0);
	rmSetObjectDefMaxDistance(snowTree, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(snowTree, avoidTC);
	rmAddObjectDefConstraint(snowTree, avoidCW);
	rmAddObjectDefConstraint(snowTree, inSnow);
//	rmAddObjectDefConstraint(snowTree, avoidRandomTurkeys);
	rmAddObjectDefConstraint(snowTree, avoidTreesLarge);
	//rmAddObjectDefConstraint(snowTree, avoidAll);
	rmAddObjectDefConstraint(snowTree, avoidImpassableLand);
    rmSetObjectDefCreateHerd(snowTree, true);

	rmPlaceObjectDefInArea(snowTree, 0, AreaID, 2*cNumberNonGaiaPlayers + 1);
	
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
	rmAddObjectDefConstraint(nugget1, avoidSnow);
	//rmAddObjectDefConstraint(nugget1, avoidCW);
	rmAddObjectDefConstraint(nugget1, avoidAll);
	rmAddObjectDefConstraint(nugget1, avoidWater20);
	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget1, 0, AreaID, cNumberNonGaiaPlayers*rmRandInt(3,4));

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
	rmAddObjectDefConstraint(nugget2, inSnow);
	rmAddObjectDefConstraint(nugget2, avoidWater20);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget2, 0, AreaID, cNumberNonGaiaPlayers);

	//Place Sheep
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
	rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(sheepID, 0, 0.46, 0.48, cNumberNonGaiaPlayers*1);

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place Whales as much in big west bay only as possible --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefInArea(whaleID, 0, bay1ID, cNumberNonGaiaPlayers*3 + rmRandInt(1,2));

	
	// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------

	int fishID=rmCreateObjectDef("fish salmon");
	rmAddObjectDefItem(fishID, "FishSalmon", 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers); 


  // King of the Hill (added 2026-11 for WoL): the middle is at the head of the fjord; first open land on the line that splits the teams
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
        rmPlaceObjectDefAtLoc(kothHillNear, 0, kothX, kothZ, 1);
        if (rmGetNumberUnitsPlaced(kothHillNear) > 0)
          break;
        kothRadius = kothRadius * 1.5;
      }
    }
  }

}
