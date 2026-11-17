// Delta - a map for AOE3:The War Chiefs
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
   string terrainType = "";
   string terrainPatchType = "";
   string terrainPatch2Type = "";
   string forestType = "";
   string riverType = "";
   string treeType = "";
   string deerType = "";
   string deer2Type = "";
   string sheepType = "";
   string extraHerdType = "";
   string fishType = "";
   string native1Name = "";
   string native2Name = "";
   string patchMixType = "";
   string mineType = "";

// Picks the map size
   int playerTiles=16500;
   if (cNumberNonGaiaPlayers > 2)
      playerTiles = 15000;
   if (cNumberNonGaiaPlayers > 4)
      playerTiles = 14000;
   if (cNumberNonGaiaPlayers > 6)
      playerTiles = 13000;

   int teamZeroCount = rmGetNumberPlayersOnTeam(0);
   int teamOneCount = rmGetNumberPlayersOnTeam(1);
   // Increased size for the 3v1s, 5v1s, 6v1s, and 7v1s, or >=4v2 - bigger map.
   int placeHolder = 0;
   if (cNumberNonGaiaPlayers > 3)
   {
	   if (( teamZeroCount >= teamOneCount * 2 ) || ( teamOneCount >= teamZeroCount * 2 ))
	   {
		placeHolder = playerTiles + 1400;
	      playerTiles = placeHolder + 100;
	   }
   }
   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

// Pattern choices
   int patternChance = rmRandInt(1,21); 
   int nativePattern = -1;
   int nativeChance = rmRandInt(1,6);
   int variantChance = rmRandInt(1,2);
   int sheepChance = rmRandInt(1,2);
   int twoChoice = rmRandInt(1,2);
   int threeChoice = rmRandInt(1,3);
   int noMix = -1;
   int forestPatch = -1;
   int terrainPatches = -1;
   int placeBerries = 1;
   int specialPatch = -1;
   int deltaPositionChance = rmRandInt(1,2);

   if (patternChance == 1) // NE
   { 
      rmSetMapType("newEngland");
	rmSetLightingSet("new england"); 
      baseType = "newengland_grass";
	forestType = "new england forest";
	riverType = "new england lake";
	treeType = "TreeNewEngland";
      if (variantChance == 1)
      {
         deerType = "deer";
         deer2Type = "moose";
      }
      else if (variantChance == 2)
      {
         deerType = "turkey";
         deer2Type = "deer";
      }
      if (rmRandInt(1,2) == 1)
   	   extraHerdType = "deer";
      else
         extraHerdType = "moose"; 
      if (sheepChance == 1)
         sheepType = "sheep";
      else
         sheepType = "cow";
      fishType = "FishSalmon";
	mineType = "mine";
	if (nativeChance < 4) 
         nativePattern = 40;
	else
         nativePattern = 5;
   }
   else if (patternChance == 2) // bayou
   {
      rmSetMapType("bayou");
      rmSetLightingSet("bayou");
      baseType = "bayou_grass";
	forestType = "bayou swamp forest";
      riverType = "yucatan Coast";
	treeType = "TreeBayou";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "turkey";
	}
      else 
	{     
         deerType = "turkey";
         deer2Type = "deer";      
	}
      if (rmRandInt(1,2) == 1)
   	   extraHerdType = "deer";
      else
         extraHerdType = "turkey"; 
      if (sheepChance == 1)
         sheepType = "sheep";
      else
         sheepType = "cow";
      fishType = "FishBass";
	mineType = "mine";
	if (nativeChance < 3)
	   nativePattern = 3;
	else if (nativeChance < 5)
	   nativePattern = 21;
	else
	   nativePattern = 42;
   }
   else if (patternChance == 3) // Great Lakes
   {
	rmSetMapType("greatlakes");
	rmSetLightingSet("Great Lakes");
      baseType = "greatlakes_grass";
	forestType = "great lakes forest";
      riverType = "great lakes";
	treeType = "TreeGreatLakes";
      if (variantChance == 1)
      {
         deerType = "deer";
         deer2Type = "moose";
	   extraHerdType = "bison";
      }
      else if (variantChance == 2)
      {
         deerType = "deer";
         deer2Type = "turkey";
	   extraHerdType = "moose";
      }
      fishType = "FishBass";
	mineType = "MineCopper";
      if (sheepChance == 1)
         sheepType = "sheep";
      else
         sheepType = "cow";
      nativeChance = rmRandInt(1,4);
      if (nativeChance == 1) 
         nativePattern = 4;
      else if (nativeChance == 2) 
         nativePattern = 5;
      else if (nativeChance == 3) 
         nativePattern = 40;
      else if (nativeChance == 4) 
         nativePattern = 22;
   }
   else if (patternChance == 4) // winter
   {
      if (variantChance == 1)
	{
         rmSetMapType("greatlakes");
         rmSetLightingSet("Great Lakes Winter");
         deerType = "deer";
         deer2Type = "moose";
         extraHerdType = "elk";
	}
	else
	{
         rmSetMapType("yukon");
         rmSetLightingSet("yukon");
         deerType = "deer";
         deer2Type = "bighornsheep";
         extraHerdType = "moose";
	}
      rmSetMapType("snow");
      baseType = "greatlakes_snow";
	forestType = "great lakes forest snow";
	riverType = "great lakes ice";
	treeType = "TreeGreatLakesSnow";    
      sheepType = "sheep";
      fishType = "FishSalmon";
	if (rmRandInt(1,2) == 1)
	   mineType = "MineTin";
	else
	   mineType = "MineCopper";
      placeBerries = 0;
      if (nativeChance == 1) 
         nativePattern = 4;
      else if (nativeChance == 2) 
         nativePattern = 5;
      else if (nativeChance == 3) 
         nativePattern = 40;
      else if (nativeChance == 4) 
         nativePattern = 22;
   }
   else if (patternChance == 5) // saguenay
   {
      rmSetMapType("saguenay");
      rmSetLightingSet("saguenay");
      baseType = "saguenay grass";
	forestType = "saguenay forest";
	riverType = "saguenay lake";
	treeType = "TreeSaguenay";
      if (variantChance == 1)
	{
         deerType = "caribou";
         deer2Type = "moose";
         extraHerdType = "caribou";
	}
      else 
	{     
         deerType = "caribou";
         deer2Type = "caribou";
         extraHerdType = "moose";       
	}
      sheepType = "sheep";
      fishType = "FishSalmon";
	if (rmRandInt(1,2) == 1)
	   mineType = "MineTin";
	else
	   mineType = "MineCopper";
	if (nativeChance < 3)
	   nativePattern = 5;
	else if (nativeChance < 5)
	   nativePattern = 6;
	else 
	   nativePattern = 16;
   }
   else if (patternChance == 6) // great plains 1
   {
      rmSetMapType("greatPlains");
      rmSetLightingSet("great plains");       
      baseType = "great plains grass"; 
	forestType = "great plains forest";
	riverType = "texas pond";
	treeType = "TreeGreatPlains";
      if (variantChance == 1)
	{
         deerType = "bison";
         deer2Type = "pronghorn";
         extraHerdType = "bison";
	}
      else 
	{     
         deerType = "pronghorn";
         deer2Type = "bison";
         extraHerdType = "elk";
	} 
      if (sheepChance == 1)
         sheepType = "cow";
      else
         sheepType = "sheep";
      fishType = "FishBass";
	mineType = "mine";
	if (nativeChance == 1)
	   nativePattern = 23;
	else if (nativeChance == 2)
	   nativePattern = 29;
	else if (nativeChance == 3)
	   nativePattern = 19;
	else if (nativeChance == 4)
	   nativePattern = 8;
	else if (nativeChance == 5)
	   nativePattern = 28;
	else if (nativeChance == 6)
	   nativePattern = 22;
   }
   else if (patternChance == 7) // great plains 2
   {
      rmSetMapType("greatPlains");
      rmSetLightingSet("great plains");
      baseType = "great plains drygrass";
	forestType = "great plains forest";
	riverType = "texas pond";
	treeType = "TreeGreatPlains";
      if (variantChance == 1)
	{
         deerType = "bison";
         deer2Type = "pronghorn";
         extraHerdType = "bison";
	}
      else 
	{     
         deerType = "pronghorn";
         deer2Type = "bison";
         extraHerdType = "bison";
	}
      sheepType = "cow";
      fishType = "FishBass";
	mineType = "mine";
	forestPatch = 1; 
	if (nativeChance == 1)
	   nativePattern = 30;
	else if (nativeChance == 2)
	   nativePattern = 29;
	else if (nativeChance == 3)
	   nativePattern = 32;
	else if (nativeChance == 4)
	   nativePattern = 8;
	else if (nativeChance == 5)
	   nativePattern = 28;
	else
	   nativePattern = 23;
   }
   else if (patternChance == 8) // texas grass
   {   
      rmSetMapType("texas");
      rmSetLightingSet("texas");
      baseType = "texas_grass";
	forestType = "texas forest";
	riverType = "texas pond";
	treeType = "TreeTexas";
      if (variantChance == 1)
	{
         deerType = "bison";
         deer2Type = "deer";
         extraHerdType = "bison";
	}
      else 
	{     
         deerType = "pronghorn";
         deer2Type = "bison";
         extraHerdType = "bison";
	}
      sheepType = "cow";
      fishType = "FishBass";
	mineType = "mine";

	if (nativeChance == 1)
	   nativePattern = 30;
	else if (nativeChance == 2)
	   nativePattern = 29;
	else if (nativeChance == 3)
	   nativePattern = 32;
	else if (nativeChance == 4)
	   nativePattern = 19;
	else if (nativeChance == 5)
	   nativePattern = 20;
	else
	   nativePattern = 9;
   }
   else if (patternChance == 9) // texas desert
   {   
      rmSetMapType("texas");
      rmSetLightingSet("texas");
      baseType = "texas_dirt";
	forestType = "texas forest dirt";
	riverType = "texas pond";
	treeType = "TreeTexasDirt";
      if (variantChance == 1)
	{
         deerType = "bison";
         deer2Type = "pronghorn";
         extraHerdType = "pronghorn";
	}
      else 
	{     
         deerType = "pronghorn";
         deer2Type = "bison";
         extraHerdType = "bison";
	}
      sheepType = "cow";
      fishType = "FishBass";
	mineType = "mine";
	if (nativeChance == 1)
	   nativePattern = 30;
	else if (nativeChance == 2)
	   nativePattern = 29;
	else if (nativeChance == 3)
	   nativePattern = 32;
	else if (nativeChance == 4)
	   nativePattern = 31;
	else if (nativeChance == 5)
	   nativePattern = 38;
	else
	   nativePattern = 39;
   }
   else if (patternChance == 10) // california desert 
   {
      rmSetMapType("california");
      rmSetLightingSet("texas");
      if (variantChance == 1)
	{
         deerType = "pronghorn";
         deer2Type = "deer";
         extraHerdType = "deer";
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "pronghorn";
         extraHerdType = "pronghorn";
	}
	forestType = "California Desert Forest";
	treeType = "TreeSonora";
	riverType = "texas pond";
	if (twoChoice == 2)
	{ 
	   baseType = "california_desert";
	   patchMixType = "california_desert0";
	   forestPatch = 1;
	}
	else
	{
	   baseType = "california_desert2";
	   patchMixType = "california_desert";
	   forestType = "california madrone forest";
	   treeType = "TreeMadrone";
         extraHerdType = "elk";
	}
       if (sheepChance == 1)
         sheepType = "cow";
      else
         sheepType = "sheep";
      fishType = "FishBass";
      mineType = "mine";
	specialPatch = 1;
	if (nativeChance == 1)
	   nativePattern = 27;
	else if (nativeChance == 2)
	   nativePattern = 43;
	else if (nativeChance == 3)
	   nativePattern = 31;
	else if (nativeChance == 4)
	   nativePattern = 30;
	else if (nativeChance == 5)
	   nativePattern = 39;
	else
	   nativePattern = 38;
   }
   else if (patternChance == 11) // california green
   {
      rmSetMapType("california");
      rmSetLightingSet("california");
      baseType = "california_grass";
	if (twoChoice == 1)
	   patchMixType = "california_grassrocks"; 
	else
	   patchMixType = "california_snowground5";
	twoChoice = rmRandInt(1,2);  
	if (twoChoice == 1)
	{ 
	   forestType = "california redwood forest";
	   treeType = "TreeRedwood";
	}
	else 
	{ 
	   forestType = "California pine forest";
	   treeType = "TreePonderosaPine";
	}
	riverType = "texas pond";
      if (variantChance == 1)
	{
         deerType = "elk";
         deer2Type = "deer";
         extraHerdType = "elk";
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "deer";
         extraHerdType = "elk";
	} 
      if (sheepChance == 1)
         sheepType = "cow";
      else
         sheepType = "sheep";
      fishType = "FishSalmon";
      mineType = "mine";
	specialPatch = 1;

	if (nativeChance == 1)
	   nativePattern = 27;
	else if (nativeChance == 2)
	   nativePattern = 28;
	else if (nativeChance == 3)
	   nativePattern = 29;
	else if (nativeChance == 4)
	   nativePattern = 30;
	else if (nativeChance == 5)
	   nativePattern = 43;
	else
	   nativePattern = 8;
   }
   else if (patternChance == 12) // nwt    
   {
      rmSetMapType("northwestTerritory");
	rmSetLightingSet("nwterritory");
      baseType = "nwt_grass1";
	if (rmRandInt(1,2) == 1)
	{
	   forestType = "NW Territory Birch Forest";
   	   treeType = "TreeGreatLakes";
	}
	else
	{ 
	   forestType = "NW Territory Forest";
	   treeType = "TreeGreatPlains";   
	}
	riverType = "Northwest Territory Water";
      if (variantChance == 1)
	{
         deerType = "elk";
         deer2Type = "deer";
         extraHerdType = "moose"; 
	}
      else 
	{     
         deerType = "deer";
         deer2Type = "moose";
         extraHerdType = "elk";
	} 
      if (sheepChance == 1)
         sheepType = "sheep";
      else
         sheepType = "cow";
      fishType = "FishSalmon";
      mineType = "mine";
	if (nativeChance == 1)
	   nativePattern = 27;
	else if (nativeChance == 2)
	   nativePattern = 28;
	else if (nativeChance == 3)
	   nativePattern = 29;
	else if (nativeChance == 4)
	   nativePattern = 6;
	else if (nativeChance == 5)
	   nativePattern = 7;
	else
	   nativePattern = 8;
   }
   else if (patternChance == 13) // yukon tundra
   {
      rmSetMapType("yukon");
      rmSetMapType("snow");
      rmSetLightingSet("yukon");
      baseType = "yukon grass";
	forestType = "yukon forest";
	riverType = "hudson bay";
	treeType = "TreeYukon";
      if (variantChance == 1)
	{
         deerType = "caribou";
         deer2Type = "caribou";
         extraHerdType = "muskOx";
	}
      else 
	{
         deerType = "muskOx";
         deer2Type = "bighornsheep";
         extraHerdType = "caribou";
	}
      sheepChance = 0;
      fishType = "FishSalmon";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
      placeBerries = 0;

	if (nativeChance == 1)
	   nativePattern = 5;
	else if (nativeChance == 2)
	   nativePattern = 6;
	else if (nativeChance == 3)
	   nativePattern = 8;
	else if (nativeChance == 4)
	   nativePattern = 16;
	else if (nativeChance == 5)
	   nativePattern = 27;
	else
	   nativePattern = 28;
   }
   else if (patternChance == 14) // palm and grass
   {
      rmSetMapType("bayou");
	rmSetLightingSet("Texas"); 
      baseType = "amazon grass";
      terrainType = "amazon\ground4_ama";
      terrainPatchType = "amazon\ground5_ama";
      terrainPatch2Type = "amazon\ground3_ama";
      riverType = "yucatan coast";
      forestType = "caribbean palm forest";
      treeType = "TreeCaribbean";
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
	   extraHerdType = "deer";
      else
         extraHerdType = "turkey";
      fishType = "FishMoonBass";
      mineType = "mine";  
      sheepType = "cow";
	noMix = 1;
	forestPatch = 1;
	terrainPatches = 1;
      if (nativeChance == 1) 
         nativePattern = 26;
      else if (nativeChance == 2) 
         nativePattern = 3;
      else if (nativeChance == 3) 
         nativePattern = 13;
      else if (nativeChance == 4) 
         nativePattern = 42;
      else if (nativeChance == 5) 
         nativePattern = 35;
      else if (nativeChance == 6) 
         nativePattern = 36;
   }
   else if (patternChance == 15) // jungle
   {
      rmSetMapType("tropical");        
      baseType = "yucatan_grass";
	forestType = "yucatan forest";
      riverType = "yucatan coast";
	treeType = "TreeYucatan";
      if (variantChance == 1)
      {
         deerType = "deer";
         deer2Type = "turkey";
         extraHerdType = "deer";
         rmSetMapType("yucatan");
	   rmSetLightingSet("yucatan");
      }
      else
	{
         deerType = "capybara";
         deer2Type = "turkey";
         extraHerdType = "tapir";
   	   rmSetMapType("amazonia");
	   rmSetLightingSet("amazon");
	}
      sheepChance = 0;
	sheepType = "cow";
      fishType = "FishTarpon";
      mineType = "mine";
 	if (nativeChance == 1)
	   nativePattern = 13;
	else if (nativeChance == 2)
	   nativePattern = 12;
	else if (nativeChance == 3)
	   nativePattern = 34;
	else if (nativeChance == 4)
	   nativePattern = 35;
	else if (nativeChance == 5)
	   nativePattern = 36;
	else
	   nativePattern = 26;
   }
   else if (patternChance == 16) // pampas
   {
      rmSetMapType("pampas");
      rmSetLightingSet("pampas");
	baseType = "pampas_grass";
      terrainType = "pampas\ground3_pam";
      terrainPatchType = "pampas\ground5_pam";
      terrainPatch2Type = "pampas\ground6_pam";
      forestType = "pampas forest";
	treeType = "TreePampas";
      riverType = "Lisbon";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "rhea";
         extraHerdType = "rhea";
	}
      else 
	{     
         deerType = "rhea";
         deer2Type = "deer";
         extraHerdType = "rhea";
	}
      sheepType = "llama";
      fishType = "FishMoonBass";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
	terrainPatches = 1;
	if (nativeChance == 1)
	   nativePattern = 14;
	else if (nativeChance == 2)
	   nativePattern = 15;
	else if (nativeChance == 3)
	   nativePattern = 24;
	else if (nativeChance == 4)
	   nativePattern = 25;
	else if (nativeChance == 5)
	   nativePattern = 26;
	else
	   nativePattern = 13;
   }
   else if (patternChance == 17) // patagonia
   {
      rmSetMapType("patagonia");
      rmSetLightingSet("patagonia");
	if (rmRandInt(1,2) == 1)
	{
	   baseType = "patagonia_grass";
	   patchMixType = "patagonia_dirt";
	}
	else
	{
         baseType = "patagonia_dirt";
	   patchMixType = "patagonia_grass";
	}
	forestType = "patagonia forest";
      riverType = "hudson bay";
	treeType = "TreePatagoniaDirt";
      if (variantChance == 1)
	{
         deerType = "deer";
         deer2Type = "rhea";
         extraHerdType = "rhea";
	}
      else 
	{     
         deerType = "rhea";
         deer2Type = "deer";
         extraHerdType = "rhea";
	}
      sheepType = "llama";
      fishType = "FishSalmon";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
	specialPatch = 1;
	if (nativeChance == 1)
	   nativePattern = 14;
	else if (nativeChance == 2)
	   nativePattern = 15;
	else if (nativeChance == 3)
	   nativePattern = 24;
	else if (nativeChance == 4)
	   nativePattern = 25;
	else if (nativeChance == 5)
	   nativePattern = 26;
	else
	   nativePattern = 11;
   }
   else if (patternChance == 18) // araucania south 
   {
      rmSetMapType("araucania");
      rmSetMapType("snow");
      rmSetLightingSet("SthAraucaniaLight");
      baseType = "araucania_snow_a";
	patchMixType = "araucania_snow_c";
	forestType = "Patagonia Snow Forest";
	riverType = "great lakes ice";
	treeType = "TreePatagoniaSnow";
      if (variantChance == 1)
	{
         deerType = "guanaco";
         deer2Type = "deer";
         extraHerdType = "guanaco"; 
	}
      else 
	{     
         deerType = "guanaco";
         deer2Type = "guanaco";
         extraHerdType = "guanaco";
	} 
      sheepType = "llama";
      fishType = "FishSalmon";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
      placeBerries = 0;
//	specialPatch = 1;
	if (nativeChance == 1)
	   nativePattern = 14;
	else if (nativeChance == 2)
	   nativePattern = 25;
	else if (nativeChance == 3)
	   nativePattern = 26;
	else if (nativeChance == 4)
	   nativePattern = 24;
	else if (nativeChance == 5)
	   nativePattern = 34;
	else
	   nativePattern = 11;
   }
   else if (patternChance == 19) // araucania green or central
   {
      rmSetMapType("araucania");
      rmSetLightingSet("Araucania Central");
	if (rmRandInt(1,2) == 1)
	{
         baseType = "araucania_grass_b";
	   patchMixType = "araucania_grass_c";
	}
	else 
	{
         baseType = "araucania_grass_c";
         patchMixType = "araucania_grass_b";
	}
	forestType = "Araucania Forest";
      riverType = "Seville";
	treeType = "TreeAraucania";
      if (variantChance == 1)
	{
         deerType = "guanaco";
         deer2Type = "deer";
         extraHerdType = "guanaco"; 
	}
      else 
	{     
         deerType = "guanaco";
         deer2Type = "guanaco";
         extraHerdType = "guanaco";
	} 
      sheepType = "llama";
      fishType = "FishSalmon";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
	forestPatch = 1; 
	specialPatch = 1;
	if (nativeChance == 1)
	   nativePattern = 14;
	else if (nativeChance == 2)
	   nativePattern = 25;
	else if (nativeChance == 3)
	   nativePattern = 26;
	else if (nativeChance == 4)
	   nativePattern = 24;
	else if (nativeChance == 5)
	   nativePattern = 34;
	else
	   nativePattern = 11;
   }
   else if (patternChance == 20) // atacama - araucania north  
   {
      rmSetMapType("araucania");
      rmSetLightingSet("NthAraucaniaLight");
	if (twoChoice == 1)
	{
	   baseType = "araucania_north_dirt_a"; 
         patchMixType = "araucania_north_grass_a";
	   placeBerries = 0;
   	   forestPatch = 1;
	}
	else 
	{
	   if (rmRandInt(1,2) == 1)
	   {
	      baseType = "araucania_north_grass_a";
            patchMixType = "araucania_north_dirt_a";
   	      forestPatch = 1;
	   }
	   else 
	   {
	      baseType = "araucania_north_grass_a";
	      patchMixType = "araucania_north_grass_b"; 
	   }
	}
	forestType =  "North Araucania Forest";
	treeType = "TreeAraucania";
	riverType = "texas pond";   
      if (variantChance == 1)
	{
         deerType = "guanaco";
         deer2Type = "deer";
         extraHerdType = "guanaco"; 
	}
      else 
	{     
         deerType = "guanaco";
         deer2Type = "guanaco";
         extraHerdType = "guanaco";
	} 
      sheepType = "llama";
      fishType = "FishSalmon";
      mineType = "MineCopper";
	specialPatch = 1;
	if (nativeChance == 1)
	   nativePattern = 14;
	else if (nativeChance == 2)
	   nativePattern = 15;
	else if (nativeChance == 3)
	   nativePattern = 24;
	else if (nativeChance == 4)
	   nativePattern = 25;
	else if (nativeChance == 5)
	   nativePattern = 26;
	else
	   nativePattern = 34;
   }
   else if (patternChance == 21) // sonora 
   {   
      rmSetMapType("sonora");
      rmSetLightingSet("pampas");
      baseType = "sonora_dirt";
	forestType = "sonora forest";
      riverType = "Lisbon";
	treeType = "TreeSonora";
      if (variantChance == 1)
	{
         deerType = "bison";
         deer2Type = "pronghorn";
	}
      else 
	{     
         deerType = "pronghorn";
         deer2Type = "bison";
	}
      if (rmRandInt(1,2) == 1)
         extraHerdType = "pronghorn";
      else
         extraHerdType = "turkey";
      sheepType = "cow";
      fishType = "FishBass";
	if (rmRandInt(1,2) == 1)
	   mineType = "mine";
	else
	   mineType = "MineCopper";
	placeBerries = 0;
	if (nativeChance == 1)
	   nativePattern = 30;
	else if (nativeChance == 2)
	   nativePattern = 31;
	else if (nativeChance == 3)
	   nativePattern = 32;
	else if (nativeChance == 4)
	   nativePattern = 33;
	else if (nativeChance == 5)
	   nativePattern = 35;
	else
	   nativePattern = 37;
   }

// Other map parameters
   rmSetSeaLevel(0);
   rmSetMapElevationParameters(cElevTurbulence, 0.04, 3, 0.3, 2.0);
   rmSetSeaType(riverType);

   if (noMix == 1)
      rmTerrainInitialize(terrainType, 1); 
   else
   {
      rmSetBaseTerrainMix(baseType);  
      rmTerrainInitialize("yukon\ground1_yuk", 1);
   }
   rmSetMapType("grass");
   rmSetMapType("water");
   rmSetWorldCircleConstraint(true);
   rmSetWindMagnitude(2);

   chooseMercs();
	wotta_triggers();

// Define some classes. These are used later for constraints.
   int classPlayer=rmDefineClass("player");
   rmDefineClass("startingUnit");
   rmDefineClass("classForest");
   rmDefineClass("importantItem");
   rmDefineClass("natives");
   rmDefineClass("classSocket");
   rmDefineClass("classPatch");
   int classHuntable=rmDefineClass("huntableFood");   
   int classHerdable=rmDefineClass("herdableFood");
   int classMine=rmDefineClass("allMines"); 

// -------------Define constraints
   
   // Map edge constraints
   int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
   int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));

    // Cardinal Directions
   int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(300), rmDegreesToRadians(60));
   int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(120), rmDegreesToRadians(240));
   int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
   int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));

   // Player constraints
   int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 30.0);
 
    // Nature avoidance
   int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 18.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 5.0);
   int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 25.0);
   int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 10.0);
   int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 30.0);
   int shortForestConstraint=rmCreateClassDistanceConstraint("short forest vs. forest", rmClassID("classForest"), 12.0);
   int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
   int avoidFastCoin = rmCreateTypeDistanceConstraint("fast coin avoids coin", "gold", 45.0);
   int avoidMineLong = rmCreateClassDistanceConstraint("avoid mines long", rmClassID("allMines"), 50.0);
   int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 40.0);
   int avoidSheep=rmCreateClassDistanceConstraint("sheep avoids sheep etc", rmClassID("herdableFood"), 45.0);
   int huntableConstraint=rmCreateClassDistanceConstraint("huntable constraint", rmClassID("huntableFood"), 35.0);
   int avoidBerryID=rmCreateTypeDistanceConstraint("avoid berry", "BerryBush", 20.0);
 
   // Avoid impassable land
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
   int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);

   // Constraint to avoid water.
   int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water", "Land", false, 4.0);
   int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 8.0);
   int avoidWater15 = rmCreateTerrainDistanceConstraint("avoid water medium long", "Land", false, 15.0);
   int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 20.0);
   int nearWater10 = rmCreateTerrainDistanceConstraint("near water", "Water", true, 10.0);

   // Constraints for water spawn points.
   int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 10.0);
   int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 40);
   int flagCircleConstraint=rmCreatePieConstraint("flag circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.44), rmDegreesToRadians(0), rmDegreesToRadians(360));

   // Unit avoidance
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
   int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("classSocket"), 10.0);
   int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 45.0);
   int avoidImportantItemSmall=rmCreateClassDistanceConstraint("important item small avoidance", rmClassID("importantItem"), 7.0);
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);
   int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 20.0);
   int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 20.0);
   int avoidStartingUnitsSmall=rmCreateClassDistanceConstraint("objects avoid starting units small", rmClassID("startingUnit"), 5.0);
   int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 55.0);
   int avoidNativesMed=rmCreateClassDistanceConstraint("stuff avoids natives medium", rmClassID("natives"), 35.0);
   int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives shorter", rmClassID("natives"), 15.0);

   // Text
   rmSetStatusText("",0.10);

//  RIVERS
   int riverOption = rmRandInt(1,2);

   // main river
   int mainRiver = -1;
   if ( cNumberNonGaiaPlayers < 4 )
	mainRiver = rmRiverCreate(-1, riverType, 5, 14, 12, 14);
   else
	mainRiver = rmRiverCreate(-1, riverType, 5, 14, 13, 16);

   if (riverOption == 1)
   {
      if (deltaPositionChance == 1)
	   rmRiverSetConnections(mainRiver, 0.5, 0.0, 0.5, 0.68);
      else
         rmRiverSetConnections(mainRiver, 0.5, 1.0, 0.5, 0.32); 
   }
   else
   {
      if (deltaPositionChance == 1)
         rmRiverSetConnections(mainRiver, 0.5, 0.0, 0.5, 0.55);
      else
         rmRiverSetConnections(mainRiver, 0.5, 1.0, 0.5, 0.45); 
   }
   rmRiverSetShallowRadius(mainRiver, 8);
   rmRiverAddShallow(mainRiver, 0.1);
   rmRiverBuild(mainRiver);
   rmRiverReveal(mainRiver, 2); 

   // 1st two branches
   int NERiver = rmRiverCreate(-1, riverType, 6, 14, 12, 13);
   // rmRiverConnectRiver(source river, dest river, float pct, float x2, float z2)
   if (riverOption == 1)
   {
      if (deltaPositionChance == 1)
	   rmRiverConnectRiver(NERiver, mainRiver, 0.64, 0.0, 0.7);
      else
         rmRiverConnectRiver(NERiver, mainRiver, 0.64, 0.0, 0.3);
   }      
   else
   {
      if (deltaPositionChance == 1)
	   rmRiverConnectRiver(NERiver, mainRiver, 0.95, 0.0, 0.7);
      else
         rmRiverConnectRiver(NERiver, mainRiver, 0.95, 0.0, 0.3);
   }
   rmRiverSetShallowRadius(NERiver, 9);
   rmRiverAddShallow(NERiver, rmRandFloat(0.15,0.22));
   rmRiverBuild(NERiver);
   rmRiverReveal(NERiver, 2);

   int NWRiver = rmRiverCreate(-1, riverType, 6, 14, 12, 13);
   if (riverOption == 1)
   {
      if (deltaPositionChance == 1)
	   rmRiverConnectRiver(NWRiver, mainRiver, 0.64, 1.0, 0.7);
      else
         rmRiverConnectRiver(NWRiver, mainRiver, 0.64, 1.0, 0.3);
   }      
   else
   {
      if (deltaPositionChance == 1)
	   rmRiverConnectRiver(NWRiver, mainRiver, 0.95, 1.0, 0.7);
      else
         rmRiverConnectRiver(NWRiver, mainRiver, 0.95, 1.0, 0.3);
   } 
   rmRiverSetShallowRadius(NWRiver, 9);
   rmRiverAddShallow(NWRiver, rmRandFloat(0.15,0.22));
   rmRiverBuild(NWRiver);
   rmRiverReveal(NWRiver, 2); 

   // 2nd two branches
   int NE2River = rmRiverCreate(-1, riverType, 6, 14, 11, 12);
   if (riverOption == 1)
   {
      if (deltaPositionChance == 1)
	   rmRiverConnectRiver(NE2River, mainRiver, 0.95, 0.3, 1.0);
      else
         rmRiverConnectRiver(NE2River, mainRiver, 0.95, 0.3, 0.0);
   }       
   else
   {
      if (deltaPositionChance == 1)
	   rmRiverConnectRiver(NE2River, NERiver, 0.7, 0.35, 1.0);
      else
         rmRiverConnectRiver(NE2River, NERiver, 0.7, 0.35, 0.0);
   }      
   rmRiverSetShallowRadius(NE2River, 9);
   rmRiverAddShallow(NE2River, rmRandFloat(0.15,0.25));
   rmRiverBuild(NE2River);
   rmRiverReveal(NE2River, 2); 

   int NW2River = rmRiverCreate(-1, riverType, 6, 14, 11, 12);
   // rmRiverConnectRiver(source river, dest river, float pct, float x2, float z2)
   if (riverOption == 1)
   {
      if (deltaPositionChance == 1)
	   rmRiverConnectRiver(NW2River, mainRiver, 0.95, 0.7, 1.0);
      else
         rmRiverConnectRiver(NW2River, mainRiver, 0.95, 0.7, 0.0);
   }      
   else
   {
      if (deltaPositionChance == 1)
	   rmRiverConnectRiver(NW2River, NWRiver, 0.7, 0.65, 1.0);
      else
         rmRiverConnectRiver(NW2River, NWRiver, 0.7, 0.65, 0.0);
   }      
   rmRiverSetShallowRadius(NW2River, 9);
   rmRiverAddShallow(NW2River, rmRandFloat(0.15,0.25));
   rmRiverBuild(NW2River);
   rmRiverReveal(NW2River, 2); 

// Text
   rmSetStatusText("",0.20);

   // Player placement.
   int playerSide = rmRandInt(1,2);
   if (cNumberTeams == 2)
   {
      if (playerSide == 1)
      {
 	   rmSetPlacementTeam(0);
      }
      else if (playerSide == 2)
	{
	   rmSetPlacementTeam(1);
	}
	if (cNumberNonGaiaPlayers == 2)
	{
         if (deltaPositionChance == 1)
	   {
	      rmSetPlacementSection(0.35, 0.45);
		rmPlacePlayersCircular(0.39, 0.41, 0.0);
	   }
         else
	   {
	      rmSetPlacementSection(0.15, 0.18); 
	      rmPlacePlayersCircular(0.39, 0.41, 0.0);
	   }
	} 
	else if (cNumberNonGaiaPlayers < 5)
	{
         if (deltaPositionChance == 1)
	   {
            rmSetPlacementSection(0.28, 0.4);
		rmPlacePlayersCircular(0.39, 0.41, 0.0);
	   }
         else
	   {
	      rmSetPlacementSection(0.1, 0.22);
	      rmPlacePlayersCircular(0.39, 0.41, 0.0);
	   }
	}
	else 
	{
         if (deltaPositionChance == 1)
	   {
            rmSetPlacementSection(0.29, 0.39);
	      rmPlacePlayersCircular(0.39, 0.41, 0.0);
	   }
         else
	   {
	      rmSetPlacementSection(0.11, 0.21); 
	      rmPlacePlayersCircular(0.39, 0.41, 0.0);
	   }
	}

      if (playerSide == 1)
      {
	   rmSetPlacementTeam(1);
	}
      else if (playerSide == 2)
	{
	   rmSetPlacementTeam(0);
	}
	if (cNumberNonGaiaPlayers == 2)
	{
         if (deltaPositionChance == 1)
	   {
            rmSetPlacementSection(0.65, 0.75);
	      rmPlacePlayersCircular(0.39, 0.41, 0.0);
	   }
         else
	   {
	      rmSetPlacementSection(0.85, 0.88);   
	      rmPlacePlayersCircular(0.39, 0.41, 0.0);
	   }
	}
	else if (cNumberNonGaiaPlayers < 5)
	{
         if (deltaPositionChance == 1)
	   {
            rmSetPlacementSection(0.6, 0.72);
	      rmPlacePlayersCircular(0.39, 0.41, 0.0);
	   }         
	   else
	   {
	      rmSetPlacementSection(0.78, 0.9); 
            rmPlacePlayersCircular(0.39, 0.41, 0.0);
	   }
	} 
	else
	{
         if (deltaPositionChance == 1)
	   {
            rmSetPlacementSection(0.61, 0.71);
	      rmPlacePlayersCircular(0.39, 0.41, 0.0);
	   }
         else
	   {
	      rmSetPlacementSection(0.79, 0.89); 
            rmPlacePlayersCircular(0.39, 0.41, 0.0);
	   }
	}
   }
   else if (cNumberTeams > 2)  // FFA
   {
      bool forwardSide = true;
	if (rmRandInt(1,2) == 1) 
	   forwardSide = false;

      float spacingIncrement = 0.125;
	if (cNumberNonGaiaPlayers > 4)
	   spacingIncrement = 0.07;
	if (cNumberNonGaiaPlayers > 6)
	   spacingIncrement = 0.05;

      float spacingForward = 0;
      float spacingBackward = 0;

      if (deltaPositionChance == 1)
	{ 
         float forwardStart = 0.58;
	   if (cNumberNonGaiaPlayers > 4)
	      forwardStart = 0.57;

         float forwardEnd = 0.75;
	   if (cNumberNonGaiaPlayers > 4)
	      forwardEnd = 0.77;

         float backwardStart = 0.42;
	   if (cNumberNonGaiaPlayers > 4)
   	      backwardStart = 0.43;

         float backwardEnd = 0.44;
	   if (cNumberNonGaiaPlayers > 4)
   	      backwardEnd = 0.45;
	}
	else if (deltaPositionChance == 2)
	{
         forwardStart = 0.09;
	   if (cNumberNonGaiaPlayers > 4)
	      forwardStart = 0.09;

         forwardEnd = 0.26;
	   if (cNumberNonGaiaPlayers > 4)
	      forwardEnd = 0.29;

         backwardStart = 0.92;
	   if (cNumberNonGaiaPlayers > 4)
   	      backwardStart = 0.93;

         backwardEnd = 0.94;
	   if (cNumberNonGaiaPlayers > 4)
   	      backwardEnd = 0.95;
	}

      for (i = 0; < cNumberNonGaiaPlayers)
      {
         if (forwardSide == true)
         {
            rmSetPlacementTeam(i);
            rmSetPlacementSection((forwardStart + spacingForward), forwardEnd);
		if (cNumberNonGaiaPlayers > 4)
	         rmPlacePlayersCircular(0.42, 0.43, 0);
		else
	         rmPlacePlayersCircular(0.39, 0.41, 0);
            spacingForward = spacingForward + spacingIncrement;
         }
         else
         {
            rmSetPlacementTeam(i);
            rmSetPlacementSection(backwardStart, backwardEnd);
		if (cNumberNonGaiaPlayers > 4)
	         rmPlacePlayersCircular(0.42, 0.43, 0);
		else
	         rmPlacePlayersCircular(0.39, 0.41, 0);
            backwardStart = backwardStart - spacingIncrement;
         }
         if (forwardSide == true)
         {
            forwardSide = false;
         }
         else
         {
            forwardSide = true;
         }
      }
   }

// Set up player areas.
   float playerFraction=rmAreaTilesToFraction(100);
   for(i=1; <cNumberPlayers)
   {
      int id=rmCreateArea("Player"+i);
      rmSetPlayerArea(i, id);
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 1);
      rmSetAreaLocPlayer(id, i);
      rmSetAreaWarnFailure(id, false);
   }

   // Clear out constraints for good measure.
   rmClearClosestPointConstraints();

   // Text
   rmSetStatusText("",0.30);

// TRADE ROUTES
   int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
   rmSetObjectDefAllowOverlap(socketID, true);
   rmSetObjectDefMinDistance(socketID, 0.0);
   rmSetObjectDefMaxDistance(socketID, 8.0);

   int tradeRoute1ID = rmCreateTradeRoute();
   if (deltaPositionChance == 1)
   { 
      if (cNumberTeams > 2)
	{
	   rmAddTradeRouteWaypoint(tradeRoute1ID, 0.0, 0.58);
         rmAddRandomTradeRouteWaypoints(tradeRoute1ID, 0.34, 0.39, 5, 7);
	   rmAddRandomTradeRouteWaypoints(tradeRoute1ID, 0.39, 0.18, 3, 3);
	}
	else
	{
   	   if (cNumberNonGaiaPlayers < 4)
	   {
	      rmAddTradeRouteWaypoint(tradeRoute1ID, 0.0, 0.55); 
            rmAddRandomTradeRouteWaypoints(tradeRoute1ID, 0.28, 0.39, 5, 7);
            rmAddRandomTradeRouteWaypoints(tradeRoute1ID, 0.38, 0.0, 5, 7);
	   }
	   else
	   {
	      rmAddTradeRouteWaypoint(tradeRoute1ID, 0.0, 0.58);
            rmAddRandomTradeRouteWaypoints(tradeRoute1ID, 0.32, 0.39, 5, 7);
   	      rmAddRandomTradeRouteWaypoints(tradeRoute1ID, 0.39, 0.0, 5, 7);
  	   }
	}
   }
   else
   {
      if (cNumberTeams > 2)
	{
	   rmAddTradeRouteWaypoint(tradeRoute1ID, 0.0, 0.42);
         rmAddRandomTradeRouteWaypoints(tradeRoute1ID, 0.34, 0.62, 5, 7);
	   rmAddRandomTradeRouteWaypoints(tradeRoute1ID, 0.39, 0.82, 3, 3);
	}
	else
	{
	   if (cNumberNonGaiaPlayers < 4)
	   {
	      rmAddTradeRouteWaypoint(tradeRoute1ID, 0.0, 0.45);
            rmAddRandomTradeRouteWaypoints(tradeRoute1ID, 0.28, 0.62, 5, 7);
            rmAddRandomTradeRouteWaypoints(tradeRoute1ID, 0.38, 1.0, 5, 7);
	   }
	   else
	   {
            rmAddTradeRouteWaypoint(tradeRoute1ID, 0.0, 0.42);
            rmAddRandomTradeRouteWaypoints(tradeRoute1ID, 0.32, 0.62, 5, 7);
            rmAddRandomTradeRouteWaypoints(tradeRoute1ID, 0.39, 1.0, 5, 7);
	   }
	}
   }
   bool placedTradeRoute1 = rmBuildTradeRoute(tradeRoute1ID, "dirt");
   if(placedTradeRoute1 == false)
 	rmEchoError("Failed to place trade route one");

   // add the meeting sockets along the trade route.
   rmSetObjectDefTradeRouteID(socketID, tradeRoute1ID);
   if (cNumberTeams == 2)
   {
      vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRoute1ID, 0.22);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
      if (cNumberNonGaiaPlayers > 3)
      {
         socketLoc1 = rmGetTradeRouteWayPoint(tradeRoute1ID, 0.5);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
      }
      socketLoc1 = rmGetTradeRouteWayPoint(tradeRoute1ID, 0.78);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
   }
   else
   {
      socketLoc1 = rmGetTradeRouteWayPoint(tradeRoute1ID, 0.22);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
      if (cNumberNonGaiaPlayers > 3)
      {
         socketLoc1 = rmGetTradeRouteWayPoint(tradeRoute1ID, 0.57);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
      }
      socketLoc1 = rmGetTradeRouteWayPoint(tradeRoute1ID, 0.92);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
   }

   int tradeRoute2ID = rmCreateTradeRoute();
   if (deltaPositionChance == 1)
   {
      if (cNumberTeams > 2)
	{
	   rmAddTradeRouteWaypoint(tradeRoute2ID, 1.0, 0.58);
         rmAddRandomTradeRouteWaypoints(tradeRoute2ID, 0.66, 0.38, 5, 7);
	   rmAddRandomTradeRouteWaypoints(tradeRoute2ID, 0.61, 0.18, 3, 3);
	}
	else
	{
	   if (cNumberNonGaiaPlayers < 4)
	   {
            rmAddTradeRouteWaypoint(tradeRoute2ID, 1.0, 0.55);
            rmAddRandomTradeRouteWaypoints(tradeRoute2ID, 0.72, 0.38, 5, 7);
            rmAddRandomTradeRouteWaypoints(tradeRoute2ID, 0.62, 0.0, 5, 7);
	   }
         else
 	   {
            rmAddTradeRouteWaypoint(tradeRoute2ID, 1.0, 0.58);
            rmAddRandomTradeRouteWaypoints(tradeRoute2ID, 0.68, 0.38, 5, 7);
            rmAddRandomTradeRouteWaypoints(tradeRoute2ID, 0.61, 0.0, 5, 7);
	   }
	}
   }
   else
   {
      if (cNumberTeams > 2)
	{
         rmAddTradeRouteWaypoint(tradeRoute2ID, 1.0, 0.42);
         rmAddRandomTradeRouteWaypoints(tradeRoute2ID, 0.66, 0.62, 5, 7);
	   rmAddRandomTradeRouteWaypoints(tradeRoute2ID, 0.61, 0.82, 3, 3);
	}
	else
	{
	   if (cNumberNonGaiaPlayers < 4)
	   {
            rmAddTradeRouteWaypoint(tradeRoute2ID, 1.0, 0.45);
            rmAddRandomTradeRouteWaypoints(tradeRoute2ID, 0.72, 0.62, 5, 7);
            rmAddRandomTradeRouteWaypoints(tradeRoute2ID, 0.62, 1.0, 5, 7);
	   }
	   else
	   {
            rmAddTradeRouteWaypoint(tradeRoute2ID, 1.0, 0.42);
            rmAddRandomTradeRouteWaypoints(tradeRoute2ID, 0.68, 0.62, 5, 7);
            rmAddRandomTradeRouteWaypoints(tradeRoute2ID, 0.61, 1.0, 5, 7);
	   }
	}
   }
   bool placedTradeRoute2 = rmBuildTradeRoute(tradeRoute2ID, "dirt");
   if(placedTradeRoute2 == false)
	rmEchoError("Failed to place trade route 2");

   // add the meeting sockets along the trade route.
   rmSetObjectDefTradeRouteID(socketID, tradeRoute2ID);
   if (cNumberTeams == 2)
   {
      vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRoute2ID, 0.22);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
      if (cNumberNonGaiaPlayers > 3)
      {
         socketLoc2 = rmGetTradeRouteWayPoint(tradeRoute2ID, 0.5);
	   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
      }
      socketLoc2 = rmGetTradeRouteWayPoint(tradeRoute2ID, 0.85);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
   }
   else
   {
      socketLoc2 = rmGetTradeRouteWayPoint(tradeRoute2ID, 0.22);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
      if (cNumberNonGaiaPlayers > 3)
      {
         socketLoc2 = rmGetTradeRouteWayPoint(tradeRoute2ID, 0.57);
	   rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
      }
      socketLoc2 = rmGetTradeRouteWayPoint(tradeRoute2ID, 0.92);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
   }

// Text
   rmSetStatusText("",0.40);

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

// Native villages
   // Village A 
   int villageAID = -1;
   int whichNative = rmRandInt(1,2);
   int villageType = rmRandInt(1,5);
   if (whichNative == 1)
	villageAID = rmCreateGrouping("village A", native1Name+villageType);
   else if (whichNative == 2)
	villageAID = rmCreateGrouping("village A", native2Name+villageType);
   rmAddGroupingToClass(villageAID, rmClassID("natives"));
   rmAddGroupingToClass(villageAID, rmClassID("importantItem"));
   rmSetGroupingMinDistance(villageAID, 0.0);
   rmSetGroupingMaxDistance(villageAID, rmXFractionToMeters(0.08));
   rmAddGroupingConstraint(villageAID, avoidImpassableLand);
   rmAddGroupingConstraint(villageAID, avoidTradeRoute);
   rmAddGroupingConstraint(villageAID, avoidWater15);
   rmAddGroupingConstraint(villageAID, playerConstraint);
   if (deltaPositionChance == 1)
   {
      if (riverOption == 1)
         rmPlaceGroupingAtLoc(villageAID, 0, 0.22, 0.74);
      else
         rmPlaceGroupingAtLoc(villageAID, 0, 0.21, 0.78);
   }
   else
   {
      if (riverOption == 1)
         rmPlaceGroupingAtLoc(villageAID, 0, 0.22, 0.26);
      else
         rmPlaceGroupingAtLoc(villageAID, 0, 0.21, 0.22);
   }

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
   rmSetGroupingMaxDistance(villageBID, rmXFractionToMeters(0.08));
   rmAddGroupingConstraint(villageBID, avoidImpassableLand);
   rmAddGroupingConstraint(villageBID, avoidTradeRoute);
   rmAddGroupingConstraint(villageBID, avoidWater15);
   rmAddGroupingConstraint(villageBID, avoidNatives);
   rmAddGroupingConstraint(villageBID, playerConstraint);
   if (deltaPositionChance == 1)
   {
      if (riverOption == 1)
         rmPlaceGroupingAtLoc(villageBID, 0, 0.78, 0.74);
      else
	   rmPlaceGroupingAtLoc(villageBID, 0, 0.79, 0.78);
   }
   else
   {
      if (riverOption == 1)
         rmPlaceGroupingAtLoc(villageBID, 0, 0.79, 0.26);
      else
         rmPlaceGroupingAtLoc(villageBID, 0, 0.79, 0.22);
   }

	
   if (cNumberNonGaiaPlayers > 3)
   {
      if (deltaPositionChance == 1)
      {
	   if (rmRandInt(1,2) == 1)
	      rmPlaceGroupingAtLoc(villageBID, 0, 0.5, 0.92);
	   else
	      rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.92);
      }
	else
      {
	   if (rmRandInt(1,2) == 1)
	      rmPlaceGroupingAtLoc(villageBID, 0, 0.5, 0.08);
	   else
	      rmPlaceGroupingAtLoc(villageAID, 0, 0.5, 0.08);
      }
   }

   // Text
   rmSetStatusText("",0.50);

// Starting Unit placement 
   int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
   rmSetObjectDefMinDistance(startingUnits, 5.0);
   rmSetObjectDefMaxDistance(startingUnits, 10.0);
   if (( teamZeroCount >= teamOneCount * 2 ) || ( teamOneCount >= teamZeroCount * 2 ))
   {
	rmSetObjectDefMaxDistance(startingUnits, 16.0);
   }
   rmAddObjectDefToClass(startingUnits, rmClassID("startingUnit"));
   rmAddObjectDefConstraint(startingUnits, avoidAll);
   rmAddObjectDefConstraint(startingUnits, avoidWater8);
   rmAddObjectDefConstraint(startingUnits, avoidTradeRoute);

   int startingTCID= rmCreateObjectDef("startingTC");
   if ( rmGetNomadStart())
   {
	rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 0.0);
   }
   else
   {
  	rmAddObjectDefItem(startingTCID, "TownCenter", 1, 0.0);
   }
   rmAddObjectDefToClass(startingTCID, rmClassID("startingUnit"));
   rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);
   if (( teamZeroCount >= teamOneCount * 2 ) || ( teamOneCount >= teamZeroCount * 2 ))
   {
	rmSetObjectDefMinDistance(startingTCID, 0.0);
	rmSetObjectDefMaxDistance(startingTCID, 10.0);
   }

   int StartAreaTreeID=rmCreateObjectDef("starting trees");
   rmAddObjectDefItem(StartAreaTreeID, treeType, 1, 0.0);
   rmSetObjectDefMinDistance(StartAreaTreeID, 10.0);
   rmSetObjectDefMaxDistance(StartAreaTreeID, 15.0);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidStartingUnitsSmall);
   
   int StartDeerID=rmCreateObjectDef("starting deer");
   rmAddObjectDefItem(StartDeerID, deerType, 1, 0.0);
   rmSetObjectDefMinDistance(StartDeerID, 10.0);
   rmSetObjectDefMaxDistance(StartDeerID, 15.0);
   rmAddObjectDefConstraint(StartDeerID, avoidStartingUnitsSmall);

   int silverType = rmRandInt(1,10);
   int playerGoldID = -1;

   int waterFlagID = -1;

   for(i=1; <cNumberPlayers)
   {
	// Place starting units and a TC!
	rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

	// Everyone gets two ore groupings, one pretty close, the other a little further away.
	silverType = rmRandInt(1,10);
	playerGoldID = rmCreateObjectDef("player silver closer "+i);
	rmAddObjectDefItem(playerGoldID, "mine", 1, 0.0);
      rmAddObjectDefToClass(playerGoldID, rmClassID("allMines"));
	rmAddObjectDefConstraint(playerGoldID, avoidTradeRoute);
	rmAddObjectDefConstraint(playerGoldID, avoidStartingUnitsSmall);
	rmAddObjectDefConstraint(playerGoldID, avoidWater8);
	rmSetObjectDefMinDistance(playerGoldID, 15.0);
	rmSetObjectDefMaxDistance(playerGoldID, 20.0);
	rmPlaceObjectDefAtLoc(playerGoldID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

	rmSetObjectDefMinDistance(playerGoldID, 35.0);
	rmSetObjectDefMaxDistance(playerGoldID, 45.0);
	rmPlaceObjectDefAtLoc(playerGoldID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

	// Placing starting huntables...
	rmPlaceObjectDefAtLoc(StartDeerID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(StartDeerID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(StartDeerID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(StartDeerID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		
	// Placing starting trees...
	rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

	// Water flag
	waterFlagID=rmCreateObjectDef("HC water flag "+i);
	rmAddObjectDefItem(waterFlagID, "HomeCityWaterSpawnFlag", 1, 0.0);
	rmAddClosestPointConstraint(flagVsFlag);
	rmAddClosestPointConstraint(flagLand);
	rmAddClosestPointConstraint(flagCircleConstraint);		
	vector TCLocation = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
      vector closestPoint = rmFindClosestPointVector(TCLocation, rmXFractionToMeters(1.0));

	rmPlaceObjectDefAtLoc(waterFlagID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
	rmClearClosestPointConstraints();
   }

   // Text
   rmSetStatusText("",0.60);

// berry bushes
   int StartBerryBushID=rmCreateObjectDef("starting berry bush");
   rmAddObjectDefItem(StartBerryBushID, "BerryBush", rmRandInt(3,5), 4.0);
   rmSetObjectDefMinDistance(StartBerryBushID, 10.0);
   rmSetObjectDefMaxDistance(StartBerryBushID, 16.0);
   rmAddObjectDefConstraint(StartBerryBushID, avoidStartingUnitsSmall);
   rmAddObjectDefConstraint(StartBerryBushID, avoidAll);
   rmAddObjectDefConstraint(StartBerryBushID, avoidWater8);
   if (placeBerries == 1)
      rmPlaceObjectDefPerPlayer(StartBerryBushID, false, 1);

// More mines
   silverType = rmRandInt(1,10);
   int silverID = rmCreateObjectDef("silver "+i);
   rmAddObjectDefItem(silverID, "mine", 1, 0.0);
   rmAddObjectDefToClass(silverID, rmClassID("allMines"));
   rmSetObjectDefMinDistance(silverID, 50.0);
   rmSetObjectDefMaxDistance(silverID, 75.0);
   rmAddObjectDefConstraint(silverID, avoidFastCoin);
   rmAddObjectDefConstraint(silverID, avoidAll);
   rmAddObjectDefConstraint(silverID, avoidWater8);
   rmAddObjectDefConstraint(silverID, avoidImpassableLand);
   rmAddObjectDefConstraint(silverID, avoidTradeRoute);
   rmAddObjectDefConstraint(silverID, avoidStartingUnits);
   rmPlaceObjectDefPerPlayer(silverID, false, 1);

   silverType = rmRandInt(1,10);
   int extraGoldID = rmCreateObjectDef("extra silver "+i);
   if (rmRandInt(1,2) == 1)
      rmAddObjectDefItem(extraGoldID, "minegold", 1, 0);
   else
      rmAddObjectDefItem(extraGoldID, "mine", 1, 0.0);
   rmAddObjectDefToClass(extraGoldID, rmClassID("importantItem"));
   rmAddObjectDefToClass(extraGoldID, rmClassID("allMines"));
   rmAddObjectDefConstraint(extraGoldID, avoidTradeRoute);
   rmAddObjectDefConstraint(extraGoldID, avoidSocket);
   rmAddObjectDefConstraint(extraGoldID, avoidMineLong);
   rmAddObjectDefConstraint(extraGoldID, avoidImportantItemSmall);
   rmAddObjectDefConstraint(extraGoldID, avoidWater8);
   rmAddObjectDefConstraint(extraGoldID, avoidAll);
   rmSetObjectDefMinDistance(extraGoldID, 0.0);
   rmSetObjectDefMaxDistance(extraGoldID, rmXFractionToMeters(0.32));

   if (deltaPositionChance == 1)
   {
      rmAddObjectDefConstraint(extraGoldID, Northward);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.4, 0.92, cNumberNonGaiaPlayers);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.6, 0.92, cNumberNonGaiaPlayers);
   }
   else
   {
      rmAddObjectDefConstraint(extraGoldID, Southward);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.4, 0.08, cNumberNonGaiaPlayers);
      rmPlaceObjectDefAtLoc(extraGoldID, 0, 0.6, 0.08, cNumberNonGaiaPlayers);
   }

   // Text
   rmSetStatusText("",0.70);

// FORESTS
   int numTries=11*cNumberNonGaiaPlayers;
   if (cNumberNonGaiaPlayers > 2)
	numTries=9*cNumberNonGaiaPlayers;
   if (cNumberNonGaiaPlayers > 4)
	numTries=8*cNumberNonGaiaPlayers;
   if (cNumberNonGaiaPlayers > 6)
	numTries=7*cNumberNonGaiaPlayers;
   int failCount=0;
   int coverForestPatchID = 0;
   for (i=0; <numTries)
   {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(170), rmAreaTilesToFraction(300));
	   rmSetAreaForestType(forest, forestType);
         rmSetAreaForestDensity(forest, 0.8);
         rmSetAreaCoherence(forest, 0.6);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
         rmAddAreaConstraint(forest, forestConstraint);
         rmAddAreaConstraint(forest, avoidAll);
         rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
         rmAddAreaConstraint(forest, avoidTradeRoute); 
	   rmAddAreaConstraint(forest, avoidStartingUnits); 
         if(rmBuildArea(forest)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount++;
            if(failCount==5)
               break;
         }
         else
            failCount=0; 
	   if (forestPatch == 1)
	   {
            coverForestPatchID = rmCreateArea("cover forest patch"+i, rmAreaID("forest "+i));   
            rmSetAreaWarnFailure(coverForestPatchID, false);
            rmSetAreaSize(coverForestPatchID, rmAreaTilesToFraction(340), rmAreaTilesToFraction(340));
            rmSetAreaCoherence(coverForestPatchID, 0.99);
		if (patternChance == 14)
	         rmSetAreaTerrainType(coverForestPatchID, "amazon\ground4_ama");
		else
		   rmSetAreaMix(coverForestPatchID, baseType);
	      rmBuildArea(coverForestPatchID);
	   }
   } 

// Patches using terrains
   if (terrainPatches == 1)
   {
      for (i=0; <cNumberNonGaiaPlayers*12)   
      {
	   int dirtPatch=rmCreateArea("smaller dirt patch "+i);
         rmSetAreaWarnFailure(dirtPatch, false);
	   if (rmRandInt(1,2) == 1)
	   {
	      rmSetAreaSize(dirtPatch, rmAreaTilesToFraction(40), rmAreaTilesToFraction(100));
	      rmSetAreaMinBlobs(dirtPatch, 2);
	      rmSetAreaMaxBlobs(dirtPatch, 4);
	      rmSetAreaMinBlobDistance(dirtPatch, 8.0);
	      rmSetAreaMaxBlobDistance(dirtPatch, 15.0);
	   }
	   else
	   {
	      rmSetAreaSize(dirtPatch, rmAreaTilesToFraction(90), rmAreaTilesToFraction(150));
	      rmSetAreaMinBlobs(dirtPatch, 3);
	      rmSetAreaMaxBlobs(dirtPatch, 5);
	      rmSetAreaMinBlobDistance(dirtPatch, 12.0);
	      rmSetAreaMaxBlobDistance(dirtPatch, 25.0);
	   }
         if (rmRandInt(1,2) == 1)
	      rmSetAreaTerrainType(dirtPatch, terrainPatchType);
	   else
	      rmSetAreaTerrainType(dirtPatch, terrainPatch2Type);
	   rmAddAreaToClass(dirtPatch, rmClassID("classPatch"));
	   rmSetAreaCoherence(dirtPatch, 0.2);
	   rmAddAreaConstraint(dirtPatch, shortAvoidImpassableLand);
	   rmAddAreaConstraint(dirtPatch, patchConstraint);
	   rmAddAreaConstraint(dirtPatch, shortForestConstraint);
	   rmBuildArea(dirtPatch);
	} 
   }

// Patches using mixes
   if (specialPatch == 1)
   {
      for (i=0; <cNumberNonGaiaPlayers*5)   
      {
	   int colorPatch=rmCreateArea("color patch "+i);
	   rmSetAreaWarnFailure(colorPatch, false);
	   rmSetAreaSize(colorPatch, rmAreaTilesToFraction(150), rmAreaTilesToFraction(200));
         rmSetAreaMix(colorPatch, patchMixType);
	   rmAddAreaToClass(colorPatch, rmClassID("classPatch"));
	   rmSetAreaMinBlobs(colorPatch, 1);
	   rmSetAreaMaxBlobs(colorPatch, 5);
	   rmSetAreaMinBlobDistance(colorPatch, 16.0);
	   rmSetAreaMaxBlobDistance(colorPatch, 36.0);
	   rmSetAreaCoherence(colorPatch, 0.1);
	   rmAddAreaConstraint(colorPatch, shortAvoidImpassableLand);
	   rmAddAreaConstraint(colorPatch, patchConstraint);
	   rmAddAreaConstraint(colorPatch, avoidWater15);
	   rmAddAreaConstraint(colorPatch, shortForestConstraint);
	   rmBuildArea(colorPatch); 
      }

      for (i=0; <cNumberNonGaiaPlayers*7)   
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
	   rmAddAreaConstraint(colorPatch2, shortAvoidImpassableLand);
	   rmAddAreaConstraint(colorPatch2, patchConstraint);
	   rmAddAreaConstraint(colorPatch2, avoidWater8);
	   rmAddAreaConstraint(colorPatch2, shortForestConstraint);
	   rmBuildArea(colorPatch2); 
      }
   }

   // Text
   rmSetStatusText("",0.80);

// Define and place Nuggets
   int nuggetID= rmCreateObjectDef("nugget"); 
   rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0);
   rmSetObjectDefMinDistance(nuggetID, 0.0);
   rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(nuggetID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nuggetID, avoidNugget);
   rmAddObjectDefConstraint(nuggetID, avoidTradeRoute);
   rmAddObjectDefConstraint(nuggetID, avoidAll);
   rmAddObjectDefConstraint(nuggetID, avoidWater20);
   rmAddObjectDefConstraint(nuggetID, circleConstraint);
   rmAddObjectDefConstraint(nuggetID, avoidStartingUnits);
   rmSetNuggetDifficulty(1, 2);
   rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);

// Domestic animals
   int sheepID=rmCreateObjectDef("herdable animal");
   rmAddObjectDefItem(sheepID, sheepType, 2, 4.0);
   rmAddObjectDefToClass(sheepID, rmClassID("herdableFood"));
   rmSetObjectDefMinDistance(sheepID, 38.0);
   rmSetObjectDefMaxDistance(sheepID, 50.0);
   rmAddObjectDefConstraint(sheepID, avoidSheep);
   rmAddObjectDefConstraint(sheepID, avoidAll);
   rmAddObjectDefConstraint(sheepID, playerConstraint);
   rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
   if (sheepChance > 0)
      rmPlaceObjectDefPerPlayer(sheepID, false, 1);

   rmSetObjectDefMinDistance(sheepID, 50.0);
   rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.3));
   if (sheepChance > 0)
      rmPlaceObjectDefPerPlayer(sheepID, false, 2);

// Huntables
   int huntable1ID=rmCreateObjectDef("first herd");
   rmAddObjectDefItem(huntable1ID, deerType, rmRandInt(5,7), 8.0);
   rmAddObjectDefToClass(huntable1ID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(huntable1ID, 0.0);
   rmSetObjectDefMaxDistance(huntable1ID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(huntable1ID, avoidAll);
   rmAddObjectDefConstraint(huntable1ID, huntableConstraint);
   rmAddObjectDefConstraint(huntable1ID, avoidImpassableLand);
   rmAddObjectDefConstraint(huntable1ID, avoidStartingUnits);
   rmSetObjectDefCreateHerd(huntable1ID, true);
   rmPlaceObjectDefAtLoc(huntable1ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);

   int huntable2ID=rmCreateObjectDef("second herd");
   rmAddObjectDefItem(huntable2ID, deer2Type, rmRandInt(4,7), 8.0);
   rmAddObjectDefToClass(huntable2ID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(huntable2ID, 0.0);
   rmSetObjectDefMaxDistance(huntable2ID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(huntable2ID, huntableConstraint);
   rmAddObjectDefConstraint(huntable2ID, avoidAll);
   rmAddObjectDefConstraint(huntable2ID, avoidImpassableLand);
   rmAddObjectDefConstraint(huntable2ID, avoidStartingUnits);
   rmSetObjectDefCreateHerd(huntable2ID, true);
   rmPlaceObjectDefAtLoc(huntable2ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

   // Text
   rmSetStatusText("",0.90);

// Extra huntables on the remote part of the map
   int herdNum = rmRandInt(3,4);
   if (cNumberNonGaiaPlayers > 4)
	herdNum = rmRandInt(4,5);
   if (cNumberNonGaiaPlayers > 6)
	herdNum = 6;
   int huntable3ID=rmCreateObjectDef("third herd");
   rmAddObjectDefItem(huntable3ID, extraHerdType, rmRandInt(5,7), 8.0);
   rmAddObjectDefToClass(huntable3ID, rmClassID("huntableFood"));
   rmSetObjectDefMinDistance(huntable3ID, 0.0);
   rmSetObjectDefMaxDistance(huntable3ID, rmXFractionToMeters(0.42));
   if ( cNumberNonGaiaPlayers > 4 )
      huntableConstraint=rmCreateClassDistanceConstraint("huntable constraint longer", rmClassID("huntableFood"), 40.0);
   rmAddObjectDefConstraint(huntable3ID, huntableConstraint);
   rmAddObjectDefConstraint(huntable3ID, avoidAll);
   rmAddObjectDefConstraint(huntable3ID, avoidImpassableLand);
   rmSetObjectDefCreateHerd(huntable3ID, true);
   if (deltaPositionChance == 1)
   {
	rmAddObjectDefConstraint(huntable3ID, Northward);
      rmPlaceObjectDefAtLoc(huntable3ID, 0, 0.5, 0.95, herdNum);
   }
   else
   {
	rmAddObjectDefConstraint(huntable3ID, Southward);
      rmPlaceObjectDefAtLoc(huntable3ID, 0, 0.5, 0.05, herdNum);
   }

// High-level reward nuggets on the remote part of the map.
   int nuggetWestID= rmCreateObjectDef("nugget west"); 
   rmAddObjectDefItem(nuggetWestID, "Nugget", 1, 0.0);
   rmSetObjectDefMinDistance(nuggetWestID, 0.0);
   rmSetObjectDefMaxDistance(nuggetWestID, rmXFractionToMeters(0.42));
   rmAddObjectDefConstraint(nuggetWestID, avoidAll);
   rmAddObjectDefConstraint(nuggetWestID, avoidNugget);
   rmAddObjectDefConstraint(nuggetWestID, circleConstraint);
   rmAddObjectDefConstraint(nuggetWestID, avoidImpassableLand);
   rmSetNuggetDifficulty(3, 4);
   if (deltaPositionChance == 1)
   {
	rmAddObjectDefConstraint(nuggetWestID, Northward);
      rmPlaceObjectDefAtLoc(nuggetWestID, 0, 0.5, 0.95, cNumberNonGaiaPlayers);   
   }
   else
   {
      rmAddObjectDefConstraint(nuggetWestID, Southward);
      rmPlaceObjectDefAtLoc(nuggetWestID, 0, 0.5, 0.05, cNumberNonGaiaPlayers);
   }
   rmSetNuggetDifficulty(2, 2);
   if (deltaPositionChance == 1)
   {
	rmAddObjectDefConstraint(nuggetWestID, Northward);
      rmPlaceObjectDefAtLoc(nuggetWestID, 0, 0.5, 0.95, 2);   
   }
   else
   {
      rmAddObjectDefConstraint(nuggetWestID, Southward);
      rmPlaceObjectDefAtLoc(nuggetWestID, 0, 0.5, 0.05, 2);
   }

// Extra sheep on the remote part of the map
   int sheepNum = rmRandInt(1,3);
   if (cNumberNonGaiaPlayers > 4)
	sheepNum = rmRandInt(3,4);
   if (cNumberNonGaiaPlayers > 6)
	sheepNum = rmRandInt(4,5);
   if (sheepChance > 0)
   {
      rmSetObjectDefMinDistance(sheepID, 10.0);
      rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.48));
      if (deltaPositionChance == 1)
      {
	   rmAddObjectDefConstraint(sheepID, Northward);
         rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.9, sheepNum);
      }
      else
      {
	   rmAddObjectDefConstraint(sheepID, Southward);
         rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.1, sheepNum);
      }
   }

// Extra berries on the remote part of the map
   int berryNum = rmRandInt(2,3);
   if (cNumberNonGaiaPlayers > 4)
	berryNum = rmRandInt(3,5);
   if (cNumberNonGaiaPlayers > 6)
	berryNum = rmRandInt(4,6);
   rmAddObjectDefConstraint(StartBerryBushID, avoidBerryID);
   rmSetObjectDefMinDistance(StartBerryBushID, 0.0);
   rmSetObjectDefMaxDistance(StartBerryBushID, rmXFractionToMeters(0.4));
   if (placeBerries == 1)
   {
      if (deltaPositionChance == 1)
      {
	   rmAddObjectDefConstraint(StartBerryBushID, Northward);
         rmPlaceObjectDefAtLoc(StartBerryBushID, 0, 0.5, 0.95, berryNum);
      }
      else
      {
   	   rmAddObjectDefConstraint(StartBerryBushID, Southward);
         rmPlaceObjectDefAtLoc(StartBerryBushID, 0, 0.5, 0.05, berryNum);
      }
   }

// Fish
   int fishID=rmCreateObjectDef("fish");
   rmAddObjectDefItem(fishID, fishType, 3, 9.0);
   rmSetObjectDefMinDistance(fishID, 0.0);
   rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.48));
   rmAddObjectDefConstraint(fishID, fishVsFishID);
   rmAddObjectDefConstraint(fishID, fishLand);
   rmAddObjectDefConstraint(fishID, circleConstraint);
   rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);
   if (cNumberNonGaiaPlayers < 4)
      rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

   // Text
   rmSetStatusText("",1.0);


  // King of the Hill (added 2026-11 for WoL): the middle of the start positions is on the river: a patch of land is laid across it there (as TAD's Acre and Orinoco do), so the hill sits on a crossing
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
    // a patch of land laid there first (the start point is on water)
    ypKingsHillLandfill(kothX, kothZ, 0.015, 1.0, baseType, 0);
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
