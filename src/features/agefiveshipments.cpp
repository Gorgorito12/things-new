// ageFiveShipments: home city cards of the fifth age (<age>4</age>, the Imperial Age) can be in the game's deck and
// be sent once the player is in that age.
//
// Stock leaves such a card out three times over:
// - the game's card list of a player (hc+228h) is built from the chosen deck by FUN_006301DE, one pass per age, and
//   the passes stop after age 3 (`cmp eax,4` at 0x63022E): a card of age 4 never gets into the game;
// - the in-game shipment panel (the gadget homeCityCardPanel, FUN_009A5658) places each card in the row of its age
//   and skips an age below 0 or above 3 (0x9A5A22..0x9A5A30); its rows are four arrays of 4 x 11 buttons;
// - the deck builder of the home city screen (buttons hcDeck-button<row><column>) and the homeCityDeck dialog
//   (FUN_009A7670) stop at the first card whose age is 4 or more (0x9A0489..0x9A04AA, 0x9A77BE..0x9A77DF).
//
// The key lets the list builder take five ages (the immediate 4 becomes 5) and shows a card of age 4 in the row of
// age 3 in the three panels: the hooks at 0x9A5A22, 0x9A0489 and 0x9A77BE read the card's age as stock does and hand
// age 4 on as 3 for the row only. The card keeps its age: the panel still greys it out until the player's age
// reaches it (FUN_009A5658 compares [card+18h] with the player's age), and the send FUN_0085A724 refuses it before
// (0x85A90A). A fifth row needs room the panels' objects do not have (their button arrays hold 4 x 11), so the
// cards share the Imperial row.
//
// In that row (JTMaston, #83, 2026-11-22) the Age IV cards stay packed at the left, as stock places them, and the
// Age V cards are packed at the right: once a fill has set a card's row, the hooks at 0x9A5A7C, 0x9A04B0 and
// 0x9A77E5 give it its column (UhcAgeFiveColumn). A fill computes the slot row x 11 + column only after that, and
// stores both the card's button and its link (panel +1F0h, builder +228h) at that slot, so the click and rollover
// of a button find the card the fill put there. Slots left between the two groups stay hidden: each fill hides the
// 44 buttons and resets the links before it places a card.
#include <windows.h>

#include <cstdint>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcAgeFivePanelHook();  // hooks/agefive_hooks.asm
void UhcAgeFiveDeckHook();
void UhcAgeFiveBuilderHook();
void UhcAgeFivePanelColumnHook();
void UhcAgeFiveBuilderColumnHook();
void UhcAgeFiveDeckColumnHook();
}

namespace {

constexpr int kColumns = 11;              // buttons in a row of every deck panel
constexpr std::uint32_t kCardAge = 0x18;  // [card+18h], the card's <age>, 0 = Age I
constexpr std::int32_t kCardSize = 0x28;
constexpr std::uint32_t kListData = 0x1C;   // a card list: its cards, 28h bytes each
constexpr std::uint32_t kListCount = 0x20;  // and how many

const wchar_t* const kWhere[] = {L"in-game shipment panel", L"deck builder", L"deck editor"};
int g_lastAgeFour[3] = {-1, -1, -1};  // the counts last logged, per panel, so a fill that repeats logs nothing
int g_lastAgeFive[3] = {-1, -1, -1};

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

}  // namespace

// Called by the three column hooks once a fill has set the card's row and column, before it uses them. Returns the
// column of the card, or -1 to leave the card out (the fill then goes on to the next card, as for a twelfth card of
// a row). Only the row of Age IV changes, and only when the list holds an Age V card: an Age IV card keeps its
// column (its rank among the Age IV cards) if it is left of the Age V cards, and an Age V card takes column
// 11 - (Age V cards) + its rank among them. `counter` is the panel's count of the row's cards, or null.
extern "C" int __stdcall UhcAgeFiveColumn(const char* list, const char* card, int column, int* counter, int where) {
  if (list == nullptr || card == nullptr) {
    return column;
  }
  const std::int32_t age = Field<std::int32_t>(card, kCardAge);
  if (age != 3 && age != 4) {
    return column;
  }
  const char* data = Field<const char*>(list, kListData);
  const std::int32_t count = Field<std::int32_t>(list, kListCount);
  if (data == nullptr || count <= 0 || card < data || card >= data + count * kCardSize ||
      (card - data) % kCardSize != 0) {
    return column;
  }
  const auto index = static_cast<std::int32_t>((card - data) / kCardSize);
  int ageFour = 0;
  int ageFive = 0;
  int rank = 0;  // the card's rank among the cards of its age in the list
  for (std::int32_t i = 0; i < count; ++i) {
    const std::int32_t a = Field<std::int32_t>(data + i * kCardSize, kCardAge);
    if (a == 3) {
      ++ageFour;
    } else if (a == 4) {
      ++ageFive;
    }
    if (i < index && a == age) {
      ++rank;
    }
  }
  if (ageFive == 0) {
    return column;  // as before: no Age V card, the stock layout
  }
  const int shown = ageFive < kColumns ? ageFive : kColumns;
  const int first = kColumns - shown;  // the first column of the Age V cards
  if (where >= 0 && where < 3 && (ageFour != g_lastAgeFour[where] || ageFive != g_lastAgeFive[where])) {
    g_lastAgeFour[where] = ageFour;
    g_lastAgeFive[where] = ageFive;
    if (ageFour + ageFive > kColumns) {
      uhc::Log(L"ageFiveShipments: the %ls's Age IV row gets %d Age IV and %d Age V cards, more than its %d buttons: "
               L"the Age V cards keep the right side, and %d Age IV card(s)%ls are not shown",
               kWhere[where], ageFour, ageFive, kColumns, ageFour - first > 0 ? ageFour - first : 0,
               ageFive > kColumns ? L" and the Age V cards after the eleventh" : L"");
    } else {
      uhc::Log(L"ageFiveShipments: the %ls's Age IV row: %d Age IV card(s) at the left, %d Age V card(s) at the "
               L"right (columns %d to %d)",
               kWhere[where], ageFour, ageFive, first + 1, kColumns);
    }
  }
  int result = age == 4 ? first + rank : rank;
  if (age == 3 && result >= first) {
    result = -1;  // its slot is the Age V cards'
  }
  if (result >= kColumns) {
    result = -1;
  }
  if (result < 0 && counter != nullptr && *counter > 0) {
    --*counter;  // the panel counted it in the row before the hook
  }
  return result;
}

namespace uhc {

Outcome ApplyAgeFiveShipments(const Config& config) {
  const Config::Args* args = config.First("ageFiveShipments");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!args->empty()) {
    Log(L"ageFiveShipments: unexpected argument %hs (it takes none); feature not applied", (*args)[0].c_str());
    return Outcome::kFailed;
  }
  if (!VerifyAll("ageFiveShipments", {&sites::kCardListAgePasses, &sites::kCardPanelAgeRow,
                                      &sites::kDeckEditorAgeRow, &sites::kDeckBuilderAgeRow,
                                      &sites::kCardPanelColumn, &sites::kDeckBuilderColumn,
                                      &sites::kDeckEditorColumn})) {
    return Outcome::kFailed;
  }
  const std::uint8_t five = 5;
  // The immediate of `cmp eax,4` (83 F8 04) at 0x63022E.
  if (!WriteBytes(sites::kCardListAgePasses.va + 2, &five, 1) ||
      !WriteJmp(sites::kCardPanelAgeRow.va, reinterpret_cast<const void*>(&UhcAgeFivePanelHook), 5) ||
      !WriteJmp(sites::kDeckEditorAgeRow.va, reinterpret_cast<const void*>(&UhcAgeFiveDeckHook), 5) ||
      !WriteJmp(sites::kDeckBuilderAgeRow.va, reinterpret_cast<const void*>(&UhcAgeFiveBuilderHook), 5) ||
      !WriteJmp(sites::kCardPanelColumn.va, reinterpret_cast<const void*>(&UhcAgeFivePanelColumnHook), 8) ||
      !WriteJmp(sites::kDeckBuilderColumn.va, reinterpret_cast<const void*>(&UhcAgeFiveBuilderColumnHook), 8) ||
      !WriteJmp(sites::kDeckEditorColumn.va, reinterpret_cast<const void*>(&UhcAgeFiveDeckColumnHook), 7)) {
    return Outcome::kFailed;
  }
  Log(L"ageFiveShipments: cards of the fifth age (<age>4</age>) are in the game's deck, shown at the right of the "
      L"fourth age's row of the shipment panel and the deck panels (the Age IV cards at the left), and sendable in "
      L"the fifth age (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
