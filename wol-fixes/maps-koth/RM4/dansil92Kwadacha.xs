include "triggers\triggerLoader.xs";

/*
==============================
		Kwadacha
         by dansil92
==============================
*/
include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
 
void main(void) {
    wotta_triggers();
	rmSetStatusText("",0.01);
   // Picks the map size
	int playerTiles=13000;
	if (cNumberNonGaiaPlayers > 4){
		playerTiles = 11000;
	}else if (cNumberNonGaiaPlayers > 6){
		playerTiles = 10000;
	}


	


	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);
	if (cNumberTeams >= 3){
	size = 2.5 * sqrt(cNumberNonGaiaPlayers*playerTiles);
}

	rmSetMapSize(size, size);

	rmSetMapType("land");
        rmSetMapType("grass");
        rmSetMapType("rockies");
	//rmSetMapType("tropical");
       	rmTerrainInitialize("grass");
		rmSetLightingSet("spccc3adark");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
	rmSetSeaLevel(-3.0);
		rmSetSeaType("yucatan Coast");


		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 16.0);

        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 14.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 54.0);
		int avoidHuntSmall=rmCreateTypeDistanceConstraint("avoid hunts", "huntable", 11.0);

		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 24.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 12.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "Mine", 55.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 19.0);
        int cliffWater = rmCreateTerrainDistanceConstraint("cliff avoids river", "Land", false, 0.01);
        int cliffWater2 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 1.5);
        int cliffWater3 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 2.5);


        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 4.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 27.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 40.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 62.0);

  int avoidBerries=rmCreateTypeDistanceConstraint("avoid berries", "berrybush", 24.0);
  int avoidBerriesSmall=rmCreateTypeDistanceConstraint("avoid berries smoll", "berrybush", 8.0);

int stayWest = rmCreatePieConstraint("Stay West",0.47,0.53, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(180),rmDegreesToRadians(0));

int stayEast = rmCreatePieConstraint("Stay East",0.53,0.47, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(180));

   

	int PlayerNum = cNumberNonGaiaPlayers;
	int TeamNum = cNumberTeams;
	int numPlayer = cNumberPlayers;


    
 // =============Player placement ======================= 
    float spawnSwitch = rmRandFloat(0,1.2);


	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){

	if (PlayerNum == 2)
	{
	rmPlacePlayer(1, 0.235, 0.6);
	rmPlacePlayer(2, 0.765, 0.4);	}

			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.65, 0.9);
			rmPlacePlayersCircular(0.32, 0.32, 0.02);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.15, 0.4);
			rmPlacePlayersCircular(0.32, 0.32, 0.02);
		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
		rmPlacePlayer(2, 0.235, 0.6);
		rmPlacePlayer(1, 0.765, 0.4);
	}

			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.65, 0.9);
			rmPlacePlayersCircular(0.31, 0.31, 0.02);
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.15, 0.4);
			rmPlacePlayersCircular(0.31, 0.31, 0.02);

		}
	}else{
	//*************ffa placement********
		rmPlacePlayersCircular(0.31, 0.31, 0.00);
	}

		
        chooseMercs();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	   rmSetAreaMix(continent2, "rockies_snow");
        rmSetAreaBaseHeight(continent2, 5.0);
        rmSetAreaCoherence(continent2, 1.0);
        rmSetAreaSmoothDistance(continent2, 6);
        rmSetAreaHeightBlend(continent2, 1);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 10);
        rmSetAreaElevationVariation(continent2, 2);
        rmSetAreaElevationPersistence(continent2, .2);
        rmSetAreaElevationOctaves(continent2, 5);
        rmSetAreaElevationMinFrequency(continent2, 0.04);
        rmSetAreaElevationType(continent2, cElevTurbulence);  
        rmBuildArea(continent2);    

		int classPatch = rmDefineClass("patch");
		int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 14.0);
		int classCenter = rmDefineClass("center");
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 30.0);
		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
        

int stayLow = rmCreateMaxHeightConstraint("patches stay low", 0.0);

       		for (i=0; < cNumberNonGaiaPlayers*25){
			int patchID = rmCreateArea("first patch"+i);
			rmSetAreaWarnFailure(patchID, false);
			rmSetAreaSize(patchID, rmAreaTilesToFraction(20), rmAreaTilesToFraction(25));
        rmSetAreaTerrainType(patchID, "rockies\groundsnow5_roc");
		//	rmAddAreaToClass(patchID, rmClassID("patch"));
			rmSetAreaSmoothDistance(patchID, 1.0);
			rmBuildArea(patchID); 
		}

		for (i=0; < cNumberNonGaiaPlayers*85){
			int patchID2 = rmCreateArea("the second patch"+i);
			rmSetAreaWarnFailure(patchID2, false);
			rmSetAreaSize(patchID2, rmAreaTilesToFraction(35), rmAreaTilesToFraction(57));
        rmSetAreaTerrainType(patchID2, "rockies\groundsnow7_roc");
	//		rmAddAreaToClass(patchID2, rmClassID("patch"));
			rmSetAreaSmoothDistance(patchID2, 1.0);
			rmBuildArea(patchID2); 
}
		rmSetStatusText("",0.2);


//===========trade route=================
		int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
        rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID, true);
        rmSetObjectDefMinDistance(socketID, 0.0);
        rmSetObjectDefMaxDistance(socketID, 6.0);      
       
        int tradeRouteID = rmCreateTradeRoute();


//circular TP

        tradeRouteID = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.875); 

	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.86); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.817); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.73); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.86, 0.60); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.875, 0.5);
 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.86, 0.4); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.817, 0.3); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.73, 0.2); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.14); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.125); 

	rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.14); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.26, 0.2); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.183, 0.3); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.14, 0.4); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.125, 0.5); 

	rmAddTradeRouteWaypoint(tradeRouteID, 0.14, 0.6); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.183, 0.7); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.26, 0.8); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.86); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.875); 


        rmBuildTradeRoute(tradeRouteID, "dirt");
	vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.0);

	if (PlayerNum == 2)
{
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.15);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.4);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.65);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.9);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);

}else{
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.222);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.387);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.554);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.721);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.888);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.055);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
}



		rmSetStatusText("",0.3);



 int avoidTPSocket =rmCreateTypeDistanceConstraint("avoid trade socket", "SocketTradeRoute", 14.0);

//=========================================================


// BUILD NATIVE SITES

	//Choose Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int subCiv3=-1;

//Cree are awesome

   if (rmAllocateSubCivs(4) == true)
   {
      subCiv0=rmGetCivID("Cree");
      rmEchoInfo("subCiv0 is Cree "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Cree");

		subCiv1=rmGetCivID("Cree");
      rmEchoInfo("subCiv1 is Cree"+subCiv1);
		if (subCiv1 >= 0)
			 rmSetSubCiv(1, "Cree");
	 
		subCiv2=rmGetCivID("Inuit");
      rmEchoInfo("subCiv2 is Inuit"+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Inuit");

		subCiv3=rmGetCivID("Inuit");
      rmEchoInfo("subCiv3 is Inuit"+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Inuit");
	}
	
	// Set up Natives	
	int nativeID0 = -1;
    int nativeID1 = -1;
	int nativeID2 = -1;
    int nativeID3 = -1;
		
	nativeID0 = rmCreateGrouping("native site 1", "native Cree village 1");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 2.00);
	rmAddGroupingToClass(nativeID0, rmClassID("patch"));

	nativeID1 = rmCreateGrouping("native site 2", "native inuit 02");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 2.00);
	rmAddGroupingToClass(nativeID1, rmClassID("patch"));


//========place=====
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.55, 0.65);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.45, 0.35);
	if (cNumberNonGaiaPlayers >= 3){
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.4, 0.55);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.6, 0.45);
}



        int continent3 = rmCreateArea("continent3");
        rmSetAreaSize(continent3, 1.0, 1.0);
        rmSetAreaLocation(continent3, 0.5, 0.5);
        rmSetAreaBaseHeight(continent3, -2.0);
        rmSetAreaCoherence(continent3, 1.0);
        rmSetAreaSmoothDistance(continent3, 14);
        rmSetAreaHeightBlend(continent3, 1);
        rmSetAreaElevationNoiseBias(continent3, 0);
        rmSetAreaElevationEdgeFalloffDist(continent3, 10);
        rmSetAreaElevationVariation(continent3, 4);
        rmSetAreaElevationPersistence(continent3, .2);
        rmSetAreaElevationOctaves(continent3, 5);
        rmSetAreaElevationMinFrequency(continent3, 0.04);
        rmSetAreaElevationType(continent3, cElevTurbulence);
		rmSetAreaCliffType(continent3, "rocky mountain edge");
		rmSetAreaCliffEdge(continent3, 1, 1.0, 0.0, 1.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(continent3, false, true, true, 0.2, true);
		rmSetAreaCliffHeight(continent3, -1, 1, 0.5);
	rmAddAreaConstraint(continent3, avoidTradeRouteSmall);
	rmAddAreaConstraint(continent3, avoidTPSocket);  
        rmBuildArea(continent3);    
				
// ******KEEP BUILDABLE LAND UNDER TCS ******

for(i=1; < cNumberNonGaiaPlayers + 1) {

    int PlayerArea1 = rmCreateArea("NeedLand1"+i);
        rmSetAreaSize(PlayerArea1, .03, .03);
        rmSetAreaBaseHeight(PlayerArea1, -1.0);
		rmAddAreaToClass(PlayerArea1, rmClassID("classCenter"));
        rmSetAreaLocation(PlayerArea1, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmSetAreaTerrainType(PlayerArea1, "rockies\groundsnow1_roc");
        rmSetAreaSmoothDistance(PlayerArea1, 16);
        rmSetAreaHeightBlend(PlayerArea1, 2);

        rmSetAreaCoherence(PlayerArea1, 0.8);
        rmBuildArea(PlayerArea1);
}



		rmSetStatusText("",0.4);
		//starting objects

	int flagLand = rmCreateTerrainDistanceConstraint("flags dont like land", "land", true, 3.0);


		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 14.0);
	rmAddObjectDefConstraint(playerStart, avoidWaterShort);

       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "mine", 1, 1.0);
        rmSetObjectDefMinDistance(goldID, 14.0);
        rmSetObjectDefMaxDistance(goldID, 16.0);
        rmAddObjectDefConstraint(goldID, avoidCoin);

    
        int goldID2 = rmCreateObjectDef("starting gold 1v1");
        rmAddObjectDefItem(goldID2, "mine", 1, 1.0);
        rmSetObjectDefMinDistance(goldID2, 0.0);
        rmSetObjectDefMaxDistance(goldID2, 1.0);
   


        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "BerryBush", 5, 4.0);
        rmSetObjectDefMinDistance(berryID, 14.0);
        rmSetObjectDefMaxDistance(berryID, 15.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "ypTreeHimalayas", rmRandInt(6,7), 7.0);
        rmSetObjectDefMinDistance(treeID, 20.0);
        rmSetObjectDefMaxDistance(treeID, 21.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "caribou", 8, 8.0);
        rmSetObjectDefMinDistance(foodID, 16.0);
        rmSetObjectDefMaxDistance(foodID, 16.0);
	rmAddObjectDefConstraint(foodID, avoidCoin);	
        rmSetObjectDefCreateHerd(foodID, true);
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "muskox", 7, 8.0);
        rmSetObjectDefMinDistance(foodID2, 20.0);
        rmSetObjectDefMaxDistance(foodID2, 20.0);
	rmAddObjectDefConstraint(foodID2, avoidHuntSmall);	
        rmSetObjectDefCreateHerd(foodID2, true);
        rmAddObjectDefConstraint(foodID2, avoidCoin);

                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "caribou", 8, 8.0);
        rmSetObjectDefMinDistance(foodID3, 40.0);
        rmSetObjectDefMaxDistance(foodID3, 40.0);
	rmAddObjectDefConstraint(foodID3, avoidWaterShort);	
        rmSetObjectDefCreateHerd(foodID3, true);


  int playerCrateID=rmCreateObjectDef("bonus starting crates");
 rmAddObjectDefItem(playerCrateID, "PetWolf", 1, 2.0);
 //rmAddObjectDefItem(playerCrateID, "WhiteWolf", 1, 2.0);
  rmSetObjectDefMinDistance(playerCrateID, 15);
  rmSetObjectDefMaxDistance(playerCrateID, 15);
	rmAddObjectDefConstraint(playerCrateID, avoidCoin);


		int extraberrywagon=rmCreateObjectDef("JapAn cAnT hUnT");
  rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
  rmSetObjectDefMinDistance(extraberrywagon, 6.0);
  rmSetObjectDefMaxDistance(extraberrywagon, 7.0);


	if (PlayerNum == 2){

        rmPlaceObjectDefAtLoc(goldID2, 0, 0.24, 0.54, 1 );
        rmPlaceObjectDefAtLoc(goldID2, 0, 0.76, 0.46, 1 );

}


		rmSetStatusText("",0.5);  

    
    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 2.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 2.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	if (PlayerNum >= 3)
	{
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
}
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
  //      rmPlaceObjectDefAtLoc(berryID , i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerCrateID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));


if (rmGetPlayerCiv(i) == rmGetCivID("Japanese")) {
        rmPlaceObjectDefAtLoc(extraberrywagon, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        }


	}

	rmSetStatusText("",0.6);
	/*
	==================
	resource placement
	==================
	*/

	if (PlayerNum == 2){
//nat tp spot
        rmPlaceObjectDefAtLoc(goldID2, 0, 0.35, 0.35, 1 );
        rmPlaceObjectDefAtLoc(goldID2, 0, 0.65, 0.65, 1 );
//second mine
        rmPlaceObjectDefAtLoc(goldID2, 0, 0.4, 0.7, 1 );
        rmPlaceObjectDefAtLoc(goldID2, 0, 0.6, 0.3, 1 );
//back mine
       rmPlaceObjectDefAtLoc(goldID2, 0, 0.1, 0.42, 1 );
       rmPlaceObjectDefAtLoc(goldID2, 0, 0.9, 0.58, 1 );

}


  	int eastmine = rmCreateObjectDef("east mines");
	rmAddObjectDefItem(eastmine, "mine", 1, 1.0);
	rmAddObjectDefConstraint(eastmine, circleConstraint);
//	rmAddObjectDefConstraint(eastmine, avoidWaterShort);
/*
	if (PlayerNum == 2)
	{
	rmSetObjectDefMinDistance(eastmine, 0);
	rmSetObjectDefMaxDistance(eastmine, 3);
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.25, 0.75, 1);
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.5, 0.875, 1);
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.75, 0.75, 1);
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.875, 0.55, 1);

	rmPlaceObjectDefAtLoc(eastmine, 0, 0.125, 0.45, 1);
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.25, 0.25, 1);
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.5, 0.125, 1);
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.75, 0.25, 1);


	rmPlaceObjectDefAtLoc(eastmine, 0, 0.4, 0.6, 1);
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.6, 0.4, 1);

}else{
*/
	rmSetObjectDefMinDistance(eastmine, rmXFractionToMeters(0.0));
	rmSetObjectDefMaxDistance(eastmine, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(eastmine, avoidCoinMed);
	rmAddObjectDefConstraint(eastmine, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(eastmine, avoidPlateau);	
	rmAddObjectDefConstraint(eastmine, avoidWaterShort);
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.5, 0.5, 8*cNumberNonGaiaPlayers);
//}
	
    int muskHunts = rmCreateObjectDef("muskHunts");
	rmAddObjectDefItem(muskHunts, "muskox", rmRandInt(10,10), 10.0);
	rmSetObjectDefCreateHerd(muskHunts, true);
	rmSetObjectDefMinDistance(muskHunts, 0);
	rmSetObjectDefMaxDistance(muskHunts, 6);
//	rmAddObjectDefConstraint(muskHunts, avoidWaterShort);	

//centre hunts
	rmPlaceObjectDefAtLoc(muskHunts, 0, 0.45, 0.7, 1);
	rmPlaceObjectDefAtLoc(muskHunts, 0, 0.55, 0.3, 1);
	rmPlaceObjectDefAtLoc(muskHunts, 0, 0.5, 0.5, 1);



    int tapirsForDays = rmCreateObjectDef("tapirsForDays");
	rmAddObjectDefItem(tapirsForDays, "caribou", rmRandInt(9,9), 10.0);
	rmSetObjectDefCreateHerd(tapirsForDays, true);
	rmSetObjectDefMinDistance(tapirsForDays, 0);
	rmSetObjectDefMaxDistance(tapirsForDays, 6);
	if (PlayerNum == 2)
{
	rmPlaceObjectDefAtLoc(tapirsForDays, 0, 0.3, 0.4, 1);
	rmPlaceObjectDefAtLoc(tapirsForDays, 0, 0.7, 0.6, 1);
}

rmSetObjectDefMaxDistance(tapirsForDays, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(tapirsForDays, circleConstraint);
	rmAddObjectDefConstraint(tapirsForDays, avoidHunt);	
	rmAddObjectDefConstraint(tapirsForDays, avoidWaterShort);	
	rmAddObjectDefConstraint(tapirsForDays, avoidCoin);	
	rmPlaceObjectDefAtLoc(tapirsForDays, 0, 0.5, 0.5, 7*cNumberNonGaiaPlayers);


int RuinID=rmCreateObjectDef("Inuksuk");
	rmAddObjectDefItem(RuinID, "Inuksuk", 1);
	rmSetObjectDefMinDistance(RuinID, 0);
	rmSetObjectDefMaxDistance(RuinID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(RuinID, avoidTradeRouteSmall);	
	rmAddObjectDefConstraint(RuinID, avoidWaterShort);	
	rmAddObjectDefConstraint(RuinID, avoidCoin);
	rmAddObjectDefConstraint(RuinID, avoidTownCenterMore);
	rmAddObjectDefConstraint(RuinID, avoidPatch);	
	rmPlaceObjectDefAtLoc(RuinID, 0, 0.5, 0.5, 1*cNumberNonGaiaPlayers);



	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
	rmSetObjectDefMinDistance(nuggetID, 0.0); 
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.5)); 
		rmAddObjectDefToClass(nuggetID, rmClassID("patch")); 
	rmAddObjectDefConstraint(nuggetID, avoidNugget); 
	rmAddObjectDefConstraint(nuggetID, circleConstraint);
	rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetID, forestConstraintShort);
	rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(nuggetID, avoidBerriesSmall); 
	rmAddObjectDefConstraint(nuggetID, avoidPlateau);
	rmAddObjectDefConstraint(nuggetID, avoidWaterShort);	
	rmAddObjectDefConstraint(nuggetID, avoidCoin);	
	rmSetNuggetDifficulty(2, 3); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 7*cNumberNonGaiaPlayers);   



	rmSetStatusText("",0.7);


/*
//==========hills==============

	for (j=0; < (9*cNumberNonGaiaPlayers)) {   
			int islandW = rmCreateArea("islandW"+j);
        rmSetAreaSize(islandW, rmAreaTilesToFraction(300), rmAreaTilesToFraction(700));
		rmAddAreaToClass(islandW, rmClassID("classCenter"));
	rmAddAreaConstraint(islandW, avoidCenter);
	rmAddAreaConstraint(islandW, avoidTradeRouteSmall);
	rmAddAreaConstraint(islandW, avoidTownCenter);
	rmAddAreaConstraint(islandW, avoidCoin);

            rmSetAreaBaseHeight(islandW, 2.0);
        rmSetAreaSmoothDistance(islandW, 8);
        rmSetAreaHeightBlend(islandW, 2);

        rmSetAreaCoherence(islandW, .75);

        rmBuildArea(islandW);  
	}

*/




	//removes loop for faster loading times
	//for (j=0; < (6*cNumberNonGaiaPlayers)) {   
		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "ypTreeHimalayas", rmRandInt(6,7), rmRandFloat(7.0,8.0));
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.47));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidSocket);
	  	rmAddObjectDefConstraint(mapTrees, avoidCoin);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees, avoidPlateau);	
		rmAddObjectDefConstraint(mapTrees, avoidTPSocket);
	rmAddObjectDefConstraint(mapTrees, avoidPatch);
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 45*cNumberNonGaiaPlayers);
	//}
		rmSetStatusText("",0.8);
		int bonusTrees=rmCreateObjectDef("bonusTrees");
		rmAddObjectDefItem(bonusTrees, "UnderbrushRockiesSnow", rmRandInt(2,3), rmRandFloat(8.0,11.0));
	  	rmAddObjectDefConstraint(bonusTrees, circleConstraint);
		rmAddObjectDefConstraint(bonusTrees, forestConstraint);
		rmAddObjectDefConstraint(bonusTrees, avoidTradeRouteSmall);	
	rmPlaceObjectDefInArea(bonusTrees, 0, continent2, 15*cNumberNonGaiaPlayers);


	rmSetStatusText("",0.9);

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
 
