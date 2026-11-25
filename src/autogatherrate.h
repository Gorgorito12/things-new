// One hook on the head of the AutoGather rate getter 0x49EBE4 (float thiscall(unitAction, resource), ret 4), shared
// by every key that multiplies an AutoGather rate (autoGatherScaleByContained, nurseryFactor): a single jmp,
// whichever of those keys are on. Every reader of the rate goes through the getter: the AutoGather update
// FUN_0048D13E (the pay) and the rate rows of both unit panels (0x6992BD, 0x69B005).
#pragma once

#include <cstdint>

namespace uhc {

// Asked before the stock body runs, in the order the keys added them (their kFeatures order). `unitAction` is the
// unit's AutoGather action ([+4] its tactics action, [+10h] the unit). Returns false to leave the rate alone, or
// true after multiplying *factor (1 on entry) by its own factor. When no filter returns true the stock getter runs
// unchanged, bit for bit; otherwise the hook runs the stock body and multiplies its result by the product.
using AutoGatherRateFilter = bool (*)(const char* unitAction, std::int32_t resource, float* factor);

// Writes the hook the first time (after checking the site's stock bytes) and adds filter.
bool AddAutoGatherRateFilter(const char* name, AutoGatherRateFilter filter);

}  // namespace uhc
