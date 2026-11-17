include "triggers\triggerLoader.xs";

/*
==============================
     	     Owikeno
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
	size = 2.8 * sqrt(cNumberNonGaiaPlayers*playerTiles);
}

	rmSetMapSize(size, size);

	rmSetMapType("water");
        rmSetMapType("grass");
        rmSetMapType("northwestTerritory");
	//rmSetMapType("tropical");
		//rmSetLightingSet("308b_caribbeanlight");
		rmSetLightingSet("303a_nativevillage");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
	rmSetSeaLevel(-3.0);
		rmSetSeaType("Northwest Territory Water");
	rmSetWindMagnitude(8);
       	rmTerrainInitialize("water");

		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 6.0);

		int avoidPlateauWater=rmCreateClassDistanceConstraint("water vs. cliffs", rmClassID("classPlateau"), 18.0);

	int avoidPlateauSPC =rmCreateClassDistanceConstraint("cliffs vs. cliffs", rmClassID("classPlateau"), 36.0);


        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 14.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 54.0);
		int avoidHuntSmall=rmCreateTypeDistanceConstraint("avoid hunts", "huntable", 11.0);

		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 24.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "MineCopper", 12.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "MineCopper", 60.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 9.0);
        int cliffWater = rmCreateTerrainDistanceConstraint("cliff avoids river", "Land", false, 0.01);
        int cliffWater2 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 2.0);
        int cliffWater3 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 4);

	int ffaRoute = 2;
if (cNumberTeams > 2){
	ffaRoute = 18;
}
        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", ffaRoute);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 27.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 9.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 40.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 62.0);

	int avoidNuggetSmall=rmCreateTypeDistanceConstraint("avoid nugget", "AbstractNugget", 8.0);


  int avoidBerries=rmCreateTypeDistanceConstraint("avoid berries", "berrybush", 24.0);
  int avoidBerriesSmall=rmCreateTypeDistanceConstraint("avoid berries smoll", "berrybush", 8.0);

int stayWest = rmCreatePieConstraint("Stay West",0.5,0.5, rmXFractionToMeters(0.1),rmXFractionToMeters(0.55), rmDegreesToRadians(225),rmDegreesToRadians(45));

int stayEast = rmCreatePieConstraint("Stay East",0.53,0.47, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(225),rmDegreesToRadians(45));

   

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
	rmPlacePlayer(1, 0.8, 0.6);
	rmPlacePlayer(2, 0.4, 0.2);	}

if (PlayerNum < 6){
			rmSetPlacementTeam(Team1);
		rmPlacePlayersLine(0.8, 0.6, 0.65, 0.75, 0, 0);
			rmSetPlacementTeam(Team2);
		rmPlacePlayersLine(0.4, 0.2, 0.25, 0.35, 0, 0);

}else{
			rmSetPlacementTeam(Team1);
		rmPlacePlayersLine(0.85, 0.55, 0.65, 0.75, 0, 0);
			rmSetPlacementTeam(Team2);
		rmPlacePlayersLine(0.45, 0.15, 0.25, 0.35, 0, 0);
}
	}else{
	//*************ffa placement********
			rmSetPlacementSection(0.7, 0.05);
			rmSetTeamSpacingModifier(0.25);
		rmPlacePlayersCircular(0.41, 0.41, 0.00);
		
}

		
        chooseMercs();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 0.58, 0.58);
        rmSetAreaLocation(continent2, 0.7, 0.3);
	   rmSetAreaMix(continent2, "nwt_grass1");
        rmSetAreaBaseHeight(continent2, 1.0);
        rmSetAreaCoherence(continent2, 0.95);
        rmSetAreaSmoothDistance(continent2, 6);
        rmSetAreaHeightBlend(continent2, 1);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 10);
        rmSetAreaElevationVariation(continent2, 6);
        rmSetAreaElevationPersistence(continent2, .2);
        rmSetAreaElevationOctaves(continent2, 5);
        rmSetAreaElevationMinFrequency(continent2, 0.04);
        rmSetAreaElevationType(continent2, cElevTurbulence);  
		rmSetAreaCliffHeight(continent2, 2, 1, 0.5);

        rmBuildArea(continent2);    

		int classPatch = rmDefineClass("patch");
		int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 20.0+cNumberNonGaiaPlayers);
		int classCenter = rmDefineClass("center");
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 35.0);
		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
        

int stayLow = rmCreateMaxHeightConstraint("patches stay low", 0.0);

       		for (i=0; < cNumberNonGaiaPlayers*25){
			int patchID = rmCreateArea("first patch"+i);
			rmSetAreaWarnFailure(patchID, false);
			rmSetAreaSize(patchID, rmAreaTilesToFraction(20), rmAreaTilesToFraction(25));
        rmSetAreaTerrainType(patchID, "NWterritory\ground_riverbed2_nwt");
		//	rmAddAreaToClass(patchID, rmClassID("patch"));
			rmSetAreaSmoothDistance(patchID, 1.0);
			rmBuildArea(patchID); 
		}

		for (i=0; < cNumberNonGaiaPlayers*85){
			int patchID2 = rmCreateArea("the second patch"+i);
			rmSetAreaWarnFailure(patchID2, false);
			rmSetAreaSize(patchID2, rmAreaTilesToFraction(35), rmAreaTilesToFraction(57));
        rmSetAreaTerrainType(patchID2, "araucania\groundshore5_ara");
	//		rmAddAreaToClass(patchID2, rmClassID("patch"));
			rmSetAreaSmoothDistance(patchID2, 1.0);
		//	rmBuildArea(patchID2); 
}
		rmSetStatusText("",0.2);


//===========trade route=================
		int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
        rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID, true);
        rmSetObjectDefMinDistance(socketID, 0.0);
        rmSetObjectDefMaxDistance(socketID, 6.0);      
        rmAddObjectDefConstraint(socketID, cliffWater2);

//cliffWater2 
        int tradeRouteID = rmCreateTradeRoute();


//linear TP

	if (cNumberTeams == 2){

        tradeRouteID = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

	rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.4); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.15, 0.65); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.25, 0.75); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.85); 
	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 1.0); 


        rmBuildTradeRoute(tradeRouteID, "WATERdirt");
	vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.0);
/*
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.143);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.286);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.429);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.571);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.714);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.857);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
*/
}else{
//ffa TP Route

        tradeRouteID = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);


		rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.7);
		rmAddTradeRouteWaypoint(tradeRouteID, .55, .45);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.0);


        rmBuildTradeRoute(tradeRouteID, "dirt");


}





 int avoidTPSocket =rmCreateTypeDistanceConstraint("avoid trade socket", "SocketTradeRoute", 8.0);

//=========================================================



        int continent3 = rmCreateArea("continent3");
        rmSetAreaSize(continent3, 0.0015, 0.0015);
        rmSetAreaLocation(continent3, 0.8, 0.2);
		rmAddAreaToClass(continent3, rmClassID("patch"));
		rmAddAreaToClass(continent3, rmClassID("classPlateau"));
        rmBuildArea(continent3);    


        int continent4 = rmCreateArea("continent4");
        rmSetAreaSize(continent4, 0.0015, 0.0015);
        rmSetAreaLocation(continent4, 0.38, 0.62);
		rmAddAreaToClass(continent4, rmClassID("patch"));
        rmBuildArea(continent4);    



				


		int middleSegment=rmCreateArea("middleSegment");
        rmSetAreaLocation(middleSegment, 0.7, 0.3); 
        rmSetAreaSize(middleSegment, .02, .02); 
        rmSetAreaCoherence(middleSegment, 0.9);
        rmBuildArea(middleSegment);


// ******KEEP BUILDABLE LAND UNDER TCS ******

for(i=1; < cNumberNonGaiaPlayers + 1) {

    int PlayerArea1 = rmCreateArea("NeedLand1"+i);
if (cNumberTeams == 2){
        rmSetAreaSize(PlayerArea1, .01, .01);
}else{
        rmSetAreaSize(PlayerArea1, rmAreaTilesToFraction(500), rmAreaTilesToFraction(500));
}
        rmSetAreaBaseHeight(PlayerArea1, 1.0);
		rmAddAreaToClass(PlayerArea1, rmClassID("patch"));
		rmAddAreaToClass(PlayerArea1, rmClassID("center"));
        rmSetAreaLocation(PlayerArea1, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmSetAreaTerrainType(PlayerArea1, "NWterritory\ground_grass1_nwt");
        rmSetAreaSmoothDistance(PlayerArea1, 16);
        rmSetAreaHeightBlend(PlayerArea1, 2);

        rmSetAreaCoherence(PlayerArea1, 0.8);
        rmBuildArea(PlayerArea1);

//*********connections**********
if (cNumberTeams == 2){
	int connection1	= rmCreateConnection("make paths centre"+i);
	rmSetConnectionType(connection1, cConnectAreas, true, 1.0);
	rmAddConnectionArea(connection1, PlayerArea1);
	rmAddConnectionArea(connection1, middleSegment);
	rmSetConnectionPositionVariance(connection1, 0.0);
	//rmSetConnectionBaseHeight(connection1, 1.0);
	rmSetConnectionCoherence(connection1, 0.8);
	//rmSetConnectionHeightBlend(connection1, 1);
	rmSetConnectionWidth(connection1, 1, 0.0);
rmAddConnectionToClass(connection1, rmClassID("patch"));
rmAddConnectionToClass(connection1, rmClassID("center"));

	rmBuildConnection(connection1);
}

}

	if (cNumberTeams > 2){

//sockets along route in ffa

	vector socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID, 0.0);
	socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID, 0.125);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc3 );
	socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc3 );
	socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID, 0.375);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc3 );
	socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc3 );
	socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID, 0.625);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc3 );
	socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc3 );
	socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID, 0.875);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc3 );

}

int pondCount = 3;
if (cNumberTeams > 2){
	pondCount = 8;
}

	for (j=0; < (pondCount*cNumberNonGaiaPlayers)) {   

		int centrePond=rmCreateArea("centre Pond"+j);
        //rmSetAreaLocation(centrePond, 0.5, 0.5);
		rmAddAreaToClass(centrePond, rmClassID("patch"));

if (cNumberTeams == 2){
        rmSetAreaSize(centrePond, 0.036, 0.036);
}else{
	rmSetAreaSize(centrePond, rmAreaTilesToFraction(700), rmAreaTilesToFraction(900));

}
        rmSetAreaWaterType(centrePond, "Northwest Territory Water");
		rmSetAreaCliffHeight(centrePond, rmRandInt(2,3), 1, 0.15);

 //       rmSetAreaBaseHeight(centrePond, 0.0);
//	rmAddAreaConstraint(centrePond, avoidPlateauWater);
	rmAddAreaConstraint(centrePond, avoidPatch);
	rmAddAreaConstraint(centrePond, avoidTradeRouteSmall);
	rmAddAreaConstraint(centrePond, avoidPlateauWater);
       // rmSetAreaSmoothDistance(centrePond, 8);
      //  rmSetAreaHeightBlend(centrePond, 2);


        rmSetAreaCoherence(centrePond, .94);

if (j == 0){
	rmSetAreaLocation(centrePond, 0.2, .5);
	rmAddAreaInfluenceSegment(centrePond, 0.17,0.5, 0.35,0.5);
     rmSetAreaSize(centrePond, 0.036, 0.036);

}
if (j == 1){
		rmSetAreaLocation(centrePond, 0.5, .8);
	rmAddAreaInfluenceSegment(centrePond, 0.5,0.83, 0.5,0.65);
        rmSetAreaSize(centrePond, 0.036, 0.036);

}
if (j == 2){
		rmSetAreaLocation(centrePond, 0.5, 0.5);
}

if (j == 3){
		rmSetAreaLocation(centrePond, 0.5, 0.1);
}

if (j == 4){
		rmSetAreaLocation(centrePond, 0.9, 0.5);
}


        rmBuildArea(centrePond);

}

		rmSetStatusText("",0.3);


//spc areas for flag placement

		int flagPond1=rmCreateArea("nw flag");
        rmSetAreaLocation(flagPond1, 0.65, 0.9);
        rmSetAreaSize(flagPond1, .01, .01);      
        rmSetAreaCoherence(flagPond1, .99);
        rmBuildArea(flagPond1);

		int flagPond2=rmCreateArea("sw flag");
        rmSetAreaLocation(flagPond2, 0.1, 0.35);
        rmSetAreaSize(flagPond2, .01, .01);      
        rmSetAreaCoherence(flagPond2, .99);
        rmBuildArea(flagPond2);




//==========random islands==============

	int stayWater = rmCreateTerrainDistanceConstraint("islands stay in water", "land", true, 18.0);

	int islandCount = 3;
if (cNumberNonGaiaPlayers > 2){
	islandCount = 2.5*cNumberNonGaiaPlayers;
}

	for (j=0; < islandCount) {   
			int smallIslands = rmCreateArea("smallIslands"+j);
        rmSetAreaSize(smallIslands, rmAreaTilesToFraction(180), rmAreaTilesToFraction(190));
	//	rmAddAreaToClass(smallIslands, rmClassID("classPlateau"));
		rmAddAreaToClass(smallIslands, rmClassID("center"));
		rmSetAreaCliffType(smallIslands, "Araucania Southern Coast");
		rmSetAreaCliffEdge(smallIslands, 1, 1, 0.0, 0.0, 2);	
	rmSetAreaCliffPainting(smallIslands, true, true, true, 1.5, true);
		rmSetAreaCliffHeight(smallIslands, 4.3, 1, 0.5);
        rmSetAreaSmoothDistance(smallIslands, 1);
        rmSetAreaHeightBlend(smallIslands, 1);
	rmAddAreaConstraint(smallIslands, avoidCenter);
	rmAddAreaConstraint(smallIslands, avoidTradeRouteSmall);
	rmAddAreaConstraint(smallIslands, circleConstraint2);
if (cNumberNonGaiaPlayers > 2){
	rmAddAreaConstraint(smallIslands, stayWater);
}
        rmSetAreaCoherence(smallIslands, .93);

if (j == 0){
	rmSetAreaLocation(smallIslands, 0.2, .8);
}
if (j == 1){
	rmSetAreaLocation(smallIslands, 0.13, .5);
}
if (j == 2){
	rmSetAreaLocation(smallIslands, 0.5, .87);
}


        rmBuildArea(smallIslands);  
	}

//==========place sockets on islands====================


//socketID
	if (cNumberTeams == 2){
        rmPlaceObjectDefAtLoc(socketID, 0, 0.2, 0.8, 1 );
        rmPlaceObjectDefAtLoc(socketID, 0, 0.13, 0.5, 1 );
        rmPlaceObjectDefAtLoc(socketID, 0, 0.5, 0.87, 1 );
}

//=======================================================

		rmSetStatusText("",0.4);


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
	 
		subCiv2=rmGetCivID("Nootka");
      rmEchoInfo("subCiv2 is Nootka"+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Nootka");

		subCiv3=rmGetCivID("Nootka");
      rmEchoInfo("subCiv3 is Nootka"+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Nootka");
	}
	
	// Set up Natives	
	int nativeID0 = -1;
    int nativeID1 = -1;
	int nativeID2 = -1;
    int nativeID3 = -1;
		
	nativeID0 = rmCreateGrouping("native site 1", "native Cree village 1");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 1.00);
	rmAddGroupingToClass(nativeID0, rmClassID("patch"));

	nativeID1 = rmCreateGrouping("native site 2", "native Nootka village 1");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 2.00);
	rmAddGroupingToClass(nativeID1, rmClassID("patch"));


//========place=====
	//rmPlaceGroupingAtLoc(nativeID0, 0, 0.55, 0.65);

	rmPlaceGroupingAtLoc(nativeID1, 0, 0.80, 0.22);

	//if (cNumberNonGaiaPlayers >= 4){
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.4, 0.62);
	//rmPlaceGroupingAtLoc(nativeID1, 0, 0.6, 0.45);
//}





		//starting objects

	int flagLand = rmCreateTerrainDistanceConstraint("flags dont like land", "land", true, 10.0);


		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 14.0);
	rmAddObjectDefConstraint(playerStart, avoidWaterShort);

       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "MineCopper", 1, 1.0);
        rmSetObjectDefMinDistance(goldID, 14.0);
        rmSetObjectDefMaxDistance(goldID, 16.0);
        rmAddObjectDefConstraint(goldID, avoidCoin);

    
        int goldID2 = rmCreateObjectDef("starting gold 1v1");
        rmAddObjectDefItem(goldID2, "MineCopper", 1, 1.0);
        rmSetObjectDefMinDistance(goldID2, 0.0);
        rmSetObjectDefMaxDistance(goldID2, 2.0);
   


        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "BerryBush", 5, 4.0);
        rmSetObjectDefMinDistance(berryID, 14.0);
        rmSetObjectDefMaxDistance(berryID, 15.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "TreeNorthwestTerritory", rmRandInt(9,10), 7.0);
        rmSetObjectDefMinDistance(treeID, 20.0);
        rmSetObjectDefMaxDistance(treeID, 21.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
		rmAddObjectDefToClass(treeID, rmClassID("classForest")); 

 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "moose", 8, 8.0);
        rmSetObjectDefMinDistance(foodID, 16.0);
        rmSetObjectDefMaxDistance(foodID, 16.0);
	rmAddObjectDefConstraint(foodID, avoidCoin);	
        rmSetObjectDefCreateHerd(foodID, true);
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "caribou", 7, 8.0);
        rmSetObjectDefMinDistance(foodID2, 20.0);
        rmSetObjectDefMaxDistance(foodID2, 20.0);
	rmAddObjectDefConstraint(foodID2, avoidHuntSmall);	
        rmSetObjectDefCreateHerd(foodID2, true);
        rmAddObjectDefConstraint(foodID2, avoidCoin);

                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "moose", 8, 8.0);
        rmSetObjectDefMinDistance(foodID3, 40.0);
        rmSetObjectDefMaxDistance(foodID3, 40.0);
	rmAddObjectDefConstraint(foodID3, avoidWaterShort);	
        rmSetObjectDefCreateHerd(foodID3, true);


  int playerCrateID=rmCreateObjectDef("bonus starting crates");
 //rmAddObjectDefItem(playerCrateID, "SPCXPCampfire", 1, 2.0);
 rmAddObjectDefItem(playerCrateID, "ypPopBlock", 1, 2.0);
  rmSetObjectDefMinDistance(playerCrateID, 10);
  rmSetObjectDefMaxDistance(playerCrateID, 12);


		int extraberrywagon=rmCreateObjectDef("JapAn cAnT hUnT");
  rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
  rmSetObjectDefMinDistance(extraberrywagon, 6.0);
  rmSetObjectDefMaxDistance(extraberrywagon, 7.0);


	if (PlayerNum == 2){

        rmPlaceObjectDefAtLoc(goldID2, 0, 0.3, 0.7, 1 );
        rmPlaceObjectDefAtLoc(goldID2, 0, 0.55, 0.27, 1 );
        rmPlaceObjectDefAtLoc(goldID2, 0, 0.73, 0.45, 1 );
}


		rmSetStatusText("",0.5);  





    
    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 1.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 1.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(berryID , i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerCrateID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));





if (cNumberTeams == 2){
//===team & 2 player flag===
    int flag1 = rmFindCloserArea(rmPlayerLocXFraction(i), rmPlayerLocZFraction(i), flagPond2, flagPond1);

		int waterFlag = rmCreateObjectDef("HC water flag "+i);
         rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 10.0);
         rmAddObjectDefItem(waterFlag, "Canoe", 1, 3.0);
         rmSetObjectDefMinDistance(waterFlag, 0);
         rmSetObjectDefMaxDistance(waterFlag, 25);
	rmAddObjectDefConstraint(waterFlag, flagLand);
        rmAddObjectDefConstraint(waterFlag, circleConstraint);
       rmPlaceObjectDefAtAreaLoc(waterFlag, i, flag1, 1);
}else{
//===ffa flag===
	 waterFlag = rmCreateObjectDef("HC water flag "+i);
         rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 5.0);
         rmAddObjectDefItem(waterFlag, "Canoe", 1, 3.0);
         rmSetObjectDefMinDistance(waterFlag, 20);
         rmSetObjectDefMaxDistance(waterFlag, 50);
        rmAddObjectDefConstraint(waterFlag, flagLand);
        rmAddObjectDefConstraint(waterFlag, circleConstraint);
         rmPlaceObjectDefAtLoc(waterFlag, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i), 1);
}


	}

	rmSetStatusText("",0.6);
	/*
	==================
	resource placement
	==================
	*/

  	int islandminesID = rmCreateObjectDef("island silver");
	rmAddObjectDefItem(islandminesID, "MineCopper", 1, 1.0);
	rmSetObjectDefMinDistance(islandminesID, 0.0);
	rmSetObjectDefMaxDistance(islandminesID, rmXFractionToMeters(0.44));
	rmAddObjectDefConstraint(islandminesID, avoidCoinMed);
	//rmAddObjectDefConstraint(islandminesID, avoidTownCenterMore);
	//rmAddObjectDefConstraint(islandminesID, avoidSocket);
	rmAddObjectDefConstraint(islandminesID, avoidPlateau);	
	rmAddObjectDefConstraint(islandminesID, avoidWaterShort);
	rmAddObjectDefConstraint(islandminesID, forestConstraintShort);
	rmAddObjectDefConstraint(islandminesID, circleConstraint);
	rmPlaceObjectDefAtLoc(islandminesID, 0, 0.5, 0.5, 7*cNumberNonGaiaPlayers);
	


    int muskHunts = rmCreateObjectDef("muskHunts");
	rmAddObjectDefItem(muskHunts, "caribou", rmRandInt(5,5), 10.0);
	rmSetObjectDefCreateHerd(muskHunts, true);
	rmSetObjectDefMinDistance(muskHunts, 0);
	rmSetObjectDefMaxDistance(muskHunts, 6);
//	rmAddObjectDefConstraint(muskHunts, avoidWaterShort);	

//centre hunts
	rmPlaceObjectDefAtLoc(muskHunts, 0, 0.45, 0.7, 1);
	rmPlaceObjectDefAtLoc(muskHunts, 0, 0.55, 0.3, 1);
	rmPlaceObjectDefAtLoc(muskHunts, 0, 0.5, 0.5, 1);



    int tapirsForDays = rmCreateObjectDef("tapirsForDays");
	rmAddObjectDefItem(tapirsForDays, "moose", rmRandInt(6,6), 10.0);
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


int RuinID=rmCreateObjectDef("del fuego");
	rmAddObjectDefItem(RuinID, "NativeHouseNootka", 1, 2);
	rmSetObjectDefMinDistance(RuinID, 0);
	rmSetObjectDefMaxDistance(RuinID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(RuinID, avoidTradeRouteSmall);	
	rmAddObjectDefConstraint(RuinID, avoidWaterShort);	
	rmAddObjectDefConstraint(RuinID, avoidCoin);
	rmAddObjectDefConstraint(RuinID, avoidTownCenterMore);
	rmAddObjectDefConstraint(RuinID, forestConstraintShort);	
	rmPlaceObjectDefAtLoc(RuinID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);



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
	//rmAddObjectDefConstraint(nuggetID, avoidPlateau);
	rmAddObjectDefConstraint(nuggetID, avoidWaterShort);	
	rmAddObjectDefConstraint(nuggetID, avoidCoin);	
	rmSetNuggetDifficulty(2, 3); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 7*cNumberNonGaiaPlayers);   



	rmSetStatusText("",0.7);





	//removes loop for faster loading times
	//for (j=0; < (6*cNumberNonGaiaPlayers)) {   
		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "TreeNorthwestTerritory", rmRandInt(5,6), rmRandFloat(7.0,8.0));
		rmAddObjectDefItem(mapTrees, "TreeRedwood", rmRandInt(3,3), rmRandFloat(4.0,5.0));
		rmAddObjectDefItem(mapTrees, "RiverPropsNWTerritory", rmRandInt(1,1), rmRandFloat(4.0,5.0));
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.47));
		//rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidSocket);
	  	rmAddObjectDefConstraint(mapTrees, avoidCoin);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees, avoidNuggetSmall);	
		rmAddObjectDefConstraint(mapTrees, avoidTPSocket);
	//rmAddObjectDefConstraint(mapTrees, avoidPatch);
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 45*cNumberNonGaiaPlayers);
	//}

		rmSetStatusText("",0.8);
		//int bonusTrees=rmCreateObjectDef("bonusTrees");
		//rmAddObjectDefItem(bonusTrees, "RiverPropsNWTerritory", rmRandInt(2,3), rmRandFloat(8.0,11.0));
	  	//rmAddObjectDefConstraint(bonusTrees, circleConstraint);
		//rmAddObjectDefConstraint(bonusTrees, forestConstraint);
		//rmAddObjectDefConstraint(bonusTrees, avoidTradeRouteSmall);	
		//rmPlaceObjectDefInArea(bonusTrees, 0, continent2, 15*cNumberNonGaiaPlayers);


	rmSetStatusText("",0.9);

	//fish and their constraints placed together at the end for ease of removal
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "FishSalmon", 14.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "Beluga", 55.0);
	int rocksHateRocksID=rmCreateTypeDistanceConstraint("rocks and rocks", "ShorelineRockBigNE", 30.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 30.0);

int fishCount = 3;
if (cNumberNonGaiaPlayers > 2){
	fishCount = 1;
}

	int fishID=rmCreateObjectDef("fishies");
	rmAddObjectDefItem(fishID, "FishSalmon", fishCount, 2.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 40*cNumberNonGaiaPlayers);


	int rocksWater=rmCreateObjectDef("water rocks");
	rmAddObjectDefItem(rocksWater, "ShorelineRockBigNE", 1, 5.0);
	rmAddObjectDefItem(rocksWater, "ShorelineRockSmallNE", 1, 8.0);
	rmSetObjectDefMinDistance(rocksWater, 0.0);
	rmSetObjectDefMaxDistance(rocksWater, rmXFractionToMeters(0.4));
	rmAddObjectDefConstraint(rocksWater, rocksHateRocksID);
	rmAddObjectDefConstraint(rocksWater, fishLand);
	rmAddObjectDefConstraint(rocksWater, avoidPlateau);
	  	rmAddObjectDefConstraint(rocksWater, circleConstraint);
	rmPlaceObjectDefAtLoc(rocksWater, 0, 0.5, 0.7, 6*cNumberNonGaiaPlayers);

	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "Beluga", 1, 0.0);

	if (PlayerNum == 2)
{
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.3, 0.8, 1);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.2, 0.7, 1);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.65, 0.9, 1);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.1, 0.35, 1);


}
	if (PlayerNum >= 3)
{
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.4));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	  	rmAddObjectDefConstraint(whaleID, circleConstraint);
	  	rmAddObjectDefConstraint(whaleID, stayWest);

	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
}

		int duckBoys=rmCreateObjectDef("duckBoys");
		rmAddObjectDefItem(duckBoys, "DuckFamily", rmRandInt(1,2), rmRandFloat(3.0,5.0));
		rmAddObjectDefConstraint(duckBoys, fishLand);
		rmSetObjectDefMinDistance(duckBoys, 0);
		rmSetObjectDefMaxDistance(duckBoys, rmXFractionToMeters(0.47));
		rmPlaceObjectDefAtLoc(duckBoys, 0, 0.5, 0.5, 1.5*cNumberNonGaiaPlayers);


	rmSetStatusText("",0.99);



  // King of the Hill (added 2026-11 for WoL): the land farthest from every Town Center around Owikeno lake
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
 
