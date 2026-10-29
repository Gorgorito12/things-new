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
    {"perfStats/perfAutoExec", ApplyPerfStats},
    {"bufferedFileReads/perfFileLog", ApplyFileIo},
    {"multipleInstances", ApplyMultipleInstances},
};

// Lowercase cfg keys read by the features above; any other key is logged as not implemented.
inline constexpr const char* kHandledKeys[] = {
    "removeconversionrestriction", "ignoreregistrypath", "deckcardcount", "basepop", "extrapop",
    "noailimit", "customrevolutionbanners", "removefamerestriction", "hcshipmentpointfallback",
    "healnonidle", "damageovertime", "dodgeanyunit", "dodgesoundset", "criticalsoundset",
    "perfstats", "perfautoexec", "perfexecfile", "bufferedfilereads", "perffilelog",
    "multipleinstances",
};

}  // namespace uhc
