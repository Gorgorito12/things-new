include "triggers\triggerLoader.xs";

/*
==============================
	      Manitoba
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
	int playerTiles=12000;
	if (cNumberNonGaiaPlayers > 4){
		playerTiles = 10000;
	}else if (cNumberNonGaiaPlayers > 6){
		playerTiles = 8500;
	}



	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);

	rmSetMapSize(size, size);

	rmSetMapType("land");
        rmSetMapType("grass");
	rmSetMapType("greatlakes");
	//rmSetMapType("tropical");


		rmSetLightingSet("301a_malta");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
	rmSetSeaLevel(-1.0);
		rmSetSeaType("Lisbon");
       	rmTerrainInitialize("grass");
		rmSetWindMagnitude(4.0);


		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 24.0);

int avoidPlateauShort =rmCreateClassDistanceConstraint("stuff vs. cliffs smoll", rmClassID("classPlateau"), 8.0);


        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.46), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 21.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 49.0);


		int avoidHuntSmall=rmCreateTypeDistanceConstraint("avoid hunts", "huntable", 24.0);

		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);


        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 24.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 10.0);
		int avoidTree=rmCreateTypeDistanceConstraint("avoid trees", "TreePonderosaPine", 11.0);




		int waterCoin=rmCreateTypeDistanceConstraint("avoid coin smallest", "Mine", 14.0);


        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "Mine", 55.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 19.0);
        int cliffWater = rmCreateTerrainDistanceConstraint("cliff avoids river", "Land", false, 7.0);



int playerFactor = 0;

	if (cNumberNonGaiaPlayers >= 5){
	playerFactor = 8;
}

	if (cNumberNonGaiaPlayers >= 5 && cNumberTeams >= 3){
	playerFactor = 12;
}


        int cliffWater2 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 28.0+playerFactor);


        int cliffWater3 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 2.5);


        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 8.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 30.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 90.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 46.0);

  int avoidBerries=rmCreateTypeDistanceConstraint("avoid berries", "berrybush", 20.0);
  int avoidBerriesSmall=rmCreateTypeDistanceConstraint("avoid berries smoll", "berrybush", 8.0);


int stayWest = rmCreatePieConstraint("Stay West",0.47,0.53, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(180),rmDegreesToRadians(0));

int stayEast = rmCreatePieConstraint("Stay East",0.53,0.47, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(180));

   

	int PlayerNum = cNumberNonGaiaPlayers;
	int TeamNum = cNumberTeams;
	int numPlayer = cNumberPlayers;


    
 // =============Player placement ======================= 
    float spawnSwitch = rmRandFloat(0,1.2);
//spawnSwitch = 0.1;


	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){

	if (PlayerNum == 2)
	{
			rmPlacePlayer(1, 0.225, 0.71);
			rmPlacePlayer(2, 0.775, 0.29);
	}



	if (PlayerNum == 4)
	{			
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.25, 0.71, 0.25, 0.45, 0, 0);
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.75, 0.29, 0.75, 0.55, 0, 0);

	}


			rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.25, 0.72, 0.25, 0.35, 0, 0);
			rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.75, 0.28, 0.75, 0.65, 0, 0);


		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
			rmPlacePlayer(2, 0.225, 0.71);
			rmPlacePlayer(1, 0.775, 0.29);
	}



	if (PlayerNum == 4)
	{			
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.25, 0.71, 0.25, 0.45, 0, 0);
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.75, 0.29, 0.75, 0.55, 0, 0);

	}


			rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.25, 0.72, 0.25, 0.35, 0, 0);
			rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.75, 0.28, 0.75, 0.65, 0, 0);

		}
	}else{
	//*************ffa placement********
		rmPlacePlayersCircular(0.4, 0.4, 0.00);
	}

		
        chooseMercs();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	   rmSetAreaMix(continent2, "greatlakes_grass");
   //     rmSetAreaTerrainType(continent2, "cave\cave_ground1");       
 rmSetAreaBaseHeight(continent2, 0.0);
        rmSetAreaCoherence(continent2, 1.0);
        rmSetAreaSmoothDistance(continent2, 6);
   rmSetAreaEdgeFilling(continent2, 1.0);
        rmSetAreaHeightBlend(continent2, 2);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 6);
        rmSetAreaElevationVariation(continent2, 4);
        rmSetAreaElevationPersistence(continent2, .2);
        rmSetAreaElevationOctaves(continent2, 5);
        rmSetAreaElevationMinFrequency(continent2, 0.04);
        rmSetAreaElevationType(continent2, cElevTurbulence);  
        rmBuildArea(continent2);    

		int classPatch = rmDefineClass("patch");
		int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 36.0);
		int classCenter = rmDefineClass("center");
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 36.0);
		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.44), rmDegreesToRadians(0), rmDegreesToRadians(360));
        


		rmSetStatusText("",0.2);


       		for (i=0; < cNumberNonGaiaPlayers*125){
			int patchID = rmCreateArea("first patch"+i);
			rmSetAreaWarnFailure(patchID, false);
			rmSetAreaSize(patchID, rmAreaTilesToFraction(37), rmAreaTilesToFraction(42));
        rmSetAreaTerrainType(patchID, "california\desert5_cal");
	//		rmAddAreaToClass(patchID, rmClassID("patch"));
			rmSetAreaSmoothDistance(patchID, 1.0);
			rmBuildArea(patchID); 
		}



//define player areas

for(i=1; < cNumberNonGaiaPlayers + 1) {

    int PlayerArea1 = rmCreateArea("NeedLand1"+i);
        rmSetAreaSize(PlayerArea1, rmAreaTilesToFraction(360), rmAreaTilesToFraction(360));
		rmAddAreaToClass(PlayerArea1, rmClassID("classPlateau"));
		rmAddAreaToClass(PlayerArea1, rmClassID("center"));
       rmSetAreaHeightBlend(PlayerArea1, 1);
        rmSetAreaLocation(PlayerArea1, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmSetAreaCoherence(PlayerArea1, 0.93);
        rmBuildArea(PlayerArea1);

}





//==========native island placement===============

		int lakeWest = rmCreateArea("west lake");
		rmSetAreaSize(lakeWest, 0.002, 0.002); 
		rmSetAreaCoherence(lakeWest, .92);
	if (cNumberTeams == 2){
		rmSetAreaLocation(lakeWest, .18, .3);
}else{
		rmSetAreaLocation(lakeWest, .30, .62);
}	
		rmAddAreaToClass(lakeWest, rmClassID("patch"));
        rmSetAreaSmoothDistance(lakeWest, 8);

		rmBuildArea(lakeWest);


		int lakeEast = rmCreateArea("east lake");
		rmSetAreaSize(lakeEast, 0.002, 0.002); 
		rmSetAreaCoherence(lakeEast, .92);
	if (cNumberTeams == 2){
		rmSetAreaLocation(lakeEast, .82, .7);	
}else{
		rmSetAreaLocation(lakeEast, .7, .38);	
}
		rmAddAreaToClass(lakeEast, rmClassID("patch"));
        rmSetAreaSmoothDistance(lakeEast, 8);

		rmBuildArea(lakeEast);

	if (PlayerNum >= 4)
{
		int lakeSE = rmCreateArea("southeast lake");
		rmSetAreaSize(lakeSE, 0.002, 0.002); 
		rmSetAreaCoherence(lakeSE, .92);

	if (cNumberTeams == 2){
		rmSetAreaLocation(lakeSE, .45, .10);
}else{
		rmSetAreaLocation(lakeSE, .75, .6);
}

		rmAddAreaToClass(lakeSE, rmClassID("patch"));	
        rmSetAreaSmoothDistance(lakeSE, 8);

		rmBuildArea(lakeSE);


		int lakeSW = rmCreateArea("southwest lake");
		rmSetAreaSize(lakeSW, 0.002, 0.002); 
		rmSetAreaCoherence(lakeSW, .92);

	if (cNumberTeams == 2){
		rmSetAreaLocation(lakeSW, .55, .9);	
}else{
		rmSetAreaLocation(lakeSW, .25, .4);	
}

		rmAddAreaToClass(lakeSW, rmClassID("patch"));
        rmSetAreaSmoothDistance(lakeSW, 8);

		rmBuildArea(lakeSW);
}




//===========trade route=================
		int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
        rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID, true);
        rmSetObjectDefMinDistance(socketID, 0.0);
        rmSetObjectDefMaxDistance(socketID, 10.0);   
	rmAddObjectDefConstraint(socketID, avoidWaterShort);	
   
       
        int tradeRouteID = rmCreateTradeRoute();


        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

	rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.9);


	rmAddTradeRouteWaypoint(tradeRouteID, 0.55, 0.75);
 	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.6); 
 	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.4); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.45, 0.25); 


	rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.1);

        rmBuildTradeRoute(tradeRouteID, "dirt");





//======================================================

		rmSetStatusText("",0.3);

int avoidTPSocket =rmCreateTypeDistanceConstraint("avoid trade socket", "SocketTradeRoute", 14.0);


int avoidCree =rmCreateTypeDistanceConstraint("avoid cree socket", "SocketCree", 18.0);


	if (PlayerNum == 2)
{
  	int smollMines = rmCreateObjectDef("competitive gold");
	rmAddObjectDefItem(smollMines, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(smollMines, 0.0);
	rmSetObjectDefMaxDistance(smollMines, 0.0);
//back mines
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.35, 0.9, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.65, 0.1, 1);
//edge "anchor" mines
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.22, 0.5, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.78, 0.5, 1);

//tp line mines
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.45, 0.73, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.55, 0.27, 1);

}

		int avoidCoinSPC=rmCreateTypeDistanceConstraint("avoid coin special", "Mine", 14.0);

//==========random lakes==============

	for (j=0; < (9*cNumberNonGaiaPlayers)) {   
			int ffaCliffs = rmCreateArea("ffaCliffs"+j);
        rmSetAreaSize(ffaCliffs, rmAreaTilesToFraction(900), rmAreaTilesToFraction(1000));
		rmAddAreaToClass(ffaCliffs, rmClassID("classPlateau"));
        rmSetAreaWaterType(ffaCliffs, "new england lake");
        rmSetAreaSmoothDistance(ffaCliffs, 10);
        rmSetAreaHeightBlend(ffaCliffs, 3);
	rmSetAreaObeyWorldCircleConstraint(ffaCliffs, false);

	rmAddAreaConstraint(ffaCliffs, avoidCenter);
	rmAddAreaConstraint(ffaCliffs, avoidPatch);
	rmAddAreaConstraint(ffaCliffs, avoidPlateau);
	rmAddAreaConstraint(ffaCliffs, avoidTPSocket);
	rmAddAreaConstraint(ffaCliffs, cliffWater2);
//	rmAddAreaRemoveType(ffaCliffs, "mine");
	rmAddAreaConstraint(ffaCliffs, avoidTradeRouteSmall);
	rmAddAreaConstraint(ffaCliffs, avoidCoinSPC);


	
if (j == 0){
	rmSetAreaLocation(ffaCliffs, .6, .6);
}
if (j == 1){
		rmSetAreaLocation(ffaCliffs, .4, .4);
}
if (j == 2){
		rmSetAreaLocation(ffaCliffs, .5, .9);
}

if (j == 3){
		rmSetAreaLocation(ffaCliffs, .5, .1);
}


//avoidTradeRouteSmall 
        rmSetAreaCoherence(ffaCliffs, .93);

        rmBuildArea(ffaCliffs);  
	}
			

        vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.15);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.85);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.36);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.64);
       rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);





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
	 
		subCiv2=rmGetCivID("Cree");
      rmEchoInfo("subCiv2 is Cree"+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Cree");

		subCiv3=rmGetCivID("Cree");
      rmEchoInfo("subCiv3 is Cree"+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Cree");
	}
	
	// Set up Natives	
	int nativeID0 = -1;
    int nativeID1 = -1;
	int nativeID2 = -1;
    int nativeID3 = -1;
		
	nativeID0 = rmCreateGrouping("native site 1", "native cree village 1");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 0.00);
	rmAddGroupingToClass(nativeID0, rmClassID("patch"));

	nativeID1 = rmCreateGrouping("native site 2", "native cree village 5");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 0.00);
	rmAddGroupingToClass(nativeID1, rmClassID("patch"));

//========place=====
	if (cNumberTeams == 2){
//sides
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.18, 0.3);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.82, 0.7);

	if (PlayerNum >= 4)
{
//top & bottom
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.45, 0.1);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.55, 0.9);
}
}else{
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.30, 0.62);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.70, 0.38);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.75, 0.6);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.25, 0.40);

}



		rmSetStatusText("",0.4);
	
	//==============starting objects=====================

		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
	rmAddObjectDefConstraint(playerStart, avoidWaterShort);

       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "mine", 1, 2.0);
        rmSetObjectDefMinDistance(goldID, 0.0);
        rmSetObjectDefMaxDistance(goldID, 0.0);
        rmAddObjectDefConstraint(goldID, avoidCoin);

        int goldID2 = rmCreateObjectDef("second gold");
        rmAddObjectDefItem(goldID2, "mine", 1, 2.0);
        rmSetObjectDefMinDistance(goldID2, 0.0);
        rmSetObjectDefMaxDistance(goldID2, 0.0);
        rmAddObjectDefConstraint(goldID2, avoidCoin);



        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "Mushrooms", 1, 4.0);
        rmSetObjectDefMinDistance(berryID, 18.0);
        rmSetObjectDefMaxDistance(berryID, 19.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "underbrushTexasGrass", rmRandInt(3,4), 9.0);
        rmAddObjectDefItem(treeID, "TreePonderosaPine", rmRandInt(9,10), 6.0);
        rmSetObjectDefMinDistance(treeID, 24.0);
        rmSetObjectDefMaxDistance(treeID, 25.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
        rmAddObjectDefConstraint(treeID, avoidTree);


 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "moose", 6, 8.0);
        rmSetObjectDefMinDistance(foodID, 10.0);
        rmSetObjectDefMaxDistance(foodID, 10.0);
	rmAddObjectDefConstraint(foodID, avoidWaterShort);	
        rmSetObjectDefCreateHerd(foodID, true);
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "deer", 5, 6.0);
        rmSetObjectDefMinDistance(foodID2, 29.0);
        rmSetObjectDefMaxDistance(foodID2, 30.0);
        rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, avoidWaterShort);	
	rmAddObjectDefConstraint(foodID2, circleConstraint);


                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "elk", 9, 6.0);
        rmSetObjectDefMinDistance(foodID3, 39.0);
        rmSetObjectDefMaxDistance(foodID3, 39.0);
	rmAddObjectDefConstraint(foodID3, avoidWaterShort);	
	rmAddObjectDefConstraint(foodID3, circleConstraint);
	rmAddObjectDefConstraint(foodID3, avoidHuntSmall);
        rmSetObjectDefCreateHerd(foodID3, true);

	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmSetNuggetDifficulty(1, 1); 
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 3.0);
    rmSetObjectDefMinDistance(playerNuggetID, 29.0);
    rmSetObjectDefMaxDistance(playerNuggetID, 29.0);
rmAddObjectDefConstraint(playerNuggetID, circleConstraint);
rmAddObjectDefConstraint(playerNuggetID, avoidTree);
rmAddObjectDefConstraint(playerNuggetID, avoidCoin);




		int extraberrywagon=rmCreateObjectDef("JapAn cAnT hUnT");
  rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
  rmSetObjectDefMinDistance(extraberrywagon, 6.0);
  rmSetObjectDefMaxDistance(extraberrywagon, 7.0);

	int flagLand = rmCreateTerrainDistanceConstraint("flags dont like land", "land", true, 7.0);



		rmSetStatusText("",0.5);  
    
    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 3.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 2.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i)+rmXTilesToFraction(12), rmPlayerLocZFraction(i));

	if (PlayerNum >= 3){
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
 }       



	rmPlaceObjectDefAtLoc(goldID2 , i, rmPlayerLocXFraction(i)-rmXTilesToFraction(12), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerNuggetID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

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

  	int copperMine = rmCreateObjectDef("east mines");
	rmAddObjectDefItem(copperMine, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(copperMine, rmXFractionToMeters(0.0));
	rmSetObjectDefMaxDistance(copperMine, rmXFractionToMeters(0.43));
	rmAddObjectDefConstraint(copperMine, avoidCoinMed);
	rmAddObjectDefConstraint(copperMine, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(copperMine, avoidTPSocket);	
	rmAddObjectDefConstraint(copperMine, cliffWater);
	rmAddObjectDefConstraint(copperMine, avoidTownCenter);
	rmAddObjectDefConstraint(copperMine, cliffWater3);
	rmPlaceObjectDefAtLoc(copperMine, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);





    int pronghornHerd = rmCreateObjectDef("pronghornHerd");
	rmAddObjectDefItem(pronghornHerd, "elk", 9, 8.0);
	rmSetObjectDefCreateHerd(pronghornHerd, true);
	rmSetObjectDefMinDistance(pronghornHerd, 0);
	rmSetObjectDefMaxDistance(pronghornHerd, 5);


	if (PlayerNum == 2){	
//centre hunts
	rmPlaceObjectDefAtLoc(pronghornHerd, 0, 0.5, 0.78, 1);
	rmPlaceObjectDefAtLoc(pronghornHerd, 0, 0.5, 0.22, 1);
	rmPlaceObjectDefAtLoc(pronghornHerd, 0, 0.5, 0.5, 1);
//2nd hunt
	rmPlaceObjectDefAtLoc(pronghornHerd, 0, 0.11, 0.6, 1);
	rmPlaceObjectDefAtLoc(pronghornHerd, 0, 0.89, 0.4, 1);
//3rd hunt
	rmPlaceObjectDefAtLoc(pronghornHerd, 0, 0.25, 0.47, 1);
	rmPlaceObjectDefAtLoc(pronghornHerd, 0, 0.75, 0.53, 1);
//4th hunt
	rmPlaceObjectDefAtLoc(pronghornHerd, 0, 0.7, 0.16, 1);
	rmPlaceObjectDefAtLoc(pronghornHerd, 0, 0.3, 0.84, 1);


}else{	

	rmSetObjectDefMaxDistance(pronghornHerd, rmXFractionToMeters(0.41));
	rmAddObjectDefConstraint(pronghornHerd, circleConstraint2);
	rmAddObjectDefConstraint(pronghornHerd, avoidTownCenter);
	rmAddObjectDefConstraint(pronghornHerd, avoidHunt);
	rmAddObjectDefConstraint(pronghornHerd, avoidPlateauShort);
	rmAddObjectDefConstraint(pronghornHerd, cliffWater);	
	rmAddObjectDefConstraint(pronghornHerd, avoidCoin);	
	rmPlaceObjectDefAtLoc(pronghornHerd, 0, 0.5, 0.5, 7*cNumberNonGaiaPlayers);
}

	int avoidBighorn=rmCreateTypeDistanceConstraint("bighorn avoids food", "Moose", 65.0);

  	int cliffSheep = rmCreateObjectDef("water Moose");
	rmAddObjectDefItem(cliffSheep, "Moose", 5, 4.0);
	rmSetObjectDefMinDistance(cliffSheep, 0.0);
	rmSetObjectDefMaxDistance(cliffSheep, rmXFractionToMeters(0.42));
	//rmAddObjectDefConstraint(cliffSheep, waterHunt);
	rmAddObjectDefConstraint(cliffSheep, avoidTownCenterMore);	
	rmAddObjectDefConstraint(cliffSheep, avoidBighorn);	
	rmAddObjectDefConstraint(cliffSheep, avoidHunt);
	rmAddObjectDefConstraint(cliffSheep, circleConstraint2);
	rmPlaceObjectDefAtLoc(cliffSheep, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);   


		rmSetStatusText("",0.7);



	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
	rmSetObjectDefMinDistance(nuggetID, 0.0); 
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.42)); 
	rmAddObjectDefConstraint(nuggetID, avoidNugget); 
	rmAddObjectDefConstraint(nuggetID, avoidTree);
	rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
//	rmAddObjectDefConstraint(nuggetID, avoidTownCenterMore); 
	rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(nuggetID, cliffWater3);	
	rmAddObjectDefConstraint(nuggetID, avoidCoin);	
	rmSetNuggetDifficulty(1, 1); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 12*cNumberNonGaiaPlayers);   



	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 2.0);

	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "FishBass", 9.0);


	int fishID=rmCreateObjectDef("fish Mahi");
	rmAddObjectDefItem(fishID, "FishBass", 1, 1.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.99));
	rmAddObjectDefConstraint(fishID, fishLand);
	rmAddObjectDefConstraint(fishID, fishVsFishID);

	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 35*cNumberNonGaiaPlayers);   



		int bonusTrees=rmCreateObjectDef("bonusTrees");
		rmAddObjectDefItem(bonusTrees, "TreePonderosaPine", rmRandInt(6,7), rmRandFloat(11.0,12.0));
	rmAddObjectDefItem(bonusTrees, "TreeNewEngland", rmRandInt(3,4), 10.0);
	rmAddObjectDefItem(bonusTrees, "UnderbrushNewEngland", rmRandInt(6,7), 12.0);
	rmAddObjectDefItem(bonusTrees, "UnderbrushTexas", rmRandInt(3,4), 12.0);
	rmAddObjectDefItem(bonusTrees, "Mushrooms", rmRandInt(1,1), 8.0);

		rmAddObjectDefToClass(bonusTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(bonusTrees, 0);
		rmSetObjectDefMaxDistance(bonusTrees, rmXFractionToMeters(0.47));
	  	rmAddObjectDefConstraint(bonusTrees, avoidTradeRouteSmall);
	  	rmAddObjectDefConstraint(bonusTrees, avoidCoin);
		rmAddObjectDefConstraint(bonusTrees, forestConstraint);
		rmAddObjectDefConstraint(bonusTrees, avoidTownCenter);	
	  	rmAddObjectDefConstraint(bonusTrees, avoidCree);
	rmPlaceObjectDefAtLoc(bonusTrees, 0, 0.5, 0.5, 50*cNumberNonGaiaPlayers);   




	rmSetStatusText("",0.99);
	




  // King of the Hill (added 2026-11 for WoL): the middle is on the lake shore; first open land on the line that splits the teams
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
 
