// Barbary
//
// Based on the bahia map that was also based in saguenay
//
// Main entry point for random map script
include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";
void main(void)
{
   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

   //Chooses which natives appear on the map
    string aur_type = "egyptian";
    int resourcesarray = xsArrayCreateString(5, "", "");

    xsArraySetString(resourcesarray, 1, "coffee");
    xsArraySetString(resourcesarray, 2, "literature");
    xsArraySetString(resourcesarray, 3, "salt");
    xsArraySetString(resourcesarray, 4, "slaves");
    xsArraySetString(resourcesarray, 5, "slaves");

    rmAllocateSubCivs(3);

    string subCiv0Name = "AURCoffeeMaghreb";
    int subCiv0 = rmGetCivID(subCiv0Name);
    rmSetSubCiv(0, subCiv0Name); 

    string subCiv1Name = "AURLiteratureMaghreb";
    int subCiv1 = rmGetCivID(subCiv1Name);
    rmSetSubCiv(1, subCiv1Name);

	string subCiv2Name = "AURSaltMaghreb";
    int subCiv2 = rmGetCivID(subCiv2Name);
    rmSetSubCiv(2, subCiv2Name);
	
	string subCiv3Name = "AURSlavesMaghreb";
    int subCiv3 = rmGetCivID(subCiv3Name);
    rmSetSubCiv(3, subCiv3Name);
	

   // Picks the map size
   int playerTiles=16000;
   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

	int whichVariation=-1;
	whichVariation = rmRandInt(1,2);

   // Picks a default water height
   rmSetSeaLevel(1.0);
//   rmSetGlobalRain( 0.3 );

   // Picks default terrain and water
	// rmSetMapElevationParameters(long type, float minFrequency, long numberOctaves, float persistence, float heightVariation)
	//rmSetMapElevationParameters(cElevTurbulence, 0.1, 4, 0.2, 4.0);
	rmSetMapElevationParameters(cElevTurbulence, 0.04, 4, 0.2, 3.0);
	rmSetSeaType("atlantic coast");
   rmEnableLocalWater(false);
	 rmSetBaseTerrainMix("barbary_grass");
    rmTerrainInitialize("patagonia\ground_dirt1_pat", 4.0);
	rmSetMapType("AFRICANdesert");
	rmSetMapType("africa");
	rmSetMapType("water");
   rmSetLightingSet("bayou");
	rmSetWorldCircleConstraint(true);

	// Choose mercs.
	chooseMercs();
wotta_triggers();
   // Define some classes. These are used later for constraints.
   int classPlayer=rmDefineClass("player");
   rmDefineClass("classCliff");
   rmDefineClass("classPatch");
   int classbigContinent=rmDefineClass("big continent");
   rmDefineClass("starting settlement");
   rmDefineClass("startingUnit");
   rmDefineClass("classForest");
   rmDefineClass("classWestForest");
   rmDefineClass("classMountain");
   rmDefineClass("importantItem");
	rmDefineClass("secrets");
	rmDefineClass("bay");
	rmDefineClass("nuggets");
	rmDefineClass("socketClass");

	int lakeClass=rmDefineClass("lake");

   // -------------Define constraints
   // These are used to have objects and areas avoid each other
   
   // Map edge constraints
   int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
   int longPlayerConstraint=rmCreateClassDistanceConstraint("continent stays away from players", classPlayer, 24.0);

   // Player constraints
   int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 30.0);
   int smallMapPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 70.0);
   int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 30.0);
   int nearWater10 = rmCreateTerrainDistanceConstraint("near water", "Water", true, 10.0);

   // Bonus area constraint.
   int bigContinentConstraint=rmCreateClassDistanceConstraint("avoid bonus island", classbigContinent, 20.0);

   // Resource avoidance
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0);
   int westForestConstraint=rmCreateClassDistanceConstraint("west forest vs. forest", rmClassID("classWestForest"), 35.0);
   int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 1.0);
   int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "gold", 40.0);
   int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 50.0);
   int avoidPlayerNugget=rmCreateTypeDistanceConstraint("player nugget avoid nugget", "AbstractNugget", 25.0);
   int avoidBighornSheep=rmCreateTypeDistanceConstraint("bighorn avoids bighorn", "Gazelle", 35.0);
   int avoidMoose=rmCreateTypeDistanceConstraint("moose avoids moose", "Deer", 35.0);
   int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 15.0);
   int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 18.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
   int whaleLand = rmCreateTerrainDistanceConstraint("whale v. land", "land", true, 20.0);
   int mountainLand = rmCreateTerrainDistanceConstraint("mountain v. land", "land", true, 30.0);
   int mountainVsMountain = rmCreateClassDistanceConstraint("mountain v. mountain", rmClassID("classMountain"), 30.0);
   int whaleVsMountain = rmCreateClassDistanceConstraint("whale v. mountain", rmClassID("classMountain"), 20.0);
	int avoidFastCoin=rmCreateTypeDistanceConstraint("fast coin avoids coin", "gold", 60.0);
	int avoidFastCoinForest=rmCreateTypeDistanceConstraint("forests avoid fast coin", "gold", 10.0);

   // Avoid impassable land
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 10.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
   int avoidCliffs=rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 30.0);
   int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 5.0);

	int avoidLake=rmCreateClassDistanceConstraint("lake vs stuff", lakeClass, 30.0);

   // Decoration avoidance
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

   // Starting units avoidance
   int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 20.0);
   int avoidStartingUnitsSmall=rmCreateClassDistanceConstraint("objects avoid starting units small", rmClassID("startingUnit"), 5.0);

   // Trade route avoidance.
   // VP avoidance
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 10.0);
   int avoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("trade route short", 9.0);
	int avoidSocket=rmCreateClassDistanceConstraint("avoid sockets", rmClassID("socketClass"), 5.0);
	int avoidSocketCliff=rmCreateClassDistanceConstraint("cliffs avoid sockets by a lot", rmClassID("socketClass"), 10.0);
	int avoidSocketPlayer=rmCreateClassDistanceConstraint("cliffs avoid sockets by a lot more", rmClassID("socketClass"), 15.0);
   int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
   int secretsAvoidSecrets = rmCreateClassDistanceConstraint("secrets avoid secrets", rmClassID("secrets"), 60.0);
   int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 30.0);

   // Constraint to avoid water.
   int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 8.0);

   // Cardinal Directions Constraints (handy!)
   int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));
   int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
   int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
   int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));

   // ships vs. ships
   int shipVsShip=rmCreateTypeDistanceConstraint("ships avoid ship", "ship", 15.0);

    // New extra stuff for water spawn point avoidance.
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 10.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 15);
	int flagEdgeConstraint = rmCreatePieConstraint("flags stay near edge of map", 0.5, 0.5, rmGetMapXSize()-20, rmGetMapXSize()-10, 0, 0, 0);

	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Text
   rmSetStatusText("",0.10);


	// int avoidBeach = rmCreateAreaDistanceConstraint("stay away from InnerLandID", InnerLandID, 4);

	// Create two Bay Areas.
/*   int bay1ID=rmCreateArea("Bay 1");
   rmSetAreaSize(bay1ID, 0.0008, 0.0008);
	rmSetAreaLocation(bay1ID, 1.0, 0.45);
	rmSetAreaWaterType(bay1ID, "guajira coast");
   rmSetAreaBaseHeight(bay1ID, 1.0); // Was 10
   rmSetAreaMinBlobs(bay1ID, 4);
   rmSetAreaMaxBlobs(bay1ID, 6);
   rmSetAreaMinBlobDistance(bay1ID, 5);
   rmSetAreaMaxBlobDistance(bay1ID, 30);
   rmSetAreaSmoothDistance(bay1ID, 10);
   rmSetAreaCoherence(bay1ID, 0.8);
	rmAddAreaToClass(bay1ID, rmClassID("bay"));
   rmSetAreaObeyWorldCircleConstraint(bay1ID, false);
	rmBuildArea(bay1ID);*/

/*   int bay2ID=rmCreateArea("Bay 2");
   rmSetAreaSize(bay2ID, 0.0008, 0.0008);
	rmSetAreaLocation(bay2ID, 0.55, 0.0);
	rmSetAreaWaterType(bay2ID, "guajira coast");
   rmSetAreaBaseHeight(bay2ID, 1.0); // Was 10
   rmSetAreaMinBlobs(bay2ID, 4);
   rmSetAreaMaxBlobs(bay2ID, 6);
   rmSetAreaMinBlobDistance(bay2ID, 5);
   rmSetAreaMaxBlobDistance(bay2ID, 30);
   rmSetAreaSmoothDistance(bay2ID, 10);
   rmSetAreaCoherence(bay2ID, 0.8);
	rmAddAreaToClass(bay2ID, rmClassID("bay"));
   rmSetAreaObeyWorldCircleConstraint(bay2ID, false);
   rmBuildArea(bay2ID);*/

   int bay3ID=rmCreateArea("Bay 3");
   rmSetAreaSize(bay3ID, 0.20, 0.20);
   rmSetAreaLocation(bay3ID, 1.0, 1.0);
	rmSetAreaWaterType(bay3ID, "guajira coast");
   rmSetAreaBaseHeight(bay3ID, 1.0); // Was 10
   rmSetAreaMinBlobs(bay3ID, 4);
   rmSetAreaMaxBlobs(bay3ID, 6);
   rmSetAreaMinBlobDistance(bay3ID, 5);
   rmSetAreaMaxBlobDistance(bay3ID, 10);
   rmSetAreaSmoothDistance(bay3ID, 10);
   rmSetAreaCoherence(bay3ID, 0.9);
   rmAddAreaInfluenceSegment(bay3ID, 0.55, 0.99, 0.99, 0.55); 
	rmAddAreaToClass(bay3ID, rmClassID("bay"));
   rmSetAreaObeyWorldCircleConstraint(bay3ID, false);
   rmBuildArea(bay3ID);

   int islandID=rmCreateArea("Order of Christ Island");
   rmSetAreaSize(islandID, 0.15, 0.15);
   rmSetAreaLocation(islandID, 0.15, 0.15);
   rmSetAreaMix(islandID, "barbary_sand");
   rmSetAreaBaseHeight(islandID, 1.0);
   rmSetAreaSmoothDistance(islandID, 10);
   rmSetAreaCoherence(islandID, 0.6);
   rmAddAreaInfluenceSegment(islandID, 0.25, 0.05, 0.05, 0.25); 
   rmSetAreaObeyWorldCircleConstraint(islandID, false);
   rmBuildArea(islandID);

// River to follow the travel of the maritime route and ensure always certain distance from route to coast
	int riverID = rmRiverCreate(-1, "guajira coast", 1, 5, 12, 14);
//	rmRiverAddWaypoint(riverID, 0.88, 0.00);
//	rmRiverAddWaypoint(riverID, 0.38, 0.01);
	rmRiverAddWaypoint(riverID, 0.99, 0.32);
	rmRiverAddWaypoint(riverID, 0.82, 0.49);
	rmRiverAddWaypoint(riverID, 0.65, 0.66);
	rmRiverAddWaypoint(riverID, 0.49, 0.83);
	rmRiverAddWaypoint(riverID, 0.32, 0.99);
//	rmRiverSetBankNoiseParams(riverID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
	rmRiverBuild(riverID);

   // Mountains
/*    int mountainID = rmCreateGrouping("Mountain 1", "bahia mountain 1");
    rmSetGroupingMinDistance(mountainID, 0.0);
    rmSetGroupingMaxDistance(mountainID, rmXFractionToMeters(0.5));
    rmAddGroupingConstraint(mountainID, mountainLand);
    rmAddGroupingConstraint(mountainID, mountainVsMountain);
    rmAddGroupingToClass(mountainID, rmClassID("classMountain"));
    rmPlaceGroupingAtLoc(mountainID, 0, 0.5, 0.5);
    mountainID = rmCreateGrouping("Mountain 2", "bahia mountain 2");
    rmSetGroupingMinDistance(mountainID, 0.0);
    rmSetGroupingMaxDistance(mountainID, rmXFractionToMeters(0.5));
    rmAddGroupingConstraint(mountainID, mountainLand);
    rmAddGroupingConstraint(mountainID, mountainVsMountain);
    rmAddGroupingToClass(mountainID, rmClassID("classMountain"));
    rmPlaceGroupingAtLoc(mountainID, 0, 0.5, 0.5);
    mountainID = rmCreateGrouping("Mountain 3", "bahia mountain 3");
    rmSetGroupingMinDistance(mountainID, 0.0);
    rmSetGroupingMaxDistance(mountainID, rmXFractionToMeters(0.5));
    rmAddGroupingConstraint(mountainID, mountainLand);
    rmAddGroupingConstraint(mountainID, mountainVsMountain);
    rmAddGroupingToClass(mountainID, rmClassID("classMountain"));
    rmPlaceGroupingAtLoc(mountainID, 0, 0.5, 0.5);*/

   // Text
   rmSetStatusText("",0.20);

   // Placement order
   // Trade route -> Player Areas -> Lake -> Cliffs -> Nuggets
   int tradeRouteID = rmCreateTradeRoute();
   int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.1);
   rmSetObjectDefAllowOverlap(socketID, true);

   rmAddObjectDefToClass(socketID, rmClassID("socketClass"));
   rmAddObjectDefConstraint(socketID, circleConstraint);

   rmSetObjectDefMinDistance(socketID, 20.0);
   rmSetObjectDefMaxDistance(socketID, 32.0);

   rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.32);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.32, 1.0);

	bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "WATERdirt");
   if(placedTradeRoute == false)
      rmEchoError("Failed to place trade route");

	// add the meeting poles along the trade route.
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

   vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.1);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   if ( cNumberNonGaiaPlayers < 6 )
   {
	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.4);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.6);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   else
   {
	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.35);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.65);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.9);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   // Text
   rmSetStatusText("",0.30);

   if ( cNumberTeams == 2 )
   {
	   if ( rmGetNumberPlayersOnTeam(0) < 5 && rmGetNumberPlayersOnTeam(1) < 5)
	   {
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.75, 0.2, 0.55, 0.2, 0.0, 0.1);

			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.2, 0.75, 0.2, 0.55, 0.0, 0.1);
	   }
	   else
	   {
   			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.2, 0.7, 0.6, 0.75, 0.0, 0.1);		// 0.25

			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.7, 0.2, 0.75, 0.6, 0.0, 0.1);	// 0.75, 0.7
	   }
   }
   else
   {
		rmSetPlacementSection(0.35, 0.9);
		rmPlacePlayersCircular(0.3, 0.3, 0.0);

   }

    // Set up player areas.
   float playerFraction=rmAreaTilesToFraction(100);
   for(i=1; <cNumberPlayers)
   {
      // Create the area.
      int id=rmCreateArea("Player"+i);
      // Assign to the player.
      rmSetPlayerArea(i, id);
	  rmAddAreaConstraint(i, avoidSocketPlayer);
      // Set the size.
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 1);
      rmSetAreaLocPlayer(id, i);
      rmSetAreaWarnFailure(id, false);
   }

   // Build the areas.
   rmBuildAllAreas();
	
   // Text
   rmSetStatusText("",0.40);

	// Add the natives
	int northNative = rmRandInt(1,2);
	int southNative = rmRandInt(1,2);
	  
    	   int christVillageID = rmCreateGrouping("South Village", "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 4))+"MAG"+rmRandInt(1, 3));
    	   rmSetGroupingMinDistance(christVillageID, 0.0);
    	   rmSetGroupingMaxDistance(christVillageID, 10.0);
    	   rmAddGroupingConstraint(christVillageID, shortAvoidImpassableLand);
    	   rmAddGroupingToClass(christVillageID, rmClassID("importantItem"));
	   rmPlaceGroupingAtLoc(christVillageID, 0, 0.4, 0.4);
	
	   int westVillageID = rmCreateGrouping("West Village 1", "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 4))+"MAG"+rmRandInt(1, 3));
    	   rmSetGroupingMinDistance(westVillageID, 0.0);
    	   rmSetGroupingMaxDistance(westVillageID, 5.0+cNumberNonGaiaPlayers*2.0);
    	   rmAddGroupingConstraint(westVillageID, avoidImpassableLand);
    	   rmAddGroupingConstraint(westVillageID, playerConstraint);
    	   rmAddGroupingConstraint(westVillageID, avoidImportantItem);
    	   rmAddGroupingToClass(westVillageID, rmClassID("importantItem"));
		   rmPlaceGroupingAtLoc(westVillageID, 0, 0.12, 0.32);

		int westVillage2ID = rmCreateGrouping("West Village 2", "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 4))+"MAG"+rmRandInt(1, 3));
    	   rmSetGroupingMinDistance(westVillage2ID, 0.0);
    	   rmSetGroupingMaxDistance(westVillage2ID, 5.0+cNumberNonGaiaPlayers*2.0);
    	   rmAddGroupingConstraint(westVillage2ID, avoidImpassableLand);
    	   rmAddGroupingConstraint(westVillage2ID, playerConstraint);
    	   rmAddGroupingConstraint(westVillage2ID, avoidImportantItem);
    	   rmAddGroupingToClass(westVillage2ID, rmClassID("importantItem"));
	       rmPlaceGroupingAtLoc(westVillage2ID, 0, 0.32, 0.12);

   // Text
   rmSetStatusText("",0.50);

      // Starting Unit placement
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 10.0);
	rmSetObjectDefMaxDistance(startingUnits, 13.0);
	rmAddObjectDefToClass(startingUnits, rmClassID("startingUnit"));
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidTradeRoute);

	int startingTCID= rmCreateObjectDef("startingTC");
	rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);
	rmAddObjectDefConstraint(startingTCID, avoidWater8);
	rmSetObjectDefMinDistance(startingTCID, 0.0);
	rmSetObjectDefMaxDistance(startingTCID, 15.0);
	if ( rmGetNomadStart())
	{
		rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 5.0);
	}
	else
	{
		rmAddObjectDefItem(startingTCID, "TownCenter", 1, 5.0);
	}
	rmAddObjectDefToClass(startingTCID, rmClassID("startingUnit"));

	int silverType = -1;
	int playerGoldID = -1;

	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "TreeTexas", 1, 0.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 10.0);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 15.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartingUnitsSmall);

	int StartarmadilloID=rmCreateObjectDef("starting armadillo");
	rmAddObjectDefItem(StartarmadilloID, "Gazelle", 1, 0.0);
	rmSetObjectDefMinDistance(StartarmadilloID, 10.0);
	rmSetObjectDefMaxDistance(StartarmadilloID, 15.0);
	rmAddObjectDefConstraint(StartarmadilloID, avoidStartingUnitsSmall);

	int StartBerryBushID=rmCreateObjectDef("starting berry bush");
	rmAddObjectDefItem(StartBerryBushID, "DatePalm", 2, 4.0);
	rmSetObjectDefMinDistance(StartBerryBushID, 10.0);
	rmSetObjectDefMaxDistance(StartBerryBushID, 16.0);
	rmAddObjectDefConstraint(StartBerryBushID, avoidStartingUnitsSmall);

	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
	rmAddObjectDefToClass(playerNuggetID, rmClassID("nuggets"));
    rmSetObjectDefMinDistance(playerNuggetID, 30.0);
    rmSetObjectDefMaxDistance(playerNuggetID, 35.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidStartingUnitsSmall);
	rmAddObjectDefConstraint(playerNuggetID, avoidPlayerNugget);
	rmAddObjectDefConstraint(playerNuggetID, circleConstraint);

	int waterFlagID=-1;

	for(i=1; <cNumberPlayers)
	{
		rmClearClosestPointConstraints();
		// Place starting units and a TC!
		rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		// Everyone gets one ore mine close by.
		silverType = rmRandInt(1,10);
		playerGoldID = rmCreateObjectDef("player silver closer "+i);
		rmAddObjectDefItem(playerGoldID, "mine", 1, 0.0);
		// rmAddObjectDefToClass(playerGoldID, rmClassID("importantItem"));
		rmAddObjectDefConstraint(playerGoldID, avoidTradeRoute);
		rmAddObjectDefConstraint(playerGoldID, avoidStartingUnitsSmall);
		rmSetObjectDefMinDistance(playerGoldID, 15.0);
		rmSetObjectDefMaxDistance(playerGoldID, 20.0);
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		// Berry Bushes
		rmPlaceObjectDefAtLoc(StartBerryBushID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		// Placing starting Pronghorns...
		rmPlaceObjectDefAtLoc(StartarmadilloID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartarmadilloID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartarmadilloID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartarmadilloID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		
		// Placing starting trees...
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		// Nuggets
		rmSetNuggetDifficulty(1, 1);
		rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		// Water flag
		waterFlagID=rmCreateObjectDef("HC water flag "+i);
		rmAddObjectDefItem(waterFlagID, "HomeCityWaterSpawnFlag", 1, 0.0);
//		rmAddClosestPointConstraint(flagEdgeConstraint);
		rmAddClosestPointConstraint(flagVsFlag);
		rmAddClosestPointConstraint(flagLand);
		rmAddClosestPointConstraint(Northward);
		vector TCLocation = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
        vector closestPoint = rmFindClosestPointVector(TCLocation, rmXFractionToMeters(1.0));

		rmPlaceObjectDefAtLoc(waterFlagID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
		rmClearClosestPointConstraints();
	}
   
	int numTries=cNumberNonGaiaPlayers*2;

   // Text
   rmSetStatusText("",0.60);

   // Define and place Nuggets
   int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetID, 0.0);
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nuggetID, avoidImpassableLand);
  	rmAddObjectDefConstraint(nuggetID, avoidNugget);
  	rmAddObjectDefConstraint(nuggetID, avoidAll);
  	rmAddObjectDefConstraint(nuggetID, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetID, avoidStartingUnits);
	rmAddObjectDefConstraint(nuggetID, avoidSocket);
	rmAddObjectDefConstraint(nuggetID, avoidWater8);
	rmAddObjectDefConstraint(nuggetID, circleConstraint);
	rmSetNuggetDifficulty(1, 3);
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*5);

   // Text
   rmSetStatusText("",0.70);

	// Ore mines, to be avoided by forests, etc.
	int silverID = -1;
	int silverWestID = -1;
	int silverCount = (cNumberNonGaiaPlayers*2);
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
		rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
   }

	// One extra gold mine per player "out west"
	for(i=0; < (cNumberNonGaiaPlayers))
	{
		silverType = rmRandInt(1,10);
		silverWestID = rmCreateObjectDef("silver west "+i);
		rmAddObjectDefItem(silverWestID, "mine", 1, 0.0);
		rmSetObjectDefMinDistance(silverWestID, 0.0);
		rmSetObjectDefMaxDistance(silverWestID, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(silverWestID, avoidFastCoin);
		rmAddObjectDefConstraint(silverWestID, avoidAll);
		rmAddObjectDefConstraint(silverWestID, avoidImpassableLand);
		rmAddObjectDefConstraint(silverWestID, avoidTradeRoute);
		rmAddObjectDefConstraint(silverWestID, avoidSocket);
		rmAddObjectDefConstraint(silverWestID, Southward);
		rmPlaceObjectDefAtLoc(silverWestID, 0, 0.5, 0.5);
   }

   // Define and place Forests
   int forestTreeID = 0;
   numTries=4*cNumberNonGaiaPlayers;
   int failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(250));
         rmSetAreaForestType(forest, "Barbary Forest");
         rmSetAreaForestDensity(forest, 1.0);
         rmSetAreaForestClumpiness(forest, 0.2);
         rmSetAreaForestUnderbrush(forest, 0.0);
         rmSetAreaCoherence(forest, 0.4);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
         rmAddAreaConstraint(forest, forestConstraint);
         rmAddAreaConstraint(forest, avoidAll);
			rmAddAreaConstraint(forest, avoidFastCoinForest);
         rmAddAreaConstraint(forest, avoidImpassableLand);
         rmAddAreaConstraint(forest, avoidTradeRoute);
		  rmAddAreaConstraint(forest, avoidStartingUnits); 
			rmAddAreaConstraint(forest, avoidSocket); 
			rmAddAreaConstraint(forest, Southward); 
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

   // Define and place Forests - now a few to the west too
   numTries=cNumberNonGaiaPlayers*3;
   failCount=0;
   for (i=0; <numTries)
      {   
         forest=rmCreateArea("west forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(300), rmAreaTilesToFraction(350));
         rmSetAreaForestType(forest, "Barbary Forest");
         rmSetAreaForestDensity(forest, 1.0);
         rmSetAreaForestClumpiness(forest, 0.2);
         rmSetAreaForestUnderbrush(forest, 0.0);
         rmSetAreaCoherence(forest, 0.4);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
		 rmAddAreaToClass(forest, rmClassID("classWestForest")); 
         rmAddAreaConstraint(forest, forestConstraint);
		 rmAddAreaConstraint(forest, westForestConstraint);
         rmAddAreaConstraint(forest, avoidAll);
			rmAddAreaConstraint(forest, avoidFastCoinForest);
        rmAddAreaConstraint(forest, avoidImpassableLand); 
        rmAddAreaConstraint(forest, avoidTradeRoute); 
	rmAddAreaConstraint(forest, avoidSocket); 
			rmAddAreaConstraint(forest, Northward); 
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
   
   // Fish
   int fishID=rmCreateObjectDef("fish");
   rmAddObjectDefItem(fishID, "FishSalmon", 3, 6.0);
   rmSetObjectDefMinDistance(fishID, 0.0);
   rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(fishID, fishVsFishID);
   rmAddObjectDefConstraint(fishID, fishLand);
   rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

	// FAST COIN -- WHALES (reasonable in Bahia, right?)
	int whaleID=rmCreateObjectDef("whale");
   rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 9.0);
   rmSetObjectDefMinDistance(whaleID, 0.0);
   rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
   rmAddObjectDefConstraint(whaleID, whaleLand);
   rmAddObjectDefConstraint(whaleID, whaleVsMountain);
   rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

   // Text
   rmSetStatusText("",0.90);

	// HACK replacing bighorn with armadillo for now.
   int bighornID=rmCreateObjectDef("bighorn sheep herd");
	rmAddObjectDefItem(bighornID, "Gazelle", rmRandInt(5,7), 6.0);
   rmSetObjectDefMinDistance(bighornID, 0.0);
   rmSetObjectDefMaxDistance(bighornID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(bighornID, avoidBighornSheep);
   rmAddObjectDefConstraint(bighornID, avoidMoose);
	rmAddObjectDefConstraint(bighornID, avoidAll);
   rmAddObjectDefConstraint(bighornID, avoidImpassableLand);
	rmAddObjectDefConstraint(bighornID, Southward);
	rmAddObjectDefConstraint(bighornID, avoidStartingUnits);
	rmAddObjectDefConstraint(bighornID, avoidSocket);
	rmAddObjectDefConstraint(bighornID, avoidTradeRoute);
   rmSetObjectDefCreateHerd(bighornID, true);
	rmPlaceObjectDefAtLoc(bighornID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*6);

	int capybaraID=rmCreateObjectDef("capybara flock");
   rmAddObjectDefItem(capybaraID, "deer", rmRandInt(6,7), 10.0);
   rmSetObjectDefMinDistance(capybaraID, 0.0);
   rmSetObjectDefMaxDistance(capybaraID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(capybaraID, avoidBighornSheep);
	rmAddObjectDefConstraint(capybaraID, avoidAll);
   rmAddObjectDefConstraint(capybaraID, avoidImpassableLand);
    rmAddObjectDefConstraint(capybaraID, avoidStartingUnits);
	rmAddObjectDefConstraint(capybaraID, avoidTradeRoute);
//	rmAddObjectDefConstraint(capybaraID, Eastward);
   rmSetObjectDefCreateHerd(capybaraID, true);
	rmPlaceObjectDefAtLoc(capybaraID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

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
