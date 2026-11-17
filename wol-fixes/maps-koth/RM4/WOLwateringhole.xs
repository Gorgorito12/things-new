include "ypKOTHInclude.xs";
// WATERING HOLE

// Main entry point for random map script
void main(void)
{

   // Text
   rmSetStatusText("",0.01);

   // Set size.
   int playerTiles=9000;
   if(cMapSize == 1)
   {
      playerTiles = 11700;
      rmEchoInfo("Large map");
   }
   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles/0.9);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

	// Picks a default water height
	rmSetSeaLevel(1.0);
	rmSetLightingSet("Mongolia");

   // Picks default terrain and water
	rmSetSeaType("savannah");
	rmSetBaseTerrainMix("great plains drygrass");
//	rmTerrainInitialize("great_plains\ground3_gp", 6.0);
   rmTerrainInitialize("water");

	rmSetMapType("grass");
	rmSetMapType("land");
	rmSetMapType("AFRICANsavannah");
	rmSetWorldCircleConstraint(true);
	rmSetWindMagnitude(2.0);

   // Define some classes.


	int classPlayer=rmDefineClass("player");
   int classIsland=rmDefineClass("island");

   int classBonusIsland=rmDefineClass("bonus island");
   int classPlayerCore=rmDefineClass("player core");
   rmDefineClass("corner");
   rmDefineClass("starting settlement");
   rmDefineClass("center");

   
   // Create a edge of map constraint.
   int edgeConstraint=rmCreateBoxConstraint("edge of map", rmXTilesToFraction(1), rmZTilesToFraction(1), 1.0-rmXTilesToFraction(1), 1.0-rmZTilesToFraction(1));
   int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(8), rmZTilesToFraction(8), 1.0-rmXTilesToFraction(8), 1.0-rmZTilesToFraction(8), 0.01);
   int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 40.0);

   // Player area constraint.
   int islandConstraint=rmCreateClassDistanceConstraint("stay away from islands", classIsland, 20.0);
   int coreBonusConstraint=rmCreateClassDistanceConstraint("core v bonus island", classPlayerCore, 50.0);
   int playerConstraint=rmCreateClassDistanceConstraint("bonus Settlement stay away from players", classPlayer, 10);

   // Bonus area constraint.
   int bonusIslandConstraint=rmCreateClassDistanceConstraint("avoid bonus island", classBonusIsland, 15.0);
   int bonusIslandEdgeConstraint=rmCreateBoxConstraint("bonus island avoids edge", rmXTilesToFraction(30), rmZTilesToFraction(30), 1.0-rmXTilesToFraction(30), 1.0-rmZTilesToFraction(30)); 

   // corner constraint.
   int cornerConstraint=rmCreateClassDistanceConstraint("stay away from corner", rmClassID("corner"), 15.0);
   int cornerOverlapConstraint=rmCreateClassDistanceConstraint("don't overlap corner", rmClassID("corner"), 2.0);

   // Settlement constraint.
   int avoidSettlement=rmCreateTypeDistanceConstraint("avoid settlement", "AbstractTownCenter", 50.0);
   int shortAvoidSettlement=rmCreateTypeDistanceConstraint("short avoid settlement", "AbstractTownCenter", 10.0);
   int farAvoidSettlement=rmCreateTypeDistanceConstraint("TCs avoid TCs by long distance", "AbstractTownCenter", 50.0);

   // Far starting settlement constraint.
   int farStartingSettleConstraint=rmCreateClassDistanceConstraint("far start settle", rmClassID("starting settlement"), 50.0);

   // Tower constraint.
   int avoidTower=rmCreateTypeDistanceConstraint("avoid tower", "tower", 25.0);

   // Gold
   int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "gold", 30.0);
   int shortAvoidGold=rmCreateTypeDistanceConstraint("short avoid gold", "gold", 10.0);

   // ypWaterBuffalos/ypWaterBuffalos
   int avoidHerdable=rmCreateTypeDistanceConstraint("avoid herdable", "herdable", 20.0);

   // Bonus huntable
   int classBonusHuntable=rmDefineClass("bonus huntable");
   int avoidBonusHuntable=rmCreateClassDistanceConstraint("avoid bonus huntable", classBonusHuntable, 15.0);
   int avoidFood=rmCreateTypeDistanceConstraint("avoid other food sources", "food", 6.0);
   int avoidFoodFar=rmCreateTypeDistanceConstraint("avoid food by more", "food", 20.0);
   int avoidPredator=rmCreateTypeDistanceConstraint("avoid predator", "animalPredator", 20.0);

   // Avoid impassable land
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 10.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 5.0);
   int tinyAvoidImpassableLand=rmCreateTerrainDistanceConstraint("tiny avoid impassable land", "Land", false, 2.0);
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);
   int farAvoidImpassableLand=rmCreateTerrainDistanceConstraint("far avoid impassable land", "land", false, 20.0);

      // Stay near shore
   int nearShore=rmCreateTerrainMaxDistanceConstraint("near shore", "land", false, 6.0);



   // note - try and trim down on the number of these. Many must be redundant.


 // -------------Define objects
   // Close Objects

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
   rmSetObjectDefMinDistance(startingUnits, 5.0);
   rmSetObjectDefMaxDistance(startingUnits, 10.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);

	int startingUnitsID= rmCreateObjectDef("starting settlement");
	if ( rmGetNomadStart())
	{
		rmAddObjectDefItem(startingUnitsID, "CoveredWagon", 1, 0.0);
	}
	else
	{
		rmAddObjectDefItem(startingUnitsID, "TownCenter", 1, 0.0);
		// Give it a little wiggle room for maps with greater than four players
		if ( cNumberNonGaiaPlayers > 4 )
		{
			rmSetObjectDefMinDistance(startingUnitsID, 0.0);
			rmSetObjectDefMaxDistance(startingUnitsID, 6.0);
		}
	}

   // towers avoid other towers
   int startingTowerID=rmCreateObjectDef("Starting tower");
   rmAddObjectDefItem(startingTowerID, "Market", 1, 5.0);
   rmSetObjectDefMinDistance(startingTowerID, 22.0);
   rmSetObjectDefMaxDistance(startingTowerID, 28.0);
   rmAddObjectDefConstraint(startingTowerID, avoidTower);

   // towers avoid other towers
   int startingTower2ID=rmCreateObjectDef("Starting tower2");
   rmAddObjectDefItem(startingTower2ID, "Outpost", 1, 0.0);
/*   rmAddObjectDefItem(startingTower2ID, "gnu", 6.0, 4.0); */
/* gnu were placed as player's */
   rmSetObjectDefMinDistance(startingTower2ID, 22.0);
   rmSetObjectDefMaxDistance(startingTower2ID, 28.0);
   rmAddObjectDefConstraint(startingTower2ID, avoidTower);

   // gold avoids gold
   int startingGoldID=rmCreateObjectDef("Starting gold");
   rmAddObjectDefItem(startingGoldID, "mine", 1, 0.0);
   rmSetObjectDefMinDistance(startingGoldID, 20.0);
   rmSetObjectDefMaxDistance(startingGoldID, 25.0);
   rmAddObjectDefConstraint(startingGoldID, avoidGold);
   rmAddObjectDefConstraint(startingGoldID, avoidImpassableLand);
   
   int startingNuggetID=rmCreateObjectDef("Starting nugget");
   rmAddObjectDefItem(startingNuggetID, "Nugget", 1, 0.0);
   rmSetObjectDefMinDistance(startingNuggetID, 20.0);
   rmSetObjectDefMaxDistance(startingNuggetID, 25.0);
   rmAddObjectDefConstraint(startingNuggetID, avoidGold);
   rmAddObjectDefConstraint(startingNuggetID, avoidImpassableLand);

   int closeypWaterBuffalosID=rmCreateObjectDef("close ypWaterBuffalos");
   rmAddObjectDefItem(closeypWaterBuffalosID, "ypWaterBuffalo", rmRandInt(0,2), 2.0);
   rmSetObjectDefMinDistance(closeypWaterBuffalosID, 25.0);
   rmSetObjectDefMaxDistance(closeypWaterBuffalosID, 30.0);
   rmAddObjectDefConstraint(closeypWaterBuffalosID, avoidImpassableLand);
   rmAddObjectDefConstraint(closeypWaterBuffalosID, avoidFood);

   int closegnuID=rmCreateObjectDef("close gnus");
   rmAddObjectDefItem(closegnuID, "gnu", rmRandInt(3,8), 4.0);
   rmSetObjectDefMinDistance(closegnuID, 25.0);
   rmSetObjectDefMaxDistance(closegnuID, 30.0);
   rmAddObjectDefConstraint(closegnuID, avoidImpassableLand);
   rmAddObjectDefConstraint(closegnuID, avoidFood);

   int closeHippoID=rmCreateObjectDef("close Hippo");
   float hippoNumber=rmRandFloat(0, 1);
   if(hippoNumber<0.3)
      rmAddObjectDefItem(closeHippoID, "hippo", 2, 1.0);
   else if(hippoNumber<0.6)
      rmAddObjectDefItem(closeHippoID, "hippo", 3, 4.0);
   else 
      rmAddObjectDefItem(closeHippoID, "hippo", 2, 1.0);
   rmSetObjectDefMinDistance(closeHippoID, 30.0);
   rmSetObjectDefMaxDistance(closeHippoID, 50.0);
   rmAddObjectDefConstraint(closeHippoID, avoidImpassableLand);
   
   int stragglerTreeID=rmCreateObjectDef("straggler tree");
   rmAddObjectDefItem(stragglerTreeID, "TreeTexas", 1, 0.0);
   rmSetObjectDefMinDistance(stragglerTreeID, 12.0);
   rmSetObjectDefMaxDistance(stragglerTreeID, 15.0);
   rmAddObjectDefConstraint(stragglerTreeID, avoidImpassableLand);

   // medium objects

   // Text
   rmSetStatusText("",0.20);

   // gold avoids gold and Settlements
   int mediumGoldID=rmCreateObjectDef("medium gold");
   rmAddObjectDefItem(mediumGoldID, "mine", 1, 0.0);
   rmSetObjectDefMinDistance(mediumGoldID, 40.0);
   rmSetObjectDefMaxDistance(mediumGoldID, 60.0);
   rmAddObjectDefConstraint(mediumGoldID, avoidGold);
   rmAddObjectDefConstraint(mediumGoldID, edgeConstraint);
   rmAddObjectDefConstraint(mediumGoldID, farStartingSettleConstraint);
   rmAddObjectDefConstraint(mediumGoldID, avoidImpassableLand);

   int mediumypWaterBuffalosID=rmCreateObjectDef("medium ypWaterBuffalos");
   rmAddObjectDefItem(mediumypWaterBuffalosID, "ypWaterBuffalo", rmRandInt(2,3), 4.0);
   rmSetObjectDefMinDistance(mediumypWaterBuffalosID, 50.0);
   rmSetObjectDefMaxDistance(mediumypWaterBuffalosID, 70.0);
   rmAddObjectDefConstraint(mediumypWaterBuffalosID, avoidImpassableLand);
   rmAddObjectDefConstraint(mediumypWaterBuffalosID, avoidFoodFar);
   rmAddObjectDefConstraint(mediumypWaterBuffalosID, farStartingSettleConstraint);

   // For this map, pick how many zebra/gnu in a grouping.  Assign this
   // to both zebra and gnu since we place them interchangeably per player.
   int numHuntable=rmRandInt(6, 10);

   int mediumgnuID=rmCreateObjectDef("medium gnus");
   rmAddObjectDefItem(mediumgnuID, "gnu", numHuntable, 4.0);
   rmSetObjectDefMinDistance(mediumgnuID, 40.0);
   rmSetObjectDefMaxDistance(mediumgnuID, 80.0);
   rmAddObjectDefConstraint(mediumgnuID, avoidImpassableLand);
   rmAddObjectDefConstraint(mediumgnuID, farStartingSettleConstraint);

   int mediumZebraID=rmCreateObjectDef("medium zebra");
   rmAddObjectDefItem(mediumZebraID, "zebra", numHuntable, 4.0);
   rmSetObjectDefMinDistance(mediumZebraID, 40.0);
   rmSetObjectDefMaxDistance(mediumZebraID, 80.0);
   rmAddObjectDefConstraint(mediumZebraID, avoidImpassableLand);
   rmAddObjectDefConstraint(mediumZebraID, farStartingSettleConstraint);

   // far objects

   // gold avoids gold, Settlements and TCs
   int farGoldID=rmCreateObjectDef("far gold");
   rmAddObjectDefItem(farGoldID, "MineGold", 1, 0.0);
   rmSetObjectDefMinDistance(farGoldID, 80.0);
   rmSetObjectDefMaxDistance(farGoldID, 100.0);
   rmAddObjectDefConstraint(farGoldID, avoidGold);
   rmAddObjectDefConstraint(farGoldID, edgeConstraint);
   rmAddObjectDefConstraint(farGoldID, shortAvoidSettlement);
   rmAddObjectDefConstraint(farGoldID, avoidImpassableLand);

   // gold avoids gold, Settlements and TCs
   int bonusGoldID=rmCreateObjectDef("gold on bonus islands");
   rmAddObjectDefItem(bonusGoldID, "MineGold", 1, 0.0);
   rmSetObjectDefMinDistance(bonusGoldID, 90.0);
   rmSetObjectDefMaxDistance(bonusGoldID, 180.0);
   rmAddObjectDefConstraint(bonusGoldID, shortAvoidGold);
   rmAddObjectDefConstraint(bonusGoldID, edgeConstraint);
   rmAddObjectDefConstraint(bonusGoldID, shortAvoidSettlement);
   rmAddObjectDefConstraint(bonusGoldID, playerConstraint);
   rmAddObjectDefConstraint(bonusGoldID, avoidImpassableLand);

   int farypWaterBuffalosID=rmCreateObjectDef("far ypWaterBuffalos");
   rmAddObjectDefItem(farypWaterBuffalosID, "ypWaterBuffalo", rmRandInt(1,2), 4.0);
   rmSetObjectDefMinDistance(farypWaterBuffalosID, 80.0);
   rmSetObjectDefMaxDistance(farypWaterBuffalosID, 150.0);
   rmAddObjectDefConstraint(farypWaterBuffalosID, avoidHerdable);
   rmAddObjectDefConstraint(farypWaterBuffalosID, shortAvoidImpassableLand);






   // pick lions or hyenas as predators
   // avoid TCs
   int farPredatorID=rmCreateObjectDef("far predator");
   float predatorSpecies=rmRandFloat(0, 1);
   if(predatorSpecies<0.5)   
      rmAddObjectDefItem(farPredatorID, "ypLion", 2, 4.0);
   else
      rmAddObjectDefItem(farPredatorID, "ypLion", 3, 2.0);
   rmSetObjectDefMinDistance(farPredatorID, 50.0);
   rmSetObjectDefMaxDistance(farPredatorID, 100.0);
   rmAddObjectDefConstraint(farPredatorID, avoidPredator);
   rmAddObjectDefConstraint(farPredatorID, farStartingSettleConstraint);
   rmAddObjectDefConstraint(farPredatorID, shortAvoidImpassableLand);

   int farCrocsID=rmCreateObjectDef("far Crocs");
   rmAddObjectDefItem(farCrocsID, "Crocodile", rmRandInt(1,2), 0.0);
   rmSetObjectDefMinDistance(farCrocsID, 50.0);
   rmSetObjectDefMaxDistance(farCrocsID, 100.0);
   rmAddObjectDefConstraint(farCrocsID, farStartingSettleConstraint);
   rmAddObjectDefConstraint(farCrocsID, nearShore);
   // try and place near water

   int numCrane=rmRandInt(6, 8);
   int farCraneID=rmCreateObjectDef("far Crane");
   rmAddObjectDefItem(farCraneID, "Ostrich", numCrane, 3.0);
   rmSetObjectDefMinDistance(farCraneID, 50.0);
   rmSetObjectDefMaxDistance(farCraneID, 150.0);
   rmAddObjectDefConstraint(farCraneID, farStartingSettleConstraint);
   rmAddObjectDefConstraint(farCraneID, nearShore);
      
   // Player huntable
   int avoidHuntable=rmCreateTypeDistanceConstraint("avoid huntable", "huntable", 20.0);
   int bonusHuntableID=rmCreateObjectDef("bonus huntable");
   float bonusChance=rmRandFloat(0, 1);
   if(bonusChance<0.5)   
      rmAddObjectDefItem(bonusHuntableID, "ypWildElephant", 2, 2.0);
   else if(bonusChance<0.75)
      rmAddObjectDefItem(bonusHuntableID, "giraffe", rmRandInt(3,4), 3.0);
   else
      rmAddObjectDefItem(bonusHuntableID, "hippo", rmRandInt(3,5), 3.0);
   rmAddObjectDefToClass(bonusHuntableID, classBonusHuntable);
   rmSetObjectDefMinDistance(bonusHuntableID, 0.0);
   rmSetObjectDefMaxDistance(bonusHuntableID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(bonusHuntableID, farStartingSettleConstraint);
   rmAddObjectDefConstraint(bonusHuntableID, avoidHuntable);
   rmAddObjectDefConstraint(bonusHuntableID, avoidBonusHuntable);
   rmAddObjectDefConstraint(bonusHuntableID, shortAvoidImpassableLand);
  
   // Bonus huntable 1
   int bonusHuntableID2=rmCreateObjectDef("bonus huntable2");
   bonusChance=rmRandFloat(0, 1);
   if(bonusChance<0.5)   
      rmAddObjectDefItem(bonusHuntableID2, "ypWildElephant", 2, 2.0);
   else if(bonusChance<0.75)
      {
         rmAddObjectDefItem(bonusHuntableID2, "Okapi", rmRandInt(5,6), 3.0);
         if(rmRandFloat(0,1)<0.5)      
            rmAddObjectDefItem(bonusHuntableID2, "zebra", rmRandInt(2,4), 3.0);
      }
   else
      rmAddObjectDefItem(bonusHuntableID2, "gnu", rmRandInt(6,9), 4.0);
   rmSetObjectDefMinDistance(bonusHuntableID2, 0.0);
   rmSetObjectDefMaxDistance(bonusHuntableID2, rmXFractionToMeters(0.5));
   rmAddObjectDefToClass(bonusHuntableID2, classBonusHuntable);
   rmAddObjectDefConstraint(bonusHuntableID2, farStartingSettleConstraint);
   rmAddObjectDefConstraint(bonusHuntableID2, nearShore);

   // Bonus huntable 2
   int bonusHuntableID3=rmCreateObjectDef("bonus huntable3");
   bonusChance=rmRandFloat(0, 1);
   if(bonusChance<0.5)   
      rmAddObjectDefItem(bonusHuntableID3, "hippo", 3, 2.0);
   else if(bonusChance<0.75)
      {
         rmAddObjectDefItem(bonusHuntableID3, "zebra", rmRandInt(4,6), 3.0);
         if(rmRandFloat(0,1)<0.5)      
            rmAddObjectDefItem(bonusHuntableID3, "giraffe", rmRandInt(2,4), 4.0);
      }
   else
      rmAddObjectDefItem(bonusHuntableID3, "ypWildElephant", 4, 3.0);
   rmSetObjectDefMinDistance(bonusHuntableID3, 0.0);
   rmSetObjectDefMaxDistance(bonusHuntableID3, rmXFractionToMeters(0.5));
   rmAddObjectDefToClass(bonusHuntableID3, classBonusHuntable);
   rmAddObjectDefConstraint(bonusHuntableID3, farStartingSettleConstraint);


   int randomTreeID=rmCreateObjectDef("random tree");
   rmAddObjectDefItem(randomTreeID, "TreeTexas", 1, 0.0);
   rmSetObjectDefMinDistance(randomTreeID, 0.0);
   rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTreeID, rmCreateTypeDistanceConstraint("random tree", "all", 4.0));
   rmAddObjectDefConstraint(randomTreeID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(randomTreeID, shortAvoidSettlement);

   int randomTreeID2=rmCreateObjectDef("random tree 2");
   rmAddObjectDefItem(randomTreeID2, "TreeCaribbean", 1, 0.0);
   rmSetObjectDefMinDistance(randomTreeID2, 0.0);
   rmSetObjectDefMaxDistance(randomTreeID2, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTreeID2, rmCreateTypeDistanceConstraint("random tree two", "all", 4.0));
   rmAddObjectDefConstraint(randomTreeID2, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(randomTreeID2, shortAvoidSettlement);

   int randomNuggetID=rmCreateObjectDef("random nugget");
   rmAddObjectDefItem(randomNuggetID, "Nugget", 1, 0.0);
   rmSetObjectDefMinDistance(randomNuggetID, 0.0);
   rmSetObjectDefMaxDistance(randomNuggetID, rmXFractionToMeters(0.35));
   int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 34.0);
   rmAddObjectDefConstraint(randomNuggetID, avoidNugget);
   rmAddObjectDefConstraint(randomNuggetID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(randomNuggetID, shortAvoidSettlement);

   // --------------------------------------------------------------------------------------------Done defining objects

   // Create areas
    rmPlacePlayersCircular(0.4, 0.45, rmDegreesToRadians(5.0));

   int centerID=rmCreateArea("center");
   rmSetAreaSize(centerID, 0.01, 0.01);
   rmSetAreaLocation(centerID, 0.5, 0.5);
   rmAddAreaToClass(centerID, rmClassID("center"));
   rmBuildArea(centerID);

    // Create player cores so bonus islands avoid them
    for(i=1; <cNumberPlayers)
   {
      // Create the area.
      int id=rmCreateArea("Player core"+i);
      rmSetAreaSize(id, rmAreaTilesToFraction(200), rmAreaTilesToFraction(200));
      rmAddAreaToClass(id, classPlayerCore);
      rmSetAreaCoherence(id, 1.0);
      rmSetAreaLocPlayer(id, i);

      rmBuildArea(id);
   }

   // Create connections
   int shallowsID=rmCreateConnection("shallows");
   rmSetConnectionType(shallowsID, cConnectAreas, false, 1.0);
   rmSetConnectionWidth(shallowsID, 16, 2);
   rmSetConnectionWarnFailure(shallowsID, false);
   rmSetConnectionBaseHeight(shallowsID, 2.0);
   rmSetConnectionHeightBlend(shallowsID, 2.0);
   rmSetConnectionSmoothDistance(shallowsID, 3.0);
   rmAddConnectionTerrainReplacement(shallowsID, "great_plains\ground3_gp", "great_plains\ground3_gp"); /*riverSandyC */

   // Create extra connections
   int extraShallowsID=rmCreateConnection("extra shallows");
   if(cNumberPlayers < 5)
      rmSetConnectionType(extraShallowsID, cConnectAreas, false, 0.75);
   else if(cNumberPlayers < 7) 
      rmSetConnectionType(extraShallowsID, cConnectAreas, false, 0.30);
   rmSetConnectionWidth(extraShallowsID, 16, 2);
   rmSetConnectionWarnFailure(extraShallowsID, false); 
   rmSetConnectionBaseHeight(extraShallowsID, 2.0);
   rmSetConnectionHeightBlend(extraShallowsID, 2.0);
   rmSetConnectionSmoothDistance(extraShallowsID, 3.0);
   rmSetConnectionPositionVariance(extraShallowsID, -1.0); 
   rmAddConnectionTerrainReplacement(extraShallowsID, "great_plains\ground3_gp", "great_plains\ground3_gp"); 
   rmAddConnectionStartConstraint(extraShallowsID, coreBonusConstraint);
   rmAddConnectionEndConstraint(extraShallowsID, coreBonusConstraint);

  // Create team connections
   int teamShallowsID=rmCreateConnection("team shallows");
   rmSetConnectionType(teamShallowsID, cConnectAllies, false, 1.0);
   rmSetConnectionWarnFailure(teamShallowsID, false);
   rmSetConnectionWidth(teamShallowsID, 16, 2);
   rmSetConnectionBaseHeight(teamShallowsID, 2.0);
   rmSetConnectionHeightBlend(teamShallowsID, 2.0);
   rmSetConnectionSmoothDistance(teamShallowsID, 3.0);
   rmAddConnectionTerrainReplacement(teamShallowsID, "great_plains\ground3_gp", "great_plains\ground3_gp");

   // Build up some bonus islands.
   int bonusCount = rmRandInt(2, 3);
   int bonusIsleSize = 1800;

   if(cNumberNonGaiaPlayers > 5) 
   {
      bonusIsleSize = 3000;
      bonusCount = rmRandInt(3, 4);
   }   
   else if(cNumberNonGaiaPlayers > 8)
   {
      bonusIsleSize = 3000;
      bonusCount = rmRandInt(3, 4);
   }   
   else
   {
      bonusIsleSize = 3000;
      bonusCount = rmRandInt(3, 4);
   }   
   rmEchoInfo("number of bonus isles "+bonusCount+ "size of isles "+bonusIsleSize);
  
   for(i=0; <bonusCount)
   {
      int bonusIslandID=rmCreateArea("bonus island"+i);
      rmSetAreaSize(bonusIslandID, rmAreaTilesToFraction(bonusIsleSize*0.9), rmAreaTilesToFraction(bonusIsleSize*1.1));
      rmSetAreaTerrainType(bonusIslandID, "great_plains\ground8_gp");
      rmAddAreaTerrainLayer(bonusIslandID, "great_plains\ground8_gp", 0, 6); 
      rmSetAreaWarnFailure(bonusIslandID, false);
      if(rmRandFloat(0.0, 1.0)<0.70)
         rmAddAreaConstraint(bonusIslandID, bonusIslandConstraint);
      rmAddAreaConstraint(bonusIslandID, bonusIslandEdgeConstraint);
      rmAddAreaToClass(bonusIslandID, classIsland);
      rmAddAreaToClass(bonusIslandID, classBonusIsland);
      rmAddAreaConstraint(bonusIslandID, coreBonusConstraint);
      rmSetAreaCoherence(bonusIslandID, 0.25);
      rmSetAreaSmoothDistance(bonusIslandID, 12);
      rmSetAreaHeightBlend(bonusIslandID, 2);
      rmSetAreaBaseHeight(bonusIslandID, 2.0);
      rmAddConnectionArea(extraShallowsID, bonusIslandID);
      rmAddConnectionArea(shallowsID, bonusIslandID);
   }  

   rmBuildAllAreas();

   // Set up player areas.
   float playerFraction=rmAreaTilesToFraction(3500);
   for(i=1; <cNumberPlayers)
   {
      // Create the area.
      id=rmCreateArea("Player"+i);
      rmSetPlayerArea(i, id);
      rmSetAreaSize(id, 1.0, 1.0);
      rmAddAreaToClass(id, classIsland);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaWarnFailure(id, false);
      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 5);
      rmSetAreaMinBlobDistance(id, 5.0);
      rmSetAreaMaxBlobDistance(id, 10.0);
      rmSetAreaCoherence(id, 0.6);
      rmSetAreaBaseHeight(id, 2.0);
      rmSetAreaSmoothDistance(id, 10);
      rmSetAreaHeightBlend(id, 2);
      rmAddAreaConstraint(id, islandConstraint);
      rmAddAreaConstraint(id, cornerOverlapConstraint);
      rmAddAreaConstraint(id, bonusIslandConstraint);
      rmAddAreaConstraint(id, centerConstraint);
      rmSetAreaLocPlayer(id, i);
      rmAddConnectionArea(extraShallowsID, id);
      rmAddConnectionArea(shallowsID, id);
      rmSetAreaTerrainType(id, "great_plains\ground8_gp");
      rmAddAreaTerrainLayer(id, "great_plains\ground8_gp", 0, 12);
   }

   // Build all areas
   rmBuildAllAreas();
   rmBuildConnection(teamShallowsID);
   rmBuildConnection(shallowsID);
   if(cNumberNonGaiaPlayers < 4)
      rmBuildConnection(extraShallowsID);
   else if(cNumberNonGaiaPlayers < 6)
   {   
      if(rmRandFloat(0,1)<0.5)
         rmBuildConnection(extraShallowsID);
   }


   for(i=1; <cNumberPlayers*50)
   {
     // Beautification sub area.
     int id2=rmCreateArea("dirt patch"+i);
     rmSetAreaSize(id2, rmAreaTilesToFraction(20), rmAreaTilesToFraction(40));
     rmSetAreaTerrainType(id2, "great_plains\ground2_gp");
     rmSetAreaMinBlobs(id2, 1);
     rmSetAreaMaxBlobs(id2, 5);
     rmSetAreaMinBlobDistance(id2, 16.0);
     rmSetAreaMaxBlobDistance(id2, 40.0);
     rmSetAreaCoherence(id2, 0.0);
     rmAddAreaConstraint(id2, shortAvoidImpassableLand);
    rmBuildArea(id2); 
   }

   // Beautification sub area.
   for(i=1; <cNumberPlayers*15)
   {
        int id3=rmCreateArea("grass patch"+i);
        rmSetAreaSize(id3, rmAreaTilesToFraction(10), rmAreaTilesToFraction(50));
        rmSetAreaTerrainType(id3, "great_plains\ground2_gp");
        rmSetAreaMinBlobs(id3, 1);
        rmSetAreaMaxBlobs(id3, 5);
        rmSetAreaMinBlobDistance(id3, 16.0);
        rmSetAreaMaxBlobDistance(id3, 40.0);
        rmSetAreaCoherence(id3, 0.0);
        rmAddAreaConstraint(id3, shortAvoidImpassableLand);
        rmBuildArea(id3);
   } 
  
   rmPlaceObjectDefPerPlayer(startingUnitsID, true);
	for(i=1; < cNumberPlayers)
	{
		rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	}

    // Elev.
   int failCount=0;
   int numTries1=10*cNumberNonGaiaPlayers;
   int avoidBuildings=rmCreateTypeDistanceConstraint("avoid buildings", "Building", 10.0);
   for(i=0; <numTries1)
   {
      int elevID=rmCreateArea("elev"+i);
      rmSetAreaSize(elevID, rmAreaTilesToFraction(20), rmAreaTilesToFraction(80));
      rmSetAreaLocation(elevID, rmRandFloat(0.0, 1.0), rmRandFloat(0.0, 1.0));
      rmSetAreaWarnFailure(elevID, false); 
      rmAddAreaConstraint(elevID, avoidBuildings);
      rmAddAreaConstraint(elevID, shortAvoidImpassableLand);
      if(rmRandFloat(0.0, 1.0)<0.7)
         rmSetAreaTerrainType(elevID, "great_plains\ground3_gp");
      rmSetAreaBaseHeight(elevID, rmRandFloat(2.0, 4.0));
      rmSetAreaHeightBlend(elevID, 1);
      rmSetAreaMinBlobs(elevID, 1);
      rmSetAreaMaxBlobs(elevID, 3);
      rmSetAreaMinBlobDistance(elevID, 16.0);
      rmSetAreaMaxBlobDistance(elevID, 40.0);
      rmSetAreaCoherence(elevID, 0.0); 

      if(rmBuildArea(elevID)==false)
      {
         // Stop trying once we fail 6 times in a row.
         failCount++;
         if(failCount==6)
            break;
      }
      else
         failCount=0; 
   }

   // Text
   rmSetStatusText("",0.40);



   // Towers.
   rmPlaceObjectDefPerPlayer(startingTowerID, true, 1);
   rmPlaceObjectDefPerPlayer(startingTower2ID, true, 0);

   // Straggler trees.
   rmPlaceObjectDefPerPlayer(stragglerTreeID, false, rmRandInt(0, 7));

   // Gold
   rmPlaceObjectDefPerPlayer(startingGoldID, false);

   // Starting Nugget
   rmSetNuggetDifficulty(1, 1);
   rmPlaceObjectDefPerPlayer(startingNuggetID, false);

    // ypWaterBuffalos
   rmPlaceObjectDefPerPlayer(closeypWaterBuffalosID, true);

   // gnu
   rmPlaceObjectDefPerPlayer(closegnuID, false); 

   // Hippo.
   rmPlaceObjectDefPerPlayer(closeHippoID, false);

   // Medium things....
   // Gold
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(mediumGoldID, 0, rmAreaID("player"+i));

   // ypWaterBuffalos
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(mediumypWaterBuffalosID, 0, rmAreaID("player"+i));

   // gnu or zebra.  Flip a coin.
   if(rmRandFloat(0.0, 1.0)<0.5)   
   {
      for(i=1; <cNumberPlayers)
         rmPlaceObjectDefInArea(mediumgnuID, 0, rmAreaID("player"+i));
   }
   else if(rmRandFloat(0,1)<0.2)
   {
      for(i=1; <cNumberPlayers)
      {
        rmPlaceObjectDefInArea(mediumgnuID, 0, rmAreaID("player"+i));
        rmPlaceObjectDefInArea(mediumZebraID, 0, rmAreaID("player"+i));
      }
   }
   else
   {
      for(i=1; <cNumberPlayers)
         rmPlaceObjectDefInArea(mediumZebraID, 0, rmAreaID("player"+i));
   }

      
   // Far things.

   // Player Far Gold, need goldNum since it randomizes for each i
   int goldNum = rmRandInt(1,2);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(farGoldID, false, rmAreaID("player"+i), goldNum);
  
  // Bonus Gold
   rmPlaceObjectDefPerPlayer(bonusGoldID, false, rmRandInt(1,2));



   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(farCrocsID, false, rmAreaID("player"+i));

   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(farCraneID, false, rmAreaID("player"+i));

   // Bonus huntable
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(bonusHuntableID, false, rmAreaID("player"+i));
  
    // Bonus huntable
   for(i=1; <bonusCount)
   {
      rmPlaceObjectDefInArea(bonusHuntableID2, false, rmAreaID("bonus island"+i));
      rmPlaceObjectDefInArea(bonusHuntableID3, false, rmAreaID("bonus island"+i));
   }
   
   // ypWaterBuffalos
   int ypWaterBuffaloNum = rmRandInt(1,2);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(farypWaterBuffalosID, false, rmAreaID("player"+i), ypWaterBuffaloNum);

   // Predators
   rmPlaceObjectDefPerPlayer(farPredatorID, false, 2);

   // Text
   rmSetStatusText("",0.60);

   // Random trees.
   rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);

   rmPlaceObjectDefAtLoc(randomTreeID2, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
   
   /// Forest.
   int classForest=rmDefineClass("forest");
   int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest v forest", rmClassID("forest"), 16.0);
   int forestSettleConstraint=rmCreateClassDistanceConstraint("forest settle", rmClassID("starting settlement"), 20.0);
   int forestCount=10*cNumberNonGaiaPlayers;
   failCount=0;
   for(i=0; <forestCount)
   {
      int forestID=rmCreateArea("forest"+i);
      rmSetAreaSize(forestID, rmAreaTilesToFraction(50), rmAreaTilesToFraction(100));
      rmSetAreaWarnFailure(forestID, false);
      if(rmRandFloat(0,1)<0.8)
         rmSetAreaForestType(forestID, "Savannah Forest");
      else
         rmSetAreaForestType(forestID, "Savannah Forest Palm");
      rmAddAreaConstraint(forestID, forestSettleConstraint);
      rmAddAreaConstraint(forestID, forestObjConstraint);
      rmAddAreaConstraint(forestID, forestConstraint);
      rmAddAreaConstraint(forestID, avoidImpassableLand);
      rmAddAreaToClass(forestID, classForest);
      
      rmSetAreaMinBlobs(forestID, 2);
      rmSetAreaMaxBlobs(forestID, 4);
      rmSetAreaMinBlobDistance(forestID, 16.0);
      rmSetAreaMaxBlobDistance(forestID, 20.0);
      rmSetAreaCoherence(forestID, 0.0);

      // Hill trees?
      if(rmRandFloat(0.0, 1.0)<0.2)
         rmSetAreaBaseHeight(forestID, rmRandFloat(3.0, 4.0));

      if(rmBuildArea(forestID)==false)
      {
         // Stop trying once we fail 3 times in a row.
         failCount++;
         if(failCount==3)
            break;
      }
      else
         failCount=0;
   }

   // Random Nugget.
   rmSetNuggetDifficulty(2, 3);
   rmPlaceObjectDefAtLoc(randomNuggetID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);

   // Text
   rmSetStatusText("",0.80);

   // Bushes
   int bushID=rmCreateObjectDef("big bush patch");
   rmAddObjectDefItem(bushID, "TreeGreatPlainsGrass", 4, 3.0);
   rmSetObjectDefMinDistance(bushID, 0.0);
   rmSetObjectDefMaxDistance(bushID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(bushID, avoidAll);
   rmPlaceObjectDefAtLoc(bushID, 0, 0.5, 0.5, 25*cNumberNonGaiaPlayers);



   // Text
   rmSetStatusText("",0.90);

   int rockID=rmCreateObjectDef("rock small");
   rmAddObjectDefItem(rockID, "UnderbrushTexas", 3, 2.0);
   rmAddObjectDefItem(rockID, "TreeGreatPlainsGrass", 4, 3.0);
   rmSetObjectDefMinDistance(rockID, 0.0);
   rmSetObjectDefMaxDistance(rockID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(rockID, avoidAll);
   rmAddObjectDefConstraint(rockID, avoidImpassableLand);
   rmPlaceObjectDefAtLoc(rockID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);

	// Perching Vultures - add four somewhere.
	int vultureID=rmCreateObjectDef("perching vultures");
	int avoidVultures=rmCreateTypeDistanceConstraint("avoid other vultures", "PropVulturePerching", 30.0);
	rmAddObjectDefItem(vultureID, "PropVulturePerching", 1, 0.0);
	rmSetObjectDefMinDistance(vultureID, 0.0);
	rmSetObjectDefMaxDistance(vultureID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(vultureID, avoidAll);
	rmAddObjectDefConstraint(vultureID, avoidVultures);
	rmPlaceObjectDefAtLoc(vultureID, 0, 0.5, 0.5, 4);
 
   int rockID2=rmCreateObjectDef("rock sprite");
   rmAddObjectDefItem(rockID2, "TreeGreatPlainsGrass", 1, 0.0);
   rmSetObjectDefMinDistance(rockID2, 0.0);
   rmSetObjectDefMaxDistance(rockID2, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(rockID2, avoidAll);
   rmAddObjectDefConstraint(rockID2, avoidImpassableLand);
   rmPlaceObjectDefAtLoc(rockID2, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers); 


  // Text
   rmSetStatusText("",1.0);


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
