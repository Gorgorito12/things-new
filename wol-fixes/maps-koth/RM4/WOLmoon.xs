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
	rmSetMapElevationParameters(cElevTurbulence, 0.00, 0, 0.0, 0.0);
	rmSetBaseTerrainMix("space");
	rmTerrainInitialize("yukon\ground1_yuk", 5);
	rmSetLightingSet("309a_summoned");
	rmSetMapType("moon");
	rmSetMapType("land");
	rmSetWorldCircleConstraint(true);
	rmSetMapType("grass");
	//rmSetSeaLevel(-4.0); //Pierre Jean: The debugger sees this as error

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
		rmDefineClass("classCliff");
			rmDefineClass("classMoon");
	rmDefineClass("canyon");
	rmDefineClass("classWaterTradeRoute");
	rmDefineClass("Green");
	rmDefineClass("Olive");

  string herdableType = "ypWaterBuffalo";
  string huntable1 = "Rabbit";
  string huntable2 = "Bison";
  string huntable3 = "Rabbit";
  string fish1 = "FishCod";
  string fish2 = "ypFishTuna";
  string whale1 = "HumpbackWhale";
  string startTreeType = "DLCmoontree";

   // -------------Define constraints----------------------------------------

    // Create an edge of map constraint.
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Player area constraint.
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 35.0);
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
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);




	int invisIslandID=rmCreateArea("invisible island");
	rmSetAreaSize(invisIslandID, 0.09, 0.09);
	rmSetAreaCoherence(invisIslandID, 0.8);
  rmSetAreaLocation(invisIslandID, .5, .5);
	rmSetAreaWarnFailure(invisIslandID, false);
	rmBuildArea(invisIslandID);


	// DEFINE AREAS

   // Build up big continent called "space"
   int bigContinentID=rmCreateArea("space");
   rmSetAreaSize(bigContinentID, 0.9, 0.9); // 3 35
   rmSetAreaWarnFailure(bigContinentID, false);
   // rmSetAreaSmoothDistance(bigContinentID, 10);
	rmSetAreaMix(bigContinentID, "space");
   rmSetAreaCoherence(bigContinentID, 1.0);
   rmSetAreaLocation(bigContinentID, 0.5, 0.5);
	rmSetAreaCliffType(bigContinentID, "black");
	rmSetAreaCliffEdge(bigContinentID, 1, 1.0, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(bigContinentID, -15, 1.0, 0.3);
	rmSetAreaCliffPainting(bigContinentID, false, false, true);
//	rmAddAreaToClass(bigContinentID, rmClassID("classCliff"));
	rmBuildArea(bigContinentID);

		   // Build up dark side of the moon
	   int moondarkID = rmCreateArea("moondark");
   rmSetAreaWarnFailure(moondarkID, false);
   rmSetAreaSize(moondarkID, 0.5, 0.5);
    rmSetAreaLocation(moondarkID, 0.5, 0.5); 
   rmSetAreaCoherence(moondarkID, 1.0);
   //rmAddAreaInfluenceSegment(moondarkID, 0.0, 0.1, 0.75, 0.9);
//   rmSetAreaTerrainType(moondarkID, "wotta\tuscany\yellow");
//	rmAddAreaTerrainLayer(moondarkID, "wotta\tuscany\brown3", 0, 4);
 //  rmAddAreaTerrainLayer(moondarkID, "wotta\tuscany\brown", 4, 10);
 //  rmAddAreaTerrainLayer(moondarkID, "wotta\tuscany\brown2", 10, 16);
   rmSetAreaObeyWorldCircleConstraint(moondarkID, false);
	rmSetAreaMix(moondarkID, "moon-dark");
//	rmAddAreaToClass(moondarkID, rmClassID("Olive"));
   rmBuildArea(moondarkID);
   
   
   	int moonlightEdgeConstraint=rmCreatePieConstraint("moonlight edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.40), rmDegreesToRadians(0), rmDegreesToRadians(360));
	
		   // Build up light side of the moon
	   int moonlightID = rmCreateArea("moonlight");
   rmSetAreaWarnFailure(moonlightID, false);
   rmSetAreaSize(moonlightID, 0.35, 0.35);
    rmSetAreaLocation(moonlightID, 0.3, 0.6); 
   rmSetAreaCoherence(moonlightID, 1.0);
   //rmAddAreaInfluenceSegment(moonlightID, 0.0, 0.1, 0.75, 0.9);
//   rmSetAreaTerrainType(moonlightID, "wotta\tuscany\yellow");
//	rmAddAreaTerrainLayer(moonlightID, "wotta\tuscany\brown3", 0, 4);
 //  rmAddAreaTerrainLayer(moonlightID, "wotta\tuscany\brown", 4, 10);
 //  rmAddAreaTerrainLayer(moonlightID, "wotta\tuscany\brown2", 10, 16);
   rmSetAreaObeyWorldCircleConstraint(moonlightID, false);
	rmSetAreaMix(moonlightID, "moon-light");
	rmAddAreaConstraint(moonlightID, moonlightEdgeConstraint);
//	rmAddAreaToClass(moonlightID, rmClassID("Olive"));
   rmBuildArea(moonlightID);	
	
   // Build up big continent called "moon"
   int moonID=rmCreateArea("moon");
   rmSetAreaSize(moonID, 0.5, 0.5); // 3 35
   rmSetAreaWarnFailure(moonID, false);
   // rmSetAreaSmoothDistance(moonID, 10);
	rmSetAreaMix(moonID, "rockies_snow");
   rmSetAreaCoherence(moonID, 1.0);
   rmSetAreaLocation(moonID, 0.5, 0.5);
	rmSetAreaCliffType(moonID, "moontospace");
	rmSetAreaCliffEdge(moonID, 1, 1.0, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(moonID, 15, 1.0, 0.3);
	rmSetAreaCliffPainting(moonID, false, false, true);
	rmAddAreaToClass(moonID, rmClassID("classMoon"));
	rmBuildArea(moonID);


  int mooncontrollerID = rmCreateObjectDef("moon helmet");
	rmAddObjectDefItem(mooncontrollerID, "DLCthemoon", 1, 0);
	rmSetObjectDefMinDistance(mooncontrollerID, 18.0);
	rmSetObjectDefMaxDistance(mooncontrollerID, 23.0);
		rmPlaceObjectDefAtLoc(mooncontrollerID, 0, 0.5,0.5);





/////////////////////////////// DEFINE STARTING OBJECTS ////////////////////////////////////

  int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 60.0);
	int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 60.0);
	//int avoidTradeRouteSockets=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 8.0); // Pierre Jean: The debugger sees this as error
	int avoidTradeRouteSockets=rmCreateTypeDistanceConstraint("avoid trade route sockets", "sockettraderoute", 8.0); // Pierre Jean: Fix
	int avoidTradeRouteSocketsShort=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 8.0);
	int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other short", rmClassID("importantItem"), 8.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("short stay away from players", classPlayer, 5.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);
   	int craterEdgeConstraint=rmCreatePieConstraint("crater edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.39), rmDegreesToRadians(0), rmDegreesToRadians(360));



  int food1ID=rmCreateObjectDef("huntable1");
	rmAddObjectDefItem(food1ID, huntable1, rmRandInt(8,10), 6.0);
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
  			rmAddObjectDefConstraint(food1ID, craterEdgeConstraint);
	rmAddObjectDefConstraint(food1ID, avoidTradeRouteSocketsShort);
  
  int food2ID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(food2ID, huntable2, rmRandInt(2,4), 6.0);
	rmSetObjectDefCreateHerd(food2ID, true);
	rmSetObjectDefMinDistance(food2ID, 0.0);
	rmSetObjectDefMaxDistance(food2ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food2ID, avoidResource);
	rmAddObjectDefConstraint(food2ID, playerConstraint);
	rmAddObjectDefConstraint(food2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food2ID, avoidHuntable1);
	rmAddObjectDefConstraint(food2ID, avoidHuntable2);
	rmAddObjectDefConstraint(food2ID, avoidTradeRoute);
			rmAddObjectDefConstraint(food2ID, craterEdgeConstraint);
	rmAddObjectDefConstraint(food2ID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(food2ID, avoidTradeRouteSocketsShort);
  
  int startFoodID=rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(startFoodID, huntable3, 10, 6.0);
	rmSetObjectDefMinDistance(startFoodID, 12.0);
	rmSetObjectDefMaxDistance(startFoodID, 18.0);
	rmSetObjectDefCreateHerd(startFoodID, false);
	rmAddObjectDefConstraint(startFoodID, avoidAll);
	rmAddObjectDefConstraint(startFoodID, avoidStartResource);
	rmAddObjectDefConstraint(startFoodID, avoidHuntable1);    
	rmAddObjectDefConstraint(startFoodID, avoidHuntable2);    
  rmAddObjectDefConstraint(startFoodID, avoidTradeRoute);
  
  int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 6, 6.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 16);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 22);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartResource);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRouteSocketsShort);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRoute);

	int StartBerriesID=rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(StartBerriesID, "BerryBush", 6, 5.0);
	rmSetObjectDefMinDistance(StartBerriesID, 10);
	rmSetObjectDefMaxDistance(StartBerriesID, 15);
	rmAddObjectDefConstraint(StartBerriesID, avoidAll);
	rmAddObjectDefConstraint(StartBerriesID, avoidStartResource);
	rmAddObjectDefConstraint(StartBerriesID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(StartBerriesID, shortPlayerConstraint);
  rmAddObjectDefConstraint(StartBerriesID, avoidTradeRoute);

  int startSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(startSilverID, "SPCSpanishShipRuins", 1, 0);
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
		//rmAddAreaConstraint(startingUnits, craterEdgeConstraint); // Pierre Jean: The debugger sees this as error

/////////////////////////////// DEFINE PLAYERS ////////////////////////////////////


  // Players
    
  float teamSide = rmRandFloat(0, 1);
  // teamSide = 0;
  
  if (weird == false) {
    
    if(teamSide > .5) {
      if(cNumberNonGaiaPlayers > 7) { 
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.5, .8);
        rmPlacePlayersCircular(.25, .25, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.0, .3);
        rmPlacePlayersCircular(.25, .25, 0);
      }
      
      else if(cNumberNonGaiaPlayers > 5) {
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.6, .9);
        rmPlacePlayersCircular(.25, .25, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.1, .4);
        rmPlacePlayersCircular(.25, .25, 0);
      }
      
      else if(cNumberNonGaiaPlayers > 2) {
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.5, .8);
        rmPlacePlayersCircular(.25, .25, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.0, .3);
        rmPlacePlayersCircular(.25, .25, 0);
        
      }
      
      else {
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.74, .75);
        rmPlacePlayersCircular(.25, .25, 0);
        
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.24, .25);
        rmPlacePlayersCircular(.25, .25, 0);
      }
    }
    
    else {
      if(cNumberNonGaiaPlayers > 7) { 
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.5, .8);
        rmPlacePlayersCircular(.25, .25, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.0, .3);
        rmPlacePlayersCircular(.25, .25, 0);
      }
      
      else if(cNumberNonGaiaPlayers > 5) {
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.6, .9);
        rmPlacePlayersCircular(.25, .25, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.1, .4);
        rmPlacePlayersCircular(.25, .25, 0);
      }
      
      else if(cNumberNonGaiaPlayers > 2) {
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.5, .8);
        rmPlacePlayersCircular(.25, .25, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.0, .3);
        rmPlacePlayersCircular(.25, .25, 0);
        
      }
      
      else {
        rmSetPlacementTeam(1);
        rmSetPlacementSection(.74, .75);
        rmPlacePlayersCircular(.25, .25, 0);
        
        rmSetPlacementTeam(0);
        rmSetPlacementSection(.24, .25);
        rmPlacePlayersCircular(.25, .25, 0);
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
    
    // Place a nugget for the player
    rmSetNuggetDifficulty(1, 1);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    
    rmClearClosestPointConstraints();
  }


  	int failCountCliffs = -1;
	int numTriesCliffs = -1;	
	int cliffsAvoidCliffs=rmCreateClassDistanceConstraint("cliffs vs. cliffs", rmClassID("classCliff"), 15.0);
	int rocksAvoidCliffs=rmCreateClassDistanceConstraint("rocks vs. cliffs", rmClassID("classCliff"), 5.0);
	
  	// Define and place cliffs
	numTriesCliffs=cNumberNonGaiaPlayers*6;
	failCountCliffs=0;
	for(i=0; <numTriesCliffs)
	{
		int cratersID=rmCreateArea("crater"+i);
	   rmSetAreaSize(cratersID, rmAreaTilesToFraction(rmRandInt(200,900)), rmAreaTilesToFraction(rmRandInt(200,900)));  // DAL - larger cliffs?
		rmSetAreaWarnFailure(cratersID, false);
		rmSetAreaCliffType(cratersID, "moon");
		rmAddAreaToClass(cratersID, rmClassID("classCliff"));	// Attempt to keep cliffs away from each other.
		rmSetAreaCliffEdge(cratersID, 2, 0.4, 0.1, 1.0, 0);
		rmSetAreaCliffPainting(cratersID, true, true, true, 1.5, true);
		rmSetAreaCliffHeight(cratersID, rmRandInt(-4,-3), 1.0, 1.0);
		rmSetAreaHeightBlend(cratersID, 1);
		rmAddAreaTerrainLayer(cratersID, "texas\ground2_tex", 0, 2);

		rmSetAreaObeyWorldCircleConstraint(cratersID, false);
		rmAddAreaConstraint(cratersID, cliffsAvoidCliffs);				// Avoid cliffs, please!
		rmAddAreaConstraint(cratersID, playerConstraint);		// Keep cliffs away from the player.
		rmAddAreaConstraint(cratersID, avoidImportantItem);
		rmAddAreaConstraint(cratersID, avoidCoin);
		rmAddAreaConstraint(cratersID, craterEdgeConstraint);
		rmSetAreaSmoothDistance(cratersID, 30);						// DAL - used to be 10
		rmSetAreaCoherence(cratersID, 0.90);

		if(rmBuildArea(cratersID)==false)
		{
			// Stop trying once we fail 3 times in a row
			failCountCliffs++;
			if(failCountCliffs==3)
				break;
		}
		else
			failCountCliffs=0;
	}






/////////////////////////////// FORESTS ////////////////////////////////////


	int forestavoidID=rmCreateArea("invisible forest avoid");
	rmSetAreaSize(forestavoidID, 0.44, 0.44);
	rmSetAreaCoherence(forestavoidID, 0.99);
         rmAddAreaToClass(forestavoidID, rmClassID("classCenterForest")); 
  rmSetAreaLocation(forestavoidID, .5, .5);
	rmSetAreaWarnFailure(forestavoidID, false);
	rmBuildArea(forestavoidID);

	int avoidforestcenter = rmCreateClassDistanceConstraint("forest vs. forest1", rmClassID("classCenterForest"), 0.1);


	// Scattered FORESTS
   int forestTreeID = 0;
   numTries2=4*cNumberNonGaiaPlayers;
   int failCount2=0;

   for (i=0; <numTries2)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest, "Moon Forest");
         rmSetAreaForestDensity(forest, 0.6);
         rmSetAreaForestClumpiness(forest, 0.4);
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
         rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(forest, avoidTC);
		 		//rmAddAreaConstraint(cratersID, rocksAvoidCliffs);	 // Pierre Jean: The debugger sees this as error
		 		rmAddAreaConstraint(forest, craterEdgeConstraint);
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
  rmAddObjectDefConstraint(nugget4, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget4, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget4, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget4, circleConstraint);
  rmAddObjectDefConstraint(nugget4, craterEdgeConstraint);
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
  rmAddObjectDefConstraint(nugget3, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget3, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget3, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget3, craterEdgeConstraint);
  rmAddObjectDefConstraint(nugget3, circleConstraint);
  rmPlaceObjectDefAtLoc(nugget3, 0, 0.5, 0.5, cNumberNonGaiaPlayers+rmRandInt(1,1));

  int nugget2= rmCreateObjectDef("nugget medium"); 
  rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(2, 2);
  rmAddObjectDefConstraint(nugget2, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget2, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget2, avoidResource);
  rmAddObjectDefConstraint(nugget2, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget2, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget2, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget2, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget2, circleConstraint);
  rmAddObjectDefConstraint(nugget2, craterEdgeConstraint);
  rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.25));
  rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.3));
  rmPlaceObjectDefAtLoc(nugget2, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

  int nugget1= rmCreateObjectDef("nugget easy"); 
  rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(1, 1);
  rmAddObjectDefConstraint(nugget1, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget1, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget1, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget1, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget1, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(nugget1, playerConstraint);
  rmAddObjectDefConstraint(nugget1, craterEdgeConstraint);
  rmAddObjectDefConstraint(nugget1, circleConstraint);
  rmSetObjectDefMinDistance(nugget1, rmXFractionToMeters(0.3));
  rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.4));
  rmPlaceObjectDefAtLoc(nugget1, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);



/////////////////////////////// HUNTABLES ////////////////////////////////////

  rmPlaceObjectDefAtLoc(food1ID, 0, 0.5, 0.5, 3.0*cNumberNonGaiaPlayers);
  rmPlaceObjectDefAtLoc(food2ID, 0, 0.5, 0.5, 2.0*cNumberNonGaiaPlayers);





/////////////////////////////// MINES ////////////////////////////////////


	// Silver

	int silverID = -1;
 	int silverID2 = -1;

	int avoidSilver=rmCreateTypeDistanceConstraint("avoid silver", "mine", 75.0);
	int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "minegold", 50.0);
	//int shortAvoidTradeRouteMines = rmCreateTradeRouteDistanceConstraint("short trade route", 6.0); // Pierre Jean: The debugger sees this as error
	int shortAvoidTradeRouteMines = rmCreateTradeRouteDistanceConstraint("short trade route 2", 6.0); // Pierre Jean: Fix

  int silverCount = 0;
  
  silverCount = cNumberNonGaiaPlayers*3;
  
	rmEchoInfo("silver count = "+silverCount);


  // silver mines over the entirety of the island
  silverID2 = rmCreateObjectDef("closer silver mines"+i);
  rmAddObjectDefItem(silverID2, "minegold", 1, 0.0);
  rmSetObjectDefMinDistance(silverID2, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(silverID2, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(silverID2, avoidImpassableLand);
  rmAddObjectDefConstraint(silverID2, avoidSilver);
  rmAddObjectDefConstraint(silverID2, avoidGold);
  rmAddObjectDefConstraint(silverID2, playerConstraint);
  rmAddObjectDefConstraint(silverID2, craterEdgeConstraint);
  rmAddObjectDefConstraint(silverID2, shortAvoidTradeRouteMines);
  rmAddObjectDefConstraint(silverID2, shortAvoidImportantItem);
  rmAddObjectDefConstraint(silverID2, avoidTradeRouteSocketsShort);
  rmPlaceObjectDefInArea(silverID2, 0, forestavoidID, silverCount);


  
  /////////////////////////////// STARS ////////////////////////////////////


	// STARS

 	int starsID = -1;

  int starsCount = 0;
  
  starsCount = cNumberNonGaiaPlayers*10;
  
	rmEchoInfo("silver count = "+starsCount);

	int starsAvoidmoon=rmCreateClassDistanceConstraint("avoid moon", rmClassID("classMoon"), 5.0);
	int starsAvoidstars=rmCreateTypeDistanceConstraint("stars v stars", "DLCstars", 30.0);	//Was 8.0
	
  // silver mines over the entirety of the island
  starsID = rmCreateObjectDef("stars"+i);
  rmAddObjectDefItem(starsID, "DLCstars", 1, 0.0);
  rmSetObjectDefMinDistance(starsID, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(starsID, rmXFractionToMeters(0.5));
//  rmAddObjectDefConstraint(starsID, avoidImpassableLand);
    rmAddObjectDefConstraint(starsID, starsAvoidmoon);
	    rmAddObjectDefConstraint(starsID, starsAvoidstars);
  rmPlaceObjectDefAtLoc(starsID, 0, 0.5, 0.5, starsCount);
  
  

  // King of the Hill (added 2026-11 for WoL): the middle is cratered; first open land on the line that splits the teams
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




