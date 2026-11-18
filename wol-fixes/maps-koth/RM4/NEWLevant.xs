// Levant
// Over Gujarat

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
include "triggers\triggerLoader.xs";

// Main entry point for random map script
void main(void)
{
   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);


   //Chooses which natives appear on the map
   int subCiv0=-1;
   int subCiv1=-1;

   if (rmAllocateSubCivs(2) == true)
   {

	  if(rmRandFloat(0,1) < 0.65)

	  {
		  subCiv0=rmGetCivID("Bhakti");
      rmEchoInfo("subCiv0 is Bhakti "+subCiv0);
	  if (subCiv0 >= 0)
		 rmSetSubCiv(0, "Bhakti");
	  }
      else
	  {
		subCiv0=rmGetCivID("Sufi");
      rmEchoInfo("subCiv0 is Sufi "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Sufi");
	  }
	  
	  if (rmRandFloat(0,1) < 0.65)
	  {
		subCiv1=rmGetCivID("Sufi");
      rmEchoInfo("subCiv1 is Sufi "+subCiv1);
      if (subCiv1 >= 0)
         rmSetSubCiv(1, "Sufi");
      }
	  else
	  {
		  subCiv1=rmGetCivID("Bhakti");
      rmEchoInfo("subCiv1 is Bhakti "+subCiv1);
	  if (subCiv1 >= 0)
		 rmSetSubCiv(1, "Bhakti");
	  }
   }


	// Picks the map size
	
	if (rmGetNumberPlayersOnTeam(0) == rmGetNumberPlayersOnTeam(1))
		int playerTiles=11820;
	else
		playerTiles=12320;

	if (cNumberNonGaiaPlayers<3)
		int size=2.3*sqrt(cNumberNonGaiaPlayers*playerTiles);
	else
		size=2.5*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Some map turbulence...
	rmSetMapElevationParameters(cElevTurbulence, 0.09, 1, 0.7, 2.0);  // Like Texas for the moment.
	rmSetMapElevationHeightBlend(0.2);

	// Picks a default water height
	rmSetSeaLevel(2.0);

	// Picks default terrain and water
	rmSetSeaType("Maltese Coast");
	rmEnableLocalWater(true);
	rmSetBaseTerrainMix("punjab_grass2");
	rmTerrainInitialize("yukon\ground4_yuk", 2.5);
	rmSetMapType("mashriq");
	rmSetMapType("water");
	rmSetMapType("grass");
	rmSetMapType("land");
	rmSetWorldCircleConstraint(true);
	rmSetWindMagnitude(9.0);
   rmSetLightingSet("sonora");
	chooseMercs();
wotta_triggers();

	// Define some classes. These are used later for constraints.
	int classPlayer=rmDefineClass("player");
	rmDefineClass("classCliff");
	rmDefineClass("classPatch");
	int classbigContinent=rmDefineClass("big continent");
	rmDefineClass("corner");
	rmDefineClass("starting settlement");
	rmDefineClass("startingUnit");
	rmDefineClass("classForest");
	rmDefineClass("natives");
	rmDefineClass("importantItem");
	rmDefineClass("secrets");
	rmDefineClass("flag");
	rmDefineClass("classHillArea");
	rmDefineClass("lake");
	int randomClass = rmDefineClass("randomAreaClass");
	// Player placement
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);

   // -------------Define constraints
   // These are used to have objects and areas avoid each other
   
	// Map edge constraintsw
	//int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(28), rmZTilesToFraction(28), 1.0-rmXTilesToFraction(28), 1.0-rmZTilesToFraction(28), 0.01);
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.40), rmDegreesToRadians(0), rmDegreesToRadians(360));
	
	int randomAreaConstraint=rmCreateClassDistanceConstraint("continent avoids random areas", randomClass, 20.0);

	// Player constraints
	int playerConstraint=rmCreateClassDistanceConstraint("player vs. player", classPlayer, 30.0);
	int playerForestConstraint=rmCreateClassDistanceConstraint("forest vs. player", rmClassID("classForest"), 8.0);
	int Northconstraint = rmCreateBoxConstraint("stay in North portion", 0, 0, 1, 0.5);
	int Southconstraint = rmCreateBoxConstraint("stay in South portion", 0, 0, 0.5, 1);
	int Eastconstraint = rmCreateBoxConstraint("stay in Far East portion", 0, .7, 1, 0);
	int EastForestconstraint = rmCreateBoxConstraint("stay in East portion", 0.4, 0.0, 0.8, 1.0);
	int WestForestconstraint = rmCreateBoxConstraint("stay in Far West portion", 0, 1, 0.60, 0);
	int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
	int Centralconstraint = rmCreateBoxConstraint("stay in Central portion", 0.25, 0.25, 0.75, 0.75);
	int smallMapPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 70.0);
	int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 20.0);
	int flagEdgeConstraint = rmCreatePieConstraint("flags stay near edge of map", 0.5, 0.5, rmGetMapXSize()-180, rmGetMapXSize()-40, 0, 0, 0);
	int nearWater10 = rmCreateTerrainDistanceConstraint("near water", "Water", true, 10.0);
	int shipVsShip=rmCreateTypeDistanceConstraint("ships avoid ship", "ship", 5.0);

	// Bonus area constraint
	int bigContinentConstraint=rmCreateClassDistanceConstraint("avoid bonus island", classbigContinent, 20.0);

	// Resource avoidance
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 18.0);
	int cliffConstraint=rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 40.0);
	int avoidCliff=rmCreateClassDistanceConstraint("stuff vs. cliff", rmClassID("classCliff"), 10.0);
	int shortAvoidCliff=rmCreateClassDistanceConstraint("short stuff vs. cliff", rmClassID("classCliff"), 8.0);
	int avoidDeer=rmCreateTypeDistanceConstraint("food avoids food", "ypNilgai", 50.0);
	int avoidElk=rmCreateTypeDistanceConstraint("elk avoids elk", "elk", 40.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("coin avoids coin", "gold", 45.0);
	int avoidCoinFar=rmCreateTypeDistanceConstraint("coin avoids coin Far", "gold", 75.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 50.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 28.0);
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 60.0);
	int avoidHomeCityWaterSpawnFlag=rmCreateTypeDistanceConstraint("avoid HomeCityWaterSpawnFlag", "HomeCityWaterSpawnFlag", 20.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 15);
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 18.0);
    int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 50.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 25.0);
	int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 55.0);

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 10.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 25.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int mediumAvoidImpassableLand=rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 15.0);
	int mediumShortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("mediumshort avoid impassable land", "Land", false, 10.0);
	int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 5.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 20.0);
	int avoidLake = rmCreateTerrainDistanceConstraint("avoid lake", "Land", false, 10.0);

   // Unit avoidance
   int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 10.0);

   // Decoration avoidance
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.9);

   // VP avoidance
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 12.0);
   int avoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("trade route short", 4.0);
   int nativeAvoidTradeRouteSocket = rmCreateTypeDistanceConstraint("avoid trade route socket", "socketTradeRoute", 20.0);
   int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 30.0);


   // Text
   rmSetStatusText("",0.10);

	// DEFINE AREAS

   // Set up player starting locations. 


	rmSetTeamSpacingModifier(0.4);


	if(cNumberTeams > 2) //ffa
	{
		rmSetPlacementSection(0.00, 0.90);
		rmSetTeamSpacingModifier(0.40);
		rmPlacePlayersCircular(0.45, 0.45, 0);
	}
	else
	{
		int teamStartLoc = rmRandInt(1, 2);
		int teamOne = -1;
		int teamTwo = -1;
		
		if (teamStartLoc == 1) 
		{
			teamOne = 0;
			teamTwo = 1;
		}
		else
		{
			teamOne = 1;
			teamTwo = 0;
		}
		if (cNumberNonGaiaPlayers == 2)
		{
			rmSetPlacementTeam(teamOne);
			rmPlacePlayersLine(0.50, 1.00, 0.52, 0.98, 0.04, 0.02);
			rmSetTeamSpacingModifier(0.05);
			rmSetPlacementTeam(teamTwo);
			rmPlacePlayersLine(0.00, 0.50, 0.02, 0.48, 0.04, 0.02);
			rmSetTeamSpacingModifier(0.05);
		}
		else 
		{			
			rmSetPlacementTeam(teamOne);
			rmPlacePlayersLine(0.50, 1.00, 0.80, 0.70, 0.04, 0.02);
			rmSetTeamSpacingModifier(0.20);
			rmSetPlacementTeam(teamTwo);
			rmPlacePlayersLine(0.00, 0.50, 0.30, 0.20, 0.04, 0.02);
			rmSetTeamSpacingModifier(0.10);
		}
	}

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
		rmAddAreaConstraint(id, playerEdgeConstraint); //this is for land only
		rmSetAreaLocPlayer(id, i);
		rmSetAreaWarnFailure(id, false);

	}

	// Build the areas.
	rmBuildAllAreas();
	

   // Text
   rmSetStatusText("",0.20);

	int BayID=rmCreateArea("Bay");
	rmSetAreaSize(BayID, 0.17, 0.17);
	rmSetAreaWaterType(BayID, "Maltese Coast");
		if (cNumberNonGaiaPlayers >= 4)
			rmSetAreaCoherence(BayID, 0.96);
		else
			rmSetAreaCoherence(BayID, 0.98);
	rmSetAreaLocation(BayID, 0.15, 0.85);
	rmAddAreaInfluencePoint(BayID, 0.05, 0.75);
	rmAddAreaInfluencePoint(BayID, 0.15, 0.85);
	rmAddAreaInfluencePoint(BayID, 0.25, 0.95);
	rmSetAreaBaseHeight(BayID, 2.0);
	rmSetAreaObeyWorldCircleConstraint(BayID, false);
	rmSetAreaMinBlobs(BayID, 0);
	rmSetAreaMaxBlobs(BayID, 1);
	rmSetAreaMinBlobDistance(BayID, 1);
	rmSetAreaMaxBlobDistance(BayID, 2);
	rmSetAreaSmoothDistance(BayID, 0);
	rmBuildArea(BayID); 

   rmSetStatusText("",0.20);

	int DesertID=rmCreateArea("desert");
	rmSetAreaSize(DesertID, 0.25, 0.25);
	rmSetAreaMix(DesertID, "texas_dirt");
	rmAddAreaTerrainLayer(DesertID, "texas\ground2_tex", 0, 4);
	rmAddAreaTerrainLayer(DesertID, "texas\ground3_tex", 4, 8);
	rmSetAreaCoherence(DesertID, 0.9);
	rmSetAreaLocation(DesertID, 0.85, 0.15);
	rmAddAreaInfluencePoint(DesertID, 0.75, 0.05);
	rmAddAreaInfluencePoint(DesertID, 0.85, 0.15);
	rmAddAreaInfluencePoint(DesertID, 0.95, 0.25);
	rmSetAreaBaseHeight(DesertID, 2.0);
	rmSetAreaObeyWorldCircleConstraint(DesertID, false);
	rmSetAreaMinBlobs(DesertID, 0);
	rmSetAreaMaxBlobs(DesertID, 1);
	rmSetAreaMinBlobDistance(DesertID, 5);
	rmSetAreaMaxBlobDistance(DesertID, 8);
	rmSetAreaSmoothDistance(DesertID, 0);
	rmBuildArea(DesertID); 

	int InvDesertID=rmCreateArea("invisible desert obstruction");
	rmSetAreaSize(InvDesertID, 0.05, 0.05);
	//rmSetAreaMix(InvDesertID, "texas_grass");
    rmAddAreaToClass(InvDesertID, rmClassID("classForest")); 
	rmSetAreaCoherence(InvDesertID, 0.99);
	rmSetAreaLocation(InvDesertID, 0.75, 0.25);
	rmAddAreaInfluencePoint(InvDesertID, 0.65, 0.15);
	rmAddAreaInfluencePoint(InvDesertID, 0.75, 0.25);
	rmAddAreaInfluencePoint(InvDesertID, 0.85, 0.35);
	rmSetAreaBaseHeight(InvDesertID, 2.0);
	rmSetAreaObeyWorldCircleConstraint(InvDesertID, false);
	rmSetAreaMinBlobs(InvDesertID, 6);
	rmSetAreaMaxBlobs(InvDesertID, 9);
	rmSetAreaMinBlobDistance(InvDesertID, 5);
	rmSetAreaMaxBlobDistance(InvDesertID, 9);
	rmSetAreaSmoothDistance(InvDesertID, 0);
	rmBuildArea(InvDesertID);

	rmSetStatusText("",0.30);

// Cliffs
	int Cliffplacement = rmRandInt(1, 2);
//	int Cliffplacement = 2;

	int Cliffs1ID=rmCreateArea("Cliffs 1");
	rmSetAreaSize(Cliffs1ID, 0.07, 0.07);
	rmSetAreaMix(Cliffs1ID, "texas_grass");
	rmSetAreaCoherence(Cliffs1ID, 0.9);
	if (Cliffplacement == 1)
		{
	rmSetAreaLocation(Cliffs1ID, 0.40, 0.60);
	rmAddAreaInfluencePoint(Cliffs1ID, 0.47, 0.67);
	rmAddAreaInfluencePoint(Cliffs1ID, 0.40, 0.60);
	rmAddAreaInfluencePoint(Cliffs1ID, 0.32, 0.52);
}
	else
		{
	rmSetAreaLocation(Cliffs1ID, 0.57, 0.57);
	rmAddAreaInfluencePoint(Cliffs1ID, 0.47, 0.67);
	rmAddAreaInfluencePoint(Cliffs1ID, 0.67, 0.47);
}
	rmSetAreaBaseHeight(Cliffs1ID, 2.0);
	rmSetAreaObeyWorldCircleConstraint(Cliffs1ID, false);
	rmSetAreaMinBlobs(Cliffs1ID, 0);
	rmSetAreaMaxBlobs(Cliffs1ID, 1);
	rmSetAreaMinBlobDistance(Cliffs1ID, 5);
	rmSetAreaMaxBlobDistance(Cliffs1ID, 8);
	rmSetAreaSmoothDistance(Cliffs1ID, 0);
	rmBuildArea(Cliffs1ID); 

	int Cliffs2ID=rmCreateArea("Cliffs 2");
	rmSetAreaSize(Cliffs2ID, 0.07, 0.07);
	rmSetAreaMix(Cliffs2ID, "texas_grass");
	rmSetAreaCoherence(Cliffs2ID, 0.9);
	if (Cliffplacement == 1)
	{
	rmSetAreaLocation(Cliffs2ID, 0.60, 0.40);
	rmAddAreaInfluencePoint(Cliffs2ID, 0.67, 0.47);
	rmAddAreaInfluencePoint(Cliffs2ID, 0.60, 0.40);
	rmAddAreaInfluencePoint(Cliffs2ID, 0.52, 0.32);
}
	else
		{
	rmSetAreaLocation(Cliffs2ID, 0.42, 0.42);
	rmAddAreaInfluencePoint(Cliffs2ID, 0.32, 0.52);
	rmAddAreaInfluencePoint(Cliffs2ID, 0.52, 0.32);
}
	rmSetAreaBaseHeight(Cliffs2ID, 2.0);
	rmSetAreaObeyWorldCircleConstraint(Cliffs2ID, false);
	rmSetAreaMinBlobs(Cliffs2ID, 0);
	rmSetAreaMaxBlobs(Cliffs2ID, 1);
	rmSetAreaMinBlobDistance(Cliffs2ID, 5);
	rmSetAreaMaxBlobDistance(Cliffs2ID, 8);
	rmSetAreaSmoothDistance(Cliffs2ID, 0);
	rmBuildArea(Cliffs2ID); 

	rmSetStatusText("",0.31);

	int CentralCliff1Constraint = rmCreateAreaConstraint("Central Cliff1 Constraint", Cliffs1ID);
	int CentralCliff2Constraint = rmCreateAreaConstraint("Central Cliff2 Constraint", Cliffs2ID);
	int avoidCliff1 = rmCreateAreaDistanceConstraint("avoid cliffs1", Cliffs1ID, 2.0);
	int avoidCliff2 = rmCreateAreaDistanceConstraint("avoid cliffs1", Cliffs2ID, 2.0);
	int avoidDesert = rmCreateAreaDistanceConstraint("avoid desert", DesertID, 10.0);

   int numTries=cNumberNonGaiaPlayers+2;
   for(i=0; <numTries)
   {
      int cliffID=rmCreateArea("cliff"+i);
      //rmSetAreaSize(cliffID, rmAreaTilesToFraction(500), rmAreaTilesToFraction(1000));
	  rmSetAreaSize(cliffID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(700));
      rmSetAreaWarnFailure(cliffID, false);
	  rmSetAreaCliffType(cliffID, "Levant");
	  rmSetAreaCliffEdge(cliffID, 1, 0.8, 0.8, 1.0, 0);
      //rmSetAreaCliffEdge(cliffID, 1, 0.6, 0.1, 1.0, 0);
	  //rmSetAreaCliffEdge(cliffID, 1, 1);
      rmSetAreaCliffPainting(cliffID, false, true, true, 1.5, true);
      rmSetAreaCliffHeight(cliffID, 7, 2.0, 0.5);
      rmSetAreaHeightBlend(cliffID, 1);
      rmAddAreaToClass(cliffID, rmClassID("classCliff")); 
//      rmAddAreaConstraint(cliffID, longAvoidImpassableLand);
      rmAddAreaConstraint(cliffID, cliffConstraint);
//	  rmAddAreaConstraint(cliffID, avoidTownCenterFar);
//      rmAddAreaConstraint(cliffID, avoidImportantItem);
//      rmAddAreaConstraint(cliffID, avoidTradeRoute);
	  rmAddAreaConstraint(cliffID, CentralCliff1Constraint);
//	  rmAddAreaConstraint(cliffID, avoidCoin);
      rmSetAreaMinBlobs(cliffID, 4);
      rmSetAreaMaxBlobs(cliffID, 6);
      rmSetAreaMinBlobDistance(cliffID, 16.0);
      rmSetAreaMaxBlobDistance(cliffID, 30.0);
      rmSetAreaSmoothDistance(cliffID, 10);
      rmSetAreaCoherence(cliffID, 0.75);
      rmBuildArea(cliffID);
   } 

	numTries=cNumberNonGaiaPlayers+2;
   for(i=0; <numTries)
   {
      int cliff02ID=rmCreateArea("cliff2"+i);
      //rmSetAreaSize(cliff02ID, rmAreaTilesToFraction(500), rmAreaTilesToFraction(1000));
	  rmSetAreaSize(cliff02ID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(700));
      rmSetAreaWarnFailure(cliff02ID, false);
	  rmSetAreaCliffType(cliff02ID, "Levant");
	  rmSetAreaCliffEdge(cliff02ID, 1, 0.8, 0.8, 1.0, 0);
      //rmSetAreaCliffEdge(cliff02ID, 1, 0.6, 0.1, 1.0, 0);
	  //rmSetAreaCliffEdge(cliff02ID, 1, 1);
      rmSetAreaCliffPainting(cliff02ID, false, true, true, 1.5, true);
      rmSetAreaCliffHeight(cliff02ID, 7, 2.0, 0.5);
      rmSetAreaHeightBlend(cliff02ID, 1);
      rmAddAreaToClass(cliff02ID, rmClassID("classCliff")); 
//      rmAddAreaConstraint(cliff02ID, longAvoidImpassableLand);
      rmAddAreaConstraint(cliff02ID, cliffConstraint);
//	  rmAddAreaConstraint(cliff02ID, avoidTownCenterFar);
//      rmAddAreaConstraint(cliff02ID, avoidImportantItem);
//      rmAddAreaConstraint(cliff02ID, avoidTradeRoute);
	  rmAddAreaConstraint(cliff02ID, CentralCliff2Constraint);
//	  rmAddAreaConstraint(cliff02ID, avoidCoin);
      rmSetAreaMinBlobs(cliff02ID, 4);
      rmSetAreaMaxBlobs(cliff02ID, 6);
      rmSetAreaMinBlobDistance(cliff02ID, 16.0);
      rmSetAreaMaxBlobDistance(cliff02ID, 30.0);
      rmSetAreaSmoothDistance(cliff02ID, 10);
      rmSetAreaCoherence(cliff02ID, 0.75);
      rmBuildArea(cliff02ID);
   } 

	numTries=cNumberNonGaiaPlayers+2;
   for(i=0; <numTries)
   {
      int patchgrassID=rmCreateArea("grass"+i);
      //rmSetAreaSize(patchgrassID, rmAreaTilesToFraction(500), rmAreaTilesToFraction(1000));
	  rmSetAreaSize(patchgrassID, rmAreaTilesToFraction(200), rmAreaTilesToFraction(500));
	  rmSetAreaMix(patchgrassID, "texas_grass");
      rmSetAreaWarnFailure(patchgrassID, false);
      rmSetAreaHeightBlend(patchgrassID, 1);
      rmAddAreaToClass(patchgrassID, rmClassID("classCliff")); 
      rmAddAreaConstraint(patchgrassID, longAvoidImpassableLand);
      rmAddAreaConstraint(patchgrassID, cliffConstraint);
	  rmAddAreaConstraint(patchgrassID, avoidCliff1);
	  rmAddAreaConstraint(patchgrassID, avoidCliff2);
	  rmAddAreaConstraint(patchgrassID, avoidDesert);
      rmAddAreaConstraint(patchgrassID, avoidImportantItem);
//      rmAddAreaConstraint(patchgrassID, avoidTradeRoute);
//	  rmAddAreaConstraint(patchgrassID, avoidCoin);
      rmSetAreaMinBlobs(patchgrassID, 4);
      rmSetAreaMaxBlobs(patchgrassID, 6);
      rmSetAreaMinBlobDistance(patchgrassID, 16.0);
      rmSetAreaMaxBlobDistance(patchgrassID, 30.0);
      rmSetAreaSmoothDistance(patchgrassID, 10);
      rmSetAreaCoherence(patchgrassID, 0.75);
      rmBuildArea(patchgrassID);
   } 

	// Placement order
   // Trade route -> River (none on this map) -> Natives -> Secrets -> Nuggets

   // Text
   rmSetStatusText("",0.40);

	// TRADE ROUTES
	int tradeRouteID = rmCreateTradeRoute();

	int socketID=rmCreateObjectDef("sockets for Trade Route");
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmAddObjectDefConstraint(socketID, avoidImpassableLand);
	rmAddObjectDefToClass(socketID, rmClassID("importantItem"));
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 0.0);
	rmSetObjectDefMaxDistance(socketID, 10.0);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 1.00);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.80, 0.80, 5, 8);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.90, 0.60, 5, 8);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.80, 0.20, 5, 8);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.40, 0.10, 5, 8);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.20, 0.20, 5, 8);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.00, 0.35, 5, 8);

	bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "ShortCamelTrain");
	if(placedTradeRoute == false)
		rmEchoError("Failed to place trade route"); 

    // add the sockets along the trade route.
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.15);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.35);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.65);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.85);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

		// PLAYER STARTING RESOURCES

   rmClearClosestPointConstraints();
   int TCfloat = -1;
   if (cNumberTeams == 2)
		if (cNumberPlayers > 6)
			TCfloat = 100;
		else if (cNumberPlayers == 2)
			TCfloat = 15;
		else
			TCfloat = 70;
   else 
		TCfloat = 100;
    

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

	rmAddObjectDefConstraint(TCID, avoidTradeRoute);
	if (rmGetNumberPlayersOnTeam(0) == rmGetNumberPlayersOnTeam(1))
		rmAddObjectDefConstraint(TCID, avoidTownCenterFar);
	else
		rmAddObjectDefConstraint(TCID, avoidTownCenter);
	rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, longAvoidImpassableLand);

	//WATER HC ARRIVAL POINT

	int waterFlagID=rmCreateObjectDef("HC water flag");
        rmAddObjectDefItem(waterFlagID, "HomeCityWaterSpawnFlag", 1, 0);
	rmSetObjectDefMinDistance(waterFlagID, 10.0);
	if (cNumberTeams>2)
		rmSetObjectDefMaxDistance(waterFlagID, 150.0);
	else
		rmSetObjectDefMaxDistance(waterFlagID, 100.0);
	rmAddClosestPointConstraint(flagConstraint);
	rmAddClosestPointConstraint(flagEdgeConstraint);

	int playergoldID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playergoldID, "Mine", 1, 0);
	rmAddObjectDefConstraint(playergoldID, avoidTradeRoute);
	rmAddObjectDefConstraint(playergoldID, avoidCliff);
	rmSetObjectDefMinDistance(playergoldID, 10.0);
	rmSetObjectDefMaxDistance(playergoldID, 15.0);
    rmAddObjectDefConstraint(playergoldID, avoidImpassableLand);

	float sheepstart = rmRandFloat(0.0, 1.0);
	int playerSheepID = rmCreateObjectDef("player sheep");
	if(sheepstart < 0.5)
		{
		rmAddObjectDefItem(playerSheepID, "DatePalm", rmRandInt(5,8), 8.0);
		rmSetObjectDefMinDistance(playerSheepID, 10);
		rmSetObjectDefMaxDistance(playerSheepID, 16);
		rmAddObjectDefConstraint(playerSheepID, avoidAll);
		rmAddObjectDefConstraint(playerSheepID, avoidImpassableLand);
		rmAddObjectDefConstraint(playerSheepID, avoidCliff);
		}
	else
		{
		rmAddObjectDefItem(playerSheepID, "ypGoat", rmRandInt(2,3), 2.0);
		rmSetObjectDefMinDistance(playerSheepID, 10);
		rmSetObjectDefMaxDistance(playerSheepID, 16);
		rmAddObjectDefConstraint(playerSheepID, avoidAll);
		rmAddObjectDefConstraint(playerSheepID, avoidImpassableLand);
		rmAddObjectDefConstraint(playerSheepID, avoidCliff);
		}

	int playerDeerID=rmCreateObjectDef("player deer");
    rmAddObjectDefItem(playerDeerID, "ypNilgai", rmRandInt(6,7), 8.0);
    rmSetObjectDefMinDistance(playerDeerID, 8);
    rmSetObjectDefMaxDistance(playerDeerID, 18);
	rmAddObjectDefConstraint(playerDeerID, avoidAll);
	rmAddObjectDefConstraint(playerDeerID, avoidCliff);
    rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
	rmSetObjectDefCreateHerd(playerDeerID, true);

	int playerFoxesID=rmCreateObjectDef("player foxes");
    rmAddObjectDefItem(playerFoxesID, "ypWildElephant", 1, 0.0);
    rmSetObjectDefMinDistance(playerFoxesID, 55);
    rmSetObjectDefMaxDistance(playerFoxesID, 58);
	rmAddObjectDefConstraint(playerFoxesID, avoidAll);
	rmAddObjectDefConstraint(playerFoxesID, avoidCliff);
    rmAddObjectDefConstraint(playerFoxesID, avoidImpassableLand);
	rmSetObjectDefCreateHerd(playerFoxesID, true);

	int playerTreeID=rmCreateObjectDef("player trees");
    rmAddObjectDefItem(playerTreeID, "TreeTexas", rmRandInt(5,9), 18.0);
    rmSetObjectDefMinDistance(playerTreeID, 18);
    rmSetObjectDefMaxDistance(playerTreeID, 25);
	rmAddObjectDefConstraint(playerTreeID, avoidAll);
	rmAddObjectDefConstraint(playerTreeID, avoidCliff);
    rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);

	int playerNuggetID= rmCreateObjectDef("player nugget"); 
	rmAddObjectDefItem(playerNuggetID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmAddObjectDefConstraint(playerNuggetID, longAvoidImpassableLand);
  	rmAddObjectDefConstraint(playerNuggetID, avoidNugget);
  	rmAddObjectDefConstraint(playerNuggetID, avoidTradeRoute);
  	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
	rmAddObjectDefConstraint(playerNuggetID, avoidCliff);
	rmSetObjectDefMinDistance(playerNuggetID, 20.0);
	rmSetObjectDefMaxDistance(playerNuggetID, 30.0);

	for(i=1; <cNumberPlayers)
   {
	rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
	rmPlaceObjectDefAtLoc(waterFlagID, i, 0.2, 0.8);
	rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playergoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerSheepID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerFoxesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
   }
   rmClearClosestPointConstraints();   	

   // NATIVE AMERICANS

   // Text
	rmSetStatusText("",0.50);
   
	float NativeVillageLoc = rmRandFloat(0,1);
     
	int nootkaVillageID = -1;
	int nootkaVillageType = rmRandInt(1,5);
	int KlamathVillageID = -1;
	int KlamathVillageType = rmRandInt(1,5);
	int Klamath1VillageID = -1;
	int Klamath1VillageType = rmRandInt(1,5);
	int nootka1VillageID = -1;
	int nootka1VillageType = rmRandInt(1,5);

		if(subCiv0 == rmGetCivID("Bhakti"))
		{   
			KlamathVillageID = rmCreateGrouping("Klamath village", "native bhakti village "+KlamathVillageType);
			rmSetGroupingMinDistance(KlamathVillageID, 0.0);
			rmSetGroupingMaxDistance(KlamathVillageID, rmXFractionToMeters(0.1));
			rmAddGroupingToClass(KlamathVillageID, rmClassID("natives"));
			rmAddGroupingConstraint(KlamathVillageID, longAvoidImpassableLand);
			rmAddGroupingToClass(KlamathVillageID, rmClassID("importantItem"));
			rmAddGroupingConstraint(KlamathVillageID, avoidTradeRoute);
			rmAddGroupingConstraint(KlamathVillageID, avoidNatives);
			rmAddGroupingConstraint(KlamathVillageID, avoidTownCenter);

			rmPlaceGroupingAtLoc(KlamathVillageID, 0, 0.50, 0.50);
		}

		else if (subCiv0 == rmGetCivID("Sufi"))
		{
			nootkaVillageID = rmCreateGrouping("nootka village", "native sufi mosque deccan "+nootkaVillageType);
			rmSetGroupingMinDistance(nootkaVillageID, 0.0);
			rmSetGroupingMaxDistance(nootkaVillageID, rmXFractionToMeters(0.1));
			rmAddGroupingToClass(nootkaVillageID, rmClassID("natives"));
			rmAddGroupingConstraint(nootkaVillageID, longAvoidImpassableLand);
			rmAddGroupingToClass(nootkaVillageID, rmClassID("importantItem"));
			rmAddGroupingConstraint(nootkaVillageID, avoidTradeRoute);
			rmAddGroupingConstraint(nootkaVillageID, avoidNatives);
			rmAddGroupingConstraint(nootkaVillageID, avoidTownCenter);
			rmPlaceGroupingAtLoc(nootkaVillageID, 0, 0.50, 0.50);
		}

	if(subCiv1 == rmGetCivID("Bhakti"))
	{
		int Klamath2VillageID = -1;
		int Klamath2VillageType = rmRandInt(4,5);
		Klamath2VillageID = rmCreateGrouping("Klamath2 village", "native bhakti village "+Klamath2VillageType);
		rmSetGroupingMinDistance(Klamath2VillageID, 0.0);
		rmSetGroupingMaxDistance(Klamath2VillageID, rmXFractionToMeters(0.1));
		rmAddGroupingToClass(Klamath2VillageID, rmClassID("natives"));
		rmAddObjectDefConstraint(Klamath2VillageID, longAvoidImpassableLand);
		rmAddGroupingConstraint(Klamath2VillageID, longAvoidImpassableLand);
		rmAddGroupingConstraint(Klamath2VillageID, avoidTradeRoute);
		rmAddGroupingConstraint(Klamath2VillageID, avoidTownCenter);
		rmAddGroupingConstraint(Klamath2VillageID, avoidNatives);
		rmPlaceGroupingAtLoc(Klamath2VillageID, 0, 0.70, 0.30);
	}
	else if (subCiv1 == rmGetCivID("Sufi"))
	{   
		int nootka2VillageID = -1;
		int nootka2VillageType = rmRandInt(1,5);
		nootka2VillageID = rmCreateGrouping("nootka2 village", "native sufi mosque deccan "+nootka2VillageType);
		rmSetGroupingMinDistance(nootka2VillageID, 0.0);
		rmSetGroupingMaxDistance(nootka2VillageID, rmXFractionToMeters(0.1));
		rmAddGroupingToClass(nootka2VillageID, rmClassID("natives"));
		rmAddGroupingConstraint(nootka2VillageID, avoidImpassableLand);
		rmAddGroupingToClass(nootka2VillageID, rmClassID("importantItem"));
		rmAddGroupingConstraint(nootka2VillageID, avoidTradeRoute);
		rmAddGroupingConstraint(nootka2VillageID, avoidTownCenter);
		rmAddGroupingConstraint(nootka2VillageID, avoidNatives);
		rmPlaceGroupingAtLoc(nootka2VillageID, 0, 0.70, 0.30);
	}

   // Text
	rmSetStatusText("",0.60);

   // Define and place Nuggets


	int nuggetID= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmSetObjectDefMinDistance(nuggetID, 0.0);
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggetID, avoidNugget);
  	rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
  	rmAddObjectDefConstraint(nuggetID, avoidTradeRoute);
  	rmAddObjectDefConstraint(nuggetID, avoidAll);
  	rmAddObjectDefConstraint(nuggetID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	int nuggetmediumID= rmCreateObjectDef("nugget medium"); 
	rmAddObjectDefItem(nuggetmediumID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(2, 2);
	rmSetObjectDefMinDistance(nuggetmediumID, 0.0);
	rmSetObjectDefMaxDistance(nuggetmediumID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggetmediumID, avoidNugget);
  	rmAddObjectDefConstraint(nuggetmediumID, avoidTownCenter);
  	rmAddObjectDefConstraint(nuggetmediumID, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetmediumID, avoidCliff);
  	rmAddObjectDefConstraint(nuggetmediumID, avoidAll);
  	rmAddObjectDefConstraint(nuggetmediumID, longAvoidImpassableLand);
	rmPlaceObjectDefAtLoc(nuggetmediumID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);


	int nuggethardID= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nuggethardID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 3);
	rmSetObjectDefMinDistance(nuggethardID, 0.0);
	rmSetObjectDefMaxDistance(nuggethardID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggethardID, avoidNugget);
  	rmAddObjectDefConstraint(nuggethardID, avoidTownCenter);
  	rmAddObjectDefConstraint(nuggethardID, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggethardID, avoidCliff);
  	rmAddObjectDefConstraint(nuggethardID, avoidAll);
	rmAddObjectDefConstraint(nuggethardID, playerEdgeConstraint);
  	rmAddObjectDefConstraint(nuggethardID, longAvoidImpassableLand);
	rmPlaceObjectDefAtLoc(nuggethardID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	if(rmRandFloat(0,1) < 0.25) //places more hard 25% of the time
	{
		int nuggethard2ID= rmCreateObjectDef("nugget more hard"); 
		rmAddObjectDefItem(nuggethard2ID, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(3, 3);
		rmSetObjectDefMinDistance(nuggethard2ID, 0.0);
		rmSetObjectDefMaxDistance(nuggethard2ID, rmXFractionToMeters(0.5));
  		rmAddObjectDefConstraint(nuggethard2ID, avoidNugget);
  		rmAddObjectDefConstraint(nuggethard2ID, avoidTownCenter);
  		rmAddObjectDefConstraint(nuggethard2ID, avoidTradeRoute);
		rmAddObjectDefConstraint(nuggethard2ID, avoidCliff);
  		rmAddObjectDefConstraint(nuggethard2ID, avoidAll);
		rmAddObjectDefConstraint(nuggethard2ID, playerEdgeConstraint);
  		rmAddObjectDefConstraint(nuggethard2ID, longAvoidImpassableLand);
		rmPlaceObjectDefAtLoc(nuggethard2ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);
	}


	//only try to place these 25% of the time
	   if(rmRandFloat(0,1) < 0.25)
	   {
		int nuggetnutsID= rmCreateObjectDef("nugget nuts"); 
		rmAddObjectDefItem(nuggetnutsID, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(4, 4);
		rmSetObjectDefMinDistance(nuggetnutsID, 0.0);
		rmSetObjectDefMaxDistance(nuggetnutsID, rmXFractionToMeters(0.5));
  		rmAddObjectDefConstraint(nuggetnutsID, avoidNugget);
  		rmAddObjectDefConstraint(nuggetnutsID, avoidTownCenter);
  		rmAddObjectDefConstraint(nuggetnutsID, avoidTradeRoute);
		rmAddObjectDefConstraint(nuggetnutsID, avoidCliff);
  		rmAddObjectDefConstraint(nuggetnutsID, avoidAll);
		rmAddObjectDefConstraint(nuggetnutsID, playerEdgeConstraint);
  		rmAddObjectDefConstraint(nuggetnutsID, longAvoidImpassableLand);
		rmPlaceObjectDefAtLoc(nuggetnutsID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
	   }


	//Place fish
   int fishID=rmCreateObjectDef("fish");
   rmAddObjectDefItem(fishID, "ypFishCarp", 3, 9.0);
   rmSetObjectDefMinDistance(fishID, 0.0);
   rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(fishID, fishVsFishID);
   rmAddObjectDefConstraint(fishID, fishLand);
   rmPlaceObjectDefAtLoc(fishID, 0, 0.3, 0.7, 4*cNumberNonGaiaPlayers);
 
	//Place whale
   int whaleID=rmCreateObjectDef("whale");
   rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 9.0);
   rmSetObjectDefMinDistance(whaleID, 0.0);
   rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
   rmAddObjectDefConstraint(whaleID, whaleLand);
   rmPlaceObjectDefAtLoc(whaleID, 0, 0.3, 0.7, 4*cNumberNonGaiaPlayers);

   // Place resources that we want forests to avoid

	// Gold mines

	int goldType = -1;
	int goldCount = (cNumberNonGaiaPlayers + rmRandInt(1,2));
	rmEchoInfo("gold count = "+goldCount);

	for(i=0; < goldCount)
	{
	  int goldID = rmCreateObjectDef("gold West "+i);
	  rmAddObjectDefItem(goldID, "MineCopper", 1, 0.0);
      rmSetObjectDefMinDistance(goldID, 0.0);
      rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(goldID, avoidCoin);
      rmAddObjectDefConstraint(goldID, avoidAll);
	  rmAddObjectDefConstraint(goldID, avoidCliff);
      rmAddObjectDefConstraint(goldID, avoidTownCenterFar);
	  rmAddObjectDefConstraint(goldID, avoidTradeRoute);
      rmAddObjectDefConstraint(goldID, mediumAvoidImpassableLand);
	  rmAddObjectDefConstraint(goldID, WestForestconstraint);
	  if (cNumberNonGaiaPlayers == 2)
	  rmPlaceObjectDefAtLoc(goldID, 0, 0.75, 0.25);
	  else
	  rmPlaceObjectDefAtLoc(goldID, 0, 0.55, 0.45);

   }

	goldCount = (cNumberNonGaiaPlayers + rmRandInt(1,2));
	rmEchoInfo("gold2 count = "+goldCount);

	for(i=0; < goldCount)
	{
	  int goldEastID = rmCreateObjectDef("gold East "+i);
	  rmAddObjectDefItem(goldEastID, "MineCopper", 1, 0.0);
      rmSetObjectDefMinDistance(goldEastID, 0.0);
      rmSetObjectDefMaxDistance(goldEastID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(goldEastID, avoidCoin);
      rmAddObjectDefConstraint(goldEastID, avoidAll);
	  rmAddObjectDefConstraint(goldEastID, avoidCliff);
      rmAddObjectDefConstraint(goldEastID, avoidTownCenterFar);
	  rmAddObjectDefConstraint(goldEastID, avoidTradeRoute);
      rmAddObjectDefConstraint(goldEastID, mediumAvoidImpassableLand);
	  if (cNumberNonGaiaPlayers == 2)
	  rmPlaceObjectDefAtLoc(goldEastID, 0, 0.75, 0.25);
	  else
	  rmPlaceObjectDefAtLoc(goldEastID, 0, 0.55, 0.45);	
	  }

	if (cNumberNonGaiaPlayers > 4)
		goldCount = (2);
	else
		goldCount = (cNumberNonGaiaPlayers + 1);
	rmEchoInfo("gold3 count = "+goldCount);

	for(i=0; < goldCount)
	{
	  int goldRandomID = rmCreateObjectDef("gold Random "+i);
	  rmAddObjectDefItem(goldRandomID, "Mine", 1, 0.0);
      rmSetObjectDefMinDistance(goldRandomID, 0.0);
      rmSetObjectDefMaxDistance(goldRandomID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(goldRandomID, avoidCoinFar);
      rmAddObjectDefConstraint(goldRandomID, avoidAll);
	  rmAddObjectDefConstraint(goldRandomID, shortAvoidCliff);
      rmAddObjectDefConstraint(goldRandomID, avoidTownCenterFar);
	  rmAddObjectDefConstraint(goldRandomID, avoidTradeRoute);
      rmAddObjectDefConstraint(goldRandomID, mediumAvoidImpassableLand);
	  if (cNumberNonGaiaPlayers == 2)
	  rmPlaceObjectDefAtLoc(goldRandomID, 0, 0.75, 0.25);
	  else
	  rmPlaceObjectDefAtLoc(goldRandomID, 0, 0.60, 0.40);	
	}

   // Text
   rmSetStatusText("",0.70);

   // FORESTS
	
	int forestTreeID = 0;
	numTries=4*cNumberNonGaiaPlayers;
	int failCount=0;
	for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest pine forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(300));
         rmSetAreaForestType(forest, "Maltese Forest");
		 rmSetAreaForestDensity(forest, 0.75);
         rmSetAreaForestClumpiness(forest, 0.10);
         rmSetAreaForestUnderbrush(forest, 0.6);
         rmSetAreaMinBlobs(forest, 8);
         rmSetAreaMaxBlobs(forest, 15);
         rmSetAreaMinBlobDistance(forest, 20.0);
         rmSetAreaMaxBlobDistance(forest, 40.0);
         rmSetAreaCoherence(forest, 0.25);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
         rmAddAreaConstraint(forest, forestConstraint);
         rmAddAreaConstraint(forest, avoidAll);
		rmAddAreaConstraint(forest, avoidTownCenter);
         //rmAddAreaConstraint(forest, avoidCliff);
         rmAddAreaConstraint(forest, avoidImpassableLand); 
         rmAddAreaConstraint(forest, avoidTradeRouteShort);
		 
         if(rmBuildArea(forest)==false)
         {
            // Stop trying once we fail 5 times in a row.
            failCount++;
            if(failCount==5)
               break;
         }
         else
            failCount=0;
      }

	forestTreeID = 0;
	numTries=4*cNumberNonGaiaPlayers;
	failCount=0;
	for (i=0; <numTries)
      {   
         int forestEast=rmCreateArea("forest desert "+i);
         rmSetAreaWarnFailure(forestEast, false);
         rmSetAreaSize(forestEast, rmAreaTilesToFraction(250), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forestEast, "Texas Forest");
		 rmSetAreaForestDensity(forestEast, 0.75);
         rmSetAreaForestClumpiness(forestEast, 0.1);
         rmSetAreaForestUnderbrush(forestEast, 0.6);
         rmSetAreaMinBlobs(forestEast, 10);
         rmSetAreaMaxBlobs(forestEast, 20);
         rmSetAreaMinBlobDistance(forestEast, 6.0);
         rmSetAreaMaxBlobDistance(forestEast, 10.0);
         rmSetAreaCoherence(forestEast, 0.8);
         rmSetAreaSmoothDistance(forestEast, 10);
         rmAddAreaToClass(forestEast, rmClassID("classForest")); 
         rmAddAreaConstraint(forestEast, forestConstraint);
		rmAddAreaConstraint(forestEast, avoidTownCenter);
         rmAddAreaConstraint(forestEast, avoidAll);
         rmAddAreaConstraint(forestEast, avoidCliff);
         rmAddAreaConstraint(forestEast, avoidImpassableLand); 
         rmAddAreaConstraint(forestEast, avoidTradeRouteShort);
		 
         if(rmBuildArea(forestEast)==false)
         {
            // Stop trying once we fail 6 times in a row.
            failCount++;
            if(failCount==6)
               break;
         }
         else
            failCount=0; 
      } 

    forestTreeID = 0;
	numTries=6*cNumberNonGaiaPlayers;
	failCount=0;
	for (i=0; <numTries)
      {   
         int forestMadrone=rmCreateArea("forest madrone "+i);
         rmSetAreaWarnFailure(forestMadrone, false);
         rmSetAreaSize(forestMadrone, rmAreaTilesToFraction(100), rmAreaTilesToFraction(150));
         rmSetAreaForestType(forestMadrone, "Maltese Forest");
		 rmSetAreaForestDensity(forestMadrone, 0.55);
         rmSetAreaForestClumpiness(forestMadrone, 0.15);
         rmSetAreaForestUnderbrush(forestMadrone, 0.6);
         rmSetAreaMinBlobs(forestMadrone, 10);
         rmSetAreaMaxBlobs(forestMadrone, 20);
         rmSetAreaMinBlobDistance(forestMadrone, 20.0);
         rmSetAreaMaxBlobDistance(forestMadrone, 30.0);
         rmSetAreaCoherence(forestMadrone, 0.35);
         rmSetAreaSmoothDistance(forestMadrone, 10);
         rmAddAreaToClass(forestMadrone, rmClassID("classForest")); 
         rmAddAreaConstraint(forestMadrone, forestConstraint);
         rmAddAreaConstraint(forestMadrone, avoidAll);
		rmAddAreaConstraint(forestMadrone, avoidTownCenter);
         rmAddAreaConstraint(forestMadrone, avoidCliff);
         rmAddAreaConstraint(forestMadrone, avoidImpassableLand); 
         rmAddAreaConstraint(forestMadrone, avoidTradeRoute);
		 
         if(rmBuildArea(forestMadrone)==false)
         {
            // Stop trying once we fail 4 times in a row.
            failCount++;
            if(failCount==4)
               break;
         }
         else
            failCount=0; 
      }

 
  // Text
   rmSetStatusText("",0.80); 


   // Deer & Elk
	int deerID=rmCreateObjectDef("deer herd");
	rmAddObjectDefItem(deerID, "ypNilgai", rmRandInt(8,10), 10.0);
	rmSetObjectDefMinDistance(deerID, 0.0);
	rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(deerID, avoidDeer);
	rmAddObjectDefConstraint(deerID, avoidAll);
	rmAddObjectDefConstraint(deerID, avoidImpassableLand);
	rmSetObjectDefCreateHerd(deerID, true);
	rmPlaceObjectDefAtLoc(deerID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);


  // Text
   rmSetStatusText("",0.90);

   rmSetMapClusteringPlacementParams(0.7, 0.2, 0.9, cClusterLand);
   rmSetMapClusteringObjectParams(0, 2, 0.5);
   //rmPlaceMapClusters("carolinas\grass2", "underbrushShrub");

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
