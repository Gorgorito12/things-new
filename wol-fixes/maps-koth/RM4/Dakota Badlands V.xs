// Dakota Badlands V
// a random map for AOE3 (original or vanilla version)
// created for the Dakotas Random Map Contest
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
   string deerType = "";
   string deer2Type = "";
   string sheepType = "";

// Set up for natives to appear on the map
   int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;

   if (rmAllocateSubCivs(3) == true)
   {
	subCiv0=rmGetCivID("Comanche");
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Comanche");

	subCiv1=rmGetCivID("Lakota");
      if (subCiv1 >= 0)
         rmSetSubCiv(1, "Lakota");

	subCiv2=rmGetCivID("Cree");
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Cree");
   }

// Pick pattern for trees, terrain, features, etc.
   int patternChance = rmRandInt(1,2);   
   int variantChance = rmRandInt(1,6);
   int lightingChance = rmRandInt(1,14);
   int axisChance = rmRandInt(1,2);
   int playerSide = rmRandInt(1,2);   
   int positionChance = rmRandInt(1,2);   
   int sectionChance = rmRandInt(1,3);
   int ffaChance = rmRandInt(1,6);
   int socketPattern = rmRandInt(1,2);   
   int nativeSetup = rmRandInt(0,10);
   int badlandVillageChance = 0;
   int villageCNum = 0;
   int villageDNum = 0;
   int sheepChance = rmRandInt(1,3);
   int twoChoice = rmRandInt(1,2);
   int threeChoice = rmRandInt(1,3);
   int forestDist = 11;
   if (cNumberNonGaiaPlayers < 4)
	forestDist = 8;
   int edgeChance = rmRandInt(1,4);
   int badlandChance = rmRandInt(1,5);

// Pick the map size
/* ====================================== MAP SIZE REFERENCE =========================================================

						#players	size	longSide	   size*longSide  'area' ratio to 1 
  
   scalingNumber 1  			2		320	400 (sizex1.25)	128k		1

   if (scalingNumber == 2)		3		380	456 (sizex1.2)	173k		1.35

   else if (scalingNumber == 3)	4		420	504 (sizex1.2)	211k		1.65

   else if (scalingNumber == 4)	5-6		460	552 (sizex1.2)	254k		1.98		

   else if (scalingNumber == 5)	7-8		500	600 (sizex1.2)	300k		2.34		

=================================================================================================================  */

   int scalingNumber = 0;
   float scalingFactor = 0;
   int size = 0;
   if (cNumberNonGaiaPlayers == 2)
   {
	scalingNumber = 1;
	scalingFactor = 1.0;
	size = 320;
   }	
   else if (cNumberNonGaiaPlayers == 3)
   {
	scalingNumber = 2;
	scalingFactor = 1.35;
	size = 380;
   }	
   else if (cNumberNonGaiaPlayers == 4)
   {
	scalingNumber = 3;
	scalingFactor = 1.7;
	size = 420;
   }	
   else if (cNumberNonGaiaPlayers < 7)
   {
	scalingNumber = 4;
	scalingFactor = 2;
	size = 460;
   }	
   else    // 7 or 8 players
   {
	scalingNumber = 5;
	scalingFactor = 2.3;
	size = 500;
   }	

   int longSide = 1.2*size;
   if (scalingNumber == 1)
	longSide = 1.25*size;
   if (axisChance == 1)
      rmSetMapSize(longSide, size);
   else
      rmSetMapSize(size, longSide);

// Elevation
   rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.7, 5.0);
   rmSetMapElevationHeightBlend(1.0);
   rmSetSeaLevel(2.0);
	
   // Text
   rmSetStatusText("",0.05);

// Pick terrain patterns and features 
   if (lightingChance == 1)
	rmSetLightingSet("ottoman morning");
   else if (lightingChance == 2)
      rmSetLightingSet("pampas");
   else if (lightingChance == 3)
      rmSetLightingSet("great plains");
   else if (lightingChance == 4)  
      rmSetLightingSet("texas");
   else if (lightingChance == 5)
      rmSetLightingSet("302a");
   else if (lightingChance == 6)
	rmSetLightingSet("bayou");
   else if (lightingChance == 7)
      rmSetLightingSet("carribean");
   else if (lightingChance == 8)
	rmSetLightingSet("Great Lakes");
   else if (lightingChance == 9)
	rmSetLightingSet("seville morning");
   else if (lightingChance == 10)
	rmSetLightingSet("307a_beach");
   else if (lightingChance == 11)
      rmSetLightingSet("311b");
   else if (lightingChance == 12)
	rmSetLightingSet("324b");
   else if (lightingChance == 13)
      rmSetLightingSet("306a_caribbean");
   else 
      rmSetLightingSet("302a_base");

   rmSetMapType("greatPlains");
   rmSetMapType("grass");

   if (patternChance == 1)       // great plains 1, green
   {
      baseType = "great plains grass"; 
      cliffType = "Texas"; 
   }
   else if (patternChance == 2)  // great plains 2, dry
   {      
      baseType = "great plains drygrass";
      cliffType = "Sonora";
   }

   if (variantChance == 1)
   {
      deerType = "elk";
      deer2Type = "bison";
   }
   if (variantChance == 2)
   {
      deerType = "bison";
      deer2Type = "elk";
   }
   if (variantChance == 3)
   {
      deerType = "deer";
      deer2Type = "bison";
   }
   if (variantChance == 4)
   {
      deerType = "bison";
      deer2Type = "deer";
   }
   if (variantChance == 5)
   {
      deerType = "bison";
      deer2Type = "pronghorn";
   }
   else 
   {     
      deerType = "pronghorn";
      deer2Type = "bison";
   }

   if (sheepChance > 1)
      sheepType = "cow";
   else
      sheepType = "sheep";
 
   rmSetBaseTerrainMix(baseType);   
   if (patternChance == 1)
	rmTerrainInitialize("great_plains\ground1_gp", 2);
   else
	rmTerrainInitialize("great_plains\ground3_gp", 2);
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
   rmDefineClass("classCliff2");
   rmDefineClass("canyon");
   rmDefineClass("center");
   rmDefineClass("prairieGrass");
   rmDefineClass("classNugget");
   rmDefineClass("socketClass");
   rmDefineClass("clearing");
   rmDefineClass("impassableCliff");
   int classHuntable=rmDefineClass("huntableFood");   
   int classHerdable=rmDefineClass("herdableFood"); 
   int classProp=rmDefineClass("propClass");

   // Text
   rmSetStatusText("",0.10);

// -------------Define constraints
   // Map edge constraints
   int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, 0, longSide*0.45, rmDegreesToRadians(0), rmDegreesToRadians(360));
   int objEdgeConstraint=rmCreateBoxConstraint("avoid edge of map used to be a circle", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
   int circleConstraintPr=rmCreatePieConstraint("circle Constraint for prairie", 0.5, 0.5, 0, longSide*0.395, rmDegreesToRadians(0), rmDegreesToRadians(360));

   // Center constraints
   int centerConstraintForest=rmCreateClassDistanceConstraint("stay away from center forest", rmClassID("center"), longSide*0.395);
   int centerConstraintForest2=rmCreateClassDistanceConstraint("stay away from center forest 2", rmClassID("center"), longSide*0.375);
   int avoidCenterShort=rmCreateClassDistanceConstraint("avoid center short", rmClassID("center"), 25.0);
   int avoidCenterLong=rmCreateClassDistanceConstraint("avoid center longer", rmClassID("center"), longSide*0.25);

   // Player constraints
   int playerConstraintForest=rmCreateClassDistanceConstraint("forests kinda stay away from players", classPlayer, 15.0);
   int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 45.0);
   int mediumPlayerConstraint=rmCreateClassDistanceConstraint("medium stay away from players", classPlayer, 25.0);
   int nuggetPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 60.0);
   int longPlayerConstraint=rmCreateClassDistanceConstraint("land stays away from players", classPlayer, 70.0); 
   int farPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players more", classPlayer, 85.0);
   int fartherPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players the most", classPlayer, 105.0);

   // Nature avoidance
   int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
   int shortForestConstraint=rmCreateClassDistanceConstraint("patch vs. forest", rmClassID("classForest"), 7.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), forestDist);
   int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "gold", 10.0);
   int shortAvoidSilver=rmCreateTypeDistanceConstraint("short gold avoid gold", "Mine", 20.0);
   int coinAvoidCoin=rmCreateTypeDistanceConstraint("coin avoids coin", "gold", 35.0);
   int avoidSheep=rmCreateClassDistanceConstraint("sheep avoids sheep etc", rmClassID("herdableFood"), 45.0);
   int huntableConstraint=rmCreateClassDistanceConstraint("huntable constraint", rmClassID("huntableFood"), 35.0);
   int longHuntableConstraint=rmCreateClassDistanceConstraint("long huntable constraint", rmClassID("huntableFood"), 55.0);
   int forestsAvoidBison=rmCreateClassDistanceConstraint("forest avoids bison", rmClassID("huntableFood"), 15.0);
   int avoidProp=rmCreateClassDistanceConstraint("prop constraint", rmClassID("propClass"), 70.0);

   // Avoid impassable land, certain features
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
   int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 18.0);
   int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 8.0);
   int clearingConstraint=rmCreateClassDistanceConstraint("avoid clearings", rmClassID("classPatch"), 7.0);
   int avoidImpassableCliff=rmCreateClassDistanceConstraint("avoid impassable cliff", rmClassID("impassableCliff"), 5.0);

   int avoidCliffsTiny=rmCreateClassDistanceConstraint("stuff vs. cliff tiny", rmClassID("classCliff"), 4.0);
   int cliffsAvoidCliffs=rmCreateClassDistanceConstraint("cliffs vs. cliffs", rmClassID("classCliff"), 25.0);
   int avoidCliffsShort=rmCreateClassDistanceConstraint("stuff vs. cliff short", rmClassID("classCliff"), 7.0);

   int avoidCliffs2=rmCreateClassDistanceConstraint("stuff vs. cliff2", rmClassID("classCliff2"), 15.0);
   int avoidCliffs2Short=rmCreateClassDistanceConstraint("stuff vs. cliff2 short", rmClassID("classCliff2"), 8.0);
   int avoidCliffs2Tiny=rmCreateClassDistanceConstraint("stuff vs. cliff2 tiny", rmClassID("classCliff2"), 5.0);

   int avoidCanyons=rmCreateClassDistanceConstraint("avoid canyons", rmClassID("canyon"), 14.0);
   int shortAvoidCanyons=rmCreateClassDistanceConstraint("avoid canyons short", rmClassID("canyon"), 8.0);
   int avoidCanyonsTiny=rmCreateClassDistanceConstraint("stuff vs. canyons tiny", rmClassID("canyon"), 1.0);

   int avoidPrairieTiny=rmCreateClassDistanceConstraint("stuff vs. prairie tiny", rmClassID("prairieGrass"), 2.0);
   int avoidPrairieShort=rmCreateClassDistanceConstraint("stuff vs. prairie short", rmClassID("prairieGrass"), 8.0);
   int avoidPrairie=rmCreateClassDistanceConstraint("stuff vs. prairie", rmClassID("prairieGrass"), 13.0);
   int avoidPrairieLong=rmCreateClassDistanceConstraint("stuff vs. prairie long", rmClassID("prairieGrass"), 17.0);
   int avoidPrairieLonger=rmCreateClassDistanceConstraint("stuff vs. prairie longer", rmClassID("prairieGrass"), 21.0); 
   
   // Unit avoidance
   int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 24.0);
   int avoidStartingUnitsSmall=rmCreateClassDistanceConstraint("objects avoid starting units small", rmClassID("startingUnit"), 10.0);
   int avoidImportantItem=rmCreateClassDistanceConstraint("things avoid each other", rmClassID("importantItem"), 10.0);
   int avoidImportantItemSmall=rmCreateClassDistanceConstraint("important item small avoidance", rmClassID("importantItem"), 7.0);
   int avoidImportantItemMed=rmCreateClassDistanceConstraint("things avoid each other med", rmClassID("importantItem"), 18.0);
   int avoidImportantItemLong=rmCreateClassDistanceConstraint("things avoid each other long", rmClassID("importantItem"), 36.0);
   int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 60.0);
   int avoidNativesMed=rmCreateClassDistanceConstraint("stuff avoids natives medium", rmClassID("natives"), 40.0);
   int avoidNativesShorter=rmCreateClassDistanceConstraint("stuff avoids natives shorter", rmClassID("natives"), 15.0);
   int avoidNativesTiny=rmCreateClassDistanceConstraint("stuff avoids natives tiny", rmClassID("natives"), 8.0);
   int avoidNugget=rmCreateClassDistanceConstraint("nugget vs. nugget", rmClassID("classNugget"), 45.0);
   int avoidNuggetMed=rmCreateClassDistanceConstraint("nugget vs. nugget med", rmClassID("classNugget"), 60.0);
   int avoidNuggetLong=rmCreateClassDistanceConstraint("nugget vs. nugget long", rmClassID("classNugget"), 80.0);
   int avoidNuggetSmall=rmCreateTypeDistanceConstraint("avoid nuggets by a little", "AbstractNugget", 10.0);
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

   // Trade route avoidance.
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 8.0);
   int avoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("trade route short", 4.0);
   int avoidSocket=rmCreateClassDistanceConstraint("avoid sockets", rmClassID("socketClass"), 13.0);

// End of constraints -------------------------------

   // Text
   rmSetStatusText("",0.15);

// Set up player starting locations
if (cNumberNonGaiaPlayers == 2)
{
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

	    rmPlacePlayersCircular(0.425, 0.43, 0.0); 

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

	    rmPlacePlayersCircular(0.425, 0.43, 0.0); 
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

	    rmPlacePlayersCircular(0.425, 0.43, 0.0); 

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

	    rmPlacePlayersCircular(0.425, 0.43, 0.0); 
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
             rmSetPlacementSection(0.2, 0.3);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.19, 0.31);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.18, 0.32);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.17, 0.33);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.16, 0.29);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.23, 0.35);

	    rmPlacePlayersCircular(0.43, 0.435, 0.0); 

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.7, 0.8);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.69, 0.81);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.68, 0.82);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.67, 0.83);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.66, 0.79);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.73, 0.85);          

	    rmPlacePlayersCircular(0.43, 0.435, 0.0); 
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
             rmSetPlacementSection(0.44, 0.56);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.43, 0.57);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.42, 0.58);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.41, 0.54);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.48, 0.6);

	    rmPlacePlayersCircular(0.43, 0.435, 0.0); 

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
             rmSetPlacementSection(0.94, 0.06);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.93, 0.07);
	    else if (sectionChance == 4)
             rmSetPlacementSection(0.92, 0.08);
	    else if (sectionChance == 5)
             rmSetPlacementSection(0.91, 0.04);
	    else if (sectionChance == 6)
             rmSetPlacementSection(0.98, 0.1);

	    rmPlacePlayersCircular(0.43, 0.435, 0.0); 
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
             rmSetPlacementSection(0.16, 0.34);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.15, 0.36);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.13, 0.37);

	    rmPlacePlayersCircular(0.435, 0.44, 0.0); 

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.66, 0.84);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.65, 0.86);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.63, 0.87);

	    rmPlacePlayersCircular(0.435, 0.44, 0.0); 
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
             rmSetPlacementSection(0.41, 0.59);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.40, 0.61);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.38, 0.62);

	    rmPlacePlayersCircular(0.435, 0.44, 0.0); 

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.91, 0.09);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.90, 0.11);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.88, 0.12);

	    rmPlacePlayersCircular(0.435, 0.44, 0.0); 
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
             rmSetPlacementSection(0.14, 0.36);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.13, 0.37);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.11, 0.39);

	    rmPlacePlayersCircular(0.44, 0.445, 0.0); 

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.64, 0.86);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.63, 0.87);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.61, 0.89);

	    rmPlacePlayersCircular(0.44, 0.445, 0.0);
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
             rmSetPlacementSection(0.39, 0.61);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.38, 0.62);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.36, 0.64);

	    rmPlacePlayersCircular(0.44, 0.445, 0.0);

	    if (playerSide == 1)
          {
		rmSetPlacementTeam(1);
	    }
          else if (playerSide == 2)
	    {
		rmSetPlacementTeam(0);
	    }
	    if (sectionChance == 1)
             rmSetPlacementSection(0.89, 0.11);
	    else if (sectionChance == 2)
             rmSetPlacementSection(0.88, 0.12);
	    else if (sectionChance == 3)
             rmSetPlacementSection(0.86, 0.14);

	    rmPlacePlayersCircular(0.44, 0.445, 0.0);
        }
      }
   }
   else if (cNumberTeams > 2)
   {
	if (cNumberNonGaiaPlayers == 3)  // FFA 3 players
	{
	   if (axisChance == 1)
	   {
		if (ffaChance == 1)
		{
		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.12, 0.13);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.38, 0.39);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.75, 0.76);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 
		}
		else if (ffaChance == 2)
		{
		   rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.12, 0.13);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.38, 0.39);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.75, 0.76);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 
		}
		else if (ffaChance == 3)
		{
		   rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.12, 0.13);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.38, 0.39);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.75, 0.76);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 
		}
		else if (ffaChance == 4)
		{
		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.62, 0.63);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.88, 0.89);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.25, 0.26);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 
		}
		else if (ffaChance == 5)
		{
		   rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.62, 0.63);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.88, 0.89);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.25, 0.26);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 
		}
		else if (ffaChance == 6)
		{
		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.62, 0.63);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.88, 0.89);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.25, 0.26);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 
		}
	   }
	   else if (axisChance == 2)
	   {
		if (ffaChance == 1)
		{
		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.37, 0.38);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.63, 0.64);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.0, 0.01);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 
		}
		else if (ffaChance == 2)
		{
		   rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.37, 0.38);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.63, 0.64);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.0, 0.01);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 
		}
		else if (ffaChance == 3)
		{
		   rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.37, 0.38);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.63, 0.64);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.0, 0.01);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 
		}
		else if (ffaChance == 4) 
		{
		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.12, 0.13);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.86, 0.87);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.5, 0.51);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 
		}
		else if (ffaChance == 5)
		{
		   rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.12, 0.13);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.86, 0.87);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.5, 0.51);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 
		}
		else if (ffaChance == 6)
		{
		   rmSetPlacementTeam(0);
		   rmSetPlacementSection(0.12, 0.13);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(2);
		   rmSetPlacementSection(0.86, 0.87);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 

		   rmSetPlacementTeam(1);
		   rmSetPlacementSection(0.5, 0.51);
		   rmPlacePlayersCircular(0.43, 0.435, 0.0); 
		}
	   }
	}
	else  // FFA, over 3 players
	{
         bool southSide = true;
	   if (rmRandInt(1,2) == 1) 
	      southSide = false;
	   float spacingIncrement = 0.24;  // 4 players  
         float northStart = 0.125;  
         float northEnd = 0.42;  
         float southStart = 0.625;
         float southEnd = 0.95;

	   if (axisChance == 2)
	   {
            northStart = 0.875;  
            northEnd = 1.17;  
            southStart = 0.375;
            southEnd = 0.7;
	   }  
	
	   if ((cNumberNonGaiaPlayers == 5) || (cNumberNonGaiaPlayers == 6))
	   {
 		spacingIncrement = 0.125;
		if (axisChance == 1)
		{
		   northStart = 0.12; 
		   northEnd = 0.43;
		   southStart = 0.62;
		   southEnd = 0.96; 
		}
		else if (axisChance == 2)
		{
		   northStart = 0.87; 
		   northEnd = 1.18;
		   southStart = 0.37;
		   southEnd = 0.71; 
		}
	   }
	   else if ((cNumberNonGaiaPlayers == 7) || (cNumberNonGaiaPlayers == 8))
	   {
		spacingIncrement = 0.085; 
		if (axisChance == 1)
		{
		   northStart = 0.11; 
		   northEnd = 0.44;
		   southStart = 0.61;
		   southEnd = 0.97;
		}
		else if (axisChance == 2)
		{
		   northStart = 0.86; 
		   northEnd = 1.19;
		   southStart = 0.36;
		   southEnd = 0.72; 
		}
	   }

         float spacingSouth = 0;
         float spacingNorth = 0;

         for (i = 0; < cNumberNonGaiaPlayers)
         {
            if (southSide == true)
            {
               rmSetPlacementTeam(i);
               rmSetPlacementSection((southStart + spacingSouth), southEnd);
	         rmSetTeamSpacingModifier(0.25);
		   if (cNumberNonGaiaPlayers > 6)
	            rmPlacePlayersCircular(0.44, 0.445, 0.0);
		   else if (cNumberNonGaiaPlayers > 4)
	            rmPlacePlayersCircular(0.435, 0.44, 0.0); 
		   else
	            rmPlacePlayersCircular(0.43, 0.435, 0.0); 
               spacingSouth = spacingSouth + spacingIncrement;
            }
            else
            {
               rmSetPlacementTeam(i);
               rmSetPlacementSection((northStart + spacingNorth), northEnd);
	         rmSetTeamSpacingModifier(0.25);
		   if (cNumberNonGaiaPlayers > 6)
	            rmPlacePlayersCircular(0.44, 0.445, 0.0);
		   else if (cNumberNonGaiaPlayers > 4)
	            rmPlacePlayersCircular(0.435, 0.44, 0.0); 
		   else
	            rmPlacePlayersCircular(0.43, 0.435, 0.0); 
               spacingNorth = spacingNorth + spacingIncrement;
            }
            if (southSide == true)
            {
               southSide = false;
            }
            else
            {
               southSide = true;
            }
	   }
      }
   }
}

   // Text
   rmSetStatusText("",0.20);
	
// Set up player areas.
   float playerFraction=rmAreaTilesToFraction(150);
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

// Trade Routes
   int tradeRouteID9 = rmCreateTradeRoute();
   if (axisChance == 2)
   {  
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.0, 0.535); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.08, 0.57); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.12, 0.64); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.2, 0.74);  
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.32, 0.79);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.5, 0.83); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.68, 0.79);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.8, 0.74); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.88, 0.64);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.92, 0.57); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 1.0, 0.535);
   }
   else
   {  
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.535, 1.0); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.57, 0.92); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.64, 0.88);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.74, 0.8);  
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.79, 0.68);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.83, 0.5);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.79, 0.32);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.74, 0.2);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.64, 0.12);
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.57, 0.08); 
      rmAddTradeRouteWaypoint(tradeRouteID9, 0.535, 0.0); 
   }
   rmBuildTradeRoute(tradeRouteID9, "carolinas\trade_route");

   // second route
   int tradeRouteID9A = rmCreateTradeRoute();
   if (axisChance == 2)
   { 
      rmAddTradeRouteWaypoint(tradeRouteID9A, 1.0, 0.465);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.92, 0.43);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.88, 0.36);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.8, 0.26);   
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.68, 0.21);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.5, 0.17);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.32, 0.21);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.2, 0.26);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.12, 0.36); 
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.08, 0.43);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.0, 0.465); 
   }
   else
   {
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.465, 0.0);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.43, 0.08);   
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.36, 0.12);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.26, 0.2);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.21, 0.32);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.17, 0.5); 
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.21, 0.68); 
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.26, 0.8);  
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.36, 0.88);
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.43, 0.92); 
      rmAddTradeRouteWaypoint(tradeRouteID9A, 0.465, 1.0);  
   }
   rmBuildTradeRoute(tradeRouteID9A, "dirt");

   // Text
   rmSetStatusText("",0.30);

// Trade sockets
   int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
   rmSetObjectDefAllowOverlap(socketID, true);
   rmAddObjectDefToClass(socketID, rmClassID("importantItem"));
   rmAddObjectDefToClass(socketID, rmClassID("socketClass"));
   rmSetObjectDefMinDistance(socketID, 0.0);
   rmSetObjectDefMaxDistance(socketID, 6.0);

   if (socketPattern == 1) // 4 or 6 sockets
   { 
      if (cNumberNonGaiaPlayers < 4)
	{
          rmSetObjectDefTradeRouteID(socketID, tradeRouteID9);
          vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.23);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.77);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          // change the trade route for the new sockets
          rmSetObjectDefTradeRouteID(socketID, tradeRouteID9A);
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.23);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
 
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.77);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	 }
	 else
	 {
          rmSetObjectDefTradeRouteID(socketID, tradeRouteID9);
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.21);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.5);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.79);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          // change the trade route for the new sockets
          rmSetObjectDefTradeRouteID(socketID, tradeRouteID9A);
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.21);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.5);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.79);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	 }
   }
   else if (socketPattern == 2) // 6 or 8 sockets
   { 
      if (cNumberNonGaiaPlayers < 4)
	{
          rmSetObjectDefTradeRouteID(socketID, tradeRouteID9);
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.15);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.5);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.85);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          // change the trade route for the new sockets
          rmSetObjectDefTradeRouteID(socketID, tradeRouteID9A);
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.15);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.5);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.85);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	 }
	 else
	 {
          rmSetObjectDefTradeRouteID(socketID, tradeRouteID9);
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.15);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.39);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.61);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9, 0.85);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          // change the trade route for the new sockets
          rmSetObjectDefTradeRouteID(socketID, tradeRouteID9A);
          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.15);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.39);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.61);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc = rmGetTradeRouteWayPoint(tradeRouteID9A, 0.85);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	 }
   }

   //Text
   rmSetStatusText("",0.35);

// Starting TCs and units 		
   int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
   rmAddObjectDefToClass(startingUnits, rmClassID("startingUnit"));
   rmSetObjectDefMinDistance(startingUnits, 5.0);
   rmSetObjectDefMaxDistance(startingUnits, 10.0);
   rmAddObjectDefConstraint(startingUnits, avoidAll);

   int startingTCID= rmCreateObjectDef("startingTC");
   rmAddObjectDefToClass(startingTCID, rmClassID("startingUnit"));
   rmSetObjectDefMaxDistance(startingTCID, 18.0);
   rmAddObjectDefConstraint(startingTCID, avoidAll);
   rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);
   rmAddObjectDefConstraint(startingTCID, avoidSocket);
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
   rmSetAreaSize(centerArea, 0.01, 0.01);
   rmSetAreaLocation(centerArea, 0.5, 0.5);
   rmAddAreaToClass(centerArea, rmClassID("center")); 

// NATIVE AMERICANS
   // Village A - appears on prairie or hills
   int villageAID = -1;
   int whichNative = rmRandInt(1,3);
   int villageType = rmRandInt(1,5);

   if (whichNative == 1)
      villageAID = rmCreateGrouping("village A", "native comanche village "+villageType);
   else if (whichNative == 2)
      villageAID = rmCreateGrouping("village A", "native lakota village "+villageType);
   else if (whichNative == 3)
      villageAID = rmCreateGrouping("village A", "native cree village "+villageType);
   rmAddGroupingToClass(villageAID, rmClassID("natives"));
   rmAddGroupingToClass(villageAID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageAID, 10.0);
   rmSetGroupingMaxDistance(villageAID, size*0.25);
   rmAddGroupingConstraint(villageAID, avoidImpassableLand);
   rmAddGroupingConstraint(villageAID, avoidTradeRoute);
   rmAddGroupingConstraint(villageAID, avoidSocket);
   rmAddGroupingConstraint(villageAID, avoidNatives);
   rmAddGroupingConstraint(villageAID, longPlayerConstraint);
   rmAddGroupingConstraint(villageAID, avoidCenterLong);

   // Village D - appears in badlands, always same type as A 
   int villageDID = -1;
   villageType = rmRandInt(1,5);

   if (whichNative == 1)
      villageDID = rmCreateGrouping("village D", "native comanche village "+villageType);
   else if (whichNative == 2)
      villageDID = rmCreateGrouping("village D", "native lakota village "+villageType);
   else if (whichNative == 3)
      villageDID = rmCreateGrouping("village D", "native cree village "+villageType);
   rmAddGroupingToClass(villageDID, rmClassID("natives"));
   rmAddGroupingToClass(villageDID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageDID, 0.18);
   rmSetGroupingMaxDistance(villageDID, size*0.45);
   rmAddGroupingConstraint(villageDID, avoidImpassableLand);
   rmAddGroupingConstraint(villageDID, avoidTradeRoute);
   rmAddGroupingConstraint(villageDID, avoidSocket);
   rmAddGroupingConstraint(villageDID, avoidNativesMed);
   rmAddGroupingConstraint(villageDID, avoidImportantItemLong);
   rmAddGroupingConstraint(villageDID, longPlayerConstraint);
   rmAddGroupingConstraint(villageDID, avoidPrairieLong);
   rmAddGroupingConstraint(villageDID, avoidCenterShort);

   // Village C   appears in badlands, always different from A and D
   int villageCID = -1;	
   villageType = rmRandInt(1,5);

   if (whichNative == 1)
   {
	if (twoChoice == 1)
	   villageCID = rmCreateGrouping("village C", "native lakota village "+villageType);
	else if (twoChoice == 2)
	   villageCID = rmCreateGrouping("village C", "native cree village "+villageType);  
   }
   else if (whichNative == 2)
   {
	if (twoChoice == 1)
	   villageCID = rmCreateGrouping("village C", "native comanche village "+villageType);
	else if (twoChoice == 2)
	   villageCID = rmCreateGrouping("village C", "native cree village "+villageType);  
   }
   else if (whichNative == 3)
   {
	if (twoChoice == 1)
	   villageCID = rmCreateGrouping("village C", "native comanche village "+villageType);
	else if (twoChoice == 2)
	   villageCID = rmCreateGrouping("village C", "native lakota village "+villageType); 
   }
   rmAddGroupingToClass(villageCID, rmClassID("importantItem"));
   rmAddGroupingToClass(villageCID, rmClassID("natives"));
   rmSetGroupingMinDistance(villageCID, 0.18);
   rmSetGroupingMaxDistance(villageCID, size*0.45);
   rmAddGroupingConstraint(villageCID, avoidImpassableLand);
   rmAddGroupingConstraint(villageCID, avoidTradeRoute);
   rmAddGroupingConstraint(villageCID, avoidSocket);
   rmAddGroupingConstraint(villageCID, avoidNativesMed);
   rmAddGroupingConstraint(villageCID, avoidImportantItemLong);
   rmAddGroupingConstraint(villageCID, longPlayerConstraint);
   rmAddGroupingConstraint(villageCID, avoidPrairieLong);
   rmAddGroupingConstraint(villageCID, avoidCenterShort);

   // Village B - randomly same or different from A and D villages, not in badlands 
   int villageBID = -1;	
   villageType = rmRandInt(1,5);
   whichNative = rmRandInt(1,3);

   if (whichNative == 1)
      villageBID = rmCreateGrouping("village B", "native comanche village "+villageType);
   else if (whichNative == 2)
      villageBID = rmCreateGrouping("village B", "native lakota village "+villageType);
   else if (whichNative == 3)
      villageBID = rmCreateGrouping("village B", "native cree village "+villageType);
   rmAddGroupingToClass(villageBID, rmClassID("importantItem"));
   rmAddGroupingToClass(villageBID, rmClassID("natives"));
   rmSetGroupingMinDistance(villageBID, 10.0);
   rmSetGroupingMaxDistance(villageBID, size*0.25);
   rmAddGroupingConstraint(villageBID, avoidImpassableLand);
   rmAddGroupingConstraint(villageBID, avoidTradeRoute);
   rmAddGroupingConstraint(villageBID, avoidSocket);
   rmAddGroupingConstraint(villageBID, avoidNatives);
   rmAddGroupingConstraint(villageBID, longPlayerConstraint);
   rmAddGroupingConstraint(villageBID, avoidCenterLong);

   // Text
   rmSetStatusText("",0.40);

// Placement of Native Americans part 1 - on prairie
   if (nativeSetup < 4) 
   {
	badlandVillageChance = rmRandInt(0,4);

      if (axisChance == 1)
	{
	   rmPlaceGroupingAtLoc(villageAID, 0, 0.77, 0.5);
	   rmPlaceGroupingAtLoc(villageAID, 0, 0.23, 0.5);
	}
      else if (axisChance == 2)
	{
	   rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.77);
	   rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.23);
	}
   }
   else if (nativeSetup < 8) 
   {
      if (axisChance == 1)
	{
	   rmPlaceGroupingAtLoc(villageAID, 0, 0.75, 0.35);
	   rmPlaceGroupingAtLoc(villageBID, 0, 0.75, 0.65);
	   rmPlaceGroupingAtLoc(villageAID, 0, 0.25, 0.35);
	   rmPlaceGroupingAtLoc(villageBID, 0, 0.25, 0.65);
	}
      else if (axisChance == 2)
	{
	   rmPlaceGroupingAtLoc(villageAID, 0, 0.35, 0.75);
	   rmPlaceGroupingAtLoc(villageBID, 0, 0.65, 0.75);
	   rmPlaceGroupingAtLoc(villageAID, 0, 0.35, 0.25);
	   rmPlaceGroupingAtLoc(villageBID, 0, 0.65, 0.25);
	}
	if (nativeSetup == 5)
	   villageDNum = 1;
	if (nativeSetup == 6)
	   villageCNum = 2;
	if (nativeSetup == 7)
	   villageDNum = 1;
   }
   else if (nativeSetup == 8) 
	villageCNum = 2;
   else if (nativeSetup == 9) 
	villageCNum = 3;
   else if (nativeSetup == 10) 
   {
	villageCNum = 2;
	villageDNum = 1;
   }

   if (badlandVillageChance == 1)
   {
      if (cNumberNonGaiaPlayers > 3)
	{
	   if (rmRandInt(1,3) == 1)
	   {
		villageCNum = rmRandInt(1,2);
		villageDNum = 1;
	   } 
	   else
  	      villageCNum = rmRandInt(1,3);
	}
	else 
	{
	   if (rmRandInt(1,3) == 1)
	   {
		villageCNum = 1;
		villageDNum = 1;
	   } 
	   else
  	      villageCNum = rmRandInt(1,2);
	}
   } 
   if (badlandVillageChance == 2)
	villageCNum = rmRandInt(1,2); 
   if (badlandVillageChance > 2)
	villageDNum = rmRandInt(1,2);   

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
   rmAddObjectDefConstraint(playerNuggetID, objEdgeConstraint);

   for(i=1; <cNumberPlayers)
   {
 	rmSetNuggetDifficulty(1, 1);
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }

   // Text
   rmSetStatusText("",0.45);

// More start area resources
   // start area trees 
   int StartAreaTreeID=rmCreateObjectDef("starting trees");
   rmAddObjectDefItem(StartAreaTreeID, "TreeGreatPlains", 1, 0.0);
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
   if (patternChance == 1)
   {
	if (rmRandInt(1,3) == 1)
   	   rmPlaceObjectDefPerPlayer(StartBerryBushID, false, 1);
   }

   // start area huntable
   int deerNum = rmRandInt(5,6);
   int startPronghornID=rmCreateObjectDef("starting pronghorn");
   rmAddObjectDefItem(startPronghornID, deerType, deerNum, 5.0);
   rmAddObjectDefToClass(startPronghornID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(startPronghornID, 16);
   rmSetObjectDefMaxDistance(startPronghornID, 22);
   rmAddObjectDefConstraint(startPronghornID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(startPronghornID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(startPronghornID, avoidAll);
   rmSetObjectDefCreateHerd(startPronghornID, true);
   rmPlaceObjectDefPerPlayer(startPronghornID, false, 1);

// Silver mines - players
   int silverType = -1;
   silverType = rmRandInt(1,10);
   int playerGoldID=rmCreateObjectDef("player silver closer");
   rmAddObjectDefItem(playerGoldID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(playerGoldID, avoidTradeRoute);
   rmAddObjectDefConstraint(playerGoldID, avoidSocket);
   rmAddObjectDefConstraint(playerGoldID, coinAvoidCoin);
   rmAddObjectDefConstraint(playerGoldID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(playerGoldID, objEdgeConstraint);
   rmAddObjectDefConstraint(playerGoldID, avoidAll);
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
   rmAddObjectDefConstraint(GoldMediumID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldMediumID, playerConstraint);
   rmAddObjectDefConstraint(GoldMediumID, objEdgeConstraint);
   rmAddObjectDefConstraint(GoldMediumID, avoidAll);
   rmSetObjectDefMinDistance(GoldMediumID, 40.0);
   rmSetObjectDefMaxDistance(GoldMediumID, 55.0);
   rmPlaceObjectDefPerPlayer(GoldMediumID, false, 1);

// Extra tree clumps near players - to ensure fair access to wood
   int extraTreesID=rmCreateObjectDef("extra trees");
   rmAddObjectDefItem(extraTreesID, "TreeGreatPlains", 5, 5.0);
   rmSetObjectDefMinDistance(extraTreesID, 14);
   rmSetObjectDefMaxDistance(extraTreesID, 18);
   rmAddObjectDefConstraint(extraTreesID, avoidAll);
   rmAddObjectDefConstraint(extraTreesID, avoidCoin);
   rmAddObjectDefConstraint(extraTreesID, avoidSocket);
   rmAddObjectDefConstraint(extraTreesID, avoidTradeRoute);
   rmAddObjectDefConstraint(extraTreesID, avoidStartingUnitsSmall);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(extraTreesID, 0, rmAreaID("player"+i), 1);

   int extraTrees2ID=rmCreateObjectDef("more extra trees");
   rmAddObjectDefItem(extraTrees2ID, "TreeGreatPlains", 5, 6.0);
   rmSetObjectDefMinDistance(extraTrees2ID, 18);
   rmSetObjectDefMaxDistance(extraTrees2ID, 24);
   rmAddObjectDefConstraint(extraTrees2ID, avoidAll);
   rmAddObjectDefConstraint(extraTrees2ID, avoidCoin);
   rmAddObjectDefConstraint(extraTrees2ID, avoidSocket);
   rmAddObjectDefConstraint(extraTrees2ID, avoidTradeRoute);
   rmAddObjectDefConstraint(extraTrees2ID, avoidStartingUnitsSmall);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(extraTrees2ID, 0, rmAreaID("player"+i), 1);

   // Text
   rmSetStatusText("",0.50);

// Forests 
   int failCount=0;
   int forestChance = -1;
   int numTries=32*scalingFactor;

   for (i=0; <numTries)
   {
      forestChance = rmRandInt(1,4);
      int forest=rmCreateArea("forest "+i);
      rmSetAreaWarnFailure(forest, false);
      rmSetAreaSize(forest, rmAreaTilesToFraction(85), rmAreaTilesToFraction(200));
      rmSetAreaForestType(forest, "great plains forest");
      rmSetAreaForestDensity(forest, rmRandFloat(0.7, 1.0));
      rmSetAreaForestClumpiness(forest, rmRandFloat(0.5, 0.9));
      rmSetAreaForestUnderbrush(forest, rmRandFloat(0.0, 0.5));
      rmSetAreaCoherence(forest, rmRandFloat(0.4, 0.7));
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
      rmAddAreaConstraint(forest, avoidAll); 
	rmAddAreaConstraint(forest, avoidCoin);  
      rmAddAreaConstraint(forest, avoidImpassableLand); 
      rmAddAreaConstraint(forest, avoidTradeRoute);
	rmAddAreaConstraint(forest, avoidStartingUnits);
	rmAddAreaConstraint(forest, avoidSocket);
	rmAddAreaConstraint(forest, avoidNativesShorter);
      rmAddAreaConstraint(forest, forestsAvoidBison); 
      rmAddAreaConstraint(forest, avoidCliffs2Short); 
	
	if (rmRandInt(1,3) > 1)
	{
         rmSetAreaBaseHeight(forest, rmRandFloat(5.0, 5.5));  
	   rmAddAreaConstraint(forest, forestConstraint); 
	}  
	if (cNumberNonGaiaPlayers > 3)
	   rmAddAreaConstraint(forest, centerConstraintForest);
	else
         rmAddAreaConstraint(forest, centerConstraintForest2);
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
   rmSetStatusText("",0.55);

// Patch to cover forest floor
   int coverAllID = rmCreateArea("main cover patch");
   rmSetAreaLocation(coverAllID, 0.5, 0.5); 
   rmSetAreaWarnFailure(coverAllID, false);
   rmSetAreaSize(coverAllID, 0.99, 0.99);
   rmSetAreaCoherence(coverAllID, 0.99);
   rmSetAreaElevationType(coverAllID, cElevTurbulence);
   if (patternChance == 1)
      rmSetAreaTerrainType(coverAllID, "great_plains\ground4_gp");
   else if (patternChance == 2) 
      rmSetAreaTerrainType(coverAllID, "great_plains\ground3_gp");  
   rmBuildArea(coverAllID);

// Lower elevation of center and leave rim a little higher and greener
   int depressionID = rmCreateArea("depression patch");
   rmSetAreaLocation(depressionID, 0.5, 0.5); 
   rmSetAreaWarnFailure(depressionID, false);
   rmSetAreaSize(depressionID, 0.95, 0.96);
   rmSetAreaCoherence(depressionID, 0.9);
   rmSetAreaBaseHeight(depressionID, 1.0);
   rmSetAreaElevationEdgeFalloffDist(depressionID, 9.0);
   rmAddAreaConstraint(depressionID, circleConstraintPr);
   rmSetAreaMix(depressionID, baseType);     
   rmBuildArea(depressionID);

// The Badlands
   // base canyon area
   int centerHighlandsID=rmCreateArea("center badlands");
   rmSetAreaLocation(centerHighlandsID, 0.5, 0.5);
   rmSetAreaSize(centerHighlandsID, 0.125, 0.135);
   if (badlandChance == 5)
   {
      rmSetAreaMinBlobs(centerHighlandsID, 7);
      rmSetAreaMaxBlobs(centerHighlandsID, 10);
      rmSetAreaMinBlobDistance(centerHighlandsID, 35.0);
      rmSetAreaMaxBlobDistance(centerHighlandsID, 50.0);
	if (rmRandInt(1,2) == 1)
	{
	   if (axisChance == 1) 
            rmAddAreaInfluenceSegment(centerHighlandsID, 0.5, 0.18, 0.5, 0.82);
	   else
	      rmAddAreaInfluenceSegment(centerHighlandsID, 0.18, 0.5, 0.82, 0.5);
	}
   }
   if (axisChance == 1)
   {
	if (badlandChance == 1)
	{
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.5, 0.16, 0.5, 0.84);
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.36, 0.35, 0.64, 0.65);
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.36, 0.65, 0.64, 0.35);
	}
	else if (badlandChance == 2)
	{
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.5, 0.16, 0.5, 0.84);
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.65, 0.5, 0.35, 0.5);
	}
	else if (badlandChance == 3)
	{
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.37, 0.32, 0.63, 0.32);
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.37, 0.68, 0.63, 0.68);
	   if (rmRandInt(1,2) == 1)
            rmAddAreaInfluenceSegment(centerHighlandsID, 0.5, 0.18, 0.5, 0.82);
	}
	else if (badlandChance == 4)
	{
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.36, 0.32, 0.36, 0.68);
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.64, 0.32, 0.64, 0.68);
	}
   }
   else if (axisChance == 2)
   {
	if (badlandChance == 1)
	{
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.16, 0.5, 0.84, 0.5);
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.35, 0.36, 0.65, 0.64);
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.65, 0.36, 0.35, 0.64);
	}
	else if (badlandChance == 2)
	{
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.16, 0.5, 0.84, 0.5);
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.5, 0.65, 0.5, 0.35);
	}
	else if (badlandChance == 3)
	{
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.32, 0.37, 0.32, 0.63);
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.68, 0.37, 0.68, 0.63);
	   if (rmRandInt(1,2) == 1)
            rmAddAreaInfluenceSegment(centerHighlandsID, 0.18, 0.5, 0.82, 0.5);
	}
	else if (badlandChance == 4)
	{
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.32, 0.36, 0.68, 0.36);
         rmAddAreaInfluenceSegment(centerHighlandsID, 0.32, 0.64, 0.68, 0.64);
	}
   }
   rmAddAreaToClass(centerHighlandsID, rmClassID("classCliff2"));
   rmSetAreaCliffType(centerHighlandsID, cliffType);
   rmSetAreaCliffPainting(centerHighlandsID, true, true, true, 1.5, true);
   if (edgeChance == 1)
      rmSetAreaCliffEdge(centerHighlandsID, 7, 0.128, 0.05, 0.5, 0);
   else if (edgeChance == 2)
      rmSetAreaCliffEdge(centerHighlandsID, 8, 0.115, 0.05, 0.5, 0);
   else if (edgeChance == 3)
      rmSetAreaCliffEdge(centerHighlandsID, 9, 0.105, 0.05, 0.5, 0);
   else if (edgeChance == 4)
      rmSetAreaCliffEdge(centerHighlandsID, 10, 0.092, 0.05, 0.5, 0);
   rmSetAreaCliffHeight(centerHighlandsID, -9, 1.0, 0.8);  
   rmSetAreaSmoothDistance(centerHighlandsID, 12);  
   rmSetAreaCoherence(centerHighlandsID, 0.4);
   rmSetAreaHeightBlend(centerHighlandsID, 1.0);
   rmAddAreaConstraint(centerHighlandsID, avoidTradeRoute);
   rmAddAreaConstraint(centerHighlandsID, avoidSocket);
   rmAddAreaConstraint(centerHighlandsID, forestObjConstraint);
   rmAddAreaConstraint(centerHighlandsID, avoidNativesShorter);
   rmBuildArea(centerHighlandsID);

   // Text
   rmSetStatusText("",0.60);

   // Patches to form edge at badlands, so prairie can be avoided by cliffs, badland items
   int prairiePatchID = rmCreateArea("prairie patch");
   rmAddAreaToClass(prairiePatchID, rmClassID("prairieGrass"));
   if (axisChance == 1)
      rmSetAreaLocation(prairiePatchID, 0.22, 0.5); 
   else
      rmSetAreaLocation(prairiePatchID, 0.5, 0.22); 
   rmSetAreaWarnFailure(prairiePatchID, false);
   rmSetAreaSize(prairiePatchID, 0.18, 0.18);
   rmSetAreaCoherence(prairiePatchID, 0.99);
   rmAddAreaConstraint(prairiePatchID, avoidCliffs2Tiny);
   rmAddAreaConstraint(prairiePatchID, circleConstraintPr);
   rmBuildArea(prairiePatchID);

   int prairiePatch2ID = rmCreateArea("prairie patch 2");
   rmAddAreaToClass(prairiePatch2ID, rmClassID("prairieGrass"));
   if (axisChance == 1)
      rmSetAreaLocation(prairiePatch2ID, 0.78, 0.5); 
   else
      rmSetAreaLocation(prairiePatch2ID, 0.5, 0.78); 
   rmSetAreaWarnFailure(prairiePatch2ID, false);
   rmSetAreaSize(prairiePatch2ID, 0.18, 0.18);
   rmSetAreaCoherence(prairiePatch2ID, 0.99);
   rmAddAreaConstraint(prairiePatch2ID, avoidCliffs2Tiny);
   rmAddAreaConstraint(prairiePatch2ID, circleConstraintPr);
   rmBuildArea(prairiePatch2ID);

   int prairiePatch3ID = rmCreateArea("prairie patch 3");
   rmAddAreaToClass(prairiePatch3ID, rmClassID("prairieGrass"));
   if (axisChance == 1)
      rmSetAreaLocation(prairiePatch3ID, 0.5, 0.9); 
   else
      rmSetAreaLocation(prairiePatch3ID, 0.9, 0.5); 
   rmSetAreaWarnFailure(prairiePatch3ID, false);
   rmSetAreaSize(prairiePatch3ID, 0.12, 0.12);
   rmSetAreaCoherence(prairiePatch3ID, 0.99);
   rmAddAreaConstraint(prairiePatch3ID, avoidCliffs2Tiny);
   rmAddAreaConstraint(prairiePatch3ID, circleConstraintPr);
   rmBuildArea(prairiePatch3ID);

   int prairiePatch4ID = rmCreateArea("prairie patch 4");
   rmAddAreaToClass(prairiePatch4ID, rmClassID("prairieGrass"));
   if (axisChance == 1)
      rmSetAreaLocation(prairiePatch4ID, 0.5, 0.1); 
   else
      rmSetAreaLocation(prairiePatch4ID, 0.1, 0.5); 
   rmSetAreaWarnFailure(prairiePatch4ID, false);
   rmSetAreaSize(prairiePatch4ID, 0.12, 0.12);
   rmSetAreaCoherence(prairiePatch4ID, 0.99);
   rmAddAreaConstraint(prairiePatch4ID, avoidCliffs2Tiny);
   rmAddAreaConstraint(prairiePatch4ID, circleConstraintPr);
   rmBuildArea(prairiePatch4ID);

   for (i=0; <scalingFactor*10)   
   {
      int smallPrairiePatchID=rmCreateArea("small prairie patch "+i); 
      rmSetAreaWarnFailure(smallPrairiePatchID, false);
      rmAddAreaToClass(smallPrairiePatchID, rmClassID("prairieGrass"));
      rmSetAreaSize(smallPrairiePatchID, rmAreaTilesToFraction(50), rmAreaTilesToFraction(90));
      rmSetAreaCoherence(smallPrairiePatchID, 0.3);
      rmAddAreaConstraint(smallPrairiePatchID, avoidCliffs2Tiny);
      rmAddAreaConstraint(smallPrairiePatchID, circleConstraintPr);
      rmAddAreaConstraint(smallPrairiePatchID, avoidPrairieTiny);
      rmBuildArea(smallPrairiePatchID);
   }

   // Badlands floor
   int badlandsFloorID=rmCreateArea("badlands floor", rmAreaID("center badlands")); 
   rmSetAreaWarnFailure(badlandsFloorID, false);
   rmSetAreaSize(badlandsFloorID, 0.99, 0.99);
   if (patternChance == 1)
      rmSetAreaMix(badlandsFloorID, "texas_dirt");
   else    
      rmSetAreaMix(badlandsFloorID, "sonora_dirt");
   rmSetAreaCoherence(badlandsFloorID, 0.99);
   rmBuildArea(badlandsFloorID); 

   // Badlands floor patches
   for (i=0; <scalingFactor*15)   
   {
      int blPatch=rmCreateArea("badlands patch "+i, rmAreaID("center badlands")); 
      rmSetAreaWarnFailure(blPatch, false);
      rmSetAreaSize(blPatch, rmAreaTilesToFraction(45), rmAreaTilesToFraction(60));
	if (patternChance == 1)
         rmSetAreaTerrainType(blPatch, "texas\ground4_tex");
	else
	{
	   if (threeChoice == 1)
            rmSetAreaTerrainType(blPatch, "sonora\cliff_edge_son");
	   else if (threeChoice == 2)
	      rmSetAreaTerrainType(blPatch, "sonora\ground_7_son");
	   else
            rmSetAreaTerrainType(blPatch, "sonora\ground_6_son");

	   threeChoice = rmRandInt(1,3); 
	}
      rmAddAreaToClass(blPatch, rmClassID("classPatch"));
      rmSetAreaMinBlobs(blPatch, 2);
      rmSetAreaMaxBlobs(blPatch, 3);
      rmSetAreaMinBlobDistance(blPatch, 6.0);
      rmSetAreaMaxBlobDistance(blPatch, 15.0);
      rmSetAreaCoherence(blPatch, 0.2);
      rmSetAreaSmoothDistance(blPatch, 10);
      rmAddAreaConstraint(blPatch, shortAvoidImpassableLand);
      rmAddAreaConstraint(blPatch, avoidPrairieShort);
      rmAddAreaConstraint(blPatch, patchConstraint);
      rmBuildArea(blPatch);
   }

   // Text
   rmSetStatusText("",0.65);

/* Contest building in center  ====== special feature for contest disabled for now ======================================
   int contestWinner = -1;
   contestWinner = rmCreateGrouping("Contest Winner!", "Contest Winner");
   rmAddGroupingToClass(contestWinner, rmClassID("importantItem"));
   rmSetGroupingMinDistance(contestWinner, 0.0);   // === can vary slightly off center if OK to add these lines =========
   rmSetGroupingMaxDistance(contestWinner, 35.0);  // ===================================================================
   rmPlaceGroupingAtLoc(contestWinner, 0, 0.5, 0.5);
// alternate would be to use this:        rmPlaceGroupingInArea(contestWinner, 0, rmAreaID("center badlands"), 1); 
====================================================================================================================== */
// Placement of Native Americans part 2 - in badlands
   if (villageCNum == 1)
      rmPlaceGroupingInArea(villageCID, 0, rmAreaID("center badlands"), 1); 

   if (villageCNum == 2)
   {
      rmPlaceGroupingInArea(villageCID, 0, rmAreaID("center badlands"), 1); 
      rmPlaceGroupingInArea(villageCID, 0, rmAreaID("center badlands"), 1); 
   }

   if (villageCNum == 3)
   {
      rmPlaceGroupingInArea(villageCID, 0, rmAreaID("center badlands"), 1); 
      rmPlaceGroupingInArea(villageCID, 0, rmAreaID("center badlands"), 1); 
      rmPlaceGroupingInArea(villageCID, 0, rmAreaID("center badlands"), 1); 
   }

   if (villageDNum == 1)
      rmPlaceGroupingInArea(villageDID, 0, rmAreaID("center badlands"), 1); 

   if (villageDNum == 2)
   {
      rmPlaceGroupingInArea(villageDID, 0, rmAreaID("center badlands"), 1); 
      rmPlaceGroupingInArea(villageDID, 0, rmAreaID("center badlands"), 1); 
   }

// Badlands clearings
   int clearNum = 2 + scalingNumber;
   for (i=0; <clearNum)   
   {
      int blClearingID=rmCreateArea("badlands clear area "+i, rmAreaID("center badlands")); 
      rmSetAreaWarnFailure(blClearingID, false);
      rmSetAreaSize(blClearingID, rmAreaTilesToFraction(75), rmAreaTilesToFraction(100));
      rmAddAreaToClass(blClearingID, rmClassID("clearing"));
      rmSetAreaMinBlobs(blClearingID, 2);
      rmSetAreaMaxBlobs(blClearingID, 3);
      rmSetAreaMinBlobDistance(blClearingID, 6.0);
      rmSetAreaMaxBlobDistance(blClearingID, 15.0);
      rmSetAreaCoherence(blClearingID, 0.5);
      rmAddAreaConstraint(blClearingID, avoidPrairie);
      rmAddAreaConstraint(blClearingID, avoidImportantItem);
      rmBuildArea(blClearingID);
   }

// Badland cliffs
   // Long cliffs
   int cliffSide = rmRandInt(1,2);   
   int twoLongCliffs = 0;
   if (cNumberNonGaiaPlayers > 6)
   {
      if (rmRandInt(1,3) > 1)
         twoLongCliffs = 1;
   }
   else if (cNumberNonGaiaPlayers > 3)
      twoLongCliffs = rmRandInt(1,2);
   else if (cNumberNonGaiaPlayers == 3)
	twoLongCliffs = rmRandInt(1,3);

   int longCliff2ID=rmCreateArea("one long cliff", rmAreaID("center badlands")); 
   rmSetAreaWarnFailure(longCliff2ID, false);
   rmAddAreaToClass(longCliff2ID, rmClassID("classCliff"));
   rmAddAreaToClass(longCliff2ID, rmClassID("impassableCliff"));
   rmSetAreaCliffType(longCliff2ID, cliffType);
   if (axisChance == 1)
   {
	if (cliffSide == 2)
	{
         rmSetAreaLocation(longCliff2ID, 0.5, 0.31);
         rmAddAreaInfluenceSegment(longCliff2ID, 0.5, 0.42, 0.5, 0.21);
	}
	else
	{
         rmSetAreaLocation(longCliff2ID, 0.5, 0.69);
         rmAddAreaInfluenceSegment(longCliff2ID, 0.5, 0.58, 0.5, 0.79);
	}
   }
   else
   {
	if (cliffSide == 2)
	{
         rmSetAreaLocation(longCliff2ID, 0.31, 0.5);
         rmAddAreaInfluenceSegment(longCliff2ID, 0.42, 0.5, 0.21, 0.5);
	}
	else
	{
         rmSetAreaLocation(longCliff2ID, 0.69, 0.5);
         rmAddAreaInfluenceSegment(longCliff2ID, 0.58, 0.5, 0.78, 0.5);
	}
   }
   rmSetAreaSize(longCliff2ID, rmAreaTilesToFraction(scalingFactor*180), rmAreaTilesToFraction(scalingFactor*220));
   rmSetAreaCliffEdge(longCliff2ID, 1, 1.0, 0.1, 1.0, 0);
   rmSetAreaCliffPainting(longCliff2ID, true, true, true, 1.5, true);
   rmSetAreaCliffHeight(longCliff2ID, 8, 1.0, 1.0);
   rmSetAreaCoherence(longCliff2ID, rmRandFloat(0.7, 0.95));
   rmSetAreaSmoothDistance(longCliff2ID, 5);
   rmSetAreaMinBlobs(longCliff2ID, 3);
   rmSetAreaMaxBlobs(longCliff2ID, 3);
   rmSetAreaMinBlobDistance(longCliff2ID, 50.0);
   rmSetAreaMaxBlobDistance(longCliff2ID, 60.0);
   rmAddAreaConstraint(longCliff2ID, avoidImportantItemMed);
   rmAddAreaConstraint(longCliff2ID, avoidPrairie);
   rmAddAreaConstraint(longCliff2ID, avoidNativesShorter);
   rmAddAreaConstraint(longCliff2ID, shortAvoidSilver);
   //rmBuildArea(longCliff2ID);

   if (twoLongCliffs == 1)
   {
      int longCliffID=rmCreateArea("other long cliff", rmAreaID("center badlands")); 
      rmSetAreaWarnFailure(longCliffID, false);
	rmAddAreaToClass(longCliffID, rmClassID("classCliff"));
      rmAddAreaToClass(longCliffID, rmClassID("impassableCliff"));
      rmSetAreaCliffType(longCliffID, cliffType);

      if (axisChance == 1)
      {
  	   if (cliffSide == 1)
 	   {
            rmSetAreaLocation(longCliffID, 0.5, 0.31);
            rmAddAreaInfluenceSegment(longCliffID, 0.5, 0.21, 0.5, 0.42);
	   }
         else
         {
            rmSetAreaLocation(longCliffID, 0.5, 0.69);
            rmAddAreaInfluenceSegment(longCliffID, 0.5, 0.79, 0.5, 0.58);
	   }
      }
      else
      {
	   if (cliffSide == 1)
         {
            rmSetAreaLocation(longCliffID, 0.31, 0.5);
            rmAddAreaInfluenceSegment(longCliffID, 0.21, 0.5, 0.42, 0.5);
 	   }
   	   else
	   {
            rmSetAreaLocation(longCliffID, 0.69, 0.5);
            rmAddAreaInfluenceSegment(longCliffID, 0.79, 0.5, 0.58, 0.5);
 	   }
      }
      rmSetAreaSize(longCliffID, rmAreaTilesToFraction(scalingFactor*180), rmAreaTilesToFraction(scalingFactor*240));
     	rmSetAreaCliffEdge(longCliffID, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffPainting(longCliffID, true, true, true, 1.5, true);
      rmSetAreaCliffHeight(longCliffID, 8, 1.0, 1.0);
      rmSetAreaCoherence(longCliffID, rmRandFloat(0.7, 0.95));
      rmSetAreaSmoothDistance(longCliffID, 5);
      rmSetAreaMinBlobs(longCliffID, 3);
      rmSetAreaMaxBlobs(longCliffID, 3);
      rmSetAreaMinBlobDistance(longCliffID, 50.0);
      rmSetAreaMaxBlobDistance(longCliffID, 60.0);
      rmAddAreaConstraint(longCliffID, avoidImportantItemMed);
	rmAddAreaConstraint(longCliffID, avoidPrairie);
	rmAddAreaConstraint(longCliffID, avoidNativesShorter);
	rmAddAreaConstraint(longCliffID, shortAvoidSilver);
	//rmBuildArea(longCliffID);
   }

   // Text
   rmSetStatusText("",0.70);

   // Biggest cliffs
   int numCliffs = scalingFactor*2; 
   for (i=0; <numCliffs)
   {
	int bigCliffID=rmCreateArea("big cliff" +i, rmAreaID("center badlands")); 
	rmSetAreaWarnFailure(bigCliffID, false);
	rmSetAreaCliffType(bigCliffID, cliffType);
      rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(120), rmAreaTilesToFraction(scalingFactor*160));
	rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
  	if (threeChoice == 1)
      {
         rmAddAreaToClass(bigCliffID, rmClassID("impassableCliff"));
         rmSetAreaCliffEdge(bigCliffID, 1, 1.0, 0.02, 1.0, 0);
         rmSetAreaMinBlobs(bigCliffID, 2);
         rmSetAreaMaxBlobs(bigCliffID, 2);
         rmSetAreaMinBlobDistance(bigCliffID, 50.0);
         rmSetAreaMaxBlobDistance(bigCliffID, 70.0);
         rmAddAreaConstraint(bigCliffID, avoidPrairieLong);
      }
	else
	{
  	   if (threeChoice == 2)
         {
            rmSetAreaCliffEdge(bigCliffID, 1, 0.9, 0.02, 1.0, 0);
         }
  	   else if (threeChoice == 3)
	   {
            rmSetAreaCliffEdge(bigCliffID, 1, 0.75, 0.1, 1.0, 0);
	   }
         rmSetAreaSmoothDistance(bigCliffID, 15);
         rmAddAreaConstraint(bigCliffID, avoidPrairieLonger);
	}
      rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
      rmSetAreaCliffHeight(bigCliffID, 9, 1.0, 1.0);
      rmSetAreaSmoothDistance(bigCliffID, 10);
      rmSetAreaCoherence(bigCliffID, 1);
      rmAddAreaConstraint(bigCliffID, avoidImportantItemMed);
	rmAddAreaConstraint(bigCliffID, avoidNativesShorter);
	rmAddAreaConstraint(bigCliffID, shortAvoidSilver);
	rmAddAreaConstraint(bigCliffID, avoidCenterShort);
	rmAddAreaConstraint(bigCliffID, cliffsAvoidCliffs);
	rmAddAreaConstraint(bigCliffID, clearingConstraint);
	rmBuildArea(bigCliffID);
      threeChoice = rmRandInt(1,3);
   }

   // Middle sized cliffs
   numTries=scalingFactor*4;
   for(i=0; <numTries)
   {
	int mesaID=rmCreateArea("mesa"+i, rmAreaID("center badlands")); 
	rmSetAreaSize(mesaID, rmAreaTilesToFraction(80), rmAreaTilesToFraction(scalingFactor*110)); 
	rmSetAreaWarnFailure(mesaID, false);
	rmSetAreaCliffType(mesaID, cliffType);
	rmAddAreaToClass(mesaID, rmClassID("canyon"));
	rmAddAreaToClass(mesaID, rmClassID("classCliff"));	
  	if (rmRandInt(1,3) > 1)
	{
         rmSetAreaCliffEdge(mesaID, 1, 0.85, 0.05, 1.0, 0); 
         rmSetAreaCliffHeight(mesaID, 9, 1.0, 1.0);
	   rmAddAreaConstraint(mesaID, avoidPrairieLong);
	}
	else
	{
	   rmSetAreaCliffEdge(mesaID, 1, 1.0, 0.1, 1.0, 0);
         rmSetAreaCliffHeight(mesaID, 9, 1.0, 1.0);
	   rmSetAreaMinBlobs(mesaID, 2);
	   rmSetAreaMaxBlobs(mesaID, 2);
	   rmSetAreaMinBlobDistance(mesaID, 15.0);
	   rmSetAreaMaxBlobDistance(mesaID, 20.0);
	   rmAddAreaToClass(mesaID, rmClassID("impassableCliff"));
	   rmAddAreaConstraint(mesaID, avoidPrairieLonger);
	}
      rmSetAreaSmoothDistance(mesaID, 10);
	rmSetAreaCoherence(mesaID, 1);
	rmAddAreaConstraint(mesaID, avoidCanyons);
	rmAddAreaConstraint(mesaID, avoidCliffsShort);
	rmAddAreaConstraint(mesaID, avoidNativesShorter);
	rmAddAreaConstraint(mesaID, shortAvoidSilver);
	rmAddAreaConstraint(mesaID, avoidImportantItemMed);
	rmAddAreaConstraint(mesaID, avoidCenterShort);
	rmAddAreaConstraint(mesaID, clearingConstraint);
	rmBuildArea(mesaID);
   }

   // Smaller ridges or hills
   numTries=scalingFactor*4;
   for(i=0; <numTries)
   {
	int smallMesaID=rmCreateArea("small mesa"+i, rmAreaID("center badlands")); 
	rmSetAreaWarnFailure(smallMesaID, false);
	rmSetAreaCliffType(smallMesaID, cliffType);
	rmAddAreaToClass(smallMesaID, rmClassID("canyon"));
	rmAddAreaToClass(smallMesaID, rmClassID("classCliff"));
      twoChoice = rmRandInt(1,2);
      if (twoChoice == 1)
      {
         rmSetAreaCliffEdge(smallMesaID, 1, 0.9, 0.02, 1.0, 0);
      }
      else if (twoChoice == 2)
      {
         rmSetAreaCliffEdge(smallMesaID, 1, 0.75, 0.1, 1.0, 0);
      }
      rmSetAreaSmoothDistance(smallMesaID, 10);
	rmSetAreaCliffHeight(smallMesaID, rmRandInt(6,7), 1.0, 1.0);
	rmSetAreaMinBlobs(smallMesaID, 2);
	rmSetAreaMaxBlobs(smallMesaID, 2);
      rmSetAreaSize(smallMesaID, rmAreaTilesToFraction(50), rmAreaTilesToFraction(100));  
      rmSetAreaMinBlobDistance(smallMesaID, 12.0);
      rmSetAreaMaxBlobDistance(smallMesaID, 16.0);
	rmSetAreaCoherence(smallMesaID, 1);
	rmAddAreaConstraint(smallMesaID, shortAvoidCanyons);
	rmAddAreaConstraint(smallMesaID, avoidCliffsShort);
	rmAddAreaConstraint(smallMesaID, avoidPrairieLonger);
	rmAddAreaConstraint(smallMesaID, avoidNativesShorter); 
	rmAddAreaConstraint(smallMesaID, shortAvoidSilver);
	rmAddAreaConstraint(smallMesaID, avoidImportantItemMed);
	rmAddAreaConstraint(smallMesaID, avoidCenterShort);
	rmAddAreaConstraint(smallMesaID, clearingConstraint);
	//rmBuildArea(smallMesaID);
   }

   // Text
   rmSetStatusText("",0.75);

// Extra silver mines - distant, and near ends of axis.
   silverType = rmRandInt(1,10);
   int extraMineID = rmCreateObjectDef("extra silver "+i);
   rmAddObjectDefItem(extraMineID, "mine", 1, 0.0);
   rmAddObjectDefToClass(extraMineID, rmClassID("importantItem"));
   rmAddObjectDefConstraint(extraMineID, avoidTradeRoute);
   rmAddObjectDefConstraint(extraMineID, avoidSocket);
   rmAddObjectDefConstraint(extraMineID, coinAvoidCoin);
   rmAddObjectDefConstraint(extraMineID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(extraMineID, avoidAll);
   rmAddObjectDefConstraint(extraMineID, avoidCliffs2Short);
   rmSetObjectDefMinDistance(extraMineID, 0.0);
   rmSetObjectDefMaxDistance(extraMineID, size*0.15);
   rmPlaceObjectDefAtLoc(extraMineID, 0, 0.5, 0.5, rmRandInt(1,3));
   if (cNumberNonGaiaPlayers > 4)
      rmPlaceObjectDefAtLoc(extraMineID, 0, 0.5, 0.5, 1);
   if (cNumberNonGaiaPlayers > 6)
      rmPlaceObjectDefAtLoc(extraMineID, 0, 0.5, 0.5, 1);
   if (axisChance == 1)
   {
      rmPlaceObjectDefAtLoc(extraMineID, 0, 0.5, 0.85, 1);
      rmPlaceObjectDefAtLoc(extraMineID, 0, 0.5, 0.15, 1);
   }
   else
   {
      rmPlaceObjectDefAtLoc(extraMineID, 0, 0.85, 0.5, 1);
      rmPlaceObjectDefAtLoc(extraMineID, 0, 0.15, 0.5, 1);
   }

   silverType = rmRandInt(1,10);
   int mineFarID=rmCreateObjectDef("player silver far");
   rmAddObjectDefItem(mineFarID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(mineFarID, avoidTradeRoute);
   rmAddObjectDefConstraint(mineFarID, avoidSocket);
   rmAddObjectDefConstraint(mineFarID, coinAvoidCoin);
   rmAddObjectDefConstraint(mineFarID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(mineFarID, objEdgeConstraint);
   rmAddObjectDefConstraint(mineFarID, avoidAll);
   rmAddObjectDefConstraint(mineFarID, avoidCliffs2Short);
   rmAddObjectDefConstraint(mineFarID, farPlayerConstraint);
   rmSetObjectDefMinDistance(mineFarID, size*0.25);
   rmSetObjectDefMaxDistance(mineFarID, size*0.33);
   rmPlaceObjectDefPerPlayer(mineFarID, false, 1);

   silverType = rmRandInt(1,10);
   int mineEdgeID=rmCreateObjectDef("player silver edge");
   rmAddObjectDefItem(mineEdgeID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(mineEdgeID, avoidTradeRoute);
   rmAddObjectDefConstraint(mineEdgeID, avoidSocket);
   rmAddObjectDefConstraint(mineEdgeID, coinAvoidCoin);
   rmAddObjectDefConstraint(mineEdgeID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(mineEdgeID, objEdgeConstraint);
   rmAddObjectDefConstraint(mineEdgeID, centerConstraintForest);
   rmAddObjectDefConstraint(mineEdgeID, avoidAll);
   rmAddObjectDefConstraint(mineEdgeID, avoidCliffs2Short);
   rmSetObjectDefMinDistance(mineEdgeID, size*0.2);
   rmSetObjectDefMaxDistance(mineEdgeID, size*0.4);
   rmAddObjectDefConstraint(mineEdgeID, fartherPlayerConstraint);
   rmPlaceObjectDefPerPlayer(mineEdgeID, false, 1);

   silverType = rmRandInt(1,10);
   int mineFartherID=rmCreateObjectDef("player silver farther");
   rmAddObjectDefItem(mineFartherID, "mine", 1, 0.0);
   rmAddObjectDefConstraint(mineFartherID, avoidTradeRoute);
   rmAddObjectDefConstraint(mineFartherID, avoidSocket);
   rmAddObjectDefConstraint(mineFartherID, coinAvoidCoin);
   rmAddObjectDefConstraint(mineFartherID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(mineFartherID, objEdgeConstraint);
   rmAddObjectDefConstraint(mineFartherID, avoidAll);
   rmAddObjectDefConstraint(mineFartherID, avoidCliffs2Short);
   rmSetObjectDefMinDistance(mineFartherID, size*0.37);
   rmSetObjectDefMaxDistance(mineFartherID, size*0.5);
   rmAddObjectDefConstraint(mineFartherID, fartherPlayerConstraint);
   if (rmRandInt(1,2) == 1)
      rmPlaceObjectDefPerPlayer(mineFartherID, false, 1);

// Random Nuggets
   int nugget2= rmCreateObjectDef("nugget medium"); 
   rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(2, 2);
   rmAddObjectDefToClass(nugget2, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(nugget2, 60.0);
   rmSetObjectDefMaxDistance(nugget2, size*0.33);
   rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget2, avoidImpassableCliff);
   rmAddObjectDefConstraint(nugget2, avoidSocket);
   rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
   rmAddObjectDefConstraint(nugget2, nuggetPlayerConstraint);
   rmAddObjectDefConstraint(nugget2, avoidNuggetMed);
   rmAddObjectDefConstraint(nugget2, avoidAll);
   rmAddObjectDefConstraint(nugget2, objEdgeConstraint);
   rmPlaceObjectDefPerPlayer(nugget2, false, 1);

   int nugget3= rmCreateObjectDef("nugget hard"); 
   rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(3, 3);
   rmAddObjectDefToClass(nugget3, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(nugget3, 80.0);
   rmSetObjectDefMaxDistance(nugget3, size*0.5);
   rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget3, avoidImpassableCliff);
   rmAddObjectDefConstraint(nugget3, avoidSocket);
   rmAddObjectDefConstraint(nugget3, avoidTradeRoute);
   rmAddObjectDefConstraint(nugget3, farPlayerConstraint);
   rmAddObjectDefConstraint(nugget3, avoidNuggetLong);
   rmAddObjectDefConstraint(nugget3, avoidAll);
   rmAddObjectDefConstraint(nugget3, objEdgeConstraint);
   rmPlaceObjectDefPerPlayer(nugget3, false, 1);

   rmAddObjectDefConstraint(nugget3, fartherPlayerConstraint);
   rmSetNuggetDifficulty(2, 3);
   rmPlaceObjectDefAtLoc(nugget3, 0, 0.5, 0.5, 1);
   rmSetNuggetDifficulty(2, 3);
   rmPlaceObjectDefPerPlayer(nugget3, false, 1);

   int nugget4= rmCreateObjectDef("nugget nuts"); 
   rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(4, 4);
   rmAddObjectDefToClass(nugget4, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(nugget4, 85.0);
   rmSetObjectDefMaxDistance(nugget4, size*0.4);
   rmAddObjectDefConstraint(nugget4, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget4, avoidImpassableCliff);
   rmAddObjectDefConstraint(nugget4, avoidSocket);
   rmAddObjectDefConstraint(nugget4, avoidTradeRoute);
   rmAddObjectDefConstraint(nugget4, fartherPlayerConstraint);
   rmAddObjectDefConstraint(nugget4, avoidNuggetLong);
   rmAddObjectDefConstraint(nugget4, avoidAll);
   rmAddObjectDefConstraint(nugget4, objEdgeConstraint);
   rmPlaceObjectDefAtLoc(nugget4, 0, 0.5, 0.5, 1);
   rmPlaceObjectDefPerPlayer(nugget4, false, 1);

   // Text
   rmSetStatusText("",0.80);

// Second huntable
   int deer2Num = rmRandInt(4,7);
   int farPronghornID=rmCreateObjectDef("far pronghorn");
   rmAddObjectDefItem(farPronghornID, deer2Type, deer2Num, 5.0);
   rmAddObjectDefToClass(farPronghornID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(farPronghornID, 42.0);
   rmSetObjectDefMaxDistance(farPronghornID, 60.0);
   rmAddObjectDefConstraint(farPronghornID, mediumPlayerConstraint);
   rmAddObjectDefConstraint(farPronghornID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(farPronghornID, avoidNativesShorter);
   rmAddObjectDefConstraint(farPronghornID, huntableConstraint);
   rmAddObjectDefConstraint(farPronghornID, avoidCliffsShort);
   rmAddObjectDefConstraint(farPronghornID, avoidAll);
   rmSetObjectDefCreateHerd(farPronghornID, true);
   rmPlaceObjectDefPerPlayer(farPronghornID, false, 1);

// Central herds
   int centNum = 3;
   if (cNumberNonGaiaPlayers > 6)
	centNum = 6;
   else if (cNumberNonGaiaPlayers > 4)
	centNum = 5;
   else if (cNumberNonGaiaPlayers == 4)
	centNum = 4;

   int centralHerdID=rmCreateObjectDef("central herd");  
   rmAddObjectDefItem(centralHerdID, "bison", rmRandInt(12,16), 6.0);
   rmAddObjectDefToClass(centralHerdID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(centralHerdID, size*0.05);
   rmSetObjectDefMaxDistance(centralHerdID, size*0.35);
   rmAddObjectDefConstraint(centralHerdID, avoidTradeRouteShort);
   rmAddObjectDefConstraint(centralHerdID, avoidImportantItem);
   rmAddObjectDefConstraint(centralHerdID, farPlayerConstraint);
   rmAddObjectDefConstraint(centralHerdID, longHuntableConstraint);
   rmAddObjectDefConstraint(centralHerdID, avoidCliffsShort);
   rmSetObjectDefCreateHerd(centralHerdID, true);
   rmPlaceObjectDefAtLoc(centralHerdID, 0, 0.5, 0.5, centNum);

   // additional of central herd type on prairie
   rmSetObjectDefMinDistance(centralHerdID, size*0.22);
   rmSetObjectDefMaxDistance(centralHerdID, size*0.4);
   rmAddObjectDefConstraint(centralHerdID, avoidCliffs2Short);
   rmPlaceObjectDefPerPlayer(centralHerdID, false, 1);

   // Text
   rmSetStatusText("",0.85);

// Far huntable
   int farHuntableID=rmCreateObjectDef("far huntable");
   rmAddObjectDefItem(farHuntableID, deerType, rmRandInt(4,6), 6.0);
   rmAddObjectDefToClass(farHuntableID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(farHuntableID, size*0.33);
   rmSetObjectDefMaxDistance(farHuntableID, size*0.4);
   rmAddObjectDefConstraint(farHuntableID, avoidTradeRouteShort);
   rmAddObjectDefConstraint(farHuntableID, avoidImportantItem);
   rmAddObjectDefConstraint(farHuntableID, farPlayerConstraint);
   rmAddObjectDefConstraint(farHuntableID, longHuntableConstraint);
   rmAddObjectDefConstraint(farHuntableID, avoidCliffsShort);
   rmAddObjectDefConstraint(farHuntableID, avoidAll);
   rmSetObjectDefCreateHerd(farHuntableID, true);
   rmPlaceObjectDefPerPlayer(farHuntableID, false, 1);

// Additional second huntable, on prairie 
   rmAddObjectDefConstraint(farPronghornID, avoidCliffs2Short);
   if (cNumberNonGaiaPlayers < 4)
   {
      rmSetObjectDefMinDistance(farPronghornID, size*0.27);
      rmSetObjectDefMaxDistance(farPronghornID, size*0.42);
      rmPlaceObjectDefPerPlayer(farPronghornID, false, 1);
   }
   if (cNumberNonGaiaPlayers == 4)
   {
      rmSetObjectDefMinDistance(farPronghornID, size*0.22);
      rmSetObjectDefMaxDistance(farPronghornID, size*0.4);
      rmPlaceObjectDefAtLoc(farPronghornID, 0, 0.5, 0.5, 2);
   }
   if (cNumberNonGaiaPlayers > 4)
   {
      rmSetObjectDefMinDistance(farPronghornID, size*0.22);
      rmSetObjectDefMaxDistance(farPronghornID, size*0.4);
      rmPlaceObjectDefAtLoc(farPronghornID, 0, 0.5, 0.5, 3);
   }

// Lone elk
   int loneElkID=rmCreateObjectDef("lone elk");
   if (rmRandInt(1,3) > 1)
      rmAddObjectDefItem(loneElkID, "elk", rmRandInt(1,2), 3.0);
   else
      rmAddObjectDefItem(loneElkID, "deer", rmRandInt(1,2), 3.0);
   rmAddObjectDefToClass(loneElkID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(loneElkID, 60.0);
   rmSetObjectDefMaxDistance(loneElkID, size*0.4);
   rmAddObjectDefConstraint(loneElkID, nuggetPlayerConstraint);
   rmAddObjectDefConstraint(loneElkID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(loneElkID, avoidNativesShorter);
   rmAddObjectDefConstraint(loneElkID, huntableConstraint);
   rmAddObjectDefConstraint(loneElkID, centerConstraintForest);
   rmAddObjectDefConstraint(loneElkID, avoidAll);
   rmSetObjectDefCreateHerd(loneElkID, true);
   rmPlaceObjectDefPerPlayer(loneElkID, false, 2);

// Sheep etc
   int sheepID=rmCreateObjectDef("herdable animal");
   rmAddObjectDefItem(sheepID, sheepType, 2, 4.0);
   rmAddObjectDefToClass(sheepID, rmClassID("herdableFood"));
   rmSetObjectDefMinDistance(sheepID, 35.0);
   rmSetObjectDefMaxDistance(sheepID, size*0.33);
   rmAddObjectDefConstraint(sheepID, avoidSheep);
   rmAddObjectDefConstraint(sheepID, avoidAll);
   rmAddObjectDefConstraint(sheepID, playerConstraint);
   rmAddObjectDefConstraint(sheepID, avoidCliffsShort);
   rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
   rmPlaceObjectDefPerPlayer(sheepID, false, 2); 

   rmAddObjectDefConstraint(sheepID, farPlayerConstraint);
   rmSetObjectDefMaxDistance(sheepID, size*0.5);
   rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2); 

// Random trees
   int StragglerTreeID=rmCreateObjectDef("stragglers");
   rmAddObjectDefItem(StragglerTreeID, "TreeGreatPlains", 1, 0.0);
   rmAddObjectDefConstraint(StragglerTreeID, avoidAll);
   rmAddObjectDefConstraint(StragglerTreeID, avoidCliffs2Short);
   rmAddObjectDefConstraint(StragglerTreeID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(StragglerTreeID, avoidCoin);
   rmAddObjectDefConstraint(StragglerTreeID, centerConstraintForest2);
   rmPlaceObjectDefAtLoc(StragglerTreeID, 0, 0.5, 0.5, scalingFactor*40);
   
   // Text
   rmSetStatusText("",0.90);

// Deco
   // Patches 
   if (patternChance == 1)
   {
      for (i=0; <scalingFactor*12)   // lighter green or green with bare patches
      {
	   int gpPatch0=rmCreateArea("GP patch 0"+i);
	   rmSetAreaWarnFailure(gpPatch0, false);
	   rmSetAreaSize(gpPatch0, rmAreaTilesToFraction(60), rmAreaTilesToFraction(90));
	   if (rmRandInt(1,2) > 1)
	      rmSetAreaTerrainType(gpPatch0, "great_plains\ground6_gp");
	   else
	      rmSetAreaTerrainType(gpPatch0, "great_plains\ground8_gp");
	   rmAddAreaToClass(gpPatch0, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatch0, 2);
	   rmSetAreaMaxBlobs(gpPatch0, 4);
	   rmSetAreaMinBlobDistance(gpPatch0, 5.0);
	   rmSetAreaMaxBlobDistance(gpPatch0, 12.0);
	   rmSetAreaCoherence(gpPatch0, 0.3);
	   rmSetAreaSmoothDistance(gpPatch0, 10);
	   rmAddAreaConstraint(gpPatch0, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatch0, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatch0, avoidCliffs2Short);
	   rmAddAreaConstraint(gpPatch0, shortForestConstraint);
	   rmAddAreaConstraint(gpPatch0, patchConstraint);
	   rmBuildArea(gpPatch0); 
      }

      for (i=0; <scalingFactor*12)    // different greens
      {
	   int gpPatch1=rmCreateArea("GP patch 1"+i);
	   rmSetAreaWarnFailure(gpPatch1, false);
	   rmSetAreaSize(gpPatch1, rmAreaTilesToFraction(40), rmAreaTilesToFraction(80));
	   if (rmRandInt(1,2) == 1)
	      rmSetAreaTerrainType(gpPatch1, "great_plains\ground5_gp");
	   else
	      rmSetAreaTerrainType(gpPatch1, "great_plains\ground1_gp");
	   rmAddAreaToClass(gpPatch1, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatch1, 2);
	   rmSetAreaMaxBlobs(gpPatch1, 4);
	   rmSetAreaMinBlobDistance(gpPatch1, 6.0);
	   rmSetAreaMaxBlobDistance(gpPatch1, 18.0);
	   rmSetAreaCoherence(gpPatch1, 0.1);
	   rmSetAreaSmoothDistance(gpPatch1, 10);
	   rmAddAreaConstraint(gpPatch1, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatch1, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatch1, avoidCliffs2Short);
	   rmAddAreaConstraint(gpPatch1, patchConstraint);
	   rmBuildArea(gpPatch1); 
      }

      for (i=0; <scalingFactor*16)   // flowers
      {
	   int gpPatch2=rmCreateArea("GP patch 2"+i);
	   rmSetAreaWarnFailure(gpPatch2, false);
	   rmSetAreaSize(gpPatch2, rmAreaTilesToFraction(50), rmAreaTilesToFraction(90));
	   if (rmRandInt(1,2) == 1)
	      rmSetAreaTerrainType(gpPatch2, "great_lakes\ground_grass4_gl");
	   else
	      rmSetAreaTerrainType(gpPatch2, "great_lakes\ground_grass5_gl");
	   rmAddAreaToClass(gpPatch2, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatch2, 2);
	   rmSetAreaMaxBlobs(gpPatch2, 4);
	   rmSetAreaMinBlobDistance(gpPatch2, 5.0);
	   rmSetAreaMaxBlobDistance(gpPatch2, 12.0);
	   rmSetAreaCoherence(gpPatch2, 0.3);
	   rmSetAreaSmoothDistance(gpPatch2, 10);
	   rmAddAreaConstraint(gpPatch2, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatch2, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatch2, avoidCliffs2Short);
	   rmBuildArea(gpPatch2); 
      }
  
      for (i=0; <scalingFactor*12)   // more flowers
      {
	   int gpPatch3=rmCreateArea("GP patch 3"+i);
	   rmSetAreaWarnFailure(gpPatch3, false);
	   rmSetAreaSize(gpPatch3, rmAreaTilesToFraction(40), rmAreaTilesToFraction(60));
	   if (rmRandInt(1,2) == 1)
	      rmSetAreaTerrainType(gpPatch3, "great_lakes\ground_grass4_gl");
	   else
	      rmSetAreaTerrainType(gpPatch3, "great_lakes\ground_grass5_gl");
	   rmAddAreaToClass(gpPatch3, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatch3, 2);
	   rmSetAreaMaxBlobs(gpPatch3, 3);
	   rmSetAreaMinBlobDistance(gpPatch3, 5.0);
	   rmSetAreaMaxBlobDistance(gpPatch3, 12.0);
	   rmSetAreaCoherence(gpPatch3, 0.3);
	   rmSetAreaSmoothDistance(gpPatch3, 10);
	   rmAddAreaConstraint(gpPatch3, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatch3, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatch3, avoidCliffs2Short);
	   rmBuildArea(gpPatch3); 
      }
   }

   if (patternChance == 2)
   {
      for (i=0; <scalingFactor*12) // green patches at edge
      {
	   int gpPatchB=rmCreateArea("GP patch B"+i);
	   rmSetAreaWarnFailure(gpPatchB, false);
	   rmSetAreaSize(gpPatchB, rmAreaTilesToFraction(70), rmAreaTilesToFraction(160));
         rmSetAreaTerrainType(gpPatchB, "great_plains\ground8_gp");
	   rmAddAreaToClass(gpPatchB, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatchB, 2);
	   rmSetAreaMaxBlobs(gpPatchB, 4);
	   rmSetAreaMinBlobDistance(gpPatchB, 12.0);
	   rmSetAreaMaxBlobDistance(gpPatchB, 20.0);
	   rmSetAreaCoherence(gpPatchB, rmRandFloat(0.1,0.4));
	   rmSetAreaSmoothDistance(gpPatchB, 10);
	   rmAddAreaConstraint(gpPatchB, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatchB, avoidCliffs2Short);
	   rmAddAreaConstraint(gpPatchB, centerConstraintForest);
	   rmAddAreaConstraint(gpPatchB, patchConstraint);
	   rmBuildArea(gpPatchB); 
      }

      for (i=0; <scalingFactor*16)  // more green at edge 
      {
	   int gpPatchD=rmCreateArea("GP patch D"+i);
	   rmSetAreaWarnFailure(gpPatchD, false);
	   rmSetAreaSize(gpPatchD, rmAreaTilesToFraction(15), rmAreaTilesToFraction(70));
         rmSetAreaTerrainType(gpPatchD, "great_plains\ground8_gp");
	   rmAddAreaToClass(gpPatchD, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatchD, 2);
	   rmSetAreaMaxBlobs(gpPatchD, 3);
	   rmSetAreaMinBlobDistance(gpPatchD, 12.0);
	   rmSetAreaMaxBlobDistance(gpPatchD, 20.0);
	   rmSetAreaCoherence(gpPatchD, 0.1);
	   rmSetAreaSmoothDistance(gpPatchD, 10);
	   rmAddAreaConstraint(gpPatchD, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatchD, avoidCliffs2Short);
	   rmAddAreaConstraint(gpPatchD, patchConstraint);  
	   rmAddAreaConstraint(gpPatchD, centerConstraintForest);
	   rmBuildArea(gpPatchD); 
      }

      for (i=0; <scalingFactor*8)  // more brown bare, stony areas away from edge
      {
	   int gpPatchA=rmCreateArea("GP patch A"+i);
	   rmSetAreaWarnFailure(gpPatchA, false);
	   rmSetAreaSize(gpPatchA, rmAreaTilesToFraction(75), rmAreaTilesToFraction(140));
         rmSetAreaTerrainType(gpPatchA, "great_plains\ground2_gp");
	   rmAddAreaToClass(gpPatchA, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatchA, 2);
	   rmSetAreaMaxBlobs(gpPatchA, 4);
	   rmSetAreaMinBlobDistance(gpPatchA, 5.0);
	   rmSetAreaMaxBlobDistance(gpPatchA, 12.0);
	   rmSetAreaCoherence(gpPatchA, 0.3);
	   rmSetAreaSmoothDistance(gpPatchA, 10);
	   rmAddAreaConstraint(gpPatchA, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatchA, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatchA, avoidCliffs2Short);
	   rmAddAreaConstraint(gpPatchA, patchConstraint);
	   rmAddAreaConstraint(gpPatchA, circleConstraintPr);
	   rmBuildArea(gpPatchA); 
      }

      for (i=0; <scalingFactor*12)   // little green patches
      {
	   int gpPatchC=rmCreateArea("GP patch C"+i);
	   rmSetAreaWarnFailure(gpPatchC, false);
	   rmSetAreaSize(gpPatchC, rmAreaTilesToFraction(15), rmAreaTilesToFraction(40));
         rmSetAreaTerrainType(gpPatchC, "great_plains\ground8_gp");
	   rmAddAreaToClass(gpPatchC, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatchC, 2);
	   rmSetAreaMaxBlobs(gpPatchC, 4);
	   rmSetAreaMinBlobDistance(gpPatchC, 6.0);
	   rmSetAreaMaxBlobDistance(gpPatchC, 12.0);
	   rmSetAreaCoherence(gpPatchC, 0.1);
	   rmSetAreaSmoothDistance(gpPatchC, 10);
	   rmAddAreaConstraint(gpPatchC, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatchC, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatchC, avoidCliffs2Short);
	   rmAddAreaConstraint(gpPatchC, patchConstraint);
	   rmBuildArea(gpPatchC); 
      }
   }

   // Text
   rmSetStatusText("",0.95);



// Props
   if (patternChance == 2)
   {
      int bisonCarcass=rmCreateGrouping("Bison Carcass", "gp_carcass_bison");
      rmAddGroupingToClass(bisonCarcass, rmClassID("propClass"));
      rmSetGroupingMinDistance(bisonCarcass, 0.0);
      rmSetGroupingMaxDistance(bisonCarcass, longSide*0.39);
      rmAddGroupingConstraint(bisonCarcass, avoidImpassableLand);
      rmAddGroupingConstraint(bisonCarcass, playerConstraint);
      rmAddGroupingConstraint(bisonCarcass, avoidTradeRoute);
      rmAddGroupingConstraint(bisonCarcass, avoidSocket);
      rmAddGroupingConstraint(bisonCarcass, avoidStartingUnits);
      rmAddGroupingConstraint(bisonCarcass, avoidAll);
      rmAddGroupingConstraint(bisonCarcass, avoidCliffsShort);
      rmAddGroupingConstraint(bisonCarcass, avoidCliffs2Short);
      rmAddGroupingConstraint(bisonCarcass, avoidNuggetSmall);
      rmAddGroupingConstraint(bisonCarcass, avoidProp);
      rmPlaceGroupingAtLoc(bisonCarcass, 0, 0.5, 0.5, rmRandInt(2,3));
   }

   int vultureID=rmCreateObjectDef("perching vultures");
   rmAddObjectDefItem(vultureID, "PropVulturePerching", 1, 0.0);
   rmAddObjectDefToClass(vultureID, rmClassID("propClass"));
   rmSetObjectDefMinDistance(vultureID, 0.0);
   rmSetObjectDefMaxDistance(vultureID, longSide*0.39);
   rmAddObjectDefConstraint(vultureID, avoidAll);
   rmAddObjectDefConstraint(vultureID, avoidImportantItem);
   rmAddObjectDefConstraint(vultureID, avoidCoin);
   rmAddObjectDefConstraint(vultureID, avoidImpassableLand);
   rmAddObjectDefConstraint(vultureID, avoidTradeRouteShort);
   rmAddObjectDefConstraint(vultureID, avoidCliffsShort);
   rmAddObjectDefConstraint(vultureID, avoidProp);
   rmAddObjectDefConstraint(vultureID, nuggetPlayerConstraint);
   rmPlaceObjectDefAtLoc(vultureID, 0, 0.5, 0.5, 2);

   int randomEagleTreeID=rmCreateObjectDef("random eagle tree");
   rmAddObjectDefItem(randomEagleTreeID, "EaglesNest", 1, 0.0);
   rmAddObjectDefToClass(randomEagleTreeID, rmClassID("propClass"));
   rmSetObjectDefMinDistance(randomEagleTreeID, 0.0);
   rmSetObjectDefMaxDistance(randomEagleTreeID, longSide*0.42);
   rmAddObjectDefConstraint(randomEagleTreeID, avoidAll);
   rmAddObjectDefConstraint(randomEagleTreeID, avoidCliffsShort);
   rmAddObjectDefConstraint(randomEagleTreeID, avoidCliffs2Short);
   rmAddObjectDefConstraint(randomEagleTreeID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(randomEagleTreeID, avoidProp);
   rmAddObjectDefConstraint(randomEagleTreeID, nuggetPlayerConstraint);
   rmPlaceObjectDefAtLoc(randomEagleTreeID, 0, 0.5, 0.5, rmRandInt(2,3));

   // Text
   rmSetStatusText("",0.99);

  // King of the Hill (added 2026-11 for WoL): centre of the badlands, inside the ring of start positions
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