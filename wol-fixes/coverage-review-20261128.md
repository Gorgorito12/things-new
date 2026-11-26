# UI coverage review of `researchGrants` and `shipTechLimit` (agent R, 2026-11-28 round)

First a review (nothing changed), then the fix the user approved on 2026-11-26 (section "The fix, done"). Static facts are in `docs/engine-symbols.md`, "Who builds a tech's or a
card's rollover"; the evidence is `rea/evidence/age3y-b1a1dab7/coverage-review-20261128.json` (main checkout).
Screenshots: `C:\Users\Jeison\Documents\GitHub\_share\maston-20261128\R\`.

## Short answer (the review, before the fix)

- Both keys show their text through one site: the command panel's call 0x4622C5 of the tech rollover builder 0x4C737C
  (`AddTechRolloverLine`). That call serves the normal and the minimised UI: both work (screenshots below).
- **Gap (same kind as quick arrival's):** the builder has two more UI callers that skip 0x4622C5, the **native
  command panel** (0x9AD7F1) and the **trade route panel** (0x9B7637), the panels of a trading post on a native socket
  or on a trade route. There neither key adds its button word or its rollover line. Only `researchGrants`' cost
  line is right there, because its cost hook 0x4C73FD sits inside the builder. This was already written as a limit in
  the guide's `researchGrants` section (2026-11-12). Not seen in game: a trading post made by a trigger does not
  land on its socket (two tries), so these two panels never opened.
- Home city, deck builder, "View All Cards", tech tree, observer: do not apply (reasons below).

## Per key and per screen (before the fix)

Test (2026-11-26, `C:\AoE3-UHC-WoLReal5`, single player, a skirmish on a test map against a German AI, `wolOtto`):
player 1 Spanish with `<ShipTechLimit>3</ShipTechLimit>`, a Market with `tools/grant_testdata.py`'s tags (scope
changed to `all`, so a point covers any research of the player), a `MapucheWarchief` with `Age0Mapuche`, two Settlers,
two trading posts made by a trigger. cfg: `researchGrants log`, `shipTechLimit log`. Build: this branch (main after
PR #87). Log: `UHCMain: 37 applied, 0 failed`; `researchGrants: applied`, `shipTechLimit: applied`; `hook reached:
tech rollover (0x4622C5)`, `researchGrants tech rollover cost (0x4C73FD)`, `can-research test (0x4C6968)`.

| Screen | Builder / site | `researchGrants` (word `Free` on the button, green rollover line, cost after the share) | `shipTechLimit` (green / red `Shipment techs: n/N` line, `n/N` on the button at the limit) | Evidence |
|---|---|---|---|---|
| Game, minimised UI, command panel | 0x4C737C via 0x4622C5 | **shown**: `Free` on all Market buttons, `Free research` in the rollover | **shown**: `Shipment techs: 1/3` after one council tech (Fowl) | `researchGrants-minimised-command-panel.png`, `shipTechLimit-minimised-command-panel.png` |
| Game, normal UI, command panel | the same | **shown** | **shown**: `Shipment techs: 0/3` | `researchGrants-normal-command-panel.png`, `shipTechLimit-normal-command-panel.png` |
| Game, a trading post on no socket | the same (its own command panel) | **shown**: Stagecoach `Free` / `Free research` | not checked (no shipment tech there) | `tradingpost-off-socket-minimised.png` |
| Game, native command panel (trading post on a native socket) | 0x4C737C called at 0x9AD7F1 in FUN_009ACAF4 | **missing** word and line (static); cost line after the share shown (static, the hook is inside the builder) | **missing** line and mark (static) | REA only; not opened in game |
| Game, trade route panel (trading post on a trade route) | 0x4C737C called at 0x9B7637 in FUN_009B687E | **missing** word and line (static); cost line after the share shown (static) | **missing** line and mark (static) | REA only; not opened in game |
| Home city in the game (shipment cards) | card builder FUN_007103CE | does not apply: a card is sent, not researched; no grant point is spent on it | does not apply: cards from the deck never count (guide) | `homecity-ingame-shipment-card.png`: the card rollover, no line, as expected |
| Home city outside the game, deck builder | FUN_007103CE | does not apply (as above; the home city buys with XP, not with a research) | does not apply | not shot: the same builder as the row above |
| "View All Cards" | FUN_00710991 | does not apply | does not apply | not shot: no tech research there |
| Tech tree | `gadtechtree.cpp`, its own text with the base cost (0x470446) | does not apply: a leftover screen the game's UI never opens (its only button is in the unused god picker); it would show the base cost | does not apply | REA and bytes |
| Observer | (the command panel) | does not apply: the price and line are for the building's owner only; the observer mode does not switch on in this install (`docs/observer-mode.md`, 2026-11-21) | the same | not tested |
| No-player rollover of the game object | 0x703F99 → 0x4C737C (player 0, unit 0) | does not apply: no player to price for | the same | callers unknown (no direct call found) |

What a missing line costs the player:
- `researchGrants`: a native or trade route tech researched at a trading post spends a point (scope `all`, or a
  trading post proto with the tags). Its button then has no `Free` or price and no green line, but the cost line in
  its rollover does show the cost after the share, and the click takes the right price (inferred: the payment hook is the same for every panel). So the gap is the word and
  the line, not the price.
- `shipTechLimit`: the refusal is at the head of the can-research test 0x4C6968, so it does not depend on the panel.
  Only the display is missing. In WoL's `techtreey.xml` 4,719 techs have a Ships cost; by name they are mostly home
  city cards, and none is named as a native or trade route tech (a name scan, not a check of each tech's buttons). **Inference:** today no tech of those two panels
  costs Ships, so the gap shows only if a modder gives one a Ships cost.

## REA list of the sites checked

| Site | What | Status |
|---|---|---|
| 0x4C737C callers: 0x4622C5, 0x703FAF, 0x9AD7F1, 0x9B7637 | every call of the tech rollover builder (`ev_3080e11c…`, `ev_6965b6ed…`, 1 unresolved = 0x703FAF) | confirmed |
| FUN_0046188E (0x4622C5) | command panel, normal and minimised UI | confirmed in game |
| FUN_009ACAF4 (0x9AD7F1), callers 0x9AE196, 0x9AE1D7 | native command panel (`uinativecommandpanel2[min].xml`) | confirmed by strings |
| FUN_009B687E (0x9B7637), callers 0x9B7FA9, 0x9B7FEA | trade route panel (`uitraderoutepanel2[min].xml`) | confirmed by strings |
| 0x703F99 (vtable 0xB88628 slot 0x144) | the game object's tech rollover, no player | confirmed by bytes; callers unknown |
| 0x4C8EE5 callers: 0x4C7477, 0x4C891C | the cost line: in the tech builder, and in another builder (not identified; not a tech rollover) | confirmed |
| 0x470446 callers: 0x4765F4, 0x4C8748, 0x70F25D, 0x70FCB8, 0x7103CE, 0x710991, 0x75FCC1, 0x99D39A, 2 unresolved | cost to text: card builders, the home city purchase dialog (`uihcconfirmdlg.xml`), unit rollovers, the tech tree gadget (0x8209DE) | confirmed callers; roles partly inferred |
| FUN_007103CE, FUN_00710991 | card rollovers (shipment panel, deck builder, deck dialog, View All Cards) | confirmed (earlier rows of engine-symbols) |
| FUN_005C3777, 0x8209F5 | tech tree gadget (`uitechtree.xml`, `%S:\n%s\nCost: %s`) | confirmed by bytes |
| 0x4C6968 | can-research test head (`shipTechLimit`'s refusal) | shared head hook: every panel that asks it |

## Not done or not seen

- The native and the trade route panels were not opened in game: `Unit Create` of a `TradingPost` near a socket put
  it beside the socket, never on it, and building one needs real clicks (not possible in a background copy).
- At the limit, the `n/N` mark on the buttons was not shot again: `researchByID` by console queued only one council
  tech (Fowl) this time, and posted clicks on the buttons did not start a research. The guide's
  `shipTechLimit-rollover.png` (2026-11-21) shows it in the command panel.
- The deck builder and "View All Cards" outside the game were not opened (no research there).
- Whether the native and the trade route panels ask the can-research test 0x4C6968 was not checked.

## The fix, done (2026-11-28, approved by the user on 2026-11-26)

**What changed.** `AddTechRolloverLine` (`src/techrollover.*`, `hooks/techrollover_hooks.asm`) moved from the command
panel's call 0x4622C5 to the builder's only exit, 0x4C78F3 (a 5-byte `jmp` over `pop ebp / pop ebx / add esp,40h`;
the hook replays them and leaves through the stock `ret` 0x4C78F8). Every game caller of the builder gets the keys'
lines. The return address picks the button's overlay buffer: 0x4622CA (command panel, `[esp+2E4h]`), 0x9AD7F6 (native
panel, `[esp+284h]`), 0x9B763C (trade route panel, `[esp+26Ch]`); each panel's call, reset and read are checked
against the stock bytes first (sites `TechButtonRollover`, `NativeTechRollover`, `TradeRouteTechRollover` and their
`*OverlayReset` / `*OverlayRead`), and a panel that does not match gets the lines without the word. A call from DLL
code (`politicianEnablesTech`'s age-up dialog) gets nothing, as before. REA for the exit: body ranges `ev_d4726e8c…`
(`rea/evidence/age3y-b1a1dab7/techrollover-builder-exit-20261128.json`), plus a capstone branch scan of `.text`.

**In game** (`C:\AoE3-UHC-WoLReal5`, `multipleInstances background`, no real mouse: the trading posts were placed with
posted messages only, `tis("TradingPost")` then a posted hover and click on the socket; a test map with a Cree village
(`rmSetSubCiv`, grouping `native cree village 1`) and a trade route with one socket; British with
`<ShipTechLimit>3</ShipTechLimit>`, the grant Market with scope `all`, test data giving Cree Warrior Societies,
Champion Cree and Stagecoach a cost of 1 Ship; a German AI). Log: `UHCMain: 37 applied, 0 failed`, `hook reached:
tech rollover (0x4C78F3)`, and `tech rollover: first rollover built for` the native panel (0x9AD7F1), the trade route
panel (0x9B7637) and the command panel (0x4622C5).

| Screen | `researchGrants` | `shipTechLimit` | Screenshot (`_share\maston-20261128\R\`) |
|---|---|---|---|
| Native panel, minimised UI | **shown**: `Free` on the buttons, `Free research` | **shown**: `Shipment techs: 0/3` | `fixed-native-panel-minimised.png` |
| Native panel, normal UI | **shown** | **shown** | `fixed-native-panel-normal.png` |
| Trade route panel, minimised UI | **shown**: Stagecoach `Free`, `Free research` | **shown** | `fixed-traderoute-panel-minimised.png` |
| Trade route panel, normal UI | **shown** | **shown** | `fixed-traderoute-panel-normal.png` |
| Command panel (control), minimised and normal UI | **shown**, as before | **shown**, as before | `fixed-command-panel-minimised.png`, `fixed-command-panel-normal.png` |
| Native panel, both keys off (control) | stock: the cost `200 wood, 150 gold, 1 Ship`, no word, no line | stock | `control-keys-off-native-panel-normal.png` |

Not seen: the `n/N` mark at the limit on the two new panels (no shipment tech of those panels could be researched in
Age I to reach the limit). It is written into the same button buffer as `researchGrants`' `Free`, which shows there.

**A/B** (`perfprobe.py`, 60 s each, normal UI, the native trading post selected with the pointer on a tech button;
another test game ran during the key-off take): key off 495 fps median, longest frame 3.5 ms (median of the seconds),
main thread 89.0 %, 0 frames over 50 ms; key on 549 fps, 2.6 ms, 92.1 %, 0 frames over 50 ms. Minimised UI, key on:
535 fps, 2.6 ms, 0 frames over 50 ms. No rise.

**Docs:** CLAUDE.md / AGENTS.md (shared hooks line), the guide's two sections (screens list, sites checked, log line;
the old limit removed), how-it-works, porting-to-another-dll, uhc-address-map, engine-symbols, porting-code.

## The fix, as proposed before the approval


Move `AddTechRolloverLine` from the call 0x4622C5 to the builder 0x4C737C itself (its head or its exit), or redirect
the calls 0x9AD7F1 and 0x9B7637 too. The overlay word needs each panel's own button buffer: the native and the trade
route panels have their own frames, to be read with REA before a hook. The builder is called per button per panel
refresh, so a head hook needs an A/B with `perfprobe.py`.
