// Thanksgiving III
// a random map for AOE3: The War Chiefs
// must have patch 1.01 installed to play!!
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
   string riverType = "";
   string treeType = "";
   string deerType = "";
   string deer2Type = "";
   string sheepType = "";
   string centerHerdType = "";
   string fishType = "";
   string scatteredDeerType = "";  

// Set up for natives to appear on the map
   int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;

   if (rmAllocateSubCivs(3) == true)
   {
	subCiv0=rmGetCivID("Huron");
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Huron");

	subCiv1=rmGetCivID("Iroquois");
      if (subCiv1 >= 0)
         rmSetSubCiv(1, "Iroquois"); 

	subCiv2=rmGetCivID("Cherokee");
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Cherokee");
   }

// Pick pattern for trees, terrain, features, etc.
   int patternChance = 1;   
   int variantChance = rmRandInt(1,2);
   int lightingChance = rmRandInt(1,2);
   int trPattern = rmRandInt(1,4);
   int socketPattern = rmRandInt(1,2);   
   int nativeSetup = rmRandInt(1,6);
   if (cNumberNonGaiaPlayers == 2)
      nativeSetup = rmRandInt(1,8); 
   int nativePattern = rmRandInt(1,3);   
   int nativeChance = rmRandInt(1,2);
   int endPosition = rmRandInt(1,3);
   int sidePosition = rmRandInt(1,3);
   int sheepChance = rmRandInt(1,2);
   int featureChance = rmRandInt(1,10);
   int cliffChance = rmRandInt(1,10);
   int makeCliffs = -1; 
   int cliffVariety = rmRandInt(0,5);
   int makeRiver = -1;
   int hillTrees = -1;
   int placeBerries = 1;
   int baseHt = -1;
   int makePatch = -1;
   int forestDist = rmRandInt(10,14);
   int circChance = rmRandInt(1,5);

// Picks the map size
   int playerTiles=16000;  
   if (cNumberNonGaiaPlayers > 7)
	playerTiles = 10500;  
   else if (cNumberNonGaiaPlayers > 5)
	playerTiles = 12000;  
   else if (cNumberNonGaiaPlayers > 3)
	playerTiles = 13500; 
   else if (cNumberNonGaiaPlayers == 3)
	playerTiles = 14500; 

   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

// Elevation
   int elevationChance = rmRandInt(1,4);
  // rmSetMapElevationParameters(long type, float minFrequency, long numberOctaves, float persistence, float heightVariation)

   if (elevationChance == 1)
   {
	rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.7, 5.0);
	rmSetMapElevationHeightBlend(1.0);
   }
   else if (elevationChance == 2)
   {
	rmSetMapElevationParameters(cElevTurbulence, 0.02, 3, 0.5, 8.0);
	rmSetMapElevationHeightBlend(1.0);
   }  
   else if (elevationChance == 3)
   {
	rmSetMapElevationParameters(cElevTurbulence, 0.1, 5, 0.2, 5.0);
	rmSetMapElevationHeightBlend(0.9);
   }
   else if (elevationChance == 4)
   {
	rmSetMapElevationParameters(cElevTurbulence, 0.1, 4, 0.2, 3.0);
	rmSetMapElevationHeightBlend(0.8);
   }

   rmSetSeaLevel(0.0);
	
// Pick terrain patterns and features 
   if (patternChance == 1) // NE
   {   
      rmSetSeaType("new england coast");
      rmSetMapType("plymouth");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("paris");
	else
	   rmSetLightingSet("new england");

      baseHt = rmRandFloat(1,3);
      baseType = "newengland_grass";
	forestType = "new england forest";
	riverType = "Hudson Bay";
      cliffType = "New England Inland Grass";
	treeType = "TreeNewEngland";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "turkey";
         centerHerdType = "turkey";
	   scatteredDeerType = "moose";         
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "turkey";
         centerHerdType = "turkey";
	   scatteredDeerType = "deer";         
	}
      if (sheepChance == 1)
         sheepType = "sheep";
      else
         sheepType = "cow";
      fishType = "FishSalmon";
      hillTrees = rmRandInt(0,1);
      makeRiver = 1;
	if (cliffChance > 2)
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
   rmDefineClass("classPatch");
   rmDefineClass("startingUnit");
   rmDefineClass("classForest");
   rmDefineClass("importantItem");
   rmDefineClass("natives");
   rmDefineClass("classCliff");
   rmDefineClass("center");
   rmDefineClass("classNugget");
   rmDefineClass("socketClass");
   int classHuntable=rmDefineClass("huntableFood");   
   int classHerdable=rmDefineClass("herdableFood"); 
   int canyon=rmDefineClass("canyon");

   // Text
   rmSetStatusText("",0.10);

// -------------Define constraints
   // Map edge constraints
   int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
   int secondEdgeConstraint=rmCreateBoxConstraint("bison edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
   int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
   int circleConstraintMt=rmCreatePieConstraint("circle Constraint for mts", 0.5, 0.5, 0, rmZFractionToMeters(0.2), rmDegreesToRadians(0), rmDegreesToRadians(360));

   // Center constraints
   int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 30.0);
   int centerConstraintShort=rmCreateClassDistanceConstraint("stay away from center short", rmClassID("center"), 12.0);
   int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 70.0);
   int centerConstraintForest=rmCreateClassDistanceConstraint("stay away from center forest", rmClassID("center"), rmZFractionToMeters(0.24));
   int centerConstraintForest2=rmCreateClassDistanceConstraint("stay away from center forest 2", rmClassID("center"), rmZFractionToMeters(0.22));
   int centerConstraintForest3=rmCreateClassDistanceConstraint("stay away from center forest 3", rmClassID("center"), rmZFractionToMeters(0.22));
   int centerConstraintForest4=rmCreateClassDistanceConstraint("stay away from center forest 4", rmClassID("center"), rmZFractionToMeters(0.20));

   // Player constraints
   int playerConstraintForest=rmCreateClassDistanceConstraint("forests kinda stay away from players", classPlayer, 15.0);
   int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 40.0);
   int playerConstraintNative=rmCreateClassDistanceConstraint("natives stay away from players", classPlayer, 37.0);
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
   int forestsAvoidBison=rmCreateClassDistanceConstraint("forest avoids bison", rmClassID("huntableFood"), 15.0);
   int avoidDucks=rmCreateTypeDistanceConstraint("avoids ducks", "DuckFamily", 50.0);

   // Avoid impassable land, certain features
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
   int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 18.0);
   int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 8.0);
   int avoidCliffs=rmCreateClassDistanceConstraint("stuff vs. cliff", rmClassID("classCliff"), 12.0);
   int cliffsAvoidCliffs=rmCreateClassDistanceConstraint("cliffs vs. cliffs", rmClassID("classCliff"), 30.0);
   int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water mid-long", "Land", false, 10.0);
   int avoidWater15 = rmCreateTerrainDistanceConstraint("avoid water mid-longer", "Land", false, 15.0);
   int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water a little more", "Land", false, 20.0);
   int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 30.0);
   int avoidCanyons=rmCreateClassDistanceConstraint("avoid canyons", rmClassID("canyon"), 35.0);
   int shortAvoidCanyons=rmCreateClassDistanceConstraint("short avoid canyons", rmClassID("canyon"), 15.0);
  
   // Unit avoidance
   int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 30.0);
   int avoidStartingUnitsSmall=rmCreateClassDistanceConstraint("objects avoid starting units small", rmClassID("startingUnit"), 10.0);
   int avoidStartingUnitsLarge=rmCreateClassDistanceConstraint("objects avoid starting units large", rmClassID("startingUnit"), 50.0);
   int avoidImportantItem=rmCreateClassDistanceConstraint("things avoid each other", rmClassID("importantItem"), 10.0);
   int avoidImportantItemSmall=rmCreateClassDistanceConstraint("important item small avoidance", rmClassID("importantItem"), 7.0);
   int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 60.0);
   int avoidNativesMed=rmCreateClassDistanceConstraint("stuff avoids natives medium", rmClassID("natives"), 30.0);
   int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives shorter", rmClassID("natives"), 15.0);
   int avoidNugget=rmCreateClassDistanceConstraint("nugget vs. nugget", rmClassID("classNugget"), 35.0);
   int avoidNuggetMed=rmCreateClassDistanceConstraint("nugget vs. nugget med", rmClassID("classNugget"), 42.0);
   int avoidNuggetLong=rmCreateClassDistanceConstraint("nugget vs. nugget long", rmClassID("classNugget"), 55.0);
   int avoidNuggetSmall=rmCreateClassDistanceConstraint("avoid nuggets by a little", rmClassID("classNugget"), 16.0);
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

   // Trade route avoidance.
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 8.0);
   int avoidTradeRouteCliff = rmCreateTradeRouteDistanceConstraint("trade route cliff", 10.0);
   int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 20.0);
   int avoidSocket=rmCreateClassDistanceConstraint("avoid sockets", rmClassID("socketClass"), 10.0);

   // Cardinal Directions - "halves" of the map.
   int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(272), rmDegreesToRadians(88));
   int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(92), rmDegreesToRadians(268));
   int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(2), rmDegreesToRadians(178));
   int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(182), rmDegreesToRadians(358));

// End of constraints ------------------------------------------------------------------------------------------------

   // Text
   rmSetStatusText("",0.15);

// Set up for axis and player side, player position
   int axisChance = rmRandInt(1,2);
   int playerSide = rmRandInt(1,2);   
   int distChance = rmRandInt(1,8);

   if (trPattern == 1)
      distChance = rmRandInt(1,6);

   if (trPattern == 2) 
	distChance = rmRandInt(1,7);

   if (trPattern == 3)
	distChance = rmRandInt(5,8);

   if (trPattern == 4)
	distChance = rmRandInt(1,5);

   int sectionChance = rmRandInt(1,3);
   int ffaChance = rmRandInt(1,4);

// Set up player starting locations
if (cNumberNonGaiaPlayers == 2)
{
   sectionChance = rmRandInt(1,11);
   if (trPattern == 4)
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
             rmSetPlacementSection(0.39, 0.41);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);

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
             rmSetPlacementSection(0.59, 0.61);
	    else if (sectionChance == 11)
             rmSetPlacementSection(0.89, 0.91);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);
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
             rmSetPlacementSection(0.34, 0.36);
	    else if (sectionChance == 11)
             rmSetPlacementSection(0.64, 0.66);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);

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
             rmSetPlacementSection(0.14, 0.16);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);
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
             rmSetPlacementSection(0.20, 0.30);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.18, 0.32);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.17, 0.33);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.16, 0.34);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.16, 0.30);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.20, 0.34);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.70, 0.80);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.68, 0.82);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.67, 0.83);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.66, 0.84);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.66, 0.80);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.70, 0.84);          

  	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);
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
             rmSetPlacementSection(0.45, 0.55);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.43, 0.57);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.42, 0.58);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.41, 0.59);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.41, 0.55);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.45, 0.59);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.95, 0.05);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.93, 0.07);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.92, 0.08);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.91, 0.09);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.91, 0.05);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.95, 0.09);

 	    if (distChance == 0)
	       rmPlacePlayersCircular(0.45, 0.46, 0.0);
	    else if (distChance == 1)
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);
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
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);

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
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);
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
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);

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
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);
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
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);

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
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);
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
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);

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
	       rmPlacePlayersCircular(0.43, 0.44, 0.0);
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
	       rmPlacePlayersCircular(0.30, 0.31, 0.0);
        }
      }
   }
   else  // for FFA or over 2 teams
   {
      if (cNumberNonGaiaPlayers == 3) 
      {
        if (axisChance == 1)
        {
		if (ffaChance == 1)
		{
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.11, 0.12);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.38, 0.39);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.75, 0.76);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		}
		else if (ffaChance == 2)
		{
	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.11, 0.12);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.38, 0.39);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(0);
            rmSetPlacementSection(0.75, 0.76);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		}		
		else if (ffaChance == 3) 
		{
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.11, 0.12);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(1);
            rmSetPlacementSection(0.38, 0.39);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(2);
            rmSetPlacementSection(0.76, 0.76);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		}
		else
            { 
		rmSetPlacementTeam(0);
            rmSetPlacementSection(0.25, 0.26);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.61, 0.62);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(1);
            rmSetPlacementSection(0.88, 0.89);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
            }
	  }
        else if (axisChance == 2)
        {
		if (ffaChance == 1)
		{
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.36, 0.37);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.63, 0.64);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.0, 0.01);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		}
		else if (ffaChance == 2)
		{
	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.36, 0.37);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.63, 0.64);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(0);
            rmSetPlacementSection(0.0, 0.01);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		}		
		else if (ffaChance == 3) 
		{
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.36, 0.37);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(1);
            rmSetPlacementSection(0.63, 0.64);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(2);
            rmSetPlacementSection(0.0, 0.01);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		}
		else
            { 
		rmSetPlacementTeam(0);
            rmSetPlacementSection(0.50, 0.51);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(2);
            rmSetPlacementSection(0.86, 0.87);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(1);
            rmSetPlacementSection(0.13, 0.14);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
            }
	  }
      }
      else if (cNumberNonGaiaPlayers == 4) 
      {
        if (axisChance == 1)
        {
		if (ffaChance == 1)
		{
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.11, 0.12);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.38, 0.39);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.61, 0.62);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(3);
            rmSetPlacementSection(0.88, 0.89);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		}
		else if (ffaChance == 2)
		{
	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.11, 0.12);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.38, 0.39);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(3);
            rmSetPlacementSection(0.61, 0.62);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(0);
            rmSetPlacementSection(0.88, 0.89);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		}		
		else if (ffaChance == 3) 
		{
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.11, 0.12);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(1);
            rmSetPlacementSection(0.38, 0.39);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(2);
            rmSetPlacementSection(0.61, 0.62);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(3);
            rmSetPlacementSection(0.88, 0.89);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		}
		else
            { 
	  	rmSetPlacementTeam(3);
            rmSetPlacementSection(0.11, 0.12);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.38, 0.39);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.61, 0.62);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(1);
            rmSetPlacementSection(0.88, 0.89);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
            }
	  }
        else if (axisChance == 2)
        {
		if (ffaChance == 1)
		{
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.36, 0.37);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.63, 0.64);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.86, 0.87);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(3);
            rmSetPlacementSection(0.13, 0.14);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		}
		else if (ffaChance == 2)
		{
	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.36, 0.37);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.63, 0.64);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(3);
            rmSetPlacementSection(0.86, 0.87);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(0);
            rmSetPlacementSection(0.13, 0.14);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		}		
		else if (ffaChance == 3) 
		{
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.36, 0.37);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(1);
            rmSetPlacementSection(0.63, 0.64);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(2);
            rmSetPlacementSection(0.86, 0.87);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(3);
            rmSetPlacementSection(0.13, 0.14);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		}
		else
            { 
	  	rmSetPlacementTeam(3);
            rmSetPlacementSection(0.36, 0.37);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.63, 0.64);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.86, 0.87);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(1);
            rmSetPlacementSection(0.13, 0.14);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
            }
	  }
	}
      else if (cNumberNonGaiaPlayers < 7) 
      {
        if (axisChance == 1)
        {
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.11, 0.12);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.38, 0.39);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(4);
            rmSetPlacementSection(0.25, 0.26);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);

	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.61, 0.62);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(3);
            rmSetPlacementSection(0.88, 0.89);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(5);
            rmSetPlacementSection(0.75, 0.76);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  }
	  else if (axisChance == 2)
        {
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.36, 0.37);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.63, 0.64);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(4);
            rmSetPlacementSection(0.50, 0.51);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);

	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.86, 0.87);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(3);
            rmSetPlacementSection(0.13, 0.14);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(5);
            rmSetPlacementSection(0.00, 0.01);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  }
      }
      else if (cNumberNonGaiaPlayers == 7) 
      {
        if (axisChance == 1)
        {
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.11, 0.12);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.38, 0.39);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(4);
            rmSetPlacementSection(0.20, 0.21);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(6);
            rmSetPlacementSection(0.29, 0.30);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);

	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.61, 0.62);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(3);
            rmSetPlacementSection(0.88, 0.89);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(5);
            rmSetPlacementSection(0.75, 0.76);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  }
	  else if (axisChance == 2)
        {
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.36, 0.37);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.63, 0.64);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(4);
            rmSetPlacementSection(0.45, 0.46);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(6);
            rmSetPlacementSection(0.54, 0.55);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);

	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.86, 0.87);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(3);
            rmSetPlacementSection(0.13, 0.14);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(5);
            rmSetPlacementSection(0.00, 0.01);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  }
      }
      else if (cNumberNonGaiaPlayers == 8) 
      {
        if (axisChance == 1)
        {
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.11, 0.12);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.38, 0.39);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(4);
            rmSetPlacementSection(0.20, 0.21);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(6);
            rmSetPlacementSection(0.29, 0.30);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);

	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.61, 0.62);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(3);
            rmSetPlacementSection(0.88, 0.89);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(5);
            rmSetPlacementSection(0.70, 0.71);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(7);
            rmSetPlacementSection(0.79, 0.80);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  }
	  else if (axisChance == 2)
        {
	  	rmSetPlacementTeam(0);
            rmSetPlacementSection(0.36, 0.37);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(2);
            rmSetPlacementSection(0.63, 0.64);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(4);
            rmSetPlacementSection(0.45, 0.46);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(6);
            rmSetPlacementSection(0.54, 0.55);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);

	  	rmSetPlacementTeam(1);
            rmSetPlacementSection(0.86, 0.87);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(3);
            rmSetPlacementSection(0.13, 0.14);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  	rmSetPlacementTeam(5);
            rmSetPlacementSection(0.95, 0.96);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
		rmSetPlacementTeam(7);
            rmSetPlacementSection(0.04, 0.05);
		rmPlacePlayersCircular(0.36, 0.37, 0.0);
	  }
      }
   }
}

   // Text
   rmSetStatusText("",0.20);
	
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

   // Text
   rmSetStatusText("",0.25);

// The River
   int riverWidthChance = rmRandInt(1,3);
   int rivermin = -1;
   int rivermax = -1;
   int shallowPattern = rmRandInt(1,6);
   if (cNumberNonGaiaPlayers < 4)
   {
 	if (shallowPattern == 2)
	   shallowPattern = rmRandInt(3,6);
   }

   if (riverWidthChance == 1)
   {
	rivermin = 7;
	rivermax = 9;
   }
   else if (riverWidthChance == 2)
   {
      rivermin = 8;
	rivermax = 10;
   }
   else
   {
      rivermin = 9;
	rivermax = 11;
   }

   if (makeRiver == 1)  
   {
	int singleRiver = rmRiverCreate(-1, riverType, 30, 10, rivermin, rivermax); 
	if (axisChance == 1)
	   rmRiverSetConnections(singleRiver, 0.5, 0.0, 0.5, 1.0);
	else
	   rmRiverSetConnections(singleRiver, 0.0, 0.5, 1.0, 0.5);

	if (shallowPattern == 6) // single larger centered 
	{
	   rmRiverSetShallowRadius(singleRiver, rmRandInt(15, 21));
	   rmRiverAddShallow(singleRiver, rmRandFloat(0.4, 0.6));
	}
	else
	{
	 if (shallowPattern < 3) // .4 and .6 crossings for 1 and 2
	 {	
	   rmRiverSetShallowRadius(singleRiver, rmRandInt(7, 11));
	   rmRiverAddShallow(singleRiver, rmRandFloat(0.34, 0.42)); 

	   rmRiverSetShallowRadius(singleRiver, rmRandInt(7, 11));
	   rmRiverAddShallow(singleRiver, rmRandFloat(0.58, 0.66));
	 }

	 if (shallowPattern < 4) // end crossings, for 2-3
	 {
	   if (shallowPattern >1)
	   {	
	      rmRiverSetShallowRadius(singleRiver, rmRandInt(7, 11));
	      rmRiverAddShallow(singleRiver, rmRandFloat(0.06, 0.2)); 

	      rmRiverSetShallowRadius(singleRiver, rmRandInt(7, 11));
	      rmRiverAddShallow(singleRiver, rmRandFloat(0.8, 0.94));
	   }
	 }

	 if (shallowPattern > 3) // end crossings for 4, 5
	 {	
	   rmRiverSetShallowRadius(singleRiver, rmRandInt(8, 13));
	   rmRiverAddShallow(singleRiver, rmRandFloat(0.1, 0.29)); 

	   rmRiverSetShallowRadius(singleRiver, rmRandInt(8, 13));
	   rmRiverAddShallow(singleRiver, rmRandFloat(0.71, 0.9));
	 }

	 if (shallowPattern > 2) // center for patterns 3, 4
	 {
	   if (shallowPattern < 5)
	   {	
	      rmRiverSetShallowRadius(singleRiver, rmRandInt(7, 11));
	      rmRiverAddShallow(singleRiver, rmRandFloat(0.45, 0.55));
	   }
	 }
	}
	rmRiverSetBankNoiseParams(singleRiver, 0.07, 2, 1.5, 10.0, 0.667, 3.0); 
	rmRiverBuild(singleRiver);
   }

   // Text
   rmSetStatusText("",0.30);

// Trade Routes
if (trPattern == 2) // 2 opposite inner semicircular routes
{
   // first route
   int tradeRouteID = rmCreateTradeRoute();
   if (axisChance == 1) 
   {	
	rmAddTradeRouteWaypoint(tradeRouteID, 0.59, 0.81);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.64, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.68, 0.65);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.73, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.68, 0.35);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.64, 0.25);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.59, 0.19);
   }
   else 
   {	
	rmAddTradeRouteWaypoint(tradeRouteID, 0.19, 0.59);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.25, 0.64);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.68);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.73);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.68);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.75, 0.64);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.81, 0.59);
   }
   rmBuildTradeRoute(tradeRouteID, "dirt");

   // second route
   int tradeRouteID2 = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.41, 0.19);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.36, 0.25);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.32, 0.35);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.27, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.32, 0.65);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.36, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.41, 0.81);
   }
   else
   {
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.19, 0.41);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.25, 0.36);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.35, 0.32);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.27);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.65, 0.32);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.75, 0.36);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.81, 0.41);
   }
   rmBuildTradeRoute(tradeRouteID2, "carolinas\trade_route");	
}
else if (trPattern == 3)  // 2 'semi-circular' outside routes
{
   int tradeRouteID9 = rmCreateTradeRoute();
   if (axisChance == 2)
   {
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.0, 0.585); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.07, 0.6); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.12, 0.68); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.19, 0.81);  
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.32, 0.89);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.5, 0.92); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.68, 0.89);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.81, 0.81); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.88, 0.68);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.93, 0.6); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 1.0, 0.585);
   }
   else
   {
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.585, 1.0); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.6, 0.93); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.68, 0.88);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.81, 0.81);  
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.89, 0.7);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.92, 0.5);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.89, 0.3);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.81, 0.19);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.68, 0.12);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.6, 0.07); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.585, 0.0); 
   }
   rmBuildTradeRoute(tradeRouteID9, "carolinas\trade_route");

   // second route
   int tradeRouteID9A = rmCreateTradeRoute();
   if (axisChance == 2)
   { 
      rmAddTradeRouteWaypoint(tradeRouteID9A, 1.0, 0.415);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.94, 0.4);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.89, 0.32);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.81, 0.19);   
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.68, 0.10);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.5, 0.07);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.32, 0.10);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.195, 0.195);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.11, 0.32); 
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.06, 0.4);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.0, 0.415); 
   }
   else
   {
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.415, 0.0);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.4, 0.06);   
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.32, 0.11);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.195, 0.195);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.10, 0.32);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.07, 0.5); 
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.10, 0.68); 
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.19, 0.81);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.32, 0.89);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.4, 0.94); 
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.415, 1.0);  
   }
   rmBuildTradeRoute(tradeRouteID9A, "dirt");
}
else if (trPattern == 4)  // two 'diagonal'
{
   int tradeRouteID4 = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.67, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.61, 0.65);
      rmAddTradeRouteWaypoint(tradeRouteID4, 0.63, 0.55);
      rmAddTradeRouteWaypoint(tradeRouteID4, 0.63, 0.45);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.61, 0.35);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.67, 0.0);
   }
   else if (axisChance == 2) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID4, 1.0, 0.67);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.6, 0.61);
      rmAddTradeRouteWaypoint(tradeRouteID4, 0.55, 0.63);
      rmAddTradeRouteWaypoint(tradeRouteID4, 0.45, 0.63);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.4, 0.61);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.0, 0.67);
   }
   rmBuildTradeRoute(tradeRouteID4, "carolinas\trade_route");

   int tradeRouteID4A = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
      rmAddTradeRouteWaypoint(tradeRouteID4A, 0.33, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.39, 0.65);
      rmAddTradeRouteWaypoint(tradeRouteID4A, 0.37, 0.55);
      rmAddTradeRouteWaypoint(tradeRouteID4A, 0.37, 0.45);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.39, 0.35);
      rmAddTradeRouteWaypoint(tradeRouteID4A, 0.33, 0.0);
   }
   else if (axisChance == 2) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID4A, 1.0, 0.33);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.62, 0.39);
      rmAddTradeRouteWaypoint(tradeRouteID4A, 0.55, 0.37);
      rmAddTradeRouteWaypoint(tradeRouteID4A, 0.45, 0.37);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.38, 0.39);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.0, 0.33);
   }
   rmBuildTradeRoute(tradeRouteID4A, "dirt");
}
else if (trPattern == 1)  // 2 'semicircular' middle routes
{
   int tradeRouteID1 = rmCreateTradeRoute();
   int tradeRouteID1A = rmCreateTradeRoute();
   if (axisChance == 2)
   {
	if (cNumberNonGaiaPlayers < 4)
	   rmAddTradeRouteWaypoint(tradeRouteID1, 0.165, 0.59);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID1, 0.165, 0.56);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.25, 0.74);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.5, 0.835);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.74, 0.75);
	if (cNumberNonGaiaPlayers < 4)
	   rmAddTradeRouteWaypoint(tradeRouteID1, 0.835, 0.59);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID1, 0.835, 0.56);
      
      rmBuildTradeRoute(tradeRouteID1, "carolinas\trade_route");	

	if (cNumberNonGaiaPlayers < 4)
	   rmAddTradeRouteWaypoint(tradeRouteID1A, 0.835, 0.41);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID1A, 0.835, 0.44);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.74, 0.25);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.5, 0.165);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.25, 0.26);
	if (cNumberNonGaiaPlayers < 4)
	   rmAddTradeRouteWaypoint(tradeRouteID1A, 0.165, 0.41);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID1A, 0.165, 0.44);
      rmBuildTradeRoute(tradeRouteID1A, "dirt");
   }
   else if (axisChance == 1)
   {
	if (cNumberNonGaiaPlayers < 4)
	   rmAddTradeRouteWaypoint(tradeRouteID1, 0.59, 0.835);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID1, 0.56, 0.835);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.74, 0.75);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.835, 0.5);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.75, 0.26);
	if (cNumberNonGaiaPlayers < 4)
	   rmAddTradeRouteWaypoint(tradeRouteID1, 0.59, 0.165);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID1, 0.56, 0.165);
      rmBuildTradeRoute(tradeRouteID1, "carolinas\trade_route");	

	if (cNumberNonGaiaPlayers < 4)
	   rmAddTradeRouteWaypoint(tradeRouteID1A, 0.41, 0.165);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID1A, 0.44, 0.165);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.26, 0.25);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.165, 0.5);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.25, 0.74);
	if (cNumberNonGaiaPlayers < 4)
	   rmAddTradeRouteWaypoint(tradeRouteID1A, 0.41, 0.835);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID1A, 0.44, 0.835);
      rmBuildTradeRoute(tradeRouteID1A, "dirt");
   }
}

   // Text
   rmSetStatusText("",0.35);

// Trade sockets
   int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
   rmSetObjectDefAllowOverlap(socketID, true);
   rmAddObjectDefToClass(socketID, rmClassID("importantItem"));
   rmSetObjectDefMinDistance(socketID, 0.0);
   rmSetObjectDefMaxDistance(socketID, 6.0);

if (trPattern == 2) // 2 opposite inner semicircular routes
{
   // add the meeting poles along the trade route.
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
   vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.17);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   if (socketPattern == 1)
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }

   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.83);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   // change the trade route for the new sockets
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID2);
   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID2, 0.83);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   if (socketPattern == 1)
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID2, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }

   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID2, 0.17);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
}
else if (trPattern == 3) // 2 outside semi-circles
{
   if (socketPattern == 1) // 6 sockets
   { 
      if (variantChance == 1)
	{
          rmSetObjectDefTradeRouteID(socketID, tradeRouteID9);
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.2);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.5);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.8);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          // change the trade route for the new sockets
          rmSetObjectDefTradeRouteID(socketID, tradeRouteID9A);
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.2);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.5);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
 
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.8);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	 }
	 else
	 {
          rmSetObjectDefTradeRouteID(socketID, tradeRouteID9);
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.25);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.5);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.75);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          // change the trade route for the new sockets
          rmSetObjectDefTradeRouteID(socketID, tradeRouteID9A);
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.25);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.5);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.75);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	 }
   }
   else if (socketPattern == 2) // 8 sockets
   { 
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID9);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.15);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.38);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.62);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.85);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      // change the trade route for the new sockets
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID9A);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.15);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.38);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.62);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.85);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
}
else if (trPattern == 4) //  2 diagonal
{
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID4);

   if (socketPattern == 1)
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.12);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.88);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   else
   {
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.17);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.83);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }

   // change the trade route for the new sockets
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID4A);
   if (socketPattern == 1)
   {
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.88);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
  
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.12);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   else
   {
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.83);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.17);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
}
else if (trPattern == 1) //  2 mid semicircles
{
   if (socketPattern == 1)
   { 
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID1);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.15);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.85);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      // change the trade route for the new sockets
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID1A);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.15);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.85);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   if (socketPattern == 2)
   { 
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID1);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.11);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.37);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.63);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.89);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      // change the trade route for the new sockets
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID1A);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.11);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.37);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.63);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.89);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
}

   //Text
   rmSetStatusText("",0.40);

// Starting TCs and units 
/* Each player gets 3 thanksgiving crates of food.  This adds 3 crates of food to all players.  Each player gets 4 pilgrims in addition to their usual starting villagers. */

   int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
   rmSetObjectDefMinDistance(startingUnits, 5.0);
   rmSetObjectDefMaxDistance(startingUnits, 10.0);
   rmAddObjectDefConstraint(startingUnits, avoidAll);
   rmAddObjectDefConstraint(startingUnits, avoidWater10);

   int startingTCID= rmCreateObjectDef("startingTC");
   rmSetObjectDefMaxDistance(startingTCID, 18.0);
   rmAddObjectDefConstraint(startingTCID, avoidAll);
   rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);
   rmAddObjectDefConstraint(startingTCID, longAvoidImpassableLand);  

   int foodChoice = rmRandInt(1,5);
   int playerCrateID=rmCreateObjectDef("bonus starting crates");
   if (foodChoice == 1)
      rmAddObjectDefItem(playerCrateID, "crateOfTurkey", 3, 4.0);
   else if (foodChoice == 2)
   {
      rmAddObjectDefItem(playerCrateID, "crateOfWheatBundle", 1, 4.0);
      rmAddObjectDefItem(playerCrateID, "crateOfTurkey", 2, 4.0);
   }
   else if (foodChoice == 3)
   {
      rmAddObjectDefItem(playerCrateID, "crateOfSquash", 1, 4.0);
      rmAddObjectDefItem(playerCrateID, "crateOfTurkey", 2, 4.0);
   }
   else if (foodChoice == 4)
   {
      rmAddObjectDefItem(playerCrateID, "crateOfSquash", 1, 4.0);
      rmAddObjectDefItem(playerCrateID, "crateOfTurkey", 1, 4.0);
      rmAddObjectDefItem(playerCrateID, "crateOfWheatBundle", 1, 4.0);
   }
   else if (foodChoice == 5)
   {
      rmAddObjectDefItem(playerCrateID, "crateOfTurkeyLarge", 1, 4.0);
   }
   rmSetObjectDefMinDistance(playerCrateID, 6);
   rmSetObjectDefMaxDistance(playerCrateID, 10);
   rmAddObjectDefConstraint(playerCrateID, avoidAll);
   rmAddObjectDefConstraint(playerCrateID, shortAvoidImpassableLand);

   int pilgrimsID = rmCreateObjectDef("player pilgrims");
   rmAddObjectDefItem(pilgrimsID, "Pilgrim", 4, 7.0);
   rmAddObjectDefItem(pilgrimsID, "PropsTable", 1, 5.0);
   rmSetObjectDefMinDistance(pilgrimsID, 7.0);
   rmSetObjectDefMaxDistance(pilgrimsID, 13.0);
   rmAddObjectDefConstraint(pilgrimsID, avoidAll);
   rmAddObjectDefConstraint(pilgrimsID, shortAvoidImpassableLand);

   int playerScoutID = rmCreateObjectDef("player scout");
   rmAddObjectDefItem(playerScoutID, "TurkeyScout", 1, 0);
   rmSetObjectDefMinDistance(playerScoutID, 7.0);
   rmSetObjectDefMaxDistance(playerScoutID, 12.0);
   rmAddObjectDefConstraint(playerScoutID, avoidAll);
   rmAddObjectDefConstraint(playerScoutID, shortAvoidImpassableLand);
              
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
      rmPlaceObjectDefAtLoc(pilgrimsID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
      rmPlaceObjectDefAtLoc(playerCrateID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
      rmPlaceObjectDefAtLoc(playerScoutID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }

   // Text
   rmSetStatusText("",0.45);

// Central features & patches, per map or variant
   // Center area
   int centerArea=rmCreateArea("TheCenter");
   rmSetAreaSize(centerArea, 0.2, 0.2);
   rmSetAreaLocation(centerArea, 0.5, 0.5);
   rmAddAreaToClass(centerArea, rmClassID("center")); 

// NATIVE AMERICANS
   // Village A 
   int villageAID = -1;
   int whichNative = rmRandInt(1,2);
   int villageType = rmRandInt(1,5);

   if (nativePattern == 1)
   {
      if (whichNative == 1)
	   villageAID = rmCreateGrouping("village A", "native cherokee village "+villageType);
      else if (whichNative == 2)
	   villageAID = rmCreateGrouping("village A", "native iroquois village "+villageType);
   }
   if (nativePattern == 2)
   {
      if (whichNative == 1)
	   villageAID = rmCreateGrouping("village A", "native huron village "+villageType);
      else if (whichNative == 2)
	   villageAID = rmCreateGrouping("village A", "native iroquois village "+villageType);
   }
   if (nativePattern == 3)
   {
      if (whichNative == 1)
	   villageAID = rmCreateGrouping("village A", "native cherokee village "+villageType);
      else if (whichNative == 2)
	   villageAID = rmCreateGrouping("village A", "native huron village "+villageType);
   }
   rmAddGroupingToClass(villageAID, rmClassID("natives"));
   rmAddGroupingToClass(villageAID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageAID, 0.0);
   rmSetGroupingMaxDistance(villageAID, rmXFractionToMeters(0.14));
   rmAddGroupingConstraint(villageAID, avoidImpassableLand);
   rmAddGroupingConstraint(villageAID, avoidTradeRoute);
   rmAddGroupingConstraint(villageAID, avoidWater10);
   rmAddGroupingConstraint(villageAID, avoidSocket);
   rmAddGroupingConstraint(villageAID, avoidNativesMed);
   rmAddGroupingConstraint(villageAID, playerConstraintNative);

   // Village D - same or opposite type from A 
   int villageDID = -1;
   whichNative = rmRandInt(1,2);
   villageType = rmRandInt(1,5);

   if (nativePattern == 1)
   {
      if (whichNative == 2)
 	   villageDID = rmCreateGrouping("village D", "native cherokee village "+villageType);
      else if (whichNative == 1)
	   villageDID = rmCreateGrouping("village D", "native iroquois village "+villageType);
   }
   if (nativePattern == 2)
   {
      if (whichNative == 2)
	   villageDID = rmCreateGrouping("village D", "native huron village "+villageType);
      else if (whichNative == 1)
	   villageDID = rmCreateGrouping("village D", "native iroquois village "+villageType);
   }
   if (nativePattern == 3)
   {
      if (whichNative == 2)
	   villageDID = rmCreateGrouping("village D", "native cherokee village "+villageType);
      else if (whichNative == 1)
	   villageDID = rmCreateGrouping("village D", "native huron village "+villageType);
   }
   rmAddGroupingToClass(villageDID, rmClassID("natives"));
   rmAddGroupingToClass(villageDID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageDID, 0.0);
   rmSetGroupingMaxDistance(villageDID, rmXFractionToMeters(0.14));
   rmAddGroupingConstraint(villageDID, avoidImpassableLand);
   rmAddGroupingConstraint(villageDID, avoidTradeRoute);
   rmAddGroupingConstraint(villageDID, avoidWater15);
   rmAddGroupingConstraint(villageDID, avoidSocket);
   rmAddGroupingConstraint(villageDID, avoidNativesMed);
   rmAddGroupingConstraint(villageDID, playerConstraintNative);

// Placement of Native Americans
   if (trPattern == 1)
	endPosition = 3;
   if (trPattern == 2)
	endPosition = rmRandInt(2,3);
   if (trPattern == 3)
	endPosition = 1;

   if (trPattern == 4)
   {
	if (cNumberNonGaiaPlayers < 4) 
	   nativeSetup = rmRandInt(3,8);
	else
	   nativeSetup = rmRandInt(3,6);
   }

   if (nativeSetup < 3)
   {
      if (axisChance == 1)
	{
	   if (endPosition == 1)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.59, 0.73);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.41, 0.73);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.59, 0.27);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.41, 0.27);
	   }
	   else if (endPosition == 2)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.59, 0.82);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.41, 0.82);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.59, 0.18);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.41, 0.18);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.59, 0.91);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.41, 0.91);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.59, 0.10);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.41, 0.10);
	   }
	}	 
      else
	{
	   if (endPosition == 1)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.73, 0.59);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.73, 0.41);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.27, 0.59);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.27, 0.41);
	   }
	   else if (endPosition == 2)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.82, 0.59);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.82, 0.41);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.18, 0.59);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.18, 0.41);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.91, 0.59);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.91, 0.41);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.10, 0.59);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.10, 0.41);
	   }
	}
   }
   else if (nativeSetup == 3)
   {
      if (axisChance == 1)
	{
	   if (trPattern == 4)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.75, 0.5);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.25, 0.5);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.73, 0.5);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.27, 0.5); 
	   }
      }
	else
	{
	   if (trPattern == 4)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.75);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.25);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.73);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.27);
	   } 
	}
   }
   else if (nativeSetup == 4)
   {
      if (axisChance == 1)
	{
	   if (trPattern == 4)
	   {  
            rmPlaceGroupingAtLoc(villageAID, 0, 0.74, 0.42);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.26, 0.42);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.74, 0.58);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.26, 0.58);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.71, 0.42);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.29, 0.42);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.71, 0.58);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.29, 0.58);
	   }
      }
	else
	{
	   if (trPattern == 4)
	   {  
            rmPlaceGroupingAtLoc(villageAID, 0, 0.42, 0.74);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.42, 0.26);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.58, 0.74);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.58, 0.26);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.42, 0.71);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.42, 0.29);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.58, 0.71);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.58, 0.29);
	   }	   
	}
   } 
   else if (nativeSetup == 5)
   {
      if (axisChance == 1)
	{
	   if (trPattern == 4)
	   {  
            rmPlaceGroupingAtLoc(villageDID, 0, 0.74, 0.42);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.26, 0.42);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.74, 0.58);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.26, 0.58);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.71, 0.42);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.29, 0.42);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.71, 0.58);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.29, 0.58);
	   }
      }
	else
	{
	   if (trPattern == 4)
	   {  
            rmPlaceGroupingAtLoc(villageDID, 0, 0.42, 0.74);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.42, 0.26);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.58, 0.74);
		rmPlaceGroupingAtLoc(villageDID, 0, 0.58, 0.26);
	   }
	   else
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.42, 0.71);
		rmPlaceGroupingAtLoc(villageAID, 0, 0.42, 0.29);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.58, 0.71);
		rmPlaceGroupingAtLoc(villageDID, 0, 0.58, 0.29);
	   }
	}
   } 
   else if (nativeSetup > 5) // Setups 6,7,8
   {
      for(i=1; <cNumberPlayers) 
      {
         rmSetGroupingMinDistance(villageAID, 42.0);
         rmSetGroupingMaxDistance(villageAID, 70.0);           
	   rmPlaceGroupingAtLoc(villageAID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	   if (nativeSetup == 7)
		rmPlaceGroupingAtLoc(villageAID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	   if (nativeSetup == 8)
	   {
            rmSetGroupingMinDistance(villageDID, 42.0);
            rmSetGroupingMaxDistance(villageDID, 70.0);      
		rmPlaceGroupingAtLoc(villageDID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
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
   rmAddObjectDefConstraint(playerNuggetID, avoidAll);
   rmAddObjectDefConstraint(playerNuggetID, circleConstraint);

   for(i=1; <cNumberPlayers)
   {
 	rmSetNuggetDifficulty(1, 1);
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }

   rmSetObjectDefMinDistance(playerNuggetID, 45.0);
   rmSetObjectDefMaxDistance(playerNuggetID, 55.0);
   for(i=1; <cNumberPlayers)
   {
 	rmSetNuggetDifficulty(2, 2);
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }

   // Text
   rmSetStatusText("",0.55);

// Cliffs
   int cliffHt = -1;
   int failCount=0;
   int numTries=cNumberNonGaiaPlayers*2;

   int anotherChance = -1;
   anotherChance = rmRandInt(0,1);

   if (makeCliffs == 2)
   {
     if (anotherChance == 1)
        makeCliffs = 1;
     else
        makeCliffs = 0;
   } 

   if (makeCliffs == 1)
   { 
      if (cliffVariety == 0) // a little like AOM Anatolia
	{
	   int gorgeHt=rmRandInt(-7,-4);
	   numTries = 2;
	   if (cNumberNonGaiaPlayers > 5)
	      numTries = 3;

	   for(i=0; <numTries)
	   {
	   int gorgeID=rmCreateArea("gorge"+i);
         rmSetAreaWarnFailure(gorgeID, false); 
	   rmSetAreaSize(gorgeID, rmAreaTilesToFraction(1500), rmAreaTilesToFraction(1800));
	   rmSetAreaCliffType(gorgeID, cliffType);
	   rmAddAreaToClass(gorgeID, rmClassID("classCliff"));
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
	   rmSetAreaMinBlobDistance(gorgeID, 16.0);
	   rmSetAreaMaxBlobDistance(gorgeID, 20.0);
	   rmSetAreaCoherence(gorgeID, rmRandFloat(0.0,0.2));
	   rmSetAreaSmoothDistance(gorgeID, rmRandInt(10,20));
	   rmSetAreaCliffHeight(gorgeID, gorgeHt, 1.0, 1.0);
	   rmSetAreaHeightBlend(gorgeID, 2);
	   rmAddAreaConstraint(gorgeID, cliffsAvoidCliffs);
         rmAddAreaConstraint(gorgeID, avoidImportantItem);
	   rmAddAreaConstraint(gorgeID, avoidTradeRoute);
         rmAddAreaConstraint(gorgeID, avoidNatives);
	   rmAddAreaConstraint(gorgeID, avoidWater20);
	   rmAddAreaConstraint(gorgeID, avoidSocket);
	   rmAddAreaConstraint(gorgeID, avoidStartingUnits);
	   rmAddAreaConstraint(gorgeID, farPlayerConstraint);
	   rmAddAreaConstraint(gorgeID, secondEdgeConstraint);
 	   rmBuildArea(gorgeID);
	   }
      }
      else // all other maps with cliffs
      {
         int numCliffs = rmRandInt(4,5);
	   if (cliffVariety == 2)
		   numCliffs = rmRandInt(5,7);

         for (i=0; <numCliffs)
         {
		cliffHt = rmRandInt(5,7);    
		int bigCliffID=rmCreateArea("big cliff" +i);
		rmSetAreaWarnFailure(bigCliffID, false);
		rmSetAreaCliffType(bigCliffID, cliffType);
		rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
		if (cliffVariety == 1) // like Patagonia
		{
   	         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(550), rmAreaTilesToFraction(750));
      	   rmSetAreaCliffEdge(bigCliffID, 2, 0.35, 0.1, 1.0, 0);
      	   rmSetAreaCliffPainting(bigCliffID, false, true, true, 1.5, true);
		   rmSetAreaCliffHeight(bigCliffID, 7, 2.0, 0.5);
		   rmSetAreaCoherence(bigCliffID, 0.5);
		   rmSetAreaSmoothDistance(bigCliffID, 5);
		   rmSetAreaHeightBlend(bigCliffID, 1.0);
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
		}
		rmSetAreaMinBlobs(bigCliffID, 3);
		rmSetAreaMaxBlobs(bigCliffID, 5);
		rmSetAreaMinBlobDistance(bigCliffID, 5.0);
		rmSetAreaMaxBlobDistance(bigCliffID, 18.0);
		rmAddAreaConstraint(bigCliffID, avoidImportantItem);
		rmAddAreaConstraint(bigCliffID, avoidTradeRoute);
            rmAddAreaConstraint(bigCliffID, avoidNatives);
	      rmAddAreaConstraint(bigCliffID, avoidWater20);
	      rmAddAreaConstraint(bigCliffID, cliffsAvoidCliffs);
	      rmAddAreaConstraint(bigCliffID, avoidSocket);
	      rmAddAreaConstraint(bigCliffID, avoidStartingUnits);
	      rmAddAreaConstraint(bigCliffID, longPlayerConstraint);
		rmBuildArea(bigCliffID);
         }
      }
   }

   // Text
   rmSetStatusText("",0.60);

// Special Thanksgiving Nuggets
   int spNugget1= rmCreateObjectDef("nugget special 1"); 
   rmAddObjectDefItem(spNugget1, "NuggetPumpkinBig", 1, 0.0);
   rmSetNuggetDifficulty(2, 2);
   rmAddObjectDefToClass(spNugget1, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(spNugget1, 80.0);
   rmSetObjectDefMaxDistance(spNugget1, rmXFractionToMeters(0.6));
   rmAddObjectDefConstraint(spNugget1, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(spNugget1, avoidSocket);
   rmAddObjectDefConstraint(spNugget1, avoidTradeRoute);
   rmAddObjectDefConstraint(spNugget1, longPlayerConstraint);
   rmAddObjectDefConstraint(spNugget1, avoidNuggetMed);
   rmAddObjectDefConstraint(spNugget1, circleConstraint);
   rmAddObjectDefConstraint(spNugget1, avoidWater10);
   rmAddObjectDefConstraint(spNugget1, avoidAll);
   rmPlaceObjectDefPerPlayer(spNugget1, false, 2);

   int nugget3= rmCreateObjectDef("nugget hard"); 
   rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(3, 3);
   rmAddObjectDefToClass(nugget3, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(nugget3, 80.0);
   rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.6));
   rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget3, avoidSocket);
   rmAddObjectDefConstraint(nugget3, avoidTradeRoute);
   rmAddObjectDefConstraint(nugget3, longPlayerConstraint);
   rmAddObjectDefConstraint(nugget3, avoidNuggetMed);
   rmAddObjectDefConstraint(nugget3, circleConstraint);
   rmAddObjectDefConstraint(nugget3, avoidWater10);
   rmAddObjectDefConstraint(nugget3, avoidAll);
   rmPlaceObjectDefPerPlayer(nugget3, false, 2);

// Pumpkin patches
   int punkinPatchID = rmCreateObjectDef("pumpkin patch"); 
   rmAddObjectDefItem(punkinPatchID, "PropsHUGEPumpkin", 1, 1.0);
   rmAddObjectDefItem(punkinPatchID, "crateOfSquash", 1, 6.0);
   rmAddObjectDefItem(punkinPatchID, "PropsPlymouth", 2, 7.0);
   rmAddObjectDefToClass(punkinPatchID, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(punkinPatchID, 40.0);
   rmSetObjectDefMaxDistance(punkinPatchID, 45.0);
   rmAddObjectDefConstraint(punkinPatchID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(punkinPatchID, avoidSocket);
   rmAddObjectDefConstraint(punkinPatchID, avoidTradeRoute);
   rmAddObjectDefConstraint(punkinPatchID, circleConstraint);
   rmAddObjectDefConstraint(punkinPatchID, avoidWater10);
   rmAddObjectDefConstraint(punkinPatchID, avoidNuggetSmall);
   rmAddObjectDefConstraint(punkinPatchID, avoidAll);
   rmPlaceObjectDefPerPlayer(punkinPatchID, false, 1);

   rmAddObjectDefConstraint(punkinPatchID, nuggetPlayerConstraint);
   rmSetObjectDefMinDistance(punkinPatchID, 50.0);
   rmSetObjectDefMaxDistance(punkinPatchID, 75.0);
   if (axisChance == 1)
   {
      rmPlaceObjectDefAtLoc(punkinPatchID, 0, 0.35, 0.5, 2);
      rmPlaceObjectDefAtLoc(punkinPatchID, 0, 0.65, 0.5, 2);
   }
   else
   {
      rmPlaceObjectDefAtLoc(punkinPatchID, 0, 0.5, 0.35, 2);
      rmPlaceObjectDefAtLoc(punkinPatchID, 0, 0.5, 0.65, 2);
   }

   // more easy nuggets
   rmAddObjectDefConstraint(nugget3, longPlayerConstraint);
   rmSetObjectDefMinDistance(nugget3, 70.0);
   rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.5));
   rmSetNuggetDifficulty(1, 1);
   rmPlaceObjectDefPerPlayer(nugget3, false, 2);
   rmSetNuggetDifficulty(2, 2);
   rmPlaceObjectDefPerPlayer(nugget3, false, 1);

// add possible New England style nuggets

   rmSetMapType("newEngland");  // enable saloon units as well

   int nugget2= rmCreateObjectDef("nugget medium"); 
   rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(2, 2);
   rmAddObjectDefToClass(nugget2, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(nugget2, 60.0);
   rmSetObjectDefMaxDistance(nugget2, 100.0);
   rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget2, avoidSocket);
   rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
   rmAddObjectDefConstraint(nugget2, nuggetPlayerConstraint);
   rmAddObjectDefConstraint(nugget2, avoidNuggetMed);
   rmAddObjectDefConstraint(nugget2, circleConstraint);
   rmAddObjectDefConstraint(nugget2, avoidWater10);
   rmAddObjectDefConstraint(nugget2, avoidAll);
   rmPlaceObjectDefPerPlayer(nugget2, false, 1);

   int nugget4= rmCreateObjectDef("nugget nuts"); 
   rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(4, 4);
   rmAddObjectDefToClass(nugget4, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(nugget4, 80.0);
   rmSetObjectDefMaxDistance(nugget4, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(nugget4, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget4, avoidSocket);
   rmAddObjectDefConstraint(nugget4, avoidTradeRoute);
   rmAddObjectDefConstraint(nugget4, farPlayerConstraint);
   rmAddObjectDefConstraint(nugget4, avoidNuggetMed);
   rmAddObjectDefConstraint(nugget4, circleConstraint);
   rmAddObjectDefConstraint(nugget4, avoidWater10);
   rmAddObjectDefConstraint(nugget4, avoidAll);
   rmPlaceObjectDefPerPlayer(nugget4, false, 1);

   // Text
   rmSetStatusText("",0.65);

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
   rmAddObjectDefConstraint(StartBerryBushID, avoidAll);
   rmPlaceObjectDefPerPlayer(StartBerryBushID, false, 1);

// start area huntable
   int deerNum = rmRandInt(4, 6);
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
   if (cNumberNonGaiaPlayers < 5)
   {
      rmAddObjectDefConstraint(farPronghornID, farPlayerConstraint);
      rmSetObjectDefMinDistance(farPronghornID, rmXFractionToMeters(0.25));
      rmSetObjectDefMaxDistance(farPronghornID, rmXFractionToMeters(0.35));
      rmPlaceObjectDefPerPlayer(farPronghornID, false, 1);
   }

   // Text
   rmSetStatusText("",0.70);

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
   rmAddObjectDefConstraint(playerGoldID, avoidWater20);
   rmSetObjectDefMinDistance(playerGoldID, 18.0);
   rmSetObjectDefMaxDistance(playerGoldID, 23.0);
   rmPlaceObjectDefPerPlayer(playerGoldID, false, 1);
   if (rmRandInt(1,4) == 1)
      rmPlaceObjectDefPerPlayer(playerGoldID, false, 1);

   silverType = rmRandInt(1,10);
   int GoldMediumID=rmCreateObjectDef("player silver med");
   rmAddObjectDefItem(GoldMediumID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(GoldMediumID, avoidTradeRoute);
   rmAddObjectDefConstraint(GoldMediumID, avoidSocket);
   rmAddObjectDefConstraint(GoldMediumID, coinAvoidCoin);
   rmAddObjectDefConstraint(GoldMediumID, shortAvoidCanyons);
   rmAddObjectDefConstraint(GoldMediumID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldMediumID, playerConstraint);
   rmAddObjectDefConstraint(GoldMediumID, circleConstraint);
   rmAddObjectDefConstraint(GoldMediumID, avoidAll);
   rmAddObjectDefConstraint(GoldMediumID, avoidWater10);
   rmSetObjectDefMinDistance(GoldMediumID, 40.0);
   rmSetObjectDefMaxDistance(GoldMediumID, 55.0);
   rmPlaceObjectDefPerPlayer(GoldMediumID, false, 1);

// Extra tree clumps near players - to ensure fair access to wood
   int extraTreesID=rmCreateObjectDef("extra trees");
   rmAddObjectDefItem(extraTreesID, treeType, 5, 5.0);
   rmSetObjectDefMinDistance(extraTreesID, 16);
   rmSetObjectDefMaxDistance(extraTreesID, 19);
   rmAddObjectDefConstraint(extraTreesID, avoidAll);
   rmAddObjectDefConstraint(extraTreesID, avoidCoin);
   rmAddObjectDefConstraint(extraTreesID, avoidSocket);
   rmAddObjectDefConstraint(extraTreesID, avoidTradeRoute);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(extraTreesID, 0, rmAreaID("player"+i), 1);

   int extraTrees2ID=rmCreateObjectDef("more extra trees");
   rmAddObjectDefItem(extraTrees2ID, treeType, 6, 6.0);
   rmSetObjectDefMinDistance(extraTrees2ID, 18);
   rmSetObjectDefMaxDistance(extraTrees2ID, 28);
   rmAddObjectDefConstraint(extraTrees2ID, avoidAll);
   rmAddObjectDefConstraint(extraTrees2ID, avoidCoin);
   rmAddObjectDefConstraint(extraTrees2ID, avoidSocket);
   rmAddObjectDefConstraint(extraTrees2ID, avoidTradeRoute);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(extraTrees2ID, 0, rmAreaID("player"+i), 1);

   // Text
   rmSetStatusText("",0.75);

// Main forests
   int forestChance = -1;
   numTries=10*cNumberNonGaiaPlayers;
   if (cNumberNonGaiaPlayers > 3)
      numTries=9*cNumberNonGaiaPlayers;  
   if (cNumberNonGaiaPlayers > 5)
      numTries=8*cNumberNonGaiaPlayers;  
   if (cNumberNonGaiaPlayers > 7)
      numTries=7*cNumberNonGaiaPlayers; 

   failCount=0;

   for (i=0; <numTries)
   {
      forestChance = rmRandInt(1,4);
      int forest=rmCreateArea("forest "+i);
      rmSetAreaWarnFailure(forest, false);
      rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(250));
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
		rmSetAreaSmoothDistance(forest, 20);
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

// smaller forest clumps
   numTries=5*cNumberNonGaiaPlayers;
   if (cNumberNonGaiaPlayers > 2)
      numTries=4*cNumberNonGaiaPlayers;  
   if (cNumberNonGaiaPlayers > 5)
      numTries=3*cNumberNonGaiaPlayers;  
   if (cNumberNonGaiaPlayers > 7)
      numTries=3*cNumberNonGaiaPlayers; 

   failCount=0;

   for (i=0; <numTries)
   {
      forestChance = rmRandInt(1,4);
      int forestSmall=rmCreateArea("forest small "+i);
      rmSetAreaWarnFailure(forestSmall, false);
      rmSetAreaSize(forestSmall, rmAreaTilesToFraction(50), rmAreaTilesToFraction(100));
      rmSetAreaForestType(forestSmall, forestType);
      rmSetAreaForestDensity(forestSmall, rmRandFloat(0.7, 1.0));
      rmSetAreaForestClumpiness(forestSmall, rmRandFloat(0.5, 0.9));
      rmSetAreaForestUnderbrush(forestSmall, rmRandFloat(0.0, 0.5));
      rmSetAreaCoherence(forestSmall, rmRandFloat(0.4, 0.7));
      rmSetAreaSmoothDistance(forestSmall, 10);
      if (forestChance == 4)
      {
		rmSetAreaMinBlobs(forestSmall, 1);
		rmSetAreaMaxBlobs(forestSmall, 3);					
		rmSetAreaMinBlobDistance(forestSmall, 8.0);
		rmSetAreaMaxBlobDistance(forestSmall, 14.0);
	}
      rmAddAreaToClass(forestSmall, rmClassID("classForest")); 
	rmAddAreaConstraint(forestSmall, mediumPlayerConstraint);
      rmAddAreaConstraint(forestSmall, forestConstraint);
      rmAddAreaConstraint(forestSmall, avoidAll); 
	rmAddAreaConstraint(forestSmall, avoidCoin);  
      rmAddAreaConstraint(forestSmall, avoidImpassableLand); 
      rmAddAreaConstraint(forestSmall, avoidTradeRoute);
	rmAddAreaConstraint(forestSmall, avoidStartingUnits);
	rmAddAreaConstraint(forestSmall, avoidSocket);
	rmAddAreaConstraint(forestSmall, avoidNativesShort);
      if(rmBuildArea(forestSmall)==false)
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

// Extra silver mines - distant, in the middle and near ends of axis.
   silverType = rmRandInt(1,10);
   int extraGoldID = rmCreateObjectDef("extra silver "+i);
   rmAddObjectDefItem(extraGoldID, "mine", 1, 0.0);
   rmAddObjectDefToClass(extraGoldID, rmClassID("importantItem"));
   rmAddObjectDefConstraint(extraGoldID, avoidTradeRoute);
   rmAddObjectDefConstraint(extraGoldID, avoidSocket);
   rmAddObjectDefConstraint(extraGoldID, coinAvoidCoin);
   rmAddObjectDefConstraint(extraGoldID, shortAvoidCanyons);
   rmAddObjectDefConstraint(extraGoldID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(extraGoldID, avoidWater10);
   rmAddObjectDefConstraint(extraGoldID, avoidAll);
   rmSetObjectDefMinDistance(extraGoldID, 0.0);
   rmSetObjectDefMaxDistance(extraGoldID, 60.0);
   rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.5, rmRandInt(1, 2));
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
   rmAddObjectDefConstraint(GoldFarID, shortAvoidCanyons);
   rmAddObjectDefConstraint(GoldFarID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldFarID, circleConstraint);
   rmAddObjectDefConstraint(GoldFarID, avoidAll);
   rmAddObjectDefConstraint(GoldFarID, farPlayerConstraint);
   rmAddObjectDefConstraint(GoldFarID, avoidWater10);
   rmSetObjectDefMinDistance(GoldFarID, 75.0);
   rmSetObjectDefMaxDistance(GoldFarID, 100.0);
   rmPlaceObjectDefPerPlayer(GoldFarID, false, 1);

   silverType = rmRandInt(1,10);
   int GoldFartherID=rmCreateObjectDef("player silver farther");
   rmAddObjectDefItem(GoldFartherID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(GoldFartherID, avoidTradeRoute);
   rmAddObjectDefConstraint(GoldFartherID, avoidSocket);
   rmAddObjectDefConstraint(GoldFartherID, coinAvoidCoin);
   rmAddObjectDefConstraint(GoldFartherID, shortAvoidCanyons);
   rmAddObjectDefConstraint(GoldFartherID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldFartherID, circleConstraint);
   rmAddObjectDefConstraint(GoldFartherID, avoidAll);
   rmAddObjectDefConstraint(GoldFartherID, avoidWater10);
   if (sectionChance > 9)
   {
      rmSetObjectDefMinDistance(GoldFartherID, 130.0);
      rmSetObjectDefMaxDistance(GoldFartherID, 200.0);
      rmAddObjectDefConstraint(GoldFartherID, fartherPlayerConstraint);
   }
   else
   {
      rmSetObjectDefMinDistance(GoldFartherID, 105.0);
      rmSetObjectDefMaxDistance(GoldFartherID, 300.0);
      rmAddObjectDefConstraint(GoldFartherID, farPlayerConstraint);
   }
   rmPlaceObjectDefPerPlayer(GoldFartherID, false, 1);

   // Text
   rmSetStatusText("",0.85);

// sheep etc
   if (sheepChance > 0)
   {
      int sheepID=rmCreateObjectDef("herdable animal");
      rmAddObjectDefItem(sheepID, sheepType, 2, 4.0);
      rmAddObjectDefToClass(sheepID, rmClassID("herdableFood"));
      rmSetObjectDefMinDistance(sheepID, 45.0);
      rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.25));
      rmAddObjectDefConstraint(sheepID, avoidSheep);
      rmAddObjectDefConstraint(sheepID, avoidAll);
      rmAddObjectDefConstraint(sheepID, playerConstraint);
      rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
      if (rmRandInt(1,2) == 1)
	   rmPlaceObjectDefPerPlayer(sheepID, false, 2);
      else 
	   rmPlaceObjectDefPerPlayer(sheepID, false, 3);

      rmAddObjectDefConstraint(sheepID, farPlayerConstraint);
      rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.4));
      rmPlaceObjectDefPerPlayer(sheepID, false, 1); 
   }

// Central herds
   int centralHerdID=rmCreateObjectDef("central herd");  
   rmAddObjectDefItem(centralHerdID, centerHerdType, rmRandInt(6,9), 6.0);
   rmAddObjectDefToClass(centralHerdID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(centralHerdID, rmXFractionToMeters(0.05));
   rmSetObjectDefMaxDistance(centralHerdID, rmXFractionToMeters(0.1));
   rmAddObjectDefConstraint(centralHerdID, avoidTradeRoute);
   rmAddObjectDefConstraint(centralHerdID, avoidImportantItem);
   rmAddObjectDefConstraint(centralHerdID, avoidWater10);
   rmAddObjectDefConstraint(centralHerdID, farPlayerConstraint);
   rmAddObjectDefConstraint(centralHerdID, longHuntableConstraint);
   rmSetObjectDefCreateHerd(centralHerdID, true);
   rmPlaceObjectDefAtLoc(centralHerdID, 0, 0.5, 0.5, 1);
   // additional of central herd type
   rmAddObjectDefConstraint(centralHerdID, farPlayerConstraint);
   rmSetObjectDefMinDistance(centralHerdID, rmXFractionToMeters(0.3));
   rmSetObjectDefMaxDistance(centralHerdID, rmXFractionToMeters(0.38));
   rmPlaceObjectDefPerPlayer(centralHerdID, false, 1);

// far huntable
   int farHuntableID=rmCreateObjectDef("far huntable");
   rmAddObjectDefItem(farHuntableID, deerType, rmRandInt(5,9), 6.0);
   rmAddObjectDefToClass(farHuntableID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(farHuntableID, rmXFractionToMeters(0.33));
   rmSetObjectDefMaxDistance(farHuntableID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(farHuntableID, avoidTradeRoute);
   rmAddObjectDefConstraint(farHuntableID, avoidImportantItem);
   rmAddObjectDefConstraint(farHuntableID, avoidWater10);
   rmAddObjectDefConstraint(farHuntableID, fartherPlayerConstraint);
   rmAddObjectDefConstraint(farHuntableID, longHuntableConstraint);
   rmAddObjectDefConstraint(farHuntableID, avoidAll);
   rmSetObjectDefCreateHerd(farHuntableID, true);
   rmPlaceObjectDefPerPlayer(farHuntableID, false, 1);

// scattered deer
   int deerID=rmCreateObjectDef("scattered deer");
   rmAddObjectDefItem(deerID, scatteredDeerType, rmRandInt(1,3), 4.0);
   rmSetObjectDefMinDistance(deerID, 35);
   rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(deerID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(deerID, avoidImportantItem);
   rmAddObjectDefConstraint(deerID, huntableConstraint);
   rmAddObjectDefConstraint(deerID, avoidAll);
   rmSetObjectDefCreateHerd(deerID, true);
   rmPlaceObjectDefAtLoc(deerID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*6);

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
   for(i=0; <cNumberNonGaiaPlayers*12)
      rmPlaceObjectDefAtLoc(StragglerTreeID, 0, 0.5, 0.5);

// Fish 
   int fishID=rmCreateObjectDef("fish");
   int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 20.0);
   rmAddObjectDefItem(fishID, fishType, 1, 0.0);
   rmSetObjectDefMinDistance(fishID, 0.0);
   rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(fishID, fishVsFishID);
   if (cNumberNonGaiaPlayers < 4)
      rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, rmRandInt(3,5));
   else
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, rmRandInt(4,6));

   // Text
   rmSetStatusText("",0.99);


  // King of the Hill (added 2026-11 for WoL): centre, beside the river crossing
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

  
