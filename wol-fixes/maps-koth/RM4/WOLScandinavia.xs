// Scandinavia

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
		subCiv0=rmGetCivID("LoggingCamp");
		rmEchoInfo("subCiv0 is LoggingCamp "+subCiv0);
		if (subCiv0 >= 0)
		rmSetSubCiv(0, "LoggingCamp");

		subCiv1=rmGetCivID("FurTrapper");
		rmEchoInfo("subCiv1 is FurTrapper "+subCiv1);
		if (subCiv1 >= 0)
		rmSetSubCiv(1, "FurTrapper");

		subCiv2=rmGetCivID("ShepherdVillage");
		rmEchoInfo("subCiv2 is ShepherdVillage "+subCiv2);
		if (subCiv2 >= 0)
		rmSetSubCiv(2, "ShepherdVillage");
	}

		// Randomizes the GAIA civ.
	//int randomEUROciv=-1;
	//randomEUROciv = rmRandInt(1,2);	
	//if ( randomEUROciv == 1 )
	//		rmSetGaiaCiv(cCivFAKEscandinavia1);
	//if ( randomEUROciv == 2 )
	//		rmSetGaiaCiv(cCivFAKEscandinavia2);
		

/// VARIATIONS ///

	// Choose summer or winter 
	int seasonPicker = rmRandInt(1,3);//1 = summer; 2 = winter; 3 = finbulwinter
	int mapDivision = rmRandInt(1,2);//1 = up; 2 = down	

	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
if (seasonPicker == 1) //summer
{
  string herdableType = "sheep";
  string huntable1 = "deer";
  string huntable2 = "Elk";
  string huntable3 = "Rabbit";
  string fish1 = "FishCod";
  string fish2 = "ypFishTuna";
  string whale1 = "HumpbackWhale";
  string startTreeType = "TreeRockies";
  string forestType = "rockies forest";
  string terrainMix = "rockies_grass";
  string waterType = "great plains pond";
  string lightingType = "311b";
   string routeType = "dirt";
   string mapType = "grass";
   int  	wintermultiplier = 1.0;
   int seasonmultiplier = 2.0;
}
if (seasonPicker == 2) //winter
{
  herdableType = "sheep";
   huntable1 = "deer";
   huntable2 = "Elk";
   huntable3 = "Rabbit";
   fish1 = "FishCod";
   fish2 = "ypFishTuna";
   whale1 = "HumpbackWhale";
   startTreeType = "TreeRockiesSnow";
   forestType = "rockies forest";
   terrainMix = "rockies_grass_snowa";
   waterType = "great lakes ice";
   lightingType = "302a";
	routeType = "dirt";
	mapType = "snow";
	 	wintermultiplier = 1.5;
	seasonmultiplier = 1.5;
}
if (seasonPicker == 3) //finmbulwinter
{
  herdableType = "sheep";
   huntable1 = "deer";
   huntable2 = "Elk";
   huntable3 = "Rabbit";
   fish1 = "FishCod";
   fish2 = "ypFishTuna";
   whale1 = "HumpbackWhale";
   startTreeType = "TreeYukon";
   forestType = "rockies snow forest";
   terrainMix = "yukon snow";
   waterType = "great lakes ice";
   lightingType = "great lakes winter";
 routeType = "EuroSnow";
 mapType = "snow";
 	seasonmultiplier = 1;
 	wintermultiplier = 2.0;
    rmSetGlobalSnow( 0.7 );
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
	rmSetMapElevationParameters(cElevTurbulence, 0.02, 10, 0.2, 10.0);  //1-frequency of turb; 2-
	rmSetBaseTerrainMix(terrainMix);
	rmTerrainInitialize("yukon\ground1_yuk", 5);
	rmSetLightingSet(lightingType);
	rmSetMapType("land");
	rmSetMapType("rockies");
	rmSetWorldCircleConstraint(true);
	rmSetMapType(mapType);

	// Misc variables for use later
	int numTries = -1;
	int numTries2 = -1;

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
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("classSocket");
	rmDefineClass("canyon");



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
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 15.0);
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
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "BerryBush", 50.0);	//Attempting to spread them out more evenly.
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
	int avoidSocketfar = rmCreateClassDistanceConstraint("avoid socket far", rmClassID("classSocket"), 15.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);

	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  (It excludes the west bay, where I do not want the flags.)
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

	// int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);












/////////////////////////////// DEFINE STARTING OBJECTS ////////////////////////////////////

  int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 60.0);
	int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 60.0);
	int avoidTradeRouteSockets=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 8.0);
	int avoidTradeRouteSocketsShort=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 8.0);
	int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other short", rmClassID("importantItem"), 8.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("short stay away from players", classPlayer, 5.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);



  int food1ID=rmCreateObjectDef("huntable1");
	rmAddObjectDefItem(food1ID, huntable1, rmRandInt(8,10)*seasonmultiplier, 6.0);
	rmSetObjectDefCreateHerd(food1ID, true);
	rmSetObjectDefMinDistance(food1ID, 0.0);
	rmSetObjectDefMaxDistance(food1ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food1ID, avoidResource);
	rmAddObjectDefConstraint(food1ID, playerConstraint);
	rmAddObjectDefConstraint(food1ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food1ID, avoidHuntable1);
	rmAddObjectDefConstraint(food1ID, avoidHuntable2);
	rmAddObjectDefConstraint(food1ID, avoidTradeRoute);
  rmAddObjectDefConstraint(food1ID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(food1ID, avoidTradeRouteSocketsShort);
  
  int food2ID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(food2ID, huntable2, rmRandInt(5,7)*seasonmultiplier, 6.0);
	rmSetObjectDefCreateHerd(food2ID, true);
	rmSetObjectDefMinDistance(food2ID, 0.0);
	rmSetObjectDefMaxDistance(food2ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food2ID, avoidResource);
	rmAddObjectDefConstraint(food2ID, playerConstraint);
	rmAddObjectDefConstraint(food2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food2ID, avoidHuntable1);
	rmAddObjectDefConstraint(food2ID, avoidHuntable2);
	rmAddObjectDefConstraint(food2ID, avoidTradeRoute);
	rmAddObjectDefConstraint(food2ID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(food2ID, avoidTradeRouteSocketsShort);
 
  int food3ID=rmCreateObjectDef("huntable3");
	rmAddObjectDefItem(food3ID, huntable3, rmRandInt(6,8)*seasonmultiplier, 6.0);
	rmSetObjectDefCreateHerd(food3ID, true);
	rmSetObjectDefMinDistance(food3ID, 0.0);
	rmSetObjectDefMaxDistance(food3ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food3ID, avoidResource);
	rmAddObjectDefConstraint(food3ID, playerConstraint);
	rmAddObjectDefConstraint(food3ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food3ID, avoidHuntable1);
	rmAddObjectDefConstraint(food3ID, avoidHuntable2);
	rmAddObjectDefConstraint(food3ID, avoidTradeRoute);
	rmAddObjectDefConstraint(food3ID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(food3ID, avoidTradeRouteSocketsShort);
	
  int startFoodID=rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(startFoodID, huntable3, 6*seasonmultiplier, 4.0);
	rmSetObjectDefMinDistance(startFoodID, 12.0);
	rmSetObjectDefMaxDistance(startFoodID, 18.0);
	rmSetObjectDefCreateHerd(startFoodID, false);
	rmAddObjectDefConstraint(startFoodID, avoidAll);
	rmAddObjectDefConstraint(startFoodID, avoidStartResource);
	rmAddObjectDefConstraint(startFoodID, avoidHuntable1);    
	rmAddObjectDefConstraint(startFoodID, avoidHuntable2);    
  rmAddObjectDefConstraint(startFoodID, avoidTradeRoute);
  
  int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 6*wintermultiplier, 6.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 16);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 22);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartResource);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRouteSocketsShort);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRoute);

	int StartBerriesID=rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(StartBerriesID, "BerryBush", 6*wintermultiplier, 5.0);
	rmSetObjectDefMinDistance(StartBerriesID, 10);
	rmSetObjectDefMaxDistance(StartBerriesID, 15);
	rmAddObjectDefConstraint(StartBerriesID, avoidAll);
	rmAddObjectDefConstraint(StartBerriesID, avoidStartResource);
	rmAddObjectDefConstraint(StartBerriesID, shortPlayerConstraint);
	rmAddObjectDefConstraint(StartBerriesID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(StartBerriesID, shortPlayerConstraint);
  rmAddObjectDefConstraint(StartBerriesID, avoidTradeRoute);
  
  int startSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(startSilverID, "minegold", 1, 0);
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
  
    if(teamSide > .5) 
		{
      if(mapDivision > 1) //up
	  { 
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.1, .4);
        rmPlacePlayersCircular(.35, .35, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.6, .9);
        rmPlacePlayersCircular(.35, .35, 0);
      }   
      else //down
	  {
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.9, .2);
        rmPlacePlayersCircular(.35, .35, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.4, .7);
        rmPlacePlayersCircular(.35, .35, 0);
      }
    }
    
    else {
        if(mapDivision > 1) //up
	  { 
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.1, .4);
        rmPlacePlayersCircular(.35, .35, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.6, .9);
        rmPlacePlayersCircular(.35, .35, 0);
      }   
      else //down
	  {
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.9, .2);
        rmPlacePlayersCircular(.35, .35, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.4, .7);
        rmPlacePlayersCircular(.35, .35, 0);
      }
    }
  }
  
  // ffa
  else {
    rmSetTeamSpacingModifier(0.5);
    rmPlacePlayersCircular(.35, .35, 0.05);
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


  
    

  
  /////////////////////////////// PLACE TRADE ROUTE ////////////////////////////////////


   int socketID=rmCreateObjectDef("Trade Route");
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 0.0);
	rmSetObjectDefMaxDistance(socketID, 6.0);
	rmAddObjectDefConstraint(socketID, shortAvoidTradeRoute);

	int tradeRouteID = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	float TradeRouteVariation = rmRandFloat(-0.2,0.2);
	if (mapDivision > 1) //up
	{
	rmAddTradeRouteWaypoint(tradeRouteID, 0, 0.5+TradeRouteVariation); 	
	rmAddTradeRouteWaypoint(tradeRouteID, 1, 0.5-TradeRouteVariation); 		
	}
	else //down
	{
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5+TradeRouteVariation, 0); 	
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5-TradeRouteVariation, 1); 		
	}


	bool placedTradeRouteB = rmBuildTradeRoute(tradeRouteID, routeType);
	if(placedTradeRouteB == false)
		rmEchoError("Failed to place trade route 2");
	vector socket1Loc = rmGetTradeRouteWayPoint(tradeRouteID, 0.00);
	if (cNumberTeams <= 2)
	{
			socket1Loc = rmGetTradeRouteWayPoint(tradeRouteID, 0.20);
			rmPlaceObjectDefAtPoint(socketID, 0, socket1Loc);
			socket1Loc = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
			rmPlaceObjectDefAtPoint(socketID, 0, socket1Loc);
			socket1Loc = rmGetTradeRouteWayPoint(tradeRouteID, 0.80);
			rmPlaceObjectDefAtPoint(socketID, 0, socket1Loc);
	}
	else
	{
			socket1Loc = rmGetTradeRouteWayPoint(tradeRouteID, 0.30);
			rmPlaceObjectDefAtPoint(socketID, 0, socket1Loc);
			socket1Loc = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
			rmPlaceObjectDefAtPoint(socketID, 0, socket1Loc);
			socket1Loc = rmGetTradeRouteWayPoint(tradeRouteID, 0.70);
			rmPlaceObjectDefAtPoint(socketID, 0, socket1Loc);	
	}	
			
		
			
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
    
    // Place a nugget for the player
    rmSetNuggetDifficulty(1, 1);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    
    rmClearClosestPointConstraints();
  }

  

	
	


			
			
			  	/////////////////////////////// PLACE EUROPEAN VILLAGES ////////////////////////////////////   


	
	        // Native settlements defined and placed
 
		int whichNative = 0;
      int nativeVillage = 0;
		string nativeName = "";
	  



	int avoidNativesVeryLong = rmCreateClassDistanceConstraint("avoid natives long ", rmClassID("natives"), 100.0);
	int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 20.0);

	whichNative = rmRandInt(1,3);
      if(whichNative == 1)
      {
         rmSetSubCiv(1, "FurTrapper");
         nativeName = "european fur trappers east";
      }
	   if(whichNative == 2)
      {
         rmSetSubCiv(2, "ShepherdVillage");
         nativeName = "european shepherd village east";
      }
	   if(whichNative == 3)
      {
         rmSetSubCiv(0, "LoggingCamp");
         nativeName = "european logging camp east";
      }
      nativeVillage = rmCreateGrouping("European 1", nativeName);
      rmSetGroupingMinDistance(nativeVillage, 10.0);
      rmSetGroupingMaxDistance(nativeVillage, 30.0);
      rmAddGroupingConstraint(nativeVillage, avoidAll);
      rmAddGroupingConstraint(nativeVillage, playerEdgeConstraint);
      rmAddGroupingConstraint(nativeVillage, playerConstraint);
	  	rmAddGroupingConstraint(nativeVillage, avoidNativesVeryLong);
		  	rmAddGroupingConstraint(nativeVillage, avoidTradeRouteFar);
		rmAddGroupingToClass(nativeVillage, rmClassID("natives"));
	 	rmAddGroupingConstraint(nativeVillage, avoidImpassableLand);	

			whichNative = rmRandInt(1,3);
      if(whichNative == 1)
      {
         rmSetSubCiv(1, "FurTrapper");
         nativeName = "european fur trappers east";
      }
	   if(whichNative == 2)
      {
         rmSetSubCiv(2, "ShepherdVillage");
         nativeName = "european shepherd village east";
      }
	   if(whichNative == 3)
      {
         rmSetSubCiv(0, "LoggingCamp");
         nativeName = "european logging camp east";
      }
			  int    nativeVillageSouth = rmCreateGrouping("European 2", nativeName);
      rmSetGroupingMinDistance(nativeVillageSouth, 10.0);
      rmSetGroupingMaxDistance(nativeVillageSouth, 30.0);
      rmAddGroupingConstraint(nativeVillageSouth, avoidAll);
      rmAddGroupingConstraint(nativeVillageSouth, playerEdgeConstraint);
      rmAddGroupingConstraint(nativeVillageSouth, playerConstraint);
	  	rmAddGroupingConstraint(nativeVillageSouth, avoidNativesVeryLong);
		  	rmAddGroupingConstraint(nativeVillageSouth, avoidTradeRouteFar);
		rmAddGroupingToClass(nativeVillageSouth, rmClassID("natives"));
	 	rmAddGroupingConstraint(nativeVillageSouth, avoidImpassableLand);

			
			
	if (cNumberTeams <= 2)
	{
			socket1Loc = rmGetTradeRouteWayPoint(tradeRouteID, 0.30);
			rmPlaceGroupingAtPoint(nativeVillage, 0, socket1Loc);
			
			socket1Loc = rmGetTradeRouteWayPoint(tradeRouteID, 0.70);
			rmPlaceGroupingAtPoint(nativeVillageSouth, 0, socket1Loc);	
	}
	else
	{
      rmSetGroupingMinDistance(nativeVillage, 0.0);	
      rmSetGroupingMinDistance(nativeVillageSouth, 0.0);
		rmSetGroupingMaxDistance(nativeVillage, 5.0);
	 rmSetGroupingMaxDistance(nativeVillageSouth, 5.0);
			  
		if (mapDivision >1) //up
		{
						rmPlaceGroupingAtLoc(nativeVillage, 0, 0.5, 0.65);
						rmPlaceGroupingAtLoc(nativeVillageSouth, 0, 0.5, 0.35);
		}
		else //down
		{
						rmPlaceGroupingAtLoc(nativeVillage, 0, 0.65, 0.5);
						rmPlaceGroupingAtLoc(nativeVillageSouth, 0, 0.35, 0.5);
		}			
	
	}

	


	int shortAvoidTradeRouteMines = rmCreateTradeRouteDistanceConstraint("trees and mines short trade route", 12.0);


  




  



  

	
  
   /////////////////////////////// PONDS ////////////////////////////////////

	// Ponds o' Fun
	int pondClass=rmDefineClass("pond");
   int pondConstraint=rmCreateClassDistanceConstraint("ponds avoid ponds", rmClassID("pond"), 90.0);
	int numPonds=15;
	
   if (seasonPicker<3)
   {
   for(i=0; <numPonds)
   {
      int smallPondID=rmCreateArea("small pond"+i);
      rmSetAreaSize(smallPondID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(340));
      rmSetAreaWaterType(smallPondID, waterType);
      rmSetAreaBaseHeight(smallPondID, 4);
      rmSetAreaMinBlobs(smallPondID, 2);
      rmSetAreaMaxBlobs(smallPondID, 4);
      rmSetAreaMinBlobDistance(smallPondID, 5.0);
      rmSetAreaMaxBlobDistance(smallPondID, 70.0);
      rmAddAreaToClass(smallPondID, pondClass);
      rmSetAreaCoherence(smallPondID, 0.5);
      rmSetAreaSmoothDistance(smallPondID, 5);
      rmAddAreaConstraint(smallPondID, pondConstraint);
      rmAddAreaConstraint(smallPondID, avoidNatives);
      rmAddAreaConstraint(smallPondID, longPlayerConstraint);
      rmAddAreaConstraint(smallPondID, avoidTradeRoute);
		rmAddAreaConstraint(smallPondID, avoidSocket);
		rmAddAreaConstraint(smallPondID, avoidImportantItem);
		rmAddAreaConstraint(smallPondID, playerEdgeConstraint);
//		rmAddAreaConstraint(smallPondID, avoidNuggetSmall);
      rmSetAreaWarnFailure(smallPondID, false);
      rmBuildArea(smallPondID);
   }

   }
   
   else
   {
   for(i=0; <numPonds) //frozen
   {
      smallPondID=rmCreateArea("small pond"+i);
      rmSetAreaSize(smallPondID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(340));
	rmSetAreaMix(smallPondID, "great_lakes_ice");
      rmSetAreaBaseHeight(smallPondID, 0);
      rmSetAreaMinBlobs(smallPondID, 2);
      rmSetAreaMaxBlobs(smallPondID, 4);
      rmSetAreaMinBlobDistance(smallPondID, 5.0);
      rmSetAreaMaxBlobDistance(smallPondID, 70.0);
      rmAddAreaToClass(smallPondID, pondClass);
      rmSetAreaCoherence(smallPondID, 0.5);
      rmSetAreaSmoothDistance(smallPondID, 5);
      rmAddAreaConstraint(smallPondID, pondConstraint);
      rmAddAreaConstraint(smallPondID, longPlayerConstraint);
      rmAddAreaConstraint(smallPondID, avoidTradeRoute);
		rmAddAreaConstraint(smallPondID, avoidSocket);
      rmAddAreaConstraint(smallPondID, avoidNatives);
		rmAddAreaConstraint(smallPondID, avoidImportantItem);
		rmAddAreaConstraint(smallPondID, playerEdgeConstraint);
//		rmAddAreaConstraint(smallPondID, avoidNuggetSmall);
      rmSetAreaWarnFailure(smallPondID, false);
      rmBuildArea(smallPondID);
   }

   }
  

 
  /////////////////////////////// FORESTS ////////////////////////////////////


	// Scattered FORESTS
   int forestTreeID = 0;
   numTries2=15*cNumberNonGaiaPlayers;
   int failCount2=0;

   for (i=0; <numTries2)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(250), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest, forestType);
         rmSetAreaForestDensity(forest, 0.9);
         rmSetAreaForestClumpiness(forest, 0.6);
         rmSetAreaForestUnderbrush(forest, 0.2);
         rmSetAreaMinBlobs(forest, 3);
         rmSetAreaMaxBlobs(forest, 7);
         rmSetAreaMinBlobDistance(forest, 16.0);
         rmSetAreaMaxBlobDistance(forest, 40.0);
         rmSetAreaCoherence(forest, 0.9);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
        rmAddAreaConstraint(forest, forestConstraint);
         rmAddAreaConstraint(forest, avoidAll);
         rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(forest, avoidTC);
		 		 rmAddAreaConstraint(forest, avoidTradeRouteSockets);
		 rmAddAreaConstraint(forest, avoidCW);
				 rmAddAreaConstraint(forest, avoidNatives);
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

	  
/////////////////////////////// TREASURES ////////////////////////////////////

  int playerConstraintNugget=rmCreateClassDistanceConstraint("stay away from players far", classPlayer, 55.0);
  int avoidNuggetsShort=rmCreateTypeDistanceConstraint("vs nugget short", "AbstractNugget", 10.0);
  int avoidNuggets=rmCreateTypeDistanceConstraint("nugget vs. nugget", "AbstractNugget", 40.0);
	int avoidNuggetFar=rmCreateTypeDistanceConstraint("nugget vs. nugget far", "AbstractNugget", 70.0);

  int nugget4= rmCreateObjectDef("nugget nuts"); 
  rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(4, 4);
  rmSetObjectDefMinDistance(nugget4, 0.0);
  rmSetObjectDefMaxDistance(nugget4, rmXFractionToMeters(0.2));
  rmAddObjectDefConstraint(nugget4, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget4, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget4, avoidResource);
  rmAddObjectDefConstraint(nugget4, avoidNuggets);
   rmAddObjectDefConstraint(nugget4, avoidNatives);
  rmAddObjectDefConstraint(nugget4, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget4, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget4, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget4, circleConstraint);
  rmPlaceObjectDefAtLoc(nugget4, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);

  int nugget3= rmCreateObjectDef("nugget hard"); 
  rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(3, 3);
  rmSetObjectDefMinDistance(nugget3, 0.0);
  rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.2));
  rmAddObjectDefConstraint(nugget3, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget3, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget3, avoidResource);
  rmAddObjectDefConstraint(nugget3, avoidNuggets);
     rmAddObjectDefConstraint(nugget3, avoidNatives);
  rmAddObjectDefConstraint(nugget3, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget3, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget3, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget3, circleConstraint);
  rmPlaceObjectDefAtLoc(nugget3, 0, 0.5, 0.5, cNumberNonGaiaPlayers+rmRandInt(1,1));

  int nugget2= rmCreateObjectDef("nugget medium"); 
  rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(2, 2);
  rmAddObjectDefConstraint(nugget2, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget2, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget2, avoidResource);
  rmAddObjectDefConstraint(nugget2, avoidNuggetFar);
     rmAddObjectDefConstraint(nugget2, avoidNatives);
  rmAddObjectDefConstraint(nugget2, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget2, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget2, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget2, circleConstraint);
  rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.25));
  rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.3));
  rmPlaceObjectDefAtLoc(nugget2, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

  int nugget1= rmCreateObjectDef("nugget easy"); 
  rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(1, 1);
  rmAddObjectDefConstraint(nugget1, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget1, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget1, avoidNuggetFar);
     rmAddObjectDefConstraint(nugget1, avoidNatives);
  rmAddObjectDefConstraint(nugget1, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget1, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget1, playerConstraint);
  rmAddObjectDefConstraint(nugget1, circleConstraint);
  rmSetObjectDefMinDistance(nugget1, rmXFractionToMeters(0.3));
  rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.4));
  rmPlaceObjectDefAtLoc(nugget1, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

  
	  
	  /////////////////////////////// SHEEP ////////////////////////////////////
  
  	int sheepID=rmCreateObjectDef("sheep");
	rmAddObjectDefItem(sheepID, "sheep", 2*seasonmultiplier, 4.0);
	rmSetObjectDefMinDistance(sheepID, 0.0);
	rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(sheepID, avoidSheep);
	rmAddObjectDefConstraint(sheepID, avoidAll);
	rmAddObjectDefConstraint(sheepID, playerConstraint);
//	rmAddObjectDefConstraint(sheepID, avoidCliffs);
	rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);
	
/////////////////////////////// HUNTABLES ////////////////////////////////////

  rmPlaceObjectDefAtLoc(food1ID, 0, 0.5, 0.5, 2.0*cNumberNonGaiaPlayers);
  rmPlaceObjectDefAtLoc(food2ID, 0, 0.5, 0.5, 2.0*cNumberNonGaiaPlayers);
  rmPlaceObjectDefAtLoc(food3ID, 0, 0.5, 0.5, 4.0*cNumberNonGaiaPlayers);

	// Berries
	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "berrybush", rmRandInt(3,6)*seasonmultiplier, 6.0);  // (3,5) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(berriesID, playerConstraint);
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, avoidResource);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
  rmAddObjectDefConstraint(berriesID, avoidImportantItem);    
	rmPlaceObjectDefAtLoc(berriesID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);

/////////////////////////////// MINES ////////////////////////////////////


	// Silver

	int silverID = -1;
	int silverType = -1;
	int silverCount = (cNumberNonGaiaPlayers*3);
	rmEchoInfo("silver count = "+silverCount);

		int avoidFastCoin=-1;
	if (cNumberNonGaiaPlayers >6)
	{
		avoidFastCoin=rmCreateTypeDistanceConstraint("fast coin avoids coin", "gold", rmXFractionToMeters(0.14));
	}
	else if (cNumberNonGaiaPlayers >4)
	{
		avoidFastCoin=rmCreateTypeDistanceConstraint("fast coin avoids coin", "gold", rmXFractionToMeters(0.16));
	}
	else
	{
		avoidFastCoin=rmCreateTypeDistanceConstraint("fast coin avoids coin", "gold", rmXFractionToMeters(0.18));
	}
	
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
		rmAddObjectDefConstraint(silverID, avoidResource);
		rmAddObjectDefConstraint(silverID, playerConstraint);
//		rmAddObjectDefConstraint(silverID, avoidNuggetSmall);
		int result = rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
		if(result == 0)
			break;
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

}