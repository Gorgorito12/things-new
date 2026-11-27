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
		subCiv0=rmGetCivID("AURsalt");
		rmEchoInfo("subCiv0 is AURsalt "+subCiv0);
		if (subCiv0 >= 0)
		rmSetSubCiv(0, "AURsalt");

		subCiv1=rmGetCivID("AURsalt");
		rmEchoInfo("subCiv1 is AURsalt "+subCiv1);
		if (subCiv1 >= 0)
		rmSetSubCiv(1, "AURsalt");

		subCiv2=rmGetCivID("AURsalt");
		rmEchoInfo("subCiv2 is AURsalt "+subCiv2);
		if (subCiv2 >= 0)
		rmSetSubCiv(2, "AURsalt");
	}

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	// 1 - Four AURsalt, next to the big mountain and at the ends of the 2 long peninsulas. 
	// 2 - Four AURsalt, at the ends of the 2 long peninsulas, and 2 on SE end of island.
    // 3 - Six AURsalt, next to the mountain, 2 on the long peninsula, and 2 on SE end of island. 

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
	rmSetBaseTerrainMix("california_desert0");
	rmTerrainInitialize("yukon\ground1_yuk", 5);
	rmSetLightingSet("pampas");
	rmSetMapType("AFRICANsavannah");
	rmSetMapType("land");
	rmSetWorldCircleConstraint(true);
	rmSetMapType("grass");
	rmSetSeaLevel(-10.0);
	
	// Misc variables for use later
	int numTries = -1;
	int numTries2 = -1;
	int numTries3 = -1;
	
	// Misc variables for use later

  int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
  bool weird = false;

  // FFA and imbalanced teams
  if ( cNumberTeams > 2 || ((teamZeroCount - teamOneCount) > 2) || ((teamOneCount - teamZeroCount) > 2) )
    weird = true;
  
  rmEchoInfo("weird = "+weird);

	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
	rmDefineClass("classCenterForest");
	rmDefineClass("classForest");
		rmDefineClass("classLake");
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("classSocket");
	rmDefineClass("canyon");
	rmDefineClass("classWaterTradeRoute");
	rmDefineClass("Green");
	rmDefineClass("Olive");
		rmDefineClass("classCliff");

  string herdableType = "ypWaterBuffalo";
  string huntable1 = "Camel";
  string huntable2 = "Boar";
  string huntable3 = "Camel";
  string fish1 = "FishCod";
  string fish2 = "ypFishTuna";
  string whale1 = "HumpbackWhale";
  string startTreeType = "TreeSonora";

   // -------------Define constraints----------------------------------------

    // Create an edge of map constraint.
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int resCenterConstraint=rmCreatePieConstraint("resources center of map", 0.5, 0.5, rmXFractionToMeters(0.3), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

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
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 10.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int avoidCoin=-1;

	int Insidedallol=rmCreateBoxConstraint("long avoid edge of map cave", rmXTilesToFraction(100), rmZTilesToFraction(100), 1.0-rmXTilesToFraction(100), 1.0-rmZTilesToFraction(100), 0.01);


	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minegold", 75.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minegold", 85.0);	// 85.0 seems the best for event minegold distribution.  This number tells minegolds how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "GrapeBush", 50.0);	//Attempting to spread them out more evenly.
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
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 18.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25); //Was 15, but made larger so ships don't sometimes stomp each other when arriving from HC.
	rmAddClosestPointConstraint(avoidWater8);  //was originally 8
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("short trade route", 3.0);
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 10.0);
	int avoidWaterTradeRoute = rmCreateClassDistanceConstraint("avoid WTR", rmClassID("classWaterTradeRoute"), 10.0);
	int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("classSocket"), 10.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);

	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  (It excludes the west bay, where I do not want the flags.)
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

	// int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);

  int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 60.0);
	int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 60.0);
	int avoidTradeRouteSockets=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 8.0);
	int avoidTradeRouteSocketsShort=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 8.0);
	int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other short", rmClassID("importantItem"), 8.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("short stay away from players", classPlayer, 5.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);

	  int playerConstraintNugget=rmCreateClassDistanceConstraint("stay away from players far", classPlayer, 55.0);
  int avoidNuggetsShort=rmCreateTypeDistanceConstraint("vs nugget short", "AbstractNugget", 10.0);
  int avoidNuggets=rmCreateTypeDistanceConstraint("nugget vs. nugget", "AbstractNugget", 40.0);
	int avoidNuggetFar=rmCreateTypeDistanceConstraint("nugget vs. nugget far", "AbstractNugget", 70.0);
	
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);




	int invisIslandID=rmCreateArea("invisible island");
	rmSetAreaSize(invisIslandID, 0.09, 0.09);
	rmSetAreaCoherence(invisIslandID, 0.8);
  rmSetAreaLocation(invisIslandID, .5, .5);
	rmSetAreaWarnFailure(invisIslandID, false);
	rmBuildArea(invisIslandID);

/////////////////////////////// EDGES ////////////////////////////////////
	
		// DEFINE AREAS
	// DAL TEMP: Big invisible continent, size 0.95, 0.95
   // Build up big continent called "big continent"
   int bigContinentID=rmCreateArea("big continent");
   rmSetAreaSize(bigContinentID, 0.9, 0.9); // 3 35
   rmSetAreaWarnFailure(bigContinentID, false);
   // rmSetAreaSmoothDistance(bigContinentID, 10);
	rmSetAreaMix(bigContinentID, "rockies_snow");
   rmSetAreaCoherence(bigContinentID, 0.9);
   rmSetAreaLocation(bigContinentID, 0.5, 0.5);
	rmSetAreaCliffType(bigContinentID, "Dallol");
	rmSetAreaCliffEdge(bigContinentID, 1, 1.0, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(bigContinentID, -4, 1.0, 0.3);
	rmSetAreaCliffPainting(bigContinentID, false, false, true);
	rmAddAreaToClass(bigContinentID, rmClassID("classCliff"));
	rmBuildArea(bigContinentID);

   int bigContinent2ID=rmCreateArea("big continent 2");
   rmSetAreaSize(bigContinent2ID, 0.64, 0.64); // 3 35
   rmSetAreaWarnFailure(bigContinent2ID, false);
   // rmSetAreaSmoothDistance(bigContinent2ID, 10);
	rmSetAreaMix(bigContinent2ID, "rockies_snow");
   rmSetAreaCoherence(bigContinent2ID, 0.9);
   rmSetAreaLocation(bigContinent2ID, 0.5, 0.5);
	rmSetAreaCliffType(bigContinent2ID, "Dallol");
	rmSetAreaCliffEdge(bigContinent2ID, 1, 1.0, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(bigContinent2ID, -8, 1.0, 0.3);
	rmSetAreaCliffPainting(bigContinent2ID, false, false, true);
	rmAddAreaToClass(bigContinent2ID, rmClassID("classCliff"));
	rmBuildArea(bigContinent2ID);
	
	
	

/////////////////////////////// PAINT TERRAIN ////////////////////////////////////


   // Build an invisible "Green" area.
   int DallolCrateID = rmCreateArea("Crater");
  	rmSetAreaLocation(DallolCrateID, 0.5, 0.5); 
   rmSetAreaWarnFailure(DallolCrateID, false);
   rmSetAreaSize(DallolCrateID, 0.15, 0.15);
   	rmSetAreaElevationVariation(DallolCrateID, 4.0);
	rmSetAreaBaseHeight(DallolCrateID, -9.0);
	rmSetAreaElevationMinFrequency(DallolCrateID, 0.05);
	rmSetAreaElevationOctaves(DallolCrateID, 3);
	rmSetAreaElevationPersistence(DallolCrateID, 0.3);      
	rmSetAreaElevationNoiseBias(DallolCrateID, 0.5);
   rmSetAreaCoherence(DallolCrateID, 0.8);
   //rmAddAreaInfluenceSegment(DallolCrateID, 0.0, 0.1, 0.75, 0.9);
   rmSetAreaObeyWorldCircleConstraint(DallolCrateID, false);
	rmSetAreaMix(DallolCrateID, "dallol");
	rmAddAreaToClass(DallolCrateID, rmClassID("Green"));
   rmBuildArea(DallolCrateID);

/////////////////////////////// PAINT TERRAIN ////////////////////////////////////

	// Scattered LAKES
	
   int lakesID = 0;
   numTries3=2*cNumberNonGaiaPlayers;
   int failCount3=0;

   for (i=0; <numTries3)
      {   
         int lakes=rmCreateArea("lake "+i);
         rmSetAreaWarnFailure(lakes, false);
         rmSetAreaSize(lakes, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
		rmSetAreaWaterType(lakes, "dallol");
         rmSetAreaMinBlobs(lakes, 3);
         rmSetAreaMaxBlobs(lakes, 7);
         rmSetAreaMinBlobDistance(lakes, 16.0);
         rmSetAreaMaxBlobDistance(lakes, 40.0);
         rmSetAreaCoherence(lakes, 0.4);
         rmSetAreaSmoothDistance(lakes, 10);
         rmAddAreaToClass(lakes, rmClassID("classLake")); 
         rmAddAreaConstraint(lakes, avoidAll);
         rmAddAreaConstraint(lakes, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(lakes, avoidTC);
		 rmAddAreaConstraint(lakes, avoidCW);
		 	rmSetAreaBaseHeight(lakes, -10.0);
		rmAddAreaConstraint(lakes, Insidedallol); 
         rmAddAreaConstraint(lakes, shortAvoidTradeRoute); 
         rmAddAreaConstraint(lakes, avoidTradeRouteSocketsShort); 
         if(rmBuildArea(lakes)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount3++;
            if(failCount3==5)
               break;
         }
         else
            failCount3=0; 
      } 
	  
	  

/////////////////////////////// DEFINE STARTING OBJECTS ////////////////////////////////////





  int food1ID=rmCreateObjectDef("huntable1");
	rmAddObjectDefItem(food1ID, huntable1, rmRandInt(5,6), 6.0);
	rmSetObjectDefCreateHerd(food1ID, true);
	rmSetObjectDefMinDistance(food1ID, rmXFractionToMeters(0.28));
	rmSetObjectDefMaxDistance(food1ID, rmXFractionToMeters(0.35));
	rmAddObjectDefConstraint(food1ID, avoidResource);
	rmAddObjectDefConstraint(food1ID, playerConstraint);
	rmAddObjectDefConstraint(food1ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food1ID, resCenterConstraint);
	rmAddObjectDefConstraint(food1ID, avoidHuntable1);
	rmAddObjectDefConstraint(food1ID, avoidHuntable2);
	rmAddObjectDefConstraint(food1ID, avoidTradeRoute);
  rmAddObjectDefConstraint(food1ID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(food1ID, avoidTradeRouteSocketsShort);
  
  int food2ID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(food2ID, huntable2, rmRandInt(3,4), 6.0);
	rmSetObjectDefCreateHerd(food2ID, true);
	rmSetObjectDefMinDistance(food2ID, rmXFractionToMeters(0.19));
	rmSetObjectDefMaxDistance(food2ID, rmXFractionToMeters(0.25));
	rmAddObjectDefConstraint(food2ID, avoidResource);
	rmAddObjectDefConstraint(food2ID, playerConstraint);
	rmAddObjectDefConstraint(food2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food2ID, resCenterConstraint);
	rmAddObjectDefConstraint(food2ID, avoidHuntable1);
	rmAddObjectDefConstraint(food2ID, avoidHuntable2);
	rmAddObjectDefConstraint(food2ID, avoidTradeRoute);
	rmAddObjectDefConstraint(food2ID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(food2ID, avoidTradeRouteSocketsShort);
  
  int startFoodID=rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(startFoodID, huntable3, 6, 4.0);
	rmSetObjectDefMinDistance(startFoodID, 12.0);
	rmSetObjectDefMaxDistance(startFoodID, 18.0);
	rmSetObjectDefCreateHerd(startFoodID, false);
	rmAddObjectDefConstraint(startFoodID, avoidAll);
	rmAddObjectDefConstraint(startFoodID, avoidStartResource);
	rmAddObjectDefConstraint(startFoodID, avoidHuntable1);    
	rmAddObjectDefConstraint(startFoodID, avoidHuntable2);    
  rmAddObjectDefConstraint(startFoodID, avoidTradeRoute);
  
  int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, rmRandInt(3,4), 6.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 16);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 22);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartResource);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRouteSocketsShort);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRoute);

	int StartBerriesID=rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(StartBerriesID, "DatePalm", rmRandInt(2,3), 5.0);
	rmSetObjectDefMinDistance(StartBerriesID, 10);
	rmSetObjectDefMaxDistance(StartBerriesID, 15);
	rmAddObjectDefConstraint(StartBerriesID, avoidAll);
	rmAddObjectDefConstraint(StartBerriesID, avoidStartResource);
	rmAddObjectDefConstraint(StartBerriesID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(StartBerriesID, shortPlayerConstraint);
  rmAddObjectDefConstraint(StartBerriesID, avoidTradeRoute);

  int startSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(startSilverID, "ypGoat", 1, 0);
	rmSetObjectDefMinDistance(startSilverID, 18.0);
	rmSetObjectDefMaxDistance(startSilverID, 23.0);
	rmAddObjectDefConstraint(startSilverID, avoidAll);
	rmAddObjectDefConstraint(startSilverID, avoidImpassableLand);
  rmAddObjectDefConstraint(startSilverID, avoidTradeRoute);


  
  int playerNuggetID=rmCreateObjectDef("player nugget");
  rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
  rmSetObjectDefMinDistance(playerNuggetID, 15.0);
  rmSetObjectDefMaxDistance(playerNuggetID, 20.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);
  rmAddObjectDefConstraint(playerNuggetID, avoidTradeRoute);

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 5.0);
  rmSetObjectDefMaxDistance(startingUnits, 10.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);
  rmAddObjectDefConstraint(startingUnits, avoidTradeRoute);


/////////////////////////////// DEFINE PLAYERS ////////////////////////////////////


  // Players
    
  float teamSide = rmRandFloat(0, 1);
  // teamSide = 0;
  
  if (weird == false) {
    
    if(teamSide > .5) {
      if(cNumberNonGaiaPlayers > 7) { 
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.5, .8);
        rmPlacePlayersCircular(.30, .30, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.0, .3);
        rmPlacePlayersCircular(.30, .30, 0);
      }
      
      else if(cNumberNonGaiaPlayers > 5) {
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.6, .9);
        rmPlacePlayersCircular(.30, .30, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.1, .4);
        rmPlacePlayersCircular(.30, .30, 0);
      }
      
      else if(cNumberNonGaiaPlayers > 2) {
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.5, .8);
        rmPlacePlayersCircular(.30, .30, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.0, .3);
        rmPlacePlayersCircular(.30, .30, 0);
        
      }
      
      else {
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.74, .75);
        rmPlacePlayersCircular(.30, .30, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.24, .30);
        rmPlacePlayersCircular(.30, .30, 0);
      }
    }
    
    else {
      if(cNumberNonGaiaPlayers > 7) { 
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.5, .8);
        rmPlacePlayersCircular(.30, .30, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.0, .3);
        rmPlacePlayersCircular(.30, .30, 0);
      }
      
      else if(cNumberNonGaiaPlayers > 5) {
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.6, .9);
        rmPlacePlayersCircular(.30, .30, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.1, .4);
        rmPlacePlayersCircular(.30, .30, 0);
      }
      
      else if(cNumberNonGaiaPlayers > 2) {
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.5, .8);
        rmPlacePlayersCircular(.30, .30, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.0, .3);
        rmPlacePlayersCircular(.30, .30, 0);
        
      }
      
      else {
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.74, .75);
        rmPlacePlayersCircular(.30, .30, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.24, .30);
        rmPlacePlayersCircular(.30, .30, 0);
      }
    }
  }
  
  // ffa
  else {
    rmSetTeamSpacingModifier(0.5);
    rmPlacePlayersCircular(.275, .275, 0.05);
  }
  
  // Set up player areas.
  float playerFraction=rmAreaTilesToFraction(100);
  for(i=1; <cNumberPlayers) {
    int id=rmCreateArea("Player"+i);
    rmSetPlayerArea(i, id);
    rmSetAreaSize(id, playerFraction, playerFraction);
    rmAddAreaToClass(id, classPlayer);
    rmAddAreaConstraint(id, avoidTradeRouteSockets); 
    rmAddAreaConstraint(id, shortAvoidTradeRoute); 
    rmAddAreaConstraint(id, shortAvoidImportantItem); 
    rmAddAreaConstraint(id, playerConstraint); 
    rmAddAreaConstraint(id, playerEdgeConstraint); 
    rmSetAreaCoherence(id, 1.0);
    rmSetAreaLocPlayer(id, i);
    rmSetAreaWarnFailure(id, true);
  }

	// Build the areas.
  rmBuildAllAreas();


/////////////////////////////// PLACE PLAYERS ////////////////////////////////////

  // starting resources

  int startingTCID= rmCreateObjectDef("startingTC");
	if (rmGetNomadStart()) {
			rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 0.0);
  }
		
  else {
    rmAddObjectDefItem(startingTCID, "townCenter", 1, 0.0);
  }

  rmSetObjectDefMinDistance(startingTCID, 5);
	rmSetObjectDefMaxDistance(startingTCID, 10);
	rmAddObjectDefConstraint(startingTCID, avoidImpassableLand);
  rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);
	rmAddObjectDefToClass(startingTCID, rmClassID("player"));

   // Text
   rmSetStatusText("",0.35);
  
  rmClearClosestPointConstraints();

	for(i=1; < cNumberPlayers) {
		int placedTC = rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLocation=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(startSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));

    // Food
		rmPlaceObjectDefAtLoc(StartBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    rmPlaceObjectDefAtLoc(startFoodID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    rmPlaceObjectDefAtLoc(food1ID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    rmPlaceObjectDefAtLoc(food2ID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    
    // Place a nugget for the player
    rmSetNuggetDifficulty(1, 1);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    

  }

 
	/////////////////////////////// PLACE TRADE ROUTES ////////////////////////////////////


   int socketID=rmCreateObjectDef("North Route");
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 0.0);
	rmSetObjectDefMaxDistance(socketID, 6.0);
	rmAddObjectDefConstraint(socketID, shortAvoidTradeRoute);

	int tradeRouteID = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.8);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.6);
	rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.5);

	bool placedTradeRouteB = rmBuildTradeRoute(tradeRouteID, "ShortCamelTrain");
	if(placedTradeRouteB == false)
		rmEchoError("Failed to place trade route 2");
		
	int tradeRoute2ID = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(socketID, tradeRoute2ID);
	rmAddTradeRouteWaypoint(tradeRoute2ID, 0.5, 0.0);
	rmAddTradeRouteWaypoint(tradeRoute2ID, 0.4, 0.2);
	rmAddTradeRouteWaypoint(tradeRoute2ID, 0.2, 0.4);
	rmAddTradeRouteWaypoint(tradeRoute2ID, 0.0, 0.5);

	bool placedTradeRouteA = rmBuildTradeRoute(tradeRoute2ID, "ShortCamelTrain");
	if(placedTradeRouteA == false)
		rmEchoError("Failed to place trade route 3");
	


		rmPlaceObjectDefAtLoc(socketID, 0, 0.31, 0.31);

	

		///////////////////////////////////////////////////////////////
		

// Invisible Curved Area Left of Crater

	int leftDesertID=rmCreateArea("Left Desert");
	rmSetAreaSize(leftDesertID, 0.17, 0.17);
	rmSetAreaCoherence(leftDesertID, 0.8);
  	rmSetAreaLocation(leftDesertID, .2, .8);
	rmAddAreaInfluenceSegment(leftDesertID, 0.8, 0.8, 0.5, 0.9);
	rmAddAreaInfluenceSegment(leftDesertID, 0.5, 0.9, 0.2, 0.8);
	rmAddAreaInfluenceSegment(leftDesertID, 0.2, 0.8, 0.1, 0.5);
	rmAddAreaInfluenceSegment(leftDesertID, 0.1, 0.5, 0.2, 0.2);
	rmSetAreaWarnFailure(leftDesertID, false);
	rmBuildArea(leftDesertID);

// Invisible Curved Area Right of Crater

	int rightDesertID=rmCreateArea("Right Desert");
	rmSetAreaSize(rightDesertID, 0.17, 0.17);
	rmSetAreaCoherence(rightDesertID, 0.8);
  	rmSetAreaLocation(rightDesertID, .8, .2);
	rmAddAreaInfluenceSegment(rightDesertID, 0.8, 0.8, 0.9, 0.5);
	rmAddAreaInfluenceSegment(rightDesertID, 0.9, 0.5, 0.8, 0.2);
	rmAddAreaInfluenceSegment(rightDesertID, 0.8, 0.2, 0.5, 0.1);
	rmAddAreaInfluenceSegment(rightDesertID, 0.5, 0.1, 0.2, 0.2);
	rmSetAreaWarnFailure(rightDesertID, false);
	rmBuildArea(rightDesertID);


		
	int DallolPropsID=rmCreateObjectDef("pillars of salt");
	rmAddObjectDefItem(DallolPropsID, "PropsDallol", 1, 0);
	rmSetObjectDefMinDistance(DallolPropsID, 10);
	rmSetObjectDefMaxDistance(DallolPropsID, 15);
	rmAddObjectDefConstraint(DallolPropsID, avoidAll);
	rmAddObjectDefConstraint(DallolPropsID, avoidStartResource);
	rmAddObjectDefConstraint(DallolPropsID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(DallolPropsID, shortPlayerConstraint);
  	rmAddObjectDefConstraint(DallolPropsID, avoidTradeRoute);
 	rmPlaceObjectDefInArea(DallolPropsID, 0, DallolCrateID, cNumberNonGaiaPlayers*12);
	
		int GeysersID=rmCreateObjectDef("geysers");
	rmAddObjectDefItem(GeysersID, "BigPropGeyser", 1, 0);
	rmSetObjectDefMinDistance(GeysersID, 10);
	rmSetObjectDefMaxDistance(GeysersID, 15);
	rmAddObjectDefConstraint(GeysersID, avoidAll);
	rmAddObjectDefConstraint(GeysersID, avoidStartResource);
	rmAddObjectDefConstraint(GeysersID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(GeysersID, shortPlayerConstraint);
  	rmAddObjectDefConstraint(GeysersID, avoidTradeRoute);
 	rmPlaceObjectDefInArea(GeysersID, 0, DallolCrateID, cNumberNonGaiaPlayers*4);
	
		int SaltMinesID=rmCreateObjectDef("SaltMines");
	rmAddObjectDefItem(SaltMinesID, "MineSalt", 1, 0);
	rmSetObjectDefMinDistance(SaltMinesID, 10);
	rmSetObjectDefMaxDistance(SaltMinesID, 15);
	rmAddObjectDefConstraint(SaltMinesID, avoidAll);
	rmAddObjectDefConstraint(SaltMinesID, avoidStartResource);
	rmAddObjectDefConstraint(SaltMinesID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(SaltMinesID, shortPlayerConstraint);
  	rmAddObjectDefConstraint(SaltMinesID, avoidTradeRoute);
 	rmPlaceObjectDefInArea(SaltMinesID, 0, DallolCrateID, cNumberNonGaiaPlayers*5);
	
	int CamelsID=rmCreateObjectDef("Camels");
	rmAddObjectDefItem(CamelsID, "Camel", rmRandInt(7,9), 10);
	rmSetObjectDefMinDistance(CamelsID, 0);
	rmSetObjectDefMaxDistance(CamelsID, 15);
	rmAddObjectDefConstraint(CamelsID, avoidAll);
	rmAddObjectDefConstraint(CamelsID, avoidStartResource);
	rmAddObjectDefConstraint(CamelsID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(CamelsID, shortPlayerConstraint);
  	rmAddObjectDefConstraint(CamelsID, avoidTradeRoute);
	rmPlaceObjectDefAtLoc(CamelsID, 0, 0.7, 0.3);

	int Camels2ID=rmCreateObjectDef("More Camels");
	rmAddObjectDefItem(Camels2ID, "Camel", rmRandInt(7,9), 10);
	rmSetObjectDefMinDistance(Camels2ID, 10);
	rmSetObjectDefMaxDistance(Camels2ID, 15);
	rmAddObjectDefConstraint(Camels2ID, avoidAll);
	rmAddObjectDefConstraint(Camels2ID, avoidStartResource);
	rmAddObjectDefConstraint(Camels2ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(Camels2ID, shortPlayerConstraint);
  	rmAddObjectDefConstraint(Camels2ID, avoidTradeRoute);
	rmPlaceObjectDefAtLoc(Camels2ID, 0, 0.3, 0.7);
	
	int VulturesLID=rmCreateObjectDef("Vultures");
	rmAddObjectDefItem(VulturesLID, "BuzzardFlock", 1, 0);
	rmSetObjectDefMinDistance(VulturesLID, 10);
	rmSetObjectDefMaxDistance(VulturesLID, 15);
	rmAddObjectDefConstraint(VulturesLID, avoidAll);
	rmAddObjectDefConstraint(VulturesLID, avoidStartResource);
	rmAddObjectDefConstraint(VulturesLID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(VulturesLID, shortPlayerConstraint);
  	rmAddObjectDefConstraint(VulturesLID, avoidTradeRoute);
 	rmPlaceObjectDefInArea(VulturesLID, 0, leftDesertID, 1);
	
	int VulturesRID=rmCreateObjectDef("More Vultures");
	rmAddObjectDefItem(VulturesRID, "PropVulturePerching", 1, 0);
	rmSetObjectDefMinDistance(VulturesRID, 10);
	rmSetObjectDefMaxDistance(VulturesRID, 15);
	rmAddObjectDefConstraint(VulturesRID, avoidAll);
	rmAddObjectDefConstraint(VulturesRID, avoidStartResource);
	rmAddObjectDefConstraint(VulturesRID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(VulturesRID, shortPlayerConstraint);
  	rmAddObjectDefConstraint(VulturesRID, avoidTradeRoute);
 	rmPlaceObjectDefInArea(VulturesRID, 0, rightDesertID, 1);

	int HyenaID=rmCreateObjectDef("Hyenas");
	rmAddObjectDefItem(HyenaID, "WildHyena", rmRandInt(3,4), 6);
	rmSetObjectDefMinDistance(HyenaID, 10);
	rmSetObjectDefMaxDistance(HyenaID, 15);
	rmAddObjectDefConstraint(HyenaID, avoidAll);
	rmAddObjectDefConstraint(HyenaID, avoidStartResource);
	rmAddObjectDefConstraint(HyenaID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(HyenaID, shortPlayerConstraint);
  	rmAddObjectDefConstraint(HyenaID, avoidTradeRoute);
 	rmPlaceObjectDefInArea(HyenaID, 0, rightDesertID, 1);
 	rmPlaceObjectDefInArea(HyenaID, 0, leftDesertID, 1);
	
		int NthTradeRouteID=rmCreateObjectDef("NthTradeRoute");
	rmAddObjectDefItem(NthTradeRouteID, "SocketTradeRoute", 1, 0);
	rmSetObjectDefMinDistance(NthTradeRouteID, 10);
	rmSetObjectDefMaxDistance(NthTradeRouteID, 15);
	rmAddObjectDefConstraint(NthTradeRouteID, avoidAll);
	rmAddObjectDefConstraint(NthTradeRouteID, avoidStartResource);
	rmAddObjectDefConstraint(NthTradeRouteID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(NthTradeRouteID, shortPlayerConstraint);
  	rmPlaceObjectDefAtLoc(NthTradeRouteID, 0, 0.693, .693, 1);
	
	    int saltrade = rmCreateGrouping("SaltTrade", "AURsalt timbuktu "+rmRandInt(1,3));
    rmSetGroupingMinDistance(saltrade, 0);
    rmSetGroupingMaxDistance(saltrade, rmXFractionToMeters(0.05));
    rmAddGroupingConstraint(saltrade, playerConstraint);
    rmAddGroupingToClass(saltrade, rmClassID("importantItem"));
    rmAddGroupingToClass(saltrade, rmClassID("natives"));
	rmPlaceGroupingAtLoc(saltrade, 0, 0.5, 0.65);
	rmPlaceGroupingAtLoc(saltrade, 0, 0.5, 0.35);
	
/////////////////////////////NUGGETS////////////////////////////////////////

  int nuggets1ID= rmCreateObjectDef("nugget easy"); 
  rmAddObjectDefItem(nuggets1ID, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(1, 1);
	rmSetObjectDefMinDistance(nuggets1ID, 10);
	rmSetObjectDefMaxDistance(nuggets1ID, 15);
	rmAddObjectDefConstraint(nuggets1ID, avoidAll);
  	rmAddObjectDefConstraint(nuggets1ID, avoidNuggetFar);
	rmAddObjectDefConstraint(nuggets1ID, avoidStartResource);
	rmAddObjectDefConstraint(nuggets1ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggets1ID, shortPlayerConstraint);
  	rmAddObjectDefConstraint(nuggets1ID, avoidTradeRoute);
 	rmPlaceObjectDefInArea(nuggets1ID, 0, rightDesertID, cNumberNonGaiaPlayers);
 	rmPlaceObjectDefInArea(nuggets1ID, 0, leftDesertID, cNumberNonGaiaPlayers);
	
	  int nuggets2ID= rmCreateObjectDef("nugget medium"); 
  rmAddObjectDefItem(nuggets2ID, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(2, 2);
	rmSetObjectDefMinDistance(nuggets2ID, 10);
	rmSetObjectDefMaxDistance(nuggets2ID, 15);
	rmAddObjectDefConstraint(nuggets2ID, avoidAll);
  	rmAddObjectDefConstraint(nuggets2ID, avoidNuggetFar);
	rmAddObjectDefConstraint(nuggets2ID, avoidStartResource);
	rmAddObjectDefConstraint(nuggets2ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggets2ID, shortPlayerConstraint);
  	rmAddObjectDefConstraint(nuggets2ID, avoidTradeRoute);
 	rmPlaceObjectDefInArea(nuggets2ID, 0, rightDesertID, cNumberNonGaiaPlayers);
 	rmPlaceObjectDefInArea(nuggets2ID, 0, leftDesertID, cNumberNonGaiaPlayers);
	
	  int nuggets3ID= rmCreateObjectDef("nugget hard"); 
  rmAddObjectDefItem(nuggets3ID, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(3, 3);
	rmSetObjectDefMinDistance(nuggets3ID, 10);
	rmSetObjectDefMaxDistance(nuggets3ID, 15);
	rmAddObjectDefConstraint(nuggets3ID, avoidAll);
  	rmAddObjectDefConstraint(nuggets3ID, avoidNuggetFar);
	rmAddObjectDefConstraint(nuggets3ID, avoidStartResource);
	rmAddObjectDefConstraint(nuggets3ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggets3ID, shortPlayerConstraint);
  	rmAddObjectDefConstraint(nuggets3ID, avoidTradeRoute);
 	rmPlaceObjectDefInArea(nuggets3ID, 0, rightDesertID, cNumberNonGaiaPlayers/2);
 	rmPlaceObjectDefInArea(nuggets3ID, 0, leftDesertID, cNumberNonGaiaPlayers/2);




/////////////////////////////// FORESTS ////////////////////////////////////


	int forestavoidID=rmCreateArea("invisible forest avoid");
	rmSetAreaSize(forestavoidID, 0.30, 0.30);
	rmSetAreaCoherence(forestavoidID, 0.99);
         rmAddAreaToClass(forestavoidID, rmClassID("classCenterForest")); 
  rmSetAreaLocation(forestavoidID, .5, .5);
	rmSetAreaWarnFailure(forestavoidID, false);
	rmBuildArea(forestavoidID);

	int avoidforestcenter = rmCreateClassDistanceConstraint("forest vs. forest1", rmClassID("classCenterForest"), 0.1);


	// Scattered FORESTS
   int forestTreeID = 0;
   numTries2=15*cNumberNonGaiaPlayers;
   int failCount2=0;

   for (i=0; <numTries2)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(300));
         rmSetAreaForestType(forest, "California Desert Forest");
         rmSetAreaForestDensity(forest, 0.25);
         rmSetAreaForestClumpiness(forest, 0.2);
         rmSetAreaForestUnderbrush(forest, 0.0);
         rmSetAreaMinBlobs(forest, 3);
         rmSetAreaMaxBlobs(forest, 7);
         rmSetAreaMinBlobDistance(forest, 16.0);
         rmSetAreaMaxBlobDistance(forest, 40.0);
         rmSetAreaCoherence(forest, 0.4);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
        rmAddAreaConstraint(forest, forestConstraint);
         rmAddAreaConstraint(forest, avoidAll);
         rmAddAreaConstraint(forest, avoidforestcenter);
         rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(forest, avoidTC);
		 rmAddAreaConstraint(forest, avoidCW);
         rmAddAreaConstraint(forest, shortAvoidTradeRoute); 
         rmAddAreaConstraint(forest, avoidTradeRouteSocketsShort); 
         if(rmBuildArea(forest)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount2++;
            if(failCount2==5)
               break;
         }
         else
            failCount2=0; 
      } 

/*

/////////////////////////////// HUNTABLES ////////////////////////////////////

  rmPlaceObjectDefAtLoc(food1ID, 0, 0.5, 0.5, 3.0*cNumberNonGaiaPlayers);
  rmPlaceObjectDefAtLoc(food2ID, 0, 0.5, 0.5, 2.0*cNumberNonGaiaPlayers);

	int saltID=rmCreateObjectDef("salt");
	rmAddObjectDefItem(saltID, "MineSalt", 1, 0);
	rmSetObjectDefMinDistance(saltID, 0.0);
	rmSetObjectDefMaxDistance(saltID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(saltID, avoidAll);
	rmAddObjectDefConstraint(saltID, avoidSocket);
	rmAddObjectDefConstraint(saltID, avoidTradeRoute);
	rmAddObjectDefConstraint(saltID, avoidTC);
	rmAddObjectDefConstraint(saltID, avoidCW);
 rmPlaceObjectDefInArea(saltID, 0, DallolCrateID, cNumberNonGaiaPlayers*4);



/////////////////////////////// MINES ////////////////////////////////////


	// Silver

	int silverID = -1;
 	int silverID2 = -1;

	int avoidSilver=rmCreateTypeDistanceConstraint("avoid silver", "mine", 75.0);
	int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "minegold", 50.0);
	int shortAvoidTradeRouteMines = rmCreateTradeRouteDistanceConstraint("short trade route", 6.0);

  int silverCount = 0;
  
  silverCount = cNumberNonGaiaPlayers*3;
  
	rmEchoInfo("silver count = "+silverCount);


*/


  // King of the Hill (added 2026-11 for WoL): centre, on the salt flat between all start positions
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




