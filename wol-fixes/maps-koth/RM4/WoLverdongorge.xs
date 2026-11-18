// Hispaniola -- JSB
// March 2006
// Main entry point for random map script    

include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";

void main(void)
{
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.10);

	// Define Carib Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;

    if (rmAllocateSubCivs(3) == true)
    {
		subCiv0=rmGetCivID("caribs");
		rmEchoInfo("subCiv0 is caribs "+subCiv0);
		if (subCiv0 >= 0)
		rmSetSubCiv(0, "caribs");

		subCiv1=rmGetCivID("caribs");
		rmEchoInfo("subCiv1 is caribs "+subCiv1);
		if (subCiv1 >= 0)
		rmSetSubCiv(1, "caribs");

		subCiv2=rmGetCivID("caribs");
		rmEchoInfo("subCiv2 is caribs "+subCiv2);
		if (subCiv2 >= 0)
		rmSetSubCiv(2, "caribs");
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
	wotta_triggers();

	if ( cNumberNonGaiaPlayers > 7 )	//If 8 player game, use only variation #2 so map builds more quickly.
	{
		whichVariation = 2;
	}
	
	// Set size of map
	int playerTiles=23500;
	if (cNumberNonGaiaPlayers >4)   // If more than 4 players...
		playerTiles = 18000;		// ...give this many tiles per player.
	if (cNumberNonGaiaPlayers >7)	// If more than 7 players...
		playerTiles = 20000;		// ...give this many tiles per player.	
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

    // Picks default terrain and water
	rmSetMapElevationParameters(cElevTurbulence, 0.02, 3, 0.5, 8.0);
	rmSetBaseTerrainMix("verdongrass");
	rmTerrainInitialize("yukon\ground1_yuk", 5);
	rmSetLightingSet("303a_boston");
	rmSetMapType("greatPlains");
	rmSetMapType("land");
	rmSetWorldCircleConstraint(true);
	rmSetMapType("grass");
	rmSetSeaLevel(-10.0);

	// Misc variables for use later
	int numTries = -1;
        int failCount = -1;

	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("classSocket");
	rmDefineClass("canyon");
	rmDefineClass("river");
	rmDefineClass("classWaterTradeRoute");

   // -------------Define constraints----------------------------------------

    // Create an edge of map constraint.
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Player area constraint.
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 25.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("long stay away from players", classPlayer, 60.0);
	int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 20.0);
	int nearWater10 = rmCreateTerrainDistanceConstraint("near water", "Water", true, 10.0);
	int nearWaterDock = rmCreateTerrainDistanceConstraint("near water for Dock", "Water", true, 0.0);
	int avoidTC=rmCreateTypeDistanceConstraint("stay away from TC", "TownCenter", 26.0);    //Originally 20.0 -- This adjustment, as well as changing the rmSetObjectDefMaxDistance to 12.0, has corrected the problem of nomad sometimes not placing CW for each player.
	int avoidTP=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets", "SocketTradeRoute", 14.0);  // JSB 1-11-05 - Just added, to try to prevent things from stomping on TPs.
	int avoidCW=rmCreateTypeDistanceConstraint("stay away from CW", "CoveredWagon", 24.0);
	int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);


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
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "mine", 75.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "mine", 85.0);	// 85.0 seems the best for event minegold distribution.  This number tells minegolds how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random turkeys", "deer", 50.0);	//Attempting to spread them out more evenly.
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 54.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 120.0);  //Added sheep 11-28-05 JSB

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 14.0);  //This one is used in one place: for helping place FFA TC's better.

	// Constraint to avoid water.
	int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);   //I added this one so I could experiment with it.
	int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 8.0);
	int avoidWater15 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 15.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);  //Added this one too.
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 18.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25); //Was 15, but made larger so ships don't sometimes stomp each other when arriving from HC.
	rmAddClosestPointConstraint(avoidWater8);  //was originally 8
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
	int avoidWaterTradeRoute = rmCreateClassDistanceConstraint("avoid water socket", rmClassID("classWaterTradeRoute"), 10.0);
	int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("classSocket"), 10.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);

	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  (It excludes the west bay, where I do not want the flags.)
	int circleConstraint=rmCreatePieConstraint("semi-circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(50), rmDegreesToRadians(290));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

	 int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);






/////////////////////////////// PLACE RIVER ////////////////////////////////////





/////////////// VERDON RIVER


	int riverID = rmRiverCreate(-1, "Verdon River", 5, 6, 6, 9);
	rmRiverAddWaypoint(riverID, rmRandFloat(0.00, 0.1), rmRandFloat(0.8, 0.90));
	rmRiverAddWaypoint(riverID, rmRandFloat(0.15, 0.25), rmRandFloat(0.75, 0.85));
	rmRiverAddWaypoint(riverID, rmRandFloat(0.35, 0.45), rmRandFloat(0.65, 0.75));
	rmRiverAddWaypoint(riverID, rmRandFloat(0.45, 0.55), rmRandFloat(0.45, 0.55));
	rmRiverAddWaypoint(riverID, rmRandFloat(0.65, 0.75), rmRandFloat(0.35, 0.45));
	rmRiverAddWaypoint(riverID, rmRandFloat(0.75, 0.85), rmRandFloat(0.15, 0.25));
	rmRiverAddWaypoint(riverID, rmRandFloat(0.8, 0.90), rmRandFloat(0.00, 0.1));
	rmRiverSetShallowRadius(riverID, 16+cNumberNonGaiaPlayers);
		rmRiverAddShallow(riverID, rmRandFloat(0.2, 0.3));
		rmRiverAddShallow(riverID, rmRandFloat(0.7, 0.8));
	//rmRiverSetBankNoiseParams(riverID, 0.07, 2, 1.5, 10.0, 0.667, 3.0);
	rmRiverSetBankNoiseParams(riverID, 0.07, 2, 1.5, 20.0, 0.667, 2.0);



/////////////// VERDON POOL


	int lakeID=rmCreateArea("Verdon Lake");
	rmSetAreaWaterType(lakeID, "verdon gorge");
	rmSetAreaSize(lakeID, 0.07, 0.07);
	rmSetAreaCoherence(lakeID, 0.8);
	rmSetAreaLocation(lakeID, 0.5, 0.5);
	rmAddAreaInfluencePoint(lakeID, 0.55, 0.48);
	rmSetAreaBaseHeight(lakeID, 0.0);
	rmSetAreaObeyWorldCircleConstraint(lakeID, false);
	rmSetAreaMinBlobs(lakeID, 2);
	rmSetAreaMaxBlobs(lakeID, 4);
	rmSetAreaMinBlobDistance(lakeID, 5);
	rmSetAreaMaxBlobDistance(lakeID, 8);
	rmSetAreaSmoothDistance(lakeID, 0);
	rmAddAreaToClass(lakeID, rmClassID("river"));

	rmBuildArea(lakeID); 
	rmRiverBuild(riverID);

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);


/////////////// FIRST STEP, CANYON NORTH


		int smallCliffHeight=rmRandInt(0,10);
		int canyon1ID=rmCreateArea("first step");
		rmSetAreaSize(canyon1ID, 0.20, 0.20); 
		rmSetAreaWarnFailure(canyon1ID, false);
		rmSetAreaCliffType(canyon1ID, "Verdon Gorge Grass");
		rmAddAreaToClass(canyon1ID, rmClassID("canyon"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(canyon1ID, 2, 0.4, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(canyon1ID, 3, 3.0, 6.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(canyon1ID, 0.6);
		rmSetAreaHeightBlend(canyon1ID, 1);
		rmSetAreaLocation(canyon1ID, 0.8, 0.8); 
  		    rmAddAreaConstraint(canyon1ID, avoidWater8);
		rmAddAreaInfluenceSegment(canyon1ID, 0.4, 0.85, 0.85, 0.4); 
		rmAddAreaInfluenceSegment(canyon1ID, 0.6, 0.9, 0.9, 0.6); 

/////////////// SECOND STEP

		int canyon2ID=rmCreateArea("second step");
		rmSetAreaSize(canyon2ID, 0.25, 0.25); 
		rmSetAreaWarnFailure(canyon2ID, false);
		rmSetAreaCliffType(canyon2ID, "Verdon Gorge");
		rmSetAreaCliffEdge(canyon2ID, 2, 0.4, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(canyon2ID, 3, 3.0, 4.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(canyon2ID, 0.6);
		rmSetAreaHeightBlend(canyon2ID, 1);
		rmSetAreaLocation(canyon2ID, 0.8, 0.8); 
		rmAddAreaInfluenceSegment(canyon2ID, 0.4, 0.8, 0.8, 0.4);
		rmAddAreaInfluenceSegment(canyon2ID, 0.6, 0.9, 0.9, 0.6);   
  		    rmAddAreaConstraint(canyon2ID, avoidWater8);


/////////////// THIRD STEP, CANYON SOUTH


		int canyon3ID=rmCreateArea("third step");
		rmSetAreaSize(canyon3ID, 0.20, 0.20); 
		rmSetAreaWarnFailure(canyon3ID, false);
		rmSetAreaCliffType(canyon3ID, "Verdon Gorge Grass");
		rmAddAreaToClass(canyon3ID, rmClassID("canyon"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(canyon3ID, 2, 0.4, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(canyon3ID, 3, 3.0, 10.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(canyon3ID, 0.6);
		rmSetAreaHeightBlend(canyon3ID, 1);
		rmSetAreaLocation(canyon3ID, 0.2, 0.2); 
  		    rmAddAreaConstraint(canyon3ID, avoidWater8);
		rmAddAreaInfluenceSegment(canyon3ID, 0.6, 0.15, 0.15, 0.6); 
		rmAddAreaInfluenceSegment(canyon3ID, 0.4, 0.1, 0.1, 0.4); 

/////////////// FOURTH STEP

		int canyon4ID=rmCreateArea("fourth step");
		rmSetAreaSize(canyon4ID, 0.25, 0.25); 
		rmSetAreaWarnFailure(canyon4ID, false);
		rmSetAreaCliffType(canyon4ID, "Verdon Gorge");
		rmSetAreaCliffEdge(canyon4ID, 2, 0.4, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(canyon4ID, 3, 3.0, 4.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(canyon4ID, 0.6);
		rmSetAreaHeightBlend(canyon4ID, 1);
		rmSetAreaLocation(canyon4ID, 0.2, 0.2); 
		rmAddAreaInfluenceSegment(canyon4ID, 0.6, 0.2, 0.2, 0.6);  
		rmAddAreaInfluenceSegment(canyon4ID, 0.4, 0.1, 0.1, 0.4); 
  		    rmAddAreaConstraint(canyon4ID, avoidWater8);


		rmBuildArea(canyon2ID);
		rmBuildArea(canyon1ID);
		rmBuildArea(canyon4ID);
		rmBuildArea(canyon3ID);

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);





//////////////////////////////////// DEFINE PLAYERS ////////////////////////////////////

 	// Place Town Centers
		rmSetTeamSpacingModifier(0.6);

		float teamStartLoc = rmRandFloat(0.0, 1.0);
		if(cNumberTeams > 2)
		{
			rmSetPlacementSection(0.10, 0.90);
			rmSetTeamSpacingModifier(0.75);
			rmPlacePlayersCircular(0.4, 0.4, 0);
		}
		else if (cNumberPlayers > 5)
		//players are placed much more spread on if players > 5
		{
			//team 0 starts on top
			if (teamStartLoc > 0.5)
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.0, 0.30);
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.45, 0.75); 
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
			}
			else
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.45, 0.75);
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.0, 0.30); 
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
			}
		}
		else
		{
			//team 0 starts on top
			if (teamStartLoc > 0.5)
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.10, 0.20);
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.60, 0.70); 
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
			}
			else
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.60, 0.70);
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.10, 0.20); 
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
			}
		}


	//WATER HC ARRIVAL POINT

   int waterFlagID = 0;
   for(i=1; <cNumberPlayers)
   {
        waterFlagID=rmCreateObjectDef("HC water flag "+i);
        rmAddObjectDefItem(waterFlagID, "HomeCityWaterSpawnFlag", 1, 0.0);
		rmAddClosestPointConstraint(flagEdgeConstraint);
		rmAddClosestPointConstraint(flagVsFlag);
		rmAddClosestPointConstraint(flagLand);
	}  



	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.60);

//////////////////////////////////// PLAYERS STARTING OBJECTS  //////////////////////////////////// 

	int playerSilverID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerSilverID, "mine", 1, 0);
	rmAddObjectDefConstraint(playerSilverID, avoidTC);
	rmSetObjectDefMinDistance(playerSilverID, 10.0);
	rmSetObjectDefMaxDistance(playerSilverID, 25.0);
    rmAddObjectDefConstraint(playerSilverID, avoidImpassableLand);

	int playerPheasantID=rmCreateObjectDef("player pheasant");
    rmAddObjectDefItem(playerPheasantID, "pheasant", rmRandInt(5,8), 10.0);
    rmSetObjectDefMinDistance(playerPheasantID, 10);
    rmSetObjectDefMaxDistance(playerPheasantID, 16);
	rmAddObjectDefConstraint(playerPheasantID, avoidAll);
    rmAddObjectDefConstraint(playerPheasantID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerPheasantID, true);

	int playerTreeID=rmCreateObjectDef("player trees");
    rmAddObjectDefItem(playerTreeID, "TreeGreatPlains", rmRandInt(7,10), 3.0);
    rmSetObjectDefMinDistance(playerTreeID, 16);
    rmSetObjectDefMaxDistance(playerTreeID, 20);
	rmAddObjectDefConstraint(playerTreeID, avoidAll);
    rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);



	// Player placement
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);


   rmClearClosestPointConstraints();
   int TCfloat = -1;
   if (cNumberTeams == 2)
	   TCfloat = 50;
   else 
	   TCfloat = 85;
    

	int TCID = rmCreateObjectDef("player TC");
	if (rmGetNomadStart())
		{
			rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
		}
	else
		{
		rmAddObjectDefItem(TCID, "TownCenter", 1, 0.0);

//		int playerMarketID = rmCreateObjectDef("player market");
//		rmAddObjectDefItem(playerMarketID, "market", 1, 0);
//		rmAddObjectDefConstraint(playerMarketID, avoidTradeRoute);
//		rmSetObjectDefMinDistance(playerMarketID, 10.0);
//		rmSetObjectDefMaxDistance(playerMarketID, 18.0);
//		rmAddObjectDefConstraint(playerMarketID, playerEdgeConstraint);
//		rmAddObjectDefConstraint(playerMarketID, mediumShortAvoidImpassableLand);
		}
	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, TCfloat);

	rmAddObjectDefConstraint(TCID, avoidTC);
	rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, avoidImpassableLand);
	//rmPlaceObjectDefPerPlayer(TCID, true);


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.70);


	for(i=1; <cNumberPlayers)
   {
	rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

//	if (rmGetNomadStart() == false)
//	{
//		rmPlaceObjectDefAtLoc(playerMarketID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
//	}
	rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	rmPlaceObjectDefAtLoc(playerPheasantID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

	vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
	rmPlaceObjectDefAtLoc(waterFlagID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
	
   }
   rmClearClosestPointConstraints();


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);



//////////////////////////////////// FORESTS ////////////////////////////////////


   // Define and place Forests
   int forestTreeID = 0;
   numTries=8*cNumberNonGaiaPlayers;
   failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest"+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest, "verdon forest");
         rmSetAreaForestDensity(forest, 0.7);
         rmSetAreaForestClumpiness(forest, 0.6);
         rmSetAreaForestUnderbrush(forest, 0.0);
         rmSetAreaMinBlobs(forest, 6);
         rmSetAreaMaxBlobs(forest, 15);
         rmSetAreaMinBlobDistance(forest, 16.0);
         rmSetAreaMaxBlobDistance(forest, 25.0);
         rmSetAreaCoherence(forest, 0.4);
         rmSetAreaSmoothDistance(forest, 10);
	      rmAddAreaToClass(forest, rmClassID("classForest"));
         rmAddAreaConstraint(forest, forestConstraint);
         rmAddAreaConstraint(forest, forestObjConstraint);
        rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
	 rmAddAreaConstraint(forest, avoidTC);

         if(rmBuildArea(forest)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount++;
            if(failCount==6)
               break;
         }
         else
            failCount=0; 
      } 



	// Scattered BERRRIES		
	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "berrybush", rmRandInt(5,8), 6.0);  // (3,5) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(berriesID, avoidTC);
	rmAddObjectDefConstraint(berriesID, avoidCW);
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
        rmPlaceObjectDefAtLoc(berriesID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);

	// Scattered MINES
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "mine", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(goldID, avoidTC);
	rmAddObjectDefConstraint(goldID, avoidCW);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidCoin);
    rmAddObjectDefConstraint(goldID, avoidImpassableLand);
        rmPlaceObjectDefAtLoc(goldID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);

	// Just a FEW scattered DEERs
	int turkeyID=rmCreateObjectDef("random turkeys");
	rmAddObjectDefItem(turkeyID, "deer", rmRandInt(4,6), 5.0);  // (2,4) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(turkeyID, 0.0);
	rmSetObjectDefMaxDistance(turkeyID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(turkeyID, avoidTC);
	rmAddObjectDefConstraint(turkeyID, avoidCW);
	rmAddObjectDefConstraint(turkeyID, avoidRandomTurkeys);
	rmAddObjectDefConstraint(turkeyID, avoidAll);
	rmAddObjectDefConstraint(turkeyID, avoidRandomBerries);
	rmAddObjectDefConstraint(turkeyID, avoidImpassableLand);
        rmPlaceObjectDefAtLoc(turkeyID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);


//////////////////////////////////// EMBELLISHMENT ////////////////////////////////////


	// RANDOM TREES

	int randomTreeID=rmCreateObjectDef("random tree");
	rmAddObjectDefItem(randomTreeID, "treeGreatPlains", 1, 0.0);
	rmSetObjectDefMinDistance(randomTreeID, 0.0);
	rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
	rmAddObjectDefConstraint(randomTreeID, avoidTC);
	rmAddObjectDefConstraint(randomTreeID, avoidAll); 
        rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 8*cNumberNonGaiaPlayers);


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",1.00);



  // King of the Hill (added 2026-11 for WoL): the middle is the gorge's lake; first open land on the line that splits the teams (the gorge's banks)
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




