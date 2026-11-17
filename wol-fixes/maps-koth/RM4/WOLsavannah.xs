// GREAT PLAINS LARGE

include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";

// Main entry point for random map script
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
   int subCiv4=-1;
   int subCiv5=-1;

	// Choose which variation to use.  1=southeast trade route, 2=northwest trade route
	int whichMap=rmRandInt(1,2);
	// int whichMap=2;

	// Are there extra meeting poles?
	int extraPoles=rmRandInt(1,2);
	extraPoles=1;
	// int extraPoles=2;

   if (rmAllocateSubCivs(6) == true)
   {
		subCiv0=rmGetCivID("AURIvory");
		rmEchoInfo("subCiv0 is Comanche "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "AURIvory");

		subCiv1=rmGetCivID("AURCattle");
		rmEchoInfo("subCiv1 is Cheyenne "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "AURCattle");

		subCiv2=rmGetCivID("AURDiamonds");
		rmEchoInfo("subCiv2 is Cheyenne "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "AURDiamonds");
		
		subCiv3=rmGetCivID("AURManioc");
		rmEchoInfo("subCiv3 is Comanche "+subCiv3);
		if (subCiv3 >= 0)
			rmSetSubCiv(3, "AURManioc");
		
		subCiv4=rmGetCivID("AURSlaves");
		rmEchoInfo("subCiv4 is Comanche "+subCiv4);
		if (subCiv4 >= 0)
			rmSetSubCiv(4, "AURSlaves");
		
		subCiv5=rmGetCivID("AURGold");
		rmEchoInfo("subCiv5 is Cheyenne "+subCiv5);
		if (subCiv5 >= 0)
			rmSetSubCiv(5, "AURGold");
   }

   // Picks the map size
	int playerTiles=21000;
   if (cNumberNonGaiaPlayers >4)
		playerTiles = 20000;
   if (cNumberNonGaiaPlayers >6)
      playerTiles = 17000;

	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Picks a default water height
	rmSetSeaLevel(0.0);

    // Picks default terrain and water
	rmSetMapElevationParameters(cElevTurbulence, 0.02, 7, 0.5, 8.0);
	rmSetBaseTerrainMix("great plains drygrass");
	rmTerrainInitialize("Deccan\ground_grass2_deccan", 5);
   rmSetMapType("AFRICANsavannah");
   rmSetMapType("africa");
	rmSetMapType("grass");
	rmSetMapType("rainclouds");
	rmSetMapType("land");
   rmSetLightingSet("seville morning");

wotta_triggers();

	// Define some classes. These are used later for constraints.
	int classPlayer=rmDefineClass("player");
	rmDefineClass("classPatch");
	rmDefineClass("starting settlement");
	rmDefineClass("startingUnit");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("secrets");
	rmDefineClass("natives");	
	rmDefineClass("classHillArea");
	rmDefineClass("socketClass");
	rmDefineClass("nuggets");

   // -------------Define constraints
   // These are used to have objects and areas avoid each other
   
   // Map edge constraints
   int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(6), rmZTilesToFraction(6), 1.0-rmXTilesToFraction(6), 1.0-rmZTilesToFraction(6), 0.01);

   // Player constraints
   int playerConstraint=rmCreateClassDistanceConstraint("player vs. player", classPlayer, 10.0);
   int smallMapPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 70.0);
   int nuggetPlayerConstraint=rmCreateClassDistanceConstraint("nuggets stay away from players a lot", classPlayer, 40.0);

   // Resource avoidance
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 25.0);
   int coinForestConstraint=rmCreateClassDistanceConstraint("coin vs. forest", rmClassID("classForest"), 15.0);
   int avoidBison=rmCreateTypeDistanceConstraint("bison avoids food", "bison", 40.0);
   int avoidPronghorn=rmCreateTypeDistanceConstraint("pronghorn avoids food", "pronghorn", 35.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("coin avoids coin", "gold", 35.0);
	int avoidStartingCoin=rmCreateTypeDistanceConstraint("starting coin avoids coin", "gold", 22.0);
   int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 40.0);
   int avoidNuggetSmall=rmCreateTypeDistanceConstraint("avoid nuggets by a little", "AbstractNugget", 10.0);

	int avoidFastCoin=-1;
	if (cNumberNonGaiaPlayers >6)
	{
		avoidFastCoin=rmCreateTypeDistanceConstraint("fast coin avoids coin", "gold", rmXFractionToMeters(0.12));
	}
	else if (cNumberNonGaiaPlayers >4)
	{
		avoidFastCoin=rmCreateTypeDistanceConstraint("fast coin avoids coin", "gold", rmXFractionToMeters(0.14));
	}
	else
	{
		avoidFastCoin=rmCreateTypeDistanceConstraint("fast coin avoids coin", "gold", rmXFractionToMeters(0.16));
	}

   // Avoid impassable land
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 6.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
   int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 5.0);

   // Unit avoidance - for things that aren't in the starting resources.
   int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 30.0);
   int avoidStartingUnitsSmall=rmCreateClassDistanceConstraint("objects avoid starting units small", rmClassID("startingUnit"), 5.0);

   // Decoration avoidance
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

   // VP avoidance
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
   int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("trade route small", 4.0);
   // int avoidTradeRoutePlayer = rmCreateTradeRouteDistanceConstraint("trade route player", 30.0);
   int avoidImportantItem=rmCreateClassDistanceConstraint("important stuff avoids each other", rmClassID("importantItem"), 15.0);

	int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 8.0);
	int avoidSocketMore=rmCreateClassDistanceConstraint("bigger socket avoidance", rmClassID("socketClass"), 15.0);

   // Constraint to avoid water.
   int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water", "Land", false, 4.0);
   int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
   int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 40.0);

	// Avoid the hilly areas.
	int avoidHills = rmCreateClassDistanceConstraint("avoid Hills", rmClassID("classHillArea"), 5.0);
	
	// natives avoid natives
	int avoidNatives = rmCreateClassDistanceConstraint("avoid Natives", rmClassID("natives"), 40.0);
	int avoidNativesNuggets = rmCreateClassDistanceConstraint("nuggets avoid Natives", rmClassID("natives"), 20.0);

	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));

   // Text
   rmSetStatusText("",0.10);
	
   // TRADE ROUTE PLACEMENT
   int tradeRouteID = rmCreateTradeRoute();

   int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
   rmAddObjectDefToClass(socketID, rmClassID("socketClass"));
   rmSetObjectDefMinDistance(socketID, 0.0);
   rmSetObjectDefMaxDistance(socketID, 8.0);

	if ( whichMap == 1 )
	{
		rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.6);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.2, 0.25, 10, 4);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.5, 0.2, 10, 4);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.8, 0.25, 10, 4);
	}
	else
	{
		rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.4);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.2, 0.75, 10, 4);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.5, 0.8, 10, 4);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.8, 0.75, 10, 4);
	}

	rmAddRandomTradeRouteWaypoints(tradeRouteID, 1.0, 0.5, 20, 4);

   bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "SavannahTrade1");
   if(placedTradeRoute == false)
      rmEchoError("Failed to place trade route"); 
  
	// add the sockets along the trade route.
   vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.1);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.9);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

	if ( extraPoles > 1 )
	{
	   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.35);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

		socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.65);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
      
   // DEFINE AREAS
   // Set up player starting locations.
   if ( whichMap == 1 )
   {
	   rmSetPlacementSection(0.7, 0.3); // 0.5
   }
   else
   {
	   rmSetPlacementSection(0.2, 0.8); // 0.5	   	
   }
   rmSetTeamSpacingModifier(0.7);
   rmPlacePlayersCircular(0.38, 0.38, 0);

	/*
	// Place the first team.
   rmSetPlacementTeam(0);
	if ( whichMap == 1 ) // se trade route
	{
		rmSetPlayerPlacementArea(0.7, 0.5, 0.9, 0.8);
	}
	else
	{
		rmSetPlayerPlacementArea(0.7, 0.2, 0.9, 0.5);
	}
   rmPlacePlayersCircular(0.3, 0.4, rmDegreesToRadians(5.0));

	// Now place Second Team
   rmSetPlacementTeam(1);
   	if ( whichMap == 1 ) // nw trade route
	{
		rmSetPlayerPlacementArea(0.1, 0.5, 0.3, 0.8);
	}
	else
	{
		rmSetPlayerPlacementArea(0.1, 0.2, 0.3, 0.5);
	}
   rmPlacePlayersCircular(0.3, 0.4, rmDegreesToRadians(5.0));
   */

	//	rmPlacePlayersCircular(0.45, 0.45, rmDegreesToRadians(5.0));

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
	  rmAddAreaConstraint(id, avoidTradeRoute); 
      rmSetAreaLocPlayer(id, i);
      rmSetAreaWarnFailure(id, false);
   }

	int numTries = -1;
	int failCount = -1;

	// Text
   rmSetStatusText("",0.20);
   
        // choose African Savannah Huntables
    int AfricanHuntableArray = xsArrayCreateString(8, "", "");

    xsArraySetString(AfricanHuntableArray, 1, "ypWildElephant");
    xsArraySetString(AfricanHuntableArray, 2, "Gazelle");
    xsArraySetString(AfricanHuntableArray, 3, "Ostrich");
    xsArraySetString(AfricanHuntableArray, 4, "Oryx");
    xsArraySetString(AfricanHuntableArray, 5, "Zebra");
    xsArraySetString(AfricanHuntableArray, 6, "Antelope");
    xsArraySetString(AfricanHuntableArray, 7, "Gnu");
	xsArraySetString(AfricanHuntableArray, 8, "CrownedCrane");

  string huntable1 = xsArrayGetString(AfricanHuntableArray, rmRandInt(2, 8));
  string huntable2 = xsArrayGetString(AfricanHuntableArray, rmRandInt(3, 8));
  string huntable3 = xsArrayGetString(AfricanHuntableArray, rmRandInt(1, 8));
  string huntable4 = xsArrayGetString(AfricanHuntableArray, rmRandInt(1, 8));

	// Two hilly areas
   int hillNorthwestID=rmCreateArea("northwest hills");
   int avoidNW = rmCreateAreaDistanceConstraint("avoid nw", hillNorthwestID, 3.0);

   rmSetAreaSize(hillNorthwestID, 0.2, 0.2);
   rmSetAreaWarnFailure(hillNorthwestID, false);
   rmSetAreaSmoothDistance(hillNorthwestID, 10);
	rmSetAreaMix(hillNorthwestID, "great plains grass");
	rmAddAreaTerrainLayer(hillNorthwestID, "great_plains\ground8_gp", 0, 4);
   rmAddAreaTerrainLayer(hillNorthwestID, "great_plains\ground1_gp", 4, 10);
   rmSetAreaElevationType(hillNorthwestID, cElevTurbulence);
   rmSetAreaElevationVariation(hillNorthwestID, 6.0);
   rmSetAreaBaseHeight(hillNorthwestID, 5);
   rmSetAreaElevationMinFrequency(hillNorthwestID, 0.05);
   rmSetAreaElevationOctaves(hillNorthwestID, 3);
   rmSetAreaElevationPersistence(hillNorthwestID, 0.3);      
   rmSetAreaElevationNoiseBias(hillNorthwestID, 0.5);
   rmSetAreaElevationEdgeFalloffDist(hillNorthwestID, 20.0);
	rmSetAreaCoherence(hillNorthwestID, 0.9);
	rmSetAreaLocation(hillNorthwestID, 0.5, 0.9);
   rmSetAreaEdgeFilling(hillNorthwestID, 5);
	rmAddAreaInfluenceSegment(hillNorthwestID, 0.1, 0.95, 0.9, 0.95);
	rmSetAreaHeightBlend(hillNorthwestID, 1);
	rmSetAreaObeyWorldCircleConstraint(hillNorthwestID, false);
	rmAddAreaToClass(hillNorthwestID, rmClassID("classHillArea"));
	rmBuildArea(hillNorthwestID);

   int hillSoutheastID=rmCreateArea("southeast hills");
   int avoidSE = rmCreateAreaDistanceConstraint("avoid se", hillSoutheastID, 3.0);

   rmSetAreaSize(hillSoutheastID, 0.2, 0.2);
   rmSetAreaWarnFailure(hillSoutheastID, false);
   rmSetAreaSmoothDistance(hillSoutheastID, 10);
	rmSetAreaMix(hillSoutheastID, "great plains grass");
	rmAddAreaTerrainLayer(hillSoutheastID, "great_plains\ground8_gp", 0, 4);
   rmAddAreaTerrainLayer(hillSoutheastID, "great_plains\ground1_gp", 4, 10);
   rmSetAreaElevationType(hillSoutheastID, cElevTurbulence);
   rmSetAreaElevationVariation(hillSoutheastID, 6.0);
   rmSetAreaBaseHeight(hillSoutheastID, 5);
   rmSetAreaElevationMinFrequency(hillSoutheastID, 0.05);
   rmSetAreaElevationOctaves(hillSoutheastID, 3);
   rmSetAreaElevationPersistence(hillSoutheastID, 0.3);
   rmSetAreaElevationNoiseBias(hillSoutheastID, 0.5);
   rmSetAreaElevationEdgeFalloffDist(hillSoutheastID, 20.0);
	rmSetAreaCoherence(hillSoutheastID, 0.9);
	rmSetAreaLocation(hillSoutheastID, 0.5, 0.1);
   rmSetAreaEdgeFilling(hillSoutheastID, 5);
	rmAddAreaInfluenceSegment(hillSoutheastID, 0.1, 0.05, 0.9, 0.05);
	rmSetAreaHeightBlend(hillSoutheastID, 1);
	rmSetAreaObeyWorldCircleConstraint(hillSoutheastID, false);
	rmAddAreaToClass(hillSoutheastID, rmClassID("classHillArea"));
	rmBuildArea(hillSoutheastID);

   // Build the areas.
   // rmBuildAllAreas();

   // Text
   rmSetStatusText("",0.30);

   // Placement order of non-trade route stuff
   // Natives -> Secrets -> Nuggets -> Small Ponds (whee)


    //STARTING UNITS and RESOURCES DEFS
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 7.0);
	rmSetObjectDefMaxDistance(startingUnits, 12.0);

	int startingTCID = rmCreateObjectDef("startingTC");
	if ( rmGetNomadStart())
	{
		rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 0.0);
	}
	else
	{
		rmAddObjectDefItem(startingTCID, "TownCenter", 1, 0.0);
	}
	rmAddObjectDefToClass(startingTCID, rmClassID("startingUnit"));
	rmSetObjectDefMinDistance(startingTCID, 0.0);
	rmSetObjectDefMaxDistance(startingTCID, 9.0);
	rmAddObjectDefConstraint(startingTCID, avoidTradeRouteSmall);

	// rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);

	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "TreeAcacia", 1, 0.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 12.0);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 18.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartingUnitsSmall);

	int StartBisonID=rmCreateObjectDef("starting bison");
	rmAddObjectDefItem(StartBisonID, huntable1, 7, 4.0);
	rmSetObjectDefMinDistance(StartBisonID, 10.0);
	rmSetObjectDefMaxDistance(StartBisonID, 12.0);
	rmSetObjectDefCreateHerd(StartBisonID, true);
	rmAddObjectDefConstraint(StartBisonID, avoidStartingUnitsSmall);

	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
	rmAddObjectDefToClass(playerNuggetID, rmClassID("nuggets"));
	rmAddObjectDefToClass(playerNuggetID, rmClassID("startingUnit"));
    rmSetObjectDefMinDistance(playerNuggetID, 28.0);
    rmSetObjectDefMaxDistance(playerNuggetID, 35.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidNugget);
	rmAddObjectDefConstraint(playerNuggetID, avoidNativesNuggets);
	rmAddObjectDefConstraint(playerNuggetID, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(playerNuggetID, circleConstraint);
	// rmAddObjectDefConstraint(playerNuggetID, avoidImportantItem);

	rmSetStatusText("",0.40);
	
	int silverType = -1;
	int playerGoldID = -1;

 	for(i=1; <cNumberPlayers)
	{
		rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		// vector closestPoint=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingUnits, i));
		// rmSetHomeCityGatherPoint(i, closestPoint);

		// Everyone gets two ore ObjectDefs, one pretty close, the other a little further away.
		silverType = rmRandInt(1,10);
		playerGoldID = rmCreateObjectDef("player silver closer "+i);
		rmAddObjectDefItem(playerGoldID, "mine", 1, 0.0);
		// rmAddObjectDefToClass(playerGoldID, rmClassID("importantItem"));
		rmAddObjectDefConstraint(playerGoldID, avoidTradeRoute);
		rmAddObjectDefConstraint(playerGoldID, avoidStartingCoin);
		rmAddObjectDefConstraint(playerGoldID, avoidStartingUnitsSmall);
		rmSetObjectDefMinDistance(playerGoldID, 15.0);
		rmSetObjectDefMaxDistance(playerGoldID, 20.0);
		
		// Place two gold mines
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		// Placing starting trees...
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		rmPlaceObjectDefAtLoc(StartBisonID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		rmSetNuggetDifficulty(1, 1);
		rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	}

	// NATIVE AMERICANS
   float NativeVillageLoc = rmRandFloat(0,1); //

   if (subCiv0 == rmGetCivID("AURIvory"))
   {  
      int comancheVillageAID = -1;
      int comancheVillageType = rmRandInt(1,3);
      comancheVillageAID = rmCreateGrouping("comanche village A", "AURivory timbuktu "+rmRandInt(1,3));
      rmSetGroupingMinDistance(comancheVillageAID, 0.0);
      rmSetGroupingMaxDistance(comancheVillageAID, rmXFractionToMeters(0.1));
      rmAddGroupingConstraint(comancheVillageAID, avoidImpassableLand);
      rmAddGroupingToClass(comancheVillageAID, rmClassID("importantItem"));
      rmAddGroupingToClass(comancheVillageAID, rmClassID("natives"));
      rmAddGroupingConstraint(comancheVillageAID, avoidNatives);
      rmAddGroupingConstraint(comancheVillageAID, avoidTradeRoute);
	  rmAddGroupingConstraint(comancheVillageAID, avoidStartingUnits);
		if ( whichMap == 1 )
		{
			rmPlaceGroupingAtLoc(comancheVillageAID, 0, 0.5, 0.5);
		}
		else
		{
			rmPlaceGroupingAtLoc(comancheVillageAID, 0, 0.35, 0.15);
		}
	}

   if (subCiv1 == rmGetCivID("AURCattle"))
   {   
      int cheyenneVillageAID = -1;
      int cheyenneVillageType = rmRandInt(1,3);
      cheyenneVillageAID = rmCreateGrouping("cheyenne village A", "AURcattle tribal "+rmRandInt(1,3));
      rmSetGroupingMinDistance(cheyenneVillageAID, 0.0);
      rmSetGroupingMaxDistance(cheyenneVillageAID, rmXFractionToMeters(0.1));
      rmAddGroupingConstraint(cheyenneVillageAID, avoidImpassableLand);
      rmAddGroupingToClass(cheyenneVillageAID, rmClassID("importantItem"));
      rmAddGroupingToClass(cheyenneVillageAID, rmClassID("natives"));
      rmAddGroupingConstraint(cheyenneVillageAID, avoidNatives);
      rmAddGroupingConstraint(cheyenneVillageAID, avoidTradeRoute);
	  rmAddGroupingConstraint(cheyenneVillageAID, avoidStartingUnits);
		if ( whichMap == 1 )
		{
			rmPlaceGroupingAtLoc(cheyenneVillageAID, 0, 0.7, 0.6); 
		}
		else
		{
			rmPlaceGroupingAtLoc(cheyenneVillageAID, 0, 0.65, 0.15); 
		}
	}

   // Text
   rmSetStatusText("",0.50);
	if(subCiv2 == rmGetCivID("AURDiamonds"))
   {   
      int cheyenneVillageID = -1;
      cheyenneVillageType = rmRandInt(1,3);
      cheyenneVillageID = rmCreateGrouping("cheyenne village", "AURdiamonds tribal "+rmRandInt(1,3));
      rmSetGroupingMinDistance(cheyenneVillageID, 0.0);
      rmSetGroupingMaxDistance(cheyenneVillageID, rmXFractionToMeters(0.1));
      rmAddGroupingConstraint(cheyenneVillageID, avoidImpassableLand);
      rmAddGroupingToClass(cheyenneVillageID, rmClassID("importantItem"));
      rmAddGroupingToClass(cheyenneVillageID, rmClassID("natives"));
      rmAddGroupingConstraint(cheyenneVillageID, avoidNatives);
		rmAddGroupingConstraint(cheyenneVillageID, avoidTradeRoute);
		rmAddGroupingConstraint(cheyenneVillageID, avoidStartingUnits);
		if ( extraPoles == 1 )
		{
			if ( whichMap == 1 )
			{
				rmPlaceGroupingAtLoc(cheyenneVillageID, 0, 0.2, 0.8);
			}
			else
			{
				rmPlaceGroupingAtLoc(cheyenneVillageID, 0, 0.15, 0.85);
			}
		}
   }

	if(subCiv3 == rmGetCivID("AURmanioc"))
   {   
      int comancheVillageBID = -1;
      comancheVillageType = rmRandInt(1,3);
      comancheVillageBID = rmCreateGrouping("comanche village B", "AURmanioc tribal "+rmRandInt(1,3));
      rmSetGroupingMinDistance(comancheVillageBID, 0.0);
      rmSetGroupingMaxDistance(comancheVillageBID, rmXFractionToMeters(0.1));
      rmAddGroupingConstraint(comancheVillageBID, avoidImpassableLand);
      rmAddGroupingToClass(comancheVillageBID, rmClassID("importantItem"));
      rmAddGroupingToClass(comancheVillageBID, rmClassID("natives"));
      rmAddGroupingConstraint(comancheVillageBID, avoidNatives);
	  rmAddGroupingConstraint(comancheVillageBID, avoidTradeRoute);
	  rmAddGroupingConstraint(comancheVillageBID, avoidStartingUnits);
		if ( whichMap == 1 )
		{
			rmPlaceGroupingAtLoc(comancheVillageBID, 0, 0.3, 0.6);
		}
		else
		{
			rmPlaceGroupingAtLoc(comancheVillageBID, 0, 0.35, 0.45);
		}
   }

	if(subCiv4 == rmGetCivID("AURslaves"))
   {
      int comancheVillageID = -1;
      comancheVillageType = rmRandInt(1,3);
      comancheVillageID = rmCreateGrouping("comanche village", "AURslaves tribal "+rmRandInt(1,3));
      rmSetGroupingMinDistance(comancheVillageID, 0.0);
	  rmSetGroupingMaxDistance(comancheVillageID, rmXFractionToMeters(0.1));
      rmAddGroupingConstraint(comancheVillageID, avoidImpassableLand);
      rmAddGroupingToClass(comancheVillageID, rmClassID("importantItem"));
      rmAddGroupingToClass(comancheVillageID, rmClassID("natives"));
      rmAddGroupingConstraint(comancheVillageID, avoidNatives);
      rmAddGroupingConstraint(comancheVillageID, avoidTradeRoute);
	  rmAddGroupingConstraint(comancheVillageID, avoidStartingUnits);
		if ( extraPoles == 1 )
		{
			if ( whichMap == 1 )
			{
				rmPlaceGroupingAtLoc(comancheVillageID, 0, 0.8, 0.8);
			}
			else
			{
				rmPlaceGroupingAtLoc(comancheVillageID, 0, 0.85, 0.85);
			}
		}
	
	}

   if (subCiv5 == rmGetCivID("AURGold"))
   {   
      int cheyenneVillageBID = -1;
      cheyenneVillageType = rmRandInt(1,3);
      cheyenneVillageBID = rmCreateGrouping("cheyenne village B", "AURgold tribal "+rmRandInt(1,3));
      rmSetGroupingMinDistance(cheyenneVillageBID, 0.0);
      rmSetGroupingMaxDistance(cheyenneVillageBID, rmXFractionToMeters(0.1));
      rmAddGroupingConstraint(cheyenneVillageBID, avoidImpassableLand);
      rmAddGroupingToClass(cheyenneVillageBID, rmClassID("importantItem"));
      rmAddGroupingToClass(cheyenneVillageBID, rmClassID("natives"));
      rmAddGroupingConstraint(cheyenneVillageBID, avoidNatives);
      rmAddGroupingConstraint(cheyenneVillageBID, avoidTradeRoute);
	  rmAddGroupingConstraint(cheyenneVillageBID, avoidStartingUnits);

		if ( whichMap == 1 )
		{
			rmPlaceGroupingAtLoc(cheyenneVillageBID, 0, 0.5, 0.9);
		}
		else
		{
			rmPlaceGroupingAtLoc(cheyenneVillageBID, 0, 0.65, 0.45);
		}
   }

   // Text
   rmSetStatusText("",0.60);

   // Define and place Nuggets
	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetID, 0.0);
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nuggetID, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nuggetID, avoidNugget);
	rmAddObjectDefConstraint(nuggetID, nuggetPlayerConstraint);
  	rmAddObjectDefConstraint(nuggetID, playerConstraint);
  	rmAddObjectDefConstraint(nuggetID, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetID, avoidSocketMore);
	rmAddObjectDefConstraint(nuggetID, avoidNativesNuggets);
	rmAddObjectDefConstraint(nuggetID, circleConstraint);
  	rmAddObjectDefConstraint(nuggetID, avoidAll);
	rmSetNuggetDifficulty(1, 3);
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*4);
   
   // Text
   rmSetStatusText("",0.70); 

	// Ponds o' Fun
	int pondClass=rmDefineClass("pond");
   int pondConstraint=rmCreateClassDistanceConstraint("ponds avoid ponds", rmClassID("pond"), 60.0);

   // int numPonds=rmRandInt(1,4);
	int numPonds=4;
   for(i=0; <numPonds)
   {
      int smallPondID=rmCreateArea("small pond"+i);
      rmSetAreaSize(smallPondID, rmAreaTilesToFraction(170), rmAreaTilesToFraction(200));
      rmSetAreaWaterType(smallPondID, "Savannah");
      rmSetAreaBaseHeight(smallPondID, 4);
      rmSetAreaMinBlobs(smallPondID, 1);
      rmSetAreaMaxBlobs(smallPondID, 5);
      rmSetAreaMinBlobDistance(smallPondID, 5.0);
      rmSetAreaMaxBlobDistance(smallPondID, 70.0);
      rmAddAreaToClass(smallPondID, pondClass);
      rmSetAreaCoherence(smallPondID, 0.5);
      rmSetAreaSmoothDistance(smallPondID, 5);
      rmAddAreaConstraint(smallPondID, pondConstraint);
      rmAddAreaConstraint(smallPondID, playerConstraint);
      rmAddAreaConstraint(smallPondID, avoidTradeRoute);
		rmAddAreaConstraint(smallPondID, avoidSocket);
		rmAddAreaConstraint(smallPondID, avoidImportantItem);
		rmAddAreaConstraint(smallPondID, avoidNW);
		rmAddAreaConstraint(smallPondID, avoidSE);
		rmAddAreaConstraint(smallPondID, avoidStartingUnits);
		rmAddAreaConstraint(smallPondID, avoidNuggetSmall);
      rmSetAreaWarnFailure(smallPondID, false);
      rmBuildArea(smallPondID);
   }

	// Build grassy areas everywhere.  Whee!
	numTries=6*cNumberNonGaiaPlayers;
	failCount=0;
	for (i=0; <numTries)
	{   
		int grassyArea=rmCreateArea("grassyArea"+i);
		rmSetAreaWarnFailure(grassyArea, false);
		rmSetAreaSize(grassyArea, rmAreaTilesToFraction(1000), rmAreaTilesToFraction(1000));
		rmSetAreaForestType(grassyArea, "Great Plains grass");
		rmSetAreaForestDensity(grassyArea, 0.3);
		rmSetAreaForestClumpiness(grassyArea, 0.1);
		rmAddAreaConstraint(grassyArea, avoidHills);
		rmAddAreaConstraint(grassyArea, avoidTradeRoute);
		rmAddAreaConstraint(grassyArea, avoidSocket);
		rmAddAreaConstraint(grassyArea, avoidNatives);
		rmAddAreaConstraint(grassyArea, avoidStartingUnits);
		rmAddAreaConstraint(grassyArea, avoidNuggetSmall);
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

	// Place resources
	// FAST COIN - three extra per player beyond starting resources.
	int silverID = -1;
	int silverCount = (cNumberNonGaiaPlayers*3);
	rmEchoInfo("silver count = "+silverCount);

	for(i=0; < silverCount)
	{
		silverType = rmRandInt(1,10);
		silverID = rmCreateObjectDef("silver "+i);
		rmAddObjectDefItem(silverID, "mine", 1, 0.0);
		rmSetObjectDefMinDistance(silverID, 0.0);
		rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(silverID, avoidFastCoin);
		rmAddObjectDefConstraint(silverID, avoidAll);
		rmAddObjectDefConstraint(silverID, avoidImpassableLand);
		rmAddObjectDefConstraint(silverID, avoidTradeRoute);
		rmAddObjectDefConstraint(silverID, avoidSocket);
		rmAddObjectDefConstraint(silverID, coinForestConstraint);
		rmAddObjectDefConstraint(silverID, avoidStartingUnits);
		rmAddObjectDefConstraint(silverID, avoidNuggetSmall);
		int result = rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
		if(result == 0)
			break;
   }

   // Text
   rmSetStatusText("",0.80);

	// bison	
   int bisonID=rmCreateObjectDef("bison herd");
   rmAddObjectDefItem(bisonID, huntable2, rmRandInt(12,16), 12.0);
   rmSetObjectDefMinDistance(bisonID, 0.0);
   rmSetObjectDefMaxDistance(bisonID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(bisonID, avoidBison);
	rmAddObjectDefConstraint(bisonID, avoidAll);
   rmAddObjectDefConstraint(bisonID, avoidImpassableLand);
	rmAddObjectDefConstraint(bisonID, avoidTradeRoute);
	rmAddObjectDefConstraint(bisonID, avoidSocket);
	rmAddObjectDefConstraint(bisonID, avoidStartingUnits);
	rmAddObjectDefConstraint(bisonID, avoidNuggetSmall);
   rmSetObjectDefCreateHerd(bisonID, true);
	rmPlaceObjectDefAtLoc(bisonID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);

	// pronghorn	
   int pronghornID=rmCreateObjectDef("pronghorn herd");
   rmAddObjectDefItem(pronghornID, huntable3, rmRandInt(6,9), 10.0);
   rmSetObjectDefMinDistance(pronghornID, 0.0);
   rmSetObjectDefMaxDistance(pronghornID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(pronghornID, avoidBison);
   rmAddObjectDefConstraint(pronghornID, avoidPronghorn);
	rmAddObjectDefConstraint(pronghornID, avoidAll);
   rmAddObjectDefConstraint(pronghornID, avoidImpassableLand);
	rmAddObjectDefConstraint(pronghornID, avoidTradeRoute);
	rmAddObjectDefConstraint(pronghornID, avoidSocket);
	rmAddObjectDefConstraint(pronghornID, avoidStartingUnits);
	rmAddObjectDefConstraint(pronghornID, avoidNuggetSmall);
   rmSetObjectDefCreateHerd(pronghornID, true);
	rmPlaceObjectDefAtLoc(pronghornID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);

		   int animal3ID=rmCreateObjectDef("animal3 herd");
   rmAddObjectDefItem(animal3ID, huntable4, rmRandInt(6,9), 10.0);
   rmSetObjectDefMinDistance(animal3ID, 0.0);
   rmSetObjectDefMaxDistance(animal3ID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(animal3ID, avoidBison);
   rmAddObjectDefConstraint(animal3ID, avoidPronghorn);
	rmAddObjectDefConstraint(animal3ID, avoidAll);
   rmAddObjectDefConstraint(animal3ID, avoidImpassableLand);
	rmAddObjectDefConstraint(animal3ID, avoidTradeRoute);
	rmAddObjectDefConstraint(animal3ID, avoidSocket);
	rmAddObjectDefConstraint(animal3ID, avoidStartingUnits);
	rmAddObjectDefConstraint(animal3ID, avoidNuggetSmall);
   rmSetObjectDefCreateHerd(animal3ID, true);
	rmPlaceObjectDefAtLoc(animal3ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);
	
	// Text
   rmSetStatusText("",0.90);

   int seConstraint = rmCreateAreaConstraint("se", hillSoutheastID);
   int heightConstraint = rmCreateMaxHeightConstraint("tree height", 6.0);
   int lowForestClass = rmDefineClass("low forest");
   int lowForestConstraint = rmCreateClassDistanceConstraint("low forest", lowForestClass, 4.0);

   // RANDOM TREES
   int count = 0;
   int maxCount = 20 * cNumberNonGaiaPlayers;
   int maxFailCount = 10 * cNumberNonGaiaPlayers;
   failCount = 0;
   for(i=1; <10)
   {
		int treeArea = rmCreateArea("se tree"+i);
		rmSetAreaSize(treeArea, 0.001, 0.003);
		rmSetAreaForestType(treeArea, "Savannah Forest");
		rmSetAreaForestDensity(treeArea, 0.2);
		rmSetAreaForestClumpiness(treeArea, 0.1);
		rmAddAreaConstraint(treeArea, seConstraint);
		rmAddAreaConstraint(treeArea, lowForestConstraint);
		rmAddAreaConstraint(treeArea, heightConstraint);
		rmAddAreaConstraint(treeArea, avoidImpassableLand);
		rmAddAreaConstraint(treeArea, avoidTradeRoute);
		rmAddAreaConstraint(treeArea, avoidSocket);
		rmAddAreaConstraint(treeArea, avoidStartingUnits);
		rmAddAreaConstraint(treeArea, avoidAll);
		rmAddAreaToClass(treeArea, lowForestClass);
		rmAddAreaConstraint(treeArea, avoidNuggetSmall);
		rmSetAreaWarnFailure(treeArea, false);
		bool ok = rmBuildArea(treeArea);
		if(ok)
		{
			count++;
			if(count > maxCount)
			break;
		}
		else
		{
			failCount++;
			if(failCount > maxFailCount)
			break;
		}
   }

   int nwConstraint = rmCreateAreaConstraint("nw", hillNorthwestID);
   int maxAreas = 5 * cNumberNonGaiaPlayers;
   int maxFails = 5 * cNumberNonGaiaPlayers;
   count = 0;
   failCount = 0;
   for(i=1; <10)
   {
      treeArea = rmCreateArea("nw tree"+i);
      rmSetAreaSize(treeArea, 0.001, 0.003);
	   rmSetAreaForestType(treeArea, "Savannah Forest");
	   rmSetAreaForestDensity(treeArea, 0.3);
	   rmSetAreaForestClumpiness(treeArea, 0.1);
	   rmAddAreaConstraint(treeArea, nwConstraint);
	   rmAddAreaConstraint(treeArea, lowForestConstraint);
	   rmAddAreaConstraint(treeArea, heightConstraint);
		rmAddAreaConstraint(treeArea, avoidImpassableLand);
		rmAddAreaConstraint(treeArea, avoidTradeRoute);
		rmAddAreaConstraint(treeArea, avoidSocket);
		rmAddAreaConstraint(treeArea, avoidStartingUnits);
		rmAddAreaConstraint(treeArea, avoidAll);
		rmAddAreaConstraint(treeArea, avoidNuggetSmall);
	   rmAddAreaToClass(treeArea, lowForestClass);
	   rmSetAreaWarnFailure(treeArea, false);
      ok = rmBuildArea(treeArea);
      if(ok)
      {
         count++;
         if(count > maxCount)
            break;
      }
      else
      {
         failCount++;
         if(failCount > maxFailCount)
            break;
      }
   }

   // Mini-forests out on the plains (mostly)
   int forestTreeID = 0;
   numTries=5*cNumberNonGaiaPlayers;
   failCount=0;
   for (i=0; <numTries)
   {   
		int forest=rmCreateArea("center forest "+i);
		rmSetAreaWarnFailure(forest, false);
		rmSetAreaSize(forest, rmAreaTilesToFraction(200), rmAreaTilesToFraction(300));
		rmSetAreaForestType(forest, "Acacia Forest");
		rmSetAreaForestDensity(forest, 0.1);
		rmSetAreaForestClumpiness(forest, 0.1);
		rmSetAreaForestUnderbrush(forest, 0.6);
		rmSetAreaCoherence(forest, 0.5);
		// rmSetAreaSmoothDistance(forest, 10);
		rmAddAreaToClass(forest, rmClassID("classForest")); 
		// rmAddAreaConstraint(forest, lowForestConstraint);
		rmAddAreaConstraint(forest, forestConstraint);
		rmAddAreaConstraint(forest, playerConstraint);
		rmAddAreaConstraint(forest, avoidImportantItem);
		rmAddAreaConstraint(forest, avoidImpassableLand); 
		rmAddAreaConstraint(forest, avoidTradeRoute);
		rmAddAreaConstraint(forest, avoidSocket);
		rmAddAreaConstraint(forest, avoidHills);
		rmAddAreaConstraint(forest, avoidNuggetSmall);
		// rmAddAreaConstraint(forest, avoidFastCoin);
		rmAddAreaConstraint(forest, avoidStartingUnits);
		if(rmBuildArea(forest)==false)
		{
			// Stop trying once we fail 10 times in a row.
			failCount++;
			if(failCount==10)
			break;
		}
		else
			failCount=0; 
   }

	// 50% chance of buffalo carcasses - either one or two if they're there.
	int areThereBuffalo=rmRandInt(1, 2);
	int howManyBuffalo=rmRandInt(1, 2);
	if ( areThereBuffalo == 1 )
	{
		int bisonCarcass=rmCreateGrouping("Bison Carcass", "gp_carcass_bison");
		rmSetGroupingMinDistance(bisonCarcass, 0.0);
		rmSetGroupingMaxDistance(bisonCarcass, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(bisonCarcass, avoidNW);
		rmAddGroupingConstraint(bisonCarcass, avoidSE);
		rmAddGroupingConstraint(bisonCarcass, avoidImpassableLand);
		rmAddGroupingConstraint(bisonCarcass, playerConstraint);
		rmAddGroupingConstraint(bisonCarcass, avoidTradeRoute);
		rmAddGroupingConstraint(bisonCarcass, avoidSocket);
		rmAddGroupingConstraint(bisonCarcass, avoidStartingUnits);
		rmAddGroupingConstraint(bisonCarcass, avoidAll);
		rmAddGroupingConstraint(bisonCarcass, avoidNuggetSmall);
		rmPlaceGroupingAtLoc(bisonCarcass, 0, 0.5, 0.5, howManyBuffalo);
	}

	// Perching Vultures - add a couple somewhere.
	int vultureID=rmCreateObjectDef("perching vultures");
	rmAddObjectDefItem(vultureID, "PropVulturePerching", 1, 0.0);
	rmSetObjectDefMinDistance(vultureID, 0.0);
	rmSetObjectDefMaxDistance(vultureID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(vultureID, avoidNW);
	rmAddObjectDefConstraint(vultureID, avoidSE);
	rmAddObjectDefConstraint(vultureID, avoidBison);
	rmAddObjectDefConstraint(vultureID, avoidAll);
	rmAddObjectDefConstraint(vultureID, avoidNuggetSmall);
	rmAddObjectDefConstraint(vultureID, avoidImpassableLand);
	rmAddObjectDefConstraint(vultureID, avoidTradeRoute);
	rmAddObjectDefConstraint(vultureID, avoidSocket);
	rmAddObjectDefConstraint(vultureID, avoidStartingUnits);
	rmAddObjectDefConstraint(vultureID, circleConstraint);
	rmAddObjectDefConstraint(vultureID, playerConstraint);
	rmPlaceObjectDefAtLoc(vultureID, 0, 0.5, 0.5, 2);
	
			int priderockID=rmCreateObjectDef("priderock");
	rmAddObjectDefItem(priderockID, "BigPropTexas", 1, 0.0);
	rmSetObjectDefMinDistance(priderockID, 0.0);
	rmSetObjectDefMaxDistance(priderockID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(priderockID, avoidAll);
	rmAddObjectDefConstraint(priderockID, avoidNuggetSmall);
	rmAddObjectDefConstraint(priderockID, avoidImpassableLand);
	rmAddObjectDefConstraint(priderockID, avoidTradeRoute);
	rmAddObjectDefConstraint(priderockID, avoidSocket);
	rmAddObjectDefConstraint(priderockID, avoidStartingUnits);
	rmAddObjectDefConstraint(priderockID, circleConstraint);
	rmAddObjectDefConstraint(priderockID, playerConstraint);
	rmPlaceObjectDefAtLoc(priderockID, 0, 0.5, 0.5, 4);
	
		int wildebeestID=rmCreateObjectDef("wildebeest");
	rmAddObjectDefItem(wildebeestID, "Gnu", cNumberNonGaiaPlayers+3, 5.0);
	rmSetObjectDefMinDistance(wildebeestID, 0.0);
	rmSetObjectDefMaxDistance(wildebeestID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(wildebeestID, avoidAll);
	rmAddObjectDefConstraint(wildebeestID, avoidNuggetSmall);
	rmAddObjectDefConstraint(wildebeestID, avoidImpassableLand);
	rmAddObjectDefConstraint(wildebeestID, avoidTradeRoute);
	rmAddObjectDefConstraint(wildebeestID, avoidSocket);
	rmAddObjectDefConstraint(wildebeestID, avoidStartingUnits);
	rmAddObjectDefConstraint(wildebeestID, circleConstraint);
	rmAddObjectDefConstraint(wildebeestID, playerConstraint);
	rmPlaceObjectDefAtLoc(wildebeestID, 0, 0.5, 0.5, 1);
	
		int zebraherdID=rmCreateObjectDef("zebraherd");
	rmAddObjectDefItem(zebraherdID, "Zebra", cNumberNonGaiaPlayers+2, 5.0);
	rmSetObjectDefMinDistance(zebraherdID, 0.0);
	rmSetObjectDefMaxDistance(zebraherdID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(zebraherdID, avoidAll);
	rmAddObjectDefConstraint(zebraherdID, avoidNuggetSmall);
	rmAddObjectDefConstraint(zebraherdID, avoidImpassableLand);
	rmAddObjectDefConstraint(zebraherdID, avoidTradeRoute);
	rmAddObjectDefConstraint(zebraherdID, avoidSocket);
	rmAddObjectDefConstraint(zebraherdID, avoidStartingUnits);
	rmAddObjectDefConstraint(zebraherdID, circleConstraint);
	rmAddObjectDefConstraint(zebraherdID, playerConstraint);
	rmPlaceObjectDefAtLoc(zebraherdID, 0, 0.5, 0.5, 1);
	
		int elephantsID=rmCreateObjectDef("elephants");
	rmAddObjectDefItem(elephantsID, "ypWildElephant", cNumberNonGaiaPlayers+2, 5.0);
	rmSetObjectDefMinDistance(elephantsID, 0.0);
	rmSetObjectDefMaxDistance(elephantsID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(elephantsID, avoidAll);
	rmAddObjectDefConstraint(elephantsID, avoidNuggetSmall);
	rmAddObjectDefConstraint(elephantsID, avoidImpassableLand);
	rmAddObjectDefConstraint(elephantsID, avoidTradeRoute);
	rmAddObjectDefConstraint(elephantsID, avoidSocket);
	rmAddObjectDefConstraint(elephantsID, avoidStartingUnits);
	rmAddObjectDefConstraint(elephantsID, circleConstraint);
	rmAddObjectDefConstraint(elephantsID, playerConstraint);
	rmPlaceObjectDefAtLoc(elephantsID, 0, 0.5, 0.5, 1);
	
		int cranesID=rmCreateObjectDef("cranes");
	rmAddObjectDefItem(cranesID, "CrownedCrane", cNumberNonGaiaPlayers+2, 5.0);
	rmSetObjectDefMinDistance(cranesID, 0.0);
	rmSetObjectDefMaxDistance(cranesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(cranesID, avoidAll);
	rmAddObjectDefConstraint(cranesID, avoidNuggetSmall);
	rmAddObjectDefConstraint(cranesID, avoidImpassableLand);
	rmAddObjectDefConstraint(cranesID, avoidTradeRoute);
	rmAddObjectDefConstraint(cranesID, avoidSocket);
	rmAddObjectDefConstraint(cranesID, avoidStartingUnits);
	rmAddObjectDefConstraint(cranesID, circleConstraint);
	rmAddObjectDefConstraint(cranesID, playerConstraint);
	rmPlaceObjectDefAtLoc(cranesID, 0, 0.5, 0.5, 1);
	
		int ExtraAcaciasID=rmCreateObjectDef("ExtraAcacias");
	rmAddObjectDefItem(ExtraAcaciasID, "TreeAcacia", 1, 0.0);
	rmSetObjectDefMinDistance(ExtraAcaciasID, 0.0);
	rmSetObjectDefMaxDistance(ExtraAcaciasID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(ExtraAcaciasID, avoidAll);
	rmAddObjectDefConstraint(ExtraAcaciasID, avoidNuggetSmall);
	rmAddObjectDefConstraint(ExtraAcaciasID, avoidImpassableLand);
	rmAddObjectDefConstraint(ExtraAcaciasID, avoidTradeRoute);
	rmAddObjectDefConstraint(ExtraAcaciasID, avoidSocket);
	rmAddObjectDefConstraint(ExtraAcaciasID, avoidStartingUnits);
	rmAddObjectDefConstraint(ExtraAcaciasID, circleConstraint);
	rmAddObjectDefConstraint(ExtraAcaciasID, playerConstraint);
	rmPlaceObjectDefAtLoc(ExtraAcaciasID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*10);
	
			int Animal4ID=rmCreateObjectDef("Animal4");
	rmAddObjectDefItem(Animal4ID, huntable4, 5, 5.0);
	rmSetObjectDefMinDistance(Animal4ID, 0.0);
	rmSetObjectDefMaxDistance(Animal4ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(Animal4ID, avoidAll);
	rmAddObjectDefConstraint(Animal4ID, avoidNuggetSmall);
	rmAddObjectDefConstraint(Animal4ID, avoidImpassableLand);
	rmAddObjectDefConstraint(Animal4ID, avoidSocket);
	rmAddObjectDefConstraint(Animal4ID, avoidStartingUnits);
	rmAddObjectDefConstraint(Animal4ID, circleConstraint);
	rmAddObjectDefConstraint(Animal4ID, playerConstraint);
	rmPlaceObjectDefAtLoc(Animal4ID, 0, 0.5, 0.5, 3);

		     // choose African Savannah Wild Animals
    int AfricanWildArray = xsArrayCreateString(4, "", "");

    xsArraySetString(AfricanWildArray, 1, "WildLion");
    xsArraySetString(AfricanWildArray, 2, "WildHyena");
    xsArraySetString(AfricanWildArray, 3, "WildRhino");
    xsArraySetString(AfricanWildArray, 4, "WildCrocodile");

  string Wild1 = xsArrayGetString(AfricanWildArray, rmRandInt(1, 4));
  string Wild2 = xsArrayGetString(AfricanWildArray, rmRandInt(1, 4));
  string Wild3 = xsArrayGetString(AfricanWildArray, rmRandInt(1, 4));
  
  		int dangerous1ID=rmCreateObjectDef("dangerous1");
	rmAddObjectDefItem(dangerous1ID, Wild1, 1, 0.0);
	rmSetObjectDefMinDistance(dangerous1ID, 0.0);
	rmSetObjectDefMaxDistance(dangerous1ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(dangerous1ID, avoidAll);
	rmAddObjectDefConstraint(dangerous1ID, avoidNuggetSmall);
	rmAddObjectDefConstraint(dangerous1ID, avoidImpassableLand);
	rmAddObjectDefConstraint(dangerous1ID, avoidSocket);
	rmAddObjectDefConstraint(dangerous1ID, avoidStartingUnits);
	rmAddObjectDefConstraint(dangerous1ID, circleConstraint);
	rmAddObjectDefConstraint(dangerous1ID, playerConstraint);
	rmPlaceObjectDefAtLoc(dangerous1ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
	
			int dangerous2ID=rmCreateObjectDef("dangerous2");
	rmAddObjectDefItem(dangerous2ID, Wild2, 1, 0.0);
	rmSetObjectDefMinDistance(dangerous2ID, 0.0);
	rmSetObjectDefMaxDistance(dangerous2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(dangerous2ID, avoidAll);
	rmAddObjectDefConstraint(dangerous2ID, avoidNuggetSmall);
	rmAddObjectDefConstraint(dangerous2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(dangerous2ID, avoidSocket);
	rmAddObjectDefConstraint(dangerous2ID, avoidStartingUnits);
	rmAddObjectDefConstraint(dangerous2ID, circleConstraint);
	rmAddObjectDefConstraint(dangerous2ID, playerConstraint);
	rmPlaceObjectDefAtLoc(dangerous2ID, 0, 0.5, 0.5, 2);
	
			int dangerous3ID=rmCreateObjectDef("dangerous3");
	rmAddObjectDefItem(dangerous3ID, Wild3, 1, 0.0);
	rmSetObjectDefMinDistance(dangerous3ID, 0.0);
	rmSetObjectDefMaxDistance(dangerous3ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(dangerous3ID, avoidAll);
	rmAddObjectDefConstraint(dangerous3ID, avoidNuggetSmall);
	rmAddObjectDefConstraint(dangerous3ID, avoidImpassableLand);
	rmAddObjectDefConstraint(dangerous3ID, avoidSocket);
	rmAddObjectDefConstraint(dangerous3ID, avoidStartingUnits);
	rmAddObjectDefConstraint(dangerous3ID, circleConstraint);
	rmAddObjectDefConstraint(dangerous3ID, playerConstraint);
	rmPlaceObjectDefAtLoc(dangerous3ID, 0, 0.5, 0.5, 1);
	

	int grassPatchGroupType=-1;
	int grassPatchGroup=-1;
	// Two grass patches per player.

	for(i=1; <2*cNumberNonGaiaPlayers)
   {
		grassPatchGroupType=rmRandInt(1, 7);
		grassPatchGroup=rmCreateGrouping("Grass Patch Group"+i, "gp_grasspatch0"+grassPatchGroupType);
		rmSetGroupingMinDistance(grassPatchGroup, 0.0);
		rmSetGroupingMaxDistance(grassPatchGroup, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(grassPatchGroup, avoidNW);
		rmAddGroupingConstraint(grassPatchGroup, avoidSE);
		rmAddGroupingConstraint(grassPatchGroup, avoidImpassableLand);
		rmAddGroupingConstraint(grassPatchGroup, playerConstraint);
		rmAddGroupingConstraint(grassPatchGroup, avoidTradeRoute);
		rmAddGroupingConstraint(grassPatchGroup, avoidSocket);
		rmAddGroupingConstraint(grassPatchGroup, avoidNuggetSmall);
		rmAddGroupingConstraint(grassPatchGroup, circleConstraint);
		rmAddGroupingConstraint(grassPatchGroup, avoidAll);
		rmPlaceGroupingAtLoc(grassPatchGroup, 0, 0.5, 0.5, 1);
	}

	int flowerPatchGroupType=-1;
	int flowerPatchGroup=-1;

	// Also two "flowers" per player.
	for(i=1; <2*cNumberNonGaiaPlayers)
   {
		flowerPatchGroupType=rmRandInt(1, 8);
		flowerPatchGroup=rmCreateGrouping("Flower Patch Group"+i, "gp_flower0"+flowerPatchGroupType);
		rmSetGroupingMinDistance(flowerPatchGroup, 0.0);
		rmSetGroupingMaxDistance(flowerPatchGroup, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(flowerPatchGroup, avoidNW);
		rmAddGroupingConstraint(flowerPatchGroup, avoidSE);
		rmAddGroupingConstraint(flowerPatchGroup, avoidImpassableLand);
		rmAddGroupingConstraint(flowerPatchGroup, playerConstraint);
		rmAddGroupingConstraint(flowerPatchGroup, avoidTradeRoute);
		rmAddGroupingConstraint(flowerPatchGroup, avoidSocket);
		rmAddGroupingConstraint(flowerPatchGroup, avoidNuggetSmall);
		rmAddGroupingConstraint(flowerPatchGroup, avoidAll);
		rmAddGroupingConstraint(flowerPatchGroup, circleConstraint);
		rmPlaceGroupingAtLoc(flowerPatchGroup, 0, 0.5, 0.5, 1);
	}

   	// And a couple of geysers.
	int geyserID=rmCreateGrouping("Geysers", "BigPropTexas");
	rmSetGroupingMinDistance(geyserID, 0.0);
	rmSetGroupingMaxDistance(geyserID, rmXFractionToMeters(0.5));
	rmAddGroupingConstraint(geyserID, avoidNW);
	rmAddGroupingConstraint(geyserID, avoidSE);
	rmAddGroupingConstraint(geyserID, avoidBison);
	rmAddGroupingConstraint(geyserID, avoidAll);
	rmAddGroupingConstraint(geyserID, avoidImpassableLand);
	rmAddGroupingConstraint(geyserID, avoidTradeRoute);
	rmAddGroupingConstraint(geyserID, avoidSocket);
	rmAddGroupingConstraint(geyserID, avoidStartingUnits);
	rmAddGroupingConstraint(geyserID, avoidNuggetSmall);
	rmAddGroupingConstraint(geyserID, playerConstraint);
	rmAddGroupingConstraint(geyserID, circleConstraint);
	rmPlaceGroupingAtLoc(geyserID, 0, 0.5, 0.5, 2);


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
