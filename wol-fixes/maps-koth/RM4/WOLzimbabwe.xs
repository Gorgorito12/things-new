// Great Zimbabwe

include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";
// Main entry point for random map script
void main(void)
{
   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

	// Which map - four possible variations (excluding which end the players start on, which is a separate thing)

   // Picks the map size
   int playerTiles=10000;		
   int size=3*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);
	
	// Picks a default water height
   rmSetSeaLevel(4.0);	// this is height of river surface compared to surrounding land. River depth is in the river XML.

	// Picks default terrain and water
	rmSetBaseTerrainMix("great plains drygrass");
	rmTerrainInitialize("Deccan\ground_grass2_deccan", 5);
   rmSetMapType("AFRICANsavannah");
   rmSetMapType("africa");
	rmSetMapType("grass");
	rmSetMapType("rainclouds");
	rmSetMapType("land");
   rmSetLightingSet("312b_washington");

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

	int classCliff = rmDefineClass("Cliffs");
	
		// *****************NATIVES****************************************************************************
 

  // choose AURs - use for Tribal Theme
    string aur_type = "tribal";
    int resourcesarray = xsArrayCreateString(17, "", "");

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
    xsArraySetString(resourcesarray, 15, "gold");
    xsArraySetString(resourcesarray, 16, "treasures");
	xsArraySetString(resourcesarray, 17, "cattle");

    rmAllocateSubCivs(3);

    string subCiv0Name = "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 14));
    int subCiv0 = rmGetCivID(subCiv0Name);
    rmSetSubCiv(0, subCiv0Name); 

    string subCiv1Name = "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 14));
    int subCiv1 = rmGetCivID(subCiv1Name);
    rmSetSubCiv(1, subCiv1Name); 

    string subCiv2Name = "AUR"+xsArrayGetString(resourcesarray, rmRandInt(15, 17));
    int subCiv2 = rmGetCivID(subCiv2Name);
    rmSetSubCiv(2, subCiv2Name); 


  // choose African Savannah Huntables
    int AfricanHuntableArray = xsArrayCreateString(7, "", "");

    xsArraySetString(AfricanHuntableArray, 1, "Gazelle");
    xsArraySetString(AfricanHuntableArray, 2, "ypWildElephant");
    xsArraySetString(AfricanHuntableArray, 3, "Ostrich");
    xsArraySetString(AfricanHuntableArray, 4, "Giraffe");
    xsArraySetString(AfricanHuntableArray, 5, "Zebra");
    xsArraySetString(AfricanHuntableArray, 6, "Antelope");
    xsArraySetString(AfricanHuntableArray, 7, "Gnu");

  string huntable1 = xsArrayGetString(AfricanHuntableArray, rmRandInt(1, 7));
  string huntable2 = xsArrayGetString(AfricanHuntableArray, rmRandInt(3, 7));
  string huntable3 = xsArrayGetString(AfricanHuntableArray, rmRandInt(1, 7));
  string huntable4 = xsArrayGetString(AfricanHuntableArray, rmRandInt(1, 7));


   // -------------Define constraints
   // These are used to have objects and areas avoid each other
   
   // Map edge constraints
   //int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(6), rmZTilesToFraction(6), 1.0-rmXTilesToFraction(6), 1.0-rmZTilesToFraction(6), 0.01);
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.43), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int coinEdgeConstraint=rmCreateBoxConstraint("coin edge of map", rmXTilesToFraction(19), rmZTilesToFraction(19), 1.0-rmXTilesToFraction(19), 1.0-rmZTilesToFraction(19), 2.0);

   // Cardinal Directions

	int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
	int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));
	int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
	int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));

	// Player constraints
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 20.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("stay far away from players", classPlayer, 50.0);
 
   // Nature avoidance
	int avoidForest=rmCreateClassDistanceConstraint("forest avoids forest", rmClassID("classForest"), 10.0);
	int avoidForestFar=rmCreateClassDistanceConstraint("forest avoids forest far", rmClassID("classForest"), 40.0);
	int avoidarmadillo=rmCreateTypeDistanceConstraint("avoids armadillo", "armadillo", 45.0);
	int avoidcapybara=rmCreateTypeDistanceConstraint("capybara avoids capybara", "capybara", 45.0);
	int avoidcapybaraFar=rmCreateTypeDistanceConstraint("capybara avoids capybara Far", "capybara", 65.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "gold", 30.0);
	int avoidCoinFar=rmCreateTypeDistanceConstraint("avoid coin far", "gold", 60.0);
   
   // Avoid impassable land
	int avoidImpassableLand = rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 10.0);
	int avoidCliff = rmCreateClassDistanceConstraint("stuff vs. cliff", rmClassID("classCliff"), 12.0);
	int cliffAvoidCliff = rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 30.0);
	int mediumShortAvoidImpassableLand = rmCreateTerrainDistanceConstraint("mediumshort avoid impassable land", "Land", false, 10.0);
	int shortAvoidImpassableLand = rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int mediumAvoidImpassableLand = rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 12.0);
	int longAvoidImpassableLand = rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 20.0);

   // Unit avoidance
	int avoidHuari=rmCreateTypeDistanceConstraint("avoid Huari", "huariStronghold", 20.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 20.0);
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
	int avoidTownCenterSupaFar=rmCreateTypeDistanceConstraint("avoid Town Center Supa Far", "townCenter", 50.0);
   int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 60.0);
   int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other by a bit", rmClassID("importantItem"), 10.0);
   int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 10.0);
   int avoidNativesFar=rmCreateClassDistanceConstraint("stuff avoids natives far", rmClassID("natives"), 45.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 65.0);
	
   // Decoration avoidance
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 8.0);
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);


   // -------------Define objects
   // These objects are all defined so they can be placed later

	rmSetStatusText("",0.10);

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);

		// ****************************** PLACE PLAYERS ******************************

	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
// 2 team and FFA support
	float OneVOnePlacement=rmRandFloat(0, 1);
	if (cNumberNonGaiaPlayers == 2)
	{

		if ( OneVOnePlacement < 0.5)
		{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.4, 0.2, 0.2, 0.4, 0, 0.0);

			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.6, 0.8, 0.8, 0.6, 0, 0.0);
		}
		else
		{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.6, 0.8, 0.8, 0.6, 0, 0.0);

			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.4, 0.2, 0.2, 0.4, 0, 0.0);
		}
		
	}
	//*******************************TEAM PLACEMENTS*****************************
	else if ( cNumberTeams == 2 && teamZeroCount == teamOneCount)
	{

		rmSetPlacementTeam(0);
		rmSetTeamSpacingModifier(0.20);
		rmPlacePlayersLine(0.1, 0.5, 0.5, 0.1, 0, 0.0);

		rmSetPlacementTeam(1);
		rmSetTeamSpacingModifier(0.20);
		rmPlacePlayersLine(0.9, 0.5, 0.5, 0.9, 0, 0.0);
	
	}
	//******************************************FFA SUPPORT***************************************
	else if (cNumberTeams > 2)
	{
      bool southSide = true;

      float spacingIncrement = (0.35 / (cNumberNonGaiaPlayers / 2));
      float spacingSouth = 0;
      float spacingNorth = 0;
      
      float southStart = 0.45;
      float southEnd = 0.82;
      float northStart = 0.95;
      float northEnd = 0.32;

      for (i = 0; < cNumberNonGaiaPlayers)
      {
         rmEchoInfo("i = "+i);
         if (southSide == true)
         {
            rmSetPlacementTeam(i);
            rmSetPlacementSection((southStart + spacingSouth), southEnd);
	         rmSetTeamSpacingModifier(0.25);
	         rmPlacePlayersCircular(0.4, 0.4, 0);
            spacingSouth = spacingSouth + spacingIncrement;
         }
         else
         {
            rmSetPlacementTeam(i);
            rmSetPlacementSection((northStart + spacingNorth), northEnd);
	         rmSetTeamSpacingModifier(0.25);
	         rmPlacePlayersCircular(0.4, 0.4, 0);
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
   else 
   {
      if (teamZeroCount < teamOneCount)
      {
         rmSetPlacementTeam(0);
         rmSetPlacementSection(0.55, 0.75);
		   rmSetTeamSpacingModifier(0.35 / teamZeroCount);
		   rmPlacePlayersCircular(0.4, 0.4, 0);

		   rmSetPlacementTeam(1);
         rmSetPlacementSection(0.95, 0.32);
		   rmSetTeamSpacingModifier(0.35 / teamOneCount);
		   rmPlacePlayersCircular(0.4, 0.4, 0);
      }
      else 
      {
         rmSetPlacementTeam(0);
         rmSetPlacementSection(0.45, 0.82);
		   rmSetTeamSpacingModifier(0.35 / teamZeroCount);
		   rmPlacePlayersCircular(0.4, 0.4, 0);

		   rmSetPlacementTeam(1);
         rmSetPlacementSection(0.0, 0.2);
		   rmSetTeamSpacingModifier(0.35 / teamOneCount);
		   rmPlacePlayersCircular(0.4, 0.4, 0);
      }
   }

   // Build a north area
	int eastIslandID = rmCreateArea("east island");
	rmSetAreaLocation(eastIslandID, 0.15, 0.85); 
	rmSetAreaWarnFailure(eastIslandID, false);
	rmSetAreaSize(eastIslandID, 0.60, 0.60);
	rmSetAreaCoherence(eastIslandID, 1.0);

	rmSetAreaElevationType(eastIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(eastIslandID, 5.0);
	rmSetAreaBaseHeight(eastIslandID, 4.0);
	rmSetAreaElevationMinFrequency(eastIslandID, 0.07);
	rmSetAreaElevationOctaves(eastIslandID, 4);
	rmSetAreaElevationPersistence(eastIslandID, 0.5);
	rmSetAreaElevationNoiseBias(eastIslandID, 1);
   
	rmSetAreaObeyWorldCircleConstraint(eastIslandID, false);
	rmSetAreaMix(eastIslandID, "great plains drygrass");

   // Text
   rmSetStatusText("",0.20);

   // Build a south area
	int westIslandID = rmCreateArea("west island");
	//rmSetAreaLocation(westIslandID, 0, 0.5);
	rmSetAreaLocation(westIslandID, 0.75, 0.25);
	rmSetAreaWarnFailure(westIslandID, false);
	rmSetAreaSize(westIslandID, 0.60, 0.60);
	rmSetAreaCoherence(westIslandID, 0.7);

	rmSetAreaElevationType(westIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(westIslandID, 5.0);
	rmSetAreaBaseHeight(westIslandID, 4.0);
	rmSetAreaElevationMinFrequency(westIslandID, 0.07);
	rmSetAreaElevationOctaves(westIslandID, 4);
	rmSetAreaElevationPersistence(westIslandID, 0.5);
	rmSetAreaElevationNoiseBias(westIslandID, 1); 
   
	rmSetAreaObeyWorldCircleConstraint(westIslandID, false);
	rmSetAreaMix(westIslandID, "texas_grass");

   rmBuildAllAreas();
   
   	int valleyID = rmCreateArea("valley");
	//rmSetAreaLocation(valleyID, 0, 0.5);
	rmSetAreaLocation(valleyID, 0.5, 0.5);
	rmSetAreaSize(valleyID, 0.2, 0.2);
	rmSetAreaCoherence(valleyID, 0.6);
	rmSetAreaObeyWorldCircleConstraint(valleyID, false);
	rmSetAreaCliffType(valleyID, "Deccan Plateau");	
	rmSetAreaCliffEdge(valleyID, 2, 0.3, 0.4, 0.4, 0);
	rmSetAreaCliffHeight(valleyID, -9, 1.0, 1.0); 
	rmSetAreaWarnFailure(valleyID, true);

	rmBuildArea(valleyID);

   // Text
   rmSetStatusText("",0.30);
	
	// Set up player areas.
   float playerFraction = rmAreaTilesToFraction(100);
   for(i = 0; < cNumberNonGaiaPlayers)
   {
      // Create the area.
      int id = rmCreateArea("Player"+i);
      // Assign to the player.
      rmSetPlayerArea(i, id);
      // Set the size.
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 1);
      rmAddAreaConstraint(id, playerConstraint); 
      rmAddAreaConstraint(id, playerEdgeConstraint);
	   rmSetAreaTerrainType(id, "terrain\great_plains\ground2_gp");
      rmSetAreaWarnFailure(id, false);
   }

   // Build the areas.
   rmBuildAllAreas();
   
	// Text
	rmSetStatusText("",0.40);

   // Text
   rmSetStatusText("",0.50);

   int failCount = -1;
   int numTries = cNumberNonGaiaPlayers+2;


    int zimbabwe = rmCreateGrouping("zimbabwe", "Great Zimbabwe "+rmRandInt(1, 5));
    rmSetGroupingMinDistance(zimbabwe, 0.0);
    rmSetGroupingMaxDistance(zimbabwe, rmXFractionToMeters(0.1));
    rmAddGroupingConstraint(zimbabwe, playerConstraint);
    rmAddGroupingToClass(zimbabwe, rmClassID("importantItem"));
	    rmAddGroupingToClass(zimbabwe, rmClassID("natives"));
    rmPlaceGroupingAtLoc(zimbabwe, 0, 0.5, 0.5);	
	
	 int aurSettlementA = rmCreateGrouping("aur village A", subCiv0Name+" "+aur_type+" "+rmRandInt(1, 3));
    rmSetGroupingMinDistance(aurSettlementA, 0.0);
    rmSetGroupingMaxDistance(aurSettlementA, rmXFractionToMeters(0.1));
    rmAddGroupingConstraint(aurSettlementA, avoidImpassableLand);
    rmAddGroupingToClass(aurSettlementA, rmClassID("importantItem"));
    rmAddGroupingToClass(aurSettlementA, rmClassID("natives"));
    rmAddGroupingConstraint(aurSettlementA, avoidImportantItem);
    rmAddGroupingConstraint(aurSettlementA, avoidNatives);
rmPlaceGroupingInArea(aurSettlementA, 0, westIslandID, 1);


    int aurSettlementB = rmCreateGrouping("aur village B", subCiv1Name+" "+aur_type+" "+rmRandInt(1, 3));
    rmSetGroupingMinDistance(aurSettlementB, 0.0);
    rmSetGroupingMaxDistance(aurSettlementB, rmXFractionToMeters(0.1));
    rmAddGroupingConstraint(aurSettlementB, avoidImpassableLand);
    rmAddGroupingToClass(aurSettlementB, rmClassID("importantItem"));
    rmAddGroupingToClass(aurSettlementB, rmClassID("natives"));
    rmAddGroupingConstraint(aurSettlementB, avoidImportantItem);
    rmAddGroupingConstraint(aurSettlementB, avoidNatives);
rmPlaceGroupingInArea(aurSettlementB, 0, eastIslandID, 1);

    int aurSettlementC = rmCreateGrouping("aur village C", subCiv2Name+" "+aur_type+" "+rmRandInt(1, 3));
    rmSetGroupingMinDistance(aurSettlementC, 0.0);
    rmSetGroupingMaxDistance(aurSettlementC, rmXFractionToMeters(0.1));
    rmAddGroupingToClass(aurSettlementC, rmClassID("importantItem"));
    rmAddGroupingToClass(aurSettlementC, rmClassID("natives"));
    rmAddGroupingConstraint(aurSettlementC, avoidImportantItem);
    rmAddGroupingConstraint(aurSettlementC, avoidNatives);
rmPlaceGroupingInArea(aurSettlementC, 0, valleyID, 1);

    int ruins = rmCreateGrouping("ruins", "Zimbabwe Small "+rmRandInt(1, 10));
    rmSetGroupingMinDistance(ruins, 0.0);
    rmSetGroupingMaxDistance(ruins, rmXFractionToMeters(0.1));
    rmAddGroupingConstraint(ruins, playerConstraint);
    rmAddGroupingToClass(ruins, rmClassID("importantItem"));
rmPlaceGroupingInArea(ruins, 0, westIslandID, 1);

    int ruins2 = rmCreateGrouping("ruins2", "Zimbabwe Small "+rmRandInt(1, 10));
    rmSetGroupingMinDistance(ruins2, 0.0);
    rmSetGroupingMaxDistance(ruins2, rmXFractionToMeters(0.1));
    rmAddGroupingConstraint(ruins2, playerConstraint);
    rmAddGroupingToClass(ruins2, rmClassID("importantItem"));
rmPlaceGroupingInArea(ruins2, 0, eastIslandID, 1);

    int ruins3 = rmCreateGrouping("ruins3", "Zimbabwe Small "+rmRandInt(1, 10));
    rmSetGroupingMinDistance(ruins3, 0.0);
    rmSetGroupingMaxDistance(ruins3, rmXFractionToMeters(0.1));
    rmAddGroupingConstraint(ruins3, playerConstraint);
    rmAddGroupingToClass(ruins3, rmClassID("importantItem"));
rmPlaceGroupingInArea(ruins3, 0, eastIslandID, 1);

    int ruins4 = rmCreateGrouping("ruins4", "Zimbabwe Small "+rmRandInt(1, 10));
    rmSetGroupingMinDistance(ruins4, 0.0);
    rmSetGroupingMaxDistance(ruins4, rmXFractionToMeters(0.1));
    rmAddGroupingConstraint(ruins4, playerConstraint);
    rmAddGroupingToClass(ruins4, rmClassID("importantItem"));
rmPlaceGroupingInArea(ruins4, 0, westIslandID, 1);


	// PLAYER STARTING RESOURCES

   rmClearClosestPointConstraints();
   int TCfloat = 10;
   
	int TCID = rmCreateObjectDef("Player TC");

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

	int playerSilverID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerSilverID, "MineGold", 1, 0);
	rmAddObjectDefConstraint(playerSilverID, avoidTownCenter);
	rmSetObjectDefMinDistance(playerSilverID, 15.0);
	rmSetObjectDefMaxDistance(playerSilverID, 20.0);
   rmAddObjectDefConstraint(playerSilverID, avoidImpassableLand);
   rmAddObjectDefConstraint(playerSilverID, coinEdgeConstraint);


	int playerarmadilloID=rmCreateObjectDef("player armadillo");
   rmAddObjectDefItem(playerarmadilloID, huntable4, 5, 10.0);
   rmSetObjectDefMinDistance(playerarmadilloID, 10);
   rmSetObjectDefMaxDistance(playerarmadilloID, 18);
   rmAddObjectDefConstraint(playerarmadilloID, avoidAll);
   rmAddObjectDefConstraint(playerarmadilloID, avoidImpassableLand);
   rmAddObjectDefConstraint(playerarmadilloID, avoidCliff);
   rmSetObjectDefCreateHerd(playerarmadilloID, true);

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

	int playerBerryID = rmCreateObjectDef("player berries");
   rmAddObjectDefItem(playerBerryID, "Watermelon", rmRandInt(2,3), 8.0);
   rmSetObjectDefMinDistance(playerBerryID, 40);
   rmSetObjectDefMaxDistance(playerBerryID, 70);
   rmAddObjectDefConstraint(playerBerryID, avoidAll);
   rmAddObjectDefConstraint(playerBerryID, avoidImpassableLand);



	int playerTreeID = rmCreateObjectDef("player trees");
   rmAddObjectDefItem(playerTreeID, "TreeAcacia", rmRandInt(5,10), 8.0);
   rmSetObjectDefMinDistance(playerTreeID, 15);
   rmSetObjectDefMaxDistance(playerTreeID, 20);
   rmAddObjectDefConstraint(playerTreeID, avoidAll);
   rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);

   
      int numCliffs=cNumberNonGaiaPlayers;
   for(i=0; <cNumberNonGaiaPlayers)
   {
   		int canyonID=rmCreateArea("cliff "+i);
		rmSetAreaSize(canyonID, 0.05, 0.05); 
		rmSetAreaWarnFailure(canyonID, false);
		rmSetAreaMix(canyonID, "texas_grass");
		rmSetAreaCoherence(canyonID, 0.9);
		rmSetAreaHeightBlend(canyonID, 1);
		rmSetAreaLocation(canyonID, 0.8, 0.8); 
   }		
		


	for(i = 1; < cNumberPlayers)
   {
	rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
	rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerBerryID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerarmadilloID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	
		rmSetAreaLocation(canyonID, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmBuildArea(canyonID);
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
      rmAddObjectDefConstraint(nuggethard2ID, playerEdgeConstraint);
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
      rmAddObjectDefConstraint(nuggetnutsID, playerEdgeConstraint);
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
      rmAddObjectDefItem(silverID, "MineGold", 1, 0.0);
      rmSetObjectDefMinDistance(silverID, 0.0);
      rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
      rmAddObjectDefConstraint(silverID, avoidCoin);
      rmAddObjectDefConstraint(silverID, avoidAll);
      rmAddObjectDefConstraint(silverID, avoidTownCenterFar);
      rmAddObjectDefConstraint(silverID, avoidNatives);
      rmAddObjectDefConstraint(silverID, avoidImpassableLand);
      rmAddObjectDefConstraint(silverID, coinEdgeConstraint);
      rmAddObjectDefConstraint(silverID, Northward);
      //rmAddObjectDefConstraint(silverID, eastIslandID);
      rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
   }

	for(i=0; < silverCount)
	{
      int silverWestID = rmCreateObjectDef("silverWest "+i);
      rmAddObjectDefItem(silverWestID, "MineGold", 1, 0.0);
      rmSetObjectDefMinDistance(silverWestID, 0.0);
      rmSetObjectDefMaxDistance(silverWestID, rmXFractionToMeters(0.5));
      rmAddObjectDefConstraint(silverWestID, avoidCoin);
      rmAddObjectDefConstraint(silverWestID, avoidAll);
      rmAddObjectDefConstraint(silverWestID, avoidTownCenterFar);
      rmAddObjectDefConstraint(silverWestID, avoidNatives);
      rmAddObjectDefConstraint(silverWestID, avoidImpassableLand);
      rmAddObjectDefConstraint(silverWestID, Southward);
      //rmAddObjectDefConstraint(silverWestID, westIslandID);
      rmAddObjectDefConstraint(silverWestID, coinEdgeConstraint);
      rmPlaceObjectDefAtLoc(silverWestID, 0, 0.5, 0.5);
   }


	//Mines to fill in the large gaps

	silverCount = 2;
	for(i=0; < silverCount)
	{
	int silverEastRandomID = rmCreateObjectDef("silverEastRandom "+i);
	rmAddObjectDefItem(silverEastRandomID, "MineGold", 1, 0.0);
	rmSetObjectDefMinDistance(silverEastRandomID, 0.0);
	rmSetObjectDefMaxDistance(silverEastRandomID, rmXFractionToMeters(0.2));
	rmAddObjectDefConstraint(silverEastRandomID, avoidCoinFar);
	rmAddObjectDefConstraint(silverEastRandomID, avoidAll);
	rmAddObjectDefConstraint(silverEastRandomID, avoidNativesFar);
	rmAddObjectDefConstraint(silverEastRandomID, longAvoidImpassableLand);
	rmAddObjectDefConstraint(silverEastRandomID, coinEdgeConstraint);
   rmAddObjectDefConstraint(silverEastRandomID, Northward);
	rmPlaceObjectDefAtLoc(silverEastRandomID, 0, 0.5, 0.5);
	}


	silverCount = 2;
	for(i=0; < silverCount)
	{
      int silverWestRandomID = rmCreateObjectDef("silverWestRandom "+i);
      rmAddObjectDefItem(silverWestRandomID, "Cow", 1, 0.0);
      rmSetObjectDefMinDistance(silverWestRandomID, 0.0);
      rmSetObjectDefMaxDistance(silverWestRandomID, rmXFractionToMeters(0.2));
      rmAddObjectDefConstraint(silverWestRandomID, avoidCoinFar);
      rmAddObjectDefConstraint(silverWestRandomID, avoidAll);
      rmAddObjectDefConstraint(silverWestRandomID, avoidNativesFar);
      rmAddObjectDefConstraint(silverWestRandomID, longAvoidImpassableLand);
      rmAddObjectDefConstraint(silverWestRandomID, coinEdgeConstraint);
      rmAddObjectDefConstraint(silverWestRandomID, Southward);
      rmPlaceObjectDefAtLoc(silverWestRandomID, 0, 0.5, 0.5);
   }

	rmSetStatusText("",0.80);

	// Forest areas

	if (cNumberNonGaiaPlayers > 4)
		numTries=3*cNumberNonGaiaPlayers;
	else
		numTries=5*cNumberNonGaiaPlayers;
	failCount=0;
	for (i=0; <numTries)
		{   
			int forestID=rmCreateArea("forestID"+i, westIslandID);
			rmSetAreaWarnFailure(forestID, false);
			rmSetAreaSize(forestID, rmAreaTilesToFraction(180), rmAreaTilesToFraction(210));
			rmSetAreaForestType(forestID, "Acacia Forest");
			rmSetAreaForestDensity(forestID, 0.7);
			rmSetAreaForestClumpiness(forestID, 0.6);		
			rmSetAreaForestUnderbrush(forestID, 0.6);
			rmSetAreaMinBlobs(forestID, 1);
			rmSetAreaMaxBlobs(forestID, 10);						
			rmSetAreaMinBlobDistance(forestID, 5.0);
			rmSetAreaMaxBlobDistance(forestID, 20.0);
			rmSetAreaCoherence(forestID, 0.4);
			rmSetAreaSmoothDistance(forestID, 10);
			rmAddAreaToClass(forestID, rmClassID("classForest"));
			rmAddAreaConstraint(forestID, avoidForest);  
			rmAddAreaConstraint(forestID, shortAvoidImportantItem);
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
		numTries=5*cNumberNonGaiaPlayers; 
	failCount=0;
	for (i=0; <numTries)
		{   
			int forestEastID=rmCreateArea("forestEastID"+i, eastIslandID);
			rmSetAreaWarnFailure(forestEastID, false);
			rmSetAreaSize(forestEastID, rmAreaTilesToFraction(180), rmAreaTilesToFraction(210));
			rmSetAreaForestType(forestEastID, "Savannah Forest");
			rmSetAreaForestDensity(forestEastID, 0.7);
			rmSetAreaForestClumpiness(forestEastID, 0.6);		
			rmSetAreaForestUnderbrush(forestEastID, 0.6);
			rmSetAreaMinBlobs(forestEastID, 2);
			rmSetAreaMaxBlobs(forestEastID, 10);						
			rmSetAreaMinBlobDistance(forestEastID, 5.0);
			rmSetAreaMaxBlobDistance(forestEastID, 20.0);
			rmSetAreaCoherence(forestEastID, 0.4);
			rmSetAreaSmoothDistance(forestEastID, 10);
			rmAddAreaToClass(forestEastID, rmClassID("classForest"));
			rmAddAreaConstraint(forestEastID, avoidForest);  
			rmAddAreaConstraint(forestEastID, shortAvoidImportantItem);
			rmAddAreaConstraint(forestEastID, playerConstraint);
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

	numTries=6*cNumberNonGaiaPlayers;  
	failCount=0;
	for (i=0; <numTries)
		{   
			int forestRandomID=rmCreateArea("forestRandomID"+i);
			rmSetAreaWarnFailure(forestRandomID, false);
			rmSetAreaSize(forestRandomID, rmAreaTilesToFraction(70), rmAreaTilesToFraction(120));
			rmSetAreaForestType(forestRandomID, "Acacia Forest");
			rmSetAreaForestDensity(forestRandomID, 0.6);
			rmSetAreaForestClumpiness(forestRandomID, 0.5);		
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
		{int capybaraCount =1.5*cNumberNonGaiaPlayers;}
	else
		{capybaraCount =0.80*cNumberNonGaiaPlayers;}

	rmEchoInfo("capybara count = "+capybaraCount);
	
	for (i=0; <capybaraCount)
		{
	int capybaraEastID = rmCreateObjectDef("capybara east herd " +i);
	rmAddObjectDefItem(capybaraEastID, huntable3, rmRandInt(8,10), 13);
	rmSetObjectDefMinDistance(capybaraEastID, 0.0);
	rmSetObjectDefMaxDistance(capybaraEastID, rmXFractionToMeters(0.8));
	rmAddObjectDefConstraint(capybaraEastID, avoidcapybara);
	rmAddObjectDefConstraint(capybaraEastID, avoidarmadillo);
	rmAddObjectDefConstraint(capybaraEastID, avoidAll);
	rmAddObjectDefConstraint(capybaraEastID, avoidNativesFar);
	rmAddObjectDefConstraint(capybaraEastID, avoidCliff);
	rmAddObjectDefConstraint(capybaraEastID, Eastward);
	rmSetObjectDefCreateHerd(capybaraEastID, true);
	
	rmPlaceObjectDefAtLoc(capybaraEastID, 0, 0.5, 0.5);
		}

	for (i=0; <capybaraCount)
		{
	int capybaraWestID = rmCreateObjectDef("capybara west herd " +i);
	rmAddObjectDefItem(capybaraWestID, huntable2, rmRandInt(8,10), 13);
	rmSetObjectDefMinDistance(capybaraWestID, 0.0);
	rmSetObjectDefMaxDistance(capybaraWestID, rmXFractionToMeters(0.8));
	rmAddObjectDefConstraint(capybaraWestID, avoidcapybara);
	rmAddObjectDefConstraint(capybaraWestID, avoidarmadillo);
	rmAddObjectDefConstraint(capybaraWestID, avoidAll);
	rmAddObjectDefConstraint(capybaraWestID, avoidNativesFar);
	rmAddObjectDefConstraint(capybaraWestID, Westward);
	rmSetObjectDefCreateHerd(capybaraWestID, true);
	rmPlaceObjectDefAtLoc(capybaraWestID, 0, 0.5, 0.5);
		}

	rmSetStatusText("",0.90);

			int capybaraRandomID = rmCreateObjectDef("capybara random herd " +i);
			rmAddObjectDefItem(capybaraRandomID, huntable1, rmRandInt(3,6), 11);
			rmSetObjectDefMinDistance(capybaraRandomID, 0.0);
			rmSetObjectDefMaxDistance(capybaraRandomID, rmXFractionToMeters(0.8));
			rmAddObjectDefConstraint(capybaraRandomID, avoidcapybaraFar);
			rmAddObjectDefConstraint(capybaraRandomID, avoidarmadillo);
			rmAddObjectDefConstraint(capybaraRandomID, avoidAll);
			rmAddObjectDefConstraint(capybaraRandomID, avoidNativesFar);
			rmSetObjectDefCreateHerd(capybaraRandomID, true);
			rmPlaceObjectDefAtLoc(capybaraRandomID, 0, 0.5, 0.5);


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

}  
