/*
==============================
           Yalu River
          by dansil92
==============================
*/
include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
include "triggers\triggerLoader.xs";

void main(void) {
	rmSetStatusText("",0.01);
   // Picks the map size
	int playerTiles= 12000;
	if (cNumberNonGaiaPlayers > 4){
		playerTiles = 11000;
	}else if (cNumberNonGaiaPlayers > 6){
		playerTiles = 10500;
	}


	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);

	if (cNumberTeams >= 3){
 size = (size*1.3);
}

	rmSetMapSize(1.1*size, size);

	rmSetMapType("land");
        rmSetMapType("water");
	rmSetMapType("yellowRiver");
	//rmSetMapType("tropical");
       	rmTerrainInitialize("grass");
	rmEnableLocalWater(true);
 	  rmSetGlobalRain( 0.8 );
		rmSetWindMagnitude(3.0);

		rmSetLightingSet("311b");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
	rmSetSeaLevel(3.0);
		rmSetSeaType("yucatan Coast");


		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 13.0);

        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 26.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 45.0);
		int avoidHuntSmall=rmCreateTypeDistanceConstraint("avoid hunts", "huntable", 20.0);

		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 14.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 60.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "mineTin", 10.0);

		int waterCoin=rmCreateTypeDistanceConstraint("avoid coin smallest", "mineTin", 8.0);


        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "mineTin", 55.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 9.0);








        int cliffWater2 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 1.5);
        int cliffWater3 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 2.5);


        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 8.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 30.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 60.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 48.0);


int avoidNuggetSmall =rmCreateTypeDistanceConstraint("avoid nuggs", "AbstractNugget", 10.0);

  int avoidBerries=rmCreateTypeDistanceConstraint("avoid berries", "berrybush", 20.0);
  int avoidBerriesSmall=rmCreateTypeDistanceConstraint("avoid berries smoll", "berrybush", 8.0);


int stayWest = rmCreatePieConstraint("Stay West",0.47,0.53, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(180),rmDegreesToRadians(0));

int stayEast = rmCreatePieConstraint("Stay East",0.53,0.47, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(180));

int avoidTemple=rmCreateTypeDistanceConstraint("avoid temples", "SPCAztecTemple", 12.0);
	int NWconstraint = rmCreateBoxConstraint("stay in NW portion", 0, 0.4, 1, 1);

   

	int PlayerNum = cNumberNonGaiaPlayers;
	int TeamNum = cNumberTeams;
	int numPlayer = cNumberPlayers;


    
 // =============Player placement ======================= 
    float spawnSwitch = rmRandFloat(0,1.2);
spawnSwitch = 0.1;


	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){

	if (PlayerNum == 2)
	{
	rmPlacePlayer(1, 0.25, 0.19);
	rmPlacePlayer(2, 0.75, 0.19);	}

	if (PlayerNum == 4)
	{			
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.2, 0.15, 0.32, 0.24, 0, 0);
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.8, 0.15, 0.68, 0.24, 0, 0);

	}

			rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.2, 0.14, 0.38, 0.275, 0, 0);
			rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.8, 0.14, 0.62, 0.275, 0, 0);

		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
	rmPlacePlayer(2, 0.4, 0.92);
	rmPlacePlayer(1, 0.6, 0.08);	}

	if (PlayerNum == 4)
	{			
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.35, 0.92, 0.65, 0.85, 0, 0);
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.65, 0.08, 0.35, 0.15, 0, 0);

	}


			rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.25, 0.92, 0.75, 0.8, 0, 0);
			rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.75, 0.08, 0.25, 0.2, 0, 0);

		}
	}else{

	//*************ffa placement********
	
	rmPlacePlayersLine(0.1, 0.26, 0.9, 0.26, 0, 0);

	}

		
	chooseMercs();
wotta_triggers();

        rmSetStatusText("",0.1); 


        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	   rmSetAreaMix(continent2, "coastal_japan_c");
    //    rmSetAreaTerrainType(continent2, "carolinas\groundforest_car");       
 rmSetAreaBaseHeight(continent2, 0.0);
        rmSetAreaCoherence(continent2, 1.0);
   //     rmSetAreaSmoothDistance(continent2, 6);
        rmSetAreaHeightBlend(continent2, 3);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 10);
        rmSetAreaElevationVariation(continent2, 3);
        rmSetAreaElevationPersistence(continent2, .2);
        rmSetAreaElevationOctaves(continent2, 5);
        rmSetAreaElevationMinFrequency(continent2, 0.04);
        rmSetAreaElevationType(continent2, cElevTurbulence);  
        rmBuildArea(continent2);    

		int classPatch = rmDefineClass("patch");
		int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 9.0);
		int classCenter = rmDefineClass("center");
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 20.0);
		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.54), rmDegreesToRadians(0), rmDegreesToRadians(360));
        

       		for (i=0; < cNumberNonGaiaPlayers*60){
			int patchID = rmCreateArea("first patch"+i);
			rmSetAreaWarnFailure(patchID, false);
			rmSetAreaSize(patchID, rmAreaTilesToFraction(20), rmAreaTilesToFraction(25));
        rmSetAreaTerrainType(patchID, "mongolia\ground_grass1_mongol");
	//		rmAddAreaToClass(patchID, rmClassID("patch"));
			rmSetAreaSmoothDistance(patchID, 1.0);
			rmBuildArea(patchID); 
		}



	rmSetStatusText("",0.2);


//===================River=====================

//	int TeamNum = cNumberTeams;
//	 numPlayer = cNumberPlayers;
	string riverType = "Coastal Japan";


	int riverID = rmRiverCreate(-1, riverType, 8, 8, 5+numPlayer*1.5, 6+numPlayer*1.5); 
    rmRiverSetBankNoiseParams(riverID, 0.07, 2, 15.0, 15.0, 0.667, 1.8);

  rmRiverAddWaypoint(riverID, 0.0, 0.34);
  rmRiverAddWaypoint(riverID, 0.4, 0.41);
  rmRiverAddWaypoint(riverID, 0.6, 0.41);

  rmRiverAddWaypoint(riverID, 1.0, 0.34);

	rmRiverSetShallowRadius(riverID, 16);


	rmRiverBuild(riverID);
	//rmRiverReveal(riverID, 2);

//====================================================


  // Trade route silk road style

  int tradeRouteID = rmCreateTradeRoute();

  int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
  rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

  rmAddObjectDefItem(socketID, "ypTradingPostCapture", 1, 2.0);
 // rmAddObjectDefItem(socketID, "ypBlindMonk", 2, 10.0);
//  rmSetNuggetDifficulty(99, 99);
	rmSetObjectDefAllowOverlap(socketID, false);
  rmSetObjectDefMinDistance(socketID, 0.0);
  rmSetObjectDefMaxDistance(socketID, 5.0);
        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

  
  rmAddTradeRouteWaypoint(tradeRouteID , 0.1, 0.8);

  rmAddTradeRouteWaypoint(tradeRouteID , 0.25, .75);

  rmAddTradeRouteWaypoint(tradeRouteID , 0.5, .7);

  rmAddTradeRouteWaypoint(tradeRouteID , 0.75, .75);

  rmAddTradeRouteWaypoint(tradeRouteID , 0.9, 0.8);

  bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water");


 
	// add the sockets along the trade route.
  vector socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.2);

  int tempCounter = 0;
  int numberPosts = 3;

	if (PlayerNum >= 6)
	{
numberPosts = 5;
}
    
  float loc0 = 0.5;
  float loc1 = 0.25;
  float loc2 = 0.75;
  float loc3 = 0.05;
  float loc4 = 0.95;
 

 float loc5 = 0.15;
  float loc6 = 0.85;
  float loc7 = 0.4; 
  float loc8 = 0.6;
  float tempLoc = 0.0;

  for(i = 0; < numberPosts) {
    
    if(i == 0)
      tempLoc = loc0;
    
    else if (i == 1)
      tempLoc = loc1;
    
    else if (i == 2)
      tempLoc = loc2;
    
    else if (i == 3)
      tempLoc = loc3;
    
    else if (i == 4)
      tempLoc = loc4;
    
    else if (i == 5)
      tempLoc = loc5;
    
    else if (i == 6)
      tempLoc = loc6;
      
    else if (i == 7)
      tempLoc = loc7;
      
    else if (i == 8)
      tempLoc = loc8;
    
    socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, tempLoc);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);




}



//=========== trade route small =================
		int socketID2=rmCreateObjectDef("sockets to dock Trade Posts2");
        rmAddObjectDefItem(socketID2, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID2, true);
        rmSetObjectDefMinDistance(socketID2, 0.0);
        rmSetObjectDefMaxDistance(socketID2, 6.0);   
	rmAddObjectDefConstraint(socketID2, avoidWaterShort);	
   
       
        int tradeRouteID2 = rmCreateTradeRoute();


        rmSetObjectDefTradeRouteID(socketID2, tradeRouteID2);

if (cNumberTeams == 2){ 

	rmAddTradeRouteWaypoint(tradeRouteID2, 0.2, 0.0);

 	rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.21); 

 	rmAddTradeRouteWaypoint(tradeRouteID2, 0.8, 0.0); 

}else{

	rmAddTradeRouteWaypoint(tradeRouteID2, 0.05, 0.11);

 	rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.11); 

 	rmAddTradeRouteWaypoint(tradeRouteID2, 0.95, 0.11); 
}

        rmBuildTradeRoute(tradeRouteID2, "water");




        vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.2);
        rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
            socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.8);
        rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
if (cNumberTeams >= 3){
            socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.5);
        rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
}


//====================================================
	rmSetStatusText("",0.3);
//===================================================

//define player areas

for(i=1; < cNumberNonGaiaPlayers + 1) {

    int PlayerArea1 = rmCreateArea("NeedLand1"+i);
        rmSetAreaSize(PlayerArea1, rmAreaTilesToFraction(1300), rmAreaTilesToFraction(1300));
//		rmAddAreaToClass(PlayerArea1, rmClassID("classPlateau"));
//		rmAddAreaToClass(PlayerArea1, rmClassID("patch"));
       rmSetAreaHeightBlend(PlayerArea1, 3);
        rmSetAreaLocation(PlayerArea1, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmSetAreaCoherence(PlayerArea1, 0.93);
        rmBuildArea(PlayerArea1);

}


		rmSetStatusText("",0.4);


//=========================================

//=========2 player fixed mines============

  	int smollMines = rmCreateObjectDef("competitive gold");
	rmAddObjectDefItem(smollMines, "mineTin", 1, 1.0);
	rmSetObjectDefMinDistance(smollMines, 0.0);
	rmSetObjectDefMaxDistance(smollMines, 2.0);
	rmAddObjectDefConstraint(smollMines, avoidWaterShort);


//centre map
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.37, 0.08, 1);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.63, 0.08, 1);

	if (PlayerNum <= 4 && cNumberTeams == 2){
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.5, 0.29, 1);
}
//behind base
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.2, 0.22);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.8, 0.22);

	if (PlayerNum >= 5 && cNumberTeams == 2)
{

	rmPlaceObjectDefAtLoc(smollMines, 0, 0.09, 0.27);
	rmPlaceObjectDefAtLoc(smollMines, 0, 0.91, 0.27);
}
//across river
	rmPlaceGroupingAtLoc(smollMines, 0, 0.1, 0.7);
	rmPlaceGroupingAtLoc(smollMines, 0, 0.9, 0.7);





int avoidTPSocket =rmCreateTypeDistanceConstraint("avoid trade socket", "SocketTradeRoute", 11.0);



// BUILD NATIVE SITES

	//Choose Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int subCiv3=-1;

   if (rmAllocateSubCivs(4) == true)
   {
      subCiv0=rmGetCivID("Zen");
      rmEchoInfo("subCiv0 is Zen"+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Zen");

		subCiv1=rmGetCivID("Zen");
      rmEchoInfo("subCiv1 is Zen"+subCiv1);
		if (subCiv1 >= 0)
			 rmSetSubCiv(1, "Zen");
	 
		subCiv2=rmGetCivID("Shaolin");
      rmEchoInfo("subCiv2 is Shaolin"+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Shaolin");

		subCiv3=rmGetCivID("Shaolin");
      rmEchoInfo("subCiv3 is Shaolin"+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Shaolin");
	}
	
	// Set up Natives	
	int nativeID0 = -1;
    int nativeID1 = -1;
	int nativeID2 = -1;
    int nativeID3 = -1;
		
	nativeID0 = rmCreateGrouping("native site 1", "native zen temple cj 05");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 3.00);

	nativeID1 = rmCreateGrouping("native site 2", "native shaolin temple yr 05");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 3.00);




	if (cNumberTeams == 2){

	rmPlaceGroupingAtLoc(nativeID0, 0, 0.5, 0.88);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.5, 0.1);
if (cNumberNonGaiaPlayers >= 5){
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.5, 0.30);
}

}else{
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.5, 0.88);
}

//always these guys
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.15, 0.65);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.85, 0.65);



				


		rmSetStatusText("",0.45);
		//starting objects

	int flagLand = rmCreateTerrainDistanceConstraint("flags dont like land", "land", true, 10.0);



	int popSpace =rmCreateObjectDef("player pop block");
	rmAddObjectDefItem(popSpace, "ypPopBlock", 1, 3.0);
    rmSetObjectDefMinDistance(popSpace, 10.0);
    rmSetObjectDefMaxDistance(popSpace, 18.0);

		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
	rmAddObjectDefConstraint(playerStart, avoidWaterShort);
	rmAddObjectDefConstraint(playerStart, avoidTemple);

       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "mineTin", 1, 3.0);
        rmSetObjectDefMinDistance(goldID, 17.0);
        rmSetObjectDefMaxDistance(goldID, 17.0);
        rmAddObjectDefConstraint(goldID, avoidCoin);
	rmAddObjectDefConstraint(goldID, avoidWaterShort);
	rmAddObjectDefConstraint(goldID, avoidTemple);



        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "BerryBush", 2, 2.0);
        rmSetObjectDefMinDistance(berryID, 12.0);
        rmSetObjectDefMaxDistance(berryID, 13.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);

        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "ypTreeJapanesePine", rmRandInt(6,7), 7.0);
        rmSetObjectDefMinDistance(treeID, 19.0);
        rmSetObjectDefMaxDistance(treeID, 21.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
	rmAddObjectDefConstraint(treeID, avoidWaterShort);
 	rmAddObjectDefConstraint(treeID, avoidBerriesSmall);

 
        int scoutID = rmCreateObjectDef("starting scout");
         rmAddObjectDefItem(scoutID , "ypMarathanCatamaran", 1, 0.0);
         rmAddObjectDefItem(scoutID , "ypFishingBoatAsian", 1, 7.0);
         rmAddObjectDefItem(scoutID , "HomeCityWaterSpawnFlag", 1, 7.0);

//HomeCityWaterSpawnFlag
        rmSetObjectDefMinDistance(scoutID, 0.0);
        rmSetObjectDefMaxDistance(scoutID, 35.0);
        rmAddObjectDefConstraint(scoutID, flagLand);


        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "ypGiantSalamander", 8, 6.0);
        rmSetObjectDefMinDistance(foodID, 2.0);
        rmSetObjectDefMaxDistance(foodID, 3.0);
	rmAddObjectDefConstraint(foodID, avoidCoin);	
        rmSetObjectDefCreateHerd(foodID, true);
  	rmAddObjectDefConstraint(foodID, avoidTemple);

        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "ypSerow", 9, 8.0);
        rmSetObjectDefMinDistance(foodID2, 30.0);
        rmSetObjectDefMaxDistance(foodID2, 30.0);
        rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, avoidWaterShort);	
	rmAddObjectDefConstraint(foodID2, avoidPlateau);
  	rmAddObjectDefConstraint(foodID2, circleConstraint);
  	rmAddObjectDefConstraint(foodID2, avoidHuntSmall);
	rmAddObjectDefConstraint(foodID2, avoidTradeRouteSmall);



                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "ypMarcoPoloSheep", 8, 8.0);
        rmSetObjectDefMinDistance(foodID3, 59.0);
        rmSetObjectDefMaxDistance(foodID3, 59.0);
	rmAddObjectDefConstraint(foodID3, avoidWaterShort);	
	rmAddObjectDefConstraint(foodID3, avoidPlateau);
        rmSetObjectDefCreateHerd(foodID3, true);

	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmSetNuggetDifficulty(1, 1); 
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 3.0);
    rmSetObjectDefMinDistance(playerNuggetID, 28.0);
    rmSetObjectDefMaxDistance(playerNuggetID, 29.0);
//	rmAddObjectDefConstraint(playerNuggetID, circleConstraint);
	rmAddObjectDefConstraint(playerNuggetID, avoidWaterShort);	
  	rmAddObjectDefConstraint(playerNuggetID, avoidTemple);

	int extraberrywagon=rmCreateObjectDef("JapAn cAnT hUnT");
  rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
  rmSetObjectDefMinDistance(extraberrywagon, 6.0);
  rmSetObjectDefMaxDistance(extraberrywagon, 7.0);



		rmSetStatusText("",0.5);  
    
    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 2.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 2.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i)-rmXTilesToFraction(10));
        rmPlaceObjectDefAtLoc(popSpace, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));


	if (PlayerNum >= 3)
{
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
}



        rmPlaceObjectDefAtLoc(berryID , i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
//        rmPlaceObjectDefAtLoc(playerNuggetID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

       rmPlaceObjectDefAtLoc(scoutID, i, rmPlayerLocXFraction(i), 0.41);


	}

	rmSetStatusText("",0.6);
	/*
	==================
	resource placement
	==================
	*/


//	if (PlayerNum >= 3)
//{
  	int copperMine = rmCreateObjectDef("east mines");
	rmAddObjectDefItem(copperMine, "mineTin", 1, 1.0);
	rmSetObjectDefMinDistance(copperMine, rmXFractionToMeters(0.0));
	rmSetObjectDefMaxDistance(copperMine, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(copperMine, avoidCoinMed);
	rmAddObjectDefConstraint(copperMine, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(copperMine, avoidPlateau);	
	rmAddObjectDefConstraint(copperMine, avoidWaterShort);
	rmAddObjectDefConstraint(copperMine, NWconstraint);
	rmAddObjectDefConstraint(copperMine, circleConstraint);
	rmPlaceObjectDefAtLoc(copperMine, 0, 0.5, 0.5, 7*cNumberNonGaiaPlayers);
//}
	


	rmSetStatusText("",0.7);


    int serowHunts = rmCreateObjectDef("serowHunts");
	rmAddObjectDefItem(serowHunts, "ypSerow", rmRandInt(7,8), 9.0);
	rmSetObjectDefCreateHerd(serowHunts, true);
	rmSetObjectDefMinDistance(serowHunts, 0);
	rmSetObjectDefMaxDistance(serowHunts, 5);
	rmAddObjectDefConstraint(serowHunts, circleConstraint);
	rmAddObjectDefConstraint(serowHunts, avoidWaterShort);	

	if (PlayerNum == 2){	
//centre hunts
	rmPlaceObjectDefAtLoc(serowHunts, 0, 0.5, 0.3, 1);
	rmPlaceObjectDefAtLoc(serowHunts, 0, 0.5, 0.05, 1);
//2nd hunt
	rmPlaceObjectDefAtLoc(serowHunts, 0, 0.3, 0.25, 1);
	rmPlaceObjectDefAtLoc(serowHunts, 0, 0.7, 0.24, 1);
}	

	rmAddObjectDefConstraint(serowHunts, NWconstraint);
	rmAddObjectDefConstraint(serowHunts, avoidHunt);	//rmAddObjectDefConstraint(serowHunts, waterHunt);
	rmAddObjectDefConstraint(serowHunts, avoidPlateau);
	rmAddObjectDefConstraint(serowHunts, avoidCoin);	
	rmAddObjectDefConstraint(serowHunts, circleConstraint);
	rmSetObjectDefMaxDistance(serowHunts, rmXFractionToMeters(0.5));
	rmPlaceObjectDefAtLoc(serowHunts, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);



    int waterLizard = rmCreateObjectDef("waterLizard");
	rmAddObjectDefItem(waterLizard, "ypGiantSalamander", rmRandInt(7,7), 10.0);
	rmSetObjectDefCreateHerd(waterLizard, true);
	rmSetObjectDefMinDistance(waterLizard, 0);
	if (PlayerNum == 2){	
//corner hunts
	rmPlaceObjectDefAtLoc(serowHunts, 0, 0.1, 0.24, 1);
	rmPlaceObjectDefAtLoc(serowHunts, 0, 0.9, 0.24, 1);
}

	rmSetObjectDefMaxDistance(waterLizard, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(waterLizard, circleConstraint);
//	rmAddObjectDefConstraint(waterLizard, avoidTownCenter);
	rmAddObjectDefConstraint(waterLizard, avoidHunt);		rmAddObjectDefConstraint(waterLizard, waterHunt);
	rmAddObjectDefConstraint(waterLizard, avoidPlateau);
	rmAddObjectDefConstraint(waterLizard, avoidWaterShort);	
	rmAddObjectDefConstraint(waterLizard, avoidCoin);
	rmAddObjectDefConstraint(waterLizard, avoidTemple);		
	rmPlaceObjectDefAtLoc(waterLizard, 0, 0.5, 0.5, 7*cNumberNonGaiaPlayers);


		rmSetStatusText("",0.8);

	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
	rmSetObjectDefMinDistance(nuggetID, 0.0); 
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.25)); 
	rmAddObjectDefConstraint(nuggetID, avoidNugget); 
	rmAddObjectDefConstraint(nuggetID, circleConstraint);
	rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetID, forestConstraintShort);
	rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSmall);
	//rmAddObjectDefConstraint(nuggetID, avoidTownCenterMore); 
	rmAddObjectDefConstraint(nuggetID, avoidPlateau);
	rmAddObjectDefConstraint(nuggetID, avoidWaterShort);	
	rmAddObjectDefConstraint(nuggetID, avoidCoin);	
	rmSetNuggetDifficulty(3, 3); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.75, 2*cNumberNonGaiaPlayers);   
//weaker nuggets
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.75)); 
	rmSetNuggetDifficulty(1, 2); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);   



		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "ypTreeAshoka", rmRandInt(7,8), rmRandFloat(13.0,14.0));
		rmAddObjectDefItem(mapTrees, "ypTreeJapanesePine", rmRandInt(3,4), rmRandFloat(14.0,15.0));
		rmAddObjectDefItem(mapTrees, "UnderbrushYellowRiver", rmRandInt(7,8), rmRandFloat(8.0,9.0));
		rmAddObjectDefItem(mapTrees, "UnderbrushCoastalJapan", rmRandInt(7,8), rmRandFloat(10.0,11.0));
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.9));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidNuggetSmall);
	  	rmAddObjectDefConstraint(mapTrees, avoidCoin);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees, circleConstraint2);	
		rmAddObjectDefConstraint(mapTrees, avoidPlateau);	
		rmAddObjectDefConstraint(mapTrees, avoidWaterShort);
  	rmAddObjectDefConstraint(mapTrees, avoidTemple);
	rmAddObjectDefConstraint(mapTrees, avoidTPSocket);
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 60*cNumberNonGaiaPlayers);
	

	rmSetStatusText("",0.9);


	//fish and their constraints placed together at the end for ease of removal
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "FishSardine", 10.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 60.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 26.0);

	int fishID=rmCreateObjectDef("fish Mahi");
	rmAddObjectDefItem(fishID, "FishSardine", 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 12*cNumberNonGaiaPlayers);




		int bonusTrees=rmCreateObjectDef("bonusTrees");
		rmAddObjectDefItem(bonusTrees, "UnderbrushCoastalJapan", rmRandInt(4,5), rmRandFloat(8.0,9.0));
		rmSetObjectDefMinDistance(bonusTrees, 0);
		rmSetObjectDefMaxDistance(bonusTrees, rmXFractionToMeters(0.47));
	  	rmAddObjectDefConstraint(bonusTrees, avoidCoin);
	  	rmAddObjectDefConstraint(bonusTrees, circleConstraint2);	
		rmPlaceObjectDefAtLoc(bonusTrees, 0, 0.5, 0.5, 40*cNumberNonGaiaPlayers);

		int waterProps =rmCreateObjectDef("water decor");
		rmAddObjectDefItem(waterProps, "RiverShallowsOri", rmRandInt(2,3), rmRandFloat(4.0,5.0));
		rmSetObjectDefMinDistance(waterProps, 0);
		rmSetObjectDefMaxDistance(waterProps, rmXFractionToMeters(0.47));
	  	rmAddObjectDefConstraint(waterProps, flagLand);	
		rmPlaceObjectDefAtLoc(waterProps, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);


//ShorelineRockSmallNE
//RiverShallowsOri



  // King of the Hill (added 2026-11 for WoL): centre, on the river bank between the two sides
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
 
