// One hook on the unknown-tag fall-through of the action parser FUN_005F98A0 (0x5FA11E), shared by
// every key that reads extra action tags (damageOverTime, spreadAnyAccuracy): a single jmp,
// whichever of those keys are on. The parser reads both a protoy.xml <ProtoAction> and a .tactics
// file's <action>; stock ignores the tags it does not know.
#pragma once

#include <cstdint>

namespace uhc {

enum class ActionSource {
  kProtoAction,  // a <ProtoAction> of protoy.xml (the parser called from 0x5FA20E)
  kTactics,      // an <action> of a .tactics file (called from 0x5FA61E, FUN_005FA5B3)
};

// One child of an action that the stock parser does not know.
struct ActionTag {
  const wchar_t* name;  // the child's tag name, as written (compare case-insensitively)
  const wchar_t* text;  // its text; may be null or empty
  const char* proto;    // the proto whose action set holds the action: [proto+4] ID, [proto+10h] name
  const char* action;   // the action: [action+4] name index, -1 until the action's <Name> is read
  ActionSource source;
};

// Called for each such child while the data loads, in file order, by the handlers in the order the
// keys added them (their kFeatures order).
using ActionTagHandler = void (*)(const ActionTag& tag);

// Writes the hook the first time (after checking the sites' stock bytes) and adds handler.
bool AddActionTagHandler(ActionTagHandler handler);

}  // namespace uhc
