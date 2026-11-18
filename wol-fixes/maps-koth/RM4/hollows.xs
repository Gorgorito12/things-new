include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";


void main(void)
{
    // Text
    // These status text lines are used to manually animate the map generation progress bar
    rmSetStatusText("",0.01);

    // Picks the map size
    int playerTiles=10000;
    int size=2.1*sqrt(cNumberNonGaiaPlayers*playerTiles);
    rmEchoInfo("Map size="+size+"m x "+size+"m");
    rmSetMapSize(size, size);

    // Picks a default water height
    rmSetSeaLevel(0.0); // this is height of river surface compared to surrounding land. River depth is in the river XML.

    // Picks default terrain and water
    rmSetBaseTerrainMix("saguenay tundra");
    rmTerrainInitialize("saguenay\ground5_sag", 5);
    rmSetMapType("hollows");
    rmSetMapType("grass");
    rmSetMapType("land");
    rmSetLightingSet("316a_russians"); // Daytime lighting

    // Make the corners.
    rmSetWorldCircleConstraint(true);

    // Choose Mercs
    chooseMercs();
    wotta_triggers();

    // Define some classes. These are used later for constraints.
    int classPlayer=rmDefineClass("player");
    rmDefineClass("classHill");
    rmDefineClass("classPatch");
    rmDefineClass("starting settlement");
    rmDefineClass("startingUnit");
    rmDefineClass("classForest");
    rmDefineClass("importantItem");
    rmDefineClass("classCliff");
    rmDefineClass("classMountain");
    rmDefineClass("classLake");

    int classCliff = rmDefineClass("Cliffs");

    // -------------Define constraints
    // These are used to have objects and areas avoid each other

    // Map edge constraints
    //int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(6), rmZTilesToFraction(6), 1.0-rmXTilesToFraction(6), 1.0-rmZTilesToFraction(6), 0.01);
    int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.43), rmDegreesToRadians(0), rmDegreesToRadians(360));
    int coinEdgeConstraint=rmCreateBoxConstraint("coin edge of map", rmXTilesToFraction(19), rmZTilesToFraction(19), 1.0-rmXTilesToFraction(19), 1.0-rmZTilesToFraction(19), 2.0);

    // Cardinal Directions
    int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
    int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));
    int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
    int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));

    // Player constraints
    int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 20.0);
    int longPlayerConstraint=rmCreateClassDistanceConstraint("stay far away from players", classPlayer, 50.0);

    // Nature avoidance
    int avoidForest=rmCreateClassDistanceConstraint("forest avoids forest", rmClassID("classForest"), 10.0);
    int avoidForestFar=rmCreateClassDistanceConstraint("forest avoids forest far", rmClassID("classForest"), 40.0);
    int avoidturkey=rmCreateTypeDistanceConstraint("avoids turkey", "turkey", 45.0);
    int avoiddeer=rmCreateTypeDistanceConstraint("deer avoids deer", "deer", 45.0);
    int avoiddeerFar=rmCreateTypeDistanceConstraint("deer avoids deer Far", "deer", 65.0);
    int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "gold", 30.0);
    int avoidCoinFar=rmCreateTypeDistanceConstraint("avoid coin far", "gold", 60.0);

    // Avoid impassable land
    int avoidImpassableLand = rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 10.0);
    int avoidCliff = rmCreateClassDistanceConstraint("stuff vs. cliff", rmClassID("classCliff"), 12.0);
    int cliffAvoidCliff = rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 30.0);
    int mediumShortAvoidImpassableLand = rmCreateTerrainDistanceConstraint("mediumshort avoid impassable land", "Land", false, 10.0);
    int shortAvoidImpassableLand = rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
    int mediumAvoidImpassableLand = rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 12.0);
    int longAvoidImpassableLand = rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 20.0);

    int avoidLake = rmCreateClassDistanceConstraint("stuff vs. lake", rmClassID("classLake"), 1.0);

    // Unit avoidance
    int avoidHuari=rmCreateTypeDistanceConstraint("avoid Huari", "huariStronghold", 20.0);
    int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 20.0);
    int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
    int avoidTownCenterSupaFar=rmCreateTypeDistanceConstraint("avoid Town Center Supa Far", "townCenter", 50.0);
    int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 60.0);
    int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other by a bit", rmClassID("importantItem"), 10.0);
    int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 65.0);

    // Decoration avoidance
    int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 8.0);


    // -------------Define objects
    // These objects are all defined so they can be placed later

    rmSetStatusText("",0.10);

    int startingUnits = rmCreateStartingUnitsObjectDef(5.0);

    // ****************************** PLACE PLAYERS ******************************

    int teamZeroCount = rmGetNumberPlayersOnTeam(0);
    int teamOneCount = rmGetNumberPlayersOnTeam(1);
    // 2 team and FFA support
    float OneVOnePlacement=rmRandFloat(0, 1);
    if (cNumberNonGaiaPlayers == 2)
    {
        if ( OneVOnePlacement < 0.5)
        {
            rmSetPlacementTeam(0);
            rmPlacePlayersLine(0.4, 0.2, 0.2, 0.4, 0, 0.0);

            rmSetPlacementTeam(1);
            rmPlacePlayersLine(0.6, 0.8, 0.8, 0.6, 0, 0.0);
        }
        else
        {
            rmSetPlacementTeam(0);
            rmPlacePlayersLine(0.6, 0.8, 0.8, 0.6, 0, 0.0);

            rmSetPlacementTeam(1);
            rmPlacePlayersLine(0.4, 0.2, 0.2, 0.4, 0, 0.0);
        }
    }
    //*******************************TEAM PLACEMENTS*****************************
    else if ( cNumberTeams == 2 && teamZeroCount == teamOneCount)
    {
        rmSetPlacementTeam(0);
        rmSetTeamSpacingModifier(0.20);
        rmPlacePlayersLine(0.1, 0.5, 0.5, 0.1, 0, 0.0);

        rmSetPlacementTeam(1);
        rmSetTeamSpacingModifier(0.20);
        rmPlacePlayersLine(0.9, 0.5, 0.5, 0.9, 0, 0.0);
    }
    //******************************************FFA SUPPORT***************************************
    else if (cNumberTeams > 2)
    {
        bool southSide = true;

        float spacingIncrement = (0.35 / (cNumberNonGaiaPlayers / 2));
        float spacingSouth = 0;
        float spacingNorth = 0;

        float southStart = 0.45;
        float southEnd = 0.82;
        float northStart = 0.95;
        float northEnd = 0.32;

        for (i = 0; < cNumberNonGaiaPlayers)
        {
            rmEchoInfo("i = "+i);
            if (southSide == true)
            {
                rmSetPlacementTeam(i);
                rmSetPlacementSection((southStart + spacingSouth), southEnd);
                rmSetTeamSpacingModifier(0.25);
                rmPlacePlayersCircular(0.4, 0.4, 0);
                spacingSouth = spacingSouth + spacingIncrement;
            }
            else
            {
                rmSetPlacementTeam(i);
                rmSetPlacementSection((northStart + spacingNorth), northEnd);
                rmSetTeamSpacingModifier(0.25);
                rmPlacePlayersCircular(0.4, 0.4, 0);
                spacingNorth = spacingNorth + spacingIncrement;
            }
            if (southSide == true)
            {
                southSide = false;
            }
            else
            {
                southSide = true;
            }
        }
    }
    else
    {
        if (teamZeroCount < teamOneCount)
        {
            rmSetPlacementTeam(0);
            rmSetPlacementSection(0.55, 0.75);
            rmSetTeamSpacingModifier(0.35 / teamZeroCount);
            rmPlacePlayersCircular(0.4, 0.4, 0);

            rmSetPlacementTeam(1);
            rmSetPlacementSection(0.95, 0.32);
            rmSetTeamSpacingModifier(0.35 / teamOneCount);
            rmPlacePlayersCircular(0.4, 0.4, 0);
        }
        else
        {
            rmSetPlacementTeam(0);
            rmSetPlacementSection(0.45, 0.82);
            rmSetTeamSpacingModifier(0.35 / teamZeroCount);
            rmPlacePlayersCircular(0.4, 0.4, 0);

            rmSetPlacementTeam(1);
            rmSetPlacementSection(0.0, 0.2);
            rmSetTeamSpacingModifier(0.35 / teamOneCount);
            rmPlacePlayersCircular(0.4, 0.4, 0);
        }
    }

    int islandID=rmCreateArea("island");
    rmSetAreaSize(islandID, 0.01, 0.01);
    rmSetAreaLocation(islandID, 0.5, 0.5);
    rmSetAreaElevationType(islandID, cElevTurbulence);
    rmSetAreaElevationVariation(islandID, 5.0);
    rmSetAreaBaseHeight(islandID, 4.0);
    rmSetAreaElevationMinFrequency(islandID, 0.07);
    rmSetAreaElevationOctaves(islandID, 4);
    rmSetAreaElevationPersistence(islandID, 0.5);
    rmSetAreaElevationNoiseBias(islandID, 1);
    rmAddAreaToClass(islandID, rmClassID("classLake"));
    rmSetAreaCoherence(islandID, 10.0);
    rmSetAreaMix(islandID, "saguenay tundra");

    // Build an east area
    int eastIslandID = rmCreateArea("east island");
    rmSetAreaLocation(eastIslandID, 0.15, 0.85);
    rmSetAreaWarnFailure(eastIslandID, false);
    rmSetAreaSize(eastIslandID, 0.40, 0.40);
    rmSetAreaCoherence(eastIslandID, 0.5);
    rmAddAreaConstraint(eastIslandID, avoidLake);

    rmSetAreaElevationType(eastIslandID, cElevTurbulence);
    rmSetAreaElevationVariation(eastIslandID, 5.0);
    rmSetAreaBaseHeight(eastIslandID, 4.0);
    rmSetAreaElevationMinFrequency(eastIslandID, 0.07);
    rmSetAreaElevationOctaves(eastIslandID, 4);
    rmSetAreaElevationPersistence(eastIslandID, 0.5);
    rmSetAreaElevationNoiseBias(eastIslandID, 1);

    rmSetAreaObeyWorldCircleConstraint(eastIslandID, false);
    rmSetAreaMix(eastIslandID, "saguenay tundra");

    rmSetStatusText("",0.20);

    // Build a west area
    int westIslandID = rmCreateArea("west island");
    rmSetAreaLocation(westIslandID, 0.75, 0.25);
    rmSetAreaWarnFailure(westIslandID, false);
    rmSetAreaSize(westIslandID, 0.40, 0.40);
    rmSetAreaCoherence(westIslandID, 0.5);
    rmAddAreaConstraint(westIslandID, avoidLake);

    rmSetAreaElevationType(westIslandID, cElevTurbulence);
    rmSetAreaElevationVariation(westIslandID, 5.0);
    rmSetAreaBaseHeight(westIslandID, 4.0);
    rmSetAreaElevationMinFrequency(westIslandID, 0.07);
    rmSetAreaElevationOctaves(westIslandID, 4);
    rmSetAreaElevationPersistence(westIslandID, 0.5);
    rmSetAreaElevationNoiseBias(westIslandID, 1);

    rmSetAreaObeyWorldCircleConstraint(westIslandID, false);
    rmSetAreaMix(westIslandID, "saguenay tundra");

    rmBuildAllAreas();

    // Text
    rmSetStatusText("",0.30);

    // Set up player areas.
    float playerFraction = rmAreaTilesToFraction(100);
    for(i = 0; < cNumberNonGaiaPlayers)
    {
        // Create the area.
        int id = rmCreateArea("Player"+i);
        // Assign to the player.
        rmSetPlayerArea(i, id);
        // Set the size.
        rmSetAreaSize(id, playerFraction, playerFraction);
        rmAddAreaToClass(id, classPlayer);
        rmSetAreaMinBlobs(id, 1);
        rmSetAreaMaxBlobs(id, 1);
        rmAddAreaConstraint(id, playerConstraint);
        rmAddAreaConstraint(id, playerEdgeConstraint);
        rmSetAreaMix(id, "saguenay tundra");
        rmSetAreaWarnFailure(id, false);
    }

    // Build the areas.
    rmBuildAllAreas();

    rmSetStatusText("",0.40);

    int failCount = -1;
    int numTries = cNumberNonGaiaPlayers+2;

    // PLAYER STARTING RESOURCES

    rmClearClosestPointConstraints();
    int TCfloat = 10;

    int TCID = rmCreateObjectDef("Player TC");

    if (rmGetNomadStart())
    {
        rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
    }
    else
    {
        rmAddObjectDefItem(TCID, "TownCenter", 1, 0.0);
    }
    rmSetObjectDefMinDistance(TCID, 0.0);
    rmSetObjectDefMaxDistance(TCID, TCfloat);

    int playerSilverID = rmCreateObjectDef("player mine");
    rmAddObjectDefItem(playerSilverID, "mine", 1, 0);
    rmAddObjectDefConstraint(playerSilverID, avoidTownCenter);
    rmSetObjectDefMinDistance(playerSilverID, 15.0);
    rmSetObjectDefMaxDistance(playerSilverID, 20.0);
    rmAddObjectDefConstraint(playerSilverID, avoidImpassableLand);
    rmAddObjectDefConstraint(playerSilverID, coinEdgeConstraint);

    int playerturkeyID=rmCreateObjectDef("player turkey");
    rmAddObjectDefItem(playerturkeyID, "turkey", rmRandInt(8,10), 10.0);
    rmSetObjectDefMinDistance(playerturkeyID, 10);
    rmSetObjectDefMaxDistance(playerturkeyID, 18);
    rmAddObjectDefConstraint(playerturkeyID, avoidAll);
    rmAddObjectDefConstraint(playerturkeyID, avoidImpassableLand);
    rmAddObjectDefConstraint(playerturkeyID, avoidCliff);
    rmSetObjectDefCreateHerd(playerturkeyID, true);

    int playerNuggetID= rmCreateObjectDef("player nugget");
    rmAddObjectDefItem(playerNuggetID, "Nugget", 1, 0.0);
    rmSetNuggetDifficulty(1, 1);
    rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);
    rmAddObjectDefConstraint(playerNuggetID, avoidNugget);
    rmAddObjectDefConstraint(playerNuggetID, avoidAll);
    rmAddObjectDefConstraint(playerNuggetID, avoidCliff);
    rmAddObjectDefConstraint(playerNuggetID, playerEdgeConstraint);
    rmSetObjectDefMinDistance(playerNuggetID, 20.0);
    rmSetObjectDefMaxDistance(playerNuggetID, 30.0);

    int playerTreeID = rmCreateObjectDef("player trees");
    rmAddObjectDefItem(playerTreeID, "TreeHollows", rmRandInt(5,10), 8.0);
    rmSetObjectDefMinDistance(playerTreeID, 15);
    rmSetObjectDefMaxDistance(playerTreeID, 20);
    rmAddObjectDefConstraint(playerTreeID, avoidAll);
    rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);

    for(i = 1; < cNumberPlayers)
    {
        rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
        rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
        rmPlaceObjectDefAtLoc(playerSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
        rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
        rmPlaceObjectDefAtLoc(playerturkeyID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
        rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

        if(ypIsAsian(i) && rmGetNomadStart() == false)
            rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

        rmClearClosestPointConstraints();
    }

    rmSetStatusText("",0.50);

    // Define and place Nuggets

    int nuggeteasyID= rmCreateObjectDef("nugget easy");
    rmAddObjectDefItem(nuggeteasyID, "Nugget", 1, 0.0);
    rmSetNuggetDifficulty(1, 1);
    rmSetObjectDefMinDistance(nuggeteasyID, 0.0);
    rmSetObjectDefMaxDistance(nuggeteasyID, rmXFractionToMeters(0.5));
    rmAddObjectDefConstraint(nuggeteasyID, avoidNugget);
    rmAddObjectDefConstraint(nuggeteasyID, avoidTownCenter);
    rmAddObjectDefConstraint(nuggeteasyID, avoidCliff);
    rmAddObjectDefConstraint(nuggeteasyID, avoidAll);
    rmAddObjectDefConstraint(nuggeteasyID, avoidImpassableLand);
    rmAddObjectDefConstraint(nuggeteasyID, playerEdgeConstraint);
    rmAddObjectDefConstraint(nuggeteasyID, avoidLake);
    rmPlaceObjectDefAtLoc(nuggeteasyID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);

    int nuggetmediumEastID= rmCreateObjectDef("nugget medium east");
    rmAddObjectDefItem(nuggetmediumEastID, "Nugget", 1, 0.0);
    rmSetNuggetDifficulty(2, 2);
    rmSetObjectDefMinDistance(nuggetmediumEastID, 0.0);
    rmSetObjectDefMaxDistance(nuggetmediumEastID, rmXFractionToMeters(0.5));
    rmAddObjectDefConstraint(nuggetmediumEastID, avoidNugget);
    rmAddObjectDefConstraint(nuggetmediumEastID, avoidTownCenter);
    rmAddObjectDefConstraint(nuggetmediumEastID, avoidCliff);
    rmAddObjectDefConstraint(nuggetmediumEastID, avoidAll);
    rmAddObjectDefConstraint(nuggetmediumEastID, avoidImpassableLand);
    rmAddObjectDefConstraint(nuggetmediumEastID, playerEdgeConstraint);
    rmAddObjectDefConstraint(nuggetmediumEastID, Eastward);
    rmAddObjectDefConstraint(nuggetmediumEastID, avoidLake);
    rmPlaceObjectDefAtLoc(nuggetmediumEastID, 0, 0.5, 0.5, 2);

    int nuggetmediumWestID= rmCreateObjectDef("nugget medium west");
    rmAddObjectDefItem(nuggetmediumWestID, "Nugget", 1, 0.0);
    rmSetNuggetDifficulty(2, 2);
    rmSetObjectDefMinDistance(nuggetmediumWestID, 0.0);
    rmSetObjectDefMaxDistance(nuggetmediumWestID, rmXFractionToMeters(0.5));
    rmAddObjectDefConstraint(nuggetmediumWestID, avoidNugget);
    rmAddObjectDefConstraint(nuggetmediumWestID, avoidTownCenter);
    rmAddObjectDefConstraint(nuggetmediumWestID, avoidCliff);
    rmAddObjectDefConstraint(nuggetmediumWestID, avoidAll);
    rmAddObjectDefConstraint(nuggetmediumWestID, avoidImpassableLand);
    rmAddObjectDefConstraint(nuggetmediumWestID, playerEdgeConstraint);
    rmAddObjectDefConstraint(nuggetmediumWestID, Westward);
    rmAddObjectDefConstraint(nuggetmediumWestID, avoidLake);
    rmPlaceObjectDefAtLoc(nuggetmediumWestID, 0, 0.5, 0.5, 2);

    int nuggethardID= rmCreateObjectDef("nugget hard");
    rmAddObjectDefItem(nuggethardID, "Nugget", 1, 0.0);
    rmSetNuggetDifficulty(3, 3);
    rmSetObjectDefMinDistance(nuggethardID, 0.0);
    rmSetObjectDefMaxDistance(nuggethardID, rmXFractionToMeters(0.5));
    rmAddObjectDefConstraint(nuggethardID, avoidNugget);
    rmAddObjectDefConstraint(nuggethardID, avoidTownCenter);
    rmAddObjectDefConstraint(nuggethardID, avoidCliff);
    rmAddObjectDefConstraint(nuggethardID, avoidAll);
    rmAddObjectDefConstraint(nuggethardID, playerEdgeConstraint);
    rmAddObjectDefConstraint(nuggethardID, avoidImpassableLand);
    rmAddObjectDefConstraint(nuggethardID, avoidLake);
    rmPlaceObjectDefAtLoc(nuggethardID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);

    if(rmRandFloat(0,1) < 0.50) //only places more hard nuggets 50% of the time
    {
        int nuggethard2ID= rmCreateObjectDef("nugget hard2");
        rmAddObjectDefItem(nuggethard2ID, "Nugget", 1, 0.0);
        rmSetNuggetDifficulty(3, 3);
        rmSetObjectDefMinDistance(nuggethard2ID, 0.0);
        rmSetObjectDefMaxDistance(nuggethard2ID, rmXFractionToMeters(0.5));
        rmAddObjectDefConstraint(nuggethard2ID, avoidNugget);
        rmAddObjectDefConstraint(nuggethard2ID, avoidTownCenter);
        rmAddObjectDefConstraint(nuggethard2ID, avoidCliff);
        rmAddObjectDefConstraint(nuggethard2ID, avoidAll);
        rmAddObjectDefConstraint(nuggethard2ID, avoidImpassableLand);
        rmAddObjectDefConstraint(nuggethard2ID, playerEdgeConstraint);
        rmAddObjectDefConstraint(nuggethard2ID, avoidLake);
        rmPlaceObjectDefAtLoc(nuggethard2ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);
    }
    else if (rmRandFloat(0,1) < 0.25)  //only try to place nuts 25% of the time
    {
        int nuggetnutsID= rmCreateObjectDef("nugget nuts");
        rmAddObjectDefItem(nuggetnutsID, "Nugget", 1, 0.0);
        rmSetNuggetDifficulty(4, 4);
        rmSetObjectDefMinDistance(nuggetnutsID, 0.0);
        rmSetObjectDefMaxDistance(nuggetnutsID, rmXFractionToMeters(0.5));
        rmAddObjectDefConstraint(nuggetnutsID, avoidNugget);
        rmAddObjectDefConstraint(nuggetnutsID, avoidTownCenter);
        rmAddObjectDefConstraint(nuggetnutsID, avoidCliff);
        rmAddObjectDefConstraint(nuggetnutsID, avoidAll);
        rmAddObjectDefConstraint(nuggetnutsID, avoidImpassableLand);
        rmAddObjectDefConstraint(nuggetnutsID, playerEdgeConstraint);
        rmAddObjectDefConstraint(nuggetnutsID, avoidLake);
        rmPlaceObjectDefAtLoc(nuggetnutsID, 0, 0.5, 0.5, 2);
    }

    // Silver mines

    rmSetStatusText("",0.60);

    int silverType = -1;
    int silverCount = (cNumberNonGaiaPlayers*1.5 + rmRandInt(1,2));
    if (cNumberNonGaiaPlayers > 5)
        silverCount = silverCount - 5;
    rmEchoInfo("silver count = "+silverCount);

    for(i=0; < silverCount)
    {
        int silverID = rmCreateObjectDef("silverEast "+i);
        rmAddObjectDefItem(silverID, "mine", 1, 0.0);
        rmSetObjectDefMinDistance(silverID, 0.0);
        rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
        rmAddObjectDefConstraint(silverID, avoidCoin);
        rmAddObjectDefConstraint(silverID, avoidAll);
        rmAddObjectDefConstraint(silverID, avoidTownCenterFar);
        rmAddObjectDefConstraint(silverID, avoidImpassableLand);
        rmAddObjectDefConstraint(silverID, coinEdgeConstraint);
        rmAddObjectDefConstraint(silverID, Northward);
        rmAddObjectDefConstraint(silverID, avoidLake);
        rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
    }

    for(i=0; < silverCount)
    {
        int silverWestID = rmCreateObjectDef("silverWest "+i);
        rmAddObjectDefItem(silverWestID, "mine", 1, 0.0);
        rmSetObjectDefMinDistance(silverWestID, 0.0);
        rmSetObjectDefMaxDistance(silverWestID, rmXFractionToMeters(0.5));
        rmAddObjectDefConstraint(silverWestID, avoidCoin);
        rmAddObjectDefConstraint(silverWestID, avoidAll);
        rmAddObjectDefConstraint(silverWestID, avoidTownCenterFar);
        rmAddObjectDefConstraint(silverWestID, avoidImpassableLand);
        rmAddObjectDefConstraint(silverWestID, Southward);
        rmAddObjectDefConstraint(silverWestID, avoidLake);
        rmAddObjectDefConstraint(silverWestID, coinEdgeConstraint);
        rmPlaceObjectDefAtLoc(silverWestID, 0, 0.5, 0.5);
    }


    // Mines to fill in the large gaps

    silverCount = 2;
    for(i=0; < silverCount)
    {
        int silverEastRandomID = rmCreateObjectDef("silverEastRandom "+i);
        rmAddObjectDefItem(silverEastRandomID, "mine", 1, 0.0);
        rmSetObjectDefMinDistance(silverEastRandomID, 0.0);
        rmSetObjectDefMaxDistance(silverEastRandomID, rmXFractionToMeters(0.2));
        rmAddObjectDefConstraint(silverEastRandomID, avoidCoinFar);
        rmAddObjectDefConstraint(silverEastRandomID, avoidAll);
        rmAddObjectDefConstraint(silverEastRandomID, longAvoidImpassableLand);
        rmAddObjectDefConstraint(silverEastRandomID, coinEdgeConstraint);
        rmAddObjectDefConstraint(silverEastRandomID, Northward);
        rmAddObjectDefConstraint(silverEastRandomID, avoidLake);
        rmPlaceObjectDefAtLoc(silverEastRandomID, 0, 0.5, 0.5);
    }

    silverCount = 2;
    for(i=0; < silverCount)
    {
        int silverWestRandomID = rmCreateObjectDef("silverWestRandom "+i);
        rmAddObjectDefItem(silverWestRandomID, "mine", 1, 0.0);
        rmSetObjectDefMinDistance(silverWestRandomID, 0.0);
        rmSetObjectDefMaxDistance(silverWestRandomID, rmXFractionToMeters(0.2));
        rmAddObjectDefConstraint(silverWestRandomID, avoidCoinFar);
        rmAddObjectDefConstraint(silverWestRandomID, avoidAll);
        rmAddObjectDefConstraint(silverWestRandomID, longAvoidImpassableLand);
        rmAddObjectDefConstraint(silverWestRandomID, coinEdgeConstraint);
        rmAddObjectDefConstraint(silverWestRandomID, Southward);
        rmAddObjectDefConstraint(silverWestRandomID, avoidLake);
        rmPlaceObjectDefAtLoc(silverWestRandomID, 0, 0.5, 0.5);
    }

    rmSetStatusText("",0.70);

    // Forest areas

    if (cNumberNonGaiaPlayers > 4)
        numTries=3*cNumberNonGaiaPlayers;
    else
        numTries=5*cNumberNonGaiaPlayers;
    failCount=0;
    for (i=0; <numTries)
    {
        int forestID=rmCreateArea("forestID"+i, westIslandID);
        rmSetAreaWarnFailure(forestID, false);
        rmSetAreaSize(forestID, rmAreaTilesToFraction(360), rmAreaTilesToFraction(210));
        rmSetAreaForestType(forestID, "Hollows Forest");
        rmSetAreaForestDensity(forestID, 0.7);
        rmSetAreaForestClumpiness(forestID, 0.2);
        rmSetAreaForestUnderbrush(forestID, 0.6);
        rmSetAreaMinBlobs(forestID, 1);
        rmSetAreaMaxBlobs(forestID, 10);
        rmSetAreaMinBlobDistance(forestID, 5.0);
        rmSetAreaMaxBlobDistance(forestID, 20.0);
        rmSetAreaCoherence(forestID, 0.4);
        rmSetAreaSmoothDistance(forestID, 10);
        rmAddAreaToClass(forestID, rmClassID("classForest"));
        rmAddAreaConstraint(forestID, avoidForest);
        rmAddAreaConstraint(forestID, shortAvoidImportantItem);
        rmAddAreaConstraint(forestID, playerConstraint);
        rmAddAreaConstraint(forestID, avoidCliff);
        rmAddAreaConstraint(forestID, avoidAll);
        rmAddAreaConstraint(forestID, avoidLake);
        if (rmBuildArea(forestID)==false)
        {
            // Stop trying once we fail 5 times in a row.
            failCount++;
            if (failCount==10)
                break;
        }
        else
            failCount=0;
    }

    if (cNumberNonGaiaPlayers > 4)
        numTries=3*cNumberNonGaiaPlayers;
    else
        numTries=5*cNumberNonGaiaPlayers;
    failCount=0;
    for (i=0; <numTries)
    {
        int forestEastID=rmCreateArea("forestEastID"+i, eastIslandID);
        rmSetAreaWarnFailure(forestEastID, false);
        rmSetAreaSize(forestEastID, rmAreaTilesToFraction(360), rmAreaTilesToFraction(210));
        rmSetAreaForestType(forestEastID, "Hollows Forest");
        rmSetAreaForestDensity(forestEastID, 0.7);
        rmSetAreaForestClumpiness(forestEastID, 0.2);
        rmSetAreaForestUnderbrush(forestEastID, 0.6);
        rmSetAreaMinBlobs(forestEastID, 2);
        rmSetAreaMaxBlobs(forestEastID, 10);
        rmSetAreaMinBlobDistance(forestEastID, 5.0);
        rmSetAreaMaxBlobDistance(forestEastID, 20.0);
        rmSetAreaCoherence(forestEastID, 0.4);
        rmSetAreaSmoothDistance(forestEastID, 10);
        rmAddAreaToClass(forestEastID, rmClassID("classForest"));
        rmAddAreaConstraint(forestEastID, avoidForest);
        rmAddAreaConstraint(forestEastID, shortAvoidImportantItem);
        rmAddAreaConstraint(forestEastID, playerConstraint);
        rmAddAreaConstraint(forestEastID, avoidCliff);
        rmAddAreaConstraint(forestEastID, avoidAll);
        rmAddAreaConstraint(forestEastID, avoidLake);
        if(rmBuildArea(forestEastID)==false)
        {
            // Stop trying once we fail 5 times in a row.
            failCount++;
            if (failCount==10)
                break;
        }
        else
            failCount=0;
    }

    numTries=9*cNumberNonGaiaPlayers;
    failCount=0;
    for (i=0; <numTries)
    {
        int forestRandomID=rmCreateArea("forestRandomID"+i);
        rmSetAreaWarnFailure(forestRandomID, false);
        rmSetAreaSize(forestRandomID, rmAreaTilesToFraction(70), rmAreaTilesToFraction(120));
        rmSetAreaForestType(forestRandomID, "Hollows Forest");
        rmSetAreaForestDensity(forestRandomID, 0.6);
        rmSetAreaForestClumpiness(forestRandomID, 0.5);
        rmSetAreaForestUnderbrush(forestRandomID, 0.4);
        rmSetAreaMinBlobs(forestRandomID, 2);
        rmSetAreaMaxBlobs(forestRandomID, 6);
        rmSetAreaMinBlobDistance(forestRandomID, 5.0);
        rmSetAreaMaxBlobDistance(forestRandomID, 15.0);
        rmSetAreaCoherence(forestRandomID, 0.4);
        rmSetAreaSmoothDistance(forestRandomID, 10);
        rmAddAreaToClass(forestRandomID, rmClassID("classForest"));
        rmAddAreaConstraint(forestRandomID, avoidForestFar);
        rmAddAreaConstraint(forestRandomID, shortAvoidImportantItem);
        rmAddAreaConstraint(forestRandomID, playerConstraint);
        rmAddAreaConstraint(forestRandomID, avoidCliff);
        rmAddAreaConstraint(forestRandomID, avoidAll);
        rmAddAreaConstraint(forestRandomID, avoidLake);
        if(rmBuildArea(forestRandomID)==false)
        {
            // Stop trying once we fail 5 times in a row.
            failCount++;
            if(failCount==10)
                break;
        }
        else
            failCount=0;
    }

    // Resources that can be placed after forests

    int deerCount = 0;
    if (cNumberNonGaiaPlayers<7)
    {
        deerCount =1.5*cNumberNonGaiaPlayers;
    }
    else
    {
        deerCount =0.80*cNumberNonGaiaPlayers;
    }

    rmEchoInfo("deer count = "+deerCount);

    for (i=0; <deerCount)
    {
        int deerEastID = rmCreateObjectDef("deer east herd " +i);
        rmAddObjectDefItem(deerEastID, "deer", rmRandInt(8,10), 13);
        rmSetObjectDefMinDistance(deerEastID, 0.0);
        rmSetObjectDefMaxDistance(deerEastID, rmXFractionToMeters(0.8));
        rmAddObjectDefConstraint(deerEastID, avoiddeer);
        rmAddObjectDefConstraint(deerEastID, avoidturkey);
        rmAddObjectDefConstraint(deerEastID, avoidAll);
        rmAddObjectDefConstraint(deerEastID, avoidCliff);
        rmAddObjectDefConstraint(deerEastID, Eastward);
        rmAddObjectDefConstraint(deerEastID, avoidLake);
        rmSetObjectDefCreateHerd(deerEastID, true);

        rmPlaceObjectDefAtLoc(deerEastID, 0, 0.5, 0.5);
    }

    for (i=0; <deerCount)
    {
        int deerWestID = rmCreateObjectDef("deer west herd " +i);
        rmAddObjectDefItem(deerWestID, "deer", rmRandInt(8,10), 13);
        rmSetObjectDefMinDistance(deerWestID, 0.0);
        rmSetObjectDefMaxDistance(deerWestID, rmXFractionToMeters(0.8));
        rmAddObjectDefConstraint(deerWestID, avoiddeer);
        rmAddObjectDefConstraint(deerWestID, avoidturkey);
        rmAddObjectDefConstraint(deerWestID, avoidAll);
        rmAddObjectDefConstraint(deerWestID, Westward);
        rmAddObjectDefConstraint(deerWestID, avoidLake);
        rmSetObjectDefCreateHerd(deerWestID, true);
        rmPlaceObjectDefAtLoc(deerWestID, 0, 0.5, 0.5);
    }

    rmSetStatusText("",0.80);

    if (cNumberNonGaiaPlayers > 4)
    {
        deerCount = 4;
        for (i = 0; < deerCount)
        {
            int deerRandomID = rmCreateObjectDef("deer random herd " +i);
            rmAddObjectDefItem(deerRandomID, "deer", rmRandInt(3,6), 11);
            rmSetObjectDefMinDistance(deerRandomID, 0.0);
            rmSetObjectDefMaxDistance(deerRandomID, rmXFractionToMeters(0.8));
            rmAddObjectDefConstraint(deerRandomID, avoiddeerFar);
            rmAddObjectDefConstraint(deerRandomID, avoidturkey);
            rmAddObjectDefConstraint(deerRandomID, avoidAll);
            rmAddObjectDefConstraint(deerRandomID, avoidLake);
            rmSetObjectDefCreateHerd(deerRandomID, true);
            rmPlaceObjectDefAtLoc(deerRandomID, 0, 0.5, 0.5);
        }
    }

    rmSetStatusText("",0.90);

    rmCreateTrigger("DeathlyHollows");
    rmSwitchToTrigger(rmTriggerID("DeathlyHollows"));
    rmAddTriggerEffect("Deathly Hollows");
    // rmSetTriggerEffectParamInt("PlayerID", 0);
    // rmSetTriggerEffectParam("Message", "\");} xsDisableSelf();} include \"dhollows.xs\"; rule Alice { xsDisableSelf(); if (true) {//");


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
