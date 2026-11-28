// Tags of a <civ> in civs.xml that stock does not know: one hook on the parser's unknown-tag path,
// shared by every key that reads one (civFirstTC's <firstTC>, sharedBuildLimit's <SettlerProtoName>,
// killSpawn's <killSpawn...> tags, shipTechLimit's <ShipTechLimit>, partisans' <PartisanNearby> with its
// cooldown="..." attribute, and the old <PartisanCooldown>, read only to say it moved).
#pragma once

#include <cstdint>

namespace uhc {

// `civ` is the civ object being filled (+8 its ID), `text` the element's text (may be null).
using CivTagHandler = void (*)(const char* civ, std::int32_t civId, const wchar_t* text);

// Makes a <civ> child element named `name` (case ignored) reach `handler`. Writes the hook the
// first time, after checking the stock bytes. The parse runs after UHCMain, so every tag is seen.
bool AddCivTagHandler(const char* name, CivTagHandler handler);

// The same, with the element's XML node too, for a tag with attributes. The node is the one the parser walks, of the
// same class as a proto tag's node (+4 its name table, +14h its text, +18h its name's index): its attributes are read
// with the game's XML reader, 0x598F37 (the attribute by name) and 0x402733 (its text), as prototags.h's handlers do.
using CivTagNodeHandler = void (*)(const char* civ, std::int32_t civId, const char* node, const wchar_t* text);
bool AddCivTagNodeHandler(const char* name, CivTagNodeHandler handler);

}  // namespace uhc
