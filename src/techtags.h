// New child tags of a <Tech> in the techtree: one hook on the tech parser's loop over the tree's nodes (0x61FDB8),
// shared by every key that reads one and by dataLint, which names the tech an effect belongs to.
#pragma once

namespace uhc {

// `node` is each node of the techtree's root (a <Tech>, or a comment), as the parser takes it.
using TechNodeObserver = void (*)(const char* node);

// `techName` is the <Tech>'s name attribute (empty if it has none), `text` the child's text (may be null).
using TechTagHandler = void (*)(const char* techNode, const wchar_t* techName, const wchar_t* text);

// Calls `observer` for every node the parser takes, before it reads it. Writes the hook the first time, after
// checking the stock bytes.
bool OnTechNode(TechNodeObserver observer);

// Makes each child element of a <Tech> named `name` (static text, case ignored) reach `handler`, in file order,
// before the parser reads that tech. The stock parser does not know the tag and reads past it.
bool AddTechTagHandler(const char* name, TechTagHandler handler);

}  // namespace uhc
