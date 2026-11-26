# Culture UI: inventory of the in-game interface's textures (2026-11-27)

For JTMaston's "Culture UI" request (paused). Read from `C:\AoE3-UHC-WoLReal` (Wars of Liberty 1.0.15c data, the same
files as the Steam install), with aoe3-blender-tools' `studio/hud.py` (the layouts the game loads for a match, found as
the game finds them: loose `data\` first, then `Data3.bar`, `Data2.bar`, `Data.bar`). Nothing was changed.

**The HUD** is `uimainnew.xml` plus nine panels the engine loads by name beside it, each in a normal and a minimised
file (`uiunitselection[min]`, `uiunitstatpanel3[min]`, `uicommandpanelnew[min]`, `uiminimappanelnew[min]`,
`uiwonderpowerpanel[min]`, `uiunittrainingpanel[min]`, `uitrainsandcontains[min]`, `uitraderoutepanel2[min]`,
`uinativecommandpanel2[min]`). They name 136 textures (8.2 MB as stored; an MB here is 1,048,576 bytes); **47 of
them are `ui\ingame\` textures, 7.8 MB**, and those are what a culture style would replace. The other 89 are icons (units, buildings,
resources), shared buttons (`ui\core_ui\...`) and the file-system background: they stay shared.

Gadget names below: `file:gadget`, with the file names shortened (`main` = `uimainnew`, `command` = `uicommandpanelnew`,
`minimap` = `uiminimappanelnew`, `selection` = `uiunitselection`, `stats` = `uiunitstatpanel3`, ...; a `min` after
the name is the minimised file). "Normal" and "Minimised" are the two interfaces of the game option.

## The atlases (where a style is made)

Eight textures hold 6.8 MB of the 7.8 MB. Restyling them changes almost every frame and background of the HUD:

| # | Texture | Size | Stored | Where | Normal UI gadgets | Minimised UI gadgets |
|---|---|---|---|---|---|---|
| 1 | `asi_ui_max` | 1024x1024 | 1.00 MB | WoL (loose) | `main:SettlerCountDialog-advancedPanelAsiMax`, `main:SettlerCountDialog-advancedPanelAsiMin`, `main:SettlerCountDialog-defaultPanelAsiMax` | `main:SettlerCountDialog-advancedPanelAsiMax`, `main:SettlerCountDialog-advancedPanelAsiMin`, `main:SettlerCountDialog-defaultPanelAsiMax` |
| 2 | `eur_max_ui` | 1024x1024 | 1.00 MB | WoL (loose) | `main:SettlerCountDialog-advancedPanelEurMax`, `main:SettlerCountDialog-advancedPanelEurMin`, `main:SettlerCountDialog-defaultPanelEurMax` | `main:SettlerCountDialog-advancedPanelEurMax`, `main:SettlerCountDialog-advancedPanelEurMin`, `main:SettlerCountDialog-defaultPanelEurMax` |
| 3 | `ingame_ui_02x_ypack` | 1024x1024 | 1.00 MB | WoL (loose) | `main:uimain-AgeAdvBG`, `main:uimain-AgeAdvFG`, `main:uimain-Score`, `selection:unitselectionpanel-stackQueue`, `selection:unitselectionpanel-unit`, `selection:unitselectionpanel-unitPortraitCountBackground`, `selection:unitselectionpanel-unitStackButtonBigBackground` | `main:uimain-AgeAdvBG`, `main:uimain-AgeAdvFG`, `main:uimain-Score` |
| 4 | `ingame_ui_small_01_asian` | 1024x1024 | 1.00 MB | WoL (loose) | `main:SettlerCountDialog-defaultPanelAsiMin` | `main:SettlerCountDialog-defaultPanelAsiMin` |
| 5 | `ingame_ui_small_01_ypack` | 1024x1024 | 1.00 MB | WoL (loose) | `command:commandpanel2-main`, `command:commandpanel2commands`, `main:SettlerCountDialog-defaultPanelEurMin`, `minimap:minimapPanel`, `trains:trainsandcontains-row0`, `trains:trainsandcontains-row1`, `trains:trainsandcontains-row2` | `commandmin:commandpanel2-main`, `commandmin:commandpanel2commands`, `main:SettlerCountDialog-defaultPanelEurMin`, `minimapmin:minimapPanel`, `trainsmin:trainsandcontains-row0`, `trainsmin:trainsandcontains-row1`, `trainsmin:trainsandcontains-row2` |
| 6 | `nat_ui_max` | 1024x1024 | 1.00 MB | WoL (loose) | `main:SettlerCountDialog-advancedPanelNatMax`, `main:SettlerCountDialog-advancedPanelNatMin`, `main:SettlerCountDialog-defaultPanelNatMax`, `main:SettlerCountDialog-defaultPanelNatMin` | `main:SettlerCountDialog-advancedPanelNatMax`, `main:SettlerCountDialog-advancedPanelNatMin`, `main:SettlerCountDialog-defaultPanelNatMax`, `main:SettlerCountDialog-defaultPanelNatMin` |
| 7 | `ingame_ui_03x_ypack` | 1024x512 | 512 KB | WoL (loose) | `native:nativecommandpanel2` |  |
| 8 | `ingame_ui_01` | 512x512 | 341 KB | stock archive Art4.bar | `minimap:shipsDisplayBG`, `minimap:shipsTimerBG`, `minimap:shipsTimerFG` | `minimapmin:shipsDisplayBG`, `minimapmin:shipsTimerBG`, `minimapmin:shipsTimerFG` |

Notes on the atlases:

- `eur_max_ui`, `asi_ui_max` and `nat_ui_max` are the backgrounds of the resource panel's three culture skins
  (`SettlerCountDialog-{default,advanced}Panel{Eur,Asi,Nat}{Max,Min}`, the engine shows one: docs/engine-symbols.md,
  "The resource panel per culture"). `ingame_ui_small_01_asian` is the minimised Asian skin's. So the stock game
  already has a per-culture texture, but for that one panel and three cultures only.
- `ingame_ui_small_01_ypack` is the wood of the minimap panel, the command panel's frame and its button grid (seen in
  game: `C:\Users\Jeison\Documents\GitHub\_share\maston-20261127\C\03_ingame_cache_test.png`), and
  `ingame_ui_02x_ypack` the age box at the top (with its age-up progress) and, in the normal interface, the selection
  panel's parts.
- `ingame_ui_03x_ypack` is the native settlement panel of the normal interface only (the minimised one uses
  `ingame_ui_small_03x_ypack`); `ingame_ui_01` is a stock texture (inside `Art4.bar`) for the shipment counter.

## The other HUD textures in ui\ingame

| Texture | Size | Stored | Where | Normal UI gadgets | Minimised UI gadgets |
|---|---|---|---|---|---|
| `ingame_ui_small_02_ypack` | 512x512 | 256 KB | WoL (loose) | `stats:unitstatpanel3-back` | `selectionmin:unitselectionpanel-unit`, `selectionmin:unitselectionpanel-unitPortraitCountBackground`, `selectionmin:unitselectionpanel-unitStackButtonBigBackground`, `statsmin:unitstatpanel3-back` |
| `ingame_ui_small_03x_ypack` | 512x256 | 128 KB | WoL (loose) | `traderoute:traderoutepanel2` | `nativemin:nativecommandpanel2`, `traderoutemin:traderoutepanel2` |
| `ingame_ui_small_04x_ypack` | 512x256 | 128 KB | WoL (loose) | `command:SocketPanel2`, `command:TreasurePanel` | `commandmin:SocketPanel2`, `commandmin:TreasurePanel` |
| `ingame_ui_tab_command_ypack` | 128x1024 | 128 KB | WoL (loose) | `selection:unitselectionpanel-showCommands`, `selection:unitselectionpanel-showStats`, `selection:unitselectionpanel-tabCommand` | `selectionmin:unitselectionpanel-showCommands`, `selectionmin:unitselectionpanel-showStats` |
| `ingame_ui_tab_stats_ypack` | 128x1024 | 128 KB | WoL (loose) | `selection:unitselectionpanel-tabStats` |  |
| `warwick_timer_panel` | 512x128 | 64 KB | WoL (loose) | `main:clockTimer` | `main:clockTimer` |
| `ingame_minimap_small_tribute_active_ypack` | 64x64 | 16 KB | WoL (loose) | `minimap:minimapPanel-explorerButton` | `minimapmin:minimapPanel-explorerButton` |
| `ingame_minimap_small_tribute_depressed_ypack` | 64x64 | 16 KB | WoL (loose) | `minimap:minimapPanel-explorerButton` | `minimapmin:minimapPanel-explorerButton` |
| `ingame_minimap_small_tribute_normal_ypack` | 64x64 | 16 KB | WoL (loose) | `minimap:minimapPanel-explorerButton` | `minimapmin:minimapPanel-explorerButton` |
| `mission_objectives` | 512x64 | 16 KB | WoL (loose) | `main:messageWindow` | `main:messageWindow` |
| `objective_counter` | 512x32 | 16 KB | WoL (loose) | `main:victoryTimerDisplay0`, `main:victoryTimerDisplay1`, `main:victoryTimerDisplay2` | `main:victoryTimerDisplay0`, `main:victoryTimerDisplay1`, `main:victoryTimerDisplay2` |
| `button` | 128x32 | 4 KB | WoL (loose) | `main:CampaignMenu-DiplomacyGame`, `main:CampaignMenu-PlayerOptions`, `main:CampaignMenu-QuitGame`, `main:CampaignMenu-ResignGame`, `main:CampaignMenu-ReturntoGame` and 39 more | `main:CampaignMenu-DiplomacyGame`, `main:CampaignMenu-PlayerOptions`, `main:CampaignMenu-QuitGame`, `main:CampaignMenu-ResignGame`, `main:CampaignMenu-ReturntoGame` and 39 more |
| `button_clicked` | 128x32 | 4 KB | WoL (loose) | `main:CampaignMenu-DiplomacyGame`, `main:CampaignMenu-PlayerOptions`, `main:CampaignMenu-QuitGame`, `main:CampaignMenu-ResignGame`, `main:CampaignMenu-ReturntoGame` and 39 more | `main:CampaignMenu-DiplomacyGame`, `main:CampaignMenu-PlayerOptions`, `main:CampaignMenu-QuitGame`, `main:CampaignMenu-ResignGame`, `main:CampaignMenu-ReturntoGame` and 39 more |
| `button_disabled` | 128x32 | 4 KB | WoL (loose) | `main:PlayerStatusButton`, `main:mainGameMenuMP-PlayerStatusButton`, `main:minimapPanel-menubutton`, `main:objectivesDialogButton`, `main:uimain-CoveredWagon` | `main:PlayerStatusButton`, `main:mainGameMenuMP-PlayerStatusButton`, `main:minimapPanel-menubutton`, `main:objectivesDialogButton`, `main:uimain-CoveredWagon` |
| `button_rollover` | 128x32 | 4 KB | WoL (loose) | `main:CampaignMenu-DiplomacyGame`, `main:CampaignMenu-PlayerOptions`, `main:CampaignMenu-QuitGame`, `main:CampaignMenu-ResignGame`, `main:CampaignMenu-ReturntoGame` and 39 more | `main:CampaignMenu-DiplomacyGame`, `main:CampaignMenu-PlayerOptions`, `main:CampaignMenu-QuitGame`, `main:CampaignMenu-ResignGame`, `main:CampaignMenu-ReturntoGame` and 39 more |
| `ingame_minimap_small_chat_active_ypack` | 64x64 | 4 KB | WoL (loose) | `minimap:minimapPanel-chat` | `minimapmin:minimapPanel-chat` |
| `ingame_minimap_small_chat_depressed_ypack` | 64x64 | 4 KB | WoL (loose) | `minimap:minimapPanel-chat` | `minimapmin:minimapPanel-chat` |
| `ingame_minimap_small_chat_normal_ypack` | 64x64 | 4 KB | WoL (loose) | `minimap:minimapPanel-chat` | `minimapmin:minimapPanel-chat` |
| `ingame_minimap_small_flare_active_ypack` | 64x64 | 4 KB | WoL (loose) | `minimap:minimapPanel-flareButton` | `minimapmin:minimapPanel-flareButton` |
| `ingame_minimap_small_flare_depressed_ypack` | 64x64 | 4 KB | WoL (loose) | `minimap:minimapPanel-flareButton` | `minimapmin:minimapPanel-flareButton` |
| `ingame_minimap_small_flare_normal_ypack` | 64x64 | 4 KB | WoL (loose) | `minimap:minimapPanel-flareButton` | `minimapmin:minimapPanel-flareButton` |
| `background_blue_c` | 64x64 | 2 KB | stock archive art2.bar | `main:chatInput` | `main:chatInput` |
| `in_game_chat_left` | 64x32 | 1 KB | WoL (loose) | `main:chatInputArtLeft` | `main:chatInputArtLeft` |
| `in_game_chat_mid` | 64x32 | 1 KB | WoL (loose) | `main:chatInputArtMiddle` | `main:chatInputArtMiddle` |
| `in_game_chat_right` | 64x32 | 1 KB | WoL (loose) | `main:chatInputArtRight` | `main:chatInputArtRight` |
| `ui_health_bar` | 128x16 | 1 KB | stock archive art2.bar | `selection:unitselectionpanel-unitHealthBarGreen`, `selection:unitselectionpanel-unitHealthBarRed`, `selection:unitselectionpanel-unitHealthBarYellow` | `selectionmin:unitselectionpanel-unitHealthBarGreen`, `selectionmin:unitselectionpanel-unitHealthBarRed`, `selectionmin:unitselectionpanel-unitHealthBarYellow` |
| `ingame_ui_health_green` | 16x8 | 0 KB | stock archive art2.bar | `selection:unitselectionpanel-unitHealthBarGreen` | `selectionmin:unitselectionpanel-unitHealthBarGreen` |
| `ingame_ui_health_red` | 16x8 | 0 KB | stock archive art2.bar | `selection:unitselectionpanel-unitHealthBarRed` | `selectionmin:unitselectionpanel-unitHealthBarRed` |
| `ingame_ui_health_yellow` | 16x8 | 0 KB | stock archive art2.bar | `selection:unitselectionpanel-unitHealthBarYellow` | `selectionmin:unitselectionpanel-unitHealthBarYellow` |
| `background_black` | 8x8 | 0 KB | stock archive art2.bar | `main:mainGameMenu`, `main:mainGameMenuMP`, `main:mainGameMenuRecGame`, `main:postGameMenu`, `native:nativecommandpanel2-NativePortraitBack` and 1 more | `main:mainGameMenu`, `main:mainGameMenuMP`, `main:mainGameMenuRecGame`, `main:postGameMenu`, `nativemin:nativecommandpanel2-NativePortraitBack` and 1 more |
| `outline_bottom_left` | 4x4 | 0 KB | stock archive art2.bar | `main:NotifyTextDisplay-border-bottom-left`, `main:chat-border-bottom-left`, `main:objectivesNotificationBorder5`, `main:percent-border-bottom-left` | `main:NotifyTextDisplay-border-bottom-left`, `main:chat-border-bottom-left`, `main:objectivesNotificationBorder5`, `main:percent-border-bottom-left` |
| `outline_bottom_middle` | 4x4 | 0 KB | stock archive art2.bar | `main:NotifyTextDisplay-border-bottom-middle`, `main:chat-border-bottom-middle`, `main:objectivesNotificationBorder6`, `main:percent-border-bottom-middle` | `main:NotifyTextDisplay-border-bottom-middle`, `main:chat-border-bottom-middle`, `main:objectivesNotificationBorder6`, `main:percent-border-bottom-middle` |
| `outline_bottom_right` | 4x4 | 0 KB | stock archive art2.bar | `main:NotifyTextDisplay-border-bottom-right`, `main:chat-border-bottom-right`, `main:objectivesNotificationBorder7`, `main:percent-border-bottom-right` | `main:NotifyTextDisplay-border-bottom-right`, `main:chat-border-bottom-right`, `main:objectivesNotificationBorder7`, `main:percent-border-bottom-right` |
| `outline_side_left` | 4x4 | 0 KB | stock archive art2.bar | `main:NotifyTextDisplay-border-side-left`, `main:chat-border-side-left`, `main:objectivesNotificationBorder3`, `main:percent-border-side-left` | `main:NotifyTextDisplay-border-side-left`, `main:chat-border-side-left`, `main:objectivesNotificationBorder3`, `main:percent-border-side-left` |
| `outline_side_right` | 4x4 | 0 KB | stock archive art2.bar | `main:NotifyTextDisplay-border-side-right`, `main:chat-border-side-right`, `main:objectivesNotificationBorder4`, `main:percent-border-side-right` | `main:NotifyTextDisplay-border-side-right`, `main:chat-border-side-right`, `main:objectivesNotificationBorder4`, `main:percent-border-side-right` |
| `outline_top_left` | 4x4 | 0 KB | stock archive art2.bar | `main:NotifyTextDisplay-border-top-left`, `main:chat-border-top-left`, `main:objectivesNotificationBorder0`, `main:percent-border-top-left` | `main:NotifyTextDisplay-border-top-left`, `main:chat-border-top-left`, `main:objectivesNotificationBorder0`, `main:percent-border-top-left` |
| `outline_top_middle` | 4x4 | 0 KB | stock archive art2.bar | `main:NotifyTextDisplay-border-top-middle`, `main:chat-border-top-middle`, `main:objectivesNotificationBorder1`, `main:percent-border-top-middle` | `main:NotifyTextDisplay-border-top-middle`, `main:chat-border-top-middle`, `main:objectivesNotificationBorder1`, `main:percent-border-top-middle` |
| `outline_top_right` | 4x4 | 0 KB | stock archive art2.bar | `main:NotifyTextDisplay-border-top-right`, `main:chat-border-top-right`, `main:objectivesNotificationBorder2`, `main:percent-border-top-right` | `main:NotifyTextDisplay-border-top-right`, `main:chat-border-top-right`, `main:objectivesNotificationBorder2`, `main:percent-border-top-right` |
| `button_disable` | NonexNone | 0 KB | stock archive ? | `main:CampaignMenu-DiplomacyGame`, `main:CampaignMenu-PlayerOptions`, `main:CampaignMenu-QuitGame`, `main:CampaignMenu-ResignGame`, `main:CampaignMenu-ReturntoGame` and 34 more | `main:CampaignMenu-DiplomacyGame`, `main:CampaignMenu-PlayerOptions`, `main:CampaignMenu-QuitGame`, `main:CampaignMenu-ResignGame`, `main:CampaignMenu-ReturntoGame` and 34 more |

The buttons (`button`, `button_clicked`, `button_rollover`, `button_disabled`, 128x32) are the states of the 44
buttons of the in-game menus that `uimainnew.xml` holds (game menu, campaign menu, post-game menu, ...): small, and
part of the HUD's file, so a style may include them.

## Not in scope: ui\ingame textures that only other screens use

These are named by layouts that are not the HUD: menus and dialogs opened from a match or from the main menu
(options, post-game, politicians, home city, tribute, chat), the old pre-TAD panels (`uimain`, `uicommandpanel`,
`uiminimappanel`, `uiunitstatpanel`, `tempinterface*`) and the observer interface. A per-culture look of those would
be a second step; the same texture redirect would cover them, as it works on names, not files.

| Used by | Textures |
|---|---|
| uiautopatcherdialog, uifilemanager, uiingamemsg1 ... | `resign_window` |
| uibattle | `battle_64x32` |
| uicivpicker, uihistory, uihomecitypicker ... | `ingame_ui_parch` |
| uicivpicker, uihomecitypicker, uihomecitypickerdocked ... | `ingame_ui_postgame_flag_british` |
| uicommandpanel | `tempinterface3` |
| uiconsulatedlg, uihistory, uihotkeys ... | `ingame_ui_postgame_topbar`, `ingame_ui_postgame_topbar_left`, `ingame_ui_postgame_topbar_right` |
| uiconsulatedlg, uipoliticianasiandlg, uipoliticiandlg ... | `politician_panel`, `politicians\politician_admiral`, `politicians\positive` |
| uigadsection | `ui_options_minmax_left` |
| uigadsection, uiplayercomms | `ui_options_minmax_middle`, `ui_options_minmax_right` |
| uihistory, uihotkeys, uioptions ... | `ui_postgame_heavyborder_bottom`, `ui_postgame_heavyborder_bottomleft`, `ui_postgame_heavyborder_bottomright`, `ui_postgame_heavyborder_left`, `ui_postgame_heavyborder_right`, `ui_postgame_heavyborder_top`, `ui_postgame_heavyborder_topleft`, `ui_postgame_heavyborder_topright` |
| uihistory, uioptions | `ui_options_active_tab`, `ui_options_inactive_tab`, `ui_options_innerborder_bottom`, `ui_options_innerborder_bottomleft`, `ui_options_innerborder_bottomright`, `ui_options_innerborder_left`, `ui_options_innerborder_right`, `ui_options_innerborder_top`, `ui_options_innerborder_topleft`, `ui_options_innerborder_topright` |
| uihomecitypicker | `hc_picker` |
| uihomecitypicker, uihomecitypickerdocked, uihomecitysummarypanel ... | `game_type_deathmatch`, `game_type_supremacy` |
| uihomecitytransportpanel | `home_city` |
| uiingamemsg3 | `ingame_ui_postgame_topbar_ends` |
| uimain | `french`, `ingame_ui_04x_ypack`, `tempinterface4` |
| uimain, uiminimappanel, uiunitstatpanel2 | `tempinterface` |
| uimain, uiplayersummarydlg, uitributedlg | `resource_food`, `resource_gold`, `resource_wood` |
| uimainnewobserver1280x720, uimainnewobserver1280x720jp, uimainnewobserver1280x768 ... | `ingame_ui_01x_asian`, `ingame_ui_01x_ypack`, `ingame_ui_05`, `ingame_ui_06` |
| uiminimappanel | `ingame_minimap_buttons_active`, `ingame_minimap_buttons_depressed`, `ingame_minimap_buttons_disabled`, `ingame_minimap_buttons_normal`, `ingame_upgrades_off`, `ingame_upgrades_on` |
| uimpesogamelist | `game_type_custom` |
| uimpsetupfinal, uimultiselectpanel, uitributedlg | `background_blue_b` |
| uinativecommandpanel, uitraderoutepanel | `tempinterface5` |
| uinewyear | `background_brown_a` |
| uioptions | `ingame_ui_parch_transition` |
| uiplayercomms | `ui_options_minmax_left_design` |
| uiplayersummarydlg, uipostgamescreen | `ingame_ui_parch_bottom`, `ingame_ui_parch_corner_bottomleft`, `ingame_ui_parch_corner_bottomright`, `ingame_ui_parch_corner_topleft`, `ingame_ui_parch_corner_topright`, `ingame_ui_parch_left`, `ingame_ui_parch_right`, `ingame_ui_parch_top` |
| uipoliticianasiandlg, uipoliticiannativedlg | `politicians\unavailable` |
| uipostgamescreen | `ingame_ui_postgame_tab_inactive`, `ingame_ui_postgame_tab_normal`, `ingame_ui_postgame_win_overlay` |
| uiunitstatpanel | `tempinterface2` |

**The observer interface** (`uimainnewobserver<resolution>.xml`, swapped in by WoL's DLL for an observer) uses its own
atlases: `ingame_ui_01x_ypack`, `ingame_ui_01x_asian`, `ingame_ui_05`, `ingame_ui_06` (docs/observer-mode.md). An
observer would see the default look unless those are styled too.

## How the counts were made

A script over `studio/hud.py`'s `Scene` (both variants): every `background`, `foreground`, `progressBarBackground`,
`progressBarMask` and `stateEntry` texture of every gadget, keyed by art path; sizes and formats from each `.ddt`'s
header (`aoe3game/ddt.py`), found loose first, then in the art archives. All other `ui*.xml` layouts of the copy were
read for the out-of-scope table.
