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

Outcome ApplyRemoveConversionRestriction(const Config& config);
Outcome ApplyIgnoreRegistryPath(const Config& config);
Outcome ApplyDeckCardCount(const Config& config);
Outcome ApplyPopLimit(const Config& config);
Outcome ApplyNoAiLimit(const Config& config);
Outcome ApplyCustomRevolutionBanners(const Config& config);
Outcome ApplyRemoveFameRestriction(const Config& config);
Outcome ApplyHcShipmentPointFallback(const Config& config);
Outcome ApplyHealNonIdle(const Config& config);
Outcome ApplyDamageOverTime(const Config& config);
Outcome ApplyDodge(const Config& config);
Outcome ApplyLiveBuildingWorkRate(const Config& config);
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
Outcome ApplyTransformInventory(const Config& config);
Outcome ApplyNoTrainNearEnemyTc(const Config& config);
Outcome ApplyOverhealHitpointBars(const Config& config);
Outcome ApplyShowGatherRate(const Config& config);
Outcome ApplyBuildingWorkRateAuras(const Config& config);
Outcome ApplyPerfStats(const Config& config);
Outcome ApplyFileIo(const Config& config);
Outcome ApplyMultipleInstances(const Config& config);

inline constexpr Feature kFeatures[] = {
    {"removeConversionRestriction", ApplyRemoveConversionRestriction},
    {"ignoreRegistryPath", ApplyIgnoreRegistryPath},
    {"deckCardCount", ApplyDeckCardCount},
    {"basePop/extraPop", ApplyPopLimit},
    {"noAILimit", ApplyNoAiLimit},
    {"customRevolutionBanners", ApplyCustomRevolutionBanners},
    {"removeFameRestriction", ApplyRemoveFameRestriction},
    {"hcShipmentPointFallback", ApplyHcShipmentPointFallback},
    {"healNonIdle", ApplyHealNonIdle},
    {"damageOverTime", ApplyDamageOverTime},
    {"dodgeAnyUnit/dodgeSoundSet/criticalSoundSet", ApplyDodge},
    {"liveBuildingWorkRate", ApplyLiveBuildingWorkRate},
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
    {"techRenameEffect/enableTechRenameEffect", ApplyTechRenameEffect},
    {"noCorpseDopples", ApplyNoCorpseDopples},
    {"danceBonusCivs", ApplyDanceBonusCivs},
    {"startingTC", ApplyStartingTc},
    {"transformInventory", ApplyTransformInventory},
    // After liveBuildingWorkRate, which verifies the stock bytes of the site this one hooks.
    {"noTrainNearEnemyTC", ApplyNoTrainNearEnemyTc},
    {"overhealHitpointBars", ApplyOverhealHitpointBars},
    {"showGatherRate", ApplyShowGatherRate},
    // Last of the WoL keys: it redirects the four calls of the BuildingWorkRate getter, which
    // liveBuildingWorkRate and noTrainNearEnemyTC verify as stock bytes.
    {"buildingWorkRateAuras", ApplyBuildingWorkRateAuras},
    {"perfStats/perfAutoExec", ApplyPerfStats},
    {"bufferedFileReads/perfFileLog", ApplyFileIo},
    {"multipleInstances", ApplyMultipleInstances},
};

// Lowercase cfg keys read by the features above; any other key is logged as not implemented.
inline constexpr const char* kHandledKeys[] = {
    "removeconversionrestriction", "ignoreregistrypath", "deckcardcount", "basepop", "extrapop",
    "noailimit", "customrevolutionbanners", "removefamerestriction", "hcshipmentpointfallback",
    "healnonidle", "damageovertime", "dodgeanyunit", "dodgesoundset", "criticalsoundset",
    "livebuildingworkrate", "techprereqrecheck", "maintainwaitforpop", "transformupdateslos",
    "broadsidemuzzlelimit", "abilityslots", "wonderpanelskipauras", "lifespanafterconstruction",
    "gaiasocketsonly", "customhotkeycontexts", "snareonlyhitunit", "techrenameeffect",
    "enabletechrenameeffect", "nocorpsedopples", "dancebonuscivs", "startingtc",
    "transforminventory", "notrainnearenemytc", "overhealhitpointbars", "showgatherrate",
    "buildingworkrateauras", "perfstats", "perfautoexec", "perfexecfile", "bufferedfilereads",
    "perffilelog", "multipleinstances",
};

}  // namespace uhc
