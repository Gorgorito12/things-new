include "triggers\triggerLoader.xs";

/*
==============================
	    Red River
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
		playerTiles = 9500;
	}
	
	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmSetMapSize(size, size);

	rmSetMapType("land");
        rmSetMapType("grass");
        rmSetMapType("yellowRiver");
       	rmTerrainInitialize("grass");

rmSetLightingSet("caribbean");
//rmSetLightingSet("patagonia");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
	rmSetSeaLevel(2.0);
		rmSetSeaType("yucatan Coast");


		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 6.0);

        int circleConstraint= rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 28.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 12.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 50.0);

		int avoidHunt2=rmCreateTypeDistanceConstraint("hunts avoid hunts2", "huntable", 20.0);

		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 3.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 87.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "CoffeePlant", 10.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "CoffeePlant", 50.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 6.0);
        int cliffWater = rmCreateTerrainDistanceConstraint("cliff avoids river", "Land", false, 0.01);
        int cliffWater2 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 1.5);
        int cliffWater3 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 2.5);


        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 6.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 26.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 10.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 35.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 60.0);

int stayWest = rmCreatePieConstraint("Stay West",0.47,0.53, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(225),rmDegreesToRadians(45));
int stayEast = rmCreatePieConstraint("Stay East",0.53,0.47, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(45),rmDegreesToRadians(225));

   

	int PlayerNum = cNumberNonGaiaPlayers;

    
 // =============Player placement ======================= 
    int spawnSwitch = rmRandInt(0,1);
	//spawnSwitch = 0;

	if (cNumberTeams == 2){

	if (PlayerNum == 2)
	{

//1v1 spawn switcher=============

	if (spawnSwitch == 1)
{
	rmPlacePlayer(1, 0.6, 0.8);
	rmPlacePlayer(2, 0.4, 0.2);
}else{
	rmPlacePlayer(2, 0.6, 0.8);
	rmPlacePlayer(1, 0.4, 0.2);

}
//===================================
	}
	if (PlayerNum == 4)
{
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.5, 0.8, 0.7, 0.8, 0, 0);
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.5, 0.2, 0.3, 0.2, 0, 0);
}else{
//easter egg 3v3 spawn
//==================================================
	if (PlayerNum == 6 && rmGetNumberPlayersOnTeam(0) == rmGetNumberPlayersOnTeam(1))
{
if(rmGetPlayerTeam(1)!=rmGetPlayerTeam(4))
{
	rmPlacePlayer(1, 0.16, 0.72);
	rmPlacePlayer(4, 0.84, 0.28);

}

}
//===================================================
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.45, 0.9, 0.7, 0.78, 0, 0);
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.55, 0.1, 0.3, 0.22, 0, 0);

}

	rmGetPlayerTeam(1);



	}else{
//ffa placement***********

			rmPlacePlayer(1, 0.55, 0.85);
			rmPlacePlayer(2, 0.45, 0.15);
			rmPlacePlayer(3, 0.16, 0.72);
			rmPlacePlayer(4, 0.84, 0.28);

	if (PlayerNum == 5){
			rmPlacePlayer(5, 0.5, 0.5);
}
	if (PlayerNum == 6){
			rmPlacePlayer(5, 0.58, 0.6);
			rmPlacePlayer(6, 0.42, 0.4);

}
	if (PlayerNum == 7){
			rmPlacePlayer(5, 0.5, 0.5);
			rmPlacePlayer(6, 0.11, 0.43);
			rmPlacePlayer(7, 0.89, 0.57);

}
	if (PlayerNum == 8){
			rmPlacePlayer(5, 0.58, 0.6);
			rmPlacePlayer(6, 0.42, 0.4);
			rmPlacePlayer(7, 0.11, 0.43);
			rmPlacePlayer(8, 0.89, 0.57);
}
	}

		
        chooseMercs();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	   rmSetAreaMix(continent2, "yellow_river_a");
        rmSetAreaBaseHeight(continent2, 4.0);
        rmSetAreaCoherence(continent2, 1.0);
        rmSetAreaSmoothDistance(continent2, 3);
		rmSetAreaEdgeFilling(continent2, 2.0);
        rmSetAreaHeightBlend(continent2, 1);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 10);
        rmSetAreaElevationVariation(continent2, 6);
        rmSetAreaElevationPersistence(continent2, .2);
        rmSetAreaElevationOctaves(continent2, 5);
        rmSetAreaElevationMinFrequency(continent2, 0.04);
        rmSetAreaElevationType(continent2, cElevTurbulence);  
        rmBuildArea(continent2);    

		int classPatch = rmDefineClass("patch");
		int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 22.0);
		int classCenter = rmDefineClass("center");
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 6.0);
		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
        

       		for (i=0; < cNumberNonGaiaPlayers*60){
			int patchID = rmCreateArea("first patch"+i);
			rmSetAreaWarnFailure(patchID, false);
			rmSetAreaSize(patchID, rmAreaTilesToFraction(45), rmAreaTilesToFraction(51));
        rmSetAreaTerrainType(patchID, "Mongolia\ground_grass4_mongol");
	//		rmAddAreaToClass(patchID, rmClassID("patch"));
	//		rmSetAreaSmoothDistance(patchID, 1.0);
			rmBuildArea(patchID); 
		}

	


		rmSetStatusText("",0.2);





 
		rmSetStatusText("",0.3);
				
//===================River=====================

	int TeamNum = cNumberTeams;
	int numPlayer = cNumberPlayers;
	string riverType = "Red River";


	int riverID = rmRiverCreate(-5, riverType, 8, 8, 4+numPlayer*0.8, 5+numPlayer*0.8); 

	rmRiverSetBankNoiseParams(riverID, 0.07, 1, 0.5, 6.0, 0.667, 1.0);


  rmRiverAddWaypoint(riverID, 0.75, 1.0);
  rmRiverAddWaypoint(riverID, 0.8, .9);
  rmRiverAddWaypoint(riverID, 0.85, .8);
  rmRiverAddWaypoint(riverID, 0.8, .7);
  rmRiverAddWaypoint(riverID, 0.75, .6);
  rmRiverAddWaypoint(riverID, 0.7, .5);
  rmRiverAddWaypoint(riverID, 0.65, .4);
  rmRiverAddWaypoint(riverID, 0.6, .3);
  rmRiverAddWaypoint(riverID, 0.65, .2);
  rmRiverAddWaypoint(riverID, 0.7, .1);
  rmRiverAddWaypoint(riverID, 0.75, .0);


	rmRiverSetShallowRadius(riverID, size);
		//rmRiverAddShallow(riverID, 0.2);

	rmRiverBuild(riverID);
	//rmRiverReveal(riverID, 2);

//second river

	int riverID2 = rmRiverCreate(-5, riverType, 8, 8, 5+numPlayer*0.8, 5+numPlayer*0.8); 

	rmRiverSetBankNoiseParams(riverID2, 0.07, 1, 0.5, 6.0, 0.667, 1.0);


  rmRiverAddWaypoint(riverID2, 0.25, 1.0);
  rmRiverAddWaypoint(riverID2, 0.3, .9);
  rmRiverAddWaypoint(riverID2, 0.35, .8);
  rmRiverAddWaypoint(riverID2, 0.4, .7);
  rmRiverAddWaypoint(riverID2, 0.35, .6);
  rmRiverAddWaypoint(riverID2, 0.3, .5);
  rmRiverAddWaypoint(riverID2, 0.25, .4);
  rmRiverAddWaypoint(riverID2, 0.2, .3);
  rmRiverAddWaypoint(riverID2, 0.15, .2);
  rmRiverAddWaypoint(riverID2, 0.2, .1);
  rmRiverAddWaypoint(riverID2, 0.25, .0);


	rmRiverSetShallowRadius(riverID2, size);
		//rmRiverAddShallow(riverID2, 0.2);

	rmRiverBuild(riverID2);


//====================================================


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
		rmAddTradeRouteWaypoint(tradeRouteID, .0, .85);	    	     
		rmAddTradeRouteWaypoint(tradeRouteID, .2, .8);
		rmAddTradeRouteWaypoint(tradeRouteID, .25, .7);
		rmAddTradeRouteWaypoint(tradeRouteID, .2, .6);
		rmAddTradeRouteWaypoint(tradeRouteID, .15, .55);
		rmAddTradeRouteWaypoint(tradeRouteID, .0, .5);

        rmBuildTradeRoute(tradeRouteID, "water");
 
        vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.4);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.8);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);



	if (PlayerNum >= 4)
	{
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.6);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

   }    

		//===========TR 2=================

		int socketID2=rmCreateObjectDef("sockets to dock Trade Posts2");
        rmAddObjectDefItem(socketID2, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID2, true);
        rmSetObjectDefMinDistance(socketID2, 0.0);
        rmSetObjectDefMaxDistance(socketID2, 6.0);      
       
        int tradeRouteID2 = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID2, tradeRouteID2);
		rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, .15);
		rmAddTradeRouteWaypoint(tradeRouteID2, .8, .2);
		rmAddTradeRouteWaypoint(tradeRouteID2, .75, .3);
		rmAddTradeRouteWaypoint(tradeRouteID2, .8, .4);
		rmAddTradeRouteWaypoint(tradeRouteID2, .85, .45);
		rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, .5);


        rmBuildTradeRoute(tradeRouteID2, "water");
 
		vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.4);
        rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.8);
        rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);

	if (PlayerNum >= 4)
	{
            socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.60);
        rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
   }    






//end routes
}


  

		int flagPond1=rmCreateArea("nw flag");
        rmSetAreaLocation(flagPond1, 0.35, 0.8);
        rmSetAreaSize(flagPond1, .002, .002);      
        rmSetAreaCoherence(flagPond1, .92);
        rmBuildArea(flagPond1);

		int flagPond2=rmCreateArea("se flag");
        rmSetAreaLocation(flagPond2, 0.65, 0.2);
        rmSetAreaSize(flagPond2, .002, .002);      
        rmSetAreaCoherence(flagPond2, .92);
        rmBuildArea(flagPond2);


			int patchID2 = rmCreateArea("the second patch");
			rmSetAreaWarnFailure(patchID2, false);
			rmSetAreaSize(patchID2, 0.99, 0.99);
			rmAddAreaTerrainReplacement(patchID2, "saguenay\shoreline3_sag", "patagonia\ground_shoreline2_pat");
			//rmPaintAreaTerrain(patchID2);
        rmSetAreaLocation(patchID2, 0.5, 0.6);	
		//	rmAddAreaToClass(patchID2, rmClassID("patch"));
	//		rmSetAreaSmoothDistance(patchID2, 1.0);
	//		rmAddAreaConstraint(patchID2, circleConstraint2);
		//	rmBuildArea(patchID2); 


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
      subCiv0=rmGetCivID("shaolin");
      rmEchoInfo("subCiv0 is shaolin"+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "shaolin");

		subCiv1=rmGetCivID("shaolin");
      rmEchoInfo("subCiv1 is shaolin"+subCiv1);
		if (subCiv1 >= 0)
			 rmSetSubCiv(1, "shaolin");
	 
		subCiv2=rmGetCivID("shaolin");
      rmEchoInfo("subCiv2 is shaolin"+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "shaolin");

		subCiv3=rmGetCivID("shaolin");
      rmEchoInfo("subCiv3 is shaolin"+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "shaolin");
	}
	
	// Set up Natives	
	int nativeID0 = -1;
    int nativeID1 = -1;
	int nativeID2 = -1;
    int nativeID3 = -1;
		
	nativeID0 = rmCreateGrouping("native site 1", "native shaolin temple yr 04");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 2.00);
	rmAddGroupingToClass(nativeID0, rmClassID("classPlateau"));

	nativeID1 = rmCreateGrouping("native site 2", "native shaolin temple yr 04");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 2.00);
	rmAddGroupingToClass(nativeID1, rmClassID("classPlateau"));


//========place=====

	if (cNumberTeams <= 6){
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.11, 0.4);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.89, 0.6);
}
	if (cNumberTeams == 4){
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.5, 0.5);
}
	if (cNumberTeams == 7){
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.16, 0.6);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.84, 0.4);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.58, 0.65);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.42, 0.35);
}
	if (cNumberTeams == 8){
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.16, 0.6);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.84, 0.4);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.73, 0.8);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.27, 0.2);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.5, 0.5);

}


		int westIsland=rmCreateArea("west Island");
        rmSetAreaLocation(westIsland, 0.1, 0.5);
        rmSetAreaSize(westIsland, .4, .4);      
        rmSetAreaCoherence(westIsland, .99);
	rmAddAreaConstraint(westIsland, avoidWaterShort);		rmAddAreaToClass(westIsland, rmClassID("center"));
        rmBuildArea(westIsland);

		int eastIsland=rmCreateArea("east Island");
        rmSetAreaLocation(eastIsland, 0.9, 0.5);
        rmSetAreaSize(eastIsland, .4, .4);      
        rmSetAreaCoherence(eastIsland, .99);
	rmAddAreaConstraint(eastIsland, avoidWaterShort);
	rmAddAreaToClass(eastIsland, rmClassID("center"));
        rmBuildArea(eastIsland);



	if (PlayerNum == 2)
{
  	int smollMines = rmCreateObjectDef("competitive gold");
	rmAddObjectDefItem(smollMines, "CoffeePlant", 3, 2.0);
	rmSetObjectDefMinDistance(smollMines, 0.0);
	rmSetObjectDefMaxDistance(smollMines, 3.0);
//back mines
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.55, 0.1, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.45, 0.9, 1);
//centre bushes
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.5, 0.5, 1);

	rmAddObjectDefConstraint(smollMines, avoidCoinMed);
	rmAddObjectDefConstraint(smollMines, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(smollMines, circleConstraint);	
	rmAddObjectDefConstraint(smollMines, avoidWaterShort);


rmPlaceObjectDefInArea(smollMines, 0, westIsland, 3);
rmPlaceObjectDefInArea(smollMines, 0, eastIsland, 3);


//	rmPlaceObjectDefAtLoc(smollMines, 0, 0.08, 0.76, 1);
//	rmPlaceObjectDefAtLoc(smollMines, 0, 0.92, 0.24, 1);
//starting coin
//	rmPlaceObjectDefAtLoc(smollMines, 0, 0.42, 0.79, 1);
//	rmPlaceObjectDefAtLoc(smollMines, 0, 0.79, 0.42, 1);
//south mine
//	rmPlaceObjectDefAtLoc(smollMines, 0, 0.3, 0.65, 1);
//	rmPlaceObjectDefAtLoc(smollMines, 0, 0.65, 0.3, 1);


}



		rmSetStatusText("",0.4);
		//starting objects

	int flagLand = rmCreateTerrainDistanceConstraint("flags dont like land", "land", true, 3.0);


		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
	rmAddObjectDefConstraint(playerStart, avoidWaterShort);

       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "CoffeePlant", 3, 2.0);
        rmSetObjectDefMinDistance(goldID, 14.0);
        rmSetObjectDefMaxDistance(goldID, 14.0);
       
        int goldID2 = rmCreateObjectDef("starting gold 2");
        rmAddObjectDefItem(goldID2, "CoffeePlant", 3, 2.0);
        rmSetObjectDefMinDistance(goldID2, 0.0);
        rmSetObjectDefMaxDistance(goldID2, 2.0);


        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "OrangeTree", 3, 4.0);
        rmSetObjectDefMinDistance(berryID, 18.0);
        rmSetObjectDefMaxDistance(berryID, 18.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "ypTreeBamboo", rmRandInt(14,15), 6.0);
        rmSetObjectDefMinDistance(treeID, 16.0);
        rmSetObjectDefMaxDistance(treeID, 16.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
		rmAddObjectDefToClass(treeID, rmClassID("classForest")); 
        rmAddObjectDefConstraint(treeID, avoidCoin);

 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "ypIbex", 8, 5.0);
        rmSetObjectDefMinDistance(foodID, 0.0);
        rmSetObjectDefMaxDistance(foodID, 3.0);
	rmAddObjectDefConstraint(foodID, avoidWaterShort);	
        rmSetObjectDefCreateHerd(foodID, true);
        //rmAddObjectDefConstraint(foodID, avoidCoin);

 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "ypGoat", 4, 3.0);
        rmSetObjectDefMinDistance(foodID2, 0.0);
	rmAddObjectDefConstraint(foodID2, avoidWaterShort);	
        rmSetObjectDefMaxDistance(foodID2, 3.0);
        rmSetObjectDefCreateHerd(foodID2, true);
                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "ypMarcoPoloSheep", 8, 8.0);
        rmSetObjectDefMinDistance(foodID3, 26.0);
        rmSetObjectDefMaxDistance(foodID3, 27.0);
	rmAddObjectDefConstraint(foodID3, avoidWaterShort);
	rmAddObjectDefConstraint(foodID3, avoidHunt2);		
        rmSetObjectDefCreateHerd(foodID3, true);

	int extraberrywagon=rmCreateObjectDef("JapAn cAnT hUnT");
  rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
  rmSetObjectDefMinDistance(extraberrywagon, 6.0);
  rmSetObjectDefMaxDistance(extraberrywagon, 7.0);

	//Dock Wagon
	int playerCrateID=rmCreateObjectDef("starting wagon");
	rmAddObjectDefItem(playerCrateID, "ypDockWagon", 1, 0.0);
	rmSetObjectDefMinDistance(playerCrateID, 12.0);
	rmSetObjectDefMaxDistance(playerCrateID, 12.0);
	rmAddObjectDefConstraint(playerCrateID, avoidWaterShort);
	rmAddObjectDefConstraint(playerCrateID, avoidHunt2);




		rmSetStatusText("",0.5);      
    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 1.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 1.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i)-rmXTilesToFraction(6), rmPlayerLocZFraction(i));

//	if (PlayerNum >= 3)
//{
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
//}

        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i)+rmXTilesToFraction(12), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerCrateID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));



    int flag1 = rmFindCloserArea(rmPlayerLocXFraction(i), rmPlayerLocZFraction(i), flagPond2, flagPond1);

		int waterFlag = rmCreateObjectDef("HC water flag "+i);
         rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 5.0);
         rmSetObjectDefMinDistance(waterFlag, 0);
         rmSetObjectDefMaxDistance(waterFlag, 10);
	rmAddObjectDefConstraint(waterFlag, flagLand);
       rmPlaceObjectDefAtAreaLoc(waterFlag, i, flag1, 1);


	}
	rmSetStatusText("",0.6);
	/*
	==================
	resource placement
	==================
	*/




  	int eastmine = rmCreateObjectDef("east mines");
	rmAddObjectDefItem(eastmine, "CoffeePlant", 4, 2.0);
	rmSetObjectDefMinDistance(eastmine, 0.0);
	rmSetObjectDefMaxDistance(eastmine, rmXFractionToMeters(0.7));

	if (PlayerNum == 2)
{
	rmSetObjectDefMaxDistance(eastmine, rmXFractionToMeters(0.25));
	rmAddObjectDefConstraint(eastmine, avoidCenter);

}
	rmAddObjectDefConstraint(eastmine, avoidCoinMed);
	rmAddObjectDefConstraint(eastmine, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(eastmine, avoidPlateau);	
	rmAddObjectDefConstraint(eastmine, avoidWaterShort);
	rmAddObjectDefConstraint(eastmine, avoidTownCenterMore);
//rmAddObjectDefConstraint(eastmine, stayEast);
	rmAddObjectDefConstraint(eastmine, circleConstraint);
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);
 


	
    int birdHunts = rmCreateObjectDef("birdHunts");
	rmAddObjectDefItem(birdHunts, "ypIbex", rmRandInt(5,6), 5.0);
	rmSetObjectDefCreateHerd(birdHunts, true);
	rmSetObjectDefMinDistance(birdHunts, 0);
	rmSetObjectDefMaxDistance(birdHunts, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(birdHunts, circleConstraint);
	//rmAddObjectDefConstraint(birdHunts, avoidTownCenterMore);
	rmAddObjectDefConstraint(birdHunts, avoidHunt);		rmAddObjectDefConstraint(birdHunts, avoidWaterShort);
	rmAddObjectDefConstraint(birdHunts, avoidPlateau);
//	rmAddObjectDefConstraint(birdHunts, avoidSocket);	
	rmAddObjectDefConstraint(birdHunts, avoidCoin);	
	rmPlaceObjectDefAtLoc(birdHunts, 0, 0.5, 0.5, 7*cNumberNonGaiaPlayers);


  	int waterBuffaloSpam = rmCreateObjectDef("buffalo bois");
	rmAddObjectDefItem(waterBuffaloSpam, "ypWaterBuffalo", rmRandInt(2,2), 4.0);
	rmSetObjectDefMinDistance(waterBuffaloSpam, 0.0);
	rmSetObjectDefMaxDistance(waterBuffaloSpam, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(waterBuffaloSpam, avoidHerd);
	rmAddObjectDefConstraint(waterBuffaloSpam, avoidCoin);	
	rmAddObjectDefConstraint(waterBuffaloSpam, circleConstraint);
	rmAddObjectDefConstraint(waterBuffaloSpam, avoidTownCenterMore);
	rmAddObjectDefConstraint(waterBuffaloSpam, avoidWaterShort);	
	rmPlaceObjectDefAtLoc(waterBuffaloSpam, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);

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
	rmSetNuggetDifficulty(3, 3); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 1.5*cNumberNonGaiaPlayers);   
	rmSetNuggetDifficulty(1, 2); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 7*cNumberNonGaiaPlayers);   

	rmSetStatusText("",0.7);

	//removes loop for faster loading times
	//for (j=0; < (6*cNumberNonGaiaPlayers)) {   
		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "ypTreeAshoka", rmRandInt(5,6), rmRandFloat(9.0,9.0));
        rmAddObjectDefItem(mapTrees, "ypTreeSaxaul", rmRandInt(7,7), 10.0);
        rmAddObjectDefItem(mapTrees, "OrangeTree", rmRandInt(1,1), 4.0);
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.7));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		//rmAddObjectDefConstraint(mapTrees, avoidCenter);
	  	rmAddObjectDefConstraint(mapTrees, avoidCoin);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees, avoidPlateau);	
		rmAddObjectDefConstraint(mapTrees, avoidWaterShort);
	rmAddObjectDefConstraint(mapTrees, circleConstraint);
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 120*cNumberNonGaiaPlayers);
	//}
		rmSetStatusText("",0.8);
		int bonusTrees=rmCreateObjectDef("bonusTrees");
		rmAddObjectDefItem(bonusTrees, "ypTreeBamboo", rmRandInt(8,8), rmRandFloat(4.0,5.0));
	rmAddObjectDefItem(bonusTrees, "UnderbrushCoastalJapan", rmRandInt(2,3), 7.0);
	  	rmAddObjectDefConstraint(bonusTrees, avoidTownCenter);
		rmAddObjectDefConstraint(bonusTrees, forestConstraintShort);
		rmAddObjectDefToClass(bonusTrees, rmClassID("classForest")); 
	  rmAddObjectDefConstraint(bonusTrees, avoidCoin);
	rmAddObjectDefConstraint(bonusTrees, avoidWaterShort);	
	rmPlaceObjectDefInArea(bonusTrees, 0, continent2  , 15*cNumberNonGaiaPlayers);


	rmSetStatusText("",0.9);


	//fish and their constraints placed together at the end for ease of removal
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "ypFishCatfish", 8.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 5.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 65.0);
	int rocksHateRocksID=rmCreateTypeDistanceConstraint("rocks and rocks", "ShorelineRockBigNE", 34.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 30.0);


	int fishID=rmCreateObjectDef("fish Mahi");
	rmAddObjectDefItem(fishID, "ypFishCatfish", 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 28*cNumberNonGaiaPlayers);


	int rocksWater=rmCreateObjectDef("water rocks");
	rmAddObjectDefItem(rocksWater, "RiverShallowsOri", 3, 5.0);
	rmAddObjectDefItem(rocksWater, "ShorelineRockSmallNE", 1, 8.0);
	rmSetObjectDefMinDistance(rocksWater, 0.0);
	rmSetObjectDefMaxDistance(rocksWater, rmXFractionToMeters(0.4));
	rmAddObjectDefConstraint(rocksWater, rocksHateRocksID);
	rmAddObjectDefConstraint(rocksWater, fishLand);
//	rmAddObjectDefConstraint(rocksWater, fishLand2);
  	rmAddObjectDefConstraint(rocksWater, circleConstraint);
	//rmPlaceObjectDefAtLoc(rocksWater, 0, 0.5, 0.7, 11*cNumberNonGaiaPlayers);

//UnderbrushLake
	int shorelinePretty=rmCreateObjectDef("coastline decor");
	rmAddObjectDefItem(shorelinePretty, "UnderbrushLake", 3, 4.0);
	rmSetObjectDefMinDistance(shorelinePretty, 0.0);
	rmSetObjectDefMaxDistance(shorelinePretty, rmXFractionToMeters(0.4));
	rmAddObjectDefConstraint(shorelinePretty, rocksHateRocksID);
	rmAddObjectDefConstraint(shorelinePretty, waterHunt);
//	rmAddObjectDefConstraint(shorelinePretty, fishLand2);
  	rmAddObjectDefConstraint(shorelinePretty, circleConstraint);
	//rmPlaceObjectDefAtLoc(shorelinePretty, 0, 0.5, 0.7, 11*cNumberNonGaiaPlayers);



  // King of the Hill (added 2026-11 for WoL): centre, on land between the rivers
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
 
