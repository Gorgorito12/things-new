include "triggers\triggerLoader.xs";


/*
=============================
------Manicouagan Basin-----
	  ---dansil92---
=============================
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
		playerTiles = 11000;
	}else if (cNumberNonGaiaPlayers > 6){
		playerTiles = 10000;
	}
	
	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmSetMapSize(size, size);

     rmSetSeaType("New England Lake");
//	rmSetSeaType("Texas Pond");
// 	rmSetBaseTerrainMix("amazon grass");
	rmSetMapType("northwestTerritory");
	rmSetMapType("water");
	//rmSetWorldCircleConstraint(true);
     rmSetLightingSet("new england start");
	rmSetOceanReveal(true);

   // Init map.
   rmTerrainInitialize("land");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
 	  rmSetGlobalRain( 0.7 );
	//	rmSetSeaLevel(-1.6);

	// Sets up the rain triggers - rain hard for 20 seconds, then lightly, then hard again, then medium, then off.
	rmCreateTrigger("ChangeRain1");
	rmSwitchToTrigger(rmTriggerID("ChangeRain1"));
	rmSetTriggerActive(true);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1", 20);
	rmAddTriggerEffect("Render Rain");
	rmSetTriggerEffectParamFloat("Percent", 0.3);

	rmCreateTrigger("ChangeRain2");
	rmSwitchToTrigger(rmTriggerID("ChangeRain2"));
	rmSetTriggerActive(true);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1", 40);
	rmAddTriggerEffect("Render Rain");
	rmSetTriggerEffectParamFloat("Percent", 1.0);

	rmCreateTrigger("ChangeRain3");
	rmSwitchToTrigger(rmTriggerID("ChangeRain3"));
	rmSetTriggerActive(true);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1", 60);
	rmAddTriggerEffect("Render Rain");
	rmSetTriggerEffectParamFloat("Percent", 0.3);

	rmCreateTrigger("ChangeRain4");
	rmSwitchToTrigger(rmTriggerID("ChangeRain4"));
	rmSetTriggerActive(true);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1", 75);
	rmAddTriggerEffect("Render Rain");
	rmSetTriggerEffectParamFloat("Percent", 0.0);

	// Sets up the lighting change trigger - happy dawn in Canada :)
	rmCreateTrigger("Day");
   rmSwitchToTrigger(rmTriggerID("Day"));
   rmSetTriggerActive(true);
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1", 2);
   rmAddTriggerEffect("Set Lighting");
   rmSetTriggerEffectParam("SetName", "new england");
   rmSetTriggerEffectParamInt("FadeTime", 120);
   


		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 10.0);

        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 13.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 50.0);
		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 40.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 50.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 10.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "Mine", 55.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 5.0);

        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 8.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 38.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 50.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 60.0);
       
	int PlayerNum = cNumberNonGaiaPlayers;
	int TeamNum = cNumberTeams;
	int numPlayer = cNumberPlayers;


    
 // =============Player placement ======================= 
    float spawnSwitch = rmRandFloat(0,1.2);


	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){

	if (PlayerNum == 2)
	{
	rmPlacePlayer(1, 0.5, 0.86);
	rmPlacePlayer(2, 0.5, 0.14);	}

			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.65, 0.84);
			rmPlacePlayersCircular(0.36, 0.36, 0.0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.15, 0.34);
			rmPlacePlayersCircular(0.36, 0.36, 0.0);
		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
		rmPlacePlayer(2, 0.5, 0.86);
		rmPlacePlayer(1, 0.5, 0.14);
	}

			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.65, 0.84);
			rmPlacePlayersCircular(0.36, 0.36, 0.0);
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.15, 0.34);
			rmPlacePlayersCircular(0.36, 0.36, 0.0);

		}
	}else{
	//*************ffa placement********
		rmPlacePlayersCircular(0.36, 0.36, 0.00);
	}


		
        chooseMercs();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	   rmSetAreaMix(continent2, "nwt_grass1");     
 //  rmSetAreaTerrainType(continent2, "carolinas\groundforest_car");
        rmSetAreaBaseHeight(continent2, 3.0);
        rmSetAreaCoherence(continent2, 1.0);
        rmSetAreaSmoothDistance(continent2, 10);
        rmSetAreaHeightBlend(continent2, 2);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 10);
        rmSetAreaElevationVariation(continent2, 5);
        rmSetAreaElevationPersistence(continent2, .2);
        rmSetAreaElevationOctaves(continent2, 5);
        rmSetAreaElevationMinFrequency(continent2, 0.04);
        rmSetAreaElevationType(continent2, cElevTurbulence);  
        rmBuildArea(continent2);    

		int classPatch = rmDefineClass("patch");
		int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 22.0);
		int classCenter = rmDefineClass("center");
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 2.0);
		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
        
		

		rmSetStatusText("",0.2);


		int waterBasin=rmCreateArea("waterBasin");
        rmSetAreaLocation(waterBasin, 0.5, 0.5);
       // rmAddAreaInfluenceSegment(waterBasin, 0.0, 0.1, 1.0, 0.1);
        rmSetAreaSize(waterBasin, .4, .4);      
        rmSetAreaWaterType(waterBasin, "Northwest Territory Water");
        rmSetAreaBaseHeight(waterBasin, 0.0);
        rmSetAreaCoherence(waterBasin, .92);
        rmBuildArea(waterBasin);



		int center = rmCreateArea("center");
		rmAddAreaToClass(center, rmClassID("center"));
        rmSetAreaSize(center, .21, .21);
        rmSetAreaLocation(center, 0.5, 0.5);
	        rmSetAreaBaseHeight(center, 3.0);
	   rmSetAreaMix(center, "nwt_grass1"); 
        rmSetAreaBaseHeight(center, 2.0);    
        rmSetAreaCoherence(center, 0.84);
        rmBuildArea(center);   



	//OBJECTS   




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
		
	nativeID0 = rmCreateGrouping("native site 1", "native cree village 2");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 0.00);
	rmAddGroupingToClass(nativeID0, rmClassID("patch"));

	nativeID1 = rmCreateGrouping("native site 2", "native cree village 3");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 0.00);
	rmAddGroupingToClass(nativeID1, rmClassID("patch"));

//========place=====
//top & bottom
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.4, 0.6);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.4, 0.37);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.6, 0.4);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.6, 0.63);







		rmSetStatusText("",0.3);
/*
========================================
LAND FOR TCS, CONNECT TO CENTRE
========================================				
*/


for(i=1; < cNumberNonGaiaPlayers + 1) {

    int PlayerArea1 = rmCreateArea("NeedLand1"+i);
        rmSetAreaSize(PlayerArea1, rmAreaTilesToFraction(900), rmAreaTilesToFraction(930));
        rmSetAreaBaseHeight(PlayerArea1, 1.0);
		rmAddAreaToClass(PlayerArea1, rmClassID("classPlateau"));
//        rmSetAreaTerrainType(PlayerArea1, "sonora\ground7_son");
       rmSetAreaHeightBlend(PlayerArea1, 1);
        rmSetAreaLocation(PlayerArea1, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmSetAreaCoherence(PlayerArea1, 0.7);
        rmBuildArea(PlayerArea1);

//*********connections**********
	if (cNumberTeams == 2){

	int connection1	= rmCreateConnection("make paths centre"+i);
	rmSetConnectionType(connection1, cConnectAreas, false, 1.0);
	rmAddConnectionArea(connection1, PlayerArea1);
	rmAddConnectionArea(connection1, center);
	rmSetConnectionPositionVariance(connection1, 0.0);
	rmSetConnectionBaseHeight(connection1, 1.0);
	rmSetConnectionCoherence(connection1, 0.8);
	//rmSetConnectionHeightBlend(connection1, 1);
	rmSetConnectionWidth(connection1, 26+cNumberNonGaiaPlayers, 1.0);
	rmBuildConnection(connection1);
}
} //dont touch, it works

		

	if (PlayerNum == 2)
{
  	int smollMines = rmCreateObjectDef("competitive gold");
	rmAddObjectDefItem(smollMines, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(smollMines, 0.0);
	rmSetObjectDefMaxDistance(smollMines, 0.0);
//centre mines
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.5, 0.5, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.31, 0.44, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.69, 0.56, 1);

//edge "anchor" mines
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.32, 0.88, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.68, 0.12, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.72, 0.88, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.28, 0.12, 1);
//second mines
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.47, 0.65, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.53, 0.35, 1);

}





		//starting objects
		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "mine", 1, 1.0);
        rmSetObjectDefMinDistance(goldID, 10.0);
        rmSetObjectDefMaxDistance(goldID, 10.0);
       
        int goldID2 = rmCreateObjectDef("starting gold 2");
        rmAddObjectDefItem(goldID2, "mine", 1, 1.0);
        rmSetObjectDefMinDistance(goldID2, 0.0);
        rmSetObjectDefMaxDistance(goldID2, 1.0);
       // rmAddObjectDefConstraint(goldID2, avoidCoin);
 
        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "BerryBush", 0, 6.0);
        rmSetObjectDefMinDistance(berryID, 8.0);
        rmSetObjectDefMaxDistance(berryID, 12.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "TreeNorthwestTerritory", rmRandInt(6,9), 10.0);
	rmAddObjectDefItem(treeID, "Mushrooms", rmRandInt(4,4), 7.0);

        rmSetObjectDefMinDistance(treeID, 12.0);
        rmSetObjectDefMaxDistance(treeID, 18.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
	rmAddObjectDefConstraint(treeID, avoidWaterShort);	

 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "Caribou", 6, 8.0);
        rmSetObjectDefMinDistance(foodID, 10.0);
        rmSetObjectDefMaxDistance(foodID, 10.0);
        rmSetObjectDefCreateHerd(foodID, true);
	rmAddObjectDefConstraint(foodID, avoidWaterShort);	
 

        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "Elk", 12, 8.0);
        rmSetObjectDefMinDistance(foodID2, 40.0);
        rmSetObjectDefMaxDistance(foodID2, 40.0);
        rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, avoidWaterShort);	
	rmAddObjectDefConstraint(foodID2, circleConstraint);


                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "Caribou", 8, 8.0);
        rmSetObjectDefMinDistance(foodID3, 65.0);
        rmSetObjectDefMaxDistance(foodID3, 65.0);
        rmSetObjectDefCreateHerd(foodID3, true);
	rmAddObjectDefConstraint(foodID3, avoidWaterShort);
	rmAddObjectDefConstraint(foodID3, avoidHunt);
	rmAddObjectDefConstraint(foodID3, circleConstraint);
	


	int extraberrywagon=rmCreateObjectDef("JapAn cAnT hUnT");
  rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
  rmSetObjectDefMinDistance(extraberrywagon, 6.0);
  rmSetObjectDefMaxDistance(extraberrywagon, 7.0);


	int flagLand = rmCreateTerrainDistanceConstraint("flags dont like land", "land", true, 3.0);


		rmSetStatusText("",0.5);      

	if (PlayerNum == 2){

        rmPlaceObjectDefAtLoc(goldID2, 0, 0.5, 0.91, 1 );
        rmPlaceObjectDefAtLoc(goldID2, 0, 0.5, 0.09, 1 );

}

    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 5.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 10.0);
        rmSetAreaSize(startID, .15, .17);              	rmSetAreaBaseHeight(startID, 3.0);

		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		if (PlayerNum >= 3)
	{
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	}
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		int waterFlag = rmCreateObjectDef("HC water flag "+i);
         rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 5.0);
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

int avoidCree =rmCreateTypeDistanceConstraint("avoid cree socket", "SocketCree", 18.0);

	
    int pronghornHunts = rmCreateObjectDef("pronghornHunts");
	rmAddObjectDefItem(pronghornHunts, "Caribou", rmRandInt(9,10), 11.0);
	rmSetObjectDefCreateHerd(pronghornHunts, true);
	rmSetObjectDefMinDistance(pronghornHunts, 0);
	rmSetObjectDefMaxDistance(pronghornHunts, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(pronghornHunts, circleConstraint);
	rmAddObjectDefConstraint(pronghornHunts, avoidTownCenterMore);
	rmAddObjectDefConstraint(pronghornHunts, avoidHunt);
//	rmAddObjectDefConstraint(pronghornHunts, avoidCenter);
//	rmAddObjectDefConstraint(pronghornHunts, avoidPlateau);	
	rmPlaceObjectDefAtLoc(pronghornHunts, 0, 0.5, 0.5, 11*cNumberNonGaiaPlayers);



  	int islandminesID = rmCreateObjectDef("island silver");
	rmAddObjectDefItem(islandminesID, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(islandminesID, 0.0);
	rmSetObjectDefMaxDistance(islandminesID, rmXFractionToMeters(0.43));
	rmAddObjectDefConstraint(islandminesID, avoidCoinMed);
	rmAddObjectDefConstraint(islandminesID, avoidTownCenterMore);
	rmAddObjectDefConstraint(islandminesID, avoidSocket);
//	rmAddObjectDefConstraint(islandminesID, avoidCenter);
//	rmAddObjectDefConstraint(islandminesID, avoidPlateau);	
	rmAddObjectDefConstraint(islandminesID, avoidWaterShort);
//	rmAddObjectDefConstraint(islandminesID, forestConstraintShort);
	rmAddObjectDefConstraint(islandminesID, circleConstraint);
	rmPlaceObjectDefAtLoc(islandminesID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);
 
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
	rmAddObjectDefConstraint(nuggetID, avoidWaterShort);	
	//rmAddObjectDefConstraint(nuggetID, avoidCenter);	
	rmSetNuggetDifficulty(1, 2); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);   
	rmSetStatusText("",0.7);


	//removes loop for faster loading times
	//for (j=0; < (14*cNumberNonGaiaPlayers)) {   
		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "TreeNorthwestTerritory", rmRandInt(6,7), rmRandFloat(11.0,13.0));
	rmAddObjectDefItem(mapTrees, "UnderbrushNewEngland", rmRandInt(3,4), rmRandFloat(7.0,8.0));
	rmAddObjectDefItem(mapTrees, "berrybush", rmRandInt(1,1), 11.0);

		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.47));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidSocket);	rmAddObjectDefConstraint(mapTrees, circleConstraint);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees, avoidCoin);	
		rmAddObjectDefConstraint(mapTrees, avoidWaterShort);	
	  	rmAddObjectDefConstraint(mapTrees, avoidCree);
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 100*cNumberNonGaiaPlayers);
	//}
		rmSetStatusText("",0.8);


	int avoidBighorn=rmCreateTypeDistanceConstraint("bighorn avoids food", "Moose", 65.0);


    for(i=1; < cNumberNonGaiaPlayers*5) {
  	int cliffSheep = rmCreateObjectDef("water Moose"+i);
	rmAddObjectDefItem(cliffSheep, "Moose", 2, 3.0);
	rmSetObjectDefMinDistance(cliffSheep, 0.0);
	rmSetObjectDefMaxDistance(cliffSheep, rmXFractionToMeters(0.42));
	rmAddObjectDefConstraint(cliffSheep, waterHunt);
	rmAddObjectDefConstraint(cliffSheep, avoidTownCenter);	
	rmAddObjectDefConstraint(cliffSheep, avoidBighorn);	
	rmPlaceObjectDefInRandomAreaOfClass(cliffSheep, 0, rmClassID("classPlateau"), 1);
}



	//fish and their constraints placed together at the end for ease of removal


	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 2.0);

	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "FishBass", 9.0);


	int fishID=rmCreateObjectDef("fish Mahi");
	rmAddObjectDefItem(fishID, "FishBass", 1, 1.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.99));
	rmAddObjectDefConstraint(fishID, fishLand);
	rmAddObjectDefConstraint(fishID, fishVsFishID);

	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 35*cNumberNonGaiaPlayers);   

//******pretty stuff******

	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 5.0);

		int duckBoys=rmCreateObjectDef("duckBoys");
		rmAddObjectDefItem(duckBoys, "DuckFamily", rmRandInt(1,2), rmRandFloat(3.0,5.0));
		rmAddObjectDefConstraint(duckBoys, whaleLand);
		rmSetObjectDefMinDistance(duckBoys, 0);
		rmSetObjectDefMaxDistance(duckBoys, rmXFractionToMeters(0.47));
		rmPlaceObjectDefAtLoc(duckBoys, 0, 0.5, 0.5, 1.5*cNumberNonGaiaPlayers);

		int marshPlants=rmCreateObjectDef("marshPlants");
		rmAddObjectDefItem(marshPlants, "RiverPropsNWTerritory", rmRandInt(4,5), rmRandFloat(8.0,9.0));
//		rmAddObjectDefConstraint(marshPlants, forestConstraint);
		rmSetObjectDefMinDistance(marshPlants, 0);
		rmSetObjectDefMaxDistance(marshPlants, rmXFractionToMeters(0.47));
		rmAddObjectDefConstraint(marshPlants, waterHunt);
	  	rmAddObjectDefConstraint(marshPlants, avoidCoinMed);	
	rmAddObjectDefConstraint(marshPlants, circleConstraint);
		rmPlaceObjectDefAtLoc(marshPlants, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);



  // King of the Hill (added 2026-11 for WoL): the land farthest from every Town Center around the crater lake
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
 
