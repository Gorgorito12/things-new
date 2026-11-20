# Politician UI (#70): test pictures

All at 1920 x 1080, windowed, in a WoL 1.2.0e copy (scenario, single player, 2026-11-20), with the files of
`apply_fix.py`. Test data on top of them: the Scandinavian first wave with three tags (Midsommar added) and the
Polish first wave with four (Resurrectionist Congregation and Roadwork Engineering added), so that every row
layout shows; the Aristocrat is a politician without tags. The scenario's own civ was made to use the European
dialog and given the politicians by trigger, since a skirmish with a Latin American civ needs a change of the
shared profile.

| # | Picture | Test | Result |
|---|---|---|---|
| 1 | `01-argentine-waves-2-4-3-tags.jpg` | Argentine waves: 2 techs (one per row), 4 and 3 (two per row); flag alone; descriptions with `--strings`; a politician without tags beside them | pass |
| 2 | `02-tooltip-trattoria.jpg` | Cursor on an icon: the tech's research rollover | pass |
| 3 | `03-tooltip-grid.jpg` | Cursor on a name in the two-per-row layout: the rollover, with "not available until Age 2" in red | pass |
| 4 | `04-click-icon-selects-politician.jpg` | A click on a tech icon selects its politician (green) | pass |
| 5 | `05-mexican-waves-long-descriptions.jpg` | Mexican waves (French, Chinese, Confederate) without `--strings`: the long descriptions fit above the techs; with `politicianPlacesFix`, a fifth politician is left out of the four places | pass |
| 6 | `06-spanish.jpg` | Spanish (WoL's ES-LA table): names and rollovers in Spanish | pass |
| 7 | `07-five-places.jpg` | The five-place dialog of #62 with the new gadgets | pass |
| 8 | `08-beside-wol-dll.jpg` | WoL's own `uhc.dll` with our `dinput8.dll` | pass |
| 9 | `09-control-key-off.jpg` | Key off, the same data: WoL's pictures with the painted icons, as today | pass (control) |
| - | (log) | A tag naming no tech: one line in the log, the other tags shown | pass |
| - | (in game) | Accepting a tagged politician: the age-up starts, 800 food paid | pass |
| - | (in game) | Closing the dialog and opening it again | pass |
| - | - | 1024 x 768 | tested in a real game, below (`real-09` to `real-13`) |
| - | - | The Asian and native dialogs | not tested in game (other builders and files; nothing there is touched) |
| - | - | Multiplayer, a saved game, a revolution | not tested |

## Real games (2026-11-20)

Skirmishes on Acre against the German AI (wolOtto, Hard), in `C:\AoE3-UHC-WoLReal7` (WoL 1.2.0e, its own profile),
with `politicianPlacesFix` and `politicianEnablesTech log`, no test data: the files of `apply_fix.py` only. In WoL's
data every politician has exactly two tags (74 politicians, 148 tags), so a real game only ever shows the one-per-row
layout; the two-per-row layout (three or four techs) needs test data, as in the pictures above. Resources were set in
memory (the player's stockpile) to reach every age quickly. The AI played (22 to 44 units).

| # | Picture | Test | Result |
|---|---|---|---|
| R1 | `real-01-argentine-1080-dialog.jpg` | Argentines, 1920 x 1080 windowed, without `--strings`: Age II, Italian, Polish and Scandinavian first waves, two techs each under the flag; the long descriptions end above the techs | pass |
| R2 | `real-02-argentine-1080-tooltip.jpg` | Cursor on the Biathlon icon: its research rollover | pass |
| R3 | `real-03-argentine-1080-click-icon.jpg` | A click on the Canned Fish icon selects the Scandinavian wave (green) | pass |
| R4 | `real-04-argentine-1080-accepted.jpg` | Accept: the age-up is queued, 800 food paid; when it ended, 2 Explorer Dogs and the Scandinavian wagon arrived (the wave clicked) | pass |
| R5 | `real-05-argentine-1080-age3.jpg` | Age III dialog: Lunfardo / Bread and Labor, Resurrectionist Congregation / Roadwork Engineering, Midsommar / Press | pass |
| R6 | `real-06-argentine-1080-click-name.jpg` | A click on a tech name (Roadwork Engineering) selects the Polish wave; accepted, 6 Cows and the Polish wagon arrived | pass |
| R7 | `real-07-argentine-1080-age4-vineyards.jpg` | Age IV dialog. The Italian wave shows "Vineyards" where its description says "Padroni": the right tech (`WOTTAimmigrantIT05`, icon `padroni`), whose name in WoL's string table (480112) is "Vineyards". A WoL text to align, not the key | pass (note) |
| R8 | `real-08-argentine-1080-age5-no-tags.jpg` | Age V: the cultural groups have no tags and look as without the key (full picture, no tech band, no line in the log) | pass |
| R9 | `real-09-argentine-768-dialog-strings.jpg` | Argentines, 1024 x 768 windowed, with `--strings`: the short descriptions; names readable, the three places alike, nothing overlaps | pass (note) |
| R10 | `real-10-argentine-768-tooltip.jpg` | 1024 x 768, cursor on "Transnational Organizations": the rollover | pass |
| R11 | `real-11-argentine-768-click-icon.jpg` | 1024 x 768, a click on the Biathlon icon selects the Scandinavian wave | pass |
| R12 | `real-12-argentine-768-accepted.jpg` | 1024 x 768, accepted: 800 food paid, the Scandinavian wave arrived | pass |
| R13 | `real-13-argentine-768-age3-long-name.jpg` | 1024 x 768, Age III: the longest name, "Resurrectionist Congregation", fits on one line inside the place; no name wrapped in any dialog | pass |
| R14 | `real-14-mexican-1080-dialog.jpg` | Mexicans, 1920 x 1080, with `--strings`: French, Chinese, Confederate first waves | pass |
| R15 | `real-15-mexican-1080-tooltip.jpg` | Cursor on the name "Chifa": the rollover | pass |
| R16 | `real-16-mexican-1080-click-icon.jpg` | A click on the Dollar Diplomacy icon selects the Confederate wave | pass |
| R17 | `real-17-mexican-1080-accepted.jpg` | Accepted: 800 food paid; the Town Hall Wagon and the American wagon arrived | pass |

Note on R9: at 1024 x 768 (4:3) the tech icons are 22 x 30 pixels, so they look a little taller than wide; at
1920 x 1080 they are square (about 41 x 42), as the README says. The flags are stretched the same way at 4:3, as in
the stock dialog. If the team wants square icons at 4:3 too, the icon gadgets would need a width that depends on
the aspect ratio, which the 1024 x 768 layout space cannot express; nothing else changes with the resolution.

Small WoL text differences seen (data, not the key): "Midsommar" (tech name) and "Midsummer" (wave description),
"Transnational Organizations" and "Transnational Organisations", "Vineyards" and "Padroni" (R7).

Videos: `docs/media/politicianEnablesTech-wol.mp4` (key on, the cursor over seven techs) and
`docs/media/politicianEnablesTech-wol-control.mp4` (key off).
