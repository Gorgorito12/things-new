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
// age 3, after the age-3 cards (the list is in age order), in the three panels: the hooks at 0x9A5A22, 0x9A0489
// and 0x9A77BE read the card's age as stock does and hand age 4 on as 3 for the row only. The card keeps its age: the panel
// still greys it out until the player's age reaches it (FUN_009A5658 compares [card+18h] with the player's age),
// and the send FUN_0085A724 refuses it before (0x85A90A). A fifth row needs room the panels' objects do not have
// (their button arrays hold 4 x 11), so the cards share the Imperial row.
#include <windows.h>

#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcAgeFivePanelHook();  // hooks/agefive_hooks.asm
void UhcAgeFiveDeckHook();
void UhcAgeFiveBuilderHook();
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
                                      &sites::kDeckEditorAgeRow, &sites::kDeckBuilderAgeRow})) {
    return Outcome::kFailed;
  }
  const std::uint8_t five = 5;
  // The immediate of `cmp eax,4` (83 F8 04) at 0x63022E.
  if (!WriteBytes(sites::kCardListAgePasses.va + 2, &five, 1) ||
      !WriteJmp(sites::kCardPanelAgeRow.va, reinterpret_cast<const void*>(&UhcAgeFivePanelHook), 5) ||
      !WriteJmp(sites::kDeckEditorAgeRow.va, reinterpret_cast<const void*>(&UhcAgeFiveDeckHook), 5) ||
      !WriteJmp(sites::kDeckBuilderAgeRow.va, reinterpret_cast<const void*>(&UhcAgeFiveBuilderHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"ageFiveShipments: cards of the fifth age (<age>4</age>) are in the game's deck, shown in the fourth age's "
      L"row of the shipment panel and the deck editor, and sendable in the fifth age (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
