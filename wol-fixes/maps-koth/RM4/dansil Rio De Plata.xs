include "triggers\triggerLoader.xs";

/*
==============================
	Rio de la Plata
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
		playerTiles = 9000;
	}
	
	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmSetMapSize(size, size*1.2);

	rmSetMapType("land");
        rmSetMapType("grass");
        rmSetMapType("pampas");
       	rmTerrainInitialize("grass");

rmSetLightingSet("306a_caribbean");
//rmSetLightingSet("patagonia");

        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
	rmSetSeaLevel(2.0);
		rmSetSeaType("yucatan Coast");


		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 6.0);

        int circleConstraint= rmCreateBoxConstraint("stay in useable portion", 0.02, 0.01, 0.98, 0.95);

       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 24.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 12.0);
        
		int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 50.0);

		int avoidHunt2=rmCreateTypeDistanceConstraint("hunts avoid hunts2", "huntable", 20.0);

		int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

        int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 87.0);

		int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 10.0);
        int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "Mine", 60.0);
        int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 9.0);
        int cliffWater = rmCreateTerrainDistanceConstraint("cliff avoids river", "Land", false, 0.01);
        int cliffWater2 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 1.5);
        int cliffWater3 = rmCreateTerrainDistanceConstraint("cliff avoids river 2", "Land", false, 2.5);


        int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 6.0);
        int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
		int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 26.0);
        int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
        int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 35.0);  
       
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 60.0);

int stayWest = rmCreatePieConstraint("Stay West",0.47,0.53, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(225),rmDegreesToRadians(45));
int stayEast = rmCreatePieConstraint("Stay East",0.53,0.47, rmXFractionToMeters(0.2),rmXFractionToMeters(0.5), rmDegreesToRadians(45),rmDegreesToRadians(225));

   

	int PlayerNum = cNumberNonGaiaPlayers;

    
 // =============Player placement ======================= 
    float spawnSwitch = rmRandFloat(0,1.2);
	spawnSwitch = 0.1;

	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){

	if (PlayerNum == 2)
	{
	rmPlacePlayer(1, 0.15, 0.5);
	rmPlacePlayer(2, 0.85, 0.5);	}

	if (PlayerNum == 4)
	{			
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.15, 0.4, 0.15, 0.55, 0, 0);
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.85, 0.4, 0.85, 0.55, 0, 0);

	}


			rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.15, 0.3, 0.15, 0.58, 0, 0);
			rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.85, 0.3, 0.85, 0.58, 0, 0);

		}else if(spawnSwitch <=1.2){

	if (PlayerNum == 2)
	{
		rmPlacePlayer(2, 0.15, 0.5);
		rmPlacePlayer(1, 0.85, 0.5);
	}

			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.8, 0.99);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.25, 0.46);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);

		}
	}else{
	//*************ffa placement********
		rmSetPlacementSection(0.7, 0.3);
		rmPlacePlayersCircular(0.35, 0.35, 0.02);
	}

		
        chooseMercs();
        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	   rmSetAreaMix(continent2, "patagonia_grass");
        rmSetAreaBaseHeight(continent2, 2.0);
        rmSetAreaCoherence(continent2, 1.0);
        rmSetAreaSmoothDistance(continent2, 5);
		rmSetAreaEdgeFilling(continent2, 1.0);
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
			rmSetAreaSize(patchID, rmAreaTilesToFraction(36), rmAreaTilesToFraction(39));
        rmSetAreaTerrainType(patchID, "patagonia\groundforest_pat");
	//		rmAddAreaToClass(patchID, rmClassID("patch"));
	//		rmSetAreaSmoothDistance(patchID, 1.0);
			rmBuildArea(patchID); 
		}

	


		rmSetStatusText("",0.2);





 
		rmSetStatusText("",0.3);
				
//===================River=====================

	int TeamNum = cNumberTeams;
	int numPlayer = cNumberPlayers;
	string riverType = "saguenay lake";


	int riverID = rmRiverCreate(-5, riverType, 8, 8, 15+numPlayer/2, 10+numPlayer/2); 

	rmRiverSetBankNoiseParams(riverID, 0.07, 1, 0.5, 6.0, 0.667, 1.0);


  rmRiverAddWaypoint(riverID, 0.5, 1.2);
  rmRiverAddWaypoint(riverID, 0.5, .8);
  rmRiverAddWaypoint(riverID, 0.5, .6);
  rmRiverAddWaypoint(riverID, 0.5, .5);

	rmRiverSetShallowRadius(riverID, size);
		rmRiverAddShallow(riverID, 0.2);

	rmRiverBuild(riverID);
	//rmRiverReveal(riverID, 2);

//====================================================

//============river inner cliff=======================

        int cliffNE = rmCreateArea("cliffNE");
        rmSetAreaSize(cliffNE, 0.4, 0.4);
        rmSetAreaLocation(cliffNE, 0.6, 0.6);		rmAddAreaToClass(cliffNE, rmClassID("classPlateau"));
        rmSetAreaBaseHeight(cliffNE, 0.0);
        rmSetAreaCoherence(cliffNE, 1.0);
        rmSetAreaHeightBlend(cliffNE, 1);
		rmAddAreaConstraint(cliffNE, cliffWater);
		rmSetAreaCliffType(cliffNE, "Pampas River");
		rmSetAreaCliffEdge(cliffNE, 1, 1, 0.0, 0.0, 2); 
		rmSetAreaCliffPainting(cliffNE, true, true, false, 1.5, true);
		rmSetAreaCliffHeight(cliffNE, 6, 0.1, 0.5);
 //       rmBuildArea(cliffNE);    

//stop pesky players dropping mortars on the cliff

        int impassableLand = rmCreateArea("impassable Land");
        rmSetAreaSize(impassableLand, 0.4, 0.4);
        rmSetAreaLocation(impassableLand, 0.6, 0.6);	
 //       rmSetAreaTerrainType(impassableLand, "cave\cave_top");
        rmSetAreaCoherence(impassableLand, 1.0);
		rmSetAreaCliffType(impassableLand, "Pampas River");
		rmSetAreaCliffEdge(impassableLand, 1, 1, 0.0, 0.0, 2); 
		rmSetAreaCliffPainting(impassableLand, true, true, false, 1.5, true);
		rmSetAreaCliffHeight(impassableLand, 3, 0.1, 0.5);

		rmAddAreaConstraint(impassableLand, cliffWater2);
 //       rmBuildArea(impassableLand);  


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
		rmAddTradeRouteWaypoint(tradeRouteID, .00, .63);	    	     rmAddTradeRouteWaypoint(tradeRouteID, .2, .7);
		rmAddTradeRouteWaypoint(tradeRouteID, .4, .78);
		rmAddTradeRouteWaypoint(tradeRouteID, .6, .78);
		rmAddTradeRouteWaypoint(tradeRouteID, .8, .7);
		rmAddTradeRouteWaypoint(tradeRouteID, 1.0, .63);

        rmBuildTradeRoute(tradeRouteID, "dirt");
 
        vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);



	if (PlayerNum >= 4)
	{
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.1);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.9);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

   }    
	if (PlayerNum >= 6)
	{
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.6);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
            socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.4);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

   }    

}


  

		int centrePond=rmCreateArea("centre Pond");
        rmSetAreaLocation(centrePond, 0.5, 0.3);
        rmAddAreaInfluenceSegment(centrePond, 0.7, 0.0, 0.55, 0.55);
        rmAddAreaInfluenceSegment(centrePond, 0.3, 0.0, 0.45, 0.55);
        rmAddAreaInfluenceSegment(centrePond, 0.8, 0.0, 0.2, 0.0);

        rmAddAreaInfluencePoint(centrePond, 0.5, 0.02);

        rmSetAreaSize(centrePond, .32, .32);      
        rmSetAreaWaterType(centrePond, "hudson bay");
        rmSetAreaBaseHeight(centrePond, 0.0);
        rmSetAreaCoherence(centrePond, .92);
        rmBuildArea(centrePond);


			int patchID2 = rmCreateArea("the second patch");
			rmSetAreaWarnFailure(patchID2, false);
			rmSetAreaSize(patchID2, 0.99, 0.99);
			rmAddAreaTerrainReplacement(patchID2, "saguenay\shoreline3_sag", "patagonia\ground_shoreline2_pat");
			//rmPaintAreaTerrain(patchID2);
        rmSetAreaLocation(patchID2, 0.5, 0.6);	
		//	rmAddAreaToClass(patchID2, rmClassID("patch"));
	//		rmSetAreaSmoothDistance(patchID2, 1.0);
	//		rmAddAreaConstraint(patchID2, circleConstraint2);
			rmBuildArea(patchID2); 


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
      subCiv0=rmGetCivID("Guarani");
      rmEchoInfo("subCiv0 is Guarani"+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Guarani");

		subCiv1=rmGetCivID("Guarani");
      rmEchoInfo("subCiv1 is Guarani"+subCiv1);
		if (subCiv1 >= 0)
			 rmSetSubCiv(1, "Guarani");
	 
		subCiv2=rmGetCivID("Jesuit");
      rmEchoInfo("subCiv2 is Jesuit"+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Jesuit");

		subCiv3=rmGetCivID("Jesuit");
      rmEchoInfo("subCiv3 is Jesuit"+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Jesuit");
	}
	
	// Set up Natives	
	int nativeID0 = -1;
    int nativeID1 = -1;
	int nativeID2 = -1;
    int nativeID3 = -1;
		
	nativeID0 = rmCreateGrouping("native site 1", "native guarani village 1");
    rmSetGroupingMinDistance(nativeID0, 0.00);
    rmSetGroupingMaxDistance(nativeID0, 2.00);
	rmAddGroupingToClass(nativeID0, rmClassID("classPlateau"));

	nativeID1 = rmCreateGrouping("native site 2", "native jesuit mission cj 04");
    rmSetGroupingMinDistance(nativeID1, 0.00);
    rmSetGroupingMaxDistance(nativeID1, 2.00);
	rmAddGroupingToClass(nativeID1, rmClassID("classPlateau"));



//avoidTradeRouteSmall
//avoidTownCenterMore
//avoidCoin

//========place=====


	rmPlaceGroupingAtLoc(nativeID1, 0, 0.15, 0.24);
	rmPlaceGroupingAtLoc(nativeID1, 0, 0.85, 0.24);

	rmPlaceGroupingAtLoc(nativeID0, 0, 0.11, 0.79);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.89, 0.79);






	if (PlayerNum == 2)
{
  	int smollMines = rmCreateObjectDef("competitive gold");
	rmAddObjectDefItem(smollMines, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(smollMines, 0.0);
	rmSetObjectDefMaxDistance(smollMines, 0.0);
//back mines
//	rmPlaceObjectDefAtLoc(smollMines, 0, 0.5, 0.95, 1);
//	rmPlaceObjectDefAtLoc(smollMines, 0, 0.95, 0.5, 1);
//edge "anchor" mines
//	rmPlaceObjectDefAtLoc(smollMines, 0, 0.26, 0.85, 1);
//	rmPlaceObjectDefAtLoc(smollMines, 0, 0.85, 0.26, 1);
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
        rmAddObjectDefItem(goldID, "mine", 1, 0.0);
        rmSetObjectDefMinDistance(goldID, 12.0);
        rmSetObjectDefMaxDistance(goldID, 12.0);
       
        int goldID2 = rmCreateObjectDef("starting gold 2");
        rmAddObjectDefItem(goldID2, "mine", 1, 4.0);
        rmSetObjectDefMinDistance(goldID2, 0.0);
        rmSetObjectDefMaxDistance(goldID2, 3.0);


        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "BerryBush", 8, 6.0);
        rmSetObjectDefMinDistance(berryID, 8.0);
        rmSetObjectDefMaxDistance(berryID, 12.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "TreeAraucania", rmRandInt(8,9), 6.0);
        rmSetObjectDefMinDistance(treeID, 14.0);
        rmSetObjectDefMaxDistance(treeID, 15.0);
       // rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "rhea", 8, 8.0);
        rmSetObjectDefMinDistance(foodID, 0.0);
        rmSetObjectDefMaxDistance(foodID, 3.0);
	rmAddObjectDefConstraint(foodID, avoidWaterShort);	
        rmSetObjectDefCreateHerd(foodID, true);
        //rmAddObjectDefConstraint(foodID, avoidCoin);

 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "tapir", 7, 8.0);
        rmSetObjectDefMinDistance(foodID2, 0.0);
	rmAddObjectDefConstraint(foodID2, avoidWaterShort);	
        rmSetObjectDefMaxDistance(foodID2, 3.0);
        rmSetObjectDefCreateHerd(foodID2, true);
                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "tapir", 8, 8.0);
        rmSetObjectDefMinDistance(foodID3, 35.0);
        rmSetObjectDefMaxDistance(foodID3, 37.0);
	rmAddObjectDefConstraint(foodID3, avoidWaterShort);
	rmAddObjectDefConstraint(foodID3, avoidHunt2);		
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
		rmAddObjectDefItem(startID, "TownCenter", 1, 1.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 1.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i)-rmXTilesToFraction(6), rmPlayerLocZFraction(i)-rmXTilesToFraction(6));

//	if (PlayerNum >= 3)
//{
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
//}

        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i)+rmXTilesToFraction(12), rmPlayerLocZFraction(i)+rmXTilesToFraction(12));

        rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));


if (rmGetPlayerCiv(i) == rmGetCivID("Japanese")) {
        rmPlaceObjectDefAtLoc(extraberrywagon, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        }

		int waterFlag = rmCreateObjectDef("HC water flag "+i);
         rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 0.0);
         rmSetObjectDefMinDistance(waterFlag, 0);
         rmSetObjectDefMaxDistance(waterFlag, 30);
        rmAddObjectDefConstraint(waterFlag, flagLand);
         rmPlaceObjectDefAtLoc(waterFlag, i, 0.5, 0.3, 1);


	}
	rmSetStatusText("",0.6);
	/*
	==================
	resource placement
	==================
	*/





  	int eastmine = rmCreateObjectDef("east mines");
	rmAddObjectDefItem(eastmine, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(eastmine, 0.0);
	rmSetObjectDefMaxDistance(eastmine, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(eastmine, avoidCoinMed);
	rmAddObjectDefConstraint(eastmine, avoidTradeRouteSmall);
	rmAddObjectDefConstraint(eastmine, avoidPlateau);	
	rmAddObjectDefConstraint(eastmine, avoidWaterShort);
	rmAddObjectDefConstraint(eastmine, avoidTownCenterMore);
//rmAddObjectDefConstraint(eastmine, stayEast);
	rmAddObjectDefConstraint(eastmine, circleConstraint);
	rmPlaceObjectDefAtLoc(eastmine, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);
 


	
    int birdHunts = rmCreateObjectDef("birdHunts");
	rmAddObjectDefItem(birdHunts, "rhea", rmRandInt(10,11), 9.0);
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

  	int LlamaTime = rmCreateObjectDef("TINA");
	rmAddObjectDefItem(LlamaTime, "Llama", rmRandInt(2,2), 4.0);
	rmSetObjectDefMinDistance(LlamaTime, 0.0);
	rmSetObjectDefMaxDistance(LlamaTime, rmXFractionToMeters(0.65));
	rmAddObjectDefConstraint(LlamaTime, avoidHerd);
	rmAddObjectDefConstraint(LlamaTime, avoidPlateau);	
	rmAddObjectDefConstraint(LlamaTime, circleConstraint);
	rmAddObjectDefConstraint(LlamaTime, avoidTownCenterMore);
	//rmAddObjectDefConstraint(LlamaTime, avoidWaterShort);	
	rmPlaceObjectDefAtLoc(LlamaTime, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

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
		rmAddObjectDefItem(mapTrees, "TreeAraucania", rmRandInt(5,6), rmRandFloat(9.0,9.0));
        rmAddObjectDefItem(mapTrees, "TreeAndes", rmRandInt(7,7), 10.0);
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.7));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidCenter);
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
		rmAddObjectDefItem(bonusTrees, "treePuya", rmRandInt(2,2), rmRandFloat(8.0,11.0));
	rmAddObjectDefItem(bonusTrees, "UnderbrushPatagoniaDirt", rmRandInt(1,2), 7.0);
	  	rmAddObjectDefConstraint(bonusTrees, avoidTownCenter);
		rmAddObjectDefConstraint(bonusTrees, forestConstraintShort);
		rmAddObjectDefToClass(bonusTrees, rmClassID("classForest")); 
		rmAddObjectDefConstraint(bonusTrees, avoidWaterShort);	
	rmPlaceObjectDefInArea(bonusTrees, 0, continent2  , 15*cNumberNonGaiaPlayers);


	rmSetStatusText("",0.9);


	//fish and their constraints placed together at the end for ease of removal
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "ypFishCatfish", 15.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 65.0);
	int rocksHateRocksID=rmCreateTypeDistanceConstraint("rocks and rocks", "ShorelineRockBigNE", 30.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 30.0);


	int fishID=rmCreateObjectDef("fish Mahi");
	rmAddObjectDefItem(fishID, "ypFishCatfish", 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 25*cNumberNonGaiaPlayers);


	int rocksWater=rmCreateObjectDef("water rocks");
	rmAddObjectDefItem(rocksWater, "ShorelineRockBigNE", 1, 5.0);
	rmAddObjectDefItem(rocksWater, "ShorelineRockSmallNE", 1, 8.0);
	rmSetObjectDefMinDistance(rocksWater, 0.0);
	rmSetObjectDefMaxDistance(rocksWater, rmXFractionToMeters(0.4));
	rmAddObjectDefConstraint(rocksWater, rocksHateRocksID);
	rmAddObjectDefConstraint(rocksWater, fishLand);
//	rmAddObjectDefConstraint(rocksWater, fishLand2);
	//  	rmAddObjectDefConstraint(rocksWater, circleConstraint);
	rmPlaceObjectDefAtLoc(rocksWater, 0, 0.5, 0.7, 6*cNumberNonGaiaPlayers);


	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "MinkeWhale", 1, 4.0);

	if (PlayerNum == 2)
{
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.62, 0.3, 1);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.38, 0.3, 1);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 1);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.1, 1);

}
	if (PlayerNum >= 3)
{
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	  //	rmAddObjectDefConstraint(whaleID, circleConstraint);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
}




  // King of the Hill (added 2026-11 for WoL): the middle is the estuary; first open land on the line that splits the teams (the river bank inland)
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
    // (0.04 of the map side per step), with the include's placer constraints, 40 m from every Town Center
    // and 10 m from every tree
    int kothAvoidLand = rmCreateTerrainDistanceConstraint("koth hill avoids impassable land", "Land", false, 6.0);
    int kothAvoidAll = rmCreateTypeDistanceConstraint("koth hill avoids all", "all", 4.0);
    int kothAvoidTC = rmCreateTypeDistanceConstraint("koth hill avoids TCs", "TownCenter", 40.0);
    int kothAvoidTrees = rmCreateTypeDistanceConstraint("koth hill avoids trees", "Tree", 10.0);
    int kothAvoidSocket = rmCreateTypeDistanceConstraint("koth hill avoids trade sockets", "socketTradeRoute", 6.0);
    int kothAvoidRoute = rmCreateTradeRouteDistanceConstraint("koth hill avoids trade route", 6.0);
    int kothAvoidFlag = rmCreateTypeDistanceConstraint("koth hill avoids water flags", "HomeCityWaterSpawnFlag", 4.0);
    float kothDist = 0.0;
    for (kothRound = 0; < 17) {
      int kothHill = rmCreateObjectDef("koth hill " + kothRound);
      rmAddObjectDefItem(kothHill, "ypKingsHill", 1, 0);
      rmSetObjectDefMinDistance(kothHill, 0.0);
      rmSetObjectDefMaxDistance(kothHill, rmXFractionToMeters(0.05));
      rmAddObjectDefConstraint(kothHill, kothAvoidLand);
      rmAddObjectDefConstraint(kothHill, kothAvoidAll);
      rmAddObjectDefConstraint(kothHill, kothAvoidTC);
      rmAddObjectDefConstraint(kothHill, kothAvoidTrees);
      rmAddObjectDefConstraint(kothHill, kothAvoidSocket);
      rmAddObjectDefConstraint(kothHill, kothAvoidRoute);
      rmAddObjectDefConstraint(kothHill, kothAvoidFlag);
      rmPlaceObjectDefAtLoc(kothHill, 0, kothX + kothDirX * kothDist, kothZ + kothDirZ * kothDist, 1);
      if (rmGetNumberUnitsPlaced(kothHill) > 0)
        break;
      // 0, +1, -1, +2, -2, ... steps
      if (kothDist > 0.0)
        kothDist = 0.0 - kothDist;
      else
        kothDist = 0.04 - kothDist;
    }
  }

	}
 
