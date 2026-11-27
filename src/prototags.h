// New tags inside a proto's <Unit>: one hook on the tail of the tag table's builder, shared by every
// key that adds a tag.
#pragma once

namespace uhc {

// The stock handler convention. `node` is the tag's XML node (its text, a BString, is at +14h), `proto`
// the base proto being read. Return true; false stops reading that proto.
using ProtoTagHandler = bool(__cdecl*)(void* context, const char* node, char* proto);

// Registers <name> (static text). Call it from a feature's apply function: the table is built later,
// during the game's startup. Writes the hook the first time, after checking the stock bytes.
bool AddProtoTagHandler(const char* name, ProtoTagHandler handler);

}  // namespace uhc
