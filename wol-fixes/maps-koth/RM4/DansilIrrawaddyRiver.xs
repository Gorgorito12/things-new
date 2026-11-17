/*
=============================
	Irrawaddy
	Original Ganges River
=============================
*/

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
include "triggers\triggerLoader.xs";
 
void main(void) {
	rmSetStatusText("",0.01);
   // Picks the map size
	int playerTiles=12000;
	if (cNumberNonGaiaPlayers > 4){
		playerTiles = 11000;
	}else if (cNumberNonGaiaPlayers > 6){
		playerTiles = 11000;
	}
	
	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmSetMapSize(size*1.15, size);

	rmSetMapType("land");
        rmSetMapType("grass");
        rmSetMapType("yellowRiver");
       	rmTerrainInitialize("grass");
		rmSetLightingSet("301a_malta");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
	rmSetSeaLevel(2.0);
		rmSetSeaType("Pampas River");
	string riverType = "Yellow River";


		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 8.0);

        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.46), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 24.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 50.0);
		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 50.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 10.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "Mine", 58.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 15.0);

        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 10.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 35.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 40.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 40.0);

int stayWest = rmCreatePieConstraint("Stay West",0.47,0.53, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(225),rmDegreesToRadians(45));
int stayEast = rmCreatePieConstraint("Stay East",0.53,0.47, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(45),rmDegreesToRadians(225));

   

	int PlayerNum = cNumberNonGaiaPlayers;

    
 	// Player placing  
    float spawnSwitch = rmRandFloat(0,1.2);


	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){

	if (PlayerNum == 2)
	{
			rmPlacePlayer(1, 0.4, 0.2);
			rmPlacePlayer(2, 0.6, 0.8);
	}

	if (PlayerNum == 4)
	{			
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.35, 0.2, 0.65, 0.2, 0, 0);
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.35, 0.8, 0.65, 0.8, 0, 0);

	}

			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.28, 0.2, 0.75, 0.2, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.28, 0.8, 0.75, 0.8, 0, 0);

		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
			rmPlacePlayer(2, 0.6, 0.2);
			rmPlacePlayer(1, 0.4, 0.8);
	}

	if (PlayerNum == 4)
	{			
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.35, 0.2, 0.65, 0.2, 0, 0);
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.35, 0.8, 0.65, 0.8, 0, 0);

	}

			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.28, 0.2, 0.75, 0.2, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.28, 0.8, 0.75, 0.8, 0, 0);
		}
	}else{

	
			rmPlacePlayer(1, 0.85, 0.25);
			rmPlacePlayer(2, 0.15, 0.75);
			rmPlacePlayer(3, 0.15, 0.25);
			rmPlacePlayer(4, 0.85, 0.75);



	if (PlayerNum == 5){
			rmPlacePlayer(5, 0.5, 0.12);
}
	if (PlayerNum == 6){
			rmPlacePlayer(5, 0.5, 0.12);
			rmPlacePlayer(6, 0.5, 0.88);
}
	if (PlayerNum == 7){
			rmPlacePlayer(5, 0.65, 0.12);
			rmPlacePlayer(6, 0.35, 0.12);
			rmPlacePlayer(7, 0.5, 0.88);

}
	if (PlayerNum == 8){
			rmPlacePlayer(5, 0.65, 0.12);
			rmPlacePlayer(6, 0.35, 0.12);
			rmPlacePlayer(7, 0.65, 0.88);
			rmPlacePlayer(8, 0.35, 0.88);
}

	}

		
	chooseMercs();
wotta_triggers();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
 //       rmSetAreaTerrainType(continent2, "great_plains\ground5_gp");
	   rmSetAreaMix(continent2, "yellow_river_b");
        rmSetAreaBaseHeight(continent2, -1.0);
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

		




 
				

	//===================River=====================

	int TeamNum = cNumberTeams;
	int numPlayer = cNumberPlayers;
    int seasonSwitch = rmRandInt(1,6);


	int riverID = rmRiverCreate(-5, riverType, 8, 8, (8+PlayerNum/2), (9+PlayerNum/2)); 

  rmRiverAddWaypoint(riverID, 0.0, 0.5);
  rmRiverAddWaypoint(riverID, 0.165, .54);
  rmRiverAddWaypoint(riverID, 0.33, .43);
  rmRiverAddWaypoint(riverID, 0.5, .5);
  rmRiverAddWaypoint(riverID, 0.665, .57);
  rmRiverAddWaypoint(riverID, 0.83, .46);
  rmRiverAddWaypoint(riverID, 1.0, 0.5);        
   

	rmRiverSetBankNoiseParams(riverID, 0.07, 2, 15.0, 15.0, 0.667, 1.8);
	rmRiverSetShallowRadius(riverID, 14);

//seasonSwitch- 1 completely shallow
//seasonSwitch- 2,3,4,5,6 staggered shallows

if (seasonSwitch >=1){
	if (PlayerNum >= 6)
	{
		rmRiverAddShallow(riverID, 0.12);
		rmRiverAddShallow(riverID, 0.32);
		rmRiverAddShallow(riverID, 0.52);
		rmRiverAddShallow(riverID, 0.74);
	}
	else
	{
		rmRiverAddShallow(riverID, 0.12);
		rmRiverAddShallow(riverID, 0.41);
		rmRiverAddShallow(riverID, 0.67);
	}
}
if (seasonSwitch == 0){
	rmRiverSetShallowRadius(riverID, size);

		rmRiverAddShallow(riverID, 0.5);
}
	rmRiverBuild(riverID);

//constraint for cliff

//int avoidRiver = rmCreateAreaDistanceConstraint("Avoid Peninsula", riverID, 14);



        int cliffNE = rmCreateArea("cliffNE");
        rmSetAreaSize(cliffNE, 0.5, 0.5);
        rmSetAreaLocation(cliffNE, 0.5, 0.8);
 //      rmSetAreaTerrainType(cliffNE, "great_plains\groundforest_gp");
 //       rmSetAreaBaseHeight(cliffNE, 1.0);
        rmSetAreaCoherence(cliffNE, 0.79);
		rmAddAreaConstraint(cliffNE, avoidWaterShort);
		rmAddAreaConstraint(cliffNE, avoidSocket);
		rmAddAreaConstraint(cliffNE, avoidTradeRouteSmall);
		rmSetAreaCliffType(cliffNE, "Yellow River");
		rmSetAreaCliffEdge(cliffNE, 8, 0.07, 0.0, 0.0, 2); 
		rmSetAreaCliffPainting(cliffNE, true, true, true, 1.5, true);
		rmSetAreaCliffHeight(cliffNE, 4, 0.1, 0.5);
        rmBuildArea(cliffNE);    



        int cliffSW = rmCreateArea("cliffSW");
        rmSetAreaSize(cliffSW, 0.5, 0.5);
        rmSetAreaLocation(cliffSW, 0.5, 0.2);
 //      rmSetAreaTerrainType(cliffSW, "great_plains\groundforest_gp");
 //       rmSetAreaBaseHeight(cliffSW, 1.0);
        rmSetAreaCoherence(cliffSW, 0.79);
		rmAddAreaConstraint(cliffSW, avoidWaterShort);
		rmAddAreaConstraint(cliffSW, avoidTradeRouteSmall);
		rmAddAreaConstraint(cliffSW, avoidSocket);
		rmSetAreaCliffType(cliffSW, "Yellow River");
		rmSetAreaCliffEdge(cliffSW, 8, 0.07, 0.0, 0.0, 2); 
		rmSetAreaCliffPainting(cliffSW, true, true, true, 1.5, true);
		rmSetAreaCliffHeight(cliffSW, 4, 0.1, 0.5);
        rmBuildArea(cliffSW);    



		rmSetStatusText("",0.3);





// BUILD NATIVE SITES

	//Choose Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int subCiv3=-1;

   if (rmAllocateSubCivs(4) == true)
   {
      subCiv0=rmGetCivID("Sufi");
      rmEchoInfo("subCiv0 is Sufi "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Sufi");

		subCiv1=rmGetCivID("Sufi");
      rmEchoInfo("subCiv1 is Sufi"+subCiv1);
		if (subCiv1 >= 0)
			 rmSetSubCiv(1, "Sufi");
	 
		subCiv2=rmGetCivID("Udasi");
      rmEchoInfo("subCiv2 is Udasi"+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Udasi");

		subCiv3=rmGetCivID("Udasi");
      rmEchoInfo("subCiv3 is Udasi"+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Udasi");
	}
	
	// Set up Natives	
	int nativeID0 = -1;
    int nativeID1 = -1;
	int nativeID2 = -1;
    int nativeID3 = -1;
		
	nativeID0 = rmCreateGrouping("native site 1", "native sufi mosque borneo 5");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 0.00);
	rmAddGroupingToClass(nativeID0, rmClassID("classPlateau"));

	nativeID1 = rmCreateGrouping("native site 2", "native Udasi village himal 2");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 0.00);
	rmAddGroupingToClass(nativeID1, rmClassID("classPlateau"));

	int nativeSwitcher = rmRandInt(0,1);

	if (cNumberTeams == 2){
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.85, 0.25);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.2, 0.8);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.2, 0.2);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.85, 0.75);
	}else{
//ffa
	if (nativeSwitcher == 1){
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.7, 0.35);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.4, 0.68);
}else{
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.7, 0.35);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.4, 0.68);

}
	}


		rmSetStatusText("",0.4);
		//starting objects

	int flagLand = rmCreateTerrainDistanceConstraint("flags dont like land", "land", true, 6.0);


		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
	rmAddObjectDefConstraint(playerStart, avoidWaterShort);

       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "mine", 1, 3.0);
        rmSetObjectDefMinDistance(goldID, 9.0);
        rmSetObjectDefMaxDistance(goldID, 10.0);
       
        int goldID2 = rmCreateObjectDef("starting gold 2");
        rmAddObjectDefItem(goldID2, "mine", 1, 16.0);
        rmSetObjectDefMinDistance(goldID2, 12.0);
        rmSetObjectDefMaxDistance(goldID2, 12.0);
        rmAddObjectDefConstraint(goldID2, avoidCoin);
 
        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "BerryBush", 8, 6.0);
        rmSetObjectDefMinDistance(berryID, 8.0);
        rmSetObjectDefMaxDistance(berryID, 12.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "ypTreeBamboo", rmRandInt(6,9), 10.0);
        rmSetObjectDefMinDistance(treeID, 12.0);
        rmSetObjectDefMaxDistance(treeID, 18.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "ypMarcoPoloSheep", 8, 8.0);
        rmSetObjectDefMinDistance(foodID, 10.0);
        rmSetObjectDefMaxDistance(foodID, 10.0);
	rmAddObjectDefConstraint(foodID, avoidWaterShort);	
        rmSetObjectDefCreateHerd(foodID, true);
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "ypMarcoPoloSheep", 7, 8.0);
        rmSetObjectDefMinDistance(foodID2, 26.0);
	rmAddObjectDefConstraint(foodID2, avoidWaterShort);	
        rmSetObjectDefMaxDistance(foodID2, 26.0);
        rmSetObjectDefCreateHerd(foodID2, true);
                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "ypMarcoPoloSheep", 8, 8.0);
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
        rmSetObjectDefMaxDistance(startID, 10.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
//        rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        //rmPlaceObjectDefAtLoc(goldID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   //     rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
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

int avoidRamps1 = rmCreateCliffRampDistanceConstraint("avoidin cliffies", cliffNE, 17);
int avoidRamps2 = rmCreateCliffRampDistanceConstraint("avoidin cliffies again", cliffSW, 17);


  	int eastmine = rmCreateObjectDef("east mines");
	rmAddObjectDefItem(eastmine, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(eastmine, 0.0);
	rmSetObjectDefMaxDistance(eastmine, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(eastmine, avoidCoinMed);
	rmAddObjectDefConstraint(eastmine, avoidTownCenterMore);
	rmAddObjectDefConstraint(eastmine, avoidPlateau);	
	rmAddObjectDefConstraint(eastmine, avoidWaterShort);	rmAddObjectDefConstraint(eastmine, avoidRamps1);
	rmAddObjectDefConstraint(eastmine, avoidRamps2);
	rmAddObjectDefConstraint(eastmine, forestConstraintShort);
	rmAddObjectDefConstraint(eastmine, circleConstraint);
	rmPlaceObjectDefInArea(eastmine, 0, cliffNE, 1.5*cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(eastmine, 0, cliffSW, 1.5*cNumberNonGaiaPlayers);


	
    int pronghornHunts = rmCreateObjectDef("pronghornHunts");
	rmAddObjectDefItem(pronghornHunts, "ypWildElephant", rmRandInt(7,7), 14.0);
	rmSetObjectDefCreateHerd(pronghornHunts, true);
	rmSetObjectDefMinDistance(pronghornHunts, 0);
	rmSetObjectDefMaxDistance(pronghornHunts, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(pronghornHunts, circleConstraint);
//	rmAddObjectDefConstraint(pronghornHunts, avoidTownCenterMore);
	rmAddObjectDefConstraint(pronghornHunts, avoidHunt);		rmAddObjectDefConstraint(pronghornHunts, avoidWaterShort);
	rmAddObjectDefConstraint(pronghornHunts, avoidRamps1);
	rmAddObjectDefConstraint(pronghornHunts, avoidRamps2);	
	rmAddObjectDefConstraint(pronghornHunts, avoidPlateau);
	rmAddObjectDefConstraint(pronghornHunts, avoidSocket);	
	rmAddObjectDefConstraint(pronghornHunts, avoidCoin);	
	rmPlaceObjectDefInArea(pronghornHunts, 0, cliffNE, 1.5*cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(pronghornHunts, 0, cliffSW, 1.5*cNumberNonGaiaPlayers);


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
	rmAddObjectDefConstraint(nuggetID, avoidRamps1);
	rmAddObjectDefConstraint(nuggetID, avoidRamps2);	
	rmAddObjectDefConstraint(nuggetID, avoidCoin);	
	rmSetNuggetDifficulty(1, 3); 
	rmPlaceObjectDefInArea(nuggetID, 0, cliffNE, 2*cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(nuggetID, 0, cliffSW, 2*cNumberNonGaiaPlayers);
	rmSetStatusText("",0.7);

	//removes loop for faster loading times
	//for (j=0; < (6*cNumberNonGaiaPlayers)) {   
		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "ypTreeSaxaul", rmRandInt(12,15), rmRandFloat(18.0,20.0));
        rmAddObjectDefItem(mapTrees, "ypTreeBamboo", rmRandInt(11,12), 10.0);
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
	rmAddObjectDefConstraint(mapTrees, avoidRamps1);
	rmAddObjectDefConstraint(mapTrees, avoidRamps2);		
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 25*cNumberNonGaiaPlayers);
	//}
		rmSetStatusText("",0.8);

	rmSetStatusText("",0.9);

  // King of the Hill (added 2026-11 for WoL): centre, on the bank of the river crossing
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
 
