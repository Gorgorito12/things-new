// Sahara

// Main entry point for random map script
include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
//include "GWevent.xs";

void main(void)
{
   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

/////////////////////////////////////////////////////  WOL African Unique Resources. /////////////////////////////////////////////////////
//
// 1. Define the nature of the map. "0" means desert, "1" means jungle, "2" means savannah.
// 2. It is standarized that Desert = egyptian, Jungle = Tribal, Savannah = timbuktu.
	int AURbuildingset=0;
// 3. Now, let's define the meaning of each subCiv.
// 4. An African RM can have up to 6 AURs, no more than that (otherwise that will require extra coding) 

	string AUR1="AURblackoil";
	string AUR2="AURCattle";
	string AUR3="AURCoffee";
	string AUR4="AURDiamonds";
	string AUR5="AURGems";
	string AUR6="AURGold";
	string AUR7="AURIncense";
	string AUR8="AURIvory";
	string AUR9="AURPalmoil";
	string AUR10="AURPapyrus";
	string AUR11="AURSalt";
	string AUR12="AURSilk";
	string AUR13="AURStatuettes";
	string AUR14="AURTreasures";
	string AUR15="AURCocoa";
	string AUR16="AUREbony";
	string AUR17="AURManioc";
	string AUR18="AURRubber";
	string AUR19="AURSlaves";
	string AUR20="AURTextiles";
	string AUR21="AURVanilla";
	string ArchitectureSet = "";
	
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int subCiv3=-1;
	int subCiv4=-1;
	int subCiv5=-1;

	int AURrandomizer = rmRandInt(1,14);

// THE RANDOMIZATION

	if (AURbuildingset == 0)
	{
			ArchitectureSet = "egyptian";
			if (AURrandomizer == 1)  
				AUR1="AURblackoil"; AUR2="AURCattle"; AUR3="AURCoffee"; AUR4="AURDiamonds"; AUR5="AURGems"; AUR6="AURGold"; AUR7="AURIncense"; AUR8="AURIvory"; AUR9="AURPalmoil"; AUR10="AURPapyrus"; AUR11="AURSalt"; AUR12="AURStatuettes"; AUR13="AURTreasures"; AUR14="AURSilk"; 
			if (AURrandomizer == 2)  
				AUR1="AURSilk"; AUR2="AURblackoil"; AUR3="AURCattle"; AUR4="AURCoffee"; AUR5="AURDiamonds"; AUR6="AURGems"; AUR7="AURGold"; AUR8="AURIncense"; AUR9="AURIvory"; AUR10="AURPalmoil"; AUR11="AURPapyrus"; AUR12="AURSalt"; AUR13="AURStatuettes"; AUR14="AURTreasures";
			if (AURrandomizer == 3)  
				AUR1="AURTreasures"; AUR2="AURSilk"; AUR3="AURblackoil"; AUR4="AURCattle"; AUR5="AURCoffee"; AUR6="AURDiamonds"; AUR7="AURGems"; AUR8="AURGold"; AUR9="AURIncense"; AUR10="AURIvory"; AUR11="AURPalmoil"; AUR12="AURPapyrus"; AUR13="AURSalt"; AUR14="AURStatuettes";
			if (AURrandomizer == 4)  
				AUR1="AURStatuettes"; AUR2="AURTreasures"; AUR3="AURSilk"; AUR4="AURblackoil"; AUR5="AURCattle"; AUR6="AURCoffee"; AUR7="AURDiamonds"; AUR8="AURGems"; AUR9="AURGold"; AUR10="AURIncense"; AUR11="AURIvory"; AUR12="AURPalmoil"; AUR13="AURPapyrus"; AUR14="AURSalt";
			if (AURrandomizer == 5)  
				AUR1="AURSalt"; AUR2="AURStatuettes"; AUR3="AURTreasures"; AUR4="AURSilk"; AUR5="AURblackoil"; AUR6="AURCattle"; AUR7="AURCoffee"; AUR8="AURDiamonds"; AUR9="AURGems"; AUR10="AURGold"; AUR11="AURIncense"; AUR12="AURIvory"; AUR13="AURPalmoil"; AUR14="AURPapyrus";
			if (AURrandomizer == 6)  
				AUR1="AURPapyrus"; AUR2="AURSalt"; AUR3="AURStatuettes"; AUR4="AURTreasures"; AUR5="AURSilk"; AUR6="AURblackoil"; AUR7="AURCattle"; AUR8="AURCoffee"; AUR9="AURDiamonds"; AUR10="AURGems"; AUR11="AURGold"; AUR12="AURIncense"; AUR13="AURIvory"; AUR14="AURPalmoil";
			if (AURrandomizer == 7)  
				AUR1="AURPalmoil"; AUR2="AURPapyrus"; AUR3="AURSalt"; AUR4="AURStatuettes"; AUR5="AURTreasures"; AUR6="AURSilk"; AUR7="AURblackoil"; AUR8="AURCattle"; AUR9="AURCoffee"; AUR10="AURDiamonds"; AUR11="AURGems"; AUR12="AURGold"; AUR13="AURIncense"; AUR14="AURIvory";
			if (AURrandomizer == 8)  
				AUR1="AURIvory"; AUR2="AURPalmoil"; AUR3="AURPapyrus"; AUR4="AURSalt"; AUR5="AURStatuettes"; AUR6="AURTreasures"; AUR7="AURSilk"; AUR8="AURblackoil"; AUR9="AURCattle"; AUR10="AURCoffee"; AUR11="AURDiamonds"; AUR12="AURGems"; AUR13="AURGold"; AUR14="AURIncense";
			if (AURrandomizer == 9)  
				AUR1="AURIncense"; AUR2="AURIvory"; AUR3="AURPalmoil"; AUR4="AURPapyrus"; AUR5="AURSalt"; AUR6="AURStatuettes"; AUR7="AURTreasures"; AUR8="AURSilk"; AUR9="AURblackoil"; AUR10="AURCattle"; AUR11="AURCoffee"; AUR12="AURDiamonds"; AUR13="AURGems"; AUR14="AURGold";
			if (AURrandomizer == 10)  
				AUR1="AURGold"; AUR2="AURIncense"; AUR3="AURIvory"; AUR4="AURPalmoil"; AUR5="AURPapyrus"; AUR6="AURSalt"; AUR7="AURStatuettes"; AUR8="AURTreasures"; AUR9="AURSilk"; AUR10="AURblackoil"; AUR11="AURCattle"; AUR12="AURCoffee"; AUR13="AURDiamonds"; AUR14="AURGems";
			if (AURrandomizer == 11)  
				AUR1="AURGems"; AUR2="AURGold"; AUR3="AURIncense"; AUR4="AURIvory"; AUR5="AURPalmoil"; AUR6="AURPapyrus"; AUR7="AURSalt"; AUR8="AURStatuettes"; AUR9="AURTreasures"; AUR10="AURSilk"; AUR11="AURblackoil"; AUR12="AURCattle"; AUR13="AURCoffee"; AUR14="AURDiamonds";
			if (AURrandomizer == 12)  
				AUR1="AURDiamonds"; AUR2="AURGems"; AUR3="AURGold"; AUR4="AURIncense"; AUR5="AURIvory"; AUR6="AURPalmoil"; AUR7="AURPapyrus"; AUR8="AURSalt"; AUR9="AURStatuettes"; AUR10="AURTreasures"; AUR11="AURSilk"; AUR12="AURblackoil"; AUR13="AURCattle"; AUR14="AURCoffee";
			if (AURrandomizer == 13)  
				AUR1="AURCoffee"; AUR2="AURDiamonds"; AUR3="AURGems"; AUR4="AURGold"; AUR5="AURIncense"; AUR6="AURIvory"; AUR7="AURPalmoil"; AUR8="AURPapyrus"; AUR9="AURSalt"; AUR10="AURStatuettes"; AUR11="AURTreasures"; AUR12="AURSilk"; AUR13="AURblackoil"; AUR14="AURCattle";
			if (AURrandomizer == 14)  
				AUR1="AURCattle"; AUR2="AURCoffee"; AUR3="AURDiamonds"; AUR4="AURGems"; AUR5="AURGold"; AUR6="AURIncense"; AUR7="AURIvory"; AUR8="AURPalmoil"; AUR9="AURPapyrus"; AUR10="AURSalt"; AUR11="AURStatuettes"; AUR12="AURTreasures"; AUR13="AURSilk"; AUR14="AURblackoil";
	}

		if (rmAllocateSubCivs(6) == true)
		{
			subCiv0=rmGetCivID(AUR1);
			rmEchoInfo("African unique resource is "+subCiv0);
			if (subCiv0 >= 0)
			rmSetSubCiv(0, AUR1);
	
			subCiv1=rmGetCivID(AUR2);
			rmEchoInfo("African unique resource is "+subCiv1);
			if (subCiv1 >= 0)
			rmSetSubCiv(1, AUR2);

			subCiv2=rmGetCivID(AUR3);
			rmEchoInfo("African unique resource is "+subCiv2);
			if (subCiv2 >= 0)
			rmSetSubCiv(2, AUR3);

			subCiv3=rmGetCivID(AUR4);
			rmEchoInfo("African unique resource is "+subCiv3);
			if (subCiv3 >= 0)
			rmSetSubCiv(3, AUR4);
		
			subCiv4=rmGetCivID(AUR5);
			rmEchoInfo("African unique resource is "+subCiv4);
			if (subCiv4 >= 0)
			rmSetSubCiv(4, AUR5);
		
			subCiv5=rmGetCivID(AUR6);
			rmEchoInfo("African unique resource is "+subCiv5);
			if (subCiv5 >= 0)
			rmSetSubCiv(5, AUR6);
		}	
		
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////// MAP PARAMETERS /////////////////////////////////////////////////////

	// Picks the map size
	//  int playerTiles=10000; old setting
	int playerTiles = 18000;
		if (cNumberNonGaiaPlayers >4)
			playerTiles = 16000;
		if (cNumberNonGaiaPlayers >6)
			playerTiles = 12000;		

		

	int size=3.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);
	rmSetMapElevationParameters(cElevTurbulence, 0.04, 3, 0.5, 20.0);
	rmSetMapElevationHeightBlend(1);

	// Picks a default water height
	rmSetSeaLevel(4.0);

    // Picks default terrain and water
	rmSetSeaType("Amazon River");
	rmSetBaseTerrainMix("sahara");
	rmTerrainInitialize("wotta\sahara", 4.0);
	rmSetMapType("AFRICANdesert");
 	rmSetLightingSet("caribbean");

  	
	// Choose mercs.
	chooseMercs();
	//gwevent();

	// Corner constraint.
	rmSetWorldCircleConstraint(false);

	int classPlayer=rmDefineClass("player");
	rmDefineClass("classHill");
	rmDefineClass("classPatch");
	rmDefineClass("starting settlement");
	rmDefineClass("startingUnit");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("classCliff");
	rmDefineClass("secrets");
	rmDefineClass("classNugget");
	rmDefineClass("center");
	int canyon=rmDefineClass("canyon");

	
	///////////////////////////////////////////////////// CONSTRAINTS /////////////////////////////////////////////////////
	
	
	
	int avoidVultures=rmCreateTypeDistanceConstraint("avoids Vultures", "PropVulturePerching", 40.0);
	int avoidCanyons=rmCreateClassDistanceConstraint("avoid canyons", rmClassID("canyon"), 35.0);
	int shortAvoidCanyons=rmCreateClassDistanceConstraint("short avoid canyons", rmClassID("canyon"), 15.0);
	int veryShortAvoidCanyons=rmCreateClassDistanceConstraint("very short avoid canyons", rmClassID("canyon"), 4.0);
	int avoidNatives=rmCreateClassDistanceConstraint("avoid natives", rmClassID("natives"), 15.0);
	int shortAvoidNatives=rmCreateClassDistanceConstraint("short avoid natives", rmClassID("natives"), 10.0);
	int avoidSilver=rmCreateTypeDistanceConstraint("gold avoid gold", "Mine", 55.0);
	int shortAvoidSilver=rmCreateTypeDistanceConstraint("short gold avoid gold", "Mine", 20.0);
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 10.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 4.0);
	int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), rmXFractionToMeters(0.23));
	int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), rmXFractionToMeters(0.10));
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 50.0);
	int shortForestConstraint=rmCreateClassDistanceConstraint("short forest vs. forest", rmClassID("classForest"), 10.0);
	int avoidHill = rmCreateTypeDistanceConstraint("avoid hill", "ypKingsHill", 8.0);

	int avoidAll=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int shortAvoidResource=rmCreateTypeDistanceConstraint("short resource avoid resource", "resource", 4.0);
	int avoidBuzzards=rmCreateTypeDistanceConstraint("buzzard avoid buzzard", "BuzzardFlock", 70.0);
	int avoidBison=rmCreateTypeDistanceConstraint("avoid Bison", "Bison", 40);
	int avoidPronghorn=rmCreateTypeDistanceConstraint("avoid Pronghorn", "Pronghorn", 40);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("long stay away from players", classPlayer, 40.0);
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 30.0);
	int mediumPlayerConstraint=rmCreateClassDistanceConstraint("medium stay away from players", classPlayer, 20.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players short", classPlayer, 8.0);
	int avoidNugget=rmCreateClassDistanceConstraint("nugget vs. nugget long", rmClassID("classNugget"), 60.0);
	int shortAvoidNugget=rmCreateClassDistanceConstraint("nugget vs. nugget short", rmClassID("classNugget"), 8.0);

	int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 8.0);
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 5.0);

	// Trade route
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("short trade route", 3.0);
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 10.0);
	int avoidWaterTradeRoute = rmCreateClassDistanceConstraint("avoid WTR", rmClassID("classWaterTradeRoute"), 10.0);
	int avoidTradeRouteSockets=rmCreateTypeDistanceConstraint("avoid Trade Socket", "sockettraderoute", 10);	
	
		
///////////////////////////////////////////////////// STARTING RESOURCES /////////////////////////////////////////////////////

	int TCID = rmCreateObjectDef("player TC");
		if (rmGetNomadStart())
		{
			rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
		}
		else
		{
            rmAddObjectDefItem(TCID, "townCenter", 1, 0);
		}
	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, 10.0);
	rmAddObjectDefConstraint(TCID, avoidTradeRoute);
	rmAddObjectDefToClass(TCID, rmClassID("player"));
	rmAddObjectDefToClass(TCID, rmClassID("startingUnit"));

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 8.0);
	rmSetObjectDefMaxDistance(startingUnits, 12.0);
	rmAddObjectDefToClass(startingUnits, rmClassID("startingUnit"));
	rmAddObjectDefConstraint(startingUnits, avoidStartingUnits);

	int playerSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(playerSilverID, "MineSalt", 1, 0);
	rmAddObjectDefConstraint(playerSilverID, avoidTradeRoute);
	rmSetObjectDefMinDistance(playerSilverID, 20.0);
	rmSetObjectDefMaxDistance(playerSilverID, 25.0);
	//rmAddObjectDefConstraint(playerSilverID, avoidAll);
	rmAddObjectDefToClass(playerSilverID, rmClassID("startingUnit"));
	rmAddObjectDefConstraint(playerSilverID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerSilverID, avoidStartingUnits);

	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	//edit
//	rmAddObjectDefItem(StartAreaTreeID, "treeCaribbean", rmRandInt(7,10), 4.0);
	rmAddObjectDefItem(StartAreaTreeID, "treeCaribbean", rmRandInt(15,15), 4.0);
	rmAddObjectDefItem(StartAreaTreeID, "UnderbrushDesert", rmRandInt(4,6), 4.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 8);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 15);
	rmAddObjectDefToClass(StartAreaTreeID, rmClassID("startingUnit"));
	rmAddObjectDefConstraint(StartAreaTreeID, avoidImpassableLand);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRoute);
	//rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidSilver);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartingUnits);
	//rmAddObjectDefConstraint(StartAreaTreeID, avoidResource);
	
	//edit
	int playerTreeID=rmCreateObjectDef("player trees");
    rmAddObjectDefItem(playerTreeID, "treeCaribbean", rmRandInt(15,15), 2.0);
    rmSetObjectDefMinDistance(playerTreeID, 16);
    rmSetObjectDefMaxDistance(playerTreeID, 20);
	rmAddObjectDefConstraint(playerTreeID, avoidAll);
    rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);

	int StartTurkeyID=rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(StartTurkeyID, "DatePalm", 4, 4.0);
	//rmSetObjectDefCreateHerd(StartTurkeyID, true);
	rmSetObjectDefMinDistance(StartTurkeyID, 10);
	rmSetObjectDefMaxDistance(StartTurkeyID, 18);
	rmAddObjectDefToClass(StartTurkeyID, rmClassID("startingUnit"));
	rmAddObjectDefConstraint(StartTurkeyID, avoidImpassableLand);
	rmAddObjectDefConstraint(StartTurkeyID, avoidTradeRoute);
	rmAddObjectDefConstraint(StartTurkeyID, avoidStartingUnits);
	rmAddObjectDefConstraint(StartTurkeyID, avoidResource);

// Player Nuggets
   int playerNuggetID=rmCreateObjectDef("player nugget");
   rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
   rmAddObjectDefToClass(playerNuggetID, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(playerNuggetID, 35.0);
   rmSetObjectDefMaxDistance(playerNuggetID, 45.0);
   rmAddObjectDefConstraint(playerNuggetID, avoidNugget);
   rmAddObjectDefConstraint(playerNuggetID, circleConstraint);

   for(i=1; <cNumberPlayers)
   {
 	rmSetNuggetDifficulty(1, 1);
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }
	
// Text
	rmSetStatusText("",0.2);
	int canyonConstraint=rmCreateClassDistanceConstraint("canyons start away from each other", canyon, 5.0);

	int failCount=0;
	int numTries=cNumberNonGaiaPlayers*15;



// Text
	rmSetStatusText("",0.6);


	
	/////////////////////////////// PLACE TRADE ROUTE ////////////////////////////////////


   int socketID=rmCreateObjectDef("Sahara Route");
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 0.0);
	rmSetObjectDefMaxDistance(socketID, 6.0);
	rmAddObjectDefConstraint(socketID, shortAvoidTradeRoute);

	int tradeRouteID = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.33, rmRandFloat(0.40,0.6));
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, rmRandFloat(0.40,0.60));
	rmAddTradeRouteWaypoint(tradeRouteID, 0.66, rmRandFloat(0.40,0.60));
	rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.5);

	bool placedTradeRouteB = rmBuildTradeRoute(tradeRouteID, "ShortCamelTrain");
	if(placedTradeRouteB == false)
		rmEchoError("Failed to place trade route 2");
	

		rmPlaceObjectDefAtLoc(socketID, 0, 0.15, rmRandFloat(0.47,0.53));
		rmPlaceObjectDefAtLoc(socketID, 0, 0.33, rmRandFloat(0.47,0.53));
		rmPlaceObjectDefAtLoc(socketID, 0, 0.50, rmRandFloat(0.47,0.53));
		rmPlaceObjectDefAtLoc(socketID, 0, 0.66, rmRandFloat(0.47,0.53));
		rmPlaceObjectDefAtLoc(socketID, 0, 0.80, rmRandFloat(0.47,0.53));
		
///////////////////////////////////////////////////// PLACE PLAYERS /////////////////////////////////////////////////////

	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
// 2 team and FFA support
	float OneVOnePlacement=rmRandFloat(0, 1);
	if (cNumberNonGaiaPlayers == 2)
	{
		if ( OneVOnePlacement < 0.5)
		{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.42, 0.15, 0.46, 0.15, 0, 0.05);

			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.40, 0.87, 0.44, 0.87, 0, 0.05);
		}
		else
		{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.40, 0.87, 0.44, 0.87, 0, 0.05);

			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.42, 0.15, 0.46, 0.15, 0, 0.05);
		}
	}
	else if ( cNumberTeams <= 2 && teamZeroCount <= 4 && teamOneCount <= 4)
	{
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.35, 0.6); // 0.5
		rmSetTeamSpacingModifier(0.25);
		rmPlacePlayersCircular(0.38, 0.40, 0);

		rmSetPlacementTeam(1);
		rmSetPlacementSection(0.85, 0.10); // 0.5
		rmSetTeamSpacingModifier(0.25);
		rmPlacePlayersCircular(0.38, 0.40, 0);
	}
	else
	{	
		rmSetTeamSpacingModifier(0.7);
		rmPlacePlayersCircular(0.42, 0.44, 0.0);
	}

/*
if ( cNumberTeams == 2 )
	{
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.60, 0.10, 0.65, 0.1, 0, 0.002);
	
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.50, 0.9, 0.55, 0.9, 0, 0.002);
	}
	else
	{
  		rmSetPlacementSection(0.0, 0.95);
		rmPlacePlayersCircular(0.35, 0.40, 0.0);
	}
*/
   // Set up player areas.
   float playerFraction=rmAreaTilesToFraction(100);
   for(i=1; <cNumberPlayers)
   {
      // Create the area.
      int id=rmCreateArea("Player"+i);
      // Assign to the player.
      rmSetPlayerArea(i, id);
      // Set the size.
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 1);
//      rmAddAreaConstraint(id, playerConstraint); 
//      rmAddAreaConstraint(id, playerEdgeConstraint); 
      rmSetAreaLocPlayer(id, i);
	  rmSetAreaTerrainType(id, "wotta\sahara");
      rmSetAreaWarnFailure(id, false);
   }
	// Build the areas.
   rmBuildAllAreas();

	
	// Text
	rmSetStatusText("",0.8);


//**************************************** cliff embellishments *********************************************
	for(i=1; <cNumberPlayers)
	{
		
		// Test of Marcin's Starting Units stuff...
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    
		rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(playerSilverID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartTurkeyID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(playerTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		
    vector TCLocation=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
    
    if(ypIsAsian(i) && rmGetNomadStart() == false)
      rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    
		//vector closestPoint=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingUnits, i));
		//rmSetHomeCityGatherPoint(i, closestPoint);
	}




///////////////////////////////////////////////////// PLACE AURS /////////////////////////////////////////////////////

			if (subCiv0 == rmGetCivID(AUR1))
		{
			int AURvillageID = -1;
			int AURvillageType = rmRandInt(1,3);
			AURrandomizer = rmRandInt(1,14);
			AURvillageID = rmCreateGrouping("AUR1", AUR1+" "+ArchitectureSet+" "+AURvillageType);
			rmSetGroupingMinDistance(AURvillageID, 0.0);
			rmSetGroupingMaxDistance(AURvillageID, 10.0);
			rmAddGroupingConstraint(AURvillageID, avoidImpassableLand);
			rmPlaceGroupingAtLoc(AURvillageID, 0, 0.65, 0.65);	
		}

			if (subCiv1 == rmGetCivID(AUR2))
		{
			int AURvillageID2 = -1;
			int AURvillageType2 = rmRandInt(1,3);
			AURrandomizer = rmRandInt(1,14);
			AURvillageID2 = rmCreateGrouping("AUR2", AUR2+" "+ArchitectureSet+" "+AURvillageType);
			rmSetGroupingMinDistance(AURvillageID2, 0.0);
			rmSetGroupingMaxDistance(AURvillageID2, 10.0);
			rmAddGroupingConstraint(AURvillageID2, avoidImpassableLand);
			rmPlaceGroupingAtLoc(AURvillageID2, 0, 0.35, 0.35);	
		}

			if (subCiv2 == rmGetCivID(AUR3))
		{
			int AURvillageID3 = -1;
			int AURvillageType3 = rmRandInt(1,3);
			AURrandomizer = rmRandInt(1,14);
			AURvillageID3 = rmCreateGrouping("AUR3", AUR3+" "+ArchitectureSet+" "+AURvillageType);
			rmSetGroupingMinDistance(AURvillageID3, 0.0);
			rmSetGroupingMaxDistance(AURvillageID3, 10.0);
			rmAddGroupingConstraint(AURvillageID3, avoidImpassableLand);
			rmPlaceGroupingAtLoc(AURvillageID3, 0, 0.35, 0.65);	
		}

			if (subCiv3 == rmGetCivID(AUR4))
		{
			int AURvillageID4 = -1;
			int AURvillageType4 = rmRandInt(1,3);
			AURrandomizer = rmRandInt(1,14);
			AURvillageID4 = rmCreateGrouping("AUR4", AUR4+" "+ArchitectureSet+" "+AURvillageType);
			rmSetGroupingMinDistance(AURvillageID4, 0.0);
			rmSetGroupingMaxDistance(AURvillageID4, 10.0);
			rmAddGroupingConstraint(AURvillageID4, avoidImpassableLand);
			rmPlaceGroupingAtLoc(AURvillageID4, 0, 0.65, 0.35);	
		}

// ************************************ FORESTS **************************************


	for(i=0; <cNumberNonGaiaPlayers*5)
	{
		int edgeForestID=rmCreateArea("edgeForest"+i);
		rmSetAreaWarnFailure(edgeForestID, false);
		rmSetAreaSize(edgeForestID, rmAreaTilesToFraction(200), rmAreaTilesToFraction(300));
		rmSetAreaForestType(edgeForestID, "caribbean forest");
		rmSetAreaForestDensity(edgeForestID, 1.0);
		rmSetAreaForestClumpiness(edgeForestID, 1.0);		
		rmSetAreaForestUnderbrush(edgeForestID, 0.0);
		rmAddAreaToClass(edgeForestID, rmClassID("classForest"));
		rmSetAreaMinBlobs(edgeForestID, 1);
		rmSetAreaMaxBlobs(edgeForestID, 3);					
		rmSetAreaMinBlobDistance(edgeForestID, 16.0);
		rmSetAreaMaxBlobDistance(edgeForestID, 30.0);
		rmSetAreaCoherence(edgeForestID, 0.6);
		rmSetAreaSmoothDistance(edgeForestID, 10);
		rmAddAreaConstraint(edgeForestID, shortPlayerConstraint);
		rmAddAreaConstraint(edgeForestID, forestConstraint); 
		rmAddAreaConstraint(edgeForestID, shortAvoidSilver);  
		rmAddAreaConstraint(edgeForestID, canyonConstraint); 
		rmAddAreaConstraint(edgeForestID, avoidTradeRoute);
		rmAddAreaConstraint(edgeForestID, avoidTradeRouteSockets);
		rmAddAreaConstraint(edgeForestID, avoidStartingUnits);
		rmAddAreaConstraint(edgeForestID, avoidNatives);
    rmAddAreaConstraint(edgeForestID, avoidHill);
			if(rmBuildArea(edgeForestID)==false)
			{
				// Stop trying once we fail 1 times in a row.  
				failCount++;
				if(failCount==1)
					break;
			}
			else
				failCount=0; 
	}

	// COIN RESOURCES

	int silverType = rmRandInt(1,10);
	int silverID = -1;
	int silverCount = cNumberNonGaiaPlayers*1;	
	rmEchoInfo("silver count = "+silverCount);

	for(i=0; < silverCount)
	{
		silverID = rmCreateObjectDef("silver"+i);
		rmAddObjectDefItem(silverID, "MineSalt", 1, 0);
		rmSetObjectDefMinDistance(silverID, 0.0);
		rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(silverID, avoidImpassableLand);
		rmAddObjectDefConstraint(silverID, canyonConstraint);
		rmAddObjectDefConstraint(silverID, avoidSilver);
		rmAddObjectDefConstraint(silverID, mediumPlayerConstraint);
		rmAddObjectDefConstraint(silverID, shortForestConstraint);
		rmAddObjectDefConstraint(silverID, avoidNatives);
		rmAddObjectDefConstraint(silverID, avoidTradeRouteSockets);
		rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);

	}

	
	for(i=0; < 10*cNumberNonGaiaPlayers)
	{
		int randomTreeID=rmCreateObjectDef("random tree "+i);
		rmAddObjectDefItem(randomTreeID, "treeCaribbean", rmRandInt(1,4), 3.0);
		rmSetObjectDefMinDistance(randomTreeID, 0.0);
		rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.3));
		rmAddObjectDefConstraint(randomTreeID, avoidResource);
		rmAddObjectDefConstraint(randomTreeID, shortAvoidImpassableLand);
		rmAddObjectDefConstraint(randomTreeID, avoidTradeRouteSockets);
		rmAddObjectDefConstraint(randomTreeID, shortPlayerConstraint);
		rmAddObjectDefConstraint(randomTreeID, avoidStartingUnits);
    rmAddObjectDefConstraint(randomTreeID, avoidHill);
		rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5);
   }


		int VulturesID=rmCreateObjectDef("vultures "+i);
		rmAddObjectDefItem(VulturesID, "PropVulturePerching", 1, 0);
		rmSetObjectDefMinDistance(VulturesID, 0.0);
		rmSetObjectDefMaxDistance(VulturesID, rmXFractionToMeters(0.3));
		rmAddObjectDefConstraint(VulturesID, avoidResource);
		rmAddObjectDefConstraint(VulturesID, shortAvoidImpassableLand);
		rmAddObjectDefConstraint(VulturesID, avoidTradeRouteSockets);
		rmAddObjectDefConstraint(VulturesID, shortPlayerConstraint);
		rmAddObjectDefConstraint(VulturesID, avoidStartingUnits);
		rmAddObjectDefConstraint(VulturesID, avoidHill);
		rmPlaceObjectDefAtLoc(VulturesID, 0, 0.5, 0.5);

		int bigrockID=rmCreateObjectDef("bigrock "+i);
		rmAddObjectDefItem(bigrockID, "BigPropTexas", 1, 0);
		rmSetObjectDefMinDistance(bigrockID, 0.0);
		rmSetObjectDefMaxDistance(bigrockID, rmXFractionToMeters(0.3));
		rmAddObjectDefConstraint(bigrockID, avoidResource);
		rmAddObjectDefConstraint(bigrockID, shortAvoidImpassableLand);
		rmAddObjectDefConstraint(bigrockID, avoidTradeRouteSockets);
		rmAddObjectDefConstraint(bigrockID, shortPlayerConstraint);
		rmAddObjectDefConstraint(bigrockID, avoidStartingUnits);
		rmAddObjectDefConstraint(bigrockID, avoidHill);
		rmPlaceObjectDefAtLoc(bigrockID, 0, 0.5, 0.5);

		int pyrmaidID=rmCreateObjectDef("pyrmaid "+i);
		rmAddObjectDefItem(pyrmaidID, "EGYpyramidlarge", 1, 0);
		rmSetObjectDefMinDistance(pyrmaidID, 0.0);
		rmSetObjectDefMaxDistance(pyrmaidID, rmXFractionToMeters(0.3));
		rmAddObjectDefConstraint(pyrmaidID, avoidResource);
		rmAddObjectDefConstraint(pyrmaidID, shortAvoidImpassableLand);
		rmAddObjectDefConstraint(pyrmaidID, avoidTradeRouteSockets);
		rmAddObjectDefConstraint(pyrmaidID, shortPlayerConstraint);
		rmAddObjectDefConstraint(pyrmaidID, avoidStartingUnits);
		rmAddObjectDefConstraint(pyrmaidID, avoidHill);
		rmPlaceObjectDefAtLoc(pyrmaidID, 0, 0.5, 0.5);

		// choose African Desert Huntables
		int AfricanHuntableArray = xsArrayCreateString(3, "", "");

		xsArraySetString(AfricanHuntableArray, 1, "Camel");
		xsArraySetString(AfricanHuntableArray, 2, "Oryx");
		xsArraySetString(AfricanHuntableArray, 3, "FennecFox");

		string huntable1 = xsArrayGetString(AfricanHuntableArray, rmRandInt(1, 3));
		string huntable2 = xsArrayGetString(AfricanHuntableArray, rmRandInt(1, 3));
		string huntable3 = xsArrayGetString(AfricanHuntableArray, rmRandInt(1, 3));

  		int AnimalsID=rmCreateObjectDef("Animals "+i);
		rmAddObjectDefItem(AnimalsID, huntable1, rmRandInt(5,8), 8.0);
		rmSetObjectDefMinDistance(AnimalsID, 0.0);
		rmSetObjectDefMaxDistance(AnimalsID, rmXFractionToMeters(0.3));
		rmAddObjectDefConstraint(AnimalsID, avoidResource);
		rmAddObjectDefConstraint(AnimalsID, shortAvoidImpassableLand);
		rmAddObjectDefConstraint(AnimalsID, avoidTradeRouteSockets);
		rmAddObjectDefConstraint(AnimalsID, shortPlayerConstraint);
		rmAddObjectDefConstraint(AnimalsID, avoidStartingUnits);
		rmAddObjectDefConstraint(AnimalsID, avoidHill);
		rmPlaceObjectDefAtLoc(AnimalsID, 0, 0.5, 0.5);

		int Animals2ID=rmCreateObjectDef("Animals2 "+i);
		rmAddObjectDefItem(Animals2ID, huntable2, rmRandInt(4,7), 8.0);
		rmSetObjectDefMinDistance(Animals2ID, 0.0);
		rmSetObjectDefMaxDistance(Animals2ID, rmXFractionToMeters(0.3));
		rmAddObjectDefConstraint(Animals2ID, avoidResource);
		rmAddObjectDefConstraint(Animals2ID, shortAvoidImpassableLand);
		rmAddObjectDefConstraint(Animals2ID, avoidTradeRouteSockets);
		rmAddObjectDefConstraint(Animals2ID, shortPlayerConstraint);
		rmAddObjectDefConstraint(Animals2ID, avoidStartingUnits);
		rmAddObjectDefConstraint(Animals2ID, avoidHill);
		rmPlaceObjectDefAtLoc(Animals2ID, 0, 0.5, 0.5);

		int Animals3ID=rmCreateObjectDef("Animals3 "+i);
		rmAddObjectDefItem(Animals3ID, "FennecFox", rmRandInt(5,8), 8.0);
		rmSetObjectDefMinDistance(Animals3ID, 0.0);
		rmSetObjectDefMaxDistance(Animals3ID, rmXFractionToMeters(0.3));
		rmAddObjectDefConstraint(Animals3ID, avoidResource);
		rmAddObjectDefConstraint(Animals3ID, shortAvoidImpassableLand);
		rmAddObjectDefConstraint(Animals3ID, avoidTradeRouteSockets);
		rmAddObjectDefConstraint(Animals3ID, shortPlayerConstraint);
		rmAddObjectDefConstraint(Animals3ID, avoidStartingUnits);
		rmAddObjectDefConstraint(Animals3ID, avoidHill);
		rmPlaceObjectDefAtLoc(Animals3ID, 0, 0.5, 0.5);

	// Define and place Nuggets

	int nuggeteasyID= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nuggeteasyID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmSetObjectDefMinDistance(nuggeteasyID, 0.0);
	rmSetObjectDefMaxDistance(nuggeteasyID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggeteasyID, avoidNugget);
  	rmAddObjectDefConstraint(nuggeteasyID, playerConstraint);
  	rmAddObjectDefConstraint(nuggeteasyID, avoidAll);
  	rmAddObjectDefConstraint(nuggeteasyID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(nuggeteasyID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);

	int nuggetmediumEastID= rmCreateObjectDef("nugget medium east"); 
	rmAddObjectDefItem(nuggetmediumEastID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(2, 2);
	rmSetObjectDefMinDistance(nuggetmediumEastID, 0.0);
	rmSetObjectDefMaxDistance(nuggetmediumEastID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggetmediumEastID, avoidNugget);
  	rmAddObjectDefConstraint(nuggetmediumEastID, playerConstraint);
  	rmAddObjectDefConstraint(nuggetmediumEastID, avoidAll);
  	rmAddObjectDefConstraint(nuggetmediumEastID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(nuggetmediumEastID, 0, 0.5, 0.5, 2);

	int nuggetmediumWestID= rmCreateObjectDef("nugget medium west"); 
	rmAddObjectDefItem(nuggetmediumWestID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(2, 2);
	rmSetObjectDefMinDistance(nuggetmediumWestID, 0.0);
	rmSetObjectDefMaxDistance(nuggetmediumWestID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggetmediumWestID, avoidNugget);
  	rmAddObjectDefConstraint(nuggetmediumWestID, playerConstraint);
  	rmAddObjectDefConstraint(nuggetmediumWestID, avoidAll);
  	rmAddObjectDefConstraint(nuggetmediumWestID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(nuggetmediumWestID, 0, 0.5, 0.5, 2);

	int nuggethardID= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nuggethardID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 3);
	rmSetObjectDefMinDistance(nuggethardID, 0.0);
	rmSetObjectDefMaxDistance(nuggethardID, rmXFractionToMeters(0.5));
  	rmAddObjectDefConstraint(nuggethardID, avoidNugget);
  	rmAddObjectDefConstraint(nuggethardID, playerConstraint);
  	rmAddObjectDefConstraint(nuggethardID, avoidAll);
  	rmAddObjectDefConstraint(nuggethardID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(nuggethardID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);




		// Text
	rmSetStatusText("",1.0);

  // King of the Hill (added 2026-11 for WoL): the middle of the start positions (the map centre), on open sand away from the cliffs; the map only included the King of the Hill library and kept objects away from a hill it never placed
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
    int kothAvoidClass0 = rmCreateClassDistanceConstraint("koth hill avoids classCliff", rmClassID("classCliff"), 20.0);
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
      rmAddObjectDefConstraint(kothHill, kothAvoidClass0);
      rmPlaceObjectDefAtLoc(kothHill, 0, kothX, kothZ, 1);
      if (rmGetNumberUnitsPlaced(kothHill) > 0)
        break;
      kothRadius = kothRadius * 1.5;
    }
  }

	}
}  
