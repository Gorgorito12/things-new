// New formatText data refs, the {name} a UI layout's text can hold. The game resolves a {name} by name in one table
// that its parser's registration fills once (FUN_005CFA7C, called from the parser's constructor at 0x5D3229); the
// evaluators take entries[id], and the table's check wants each id to equal its index. This module redirects that
// call: the stock registration runs, then each added ref is appended with the next id. Shared: a key adds its refs
// here, never a second write at 0x5D3229 (docs/engine-symbols.md, "Unit panels").
#pragma once

#include <cstdint>

namespace uhc {

// The value a provider fills: the evaluator sets `type` to the ref's registered type first, then calls the
// provider; type 1 is a float at +4, 2 an int at +4, 3 a BString (one wchar_t*) at +4. The provider returns false
// when it has no value (the text then shows nothing). During the call [0C6DF7Ch] points to a BString holding the
// whole token, "{name(arg)}" (lowercased, seen in game): the stock providers take what is between the first "(" and
// the next ")" (0x453F8F, strchr 28h / 29h, e.g. for {resource(food)}), and an added one does the same.
struct DataRefValue {
  std::int32_t type;
  union {
    float real;
    std::int32_t integer;
    wchar_t* text;  // type 3: a BString; assign it with BStringAssign (0x443BB8)
  };
};
using DataRefProvider = bool(__stdcall*)(DataRefValue* value);

inline constexpr std::int32_t kDataRefFloat = 1;
inline constexpr std::int32_t kDataRefInt = 2;
inline constexpr std::int32_t kDataRefString = 3;

// Adds {name} (copied; ASCII letters and digits) with that type and provider. Installs the redirect on first use;
// false if the host bytes do not match, the name is already added, or the game's table was already built.
bool AddDataRef(const wchar_t* name, std::int32_t type, DataRefProvider provider);

}  // namespace uhc
