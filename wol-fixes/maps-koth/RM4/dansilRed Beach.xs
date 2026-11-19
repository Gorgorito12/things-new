include "triggers\triggerLoader.xs";

/* 
=========================================
			Red Beach
 		     by dansil92
=========================================
*/


include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
 
void main(void) {
    wotta_triggers();
	rmSetStatusText("",0.01);
   // Picks the map size
	int playerTiles=11000;
	if (cNumberNonGaiaPlayers > 4){
		playerTiles = 9600;
	}else if (cNumberNonGaiaPlayers > 6){
		playerTiles = 8000;
	}
	
	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmSetMapSize(size, size);

     rmSetSeaType("red beach");
//	rmSetSeaType("Texas Pond");
// 	rmSetBaseTerrainMix("amazon grass");
	rmSetMapType("yellowRiver");
	//rmSetMapType("tropical");
	rmSetMapType("water");
	rmSetWorldCircleConstraint(true);
   rmSetLightingSet("st_petersburg");
	rmSetOceanReveal(true);

   // Init map.
   rmTerrainInitialize("water");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
 	  rmSetGlobalRain( 0.7 );
		rmSetSeaLevel(-1.6);




		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 10.0);

        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.49), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 22.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 50.0);
		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 50.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "CoffeePlant", 10.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "CoffeePlant", 42.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 3.0);

        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 8.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 35.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 42.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 40.0);
       
	int PlayerNum = cNumberNonGaiaPlayers;
	int TeamNum = cNumberTeams;
	int numPlayer = cNumberPlayers;


    
 // =============Player placement ======================= 
    float spawnSwitch = rmRandFloat(0,1.2);


	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){

	if (PlayerNum == 2)
	{
	rmPlacePlayersCircular(0.32, 0.32, 0.02);
	}

			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.65, 0.8);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.15, 0.3);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
		rmPlacePlayersCircular(0.32, 0.32, 0.02);
	}

			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.65, 0.8);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.15, 0.3);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);

		}
	}else{
		rmPlacePlayersCircular(0.36, 0.36, 0.02);
	}
		
        chooseMercs();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
        rmSetAreaMix(continent2, "redbeach_grass");
        rmSetAreaBaseHeight(continent2, 2.1);
        rmSetAreaCoherence(continent2, .9);
        rmSetAreaSmoothDistance(continent2, 10);
        rmSetAreaHeightBlend(continent2, 1);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 8);
        rmSetAreaElevationVariation(continent2, 7);
        rmSetAreaElevationPersistence(continent2, .1);
        rmSetAreaElevationOctaves(continent2, 5);
        rmSetAreaElevationMinFrequency(continent2, 0.04);
        rmSetAreaElevationType(continent2, cElevTurbulence);  
        rmBuildArea(continent2);    

		int classPatch = rmDefineClass("patch");
		int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 10.0);
		int classCenter = rmDefineClass("center");
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 2.0);
		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
        
		int center = rmCreateArea("center");
		//rmAddAreaToClass(center, rmClassID("center"));
        rmSetAreaSize(center, .10, .11);
        rmSetAreaLocation(center, 0.5, 0.5);
	        rmSetAreaBaseHeight(center, 3.0);
        rmSetAreaCoherence(center, 0.7);
        rmBuildArea(center);   





		rmSetStatusText("",0.2);



	//OBJECTS   



		int AztecVillage=rmCreateArea("AztecVillage");
        rmSetAreaLocation(AztecVillage, 0.5, 0.5); 
	//rmSetAreaTerrainType(AztecVillage, "Amazon\ground4_ama");      
        rmSetAreaSize(AztecVillage, .02, .02); 
        rmSetAreaBaseHeight(AztecVillage, 1.7);
        rmSetAreaHeightBlend(AztecVillage, 2);
        rmSetAreaCoherence(AztecVillage, 0.9);
        rmBuildArea(AztecVillage);








// BUILD NATIVE SITES

	//Choose Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int subCiv3=-1;

   if (rmAllocateSubCivs(4) == true)
   {
      subCiv0=rmGetCivID("Shaolin");
      rmEchoInfo("subCiv0 is Shaolin "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Shaolin");

		subCiv1=rmGetCivID("Shaolin");
      rmEchoInfo("subCiv1 is Shaolin "+subCiv1);
		if (subCiv1 >= 0)
			 rmSetSubCiv(1, "Aztecs");
	 
		subCiv2=rmGetCivID("Zen");
      rmEchoInfo("subCiv2 is Zen "+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Zen");

		subCiv3=rmGetCivID("Zen");
      rmEchoInfo("subCiv3 is Zen "+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Zen");
	}
	
	// Set up Natives	
	int nativeID0 = -1;
    int nativeID1 = -1;
	int nativeID2 = -1;
    int nativeID3 = -1;


		nativeID0 = rmCreateGrouping("native site 1", "native shaolin temple yr 01");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 2.00);
	rmAddGroupingToClass(nativeID0, rmClassID("patch"));

	nativeID1 = rmCreateGrouping("native site 2", "native zen temple yr 05");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 2.00);
	rmAddGroupingToClass(nativeID1, rmClassID("patch"));


//========place=====
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.52, 0.62);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.48, 0.38);

	if (cNumberNonGaiaPlayers >= 3){
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.4, 0.51);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.6, 0.49);
}



		rmSetStatusText("",0.3);
/*
========================================
LAND FOR TCS, CONNECT TO CENTRE
========================================				
*/
for(i=1; < cNumberNonGaiaPlayers + 1) {

    int PlayerArea1 = rmCreateArea("NeedLand1"+i);
        rmSetAreaSize(PlayerArea1, rmAreaTilesToFraction(430), rmAreaTilesToFraction(430));
        rmSetAreaBaseHeight(PlayerArea1, 1.0);
		rmAddAreaToClass(PlayerArea1, rmClassID("classPlateau"));
//        rmSetAreaTerrainType(PlayerArea1, "sonora\ground7_son");
       rmSetAreaHeightBlend(PlayerArea1, 1);
        rmSetAreaLocation(PlayerArea1, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmSetAreaCoherence(PlayerArea1, 0.7);
        rmBuildArea(PlayerArea1);

//*********connections**********

	int connection1	= rmCreateConnection("make paths centre"+i);
	rmSetConnectionType(connection1, cConnectAreas, false, 1.0);
	rmAddConnectionArea(connection1, PlayerArea1);
	rmAddConnectionArea(connection1, AztecVillage);
	rmSetConnectionPositionVariance(connection1, 0.0);
	rmSetConnectionBaseHeight(connection1, 1.0);
	rmSetConnectionCoherence(connection1, 0.8);
	rmSetConnectionHeightBlend(connection1, 1);
	rmSetConnectionWidth(connection1, 18+cNumberNonGaiaPlayers, 1.0);
	rmBuildConnection(connection1);

} //dont touch, it works

		



		//starting objects
		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "CoffeePlant", 4, 3.0);
        rmSetObjectDefMinDistance(goldID, 12.0);
        rmSetObjectDefMaxDistance(goldID, 12.0);
       
        int goldID2 = rmCreateObjectDef("starting gold 2");
        rmAddObjectDefItem(goldID2, "CoffeePlant", 1, 16.0);
        rmSetObjectDefMinDistance(goldID2, 12.0);
        rmSetObjectDefMaxDistance(goldID2, 12.0);
        rmAddObjectDefConstraint(goldID2, avoidCoin);
 
        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "KiwiFruit", 5, 3.0);
        rmSetObjectDefMinDistance(berryID, 16.0);
        rmSetObjectDefMaxDistance(berryID, 16.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "ypTreeBamboo", rmRandInt(14,15), 7.0);
        rmSetObjectDefMinDistance(treeID, 12.0);
        rmSetObjectDefMaxDistance(treeID, 18.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "ypMarcoPoloSheep", 6, 8.0);
        rmSetObjectDefMinDistance(foodID, 10.0);
        rmSetObjectDefMaxDistance(foodID, 10.0);
        rmSetObjectDefCreateHerd(foodID, false);
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "ypIbex", 12, 8.0);
        rmSetObjectDefMinDistance(foodID2, 40.0);
        rmSetObjectDefMaxDistance(foodID2, 40.0);
        rmSetObjectDefCreateHerd(foodID2, true);
                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "ypSerow", 8, 8.0);
        rmSetObjectDefMinDistance(foodID3, 65.0);
        rmSetObjectDefMaxDistance(foodID3, 65.0);
        rmSetObjectDefCreateHerd(foodID3, true);


		rmSetStatusText("",0.5);      


    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 1.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 1.0);
        rmSetAreaSize(startID, .15, .17);              	rmSetAreaBaseHeight(startID, 3.0);

		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        //rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));


	}
	rmSetStatusText("",0.6);


	/*
	==================
	resource placement
	==================
	*/
	
    int pronghornHunts = rmCreateObjectDef("pronghornHunts");
	rmAddObjectDefItem(pronghornHunts, "ypIbex", rmRandInt(5,5), 7.0);
	rmSetObjectDefCreateHerd(pronghornHunts, true);
	rmSetObjectDefMinDistance(pronghornHunts, 0);
	rmSetObjectDefMaxDistance(pronghornHunts, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(pronghornHunts, circleConstraint);
	rmAddObjectDefConstraint(pronghornHunts, avoidTownCenterMore);
	rmAddObjectDefConstraint(pronghornHunts, avoidHunt);
	rmAddObjectDefConstraint(pronghornHunts, avoidWaterShort);
	rmAddObjectDefConstraint(pronghornHunts, avoidPatch);	
	rmPlaceObjectDefAtLoc(pronghornHunts, 0, 0.5, 0.5, 11*cNumberNonGaiaPlayers);



  	int islandminesID = rmCreateObjectDef("island silver");
	rmAddObjectDefItem(islandminesID, "CoffeePlant", 3, 3.0);
	rmSetObjectDefMinDistance(islandminesID, 0.0);
	rmSetObjectDefMaxDistance(islandminesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(islandminesID, avoidCoinMed);
	rmAddObjectDefConstraint(islandminesID, avoidTownCenterMore);
	//rmAddObjectDefConstraint(islandminesID, avoidSocket);
	//rmAddObjectDefConstraint(islandminesID, avoidCenter);
	rmAddObjectDefConstraint(islandminesID, avoidPatch);	
	rmAddObjectDefConstraint(islandminesID, avoidWaterShort);
	rmAddObjectDefConstraint(islandminesID, forestConstraintShort);
	rmAddObjectDefConstraint(islandminesID, circleConstraint);
	rmPlaceObjectDefAtLoc(islandminesID, 0, 0.5, 0.5, 14*cNumberNonGaiaPlayers);
 
	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
	rmSetObjectDefMinDistance(nuggetID, 0.0); 
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.44)); 
	rmAddObjectDefConstraint(nuggetID, avoidNugget); 
	rmAddObjectDefConstraint(nuggetID, circleConstraint);
	rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetID, forestConstraintShort);
	rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(nuggetID, avoidWaterShort); 
	rmAddObjectDefConstraint(nuggetID, avoidPatch);		//rmAddObjectDefConstraint(nuggetID, avoidCenter);	
	rmSetNuggetDifficulty(1, 1); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);   

	rmSetStatusText("",0.7);
	//removes loop for faster loading times
	//for (j=0; < (14*cNumberNonGaiaPlayers)) {   
		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "ypTreeYellowRiver", rmRandInt(12,12), rmRandFloat(10.0,12.0));
		rmAddObjectDefItem(mapTrees, "ypTreeBamboo", rmRandInt(4,5), rmRandFloat(10.0,12.0));
		rmAddObjectDefItem(mapTrees, "UnderbrushYellowRiver", rmRandInt(4,5), rmRandFloat(10.0,12.0));
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidCoin);
	  	rmAddObjectDefConstraint(mapTrees, circleConstraint);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees, avoidPatch);	
		//rmAddObjectDefConstraint(mapTrees, avoidWaterShort);	
		rmAddObjectDefConstraint(mapTrees, avoidCenter);
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 100*cNumberNonGaiaPlayers);
	//}
		rmSetStatusText("",0.8);

  // King of the Hill (added 2026-11 for WoL): centre of the marsh, beside the native villages
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

	//fish and their constraints placed together at the end for ease of removal
		}
 
