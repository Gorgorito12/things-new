Age V (Imperial Age) shipments - request #83, 2026-11-21
=========================================================

What it is
----------
Home city cards that can only be sent in the Imperial Age (the fifth age, "age 4" inside the game).

With the key `ageFiveShipments` in Startup\wol.cfg:
- a card with <age>4</age> in its home city file (data\homecityxxx.xml) is part of the game's deck;
- it is shown in the Age IV row, after the Age IV cards, both in the in-game shipment panel and in the
  home city's "Build a Deck" screen;
- until the player reaches the Imperial Age the card is greyed out and its rollover says, in red,
  "This Card cannot be sent until Age 5" (the game's own line); a send before that is refused;
- in the Imperial Age it is sent like any other card; `shipmentCounts` counts it in Age V.

Without the key the game drops such a card: a deck of 25 with one Age V card plays with 24 cards, and
neither panel shows it.

Why not a fifth row
-------------------
In the exe each deck panel holds exactly four rows of 11 buttons, and a card's row is its age. A fifth
row would need both panels rebuilt (new storage for the buttons and every piece of code that reads
them), not a layout edit. So the Imperial cards share the Age IV row. A row holds 11 cards: Age IV and
Age V cards together beyond 11 are not shown (the same as stock with a twelfth card).

Also: the card inventory's "By Age" view has four tabs (I to IV); an Age V card is found under
"By Building".

What to install
---------------
Nothing but the key: no layout or data file changes. Give a card <age>4</age> to make it an Age V card.

Screenshots (WoL 1.2.0e, Dutch, test data: HCShipCannons1 "2 Steel Guns" given <age>4</age>)
- panel-age1-key-on.png   in Age I: the Age V card is the fourth card of the Age IV row, greyed, with
                          "This Card cannot be sent until Age 5".
- panel-age4-key-on.png   in Age IV: rows I to IV are active, the Age V card stays greyed.
- deck-builder-key-on.png "Build a Deck": the Age V card in the Age IV row (25/25).
- deck-builder-key-off.png the same deck with the key off: the Age IV row has three cards, the counter
                          still says 25/25 (the Age V card is in the deck but never shown or played).

Tested (single player, 2026-11-21): the card in the game's deck (24 of 25 cards before, 25 after), greyed
in Ages I to IV, a send in Age IV refused (nothing queued), sent in Age V, arrived and counted in Age V
by shipmentCounts; "Build a Deck" shows it. Not tested: the AI with an Age V card in its deck, other
resolutions than 1920 x 1080 (no layout changes, so none expected).
