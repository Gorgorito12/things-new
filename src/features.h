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
Outcome ApplyUnitResourceAuras(const Config& config);
Outcome ApplyResourceGatherAuras(const Config& config);
Outcome ApplyResourceDebt(const Config& config);
Outcome ApplyCostEscalationTechs(const Config& config);
Outcome ApplyTrainBatchSize(const Config& config);
Outcome ApplyKillBountyTechs(const Config& config);
Outcome ApplyTeamKillBounty(const Config& config);
Outcome ApplyResourceBounty(const Config& config);
Outcome ApplyCantBeSlowed(const Config& config);
Outcome ApplyTechPrereqRecheck(const Config& config);
Outcome ApplyMaintainWaitForPop(const Config& config);
Outcome ApplyTransformUpdatesLos(const Config& config);
Outcome ApplyBroadsideMuzzleLimit(const Config& config);
Outcome ApplyAbilitySlots(const Config& config);
Outcome ApplyWonderPanelSkipAuras(const Config& config);
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
Outcome ApplyNoTrainNearEnemyTc(const Config& config);
Outcome ApplyOverhealHitpointBars(const Config& config);
Outcome ApplyOverhealSources(const Config& config);
Outcome ApplyOverhealDecay(const Config& config);
Outcome ApplyShowGatherRate(const Config& config);
Outcome ApplyBuildingWorkRateAuras(const Config& config);
Outcome ApplyPerfStats(const Config& config);
Outcome ApplyFileIo(const Config& config);
Outcome ApplyMultipleInstances(const Config& config);
Outcome ApplyPlugins(const Config& config);
Outcome ApplyAsianCivs(const Config& config);
Outcome ApplyTwoScoutCivs(const Config& config);
Outcome ApplyMarketUnits(const Config& config);
Outcome ApplyExplorerUnits(const Config& config);
Outcome ApplyNativeCivs(const Config& config);
Outcome ApplyBigButton(const Config& config);
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
// dance.cpp: the four fire pit dance gates, shared by danceBonusCivs and nativeCivs.
bool InstallDanceGates(const char* feature);
bool AddDanceCivs(const std::vector<std::string>& names, const char* feature);
Outcome ApplySelectionLimit(const Config& config);
Outcome ApplyEnableAllTeams(const Config& config);

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
    {"unitResourceAuras", ApplyUnitResourceAuras},
    {"costEscalationTechs", ApplyCostEscalationTechs},
    {"trainBatchSize", ApplyTrainBatchSize},
    {"killBountyTechs", ApplyKillBountyTechs},
    {"teamKillBounty", ApplyTeamKillBounty},
    {"resourceBounty", ApplyResourceBounty},
    {"techPrereqRecheck", ApplyTechPrereqRecheck},
    {"maintainWaitForPop", ApplyMaintainWaitForPop},
    {"transformUpdatesLOS", ApplyTransformUpdatesLos},
    {"broadsideMuzzleLimit", ApplyBroadsideMuzzleLimit},
    {"abilitySlots", ApplyAbilitySlots},
    {"wonderPanelSkipAuras", ApplyWonderPanelSkipAuras},
    {"lifespanAfterConstruction", ApplyLifespanAfterConstruction},
    {"gaiaSocketsOnly", ApplyGaiaSocketsOnly},
    {"customHotkeyContexts", ApplyCustomHotkeyContexts},
    {"snareOnlyHitUnit", ApplySnareOnlyHitUnit},
    // After damageOverTime and snareOnlyHitUnit: both verify the stock bytes of the site it writes.
    {"cantBeSlowed", ApplyCantBeSlowed},
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
    {"selectionLimit", ApplySelectionLimit},
    {"enableAllTeams", ApplyEnableAllTeams},
    {"startingTC", ApplyStartingTc},
    // After startingTC: both use the FirstTC proto hook at 0x506B3B, which the first one writes.
    {"civFirstTC", ApplyCivFirstTc},
    {"transformInventory", ApplyTransformInventory},
    // After liveBuildingWorkRate, which verifies the stock bytes of the site this one hooks.
    {"noTrainNearEnemyTC", ApplyNoTrainNearEnemyTc},
    {"overhealHitpointBars", ApplyOverhealHitpointBars},
    // After overhealHitpointBars, whose unit types and reference it uses.
    {"overhealSources", ApplyOverhealSources},
    // After overhealSources: they share the add-HP hook, which the first one writes.
    {"overhealDecay", ApplyOverhealDecay},
    {"showGatherRate", ApplyShowGatherRate},
    // After showGatherRate, which verifies the bytes of the call this key redirects.
    {"resourceGatherAuras", ApplyResourceGatherAuras},
    {"resourceDebt", ApplyResourceDebt},
    // Last of the new keys: it redirects the four calls of the BuildingWorkRate getter, which
    // liveBuildingWorkRate and noTrainNearEnemyTC verify as stock bytes.
    {"buildingWorkRateAuras", ApplyBuildingWorkRateAuras},
    {"perfStats/perfAutoExec", ApplyPerfStats},
    {"bufferedFileReads/perfFileLog", ApplyFileIo},
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
    "livebuildingworkrate", "workratebyabstracttype", "autogatherscalebycontained", "unitresourceauras", "resourcegatherauras", "resourcedebt", "costescalationtechs", "trainbatchsize", "killbountytechs", "teamkillbounty", "resourcebounty", "cantbeslowed", "techprereqrecheck", "maintainwaitforpop", "transformupdateslos",
    "broadsidemuzzlelimit", "abilityslots", "wonderpanelskipauras", "lifespanafterconstruction",
    "gaiasocketsonly", "customhotkeycontexts", "snareonlyhitunit", "techrenameeffect",
    "enabletechrenameeffect", "nocorpsedopples", "dancebonuscivs", "startingtc", "civfirsttc",
    "transforminventory", "notrainnearenemytc", "overhealhitpointbars", "overhealsources", "overhealdecay", "showgatherrate",
    "buildingworkrateauras", "perfstats", "perfautoexec", "perfexecfile", "bufferedfilereads",
    "perffilelog", "multipleinstances", "customsyscalls", "customcheats", "asiancivs", "twoscoutcivs", "marketunits", "explorerunits", "nativecivs", "bigbuttoncivs", "nobigbuttonblds", "enablefarmanim", "enablerectfarmanim", "farmingradius", "wondercivunittype", "trainsingleabstracttype", "selectionlimit", "enableallteams", "kbunitsyscalls", "customprotounitcommands", "multiarmor", "betterfreedynamicunit", "nowalkfarm", "repairwallglobal", "compatmode", "gatherfix", "roffix", "stunmovingtargetfix", "nodamageonunbuiltfoundations", "fallenherotacticsfix",
};

}  // namespace uhc
