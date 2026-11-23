// New child tags of a <card> in a home city file (homecity<civ>.xml): one hook on the home city loader's commit of
// each card (the call 0x630017 of the append to the home city's card array hc+204h), shared by every key that reads
// one (resendableCards' <resendeveryage>). The stock loader reads past a tag it does not know.
#pragma once

#include <cstdint>

namespace uhc {

// `hc` is the home city being loaded, `card` the card just added to its card array (a record of 28h bytes: +0 the
// tech ID, +4 <maxcount>, +18h <age>, +20h the sends left in a game, byte +24h <infiniteinlastage>; the game's card
// list of a player, hc+228h, is built from these records by copying them), `text` the tag's text (may be null).
using CardTagHandler = void (*)(char* hc, char* card, const wchar_t* text);

// Makes each child element of a <card> named `name` (static text, case ignored) reach `handler`, once the card is in
// the home city's array. Writes the hook the first time, after checking the stock bytes.
bool AddCardTagHandler(const char* feature, const char* name, CardTagHandler handler);

}  // namespace uhc
