// Barrier Ridge TWC
// a random map for AOE3: The War Chiefs
// by RF_Gandalf

include "mercenaries.xs";
include "triggers\triggerLoader.xs";
include "ypKOTHInclude.xs";

void main(void)
{  
   // Text
   rmSetStatusText("",0.01);

// Set up for variables
   string baseType = "";
   string cliffType = "";
   string forestType = "";
   string treeType = "";
   string deerType = "";
   string deer2Type = "";
   string sheepType = "";
   string centerHerdType = "";
   string native1Name = "";
   string native2Name = "";
   string patchMixType = "";
   string mineType = "";

// Pick pattern for trees, terrain, features, etc.
   int patternChance = rmRandInt(1,28);   
   int variantChance = rmRandInt(1,2);
   int lightingChance = rmRandInt(1,2);
   int trPattern = rmRandInt(1,5);
   int socketPattern = rmRandInt(1,2);   
   int nativeSetup = rmRandInt(7,17);
   if (cNumberNonGaiaPlayers > 4)
      nativeSetup = rmRandInt(9,17);	 
   int nativePattern = -1;
   int sheepChance = rmRandInt(1,2);
   int cliffChance = rmRandInt(1,10);
   int makeCliffs = -1; 
   int cliffVariety = rmRandInt(0,5);
   int vultures = -1;
   int eagles = -1;
   int plainsMap = -1;
   int hillTrees = -1;
   int placeBerries = 1;
   int tropicalMap = -1;
   int forestDist = rmRandInt(12,18);
   int axisChance = rmRandInt(1,2);
   int playerSide = rmRandInt(1,2);   
   int makeBarrierRangeForest = 1;
   int gapPattern = rmRandInt(1,3);
   int twoChoice = rmRandInt(1,2);
   int threeChoice = rmRandInt(1,3);
   int fourChoice = rmRandInt(1,4);
   int fiveChoice = rmRandInt(1,5);
   int sixChoice = rmRandInt(1,6);
   int placeGold = rmRandInt(1,5);

   int specialPatch = 0;
   int coverUp = 0;
   int forestPatch = 0;
   int noCliffForest = 0;

// Picks the map size
   int playerTiles = 15000;
   if (cNumberNonGaiaPlayers == 8)
	playerTiles = 11000;
   else if (cNumberNonGaiaPlayers == 7)
	playerTiles = 12000;
   else if (cNumberNonGaiaPlayers == 6)
	playerTiles = 13000;
   else if (cNumberNonGaiaPlayers == 5)
	playerTiles = 13500;
   else if (cNumberNonGaiaPlayers == 4)
	playerTiles = 14000;
   else if (cNumberNonGaiaPlayers == 3)
	playerTiles = 14500;

   int size=2*sqrt(cNumberNonGaiaPlayers*playerTiles);
   int longSide=1.6*size; 
   if (axisChance == 2) 
      rmSetMapSize(size, longSide);
   else if (axisChance == 1)    
      rmSetMapSize(longSide, size);
   
// Elevation
   rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.7, 5.0);
   rmSetMapElevationHeightBlend(1.0);
   rmSetSeaLevel(0.0);
	
   // Text
   rmSetStatusText("",0.05);

// Terrain patterns and features 
/*  can use these in single player to select favorite features - 
    but restore map from the zip file for use in multiplayer 
    to ensure files are exactly the same  */ 

//  trPattern = 4;
//  variantChance = 2;
//  cliffChance = 8;
//  lightingChance = 1;
//  nativeSetup = 15;
//  gapPattern = 3;
//  patternChance = 28;

   if (patternChance == 1) // NE
   {  
      rmSetMapType("newEngland");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("paris");
	else
	   rmSetLightingSet("new england");
      baseType = "newengland_grass";
	forestType = "new england forest";
      cliffType = "New England Inland Grass";
	treeType = "TreeNewEngland";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "turkey";
         centerHerdType = "moose";         
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "moose";
         centerHerdType = "turkey";        
	}
      if (sheepChance == 1)
         sheepType = "sheep";
      else
         sheepType = "cow";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineTin";
      hillTrees = rmRandInt(0,1);

	if (cliffChance > 2)
         makeCliffs = 1;

	if (twoChoice == 1)
	   nativePattern = 40;
	else
	   nativePattern = 5;
   }
   else if (patternChance == 2) // carolina
   {
      rmSetMapType("carolina");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("312b_washington");
	else
	   rmSetLightingSet("carolina");

      baseType = "carolina_grass";
	forestType = "carolina pine forest";
      cliffType = "Carolina Inland";
	treeType = "TreeCarolinaGrass";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "turkey";
         centerHerdType = "deer";
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "deer";
         centerHerdType = "turkey";        
	}   
      if (sheepChance == 1)
         sheepType = "cow";
      else
         sheepType = "sheep";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineTin";
      hillTrees = rmRandInt(0,1);

	if (cliffChance > 7)
         makeCliffs = 1;

	if (twoChoice == 1)
	   nativePattern = 40;
	else
	   nativePattern = 3;
   }
   else if (patternChance == 3) // bayou
   {
      rmSetMapType("bayou");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("paris");
	else
         rmSetLightingSet("bayou");

      baseType = "bayou_grass";
      cliffType = "Bayou";
	forestType = "bayou swamp forest";
	treeType = "TreeBayou";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "turkey";
         centerHerdType = "deer";
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "deer";
         centerHerdType = "turkey";        
	}
      if (sheepChance == 1)
         sheepType = "sheep";
      else
         sheepType = "cow";
      mineType = "mine";
	eagles = 1;
      makeCliffs = 0;
	if (fourChoice == 1)
	   makeCliffs = 1;

	if (twoChoice == 1)
	   nativePattern = 3;
	else
	   nativePattern = 21;
   }
   else if (patternChance == 4) // great lakes
   {
      rmSetMapType("greatlakes");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("constantinople");
	else
         rmSetLightingSet("Great Lakes");

      baseType = "greatlakes_grass";
	forestType = "great lakes forest";
      cliffType = "New England Inland Grass";
	treeType = "TreeGreatLakes";
	variantChance = rmRandInt(1,2);
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "moose";
         centerHerdType = "bison";
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "turkey";
         centerHerdType = "moose";        
	}   
      sheepType = "sheep";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
      hillTrees = rmRandInt(0,1);

	if (cliffChance >6)
         makeCliffs = 1;

	if (fiveChoice == 1)
	   nativePattern = 4;
	else if (fiveChoice == 2)
	   nativePattern = 5;
	else if (fiveChoice == 3)
	   nativePattern = 19;
	else if (fiveChoice == 4)
	   nativePattern = 21;
	else
	   nativePattern = 22;
   }
   else if (patternChance == 5) // great lakes winter
   {
      rmSetMapType("greatlakes");
      rmSetMapType("snow");
	if (lightingChance == 1)
	   rmSetLightingSet("308b_caribbeanlight");
	else
         rmSetLightingSet("Great Lakes Winter");

      baseType = "greatlakes_snow";
	forestType = "great lakes forest snow";
      cliffType = "rocky mountain2";
	treeType = "TreeGreatLakesSnow";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "moose";
         centerHerdType = "elk";
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "bison";
         centerHerdType = "moose";       
	}      
      sheepType = "sheep";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
      placeBerries = 0;
      hillTrees = rmRandInt(0,1);

	if (fourChoice == 1)
	   nativePattern = 4;
	else if (fourChoice == 2)
	   nativePattern = 5;
	else if (fourChoice == 3)
	   nativePattern = 19;
	else
	   nativePattern = 22;
   }
   else if (patternChance == 6) // yukon tundra
   {
      rmSetMapType("yukon");
      rmSetMapType("snow");
	if (lightingChance == 1)
         rmSetLightingSet("seville morning");
	else
         rmSetLightingSet("yukon");

      baseType = "yukon grass";
	forestType = "yukon forest";
      cliffType = "rocky mountain2";
	treeType = "TreeYukon";

      if (fourChoice == 1)
	{
         deerType = "muskOx";
         deer2Type = "caribou";
         centerHerdType = "caribou";
	}
	else if (fourChoice == 2)
	{
                  deerType = "muskOx";
                  deer2Type = "caribou";
                  centerHerdType = "bighornsheep";
	}
      else if (fourChoice == 3)
      {
                  deerType = "caribou";
                  deer2Type = "muskOx";
                  centerHerdType = "bighornsheep";
	}
	else if (fourChoice == 4)
	{
            deerType = "caribou";
            deer2Type = "muskOx";
            centerHerdType = "caribou";
	}
      mineType = "mine";
      sheepChance = 0;
      placeBerries = 0;
      hillTrees = 0;

	if (sixChoice == 1)
	   nativePattern = 5;
	else if (sixChoice == 2)
	   nativePattern = 6;
	else if (sixChoice == 3)
	   nativePattern = 8;
	else if (sixChoice == 4)
	   nativePattern = 16;
	else if (sixChoice == 5)
	   nativePattern = 27;
	else
	   nativePattern = 28;  
   }
   else if (patternChance == 7) // yukon
   {
      rmSetMapType("yukon");
      rmSetMapType("snow");
	if (lightingChance == 1)
	   rmSetLightingSet("305b");
	else
         rmSetLightingSet("yukon");

      baseType = "yukon snow";
	forestType = "yukon snow forest";
      cliffType = "rocky mountain2";
	treeType = "TreeYukonSnow";
      if (variantChance == 1)
	{
         deerType = "caribou";
         deer2Type = "muskOx";
         centerHerdType = "bighornsheep";
	}
      else 
	{     
         deerType = "muskOx";
         deer2Type = "caribou";
         centerHerdType = "caribou";       
	}
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "minegold";
      sheepChance = 0;
      placeBerries = 0;
      hillTrees = rmRandInt(0,1);

	if (cliffChance > 2)
         makeCliffs = 1;

	if (sixChoice == 1)
	   nativePattern = 5;
	else if (sixChoice == 2)
	   nativePattern = 6;
	else if (sixChoice == 3)
	   nativePattern = 8;
	else if (sixChoice == 4)
	   nativePattern = 16;
	else if (sixChoice == 5)
	   nativePattern = 27;
	else
	   nativePattern = 28;  
   }
   else if (patternChance == 8) // rockies
   {
      rmSetMapType("rockies");
      rmSetMapType("snow");
	if (lightingChance == 1)
	   rmSetLightingSet("ottoman morning");
	else
         rmSetLightingSet("rockies");

      baseType = "rockies_grass";
	forestType = "rockies forest";
      cliffType = "rocky mountain2";
	treeType = "TreeRockies";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "elk";
         centerHerdType = "bighornsheep";
	}
      else 
	{     
         deerType = "elk";
         deer2Type = "elk";
         centerHerdType = "bighornsheep";
	}   
      if (sheepChance == 1)
         sheepType = "cow";
      else
         sheepType = "sheep";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "minegold";
	eagles = 1;
      hillTrees = 1;

	if (sixChoice == 1)
	   nativePattern = 6;
	else if (sixChoice == 2)
	   nativePattern = 7;
	else if (sixChoice == 3)
	   nativePattern = 8;
	else if (sixChoice == 4)
	   nativePattern = 23;
	else if (sixChoice == 5)
	   nativePattern = 27;
	else
	   nativePattern = 28;
   }
   else if (patternChance == 9) // great plains 1
   {
      rmSetMapType("greatPlains");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("ottoman morning");
	else
         rmSetLightingSet("great plains");
       
      baseType = "great plains grass"; 
	forestType = "great plains forest";
      cliffType = "Great Plains";
	treeType = "TreeGreatPlains";
      if (variantChance == 1)
	{
         deerType = "bison";
         deer2Type = "pronghorn";
         centerHerdType = "bison";
	}
      else 
	{     
         deerType = "pronghorn";
         deer2Type = "bison";
         centerHerdType = "elk";
	} 
      if (sheepChance == 1)
         sheepType = "cow";
      else
         sheepType = "sheep";
      mineType = "mine";
      vultures = 1;
      plainsMap = 1;
	noCliffForest = 1;
      makeBarrierRangeForest = 0;

	if (cliffChance > 7)
         makeCliffs = 1;

	if (sixChoice == 1)
	   nativePattern = 23;
	else if (sixChoice == 2)
	   nativePattern = 29;
	else if (sixChoice == 3)
	   nativePattern = 19;
	else if (sixChoice == 4)
	   nativePattern = 8;
	else if (sixChoice == 5)
	   nativePattern = 28;
	else if (sixChoice == 6)
	   nativePattern = 22;
   }
   else if (patternChance == 10) // great plains 2
   {
      rmSetMapType("greatPlains");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("spc14abuffalo");
	else
         rmSetLightingSet("great plains");
       
      baseType = "great plains drygrass";
	forestType = "great plains forest";
      cliffType = "Great Plains";
	treeType = "TreeGreatPlains";
      if (variantChance == 1)
	{
         deerType = "bison";
         deer2Type = "pronghorn";
         centerHerdType = "bison";
	}
      else 
	{     
         deerType = "pronghorn";
         deer2Type = "bison";
         centerHerdType = "bison";
	}
      sheepType = "cow";
      mineType = "mine";
      vultures = 1;
      plainsMap = 1;
	noCliffForest = 1;
      makeBarrierRangeForest = 0;

	if (cliffChance > 7)
         makeCliffs = 1;

	if (sixChoice == 1)
	   nativePattern = 23;
	else if (sixChoice == 2)
	   nativePattern = 29;
	else if (sixChoice == 3)
	   nativePattern = 30;
	else if (sixChoice == 4)
	   nativePattern = 8;
	else if (sixChoice == 5)
	   nativePattern = 28;
	else if (sixChoice == 6)
	   nativePattern = 32;
   }
   else if (patternChance == 11) // texas grass
   {   
      rmSetMapType("texas");
	rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("pampas");
	else
         rmSetLightingSet("texas");

      baseType = "texas_grass";
	forestType = "texas forest";
      cliffType = "Texas Grass";
	treeType = "TreeTexas";
      if (variantChance == 1)
	{
         deerType = "bison";
         deer2Type = "deer";
         centerHerdType = "bison";
	}
      else 
	{     
         deerType = "pronghorn";
         deer2Type = "bison";
         centerHerdType = "bison";
	}
      sheepType = "cow";
      mineType = "mine";
      vultures = 1;

	if (cliffChance > 3)
         makeCliffs = 1;

      makeBarrierRangeForest = 0;

	if (sixChoice == 1)
	   nativePattern = 30;
	else if (sixChoice == 2)
	   nativePattern = 29;
	else if (sixChoice == 3)
	   nativePattern = 19;
	else if (sixChoice == 4)
	   nativePattern = 9;
	else if (sixChoice == 5)
	   nativePattern = 20;
	else if (sixChoice == 6)
	   nativePattern = 32;
   }
   else if (patternChance == 12) // texas desert
   {   
      rmSetMapType("texas");
	rmSetMapType("grass");

      if (lightingChance == 1)
         rmSetLightingSet("seville");
      else
         rmSetLightingSet("texas");

      baseType = "texas_dirt";

	forestType = "texas forest dirt";
      cliffType = "Texas";
	treeType = "TreeTexasDirt";
      if (variantChance == 1)
	{
         deerType = "bison";
         deer2Type = "pronghorn";
         centerHerdType = "pronghorn";
	}
      else 
	{     
         deerType = "pronghorn";
         deer2Type = "bison";
         centerHerdType = "bison";
	}
      sheepType = "cow";
      mineType = "mine";
      vultures = 1;

      makeCliffs = 1;

      makeBarrierRangeForest = 0;

	if (sixChoice == 1)
	   nativePattern = 29;
	else if (sixChoice == 2)
	   nativePattern = 30;
	else if (sixChoice == 3)
	   nativePattern = 31;
	else if (sixChoice == 4)
	   nativePattern = 32;
	else if (sixChoice == 5)
	   nativePattern = 38;
	else if (sixChoice == 6)
	   nativePattern = 39;
   }
   else if (patternChance == 13) // sonora
   {   
      rmSetMapType("sonora");
	rmSetMapType("grass");
      if (lightingChance == 1)
         rmSetLightingSet("sonora");
	else
         rmSetLightingSet("pampas");
	baseType = "sonora_dirt";
	forestType = "sonora forest";
      cliffType = "Sonora";
	treeType = "TreeSonora";
      if (variantChance == 1)
	{
         deerType = "pronghorn";
         deer2Type = "bison";
         centerHerdType = "bighornsheep";         
	}
      else 
	{     
         deerType = "pronghorn";
         deer2Type = "bighornsheep";
         centerHerdType = "bison";         
	}
      if (sheepChance == 1)
         sheepType = "sheep";
      else
         sheepType = "cow";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
      vultures = 1;
      makeBarrierRangeForest = 0;
      cliffVariety = 8;
      makeCliffs = 1;
	noCliffForest = 1;
      placeBerries = 0;

	if (sixChoice == 1)
	   nativePattern = 33;
	else if (sixChoice == 2)
	   nativePattern = 30;
	else if (sixChoice == 3)
	   nativePattern = 31;
	else if (sixChoice == 4)
	   nativePattern = 32;
	else if (sixChoice == 5)
	   nativePattern = 35;
	else if (sixChoice == 6)
	   nativePattern = 37;
   }
   else if (patternChance == 14) // yucatan
   {
      rmSetMapType("yucatan");
      rmSetMapType("tropical");
	if (lightingChance == 1)
	   rmSetLightingSet("311b");
	else
         rmSetLightingSet("yucatan");

      baseType = "yucatan_grass";
	forestType = "yucatan forest";
      cliffType = "Amazon";
	treeType = "TreeYucatan";
      if (variantChance == 1)
      {
         deerType = "tapir";
         deer2Type = "capybara";
         centerHerdType = "turkey";
      }
      else
	{
         deerType = "capybara";
         deer2Type = "turkey";
         centerHerdType = "tapir";
	}
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineTin";
      sheepChance = 0;
      tropicalMap = 1;
      hillTrees = rmRandInt(0,1);

	if (cliffChance > 7)
         makeCliffs = 1;

	if (fiveChoice == 1)
	   nativePattern = 11;
	else if (fiveChoice == 2)
	   nativePattern = 12;
	else if (fiveChoice == 3)
	   nativePattern = 34;
	else if (fiveChoice == 4)
	   nativePattern = 35;
	else
	   nativePattern = 36;
   }
   else if (patternChance == 15) // caribbean
   {
      rmSetMapType("caribbean");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("301a_malta");
	else
         rmSetLightingSet("caribbean");
     
      baseType = "caribbean grass";
	forestType = "caribbean palm forest";
      cliffType = "Caribbean";
	treeType = "TreeCaribbean";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "deer";
         centerHerdType = "tapir";
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "tapir";
         centerHerdType = "deer";
	}
      mineType = "mine";
      sheepChance = 0;
      tropicalMap = 1;

	if (cliffChance > 7)
         makeCliffs = 1;

	if (fiveChoice == 1)
	   nativePattern = 12;
	else if (fiveChoice == 2)
	   nativePattern = 13;
	else if (fiveChoice == 3)
	   nativePattern = 18;
	else if (fiveChoice == 4)
	   nativePattern = 36;
	else
	   nativePattern = 42;
   }
   else if (patternChance == 16) // amazon
   {
      rmSetMapType("amazonia");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("323b_inca");
	else
         rmSetLightingSet("amazon");
     
      baseType = "amazon grass";
	forestType = "amazon rain forest";
      cliffType = "Amazon";
	treeType = "TreeAmazon";
      if (variantChance == 1)
      {
         deerType = "tapir";
         deer2Type = "tapir";
         centerHerdType = "capybara";
      }
      else
	{
         deerType = "capybara";
         deer2Type = "tapir";
         centerHerdType = "capybara";
	}
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineTin";
      sheepChance = 0;
      tropicalMap = 1;

	if (cliffChance > 7)
         makeCliffs = 1;

	if (fiveChoice == 1)
	   nativePattern = 13;
	else if (fiveChoice == 2)
	   nativePattern = 14;
	else if (fiveChoice == 3)
	   nativePattern = 15;
	else if (fiveChoice == 4)
	   nativePattern = 18;
	else
	   nativePattern = 26;
   }
   else if (patternChance == 17) // saguenay
   {
      rmSetMapType("saguenay");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("lisbon");
	else
         rmSetLightingSet("saguenay");

      baseType = "saguenay grass";
	forestType = "saguenay forest";
      cliffType = "New England Inland Grass";
	treeType = "TreeSaguenay";
      if (variantChance == 1)
	{
         deerType = "caribou";
         deer2Type = "moose";
         centerHerdType = "caribou";
	}
      else 
	{     
         deerType = "caribou";
         deer2Type = "caribou";
         centerHerdType = "moose";       
	}
      sheepType = "sheep";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
      makeCliffs = 0;
      makeBarrierRangeForest = 0;

	if (fourChoice == 1)
	   nativePattern = 5;
	else if (fourChoice == 2)
	   nativePattern = 6;
	else if (fourChoice == 3)
	   nativePattern = 8;
	else
	   nativePattern = 16;
   }
   else if (patternChance == 18) // patagonia
   {
      rmSetMapType("patagonia");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("paris day");
	else
         rmSetLightingSet("patagonia");
	if (rmRandInt(1,2) == 1)
         baseType = "patagonia_grass";
	else
         baseType = "patagonia_dirt";
	forestType = "patagonia forest";
      cliffType = "Patagonia";
	treeType = "TreePatagoniaDirt";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "rhea";
         centerHerdType = "rhea";
	}
      else 
	{     
         deerType = "rhea";
         deer2Type = "guanaco";
         centerHerdType = "rhea";
	}
      sheepType = "llama";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
      hillTrees = rmRandInt(0,1);

	if (cliffChance < 6)
         makeCliffs = 1;

	if (fiveChoice == 1)
	   nativePattern = 14;
	else if (fiveChoice == 2)
	   nativePattern = 15;
	else if (fiveChoice == 3)
	   nativePattern = 24;
	else if (fiveChoice == 4)
	   nativePattern = 25;
	else
	   nativePattern = 26;
   }
   else if (patternChance == 19) // andes
   {
      rmSetMapType("andes");
      rmSetMapType("grass");
	if (lightingChance == 1)
         rmSetLightingSet("greatplainstest");
	else
	   rmSetLightingSet("andes");
	if (twoChoice == 1)
	{
         baseType = "andes_grass_a";
	   patchMixType = "andes_grass_b";
	}
	else
	{
         baseType = "andes_grass_b";
	   patchMixType = "andes_grass_a";
	}
	forestType = "andes forest";
      cliffType = "andes";
	treeType = "TreeAndes";
      if (variantChance == 1)
	{
         deerType = "guanaco";
         deer2Type = "guanaco";
         centerHerdType = "rhea";
	}
      else 
	{     
         deerType = "guanaco";
         deer2Type = "guanaco";
         centerHerdType = "guanaco";
	}
      sheepType = "llama";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
      hillTrees = rmRandInt(0,1);
      eagles = 1;
      makeBarrierRangeForest = 0;
      specialPatch = 1;

	if (fiveChoice == 1)
	   nativePattern = 14;
	else if (fiveChoice == 2)
	   nativePattern = 24;
	else if (fiveChoice == 3)
	   nativePattern = 25;
	else if (fiveChoice == 4)
	   nativePattern = 26;
	else
	   nativePattern = 18;
   }
   else if (patternChance == 20) // araucania green or central
   {
      rmSetMapType("araucania");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("Araucania Central");
	else
         rmSetLightingSet("Texas"); 
	if (fourChoice == 1)
	{
         baseType = "araucania_grass_a";
	   patchMixType = "araucania_grass_b";
	}
	else if (fourChoice == 2)
	{
         baseType = "araucania_grass_b";
	   patchMixType = "araucania_grass_a";
	}
	else if (fourChoice == 3)
	{
         baseType = "araucania_grass_c";
	   patchMixType = "araucania_grass_b";
	}
	else
	{
         baseType = "araucania_grass_d";
	   patchMixType = "araucania_grass_c";
	}
	forestType = "Araucania Forest";
	cliffType = "Araucania Central";      
	treeType = "TreeAraucania";
      if (variantChance == 1)
	{
         deerType = "guanaco";
         deer2Type = "deer";
         centerHerdType = "guanaco"; 
	}
      else 
	{     
         deerType = "guanaco";
         deer2Type = "guanaco";
         centerHerdType = "guanaco";
	} 
      sheepType = "llama";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
	coverUp = rmRandInt(1,2);   
      specialPatch = 1;

	if (fiveChoice == 1)
	   nativePattern = 14;
	else if (fiveChoice == 2)
	   nativePattern = 25;
	else if (fiveChoice == 3)
	   nativePattern = 11;
	else if (fiveChoice == 4)
	   nativePattern = 26;
	else
	   nativePattern = 34;
   }
   else if (patternChance == 21) // araucania north  
   {
      rmSetMapType("araucania");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("NthAraucaniaLight");
	else
         rmSetLightingSet("constantinople");  
	if (cliffChance > 3)
         makeCliffs = 1;
	if (fourChoice == 1) 
	{
	   baseType = "araucania_north_grass_a";
         patchMixType = "araucania_north_dirt_a"; 
	   makeCliffs = 0;
         placeBerries = 0;
	}
	else if (fourChoice == 2)
	{
	   baseType = "araucania_north_grass_a";
	   patchMixType = "araucania_north_grass_b"; 
	   makeCliffs = 0;
	}
	else if (fourChoice == 3)
	{
	   baseType = "araucania_north_grass_b";
	   patchMixType = "araucania_north_grass_a"; 
	}
	else if (fourChoice == 4)
	{
	   baseType = "araucania_north_grass_c";
	   patchMixType = "araucania_north_grass_a"; 
	}
	forestType =  "North Araucania Forest";
	cliffType = "Araucania North";
	treeType = "TreeAraucania";
      if (variantChance == 1)
	{
         deerType = "guanaco";
         deer2Type = "deer";
         centerHerdType = "guanaco"; 
	}
      else 
	{     
         deerType = "guanaco";
         deer2Type = "guanaco";
         centerHerdType = "guanaco";
	} 
      sheepType = "llama";
      mineType = "MineCopper";
	specialPatch = 1;
	hillTrees = 0;
      makeBarrierRangeForest = 0;

	if (fiveChoice == 1)
	   nativePattern = 14;
	else if (fiveChoice == 2)
	   nativePattern = 24;
	else if (fiveChoice == 3)
	   nativePattern = 25;
	else if (fiveChoice == 4)
	   nativePattern = 26;
	else
	   nativePattern = 18;
   }
   else if (patternChance == 22) // araucania south 
   {
      rmSetMapType("araucania");
      rmSetMapType("snow");
      rmSetLightingSet("303a_boston");  
	if (fourChoice == 1)
	{
   	   baseType = "araucania_snow_a";
         patchMixType = "araucania_snow_b";
	}
	else if (fourChoice == 2)
	{
   	   baseType = "araucania_snow_a";
         patchMixType = "araucania_snow_c";
	}
	else if (fourChoice == 3)
	{
   	   baseType = "araucania_snow_c";
         patchMixType = "araucania_snow_a";
	}
	else if (fourChoice == 4)
	{
   	   baseType = "araucania_snow_b";
         patchMixType = "araucania_snow_a";
	   coverUp = 1;
	}
	forestType = "Patagonia Snow Forest";
      cliffType = "Araucania South";
	treeType = "TreePatagoniaSnow";
      if (variantChance == 1)
	{
         deerType = "guanaco";
         deer2Type = "deer";
         centerHerdType = "guanaco"; 
	}
      else 
	{     
         deerType = "guanaco";
         deer2Type = "guanaco";
         centerHerdType = "guanaco";
	} 
      if (sheepChance == 1)
         sheepType = "sheep";
      else
         sheepType = "llama";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
      placeBerries = 0;
      hillTrees = rmRandInt(0,1);
	specialPatch = 1;
      makeBarrierRangeForest = 0;

	fourChoice = rmRandInt(1,4);
	if (fourChoice == 1)
	   nativePattern = 14;
	else if (fourChoice == 2)
	   nativePattern = 25;
	else if (fourChoice == 3)
	   nativePattern = 26;
	else
	   nativePattern = 11;
   }
   else if (patternChance == 23) // california green
   {
      rmSetMapType("california");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("california");
	else
         rmSetLightingSet("new england");      
	if (threeChoice == 1)
	{
         baseType = "california_grass";
	   if (twoChoice == 1)
	      patchMixType = "california_grassrocks"; 
	   else
	      patchMixType = "california_snowground5";  
	}
	else if (threeChoice == 2)
	{
         baseType = "california_grassrocks"; 
	   if (twoChoice == 1)
	      patchMixType = "california_grass"; 
	   else
	      patchMixType = "california_snowground5";  
	}
	else if (threeChoice == 3)
	{
         baseType = "california_snowground5";  
	   if (twoChoice == 1)
	      patchMixType = "california_grass"; 
	   else
	      patchMixType = "california_grassrocks"; 
	}
	if (fiveChoice < 3)
	{ 
	   forestType = "california redwood forest";
	   treeType = "TreeRedwood";
	}
	else if (fiveChoice < 5)
	{ 
	   forestType = "California pine forest";
	   treeType = "TreePonderosaPine";
	}
	else
	{
	   forestType = "california madrone forest";
	   treeType = "TreeMadrone";
	}
      cliffType = "California";
      if (variantChance == 1)
	{
         deerType = "elk";
         deer2Type = "deer";
         centerHerdType = "elk";
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "deer";
         centerHerdType = "elk";
	} 
      if (sheepChance == 1)
         sheepType = "cow";
      else
         sheepType = "sheep";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "minegold";
	specialPatch = 1;
      hillTrees = rmRandInt(0,1);
      eagles = 1;

	if (cliffChance > 7)
         makeCliffs = 1;
	if (fourChoice < 3)
	   nativePattern = 27;
	else
	   nativePattern = 28;
   }
   else if (patternChance == 24) // california desert 
   {
      rmSetMapType("california");
      rmSetMapType("grass");
	if (lightingChance == 1)
	   rmSetLightingSet("texas");
	else
         rmSetLightingSet("307a_beach");      
      if (variantChance == 1)
	{
         deerType = "pronghorn";
         deer2Type = "pronghorn";
         centerHerdType = "deer";
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "deer";
         centerHerdType = "pronghorn";
	}
	forestType = "California Desert Forest";
	treeType = "TreeSonora";
	if (threeChoice == 1)
	{ 
	   baseType = "california_desert0";
	   patchMixType = "california_desert";
         placeBerries = 0;
	}
	else if (threeChoice == 2)
	{ 
	   baseType = "california_desert";
	   patchMixType = "california_desert0";
	   placeBerries = 0;
	}
	else
	{
	   baseType = "california_desert2";
	   patchMixType = "california_desert";
	   forestType = "california madrone forest";
	   treeType = "TreeMadrone";
         centerHerdType = "elk";
	}
	cliffType = "Sonora";
       if (sheepChance == 1)
         sheepType = "cow";
      else
         sheepType = "sheep";
      mineType = "mine";
      hillTrees = rmRandInt(0,1);
      vultures = 1;
	coverUp = 1;

	if (fourChoice < 3)
	   nativePattern = 27;
	else
	   nativePattern = 43;
   }
   else if (patternChance == 25) // nwt    
   {
      rmSetMapType("northwestTerritory");
      rmSetMapType("grass");
	if (lightingChance == 2)
	   rmSetLightingSet("nwterritory");
	else
         rmSetLightingSet("saguenay");
      baseType = "nwt_grass1";
	if (twoChoice == 1)
	{
	   forestType = "NW Territory Birch Forest";
   	   treeType = "TreeGreatLakes";
	}
	else
	{ 
	   forestType = "NW Territory Forest";
	   treeType = "TreeGreatPlains";   
	}
	cliffType = "Araucania Central";    
      if (variantChance == 1)
	{
         deerType = "elk";
         deer2Type = "deer";
         centerHerdType = "moose"; 
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "moose";
         centerHerdType = "elk";
	} 
      if (sheepChance == 1)
         sheepType = "sheep";
      else
         sheepType = "cow";
      makeCliffs = 2;  
      eagles = 1;
      mineType = "mine";
      hillTrees = rmRandInt(0,1);
	coverUp = 1;

	if (fourChoice == 1)
	   nativePattern = 27;
	else if (fourChoice == 2)
	   nativePattern = 28;
	else if (fourChoice == 3)
	   nativePattern = 7;
	else
	   nativePattern = 6;
   }
   else if (patternChance == 26) // painted desert     
   {   
      rmSetMapType("sonora");
	rmSetMapType("desert");
      if (lightingChance == 1)
         rmSetLightingSet("sonora");
      else
         rmSetLightingSet("pampas");
	if (twoChoice == 1)
         baseType = "painteddesert_groundmix_1";
	else
         baseType = "painteddesert_groundmix_2";
	forestType = "painteddesert forest";
      cliffType = "Painteddesert";
	treeType = "TreePaintedDesert";
      if (variantChance == 1)
	{
         deerType = "pronghorn";
         deer2Type = "bison";
         centerHerdType = "bighornsheep";         
	}
      else 
	{     
         deerType = "pronghorn";
         deer2Type = "bighornsheep";
         centerHerdType = "bison";         
	}
      if (sheepChance == 1)
         sheepType = "sheep";
      else
         sheepType = "cow";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
      vultures = 1;
      makeBarrierRangeForest = 0;
      cliffVariety = 8;
      makeCliffs = 1;
	noCliffForest = 1;
      placeBerries = 0;

	if (fiveChoice == 1)
	   nativePattern = 30;
	else if (fiveChoice == 2)
	   nativePattern = 31;
	else if (fiveChoice == 3)
	   nativePattern = 32;
	else if (fiveChoice == 4)
	   nativePattern = 33;
	else
	   nativePattern = 37;
   }
   else if (patternChance == 27) // palm and grass
   {
      rmSetMapType("yucatan");
      if (lightingChance == 1)
         rmSetLightingSet("Texas");
      else
         rmSetLightingSet("pampas");

      baseType = "yucatan_grass";
      forestType = "caribbean palm forest";
      treeType = "TreeCaribbean";
      cliffType = "Amazon";
      if (variantChance == 1)
      {
         deerType = "deer";
         deer2Type = "turkey";
      }
      else if (variantChance == 2)
      {
         deerType = "turkey";
         deer2Type = "deer";
      }
      if (rmRandInt(1,2) == 1)
	   centerHerdType = "deer";
      else
         centerHerdType = "turkey";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineTin";
      sheepType = "cow";
	coverUp = 1;
      makeCliffs = 2;
      tropicalMap = 1;

      if (sixChoice == 1) 
         nativePattern = 26;
      else if (sixChoice == 2) 
         nativePattern = 3;
      else if (sixChoice == 3) 
         nativePattern = 13;
      else if (sixChoice == 4) 
         nativePattern = 42;
      else if (sixChoice == 5) 
         nativePattern = 35;
      else if (sixChoice == 6) 
         nativePattern = 36;
   }
   else if (patternChance == 28) // palm desert
   {   
      rmSetMapType("sonora");
	rmSetMapType("grass");
      if (lightingChance == 1)
         rmSetLightingSet("seville");
      else
         rmSetLightingSet("pampas");
	if (twoChoice == 1)
	{
         baseType = "texas_dirt";
         cliffType = "Texas";
	}
	else
	{
         baseType = "sonora_dirt";
         cliffType = "Sonora";

	}
	forestType = "caribbean palm forest";
	treeType = "TreeCaribbean";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "turkey";
         centerHerdType = "deer";
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "deer";
         centerHerdType = "turkey";
	}
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
      sheepType = "cow";
      vultures = 1;
	coverUp = 1;
      makeCliffs = 2;
	noCliffForest = 1;
      makeBarrierRangeForest = 0;

	if (fourChoice == 1)
	   nativePattern = 36;
	else if (fourChoice == 2)
	   nativePattern = 34;
	else if (fourChoice == 3)
	   nativePattern = 35;
	else 
	   nativePattern = 33;
   }

   rmSetBaseTerrainMix(baseType);
   rmTerrainInitialize("yukon\ground1_yuk", 1);
   rmEnableLocalWater(false);
   rmSetMapType("land");

   rmSetWorldCircleConstraint(true);
   rmSetWindMagnitude(2.0);

// Native patterns
  if (nativePattern == 1)
  {
      rmSetSubCiv(0, "Cherokee");
      native1Name = "native cherokee village ";
      rmSetSubCiv(1, "Iroquois");
      native2Name = "native iroquois village ";
  }
  else if (nativePattern == 2)
  {
      rmSetSubCiv(0, "Comanche");
      native1Name = "native comanche village ";
      rmSetSubCiv(1, "Lakota");
      native2Name = "native lakota village ";
  }
  else if (nativePattern == 3)
  {
      rmSetSubCiv(0, "Cherokee");
      native1Name = "native cherokee village ";
      rmSetSubCiv(1, "Seminoles");
      native2Name = "native seminole village ";
  }
  else if (nativePattern == 4)
  {
      rmSetSubCiv(0, "Cheyenne");
      native1Name = "native cheyenne village ";
      rmSetSubCiv(1, "Huron");
      native2Name = "native huron village ";
  }
  else if (nativePattern == 5)
  {
      rmSetSubCiv(0, "Huron");
      native1Name = "native huron village ";
      rmSetSubCiv(1, "Cree");
      native2Name = "native cree village ";
  }
  else if (nativePattern == 6)
  {
      rmSetSubCiv(0, "Nootka");
      native1Name = "native nootka village ";
      rmSetSubCiv(1, "Cree");
      native2Name = "native cree village ";
  }
  else if (nativePattern == 7)
  {
      rmSetSubCiv(0, "Nootka");
      native1Name = "native nootka village ";
      rmSetSubCiv(1, "Cheyenne");
      native2Name = "native cheyenne village ";
  }
  else if (nativePattern == 8)
  {
      rmSetSubCiv(0, "Cree");
      native1Name = "native cree village ";
      rmSetSubCiv(1, "Cheyenne");
      native2Name = "native cheyenne village ";
  }
  else if (nativePattern == 9)
  {
      rmSetSubCiv(0, "Seminoles");
      native1Name = "native seminole village ";
      rmSetSubCiv(1, "Comanche");
      native2Name = "native comanche village ";
  }
  else if (nativePattern == 10)
  {
      rmSetSubCiv(0, "Zapotec");
      native1Name = "native zapotec village ";
      rmSetSubCiv(1, "Comanche");
      native2Name = "native comanche village ";
  }
  else if (nativePattern == 11)
  {
      rmSetSubCiv(0, "Mapuche");
      native1Name = "native mapuche village ";
      rmSetSubCiv(1, "Maya");
      native2Name = "native maya village ";
  }
  else if (nativePattern == 12)
  {
      rmSetSubCiv(0, "Caribs");
      native1Name = "native carib village ";
      rmSetSubCiv(1, "Maya");
      native2Name = "native maya village ";
  }
  else if (nativePattern == 13)
  {
      rmSetSubCiv(0, "Caribs");
      native1Name = "native carib village ";
      rmSetSubCiv(1, "Tupi");
      native2Name = "native tupi village ";
  }
  else if (nativePattern == 14)
  {
      rmSetSubCiv(0, "Incas");
      native1Name = "native inca village ";
      rmSetSubCiv(1, "Tupi");
      native2Name = "native tupi village ";
  }
  else if (nativePattern == 15)
  {
      rmSetSubCiv(0, "Maya");
      native1Name = "native maya village ";
      rmSetSubCiv(1, "Tupi");
      native2Name = "native tupi village ";
  }
  else if (nativePattern == 16)
  {
      rmSetSubCiv(0, "Nootka");
      native1Name = "native nootka village ";
      rmSetSubCiv(1, "Huron");
      native2Name = "native huron village ";
  }
  else if (nativePattern == 17)
  {
      rmSetSubCiv(0, "Incas");
      native1Name = "native inca village ";
      rmSetSubCiv(1, "Aztecs");
      native2Name = "native aztec village ";
  }
  else if (nativePattern == 18)
  {
      rmSetSubCiv(0, "Incas");
      native1Name = "native inca village ";
      rmSetSubCiv(1, "Caribs");
      native2Name = "native carib village ";
  }
  else if (nativePattern == 19)
  {
      rmSetSubCiv(0, "Cherokee");
      native1Name = "native cherokee village ";
      rmSetSubCiv(1, "Cheyenne");
      native2Name = "native cheyenne village ";
  }
  else if (nativePattern == 20)
  {
      rmSetSubCiv(0, "Cherokee");
      native1Name = "native cherokee village ";
      rmSetSubCiv(1, "Comanche");
      native2Name = "native comanche village ";
  }
  else if (nativePattern == 21)
  {
      rmSetSubCiv(0, "Seminoles");
      native1Name = "native seminole village ";
      rmSetSubCiv(1, "Huron");
      native2Name = "native huron village ";
  }
  else if (nativePattern == 22)
  {
      rmSetSubCiv(0, "Cherokee");
      native1Name = "native cherokee village ";
      rmSetSubCiv(1, "Cree");
      native2Name = "native cree village ";
  }
  else if (nativePattern == 23)
  {
      rmSetSubCiv(0, "Comanche");
      native1Name = "native comanche village ";
      rmSetSubCiv(1, "Cree");
      native2Name = "native cree village ";
  }
  else if (nativePattern == 24)
  {
      rmSetSubCiv(0, "Incas");
      native1Name = "native inca village ";
      rmSetSubCiv(1, "Maya");
      native2Name = "native maya village ";
  }
  else if (nativePattern == 25)
  {
      rmSetSubCiv(0, "Incas");
      native1Name = "native inca village ";
      rmSetSubCiv(1, "Mapuche");
      native2Name = "native mapuche village ";
  }
  else if (nativePattern == 26)
  {
      rmSetSubCiv(0, "Tupi");
      native1Name = "native tupi village ";
      rmSetSubCiv(1, "Mapuche");
      native2Name = "native mapuche village ";
  }
  else if (nativePattern == 27)
  {
      rmSetSubCiv(0, "Klamath");
      native1Name = "native klamath village ";
      rmSetSubCiv(1, "Nootka");
      native2Name = "native nootka village ";
  }
  else if (nativePattern == 28)
  {
      rmSetSubCiv(0, "Klamath");
      native1Name = "native klamath village ";
      rmSetSubCiv(1, "Cheyenne");
      native2Name = "native cheyenne village ";
  }
  else if (nativePattern == 29)
  {
      rmSetSubCiv(0, "Comanche");
      native1Name = "native comanche village ";
      rmSetSubCiv(1, "Cheyenne");
      native2Name = "native cheyenne village ";
  }
  else if (nativePattern == 30)
  {
      rmSetSubCiv(0, "Apache");
      native1Name = "native apache village ";
      rmSetSubCiv(1, "Cheyenne");
      native2Name = "native cheyenne village ";
  }
  else if (nativePattern == 31)
  {
      rmSetSubCiv(0, "Apache");
      native1Name = "native apache village ";
      rmSetSubCiv(1, "Navajo");
      native2Name = "native navajo village ";
  }
  else if (nativePattern == 32)
  {
      rmSetSubCiv(0, "Apache");
      native1Name = "native apache village ";
      rmSetSubCiv(1, "Comanche");
      native2Name = "native comanche village ";
  }
  else if (nativePattern == 33)
  {
      rmSetSubCiv(0, "Apache");
      native1Name = "native apache village ";
      rmSetSubCiv(1, "Zapotec");
      native2Name = "native zapotec village ";
  }
  else if (nativePattern == 34)
  {
      rmSetSubCiv(0, "Incas");
      native1Name = "native inca village ";
      rmSetSubCiv(1, "Zapotec");
      native2Name = "native zapotec village ";
  }
  else if (nativePattern == 35)
  {
      rmSetSubCiv(0, "Maya");
      native1Name = "native maya village ";
      rmSetSubCiv(1, "Zapotec");
      native2Name = "native zapotec village ";
  }
  else if (nativePattern == 36)
  {
      rmSetSubCiv(0, "Caribs");
      native1Name = "native carib village ";
      rmSetSubCiv(1, "Zapotec");
      native2Name = "native zapotec village ";
  }
  else if (nativePattern == 37)
  {
      rmSetSubCiv(0, "Navajo");
      native1Name = "native navajo village ";
      rmSetSubCiv(1, "Zapotec");
      native2Name = "native zapotec village ";
  }
  else if (nativePattern == 38)
  {
      rmSetSubCiv(0, "Navajo");
      native1Name = "native navajo village ";
      rmSetSubCiv(1, "Comanche");
      native2Name = "native comanche village ";
  }
  else if (nativePattern == 39)
  {
      rmSetSubCiv(0, "Navajo");
      native1Name = "native navajo village ";
      rmSetSubCiv(1, "Cheyenne");
      native2Name = "native cheyenne village ";
  }
  else if (nativePattern == 40)
  {
      rmSetSubCiv(0, "Cherokee");
      native1Name = "native cherokee village ";
      rmSetSubCiv(1, "Huron");
      native2Name = "native huron village ";
  }
  else if (nativePattern == 41)
  {
      rmSetSubCiv(0, "Lakota");
      native1Name = "native lakota village ";
      rmSetSubCiv(1, "Huron");
      native2Name = "native huron village ";
  }
  else if (nativePattern == 42)
  {
      rmSetSubCiv(0, "Caribs");
      native1Name = "native carib village ";
      rmSetSubCiv(1, "Seminoles");
      native2Name = "native seminole village ";
  }
  else if (nativePattern == 43)
  {
      rmSetSubCiv(0, "Apache");
      native1Name = "native apache village ";
      rmSetSubCiv(1, "Klamath");
      native2Name = "native klamath village ";
  }

// Precipitation
   if (patternChance == 16) // amazon
      if (lightingChance == 2)
         rmSetGlobalRain( 1.0 );
   if (patternChance == 7) // yukon
      if (lightingChance == 2)
         rmSetGlobalSnow( 0.8 );
   if (patternChance == 5) // great lakes winter
      rmSetGlobalSnow( 0.7 );
   if (patternChance == 8) // rockies
      if (lightingChance == 2)
         rmSetGlobalSnow( 0.5 );
   if (patternChance == 14) // yucatan
      if (lightingChance == 2)
         rmSetGlobalRain( 0.7 );
   if (patternChance == 6) // yukon tundra
      if (lightingChance == 2)         
         rmSetGlobalSnow( 0.7 );
   
   chooseMercs();
	wotta_triggers();

// Define some classes.
   int classPlayer=rmDefineClass("player");
   rmDefineClass("classPatch");
   rmDefineClass("starting settlement");
   rmDefineClass("startingUnit");
   rmDefineClass("classForest");
   rmDefineClass("importantItem");
   rmDefineClass("natives");
   rmDefineClass("classCliff");
   rmDefineClass("classBarrierRidge");
   rmDefineClass("center");
   rmDefineClass("classNugget");
   rmDefineClass("socketClass");
   rmDefineClass("classBase");
   int classHuntable=rmDefineClass("huntableFood");   
   int classHerdable=rmDefineClass("herdableFood"); 
   int canyon=rmDefineClass("canyon");

   // Text
   rmSetStatusText("",0.10);

// -------------Define constraints
   // Map edge constraints
   int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
   int secondEdgeConstraint=rmCreateBoxConstraint("avoid edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);

   // Center constraints
   int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 60.0);

   // Player constraints
   int playerConstraintForest=rmCreateClassDistanceConstraint("forests kinda stay away from players", classPlayer, 15.0);
   int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 40.0);
   int mediumPlayerConstraint=rmCreateClassDistanceConstraint("medium stay away from players", classPlayer, 25.0);
   int nuggetPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 60.0);
   int farPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players more", classPlayer, 85.0);
   int fartherPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players the most", classPlayer, 105.0);
   int longPlayerConstraint=rmCreateClassDistanceConstraint("land stays away from players", classPlayer, 70.0); 

   // Nature avoidance
   int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
   int shortForestConstraint=rmCreateClassDistanceConstraint("patch vs. forest", rmClassID("classForest"), 15.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), forestDist);
   int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
   int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "gold", 10.0);
   int shortAvoidSilver=rmCreateTypeDistanceConstraint("short gold avoid gold", "Mine", 20.0);
   int coinAvoidCoin=rmCreateTypeDistanceConstraint("coin avoids coin", "gold", 45.0);
   int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 1.0);
   int avoidSheep=rmCreateClassDistanceConstraint("sheep avoids sheep etc", rmClassID("herdableFood"), 45.0);
   int huntableConstraint=rmCreateClassDistanceConstraint("huntable constraint", rmClassID("huntableFood"), 35.0);
   int longHuntableConstraint=rmCreateClassDistanceConstraint("long huntable constraint", rmClassID("huntableFood"), 55.0);
   int forestsAvoidBison=rmCreateClassDistanceConstraint("forest avoids bison", rmClassID("huntableFood"), 15.0);

   // Avoid impassable land, certain features
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
   int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 18.0);
   int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 8.0);
   int avoidCliffs=rmCreateClassDistanceConstraint("stuff vs. cliff", rmClassID("classCliff"), 12.0);
   int avoidCliff20=rmCreateClassDistanceConstraint("avoid cliffs 20", rmClassID("classCliff"), 20.0);
   int avoidCliff30=rmCreateClassDistanceConstraint("avoid cliffs 30", rmClassID("classCliff"), 30.0);
   int avoidCliffsShort=rmCreateClassDistanceConstraint("stuff vs. cliff short", rmClassID("classCliff"), 7.0);
   int cliffsAvoidCliffs=rmCreateClassDistanceConstraint("cliffs vs. cliffs", rmClassID("classCliff"), 30.0);
   int avoidBarrier=rmCreateClassDistanceConstraint("stuff vs. barrier", rmClassID("classBarrierRidge"), 10.0);
   int avoidBase=rmCreateClassDistanceConstraint("stuff vs. base", rmClassID("classBase"), 1.0);
   int avoidCanyons=rmCreateClassDistanceConstraint("avoid canyons", rmClassID("canyon"), 35.0);
   int shortAvoidCanyons=rmCreateClassDistanceConstraint("short avoid canyons", rmClassID("canyon"), 15.0);
  
   // Unit avoidance
   int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 30.0);
   int avoidStartingUnitsSmall=rmCreateClassDistanceConstraint("objects avoid starting units small", rmClassID("startingUnit"), 10.0);
   int avoidImportantItem=rmCreateClassDistanceConstraint("things avoid each other", rmClassID("importantItem"), 10.0);
   int avoidImportantItemSmall=rmCreateClassDistanceConstraint("important item small avoidance", rmClassID("importantItem"), 7.0);
   int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 60.0);
   int avoidNativesMed=rmCreateClassDistanceConstraint("stuff avoids natives medium", rmClassID("natives"), 35.0);
   int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives shorter", rmClassID("natives"), 15.0);
   int avoidNugget=rmCreateClassDistanceConstraint("nugget vs. nugget", rmClassID("classNugget"), 42.0);
   int avoidNuggetMed=rmCreateClassDistanceConstraint("nugget vs. nugget med", rmClassID("classNugget"), 50.0);
   int avoidNuggetLong=rmCreateClassDistanceConstraint("nugget vs. nugget long", rmClassID("classNugget"), 70.0);
   int avoidNuggetSmall=rmCreateTypeDistanceConstraint("avoid nuggets by a little", "AbstractNugget", 10.0);
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

   // Trade route avoidance.
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 8.0);
   int avoidTradeRouteCliff = rmCreateTradeRouteDistanceConstraint("trade route cliff", 10.0);
   int avoidSocket=rmCreateClassDistanceConstraint("avoid sockets", rmClassID("socketClass"), 12.0);
// ---------------------------------------------------------------------------------------
   // Text
   rmSetStatusText("",0.15);

// Set up player starting locations
if (cNumberTeams == 2)
{
   if (cNumberNonGaiaPlayers == 2)
   {
      if (axisChance == 1)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.22, 0.23);
	   }
	   else
	   {
            rmSetPlacementSection(0.77, 0.78);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.27, 0.28);
	   }
	   else
	   {
            rmSetPlacementSection(0.72, 0.73);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);
	}
	else if (axisChance == 2)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.02, 0.03);
	   }
	   else
	   {
	      rmSetPlacementSection(0.46, 0.47);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.96, 0.97);
	   }
	   else
	   {
	      rmSetPlacementSection(0.52, 0.53);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);
	}
   }
   else if (cNumberNonGaiaPlayers < 5)
   {
      if (axisChance == 1)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.18, 0.32);
	   }
	   else
	   {
	      rmSetPlacementSection(0.68, 0.82);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.18, 0.32);
	   }
	   else
	   {
	      rmSetPlacementSection(0.68, 0.82);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);
	}
	else if (axisChance == 2)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.93, 0.07);
	   }
	   else
	   {
	      rmSetPlacementSection(0.43, 0.57);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.93, 0.07);
	   }
	   else
	   {
	      rmSetPlacementSection(0.43, 0.57);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);
	}
   }
   else if (cNumberNonGaiaPlayers < 7)
   {
      if (axisChance == 1)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.14, 0.36);
	   }
	   else
	   {
	      rmSetPlacementSection(0.64, 0.86);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.14, 0.36);
	   }
	   else
	   {
	      rmSetPlacementSection(0.64, 0.86);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);
	}
	else if (axisChance == 2)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.89, 0.11);
	   }
	   else
	   {
	      rmSetPlacementSection(0.39, 0.61);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.89, 0.11);
	   }
	   else
	   {
	      rmSetPlacementSection(0.39, 0.61);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);
	}
   }
   else
   {
      if (axisChance == 1)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.13, 0.37);
	   }
	   else
	   {
	      rmSetPlacementSection(0.63, 0.87);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.13, 0.37);
	   }
	   else
	   {
	      rmSetPlacementSection(0.63, 0.87);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);
	}
	else if (axisChance == 2)
	{
	   rmSetPlacementTeam(0);
	   if (playerSide == 1)
	   {
            rmSetPlacementSection(0.88, 0.12);
	   }
	   else
	   {
	      rmSetPlacementSection(0.38, 0.62);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);

	   rmSetPlacementTeam(1);
	   if (playerSide == 2)
	   {
            rmSetPlacementSection(0.88, 0.12);
	   }
	   else
	   {
	      rmSetPlacementSection(0.38, 0.62);
	   }
	   rmPlacePlayersCircular(0.39, 0.4, 0.0);
	}
   }
}
else if (cNumberTeams > 2)
   rmPlacePlayersSquare(0.38, 0.0, 0.0);

   // Text
   rmSetStatusText("",0.20);
	
// Set up player areas.
   float playerFraction=rmAreaTilesToFraction(120);
   for(i=1; <cNumberPlayers)
   {
      int id=rmCreateArea("Player"+i);
      rmSetPlayerArea(i, id);
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 1);
      rmAddAreaConstraint(id, playerConstraint); 
      rmAddAreaConstraint(id, longAvoidImpassableLand);
      rmAddAreaConstraint(id, playerEdgeConstraint); 
      rmSetAreaLocPlayer(id, i);
      rmSetAreaMix(id, baseType);
      rmSetAreaWarnFailure(id, false);
   }
   rmBuildAllAreas();

   // Text
   rmSetStatusText("",0.25);

// Central barrier range
   // Define base size
   int radius = size * 0.5;
   int baseRidgeSize = radius * radius * 0.22;
   int midRidgeSize = radius * radius * 0.1;
   int innerRidgeSize = radius * radius * 0.04;
   int midRidgeSize2 = midRidgeSize * 0.65;
   int innerRidgeSize2 = innerRidgeSize * 0.65;

   // base
   int mountainBaseID = rmCreateArea("mountain base"); 
   rmAddAreaToClass(mountainBaseID, rmClassID("classBase"));
   rmSetAreaLocation(mountainBaseID, 0.5, 0.5); 
   if (axisChance == 1) 
      rmAddAreaInfluenceSegment(mountainBaseID, 0.5, 0.0, 0.5, 1.0); 
   else
      rmAddAreaInfluenceSegment(mountainBaseID, 0.0, 0.5, 1.0, 0.5); 
   rmSetAreaWarnFailure(mountainBaseID, false);
   rmSetAreaSize(mountainBaseID, rmAreaTilesToFraction(baseRidgeSize), rmAreaTilesToFraction(baseRidgeSize));
   rmSetAreaBaseHeight(mountainBaseID, 4.0);
   rmSetAreaElevationType(mountainBaseID, cElevTurbulence);
   rmSetAreaElevationVariation(mountainBaseID, rmRandInt(2,3));
   rmSetAreaHeightBlend(mountainBaseID, 1);
   rmSetAreaCoherence(mountainBaseID, rmRandFloat(0.7,0.8));
   rmSetAreaSmoothDistance(mountainBaseID, rmRandInt(8,12));
   if (patternChance == 6)  // Yukon Tundra
   {
      rmSetAreaTerrainType(mountainBaseID, "yukon\ground1_yuk");
      rmAddAreaTerrainLayer(mountainBaseID, "yukon\ground5_yuk", 0, 3);
      rmAddAreaTerrainLayer(mountainBaseID, "yukon\ground4_yuk", 3, 6);
      rmAddAreaTerrainLayer(mountainBaseID, "yukon\ground8_yuk", 6, 9);
   }
   if (patternChance == 22) // S Araucania
   {
      rmSetAreaTerrainType(mountainBaseID, "rockies\groundsnow1_roc");
      rmAddAreaTerrainLayer(mountainBaseID, "patagonia\ground_snow1_pat", 0, 5);
	rmAddAreaTerrainLayer(mountainBaseID, "patagonia\ground_snow2_pat", 5, 7);
   }
   if (patternChance == 8) // Rockies
   {
      rmSetAreaTerrainType(mountainBaseID, "rockies\groundsnow1_roc");
      rmAddAreaTerrainLayer(mountainBaseID, "rockies\groundsnow8_roc", 0, 3);
      rmAddAreaTerrainLayer(mountainBaseID, "rockies\groundsnow7_roc", 3, 6);
      rmAddAreaTerrainLayer(mountainBaseID, "rockies\groundsnow6_roc", 6, 9);
   }
   rmBuildArea(mountainBaseID);

   // Center 2 part barrier range
   int barrier1ID=rmCreateArea("barrier 1"); // south mt
   rmSetAreaWarnFailure(barrier1ID, false); 
   if (patternChance == 22)
      rmSetAreaCliffType(barrier1ID, "rocky mountain2");
   else
      rmSetAreaCliffType(barrier1ID, cliffType);
   rmAddAreaToClass(barrier1ID, rmClassID("classCliff"));
   rmAddAreaToClass(barrier1ID, rmClassID("classBarrierRidge"));
   rmAddAreaConstraint(barrier1ID, avoidCliff30);
   if (gapPattern == 1)
   {
      if (cNumberNonGaiaPlayers > 6) 
         rmSetAreaSize(barrier1ID, 0.031, 0.033);
	else  if (cNumberNonGaiaPlayers < 4)
         rmSetAreaSize(barrier1ID, 0.037, 0.039);
      else
         rmSetAreaSize(barrier1ID, 0.036, 0.038);
      if (axisChance == 1)
      { 
         rmSetAreaLocation(barrier1ID, 0.5, 0.25);
         rmAddAreaInfluenceSegment(barrier1ID, 0.5, 0.0, 0.5, 0.43);
	}
	else
	{
         rmSetAreaLocation(barrier1ID, 0.25, 0.5);
         rmAddAreaInfluenceSegment(barrier1ID, 0.0, 0.5, 0.43, 0.5);
	}
      rmSetAreaCliffEdge(barrier1ID, 1, 1.0, 0.1, 1.0, 0);
   }
   else if (gapPattern == 2)
   {
      if (cNumberNonGaiaPlayers < 4)
         rmSetAreaSize(barrier1ID, 0.024, 0.025);
	else
         rmSetAreaSize(barrier1ID, 0.021, 0.023);
      if (axisChance == 1)
      {
         rmSetAreaLocation(barrier1ID, 0.5, 0.16);
         rmAddAreaInfluenceSegment(barrier1ID, 0.5, 0.0, 0.5, 0.26);
	}
	else
	{
         rmSetAreaLocation(barrier1ID, 0.16, 0.5);
         rmAddAreaInfluenceSegment(barrier1ID, 0.0, 0.5, 0.26, 0.5);
	}
      rmSetAreaCliffEdge(barrier1ID, 1, 1.0, 0.1, 1.0, 0);
   }
   else if (gapPattern == 3)
   {
      if (cNumberNonGaiaPlayers < 4)
         rmSetAreaSize(barrier1ID, 0.065, 0.065);
      else if (cNumberNonGaiaPlayers > 6) 
         rmSetAreaSize(barrier1ID, 0.055, 0.055); 
	else
         rmSetAreaSize(barrier1ID, 0.06, 0.06);
      if (axisChance == 1)
      {
         rmSetAreaLocation(barrier1ID, 0.5, 0.25);
         rmAddAreaInfluenceSegment(barrier1ID, 0.5, 0.0, 0.5, 0.71);
	}
	else
	{
         rmSetAreaLocation(barrier1ID, 0.25, 0.5);
         rmAddAreaInfluenceSegment(barrier1ID, 0.0, 0.5, 0.71, 0.5);
	}
      rmSetAreaCliffEdge(barrier1ID, 1, 1.0, 0.1, 1.0, 0);
   }
   rmSetAreaMinBlobs(barrier1ID, 2);
   rmSetAreaMaxBlobs(barrier1ID, 4);
   rmSetAreaMinBlobDistance(barrier1ID, 10.0);
   rmSetAreaMaxBlobDistance(barrier1ID, 14.0);
   if ((patternChance == 8) || (patternChance == 9) || (patternChance == 6) || (patternChance == 10) || (patternChance == 19) ||  (patternChance == 22)) 
      rmSetAreaCliffPainting(barrier1ID, true, true, true, 1.5, true);
   else
      rmSetAreaCliffPainting(barrier1ID, false, true, true, 1.5, true);
   if ((patternChance == 3) || (patternChance == 15)) 
      rmSetAreaCliffHeight(barrier1ID, rmRandInt(6,7), 1.0, 1.0);
   else
      rmSetAreaCliffHeight(barrier1ID, rmRandInt(8,9), 1.0, 1.0);
   rmSetAreaCoherence(barrier1ID, 0.9);
   rmSetAreaSmoothDistance(barrier1ID, 5);
   rmSetAreaHeightBlend(barrier1ID, 2);

   int barrier2ID=rmCreateArea("barrier 2"); // north mt
   rmSetAreaWarnFailure(barrier2ID, false); 
   if (patternChance == 22)
      rmSetAreaCliffType(barrier2ID, "rocky mountain2");
   else
      rmSetAreaCliffType(barrier2ID, cliffType);
   rmAddAreaToClass(barrier2ID, rmClassID("classCliff"));
   rmAddAreaToClass(barrier2ID, rmClassID("classBarrierRidge"));
   rmAddAreaConstraint(barrier2ID, avoidCliff30);
   rmAddAreaConstraint(barrier2ID, avoidTradeRouteCliff);
   if (gapPattern == 1)
   {
      if (cNumberNonGaiaPlayers > 6) 
         rmSetAreaSize(barrier2ID, 0.031, 0.033);
	else if (cNumberNonGaiaPlayers < 4)
         rmSetAreaSize(barrier2ID, 0.037, 0.039);
      else
         rmSetAreaSize(barrier2ID, 0.036, 0.038);
      if (axisChance == 1)
      {
         rmSetAreaLocation(barrier2ID, 0.5, 0.75);
         rmAddAreaInfluenceSegment(barrier2ID, 0.5, 1.0, 0.5, 0.57);
	}
	else
	{
         rmSetAreaLocation(barrier2ID, 0.75, 0.5);
         rmAddAreaInfluenceSegment(barrier2ID, 1.0, 0.5, 0.57, 0.5);
	}
      rmSetAreaCliffEdge(barrier2ID, 1, 1.0, 0.1, 1.0, 0);
   }
   else if (gapPattern == 2)
   {
      if (cNumberNonGaiaPlayers < 4)
         rmSetAreaSize(barrier2ID, 0.06, 0.06);
      else if (cNumberNonGaiaPlayers > 6) 
         rmSetAreaSize(barrier2ID, 0.05, 0.05); 
	else
         rmSetAreaSize(barrier2ID, 0.055, 0.055);
      if (axisChance == 1)
      {
         rmSetAreaLocation(barrier2ID, 0.5, 0.75);
         rmAddAreaInfluenceSegment(barrier2ID, 0.5, 1.0, 0.5, 0.29);
	}
	else
	{
         rmSetAreaLocation(barrier2ID, 0.55, 0.5);
         rmAddAreaInfluenceSegment(barrier2ID, 1.0, 0.5, 0.29, 0.5);
	}
      rmSetAreaCliffEdge(barrier2ID, 1, 1.0, 0.1, 1.0, 0);
   }
   else if (gapPattern == 3)
   {
      if (cNumberNonGaiaPlayers < 4)
         rmSetAreaSize(barrier2ID, 0.026, 0.027);
	else
         rmSetAreaSize(barrier2ID, 0.021, 0.023);
      if (axisChance == 1)
      {
         rmSetAreaLocation(barrier2ID, 0.5, 0.84);
         rmAddAreaInfluenceSegment(barrier2ID, 0.5, 1.0, 0.5, 0.72);
	}
	else
	{
         rmSetAreaLocation(barrier2ID, 0.84, 0.5);
         rmAddAreaInfluenceSegment(barrier2ID, 1.0, 0.5, 0.72, 0.5);
	}
      rmSetAreaCliffEdge(barrier2ID, 1, 1.0, 0.1, 1.0, 0);
   }
   rmSetAreaMinBlobs(barrier2ID, 2);
   rmSetAreaMaxBlobs(barrier2ID, 4);
   rmSetAreaMinBlobDistance(barrier2ID, 10.0);
   rmSetAreaMaxBlobDistance(barrier2ID, 14.0);
   if ((patternChance == 8) || (patternChance == 9) || (patternChance == 6) || (patternChance == 10) || (patternChance == 19) || (patternChance == 22))
      rmSetAreaCliffPainting(barrier2ID, true, true, true, 1.5, true);
   else
      rmSetAreaCliffPainting(barrier2ID, false, true, true, 1.5, true);
   if ((patternChance == 3) || (patternChance == 15)) 
      rmSetAreaCliffHeight(barrier2ID, rmRandInt(6,7), 1.0, 1.0);
   else
      rmSetAreaCliffHeight(barrier2ID, rmRandInt(8,9), 1.0, 1.0);
   rmSetAreaCoherence(barrier2ID, 0.9);
   rmSetAreaSmoothDistance(barrier2ID, 5);
   rmSetAreaHeightBlend(barrier2ID, 2);

   if (gapPattern == 3)
   {
      rmBuildArea(barrier2ID);
      rmBuildArea(barrier1ID);
   }
   else if (gapPattern == 2)
   {
      rmBuildArea(barrier1ID);
      rmBuildArea(barrier2ID);
   }
   else if (gapPattern == 1)
   {
      if (rmRandInt(1,2) == 1)
      {
         rmBuildArea(barrier2ID);
         rmBuildArea(barrier1ID);
      }
      else 
      {
         rmBuildArea(barrier1ID);
         rmBuildArea(barrier2ID);
      }
   }

   // Text
   rmSetStatusText("",0.30);

// Trade Routes
variantChance = rmRandInt(1,2);
if (trPattern == 2) // 2 opposite inner semicircular routes
{
   // first route
   int tradeRouteID = rmCreateTradeRoute();
   if (axisChance == 1) 
   {	
	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.65);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.75, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.35);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.0);
   }
   else 
   {	
	rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.6);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.7);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.7);
	rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.6);
   }
   rmBuildTradeRoute(tradeRouteID, "dirt");

   // second route
   int tradeRouteID2 = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.4, 0.0);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.3, 0.35);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.25, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.3, 0.65);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.4, 1.0);
   }
   else
   {
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.0, 0.4);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.35, 0.3);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.25);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.65, 0.3);
	rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, 0.4);
   }
   rmBuildTradeRoute(tradeRouteID2, "carolinas\trade_route");	
}
else if (trPattern == 4)  // two side-to-side
{
   int tradeRouteID4 = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.67, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.62, 0.78);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.62, 0.7);
	if (variantChance == 1)
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.67, 0.55);
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.67, 0.45);
	}
	else
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.64, 0.55);
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.64, 0.45);
	}
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.62, 0.3);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.62, 0.22);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.67, 0.0);
   }
   else if (axisChance == 2) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID4, 1.0, 0.67);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.78, 0.63);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.7, 0.62);
	if (variantChance == 1)
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.53, 0.67);
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.47, 0.67);
	}
	else
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.55, 0.65);
	   rmAddTradeRouteWaypoint(tradeRouteID4, 0.45, 0.65);
	}
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.3, 0.62);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.22, 0.63);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.0, 0.67);
   }
   rmBuildTradeRoute(tradeRouteID4, "carolinas\trade_route");

   int tradeRouteID4A = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
      rmAddTradeRouteWaypoint(tradeRouteID4A, 0.33, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.38, 0.78);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.38, 0.7);
	if (variantChance == 1)
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.33, 0.55);
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.33, 0.45);
	}
	else
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.36, 0.55);
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.36, 0.45);
	}
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.38, 0.3);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.38, 0.22);
      rmAddTradeRouteWaypoint(tradeRouteID4A, 0.33, 0.0);
   }
   else if (axisChance == 2) 
   {
	rmAddTradeRouteWaypoint(tradeRouteID4A, 1.0, 0.33);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.78, 0.37);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.7, 0.38);
	if (variantChance == 1)
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.53, 0.33);
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.47, 0.33);
	}
	else
	{
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.55, 0.35);
	   rmAddTradeRouteWaypoint(tradeRouteID4A, 0.45, 0.35);
	}
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.3, 0.38);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.22, 0.37);
	rmAddTradeRouteWaypoint(tradeRouteID4A, 0.0, 0.33);
   }
   rmBuildTradeRoute(tradeRouteID4A, "dirt");
}
else if (trPattern == 3)  // two opposite parabolas
{
   int tradeRouteID3 = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
	if (variantChance == 1)
	   rmAddTradeRouteWaypoint(tradeRouteID3, 0.75, 1.0);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID3, 0.85, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.7, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.65, 0.62);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.62, 0.51);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.62, 0.49);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.65, 0.38);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.7, 0.11);
	if (variantChance == 1)
	   rmAddTradeRouteWaypoint(tradeRouteID3, 0.75, 0.0);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID3, 0.85, 0.0);
   }
   else if (axisChance == 2) 
   {
	if (variantChance == 1)
	   rmAddTradeRouteWaypoint(tradeRouteID3, 1.0, 0.75);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID3, 1.0, 0.85);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.88, 0.7);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.62, 0.65);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.51, 0.62);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.49, 0.62);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.38, 0.65);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.12, 0.7);
	if (variantChance == 1)
	   rmAddTradeRouteWaypoint(tradeRouteID3, 0.0, 0.75);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID3, 0.0, 0.85);
   }
   rmBuildTradeRoute(tradeRouteID3, "carolinas\trade_route");

   int tradeRouteID3A = rmCreateTradeRoute();
   if (axisChance == 1) 
   {
	if (variantChance == 1)
         rmAddTradeRouteWaypoint(tradeRouteID3A, 0.25, 1.0);
	else
         rmAddTradeRouteWaypoint(tradeRouteID3A, 0.15, 1.0);
      rmAddTradeRouteWaypoint(tradeRouteID3A, 0.3, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.35, 0.62);
      rmAddTradeRouteWaypoint(tradeRouteID3A, 0.38, 0.51);
      rmAddTradeRouteWaypoint(tradeRouteID3A, 0.38, 0.49);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.35, 0.38);
      rmAddTradeRouteWaypoint(tradeRouteID3A, 0.3, 0.12);
	if (variantChance == 1)
         rmAddTradeRouteWaypoint(tradeRouteID3A, 0.25, 0.0);
	else
         rmAddTradeRouteWaypoint(tradeRouteID3A, 0.15, 0.0);
   }
   else if (axisChance == 2) 
   {
	if (variantChance == 1)
	   rmAddTradeRouteWaypoint(tradeRouteID3A, 1.0, 0.25);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID3A, 1.0, 0.15);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.88, 0.3);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.62, 0.35);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.51, 0.38);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.49, 0.38);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.38, 0.35);
	rmAddTradeRouteWaypoint(tradeRouteID3A, 0.12, 0.3);
	if (variantChance == 1)
	   rmAddTradeRouteWaypoint(tradeRouteID3A, 0.0, 0.25);
	else
	   rmAddTradeRouteWaypoint(tradeRouteID3A, 0.0, 0.15);
   }
   rmBuildTradeRoute(tradeRouteID3A, "dirt");
}
else if (trPattern == 1)  // 2 'semicircular' middle routes
{
   int tradeRouteID1 = rmCreateTradeRoute();
   int tradeRouteID1A = rmCreateTradeRoute();
   if (axisChance == 2)
   {
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.0, 0.62);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.2, 0.72);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.25, 0.76);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.5, 0.8);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.75, 0.76);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.8, 0.72);
      rmAddTradeRouteWaypoint(tradeRouteID1, 1.0, 0.62);
      rmBuildTradeRoute(tradeRouteID1, "carolinas\trade_route");	

      rmAddTradeRouteWaypoint(tradeRouteID1A, 1.0, 0.38);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.8, 0.28);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.75, 0.24);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.5, 0.2);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.25, 0.24);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.2, 0.28);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.0, 0.38);
      rmBuildTradeRoute(tradeRouteID1A, "dirt");
   }
   else if (axisChance == 1)
   {	
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.62, 1.0);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.72, 0.8);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.76, 0.75);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.8, 0.5);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.76, 0.25);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.72, 0.2);
      rmAddTradeRouteWaypoint(tradeRouteID1, 0.62, 0.0);
      rmBuildTradeRoute(tradeRouteID1, "carolinas\trade_route");	

      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.38, 0.0);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.28, 0.2);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.24, 0.25);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.2, 0.5);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.28, 0.8);
      rmAddTradeRouteWaypoint(tradeRouteID1A, 0.38, 1.0);
      rmBuildTradeRoute(tradeRouteID1A, "dirt");
   }
}
else if (trPattern == 5)  // 2 diagonal routes
{
   int tradeRouteID5 = rmCreateTradeRoute();
   int tradeRouteID5A = rmCreateTradeRoute();
   if (axisChance == 2)
   {
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.0, 0.62);
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.15, 0.66);
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.25, 0.7);
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.5, 0.74);
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.75, 0.78);
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.85, 0.82);
      rmAddTradeRouteWaypoint(tradeRouteID5, 1.0, 0.86);
      rmBuildTradeRoute(tradeRouteID5, "carolinas\trade_route");	

      rmAddTradeRouteWaypoint(tradeRouteID5A, 1.0, 0.38);
      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.85, 0.34);
      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.75, 0.3);
      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.5, 0.26);
      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.25, 0.22);
      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.15, 0.18);
      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.0, 0.14);
      rmBuildTradeRoute(tradeRouteID5A, "dirt");
   }
   else if (axisChance == 1)
   {	
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.62, 1.0);
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.66, 0.8);
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.7, 0.75);
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.74, 0.5);
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.78, 0.25);
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.82, 0.2);
      rmAddTradeRouteWaypoint(tradeRouteID5, 0.86, 0.0);
      rmBuildTradeRoute(tradeRouteID5, "carolinas\trade_route");	

      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.38, 0.0);
      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.34, 0.15);
      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.3, 0.25);
      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.26, 0.5);
      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.22, 0.75);
      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.18, 0.85);
      rmAddTradeRouteWaypoint(tradeRouteID5A, 0.14, 1.0);
      rmBuildTradeRoute(tradeRouteID5A, "dirt");
   }
}

   // Text
   rmSetStatusText("",0.35);

// Trade sockets
   int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
   rmSetObjectDefAllowOverlap(socketID, true);
   rmAddObjectDefToClass(socketID, rmClassID("importantItem"));
   rmSetObjectDefMinDistance(socketID, 0.0);
   rmSetObjectDefMaxDistance(socketID, 7.0);
   variantChance = rmRandInt(1,2);

if (trPattern == 2) // 2 opposite inner semicircular routes
{
   // add the meeting poles along the trade route.
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
   vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.17);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   if (socketPattern == 1)
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }

   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.83);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   // change the trade route for the new sockets
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID2);
   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID2, 0.83);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   if (socketPattern == 1)
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID2, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }

   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID2, 0.17);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
}
else if (trPattern == 4) //  2 side-to-side
{
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID4);
   if (socketPattern == 1) // 3 sockets per route
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.12);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.88);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   else  // 2 sockets per route
   {
	if (variantChance == 1)
	{
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.23);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.77);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
	else
	{
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.32);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4, 0.68);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
   }

   // change the trade route for the new sockets
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID4A);
   if (socketPattern == 1)  // 3 sockets per route
   {
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.88);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
  
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.12);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   else  // 2 sockets per route
   {
	if (variantChance == 1)
	{
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.23);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.77);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
	else
	{
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.68);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID4A, 0.32);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
   }
}
else if (trPattern == 3) //  2 parabolas
{
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID3);
   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID3, 0.17);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   if (socketPattern == 1)
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID3, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }

   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID3, 0.83);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   // change the trade route for the new sockets
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID3A);
   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID3A, 0.83);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   if (socketPattern == 1)
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID3A, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }

   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID3A, 0.17);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
}
else if (trPattern == 1) //  2 middle semicircles
{
   if (socketPattern == 1) // 3 per route
   { 
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID1);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.1);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.9);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      // change the trade route for the new sockets
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID1A);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.1);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.9);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   if (socketPattern == 2)  
   { 
	if (variantChance == 1) // 4 per route
	{
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID1);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.1);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.35);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.6);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.85);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      // change the trade route for the new sockets
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID1A);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.1);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.35);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.6);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.85);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
	else  // 2 per route
	{
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID1);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.28);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1, 0.72);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      // change the trade route for the new sockets
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID1A);
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.28);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID1A, 0.72);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	}
   }
}
else if (trPattern == 5) //  2 diagonals
{
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID5);
   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.21);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   if (socketPattern == 1)
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5, 0.79);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   // change the trade route for the new sockets
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID5A);
   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5A, 0.79);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   if (socketPattern == 1)
   { 
      socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5A, 0.5);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }
   socketLoc = rmGetTradeRouteWayPoint(tradeRouteID5A, 0.21);
   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
}

   //Text
   rmSetStatusText("",0.40);

// Starting TCs and units 	
   int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
   rmSetObjectDefMinDistance(startingUnits, 5.0);
   rmSetObjectDefMaxDistance(startingUnits, 10.0);
   rmAddObjectDefConstraint(startingUnits, avoidAll);
   rmAddObjectDefConstraint(startingUnits, avoidBase);

   int startingTCID= rmCreateObjectDef("startingTC");
   rmSetObjectDefMaxDistance(startingTCID, 18.0);
   rmAddObjectDefConstraint(startingTCID, avoidAll);
   rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);
   rmAddObjectDefConstraint(startingTCID, avoidBase);                
   if ( rmGetNomadStart())
   {
	rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 0.0);
   }
   else
   {
      rmAddObjectDefItem(startingTCID, "TownCenter", 1, 0.0);
   }

   for(i=1; <cNumberPlayers)
   {	
      rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
      rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }
   
// Central features & patches, per map or variant
   // Center area
   int centerArea=rmCreateArea("TheCenter");
   rmSetAreaSize(centerArea, 0.2, 0.2);
   rmSetAreaLocation(centerArea, 0.5, 0.5);
   rmAddAreaToClass(centerArea, rmClassID("center")); 

   // Dirt patches for Sonora
   if (patternChance == 13)
   {
	for (i=0; <cNumberNonGaiaPlayers*6)   
      {
		int dirtPatch=rmCreateArea("open dirt patch "+i);
		rmSetAreaWarnFailure(dirtPatch, false);
		rmSetAreaSize(dirtPatch, rmAreaTilesToFraction(150), rmAreaTilesToFraction(200));
		rmSetAreaTerrainType(dirtPatch, "sonora\ground7_son");
		rmAddAreaToClass(dirtPatch, rmClassID("classPatch"));
		rmSetAreaMinBlobs(dirtPatch, 1);
		rmSetAreaMaxBlobs(dirtPatch, 5);
		rmSetAreaMinBlobDistance(dirtPatch, 16.0);
		rmSetAreaMaxBlobDistance(dirtPatch, 40.0);
		rmSetAreaCoherence(dirtPatch, 0.1);
		rmSetAreaSmoothDistance(dirtPatch, 10);
		rmAddAreaConstraint(dirtPatch, shortAvoidImpassableLand);
		rmAddAreaConstraint(dirtPatch, patchConstraint);
		rmBuildArea(dirtPatch); 
      }
   }

   // Snow patches for Yukon Tundra
   if (patternChance == 6)
   { 
      for(i=1; <cNumberPlayers*6)
      {
      int patchAID=rmCreateArea("PatchA"+i);
      rmSetAreaSize(patchAID, rmAreaTilesToFraction(175), rmAreaTilesToFraction(250));
      rmAddAreaToClass(patchAID, rmClassID("classPatch"));
      rmSetAreaTerrainType(patchAID, "yukon\ground1_yuk");
      rmAddAreaTerrainLayer(patchAID, "yukon\ground5_yuk", 0, 2);
      rmAddAreaTerrainLayer(patchAID, "yukon\ground4_yuk", 2, 3);
      rmAddAreaTerrainLayer(patchAID, "yukon\ground8_yuk", 3, 4);
      rmSetAreaWarnFailure(patchAID, false);
      rmSetAreaMinBlobs(patchAID, 2);
      rmSetAreaMaxBlobs(patchAID, 3);
      rmSetAreaMinBlobDistance(patchAID, 10.0);
      rmSetAreaMaxBlobDistance(patchAID, 20.0);
      rmSetAreaCoherence(patchAID, 0.3);
      rmAddAreaConstraint(patchAID, playerConstraint);
      rmAddAreaConstraint(patchAID, shortAvoidImpassableLand);
      rmAddAreaConstraint(patchAID, patchConstraint);
      rmSetAreaWarnFailure(patchAID, false);
      rmBuildArea(patchAID);
      }
   }

   // Text
   rmSetStatusText("",0.45);

// NATIVE AMERICANS
   // Village A 
   int villageAID = -1;
   int whichNative = rmRandInt(1,2);
   int villageType = rmRandInt(1,5);

   if (whichNative == 1)
	   villageAID = rmCreateGrouping("village A", native1Name+villageType);
   else if (whichNative == 2)
	   villageAID = rmCreateGrouping("village A", native2Name+villageType);   rmAddGroupingToClass(villageAID, rmClassID("natives"));

   rmAddGroupingToClass(villageAID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageAID, 0.0);
   rmSetGroupingMaxDistance(villageAID, size*0.1);
   rmAddGroupingConstraint(villageAID, avoidImpassableLand);
   rmAddGroupingConstraint(villageAID, avoidTradeRoute);
   rmAddGroupingConstraint(villageAID, avoidNativesMed);
   rmAddGroupingConstraint(villageAID, nuggetPlayerConstraint);
   rmAddGroupingConstraint(villageAID, avoidBarrier);

   // Village D - opposite type from A 
   int villageDID = -1;
   villageType = rmRandInt(1,5);

   if (whichNative == 2)
	   villageDID = rmCreateGrouping("village D", native1Name+villageType);
   else if (whichNative == 1)
	   villageDID = rmCreateGrouping("village D", native2Name+villageType);

   rmAddGroupingToClass(villageDID, rmClassID("natives"));
   rmAddGroupingToClass(villageDID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageDID, 0.0);
   rmSetGroupingMaxDistance(villageDID, size*0.1);
   rmAddGroupingConstraint(villageDID, avoidImpassableLand);
   rmAddGroupingConstraint(villageDID, avoidTradeRoute);
   rmAddGroupingConstraint(villageDID, avoidNativesMed);
   rmAddGroupingConstraint(villageDID, nuggetPlayerConstraint);
   rmAddGroupingConstraint(villageDID, avoidBarrier);

   // Village B - randomly same or opposite village A
   int villageBID = -1;	
   villageType = rmRandInt(1,5);
   whichNative = rmRandInt(1,2);

   if (whichNative == 1)
	   villageBID = rmCreateGrouping("village B", native1Name+villageType);
   else if (whichNative == 2)
	   villageBID = rmCreateGrouping("village B", native2Name+villageType);

   rmAddGroupingToClass(villageBID, rmClassID("importantItem"));
   rmAddGroupingToClass(villageBID, rmClassID("natives"));
   rmSetGroupingMinDistance(villageBID, 0.0);
   rmSetGroupingMaxDistance(villageBID, size*0.14);
   rmAddGroupingConstraint(villageBID, avoidImpassableLand);
   rmAddGroupingConstraint(villageBID, avoidTradeRoute);
   rmAddGroupingConstraint(villageBID, avoidNatives);
   rmAddGroupingConstraint(villageBID, nuggetPlayerConstraint);
   rmAddGroupingConstraint(villageBID, avoidBarrier);

// Placement of Native Americans
   if ((nativeSetup == 13) || (nativeSetup == 17))  
   {
      if (axisChance == 2)
	{
  	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageAID, 0, 0.79, 0.34);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.21, 0.34);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.79, 0.66);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.21, 0.66);
		   if (nativeSetup == 17)
		   {	
			rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.39);
			rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.61);
		   }
  
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageAID, 0, 0.7, 0.39);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.3, 0.39);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.7, 0.61);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.3, 0.61);
		   if (nativeSetup == 17)
		   {	
			rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.34);
			rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.66);
		   }
	      }
      }
	else if (axisChance == 1)
	{
	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageAID, 0, 0.39, 0.79);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.39, 0.21);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.61, 0.79);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.61, 0.21);
		   if (nativeSetup == 17)
		   {	
			rmPlaceGroupingAtLoc(villageDID, 0, 0.34, 0.5);
			rmPlaceGroupingAtLoc(villageDID, 0, 0.66, 0.5);
		   }
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageAID, 0, 0.34, 0.7);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.34, 0.3);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.66, 0.7);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.66, 0.3);
		   if (nativeSetup == 17)
		   {	
			rmPlaceGroupingAtLoc(villageDID, 0, 0.39, 0.5);
			rmPlaceGroupingAtLoc(villageDID, 0, 0.61, 0.5);
		   }
	      }	   
	}
   } 
   else if (nativeSetup == 14)
   {
      if (axisChance == 2)
	{
  	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageAID, 0, 0.79, 0.38);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.21, 0.38);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.79, 0.62);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.21, 0.62);
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageAID, 0, 0.67, 0.4);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.33, 0.4);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.67, 0.6);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.33, 0.6);
	      }
      }
	else if (axisChance == 1)
	{
	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageDID, 0, 0.4, 0.79);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.4, 0.21);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.6, 0.79);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.6, 0.21);
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageDID, 0, 0.38, 0.71);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.38, 0.29);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.62, 0.71);
		   rmPlaceGroupingAtLoc(villageDID, 0, 0.62, 0.29);
	      }
	}
   } 
   else if (nativeSetup > 14) // 15 AND 16
   {
	if (nativeSetup == 15)
	{
	   if (axisChance == 1)
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.38, 0.51);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.62, 0.49);

         }
   	   else
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.51, 0.62);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.49, 0.38);
	   }
	}
      if (axisChance == 2)
	{
  	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageAID, 0, 0.85, 0.135);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.15, 0.135);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.15, 0.865);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.85, 0.865);
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageAID, 0, 0.85, 0.135);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.15, 0.135);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.15, 0.865);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.85, 0.865);
	      }
      }
	else if (axisChance == 1)
	{
	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageDID, 0, 0.135, 0.85);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.135, 0.15);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.865, 0.15);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.865, 0.85);
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageAID, 0, 0.135, 0.85);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.135, 0.15);
               rmPlaceGroupingAtLoc(villageAID, 0, 0.865, 0.15);
		   rmPlaceGroupingAtLoc(villageAID, 0, 0.865, 0.85);
	      }
	}
   } 
   else 
   {
	if (nativeSetup == 10)
	{
   	   rmSetGroupingMaxDistance(villageDID, size*0.1);
	   if (axisChance == 1)
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.39, 0.5);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.61, 0.5);
         }
	   else
	   {
            rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.39);
            rmPlaceGroupingAtLoc(villageDID, 0, 0.5, 0.61);
	   }
	}
	if (nativeSetup == 11)
	{
	   if (axisChance == 1)
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.39, 0.5);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.61, 0.5);
         }
	   else
	   {
            rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.39);
            rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.61);
	   }
	}
	if (nativeSetup == 12)
	{
         if (axisChance == 2)
   	   {
  	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageDID, 0, 0.79, 0.38);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.21, 0.38);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.79, 0.62);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.21, 0.62);
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageDID, 0, 0.67, 0.4);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.33, 0.4);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.67, 0.6);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.33, 0.6);
	      }
         }
	   else if (axisChance == 1)
	   {
	      if (variantChance == 1)
	      {  
               rmPlaceGroupingAtLoc(villageDID, 0, 0.4, 0.79);
		   rmPlaceGroupingAtLoc(villageDID, 0, 0.4, 0.21);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.6, 0.79);
		   rmPlaceGroupingAtLoc(villageDID, 0, 0.6, 0.21);
	      }
	      else
	      {
               rmPlaceGroupingAtLoc(villageDID, 0, 0.38, 0.71);
		   rmPlaceGroupingAtLoc(villageDID, 0, 0.38, 0.29);
               rmPlaceGroupingAtLoc(villageDID, 0, 0.62, 0.71);
		   rmPlaceGroupingAtLoc(villageDID, 0, 0.62, 0.29);
	      }
	   }
	}
      for(i=1; <cNumberPlayers) // for all setups 7-12
      {
         rmSetGroupingMinDistance(villageAID, 55.0);
         rmSetGroupingMaxDistance(villageAID, 80.0);           
	   rmPlaceGroupingAtLoc(villageAID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	   if (nativeSetup == 7)
	   {
            rmSetGroupingMinDistance(villageDID, 55.0);
            rmSetGroupingMaxDistance(villageDID, 80.0);      
		rmPlaceGroupingAtLoc(villageDID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	   }
	   if (nativeSetup == 8)
		rmPlaceGroupingAtLoc(villageAID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
      }
   }

   // Text
   rmSetStatusText("",0.50);

// Player Nuggets
   int playerNuggetID=rmCreateObjectDef("player nugget");
   rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
   rmAddObjectDefToClass(playerNuggetID, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(playerNuggetID, 35.0);
   rmSetObjectDefMaxDistance(playerNuggetID, 45.0);
   rmAddObjectDefConstraint(playerNuggetID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(playerNuggetID, avoidTradeRoute);
   rmAddObjectDefConstraint(playerNuggetID, avoidSocket);
   rmAddObjectDefConstraint(playerNuggetID, avoidNugget);
   for(i=1; <cNumberPlayers)
   {
 	rmSetNuggetDifficulty(1, 1);
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }

   // Text
   rmSetStatusText("",0.55);

// Cliffs
   int cliffHt = -1;
   int failCount=0;
   int numTries=cNumberNonGaiaPlayers*7;
   int anotherChance = -1;
   anotherChance = rmRandInt(0,1);

   if (makeCliffs == 2)
   {
     if (anotherChance == 1)
        makeCliffs = 1;
     else
        makeCliffs = 0;
   } 

   if (makeCliffs == 1)
   { 
	if (cliffVariety == 8) // for Sonora and Painted Desert only
	{
	   // bigger mesas
	   for(i=0; <numTries)
	   {
		int mesaID=rmCreateArea("mesa"+i);
		rmSetAreaSize(mesaID, rmAreaTilesToFraction(25), rmAreaTilesToFraction(160)); 
		rmSetAreaWarnFailure(mesaID, false);
		rmSetAreaCliffType(mesaID, cliffType);
		rmAddAreaToClass(mesaID, rmClassID("canyon"));
		rmAddAreaToClass(mesaID, rmClassID("classCliff"));	
		rmSetAreaCliffEdge(mesaID, 1, 1.0, 0.1, 1.0, 0);
  	      rmSetAreaCliffHeight(mesaID, rmRandInt(6,9), 1.0, 1.0);
		rmAddAreaConstraint(mesaID, avoidCanyons);
		rmAddAreaConstraint(mesaID, avoidCliffs);
		rmSetAreaMinBlobs(mesaID, 3);
		rmSetAreaMaxBlobs(mesaID, 5);
		rmSetAreaMinBlobDistance(mesaID, 3.0);
		rmSetAreaMaxBlobDistance(mesaID, 5.0);
		rmSetAreaCoherence(mesaID, 0.5);
		rmAddAreaConstraint(mesaID, playerConstraint); 
		rmAddAreaConstraint(mesaID, avoidSocket);
		rmAddAreaConstraint(mesaID, avoidNativesShort);
		rmAddAreaConstraint(mesaID, avoidTradeRoute);
		rmAddAreaConstraint(mesaID, shortAvoidSilver);
		if(rmBuildArea(mesaID)==false)
		{
			// Stop trying once we fail 3 times in a row.
			failCount++;
			if(failCount==2)
				break;
		}
		else
			failCount=0;
	   }
	// smaller mesas
	   numTries=cNumberNonGaiaPlayers*12;

	   for(i=0; <numTries)
	   {
		int smallMesaID=rmCreateArea("small mesa"+i);
		rmSetAreaSize(smallMesaID, rmAreaTilesToFraction(4), rmAreaTilesToFraction(8));  
		rmSetAreaWarnFailure(smallMesaID, false);
		rmSetAreaCliffType(smallMesaID, cliffType);
		rmAddAreaToClass(smallMesaID, rmClassID("canyon"));
		rmAddAreaToClass(smallMesaID, rmClassID("classCliff"));	
		rmSetAreaCliffEdge(smallMesaID, 1, 1.0, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(smallMesaID, rmRandInt(5,8), 1.0, 1.0);
		rmAddAreaConstraint(smallMesaID, shortAvoidCanyons);
		rmAddAreaConstraint(smallMesaID, avoidCliffs);
		rmSetAreaMinBlobs(smallMesaID, 3);
		rmSetAreaMaxBlobs(smallMesaID, 5);
		rmSetAreaMinBlobDistance(smallMesaID, 3.0);
		rmSetAreaMaxBlobDistance(smallMesaID, 5.0);
		rmSetAreaCoherence(smallMesaID, 0.3);
		rmAddAreaConstraint(smallMesaID, mediumPlayerConstraint); 
		rmAddAreaConstraint(smallMesaID, avoidNativesShort); 
		rmAddAreaConstraint(smallMesaID, avoidSocket);
		rmAddAreaConstraint(smallMesaID, avoidTradeRoute);
		rmAddAreaConstraint(smallMesaID, shortAvoidSilver);
		if(rmBuildArea(smallMesaID)==false)
		{
			// Stop trying once we fail 3 times in a row.
			failCount++;
			if(failCount==20)
				break;
		}
		else
			failCount=0;
	   }
	}
	else if (cliffVariety == 0) // a little like AOM Anatolia
	{
	   int gorgeHt = rmRandInt(-7,-4);
	   numTries = 2;
	   if (cNumberNonGaiaPlayers > 5)
	      numTries = 3;

	   for(i=0; <numTries)
	   {
	   int gorgeID=rmCreateArea("gorge"+i);
         rmSetAreaWarnFailure(gorgeID, false); 
	   rmSetAreaSize(gorgeID, rmAreaTilesToFraction(1500), rmAreaTilesToFraction(1800));
	   rmSetAreaCliffType(gorgeID, cliffType);
	   rmAddAreaToClass(gorgeID, rmClassID("classCliff"));
	   rmSetAreaMinBlobs(gorgeID, 4);
	   rmSetAreaMaxBlobs(gorgeID, 6);
	   if (rmRandInt(1,3) == 1)
	      rmSetAreaCliffEdge(gorgeID, 6, 0.10, 0.2, 1.0, 0);
	   else
	   {
		if (rmRandInt(1,2) == 1) 
	         rmSetAreaCliffEdge(gorgeID, 5, 0.15, 0.15, 1.0, 0);
		else
	         rmSetAreaCliffEdge(gorgeID, 4, 0.17, 0.15, 1.0, 0);
	   }		
	   rmSetAreaCliffPainting(gorgeID, false, true, true, 1.5);  
	   rmSetAreaMinBlobDistance(gorgeID, 16.0);
	   rmSetAreaMaxBlobDistance(gorgeID, 20.0);
	   rmSetAreaCoherence(gorgeID, rmRandFloat(0.0,0.2));
	   rmSetAreaSmoothDistance(gorgeID, rmRandInt(10,20));
	   rmSetAreaCliffHeight(gorgeID, gorgeHt, 1.0, 1.0);
	   rmSetAreaHeightBlend(gorgeID, 2);
	   rmAddAreaConstraint(gorgeID, cliffsAvoidCliffs);
         rmAddAreaConstraint(gorgeID, avoidImportantItem);
	   rmAddAreaConstraint(gorgeID, avoidTradeRoute);
         rmAddAreaConstraint(gorgeID, avoidNatives);
	   rmAddAreaConstraint(gorgeID, avoidSocket);
	   rmAddAreaConstraint(gorgeID, avoidBarrier);
	   rmAddAreaConstraint(gorgeID, avoidStartingUnits);
	   rmAddAreaConstraint(gorgeID, fartherPlayerConstraint);
	   rmAddAreaConstraint(gorgeID, secondEdgeConstraint);
 	   rmBuildArea(gorgeID);
	   }
      }
      else // all other maps with cliffs
      {
         int numCliffs = cNumberNonGaiaPlayers + rmRandInt(2,6);

         for (i=0; <numCliffs)
         {
		cliffHt = rmRandInt(5,7);    
		int bigCliffID=rmCreateArea("big cliff" +i);
		rmSetAreaWarnFailure(bigCliffID, false);
		rmSetAreaCliffType(bigCliffID, cliffType);
		rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
		if (cliffVariety == 1) // like Patagonia
		{
   	         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(550), rmAreaTilesToFraction(750));
      	   rmSetAreaCliffEdge(bigCliffID, 2, 0.35, 0.1, 1.0, 0);
      	   rmSetAreaCliffPainting(bigCliffID, false, true, true, 1.5, true);
		   rmSetAreaCliffHeight(bigCliffID, 7, 2.0, 0.5);
		   rmSetAreaCoherence(bigCliffID, 0.5);
		   rmSetAreaSmoothDistance(bigCliffID, rmRandInt(5,10));
		   rmSetAreaHeightBlend(bigCliffID, 1.0);
		   rmSetAreaMinBlobs(bigCliffID, 4);
	  	   rmSetAreaMaxBlobs(bigCliffID, 6);
		   rmSetAreaMinBlobDistance(bigCliffID, 10.0);
		   rmSetAreaMaxBlobDistance(bigCliffID, 18.0);
		}
		else if (cliffVariety == 2) // smaller, kinda like in Sudden Death from AOM
		{
   	         rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(280), rmAreaTilesToFraction(400));
		   rmSetAreaCliffEdge(bigCliffID, 1, 0.6, 0.1, 1.0, 0);
		   rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
		   rmSetAreaCliffHeight(bigCliffID, cliffHt, 1.0, 1.0);
		   rmSetAreaCoherence(bigCliffID, rmRandFloat(0.4, 0.9));
		   rmSetAreaSmoothDistance(bigCliffID, 10);
		   rmSetAreaHeightBlend(bigCliffID, 2.0);
		   rmSetAreaMinBlobs(bigCliffID, 1);
	  	   rmSetAreaMaxBlobs(bigCliffID, 3);
		   rmSetAreaMinBlobDistance(bigCliffID, 5.0);
		   rmSetAreaMaxBlobDistance(bigCliffID, 10);
		}
		else
		{
		   if (plainsMap == 1)
		   {
			if (cliffVariety == 3)  // odd ridges for selected maps
			{
   	         	   rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(250), rmAreaTilesToFraction(450));
		   	   rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
		   	   if (rmRandInt(1,2) == 1)
 	            	rmSetAreaCliffEdge(bigCliffID, 2, 0.36, 0.1, 1.0, 0);
		   	   else
 	            	rmSetAreaCliffEdge(bigCliffID, 3, 0.26, 0.08, 1.0, 0);
		   	   rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
		   	   rmSetAreaCliffHeight(bigCliffID, cliffHt, 2.0, 1.0);
		  	   rmSetAreaCoherence(bigCliffID, rmRandFloat(0.3, 0.5));
		   	   rmSetAreaSmoothDistance(bigCliffID, 5);
		   	   rmSetAreaHeightBlend(bigCliffID, 1.0);
	  	   	   rmSetAreaMinBlobs(bigCliffID, 2);
		   	   rmSetAreaMaxBlobs(bigCliffID, 2);
		   	   rmSetAreaMinBlobDistance(bigCliffID, 100.0);
		   	   rmSetAreaMaxBlobDistance(bigCliffID, 130.0);
			}
			else if (cliffVariety == 4)  // smooth rock domes for plains maps
			{
   	         	   rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(200), rmAreaTilesToFraction(400));
		   	   rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
		   	   rmSetAreaCliffEdge(bigCliffID, 1, 0.005, 0.01, 1.0, 0);
		         rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
		   	   rmSetAreaCliffHeight(bigCliffID, rmRandInt(7,8), 2.0, 1.0);
		   	   rmSetAreaCoherence(bigCliffID, rmRandFloat(0.3, 0.5));
		   	   rmSetAreaSmoothDistance(bigCliffID, 20);
		   	   rmSetAreaHeightBlend(bigCliffID, 1.0);
	     		}
		      else  // kinda random, kinda like Texas or NE
		      {
   	               rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(700));
		         rmSetAreaCliffEdge(bigCliffID, 1, 0.6, 0.1, 1.0, 0);
		         rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
		         rmSetAreaCliffHeight(bigCliffID, cliffHt, 2.0, 1.0);
  		         rmSetAreaCoherence(bigCliffID, rmRandFloat(0.4, 0.9));
		         rmSetAreaSmoothDistance(bigCliffID, 15);
		         rmSetAreaHeightBlend(bigCliffID, 1.0);
		         rmSetAreaMinBlobs(bigCliffID, 3);
		         rmSetAreaMaxBlobs(bigCliffID, 5);
		         rmSetAreaMinBlobDistance(bigCliffID, 10.0);
		         rmSetAreaMaxBlobDistance(bigCliffID, 18.0);
		      }
		   }
		   else if ((patternChance == 11) || (patternChance == 12) || (patternChance == 18) || (patternChance == 19)) 
		   { 
			if (cliffVariety < 5)  // odd ridges for selected maps
			{
   	         	   rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(250), rmAreaTilesToFraction(450));
		   	   rmAddAreaToClass(bigCliffID, rmClassID("classCliff"));
		   	   if (rmRandInt(1,2) == 1)
 	            	rmSetAreaCliffEdge(bigCliffID, 2, 0.36, 0.1, 1.0, 0);
		   	   else
 	            	rmSetAreaCliffEdge(bigCliffID, 3, 0.26, 0.08, 1.0, 0);
		   	   rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
		   	   rmSetAreaCliffHeight(bigCliffID, cliffHt, 2.0, 1.0);
		  	   rmSetAreaCoherence(bigCliffID, rmRandFloat(0.3, 0.5));
		   	   rmSetAreaSmoothDistance(bigCliffID, 5);
		   	   rmSetAreaHeightBlend(bigCliffID, 1.0);
	  	   	   rmSetAreaMinBlobs(bigCliffID, 2);
		   	   rmSetAreaMaxBlobs(bigCliffID, 2);
		   	   rmSetAreaMinBlobDistance(bigCliffID, 100.0);
		   	   rmSetAreaMaxBlobDistance(bigCliffID, 130.0);
			}
		      else  // kinda random, kinda like Texas or NE
		      {
   	               rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(700));
		         rmSetAreaCliffEdge(bigCliffID, 1, 0.6, 0.1, 1.0, 0);
		         rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
		         rmSetAreaCliffHeight(bigCliffID, cliffHt, 2.0, 1.0);
  		         rmSetAreaCoherence(bigCliffID, rmRandFloat(0.4, 0.9));
		         rmSetAreaSmoothDistance(bigCliffID, 15);
		         rmSetAreaHeightBlend(bigCliffID, 1.0);
		         rmSetAreaMinBlobs(bigCliffID, 3);
		         rmSetAreaMaxBlobs(bigCliffID, 5);
		         rmSetAreaMinBlobDistance(bigCliffID, 10.0);
		         rmSetAreaMaxBlobDistance(bigCliffID, 18.0);
		      }
		   }
		   else  // kinda random, kinda like Texas or NE
		   {
   	            rmSetAreaSize(bigCliffID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(700));
		      rmSetAreaCliffEdge(bigCliffID, 1, 0.6, 0.1, 1.0, 0);
		      rmSetAreaCliffPainting(bigCliffID, true, true, true, 1.5, true);
		      rmSetAreaCliffHeight(bigCliffID, cliffHt, 2.0, 1.0);
		      rmSetAreaCoherence(bigCliffID, rmRandFloat(0.4, 0.9));
		      rmSetAreaSmoothDistance(bigCliffID, 15);
		      rmSetAreaHeightBlend(bigCliffID, 1.0);
		      rmSetAreaMinBlobs(bigCliffID, 3);
		      rmSetAreaMaxBlobs(bigCliffID, 5);
		      rmSetAreaMinBlobDistance(bigCliffID, 10.0);
		      rmSetAreaMaxBlobDistance(bigCliffID, 18.0);
		   }
	      }
		rmAddAreaConstraint(bigCliffID, avoidImportantItem);
		rmAddAreaConstraint(bigCliffID, avoidTradeRoute);
            rmAddAreaConstraint(bigCliffID, avoidNatives);
	      rmAddAreaConstraint(bigCliffID, cliffsAvoidCliffs);
	      rmAddAreaConstraint(bigCliffID, avoidSocket);
	      rmAddAreaConstraint(bigCliffID, avoidStartingUnits);
	      rmAddAreaConstraint(bigCliffID, longPlayerConstraint);
		rmBuildArea(bigCliffID);
         }
      }
   }

   // Text
   rmSetStatusText("",0.60);

// Random Nuggets
   int nugget2= rmCreateObjectDef("nugget medium"); 
   rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(2, 2);
   rmAddObjectDefToClass(nugget2, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(nugget2, 60.0);
   rmSetObjectDefMaxDistance(nugget2, size*0.3);
   rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget2, avoidSocket);
   rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
   rmAddObjectDefConstraint(nugget2, nuggetPlayerConstraint);
   rmAddObjectDefConstraint(nugget2, avoidNuggetMed);
   rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
   rmAddObjectDefConstraint(nugget2, avoidBarrier);
   rmAddObjectDefConstraint(nugget2, avoidAll);
   rmPlaceObjectDefPerPlayer(nugget2, false, 1);

   int nugget3= rmCreateObjectDef("nugget hard"); 
   rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(3, 3);
   rmAddObjectDefToClass(nugget3, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(nugget3, 80.0);
   rmSetObjectDefMaxDistance(nugget3, size*0.35);
   rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget3, avoidSocket);
   rmAddObjectDefConstraint(nugget3, avoidTradeRoute);
   rmAddObjectDefConstraint(nugget3, farPlayerConstraint);
   rmAddObjectDefConstraint(nugget3, avoidNuggetLong);
   rmAddObjectDefConstraint(nugget3, playerEdgeConstraint);
   rmAddObjectDefConstraint(nugget3, avoidBarrier);
   rmAddObjectDefConstraint(nugget3, avoidAll);
   rmPlaceObjectDefPerPlayer(nugget3, false, 1);

   rmAddObjectDefConstraint(nugget3, fartherPlayerConstraint);
   rmSetNuggetDifficulty(2, 3);
   rmPlaceObjectDefPerPlayer(nugget3, false, 1);

   int nugget4= rmCreateObjectDef("nugget nuts"); 
   rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(4, 4);
   rmAddObjectDefToClass(nugget4, rmClassID("classNugget"));
   rmSetObjectDefMinDistance(nugget4, 85.0);
   rmSetObjectDefMaxDistance(nugget4, size*0.38);
   rmAddObjectDefConstraint(nugget4, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget4, avoidSocket);
   rmAddObjectDefConstraint(nugget4, avoidTradeRoute);
   rmAddObjectDefConstraint(nugget4, fartherPlayerConstraint);
   rmAddObjectDefConstraint(nugget4, avoidNuggetLong);
   rmAddObjectDefConstraint(nugget4, playerEdgeConstraint);
   rmAddObjectDefConstraint(nugget4, avoidBarrier);
   rmAddObjectDefConstraint(nugget4, avoidAll);
   rmPlaceObjectDefPerPlayer(nugget4, false, 1);

// more resources
   // start area trees 
   int StartAreaTreeID=rmCreateObjectDef("starting trees");
   rmAddObjectDefItem(StartAreaTreeID, treeType, 1, 0.0);
   rmSetObjectDefMinDistance(StartAreaTreeID, 8);
   rmSetObjectDefMaxDistance(StartAreaTreeID, 12);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRoute);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
   rmPlaceObjectDefPerPlayer(StartAreaTreeID, false, 3);

   // berry bushes
   int berryNum = rmRandInt(2,5);
   int StartBerryBushID=rmCreateObjectDef("starting berry bush");
   rmAddObjectDefItem(StartBerryBushID, "BerryBush", rmRandInt(3,4), 4.0);
   rmSetObjectDefMinDistance(StartBerryBushID, 10.0);
   rmSetObjectDefMaxDistance(StartBerryBushID, 16.0);
   rmAddObjectDefConstraint(StartBerryBushID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(StartBerryBushID, avoidBarrier);
   if (placeBerries == 1)
      rmPlaceObjectDefPerPlayer(StartBerryBushID, false, 1);
   if (tropicalMap == 1)
      rmPlaceObjectDefPerPlayer(StartBerryBushID, false, 1);
   rmSetObjectDefMinDistance(StartBerryBushID, 70.0);
   rmSetObjectDefMaxDistance(StartBerryBushID, 85.0);
   if (tropicalMap == 1)
      rmPlaceObjectDefPerPlayer(StartBerryBushID, false, 1);
   rmSetObjectDefMaxDistance(StartBerryBushID, size*0.38);
   if (tropicalMap == 1)
      rmPlaceObjectDefPerPlayer(StartBerryBushID, false, 1);

   // Text
   rmSetStatusText("",0.65);

   // start area huntable
   int deerNum = rmRandInt(5, 8);
   int startPronghornID=rmCreateObjectDef("starting pronghorn");
   rmAddObjectDefItem(startPronghornID, deerType, deerNum, 5.0);
   rmAddObjectDefToClass(startPronghornID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(startPronghornID, 16);
   rmSetObjectDefMaxDistance(startPronghornID, 22);
   rmAddObjectDefConstraint(startPronghornID, avoidStartResource);
   rmAddObjectDefConstraint(startPronghornID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(startPronghornID, avoidBarrier);
   rmAddObjectDefConstraint(startPronghornID, avoidAll);
   rmSetObjectDefCreateHerd(startPronghornID, true);
   rmPlaceObjectDefPerPlayer(startPronghornID, false, 1);

   // second huntable
   int deer2Num = rmRandInt(4, 8);
   int farPronghornID=rmCreateObjectDef("far pronghorn");
   rmAddObjectDefItem(farPronghornID, deer2Type, deer2Num, 5.0);
   rmAddObjectDefToClass(farPronghornID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(farPronghornID, 42.0);
   rmSetObjectDefMaxDistance(farPronghornID, 60.0);
   rmAddObjectDefConstraint(farPronghornID, avoidStartResource);
   rmAddObjectDefConstraint(farPronghornID, mediumPlayerConstraint);
   rmAddObjectDefConstraint(farPronghornID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(farPronghornID, avoidNativesShort);
   rmAddObjectDefConstraint(farPronghornID, huntableConstraint);
   rmAddObjectDefConstraint(farPronghornID, avoidBarrier);
   rmAddObjectDefConstraint(farPronghornID, avoidAll);
   rmSetObjectDefCreateHerd(farPronghornID, true);
   if (sheepChance == 0)
      rmPlaceObjectDefPerPlayer(farPronghornID, false, 2);
   else
      rmPlaceObjectDefPerPlayer(farPronghornID, false, 1);

// Silver mines - players
   int silverType = -1;
   silverType = rmRandInt(1,10);
   int playerGoldID=rmCreateObjectDef("player silver closer");
   rmAddObjectDefItem(playerGoldID, mineType, 1, 0.0);
   rmAddObjectDefConstraint(playerGoldID, avoidTradeRoute);
   rmAddObjectDefConstraint(playerGoldID, avoidSocket);
   rmAddObjectDefConstraint(playerGoldID, coinAvoidCoin);
   rmAddObjectDefConstraint(playerGoldID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(playerGoldID, avoidAll);
   rmAddObjectDefConstraint(playerGoldID, avoidBarrier);
   rmSetObjectDefMinDistance(playerGoldID, 18.0);
   rmSetObjectDefMaxDistance(playerGoldID, 23.0);
   rmPlaceObjectDefPerPlayer(playerGoldID, false, 1);

   rmAddObjectDefConstraint(playerGoldID, playerConstraint);
   rmSetObjectDefMinDistance(playerGoldID, 50.0);
   rmSetObjectDefMaxDistance(playerGoldID, 60.0);
   rmPlaceObjectDefPerPlayer(playerGoldID, false, 1);

   silverType = rmRandInt(1,10);
   int GoldMediumID=rmCreateObjectDef("player silver med");
   rmAddObjectDefItem(GoldMediumID, mineType, 1, 0.0);
   rmAddObjectDefConstraint(GoldMediumID, avoidTradeRoute);
   rmAddObjectDefConstraint(GoldMediumID, avoidSocket);
   rmAddObjectDefConstraint(GoldMediumID, coinAvoidCoin);
   rmAddObjectDefConstraint(GoldMediumID, shortAvoidCanyons);
   rmAddObjectDefConstraint(GoldMediumID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldMediumID, farPlayerConstraint);
   rmAddObjectDefConstraint(GoldMediumID, avoidBarrier);
   rmAddObjectDefConstraint(GoldMediumID, avoidAll);
   rmSetObjectDefMinDistance(GoldMediumID, 85.0);
   rmSetObjectDefMaxDistance(GoldMediumID, 100.0);
   rmPlaceObjectDefPerPlayer(GoldMediumID, false, 1);

   // Text
   rmSetStatusText("",0.70);

// Extra tree clumps near players - to ensure fair access to wood
   int extraTreesID=rmCreateObjectDef("extra trees");
   rmAddObjectDefItem(extraTreesID, treeType, 4, 5.0);
   rmSetObjectDefMinDistance(extraTreesID, 14);
   rmSetObjectDefMaxDistance(extraTreesID, 18);
   rmAddObjectDefConstraint(extraTreesID, avoidAll);
   rmAddObjectDefConstraint(extraTreesID, avoidCoin);
   rmAddObjectDefConstraint(extraTreesID, avoidSocket);
   rmAddObjectDefConstraint(extraTreesID, avoidTradeRoute);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(extraTreesID, 0, rmAreaID("player"+i), 1);

   int extraTrees2ID=rmCreateObjectDef("more extra trees");
   rmAddObjectDefItem(extraTrees2ID, treeType, 5, 6.0);
   rmSetObjectDefMinDistance(extraTrees2ID, 18);
   rmSetObjectDefMaxDistance(extraTrees2ID, 28);
   rmAddObjectDefConstraint(extraTrees2ID, avoidAll);
   rmAddObjectDefConstraint(extraTrees2ID, avoidCoin);
   rmAddObjectDefConstraint(extraTrees2ID, avoidSocket);
   rmAddObjectDefConstraint(extraTrees2ID, avoidTradeRoute);
   for(i=1; <cNumberPlayers)
      rmPlaceObjectDefInArea(extraTrees2ID, 0, rmAreaID("player"+i), 2);

// Forest on the barrier ridge 
if (makeBarrierRangeForest == 1)
{
   if (gapPattern == 1)
      numTries=3*cNumberNonGaiaPlayers;
   else if (gapPattern == 2)
      numTries=2*cNumberNonGaiaPlayers;
   else if (gapPattern == 3)
      numTries=3.5*cNumberNonGaiaPlayers;

   for (i=0; <numTries)
   { 
      int forestPatchID = rmCreateArea("forest patch"+i, rmAreaID("barrier 1"));
      rmAddAreaToClass(forestPatchID, rmClassID("classForest"));
      rmSetAreaWarnFailure(forestPatchID, false);
      rmSetAreaSize(forestPatchID, rmAreaTilesToFraction(80), rmAreaTilesToFraction(150));
      rmSetAreaCoherence(forestPatchID, 0.6);
      if (patternChance == 8)
	   rmSetAreaForestType(forestPatchID, "rockies snow forest");
      else if (patternChance == 6)
	   rmSetAreaForestType(forestPatchID, "yukon snow forest");
      else if (patternChance == 19)
	   rmSetAreaForestType(forestPatchID, "patagonia snow forest");
	else 
         rmSetAreaForestType(forestPatchID, forestType);
      rmSetAreaForestDensity(forestPatchID, 0.6);
      rmSetAreaForestClumpiness(forestPatchID, 0.9);
      rmSetAreaForestUnderbrush(forestPatchID, 0.2);
      rmSetAreaCoherence(forestPatchID, 0.4);
      rmSetAreaSmoothDistance(forestPatchID, 10);
      rmAddAreaConstraint(forestPatchID, avoidAll);
      rmAddAreaConstraint(forestPatchID, avoidTradeRoute);
	rmAddAreaConstraint(forestPatchID, avoidSocket);
      rmBuildArea(forestPatchID);
   } 

   if (gapPattern == 3)
      numTries=2*cNumberNonGaiaPlayers;
   else if (gapPattern == 2)
      numTries=3.5*cNumberNonGaiaPlayers;

   for (i=0; <numTries)
   { 
      int forestPatch2ID = rmCreateArea("forest patch2"+i, rmAreaID("barrier 2"));
      rmAddAreaToClass(forestPatch2ID, rmClassID("classForest"));
      rmSetAreaWarnFailure(forestPatch2ID, false);
      rmSetAreaSize(forestPatch2ID, rmAreaTilesToFraction(80), rmAreaTilesToFraction(150));
      rmSetAreaCoherence(forestPatch2ID, 0.6);
      if (patternChance == 8)
	   rmSetAreaForestType(forestPatch2ID, "rockies snow forest");
      else if (patternChance == 6)
	   rmSetAreaForestType(forestPatch2ID, "yukon snow forest");
      else if (patternChance == 22)
	   rmSetAreaForestType(forestPatch2ID, "patagonia snow forest");
	else 
         rmSetAreaForestType(forestPatch2ID, forestType);
      rmSetAreaForestDensity(forestPatch2ID, 0.6);
      rmSetAreaForestClumpiness(forestPatch2ID, 0.9);
      rmSetAreaForestUnderbrush(forestPatch2ID, 0.2);
      rmSetAreaCoherence(forestPatch2ID, 0.4);
      rmSetAreaSmoothDistance(forestPatch2ID, 10);
      rmAddAreaConstraint(forestPatch2ID, avoidAll);
      rmAddAreaConstraint(forestPatch2ID, avoidTradeRoute);
	rmAddAreaConstraint(forestPatch2ID, avoidSocket);
      rmBuildArea(forestPatch2ID);
   }       
}

   // Text
   rmSetStatusText("",0.75);

// Main forests
   int forestChance = -1;
   int coverForestPatchID = 0;

      numTries=11*cNumberNonGaiaPlayers;
      if (cNumberNonGaiaPlayers == 3)
         numTries=10*cNumberNonGaiaPlayers; 
      if (cNumberNonGaiaPlayers > 3)
         numTries=9*cNumberNonGaiaPlayers;  
      if (cNumberNonGaiaPlayers > 5)
         numTries=8*cNumberNonGaiaPlayers;  
      if (cNumberNonGaiaPlayers > 7)
         numTries=7*cNumberNonGaiaPlayers;   

   failCount=0;
   for (i=0; <numTries)
   {
      forestChance = rmRandInt(1,4);
      int forest=rmCreateArea("forest "+i);
      rmSetAreaWarnFailure(forest, false);
      rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(280));
      rmSetAreaForestType(forest, forestType);
      rmSetAreaForestDensity(forest, rmRandFloat(0.7, 1.0));
      rmSetAreaForestClumpiness(forest, rmRandFloat(0.5, 0.9));
      rmSetAreaForestUnderbrush(forest, rmRandFloat(0.0, 0.5));
      rmSetAreaCoherence(forest, rmRandFloat(0.4, 0.7));
      rmSetAreaSmoothDistance(forest, rmRandInt(10,20));
      if (forestChance == 3)
      {
		rmSetAreaMinBlobs(forest, 1);
		rmSetAreaMaxBlobs(forest, 3);					
		rmSetAreaMinBlobDistance(forest, 12.0);
		rmSetAreaMaxBlobDistance(forest, 24.0);
	}
      if (forestChance == 4)
      {
		rmSetAreaMinBlobs(forest, 3);
		rmSetAreaMaxBlobs(forest, 5);					
		rmSetAreaMinBlobDistance(forest, 16.0);
		rmSetAreaMaxBlobDistance(forest, 28.0);
		rmSetAreaSmoothDistance(forest, 120);
	}
      rmAddAreaToClass(forest, rmClassID("classForest")); 
	rmAddAreaConstraint(forest, mediumPlayerConstraint);
      rmAddAreaConstraint(forest, forestConstraint);
      rmAddAreaConstraint(forest, avoidAll); 
	rmAddAreaConstraint(forest, avoidCoin);  
	rmAddAreaConstraint(forest, avoidBarrier);
	rmAddAreaConstraint(forest, avoidBase);
      rmAddAreaConstraint(forest, avoidImpassableLand); 
      rmAddAreaConstraint(forest, avoidTradeRoute);
	rmAddAreaConstraint(forest, avoidStartingUnits);
	rmAddAreaConstraint(forest, avoidSocket);
	rmAddAreaConstraint(forest, avoidNativesShort);
	if (noCliffForest == 1)
	   rmAddAreaConstraint(forest, avoidCliffsShort);
	if (hillTrees == 1)
	{
	   if (rmRandInt(1,3) > 1)
            rmSetAreaBaseHeight(forest, rmRandFloat(3.5, 5.0));
	}
      if(rmBuildArea(forest)==false)
      {
         // Stop trying once we fail 3 times in a row.
         failCount++;
         if(failCount==5)
            break;
      }
      else
         failCount=0; 
   }

// Patch to cover forest floor or cliffs in some patterns
if (coverUp == 1)
{
   int coverPatchID = rmCreateArea("cover patch"+i);
   rmSetAreaLocation(coverPatchID, 0.5, 0.5); 
   rmSetAreaWarnFailure(coverPatchID, false);
   rmSetAreaSize(coverPatchID, 0.99, 0.99);
   rmSetAreaCoherence(coverPatchID, 0.99);
   rmSetAreaMix(coverPatchID, baseType);
   rmBuildArea(coverPatchID);

   int coverPatch2ID = rmCreateArea("cover patch 2"+1);
   rmSetAreaLocation(coverPatch2ID, 0.5, 0.5); 
   rmSetAreaWarnFailure(coverPatch2ID, false);
   rmSetAreaSize(coverPatch2ID, 0.99, 0.99);
   rmSetAreaCoherence(coverPatch2ID, 0.99);
   rmSetAreaMix(coverPatch2ID, baseType);
   rmBuildArea(coverPatch2ID);
}
 

// Deco
   // Patches for Araucania, California, Andes, Patagonia
   if (specialPatch == 1)
   {
      for (i=0; <cNumberNonGaiaPlayers*8)   
      {
	   int colorPatch=rmCreateArea("color patch "+i);
	   rmSetAreaWarnFailure(colorPatch, false);
	   rmSetAreaSize(colorPatch, rmAreaTilesToFraction(250), rmAreaTilesToFraction(400));
         rmSetAreaMix(colorPatch, patchMixType);
	   rmAddAreaToClass(colorPatch, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(colorPatch, 1);
	   rmSetAreaMaxBlobs(colorPatch, 5);
	   rmSetAreaMinBlobDistance(colorPatch, 16.0);
	   rmSetAreaMaxBlobDistance(colorPatch, 36.0);
	   rmSetAreaCoherence(colorPatch, 0.1);
	   rmSetAreaSmoothDistance(colorPatch, 10);
	   rmAddAreaConstraint(colorPatch, shortAvoidImpassableLand);
	   rmAddAreaConstraint(colorPatch, patchConstraint);
	   rmAddAreaConstraint(colorPatch, shortForestConstraint);
	   if (patternChance == 22)
		rmAddAreaConstraint(colorPatch, avoidBarrier);
	   rmBuildArea(colorPatch); 
      }

      for (i=0; <cNumberNonGaiaPlayers*12)   
      {
	   int colorPatch2=rmCreateArea("2nd color patch "+i);
	   rmSetAreaWarnFailure(colorPatch2, false);
	   rmSetAreaSize(colorPatch2, rmAreaTilesToFraction(60), rmAreaTilesToFraction(150));
         rmSetAreaMix(colorPatch2, patchMixType);
	   rmAddAreaToClass(colorPatch2, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(colorPatch2, 1);
	   rmSetAreaMaxBlobs(colorPatch2, 3);
	   rmSetAreaMinBlobDistance(colorPatch2, 10.0);
	   rmSetAreaMaxBlobDistance(colorPatch2, 20.0);
	   rmSetAreaCoherence(colorPatch2, 0.1);
	   rmSetAreaSmoothDistance(colorPatch2, 10);
	   rmAddAreaConstraint(colorPatch2, shortAvoidImpassableLand);
	   rmAddAreaConstraint(colorPatch2, patchConstraint);
	   rmAddAreaConstraint(colorPatch2, shortForestConstraint);
	   if (patternChance == 22)
		rmAddAreaConstraint(colorPatch2, avoidBarrier);
	   rmBuildArea(colorPatch2); 
      }
   }

   // Text
   rmSetStatusText("",0.80);

// Extra silver mines - more central.
   silverType = rmRandInt(1,10);
   int extraGoldID = rmCreateObjectDef("extra silver "+i);
   if (placeGold == 5)
      rmAddObjectDefItem(extraGoldID, "minegold", 1, 0);
   else
      rmAddObjectDefItem(extraGoldID, mineType, 1, 0.0);
   rmAddObjectDefToClass(extraGoldID, rmClassID("importantItem"));
   rmAddObjectDefConstraint(extraGoldID, avoidTradeRoute);
   rmAddObjectDefConstraint(extraGoldID, avoidSocket);
   rmAddObjectDefConstraint(extraGoldID, coinAvoidCoin);
   rmAddObjectDefConstraint(extraGoldID, shortAvoidCanyons);
   rmAddObjectDefConstraint(extraGoldID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(extraGoldID, avoidBarrier);
   rmAddObjectDefConstraint(extraGoldID, avoidAll);
   rmSetObjectDefMinDistance(extraGoldID, 0.0);
   rmSetObjectDefMaxDistance(extraGoldID, 90.0);
   rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.5, 0.5, rmRandInt(1,2));
   if (axisChance == 1)
   {
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.44, 0.78, 1);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.56, 0.22, 1);
      if (cNumberNonGaiaPlayers > 4)
	{
         rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.44, 0.22, 1);
         rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.56, 0.78, 1);
	}
   }
   else
   {
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.8, 0.55, 1);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.2, 0.45, 1);
      if (cNumberNonGaiaPlayers > 4)
	{
         rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.2, 0.55, 1);
         rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.8, 0.45, 1);
	}
   }

   silverType = rmRandInt(1,10);
   int GoldFarID=rmCreateObjectDef("player silver far");
   if (placeGold == 1)
      rmAddObjectDefItem(GoldFarID, "minegold", 1, 0);
   else
      rmAddObjectDefItem(GoldFarID, mineType, 1, 0.0);
   rmAddObjectDefConstraint(GoldFarID, avoidTradeRoute);
   rmAddObjectDefConstraint(GoldFarID, avoidSocket);
   rmAddObjectDefConstraint(GoldFarID, coinAvoidCoin);
   rmAddObjectDefConstraint(GoldFarID, shortAvoidCanyons);
   rmAddObjectDefConstraint(GoldFarID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(GoldFarID, avoidBarrier);
   rmAddObjectDefConstraint(GoldFarID, avoidAll);
   rmAddObjectDefConstraint(GoldFarID, fartherPlayerConstraint);
   rmAddObjectDefConstraint(GoldFarID, centerConstraintFar);
   rmSetObjectDefMinDistance(GoldFarID, 100.0);
   rmSetObjectDefMaxDistance(GoldFarID, 120.0);
   rmPlaceObjectDefPerPlayer(GoldFarID, false, 1);

// sheep etc
   if (sheepChance > 0)
   {
      int sheepID=rmCreateObjectDef("herdable animal");
      rmAddObjectDefItem(sheepID, sheepType, 2, 4.0);
      rmAddObjectDefToClass(sheepID, rmClassID("herdableFood"));
      rmSetObjectDefMinDistance(sheepID, 40.0);
      rmSetObjectDefMaxDistance(sheepID, 0.2*longSide);
      rmAddObjectDefConstraint(sheepID, avoidSheep);
      rmAddObjectDefConstraint(sheepID, avoidAll);
      rmAddObjectDefConstraint(sheepID, playerConstraint);
      rmAddObjectDefConstraint(sheepID, avoidCliffs);
      rmAddObjectDefConstraint(sheepID, avoidBarrier);
      rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
      rmPlaceObjectDefPerPlayer(sheepID, false, 2);
      rmAddObjectDefConstraint(sheepID, farPlayerConstraint);
      rmSetObjectDefMaxDistance(sheepID, 0.35*longSide);
      if (rmRandInt(1,2) == 1)
         rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);
      else 
         rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3); 
   }

   // Text
   rmSetStatusText("",0.85);

// Central herds
   int centralHerdID=rmCreateObjectDef("central herd");  
   rmAddObjectDefItem(centralHerdID, centerHerdType, rmRandInt(7,9), 6.0);
   rmAddObjectDefToClass(centralHerdID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(centralHerdID, 0.15*size);
   rmSetObjectDefMaxDistance(centralHerdID, 0.22*size);
   rmAddObjectDefConstraint(centralHerdID, avoidTradeRoute);
   rmAddObjectDefConstraint(centralHerdID, avoidImportantItem);
   rmAddObjectDefConstraint(centralHerdID, farPlayerConstraint);
   rmAddObjectDefConstraint(centralHerdID, longHuntableConstraint);
   rmAddObjectDefConstraint(centralHerdID, avoidBarrier);
   rmSetObjectDefCreateHerd(centralHerdID, true);
   rmPlaceObjectDefAtLoc(centralHerdID, 0, 0.5, 0.5, 2);

   // additional of central herd type per player
   rmAddObjectDefConstraint(centralHerdID, fartherPlayerConstraint);
   rmSetObjectDefMinDistance(centralHerdID, 0.25*size);
   rmSetObjectDefMaxDistance(centralHerdID, 0.35*size);
   rmPlaceObjectDefPerPlayer(centralHerdID, false, 1);

// Far huntable
   int farHuntableID=rmCreateObjectDef("far huntable");
   rmAddObjectDefItem(farHuntableID, deerType, rmRandInt(5,9), 6.0);
   rmAddObjectDefToClass(farHuntableID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(farHuntableID, 0.22*size);
   rmSetObjectDefMaxDistance(farHuntableID, 0.35*size);
   rmAddObjectDefConstraint(farHuntableID, avoidTradeRoute);
   rmAddObjectDefConstraint(farHuntableID, avoidImportantItem);
   rmAddObjectDefConstraint(farHuntableID, fartherPlayerConstraint);
   rmAddObjectDefConstraint(farHuntableID, longHuntableConstraint);
   rmAddObjectDefConstraint(farHuntableID, avoidAll);
   rmAddObjectDefConstraint(farHuntableID, avoidBarrier);
   rmSetObjectDefCreateHerd(farHuntableID, true);
   rmPlaceObjectDefPerPlayer(farHuntableID, false, 1);

// Lone elk
   int loneElkID=rmCreateObjectDef("lone elk");
   threeChoice = rmRandInt(1,3);
   if (threeChoice == 1)
      rmAddObjectDefItem(loneElkID, centerHerdType, rmRandInt(1,2), 3.0);
   else if (threeChoice == 2)
      rmAddObjectDefItem(loneElkID, deer2Type, rmRandInt(1,2), 3.0);
   else
      rmAddObjectDefItem(loneElkID, deerType, rmRandInt(1,2), 3.0);
   rmAddObjectDefToClass(loneElkID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(loneElkID, 75.0);
   rmSetObjectDefMaxDistance(loneElkID, 0.4*size);
   rmAddObjectDefConstraint(loneElkID, longPlayerConstraint);
   rmAddObjectDefConstraint(loneElkID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(loneElkID, avoidNativesShort);
   rmAddObjectDefConstraint(loneElkID, huntableConstraint);
   rmAddObjectDefConstraint(loneElkID, avoidBarrier);
   rmAddObjectDefConstraint(loneElkID, avoidAll);
   rmSetObjectDefCreateHerd(loneElkID, true);
   rmPlaceObjectDefPerPlayer(loneElkID, false, 2);

   // Text
   rmSetStatusText("",0.90);

// Random trees
   int numTrees = cNumberNonGaiaPlayers*9;
   if (cNumberNonGaiaPlayers == 2)
	numTrees = cNumberNonGaiaPlayers*15;
   if (cNumberNonGaiaPlayers == 3)
	numTrees = cNumberNonGaiaPlayers*13;
   if (cNumberNonGaiaPlayers == 4)
	numTrees = cNumberNonGaiaPlayers*11;
   int StragglerTreeID=rmCreateObjectDef("stragglers");
   rmAddObjectDefItem(StragglerTreeID, treeType, 1, 0.0);
   rmAddObjectDefConstraint(StragglerTreeID, avoidAll);
   rmAddObjectDefConstraint(StragglerTreeID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(StragglerTreeID, avoidCoin);
   rmAddObjectDefConstraint(StragglerTreeID, patchConstraint);
   rmAddObjectDefConstraint(StragglerTreeID, avoidBarrier);
   rmSetObjectDefMinDistance(StragglerTreeID, 10.0);
   rmSetObjectDefMaxDistance(StragglerTreeID, rmXFractionToMeters(0.5));
   for(i=0; <numTrees)
      rmPlaceObjectDefAtLoc(StragglerTreeID, 0, 0.5, 0.5);
   if (tropicalMap == 1) 
   {
      for(i=0; <cNumberNonGaiaPlayers*5)
         rmPlaceObjectDefAtLoc(StragglerTreeID, 0, 0.5, 0.5);
   }

   // Text
   rmSetStatusText("",0.95);

// Deco
   // Dirt patches for Carolina
   if (patternChance == 2)
   {
	if (variantChance == 2)
	{
	   for (i=0; <cNumberNonGaiaPlayers*16)   
         {
		int dirtPatchC=rmCreateArea("carolina dirt patch "+i);
		rmSetAreaWarnFailure(dirtPatchC, false);
		rmSetAreaSize(dirtPatchC, rmAreaTilesToFraction(160), rmAreaTilesToFraction(260));
		rmSetAreaTerrainType(dirtPatchC, "carolina\ground_grass4_car");
		rmAddAreaToClass(dirtPatchC, rmClassID("classPatch"));
		rmSetAreaMinBlobs(dirtPatchC, 3);
		rmSetAreaMaxBlobs(dirtPatchC, 5);
		rmSetAreaMinBlobDistance(dirtPatchC, 16.0);
		rmSetAreaMaxBlobDistance(dirtPatchC, 36.0);
		rmSetAreaCoherence(dirtPatchC, 0.0);
		rmSetAreaSmoothDistance(dirtPatchC, 10);
		rmAddAreaConstraint(dirtPatchC, shortAvoidImpassableLand);
		rmAddAreaConstraint(dirtPatchC, patchConstraint);
	      rmAddAreaConstraint(dirtPatchC, shortForestConstraint);
		rmBuildArea(dirtPatchC); 
	   }
      }
   }

   // Patches for Great Plains 1
   if (patternChance == 9)
   {
      for (i=0; <cNumberNonGaiaPlayers*30)   
      {
	   int gpPatch2=rmCreateArea("GP patch "+i);
	   rmSetAreaWarnFailure(gpPatch2, false);
	   rmSetAreaSize(gpPatch2, rmAreaTilesToFraction(50), rmAreaTilesToFraction(90));
	   if (rmRandInt(1,2) == 1)
	      rmSetAreaTerrainType(gpPatch2, "great_lakes\ground_grass4_gl");
	   else
	      rmSetAreaTerrainType(gpPatch2, "great_lakes\ground_grass5_gl");
	   rmAddAreaToClass(gpPatch2, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatch2, 2);
	   rmSetAreaMaxBlobs(gpPatch2, 4);
	   rmSetAreaMinBlobDistance(gpPatch2, 12.0);
	   rmSetAreaMaxBlobDistance(gpPatch2, 18.0);
	   rmSetAreaCoherence(gpPatch2, 0.1);
	   rmSetAreaSmoothDistance(gpPatch2, 10);
	   rmAddAreaConstraint(gpPatch2, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatch2, patchConstraint);
	   rmAddAreaConstraint(gpPatch2, avoidCliffsShort);
	   rmBuildArea(gpPatch2); 
      }
   }

   // Patches for Great Plains 2 - break up the lines!
   if (patternChance == 10)
   {
      for (i=0; <cNumberNonGaiaPlayers*15)   
      {
	   int gpPatchA=rmCreateArea("GP patch A"+i);
	   rmSetAreaWarnFailure(gpPatchA, false);
	   rmSetAreaSize(gpPatchA, rmAreaTilesToFraction(75), rmAreaTilesToFraction(140));
         rmSetAreaTerrainType(gpPatchA, "great_plains\ground2_gp");
	   rmAddAreaToClass(gpPatchA, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatchA, 2);
	   rmSetAreaMaxBlobs(gpPatchA, 4);
	   rmSetAreaMinBlobDistance(gpPatchA, 5.0);
	   rmSetAreaMaxBlobDistance(gpPatchA, 12.0);
	   rmSetAreaCoherence(gpPatchA, 0.3);
	   rmSetAreaSmoothDistance(gpPatchA, 10);
	   rmAddAreaConstraint(gpPatchA, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatchA, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatchA, patchConstraint);
	   rmBuildArea(gpPatchA); 
      }
      for (i=0; <cNumberNonGaiaPlayers*15)   // little green patches
      {
	   int gpPatchC=rmCreateArea("GP patch C"+i);
	   rmSetAreaWarnFailure(gpPatchC, false);
	   rmSetAreaSize(gpPatchC, rmAreaTilesToFraction(15), rmAreaTilesToFraction(40));
         rmSetAreaTerrainType(gpPatchC, "great_plains\ground8_gp");
	   rmAddAreaToClass(gpPatchC, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatchC, 2);
	   rmSetAreaMaxBlobs(gpPatchC, 4);
	   rmSetAreaMinBlobDistance(gpPatchC, 5.0);
	   rmSetAreaMaxBlobDistance(gpPatchC, 10.0);
	   rmSetAreaCoherence(gpPatchC, 0.1);
	   rmSetAreaSmoothDistance(gpPatchC, 10);
	   rmAddAreaConstraint(gpPatchC, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatchC, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatchC, patchConstraint);
	   rmBuildArea(gpPatchC); 
      }
      for (i=0; <cNumberNonGaiaPlayers*20)   
      {
	   int gpPatchD=rmCreateArea("GP patch D"+i);
	   rmSetAreaWarnFailure(gpPatchD, false);
	   rmSetAreaSize(gpPatchD, rmAreaTilesToFraction(50), rmAreaTilesToFraction(70));
         rmSetAreaTerrainType(gpPatchD, "great_plains\ground3_gp");
	   rmAddAreaToClass(gpPatchD, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(gpPatchD, 3);
	   rmSetAreaMaxBlobs(gpPatchD, 5);
	   rmSetAreaMinBlobDistance(gpPatchD, 12.0);
	   rmSetAreaMaxBlobDistance(gpPatchD, 20.0);
	   rmSetAreaCoherence(gpPatchD, 0.1);
	   rmSetAreaSmoothDistance(gpPatchD, 10);
	   rmAddAreaConstraint(gpPatchD, shortAvoidImpassableLand);
	   rmAddAreaConstraint(gpPatchD, avoidCliffsShort);
	   rmAddAreaConstraint(gpPatchD, patchConstraint);
	   rmBuildArea(gpPatchD); 
      }
   }
   if (patternChance == 12) // Texas desert
   {
	int bigDecorationID=rmCreateObjectDef("Big Texas Things");
	int avoidBigDecoration=rmCreateTypeDistanceConstraint("avoid big decorations", "BigPropTexas", 45.0);
	rmAddObjectDefItem(bigDecorationID, "BigPropTexas", 1, 0.0);
	rmSetObjectDefMinDistance(bigDecorationID, 0.0);
	rmSetObjectDefMaxDistance(bigDecorationID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(bigDecorationID, avoidAll);
	rmAddObjectDefConstraint(bigDecorationID, avoidImportantItem);
	rmAddObjectDefConstraint(bigDecorationID, avoidCoin);
	rmAddObjectDefConstraint(bigDecorationID, avoidImpassableLand);
	rmAddObjectDefConstraint(bigDecorationID, avoidBigDecoration);
	rmAddObjectDefConstraint(bigDecorationID, avoidCliffs);
	rmAddObjectDefConstraint(bigDecorationID, longPlayerConstraint);
	rmPlaceObjectDefAtLoc(bigDecorationID, 0, 0.5, 0.5, rmRandInt(2,3));
   }

   if (plainsMap == 1)
   {
	int areThereBuffalo=rmRandInt(1, 2);
	int howManyBuffalo=rmRandInt(2, 3);
	if ( areThereBuffalo == 1 )
	{
		int bisonCarcass=rmCreateGrouping("Bison Carcass", "gp_carcass_bison");
		rmSetGroupingMinDistance(bisonCarcass, 0.0);
		rmSetGroupingMaxDistance(bisonCarcass, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(bisonCarcass, avoidImpassableLand);
		rmAddGroupingConstraint(bisonCarcass, playerConstraint);
		rmAddGroupingConstraint(bisonCarcass, avoidTradeRoute);
		rmAddGroupingConstraint(bisonCarcass, avoidSocket);
		rmAddGroupingConstraint(bisonCarcass, avoidStartingUnits);
		rmAddGroupingConstraint(bisonCarcass, avoidAll);
		rmAddGroupingConstraint(bisonCarcass, avoidNuggetSmall);
		rmPlaceGroupingAtLoc(bisonCarcass, 0, 0.5, 0.5, howManyBuffalo);
	}

	int grassPatchGroupType=-1;
	int grassPatchGroup=-1;

	for(i=1; <14*cNumberNonGaiaPlayers)
      {
		grassPatchGroupType=rmRandInt(1, 7);
		grassPatchGroup=rmCreateGrouping("Grass Patch Group"+i, "gp_grasspatch0"+grassPatchGroupType);
		rmSetGroupingMinDistance(grassPatchGroup, 0.0);
		rmSetGroupingMaxDistance(grassPatchGroup, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(grassPatchGroup, avoidImpassableLand);
		rmAddGroupingConstraint(grassPatchGroup, playerConstraint);
		rmAddGroupingConstraint(grassPatchGroup, avoidTradeRoute);
		rmAddGroupingConstraint(grassPatchGroup, avoidSocket);
		rmAddGroupingConstraint(grassPatchGroup, avoidNatives);
		rmAddGroupingConstraint(grassPatchGroup, avoidNuggetSmall);
		rmAddGroupingConstraint(grassPatchGroup, playerEdgeConstraint);
		rmAddGroupingConstraint(grassPatchGroup, avoidStartingUnits);
		rmAddGroupingConstraint(grassPatchGroup, avoidAll);
		rmAddGroupingConstraint(grassPatchGroup, avoidCliffs);
		rmPlaceGroupingAtLoc(grassPatchGroup, 0, 0.5, 0.5, 1);
	}

	int flowerPatchGroupType=-1;
	int flowerPatchGroup=-1;

	for(i=1; <12*cNumberNonGaiaPlayers)
      {
		flowerPatchGroupType=rmRandInt(1, 8);
		flowerPatchGroup=rmCreateGrouping("Flower Patch Group"+i, "gp_flower0"+flowerPatchGroupType);
		rmSetGroupingMinDistance(flowerPatchGroup, 0.0);
		rmSetGroupingMaxDistance(flowerPatchGroup, rmXFractionToMeters(0.5));
		rmAddGroupingConstraint(flowerPatchGroup, avoidImpassableLand);
		rmAddGroupingConstraint(flowerPatchGroup, playerConstraint);
		rmAddGroupingConstraint(flowerPatchGroup, avoidTradeRoute);
		rmAddGroupingConstraint(flowerPatchGroup, avoidSocket);
		rmAddGroupingConstraint(flowerPatchGroup, avoidNatives);
		rmAddGroupingConstraint(flowerPatchGroup, avoidNuggetSmall);
		rmAddGroupingConstraint(flowerPatchGroup, avoidAll);
		rmAddGroupingConstraint(flowerPatchGroup, avoidCliffs);
		rmAddGroupingConstraint(flowerPatchGroup, playerEdgeConstraint);
		rmAddGroupingConstraint(flowerPatchGroup, avoidStartingUnits);
		rmPlaceGroupingAtLoc(flowerPatchGroup, 0, 0.5, 0.5, 1);
	}
   }

   if (vultures == 1)
   { 
	int vultureID=rmCreateObjectDef("perching vultures");
	int avoidVultures=rmCreateTypeDistanceConstraint("avoid other vultures", "PropVulturePerching", 30.0);
	rmAddObjectDefItem(vultureID, "PropVulturePerching", 1, 0.0);
	rmSetObjectDefMinDistance(vultureID, 0.0);
	rmSetObjectDefMaxDistance(vultureID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(vultureID, avoidAll);
	rmAddObjectDefConstraint(vultureID, avoidImportantItem);
	rmAddObjectDefConstraint(vultureID, avoidCoin);
	rmAddObjectDefConstraint(vultureID, avoidImpassableLand);
	rmAddObjectDefConstraint(vultureID, avoidTradeRoute);
	rmAddObjectDefConstraint(vultureID, avoidCliffs);
	rmAddObjectDefConstraint(vultureID, avoidVultures);
	rmAddObjectDefConstraint(vultureID, longPlayerConstraint);
	rmPlaceObjectDefAtLoc(vultureID, 0, 0.5, 0.5, 2);
   }

   if (eagles == 1)
   {
	int avoidEagles=rmCreateTypeDistanceConstraint("avoids Eagles", "EaglesNest", 40.0);
	int randomEagleTreeID=rmCreateObjectDef("random eagle tree");
	rmAddObjectDefItem(randomEagleTreeID, "EaglesNest", 1, 0.0);
	rmSetObjectDefMinDistance(randomEagleTreeID, 0.0);
	rmSetObjectDefMaxDistance(randomEagleTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomEagleTreeID, avoidAll);
	rmAddObjectDefConstraint(randomEagleTreeID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidEagles);
	rmPlaceObjectDefAtLoc(randomEagleTreeID, 0, 0.5, 0.5, 2);
   }

   if (patternChance == 13) // Sonora
   {
	int buzzardFlockID=rmCreateObjectDef("buzzards");
	int avoidBuzzards=rmCreateTypeDistanceConstraint("buzzard avoid buzzard", "BuzzardFlock", 70.0);
	rmAddObjectDefItem(buzzardFlockID, "BuzzardFlock", 1, 3.0);
	rmSetObjectDefMinDistance(buzzardFlockID, 0.0);
	rmSetObjectDefMaxDistance(buzzardFlockID, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(buzzardFlockID, avoidBuzzards);
	rmAddObjectDefConstraint(buzzardFlockID, avoidSocket);
	rmAddObjectDefConstraint(buzzardFlockID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(buzzardFlockID, playerConstraint);
	rmPlaceObjectDefAtLoc(buzzardFlockID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
   }

   if (patternChance == 4) // GL
   {
	int avoidGrass=rmCreateTypeDistanceConstraint("avoids grass", "underbrushTexasGrass", 30.0);
   	int Grass=rmCreateObjectDef("grass");
	rmAddObjectDefItem(Grass, "underbrushTexasGrass", 1, 0.0);
	rmSetObjectDefMinDistance(Grass, 0.0);
	rmSetObjectDefMaxDistance(Grass, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(Grass, avoidAll);
	rmAddObjectDefConstraint(Grass, avoidImpassableLand);
	rmAddObjectDefConstraint(Grass, playerConstraint);
	rmPlaceObjectDefAtLoc(Grass, 0, 0.5, 0.5, 8*cNumberNonGaiaPlayers);
   }

   // Text
   rmSetStatusText("",0.99);

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

  
