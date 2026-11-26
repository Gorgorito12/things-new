SELECT THE FATTENED LIVESTOCK (request #106)
=============================================

AN OPTIONAL PACK. Nothing changes until apply_fix.py is run. It needs the DLL key selectFattened (apply_fix.py adds
the line to Startup\wol.cfg).

What it does
------------
A square button just above the resource panel's left end, beside the home city flag, shows how many of your livestock (sheep, cows,
goats, llamas, camels, hens... any unit of type Herdable) have reached their maximum food. Clicking it selects all
of them, on the whole map, as a click on them would; the selection panel then shows them as usual. With more than
the selection limit (50, or the key selectionLimit: 75 in WoL), the ones nearest the centre of the screen are
selected. The button hides when there are none. Shift+Ctrl+F does the same ("Select Fattened Livestock", in the
hotkey menu's group "Find Unit Hotkeys"). Its tooltip: "Fattened livestock: 9. Click to select them (Shift+Ctrl+F)."

It only changes your own selection: nothing goes to the other players, and the game is not changed.

Layout map (size1024 units; at 1920 x 1080 a unit is 1.875 px wide and 1.406 px high)
-------------------------------------------------------------------------------------
    uhcFattened            249 594 270 623   hidden; the key shows it while the count is above 0
      uhcFattened-button   249 594 270 623   the icon (40 x 40 px at 1080p), <command>uhcSelectFattened</command>
      uhcFattened-count    260 609 270 623   {uhcFattened}, NumbersFont 12, white, centred in the button's bottom right

Why there: the home city flag (uimain-homeCityToggle, 194 605 246 645 in uiminimappanelnew.xml and
uiminimappanelnewmin.xml) sits on the panel's left corner in a game with a home city, so the button is right of it.
The resource panel's 12 variants (SettlerCountDialog-*) start their art at y 625 to 639, below the button. No other
gadget of the game screen's layouts (uimainnew, uiminimappanelnew*, the oil and faith panel packs' 6 layouts) meets
its box. It is a top-level gadget at the end of data\uimainnew.xml, outside the panel's block, so the oil and faith
panel packs (wol-fixes\oil-panel, wol-fixes\faith-panel) apply and restore as before. With both, restore in the
reverse order of applying: each pack's backup holds the files as they were when it was applied, so restoring the
first-applied pack first puts back files without the other pack's changes and leaves the other pack's backup wrong.

Installing
----------
    python apply_fix.py "<WoL folder>"              apply (backup in <WoL folder>\select-fattened-backup\)
    python apply_fix.py "<WoL folder>" --check      what is applied (exit code 0 only when all is)
    python apply_fix.py "<WoL folder>" --restore    the backed-up files back, byte for byte; the icon deleted

Only the hotkey, without the button:

    python apply_fix.py "<WoL folder>" --hotkey-only    the keymap entry, its name and the cfg line only

This leaves data\uimainnew.xml alone, adds no icon and no tooltip string (690911): it changes data\DefaultKeyMapY.xml,
string 690912 (the hotkey's name in the hotkey menu) in the three string tables, and Startup\wol.cfg. --check and
--restore work the same way: they read which mode was applied from the backup (select-fattened-backup\manifest.json).
The DLL key needs no other setting: with no button in the layout it only looks for one every 2 seconds (with
"selectFattened log" it says so once in the log). To change modes, --restore first, then apply the other way.

Files: adds art\ui\ingame\uhc_select_fattened.ddt (64 x 64, drawn by aoe3-blender-tools' make_command_icon.py
--glyph fattened); changes data\uimainnew.xml (one gadget before </layout>), data\DefaultKeyMapY.xml (one entry after
"Find Idle Military"; refused if shift-control-f is already bound), strings 690911 and 690912 in data\stringtabley.xml,
translations\_originals (English) and translations\ES-LA (Spanish), and Startup\wol.cfg (the line selectFattened).

Limits
------
- A player who saved custom hotkeys keeps them; the new entry is added to the defaults.
- The observer layouts (uimainnewobserver*.xml) get no button: an observer has no livestock of its own.

---------------------------------------------------------------------------------------------------------------------
(Español)

Un botón encima del panel de recursos, a su izquierda, muestra cuántos animales de ganado tuyos llegaron a su máximo
de comida y los selecciona al pulsarlo, en todo el mapa; si pasan del límite de selección, los más cercanos al centro
de la pantalla. Se oculta cuando no hay ninguno. Mayús+Ctrl+F hace lo mismo. Solo cambia tu selección.
Con --hotkey-only se instala solo la tecla (Mayús+Ctrl+F), sin el botón ni su icono.
