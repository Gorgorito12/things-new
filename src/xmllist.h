// Small readers for the name-list files in data\uhc (customabstracttypes.xml,
// customprotounitcommands.xml): a root element holding one element per name, e.g.
//   <AbstractTypes><AbstractType stringId="430103">AbstractLightCavalry</AbstractType></AbstractTypes>
// Comments are skipped; tag names match in any case.
#pragma once

#include <deque>
#include <string>

namespace uhc {

struct XmlListEntry {
  std::string name;
  int stringId = -1;  // the stringId attribute, -1 when absent
};

// Resolves `arg` (or `defaultPath` when empty) against the exe's folder unless it is absolute,
// and reads the file (at most 4 MB). Returns false if it cannot be read; *path is set either way.
bool ReadDataListFile(const std::string& arg, const wchar_t* defaultName, std::wstring* path, std::string* text);

// The <tag> elements of `text` (tag in lowercase, without '<'), in file order. An element whose
// name is empty or not made of letters, digits and '_' (at most 100 chars) counts in *bad.
std::deque<XmlListEntry> ParseXmlList(const std::string& text, const std::string& tag, int* bad);

}  // namespace uhc
