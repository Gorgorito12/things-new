// New Congo
// modified from praires by RF_Gandalf

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
   string fishType = "";

// Set up for natives to appear on the map
    string aur_type = "tribal";
    int resourcesarray = xsArrayCreateString(15, "", "");

    xsArraySetString(resourcesarray, 1, "cattle");
    xsArraySetString(resourcesarray, 2, "cocoa");
    xsArraySetString(resourcesarray, 3, "diamonds");
    xsArraySetString(resourcesarray, 4, "timber");
    xsArraySetString(resourcesarray, 5, "gems");
    xsArraySetString(resourcesarray, 6, "gold");
    xsArraySetString(resourcesarray, 7, "manioc");
    xsArraySetString(resourcesarray, 8, "palmoil");
    xsArraySetString(resourcesarray, 9, "rubber");
    xsArraySetString(resourcesarray, 10, "slaves");
    xsArraySetString(resourcesarray, 11, "figurines");
    xsArraySetString(resourcesarray, 12, "textiles");
    xsArraySetString(resourcesarray, 13, "treasures");
    xsArraySetString(resourcesarray, 14, "vanilla");

    rmAllocateSubCivs(6);

    string subCiv0Name = "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 14));
    int subCiv0 = rmGetCivID(subCiv0Name);
    rmSetSubCiv(0, subCiv0Name); 

    string subCiv1Name = "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 14));
    int subCiv1 = rmGetCivID(subCiv1Name);
    rmSetSubCiv(1, subCiv1Name); 

    string subCiv2Name = "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 14));
    int subCiv2 = rmGetCivID(subCiv2Name);
    rmSetSubCiv(2, subCiv2Name); 

    string subCiv3Name = "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 14));
    int subCiv3 = rmGetCivID(subCiv3Name);
    rmSetSubCiv(3, subCiv3Name); 

// Pick pattern for trees, terrain, features, etc.
   int patternChance = rmRandInt(9,10);   
   int variantChance = rmRandInt(1,6);
//   int lightingChance = rmRandInt(1,18);
   int axisChance = rmRandInt(1,2);
   int playerSide = rmRandInt(1,2);   
   int positionChance = rmRandInt(1,2);   
   int distChance = rmRandInt(0,9);
   int sectionChance = rmRandInt(1,3);
   int ffaChance = rmRandInt(1,4);
   int trPattern = -1;
   int trPicker = rmRandInt(1,7);
   if (trPicker == 1)
	trPattern = 0;
   if (trPicker == 2)
	trPattern = 1;
   if (trPicker == 3)
	trPattern = 4;
   if (trPicker == 4)
	trPattern = 5;
   if (trPicker == 5)
	trPattern = 6;
   if (trPicker == 6)
	trPattern = 8;
   if (trPicker == 7)
	trPattern = 9;
   int randomChance = rmRandInt(1,2);
   int socketPattern = rmRandInt(1,2);   
   int nativeSetup = rmRandInt(0,14);
   if (cNumberNonGaiaPlayers > 5)
   {
	if (nativeSetup == 10)
	{
	   if (rmRandInt(1,4) == 4)
		nativeSetup = rmRandInt(12,15);
	   else
            nativeSetup = rmRandInt(0,9);
	}
	if (nativeSetup == 11)
	{
	   if (rmRandInt(1,4) == 4)
		nativeSetup = rmRandInt(12,15);
	   else
            nativeSetup = rmRandInt(0,9);
	}
   }
   int nativePattern = -1;
   int nativeNumber = rmRandInt(1,6);
   if (cNumberNonGaiaPlayers < 4)
	nativeNumber = 1;
   int endPosition = rmRandInt(1,3);
   int sidePosition = rmRandInt(1,3);
   int sheepChance = rmRandInt(1,2);
   int featureChance = rmRandInt(1,10);
   int cliffChance = rmRandInt(1,10);
   int makeCliffs = -1; 
   int cliffVariety = rmRandInt(0,6);
   int makePonds = -1;
   int makeCentralHighlands = -1;
   int makeCentralCanyon = -1;
   int baseHt = -1;
   int forestDist = rmRandInt(13,19);
   if (cNumberNonGaiaPlayers < 4)
	forestDist = rmRandInt(5,8);

// Picks the map size
   int playerTiles=14000;   // size = 324 for 2
   if (cNumberNonGaiaPlayers > 7)
	playerTiles = 11000;  // size = 593 for 8
   else if (cNumberNonGaiaPlayers > 5) 
	playerTiles = 12000;  // size = 536 for 6
   else if (cNumberNonGaiaPlayers > 3)
	playerTiles = 14200;  // size = 460 for 4
   else if (cNumberNonGaiaPlayers == 3)   
	playerTiles = 15000;  // size = 424 for 3 pl

   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

// Elevation
   rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.7, 5.0);
   rmSetMapElevationHeightBlend(1.0);
   rmSetSeaLevel(2.0);
	
   // Text
   rmSetStatusText("",0.05);

// Pick terrain patterns and features 

	rmSetLightingSet("yellow_river");

   makePonds = rmRandInt(1,10);
   if (featureChance == 10)
      makePonds = 1;
   else if (featureChance == 1)
   {
      makeCentralCanyon = 1;
      nativeNumber = 1;
   }
   else if (featureChance == 2)
   {
      makeCentralHighlands = 1;
      nativeNumber = 1;
   }
	rmSetMapType("AFRICANjungle");
	rmSetMapType("rainclouds");
	rmSetMapType("land");
   forestType = "AfricanRainForest";
   cliffType = "Araucania Central";
   pondType = "Congo River";
   treeType = "TreeAmazon";
   baseHt = 1;
   if (sheepChance == 1)
      sheepType = "WildCrocodile";
   else
      sheepType = "WildCrocodile";
   fishType = "FishBass";
   if (patternChance == 9) //
   {
      baseType = "rainforest"; 

      if (variantChance == 1)
	{
         deerType = "Antelope";
         deer2Type = "ypWildElephant";
         centerHerdType = "Okapi";
	}
      if (variantChance == 2)
	{
         deerType = "Okapi";
         deer2Type = "ypWildElephant";
         centerHerdType = "Antelope";
	}
      if (variantChance == 3)
	{
         deerType = "Okapi";
         deer2Type = "ypWildElephant";
         centerHerdType = "Okapi";
	}
      if (variantChance == 4)
	{
         deerType = "Antelope";
         deer2Type = "Hippo";
         centerHerdType = "Okapi"; 
	}
      if (variantChance == 5)
	{
         deerType = "Okapi";
         deer2Type = "Hippo";
         centerHerdType = "Antelope"; 
	}
      else 
	{     
         deerType = "Okapi";
         deer2Type = "Hippo";
         centerHerdType = "Okapi"; 
	}
	if (cliffChance > 6)
         makeCliffs = 1;
	else if (cliffChance == 1)
	   makePonds = 1;
   }
   else if (patternChance == 10) // great plains 2, yellow
   {      
      baseType = "rainforest";
      if (variantChance == 1)
	{
         deerType = "Antelope";
         deer2Type = "ypWildElephant";
         centerHerdType = "Okapi";
	}
      if (variantChance == 2)
	{
         deerType = "Okapi";
         deer2Type = "ypWildElephant";
         centerHerdType = "Antelope";
	}
      if (variantChance == 3)
	{
         deerType = "Okapi";
         deer2Type = "ypWildElephant";
         centerHerdType = "Okapi";
	}
      if (variantChance == 4)
	{
         deerType = "Antelope";
         deer2Type = "Hippo";
         centerHerdType = "Okapi"; 
	}
      if (variantChance == 5)
	{
         deerType = "Okapi";
         deer2Type = "Hippo";
         centerHerdType = "Antelope"; 
	}
      else 
	{     
         deerType = "Okapi";
         deer2Type = "Hippo";
         centerHerdType = "Okapi"; 
	}
	if (cliffChance > 5)
         makeCliffs = 1;
   }
   rmSetBaseTerrainMix(baseType);
   rmTerrainInitialize("yukon\ground1_yuk", 1);
   rmEnableLocalWater(false);
   rmSetMapType("land");

   rmSetWorldCircleConstraint(true);
   rmSetWindMagnitude(2.0);
  
   chooseMercs();
	wotta_triggers();

// Define some classes.
   int classPlayer=rmDefineClass("player");
   int lakeClass=rmDefineClass("lake");
   rmDefineClass("classPatch");
   rmDefineClass("starting settlement");
   rmDefineClass("startingUnit");
   rmDefineClass("classForest");
   rmDefineClass("importantItem");
   rmDefineClass("natives");
   rmDefineClass("classCliff");
   rmDefineClass("classCliff2");
   int canyon=rmDefineClass("canyon");
   rmDefineClass("center");
   rmDefineClass("classNugget");
   rmDefineClass("socketClass");
   int classHuntable=rmDefineClass("huntableFood");   
   int classHerdable=rmDefineClass("herdableFood"); 
   int classProp=rmDefineClass("propClass");

   // Text
   rmSetStatusText("",0.10);

// -------------Define constraints
   // Map edge constraints
   int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
   int secondEdgeConstraint=rmCreateBoxConstraint("bison edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
   int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
   int circleConstraintMt=rmCreatePieConstraint("circle Constraint for mts", 0.5, 0.5, 0, rmZFractionToMeters(0.395), rmDegreesToRadians(0), rmDegreesToRadians(360));
   int circleConstraintMt2=rmCreatePieConstraint("circle Constraint for mts 2", 0.5, 0.5, 0, rmZFractionToMeters(0.375), rmDegreesToRadians(0), rmDegreesToRadians(360));

   // Center constraints
   int centerConstraintForest=rmCreateClassDistanceConstraint("stay away from center forest", rmClassID("center"), rmZFractionToMeters(0.40));
   int centerConstraintForest2=rmCreateClassDistanceConstraint("stay away from center forest 2", rmClassID("center"), rmZFractionToMeters(0.38));

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
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), forestDist);
   int longForestConstraint=rmCreateClassDistanceConstraint("long forest vs. forest", rmClassID("classForest"), 26.0);
   int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
   int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "gold", 10.0);
   int shortAvoidSilver=rmCreateTypeDistanceConstraint("short gold avoid gold", "Mine", 20.0);
   int coinAvoidCoin=rmCreateTypeDistanceConstraint("coin avoids coin", "gold", 35.0);
   int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 1.0);
   int avoidSheep=rmCreateClassDistanceConstraint("sheep avoids sheep etc", rmClassID("herdableFood"), 45.0);
   int huntableConstraint=rmCreateClassDistanceConstraint("huntable constraint", rmClassID("huntableFood"), 35.0);
   int longHuntableConstraint=rmCreateClassDistanceConstraint("long huntable constraint", rmClassID("huntableFood"), 55.0);
   int forestsAvoidBison=rmCreateClassDistanceConstraint("forest avoids bison", rmClassID("huntableFood"), 15.0);
   int avoidProp=rmCreateClassDistanceConstraint("prop constraint", rmClassID("propClass"), 45.0);

   // Avoid impassable land, certain features
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
   int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 18.0);
   int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 8.0);
   int avoidCliffs=rmCreateClassDistanceConstraint("stuff vs. cliff", rmClassID("classCliff"), 25.0);
   int avoidCliffs2=rmCreateClassDistanceConstraint("stuff vs. cliff2", rmClassID("classCliff2"), 15.0);
   int avoidCanyons=rmCreateClassDistanceConstraint("avoid canyons", rmClassID("canyon"), 20.0);
   int avoidCanyonsLong=rmCreateClassDistanceConstraint("avoid canyons long", rmClassID("canyon"), 60.0);
   int cliffsAvoidCliffs=rmCreateClassDistanceConstraint("cliffs vs. cliffs", rmClassID("classCliff"), 30.0);
   int avoidCliffsShort=rmCreateClassDistanceConstraint("stuff vs. cliff short", rmClassID("classCliff"), 7.0);
   int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water mid-long", "Land", false, 10.0);
   int avoidLakesFar=rmCreateClassDistanceConstraint("stuff vs.lakes far", rmClassID("lake"), 55.0);
  
   // Unit avoidance
   int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 30.0);
   int avoidStartingUnitsSmall=rmCreateClassDistanceConstraint("objects avoid starting units small", rmClassID("startingUnit"), 10.0);
   int avoidStartingUnitsLarge=rmCreateClassDistanceConstraint("objects avoid starting units large", rmClassID("startingUnit"), 50.0);
   int avoidImportantItem=rmCreateClassDistanceConstraint("things avoid each other", rmClassID("importantItem"), 10.0);
   int avoidImportantItemSmall=rmCreateClassDistanceConstraint("important item small avoidance", rmClassID("importantItem"), 7.0);
   int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 60.0);
   int avoidNativesMed=rmCreateClassDistanceConstraint("stuff avoids natives medium", rmClassID("natives"), 40.0);
   int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives shorter", rmClassID("natives"), 25.0);
   int avoidNativesTiny=rmCreateClassDistanceConstraint("stuff avoids natives tiny", rmClassID("natives"), 8.0);
   int avoidNugget=rmCreateClassDistanceConstraint("nugget vs. nugget", rmClassID("classNugget"), 45.0);
   int avoidNuggetMed=rmCreateClassDistanceConstraint("nugget vs. nugget med", rmClassID("classNugget"), 60.0);
   int avoidNuggetLong=rmCreateClassDistanceConstraint("nugget vs. nugget long", rmClassID("classNugget"), 80.0);
   int avoidNuggetSmall=rmCreateTypeDistanceConstraint("avoid nuggets by a little", "AbstractNugget", 10.0);
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

   // Trade route avoidance.
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 8.0);
   int avoidTradeRouteForest = rmCreateTradeRouteDistanceConstraint("trade route forest", 3.0);
   int avoidSocket=rmCreateClassDistanceConstraint("avoid sockets", rmClassID("socketClass"), 13.0);

// End of constraints -------------------------------

   // Text
   rmSetStatusText("",0.15);

// Set up for axis and player side, player position
   if (trPattern < 2)
   {
	if (rmRandInt(1,8) == 1)
         distChance = 9;
	else
         distChance = rmRandInt(0,6);
   }

   if (trPattern > 7)
	distChance = rmRandInt(2,9);

// Set up player starting locations
if (cNumberNonGaiaPlayers == 2)
{
   sectionChance = rmRandInt(1,13);
   if (trPattern == 4)
      sectionChance = rmRandInt(1,9);
   if (trPattern == 5) 
      sectionChance = rmRandInt(1,9);
   if (axisChance == 1)
   {
      if (playerSide == 1)
      {
	     rmSetPlacementTeam(0);
      }
      else if (playerSide == 2)
      {
		rmSetPlacementTeam(1);
      }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.24, 0.26);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.29, 0.31);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.19, 0.21);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.14, 0.16);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.34, 0.36);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.34, 0.36);
	    else if (sectionChance == 7)
             rmSetPlacementSection(0.14, 0.16);
	    else if (sectionChance == 8)
             rmSetPlacementSection(0.29, 0.31);
	    else if (sectionChance == 9)
             rmSetPlacementSection(0.19, 0.21);
	    else if (sectionChance == 10)
             rmSetPlacementSection(0.09, 0.11);
	    else if (sectionChance == 11)
             rmSetPlacementSection(0.89, 0.91);
	    else if (sectionChance == 12)
             rmSetPlacementSection(0.09, 0.11);
	    else if (sectionChance == 13)
             rmSetPlacementSection(0.39, 0.41);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.74, 0.76);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.79, 0.81);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.69, 0.71);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.64, 0.66);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.84, 0.86);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.64, 0.66);
	    else if (sectionChance == 7)
             rmSetPlacementSection(0.84, 0.86);
	    else if (sectionChance == 8)
             rmSetPlacementSection(0.69, 0.71);
	    else if (sectionChance == 9)
             rmSetPlacementSection(0.79, 0.81);
	    else if (sectionChance == 10)
             rmSetPlacementSection(0.39, 0.41);
	    else if (sectionChance == 11)
             rmSetPlacementSection(0.59, 0.61);
	    else if (sectionChance == 12)
             rmSetPlacementSection(0.59, 0.61);
	    else if (sectionChance == 13)
             rmSetPlacementSection(0.89, 0.91);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);
   }
   else if (axisChance == 2)
   {
	    if (playerSide == 1)
          {
		rmSetPlacementTeam(0);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(1);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.49, 0.51);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.44, 0.46);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.54, 0.56);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.39, 0.41);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.59, 0.61);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.89, 0.91);
	    else if (sectionChance == 7)
             rmSetPlacementSection(0.09, 0.11);
	    else if (sectionChance == 8)
             rmSetPlacementSection(0.54, 0.56);
	    else if (sectionChance == 9)
             rmSetPlacementSection(0.44, 0.46);
	    else if (sectionChance == 10)
             rmSetPlacementSection(0.14, 0.16);
	    else if (sectionChance == 11)
             rmSetPlacementSection(0.34, 0.36);
	    else if (sectionChance == 12)
             rmSetPlacementSection(0.34, 0.36);
	    else if (sectionChance == 13)
             rmSetPlacementSection(0.64, 0.66);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.99, 0.01);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.94, 0.96);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.04, 0.06);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.89, 0.91);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.09, 0.11);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.59, 0.61);
	    else if (sectionChance == 7)
             rmSetPlacementSection(0.39, 0.41);
	    else if (sectionChance == 8)
             rmSetPlacementSection(0.94, 0.96);
	    else if (sectionChance == 9)
             rmSetPlacementSection(0.04, 0.06);
	    else if (sectionChance == 10)
             rmSetPlacementSection(0.84, 0.86);
	    else if (sectionChance == 11)
             rmSetPlacementSection(0.64, 0.66);
	    else if (sectionChance == 12)
             rmSetPlacementSection(0.84, 0.86);
	    else if (sectionChance == 13)
             rmSetPlacementSection(0.14, 0.16);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);
   }
}   
else 
{ 
   if (cNumberTeams == 2)
   {
      if (cNumberNonGaiaPlayers == 4) // 2 teams, 4 players 
      {
	  sectionChance = rmRandInt(1,6);
        if (axisChance == 1)
        {
          if (playerSide == 1)
          {
	  	rmSetPlacementTeam(0);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(1);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.21, 0.29);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.19, 0.31);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.18, 0.32);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.17, 0.33);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.16, 0.26);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.24, 0.34);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.71, 0.79);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.69, 0.81);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.68, 0.82);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.67, 0.83);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.66, 0.76);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.74, 0.84);          

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);
        }
        else if (axisChance == 2)
        {
	    if (playerSide == 1)
          {
		rmSetPlacementTeam(0);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(1);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.46, 0.54);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.44, 0.56);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.43, 0.57);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.42, 0.58);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.41, 0.51);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.49, 0.59);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.96, 0.04);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.94, 0.06);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.93, 0.07);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.92, 0.08);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.91, 0.01);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.99, 0.09);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);
        } 
      }
      else if (cNumberNonGaiaPlayers <7) // for 2 teams, for 3 or 5-6 players
      {
        if (axisChance == 1)
        {
          if (playerSide == 1)
          {
	  	rmSetPlacementTeam(0);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(1);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.17, 0.33);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.15, 0.35);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.13, 0.37);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.67, 0.83);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.65, 0.85);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.63, 0.87);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);
        }
        else if (axisChance == 2)
        {
	    if (playerSide == 1)
          {
		rmSetPlacementTeam(0);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(1);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.42, 0.58);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.40, 0.60);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.38, 0.62);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.92, 0.08);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.90, 0.10);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.88, 0.12);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);
        }
      }
      else  // for 2 teams, for over 6 players
      {
        if (axisChance == 1)
        {
          if (playerSide == 1)
          {
	  	rmSetPlacementTeam(0);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(1);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.15, 0.35);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.13, 0.37);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.11, 0.39);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.65, 0.85);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.63, 0.87);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.61, 0.89);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);
        }
        else if (axisChance == 2)
        {
	    if (playerSide == 1)
          {
		rmSetPlacementTeam(0);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(1);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.40, 0.60);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.38, 0.62);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.36, 0.64);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.90, 0.10);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.88, 0.12);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.86, 0.14);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);
        }
      }
   }
   else  // for FFA or over 2 teams
   {
      if (cNumberNonGaiaPlayers == 3) 
      {
		if (ffaChance == 1)
		{
   		   rmPlacePlayer(1, 0.31, 0.71);
		   rmPlacePlayer(2, 0.69, 0.71);
		   rmPlacePlayer(3, 0.69, 0.29);
		}
		else if (ffaChance == 2)
		{
   		   rmPlacePlayer(2, 0.31, 0.71);
		   rmPlacePlayer(3, 0.69, 0.71);
		   rmPlacePlayer(1, 0.69, 0.29);
		}		
		else if (ffaChance == 3)
		{
   		   rmPlacePlayer(3, 0.31, 0.71);
		   rmPlacePlayer(1, 0.69, 0.71);
		   rmPlacePlayer(2, 0.69, 0.29);
		}
		else
            { 
	       if (distChance == 0)
	          rmPlacePlayersCircular(0.45, 0.46, 0.0);
	       else if (distChance == 1)
	          rmPlacePlayersCircular(0.44, 0.45, 0.0);
	       else if (distChance == 2)
	          rmPlacePlayersCircular(0.42, 0.43, 0.0);
	       else if (distChance == 3)
	          rmPlacePlayersCircular(0.40, 0.41, 0.0);
	       else if (distChance == 4)
	          rmPlacePlayersCircular(0.38, 0.39, 0.0);
	       else if (distChance == 5)
	          rmPlacePlayersCircular(0.36, 0.37, 0.0);
	       else if (distChance == 6)
	          rmPlacePlayersCircular(0.34, 0.35, 0.0);
	       else if (distChance == 7)
	          rmPlacePlayersCircular(0.32, 0.33, 0.0);
	       else if (distChance == 8)
	          rmPlacePlayersCircular(0.29, 0.31, 0.0);
	       else if (distChance == 9)
	          rmPlacePlayersCircular(0.26, 0.28, 0.0);
            }
      }
      else if (cNumberNonGaiaPlayers == 4) 
      {
		if (ffaChance == 1)
		{
   		   rmPlacePlayer(1, 0.31, 0.71);
		   rmPlacePlayer(2, 0.69, 0.71);
		   rmPlacePlayer(3, 0.69, 0.29);
		   rmPlacePlayer(4, 0.31, 0.29);
		}
		else if (ffaChance == 2)
		{
   		   rmPlacePlayer(2, 0.31, 0.71);
		   rmPlacePlayer(3, 0.69, 0.71);
		   rmPlacePlayer(4, 0.69, 0.29);
		   rmPlacePlayer(1, 0.31, 0.29);
		}		
		else if (ffaChance == 3) 
		{
   		   rmPlacePlayer(3, 0.31, 0.71);
		   rmPlacePlayer(4, 0.69, 0.71);
		   rmPlacePlayer(1, 0.69, 0.29);
		   rmPlacePlayer(2, 0.31, 0.29);
		}
		else
            { 
	       if (distChance == 0)
	          rmPlacePlayersCircular(0.45, 0.46, 0.0);
	       else if (distChance == 1)
	          rmPlacePlayersCircular(0.44, 0.45, 0.0);
	       else if (distChance == 2)
	          rmPlacePlayersCircular(0.42, 0.43, 0.0);
	       else if (distChance == 3)
	          rmPlacePlayersCircular(0.40, 0.41, 0.0);
	       else if (distChance == 4)
	          rmPlacePlayersCircular(0.38, 0.39, 0.0);
	       else if (distChance == 5)
	          rmPlacePlayersCircular(0.36, 0.37, 0.0);
	       else if (distChance == 6)
	          rmPlacePlayersCircular(0.34, 0.35, 0.0);
	       else if (distChance == 7)
	          rmPlacePlayersCircular(0.32, 0.33, 0.0);
	       else if (distChance == 8)
	          rmPlacePlayersCircular(0.29, 0.31, 0.0);
	       else if (distChance == 9)
	          rmPlacePlayersCircular(0.26, 0.28, 0.0);
            }
	}
      else  // over 4 FFA 
      { 
 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.44, 0.45, 0.0);
	    else if (distChance == 2)
	       rmPlacePlayersCircular(0.42, 0.43, 0.0);
	    else if (distChance == 3)
	       rmPlacePlayersCircular(0.40, 0.41, 0.0);
	    else if (distChance == 4)
	       rmPlacePlayersCircular(0.38, 0.39, 0.0);
	    else if (distChance == 5)
	       rmPlacePlayersCircular(0.36, 0.37, 0.0);
	    else if (distChance == 6)
	       rmPlacePlayersCircular(0.34, 0.35, 0.0);
	    else if (distChance == 7)
	       rmPlacePlayersCircular(0.32, 0.33, 0.0);
	    else if (distChance == 8)
	       rmPlacePlayersCircular(0.29, 0.31, 0.0);
	    else if (distChance == 9)
	       rmPlacePlayersCircular(0.26, 0.28, 0.0);
      }
   }
}

   // Text
   rmSetStatusText("",0.20);
	
// Set up player areas.
   float playerFraction=rmAreaTilesToFraction(300);
   for(i=1; <cNumberPlayers)
   {
      int id=rmCreateArea("Player"+i);
      rmSetPlayerArea(i, id);
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 1);
      rmAddAreaConstraint(id, longAvoidImpassableLand);
      rmAddAreaConstraint(id, playerEdgeConstraint); 
      rmSetAreaLocPlayer(id, i);
      rmSetAreaMix(id, baseType);
      rmSetAreaWarnFailure(id, false);
   }
   rmBuildAllAreas();

   // Text
   rmSetStatusText("",0.25);

   //Text
   rmSetStatusText("",0.35);

// Starting TCs and units 		
   int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
   rmSetObjectDefMinDistance(startingUnits, 5.0);
   rmSetObjectDefMaxDistance(startingUnits, 10.0);
   rmAddObjectDefConstraint(startingUnits, avoidAll);

   int startingTCID= rmCreateObjectDef("startingTC");
   rmSetObjectDefMaxDistance(startingTCID, 18.0);
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

// Central features & patches, per map or variant
   // Center area
   int centerArea=rmCreateArea("TheCenter");
   rmSetAreaSize(centerArea, 0.05, 0.05);
   rmSetAreaLocation(centerArea, 0.5, 0.5);
   rmAddAreaToClass(centerArea, rmClassID("center")); 
 
   // Text
   rmSetStatusText("",0.40);

// NATIVE AFRICANS
   // Village A 
   int villageAID = -1;
   int whichNative = rmRandInt(1,4);
   int villageType = rmRandInt(1,3);

   if (whichNative == 1)
      villageAID = rmCreateGrouping("village A", subCiv0Name+" "+aur_type+" "+villageType);
   else if (whichNative == 2)
      villageAID = rmCreateGrouping("village A", subCiv1Name+" "+aur_type+" "+villageType);
   else if (whichNative == 3)
      villageAID = rmCreateGrouping("village A", subCiv2Name+" "+aur_type+" "+villageType);
   else if (whichNative == 4)
      villageAID = rmCreateGrouping("village A", subCiv3Name+" "+aur_type+" "+villageType);
   rmAddGroupingToClass(villageAID, rmClassID("natives"));
   rmAddGroupingToClass(villageAID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageAID, 0.0);
   rmSetGroupingMaxDistance(villageAID, rmXFractionToMeters(0.08));
   rmAddGroupingConstraint(villageAID, avoidImpassableLand);
   rmAddGroupingConstraint(villageAID, avoidTradeRoute);
   rmAddGroupingConstraint(villageAID, avoidNativesMed);
   rmAddGroupingConstraint(villageAID, playerConstraint);

   // Village D - always different type from A 
   int villageDID = -1;
   villageType = rmRandInt(1,5);
   int threeChoice = rmRandInt(1,3);

   if (whichNative == 1)
   {
	if (threeChoice == 1)
	   villageDID = rmCreateGrouping("village D", subCiv0Name+" "+aur_type+" "+villageType);
	else if (threeChoice == 2)
	   villageDID = rmCreateGrouping("village D", subCiv1Name+" "+aur_type+" "+villageType);  
	else  
	   villageDID = rmCreateGrouping("village D", subCiv2Name+" "+aur_type+" "+villageType);
   }
   else if (whichNative == 2)
   {
	if (threeChoice == 1)
	   villageDID = rmCreateGrouping("village D", subCiv1Name+" "+aur_type+" "+villageType);
	else if (threeChoice == 2)
	   villageDID = rmCreateGrouping("village D", subCiv2Name+" "+aur_type+" "+villageType);  
	else  
	   villageDID = rmCreateGrouping("village D", subCiv3Name+" "+aur_type+" "+villageType);
   }
   else if (whichNative == 3)
   {
	if (threeChoice == 1)
	   villageDID = rmCreateGrouping("village D", subCiv2Name+" "+aur_type+" "+villageType);
	else if (threeChoice == 2)
	   villageDID = rmCreateGrouping("village D", subCiv3Name+" "+aur_type+" "+villageType); 
	else  
	   villageDID = rmCreateGrouping("village D", subCiv0Name+" "+aur_type+" "+villageType);
   }
   else if (whichNative == 4)
   {
	if (threeChoice == 1)
	   villageDID = rmCreateGrouping("village D", subCiv3Name+" "+aur_type+" "+villageType);
	else if (threeChoice == 2)
	   villageDID = rmCreateGrouping("village D", subCiv0Name+" "+aur_type+" "+villageType); 
	else  
	   villageDID = rmCreateGrouping("village D", subCiv1Name+" "+aur_type+" "+villageType);
   }
   rmAddGroupingToClass(villageDID, rmClassID("natives"));
   rmAddGroupingToClass(villageDID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageDID, 0.0);
   rmSetGroupingMaxDistance(villageDID, rmXFractionToMeters(0.08));
   rmAddGroupingConstraint(villageDID, avoidImpassableLand);
   rmAddGroupingConstraint(villageDID, avoidTradeRoute);
   rmAddGroupingConstraint(villageDID, avoidNativesMed);
   rmAddGroupingConstraint(villageDID, playerConstraint);

   // Village B - randomly same or different from other villages 
   int villageBID = -1;	
   villageType = rmRandInt(1,5);
   whichNative = rmRandInt(1,4);

   if (whichNative == 1)
      villageBID = rmCreateGrouping("village B", subCiv0Name+" "+aur_type+" "+villageType);
   else if (whichNative == 2)
      villageBID = rmCreateGrouping("village B", subCiv1Name+" "+aur_type+" "+villageType);
   else if (whichNative == 3)
      villageBID = rmCreateGrouping("village B", subCiv2Name+" "+aur_type+" "+villageType);
   else if (whichNative == 4)
      villageBID = rmCreateGrouping("village B", subCiv3Name+" "+aur_type+" "+villageType);
   rmAddGroupingToClass(villageBID, rmClassID("importantItem"));
   rmAddGroupingToClass(villageBID, rmClassID("natives"));
   rmSetGroupingMinDistance(villageBID, 0.0);
   rmSetGroupingMaxDistance(villageBID, rmXFractionToMeters(0.08));
   rmAddGroupingConstraint(villageBID, avoidImpassableLand);
   rmAddGroupingConstraint(villageBID, avoidTradeRoute);
   rmAddGroupingConstraint(villageBID, avoidNatives);
   rmAddGroupingConstraint(villageBID, playerConstraint);

   // Village C // appears in center, variable, randomly same or opposite A and B
   int villageCID = -1;	
   villageType = rmRandInt(1,5);
   whichNative = rmRandInt(1,4);

   if (whichNative == 1)
      villageCID = rmCreateGrouping("village C", subCiv0Name+" "+aur_type+" "+villageType);
   else if (whichNative == 2)
      villageCID = rmCreateGrouping("village C", subCiv1Name+" "+aur_type+" "+villageType);
   else if (whichNative == 3)
      villageCID = rmCreateGrouping("village C", subCiv2Name+" "+aur_type+" "+villageType);
   else if (whichNative == 4)
      villageCID = rmCreateGrouping("village C", subCiv3Name+" "+aur_type+" "+villageType);
   rmAddGroupingToClass(villageCID, rmClassID("importantItem"));
   rmAddGroupingToClass(villageCID, rmClassID("natives"));
   rmSetGroupingMinDistance(villageCID, 0.0);
   rmSetGroupingMaxDistance(villageCID, rmXFractionToMeters(0.06));
   rmAddGroupingConstraint(villageCID, avoidImpassableLand);
   rmAddGroupingConstraint(villageCID, avoidTradeRoute);
   rmAddGroupingConstraint(villageCID, avoidNatives);
   rmAddGroupingConstraint(villageCID, playerConstraint);

   // Text
   rmSetStatusText("",0.45);

   // Placement of Native Africans
 
  if (trPattern > 7)
	endPosition = rmRandInt(1,2);
   if (trPattern == 2)
	endPosition = rmRandInt(2,3);
   if (trPattern == 3)
	endPosition = rmRandInt(2,3);
   if (trPattern == 0)
   {
	if (rmRandInt(1,2) == 1)
	   endPosition = 3;
	else
	   endPosition = 1;
   }
   if (trPattern == 1)
   {
	if (rmRandInt(1,2) == 1)
	   endPosition = 3;
	else
	   endPosition = 1;
   }

   if (nativeSetup < 4) 
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
            rmPlaceGroupingAtLoc(villageBID, 0, 0.495, 0.09);
	}
      else
	{
	   if (endPosition == 1)
            rmPlaceGroupingAtLoc(villageBID, 0, 0.27, 0.495);
	   else if (endPosition == 2)
            rmPlaceGroupingAtLoc(villageBID, 0, 0.18, 0.505);
	   else
            rmPlaceGroupingAtLoc(villageBID, 0, 0.09, 0.495);
	}
         
	if (nativeSetup < 2)
	{
         rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.5);
	}
	else 
	{
         if (nativeNumber < 2)
	   {
            rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.5);
	   }
	   else
	   {
	      rmSetGroupingMaxDistance(villageCID, rmXFractionToMeters(0.085));
		if (axisChance == 1)
		{
               rmPlaceGroupingAtLoc(villageCID, 0, 0.485, 0.51);
               rmPlaceGroupingAtLoc(villageCID, 0, 0.515, 0.49);
	      }
		else
		{
               rmPlaceGroupingAtLoc(villageCID, 0, 0.51, 0.515);
               rmPlaceGroupingAtLoc(villageCID, 0, 0.49, 0.485);
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
               rmPlaceGroupingAtLoc(villageDID, 0, 0.745, 0.495);
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
               rmPlaceGroupingAtLoc(villageDID, 0, 0.505, 0.07);
	   }            
         else
	   {
	      if (endPosition == 1)
               rmPlaceGroupingAtLoc(villageDID, 0, 0.25, 0.505);
	      else if (endPosition == 2)
               rmPlaceGroupingAtLoc(villageDID, 0, 0.16, 0.495);
	      else
               rmPlaceGroupingAtLoc(villageDID, 0, 0.07, 0.505);
	   }            
	}
	if (nativeSetup == 8)
	{
         if (nativeNumber > 2)
	   {
		if (axisChance == 1)
		{
               rmPlaceGroupingAtLoc(villageDID, 0, 0.485, 0.49);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.515, 0.51);
	      }
		else
		{
               rmPlaceGroupingAtLoc(villageDID, 0, 0.49, 0.515);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.51, 0.485);
	      }
	   }
	   else  // for nativeNumber == 1
	   {
	      rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.5);
	   }
	}
	if (nativeSetup == 9)
	{
         rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.5);
	}
	if (nativeSetup < 12)
	{
         for(i=1; <cNumberPlayers) 
         {
            rmSetGroupingMinDistance(villageAID, 55.0);
            rmSetGroupingMaxDistance(villageAID, 80.0);           
   	      rmPlaceGroupingAtLoc(villageAID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	      if (nativeSetup == 10)
 	      {
               rmSetGroupingMinDistance(villageDID, 55.0);
               rmSetGroupingMaxDistance(villageDID, 80.0);      
		   rmPlaceGroupingAtLoc(villageDID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	      }
	      if (nativeSetup == 11)
		   rmPlaceGroupingAtLoc(villageAID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	   }
	}
      if (nativeSetup > 11) // setup 12 to 14
      {
         rmSetGroupingMaxDistance(villageAID, rmXFractionToMeters(0.075));
         rmAddGroupingConstraint(villageAID, nuggetPlayerConstraint);
         if (axisChance == 1)
	   {
		if (distChance < 6)
		{
               rmPlaceGroupingAtLoc(villageAID, 0, 0.33, 0.4);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.33, 0.6);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.67, 0.4);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.67, 0.6);
		}
		else
		{
               rmPlaceGroupingAtLoc(villageAID, 0, 0.12, 0.31);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.12, 0.69);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.88, 0.31);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.88, 0.69);
		}
	   }
	   else
	   {
		if (distChance < 6)
		{
               rmPlaceGroupingAtLoc(villageAID, 0, 0.4, 0.33);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.6, 0.33);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.4, 0.67);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.6, 0.67);
		}
		else
		{
               rmPlaceGroupingAtLoc(villageAID, 0, 0.31, 0.12);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.69, 0.12);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.31, 0.88);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.69, 0.88);
		}
	   }
	   if (nativeSetup == 13) 
	   {
            if (nativeNumber < 2)
	      {
	         rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.5);
		}
		else
		{
	         if (axisChance == 1)
		   {
               	rmPlaceGroupingAtLoc(villageDID, 0, 0.485, 0.49);
               	rmPlaceGroupingAtLoc(villageDID, 0, 0.515, 0.51);
	         }
		   else
		   {
           		rmPlaceGroupingAtLoc(villageDID, 0, 0.49, 0.515);
           	      rmPlaceGroupingAtLoc(villageDID, 0, 0.51, 0.485);
	         }
		}
	   }
	   if (nativeSetup == 14) 
	   {
            if (axisChance == 1)
	      {
	         if (endPosition == 1)
		   {
                  rmPlaceGroupingAtLoc(villageDID, 0, 0.495, 0.75);
                  rmPlaceGroupingAtLoc(villageDID, 0, 0.505, 0.25);
		   } 
   	         else if (endPosition == 2)
		   {
                  rmPlaceGroupingAtLoc(villageDID, 0, 0.505, 0.84);
                  rmPlaceGroupingAtLoc(villageDID, 0, 0.495, 0.16);
		   } 
	         else
		   {
                  rmPlaceGroupingAtLoc(villageDID, 0, 0.505, 0.07);
                  rmPlaceGroupingAtLoc(villageDID, 0, 0.495, 0.93);
		   } 
	      }
            else
	      {
	         if (endPosition == 1)
		   {
                  rmPlaceGroupingAtLoc(villageDID, 0, 0.745, 0.495);
                  rmPlaceGroupingAtLoc(villageDID, 0, 0.25, 0.505);
		   }
	         else if (endPosition == 2)
		   {
                  rmPlaceGroupingAtLoc(villageDID, 0, 0.84, 0.505);
                  rmPlaceGroupingAtLoc(villageDID, 0, 0.16, 0.495);
		   }
	         else
		   {
                  rmPlaceGroupingAtLoc(villageDID, 0, 0.93, 0.495);
                  rmPlaceGroupingAtLoc(villageDID, 0, 0.07, 0.505);
		   }
	      }                
	   }
      }
   }
   else if (nativeSetup > 3) // setup 4 and 5
   {
      if (axisChance == 1)
	{
	   if (endPosition == 1)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.75);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.25);
	   }
	   else if (endPosition == 2)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.84);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.16);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.93);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.08);
	   }
	}          
      else
	{
	   if (endPosition == 1)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.75, 0.5);
	      rmPlaceGroupingAtLoc(villageAID, 0, 0.25, 0.5);
	   }
	   else if (endPosition == 2)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.84, 0.5);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.16, 0.5);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.93, 0.5);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.07, 0.5);
	   }
	}               
	if (nativeSetup == 4)
	{
	   if (nativeNumber == 1)
            rmPlaceGroupingAtLoc(villageCID, 0, 0.5, 0.5);
	   else
	   {
	      if (axisChance == 1)
	      {
               rmPlaceGroupingAtLoc(villageDID, 0, 0.485, 0.51);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.515, 0.49);
            }
   	      else
	      {
               rmPlaceGroupingAtLoc(villageDID, 0, 0.51, 0.515);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.49, 0.485);
	      }
	   }
	}
      if (axisChance == 1)
	{
         if (sidePosition == 1)
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.74, 0.5);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.24, 0.5);
	   }
	   else if (sidePosition == 2)
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.84, 0.5);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.16, 0.5);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.93, 0.5);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.08, 0.5);
	   }
      }
	else
	{
         if (sidePosition == 1)
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.75);
		rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.25);
	   }	   
	   else if (sidePosition == 2)
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.84);
		rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.16);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.93);
		rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.08); 
         }
	}  
   }


  // King of the Hill (added 2026-11 for WoL): the middle of all start positions (the map centre), on open land
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
   rmAddObjectDefConstraint(playerNuggetID, circleConstraint);

   for(i=1; <cNumberPlayers)
   {
 	rmSetNuggetDifficulty(1, 1);
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }

   // Text
   rmSetStatusText("",0.55);

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
   rmAddObjectDefItem(StartBerryBushID, "BerryBush", rmRandInt(2,4), 4.0);
   rmSetObjectDefMinDistance(StartBerryBushID, 10.0);
   rmSetObjectDefMaxDistance(StartBerryBushID, 16.0);
   rmAddObjectDefConstraint(StartBerryBushID, avoidStartingUnitsSmall);
   rmPlaceObjectDefPerPlayer(StartBerryBushID, false, 1);

   // start area huntable
   int deerNum = rmRandInt(5,6);
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
   int deer2Num = rmRandInt(3,3);
   int farPronghornID=rmCreateObjectDef("far pronghorn");
   rmAddObjectDefItem(farPronghornID, deer2Type, deer2Num, 5.0);
   rmAddObjectDefToClass(farPronghornID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(farPronghornID, 32.0);
   rmSetObjectDefMaxDistance(farPronghornID, 45.0);
   rmAddObjectDefConstraint(farPronghornID, avoidStartResource);
   rmAddObjectDefConstraint(farPronghornID, mediumPlayerConstraint);
   rmAddObjectDefConstraint(farPronghornID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(farPronghornID, avoidNativesShort);
   rmAddObjectDefConstraint(farPronghornID, huntableConstraint);
   rmAddObjectDefConstraint(farPronghornID, avoidAll);
   rmSetObjectDefCreateHerd(farPronghornID, true);
   rmPlaceObjectDefPerPlayer(farPronghornID, false, 1);

   // Text
   rmSetStatusText("",0.60);

// Silver mines - players
   int silverType = -1;
   silverType = rmRandInt(1,10);
   int playerGoldID=rmCreateObjectDef("player silver closer");
   rmAddObjectDefItem(playerGoldID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(playerGoldID, avoidTradeRoute);
   rmAddObjectDefConstraint(playerGoldID, avoidSocket);
   rmAddObjectDefConstraint(playerGoldID, coinAvoidCoin);
   rmAddObjectDefConstraint(playerGoldID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(playerGoldID, circleConstraint);
   rmAddObjectDefConstraint(playerGoldID, avoidAll);
   rmSetObjectDefMinDistance(playerGoldID, 18.0);
   rmSetObjectDefMaxDistance(playerGoldID, 23.0);
   rmPlaceObjectDefPerPlayer(playerGoldID, false, 1);
   if (rmRandInt(1,4) == 1)
      rmPlaceObjectDefPerPlayer(playerGoldID, false, 1);

   silverType = rmRandInt(1,10);
   int GoldMediumID=rmCreateObjectDef("player silver med");
   rmAddObjectDefItem(GoldMediumID, "MineGold", 1, 0.0);
   rmAddObjectDefConstraint(GoldMediumID, avoidTradeRoute);
   rmAddObjectDefConstraint(GoldMediumID, avoidSocket);
   rmAddObjectDefConstraint(GoldMediumID, coinAvoidCoin);
   rmAddObjectDefConstraint(GoldMediumID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldMediumID, playerConstraint);
   rmAddObjectDefConstraint(GoldMediumID, circleConstraint);
   rmAddObjectDefConstraint(GoldMediumID, avoidAll);
   rmSetObjectDefMinDistance(GoldMediumID, 40.0);
   rmSetObjectDefMaxDistance(GoldMediumID, 55.0);
   rmPlaceObjectDefPerPlayer(GoldMediumID, false, 1);

// Extra tree clumps near players - to ensure fair access to wood
   int extraTreesID=rmCreateObjectDef("extra trees");
   rmAddObjectDefItem(extraTreesID, treeType, 5, 5.0);
   rmSetObjectDefMinDistance(extraTreesID, 14);
   rmSetObjectDefMaxDistance(extraTreesID, 18);
   rmAddObjectDefConstraint(extraTreesID, avoidAll);
   rmAddObjectDefConstraint(extraTreesID, avoidCoin);
   rmAddObjectDefConstraint(extraTreesID, avoidSocket);
   rmAddObjectDefConstraint(extraTreesID, avoidTradeRoute);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(extraTreesID, 0, rmAreaID("player"+i), 1);

   int extraTrees2ID=rmCreateObjectDef("more extra trees");
   rmAddObjectDefItem(extraTrees2ID, treeType, 6, 6.0);
   rmSetObjectDefMinDistance(extraTrees2ID, 19);
   rmSetObjectDefMaxDistance(extraTrees2ID, 30);
   rmAddObjectDefConstraint(extraTrees2ID, avoidAll);
   rmAddObjectDefConstraint(extraTrees2ID, avoidCoin);
   rmAddObjectDefConstraint(extraTrees2ID, avoidSocket);
   rmAddObjectDefConstraint(extraTrees2ID, avoidTradeRoute);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(extraTrees2ID, 0, rmAreaID("player"+i), 2);

   // Text
   rmSetStatusText("",0.65);

// Forests 
   int failCount=0;
   int forestChance = -1;
   int numTries=22*cNumberNonGaiaPlayers;
   if (cNumberNonGaiaPlayers == 3)
      numTries=20*cNumberNonGaiaPlayers;  
   if (cNumberNonGaiaPlayers > 3)
      numTries=17*cNumberNonGaiaPlayers;  
   if (cNumberNonGaiaPlayers > 5)
      numTries=15*cNumberNonGaiaPlayers;    

   for (i=0; <numTries)
   {
      forestChance = rmRandInt(1,4);
      int forest=rmCreateArea("forest "+i);
      rmSetAreaWarnFailure(forest, false);
      rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(185));
      rmSetAreaForestType(forest, forestType);
      rmSetAreaForestDensity(forest, rmRandFloat(0.7, 1.0));
      rmSetAreaForestClumpiness(forest, rmRandFloat(0.5, 0.9));
      rmSetAreaForestUnderbrush(forest, rmRandFloat(0.5, 0.5));
      rmSetAreaCoherence(forest, rmRandFloat(0.4, 0.5));
      rmSetAreaSmoothDistance(forest, rmRandInt(10,20));
      if (forestChance == 3)
      {
	   rmSetAreaMinBlobs(forest, 1);
	   rmSetAreaMaxBlobs(forest, 3);					
	   rmSetAreaMinBlobDistance(forest, 10.0);
	   rmSetAreaMaxBlobDistance(forest, 20.0);
	}
      if (forestChance == 4)
      {
	   rmSetAreaMinBlobs(forest, 3);
	   rmSetAreaMaxBlobs(forest, 5);					
	   rmSetAreaMinBlobDistance(forest, 12.0);
	   rmSetAreaMaxBlobDistance(forest, 20.0);
	}
      rmAddAreaToClass(forest, rmClassID("classForest")); 
	rmAddAreaConstraint(forest, playerConstraintForest);
      rmAddAreaConstraint(forest, forestObjConstraint);
      rmAddAreaConstraint(forest, avoidAll); 
	rmAddAreaConstraint(forest, avoidCoin);  
      rmAddAreaConstraint(forest, avoidImpassableLand); 
      rmAddAreaConstraint(forest, avoidTradeRouteForest);
	rmAddAreaConstraint(forest, avoidStartingUnits);
	rmAddAreaConstraint(forest, avoidSocket);
	rmAddAreaConstraint(forest, avoidNativesTiny);
      rmAddAreaConstraint(forest, forestsAvoidBison); 
	
//	if (rmRandInt(1,3) > 1)
//         rmSetAreaBaseHeight(forest, rmRandFloat(4.0, 5.5));

/*	if (cNumberNonGaiaPlayers > 3)
	   rmAddAreaConstraint(forest, centerConstraintForest);
	else
         rmAddAreaConstraint(forest, centerConstraintForest2);*/
      if(rmBuildArea(forest)==false)
      {
         // Stop trying once we fail 3 times in a row.
         failCount++;
         if(failCount==15)
            break;
      }
      else
         failCount=0; 
   } 
/*
// Patch to cover forest floor in each version
      int desertID = rmCreateArea("color patch");
      rmSetAreaLocation(desertID, 0.5, 0.5); 
      rmSetAreaWarnFailure(desertID, false);
      rmSetAreaSize(desertID, 0.99, 0.99);
      rmSetAreaCoherence(desertID, 0.9);
	rmSetAreaElevationType(desertID, cElevTurbulence);
//      if (patternChance == 9)
//         rmSetAreaTerrainType(desertID, "wotta\nile\llanos5");
//      else if (patternChance == 10) 
         rmSetAreaMix(desertID, baseType);     
      rmBuildArea(desertID);

// Patch to lower elevation of center and leave rim a little higher
      int desert2ID = rmCreateArea("lower patch");
      rmSetAreaLocation(desert2ID, 0.5, 0.5); 
      rmSetAreaWarnFailure(desert2ID, false);
      rmSetAreaSize(desert2ID, 0.95, 0.96);
      rmSetAreaCoherence(desert2ID, 0.9);
      rmSetAreaBaseHeight(desert2ID, 0.0);
	rmSetAreaElevationEdgeFalloffDist(desert2ID, 8.0);
      rmAddAreaConstraint(desert2ID, circleConstraintMt);
//      if (patternChance == 9)
//         rmSetAreaTerrainType(desert2ID, "wotta\nile\llanos5");
//      else if (patternChance == 10) 
         rmSetAreaMix(desert2ID, baseType);     
      rmBuildArea(desert2ID);
*/
   // Text
   rmSetStatusText("",0.70);

// Cliffs etc
   // Center Highland or Canyon
   int makeCentralCliffArea = -1;
   if (makeCentralHighlands == 1)
	makeCentralCliffArea = 1;
   if (makeCentralCanyon == 1)
 	makeCentralCliffArea = 1;

   if (trPattern == 5)
	makeCentralCliffArea = 0;
   if (trPattern == 6)
	makeCentralCliffArea = 0;

   if (makeCentralCliffArea == 1)
   {
	cliffVariety = rmRandInt(1,5);
      int edgeChance = rmRandInt(1,4);
      int centerHighlandsID=rmCreateArea("center highlands");
      rmSetAreaLocation(centerHighlandsID, 0.5, 0.5);
      rmSetAreaSize(centerHighlandsID, 0.028, 0.035);
      rmAddAreaToClass(centerHighlandsID, rmClassID("classCliff2"));
      rmSetAreaMix(centerHighlandsID, baseType);
      rmSetAreaCliffType(centerHighlandsID, cliffType);
      rmSetAreaCliffPainting(centerHighlandsID, false, true, true, 1.5, true);
	if (edgeChance == 1)
         rmSetAreaCliffEdge(centerHighlandsID, 3, 0.27, 0.12, 0.5, 0);
	else if (edgeChance == 2)
         rmSetAreaCliffEdge(centerHighlandsID, 4, 0.2, 0.12, 0.5, 0);
	else if (edgeChance == 3)
         rmSetAreaCliffEdge(centerHighlandsID, 2, 0.41, 0.12, 0.5, 0);
	else if (edgeChance == 4)
         rmSetAreaCliffEdge(centerHighlandsID, 5, 0.1, 0.12, 0.5, 0);
	if (makeCentralHighlands == 1)
	   rmSetAreaCliffHeight(centerHighlandsID, rmRandInt(6,8), 1.0, 0.5);
	else if (makeCentralCanyon == 1)
	   rmSetAreaCliffHeight(centerHighlandsID, -8, 1.0, 0.5);
      rmSetAreaSmoothDistance(centerHighlandsID, 12);
      rmSetAreaCoherence(centerHighlandsID, 0.5);
	rmSetAreaHeightBlend(centerHighlandsID, 1.0);
      rmAddAreaConstraint(centerHighlandsID, avoidTradeRoute);
      rmAddAreaConstraint(centerHighlandsID, avoidSocket);
      rmBuildArea(centerHighlandsID);
   }

   // Regular Cliffs
   int cliffHt = -1;
   failCount=0;

   if (makeCliffs == 1)
   { 
      if (cliffVariety == 0) // a little like AOM Anatolia
	{
	   int gorgeHt=rmRandInt(-7,-4);
	   numTries = 3;
	   if (cNumberNonGaiaPlayers < 4)
	      numTries = 2;
	   if (cNumberNonGaiaPlayers > 5)
	      numTries = 4;

	   for(i=0; <numTries)
	   {
	   int gorgeID=rmCreateArea("gorge"+i);
         rmSetAreaWarnFailure(gorgeID, false); 
	   rmSetAreaSize(gorgeID, rmAreaTilesToFraction(1600), rmAreaTilesToFraction(2100));
	   rmSetAreaCliffType(gorgeID, cliffType);
	   rmAddAreaToClass(gorgeID, rmClassID("canyon"));
	   rmSetAreaMinBlobs(gorgeID, 4);
	   rmSetAreaMaxBlobs(gorgeID, 6);
	   if (rmRandInt(1,3) == 1)
	      rmSetAreaCliffEdge(gorgeID, 6, 0.10, 0.2, 1.0, 0);
	   else
	   {
		if (rmRandInt(1,2) == 1) 
	         rmSetAreaCliffEdge(gorgeID, 5, 0.15, 0.15, 1.0, 0);
		else
	         rmSetAreaCliffEdge(gorgeID, 4, 0.17, 0.15, 1.0, 0);
	   }		
	   rmSetAreaCliffPainting(gorgeID, false, true, true, 1.5);
	   rmSetAreaMinBlobDistance(gorgeID, 20.0);
	   rmSetAreaMaxBlobDistance(gorgeID, 30.0);
	   rmSetAreaCoherence(gorgeID, rmRandFloat(0.0,0.2));
	   rmSetAreaSmoothDistance(gorgeID, rmRandInt(10,20));
	   rmSetAreaCliffHeight(gorgeID, gorgeHt, 1.0, 1.0);
	   rmSetAreaHeightBlend(gorgeID, 2);
	   rmAddAreaConstraint(gorgeID, avoidCanyonsLong);
	   rmAddAreaConstraint(gorgeID, cliffsAvoidCliffs);
         rmAddAreaConstraint(gorgeID, avoidImportantItem);
	   rmAddAreaConstraint(gorgeID, avoidTradeRoute);
         rmAddAreaConstraint(gorgeID, avoidNatives);
	   rmAddAreaConstraint(gorgeID, avoidSocket);
	   rmAddAreaConstraint(gorgeID, shortForestConstraint);
	   rmAddAreaConstraint(gorgeID, avoidStartingUnits);
	   rmAddAreaConstraint(gorgeID, fartherPlayerConstraint);
	   rmAddAreaConstraint(gorgeID, secondEdgeConstraint);
 	   rmBuildArea(gorgeID);
	   }
      }
      else // all other maps with cliffs
      {
         int numCliffs = rmRandInt(5,9);
	   if (cliffVariety == 2)
		if (makeCentralCliffArea == 1)
		   numCliffs = rmRandInt(4,8);
		else
		   numCliffs = rmRandInt(6,10);
	   else
 		if (makeCentralCliffArea == 1)
		   numCliffs = rmRandInt(4,6);
	   if (cliffChance > 7)
		numCliffs = rmRandInt(2,4);

         for (i=0; <numCliffs)
         {
		cliffHt = rmRandInt(6,8);    
		int bigCliffID=rmCreateArea("big cliff" +i);
		rmSetAreaWarnFailure(bigCliffID, false);
		rmSetAreaCliffType(bigCliffID, cliffType);
		if (cliffVariety == 1) // like Patagonia
		{
   	         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(600), rmAreaTilesToFraction(800));
		   rmAddAreaToClass(bigCliffID, rmClassID("classCliff2"));
      	   rmSetAreaCliffEdge(bigCliffID, 2, 0.35, 0.1, 1.0, 0);
      	   rmSetAreaCliffPainting(bigCliffID, false, true, true, 1.5, true);
		   rmSetAreaCliffHeight(bigCliffID, 7, 2.0, 0.5);
		   rmSetAreaCoherence(bigCliffID, 0.5);
		   rmSetAreaSmoothDistance(bigCliffID, 5);
		   rmSetAreaHeightBlend(bigCliffID, 1.0);
	  	   rmSetAreaMinBlobs(bigCliffID, 1);
		   rmSetAreaMaxBlobs(bigCliffID, 5);
		   rmSetAreaMinBlobDistance(bigCliffID, 6.0);
		   rmSetAreaMaxBlobDistance(bigCliffID, 20.0);
		}
		else if (cliffVariety == 2) // smaller, kinda like in Sudden Death from AOM
		{
   	         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(280), rmAreaTilesToFraction(400));
		   rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
		   rmSetAreaCliffEdge(bigCliffID, 1, 0.6, 0.1, 1.0, 0);
		   rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
		   rmSetAreaCliffHeight(bigCliffID, cliffHt, 1.0, 1.0);
		   rmSetAreaCoherence(bigCliffID, rmRandFloat(0.4, 0.9));
		   rmSetAreaSmoothDistance(bigCliffID, 10);
		   rmSetAreaHeightBlend(bigCliffID, 2.0);
	  	   rmSetAreaMinBlobs(bigCliffID, 1);
		   rmSetAreaMaxBlobs(bigCliffID, 3);
		   rmSetAreaMinBlobDistance(bigCliffID, 6.0);
		   rmSetAreaMaxBlobDistance(bigCliffID, 15.0);
		}
		else if (cliffVariety == 3)  // odd ridges
		{
   	         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(300), rmAreaTilesToFraction(400));
		   rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
		   if (rmRandInt(1,2) == 1)
 	            rmSetAreaCliffEdge(bigCliffID, 2, 0.36, 0.1, 1.0, 0);
		   else
 	            rmSetAreaCliffEdge(bigCliffID, 3, 0.26, 0.08, 1.0, 0);
		   rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
		   rmSetAreaCliffHeight(bigCliffID, cliffHt, 2.0, 1.0);
		   rmSetAreaCoherence(bigCliffID, rmRandFloat(0.3, 0.5));
		   rmSetAreaSmoothDistance(bigCliffID, 5);
		   rmSetAreaHeightBlend(bigCliffID, 1.0);
	  	   rmSetAreaMinBlobs(bigCliffID, 2);
		   rmSetAreaMaxBlobs(bigCliffID, 2);
		   rmSetAreaMinBlobDistance(bigCliffID, 100.0);
		   rmSetAreaMaxBlobDistance(bigCliffID, 130.0);
	         rmAddAreaConstraint(bigCliffID, circleConstraintMt);
		}
		else if (cliffVariety == 4)  // smooth rock domes
		{
   	         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(200), rmAreaTilesToFraction(400));
		   rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
		   rmSetAreaCliffEdge(bigCliffID, 1, 0.005, 0.01, 1.0, 0);
		   rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
		   rmSetAreaCliffHeight(bigCliffID, rmRandInt(7,8), 2.0, 1.0);
		   rmSetAreaCoherence(bigCliffID, rmRandFloat(0.3, 0.5));
		   rmSetAreaSmoothDistance(bigCliffID, 20);
		   rmSetAreaHeightBlend(bigCliffID, 1.0);
	         rmAddAreaConstraint(bigCliffID, circleConstraintMt);
		}
		else  // kinda random, kinda like Texas or NE
		{
   	         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(800));
		   rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
		   rmSetAreaCliffEdge(bigCliffID, 1, 0.6, 0.1, 1.0, 0);
		   rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
		   rmSetAreaCliffHeight(bigCliffID, cliffHt, 2.0, 1.0);
		   rmSetAreaCoherence(bigCliffID, rmRandFloat(0.4, 0.9));
		   rmSetAreaSmoothDistance(bigCliffID, 15);
		   rmSetAreaHeightBlend(bigCliffID, 1.0);
	  	   rmSetAreaMinBlobs(bigCliffID, 3);
		   rmSetAreaMaxBlobs(bigCliffID, 5);
		   rmSetAreaMinBlobDistance(bigCliffID, 6.0);
		   rmSetAreaMaxBlobDistance(bigCliffID, 20.0);
		}
		rmAddAreaConstraint(bigCliffID, avoidImportantItem);
		rmAddAreaConstraint(bigCliffID, avoidTradeRoute);
            rmAddAreaConstraint(bigCliffID, avoidNatives);
	      rmAddAreaConstraint(bigCliffID, avoidCliffs2);
	      rmAddAreaConstraint(bigCliffID, cliffsAvoidCliffs);
	      rmAddAreaConstraint(bigCliffID, avoidSocket);
	      rmAddAreaConstraint(bigCliffID, longForestConstraint);
	      rmAddAreaConstraint(bigCliffID, avoidStartingUnits);
	      rmAddAreaConstraint(bigCliffID, longPlayerConstraint);
		rmBuildArea(bigCliffID);
         }
      }
   }

// Random ponds
   if (makePonds == 1)
   {
	for (i=0; <cNumberNonGaiaPlayers*2)   
      {
	   int pondID=rmCreateArea("random pond"+i);
	   if (patternChance == 9)
	      rmSetAreaSize(pondID, rmAreaTilesToFraction(300), rmAreaTilesToFraction(750));
	   else if (patternChance == 10)
	      rmSetAreaSize(pondID, rmAreaTilesToFraction(200), rmAreaTilesToFraction(450));
         rmSetAreaWaterType(pondID, pondType);
         rmSetAreaMinBlobs(pondID, 1);
         rmSetAreaMaxBlobs(pondID, 6);
         rmSetAreaMinBlobDistance(pondID, 12.0);
         rmSetAreaMaxBlobDistance(pondID, 35.0);
         rmAddAreaToClass(pondID, lakeClass);
         rmAddAreaConstraint(pondID, avoidLakesFar);
         rmAddAreaConstraint(pondID, longPlayerConstraint);
         rmAddAreaConstraint(pondID, circleConstraint);
         rmAddAreaConstraint(pondID, avoidTradeRoute);
         rmAddAreaConstraint(pondID, avoidSocket);
         rmAddAreaConstraint(pondID, avoidCliffs);
         rmAddAreaConstraint(pondID, avoidCliffs2);
         rmAddAreaConstraint(pondID, avoidCanyons);
         rmAddAreaConstraint(pondID, avoidAll);
         rmAddAreaConstraint(pondID, avoidNativesShort);
         rmSetAreaCoherence(pondID, rmRandFloat(0.1,0.7));
         rmSetAreaWarnFailure(pondID, false);
         rmBuildArea(pondID);
      }
   }

   // Text
   rmSetStatusText("",0.75);

// Extra silver mines - distant, in the middle and near ends of axis.
   silverType = rmRandInt(1,10);
   int extraGoldID = rmCreateObjectDef("extra silver "+i);
   rmAddObjectDefItem(extraGoldID, "mine", 1, 0.0);
   rmAddObjectDefToClass(extraGoldID, rmClassID("importantItem"));
   rmAddObjectDefConstraint(extraGoldID, avoidTradeRoute);
   rmAddObjectDefConstraint(extraGoldID, avoidSocket);
   rmAddObjectDefConstraint(extraGoldID, coinAvoidCoin);
   rmAddObjectDefConstraint(extraGoldID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(extraGoldID, avoidWater10);
   rmAddObjectDefConstraint(extraGoldID, avoidAll);
   rmAddObjectDefConstraint(extraGoldID, avoidCliffsShort);
   rmSetObjectDefMinDistance(extraGoldID, 0.0);
   rmSetObjectDefMaxDistance(extraGoldID, 60.0);
   rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.5, rmRandInt(1, 3));
   if (cNumberNonGaiaPlayers > 4)
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.5, 1);
   if (cNumberNonGaiaPlayers > 6)
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.5, 1);
   if (axisChance == 1)
   {
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.49, 0.78, 1);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.51, 0.22, 1);
   }
   else
   {
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.78, 0.51, 1);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.22, 0.49, 1);
   }

   silverType = rmRandInt(1,10);
   int GoldFarID=rmCreateObjectDef("player silver far");
   rmAddObjectDefItem(GoldFarID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(GoldFarID, avoidTradeRoute);
   rmAddObjectDefConstraint(GoldFarID, avoidSocket);
   rmAddObjectDefConstraint(GoldFarID, coinAvoidCoin);
   rmAddObjectDefConstraint(GoldFarID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldFarID, circleConstraint);
   rmAddObjectDefConstraint(GoldFarID, avoidAll);
   rmAddObjectDefConstraint(GoldFarID, avoidCliffsShort);
   rmAddObjectDefConstraint(GoldFarID, farPlayerConstraint);
   rmAddObjectDefConstraint(GoldFarID, avoidWater10);
   rmSetObjectDefMinDistance(GoldFarID, 75.0);
   rmSetObjectDefMaxDistance(GoldFarID, 100.0);
   rmPlaceObjectDefPerPlayer(GoldFarID, false, rmRandInt(1, 2));

   silverType = rmRandInt(1,10);
   int GoldEdgeID=rmCreateObjectDef("player silver edge");
   rmAddObjectDefItem(GoldEdgeID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(GoldEdgeID, avoidTradeRoute);
   rmAddObjectDefConstraint(GoldEdgeID, avoidSocket);
   rmAddObjectDefConstraint(GoldEdgeID, coinAvoidCoin);
   rmAddObjectDefConstraint(GoldEdgeID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldEdgeID, circleConstraint);
   rmAddObjectDefConstraint(GoldEdgeID, centerConstraintForest);
   rmAddObjectDefConstraint(GoldEdgeID, avoidAll);
   rmAddObjectDefConstraint(GoldEdgeID, avoidCliffsShort);
   rmAddObjectDefConstraint(GoldEdgeID, avoidWater10);
   rmSetObjectDefMinDistance(GoldEdgeID, 105.0);
   rmSetObjectDefMaxDistance(GoldEdgeID, 150.0);
   rmAddObjectDefConstraint(GoldEdgeID, fartherPlayerConstraint);
   rmPlaceObjectDefPerPlayer(GoldEdgeID, false, 1);

   silverType = rmRandInt(1,10);
   int GoldFartherID=rmCreateObjectDef("player silver farther");
   rmAddObjectDefItem(GoldFartherID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(GoldFartherID, avoidTradeRoute);
   rmAddObjectDefConstraint(GoldFartherID, avoidSocket);
   rmAddObjectDefConstraint(GoldFartherID, coinAvoidCoin);
   rmAddObjectDefConstraint(GoldFartherID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldFartherID, circleConstraint);
   rmAddObjectDefConstraint(GoldFartherID, avoidAll);
   rmAddObjectDefConstraint(GoldFartherID, avoidCliffsShort);
   rmAddObjectDefConstraint(GoldFartherID, avoidWater10);
   if (sectionChance > 9)
   {
      rmSetObjectDefMinDistance(GoldFartherID, 160.0);
      rmSetObjectDefMaxDistance(GoldFartherID, 300.0);
      rmAddObjectDefConstraint(GoldFartherID, enormousPlayerConstraint);
   }
   else
   {
      rmSetObjectDefMinDistance(GoldFartherID, 110.0);
      rmSetObjectDefMaxDistance(GoldFartherID, 300.0);
      rmAddObjectDefConstraint(GoldFartherID, fartherPlayerConstraint);
   }
   if (cNumberNonGaiaPlayers < 4)
	rmPlaceObjectDefPerPlayer(GoldFartherID, false, 2);
   else if (cNumberNonGaiaPlayers < 6)
      rmPlaceObjectDefPerPlayer(GoldFartherID, false, 1);

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
   rmAddObjectDefConstraint(nugget2, avoidWater10);
   rmAddObjectDefConstraint(nugget2, avoidAll);
   rmAddObjectDefConstraint(nugget2, circleConstraint);
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
   rmAddObjectDefConstraint(nugget3, avoidWater10);
   rmAddObjectDefConstraint(nugget3, avoidAll);
   rmAddObjectDefConstraint(nugget3, circleConstraint);
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
   rmAddObjectDefConstraint(nugget4, avoidWater10);
   rmAddObjectDefConstraint(nugget4, avoidAll);
   rmAddObjectDefConstraint(nugget4, circleConstraint);
   rmPlaceObjectDefPerPlayer(nugget4, false, 1);

   // Text
   rmSetStatusText("",0.80);

// Lone elk
   int loneElkID=rmCreateObjectDef("lone elk");
      rmAddObjectDefItem(loneElkID, "ypWildElephant", rmRandInt(2,3), 3.0);
   rmAddObjectDefToClass(loneElkID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(loneElkID, 60.0);
   rmSetObjectDefMaxDistance(loneElkID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(loneElkID, nuggetPlayerConstraint);
   rmAddObjectDefConstraint(loneElkID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(loneElkID, avoidNativesShort);
   rmAddObjectDefConstraint(loneElkID, huntableConstraint);
   rmAddObjectDefConstraint(loneElkID, centerConstraintForest);
   rmAddObjectDefConstraint(loneElkID, avoidAll);
   rmSetObjectDefCreateHerd(loneElkID, true);
   rmPlaceObjectDefPerPlayer(loneElkID, false, 3);

// Central herds
   int centralHerdID=rmCreateObjectDef("central herd");  
   rmAddObjectDefItem(centralHerdID, centerHerdType, rmRandInt(12,16), 6.0);
   rmAddObjectDefToClass(centralHerdID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(centralHerdID, rmXFractionToMeters(0.05));
   rmSetObjectDefMaxDistance(centralHerdID, rmXFractionToMeters(0.25));
   rmAddObjectDefConstraint(centralHerdID, avoidTradeRoute);
   rmAddObjectDefConstraint(centralHerdID, avoidImportantItem);
   rmAddObjectDefConstraint(centralHerdID, avoidWater10);
   rmAddObjectDefConstraint(centralHerdID, farPlayerConstraint);
   rmAddObjectDefConstraint(centralHerdID, longHuntableConstraint);
   rmAddObjectDefConstraint(centralHerdID, avoidCliffsShort);
   rmSetObjectDefCreateHerd(centralHerdID, true);
   rmPlaceObjectDefAtLoc(centralHerdID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
   // additional of central herd type
   rmAddObjectDefConstraint(centralHerdID, fartherPlayerConstraint);
   rmSetObjectDefMinDistance(centralHerdID, rmXFractionToMeters(0.25));
   rmSetObjectDefMaxDistance(centralHerdID, rmXFractionToMeters(0.38));
   if (cNumberNonGaiaPlayers < 7)
      rmPlaceObjectDefPerPlayer(centralHerdID, false, 2);
   else
      rmPlaceObjectDefPerPlayer(centralHerdID, false, 1);

// far huntable
   int farHuntableID=rmCreateObjectDef("far huntable");
   rmAddObjectDefItem(farHuntableID, deerType, rmRandInt(4,6), 6.0);
   rmAddObjectDefToClass(farHuntableID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(farHuntableID, rmXFractionToMeters(0.33));
   rmSetObjectDefMaxDistance(farHuntableID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(farHuntableID, avoidTradeRoute);
   rmAddObjectDefConstraint(farHuntableID, avoidImportantItem);
   rmAddObjectDefConstraint(farHuntableID, avoidWater10);
   rmAddObjectDefConstraint(farHuntableID, fartherPlayerConstraint);
   rmAddObjectDefConstraint(farHuntableID, longHuntableConstraint);
   rmAddObjectDefConstraint(farHuntableID, avoidCliffsShort);
   rmAddObjectDefConstraint(farHuntableID, avoidAll);
   rmSetObjectDefCreateHerd(farHuntableID, true);
   rmPlaceObjectDefPerPlayer(farHuntableID, false, 1);

// additional second huntable for low player numbers
//   if (cNumberNonGaiaPlayers < 4)
//   {
      rmAddObjectDefConstraint(farPronghornID, avoidCliffsShort);
      rmAddObjectDefConstraint(farPronghornID, fartherPlayerConstraint);
      rmSetObjectDefMinDistance(farPronghornID, rmXFractionToMeters(0.2));
      rmSetObjectDefMaxDistance(farPronghornID, rmXFractionToMeters(0.35));
      rmPlaceObjectDefPerPlayer(farPronghornID, false, 1);
//   }

// sheep etc
   int sheepID=rmCreateObjectDef("herdable animal");
   rmAddObjectDefItem(sheepID, sheepType, 2, 4.0);
   rmAddObjectDefToClass(sheepID, rmClassID("herdableFood"));
   rmSetObjectDefMinDistance(sheepID, 35.0);
   rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.3));
   rmAddObjectDefConstraint(sheepID, avoidSheep);
   rmAddObjectDefConstraint(sheepID, avoidAll);
   rmAddObjectDefConstraint(sheepID, playerConstraint);
   rmAddObjectDefConstraint(sheepID, avoidCliffsShort);
   rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
//   if (rmRandInt(1,2) == 1)
//      rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);
//   else 
//      rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3); 

   rmAddObjectDefConstraint(sheepID, farPlayerConstraint);
   rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.45));
//   rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3); 

   // Text
   rmSetStatusText("",0.85);

// Random trees
   int StragglerTreeID=rmCreateObjectDef("stragglers");
   rmAddObjectDefItem(StragglerTreeID, treeType, 1, 0.0);
   rmAddObjectDefConstraint(StragglerTreeID, avoidAll);
   rmAddObjectDefConstraint(StragglerTreeID, avoidCliffsShort);
   rmAddObjectDefConstraint(StragglerTreeID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(StragglerTreeID, avoidCoin);
   rmAddObjectDefConstraint(StragglerTreeID, patchConstraint);
//   rmAddObjectDefConstraint(StragglerTreeID, avoidWater10);
//   rmAddObjectDefConstraint(StragglerTreeID, centerConstraintForest2);
   rmSetObjectDefMinDistance(StragglerTreeID, 10.0);
   rmSetObjectDefMaxDistance(StragglerTreeID, rmXFractionToMeters(0.5));
   for(i=0; <cNumberNonGaiaPlayers*45)
      rmPlaceObjectDefAtLoc(StragglerTreeID, 0, 0.5, 0.5);
/*   
// Fish
   int fishID=rmCreateObjectDef("fish");
   int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 26.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 7.0);
   rmAddObjectDefItem(fishID, fishType, 1, 0.0);
   rmSetObjectDefMinDistance(fishID, 0.0);
   rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(fishID, fishVsFishID);
   rmAddObjectDefConstraint(fishID, fishLand);
   if (cNumberNonGaiaPlayers < 4)
      rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, rmRandInt(3,5));
   else
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, rmRandInt(4,6));
*/
   // Text
   rmSetStatusText("",0.90);

// Deco
   // Patches 
/*   if (patternChance == 9)
   {
      for (i=0; <cNumberNonGaiaPlayers*45)   
      {
	   int gpPatch2=rmCreateArea("GP patch 2"+i);
	   rmSetAreaWarnFailure(gpPatch2, false);
	   rmSetAreaSize(gpPatch2, rmAreaTilesToFraction(50), rmAreaTilesToFraction(90));
	   if (rmRandInt(1,2) == 1)
	      rmSetAreaTerrainType(gpPatch2, "wotta\nile\llanos1");
	   else
	      rmSetAreaTerrainType(gpPatch2, "wotta\nile\llanos2");
	   rmAddAreaToClass(gpPatch2, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatch2, 2);
	   rmSetAreaMaxBlobs(gpPatch2, 4);
	   rmSetAreaMinBlobDistance(gpPatch2, 5.0);
	   rmSetAreaMaxBlobDistance(gpPatch2, 12.0);
	   rmSetAreaCoherence(gpPatch2, 0.3);
	   rmSetAreaSmoothDistance(gpPatch2, 10);
	   rmAddAreaConstraint(gpPatch2, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatch2, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatch2, patchConstraint);
	   rmBuildArea(gpPatch2); 
      }
   
      for (i=0; <cNumberNonGaiaPlayers*25)   
      {
	   int gpPatch0=rmCreateArea("GP patch 0"+i);
	   rmSetAreaWarnFailure(gpPatch0, false);
	   rmSetAreaSize(gpPatch0, rmAreaTilesToFraction(60), rmAreaTilesToFraction(90));
	   if (rmRandInt(1,2) > 1)
	      rmSetAreaTerrainType(gpPatch0, "wotta\nile\llanos3");
	   else
	      rmSetAreaTerrainType(gpPatch0, "wotta\nile\llanos4");
	   rmAddAreaToClass(gpPatch0, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatch0, 2);
	   rmSetAreaMaxBlobs(gpPatch0, 4);
	   rmSetAreaMinBlobDistance(gpPatch0, 5.0);
	   rmSetAreaMaxBlobDistance(gpPatch0, 12.0);
	   rmSetAreaCoherence(gpPatch0, 0.3);
	   rmSetAreaSmoothDistance(gpPatch0, 10);
	   rmAddAreaConstraint(gpPatch0, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatch0, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatch0, forestConstraint);
	   rmAddAreaConstraint(gpPatch0, patchConstraint);
	   rmBuildArea(gpPatch0); 
      }

      for (i=0; <cNumberNonGaiaPlayers*28)   
      {
	   int gpPatch1=rmCreateArea("GP patch 1"+i);
	   rmSetAreaWarnFailure(gpPatch1, false);
	   rmSetAreaSize(gpPatch1, rmAreaTilesToFraction(50), rmAreaTilesToFraction(80));
	   if (rmRandInt(1,2) == 1)
	      rmSetAreaTerrainType(gpPatch1, "wotta\nile\llanos3");
	   else
	      rmSetAreaTerrainType(gpPatch1, "wotta\nile\llanos2");
	   rmAddAreaToClass(gpPatch1, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatch1, 2);
	   rmSetAreaMaxBlobs(gpPatch1, 4);
	   rmSetAreaMinBlobDistance(gpPatch1, 12.0);
	   rmSetAreaMaxBlobDistance(gpPatch1, 18.0);
	   rmSetAreaCoherence(gpPatch1, 0.1);
	   rmSetAreaSmoothDistance(gpPatch1, 10);
	   rmAddAreaConstraint(gpPatch1, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatch1, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatch1, patchConstraint);
	   rmBuildArea(gpPatch1); 
      }

      for (i=0; <cNumberNonGaiaPlayers*45)   
      {
	   int gpPatch3=rmCreateArea("GP patch 3"+i);
	   rmSetAreaWarnFailure(gpPatch3, false);
	   rmSetAreaSize(gpPatch3, rmAreaTilesToFraction(50), rmAreaTilesToFraction(90));
	   if (rmRandInt(1,2) == 1)
	      rmSetAreaTerrainType(gpPatch3, "wotta\nile\llanos1");
	   else
	      rmSetAreaTerrainType(gpPatch3, "wotta\nile\llanos5");
	   rmAddAreaToClass(gpPatch3, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatch3, 2);
	   rmSetAreaMaxBlobs(gpPatch3, 4);
	   rmSetAreaMinBlobDistance(gpPatch3, 5.0);
	   rmSetAreaMaxBlobDistance(gpPatch3, 12.0);
	   rmSetAreaCoherence(gpPatch3, 0.3);
	   rmSetAreaSmoothDistance(gpPatch3, 10);
	   rmAddAreaConstraint(gpPatch3, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatch3, avoidCliffsShort);
	   rmBuildArea(gpPatch3); 
      }
   }

   if (patternChance == 10)
   {
      for (i=0; <cNumberNonGaiaPlayers*45) // edge green patch   
      {
	   int gpPatchB=rmCreateArea("GP patch B"+i);
	   rmSetAreaWarnFailure(gpPatchB, false);
	   rmSetAreaSize(gpPatchB, rmAreaTilesToFraction(90), rmAreaTilesToFraction(160));
         rmSetAreaTerrainType(gpPatchB, "wotta\nile\llanos4");
	   rmAddAreaToClass(gpPatchB, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatchB, 2);
	   rmSetAreaMaxBlobs(gpPatchB, 4);
	   rmSetAreaMinBlobDistance(gpPatchB, 10.0);
	   rmSetAreaMaxBlobDistance(gpPatchB, 20.0);
	   rmSetAreaCoherence(gpPatchB, rmRandFloat(0.1,0.4));
	   rmSetAreaSmoothDistance(gpPatchB, 10);
	   rmAddAreaConstraint(gpPatchB, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatchB, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatchB, centerConstraintForest);
	   rmAddAreaConstraint(gpPatchB, patchConstraint);
	   rmBuildArea(gpPatchB); 
      }

      for (i=0; <cNumberNonGaiaPlayers*30)   
      {
	   int gpPatchA=rmCreateArea("GP patch A"+i);
	   rmSetAreaWarnFailure(gpPatchA, false);
	   rmSetAreaSize(gpPatchA, rmAreaTilesToFraction(75), rmAreaTilesToFraction(140));
         rmSetAreaTerrainType(gpPatchA, "wotta\nile\llanos3");
	   rmAddAreaToClass(gpPatchA, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatchA, 2);
	   rmSetAreaMaxBlobs(gpPatchA, 4);
	   rmSetAreaMinBlobDistance(gpPatchA, 5.0);
	   rmSetAreaMaxBlobDistance(gpPatchA, 12.0);
	   rmSetAreaCoherence(gpPatchA, 0.3);
	   rmSetAreaSmoothDistance(gpPatchA, 10);
	   rmAddAreaConstraint(gpPatchA, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatchA, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatchA, patchConstraint);
	   rmBuildArea(gpPatchA); 
      }

      for (i=0; <cNumberNonGaiaPlayers*25)   // little green patches
      {
	   int gpPatchC=rmCreateArea("GP patch C"+i);
	   rmSetAreaWarnFailure(gpPatchC, false);
	   rmSetAreaSize(gpPatchC, rmAreaTilesToFraction(15), rmAreaTilesToFraction(40));
         rmSetAreaTerrainType(gpPatchC, "wotta\nile\llanos5");
	   rmAddAreaToClass(gpPatchC, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatchC, 2);
	   rmSetAreaMaxBlobs(gpPatchC, 4);
	   rmSetAreaMinBlobDistance(gpPatchC, 5.0);
	   rmSetAreaMaxBlobDistance(gpPatchC, 10.0);
	   rmSetAreaCoherence(gpPatchC, 0.1);
	   rmSetAreaSmoothDistance(gpPatchC, 10);
	   rmAddAreaConstraint(gpPatchC, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatchC, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatchC, patchConstraint);
	   rmBuildArea(gpPatchC); 
      }

      for (i=0; <cNumberNonGaiaPlayers*35)   
      {
	   int gpPatchD=rmCreateArea("GP patch D"+i);
	   rmSetAreaWarnFailure(gpPatchD, false);
	   rmSetAreaSize(gpPatchD, rmAreaTilesToFraction(50), rmAreaTilesToFraction(70));
         rmSetAreaTerrainType(gpPatchD, "wotta\nile\llanos5");
	   rmAddAreaToClass(gpPatchD, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatchD, 3);
	   rmSetAreaMaxBlobs(gpPatchD, 5);
	   rmSetAreaMinBlobDistance(gpPatchD, 12.0);
	   rmSetAreaMaxBlobDistance(gpPatchD, 20.0);
	   rmSetAreaCoherence(gpPatchD, 0.1);
	   rmSetAreaSmoothDistance(gpPatchD, 10);
	   rmAddAreaConstraint(gpPatchD, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatchD, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatchD, patchConstraint);
	   rmBuildArea(gpPatchD); 
      }
   }*/

   // Text
   rmSetStatusText("",0.95);

/*   // Grasses
   int flowerPatchGroupType=-1;
   int flowerPatchGroup=-1;
   int grassPatchGroupType=-1;
   int grassPatchGroup=-1;
   int greenGrassGroup=-1;

   if (patternChance == 9)
   {
	for(i=1; <5*cNumberNonGaiaPlayers)
      {
		grassPatchGroupType=rmRandInt(2, 3);
		greenGrassGroup=rmCreateGrouping("Green Grass Group"+i, "gp_bigpatch0"+grassPatchGroupType);
		rmSetGroupingMinDistance(greenGrassGroup, 0.0);
		rmSetGroupingMaxDistance(greenGrassGroup, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(greenGrassGroup, avoidImpassableLand);
		rmAddGroupingConstraint(greenGrassGroup, playerConstraint);
		rmAddGroupingConstraint(greenGrassGroup, avoidTradeRoute);
		rmAddGroupingConstraint(greenGrassGroup, avoidSocket);
		rmAddGroupingConstraint(greenGrassGroup, avoidNativesTiny);
		rmAddGroupingConstraint(greenGrassGroup, avoidNuggetSmall);
		rmAddGroupingConstraint(greenGrassGroup, circleConstraint);
		rmAddGroupingConstraint(greenGrassGroup, avoidStartingUnits);
		rmAddGroupingConstraint(greenGrassGroup, avoidAll);
		rmAddGroupingConstraint(greenGrassGroup, avoidCliffsShort);
		rmPlaceGroupingAtLoc(greenGrassGroup, 0, 0.5, 0.5, 2);
	}

	for(i=1; <55*cNumberNonGaiaPlayers)
      {
		flowerPatchGroupType=rmRandInt(1, 8);
		flowerPatchGroup=rmCreateGrouping("Flower Patch Group"+i, "gp_flower0"+flowerPatchGroupType);
		rmSetGroupingMinDistance(flowerPatchGroup, 0.0);
		rmSetGroupingMaxDistance(flowerPatchGroup, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(flowerPatchGroup, avoidImpassableLand);
		rmAddGroupingConstraint(flowerPatchGroup, playerConstraint);
		rmAddGroupingConstraint(flowerPatchGroup, avoidTradeRoute);
		rmAddGroupingConstraint(flowerPatchGroup, avoidSocket);
		rmAddGroupingConstraint(flowerPatchGroup, avoidNativesTiny);
		rmAddGroupingConstraint(flowerPatchGroup, avoidNuggetSmall);
		rmAddGroupingConstraint(flowerPatchGroup, avoidAll);
		rmAddGroupingConstraint(flowerPatchGroup, avoidCliffsShort);
		rmAddGroupingConstraint(flowerPatchGroup, circleConstraint);
		rmAddGroupingConstraint(flowerPatchGroup, avoidStartingUnits);
		rmPlaceGroupingAtLoc(flowerPatchGroup, 0, 0.5, 0.5, 2);
	}

	for(i=1; <55*cNumberNonGaiaPlayers)
      {
		grassPatchGroupType=rmRandInt(1, 7);
		grassPatchGroup=rmCreateGrouping("Grass Patch Group"+i, "gp_grasspatch0"+grassPatchGroupType);
		rmSetGroupingMinDistance(grassPatchGroup, 0.0);
		rmSetGroupingMaxDistance(grassPatchGroup, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(grassPatchGroup, avoidImpassableLand);
		rmAddGroupingConstraint(grassPatchGroup, playerConstraint);
		rmAddGroupingConstraint(grassPatchGroup, avoidTradeRoute);
		rmAddGroupingConstraint(grassPatchGroup, avoidSocket);
		rmAddGroupingConstraint(grassPatchGroup, avoidNativesTiny);
		rmAddGroupingConstraint(grassPatchGroup, avoidNuggetSmall);
		rmAddGroupingConstraint(grassPatchGroup, circleConstraint);
		rmAddGroupingConstraint(grassPatchGroup, avoidStartingUnits);
		rmAddGroupingConstraint(grassPatchGroup, avoidAll);
		rmAddGroupingConstraint(grassPatchGroup, avoidCliffsShort);
		rmPlaceGroupingAtLoc(grassPatchGroup, 0, 0.5, 0.5, 2);
	}
   }

   if (patternChance == 10)
   {
	for(i=1; <35*cNumberNonGaiaPlayers) // green at periphery
      {
		flowerPatchGroupType=rmRandInt(1, 8);
		flowerPatchGroup=rmCreateGrouping("Flower Patch Group"+i, "gp_flower0"+flowerPatchGroupType);
		rmSetGroupingMinDistance(flowerPatchGroup, 0.0);
		rmSetGroupingMaxDistance(flowerPatchGroup, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(flowerPatchGroup, avoidImpassableLand);
		rmAddGroupingConstraint(flowerPatchGroup, playerConstraint);
		rmAddGroupingConstraint(flowerPatchGroup, avoidTradeRoute);
		rmAddGroupingConstraint(flowerPatchGroup, avoidSocket);
		rmAddGroupingConstraint(flowerPatchGroup, avoidNativesTiny);
		rmAddGroupingConstraint(flowerPatchGroup, avoidNuggetSmall);
		rmAddGroupingConstraint(flowerPatchGroup, avoidAll);
		rmAddGroupingConstraint(flowerPatchGroup, avoidCliffsShort);
		rmAddGroupingConstraint(flowerPatchGroup, centerConstraintForest);
		rmAddGroupingConstraint(flowerPatchGroup, avoidStartingUnits);
		rmPlaceGroupingAtLoc(flowerPatchGroup, 0, 0.5, 0.5, 2);
	}

	int dryGrassGroup=-1;
	for(i=1; <5*cNumberNonGaiaPlayers)
      {
		grassPatchGroupType=rmRandInt(4, 9);
		dryGrassGroup=rmCreateGrouping("Dry Grass Group"+i, "gp_dry_bigpatch0"+grassPatchGroupType);
		rmSetGroupingMinDistance(dryGrassGroup, 0.0);
		rmSetGroupingMaxDistance(dryGrassGroup, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(dryGrassGroup, avoidImpassableLand);
		rmAddGroupingConstraint(dryGrassGroup, playerConstraint);
		rmAddGroupingConstraint(dryGrassGroup, avoidTradeRoute);
		rmAddGroupingConstraint(dryGrassGroup, avoidSocket);
		rmAddGroupingConstraint(dryGrassGroup, avoidNativesTiny);
		rmAddGroupingConstraint(dryGrassGroup, avoidNuggetSmall);
		rmAddGroupingConstraint(dryGrassGroup, circleConstraintMt);
		rmAddGroupingConstraint(dryGrassGroup, avoidStartingUnits);
		rmAddGroupingConstraint(dryGrassGroup, avoidAll);
		rmAddGroupingConstraint(dryGrassGroup, avoidCliffsShort);
		rmPlaceGroupingAtLoc(dryGrassGroup, 0, 0.5, 0.5, 1);
	}

	numTries=16*cNumberNonGaiaPlayers;
	failCount=0;
	for (i=0; <numTries)
	{   
		int grassyArea=rmCreateArea("grassyArea"+i);
		rmSetAreaWarnFailure(grassyArea, false);
		rmSetAreaSize(grassyArea, rmAreaTilesToFraction(200), rmAreaTilesToFraction(600));
		rmSetAreaForestType(grassyArea, "AfricanRainForest");
		rmSetAreaForestDensity(grassyArea, 0.6);
		rmSetAreaForestClumpiness(grassyArea, 0.2);
		rmAddAreaConstraint(grassyArea, avoidTradeRoute);
		rmAddAreaConstraint(grassyArea, avoidSocket);
		rmAddAreaConstraint(grassyArea, avoidAll);
		rmAddAreaConstraint(grassyArea, forestsAvoidBison);
		rmAddAreaConstraint(grassyArea, avoidNativesTiny);
		rmAddAreaConstraint(grassyArea, avoidStartingUnits);
		rmAddAreaConstraint(grassyArea, avoidCliffsShort);
		rmAddAreaConstraint(grassyArea, playerConstraint);
		rmAddAreaConstraint(grassyArea, avoidNuggetSmall);
		rmAddAreaConstraint(grassyArea, circleConstraintMt);
		if(rmBuildArea(grassyArea)==false)
		{
			// Stop trying once we fail 5 times in a row.
			failCount++;
			if(failCount==5)
				break;
		}
		else
			failCount=0; 
	}

	numTries=30*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{   
		int grassyArea2=rmCreateArea("smallGrassyArea"+i);
		rmSetAreaWarnFailure(grassyArea2, false);
		rmSetAreaSize(grassyArea2, rmAreaTilesToFraction(50), rmAreaTilesToFraction(70));
		rmSetAreaForestType(grassyArea2, "AfricanRainForest");
		rmSetAreaForestDensity(grassyArea2, 0.6);
		rmSetAreaForestClumpiness(grassyArea2, 0.5);
		rmAddAreaConstraint(grassyArea2, avoidTradeRoute);
		rmAddAreaConstraint(grassyArea2, avoidSocket);
		rmAddAreaConstraint(grassyArea2, avoidAll);
		rmAddAreaConstraint(grassyArea2, forestsAvoidBison);
		rmAddAreaConstraint(grassyArea2, avoidNativesTiny);
		rmAddAreaConstraint(grassyArea2, avoidStartingUnits);
		rmAddAreaConstraint(grassyArea2, avoidCliffsShort);
		rmAddAreaConstraint(grassyArea2, playerConstraint);
		rmAddAreaConstraint(grassyArea2, avoidNuggetSmall);
		rmAddAreaConstraint(grassyArea2, circleConstraintMt);
		rmBuildArea(grassyArea2);
	}
   }
/*
   // props
   if (patternChance == 10)
   {
   int bisonCarcass=rmCreateGrouping("Bison Carcass", "gp_carcass_bison");
   rmAddGroupingToClass(bisonCarcass, rmClassID("propClass"));
   rmSetGroupingMinDistance(bisonCarcass, 0.0);
   rmSetGroupingMaxDistance(bisonCarcass, rmXFractionToMeters(0.4));
   rmAddGroupingConstraint(bisonCarcass, avoidImpassableLand);
   rmAddGroupingConstraint(bisonCarcass, playerConstraint);
   rmAddGroupingConstraint(bisonCarcass, avoidTradeRoute);
   rmAddGroupingConstraint(bisonCarcass, avoidSocket);
   rmAddGroupingConstraint(bisonCarcass, avoidStartingUnits);
   rmAddGroupingConstraint(bisonCarcass, avoidAll);
   rmAddGroupingConstraint(bisonCarcass, avoidCliffs);
   rmAddGroupingConstraint(bisonCarcass, avoidNuggetSmall);
   rmAddGroupingConstraint(bisonCarcass, avoidProp);
   rmPlaceGroupingAtLoc(bisonCarcass, 0, 0.5, 0.5, rmRandInt(2,3));
   }

   int vultureID=rmCreateObjectDef("perching vultures");
   rmAddObjectDefItem(vultureID, "PropVulturePerching", 1, 0.0);
   rmAddObjectDefToClass(vultureID, rmClassID("propClass"));
   rmSetObjectDefMinDistance(vultureID, 0.0);
   rmSetObjectDefMaxDistance(vultureID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(vultureID, avoidAll);
   rmAddObjectDefConstraint(vultureID, avoidImportantItem);
   rmAddObjectDefConstraint(vultureID, avoidCoin);
   rmAddObjectDefConstraint(vultureID, avoidImpassableLand);
   rmAddObjectDefConstraint(vultureID, avoidTradeRoute);
   rmAddObjectDefConstraint(vultureID, avoidCliffsShort);
   rmAddObjectDefConstraint(vultureID, avoidProp);
   rmAddObjectDefConstraint(vultureID, longPlayerConstraint);
   rmPlaceObjectDefAtLoc(vultureID, 0, 0.5, 0.5, 2);

   int randomEagleTreeID=rmCreateObjectDef("random eagle tree");
   rmAddObjectDefItem(randomEagleTreeID, "EaglesNest", 1, 0.0);
   rmAddObjectDefToClass(randomEagleTreeID, rmClassID("propClass"));
   rmSetObjectDefMinDistance(randomEagleTreeID, 0.0);
   rmSetObjectDefMaxDistance(randomEagleTreeID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(randomEagleTreeID, avoidAll);
   rmAddObjectDefConstraint(randomEagleTreeID, avoidCliffsShort);
   rmAddObjectDefConstraint(randomEagleTreeID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(randomEagleTreeID, avoidProp);
   rmPlaceObjectDefAtLoc(randomEagleTreeID, 0, 0.5, 0.5, 3);
*/
   rmCreateTrigger("Blackmap");
   rmSwitchToTrigger(rmTriggerID("Blackmap"));
   rmAddTriggerCondition("Timer ms");
   rmSetTriggerConditionParamInt("Param1", 500);
   rmSetTriggerActive(true);
   rmSetTriggerLoop(true);
   rmAddTriggerEffect("Reset All Blackmap");
   
   // Text
   rmSetStatusText("",0.99);

}  

  
