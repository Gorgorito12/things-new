SCENARIO EDITOR SEARCH FOR WARS OF LIBERTY (request #82)
=========================================================

What it does
------------
With the DLL key `editorSearch`, three places of the scenario editor get a search field:

  - the Objects palette (Place Object): a "Search:" field to the right of the category list;
  - the Forbidden Units/Techs dialog (Scenario > Forbidden Units/Techs): a "Search:" field under the "Allowed" list,
    for units and for techs;
  - the trigger editor's Conditions / Effects panel: a "Search:" field on the row of "Type:". It filters the Type
    list and the unit, unit type and tech lists of the condition or effect open below;
  - the trigger editor's list of triggers (the "Trigger Editor" panel on the left): a "Search:" field above "Group:".
    It filters the triggers of the group shown, by name. The trigger being edited always stays in the list.

Type part of a name and the list keeps only the entries that match. Upper and lower case do not matter. Several words
narrow it down: every word must be found ("inf musk" finds "INF R-LU Musketeer" but not "Musk Ox"). A unit is found by
the name the list shows (the palette's "INF R-SK Forest Prowler"), by its internal name (xpMusketWarrior) and by its
display name; a tech by its internal name, which is what the lists show. Erase the text and the full list comes back.
The list follows the text once the typing pauses for a quarter of a second (the palette takes the game about 0.2 s to
refill, so a word typed at speed refills it once).

In the trigger editor one field serves every list of the panel, so a list where nothing matches keeps all its
entries: "create" narrows the Type list to the ten "... Create ..." types and leaves the unit list whole; "musket"
matches no type, so the Type list stays whole, and narrows the unit list (ProtoName) to the musketeers. A parameter's
current value always stays in its list, so its field keeps showing it. The value saved is the name you pick, exactly
as from the full list (tested: saved, editor left, scenario loaded again).

The list of triggers has its own field. A trigger picked from a short list is that trigger: the game gives each row
its trigger's place in the group, and a click reads that, not the row (tested: its conditions, effects and a Loop
change all went to the trigger picked, and the full list showed the same). The text stays when you change group;
Insert and Del work as usual (the new trigger shows, being the one edited). To make room for the field, the Trigger
Editor panel now starts as high as the Triggers panel next to it, and its search row is level with the Conditions /
Effects panel's.

It works with everything else in those lists:
  - the palette's category list (All, Units, Buildings, Nature...) still applies: "musk" in Nature shows the Musk
    Deer and the Musk Ox only;
  - an entry picked from a filtered palette is placed as usual;
  - in the Forbidden dialog, "Add" and "Remove" work on the filtered list, and switching between "Display Units"
    and "Display Techs" keeps the search;
  - leaving the editor clears the fields.

It changes nothing else: nothing is saved in the scenario but the values you pick, nothing reaches a game, and a cfg
without the key shows the fields but does not filter.

Files
-----
  files\data\uieditorpalettes.xml       the game's Objects and Terrain palettes, plus the field
                                        EditorProtoPaletteSearch and its "Search:" label inside the Objects
                                        palette (copy of the file in Data3.bar)
  files\data\uiforbiddenunitstechs.xml  the Forbidden Units/Techs dialog, plus the field ForbiddenUnitsTechs_Search
                                        and its label under the Allowed list (copy of the file in Data2.bar)
  files\data\uitriggereditor.xml        the trigger editor, plus the field trEdit-CondEffPanel-search and its label
                                        in the Conditions / Effects panel, and trEdit-Trigger-search and its label
                                        above the list of triggers (copy of the file in Data3.bar)
  apply_fix.py                          installs the three files and the cfg line (see below)
  media\                                screenshots (English), taken in a WoL copy with the DLL

To install
----------
With Python 3:

    python apply_fix.py <WoL folder>             copies the three files and adds the line below to Startup\wol.cfg
    python apply_fix.py <WoL folder> --check     says what is applied
    python apply_fix.py <WoL folder> --restore   puts everything back as it was (from <WoL folder>\editor-backup)

By hand:
1. Copy the three files of files\data into WoL's data folder (they are new loose files: nothing of WoL's is
   overwritten; WoL's own uieditormenu.xml is not touched).
2. Add a line to Startup\wol.cfg:

       editorSearch

   (`editorSearch log` also writes each search to UHC.log: "editorSearch: Objects palette "musk": 9 shown,
   3202 hidden (181.5 ms)", "editorSearch: trigger parameter list "cavalry": 13 of 3634", "editorSearch: trigger list
   "captain": 4 shown, 23 hidden (0.1 ms)").

Without a file the key does nothing visible there (the list stays as it is, and the log says the field is missing).
Without the key the fields show but do not filter.

Screenshots
-----------
  palette-empty.png             the Objects palette with the empty field (the full list)
  palette-musk.png              "musk": 9 entries (musketeers, musket riders, Musk Deer, Musk Ox)
  palette-two-words.png         "INF musk": the 4 infantry ones
  palette-prowler.png           "prowler": found by the names the palette shows
  palette-category.png          "musk" with the category Nature: Musk Deer and Musk Ox
  palette-placed.jpg            a Forest Prowler picked from a filtered list and placed
  palette-reopened.png          the editor left and opened again: the field is empty, the list full
  palette-keyoff.png            key off: the field takes the text, the palette stays full
  forbid-units-musket.png       Forbidden Units/Techs, "musket": 7 units
  forbid-added.png              Musketeer added to the forbidden list from the filtered list
  forbid-techs-musket.png       "Display Techs" with the same search
  forbid-cleared.png            the field erased: the full list, without the forbidden Musketeer
  nolayout.jpg                  the key on with the game's own palette and dialog layouts: stock
  trigger-panel.png             the Effects panel with the new field next to "Type:", and the list of triggers
                                with its own field ("training")
  trigger-list-training.png     "training": the list keeps 2 of 27 triggers; P2_LandTrainingKicker picked shows its
                                own 4 conditions and 5 effects
  trigger-type-create.jpg       "create": the Type list keeps the 10 "... Create ..." effects
  trigger-unit-musket.jpg       "musket" with Unit Create: the Type list stays whole, ProtoName keeps 6 units
  trigger-tech-guard-musket.png condition Tech Status Equals, "guard musket": the Tech list keeps 2 of 10,542 techs
  trigger-unittype-cavalry.png  Unit Create at Unittype, "cavalry": the unit type list keeps 25
  trigger-value-kept.jpg        the value set (Musketeer) stays in a list filtered by "cavalry"
  trigger-reloaded-effect.png   after saving and loading the scenario: Unit Create / CavalryArcher, picked filtered
  trigger-reloaded-condition.png  Tech Status Equals / GuardMusketeers, picked filtered
  trigger-nolayout.jpg          the key on with the game's own uitriggereditor.xml: stock
  trigger-keyoff.jpg            key off: the field takes the text, every list stays full

Not covered
-----------
The other parameter lists of the trigger editor (players, resources, areas, sounds...) are not filtered; they are
short.
