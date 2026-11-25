# Player names with accents in the map triggers

**The bug.** A player name with a letter outside plain ASCII (an accent: 13 of the AI names in WoL's Spanish
translation, 5 in English, and any human name with one) or with a quote stops the whole trigger script of every
map that calls `wotta_triggers()` (193 of the RM4 maps). The game then runs with no trigger at all: no King of the
Hill, none of WoL's own triggers, no observer panel. Nothing shows on screen; the log says
`trigtemp.xs: Token Error 0008: string not terminated` and `Error 0003: could not compile file 'trigtemp.xs'`.
Found in the 2026-11-17 map sweep (`docs/wol-maps.md`), seen again in the observer tests of #81.

**The cause.** `RM4\triggers\triggerLoader.xs` (the same file is in `RM3\triggers`) builds two messages per player
when the map is generated:

```
rmSetTriggerEffectParam("Text", rmGetPlayerName(i)+" has entered the Great War Age!");
rmSetTriggerEffectParam("Text", rmGetPlayerName(i)+" has started the Inquisition!");
```

The game writes them into the trigger script as string literals, `trOverlayText("Carlos el Diplomático has entered
the Great War Age!", ...)`, and the script compiler refuses a byte above 7Fh inside a literal (and a quote ends it).

**The fix** (`apply_fix.py`). The messages no longer carry the name; they ask for it when the trigger runs, as WoL's
`culture_music.xs` already does for the civ name:

```
rmSetTriggerEffectParam("Text", "\"+kbGetPlayerName("+i+")+\" has entered the Great War Age!");
```

which the game writes as `trOverlayText(""+kbGetPlayerName(2)+" has entered the Great War Age!", ...)`. It compiles
whatever the name is, and the message shows the name as the game has it, accents included. One file changes (and
its RM3 copy, and `greatwar.xs`, which has the same line but is not included today); no new trigger effect, nothing
else in the maps.

```
python apply_fix.py "<WoL folder>"            apply (originals kept as <file>.names-orig)
python apply_fix.py "<WoL folder>" --check    what is applied
python apply_fix.py "<WoL folder>" --restore  the originals back
```

**Tested** (2026-11-25, single player, a copy of WoL 1.0.15c in Spanish, 3-player skirmishes against Carlos el
Diplomático, with an accent, and Otto Von Bismarck):

| Map | Before | After |
|---|---|---|
| `ESOC_Adirondacks` | `Token Error 0008` at the accented player's message: no trigger runs | no XS error |
| `Arabia` | the same | no XS error |
| `California` | - | no XS error |
| `Ceylon` | - | no XS error |
| `DansilAlaska` | - | no XS error |

On `Arabia`, with both AIs given the Great War by a test trigger, the alarm showed "Carlos el Diplomático has
entered the Great War Age!" and "Otto Von Bismarck has entered the Great War Age!" on screen, the accent drawn
(picture `07-accented-ai-name-great-war-message.jpg` in the share folder). The change is in the triggers only: the
map generation does not use these lines. The test copy was restored afterwards.

This replaces the 2026-11-17 proposal in `wol-fixes/maps/` (a new effect "Overlay Text Player Name" in
`trigger3\wotta triggers.xml` plus the same two lines): it needs one file instead of two.
