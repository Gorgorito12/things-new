// Baja California TWC
// a random map for AOE3:TWC
// by RF_Gandalf

include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";

void main(void)
{  
   // Text
   rmSetStatusText("",0.01);

// Set up for variables
   string baseType = "";
   string cliffType = "";
   string forestType = "";
   string treeType = "";
   string deerType = "";
   string deer2Type = "";
   string sheepType = "";
   string centerHerdType = "";
   string fishType = "";
   string fish2Type = "";
   string whaleType = "";
   string native1Name = "";
   string native2Name = "";

// Pick pattern for trees, terrain, features, etc.
   int variantChance = rmRandInt(1,2);
   int lightingChance = rmRandInt(1,2);
   int positionChance = rmRandInt(1,2);
   int playerSide = rmRandInt(1,2);
   int playerChance = rmRandInt(1,4);
   int socketPattern = rmRandInt(1,2);   
   int nativeSetup = rmRandInt(0,7);
   int nativePattern = rmRandInt(1,6);
   int nativePosition = rmRandInt(1,2);
   int sheepChance = rmRandInt(1,2);
   int fourChoice = rmRandInt(1,4); 
   int vultures = 0;
   int eagles = 0;
   if (rmRandInt(1,2) == 1)
	eagles = 1;
   else 
	vultures = 1;

   // Size
   int playerTiles = 20000;
   if (cNumberNonGaiaPlayers == 3)
	playerTiles = 18500;
   if (cNumberNonGaiaPlayers >3)
	playerTiles = 17000;
   if (cNumberNonGaiaPlayers >5)
	playerTiles = 15500;
   if (cNumberNonGaiaPlayers >6)
	playerTiles = 14000;		
   int size=2*sqrt(cNumberNonGaiaPlayers*playerTiles);
   int longSide=2.0*size;      
   rmEchoInfo("Map size="+size+"m x "+longSide+"m");
   rmSetMapSize(size, longSide);

// Elevation
   rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.7, 5.0);
   rmSetMapElevationHeightBlend(0.8);
   rmSetSeaLevel(0.0);
	
// Pick terrain patterns and features  
// sonora type terrain 
   rmSetSeaType("hudson bay");
   rmSetMapType("sonora");
   rmSetMapType("grass");
   if (lightingChance == 1)
      rmSetLightingSet("sonora");
   else
      rmSetLightingSet("pampas");

   baseType = "sonora_dirt";
   forestType = "sonora forest";
   cliffType = "Sonora";
   treeType = "TreeSonora";
   if (variantChance == 1)
   {
      deerType = "pronghorn";
      deer2Type = "bison";
      centerHerdType = "bighornsheep";         
   }
   else 
   {     
      deerType = "bison";
      deer2Type = "pronghorn";
      centerHerdType = "bighornsheep";         
   }
   if (sheepChance == 1)
      sheepType = "sheep";
   else
      sheepType = "cow";
   fishType = "FishMahi";
   fish2Type = "FishSardine";
   whaleType = "humpbackWhale";

   rmTerrainInitialize("water");
   rmSetMapType("water");
   rmSetWorldCircleConstraint(true);
   rmSetWindMagnitude(2.0);
   
   chooseMercs();
	wotta_triggers();

// Set up for natives to appear on the map
   if (nativePattern == 1)
   {
      rmSetSubCiv(0, "Apache");
      native1Name = "native apache village ";
      rmSetSubCiv(1, "Navajo");
      native2Name = "native navajo village ";
   }
   else if (nativePattern == 2)
   {
      rmSetSubCiv(0, "Apache");
      native1Name = "native apache village ";
      rmSetSubCiv(1, "Maya");
      native2Name = "native maya village ";
   }
   else if (nativePattern == 3)
   {
      rmSetSubCiv(0, "Apache");
      native1Name = "native apache village ";
      rmSetSubCiv(1, "Zapotec");
      native2Name = "native zapotec village ";
   }
   else if (nativePattern == 4)
   {
      rmSetSubCiv(0, "Maya");
      native1Name = "native maya village ";
      rmSetSubCiv(1, "Zapotec");
      native2Name = "native zapotec village ";
   }
   else if (nativePattern == 5)
   {
      rmSetSubCiv(0, "Maya");
      native1Name = "native maya village ";
      rmSetSubCiv(1, "Navajo");
      native2Name = "native navajo village ";
   }
   else if (nativePattern == 6)
   {
      rmSetSubCiv(0, "Navajo");
      native1Name = "native navajo village ";
      rmSetSubCiv(1, "Zapotec");
      native2Name = "native zapotec village ";
   }

// Define some classes.
   int classPlayer=rmDefineClass("player");
   rmDefineClass("classHill");
   rmDefineClass("classPatch");
   rmDefineClass("classFish");
   rmDefineClass("starting settlement");
   rmDefineClass("startingUnit");
   rmDefineClass("classForest");
   rmDefineClass("importantItem");
   rmDefineClass("natives");
   rmDefineClass("classCliff");
   rmDefineClass("nuggets");
   rmDefineClass("center");
   rmDefineClass("socketClass");
   int classHuntable=rmDefineClass("huntableFood");   
   int classHerdable=rmDefineClass("herdableFood"); 

   // Text
   rmSetStatusText("",0.10);

// -------------Define constraints
   // Map edge constraints
   int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
   int bisonEdgeConstraint=rmCreateBoxConstraint("bison edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
   int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 30.0);
   int centerConstraintShort=rmCreateClassDistanceConstraint("stay away from center short", rmClassID("center"), 12.0);
   int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 70.0);
   int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
   int circleConstraintPond=rmCreatePieConstraint("circle Constraint for pond", 0.5, 0.5, 0, rmZFractionToMeters(0.33), rmDegreesToRadians(0), rmDegreesToRadians(360));

   // Player constraints
   int playerConstraintForest=rmCreateClassDistanceConstraint("forests kinda stay away from players", classPlayer, 15.0);
   int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 45.0);
   int mediumPlayerConstraint=rmCreateClassDistanceConstraint("medium stay away from players", classPlayer, 25.0);
   int nuggetPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 60.0);
   int farPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players more", classPlayer, 85.0);
   int fartherPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players the most", classPlayer, 105.0);
   int enormousPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players for asymmetric starts", classPlayer, 160.0);
   int longPlayerConstraint=rmCreateClassDistanceConstraint("land stays away from players", classPlayer, 70.0); 

   // Nature avoidance
   int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
   int shortForestConstraint=rmCreateClassDistanceConstraint("patch vs. forest", rmClassID("classForest"), 15.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0);
   int longForestConstraint=rmCreateClassDistanceConstraint("long forest vs. forest", rmClassID("classForest"), 25.0);
   int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
   int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "gold", 10.0);
   int shortAvoidSilver=rmCreateTypeDistanceConstraint("short gold avoid gold", "Mine", 20.0);
   int coinAvoidCoin=rmCreateTypeDistanceConstraint("coin avoids coin", "gold", 35.0);
   int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 1.0);
   int avoidSheep=rmCreateClassDistanceConstraint("sheep avoids sheep etc", rmClassID("herdableFood"), 45.0);
   int huntableConstraint=rmCreateClassDistanceConstraint("huntable constraint", rmClassID("huntableFood"), 35.0);
   int forestsAvoidBison=rmCreateClassDistanceConstraint("forest avoids bison", rmClassID("huntableFood"), 15.0);

   // Avoid impassable land, certain features
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
   int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 18.0);
   int hillConstraint=rmCreateClassDistanceConstraint("hill vs. hill", rmClassID("classHill"), 15.0);
   int shortHillConstraint=rmCreateClassDistanceConstraint("patches vs. hill", rmClassID("classHill"), 5.0);
   int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 8.0);
   int avoidCliffs=rmCreateClassDistanceConstraint("stuff vs. cliff", rmClassID("classCliff"), 12.0);
   int cliffsAvoidCliffs=rmCreateClassDistanceConstraint("cliffs vs. cliffs", rmClassID("classCliff"), 30.0);
   int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water mid-long", "Land", false, 10.0);
   int avoidWater15 = rmCreateTerrainDistanceConstraint("avoid water mid-longer", "Land", false, 15.0);
   int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water a little more", "Land", false, 20.0);
   int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 30.0);

   // Unit avoidance
   int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 30.0);
   int avoidStartingUnitsSmall=rmCreateClassDistanceConstraint("objects avoid starting units small", rmClassID("startingUnit"), 10.0);
   int avoidStartingUnitsLarge=rmCreateClassDistanceConstraint("objects avoid starting units large", rmClassID("startingUnit"), 50.0);
   int avoidImportantItem=rmCreateClassDistanceConstraint("things avoid each other", rmClassID("importantItem"), 10.0);
   int avoidImportantItemSmall=rmCreateClassDistanceConstraint("important item small avoidance", rmClassID("importantItem"), 7.0);
   int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 60.0);
   int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives shorter", rmClassID("natives"), 35.0);
   int avoidNugget=rmCreateClassDistanceConstraint("stuff avoids nuggets", rmClassID("nuggets"), 40.0);
   int avoidNuggetSmall=rmCreateTypeDistanceConstraint("avoid nuggets by a little", "AbstractNugget", 10.0);
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

   // Trade route avoidance.
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 8.0);
   int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 20.0);
   int avoidSocket=rmCreateClassDistanceConstraint("avoid sockets", rmClassID("socketClass"), 13.0);

   // New extra stuff for water spawn point avoidance.
   int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 35.0);
   int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 70);
   int flagEdgeConstraint = rmCreateBoxConstraint("flag edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);

// End of constraints -----------------------------------

// Build up big continent 
   int bigContinentID=rmCreateArea("big continent");
   rmSetAreaSize(bigContinentID, 0.41, 0.41);		
   rmSetAreaMix(bigContinentID, baseType);
   rmSetAreaElevationType(bigContinentID, cElevTurbulence);
   rmSetAreaElevationVariation(bigContinentID, 2.0);
   rmSetAreaBaseHeight(bigContinentID, 2);
   rmSetAreaElevationMinFrequency(bigContinentID, 0.09);
   rmSetAreaElevationPersistence(bigContinentID, 0.5);
   rmSetAreaSmoothDistance(bigContinentID, 20); 
   rmSetAreaCoherence(bigContinentID, 0.7);
   rmSetAreaLocation(bigContinentID, 0.5, 0.55);
   rmAddAreaInfluenceSegment(bigContinentID, 0.5, 0.3, 0.5, 0.75); 
   rmBuildArea(bigContinentID);

   int smallContinent1ID=rmCreateArea("small continent spur 1"); // northern extension
   rmSetAreaSize(smallContinent1ID, 0.22, 0.22);
   rmSetAreaWarnFailure(smallContinent1ID, false);
   rmSetAreaSmoothDistance(smallContinent1ID, 25);
   rmSetAreaMix(smallContinent1ID, baseType);
   rmSetAreaElevationType(smallContinent1ID, cElevTurbulence);
   rmSetAreaElevationVariation(smallContinent1ID, 2.0);
   rmSetAreaBaseHeight(smallContinent1ID, 4.0);
   rmSetAreaElevationMinFrequency(smallContinent1ID, 0.09);
   rmSetAreaElevationPersistence(smallContinent1ID, 0.8);      
   rmSetAreaCoherence(smallContinent1ID, 0.6);
   rmSetAreaLocation(smallContinent1ID, 0.5, 0.9);
   rmAddAreaInfluenceSegment(smallContinent1ID, 0.3, 1.0, 0.7, 1.0);
   rmSetAreaEdgeFilling(smallContinent1ID, 2);
   rmSetAreaObeyWorldCircleConstraint(smallContinent1ID, false);
   rmBuildArea(smallContinent1ID);

   int smallContinent2ID=rmCreateArea("small continent spur 2"); // southern tip
   rmSetAreaSize(smallContinent2ID, 0.09, 0.10);
   rmSetAreaWarnFailure(smallContinent2ID, false);
   rmSetAreaSmoothDistance(smallContinent2ID, 25);
   rmSetAreaMix(smallContinent2ID, baseType);
   rmSetAreaElevationType(smallContinent2ID, cElevTurbulence);
   rmSetAreaElevationVariation(smallContinent2ID, 2.0);
   rmSetAreaBaseHeight(smallContinent2ID, 2.0);
   rmSetAreaElevationMinFrequency(smallContinent2ID, 0.09);
   rmSetAreaElevationPersistence(smallContinent2ID, 0.2);      
   rmSetAreaCoherence(smallContinent2ID, 0.5);
   rmSetAreaLocation(smallContinent2ID, 0.5, 0.35);
   rmAddAreaInfluenceSegment(smallContinent2ID, 0.5, 0.12, 0.5, 0.6);
   rmBuildArea(smallContinent2ID);

   // Text
   rmSetStatusText("",0.20);
 
// Set up player starting locations

   if (cNumberNonGaiaPlayers == 2) 
   {
	if (playerChance == 1)
	{
	   if (playerSide == 1)
	   {
            rmPlacePlayer(1, 0.31, 0.6);
            rmPlacePlayer(2, 0.69, 0.35);
	   }
	   else if (playerSide == 2)
 	   {
            rmPlacePlayer(2, 0.31, 0.6);
            rmPlacePlayer(1, 0.69, 0.35);
	   }
	}
	else if (playerChance == 2)
	{
	   if (playerSide == 1)
	   {
            rmPlacePlayer(1, 0.31, 0.65);
            rmPlacePlayer(2, 0.69, 0.4);
	   }
	   else if (playerSide == 2)
 	   {
            rmPlacePlayer(2, 0.31, 0.65);
            rmPlacePlayer(1, 0.69, 0.4);
	   }
	}
	else if (playerChance == 3)
	{
	   if (playerSide == 1)
	   {
            rmPlacePlayer(1, 0.31, 0.7);
            rmPlacePlayer(2, 0.69, 0.45);
	   }
	   else if (playerSide == 2)
 	   {
            rmPlacePlayer(2, 0.31, 0.7);
            rmPlacePlayer(1, 0.69, 0.45);
	   }
	}
	else if (playerChance == 4)
	{
	   if (playerSide == 1)
	   {
            rmPlacePlayer(1, 0.31, 0.75);
            rmPlacePlayer(2, 0.69, 0.5);
	   }
	   else if (playerSide == 2)
 	   {
            rmPlacePlayer(2, 0.31, 0.75);
            rmPlacePlayer(1, 0.69, 0.5);
	   }
	}
   }
   else if (cNumberTeams == 2)
   {
 	if (playerSide == 1)
	   rmSetPlacementTeam(0);
	else
	   rmSetPlacementTeam(1);
	if (cNumberNonGaiaPlayers <5)
	{
		if (positionChance == 1)    
               rmPlacePlayersLine(0.32, 0.38, 0.33, 0.60, 0.0, 0.2);
		else
               rmPlacePlayersLine(0.32, 0.46, 0.33, 0.68, 0.0, 0.2);
	}
	else if (cNumberNonGaiaPlayers <7)
	{
		if (positionChance == 1)    
               rmPlacePlayersLine(0.32, 0.32, 0.33, 0.62, 0.0, 0.2);
		else
               rmPlacePlayersLine(0.32, 0.39, 0.33, 0.69, 0.0, 0.2);
	}
	else 
	{
		if (positionChance == 1)    
               rmPlacePlayersLine(0.32, 0.32, 0.33, 0.66, 0.0, 0.2);
		else
               rmPlacePlayersLine(0.32, 0.37, 0.33, 0.71, 0.0, 0.2);
	}

	if (playerSide == 1)
	   rmSetPlacementTeam(1);
	else
	   rmSetPlacementTeam(0);
      if (cNumberNonGaiaPlayers < 5)
	{
		if (positionChance == 1)    
               rmPlacePlayersLine(0.67, 0.46, 0.68, 0.68, 0.0, 0.2);
		else
               rmPlacePlayersLine(0.67, 0.38, 0.68, 0.60, 0.0, 0.2);
	}
      else if (cNumberNonGaiaPlayers < 7)
	{
		if (positionChance == 1)  
               rmPlacePlayersLine(0.67, 0.39, 0.68, 0.69, 0.0, 0.2);  
		else
               rmPlacePlayersLine(0.67, 0.32, 0.68, 0.62, 0.0, 0.2);
	}
	else 
	{
		if (positionChance == 1)  
               rmPlacePlayersLine(0.67, 0.37, 0.68, 0.71, 0.0, 0.2);  
		else
               rmPlacePlayersLine(0.67, 0.32, 0.68, 0.66, 0.0, 0.2);
	}
   }
   else if (cNumberTeams > 2) // free for all
   {
	if (cNumberNonGaiaPlayers == 3)
	{
	   if (playerSide == 1)
	   {
            rmPlacePlayer(1, 0.31, 0.5);
            rmPlacePlayer(2, 0.69, 0.35);
            rmPlacePlayer(3, 0.69, 0.65);
	   }
	   else if (playerSide == 2)
 	   {
            rmPlacePlayer(2, 0.69, 0.55);
            rmPlacePlayer(1, 0.31, 0.75);
            rmPlacePlayer(3, 0.31, 0.35);
	   }
	}
	else if (cNumberNonGaiaPlayers == 4)
	{
	   if (playerSide == 2)
	   {
            rmPlacePlayer(1, 0.31, 0.45);
            rmPlacePlayer(2, 0.69, 0.35);
            rmPlacePlayer(3, 0.69, 0.65);
            rmPlacePlayer(4, 0.31, 0.75);
	   }
	   else if (playerSide == 1)
 	   {
            rmPlacePlayer(3, 0.69, 0.45);
            rmPlacePlayer(4, 0.31, 0.65);
            rmPlacePlayer(2, 0.31, 0.35);
            rmPlacePlayer(1, 0.69, 0.75);
	   }
	}
	else if (cNumberNonGaiaPlayers == 5)
	{
	   if (playerSide == 2)
	   {
            rmPlacePlayer(1, 0.31, 0.35);
            rmPlacePlayer(2, 0.69, 0.45);
            rmPlacePlayer(3, 0.69, 0.65);
            rmPlacePlayer(4, 0.31, 0.55);
            rmPlacePlayer(5, 0.31, 0.75);
	   }
	   else if (playerSide == 1)
 	   {
            rmPlacePlayer(3, 0.69, 0.35);
            rmPlacePlayer(4, 0.31, 0.65);
            rmPlacePlayer(5, 0.69, 0.55);
            rmPlacePlayer(1, 0.69, 0.75);
            rmPlacePlayer(2, 0.31, 0.45);
	   }
	}
	else if (cNumberNonGaiaPlayers == 6)
	{
	   if (playerSide == 1)
	   {
            rmPlacePlayer(1, 0.31, 0.3);
            rmPlacePlayer(2, 0.69, 0.4);
            rmPlacePlayer(3, 0.31, 0.5);
            rmPlacePlayer(4, 0.69, 0.6);
            rmPlacePlayer(5, 0.69, 0.8);
            rmPlacePlayer(6, 0.31, 0.7);

	   }
	   else if (playerSide == 2)
 	   {
            rmPlacePlayer(3, 0.69, 0.3);
            rmPlacePlayer(6, 0.69, 0.5);
            rmPlacePlayer(1, 0.69, 0.7);
            rmPlacePlayer(4, 0.31, 0.4);
            rmPlacePlayer(2, 0.31, 0.8);
            rmPlacePlayer(5, 0.31, 0.6);
	   }
	}
	else if (cNumberNonGaiaPlayers == 7)
	{
	   if (playerSide == 1)
	   {
            rmPlacePlayer(1, 0.31, 0.3);
            rmPlacePlayer(2, 0.69, 0.37);
            rmPlacePlayer(3, 0.31, 0.47);
            rmPlacePlayer(4, 0.69, 0.55);
            rmPlacePlayer(5, 0.69, 0.73);
            rmPlacePlayer(6, 0.31, 0.81);
            rmPlacePlayer(7, 0.31, 0.64);
	   }
	   else if (playerSide == 2)
 	   {
            rmPlacePlayer(3, 0.69, 0.30);
            rmPlacePlayer(6, 0.69, 0.47);
            rmPlacePlayer(2, 0.69, 0.64);
            rmPlacePlayer(7, 0.69, 0.81);
            rmPlacePlayer(4, 0.31, 0.37);
            rmPlacePlayer(5, 0.31, 0.55);
            rmPlacePlayer(1, 0.31, 0.73);
	   }
	}
	else if (cNumberNonGaiaPlayers == 8)
	{
	   if (playerSide == 1)
	   {
            rmPlacePlayer(1, 0.31, 0.3);
            rmPlacePlayer(2, 0.69, 0.47);
            rmPlacePlayer(3, 0.31, 0.47);
            rmPlacePlayer(4, 0.69, 0.64);
            rmPlacePlayer(5, 0.69, 0.81);
            rmPlacePlayer(6, 0.31, 0.81);
            rmPlacePlayer(7, 0.31, 0.64);
            rmPlacePlayer(8, 0.69, 0.30);
	   }
	   else if (playerSide == 2)
 	   {
            rmPlacePlayer(3, 0.69, 0.30);
            rmPlacePlayer(6, 0.69, 0.47);
            rmPlacePlayer(1, 0.69, 0.64);
            rmPlacePlayer(7, 0.69, 0.81);
            rmPlacePlayer(2, 0.31, 0.30);
            rmPlacePlayer(4, 0.31, 0.47);
            rmPlacePlayer(8, 0.31, 0.64);
            rmPlacePlayer(5, 0.31, 0.81);
	   }
	}
   }

   // Text
   rmSetStatusText("",0.25);
	
// Set up player areas.
   float playerFraction=rmAreaTilesToFraction(120);
   for(i=1; <cNumberPlayers)
   {
      int id=rmCreateArea("Player"+i);
      rmSetPlayerArea(i, id);
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 1);
      rmAddAreaConstraint(id, playerConstraint); 
      rmAddAreaConstraint(id, longAvoidImpassableLand);
      rmAddAreaConstraint(id, playerEdgeConstraint); 
      rmSetAreaLocPlayer(id, i);
      rmSetAreaMix(id, baseType);
      rmSetAreaWarnFailure(id, false);
   }
   rmBuildAllAreas();

// Central Mountain Range
   int barrierCID=rmCreateArea("barrier center single"); 
   rmSetAreaWarnFailure(barrierCID, false);
   rmSetAreaCliffType(barrierCID, cliffType);
   rmAddAreaToClass(barrierCID, rmClassID("classCliff"));
   rmAddAreaConstraint(barrierCID, playerEdgeConstraint); 
   rmAddAreaConstraint(barrierCID, mediumPlayerConstraint); 
   if (cNumberNonGaiaPlayers > 6) 
      rmSetAreaSize(barrierCID, 0.078, 0.08);
   else if (cNumberNonGaiaPlayers > 3) 
      rmSetAreaSize(barrierCID, 0.09, 0.095);
   else if (cNumberNonGaiaPlayers == 3) 
      rmSetAreaSize(barrierCID, 0.11, 0.115);
   else
      rmSetAreaSize(barrierCID, 0.115, 0.12);
   rmSetAreaLocation(barrierCID, 0.5, 0.6);
   rmAddAreaInfluenceSegment(barrierCID, 0.5, 0.3, 0.5, 0.9); 
   if (cNumberNonGaiaPlayers > 6)
      rmSetAreaCliffEdge(barrierCID, 12, 0.08, 0.05, 0.6, 0);
   else if (cNumberNonGaiaPlayers > 5)
      rmSetAreaCliffEdge(barrierCID, 11, 0.086, 0.05, 0.6, 0);
   else if (cNumberNonGaiaPlayers > 3)
      rmSetAreaCliffEdge(barrierCID, 10, 0.095, 0.05, 0.6, 0);
   else
   {
      if (fourChoice == 1)  
         rmSetAreaCliffEdge(barrierCID, 8, 0.12, 0.05, 0.6, 0);
      else if (fourChoice == 2)
         rmSetAreaCliffEdge(barrierCID, 10, 0.095, 0.05, 0.6, 0);
      else 
         rmSetAreaCliffEdge(barrierCID, 9, 0.105, 0.05, 0.6, 0);
   }
   rmSetAreaCliffPainting(barrierCID, false, true, true, 1.5, true);
   rmSetAreaCliffHeight(barrierCID, rmRandInt(8,9), 1.0, 1.0);
   rmSetAreaCoherence(barrierCID, 0.8);
   rmSetAreaSmoothDistance(barrierCID, 5);
   rmSetAreaHeightBlend(barrierCID, 2);
   rmBuildArea(barrierCID);

   // Text
   rmSetStatusText("",0.30);

// Trade Routes
   int tradeRouteID6 = rmCreateTradeRoute();
   if (cNumberNonGaiaPlayers > 3)
   {
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.5, 0.14);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.5, 0.3);      
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.515, 0.35);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.485, 0.45);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.5, 0.5);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.5, 0.65);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.515, 0.7);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.485, 0.8);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.5, 0.85);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.5, 1.0);
   }
   else
   {
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.5, 0.14);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.5, 0.35);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.5, 0.5);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.5, 0.55);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.5, 0.8);
      rmAddTradeRouteWaypoint(tradeRouteID6, 0.5, 1.0);
   }
   rmBuildTradeRoute(tradeRouteID6, "carolinas\trade_route");	

// Trade sockets
   int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
   rmSetObjectDefAllowOverlap(socketID, true);
   rmAddObjectDefToClass(socketID, rmClassID("importantItem"));
   rmSetObjectDefMinDistance(socketID, 0.0);
   rmSetObjectDefMaxDistance(socketID, 6.0);
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID6);

   if (socketPattern == 1)
   {
      if (cNumberNonGaiaPlayers < 4)
      {
         vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.02);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.32);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.65);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.96);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
	else
	{
         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.02);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.3);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.49);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.67);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.96);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
   }
   else if (socketPattern == 2)
   {
      if (cNumberNonGaiaPlayers > 3)
      {
         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.02);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.32);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.65);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.96);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
	else
	{
         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.02);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.49);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc = rmGetTradeRouteWayPoint(tradeRouteID6, 0.96);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
   }

   //Text
   rmSetStatusText("",0.35);

// Starting TCs and units 		
   int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
   rmSetObjectDefMinDistance(startingUnits, 5.0);
   rmSetObjectDefMaxDistance(startingUnits, 10.0);
   rmAddObjectDefConstraint(startingUnits, avoidAll);

   int startingTCID= rmCreateObjectDef("startingTC");
   rmSetObjectDefMaxDistance(startingTCID, 8.0);
   rmAddObjectDefConstraint(startingTCID, avoidAll);
   rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);
   rmAddObjectDefConstraint(startingTCID, longAvoidImpassableLand );                
   if ( rmGetNomadStart())
   {
	rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 0.0);
   }
   else
   {
      rmAddObjectDefItem(startingTCID, "TownCenter", 1, 0.0);
   }

   for(i=1; <cNumberPlayers)
   {	
      rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
      rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }

   // Center area
   int centerArea=rmCreateArea("TheCenter");
   rmSetAreaSize(centerArea, 0.05, 0.05);
   rmSetAreaLocation(centerArea, 0.5, 0.55);
   rmAddAreaToClass(centerArea, rmClassID("center")); 

   // Dirt patches
   for (i=0; <cNumberNonGaiaPlayers*6)   
   {
	int dirtPatch=rmCreateArea("open dirt patch "+i);
	rmSetAreaWarnFailure(dirtPatch, false);
	rmSetAreaSize(dirtPatch, rmAreaTilesToFraction(150), rmAreaTilesToFraction(230));
	rmSetAreaTerrainType(dirtPatch, "sonora\ground7_son");
	rmAddAreaToClass(dirtPatch, rmClassID("classPatch"));
	rmSetAreaMinBlobs(dirtPatch, 1);
	rmSetAreaMaxBlobs(dirtPatch, 5);
	rmSetAreaMinBlobDistance(dirtPatch, 16.0);
	rmSetAreaMaxBlobDistance(dirtPatch, 40.0);
	rmSetAreaCoherence(dirtPatch, 0.0);
	rmSetAreaSmoothDistance(dirtPatch, 10);
	rmAddAreaConstraint(dirtPatch, shortAvoidImpassableLand);
	rmAddAreaConstraint(dirtPatch, patchConstraint);
	rmBuildArea(dirtPatch); 
   }
 
   // Text
   rmSetStatusText("",0.40);

// Water Flag
   int waterFlagID=-1;
   for(i=1; <cNumberPlayers)
   {
      rmClearClosestPointConstraints();
      waterFlagID=rmCreateObjectDef("HC water flag "+i);
      rmAddObjectDefItem(waterFlagID, "HomeCityWaterSpawnFlag", 1, 5.0);
      rmAddClosestPointConstraint(flagEdgeConstraint);
      rmAddClosestPointConstraint(flagVsFlag);
      rmAddClosestPointConstraint(flagLand);
      vector TCLocation = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
      vector closestPoint = rmFindClosestPointVector(TCLocation, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(waterFlagID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
      rmClearClosestPointConstraints();
   }

   // Text
   rmSetStatusText("",0.50);

// NATIVE AMERICANS
   // Village A 
   int villageAID = -1;
   int whichNative = rmRandInt(1,2);
   int villageType = rmRandInt(1,5);

   if (whichNative == 1)
	villageAID = rmCreateGrouping("village A", native1Name+villageType);
   else if (whichNative == 2)
	villageAID = rmCreateGrouping("village A", native2Name+villageType);
   rmAddGroupingToClass(villageAID, rmClassID("natives"));
   rmAddGroupingToClass(villageAID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageAID, 0.0);
   rmSetGroupingMaxDistance(villageAID, rmXFractionToMeters(0.07));
   rmAddGroupingConstraint(villageAID, avoidImpassableLand);
   rmAddGroupingConstraint(villageAID, avoidTradeRoute);
   rmAddGroupingConstraint(villageAID, avoidSocket);
   rmAddGroupingConstraint(villageAID, avoidWater15);
   rmAddGroupingConstraint(villageAID, avoidNatives);
   rmAddGroupingConstraint(villageAID, playerConstraint);

   // Village D - opposite type from A 
   int villageDID = -1;
   villageType = rmRandInt(1,5);

   if (whichNative == 2)
	   villageDID = rmCreateGrouping("village D", native1Name+villageType);
   else if (whichNative == 1)
	   villageDID = rmCreateGrouping("village D", native2Name+villageType);
   rmAddGroupingToClass(villageDID, rmClassID("natives"));
   rmAddGroupingToClass(villageDID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageDID, 0.0);
   rmSetGroupingMaxDistance(villageDID, rmXFractionToMeters(0.07));
   rmAddGroupingConstraint(villageDID, avoidImpassableLand);
   rmAddGroupingConstraint(villageDID, avoidTradeRoute);
   rmAddGroupingConstraint(villageDID, avoidSocket);
   rmAddGroupingConstraint(villageDID, avoidWater15);
   rmAddGroupingConstraint(villageDID, avoidNatives);
   rmAddGroupingConstraint(villageDID, playerConstraint);

   // Village B - randomly same or opposite village A
   int villageBID = -1;	
   villageType = rmRandInt(1,5);
   whichNative = rmRandInt(1,2);

   if (whichNative == 1)
	villageBID = rmCreateGrouping("village B", native1Name+villageType);
   else if (whichNative == 2)
	villageBID = rmCreateGrouping("village B", native2Name+villageType);
   rmAddGroupingToClass(villageBID, rmClassID("importantItem"));
   rmAddGroupingToClass(villageBID, rmClassID("natives"));
   rmSetGroupingMinDistance(villageBID, 0.0);
   rmSetGroupingMaxDistance(villageBID, rmXFractionToMeters(0.07));
   rmAddGroupingConstraint(villageBID, avoidImpassableLand);
   rmAddGroupingConstraint(villageBID, avoidTradeRoute);
   rmAddGroupingConstraint(villageBID, avoidSocket);
   rmAddGroupingConstraint(villageBID, avoidWater15);
   rmAddGroupingConstraint(villageBID, avoidNatives);
   rmAddGroupingConstraint(villageBID, playerConstraint);

   // Village C // appears in center, variable, randomly same or opposite A and B
   int villageCID = -1;	
   villageType = rmRandInt(1,5);
   whichNative = rmRandInt(1,2);

   if (whichNative == 1)
	   villageCID = rmCreateGrouping("village C", native1Name+villageType);
   else if (whichNative == 2)
	   villageCID = rmCreateGrouping("village C", native2Name+villageType);
   rmAddGroupingToClass(villageCID, rmClassID("importantItem"));
   rmAddGroupingToClass(villageCID, rmClassID("natives"));
   rmSetGroupingMinDistance(villageCID, 0.0);
   rmSetGroupingMaxDistance(villageCID, rmXFractionToMeters(0.1));
   rmAddGroupingConstraint(villageCID, avoidImpassableLand);
   rmAddGroupingConstraint(villageCID, avoidWater10);
   rmAddGroupingConstraint(villageCID, avoidTradeRoute);
   rmAddGroupingConstraint(villageCID, avoidSocket);
   rmAddGroupingConstraint(villageCID, avoidNatives);
   rmAddGroupingConstraint(villageCID, playerConstraint);

   // Placement of Native Americans
   if (nativeSetup < 2) // setup 0,1
   {
      if (cNumberNonGaiaPlayers < 4)
      {
         rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.97); 
         rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.15);
      }
	else
      {
         rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.96); 
         rmPlaceGroupingAtLoc(villageBID, 0, 0.5, 0.56);
         rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.16);
      }
   }
   else if (nativeSetup < 4) // setup 2,3
   {
      rmPlaceGroupingAtLoc(villageDID, 0, 0.4, 0.23);
      rmPlaceGroupingAtLoc(villageAID, 0, 0.6, 0.23);
	if (nativePosition == 1)
      {
         rmPlaceGroupingAtLoc(villageAID, 0, 0.15, 0.93);
         rmPlaceGroupingAtLoc(villageDID, 0, 0.85, 0.93);
      }
	else
      {
         rmPlaceGroupingAtLoc(villageAID, 0, 0.25, 0.86);
         rmPlaceGroupingAtLoc(villageDID, 0, 0.75, 0.86);
	}
      if (nativeSetup == 3)
         rmPlaceGroupingAtLoc(villageBID, 0, 0.5, 0.55);
   }
   else if (nativeSetup < 6) // setup 4,5
   {
	if (nativePosition == 1)
      {
         rmPlaceGroupingAtLoc(villageCID, 0, 0.15, 0.93);
         rmPlaceGroupingAtLoc(villageCID, 0, 0.85, 0.93);
      }
	else
      {
         rmPlaceGroupingAtLoc(villageCID, 0, 0.25, 0.87);
         rmPlaceGroupingAtLoc(villageCID, 0, 0.75, 0.87);
	}
      rmPlaceGroupingAtLoc(villageAID, 0, 0.4, 0.23);
      rmPlaceGroupingAtLoc(villageAID, 0, 0.6, 0.23);
      if (nativeSetup == 5)
         rmPlaceGroupingAtLoc(villageBID, 0, 0.5, 0.55);
   }
   else if (nativeSetup == 6) 
   {
      rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.19);
	if (nativePosition == 1)
      {
         rmPlaceGroupingAtLoc(villageAID, 0, 0.15, 0.93);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.85, 0.93);
      }
	else
      {
         rmPlaceGroupingAtLoc(villageAID, 0, 0.25, 0.88);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.75, 0.88);
	}
   }
   else if (nativeSetup == 7) 
   {
      if (cNumberNonGaiaPlayers == 2)
      {
         rmPlaceGroupingAtLoc(villageCID, 0, 0.37, 0.95); 
         rmPlaceGroupingAtLoc(villageCID, 0, 0.63, 0.95); 
         rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.15);
      }
	else
      {
         rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.96); 
         rmPlaceGroupingAtLoc(villageBID, 0, 0.5, 0.69);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.5, 0.45);
         rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.16);
      }
   }

   // Text
   rmSetStatusText("",0.60);

// Cliffs
   int cliffHt = -1;
   int numCliffs=(cNumberNonGaiaPlayers*2 + 3);
   int cliffVariety = rmRandInt(1,3);

   for (i=0; <numCliffs)
   {
      cliffVariety = rmRandInt(1,3);
	cliffHt = rmRandInt(5,7);    
	int bigCliffID=rmCreateArea("big cliff" +i);
	rmSetAreaWarnFailure(bigCliffID, false);
	rmSetAreaCliffType(bigCliffID, cliffType);
	rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
	if (cliffVariety == 1) // like Patagonia
	{
         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(600), rmAreaTilesToFraction(800));
     	   rmSetAreaCliffEdge(bigCliffID, 2, 0.38, 0.1, 1.0, 0);
     	   rmSetAreaCliffPainting(bigCliffID, false, true, true, 1.5, true);  
	   rmSetAreaCliffHeight(bigCliffID, 7, 2.0, 0.5);
	   rmSetAreaCoherence(bigCliffID, 0.5);
	   rmSetAreaSmoothDistance(bigCliffID, 5);
	   rmSetAreaHeightBlend(bigCliffID, 1.0);
	   rmSetAreaMinBlobs(bigCliffID, 5);
	   rmSetAreaMaxBlobs(bigCliffID, 7);
	   rmSetAreaMinBlobDistance(bigCliffID, 5.0);
	   rmSetAreaMaxBlobDistance(bigCliffID, 20.0);
	}
	else if (cliffVariety == 2) // smaller, kinda like in Sudden Death from AOM
	{
         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(280), rmAreaTilesToFraction(400));
	   rmSetAreaCliffEdge(bigCliffID, 1, 0.6, 0.1, 1.0, 0);
	   rmSetAreaCliffPainting(bigCliffID, false, true, true, 1.5, true);
	   rmSetAreaCliffHeight(bigCliffID, cliffHt, 1.0, 1.0);
	   rmSetAreaCoherence(bigCliffID, rmRandFloat(0.4, 0.9));
	   rmSetAreaSmoothDistance(bigCliffID, 10);
	   rmSetAreaHeightBlend(bigCliffID, 2.0);
	   rmSetAreaMinBlobs(bigCliffID, 1);
	   rmSetAreaMaxBlobs(bigCliffID, 3);
	   rmSetAreaMinBlobDistance(bigCliffID, 5.0);
	   rmSetAreaMaxBlobDistance(bigCliffID, 12.0);
	}
	else  // kinda random, kinda like Texas or NE
	{
         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(800));
	   rmSetAreaCliffEdge(bigCliffID, 1, 0.65, 0.1, 1.0, 0);
	   rmSetAreaCliffPainting(bigCliffID, false, true, true, 1.5, true);
	   rmSetAreaCliffHeight(bigCliffID, cliffHt, 2.0, 1.0);
	   rmSetAreaCoherence(bigCliffID, rmRandFloat(0.4, 0.9));
	   rmSetAreaSmoothDistance(bigCliffID, 15);
	   rmSetAreaHeightBlend(bigCliffID, 1.0);
	   rmSetAreaMinBlobs(bigCliffID, 3);
	   rmSetAreaMaxBlobs(bigCliffID, 7);
	   rmSetAreaMinBlobDistance(bigCliffID, 5.0);
	   rmSetAreaMaxBlobDistance(bigCliffID, 20.0);
	}
	rmAddAreaConstraint(bigCliffID, avoidImportantItem);
	rmAddAreaConstraint(bigCliffID, avoidTradeRoute);
      rmAddAreaConstraint(bigCliffID, avoidNatives);
      rmAddAreaConstraint(bigCliffID, avoidWater20);
      rmAddAreaConstraint(bigCliffID, cliffsAvoidCliffs);
      rmAddAreaConstraint(bigCliffID, avoidSocket);
      rmAddAreaConstraint(bigCliffID, avoidStartingUnits);
      rmAddAreaConstraint(bigCliffID, farPlayerConstraint);
	rmBuildArea(bigCliffID);
   }
      
// Player Nuggets
   int playerNuggetID=rmCreateObjectDef("player nugget");
   rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
   rmAddObjectDefToClass(playerNuggetID, rmClassID("nuggets"));
   rmSetObjectDefMinDistance(playerNuggetID, 35.0);
   rmSetObjectDefMaxDistance(playerNuggetID, 45.0);
   rmAddObjectDefConstraint(playerNuggetID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(playerNuggetID, avoidTradeRoute);
   rmAddObjectDefConstraint(playerNuggetID, avoidSocket);
   rmAddObjectDefConstraint(playerNuggetID, avoidNugget);
   rmAddObjectDefConstraint(playerNuggetID, avoidNatives);
   rmAddObjectDefConstraint(playerNuggetID, circleConstraint);
   rmAddObjectDefConstraint(playerNuggetID, avoidWater10);

   for(i=1; <cNumberPlayers)
   {
 	rmSetNuggetDifficulty(1, 1);
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }

// Random Nuggets
   int nuggetID= rmCreateObjectDef("nugget"); 
   rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0);
   rmAddObjectDefToClass(nuggetID, rmClassID("nuggets"));
   rmSetObjectDefMinDistance(nuggetID, 45.0);
   rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.3));
   rmAddObjectDefConstraint(nuggetID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nuggetID, avoidNugget);
   rmAddObjectDefConstraint(nuggetID, avoidStartingUnits);
   rmAddObjectDefConstraint(nuggetID, avoidTradeRoute);
   rmAddObjectDefConstraint(nuggetID, avoidSocket);
   rmAddObjectDefConstraint(nuggetID, avoidAll);
   rmAddObjectDefConstraint(nuggetID, nuggetPlayerConstraint);
   rmAddObjectDefConstraint(nuggetID, circleConstraint);
   rmAddObjectDefConstraint(nuggetID, avoidWater20);

   for(i=1; <cNumberPlayers)
   {
      rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.5));
      rmSetNuggetDifficulty(2, 2);
	rmPlaceObjectDefAtLoc(nuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
      rmSetNuggetDifficulty(3, 3);
	rmPlaceObjectDefAtLoc(nuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }
   
   rmAddObjectDefConstraint(nuggetID, farPlayerConstraint);
   rmSetObjectDefMinDistance(nuggetID, 100.0);
   rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(1.5));
   for(i=1; <cNumberPlayers)
   {
      rmSetNuggetDifficulty(2, 2);
	rmPlaceObjectDefAtLoc(nuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
      rmSetNuggetDifficulty(4, 4);
	rmPlaceObjectDefAtLoc(nuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }

   // Text
   rmSetStatusText("",0.65);

// more resources
   // start area trees 
   int StartAreaTreeID=rmCreateObjectDef("starting trees");
   rmAddObjectDefItem(StartAreaTreeID, treeType, 1, 0.0);
   rmSetObjectDefMinDistance(StartAreaTreeID, 8);
   rmSetObjectDefMaxDistance(StartAreaTreeID, 12);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRoute);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
   rmPlaceObjectDefPerPlayer(StartAreaTreeID, false, 3);

   // start area huntable
   int deerNum = rmRandInt(4, 6);
   int startPronghornID=rmCreateObjectDef("starting pronghorn");
   rmAddObjectDefItem(startPronghornID, deerType, deerNum, 4.0);
   rmAddObjectDefToClass(startPronghornID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(startPronghornID, 16);
   rmSetObjectDefMaxDistance(startPronghornID, 22);
   rmAddObjectDefConstraint(startPronghornID, avoidStartResource);
   rmAddObjectDefConstraint(startPronghornID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(startPronghornID, avoidAll);
   rmSetObjectDefCreateHerd(startPronghornID, true);
   rmPlaceObjectDefPerPlayer(startPronghornID, false, 1);

   // second huntable
   int deer2Num = rmRandInt(4, 6);
   int farPronghornID=rmCreateObjectDef("far pronghorn");
   rmAddObjectDefItem(farPronghornID, deer2Type, deer2Num, 4.0);
   rmAddObjectDefToClass(farPronghornID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(farPronghornID, 42.0);
   rmSetObjectDefMaxDistance(farPronghornID, 65.0);
   rmAddObjectDefConstraint(farPronghornID, avoidStartResource);
   rmAddObjectDefConstraint(farPronghornID, mediumPlayerConstraint);
   rmAddObjectDefConstraint(farPronghornID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(farPronghornID, avoidNatives);
   rmAddObjectDefConstraint(farPronghornID, huntableConstraint);
   rmAddObjectDefConstraint(farPronghornID, avoidAll);
   rmSetObjectDefCreateHerd(farPronghornID, true);
   rmPlaceObjectDefPerPlayer(farPronghornID, false, 1);

// Mines - players
   int silverType = -1;
   silverType = rmRandInt(1,10);
   int playerGoldID=rmCreateObjectDef("player mine");
   rmAddObjectDefItem(playerGoldID, "mine", 1, 0);
   rmAddObjectDefConstraint(playerGoldID, avoidTradeRoute);
   rmAddObjectDefConstraint(playerGoldID, avoidSocket);
   rmAddObjectDefConstraint(playerGoldID, coinAvoidCoin);
   rmAddObjectDefConstraint(playerGoldID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(playerGoldID, avoidCliffs);
   rmAddObjectDefConstraint(playerGoldID, avoidAll);
   rmAddObjectDefConstraint(playerGoldID, avoidWater20);
   rmSetObjectDefMinDistance(playerGoldID, 18.0);
   rmSetObjectDefMaxDistance(playerGoldID, 22.0);
   rmPlaceObjectDefPerPlayer(playerGoldID, false, 1);

   silverType = rmRandInt(1,10);
   int GoldMediumID=rmCreateObjectDef("player silver med");
   rmAddObjectDefItem(GoldMediumID, "mine", 1, 0);
   rmAddObjectDefConstraint(GoldMediumID, avoidTradeRoute);
   rmAddObjectDefConstraint(GoldMediumID, avoidSocket);
   rmAddObjectDefConstraint(GoldMediumID, coinAvoidCoin);
   rmAddObjectDefConstraint(GoldMediumID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldMediumID, playerConstraint);
   rmAddObjectDefConstraint(GoldMediumID, avoidCliffs);
   rmAddObjectDefConstraint(GoldMediumID, avoidAll);
   rmAddObjectDefConstraint(GoldMediumID, avoidWater10);
   rmSetObjectDefMinDistance(GoldMediumID, 45.0);
   rmSetObjectDefMaxDistance(GoldMediumID, 48.0);
   rmPlaceObjectDefPerPlayer(GoldMediumID, false, 1);

// Extra silver or gold mines 
   silverType = rmRandInt(1,10);
   int extraGoldID = rmCreateObjectDef("extra gold");
   rmAddObjectDefItem(extraGoldID, "minegold", 1, 0);
   rmAddObjectDefToClass(extraGoldID, rmClassID("importantItem"));
   rmAddObjectDefConstraint(extraGoldID, farPlayerConstraint);
   rmAddObjectDefConstraint(extraGoldID, avoidTradeRoute);
   rmAddObjectDefConstraint(extraGoldID, avoidSocket);
   rmAddObjectDefConstraint(extraGoldID, coinAvoidCoin);
   rmAddObjectDefConstraint(extraGoldID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(extraGoldID, avoidWater10);
   rmAddObjectDefConstraint(extraGoldID, avoidAll);
   rmSetObjectDefMinDistance(extraGoldID, 0.0);
   rmSetObjectDefMaxDistance(extraGoldID, 30.0);
   rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.35, 1);
   if (cNumberNonGaiaPlayers < 5)
   {
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.9, 1);
      if (rmRandInt(1,2) == 1)
         rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.5, 1);
      else
         rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.63, 1);
   }
   else
   {
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.49, 1);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.65, 1);
   }
   rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.77, 1);

   silverType = rmRandInt(1,10);
   int GoldFartherID=rmCreateObjectDef("extra silver farther");
   rmAddObjectDefItem(GoldFartherID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(GoldFartherID, avoidTradeRoute);
   rmAddObjectDefConstraint(GoldFartherID, avoidSocket);
   rmAddObjectDefConstraint(GoldFartherID, coinAvoidCoin);
   rmAddObjectDefConstraint(GoldFartherID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldFartherID, circleConstraint);
   rmAddObjectDefConstraint(GoldFartherID, avoidAll);
   rmAddObjectDefConstraint(GoldFartherID, avoidWater10);
   rmSetObjectDefMinDistance(GoldFartherID, 0.0);
   rmSetObjectDefMaxDistance(GoldFartherID, 35.0);
   rmAddObjectDefConstraint(GoldFartherID, farPlayerConstraint);
   rmPlaceObjectDefAtLoc(GoldFartherID, 0, 0.5, 0.22, 1);
   rmPlaceObjectDefAtLoc(GoldFartherID, 0, 0.25, 0.93, 1);
   rmPlaceObjectDefAtLoc(GoldFartherID, 0, 0.75, 0.93, 1);
   if (cNumberNonGaiaPlayers > 6)
   {   
      rmPlaceObjectDefAtLoc(GoldFartherID, 0, 0.28, 0.9, 1);
      rmPlaceObjectDefAtLoc(GoldFartherID, 0, 0.72, 0.9, 1);
   }

// Extra tree clumps near players - to ensure fair access to wood
   int extraTreesID=rmCreateObjectDef("extra trees");
   rmAddObjectDefItem(extraTreesID, treeType, 5, 5.0);
   rmSetObjectDefMinDistance(extraTreesID, 14);
   rmSetObjectDefMaxDistance(extraTreesID, 19);
   rmAddObjectDefConstraint(extraTreesID, avoidAll);
   rmAddObjectDefConstraint(extraTreesID, avoidCoin);
   rmAddObjectDefConstraint(extraTreesID, avoidSocket);
   rmAddObjectDefConstraint(extraTreesID, avoidTradeRoute);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(extraTreesID, 0, rmAreaID("player"+i), 2);

   // Text
   rmSetStatusText("",0.70);

// sheep etc
   int sheepID=rmCreateObjectDef("herdable animal");
   rmAddObjectDefItem(sheepID, sheepType, 2, 4.0);
   rmAddObjectDefToClass(sheepID, rmClassID("herdableFood"));
   rmSetObjectDefMinDistance(sheepID, 35.0);
   rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(sheepID, avoidSheep);
   rmAddObjectDefConstraint(sheepID, avoidAll);
   rmAddObjectDefConstraint(sheepID, playerConstraint);
   rmAddObjectDefConstraint(sheepID, avoidCliffs);
   rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
   if (rmRandInt(1,2) == 1)
      rmPlaceObjectDefPerPlayer(sheepID, false, 3);
   else 
      rmPlaceObjectDefPerPlayer(sheepID, false, 4);

// Central herds
   int centralHerdID=rmCreateObjectDef("central herd");  
   rmAddObjectDefItem(centralHerdID, centerHerdType, rmRandInt(5,7), 6.0);
   rmAddObjectDefToClass(centralHerdID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(centralHerdID, 0.0);
   rmSetObjectDefMaxDistance(centralHerdID, rmXFractionToMeters(0.06));
   rmAddObjectDefConstraint(centralHerdID, avoidTradeRoute);
   rmAddObjectDefConstraint(centralHerdID, avoidImportantItem);
   rmAddObjectDefConstraint(centralHerdID, avoidWater10);
   rmAddObjectDefConstraint(centralHerdID, longPlayerConstraint);
   rmAddObjectDefConstraint(centralHerdID, huntableConstraint);
   rmSetObjectDefCreateHerd(centralHerdID, true);
   rmPlaceObjectDefAtLoc(centralHerdID, 0, 0.5, 0.55, 1);
   // additional of central herd type
   rmAddObjectDefConstraint(centralHerdID, farPlayerConstraint);
   rmSetObjectDefMinDistance(centralHerdID, rmXFractionToMeters(0.3));
   rmSetObjectDefMaxDistance(centralHerdID, rmXFractionToMeters(0.38));
   rmPlaceObjectDefInArea(centralHerdID, 0, barrierCID, cNumberNonGaiaPlayers);

// forest
   int failCount=0;
   int numTries=16*cNumberNonGaiaPlayers; 
   int forestChance = -1;

   if (cNumberNonGaiaPlayers == 3)
      numTries=14*cNumberNonGaiaPlayers;  
   if (cNumberNonGaiaPlayers > 3)
      numTries=12*cNumberNonGaiaPlayers;  
   if (cNumberNonGaiaPlayers > 5)
      numTries=11*cNumberNonGaiaPlayers;
   if (cNumberNonGaiaPlayers > 7)
      numTries=10*cNumberNonGaiaPlayers;   

   for (i=0; <numTries)
   {
      forestChance = rmRandInt(1, 2);
      int forest=rmCreateArea("forest "+i);
      rmSetAreaWarnFailure(forest, false);
      rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(230));
      rmSetAreaForestType(forest, forestType);
      rmSetAreaForestDensity(forest, rmRandFloat(0.7, 1.0));
      rmSetAreaForestClumpiness(forest, rmRandFloat(0.5, 0.9));
      rmSetAreaForestUnderbrush(forest, rmRandFloat(0.0, 0.5));
      rmSetAreaCoherence(forest, rmRandFloat(0.4, 0.7));
      if (forestChance == 2)
      {
		rmSetAreaMinBlobs(forest, 1);
		rmSetAreaMaxBlobs(forest, 3);					
		rmSetAreaMinBlobDistance(forest, 12.0);
		rmSetAreaMaxBlobDistance(forest, 24.0);
	}
      rmSetAreaSmoothDistance(forest, 20);
      rmAddAreaToClass(forest, rmClassID("classForest")); 
	rmAddAreaConstraint(forest, mediumPlayerConstraint);
      rmAddAreaConstraint(forest, forestConstraint);
      rmAddAreaConstraint(forest, avoidAll); 
	rmAddAreaConstraint(forest, avoidCoin);  
      rmAddAreaConstraint(forest, avoidImpassableLand); 
      rmAddAreaConstraint(forest, avoidTradeRoute);
	rmAddAreaConstraint(forest, avoidStartingUnits);
	rmAddAreaConstraint(forest, avoidSocket);
	rmAddAreaConstraint(forest, avoidNativesShort);
      rmAddAreaConstraint(forest, forestsAvoidBison); 
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

   // Text
   rmSetStatusText("",0.80);

// Mountain trees
   int mtTreesID=rmCreateObjectDef("mountain trees");
   rmAddObjectDefItem(mtTreesID, treeType, 5, 10.0);
   rmAddObjectDefConstraint(mtTreesID, avoidAll);
   rmAddObjectDefConstraint(mtTreesID, avoidCoin);
   rmAddObjectDefConstraint(mtTreesID, avoidSocket);
   rmAddObjectDefConstraint(mtTreesID, avoidTradeRoute);
   rmPlaceObjectDefInArea(mtTreesID, 0, rmAreaID("barrier center single"), cNumberNonGaiaPlayers*6);

// Random trees
   int StragglerTreeID=rmCreateObjectDef("stragglers");
   rmAddObjectDefItem(StragglerTreeID, treeType, 1, 0.0);
   rmAddObjectDefConstraint(StragglerTreeID, avoidAll);
   rmAddObjectDefConstraint(StragglerTreeID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(StragglerTreeID, avoidCoin);
   rmAddObjectDefConstraint(StragglerTreeID, patchConstraint);
   rmAddObjectDefConstraint(StragglerTreeID, avoidWater10);
   rmSetObjectDefMinDistance(StragglerTreeID, 10.0);
   rmSetObjectDefMaxDistance(StragglerTreeID, rmXFractionToMeters(0.5));
   for(i=0; <cNumberNonGaiaPlayers*6)
      rmPlaceObjectDefAtLoc(StragglerTreeID, 0, 0.5, 0.3);
   for(i=0; <cNumberNonGaiaPlayers*6)
      rmPlaceObjectDefAtLoc(StragglerTreeID, 0, 0.5, 0.75);

   // Text
   rmSetStatusText("",0.90);

// Fish
   int fishVsFishID=rmCreateClassDistanceConstraint("fish v fish", rmClassID("classFish"), 20.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 5.0);
   int fishID=rmCreateObjectDef("fish");
   rmAddObjectDefItem(fishID, fishType, 2, 5.0);
   rmAddObjectDefToClass(fishID, rmClassID("classFish"));
   rmSetObjectDefMinDistance(fishID, 0.0);
   rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(2.2));
   rmAddObjectDefConstraint(fishID, fishVsFishID);
   rmAddObjectDefConstraint(fishID, fishLand);
   if (cNumberNonGaiaPlayers < 4)
      rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.45, cNumberNonGaiaPlayers*11);
   else if (cNumberNonGaiaPlayers < 6)
      rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.45, cNumberNonGaiaPlayers*9);
   else
      rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.45, cNumberNonGaiaPlayers*8);

   int fish2ID=rmCreateObjectDef("second type fish");
   rmAddObjectDefItem(fish2ID, fish2Type, 2, 5.0);
   rmAddObjectDefToClass(fish2ID, rmClassID("classFish"));
   rmSetObjectDefMinDistance(fish2ID, 0.0);
   rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(2.2));
   rmAddObjectDefConstraint(fish2ID, fishVsFishID);
   rmAddObjectDefConstraint(fish2ID, fishLand);
   if (cNumberNonGaiaPlayers < 4)
      rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.45, cNumberNonGaiaPlayers*12);
   else if (cNumberNonGaiaPlayers < 6)
      rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.45, cNumberNonGaiaPlayers*10);
   else
      rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.45, cNumberNonGaiaPlayers*8);

// Whales
   int whaleLand = rmCreateTerrainDistanceConstraint("whale v. land", "land", true, 12.0);
   int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", whaleType, 40.0);
   int whaleID=rmCreateObjectDef("whale");
   rmAddObjectDefItem(whaleID, whaleType, 1, 5.0);
   rmSetObjectDefMinDistance(whaleID, 0.0);
   rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
   rmAddObjectDefConstraint(whaleID, whaleLand);
   if (cNumberNonGaiaPlayers < 4)
      rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.08, 4*cNumberNonGaiaPlayers);
   else
      rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.08, 3*cNumberNonGaiaPlayers);

   rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.9));
   if (cNumberNonGaiaPlayers < 4)
      rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
   else
      rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

// Deco  
   if (vultures == 1)
   { 
	int vultureID=rmCreateObjectDef("perching vultures");
	int avoidVultures=rmCreateTypeDistanceConstraint("avoid other vultures", "PropVulturePerching", 50.0);
	rmAddObjectDefItem(vultureID, "PropVulturePerching", 1, 0.0);
	rmSetObjectDefMinDistance(vultureID, 0.0);
	rmSetObjectDefMaxDistance(vultureID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(vultureID, avoidAll);
	rmAddObjectDefConstraint(vultureID, avoidImportantItem);
	rmAddObjectDefConstraint(vultureID, avoidCoin);
	rmAddObjectDefConstraint(vultureID, avoidImpassableLand);
	rmAddObjectDefConstraint(vultureID, avoidTradeRoute);
	rmAddObjectDefConstraint(vultureID, avoidCliffs);
	rmAddObjectDefConstraint(vultureID, avoidVultures);
	rmAddObjectDefConstraint(vultureID, avoidWater20);
	rmAddObjectDefConstraint(vultureID, longPlayerConstraint);
	rmPlaceObjectDefAtLoc(vultureID, 0, 0.5, 0.35, 1);
	rmPlaceObjectDefAtLoc(vultureID, 0, 0.5, 0.55, 1);
	rmPlaceObjectDefAtLoc(vultureID, 0, 0.5, 0.8, 2);
   }

   if (eagles == 1)
   {
	int avoidEagles=rmCreateTypeDistanceConstraint("avoids Eagles", "EaglesNest", 50.0);
	int randomEagleTreeID=rmCreateObjectDef("random eagle tree");
	rmAddObjectDefItem(randomEagleTreeID, "EaglesNest", 1, 0.0);
	rmSetObjectDefMinDistance(randomEagleTreeID, 10.0);
	rmSetObjectDefMaxDistance(randomEagleTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomEagleTreeID, avoidAll);
	rmAddObjectDefConstraint(randomEagleTreeID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidEagles);
	rmPlaceObjectDefAtLoc(randomEagleTreeID, 0, 0.5, 0.8, 2);
	rmPlaceObjectDefAtLoc(randomEagleTreeID, 0, 0.5, 0.55, 1);
	rmPlaceObjectDefAtLoc(randomEagleTreeID, 0, 0.5, 0.35, 1);
   }

   int buzzardFlockID=rmCreateObjectDef("buzzards");
   int avoidBuzzards=rmCreateTypeDistanceConstraint("buzzard avoid buzzard", "BuzzardFlock", 70.0);
   rmAddObjectDefItem(buzzardFlockID, "BuzzardFlock", 1, 3.0);
   rmSetObjectDefMinDistance(buzzardFlockID, 0.0);
   rmSetObjectDefMaxDistance(buzzardFlockID, rmXFractionToMeters(0.3));
   rmAddObjectDefConstraint(buzzardFlockID, avoidBuzzards);
   rmAddObjectDefConstraint(buzzardFlockID, avoidSocket);
   rmAddObjectDefConstraint(buzzardFlockID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(buzzardFlockID, playerConstraint);
   rmPlaceObjectDefAtLoc(buzzardFlockID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

  // King of the Hill (added 2026-11 for WoL): centre of the land strip, between the two sides
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

  
