// Cerrado

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
   int size=2.1*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);
	
	// Picks a default water height
   rmSetSeaLevel(4.0);	// this is height of river surface compared to surrounding land. River depth is in the river XML.

	// Picks default terrain and water
	rmSetBaseTerrainMix("cerrado_grass");
	rmTerrainInitialize("wotta\cerrado\cerrado1", 5);
	rmSetMapType("bayou");
	rmSetMapType("grass");
	rmSetMapType("land");
   rmSetLightingSet("caribbean");

	// Make the corners.
	rmSetWorldCircleConstraint(true);

	// Choose Mercs
	chooseMercs();
	wotta_triggers();

	// Set up Natives
   int whichNative = rmRandInt(1,6);
   int subCiv0 = -1;
   int subCiv1 = -1;
   string nativeName = "";

	if (whichNative < 3)
	{
      subCiv0 = rmGetCivID("Guarani");
      rmEchoInfo("subCiv0 is Guarani "+subCiv0);
      subCiv1 = rmGetCivID("Guarani");
      rmEchoInfo("subCiv1 is Guarani "+subCiv1);
      rmSetSubCiv(0, "Guarani", true);
      rmSetSubCiv(1, "Guarani", true);
      nativeName = "native Guarani village ";
	}
	else if (whichNative == 3)
	{
      subCiv0 = rmGetCivID("Guaicuru");
      rmEchoInfo("subCiv0 is Guaicuru "+subCiv0);
      subCiv1 = rmGetCivID("Guaicuru");
      rmEchoInfo("subCiv1 is Guaicuru "+subCiv1);
      rmSetSubCiv(0, "Guaicuru", true);
      rmSetSubCiv(1, "Guaicuru", true);
      nativeName = "native Guaicuru village ";
   }
   else
   {
      subCiv0 = rmGetCivID("Sertanejo");
      rmEchoInfo("subCiv0 is Sertanejo "+subCiv0);
      subCiv1 = rmGetCivID("Sertanejo");
      rmEchoInfo("subCiv1 is Sertanejo "+subCiv1);
      rmSetSubCiv(0, "Sertanejo", true);
      rmSetSubCiv(1, "Sertanejo", true);
      nativeName = "native Sertanejo village ";
   }

   // Define some classes. These are used later for constraints.
   int classPlayer=rmDefineClass("player");
   rmDefineClass("classHill");
   rmDefineClass("classPatch");
   rmDefineClass("starting settlement");
   rmDefineClass("startingUnit");
   rmDefineClass("classForest");
   rmDefineClass("classForestWild");
   rmDefineClass("importantItem");
   rmDefineClass("natives");
	rmDefineClass("classCliff");
	rmDefineClass("classMountain");
	rmDefineClass("classCity");
	rmDefineClass("classVillage");
   rmDefineClass("center");


	int classCliff = rmDefineClass("Cliffs");

   // -------------Define constraints
   // These are used to have objects and areas avoid each other
   
   // Map edge constraints
   //int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(6), rmZTilesToFraction(6), 1.0-rmXTilesToFraction(6), 1.0-rmZTilesToFraction(6), 0.01);
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.43), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int coinEdgeConstraint=rmCreatePieConstraint("coin edge of map", 0.5, 0.5, rmXFractionToMeters(0.33), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

   // Cardinal Directions

	int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
	int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));
	int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
	int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));
   int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 40.0);

	// Player constraints
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 20.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("stay far away from players", classPlayer, 50.0);
 
   // Nature avoidance
	int avoidForest=rmCreateClassDistanceConstraint("forest avoids forest", rmClassID("classForest"), 10.0);
	int avoidForestFar=rmCreateClassDistanceConstraint("forest avoids forest far", rmClassID("classForest"), 40.0);
//	int avoidaCapybara=rmCreateTypeDistanceConstraint("avoids Capybara", "Capybara", 45.0);
	int avoiddeer=rmCreateTypeDistanceConstraint("avoids deer", "Deer", 45.0);
	int avoidcapybara=rmCreateTypeDistanceConstraint("capybara avoids capybara", "capybara", 45.0);
	int avoidcapybaraFar=rmCreateTypeDistanceConstraint("capybara avoids capybara Far", "capybara", 65.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "mine", 30.0);
	int avoidCoinShort=rmCreateTypeDistanceConstraint("avoid coin short", "mine", 10.0);
	int avoidCoinFar=rmCreateTypeDistanceConstraint("avoid coin far", "mine", 60.0);
   
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
   int avoidVillages=rmCreateClassDistanceConstraint("avoids villages", rmClassID("ClassVillage"), 20.0);




   // Center area
   int centerArea=rmCreateArea("TheCenter");
   rmSetAreaSize(centerArea, 0.2, 0.2);
   rmSetAreaLocation(centerArea, 0.5, 0.5);
   rmAddAreaToClass(centerArea, rmClassID("center")); 




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



   rmBuildAllAreas();



		 // Build the middle desert area.
		int westDesertID = rmCreateArea("west desert");
		rmSetAreaLocation(westDesertID, 0.5, 0.5); 
		rmSetAreaWarnFailure(westDesertID, false);
		rmSetAreaSize(westDesertID, 0.22, 0.22);
		rmSetAreaCoherence(westDesertID, 0.8);
		rmSetAreaSmoothDistance(westDesertID, 8);
		rmSetAreaTerrainType(westDesertID, "props\east_colony");
		rmSetAreaObeyWorldCircleConstraint(westDesertID, false);
		rmAddAreaToClass(westDesertID, rmClassID("ClassCity"));
		rmBuildArea(westDesertID);




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
	   rmSetAreaTerrainType(id, "wotta\cerrado\cerrado1");
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
 
   // Place Natives
      int nativeVillageA = 0;
      int nativeVillageTypeA = rmRandInt(1,3);
      
      nativeVillageA = rmCreateGrouping("Native village A "+i, nativeName+nativeVillageTypeA);
      rmSetGroupingMinDistance(nativeVillageA, 0.0);
      rmSetGroupingMaxDistance(nativeVillageA, 20.0);
      rmAddGroupingConstraint(nativeVillageA, avoidImpassableLand);
      rmAddGroupingToClass(nativeVillageA, rmClassID("natives"));
      rmAddGroupingToClass(nativeVillageA, rmClassID("importantItem"));
      if (cNumberTeams > 2 || teamZeroCount > teamOneCount || teamOneCount > teamZeroCount)
      {
         rmPlaceGroupingAtLoc(nativeVillageA, 0, 0.33, 0.5);
      }
      else
      {
         rmPlaceGroupingAtLoc(nativeVillageA, 0, 0.33, 0.5);
      }

      int nativeVillageB = 0;
      int nativeVillageTypeB = rmRandInt(1,3);

      nativeVillageB = rmCreateGrouping("Native village B "+i, nativeName+nativeVillageTypeB);
      rmSetGroupingMinDistance(nativeVillageB, 0.0);
      rmSetGroupingMaxDistance(nativeVillageB, 20.0);
      rmAddGroupingConstraint(nativeVillageB, avoidImpassableLand);
      rmAddGroupingToClass(nativeVillageB, rmClassID("natives"));
      rmAddGroupingToClass(nativeVillageB, rmClassID("importantItem"));
      if (cNumberTeams > 2 || teamZeroCount > teamOneCount || teamOneCount > teamZeroCount)
      {
         rmPlaceGroupingAtLoc(nativeVillageB, 0, 0.66, 0.5);
      }
      else
      {
         rmPlaceGroupingAtLoc(nativeVillageB, 0, 0.66, 0.5);
      }



	// ********************************************** TRADE ROUTE **************************************************
    // the first in the middle of a city!


   int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 0.0);
	rmSetObjectDefMaxDistance(socketID, 6.0);


	int tradeRouteID = rmCreateTradeRoute();
        int tradeRouteRANDOM = rmRandInt(1,2);

	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
        if (tradeRouteRANDOM > 1)
      {
	rmAddTradeRouteWaypoint(tradeRouteID, 0.25, 1);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.25, 0.25);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.582, 0.25);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.582, 0.416);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.416, 0.416);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.416, 0.582);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.582, 0.582);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.582, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.75, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.75, 0);
      }
      else
      {
	rmAddTradeRouteWaypoint(tradeRouteID, 0.0, .25);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.75, 0.25);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.75, 0.416);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.582, 0.416);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.582, 0.582);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.416, 0.582);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.416, 0.416);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.25, 0.416);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.25, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID, 1, 0.75);
      }



	bool placedTradeRouteA = rmBuildTradeRoute(tradeRouteID, "WOTTAdirt");
	if(placedTradeRouteA == false)
		rmEchoError("Failed to place trade route 1");

	rmPlaceObjectDefAtLoc(socketID, 0, 0.26, 0.74);
	rmPlaceObjectDefAtLoc(socketID, 0, 0.26, 0.26);
	rmPlaceObjectDefAtLoc(socketID, 0, 0.74, 0.26);
	rmPlaceObjectDefAtLoc(socketID, 0, 0.74, 0.74);
	rmPlaceObjectDefAtLoc(socketID, 0, 0.44, 0.44);
	rmPlaceObjectDefAtLoc(socketID, 0, 0.56, 0.56);



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
	rmAddObjectDefItem(playerSilverID, "mine", 1, 0);
	rmAddObjectDefConstraint(playerSilverID, avoidTownCenter);
	rmSetObjectDefMinDistance(playerSilverID, 15.0);
	rmSetObjectDefMaxDistance(playerSilverID, 20.0);
   rmAddObjectDefConstraint(playerSilverID, avoidImpassableLand);
   rmAddObjectDefConstraint(playerSilverID, coinEdgeConstraint);
   
	int playerSilver2ID = rmCreateObjectDef("player mine2");
	rmAddObjectDefItem(playerSilver2ID, "mine", 1, 0);
	rmAddObjectDefConstraint(playerSilver2ID, avoidTownCenter);
	rmSetObjectDefMinDistance(playerSilver2ID, rmXFractionToMeters(0.19));
	rmSetObjectDefMaxDistance(playerSilver2ID, rmXFractionToMeters(0.25));
		rmAddObjectDefConstraint(playerSilver2ID, avoidImpassableLand);
		rmAddObjectDefConstraint(playerSilver2ID, avoidCoin);
		rmAddObjectDefConstraint(playerSilver2ID, playerConstraint);
		rmAddObjectDefConstraint(playerSilver2ID, avoidForest);
		rmAddObjectDefConstraint(playerSilver2ID, avoidTradeRoute);
		rmAddObjectDefConstraint(playerSilver2ID, avoidVillages);
		rmAddObjectDefConstraint(playerSilver2ID, avoidAll);
   rmAddObjectDefConstraint(playerSilver2ID, coinEdgeConstraint);

	int playerSilver3ID = rmCreateObjectDef("player mine3");
	rmAddObjectDefItem(playerSilver3ID, "mine", 1, 0);
	rmAddObjectDefConstraint(playerSilver3ID, avoidTownCenter);
	rmSetObjectDefMinDistance(playerSilver3ID, rmXFractionToMeters(0.34));
	rmSetObjectDefMaxDistance(playerSilver3ID, rmXFractionToMeters(0.38));
		rmAddObjectDefConstraint(playerSilver3ID, avoidImpassableLand);
		rmAddObjectDefConstraint(playerSilver3ID, avoidCoin);
		rmAddObjectDefConstraint(playerSilver3ID, playerConstraint);
		rmAddObjectDefConstraint(playerSilver3ID, avoidForest);
		rmAddObjectDefConstraint(playerSilver3ID, avoidTradeRoute);
		rmAddObjectDefConstraint(playerSilver3ID, avoidVillages);
		rmAddObjectDefConstraint(playerSilver3ID, avoidAll);
   rmAddObjectDefConstraint(playerSilver3ID, coinEdgeConstraint);

	int playerCapybaraID=rmCreateObjectDef("player Capybara");
   rmAddObjectDefItem(playerCapybaraID, "Capybara", rmRandInt(8,10), 10.0);
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

	int playerBerryID = rmCreateObjectDef("player berries");
   rmAddObjectDefItem(playerBerryID, "jabuticababush", rmRandInt(5,6), 8.0);
   rmSetObjectDefMinDistance(playerBerryID, 15);
   rmSetObjectDefMaxDistance(playerBerryID, 20);
   rmAddObjectDefConstraint(playerBerryID, avoidAll);
   rmAddObjectDefConstraint(playerBerryID, avoidImpassableLand);

	int avoidAbandoned=rmCreateTypeDistanceConstraint("avoid abandoned", "PYabandonedbuilding", 3.0);
	int avoidAbandonedLong=rmCreateTypeDistanceConstraint("avoid abandoned long", "PYabandonedbuilding", 40.0);

	int playerAbandonedID = rmCreateObjectDef("Abandoned Buildings");
   rmAddObjectDefItem(playerAbandonedID, "PYabandonedbuilding", 1, 8.0);
   rmSetObjectDefMinDistance(playerAbandonedID, 15);
   rmSetObjectDefMaxDistance(playerAbandonedID, rmXFractionToMeters(0.3));
   rmAddObjectDefConstraint(playerAbandonedID, avoidAll);
   rmAddObjectDefConstraint(playerAbandonedID, avoidImpassableLand);
   rmAddObjectDefConstraint(playerAbandonedID, avoidAbandoned);
   rmAddObjectDefConstraint(playerAbandonedID, avoidVillages);
   rmAddObjectDefConstraint(playerAbandonedID, avoidAbandonedLong);
   rmPlaceObjectDefAtLoc(playerAbandonedID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);


	int playerTreeID = rmCreateObjectDef("player trees");
   rmAddObjectDefItem(playerTreeID, "TreeCerrado", rmRandInt(5,10), 8.0);
   rmSetObjectDefMinDistance(playerTreeID, 15);
   rmSetObjectDefMaxDistance(playerTreeID, 20);
   rmAddObjectDefConstraint(playerTreeID, avoidAll);
   rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);


	for(i = 1; < cNumberPlayers)
   {
	rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
	rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerBerryID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerCapybaraID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerSilver2ID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerSilver3ID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
   rmClearClosestPointConstraints();
   }

	// Text
	rmSetStatusText("",0.60);

//more hunt

	for(i=0; <  2*cNumberNonGaiaPlayers + 2)
	{
	int guazupucuID=rmCreateObjectDef("guazu pucu" + i);
	rmAddObjectDefItem(guazupucuID, "Deer", rmRandInt(8,10), 10.0);
	rmSetObjectDefMinDistance(guazupucuID, rmXFractionToMeters(0.38));
	rmSetObjectDefMaxDistance(guazupucuID, rmXFractionToMeters(0.49));
	rmAddObjectDefConstraint(guazupucuID, avoidAll);
	rmAddObjectDefConstraint(guazupucuID, avoidImpassableLand);
	rmAddObjectDefConstraint(guazupucuID, avoidCliff);
	rmAddObjectDefConstraint(guazupucuID, avoiddeer);
	rmAddObjectDefConstraint(guazupucuID, avoidcapybaraFar);
   rmAddObjectDefConstraint(guazupucuID, avoidAbandoned);
	rmSetObjectDefCreateHerd(guazupucuID, true);
	rmPlaceObjectDefAtLoc(guazupucuID, 0, 0.5, 0.5);
	}

	// SCENARIO DESIGNED VILLAGES

   int secondEdgeConstraint=rmCreateBoxConstraint("avoid edge of map", rmXTilesToFraction(50), rmZTilesToFraction(50), 1.0-rmXTilesToFraction(50), 1.0-rmZTilesToFraction(50), 0.01);

	int VillageType = -1;
	int VillageID = -1;
	int VillageCount = cNumberNonGaiaPlayers*3;	
	rmEchoInfo("Village count = "+VillageCount);

	for(i=0; < VillageCount)
	{
		VillageType = rmRandInt(1,4);
      VillageID = rmCreateGrouping("village "+i, "PY village "+VillageType);
      rmSetGroupingMinDistance(VillageID, 0.0);
      rmSetGroupingMaxDistance(VillageID, rmXFractionToMeters(0.5));
		rmAddGroupingToClass(VillageID, rmClassID("ClassVillage"));
		rmAddGroupingConstraint(VillageID, avoidTradeRoute);
		rmAddGroupingConstraint(VillageID, avoidVillages);
		rmAddGroupingConstraint(VillageID, avoidAll);
		rmAddGroupingConstraint(VillageID, secondEdgeConstraint);
		rmPlaceGroupingAtLoc(VillageID, 0, 0.5, 0.5);
   }



	   // FORESTS WITH BUILDINGS
   int forestTreeID = 0;
   int numTries1=3*cNumberNonGaiaPlayers;
   int failCount1=0;
   for (i=0; <numTries1)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(200), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest, "Urban Neighborhood");
         rmSetAreaForestDensity(forest, 0.8);
         rmSetAreaForestClumpiness(forest, 0.0);
         rmSetAreaForestUnderbrush(forest, 0.0);
         rmSetAreaMinBlobs(forest, 1);
         rmSetAreaMaxBlobs(forest, 4);
         rmSetAreaMinBlobDistance(forest, 16.0);
         rmSetAreaMaxBlobDistance(forest, 20.0);
         rmSetAreaCoherence(forest, 0.4);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
         rmAddAreaConstraint(forest, avoidAll);
         rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
         rmAddAreaConstraint(forest, avoidTradeRoute);
         rmAddAreaConstraint(forest, secondEdgeConstraint);
         if(rmBuildArea(forest)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount1++;
            if(failCount1==5)
               break;
         }
         else
            failCount1=0; 
      } 


	   // FORESTS PURE

	int avoidForestWild=rmCreateClassDistanceConstraint("forest avoids forest very far", rmClassID("classForestWild"), 50.0);


   int forestTree2ID = 0;
   int numTries2=5*cNumberNonGaiaPlayers;
   int failCount2=0;
   for (i=0; <numTries2)
      {   
         int forest2=rmCreateArea("forest2 "+i);
         rmSetAreaWarnFailure(forest2, false);
         rmSetAreaSize(forest2, rmAreaTilesToFraction(200), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest2, "Cerrado Forest");
         rmSetAreaForestDensity(forest2, 0.8);
         rmSetAreaForestClumpiness(forest2, 0.0);
         rmSetAreaForestUnderbrush(forest2, 0.0);
         rmSetAreaMinBlobs(forest2, 2);
         rmSetAreaMaxBlobs(forest2, 6);
         rmSetAreaMinBlobDistance(forest2, 16.0);
         rmSetAreaMaxBlobDistance(forest2, 20.0);
         rmSetAreaCoherence(forest2, 0.4);
         rmSetAreaSmoothDistance(forest2, 10);
         rmAddAreaToClass(forest2, rmClassID("classForestWild")); 
         rmAddAreaConstraint(forest2, avoidAll);
         rmAddAreaConstraint(forest2, avoidCoinShort);
         rmAddAreaConstraint(forest2, shortAvoidImpassableLand); 
         rmAddAreaConstraint(forest2, avoidTradeRoute);
         rmAddAreaConstraint(forest2, avoidForestWild);
         if(rmBuildArea(forest2)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount2++;
            if(failCount2==5)
               break;
         }
         else
            failCount2=0; 
      } 



	// COIN RESOURCES OBSOLET
/*
	int silverType = rmRandInt(1,10);
	int silverID = -1;
	int silverCount = cNumberNonGaiaPlayers*2;	
	rmEchoInfo("silver count = "+silverCount);

	for(i=0; < silverCount)
	{
		silverID = rmCreateObjectDef("silver"+i);
		rmAddObjectDefItem(silverID, "mine", 1, 0);
		rmSetObjectDefMinDistance(silverID, 0.0);
		rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(silverID, avoidImpassableLand);
		rmAddObjectDefConstraint(silverID, avoidCoin);
		rmAddObjectDefConstraint(silverID, playerConstraint);
		rmAddObjectDefConstraint(silverID, avoidForest);
		rmAddObjectDefConstraint(silverID, avoidTradeRoute);
		rmAddObjectDefConstraint(silverID, avoidVillages);
		rmAddObjectDefConstraint(silverID, avoidAll);
		rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);

	}
*/

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
  	rmAddObjectDefConstraint(nuggethardID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(nuggethardID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);




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
