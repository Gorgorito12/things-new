include "triggers\triggerLoader.xs";

/*
======================
	Appalachians
======================
*/
//Map by dansil92

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
 
void main(void) {
    wotta_triggers();
	rmSetStatusText("",0.01);
 
//pick map size

//size is determined by the number of players across the x axis
//y axis is mostly static, varying minimally

	int sizeY = 200*cNumberNonGaiaPlayers;
	int sizeX = 400;

	if (cNumberNonGaiaPlayers == 2){
		sizeX = 275;
	}

	rmSetMapSize(sizeX, sizeY);



	rmSetMapType("land");
        rmSetMapType("snow");
        rmSetMapType("northwestTerritory");
       	rmTerrainInitialize("snow");
	

int lightingSwitcher = rmRandInt(1,3);
/*
if (lightingSwitcher == 1){
		rmSetLightingSet("3x01a_carolina");
}
if (lightingSwitcher == 2){*/
		rmSetLightingSet("st_petersburg");
/*}
if (lightingSwitcher == 3){
		rmSetLightingSet("spcjc4a");
}*/

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
		
		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 12.0);

        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.49), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 35.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 55.0);
		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 50.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 12.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "Mine", 70.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 12.0);
        int avoidWaterX = rmCreateTerrainDistanceConstraint("avoid water short 21", "Land", false, 31.0);

        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 8.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 35.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 40.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 60.0);
       
 	// Player placing  
    float spawnSwitch = rmRandFloat(0,1.2);

	int TeamNum = cNumberTeams;
	int numPlayer = cNumberPlayers;


	int PlayerNum = cNumberNonGaiaPlayers;

    


	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){

	if (PlayerNum == 2)
	{
			rmPlacePlayer(1, 0.5, 0.25);
			rmPlacePlayer(2, 0.5, 0.75);
	}
if (PlayerNum == 4)
	{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.5, 0.15, 0.5, 0.4, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.5, 0.6, 0.5, 0.85, 0, 0);
	}

			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.5, 0.1, 0.5, 0.4, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.5, 0.6, 0.5, 0.9, 0, 0);
		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
			rmPlacePlayer(2, 0.5, 0.25);
			rmPlacePlayer(1, 0.5, 0.75);
	}
if (PlayerNum == 4)
	{
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.5, 0.15, 0.5, 0.4, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.5, 0.6, 0.5, 0.85, 0, 0);
	}


			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.5, 0.1, 0.5, 0.4, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.5, 0.6, 0.5, 0.9, 0, 0);
		}
	}else{
		rmPlacePlayersLine(0.5, 0.1, 0.5, 0.9, 0, 0);
	}
		
        chooseMercs();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	   rmSetAreaMix(continent2, "rockies_snow");
//	   rmSetAreaMix(continent2, "rockies_grass");
	rmAddAreaTerrainLayer(continent2, "rockies\groundsnow6_roc", 4, 6);
	rmAddAreaTerrainLayer(continent2, "rockies\groundsnow7_roc", 5, 8);
        rmSetAreaBaseHeight(continent2, -2.0);
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




		//=============trade routes===============

		int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
        rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID, true);
        rmSetObjectDefMinDistance(socketID, 0.0);
        rmSetObjectDefMaxDistance(socketID, 6.0);      
       
        int tradeRouteID = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.7, .01);
		rmAddTradeRouteWaypoint(tradeRouteID, .7, .5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.7, .99);

        rmBuildTradeRoute(tradeRouteID, "snow");
 
        vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);

//===place a tp directly above each player tc====

for(i=1; < cNumberNonGaiaPlayers + 1) {
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
}


	 
		rmSetStatusText("",0.3);


//===========Draw Major Landforms===============


	//cliffs keep area narrower and define area
		int cliffs = rmCreateArea("NW cliffs");
		rmSetAreaSize(cliffs, 0.1, 0.11); 
		rmAddAreaToClass(cliffs, rmClassID("classPlateau"));
		rmSetAreaCliffType(cliffs, "New England snow");
//	rmSetAreaTerrainType(cliffs, "carolinas\blackmap");      
		rmSetAreaCliffEdge(cliffs, 1, 1.0, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(cliffs, false, true, true, 0.4, true);
		rmSetAreaCliffHeight(cliffs, 4, 0.1, 0.5);
		//rmAddAreaConstraint(cliffs, avoidCenter);
		rmSetAreaCoherence(cliffs, .97);
		rmSetAreaLocation(cliffs, .97, .5);	
        rmAddAreaInfluenceSegment(cliffs, 0.95, 0.01, 0.99, 0.95);
		rmBuildArea(cliffs);


//laugh at wall lamers
				
		int iceWall =rmCreateArea("icy patch");
        rmSetAreaLocation(iceWall, 0.04, 0.5);
        rmAddAreaInfluenceSegment(iceWall, 0.1, 0.0, 0.1, 1.0);
	rmSetAreaTerrainType(iceWall, "great_lakes\ground_ice1_gl");      
        rmSetAreaSmoothDistance(iceWall, 10);
        rmSetAreaHeightBlend(iceWall, 1);
        rmSetAreaSize(iceWall, .29, .31);      
        rmSetAreaBaseHeight(iceWall, -3.0);
        rmSetAreaCoherence(iceWall, .92);
        rmBuildArea(iceWall);



//water spawn to SE				
		int atlanticOcean=rmCreateArea("atlanticOcean");
        rmSetAreaLocation(atlanticOcean, 0.04, 0.5);
        rmAddAreaInfluenceSegment(atlanticOcean, 0.1, 0.0, 0.1, 1.0);
        rmSetAreaSize(atlanticOcean, .21, .22);      
        rmSetAreaWaterType(atlanticOcean, "great lakes ice");
        rmSetAreaBaseHeight(atlanticOcean, 0.0);
        rmSetAreaCoherence(atlanticOcean, .92);
        rmBuildArea(atlanticOcean);

		
		rmSetStatusText("",0.4);

//=========cliffs to northeast and southwest of each player=====



//first draw an area around tc to mark player areas

for(i=1; < cNumberNonGaiaPlayers + 1) {
		int center = rmCreateArea("center"+i);
		rmAddAreaToClass(center, rmClassID("center"));
        rmSetAreaSize(center, rmAreaTilesToFraction(5600), rmAreaTilesToFraction(5600));
        rmSetAreaLocation(center, 0.4, rmPlayerLocZFraction(i));
        rmAddAreaInfluenceSegment(center, 0.2, rmPlayerLocZFraction(i), 0.75, rmPlayerLocZFraction(i));
        rmSetAreaCoherence(center, 0.85);
        rmBuildArea(center);   
}

//draw cliffs to SW of each tc that avoid player area

for(i=1; < cNumberNonGaiaPlayers + 1) {
		int playerCliffSW = rmCreateArea("playerCliffSW"+i);
		rmSetAreaSize(playerCliffSW, rmAreaTilesToFraction(2600), rmAreaTilesToFraction(2600)); 
		rmAddAreaToClass(playerCliffSW, rmClassID("classPlateau"));
		rmSetAreaCliffType(playerCliffSW, "Rocky Mountain Edge");
		rmSetAreaCliffEdge(playerCliffSW, 1, 1.0, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(playerCliffSW, false, true, true, 0.4, true);
		rmSetAreaCliffHeight(playerCliffSW, 5, 0.1, 0.5);
		rmAddAreaConstraint(playerCliffSW, avoidCenter);
		rmAddAreaConstraint(playerCliffSW, avoidWaterX);
		rmAddAreaConstraint(playerCliffSW, avoidPlateau);
	rmAddAreaConstraint(playerCliffSW, avoidTradeRouteSmall);
	rmAddAreaConstraint(playerCliffSW, avoidSocket); 
		rmSetAreaCoherence(playerCliffSW, .85);
rmSetAreaLocation(playerCliffSW, 0.5, rmPlayerLocZFraction(i)-rmZTilesToFraction(50));	
		rmBuildArea(playerCliffSW);
}


//draw cliffs to NE of each tc that avoid player area

for(i=1; < cNumberNonGaiaPlayers + 1) {
		int playerCliffNE = rmCreateArea("playerCliffNE"+i);
		rmSetAreaSize(playerCliffNE, rmAreaTilesToFraction(2600), rmAreaTilesToFraction(2600)); 
		rmAddAreaToClass(playerCliffNE, rmClassID("classPlateau"));
		rmSetAreaCliffType(playerCliffNE, "Rocky Mountain Edge");
		rmSetAreaCliffEdge(playerCliffNE, 1, 1.0, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(playerCliffNE, false, true, true, 0.4, true);
		rmSetAreaCliffHeight(playerCliffNE, 5, 0.1, 0.5);
		rmAddAreaConstraint(playerCliffNE, avoidCenter);
		rmAddAreaConstraint(playerCliffNE, avoidWaterX);
		rmAddAreaConstraint(playerCliffSW, avoidPlateau);
	rmAddAreaConstraint(playerCliffNE, avoidTradeRouteSmall);
	rmAddAreaConstraint(playerCliffNE, avoidSocket); 
		rmSetAreaCoherence(playerCliffNE, .85);
		rmSetAreaLocation(playerCliffNE, 0.5, rmPlayerLocZFraction(i)+rmZTilesToFraction(50));	
		rmBuildArea(playerCliffNE);
}



		//starting objects
		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
        rmAddObjectDefConstraint(playerStart, avoidPlateau);	

       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "minegold", 1, 8.0);
        rmSetObjectDefMinDistance(goldID, 12.0);
        rmSetObjectDefMaxDistance(goldID, 12.0);
        rmAddObjectDefConstraint(goldID, avoidPlateau);	
       
        int goldID2 = rmCreateObjectDef("starting gold 2");
        rmAddObjectDefItem(goldID2, "mine", 1, 16.0);
        rmSetObjectDefMinDistance(goldID2, 12.0);
        rmSetObjectDefMaxDistance(goldID2, 12.0);
        rmAddObjectDefConstraint(goldID2, avoidCoin);
        rmAddObjectDefConstraint(goldID2, avoidPlateau);	

 
        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "BerryBush", 2, 6.0);
        rmSetObjectDefMinDistance(berryID, 8.0);
        rmSetObjectDefMaxDistance(berryID, 12.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "ypTreeHimalayas", rmRandInt(5,6), 7.0);
        rmSetObjectDefMinDistance(treeID, 15.0);
        rmSetObjectDefMaxDistance(treeID, 18.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "elk", 6, 8.0);
        rmSetObjectDefMinDistance(foodID, 10.0);
        rmSetObjectDefMaxDistance(foodID, 10.0);
        rmSetObjectDefCreateHerd(foodID, true);
        rmAddObjectDefConstraint(foodID, avoidPlateau);	

 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "elk", 7, 8.0);
        rmSetObjectDefMinDistance(foodID2, 28.0);
        rmSetObjectDefMaxDistance(foodID2, 29.0);
        rmSetObjectDefCreateHerd(foodID2, true);
        rmAddObjectDefConstraint(foodID2, avoidPlateau);
                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "Moose", 8, 8.0);
        rmSetObjectDefMinDistance(foodID3, 45.0);
        rmSetObjectDefMaxDistance(foodID3, 45.0);
        rmSetObjectDefCreateHerd(foodID3, true);
        rmAddObjectDefConstraint(foodID3, avoidPlateau);
        
		int FoxID = rmCreateObjectDef("starting fox");
        rmAddObjectDefItem(FoxID, "Fox", 5, 8.0);
        rmSetObjectDefMinDistance(FoxID, 45.0);
        rmSetObjectDefMaxDistance(FoxID, 45.0);
        rmSetObjectDefCreateHerd(FoxID, true);
        rmAddObjectDefConstraint(FoxID, avoidPlateau);	

	int extraberrywagon=rmCreateObjectDef("jApaN cAnT hUnT");
  rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
  rmSetObjectDefMinDistance(extraberrywagon, 10.0);
  rmSetObjectDefMaxDistance(extraberrywagon, 10.0);



		rmSetStatusText("",0.5);      
    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 3.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 10.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
 //       rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        //rmPlaceObjectDefAtLoc(goldID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(FoxID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		int waterFlag = rmCreateObjectDef("HC water flag "+i);
         rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 0.0);
         rmSetObjectDefMinDistance(waterFlag, 1);
         rmSetObjectDefMaxDistance(waterFlag, 8);
         rmPlaceObjectDefAtLoc(waterFlag, i, 0.1, rmPlayerLocZFraction(i), 1);

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
	

int avoidIce = rmCreateAreaDistanceConstraint("Avoid Ice", iceWall, 14);




    int pronghornHunts = rmCreateObjectDef("pronghornHunts");
	rmAddObjectDefItem(pronghornHunts, "Moose", rmRandInt(7,8), 14.0);
	rmSetObjectDefCreateHerd(pronghornHunts, true);
	rmSetObjectDefMinDistance(pronghornHunts, 0);
	rmSetObjectDefMaxDistance(pronghornHunts, rmZFractionToMeters(0.44));
	rmAddObjectDefConstraint(pronghornHunts, avoidTownCenterMore);
	rmAddObjectDefConstraint(pronghornHunts, avoidHunt);
	rmAddObjectDefConstraint(pronghornHunts, avoidPlateau);
	rmAddObjectDefConstraint(pronghornHunts, avoidWaterShort);	
	rmPlaceObjectDefAtLoc(pronghornHunts, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);

  	int islandminesID = rmCreateObjectDef("island silver");
	rmAddObjectDefItem(islandminesID, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(islandminesID, 0.0);
	rmSetObjectDefMaxDistance(islandminesID, rmZFractionToMeters(0.46));
	rmAddObjectDefConstraint(islandminesID, avoidCoinMed);
	rmAddObjectDefConstraint(islandminesID, avoidTownCenterMore);
	rmAddObjectDefConstraint(islandminesID, avoidSocket);
	rmAddObjectDefConstraint(islandminesID, avoidPlateau);	
	rmAddObjectDefConstraint(islandminesID, avoidWaterShort);
	rmAddObjectDefConstraint(islandminesID, forestConstraintShort);
//	rmAddObjectDefConstraint(islandminesID, circleConstraint);
	rmPlaceObjectDefAtLoc(islandminesID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);
 
	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
	rmSetObjectDefMinDistance(nuggetID, 0.0); 
	rmSetObjectDefMaxDistance(nuggetID, rmZFractionToMeters(0.45)); 
	rmAddObjectDefConstraint(nuggetID, avoidNugget); 
//	rmAddObjectDefConstraint(nuggetID, circleConstraint);
	rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetID, forestConstraintShort);
	rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(nuggetID, avoidSocket); 
	rmAddObjectDefConstraint(nuggetID, avoidPlateau);	
	rmAddObjectDefConstraint(nuggetID, avoidWaterShort);
	rmSetNuggetDifficulty(1, 2); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);   
	rmSetStatusText("",0.7);

		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "ypTreeHimalayas", rmRandInt(12,15), rmRandFloat(14.0,20.0));
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmZFractionToMeters(0.45));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidSocket);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees, avoidIce);	
//		rmAddObjectDefConstraint(mapTrees, avoidWaterShort);	
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 25*cNumberNonGaiaPlayers);



		rmSetStatusText("",0.8);
	//fish and their constraints placed together at the end for ease of removal
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "FishMahi", 16.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 60.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 26.0);

	int fishID=rmCreateObjectDef("fish Mahi");
	rmAddObjectDefItem(fishID, "FishSalmon", 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmZFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 7*cNumberNonGaiaPlayers);



	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, 5);
//===place a whale directly below each player tc====

for(i=1; < cNumberNonGaiaPlayers + 1) {
        rmPlaceObjectDefAtLoc(whaleID, 0, 0.01, rmPlayerLocZFraction(i));
}
	if (cNumberNonGaiaPlayers == 2){
        rmPlaceObjectDefAtLoc(whaleID, 0, 0.1, 0.5);
}


	rmSetStatusText("",0.9);

  // King of the Hill (added 2026-11 for WoL): middle of the land strip, between the two sides
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
    // (0.025 of the map side per step), with the include's placer constraints, 40 m from every Town Center
    // and 10 m from every tree
    int kothAvoidLand = rmCreateTerrainDistanceConstraint("koth hill avoids impassable land", "Land", false, 6.0);
    int kothAvoidAll = rmCreateTypeDistanceConstraint("koth hill avoids all", "all", 4.0);
    int kothAvoidTC = rmCreateTypeDistanceConstraint("koth hill avoids TCs", "TownCenter", 40.0);
    int kothAvoidTrees = rmCreateTypeDistanceConstraint("koth hill avoids trees", "Tree", 10.0);
    int kothAvoidTreesNear = rmCreateTypeDistanceConstraint("koth hill avoids trees near", "Tree", 5.0);
    int kothAvoidSocket = rmCreateTypeDistanceConstraint("koth hill avoids trade sockets", "socketTradeRoute", 6.0);
    int kothAvoidRoute = rmCreateTradeRouteDistanceConstraint("koth hill avoids trade route", 6.0);
    int kothAvoidClass0 = rmCreateClassDistanceConstraint("koth hill avoids classPlateau", rmClassID("classPlateau"), 20.0);
    int kothAvoidFlag = rmCreateTypeDistanceConstraint("koth hill avoids water flags", "HomeCityWaterSpawnFlag", 4.0);
    int kothDone = 0;
    float kothDist = 0.0;
    for (kothRound = 0; < 41) {
      int kothHill = rmCreateObjectDef("koth hill " + kothRound);
      rmAddObjectDefItem(kothHill, "ypKingsHill", 1, 0);
      rmSetObjectDefMinDistance(kothHill, 0.0);
      rmSetObjectDefMaxDistance(kothHill, rmXFractionToMeters(0.025));
      rmAddObjectDefConstraint(kothHill, kothAvoidLand);
      rmAddObjectDefConstraint(kothHill, kothAvoidAll);
      rmAddObjectDefConstraint(kothHill, kothAvoidTC);
      rmAddObjectDefConstraint(kothHill, kothAvoidTrees);
      rmAddObjectDefConstraint(kothHill, kothAvoidSocket);
      rmAddObjectDefConstraint(kothHill, kothAvoidRoute);
      rmAddObjectDefConstraint(kothHill, kothAvoidFlag);
      rmAddObjectDefConstraint(kothHill, kothAvoidClass0);
      rmPlaceObjectDefAtLoc(kothHill, 0, kothX + kothDirX * kothDist, kothZ + kothDirZ * kothDist, 1);
      if (rmGetNumberUnitsPlaced(kothHill) > 0) {
        kothDone = 1;
        break;
      }
      // 0, +1, -1, +2, -2, ... steps
      if (kothDist > 0.0)
        kothDist = 0.0 - kothDist;
      else
        kothDist = 0.025 - kothDist;
    }
    // no room on that line: the open land nearest to the middle, trees allowed closer (5 m)
    if (kothDone == 0) {
      float kothRadius = 0.04;
      for (kothNear = 0; < 8) {
        int kothHillNear = rmCreateObjectDef("koth hill near " + kothNear);
        rmAddObjectDefItem(kothHillNear, "ypKingsHill", 1, 0);
        rmSetObjectDefMinDistance(kothHillNear, 0.0);
        rmSetObjectDefMaxDistance(kothHillNear, rmXFractionToMeters(kothRadius));
        rmAddObjectDefConstraint(kothHillNear, kothAvoidLand);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidAll);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidTC);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidTreesNear);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidSocket);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidRoute);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidFlag);
        rmAddObjectDefConstraint(kothHillNear, kothAvoidClass0);
        rmPlaceObjectDefAtLoc(kothHillNear, 0, kothX, kothZ, 1);
        if (rmGetNumberUnitsPlaced(kothHillNear) > 0)
          break;
        kothRadius = kothRadius * 1.5;
      }
    }
  }

	}
 
