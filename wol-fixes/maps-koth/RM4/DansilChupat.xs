/*
==============================
		Chupat
     by Daniel Sillito
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

	rmSetMapType("land");
        rmSetMapType("grass");
        rmSetMapType("araucania");
       	rmTerrainInitialize("grass");
		rmSetLightingSet("301a_malta");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
	rmSetSeaLevel(2.0);
		rmSetSeaType("yucatan Coast");


		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 16.0);

        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.46), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 50.0);
		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 24.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 10.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "Mine", 55.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 16.0);
        int cliffWater = rmCreateTerrainDistanceConstraint("cliff avoids river", "Land", false, 0.01);
        int cliffWater2 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 1.5);
        int cliffWater3 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 2.5);


        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 8.0);
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
	rmPlacePlayer(1, 0.45, 0.85);
	rmPlacePlayer(2, 0.85, 0.45);	}

			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.8, 0.99);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.25, 0.46);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
		rmPlacePlayer(2, 0.45, 0.85);
		rmPlacePlayer(1, 0.85, 0.45);
	}

			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.8, 0.99);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.25, 0.46);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);

		}
	}else{
	//*************ffa placement********
		rmSetPlacementSection(0.25, 0.99);
		rmPlacePlayersCircular(0.35, 0.35, 0.02);
	}

		
	chooseMercs();
wotta_triggers();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	   rmSetAreaMix(continent2, "pampas_grass");
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
	string riverType = "Chubut";


	int riverID = rmRiverCreate(-5, riverType, 8, 8, 5+numPlayer/2, 5.1+numPlayer/2); 

  rmRiverAddWaypoint(riverID, 1.0, .6);
  rmRiverAddWaypoint(riverID, 0.8, .65);
  rmRiverAddWaypoint(riverID, 0.7, .6);
  rmRiverAddWaypoint(riverID, 0.7, .5);
  rmRiverAddWaypoint(riverID, 0.6, .4);
  rmRiverAddWaypoint(riverID, 0.4, .4);
  rmRiverAddWaypoint(riverID, 0.4, .6);
  rmRiverAddWaypoint(riverID, 0.5, .7);
  rmRiverAddWaypoint(riverID, 0.6, .7);
  rmRiverAddWaypoint(riverID, 0.65, .8);
  rmRiverAddWaypoint(riverID, 0.6, 1.0);

	rmRiverSetShallowRadius(riverID, 14);
	rmRiverBuild(riverID);
	rmRiverReveal(riverID, 2);

//====================================================

//============river inner cliff=======================

        int cliffNE = rmCreateArea("cliffNE");
        rmSetAreaSize(cliffNE, 0.4, 0.4);
        rmSetAreaLocation(cliffNE, 0.6, 0.6);		rmAddAreaToClass(cliffNE, rmClassID("classPlateau"));
        rmSetAreaBaseHeight(cliffNE, 0.0);
        rmSetAreaCoherence(cliffNE, 1.0);
        rmSetAreaHeightBlend(cliffNE, 1);
		rmAddAreaConstraint(cliffNE, cliffWater);
		rmSetAreaCliffType(cliffNE, "Pampas River");
		rmSetAreaCliffEdge(cliffNE, 1, 1, 0.0, 0.0, 2); 
		rmSetAreaCliffPainting(cliffNE, true, true, false, 1.5, true);
		rmSetAreaCliffHeight(cliffNE, 6, 0.1, 0.5);
        rmBuildArea(cliffNE);    

//stop pesky players dropping mortars on the cliff

        int impassableLand = rmCreateArea("impassable Land");
        rmSetAreaSize(impassableLand, 0.4, 0.4);
        rmSetAreaLocation(impassableLand, 0.6, 0.6);	
 //       rmSetAreaTerrainType(impassableLand, "cave\cave_top");
        rmSetAreaCoherence(impassableLand, 1.0);
		rmSetAreaCliffType(impassableLand, "Pampas River");
		rmSetAreaCliffEdge(impassableLand, 1, 1, 0.0, 0.0, 2); 
		rmSetAreaCliffPainting(impassableLand, true, true, false, 1.5, true);
		rmSetAreaCliffHeight(impassableLand, 3, 0.1, 0.5);

		rmAddAreaConstraint(impassableLand, cliffWater2);
        rmBuildArea(impassableLand);  
  


//=========================================================


// BUILD NATIVE SITES

	//Choose Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int subCiv3=-1;

//mapuche are awesome

   if (rmAllocateSubCivs(4) == true)
   {
      subCiv0=rmGetCivID("Mapuche");
      rmEchoInfo("subCiv0 is Mapuche "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Mapuche");

		subCiv1=rmGetCivID("Mapuche");
      rmEchoInfo("subCiv1 is Mapuche"+subCiv1);
		if (subCiv1 >= 0)
			 rmSetSubCiv(1, "Mapuche");
	 
		subCiv2=rmGetCivID("Mapuche");
      rmEchoInfo("subCiv2 is Mapuche"+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Mapuche");

		subCiv3=rmGetCivID("Mapuche");
      rmEchoInfo("subCiv3 is Mapuche"+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Mapuche");
	}
	
	// Set up Natives	
	int nativeID0 = -1;
    int nativeID1 = -1;
	int nativeID2 = -1;
    int nativeID3 = -1;
		
	nativeID0 = rmCreateGrouping("native site 1", "native mapuche village 3");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 0.00);
	rmAddGroupingToClass(nativeID0, rmClassID("classPlateau"));

	nativeID1 = rmCreateGrouping("native site 2", "native mapuche village 5");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 0.00);
	rmAddGroupingToClass(nativeID1, rmClassID("classPlateau"));

//========place=====
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.22, 0.82);	rmPlaceGroupingAtLoc(nativeID0, 0, 0.82, 0.22);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.1, 0.5);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.5, 0.1);	rmPlaceGroupingAtLoc(nativeID1, 0, 0.22, 0.22);
	if (PlayerNum >= 7)
{
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.43, 0.92);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.92, 0.43);
}



//===========trade route=================
//trade route not in ffa games

	if (cNumberTeams == 2){
		int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
        rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID, true);
        rmSetObjectDefMinDistance(socketID, 0.0);
        rmSetObjectDefMaxDistance(socketID, 6.0);      
       
        int tradeRouteID = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
		rmAddTradeRouteWaypoint(tradeRouteID, .01, .35);	    	     rmAddTradeRouteWaypoint(tradeRouteID, .21, .39);
		rmAddTradeRouteWaypoint(tradeRouteID, .32, .32);
		rmAddTradeRouteWaypoint(tradeRouteID, .39, .21);
		rmAddTradeRouteWaypoint(tradeRouteID, .35, .01);
        rmBuildTradeRoute(tradeRouteID, "dirt");
 
        vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

	if (PlayerNum >= 6)
	{
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
   }    
}


		rmSetStatusText("",0.4);
		//starting objects

	int flagLand = rmCreateTerrainDistanceConstraint("flags dont like land", "land", true, 3.0);


		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
	rmAddObjectDefConstraint(playerStart, avoidWaterShort);

       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "mine", 1, 3.0);
        rmSetObjectDefMinDistance(goldID, 10.0);
        rmSetObjectDefMaxDistance(goldID, 10.0);
       
        int goldID2 = rmCreateObjectDef("starting gold 2");
        rmAddObjectDefItem(goldID2, "mine", 1, 4.0);
        rmSetObjectDefMinDistance(goldID2, 0.0);
        rmSetObjectDefMaxDistance(goldID2, 3.0);


        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "BerryBush", 8, 6.0);
        rmSetObjectDefMinDistance(berryID, 8.0);
        rmSetObjectDefMaxDistance(berryID, 12.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "TreeAraucania", rmRandInt(6,9), 10.0);
        rmSetObjectDefMinDistance(treeID, 11.0);
        rmSetObjectDefMaxDistance(treeID, 12.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "rhea", 8, 8.0);
        rmSetObjectDefMinDistance(foodID, 10.0);
        rmSetObjectDefMaxDistance(foodID, 10.0);
	rmAddObjectDefConstraint(foodID, avoidWaterShort);	
        rmSetObjectDefCreateHerd(foodID, true);
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "guanaco", 7, 8.0);
        rmSetObjectDefMinDistance(foodID2, 26.0);
	rmAddObjectDefConstraint(foodID2, avoidWaterShort);	
        rmSetObjectDefMaxDistance(foodID2, 26.0);
        rmSetObjectDefCreateHerd(foodID2, true);
                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "guanaco", 8, 8.0);
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
		rmAddObjectDefItem(startID, "TownCenter", 1, 3.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 3.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

	if (PlayerNum == 2)
{
        rmPlaceObjectDefAtLoc(goldID2, i, rmPlayerLocXFraction(i)-40, rmPlayerLocZFraction(i)-40);
}

        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));


if (rmGetPlayerCiv(i) == rmGetCivID("Japanese")) {
        rmPlaceObjectDefAtLoc(extraberrywagon, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        }

		int waterFlag = rmCreateObjectDef("HC water flag "+i);
         rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 0.0);
         rmSetObjectDefMinDistance(waterFlag, 0);
         rmSetObjectDefMaxDistance(waterFlag, 25);
        rmAddObjectDefConstraint(waterFlag, flagLand);
         rmPlaceObjectDefAtLoc(waterFlag, i, 0.4, 0.4, 1);


	}
	rmSetStatusText("",0.6);
	/*
	==================
	resource placement
	==================
	*/



  	int eastmine = rmCreateObjectDef("east mines");
	rmAddObjectDefItem(eastmine, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(eastmine, 0.0);
	rmSetObjectDefMaxDistance(eastmine, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(eastmine, avoidCoinMed);
	rmAddObjectDefConstraint(eastmine, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(eastmine, avoidPlateau);	
	rmAddObjectDefConstraint(eastmine, avoidWaterShort);
	rmAddObjectDefConstraint(eastmine, avoidTownCenterMore);
rmAddObjectDefConstraint(eastmine, stayEast);
	rmAddObjectDefConstraint(eastmine, circleConstraint);
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
 
  	int westmine = rmCreateObjectDef("west mines");
	rmAddObjectDefItem(westmine, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(westmine, 0.0);
	rmSetObjectDefMaxDistance(westmine, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(westmine, avoidCoinMed);
	rmAddObjectDefConstraint(westmine, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(westmine, avoidPlateau);	
	rmAddObjectDefConstraint(westmine, avoidWaterShort);
	rmAddObjectDefConstraint(westmine, avoidTownCenterMore);
rmAddObjectDefConstraint(westmine, stayWest);
	rmAddObjectDefConstraint(westmine, circleConstraint);
	rmPlaceObjectDefAtLoc(westmine, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);


	
    int birdHunts = rmCreateObjectDef("birdHunts");
	rmAddObjectDefItem(birdHunts, "rhea", rmRandInt(6,7), 14.0);
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
	rmAddObjectDefItem(LlamaTime, "Llama", rmRandInt(2,2), 4.0);
	rmSetObjectDefMinDistance(LlamaTime, 0.0);
	rmSetObjectDefMaxDistance(LlamaTime, 160);
	rmAddObjectDefConstraint(LlamaTime, avoidHerd);
	rmAddObjectDefConstraint(LlamaTime, avoidPlateau);	
	rmAddObjectDefConstraint(LlamaTime, circleConstraint);
	rmPlaceObjectDefAtLoc(LlamaTime, 0, 0.14, 0.14, 2*cNumberNonGaiaPlayers);
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
		rmAddObjectDefItem(mapTrees, "TreeAraucania", rmRandInt(4,5), rmRandFloat(14.0,20.0));
        rmAddObjectDefItem(mapTrees, "TreePampas", rmRandInt(7,8), 10.0);
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
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 45*cNumberNonGaiaPlayers);
	//}
		rmSetStatusText("",0.8);
		int bonusTrees=rmCreateObjectDef("bonusTrees");
		rmAddObjectDefItem(bonusTrees, "treePuya", rmRandInt(3,4), rmRandFloat(8.0,11.0));
	rmAddObjectDefItem(bonusTrees, "UnderbrushDesert", rmRandInt(1,1), 7.0);
	  	rmAddObjectDefConstraint(bonusTrees, circleConstraint);
		rmAddObjectDefConstraint(bonusTrees, forestConstraint);
//		rmAddObjectDefConstraint(bonusTrees, avoidWaterShort);	
	rmPlaceObjectDefInArea(bonusTrees, 0, impassableLand , 15*cNumberNonGaiaPlayers);


	rmSetStatusText("",0.9);

  // King of the Hill (added 2026-11 for WoL): the open land just south of the river bend, on the line halfway between the two sides (the middle, inside the bend, cannot be reached on foot)
  if(rmGetIsKOTH()) {
    // the start point: (0.38, 0.38)
    float kothX = 0.38;
    float kothZ = 0.38;
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
 
