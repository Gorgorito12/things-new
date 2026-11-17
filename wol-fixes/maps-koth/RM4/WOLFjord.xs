// Fjord

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
include "triggers\triggerLoader.xs";

//Trigos to make the map rotate

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
   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

  int whichVersion = rmRandInt(1,3);
  //~ whichVersion = 3; 
 
  // initialize map type variables
  string nativeCiv1 = "";
  string nativeCiv2 = "";
  string nativeCiv3 = "";
  
  string nativeString1= "";
  string nativeString2= "";
  string nativeString3= "";
 
  string baseMix = "";
  string baseTerrain = "";
 
  string forestType = "";
  string startTreeType = "";
  
  string mapType1 = "";
  string mapType2 = "";
  
  string herdableType = "";
  string huntable1 = "";
  string huntable2 = "";
  
  string lightingType = "";
  
  string guardianType = "";
  string cliffType = "";
  
  string guardianDistance = "35.0";
  int numberPosts = 5;
  int triggerCounter = 0; 
  
  string tradeRouteType = "";
  
  //Phase
 	float p = -40 + rmRandFloat(0,130);
//	float p = 0;

    nativeCiv1 = "LoggingCamp";
    nativeCiv2 = "FurTrapper";
    nativeCiv3 = "Fishing";
    nativeString1 = "european logging camp east";
    nativeString2 = "european fur trappers east";
    nativeString3 = "european fishing village east";
    baseMix = "patagonia_snow";
    baseTerrain = "patagonia\ground_snow1_pat";
    forestType = "Patagonia Snow Forest";
    startTreeType = "TreeYukonSnow";
    cliffType = "Fjord";
    mapType1 = "yukon";
    mapType2 = "snow";
    herdableType = "Sheep";
    huntable1 = "Caribou";
    huntable2 = "Elk";    
    lightingType = "st_petersburg";
    tradeRouteType = "water";
    guardianType = "ypWokou";

  
// Natives
   int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;

  if (rmAllocateSubCivs(3) == true) {
    // 1st Native Civ
    subCiv0=rmGetCivID(nativeCiv1);
    if (subCiv0 >= 0)
      rmSetSubCiv(0, nativeCiv1);

    // 2nd Native Civ
    subCiv1=rmGetCivID(nativeCiv2);
    if (subCiv1 >= 0)
      rmSetSubCiv(1, nativeCiv2);
 
	// 3th Native Civ
    subCiv2=rmGetCivID(nativeCiv3);
    if (subCiv2 >= 0)
      rmSetSubCiv(2, nativeCiv3);
  }
	
// Map Basics
	int playerTiles = 12500;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 12000;
	if (cNumberNonGaiaPlayers >6)
		playerTiles = 11500;		

	int size=2.5*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	rmSetMapElevationParameters(cElevTurbulence, 0.04, 3, 0.5, 2.0);
	rmSetMapElevationHeightBlend(1);
	
	rmSetSeaLevel(-2.0);
	rmSetSeaType("Araucania Southern Coast");
	rmSetLightingSet(lightingType);

	rmSetBaseTerrainMix(baseMix);
	rmTerrainInitialize(baseTerrain, 4.0);
	rmEnableLocalWater(false);
	rmSetMapType(mapType1);
	rmSetMapType(mapType2);
	rmSetMapType("land");
	rmSetMapType("water");
	rmSetWorldCircleConstraint(true);
	rmSetWindMagnitude(2.0);

	chooseMercs();
	wotta_triggers();
	
// Classes
	int classPlayer=rmDefineClass("player");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("classNugget");
	rmDefineClass("natives");

  bool weird = false;
  int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
    
  if (cNumberTeams > 2 || (teamZeroCount - teamOneCount) > 2 || (teamOneCount - teamZeroCount) > 2)
    weird = true;

// Constraints
    
	// Map edge constraints
	int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(12), rmZTilesToFraction(12), 1.0-rmXTilesToFraction(12), 1.0-rmZTilesToFraction(12), 0.01);

	// Player constraints
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 25.0);
  int longPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players long", classPlayer, 45.0);
	int mediumPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players medium", classPlayer, 15.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("short stay away from players", classPlayer, 5.0);
  int playerConstraintNugget = rmCreateClassDistanceConstraint("nuggets stay away from players long", classPlayer, 55.0);
  int avoidKOTH = rmCreateTypeDistanceConstraint("avoid KOTH", "ypKingsHill", 6.0);
  int nativePlayerConstraint = rmCreateTypeDistanceConstraint("avoid TCs", "TownCenter", 70.0);
  int avoidTC = rmCreateTypeDistanceConstraint("tc avoid", "TownCenter", 35.0);
  //~ int nativePlayerConstraint = rmCreateClassDistanceConstraint("avoid TCs", classPlayer, 45.0);

	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 30.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int shortAvoidResource=rmCreateTypeDistanceConstraint("resource avoid resource short", "resource", 5.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);
	   
	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);

  // resource avoidance
	int avoidSilver=rmCreateTypeDistanceConstraint("gold avoid gold", "mine", 85.0);
	int mediumAvoidSilver=rmCreateTypeDistanceConstraint("medium gold avoid gold", "mine", 30.0);
	int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid deer", huntable1, 60.0);
	int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid tapir", huntable2, 60.0);
	int avoidNuggets=rmCreateTypeDistanceConstraint("nugget vs. nugget", "AbstractNugget", 20.0);
	int avoidNuggetFar=rmCreateTypeDistanceConstraint("nugget vs. nugget far", "AbstractNugget", 70.0);
  int avoidHerdable=rmCreateTypeDistanceConstraint("herdables avoid herdables", herdableType, 75.0);

	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int circleConstraintTwo=rmCreatePieConstraint("circle Constraint 2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Unit avoidance
	int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), rmXFractionToMeters(0.2));
	int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 12.0);
	int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other short", rmClassID("importantItem"), 7.0);
	int farAvoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives alot", rmClassID("natives"), 80.0);

	// Decoration avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 7.0);

	// Trade route avoidance.
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route short", 6.0);
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 10.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 20.0);
	int avoidTradeRouteSocketsShort=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "ypTradingPostCapture", 4.0);
  int avoidTradeRouteSockets=rmCreateTypeDistanceConstraint("avoid trade route sockets", "ypTradingPostCapture", 20.0);
	int avoidTradeRouteSocketsFar=rmCreateTypeDistanceConstraint("avoid trade route sockets far", "ypTradingPostCapture", 40.0);
	int avoidMineSockets=rmCreateTypeDistanceConstraint("avoid mine sockets", "mine", 10.0);

// ❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄ SEA and FJORD ❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄❄

	int Ground00ID=rmCreateArea("Ground0-0");
	rmSetAreaSize(Ground00ID, 0.045, 0.045);
	rmSetAreaMix(Ground00ID, "great_lakes_ice");
	rmSetAreaLocation(Ground00ID, 0.48*_cos(rmDegreesToRadians(-90 + p))+0.5, 0.48*_sin(rmDegreesToRadians(-90 + p))+0.5);
	rmSetAreaWarnFailure(Ground00ID, false);
	rmSetAreaBaseHeight(Ground00ID, 4.0);
	rmSetAreaSmoothDistance(Ground00ID, 20);
	rmSetAreaCoherence(Ground00ID, .85);
	rmSetAreaObeyWorldCircleConstraint(Ground00ID, false);
	rmAddAreaInfluenceSegment(Ground00ID, 0.49*_cos(rmDegreesToRadians(-82 + p))+0.5, 0.49*_sin(rmDegreesToRadians(-82 + p))+0.5, 0.48*_cos(rmDegreesToRadians(-98 + p))+0.5, 0.48*_sin(rmDegreesToRadians(-98 + p))+0.5); 
	rmBuildArea(Ground00ID);
	
	int Ground0ID=rmCreateArea("Ground0");
	rmSetAreaSize(Ground0ID, 0.047, 0.047);
	rmSetAreaTerrainType(Ground0ID, baseTerrain);
	rmSetAreaLocation(Ground0ID, 0.48*_cos(rmDegreesToRadians(-90 + p))+0.5, 0.48*_sin(rmDegreesToRadians(-90 + p))+0.5);
	rmSetAreaWarnFailure(Ground0ID, false);
	rmSetAreaBaseHeight(Ground0ID, 4.5);
	rmSetAreaElevationVariation(Ground0ID, 6.0);
	rmSetAreaElevationMinFrequency(Ground0ID, 0.09);
	rmSetAreaElevationOctaves(Ground0ID, 3);
	rmSetAreaElevationPersistence(Ground0ID, 0.2);
	rmSetAreaElevationNoiseBias(Ground0ID, 1);
	rmSetAreaSmoothDistance(Ground0ID, 20);
	rmSetAreaCoherence(Ground0ID, .85);
	rmSetAreaObeyWorldCircleConstraint(Ground0ID, false);
	rmAddAreaInfluenceSegment(Ground0ID, 0.49*_cos(rmDegreesToRadians(-82 + p))+0.5, 0.49*_sin(rmDegreesToRadians(-82 + p))+0.5, 0.48*_cos(rmDegreesToRadians(-98 + p))+0.5, 0.48*_sin(rmDegreesToRadians(-98 + p))+0.5); 
	rmBuildArea(Ground0ID);

	int bay1ID=rmCreateArea("Bay 1");
	rmSetAreaSize(bay1ID, 0.18, 0.18);
	rmSetAreaLocation(bay1ID, 0.49*_cos(rmDegreesToRadians(90 + p))+0.5, 0.49*_sin(rmDegreesToRadians(90 + p))+0.5);
	rmSetAreaWaterType(bay1ID, "Fjord Snow");
	rmSetAreaBaseHeight(bay1ID, -2.0);
	rmSetAreaSmoothDistance(bay1ID, 20);
	rmSetAreaCoherence(bay1ID, 0.8);
	rmAddAreaInfluenceSegment(bay1ID, 0.49*_cos(rmDegreesToRadians(70 + p))+0.5, 0.49*_sin(rmDegreesToRadians(70 + p))+0.5, 0.49*_cos(rmDegreesToRadians(110 + p))+0.5, 0.49*_sin(rmDegreesToRadians(110 + p))+0.5);
	rmAddAreaInfluenceSegment(bay1ID, 0.49*_cos(rmDegreesToRadians(80 + p))+0.5, 0.49*_sin(rmDegreesToRadians(80 + p))+0.5, 0.49*_cos(rmDegreesToRadians(100 + p))+0.5, 0.49*_sin(rmDegreesToRadians(100 + p))+0.5);
	rmSetAreaObeyWorldCircleConstraint(bay1ID, false);
	rmBuildArea(bay1ID);
	
 	int bay2ID=rmCreateArea("Bay 2");
	rmSetAreaSize(bay2ID, 0.34, 0.34);
	rmSetAreaLocation(bay2ID, 0.08*_cos(rmDegreesToRadians(90 + p))+0.5, 0.08*_sin(rmDegreesToRadians(90 + p))+0.5);
	rmSetAreaWaterType(bay2ID, "Fjord Snow");
	rmSetAreaBaseHeight(bay2ID, -2.0);
	rmSetAreaSmoothDistance(bay2ID, 20);
	rmSetAreaCoherence(bay2ID, 0.8);
	rmAddAreaInfluenceSegment(bay2ID, 0.22*_cos(rmDegreesToRadians(-45 + p))+0.5, 0.22*_sin(rmDegreesToRadians(-45 + p))+0.5, 0.30*_cos(rmDegreesToRadians(60 + p))+0.5, 0.30*_sin(rmDegreesToRadians(60 + p))+0.5);
	rmAddAreaInfluenceSegment(bay2ID, 0.30*_cos(rmDegreesToRadians(60 + p))+0.5, 0.30*_sin(rmDegreesToRadians(60 + p))+0.5, 0.30*_cos(rmDegreesToRadians(120 + p))+0.5, 0.30*_sin(rmDegreesToRadians(120 + p))+0.5);
	rmAddAreaInfluenceSegment(bay2ID, 0.30*_cos(rmDegreesToRadians(120 + p))+0.5, 0.30*_sin(rmDegreesToRadians(120 + p))+0.5, 0.22*_cos(rmDegreesToRadians(-135 + p))+0.5, 0.22*_sin(rmDegreesToRadians(-135 + p))+0.5);
	rmAddAreaInfluenceSegment(bay2ID, 0.22*_cos(rmDegreesToRadians(-135 + p))+0.5, 0.22*_sin(rmDegreesToRadians(-135 + p))+0.5, 0.22*_cos(rmDegreesToRadians(-45 + p))+0.5, 0.22*_sin(rmDegreesToRadians(-45 + p))+0.5);
	rmSetAreaObeyWorldCircleConstraint(bay2ID, false);
	rmBuildArea(bay2ID);
	
  	int bay3ID=rmCreateArea("Bay 3");
	rmSetAreaSize(bay3ID, 0.02, 0.02);
	rmSetAreaLocation(bay3ID, 0.20*_cos(rmDegreesToRadians(-90 + p))+0.5, 0.20*_sin(rmDegreesToRadians(-90 + p))+0.5);
	rmSetAreaWaterType(bay3ID, "Fjord Snow");
	rmSetAreaBaseHeight(bay3ID, -2.0);
	rmSetAreaSmoothDistance(bay3ID, 20);
	rmSetAreaCoherence(bay3ID, 0.8);
	rmAddAreaInfluenceSegment(bay3ID, 0.20*_cos(rmDegreesToRadians(-90 + p))+0.5, 0.20*_sin(rmDegreesToRadians(-90 + p))+0.5, 0.37*_cos(rmDegreesToRadians(-90 + p))+0.5, 0.37*_sin(rmDegreesToRadians(-90 + p))+0.5);
//	rmAddAreaInfluenceSegment(bay3ID, 0.49*_cos(rmDegreesToRadians(80 + p))+0.5, 0.49*_sin(rmDegreesToRadians(80 + p))+0.5, 0.49*_cos(rmDegreesToRadians(100 + p))+0.5, 0.49*_sin(rmDegreesToRadians(100 + p))+0.5);
	rmSetAreaObeyWorldCircleConstraint(bay3ID, false);
	rmBuildArea(bay3ID); 

// ////////////////////////////// CLIFFS ////////////////////////////////

	int Ground1ID=rmCreateArea("Ground1");
	rmSetAreaSize(Ground1ID, 0.035, 0.035);
	rmSetAreaMix(Ground1ID, baseMix);
	rmSetAreaLocation(Ground1ID, 0.25*_cos(rmDegreesToRadians(35 + p))+0.5, 0.25*_sin(rmDegreesToRadians(35 + p))+0.5);
	rmSetAreaWarnFailure(Ground1ID, false);
	rmSetAreaBaseHeight(Ground1ID, 2.8);
	rmSetAreaSmoothDistance(Ground1ID, 20);
	rmSetAreaCoherence(Ground1ID, .85);
	rmSetAreaObeyWorldCircleConstraint(Ground1ID, false);
	rmAddAreaInfluenceSegment(Ground1ID, 0.31*_cos(rmDegreesToRadians(16 + p))+0.5, 0.31*_sin(rmDegreesToRadians(16 + p))+0.5, 0.20*_cos(rmDegreesToRadians(45 + p))+0.5, 0.20*_sin(rmDegreesToRadians(45 + p))+0.5); 
	rmAddAreaInfluenceSegment(Ground1ID, 0.20*_cos(rmDegreesToRadians(45 + p))+0.5, 0.20*_sin(rmDegreesToRadians(45 + p))+0.5, 0.35*_cos(rmDegreesToRadians(41 + p))+0.5, 0.35*_sin(rmDegreesToRadians(41 + p))+0.5); 
	rmAddAreaInfluenceSegment(Ground1ID, 0.35*_cos(rmDegreesToRadians(41 + p))+0.5, 0.35*_sin(rmDegreesToRadians(41 + p))+0.5, 0.31*_cos(rmDegreesToRadians(16 + p))+0.5, 0.31*_sin(rmDegreesToRadians(16 + p))+0.5); 

	int Ground2ID=rmCreateArea("Ground2");
	rmSetAreaSize(Ground2ID, 0.035, 0.035);
	rmSetAreaMix(Ground2ID, baseMix);
	rmSetAreaLocation(Ground2ID, 0.25*_cos(rmDegreesToRadians(145 + p))+0.5, 0.25*_sin(rmDegreesToRadians(145 + p))+0.5);
	rmSetAreaWarnFailure(Ground2ID, false);
	rmSetAreaBaseHeight(Ground2ID, 2.8);
	rmSetAreaSmoothDistance(Ground2ID, 20);
	rmSetAreaCoherence(Ground2ID, .85);
	rmSetAreaObeyWorldCircleConstraint(Ground2ID, false);
	rmAddAreaInfluenceSegment(Ground2ID, 0.31*_cos(rmDegreesToRadians(164 + p))+0.5, 0.31*_sin(rmDegreesToRadians(164 + p))+0.5, 0.20*_cos(rmDegreesToRadians(135 + p))+0.5, 0.20*_sin(rmDegreesToRadians(135 + p))+0.5); 
	rmAddAreaInfluenceSegment(Ground2ID, 0.20*_cos(rmDegreesToRadians(135 + p))+0.5, 0.20*_sin(rmDegreesToRadians(135 + p))+0.5, 0.35*_cos(rmDegreesToRadians(139 + p))+0.5, 0.35*_sin(rmDegreesToRadians(139 + p))+0.5); 
	rmAddAreaInfluenceSegment(Ground2ID, 0.35*_cos(rmDegreesToRadians(139 + p))+0.5, 0.35*_sin(rmDegreesToRadians(139 + p))+0.5, 0.31*_cos(rmDegreesToRadians(164 + p))+0.5, 0.31*_sin(rmDegreesToRadians(164 + p))+0.5); 

	rmBuildAllAreas();

	int Wall1ID=rmCreateArea("Wall1");
	rmSetAreaSize(Wall1ID, 0.055, 0.055);
	rmSetAreaLocation(Wall1ID, 0.49*_cos(rmDegreesToRadians(40 + p))+0.5, 0.49*_sin(rmDegreesToRadians(40 + p))+0.5);
	rmSetAreaWarnFailure(Wall1ID, false);
	rmSetAreaBaseHeight(Wall1ID, 3.8);
	rmSetAreaMix(Wall1ID, baseMix);
	rmSetAreaSmoothDistance(Wall1ID, 10);
	rmSetAreaCoherence(Wall1ID, .85);
	rmSetAreaCliffType(Wall1ID, cliffType);
	rmSetAreaCliffEdge(Wall1ID, 6, 0.8, 0, 1.0, 0);
	rmSetAreaCliffHeight(Wall1ID, 0, 0, 0.0);
	rmSetAreaCliffPainting(Wall1ID, true, true, true, 0, true);
	rmSetAreaObeyWorldCircleConstraint(Wall1ID, false);
	rmAddAreaInfluenceSegment(Wall1ID, 0.46*_cos(rmDegreesToRadians(40 + p))+0.5, 0.46*_sin(rmDegreesToRadians(40 + p))+0.5, 0.24*_cos(rmDegreesToRadians(58 + p))+0.5, 0.24*_sin(rmDegreesToRadians(58 + p))+0.5); 
	rmAddAreaInfluenceSegment(Wall1ID, 0.24*_cos(rmDegreesToRadians(58 + p))+0.5, 0.24*_sin(rmDegreesToRadians(58 + p))+0.5, 0.20*_cos(rmDegreesToRadians(45 + p))+0.5, 0.20*_sin(rmDegreesToRadians(45 + p))+0.5); 

	int Wall2ID=rmCreateArea("Wall2");
	rmSetAreaSize(Wall2ID, 0.055, 0.055);
	rmSetAreaLocation(Wall2ID, 0.49*_cos(rmDegreesToRadians(140 + p))+0.5, 0.49*_sin(rmDegreesToRadians(140 + p))+0.5);
	rmSetAreaWarnFailure(Wall2ID, false);
	rmSetAreaBaseHeight(Wall2ID, 3.8);
	rmSetAreaMix(Wall2ID, baseMix);
	rmSetAreaSmoothDistance(Wall2ID, 10);
	rmSetAreaCoherence(Wall2ID, .85);
	rmSetAreaCliffType(Wall2ID, cliffType);
	rmSetAreaCliffEdge(Wall2ID, 6, 0.8, 0, 1.0, 0);
	rmSetAreaCliffHeight(Wall2ID, 0, 0, 0.0);
	rmSetAreaCliffPainting(Wall2ID, true, true, true, 0, true);
	rmSetAreaObeyWorldCircleConstraint(Wall2ID, false);
	rmAddAreaInfluenceSegment(Wall2ID, 0.46*_cos(rmDegreesToRadians(140 + p))+0.5, 0.46*_sin(rmDegreesToRadians(140 + p))+0.5, 0.24*_cos(rmDegreesToRadians(122 + p))+0.5, 0.24*_sin(rmDegreesToRadians(122 + p))+0.5); 
	rmAddAreaInfluenceSegment(Wall2ID, 0.24*_cos(rmDegreesToRadians(122 + p))+0.5, 0.24*_sin(rmDegreesToRadians(122 + p))+0.5, 0.20*_cos(rmDegreesToRadians(135 + p))+0.5, 0.20*_sin(rmDegreesToRadians(135 + p))+0.5); 

	int Wall3ID=rmCreateArea("Wall3");
	rmSetAreaSize(Wall3ID, 0.036, 0.036);
	rmSetAreaLocation(Wall3ID, 0.30*_cos(rmDegreesToRadians(-15 + p))+0.5, 0.30*_sin(rmDegreesToRadians(-15 + p))+0.5);
	rmSetAreaWarnFailure(Wall3ID, false);
	rmSetAreaBaseHeight(Wall3ID, 3.8);
	rmSetAreaMix(Wall3ID, baseMix);
	rmSetAreaSmoothDistance(Wall3ID, 10);
	rmSetAreaCoherence(Wall3ID, .85);
	rmSetAreaCliffType(Wall3ID, cliffType);
	rmSetAreaCliffEdge(Wall3ID, 6, 0.8, 0, 1.0, 0);
	rmSetAreaCliffHeight(Wall3ID, 0, 0, 0.0);
	rmSetAreaCliffPainting(Wall3ID, true, true, true, 0, true);
	rmSetAreaObeyWorldCircleConstraint(Wall3ID, false);
	rmAddAreaInfluenceSegment(Wall3ID, 0.30*_cos(rmDegreesToRadians(-15 + p))+0.5, 0.30*_sin(rmDegreesToRadians(-15 + p))+0.5, 0.34*_cos(rmDegreesToRadians(-20 + p))+0.5, 0.34*_sin(rmDegreesToRadians(-20 + p))+0.5); 
	rmAddAreaInfluenceSegment(Wall3ID, 0.34*_cos(rmDegreesToRadians(-20 + p))+0.5, 0.34*_sin(rmDegreesToRadians(-20 + p))+0.5, 0.17*_cos(rmDegreesToRadians(-12 + p))+0.5, 0.14*_sin(rmDegreesToRadians(-12 + p))+0.5); 
	rmAddAreaInfluenceSegment(Wall3ID, 0.17*_cos(rmDegreesToRadians(-12 + p))+0.5, 0.17*_sin(rmDegreesToRadians(-12 + p))+0.5, 0.30*_cos(rmDegreesToRadians(-15 + p))+0.5, 0.30*_sin(rmDegreesToRadians(-15 + p))+0.5); 

	int Wall4ID=rmCreateArea("Wall4");
	rmSetAreaSize(Wall4ID, 0.036, 0.036);
	rmSetAreaLocation(Wall4ID, 0.34*_cos(rmDegreesToRadians(-165 + p))+0.5, 0.34*_sin(rmDegreesToRadians(-165 + p))+0.5);
	rmSetAreaWarnFailure(Wall4ID, false);
	rmSetAreaBaseHeight(Wall4ID, 3.8);
	rmSetAreaMix(Wall4ID, baseMix);
	rmSetAreaSmoothDistance(Wall4ID, 10);
	rmSetAreaCoherence(Wall4ID, .85);
	rmSetAreaCliffType(Wall4ID, cliffType);
	rmSetAreaCliffEdge(Wall4ID, 6, 0.8, 0, 1.0, 0);
	rmSetAreaCliffHeight(Wall4ID, 0, 0, 0.0);
	rmSetAreaCliffPainting(Wall4ID, true, true, true, 0, true);
	rmSetAreaObeyWorldCircleConstraint(Wall4ID, false);
	rmAddAreaInfluenceSegment(Wall4ID, 0.34*_cos(rmDegreesToRadians(-165 + p))+0.5, 0.34*_sin(rmDegreesToRadians(-165 + p))+0.5, 0.37*_cos(rmDegreesToRadians(-160 + p))+0.5, 0.37*_sin(rmDegreesToRadians(-160 + p))+0.5); 
	rmAddAreaInfluenceSegment(Wall4ID, 0.37*_cos(rmDegreesToRadians(-160 + p))+0.5, 0.37*_sin(rmDegreesToRadians(-160 + p))+0.5, 0.17*_cos(rmDegreesToRadians(-168 + p))+0.5, 0.17*_sin(rmDegreesToRadians(-168 + p))+0.5); 
	rmAddAreaInfluenceSegment(Wall4ID, 0.17*_cos(rmDegreesToRadians(-168 + p))+0.5, 0.17*_sin(rmDegreesToRadians(-168 + p))+0.5, 0.34*_cos(rmDegreesToRadians(-165 + p))+0.5, 0.34*_sin(rmDegreesToRadians(-165 + p))+0.5); 

	int Wall5ID=rmCreateArea("Wall5");
	rmSetAreaSize(Wall5ID, 0.035, 0.035);
	rmSetAreaLocation(Wall5ID, 0.28*_cos(rmDegreesToRadians(-67 + p))+0.5, 0.28*_sin(rmDegreesToRadians(-67 + p))+0.5);
	rmSetAreaWarnFailure(Wall5ID, false);
	rmSetAreaBaseHeight(Wall5ID, 3.8);
	rmSetAreaMix(Wall5ID, baseMix);
	rmSetAreaSmoothDistance(Wall5ID, 10);
	rmSetAreaCoherence(Wall5ID, .85);
	rmSetAreaCliffType(Wall5ID, cliffType);
	rmSetAreaCliffEdge(Wall5ID, 6, 0.8, 0, 1.0, 0);
	rmSetAreaCliffHeight(Wall5ID, 0, 0, 0.0);
	rmSetAreaCliffPainting(Wall5ID, true, true, true, 0, true);
	rmSetAreaObeyWorldCircleConstraint(Wall5ID, false);
	rmAddAreaInfluenceSegment(Wall5ID, 0.25*_cos(rmDegreesToRadians(-65 + p))+0.5, 0.25*_sin(rmDegreesToRadians(-65 + p))+0.5, 0.40*_cos(rmDegreesToRadians(-52 + p))+0.5, 0.40*_sin(rmDegreesToRadians(-52 + p))+0.5); 
	rmAddAreaInfluenceSegment(Wall5ID, 0.40*_cos(rmDegreesToRadians(-52 + p))+0.5, 0.40*_sin(rmDegreesToRadians(-52 + p))+0.5, 0.28*_cos(rmDegreesToRadians(-67 + p))+0.5, 0.28*_sin(rmDegreesToRadians(-67 + p))+0.5); 
	rmAddAreaInfluenceSegment(Wall5ID, 0.28*_cos(rmDegreesToRadians(-67 + p))+0.5, 0.28*_sin(rmDegreesToRadians(-67 + p))+0.5, 0.24*_cos(rmDegreesToRadians(-65 + p))+0.5, 0.24*_sin(rmDegreesToRadians(-65 + p))+0.5); 

   rmSetStatusText("",0.30);

	int Wall6ID=rmCreateArea("Wall6");
	rmSetAreaSize(Wall6ID, 0.035, 0.035);
	rmSetAreaLocation(Wall6ID, 0.28*_cos(rmDegreesToRadians(-113 + p))+0.5, 0.28*_sin(rmDegreesToRadians(-113 + p))+0.5);
	rmSetAreaWarnFailure(Wall6ID, false);
	rmSetAreaBaseHeight(Wall6ID, 3.8);
	rmSetAreaMix(Wall6ID, baseMix);
	rmSetAreaSmoothDistance(Wall6ID, 10);
	rmSetAreaCoherence(Wall6ID, .85);
	rmSetAreaCliffType(Wall6ID, cliffType);
	rmSetAreaCliffEdge(Wall6ID, 6, 0.8, 0, 1.0, 0);
	rmSetAreaCliffHeight(Wall6ID, 0, 0, 0.0);
	rmSetAreaCliffPainting(Wall6ID, true, true, true, 0, true);
	rmSetAreaObeyWorldCircleConstraint(Wall6ID, false);
	rmAddAreaInfluenceSegment(Wall6ID, 0.25*_cos(rmDegreesToRadians(-115 + p))+0.5, 0.25*_sin(rmDegreesToRadians(-115 + p))+0.5, 0.40*_cos(rmDegreesToRadians(-128 + p))+0.5, 0.40*_sin(rmDegreesToRadians(-128 + p))+0.5); 
	rmAddAreaInfluenceSegment(Wall6ID, 0.40*_cos(rmDegreesToRadians(-128 + p))+0.5, 0.40*_sin(rmDegreesToRadians(-128 + p))+0.5, 0.28*_cos(rmDegreesToRadians(-113 + p))+0.5, 0.28*_sin(rmDegreesToRadians(-113 + p))+0.5); 
	rmAddAreaInfluenceSegment(Wall6ID, 0.28*_cos(rmDegreesToRadians(-113 + p))+0.5, 0.28*_sin(rmDegreesToRadians(-113 + p))+0.5, 0.25*_cos(rmDegreesToRadians(-115 + p))+0.5, 0.25*_sin(rmDegreesToRadians(-115 + p))+0.5); 

	int GlacierID=rmCreateArea("Glacier1");
	rmSetAreaSize(GlacierID, 0.022, 0.022);
	rmSetAreaLocation(GlacierID, 0.49*_cos(rmDegreesToRadians(-90 + p))+0.5, 0.49*_sin(rmDegreesToRadians(-90 + p))+0.5);
	rmSetAreaWarnFailure(GlacierID, false);
	rmSetAreaBaseHeight(GlacierID, 3.6);
	rmSetAreaSmoothDistance(GlacierID, 10);
	rmSetAreaCoherence(GlacierID, .85);
	rmSetAreaCliffType(GlacierID, "Glacier");
	rmSetAreaCliffEdge(GlacierID, 6, 0.8, 0, 1.0, 0);
	rmSetAreaCliffHeight(GlacierID, 0, 0, 0.0);
	rmSetAreaCliffPainting(GlacierID, true, true, true, 0, true);
	rmSetAreaObeyWorldCircleConstraint(GlacierID, false);
	rmAddAreaInfluenceSegment(GlacierID, 0.40*_cos(rmDegreesToRadians(-82 + p))+0.5, 0.40*_sin(rmDegreesToRadians(-82 + p))+0.5, 0.40*_cos(rmDegreesToRadians(-98 + p))+0.5, 0.40*_sin(rmDegreesToRadians(-98 + p))+0.5); 
	rmAddAreaInfluenceSegment(GlacierID, 0.40*_cos(rmDegreesToRadians(-98 + p))+0.5, 0.40*_sin(rmDegreesToRadians(-98 + p))+0.5, 0.49*_cos(rmDegreesToRadians(-97 + p))+0.5, 0.49*_sin(rmDegreesToRadians(-97 + p))+0.5); 
	rmAddAreaInfluenceSegment(GlacierID, 0.49*_cos(rmDegreesToRadians(-97 + p))+0.5, 0.49*_sin(rmDegreesToRadians(-97 + p))+0.5, 0.49*_cos(rmDegreesToRadians(-83 + p))+0.5, 0.49*_sin(rmDegreesToRadians(-83 + p))+0.5); 
	rmAddAreaInfluenceSegment(GlacierID, 0.49*_cos(rmDegreesToRadians(-83 + p))+0.5, 0.49*_sin(rmDegreesToRadians(-83 + p))+0.5, 0.40*_cos(rmDegreesToRadians(-82 + p))+0.5, 0.40*_sin(rmDegreesToRadians(-82 + p))+0.5); 

	rmBuildAllAreas();
	
	int avoidGlacier = rmCreateAreaDistanceConstraint("avoid glacier ", GlacierID, 5.0);

// ************************** DEFINE OBJECTS ****************************
	
  int deerID=rmCreateObjectDef("huntable1");
	rmAddObjectDefItem(deerID, huntable1, rmRandInt(8,10), 6.0);
	rmSetObjectDefCreateHerd(deerID, true);
	rmSetObjectDefMinDistance(deerID, 0.0);
	rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(deerID, avoidResource);
	rmAddObjectDefConstraint(deerID, playerConstraint);
	rmAddObjectDefConstraint(deerID, avoidImpassableLand);
	rmAddObjectDefConstraint(deerID, avoidHuntable1);
	rmAddObjectDefConstraint(deerID, avoidHuntable2);
  rmAddObjectDefConstraint(deerID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(deerID, avoidTradeRouteSockets);
	rmAddObjectDefConstraint(deerID, avoidGlacier);
  
  int tapirID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(tapirID, huntable2, rmRandInt(10,12), 6.0);
	rmSetObjectDefCreateHerd(tapirID, true);
	rmSetObjectDefMinDistance(tapirID, 0.0);
	rmSetObjectDefMaxDistance(tapirID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(tapirID, avoidResource);
	rmAddObjectDefConstraint(tapirID, playerConstraint);
	rmAddObjectDefConstraint(tapirID, avoidImpassableLand);
	rmAddObjectDefConstraint(tapirID, avoidHuntable1);
	rmAddObjectDefConstraint(tapirID, avoidHuntable2);
	rmAddObjectDefConstraint(tapirID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(tapirID, avoidTradeRouteSockets);
	rmAddObjectDefConstraint(tapirID, avoidGlacier);

  
  int StartDeerID=rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(StartDeerID, huntable1, 7, 4.0);
	rmSetObjectDefMinDistance(StartDeerID, 12.0);
	rmSetObjectDefMaxDistance(StartDeerID, 18.0);
	rmSetObjectDefCreateHerd(StartDeerID, false);
	rmAddObjectDefConstraint(StartDeerID, avoidHuntable1);    
	rmAddObjectDefConstraint(StartDeerID, avoidHuntable2);    
	rmAddObjectDefConstraint(StartDeerID, avoidGlacier);
   
	// -------------Done defining objects
  // Text
  rmSetStatusText("",0.10);

// Players
  
  // Set up player areas.
  float playerFraction=rmAreaTilesToFraction(100);
  for(i=1; <cNumberPlayers) {
    int id=rmCreateArea("Player"+i);
    rmSetPlayerArea(i, id);
    rmSetAreaSize(id, playerFraction, playerFraction);
    rmAddAreaToClass(id, classPlayer);
    rmAddAreaConstraint(id, avoidTradeRouteSockets); 
    rmAddAreaConstraint(id, shortAvoidImportantItem); 
    rmAddAreaConstraint(id, playerConstraint); 
    rmAddAreaConstraint(id, playerEdgeConstraint); 
    rmSetAreaCoherence(id, 1.0);
    //~ rmSetAreaLocPlayer(id, i);
    rmSetAreaWarnFailure(id, false);
  }
  
  // Build the areas.
  rmBuildAllAreas();
  
   // Text
   rmSetStatusText("",0.40);
  
   // Players start
  
  if (cNumberTeams == 2) {
   
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
   
    rmSetPlacementTeam(teamOne);
    rmPlacePlayersLine(0.30*_cos(rmDegreesToRadians(48 + p))+0.5, 0.30*_sin(rmDegreesToRadians(48 + p))+0.5, 0.42*_cos(rmDegreesToRadians(2 + p))+0.5, 0.42*_sin(rmDegreesToRadians(2 + p))+0.5, .05, .05);
  
    rmSetPlacementTeam(teamTwo);
    rmPlacePlayersLine(0.30*_cos(rmDegreesToRadians(132 + p))+0.5, 0.30*_sin(rmDegreesToRadians(132 + p))+0.5, 0.42*_cos(rmDegreesToRadians(178 + p))+0.5, 0.42*_sin(rmDegreesToRadians(178 + p))+0.5, .05, .05);
  }
  
  // ffa
   else {
    rmSetTeamSpacingModifier(0.3);
	rmSetPlacementSection(0.15 - 0.00277*p, 0.85 - 0.00277*p);
    rmPlacePlayersCircular(0.44, 0.44, 0);
  }

  // starting resources
  int TCfloat = -1;
	if (cNumberNonGaiaPlayers <= 4)
		TCfloat = 15;
  else if (cNumberTeams > 2)
    TCfloat = 15;
	else if (weird)
    TCfloat = 50;
  else
		TCfloat = 20;

  int startingTCID= rmCreateObjectDef("startingTC");
	if (rmGetNomadStart()) {
			rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 5.0);
  }
		
  else {
    rmAddObjectDefItem(startingTCID, "townCenter", 1, 5.0);
  }

  rmSetObjectDefMinDistance(startingTCID, 0);
	rmSetObjectDefMaxDistance(startingTCID, TCfloat);
	rmAddObjectDefConstraint(startingTCID, avoidImpassableLand);
  rmAddObjectDefConstraint(startingTCID, avoidTC);
  rmAddObjectDefConstraint(startingTCID, avoidTradeRouteSockets);
	rmAddObjectDefToClass(startingTCID, rmClassID("player"));

  int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 8, 6.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 16);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 22);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartResource);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImportantItem);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRouteSockets);

   // Text
   rmSetStatusText("",0.50);

  int startSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(startSilverID, "mine", 1, 0);
	rmSetObjectDefMinDistance(startSilverID, 12.0);
	rmSetObjectDefMaxDistance(startSilverID, 20.0);
	rmAddObjectDefConstraint(startSilverID, avoidAll);
	rmAddObjectDefConstraint(startSilverID, avoidImpassableLand);

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 5.0);
  rmSetObjectDefMaxDistance(startingUnits, 10.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);

  int playerCrateID=rmCreateObjectDef("bonus starting wood");
  rmAddObjectDefItem(playerCrateID, "crateOfWood", 3, 3.0);
  rmSetObjectDefMinDistance(playerCrateID, 4);
  rmSetObjectDefMaxDistance(playerCrateID, 8);
  rmAddObjectDefConstraint(playerCrateID, avoidStartResource);
  rmAddObjectDefConstraint(playerCrateID, shortAvoidImpassableLand);
  
  	// Market
	int startResourceBuildingID=rmCreateObjectDef("starting resource building");
  rmAddObjectDefItem(startResourceBuildingID, "Market", 1, 0.0);
	rmSetObjectDefMinDistance(startResourceBuildingID, 16.0);
	rmSetObjectDefMaxDistance(startResourceBuildingID, 20.0);
  rmAddObjectDefConstraint(startResourceBuildingID, avoidAll);
	rmAddObjectDefConstraint(startResourceBuildingID, avoidImpassableLand);
  
  // Asian Market
  int startResourceBuildingAsianID=rmCreateObjectDef("starting resource building asian");
  rmAddObjectDefItem(startResourceBuildingAsianID, "ypTradeMarketAsian", 1, 0.0);
	rmSetObjectDefMinDistance(startResourceBuildingAsianID, 16.0);
	rmSetObjectDefMaxDistance(startResourceBuildingAsianID, 20.0);
  rmAddObjectDefConstraint(startResourceBuildingAsianID, avoidAll);
	rmAddObjectDefConstraint(startResourceBuildingAsianID, avoidImpassableLand);
  
  int playerNuggetID=rmCreateObjectDef("player nugget");
  rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
  rmSetObjectDefMinDistance(playerNuggetID, 15.0);
  rmSetObjectDefMaxDistance(playerNuggetID, 20.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);
  rmAddObjectDefConstraint(playerNuggetID, avoidTradeRoute);
  
	// Text
	rmSetStatusText("",0.60);

	for(i=1; < cNumberPlayers) {
		rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLocation=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(startSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(StartDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
         
    // Place a nugget for the player
    rmSetNuggetDifficulty(1, 1);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
         
	}

  // Natives
  
    //1
    int nativeArea1=rmCreateArea("native1");
    rmSetAreaSize(nativeArea1, .04, .04);
    rmAddAreaConstraint(nativeArea1, circleConstraintTwo); 
    rmSetAreaCoherence(nativeArea1, 1.0);
  
    if(cNumberTeams == 2) {
      rmSetAreaLocation(nativeArea1, 0.42*_cos(rmDegreesToRadians(-12 + p))+0.5, 0.42*_sin(rmDegreesToRadians(-12 + p))+0.5);
    }
    
    else {
      rmSetAreaLocation(nativeArea1, 0.35*_cos(rmDegreesToRadians(110 + p))+0.5, 0.35*_sin(rmDegreesToRadians(110 + p))+0.5);
    }
    
    //2
    int nativeArea2=rmCreateArea("native2");
    rmSetAreaSize(nativeArea2, .04, .04);
    rmAddAreaConstraint(nativeArea2, circleConstraintTwo); 
    rmSetAreaCoherence(nativeArea2, 1.0);
  
    if(cNumberTeams == 2) {
      rmSetAreaLocation(nativeArea2, 0.42*_cos(rmDegreesToRadians(-168 + p))+0.5, 0.42*_sin(rmDegreesToRadians(-168 + p))+0.5);
    }
    
    else {
      rmSetAreaLocation(nativeArea2, 0.35*_cos(rmDegreesToRadians(70 + p))+0.5, 0.35*_sin(rmDegreesToRadians(70 + p))+0.5);
    }
    
    //3
    int nativeArea3=rmCreateArea("native3");
    rmSetAreaSize(nativeArea3, .045, .045);
    rmAddAreaConstraint(nativeArea3, circleConstraintTwo);
    rmSetAreaCoherence(nativeArea3, 1.0);
  
    if(cNumberTeams == 2) {
      rmSetAreaLocation(nativeArea3, 0.25*_cos(rmDegreesToRadians(-7 + p))+0.5, 0.25*_sin(rmDegreesToRadians(-7 + p))+0.5);
    }
    
    else {
      rmSetAreaLocation(nativeArea3, 0.26*_cos(rmDegreesToRadians(-173 + p))+0.5, 0.26*_sin(rmDegreesToRadians(-173 + p))+0.5);
    }
    
    //4
    int nativeArea4=rmCreateArea("native4");
    rmSetAreaSize(nativeArea4, .045, .045);
    rmAddAreaConstraint(nativeArea4, circleConstraintTwo); 
    rmSetAreaCoherence(nativeArea4, 1.0);
  
    if(cNumberTeams == 2) {
      rmSetAreaLocation(nativeArea4, 0.25*_cos(rmDegreesToRadians(-173 + p))+0.5, 0.25*_sin(rmDegreesToRadians(-173 + p))+0.5);
    }
    
    else {
      rmSetAreaLocation(nativeArea4, 0.26*_cos(rmDegreesToRadians(-7 + p))+0.5, 0.26*_sin(rmDegreesToRadians(-7 + p))+0.5);
    }
    
    //5
    int nativeArea5=rmCreateArea("native5");
    rmSetAreaSize(nativeArea5, .045, .045);
    rmAddAreaConstraint(nativeArea5, circleConstraintTwo); 
    rmSetAreaCoherence(nativeArea5, 1.0);
  
    if(cNumberTeams == 2) {
      rmSetAreaLocation(nativeArea5, 0.30*_cos(rmDegreesToRadians(-55 + p))+0.5, 0.30*_sin(rmDegreesToRadians(-55 + p))+0.5);
    }
    
    else {
      rmSetAreaLocation(nativeArea5, 0.32*_cos(rmDegreesToRadians(-125 + p))+0.5, 0.32*_sin(rmDegreesToRadians(-125 + p))+0.5);
    }
    
    //6
    int nativeArea6=rmCreateArea("native6");
    rmSetAreaSize(nativeArea6, .045, .045);
    rmAddAreaConstraint(nativeArea6, circleConstraintTwo); 
    rmSetAreaCoherence(nativeArea6, 1.0);
  
    if(cNumberTeams == 2) {
      rmSetAreaLocation(nativeArea6, 0.30*_cos(rmDegreesToRadians(-125 + p))+0.5, 0.30*_sin(rmDegreesToRadians(-125 + p))+0.5);
    }
    
    else {
      rmSetAreaLocation(nativeArea6, 0.32*_cos(rmDegreesToRadians(-55 + p))+0.5, 0.32*_sin(rmDegreesToRadians(-55 + p))+0.5);
    }
    
    rmBuildAllAreas();
  
  // always at least one native village of each type
  if (subCiv0 == rmGetCivID(nativeCiv1)) {  
    int nativeVillage1Type = rmRandInt(1,5);
    int nativeVillage1ID = rmCreateGrouping("native village 1", nativeString1);
    rmSetGroupingMinDistance(nativeVillage1ID, 0.0);
    rmSetGroupingMaxDistance(nativeVillage1ID, 10.0);
    rmAddGroupingToClass(nativeVillage1ID, rmClassID("importantItem"));
    rmAddGroupingConstraint(nativeVillage1ID, nativePlayerConstraint);
    rmAddGroupingConstraint(nativeVillage1ID, avoidTradeRoute);
    rmAddGroupingConstraint(nativeVillage1ID, circleConstraintTwo);
    rmAddGroupingConstraint(nativeVillage1ID, avoidTradeRouteSockets);
    rmAddGroupingConstraint(nativeVillage1ID, avoidImportantItem);
    rmPlaceGroupingInArea(nativeVillage1ID, 0, nativeArea1, 1);
  }	

  if (subCiv1 == rmGetCivID(nativeCiv2)) {  
    int nativeVillage2Type = rmRandInt(1,5);
    int nativeVillage2ID = rmCreateGrouping("native village 2", nativeString2);
    rmSetGroupingMinDistance(nativeVillage2ID, 0.0);
    rmSetGroupingMaxDistance(nativeVillage2ID, 10.0);
    rmAddGroupingToClass(nativeVillage2ID, rmClassID("importantItem"));
    rmAddGroupingConstraint(nativeVillage2ID, nativePlayerConstraint);
    rmAddGroupingConstraint(nativeVillage2ID, avoidTradeRoute);
    rmAddGroupingConstraint(nativeVillage2ID, circleConstraintTwo);
    rmAddGroupingConstraint(nativeVillage2ID, avoidTradeRouteSockets);
    rmAddGroupingConstraint(nativeVillage2ID, avoidImportantItem);
    rmPlaceGroupingInArea(nativeVillage2ID, 0, nativeArea2, 1);
  }   

  // Two more Natives for four and above
  int whichNative = 0;
  
  if(cNumberNonGaiaPlayers > 3) {
    int randomNativeType = rmRandInt(1,5);
    int randomNativeID = 0;
    whichNative = rmRandInt(1,3);
    if(whichNative == 1)
      randomNativeID = rmCreateGrouping("random village 1a", nativeString1);
    else if(whichNative == 2)
      randomNativeID = rmCreateGrouping("random village 1b", nativeString2);
    else
      randomNativeID = rmCreateGrouping("random village 1c", nativeString3);
    rmSetGroupingMinDistance(randomNativeID, 0.0);
    rmSetGroupingMaxDistance(randomNativeID, 10.0);
    rmAddGroupingToClass(randomNativeID, rmClassID("importantItem"));
    rmAddGroupingConstraint(randomNativeID, nativePlayerConstraint);
    rmAddGroupingConstraint(randomNativeID, avoidTradeRoute);
    rmAddGroupingConstraint(randomNativeID, circleConstraintTwo);
    rmAddGroupingConstraint(randomNativeID, avoidTradeRouteSockets);
    rmAddGroupingConstraint(randomNativeID, avoidImportantItem);
    rmPlaceGroupingInArea(randomNativeID, 0, nativeArea3, 1);
    
    int randomNativeType1 = rmRandInt(1,5);
    int randomNativeID1 = 0;
    whichNative = rmRandInt(1,3);
    if(whichNative == 1)
      randomNativeID1 = rmCreateGrouping("random village 2a", nativeString1);
    else if(whichNative == 2)
      randomNativeID1 = rmCreateGrouping("random village 2b", nativeString2);
    else
      randomNativeID1 = rmCreateGrouping("random village 2c", nativeString3);
    rmSetGroupingMinDistance(randomNativeID1, 0.0);
    rmSetGroupingMaxDistance(randomNativeID1, 10.0);
    rmAddGroupingToClass(randomNativeID1, rmClassID("importantItem"));
    rmAddGroupingConstraint(randomNativeID1, nativePlayerConstraint);
    rmAddGroupingConstraint(randomNativeID1, avoidTradeRoute);
    rmAddGroupingConstraint(randomNativeID1, circleConstraintTwo);
    rmAddGroupingConstraint(randomNativeID1, avoidTradeRouteSockets);
    rmAddGroupingConstraint(randomNativeID1, avoidImportantItem);
    rmPlaceGroupingInArea(randomNativeID1, 0, nativeArea4, 1);
  }
  
  // Two more natives for 6 and above
  if(cNumberNonGaiaPlayers > 5) {
    int randomNativeType2 = rmRandInt(1,5);
    int randomNativeID2 = 0;
    whichNative = rmRandInt(1,3);
    if(whichNative == 1)
      randomNativeID2 = rmCreateGrouping("random village 3a", nativeString1);
    else if(whichNative == 1)
      randomNativeID2 = rmCreateGrouping("random village 3b", nativeString2);
    else
      randomNativeID2 = rmCreateGrouping("random village 3c", nativeString3);
    rmSetGroupingMinDistance(randomNativeID2, 0.0);
    rmSetGroupingMaxDistance(randomNativeID2, 10.0);
    rmAddGroupingToClass(randomNativeID2, rmClassID("importantItem"));
    rmAddGroupingConstraint(randomNativeID2, nativePlayerConstraint);
    rmAddGroupingConstraint(randomNativeID2, avoidTradeRoute);
    rmAddGroupingConstraint(randomNativeID2, circleConstraintTwo);
    rmAddGroupingConstraint(randomNativeID2, avoidTradeRouteSockets);
    rmAddGroupingConstraint(randomNativeID2, avoidImportantItem);
    rmPlaceGroupingInArea(randomNativeID2, 0, nativeArea5, 1);
    
    int randomNativeType3 = rmRandInt(1,5);
    int randomNativeID3 = 0;
    whichNative = rmRandInt(1,3);
    if(whichNative == 1)
      randomNativeID3 = rmCreateGrouping("random village 4a", nativeString1);
    else if(whichNative == 2)
      randomNativeID3 = rmCreateGrouping("random village 4b", nativeString2);
    else
      randomNativeID3 = rmCreateGrouping("random village 4c", nativeString3);
    rmSetGroupingMinDistance(randomNativeID3, 0.0);
    rmSetGroupingMaxDistance(randomNativeID3, 10.0);
    rmAddGroupingToClass(randomNativeID3, rmClassID("importantItem"));
    rmAddGroupingConstraint(randomNativeID3, nativePlayerConstraint);
    rmAddGroupingConstraint(randomNativeID3, avoidTradeRoute);
    rmAddGroupingConstraint(randomNativeID3, circleConstraintTwo);
    rmAddGroupingConstraint(randomNativeID3, avoidTradeRouteSockets);
    rmAddGroupingConstraint(randomNativeID3, avoidImportantItem);
    rmPlaceGroupingInArea(randomNativeID3, 0, nativeArea6, 1);
  }
  
	// Text
	rmSetStatusText("",0.70);

	// Text
	rmSetStatusText("",0.80);
 
	// Text
	rmSetStatusText("",0.85);

  // check for KOTH game mode  
	// Silver
	int silverID = -1;
 	int silverID2 = -1;

  int silverCount = 0;
  
  if (whichVersion == 2)
	  silverCount = 4;	
  
  else 
    silverCount = 3;
  
	rmEchoInfo("silver count = "+silverCount);

  silverID = rmCreateObjectDef("silver mines"+i);
  rmAddObjectDefItem(silverID, "mine", rmRandInt(1,1), 5.0);
  rmSetObjectDefMinDistance(silverID, 0.0);
  rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(silverID, avoidImpassableLand);
  rmAddObjectDefConstraint(silverID, avoidSilver);
  rmAddObjectDefConstraint(silverID, avoidKOTH);
  rmAddObjectDefConstraint(silverID, longPlayerConstraint);
  rmAddObjectDefConstraint(silverID, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(silverID, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(silverID, avoidGlacier);
  rmPlaceObjectDefPerPlayer(silverID, false, silverCount);
 
  silverID2 = rmCreateObjectDef("closer silver mines"+i);
  rmAddObjectDefItem(silverID2, "mine", rmRandInt(1,1), 5.0);
  rmSetObjectDefMinDistance(silverID2, rmXFractionToMeters(0.1));
  rmSetObjectDefMaxDistance(silverID2, rmXFractionToMeters(0.4));
  rmAddObjectDefConstraint(silverID2, avoidImpassableLand);
  rmAddObjectDefConstraint(silverID2, avoidSilver);
  rmAddObjectDefConstraint(silverID2, avoidKOTH);
  rmAddObjectDefConstraint(silverID2, playerConstraint);
  rmAddObjectDefConstraint(silverID2, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(silverID2, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(silverID2, avoidGlacier);
  rmPlaceObjectDefPerPlayer(silverID2, false, silverCount);

// Forests
	int forestTreeID = 0;
	
	int numTries=10*cNumberNonGaiaPlayers; 
	int failCount=0;
	for (i=0; <numTries)	{   
    int forestID=rmCreateArea("forest"+i);
    rmAddAreaToClass(forestID, rmClassID("classForest"));
    rmSetAreaWarnFailure(forestID, false);
    rmSetAreaSize(forestID, rmAreaTilesToFraction(200), rmAreaTilesToFraction(300));
    rmSetAreaForestType(forestID, forestType);
    
    if(whichVersion == 2)
      rmSetAreaForestDensity(forestID, 0.9);
    
    else
      rmSetAreaForestDensity(forestID, 0.95);
    
    rmSetAreaForestClumpiness(forestID, 0.7);
    rmSetAreaForestUnderbrush(forestID, 0.0);
    rmSetAreaMinBlobs(forestID, 1);
    rmSetAreaMaxBlobs(forestID, 2);					
    rmSetAreaMinBlobDistance(forestID, 6.0);
    rmSetAreaMaxBlobDistance(forestID, 10.0);
    rmSetAreaCoherence(forestID, 0.4);
    rmSetAreaSmoothDistance(forestID, 10);
    rmAddAreaConstraint(forestID, playerConstraint);  
    rmAddAreaConstraint(forestID, shortAvoidResource);			
    rmAddAreaConstraint(forestID, shortAvoidTradeRoute);
    rmAddAreaConstraint(forestID, avoidTradeRouteSockets);
    rmAddAreaConstraint(forestID, avoidMineSockets);
    rmAddAreaConstraint(forestID, avoidKOTH);
	rmAddAreaConstraint(forestID, avoidGlacier);
    rmAddAreaConstraint(forestID, forestConstraint);
    rmAddAreaConstraint(forestID, shortAvoidImportantItem);
    if(rmBuildArea(forestID)==false)
    {
      // Stop trying once we fail 5 times in a row.  
      failCount++;
      if(failCount==5)
        break;
    }
    else
      failCount=0; 
  } 

	
// *********************** OBJECTS PLACED AFTER FORESTS ********************
	// Resources that can be placed after forests
  
  if(whichVersion == 1) {
	  rmPlaceObjectDefAtLoc(deerID, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
	  rmPlaceObjectDefAtLoc(tapirID, 0, 0.5, 0.5, 3.0*cNumberNonGaiaPlayers);
  }
  
  else if (whichVersion == 2) {
    rmPlaceObjectDefAtLoc(deerID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
	  rmPlaceObjectDefAtLoc(tapirID, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
  }
  
  else {
    rmPlaceObjectDefAtLoc(deerID, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
	  rmPlaceObjectDefAtLoc(tapirID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
  }

	// Text
	rmSetStatusText("",0.90);
	
	// Nuggets
  
  int nugget4= rmCreateObjectDef("nugget nuts"); 
  rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(4, 4);
  rmSetObjectDefMinDistance(nugget4, 0.0);
  rmSetObjectDefMaxDistance(nugget4, 10.0);
  rmAddObjectDefConstraint(nugget4, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget4, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget4, shortAvoidResource);
  rmAddObjectDefConstraint(nugget4, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget4, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget4, avoidTradeRouteSocketsFar);
  rmAddObjectDefConstraint(nugget4, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget4, circleConstraint);
  rmAddObjectDefConstraint(nugget4, avoidGlacier);
  rmPlaceObjectDefAtLoc(nugget4, 0, 0.28*_cos(rmDegreesToRadians(-67  + p))+0.5, 0.28*_sin(rmDegreesToRadians(-67  + p))+0.5, 1);
  rmPlaceObjectDefAtLoc(nugget4, 0, 0.28*_cos(rmDegreesToRadians(-103 + p))+0.5, 0.28*_sin(rmDegreesToRadians(-103 + p))+0.5, 1);
  
  int nugget1= rmCreateObjectDef("nugget easy"); 
  rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(1, 1);
  rmAddObjectDefConstraint(nugget1, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget1, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget1, shortAvoidResource);
  rmAddObjectDefConstraint(nugget1, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget1, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget1, avoidTradeRouteSocketsFar);
  rmAddObjectDefConstraint(nugget1, playerConstraint);
  rmAddObjectDefConstraint(nugget1, circleConstraint);
  rmAddObjectDefConstraint(nugget1, avoidGlacier);
  rmSetObjectDefMinDistance(nugget1, 40.0);
  rmSetObjectDefMaxDistance(nugget1, 60.0);
  rmPlaceObjectDefPerPlayer(nugget1, false, 2);

  int nugget2= rmCreateObjectDef("nugget medium"); 
  rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(2, 2);
  rmSetObjectDefMinDistance(nugget2, 0.0);
  rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(nugget2, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget2, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget2, shortAvoidResource);
  rmAddObjectDefConstraint(nugget2, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget2, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget2, avoidTradeRouteSocketsFar);
  rmAddObjectDefConstraint(nugget2, mediumPlayerConstraint);
  rmAddObjectDefConstraint(nugget2, circleConstraint);
  rmAddObjectDefConstraint(nugget2, avoidGlacier);
  rmSetObjectDefMinDistance(nugget2, 80.0);
  rmSetObjectDefMaxDistance(nugget2, 120.0);
  rmPlaceObjectDefPerPlayer(nugget2, false, 1);

  int nugget3= rmCreateObjectDef("nugget hard"); 
  rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(3, 3);
  rmSetObjectDefMinDistance(nugget3, 0.0);
  rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.35));
  rmAddObjectDefConstraint(nugget3, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget3, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget3, shortAvoidResource);
  rmAddObjectDefConstraint(nugget3, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget3, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget3, avoidTradeRouteSocketsFar);
  rmAddObjectDefConstraint(nugget3, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget3, circleConstraint);
  rmAddObjectDefConstraint(nugget3, avoidGlacier);
  rmPlaceObjectDefAtLoc(nugget3, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	int herdableID=rmCreateObjectDef("herdables");
	rmAddObjectDefItem(herdableID, herdableType, 2, 5.0);
	rmSetObjectDefMinDistance(herdableID, 0.0);
	rmSetObjectDefMaxDistance(herdableID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(herdableID, avoidHerdable);
	rmAddObjectDefConstraint(herdableID, avoidAll);
	rmAddObjectDefConstraint(herdableID, longPlayerConstraint);
	rmAddObjectDefConstraint(herdableID, avoidImpassableLand);
	rmAddObjectDefConstraint(herdableID, avoidGlacier);
  rmAddObjectDefConstraint(herdableID, avoidTradeRoute);
  
  if(whichVersion == 2)
	 rmPlaceObjectDefAtLoc(herdableID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2.5);
	
	//Sea Constraints  
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fishMahi", 25.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 20.0);
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "HumpbackWhale", 30.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 17.0);
	
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.45*_cos(rmDegreesToRadians(90 + p))+0.5, 0.45*_sin(rmDegreesToRadians(90 + p))+0.5, cNumberNonGaiaPlayers*3 + rmRandInt(1,2));

	int fishID=rmCreateObjectDef("fish Mahi");
	rmAddObjectDefItem(fishID, "FishMahi", 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishVsWhaleID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers); 
	// Text
	rmSetStatusText("",0.99);
   

  // King of the Hill (added 2026-11 for WoL): the land between the fjords farthest from every Town Center (the centre is water)
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
