// Central America Plus TWC
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
   string pondType = "";
   string cliffType = "";
   string forestType = "";
   string riverType = "";
   string treeType = "";
   string deerType = "";
   string deer2Type = "";
   string sheepType = "";
   string centerHerdType = "";
   string fishType = "";
   string fish2Type = "";
   string whaleType = "";
   string oceanType = "";

// Set up for natives to appear on the map
   int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;
   int subCiv3=-1;

   if (rmAllocateSubCivs(4) == true)
   {
	subCiv0=rmGetCivID("Aztecs");
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Aztecs");

	subCiv1=rmGetCivID("Maya");
      if (subCiv1 >= 0)
         rmSetSubCiv(1, "Maya");

	subCiv2=rmGetCivID("zapotec");
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "zapotec");

	subCiv3=rmGetCivID("Miskitos");
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Miskitos");
    }

// Pick pattern for trees, terrain, features, etc.
   int variantChance = rmRandInt(1,6);
   int lightingChance = rmRandInt(1,5);
   int trPattern = rmRandInt(3,5);
   int socketPattern = rmRandInt(1,2);   
   int nativeSetup = rmRandInt(0,17);
   if (cNumberNonGaiaPlayers > 4)
   {
	if (nativeSetup == 9)
         nativeSetup = rmRandInt(11,17);
	if (nativeSetup == 10)
         nativeSetup = rmRandInt(0,8);
   }	 
   int nativePattern = 11; //rmRandInt(10,13);
   int nativeNumber = rmRandInt(2,6);
   int endPosition = rmRandInt(1,3);
   int sidePosition = rmRandInt(1,3);
   int sheepChance = rmRandInt(1,2);
   int cliffChance = rmRandInt(1,10);
   int cliffVariety = rmRandInt(1,4);
   int hillTrees = -1;
   int placeBerries = 1;
   int baseHt = -1;
   int forestDist = rmRandInt(12,18);
   int circChance = rmRandInt(1,5);
   int axisChance = rmRandInt(1,2);
   int playerSide = rmRandInt(1,2);   
   int coastPatch = -1;
   int threeChoice = rmRandInt(1,3);
   int fourChoice = rmRandInt(1,4);
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

   int size=1.8*sqrt(cNumberNonGaiaPlayers*playerTiles);
   int longSide=1.6*size; 
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
//  trPattern = 5;
//  variantChance = 2;
//  lightingChance = 1;

      rmSetSeaType("yucatan Coast");
      rmSetMapType("yucatan");
      rmSetMapType("tropical");
	if (lightingChance == 1)
	   rmSetLightingSet("311b");
	else if (lightingChance == 2)
         rmSetLightingSet("yucatan");
	else if (lightingChance == 3)
         rmSetLightingSet("sonora");
	else if (lightingChance == 4)
         rmSetLightingSet("323b_inca");
	else
         rmSetLightingSet("seville");
     
      baseHt = 1;
      baseType = "yucatan_grass";
      oceanType = "yucatan Coast";
	forestType = "yucatan forest";
      cliffType = "Amazon";
	treeType = "TreeYucatan";
      if (variantChance == 1)
      {
         deerType = "tapir";
         deer2Type = "capybara";
         centerHerdType = "turkey";
      }
      else if (variantChance == 2)
	{
         deerType = "capybara";
         deer2Type = "turkey";
         centerHerdType = "tapir";
	}
      else if (variantChance == 3)
	{
         deerType = "capybara";
         deer2Type = "deer";
         centerHerdType = "tapir";
	}
      else if (variantChance == 4)
	{
         deerType = "capybara";
         deer2Type = "turkey";
         centerHerdType = "deer";
	}
      else if (variantChance == 5)
	{
         deerType = "deer";
         deer2Type = "tapir";
         centerHerdType = "capybara";
	}
	else
      {
         deerType = "tapir";
         deer2Type = "turkey";
         centerHerdType = "deer";
      }
      sheepType = "cow";
      fishType = "FishMahi";
      fish2Type = "FishTarpon";
      whaleType = "humpbackWhale";
      hillTrees = rmRandInt(0,1);

   rmSetBaseTerrainMix(baseType);
   rmTerrainInitialize("yukon\ground1_yuk", 1);
   rmEnableLocalWater(false);
   rmSetMapType("land");
   rmSetWorldCircleConstraint(true);
   rmSetWindMagnitude(1.0);
   if (lightingChance < 3)
      rmSetGlobalRain( 0.7 );
   chooseMercs();
	wotta_triggers();

// Define some classes.
   int classPlayer=rmDefineClass("player");
   rmDefineClass("classPatch");
   rmDefineClass("starting settlement");
   rmDefineClass("startingUnit");
   rmDefineClass("classForest");
   rmDefineClass("importantItem");
   rmDefineClass("natives");
   rmDefineClass("classCliff");
   rmDefineClass("center");
   rmDefineClass("classNugget");
   rmDefineClass("socketClass");
   rmDefineClass("classSea");
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
   int enormousPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players for asymmetric starts", classPlayer, 130.0);
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

   // Avoid impassable land, certain features
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
   int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 18.0);
   int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 8.0);
   int avoidCliffs=rmCreateClassDistanceConstraint("stuff vs. cliff", rmClassID("classCliff"), 12.0);
   int avoidCliff20=rmCreateClassDistanceConstraint("avoid cliffs 20", rmClassID("classCliff"), 20.0);
   int avoidCliffsShort=rmCreateClassDistanceConstraint("stuff vs. cliff short", rmClassID("classCliff"), 7.0);
   int cliffsAvoidCliffs=rmCreateClassDistanceConstraint("cliffs vs. cliffs", rmClassID("classCliff"), 30.0);
   int avoidWater5 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 5.0);
   int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water mid-long", "Land", false, 10.0);
   int avoidWater15 = rmCreateTerrainDistanceConstraint("avoid water mid-longer", "Land", false, 15.0);
   int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water a little more", "Land", false, 20.0);
   int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 30.0);
   int avoidSea=rmCreateClassDistanceConstraint("stuff vs.sea", rmClassID("classSea"), 25.0);
   int avoidClearing=rmCreateClassDistanceConstraint("avoid clearings", rmClassID("classClearing"), 10.0);  
  
   // Unit avoidance
   int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 30.0);
   int avoidStartingUnitsSmall=rmCreateClassDistanceConstraint("objects avoid starting units small", rmClassID("startingUnit"), 10.0);
   int avoidStartingUnitsLong=rmCreateClassDistanceConstraint("objects avoid starting units long", rmClassID("startingUnit"), 70.0);
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
   int flagLand = rmCreateTerrainDistanceConstraint("flag land", "land", true, 20.0);
// ---------------------------------------------------------------------------------------------------------------------------------------
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
	   rmPlacePlayersCircular(0.33, 0.34, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.27, 0.28);
	   }
	   else
	   {
            rmSetPlacementSection(0.72, 0.73);
	   }
	   rmPlacePlayersCircular(0.33, 0.34, 0.0);
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
	   rmPlacePlayersCircular(0.33, 0.34, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.96, 0.97);
	   }
	   else
	   {
	      rmSetPlacementSection(0.52, 0.53);
	   }
	   rmPlacePlayersCircular(0.33, 0.34, 0.0);
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
	   rmPlacePlayersCircular(0.34, 0.35, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.18, 0.32);
	   }
	   else
	   {
	      rmSetPlacementSection(0.68, 0.82);
	   }
	   rmPlacePlayersCircular(0.34, 0.35, 0.0);
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
	   rmPlacePlayersCircular(0.34, 0.35, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.93, 0.07);
	   }
	   else
	   {
	      rmSetPlacementSection(0.43, 0.57);
	   }
	   rmPlacePlayersCircular(0.34, 0.35, 0.0);
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
	   rmPlacePlayersCircular(0.35, 0.36, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.14, 0.36);
	   }
	   else
	   {
	      rmSetPlacementSection(0.64, 0.86);
	   }
	   rmPlacePlayersCircular(0.35, 0.36, 0.0);
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
	   rmPlacePlayersCircular(0.35, 0.36, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.89, 0.11);
	   }
	   else
	   {
	      rmSetPlacementSection(0.39, 0.61);
	   }
	   rmPlacePlayersCircular(0.35, 0.36, 0.0);
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
	   rmPlacePlayersCircular(0.35, 0.36, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.13, 0.37);
	   }
	   else
	   {
	      rmSetPlacementSection(0.63, 0.87);
	   }
	   rmPlacePlayersCircular(0.35, 0.36, 0.0);
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
	   rmPlacePlayersCircular(0.35, 0.36, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.88, 0.12);
	   }
	   else
	   {
	      rmSetPlacementSection(0.38, 0.62);
	   }
	   rmPlacePlayersCircular(0.35, 0.36, 0.0);
	}
   }
}
else if (cNumberTeams > 2)
   rmPlacePlayersCircular(0.34, 0.36, 0.0);

   // Text
   rmSetStatusText("",0.20);

// Set up player areas.
   float playerFraction=rmAreaTilesToFraction(100);
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
      rmAddAreaConstraint(id, avoidWater20); 
      rmSetAreaLocPlayer(id, i);
      rmSetAreaMix(id, baseType);
      rmSetAreaWarnFailure(id, false);
   }
   rmBuildAllAreas();

   // Text
   rmSetStatusText("",0.25);

// First water area
   int sea1ID=rmCreateArea("first sea");
   rmAddAreaToClass(sea1ID, rmClassID("classSea"));
   rmSetAreaSize(sea1ID, 0.11, 0.11);
   if (axisChance == 2)
   {
      rmSetAreaLocation(sea1ID, 0.5, 0.965);
      rmAddAreaInfluenceSegment(sea1ID, 0.5, 0.965, 1.0, 0.91);
      rmAddAreaInfluenceSegment(sea1ID, 0.5, 0.965, 0.0, 0.91);
   }
   else if (axisChance == 1)
   {
      rmSetAreaLocation(sea1ID, 0.965, 0.5);
      rmAddAreaInfluenceSegment(sea1ID, 0.965, 0.5, 0.91, 0.0);
      rmAddAreaInfluenceSegment(sea1ID, 0.965, 0.5, 0.91, 1.0);
   }
   rmSetAreaWaterType(sea1ID, oceanType);
   rmSetAreaBaseHeight(sea1ID, 0.0); 
   rmSetAreaMinBlobs(sea1ID, 8);
   rmSetAreaMaxBlobs(sea1ID, 10);
   rmSetAreaMinBlobDistance(sea1ID, 10);
   rmSetAreaMaxBlobDistance(sea1ID, 30);
   rmSetAreaSmoothDistance(sea1ID, 20);
   rmSetAreaCoherence(sea1ID, 0.6);
   rmSetAreaEdgeFilling(sea1ID, 2);
   rmAddAreaConstraint(sea1ID, mediumPlayerConstraint); 
   rmSetAreaObeyWorldCircleConstraint(sea1ID, false);
   rmBuildArea(sea1ID);

// Second water area
   int sea2ID=rmCreateArea("second sea");
   rmAddAreaToClass(sea2ID, rmClassID("classSea"));
   rmSetAreaSize(sea2ID, 0.11, 0.11);
   if (axisChance == 2)
   {
      rmSetAreaLocation(sea2ID, 0.5, 0.035);
      rmAddAreaInfluenceSegment(sea2ID, 0.5, 0.035, 0.0, 0.09);
      rmAddAreaInfluenceSegment(sea2ID, 0.5, 0.035, 1.0, 0.09);
   }
   else if (axisChance == 1)
   {
      rmSetAreaLocation(sea2ID, 0.03, 0.55);
      rmAddAreaInfluenceSegment(sea2ID, 0.035, 0.5, 0.09, 0.0);
      rmAddAreaInfluenceSegment(sea2ID, 0.035, 0.5, 0.09, 1.0);
   }
   rmSetAreaWaterType(sea2ID, oceanType);
   rmSetAreaBaseHeight(sea2ID, 0.0); 
   rmSetAreaMinBlobs(sea2ID, 8);
   rmSetAreaMaxBlobs(sea2ID, 10);
   rmSetAreaMinBlobDistance(sea2ID, 10);
   rmSetAreaMaxBlobDistance(sea2ID, 30);
   rmSetAreaSmoothDistance(sea2ID, 20);
   rmSetAreaCoherence(sea2ID, 0.6);
   rmSetAreaEdgeFilling(sea2ID, 2);
   rmAddAreaConstraint(sea2ID, mediumPlayerConstraint); 
   rmSetAreaObeyWorldCircleConstraint(sea2ID, false);
   rmBuildArea(sea2ID);

   // Text
   rmSetStatusText("",0.30);

// Central highlands
   int barrierCID=rmCreateArea("barrier center single"); 
   rmSetAreaWarnFailure(barrierCID, false);
   rmSetAreaCliffType(barrierCID, cliffType);
   rmAddAreaToClass(barrierCID, rmClassID("classCliff"));
   rmAddAreaConstraint(barrierCID, playerEdgeConstraint);
   rmAddAreaConstraint(barrierCID, mediumPlayerConstraint);  
   if (cNumberNonGaiaPlayers > 6) 
      rmSetAreaSize(barrierCID, 0.12, 0.125);
   else if (cNumberNonGaiaPlayers > 3) 
      rmSetAreaSize(barrierCID, 0.13, 0.135);
   else
      rmSetAreaSize(barrierCID, 0.16, 0.165);
   rmSetAreaLocation(barrierCID, 0.5, 0.5);
   if (axisChance == 1) 
      rmAddAreaInfluenceSegment(barrierCID, 0.5, 0.04, 0.5, 0.96); 
   else
      rmAddAreaInfluenceSegment(barrierCID, 0.04, 0.5, 0.96, 0.5); 
   if (rmRandInt(1,2) == 1)
      rmSetAreaCliffEdge(barrierCID, 6, 0.145, 0.05, 0.6, 0);
   else
      rmSetAreaCliffEdge(barrierCID, 5, 0.172, 0.05, 0.6, 0);
   rmSetAreaCliffPainting(barrierCID, false, true, true, 1.5, true); 
   rmSetAreaCliffHeight(barrierCID, rmRandInt(8,9), 1.0, 1.0);
   rmSetAreaCoherence(barrierCID, 0.8);
   rmSetAreaSmoothDistance(barrierCID, 5);
   rmSetAreaHeightBlend(barrierCID, 2);
   rmBuildArea(barrierCID);

// Central Valley
   fourChoice = rmRandInt(1,4);
   int valleyID=rmCreateArea("valley");
   rmSetAreaWarnFailure(valleyID, false); 
   rmSetAreaCliffType(valleyID, cliffType);
   rmAddAreaToClass(valleyID, rmClassID("classCliff"));
   if (cNumberNonGaiaPlayers > 6) 
     	rmSetAreaSize(valleyID, 0.075, 0.08);
   else if (cNumberNonGaiaPlayers > 3) 
      rmSetAreaSize(valleyID, 0.082, 0.087);
   else
      rmSetAreaSize(valleyID, 0.087, 0.09);
   rmSetAreaLocation(valleyID, 0.5, 0.5);

   if (axisChance == 1)
   {
	if (fourChoice == 1)
         rmAddAreaInfluenceSegment(valleyID, 0.5, 0.0, 0.5, 1.0); 
	else
	{
	   threeChoice = rmRandInt(1,3);
	   if (threeChoice == 1)
	   { 
     	      rmAddAreaInfluenceSegment(valleyID, 0.5, 0.6, 0.54, 1.0); 
	   }
	   else if (threeChoice == 2)
	   { 
     	      rmAddAreaInfluenceSegment(valleyID, 0.5, 0.6, 0.46, 1.0); 
	   }
	   else if (threeChoice == 3)
	   { 
     	      rmAddAreaInfluenceSegment(valleyID, 0.5, 0.6, 0.5, 1.0); 
	   }
	   threeChoice = rmRandInt(1,3);
	   if (threeChoice == 1)
	   { 
     	      rmAddAreaInfluenceSegment(valleyID, 0.5, 0.4, 0.54, 0.0); 
	   }
	   else if (threeChoice == 2)
	   { 
     	      rmAddAreaInfluenceSegment(valleyID, 0.5, 0.4, 0.46, 0.0); 
	   }
	   else if (threeChoice == 3)
	   { 
     	      rmAddAreaInfluenceSegment(valleyID, 0.5, 0.4, 0.5, 0.0); 
	   }
	}
   }
   else if (axisChance == 2)
   {
      if (fourChoice == 1)
         rmAddAreaInfluenceSegment(valleyID, 0.0, 0.5, 1.0, 0.5);
	else
	{
	   threeChoice = rmRandInt(1,3);
	   if (threeChoice == 1)
	   {
            rmAddAreaInfluenceSegment(valleyID, 0.6, 0.5, 1.0, 0.54); 
	   }
	   else if (threeChoice == 2)
	   { 
            rmAddAreaInfluenceSegment(valleyID, 0.6, 0.5, 1.0, 0.46); 
	   }
	   else if (threeChoice == 3)
	   { 
            rmAddAreaInfluenceSegment(valleyID, 0.6, 0.5, 1.0, 0.5); 
	   }
	   threeChoice = rmRandInt(1,3);
	   if (threeChoice == 1)
	   { 
            rmAddAreaInfluenceSegment(valleyID, 0.4, 0.5, 0.0, 0.54); 
	   }
	   else if (threeChoice == 2)
	   { 
            rmAddAreaInfluenceSegment(valleyID, 0.4, 0.5, 0.0, 0.46); 
	   }
	   else if (threeChoice == 3)
	   { 
            rmAddAreaInfluenceSegment(valleyID, 0.4, 0.5, 0.0, 0.5); 
	   }
	}	     
   }
   fourChoice = rmRandInt(1,4);
   if (fourChoice == 1)
      rmSetAreaCliffEdge(valleyID, 9, 0.088, 0.1, 1.0, 0);
   else if (fourChoice == 2)
      rmSetAreaCliffEdge(valleyID, 8, 0.094, 0.1, 1.0, 0);
   else if (fourChoice == 3)
      rmSetAreaCliffEdge(valleyID, 7, 0.125, 0.115, 1.0, 0);
   else
      rmSetAreaCliffEdge(valleyID, 6, 0.135, 0.125, 1.0, 0);
   rmSetAreaCliffPainting(valleyID, false, true, true, 1.5);
   rmSetAreaCoherence(valleyID, rmRandFloat(0.4,0.8));
   rmSetAreaSmoothDistance(valleyID, rmRandInt(10,20));  
   rmSetAreaCliffHeight(valleyID, rmRandInt(-7,-5), 1.0, 1.0);
   rmSetAreaHeightBlend(valleyID, 2);
   rmAddAreaConstraint(valleyID, avoidImportantItem);
   rmAddAreaConstraint(valleyID, avoidTradeRoute);
   rmAddAreaConstraint(valleyID, avoidNatives);
   rmAddAreaConstraint(valleyID, avoidWater20);
   rmAddAreaConstraint(valleyID, avoidSocket);
   rmAddAreaConstraint(valleyID, mediumPlayerConstraint);  
   rmBuildArea(valleyID);

// Trade Routes
variantChance = rmRandInt(1,2);
if (trPattern == 5)  // one single diagonal route
{
   int tradeRouteID5 = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
	if (variantChance == 1)
	{	
   	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.22, 0.0);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.32, 0.4);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.5, 0.5);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.68, 0.6);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.78, 1.0);
	}
	else if (variantChance == 2)
	{	
   	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.22, 1.0);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.32, 0.6);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.5, 0.5);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.68, 0.4);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.78, 0.0);
	}
   }
   else 
   {
	if (variantChance == 1)
	{	
   	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.0, 0.22);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.4, 0.32);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.5, 0.5);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.6, 0.68);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 1.0, 0.78);
	}
	else if (variantChance == 2)
	{	
   	   rmAddTradeRouteWaypoint(tradeRouteID5, 1.0, 0.22);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.6, 0.32);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.5, 0.5);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.4, 0.68);
	   rmAddTradeRouteWaypoint(tradeRouteID5, 0.0, 0.78);
	}
   }
   rmBuildTradeRoute(tradeRouteID5, "dirt");
}
else if (trPattern == 4)  // two side-to-side
{
   int tradeRouteID4 = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.67, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.66, 0.78);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.65, 0.7);
	if (variantChance == 1)
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.67, 0.53);
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.67, 0.47);
	}
	else
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.69, 0.55);
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.69, 0.45);
	}
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.65, 0.3);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.66, 0.22);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.67, 0.0);
   }
   else if (axisChance == 2) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID4, 1.0, 0.67);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.78, 0.66);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.7, 0.65);
	if (variantChance == 1)
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.53, 0.67);
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.47, 0.67);
	}
	else
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.55, 0.69);
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.45, 0.69);
	}
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.3, 0.65);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.22, 0.66);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.0, 0.67);
   }
   rmBuildTradeRoute(tradeRouteID4, "carolinas\trade_route");

   int tradeRouteID4A = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
      rmAddTradeRouteWaypoint(tradeRouteID4A, 0.33, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.34, 0.78);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.35, 0.7);
	if (variantChance == 1)
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.33, 0.53);
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.33, 0.47);
	}
	else
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.31, 0.55);
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.31, 0.45);
	}
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.35, 0.3);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.34, 0.22);
      rmAddTradeRouteWaypoint(tradeRouteID4A, 0.33, 0.0);
   }
   else if (axisChance == 2) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID4A, 1.0, 0.33);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.78, 0.34);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.7, 0.35);
	if (variantChance == 1)
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.53, 0.33);
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.47, 0.33);
	}
	else
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.55, 0.31);
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.45, 0.31);
	}
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.3, 0.35);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.22, 0.34);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.0, 0.33);
   }
   rmBuildTradeRoute(tradeRouteID4A, "dirt");
}
else if (trPattern == 3)  // two opposite parabolas
{
   int tradeRouteID3 = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
	if (variantChance == 1)
	   rmAddTradeRouteWaypoint(tradeRouteID3, 0.75, 1.0);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID3, 0.85, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.72, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.68, 0.62);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.65, 0.53);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.65, 0.47);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.68, 0.38);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.72, 0.11);
	if (variantChance == 1)
	   rmAddTradeRouteWaypoint(tradeRouteID3, 0.75, 0.0);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID3, 0.85, 0.0);
   }
   else if (axisChance == 2) 
   {
	if (variantChance == 1)
	   rmAddTradeRouteWaypoint(tradeRouteID3, 1.0, 0.75);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID3, 1.0, 0.85);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.88, 0.72);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.62, 0.68);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.53, 0.65);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.47, 0.65);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.38, 0.68);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.12, 0.72);
	if (variantChance == 1)
	   rmAddTradeRouteWaypoint(tradeRouteID3, 0.0, 0.75);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID3, 0.0, 0.85);
   }
   rmBuildTradeRoute(tradeRouteID3, "carolinas\trade_route");

   int tradeRouteID3A = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
	if (variantChance == 1)
         rmAddTradeRouteWaypoint(tradeRouteID3A, 0.25, 1.0);
	else
         rmAddTradeRouteWaypoint(tradeRouteID3A, 0.15, 1.0);
      rmAddTradeRouteWaypoint(tradeRouteID3A, 0.28, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.32, 0.62);
      rmAddTradeRouteWaypoint(tradeRouteID3A, 0.35, 0.53);
      rmAddTradeRouteWaypoint(tradeRouteID3A, 0.35, 0.47);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.32, 0.38);
      rmAddTradeRouteWaypoint(tradeRouteID3A, 0.28, 0.12);
	if (variantChance == 1)
         rmAddTradeRouteWaypoint(tradeRouteID3A, 0.25, 0.0);
	else
         rmAddTradeRouteWaypoint(tradeRouteID3A, 0.15, 0.0);
   }
   else if (axisChance == 2) 
   {
	if (variantChance == 1)
	   rmAddTradeRouteWaypoint(tradeRouteID3A, 1.0, 0.25);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID3A, 1.0, 0.15);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.88, 0.28);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.62, 0.32);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.53, 0.35);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.47, 0.35);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.38, 0.32);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.12, 0.28);
	if (variantChance == 1)
	   rmAddTradeRouteWaypoint(tradeRouteID3A, 0.0, 0.25);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID3A, 0.0, 0.15);
   }
   rmBuildTradeRoute(tradeRouteID3A, "dirt");
}

   // Text
   rmSetStatusText("",0.35);

// Trade sockets
   int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
   rmSetObjectDefAllowOverlap(socketID, true);
   rmAddObjectDefToClass(socketID, rmClassID("importantItem"));
   rmSetObjectDefMinDistance(socketID, 0.0);
   rmSetObjectDefMaxDistance(socketID, 8.0);
   variantChance = rmRandInt(1,2);

if (trPattern == 5) // single diagonal
{
   if (socketPattern == 1)
   {
	if (variantChance == 1) // 4 sockets
	{
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID5);
      vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.09);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.21);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.79);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.91);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
	else // 5 sockets
	{
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID5);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.09);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.2);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.8);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.91);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
   }
   else if (socketPattern == 2)
   {
	if (variantChance == 1) // 3 sockets
	{	
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID5);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.16);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.84);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
	else // 3 sockets
	{	
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID5);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.2);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.8);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
   }
}
else if (trPattern == 4) //  2 side-to-side
{
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID4);
   if (socketPattern == 1) // 3 sockets per route
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.12);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.88);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   else  // 2 sockets per route
   {
	if (variantChance == 1)
	{
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.23);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.77);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
	else
	{
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.32);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.68);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
   }

   // change the trade route for the new sockets
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID4A);
   if (socketPattern == 1)  // 3 sockets per route
   {
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.88);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
  
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.12);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   else  // 2 sockets per route
   {
	if (variantChance == 1)
	{
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.23);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.77);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
	else
	{
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.68);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.32);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
   }
}
else if (trPattern == 3) //  2 parabolas
{
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID3);
   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID3, 0.17);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   if (socketPattern == 1)
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID3, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }

   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID3, 0.83);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   // change the trade route for the new sockets
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID3A);
   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID3A, 0.83);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   if (socketPattern == 1)
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID3A, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }

   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID3A, 0.17);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
}

   //Text
   rmSetStatusText("",0.40);

// Starting TCs and units 	
   int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
   rmSetObjectDefMinDistance(startingUnits, 5.0);
   rmSetObjectDefMaxDistance(startingUnits, 10.0);
   rmAddObjectDefConstraint(startingUnits, avoidAll);
   rmAddObjectDefConstraint(startingUnits, avoidWater10);

   int startingTCID= rmCreateObjectDef("startingTC");
   rmSetObjectDefMaxDistance(startingTCID, 18.0);
   rmAddObjectDefConstraint(startingTCID, avoidAll);
   rmAddObjectDefConstraint(startingTCID, avoidWater20);
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

   int startingOutpostID = rmCreateObjectDef("initial outpost wagon");
   rmAddObjectDefItem(startingOutpostID, "OutpostWagon", 2, 2.0);
   rmSetObjectDefMinDistance(startingOutpostID, 5.0);
   rmSetObjectDefMaxDistance(startingOutpostID, 10.0);
   rmAddObjectDefConstraint(startingOutpostID, avoidAll);

   int startingRussianOutpostID = rmCreateObjectDef("initial russian outpost wagon");
   rmAddObjectDefItem(startingRussianOutpostID, "OutpostWagon", 1, 0.0);
   rmSetObjectDefMinDistance(startingRussianOutpostID, 5.0);
   rmSetObjectDefMaxDistance(startingRussianOutpostID, 10.0);
   rmAddObjectDefConstraint(startingRussianOutpostID, avoidAll);

   int startingWarHutTravoisID = rmCreateObjectDef("initial war hut travois");
   rmAddObjectDefItem(startingWarHutTravoisID, "WarHutTravois", 1, 0.0);
   rmSetObjectDefMinDistance(startingWarHutTravoisID, 5.0);
   rmSetObjectDefMaxDistance(startingWarHutTravoisID, 10.0);
   rmAddObjectDefConstraint(startingWarHutTravoisID, avoidAll);

   int waterFlagID=rmCreateObjectDef("HC water flag "+i);
   rmAddObjectDefItem(waterFlagID, "HomeCityWaterSpawnFlag", 1, 0.0);
   rmAddClosestPointConstraint(playerEdgeConstraint);
   rmAddClosestPointConstraint(flagVsFlag);
   rmAddClosestPointConstraint(flagLand);

   for(i=1; <cNumberPlayers)
   {	
      rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
      rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

	if ( rmGetPlayerCiv(i) ==  rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) ==  rmGetCivID("XPSioux") ||	rmGetPlayerCiv(i) ==  rmGetCivID("XPAztec"))
	{
		rmPlaceObjectDefAtLoc(startingWarHutTravoisID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	}
	else if(rmGetPlayerCiv(i) == rmGetCivID("Russians"))
	{
		rmPlaceObjectDefAtLoc(startingRussianOutpostID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	}
	else
	{
		rmPlaceObjectDefAtLoc(startingOutpostID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	}

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

// NATIVE AMERICANS
   // Village A 
   int villageAID = -1;
   int whichNative = rmRandInt(1,2);
   int villageType = rmRandInt(1,3);

   if (nativePattern == 10)
   {
      if (whichNative == 1)
	   villageAID = rmCreateGrouping("village A", "native maya village "+villageType);
      else if (whichNative == 2)
	   villageAID = rmCreateGrouping("village A", "native miskito village "+villageType);
   }
   if (nativePattern == 11)
   {
      if (whichNative == 1)
	   villageAID = rmCreateGrouping("village A", "native miskito village "+villageType);
      else if (whichNative == 2)
	   villageAID = rmCreateGrouping("village A", "native aztec village "+villageType);
   }
   if (nativePattern == 12)
   {
      if (whichNative == 1)
	   villageAID = rmCreateGrouping("village A", "native maya village "+villageType);
      else if (whichNative == 2)
	   villageAID = rmCreateGrouping("village A", "native zapotec village "+villageType);
   }
   if (nativePattern == 13)
   {
      if (whichNative == 2)
	   villageAID = rmCreateGrouping("village A", "native miskito village "+villageType);
      else if (whichNative == 1)
	   villageAID = rmCreateGrouping("village A", "native aztec village "+villageType);
   }
   if (nativePattern == 14)
   {
      if (whichNative == 1)
	   villageAID = rmCreateGrouping("village A", "native aztec village "+villageType);
      else if (whichNative == 2)
	   villageAID = rmCreateGrouping("village A", "native miskito village "+villageType);
   }
   if (nativePattern == 15)
   {
      if (whichNative == 1)
	   villageAID = rmCreateGrouping("village A", "native zapotec village "+villageType);
      else if (whichNative == 2)
	   villageAID = rmCreateGrouping("village A", "native miskito village "+villageType);
   }
   rmAddGroupingToClass(villageAID, rmClassID("natives"));
   rmAddGroupingToClass(villageAID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageAID, 0.0);
   rmSetGroupingMaxDistance(villageAID, size*0.14);
   rmAddGroupingConstraint(villageAID, avoidImpassableLand);
   rmAddGroupingConstraint(villageAID, avoidTradeRoute);
   rmAddGroupingConstraint(villageAID, avoidWater10);
   rmAddGroupingConstraint(villageAID, avoidNativesMed);
   rmAddGroupingConstraint(villageAID, playerConstraint);

   // Village D - opposite type from A 
   int villageDID = -1;
   villageType = rmRandInt(1,5);

   if (nativePattern == 10)
   {
      if (whichNative == 2)
	   villageDID = rmCreateGrouping("village D", "native maya village "+villageType);
      else if (whichNative == 1)
	   villageDID = rmCreateGrouping("village D", "native miskito village "+villageType);
   }
   if (nativePattern == 11)
   {
      if (whichNative == 2)
	   villageDID = rmCreateGrouping("village D", "native maya village "+villageType);
      else if (whichNative == 1)
	   villageDID = rmCreateGrouping("village D", "native aztec village "+villageType);
   }
   if (nativePattern == 12)
   {
      if (whichNative == 2)
	   villageDID = rmCreateGrouping("village D", "native maya village "+villageType);
      else if (whichNative == 1)
	   villageDID = rmCreateGrouping("village D", "native zapotec village "+villageType);
   }
   if (nativePattern == 13)
   {
      if (whichNative == 2)
	   villageDID = rmCreateGrouping("village D", "native miskito village "+villageType);
      else if (whichNative == 1)
	   villageDID = rmCreateGrouping("village D", "native aztec village "+villageType);
   }
   if (nativePattern == 14)
   {
      if (whichNative == 2)
	   villageDID = rmCreateGrouping("village D", "native aztec village "+villageType);
      else if (whichNative == 1)
	   villageDID = rmCreateGrouping("village D", "native zapotec village "+villageType);
   }
   if (nativePattern == 15)
   {
      if (whichNative == 2)
	   villageDID = rmCreateGrouping("village D", "native zapotec village "+villageType);
      else if (whichNative == 1)
	   villageDID = rmCreateGrouping("village D", "native miskito village "+villageType);
   }
   rmAddGroupingToClass(villageDID, rmClassID("natives"));
   rmAddGroupingToClass(villageDID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageDID, 0.0);
   rmSetGroupingMaxDistance(villageDID, size*0.14);
   rmAddGroupingConstraint(villageDID, avoidImpassableLand);
   rmAddGroupingConstraint(villageDID, avoidTradeRoute);
   rmAddGroupingConstraint(villageDID, avoidWater10);
   rmAddGroupingConstraint(villageDID, avoidNativesMed);
   rmAddGroupingConstraint(villageDID, playerConstraint);

   // Village B - randomly same or opposite village A
   int villageBID = -1;	
   villageType = rmRandInt(1,5);
   whichNative = rmRandInt(1,2);

   if (nativePattern == 10)
   {
      if (whichNative == 1)
	   villageBID = rmCreateGrouping("village B", "native maya village "+villageType);
      else if (whichNative == 2)
	   villageBID = rmCreateGrouping("village B", "native miskito village "+villageType);
   }
   if (nativePattern == 11)
   {
      if (whichNative == 1)
	   villageBID = rmCreateGrouping("village B", "native maya village "+villageType);
      else if (whichNative == 2)
	   villageBID = rmCreateGrouping("village B", "native aztec village "+villageType);
   }
   if (nativePattern == 12)
   {
      if (whichNative == 1)
	   villageBID = rmCreateGrouping("village B", "native maya village "+villageType);
      else if (whichNative == 2)
	   villageBID = rmCreateGrouping("village B", "native zapotec village "+villageType);
   }
   if (nativePattern == 13)
   {
      if (whichNative == 2)
	   villageBID = rmCreateGrouping("village B", "native miskito village "+villageType);
      else if (whichNative == 1)
	   villageBID = rmCreateGrouping("village B", "native aztec village "+villageType);
   }
   if (nativePattern == 14)
   {
      if (whichNative == 1)
	   villageBID = rmCreateGrouping("village B", "native aztec village "+villageType);
      else if (whichNative == 2)
	   villageBID = rmCreateGrouping("village B", "native zapotec village "+villageType);
   }
   if (nativePattern == 15)
   {
      if (whichNative == 1)
	   villageBID = rmCreateGrouping("village B", "native zapotec village "+villageType);
      else if (whichNative == 2)
	   villageBID = rmCreateGrouping("village B", "native miskito village "+villageType);
   }
   rmAddGroupingToClass(villageBID, rmClassID("importantItem"));
   rmAddGroupingToClass(villageBID, rmClassID("natives"));
   rmSetGroupingMinDistance(villageBID, 0.0);
   rmSetGroupingMaxDistance(villageBID, size*0.14);
   rmAddGroupingConstraint(villageBID, avoidImpassableLand);
   rmAddGroupingConstraint(villageBID, avoidTradeRoute);
   rmAddGroupingConstraint(villageBID, avoidWater15);
   rmAddGroupingConstraint(villageBID, avoidNatives);
   rmAddGroupingConstraint(villageBID, playerConstraint);

   // Village C // appears in center, variable, randomly same or opposite A and B
   int villageCID = -1;	
   villageType = rmRandInt(1,5);
   whichNative = rmRandInt(1,2);

   if (nativePattern == 10)
   {
      if (whichNative == 1)
	   villageCID = rmCreateGrouping("village C", "native maya village "+villageType);
      else if (whichNative == 2)
	   villageCID = rmCreateGrouping("village C", "native miskito village "+villageType);
   }
   if (nativePattern == 11)
   {
      if (whichNative == 1)
	   villageCID = rmCreateGrouping("village C", "native maya village "+villageType);
      else if (whichNative == 2)
	   villageCID = rmCreateGrouping("village C", "native aztec village "+villageType);
   }
   if (nativePattern == 12)
   {
      if (whichNative == 1)
	   villageCID = rmCreateGrouping("village C", "native maya village "+villageType);
      else if (whichNative == 2)
	   villageCID = rmCreateGrouping("village C", "native zapotec village "+villageType);
   }
   if (nativePattern == 13)
   {
      if (whichNative == 2)
	   villageCID = rmCreateGrouping("village C", "native miskito village "+villageType);
      else if (whichNative == 1)
	   villageCID = rmCreateGrouping("village C", "native aztec village "+villageType);
   }
   if (nativePattern == 14)
   {
      if (whichNative == 1)
	   villageCID = rmCreateGrouping("village C", "native aztec village "+villageType);
      else if (whichNative == 2)
	   villageCID = rmCreateGrouping("village C", "native zapotec village "+villageType);
   }
   if (nativePattern == 15)
   {
      if (whichNative == 1)
	   villageCID = rmCreateGrouping("village C", "native zapotec village "+villageType);
      else if (whichNative == 2)
	   villageCID = rmCreateGrouping("village C", "native miskito village "+villageType);
   }
   rmAddGroupingToClass(villageCID, rmClassID("importantItem"));
   rmAddGroupingToClass(villageCID, rmClassID("natives"));
   rmSetGroupingMinDistance(villageCID, 0.0);
   rmSetGroupingMaxDistance(villageCID, size*0.14);
   rmAddGroupingConstraint(villageCID, avoidImpassableLand);
   rmAddGroupingConstraint(villageCID, avoidWater10);
   rmAddGroupingConstraint(villageCID, avoidTradeRoute);
   rmAddGroupingConstraint(villageCID, avoidNatives);
   rmAddGroupingConstraint(villageCID, playerConstraint);

// Placement of Native Americans
   if ((nativeSetup == 13) || (nativeSetup == 17))  
   {
      if (axisChance == 2)
	{
  	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageAID, 0, 0.79, 0.36);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.21, 0.36);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.79, 0.64);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.21, 0.64);
		   if (nativeSetup == 17)
		   {	
			rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.4);
			rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.6);
		   }
  
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageAID, 0, 0.67, 0.4);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.33, 0.4);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.67, 0.6);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.33, 0.6);
		   if (nativeSetup == 17)
		   {	
			rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.34);
			rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.66);
		   }
	      }
      }
	else if (axisChance == 1)
	{
	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageAID, 0, 0.4, 0.79);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.4, 0.21);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.6, 0.79);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.6, 0.21);
		   if (nativeSetup == 17)
		   {	
			rmPlaceGroupingAtLoc(villageDID, 0, 0.33, 0.5);
			rmPlaceGroupingAtLoc(villageDID, 0, 0.67, 0.5);
		   }
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageAID, 0, 0.37, 0.71);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.37, 0.29);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.63, 0.71);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.63, 0.29);
		   if (nativeSetup == 17)
		   {	
			rmPlaceGroupingAtLoc(villageDID, 0, 0.4, 0.5);
			rmPlaceGroupingAtLoc(villageDID, 0, 0.6, 0.5);
		   }
	      }	   
	}
   } 
   else if (nativeSetup == 14)
   {
      if (axisChance == 2)
	{
  	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageAID, 0, 0.79, 0.38);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.21, 0.38);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.79, 0.62);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.21, 0.62);
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageAID, 0, 0.67, 0.4);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.33, 0.4);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.67, 0.6);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.33, 0.6);
	      }
      }
	else if (axisChance == 1)
	{
	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageDID, 0, 0.4, 0.79);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.4, 0.21);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.6, 0.79);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.6, 0.21);
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageDID, 0, 0.38, 0.71);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.38, 0.29);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.62, 0.71);
		   rmPlaceGroupingAtLoc(villageDID, 0, 0.62, 0.29);
	      }
	}
   } 
   else if (nativeSetup > 14) // 15 AND 16
   {
	if (nativeSetup == 15)
	{
	   if (axisChance == 1)
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.4, 0.51);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.6, 0.49);

         }
   	   else
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.51, 0.6);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.49, 0.4);
	   }
	}
	rmAddGroupingConstraint(villageAID, avoidWater20);
	rmAddGroupingConstraint(villageDID, avoidWater20);
      if (axisChance == 2)
	{
  	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageAID, 0, 0.85, 0.135);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.15, 0.135);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.15, 0.865);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.85, 0.865);
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageAID, 0, 0.85, 0.135);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.15, 0.135);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.15, 0.865);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.85, 0.865);
	      }
      }
	else if (axisChance == 1)
	{
	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageDID, 0, 0.135, 0.85);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.135, 0.15);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.865, 0.15);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.865, 0.85);
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageAID, 0, 0.135, 0.85);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.135, 0.15);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.865, 0.15);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.865, 0.85);
	      }
	}
   } 
   else if (nativeSetup < 4)
   {
      if (axisChance == 1)
	{
	   if (endPosition == 1)
            rmPlaceGroupingAtLoc(villageAID, 0, 0.505, 0.73);
	   else if (endPosition == 2)
            rmPlaceGroupingAtLoc(villageAID, 0, 0.495, 0.82);
	   else
            rmPlaceGroupingAtLoc(villageAID, 0, 0.505, 0.91);
	}	 
      else
	{
	   if (endPosition == 1)
            rmPlaceGroupingAtLoc(villageAID, 0, 0.73, 0.505);
	   else if (endPosition == 2)
            rmPlaceGroupingAtLoc(villageAID, 0, 0.82, 0.495);
	   else
            rmPlaceGroupingAtLoc(villageAID, 0, 0.91, 0.505);
	}
         
      if (axisChance == 1)
	{
	   if (endPosition == 1)
            rmPlaceGroupingAtLoc(villageBID, 0, 0.495, 0.27);
	   else if (endPosition == 2)
            rmPlaceGroupingAtLoc(villageBID, 0, 0.505, 0.18);
	   else
            rmPlaceGroupingAtLoc(villageBID, 0, 0.495, 0.10);
	}
      else
	{
	   if (endPosition == 1)
            rmPlaceGroupingAtLoc(villageBID, 0, 0.27, 0.495);
	   else if (endPosition == 2)
            rmPlaceGroupingAtLoc(villageBID, 0, 0.18, 0.505);
	   else
            rmPlaceGroupingAtLoc(villageBID, 0, 0.10, 0.495);
	}
	if (nativeSetup < 2)
	{
         if (nativeNumber > 2)
            rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.5);
	}
	else 
	{
	   rmSetGroupingMaxDistance(villageCID, size*0.1);
         if (nativeNumber > 2)
	   {
		if (axisChance == 1)
		{
               rmPlaceGroupingAtLoc(villageCID, 0, 0.465, 0.5);
               rmPlaceGroupingAtLoc(villageCID, 0, 0.535, 0.5);
	      }
		else
		{
               rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.535);
               rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.465);
	      }
	   }
	}
   }
   else if (nativeSetup > 5)
   {
	if (nativeSetup == 7)
	{
         if (axisChance == 1)
	   {
	      if (endPosition == 1)
               rmPlaceGroupingAtLoc(villageDID, 0, 0.495, 0.75); 
	      else if (endPosition == 2)
               rmPlaceGroupingAtLoc(villageDID, 0, 0.505, 0.84); 
	      else
               rmPlaceGroupingAtLoc(villageDID, 0, 0.495, 0.93); 
	   }
         else
	   {
	      if (endPosition == 1)
               rmPlaceGroupingAtLoc(villageDID, 0, 0.75, 0.495);
	      else if (endPosition == 2)
               rmPlaceGroupingAtLoc(villageDID, 0, 0.84, 0.505);
	      else
              rmPlaceGroupingAtLoc(villageDID, 0, 0.93, 0.495);
	   }
            
         if (axisChance == 1)
	   {
	      if (endPosition == 1)
               rmPlaceGroupingAtLoc(villageDID, 0, 0.505, 0.25);
	      else if (endPosition == 2)
               rmPlaceGroupingAtLoc(villageDID, 0, 0.495, 0.16);
	      else
               rmPlaceGroupingAtLoc(villageDID, 0, 0.505, 0.08);
	   }            
         else
	   {
	      if (endPosition == 1)
               rmPlaceGroupingAtLoc(villageDID, 0, 0.25, 0.505);
	      else if (endPosition == 2)
               rmPlaceGroupingAtLoc(villageDID, 0, 0.16, 0.495);
	      else
               rmPlaceGroupingAtLoc(villageDID, 0, 0.08, 0.505);
	   }          
	}
	if (nativeSetup == 8)
	{
   	      rmSetGroupingMaxDistance(villageDID, size*0.1);
		if (axisChance == 1)
		{
               rmPlaceGroupingAtLoc(villageDID, 0, 0.465, 0.49);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.535, 0.51);
	      }
		else
		{
               rmPlaceGroupingAtLoc(villageDID, 0, 0.49, 0.535);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.51, 0.465);
	      }
	}
	if (nativeSetup == 11)
	{
		if (axisChance == 1)
		{
               rmPlaceGroupingAtLoc(villageBID, 0, 0.39, 0.5);
               rmPlaceGroupingAtLoc(villageBID, 0, 0.61, 0.5);
	      }
		else
		{
               rmPlaceGroupingAtLoc(villageBID, 0, 0.5, 0.39);
               rmPlaceGroupingAtLoc(villageBID, 0, 0.5, 0.61);
	      }
	}
	if (nativeSetup == 12)
	{
         if (axisChance == 2)
   	   {
  	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageDID, 0, 0.79, 0.38);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.21, 0.38);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.79, 0.62);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.21, 0.62);
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageDID, 0, 0.67, 0.4);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.33, 0.4);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.67, 0.6);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.33, 0.6);
	      }
         }
	   else if (axisChance == 1)
	   {
	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageDID, 0, 0.4, 0.79);
		   rmPlaceGroupingAtLoc(villageDID, 0, 0.4, 0.21);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.6, 0.79);
		   rmPlaceGroupingAtLoc(villageDID, 0, 0.6, 0.21);
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageDID, 0, 0.38, 0.71);
		   rmPlaceGroupingAtLoc(villageDID, 0, 0.38, 0.29);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.62, 0.71);
		   rmPlaceGroupingAtLoc(villageDID, 0, 0.62, 0.29);
	      }
	   }
	}
      for(i=1; <cNumberPlayers) 
      {
         rmSetGroupingMinDistance(villageAID, 65.0);
         rmSetGroupingMaxDistance(villageAID, 90.0);           
	   rmPlaceGroupingAtLoc(villageAID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	   if (nativeSetup == 9)
	   {
            rmSetGroupingMinDistance(villageDID, 65.0);
            rmSetGroupingMaxDistance(villageDID, 90.0);      
		rmPlaceGroupingAtLoc(villageDID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	   }
	   if (nativeSetup == 10)
		rmPlaceGroupingAtLoc(villageAID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
      }
   }
   else if (nativeSetup > 3) // setup 4 and 5
   {
      if (axisChance == 1)
	{
	   if (endPosition == 1)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.52, 0.75);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.48, 0.25);
	   }
	   else if (endPosition == 2)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.48, 0.84);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.52, 0.16);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.52, 0.93);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.48, 0.08);
	   }
	}          
      else
	{
	   if (endPosition == 1)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.75, 0.52);
	      rmPlaceGroupingAtLoc(villageAID, 0, 0.25, 0.48);
	   }
	   else if (endPosition == 2)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.84, 0.52);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.16, 0.48);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.93, 0.48);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.08, 0.52);
	   }
	}       
         
	if (nativeSetup == 4)
	{
	   if (axisChance == 1)
	   {

            rmPlaceGroupingAtLoc(villageDID, 0, 0.415, 0.5);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.585, 0.5);
         }
   	   else
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.51, 0.585);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.49, 0.415);
	   }
	}
	if (nativeSetup == 5)
	{	
   	   rmSetGroupingMaxDistance(villageDID, size*0.1);
         if (axisChance == 1)
	   {
            if (sidePosition == 1)
	      {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.7, 0.5);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.3, 0.5);
	      }
	      else if (sidePosition == 2)
	      {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.74, 0.5);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.26, 0.5);
	      }
	      else
	      {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.78, 0.5);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.22, 0.5);
		}
         }
	   else
	   {
            if (endPosition == 1)
	      {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.7);
		rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.3);
	      }	   
	      else if (endPosition == 2)
	      {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.74);
		rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.26);
	      }
	      else
	      {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.78);
		rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.22); 
            }
	   }
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
   int numCliffs = cNumberNonGaiaPlayers + rmRandInt(4,7);
   for (i=0; <numCliffs)
   {
	cliffHt = rmRandInt(5,7);    
	int bigCliffID=rmCreateArea("big cliff" +i);
	rmSetAreaWarnFailure(bigCliffID, false);
	rmSetAreaCliffType(bigCliffID, cliffType);
	rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
	if (cliffVariety == 1) // like Patagonia
	{
         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(450), rmAreaTilesToFraction(700));
     	   rmSetAreaCliffEdge(bigCliffID, 2, 0.35, 0.1, 1.0, 0);
     	   rmSetAreaCliffPainting(bigCliffID, false, true, true, 1.5, true);
	   rmSetAreaCliffHeight(bigCliffID, 7, 2.0, 0.5);
	   rmSetAreaCoherence(bigCliffID, 0.5);
	   rmSetAreaSmoothDistance(bigCliffID, rmRandInt(5,10));
	   rmSetAreaHeightBlend(bigCliffID, 1.0);
	   rmSetAreaMinBlobs(bigCliffID, 4);
  	   rmSetAreaMaxBlobs(bigCliffID, 6);
	   rmSetAreaMinBlobDistance(bigCliffID, 10.0);
	   rmSetAreaMaxBlobDistance(bigCliffID, 18.0);
	}
	else if (cliffVariety == 2) // smaller, kinda like in Sudden Death from AOM
	{
         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(280), rmAreaTilesToFraction(400));
	   rmSetAreaCliffEdge(bigCliffID, 1, 0.6, 0.1, 1.0, 0);
	   rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
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
         rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
         rmSetAreaCliffHeight(bigCliffID, cliffHt, 2.0, 1.0);
         rmSetAreaCoherence(bigCliffID, rmRandFloat(0.4, 0.9));
         rmSetAreaSmoothDistance(bigCliffID, 15);
         rmSetAreaHeightBlend(bigCliffID, 1.0);
         rmSetAreaMinBlobs(bigCliffID, 3);
         rmSetAreaMaxBlobs(bigCliffID, 5);
         rmSetAreaMinBlobDistance(bigCliffID, 10.0);
         rmSetAreaMaxBlobDistance(bigCliffID, 18.0);
      }
      rmAddAreaConstraint(bigCliffID, avoidStartingUnitsLong);
      rmAddAreaConstraint(bigCliffID, longPlayerConstraint);
	rmAddAreaConstraint(bigCliffID, avoidImportantItem);
	rmAddAreaConstraint(bigCliffID, avoidTradeRoute);
      rmAddAreaConstraint(bigCliffID, avoidNatives);
      rmAddAreaConstraint(bigCliffID, avoidWater20);
      rmAddAreaConstraint(bigCliffID, cliffsAvoidCliffs);
      rmAddAreaConstraint(bigCliffID, avoidSocket);
	rmBuildArea(bigCliffID);
   }

   // Text
   rmSetStatusText("",0.60);

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
   rmAddObjectDefConstraint(nugget4, avoidAll);
   rmPlaceObjectDefPerPlayer(nugget4, false, 1);
   rmPlaceObjectDefInArea(nugget4, 0, rmAreaID("barrier center single"), 1);
   rmSetNuggetDifficulty(3, 3);
   rmPlaceObjectDefInArea(nugget4, 0, rmAreaID("barrier center single"), 1);
   rmSetNuggetDifficulty(2, 2);
   rmPlaceObjectDefInArea(nugget4, 0, rmAreaID("barrier center single"), 2);

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

   // berry bushes
   int berryNum = rmRandInt(2,5);
   int StartBerryBushID=rmCreateObjectDef("starting berry bush");
   rmAddObjectDefItem(StartBerryBushID, "BerryBush", rmRandInt(2,5), 4.0);
   rmSetObjectDefMinDistance(StartBerryBushID, 10.0);
   rmSetObjectDefMaxDistance(StartBerryBushID, 16.0);
   rmAddObjectDefConstraint(StartBerryBushID, avoidStartingUnitsSmall);
   rmPlaceObjectDefPerPlayer(StartBerryBushID, false, 2);

   rmSetObjectDefMinDistance(StartBerryBushID, 60.0);
   rmSetObjectDefMaxDistance(StartBerryBushID, 70.0);
   rmPlaceObjectDefPerPlayer(StartBerryBushID, false, 1);
   rmSetObjectDefMinDistance(StartBerryBushID, 75.0);
   rmSetObjectDefMaxDistance(StartBerryBushID, 85.0);
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
   rmPlaceObjectDefPerPlayer(startPronghornID, false, 1);

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
      rmPlaceObjectDefPerPlayer(farPronghornID, false, 2);
   else
      rmPlaceObjectDefPerPlayer(farPronghornID, false, 1);

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
      rmPlaceObjectDefInArea(extraTreesID, 0, rmAreaID("player"+i), 2);

   int extraTrees2ID=rmCreateObjectDef("more extra trees");
   rmAddObjectDefItem(extraTrees2ID, treeType, 5, 6.0);
   rmSetObjectDefMinDistance(extraTrees2ID, 18);
   rmSetObjectDefMaxDistance(extraTrees2ID, 28);
   rmAddObjectDefConstraint(extraTrees2ID, avoidAll);
   rmAddObjectDefConstraint(extraTrees2ID, avoidCoin);
   rmAddObjectDefConstraint(extraTrees2ID, avoidSocket);
   rmAddObjectDefConstraint(extraTrees2ID, avoidTradeRoute);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(extraTrees2ID, 0, rmAreaID("player"+i), 2);

// Central forests for highlands, valley
   int numTries=5*cNumberNonGaiaPlayers;
   for (i=0; <numTries)
   { 
      int forestPatchID = rmCreateArea("forest patch"+i, rmAreaID("barrier center single"));
      rmAddAreaToClass(forestPatchID, rmClassID("classForest"));
      rmSetAreaWarnFailure(forestPatchID, false);
      rmSetAreaSize(forestPatchID, rmAreaTilesToFraction(80), rmAreaTilesToFraction(150));
      rmSetAreaCoherence(forestPatchID, 0.6);
 	rmSetAreaForestType(forestPatchID, forestType);
      rmSetAreaForestDensity(forestPatchID, 0.6);
      rmSetAreaForestClumpiness(forestPatchID, 0.9);
      rmSetAreaForestUnderbrush(forestPatchID, 0.2);
      rmSetAreaCoherence(forestPatchID, 0.4);
      rmSetAreaSmoothDistance(forestPatchID, 10);
      rmAddAreaConstraint(forestPatchID, avoidAll);
      rmAddAreaConstraint(forestPatchID, avoidTradeRoute);
      rmAddAreaConstraint(forestPatchID, avoidSocket);
      rmAddAreaConstraint(forestPatchID, avoidNativesShort);
      rmBuildArea(forestPatchID);
   }

// Clearings
   for (i=0; <cNumberNonGaiaPlayers*3)   
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
   numTries=17*cNumberNonGaiaPlayers;
   if (cNumberNonGaiaPlayers > 3)
      numTries=15*cNumberNonGaiaPlayers;  
   if (cNumberNonGaiaPlayers > 5)
      numTries=12*cNumberNonGaiaPlayers;  
   if (cNumberNonGaiaPlayers > 7)
      numTries=10*cNumberNonGaiaPlayers;    


   failCount=0;
   for (i=0; <numTries)
   {
      forestChance = rmRandInt(1,4);
      int forest=rmCreateArea("forest "+i);
      rmSetAreaWarnFailure(forest, false);
      rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(300));
      rmSetAreaForestType(forest, forestType);
      rmSetAreaForestDensity(forest, rmRandFloat(0.7, 1.0));
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
		rmSetAreaSmoothDistance(forest, 120);
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
	rmAddAreaConstraint(forest, avoidClearing);
      if (rmRandInt(1,3) > 1)
         rmSetAreaBaseHeight(forest, rmRandFloat(2.5, 3.5));
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
   rmSetObjectDefMaxDistance(extraGoldID, 90.0);
   rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.5, rmRandInt(1,2));
   if (axisChance == 1)
   {
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.78, 1);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.22, 1);
   }
   else
   {
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.78, 0.5, 1);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.22, 0.5, 1);
   }
   rmPlaceObjectDefInArea(extraGoldID, 0, rmAreaID("barrier center single"), 2);
   if (cNumberNonGaiaPlayers > 4)
      rmPlaceObjectDefInArea(extraGoldID, 0, rmAreaID("barrier center single"), 3);

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
   rmPlaceObjectDefPerPlayer(GoldFarID, false, 1);

// sheep etc
   int sheepID=rmCreateObjectDef("herdable animal");
   rmAddObjectDefItem(sheepID, sheepType, 2, 4.0);
   rmAddObjectDefToClass(sheepID, rmClassID("herdableFood"));
   rmSetObjectDefMinDistance(sheepID, 40.0);
   rmSetObjectDefMaxDistance(sheepID, 0.22*longSide);
   rmAddObjectDefConstraint(sheepID, avoidSheep);
   rmAddObjectDefConstraint(sheepID, avoidAll);
   rmAddObjectDefConstraint(sheepID, playerConstraint);
   rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
   rmPlaceObjectDefPerPlayer(sheepID, false, 2);
   rmPlaceObjectDefInArea(sheepID, 0, rmAreaID("barrier center single"), cNumberNonGaiaPlayers*2);

   // Text
   rmSetStatusText("",0.85);

// Central herds
   int centralHerdID=rmCreateObjectDef("central herd");  
   rmAddObjectDefItem(centralHerdID, centerHerdType, rmRandInt(7,9), 6.0);
   rmAddObjectDefToClass(centralHerdID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(centralHerdID, 0.05*size);
   rmSetObjectDefMaxDistance(centralHerdID, 0.15*size);
   rmAddObjectDefConstraint(centralHerdID, avoidTradeRoute);
   rmAddObjectDefConstraint(centralHerdID, avoidImportantItem);
   rmAddObjectDefConstraint(centralHerdID, avoidWater10);
   rmAddObjectDefConstraint(centralHerdID, farPlayerConstraint);
   rmAddObjectDefConstraint(centralHerdID, longHuntableConstraint);
   rmSetObjectDefCreateHerd(centralHerdID, true);
   rmPlaceObjectDefAtLoc(centralHerdID, 0, 0.5, 0.5, 2);
   // additional of central herd type
   rmAddObjectDefConstraint(centralHerdID, fartherPlayerConstraint);
   rmSetObjectDefMinDistance(centralHerdID, 0.15*size);
   rmSetObjectDefMaxDistance(centralHerdID, 0.3*size);
   rmPlaceObjectDefPerPlayer(centralHerdID, false, 1);

// far huntable
   int farHuntableID=rmCreateObjectDef("far huntable");
   rmAddObjectDefItem(farHuntableID, deerType, rmRandInt(5,9), 6.0);
   rmAddObjectDefToClass(farHuntableID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(farHuntableID, 0.2*size);
   rmSetObjectDefMaxDistance(farHuntableID, 0.3*size);
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
   rmAddObjectDefConstraint(StragglerTreeID, avoidCoin);
   rmAddObjectDefConstraint(StragglerTreeID, patchConstraint);
   rmAddObjectDefConstraint(StragglerTreeID, avoidWater10);
   rmSetObjectDefMinDistance(StragglerTreeID, 10.0);
   rmSetObjectDefMaxDistance(StragglerTreeID, rmXFractionToMeters(0.5));
   for(i=0; <cNumberNonGaiaPlayers*18)
      rmPlaceObjectDefAtLoc(StragglerTreeID, 0, 0.5, 0.5);

   // Text
   rmSetStatusText("",0.95);

// Fish
   int fishNum = cNumberNonGaiaPlayers * rmRandInt(5,6);
   if (cNumberNonGaiaPlayers > 3)
	fishNum = cNumberNonGaiaPlayers * rmRandInt(4,5);
   int fishID=rmCreateObjectDef("fish");
   int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 22.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
   rmAddObjectDefItem(fishID, fishType, 1, 5.0);
   rmAddObjectDefConstraint(fishID, fishVsFishID);
   rmAddObjectDefConstraint(fishID, fishLand);
   for(i=0; <fishNum)
   { 
      rmPlaceObjectDefInArea(fishID, 0, rmAreaID("first sea"), rmRandInt(1,2));
      rmPlaceObjectDefInArea(fishID, 0, rmAreaID("second sea"), rmRandInt(1,2));
   }

   fishNum = cNumberNonGaiaPlayers * 4;
   int fish2ID=rmCreateObjectDef("second fish");
   rmAddObjectDefItem(fish2ID, fish2Type, 1, 5.0);
   rmAddObjectDefConstraint(fish2ID, fishVsFishID);
   rmAddObjectDefConstraint(fish2ID, fishLand);
   for(i=0; <fishNum)
   { 
      rmPlaceObjectDefInArea(fish2ID, 0, rmAreaID("first sea"), 1);
      rmPlaceObjectDefInArea(fish2ID, 0, rmAreaID("second sea"), 1);
   }

// Whales
   int whaleNum = cNumberNonGaiaPlayers + rmRandInt(1,3);
   int whaleID=rmCreateObjectDef("whale");
   int whaleLand = rmCreateTerrainDistanceConstraint("whale v. land", "land", true, 18.0);
   int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", whaleType, 40.0);
   rmAddObjectDefItem(whaleID, whaleType, 1, 5.0);
   rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
   rmAddObjectDefConstraint(whaleID, whaleLand);
   rmAddObjectDefConstraint(whaleID, centerConstraintFar);
   rmPlaceObjectDefInArea(whaleID, 0, rmAreaID("first sea"), whaleNum);
   rmPlaceObjectDefInArea(whaleID, 0, rmAreaID("second sea"), whaleNum);

   // Text
   rmSetStatusText("",0.99);

  // King of the Hill (added 2026-11 for WoL): the middle of all start positions (the map centre), on open land
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

  
