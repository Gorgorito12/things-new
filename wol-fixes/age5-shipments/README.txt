Age V (Imperial Age) shipments - request #83, 2026-11-21 (layout changed 2026-11-22)
====================================================================================

What it is
----------
Home city cards that can only be sent in the Imperial Age (the fifth age, "age 4" inside the game).

With the key `ageFiveShipments` in Startup\wol.cfg:
- a card with <age>4</age> in its home city file (data\homecityxxx.xml) is part of the game's deck;
- it is shown in the Age IV row, at its RIGHT end: the Age IV cards stay packed at the left, the Age V cards are
  packed at the right (in the order of the deck), and the slots between the two groups stay empty. The same in
  the in-game shipment panel, in the home city's "Build a Deck" screen, and in the deck chooser a game opens when
  the home city has several decks ("Select a Deck");
- until the player reaches the Imperial Age the card is greyed out and its rollover says, in red,
  "This Card cannot be sent until Age 5" (the game's own line); a send before that is refused;
- in the Imperial Age it is sent like any other card; `shipmentCounts` counts it in Age V.

Without the key the game drops such a card: a deck of 25 with three Age V cards plays with 22 cards, and
neither panel shows them.

The layout (your request of 2026-11-22)
---------------------------------------
Until 2026-11-22 the Age V cards came right after the Age IV cards. Now, for a row of 11 buttons:
- Age IV cards: columns 1, 2, 3, ... from the left, as before;
- Age V cards: the last columns: with 3 Age V cards, columns 9, 10 and 11; with 1, column 11.
A deck with no Age V card looks exactly as before.

A row still holds 11 cards. When the Age IV and Age V cards together are more than 11, the Age V cards keep
the right end and the last Age IV cards are not shown (the log says how many): they stay in the deck, but
without a button the player cannot send them, as the game does with a twelfth card of a row. Keep Age IV +
Age V at 11 or less per deck to see every card.

Each button keeps its own card: its rollover, a click (a send in game, a removal in "Build a Deck") and its
overlays (cost, shipments left) belong to the card shown there. Tested below.

Why not a fifth row
-------------------
In the exe each deck panel holds exactly four rows of 11 buttons, and a card's row is its age. A fifth
row would need both panels rebuilt (new storage for the buttons and every piece of code that reads
them), not a layout edit. So the Imperial cards share the Age IV row, at its right end.

Also: the card inventory's "By Age" view has four tabs (I to IV); an Age V card is found under
"By Building".

What to install
---------------
Nothing but the key: no layout or data file changes. Give a card <age>4</age> to make it an Age V card.

Pictures (WoL 1.2.0e, Portuguese, Lisbon's deck; test data: "16 Line Infantry" (WOLHCShipLineInfantry5),
"14 Ultramarinos" (WOLHCShipAtiradores2) and "2 Steel Guns" (HCShipCannons1), three Age IV cards, given <age>4</age>)
- deck-builder-key-on.png      "Build a Deck": six Age IV cards at the left, the three Age V cards at the right.
- deck-builder-two-age5.png    after a click on "14 Ultramarinos" (column 10): that card left the deck (24/25), the two
                               others moved to columns 10 and 11.
- deck-builder-one-age5.png    after a click on "16 Line Infantry": "2 Steel Guns" alone in column 11 (23/25).
- deck-builder-no-age5.png     after a click on it: no Age V card, the row as before (22/25).
- deck-builder-overflow.png    three Age III cards also made Age IV (9 + 3 = 12): eight Age IV cards at the left, the
                               three Age V cards at the right, one Age IV card not shown.
- deck-builder-key-off.png     the key off: six Age IV cards, no Age V card, the counter still 25/25.
- panel-age3-key-on.png        the in-game panel in Age III: the same layout; Age IV and Age V cards greyed.
- panel-age3-rollover-age5.png the rollover of column 9: "16 Line Infantry", "This Card cannot be sent until Age 5".
- panel-age5-key-on.png        in the Imperial Age: every card active (the rollover of "2 Steel Guns" without the line).
- panel-overflow.png           the full row in game, as in the deck builder.
- panel-key-off.png            the key off, Imperial Age: six Age IV cards, no Age V card.
- deck-dialog-key-on.png       the deck chooser of a game whose home city has two decks ("Select a Deck"): the same
                               layout.
Videos: docs\media\ageFiveShipments-wol.mp4 (sends from the right-hand slots) and ageFiveShipments-wol-control.mp4.

Tested (single player, 2026-11-21 and 2026-11-22)
-------------------------------------------------
2026-11-21 (Dutch, one Age V card): the card in the game's deck (24 of 25 cards before, 25 after), greyed in
Ages I to IV, a send in Age IV refused (nothing queued), sent in Age V, arrived and counted in Age V by
shipmentCounts; "Build a Deck" shows it.
2026-11-22 (Portuguese, three Age V cards, the right-hand layout):
- the rollover of every card of the Age IV row named that card (deck builder, in-game panel, deck chooser);
- in Age III, clicks on an Age V and an Age IV card sent nothing;
- in Age V, clicks on columns 11 and 9 shipped "2 Steel Guns" and "16 Line Infantry", clicks on Age IV columns 1
  and 2 shipped those two cards (the log names each card);
- in "Build a Deck", clicks removed the card under the cursor, and the others moved right (3, 2, 1, 0 Age V cards);
- the full row (9 + 3) and the key off, as in the pictures.
Not tested: the AI with an Age V card in its deck, multiplayer, other resolutions than 1920 x 1080 (the panels'
own buttons are used, so no difference is expected).
