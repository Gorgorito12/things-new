#include "actiontags.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

namespace {

constexpr std::size_t kMaxHandlers = 4;
// Return address of the parser's call by the <ProtoAction> handler; the hook passes only that one
// and 0x5FA623, the tactics <action> creator's (docs/engine-symbols.md, "Damage and poison").
constexpr std::uint32_t kFromProtoAction = 0x005FA213;

uhc::ActionTagHandler g_handlers[kMaxHandlers] = {};
std::size_t g_handlerCount = 0;
bool g_installed = false;

}  // namespace

extern "C" {
void UhcActionTagHook();  // hooks/actiontag_hooks.asm

// From the hook, for each child of an action the stock parser does not know. tag is the address of
// the child's tag-name BString (its UTF-16 text is *tag); the child's text is at [node+14h].
void __stdcall UhcActionTag(const wchar_t* const* tag, const char* node, const char* proto, const char* action,
                            std::uint32_t returnAddress) {
  if (tag == nullptr || *tag == nullptr || node == nullptr || proto == nullptr || action == nullptr) {
    return;
  }
  const uhc::ActionTag child{*tag, *reinterpret_cast<const wchar_t* const*>(node + 0x14), proto, action,
                             returnAddress == kFromProtoAction ? uhc::ActionSource::kProtoAction
                                                               : uhc::ActionSource::kTactics};
  for (std::size_t i = 0; i < g_handlerCount; ++i) {
    g_handlers[i](child);
  }
}
}

namespace uhc {

bool AddActionTagHandler(ActionTagHandler handler) {
  if (g_handlerCount == kMaxHandlers) {
    Log(L"action tags: more than %u handlers", static_cast<unsigned>(kMaxHandlers));
    return false;
  }
  if (!g_installed) {
    // test eax,eax / je 5FD4EDh at 0x5FA11E; the hook re-executes them. Its two callers' return
    // addresses are checked as well, since the hook tells them apart by those.
    if (!VerifyAll("action tags", {&sites::kDotProtoActionTag, &sites::kDotProtoActionCall,
                                   &sites::kTacticsActionCall}) ||
        !WriteJmp(0x005FA11E, reinterpret_cast<const void*>(&UhcActionTagHook), 8)) {
      return false;
    }
    g_installed = true;
  }
  g_handlers[g_handlerCount++] = handler;
  return true;
}

}  // namespace uhc
