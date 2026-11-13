// Feature registry: one entry per uhc.cfg key (or key group), applied in a fixed order.
#pragma once

#include <cstddef>

#include "config.h"

namespace uhc {

enum class Outcome { kNotConfigured, kApplied, kFailed };

struct Feature {
  const char* name;
  Outcome (*apply)(const Config& config);
};

Outcome ApplyCustomAbstractTypes(const Config& config);
Outcome ApplyRemoveConversionRestriction(const Config& config);
Outcome ApplyIgnoreRegistryPath(const Config& config);
Outcome ApplyDeckCardCount(const Config& config);
Outcome ApplyPopLimit(const Config& config);
Outcome ApplyDecimalPopulation(const Config& config);
Outcome ApplyNoAiLimit(const Config& config);
Outcome ApplyCustomRevolutionBanners(const Config& config);
Outcome ApplyRemoveFameRestriction(const Config& config);
Outcome ApplyHcShipmentPointFallback(const Config& config);
Outcome ApplyHealNonIdle(const Config& config);
Outcome ApplySmartHealTargets(const Config& config);
Outcome ApplyDamageOverTime(const Config& config);
Outcome ApplyDodge(const Config& config);
Outcome ApplySpreadAnyAccuracy(const Config& config);
Outcome ApplyLiveBuildingWorkRate(const Config& config);
Outcome ApplyWorkRateByAbstractType(const Config& config);
Outcome ApplyAutoGatherScaleByContained(const Config& config);
Outcome ApplyContainedUnitsROF(const Config& config);
Outcome ApplyNumberOfShots(const Config& config);
Outcome ApplyUnitResourceAuras(const Config& config);
Outcome ApplyResourceGatherAuras(const Config& config);
Outcome ApplyResourceDebt(const Config& config);
Outcome ApplyCostEscalationTechs(const Config& config);
Outcome ApplyTrainBatchSize(const Config& config);
Outcome ApplyPillageGold(const Config& config);
Outcome ApplyVeterancyBonus(const Config& config);
Outcome ApplyHcTargetTechs(const Config& config);
Outcome ApplyDetonationDeath(const Config& config);
Outcome ApplyAnnexFacing(const Config& config);
Outcome ApplyAccuracyTechs(const Config& config);
Outcome ApplyCratePriority(const Config& config);
Outcome ApplySharedBuildLimit(const Config& config);
Outcome ApplyDisplayedRange(const Config& config);
Outcome ApplyLinkedResource(const Config& config);
Outcome ApplyUnitTypeTechs(const Config& config);
Outcome ApplyAuraStacking(const Config& config);
Outcome ApplyDataLint(const Config& config);
Outcome ApplyDoNotQueue(const Config& config);
Outcome ApplyNextResearchFree(const Config& config);
Outcome ApplyResearchGrants(const Config& config);
Outcome ApplyKillBountyTechs(const Config& config);
Outcome ApplyTeamKillBounty(const Config& config);
Outcome ApplyResourceBounty(const Config& config);
Outcome ApplyCantBeSlowed(const Config& config);
Outcome ApplyStealthTargeting(const Config& config);
Outcome ApplyCustomWalls(const Config& config);
Outcome ApplyDirectionalAttack(const Config& config);
Outcome ApplySnareValues(const Config& config);
Outcome ApplyTechPrereqRecheck(const Config& config);
Outcome ApplyMaintainWaitForPop(const Config& config);
Outcome ApplyTransformUpdatesLos(const Config& config);
Outcome ApplyBroadsideMuzzleLimit(const Config& config);
Outcome ApplyAbilitySlots(const Config& config);
Outcome ApplyWonderPanelSkipAuras(const Config& config);
Outcome ApplyNativePreview(const Config& config);
Outcome ApplyLifespanAfterConstruction(const Config& config);
Outcome ApplyGaiaSocketsOnly(const Config& config);
Outcome ApplyCustomHotkeyContexts(const Config& config);
Outcome ApplySnareOnlyHitUnit(const Config& config);
Outcome ApplyTechRenameEffect(const Config& config);
Outcome ApplyNoCorpseDopples(const Config& config);
Outcome ApplyDanceBonusCivs(const Config& config);
Outcome ApplyStartingTc(const Config& config);
Outcome ApplyCivFirstTc(const Config& config);
Outcome ApplyTransformInventory(const Config& config);
Outcome ApplyTransformSpan(const Config& config);
Outcome ApplyNoTrainNearEnemyTc(const Config& config);
Outcome ApplyOverhealHitpointBars(const Config& config);
Outcome ApplyOverhealSources(const Config& config);
Outcome ApplyOverhealDecay(const Config& config);
Outcome ApplySteadyHitpointBars(const Config& config);
Outcome ApplyInventoryBars(const Config& config);
Outcome ApplyShowGatherRate(const Config& config);
Outcome ApplyBuildingWorkRateAuras(const Config& config);
Outcome ApplyRendererOption(const Config& config);
Outcome ApplyPerfStats(const Config& config);
Outcome ApplyFileIo(const Config& config);
Outcome ApplyFastVertexFill(const Config& config);
// True once fastVertexFill replaced the cloth flags' fill loops in this run (applied, not `verify`). rendererOption
// reads it when the game calls Direct3DCreate9, after every key has applied.
bool FastVertexFillActive();
Outcome ApplyFastLastInLine(const Config& config);
Outcome ApplyXsErrorLog(const Config& config);
Outcome ApplyMultipleInstances(const Config& config);
Outcome ApplyPlugins(const Config& config);
Outcome ApplyAsianCivs(const Config& config);
Outcome ApplyTwoScoutCivs(const Config& config);
Outcome ApplyMarketUnits(const Config& config);
Outcome ApplyExplorerUnits(const Config& config);
Outcome ApplyNativeCivs(const Config& config);
Outcome ApplyBigButton(const Config& config);
Outcome ApplyAgeUpBuildings(const Config& config);
Outcome ApplyFarmAnim(const Config& config);
Outcome ApplyFarmingRadius(const Config& config);
Outcome ApplyWonderCivUnitType(const Config& config);
Outcome ApplyTrainSingleAbstractType(const Config& config);
Outcome ApplyKbUnitSyscalls(const Config& config);
Outcome ApplyCustomProtoUnitCommands(const Config& config);
Outcome ApplyMultiArmor(const Config& config);
Outcome ApplyBetterFreeDynamicUnit(const Config& config);
Outcome ApplyNoWalkFarm(const Config& config);
Outcome ApplyRepairWallGlobal(const Config& config);
Outcome ApplyCompatMode(const Config& config);
Outcome ApplyGatherFix(const Config& config);
Outcome ApplyRofFix(const Config& config);
Outcome ApplyStunMovingTargetFix(const Config& config);
Outcome ApplyNoDamageOnUnbuiltFoundations(const Config& config);
Outcome ApplyFallenHeroTacticsFix(const Config& config);
Outcome ApplyImpactBoneFix(const Config& config);
Outcome ApplyCustomImpactTypes(const Config& config);
// dance.cpp: the four fire pit dance gates, shared by danceBonusCivs and nativeCivs.
bool InstallDanceGates(const char* feature);
bool AddDanceCivs(const std::vector<std::string>& names, const char* feature);
// Puts FirstTC first in hcShipmentPointFallback's list, and installs its hook if the key is off. For firstTC,
// which applies after that key.
bool AddFirstTcShipmentPoint();
Outcome ApplySelectionLimit(const Config& config);
Outcome ApplyEnableAllTeams(const Config& config);

// menuOptions is not in this list: ApplyFeatures applies it before the first key (menuoptions.h), since it decides
// which of the keys it names the list then sees.
inline constexpr Feature kFeatures[] = {
    // First: its types get their IDs before any other feature requests one.
    {"customAbstractTypes", ApplyCustomAbstractTypes},
    {"removeConversionRestriction", ApplyRemoveConversionRestriction},
    {"ignoreRegistryPath", ApplyIgnoreRegistryPath},
    {"deckCardCount", ApplyDeckCardCount},
    {"basePop/extraPop", ApplyPopLimit},
    // After basePop/extraPop: it scales their cap hook, and installs it when they did not.
    {"decimalPopulation", ApplyDecimalPopulation},
    {"noAILimit/noAILimitV2", ApplyNoAiLimit},
    {"customRevolutionBanners", ApplyCustomRevolutionBanners},
    {"removeFameRestriction", ApplyRemoveFameRestriction},
    {"hcShipmentPointFallback", ApplyHcShipmentPointFallback},
    {"healNonIdle", ApplyHealNonIdle},
    {"smartHealTargets", ApplySmartHealTargets},
    {"damageOverTime", ApplyDamageOverTime},
    {"dodgeAnyUnit/dodgeChance/dodgeSoundSet/criticalSoundSet", ApplyDodge},
    // After damageOverTime: both read action tags through the shared hook (actiontags.h), in this order.
    {"spreadAnyAccuracy", ApplySpreadAnyAccuracy},
    {"liveBuildingWorkRate", ApplyLiveBuildingWorkRate},
    {"workRateByAbstractType", ApplyWorkRateByAbstractType},
    {"autoGatherScaleByContained", ApplyAutoGatherScaleByContained},
    {"containedUnitsROF", ApplyContainedUnitsROF},
    // After containedUnitsROF: its filter on the shared ROF reads (rofreads.h) runs on that key's result.
    {"numberOfShots", ApplyNumberOfShots},
    {"unitResourceAuras", ApplyUnitResourceAuras},
    {"displayedRange", ApplyDisplayedRange},
    {"costEscalationTechs", ApplyCostEscalationTechs},
    {"unitTypeTechs", ApplyUnitTypeTechs},
    {"trainBatchSize", ApplyTrainBatchSize},
    {"pillageGold", ApplyPillageGold},
    {"veterancyBonus", ApplyVeterancyBonus},
    {"hcTargetTechs", ApplyHcTargetTechs},
    {"accuracyTechs", ApplyAccuracyTechs},
    {"cratePriority", ApplyCratePriority},
    {"sharedBuildLimit", ApplySharedBuildLimit},
    {"doNotQueue", ApplyDoNotQueue},
    {"nextResearchFree", ApplyNextResearchFree},
    // After nextResearchFree: a research it makes free is not asked of this key (the shared payment, researchpay.h).
    {"researchGrants", ApplyResearchGrants},
    {"killBountyTechs", ApplyKillBountyTechs},
    {"teamKillBounty", ApplyTeamKillBounty},
    {"resourceBounty", ApplyResourceBounty},
    {"techPrereqRecheck", ApplyTechPrereqRecheck},
    {"maintainWaitForPop", ApplyMaintainWaitForPop},
    {"transformUpdatesLOS", ApplyTransformUpdatesLos},
    {"broadsideMuzzleLimit", ApplyBroadsideMuzzleLimit},
    {"abilitySlots", ApplyAbilitySlots},
    {"wonderPanelSkipAuras", ApplyWonderPanelSkipAuras},
    {"nativePreview", ApplyNativePreview},
    {"lifespanAfterConstruction", ApplyLifespanAfterConstruction},
    {"gaiaSocketsOnly", ApplyGaiaSocketsOnly},
    {"customHotkeyContexts", ApplyCustomHotkeyContexts},
    {"snareOnlyHitUnit", ApplySnareOnlyHitUnit},
    // After damageOverTime and snareOnlyHitUnit: both verify the stock bytes of the site it writes.
    {"cantBeSlowed", ApplyCantBeSlowed},
    // After cantBeSlowed: its hook continues at the push this key writes.
    {"snareValues", ApplySnareValues},
    {"stealthTargeting", ApplyStealthTargeting},
    {"customWalls", ApplyCustomWalls},
    {"directionalAttack", ApplyDirectionalAttack},
    {"techRenameEffect/enableTechRenameEffect", ApplyTechRenameEffect},
    {"noCorpseDopples", ApplyNoCorpseDopples},
    {"danceBonusCivs", ApplyDanceBonusCivs},
    {"asianCivs", ApplyAsianCivs},
    {"twoScoutCivs", ApplyTwoScoutCivs},
    {"marketUnits", ApplyMarketUnits},
    {"explorerUnits", ApplyExplorerUnits},
    // After danceBonusCivs: it adds its civs to the dance gates that key installs.
    {"nativeCivs", ApplyNativeCivs},
    {"bigButtonCivs/noBigButtonBlds", ApplyBigButton},
    {"ageUpBuildings", ApplyAgeUpBuildings},
    {"enableFarmAnim/enableRectFarmAnim", ApplyFarmAnim},
    // After enableFarmAnim: its indices count that key's entries.
    {"farmingRadius", ApplyFarmingRadius},
    {"wonderCivUnitType", ApplyWonderCivUnitType},
    {"trainSingleAbstractType", ApplyTrainSingleAbstractType},
    {"kbUnitSyscalls", ApplyKbUnitSyscalls},
    {"customProtoUnitCommands", ApplyCustomProtoUnitCommands},
    {"multiarmor", ApplyMultiArmor},
    {"betterfreedynamicunit", ApplyBetterFreeDynamicUnit},
    {"nowalkfarm", ApplyNoWalkFarm},
    {"repairWallGlobal", ApplyRepairWallGlobal},
    {"compatMode", ApplyCompatMode},
    {"gatherFix", ApplyGatherFix},
    {"rofFix", ApplyRofFix},
    {"stunMovingTargetFix", ApplyStunMovingTargetFix},
    {"noDamageOnUnbuiltFoundations", ApplyNoDamageOnUnbuiltFoundations},
    {"fallenHeroTacticsFix", ApplyFallenHeroTacticsFix},
    {"impactBoneFix", ApplyImpactBoneFix},
    {"customImpactTypes", ApplyCustomImpactTypes},
    {"selectionLimit", ApplySelectionLimit},
    {"enableAllTeams", ApplyEnableAllTeams},
    {"startingTC", ApplyStartingTc},
    // After startingTC: both use the FirstTC proto hook at 0x506B3B, which the first one writes.
    {"civFirstTC", ApplyCivFirstTc},
    {"transformInventory", ApplyTransformInventory},
    {"transformSpan", ApplyTransformSpan},
    // After liveBuildingWorkRate, which verifies the stock bytes of the site this one hooks.
    {"noTrainNearEnemyTC", ApplyNoTrainNearEnemyTc},
    {"overhealHitpointBars", ApplyOverhealHitpointBars},
    // After overhealHitpointBars, whose unit types and reference it uses.
    {"overhealSources", ApplyOverhealSources},
    // After overhealSources: they share the add-HP hook, which the first one writes.
    {"overhealDecay", ApplyOverhealDecay},
    // After overhealDecay: its threshold uses the same add-HP hook, and overhealSources verifies the
    // stock bytes of that entry.
    {"detonationDeath", ApplyDetonationDeath},
    // Shares the death observer (deathobservers.h) with detonationDeath; its observer runs after that one.
    {"annexFacing", ApplyAnnexFacing},
    {"steadyHitpointBars", ApplySteadyHitpointBars},
    // After overhealHitpointBars: both add bars through the shared floating bar hooks (floatingbars.h), the segment
    // first.
    {"inventoryBars", ApplyInventoryBars},
    {"showGatherRate", ApplyShowGatherRate},
    // After showGatherRate, which verifies the bytes of the call this key redirects.
    {"resourceGatherAuras", ApplyResourceGatherAuras},
    {"resourceDebt", ApplyResourceDebt},
    // After resourceDebt and the keys that verify the heads of the inventory add and the inventory recreate.
    {"linkedResource", ApplyLinkedResource},
    {"auraStacking", ApplyAuraStacking},
    // Last of the new keys: it redirects the four calls of the BuildingWorkRate getter, which
    // liveBuildingWorkRate and noTrainNearEnemyTC verify as stock bytes.
    {"buildingWorkRateAuras", ApplyBuildingWorkRateAuras},
    // After the keys that verify the sites it writes as stock bytes; before the plugins, as a plugin may read its log.
    {"dataLint", ApplyDataLint},
    // Before perfStats: it replaces the Direct3DCreate9 the game gets (d3d9hooks.h), which perfStats then observes.
    {"rendererOption", ApplyRendererOption},
    {"perfStats/perfAutoExec", ApplyPerfStats},
    {"bufferedFileReads/perfFileLog", ApplyFileIo},
    {"fastVertexFill", ApplyFastVertexFill},
    {"fastLastInLine", ApplyFastLastInLine},
    {"xsErrorLog", ApplyXsErrorLog},
    {"multipleInstances", ApplyMultipleInstances},
    // Last: plugins load once every other hook is in place.
    {"customSyscalls/customCheats", ApplyPlugins},
};

// Lowercase cfg keys read by the features above; any other key is logged as not implemented.
inline constexpr const char* kHandledKeys[] = {
    "customabstracttypes",
    "removeconversionrestriction", "ignoreregistrypath", "deckcardcount", "basepop", "extrapop",
    "decimalpopulation",
    "noailimit", "noailimitv2", "customrevolutionbanners", "removefamerestriction", "hcshipmentpointfallback",
    "healnonidle", "smarthealtargets", "damageovertime", "dodgeanyunit", "dodgechance",
    "dodgesoundset", "criticalsoundset", "spreadanyaccuracy",
    "livebuildingworkrate", "workratebyabstracttype", "autogatherscalebycontained", "containedunitsrof", "numberofshots", "unitresourceauras", "resourcegatherauras", "resourcedebt", "costescalationtechs", "trainbatchsize", "pillagegold", "accuracytechs", "cratepriority", "techprereqrecheck", "maintainwaitforpop", "transformupdateslos", "sharedbuildlimit", "donotqueue", "nextresearchfree", "researchgrants", "killbountytechs", "teamkillbounty", "resourcebounty", "cantbeslowed", "snarevalues", "stealthtargeting", "customwalls", "directionalattack", "transformspan", "veterancybonus", "hctargettechs", "detonationdeath", "annexfacing", "unittypetechs",
    "broadsidemuzzlelimit", "abilityslots", "wonderpanelskipauras", "nativepreview", "lifespanafterconstruction",
    "gaiasocketsonly", "customhotkeycontexts", "snareonlyhitunit", "techrenameeffect",
    "displayedrange", "linkedresource", "aurastacking", "enabletechrenameeffect", "nocorpsedopples", "dancebonuscivs", "startingtc", "civfirsttc", "firsttc",
    "transforminventory", "notrainnearenemytc", "overhealhitpointbars", "overhealsources", "overhealdecay", "steadyhitpointbars", "inventorybars", "showgatherrate",
    "buildingworkrateauras", "xserrorlog", "datalint", "menuoptions", "rendereroption", "perfstats", "perfautoexec", "perfexecfile", "bufferedfilereads", "fastvertexfill", "fastlastinline",
    "perffilelog", "multipleinstances", "customsyscalls", "customcheats", "asiancivs", "twoscoutcivs", "marketunits", "explorerunits", "nativecivs", "bigbuttoncivs", "nobigbuttonblds", "ageupbuildings", "enablefarmanim", "enablerectfarmanim", "farmingradius", "wondercivunittype", "trainsingleabstracttype", "selectionlimit", "enableallteams", "kbunitsyscalls", "customprotounitcommands", "multiarmor", "betterfreedynamicunit", "nowalkfarm", "repairwallglobal", "compatmode", "gatherfix", "roffix", "stunmovingtargetfix", "nodamageonunbuiltfoundations", "fallenherotacticsfix", "impactbonefix", "customimpacttypes",
};

}  // namespace uhc
