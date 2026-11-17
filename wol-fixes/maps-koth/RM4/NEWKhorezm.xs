// Khorezm
// Old RED BEACH a deliberate modification of orinoco.

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";


void main(void)
{
   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

   //Chooses which natives appear on the map
   int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;
   int subCiv3=-1;


	// All tupi all the time
   if (rmAllocateSubCivs(4) == true)
   {
		if(rmRandFloat(1,1) > 0.50) 
		{ //this is a mixed range and melee map
			if(rmRandFloat(0,1) > 0.50) 
			{ //Tupi or Caribs
				string rangedCiv = "zen"; //tupi
			}
			else
			{
				rangedCiv = "Caribs"; //caribs
			}
			if(rmRandFloat(0,1) > 0.50)
			{ //Zapotec or Maya
				string meleeCiv = "zen"; //zapotec
			}
			else
			{
				meleeCiv = "Paulista"; //Maya
			}
			
			if(rmRandFloat(0,1) > 0.50) 
			{ //Ranged Top Left and Bottom Right
				subCiv0=rmGetCivID(rangedCiv);
				if (subCiv0 >= 0)
					rmSetSubCiv(0, rangedCiv);
				subCiv1=rmGetCivID(meleeCiv);
				if (subCiv1 >= 0)
					rmSetSubCiv(1, meleeCiv);

				subCiv2=rmGetCivID(meleeCiv);
				if (subCiv2 >= 0)
					rmSetSubCiv(2, meleeCiv);

				subCiv3=rmGetCivID(rangedCiv);
				if (subCiv3 >= 0)
					rmSetSubCiv(3, rangedCiv);
			}
			else
			{ //Melee Top Left and Bottom Right
				subCiv0=rmGetCivID(meleeCiv);
				if (subCiv0 >= 0)
					rmSetSubCiv(0, meleeCiv);
				subCiv1=rmGetCivID(rangedCiv);
				if (subCiv1 >= 0)
					rmSetSubCiv(1, rangedCiv);

				subCiv2=rmGetCivID(rangedCiv);
				if (subCiv2 >= 0)
					rmSetSubCiv(2, rangedCiv);

				subCiv3=rmGetCivID(meleeCiv);
				if (subCiv3 >= 0)
					rmSetSubCiv(3, meleeCiv);
			}

		}
		else
		{ //this is a all ranged or all melee map
			if(rmRandFloat(0,1) > 0.50) 
			{ //Ranged only (Tupi & Caribs)
				if(rmRandFloat(0,1) > 0.50) 
				{ //Tupi Top Left and Bottom Right
					subCiv0=rmGetCivID("zen");
					if (subCiv0 >= 0)
						rmSetSubCiv(0, "zen");
					subCiv1=rmGetCivID("shaolin");
					if (subCiv1 >= 0)
						rmSetSubCiv(1, "shaolin");

					subCiv2=rmGetCivID("shaolin");
					if (subCiv2 >= 0)
						rmSetSubCiv(2, "shaolin");

					subCiv3=rmGetCivID("zen");
					if (subCiv3 >= 0)
						rmSetSubCiv(3, "zen");
				}
				else
				{ //Tupi Bottom Left and Top Right
					subCiv0=rmGetCivID("shaolin");
					if (subCiv0 >= 0)
						rmSetSubCiv(0, "shaolin");
					subCiv1=rmGetCivID("zen");
					if (subCiv1 >= 0)
						rmSetSubCiv(1, "zen");

					subCiv2=rmGetCivID("zen");
					if (subCiv2 >= 0)
						rmSetSubCiv(2, "zen");

					subCiv3=rmGetCivID("shaolin");
					if (subCiv3 >= 0)
						rmSetSubCiv(3, "shaolin");
				}
			}
			else
			{ //Melee only (Zapotec & Maya)
				if(rmRandFloat(0,1) > 0.50) 
				{ //Zapotec Top Left and Bottom Right
					subCiv0=rmGetCivID("zen");
					if (subCiv0 >= 0)
						rmSetSubCiv(0, "zen");
					subCiv1=rmGetCivID("shaolin");
					if (subCiv1 >= 0)
						rmSetSubCiv(1, "shaolin");

					subCiv2=rmGetCivID("shaolin");
					if (subCiv2 >= 0)
						rmSetSubCiv(2, "shaolin");

					subCiv3=rmGetCivID("zen");
					if (subCiv3 >= 0)
						rmSetSubCiv(3, "zen");
				}
				else
				{ //Zapotec Bottom Left and Top Right
					subCiv0=rmGetCivID("shaolin");
					if (subCiv0 >= 0)
						rmSetSubCiv(0, "shaolin");
					subCiv1=rmGetCivID("zen");
					if (subCiv1 >= 0)
						rmSetSubCiv(1, "zen");

					subCiv2=rmGetCivID("zen");
					if (subCiv2 >= 0)
						rmSetSubCiv(2, "zen");

					subCiv3=rmGetCivID("shaolin");
					if (subCiv3 >= 0)
						rmSetSubCiv(3, "shaolin");
				}

			}

		}

	}

	// Which map - four possible variations (excluding which end the players start on, which is a separate thing)

   // Picks the map size
	if(cNumberTeams > 2)
		int playerTiles=12000;
	else if (rmGetNumberPlayersOnTeam(0) == rmGetNumberPlayersOnTeam(1))
		playerTiles=11000;
	else
		playerTiles=12000;	
			
	int size=2.1*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);
	
	// Picks a default water height
	rmSetSeaLevel(3.0);	// this is height of river surface compared to surrounding land. River depth is in the river XML.

	// Picks default terrain and water
	rmSetBaseTerrainMix("khorezm");
	rmTerrainInitialize("wotta\dirty\ground4_dirty", 4);
	rmSetMapType("centralasia");
	rmSetMapType("grass");
	rmSetMapType("land");
	rmSetLightingSet("deccan");

	// Make the corners.
	rmSetWorldCircleConstraint(true);

	// Choose Mercs
	chooseMercs();
wotta_triggers();

   // Define some classes. These are used later for constraints.
   int classPlayer=rmDefineClass("player");
   rmDefineClass("classHill");
   rmDefineClass("classPatch");
   rmDefineClass("starting settlement");
   rmDefineClass("startingUnit");
   rmDefineClass("classForest");
   rmDefineClass("importantItem");
   rmDefineClass("natives");
	rmDefineClass("classCliff");
	rmDefineClass("classMountain");

   // -------------Define constraints
   // These are used to have objects and areas avoid each other
   
   // Map edge constraints
   //int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(6), rmZTilesToFraction(6), 1.0-rmXTilesToFraction(6), 1.0-rmZTilesToFraction(6), 0.01);
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int coinEdgeConstraint=rmCreateBoxConstraint("coin edge of map", rmXTilesToFraction(19), rmZTilesToFraction(19), 1.0-rmXTilesToFraction(19), 1.0-rmZTilesToFraction(19), 2.0);
	int coinEdgeWestConstraint=rmCreateBoxConstraint("coin edge of mapwest", rmXTilesToFraction(19), rmZTilesToFraction(19), 1.0-rmXTilesToFraction(19), 1.0-rmZTilesToFraction(19), 2.0);

   // Cardinal Directions

	int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(90), rmDegreesToRadians(270));
	int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(270), rmDegreesToRadians(90));

   
	// Player constraints
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 20.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("stay far away from players", classPlayer, 50.0);
 
   // Nature avoidance
	int avoidForest=rmCreateClassDistanceConstraint("forest avoids forest", rmClassID("classForest"), 20.0);
	int avoidForestFar=rmCreateClassDistanceConstraint("forest avoids forest far", rmClassID("classForest"), 30.0);
	int avoidCapybara=rmCreateTypeDistanceConstraint("avoids Capybara", "capybara", 45.0);
	int avoidTapir=rmCreateTypeDistanceConstraint("Tapir avoids Tapir", "Tapir", 45.0);
	int avoidTapirFar=rmCreateTypeDistanceConstraint("Tapir avoids Tapir Far", "Tapir", 65.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "gold", 35.0);
	int avoidCoinFar=rmCreateTypeDistanceConstraint("avoid coin far", "gold", 60.0);
   
   // Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 10.0);
	int avoidRiver = rmCreateTerrainDistanceConstraint("avoid river", "Land", false, 5.0);
	int avoidRiverFar = rmCreateTerrainDistanceConstraint("avoid river far", "Land", false, 35.0);
	int avoidCliff=rmCreateClassDistanceConstraint("stuff vs. cliff", rmClassID("classCliff"), 12.0);
	int cliffAvoidCliff=rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 30.0);
	int mediumShortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("mediumshort avoid impassable land", "Land", false, 10.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int mediumAvoidImpassableLand=rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 12.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 20.0);

   // Unit avoidance
	int avoidHuari=rmCreateTypeDistanceConstraint("avoid Huari", "huariStronghold", 20.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 20.0);
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
	int avoidTownCenterSupaFar=rmCreateTypeDistanceConstraint("avoid Town Center Supa Far", "townCenter", 50.0);
	int avoidTownCenterFFAFar=rmCreateTypeDistanceConstraint("avoid Town Center FFA Far", "townCenter", 80.0);
   int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 60.0);
   int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other by a bit", rmClassID("importantItem"), 10.0);
   int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 10.0);
   int avoidNativesFar=rmCreateClassDistanceConstraint("stuff avoids natives far", rmClassID("natives"), 45.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 65.0);
	
   // Decoration avoidance
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 8.0);


   // -------------Define objects
   // These objects are all defined so they can be placed later

	rmSetStatusText("",0.10);

	int topOrBottom = rmRandInt(1, 5);

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	
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

	if(cNumberTeams > 2) //ffa
	{
		rmSetPlacementSection(0.0, 1.0);
		rmSetTeamSpacingModifier(0.80);
		rmPlacePlayersCircular(0.44, 0.44, 0);
	}
	else
	{
			// *** Start on the Top
			rmSetPlacementTeam(teamOne);	
			rmPlacePlayersLine(0.1, 0.3, 0.1, 0.7, 0.0, 0.3);

			rmSetPlacementTeam(teamTwo);
			rmPlacePlayersLine(0.9, 0.3, 0.9, 0.7, 0.0, 0.3);
	}

   // Build a north area
	int eastIslandID = rmCreateArea("east island");
	//rmSetAreaLocation(eastIslandID, 0.75, 0.50);
	rmSetAreaLocation(eastIslandID, 0.15, 0.85); 
	rmSetAreaWarnFailure(eastIslandID, false);
	rmSetAreaSize(eastIslandID, 0.45, 0.45);
	rmSetAreaCoherence(eastIslandID, 1.0);

	rmSetAreaElevationType(eastIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(eastIslandID, 4.0);
	rmSetAreaBaseHeight(eastIslandID, 4.0);
	rmSetAreaElevationMinFrequency(eastIslandID, 0.07);
	rmSetAreaElevationOctaves(eastIslandID, 4);
	rmSetAreaElevationPersistence(eastIslandID, 0.5);
	rmSetAreaElevationNoiseBias(eastIslandID, 1);
   
	rmSetAreaObeyWorldCircleConstraint(eastIslandID, false);
	rmSetAreaMix(eastIslandID, "khorezm");


   // Text
   rmSetStatusText("",0.20);

   // Build a south area
	int westIslandID = rmCreateArea("west island");
	//rmSetAreaLocation(westIslandID, 0, 0.5);
	rmSetAreaLocation(westIslandID, 0.75, 0.25);
	rmSetAreaWarnFailure(westIslandID, false);
	rmSetAreaSize(westIslandID, 0.45, 0.45);
	rmSetAreaCoherence(westIslandID, 1.0);

	rmSetAreaElevationType(westIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(westIslandID, 4.0);
	rmSetAreaBaseHeight(westIslandID, 4.0);
	rmSetAreaElevationMinFrequency(westIslandID, 0.07);
	rmSetAreaElevationOctaves(westIslandID, 4);
	rmSetAreaElevationPersistence(westIslandID, 0.5);
	rmSetAreaElevationNoiseBias(westIslandID, 1); 
   
	rmSetAreaObeyWorldCircleConstraint(westIslandID, false);
	rmSetAreaMix(westIslandID, "khorezm");

   rmBuildAllAreas();

   // Text
   rmSetStatusText("",0.30);

	// Middle River
	int riverID = rmRiverCreate(-1, "Mesopotamian Marshes", 5, 15, 6+sqrt(cNumberNonGaiaPlayers), 7+sqrt(cNumberNonGaiaPlayers));
	if(topOrBottom == 1)
	{	
	rmRiverAddWaypoint(riverID, 0.25, 1.00);
	rmRiverAddWaypoint(riverID, 0.30, 0.80);
	rmRiverAddWaypoint(riverID, 0.45, 0.85);
	rmRiverAddWaypoint(riverID, 0.50, 0.70);
	rmRiverAddWaypoint(riverID, 0.40, 0.60);
	rmRiverAddWaypoint(riverID, 0.25, 0.60);
	rmRiverAddWaypoint(riverID, 0.20, 0.50);
	rmRiverAddWaypoint(riverID, 0.25, 0.35);
	rmRiverAddWaypoint(riverID, 0.40, 0.20);
	rmRiverAddWaypoint(riverID, 0.40, 0.10);
	rmRiverAddWaypoint(riverID, 0.25, 0.00);
}	
	else if(topOrBottom == 2)
	{	
	rmRiverAddWaypoint(riverID, 0.25, 1.00);
	rmRiverAddWaypoint(riverID, 0.30, 0.80);
	rmRiverAddWaypoint(riverID, 0.25, 0.60);
	rmRiverAddWaypoint(riverID, 0.40, 0.50);
	rmRiverAddWaypoint(riverID, 0.20, 0.30);
	rmRiverAddWaypoint(riverID, 0.30, 0.10);
	rmRiverAddWaypoint(riverID, 0.40, 0.15);
	rmRiverAddWaypoint(riverID, 0.40, 0.30);
	rmRiverAddWaypoint(riverID, 0.55, 0.30);
	rmRiverAddWaypoint(riverID, 0.60, 0.10);
	rmRiverAddWaypoint(riverID, 0.50, 0.00);
}	
	else if(topOrBottom == 3)
	{	
	rmRiverAddWaypoint(riverID, 0.35, 1.00);
	rmRiverAddWaypoint(riverID, 0.30, 0.90);
	rmRiverAddWaypoint(riverID, 0.25, 0.75);
	rmRiverAddWaypoint(riverID, 0.35, 0.65);
	rmRiverAddWaypoint(riverID, 0.40, 0.50);
	rmRiverAddWaypoint(riverID, 0.30, 0.45);
	rmRiverAddWaypoint(riverID, 0.30, 0.30);
	rmRiverAddWaypoint(riverID, 0.45, 0.35);
	rmRiverAddWaypoint(riverID, 0.50, 0.20);
	rmRiverAddWaypoint(riverID, 0.45, 0.10);
	rmRiverAddWaypoint(riverID, 0.30, 0.00);
}	
	else if(topOrBottom == 4)
	{	
	rmRiverAddWaypoint(riverID, 0.50, 1.00);
	rmRiverAddWaypoint(riverID, 0.50, 0.75);
	rmRiverAddWaypoint(riverID, 0.45, 0.65);
	rmRiverAddWaypoint(riverID, 0.30, 0.70);
	rmRiverAddWaypoint(riverID, 0.30, 0.60);
	rmRiverAddWaypoint(riverID, 0.40, 0.50);
	rmRiverAddWaypoint(riverID, 0.20, 0.50);
	rmRiverAddWaypoint(riverID, 0.30, 0.30);
	rmRiverAddWaypoint(riverID, 0.45, 0.40);
	rmRiverAddWaypoint(riverID, 0.55, 0.35);
}	
	else
	{	
	rmRiverAddWaypoint(riverID, 0.50, 1.00);
	rmRiverAddWaypoint(riverID, 0.50, 0.80);
	rmRiverAddWaypoint(riverID, 0.60, 0.70);
	rmRiverAddWaypoint(riverID, 0.70, 0.70);
	rmRiverAddWaypoint(riverID, 0.70, 0.50);
	rmRiverAddWaypoint(riverID, 0.60, 0.40);
	rmRiverAddWaypoint(riverID, 0.70, 0.30);
	rmRiverAddWaypoint(riverID, 0.50, 0.20);
}
	rmRiverSetBankNoiseParams(riverID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	rmRiverBuild(riverID);

	int river2ID = rmRiverCreate(-1, "Mesopotamian Marshes", 5, 15, 6+sqrt(cNumberNonGaiaPlayers), 7+sqrt(cNumberNonGaiaPlayers));
	if(topOrBottom == 1)
{
	rmRiverAddWaypoint(river2ID, 0.75, 0.00);
	rmRiverAddWaypoint(river2ID, 0.70, 0.20);
	rmRiverAddWaypoint(river2ID, 0.55, 0.15);
	rmRiverAddWaypoint(river2ID, 0.50, 0.30);
	rmRiverAddWaypoint(river2ID, 0.60, 0.40);
	rmRiverAddWaypoint(river2ID, 0.75, 0.40);
	rmRiverAddWaypoint(river2ID, 0.80, 0.50);
	rmRiverAddWaypoint(river2ID, 0.75, 0.65);
	rmRiverAddWaypoint(river2ID, 0.60, 0.80);
	rmRiverAddWaypoint(river2ID, 0.60, 0.90);
	rmRiverAddWaypoint(river2ID, 0.75, 1.00);
}
	else if(topOrBottom == 2)
{
	rmRiverAddWaypoint(river2ID, 0.75, 0.00);
	rmRiverAddWaypoint(river2ID, 0.70, 0.20);
	rmRiverAddWaypoint(river2ID, 0.75, 0.40);
	rmRiverAddWaypoint(river2ID, 0.60, 0.50);
	rmRiverAddWaypoint(river2ID, 0.80, 0.70);
	rmRiverAddWaypoint(river2ID, 0.70, 0.90);
	rmRiverAddWaypoint(river2ID, 0.60, 0.85);
	rmRiverAddWaypoint(river2ID, 0.60, 0.70);
	rmRiverAddWaypoint(river2ID, 0.45, 0.70);
	rmRiverAddWaypoint(river2ID, 0.40, 0.90);
	rmRiverAddWaypoint(river2ID, 0.50, 1.00);
}
	else if(topOrBottom == 3)
{
	rmRiverAddWaypoint(river2ID, 0.65, 0.00);
	rmRiverAddWaypoint(river2ID, 0.70, 0.10);
	rmRiverAddWaypoint(river2ID, 0.75, 0.25);
	rmRiverAddWaypoint(river2ID, 0.65, 0.35);
	rmRiverAddWaypoint(river2ID, 0.60, 0.50);
	rmRiverAddWaypoint(river2ID, 0.70, 0.55);
	rmRiverAddWaypoint(river2ID, 0.70, 0.70);
	rmRiverAddWaypoint(river2ID, 0.55, 0.65);
	rmRiverAddWaypoint(river2ID, 0.50, 0.80);
	rmRiverAddWaypoint(river2ID, 0.55, 0.90);
	rmRiverAddWaypoint(river2ID, 0.70, 1.00);
}
	else if(topOrBottom == 4)
{
	rmRiverAddWaypoint(river2ID, 0.50, 0.00);
	rmRiverAddWaypoint(river2ID, 0.50, 0.25);
	rmRiverAddWaypoint(river2ID, 0.55, 0.35);
	rmRiverAddWaypoint(river2ID, 0.70, 0.30);
	rmRiverAddWaypoint(river2ID, 0.70, 0.40);
	rmRiverAddWaypoint(river2ID, 0.60, 0.50);
	rmRiverAddWaypoint(river2ID, 0.80, 0.50);
	rmRiverAddWaypoint(river2ID, 0.70, 0.70);
	rmRiverAddWaypoint(river2ID, 0.55, 0.60);
	rmRiverAddWaypoint(river2ID, 0.45, 0.65);
}
	else
{
	rmRiverAddWaypoint(river2ID, 0.50, 0.00);
	rmRiverAddWaypoint(river2ID, 0.50, 0.20);
	rmRiverAddWaypoint(river2ID, 0.40, 0.30);
	rmRiverAddWaypoint(river2ID, 0.30, 0.30);
	rmRiverAddWaypoint(river2ID, 0.30, 0.50);
	rmRiverAddWaypoint(river2ID, 0.40, 0.60);
	rmRiverAddWaypoint(river2ID, 0.80, 0.70);
	rmRiverAddWaypoint(river2ID, 0.50, 0.80);
}
	rmRiverSetBankNoiseParams(river2ID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	rmRiverBuild(river2ID);

	// Set up player areas.
   float playerFraction=rmAreaTilesToFraction(600);
   for(i=1; <cNumberPlayers)
   {
      // Create the area.
   int id=rmCreateArea("Player"+i);
    rmSetPlayerArea(i, id);
    rmSetAreaSize(id, playerFraction, playerFraction);
//    rmAddAreaToClass(id, classIsland);
    rmSetAreaLocPlayer(id, i);
    rmSetAreaWarnFailure(id, false);
	  rmSetAreaCoherence(id, 0.5);
	  	if(cNumberTeams > 2)
    {
		rmSetAreaBaseHeight(id, 2.0);
	}
		else
		{
			}
    rmSetAreaSmoothDistance(id, 20);
    rmSetAreaMix(id, "khorezm");
//    rmAddAreaToClass(id, classIsland);
//    rmAddAreaConstraint(id, islandConstraint);
//    rmAddAreaConstraint(id, islandEdgeConstraint);
    rmSetAreaElevationType(id, cElevTurbulence);
    rmSetAreaElevationVariation(id, 4.0);
    rmSetAreaElevationMinFrequency(id, 0.09);
    rmSetAreaElevationOctaves(id, 3);
    rmSetAreaElevationPersistence(id, 0.2);
    rmSetAreaElevationNoiseBias(id, 1);	  
   }

	// Build the areas.
	rmBuildAllAreas();
   
	// Text
	rmSetStatusText("",0.40);


	//Top Left Village
	int topleftVillageID = -1;
	if (subCiv0 == rmGetCivID("zen"))
	{  
		topleftVillageID = rmCreateGrouping("Emboaba village Top Left", "native zen temple cj 0"+rmRandInt(1,3));
	}
	else if (subCiv0 == rmGetCivID("shaolin"))
	{  
		topleftVillageID = rmCreateGrouping("Carib village Top Left", "native shaolin temple yr 0"+rmRandInt(1,3));
	}
	else if (subCiv0 == rmGetCivID("zen"))
	{  
		topleftVillageID = rmCreateGrouping("Quilombola village Top Left", "native zen temple cj 0"+rmRandInt(1,3));
	}
	else
	{  
		topleftVillageID = rmCreateGrouping("Bandeirante village Top Left", "native shaolin temple yr 0"+rmRandInt(1,3));
	}
	rmSetGroupingMinDistance(topleftVillageID, 0.0);
	rmSetGroupingMaxDistance(topleftVillageID, 0.20);
	rmAddGroupingToClass(topleftVillageID, rmClassID("natives"));
	rmAddGroupingToClass(topleftVillageID, rmClassID("importantItem"));
		 if(topOrBottom == 1)
	rmPlaceGroupingAtLoc(topleftVillageID, 0, 0.85, 0.75);
	else if(topOrBottom == 2)
	rmPlaceGroupingAtLoc(topleftVillageID, 0, 0.4, 0.6);
	else if(topOrBottom == 3)
	rmPlaceGroupingAtLoc(topleftVillageID, 0, 0.2, 0.5);
	else if(topOrBottom == 4)
	rmPlaceGroupingAtLoc(topleftVillageID, 0, 0.65, 0.2);
	else
	rmPlaceGroupingAtLoc(topleftVillageID, 0, 0.6, 0.2);

	//Top Left Village
	int bottomleftVillageID = -1;
	if (subCiv1 == rmGetCivID("zen"))
	{  
		bottomleftVillageID = rmCreateGrouping("Emboaba village Bottom Left", "native zen temple cj 0"+rmRandInt(1,3));
	}
	else if (subCiv1 == rmGetCivID("shaolin"))
	{  
		bottomleftVillageID = rmCreateGrouping("Carib village Bottom Left", "native shaolin temple yr 0"+rmRandInt(1,3));
	}
	else if (subCiv1 == rmGetCivID("zen"))
	{  
		bottomleftVillageID = rmCreateGrouping("Quilombola village Bottom Left", "native zen temple cj 0"+rmRandInt(1,3));
	}
	else
	{  
		bottomleftVillageID = rmCreateGrouping("Bandeirante village Bottom Left", "native shaolin temple yr 0"+rmRandInt(1,3));
	}
	rmSetGroupingMinDistance(bottomleftVillageID, 0.0);
	rmSetGroupingMaxDistance(bottomleftVillageID, 0.20);
	rmAddGroupingToClass(bottomleftVillageID, rmClassID("natives"));
	rmAddGroupingToClass(bottomleftVillageID, rmClassID("importantItem"));
		 if(topOrBottom == 1)
	rmPlaceGroupingAtLoc(bottomleftVillageID, 0, 0.45, 0.35);
	else if(topOrBottom == 2)
	rmPlaceGroupingAtLoc(bottomleftVillageID, 0, 0.5, 0.2);
	else if(topOrBottom == 3)
	rmPlaceGroupingAtLoc(bottomleftVillageID, 0, 0.85, 0.7);
	else if(topOrBottom == 4)
	rmPlaceGroupingAtLoc(bottomleftVillageID, 0, 0.8, 0.75);
	else
	rmPlaceGroupingAtLoc(bottomleftVillageID, 0, 0.8, 0.75);

	//Top Right Village
	int topRightVillageID = -1;
	if (subCiv2 == rmGetCivID("zen"))
	{  
		topRightVillageID = rmCreateGrouping("Emboaba village Top Right", "native zen temple cj 0"+rmRandInt(1,3));
	}
	else if (subCiv2 == rmGetCivID("shaolin"))
	{  
		topRightVillageID = rmCreateGrouping("Carib village Top Right", "native shaolin temple yr 0"+rmRandInt(1,3));
	}
	else if (subCiv2 == rmGetCivID("zen"))
	{  
		topRightVillageID = rmCreateGrouping("Quilombola village Top Right", "native zen temple cj 0"+rmRandInt(1,3));
	}
	else
	{  
		topRightVillageID = rmCreateGrouping("Bandeirante village Top Right", "native shaolin temple yr 0"+rmRandInt(1,3));
	}
	rmSetGroupingMinDistance(topRightVillageID, 0.0);
	rmSetGroupingMaxDistance(topRightVillageID, 0.20);
	rmAddGroupingToClass(topRightVillageID, rmClassID("natives"));
	rmAddGroupingToClass(topRightVillageID, rmClassID("importantItem"));
		 if(topOrBottom == 1)
	rmPlaceGroupingAtLoc(topRightVillageID, 0, 0.55, 0.65);
	else if(topOrBottom == 2)
	rmPlaceGroupingAtLoc(topRightVillageID, 0, 0.5, 0.8);
	else if(topOrBottom == 3)
	rmPlaceGroupingAtLoc(topRightVillageID, 0, 0.15, 0.3);
	else if(topOrBottom == 4)
	rmPlaceGroupingAtLoc(topRightVillageID, 0, 0.2, 0.35);
	else
	rmPlaceGroupingAtLoc(topRightVillageID, 0, 0.2, 0.35);


	//Bottom Right Village
	int bottomRightVillageID = -1;
	if (subCiv3 == rmGetCivID("zen"))
	{  
		bottomRightVillageID = rmCreateGrouping("Emboaba village Bottom Right", "native zen temple cj 0"+rmRandInt(1,3));
	}
	else if (subCiv3 == rmGetCivID("shaolin"))
	{  
		bottomRightVillageID = rmCreateGrouping("Carib village Bottom Right", "native shaolin temple yr 0"+rmRandInt(1,3));
	}
	else if (subCiv3 == rmGetCivID("zen"))
	{  
		bottomRightVillageID = rmCreateGrouping("Quilombola village Bottom Right", "native zen temple cj 0"+rmRandInt(1,3));
	}
	else
	{  
		bottomRightVillageID = rmCreateGrouping("Bandeirante village Bottom Right", "native shaolin temple yr 0"+rmRandInt(1,3));
	}
	rmSetGroupingMinDistance(bottomRightVillageID, 0.0);
	rmSetGroupingMaxDistance(bottomRightVillageID, 0.20);
	rmAddGroupingToClass(bottomRightVillageID, rmClassID("natives"));
	rmAddGroupingToClass(bottomRightVillageID, rmClassID("importantItem"));
		 if(topOrBottom == 1)
	rmPlaceGroupingAtLoc(bottomRightVillageID, 0, 0.15, 0.25);
	else if(topOrBottom == 2)
	rmPlaceGroupingAtLoc(bottomRightVillageID, 0, 0.6, 0.4);
	else if(topOrBottom == 3)
	rmPlaceGroupingAtLoc(bottomRightVillageID, 0, 0.8, 0.4);
	else if(topOrBottom == 4)
	rmPlaceGroupingAtLoc(bottomRightVillageID, 0, 0.35, 0.8);
	else
	rmPlaceGroupingAtLoc(bottomRightVillageID, 0, 0.4, 0.8);


	// Text
	rmSetStatusText("",0.50);


	int failCount = -1;
	int numTries=cNumberNonGaiaPlayers+2;


	// PLAYER STARTING RESOURCES

	rmClearClosestPointConstraints();
	int TCfloat = -1;
	if (cNumberTeams == 2)
	{
		if (cNumberNonGaiaPlayers > 2)
			TCfloat = 10;
		else if (cNumberNonGaiaPlayers > 5)
			TCfloat = 12;
		else 
			TCfloat = 5;
	}
	else 
		TCfloat = 5;
    

	int TCID = rmCreateObjectDef("player TC");
	if (rmGetNomadStart())
		{
		rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
		}
	else
		{
		rmAddObjectDefItem(TCID, "TownCenter", 1, 0.0);
		}

	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, TCfloat);

	if (cNumberTeams == 2)
		if (rmGetNumberPlayersOnTeam(0) == rmGetNumberPlayersOnTeam(1))
			rmAddObjectDefConstraint(TCID, avoidTownCenterSupaFar);
		else
			rmAddObjectDefConstraint(TCID, avoidTownCenterFar);
	else
		rmAddObjectDefConstraint(TCID, avoidTownCenterFFAFar);
	rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
//	rmAddObjectDefConstraint(TCID, avoidRiverFar);
	rmAddObjectDefConstraint(TCID, avoidAll);
	//rmAddGroupingConstraint(TCID, avoidNativesFar);
	rmAddObjectDefConstraint(TCID, mediumShortAvoidImpassableLand);

	int playerSilverID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerSilverID, "mine", 1, 0);
	rmAddObjectDefConstraint(playerSilverID, avoidTownCenter);
	rmSetObjectDefMinDistance(playerSilverID, 15.0);
	rmSetObjectDefMaxDistance(playerSilverID, 20.0);
    rmAddObjectDefConstraint(playerSilverID, avoidImpassableLand);

	int playerCapybaraID=rmCreateObjectDef("player Capybara");
    rmAddObjectDefItem(playerCapybaraID, "ypMuskDeer", rmRandInt(8,10), 10.0);
    rmSetObjectDefMinDistance(playerCapybaraID, 10);
    rmSetObjectDefMaxDistance(playerCapybaraID, 18);
	rmAddObjectDefConstraint(playerCapybaraID, avoidAll);
    rmAddObjectDefConstraint(playerCapybaraID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerCapybaraID, avoidCliff);
    rmSetObjectDefCreateHerd(playerCapybaraID, true);

	int playerNuggetID= rmCreateObjectDef("player nugget"); 
	rmAddObjectDefItem(playerNuggetID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);
  	rmAddObjectDefConstraint(playerNuggetID, avoidNugget);
  	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
	rmAddObjectDefConstraint(playerNuggetID, avoidCliff);
	rmAddObjectDefConstraint(playerNuggetID, playerEdgeConstraint);
	rmSetObjectDefMinDistance(playerNuggetID, 20.0);
	rmSetObjectDefMaxDistance(playerNuggetID, 30.0);

	int playerTreeID=rmCreateObjectDef("player trees");
    rmAddObjectDefItem(playerTreeID, "TreeGreatPlains", rmRandInt(5,10), 8.0);
    rmSetObjectDefMinDistance(playerTreeID, 15);
    rmSetObjectDefMaxDistance(playerTreeID, 20);
	rmAddObjectDefConstraint(playerTreeID, avoidAll);
    rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);

	for(i=1; <cNumberPlayers)
   {
	rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
	rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerCapybaraID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

   rmClearClosestPointConstraints();
   }

	// Text
	rmSetStatusText("",0.60);


	// Define and place Nuggets

	int nuggeteasyID= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nuggeteasyID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmSetObjectDefMinDistance(nuggeteasyID, 0.0);
	rmSetObjectDefMaxDistance(nuggeteasyID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggeteasyID, avoidNugget);
  	rmAddObjectDefConstraint(nuggeteasyID, avoidTownCenter);
	rmAddObjectDefConstraint(nuggeteasyID, avoidCliff);
  	rmAddObjectDefConstraint(nuggeteasyID, avoidAll);
  	rmAddObjectDefConstraint(nuggeteasyID, avoidImpassableLand);
	rmAddObjectDefConstraint(nuggeteasyID, playerEdgeConstraint);
	rmPlaceObjectDefAtLoc(nuggeteasyID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);

	int nuggetmediumEastID= rmCreateObjectDef("nugget medium east"); 
	rmAddObjectDefItem(nuggetmediumEastID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(2, 2);
	rmSetObjectDefMinDistance(nuggetmediumEastID, 0.0);
	rmSetObjectDefMaxDistance(nuggetmediumEastID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggetmediumEastID, avoidNugget);
  	rmAddObjectDefConstraint(nuggetmediumEastID, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetmediumEastID, avoidCliff);
  	rmAddObjectDefConstraint(nuggetmediumEastID, avoidAll);
  	rmAddObjectDefConstraint(nuggetmediumEastID, avoidImpassableLand);
	rmAddObjectDefConstraint(nuggetmediumEastID, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetmediumEastID, Eastward);
	rmPlaceObjectDefAtLoc(nuggetmediumEastID, 0, 0.5, 0.5, 2);

	int nuggetmediumWestID= rmCreateObjectDef("nugget medium west"); 
	rmAddObjectDefItem(nuggetmediumWestID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(2, 2);
	rmSetObjectDefMinDistance(nuggetmediumWestID, 0.0);
	rmSetObjectDefMaxDistance(nuggetmediumWestID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggetmediumWestID, avoidNugget);
  	rmAddObjectDefConstraint(nuggetmediumWestID, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetmediumWestID, avoidCliff);
  	rmAddObjectDefConstraint(nuggetmediumWestID, avoidAll);
  	rmAddObjectDefConstraint(nuggetmediumWestID, avoidImpassableLand);
	rmAddObjectDefConstraint(nuggetmediumWestID, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetmediumWestID, Westward);
	rmPlaceObjectDefAtLoc(nuggetmediumWestID, 0, 0.5, 0.5, 2);

	int nuggethardID= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nuggethardID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 3);
	rmSetObjectDefMinDistance(nuggethardID, 0.0);
	rmSetObjectDefMaxDistance(nuggethardID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggethardID, avoidNugget);
  	rmAddObjectDefConstraint(nuggethardID, avoidTownCenter);
	rmAddObjectDefConstraint(nuggethardID, avoidCliff);
  	rmAddObjectDefConstraint(nuggethardID, avoidAll);
	rmAddObjectDefConstraint(nuggethardID, playerEdgeConstraint);
  	rmAddObjectDefConstraint(nuggethardID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(nuggethardID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);

	if(rmRandFloat(0,1) < 0.50) //only places more hard nuggets 50% of the time
		{
		int nuggethard2ID= rmCreateObjectDef("nugget hard2"); 
		rmAddObjectDefItem(nuggethard2ID, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(3, 3);
		rmSetObjectDefMinDistance(nuggethard2ID, 0.0);
		rmSetObjectDefMaxDistance(nuggethard2ID, rmXFractionToMeters(0.5));
  		rmAddObjectDefConstraint(nuggethard2ID, avoidNugget);
  		rmAddObjectDefConstraint(nuggethard2ID, avoidTownCenter);
		rmAddObjectDefConstraint(nuggethard2ID, avoidCliff);
  		rmAddObjectDefConstraint(nuggethard2ID, avoidAll);
  		rmAddObjectDefConstraint(nuggethard2ID, avoidImpassableLand);
		rmPlaceObjectDefAtLoc(nuggethard2ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);
		}
	else if (rmRandFloat(0,1) < 0.25)  //only try to place nuts 25% of the time
		{
		int nuggetnutsID= rmCreateObjectDef("nugget nuts"); 
		rmAddObjectDefItem(nuggetnutsID, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(4, 4);
		rmSetObjectDefMinDistance(nuggetnutsID, 0.0);
		rmSetObjectDefMaxDistance(nuggetnutsID, rmXFractionToMeters(0.5));
  		rmAddObjectDefConstraint(nuggetnutsID, avoidNugget);
  		rmAddObjectDefConstraint(nuggetnutsID, avoidTownCenter);
		rmAddObjectDefConstraint(nuggetnutsID, avoidCliff);
  		rmAddObjectDefConstraint(nuggetnutsID, avoidAll);
  		rmAddObjectDefConstraint(nuggetnutsID, avoidImpassableLand);
		rmPlaceObjectDefAtLoc(nuggetnutsID, 0, 0.5, 0.5, 2);
		}



	// Silver mines

	rmSetStatusText("",0.70);
 
	int silverType = -1;
	int silverCount = (cNumberNonGaiaPlayers*1.5 + rmRandInt(1,2));
	if (cNumberNonGaiaPlayers > 5)
		silverCount = silverCount - 5;
	rmEchoInfo("silver count = "+silverCount);

	for(i=0; < silverCount)
	{
	  int silverID = rmCreateObjectDef("silverEast "+i);
	  rmAddObjectDefItem(silverID, "mine", 1, 0.0);
      rmSetObjectDefMinDistance(silverID, 0.0);
      rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(silverID, avoidCoin);
      rmAddObjectDefConstraint(silverID, avoidAll);
      rmAddObjectDefConstraint(silverID, avoidTownCenterFar);
	  rmAddObjectDefConstraint(silverID, avoidNatives);
      rmAddObjectDefConstraint(silverID, avoidImpassableLand);
	  rmAddObjectDefConstraint(silverID, coinEdgeConstraint);
	  rmAddObjectDefConstraint(silverID, Eastward);
	  //rmAddObjectDefConstraint(silverID, eastIslandID);
	  rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
   }


	for(i=0; < silverCount)
	{
	  int silverWestID = rmCreateObjectDef("silverWest "+i);
	  rmAddObjectDefItem(silverWestID, "mine", 1, 0.0);
      rmSetObjectDefMinDistance(silverWestID, 0.0);
      rmSetObjectDefMaxDistance(silverWestID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(silverWestID, avoidCoin);
      rmAddObjectDefConstraint(silverWestID, avoidAll);
      rmAddObjectDefConstraint(silverWestID, avoidTownCenterFar);
	  rmAddObjectDefConstraint(silverWestID, avoidNatives);
      rmAddObjectDefConstraint(silverWestID, avoidImpassableLand);
	  rmAddObjectDefConstraint(silverWestID, Westward);
	  //rmAddObjectDefConstraint(silverWestID, westIslandID);
	  rmAddObjectDefConstraint(silverWestID, coinEdgeConstraint);
	  rmPlaceObjectDefAtLoc(silverWestID, 0, 0.5, 0.5);
   }


	//Mines to fill in the large gaps

	silverCount = 2;
	for(i=0; < silverCount)
	{
	int silverEastRandomID = rmCreateObjectDef("silverEastRandom "+i);
	rmAddObjectDefItem(silverEastRandomID, "mine", 1, 0.0);
	rmSetObjectDefMinDistance(silverEastRandomID, 0.0);
	rmSetObjectDefMaxDistance(silverEastRandomID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(silverEastRandomID, avoidCoinFar);
	rmAddObjectDefConstraint(silverEastRandomID, avoidAll);
	rmAddObjectDefConstraint(silverEastRandomID, avoidNativesFar);
	rmAddObjectDefConstraint(silverEastRandomID, longAvoidImpassableLand);
	rmAddObjectDefConstraint(silverEastRandomID, coinEdgeConstraint);
	rmAddObjectDefConstraint(silverEastRandomID, Eastward);
	rmPlaceObjectDefAtLoc(silverEastRandomID, 0, 0.25, 0.5);
	}

	silverCount = 2;
	for(i=0; < silverCount)
	{
	  int silverWestRandomID = rmCreateObjectDef("silverWestRandom "+i);
	  rmAddObjectDefItem(silverWestRandomID, "mine", 1, 0.0);
      rmSetObjectDefMinDistance(silverWestRandomID, 0.0);
      rmSetObjectDefMaxDistance(silverWestRandomID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(silverWestRandomID, avoidCoinFar);
      rmAddObjectDefConstraint(silverWestRandomID, avoidAll);
	  rmAddObjectDefConstraint(silverWestRandomID, avoidNativesFar);
      rmAddObjectDefConstraint(silverWestRandomID, longAvoidImpassableLand);
	  rmAddObjectDefConstraint(silverWestRandomID, coinEdgeConstraint);
	  rmAddObjectDefConstraint(silverWestRandomID, Westward);
	  rmPlaceObjectDefAtLoc(silverWestRandomID, 0, 0.75, 0.5);
   }



	rmSetStatusText("",0.80);

	// Forest areas

	if (cNumberNonGaiaPlayers > 4)
		numTries=3*cNumberNonGaiaPlayers;
	else
		numTries=4*cNumberNonGaiaPlayers;
	failCount=0;
	for (i=0; <numTries)
		{   
			int forestID=rmCreateArea("forestID"+i, westIslandID);
			rmSetAreaWarnFailure(forestID, false);
			rmSetAreaSize(forestID, rmAreaTilesToFraction(160), rmAreaTilesToFraction(200));
			rmSetAreaForestType(forestID, "tugay forest");
			rmSetAreaForestDensity(forestID, 0.6);
			rmSetAreaForestClumpiness(forestID, 0.4);		
			rmSetAreaForestUnderbrush(forestID, 0.6);
			rmSetAreaMinBlobs(forestID, 4);
			rmSetAreaMaxBlobs(forestID, 10);						
			rmSetAreaMinBlobDistance(forestID, 5.0);
			rmSetAreaMaxBlobDistance(forestID, 20.0);
			rmSetAreaCoherence(forestID, 0.4);
			rmSetAreaSmoothDistance(forestID, 10);
			rmAddAreaToClass(forestID, rmClassID("classForest"));
			rmAddAreaConstraint(forestID, avoidForest);  
			rmAddAreaConstraint(forestID, shortAvoidImportantItem);
			rmAddAreaConstraint(forestID, avoidRiver);
			rmAddAreaConstraint(forestID, playerConstraint);
			rmAddAreaConstraint(forestID, avoidCliff);
			rmAddAreaConstraint(forestID, avoidAll);
			if(rmBuildArea(forestID)==false)
			{
				// Stop trying once we fail 5 times in a row.
				failCount++;
				if(failCount==10)
					break;
			}
			else
				failCount=0; 
		}

	if (cNumberNonGaiaPlayers > 4)
		numTries=3*cNumberNonGaiaPlayers;
	else
		numTries=4*cNumberNonGaiaPlayers; 
	failCount=0;
	for (i=0; <numTries)
		{   
			int forestEastID=rmCreateArea("forestEastID"+i, eastIslandID);
			rmSetAreaWarnFailure(forestEastID, false);
			rmSetAreaSize(forestEastID, rmAreaTilesToFraction(160), rmAreaTilesToFraction(200));
			rmSetAreaForestType(forestEastID, "tugay forest");
			rmSetAreaForestDensity(forestEastID, 0.6);
			rmSetAreaForestClumpiness(forestEastID, 0.4);		
			rmSetAreaForestUnderbrush(forestEastID, 0.6);
			rmSetAreaMinBlobs(forestEastID, 4);
			rmSetAreaMaxBlobs(forestEastID, 10);						
			rmSetAreaMinBlobDistance(forestEastID, 5.0);
			rmSetAreaMaxBlobDistance(forestEastID, 20.0);
			rmSetAreaCoherence(forestEastID, 0.4);
			rmSetAreaSmoothDistance(forestEastID, 10);
			rmAddAreaToClass(forestEastID, rmClassID("classForest"));
			rmAddAreaConstraint(forestEastID, avoidForest);  
			rmAddAreaConstraint(forestEastID, shortAvoidImportantItem);
			rmAddAreaConstraint(forestEastID, playerConstraint);
			rmAddAreaConstraint(forestEastID, avoidRiver);
			rmAddAreaConstraint(forestEastID, avoidCliff);
			rmAddAreaConstraint(forestEastID, avoidAll);
			if(rmBuildArea(forestEastID)==false)
			{
				// Stop trying once we fail 5 times in a row.
				failCount++;
				if(failCount==10)
					break;
			}
			else
				failCount=0; 
		}

	numTries=7*cNumberNonGaiaPlayers;  
	failCount=0;
	for (i=0; <numTries)
		{   
			int forestRandomID=rmCreateArea("forestRandomID"+i);
			rmSetAreaWarnFailure(forestRandomID, false);
			rmSetAreaSize(forestRandomID, rmAreaTilesToFraction(70), rmAreaTilesToFraction(120));
			rmSetAreaForestType(forestRandomID, "tugay forest");
			rmSetAreaForestDensity(forestRandomID, 0.6);
			rmSetAreaForestClumpiness(forestRandomID, 0.3);		
			rmSetAreaForestUnderbrush(forestRandomID, 0.4);
			rmSetAreaMinBlobs(forestRandomID, 2);
			rmSetAreaMaxBlobs(forestRandomID, 6);						
			rmSetAreaMinBlobDistance(forestRandomID, 5.0);
			rmSetAreaMaxBlobDistance(forestRandomID, 15.0);
			rmSetAreaCoherence(forestRandomID, 0.4);
			rmSetAreaSmoothDistance(forestRandomID, 10);
			rmAddAreaToClass(forestRandomID, rmClassID("classForest"));
			rmAddAreaConstraint(forestRandomID, avoidForestFar); 
			rmAddAreaConstraint(forestRandomID, shortAvoidImportantItem);
			rmAddAreaConstraint(forestRandomID, playerConstraint);
			rmAddAreaConstraint(forestRandomID, avoidRiver);
			rmAddAreaConstraint(forestRandomID, avoidCliff);
			rmAddAreaConstraint(forestRandomID, avoidAll);
			if(rmBuildArea(forestRandomID)==false)
			{
				// Stop trying once we fail 5 times in a row.
				failCount++;
				if(failCount==10)
					break;
			}
			else
				failCount=0; 
		}



	// Text
	

	// Resources that can be placed after forests


	// Text
	

	if (cNumberNonGaiaPlayers<7)
		{int tapirCount =1.5*cNumberNonGaiaPlayers;}
	else
		{tapirCount =0.80*cNumberNonGaiaPlayers;}

	rmEchoInfo("tapir count = "+tapirCount);
	
	for (i=0; <tapirCount)
		{
	int tapirEastID = rmCreateObjectDef("tapir east herd " +i);
	rmAddObjectDefItem(tapirEastID, "CrownedCrane", rmRandInt(10,13), 13);
	rmSetObjectDefMinDistance(tapirEastID, 0.0);
	rmSetObjectDefMaxDistance(tapirEastID, rmXFractionToMeters(0.8));
	rmAddObjectDefConstraint(tapirEastID, avoidTapir);
	rmAddObjectDefConstraint(tapirEastID, avoidCapybara);
	rmAddObjectDefConstraint(tapirEastID, avoidAll);
	rmAddObjectDefConstraint(tapirEastID, avoidNativesFar);
	rmAddObjectDefConstraint(tapirEastID, avoidRiver);
	rmAddObjectDefConstraint(tapirEastID, avoidCliff);
	rmAddObjectDefConstraint(tapirEastID, Eastward);
	rmSetObjectDefCreateHerd(tapirEastID, true);
	
	rmPlaceObjectDefAtLoc(tapirEastID, 0, 0.5, 0.5);
		}

	for (i=0; <tapirCount)
		{
	int tapirWestID = rmCreateObjectDef("tapir west herd " +i);
	rmAddObjectDefItem(tapirWestID, "CrownedCrane", rmRandInt(10,13), 13);
	rmSetObjectDefMinDistance(tapirWestID, 0.0);
	rmSetObjectDefMaxDistance(tapirWestID, rmXFractionToMeters(0.8));
	rmAddObjectDefConstraint(tapirWestID, avoidTapir);
	rmAddObjectDefConstraint(tapirWestID, avoidCapybara);
	rmAddObjectDefConstraint(tapirWestID, avoidAll);
	rmAddObjectDefConstraint(tapirWestID, avoidNativesFar);
	rmAddObjectDefConstraint(tapirWestID, avoidRiver);
	rmAddObjectDefConstraint(tapirWestID, Westward);
	rmSetObjectDefCreateHerd(tapirWestID, true);
	rmPlaceObjectDefAtLoc(tapirWestID, 0, 0.5, 0.5);
		}

	rmSetStatusText("",0.90);

	if (cNumberNonGaiaPlayers > 4)
	{
	tapirCount =4;
		for (i=0; <tapirCount)
		{
			int tapirRandomID = rmCreateObjectDef("tapir random herd " +i);
			rmAddObjectDefItem(tapirRandomID, "ypMuskDeer", rmRandInt(4,7), 11);
			rmSetObjectDefMinDistance(tapirRandomID, 0.0);
			rmSetObjectDefMaxDistance(tapirRandomID, rmXFractionToMeters(0.8));
			rmAddObjectDefConstraint(tapirRandomID, avoidTapirFar);
			rmAddObjectDefConstraint(tapirRandomID, avoidCapybara);
			rmAddObjectDefConstraint(tapirRandomID, avoidAll);
			rmAddObjectDefConstraint(tapirRandomID, avoidNativesFar);
			rmAddObjectDefConstraint(tapirRandomID, avoidRiver);
			rmSetObjectDefCreateHerd(tapirRandomID, true);
			rmPlaceObjectDefAtLoc(tapirRandomID, 0, 0.5, 0.5);
		}
	}

	// Text
	rmSetStatusText("",1.0);

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
