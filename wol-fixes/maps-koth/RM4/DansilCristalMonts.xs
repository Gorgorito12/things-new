/* ============================
	Monts de Cristal
	Original Upper Andes
	by dansil92
=============================== */
include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
include "triggers\triggerLoader.xs";
 
void main(void) {
	rmSetStatusText("",0.01);
   // Picks the map size
	int playerTiles=14000;
	if (cNumberNonGaiaPlayers > 4){
		playerTiles = 12000;
	}else if (cNumberNonGaiaPlayers > 6){
		playerTiles = 10000;
	}
	
	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmSetMapSize(size, size);

	rmSetMapType("land");
        rmSetMapType("grass");
        rmSetMapType("AFRICANjungle");
       	rmTerrainInitialize("grass");
		rmSetLightingSet("saguenay");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
		
		//=========Constraints=====
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 12.0);

        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.49), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 10.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 3.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 50.0);
		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 50.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 10.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "Mine", 60.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 5.0);

        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 8.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 35.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 40.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 60.0);

       
 	// Player placing  
    float spawnSwitch = rmRandFloat(0,1.2);


int PlayerNum = cNumberNonGaiaPlayers;
	

	

	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){

	if (PlayerNum == 2)
	{
	rmPlacePlayer(1, 0.4, 0.75);
	rmPlacePlayer(2, 0.75, 0.4);	}

			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.76, 0.00);
			rmPlacePlayersCircular(0.32, 0.32, 0.02);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.25, 0.49);
			rmPlacePlayersCircular(0.32, 0.32, 0.02);
		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
		rmPlacePlayer(2, 0.4, 0.75);
		rmPlacePlayer(1, 0.75, 0.4);
	}

			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.76, 0.00);
			rmPlacePlayersCircular(0.32, 0.32, 0.02);
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.25, 0.49);
			rmPlacePlayersCircular(0.32, 0.32, 0.02);

		}
	}else{
	//*************ffa placement********
	if (cNumberTeams >= 3){	
	if (PlayerNum == 3)
{
		rmPlacePlayer(1, 0.32, 0.32);
		rmPlacePlayer(2, 0.43, 0.77);
		rmPlacePlayer(3, 0.77, 0.43);
}


		rmPlacePlayersCircular(0.28, 0.28, 0.02);
	}
}
//=========start map=========

	chooseMercs();
wotta_triggers();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	rmSetAreaMix(continent2, "rainforest");
        rmSetAreaBaseHeight(continent2, -2.0);
        rmSetAreaCoherence(continent2, 1.0);
        rmSetAreaSmoothDistance(continent2, 10);
        rmSetAreaHeightBlend(continent2, 1);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 10);
        rmSetAreaElevationVariation(continent2, 1);
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
        
		int center = rmCreateArea("center");
		rmAddAreaToClass(center, rmClassID("center"));
        rmSetAreaSize(center, .1, .1);
        rmSetAreaLocation(center, 0.5, 0.5);
        rmSetAreaCoherence(center, 1.0);
        rmBuildArea(center);   


		rmSetStatusText("",0.2);

//======place trees first, remove from areas later=======


		int lowlandTrees=rmCreateObjectDef("Lowland Trees");
	rmAddObjectDefItem(lowlandTrees, "TreeAmazon", rmRandInt(12,14), rmRandFloat(13.0,16.0));
		rmAddObjectDefToClass(lowlandTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(lowlandTrees, 0);
		rmSetObjectDefMaxDistance(lowlandTrees, rmXFractionToMeters(0.48));
	rmAddObjectDefConstraint(lowlandTrees, avoidPlateau);
		rmAddObjectDefConstraint(lowlandTrees, forestConstraintShort);
		rmAddObjectDefConstraint(lowlandTrees, avoidSocket);
		rmPlaceObjectDefAtLoc(lowlandTrees, 0, 0.5, 0.5, 100*cNumberNonGaiaPlayers);



//=====build centre plateau, from centre toward each player=====


		int cliffs = rmCreateArea("cliffs");
		rmSetAreaSize(cliffs, 0.15, 0.15); 
		rmAddAreaToClass(cliffs, rmClassID("classPlateau"));
//		rmAddAreaTerrainReplacement(cliffs, "texas\ground4_tex", "california\ground6_cal"); //idk why cali works, dont touch it
		rmSetAreaCliffType(cliffs, "Bioko");
//        rmSetAreaHeightBlend(cliffs, 1);
		rmSetAreaCliffEdge(cliffs, 1, 1.0, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(cliffs, true, true, true, 0.4, true);
		rmSetAreaCliffHeight(cliffs, 3, 0.1, 0.5);

for(i=1; < cNumberNonGaiaPlayers + 1) {

	rmAddAreaInfluenceSegment(cliffs, 0.5,0.5, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
}

//===expand south for 2 player mode===
	if (PlayerNum == 2)
	{
	rmAddAreaInfluenceSegment(cliffs, 0.4,0.5, 0.5,0.4);	
}

		rmSetAreaCoherence(cliffs, .89);
	rmAddAreaRemoveType(cliffs, "TreeAmazon");
		rmSetAreaLocation(cliffs, .5, .5);		
		rmBuildArea(cliffs);


//=====decorative centre section==========


		int centerCliffs = rmCreateArea("centerCliffs");
		rmSetAreaSize(centerCliffs, 0.007, 0.008); 
		rmAddAreaToClass(centerCliffs, rmClassID("classPlateau"));
		rmSetAreaCliffType(centerCliffs, "Bioko");
		rmSetAreaCliffEdge(centerCliffs, 4, 0.2, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(centerCliffs, true, true, true, 0.4, true);
		rmSetAreaCliffHeight(centerCliffs, -4, 0.1, 0.5);
        rmSetAreaHeightBlend(centerCliffs, 1);
		//rmAddAreaConstraint(centerCliffs, avoidCenter);
		rmSetAreaCoherence(centerCliffs, .87);
		rmSetAreaLocation(centerCliffs, .5, .5);		
		rmBuildArea(centerCliffs);

  // check for KOTH game mode. Fixed 2026-11: this block was not closed, so it also held the
  // decorative centre cliffs above, which were then only built in King of the Hill games.
  // The hill now goes in after the cliffs.
  if(rmGetIsKOTH()) {
    float xLoc = 0.5;
    float yLoc = 0.5;
    float walk = 0.03;
    ypKingsHillPlacer(xLoc, yLoc, walk, 0);
  }


// ******KEEP BUILDABLE LAND UNDER TCS ******

for(i=1; < cNumberNonGaiaPlayers + 1) {

    int PlayerArea1 = rmCreateArea("NeedLand1"+i);
        rmSetAreaSize(PlayerArea1, rmAreaTilesToFraction(2100), rmAreaTilesToFraction(2100));
        rmSetAreaBaseHeight(PlayerArea1, 0.3);
	rmAddAreaRemoveType(PlayerArea1, "TreeAmazon");
 //       rmSetAreaHeightBlend(PlayerArea1, 1);
		rmAddAreaToClass(PlayerArea1, rmClassID("classPlateau"));
		rmSetAreaCliffType(PlayerArea1, "Bioko");
  rmSetAreaSmoothDistance(PlayerArea1, 10);
		rmSetAreaCliffEdge(PlayerArea1, 4, 0.125, 0.0, 1.0, 1); //4,.225 looks cool too
		rmSetAreaCliffPainting(PlayerArea1, false, false, true, 0.2, true);
		rmSetAreaCliffHeight(PlayerArea1, 0, 0.1, 0.5);
        rmSetAreaLocation(PlayerArea1, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmSetAreaCoherence(PlayerArea1, 0.84);
        rmBuildArea(PlayerArea1);

} //dont touch, it works

		rmSetStatusText("",0.3);
/*
===================
ADD IN NATIVE AREAS
===================
*/
//========first area for all spawns======

//clear trees
		int nativeArea1 = rmCreateArea("villages1");
        rmSetAreaSize(nativeArea1, .044, .045);
        rmSetAreaLocation(nativeArea1, 0.2, 0.2);
        rmSetAreaCoherence(nativeArea1, 0.84);
	rmSetAreaReveal(nativeArea1, 2);
		rmAddAreaToClass(nativeArea1, rmClassID("classPlateau"));
	rmAddAreaInfluenceSegment(nativeArea1, 0.1,0.3, 0.3,0.1);	
	rmSetAreaMix(nativeArea1, "lualaba_grass2");
	rmAddAreaRemoveType(nativeArea1, "TreeAmazon");
        rmBuildArea(nativeArea1);   


   //Chooses which natives appear on the map
   int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;
	int subCiv3=-1;


	// All Inca all the time
   if (rmAllocateSubCivs(4) == true)
   {
		subCiv0=rmGetCivID("Incas");
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Incas");

		subCiv1=rmGetCivID("Incas");
      if (subCiv1 >= 0)
         rmSetSubCiv(1, "Incas");

		subCiv2=rmGetCivID("Incas");
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Incas");

		subCiv3=rmGetCivID("Incas");
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Incas");
	}


//===========place first two settlements===========

	if (subCiv0 == rmGetCivID("Incas"))
	{  
		int incaVillageAID = -1;
		incaVillageAID = rmCreateGrouping("back inca village", "native inca village "+1);
		rmSetGroupingMinDistance(incaVillageAID, 0.0);
		rmSetGroupingMaxDistance(incaVillageAID, 5.0);
		rmPlaceGroupingAtLoc(incaVillageAID, 0, 0.27, 0.13);
	}

	if (subCiv1 == rmGetCivID("Incas"))
	{  
		int incavillageBID = -1;
		incavillageBID = rmCreateGrouping("left city", "native inca village "+2);
		rmSetGroupingMinDistance(incavillageBID, 0.0);
		rmSetGroupingMaxDistance(incavillageBID, 5.0);
		rmPlaceGroupingAtLoc(incavillageBID, 0, 0.13, 0.27);
	}


//======team games & large ffa add top native settlement======

	if (PlayerNum >= 4)
{
//====clear area of trees=====
		int nativeArea2 = rmCreateArea("villages2");
        rmSetAreaSize(nativeArea2, .044, .045);
        rmSetAreaLocation(nativeArea2, 0.8, 0.8);
        rmSetAreaCoherence(nativeArea2, 0.84);
		rmAddAreaToClass(nativeArea2, rmClassID("classPlateau"));
	rmAddAreaInfluenceSegment(nativeArea2, 0.9,0.7, 0.7,0.9);	
	rmSetAreaMix(nativeArea2, "lualaba_grass2");
	rmAddAreaRemoveType(nativeArea2, "TreeAmazon");
        rmBuildArea(nativeArea2);   



	if (subCiv2 == rmGetCivID("Incas"))
	{  
		int incavillageCID = -1;
		incavillageCID = rmCreateGrouping("right city", "native inca village "+3);
		rmSetGroupingMinDistance(incavillageCID, 0.0);
		rmSetGroupingMaxDistance(incavillageCID, 5.0);
		rmPlaceGroupingAtLoc(incavillageCID, 0, 0.87, 0.73);
	}

	if (subCiv3 == rmGetCivID("Incas"))
	{  
		int incavillageDID = -1;
		incavillageDID = rmCreateGrouping("front city", "native inca village "+4);
		rmSetGroupingMinDistance(incavillageDID, 0.0);
		rmSetGroupingMaxDistance(incavillageDID, 5.0);
		rmPlaceGroupingAtLoc(incavillageDID, 0, 0.73, 0.87);
	}
}

	if (cNumberTeams >= 3){
//=====for ffa games add in east & west natives====

		int nativeArea3 = rmCreateArea("villages3");
        rmSetAreaSize(nativeArea3, .044, .045);
        rmSetAreaLocation(nativeArea3, 0.2, 0.8);
        rmSetAreaCoherence(nativeArea3, 0.84);
	rmAddAreaInfluenceSegment(nativeArea3, 0.3,0.9, 0.1,0.7);	
		rmAddAreaToClass(nativeArea3, rmClassID("classPlateau"));
	rmSetAreaMix(nativeArea3, "lualaba_grass2");
	rmAddAreaRemoveType(nativeArea3, "TreeAmazon");
        rmBuildArea(nativeArea3);   

		int nativeArea4 = rmCreateArea("villages4");
        rmSetAreaSize(nativeArea4, .044, .045);
        rmSetAreaLocation(nativeArea4, 0.8, 0.2);
        rmSetAreaCoherence(nativeArea4, 0.84);
		rmAddAreaToClass(nativeArea4, rmClassID("classPlateau"));
	rmAddAreaInfluenceSegment(nativeArea4, 0.9,0.3, 0.7,0.1);	
	rmSetAreaMix(nativeArea4, "lualaba_grass2");
	rmAddAreaRemoveType(nativeArea4, "TreeAmazon");
        rmBuildArea(nativeArea4);   

//=======place villages in clearings=====

		rmPlaceGroupingAtLoc(incaVillageAID, 0, 0.27, 0.87);
		rmPlaceGroupingAtLoc(incaVillageAID, 0, 0.13, 0.73);
		rmPlaceGroupingAtLoc(incavillageBID, 0, 0.87, 0.27);
		rmPlaceGroupingAtLoc(incavillageBID, 0, 0.73, 0.13);

}

//=======add mines to the inca areas as per spawn type======


 	int smollMines = rmCreateObjectDef("Inca Gold");
	rmAddObjectDefItem(smollMines, "minegold", 1, 1.0);
	rmSetObjectDefMinDistance(smollMines, 0.0);
	rmSetObjectDefMaxDistance(smollMines, 14);
	rmAddObjectDefConstraint(smollMines, avoidSocket);
        rmAddObjectDefConstraint(smollMines, avoidCoin);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.2 , 0.2, 2);
	if (PlayerNum >= 4)
{
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.8 , 0.8, 2);
}

	if (cNumberTeams >= 3){
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.8 , 0.2, 2);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.2 , 0.8, 2);

}


/*
====================
  END NATIVE AREAS
====================
*/



		
		rmSetStatusText("",0.4);


		//starting objects

		int avoidCoinSmoll=rmCreateTypeDistanceConstraint("avoid coin", "minegold", 6.0);

		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "minegold", 1, 8.0);
        rmSetObjectDefMinDistance(goldID, 12.0);
        rmSetObjectDefMaxDistance(goldID, 12.0);
       
        int goldID2 = rmCreateObjectDef("starting gold 2");
        rmAddObjectDefItem(goldID2, "mine", 1, 16.0);
        rmSetObjectDefMinDistance(goldID2, 12.0);
        rmSetObjectDefMaxDistance(goldID2, 12.0);
        rmAddObjectDefConstraint(goldID2, avoidCoin);
 
        int llamaID = rmCreateObjectDef("Dem start llamas");
        rmAddObjectDefItem(llamaID, "ypGoat", 6, 4.0);
        rmSetObjectDefMinDistance(llamaID, 8.0);
        rmSetObjectDefMaxDistance(llamaID, 12.0);
        rmAddObjectDefConstraint(llamaID, avoidCoinSmoll);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "ypTreeBorneoCanopy", rmRandInt(11,12), 12.0);
        rmSetObjectDefMinDistance(treeID, 12.0);
        rmSetObjectDefMaxDistance(treeID, 18.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoinSmoll);
 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "Antelope", 8, 8.0);
        rmSetObjectDefMinDistance(foodID, 10.0);
        rmSetObjectDefMaxDistance(foodID, 10.0);
        rmSetObjectDefCreateHerd(foodID, true);
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "Antelope", 7, 8.0);
        rmSetObjectDefMinDistance(foodID2, 20.0);
        rmSetObjectDefMaxDistance(foodID2, 21.0);
        rmSetObjectDefCreateHerd(foodID2, true);
                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "ypWildElephant", 3, 6.0);
        rmSetObjectDefMinDistance(foodID3, 30.0);
        rmSetObjectDefMaxDistance(foodID3, 32.0);
        rmSetObjectDefCreateHerd(foodID3, true);

	int extraberrywagon=rmCreateObjectDef("JapAn cAnT hUnT");
  rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
  rmSetObjectDefMinDistance(extraberrywagon, 6.0);
  rmSetObjectDefMaxDistance(extraberrywagon, 7.0);


        int WarriorID = rmCreateObjectDef("Bolas Buddy");
        rmAddObjectDefItem(WarriorID, "NatBolasWarrior", 1, 8.0);
        rmSetObjectDefMinDistance(WarriorID, 10.0);
        rmSetObjectDefMaxDistance(WarriorID, 12.0);
        rmAddObjectDefConstraint(WarriorID, avoidCoinSmoll);


	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
    rmSetObjectDefMinDistance(playerNuggetID, 25.0);
    rmSetObjectDefMaxDistance(playerNuggetID, 27.0);
	rmSetNuggetDifficulty(1, 1); 
	rmAddObjectDefConstraint(playerNuggetID, avoidNugget);
	rmAddObjectDefConstraint(playerNuggetID, circleConstraint);
        rmAddObjectDefConstraint(playerNuggetID, avoidCoin);





		rmSetStatusText("",0.5);      
    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 5.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 10.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(llamaID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(WarriorID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
//===oh japan why you so annoying===
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
	
    int pronghornHunts = rmCreateObjectDef("pronghornHunts");
	rmAddObjectDefItem(pronghornHunts, "Antelope", rmRandInt(7,8), 14.0);
	rmSetObjectDefCreateHerd(pronghornHunts, true);
	rmSetObjectDefMinDistance(pronghornHunts, 0);
	rmSetObjectDefMaxDistance(pronghornHunts, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(pronghornHunts, circleConstraint);
	rmAddObjectDefConstraint(pronghornHunts, avoidTownCenterMore);
	rmAddObjectDefConstraint(pronghornHunts, avoidHunt);
	rmAddObjectDefConstraint(pronghornHunts, avoidPlateau);	
	rmPlaceObjectDefAtLoc(pronghornHunts, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);


		rmSetStatusText("",0.8);


  	int islandminesID = rmCreateObjectDef("island silver");
	rmAddObjectDefItem(islandminesID, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(islandminesID, 0.0);
	rmSetObjectDefMaxDistance(islandminesID, rmXFractionToMeters(0.49));
	rmAddObjectDefConstraint(islandminesID, avoidCoinMed);
	rmAddObjectDefConstraint(islandminesID, avoidTownCenterMore);
	rmAddObjectDefConstraint(islandminesID, avoidSocket);
	rmAddObjectDefConstraint(islandminesID, avoidPlateau);	
	rmAddObjectDefConstraint(islandminesID, avoidWaterShort);
//	rmAddObjectDefConstraint(islandminesID, forestConstraintShort);
	rmAddObjectDefConstraint(islandminesID, circleConstraint);
	rmPlaceObjectDefAtLoc(islandminesID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);
 

int avoidStronghold=rmCreateTypeDistanceConstraint("avoid Huari", "HuariStrongholdAndes", 35.0);



	int NorthNuggs= rmCreateObjectDef("nuggetStronk"); 
	rmAddObjectDefItem(NorthNuggs, "AURbuildings", 1, 7.0); 
	rmSetObjectDefMinDistance(NorthNuggs, 0.0); 
	rmSetObjectDefMaxDistance(NorthNuggs, rmXFractionToMeters(0.49)); 
	rmAddObjectDefConstraint(NorthNuggs, avoidStronghold); 
	rmAddObjectDefConstraint(NorthNuggs, circleConstraint);
	rmAddObjectDefConstraint(NorthNuggs, forestConstraintShort);
	rmAddObjectDefConstraint(NorthNuggs, avoidPlateau);	
	rmPlaceObjectDefAtLoc(NorthNuggs, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);   




	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
	rmSetObjectDefMinDistance(nuggetID, 0.0); 
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.5)); 
	rmAddObjectDefConstraint(nuggetID, avoidNugget); 
	rmAddObjectDefConstraint(nuggetID, circleConstraint);
	rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetID, forestConstraintShort);
	rmAddObjectDefConstraint(nuggetID, avoidStronghold);
	rmAddObjectDefConstraint(nuggetID, avoidSocket); 
	rmAddObjectDefConstraint(nuggetID, avoidPlateau);	
	rmSetNuggetDifficulty(1, 3); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);   
	rmSetStatusText("",0.7);


	//removes loop for faster loading times
	//for (j=0; < (6*cNumberNonGaiaPlayers)) {   
		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "ypTreeBorneoCanopy", rmRandInt(2,3), rmRandFloat(8.0,9.0));
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidSocket);
	  	rmAddObjectDefConstraint(mapTrees, circleConstraint);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
//		rmAddObjectDefConstraint(mapTrees, avoidPlateau);	
		rmAddObjectDefConstraint(mapTrees, avoidWaterShort);	
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 12*cNumberNonGaiaPlayers);
	//}
	rmSetStatusText("",0.9);
	}
 
