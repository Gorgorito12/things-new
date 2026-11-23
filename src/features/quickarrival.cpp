// quickArrivalCards [stringid N] [log]: <Flag>QuickArrival</Flag> on a home city card's tech adds the bullet line
// "This is a quick-arrival card." to the card's rollover, right after its send-limit line ("This Card may be sent
// INFINITE times" / "ONE time" / N times), before the advanced info. Display only.
//
// The card rollover builder FUN_007103CE(list, hc, tech, ...) is the one used by the in-game shipment panel
// (0x9A61B7), the deck builder of the home city screen (0x9A0714) and the deck dialog (0x9A7A1E), all three in list
// mode (its sixth argument 1). Its lines, in order: the name (header, FUN_004C5032), the population, the unit's own
// text when the tech has no rollover text, "This Card cannot be sent until Age N" (9012h), the cost, the tech's
// rollover text, the send-limit line (9001h/9002h/9003h), then, with the detailed help option on, the advanced info
// FUN_0071006D. Each line goes through FUN_004C5076(list, line, 1, 0), which appends "<ttf><ttb>" and the line: the
// bullet. The key's hook sits at the join before the advanced info (0x710909) and appends its line the same way.
//
// The flag is read through the shared flag reader hook (techflags.h); the techs are kept by ID.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../techflags.h"

extern "C" void UhcQuickArrivalHook();

namespace {

constexpr std::uint32_t kAdvancedJoin = 0x00710909;  // mov ecx,[0D6F6F0h]
constexpr std::int32_t kMaxTech = 1 << 20;
constexpr const wchar_t* kDefaultText = L"This is a quick-arrival card.";
constexpr const wchar_t* kBullet = L"<ttf><ttb>";  // what FUN_004C5076(list, line, 1, 0) puts before a line

// The engine's string: one pointer to a wide, reference-counted buffer; null is empty.
struct BString {
  wchar_t* text;
};
using AppendFn = void(__thiscall*)(void* text, const wchar_t* more, std::int32_t length, std::int32_t start);
const auto kAppend = reinterpret_cast<AppendFn>(0x00443960);  // BString append; -1, -1: all of it, at the end
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t stringId);
using BStringFreeFn = void(__thiscall*)(BString* self);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);

std::vector<bool> g_quick;  // by tech ID; filled while the techtree loads
std::int32_t g_stringId = -1;
bool g_log = false;
int g_logLines = 0;
bool g_loggedLine = false;

bool ReadFlag(char* record, const char* name) {
  if (_stricmp(name, "QuickArrival") != 0) {
    return false;
  }
  const char* def = *reinterpret_cast<const char* const*>(record);
  const std::int32_t tech = def == nullptr ? -1 : *reinterpret_cast<const std::int32_t*>(def);
  if (tech < 0 || tech >= kMaxTech) {
    return true;
  }
  if (static_cast<std::size_t>(tech) >= g_quick.size()) {
    g_quick.resize(static_cast<std::size_t>(tech) + 1, false);
  }
  g_quick[static_cast<std::size_t>(tech)] = true;
  if (g_log && g_logLines < 200) {
    ++g_logLines;
    uhc::Log(L"quickArrivalCards: tech %d has the QuickArrival flag", tech);
  }
  return true;
}

}  // namespace

// From the hook, once the card's send-limit line is in: `list` is the rollover being built, `tech` the card's tech
// ID, `listMode` the builder's sixth argument (1 in the three callers: one bulleted line per entry).
extern "C" void __stdcall UhcQuickArrivalLine(void* list, std::int32_t tech, std::uint32_t listMode) {
  if (list == nullptr || tech < 0 || static_cast<std::size_t>(tech) >= g_quick.size() ||
      !g_quick[static_cast<std::size_t>(tech)]) {
    return;
  }
  BString fromTable{nullptr};
  const wchar_t* text = kDefaultText;
  if (g_stringId >= 0) {
    kBStringFromId(&fromTable, g_stringId);
    if (fromTable.text != nullptr && fromTable.text[0] != 0) {
      text = fromTable.text;
    }
  }
  if ((listMode & 0xFF) != 0) {
    kAppend(list, kBullet, -1, -1);
  } else {
    kAppend(list, L"\n", -1, -1);  // the builder's string mode puts each line after a line break
  }
  kAppend(list, text, -1, -1);
  if (g_log && !g_loggedLine) {
    g_loggedLine = true;
    uhc::Log(L"quickArrivalCards: the line was added to the rollover of tech %d (logged once)", tech);
  }
  if (g_stringId >= 0) {
    kBStringFree(&fromTable);
  }
}

namespace uhc {

Outcome ApplyQuickArrivalCards(const Config& config) {
  const Config::Args* args = config.First("quickArrivalCards");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  std::int32_t stringId = -1;
  for (std::size_t i = 0; i < args->size(); ++i) {
    const std::string& arg = (*args)[i];
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (_stricmp(arg.c_str(), "stringid") == 0 && i + 1 < args->size()) {
      const std::string& value = (*args)[++i];
      char* end = nullptr;
      const long id = std::strtol(value.c_str(), &end, 10);
      if (value.empty() || *end != 0 || id < 0 || id > 0x7FFFFFFF) {
        Log(L"quickArrivalCards: stringid %hs is not a string ID (0 or more); feature not applied", value.c_str());
        return Outcome::kFailed;
      }
      stringId = static_cast<std::int32_t>(id);
    } else {
      Log(L"quickArrivalCards: unexpected argument %hs (expected: [stringid N] [log]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("quickArrivalCards", {&sites::kCardRolloverHead, &sites::kCardRolloverAdvanced,
                                       &sites::kCardBulletLine, &sites::kBStringAppend})) {
    return Outcome::kFailed;
  }
  g_log = log;
  g_stringId = stringId;
  if (!AddTechFlagHandler("quickArrivalCards", &ReadFlag) ||
      !WriteJmp(kAdvancedJoin, reinterpret_cast<const void*>(&UhcQuickArrivalHook), 6)) {
    return Outcome::kFailed;
  }
  if (stringId >= 0) {
    Log(L"quickArrivalCards: the tech flag QuickArrival adds the line of string %d to a card's rollover", stringId);
  } else {
    Log(L"quickArrivalCards: the tech flag QuickArrival adds the line \"%ls\" to a card's rollover", kDefaultText);
  }
  return Outcome::kApplied;
}

}  // namespace uhc
