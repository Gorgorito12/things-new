include "triggers\triggerLoader.xs";

/*
==============================
	  Western Australia
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


	if (cNumberTeams == 2){
	rmSetMapSize(size*1.25, size);
}else{
	rmSetMapSize(size*1.5, size*1.2);
}
	rmSetMapType("land");
        rmSetMapType("grass");
	rmSetMapType("australia");
	//rmSetMapType("tropical");


		rmSetLightingSet("Berlin Dusk");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
	rmSetSeaLevel(-1.0);
		rmSetSeaType("Lisbon");
       	rmTerrainInitialize("grass");
		rmSetWindMagnitude(4.0);

		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 25.0);

int avoidPlateauShort =rmCreateClassDistanceConstraint("stuff vs. cliffs smoll", rmClassID("classPlateau"), 8.0);


        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.6), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 16.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 8.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 50.0);


		int avoidHuntSmall=rmCreateTypeDistanceConstraint("avoid hunts", "huntable", 20.0);

		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);


        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 24.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "minesalt", 10.0);
		int avoidTree=rmCreateTypeDistanceConstraint("avoid trees", "TreeSandalwood", 35.0);
		int avoidTreeShort=rmCreateTypeDistanceConstraint("avoid sandalwood", "TreeSandalwood", 12.0);




		int waterCoin=rmCreateTypeDistanceConstraint("avoid coin smallest", "minesalt", 15.0);


        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "minesalt", 40);
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
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 70.0);

  int avoidBerries=rmCreateTypeDistanceConstraint("avoid berries", "BushTomato", 20.0);
  int avoidBerriesSmall=rmCreateTypeDistanceConstraint("avoid berries smoll", "BushTomato", 15.0);


int stayWest = rmCreatePieConstraint("Stay West",0.47,0.53, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(180),rmDegreesToRadians(0));

int stayEast = rmCreatePieConstraint("Stay East",0.53,0.47, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(180));

   

	int PlayerNum = cNumberNonGaiaPlayers;
	int TeamNum = cNumberTeams;
	int numPlayer = cNumberPlayers;


    
 // =============Player placement ======================= 
    float spawnSwitch = rmRandInt(0,1);
	
	int Team1 = spawnSwitch;
	int Team2 = 0;
if (Team1 == 0){
	Team2 = 1;
}

	if (cNumberTeams == 2){


	if (PlayerNum == 2)
	{
	rmPlacePlayer(1, 0.38, 0.8);
	rmPlacePlayer(2, 0.38, 0.2);	}

if (PlayerNum < 6){
			rmSetPlacementTeam(Team1);
		rmPlacePlayersLine(0.38, 0.8, 0.55, 0.8, 0, 0);
			rmSetPlacementTeam(Team2);
		rmPlacePlayersLine(0.38, 0.2, 0.55, 0.2, 0, 0);

}else{
			rmSetPlacementTeam(Team1);
		rmPlacePlayersLine(0.38, 0.8, 0.67, 0.8, 0, 0);
			rmSetPlacementTeam(Team2);
		rmPlacePlayersLine(0.38, 0.2, 0.67, 0.2, 0, 0);
}
	}else{
	//*************ffa placement********
			rmSetPlacementSection(0.0, 0.5);
			rmSetTeamSpacingModifier(0.25);
		rmPlacePlayersCircular(0.41, 0.41, 0.00);
		
}

		
        chooseMercs();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	   rmSetAreaMix(continent2, "outbacksand");
       // rmSetAreaTerrainType(continent2, "wotta\salt");       
 rmSetAreaBaseHeight(continent2, 0.0);
        rmSetAreaCoherence(continent2, 1.0);
        rmSetAreaSmoothDistance(continent2, 10);
   rmSetAreaEdgeFilling(continent2, 2.0);
        rmSetAreaHeightBlend(continent2, 2);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 6);
        rmSetAreaElevationVariation(continent2, 5);
        rmSetAreaElevationPersistence(continent2, .2);
        rmSetAreaElevationOctaves(continent2, 5);
        rmSetAreaElevationMinFrequency(continent2, 0.04);
        rmSetAreaElevationType(continent2, cElevTurbulence);  
        rmBuildArea(continent2);    

		int classPatch = rmDefineClass("patch");
		int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 11.0);
		int classCenter = rmDefineClass("center");
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 36.0);
		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.56), rmDegreesToRadians(0), rmDegreesToRadians(360));



//===========trade route=================

int avoidTPSocket =rmCreateTypeDistanceConstraint("avoid trade socket", "SocketTradeRoute", 13.0);


	if (cNumberTeams == 2){

		int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
        rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID, true);
        rmSetObjectDefMinDistance(socketID, 0.0);
        rmSetObjectDefMaxDistance(socketID, 6.0);   
	rmAddObjectDefConstraint(socketID, avoidWaterShort);	
   
       
        int tradeRouteID = rmCreateTradeRoute();


        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

	if (PlayerNum >= 5)
	{
	rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.8);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.7);

	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.5);

	rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.3);
 	rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.2); 

}else{

	rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.5);
 	rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.0); 

}
        rmBuildTradeRoute(tradeRouteID, "DirtAustralian");


        vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

	if (PlayerNum >= 3)
	{
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.4);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.6);
       rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
}

}
//======================================================


		rmSetStatusText("",0.2);




//define player areas

for(i=1; < cNumberNonGaiaPlayers + 1) {

    int PlayerArea1 = rmCreateArea("NeedLand1"+i);
        rmSetAreaSize(PlayerArea1, rmAreaTilesToFraction(380), rmAreaTilesToFraction(380));
		rmAddAreaToClass(PlayerArea1, rmClassID("classPlateau"));
		rmAddAreaToClass(PlayerArea1, rmClassID("center"));
       rmSetAreaHeightBlend(PlayerArea1, 1);
        rmSetAreaLocation(PlayerArea1, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmSetAreaCoherence(PlayerArea1, 0.99);
        rmBuildArea(PlayerArea1);

}


        int continent4 = rmCreateArea("continent4");
        rmSetAreaSize(continent4, 0.25, 0.25);
        rmSetAreaLocation(continent4, 0.1, 0.5);
		rmAddAreaToClass(continent4, rmClassID("patch"));
	//   rmSetAreaMix(continent4, "rockies_grass");
        rmSetAreaCoherence(continent4, 0.9);
	rmAddAreaConstraint(continent4, avoidPlateau);

        rmBuildArea(continent4);    

   int stayForest = rmCreateAreaConstraint("stay in the forest", continent4);


		rmSetStatusText("",0.3);



int avoidCree =rmCreateTypeDistanceConstraint("avoid cree socket", "SocketCree", 18.0);


	if (PlayerNum == 2)
{
  	int smollMines = rmCreateObjectDef("competitive gold");
	rmAddObjectDefItem(smollMines, "minesalt", 1, 0.0);
	rmSetObjectDefMinDistance(smollMines, 0.0);
	rmSetObjectDefMaxDistance(smollMines, 0.0);
//middle mines

/*
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.05, 0.5, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.93, 0.5, 1);	rmPlaceObjectDefAtLoc(smollMines, 0, 0.44, 0.5, 1);

	rmPlaceObjectDefAtLoc(smollMines, 0, 0.63, 0.62, 1);	rmPlaceObjectDefAtLoc(smollMines, 0, 0.63, 0.38, 1);


//edge "anchor" mines
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.55, 0.94, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.55, 0.06, 1);
//2nd mines
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.22, 0.28, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.22, 0.72, 1);
*/

}


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
		
	nativeID0 = rmCreateGrouping("native site 1", "native cameleers village 1");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 2.00);
	rmAddGroupingToClass(nativeID0, rmClassID("patch"));

	nativeID1 = rmCreateGrouping("native site 2", "native cameleers village 4");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 2.00);
	rmAddGroupingToClass(nativeID1, rmClassID("patch"));

	nativeID2 = rmCreateGrouping("native site 3", "native cameleers village 2");
    rmSetGroupingMinDistance(nativeID2, 0.00);
    rmSetGroupingMaxDistance(nativeID2, 4.00);
	rmAddGroupingToClass(nativeID2, rmClassID("patch"));


//=== mining camp east

//========place=====
	if (cNumberTeams == 2){


//sides


	if (PlayerNum >= 3)
{
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.75, 0.15);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.75, 0.85);
}

}else{
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.6, 0.5);
}

	rmPlaceGroupingAtLoc(nativeID2, 0, 0.78, 0.5);



       	int stayCentral = rmCreateBoxConstraint("stay in middle portion", 0.2, 0.05, 10., 0.95);


//==========salt flats==============

	for (j=0; < (10*cNumberNonGaiaPlayers)) {   
			int ffaCliffs = rmCreateArea("ffaCliffs"+j);
        rmSetAreaSize(ffaCliffs, rmAreaTilesToFraction(300), rmAreaTilesToFraction(400));
		rmAddAreaToClass(ffaCliffs, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(ffaCliffs, true);
	   rmSetAreaMix(ffaCliffs, "atacama_salt");
        rmSetAreaTerrainType(ffaCliffs, "wotta\salt");       
    //    rmSetAreaCoherence(ffaCliffs, 0.99);

 rmSetAreaBaseHeight(ffaCliffs, -6.0);
        rmSetAreaSmoothDistance(ffaCliffs, 10);
        rmSetAreaHeightBlend(ffaCliffs, 2);
//come back to this
	rmAddAreaRemoveType(ffaCliffs, "all");



	rmAddAreaConstraint(ffaCliffs, avoidCenter);
	rmAddAreaConstraint(ffaCliffs, avoidPatch);
	rmAddAreaConstraint(ffaCliffs, avoidPlateau);
	rmAddAreaConstraint(ffaCliffs, avoidTPSocket);
	rmAddAreaConstraint(ffaCliffs, stayCentral);
	rmAddAreaConstraint(ffaCliffs, circleConstraint);
	rmAddAreaConstraint(ffaCliffs, avoidTradeRouteSmall);
	rmSetAreaMinBlobs(ffaCliffs, 2);
	rmSetAreaMaxBlobs(ffaCliffs, 4);
	rmSetAreaMinBlobDistance(ffaCliffs, 12);
	rmSetAreaMaxBlobDistance(ffaCliffs, 14);

	
if (j == 0){
	rmSetAreaLocation(ffaCliffs, 0.5, .5);
}
if (j == 1){
		rmSetAreaLocation(ffaCliffs, 0.8, .2);
}
if (j == 2){
		rmSetAreaLocation(ffaCliffs, .8, .8);
}
if (j == 3){
		rmSetAreaLocation(ffaCliffs, .95, .5);
}
if (j == 4){
		rmSetAreaLocation(ffaCliffs, .65, .1);
}
if (j == 5){
		rmSetAreaLocation(ffaCliffs, .65, .9);
}


//avoidTradeRouteSmall 
        rmSetAreaCoherence(ffaCliffs, .99);

        rmBuildArea(ffaCliffs);  
	}
			



		rmSetStatusText("",0.4);
	
	//==============starting objects=====================

		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
	rmAddObjectDefConstraint(playerStart, avoidWaterShort);

       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "minesalt", 1, 2.0);
        rmSetObjectDefMinDistance(goldID, 0.0);
        rmSetObjectDefMaxDistance(goldID, 0.0);
        rmAddObjectDefConstraint(goldID, avoidCoin);

        int goldID2 = rmCreateObjectDef("second gold");
        rmAddObjectDefItem(goldID2, "minesalt", 1, 2.0);
        rmSetObjectDefMinDistance(goldID2, 0.0);
        rmSetObjectDefMaxDistance(goldID2, 0.0);
        rmAddObjectDefConstraint(goldID2, avoidCoin);



        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "BushTomato", 6, 4.0);
        rmAddObjectDefItem(berryID, "TreeWhiteGum", rmRandInt(2,2), 7.0);

        rmSetObjectDefMinDistance(berryID, 14.0);
        rmSetObjectDefMaxDistance(berryID, 17.0);
        rmAddObjectDefConstraint(berryID, avoidTreeShort);
        rmAddObjectDefConstraint(berryID, avoidBerriesSmall);


 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "underbrushTexasGrass", rmRandInt(1,2), 9.0);
    //    rmAddObjectDefItem(treeID, "TreeWhiteGum", rmRandInt(3,4), 7.0);
		rmAddObjectDefItem(treeID, "TreeSandalwood", rmRandInt(3,3), rmRandFloat(4.0,5.0));
        rmSetObjectDefMinDistance(treeID, 2.0);
        rmSetObjectDefMaxDistance(treeID, 4.0);
        rmAddObjectDefConstraint(treeID, avoidCoin);


 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "ReproducingEmu", 4, 8.0);
        rmSetObjectDefMinDistance(foodID, 10.0);
        rmSetObjectDefMaxDistance(foodID, 10.0);
	rmAddObjectDefConstraint(foodID, avoidHuntSmall);	
        rmSetObjectDefCreateHerd(foodID, true);
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "ReproducingEmu", 3, 8.0);
        rmSetObjectDefMinDistance(foodID2, 30.0);
        rmSetObjectDefMaxDistance(foodID2, 30.0);
        rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, avoidWaterShort);	
	rmAddObjectDefConstraint(foodID2, avoidHuntSmall);


                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "ReproducingEmu", 5, 6.0);
        rmSetObjectDefMinDistance(foodID3, 42.0);
        rmSetObjectDefMaxDistance(foodID3, 42.0);
	rmAddObjectDefConstraint(foodID3, avoidWaterShort);	
	rmAddObjectDefConstraint(foodID3, circleConstraint);
	rmAddObjectDefConstraint(foodID3, avoidHuntSmall);
        rmSetObjectDefCreateHerd(foodID3, true);

	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmSetNuggetDifficulty(1, 1); 
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 3.0);
    rmSetObjectDefMinDistance(playerNuggetID, 29.0);
    rmSetObjectDefMaxDistance(playerNuggetID, 32.0);
rmAddObjectDefConstraint(playerNuggetID, circleConstraint);
rmAddObjectDefConstraint(playerNuggetID, avoidTreeShort);
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
        rmSetObjectDefMaxDistance(startID, 3.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(treeID, 0, rmPlayerLocXFraction(i)+rmXTilesToFraction(9), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(foodID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(foodID2, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(playerNuggetID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

	}

	rmSetStatusText("",0.6);
	/*
	==================
	resource placement
	==================
	*/

  	int copperMine = rmCreateObjectDef("east mines");
	rmAddObjectDefItem(copperMine, "minesalt", 1, 1.0);
	rmSetObjectDefMinDistance(copperMine, rmXFractionToMeters(0.0));
	rmSetObjectDefMaxDistance(copperMine, rmXFractionToMeters(0.41));
	rmAddObjectDefConstraint(copperMine, avoidCoinMed);
	rmAddObjectDefConstraint(copperMine, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(copperMine, avoidTPSocket);	
	rmAddObjectDefConstraint(copperMine, cliffWater);
	rmAddObjectDefConstraint(copperMine, avoidTownCenter);
	rmAddObjectDefConstraint(copperMine, avoidPlateauShort);
	rmAddObjectDefConstraint(copperMine, avoidPatch);
	rmAddObjectDefConstraint(copperMine, circleConstraint);

//	rmPlaceObjectDefAtLoc(copperMine, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);



    int pronghornHerd = rmCreateObjectDef("pronghornHerd");
	rmAddObjectDefItem(pronghornHerd, "ReproducingEmu", 4, 8.0);
	rmSetObjectDefCreateHerd(pronghornHerd, true);
	rmSetObjectDefMinDistance(pronghornHerd, 0);
	rmSetObjectDefMaxDistance(pronghornHerd, rmXFractionToMeters(0.6));
//	rmAddObjectDefConstraint(pronghornHerd, circleConstraint2);
	rmAddObjectDefConstraint(pronghornHerd, avoidTownCenterMore);
	rmAddObjectDefConstraint(pronghornHerd, avoidHunt);
	//rmAddObjectDefConstraint(pronghornHerd, avoidPlateauShort);
	rmAddObjectDefConstraint(pronghornHerd, circleConstraint2);

	rmAddObjectDefConstraint(pronghornHerd, cliffWater);	
	rmAddObjectDefConstraint(pronghornHerd, avoidCoin);	
	rmPlaceObjectDefAtLoc(pronghornHerd, 0, 0.5, 0.5, 8*cNumberNonGaiaPlayers);



		rmSetStatusText("",0.7);



	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
        rmAddObjectDefItem(nuggetID, "BushTomato", 1, 4.0);
	rmSetObjectDefMinDistance(nuggetID, 0.0); 
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.44)); 
	rmAddObjectDefConstraint(nuggetID, avoidNugget); 
	rmAddObjectDefConstraint(nuggetID, avoidPlateauShort);
	rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetID, circleConstraint2); 
	rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(nuggetID, avoidTreeShort);	
	rmAddObjectDefConstraint(nuggetID, avoidCoin);	
	rmSetNuggetDifficulty(1, 1); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 12*cNumberNonGaiaPlayers);   






//======place trees first, remove from areas later=======

		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "TreeWattle", 5, 10);
		rmAddObjectDefItem(mapTrees, "TreeWhiteGum", 4, 10);

		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 

		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidSocket);
		rmAddObjectDefConstraint(mapTrees, forestConstraintShort);
		rmAddObjectDefConstraint(mapTrees, stayForest);
		rmAddObjectDefConstraint(mapTrees, circleConstraint);	
		//rmAddObjectDefConstraint(mapTrees, stayLow);	
		//rmAddObjectDefConstraint(mapTrees, avoidWaterShort);	

		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 20*cNumberNonGaiaPlayers);


	rmSetStatusText("",0.8);

int stayLow = rmCreateMaxHeightConstraint("coin stays low", -5.0);

		int saltMines=rmCreateObjectDef("salty bois");
	rmAddObjectDefItem(saltMines, "minesalt", 1, 3.0);
		rmAddObjectDefConstraint(saltMines, avoidCoinMed);
	rmAddObjectDefConstraint(saltMines, avoidTPSocket);	
rmAddObjectDefConstraint(saltMines, circleConstraint);
rmAddObjectDefConstraint(saltMines, stayLow);

    for(i=1; < cNumberNonGaiaPlayers*12) {
	rmPlaceObjectDefInRandomAreaOfClass(saltMines, 0, rmClassID("classPlateau"), 1);
 }
		int bonusTrees=rmCreateObjectDef("sandalwood trees");
		rmAddObjectDefItem(bonusTrees, "TreeSandalwood", rmRandInt(1,1), rmRandFloat(0.0,1.0));
		rmAddObjectDefToClass(bonusTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(bonusTrees, 0);
		rmSetObjectDefMaxDistance(bonusTrees, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(bonusTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(bonusTrees, avoidPlateauShort);	
		rmAddObjectDefConstraint(bonusTrees, avoidTree);	
		rmAddObjectDefConstraint(bonusTrees, stayForest);	
		//rmAddObjectDefConstraint(bonusTrees, circleConstraint);	

	rmPlaceObjectDefAtLoc(bonusTrees, 0, 0.5, 0.5, 8*cNumberNonGaiaPlayers);  



	rmSetStatusText("",0.9);

		int scatteredTrees=rmCreateObjectDef("scatteredTrees");
		rmAddObjectDefItem(scatteredTrees, "TreeWattle", rmRandInt(3,3), rmRandFloat(7.0,7.0));
		rmAddObjectDefItem(scatteredTrees, "TreeWhiteGum", rmRandInt(1,1), rmRandFloat(7.0,7.0));

		rmAddObjectDefToClass(scatteredTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(scatteredTrees, 0);
		rmSetObjectDefMaxDistance(scatteredTrees, rmXFractionToMeters(0.45));
	  	rmAddObjectDefConstraint(scatteredTrees, avoidTradeRouteSmall);
	  	rmAddObjectDefConstraint(scatteredTrees, avoidCoin);
		rmAddObjectDefConstraint(scatteredTrees, forestConstraint);
		rmAddObjectDefConstraint(scatteredTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(scatteredTrees, avoidPlateauShort);	
	rmPlaceObjectDefAtLoc(scatteredTrees, 0, 0.5, 0.5, 30*cNumberNonGaiaPlayers);  

	int propsHateProps =rmCreateTypeDistanceConstraint("fish v fish", "UnderbrushRockies", 12.0);


		//int waterProps =rmCreateObjectDef("water decor");
		//rmAddObjectDefItem(waterProps, "UnderbrushRockies", rmRandInt(2,3), rmRandFloat(4.0,5.0));
		//rmSetObjectDefMinDistance(waterProps, 0);
		//rmSetObjectDefMaxDistance(waterProps, rmXFractionToMeters(0.47));
		//rmPlaceObjectDefAtLoc(waterProps, 0, 0.5, 0.5, 60*cNumberNonGaiaPlayers);



	rmSetStatusText("",0.99);
	




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
 
