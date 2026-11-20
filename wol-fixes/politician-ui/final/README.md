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
| - | - | 1024 x 768 | not tested (the resolution is in the shared profile) |
| - | - | The Asian and native dialogs | not tested in game (other builders and files; nothing there is touched) |
| - | - | Multiplayer, a saved game, a revolution | not tested |

Videos: `docs/media/politicianEnablesTech-wol.mp4` (key on, the cursor over seven techs) and
`docs/media/politicianEnablesTech-wol-control.mp4` (key off).
