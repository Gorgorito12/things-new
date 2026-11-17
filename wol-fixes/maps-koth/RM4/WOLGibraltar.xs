// Gibraltar  

include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";

//// Trigonometric functions

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
	int subCiv3=-1;
	int subCiv4=-1;
	int subCiv5=-1;

    rmAllocateSubCivs(6);
		subCiv0=rmGetCivID("AURsilk");
		rmEchoInfo("subCiv0 is AURsilk "+subCiv0);
		if (subCiv0 >= 0)
		rmSetSubCiv(0, "AURsilk");

		subCiv1=rmGetCivID("AURliterature");
		rmEchoInfo("subCiv1 is AURliterature "+subCiv1);
		if (subCiv1 >= 0)
		rmSetSubCiv(1, "AURliterature");

		subCiv2=rmGetCivID("AURloil");
		rmEchoInfo("subCiv2 is AURloil "+subCiv2);
		if (subCiv2 >= 0)
		rmSetSubCiv(2, "AURloil");
		
		subCiv3=rmGetCivID("Farmstead");
		rmEchoInfo("subCiv3 is Farmstead "+subCiv3);
		if (subCiv3 >= 0)
		rmSetSubCiv(3, "Farmstead");
		
		subCiv4=rmGetCivID("Priory");
		rmEchoInfo("subCiv4 is Priory "+subCiv4);
		if (subCiv4 >= 0)
		rmSetSubCiv(4, "Priory");
		
		subCiv5=rmGetCivID("Fishing");
		rmEchoInfo("subCiv5 is Fishing "+subCiv5);
		if (subCiv5 >= 0)
		rmSetSubCiv(5, "Fishing");


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	// 1.- The big continent is in spain
	// 2.- The big continent is in morocco
	
	int whichVariation=-1;
	 whichVariation = rmRandInt(1,2);
	// The line below can be uncommented to force the variation to the number indicated, for testing.
//	 whichVariation = 1; 

	rmEchoInfo("Map Variation: "+whichVariation);
	
	chooseMercs();
wotta_triggers();

	
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
	rmSetSeaLevel(1.0);          
	rmSetSeaType("Gibraltar Coast");
	rmSetBaseTerrainMix("caribbean grass");
	rmSetMapType("AFRICANdesert");
	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetLightingSet("seville");

	// Initialize map.
    rmTerrainInitialize("carolinas\ground_grass1_car", 12.0);

	// Misc variables for use later
	int numTries = -1;

	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
	int classPatch=rmDefineClass("patch");
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
	int islandConstraintHuge=rmCreateClassDistanceConstraint("islands avoid each other but a lot", classIsland, rmZFractionToMeters(0.21));


	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fishMahi", 25.0);			// was 50.0
	// int fishVsFishTarponID=rmCreateTypeDistanceConstraint("fish v fish2", "fishTarpon", 20.0);  // was 40.0 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 6.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "HumpbackWhale", 40.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 17.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int avoidCoin=-1;
	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "MineTin", 75.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "MineTin", 85.0);	// 85.0 seems the best for event minegold distribution.  This number tells minegolds how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "Appletree", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomDeer=rmCreateTypeDistanceConstraint("avoid random deer", "Deer", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomGazelle=rmCreateTypeDistanceConstraint("avoid random gazelle", "Gazelle", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomBighorn=rmCreateTypeDistanceConstraint("avoid random bighorn", "BighornSheep", 50.0);	//Attempting to spread them out more evenly.
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 54.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 120.0);  //Added sheep 11-28-05 JSB

	int avoidCoinSmall = rmCreateTypeDistanceConstraint("avoid coin near", "MineTin", 45.0);

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
	
	int avoidPatch = rmCreateClassDistanceConstraint("patch avoid patch", rmClassID("patch"), 12.0);

	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  (It excludes the west bay, where I do not want the flags.)
	int circleConstraint=rmCreatePieConstraint("semi-circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(50), rmDegreesToRadians(290));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

	// int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);

	int seaID=rmCreateArea("sea mask");
	rmSetAreaSize(seaID, 1.0, 1.0);
	rmSetAreaSmoothDistance(seaID, 12);
	rmSetAreaCoherence(seaID, 0.6);
	rmSetAreaWaterType(seaID, "Gibraltar Coast");
	rmSetAreaObeyWorldCircleConstraint(seaID, false);
	rmSetAreaLocation(seaID, 0.5, 0.5);
	rmBuildArea(seaID);


//make the continent

	int bigIslandID=rmCreateArea("Continent");
	rmSetAreaSize(bigIslandID, 0.3, 0.3);
	rmSetAreaCoherence(bigIslandID, 0.77);
	rmSetAreaBaseHeight(bigIslandID, 1.1);
	rmSetAreaSmoothDistance(bigIslandID, 60);
	if (whichVariation == 1)
	{
		rmSetAreaMix(bigIslandID, "california_grass");
	}
	else
	{
		rmSetAreaMix(bigIslandID, "california_desert3");
	}
	//	rmAddAreaToClass(bigIslandID, classIsland);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 2.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmSetAreaElevationOctaves(bigIslandID, 3);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);
	rmSetAreaWarnFailure(bigIslandID, false);
	rmSetAreaLocation(bigIslandID, 0.5, 0.5);

 float p = 45;
 float q = 225;

 float a1 = -1;
 float a2 = -1;
 float a3 = -1;
 float a4 = -1;

	if (whichVariation == 1)
	{	
		a1 = 60;
		a2 = 52;
		a3 = 90;
		a4 = 150;
		
	rmAddAreaInfluenceSegment(bigIslandID, 0.49*_cos(rmDegreesToRadians(p - a1))+0.5, 0.49*_sin(rmDegreesToRadians(p - a1))+0.5, 0.30*_cos(rmDegreesToRadians(p - a2))+0.5, 0.30*_sin(rmDegreesToRadians(p - a2))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.30*_cos(rmDegreesToRadians(p - a2))+0.5, 0.30*_sin(rmDegreesToRadians(p - a2))+0.5, 0.20*_cos(rmDegreesToRadians(p - a3))+0.5, 0.20*_sin(rmDegreesToRadians(p - a3))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.20*_cos(rmDegreesToRadians(p - a3))+0.5, 0.20*_sin(rmDegreesToRadians(p - a3))+0.5, 0.11*_cos(rmDegreesToRadians(p - a4))+0.5, 0.11*_sin(rmDegreesToRadians(p - a4))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.11*_cos(rmDegreesToRadians(p - a4))+0.5, 0.11*_sin(rmDegreesToRadians(p - a4))+0.5, 0.11*_cos(rmDegreesToRadians(p + a4))+0.5, 0.11*_sin(rmDegreesToRadians(p + a4))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.11*_cos(rmDegreesToRadians(p + a4))+0.5, 0.11*_sin(rmDegreesToRadians(p + a4))+0.5, 0.20*_cos(rmDegreesToRadians(p + a3))+0.5, 0.20*_sin(rmDegreesToRadians(p + a3))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.20*_cos(rmDegreesToRadians(p + a3))+0.5, 0.20*_sin(rmDegreesToRadians(p + a3))+0.5, 0.30*_cos(rmDegreesToRadians(p + a2))+0.5, 0.30*_sin(rmDegreesToRadians(p + a2))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.30*_cos(rmDegreesToRadians(p + a2))+0.5, 0.30*_sin(rmDegreesToRadians(p + a2))+0.5, 0.49*_cos(rmDegreesToRadians(p + a1))+0.5, 0.49*_sin(rmDegreesToRadians(p + a1))+0.5);
	
	rmAddAreaInfluenceSegment(bigIslandID, 0.49*_cos(rmDegreesToRadians(p + a1))+0.5, 0.49*_sin(rmDegreesToRadians(p + a1))+0.5, 0.50*_cos(rmDegreesToRadians(p + a1 + 4))+0.5, 0.50*_sin(rmDegreesToRadians(p + a1 + 4))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.50*_cos(rmDegreesToRadians(p + a1 + 4))+0.5, 0.50*_sin(rmDegreesToRadians(p + a1 + 4))+0.5, 0.66*_cos(rmDegreesToRadians(p + 00))+0.5, 0.66*_sin(rmDegreesToRadians(p + 00))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.66*_cos(rmDegreesToRadians(p - 00))+0.5, 0.66*_sin(rmDegreesToRadians(p - 00))+0.5, 0.50*_cos(rmDegreesToRadians(p - a1 - 4))+0.5, 0.50*_sin(rmDegreesToRadians(p - a1 - 4))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.50*_cos(rmDegreesToRadians(p - a1 - 4))+0.5, 0.50*_sin(rmDegreesToRadians(p - a1 - 4))+0.5, 0.49*_cos(rmDegreesToRadians(p - a1))+0.5, 0.49*_sin(rmDegreesToRadians(p - a1))+0.5);
	}

else
	{		
		a1 = 130;
		a2 = 120;
		a3 = 80;
		a4 = 75;
		
	rmAddAreaInfluenceSegment(bigIslandID, 0.49*_cos(rmDegreesToRadians(p - a1))+0.5, 0.49*_sin(rmDegreesToRadians(p - a1))+0.5, 0.36*_cos(rmDegreesToRadians(p - a2))+0.5, 0.36*_sin(rmDegreesToRadians(p - a2))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.36*_cos(rmDegreesToRadians(p - a2))+0.5, 0.36*_sin(rmDegreesToRadians(p - a2))+0.5, 0.20*_cos(rmDegreesToRadians(p - a3))+0.5, 0.20*_sin(rmDegreesToRadians(p - a3))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.20*_cos(rmDegreesToRadians(p - a3))+0.5, 0.20*_sin(rmDegreesToRadians(p - a3))+0.5, 0.07*_cos(rmDegreesToRadians(p - a4))+0.5, 0.07*_sin(rmDegreesToRadians(p - a4))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.07*_cos(rmDegreesToRadians(p - a4))+0.5, 0.07*_sin(rmDegreesToRadians(p - a4))+0.5, 0.07*_cos(rmDegreesToRadians(p + a4))+0.5, 0.07*_sin(rmDegreesToRadians(p + a4))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.07*_cos(rmDegreesToRadians(p + a4))+0.5, 0.07*_sin(rmDegreesToRadians(p + a4))+0.5, 0.20*_cos(rmDegreesToRadians(p + a3))+0.5, 0.20*_sin(rmDegreesToRadians(p + a3))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.20*_cos(rmDegreesToRadians(p + a3))+0.5, 0.20*_sin(rmDegreesToRadians(p + a3))+0.5, 0.36*_cos(rmDegreesToRadians(p + a2))+0.5, 0.36*_sin(rmDegreesToRadians(p + a2))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.36*_cos(rmDegreesToRadians(p + a2))+0.5, 0.36*_sin(rmDegreesToRadians(p + a2))+0.5, 0.49*_cos(rmDegreesToRadians(p + a1))+0.5, 0.49*_sin(rmDegreesToRadians(p + a1))+0.5);
	
	rmAddAreaInfluenceSegment(bigIslandID, 0.49*_cos(rmDegreesToRadians(p + a1))+0.5, 0.49*_sin(rmDegreesToRadians(p + a1))+0.5, 0.50*_cos(rmDegreesToRadians(p + a1 - 4))+0.5, 0.50*_sin(rmDegreesToRadians(p + a1 - 4))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.50*_cos(rmDegreesToRadians(p + a1 - 4))+0.5, 0.50*_sin(rmDegreesToRadians(p + a1 - 4))+0.5, 0.66*_cos(rmDegreesToRadians(p + 180))+0.5, 0.66*_sin(rmDegreesToRadians(p + 180))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.66*_cos(rmDegreesToRadians(p - 180))+0.5, 0.66*_sin(rmDegreesToRadians(p - 180))+0.5, 0.50*_cos(rmDegreesToRadians(p - a1 + 4))+0.5, 0.50*_sin(rmDegreesToRadians(p - a1 + 4))+0.5);
	rmAddAreaInfluenceSegment(bigIslandID, 0.50*_cos(rmDegreesToRadians(p - a1 + 4))+0.5, 0.50*_sin(rmDegreesToRadians(p - a1 + 4))+0.5, 0.49*_cos(rmDegreesToRadians(p - a1))+0.5, 0.49*_sin(rmDegreesToRadians(p - a1))+0.5);
	}

	rmBuildArea(bigIslandID);

	int smallIslandID=rmCreateArea("other Continent");
	rmSetAreaSize(smallIslandID, 0.14, 0.14);
	rmSetAreaCoherence(smallIslandID, 0.77);
	rmSetAreaBaseHeight(smallIslandID, 1.1);
	rmSetAreaSmoothDistance(smallIslandID, 60);
	if (whichVariation == 1)
	{
		rmSetAreaMix(smallIslandID, "california_desert3");
	}
	else
	{
		rmSetAreaMix(smallIslandID, "california_grass");
	}
	rmAddAreaToClass(smallIslandID, classIsland);
	rmSetAreaObeyWorldCircleConstraint(smallIslandID, false);
	rmSetAreaElevationType(smallIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(smallIslandID, 2.0);
	rmSetAreaElevationMinFrequency(smallIslandID, 0.09);
	rmSetAreaElevationOctaves(smallIslandID, 3);
	rmSetAreaElevationPersistence(smallIslandID, 0.2);
	rmSetAreaElevationNoiseBias(smallIslandID, 1);
	rmSetAreaWarnFailure(smallIslandID, false);

 float b1 = -1;
 float b2 = -1;
 float b3 = -1;
 float b4 = -1;

	if (whichVariation == 1)
	{	
		rmSetAreaLocation(smallIslandID, 0.2, 0.2);
		
		b1 = 34;
		b2 = 30;
		b3 = 90;
		b4 = 150;
		
	rmAddAreaInfluenceSegment(smallIslandID, 0.49*_cos(rmDegreesToRadians(q - b1))+0.5, 0.49*_sin(rmDegreesToRadians(q - b1))+0.5, 0.40*_cos(rmDegreesToRadians(q - b2))+0.5, 0.40*_sin(rmDegreesToRadians(q - b2))+0.5);
	rmAddAreaInfluenceSegment(smallIslandID, 0.40*_cos(rmDegreesToRadians(q - b2))+0.5, 0.40*_sin(rmDegreesToRadians(q - b2))+0.5, 0.40*_cos(rmDegreesToRadians(q + b2))+0.5, 0.40*_sin(rmDegreesToRadians(q + b2))+0.5);
	rmAddAreaInfluenceSegment(smallIslandID, 0.40*_cos(rmDegreesToRadians(q + b2))+0.5, 0.40*_sin(rmDegreesToRadians(q + b2))+0.5, 0.49*_cos(rmDegreesToRadians(q + b1))+0.5, 0.49*_sin(rmDegreesToRadians(q + b1))+0.5);
	
	rmAddAreaInfluenceSegment(smallIslandID, 0.49*_cos(rmDegreesToRadians(q + b1))+0.5, 0.49*_sin(rmDegreesToRadians(q + b1))+0.5, 0.50*_cos(rmDegreesToRadians(q + b1 - 4))+0.5, 0.50*_sin(rmDegreesToRadians(q + b1 - 4))+0.5);
	rmAddAreaInfluenceSegment(smallIslandID, 0.50*_cos(rmDegreesToRadians(q + b1 - 4))+0.5, 0.50*_sin(rmDegreesToRadians(q + b1 - 4))+0.5, 0.66*_cos(rmDegreesToRadians(q))+0.5, 0.66*_sin(rmDegreesToRadians(q))+0.5);
	rmAddAreaInfluenceSegment(smallIslandID, 0.66*_cos(rmDegreesToRadians(q))+0.5, 0.66*_sin(rmDegreesToRadians(q))+0.5, 0.50*_cos(rmDegreesToRadians(q - b1 + 4))+0.5, 0.50*_sin(rmDegreesToRadians(q - b1 + 4))+0.5);
	rmAddAreaInfluenceSegment(smallIslandID, 0.50*_cos(rmDegreesToRadians(q - b1 + 4))+0.5, 0.50*_sin(rmDegreesToRadians(q - b1 + 4))+0.5, 0.49*_cos(rmDegreesToRadians(q - b1))+0.5, 0.49*_sin(rmDegreesToRadians(q - b1))+0.5);
	}

else
	{		
		rmSetAreaLocation(smallIslandID, 0.8, 0.8);

		b1 = 150;
		b2 = 156;
		b3 = 80;
		b4 = 120;
		
	rmAddAreaInfluenceSegment(smallIslandID, 0.57*_cos(rmDegreesToRadians(q - b1))+0.5, 0.57*_sin(rmDegreesToRadians(q - b1))+0.5, 0.40*_cos(rmDegreesToRadians(q - b2))+0.5, 0.40*_sin(rmDegreesToRadians(q - b2))+0.5);
	rmAddAreaInfluenceSegment(smallIslandID, 0.40*_cos(rmDegreesToRadians(q - b2))+0.5, 0.40*_sin(rmDegreesToRadians(q - b2))+0.5, 0.40*_cos(rmDegreesToRadians(q + b2))+0.5, 0.40*_sin(rmDegreesToRadians(q + b2))+0.5);
	rmAddAreaInfluenceSegment(smallIslandID, 0.40*_cos(rmDegreesToRadians(q + b2))+0.5, 0.40*_sin(rmDegreesToRadians(q + b2))+0.5, 0.57*_cos(rmDegreesToRadians(q + b1))+0.5, 0.57*_sin(rmDegreesToRadians(q + b1))+0.5);
/*	
	rmAddAreaInfluenceSegment(smallIslandID, 0.49*_cos(rmDegreesToRadians(q + b1))+0.5, 0.49*_sin(rmDegreesToRadians(q + b1))+0.5, 0.50*_cos(rmDegreesToRadians(q + b1 - 4))+0.5, 0.50*_sin(rmDegreesToRadians(q + b1 - 4))+0.5);
	rmAddAreaInfluenceSegment(smallIslandID, 0.50*_cos(rmDegreesToRadians(q + b1 - 4))+0.5, 0.50*_sin(rmDegreesToRadians(q + b1 - 4))+0.5, 0.66*_cos(rmDegreesToRadians(q + 180))+0.5, 0.66*_sin(rmDegreesToRadians(q + 180))+0.5);
	rmAddAreaInfluenceSegment(smallIslandID, 0.66*_cos(rmDegreesToRadians(q + 180))+0.5, 0.66*_sin(rmDegreesToRadians(q + 180))+0.5, 0.50*_cos(rmDegreesToRadians(q - b1 + 4))+0.5, 0.50*_sin(rmDegreesToRadians(q - b1 + 4))+0.5);
	rmAddAreaInfluenceSegment(smallIslandID, 0.50*_cos(rmDegreesToRadians(q - b1 + 4))+0.5, 0.50*_sin(rmDegreesToRadians(q - b1 + 4))+0.5, 0.49*_cos(rmDegreesToRadians(q - b1))+0.5, 0.49*_sin(rmDegreesToRadians(q - b1))+0.5);*/
	}

	rmBuildArea(smallIslandID);


	int stayInBig = rmCreateAreaMaxDistanceConstraint("stay in big island ", bigIslandID, 0.0);
	int stayInSmall = rmCreateAreaMaxDistanceConstraint("stay in small island ", smallIslandID, 0.0);


	rmSetStatusText("",0.40);	

    // Set up player areas.
	
		int teamStartLoc = rmRandInt(0, 1);
		int teamOne = -1;
		int teamTwo = -1;
		if(teamStartLoc == 1)
		{
			teamOne = 0;
			teamTwo = 1;
		}
		else
		{
			teamOne = 1;
			teamTwo = 0;
		}

	if (whichVariation == 1)
	{
		if(cNumberTeams > 2)
		{
				rmSetPlacementSection(0.00, 0.25);
				rmPlacePlayersCircular(0.45, 0.45, 0);
		}
		else
		{
				rmSetPlacementTeam(teamOne);
				rmPlacePlayersLine(0.55, 0.80, 0.45, 0.65, 0.0, 0.0);
				rmSetPlacementTeam(teamTwo);
				rmPlacePlayersLine(0.80, 0.55, 0.65, 0.45, 0.0, 0.0);
		}
	}

	else	
	{
		if(cNumberTeams > 2)
		{
				rmSetPlacementSection(0.50, 0.75);
				rmPlacePlayersCircular(0.4, 0.4, 0);
		}
		else
		{
				rmSetPlacementTeam(teamOne);
				rmPlacePlayersLine(0.45, 0.20, 0.55, 0.35, 0.0, 0.0);
				rmSetPlacementTeam(teamTwo);
				rmPlacePlayersLine(0.20, 0.45, 0.35, 0.55, 0.0, 0.0);
		}
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
	// europeans in the north, africans in the south, three in the big continent, 2 in the small zone
	
	//utility numbers:
	float no1 = -1;
	float no2 = -1;
	float no3 = -1;
	float no4 = -1;
	float no5 = -1;
	
	int whichNatives = rmRandInt(1,6);
//	int whichNatives = 1;
	string bigNS1 = "";
	string bigNS2 = "";
	string bigNS3 = "";
	string smallNS1 = "";
	string smallNS2 = "";

	if (whichVariation == 1)  
	{ 
		no1 = 0.90;
		no2 = 0.50;
		no3 = 0.30;
		no4 = 0.10;
		no5 = 0.68;
		
	if (whichNatives == 1)
	{
		bigNS1 = "european priory med";
		bigNS2 = "european farmstead med";
		bigNS3 = "european fishing village med";
		smallNS1 = "AURoil egyptian ";
		smallNS2 = "AURliterature egyptian ";
	}
	else if (whichNatives == 2)
	{
		bigNS1 = "european priory med";
		bigNS2 = "european fishing village med";
		bigNS3 = "european farmstead med";
		smallNS1 = "AURoil egyptian ";
		smallNS2 = "AURsilk egyptian ";
	}
	else if (whichNatives == 3)
	{
		bigNS1 = "european farmstead med";
		bigNS2 = "european priory med";
		bigNS3 = "european fishing village med";
		smallNS1 = "AURliterature egyptian ";
		smallNS2 = "AURsilk egyptian ";
	}
	else if (whichNatives == 4)
	{
		bigNS1 = "european farmstead med";
		bigNS2 = "european fishing village med";
		bigNS3 = "european priory med";
		smallNS1 = "AURliterature egyptian ";
		smallNS2 = "AURoil egyptian ";
	}
	else if (whichNatives == 5)
	{
		bigNS1 = "european fishing village med";
		bigNS2 = "european farmstead med";
		bigNS3 = "european priory med";
		smallNS1 = "AURsilk egyptian ";
		smallNS2 = "AURoil egyptian ";
	}
	else
	{
		bigNS1 = "european fishing village med";
		bigNS2 = "european farmstead med";
		bigNS3 = "european priory med";
		smallNS1 = "AURsilk egyptian ";
		smallNS2 = "AURliterature egyptian ";
	}
}
	else
	{ 
		no1 = 0.40;
		no2 = 0.10;
		no3 = 0.85;
		no4 = 0.65;
		no5 = 0.32;
		
	if (whichNatives == 1)
	{
		bigNS1 = "AURoil egyptian ";
		bigNS2 = "AURliterature egyptian ";
		bigNS3 = "AURsilk egyptian ";
		smallNS1 = "european priory med";
		smallNS2 = "european fishing village med";
	}
	else if (whichNatives == 2)
	{
		bigNS1 = "AURoil egyptian ";
		bigNS2 = "AURsilk egyptian ";
		bigNS3 = "AURliterature egyptian ";
		smallNS1 = "european priory med";
		smallNS2 = "european farmstead med";
	}
	else if (whichNatives == 3)
	{
		bigNS1 = "AURliterature egyptian ";
		bigNS2 = "AURoil egyptian ";
		bigNS3 = "AURsilk egyptian ";
		smallNS1 = "european fishing village med";
		smallNS2 = "european farmstead med";
	}
	else if (whichNatives == 4)
	{
		bigNS1 = "AURliterature egyptian ";
		bigNS2 = "AURsilk egyptian ";
		bigNS3 = "AURoil egyptian ";
		smallNS1 = "european fishing village med";
		smallNS2 = "european priory med";
	}
	else if (whichNatives == 5)
	{
		bigNS1 = "AURsilk egyptian ";
		bigNS2 = "AURliterature egyptian ";
		bigNS3 = "AURoil egyptian ";
		smallNS1 = "european farmstead med";
		smallNS2 = "european priory med";
	}
	else
	{
		bigNS1 = "AURsilk egyptian ";
		bigNS2 = "AURoil egyptian ";
		bigNS3 = "AURliterature egyptian ";
		smallNS1 = "european farmstead med";
		smallNS2 = "european fishing village med";
	}
}
  
			int BigCont1VillageID = -1;
			int BigCont1VillageType = rmRandInt(1,3);
			if (whichVariation == 1)
			BigCont1VillageID = rmCreateGrouping("BigCont1 city", bigNS1);
			else
			BigCont1VillageID = rmCreateGrouping("BigCont1 city", bigNS1+BigCont1VillageType);
	
			rmSetGroupingMinDistance(BigCont1VillageID, 0.0);
			rmSetGroupingMaxDistance(BigCont1VillageID, 4.0);
			rmAddGroupingConstraint(BigCont1VillageID, avoidImpassableLand);
			rmPlaceGroupingAtLoc(BigCont1VillageID, 0, no1, no2);

			int BigCont2VillageID = -1;
			int BigCont2VillageType = rmRandInt(1,3);
			if (whichVariation == 1)
			BigCont2VillageID = rmCreateGrouping("BigCont2 city", bigNS2);
			else
			BigCont2VillageID = rmCreateGrouping("BigCont2 city", bigNS2+BigCont2VillageType);

			rmSetGroupingMinDistance(BigCont2VillageID, 0.0);
			rmSetGroupingMaxDistance(BigCont2VillageID, 4.0);
			rmAddGroupingConstraint(BigCont2VillageID, avoidImpassableLand);
			rmPlaceGroupingAtLoc(BigCont2VillageID, 0, no2, no1);

			int BigCont3VillageID = -1;
			int BigCont3VillageType = rmRandInt(1,3);
			if (whichVariation == 1)
			BigCont3VillageID = rmCreateGrouping("BigCont3 city", bigNS3);
			else
			BigCont3VillageID = rmCreateGrouping("BigCont3 city", bigNS3+BigCont3VillageType);

			rmSetGroupingMinDistance(BigCont3VillageID, 0.0);
			rmSetGroupingMaxDistance(BigCont3VillageID, 4.0);
			rmAddGroupingConstraint(BigCont3VillageID, avoidImpassableLand);
			rmPlaceGroupingAtLoc(BigCont3VillageID, 0, no5, no5);

			int SmallCont1VillageID = -1;
			int SmallCont1VillageType = rmRandInt(1,3);
			if (whichVariation == 1)
			SmallCont1VillageID = rmCreateGrouping("SmallCont1 city", smallNS1+SmallCont1VillageType);
			else
			SmallCont1VillageID = rmCreateGrouping("SmallCont1 city", smallNS1);
			
			rmSetGroupingMinDistance(SmallCont1VillageID, 0.0);
			rmSetGroupingMaxDistance(SmallCont1VillageID, 4.0);
			rmAddGroupingConstraint(SmallCont1VillageID, avoidImpassableLand);
			rmPlaceGroupingAtLoc(SmallCont1VillageID, 0, no3, no4);

			int SmallCont2VillageID = -1;
			int SmallCont2VillageType = rmRandInt(1,3);
			if (whichVariation == 1)
			SmallCont2VillageID = rmCreateGrouping("SmallCont2 city", smallNS2+SmallCont2VillageType);
			else
			SmallCont2VillageID = rmCreateGrouping("SmallCont2 city", smallNS2);

			rmSetGroupingMinDistance(SmallCont2VillageID, 0.0);
			rmSetGroupingMaxDistance(SmallCont2VillageID, 4.0);
			rmAddGroupingConstraint(SmallCont2VillageID, avoidImpassableLand);
			rmPlaceGroupingAtLoc(SmallCont2VillageID, 0, no4, no3);


		int smallCliffHeight=rmRandInt(0,10);
		int smallMesaID=rmCreateArea("small mesa"+i);
		rmSetAreaSize(smallMesaID, 0.04, 0.04);
		rmSetAreaWarnFailure(smallMesaID, false);
		rmSetAreaCliffType(smallMesaID, "California");
		rmAddAreaToClass(smallMesaID, rmClassID("canyon"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(smallMesaID, 6, .14, 0, 1.0, 0);
		rmSetAreaCliffPainting(smallMesaID, false, true, true, 0, true);
		rmSetAreaCliffHeight(smallMesaID, rmRandInt(6, 8), 1.0, 1.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(smallMesaID, 0.88);
		if (whichVariation == 1)
		{
		rmSetAreaLocation(smallMesaID, 0.54, 0.54); 
		}
		else
		{
		rmSetAreaLocation(smallMesaID, 0.46, 0.46); 
		}
		rmBuildArea(smallMesaID);


		int smallMesa2ID=rmCreateArea("small mesa 2");
		rmSetAreaSize(smallMesa2ID, 0.09, 0.09);
		rmSetAreaWarnFailure(smallMesa2ID, false);
		rmSetAreaCliffType(smallMesa2ID, "California");
		rmAddAreaToClass(smallMesa2ID, rmClassID("canyon"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(smallMesa2ID, 6, .14, 0, 1.0, 0);
		rmSetAreaCliffPainting(smallMesa2ID, false, true, true, 0, true);

		rmSetAreaCoherence(smallMesa2ID, 0.88);

		if (cNumberTeams == 2 )
		{
		rmSetAreaCliffHeight(smallMesa2ID, rmRandInt(6, 8), 1.0, 1.0); 
		}
		else
		{
		rmSetAreaCliffHeight(smallMesa2ID, 0, 1.0, 1.0); 
		}

		if (whichVariation == 1)
		{
		rmSetAreaLocation(smallMesa2ID, 0.85, 0.85); 
		}
		else
		{
		rmSetAreaLocation(smallMesa2ID, 0.15, 0.15); 
		}
		rmBuildArea(smallMesa2ID);
		
		int smallMesa3ID=rmCreateArea("small mesa 3");
		rmSetAreaSize(smallMesa3ID, 0.04, 0.04);
		rmSetAreaWarnFailure(smallMesa3ID, false);
		rmSetAreaCliffType(smallMesa3ID, "California");
		rmAddAreaToClass(smallMesa3ID, rmClassID("canyon"));
		rmSetAreaCliffEdge(smallMesa3ID, 6, .14, 0, 1.0, 0);
		rmSetAreaCliffPainting(smallMesa3ID, false, true, true, 0, true);
		rmSetAreaCoherence(smallMesa3ID, 0.88);
		rmSetAreaCliffHeight(smallMesa3ID, rmRandInt(6, 8), 1.0, 1.0); 

		if (whichVariation == 1)
		{
		rmSetAreaLocation(smallMesa3ID, 0.19, 0.19); 
		}
		else
		{
		rmSetAreaLocation(smallMesa3ID, 0.81, 0.81); 
		}
		rmBuildArea(smallMesa3ID);

	// Special AREA CONSTRAINTS and use it to make resources in or out the mountain:

		int smallMesaConstraint = rmCreateClassDistanceConstraint("avoid Small Mesa", rmClassID("canyon"), 4.0);
		int stayInMesa1 = rmCreateAreaMaxDistanceConstraint("stay in Mesa 1 ", smallMesaID, 0.0);
		int stayInMesa2 = rmCreateAreaMaxDistanceConstraint("stay in Mesa 2 ", smallMesa2ID, 0.0);
		int stayInMesa3 = rmCreateAreaMaxDistanceConstraint("stay in Mesa 3 ", smallMesa3ID, 0.0);

	
	
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

	//Prepare to place player starting Berries
	int playerBerriesID=rmCreateObjectDef("player berries");
	rmAddObjectDefItem(playerBerriesID, "Appletree", rmRandInt(4,6), 4.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerBerriesID, 21);
    rmSetObjectDefMaxDistance(playerBerriesID, 26);		
	rmAddObjectDefConstraint(playerBerriesID, avoidAll);
    rmAddObjectDefConstraint(playerBerriesID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerBerriesID, true);

	//Prepare to place player starting Turkeys
	int playerTurkeyID=rmCreateObjectDef("player turkeys");
    rmAddObjectDefItem(playerTurkeyID, "Deer", rmRandInt(6,7), 4.0);
    rmSetObjectDefMinDistance(playerTurkeyID, 14);
	rmSetObjectDefMaxDistance(playerTurkeyID, 19);	
	rmAddObjectDefConstraint(playerTurkeyID, avoidAll);
    rmAddObjectDefConstraint(playerTurkeyID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerTurkeyID, true);

	//Prepare to place player starting trees
	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "TreePonderosaPine", 1, 0.0);
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

   int forestTreeID = 0;
   numTries=10*cNumberNonGaiaPlayers;
   int failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
		
		if (whichVariation == 1)
         rmSetAreaForestType(forest, "Verdon Forest");
        else
         rmSetAreaForestType(forest, "African Atlas Forest");

         rmSetAreaForestDensity(forest, 0.8);
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
		 rmAddAreaConstraint(forest, avoidWater8);
         rmAddAreaConstraint(forest, avoidTradeRoute); 
         rmAddAreaConstraint(forest, stayInBig); 
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
	// Scattered FORESTS
 
   for (i=0; <numTries)
      {   
         int greenPatch=rmCreateArea("green "+i);
         rmSetAreaWarnFailure(greenPatch, false);
         rmSetAreaSize(greenPatch, rmAreaTilesToFraction(150), rmAreaTilesToFraction(200));
         rmSetAreaObeyWorldCircleConstraint(greenPatch, false);
	     rmSetAreaMix(greenPatch, "california_grassrocks");
         rmSetAreaMinBlobs(greenPatch, 1);
         rmSetAreaMaxBlobs(greenPatch, 5);
         rmSetAreaMinBlobDistance(greenPatch, 16.0);
         rmSetAreaMaxBlobDistance(greenPatch, 40.0);
         rmSetAreaCoherence(greenPatch, 0.1);
         rmSetAreaSmoothDistance(greenPatch, 10);
         rmAddAreaToClass(greenPatch, rmClassID("patch")); 
         rmAddAreaConstraint(greenPatch, avoidAll);
         rmAddAreaConstraint(greenPatch, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(greenPatch, avoidPatch); 
		 rmAddAreaConstraint(greenPatch, avoidWater8);
         if(rmBuildArea(greenPatch)==false)
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
         int forest2=rmCreateArea("forest2 "+i);
         rmSetAreaWarnFailure(forest2, false);
         rmSetAreaSize(forest2, rmAreaTilesToFraction(120), rmAreaTilesToFraction(300));
		
		if (whichVariation == 1)
         rmSetAreaForestType(forest2, "African Atlas Forest");
        else
         rmSetAreaForestType(forest2, "Verdon Forest");

         rmSetAreaForestDensity(forest2, 0.8);
         rmSetAreaForestClumpiness(forest2, 0.4);
         rmSetAreaForestUnderbrush(forest2, 0.0);
         rmSetAreaMinBlobs(forest2, 1);
         rmSetAreaMaxBlobs(forest2, 5);
         rmSetAreaMinBlobDistance(forest2, 16.0);
         rmSetAreaMaxBlobDistance(forest2, 40.0);
         rmSetAreaCoherence(forest2, 0.4);
         rmSetAreaSmoothDistance(forest2, 10);
         rmAddAreaToClass(forest2, rmClassID("classForest")); 
         rmAddAreaConstraint(forest2, forestConstraint);
         rmAddAreaConstraint(forest2, avoidAll);
         rmAddAreaConstraint(forest2, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(forest2, smallMesaConstraint); 
		 rmAddAreaConstraint(forest2, avoidTC);
		 rmAddAreaConstraint(forest2, avoidCW);
		 rmAddAreaConstraint(forest2, avoidWater8);
         rmAddAreaConstraint(forest2, avoidTradeRoute); 
         rmAddAreaConstraint(forest2, stayInSmall); 
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

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);

	// Scattered MINES
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "MineTin", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(goldID, avoidTC);
	rmAddObjectDefConstraint(goldID, avoidCW);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidCoin);
    rmAddObjectDefConstraint(goldID, avoidImpassableLand);
	rmAddObjectDefConstraint(goldID, smallMesaConstraint);
	rmPlaceObjectDefInArea(goldID, 0, bigIslandID, cNumberNonGaiaPlayers*3);
	
	int gold2ID = rmCreateObjectDef("random gold   2");
	rmAddObjectDefItem(gold2ID, "MineTin", 1, 0);
	rmSetObjectDefMinDistance(gold2ID, 0.0);
	rmSetObjectDefMaxDistance(gold2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(gold2ID, avoidTC);
	rmAddObjectDefConstraint(gold2ID, avoidCW);
	rmAddObjectDefConstraint(gold2ID, avoidAll);
	rmAddObjectDefConstraint(gold2ID, avoidCoinSmall);
    rmAddObjectDefConstraint(gold2ID, avoidImpassableLand);
//	rmAddObjectDefConstraint(gold2ID, smallMesaConstraint);
	rmPlaceObjectDefInArea(gold2ID, 0, smallMesaID, cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(gold2ID, 0, smallMesa2ID, cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(gold2ID, 0, smallIslandID, 3*cNumberNonGaiaPlayers);

	// Just a FEW scattered animals
	int huntID=rmCreateObjectDef("random huntable");
	
	if (whichVariation == 1)
	rmAddObjectDefItem(huntID, "Deer", rmRandInt(6,7), 7.0);
	else
	rmAddObjectDefItem(huntID, "Gazelle", rmRandInt(6,7), 7.0);

	
	rmSetObjectDefMinDistance(huntID, 0.0);
	rmSetObjectDefMaxDistance(huntID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(huntID, avoidTC);
	rmAddObjectDefConstraint(huntID, avoidCW);
	rmAddObjectDefConstraint(huntID, avoidRandomDeer);
	rmAddObjectDefConstraint(huntID, avoidRandomGazelle);
	rmAddObjectDefConstraint(huntID, avoidRandomBighorn);
	//rmAddObjectDefConstraint(huntID, avoidAll);
	//rmAddObjectDefConstraint(huntID, avoidRandomBerries);
	rmAddObjectDefConstraint(huntID, avoidImpassableLand);
	rmAddObjectDefConstraint(huntID, smallMesaConstraint);
	rmSetObjectDefCreateHerd(huntID, true);
	rmPlaceObjectDefInArea(huntID, 0, bigIslandID, cNumberNonGaiaPlayers*5);

	int hunt2ID=rmCreateObjectDef("random huntable 2");
	
	if (whichVariation == 1)
	rmAddObjectDefItem(hunt2ID, "Gazelle", rmRandInt(7,9), 7.0);
	else
	rmAddObjectDefItem(hunt2ID, "Deer", rmRandInt(7,9), 7.0);

	
	rmSetObjectDefMinDistance(hunt2ID, 0.0);
	rmSetObjectDefMaxDistance(hunt2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(hunt2ID, avoidTC);
	rmAddObjectDefConstraint(hunt2ID, avoidCW);
	rmAddObjectDefConstraint(hunt2ID, avoidRandomDeer);
	rmAddObjectDefConstraint(hunt2ID, avoidRandomGazelle);
	rmAddObjectDefConstraint(hunt2ID, avoidRandomBighorn);
	//rmAddObjectDefConstraint(hunt2ID, avoidAll);
	//rmAddObjectDefConstraint(hunt2ID, avoidRandomBerries);
	rmAddObjectDefConstraint(hunt2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(hunt2ID, smallMesaConstraint);
	rmSetObjectDefCreateHerd(hunt2ID, true);
	rmPlaceObjectDefInArea(hunt2ID, 0, smallIslandID, 1 + cNumberNonGaiaPlayers);
	
	int hunt3ID=rmCreateObjectDef("random huntable 3");
	rmAddObjectDefItem(hunt3ID, "BighornSheep", rmRandInt(7,9), 7.0);
	rmSetObjectDefMinDistance(hunt3ID, 0.0);
	rmSetObjectDefMaxDistance(hunt3ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(hunt3ID, avoidTC);
	rmAddObjectDefConstraint(hunt3ID, avoidCW);
	rmAddObjectDefConstraint(hunt3ID, avoidRandomDeer);
	rmAddObjectDefConstraint(hunt3ID, avoidRandomGazelle);
	rmAddObjectDefConstraint(hunt3ID, avoidRandomBighorn);
	//rmAddObjectDefConstraint(hunt3ID, avoidAll);
	//rmAddObjectDefConstraint(hunt3ID, avoidRandomBerries);
	rmAddObjectDefConstraint(hunt3ID, avoidImpassableLand);
//	rmAddObjectDefConstraint(hunt3ID, smallMesaConstraint);
	rmSetObjectDefCreateHerd(hunt3ID, true);
	rmPlaceObjectDefInArea(hunt3ID, 0, smallMesaID, cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(hunt3ID, 0, smallMesa2ID, cNumberNonGaiaPlayers*2);
	rmPlaceObjectDefInArea(hunt3ID, 0, smallMesa3ID, cNumberNonGaiaPlayers);

	// Define and place Nuggets
	// Easier nuggets, for the main continent
	int nugget1= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget1, 0.0);
	if (whichVariation == 1)
	rmSetNuggetDifficulty(21, 21);
	else
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

	// Tougher nuggets, for the small zone
	int nugget2= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget2, 0.0);
	if (whichVariation == 1)
	rmSetNuggetDifficulty(2, 3);
	else
	rmSetNuggetDifficulty(22, 23);
	
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNugget);
	rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget2, avoidTC);
	rmAddObjectDefConstraint(nugget2, avoidCW);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidWater8);
//	rmAddObjectDefConstraint(nugget2, smallMesaConstraint);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget2, 0, smallIslandID, 2*cNumberNonGaiaPlayers);

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
	rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*1);

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place Whales as much in big west bay only as possible --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, 0.5);		//Distance whales will be placed from the starting spot (below)
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
	rmAddObjectDefItem(randomTreeID, "TreePonderosaPine", 1, 0.0);
	rmSetObjectDefMinDistance(randomTreeID, 0.0);
	rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
	rmAddObjectDefConstraint(randomTreeID, avoidTC);
	rmAddObjectDefConstraint(randomTreeID, avoidCW);
	rmAddObjectDefConstraint(randomTreeID, avoidAll); 
//	rmAddObjectDefConstraint(randomTreeID, stayInMesa1);
	rmPlaceObjectDefInArea(randomTreeID, 0, smallMesaID, 8*cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(randomTreeID, 0, smallMesa2ID, 12*cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(randomTreeID, 0, smallMesa3ID, 8*cNumberNonGaiaPlayers);


  // King of the Hill (added 2026-11 for WoL): centre of the southern land, where every player starts
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




