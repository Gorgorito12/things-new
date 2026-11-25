RANGE RINGS IN THE OPTIONS MENU FOR WARS OF LIBERTY (2026-11-25)
================================================================

What it does
------------
The player turns the range rings of the DLL key `displayedRange` on or off in the game's options menu:

  Options -> UI Options -> Game UI Options -> "Show Range Rings" (a check box, right under "ALT key shows hitpoint
  bars"), with the tooltip "Shows how far the selected units and buildings shoot, as rings on the ground, and the
  range of a building while you place it. Takes effect at once."

The change shows as soon as the player clicks OK, with no restart:
  - in the main menu, for the next match;
  - during a match (Menu -> Options): the rings of the selected units, and of a building being placed, come or go as
    the game resumes. In single player every row of the options screen can be changed during a match.

The choice is kept in uhc-options.cfg next to UHC.log (engine-ext\ with our dinput8.dll), not in the profile, and is
used at every start. Until the player chooses, the rings are on (the pack adds the `displayedRange` line).

Installing
----------
  python apply_fix.py "<WoL folder>"             applies it, with a backup in <WoL folder>\options-menu-backup
  python apply_fix.py "<WoL folder>" --check     says what is applied
  python apply_fix.py "<WoL folder>" --restore   puts the files back as they were (byte for byte)

Files it changes:
  data\options.xml            the field OptionDisplayedRange, after the OptionShowHPOnAlt field (or at the end of
                              the first section if the file has no such field)
  Startup\wol.cfg             `menuOptions displayedRange` and `displayedRange`, each only when missing; a
                              `displayedRange` line already there keeps its arguments (noPlacement, log)
  engine-ext\engine-ext.cfg   the same, when the folder has one (our dinput8.dll beside WoL's own DLL)

The field, if you prefer to add it by hand:

    <field>
        CheckBox
        <name>OptionDisplayedRange</name>
        <label>Show Range Rings</label>
        <tooltip>Shows how far the selected units and buildings shoot, as rings on the ground, and the range of a building while you place it. Takes effect at once.</tooltip>
    </field>

The label and the tooltip are free text (a $$<id>$$ string ID works too, as in the other fields). The <name> is fixed.
A DropDown with two <value> lines, Off first, works as well.

IMPORTANT: keep the file's Windows line ends (CRLF). WoL's options.xml has them; a field written with Unix line ends
(LF only) in it is left off the screen, with no error and no log line. apply_fix.py keeps the file's line ends and
encoding.

Good to know
------------
- The field does something only with `menuOptions displayedRange` in the cfg. Without that line, the row is an
  unticked check box that does nothing (the game's own behaviour for a name it does not know). Without the field, the
  menu is the stock one.
- The key is applied whether the box is ticked or not: off, it only stops drawing. The rings still need their data
  (<DisplayRange>, <AlwaysDisplayRange> or <DisplayedRange> on the protos; the placement ghost needs nothing) and the
  ring files of tools\rings in art\effects\uhc_rings.
- "Restore Defaults" on the options screen leaves this option alone (it resets the game's own options, the screen
  resolution included).
- Display only: each player may have it on or off.
- The log says `menuOptions: displayedRange follows OptionDisplayedRange: on (...)` at start, and on each OK
  `displayedRange: off chosen in the menu; it takes effect at once` and `displayedRange: off from the options menu`.
