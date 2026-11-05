// Tags of a <civ> in civs.xml that stock does not know: one hook on the parser's unknown-tag path,
// shared by every key that reads one (civFirstTC's <firstTC>, sharedBuildLimit's <SettlerProtoName>).
#pragma once

#include <cstdint>

namespace uhc {

// `civ` is the civ object being filled (+8 its ID), `text` the element's text (may be null).
using CivTagHandler = void (*)(const char* civ, std::int32_t civId, const wchar_t* text);

// Makes a <civ> child element named `name` (case ignored) reach `handler`. Writes the hook the
// first time, after checking the stock bytes. The parse runs after UHCMain, so every tag is seen.
bool AddCivTagHandler(const char* name, CivTagHandler handler);

}  // namespace uhc
