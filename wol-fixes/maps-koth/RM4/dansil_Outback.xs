/*
==============================
		Outback
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
	int playerTiles=16000;
	if (cNumberNonGaiaPlayers > 4){
		playerTiles = 15400;
	}else if (cNumberNonGaiaPlayers > 6){
		playerTiles = 14000;
	}
	
	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmSetMapSize(size, size);

	if (cNumberTeams >= 3){
	size = 2.4 * sqrt(cNumberNonGaiaPlayers*playerTiles);
}


	rmSetMapType("land");
        rmSetMapType("grass");
        rmSetMapType("australia");
       	rmTerrainInitialize("grass");
		rmSetLightingSet("307a_beach");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
	rmSetSeaLevel(2.0);
		rmSetSeaType("yucatan Coast");


		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 5.0);

        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.46), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 12.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 50.0);
		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 50.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "mineopal", 10.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "mineopal", 55.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 16.0);
        int cliffWater = rmCreateTerrainDistanceConstraint("cliff avoids river", "Land", false, 8.0);
        int cliffWater2 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 10.0);
        int cliffWater3 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 12.5);


        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 6.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 30.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 40.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 60.0);

int stayWest = rmCreatePieConstraint("Stay West",0.47,0.53, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(225),rmDegreesToRadians(45));
int stayEast = rmCreatePieConstraint("Stay East",0.53,0.47, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(45),rmDegreesToRadians(225));

   

	int PlayerNum = cNumberNonGaiaPlayers;

    
 // =============Player placement ======================= 
    float spawnSwitch = rmRandFloat(0,1.2);


	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){

	if (PlayerNum == 2)
	{
	rmPlacePlayer(1, 0.15, 0.6);
	rmPlacePlayer(2, 0.85, 0.6);	}

			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.75, 0.85);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.15, 0.25);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
		rmPlacePlayer(2, 0.15, 0.6);
		rmPlacePlayer(1, 0.85, 0.6);
	}

			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.75, 0.85);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.15, 0.25);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);

		}
	}else{
	//*************ffa placement********
		rmSetPlacementSection(0.75, 0.25);
		rmPlacePlayersCircular(0.31, 0.31, 0.02);
	}

		
	chooseMercs();
wotta_triggers();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	   rmSetAreaMix(continent2, "ausforest_transition");
        rmSetAreaBaseHeight(continent2, 1.0);
        rmSetAreaCoherence(continent2, 1.0);
        rmSetAreaSmoothDistance(continent2, 10);
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
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 3.0);
		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
        



		rmSetStatusText("",0.2);




 
		rmSetStatusText("",0.3);
				
//===================River=====================
	//pampas river would be prettier, but yucatan water allows for water flags

	int TeamNum = cNumberTeams;
	int numPlayer = cNumberPlayers;
	string riverType = "Great Plains Pond";


	int riverID = rmRiverCreate(-5, riverType, 8, 8, 3+numPlayer/2, 4+numPlayer/2); 

  rmRiverAddWaypoint(riverID, 0.0, .27);

  rmRiverAddWaypoint(riverID, 0.5, .33);

  rmRiverAddWaypoint(riverID, 1.0, 0.27);

	rmRiverSetShallowRadius(riverID, 9);

		rmRiverAddShallow(riverID, 0.2);
		rmRiverAddShallow(riverID, 0.8);
		rmRiverAddShallow(riverID, 0.5);

	rmRiverBuild(riverID);
	rmRiverReveal(riverID, 2);

//====================================================

//============river inner cliff=======================

        int cliffNE = rmCreateArea("cliffNE");
        rmSetAreaSize(cliffNE, 0.4, 0.4);
        rmSetAreaLocation(cliffNE, 0.5, 0.1);		//rmAddAreaToClass(cliffNE, rmClassID("classPlateau"));
        rmSetAreaBaseHeight(cliffNE, 0.0);
        rmSetAreaCoherence(cliffNE, 1.0);
        rmSetAreaHeightBlend(cliffNE, 1);
		rmAddAreaConstraint(cliffNE, cliffWater);
		rmSetAreaCliffType(cliffNE, "Outback");
		rmSetAreaCliffEdge(cliffNE, 6, 0.1, 0.0, 0.0, 2); 
		rmSetAreaCliffPainting(cliffNE, false, false, false, 1.5, true);
		rmSetAreaCliffHeight(cliffNE, 6, 0.1, 0.5);
        rmBuildArea(cliffNE);    

//stop pesky players dropping mortars on the cliff

        int impassableLand = rmCreateArea("impassable Land");
        rmSetAreaSize(impassableLand, 0.8, 0.8);
        rmSetAreaLocation(impassableLand, 0.5, 0.6);	
 //       rmSetAreaTerrainType(impassableLand, "cave\cave_top");
        rmSetAreaCoherence(impassableLand, 1.0);
		rmSetAreaCliffType(impassableLand, "Outback");
		rmSetAreaCliffEdge(impassableLand, 10, 0.04, 0.0, 0.0, 2); 
		rmSetAreaCliffPainting(impassableLand, false, false, false, 1.5, true);
		rmSetAreaCliffHeight(impassableLand, 6, 0.1, 0.5);

		rmAddAreaConstraint(impassableLand, cliffWater);
        rmBuildArea(impassableLand);  
  


//=========================================================


// BUILD NATIVE SITES

	//Choose Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int subCiv3=-1;

//Cameleers are awesome

   if (rmAllocateSubCivs(4) == true)
   {
      subCiv0=rmGetCivID("Cameleers");
      rmEchoInfo("subCiv0 is Cameleers "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Cameleers");

		subCiv1=rmGetCivID("Cameleers");
      rmEchoInfo("subCiv1 is Cameleers"+subCiv1);
		if (subCiv1 >= 0)
			 rmSetSubCiv(1, "Cameleers");
	 
		subCiv2=rmGetCivID("Cameleers");
      rmEchoInfo("subCiv2 is Cameleers"+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Cameleers");

		subCiv3=rmGetCivID("Cameleers");
      rmEchoInfo("subCiv3 is Cameleers"+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Cameleers");
	}
	
	// Set up Natives	
	int nativeID0 = -1;
    int nativeID1 = -1;
	int nativeID2 = -1;
    int nativeID3 = -1;
		
	nativeID0 = rmCreateGrouping("native site 1", "native cameleers village 3");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 0.00);
	rmAddGroupingToClass(nativeID0, rmClassID("classPlateau"));

	nativeID1 = rmCreateGrouping("native site 2", "native cameleers village 4");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 0.00);
	rmAddGroupingToClass(nativeID1, rmClassID("classPlateau"));

//========place=====
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.25, 0.8);	rmPlaceGroupingAtLoc(nativeID0, 0, 0.75, 0.8);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.5, 0.12);
	if (PlayerNum >= 7)
{
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.5, 0.88);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.5, 0.6);
}



//===========trade route=================
//trade route not in ffa games

		int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
        rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID, true);
        rmSetObjectDefMinDistance(socketID, 0.0);
        rmSetObjectDefMaxDistance(socketID, 6.0);      
       
        int tradeRouteID = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
		rmAddTradeRouteWaypoint(tradeRouteID, .0, .36);	  
  	     rmAddTradeRouteWaypoint(tradeRouteID, .2, .43);
  	     rmAddTradeRouteWaypoint(tradeRouteID, .5, .45);
		rmAddTradeRouteWaypoint(tradeRouteID, .8, .43);
		rmAddTradeRouteWaypoint(tradeRouteID, 1.0, .36);
        rmBuildTradeRoute(tradeRouteID, "DirtAustralian");
 
        vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

	if (PlayerNum >= 6)
	{
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.1);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.9);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

   }    



		rmSetStatusText("",0.4);
		//starting objects

	int flagLand = rmCreateTerrainDistanceConstraint("flags dont like land", "land", true, 3.0);


		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
	rmAddObjectDefConstraint(playerStart, avoidWaterShort);

       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "mineopal", 1, 3.0);
        rmSetObjectDefMinDistance(goldID, 13.0);
        rmSetObjectDefMaxDistance(goldID, 14.0);
       
        int goldID2 = rmCreateObjectDef("starting gold 2");
        rmAddObjectDefItem(goldID2, "mineopal", 1, 4.0);
        rmSetObjectDefMinDistance(goldID2, 12.0);
        rmSetObjectDefMaxDistance(goldID2, 13.0);


        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "MacadamiaTree", 4, 5.0);
        rmSetObjectDefMinDistance(berryID, 12.0);
        rmSetObjectDefMaxDistance(berryID, 13.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "TreeWhiteGum", rmRandInt(3,4), 6.0);
        rmSetObjectDefMinDistance(treeID, 14.0);
        rmSetObjectDefMaxDistance(treeID, 15.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "Rabbit", 9, 7.0);
        rmSetObjectDefMinDistance(foodID, 12.0);
        rmSetObjectDefMaxDistance(foodID, 12.0);
	//rmAddObjectDefConstraint(foodID, avoidWaterShort);	
        rmSetObjectDefCreateHerd(foodID, true);
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "ReproducingWombat", 7, 8.0);
        rmSetObjectDefMinDistance(foodID2, 26.0);
        rmSetObjectDefMaxDistance(foodID2, 26.0);
	rmAddObjectDefConstraint(foodID2, avoidWaterShort);	
        rmSetObjectDefCreateHerd(foodID2, true);
                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "ReproducingWombat", 8, 8.0);
        rmSetObjectDefMinDistance(foodID3, 40.0);
        rmSetObjectDefMaxDistance(foodID3, 40.0);
	rmAddObjectDefConstraint(foodID3, avoidWaterShort);	
        rmSetObjectDefCreateHerd(foodID3, true);

	int extraberrywagon=rmCreateObjectDef("JapAn cAnT hUnT");
  rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
  rmSetObjectDefMinDistance(extraberrywagon, 6.0);
  rmSetObjectDefMaxDistance(extraberrywagon, 7.0);




		rmSetStatusText("",0.5);      
    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 1.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 1.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));


	}

	rmSetStatusText("",0.6);
	/*
	==================
	resource placement
	==================
	*/



  	int islandminesID = rmCreateObjectDef("island silver");
	rmAddObjectDefItem(islandminesID, "mineopal", 1, 1.0);
	rmSetObjectDefMinDistance(islandminesID, 0.0);
	rmSetObjectDefMaxDistance(islandminesID, rmXFractionToMeters(0.44));
	rmAddObjectDefConstraint(islandminesID, avoidCoinMed);
	rmAddObjectDefConstraint(islandminesID, avoidTownCenterMore);
	rmAddObjectDefConstraint(islandminesID, circleConstraint);
	rmAddObjectDefConstraint(islandminesID, avoidPlateau);	
	rmAddObjectDefConstraint(islandminesID, avoidWaterShort);
	rmAddObjectDefConstraint(islandminesID, forestConstraintShort);
	rmAddObjectDefConstraint(islandminesID, avoidTradeRouteSmall);
	rmPlaceObjectDefAtLoc(islandminesID, 0, 0.5, 0.5, 7*cNumberNonGaiaPlayers);


	
    int birdHunts = rmCreateObjectDef("birdHunts");
	rmAddObjectDefItem(birdHunts, "ReproducingEmu", rmRandInt(6,7), 14.0);
	rmSetObjectDefCreateHerd(birdHunts, true);
	rmSetObjectDefMinDistance(birdHunts, 0);
	rmSetObjectDefMaxDistance(birdHunts, rmXFractionToMeters(0.5));
//	rmAddObjectDefConstraint(birdHunts, circleConstraint);
	rmAddObjectDefConstraint(birdHunts, avoidTownCenterMore);
	rmAddObjectDefConstraint(birdHunts, avoidHunt);		rmAddObjectDefConstraint(birdHunts, avoidWaterShort);
	rmAddObjectDefConstraint(birdHunts, avoidPlateau);
	rmAddObjectDefConstraint(birdHunts, avoidSocket);	
	rmAddObjectDefConstraint(birdHunts, avoidCoin);	
	rmPlaceObjectDefAtLoc(birdHunts, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);

// llamas not in FFA
	if (cNumberTeams == 2){
  	int LlamaTime = rmCreateObjectDef("TINA");
	rmAddObjectDefItem(LlamaTime, "Sheep", , 4.0);
	rmSetObjectDefMinDistance(LlamaTime, 0.0);
	rmSetObjectDefMaxDistance(LlamaTime, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(LlamaTime, avoidHerd);
	rmAddObjectDefConstraint(LlamaTime, avoidPlateau);	
	rmAddObjectDefConstraint(LlamaTime, circleConstraint);
	rmAddObjectDefConstraint(LlamaTime, avoidTownCenterMore);
	rmAddObjectDefConstraint(LlamaTime, avoidWaterShort);

//avoidWaterShort
	rmPlaceObjectDefAtLoc(LlamaTime, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);
}

	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
	rmSetObjectDefMinDistance(nuggetID, 0.0); 
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.5)); 
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
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);   
	rmSetStatusText("",0.7);

	//removes loop for faster loading times
	//for (j=0; < (6*cNumberNonGaiaPlayers)) {   
		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "TreeWhiteGum", rmRandInt(5,6), rmRandFloat(17.0,20.0));
        	rmAddObjectDefItem(mapTrees, "TreeXanthorrhoea", rmRandInt(2,3), 18.0);
        	rmAddObjectDefItem(mapTrees, "TreeWattle", rmRandInt(2,3), 18.0);
        	rmAddObjectDefItem(mapTrees, "ypTreeEucalyptus", rmRandInt(6,7), 18.0);
        	rmAddObjectDefItem(mapTrees, "MacadamiaTree", rmRandInt(1,1), 3.0);
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidSocket);
	  	rmAddObjectDefConstraint(mapTrees, avoidCoin);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees, avoidPlateau);	
		rmAddObjectDefConstraint(mapTrees, avoidWaterShort);
	rmAddObjectDefConstraint(mapTrees, circleConstraint);
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 35*cNumberNonGaiaPlayers);
	//}
		rmSetStatusText("",0.8);
		int bonusTrees=rmCreateObjectDef("bonusTrees");
		rmAddObjectDefItem(bonusTrees, "BushTomato", rmRandInt(1,1), rmRandFloat(4.0,6.0));
	rmAddObjectDefItem(bonusTrees, "SilverFern", rmRandInt(1,1), 7.0);
	  	rmAddObjectDefConstraint(bonusTrees, circleConstraint);
		rmAddObjectDefConstraint(bonusTrees, forestConstraintShort);
	rmAddObjectDefConstraint(bonusTrees, avoidTownCenter);

//		rmAddObjectDefConstraint(bonusTrees, avoidWaterShort);	
	rmPlaceObjectDefInArea(bonusTrees, 0, continent2 , 18*cNumberNonGaiaPlayers);


	rmSetStatusText("",0.9);

  // King of the Hill (added 2026-11 for WoL): the middle of all start positions (the map centre), on open land
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
    // (0.025 of the map side per step), with the include's placer constraints, 40 m from every Town Center
    // and 10 m from every tree
    int kothAvoidLand = rmCreateTerrainDistanceConstraint("koth hill avoids impassable land", "Land", false, 6.0);
    int kothAvoidAll = rmCreateTypeDistanceConstraint("koth hill avoids all", "all", 4.0);
    int kothAvoidTC = rmCreateTypeDistanceConstraint("koth hill avoids TCs", "TownCenter", 40.0);
    int kothAvoidTrees = rmCreateTypeDistanceConstraint("koth hill avoids trees", "Tree", 10.0);
    int kothAvoidTreesNear = rmCreateTypeDistanceConstraint("koth hill avoids trees near", "Tree", 5.0);
    int kothAvoidSocket = rmCreateTypeDistanceConstraint("koth hill avoids trade sockets", "socketTradeRoute", 6.0);
    int kothAvoidRoute = rmCreateTradeRouteDistanceConstraint("koth hill avoids trade route", 6.0);
    int kothAvoidFlag = rmCreateTypeDistanceConstraint("koth hill avoids water flags", "HomeCityWaterSpawnFlag", 4.0);
    int kothDone = 0;
    float kothDist = 0.0;
    for (kothRound = 0; < 41) {
      int kothHill = rmCreateObjectDef("koth hill " + kothRound);
      rmAddObjectDefItem(kothHill, "ypKingsHill", 1, 0);
      rmSetObjectDefMinDistance(kothHill, 0.0);
      rmSetObjectDefMaxDistance(kothHill, rmXFractionToMeters(0.025));
      rmAddObjectDefConstraint(kothHill, kothAvoidLand);
      rmAddObjectDefConstraint(kothHill, kothAvoidAll);
      rmAddObjectDefConstraint(kothHill, kothAvoidTC);
      rmAddObjectDefConstraint(kothHill, kothAvoidTrees);
      rmAddObjectDefConstraint(kothHill, kothAvoidSocket);
      rmAddObjectDefConstraint(kothHill, kothAvoidRoute);
      rmAddObjectDefConstraint(kothHill, kothAvoidFlag);
      rmPlaceObjectDefAtLoc(kothHill, 0, kothX + kothDirX * kothDist, kothZ + kothDirZ * kothDist, 1);
      if (rmGetNumberUnitsPlaced(kothHill) > 0) {
        kothDone = 1;
        break;
      }
      // 0, +1, -1, +2, -2, ... steps
      if (kothDist > 0.0)
        kothDist = 0.0 - kothDist;
      else
        kothDist = 0.025 - kothDist;
    }
    // no room on that line: the open land nearest to the middle, trees allowed closer (5 m)
    if (kothDone == 0) {
      float kothRadius = 0.04;
      for (kothNear = 0; < 8) {
        int kothHillNear = rmCreateObjectDef("koth hill near " + kothNear);
        rmAddObjectDefItem(kothHillNear, "ypKingsHill", 1, 0);
        rmSetObjectDefMinDistance(kothHillNear, 0.0);
        rmSetObjectDefMaxDistance(kothHillNear, rmXFractionToMeters(kothRadius));
        rmAddObjectDefConstraint(kothHillNear, kothAvoidLand);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidAll);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidTC);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidTreesNear);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidSocket);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidRoute);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidFlag);
        rmPlaceObjectDefAtLoc(kothHillNear, 0, kothX, kothZ, 1);
        if (rmGetNumberUnitsPlaced(kothHillNear) > 0)
          break;
        kothRadius = kothRadius * 1.5;
      }
    }
  }

	}
 
