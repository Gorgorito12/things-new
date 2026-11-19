// Black Forest by M0nTy_PyThon - a modified ALFHEIM map
//
// Main entry point for random map script
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";
void main(void)
{

   // Text
   rmSetStatusText("",0.01);

   // Set size.
   int playerTiles=9000;
   if(cMapSize == 1)
   {
      playerTiles = 12500;
      rmEchoInfo("Large map");
   }
   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

   // Set up default water.
   rmSetSeaLevel(0.0);

   // Init map.
	rmSetBaseTerrainMix("rockies_grass");
	rmTerrainInitialize("NWterritory\ground_grass1_nwt", 5);
	rmSetMapType("northwestTerritory");
	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetLightingSet("nwterritory");
	rmSetWorldCircleConstraint(true);

	wotta_triggers();
	
   // Define some classes.
   int classPlayer=rmDefineClass("player");
   rmDefineClass("classHill");
   rmDefineClass("starting settlement");

    // -------------Define constraints

   // Create a edge of map constraint.
   int edgeConstraint=rmCreateBoxConstraint("edge of map", rmXTilesToFraction(8), rmZTilesToFraction(8), 1.0-rmXTilesToFraction(8), 1.0-rmZTilesToFraction(8));

   // Player area constraint.
   int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 20);

   // Settlement constraint.
   int shortAvoidSettlement=rmCreateTypeDistanceConstraint("objects avoid TC by short distance", "AbstractTownCenter", 10.0);
   int farAvoidSettlement=rmCreateTypeDistanceConstraint("objects avoid TC by long distance", "AbstractTownCenter", 50.0);
   int farStartingSettleConstraint=rmCreateClassDistanceConstraint("objects avoid player TCs", rmClassID("starting settlement"), 50.0);

   // Tower constraint.
   int avoidTower=rmCreateTypeDistanceConstraint("towers avoid towers", "tower", 20.0);
   int avoidTower2=rmCreateTypeDistanceConstraint("objects avoid towers", "tower", 22.0);

   // Gold
   int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "abstractmine", 30.0);
   int shortAvoidGold=rmCreateTypeDistanceConstraint("gold vs. gold", "abstractmine", 24.0);

   // Herd animals
   int avoidHerdable=rmCreateTypeDistanceConstraint("avoid herdable", "herdable", 20.0);
   int avoidFood=rmCreateTypeDistanceConstraint("avoid food", "food", 12.0);
   int avoidPredator=rmCreateTypeDistanceConstraint("avoid predator", "animalPredator", 40.0);

   // Avoid impassable land
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "land", false, 8.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "land", false, 4.0);
   int avoidBuildings=rmCreateTypeDistanceConstraint("avoid buildings", "Building", 20.0);

   // -------------Define objects
   // Close Objects

   int startingSettlementID=rmCreateObjectDef("Starting settlement");
   rmAddObjectDefItem(startingSettlementID, "TownCenter", 1, 0.0);
   rmAddObjectDefToClass(startingSettlementID, rmClassID("starting settlement"));
   rmSetObjectDefMinDistance(startingSettlementID, 0.0);
   rmSetObjectDefMaxDistance(startingSettlementID, 0.0);

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
   
   // towers avoid other towers
   int startingTowerID=rmCreateObjectDef("Starting tower");
   rmAddObjectDefItem(startingTowerID, "tower", 1, 0.0);
   rmSetObjectDefMinDistance(startingTowerID, 22.0);
   rmSetObjectDefMaxDistance(startingTowerID, 28.0);
   rmAddObjectDefConstraint(startingTowerID, avoidTower);

   // gold avoids gold
   int startingGoldID=rmCreateObjectDef("Starting gold");
   rmAddObjectDefItem(startingGoldID, "mine", 1, 0.0);
   rmSetObjectDefMinDistance(startingGoldID, 20.0);
   rmSetObjectDefMaxDistance(startingGoldID, 25.0);
   rmAddObjectDefConstraint(startingGoldID, avoidGold);

   int closeCowsID=rmCreateObjectDef("close Cows");
   rmAddObjectDefItem(closeCowsID, "cow", rmRandInt(2,5), 2.0);
   rmSetObjectDefMinDistance(closeCowsID, 20.0);
   rmSetObjectDefMaxDistance(closeCowsID, 25.0);
   rmAddObjectDefConstraint(closeCowsID, avoidFood);

   int BerryNum=rmRandInt(6, 10);
   int closeChickensID=rmCreateObjectDef("close Chickens");
   rmAddObjectDefItem(closeChickensID, "fowl", BerryNum, 5.0);
   rmSetObjectDefMinDistance(closeChickensID, 25.0);
   rmSetObjectDefMaxDistance(closeChickensID, 30.0);

   int avoidChickens=rmCreateTypeDistanceConstraint("avoid chickens", "chicken", 10.0);
   int closeBerriesID=rmCreateObjectDef("close berries");
   rmAddObjectDefItem(closeBerriesID, "berrybush", BerryNum, 4.0);
   rmSetObjectDefMinDistance(closeBerriesID, 20.0);
   rmSetObjectDefMaxDistance(closeBerriesID, 28.0);
   rmAddObjectDefConstraint(closeBerriesID, avoidChickens);
   
   int closeElkID=rmCreateObjectDef("close elk");
   if(rmRandFloat(0,1)<0.75)
      rmAddObjectDefItem(closeElkID, "elk", rmRandInt(7,8), 4.0);
   else
      rmAddObjectDefItem(closeElkID, "elk", 9, 2.0);
   rmSetObjectDefMinDistance(closeElkID, 15.0);
   rmSetObjectDefMaxDistance(closeElkID, 23.0);
   rmAddObjectDefConstraint(closeElkID, shortAvoidSettlement);
   rmAddObjectDefConstraint(closeElkID, avoidChickens);
   
   int stragglerTreeID=rmCreateObjectDef("straggler tree");
   rmAddObjectDefItem(stragglerTreeID, "TreeRockies", 1, 0.0);
   rmSetObjectDefMinDistance(stragglerTreeID, 12.0);
   rmSetObjectDefMaxDistance(stragglerTreeID, 15.0);

   // Medium Objects

   // gold avoids gold and Settlements
   int mediumGoldID=rmCreateObjectDef("medium gold");
   rmAddObjectDefItem(mediumGoldID, "mine", 1, 0.0);
   rmSetObjectDefMinDistance(mediumGoldID, 40.0);
   rmSetObjectDefMaxDistance(mediumGoldID, 60.0);
   rmAddObjectDefConstraint(mediumGoldID, shortAvoidGold);
   rmAddObjectDefConstraint(mediumGoldID, shortAvoidSettlement);
   rmAddObjectDefConstraint(mediumGoldID, farStartingSettleConstraint);

   int mediumCowID=rmCreateObjectDef("medium Cow");
   rmAddObjectDefItem(mediumCowID, "cow", rmRandFloat(2,3), 4.0);
   rmSetObjectDefMinDistance(mediumCowID, 50.0);
   rmSetObjectDefMaxDistance(mediumCowID, 100.0);
   rmAddObjectDefConstraint(mediumCowID, farStartingSettleConstraint); 

   int mediumDeerID=rmCreateObjectDef("medium deer");
   rmAddObjectDefItem(mediumDeerID, "deer", rmRandInt(7,8), 4.0);
   rmAddObjectDefItem(mediumDeerID, "deer", rmRandInt(6,7), 4.0);
   rmSetObjectDefMinDistance(mediumDeerID, 50.0);
   rmSetObjectDefMaxDistance(mediumDeerID, 55.0);
   rmAddObjectDefConstraint(mediumDeerID, avoidFood);
   rmAddObjectDefConstraint(mediumDeerID, farStartingSettleConstraint);

   // Far Objects

   // gold avoids gold, Settlements and TCs
   int farGoldID=rmCreateObjectDef("far gold");
   rmAddObjectDefItem(farGoldID, "minegold", 1, 0.0);
   rmSetObjectDefMinDistance(farGoldID, 80.0);
   rmSetObjectDefMaxDistance(farGoldID, 150.0);
   rmAddObjectDefConstraint(farGoldID, shortAvoidGold);
   rmAddObjectDefConstraint(farGoldID, shortAvoidSettlement);
   rmAddObjectDefConstraint(farGoldID, farStartingSettleConstraint);
  
   int farCowID=rmCreateObjectDef("far Cow");
   rmAddObjectDefItem(farCowID, "cow", rmRandInt(2,3), 4.0);
   rmSetObjectDefMinDistance(farCowID, 80.0);
   rmSetObjectDefMaxDistance(farCowID, 150.0);
   rmAddObjectDefConstraint(farCowID, farStartingSettleConstraint);
   rmAddObjectDefConstraint(farCowID, avoidHerdable);
   rmAddObjectDefConstraint(farCowID, avoidFood);
   
   
     int Boar=rmCreateObjectDef("Boar");
  rmAddObjectDefItem(Boar, "Boar", 1, 1.0);
  rmSetObjectDefMinDistance(Boar, 0.0);
  rmSetObjectDefMaxDistance(Boar, rmXFractionToMeters(0.225));
  rmAddObjectDefConstraint(Boar, shortAvoidSettlement);
  rmPlaceObjectDefAtLoc(Boar, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2); 

   // pick wolves or bears as predators
   // avoid TCs and other animals
   int farPredatorID=rmCreateObjectDef("far predator");
   float predatorSpecies=rmRandFloat(0, 1);
   if(predatorSpecies<0.5)   
      rmAddObjectDefItem(farPredatorID, "wolf", rmRandInt(2,3), 4.0);
   else
      rmAddObjectDefItem(farPredatorID, "bear", 2, 4.0);
   rmSetObjectDefMinDistance(farPredatorID, 50.0);
   rmSetObjectDefMaxDistance(farPredatorID, 100.0);
   rmAddObjectDefConstraint(farPredatorID, avoidPredator);
   rmAddObjectDefConstraint(farPredatorID, farStartingSettleConstraint); 
   rmAddObjectDefConstraint(farPredatorID, avoidFood);

   // This map will either use boar or deer as the extra huntable food.
   int classBonusHuntable=rmDefineClass("bonus huntable");
   int avoidBonusHuntable=rmCreateClassDistanceConstraint("avoid bonus huntable", classBonusHuntable, 40.0);
   int avoidHuntable=rmCreateTypeDistanceConstraint("avoid huntable", "huntable", 20.0);

   // hunted avoids hunted and TCs
   int bonusHuntableID=rmCreateObjectDef("bonus huntable");
   float bonusChance=rmRandFloat(0, 1);
   if(bonusChance < 0.33)   
      rmAddObjectDefItem(bonusHuntableID, "elk", rmRandInt(3,8), 4.0);
   else if(bonusChance < 0.66)
      rmAddObjectDefItem(bonusHuntableID, "caribou", rmRandInt(3,6), 4.0);
   else
      rmAddObjectDefItem(bonusHuntableID, "aurochs", rmRandInt(3,4), 4.0);
   rmSetObjectDefMinDistance(bonusHuntableID, 0.0);
   rmSetObjectDefMaxDistance(bonusHuntableID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(bonusHuntableID, avoidBonusHuntable);
   rmAddObjectDefConstraint(bonusHuntableID, avoidHuntable);
   rmAddObjectDefToClass(bonusHuntableID, classBonusHuntable);
   rmAddObjectDefConstraint(bonusHuntableID, farStartingSettleConstraint); 
   
   int randomTreeID=rmCreateObjectDef("random tree");
   rmAddObjectDefItem(randomTreeID, "TreeRockies", 1, 0.0);
   rmSetObjectDefMinDistance(randomTreeID, 0.0);
   rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTreeID, rmCreateTypeDistanceConstraint("random tree", "all", 4.0));
   rmAddObjectDefConstraint(randomTreeID, shortAvoidSettlement);
   rmAddObjectDefConstraint(randomTreeID, shortAvoidImpassableLand);


   // -------------Done defining objects

   // Cheesy "circular" placement of players.
   rmSetTeamSpacingModifier(0.75);
   rmPlacePlayersCircular(0.3, 0.4, rmDegreesToRadians(5.0));

   // Set up player areas.
   float playerFraction=rmAreaTilesToFraction(4000);
   for(i=1; <cNumberPlayers)
   {
      // Create the area.
      int id=rmCreateArea("Player"+i);

      // Assign to the player.
      rmSetPlayerArea(i, id);

      // Set the size.
      rmSetAreaSize(id, 0.9*playerFraction, 1.1*playerFraction);

      rmAddAreaToClass(id, classPlayer);
      rmSetAreaWarnFailure(id, false);

      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 5);
      rmSetAreaMinBlobDistance(id, 16.0);
      rmSetAreaMaxBlobDistance(id, 40.0);
      rmSetAreaCoherence(id, 0.0);

      //rmSetAreaBaseHeight(id, 4.0);

      // Add constraints.
      rmAddAreaConstraint(id, playerConstraint);

      // Set the location.
      rmSetAreaLocPlayer(id, i);


   }

   // Build the areas.
   rmBuildAllAreas();

   for(i=1; <cNumberPlayers)
   {
      // Beautification sub area.
      int id2=rmCreateArea("Player inner"+i, rmAreaID("player"+i));
      rmSetAreaSize(id2, rmAreaTilesToFraction(200), rmAreaTilesToFraction(300));
      rmSetAreaLocPlayer(id2, i);
      rmSetAreaTerrainType(id2, "rockies\groundforest_roc");
      rmSetAreaMinBlobs(id2, 1);
      rmSetAreaMaxBlobs(id2, 5);
      rmSetAreaMinBlobDistance(id2, 16.0);
      rmSetAreaMaxBlobDistance(id2, 40.0);
      rmSetAreaCoherence(id2, 0.0);

      rmBuildArea(id2); 
   } 

      for(i=1; <cNumberPlayers*20)
   {
      // Beautification sub area.
      int id4=rmCreateArea("Grass patch 2 "+i);
      rmSetAreaSize(id4, rmAreaTilesToFraction(5), rmAreaTilesToFraction(16));
      rmSetAreaTerrainType(id4, "nwterritory\ground_grass3_nwt");
      rmSetAreaMinBlobs(id4, 1);
      rmSetAreaMaxBlobs(id4, 5);
      rmSetAreaWarnFailure(id4, false);
      rmSetAreaMinBlobDistance(id4, 16.0);
      rmSetAreaMaxBlobDistance(id4, 40.0);
      rmSetAreaCoherence(id4, 0.0);

      rmBuildArea(id4);
   }

   for(i=1; <cNumberPlayers*12)
   {
      // Beautification sub area.
      int id5=rmCreateArea("Grass patch 3 "+i);
      rmSetAreaSize(id5, rmAreaTilesToFraction(5), rmAreaTilesToFraction(20));
      rmSetAreaTerrainType(id5, "coastal japan\ground_grass1_co_japan");
      rmSetAreaMinBlobs(id5, 1);
      rmSetAreaMaxBlobs(id5, 5);
      rmSetAreaWarnFailure(id5, false);
      rmSetAreaMinBlobDistance(id5, 16.0);
      rmSetAreaMaxBlobDistance(id5, 40.0);
      rmSetAreaCoherence(id5, 0.0);

      rmBuildArea(id5);
   }



      // Text
   rmSetStatusText("",0.20);

   // Place starting settlements.
   // Close things....
   // TC
   rmPlaceObjectDefPerPlayer(startingSettlementID, true);
	for(i=1; < cNumberPlayers)
	{
		rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	}

   // Settlements.
   id=rmAddFairLoc("Settlement", false, true,  60, 80, 40, 10);

   id=rmAddFairLoc("Settlement", true, false, 70, 120, 60, 10);

   id=rmAddFairLoc("Settlement", false, true,  80, 130, 60, 10);

   if(rmPlaceFairLocs())
   {
      id=rmCreateObjectDef("far settlement2");
      rmAddObjectDefItem(id, "Settlement", 1, 0.0);
      for(i=1; <cNumberPlayers)
      {
         for(j=0; <rmGetNumberFairLocs(i))
            rmPlaceObjectDefAtLoc(id, i, rmFairLocXFraction(i, j), rmFairLocZFraction(i, j), 1);
      }
   }

   // Text
   rmSetStatusText("",0.40);

   // Towers.
   rmPlaceObjectDefPerPlayer(startingTowerID, true, 4);


   // Slight Elevation
   int numTries=30*cNumberNonGaiaPlayers;
   int failCount=0;
   for(i=0; <numTries)
   {
      int elevID=rmCreateArea("wrinkle"+i);
      rmSetAreaSize(elevID, rmAreaTilesToFraction(15), rmAreaTilesToFraction(120));
      rmSetAreaLocation(elevID, rmRandFloat(0.0, 1.0), rmRandFloat(0.0, 1.0));
      rmSetAreaWarnFailure(elevID, false);
      rmSetAreaBaseHeight(elevID, rmRandFloat(2.0, 4.0));
      rmAddAreaConstraint(elevID, avoidBuildings);
      rmSetAreaMinBlobs(elevID, 1);
      rmSetAreaMaxBlobs(elevID, 3);
      rmSetAreaMinBlobDistance(elevID, 16.0);
      rmSetAreaMaxBlobDistance(elevID, 20.0);
      rmSetAreaCoherence(elevID, 0.0);

      if(rmBuildArea(elevID)==false)
      {
         // Stop trying once we fail 3 times in a row.
         failCount++;
         if(failCount==3)
            break;
      }
      else
         failCount=0;
   }

   // Elev.
   numTries=10*cNumberNonGaiaPlayers;
   failCount=0;
   for(i=0; <numTries)
   {
      elevID=rmCreateArea("elev"+i);
      rmSetAreaSize(elevID, rmAreaTilesToFraction(15), rmAreaTilesToFraction(120));
      rmSetAreaLocation(elevID, rmRandFloat(0.0, 1.0), rmRandFloat(0.0, 1.0));
      rmSetAreaWarnFailure(elevID, false);
      rmAddAreaConstraint(elevID, avoidBuildings);
      rmSetAreaBaseHeight(elevID, rmRandFloat(3.0, 4.0));
      rmSetAreaMinBlobs(elevID, 1);
      rmSetAreaMaxBlobs(elevID, 5);
      rmSetAreaMinBlobDistance(elevID, 16.0);
      rmSetAreaMaxBlobDistance(elevID, 40.0);
      rmSetAreaCoherence(elevID, 0.0);

      if(rmBuildArea(elevID)==false)
      {
         // Stop trying once we fail 3 times in a row.
         failCount++;
         if(failCount==3)
            break;
      }
      else
         failCount=0;
   }

   // Straggler trees.
   rmPlaceObjectDefPerPlayer(stragglerTreeID, false, rmRandInt(2, 5));

   // Gold
   rmPlaceObjectDefPerPlayer(startingGoldID, false);

   // cows
   rmPlaceObjectDefPerPlayer(closeCowsID, true);
   
   // chickens and berries   
   rmPlaceObjectDefPerPlayer(closeChickensID, false);

   rmPlaceObjectDefPerPlayer(closeBerriesID, false);

   // Elk
	rmPlaceObjectDefPerPlayer(closeElkID, false);
      
 // Ruins
   int ruinID=0;
   int columnID=0;
   int relicID=0;
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 5.0);
   int avoidRuins=rmCreateTypeDistanceConstraint("ruin vs ruin", "relic", 60.0);
   int stayInRuins=rmCreateEdgeDistanceConstraint("stay in ruins", ruinID, 4.0);

   for(i=0; <2*cNumberNonGaiaPlayers)
   {
      ruinID=rmCreateArea("ruins "+i);
      rmSetAreaSize(ruinID, rmAreaTilesToFraction(120), rmAreaTilesToFraction(180));
      rmSetAreaTerrainType(ruinID, "wol pavements\3");
      rmAddAreaTerrainLayer(ruinID, "rockies\ground3_roc", 0, 1);
      rmSetAreaMinBlobs(ruinID, 1);
      rmSetAreaMaxBlobs(ruinID, 2);
      rmSetAreaWarnFailure(ruinID, false); 
      rmSetAreaMinBlobDistance(ruinID, 16.0);
      rmSetAreaMaxBlobDistance(ruinID, 40.0);
      rmSetAreaCoherence(ruinID, 0.8);
      rmSetAreaSmoothDistance(ruinID, 10);
      rmAddAreaConstraint(ruinID, avoidAll);
      rmAddAreaConstraint(ruinID, avoidRuins);
      rmAddAreaConstraint(ruinID, stayInRuins);
      rmAddAreaConstraint(ruinID, avoidBuildings);
      rmAddAreaConstraint(ruinID, farStartingSettleConstraint);

      rmBuildArea(ruinID);
    
      columnID=rmCreateObjectDef("columns "+i);
      rmAddObjectDefItem(columnID, "ruins", rmRandInt(0,1), 0.0);
      rmAddObjectDefItem(columnID, "columns broken", rmRandInt(2,5), 4.0);
      rmAddObjectDefItem(columnID, "columns", rmRandFloat(0,2), 4.0);
      rmAddObjectDefItem(columnID, "rock limestone small", rmRandInt(1,3), 4.0);
      rmAddObjectDefItem(columnID, "rock limestone sprite", rmRandInt(6,12), 6.0);
      rmAddObjectDefItem(columnID, "grass", rmRandFloat(3,6), 4.0);
      rmSetObjectDefMinDistance(columnID, 0.0);
      rmSetObjectDefMaxDistance(columnID, 0.0);
      rmPlaceObjectDefInArea(columnID, 0, rmAreaID("ruins "+i), 1);

      relicID=rmCreateObjectDef("relics "+i);
      rmAddObjectDefItem(relicID, "relic", 1, 0.0);
      rmSetObjectDefMinDistance(relicID, 0.0);
      rmSetObjectDefMaxDistance(relicID, 0.0);
      rmAddObjectDefConstraint(relicID, avoidAll);
      rmAddObjectDefConstraint(relicID, stayInRuins);
      rmPlaceObjectDefInArea(relicID, 0, rmAreaID("ruins "+i), 1);

      if(rmGetNumberUnitsPlaced(relicID) < 1)
      {
         rmEchoInfo("---------------------failed to place relicID in ruins "+i+". So just dropping backup Relic.");
         rmSetAreaSize(ruinID, rmAreaTilesToFraction(50), rmAreaTilesToFraction(100));
         int backupRelicID=rmCreateObjectDef("backup relic "+i);
         rmAddObjectDefItem(backupRelicID, "relic", 1, 0.0);
         rmSetObjectDefMinDistance(backupRelicID, 0.0);
         rmSetObjectDefMaxDistance(backupRelicID, rmXFractionToMeters(0.5));
         rmAddObjectDefConstraint(backupRelicID, avoidRuins);
         rmAddObjectDefConstraint(backupRelicID, farStartingSettleConstraint);
         rmPlaceObjectDefAtLoc(backupRelicID, 0, 0.5, 0.5, 1);
      }

   }

   // Medium things....
   // Gold
   rmPlaceObjectDefPerPlayer(mediumGoldID, false, rmRandInt(1, 2));

   // Herds.
   rmPlaceObjectDefPerPlayer(mediumCowID, false); 

   // Deer.
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefAtLoc(mediumDeerID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
            
   // Far things.

   // Gold.
   rmPlaceObjectDefPerPlayer(farGoldID, false, rmRandInt(3, 4));

   // Bonus huntable.
   rmPlaceObjectDefPerPlayer(bonusHuntableID, false, rmRandInt(1, 2));

   // Herds.
   rmPlaceObjectDefPerPlayer(farCowID, false, rmRandInt(1, 2));
   
   // Forest.
   int classForest=rmDefineClass("forest");
   int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 8.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest v forest", rmClassID("forest"), 12.0);
   int forestSettleConstraint=rmCreateClassDistanceConstraint("forest settle", rmClassID("starting settlement"), 30.0);
   int count=0;
   numTries=20*cNumberNonGaiaPlayers;
   failCount=0;
   for(i=0; <numTries)
   {
      int forestID=rmCreateArea("forest"+i);
      rmSetAreaSize(forestID, rmAreaTilesToFraction(rmRandInt(600,1200)), rmAreaTilesToFraction(rmRandInt(600,1200)));
      rmSetAreaWarnFailure(forestID, false);
      rmSetAreaForestType(forestID, "NW Territory Forest");
      rmAddAreaConstraint(forestID, forestSettleConstraint);
      rmAddAreaConstraint(forestID, forestObjConstraint);
      rmAddAreaConstraint(forestID, forestConstraint);
      rmAddAreaToClass(forestID, classForest);
      
      rmSetAreaMinBlobs(forestID, 3);
      rmSetAreaMaxBlobs(forestID, 8);
      rmSetAreaMinBlobDistance(forestID, 16.0);
      rmSetAreaMaxBlobDistance(forestID, 40.0);
      rmSetAreaCoherence(forestID, 0.0);

      // Hill trees?
      if(rmRandFloat(0.0, 1.0)<0.2)
         rmSetAreaBaseHeight(forestID, rmRandFloat(3.0, 4.0));

      if(rmBuildArea(forestID)==false)
      {
         // Stop trying once we fail 10 times in a row.
         failCount++;
         if(failCount==10)
            break;
      }
      else
         failCount=0;
   }

   // Text
   rmSetStatusText("",0.60);

   // Random trees
   rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 25*cNumberNonGaiaPlayers);

   
   // Text
   rmSetStatusText("",0.80);

   // Rocks
   int rockID=rmCreateObjectDef("rock");
   rmAddObjectDefItem(rockID, "andes_grassrock_a", 1, 0.0);
   rmSetObjectDefMinDistance(rockID, 0.0);
   rmSetObjectDefMaxDistance(rockID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(rockID, avoidAll);
   rmAddObjectDefConstraint(rockID, avoidImpassableLand);
   rmPlaceObjectDefAtLoc(rockID, 0, 0.5, 0.5, 30*cNumberNonGaiaPlayers);

   // Logs
   int logID=rmCreateObjectDef("log");
   rmAddObjectDefItem(logID, "UnderbrushRockies", 1, 0.0);
   rmSetObjectDefMinDistance(logID, 0.0);
   rmSetObjectDefMaxDistance(logID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(logID, avoidAll);
   rmAddObjectDefConstraint(logID, avoidImpassableLand);
   rmAddObjectDefConstraint(logID, avoidBuildings);
   rmPlaceObjectDefAtLoc(logID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);


   // Text
   rmSetStatusText("",1.00);


  // King of the Hill (added 2026-11 for WoL): the middle of all start positions (the map centre), on open land
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
        rmPlaceObjectDefAtLoc(kothHillNear, 0, kothX, kothZ, 1);
        if (rmGetNumberUnitsPlaced(kothHillNear) > 0)
          break;
        kothRadius = kothRadius * 1.5;
      }
    }
  }

}  
