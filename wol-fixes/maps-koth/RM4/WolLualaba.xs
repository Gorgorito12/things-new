// Lualaba
// Started with modified Orinoco

include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";
// Main entry point for random map script
void main(void)
{
   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

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

    rmAllocateSubCivs(4);

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

   // Picks the map size
	if(cNumberTeams > 2)
		int playerTiles=15000;
	else if (rmGetNumberPlayersOnTeam(0) == rmGetNumberPlayersOnTeam(1))
		playerTiles=16400;
	else
		playerTiles=16200;	
			
	int size=2.1*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);
	
	// Picks a default water height
	rmSetSeaLevel(2.0);

	// Picks default terrain and water
	//	rmAddMapTerrainByHeightInfo("yukon\ground2_yuk", 6.0, 9.0, 1.0);
	//	rmAddMapTerrainByHeightInfo("yukon\ground3_yuk", 9.0, 16.0);
	rmSetBaseTerrainMix("lualaba_grass1");
	rmTerrainInitialize("amazon\ground4_ama", 3);
	rmSetMapType("AFRICANjungle");
	rmSetMapType("tropical");
	rmSetMapType("land");
	rmSetLightingSet("lualaba");

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
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.43), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int coinEdgeConstraint=rmCreateBoxConstraint("coin edge of map", rmXTilesToFraction(19), rmZTilesToFraction(19), 1.0-rmXTilesToFraction(19), 1.0-rmZTilesToFraction(19), 2.0);
	int coinEdgeWestConstraint=rmCreateBoxConstraint("coin edge of mapwest", rmXTilesToFraction(19), rmZTilesToFraction(19), 1.0-rmXTilesToFraction(19), 1.0-rmZTilesToFraction(19), 2.0);

   // Cardinal Directions

	int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.32, 0.68, 0, rmZFractionToMeters(0.75), rmDegreesToRadians(65), rmDegreesToRadians(205));
	int NoEastward=rmCreatePieConstraint("NOeastMapConstraint", 0.36, 0.64, 0, rmZFractionToMeters(0.75), rmDegreesToRadians(200), rmDegreesToRadians(70));
	int Westward=rmCreatePieConstraint("westMapConstraint", 0.42, 0.58, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));
	int Northward=rmCreatePieConstraint("northMapConstraint", 0.52, 0.52, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));
	int Southward=rmCreatePieConstraint("southMapConstraint", 0.48, 0.48, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));

   
	// Player constraints
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 20.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("stay far away from players", classPlayer, 50.0);
 
   // Nature avoidance
	int avoidForest=rmCreateClassDistanceConstraint("forest avoids forest", rmClassID("classForest"), 16.0);
	int avoidForestFar=rmCreateClassDistanceConstraint("forest avoids forest far", rmClassID("classForest"), 9.0);
	int avoidCapybara=rmCreateTypeDistanceConstraint("avoids Capybara", "ypWildElephant", 35.0);
	int avoidTapir=rmCreateTypeDistanceConstraint("Tapir avoids Tapir", "Okapi", 35.0);
	int avoidTapirFar=rmCreateTypeDistanceConstraint("Tapir avoids Tapir Far", "Okapi", 52.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "gold", 29.0);
	int avoidCoinFar=rmCreateTypeDistanceConstraint("avoid coin far", "gold", 50.0);
   
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
   int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 13.0);
   int avoidNativesFar=rmCreateClassDistanceConstraint("stuff avoids natives far", rmClassID("natives"), 45.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 65.0);
	
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 15.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 4.0);	
	
   // Decoration avoidance
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 8.0);


   // -------------Define objects
   // These objects are all defined so they can be placed later

	rmSetStatusText("",0.10);

//	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
//	int teamOneCount = rmGetNumberPlayersOnTeam(1);

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	
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

		if(cNumberTeams > 2)
		{
				rmPlacePlayersLine(0.4, 0.6, 0.75, 0.25, 0.05, 0.1);
		}
		else
		{
				rmSetPlacementTeam(teamOne);
					if (cNumberNonGaiaPlayers > 5){
				rmPlacePlayersLine(0.26, 0.34, 0.45, 0.05, 0.05, 0.1);
			}
					else if (cNumberNonGaiaPlayers > 3){
				rmPlacePlayersLine(0.29, 0.27, 0.42, 0.12, 0.05, 0.1);
			}
					else
					{
				rmPlacePlayersLine(0.32, 0.23, 0.39, 0.16, 0.05, 0.1);
			}
				rmSetPlacementTeam(teamTwo);
					if (cNumberNonGaiaPlayers > 5){
				rmPlacePlayersLine(0.66, 0.74, 0.95, 0.55, 0.05, 0.1);
						}
					else if (cNumberNonGaiaPlayers > 3){
				rmPlacePlayersLine(0.73, 0.71, 0.88, 0.58, 0.05, 0.1);
			}
					else
					{
				rmPlacePlayersLine(0.77, 0.68, 0.84, 0.61, 0.05, 0.1);
			}
		}

   // Build a east area
	int eastIslandID = rmCreateArea("east island");
	//rmSetAreaLocation(eastIslandID, 0.75, 0.50);
	rmSetAreaLocation(eastIslandID, 0.75, 0.75); 
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
		
//	rmAddAreaTerrainLayer(eastIslandID, "lualaba\lualabaDF4", 0, 3);
//	rmAddAreaTerrainLayer(eastIslandID, "lualaba\lualabaRF1", 3, 6);
//	rmAddAreaTerrainLayer(eastIslandID, "lualaba\lualabaRF2", 6, 9);

	rmAddAreaConstraint(eastIslandID, Northward);
   
	rmSetAreaObeyWorldCircleConstraint(eastIslandID, false);
	rmSetAreaMix(eastIslandID, "lualaba_grass1");


   // Text
   rmSetStatusText("",0.20);

   // Build a west area
	int westIslandID = rmCreateArea("west island");
	//rmSetAreaLocation(westIslandID, 0, 0.5);
	rmSetAreaLocation(westIslandID, 0.25, 0.25);
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
	//rmAddAreaTerrainLayer(westIslandID, "andes\ground10_and", 0, 3);
//	rmAddAreaTerrainLayer(westIslandID, "amazon\ground4_ama", 3, 12);
	//rmAddAreaTerrainLayer(westIslandID, "andes\ground4_and", 6, 8);
   
	rmAddAreaConstraint(westIslandID, Southward);
   
	rmSetAreaObeyWorldCircleConstraint(westIslandID, false);
//	rmSetAreaMix(westIslandID, "amazon grass");
	rmSetAreaMix(westIslandID, "lualaba_grass1");

   rmBuildAllAreas();

   // Build a east area
	int northIslandID = rmCreateArea("north island");
//	rmSetAreaLocation(northIslandID, 0.75, 0.25);
	rmSetAreaLocation(northIslandID, 0.85, 0.15);
	rmSetAreaWarnFailure(northIslandID, false);
//	rmSetAreaSize(northIslandID, 0.83, 0.83);
	rmSetAreaSize(northIslandID, 0.33, 0.33);
	rmSetAreaCoherence(northIslandID, 0.6);
//        rmAddAreaInfluenceSegment(northIslandID, 0.50, 0.90, 0.90, 0.50);
//        rmAddAreaInfluenceSegment(northIslandID, 0.90, 0.50, 0.85, 0.85);
//        rmAddAreaInfluenceSegment(northIslandID, 0.85, 0.85, 0.50, 0.90);
	rmSetAreaElevationType(northIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(northIslandID, 4.0);
	rmSetAreaBaseHeight(northIslandID, 4.0);
	rmSetAreaElevationMinFrequency(northIslandID, 0.07);
	rmSetAreaElevationOctaves(northIslandID, 4);
	rmSetAreaElevationPersistence(northIslandID, 0.5);
	rmSetAreaElevationNoiseBias(northIslandID, 1); 
	rmAddAreaTerrainLayer(northIslandID, "lualaba\lualabaDF4", 0, 3);
	rmAddAreaTerrainLayer(northIslandID, "lualaba\lualabaRF1", 3, 6);
	rmAddAreaTerrainLayer(northIslandID, "lualaba\lualabaRF2", 6, 9);
   
//	rmAddAreaConstraint(northIslandID, Eastward);
   
	rmSetAreaObeyWorldCircleConstraint(northIslandID, false);
//	rmSetAreaMix(northIslandID, "amazon grass");
	rmSetAreaMix(northIslandID, "lualaba_grass2");

	rmBuildArea(northIslandID);

   // Text
   rmSetStatusText("",0.30);
	float radius = rmZFractionToTiles(0.03);
	// Middle River
	int riverID = rmRiverCreate(-1, "Lualaba River", 5, 5, 9, 11);
	rmRiverAddWaypoint(riverID, 0.01, 0.28);
	rmRiverAddWaypoint(riverID, 0.22, 0.42);
	rmRiverAddWaypoint(riverID, 0.23, 0.57);
	rmRiverAddWaypoint(riverID, 0.20, 0.66);
	rmRiverAddWaypoint(riverID, 0.34, 0.80);
	rmRiverAddWaypoint(riverID, 0.43, 0.77);
	rmRiverAddWaypoint(riverID, 0.58, 0.78);
	rmRiverAddWaypoint(riverID, 0.72, 0.99);
	rmRiverSetShallowRadius(riverID, 11+cNumberNonGaiaPlayers);
//	rmRiverSetBankNoiseParams(riverID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	rmRiverBuild(riverID);
		
	int river2ID = rmRiverCreate(-1, "Lualaba River", 5, 5, 6, 6);
	rmRiverAddWaypoint(river2ID, 0.72, 0.01);
	rmRiverAddWaypoint(river2ID, 0.62, 0.17);
	rmRiverAddWaypoint(river2ID, 0.57, 0.27);
	rmRiverAddWaypoint(river2ID, 0.47, 0.37);
	rmRiverAddWaypoint(river2ID, 0.22, 0.42);
	rmRiverSetShallowRadius(river2ID, radius);
			rmRiverAddShallow(river2ID, rmRandFloat(0.85, 0.87));
			rmRiverAddShallow(river2ID, rmRandFloat(0.53, 0.56));
			rmRiverAddShallow(river2ID, rmRandFloat(0.15, 0.17));
//	rmRiverSetBankNoiseParams(river2ID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	rmRiverBuild(river2ID);
	
	int river3ID = rmRiverCreate(-1, "Lualaba River", 5, 5, 6, 6);
	rmRiverAddWaypoint(river3ID, 0.99, 0.28);
	rmRiverAddWaypoint(river3ID, 0.83, 0.38);
	rmRiverAddWaypoint(river3ID, 0.73, 0.43);
	rmRiverAddWaypoint(river3ID, 0.63, 0.53);
	rmRiverAddWaypoint(river3ID, 0.58, 0.78);
	rmRiverSetShallowRadius(river3ID, radius);
			rmRiverAddShallow(river3ID, rmRandFloat(0.85, 0.87));
			rmRiverAddShallow(river3ID, rmRandFloat(0.53, 0.56));
			rmRiverAddShallow(river3ID, rmRandFloat(0.15, 0.17));
//	rmRiverSetBankNoiseParams(river3ID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	rmRiverBuild(river3ID);
        
	// Set up player areas.
   float playerFraction=rmAreaTilesToFraction(100);
   for(i=1; <cNumberPlayers)
   {
      // Create the area.
      int id=rmCreateArea("Player"+i);
      // Assign to the player.
      rmSetPlayerArea(i, id);
      // Set the size.
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 1);
      rmAddAreaConstraint(id, playerConstraint); 
      rmAddAreaConstraint(id, playerEdgeConstraint);
      rmSetAreaLocPlayer(id, i);
	  rmSetAreaTerrainType(id, "carolina\marshflats");
		// rmSetAreaBaseHeight(id, 8.0);
      rmSetAreaWarnFailure(id, false);
   }

	// Build the areas.
	rmBuildAllAreas();
   
	// Text
	rmSetStatusText("",0.40);


	//Top Left Village
	int topleftVillageID = -1;
		topleftVillageID = rmCreateGrouping("Emboaba village Top Left", subCiv0Name+" "+aur_type+" "+rmRandInt(1, 3));
	rmSetGroupingMinDistance(topleftVillageID, 0.0);
	rmSetGroupingMaxDistance(topleftVillageID, 0.05);
	rmAddGroupingToClass(topleftVillageID, rmClassID("natives"));
	rmAddGroupingToClass(topleftVillageID, rmClassID("importantItem"));
	rmPlaceGroupingAtLoc(topleftVillageID, 0, 0.47, 0.93);

	//Bottom Left Village
	int bottomleftVillageID = -1;
		bottomleftVillageID = rmCreateGrouping("Emboaba village Bottom Left", subCiv1Name+" "+aur_type+" "+rmRandInt(1, 3));
	rmSetGroupingMinDistance(bottomleftVillageID, 0.0);
	rmSetGroupingMaxDistance(bottomleftVillageID, 0.05);
	rmAddGroupingToClass(bottomleftVillageID, rmClassID("natives"));
	rmAddGroupingToClass(bottomleftVillageID, rmClassID("importantItem"));
	rmPlaceGroupingAtLoc(bottomleftVillageID, 0, 0.07, 0.53);

	//Top Right Village
	int topRightVillageID = -1;  
		topRightVillageID = rmCreateGrouping("Emboaba village Top Right", subCiv2Name+" "+aur_type+" "+rmRandInt(1, 3));
	rmSetGroupingMinDistance(topRightVillageID, 0.0);
	rmSetGroupingMaxDistance(topRightVillageID, 0.05);
	rmAddGroupingToClass(topRightVillageID, rmClassID("natives"));
	rmAddGroupingToClass(topRightVillageID, rmClassID("importantItem"));
	rmPlaceGroupingAtLoc(topRightVillageID, 0, 0.45, 0.55);


	//Bottom Right Village
	int bottomRightVillageID = -1;
		bottomRightVillageID = rmCreateGrouping("Emboaba village Bottom Right", subCiv3Name+" "+aur_type+" "+rmRandInt(1, 3));
	rmSetGroupingMinDistance(bottomRightVillageID, 0.0);
	rmSetGroupingMaxDistance(bottomRightVillageID, 0.05);
	rmAddGroupingToClass(bottomRightVillageID, rmClassID("natives"));
	rmAddGroupingToClass(bottomRightVillageID, rmClassID("importantItem"));
	rmPlaceGroupingAtLoc(bottomRightVillageID, 0, 0.75, 0.25);


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
			TCfloat = 22;
		else if (cNumberNonGaiaPlayers > 5)
			TCfloat = 26;
		else 
			TCfloat = 15;
	}
	else 
		TCfloat = 15;
    

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
		rmAddObjectDefConstraint(TCID, avoidTownCenterFar);
	rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, avoidRiverFar);
	rmAddObjectDefConstraint(TCID, avoidAll);
	//rmAddGroupingConstraint(TCID, avoidNativesFar);
	rmAddObjectDefConstraint(TCID, mediumShortAvoidImpassableLand);

	int playerSilverID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerSilverID, "mineGold", 1, 0);
	rmAddObjectDefConstraint(playerSilverID, avoidTownCenter);
	rmSetObjectDefMinDistance(playerSilverID, 15.0);
	rmSetObjectDefMaxDistance(playerSilverID, 20.0);
    rmAddObjectDefConstraint(playerSilverID, avoidImpassableLand);

	// Extra Free Villagers to uniqueness and dynamism
	int playerVillsID = rmCreateObjectDef("player extra vills");
	rmAddObjectDefItem(playerVillsID, "AFRICANvillager", 5, 5.0);
	rmAddObjectDefItem(playerVillsID, "SPCTentLarge", 1, 5.0);
	rmAddObjectDefConstraint(playerVillsID, avoidTownCenter);
	rmSetObjectDefMinDistance(playerVillsID, 10.0);
	rmSetObjectDefMaxDistance(playerVillsID, 18.0);
    rmAddObjectDefConstraint(playerVillsID, avoidImpassableLand);

	int playerCapybaraID=rmCreateObjectDef("player Capybara");
    rmAddObjectDefItem(playerCapybaraID, "Okapi", rmRandInt(8,10), 10.0);
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
    rmAddObjectDefItem(playerTreeID, "TreeAmazon", rmRandInt(5,10), 8.0);
    rmSetObjectDefMinDistance(playerTreeID, 15);
    rmSetObjectDefMaxDistance(playerTreeID, 20);
	rmAddObjectDefConstraint(playerTreeID, avoidAll);
    rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);

	int waterSpawnPointID = 0;

	for(i=1; <cNumberPlayers)
   {
	rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
	rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerCapybaraID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerVillsID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 15.0);  // ...Flag", 1, 1.0); - the first number is the number of flags.  The next number is the float distance.
//		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, 0.27, 0.73);

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
	rmAddObjectDefConstraint(nuggeteasyID, Eastward);
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
	rmAddObjectDefConstraint(nuggetmediumEastID, Northward);
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
	rmAddObjectDefConstraint(nuggetmediumWestID, Southward);
	rmAddObjectDefConstraint(nuggetmediumWestID, Eastward);
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
  	rmAddObjectDefConstraint(nuggethardID, Eastward);
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
  		rmAddObjectDefConstraint(nuggethard2ID, Eastward);
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
  		rmAddObjectDefConstraint(nuggetnutsID, Eastward);
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
	  rmAddObjectDefItem(silverID, "MineCopper", 1, 0.0);
      rmSetObjectDefMinDistance(silverID, 0.0);
      rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(silverID, avoidCoin);
      rmAddObjectDefConstraint(silverID, avoidAll);
      rmAddObjectDefConstraint(silverID, avoidTownCenterFar);
	  rmAddObjectDefConstraint(silverID, avoidNatives);
      rmAddObjectDefConstraint(silverID, avoidImpassableLand);
	  rmAddObjectDefConstraint(silverID, coinEdgeConstraint);
	  rmAddObjectDefConstraint(silverID, Northward);
	  rmAddObjectDefConstraint(silverID, Eastward);
	  //rmAddObjectDefConstraint(silverID, eastIslandID);
	  rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
   }


	for(i=0; < silverCount)
	{
	  int silverWestID = rmCreateObjectDef("silverWest "+i);
	  rmAddObjectDefItem(silverWestID, "MineCopper", 1, 0.0);
      rmSetObjectDefMinDistance(silverWestID, 0.0);
      rmSetObjectDefMaxDistance(silverWestID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(silverWestID, avoidCoin);
      rmAddObjectDefConstraint(silverWestID, avoidAll);
      rmAddObjectDefConstraint(silverWestID, avoidTownCenterFar);
	  rmAddObjectDefConstraint(silverWestID, avoidNatives);
      rmAddObjectDefConstraint(silverWestID, avoidImpassableLand);
	  rmAddObjectDefConstraint(silverWestID, Southward);
	  rmAddObjectDefConstraint(silverWestID, Eastward);
	  //rmAddObjectDefConstraint(silverWestID, westIslandID);
	  rmAddObjectDefConstraint(silverWestID, coinEdgeConstraint);
	  rmPlaceObjectDefAtLoc(silverWestID, 0, 0.5, 0.5);
   }


	//Mines to fill in the large gaps

	silverCount = 2;
	for(i=0; < silverCount)
	{
	int silverEastRandomID = rmCreateObjectDef("silverEastRandom "+i);
	rmAddObjectDefItem(silverEastRandomID, "MineCopper", 1, 0.0);
	rmSetObjectDefMinDistance(silverEastRandomID, 0.0);
	rmSetObjectDefMaxDistance(silverEastRandomID, rmXFractionToMeters(0.495));
	rmAddObjectDefConstraint(silverEastRandomID, avoidCoinFar);
	rmAddObjectDefConstraint(silverEastRandomID, avoidAll);
	rmAddObjectDefConstraint(silverEastRandomID, avoidNativesFar);
	rmAddObjectDefConstraint(silverEastRandomID, longAvoidImpassableLand);
	rmAddObjectDefConstraint(silverEastRandomID, coinEdgeConstraint);
	rmAddObjectDefConstraint(silverEastRandomID, Northward);
	rmAddObjectDefConstraint(silverEastRandomID, Eastward);
	rmPlaceObjectDefAtLoc(silverEastRandomID, 0, 0.25, 0.75);
	}

	silverCount = 2;
	for(i=0; < silverCount)
	{
	  int silverWestRandomID = rmCreateObjectDef("silverWestRandom "+i);
	  rmAddObjectDefItem(silverWestRandomID, "MineCopper", 1, 0.0);
      rmSetObjectDefMinDistance(silverWestRandomID, 0.0);
      rmSetObjectDefMaxDistance(silverWestRandomID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(silverWestRandomID, avoidCoinFar);
      rmAddObjectDefConstraint(silverWestRandomID, avoidAll);
	  rmAddObjectDefConstraint(silverWestRandomID, avoidNativesFar);
      rmAddObjectDefConstraint(silverWestRandomID, longAvoidImpassableLand);
	  rmAddObjectDefConstraint(silverWestRandomID, coinEdgeConstraint);
	  rmAddObjectDefConstraint(silverWestRandomID, Southward);
	  rmAddObjectDefConstraint(silverWestRandomID, Eastward);
	  rmPlaceObjectDefAtLoc(silverWestRandomID, 0, 0.75, 0.75);
   }



	rmSetStatusText("",0.80);

	// Forest areas

	numTries=4*cNumberNonGaiaPlayers;  
	failCount=0;
	for (i=0; <numTries)
		{   
			int forestRandomID=rmCreateArea("forestRandomID"+i, northIslandID);
			rmSetAreaWarnFailure(forestRandomID, false);
			rmSetAreaSize(forestRandomID, rmAreaTilesToFraction(190), rmAreaTilesToFraction(220));
			rmSetAreaForestType(forestRandomID, "LualabaRainForest1");
			rmSetAreaForestDensity(forestRandomID, 0.9);
			rmSetAreaForestClumpiness(forestRandomID, 0.3);		
			rmSetAreaForestUnderbrush(forestRandomID, 0.4);
			rmSetAreaMinBlobs(forestRandomID, 2);
			rmSetAreaMaxBlobs(forestRandomID, 6);						
			rmSetAreaMinBlobDistance(forestRandomID, 5.0);
			rmSetAreaMaxBlobDistance(forestRandomID, 15.0);
			rmSetAreaCoherence(forestRandomID, 0.4);
			rmSetAreaSmoothDistance(forestRandomID, 10);
			rmAddAreaToClass(forestRandomID, rmClassID("classForest"));
			rmAddAreaConstraint(forestRandomID, avoidForest); 
			rmAddAreaConstraint(forestRandomID, shortAvoidImportantItem);
			rmAddAreaConstraint(forestRandomID, playerConstraint);
			rmAddAreaConstraint(forestRandomID, avoidRiver);
			rmAddAreaConstraint(forestRandomID, avoidCliff);
			rmAddAreaConstraint(forestRandomID, avoidAll);
//			rmAddAreaConstraint(forestRandomID, Northward);
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

	if (cNumberNonGaiaPlayers > 4)
		numTries=2*cNumberNonGaiaPlayers;
	else
		numTries=3*cNumberNonGaiaPlayers;
	failCount=0;
	for (i=0; <numTries)
		{   
			int forestID=rmCreateArea("forestID"+i);
			rmSetAreaWarnFailure(forestID, false);
			rmSetAreaSize(forestID, rmAreaTilesToFraction(160), rmAreaTilesToFraction(200));
			rmSetAreaForestType(forestID, "LualabaRainForest1");
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
			rmAddAreaConstraint(forestID, Southward);
//			rmAddAreaConstraint(forestID, Westward);
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
		numTries=2*cNumberNonGaiaPlayers;
	else
		numTries=3*cNumberNonGaiaPlayers; 
	failCount=0;
	for (i=0; <numTries)
		{   
			int forestEastID=rmCreateArea("forestEastID"+i);
			rmSetAreaWarnFailure(forestEastID, false);
			rmSetAreaSize(forestEastID, rmAreaTilesToFraction(160), rmAreaTilesToFraction(200));
			rmSetAreaForestType(forestEastID, "LualabaRainForest2");
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
			rmAddAreaConstraint(forestEastID, Northward);
//			rmAddAreaConstraint(forestEastID, Eastward);
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

	// Text
	

	// Resources that can be placed after forests


	// Text
	

	if (cNumberNonGaiaPlayers<7)
		{int tapirCount =1.8*cNumberNonGaiaPlayers;}
	else
		{tapirCount =1.2*cNumberNonGaiaPlayers;}

	rmEchoInfo("tapir count = "+tapirCount);
	
	for (i=0; <tapirCount)
		{
	int tapirEastID = rmCreateObjectDef("tapir east herd " +i);
	rmAddObjectDefItem(tapirEastID, "ypWildElephant", rmRandInt(4,5), 13);
	rmSetObjectDefMinDistance(tapirEastID, 0.0);
	rmSetObjectDefMaxDistance(tapirEastID, rmXFractionToMeters(0.8));
	rmAddObjectDefConstraint(tapirEastID, avoidTapir);
	rmAddObjectDefConstraint(tapirEastID, avoidCapybara);
	rmAddObjectDefConstraint(tapirEastID, avoidAll);
	rmAddObjectDefConstraint(tapirEastID, avoidNativesFar);
	rmAddObjectDefConstraint(tapirEastID, avoidRiver);
	rmAddObjectDefConstraint(tapirEastID, avoidCliff);
	rmAddObjectDefConstraint(tapirEastID, Northward);
	rmAddObjectDefConstraint(tapirEastID, Eastward);
	rmSetObjectDefCreateHerd(tapirEastID, true);
	
	rmPlaceObjectDefAtLoc(tapirEastID, 0, 0.5, 0.5);
		}

	for (i=0; <tapirCount)
		{
	int tapirWestID = rmCreateObjectDef("tapir west herd " +i);
	rmAddObjectDefItem(tapirWestID, "ypWildElephant", rmRandInt(4,5), 13);
	rmSetObjectDefMinDistance(tapirWestID, 0.0);
	rmSetObjectDefMaxDistance(tapirWestID, rmXFractionToMeters(0.8));
	rmAddObjectDefConstraint(tapirWestID, avoidTapir);
	rmAddObjectDefConstraint(tapirWestID, avoidCapybara);
	rmAddObjectDefConstraint(tapirWestID, avoidAll);
	rmAddObjectDefConstraint(tapirWestID, avoidNativesFar);
	rmAddObjectDefConstraint(tapirWestID, avoidRiver);
	rmAddObjectDefConstraint(tapirWestID, Southward);
	rmAddObjectDefConstraint(tapirWestID, Eastward);
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
			rmAddObjectDefItem(tapirRandomID, "Okapi", rmRandInt(3,6), 11);
			rmSetObjectDefMinDistance(tapirRandomID, 0.0);
			rmSetObjectDefMaxDistance(tapirRandomID, rmXFractionToMeters(0.8));
			rmAddObjectDefConstraint(tapirRandomID, avoidTapirFar);
			rmAddObjectDefConstraint(tapirRandomID, avoidCapybara);
			rmAddObjectDefConstraint(tapirRandomID, avoidAll);
			rmAddObjectDefConstraint(tapirRandomID, avoidNativesFar);
			rmAddObjectDefConstraint(tapirRandomID, avoidRiver);
			rmAddObjectDefConstraint(tapirRandomID, Eastward);
			rmSetObjectDefCreateHerd(tapirRandomID, true);
			rmPlaceObjectDefAtLoc(tapirRandomID, 0, 0.5, 0.5);
		}
	}

	tapirCount = 2*cNumberNonGaiaPlayers+1;
		for (i=0; <tapirCount)
		{
			int WestHerdID = rmCreateObjectDef("west elephant herd " +i);
			rmAddObjectDefItem(WestHerdID, "ypWildElephant", rmRandInt(6,7), 11);
			rmSetObjectDefMinDistance(WestHerdID, 0.0);
			rmSetObjectDefMaxDistance(WestHerdID, rmXFractionToMeters(0.5));
			rmAddObjectDefConstraint(WestHerdID, avoidTapir);
			rmAddObjectDefConstraint(WestHerdID, avoidCapybara);
			rmAddObjectDefConstraint(WestHerdID, avoidAll);
			rmAddObjectDefConstraint(WestHerdID, avoidNatives);
			rmAddObjectDefConstraint(WestHerdID, avoidRiver);
			rmAddObjectDefConstraint(WestHerdID, NoEastward);
			rmSetObjectDefCreateHerd(WestHerdID, true);
			rmPlaceObjectDefAtLoc(WestHerdID, 0, 0.5, 0.5);
		}

	silverCount = 2*cNumberNonGaiaPlayers+1;
	for(i=0; < silverCount)
	{
	  int GoldWestID = rmCreateObjectDef("Gold West "+i);
	  rmAddObjectDefItem(GoldWestID, "MineGold", 1, 0.0);
      rmSetObjectDefMinDistance(GoldWestID, 0.0);
      rmSetObjectDefMaxDistance(GoldWestID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(GoldWestID, avoidCoin);
      rmAddObjectDefConstraint(GoldWestID, avoidAll);
	  rmAddObjectDefConstraint(GoldWestID, avoidNatives);
      rmAddObjectDefConstraint(GoldWestID, longAvoidImpassableLand);
//	  rmAddObjectDefConstraint(GoldWestID, coinEdgeConstraint);
	  rmAddObjectDefConstraint(GoldWestID, NoEastward);
	  rmPlaceObjectDefAtLoc(GoldWestID, 0, 0.5, 0.5);
   }

   int Fish1ID=rmCreateObjectDef("fish one");
   rmAddObjectDefItem(Fish1ID, "ypFishCarp", 1, 0.0);
   rmSetObjectDefMinDistance(Fish1ID, 0.0);
   rmSetObjectDefMaxDistance(Fish1ID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(Fish1ID, fishLand);
   rmAddObjectDefConstraint(Fish1ID, fishVsFishID);
   rmAddObjectDefConstraint(Fish1ID, Westward);
	rmPlaceObjectDefAtLoc(Fish1ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*5);
	
   int Fish2ID=rmCreateObjectDef("fish two");
   rmAddObjectDefItem(Fish2ID, "ypFishCatfish", 1, 0.0);
   rmSetObjectDefMinDistance(Fish2ID, 0.0);
   rmSetObjectDefMaxDistance(Fish2ID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(Fish2ID, fishLand);
   rmAddObjectDefConstraint(Fish2ID, fishVsFishID);
   rmAddObjectDefConstraint(Fish2ID, Westward);
	rmPlaceObjectDefAtLoc(Fish2ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*5);

  int CrocodileID=rmCreateObjectDef("Crocodile");
	rmAddObjectDefItem(CrocodileID, "WildCrocodile", 1, 0.0);
	rmSetObjectDefMinDistance(CrocodileID, 0);
	rmSetObjectDefMaxDistance(CrocodileID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(CrocodileID, avoidAll);
  	rmAddObjectDefConstraint(CrocodileID, NoEastward);
	rmPlaceObjectDefAtLoc(CrocodileID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);

	// Text
	rmSetStatusText("",1.0);

  // King of the Hill (added 2026-11 for WoL): centre, between the river branches
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
  
