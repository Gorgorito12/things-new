// resendableCards: <resendeveryage>1</resendeveryage> in a home city card makes the card sendable again each time
// its player reaches a new age: its sends left go back to its <maxcount>, as stock does once for an
// <infiniteinlastage> card when the player reaches the Imperial Age.
//
// How stock counts a card's sends: the game's card list of a player (hc+228h, records of 28h built from the deck by
// FUN_006301DE) keeps the sends left in [card+20h], set to <maxcount> [card+4] when the list is built. The send
// FUN_0085A724 refuses a card with <maxcount> >= 0 and no sends left ("You have already sent %s", 8FFDh, 0x85A9B9)
// and takes one with FUN_0085FBEA(card, -1) (0x85ACF8); a cancel gives it back (+1, 0x85AE98); the shipment panel
// greys such a card (0x9A5AFC). The card's tech has the HomeCity flag, which the tech activation 0x94CF27 never
// refuses as already active, so the tech runs again at each shipment. The age setter FUN_008D4E01 calls
// FUN_0085650A(hc) when the new age is above 3 (the Imperial Age), which sets [card+20h] = [card+4] for each card of
// the list whose byte [card+24h] is 1 (<infiniteinlastage>). The field is in the saved game (the card's save at
// 0x85FC40 writes +20h and the byte +24h).
//
// The key: the tag sets bit 1 (02h) of the card's byte +24h in the home city's card array, read through the shared
// card tag hook (cardtags.h); the deck build, the save and the load copy the byte whole, so every player's copy of
// the card carries it. At the age setter's join after the new age is written (0x8D502F, before the stock refill),
// when the player advances (the setter's flag [esp+13h] is 0), each card of the player's list with the bit and a
// <maxcount> of 0 or more gets [card+20h] = [card+4]: one reset per age-up, never added to what is left, so an age
// with no send does not stack. An <infiniteinlastage> card that also has the bit is refilled the same way at the
// Imperial Age (stock's test `== 1` no longer matches it, and this reset has already done it). The card rollover
// builder hides the card's cost after its tech was researched unless the card is <infiniteinlastage> in age 4 with
// sends left; for a card with the bit the age test is skipped, so the cost shows again when it can be sent.
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <string>

#include "../cardtags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcResendAgeHook();
void UhcResendCostHook();
}

namespace {

constexpr std::uint32_t kAgeJoin = 0x008D502F;     // mov eax,[0C66234h]
constexpr std::uint32_t kCostAgeCheck = 0x00710804;  // cmp dword ptr [eax+50h],4 / jne 710863h
constexpr std::uint8_t kResendBit = 0x02;           // in the card's byte +24h; bit 0 is <infiniteinlastage>
constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr int kMaxLines = 200;

bool g_log = false;
int g_lines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

void Line(const wchar_t* format, ...) {
  if (g_lines >= kMaxLines) {
    return;
  }
  wchar_t text[512];
  va_list args;
  va_start(args, format);
  _vsnwprintf_s(text, _TRUNCATE, format, args);
  va_end(args);
  ++g_lines;
  uhc::Log(L"%ls%ls", text, g_lines == kMaxLines ? L" (no more lines are logged)" : L"");
}

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

const wchar_t* AgeName(std::int32_t age) {
  static const wchar_t* const kNames[] = {L"I", L"II", L"III", L"IV", L"V"};
  return age >= 0 && age < 5 ? kNames[age] : L"?";
}

// <resendeveryage>: 1 or true sets the bit, 0 or false clears it.
void ReadTag(char* hc, char* card, const wchar_t* text) {
  std::wstring value = text == nullptr ? L"" : text;
  while (!value.empty() && iswspace(value.back())) {
    value.pop_back();
  }
  std::size_t first = 0;
  while (first < value.size() && iswspace(value[first])) {
    ++first;
  }
  value = value.substr(first);
  auto& flags = *reinterpret_cast<std::uint8_t*>(card + 0x24);
  const std::int32_t tech = Field<std::int32_t>(card, 0x00);
  if (value == L"1" || _wcsicmp(value.c_str(), L"true") == 0) {
    flags = static_cast<std::uint8_t>(flags | kResendBit);
    if (g_log) {
      Line(L"resendableCards: card %d (%ls) of home city %p is sent again in each new age (maxcount %d)", tech,
           TechName(tech), static_cast<void*>(hc), Field<std::int32_t>(card, 0x04));
    }
  } else if (value == L"0" || _wcsicmp(value.c_str(), L"false") == 0) {
    flags = static_cast<std::uint8_t>(flags & ~kResendBit);
  } else {
    Line(L"resendableCards: <resendeveryage>%ls</resendeveryage> on card %d (%ls) is not 1, 0, true or false; ignored",
         value.c_str(), tech, TechName(tech));
  }
}

}  // namespace

extern "C" {

// From the age setter's join: `player` has its new age in [player+50h]; `notAdvance` is the setter's flag, 1 when
// the old age was the same or higher.
void __stdcall UhcResendAgeUp(char* player, std::uint32_t notAdvance) {
  if (player == nullptr || (notAdvance & 0xFF) != 0) {
    return;
  }
  char* hc = Field<char*>(player, 0x84);
  if (hc == nullptr) {
    return;
  }
  // The game's card list hc+228h: [list+1Ch] the records, [list+20h] their count (FUN_0085FFCE).
  char* cards = Field<char*>(hc, 0x228 + 0x1C);
  const std::int32_t count = Field<std::int32_t>(hc, 0x228 + 0x20);
  for (std::int32_t i = 0; cards != nullptr && i < count; ++i) {
    char* card = cards + static_cast<std::uint32_t>(i) * 0x28;
    if ((Field<std::uint8_t>(card, 0x24) & kResendBit) == 0) {
      continue;
    }
    const std::int32_t max = Field<std::int32_t>(card, 0x04);
    const std::int32_t left = Field<std::int32_t>(card, 0x20);
    if (max < 0 || left == max) {
      continue;  // infinite, or not sent since the last reset
    }
    *reinterpret_cast<std::int32_t*>(card + 0x20) = max;
    if (g_log) {
      const std::int32_t tech = Field<std::int32_t>(card, 0x00);
      Line(L"resendableCards: player %d reached Age %ls: card %d (%ls) can be sent %d time(s) again (it had %d left)",
           Field<std::int32_t>(player, 0x00), AgeName(Field<std::int32_t>(player, 0x50)), tech, TechName(tech), max,
           left);
    }
  }
}

// From the card rollover's cost test: true when the card has the bit (the age test is then skipped).
bool __stdcall UhcResendCard(const char* card) {
  return card != nullptr && (Field<std::uint8_t>(card, 0x24) & kResendBit) != 0;
}
}

namespace uhc {

Outcome ApplyResendableCards(const Config& config) {
  const Config::Args* args = config.First("resendableCards");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"resendableCards: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("resendableCards", {&sites::kAgeUpJoin, &sites::kAgeUpStockRefill, &sites::kSetAgeAdvanceFlag,
                                     &sites::kCardRolloverAgeCheck, &sites::kCardRolloverHead})) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!AddCardTagHandler("resendableCards", "resendeveryage", &ReadTag) ||
      !WriteJmp(kAgeJoin, reinterpret_cast<const void*>(&UhcResendAgeHook), 5) ||
      !WriteJmp(kCostAgeCheck, reinterpret_cast<const void*>(&UhcResendCostHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"resendableCards: a card with <resendeveryage>1</resendeveryage> gets its sends back (its maxcount) each time "
      L"its player reaches a new age%ls (multiplayer unverified)",
      log ? L"; each card read and each reset is logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
