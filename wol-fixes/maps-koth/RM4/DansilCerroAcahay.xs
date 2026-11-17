// Alto Parana
// Made by dansil92
// Adapted to WOL by hrds

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
include "triggers\triggerLoader.xs";
 
void main(void) {
	rmSetStatusText("",0.01);
   // Picks the map size
	int playerTiles=25000;
	if (cNumberNonGaiaPlayers > 4){
		playerTiles = 22000;
	}else if (cNumberNonGaiaPlayers > 6){
		playerTiles = 19000;
	}
	
	int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmSetMapSize(size, size);


	rmSetMapType("land");
        rmSetMapType("grass");
        rmSetMapType("yucatan");
       	rmTerrainInitialize("grass");
		rmSetLightingSet("deccan");
rmSetSeaType("Araucania North Coast");
        rmDefineClass("classForest");
		rmDefineClass("classPlateau");
				
		//Constraints
		int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 10.0);

        int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.49), rmDegreesToRadians(0), rmDegreesToRadians(360));
       
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 12.0);
        int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
        
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

	if (cNumberTeams == 2){
		if (spawnSwitch <=0.6){
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.25, 0.35, 0.35, 0.25, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.75, 0.65, 0.65, 0.75, 0, 0);
		}else if(spawnSwitch <=1.2){
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.25, 0.35, 0.35, 0.25, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.75, 0.65, 0.65, 0.75, 0, 0);
		}
	}else{
		rmPlacePlayersCircular(0.3, 0.32, 0.02);
	}
		
		chooseMercs();
wotta_triggers();


        rmSetStatusText("",0.1); 
        int continent2 = rmCreateArea("continent");
        rmSetAreaSize(continent2, 1.0, 1.0);
        rmSetAreaLocation(continent2, 0.5, 0.5);
	rmSetAreaMix(continent2, "patagonia_grass");
        rmSetAreaTerrainType(continent2, "patagonia\ground_grass1_pat");
        rmSetAreaBaseHeight(continent2, -6.0);
        rmSetAreaCoherence(continent2, .99);
        rmSetAreaSmoothDistance(continent2, 10);
        rmSetAreaHeightBlend(continent2, 1);
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
        
		int center = rmCreateArea("center");
		rmAddAreaToClass(center, rmClassID("center"));
        rmSetAreaSize(center, .1, .1);
        rmSetAreaLocation(center, 0.5, 0.5);
        rmSetAreaCoherence(center, 1.0);
        rmBuildArea(center);   


//build textures

       		for (i=0; < cNumberNonGaiaPlayers*125){
			int patchID = rmCreateArea("first patch"+i);
			rmSetAreaWarnFailure(patchID, false);
			rmSetAreaSize(patchID, rmAreaTilesToFraction(40), rmAreaTilesToFraction(60));
			rmAddAreaTerrainReplacement(patchID, "patagonia\ground_grass1_pat", "patagonia\ground_dirt1_pat");
			rmPaintAreaTerrain(patchID);
			rmAddAreaToClass(patchID, rmClassID("patch"));
			rmSetAreaSmoothDistance(patchID, 1.0);
			rmAddAreaConstraint(patchID, circleConstraint2);
			rmBuildArea(patchID); 
		}
		
		for (i=0; < cNumberNonGaiaPlayers*125){
			int patchID2 = rmCreateArea("the second patch"+i);
			rmSetAreaWarnFailure(patchID2, false);
			rmSetAreaSize(patchID2, rmAreaTilesToFraction(11), rmAreaTilesToFraction(17));
			rmAddAreaTerrainReplacement(patchID2, "patagonia\ground_grass1_pat", "patagonia\ground_shoreline1_pat");
			rmPaintAreaTerrain(patchID2);
			rmAddAreaToClass(patchID2, rmClassID("patch"));
			rmSetAreaSmoothDistance(patchID2, 1.0);
			rmAddAreaConstraint(patchID2, circleConstraint2);
			rmBuildArea(patchID2); 
		}
		

		for (i=0; < cNumberNonGaiaPlayers*125){
			int patchID3 = rmCreateArea("the third patch"+i);
			rmSetAreaWarnFailure(patchID3, false);
			rmSetAreaSize(patchID3, rmAreaTilesToFraction(11), rmAreaTilesToFraction(17));
			rmAddAreaTerrainReplacement(patchID3, "patagonia\ground_grass1_pat", "patagonia\ground_dirt1_pat");
			rmPaintAreaTerrain(patchID3);
			rmAddAreaToClass(patchID3, rmClassID("patch"));
			rmSetAreaSmoothDistance(patchID3, 1.0);
			rmAddAreaConstraint(patchID3, circleConstraint2);
			rmBuildArea(patchID3); 
		}
		




rmSetStatusText("",0.2);
		




	//build trade routes

//trade route (south)

		int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
        rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID, true);
        rmSetObjectDefMinDistance(socketID, 0.0);
        rmSetObjectDefMaxDistance(socketID, 6.0);      
       
        int tradeRouteID = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
		rmAddTradeRouteWaypoint(tradeRouteID, .05, .5);
		rmAddTradeRouteWaypoint(tradeRouteID, .4, .5);
		rmAddTradeRouteWaypoint(tradeRouteID, .5, .4);
	rmAddTradeRouteWaypoint(tradeRouteID, .5, .05);
        rmBuildTradeRoute(tradeRouteID, "dirt");
 
        vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.4);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.15);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.6);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.85);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);



		
		//trade route(north)

		int socketID2=rmCreateObjectDef("sockets to dock Trade Posts2");
        rmAddObjectDefItem(socketID2, "SocketTradeRoute", 1, 0.0);
        rmSetObjectDefAllowOverlap(socketID2, true);
        rmSetObjectDefMinDistance(socketID2, 0.0);
        rmSetObjectDefMaxDistance(socketID2, 6.0);      
       
        int tradeRouteID2 = rmCreateTradeRoute();
        rmSetObjectDefTradeRouteID(socketID2, tradeRouteID2);
		rmAddTradeRouteWaypoint(tradeRouteID2, .5, .95);
		rmAddTradeRouteWaypoint(tradeRouteID2, .5, .6);
	rmAddTradeRouteWaypoint(tradeRouteID2, .6, .5);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.95, .5);

        rmBuildTradeRoute(tradeRouteID2, "dirt");
 
		vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.15);
        rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
       
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.4);
        rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
       
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.6);
        rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);

        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.85);
        rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);

       		
		//end tr 2	

	//Choose Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int subCiv3=-1;

   if (rmAllocateSubCivs(4) == true)
   {
      subCiv0=rmGetCivID("Guarani");
      rmEchoInfo("subCiv0 is Guarani "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "Guarani");

		subCiv1=rmGetCivID("Guaicuru");
      rmEchoInfo("subCiv1 is Guaicuru "+subCiv1);
		if (subCiv1 >= 0)
			 rmSetSubCiv(1, "Guaicuru");
	 
		subCiv2=rmGetCivID("Guarani");
      rmEchoInfo("subCiv2 is Guarani "+subCiv2);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, "Guarani");

		subCiv3=rmGetCivID("Guaicuru");
      rmEchoInfo("subCiv3 is Guaicuru "+subCiv3);
      if (subCiv3 >= 0)
         rmSetSubCiv(3, "Guaicuru");
	}




	//Jesuit settlements

	int VillageID2 =-1;
if (rmRandFloat(0,1)<0.5)
	VillageID2 = rmCreateGrouping("right location", "native Guarani village "+rmRandInt(1,3)); //   X marks the spot
else
	VillageID2 = rmCreateGrouping("right location", "native Guaicuru village "+rmRandInt(1,3));
    rmSetGroupingMinDistance(VillageID2, 0.0);
    rmSetGroupingMaxDistance(VillageID2, rmXFractionToMeters(0.0));
	rmPlaceGroupingAtLoc(VillageID2, 0, 0.4, 0.4);


	int VillageID3 =-1;
if (rmRandFloat(0,1)<0.5)
	VillageID3 = rmCreateGrouping("right location", "native Guaicuru village "+rmRandInt(1,3)); //   X marks the spot
else
	VillageID3 = rmCreateGrouping("right location", "native Guarani village "+rmRandInt(1,3));
    rmSetGroupingMinDistance(VillageID3, 0.0);
    rmSetGroupingMaxDistance(VillageID3, rmXFractionToMeters(0.0));
	rmPlaceGroupingAtLoc(VillageID3, 0, 0.6, 0.6);

	int VillageID4 =-1;
if (rmRandFloat(0,1)<0.5)
	VillageID4 = rmCreateGrouping("right location", "native Guaicuru village "+rmRandInt(1,3)); //   X marks the spot
else
	VillageID4 = rmCreateGrouping("right location", "native Guarani village "+rmRandInt(1,3));
    rmSetGroupingMinDistance(VillageID4, 0.0);
    rmSetGroupingMaxDistance(VillageID4, rmXFractionToMeters(0.0));
	rmPlaceGroupingAtLoc(VillageID4, 0, 0.4, 0.6);

	int VillageID5 =-1;
if (rmRandFloat(0,1)<0.5)
	VillageID5 = rmCreateGrouping("right location", "native Guarani village "+rmRandInt(1,3)); //   X marks the spot
else
	VillageID5 = rmCreateGrouping("right location", "native Guaicuru village "+rmRandInt(1,3));
    rmSetGroupingMinDistance(VillageID5, 0.0);
    rmSetGroupingMaxDistance(VillageID5, rmXFractionToMeters(0.0));
	rmPlaceGroupingAtLoc(VillageID5, 0, 0.6, 0.4);




		rmSetStatusText("",0.3);





//coding for crater start:
		

		int crater = rmCreateArea("crater");
        rmSetAreaSize(crater, .5, .54);
        rmSetAreaLocation(crater, 0.5, 0.5);        	rmSetAreaBaseHeight(crater, 7.0);
        rmSetAreaCoherence(crater, .8);
		rmSetAreaHeightBlend(crater, 12);
		rmSetAreaElevationNoiseBias(crater, 0);
        rmSetAreaElevationEdgeFalloffDist(crater, 10);
        rmSetAreaElevationVariation(crater, 5);
        rmSetAreaElevationPersistence(crater, .2);
        rmSetAreaElevationOctaves(crater, 5);
        rmSetAreaElevationMinFrequency(crater, 0.04);
        rmSetAreaElevationType(crater, cElevTurbulence);  
        rmBuildArea(crater);  
	

		int innercliff = rmCreateArea("innercliff");
        rmSetAreaSize(innercliff, .36, .38);
        rmSetAreaLocation(innercliff, 0.5, 0.5);
            rmSetAreaBaseHeight(innercliff, -6.0);
        rmSetAreaCoherence(innercliff, .8);
		rmSetAreaHeightBlend(innercliff, 7);
		rmSetAreaElevationNoiseBias(innercliff, 0);
        rmSetAreaElevationEdgeFalloffDist(innercliff, 10);
        rmSetAreaElevationVariation(innercliff, 7);
        rmSetAreaElevationPersistence(innercliff, .2);
        rmSetAreaElevationOctaves(innercliff, 5);
        rmSetAreaElevationMinFrequency(innercliff, 0.04);
        rmSetAreaElevationType(innercliff, cElevTurbulence);  
        rmBuildArea(innercliff);  





		int lowlands=rmCreateArea("lowlands");
        rmSetAreaLocation(lowlands, 0.5, 0.5); 
	rmSetAreaTerrainType(lowlands, "patagonia\groundforest_pat");      
        rmSetAreaSize(lowlands, .04, .05); 
        rmSetAreaCoherence(lowlands, 0.35);
        rmBuildArea(lowlands);



//central hill
	
		int cerro = rmCreateArea("cerro");
        rmSetAreaSize(cerro, .004, .005);
        rmSetAreaLocation(cerro, 0.5, 0.5);
        rmSetAreaTerrainType(cerro, "patagonia\ground_clifftop_pat");
        rmSetAreaBaseHeight(cerro, 6.0);
		rmSetAreaHeightBlend(cerro, 12);
 //	rmAddAreaInfluenceSegment(cerro, 0.0, 1.0, 1.0, 0.0);
       rmSetAreaCoherence(cerro, .67);
        rmBuildArea(cerro);    




//End crater



//Start waypoints for traderoude paths


//SW	
		int waypoint1 = rmCreateArea("waypoint1");
        rmSetAreaSize(waypoint1, .008, .009);
        rmSetAreaLocation(waypoint1, 0.1, 0.5);
        rmSetAreaTerrainType(waypoint1, "patagonia\ground_grass1_pat");
        rmSetAreaBaseHeight(waypoint1, -7.0);
		rmSetAreaHeightBlend(waypoint1, 12);
 	rmAddAreaInfluenceSegment(waypoint1, 0.05, 0.5, 0.18, 0.5);
       rmSetAreaCoherence(waypoint1, .87);
        rmBuildArea(waypoint1);    


//SE
		int waypoint2 = rmCreateArea("waypoint2");
        rmSetAreaSize(waypoint2, .008, .009);
        rmSetAreaLocation(waypoint2, 0.5, 0.1);
        rmSetAreaTerrainType(waypoint2, "patagonia\ground_grass1_pat");
        rmSetAreaBaseHeight(waypoint2, -7.0);
		rmSetAreaHeightBlend(waypoint2, 12);
 	rmAddAreaInfluenceSegment(waypoint2, 0.5, 0.05, 0.5, 0.18);
       rmSetAreaCoherence(waypoint2, .87);
        rmBuildArea(waypoint2);    


//NW
		int waypoint3 = rmCreateArea("waypoint3");
        rmSetAreaSize(waypoint3, .008, .009);
        rmSetAreaLocation(waypoint3, 0.5, 0.9);
        rmSetAreaTerrainType(waypoint3, "patagonia\ground_grass1_pat");
        rmSetAreaBaseHeight(waypoint3, -7.0);
		rmSetAreaHeightBlend(waypoint3, 12);
 	rmAddAreaInfluenceSegment(waypoint3, 0.5, 0.95, 0.5, 0.82);
       rmSetAreaCoherence(waypoint3, .87);
        rmBuildArea(waypoint3);    



//NE


		int waypoint4 = rmCreateArea("waypoint4");
        rmSetAreaSize(waypoint4, .008, .009);
        rmSetAreaLocation(waypoint4, 0.9, 0.5);
        rmSetAreaTerrainType(waypoint4, "patagonia\ground_grass1_pat");
        rmSetAreaBaseHeight(waypoint4, -7.0);
		rmSetAreaHeightBlend(waypoint4, 12);
 	rmAddAreaInfluenceSegment(waypoint4, 0.95, 0.5, 0.82, 0.5);
       rmSetAreaCoherence(waypoint4, .87);
        rmBuildArea(waypoint4);    

//End waypoints


		//starting objects
		
        int playerStart = rmCreateStartingUnitsObjectDef(5.0);
        rmSetObjectDefMinDistance(playerStart, 7.0);
        rmSetObjectDefMaxDistance(playerStart, 12.0);
       
        int goldID = rmCreateObjectDef("starting gold");
        rmAddObjectDefItem(goldID, "mine", 1, 8.0);
        rmSetObjectDefMinDistance(goldID, 12.0);
        rmSetObjectDefMaxDistance(goldID, 12.0);
       
        int goldID2 = rmCreateObjectDef("starting gold 2");
        rmAddObjectDefItem(goldID2, "mine", 1, 16.0);
        rmSetObjectDefMinDistance(goldID2, 12.0);
        rmSetObjectDefMaxDistance(goldID2, 12.0);
        rmAddObjectDefConstraint(goldID2, avoidCoin);
 
/*

        int berryID = rmCreateObjectDef("starting berries");
        rmAddObjectDefItem(berryID, "BerryBush", 4, 6.0);
        rmSetObjectDefMinDistance(berryID, 8.0);
        rmSetObjectDefMaxDistance(berryID, 12.0);
        rmAddObjectDefConstraint(berryID, avoidCoin);

*/
 
        int treeID = rmCreateObjectDef("starting trees");
        rmAddObjectDefItem(treeID, "treeCaribbean", rmRandInt(6,9), 10.0);
        rmSetObjectDefMinDistance(treeID, 12.0);
        rmSetObjectDefMaxDistance(treeID, 18.0);
        rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
        rmAddObjectDefConstraint(treeID, avoidCoin);
 
        int foodID = rmCreateObjectDef("starting hunt");
        rmAddObjectDefItem(foodID, "Capybara", 6, 8.0);
        rmSetObjectDefMinDistance(foodID, 10.0);
        rmSetObjectDefMaxDistance(foodID, 10.0);
        rmSetObjectDefCreateHerd(foodID, true);
 
        int foodID2 = rmCreateObjectDef("starting hunt 2");
        rmAddObjectDefItem(foodID2, "Rhea", 12, 8.0);
        rmSetObjectDefMinDistance(foodID2, 40.0);
        rmSetObjectDefMaxDistance(foodID2, 40.0);
        rmSetObjectDefCreateHerd(foodID2, true);
                       
		int foodID3 = rmCreateObjectDef("starting hunt 3");
        rmAddObjectDefItem(foodID3, "Tapir", 8, 8.0);
        rmSetObjectDefMinDistance(foodID3, 65.0);
        rmSetObjectDefMaxDistance(foodID3, 65.0);
        rmSetObjectDefCreateHerd(foodID3, true);

		rmSetStatusText("",0.5);      

  int extraberrywagon=rmCreateObjectDef("Starting Asian Outpost");
  rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
  rmSetObjectDefMinDistance(extraberrywagon, 10.0);
  rmSetObjectDefMaxDistance(extraberrywagon, 10.0);		
  rmAddObjectDefConstraint(extraberrywagon, avoidCoin);
		
    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "TownCenter", 1, 5.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 10.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
  //      rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        //rmPlaceObjectDefAtLoc(goldID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
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
	
    int pronghornHunts = rmCreateObjectDef("pronghornHunts");
	rmAddObjectDefItem(pronghornHunts, "Tapir", rmRandInt(9,10), 11.0);
	rmSetObjectDefCreateHerd(pronghornHunts, true);
	rmSetObjectDefMinDistance(pronghornHunts, 0);
	rmSetObjectDefMaxDistance(pronghornHunts, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(pronghornHunts, circleConstraint);
	rmAddObjectDefConstraint(pronghornHunts, avoidTownCenterMore);
	rmAddObjectDefConstraint(pronghornHunts, avoidHunt);
	rmAddObjectDefConstraint(pronghornHunts, avoidCenter);
	rmAddObjectDefConstraint(pronghornHunts, avoidPlateau);	
	rmPlaceObjectDefAtLoc(pronghornHunts, 0, 0.5, 0.5, 11*cNumberNonGaiaPlayers);


  	int islandminesID = rmCreateObjectDef("island silver");
	rmAddObjectDefItem(islandminesID, "mine", 1, 1.0);
	rmSetObjectDefMinDistance(islandminesID, 0.0);
	rmSetObjectDefMaxDistance(islandminesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(islandminesID, avoidCoinMed);
	rmAddObjectDefConstraint(islandminesID, avoidTownCenterMore);
	rmAddObjectDefConstraint(islandminesID, avoidSocket);
	rmAddObjectDefConstraint(islandminesID, avoidCenter);
	rmAddObjectDefConstraint(islandminesID, avoidPlateau);	
	rmAddObjectDefConstraint(islandminesID, avoidWaterShort);
	rmAddObjectDefConstraint(islandminesID, forestConstraintShort);
	rmAddObjectDefConstraint(islandminesID, circleConstraint);
	rmPlaceObjectDefAtLoc(islandminesID, 0, 0.5, 0.5, 8*cNumberNonGaiaPlayers);
 
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
	rmAddObjectDefConstraint(nuggetID, avoidPlateau);		rmAddObjectDefConstraint(nuggetID, avoidCenter);	
	rmSetNuggetDifficulty(2, 3); 
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);   
	rmSetStatusText("",0.7);

//so many trees


	//removes loop for faster loading times
	//for (j=0; < (14*cNumberNonGaiaPlayers)) {   
		int mapTrees=rmCreateObjectDef("map trees");
		rmAddObjectDefItem(mapTrees, "treeCaribbean", rmRandInt(8,10), rmRandFloat(14.0,16.0));
		rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees, 0);
		rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees, avoidSocket);
	  	rmAddObjectDefConstraint(mapTrees, circleConstraint);
		rmAddObjectDefConstraint(mapTrees, forestConstraint);
		rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees, avoidPlateau);	
		rmAddObjectDefConstraint(mapTrees, avoidWaterShort);	
		rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 17*cNumberNonGaiaPlayers);
	//}

	int mapTrees2=rmCreateObjectDef("map trees 2");
		rmAddObjectDefItem(mapTrees2, "treePuya", rmRandInt(4,6), rmRandFloat(6.0,12.0));
		rmAddObjectDefToClass(mapTrees2, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees2, 0);
		rmSetObjectDefMaxDistance(mapTrees2, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(mapTrees2, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees2, avoidSocket);
	  	rmAddObjectDefConstraint(mapTrees2, circleConstraint);
		rmAddObjectDefConstraint(mapTrees2, forestConstraint);
		rmAddObjectDefConstraint(mapTrees2, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees2, avoidWaterShort);	
		rmPlaceObjectDefAtLoc(mapTrees2, 0, 0.5, 0.5, 17*cNumberNonGaiaPlayers);
	


	int mapTrees3=rmCreateObjectDef("map trees 3");
		rmAddObjectDefItem(mapTrees3, "treeYucatan", rmRandInt(4,10), rmRandFloat(14.0,16.0));
		rmAddObjectDefToClass(mapTrees3, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees3, 0);
		rmSetObjectDefMaxDistance(mapTrees3, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(mapTrees3, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees3, avoidSocket);
	  	rmAddObjectDefConstraint(mapTrees3, circleConstraint);
		rmAddObjectDefConstraint(mapTrees3, forestConstraint);
		rmAddObjectDefConstraint(mapTrees3, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees3, avoidWaterShort);	
		rmPlaceObjectDefAtLoc(mapTrees3, 0, 0.5, 0.5, 17*cNumberNonGaiaPlayers);


	int mapTrees4=rmCreateObjectDef("map trees 4");
		rmAddObjectDefItem(mapTrees4, "treePampas", rmRandInt(2,4), rmRandFloat(20.0,21.0));
		rmAddObjectDefToClass(mapTrees4, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(mapTrees4, 0);
		rmSetObjectDefMaxDistance(mapTrees4, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(mapTrees4, avoidTradeRouteSmall);
		rmAddObjectDefConstraint(mapTrees4, avoidSocket);
	  	rmAddObjectDefConstraint(mapTrees4, circleConstraint);
		rmAddObjectDefConstraint(mapTrees4, forestConstraint);
		rmAddObjectDefConstraint(mapTrees4, avoidTownCenter);	
		rmAddObjectDefConstraint(mapTrees4, avoidWaterShort);	
		rmPlaceObjectDefAtLoc(mapTrees4, 0, 0.5, 0.5, 47*cNumberNonGaiaPlayers);





		rmSetStatusText("",0.9);
	

  // King of the Hill (added 2026-11 for WoL): the middle of all start positions (the map centre), on open land
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
 
