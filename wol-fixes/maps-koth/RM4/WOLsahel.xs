// SAHEL

include "mercenaries.xs";
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


	// Which map - four possible variations (excluding which end the players start on, which is a separate thing)

   // Picks the map size
	if(cNumberTeams > 2)
		int playerTiles=15000;
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
	//	rmAddMapTerrainByHeightInfo("yukon\ground2_yuk", 6.0, 9.0, 1.0);
	//	rmAddMapTerrainByHeightInfo("yukon\ground3_yuk", 9.0, 16.0);
	rmSetBaseTerrainMix("sahel_mix");
	rmTerrainInitialize("deccan\ground_grass3_deccan", 4);
	rmSetMapType("AFRICANdesert");
	rmSetMapType("AFRICANsavannah");
	rmSetMapType("grass");
	rmSetMapType("land");
	rmSetLightingSet("carribean");

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

	int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
	int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));

   
	// Player constraints
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 20.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("stay far away from players", classPlayer, 50.0);
 
   // Nature avoidance
	int avoidForest=rmCreateClassDistanceConstraint("forest avoids forest", rmClassID("classForest"), 20.0);
	int avoidForestFar=rmCreateClassDistanceConstraint("forest avoids forest far", rmClassID("classForest"), 50.0);
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
 

   int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));
   int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
	
   // Decoration avoidance
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 8.0);


   // -------------Define objects
   // These objects are all defined so they can be placed later

	rmSetStatusText("",0.10);

	float topOrBottom = rmRandFloat(0.0, 1.0);

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	if ( cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 5 || cNumberNonGaiaPlayers == 7)
		rmSetPlacementSection(0.35, 0.79);
	else
		rmSetPlacementSection(0.40, 0.84);
	rmPlacePlayersCircular(0.4, 0.4, 0.0);




   // DESERT AREA
	int eastIslandID = rmCreateArea("east island");
	rmSetAreaLocation(eastIslandID, 1, 1); 
	rmSetAreaWarnFailure(eastIslandID, false);
	rmSetAreaSize(eastIslandID, 0.3, 0.3);
	rmSetAreaCoherence(eastIslandID, 0.4);
	rmAddAreaInfluenceSegment(eastIslandID, 0.6, 1.0, 1.0, 0.6); 
  rmAddAreaTerrainLayer(eastIslandID, "sahel\ground2_sahel", 0, 4);
  rmAddAreaTerrainLayer(eastIslandID, "sahel\ground_transition_sahel", 4, 8);
	rmSetAreaElevationType(eastIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(eastIslandID, 3.0);
	rmSetAreaBaseHeight(eastIslandID, 4.0);
	rmSetAreaElevationMinFrequency(eastIslandID, 0.12);
	rmSetAreaElevationOctaves(eastIslandID, 4);
	rmSetAreaElevationPersistence(eastIslandID, 0.5);
	rmSetAreaElevationNoiseBias(eastIslandID, 1);
   
	rmSetAreaObeyWorldCircleConstraint(eastIslandID, false);
	rmSetAreaMix(eastIslandID, "sahara");


   // Text
   rmSetStatusText("",0.20);

   // SOUTHERN SAVANNAH-WOODLANDS
	int westIslandID = rmCreateArea("west island");
	rmSetAreaLocation(westIslandID, 0, 0);
	rmSetAreaWarnFailure(westIslandID, false);
	rmSetAreaSize(westIslandID, 0.23, 0.23);
	rmSetAreaCoherence(westIslandID, 0.4);
	rmAddAreaInfluenceSegment(westIslandID, 0.3, 0.0, 0.0, 0.3); 
  rmAddAreaTerrainLayer(westIslandID, "texas\ground3_tex", 0, 7);
	rmSetAreaElevationType(westIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(westIslandID, 4.0);
	rmSetAreaBaseHeight(westIslandID, 4.0);
	rmSetAreaElevationMinFrequency(westIslandID, 0.07);
	rmSetAreaElevationOctaves(westIslandID, 4);
	rmSetAreaElevationPersistence(westIslandID, 0.5);
	rmSetAreaElevationNoiseBias(westIslandID, 1); 
   
	rmSetAreaObeyWorldCircleConstraint(westIslandID, false);
	rmSetAreaMix(westIslandID, "texas_grass");

   rmBuildAllAreas();





   // Text
   rmSetStatusText("",0.30);


//TRADE ROUTE NORTH - SOUTH
   int tradeRouteID = rmCreateTradeRoute();
    
    int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
    rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

    rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
    rmSetObjectDefAllowOverlap(socketID, true);
    rmSetObjectDefMinDistance(socketID, 0.0);
    rmSetObjectDefMaxDistance(socketID, 8.0);

    rmAddTradeRouteWaypoint(tradeRouteID, 1, 1);
    rmAddTradeRouteWaypoint(tradeRouteID, .5, .5);
    rmAddTradeRouteWaypoint(tradeRouteID, 0, 0);
    
rmBuildTradeRoute(tradeRouteID, "ShortCamelTrain");
    
    // add the sockets along the trade route.
    vector socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.2);
    rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   
    socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.8);
    rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

    int timbuktuEast = rmCreateGrouping("timbuktuEast", "Timbuktu City East");
    rmAddGroupingToClass(timbuktuEast, rmClassID("importantItem"));
    rmAddGroupingToClass(timbuktuEast, rmClassID("natives"));
    rmPlaceGroupingAtLoc(timbuktuEast, 0, 0.53, 0.47);

    int timbuktuwest = rmCreateGrouping("timbuktuwest", "Timbuktu City West");
    rmAddGroupingToClass(timbuktuwest, rmClassID("importantItem"));
    rmAddGroupingToClass(timbuktuwest, rmClassID("natives"));
    rmPlaceGroupingAtLoc(timbuktuwest, 0, 0.47, 0.53);


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


float AURTypes = rmRandFloat(0, 1); 

	//Top Left Village
	int topleftVillageID = -1;
if(AURTypes > .5) 
{
    rmSetSubCiv(0, "AURSalt"); 
	topleftVillageID = rmCreateGrouping("Maya village Top Left", "AURsalt timbuktu "+rmRandInt(1,3));
}
else
{
    rmSetSubCiv(0, "AURLiterature"); 
	topleftVillageID = rmCreateGrouping("Maya village Top Left", "AURliterature timbuktu "+rmRandInt(1,3));
}

	rmSetGroupingMinDistance(topleftVillageID, 0.0);
	rmSetGroupingMaxDistance(topleftVillageID, 0.20);
	rmAddGroupingToClass(topleftVillageID, rmClassID("natives"));
	rmAddGroupingToClass(topleftVillageID, rmClassID("importantItem"));
	rmPlaceGroupingInArea(topleftVillageID, 0, westIslandID, 1);

	//Top Left Village
	int bottomleftVillageID = -1;
if(AURTypes > .5) 
{
    rmSetSubCiv(1, "AURSlaves"); 
	bottomleftVillageID = rmCreateGrouping("Maya village Bottom Left", "AURslaves timbuktu "+rmRandInt(1,3));
}
else
{
    rmSetSubCiv(1, "AURIvory"); 
	bottomleftVillageID = rmCreateGrouping("Maya village Bottom Left", "AURivory timbuktu "+rmRandInt(1,3));
}
	rmSetGroupingMinDistance(bottomleftVillageID, 0.0);
	rmSetGroupingMaxDistance(bottomleftVillageID, 0.20);
	rmAddGroupingToClass(bottomleftVillageID, rmClassID("natives"));
	rmAddGroupingToClass(bottomleftVillageID, rmClassID("importantItem"));
	rmPlaceGroupingInArea(bottomleftVillageID, 0, eastIslandID, 1);

	//Top Right Village
	int topRightVillageID = -1;
	if(AURTypes > .5) 
{
    rmSetSubCiv(2, "AURIncense"); 
	topRightVillageID = rmCreateGrouping("Maya village Top Right", "AURincense timbuktu "+rmRandInt(1,3));
}
else
{
    rmSetSubCiv(2, "AURCoffee"); 
	topRightVillageID = rmCreateGrouping("Maya village Top Right", "AURcoffee timbuktu "+rmRandInt(1,3));
}
	rmSetGroupingMinDistance(topRightVillageID, 0.0);
	rmSetGroupingMaxDistance(topRightVillageID, 0.20);
	rmAddGroupingToClass(topRightVillageID, rmClassID("natives"));
	rmAddGroupingToClass(topRightVillageID, rmClassID("importantItem"));
	rmPlaceGroupingInArea(topRightVillageID, 0, westIslandID, 1);


	//Bottom Right Village
	int bottomRightVillageID = -1;
if(AURTypes > .5) {
    rmSetSubCiv(3, "AURGold"); 
	bottomRightVillageID = rmCreateGrouping("Maya village Bottom Right", "AURgold timbuktu "+rmRandInt(1,3));
}
else
{
    rmSetSubCiv(3, "AURRubber"); 
	bottomRightVillageID = rmCreateGrouping("Maya village Bottom Right", "AURrubber timbuktu "+rmRandInt(1,3));
}
	rmSetGroupingMinDistance(bottomRightVillageID, 0.0);
	rmSetGroupingMaxDistance(bottomRightVillageID, 0.20);
	rmAddGroupingToClass(bottomRightVillageID, rmClassID("natives"));
	rmAddGroupingToClass(bottomRightVillageID, rmClassID("importantItem"));
	rmPlaceGroupingInArea(bottomRightVillageID, 0, eastIslandID, 1);


	// Text
	rmSetStatusText("",0.50);


	int failCount = -1;
	int numTries=cNumberNonGaiaPlayers+2;


	// PLAYER STARTING RESOURCES

  // choose African Huntables
    int AfricanHuntableArray = xsArrayCreateString(9, "", "");

    xsArraySetString(AfricanHuntableArray, 1, "Gnu");
    xsArraySetString(AfricanHuntableArray, 2, "ypWildElephant");
    xsArraySetString(AfricanHuntableArray, 3, "Ostrich");
    xsArraySetString(AfricanHuntableArray, 4, "Giraffe");
    xsArraySetString(AfricanHuntableArray, 5, "Zebra");
    xsArraySetString(AfricanHuntableArray, 6, "Antelope");
    xsArraySetString(AfricanHuntableArray, 7, "Gazelle");
    xsArraySetString(AfricanHuntableArray, 8, "Oryx");
    xsArraySetString(AfricanHuntableArray, 9, "Camel");

  string DesertHuntable = xsArrayGetString(AfricanHuntableArray, rmRandInt(8, 9));
  string SavannahHuntable = xsArrayGetString(AfricanHuntableArray, rmRandInt(1, 5));
  string SahelHuntable1 = xsArrayGetString(AfricanHuntableArray, rmRandInt(1, 9));
  string SahelHuntable2 = xsArrayGetString(AfricanHuntableArray, rmRandInt(1, 9));
  string StarterHuntable = xsArrayGetString(AfricanHuntableArray, rmRandInt(1, 9));

	rmClearClosestPointConstraints();
	int TCfloat = -1;
	if (cNumberTeams == 2)
	{
		if (cNumberNonGaiaPlayers > 2)
			TCfloat = 90;
		else if (cNumberNonGaiaPlayers > 5)
			TCfloat = 120;
		else 
			TCfloat = 55;
	}
	else 
		TCfloat = 50;
    

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
	rmAddObjectDefConstraint(TCID, avoidRiverFar);
	rmAddObjectDefConstraint(TCID, avoidAll);
	//rmAddGroupingConstraint(TCID, avoidNativesFar);
	rmAddObjectDefConstraint(TCID, mediumShortAvoidImpassableLand);

	int playerSilverID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerSilverID, "MineGold", 2, 9);
	rmAddObjectDefConstraint(playerSilverID, avoidTownCenter);
	rmSetObjectDefMinDistance(playerSilverID, 15.0);
	rmSetObjectDefMaxDistance(playerSilverID, 20.0);
    rmAddObjectDefConstraint(playerSilverID, avoidImpassableLand);

	int playerCapybaraID=rmCreateObjectDef("player Capybara");
    rmAddObjectDefItem(playerCapybaraID, StarterHuntable, rmRandInt(3,4), 10.0);
    rmSetObjectDefMinDistance(playerCapybaraID, 10);
    rmSetObjectDefMaxDistance(playerCapybaraID, 18);
	rmAddObjectDefConstraint(playerCapybaraID, avoidAll);
    rmAddObjectDefConstraint(playerCapybaraID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerCapybaraID, avoidCliff);
    rmSetObjectDefCreateHerd(playerCapybaraID, true);

	int playerNuggetID= rmCreateObjectDef("player nugget"); 
	rmAddObjectDefItem(playerNuggetID, "Peanuts", rmRandInt(3,5), 2.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);
  	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
	rmAddObjectDefConstraint(playerNuggetID, avoidCliff);
	rmSetObjectDefMinDistance(playerNuggetID, 40.0);
	rmSetObjectDefMaxDistance(playerNuggetID, 60.0);


	int playerTreeID=rmCreateObjectDef("player trees");
    rmAddObjectDefItem(playerTreeID, "ypGoat", rmRandInt(3,4), 8.0);
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
	rmPlaceObjectDefAtLoc(nuggeteasyID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);

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
	rmPlaceObjectDefAtLoc(nuggetmediumEastID, 0, 0.5, 0.5, 3);

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
	rmPlaceObjectDefAtLoc(nuggetmediumWestID, 0, 0.5, 0.5, 3);

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
	rmPlaceObjectDefAtLoc(nuggethardID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);

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
		rmPlaceObjectDefAtLoc(nuggethard2ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);
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




	rmSetStatusText("",0.70);
 
	int silverType = -1;
	int silverCount = (cNumberNonGaiaPlayers + rmRandInt(1,2));
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
		rmAddObjectDefConstraint(silverID, Southward);
	  //rmAddObjectDefConstraint(silverID, eastIslandID);
	  rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
   }


	for(i=0; < silverCount)
	{
	  int silverWestID = rmCreateObjectDef("silverWest "+i);
	  rmAddObjectDefItem(silverWestID, "MineSalt", 1, 0.0);
      rmSetObjectDefMinDistance(silverWestID, 0.0);
      rmSetObjectDefMaxDistance(silverWestID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(silverWestID, avoidCoin);
      rmAddObjectDefConstraint(silverWestID, avoidAll);
      rmAddObjectDefConstraint(silverWestID, avoidTownCenterFar);
	  rmAddObjectDefConstraint(silverWestID, avoidNatives);
      rmAddObjectDefConstraint(silverWestID, avoidImpassableLand);
	  //rmAddObjectDefConstraint(silverWestID, westIslandID);
	  rmAddObjectDefConstraint(silverWestID, coinEdgeConstraint);
		rmAddObjectDefConstraint(silverWestID, Northward);
	  rmPlaceObjectDefAtLoc(silverWestID, 0, 0.5, 0.5);
   }


	//Mines to fill in the large gaps

	silverCount = 2;
	for(i=0; < silverCount)
	{
	int silverEastRandomID = rmCreateObjectDef("silverEastRandom "+i);
	rmAddObjectDefItem(silverEastRandomID, "ypGoat", 2, 0.0);
	rmSetObjectDefMinDistance(silverEastRandomID, 0.0);
	rmSetObjectDefMaxDistance(silverEastRandomID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(silverEastRandomID, avoidCoinFar);
	rmAddObjectDefConstraint(silverEastRandomID, avoidAll);
	rmAddObjectDefConstraint(silverEastRandomID, avoidNativesFar);
	rmAddObjectDefConstraint(silverEastRandomID, longAvoidImpassableLand);
	rmAddObjectDefConstraint(silverEastRandomID, coinEdgeConstraint);
	rmPlaceObjectDefAtLoc(silverEastRandomID, 0, 0.25, 0.5);
	}

	silverCount = 2;
	for(i=0; < silverCount)
	{
	  int silverWestRandomID = rmCreateObjectDef("silverWestRandom "+i);
	  rmAddObjectDefItem(silverWestRandomID, "ypGoat", 2, 0.0);
      rmSetObjectDefMinDistance(silverWestRandomID, 0.0);
      rmSetObjectDefMaxDistance(silverWestRandomID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(silverWestRandomID, avoidCoinFar);
      rmAddObjectDefConstraint(silverWestRandomID, avoidAll);
	  rmAddObjectDefConstraint(silverWestRandomID, avoidNativesFar);
      rmAddObjectDefConstraint(silverWestRandomID, longAvoidImpassableLand);
	  rmAddObjectDefConstraint(silverWestRandomID, coinEdgeConstraint);
	  rmPlaceObjectDefAtLoc(silverWestRandomID, 0, 0.75, 0.5);
   }



	rmSetStatusText("",0.80);

	// Forest areas

	if (cNumberNonGaiaPlayers > 4)
		numTries=2*cNumberNonGaiaPlayers;
	else
		numTries=3*cNumberNonGaiaPlayers;
	failCount=0;
	for (i=0; <numTries)
		{   
			int forestID=rmCreateArea("forestID"+i, westIslandID);
			rmSetAreaWarnFailure(forestID, false);
			rmSetAreaSize(forestID, rmAreaTilesToFraction(160), rmAreaTilesToFraction(200));
			rmSetAreaForestType(forestID, "Texas Forest");
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
		numTries=2*cNumberNonGaiaPlayers;
	else
		numTries=3*cNumberNonGaiaPlayers; 
	failCount=0;
	for (i=0; <numTries)
		{   
			int forestEastID=rmCreateArea("forestEastID"+i, eastIslandID);
			rmSetAreaWarnFailure(forestEastID, false);
			rmSetAreaSize(forestEastID, rmAreaTilesToFraction(80), rmAreaTilesToFraction(100));
			rmSetAreaForestType(forestEastID, "African Desert Forest");
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

	numTries=4*cNumberNonGaiaPlayers;  
	failCount=0;
	for (i=0; <numTries)
		{   
			int forestRandomID=rmCreateArea("forestRandomID"+i);
			rmSetAreaWarnFailure(forestRandomID, false);
			rmSetAreaSize(forestRandomID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(400));
			rmSetAreaForestType(forestRandomID, "Acacia Forest");
			rmSetAreaForestDensity(forestRandomID, 0.4);
			rmSetAreaForestClumpiness(forestRandomID, 0.02);		
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
		{int tapirCount =cNumberNonGaiaPlayers;}
	else
		{tapirCount =0.5*cNumberNonGaiaPlayers;}

	rmEchoInfo("tapir count = "+tapirCount);
	
	for (i=0; <tapirCount)
		{
	int tapirEastID = rmCreateObjectDef("tapir east herd " +i);
	rmAddObjectDefItem(tapirEastID, SahelHuntable2, rmRandInt(3,4), 4);
	rmSetObjectDefMinDistance(tapirEastID, 0.0);
	rmSetObjectDefMaxDistance(tapirEastID, rmXFractionToMeters(0.8));
	rmAddObjectDefConstraint(tapirEastID, avoidTapirFar);
	rmAddObjectDefConstraint(tapirEastID, avoidCapybara);
	rmAddObjectDefConstraint(tapirEastID, avoidAll);
	rmAddObjectDefConstraint(tapirEastID, avoidNativesFar);
	rmAddObjectDefConstraint(tapirEastID, avoidCliff);
	rmSetObjectDefCreateHerd(tapirEastID, true);
	
	rmPlaceObjectDefAtLoc(tapirEastID, 0, 0.5, 0.5);
		}

	for (i=0; <tapirCount)
		{
	int tapirWestID = rmCreateObjectDef("tapir west herd " +i);
	rmAddObjectDefItem(tapirWestID, SahelHuntable1, rmRandInt(4,5), 10);
	rmSetObjectDefMinDistance(tapirWestID, 0.0);
	rmSetObjectDefMaxDistance(tapirWestID, rmXFractionToMeters(0.8));
	rmAddObjectDefConstraint(tapirWestID, avoidTapirFar);
	rmAddObjectDefConstraint(tapirWestID, avoidCapybara);
	rmAddObjectDefConstraint(tapirWestID, avoidAll);
	rmAddObjectDefConstraint(tapirWestID, avoidNativesFar);
	rmSetObjectDefCreateHerd(tapirWestID, true);
	rmPlaceObjectDefAtLoc(tapirWestID, 0, 0.5, 0.5, 2);
		}

	rmSetStatusText("",0.90);

		for (i=0; <tapirCount)
		{
			int tapirRandomID = rmCreateObjectDef("tapir random herd " +i);
			rmAddObjectDefItem(tapirRandomID, "Camel", rmRandInt(1,2), 1);
			rmSetObjectDefMinDistance(tapirRandomID, 0.0);
			rmSetObjectDefMaxDistance(tapirRandomID, rmXFractionToMeters(1.0));
			rmAddObjectDefConstraint(tapirRandomID, avoidTapirFar);
			rmAddObjectDefConstraint(tapirRandomID, avoidCapybara);
			rmAddObjectDefConstraint(tapirRandomID, avoidAll);
			rmSetObjectDefCreateHerd(tapirRandomID, true);
			rmPlaceObjectDefInArea(tapirRandomID, 0, eastIslandID, cNumberNonGaiaPlayers+2);
		}
		for (i=0; <tapirCount)
		{
			int elephantID = rmCreateObjectDef("elephant herd " +i);
			rmAddObjectDefItem(elephantID, SavannahHuntable, rmRandInt(1,3), 1);
			rmSetObjectDefMinDistance(elephantID, 0.02);
			rmSetObjectDefMaxDistance(elephantID, 0.1);
			rmAddObjectDefConstraint(elephantID, avoidTapirFar);
			rmAddObjectDefConstraint(elephantID, avoidCapybara);
			rmAddObjectDefConstraint(elephantID, avoidAll);
			rmSetObjectDefCreateHerd(elephantID, true);
			rmPlaceObjectDefInArea(elephantID, 0, westIslandID, cNumberNonGaiaPlayers);

		}

			int vultureID = rmCreateObjectDef("perching vultures " +i);
			rmAddObjectDefItem(vultureID, "PropVulturePerching", 1, 0);
			rmSetObjectDefMinDistance(vultureID, 0.04);
			rmSetObjectDefMaxDistance(vultureID,0.1);
			rmAddObjectDefConstraint(vultureID, avoidTapirFar);
			rmAddObjectDefConstraint(vultureID, avoidCapybara);
			rmAddObjectDefConstraint(vultureID, avoidAll);
			rmAddObjectDefConstraint(vultureID, avoidNativesFar);
			rmAddObjectDefConstraint(vultureID, avoidRiver);
			rmPlaceObjectDefAtLoc(vultureID, 0, 0.5, 0.5, 5);


	// Text
	rmSetStatusText("",1.0);

  // King of the Hill (added 2026-11 for WoL): centre, beside the central trade route
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
