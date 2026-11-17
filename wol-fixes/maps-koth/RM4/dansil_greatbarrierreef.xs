include "triggers\triggerLoader.xs";

/*
===========================
	Great Barrier Reef
       Map by dansil92
===========================
*/

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
 
void main(void) {
    wotta_triggers();
	rmSetStatusText("",0.01);
 
//pick map size

//size is determined by the number of players across the x axis
//y axis is mostly static, varying minimally

	int sizeY = 250+100*cNumberNonGaiaPlayers;
	int sizeX = 450;

	if (cNumberNonGaiaPlayers == 2){
		sizeX = 275;
	}

	rmSetMapSize(sizeX, sizeY);



	rmSetMapType("land");
        rmSetMapType("snow");
        rmSetMapType("northwestTerritory");
	rmSetSeaLevel(-3.0);
		rmSetSeaType("ceylon coast");

       	rmTerrainInitialize("water");
	

		rmSetLightingSet("301a_Malta");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
		
		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 12.0);

        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.49), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 9.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 55.0);
		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 50.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 12.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "SPCSpanishShipRuins", 60.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 12.0);
        int avoidWaterX = rmCreateTerrainDistanceConstraint("avoid water short 21", "Land", false, 31.0);

        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 8.0);
        int avoidSocket=rmCreateTypeDistanceConstraint("socket avoidance", "SocketTradeRoute", 25.0);
        
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
			rmPlacePlayer(1, 0.7, 0.25);
			rmPlacePlayer(2, 0.7, 0.75);
	}
if (PlayerNum == 4)
	{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.7, 0.15, 0.7, 0.3, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.7, 0.7, 0.7, 0.85, 0, 0);
	}

			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.7, 0.1, 0.7, 0.3, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.7, 0.7, 0.7, 0.9, 0, 0);
		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
			rmPlacePlayer(2, 0.7, 0.25);
			rmPlacePlayer(1, 0.7, 0.75);
	}
if (PlayerNum == 4)
	{
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.7, 0.15, 0.7, 0.3, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.7, 0.7, 0.7, 0.85, 0, 0);
	}


			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.7, 0.1, 0.7, 0.3, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.7, 0.7, 0.7, 0.9, 0, 0);
		}
	}else{
		rmPlacePlayersLine(0.7, 0.1, 0.7, 0.9, 0, 0);
	}
		
        chooseMercs();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 0.6, 0.6);
        rmSetAreaLocation(continent2, 0.3, 0.3);
        rmSetAreaBaseHeight(continent2, -4.0);
        rmSetAreaCoherence(continent2, 0.7);
        rmSetAreaSmoothDistance(continent2, 10);
        rmSetAreaHeightBlend(continent2, 1);
        rmSetAreaElevationNoiseBias(continent2, 0);
        rmSetAreaElevationEdgeFalloffDist(continent2, 10);
        rmSetAreaElevationVariation(continent2, 2);
        rmSetAreaElevationPersistence(continent2, .2);
        rmSetAreaElevationOctaves(continent2, 5);
        rmSetAreaElevationMinFrequency(continent2, 0.045);
        rmAddAreaInfluenceSegment(continent2, 0.3, 0.9, 0.3, 0.1);

        rmSetAreaElevationType(continent2, cElevTurbulence);  
        rmBuildArea(continent2);    

		int classPatch = rmDefineClass("patch");
		int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 22.0);
		int classCenter = rmDefineClass("center");
		int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 3.0);
		int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
        


		rmSetStatusText("",0.2);




   int watersocketID=rmCreateObjectDef("sockets to dock Water Posts");
	rmAddObjectDefItem(watersocketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(watersocketID, true);
	rmSetObjectDefMinDistance(watersocketID, 0.0);
	rmSetObjectDefMaxDistance(watersocketID, 10.0);

	int watertradeRouteID = rmCreateTradeRoute();

	rmSetObjectDefTradeRouteID(watersocketID, watertradeRouteID);

		rmAddTradeRouteWaypoint(watertradeRouteID, 0.85, .01);
		rmAddTradeRouteWaypoint(watertradeRouteID, .85, .5);
		rmAddTradeRouteWaypoint(watertradeRouteID, 0.85, .99);

	rmBuildTradeRoute(watertradeRouteID, "WATERdirt");




		rmSetStatusText("",0.3);


//===========Draw Major Landforms===============


	//cliffs keep area narrower and define area
		int cliffs = rmCreateArea("NW cliffs");
		rmSetAreaSize(cliffs, 0.1, 0.11); 
		rmAddAreaToClass(cliffs, rmClassID("classPlateau"));
	//	rmSetAreaCliffType(cliffs, "New England snow");
//	rmSetAreaTerrainType(cliffs, "carolinas\blackmap");      
		rmSetAreaCliffEdge(cliffs, 1, 1.0, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(cliffs, false, true, true, 0.4, true);
		rmSetAreaCliffHeight(cliffs, 4, 0.1, 0.5);
		//rmAddAreaConstraint(cliffs, avoidCenter);
		rmSetAreaCoherence(cliffs, .97);
		rmSetAreaLocation(cliffs, .97, .5);	
        rmAddAreaInfluenceSegment(cliffs, 0.95, 0.01, 0.99, 0.95);
	//	rmBuildArea(cliffs);


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
    //    rmBuildArea(iceWall);


		int classMountain = rmDefineClass("mountain");

		int avoidMountain = rmCreateClassDistanceConstraint("avoid mountains", rmClassID("mountain"), 45.0);




//water spawn to NE				
		int atlanticOcean=rmCreateArea("continental shelf");
        rmSetAreaLocation(atlanticOcean, 0.9, 0.5);
        rmAddAreaInfluenceSegment(atlanticOcean, 0.9, 0.0, 0.9, 1.0);
		rmAddAreaToClass(atlanticOcean, rmClassID("classPlateau"));

        rmSetAreaSize(atlanticOcean, .35, .35); 
        rmSetAreaSmoothDistance(atlanticOcean, 25);
        rmSetAreaHeightBlend(atlanticOcean, 2);
             rmSetAreaWaterType(atlanticOcean, "ceylon coast");
        rmSetAreaBaseHeight(atlanticOcean, -55.0);
        rmSetAreaCoherence(atlanticOcean, .6);
        rmBuildArea(atlanticOcean);

	for (j=0; < (10*cNumberNonGaiaPlayers)) {   
			int ffaCliffs = rmCreateArea("ffaCliffs"+j);
        rmSetAreaSize(ffaCliffs, rmAreaTilesToFraction(80), rmAreaTilesToFraction(200));
//		rmAddAreaToClass(ffaCliffs, rmClassID("classPlateau"));
		rmAddAreaToClass(ffaCliffs, rmClassID("mountain"));
		rmSetAreaTerrainType(ffaCliffs, "Ceylon\seafloor5_ceylon");      
        rmSetAreaBaseHeight(ffaCliffs, rmRandInt(-2.0, -1.0));
        rmSetAreaSmoothDistance(ffaCliffs, 5);
        rmSetAreaHeightBlend(ffaCliffs, 1);

	rmSetAreaMinBlobs(ffaCliffs, 2);
	rmSetAreaMaxBlobs(ffaCliffs, 11);
	rmSetAreaMinBlobDistance(ffaCliffs, 4);
	rmSetAreaMaxBlobDistance(ffaCliffs, 20);

	rmAddAreaConstraint(ffaCliffs, avoidPlateau);
	rmAddAreaConstraint(ffaCliffs, avoidMountain);
	//rmAddAreaConstraint(ffaCliffs, circleConstraint2);
	//rmAddAreaConstraint(ffaCliffs, avoidTownCenterMore);
        rmSetAreaCoherence(ffaCliffs, .96);

        rmBuildArea(ffaCliffs);  
	}

		
	int stayWater = rmCreateTerrainDistanceConstraint("islands stay in water", "land", true, 18.0);

	int islandCount = 3;

	for (j=0; < islandCount) {   
			int smallIslands = rmCreateArea("smallIslands"+j);
        rmSetAreaSize(smallIslands, rmAreaTilesToFraction(290), rmAreaTilesToFraction(290));
		rmAddAreaToClass(smallIslands, rmClassID("classPlateau"));
		rmAddAreaToClass(smallIslands, rmClassID("center"));
		rmSetAreaCliffType(smallIslands, "Ceylon");
		rmSetAreaCliffEdge(smallIslands, 1, 1, 0.0, 0.0, 2);	
	rmSetAreaCliffPainting(smallIslands, true, true, true, 1.5, true);
		rmSetAreaCliffHeight(smallIslands, 4.3, 1, 0.5);
        rmSetAreaSmoothDistance(smallIslands, 1);
        rmSetAreaHeightBlend(smallIslands, 1);
        rmSetAreaCoherence(smallIslands, 0.85);
//	rmAddAreaConstraint(smallIslands, avoidCenter);
	rmAddAreaConstraint(smallIslands, avoidTradeRouteSmall);
//	rmAddAreaConstraint(smallIslands, circleConstraint2);

if (j == 0){
	rmSetAreaLocation(smallIslands, 0.77, .8);
}
if (j == 1){
	rmSetAreaLocation(smallIslands, 0.77, .5);
}
if (j == 2){
	rmSetAreaLocation(smallIslands, 0.77, .2);
}


        rmBuildArea(smallIslands);  
	}


	 		rmPlaceObjectDefAtLoc(watersocketID, 0, 0.78, 0.8); 
	 		rmPlaceObjectDefAtLoc(watersocketID, 0, 0.78, 0.5); 
	 		rmPlaceObjectDefAtLoc(watersocketID, 0, 0.78, 0.2); 


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
 //       rmBuildArea(center);   
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
	//	rmBuildArea(playerCliffSW);
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
	//	rmBuildArea(playerCliffNE);
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


/*     
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
         rmPlaceObjectDefAtLoc(waterFlag, i, 0.9, rmPlayerLocZFraction(i), 1);

if (rmGetPlayerCiv(i) == rmGetCivID("Japanese")) {
        rmPlaceObjectDefAtLoc(extraberrywagon, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
}

	}

*/

   int colonyShipID=rmCreateObjectDef("colony ship");
   rmAddObjectDefItem(colonyShipID, "FishingBoat", 1, 0.0);
   rmSetObjectDefGarrisonStartingUnits(colonyShipID, true);
   rmSetObjectDefMinDistance(colonyShipID, 0.0);
   rmSetObjectDefMaxDistance(colonyShipID, 20.0);

    for(i=1; < cNumberNonGaiaPlayers + 1) {

        rmPlaceObjectDefAtLoc(colonyShipID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));


	rmAddPlayerResource(i, "wood", 600);
	rmAddPlayerResource(i, "XP", 80);


		int waterFlag = rmCreateObjectDef("HC water flag "+i);
         rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 0.0);
         rmAddObjectDefItem(waterFlag, "FishingBoat", 5, 10.0);

         rmSetObjectDefMinDistance(waterFlag, 1);
         rmSetObjectDefMaxDistance(waterFlag, 8);
         rmPlaceObjectDefAtLoc(waterFlag, i, 0.9, rmPlayerLocZFraction(i), 1);
}
	rmSetStatusText("",0.6);
	/*
	==================
	resource placement
	==================
	*/
	

int avoidIce = rmCreateAreaDistanceConstraint("Avoid Ice", iceWall, 14);




    int pronghornHunts = rmCreateObjectDef("pronghornHunts");
	rmAddObjectDefItem(pronghornHunts, "Crab", rmRandInt(7,8), 14.0);
	rmAddObjectDefItem(pronghornHunts, "Coconut", rmRandInt(1,1), 8.0);

	rmSetObjectDefCreateHerd(pronghornHunts, true);
	rmSetObjectDefMinDistance(pronghornHunts, 0);
	rmSetObjectDefMaxDistance(pronghornHunts, rmZFractionToMeters(0.44));
	rmAddObjectDefConstraint(pronghornHunts, avoidTownCenterMore);
	rmAddObjectDefConstraint(pronghornHunts, avoidHunt);
	rmAddObjectDefConstraint(pronghornHunts, avoidPlateau);
	//rmAddObjectDefConstraint(pronghornHunts, avoidWaterShort);	
	rmPlaceObjectDefAtLoc(pronghornHunts, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);

  	int islandminesID = rmCreateObjectDef("island silver");
	rmAddObjectDefItem(islandminesID, "SPCSpanishShipRuins", 1, 1.0);
//		rmAddObjectDefItem(islandminesID, "CrateofWood", rmRandInt(3,3), rmRandFloat(6.0,7.0));
	rmSetObjectDefMinDistance(islandminesID, 0.0);
	rmSetObjectDefMaxDistance(islandminesID, rmZFractionToMeters(0.46));
	rmAddObjectDefConstraint(islandminesID, avoidCoinMed);
	rmAddObjectDefConstraint(islandminesID, avoidTownCenterMore);
//	rmAddObjectDefConstraint(islandminesID, avoidSocket);
	//rmAddObjectDefConstraint(islandminesID, avoidPlateau);	
	//rmAddObjectDefConstraint(islandminesID, avoidWaterShort);
	//rmAddObjectDefConstraint(islandminesID, forestConstraintShort);
//	rmAddObjectDefConstraint(islandminesID, circleConstraint);
	rmPlaceObjectDefAtLoc(islandminesID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);
 
	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "FishReefShark", 1, 0.0); 
	rmSetObjectDefMinDistance(nuggetID, 0.0); 
	rmSetObjectDefMaxDistance(nuggetID, rmZFractionToMeters(0.45)); 
	//rmAddObjectDefConstraint(nuggetID, avoidNugget); 
//	rmAddObjectDefConstraint(nuggetID, circleConstraint);
	rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
//	rmAddObjectDefConstraint(nuggetID, forestConstraintShort);
//	rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(nuggetID, avoidSocket); 
	rmAddObjectDefConstraint(nuggetID, avoidPlateau);	
	//rmAddObjectDefConstraint(nuggetID, avoidWaterShort);
	//rmSetNuggetDifficulty(1, 2); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);   
	rmSetStatusText("",0.7);

		int mapTrees=rmCreateObjectDef("map trees");
		
	rmAddObjectDefItem(mapTrees, "CrateofWood", rmRandInt(5,6), rmRandFloat(10.0,14.0));

	rmAddObjectDefItem(mapTrees, "ypPropsCargoDebris", rmRandInt(5,8), rmRandFloat(10.0,14.0));
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.77, 0.2, 1);
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.77, 0.8, 1);

		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmZFractionToMeters(0.45));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidSocket);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees, avoidIce);	
//		rmAddObjectDefConstraint(mapTrees, avoidWaterShort);	
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 25*cNumberNonGaiaPlayers);


		int bonusTrees=rmCreateObjectDef("bonusTrees");
		rmAddObjectDefItem(bonusTrees, "TreeFale", rmRandInt(3,3), rmRandFloat(8.0,11.0));
		rmAddObjectDefToClass(bonusTrees, rmClassID("classForest")); 
	  	rmAddObjectDefConstraint(bonusTrees, avoidSocket);
		rmAddObjectDefConstraint(bonusTrees, forestConstraintShort);
		rmAddObjectDefConstraint(bonusTrees, avoidTradeRouteSmall);	
	rmPlaceObjectDefInArea(bonusTrees, 0, continent2, 15*cNumberNonGaiaPlayers);


		rmSetStatusText("",0.8);
	//fish and their constraints placed together at the end for ease of removal
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "FishParrotfish", 14.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 80.0);
	int rocksHateRocksID=rmCreateTypeDistanceConstraint("rocks and rocks", "ShorelineRockSmallNE", 30.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 22.0);

int fishCount = 3;
if (cNumberNonGaiaPlayers > 2){
	fishCount = 1;
}

	int fishID=rmCreateObjectDef("fishies");
	rmAddObjectDefItem(fishID, "FishParrotfish", fishCount, 2.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.9));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 40*cNumberNonGaiaPlayers);


	int rocksWater=rmCreateObjectDef("water rocks");
	rmAddObjectDefItem(rocksWater, "ShorelineRockSmallNE", 3, 8.0);
	rmSetObjectDefMinDistance(rocksWater, 0.0);
	rmSetObjectDefMaxDistance(rocksWater, rmXFractionToMeters(0.4));
	rmAddObjectDefConstraint(rocksWater, rocksHateRocksID);
	rmAddObjectDefConstraint(rocksWater, fishLand);
	rmAddObjectDefConstraint(rocksWater, avoidPlateau);
	  	rmAddObjectDefConstraint(rocksWater, circleConstraint);
	//rmPlaceObjectDefAtLoc(rocksWater, 0, 0.5, 0.7, 6*cNumberNonGaiaPlayers);


	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "MinkeWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, 5);
//===place a whale directly below each player tc====

for(i=1; < cNumberNonGaiaPlayers + 1) {
        rmPlaceObjectDefAtLoc(whaleID, 0, 0.93, rmPlayerLocZFraction(i));
}
	if (cNumberNonGaiaPlayers == 2){
        rmPlaceObjectDefAtLoc(whaleID, 0, 0.92, 0.5);
}


	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);

	rmPlaceObjectDefInArea(whaleID, 0, continent2, 4*cNumberNonGaiaPlayers);

	rmSetStatusText("",0.9);

  // King of the Hill (added 2026-11 for WoL): the mainland farthest from every Town Center, between the two sides
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
 
