// Iberian Peninsula 

include "mercenaries.xs";
//include "GWevent.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.10);

	// Define Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;

    if (rmAllocateSubCivs(3) == true)
    {
		subCiv0=rmGetCivID("Priory");
		rmEchoInfo("subCiv0 is Priory "+subCiv0);
		if (subCiv0 >= 0)
		rmSetSubCiv(0, "Priory");

		subCiv1=rmGetCivID("FishingVillage");
		rmEchoInfo("subCiv1 is FishingVillage "+subCiv1);
		if (subCiv1 >= 0)
		rmSetSubCiv(1, "FishingVillage");

		subCiv2=rmGetCivID("Farmstead");
		rmEchoInfo("subCiv2 is Farmstead "+subCiv2);
		if (subCiv2 >= 0)
		rmSetSubCiv(2, "Farmstead");
	}

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	// 1 - Four Caribs, next to the big mountain and at the ends of the 2 long peninsulas. 
	// 2 - Four Caribs, at the ends of the 2 long peninsulas, and 2 on SE end of island.
    // 3 - Six Caribs, next to the mountain, 2 on the long peninsula, and 2 on SE end of island. 

	int whichVariation=-1;
	whichVariation = rmRandInt(1,3);
	// The line below can be uncommented to force the variation to the number indicated, for testing.
	// whichVariation = 3; 

	rmEchoInfo("Map Variation: "+whichVariation);
	
	chooseMercs();
	//gwevent();

	if ( cNumberNonGaiaPlayers > 7 )	//If 8 player game, use only variation #2 so map builds more quickly.
	{
		whichVariation = 2;
	}
	
	// Set size of map
	int playerTiles=22000;
	if (cNumberNonGaiaPlayers >4)   // If more than 4 players...
		playerTiles = 18000;		// ...give this many tiles per player.
	if (cNumberNonGaiaPlayers >7)	// If more than 7 players...
		playerTiles = 20000;		// ...give this many tiles per player.	
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size*1.5, size*1.5);

	// Set up default water type.
	rmSetSeaLevel(1.0);          
	rmSetSeaType("california coast");
	rmSetBaseTerrainMix("caribbean grass");
	rmSetMapType("caribbean");
	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetLightingSet("caribbean");

	// Initialize map.
	rmTerrainInitialize("water");

	// Misc variables for use later
	int numTries = -1;

	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
	int classMountain=rmDefineClass("mountain");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("classWall");
	rmDefineClass("natives");
	rmDefineClass("classSocket");
	rmDefineClass("canyon");
	rmDefineClass("classWaterTradeRoute");

	// Randomizes the GAIA civ.
	//int randomEUROciv=-1;
	//randomEUROciv = rmRandInt(1,3);	
	//if ( randomEUROciv == 1 )
	//		rmSetGaiaCiv(cCivFAKEiberianpeninsula1);
	//if ( randomEUROciv == 2 )
	//		rmSetGaiaCiv(cCivFAKEiberianpeninsula2);
	//if ( randomEUROciv == 3 )
	//		rmSetGaiaCiv(cCivFAKEiberianpeninsula3);
	

	
	
   // -------------Define constraints----------------------------------------

    // Create an edge of map constraint.
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Player area constraint.
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 25.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("long stay away from players", classPlayer, 60.0);
	int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 20.0);
	int nearWater10 = rmCreateTerrainDistanceConstraint("near water", "Water", true, 10.0);
	int nearWaterDock = rmCreateTerrainDistanceConstraint("near water for Dock", "Water", true, 0.0);
	int nearWaterShort = rmCreateTerrainMaxDistanceConstraint("near water for short", "Water", false, 0.0);
	int avoidTC=rmCreateTypeDistanceConstraint("stay away from TC", "TownCenter", 26.0);    //Originally 20.0 -- This adjustment, as well as changing the rmSetObjectDefMaxDistance to 12.0, has corrected the problem of nomad sometimes not placing CW for each player.
	int avoidTP=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets", "SocketTradeRoute", 14.0);  // JSB 1-11-05 - Just added, to try to prevent things from stomping on TPs.
	int avoidCW=rmCreateTypeDistanceConstraint("stay away from CW", "CoveredWagon", 24.0);
	int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);
	int wallConstraint=rmCreateClassDistanceConstraint("wall vs. wall", rmClassID("classWall"), 40.0);


	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fishMahi", 25.0);			// was 50.0
	// int fishVsFishTarponID=rmCreateTypeDistanceConstraint("fish v fish2", "fishTarpon", 20.0);  // was 40.0 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 2.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "HumpbackWhale", 40.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 17.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int avoidCoin=-1;




	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minegold", 75.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minegold", 85.0);	// 85.0 seems the best for event minegold distribution.  This number tells minegolds how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random turkeys", "turkey", 50.0);	//Attempting to spread them out more evenly.
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 54.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 120.0);  //Added sheep 11-28-05 JSB

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 14.0);  //This one is used in one place: for helping place FFA TC's better.

	// Constraint to avoid water.
	int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);   //I added this one so I could experiment with it.
	int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 8.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);  //Added this one too.
	int avoidWater80 = rmCreateTerrainDistanceConstraint("avoid water much long", "Land", false, 80.0);  //Added this one too.
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 18.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25); //Was 15, but made larger so ships don't sometimes stomp each other when arriving from HC.
	rmAddClosestPointConstraint(avoidWater8);  //was originally 8
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 10.0);
	int avoidWaterTradeRoute = rmCreateClassDistanceConstraint("avoid WTR", rmClassID("classWaterTradeRoute"), 10.0);
	int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("classSocket"), 10.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);

	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  (It excludes the west bay, where I do not want the flags.)
	int circleConstraint=rmCreatePieConstraint("semi-circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(50), rmDegreesToRadians(290));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

	// int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);

	int thenorth=rmCreatePieConstraint("semi-circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(-45), rmDegreesToRadians(135));
	int thesouth=rmCreatePieConstraint("semi-circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(135), rmDegreesToRadians(315));
	
/////////////////////////////// PLACE WATER TRADE ROUTE ////////////////////////////////////


   int watersocketID=rmCreateObjectDef("sockets to dock Water Posts");
	rmAddObjectDefItem(watersocketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(watersocketID, true);
	rmSetObjectDefMinDistance(watersocketID, 0.0);
	rmSetObjectDefMaxDistance(watersocketID, 20.0);
	rmAddObjectDefConstraint(watersocketID, avoidImpassableLand);
	rmAddObjectDefConstraint(watersocketID, nearWaterShort);
	rmAddObjectDefConstraint(watersocketID, avoidAll);

	int watertradeRouteID = rmCreateTradeRoute();
	rmAddObjectDefToClass(watertradeRouteID, rmClassID("classWaterTradeRoute"));

	rmSetObjectDefTradeRouteID(watersocketID, watertradeRouteID);

	rmAddTradeRouteWaypoint(watertradeRouteID, 1.0, 0.2);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.82, 0.25);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.68, 0.22);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.67, 0.144);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.58, 0.156);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.52, 0.12);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.40, 0.128);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.236, 0.258);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.170, 0.27);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.15, 0.35);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.075, 0.42);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.05, 0.51);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.13, 0.6);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.13, 0.67);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.31, 0.76);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.40, 0.87);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.43, 0.95);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.58, 0.90);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.62, 0.86);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.72, 0.74);
	rmAddTradeRouteWaypoint(watertradeRouteID, 0.87, 0.60);
	rmAddTradeRouteWaypoint(watertradeRouteID, 1.00, 0.71);

	bool placedTradeRouteB = rmBuildTradeRoute(watertradeRouteID, "WATERdirt");
	if(placedTradeRouteB == false)
		rmEchoError("Failed to place trade route 2");




/////////////////////////////// PENINSULA ////////////////////////////////////

	// Bonus area constraint.  
	int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 30.0);
	int mountainConstraint=rmCreateClassDistanceConstraint("avoid mountain", classMountain, 5.0);
	
   int IslandLoc = 1;

	// Make Spain

	int SpainID=rmCreateArea("Great Spain");
	rmSetAreaSize(SpainID, 0.38, 0.38);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(SpainID, 0.80);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(SpainID, 4.0);
	rmSetAreaSmoothDistance(SpainID, 20);
	rmSetAreaMix(SpainID, "california_desert0");
	rmAddAreaToClass(SpainID, classIsland);
	rmAddAreaConstraint(SpainID, islandConstraint);
	rmAddAreaConstraint(SpainID, avoidTradeRouteFar);
	rmSetAreaObeyWorldCircleConstraint(SpainID, false);
	rmSetAreaElevationType(SpainID, cElevTurbulence);
	rmSetAreaElevationVariation(SpainID, 4.0);
	rmSetAreaElevationMinFrequency(SpainID, 0.09);
	rmSetAreaElevationOctaves(SpainID, 3);
	rmSetAreaElevationPersistence(SpainID, 0.2);
	rmSetAreaElevationNoiseBias(SpainID, 1);
	rmAddAreaInfluenceSegment(SpainID, 0.515, 0.785, 0.670, 0.605);
	rmAddAreaInfluenceSegment(SpainID, 0.790, 0.500, 1.000, 0.540);
	rmAddAreaInfluenceSegment(SpainID, 1, 0.310, 0.815, 0.392);
	rmAddAreaInfluenceSegment(SpainID, 0.815, 0.392, 0.630, 0.347);
	rmAddAreaInfluenceSegment(SpainID, 0.518, 0.244, 0.413, 0.262);
	rmAddAreaInfluenceSegment(SpainID, 0.281, 0.341, 0.313, 0.427);
	rmAddAreaInfluenceSegment(SpainID, 0.205, 0.500, 0.360, 0.644);
	rmAddAreaInfluenceSegment(SpainID, 0.515, 0.785, 0.670, 0.605);

	rmSetAreaWarnFailure(SpainID, false);

	if (IslandLoc == 1)


	rmSetAreaLocation(SpainID, .5, .5);
	rmBuildArea(SpainID);


		// Make Gibraltar

	int GibraltarID=rmCreateArea("Gibraltar");
	rmSetAreaSize(GibraltarID, 0.06, 0.06);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(GibraltarID, 0.80);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(GibraltarID, 4.0);
	rmSetAreaSmoothDistance(GibraltarID, 20);
	rmSetAreaMix(GibraltarID, "california_desert0");
	rmAddAreaToClass(GibraltarID, classIsland);
	rmAddAreaConstraint(GibraltarID, islandConstraint);
	rmAddAreaConstraint(GibraltarID, avoidTradeRouteFar);
	rmSetAreaObeyWorldCircleConstraint(GibraltarID, false);
	rmSetAreaElevationType(GibraltarID, cElevTurbulence);
	rmSetAreaElevationVariation(GibraltarID, 4.0);
	rmSetAreaElevationMinFrequency(GibraltarID, 0.09);
	rmSetAreaElevationOctaves(GibraltarID, 3);
	rmSetAreaElevationPersistence(GibraltarID, 0.2);
	rmSetAreaElevationNoiseBias(GibraltarID, 1);
	rmAddAreaInfluenceSegment(GibraltarID, 0.0, 0.0, 0.03, 0.3);
		rmAddAreaInfluenceSegment(GibraltarID, 0.03, 0.3,  0.17, 0.27);
	rmAddAreaInfluenceSegment(GibraltarID, 0.17, 0.27, 0.17, 0.16);
	rmAddAreaInfluenceSegment(GibraltarID, 0.17, 0.16, 0.42, 0.02);
	rmAddAreaInfluenceSegment(GibraltarID, 0.42, 0.02, 0.00, 0.00);

	rmSetAreaLocation(GibraltarID, .0, .0);
	rmBuildArea(GibraltarID);


			// Make the Mountains

	int MountainsID=rmCreateArea("Mountains");
	rmSetAreaSize(MountainsID, 0.05, 0.05);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(MountainsID, 0.80);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
//	rmSetAreaBaseHeight(MountainsID, 4.0);
	rmSetAreaSmoothDistance(MountainsID, 20);
	rmSetAreaMix(MountainsID, "california_desert0");
	rmAddAreaToClass(MountainsID, classIsland);
	rmAddAreaToClass(MountainsID, classMountain);
//	rmAddAreaConstraint(MountainsID, islandConstraint);
	rmAddAreaConstraint(MountainsID, avoidTradeRouteFar);
	rmSetAreaObeyWorldCircleConstraint(MountainsID, false);
	rmSetAreaCliffType(MountainsID, "Araucania Southern Coast");
	rmSetAreaCliffEdge(MountainsID, 1, 1, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(MountainsID, 6, 1.0, 1.0);
	rmSetAreaMinBlobs(MountainsID, 2);
	rmSetAreaMaxBlobs(MountainsID, 5);
	rmSetAreaMinBlobDistance(MountainsID, 10.0);
	rmSetAreaMaxBlobDistance(MountainsID, 30.0);
	rmSetAreaElevationType(MountainsID, cElevTurbulence);
	rmSetAreaElevationVariation(MountainsID, 1.0);
	rmSetAreaElevationMinFrequency(MountainsID, 0.09);
	rmSetAreaElevationOctaves(MountainsID, 3);
	rmSetAreaElevationPersistence(MountainsID, 0.2);
	rmSetAreaElevationNoiseBias(MountainsID, 1);
	rmAddAreaInfluenceSegment(MountainsID,  .95, .3,  .95, .6); 
	rmSetAreaLocation(MountainsID, .95, .41);
	rmBuildArea(MountainsID);



/////////////////////////////// RIVER TEJO ////////////////////////////////////

		if(cNumberTeams <= 2)
		{
			// Middle River - Only appears if there are 2 teams.
			int riverID = rmRiverCreate(-1, "Tejo River", 5, 15, 5, 8);
			rmRiverAddWaypoint(riverID, 0.31, 0.62); 
			rmRiverAddWaypoint(riverID, 0.49, 0.49);
			rmRiverAddWaypoint(riverID, 0.62, 0.45);

			rmRiverAddWaypoint(riverID, 0.62, 0.37);
			rmRiverAddWaypoint(riverID, 0.55, 0.30);
			rmRiverAddWaypoint(riverID, 0.65, 0.20);
			rmRiverSetShallowRadius(riverID, 16+cNumberNonGaiaPlayers);

				// crossing on top - players on bottom
				rmRiverAddShallow(riverID, rmRandFloat(0.0, 0.0));
				rmRiverAddShallow(riverID, rmRandFloat(0.2, 0.4));
				rmRiverAddShallow(riverID, rmRandFloat(0.7, 0.8));

			//rmRiverSetBankNoiseParams(riverID, 0.07, 2, 1.5, 10.0, 0.667, 3.0);
			rmRiverSetBankNoiseParams(riverID, 0.07, 2, 1.5, 10.0, 0.667, 2.0);
			rmRiverBuild(riverID);
		}
		else
		{

		}




/////////////////////////////// PLACE SOCKETS ////////////////////////////////////

	//NORTH
		rmPlaceObjectDefAtLoc(watersocketID, 0, 0.75, 0.27); //
		rmPlaceObjectDefAtLoc(watersocketID, 0, 0.48, 0.88); //
		rmPlaceObjectDefAtLoc(watersocketID, 0, 0.76, 0.66); //
		
	//SOUTH
		rmPlaceObjectDefAtLoc(watersocketID, 0, 0.2, 0.3); //
		rmPlaceObjectDefAtLoc(watersocketID, 0, 0.4, 0.18); //
		rmPlaceObjectDefAtLoc(watersocketID, 0, 0.18, 0.65); //



/////////////////////////////// DEFINE PLAYER AREAS ////////////////////////////////////

		//rmSetTeamSpacingModifier(0.6);

		float teamStartLoc = rmRandFloat(0.0, 1.0);
		if(cNumberTeams > 2)
		{
			rmSetPlacementSection(0.0, 1.00);
			rmPlacePlayersCircular(0.26, 0.26, 0);
		}
		else
		{
			// Team 0 starts up
			if (teamStartLoc > 0.5)
			{
				rmSetPlacementTeam(0);
				rmPlacePlayersLine(0.2, 0.5, 0.5, 0.27, 0.0, 0.0);
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.45, 0.7, 0.75, 0.47, 0.0, 0.0);
			}
			else
			{
				rmSetPlacementTeam(0);
				rmPlacePlayersLine(0.45, 0.7, 0.75, 0.47, 0.0, 0.0);
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.2, 0.5, 0.5, 0.27, 0.0, 0.0);
			}
		}
	float playerFraction=rmAreaTilesToFraction(500 + cNumberNonGaiaPlayers*150);
	string herdableType = "ypWaterBuffalo";
	string huntable1 = "deer";
	string huntable2 = "rabbit";
	string huntable3 = "ypIbex";
	string fish1 = "FishTarpon";
	string fish2 = "FishTarpon";
	string whale1 = "HumpbackWhale";
	string startTreeType = "TreeMadrone";
  
  	/////////////////////////////// PLACE PLAYERS ////////////////////////////////////

	int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 60.0);
	int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 60.0);
	int avoidHuntable3=rmCreateTypeDistanceConstraint("avoid huntable3", huntable3, 60.0);
	int avoidTradeRouteSocketsShort=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 8.0);
	int avoidTCshort=rmCreateTypeDistanceConstraint("stay away from TC by a little bit", "TownCenter", 14.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 5.0);
	rmDefineClass("Road");
	  	int avoidRoad = rmCreateClassDistanceConstraint("avoid road", rmClassID("Road"), 0.0);
	  	int avoidRoadlonger = rmCreateClassDistanceConstraint("avoid road long", rmClassID("Road"), 10.0);

	int food1ID=rmCreateObjectDef("huntable1");
	rmAddObjectDefItem(food1ID, huntable1, rmRandInt(3,5), 6.0);
	rmSetObjectDefCreateHerd(food1ID, true);
	rmSetObjectDefMinDistance(food1ID, 0.0);
	rmSetObjectDefMaxDistance(food1ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food1ID, avoidResource);
	rmAddObjectDefConstraint(food1ID, playerConstraint);
	rmAddObjectDefConstraint(food1ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food1ID, avoidHuntable1);
	rmAddObjectDefConstraint(food1ID, avoidWater2);
	rmAddObjectDefConstraint(food1ID, avoidRoad);
	rmAddObjectDefConstraint(food1ID, mountainConstraint);
	rmAddObjectDefConstraint(food1ID, avoidHuntable2);
	rmAddObjectDefConstraint(food1ID, avoidHuntable3);
	rmAddObjectDefConstraint(food1ID, avoidTC);
	rmAddObjectDefConstraint(food1ID, avoidTradeRouteSocketsShort);

	int food2ID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(food2ID, huntable2, rmRandInt(5,6), 4.0);
	rmSetObjectDefCreateHerd(food2ID, true);
	rmSetObjectDefMinDistance(food2ID, 0.0);
	rmSetObjectDefMaxDistance(food2ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food2ID, avoidResource);
	rmAddObjectDefConstraint(food2ID, playerConstraint);
	rmAddObjectDefConstraint(food2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food2ID, avoidHuntable1);
	rmAddObjectDefConstraint(food2ID, avoidHuntable2);
	rmAddObjectDefConstraint(food2ID, mountainConstraint);
	rmAddObjectDefConstraint(food2ID, avoidRoad);
	rmAddObjectDefConstraint(food2ID, avoidHuntable3);
	rmAddObjectDefConstraint(food2ID, avoidWater2);
	rmAddObjectDefConstraint(food2ID, avoidTC);
	rmAddObjectDefConstraint(food2ID, avoidTradeRouteSocketsShort);

   int food3ID=rmCreateObjectDef("huntable3");
	rmAddObjectDefItem(food3ID, huntable3, rmRandInt(4,6), 6.0);
	rmSetObjectDefCreateHerd(food3ID, true);
	rmSetObjectDefMinDistance(food3ID, 0.0);
	rmSetObjectDefMaxDistance(food3ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food3ID, avoidResource);
	rmAddObjectDefConstraint(food3ID, playerConstraint);
	rmAddObjectDefConstraint(food3ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food3ID, avoidHuntable1);
	rmAddObjectDefConstraint(food3ID, mountainConstraint);
	rmAddObjectDefConstraint(food3ID, avoidHuntable2);
	rmAddObjectDefConstraint(food3ID, avoidHuntable3);
	rmAddObjectDefConstraint(food3ID, avoidRoad);
	rmAddObjectDefConstraint(food3ID, avoidWater2);
	rmAddObjectDefConstraint(food3ID, avoidTC);
	rmAddObjectDefConstraint(food3ID, avoidTradeRouteSocketsShort);

	//Place player TCs and starting Gold Mines.

	int TCID = rmCreateObjectDef("player TC");
	if ( rmGetNomadStart())
		rmAddObjectDefItem(TCID, "coveredWagon", 1, 0);
	else
		rmAddObjectDefItem(TCID, "townCenter", 1, 0);

	//Prepare to place TCs
	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, 10.0);

	//Prepare to place Explorers, Explorer's dog, etc.
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 8.0);
	rmSetObjectDefMaxDistance(startingUnits, 12.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);

	//Prepare to place player starting Mines 
	int playerGoldID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(playerGoldID, "mine", 2, 0);
	rmSetObjectDefMinDistance(playerGoldID, 20.0);
	rmSetObjectDefMaxDistance(playerGoldID, 25.0);
	rmAddObjectDefConstraint(playerGoldID, avoidRoad);
	rmAddObjectDefConstraint(playerGoldID, avoidAll);
	rmAddObjectDefConstraint(playerGoldID, avoidTCshort);
	rmAddObjectDefConstraint(playerGoldID, avoidStartResource);
	rmAddObjectDefConstraint(playerGoldID, avoidImpassableLand);

	//Prepare to place player starting church 
	int playerChurchID = rmCreateObjectDef("player church");
	rmAddObjectDefItem(playerChurchID, "Church", 1, 10);
	rmAddObjectDefItem(playerChurchID, "Missionary", 1, 4.0);
	rmSetObjectDefMinDistance(playerChurchID, 15.0);
	rmSetObjectDefMaxDistance(playerChurchID, 20.0);
	rmAddObjectDefConstraint(playerChurchID, avoidRoad);
	rmAddObjectDefConstraint(playerChurchID, avoidAll);
	rmAddObjectDefConstraint(playerChurchID, avoidTCshort);
	rmAddObjectDefConstraint(playerChurchID, avoidStartResource);
	rmAddObjectDefConstraint(playerChurchID, avoidImpassableLand);
  
	//Prepare to place player starting food
	int playerFoodID=rmCreateObjectDef("player food");
	rmAddObjectDefItem(playerFoodID, huntable3, 6, 4.0);
	rmSetObjectDefMinDistance(playerFoodID, 10);
	rmSetObjectDefMaxDistance(playerFoodID, 15);
	rmAddObjectDefConstraint(playerFoodID, avoidAll);
	rmAddObjectDefConstraint(playerFoodID, avoidTCshort);
//	rmAddObjectDefConstraint(playerFoodID, avoidStartResource);
	rmAddObjectDefConstraint(playerFoodID, avoidImpassableLand);
	rmSetObjectDefCreateHerd(playerFoodID, false);
  
	//Prepare to place player starting Berries
	int playerBerriesID=rmCreateObjectDef("player berries");
	rmAddObjectDefItem(playerBerriesID, "berrybush", 6, 4.0);
	rmSetObjectDefMinDistance(playerBerriesID, 15);
	rmSetObjectDefMaxDistance(playerBerriesID, 20);
	rmAddObjectDefConstraint(playerBerriesID, avoidRoad); 
	rmAddObjectDefConstraint(playerBerriesID, avoidAll);
	rmAddObjectDefConstraint(playerBerriesID, avoidTCshort);
	rmAddObjectDefConstraint(playerBerriesID, avoidStartResource);
	rmAddObjectDefConstraint(playerBerriesID, avoidImpassableLand);

	//Prepare to place player starting trees
	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 10, 12.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 10);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 30);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidWater8);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidTC);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartResource);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImpassableLand);


	// Starting area nuggets
	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
	rmSetObjectDefMinDistance(playerNuggetID, 10.0);
	rmSetObjectDefMaxDistance(playerNuggetID, 20.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidRoad); 
	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
	rmAddObjectDefConstraint(playerNuggetID, avoidTCshort);
	rmAddObjectDefConstraint(playerNuggetID, shortAvoidImpassableLand);

	int waterSpawnPointID = 0;

	/////////////////////////////// PLACE PAVEMENT AND ROADS ////////////////////////////////////

  for(i=1; <cNumberPlayers) {
    int id=rmCreateArea("Player"+i);
    rmSetPlayerArea(i, id);
    rmSetAreaSize(id, playerFraction/4, playerFraction/4);
    rmAddAreaToClass(id, classPlayer);
    rmSetAreaCoherence(id, 1.0);
    rmSetAreaLocPlayer(id, i);
	      rmSetAreaCoherence(id, 0.35);
   rmSetAreaTerrainType(id, "props\east_colony2");
	rmAddAreaToClass(id, rmClassID("Road"));
    rmSetAreaWarnFailure(id, true);
  }

	if (cNumberTeams <= 2)
	{
	int roadvariable1 = rmRandFloat(-0.02,0.02);
	int roadvariable2 = rmRandFloat(-0.02,0.02);

    int road1ID=rmCreateArea("Road1");
    rmSetAreaSize(road1ID, playerFraction/3, playerFraction/3);
    rmSetAreaCoherence(road1ID, 0.95);
		rmAddAreaInfluenceSegment(road1ID, 0.2, 0.5, 0.3+roadvariable1, 0.45+roadvariable1); 
		rmAddAreaInfluenceSegment(road1ID, 0.3+roadvariable1, 0.45+roadvariable1, 0.4+roadvariable2, 0.35+roadvariable2); 
		rmAddAreaInfluenceSegment(road1ID, 0.4+roadvariable2, 0.35+roadvariable2, 0.5, 0.27); 
   rmSetAreaTerrainType(road1ID, "props\east_colony2");
	rmAddAreaToClass(road1ID, rmClassID("Road"));
    rmSetAreaWarnFailure(road1ID, true);
 		rmSetAreaLocation(road1ID, 0.2, 0.5); 
		rmBuildArea(road1ID); 
 
    int road2ID=rmCreateArea("Road2");
    rmSetAreaSize(road2ID, playerFraction/3, playerFraction/3);
    rmSetAreaCoherence(road2ID, 0.95);
		rmAddAreaInfluenceSegment(road2ID, 0.45, 0.7, 0.55+roadvariable1, 0.61+roadvariable1); 
		rmAddAreaInfluenceSegment(road2ID, 0.55+roadvariable1, 0.61+roadvariable1, 0.65+roadvariable2, 0.55+roadvariable2); 
		rmAddAreaInfluenceSegment(road2ID, 0.65+roadvariable2, 0.55+roadvariable2, 0.75, 0.47); 
   rmSetAreaTerrainType(road2ID, "props\east_colony2");
	rmAddAreaToClass(road2ID, rmClassID("Road"));
    rmSetAreaWarnFailure(road2ID, true);
 		rmSetAreaLocation(road2ID, 0.45, 0.7); 
		rmBuildArea(road2ID); 
	}
	else
	{
		
	}	
  
  rmBuildAllAreas();
   
	
	/////////////////////////////// PLACE PLAYERS ////////////////////////////////////
		
		
  
  rmClearClosestPointConstraints();

	for(i=1; <cNumberPlayers) {
    
    // Place TC and starting units
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerChurchID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));    
		rmPlaceObjectDefAtLoc(playerFoodID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 
    rmPlaceObjectDefAtLoc(playerBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 

		// Place player starting trees
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    
    // Place starting nugget
    rmSetNuggetDifficulty(21, 21);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

    if(ypIsAsian(i) && rmGetNomadStart() == false)
      rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    
		// Place water spawn points for the players along with a canoe
		waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 10.0);
		rmAddClosestPointConstraint(flagVsFlag);
		rmAddClosestPointConstraint(flagLand);
//    rmAddClosestPointConstraint(flagEdgeConstraint);
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
     
 
       int fail=0;	
   rmDefineClass("natives");  
	int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 50.0);
		int avoidNativeslong=rmCreateClassDistanceConstraint("stuff avoids natives long", rmClassID("natives"), 70.0);
	int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives by a bit", rmClassID("natives"), 20.0);
	


   
	/////////////////////////////// PLACE EUROPEAN VILLAGES ////////////////////////////////////


	
	        // Native settlements defined and placed
 
		int whichNative = 0;
      int nativeVillage = 0;
		string nativeName = "";
	  
      whichNative = rmRandInt(1,3);
      if(whichNative == 1)
      {
         rmSetSubCiv(1, "FishingVillage");
         nativeName = "european fishing village med";
      }
	   if(whichNative == 2)
      {
         rmSetSubCiv(2, "Farmstead");
         nativeName = "european farmstead med";
      }
      else
      {
         rmSetSubCiv(0, "Priory");
         nativeName = "european priory med";
      }


	int avoidNativesVeryLong = rmCreateClassDistanceConstraint("avoid natives long ", rmClassID("natives"), 100.0);

	
	if (cNumberTeams <= 2)
	{
      nativeVillage = rmCreateGrouping("European "+i, nativeName);
      rmSetGroupingMinDistance(nativeVillage, 40.0);
      rmSetGroupingMaxDistance(nativeVillage, 80.0);
      rmAddGroupingToClass(nativeVillage, playerConstraint);
      rmAddGroupingConstraint(nativeVillage, avoidAll);
      rmAddGroupingConstraint(nativeVillage, avoidWater8);
	  	rmAddGroupingConstraint(nativeVillage, avoidNatives);
		  	rmAddGroupingConstraint(nativeVillage, avoidRoadlonger);
		rmAddGroupingToClass(nativeVillage, rmClassID("natives"));
	 	rmAddGroupingConstraint(nativeVillage, avoidImpassableLand);
	rmAddGroupingConstraint(nativeVillage, mountainConstraint);
      rmPlaceGroupingAtLoc(nativeVillage, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	}
	else
	{
      nativeVillage = rmCreateGrouping("European "+i, nativeName);
      rmSetGroupingMinDistance(nativeVillage, 40.0);
      rmSetGroupingMaxDistance(nativeVillage, 80.0);
      rmAddGroupingToClass(nativeVillage, playerConstraint);
      rmAddGroupingConstraint(nativeVillage, avoidAll);
      rmAddGroupingConstraint(nativeVillage, avoidWater8);
		  	rmAddGroupingConstraint(nativeVillage, avoidRoadlonger);
	  	rmAddGroupingConstraint(nativeVillage, avoidNatives);
		rmAddGroupingToClass(nativeVillage, rmClassID("natives"));
	 	rmAddGroupingConstraint(nativeVillage, avoidImpassableLand);
	rmAddGroupingConstraint(nativeVillage, mountainConstraint);
      rmPlaceGroupingAtLoc(nativeVillage, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
			
	
	}

	  
		rmClearClosestPointConstraints();
   }
   


   /////////////////////////////// MINES ////////////////////////////////////


	// Silver

		int avoidSilver=rmCreateTypeDistanceConstraint("avoid silver", "minegold", 75.0);
		
	int silverID = -1;
 	int silverID2 = -1;

  int silverCount = 0;
  
  silverCount = cNumberNonGaiaPlayers*2;
  
	rmEchoInfo("silver count = "+silverCount);


  // north gold mines
  silverID2 = rmCreateObjectDef("gold n"+i);
  rmAddObjectDefItem(silverID2, "minegold", 1, 0.0);
  rmSetObjectDefMinDistance(silverID2, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(silverID2, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(silverID2, avoidImpassableLand);
  rmAddObjectDefConstraint(silverID2, avoidSilver);
   rmAddObjectDefConstraint(silverID2, avoidWater40);
    rmAddObjectDefConstraint(silverID2, avoidRoadlonger);
  rmAddObjectDefConstraint(silverID2, playerConstraint);
  rmAddObjectDefConstraint(silverID2, mountainConstraint);
  rmAddObjectDefConstraint(silverID2, avoidAll);
   rmAddObjectDefConstraint(silverID2, thenorth);
  rmPlaceObjectDefInArea(silverID2, 0, SpainID, silverCount);

  // south gold mines
  silverID = rmCreateObjectDef("gold s"+i);
  rmAddObjectDefItem(silverID, "minegold", 1, 0.0);
  rmSetObjectDefMinDistance(silverID, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(silverID, avoidImpassableLand);
  rmAddObjectDefConstraint(silverID, avoidSilver);
   rmAddObjectDefConstraint(silverID, avoidWater40);
    rmAddObjectDefConstraint(silverID, avoidRoadlonger);
  rmAddObjectDefConstraint(silverID, playerConstraint);
  rmAddObjectDefConstraint(silverID, mountainConstraint);
  rmAddObjectDefConstraint(silverID, avoidAll);
    rmAddObjectDefConstraint(silverID, thesouth);
  rmPlaceObjectDefInArea(silverID, 0, SpainID, silverCount);
  
   /////////////////////////////// NUGGETS ////////////////////////////////////
  
  	int nuggetID= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(21, 21);
	rmSetObjectDefMinDistance(nuggetID, 0.0);
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggetID, avoidNugget);
  	rmAddObjectDefConstraint(nuggetID, avoidTC);
  	rmAddObjectDefConstraint(nuggetID, avoidTradeRoute);
  	rmAddObjectDefConstraint(nuggetID, avoidAll);
  	rmAddObjectDefConstraint(nuggetID, avoidRoadlonger);
	  	rmAddObjectDefConstraint(nuggetID, mountainConstraint);
  	rmAddObjectDefConstraint(nuggetID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	int nuggetmediumID= rmCreateObjectDef("nugget medium"); 
	rmAddObjectDefItem(nuggetmediumID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(22, 22);
	rmSetObjectDefMinDistance(nuggetmediumID, 0.0);
	rmSetObjectDefMaxDistance(nuggetmediumID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggetmediumID, avoidNugget);
  	rmAddObjectDefConstraint(nuggetmediumID, avoidTC);
  	rmAddObjectDefConstraint(nuggetmediumID, avoidTradeRoute);
	  	rmAddObjectDefConstraint(nuggetmediumID, avoidRoadlonger);
	  	rmAddObjectDefConstraint(nuggetmediumID, mountainConstraint);
  	rmAddObjectDefConstraint(nuggetmediumID, avoidAll);
  	rmAddObjectDefConstraint(nuggetmediumID, longAvoidImpassableLand);
	rmPlaceObjectDefAtLoc(nuggetmediumID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);


	int nuggethardID= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nuggethardID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(23, 23);
	rmSetObjectDefMinDistance(nuggethardID, 0.0);
	rmSetObjectDefMaxDistance(nuggethardID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggethardID, avoidNugget);
  	rmAddObjectDefConstraint(nuggethardID, avoidTC);
  	rmAddObjectDefConstraint(nuggethardID, avoidTradeRoute);
	  	rmAddObjectDefConstraint(nuggethardID, avoidRoadlonger);
	  	rmAddObjectDefConstraint(nuggethardID, mountainConstraint);
  	rmAddObjectDefConstraint(nuggethardID, avoidAll);
	rmAddObjectDefConstraint(nuggethardID, playerEdgeConstraint);
  	rmAddObjectDefConstraint(nuggethardID, longAvoidImpassableLand);
	rmPlaceObjectDefAtLoc(nuggethardID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	if(rmRandFloat(0,1) < 0.25) //places more hard 25% of the time
	{
		int nuggethard2ID= rmCreateObjectDef("nugget more hard"); 
		rmAddObjectDefItem(nuggethard2ID, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(23, 23);
		rmSetObjectDefMinDistance(nuggethard2ID, 0.0);
		rmSetObjectDefMaxDistance(nuggethard2ID, rmXFractionToMeters(0.5));
  		rmAddObjectDefConstraint(nuggethard2ID, avoidNugget);
  		rmAddObjectDefConstraint(nuggethard2ID, avoidTC);
			  	rmAddObjectDefConstraint(nuggethard2ID, avoidRoadlonger);
	  	rmAddObjectDefConstraint(nuggethard2ID, mountainConstraint);
  		rmAddObjectDefConstraint(nuggethard2ID, avoidTradeRoute);
  		rmAddObjectDefConstraint(nuggethard2ID, avoidAll);
		rmAddObjectDefConstraint(nuggethard2ID, playerEdgeConstraint);
  		rmAddObjectDefConstraint(nuggethard2ID, longAvoidImpassableLand);
		rmPlaceObjectDefAtLoc(nuggethard2ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);
	}


	//only try to place these 75% of the time
	   if(rmRandFloat(0,1) > 0.25)
	   {
		int nuggetnutsID= rmCreateObjectDef("nugget nuts"); 
		rmAddObjectDefItem(nuggetnutsID, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(24, 24);
		rmSetObjectDefMinDistance(nuggetnutsID, 0.0);
		rmSetObjectDefMaxDistance(nuggetnutsID, rmXFractionToMeters(0.5));
  		rmAddObjectDefConstraint(nuggetnutsID, avoidNugget);
  		rmAddObjectDefConstraint(nuggetnutsID, avoidTC);
					  	rmAddObjectDefConstraint(nuggetnutsID, avoidRoadlonger);
	  	rmAddObjectDefConstraint(nuggetnutsID, mountainConstraint);
  		rmAddObjectDefConstraint(nuggetnutsID, avoidTradeRoute);
  		rmAddObjectDefConstraint(nuggetnutsID, avoidAll);
		rmAddObjectDefConstraint(nuggetnutsID, playerEdgeConstraint);
  		rmAddObjectDefConstraint(nuggetnutsID, longAvoidImpassableLand);
		rmPlaceObjectDefAtLoc(nuggetnutsID, GibraltarID, 0.5, 0.5, cNumberNonGaiaPlayers);
	   }
	   
	   
	   
   /////////////////////////////// FORESTS ////////////////////////////////////

	// Scattered FORESTS
   int forestTreeID = 0;
   numTries=10*cNumberNonGaiaPlayers;
   int failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest, "california madrone forest");
         rmSetAreaForestDensity(forest, 0.4);
         rmSetAreaForestClumpiness(forest, 0.4);
         rmSetAreaForestUnderbrush(forest, 0.0);
         rmSetAreaMinBlobs(forest, 1);
         rmSetAreaMaxBlobs(forest, 5);
         rmSetAreaMinBlobDistance(forest, 16.0);
         rmSetAreaMaxBlobDistance(forest, 40.0);
         rmSetAreaCoherence(forest, 0.4);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
         rmAddAreaConstraint(forest, forestConstraint);
         rmAddAreaConstraint(forest, avoidAll);
         rmAddAreaConstraint(forest, avoidRoadlonger);
         rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(forest, mountainConstraint);
		 rmAddAreaConstraint(forest, avoidTC);
		 rmAddAreaConstraint(forest, avoidCW);
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
	  
	  //SPARCE TREES
 
  int avoidSparce=rmCreateTypeDistanceConstraint("avoid sparce trees", startTreeType, 10.0); 
  
	//Prepare to place player starting trees
	int SparceTreeID=rmCreateObjectDef("sparce trees");
	rmAddObjectDefItem(SparceTreeID, startTreeType, 5, 10.0);
	rmSetObjectDefMinDistance(SparceTreeID, 0.0);
	rmSetObjectDefMaxDistance(SparceTreeID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(SparceTreeID, avoidAll);
	rmAddObjectDefConstraint(SparceTreeID, avoidWater8);
		rmAddObjectDefConstraint(SparceTreeID, avoidTC);
		rmAddObjectDefConstraint(SparceTreeID, avoidRoadlonger);
		rmAddObjectDefConstraint(SparceTreeID, avoidSparce);
		rmAddObjectDefConstraint(SparceTreeID, mountainConstraint);
	rmAddObjectDefConstraint(SparceTreeID, avoidStartResource);
	rmAddObjectDefConstraint(SparceTreeID, shortAvoidImpassableLand);

	  rmPlaceObjectDefAtLoc(SparceTreeID, 0, 0.5, 0.5, 4.0*cNumberNonGaiaPlayers);	
	
	/////////////////////////////// HUNTABLES ////////////////////////////////////

  rmPlaceObjectDefAtLoc(food1ID, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
  rmPlaceObjectDefAtLoc(food2ID, 0, 0.5, 0.5, 2.0*cNumberNonGaiaPlayers);
  rmPlaceObjectDefAtLoc(food3ID, 0, 0.5, 0.5, 2.0*cNumberNonGaiaPlayers);
  
		
	/////////////////////////////// PLACE ROAD EMBELLISHMENT ////////////////////////////////////

	int objectVSpot=rmCreateTypeDistanceConstraint("pot vs pot", "PropsPottedPlants", 20.0);	//Was 8.0
	

	int pottedplantsID=rmCreateObjectDef("potted plants");
	rmAddObjectDefItem(pottedplantsID, "PropsPottedPlants", 1, 0.0);
	rmSetObjectDefMinDistance(pottedplantsID, 1.0);
	rmSetObjectDefMaxDistance(pottedplantsID, 2.0);
	rmAddObjectDefConstraint(pottedplantsID, avoidAll);
	rmAddObjectDefConstraint(pottedplantsID, objectVSpot);
	rmAddObjectDefConstraint(pottedplantsID, avoidRoad);	
	rmAddObjectDefConstraint(pottedplantsID, playerConstraint);	
	rmSetObjectDefMaxDistance(pottedplantsID, rmXFractionToMeters(0.5));
	rmPlaceObjectDefInArea(pottedplantsID, 0, road1ID, 2*cNumberNonGaiaPlayers);   //Scatter 8 random trees per player.
	rmPlaceObjectDefInArea(pottedplantsID, 0, road2ID, 2*cNumberNonGaiaPlayers);   //Scatter 8 random trees per player.	 

	/////////////////////////////// PLACE MOUNTAIN FOREST ////////////////////////////////////

	//Prepare to place player starting trees
	int MountainTreeID=rmCreateObjectDef("mountain trees");
	rmAddObjectDefItem(MountainTreeID, "TreeGreatLakesSnow", 100, 0.0);
	rmSetObjectDefMinDistance(MountainTreeID, 0.0);
	rmSetObjectDefMaxDistance(MountainTreeID, 2);
//	rmAddObjectDefConstraint(MountainTreeID, avoidAll);
	rmAddObjectDefConstraint(MountainTreeID, avoidTC);
	rmAddObjectDefConstraint(MountainTreeID, avoidRoadlonger);
//	rmAddObjectDefConstraint(MountainTreeID, avoidSparce);
//	rmAddObjectDefConstraint(MountainTreeID, avoidStartResource);
	rmAddObjectDefConstraint(MountainTreeID, shortAvoidImpassableLand);
	rmPlaceObjectDefInArea(MountainTreeID, 0, MountainsID, 100*cNumberNonGaiaPlayers);   //Scatter 8 random trees per player.	 	


	/////////////////////////////// PLACE FISH ////////////////////////////////////

	int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 30.0);	

	int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, fish1, 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 20*cNumberNonGaiaPlayers);

	// Silly Rock Walls can get placed last.  May not place at all...
	int stoneWallType = -1;
	int stoneWallID = -1;
	int stoneWallCount = cNumberNonGaiaPlayers*2;	
	rmEchoInfo("stoneWall count = "+stoneWallCount);

	for(i=0; < stoneWallCount)
	{
		stoneWallType = rmRandInt(1,4);
      stoneWallID = rmCreateGrouping("stone wall "+i, "ne_rockwall "+stoneWallType);
		rmAddGroupingToClass(stoneWallID, rmClassID("classWall"));
      rmSetGroupingMinDistance(stoneWallID, 0.0);
      rmSetGroupingMaxDistance(stoneWallID, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(stoneWallID, avoidTC);
		rmAddGroupingConstraint(stoneWallID, avoidWater8);
		rmAddGroupingConstraint(stoneWallID, avoidImpassableLand);
		rmAddGroupingConstraint(stoneWallID, avoidRoadlonger);
		rmAddGroupingConstraint(stoneWallID, mountainConstraint);
		rmPlaceGroupingAtLoc(stoneWallID, 0, 0.5, 0.5);
   }

  // King of the Hill (added 2026-11 for WoL): the middle is on the inner river; first open land on the line that splits the teams
  if(rmGetIsKOTH()) {
    // the middle of each team's starts (player 1's team, and everybody else)
    float kothAX = 0.0;
    float kothAZ = 0.0;
    float kothAN = 0.0;
    float kothBX = 0.0;
    float kothBZ = 0.0;
    float kothBN = 0.0;
    for (kothP = 1; < cNumberPlayers) {
      if (rmGetPlayerTeam(kothP) == rmGetPlayerTeam(1)) {
        kothAX = kothAX + rmPlayerLocXFraction(kothP);
        kothAZ = kothAZ + rmPlayerLocZFraction(kothP);
        kothAN = kothAN + 1.0;
      }
      else {
        kothBX = kothBX + rmPlayerLocXFraction(kothP);
        kothBZ = kothBZ + rmPlayerLocZFraction(kothP);
        kothBN = kothBN + 1.0;
      }
    }
    // from the point between them, along the line square to the one joining them
    float kothX = 0.5;
    float kothZ = 0.5;
    float kothDirX = 1.0;
    float kothDirZ = 0.0;
    if (kothBN > 0.0) {
      kothAX = kothAX / kothAN;
      kothAZ = kothAZ / kothAN;
      kothBX = kothBX / kothBN;
      kothBZ = kothBZ / kothBN;
      kothX = (kothAX + kothBX) / 2.0;
      kothZ = (kothAZ + kothBZ) / 2.0;
      float kothLen = sqrt((kothBX - kothAX) * (kothBX - kothAX) + (kothBZ - kothAZ) * (kothBZ - kothAZ));
      if (kothLen > 0.01) {
        kothDirX = 0.0 - (kothBZ - kothAZ) / kothLen;
        kothDirZ = (kothBX - kothAX) / kothLen;
      }
    }
    // the hill on the first open land along that line, from the middle outwards, one side then the other
    // (0.04 of the map side per step), with the include's placer constraints, 40 m from every Town Center
    // and 10 m from every tree
    int kothAvoidLand = rmCreateTerrainDistanceConstraint("koth hill avoids impassable land", "Land", false, 6.0);
    int kothAvoidAll = rmCreateTypeDistanceConstraint("koth hill avoids all", "all", 4.0);
    int kothAvoidTC = rmCreateTypeDistanceConstraint("koth hill avoids TCs", "TownCenter", 40.0);
    int kothAvoidTrees = rmCreateTypeDistanceConstraint("koth hill avoids trees", "Tree", 10.0);
    int kothAvoidSocket = rmCreateTypeDistanceConstraint("koth hill avoids trade sockets", "socketTradeRoute", 6.0);
    int kothAvoidRoute = rmCreateTradeRouteDistanceConstraint("koth hill avoids trade route", 6.0);
    int kothAvoidFlag = rmCreateTypeDistanceConstraint("koth hill avoids water flags", "HomeCityWaterSpawnFlag", 4.0);
    float kothDist = 0.0;
    for (kothRound = 0; < 17) {
      int kothHill = rmCreateObjectDef("koth hill " + kothRound);
      rmAddObjectDefItem(kothHill, "ypKingsHill", 1, 0);
      rmSetObjectDefMinDistance(kothHill, 0.0);
      rmSetObjectDefMaxDistance(kothHill, rmXFractionToMeters(0.05));
      rmAddObjectDefConstraint(kothHill, kothAvoidLand);
      rmAddObjectDefConstraint(kothHill, kothAvoidAll);
      rmAddObjectDefConstraint(kothHill, kothAvoidTC);
      rmAddObjectDefConstraint(kothHill, kothAvoidTrees);
      rmAddObjectDefConstraint(kothHill, kothAvoidSocket);
      rmAddObjectDefConstraint(kothHill, kothAvoidRoute);
      rmAddObjectDefConstraint(kothHill, kothAvoidFlag);
      rmPlaceObjectDefAtLoc(kothHill, 0, kothX + kothDirX * kothDist, kothZ + kothDirZ * kothDist, 1);
      if (rmGetNumberUnitsPlaced(kothHill) > 0)
        break;
      // 0, +1, -1, +2, -2, ... steps
      if (kothDist > 0.0)
        kothDist = 0.0 - kothDist;
      else
        kothDist = 0.04 - kothDist;
    }
  }

}