// One hook on the tail of the ModifyType name parser FUN_005F5645 (0x5FE6D7), shared by every key
// that adds a name to <ModifyType>: a single jmp, whichever of those keys are on.
#pragma once

#include <cstdint>

namespace uhc {

// Makes `name` (static text; case ignored, like every stock name) read as `stat`. The stock stats
// are 0..8 and 0Bh..0Eh; the keys use 40h and up. Writes the hook the first time, after checking
// the stock bytes.
bool AddModifyType(const wchar_t* name, std::int32_t stat);

}  // namespace uhc
