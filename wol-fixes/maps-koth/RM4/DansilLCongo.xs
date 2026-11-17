include "triggers\triggerLoader.xs";

// Lower Congo //
// Based in Manitoulin
// Original Design by dansil92

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
 
void main(void) {
    wotta_triggers();
	rmSetStatusText("",0.01);
   // Picks the map size
	int playerTiles=18000;
	if (cNumberNonGaiaPlayers > 4){
		playerTiles = 14000;
	}else if (cNumberNonGaiaPlayers > 6){
		playerTiles = 11500;
	}
	
	int size = 1.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmSetMapSize(size, 1.3*size);

	rmSetMapType("land");
        rmSetMapType("grass");
        rmSetMapType("AFRICANjungle");
       	rmTerrainInitialize("grass");
		rmSetLightingSet("yucatan");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
		
		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 12.0);

       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
		int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.59), rmDegreesToRadians(0), rmDegreesToRadians(360));        

		int avoidDeer=rmCreateTypeDistanceConstraint("Deer avoid Deer", "ypWildElephant", 20.0);


		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 50.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 10.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "Mine", 60.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 5.0);

        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 8.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 35.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 40.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 60.0);
       	int SEconstraint = rmCreateBoxConstraint("stay in middle portion", 0, 0.4, 1, 0.6);

 	// Player placing  
    float spawnSwitch = rmRandFloat(0,1.2);

	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.23, 0.15, 0.77, 0.15, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.77, 0.85, 0.23, 0.85, 0, 0);
		}else if(spawnSwitch <=1.2){
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.23, 0.15, 0.77, 0.15, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.77, 0.85, 0.23, 0.85, 0, 0);
		}
	}else{
		rmPlacePlayersSquare(0.35, 0.4, 0.02);
	}
		
        chooseMercs();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
		rmSetAreaMix(continent2, "lualaba_grass2");
        rmSetAreaTerrainType(continent2, "punjab\punjabground2");
        rmSetAreaBaseHeight(continent2, 1.5);
        rmSetAreaCoherence(continent2, 1.0);
        rmSetAreaSmoothDistance(continent2, 10);
        rmSetAreaHeightBlend(continent2, 1);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 10);
        rmSetAreaElevationVariation(continent2, 3);
        rmSetAreaElevationPersistence(continent2, .2);
        rmSetAreaElevationOctaves(continent2, 5);
        rmSetAreaElevationMinFrequency(continent2, 0.04);
        rmSetAreaElevationType(continent2, cElevTurbulence);  
        rmBuildArea(continent2);    

		int classPatch = rmDefineClass("patch");
		int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 22.0);
		int classCenter = rmDefineClass("center");
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 3.0);
		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.58), rmDegreesToRadians(0), rmDegreesToRadians(360));
        
		int center = rmCreateArea("center");
		rmAddAreaToClass(center, rmClassID("center"));
        rmSetAreaSize(center, .1, .1);
        rmSetAreaLocation(center, 0.5, 0.5);
        rmSetAreaCoherence(center, 1.0);
 //       rmBuildArea(center);   
       		for (i=0; < cNumberNonGaiaPlayers*125){
			int patchID = rmCreateArea("first patch"+i);
			rmSetAreaWarnFailure(patchID, false);
			rmSetAreaSize(patchID, rmAreaTilesToFraction(40), rmAreaTilesToFraction(60));
			rmAddAreaTerrainReplacement(patchID, "lualaba\lualabaRF2", "lualaba\biokoGR1");
			rmPaintAreaTerrain(patchID);
			rmAddAreaToClass(patchID, rmClassID("patch"));
			rmSetAreaSmoothDistance(patchID, 1.0);
			rmAddAreaConstraint(patchID, circleConstraint2);
			rmBuildArea(patchID); 
		}
		
		for (i=0; < cNumberNonGaiaPlayers*125){
			int patchID2 = rmCreateArea("the second patch"+i);
			rmSetAreaWarnFailure(patchID2, false);
			rmSetAreaSize(patchID2, rmAreaTilesToFraction(11), rmAreaTilesToFraction(17));
			rmAddAreaTerrainReplacement(patchID2, "lualaba\lualabaRF1", "lualaba\biokoGR2");
			rmPaintAreaTerrain(patchID2);
			rmAddAreaToClass(patchID2, rmClassID("patch"));
			rmSetAreaSmoothDistance(patchID2, 1.0);
			rmAddAreaConstraint(patchID2, circleConstraint2);
			rmBuildArea(patchID2); 
		}
		rmSetStatusText("",0.2);
		//trade routes
		int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
        rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID, true);
        rmSetObjectDefMinDistance(socketID, 0.0);
        rmSetObjectDefMaxDistance(socketID, 6.0);      
       
        int tradeRouteID = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.0, .5);
		rmAddTradeRouteWaypoint(tradeRouteID, 1.0, .5);

        rmBuildTradeRoute(tradeRouteID, "SavannahTrade1");
 
        vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.4);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.1);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.6);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.9);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);





		rmSetStatusText("",0.3);
				
		int straightLakeNW=rmCreateArea("straightLakeNW");
        rmSetAreaLocation(straightLakeNW, 0.5, 0.67);
/*        rmAddAreaInfluenceSegment(straightLakeNW, 0.0, 0.52, 0.3, 0.69);
        rmAddAreaInfluenceSegment(straightLakeNW, 0.3, 0.69, 0.4, 0.67);        
        rmAddAreaInfluenceSegment(straightLakeNW, 0.4, 0.67, 0.6, 0.67);
        rmAddAreaInfluenceSegment(straightLakeNW, 0.6, 0.67, 0.7, 0.69);
        rmAddAreaInfluenceSegment(straightLakeNW, 0.7, 0.69, 1.0, 0.52);*/
        rmAddAreaInfluenceSegment(straightLakeNW, 0.0, 0.67, 1.0, 0.67);
        rmSetAreaSize(straightLakeNW, .12, .13);      
        rmSetAreaWaterType(straightLakeNW, "Lower Congo");
        rmSetAreaBaseHeight(straightLakeNW, -0.5);
        rmSetAreaCoherence(straightLakeNW, .85);
        rmBuildArea(straightLakeNW);
		

				
		int straightLakeSE=rmCreateArea("straightLakeSE");
        rmSetAreaLocation(straightLakeSE, 0.5, 0.33);
/*        rmAddAreaInfluenceSegment(straightLakeSE, 0.0, 0.48, 0.3, 0.31);
        rmAddAreaInfluenceSegment(straightLakeSE, 0.3, 0.31, 0.4, 0.33);
        rmAddAreaInfluenceSegment(straightLakeSE, 0.4, 0.33, 0.6, 0.33);
        rmAddAreaInfluenceSegment(straightLakeSE, 0.6, 0.33, 0.7, 0.31);
        rmAddAreaInfluenceSegment(straightLakeSE, 0.7, 0.31, 1.0, 0.48);*/
        rmAddAreaInfluenceSegment(straightLakeSE, 0.0, 0.33, 1.0, 0.33);
        rmSetAreaSize(straightLakeSE, .12, .13);      
        rmSetAreaWaterType(straightLakeSE, "Lower Congo");
        rmSetAreaBaseHeight(straightLakeSE, -0.5);
        rmSetAreaCoherence(straightLakeSE, .85);
        rmBuildArea(straightLakeSE);


	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 8.0);




	//starting objects
		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "mine", 1, 8.0);
        rmSetObjectDefMinDistance(goldID, 12.0);
        rmSetObjectDefMaxDistance(goldID, 12.0);
       
        int goldID2 = rmCreateObjectDef("starting gold 2");
        rmAddObjectDefItem(goldID2, "mine", 1, 16.0);
        rmSetObjectDefMinDistance(goldID2, 16.0);
        rmSetObjectDefMaxDistance(goldID2, 19.0);
        rmAddObjectDefConstraint(goldID2, avoidCoin);
        rmAddObjectDefConstraint(goldID2, avoidWaterShort);

 
        int berryID = rmCreateObjectDef("starting sheep");
        rmAddObjectDefItem(berryID, "ypGoat", 10, 6.0);
        rmSetObjectDefMinDistance(berryID, 8.0);
        rmSetObjectDefMaxDistance(berryID, 12.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "ypTreeBorneoPalm", rmRandInt(6,9), 10.0);
        rmSetObjectDefMinDistance(treeID, 12.0);
        rmSetObjectDefMaxDistance(treeID, 18.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "ypWildElephant", 3, 8.0);
        rmSetObjectDefMinDistance(foodID, 12.0);
        rmSetObjectDefMaxDistance(foodID, 12.0);
        rmSetObjectDefCreateHerd(foodID, true);
	
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "Antelope", 7, 8.0);
        rmSetObjectDefMinDistance(foodID2, 14.0);
        rmSetObjectDefMaxDistance(foodID2, 14.0);
        rmSetObjectDefCreateHerd(foodID2, true);
        rmAddObjectDefConstraint(foodID2, avoidWaterShort);

                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "Antelope", 8, 8.0);
        rmSetObjectDefMinDistance(foodID3, 25.0);
        rmSetObjectDefMaxDistance(foodID3, 25.0);
        rmSetObjectDefCreateHerd(foodID3, true);
        rmAddObjectDefConstraint(foodID3, avoidWaterShort);

	int extraberrywagon=rmCreateObjectDef("Starting Asian Outpost");
  rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
  rmSetObjectDefMinDistance(extraberrywagon, 10.0);
  rmSetObjectDefMaxDistance(extraberrywagon, 10.0);

		rmSetStatusText("",0.6);     
 
    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 5.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 10.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		int waterFlag = rmCreateObjectDef("HC water flag "+i);
         rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 0.0);
         rmSetObjectDefMinDistance(waterFlag, 45);
         rmSetObjectDefMaxDistance(waterFlag, 85);
	rmAddObjectDefConstraint(waterFlag, whaleLand);

         rmPlaceObjectDefAtLoc(waterFlag, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i), 1);

if (rmGetPlayerCiv(i) == rmGetCivID("Japanese")) {
        rmPlaceObjectDefAtLoc(extraberrywagon, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
}
	}
	rmSetStatusText("",0.7);
	/*
	==================
	resource placement
	==================
	*/

	


    int pronghornHunts = rmCreateObjectDef("pronghornHunts");
	rmAddObjectDefItem(pronghornHunts, "ypWildElephant", rmRandInt(3,4), 9.0);
	rmSetObjectDefCreateHerd(pronghornHunts, true);
	rmSetObjectDefMinDistance(pronghornHunts, 0);
	rmSetObjectDefMaxDistance(pronghornHunts, rmXFractionToMeters(0.6));
	rmAddObjectDefConstraint(pronghornHunts, circleConstraint);
	rmAddObjectDefConstraint(pronghornHunts, avoidTownCenterMore);
	rmAddObjectDefConstraint(pronghornHunts, avoidDeer);
	rmAddObjectDefConstraint(pronghornHunts, SEconstraint);
	rmAddObjectDefConstraint(pronghornHunts, avoidPlateau);	
	rmPlaceObjectDefAtLoc(pronghornHunts, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

  	int islandminesID = rmCreateObjectDef("island silver");
	rmAddObjectDefItem(islandminesID, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(islandminesID, 0.0);
	rmSetObjectDefMaxDistance(islandminesID, rmXFractionToMeters(0.6));
	rmAddObjectDefConstraint(islandminesID, avoidCoinMed);
	rmAddObjectDefConstraint(islandminesID, avoidTownCenterMore);
	rmAddObjectDefConstraint(islandminesID, avoidSocket);
	rmAddObjectDefConstraint(islandminesID, avoidPlateau);	
	rmAddObjectDefConstraint(islandminesID, avoidWaterShort);
	rmAddObjectDefConstraint(islandminesID, forestConstraintShort);
	rmAddObjectDefConstraint(islandminesID, SEconstraint);
	rmPlaceObjectDefAtLoc(islandminesID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

//*******bonus coin for 4 or less players *******

  if(cNumberNonGaiaPlayers < 5) {

        int goldID0 = rmCreateObjectDef("bonus gold");
        rmAddObjectDefItem(goldID0, "mine", 1, 8.0);
        rmSetObjectDefMinDistance(goldID0, 4.0);
        rmSetObjectDefMaxDistance(goldID0, 10.0);
	rmPlaceObjectDefAtLoc(goldID0, 0, 0.5, 0.15, 1);


        int goldID9 = rmCreateObjectDef("bonus gold 2");
        rmAddObjectDefItem(goldID9, "mine", 1, 8.0);
        rmSetObjectDefMinDistance(goldID9, 4.0);
        rmSetObjectDefMaxDistance(goldID9, 10.0);
	rmPlaceObjectDefAtLoc(goldID9, 0, 0.5, 0.85, 1);

}

  if(cNumberNonGaiaPlayers < 3) {

        int goldID8 = rmCreateObjectDef("bonus gold 3");
        rmAddObjectDefItem(goldID8, "mine", 1, 8.0);
        rmSetObjectDefMinDistance(goldID8, 4.0);
        rmSetObjectDefMaxDistance(goldID8, 10.0);
        rmAddObjectDefConstraint(goldID8, avoidWaterShort);

	rmPlaceObjectDefAtLoc(goldID8, 0, 0.8, 0.2, 1);


        int goldID7 = rmCreateObjectDef("bonus gold 4");
        rmAddObjectDefItem(goldID7, "mine", 1, 8.0);
        rmSetObjectDefMinDistance(goldID7, 4.0);
        rmSetObjectDefMaxDistance(goldID7, 10.0);
        rmAddObjectDefConstraint(goldID7, avoidWaterShort);

	rmPlaceObjectDefAtLoc(goldID7, 0, 0.2, 0.8, 1);

}



// ********* END BONUS COIN ********
 
	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
	rmSetObjectDefMinDistance(nuggetID, 0.0); 
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.6)); 
	rmAddObjectDefConstraint(nuggetID, avoidNugget); 
	rmAddObjectDefConstraint(nuggetID, circleConstraint);
	rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetID, forestConstraintShort);
	rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(nuggetID, avoidSocket); 
	rmAddObjectDefConstraint(nuggetID, avoidPlateau);	
	rmAddObjectDefConstraint(nuggetID, avoidWaterShort);      	
	rmAddObjectDefConstraint(nuggetID, avoidCoin);
	rmSetNuggetDifficulty(1, 3); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);   

	rmSetStatusText("",0.7);

	//removes loop for faster loading times
	//for (j=0; < (6*cNumberNonGaiaPlayers)) {   
		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "ypTreeBorneoPalm", rmRandInt(9,14), rmRandFloat(14.0,20.0));
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.6));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidSocket);
//	  	rmAddObjectDefConstraint(mapTrees, circleConstraint);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees, avoidPlateau);	
		rmAddObjectDefConstraint(mapTrees, avoidWaterShort);	
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 50*cNumberNonGaiaPlayers);
	//}



		rmSetStatusText("",0.9);


	//fish and their constraints placed together at the end for ease of removal
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "ypFishCarp", 3.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 3.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 50.0);
//	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 15.0);

	int fishID=rmCreateObjectDef("fish Mahi");
	rmAddObjectDefItem(fishID, "ypFishCarp", 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 12*cNumberNonGaiaPlayers);
/*
	int fish2ID=rmCreateObjectDef("fish Tarpon");
	rmAddObjectDefItem(fish2ID, "FishTarpon", 1, 0.0);
	rmSetObjectDefMinDistance(fish2ID, 0.0);
	rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fish2ID, fishVsFishID);
	rmAddObjectDefConstraint(fish2ID, fishLand);
	rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);
*/
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
//	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);
	
	rmSetStatusText("",0.99);

  // King of the Hill (added 2026-11 for WoL): centre, on the river bank between the two sides
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
 
