// Serra do mar
// Started over Saguenay
include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";
void main(void)
{
	// Map variation variable
	int whichVariation=-1;
	whichVariation = rmRandInt(1,2);

	// Which trade route?
	int whichTradeRoute = rmRandInt(1,3);  // On a 1, do the funky mini-route in the middle.
	if ( cNumberTeams != 2 ) // On FFA, do NOT do the funky mini-route.
	{
		whichTradeRoute = rmRandInt(2, 3);
	}

	if ( cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 5 || cNumberNonGaiaPlayers == 7 )  // On odd numbers of players, no miniroute
	{
		whichTradeRoute = rmRandInt(2, 3);
	}
	
	whichTradeRoute = 2;
   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

   //Chooses which natives appear on the map
   int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;
   int subCiv3=-1;

   if (rmAllocateSubCivs(4) == true)
   {
      subCiv0=rmGetCivID("Paulista");
      rmEchoInfo("subCiv0 is Bandeirante "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Paulista");

		subCiv1=rmGetCivID("Sertanejo");
      rmEchoInfo("subCiv1 is Sertanejo "+subCiv1);
		if (subCiv1 >= 0)
			 rmSetSubCiv(1, "Sertanejo");
	 
		subCiv2=rmGetCivID("Jesuit");
      rmEchoInfo("subCiv2 is Jesuit "+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Jesuit");

		subCiv3=rmGetCivID("Jesuit");
      rmEchoInfo("subCiv3 is Jesuit "+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Jesuit");
	}

   // Picks the map size
   int playerTiles=13000;
   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);
   rmSetLightingSet("pampas");

   // Picks a default water height
   rmSetSeaLevel(-1.0);

	// Picks default terrain and water
	// rmSetMapElevationParameters(long type, float minFrequency, long numberOctaves, float persistence, float heightVariation)
	rmSetMapElevationParameters(cElevTurbulence, 0.1, 4, 0.3, 2.0);
	rmSetSeaType("Serra Coast");
	rmEnableLocalWater(false);
	rmSetBaseTerrainMix("cerrado_dirt");
	rmTerrainInitialize("saguenay\ground1_sag",2);
	rmSetMapType("brazil");
	rmSetMapType("water");
	rmSetMapType("grass");
	// rmSetGlobalSnow( 0.7 );
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
   rmDefineClass("importantItem");
	rmDefineClass("secrets");
	rmDefineClass("nuggets");
	rmDefineClass("bay");
	rmDefineClass("classSocket");

   // -------------Define constraints
   // These are used to have objects and areas avoid each others
   
   // Map edge constraints
   int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
   int longPlayerConstraint=rmCreateClassDistanceConstraint("continent stays away from players", classPlayer, 24.0);

   // Player constraints
   int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 15.0);
   int smallMapPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 60.0);
   int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 30.0);
   int nearWater10 = rmCreateTerrainDistanceConstraint("near water", "Water", true, 10.0);

   // Cardinal Directions
   int NWconstraint=rmCreatePieConstraint("northwestMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(270), rmDegreesToRadians(90));
   int NEconstraint=rmCreatePieConstraint("northeastMapConstraint", 0.55, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(180), rmDegreesToRadians(360));
   int SWconstraint=rmCreatePieConstraint("southwestMapConstraint", 0.45, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(1), rmDegreesToRadians(180));
   int SEconstraint=rmCreatePieConstraint("southeastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(90), rmDegreesToRadians(270));

   // Bonus area constraint.
   int bigContinentConstraint=rmCreateClassDistanceConstraint("avoid bonus island", classbigContinent, 20.0);

   // Resource avoidance
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0);
   int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 1.0);
   int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "gold", 50.0);
   int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 50.0);
   int avoidElk=rmCreateTypeDistanceConstraint("elk avoids elk", "Capybara", 35.0);
   int avoidMoose=rmCreateTypeDistanceConstraint("moose avoids moose", "Deer", 30.0);
   int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 18.0);
   int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "beluga", 15.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
   int whaleLand = rmCreateTerrainDistanceConstraint("whale v. land", "land", true, 15.0);
   int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 40.0);

   // Avoid impassable land
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 10.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
   int avoidCliffs=rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 30.0);
   int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 5.0);
   int avoidHudsonSmall=rmCreateClassDistanceConstraint("inner land avoids bay", rmClassID("bay"), rmXFractionToMeters(0.15));
   int avoidHudsonLarge=rmCreateClassDistanceConstraint("outer land avoids bay", rmClassID("bay"), rmXFractionToMeters(0.3));

   // Unit avoidance
	int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 20.0);
	int avoidStartingUnitsSmall=rmCreateClassDistanceConstraint("objects avoid starting units small", rmClassID("startingUnit"), 5.0);
	int avoidStartingUnitsBay=rmCreateClassDistanceConstraint("bay avoids starting units", rmClassID("startingUnit"), 40.0);

   // Decoration avoidance
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

   // Trade route avoidance.
   // VP avoidance
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
   int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route long", 20.0);
   int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("classSocket"), 10.0);
   int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
   int avoidImportantShort = rmCreateClassDistanceConstraint("secrets etc avoid each other near", rmClassID("importantItem"), 7.0);
   int secretsAvoidSecrets = rmCreateClassDistanceConstraint("secrets avoid secrets", rmClassID("secrets"), 60.0);

   // Constraint to avoid water.
   int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water", "Land", false, 8.0);
   int avoidWater16 = rmCreateTerrainDistanceConstraint("avoid water 16", "Land", false, 16.0);

    // ships vs. ships
   int shipVsShip=rmCreateTypeDistanceConstraint("ships avoid ship", "ship", 5.0);

   // Cardinal Direction
   int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));

	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));

   // Text
   rmSetStatusText("",0.10);

   // Text
   rmSetStatusText("",0.20);

   int OuterLandID=rmCreateArea("Larger area away from bay");
   rmSetAreaWarnFailure(OuterLandID, false);
   rmSetAreaLocation(OuterLandID, 0.5, 0.5);
   rmSetAreaSize(OuterLandID, 1, 1);
//   rmSetAreaTerrainType(OuterLandID, "cuba\cuba1");
   rmSetAreaBaseHeight(OuterLandID, 2.0);
   rmSetAreaElevationType(OuterLandID, cElevTurbulence);
   rmSetAreaElevationVariation(OuterLandID, 4.0);
   rmSetAreaElevationMinFrequency(OuterLandID, 0.1);
   rmSetAreaElevationOctaves(OuterLandID, 4);
   rmSetAreaElevationPersistence(OuterLandID, 0.4);
	rmSetAreaMix(OuterLandID, "cerrado_dirt");
   rmBuildArea(OuterLandID);

   int InnerLandID=rmCreateArea("Smaller area near bay");
   rmSetAreaWarnFailure(InnerLandID, false);
   rmSetAreaLocation(InnerLandID, 0.5, 0.01);
	rmAddAreaInfluenceSegment(InnerLandID, 0.2, 0.1, 0.8, 0.1);
   rmSetAreaSize(InnerLandID, 0.45, 0.45);
      rmSetAreaCoherence(InnerLandID, 0.8);
//   rmSetAreaTerrainType(InnerLandID, "cuba\cuba1");
   rmSetAreaBaseHeight(InnerLandID, 1.0);
   rmSetAreaElevationType(InnerLandID, cElevTurbulence);
   rmSetAreaElevationVariation(InnerLandID, 2.0);
   rmSetAreaElevationMinFrequency(InnerLandID, 0.1);
   rmSetAreaElevationOctaves(InnerLandID, 4);
   rmSetAreaElevationPersistence(InnerLandID, 0.5);
   rmSetAreaMinBlobs(InnerLandID, 8);
   rmSetAreaMaxBlobs(InnerLandID, 10);
   rmSetAreaMinBlobDistance(InnerLandID, 10);
   rmSetAreaMaxBlobDistance(InnerLandID, 20);
	rmSetAreaMix(InnerLandID, "SerradoMar");
   rmAddAreaTerrainLayer(InnerLandID, "cuba\cuba2", 0, 4);
   rmSetAreaObeyWorldCircleConstraint(InnerLandID, false);
	// rmAddAreaTerrainLayer(InnerLandID, "saguenay\ground3_sag", 2, 4);
   // rmAddAreaTerrainLayer(InnerLandID, "saguenay\ground2_sag", 4, 6);
   // rmAddAreaTerrainLayer(InnerLandID, "saguenay\ground2_sag", 6, 8);

	// DAL 
	// rmAddAreaTerrainLayer(InnerLandID, "saguenay\shoreline1_sag", 0, 4);
	// rmAddAreaTerrainLayer(InnerLandID, "saguenay\shoreline2_sag", 4, 8);
   rmBuildArea(InnerLandID);

	//	rmPaintAreaTerrainByHeight(OuterLandID, "yukon\ground6_yuk", 8, 10);
	//	rmPaintAreaTerrainByHeight(OuterLandID, "yukon\ground5_yuk", 10, 18);

	//	rmPaintAreaTerrainByHeight(InnerLandID, "yukon\ground2_yuk", 7.5, 16);
	//	rmPaintAreaTerrainByHeight(InnerLandID, "yukon\ground2_yuk", 8, 16);

	int avoidBeach = rmCreateAreaDistanceConstraint("stay away from InnerLandID", InnerLandID, 4);
///*
   // Trade route hack.
   // rmAddTradeRouteWaypoint(tradeRouteID, xFraction, zFraction)
   // rmAddRandomTradeRouteWaypoints(tradeRouteID, endXFraction, endZFraction, count, maxVariation) 
	int tradeRouteID = rmCreateTradeRoute();
   int socketID=rmCreateObjectDef("sockets");
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmAddObjectDefToClass(socketID, rmClassID("classSocket"));
   rmSetObjectDefMinDistance(socketID, 0.0);
   rmSetObjectDefMaxDistance(socketID, 8.0);

	if ( whichTradeRoute > 1 )
	{
		rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.9);  // DAL - 0.75
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.55, 0.62, 10, 12);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.45, 0.62, 10, 12);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.2, 0.9, 5, 10); // DAL - 0.75
	}
	else
	{
		rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.0);
		rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.45, 0.45, 10, 12);
	}

   bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "WOTTAdirt");
   if(placedTradeRoute == false)
      rmEchoError("Failed to place trade route");

	// add the meeting poles along the trade route.
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
   vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0);

	if ( whichTradeRoute > 1 )
	{
		socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.10);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
		if ( whichVariation == 2 )
		{
			socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
		}

		socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

		if ( whichVariation == 2 )
		{
			socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
		}
	}
	else
	{
		socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.4);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

		socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.7);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
   
	// Place one at the end in all cases.
	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.9);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
//*/
   // x z x z
   // Set up player areas.
   float playerFraction=rmAreaTilesToFraction(50);

	rmSetPlacementSection(0.78, 0.22);
	rmPlacePlayersCircular(0.4, 0.4, 0.1);

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
      // rmAddAreaConstraint(id, avoidWater16); 
	  rmAddAreaConstraint(id, avoidTradeRouteFar); 
	  rmAddAreaConstraint(id, avoidSocket); 
      rmAddAreaConstraint(id, playerEdgeConstraint); 
      rmSetAreaLocPlayer(id, i);
      rmSetAreaWarnFailure(id, false);
   }

   // Build the areas.
   rmBuildAllAreas();

	// Create a HudsonBay water area -- the mediterranean part.
   int HudsonBayID=rmCreateArea("Hudson Bay");
   if ( cNumberNonGaiaPlayers < 8 )
   {
		rmSetAreaSize(HudsonBayID, 0.2, 0.2);
   }
   else
   {
	   	rmSetAreaSize(HudsonBayID, 0.15, 0.15);
   }
   rmSetAreaLocation(HudsonBayID, 0.5, 0.05);
	rmAddAreaInfluenceSegment(HudsonBayID, 0.4, 0.035, 0.6, 0.035);
	rmAddAreaInfluenceSegment(HudsonBayID, 0.3, 0.035, 0.7, 0.035);
	rmAddAreaInfluenceSegment(HudsonBayID, 0.1, 0.0, 0.9, 0.0);
   rmSetAreaWaterType(HudsonBayID, "Serra Coast");
   rmSetAreaBaseHeight(HudsonBayID, -1.0); // Was 10
   rmSetAreaMinBlobs(HudsonBayID, 8);
   rmSetAreaMaxBlobs(HudsonBayID, 10);
   rmSetAreaMinBlobDistance(HudsonBayID, 8);
   rmSetAreaMaxBlobDistance(HudsonBayID, 11);
   rmSetAreaSmoothDistance(HudsonBayID, 50);
   rmSetAreaCoherence(HudsonBayID, 0.8);
   rmAddAreaConstraint(HudsonBayID, avoidStartingUnitsBay); 
	rmAddAreaToClass(HudsonBayID, rmClassID("bay"));
   rmSetAreaObeyWorldCircleConstraint(HudsonBayID, false);
   
   rmBuildArea(HudsonBayID);

   // Text
   rmSetStatusText("",0.30);

   // Text
   rmSetStatusText("",0.40);
   
   // Define and place the Native Villages and Secrets of the New World
   // Text
   rmSetStatusText("",0.50);
   
   float NativeVillageLoc = rmRandFloat(0,1);

	float natPos1x = 0.35; float natPos1z = 0.28;
	float natPos2x = 0.65; float natPos2z = 0.28;
	float natPos3x = 0.65; float natPos3z = 0.65;
	float natPos4x = 0.35; float natPos4z = 0.65;
     
	int CreeVillageAID = -1;
   int CreeVillageType = rmRandInt(1,3);
   CreeVillageAID = rmCreateGrouping("Cree village A", "native bandeirante village "+CreeVillageType);
   rmSetGroupingMinDistance(CreeVillageAID, 0.0);
   rmSetGroupingMaxDistance(CreeVillageAID, rmXFractionToMeters(0.05));
   rmAddGroupingConstraint(CreeVillageAID, avoidImpassableLand);
   rmAddGroupingToClass(CreeVillageAID, rmClassID("importantItem"));
   rmAddGroupingConstraint(CreeVillageAID, avoidTradeRoute);
   rmAddGroupingConstraint(CreeVillageAID, avoidSocket);
   rmAddGroupingConstraint(CreeVillageAID, avoidImportantItem);
	rmAddGroupingConstraint(CreeVillageAID, playerConstraint);
	if ( whichTradeRoute == 1 )
	{
		if(NativeVillageLoc < 0.25)
			rmPlaceGroupingAtLoc(CreeVillageAID, 0, natPos1x, natPos1z);
		else if(NativeVillageLoc < 0.5)
			rmPlaceGroupingAtLoc(CreeVillageAID, 0, natPos2x, natPos2z); // DAL
		else if(NativeVillageLoc < 0.75)
			rmPlaceGroupingAtLoc(CreeVillageAID, 0, natPos3x, natPos3z); // DAL
		else
			rmPlaceGroupingAtLoc(CreeVillageAID, 0, natPos4x, natPos4z);
	}
	else
	{
		if(NativeVillageLoc < 0.25)
			rmPlaceGroupingAtLoc(CreeVillageAID, 0, natPos1x, natPos1z);
		else if(NativeVillageLoc < 0.5)
			rmPlaceGroupingAtLoc(CreeVillageAID, 0, natPos2x, natPos2z); // DAL
		else if(NativeVillageLoc < 0.75)
			rmPlaceGroupingAtLoc(CreeVillageAID, 0, natPos3x, natPos3z); // DAL
		else
			rmPlaceGroupingAtLoc(CreeVillageAID, 0, natPos4x, natPos4z);
	}

   int CreeVillageBID = -1;
   CreeVillageType = rmRandInt(1,3);
   CreeVillageBID = rmCreateGrouping("Cree village B", "native bandeirante village "+CreeVillageType);
   rmSetGroupingMaxDistance(CreeVillageBID, rmXFractionToMeters(0.05));
   rmAddGroupingConstraint(CreeVillageBID, avoidImpassableLand);
   rmAddGroupingToClass(CreeVillageBID, rmClassID("importantItem"));
   rmAddGroupingConstraint(CreeVillageBID, avoidTradeRoute);
   rmAddGroupingConstraint(CreeVillageBID, avoidSocket);
   rmAddGroupingConstraint(CreeVillageBID, avoidImportantItem);
	rmAddGroupingConstraint(CreeVillageBID, playerConstraint);
	if ( whichTradeRoute == 1 )
	{
		if(NativeVillageLoc < 0.25)
			rmPlaceGroupingAtLoc(CreeVillageBID, 0, natPos4x, natPos4z); //DAL
		else if(NativeVillageLoc < 0.5)
			rmPlaceGroupingAtLoc(CreeVillageBID, 0, natPos1x, natPos1z);
		else if(NativeVillageLoc < 0.75)
			rmPlaceGroupingAtLoc(CreeVillageBID, 0, natPos2x, natPos2z);
		else
			rmPlaceGroupingAtLoc(CreeVillageBID, 0, natPos3x, natPos3z); //DAL
	}
	else
	{
		if(NativeVillageLoc < 0.25)
			rmPlaceGroupingAtLoc(CreeVillageBID, 0, natPos4x, natPos4z); //DAL
		else if(NativeVillageLoc < 0.5)
			rmPlaceGroupingAtLoc(CreeVillageBID, 0, natPos1x, natPos1z);
		else if(NativeVillageLoc < 0.75)
			rmPlaceGroupingAtLoc(CreeVillageBID, 0, natPos2x, natPos2z);
		else
			rmPlaceGroupingAtLoc(CreeVillageBID, 0, natPos3x, natPos3z); //DAL
	}
     
   int huronVillageAID = -1;
   int huronVillageType = rmRandInt(1,3);
   huronVillageAID = rmCreateGrouping("huron village A", "native jesuit mission cj 0"+huronVillageType);
   rmSetGroupingMaxDistance(huronVillageAID, rmXFractionToMeters(0.10));
   rmAddGroupingConstraint(huronVillageAID, avoidImpassableLand);
   rmAddGroupingToClass(huronVillageAID, rmClassID("importantItem"));
   rmAddGroupingConstraint(huronVillageAID, avoidTradeRoute);
   rmAddGroupingConstraint(huronVillageAID, avoidSocket);
   rmAddGroupingConstraint(huronVillageAID, avoidImportantItem);
	rmAddGroupingConstraint(huronVillageAID, playerConstraint);
	if ( whichTradeRoute == 1 )
	{
		if(NativeVillageLoc < 0.25)
			rmPlaceGroupingAtLoc(huronVillageAID, 0, natPos3x, natPos3z); //DAL
		else if(NativeVillageLoc < 0.5)
			rmPlaceGroupingAtLoc(huronVillageAID, 0, natPos4x, natPos4z);
		else if(NativeVillageLoc < 0.75)
			rmPlaceGroupingAtLoc(huronVillageAID, 0, natPos1x, natPos1z); //DAL
		else
			rmPlaceGroupingAtLoc(huronVillageAID, 0, natPos2x, natPos2z);
	}
	else
	{
		if(NativeVillageLoc < 0.25)
			rmPlaceGroupingAtLoc(huronVillageAID, 0, natPos3x, natPos3z); //DAL
		else if(NativeVillageLoc < 0.5)
			rmPlaceGroupingAtLoc(huronVillageAID, 0, natPos4x, natPos4z);
		else if(NativeVillageLoc < 0.75)
			rmPlaceGroupingAtLoc(huronVillageAID, 0, natPos1x, natPos1z); //DAL
		else
			rmPlaceGroupingAtLoc(huronVillageAID, 0, natPos2x, natPos2z);
	}

	int huronVillageBID = -1;
   huronVillageType = rmRandInt(1,3);
   huronVillageBID = rmCreateGrouping("huron village B", "native jesuit mission cj 0"+huronVillageType);
   rmSetGroupingMinDistance(huronVillageBID, 0.0);
   rmSetGroupingMaxDistance(huronVillageBID, rmXFractionToMeters(0.10));
   rmAddGroupingConstraint(huronVillageBID, avoidImpassableLand);
   rmAddGroupingToClass(huronVillageBID, rmClassID("importantItem"));
   rmAddGroupingConstraint(huronVillageBID, avoidSocket);
   rmAddGroupingConstraint(huronVillageBID, avoidTradeRoute);
	rmAddGroupingConstraint(huronVillageBID, playerConstraint);
	if ( whichTradeRoute == 1 )
	{
		if(NativeVillageLoc < 0.25)
			rmPlaceGroupingAtLoc(huronVillageBID, 0, natPos2x, natPos2z);
		else if(NativeVillageLoc < 0.5)
			rmPlaceGroupingAtLoc(huronVillageBID, 0, natPos3x, natPos3z);	//DAL
		else if(NativeVillageLoc < 0.75)
			rmPlaceGroupingAtLoc(huronVillageBID, 0, natPos4x, natPos4z);
		else
			rmPlaceGroupingAtLoc(huronVillageBID, 0, natPos1x, natPos1z); //DAL
	}
	else
	{
		if(NativeVillageLoc < 0.25)
			rmPlaceGroupingAtLoc(huronVillageBID, 0, natPos2x, natPos2z);
		else if(NativeVillageLoc < 0.5)
			rmPlaceGroupingAtLoc(huronVillageBID, 0, natPos3x, natPos3z);	//DAL
		else if(NativeVillageLoc < 0.75)
			rmPlaceGroupingAtLoc(huronVillageBID, 0, natPos4x, natPos4z);
		else
			rmPlaceGroupingAtLoc(huronVillageBID, 0, natPos1x, natPos1z); //DAL
	}

//Forestry Hills

  int startingCliff1=rmCreateArea("Serra 1");
  rmSetAreaSize(startingCliff1, .035, .035);
  rmSetAreaLocation(startingCliff1, 0.5, 0.45);
  rmSetAreaWarnFailure(startingCliff1, false);
  rmSetAreaSmoothDistance(startingCliff1, 10);
  rmSetAreaCoherence(startingCliff1, .6);
   rmSetAreaBaseHeight(startingCliff1, 8.0);
  rmAddAreaInfluenceSegment(startingCliff1, 0.42, 0.45, 0.58, 0.45);
         rmSetAreaForestType(startingCliff1, "Bahia Forest");
         rmSetAreaForestDensity(startingCliff1, 1.0);
         rmSetAreaForestClumpiness(startingCliff1, 0.8);
         rmSetAreaForestUnderbrush(startingCliff1, 0.5);
//  rmSetAreaCliffEdge(startingCliff1, 6, .11, 0, 1.0, 0);
//  rmSetAreaCliffHeight(startingCliff1, 5, 2.0, 0.5);  
//  rmSetAreaCliffType(startingCliff1, CliffType);
//  rmSetAreaTerrainType(startingCliff1, BaseTerrain);
//  rmSetAreaMix(startingCliff1, BaseMix2);
  //rmSetAreaCliffPainting(startingCliff1, true, true, true, 0, true);
  rmAddAreaToClass(startingCliff1, rmClassID("classForest"));
  rmAddAreaConstraint(startingCliff1, avoidImportantShort);
//  rmAddAreaConstraint(startingCliff1, avoidTradeRoute);
//  rmAddAreaConstraint(startingCliff1, avoidTradeSockets);
  rmBuildArea(startingCliff1);

  int startingCliff2=rmCreateArea("Serra 2");
  rmSetAreaSize(startingCliff2, .035, .035);
  rmSetAreaLocation(startingCliff2, 0.18, 0.40);
  rmSetAreaWarnFailure(startingCliff2, false);
  rmSetAreaSmoothDistance(startingCliff2, 10);
  rmSetAreaCoherence(startingCliff2, .6);
   rmSetAreaBaseHeight(startingCliff2, 9.0);
  rmAddAreaInfluenceSegment(startingCliff2, 0.08, 0.38, 0.24, 0.42);
         rmSetAreaForestType(startingCliff2, "Bahia Forest");
         rmSetAreaForestDensity(startingCliff2, 1.0);
         rmSetAreaForestClumpiness(startingCliff2, 0.8);
         rmSetAreaForestUnderbrush(startingCliff2, 0.5);
  rmAddAreaToClass(startingCliff2, rmClassID("classForest"));
  rmAddAreaConstraint(startingCliff2, avoidImportantShort);
  rmBuildArea(startingCliff2);

    int startingCliff3=rmCreateArea("Serra 3");
  rmSetAreaSize(startingCliff3, .035, .035);
  rmSetAreaLocation(startingCliff3, 0.82, 0.40);
  rmSetAreaWarnFailure(startingCliff3, false);
  rmSetAreaSmoothDistance(startingCliff3, 10);
  rmSetAreaCoherence(startingCliff3, .6);
   rmSetAreaBaseHeight(startingCliff3, 9.0);
  rmAddAreaInfluenceSegment(startingCliff3, 0.76, 0.42, 0.92, 0.38);
         rmSetAreaForestType(startingCliff3, "Bahia Forest");
         rmSetAreaForestDensity(startingCliff3, 1.0);
         rmSetAreaForestClumpiness(startingCliff3, 0.8);
         rmSetAreaForestUnderbrush(startingCliff3, 0.5);
  rmAddAreaToClass(startingCliff3, rmClassID("classForest"));
  rmAddAreaConstraint(startingCliff3, avoidImportantShort);
  rmBuildArea(startingCliff3);

    // NEW Starting Unit placement
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 0.0);
	rmSetObjectDefMaxDistance(startingUnits, 12.0);
	rmAddObjectDefToClass(startingUnits, rmClassID("startingUnit"));
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidSocket);
	rmAddObjectDefConstraint(startingUnits, avoidTradeRoute);

	int startingTCID= rmCreateObjectDef("startingTC");
	if ( rmGetNomadStart())
	{
		rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 0.0);
	}
	else
	{
		rmAddObjectDefItem(startingTCID, "TownCenter", 1, 0.0);
	}
	rmSetObjectDefMinDistance(startingTCID, 0.0);
	if ( cNumberTeams == 2 )
	{
		rmSetObjectDefMaxDistance(startingTCID, 15.0); // DAL - was 60
	}
	else	// FFA
	{
		rmSetObjectDefMaxDistance(startingTCID, 15.0);
	}
	rmAddObjectDefToClass(startingTCID, rmClassID("startingUnit"));
	rmAddObjectDefConstraint(startingTCID, avoidSocket);
	rmAddObjectDefConstraint(startingTCID, avoidWater8);
	rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);

	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "TreeGreatPlainsGrass", 1, 0.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 10.0);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 15.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartingUnitsSmall);

	int StartDeerID=rmCreateObjectDef("starting deer");
	rmAddObjectDefItem(StartDeerID, "deer", 3, 4.0);
	rmSetObjectDefMinDistance(StartDeerID, 12.0);
	rmSetObjectDefMaxDistance(StartDeerID, 18.0);
	rmSetObjectDefCreateHerd(StartDeerID, true);
	rmAddObjectDefConstraint(StartDeerID, avoidStartingUnitsSmall);

	// Pick a random building
	int startResourceBuildingID=rmCreateObjectDef("starting resource building");
	int whichBuilding = rmRandInt(1,3);
	if ( whichBuilding == 1 )
	{
		rmAddObjectDefItem(startResourceBuildingID, "Plantation", 1, 0.0);
	}
	else if ( whichBuilding == 2 )
	{
		rmAddObjectDefItem(startResourceBuildingID, "Market", 1, 0.0);
	}
	else
	{
		rmAddObjectDefItem(startResourceBuildingID, "LivestockPen", 1, 0.0);
	}
	rmSetObjectDefMinDistance(startResourceBuildingID, 16.0);
	rmSetObjectDefMaxDistance(startResourceBuildingID, 20.0);
	rmAddObjectDefConstraint(startResourceBuildingID, avoidStartingUnitsSmall);
	rmAddObjectDefToClass(startResourceBuildingID, rmClassID("startingUnit"));

	// Pick a random building (native version)
	int startResourceBuildingNativeID=rmCreateObjectDef("starting resource building native");
	if ( whichBuilding == 1 )
	{
		rmAddObjectDefItem(startResourceBuildingNativeID, "Plantation", 1, 0.0);
	}
	else if ( whichBuilding == 2 )
	{
		rmAddObjectDefItem(startResourceBuildingNativeID, "Market", 1, 0.0);
	}
	else
	{
		rmAddObjectDefItem(startResourceBuildingNativeID, "Farm", 1, 0.0);
	}
	rmSetObjectDefMinDistance(startResourceBuildingNativeID, 16.0);
	rmSetObjectDefMaxDistance(startResourceBuildingNativeID, 20.0);
	rmAddObjectDefConstraint(startResourceBuildingNativeID, avoidStartingUnitsSmall);
	rmAddObjectDefToClass(startResourceBuildingNativeID, rmClassID("startingUnit"));

    int silverID = -1;
    int silver2ID = -1;
	int silverType = rmRandInt(1,10);
	int playerGoldID = -1;

	// Everyone gets two ore mines, one pretty close, the other a little further away.
	silverType = rmRandInt(1,10);
	playerGoldID = rmCreateObjectDef("player silver "+i);
	rmAddObjectDefItem(playerGoldID, "mine", 1, 0.0);
	// rmAddGroupingToClass(playerGoldID, rmClassID("importantItem"));
	rmAddObjectDefConstraint(playerGoldID, avoidTradeRoute);
	rmAddObjectDefConstraint(playerGoldID, avoidStartingUnitsSmall);
	rmSetObjectDefMinDistance(playerGoldID, 15.0);
	rmSetObjectDefMaxDistance(playerGoldID, 20.0);
	
	// Extra crates for the starting guys (if not FFA)
	int extraCrate=rmCreateObjectDef("extra crate");
	rmAddObjectDefItem(extraCrate, "CrateofFood", 1, 0.0);
	rmSetObjectDefMinDistance(extraCrate, 6.0);
	rmSetObjectDefMaxDistance(extraCrate, 9.0);

	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
	rmAddObjectDefToClass(playerNuggetID, rmClassID("nuggets"));
    rmSetObjectDefMinDistance(playerNuggetID, 30.0);
    rmSetObjectDefMaxDistance(playerNuggetID, 35.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidStartingUnitsSmall);
	rmAddObjectDefConstraint(playerNuggetID, avoidNugget);
	rmAddObjectDefConstraint(playerNuggetID, circleConstraint);
	// rmAddObjectDefConstraint(playerNuggetID, avoidImportantItem);

	// John's sweet solution to placing stuff around the TC regardless of where the player start area actually is, YAY!!!!!!
	for(i=1; <cNumberPlayers)
	{
		rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLocation=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
		
/*		if ( rmGetNomadStart() == false )
		{
			if ( rmGetPlayerCiv(i) ==  rmGetCivID("XPIroquois") ||
						rmGetPlayerCiv(i) ==  rmGetCivID("XPSioux") ||
						rmGetPlayerCiv(i) ==  rmGetCivID("XPAztec"))
			{
				rmPlaceObjectDefAtLoc(startResourceBuildingNativeID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			}
			else
			{
				rmPlaceObjectDefAtLoc(startResourceBuildingID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			}
		}*/
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		
		rmPlaceObjectDefAtLoc(StartDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(StartDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));

		// Player nuggets
		rmSetNuggetDifficulty(1, 1);
		rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));

		/*
		// DAL TAKEN OUT
		if ( rmGetPlayerTeam(i) == 1 && cNumberTeams == 2 )	// Only place this sucker if not FFA
	    {
			rmPlaceObjectDefAtLoc(extraCrate, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	    }
		*/
	}

	// Let's try ponds instead of cliffs.
	int pondClass=rmDefineClass("pond");
   int pondConstraint=rmCreateClassDistanceConstraint("ponds avoid ponds", rmClassID("pond"), 60.0);

   int numPonds=cNumberNonGaiaPlayers;
	for(i=0; <numPonds)
   {
      int smallPondID=rmCreateArea("small pond"+i);
      rmSetAreaSize(smallPondID, rmAreaTilesToFraction(250), rmAreaTilesToFraction(400));
      rmSetAreaWaterType(smallPondID, "saguenay lake");
      rmSetAreaBaseHeight(smallPondID, 4);
      rmAddAreaToClass(smallPondID, pondClass);
      rmSetAreaCoherence(smallPondID, 0.4);
      rmSetAreaSmoothDistance(smallPondID, 5);
      rmAddAreaConstraint(smallPondID, pondConstraint);
      rmAddAreaConstraint(smallPondID, avoidTradeRoute);
      rmAddAreaConstraint(smallPondID, avoidImportantItem);
      rmAddAreaConstraint(smallPondID, avoidImpassableLand);
      rmAddAreaConstraint(smallPondID, avoidCliffs);
	  rmAddAreaConstraint(smallPondID, avoidSocket);
	  rmAddAreaConstraint(smallPondID, avoidStartingUnitsBay);
	  rmAddAreaConstraint(smallPondID, Southward);
      rmSetAreaWarnFailure(smallPondID, false);
     // rmBuildArea(smallPondID);
   }


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
	rmAddObjectDefConstraint(nuggetID, circleConstraint);
	rmSetNuggetDifficulty(1, 3);
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*5);
   
   int fishID=rmCreateObjectDef("fish");
   rmAddObjectDefItem(fishID, "FishSalmon", 3, 9.0);
   rmSetObjectDefMinDistance(fishID, 0.0);
   rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(fishID, fishVsFishID);
   rmAddObjectDefConstraint(fishID, fishLand);
   rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);

   // Text
   rmSetStatusText("",0.70);

	// FAST COIN -- WHALES	 
	int whaleID=rmCreateObjectDef("whale");
   rmAddObjectDefItem(whaleID, "HumpbackWhale", 2, 9.0);
   rmSetObjectDefMinDistance(whaleID, 0.0);
   rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
   rmAddObjectDefConstraint(whaleID, whaleLand);
   rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

   // Place resources that we want forests to avoid
	// FAST COIN -- Ore Mines
	silverType = -1;
	silverID = -1;
	silver2ID = -1;
	int silverCount = cNumberNonGaiaPlayers*3;
	rmEchoInfo("silver count 1 = "+silverCount);

	// 3 per player in each side.
	for(i=0; < silverCount)
	{
		silverType = rmRandInt(1,10);
		silverID = rmCreateObjectDef("silver "+i);
		rmAddObjectDefItem(silverID, "mine", 1, 0.0);
		rmSetObjectDefMinDistance(silverID, 0.0);
		rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(silverID, avoidCoin);
		rmAddObjectDefConstraint(silverID, avoidAll);
		rmAddObjectDefConstraint(silverID, avoidImpassableLand);
		rmAddObjectDefConstraint(silverID, avoidTradeRoute);
		rmAddObjectDefConstraint(silverID, avoidSocket);
		rmAddObjectDefConstraint(silverID, NEconstraint);
		rmAddObjectDefConstraint(silverID, avoidStartingUnits);
		rmAddObjectDefConstraint(silverID, avoidBeach);
		rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
   }
	for(i=0; < silverCount)
	{
		silver2ID = rmCreateObjectDef("silver2 "+i);
		rmAddObjectDefItem(silver2ID, "mine", 1, 0.0);
		rmSetObjectDefMinDistance(silver2ID, 0.0);
		rmSetObjectDefMaxDistance(silver2ID, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(silver2ID, avoidCoin);
		rmAddObjectDefConstraint(silver2ID, avoidAll);
		rmAddObjectDefConstraint(silver2ID, avoidImpassableLand);
		rmAddObjectDefConstraint(silver2ID, avoidTradeRoute);
		rmAddObjectDefConstraint(silver2ID, avoidSocket);
		rmAddObjectDefConstraint(silver2ID, SWconstraint);
		rmAddObjectDefConstraint(silver2ID, avoidStartingUnits);
		rmAddObjectDefConstraint(silver2ID, avoidBeach);
		rmPlaceObjectDefAtLoc(silver2ID, 0, 0.5, 0.5);
   }

	// Define and place Forests
   int forestTreeID = 0;
   int numTries=6*cNumberNonGaiaPlayers;
   int failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(250), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest, "Cerrado Forest");
			// rmSetAreaForestType(forest, "dunes");
         rmSetAreaForestDensity(forest, 0.6);
         rmSetAreaForestClumpiness(forest, 0.8);
         rmSetAreaForestUnderbrush(forest, 0.0);
         rmSetAreaMinBlobs(forest, 1);
         rmSetAreaMaxBlobs(forest, 5);
         rmSetAreaMinBlobDistance(forest, 10.0);
         rmSetAreaMaxBlobDistance(forest, 30.0);
         rmSetAreaCoherence(forest, 0.4);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
         rmAddAreaConstraint(forest, forestConstraint);
         rmAddAreaConstraint(forest, avoidAll);
         // rmAddAreaConstraint(forest, avoidBeach);
         rmAddAreaConstraint(forest, avoidImpassableLand); 
         rmAddAreaConstraint(forest, avoidTradeRoute); 
			rmAddAreaConstraint(forest, avoidBeach); 
			rmAddAreaConstraint(forest, avoidSocket); 
			rmAddAreaConstraint(forest, avoidStartingUnits); 
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

   int elkID=rmCreateObjectDef("elk herd");
	rmAddObjectDefItem(elkID, "Capybara", rmRandInt(7,8), 6.0);
   rmSetObjectDefMinDistance(elkID, 0.0);
   rmSetObjectDefMaxDistance(elkID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(elkID, avoidElk);
   rmAddObjectDefConstraint(elkID, avoidMoose);
	rmAddObjectDefConstraint(elkID, avoidAll);
   rmAddObjectDefConstraint(elkID, avoidImpassableLand);
	rmAddObjectDefConstraint(elkID, avoidSocket);
	rmAddObjectDefConstraint(elkID, avoidTradeRoute);
	rmAddObjectDefConstraint(elkID, avoidStartingUnits);


   rmSetObjectDefCreateHerd(elkID, true);
	rmPlaceObjectDefAtLoc(elkID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*4);

   int mooseID=rmCreateObjectDef("moose herd");
	rmAddObjectDefItem(mooseID, "Deer", rmRandInt(4,5), 8.0);
   rmSetObjectDefMinDistance(mooseID, 0.0);
   rmSetObjectDefMaxDistance(mooseID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(mooseID, avoidElk);
   rmAddObjectDefConstraint(mooseID, avoidMoose);
	rmAddObjectDefConstraint(mooseID, avoidAll);
   rmAddObjectDefConstraint(mooseID, avoidImpassableLand);
	rmAddObjectDefConstraint(mooseID, avoidSocket);
	rmAddObjectDefConstraint(mooseID, avoidTradeRoute);
	rmAddObjectDefConstraint(mooseID, avoidStartingUnits);

   rmSetObjectDefCreateHerd(mooseID, true);
	rmPlaceObjectDefAtLoc(mooseID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);

	// Text
   rmSetStatusText("",0.90);

   int rockVsLand = rmCreateTerrainDistanceConstraint("rock v. land", "land", true, 2.0);
   int nearShore=rmCreateTerrainMaxDistanceConstraint("rock v. water", "land", true, 14.0);

   int coastalRockID=rmCreateObjectDef("coastal rocks");
   rmAddObjectDefItem(coastalRockID, "coastalRocksSaguenay", 1, 0.0);
   rmSetObjectDefMinDistance(coastalRockID, 0.0);
   rmSetObjectDefMaxDistance(coastalRockID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(coastalRockID, rockVsLand);
	rmAddObjectDefConstraint(coastalRockID, nearShore);
   rmAddObjectDefConstraint(coastalRockID, avoidStartingUnits);

   rmPlaceObjectDefAtLoc(coastalRockID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);

   int sheepID=rmCreateObjectDef("sheep");
   rmAddObjectDefItem(sheepID, "sheep", 2, 3.0);
   rmSetObjectDefMinDistance(sheepID, 0.0);
   rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(sheepID, avoidSheep);
   rmAddObjectDefConstraint(sheepID, avoidElk);
   rmAddObjectDefConstraint(sheepID, avoidMoose);
	rmAddObjectDefConstraint(sheepID, avoidAll);
   rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
	rmAddObjectDefConstraint(sheepID, avoidSocket);
	rmAddObjectDefConstraint(sheepID, avoidTradeRoute);
	rmAddObjectDefConstraint(sheepID, avoidStartingUnits);
   rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);


    //CARAVELS for Team 1 Only, if not FFA
   int colonyShipID = 0;
   for(i=1; <cNumberPlayers)
   {
		colonyShipID=rmCreateObjectDef("colony ship "+i);
	   // Only place Caravels/Galleys for Team #1.
		// DAL Temporarily pulled for crazy fix-a-tron
		/*
	   if ( rmGetPlayerTeam(i) == 0 && cNumberTeams == 2 )
	   {
			if(rmGetPlayerCiv(i) == rmGetCivID("Ottomans"))
				rmAddObjectDefItem(colonyShipID, "Galley", 1, 0.0);
			else
				rmAddObjectDefItem(colonyShipID, "caravel", 1, 0.0);
	   }
	   */

  		rmAddObjectDefItem(colonyShipID, "HomeCityWaterSpawnFlag", 1, 5.0);
		rmAddObjectDefConstraint(colonyShipID, shipVsShip);
		rmAddObjectDefConstraint(colonyShipID, fishLand);
		rmSetObjectDefMinDistance(colonyShipID, 0.0);
		rmSetObjectDefMaxDistance(colonyShipID, rmXFractionToMeters(0.35));

		// vector colonyShipLocation=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(colonyShipID, i));
		// rmSetHomeCityWaterSpawnPoint(i, colonyShipLocation);
    
	   	rmPlaceObjectDefAtLoc(colonyShipID, i, 0.5, 0.0, 1);
	}   

   // Text
   rmSetStatusText("",1.0);      
}
