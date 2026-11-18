// Titicaca
// Originally Finger Lake by RF_Gandalf

include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";

void main(void)
{  
   // Text
   rmSetStatusText("",0.01);

// Set up for variables
   string baseType = "";
   string pondType = "";
   string cliffType = "";
   string forestType = "";
   string treeType = "";
   string deerType = "";
   string deer2Type = "";
   string sheepType = "";
   string centerHerdType = "";
   string lakeFishType = "";

// Set up for natives to appear on the map
   int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;

   if (rmAllocateSubCivs(4) == true)
   {
	subCiv0=rmGetCivID("Aymara");
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Aymara");

	subCiv1=rmGetCivID("Republiqueta");
      if (subCiv1 >= 0)
         rmSetSubCiv(1, "Republiqueta"); 

	subCiv2=rmGetCivID("Cherokee");
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Cherokee");
   }

// Pick pattern for trees, terrain, features, etc.
//   int seasonPicker = rmRandInt(1,5);
   int seasonPicker = 2;
   int patternChance = -1;  
   int variantChance = rmRandInt(1,2);
   int lightingChance = rmRandInt(1,2);
   int trPattern = 7;
   int socketPattern = rmRandInt(1,2);   
   int nativeSetup = rmRandInt(1,7);
   if (cNumberNonGaiaPlayers > 4)
      nativeSetup = rmRandInt(2,7);
   int nativePattern = rmRandInt(1,3);
//   int sheepChance = rmRandInt(1,2);
   int sheepChance = 1;
   int featureChance = rmRandInt(1,10);
   int makeCliffs = -1; 
   int cliffVariety = rmRandInt(0,5);
   int makeLake = 1;
   int makeLakefish = -1; 
   int eagles = -1;
   int hillTrees = -1;
   int placeBerries = 1;
   int baseHt = -1;
   int forestDist = rmRandInt(12,18);
   int circChance = rmRandInt(1,5);
   int placeCircular = 0;
//   int axisChance = rmRandInt(1,2);
   int axisChance = 2;
   int playerSide = rmRandInt(1,2);   
   int twoChoice = rmRandInt(1,2);
   int threeChoice = rmRandInt(1,3);
   int fourChoice = rmRandInt(1,4);
   int fiveChoice = rmRandInt(1,5);
   int placeGold = rmRandInt(1,5);

// Picks the map size
   int playerTiles = 20000;
   if (cNumberNonGaiaPlayers == 8)
	playerTiles = 14000;
   else if (cNumberNonGaiaPlayers == 7)
	playerTiles = 14500;
   else if (cNumberNonGaiaPlayers == 6)
	playerTiles = 15750;
   else if (cNumberNonGaiaPlayers == 5)
	playerTiles = 16500;
   else if (cNumberNonGaiaPlayers == 4)
	playerTiles = 17500;
   else if (cNumberNonGaiaPlayers == 3)
	playerTiles = 18500;

   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   int longSide=1.3*size; 
   if (axisChance == 2) 
      rmSetMapSize(size, longSide);
   else if (axisChance == 1)    
      rmSetMapSize(longSide, size);
   
// Elevation
   rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.7, 5.0);
   rmSetMapElevationHeightBlend(1.0);
   rmSetSeaLevel(0.0);
	
   // Text
   rmSetStatusText("",0.05);

// Pick terrain patterns and features 

   if (seasonPicker == 1)
	patternChance = 5;
   else if (seasonPicker < 4)
	patternChance = 4;
   else
	patternChance = 6;

   if (patternChance == 4) // summer
   {
      rmSetMapType("andes");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("spccc1a1");
	else
         rmSetLightingSet("spcjc4blight");

      baseType = "titicaca_grass";
	forestType = "Titicaca Forest";
      cliffType = "Missouri 2";
      pondType = "Falkland Coast";
	treeType = "Treeandes";
      if (variantChance == 1)
	{
         deerType = "guanaco";
         deer2Type = "rhea";
         centerHerdType = "guanaco";
	}
      else 
	{     
         deerType = "rhea";
         deer2Type = "guanaco";
         centerHerdType = "guanaco";        
	}   
   }
   else if (patternChance == 5) // winter
   {
      rmSetMapType("greatlakes");
      rmSetMapType("snow");
	if (lightingChance == 1)
	   rmSetLightingSet("Rockies");
	else
         rmSetLightingSet("Great Lakes Winter");

      baseType = "greatlakes_snow";
	forestType = "great lakes forest snow";
      cliffType = "rocky mountain2";
      pondType = "great lakes ice";
	treeType = "TreeGreatLakesSnow";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "moose";
         centerHerdType = "elk";
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "elk";
         centerHerdType = "moose";       
	}      
      placeBerries = 0;
   }
   else if (patternChance == 6) //  fall
   {
      rmSetMapType("newEngland");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("paris");
	else
	   rmSetLightingSet("new england");
      baseType = "newengland_grass";
	forestType = "new england forest";
      cliffType = "New England Inland Grass";
	pondType = "new england lake";
	treeType = "TreeNewEngland";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "turkey";
         centerHerdType = "moose";         
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "moose";
         centerHerdType = "turkey";        
	}
   }
   if (sheepChance == 1)
      sheepType = "llama";
   else
      sheepType = "sheep";
   lakeFishType = "FishSalmon";
   baseHt = 1;
   hillTrees = rmRandInt(0,1);
   makeCliffs = 1;

   rmSetBaseTerrainMix(baseType);
   rmTerrainInitialize("yukon\ground1_yuk", 1);
   rmEnableLocalWater(false);
   rmSetMapType("land");
   rmSetWorldCircleConstraint(true);
   rmSetWindMagnitude(2.0);

// Precipitation
   if (patternChance == 5) // winter
      rmSetGlobalSnow( 0.7 );
   
   chooseMercs();
	wotta_triggers();

// Define some classes.
   int classPlayer=rmDefineClass("player");
   int lakeClass=rmDefineClass("lake");
   rmDefineClass("classHill");
   rmDefineClass("classPatch");
   rmDefineClass("starting settlement");
   rmDefineClass("startingUnit");
   rmDefineClass("classForest");
   rmDefineClass("importantItem");
   rmDefineClass("natives");
   rmDefineClass("classCliff");
   rmDefineClass("classMountain");
   rmDefineClass("center");
   rmDefineClass("classNugget");
   rmDefineClass("socketClass");
   rmDefineClass("classClearing"); 
   int classHuntable=rmDefineClass("huntableFood");   
   int classHerdable=rmDefineClass("herdableFood"); 

   // Text
   rmSetStatusText("",0.10);

// -------------Define constraints
   // Map edge constraints
   int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
   int secondEdgeConstraint=rmCreateBoxConstraint("avoid edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
   int circleConstraintMt=rmCreatePieConstraint("circle Constraint for mts", 0.5, 0.5, 0, size*0.38, rmDegreesToRadians(0), rmDegreesToRadians(360));

   // Center constraints
   int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 30.0);
   int centerConstraintShort=rmCreateClassDistanceConstraint("stay away from center short", rmClassID("center"), 12.0);
   int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 70.0);
   int centerConstraintForest=rmCreateClassDistanceConstraint("stay away from center forest", rmClassID("center"), 0.24*size);
   int centerConstraintForest2=rmCreateClassDistanceConstraint("stay away from center forest 2", rmClassID("center"), 0.24*size);
   int centerConstraintForest3=rmCreateClassDistanceConstraint("stay away from center forest 3", rmClassID("center"), 0.24*size);

   // Player constraints
   int playerConstraintForest=rmCreateClassDistanceConstraint("forests kinda stay away from players", classPlayer, 15.0);
   int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 40.0);
   int mediumPlayerConstraint=rmCreateClassDistanceConstraint("medium stay away from players", classPlayer, 25.0);
   int nuggetPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 60.0);
   int farPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players more", classPlayer, 85.0);
   int fartherPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players the most", classPlayer, 105.0);
   int longPlayerConstraint=rmCreateClassDistanceConstraint("land stays away from players", classPlayer, 70.0); 

   // Nature avoidance
   int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
   int shortForestConstraint=rmCreateClassDistanceConstraint("patch vs. forest", rmClassID("classForest"), 15.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), forestDist);
   int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
   int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "gold", 10.0);
   int shortAvoidSilver=rmCreateTypeDistanceConstraint("short gold avoid gold", "Mine", 20.0);
   int coinAvoidCoin=rmCreateTypeDistanceConstraint("coin avoids coin", "gold", 35.0);
   int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 1.0);
   int avoidSheep=rmCreateClassDistanceConstraint("sheep avoids sheep etc", rmClassID("herdableFood"), 45.0);
   int huntableConstraint=rmCreateClassDistanceConstraint("huntable constraint", rmClassID("huntableFood"), 35.0);
   int longHuntableConstraint=rmCreateClassDistanceConstraint("long huntable constraint", rmClassID("huntableFood"), 55.0);
   int forestsAvoidBison=rmCreateClassDistanceConstraint("forest avoids bison", rmClassID("huntableFood"), 15.0);

   // Avoid impassable land, certain features
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
   int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 18.0);
   int hillConstraint=rmCreateClassDistanceConstraint("hill vs. hill", rmClassID("classHill"), 15.0);
   int shortHillConstraint=rmCreateClassDistanceConstraint("patches vs. hill", rmClassID("classHill"), 5.0);
   int longHillConstraint=rmCreateClassDistanceConstraint("far from hill", rmClassID("classHill"), 35.0);
   int medHillConstraint=rmCreateClassDistanceConstraint("medium from hill", rmClassID("classHill"), 28.0);
   int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 8.0);
   int avoidCliffs=rmCreateClassDistanceConstraint("stuff vs. cliff", rmClassID("classCliff"), 12.0);
   int avoidCliff20=rmCreateClassDistanceConstraint("avoid cliffs 20", rmClassID("classCliff"), 20.0);
   int avoidCliffsShort=rmCreateClassDistanceConstraint("stuff vs. cliff short", rmClassID("classCliff"), 7.0);
   int cliffsAvoidCliffs=rmCreateClassDistanceConstraint("cliffs vs. cliffs", rmClassID("classCliff"), 30.0);
   int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water mid-long", "Land", false, 10.0);
   int avoidWater15 = rmCreateTerrainDistanceConstraint("avoid water mid-longer", "Land", false, 15.0);
   int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water a little more", "Land", false, 20.0);
   int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 30.0);
   int avoidLakes=rmCreateClassDistanceConstraint("stuff vs.lakes", rmClassID("lake"), 12.0);
   int avoidLakesFar=rmCreateClassDistanceConstraint("stuff vs.lakes far", rmClassID("lake"), 55.0);
   int avoidClearing=rmCreateClassDistanceConstraint("avoid clearings", rmClassID("classClearing"), 10.0);  
  
   // Unit avoidance
   int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 30.0);
   int avoidStartingUnitsSmall=rmCreateClassDistanceConstraint("objects avoid starting units small", rmClassID("startingUnit"), 10.0);
   int avoidImportantItem=rmCreateClassDistanceConstraint("things avoid each other", rmClassID("importantItem"), 10.0);
   int avoidImportantItemSmall=rmCreateClassDistanceConstraint("important item small avoidance", rmClassID("importantItem"), 7.0);
   int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 60.0);
   int avoidNativesMed=rmCreateClassDistanceConstraint("stuff avoids natives medium", rmClassID("natives"), 35.0);
   int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives shorter", rmClassID("natives"), 15.0);
   int avoidNugget=rmCreateClassDistanceConstraint("nugget vs. nugget", rmClassID("classNugget"), 42.0);
   int avoidNuggetMed=rmCreateClassDistanceConstraint("nugget vs. nugget med", rmClassID("classNugget"), 50.0);
   int avoidNuggetLong=rmCreateClassDistanceConstraint("nugget vs. nugget long", rmClassID("classNugget"), 70.0);
   int avoidNuggetSmall=rmCreateTypeDistanceConstraint("avoid nuggets by a little", "AbstractNugget", 10.0);
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

   // Trade route avoidance.
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 8.0);
   int avoidTradeRouteCliff = rmCreateTradeRouteDistanceConstraint("trade route cliff", 10.0);
   int avoidSocket=rmCreateClassDistanceConstraint("avoid sockets", rmClassID("socketClass"), 12.0);

   // Water Flag constraint
   int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25);
   int flagLand = rmCreateTerrainDistanceConstraint("flag land", "land", true, 10.0);
// ---------------------------------------------------------------------------------------

   // Text
   rmSetStatusText("",0.15);

// Set up player starting locations
if (cNumberTeams == 2)
{
   if (cNumberNonGaiaPlayers == 2)
   {
      if (axisChance == 1)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.22, 0.23);
	   }
	   else
	   {
            rmSetPlacementSection(0.77, 0.78);
	   }
	   rmPlacePlayersCircular(0.41, 0.42, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.27, 0.28);
	   }
	   else
	   {
            rmSetPlacementSection(0.72, 0.73);
	   }
	   rmPlacePlayersCircular(0.41, 0.42, 0.0);
	}
	else if (axisChance == 2)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.02, 0.03);
	   }
	   else
	   {
	      rmSetPlacementSection(0.46, 0.47);
	   }
	   rmPlacePlayersCircular(0.41, 0.42, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.96, 0.97);
	   }
	   else
	   {
	      rmSetPlacementSection(0.52, 0.53);
	   }
	   rmPlacePlayersCircular(0.41, 0.42, 0.0);
	}
   }
   else if (cNumberNonGaiaPlayers < 5)
   {
      if (axisChance == 1)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.18, 0.32);
	   }
	   else
	   {
	      rmSetPlacementSection(0.68, 0.82);
	   }
	   rmPlacePlayersCircular(0.41, 0.42, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.18, 0.32);
	   }
	   else
	   {
	      rmSetPlacementSection(0.68, 0.82);
	   }
	   rmPlacePlayersCircular(0.41, 0.42, 0.0);
	}
	else if (axisChance == 2)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.93, 0.07);
	   }
	   else
	   {
	      rmSetPlacementSection(0.43, 0.57);
	   }
	   rmPlacePlayersCircular(0.41, 0.42, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.93, 0.07);
	   }
	   else
	   {
	      rmSetPlacementSection(0.43, 0.57);
	   }
	   rmPlacePlayersCircular(0.41, 0.42, 0.0);
	}
   }
   else if (cNumberNonGaiaPlayers < 7)
   {
      if (axisChance == 1)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.14, 0.36);
	   }
	   else
	   {
	      rmSetPlacementSection(0.64, 0.86);
	   }
	   rmPlacePlayersCircular(0.42, 0.43, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.14, 0.36);
	   }
	   else
	   {
	      rmSetPlacementSection(0.64, 0.86);
	   }
	   rmPlacePlayersCircular(0.42, 0.43, 0.0);
	}
	else if (axisChance == 2)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.89, 0.11);
	   }
	   else
	   {
	      rmSetPlacementSection(0.39, 0.61);
	   }
	   rmPlacePlayersCircular(0.42, 0.43, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.89, 0.11);
	   }
	   else
	   {
	      rmSetPlacementSection(0.39, 0.61);
	   }
	   rmPlacePlayersCircular(0.42, 0.43, 0.0);
	}
   }
   else
   {
      if (axisChance == 1)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.13, 0.37);
	   }
	   else
	   {
	      rmSetPlacementSection(0.63, 0.87);
	   }
	   rmPlacePlayersCircular(0.42, 0.43, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.13, 0.37);
	   }
	   else
	   {
	      rmSetPlacementSection(0.63, 0.87);
	   }
	   rmPlacePlayersCircular(0.42, 0.43, 0.0);
	}
	else if (axisChance == 2)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.88, 0.12);
	   }
	   else
	   {
	      rmSetPlacementSection(0.38, 0.62);
	   }
	   rmPlacePlayersCircular(0.42, 0.43, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.88, 0.12);
	   }
	   else
	   {
	      rmSetPlacementSection(0.38, 0.62);
	   }
	   rmPlacePlayersCircular(0.42, 0.43, 0.0);
	}
   }
}
else if (cNumberTeams > 2)
   rmPlacePlayersSquare(0.43, 0.0, 0.0);


   // Text
   rmSetStatusText("",0.20);

	
// Set up player areas.
   float playerFraction=rmAreaTilesToFraction(900);
   for(i=1; <cNumberPlayers)
   {
      int id=rmCreateArea("Player"+i);
      rmSetPlayerArea(i, id);
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
		rmSetAreaCliffType(id, cliffType);
		rmSetAreaCliffEdge(id, 2, 0.4, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(id, 4, 1.0, 1.0);
		rmSetAreaCliffPainting(id, false, false, false, 1.5, true);
      rmAddAreaConstraint(id, playerConstraint); 
      rmAddAreaConstraint(id, longAvoidImpassableLand);
      rmAddAreaConstraint(id, playerEdgeConstraint); 
      rmAddAreaConstraint(id, avoidWater20); 
      rmSetAreaLocPlayer(id, i);
		rmSetAreaCoherence(id, 0.9);
      rmSetAreaMix(id, baseType);
      rmSetAreaWarnFailure(id, false);
   }
   rmBuildAllAreas();

   // Text
   rmSetStatusText("",0.25);


   // Text
   rmSetStatusText("",0.30);

// Trade Routes
trPattern = 7;  
variantChance = rmRandInt(1,2);
if (trPattern == 7) // 2 end-to-end edge routes
{
   // first route
   int tradeRouteID7 = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.0, 0.03);
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.12, 0.07);
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.25, 0.15);	
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.4, 0.18);	
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.45, 0.15);	
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.5, 0.11);	
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.55, 0.15);	
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.6, 0.18);
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.75, 0.15);	
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.88, 0.07);
	rmAddTradeRouteWaypoint(tradeRouteID7, 1.0, 0.03);
   }
   else 
   {
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.03, 0.0);
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.07, 0.11);	
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.15, 0.25);
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.18, 0.4);
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.15, 0.45);
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.11, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.15, 0.55);
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.18, 0.6);
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.15, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.07, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID7, 0.03, 1.0);
   }
   rmBuildTradeRoute(tradeRouteID7, "dirt");

   // second route
   int tradeRouteID7A = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.0, 0.98);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.12, 0.93);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.25, 0.85);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.4, 0.82);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.45, 0.89);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.5, 0.85);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.55, 0.89);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.6, 0.82);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.75, 0.85);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.88, 0.93);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 1.0, 0.98);
   }
   else
   {
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.98, 0.0);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.93, 0.12);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.85, 0.25);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.82, 0.4);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.85, 0.45);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.89, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.85, 0.55);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.82, 0.6);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.85, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.93, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID7A, 0.98, 1.0);
   }
   rmBuildTradeRoute(tradeRouteID7A, "carolinas\trade_route");	
}

   // Text
   rmSetStatusText("",0.35);

// Trade sockets
   int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
   rmSetObjectDefAllowOverlap(socketID, true);
   rmAddObjectDefToClass(socketID, rmClassID("importantItem"));
   rmSetObjectDefMinDistance(socketID, 0.0);
   rmSetObjectDefMaxDistance(socketID, 7.0);
   variantChance = rmRandInt(1,2);

if (trPattern == 7) // 2 side end-to-end routes
{
   // add the meeting poles along the trade route.
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID7);
   vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID7, 0.21);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   if (socketPattern == 1) // 3 per route
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID7, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   else // 4 per route
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID7, 0.4);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID7, 0.6);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }

   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID7, 0.79);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   // change the trade route for the new sockets
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID7A);
   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID7A, 0.79);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   if (socketPattern == 1) // 3 per route
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID7A, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   else // 4 per route
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID7A, 0.4);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID7A, 0.6);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }

   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID7A, 0.21);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
}

   //Text
   rmSetStatusText("",0.40);

// Center lake      
   int smalllakeID=rmCreateArea("small lake");
   rmAddAreaToClass(smalllakeID, lakeClass);
   rmSetAreaSize(smalllakeID, 0.22, 0.22);
   rmSetAreaLocation(smalllakeID, 0.5, 0.5);
   if (axisChance == 2) 
      rmAddAreaInfluenceSegment(smalllakeID, 0.5, 0.39, 0.5, 0.61); 
   else
      rmAddAreaInfluenceSegment(smalllakeID, 0.39, 0.5, 0.61, 0.5); 
   rmSetAreaCoherence(smalllakeID, rmRandFloat(0.5,0.7));
   rmSetAreaWaterType(smalllakeID, pondType);
   rmSetAreaBaseHeight(smalllakeID, baseHt);
   rmSetAreaSmoothDistance(smalllakeID, 5);
   rmAddAreaConstraint(smalllakeID, playerConstraint);
   rmAddAreaConstraint(smalllakeID, avoidTradeRoute);
   rmAddAreaConstraint(smalllakeID, avoidSocket);
   rmSetAreaWarnFailure(smalllakeID, false);
   rmBuildArea(smalllakeID);

// Starting TCs and units 	
   int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
   rmSetObjectDefMinDistance(startingUnits, 5.0);
   rmSetObjectDefMaxDistance(startingUnits, 10.0);
   rmAddObjectDefConstraint(startingUnits, avoidAll);
   rmAddObjectDefConstraint(startingUnits, avoidWater10);

   int startingTCID= rmCreateObjectDef("startingTC");
   rmSetObjectDefMaxDistance(startingTCID, 18.0);
   rmAddObjectDefConstraint(startingTCID, avoidAll);
   rmAddObjectDefConstraint(startingTCID, avoidWater10);
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

   int waterFlagID=rmCreateObjectDef("HC water flag "+i);
   rmAddObjectDefItem(waterFlagID, "HomeCityWaterSpawnFlag", 1, 0.0);
   rmAddClosestPointConstraint(playerEdgeConstraint);
   rmAddClosestPointConstraint(flagVsFlag);
   rmAddClosestPointConstraint(flagLand);

   for(i=1; <cNumberPlayers)
   {	
      rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
      rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

	vector TCLocation = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
	vector closestPoint = rmFindClosestPointVector(TCLocation, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(waterFlagID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
   }
   rmClearClosestPointConstraints();

// Central features & patches, per map or variant
   // Center area
   int centerArea=rmCreateArea("TheCenter");
   rmSetAreaSize(centerArea, 0.2, 0.2);
   rmSetAreaLocation(centerArea, 0.5, 0.5);
   rmAddAreaToClass(centerArea, rmClassID("center")); 

   // Text
   rmSetStatusText("",0.45);

// NATIVES
   // Village A 
   int villageAID = -1;
   int whichNative = rmRandInt(1,2);
   int villageType = rmRandInt(1,3);

   if (nativePattern == 1)
   {
      if (whichNative == 1)
	   villageAID = rmCreateGrouping("village A", "native Aymara village "+villageType);
      else if (whichNative == 2)
 	   villageAID = rmCreateGrouping("village A", "native emboaba village "+villageType);
   }
   if (nativePattern == 2)
   {
      if (whichNative == 1)
         villageAID = rmCreateGrouping("village A", "native Aymara village "+villageType);
      else if (whichNative == 2)
 	   villageAID = rmCreateGrouping("village A", "native emboaba village "+villageType);
   }
   if (nativePattern == 3)
   {
      if (whichNative == 1)
         villageAID = rmCreateGrouping("village A", "native Aymara village "+villageType);
      else if (whichNative == 2)
         villageAID = rmCreateGrouping("village A", "native emboaba village "+villageType);
   }

   rmAddGroupingToClass(villageAID, rmClassID("natives"));
   rmAddGroupingToClass(villageAID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageAID, 0.0);
   rmSetGroupingMaxDistance(villageAID, size*0.1);
   rmAddGroupingConstraint(villageAID, avoidImpassableLand);
   rmAddGroupingConstraint(villageAID, avoidTradeRoute);
   rmAddGroupingConstraint(villageAID, avoidWater10);
   rmAddGroupingConstraint(villageAID, avoidNativesMed);
   rmAddGroupingConstraint(villageAID, playerConstraint);

   // Village B - randomly same or opposite village A
   int villageBID = -1;	
   villageType = rmRandInt(1,3);
   whichNative = rmRandInt(1,2);

   if (nativePattern == 1)
   {
      if (whichNative == 1)
	   villageBID = rmCreateGrouping("village B", "native Aymara village "+villageType);
      else if (whichNative == 2)
 	   villageBID = rmCreateGrouping("village B", "native emboaba village "+villageType);
   }
   if (nativePattern == 2)
   {
      if (whichNative == 1)
         villageBID = rmCreateGrouping("village B", "native Aymara village "+villageType);
      else if (whichNative == 2)
 	   villageBID = rmCreateGrouping("village B", "native emboaba village "+villageType);
   }
   if (nativePattern == 3)
   {
      if (whichNative == 1)
         villageBID = rmCreateGrouping("village B", "native Aymara village "+villageType);
      else if (whichNative == 2)
         villageBID = rmCreateGrouping("village B", "native emboaba village "+villageType);
   }
   rmAddGroupingToClass(villageBID, rmClassID("importantItem"));
   rmAddGroupingToClass(villageBID, rmClassID("natives"));
   rmSetGroupingMinDistance(villageBID, 0.0);
   rmSetGroupingMaxDistance(villageBID, size*0.1);
   rmAddGroupingConstraint(villageBID, avoidImpassableLand);
   rmAddGroupingConstraint(villageBID, avoidTradeRoute);
   rmAddGroupingConstraint(villageBID, avoidWater15);
   rmAddGroupingConstraint(villageBID, avoidNatives);
   rmAddGroupingConstraint(villageBID, playerConstraint);

// Placement of Natives 
   if (nativeSetup < 4)  
   {
      for(i=1; <cNumberPlayers) 
      {
         rmSetGroupingMinDistance(villageAID, 65.0);
         rmSetGroupingMaxDistance(villageAID, 90.0);           
	   rmPlaceGroupingAtLoc(villageAID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	   if (nativeSetup == 1)
	   {
            rmSetGroupingMinDistance(villageBID, 65.0);
            rmSetGroupingMaxDistance(villageBID, 90.0);      
		rmPlaceGroupingAtLoc(villageBID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	   }
      }
   }

   if ((nativeSetup == 3) || (nativeSetup == 7)) 
   {
	if (axisChance == 1)
	{
         rmPlaceGroupingAtLoc(villageBID, 0, 0.5, 0.05);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.5, 0.95);
	}
	else
	{
         rmPlaceGroupingAtLoc(villageBID, 0, 0.05, 0.5);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.95, 0.5);
	}
   }

   if (nativeSetup == 4)   
   {
	if (axisChance == 1)
	{
         rmPlaceGroupingAtLoc(villageAID, 0, 0.35, 0.05);
         rmPlaceGroupingAtLoc(villageAID, 0, 0.65, 0.95);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.35, 0.95);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.65, 0.05);
	}
	else
	{
         rmPlaceGroupingAtLoc(villageAID, 0, 0.05, 0.35);
         rmPlaceGroupingAtLoc(villageAID, 0, 0.95, 0.65);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.95, 0.35);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.05, 0.65);
	}
   }

   if (nativeSetup == 5)   
   {
	if (axisChance == 1)
	{
         rmPlaceGroupingAtLoc(villageAID, 0, 0.25, 0.05);
         rmPlaceGroupingAtLoc(villageAID, 0, 0.75, 0.95);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.25, 0.95);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.75, 0.05);
	}
	else
	{
         rmPlaceGroupingAtLoc(villageAID, 0, 0.05, 0.25);
         rmPlaceGroupingAtLoc(villageAID, 0, 0.95, 0.75);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.95, 0.25);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.05, 0.75);
	}
   }

   if ((nativeSetup == 6) || (nativeSetup == 7))   
   {   
      if (axisChance == 2)
	{
         rmPlaceGroupingAtLoc(villageAID, 0, 0.9, 0.13);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.1, 0.13);
         rmPlaceGroupingAtLoc(villageAID, 0, 0.1, 0.87);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.9, 0.87);
      }
	else if (axisChance == 1)
	{
         rmPlaceGroupingAtLoc(villageBID, 0, 0.13, 0.9);
	   rmPlaceGroupingAtLoc(villageAID, 0, 0.13, 0.1);
         rmPlaceGroupingAtLoc(villageBID, 0, 0.87, 0.1);
	   rmPlaceGroupingAtLoc(villageAID, 0, 0.87, 0.9);
	}
   }

   // Text
   rmSetStatusText("",0.50);

// Player Nuggets
   int playerNuggetID=rmCreateObjectDef("player nugget");
   rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
   rmAddObjectDefToClass(playerNuggetID, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(playerNuggetID, 35.0);
   rmSetObjectDefMaxDistance(playerNuggetID, 45.0);
   rmAddObjectDefConstraint(playerNuggetID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(playerNuggetID, avoidTradeRoute);
   rmAddObjectDefConstraint(playerNuggetID, avoidSocket);
   rmAddObjectDefConstraint(playerNuggetID, avoidNugget);
   rmAddObjectDefConstraint(playerNuggetID, avoidWater10);
   for(i=1; <cNumberPlayers)
   {
 	rmSetNuggetDifficulty(1, 1);
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }

   // Text
   rmSetStatusText("",0.55);

// Cliffs
   int cliffHt = -1;
   int failCount=0;
   int numTries=cNumberNonGaiaPlayers*14;

numTries=cNumberNonGaiaPlayers*8;
cliffVariety = rmRandInt(1,5);


   int numCliffs = cNumberNonGaiaPlayers + rmRandInt(4,6);

   for (i=0; <numCliffs)
   {
	cliffVariety = rmRandInt(1,5);
		cliffHt = rmRandInt(5,7);    
		int bigCliffID=rmCreateArea("big cliff" +i);
		rmSetAreaWarnFailure(bigCliffID, false);
		rmSetAreaCliffType(bigCliffID, cliffType);
		rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
		if (cliffVariety == 1) // like Patagonia
		{
   	         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(550), rmAreaTilesToFraction(750));
      	   rmSetAreaCliffEdge(bigCliffID, 2, 0.35, 0.1, 1.0, 0);
      	   rmSetAreaCliffPainting(bigCliffID, false, false, false, 1.5, true);
		   rmSetAreaCliffHeight(bigCliffID, 7, 2.0, 0.5);
		   rmSetAreaCoherence(bigCliffID, 0.5);
		   rmSetAreaSmoothDistance(bigCliffID, rmRandInt(5,10));
		   rmSetAreaHeightBlend(bigCliffID, 1.0);
		   rmSetAreaMinBlobs(bigCliffID, 2);
	  	   rmSetAreaMaxBlobs(bigCliffID, 3);
		   rmSetAreaMinBlobDistance(bigCliffID, 15.0);
		   rmSetAreaMaxBlobDistance(bigCliffID, 20.0);
		}
		else if (cliffVariety == 2) // smaller, kinda like in Sudden Death from AOM
		{
   	         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(280), rmAreaTilesToFraction(400));
		   rmSetAreaCliffEdge(bigCliffID, 1, 0.6, 0.1, 1.0, 0);
		   rmSetAreaCliffPainting(bigCliffID, false, false, false, 1.5, true);
		   rmSetAreaCliffHeight(bigCliffID, cliffHt, 1.0, 1.0);
		   rmSetAreaCoherence(bigCliffID, rmRandFloat(0.4, 0.9));
		   rmSetAreaSmoothDistance(bigCliffID, 10);
		   rmSetAreaHeightBlend(bigCliffID, 2.0);
		   rmSetAreaMinBlobs(bigCliffID, 1);
	  	   rmSetAreaMaxBlobs(bigCliffID, 3);
		   rmSetAreaMinBlobDistance(bigCliffID, 5.0);
		   rmSetAreaMaxBlobDistance(bigCliffID, 10);
  	      }		   
		else  // kinda random, kinda like Texas or NE
		{
   	            rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(700));
		      rmSetAreaCliffEdge(bigCliffID, 1, 0.6, 0.1, 1.0, 0);
		      rmSetAreaCliffPainting(bigCliffID, false, false, false, 1.5, true);
		      rmSetAreaCliffHeight(bigCliffID, cliffHt, 2.0, 1.0);
		      rmSetAreaCoherence(bigCliffID, rmRandFloat(0.4, 0.9));
		      rmSetAreaSmoothDistance(bigCliffID, 15);
		      rmSetAreaHeightBlend(bigCliffID, 1.0);
		      rmSetAreaMinBlobs(bigCliffID, 2);
		      rmSetAreaMaxBlobs(bigCliffID, 2);
		      rmSetAreaMinBlobDistance(bigCliffID, 15.0);
		      rmSetAreaMaxBlobDistance(bigCliffID, 25.0);
	      }
		rmAddAreaConstraint(bigCliffID, avoidImportantItem);
		rmAddAreaConstraint(bigCliffID, avoidTradeRoute);
            rmAddAreaConstraint(bigCliffID, avoidNatives);
	      rmAddAreaConstraint(bigCliffID, avoidWater20);
	      rmAddAreaConstraint(bigCliffID, cliffsAvoidCliffs);
	      rmAddAreaConstraint(bigCliffID, avoidSocket);
	      rmAddAreaConstraint(bigCliffID, avoidStartingUnits);
	      rmAddAreaConstraint(bigCliffID, longPlayerConstraint);
	      rmAddAreaConstraint(bigCliffID, longHillConstraint);
		rmBuildArea(bigCliffID);
   }

   // Text
   rmSetStatusText("",0.60);

// more resources
   // start area trees 
   int StartAreaTreeID=rmCreateObjectDef("starting trees");
   rmAddObjectDefItem(StartAreaTreeID, treeType, 1, 0.0);
   rmSetObjectDefMinDistance(StartAreaTreeID, 8);
   rmSetObjectDefMaxDistance(StartAreaTreeID, 12);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRoute);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
   rmPlaceObjectDefPerPlayer(StartAreaTreeID, false, 5);

   // berry bushes
   int berryNum = rmRandInt(2,5);
   int StartBerryBushID=rmCreateObjectDef("starting berry bush");
   rmAddObjectDefItem(StartBerryBushID, "BerryBush", rmRandInt(2,4), 4.0);
   rmSetObjectDefMinDistance(StartBerryBushID, 10.0);
   rmSetObjectDefMaxDistance(StartBerryBushID, 16.0);
   rmAddObjectDefConstraint(StartBerryBushID, avoidStartingUnitsSmall);
   if (placeBerries == 1)
      rmPlaceObjectDefPerPlayer(StartBerryBushID, false, 1);
   rmSetObjectDefMinDistance(StartBerryBushID, 70.0);
   rmSetObjectDefMaxDistance(StartBerryBushID, 85.0);
   if (patternChance == 4)
      rmPlaceObjectDefPerPlayer(StartBerryBushID, false, 1);

   // Text
   rmSetStatusText("",0.65);

   // start area huntable
   int deerNum = rmRandInt(5, 8);
   int startPronghornID=rmCreateObjectDef("starting pronghorn");
   rmAddObjectDefItem(startPronghornID, deerType, deerNum, 5.0);
   rmAddObjectDefToClass(startPronghornID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(startPronghornID, 16);
   rmSetObjectDefMaxDistance(startPronghornID, 22);
   rmAddObjectDefConstraint(startPronghornID, avoidStartResource);
   rmAddObjectDefConstraint(startPronghornID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(startPronghornID, avoidAll);
   rmSetObjectDefCreateHerd(startPronghornID, true);
   rmPlaceObjectDefPerPlayer(startPronghornID, false, 2);

   // second huntable
   int deer2Num = rmRandInt(4, 8);
   int farPronghornID=rmCreateObjectDef("far pronghorn");
   rmAddObjectDefItem(farPronghornID, deer2Type, deer2Num, 5.0);
   rmAddObjectDefToClass(farPronghornID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(farPronghornID, 42.0);
   rmSetObjectDefMaxDistance(farPronghornID, 60.0);
   rmAddObjectDefConstraint(farPronghornID, avoidStartResource);
   rmAddObjectDefConstraint(farPronghornID, mediumPlayerConstraint);
   rmAddObjectDefConstraint(farPronghornID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(farPronghornID, avoidNativesShort);
   rmAddObjectDefConstraint(farPronghornID, huntableConstraint);
   rmAddObjectDefConstraint(farPronghornID, avoidAll);
   rmSetObjectDefCreateHerd(farPronghornID, true);
   if (sheepChance == 0)
      rmPlaceObjectDefPerPlayer(farPronghornID, false, 4);
   else
      rmPlaceObjectDefPerPlayer(farPronghornID, false, 3);

   // additional second huntable for low player numbers
   if (cNumberNonGaiaPlayers < 4)
   {
      rmAddObjectDefConstraint(farPronghornID, fartherPlayerConstraint);
      rmSetObjectDefMinDistance(farPronghornID, rmXFractionToMeters(0.25));
      rmSetObjectDefMaxDistance(farPronghornID, rmXFractionToMeters(0.38));
      rmPlaceObjectDefPerPlayer(farPronghornID, false, 1);
   }

// Silver mines - players
   int silverType = -1;
   silverType = rmRandInt(1,10);
   int playerGoldID=rmCreateObjectDef("player silver closer");
   rmAddObjectDefItem(playerGoldID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(playerGoldID, avoidTradeRoute);
   rmAddObjectDefConstraint(playerGoldID, avoidSocket);
   rmAddObjectDefConstraint(playerGoldID, coinAvoidCoin);
   rmAddObjectDefConstraint(playerGoldID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(playerGoldID, avoidAll);
   rmAddObjectDefConstraint(playerGoldID, avoidWater10);
   rmSetObjectDefMinDistance(playerGoldID, 18.0);
   rmSetObjectDefMaxDistance(playerGoldID, 23.0);
   rmPlaceObjectDefPerPlayer(playerGoldID, false, 1);

   rmAddObjectDefConstraint(playerGoldID, playerConstraint);
   rmSetObjectDefMinDistance(playerGoldID, 50.0);
   rmSetObjectDefMaxDistance(playerGoldID, 60.0);
   rmPlaceObjectDefPerPlayer(playerGoldID, false, 1);

   silverType = rmRandInt(1,10);
   int GoldMediumID=rmCreateObjectDef("player silver med");
   rmAddObjectDefItem(GoldMediumID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(GoldMediumID, avoidTradeRoute);
   rmAddObjectDefConstraint(GoldMediumID, avoidSocket);
   rmAddObjectDefConstraint(GoldMediumID, coinAvoidCoin);
   rmAddObjectDefConstraint(GoldMediumID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldMediumID, farPlayerConstraint);
   rmAddObjectDefConstraint(GoldMediumID, avoidAll);
   rmAddObjectDefConstraint(GoldMediumID, avoidWater10);
   rmSetObjectDefMinDistance(GoldMediumID, 85.0);
   rmSetObjectDefMaxDistance(GoldMediumID, 100.0);
   rmPlaceObjectDefPerPlayer(GoldMediumID, false, 1);

   // Text
   rmSetStatusText("",0.70);

// Extra tree clumps near players - to ensure fair access to wood
   int extraTreesID=rmCreateObjectDef("extra trees");
   rmAddObjectDefItem(extraTreesID, treeType, 4, 5.0);
   rmSetObjectDefMinDistance(extraTreesID, 14);
   rmSetObjectDefMaxDistance(extraTreesID, 18);
   rmAddObjectDefConstraint(extraTreesID, avoidAll);
   rmAddObjectDefConstraint(extraTreesID, avoidCoin);
   rmAddObjectDefConstraint(extraTreesID, avoidSocket);
   rmAddObjectDefConstraint(extraTreesID, avoidTradeRoute);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(extraTreesID, 0, rmAreaID("player"+i), 1);

   int extraTrees2ID=rmCreateObjectDef("more extra trees");
   rmAddObjectDefItem(extraTrees2ID, treeType, 5, 6.0);
   rmSetObjectDefMinDistance(extraTrees2ID, 18);
   rmSetObjectDefMaxDistance(extraTrees2ID, 28);
   rmAddObjectDefConstraint(extraTrees2ID, avoidAll);
   rmAddObjectDefConstraint(extraTrees2ID, avoidCoin);
   rmAddObjectDefConstraint(extraTrees2ID, avoidSocket);
   rmAddObjectDefConstraint(extraTrees2ID, avoidTradeRoute);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(extraTrees2ID, 0, rmAreaID("player"+i), 1);

// Clearings

      for (i=0; <cNumberNonGaiaPlayers*2)   
      {
	   int forestClearing=rmCreateArea("forest clearing "+i);
	   rmSetAreaWarnFailure(forestClearing, false);
	   rmSetAreaSize(forestClearing, rmAreaTilesToFraction(200), rmAreaTilesToFraction(300));
	   rmSetAreaMix(forestClearing, baseType);
	   rmAddAreaToClass(forestClearing, rmClassID("classClearing"));
	   rmSetAreaMinBlobs(forestClearing, 1);
	   rmSetAreaMaxBlobs(forestClearing, 3);
	   rmSetAreaMinBlobDistance(forestClearing, 6.0);
	   rmSetAreaMaxBlobDistance(forestClearing, 16.0);
	   rmSetAreaCoherence(forestClearing, 0.6);
	   rmSetAreaSmoothDistance(forestClearing, 10);
	   rmAddAreaConstraint(forestClearing, shortAvoidImpassableLand);
	   rmAddAreaConstraint(forestClearing, avoidClearing);
	   rmAddAreaConstraint(forestClearing, farPlayerConstraint);
	   rmAddAreaConstraint(forestClearing, patchConstraint);
	   rmBuildArea(forestClearing); 
      }

   // Text
   rmSetStatusText("",0.75);

// Main forests
   int forestChance = -1;

      numTries=18*cNumberNonGaiaPlayers;
      if (cNumberNonGaiaPlayers > 3)
         numTries=16*cNumberNonGaiaPlayers;  
      if (cNumberNonGaiaPlayers > 5)
         numTries=13*cNumberNonGaiaPlayers;  
      if (cNumberNonGaiaPlayers > 7)
         numTries=11*cNumberNonGaiaPlayers; 

   failCount=0;
   for (i=0; <numTries)
   {
      forestChance = rmRandInt(1,4);
      int forest=rmCreateArea("forest "+i);
      rmSetAreaWarnFailure(forest, false);
      rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(250));
      rmSetAreaForestType(forest, forestType);
      rmSetAreaForestDensity(forest, rmRandFloat(0.7, 0.9));
      rmSetAreaForestClumpiness(forest, rmRandFloat(0.5, 0.9));
      rmSetAreaForestUnderbrush(forest, rmRandFloat(0.0, 0.5));
      rmSetAreaCoherence(forest, rmRandFloat(0.4, 0.7));
      rmSetAreaSmoothDistance(forest, rmRandInt(10,20));
      if (forestChance == 3)
      {
		rmSetAreaMinBlobs(forest, 1);
		rmSetAreaMaxBlobs(forest, 3);					
		rmSetAreaMinBlobDistance(forest, 12.0);
		rmSetAreaMaxBlobDistance(forest, 24.0);
	}
      if (forestChance == 4)
      {
		rmSetAreaMinBlobs(forest, 3);
		rmSetAreaMaxBlobs(forest, 5);					
		rmSetAreaMinBlobDistance(forest, 16.0);
		rmSetAreaMaxBlobDistance(forest, 28.0);
	}
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
	rmAddAreaConstraint(forest, hillConstraint);
	rmAddAreaConstraint(forest, avoidClearing);
	if (hillTrees == 1)
	{
	   if (rmRandInt(1,3) > 1)
            rmSetAreaBaseHeight(forest, rmRandFloat(3.5, 5.0));
	}
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

// Random Nuggets
   int nugget2= rmCreateObjectDef("nugget medium"); 
   rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(2, 2);
   rmAddObjectDefToClass(nugget2, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(nugget2, 60.0);
   rmSetObjectDefMaxDistance(nugget2, 110.0);
   rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget2, avoidSocket);
   rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
   rmAddObjectDefConstraint(nugget2, nuggetPlayerConstraint);
   rmAddObjectDefConstraint(nugget2, avoidNuggetMed);
   rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
   rmAddObjectDefConstraint(nugget2, avoidWater10);
   rmAddObjectDefConstraint(nugget2, avoidAll);
   rmPlaceObjectDefPerPlayer(nugget2, false, 1);

   int nugget3= rmCreateObjectDef("nugget hard"); 
   rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(3, 3);
   rmAddObjectDefToClass(nugget3, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(nugget3, 80.0);
   rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.6));
   rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget3, avoidSocket);
   rmAddObjectDefConstraint(nugget3, avoidTradeRoute);
   rmAddObjectDefConstraint(nugget3, farPlayerConstraint);
   rmAddObjectDefConstraint(nugget3, avoidNuggetLong);
   rmAddObjectDefConstraint(nugget3, playerEdgeConstraint);
   rmAddObjectDefConstraint(nugget3, avoidWater10);
   rmAddObjectDefConstraint(nugget3, avoidAll);
   rmPlaceObjectDefPerPlayer(nugget3, false, 1);

   rmAddObjectDefConstraint(nugget3, fartherPlayerConstraint);
   rmSetNuggetDifficulty(2, 3);
   rmPlaceObjectDefPerPlayer(nugget3, false, 1);

   int nugget4= rmCreateObjectDef("nugget nuts"); 
   rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(4, 4);
   rmAddObjectDefToClass(nugget4, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(nugget4, 85.0);
   rmSetObjectDefMaxDistance(nugget4, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(nugget4, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget4, avoidSocket);
   rmAddObjectDefConstraint(nugget4, avoidTradeRoute);
   rmAddObjectDefConstraint(nugget4, fartherPlayerConstraint);
   rmAddObjectDefConstraint(nugget4, avoidNuggetLong);
   rmAddObjectDefConstraint(nugget4, playerEdgeConstraint);
   rmAddObjectDefConstraint(nugget4, avoidWater10);
   rmAddObjectDefConstraint(nugget4, avoidAll);
   rmPlaceObjectDefPerPlayer(nugget4, false, 1);

// Extra silver mines - more central.
   silverType = rmRandInt(1,10);
   int extraGoldID = rmCreateObjectDef("extra silver "+i);
   if (placeGold == 5)
      rmAddObjectDefItem(extraGoldID, "minegold", 1, 0);
   else
      rmAddObjectDefItem(extraGoldID, "mine", 1, 0.0);
   rmAddObjectDefToClass(extraGoldID, rmClassID("importantItem"));
   rmAddObjectDefConstraint(extraGoldID, avoidTradeRoute);
   rmAddObjectDefConstraint(extraGoldID, avoidSocket);
   rmAddObjectDefConstraint(extraGoldID, coinAvoidCoin);
   rmAddObjectDefConstraint(extraGoldID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(extraGoldID, avoidWater10);
   rmAddObjectDefConstraint(extraGoldID, avoidAll);
   rmSetObjectDefMinDistance(extraGoldID, 0.0);
   rmSetObjectDefMaxDistance(extraGoldID, 115.0);
   rmAddObjectDefConstraint(extraGoldID, centerConstraintFar);
   rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.5, rmRandInt(1,2));
   if (cNumberNonGaiaPlayers > 4)
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.5, 1);
   if (axisChance == 1)
   {
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.49, 0.78, 2);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.51, 0.22, 2);
   }
   else
   {
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.78, 0.51, 2);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.22, 0.49, 2);
   }

   silverType = rmRandInt(1,10);
   int GoldFarID=rmCreateObjectDef("player silver far");
   if (placeGold == 1)
      rmAddObjectDefItem(GoldFarID, "minegold", 1, 0);
   else
      rmAddObjectDefItem(GoldFarID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(GoldFarID, avoidTradeRoute);
   rmAddObjectDefConstraint(GoldFarID, avoidSocket);
   rmAddObjectDefConstraint(GoldFarID, coinAvoidCoin);
   rmAddObjectDefConstraint(GoldFarID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldFarID, avoidAll);
   rmAddObjectDefConstraint(GoldFarID, fartherPlayerConstraint);
   rmAddObjectDefConstraint(GoldFarID, centerConstraintFar);
   rmAddObjectDefConstraint(GoldFarID, avoidWater10);
   rmSetObjectDefMinDistance(GoldFarID, 125.0);
   rmSetObjectDefMaxDistance(GoldFarID, 170.0);
   if (rmRandInt(1,3) == 1)
      rmPlaceObjectDefPerPlayer(GoldFarID, false, 2);
   else
      rmPlaceObjectDefPerPlayer(GoldFarID, false, 1);

// sheep etc
   if (sheepChance > 0)
   {
      int sheepID=rmCreateObjectDef("herdable animal");
      rmAddObjectDefItem(sheepID, sheepType, 2, 4.0);
      rmAddObjectDefToClass(sheepID, rmClassID("herdableFood"));
      rmSetObjectDefMinDistance(sheepID, 40.0);
      rmSetObjectDefMaxDistance(sheepID, 0.25*longSide);
      rmAddObjectDefConstraint(sheepID, avoidSheep);
      rmAddObjectDefConstraint(sheepID, avoidAll);
      rmAddObjectDefConstraint(sheepID, playerConstraint);
      rmAddObjectDefConstraint(sheepID, avoidCliffs);
      rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
      rmPlaceObjectDefPerPlayer(sheepID, false, 2);
      rmAddObjectDefConstraint(sheepID, farPlayerConstraint);
      rmSetObjectDefMaxDistance(sheepID, 0.35*longSide);
      if (rmRandInt(1,2) == 1)
         rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);
      else 
         rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3); 
   }

   // Text
   rmSetStatusText("",0.85);

// Central herds
   int centralHerdID=rmCreateObjectDef("central herd");  
   rmAddObjectDefItem(centralHerdID, centerHerdType, rmRandInt(7,9), 6.0);
   rmAddObjectDefToClass(centralHerdID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(centralHerdID, 0.1*size);
   rmSetObjectDefMaxDistance(centralHerdID, 0.22*size);
   rmAddObjectDefConstraint(centralHerdID, avoidTradeRoute);
   rmAddObjectDefConstraint(centralHerdID, avoidImportantItem);
   rmAddObjectDefConstraint(centralHerdID, avoidWater10);
   rmAddObjectDefConstraint(centralHerdID, farPlayerConstraint);
   rmAddObjectDefConstraint(centralHerdID, longHuntableConstraint);
   rmSetObjectDefCreateHerd(centralHerdID, true);
   rmPlaceObjectDefAtLoc(centralHerdID, 0, 0.5, 0.5, 2);
   // additional of central herd type
   rmAddObjectDefConstraint(centralHerdID, fartherPlayerConstraint);
   rmSetObjectDefMinDistance(centralHerdID, 0.22*size);
   rmSetObjectDefMaxDistance(centralHerdID, 0.35*size);
   rmPlaceObjectDefPerPlayer(centralHerdID, false, 1);

// far huntable
   int farHuntableID=rmCreateObjectDef("far huntable");
   rmAddObjectDefItem(farHuntableID, deerType, rmRandInt(5,9), 6.0);
   rmAddObjectDefToClass(farHuntableID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(farHuntableID, 0.25*size);
   rmSetObjectDefMaxDistance(farHuntableID, 0.4*size);
   rmAddObjectDefConstraint(farHuntableID, avoidTradeRoute);
   rmAddObjectDefConstraint(farHuntableID, avoidImportantItem);
   rmAddObjectDefConstraint(farHuntableID, avoidWater10);
   rmAddObjectDefConstraint(farHuntableID, fartherPlayerConstraint);
   rmAddObjectDefConstraint(farHuntableID, longHuntableConstraint);
   rmAddObjectDefConstraint(farHuntableID, avoidAll);
   rmSetObjectDefCreateHerd(farHuntableID, true);
   rmPlaceObjectDefPerPlayer(farHuntableID, false, 1);

// Lone elk
   int loneElkID=rmCreateObjectDef("lone elk");
   threeChoice = rmRandInt(1,3);
   if (threeChoice == 1)
      rmAddObjectDefItem(loneElkID, centerHerdType, rmRandInt(1,2), 3.0);
   else if (threeChoice == 2)
      rmAddObjectDefItem(loneElkID, deer2Type, rmRandInt(1,2), 3.0);
   else
      rmAddObjectDefItem(loneElkID, deerType, rmRandInt(1,2), 3.0);
   rmAddObjectDefToClass(loneElkID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(loneElkID, 70.0);
   rmSetObjectDefMaxDistance(loneElkID, 0.4*size);
   rmAddObjectDefConstraint(loneElkID, longPlayerConstraint);
   rmAddObjectDefConstraint(loneElkID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(loneElkID, avoidNativesShort);
   rmAddObjectDefConstraint(loneElkID, huntableConstraint);
   rmAddObjectDefConstraint(loneElkID, avoidAll);
   rmSetObjectDefCreateHerd(loneElkID, true);
   rmPlaceObjectDefPerPlayer(loneElkID, false, 2);

   // Text
   rmSetStatusText("",0.90);

// Random trees
   int StragglerTreeID=rmCreateObjectDef("stragglers");
   rmAddObjectDefItem(StragglerTreeID, treeType, 1, 0.0);
   rmAddObjectDefConstraint(StragglerTreeID, avoidAll);
   rmAddObjectDefConstraint(StragglerTreeID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(StragglerTreeID, hillConstraint);
   rmAddObjectDefConstraint(StragglerTreeID, avoidCoin);
   rmAddObjectDefConstraint(StragglerTreeID, patchConstraint);
   rmAddObjectDefConstraint(StragglerTreeID, avoidWater10);
   rmSetObjectDefMinDistance(StragglerTreeID, 10.0);
   rmSetObjectDefMaxDistance(StragglerTreeID, rmXFractionToMeters(0.5));
   for(i=0; <cNumberNonGaiaPlayers*16)
      rmPlaceObjectDefAtLoc(StragglerTreeID, 0, 0.5, 0.5);

// Fish
   int fishNum = cNumberNonGaiaPlayers * rmRandInt(3,4);
   if (cNumberNonGaiaPlayers > 3)
	fishNum = cNumberNonGaiaPlayers * rmRandInt(2,3);
   int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 12.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 4.0);

   int lakeFishID=rmCreateObjectDef("lake fish");
   rmAddObjectDefItem(lakeFishID, lakeFishType, 1, 5.0);
   rmSetObjectDefMinDistance(lakeFishID, 5.0);
   rmSetObjectDefMaxDistance(lakeFishID, 90.0);
   rmAddObjectDefConstraint(lakeFishID, fishLand);
   rmAddObjectDefConstraint(lakeFishID, fishVsFishID);

   for(i=0; <fishNum)
   {
	if (axisChance == 1)
	{ 
	   rmPlaceObjectDefAtLoc(lakeFishID, 0, 0.28, 0.5, rmRandInt(1,2)); 
	   rmPlaceObjectDefAtLoc(lakeFishID, 0, 0.39, 0.5, rmRandInt(1,2)); 
	   rmPlaceObjectDefAtLoc(lakeFishID, 0, 0.5, 0.5, rmRandInt(1,2)); 
	   rmPlaceObjectDefAtLoc(lakeFishID, 0, 0.61, 0.5, rmRandInt(1,2)); 
	   rmPlaceObjectDefAtLoc(lakeFishID, 0, 0.72, 0.5, rmRandInt(1,2));
	}
	else
	{ 
	   rmPlaceObjectDefAtLoc(lakeFishID, 0, 0.5, 0.28, rmRandInt(1,2)); 
	   rmPlaceObjectDefAtLoc(lakeFishID, 0, 0.5, 0.39, rmRandInt(1,2)); 
	   rmPlaceObjectDefAtLoc(lakeFishID, 0, 0.5, 0.5, rmRandInt(1,2)); 
	   rmPlaceObjectDefAtLoc(lakeFishID, 0, 0.5, 0.61, rmRandInt(1,2)); 
	   rmPlaceObjectDefAtLoc(lakeFishID, 0, 0.5, 0.72, rmRandInt(1,2));
	}
   }
   fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish longer", "fish", 16.0);
   rmPlaceObjectDefInArea(lakeFishID, 0, rmAreaID("small lake"), cNumberNonGaiaPlayers + rmRandInt(5,7));

   // Text
   rmSetStatusText("",0.95);

// Deco

	int avoidEagles=rmCreateTypeDistanceConstraint("avoids Eagles", "EaglesNest", 40.0);
	int randomEagleTreeID=rmCreateObjectDef("random eagle tree");
	rmAddObjectDefItem(randomEagleTreeID, "EaglesNest", 1, 0.0);
	rmSetObjectDefMinDistance(randomEagleTreeID, 0.0);
	rmSetObjectDefMaxDistance(randomEagleTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomEagleTreeID, avoidAll);
	rmAddObjectDefConstraint(randomEagleTreeID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidEagles);
	rmPlaceObjectDefAtLoc(randomEagleTreeID, 0, 0.5, 0.5, 2);

   if (patternChance == 4) // summer
   {
	int avoidGrass=rmCreateTypeDistanceConstraint("avoids grass", "underbrushTexasGrass", 30.0);
   	int Grass=rmCreateObjectDef("grass");
	rmAddObjectDefItem(Grass, "underbrushTexasGrass", 1, 0.0);
	rmSetObjectDefMinDistance(Grass, 0.0);
	rmSetObjectDefMaxDistance(Grass, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(Grass, avoidAll);
	rmAddObjectDefConstraint(Grass, avoidImpassableLand);
	rmAddObjectDefConstraint(Grass, playerConstraint);
	rmPlaceObjectDefAtLoc(Grass, 0, 0.5, 0.5, 8*cNumberNonGaiaPlayers);
   }
   
   // Text
   rmSetStatusText("",0.99);


  // King of the Hill (added 2026-11 for WoL): the middle is Lake Titicaca; first open land on the line that splits the teams (its shore)
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

  
