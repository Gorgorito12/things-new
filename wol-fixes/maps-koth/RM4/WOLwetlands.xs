include "ypKOTHInclude.xs";
// Marsh

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
   int size=2*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

   // Set up default water.
   rmSetSeaLevel(0.0);
   rmSetSeaType("African Marsh");
	rmSetLightingSet("303a_atsea");

	// Make it rain
   rmSetGlobalRain( 0.7 );

   // Init map.
   rmTerrainInitialize("water");
//	rmSetLightingSet("Ghost Lake");

	rmSetMapType("africa");
	rmSetMapType("AFRICANjungle");
	rmSetMapType("AFRICANmarsh");

   // Define some classes.
   int classIsland=rmDefineClass("island");
   int classBonusIsland=rmDefineClass("bonus island");
   int classPlayerCore=rmDefineClass("player core");
   int classPlayer=rmDefineClass("player");
	int classForest=rmDefineClass("forest");
   rmDefineClass("corner");
   rmDefineClass("starting settlement");
   rmDefineClass("center");
   
   // Create a edge of map constraint.
   int edgeConstraint=rmCreateBoxConstraint("edge of map", rmXTilesToFraction(1), rmZTilesToFraction(1), 1.0-rmXTilesToFraction(1), 1.0-rmZTilesToFraction(1));
   int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(8), rmZTilesToFraction(8), 1.0-rmXTilesToFraction(8), 1.0-rmZTilesToFraction(8), 0.01);
   int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 60.0);
   int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.49), rmDegreesToRadians(0), rmDegreesToRadians(360));

   // Player area constraint.
   int islandConstraint=rmCreateClassDistanceConstraint("stay away from islands", classIsland, 20.0);
   int coreBonusConstraint=rmCreateClassDistanceConstraint("core v bonus island", classPlayerCore, 60.0);
   int playerConstraint=rmCreateClassDistanceConstraint("bonus Settlement stay away from players", classPlayer, 10);

   // Bonus area constraint.
   int bonusIslandConstraint=rmCreateClassDistanceConstraint("avoid bonus island", classBonusIsland, 15.0);
   int bonusIslandEdgeConstraint=rmCreateBoxConstraint("bonus island avoids edge", rmXTilesToFraction(30), rmZTilesToFraction(30), 1.0-rmXTilesToFraction(30), 1.0-rmZTilesToFraction(30)); 

   // corner constraint.
   int cornerConstraint=rmCreateClassDistanceConstraint("stay away from corner", rmClassID("corner"), 15.0);
   int cornerOverlapConstraint=rmCreateClassDistanceConstraint("don't overlap corner", rmClassID("corner"), 2.0);

   // Settlement constraint.
   int avoidSettlement=rmCreateTypeDistanceConstraint("avoid settlement", "AbstractTownCenter", 30.0);
   int shortAvoidSettlement=rmCreateTypeDistanceConstraint("short avoid settlement", "AbstractTownCenter", 10.0);
   int farAvoidSettlement=rmCreateTypeDistanceConstraint("TCs avoid TCs by long distance", "AbstractTownCenter", 50.0);

   // Far starting settlement constraint.
   int farStartingSettleConstraint=rmCreateClassDistanceConstraint("far start settle", rmClassID("starting settlement"), 50.0);

   // Tower constraint.
   int avoidTower=rmCreateTypeDistanceConstraint("avoid tower", "tower", 25.0);

	

   // Gold
   int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "gold", 30.0);
   int shortAvoidGold=rmCreateTypeDistanceConstraint("short avoid gold", "gold", 10.0);

   // Pigs/pigs
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
   int nearShore=rmCreateTerrainMaxDistanceConstraint("near shore", "water", true, 6.0);
	
	//Forest close constraint
	int closeForestConstraint=rmCreateClassDistanceConstraint("closeforest v oakforest", rmClassID("forest"), 6.0);


   // note - try and trim down on the number of these. Many must be redundant.


 // -------------Define objects
   // Close Objects

   int startingSettlementID=rmCreateObjectDef("Starting settlement");
   rmAddObjectDefItem(startingSettlementID, "TownCenter", 1, 0.0);
   rmAddObjectDefToClass(startingSettlementID, rmClassID("starting settlement"));
   rmSetObjectDefMinDistance(startingSettlementID, 0.0);
   rmSetObjectDefMaxDistance(startingSettlementID, 0.0);
   
   int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
      rmSetNuggetDifficulty(1, 1);

   // towers avoid other towers
   int startingTowerID=rmCreateObjectDef("Starting tower");
   rmAddObjectDefItem(startingTowerID, "nugget", 1, 0.0);
   rmSetObjectDefMinDistance(startingTowerID, 32.0);
   rmSetObjectDefMaxDistance(startingTowerID, 48.0);
   rmAddObjectDefConstraint(startingTowerID, avoidTower);
   rmAddObjectDefConstraint(startingTowerID, circleConstraint);
	rmAddObjectDefConstraint(startingTowerID, closeForestConstraint);

   // towers avoid other towers
   int startingTower2ID=rmCreateObjectDef("Starting tower2");
   rmAddObjectDefItem(startingTower2ID, "nugget", 1, 0.0);
/*   rmAddObjectDefItem(startingTower2ID, "gazelle", 6.0, 4.0); */
/* Gazelle were placed as player's */
   rmSetObjectDefMinDistance(startingTower2ID, 52.0);
   rmSetObjectDefMaxDistance(startingTower2ID, 78.0);
   rmAddObjectDefConstraint(startingTower2ID, circleConstraint);
	rmAddObjectDefConstraint(startingTower2ID, closeForestConstraint);

   // gold avoids gold
   int startingGoldID=rmCreateObjectDef("Starting gold");
   rmAddObjectDefItem(startingGoldID, "mine", 1, 0.0);
   rmSetObjectDefMinDistance(startingGoldID, 20.0);
   rmSetObjectDefMaxDistance(startingGoldID, 25.0);
   rmAddObjectDefConstraint(startingGoldID, avoidGold);
   rmAddObjectDefConstraint(startingGoldID, circleConstraint);
   rmAddObjectDefConstraint(startingGoldID, avoidImpassableLand);

   int closePigsID=rmCreateObjectDef("close Pigs");
   rmAddObjectDefItem(closePigsID, "pig", 4, 2.0);
   rmSetObjectDefMinDistance(closePigsID, 25.0);
   rmSetObjectDefMaxDistance(closePigsID, 30.0);
   rmAddObjectDefConstraint(closePigsID, avoidImpassableLand);
   rmAddObjectDefConstraint(closePigsID, avoidFood);
	rmAddObjectDefConstraint(closePigsID, avoidAll);
	rmAddObjectDefConstraint(closePigsID, circleConstraint);
	rmAddObjectDefConstraint(closePigsID, closeForestConstraint);


   int closeGazelleID=rmCreateObjectDef("close gazelles");
   rmAddObjectDefItem(closeGazelleID, "okapi", rmRandInt(6,8), 4.0);
   rmSetObjectDefMinDistance(closeGazelleID, 25.0);
   rmSetObjectDefMaxDistance(closeGazelleID, 30.0);
   rmAddObjectDefConstraint(closeGazelleID, avoidImpassableLand);
   rmAddObjectDefConstraint(closeGazelleID, avoidFood);
	rmAddObjectDefConstraint(closeGazelleID, bonusIslandConstraint);
	rmAddObjectDefConstraint(closeGazelleID, closeForestConstraint);
	rmAddObjectDefConstraint(closeGazelleID, avoidAll);
	rmAddObjectDefConstraint(closeGazelleID, circleConstraint);

   int closeHippoID=rmCreateObjectDef("close Hippo");
   float hippoNumber=rmRandFloat(0, 1);
   if(hippoNumber<0.3)
      rmAddObjectDefItem(closeHippoID, "hippo", 2, 1.0);
   else if(hippoNumber<0.6)
      rmAddObjectDefItem(closeHippoID, "hippo", 3, 4.0);
   else 
      rmAddObjectDefItem(closeHippoID, "ypWaterBuffalo", 2, 1.0);
   rmSetObjectDefMinDistance(closeHippoID, 30.0);
   rmSetObjectDefMaxDistance(closeHippoID, 50.0);
   rmAddObjectDefConstraint(closeHippoID, avoidImpassableLand);
	rmAddObjectDefConstraint(closeHippoID, closeForestConstraint);
	rmAddObjectDefConstraint(closeHippoID, avoidAll);
   
   

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
   rmAddObjectDefConstraint(mediumGoldID, circleConstraint);

   int mediumPigsID=rmCreateObjectDef("medium pigs");
   rmAddObjectDefItem(mediumPigsID, "pig", rmRandInt(2,3), 4.0);
   rmSetObjectDefMinDistance(mediumPigsID, 50.0);
   rmSetObjectDefMaxDistance(mediumPigsID, 70.0);
   rmAddObjectDefConstraint(mediumPigsID, avoidImpassableLand);
   rmAddObjectDefConstraint(mediumPigsID, avoidFoodFar);
   rmAddObjectDefConstraint(mediumPigsID, farStartingSettleConstraint);
	rmAddObjectDefConstraint(mediumPigsID, closeForestConstraint);
	rmAddObjectDefConstraint(mediumPigsID, playerConstraint);
	rmAddObjectDefConstraint(mediumPigsID, circleConstraint);

   // For this map, pick how many zebra/gazelle in a grouping.  Assign this
   // to both zebra and gazelle since we place them interchangeably per player.
   int numHuntable=rmRandInt(6, 8);

   int mediumGazelleID=rmCreateObjectDef("medium gazelles");
   rmAddObjectDefItem(mediumGazelleID, "okapi", numHuntable, 6.0);
   rmSetObjectDefMinDistance(mediumGazelleID, 40.0);
   rmSetObjectDefMaxDistance(mediumGazelleID, 50.0);
   rmAddObjectDefConstraint(mediumGazelleID, avoidImpassableLand);
   rmAddObjectDefConstraint(mediumGazelleID, farStartingSettleConstraint);
	rmAddObjectDefConstraint(mediumGazelleID, closeForestConstraint);
	rmAddObjectDefConstraint(mediumGazelleID, circleConstraint);
	rmAddObjectDefConstraint(mediumGazelleID, avoidAll);
	
   int mediumCraneID=rmCreateObjectDef("medium Cranes");
   rmAddObjectDefItem(mediumCraneID, "CrownedCrane", numHuntable, 8.0);
   rmSetObjectDefMinDistance(mediumCraneID, 60.0);
   rmSetObjectDefMaxDistance(mediumCraneID, 70.0);
   rmAddObjectDefConstraint(mediumCraneID, avoidImpassableLand);
   rmAddObjectDefConstraint(mediumCraneID, farStartingSettleConstraint);
	rmAddObjectDefConstraint(mediumCraneID, closeForestConstraint);
	rmAddObjectDefConstraint(mediumCraneID, circleConstraint);
	rmAddObjectDefConstraint(mediumCraneID, avoidAll);	

   int mediumZebraID=rmCreateObjectDef("medium zebra");
   rmAddObjectDefItem(mediumZebraID, "okapi", numHuntable, 8.0);
   rmSetObjectDefMinDistance(mediumZebraID, 80.0);
   rmSetObjectDefMaxDistance(mediumZebraID, 90.0);
   rmAddObjectDefConstraint(mediumZebraID, avoidImpassableLand);
   rmAddObjectDefConstraint(mediumZebraID, farStartingSettleConstraint);
	rmAddObjectDefConstraint(mediumZebraID, closeForestConstraint);
	rmAddObjectDefConstraint(mediumZebraID, circleConstraint);
	rmAddObjectDefConstraint(mediumZebraID, avoidAll);

   // far objects

   // gold avoids gold, Settlements and TCs
   int farGoldID=rmCreateObjectDef("far gold");
   rmAddObjectDefItem(farGoldID, "mine", 1, 0.0);
   rmSetObjectDefMinDistance(farGoldID, 80.0);
   rmSetObjectDefMaxDistance(farGoldID, 100.0);
   rmAddObjectDefConstraint(farGoldID, avoidGold);
   rmAddObjectDefConstraint(farGoldID, edgeConstraint);
   rmAddObjectDefConstraint(farGoldID, shortAvoidSettlement);
   rmAddObjectDefConstraint(farGoldID, avoidImpassableLand);
	

   // gold avoids gold, Settlements and TCs
   int bonusGoldID=rmCreateObjectDef("gold on bonus islands");
   rmAddObjectDefItem(bonusGoldID, "mine", 1, 0.0);
   rmSetObjectDefMinDistance(bonusGoldID, 90.0);
   rmSetObjectDefMaxDistance(bonusGoldID, 180.0);
   rmAddObjectDefConstraint(bonusGoldID, shortAvoidGold);
   rmAddObjectDefConstraint(bonusGoldID, edgeConstraint);
   rmAddObjectDefConstraint(bonusGoldID, shortAvoidSettlement);
   rmAddObjectDefConstraint(bonusGoldID, playerConstraint);
   rmAddObjectDefConstraint(bonusGoldID, avoidImpassableLand);

   int farPigsID=rmCreateObjectDef("far pigs");
   rmAddObjectDefItem(farPigsID, "pig", rmRandInt(1,2), 4.0);
   rmSetObjectDefMinDistance(farPigsID, 80.0);
   rmSetObjectDefMaxDistance(farPigsID, 150.0);
   rmAddObjectDefConstraint(farPigsID, avoidHerdable);
   rmAddObjectDefConstraint(farPigsID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(farPigsID, playerConstraint);
	rmAddObjectDefConstraint(farPigsID, closeForestConstraint);
  
   // pick lions or hyenas as predators
   // avoid TCs
   int farPredatorID=rmCreateObjectDef("far predator");
   float predatorSpecies=rmRandFloat(0, 1);
   if(predatorSpecies<0.5)   
      rmAddObjectDefItem(farPredatorID, "crocodile", 1, 4.0);
   else
      rmAddObjectDefItem(farPredatorID, "crocodile", 2, 2.0);
   rmSetObjectDefMinDistance(farPredatorID, 50.0);
   rmSetObjectDefMaxDistance(farPredatorID, 100.0);
   rmAddObjectDefConstraint(farPredatorID, avoidPredator);
   rmAddObjectDefConstraint(farPredatorID, farStartingSettleConstraint);
   rmAddObjectDefConstraint(farPredatorID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(farPredatorID, closeForestConstraint);
	rmAddObjectDefConstraint(farPredatorID, playerConstraint);

   int farCrocsID=rmCreateObjectDef("far Crocs");
   rmAddObjectDefItem(farCrocsID, "crocodile", rmRandInt(1,2), 0.0);
   rmSetObjectDefMinDistance(farCrocsID, 50.0);
   rmSetObjectDefMaxDistance(farCrocsID, 100.0);
   rmAddObjectDefConstraint(farCrocsID, farStartingSettleConstraint);
   rmAddObjectDefConstraint(farCrocsID, nearShore);
   // try and place near water

   int numCrane=rmRandInt(6, 8);
   int farCraneID=rmCreateObjectDef("far Crane");
   rmAddObjectDefItem(farCraneID, "crowned crane", numCrane, 3.0);
   rmSetObjectDefMinDistance(farCraneID, 100.0);
   rmSetObjectDefMaxDistance(farCraneID, 150.0);
   //rmAddObjectDefConstraint(farCraneID, farStartingSettleConstraint);
	rmAddObjectDefConstraint(farCraneID, circleConstraint);
   rmAddObjectDefConstraint(farCraneID, nearShore);
      
   // Player huntable
   int avoidHuntable=rmCreateTypeDistanceConstraint("avoid huntable", "huntable", 20.0);
   int bonusHuntableID=rmCreateObjectDef("bonus huntable");
   float bonusChance=rmRandFloat(0, 1);
   if(bonusChance<0.5)   
      rmAddObjectDefItem(bonusHuntableID, "ypWaterBuffalo", 2, 2.0);
   else if(bonusChance<0.75)
      rmAddObjectDefItem(bonusHuntableID, "okapi", rmRandInt(5,6), 3.0);
   else
      rmAddObjectDefItem(bonusHuntableID, "hippo", rmRandInt(3,5), 3.0);
   rmAddObjectDefToClass(bonusHuntableID, classBonusHuntable);
   rmSetObjectDefMinDistance(bonusHuntableID, 0.0);
   rmSetObjectDefMaxDistance(bonusHuntableID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(bonusHuntableID, shortAvoidSettlement);
   rmAddObjectDefConstraint(bonusHuntableID, avoidHuntable);
   rmAddObjectDefConstraint(bonusHuntableID, avoidBonusHuntable);
   rmAddObjectDefConstraint(bonusHuntableID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(bonusHuntableID, closeForestConstraint);
	rmAddObjectDefConstraint(bonusHuntableID, avoidAll);
  
   // Bonus huntable 1
   int bonusHuntableID2=rmCreateObjectDef("bonus huntable2");
   bonusChance=rmRandFloat(0, 1);
   if(bonusChance<0.5)   
      rmAddObjectDefItem(bonusHuntableID2, "hippo", 2, 2.0);
   else if(bonusChance<0.75)
      {
         rmAddObjectDefItem(bonusHuntableID2, "ypWaterBuffalo", rmRandInt(3,4), 3.0);
         if(rmRandFloat(0,1)<0.5)      
            rmAddObjectDefItem(bonusHuntableID2, "okapi", rmRandInt(2,4), 3.0);
      }
   else
      rmAddObjectDefItem(bonusHuntableID2, "okapi", rmRandInt(6,9), 4.0);
   rmSetObjectDefMinDistance(bonusHuntableID2, 0.0);
   rmSetObjectDefMaxDistance(bonusHuntableID2, rmXFractionToMeters(0.5));
   rmAddObjectDefToClass(bonusHuntableID2, classBonusHuntable);
   rmAddObjectDefConstraint(bonusHuntableID2, avoidSettlement);
	rmAddObjectDefConstraint(bonusHuntableID2, bonusIslandConstraint);
//   rmAddObjectDefConstraint(bonusHuntableID2, nearShore);
	rmAddObjectDefConstraint(bonusHuntableID2, avoidAll);
	rmAddObjectDefConstraint(bonusHuntableID2, closeForestConstraint);

   // Bonus huntable 3 and 3b - 2 versions to have different types of animals instead of all one type in the Marsh
	
   int bonusHuntableID3=rmCreateObjectDef("bonus huntable3");
   bonusChance=rmRandFloat(0, 1);
   if(bonusChance<0.5)   
      rmAddObjectDefItem(bonusHuntableID3, "boar", 4, 2.0);
   else if(bonusChance<0.75)
      {
         rmAddObjectDefItem(bonusHuntableID3, "boar", 6, 3.0);
         if(rmRandFloat(0,1)<0.5)      
            rmAddObjectDefItem(bonusHuntableID3, "crowned crane", rmRandInt(4,6), 4.0);
      }
   else
      rmAddObjectDefItem(bonusHuntableID3, "ypWaterBuffalo", rmRandInt(4,5), 3.0);
   rmSetObjectDefMinDistance(bonusHuntableID3, 0.0);
   rmSetObjectDefMaxDistance(bonusHuntableID3, rmXFractionToMeters(0.5));
   rmAddObjectDefToClass(bonusHuntableID3, classBonusHuntable);
   rmAddObjectDefConstraint(bonusHuntableID3, shortAvoidSettlement);
//	rmAddObjectDefConstraint(bonusHuntableID3, avoidAll);
	rmAddObjectDefConstraint(bonusHuntableID3, closeForestConstraint);
	rmAddObjectDefConstraint(bonusHuntableID3, avoidHuntable);
	rmAddObjectDefConstraint(bonusHuntableID3, playerConstraint);
	rmAddObjectDefConstraint(bonusHuntableID3, shortAvoidImpassableLand);


	int bonusHuntableID4=rmCreateObjectDef("bonus huntable3b");
   bonusChance=rmRandFloat(0, 1);
   if(bonusChance<0.5)   
      rmAddObjectDefItem(bonusHuntableID4, "boar", 4, 2.0);
   else if(bonusChance<0.75)
      {
         rmAddObjectDefItem(bonusHuntableID4, "boar", 6, 3.0);
         if(rmRandFloat(0,1)<0.5)      
            rmAddObjectDefItem(bonusHuntableID4, "crowned crane", rmRandInt(4,6), 4.0);
      }
   else
      rmAddObjectDefItem(bonusHuntableID4, "ypWaterBuffalo", rmRandInt(2,3), 3.0);
   rmSetObjectDefMinDistance(bonusHuntableID4, 0.0);
   rmSetObjectDefMaxDistance(bonusHuntableID4, rmXFractionToMeters(0.5));
   rmAddObjectDefToClass(bonusHuntableID4, classBonusHuntable);
   rmAddObjectDefConstraint(bonusHuntableID4, shortAvoidSettlement);
//	rmAddObjectDefConstraint(bonusHuntableID4, avoidAll);
	rmAddObjectDefConstraint(bonusHuntableID4, closeForestConstraint);
	rmAddObjectDefConstraint(bonusHuntableID4, avoidHuntable);
	rmAddObjectDefConstraint(bonusHuntableID4, playerConstraint);
	rmAddObjectDefConstraint(bonusHuntableID4, shortAvoidImpassableLand);
	
	

 

   


   // ===================================Done defining objects=============================================
	
   // ###################################### Create areas ###############################################


    rmPlacePlayersCircular(0.38, 0.40, rmDegreesToRadians(5.0));

	 rmSetStatusText("",0.40);


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
      rmSetAreaSize(id, rmAreaTilesToFraction(500), rmAreaTilesToFraction(500));
      rmAddAreaToClass(id, classPlayerCore);
      rmSetAreaCoherence(id, 1.0);
		rmSetAreaBaseHeight(id, 3.0);
      rmSetAreaLocPlayer(id, i);
	
      rmBuildArea(id);
   }

// Attempt to replace connections
   int Shallow1ID=rmCreateArea("Shallow 1");
   rmSetAreaSize(Shallow1ID, 0.09, 0.09);
   rmSetAreaLocation(Shallow1ID, 0.5, 0.5);
   rmSetAreaBaseHeight(Shallow1ID, -0.75);
   rmSetAreaCoherence(Shallow1ID, 0.9);
//         rmSetAreaTerrainType(Shallow1ID, "borneo\ground_sand1_borneo");
   rmBuildArea(Shallow1ID);

   int Shallow2ID=rmCreateArea("Shallow 2");
   rmSetAreaSize(Shallow2ID, 0.09, 0.09);
   rmSetAreaLocation(Shallow2ID, 0.5, 0.5);
   rmSetAreaBaseHeight(Shallow2ID, -0.75);
   rmAddAreaInfluenceSegment(Shallow2ID, .75, .75, .25, .25);
   rmAddAreaInfluenceSegment(Shallow2ID, .25, .75, .75, .25);
   rmSetAreaCoherence(Shallow2ID, 0.9);
//         rmSetAreaTerrainType(Shallow2ID, "borneo\ground_sand2_borneo");
   rmBuildArea(Shallow2ID);

   int Shallow3ID=rmCreateArea("Shallow 3");
   rmSetAreaSize(Shallow3ID, 0.09, 0.09);
   rmSetAreaLocation(Shallow3ID, 0.5, 0.5);
   rmSetAreaBaseHeight(Shallow3ID, -0.75);
   rmAddAreaInfluenceSegment(Shallow3ID, .5, .85, .5, .15);
   rmAddAreaInfluenceSegment(Shallow3ID, .85, .5, .15, .5);
   rmSetAreaCoherence(Shallow3ID, 0.9);
//         rmSetAreaTerrainType(Shallow3ID, "borneo\ground_sand3_borneo");
   rmBuildArea(Shallow3ID);

   int Shallow4ID=rmCreateArea("Shallow 4");
   rmSetAreaSize(Shallow4ID, 0.07, 0.07);
   rmSetAreaLocation(Shallow4ID, 0.75, 0.75);
   rmSetAreaBaseHeight(Shallow4ID, -0.75);
   rmAddAreaInfluenceSegment(Shallow4ID, .75, .75, .85, .5);
   rmAddAreaInfluenceSegment(Shallow4ID, .85, .5, .75, .25);
   rmAddAreaInfluenceSegment(Shallow4ID, .75, .25, .5, .15);
   rmAddAreaInfluenceSegment(Shallow4ID, .5, .15, .25, .25);
   rmSetAreaCoherence(Shallow4ID, 0.9);
//         rmSetAreaTerrainType(Shallow4ID, "borneo\ground_sand3_borneo");
   rmBuildArea(Shallow4ID);

   int Shallow5ID=rmCreateArea("Shallow 5");
   rmSetAreaSize(Shallow5ID, 0.07, 0.07);
   rmSetAreaLocation(Shallow5ID, 0.25, 0.25);
   rmSetAreaBaseHeight(Shallow5ID, -0.75);
   rmAddAreaInfluenceSegment(Shallow5ID, .25, .25, .15, .5);
   rmAddAreaInfluenceSegment(Shallow5ID, .15, .5, .25, .75);
   rmAddAreaInfluenceSegment(Shallow5ID, .25, .75, .5, .85);
   rmAddAreaInfluenceSegment(Shallow5ID, .5, .85, .75, .75);
   rmSetAreaCoherence(Shallow5ID, 0.9);
//         rmSetAreaTerrainType(Shallow5ID, "borneo\ground_sand3_borneo");
   rmBuildArea(Shallow5ID);

   // Create connections (Obsolete at the moment)
   int shallowsID=rmCreateConnection("shallows");
   rmSetConnectionType(shallowsID, cConnectAreas, false, 1.0);
   rmSetConnectionWidth(shallowsID, 14, 2);
   rmSetConnectionWarnFailure(shallowsID, false);
   rmSetConnectionBaseHeight(shallowsID, -0.5);
   rmSetConnectionHeightBlend(shallowsID, 1.0);
   rmSetConnectionSmoothDistance(shallowsID, 3.0);
   rmAddConnectionTerrainReplacement(shallowsID, "MarshF"); /*RiverMarshA */

   // Create extra connections
   int extraShallowsID=rmCreateConnection("extra shallows");
   if(cNumberPlayers < 5)
      rmSetConnectionType(extraShallowsID, cConnectAreas, false, 0.75);
   else if(cNumberPlayers < 7) 
      rmSetConnectionType(extraShallowsID, cConnectAreas, false, 0.30);
   rmSetConnectionWidth(extraShallowsID, 28, 2);
   rmSetConnectionWarnFailure(extraShallowsID, false); 
   rmSetConnectionBaseHeight(extraShallowsID, 0.1);
   rmSetConnectionHeightBlend(extraShallowsID, 0.0);
   rmSetConnectionSmoothDistance(extraShallowsID, 3.0);
   rmSetConnectionPositionVariance(extraShallowsID, -1.0); 
   rmAddConnectionTerrainReplacement(extraShallowsID, "MarshF"); 
   rmAddConnectionStartConstraint(extraShallowsID, coreBonusConstraint);
   rmAddConnectionEndConstraint(extraShallowsID, coreBonusConstraint);

  // Create team connections
   int teamShallowsID=rmCreateConnection("team shallows");
   rmSetConnectionType(teamShallowsID, cConnectAllies, false, 1.0);
   rmSetConnectionWarnFailure(teamShallowsID, false);
   rmSetConnectionWidth(teamShallowsID, 14, 2);
   rmSetConnectionBaseHeight(teamShallowsID, -0.5);
   rmSetConnectionHeightBlend(teamShallowsID, 2.0);
   rmSetConnectionSmoothDistance(teamShallowsID, 3.0);
   rmAddConnectionTerrainReplacement(teamShallowsID, "MarshF");

// Build up some bonus islands.
   int bonusCount = rmRandInt(4, 5);
   int bonusIsleSize = 2800;
/*
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
*/
   rmEchoInfo("number of bonus isles "+bonusCount+ "size of isles "+bonusIsleSize);
  
   for(i=0; <bonusCount)
   {
      int bonusIslandID=rmCreateArea("bonus island"+i);
      rmSetAreaSize(bonusIslandID, rmAreaTilesToFraction(bonusIsleSize*0.9), rmAreaTilesToFraction(bonusIsleSize*1.1));
      rmSetAreaMix(bonusIslandID, "africanmarsh");
      rmAddAreaTerrainLayer(bonusIslandID, "wotta\marsh\marshf", 0, 6); 
      rmSetAreaWarnFailure(bonusIslandID, false);
//      if(rmRandFloat(0.0, 1.0)<0.70)
         rmAddAreaConstraint(bonusIslandID, bonusIslandConstraint);
      rmAddAreaConstraint(bonusIslandID, bonusIslandEdgeConstraint);
      rmAddAreaToClass(bonusIslandID, classIsland);
      rmAddAreaToClass(bonusIslandID, classBonusIsland);
      rmAddAreaConstraint(bonusIslandID, coreBonusConstraint);
      rmSetAreaCoherence(bonusIslandID, 0.25);
      rmSetAreaSmoothDistance(bonusIslandID, 12);
      rmSetAreaHeightBlend(bonusIslandID, 2);
      rmSetAreaBaseHeight(bonusIslandID, 2.0);
//      rmAddConnectionArea(extraShallowsID, bonusIslandID);
		rmAddAreaConstraint(bonusIslandID, islandConstraint);
//      rmAddConnectionArea(shallowsID, bonusIslandID);
   }  

   rmBuildAllAreas();

	 rmSetStatusText("",0.50);

   // Set up player areas.
   float playerFraction=rmAreaTilesToFraction(800);
   for(i=1; <cNumberPlayers)
   {
      // Create the area.
      id=rmCreateArea("Player"+i);
      rmSetPlayerArea(i, id);
      rmSetAreaSize(id, 0.5, 0.5);
      rmAddAreaToClass(id, classIsland);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaWarnFailure(id, false);
      rmSetAreaMinBlobs(id, 3);
      rmSetAreaMaxBlobs(id, 6);
      rmSetAreaMinBlobDistance(id, 7.0);
      rmSetAreaMaxBlobDistance(id, 12.0);
      rmSetAreaCoherence(id, 0.5);
      rmSetAreaBaseHeight(id, 2.0);
      rmSetAreaSmoothDistance(id, 10);
      rmSetAreaHeightBlend(id, 2);
      rmAddAreaConstraint(id, islandConstraint);
      rmAddAreaConstraint(id, cornerOverlapConstraint);
      rmAddAreaConstraint(id, bonusIslandConstraint);
      rmAddAreaConstraint(id, centerConstraint);
      rmSetAreaLocPlayer(id, i);
//      rmAddConnectionArea(extraShallowsID, id);
//      rmAddConnectionArea(shallowsID, id);
      rmSetAreaMix(id, "africanmarsh");
		rmAddAreaTerrainLayer(id, "MarshD", 4, 7);
      rmAddAreaTerrainLayer(id, "MarshD", 2, 4);
		rmAddAreaTerrainLayer(id, "MarshE", 0, 2);
   }

   // Build all areas
   rmBuildAllAreas();
   
   for(i=1; <cNumberPlayers)
   {
      // Create the area.
      int id2=rmCreateArea("PlayerX"+i);
      rmSetPlayerArea(i, id2);
      rmSetAreaSize(id2, playerFraction, playerFraction);
//      rmAddAreaToClass(id2, classIsland);
//      rmAddAreaToClass(id2, classPlayer);
      rmSetAreaWarnFailure(id2, false);
      rmSetAreaCoherence(id2, 0.99);
      rmSetAreaBaseHeight(id2, 2.0);
      rmSetAreaSmoothDistance(id2, 10);
      rmSetAreaLocPlayer(id2, i);
      rmSetAreaMix(id2, "africanmarsh");
   }

   // Build all areas
   rmBuildAllAreas();

   rmPlaceObjectDefPerPlayer(startingSettlementID, true);
	for(i=1; < cNumberPlayers)
	{
		rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	}



/// African Marsh.
   
   int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest v forest", rmClassID("forest"), 24.0);
	int oakForestConstraint=rmCreateClassDistanceConstraint("oakforest v oakforest", rmClassID("forest"), 30.0);

   int forestSettleConstraint=rmCreateClassDistanceConstraint("forest settle", rmClassID("starting settlement"), 20.0);
   int forestCount=3*cNumberNonGaiaPlayers;
   int failCount=0;
   for(i=0; <forestCount)
   {
      int forestID=rmCreateArea("forest"+i);
      rmSetAreaSize(forestID, rmAreaTilesToFraction(50), rmAreaTilesToFraction(100));
      rmSetAreaWarnFailure(forestID, false);
/*      if(rmRandFloat(0,1)<0.8)
         rmSetAreaForestType(forestID, "African Marsh");
      else
         rmSetAreaForestType(forestID, "African Marsh");
*/
		rmSetAreaForestType(forestID, "African Marsh");
      rmAddAreaConstraint(forestID, forestSettleConstraint);
      rmAddAreaConstraint(forestID, forestObjConstraint);
      rmAddAreaConstraint(forestID, forestConstraint);
		rmAddAreaConstraint(forestID, playerConstraint);
      rmAddAreaConstraint(forestID, avoidImpassableLand);
      rmAddAreaToClass(forestID, classForest);
		rmSetAreaTerrainType(forestID, "MarshA");
      rmAddAreaTerrainLayer(forestID, "MarshB", 0, 2); 
      
      rmSetAreaMinBlobs(forestID, 2);
      rmSetAreaMaxBlobs(forestID, 4);
      rmSetAreaMinBlobDistance(forestID, 16.0);
      rmSetAreaMaxBlobDistance(forestID, 20.0);
      rmSetAreaCoherence(forestID, 0.0);

      // Hill trees?
//      if(rmRandFloat(0.0, 1.0)<0.2)
//         rmSetAreaBaseHeight(forestID, rmRandFloat(6.0, 9.0));
			rmSetAreaBaseHeight(forestID, 0);
			rmSetAreaSmoothDistance(forestID, 4);
			rmSetAreaHeightBlend(forestID, 2);

	
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

	 rmSetStatusText("",0.60);

	// Beautification sub area.
   for(i=1; <cNumberPlayers*20)
   {
        int id3=rmCreateArea("marsh patch"+i);
        rmSetAreaSize(id3, rmAreaTilesToFraction(10), rmAreaTilesToFraction(50));
        rmSetAreaTerrainType(id3, "MarshC");
        rmSetAreaMinBlobs(id3, 1);
        rmSetAreaMaxBlobs(id3, 5);
        rmSetAreaMinBlobDistance(id3, 16.0);
        rmSetAreaMaxBlobDistance(id3, 40.0);
        rmSetAreaCoherence(id3, 0.0);
        rmAddAreaConstraint(id3, shortAvoidImpassableLand);
		  rmAddAreaConstraint(id3, closeForestConstraint);
		  rmAddAreaConstraint(id3, playerConstraint);
        rmBuildArea(id3);
   } 

/// Player Forests.
   
   int playerForestCount=6*cNumberNonGaiaPlayers;
   int playerfailCount=0;
   for(i=0; <playerForestCount)
   {
      int playerForestID=rmCreateArea("playerForest"+i);
      rmSetAreaSize(playerForestID, rmAreaTilesToFraction(100), rmAreaTilesToFraction(160));
      rmSetAreaWarnFailure(playerForestID, false);
/*      if(rmRandFloat(0,1)<0.8)
         rmSetAreaForestType(forestID, "African Marsh");
      else
         rmSetAreaForestType(forestID, "African Marsh");
*/
		rmSetAreaForestType(playerForestID, "African Marsh");
      rmAddAreaConstraint(playerForestID, forestSettleConstraint);
      rmAddAreaConstraint(playerForestID, forestObjConstraint);
      rmAddAreaConstraint(playerForestID, oakForestConstraint);
		rmAddAreaConstraint(playerForestID, bonusIslandConstraint);
      rmAddAreaConstraint(playerForestID, avoidImpassableLand);
      rmAddAreaToClass(playerForestID, classForest);
      
      rmSetAreaMinBlobs(playerForestID, 2);
      rmSetAreaMaxBlobs(playerForestID, 4);
      rmSetAreaMinBlobDistance(playerForestID, 16.0);
      rmSetAreaMaxBlobDistance(playerForestID, 20.0);
      rmSetAreaCoherence(playerForestID, 0.0);

      // Hill trees?
//      if(rmRandFloat(0.0, 1.0)<0.6)
//         rmSetAreaBaseHeight(playerForestID, rmRandFloat(10.0, 12.0));
			rmSetAreaSmoothDistance(playerForestID, 14);
			rmSetAreaHeightBlend(playerForestID, 2);

      if(rmBuildArea(playerForestID)==false)
      {
         // Stop trying once we fail 3 times in a row.
         playerfailCount++;
         if(playerfailCount==3)
            break;
      }
      else
         playerfailCount=0;
   }


   // Elev.
   failCount=0;
   int numTries1=10*cNumberNonGaiaPlayers;
   int avoidBuildings=rmCreateTypeDistanceConstraint("avoid buildings", "Building", 10.0);
   for(i=0; <numTries1)
   {
      int elevID=rmCreateArea("elev"+i);
      rmSetAreaSize(elevID, rmAreaTilesToFraction(50), rmAreaTilesToFraction(120));
      rmSetAreaLocation(elevID, rmRandFloat(0.0, 1.0), rmRandFloat(0.0, 1.0));
      rmSetAreaWarnFailure(elevID, false); 
      rmAddAreaConstraint(elevID, avoidBuildings);
      rmAddAreaConstraint(elevID, shortAvoidImpassableLand);
		rmAddAreaConstraint(elevID, bonusIslandConstraint);
      if(rmRandFloat(0.0, 1.0)<0.7)
		{
         rmSetAreaTerrainType(elevID, "MarshD");
			rmAddAreaTerrainLayer(elevID, "MarshE", 0, 4); 
		}
      rmSetAreaBaseHeight(elevID, rmRandFloat(6.0, 10.0));
      rmSetAreaHeightBlend(elevID, 2);
		rmSetAreaSmoothDistance(elevID, 20);
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

	// Beautification

	int logID=rmCreateObjectDef("log");
   rmAddObjectDefItem(logID, "rotting log", rmRandInt(1,2), 0.0);
	rmAddObjectDefItem(logID, "Underbrushcarolinasmarsh", 1, 2.0);
	rmAddObjectDefItem(logID, "andes_grassrock_a", rmRandInt(3,5), 2.0);
   rmSetObjectDefMinDistance(logID, 0.0);
   rmSetObjectDefMaxDistance(logID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(logID, avoidAll);
   rmAddObjectDefConstraint(logID, avoidImpassableLand);
   rmAddObjectDefConstraint(logID, playerConstraint);
   rmPlaceObjectDefAtLoc(logID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);

	int grassesID=rmCreateObjectDef("grasses");
   rmAddObjectDefItem(grassesID, "bush", rmRandInt(1,3), 2.0);
	rmAddObjectDefItem(grassesID, "UnderbrushAmazon", rmRandInt(3,5), 5.0);
	rmAddObjectDefItem(grassesID, "andes_grassrock_a", rmRandInt(2,4), 10.0);
   rmSetObjectDefMinDistance(grassesID, 0.0);
   rmSetObjectDefMaxDistance(grassesID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(grassesID, avoidAll);
   rmAddObjectDefConstraint(grassesID, avoidImpassableLand);
   rmAddObjectDefConstraint(grassesID, bonusIslandConstraint);
   rmPlaceObjectDefAtLoc(grassesID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);

	int reedsID=rmCreateObjectDef("reeds");
   rmAddObjectDefItem(reedsID, "Underbrushcarolinasmarsh", rmRandInt(4,6), 2.0);
	rmAddObjectDefItem(reedsID, "UnderbrushAmazon", rmRandInt(1,3), 3.0);
	rmSetObjectDefMinDistance(reedsID, 0.0);
   rmSetObjectDefMaxDistance(reedsID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(reedsID, avoidAll);
   rmAddObjectDefConstraint(reedsID, nearShore);
   rmPlaceObjectDefAtLoc(reedsID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);

	int lilyID=rmCreateObjectDef("pads");
   rmAddObjectDefItem(lilyID, "Underbrushcarolinasmarsh", rmRandInt(3,5), 4.0);
   rmSetObjectDefMinDistance(lilyID, 0.0);
   rmSetObjectDefMaxDistance(lilyID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(lilyID, avoidAll);
   rmPlaceObjectDefAtLoc(lilyID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);




	// Home Settlement
   id=rmAddFairLoc("nugget", false, true, 60, 100, 40, 16); /* bool forward bool inside */
   rmAddFairLocConstraint(id, avoidImpassableLand);

	id=rmAddFairLoc("nugget", true, false,  70, 160, 80, 16); 
   rmAddFairLocConstraint(id, shortAvoidImpassableLand);
   rmAddFairLocConstraint(id, playerConstraint);

   
   if(rmPlaceFairLocs())
   {
      id=rmCreateObjectDef("far settlement");
      rmAddObjectDefItem(id, "nugget", 1, 0.0);
      rmSetNuggetDifficulty(2, 2);
      for(i=1; <cNumberPlayers)
      {
         for(j=0; <rmGetNumberFairLocs(i))
            rmPlaceObjectDefAtLoc(id, i, rmFairLocXFraction(i, j), rmFairLocZFraction(i, j), 1);
      }
   }

   rmResetFairLocs();

   // Bonus Settlement
      rmSetNuggetDifficulty(3, 3);

   if(rmPlaceFairLocs())
   {
      id=rmCreateObjectDef("bonus settlement");
      rmAddObjectDefItem(id, "nugget", 1, 0.0);
      for(i=1; <cNumberPlayers)
      {
         for(j=0; <rmGetNumberFairLocs(i))
         {
            int bonusSettleArea = rmCreateArea("bonus settlement area"+i +j);
            rmSetAreaLocation(bonusSettleArea, rmFairLocXFraction(i, j), rmFairLocZFraction(i, j));
            rmBuildArea(bonusSettleArea);
            rmPlaceObjectDefAtAreaLoc(id, i, bonusSettleArea); 
         }
			
      }
				
	}	
	
// PLACE STARTING TOWN AND RESOURCES

 rmSetStatusText("",0.70);

// Towers.
   rmPlaceObjectDefPerPlayer(startingTowerID, true, 3);
   rmPlaceObjectDefPerPlayer(startingTower2ID, true, 1);

   // Straggler trees.

	int stragglerTreeID=rmCreateObjectDef("straggler tree");
   rmAddObjectDefItem(stragglerTreeID, "TreeBayou", 1, 0.0);
   rmSetObjectDefMinDistance(stragglerTreeID, 12.0);
   rmSetObjectDefMaxDistance(stragglerTreeID, 15.0);
   rmAddObjectDefConstraint(stragglerTreeID, avoidImpassableLand);
	rmAddObjectDefConstraint(stragglerTreeID, bonusIslandConstraint);

	int stragglerTreeMarshID=rmCreateObjectDef("straggler tree2");
   rmAddObjectDefItem(stragglerTreeMarshID, "TreeAmazon", 1, 0.0);
   rmSetObjectDefMinDistance(stragglerTreeMarshID, 4.0);
   rmSetObjectDefMaxDistance(stragglerTreeMarshID, 15.0);
   rmAddObjectDefConstraint(stragglerTreeMarshID, avoidImpassableLand);
	rmAddObjectDefConstraint(stragglerTreeMarshID, playerConstraint);
   
	
	rmPlaceObjectDefPerPlayer(stragglerTreeID, false, rmRandInt(3, 7));
	
	rmPlaceObjectDefPerPlayer(stragglerTreeMarshID, false, rmRandInt(3, 5));

   // Gold
   rmPlaceObjectDefPerPlayer(startingGoldID, false);

	// Pigs
   rmPlaceObjectDefPerPlayer(closePigsID, true);

	// Gazelle
   rmPlaceObjectDefPerPlayer(closeGazelleID, false); 

// Medium things....
   // Gold
//   for(i=1; <cNumberPlayers)
		rmPlaceObjectDefPerPlayer(mediumGoldID, false, rmRandInt(1,2));
//      rmPlaceObjectDefInArea(mediumGoldID, 0, rmAreaID("player"+i));
		rmPlaceObjectDefPerPlayer(mediumGazelleID, false, rmRandInt(1,2));
		rmPlaceObjectDefPerPlayer(mediumCraneID, false, 1);
        rmPlaceObjectDefPerPlayer(mediumZebraID, false, 1);
        
   // Pigs
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(mediumPigsID, 0, rmAreaID("bonus island"+i));

// Far things.

   // Player Far Gold, need goldNum since it randomizes for each i
   int goldNum = rmRandInt(1,2);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(farGoldID, false, rmAreaID("player"+i), goldNum);
      rmPlaceObjectDefInArea(farCraneID, false, rmAreaID("player"+i), 1);
      
  // Bonus Gold
   rmPlaceObjectDefPerPlayer(bonusGoldID, false, rmRandInt(1,2));


   // Bonus huntable
   for(i=1; <cNumberPlayers)
	{
      rmPlaceObjectDefInArea(bonusHuntableID, false, rmAreaID("player"+i));
		rmPlaceObjectDefInArea(bonusHuntableID2, false, rmAreaID("player"+i));
	}
    // Bonus huntable
//   for(i=1; <4*bonusCount)
//      rmPlaceObjectDefInArea(bonusHuntableID3, false, rmAreaID("bonus island"+i));
	rmPlaceObjectDefAtLoc(bonusHuntableID3, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
	rmPlaceObjectDefAtLoc(bonusHuntableID4, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
   
   
   // Pigs
   int pigNum = rmRandInt(1,2);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(farPigsID, false, rmAreaID("bonus island"+i), pigNum);

   // Predators
   rmPlaceObjectDefPerPlayer(farPredatorID, false, 2);

   // Text
   rmSetStatusText("",0.80);
	
	
	
// Random trees.

	int randomTreeID=rmCreateObjectDef("random tree");
   rmAddObjectDefItem(randomTreeID, "TreeBayou", 1, 0.0);
   rmSetObjectDefMinDistance(randomTreeID, 0.0);
   rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTreeID, rmCreateTypeDistanceConstraint("random tree", "all", 4.0));
   rmAddObjectDefConstraint(randomTreeID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(randomTreeID, shortAvoidSettlement);
	rmAddObjectDefConstraint(randomTreeID, bonusIslandConstraint);

   int randomTreeID2=rmCreateObjectDef("random tree 2");
   rmAddObjectDefItem(randomTreeID2, "TreeBayou", 1, 0.0);
   rmSetObjectDefMinDistance(randomTreeID2, 0.0);
   rmSetObjectDefMaxDistance(randomTreeID2, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTreeID2, rmCreateTypeDistanceConstraint("random tree two", "all", 4.0));
   rmAddObjectDefConstraint(randomTreeID2, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(randomTreeID2, shortAvoidSettlement);
	rmAddObjectDefConstraint(randomTreeID2, playerConstraint);


   rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);

   rmPlaceObjectDefAtLoc(randomTreeID2, 0, 0.5, 0.5, 20*cNumberNonGaiaPlayers);

// SWARMS OF BUGS

	/*
	int bugsID=rmCreateObjectDef("swarms");
	rmAddObjectDefItem(bugsID, "TreeBayou", 3, 2.0);
	rmAddObjectDefItem(bugsID, "MarshPlantsBay", 1, 0.0);
   rmSetObjectDefMinDistance(bugsID, 0.0);
   rmSetObjectDefMaxDistance(bugsID, 600);
   rmAddObjectDefConstraint(bugsID, avoidAll);
	rmAddObjectDefConstraint(bugsID, playerConstraint);
	rmAddObjectDefConstraint(bugsID, avoidImpassableLand);
   rmPlaceObjectDefAtLoc(bugsID, 0, 0.5, 0.5, 1*cNumberNonGaiaPlayers); 

	int bugs2ID=rmCreateObjectDef("swarms2");
	rmAddObjectDefItem(bugs2ID, "TreeBayou", 4, 2.0);
	rmAddObjectDefItem(bugs2ID, "MarshPlantsBay", 1, 0.0);
   rmSetObjectDefMinDistance(bugs2ID, 0.0);
   rmSetObjectDefMaxDistance(bugs2ID, 600);
   rmAddObjectDefConstraint(bugs2ID, avoidAll);
	rmAddObjectDefConstraint(bugs2ID, playerConstraint);
	rmAddObjectDefConstraint(bugs2ID, avoidImpassableLand);
   rmPlaceObjectDefAtLoc(bugs2ID, 0, 0.5, 0.5, 1*cNumberNonGaiaPlayers); 
*/
	int mistID=rmCreateObjectDef("bugs");
	rmAddObjectDefItem(mistID, "MarshPlantsBay", 1, 0.0);
   rmSetObjectDefMinDistance(mistID, 0.0);
   rmSetObjectDefMaxDistance(mistID, 600);
   rmAddObjectDefConstraint(mistID, avoidAll);
	rmAddObjectDefConstraint(mistID, playerConstraint);
	rmAddObjectDefConstraint(mistID, avoidImpassableLand);
   rmPlaceObjectDefAtLoc(mistID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers); 

	rmSetStatusText("",0.99);


  // King of the Hill (added 2026-11 for WoL): the central island of the marsh
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
