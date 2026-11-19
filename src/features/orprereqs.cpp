// orPrereqsQty: <Flag qty="N">OrPrereqs</Flag> makes a tech available when at least N of its prerequisites are
// met, instead of one.
//
// Stock reads <Flag>OrPrereqs</Flag> into bit 21 of the tech's status bits (the flag setter's case 0x62237E), and
// the prerequisite list evaluator FUN_005094B4 (bool thiscall(list = def+1Ch, Player*, bool or), ret 8) then ORs
// the prerequisites instead of ANDing them: the first one met returns true. Its only stock caller is the per-tech
// update 0x509537, which caches the result in status bit 3; techPrereqRecheck calls it too.
//
// The key redirects the tech tag table's <Flag> handler (the immediate of its registration, 0x6237E8) to
// UhcOrQtyFlag, which runs the stock handler and then reads qty="N" of an OrPrereqs flag into a table by tech ID
// (the setup 0x6201E5 stores the ID in [def+0] and the def in [record+0]). A jmp at the evaluator's head
// (hooks/orprereqs_hooks.asm) asks UhcOrQtyEval first: for an OR list whose tech has N >= 2 it counts the
// prerequisites met through their vtable slot +8, as stock calls them, and returns true from the N-th one;
// anything else goes on to the stock code.
#include <windows.h>

#include <charconv>
#include <cstdint>
#include <map>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
constexpr std::uint32_t kStockFlagHandler = 0x00620BF1;
constexpr std::uint32_t kFlagRegisterImm = 0x006237E8;  // the immediate of mov dword ptr [esp+10h], 620BF1h
constexpr int kMaxQty = 255;  // the list's length is a byte
constexpr int kMaxLines = 40;
constexpr int kMaxEvalLines = 200;

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
using FlagHandlerFn = bool(__cdecl*)(const char* node, char* record);
const auto kFlagHandler = reinterpret_cast<FlagHandlerFn>(kStockFlagHandler);
using PrereqMetFn = bool(__thiscall*)(const char* prereq, char* player);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Qty {
  const char* def = nullptr;  // the tech's definition when qty was read, to tell a stale entry
  std::uint8_t qty = 0;
};

std::vector<Qty> g_qty;  // by tech ID
int g_techs = 0;         // with a qty, in this data load
bool g_log = false;
bool g_listed = false;  // the techs were listed (once per data load, at the first evaluation)
int g_lines = 0;
int g_evalLines = 0;
std::map<std::uint32_t, int> g_lastMet;  // "log": (player << 24 | tech ID) -> prerequisites met at the last evaluation

const wchar_t* TechName(std::int32_t id) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (database == nullptr) {
    return L"?";
  }
  const wchar_t* const* names = Field<const wchar_t* const*>(database, 0x3824);
  if (names == nullptr || id < 0 || id >= Field<std::int32_t>(database, 0x3828) || names[id] == nullptr) {
    return L"?";
  }
  return names[id];
}

int PrereqCount(const char* def) {
  const char* const* list = Field<const char* const*>(def, 0x1C);
  const std::uint8_t length = Field<std::uint8_t>(def, 0x20);
  int count = 0;
  for (std::uint8_t i = 0; list != nullptr && i < length; ++i) {
    count += list[i] != nullptr ? 1 : 0;
  }
  return count;
}

// Once per data load, at the first evaluation, when every tech's prerequisites are read.
void ListTechs() {
  g_listed = true;
  uhc::Log(L"orPrereqsQty: %d tech(s) with qty on OrPrereqs", g_techs);
  int listed = 0;
  int never = 0;
  for (std::size_t id = 0; id < g_qty.size(); ++id) {
    const Qty& entry = g_qty[id];
    if (entry.def == nullptr || entry.qty == 0) {
      continue;
    }
    const int count = PrereqCount(entry.def);
    if (entry.qty > count) {
      ++never;
    }
    if (listed++ < kMaxLines) {
      uhc::Log(L"orPrereqsQty:   tech %u (%ls): %u of %d prerequisite(s)%ls", static_cast<unsigned>(id),
               TechName(static_cast<std::int32_t>(id)), entry.qty, count,
               entry.qty > count ? L"; more than it has, so never met" : L"");
    }
  }
  if (listed > kMaxLines) {
    uhc::Log(L"orPrereqsQty:   and %d more", listed - kMaxLines);
  }
  if (never > 0) {
    uhc::Log(L"orPrereqsQty: %d tech(s) ask more prerequisites than they have and are never available", never);
  }
}

bool ParseQty(const char* text, int* qty) {
  if (text == nullptr) {
    return false;
  }
  while (*text == ' ') {
    ++text;
  }
  const char* last = text + std::strlen(text);
  while (last > text && last[-1] == ' ') {
    --last;
  }
  int value = 0;
  const auto [end, error] = std::from_chars(text, last, value);
  if (error != std::errc() || end != last || value < 1 || value > kMaxQty) {
    return false;
  }
  *qty = value;
  return true;
}

}  // namespace

extern "C" {

void UhcOrQtyEvalHook();  // hooks/orprereqs_hooks.asm

// The tech tag table's <Flag> handler while the techtree is read: cdecl(node, record), like the stock one.
bool __cdecl UhcOrQtyFlag(const char* node, char* record) {
  const bool result = kFlagHandler(node, record);
  if (!result || node == nullptr || record == nullptr) {
    return result;
  }
  const void* attribute = nullptr;
  if (!kXmlAttribute(node, "qty", &attribute) || attribute == nullptr) {
    return result;
  }
  const char* flag = kXmlText(node + 0x14);
  const char* def = Field<const char*>(record, 0x00);
  const std::int32_t id = def == nullptr ? -1 : Field<std::int32_t>(def, 0x00);
  const char* text = kXmlText(attribute);
  if (flag == nullptr || _stricmp(flag, "OrPrereqs") != 0) {
    if (g_lines++ < kMaxLines) {
      uhc::Log(L"orPrereqsQty: tech %d (%ls): qty on <Flag>%hs</Flag> ignored; it belongs on OrPrereqs", id,
               TechName(id), flag == nullptr ? "" : flag);
    }
    return result;
  }
  int qty = 0;
  if (id < 0 || id > 0xFFFFF || !ParseQty(text, &qty)) {
    if (g_lines++ < kMaxLines) {
      uhc::Log(L"orPrereqsQty: tech %d (%ls): qty=\"%hs\" is not a whole number from 1 to %d; ignored", id,
               TechName(id), text == nullptr ? "" : text, kMaxQty);
    }
    return result;
  }
  if (static_cast<std::size_t>(id) >= g_qty.size()) {
    g_qty.resize(static_cast<std::size_t>(id) + 1);
  }
  if (g_qty[id].def != def) {
    ++g_techs;
  }
  g_qty[id] = {def, static_cast<std::uint8_t>(qty)};
  g_listed = false;
  return result;
}

// From the evaluator's head: list = ECX (def+1Ch), the player, and the OR flag (its low byte, as stock reads it).
// Returns 0 or 1 for a tech with qty >= 2 and the OR flag; -1 lets the stock code evaluate the list.
std::int32_t __stdcall UhcOrQtyEval(const char* list, char* player, std::uint32_t orFlag) {
  if ((orFlag & 0xFF) == 0 || list == nullptr || g_qty.empty()) {
    return -1;
  }
  const char* def = list - 0x1C;
  const std::int32_t id = Field<std::int32_t>(def, 0x00);
  if (id < 0 || static_cast<std::size_t>(id) >= g_qty.size() || g_qty[id].def != def || g_qty[id].qty < 2) {
    return -1;
  }
  if (!g_listed) {
    ListTechs();
  }
  const int qty = g_qty[id].qty;
  const char* const* items = Field<const char* const*>(list, 0x00);
  const std::uint8_t length = Field<std::uint8_t>(list, 0x04);
  int met = 0;
  for (std::uint8_t i = 0; items != nullptr && i < length && met < qty; ++i) {
    const char* prereq = items[i];
    if (prereq == nullptr) {
      continue;
    }
    const auto metFn = reinterpret_cast<PrereqMetFn>(Field<const void* const*>(prereq, 0x00)[2]);
    if (metFn(prereq, player)) {
      ++met;
    }
  }
  if (g_log && g_evalLines < kMaxEvalLines) {
    // Only a change: techPrereqRecheck may evaluate the same list on every world update.
    const std::int32_t playerId = player == nullptr ? -1 : Field<std::int32_t>(player, 0x00);
    const std::uint32_t key = (static_cast<std::uint32_t>(playerId & 0xFF) << 24) | static_cast<std::uint32_t>(id);
    const auto last = g_lastMet.find(key);
    if (last == g_lastMet.end() || last->second != met) {
      g_lastMet[key] = met;
      ++g_evalLines;
      uhc::Log(L"orPrereqsQty: player %d, tech %d (%ls): %d of %d needed met%ls%ls", playerId, id, TechName(id),
               met, qty, met >= qty ? L": available" : L": not yet",
               g_evalLines == kMaxEvalLines ? L" (no more changes are logged)" : L"");
    }
  }
  return met >= qty ? 1 : 0;
}
}

namespace uhc {

Outcome ApplyOrPrereqsQty(const Config& config) {
  const Config::Args* args = config.First("orPrereqsQty");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"orPrereqsQty: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  // techPrereqRecheck verifies the evaluator's head before this key writes it.
  if (!VerifyAll("orPrereqsQty", {&sites::kOrQtyEvalHead, &sites::kOrQtyEvalTrue, &sites::kOrQtyVtableThunk,
                                  &sites::kOrQtyFlagHandler, &sites::kOrQtyFlagRegister, &sites::kOrQtyFlagBit,
                                  &sites::kOrQtyTechSetup, &sites::kTechPrereqListLoop,
                                  &sites::kTechPrereqEntryUpdate})) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!WriteDword(kFlagRegisterImm, reinterpret_cast<std::uint32_t>(&UhcOrQtyFlag)) ||
      !WriteJmp(sites::kOrQtyEvalHead.va, reinterpret_cast<const void*>(&UhcOrQtyEvalHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"orPrereqsQty: <Flag qty=\"N\">OrPrereqs</Flag> needs N of the tech's prerequisites%ls (multiplayer "
      L"unverified)",
      log ? L"; each change of a tech's count is logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
