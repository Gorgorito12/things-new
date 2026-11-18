/*
==============================
		Nahanni
         by dansil92
==============================
*/
include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
include "triggers\triggerLoader.xs";

void main(void) {
	rmSetStatusText("",0.01);
   // Picks the map size
	int playerTiles=13000;
	if (cNumberNonGaiaPlayers > 4){
		playerTiles = 12000;
	}else if (cNumberNonGaiaPlayers > 6){
		playerTiles = 11000;
	}



	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);

	if (cNumberTeams >= 3){
	size = 2.5 * sqrt(cNumberNonGaiaPlayers*playerTiles);
}

	rmSetMapSize(size, size);

	rmSetMapType("land");
        rmSetMapType("grass");
	rmSetMapType("california");
       	rmTerrainInitialize("grass");

 	  rmSetGlobalRain( 0.6 );

		rmSetLightingSet("spccc5balt");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
	rmSetSeaLevel(-5.0);
		rmSetSeaType("yucatan Coast");


		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 16.0);

		int avoidPlateauSmall=rmCreateClassDistanceConstraint("stuff vs. cliffs s", rmClassID("classPlateau"), 7.0);


        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.46), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 27.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 60.0);

		int avoidHuntSmall=rmCreateTypeDistanceConstraint("hunts avoid hunts small", "huntable", 30.0);


		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 24.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 10.0);
		int avoidGold=rmCreateTypeDistanceConstraint("avoid coin gold", "mineGold", 16.0);

		int waterCoin=rmCreateTypeDistanceConstraint("avoid coin smallest", "Mine", 8.0);


        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "Mine", 55.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 19.0);
        int cliffWater = rmCreateTerrainDistanceConstraint("cliff avoids river", "Land", false, 0.01);
        int cliffWater2 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 1.5);
        int cliffWater3 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 2.5);


        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 9.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 30.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 60.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 60.0);

  int avoidBerries=rmCreateTypeDistanceConstraint("avoid berries", "berrybush", 20.0);
  int avoidBerriesSmall=rmCreateTypeDistanceConstraint("avoid berries smoll", "berrybush", 8.0);


int stayWest = rmCreatePieConstraint("Stay West",0.47,0.53, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(180),rmDegreesToRadians(0));

int stayEast = rmCreatePieConstraint("Stay East",0.53,0.47, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(180));

   

	int PlayerNum = cNumberNonGaiaPlayers;
	int TeamNum = cNumberTeams;
	int numPlayer = cNumberPlayers;


    
 // =============Player placement ======================= 
    float spawnSwitch = rmRandFloat(0,1.2);
spawnSwitch = 0.1;


	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){

	if (PlayerNum == 2)
	{
	rmPlacePlayer(1, 0.25, 0.75);
	rmPlacePlayer(2, 0.75, 0.22);	}

			rmSetPlacementTeam(0);
		rmSetPlayerPlacementArea(0.1, 0.6, 0.4, 0.9);
			rmPlacePlayersCircular(0.3, 0.3, 0.0);
			rmSetPlacementTeam(1);
		rmSetPlayerPlacementArea(0.6, 0.1, 0.9, 0.4);
			rmPlacePlayersCircular(0.3, 0.3, 0.0);

		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
		rmPlacePlayer(2, 0.25, 0.75);
		rmPlacePlayer(1, 0.75, 0.25);
	}

			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.65, 0.9);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.15, 0.4);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);

		}
	}else{
	//*************ffa placement********
		rmPlacePlayersCircular(0.42, 0.42, 0.00);
	}

		
	chooseMercs();
wotta_triggers();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	   rmSetAreaMix(continent2, "nwt_grass1");
        rmSetAreaBaseHeight(continent2, -5.0);
        rmSetAreaCoherence(continent2, 1.0);
        rmSetAreaSmoothDistance(continent2, 6);
        rmSetAreaHeightBlend(continent2, 1);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 10);
        rmSetAreaElevationVariation(continent2, 4);
        rmSetAreaElevationPersistence(continent2, .2);
        rmSetAreaElevationOctaves(continent2, 5);
        rmSetAreaElevationMinFrequency(continent2, 0.04);
        rmSetAreaElevationType(continent2, cElevTurbulence);  
        rmBuildArea(continent2);    

		int classPatch = rmDefineClass("patch");
		int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 22.0);
		int classCenter = rmDefineClass("center");
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 27.0);
		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
        



		rmSetStatusText("",0.2);

		int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
        rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID, true);
        rmSetObjectDefMinDistance(socketID, 0.0);
        rmSetObjectDefMaxDistance(socketID, 6.0);      


/*
=============================
	two team spawn
=============================
*/


	if (cNumberTeams == 2){

		int cliffs = rmCreateArea("cliffs west");
		rmSetAreaSize(cliffs, 0.17, 0.17); 
		rmAddAreaToClass(cliffs, rmClassID("center"));
		rmSetAreaCliffType(cliffs, "patagonia");
//        rmSetAreaHeightBlend(cliffs, 1);
		rmSetAreaCliffEdge(cliffs, 1, 1.0, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(cliffs, false, true, true, 0.4, true);
		rmSetAreaCliffHeight(cliffs, 8, 0.1, 0.5);
		rmSetAreaCoherence(cliffs, .92);
		rmSetAreaLocation(cliffs, .2, .8);	
		rmBuildArea(cliffs);


		int cliffs2 = rmCreateArea("cliffs east");
		rmSetAreaSize(cliffs2, 0.17, 0.17); 
		rmAddAreaToClass(cliffs2, rmClassID("center"));
		rmSetAreaCliffType(cliffs2, "patagonia");
//        rmSetAreaHeightBlend(cliffs2, 1);
		rmSetAreaCliffEdge(cliffs2, 1, 1.0, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(cliffs2, false, true, true, 0.4, true);
		rmSetAreaCliffHeight(cliffs2, 8, 0.1, 0.5);
		rmSetAreaCoherence(cliffs2, .92);
		rmSetAreaLocation(cliffs2, .8, .2);	
		rmBuildArea(cliffs2);


		int glacierN = rmCreateArea("cliffs north");
		rmSetAreaSize(glacierN, 0.07, 0.07); 
		rmAddAreaToClass(glacierN, rmClassID("classPlateau"));
	rmAddAreaToClass(glacierN, rmClassID("center"));
		rmSetAreaCliffType(glacierN, "patagonia");
		rmSetAreaCliffEdge(glacierN, 1, 1.0, 0.5, 0.5, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(glacierN, true, true, true, 0.4, true);
		rmSetAreaCliffHeight(glacierN, 9, 0.1, 0.0);
		rmSetAreaCoherence(glacierN, .93);
		rmSetAreaLocation(glacierN, .85, .85);	
        rmAddAreaInfluenceSegment(glacierN, 0.95, 0.85, 0.85, 0.95);
		rmBuildArea(glacierN);

		int glacierS = rmCreateArea("cliffs south");
		rmSetAreaSize(glacierS, 0.07, 0.07); 
	rmAddAreaToClass(glacierS, rmClassID("classPlateau"));
	rmAddAreaToClass(glacierS, rmClassID("center"));
		rmSetAreaCliffType(glacierS, "patagonia");
        rmSetAreaHeightBlend(glacierS, 4);
		rmSetAreaCliffEdge(glacierS, 1, 1.0, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(glacierS, true, true, true, 0.4, true);
		rmSetAreaCliffHeight(glacierS, 7, 0.1, 0.5);
		rmSetAreaCoherence(glacierS, .93);
		rmSetAreaLocation(glacierS, .15, .15);	
        rmAddAreaInfluenceSegment(glacierS, 0.05, 0.15, 0.15, 0.05);
		rmBuildArea(glacierS);


		int glacierBaseNW = rmCreateArea("flatland northwest");
		rmSetAreaSize(glacierBaseNW, 0.1, 0.1); 
		rmSetAreaCoherence(glacierBaseNW, .92);
		rmSetAreaLocation(glacierBaseNW, .5, .9);	
	rmAddAreaConstraint(glacierBaseNW, avoidPlateau);
	rmAddAreaToClass(glacierBaseNW, rmClassID("center"));
	   rmSetAreaMix(glacierBaseNW, "nwt_grass1");
        rmSetAreaSmoothDistance(glacierBaseNW, 25);
        rmSetAreaHeightBlend(glacierBaseNW, 2);
	rmAddAreaTerrainReplacement(glacierBaseNW, "patagonia\ground_clifftop_pat", "nwterritory\ground_grass1_nwt");
	rmAddAreaTerrainReplacement(glacierBaseNW, "patagonia\ground_dirt3_pat", "nwterritory\ground_grass1_nwt");
        rmSetAreaBaseHeight(glacierBaseNW, 1.5);
        rmAddAreaInfluenceSegment(glacierBaseNW, 0.15, 0.9, 0.85, 0.9);
		rmBuildArea(glacierBaseNW);


		int glacierBaseNE = rmCreateArea("flatland northeast");
		rmSetAreaSize(glacierBaseNE, 0.1, 0.1); 
		rmSetAreaCoherence(glacierBaseNE, .92);
		rmSetAreaLocation(glacierBaseNE, .9, .5);	
	rmAddAreaConstraint(glacierBaseNE, avoidPlateau);
	rmAddAreaToClass(glacierBaseNE, rmClassID("center"));
	   rmSetAreaMix(glacierBaseNE, "nwt_grass1");
        rmSetAreaSmoothDistance(glacierBaseNE, 25);
        rmSetAreaHeightBlend(glacierBaseNE, 2);
	rmAddAreaTerrainReplacement(glacierBaseNE, "patagonia\ground_clifftop_pat", "nwterritory\ground_grass1_nwt");
	rmAddAreaTerrainReplacement(glacierBaseNE, "patagonia\ground_dirt3_pat", "nwterritory\ground_grass1_nwt");
       rmSetAreaBaseHeight(glacierBaseNE, 1.5);
        rmAddAreaInfluenceSegment(glacierBaseNE, 0.9, 0.15, 0.9, 0.85);
		rmBuildArea(glacierBaseNE);


		int glacierBaseSW = rmCreateArea("flatland southwest");
		rmSetAreaSize(glacierBaseSW, 0.1, 0.1); 
		rmSetAreaCoherence(glacierBaseSW, .92);
		rmSetAreaLocation(glacierBaseSW, .1, .5);	
	rmAddAreaConstraint(glacierBaseSW, avoidPlateau);
	rmAddAreaToClass(glacierBaseSW, rmClassID("center"));
	   rmSetAreaMix(glacierBaseSW, "nwt_grass1");
        rmSetAreaSmoothDistance(glacierBaseSW, 25);
        rmSetAreaHeightBlend(glacierBaseSW, 2);
	rmAddAreaTerrainReplacement(glacierBaseSW, "patagonia\ground_clifftop_pat", "nwterritory\ground_grass1_nwt");
	rmAddAreaTerrainReplacement(glacierBaseSW, "patagonia\ground_dirt3_pat", "nwterritory\ground_grass1_nwt");
        rmSetAreaBaseHeight(glacierBaseSW, 1.5);
        rmAddAreaInfluenceSegment(glacierBaseSW, 0.1, 0.15, 0.1, 0.85);
		rmBuildArea(glacierBaseSW);


		int glacierBaseSE = rmCreateArea("flatland southeast");
		rmSetAreaSize(glacierBaseSE, 0.1, 0.1); 
		rmSetAreaCoherence(glacierBaseSE, .92);
		rmSetAreaLocation(glacierBaseSE, .5, .1);	
	rmAddAreaConstraint(glacierBaseSE, avoidPlateau);
	rmAddAreaToClass(glacierBaseSE, rmClassID("center"));
	   rmSetAreaMix(glacierBaseSE, "nwt_grass1");
        rmSetAreaSmoothDistance(glacierBaseSE, 25);
        rmSetAreaHeightBlend(glacierBaseSE, 2);
	rmAddAreaTerrainReplacement(glacierBaseSE, "patagonia\ground_clifftop_pat", "nwterritory\ground_grass1_nwt");
	rmAddAreaTerrainReplacement(glacierBaseSE, "patagonia\ground_dirt3_pat", "nwterritory\ground_grass1_nwt");
        rmSetAreaBaseHeight(glacierBaseSE, 1.5);
        rmAddAreaInfluenceSegment(glacierBaseSE, 0.15, 0.1, 0.85, 0.1);
		rmBuildArea(glacierBaseSE);



	//build trade routes

//trade route (south)

       
        int tradeRouteID = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
		rmAddTradeRouteWaypoint(tradeRouteID, .0, .45);
		rmAddTradeRouteWaypoint(tradeRouteID, .2, .45);
		rmAddTradeRouteWaypoint(tradeRouteID, .45, .2);
		rmAddTradeRouteWaypoint(tradeRouteID, .45, .0);
        rmBuildTradeRoute(tradeRouteID, "dirt");
 
        vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.12);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.88);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);



		
		//trade route(north)

		int socketID2=rmCreateObjectDef("sockets to dock Trade Posts2");
        rmAddObjectDefItem(socketID2, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID2, true);
        rmSetObjectDefMinDistance(socketID2, 0.0);
        rmSetObjectDefMaxDistance(socketID2, 6.0);      
       
        int tradeRouteID2 = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID2, tradeRouteID2);
		rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, .55);
		rmAddTradeRouteWaypoint(tradeRouteID2, .8, .55);
		rmAddTradeRouteWaypoint(tradeRouteID2, .55, .8);
		rmAddTradeRouteWaypoint(tradeRouteID2, .55, 1.0);

        rmBuildTradeRoute(tradeRouteID2, "dirt");
 
		vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.12);
        rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);       
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.88);
        rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);



}




		rmSetStatusText("",0.3);

	if (cNumberTeams >= 3){

		int center = rmCreateArea("center");
		rmAddAreaToClass(center, rmClassID("patch"));
        rmSetAreaSize(center, .11, .18);
        rmSetAreaLocation(center, 0.5, 0.5);
        rmSetAreaCoherence(center, 1.0);
        rmBuildArea(center);   



for(i=1; < cNumberNonGaiaPlayers + 1) {

    int PlayerArea1 = rmCreateArea("NeedLand1"+i);
        rmSetAreaSize(PlayerArea1, rmAreaTilesToFraction(2600), rmAreaTilesToFraction(2600));
		rmAddAreaToClass(PlayerArea1, rmClassID("classPlateau"));
		rmAddAreaToClass(PlayerArea1, rmClassID("center"));
       rmSetAreaHeightBlend(PlayerArea1, 2);
        rmSetAreaLocation(PlayerArea1, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmSetAreaCoherence(PlayerArea1, 0.85);
        rmBuildArea(PlayerArea1);

}

//ffa circular TP

        tradeRouteID = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
      rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.65);
       rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.7);
     rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.65);
       rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.5);
	  rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.35);
       rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.3);
	  rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.35);
       rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.5);
	  rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.65);
        rmBuildTradeRoute(tradeRouteID, "dirt");

	vector socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID, 0.2);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc3 );
	socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID, 0.45);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc3 );
	socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID, 0.7);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc3 );
	socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID, 0.95);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc3 );



//==========hills==============

	for (j=0; < (9*cNumberNonGaiaPlayers)) {   
			int ffaCliffs = rmCreateArea("ffaCliffs"+j);
        rmSetAreaSize(ffaCliffs, rmAreaTilesToFraction(300), rmAreaTilesToFraction(400));
		rmAddAreaToClass(ffaCliffs, rmClassID("classPlateau"));
		rmAddAreaToClass(ffaCliffs, rmClassID("center"));
		rmSetAreaCliffType(ffaCliffs, "patagonia");
		rmSetAreaCliffEdge(ffaCliffs, 1, 1, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(ffaCliffs, true, true, true, 1.5, true);
		rmSetAreaCliffHeight(ffaCliffs, 8, 1, 0.5);
	rmAddAreaConstraint(ffaCliffs, avoidCenter);
	rmAddAreaConstraint(ffaCliffs, avoidPlateau);
	rmAddAreaConstraint(ffaCliffs, avoidPatch);
	rmAddAreaConstraint(ffaCliffs, avoidTradeRouteSmall);


//avoidPatch
        rmSetAreaCoherence(ffaCliffs, .89);

        rmBuildArea(ffaCliffs);  
	}




}



	if (PlayerNum == 2)
{
//=========2 player fixed mines============

  	int smollMines = rmCreateObjectDef("competitive gold");
	rmAddObjectDefItem(smollMines, "mineGold", 1, 1.0);
	rmSetObjectDefMinDistance(smollMines, 0.0);
	rmSetObjectDefMaxDistance(smollMines, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.15, 0.4, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.4, 0.15, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.48, 0.83, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.83, 0.48, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.5, 0.5, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.93, 0.93, 1);


  	int smollMines2 = rmCreateObjectDef("second mine");
	rmAddObjectDefItem(smollMines2, "mine", 1, 1.0);
	rmPlaceObjectDefAtLoc(smollMines2, 0, 0.12, 0.65, 1);
	rmPlaceObjectDefAtLoc(smollMines2, 0, 0.65, 0.12, 1);


}






//==========ponds==============

 int pondNumber = 4;

	if (PlayerNum >= 3){
	pondNumber = 4*cNumberNonGaiaPlayers;
}
	for (j=0; < (pondNumber)) { 
  
			int islandW = rmCreateArea("islandW"+j);
        rmSetAreaSize(islandW, rmAreaTilesToFraction(130), rmAreaTilesToFraction(260));
		rmAddAreaToClass(islandW, rmClassID("classPlateau"));
        rmSetAreaWaterType(islandW, "Northwest Territory Water");
        rmSetAreaBaseHeight(islandW, -5);
        rmSetAreaCoherence(islandW, .85);
        rmSetAreaHeightBlend(islandW, 1);
        rmSetAreaSmoothDistance(islandW, 3);
	rmAddAreaConstraint(islandW, avoidPlateau);
	rmAddAreaConstraint(islandW, avoidCenter);
	rmAddAreaConstraint(islandW, avoidGold);
	rmAddAreaConstraint(islandW, avoidTradeRouteSmall);
	if (PlayerNum == 2){

if (j == 0){
		rmSetAreaLocation(islandW, .65, .55);	
}
if (j == 1){
		rmSetAreaLocation(islandW, .35, .45);	
}

}

        rmBuildArea(islandW);  
	}




 
				


		rmSetStatusText("",0.4);
		//starting objects

		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
	rmAddObjectDefConstraint(playerStart, avoidWaterShort);

       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "mine", 1, 3.0);
        rmSetObjectDefMinDistance(goldID, 16.0);
        rmSetObjectDefMaxDistance(goldID, 16.0);
        rmAddObjectDefConstraint(goldID, avoidCoinMed);



        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "BerryBush", 5, 4.0);
        rmSetObjectDefMinDistance(berryID, 16.0);
        rmSetObjectDefMaxDistance(berryID, 17.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "TreeNorthwestTerritory", rmRandInt(6,7), 7.0);
        rmSetObjectDefMinDistance(treeID, 19.0);
        rmSetObjectDefMaxDistance(treeID, 21.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "caribou", 8, 8.0);
        rmSetObjectDefMinDistance(foodID, 10.0);
        rmSetObjectDefMaxDistance(foodID, 10.0);
	rmAddObjectDefConstraint(foodID, avoidWaterShort);	
        rmSetObjectDefCreateHerd(foodID, true);
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "moose", 7, 8.0);
        rmSetObjectDefMinDistance(foodID2, 35.0);
        rmSetObjectDefMaxDistance(foodID2, 35.0);
        rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, avoidWaterShort);	
	rmAddObjectDefConstraint(foodID2, circleConstraint);


                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "caribou", 8, 8.0);
        rmSetObjectDefMinDistance(foodID3, 59.0);
        rmSetObjectDefMaxDistance(foodID3, 59.0);
	rmAddObjectDefConstraint(foodID3, avoidWaterShort);	
	rmAddObjectDefConstraint(foodID3, circleConstraint);
        rmSetObjectDefCreateHerd(foodID3, true);

	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmSetNuggetDifficulty(1, 1); 
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 3.0);
    rmSetObjectDefMinDistance(playerNuggetID, 28.0);
    rmSetObjectDefMaxDistance(playerNuggetID, 35.0);
	rmAddObjectDefConstraint(playerNuggetID, circleConstraint);



		rmSetStatusText("",0.5);  
    
    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 3.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 3.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(berryID , i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerNuggetID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

	}

	rmSetStatusText("",0.6);
	/*
	==================
	resource placement
	==================
	*/


	if (PlayerNum >= 3)
{
  	int eastmine = rmCreateObjectDef("east mines");
	rmAddObjectDefItem(eastmine, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(eastmine, rmXFractionToMeters(0.0));
	rmSetObjectDefMaxDistance(eastmine, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(eastmine, avoidCoinMed);
	rmAddObjectDefConstraint(eastmine, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(eastmine, avoidWaterShort);
	rmAddObjectDefConstraint(eastmine, avoidTownCenterMore);
//rmAddObjectDefConstraint(eastmine, stayEast);
	rmAddObjectDefConstraint(eastmine, circleConstraint);

	if (cNumberTeams == 2){
	rmAddObjectDefConstraint(eastmine, avoidPlateau);	
}else{
	rmAddObjectDefConstraint(eastmine, avoidPlateauSmall);	
}
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);
}
	
    int mooseHunts = rmCreateObjectDef("mooseHunts");
	rmAddObjectDefItem(mooseHunts, "moose", rmRandInt(3,3), 7.0);
	rmSetObjectDefCreateHerd(mooseHunts, true);
	rmSetObjectDefMinDistance(mooseHunts, 0);
	rmSetObjectDefMaxDistance(mooseHunts, rmXFractionToMeters(0.43));
	rmAddObjectDefConstraint(mooseHunts, circleConstraint);
	rmAddObjectDefConstraint(mooseHunts, avoidTownCenterMore);
	rmAddObjectDefConstraint(mooseHunts, avoidHuntSmall);		rmAddObjectDefConstraint(mooseHunts, avoidCenter);
	rmAddObjectDefConstraint(mooseHunts, waterHunt);	
	rmAddObjectDefConstraint(mooseHunts, avoidCoin);	
	rmPlaceObjectDefAtLoc(mooseHunts, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);


    int elkHunts = rmCreateObjectDef("elkHunts");
	rmAddObjectDefItem(elkHunts, "elk", rmRandInt(7,7), 12.0);
	rmSetObjectDefCreateHerd(elkHunts, true);
	rmSetObjectDefMinDistance(elkHunts, 0);
	rmSetObjectDefMaxDistance(elkHunts, rmXFractionToMeters(0.43));
	rmAddObjectDefConstraint(elkHunts, circleConstraint);
	rmAddObjectDefConstraint(elkHunts, avoidTownCenterMore);
	rmAddObjectDefConstraint(elkHunts, avoidHunt);		rmAddObjectDefConstraint(elkHunts, avoidBerries);
	rmAddObjectDefConstraint(elkHunts, avoidPlateau);
	rmAddObjectDefConstraint(elkHunts, avoidWaterShort);	
	rmAddObjectDefConstraint(elkHunts, avoidCoin);	
	rmPlaceObjectDefAtLoc(elkHunts, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);




	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
	rmSetObjectDefMinDistance(nuggetID, 0.0); 
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.5)); 
	rmAddObjectDefConstraint(nuggetID, avoidNugget); 
	rmAddObjectDefConstraint(nuggetID, circleConstraint);
	rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetID, forestConstraintShort);
	rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(nuggetID, avoidTownCenterMore); 
	rmAddObjectDefConstraint(nuggetID, avoidPlateau);
	rmAddObjectDefConstraint(nuggetID, avoidWaterShort);	
	rmAddObjectDefConstraint(nuggetID, avoidCoin);	
	rmSetNuggetDifficulty(2, 3); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);   
	rmSetStatusText("",0.7);

	//removes loop for faster loading times
	//for (j=0; < (6*cNumberNonGaiaPlayers)) {   
		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "TreeNorthwestTerritory", rmRandInt(14,16), rmRandFloat(11.0,12.0));
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.47));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidGold);
	  	rmAddObjectDefConstraint(mapTrees, avoidCoin);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenterSmall);	
		rmAddObjectDefConstraint(mapTrees, avoidPlateau);	
//		rmAddObjectDefConstraint(mapTrees, avoidWaterShort);
	rmAddObjectDefConstraint(mapTrees, circleConstraint);
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 45*cNumberNonGaiaPlayers);
	//}
		rmSetStatusText("",0.8);
		int marshPlants=rmCreateObjectDef("marshPlants");
		rmAddObjectDefItem(marshPlants, "RiverPropsNWTerritory", rmRandInt(4,5), rmRandFloat(8.0,9.0));
//		rmAddObjectDefConstraint(marshPlants, forestConstraint);
		rmSetObjectDefMinDistance(marshPlants, 0);
		rmSetObjectDefMaxDistance(marshPlants, rmXFractionToMeters(0.47));
		rmAddObjectDefConstraint(marshPlants, waterHunt);
	  	rmAddObjectDefConstraint(marshPlants, avoidCoinMed);	
	  	rmAddObjectDefConstraint(marshPlants, avoidGold);	
		//rmPlaceObjectDefAtLoc(marshPlants, 0, 0.5, 0.5, 16*cNumberNonGaiaPlayers);

	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 5.0);


		int duckBoys=rmCreateObjectDef("duckBoys");
		rmAddObjectDefItem(duckBoys, "DuckFamily", rmRandInt(1,2), rmRandFloat(3.0,5.0));
		rmAddObjectDefConstraint(duckBoys, whaleLand);
		rmSetObjectDefMinDistance(duckBoys, 0);
		rmSetObjectDefMaxDistance(duckBoys, rmXFractionToMeters(0.47));
		rmPlaceObjectDefAtLoc(duckBoys, 0, 0.5, 0.5, 1*cNumberNonGaiaPlayers);



	rmSetStatusText("",0.9);

  // King of the Hill (added 2026-11 for WoL): centre, on land among the central ponds
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
 
