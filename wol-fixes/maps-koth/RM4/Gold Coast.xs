// Gold Coast
// Started with patagonia script
include "mercenaries.xs";
include "ypAsianInclude.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";
void main(void)
{
   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

    string aur_type = "tribal";
    int resourcesarray = xsArrayCreateString(13, "", "");

    xsArraySetString(resourcesarray, 1, "gold");
    xsArraySetString(resourcesarray, 2, "gold");
    xsArraySetString(resourcesarray, 3, "gold");
    xsArraySetString(resourcesarray, 4, "slaves");
    xsArraySetString(resourcesarray, 5, "slaves");
    xsArraySetString(resourcesarray, 6, "palmoil");
    xsArraySetString(resourcesarray, 7, "palmoil");
    xsArraySetString(resourcesarray, 8, "figurines");
    xsArraySetString(resourcesarray, 9, "figurines");
    xsArraySetString(resourcesarray, 10, "ivory");
    xsArraySetString(resourcesarray, 11, "rubber");
    xsArraySetString(resourcesarray, 12, "textiles");
    xsArraySetString(resourcesarray, 13, "textiles");

    rmAllocateSubCivs(6);

    string subCiv0Name = "AURgoldGuinea";
    int subCiv0 = rmGetCivID(subCiv0Name);
    rmSetSubCiv(0, subCiv0Name); 

    string subCiv1Name = "AURslavesGuinea";
    int subCiv1 = rmGetCivID(subCiv1Name);
    rmSetSubCiv(1, subCiv1Name);

	string subCiv2Name = "AURpalmoilGuinea";
    int subCiv2 = rmGetCivID(subCiv2Name);
    rmSetSubCiv(2, subCiv2Name);
	
	string subCiv3Name = "AURfigurinesGuinea";
    int subCiv3 = rmGetCivID(subCiv3Name);
    rmSetSubCiv(3, subCiv3Name);
    
	string subCiv4Name = "AURivoryGuinea";
    int subCiv4 = rmGetCivID(subCiv4Name);
    rmSetSubCiv(4, subCiv4Name);

	string subCiv5Name = "AURrubberGuinea";
    int subCiv5 = rmGetCivID(subCiv5Name);
    rmSetSubCiv(5, subCiv5Name);

	string subCiv6Name = "AURtextilesGuinea";
    int subCiv6 = rmGetCivID(subCiv6Name);
    rmSetSubCiv(6, subCiv6Name);
    
   //Chooses which natives appear on the map

   // Picks the map size
   int playerTiles=15000;
   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

	int whichVariation=-1;
	whichVariation = rmRandInt(1,2);

   // Picks a default water height
   rmSetSeaLevel(-1.0);

   // Picks default terrain and water
	// rmSetMapElevationParameters(long type, float minFrequency, long numberOctaves, float persistence, float heightVariation)
	rmSetMapElevationParameters(cElevTurbulence, 0.1, 4, 0.2, 3.0);
	rmSetSeaType("new england coast");
//   rmEnableLocalWater(false);
	 rmSetBaseTerrainMix("carolina_grass");
    rmTerrainInitialize("carolinas\ground_grass1_car", 2.0);
	rmSetMapType("AFRICANjungle");
	rmSetMapType("water");
	rmSetMapType("grass");
   rmSetLightingSet("patagonia");
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
   rmDefineClass("importantItem");
	rmDefineClass("natives");	
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
   int avoidBighornSheep=rmCreateTypeDistanceConstraint("bighorn avoids bighorn", "Antelope", 35.0);
   int avoidMoose=rmCreateTypeDistanceConstraint("moose avoids moose", "Gnu", 35.0);
   int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 15.0);
   int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 18.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
   int whaleLand = rmCreateTerrainDistanceConstraint("whale v. land", "land", true, 20.0);
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
	int avoidSocket=rmCreateClassDistanceConstraint("avoid sockets", rmClassID("socketClass"), 5.0);
	int avoidSocketCliff=rmCreateClassDistanceConstraint("cliffs avoid sockets by a lot", rmClassID("socketClass"), 10.0);
	int avoidSocketPlayer=rmCreateClassDistanceConstraint("cliffs avoid sockets by a lot more", rmClassID("socketClass"), 15.0);
   int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
   int secretsAvoidSecrets = rmCreateClassDistanceConstraint("secrets avoid secrets", rmClassID("secrets"), 60.0);
   int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 30.0);

	// natives avoid natives
	int avoidNatives = rmCreateClassDistanceConstraint("avoid Natives", rmClassID("natives"), 15.0);
	int avoidNativesSmall = rmCreateClassDistanceConstraint("forests avoid Natives", rmClassID("natives"), 5.0);
	int avoidNativesNuggets = rmCreateClassDistanceConstraint("nuggets avoid Natives", rmClassID("natives"), 20.0);

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
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 20.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 15);
	int flagEdgeConstraint = rmCreatePieConstraint("flags stay near edge of map", 0.5, 0.5, rmGetMapXSize()-20, rmGetMapXSize()-10, 0, 0, 0);

	int SocketEdgeConstraint = rmCreatePieConstraint("socket stay near edge of map", 0.5, 0.5, rmZFractionToMeters(0.35), rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360)); //to force the sea sockets to spawn in the islands

	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Text
   rmSetStatusText("",0.10);

	// int avoidBeach = rmCreateAreaDistanceConstraint("stay away from InnerLandID", InnerLandID, 4);

	// Trade route hack.
   //	rmAddTradeRouteWaypoint(tradeRouteID, xFraction, zFraction)
   // rmAddRandomTradeRouteWaypoints(tradeRouteID, endXFraction, endZFraction, count, maxVariation) 
   int tradeRouteID2 = rmCreateTradeRoute();
   int socketID=rmCreateObjectDef("sockets to dock Trade Posts 2");
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);

   rmAddObjectDefConstraint(socketID, circleConstraint);
   rmAddObjectDefConstraint(socketID, SocketEdgeConstraint);
   rmAddObjectDefToClass(socketID, rmClassID("socketClass"));

   rmSetObjectDefMinDistance(socketID, 0.0);
   rmSetObjectDefMaxDistance(socketID, 24.0+5*cNumberNonGaiaPlayers);

   rmAddTradeRouteWaypoint(tradeRouteID2, 0.03, 0.57);
   rmAddRandomTradeRouteWaypoints(tradeRouteID2, 0.17, 0.52, 0, 0);
   rmAddRandomTradeRouteWaypoints(tradeRouteID2, 0.24, 0.24, 0, 0);
   rmAddRandomTradeRouteWaypoints(tradeRouteID2, 0.52, 0.17, 0, 0);
   rmAddRandomTradeRouteWaypoints(tradeRouteID2, 0.57, 0.03, 0, 0);

   bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID2, "WATERdirt");
   if(placedTradeRoute == false)
      rmEchoError("Failed to place trade route");

	// Create two Bay Areas.
   int bay1ID=rmCreateArea("Bay 1");
   rmSetAreaSize(bay1ID, 0.16, 0.16);
	rmSetAreaLocation(bay1ID, 0.25, 0.25);
	rmSetAreaWaterType(bay1ID, "atlantic coast");
   rmSetAreaBaseHeight(bay1ID, 1.0); // Was 10
   rmSetAreaMinBlobs(bay1ID, 4);
   rmSetAreaMaxBlobs(bay1ID, 6);
   rmSetAreaMinBlobDistance(bay1ID, 5);
   rmSetAreaMaxBlobDistance(bay1ID, 30);
   rmSetAreaSmoothDistance(bay1ID, 20);
   rmSetAreaCoherence(bay1ID, 0.8);
		rmAddAreaInfluenceSegment(bay1ID, 0.03, 0.67, 0.20, 0.55);
		rmAddAreaInfluenceSegment(bay1ID, 0.20, 0.55, 0.30, 0.30);
		rmAddAreaInfluenceSegment(bay1ID, 0.30, 0.30, 0.55, 0.20);
		rmAddAreaInfluenceSegment(bay1ID, 0.55, 0.20, 0.67, 0.03);
	rmAddAreaToClass(bay1ID, rmClassID("bay"));
   rmSetAreaObeyWorldCircleConstraint(bay1ID, false);
	rmBuildArea(bay1ID);

   int bay2ID=rmCreateArea("Bay 2");
   rmSetAreaSize(bay2ID, 0.3, 0.3);
	rmSetAreaLocation(bay2ID, 0.18, 0.18);
	rmSetAreaWaterType(bay2ID, "atlantic coast");
   rmSetAreaBaseHeight(bay2ID, 1.0); // Was 10
   rmSetAreaMinBlobs(bay2ID, 4);
   rmSetAreaMaxBlobs(bay2ID, 4);
   rmSetAreaMinBlobDistance(bay2ID, 5);
   rmSetAreaMaxBlobDistance(bay2ID, 20);
   rmSetAreaSmoothDistance(bay2ID, 20);
   rmSetAreaCoherence(bay2ID, 1);
		rmAddAreaInfluenceSegment(bay2ID, 0.50, 0.01, 0.20, 0.20);
		rmAddAreaInfluenceSegment(bay2ID, 0.20, 0.20, 0.01, 0.50);
	rmAddAreaToClass(bay2ID, rmClassID("bay"));
   rmSetAreaObeyWorldCircleConstraint(bay2ID, false);
   rmBuildArea(bay2ID);

   int Island1ID=rmCreateArea("island 1");
   rmSetAreaSize(Island1ID, 0.015, 0.015);
   rmSetAreaLocation(Island1ID, 0.4, 0.1);
   rmSetAreaBaseHeight(Island1ID, 1.0); 
   rmSetAreaMix(Island1ID, "carolina_grass");
   rmSetAreaMinBlobs(Island1ID, 4);
   rmSetAreaMaxBlobs(Island1ID, 6);
   rmSetAreaMinBlobDistance(Island1ID, 5);
   rmSetAreaMaxBlobDistance(Island1ID, 25);
   rmSetAreaSmoothDistance(Island1ID, 30);
   rmSetAreaCoherence(Island1ID, 0.8);
   rmAddAreaToClass(Island1ID, rmClassID("bay"));
   rmSetAreaObeyWorldCircleConstraint(Island1ID, true);
   rmBuildArea(Island1ID);

   int Island2ID=rmCreateArea("island 2");
   rmSetAreaSize(Island2ID, 0.015, 0.015);
   rmSetAreaLocation(Island2ID, 0.1, 0.4);
   rmSetAreaBaseHeight(Island2ID, 1.0); //
   rmSetAreaMix(Island2ID, "carolina_grass");
   rmSetAreaMinBlobs(Island2ID, 4);
   rmSetAreaMaxBlobs(Island2ID, 4);
   rmSetAreaMinBlobDistance(Island2ID, 5);
   rmSetAreaMaxBlobDistance(Island2ID, 20);
   rmSetAreaSmoothDistance(Island2ID, 30);
   rmSetAreaCoherence(Island2ID, 0.8);
   rmAddAreaToClass(Island2ID, rmClassID("bay"));
   rmSetAreaObeyWorldCircleConstraint(Island2ID, true);
   rmBuildArea(Island2ID);

   // Text
   rmSetStatusText("",0.20);

   //// NATIVES ////

//    int TPC=rmRandInt(1,2);

    int aurSettlementC = rmCreateGrouping("aur village C", "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 12))+"GUI"+rmRandInt(1, 3));
    rmSetGroupingMinDistance(aurSettlementC, 0.0);
    rmSetGroupingMaxDistance(aurSettlementC, rmXFractionToMeters(0.01));
    rmAddGroupingConstraint(aurSettlementC, avoidImpassableLand);
    rmAddGroupingToClass(aurSettlementC, rmClassID("importantItem"));
    rmAddGroupingToClass(aurSettlementC, rmClassID("natives"));
    rmAddGroupingConstraint(aurSettlementC, avoidNatives);
    rmAddGroupingConstraint(aurSettlementC, avoidTradeRoute);
    rmAddGroupingConstraint(aurSettlementC, avoidStartingUnits);
//    	if (TPC == 1 )
 //   	{
    		rmPlaceGroupingAtLoc(aurSettlementC, 0, 0.45, 0.45);
//    	}
//    	else
//    	{
//    		rmPlaceGroupingAtLoc(aurSettlementC, 0, 0.47, 0.47);
//    	}

      int aurSettlementD = rmCreateGrouping("aur village D", "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 12))+"GUI"+rmRandInt(1, 3));
      rmSetGroupingMinDistance(aurSettlementD, 0.0);
      rmSetGroupingMaxDistance(aurSettlementD, rmXFractionToMeters(0.01));
      rmAddGroupingConstraint(aurSettlementD, avoidImpassableLand);
      rmAddGroupingToClass(aurSettlementD, rmClassID("importantItem"));
      rmAddGroupingToClass(aurSettlementD, rmClassID("natives"));
      rmAddGroupingConstraint(aurSettlementD, avoidNatives);
	  rmAddGroupingConstraint(aurSettlementD, avoidTradeRoute);
	  rmAddGroupingConstraint(aurSettlementD, avoidStartingUnits);
//		if (TCP == 1 )
//		{
			rmPlaceGroupingAtLoc(aurSettlementD, 0, 0.4, 0.8);
//		}
//		else
//		{
//			rmPlaceGroupingAtLoc(aurSettlementD, 0, 0.35, 0.85);
//		}

      int aurSettlementE = rmCreateGrouping("aur village E", "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 12))+"GUI"+rmRandInt(1, 3));
      rmSetGroupingMinDistance(aurSettlementE, 0.0);
	  rmSetGroupingMaxDistance(aurSettlementE, rmXFractionToMeters(0.01));
      rmAddGroupingConstraint(aurSettlementE, avoidImpassableLand);
      rmAddGroupingToClass(aurSettlementE, rmClassID("importantItem"));
      rmAddGroupingToClass(aurSettlementE, rmClassID("natives"));
      rmAddGroupingConstraint(aurSettlementE, avoidNatives);
      rmAddGroupingConstraint(aurSettlementE, avoidTradeRoute);
	  rmAddGroupingConstraint(aurSettlementE, avoidStartingUnits);
//		if (TCP == 1 )
//			{
				rmPlaceGroupingAtLoc(aurSettlementE, 0, 0.8, 0.4);
//			}
//			else
//			{
//				rmPlaceGroupingAtLoc(aurSettlementE, 0, 0.85, 0.35);
//			}

      int aurSettlementF = rmCreateGrouping("aur village F", "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 12))+"GUI"+rmRandInt(1, 3));
      rmSetGroupingMinDistance(aurSettlementF, 0.0);
	  rmSetGroupingMaxDistance(aurSettlementF, rmXFractionToMeters(0.01));
      rmAddGroupingConstraint(aurSettlementF, avoidImpassableLand);
      rmAddGroupingToClass(aurSettlementF, rmClassID("importantItem"));
      rmAddGroupingToClass(aurSettlementF, rmClassID("natives"));
      rmAddGroupingConstraint(aurSettlementF, avoidNatives);
      rmAddGroupingConstraint(aurSettlementF, avoidTradeRoute);
	  rmAddGroupingConstraint(aurSettlementF, avoidStartingUnits);
//		if ( TCP == 1 )
//			{
				rmPlaceGroupingAtLoc(aurSettlementF, 0, 0.65, 0.40);
//			}
//			else
//			{
//				rmPlaceGroupingAtLoc(aurSettlementF, 0, 0.85, 0.65);
//			}

      int aurSettlementG = rmCreateGrouping("aur village G", "AUR"+xsArrayGetString(resourcesarray, rmRandInt(1, 12))+"GUI"+rmRandInt(1, 3));
      rmSetGroupingMinDistance(aurSettlementG, 0.0);
      rmSetGroupingMaxDistance(aurSettlementG, rmXFractionToMeters(0.01));
      rmAddGroupingConstraint(aurSettlementG, avoidImpassableLand);
      rmAddGroupingToClass(aurSettlementG, rmClassID("importantItem"));
      rmAddGroupingToClass(aurSettlementG, rmClassID("natives"));
      rmAddGroupingConstraint(aurSettlementG, avoidNatives);
      rmAddGroupingConstraint(aurSettlementG, avoidTradeRoute);
	  rmAddGroupingConstraint(aurSettlementG, avoidStartingUnits);
//		if ( TCP == 1 )
//		{
			rmPlaceGroupingAtLoc(aurSettlementG, 0, 0.40, 0.65);
//		}
//		else
//		{
//			rmPlaceGroupingAtLoc(aurSettlementG, 0, 0.65, 0.85);
//		}

   // Text
   rmSetStatusText("",0.30);

	// DEFINE Player Areas
   // Set up player starting locations. These are just used to place Caravels away from each other.
   /* DAL - old placement.
	rmSetPlacementSection(0.35, 0.65);
   rmSetTeamSpacingModifier(0.50);
   rmPlacePlayersCircular(0.45, 0.45, rmDegreesToRadians(5.0));
	*/

   float spawnSwitch = rmRandFloat(0,1);

   if ( cNumberTeams == 2 )
   {
	   if (spawnSwitch <=0.5)
	   {
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.55, 0.90, 0.25, 0.8, 0.0, 0.1);

			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.90, 0.55, 0.8, 0.25, 0.0, 0.1);
	   }
	   else
	   {
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.55, 0.90, 0.25, 0.8, 0.0, 0.1);

			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.90, 0.55, 0.8, 0.25, 0.0, 0.1);
	   }
   }
   else
   {
		// rmPlacePlayersLine(0.3, 0.2, 0.8, 0.7, 0.0, 0.1);
		// rmSetPlayerPlacementArea(0.0, 0.5, 0.7, 0.8);
		rmSetPlacementSection(0.90, 0.35);
		rmPlacePlayersCircular(0.40, 0.40, 0.0);

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
      // rmAddAreaConstraint(id, playerConstraint); 
      // rmAddAreaConstraint(id, playerEdgeConstraint); 
      rmSetAreaLocPlayer(id, i);
      rmSetAreaWarnFailure(id, false);
   }

   // Build the areas.
   rmBuildAllAreas();
	
   // Text
   rmSetStatusText("",0.40);

	// Trade route hack.
   //	rmAddTradeRouteWaypoint(tradeRouteID, xFraction, zFraction)
   // rmAddRandomTradeRouteWaypoints(tradeRouteID, endXFraction, endZFraction, count, maxVariation) 
/*   int tradeRouteID2 = rmCreateTradeRoute();
   int socketID=rmCreateObjectDef("sockets to dock Trade Posts 2");
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);

   rmAddObjectDefConstraint(socketID, circleConstraint);
   rmAddObjectDefToClass(socketID, rmClassID("socketClass"));

   rmSetObjectDefMinDistance(socketID, 0.0);
   rmSetObjectDefMaxDistance(socketID, 20.0+6*cNumberNonGaiaPlayers);

   rmAddTradeRouteWaypoint(tradeRouteID2, 0.03, 0.57);
   rmAddRandomTradeRouteWaypoints(tradeRouteID2, 0.17, 0.52, 0, 0);
   rmAddRandomTradeRouteWaypoints(tradeRouteID2, 0.24, 0.24, 0, 0);
   rmAddRandomTradeRouteWaypoints(tradeRouteID2, 0.52, 0.17, 0, 0);
   rmAddRandomTradeRouteWaypoints(tradeRouteID2, 0.57, 0.03, 0, 0);

   bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID2, "WATERdirt");
   if(placedTradeRoute == false)
      rmEchoError("Failed to place trade route");
*/
	// add the meeting poles along the trade route.
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID2);

   vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID2, 0.25);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID2, 0.75);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

	// Adding a lake in the middle.
	int patchID=rmCreateArea("dry patch 1");
	int lakeConstraint=rmCreateClassDistanceConstraint("stuff vs. lake", rmClassID("lake"), 15.0);

		rmSetAreaLocation(patchID, 0.7, 0.7);
		rmAddAreaInfluenceSegment(patchID, 0.8, 0.65, 0.60, 0.60);
		rmAddAreaInfluenceSegment(patchID, 0.60, 0.60, 0.65, 0.8);

			rmSetAreaSize(patchID, 0.12, 0.12);

		rmSetAreaObeyWorldCircleConstraint(patchID, false);
		rmSetAreaCoherence(patchID, 0.5);									// higher = rounder
	
	rmSetAreaMix(patchID, "texas_grass");
	rmSetAreaBaseHeight(patchID, 1.5);
	rmSetAreaMinBlobs(patchID, 5);
	rmSetAreaMaxBlobs(patchID, 5);
	rmSetAreaMinBlobDistance(patchID, 10.0);
	rmSetAreaMaxBlobDistance(patchID, 20.0);
//	rmAddAreaToClass(patchID, lakeClass);
	rmSetAreaWarnFailure(patchID, false);
	// Only build if two teams.

		rmBuildArea(patchID);
	

   // Text
   rmSetStatusText("",0.50);

      // Starting Unit placement
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 5.0);
	rmSetObjectDefMaxDistance(startingUnits, 10.0);
	rmAddObjectDefToClass(startingUnits, rmClassID("startingUnit"));
	rmAddObjectDefConstraint(startingUnits, avoidAll);

	int startingTCID= rmCreateObjectDef("startingTC");
	if ( rmGetNomadStart())
	{
		rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 0.0);
	}
	else
	{
		rmAddObjectDefItem(startingTCID, "TownCenter", 1, 0.0);
	}
	rmAddObjectDefToClass(startingTCID, rmClassID("startingUnit"));

	int silverType = -1;
	int playerGoldID = -1;

	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "TreeCaribbean", 1, 0.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 10.0);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 15.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartingUnitsSmall);

	int StartDeerID=rmCreateObjectDef("starting deer");
	rmAddObjectDefItem(StartDeerID, "ypWildElephant", 1, 0.0);
	rmSetObjectDefMinDistance(StartDeerID, 10.0);
	rmSetObjectDefMaxDistance(StartDeerID, 15.0);
	rmAddObjectDefConstraint(StartDeerID, avoidStartingUnitsSmall);

	int StartBerryBushID=rmCreateObjectDef("starting berry bush");
	rmAddObjectDefItem(StartBerryBushID, "BerryBush", 2, 4.0);
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
	// rmAddObjectDefConstraint(playerNuggetID, avoidImportantItem);

	int waterFlagID=-1;

	for(i=1; <cNumberPlayers)
	{
		rmClearClosestPointConstraints();
		// Place starting units and a TC!
		rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		// Everyone gets one ore mine close by.
		silverType = rmRandInt(1,10);
		playerGoldID = rmCreateObjectDef("player gold closer "+i);
		rmAddObjectDefItem(playerGoldID, "minegold", 1, 0.0);
		// rmAddObjectDefToClass(playerGoldID, rmClassID("importantItem"));
		rmAddObjectDefConstraint(playerGoldID, avoidTradeRoute);
		rmAddObjectDefConstraint(playerGoldID, avoidStartingUnitsSmall);
		rmSetObjectDefMinDistance(playerGoldID, 15.0);
		rmSetObjectDefMaxDistance(playerGoldID, 20.0);
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		// Berry Bushes
		rmPlaceObjectDefAtLoc(StartBerryBushID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		// Placing starting Pronghorns...
		rmPlaceObjectDefAtLoc(StartDeerID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartDeerID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartDeerID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		
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
		rmAddClosestPointConstraint(flagEdgeConstraint);
		rmAddClosestPointConstraint(flagVsFlag);
		rmAddClosestPointConstraint(flagLand);
		vector TCLocation = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
        vector closestPoint = rmFindClosestPointVector(TCLocation, rmXFractionToMeters(1.0));

		rmPlaceObjectDefAtLoc(waterFlagID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
		rmClearClosestPointConstraints();
	}
   
	int numTries=cNumberNonGaiaPlayers*2;
	// Define and place cliffs
   for(i=0; <numTries)
   {
      int cliffID=rmCreateArea("cliff"+i);
      rmSetAreaSize(cliffID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(700));
      rmSetAreaWarnFailure(cliffID, false);
      rmSetAreaCliffType(cliffID, "amazon");
      rmSetAreaCliffEdge(cliffID, 2, 0.3, 0.1, 1.0, 0);
      rmSetAreaCliffPainting(cliffID, false, true, true, 1.5, true);
      rmSetAreaCliffHeight(cliffID, 7, 2.0, 0.5);
      rmSetAreaHeightBlend(cliffID, 1);
      rmSetAreaObeyWorldCircleConstraint(cliffID, false);
      rmAddAreaToClass(cliffID, rmClassID("classCliff")); 
//	  rmSetAreaMix(cliffID, "patagonia_dirt");
      rmAddAreaConstraint(cliffID, avoidImportantItem);
      rmAddAreaConstraint(cliffID, avoidImpassableLand);
      rmAddAreaConstraint(cliffID, avoidCliffs);
	  rmAddAreaConstraint(cliffID, playerConstraint);
      rmAddAreaConstraint(cliffID, avoidTradeRoute);
      rmAddAreaConstraint(cliffID, avoidNatives);
	  rmAddAreaConstraint(cliffID, avoidSocketCliff);
	  rmAddAreaConstraint(cliffID, avoidStartingUnits);
//	  rmAddAreaConstraint(cliffID, avoidLake);
	  rmAddAreaConstraint(cliffID, Northward);

      rmSetAreaMinBlobs(cliffID, 2);
      rmSetAreaMaxBlobs(cliffID, 3);
      rmSetAreaMinBlobDistance(cliffID, 5.0);
      rmSetAreaMaxBlobDistance(cliffID, 20.0);
      rmSetAreaSmoothDistance(cliffID, 5);
      rmSetAreaCoherence(cliffID, 0.5);		// higher = tries to make round
      rmBuildArea(cliffID);
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
	rmAddObjectDefConstraint(nuggetID, avoidNativesNuggets);
	rmAddObjectDefConstraint(nuggetID, avoidStartingUnits);
	rmAddObjectDefConstraint(nuggetID, avoidSocket);
	rmAddObjectDefConstraint(nuggetID, avoidWater8);
	rmAddObjectDefConstraint(nuggetID, circleConstraint);
	rmSetNuggetDifficulty(1, 3);
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*5);
   
   int fishID=rmCreateObjectDef("fish");
   rmAddObjectDefItem(fishID, "FishSalmon", 3, 6.0);
   rmSetObjectDefMinDistance(fishID, 0.0);
   rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(fishID, fishVsFishID);
   rmAddObjectDefConstraint(fishID, fishLand);
   rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

   // Text
   rmSetStatusText("",0.70);

	// FAST COIN -- WHALES
	int whaleID=rmCreateObjectDef("whale");
   rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 9.0);
   rmSetObjectDefMinDistance(whaleID, 0.0);
   rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
   rmAddObjectDefConstraint(whaleID, whaleLand);
   rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

		int goooldID = rmCreateObjectDef("goldCenter");
		rmAddObjectDefItem(goooldID, "minegold", 1, 0.0);
		rmSetObjectDefMinDistance(goooldID, 0.0);
		rmSetObjectDefMaxDistance(goooldID, rmXFractionToMeters(0.12));
//		rmAddObjectDefConstraint(goooldID, avoidFastCoin);
//		rmAddObjectDefConstraint(goooldID, avoidAll);
//		rmAddObjectDefConstraint(goooldID, avoidNativesNuggets);
//		rmAddObjectDefConstraint(goooldID, avoidImpassableLand);
//		rmAddObjectDefConstraint(goooldID, avoidTradeRoute);
//		rmAddObjectDefConstraint(goooldID, avoidSocket);
		rmPlaceObjectDefAtLoc(goooldID, 0, 0.70, 0.70, 2 +cNumberNonGaiaPlayers);

	// Ore mines, to be avoided by forests, etc.
	int silverID = -1;
	int silverWestID = -1;
	int silverCount = (cNumberNonGaiaPlayers*2);
	rmEchoInfo("silver count = "+silverCount);
	for(i=0; < silverCount)
	{
		silverType = rmRandInt(1,10);
		silverID = rmCreateObjectDef("gold "+i);
		rmAddObjectDefItem(silverID, "minegold", 1, 16.0);
		rmSetObjectDefMinDistance(silverID, 0.0);
		rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.2));
		rmAddObjectDefConstraint(silverID, avoidFastCoin);
		rmAddObjectDefConstraint(silverID, avoidAll);
		rmAddObjectDefConstraint(silverID, avoidNativesNuggets);
		rmAddObjectDefConstraint(silverID, avoidImpassableLand);
		rmAddObjectDefConstraint(silverID, avoidTradeRoute);
		rmAddObjectDefConstraint(silverID, avoidSocket);
		rmPlaceObjectDefAtLoc(silverID, 0, 0.65, 0.65);
   }

	// One extra gold mine per player "out North"
	for(i=0; < (cNumberNonGaiaPlayers))
	{
		silverType = rmRandInt(1,10);
		silverWestID = rmCreateObjectDef("gold north "+i);
		rmAddObjectDefItem(silverWestID, "minegold", 1, 0.0);
		rmSetObjectDefMinDistance(silverWestID, 0.0);
		rmSetObjectDefMaxDistance(silverWestID, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(silverWestID, avoidFastCoin);
		rmAddObjectDefConstraint(silverWestID, avoidAll);
		rmAddObjectDefConstraint(silverWestID, avoidNativesNuggets);
		rmAddObjectDefConstraint(silverWestID, avoidImpassableLand);
		rmAddObjectDefConstraint(silverWestID, avoidTradeRoute);
		rmAddObjectDefConstraint(silverWestID, avoidSocket);
		rmAddObjectDefConstraint(silverWestID, Northward);
		rmPlaceObjectDefAtLoc(silverWestID, 0, 0.5, 0.5);
   }

   // Define and place Forests
   int forestTreeID = 0;
   numTries=20*cNumberNonGaiaPlayers;
   int failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(250));
         rmSetAreaForestType(forest, "Savannah Forest Palm");
			// rmSetAreaForestType(forest, "dunes");
         rmSetAreaForestDensity(forest, 8.0);
         rmSetAreaForestClumpiness(forest, 0.2);
         rmSetAreaForestUnderbrush(forest, 0.0);
         /*
			rmSetAreaMinBlobs(forest, 1);
         rmSetAreaMaxBlobs(forest, 4);
         rmSetAreaMinBlobDistance(forest, 4.0);
         rmSetAreaMaxBlobDistance(forest, 12.0);
			*/
         rmSetAreaCoherence(forest, 0.4);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
         rmAddAreaConstraint(forest, forestConstraint);
//         rmAddAreaConstraint(forest, avoidAll);
			rmAddAreaConstraint(forest, avoidFastCoinForest);
         // rmAddAreaConstraint(forest, avoidBeach);
         rmAddAreaConstraint(forest, avoidImpassableLand); 
         rmAddAreaConstraint(forest, avoidTradeRoute);
         	rmAddAreaConstraint(forest, avoidNativesSmall); 
		  rmAddAreaConstraint(forest, avoidStartingUnits); 
			rmAddAreaConstraint(forest, avoidSocket); 
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

   // Text
   rmSetStatusText("",0.90);

	// hunt
   int bighornID=rmCreateObjectDef("bighorn sheep herd");
	rmAddObjectDefItem(bighornID, "Antelope", rmRandInt(8,10), 6.0);
   rmSetObjectDefMinDistance(bighornID, 0.0);
   rmSetObjectDefMaxDistance(bighornID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(bighornID, avoidBighornSheep);
   rmAddObjectDefConstraint(bighornID, avoidMoose);
	rmAddObjectDefConstraint(bighornID, avoidAll);
   rmAddObjectDefConstraint(bighornID, avoidImpassableLand);
//	rmAddObjectDefConstraint(bighornID, Northward);
	rmAddObjectDefConstraint(bighornID, avoidStartingUnits);
	rmAddObjectDefConstraint(bighornID, avoidSocket);
	rmAddObjectDefConstraint(bighornID, avoidTradeRoute);
	rmAddObjectDefConstraint(bighornID, avoidNatives); 
   rmSetObjectDefCreateHerd(bighornID, true);
	rmPlaceObjectDefAtLoc(bighornID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*6);

	int rheaID=rmCreateObjectDef("rhea flock");
   rmAddObjectDefItem(rheaID, "Gnu", rmRandInt(7,9), 6.0);
   rmSetObjectDefMinDistance(rheaID, 0.0);
   rmSetObjectDefMaxDistance(rheaID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(rheaID, avoidBighornSheep);
   rmAddObjectDefConstraint(rheaID, avoidMoose);
	rmAddObjectDefConstraint(rheaID, avoidAll);
	rmAddObjectDefConstraint(rheaID, avoidNatives);
//   rmAddObjectDefConstraint(rheaID, avoidImpassableLand);
    rmAddObjectDefConstraint(rheaID, avoidStartingUnits);
	rmAddObjectDefConstraint(rheaID, avoidTradeRoute);
	rmAddObjectDefConstraint(rheaID, Northward);
   rmSetObjectDefCreateHerd(rheaID, true);
	rmPlaceObjectDefAtLoc(rheaID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	int sheepID=rmCreateObjectDef("L-F-&");
	rmAddObjectDefItem(sheepID, "ypWildElephant", rmRandInt(3,4), 3.0);
	rmSetObjectDefMinDistance(sheepID, 0.0);
	rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(sheepID, avoidSheep);
	rmAddObjectDefConstraint(sheepID, avoidAll);
    rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
    rmAddObjectDefConstraint(sheepID, avoidStartingUnits);
	rmAddObjectDefConstraint(sheepID, avoidTradeRoute);
	rmAddObjectDefConstraint(sheepID, avoidNatives);
//	rmAddObjectDefConstraint(sheepID, Westward);
	rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
	
	int randomtreesID=rmCreateObjectDef("random trees");
	rmAddObjectDefItem(randomtreesID, "treeCaribbean", rmRandInt(5,9), 10.0);
	rmSetObjectDefMinDistance(randomtreesID, 0.0);
	rmSetObjectDefMaxDistance(randomtreesID, rmXFractionToMeters(0.5));
//	rmAddObjectDefConstraint(randomtreesID, avoidSheep);
	rmAddObjectDefConstraint(randomtreesID, avoidAll);
    rmAddObjectDefConstraint(randomtreesID, avoidImpassableLand);
    rmAddObjectDefConstraint(randomtreesID, avoidStartingUnits);
	rmAddObjectDefConstraint(randomtreesID, avoidTradeRoute);
	rmAddObjectDefConstraint(randomtreesID, avoidNatives);
	rmAddObjectDefConstraint(randomtreesID, Northward);
	rmPlaceObjectDefAtLoc(randomtreesID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);
	
//   rmSetMapClusteringPlacementParams(0.8, 0.2, 0.6, cClusterLand);
//   rmSetMapClusteringObjectParams(0, 1, 0.1);
//   rmPlaceMapClusters("carolinas\grass4", "underbrushRock");
	
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
