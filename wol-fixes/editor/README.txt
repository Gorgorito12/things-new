SCENARIO EDITOR SEARCH FOR WARS OF LIBERTY (request #82, first part)
===================================================================

What it does
------------
With the DLL key `editorSearch`, two lists of the scenario editor get a search field:

  - the Objects palette (Place Object): a "Search:" field to the right of the category list;
  - the Forbidden Units/Techs dialog (Scenario > Forbidden Units/Techs): a "Search:" field under the
    "Allowed" list, for units and for techs.

Type part of a name and the list keeps only the entries that match, as you type. Upper and lower case do not
matter. Several words narrow it down: every word must be found ("inf musk" finds "INF R-LU Musketeer" but not
"Musk Ox"). A unit is found by the name the palette shows (WoL's "INF R-SK Forest Prowler") and by its internal
name (xpMusketWarrior); a tech by its internal name, which is what the dialog shows. Erase the text and the full
list comes back.

It works with everything else in those lists:
  - the palette's category list (All, Units, Buildings, Nature...) still applies: "musk" in Nature shows the Musk
    Deer and the Musk Ox only;
  - an entry picked from a filtered palette is placed as usual;
  - in the Forbidden dialog, "Add" and "Remove" work on the filtered list, and switching between "Display Units"
    and "Display Techs" keeps the search;
  - leaving the editor clears the fields.

It changes nothing else: nothing is saved in the scenario, nothing reaches a game, and a cfg without the key
shows the field but does not filter.

Files
-----
  files\data\uieditorpalettes.xml       the game's Objects and Terrain palettes, plus the field
                                        EditorProtoPaletteSearch and its "Search:" label inside the Objects
                                        palette (copy of the file in Data3.bar)
  files\data\uiforbiddenunitstechs.xml  the Forbidden Units/Techs dialog, plus the field ForbiddenUnitsTechs_Search
                                        and its label under the Allowed list (copy of the file in Data2.bar)
  media\                                screenshots (English), taken in a WoL copy with the DLL

To install
----------
1. Copy the two files of files\data into WoL's data folder (they are new loose files: nothing of WoL's is
   overwritten; WoL's own uieditormenu.xml is not touched).
2. Add a line to Startup\wol.cfg:

       editorSearch

   (`editorSearch log` also writes each search to UHC.log: "editorSearch: Objects palette "musk": 9 shown,
   3202 hidden (181.5 ms)").

Without the two files the key does nothing visible (the lists stay as they are, and the log says the field is
missing). Without the key the fields show but do not filter.

Screenshots
-----------
  palette-empty.png          the Objects palette with the empty field (the full list)
  palette-musk.png           "musk": 9 entries (musketeers, musket riders, Musk Deer, Musk Ox)
  palette-two-words.png      "INF musk": the 4 infantry ones
  palette-prowler.png        "prowler": found by the names the palette shows
  palette-category.png       "musk" with the category Nature: Musk Deer and Musk Ox
  palette-placed.jpg         a Forest Prowler picked from a filtered list and placed
  palette-reopened.png       the editor left and opened again: the field is empty, the list full
  forbid-units-musket.png    Forbidden Units/Techs, "musket": 7 units
  forbid-added.png           Musketeer added to the forbidden list from the filtered list
  forbid-techs-musket.png    "Display Techs" with the same search
  forbid-cleared.png         the field erased: the full list, without the forbidden Musketeer
  nolayout.jpg               the key on with the game's own layouts: the stock dialog and palette

Not in this part
----------------
Triggers (the condition and effect types and the unit and tech lists of their parameters) are not searchable
yet: those lists are built differently, and they are the next step of #82.
