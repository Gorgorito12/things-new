CULTURE UI TEMPLATES
====================

These files restyle the minimised in-game interface per culture family. Each .psd is one texture of the game
(art\ui\ingame\<texture>.ddt). Paint over the pieces; the game picks your texture by the player's family.

WHAT IS IN EACH .PSD (bottom to top)
  Original  today's art, hidden and locked: switch it on to compare, never paint on it.
  Paint     one layer per piece, holding today's art at its place. Paint on these layers
            (or add your own layers inside this group). Layer names: number, what it is, (the
            game's gadget). Pieces that share pixels share one layer.
  Guides    hidden: switch it on to see each piece's outline, number and name, the areas the
            game does not use (red hatching) and the pieces the screen stretches (orange).
  Photoshop guides (View > Show > Guides) run along the pieces' edges.

RULES
  - Keep the canvas size. Keep each piece inside its outline: the game crops exactly there.
  - Transparency matters: the game draws the alpha you paint (rounded edges, holes, see-through
    parts). Keep the outer shape of each piece unless you mean to change it.
  - Hatched areas are not used by this interface: paint there is dropped. They may still hold
    art (parts of the normal interface, or nothing the game uses): leave them as they are. Only
    the minimised interface is styled, so there is no need to repaint them.
  - The layout is made for a 4:3 screen: at 1920x1080 the game widens every piece
    1.33 times against its height. Draw with the original's proportions, not the
    screen's: the original art is already drawn for that.
  - Orange pieces are enlarged or stretched unevenly on screen: avoid fine detail that would blur,
    and patterns that would look distorted. The reference sheet lists each piece's screen size.

FILE NAMES
  <texture>_<suffix>.ddt for a family, <texture>_<suffix>_gw.ddt for its Great War look.
  Suffixes: eu Europeans, an Anglos, la Latin Americans, ns Nation states, af Africans, as Asians, me Middle East, na Native Americans, po Polynesians.
  A family without its own texture shows today's art; a family without a _gw texture keeps its
  own look in the Great War.

HOW TO HAND THEM IN
  Either save the .psd (keep the Paint group; Original and Guides are ignored), or export a
  flattened PNG with transparency (File > Export > Export As > PNG, with Original and Guides
  hidden). Name it <texture>_<suffix>.psd or .png (for example ingame_ui_small_01_ypack_as.png).
  Blend modes other than Normal, layer styles and clipping masks are not read from a .psd:
  merge them into a normal layer, or hand in the exported PNG.

WHICH TEXTURES EACH FAMILY NEEDS
  The resource panel has three looks (European, Asian, Native); the game shows each civ one of
  them (read from this copy). Every family restyles the shared pieces, and only the resource
  panel look its civs see.
  Shared by every family (pieces of a resource panel look excepted):
    button, button_clicked, button_disabled
    button_rollover, ingame_ui_01, ingame_ui_02x_ypack
    ingame_ui_small_01_ypack, ingame_ui_small_02_ypack, ingame_ui_small_03x_ypack
    ingame_ui_small_04x_ypack, ingame_ui_tab_command_ypack, mission_objectives
    objective_counter, ui_health_bar, warwick_timer_panel
  European resource panel: eur_max_ui, ingame_ui_small_01_ypack (piece 21)
  Asian resource panel: asi_ui_max, ingame_ui_small_01_asian
  Native resource panel: nat_ui_max
  eu  Europeans (Austrohungarians, Belgians, British, Danish, Dutch, French, Germans, Italians, Portuguese, Russians, Spanish, Swedish, Ottomans): the shared ones + the European resource panel
  an  Anglos (UnitedStates, Australians, Canadians): the shared ones + the European resource panel
  la  Latin Americans (Argentineans, Bolivians, Brazilians, Centralamericans, Chileans, Colombians, Haitians, Mexicans, Paraguayans, Peruvians, Uruguayans): the shared ones + the European resource panel
  ns  Nation states (Bulgarians, Greeks, Romanians, Serbians): the shared ones + the European resource panel
  af  Africans (Ethiopians, Zulu): the shared ones + the Asian resource panel
  as  Asians (Chinese, Indians, Japanese, Koreans): the shared ones + the Asian resource panel
  me  Middle East (Afghans, Egyptians, Persians, Saudis, Uzbeks): the shared ones + the European and Asian resource panel
  na  Native Americans (XPIroquois, XPSioux, WallMapu): the shared ones + the Native resource panel
  po  Polynesians (Maori): the shared ones + the Asian resource panel

LEFT OUT (small textures, under 65 px on their longer side; they keep today's look)
  background_black 8x8, background_blue_c 64x64, in_game_chat_left 64x32
  in_game_chat_mid 64x32, in_game_chat_right 64x32, ingame_minimap_small_chat_active_ypack 64x64
  ingame_minimap_small_chat_depressed_ypack 64x64, ingame_minimap_small_chat_normal_ypack 64x64, ingame_minimap_small_flare_active_ypack 64x64
  ingame_minimap_small_flare_depressed_ypack 64x64, ingame_minimap_small_flare_normal_ypack 64x64, ingame_minimap_small_tribute_active_ypack 64x64
  ingame_minimap_small_tribute_depressed_ypack 64x64, ingame_minimap_small_tribute_normal_ypack 64x64, ingame_ui_health_green 16x8
  ingame_ui_health_red 16x8, ingame_ui_health_yellow 16x8, outline_bottom_left 4x4
  outline_bottom_middle 4x4, outline_bottom_right 4x4, outline_side_left 4x4
  outline_side_right 4x4, outline_top_left 4x4, outline_top_middle 4x4
  outline_top_right 4x4
  (tools/make_ui_templates.py templates --all makes templates for them too.)

TEXTURES AND PIECES
  asi_ui_max.psd  1024x1024
      1 Resource panel advanced, Asian (SettlerCountDialog-advancedPanelAsiMin): 246x287 px at 440,737; shown: when the game shows it; Asian resource panel skin
  button.psd  128x32
      2 Menu button, normal (InGameMenu-ReturntoGame, InGameMenu-DiplomacyGame, InGameMenu-SaveGame +36): 106x22 px at 0,0, x2.55 y1.69 enlarged uneven; shown: when the game shows it
      3 Menu button, normal (objectivesDialogButton, minimapPanel-menubutton, PlayerStatusButton +2): 107x23 px at 0,0, x2.58 y1.66 enlarged uneven; shown: always
  button_clicked.psd  128x32
      4 Menu button, pressed (InGameMenu-ReturntoGame, InGameMenu-DiplomacyGame, InGameMenu-SaveGame +36): 106x22 px at 0,0, x2.55 y1.69 enlarged uneven; shown: when the game shows it
      5 Menu button, pressed (objectivesDialogButton, minimapPanel-menubutton, PlayerStatusButton +2): 107x23 px at 0,0, x2.58 y1.66 enlarged uneven; shown: always
  button_disabled.psd  128x32
      6 Menu button, disabled (objectivesDialogButton, minimapPanel-menubutton, PlayerStatusButton +2): 107x23 px at 0,0, x2.58 y1.66 enlarged uneven; shown: always
  button_rollover.psd  128x32
      7 Menu button, mouse over (InGameMenu-ReturntoGame, InGameMenu-DiplomacyGame, InGameMenu-SaveGame +36): 106x22 px at 0,0, x2.55 y1.69 enlarged uneven; shown: when the game shows it
      8 Menu button, mouse over (objectivesDialogButton, minimapPanel-menubutton, PlayerStatusButton +2): 107x23 px at 0,0, x2.58 y1.66 enlarged uneven; shown: always
  eur_max_ui.psd  1024x1024
      9 Resource panel advanced, European (SettlerCountDialog-advancedPanelEurMin): 241x272 px at 445,752; shown: when the game shows it; European resource panel skin
  ingame_ui_01.psd  512x512
     10 Shipment timer bar, full (shipsTimerFG): 100x11 px at 355,315; shown: usually shown: the shipment counter (a player with a home city)
     11 Shipment counter (shipsDisplayBG): 29x25 px at 353,332, x1.10 y1.12 enlarged uneven; shown: usually shown: the shipment counter (a player with a home city)
     12 Shipment timer bar, empty (shipsTimerBG): 100x11 px at 355,366; shown: usually shown: the shipment counter (a player with a home city)
  ingame_ui_02x_ypack.psd  1024x1024
     13 Age-up bar, full (uimain-AgeAdvFG): 338x38 px at 624,310; shown: advancing to the next age (its progress)
     14 Age box (uimain-Score): 456x74 px at 566,394; shown: always
     15 Age-up bar, empty (uimain-AgeAdvBG): 338x38 px at 624,410; shown: always
  ingame_ui_small_01_asian.psd  1024x1024
     16 Resource panel, Asian (SettlerCountDialog-defaultPanelAsiMin): 246x285 px at 440,453; shown: Asian resource panel skin
  ingame_ui_small_01_ypack.psd  1024x1024
     17 Train and hold row (trainsandcontains-row0, trainsandcontains-row1, trainsandcontains-row2): 656x78 px at 0,0; shown: what a building trains and holds
     18 Command panel (commandpanel2-main): 656x228 px at 0,0; shown: always
     19 Command panel bottom strip (commandpanel2commands): 656x44 px at 0,348; shown: always
     20 Minimap frame (minimapPanel): 684x276 px at 0,746; shown: always
     21 Resource panel, European (SettlerCountDialog-defaultPanelEurMin): 244x277 px at 691,747; shown: European resource panel skin
  ingame_ui_small_02_ypack.psd  512x512
     22 Selection panel (unitselectionpanel-unit): 352x138 px at 0,0, x1.91 y1.43 enlarged; shown: usually shown: a unit selected
     23 Unit stats panel (unitstatpanel3-back): 328x114 px at 0,284, x1.85 y1.44 enlarged; shown: the unit information tab
     24 Unit count badge (unitselectionpanel-unitPortraitCountBackground): 32x32 px at 441,322, x1.88 y1.41 enlarged; shown: usually shown: a unit selected
     25 Unit stack button (unitselectionpanel-unitStackButtonBigBackground): 36x36 px at 439,370, x1.88 y1.41 enlarged; shown: usually shown: a unit selected
  ingame_ui_small_03x_ypack.psd  512x256
     26 Trade route panel (traderoutepanel2, nativecommandpanel2): 328x117 px at 0,0, x1.85 y1.42 enlarged; shown: a trade route selected | a native settlement selected
  ingame_ui_small_04x_ypack.psd  512x256
     27 Building site panel (SocketPanel2, TreasurePanel): 329x136 px at 0,0, x1.85 y1.45 enlarged; shown: when the game shows it
  ingame_ui_tab_command_ypack.psd  128x1024
     28 Commands tab, front (unitselectionpanel-showCommands, unitselectionpanel-showStats): 128x220 px at 0,0, x0.40 y0.35 uneven; shown: usually shown: a unit selected
  mission_objectives.psd  512x64
     29 Message window (messageWindow): 512x64 px at 0,0, tiled; shown: when the game shows it
  nat_ui_max.psd  1024x1024
     30 Resource panel, Native (SettlerCountDialog-defaultPanelNatMin): 252x284 px at 445,296; shown: Native resource panel skin
     31 Resource panel advanced, Native (SettlerCountDialog-advancedPanelNatMin): 246x285 px at 440,739; shown: when the game shows it; Native resource panel skin
  objective_counter.psd  512x32
     32 Victory timer (victoryTimerDisplay0, victoryTimerDisplay1, victoryTimerDisplay2): 340x32 px at 172,0, x1.88 y1.41 enlarged; shown: victory display and timers
  ui_health_bar.psd  128x16
     33 Health bar, frame (unitselectionpanel-unitHealthBarGreen, unitselectionpanel-unitHealthBarYellow, unitselectionpanel-unitHealthBarRed): 128x16 px at 0,0, x1.03 y0.62 uneven; shown: usually shown: a unit selected; green only | usually shown: a unit selected; yellow only | usually shown: a unit selected; red only
  warwick_timer_panel.psd  512x128
     34 Game clock (clockTimer): 389x74 px at 0,0, x1.87 y1.40 enlarged; shown: a game clock (a timer of the map)

PREVIEW WITHOUT THE GAME (for the person with aoe3-blender-tools)
  python -I tools/make_ui_templates.py build --game <copy> --in <filled files> --suffix as --out <dir>
  python -I tools/ui_preview.py --game <copy> --scene min --size 1920x1080 --culture Asi \
      --override <dir> --suffix as --out preview.png
  (--culture: the resource panel look of the family, Eur, Asi or Nat.)

reference_sheet.png shows the interface with every piece numbered and each texture with the same
numbers. pieces.json is the same map for tools.
