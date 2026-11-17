include "triggers\triggerLoader.xs";

/*
==============================
		Fiji
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
	int playerTiles=20000;
	if (cNumberNonGaiaPlayers > 4){
		playerTiles = 17000;
	}else if (cNumberNonGaiaPlayers > 6){
		playerTiles = 14000;
	}



	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);

	if (cNumberTeams >= 3){
	size = 2.5 * sqrt(cNumberNonGaiaPlayers*playerTiles);
}

	rmSetMapSize(size, size);

	rmSetSeaType("Ceylon Coast");
	rmSetMapType("polynesia");
	rmSetMapType("water");
	rmSetWorldCircleConstraint(true);
//	rmSetOceanReveal(true);
	rmSetLightingSet("Yucatan");
//		rmSetLightingSet("lisbon");
//		rmSetLightingSet("amsterdam evening");
//		rmSetLightingSet("lisbon storm");
		rmSetSeaLevel(0.0);



   // Init map.
   rmTerrainInitialize("water");

 	  rmSetGlobalRain( 0.6 );

//		rmSetLightingSet("st_louis");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");



		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 12.0);

		int avoidPlateauSmall=rmCreateClassDistanceConstraint("stuff vs. cliffs s", rmClassID("classPlateau"), 7.0);


        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 28.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 18.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 48.0);

		int avoidHuntSmall=rmCreateTypeDistanceConstraint("hunts avoid hunts small", "huntable", 30.0);


		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 24.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "guano", 10.0);
		int avoidCoinSPC=rmCreateTypeDistanceConstraint("avoid special coin", "mineBasalt", 12.0);

		int avoidGold=rmCreateTypeDistanceConstraint("avoid coin gold", "mineGold", 16.0);

		int waterCoin=rmCreateTypeDistanceConstraint("avoid coin smallest", "guano", 8.0);


        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "guano", 75.0);

        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 5.0);
        int cliffWater = rmCreateTerrainDistanceConstraint("cliff avoids river", "Land", false, 26.00);
        int cliffWater2 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 5.0);
        int cliffWater3 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 14.0);


        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 9.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 38.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 21.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 60.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 70.0);

		int avoidNuggetSmall=rmCreateTypeDistanceConstraint("avoid teh nuggs", "AbstractNugget", 10.0);



  int avoidBerries=rmCreateTypeDistanceConstraint("avoid berries", "berrybush", 20.0);
  int avoidBerriesSmall=rmCreateTypeDistanceConstraint("avoid berries smoll", "berrybush", 8.0);

//SocketFale
  int avoidFale =rmCreateTypeDistanceConstraint("avoid fales", "SocketFale", 18.0);
  int avoidFaleSmall =rmCreateTypeDistanceConstraint("avoid fales a little less", "SocketFale", 15.0);


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
	rmPlacePlayer(1, 0.3, 0.7);
	rmPlacePlayer(2, 0.7, 0.3);	
}

		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.4, 0.8, 0.2, 0.6, 0, 0);
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.6, 0.2, 0.8, 0.4, 0, 0);


		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
	rmPlacePlayer(1, 0.3, 0.7);
	rmPlacePlayer(2, 0.7, 0.3);	
	}

		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.4, 0.8, 0.2, 0.6, 0, 0);
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.6, 0.2, 0.8, 0.4, 0, 0);

		}
	}else{
	//*************ffa placement********
		rmPlacePlayersCircular(0.32, 0.32, 0.00);
	}

		
        chooseMercs();
        rmSetStatusText("",0.1); 


        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 0.39, 0.39);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	//   rmSetAreaMix(continent2, "araucania_dirt_b");
	   rmSetAreaMix(continent2, "ceylon_sand_a");

        rmSetAreaBaseHeight(continent2, 4.0);
        rmSetAreaCoherence(continent2, 0.86);
        rmSetAreaSmoothDistance(continent2, 11);
        rmSetAreaHeightBlend(continent2, 3);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 10);
        rmSetAreaElevationVariation(continent2, 5);
        rmSetAreaElevationPersistence(continent2, .2);
        rmSetAreaElevationOctaves(continent2, 5);
        rmSetAreaElevationMinFrequency(continent2, 0.04);
        rmSetAreaElevationType(continent2, cElevTurbulence);  
        rmBuildArea(continent2);    

		int classPatch = rmDefineClass("patch");
		int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 12.0);
		int classCenter = rmDefineClass("center");
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 18.0);

		int avoidCenterShort = rmCreateClassDistanceConstraint("avoid center small", rmClassID("center"), 5.0);

		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.4), rmDegreesToRadians(0), rmDegreesToRadians(360));
        
//=======================================================

       		for (i=0; < cNumberNonGaiaPlayers*60){
			int patchID = rmCreateArea("first patch"+i);
			rmSetAreaWarnFailure(patchID, false);
			rmSetAreaSize(patchID, rmAreaTilesToFraction(20), rmAreaTilesToFraction(25));
        rmSetAreaTerrainType(patchID, "ceylon\ground_shoreline2_ceylon");
			rmSetAreaSmoothDistance(patchID, 1.0);
			rmBuildArea(patchID); 
		}
//=====================================================


for(i=1; < cNumberNonGaiaPlayers + 1) {

    int PlayerArea1 = rmCreateArea("NeedLand1"+i);
        rmSetAreaSize(PlayerArea1, rmAreaTilesToFraction(200), rmAreaTilesToFraction(200));
		rmAddAreaToClass(PlayerArea1, rmClassID("center"));
		rmAddAreaToClass(PlayerArea1, rmClassID("patch"));

//       rmSetAreaHeightBlend(PlayerArea1, 2);
        rmSetAreaBaseHeight(PlayerArea1, 4.25);
        rmSetAreaLocation(PlayerArea1, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	   rmSetAreaMix(PlayerArea1, "ceylon_grass_a");

        rmSetAreaCoherence(PlayerArea1, 0.85);
//   rmSetAreaEdgeFilling(PlayerArea1, 1.0);
        rmBuildArea(PlayerArea1);

}



		rmSetStatusText("",0.2);





	int NWconstraint = rmCreateBoxConstraint("stay in NW portion", 0, 0.6, 0.4, 1);
	int NEconstraint = rmCreateBoxConstraint("stay in NE portion", 0.6, 0.0, 1.0, 0.4);



		int glacierBaseNW = rmCreateArea("flatland northwest");
		rmSetAreaSize(glacierBaseNW, 0.48, 0.48); 
		rmSetAreaCoherence(glacierBaseNW, .92);
		rmSetAreaLocation(glacierBaseNW, .5, .5);	
	//rmAddAreaToClass(glacierBaseNW, rmClassID("center"));
		//rmBuildArea(glacierBaseNW);


		int jungleArea = rmCreateArea("jungle Area ");
		rmSetAreaSize(jungleArea, 0.24, 0.24); 
		rmAddAreaToClass(jungleArea, rmClassID("center"));
      rmSetAreaBaseHeight(jungleArea, 5.0);
     rmSetAreaSmoothDistance(jungleArea, 1);
	rmSetAreaCoherence(jungleArea, .94);
	   rmSetAreaMix(jungleArea, "borneo_grass_b");
	rmSetAreaLocation(jungleArea, .5, .5);	
	rmAddAreaConstraint(jungleArea, cliffWater);
	rmAddAreaConstraint(jungleArea, avoidPatch);
	rmSetAreaObeyWorldCircleConstraint(jungleArea, false);
	rmBuildArea(jungleArea);


// BUILD NATIVE SITES

	//Choose Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int subCiv3=-1;


			int natPicker = rmRandInt(1,5);



   if (rmAllocateSubCivs(4) == true)
   {
      subCiv0=rmGetCivID("Fale");
      rmEchoInfo("subCiv0 is Fale "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Fale");

		subCiv1=rmGetCivID("Fale");
      rmEchoInfo("subCiv1 is Fale "+subCiv1);
		if (subCiv1 >= 0)
			 rmSetSubCiv(1, "Fale");
	 
		subCiv2=rmGetCivID("Fale");
      rmEchoInfo("subCiv2 is Fale "+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Fale");

		subCiv3=rmGetCivID("Fale");
      rmEchoInfo("subCiv3 is Fale "+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Fale");
	}
	
	// Set up Natives	
	int nativeID0 = -1;
    int nativeID1 = -1;
	int nativeID2 = -1;
    int nativeID3 = -1;
		
	nativeID0 = rmCreateGrouping("native site 1", "Atoll Fale 2");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 0.00);
	rmAddAreaToClass(nativeID0, rmClassID("patch"));

	nativeID1 = rmCreateGrouping("native site 2", "Atoll Fale 3");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 0.00);
	rmAddAreaToClass(nativeID1, rmClassID("patch"));


//========place=====
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.55, 0.65);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.65, 0.55);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.45, 0.35);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.35, 0.45);





		int centreMountains = rmCreateArea("big mountains");
		rmSetAreaSize(centreMountains, 0.05, 0.05); 
		rmAddAreaToClass(centreMountains, rmClassID("classPlateau"));
		rmSetAreaCliffType(centreMountains, "Bioko");
        rmSetAreaHeightBlend(centreMountains, 1);
		rmSetAreaCliffEdge(centreMountains, 7, 0.07, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(centreMountains , true, true, true, 0.4, true);
		rmSetAreaCliffHeight(centreMountains, 16, 0.1, 0.5);
        rmSetAreaBaseHeight(centreMountains, 6.0);
        rmSetAreaSmoothDistance(centreMountains, 3);
		rmSetAreaCoherence(centreMountains, .96);
		rmSetAreaLocation(centreMountains, .5, .5);	
        rmAddAreaInfluenceSegment(centreMountains, 0.55, 0.55, 0.45, 0.45);
     //   rmAddAreaInfluenceSegment(centreMountains, 1.0, 0.0, 0.7, 0.0);
	//rmAddAreaConstraint(centreMountains, avoidCenterShort);
	rmAddAreaConstraint(centreMountains, cliffWater);
	rmAddAreaConstraint(centreMountains, avoidFale);

	rmBuildArea(centreMountains);


  int avoidBasalt =rmCreateTypeDistanceConstraint("basalt avoids the other ones", "mineBasalt", 45.0);

  int avoidBasaltShort =rmCreateTypeDistanceConstraint("basalt constraint", "mineBasalt", 8.0);


  	int smollMines = rmCreateObjectDef("competitive gold");
	rmAddObjectDefItem(smollMines, "mineBasalt", 1, 1.0);
        rmAddObjectDefConstraint(smollMines, avoidBasalt);
        rmAddObjectDefConstraint(smollMines, avoidWaterShort);
	rmPlaceObjectDefInArea(smollMines, 0, centreMountains, 2*cNumberNonGaiaPlayers);





//========================================================




		rmSetStatusText("",0.3);

   int stayMountain = rmCreateAreaConstraint("cliffs stay in mountains", centreMountains);

		int classMountain = rmDefineClass("mountain");

		int avoidMountain = rmCreateClassDistanceConstraint("avoid mountains", rmClassID("mountain"), 12.0);




	for (j=0; < (6*cNumberNonGaiaPlayers)) {   
			int ffaCliffs = rmCreateArea("ffaCliffs"+j);
        rmSetAreaSize(ffaCliffs, rmAreaTilesToFraction(10), rmAreaTilesToFraction(45));
		rmAddAreaToClass(ffaCliffs, rmClassID("classPlateau"));
		rmAddAreaToClass(ffaCliffs, rmClassID("mountain"));
		rmSetAreaCliffType(ffaCliffs, "Patagonia");
		rmSetAreaCliffEdge(ffaCliffs, 1, 1, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(ffaCliffs, false, false, false, 1.5, true);
		rmSetAreaCliffHeight(ffaCliffs, rmRandInt(6,8), 1, 0.5);
        rmSetAreaSmoothDistance(ffaCliffs, 5);
        rmSetAreaHeightBlend(ffaCliffs, 1);
	//rmAddAreaConstraint(ffaCliffs, avoidWaterShort);
	rmAddAreaConstraint(ffaCliffs, avoidMountain);
	rmAddAreaConstraint(ffaCliffs, avoidBasaltShort);
	rmAddAreaConstraint(ffaCliffs, stayMountain);
        rmSetAreaCoherence(ffaCliffs, .98);

        rmBuildArea(ffaCliffs);  
	}

	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
	rmAddObjectDefConstraint(nuggetID, avoidNugget); 
	rmAddObjectDefConstraint(nuggetID, forestConstraintShort);
	rmAddObjectDefConstraint(nuggetID, avoidBasaltShort);
	rmAddObjectDefConstraint(nuggetID, avoidMountain);	
	rmSetNuggetDifficulty(1, 1); 

rmPlaceObjectDefInArea(nuggetID, 0, centreMountains , 3*cNumberNonGaiaPlayers);





		rmSetStatusText("",0.4);
		//starting objects

		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
	rmAddObjectDefConstraint(playerStart, avoidWaterShort);

       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "guano", 1, 3.0);
        rmSetObjectDefMinDistance(goldID, 12.0);
        rmSetObjectDefMaxDistance(goldID, 17.0);
        rmAddObjectDefConstraint(goldID, avoidWaterShort);
	rmAddObjectDefConstraint(goldID, avoidCenterShort);




        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "BananaBush", 5, 4.0);
        rmSetObjectDefMinDistance(berryID, 16.0);
        rmSetObjectDefMaxDistance(berryID, 17.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "ypTreeCeylon", rmRandInt(6,7), 5.0);
        rmSetObjectDefMinDistance(treeID, 19.0);
        rmSetObjectDefMaxDistance(treeID, 21.0);
        rmAddObjectDefConstraint(treeID, avoidPlateau);
        rmAddObjectDefConstraint(treeID, avoidCoin);
		rmAddObjectDefToClass(treeID, rmClassID("classForest")); 

 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "Crab", 7, 3.0);
        rmSetObjectDefMinDistance(foodID, 9.0);
        rmSetObjectDefMaxDistance(foodID, 9.0);
	rmAddObjectDefConstraint(foodID, avoidWaterShort);	
        rmSetObjectDefCreateHerd(foodID, true);
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "Iguana", 5, 4.0);
        rmSetObjectDefMinDistance(foodID2, 24.0);
        rmSetObjectDefMaxDistance(foodID2, 24.0);
        rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, avoidWaterShort);	
	rmAddObjectDefConstraint(foodID2, avoidCenterShort);
	rmAddObjectDefConstraint(foodID2, avoidCoin);



                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "Crab", 9, 8.0);
        rmSetObjectDefMinDistance(foodID3, 40.0);
        rmSetObjectDefMaxDistance(foodID3, 40.0);
	rmAddObjectDefConstraint(foodID3, avoidPlateau);	
	rmAddObjectDefConstraint(foodID3, avoidCenterShort);
	rmAddObjectDefConstraint(foodID3, avoidHunt);
        rmSetObjectDefCreateHerd(foodID3, true);

	int playerwetNuggetID=rmCreateObjectDef("player nugget");
	rmSetNuggetDifficulty(1, 1); 
	rmAddObjectDefItem(playerwetNuggetID, "nugget", 1, 3.0);
    rmSetObjectDefMinDistance(playerwetNuggetID, 28.0);
    rmSetObjectDefMaxDistance(playerwetNuggetID, 29.0);
	rmAddObjectDefConstraint(playerwetNuggetID, circleConstraint);

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
	if (rmGetNomadStart())
		{
		rmAddObjectDefItem(startID, "CoveredWagon", 1, 1.0);
		}
	else
		{
		rmAddObjectDefItem(startID, "TownCenter", 1, 1.0);
		}
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 1.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
  //      rmPlaceObjectDefAtLoc(berryID , i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
 //       rmPlaceObjectDefAtLoc(playerwetNuggetID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		int waterFlag = rmCreateObjectDef("HC water flag "+i);
         rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 0.0);
        // rmAddObjectDefItem(waterFlag, "Outrigger", 1, 0.0);
         rmSetObjectDefMinDistance(waterFlag, 10);
         rmSetObjectDefMaxDistance(waterFlag, 40);
        rmAddObjectDefConstraint(waterFlag, flagLand);
         rmPlaceObjectDefAtLoc(waterFlag, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i), 1);




	}

	rmSetStatusText("",0.6);






	/*
	==================
	resource placement
	==================
	*/




  	int eastmine = rmCreateObjectDef("east mines");
	rmAddObjectDefItem(eastmine, "guano", 1, 1.0);
	rmSetObjectDefMinDistance(eastmine, rmXFractionToMeters(0.0));
	rmSetObjectDefMaxDistance(eastmine, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(eastmine, avoidCoinMed);
	rmAddObjectDefConstraint(eastmine, avoidCenter);
	rmAddObjectDefConstraint(eastmine, cliffWater2);
	rmAddObjectDefConstraint(eastmine, avoidTownCenter);
	rmAddObjectDefConstraint(eastmine, circleConstraint);
	rmAddObjectDefConstraint(eastmine, avoidPlateau);	
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.5, 0.5, 8*cNumberNonGaiaPlayers);

	
    int muskHunts = rmCreateObjectDef("muskHunts");
	rmAddObjectDefItem(muskHunts, "guanaco", rmRandInt(12,13), 10.0);
	rmSetObjectDefCreateHerd(muskHunts, true);
	rmSetObjectDefMinDistance(muskHunts, 0);
	rmSetObjectDefMaxDistance(muskHunts, 10);
//	rmAddObjectDefConstraint(muskHunts, avoidWaterShort);	

//centre hunts
	//rmPlaceObjectDefAtLoc(muskHunts, 0, 0.7, 0.7, 1);
	//rmPlaceObjectDefAtLoc(muskHunts, 0, 0.3, 0.3, 1);
	if (PlayerNum >= 3)
{
	//rmPlaceObjectDefAtLoc(muskHunts, 0, 0.5, 0.5, 1);
}


    int elkHunts = rmCreateObjectDef("elkHunts");
	rmAddObjectDefItem(elkHunts, "Iguana", rmRandInt(2,2), 2.0);
	rmSetObjectDefCreateHerd(elkHunts, true);
	rmSetObjectDefMinDistance(elkHunts, 0);
	rmSetObjectDefMaxDistance(elkHunts, rmXFractionToMeters(0.47));
	rmAddObjectDefConstraint(elkHunts, circleConstraint);
	rmAddObjectDefConstraint(elkHunts, avoidTownCenter);
	rmAddObjectDefConstraint(elkHunts, avoidHunt);		//rmAddObjectDefConstraint(elkHunts, avoidBerries);
	rmAddObjectDefConstraint(elkHunts, avoidPlateau);
	rmAddObjectDefConstraint(elkHunts, avoidWaterShort);	
//	rmAddObjectDefConstraint(elkHunts, avoidCoin);	
	rmPlaceObjectDefAtLoc(elkHunts, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);





	rmSetStatusText("",0.7);

int avoidTPSocket =rmCreateTypeDistanceConstraint("avoid trade socket", "SocketTradeRoute", 16.0);



	//removes loop for faster loading times
	//for (j=0; < (6*cNumberNonGaiaPlayers)) {   
		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "ypTreeCeylon", rmRandInt(4,5), rmRandFloat(6.0,7.0));
		rmAddObjectDefItem(mapTrees, "Coconut", rmRandInt(2,3), rmRandFloat(4.0,6.0));
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(mapTrees, avoidTPSocket);
		rmAddObjectDefConstraint(mapTrees, avoidGold);
	  	rmAddObjectDefConstraint(mapTrees, avoidCoin);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenterSmall);	
		rmAddObjectDefConstraint(mapTrees, avoidNuggetSmall);	
		rmAddObjectDefConstraint(mapTrees, cliffWater2);
	rmAddObjectDefConstraint(mapTrees, avoidCenter);
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 50*cNumberNonGaiaPlayers);
	//}
		rmSetStatusText("",0.8);


		int marshPlants=rmCreateObjectDef("marshPlants");	
		rmAddObjectDefItem(marshPlants, "BananaBush", rmRandInt(4,4), rmRandFloat(2.0,2.0));
		rmAddObjectDefItem(marshPlants, "Iguana", rmRandInt(2,2), rmRandFloat(4.0,5.0));
		rmAddObjectDefToClass(marshPlants, rmClassID("classForest")); 
	rmSetObjectDefMinDistance(marshPlants, 0);
		rmSetObjectDefMaxDistance(marshPlants, rmXFractionToMeters(0.5));
	  	rmAddObjectDefConstraint(marshPlants, avoidFaleSmall);	
	rmAddObjectDefConstraint(marshPlants, avoidPlateauSmall);
		rmAddObjectDefConstraint(marshPlants, forestConstraint);
	rmPlaceObjectDefInArea(marshPlants, 0, jungleArea, 10*cNumberNonGaiaPlayers);


		int marshPlants2=rmCreateObjectDef("marshPlants2");	
		rmAddObjectDefItem(marshPlants2, "Breadfruit", rmRandInt(4,4), rmRandFloat(4.0,5.0));
		rmAddObjectDefToClass(marshPlants2, rmClassID("classForest")); 
	rmSetObjectDefMinDistance(marshPlants2, 0);
		rmSetObjectDefMaxDistance(marshPlants2, rmXFractionToMeters(0.5));
	  	rmAddObjectDefConstraint(marshPlants2, avoidFaleSmall);	
	rmAddObjectDefConstraint(marshPlants2, avoidPlateauSmall);
		rmAddObjectDefConstraint(marshPlants2, forestConstraint);
	rmPlaceObjectDefInArea(marshPlants2, 0, jungleArea, 10*cNumberNonGaiaPlayers);


		int bonusTrees=rmCreateObjectDef("bonusTrees");
		rmAddObjectDefItem(bonusTrees, "ypTreeCeylon", rmRandInt(6,7), rmRandFloat(4.0,4.0));
	//	rmAddObjectDefItem(bonusTrees, "BananaBush", rmRandInt(1,1), rmRandFloat(4.0,4.0));
	//	rmAddObjectDefItem(bonusTrees, "Breadfruit", rmRandInt(1,1), rmRandFloat(4.0,4.0));	
	rmAddObjectDefToClass(bonusTrees, rmClassID("classForest")); 
	rmAddObjectDefConstraint(bonusTrees, avoidFaleSmall);
	rmAddObjectDefConstraint(bonusTrees, avoidPlateauSmall);
	//rmAddObjectDefConstraint(bonusTrees, forestConstraint);
rmPlaceObjectDefInArea(bonusTrees, 0, jungleArea, 70*cNumberNonGaiaPlayers);


	int mapTrees2=rmCreateObjectDef("map trees 2");
		rmAddObjectDefItem(mapTrees2, "ypTreeBorneo", rmRandInt(4,5), rmRandFloat(6.0,12.0));
		rmAddObjectDefToClass(mapTrees2, rmClassID("classForest")); 	
		//rmSetObjectDefMinDistance(mapTrees2, 6);
		//rmSetObjectDefMaxDistance(mapTrees2, 45);
	rmAddObjectDefConstraint(mapTrees2, avoidWaterShort);
	rmAddObjectDefConstraint(mapTrees2, avoidBasaltShort);
		rmAddObjectDefConstraint(mapTrees2, forestConstraintShort);	
rmPlaceObjectDefInArea(mapTrees2, 0, centreMountains, 14*cNumberNonGaiaPlayers);






	//fish and their constraints placed together at the end for ease of removal
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "ypFishMolaMola", 20.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 10.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 90.0);

	int fishID=rmCreateObjectDef("fish Mahi");
	rmAddObjectDefItem(fishID, "ypFishMolaMola", 1, 4.0);
	rmAddObjectDefItem(fishID, "ypFishTuna", 1, 6.0);
//ypFishTuna
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 20*cNumberNonGaiaPlayers);


	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 14.0);

	int whaleVsWhaleID2 =rmCreateTypeDistanceConstraint("shark  v whale", "FishReefShark", 60.0);

	int wetNuggetID= rmCreateObjectDef("water nugget"); 
	rmAddObjectDefItem(wetNuggetID, "ypNuggetBoat", 1, 0.0); 
	rmSetObjectDefMinDistance(wetNuggetID, 0.0); 
	rmSetObjectDefMaxDistance(wetNuggetID, rmXFractionToMeters(0.5)); 
	rmAddObjectDefConstraint(wetNuggetID, avoidNugget); 
	rmAddObjectDefConstraint(wetNuggetID, circleConstraint);
	rmAddObjectDefConstraint(wetNuggetID, whaleLand);
//	rmAddObjectDefConstraint(wetNuggetID, avoidTradeRouteSmall);
//	rmAddObjectDefConstraint(wetNuggetID, avoidPatch); 
//	rmAddObjectDefConstraint(wetNuggetID, avoidPlateau);
//	rmAddObjectDefConstraint(wetNuggetID, cliffWater2);	
//	rmAddObjectDefConstraint(wetNuggetID, avoidCoin);	
	rmSetNuggetDifficulty(5, 5); 
	rmPlaceObjectDefAtLoc(wetNuggetID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);


		int duckBoys=rmCreateObjectDef("duckBoys");
		rmAddObjectDefItem(duckBoys, "FishReefShark", rmRandInt(1,2), rmRandFloat(3.0,5.0));
		rmAddObjectDefConstraint(duckBoys, whaleLand);
		rmAddObjectDefConstraint(duckBoys, whaleVsWhaleID2);
		rmSetObjectDefMinDistance(duckBoys, 0);
		rmSetObjectDefMaxDistance(duckBoys, rmXFractionToMeters(0.47));
		rmPlaceObjectDefAtLoc(duckBoys, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);



	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "MinkeWhale", 1, 0.0);

	rmPlaceObjectDefAtLoc(whaleID, 0, 0.18, 0.82, 1);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.82, 0.18, 1);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.95, 1);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.05, 1);

	
if (PlayerNum >= 4)
	{
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.05, 0.5, 1);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.95, 0.5, 1);
	}

		rmAddObjectDefConstraint(whaleID, whaleLand);
		rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
		rmSetObjectDefMinDistance(whaleID, 0);
		rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.47));

		rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);


	rmSetStatusText("",0.9);

  // King of the Hill (added 2026-11 for WoL): centre of the island, inside the ring of start positions
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
 
