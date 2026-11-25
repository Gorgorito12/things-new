"""Stops a player name with accents (or a quote) from breaking the trigger script of Wars of Liberty's random maps.

    python apply_fix.py <WoL folder>              apply (each file it changes is kept first as <file>.names-orig)
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    python apply_fix.py <WoL folder> --restore    put the kept files back and remove the copies
    (a folder under steamapps is refused unless --force is given)

The cause. WoL's shared trigger library (RM4\\triggers\\triggerLoader.xs, called by wotta_triggers() in 193 maps,
and the same file in RM3\\triggers) gives each player an "Overlay Text" trigger whose text is built when the map is
generated: rmSetTriggerEffectParam("Text", rmGetPlayerName(i)+" has entered the Great War Age!"). The game writes
that text into the trigger script as a string literal, trOverlayText("<name> has entered ...", ...). A name with a
letter outside plain ASCII (13 of the AI names in WoL's Spanish translation, such as Carlos el Diplomatico and
Napoleon III with their accents) or with a quote makes the literal invalid (trigtemp.xs: "Token Error 0008: string not terminated"), the whole trigger script
fails to compile, and the game runs with no trigger at all: King of the Hill, WoL's triggers, the observer panel.

The fix. The text no longer carries the name: it calls kbGetPlayerName(<player>) when the trigger runs, the same way
WoL's culture_music.xs already gets the civ name (kbGetCivName). The trigger script then reads
trOverlayText(""+kbGetPlayerName(3)+" has entered the Great War Age!", ...), which compiles whatever the name is,
and the message shows the name as the game has it, accents included. Every line of the form
rmSetTriggerEffectParam("Text", rmGetPlayerName(i)+"...") in RM3\\triggers\\*.xs and RM4\\triggers\\*.xs changes
(triggerLoader.xs: the Great War and the Inquisition messages; greatwar.xs, not included by WoL today: one). Nothing
else changes; the map generation is the same. Byte-level: encoding and line ends kept.
"""
import pathlib
import re
import sys

KEEP = ".names-orig"
OLD = re.compile(rb'(rmSetTriggerEffectParam\("Text",\s*)rmGetPlayerName\((\w+)\)\s*\+\s*"')
NEW = rb'\1"\\"+kbGetPlayerName("+\2+")+\\"'
DONE = re.compile(rb'rmSetTriggerEffectParam\("Text",\s*"\\"\+kbGetPlayerName\("\+\w+\+"\)\+\\"')


def files(wol):
    for folder in ("RM3", "RM4"):
        yield from sorted((wol / folder / "triggers").glob("*.xs"))


def main(argv):
    if not argv or argv[0].startswith("-"):
        sys.exit(__doc__)
    wol = pathlib.Path(argv[0])
    if not (wol / "RM4" / "triggers").is_dir():
        sys.exit(f"{wol}: no RM4\\triggers folder (give the Wars of Liberty folder)")
    if "steamapps" in str(wol.resolve()).lower() and "--force" not in argv and "--check" not in argv:
        sys.exit("refused: this is a Steam folder (use a copy, or add --force)")
    changed = 0
    for path in files(wol):
        keep = path.with_name(path.name + KEEP)
        now = path.read_bytes()
        if "--check" in argv:
            old, new = len(OLD.findall(now)), len(DONE.findall(now))
            if old or new:
                print(f"{path.relative_to(wol)}: {new} name lines fixed, {old} not fixed"
                      + (" (original kept)" if keep.exists() else ""))
            continue
        if "--restore" in argv:
            if keep.exists():
                path.write_bytes(keep.read_bytes())
                keep.unlink()
                changed += 1
                print(f"{path.relative_to(wol)}: restored")
            continue
        new, n = OLD.subn(NEW, now)
        if not n:
            continue
        if not keep.exists():
            keep.write_bytes(now)
        path.write_bytes(new)
        changed += 1
        print(f"{path.relative_to(wol)}: {n} name lines fixed")
    if "--check" not in argv:
        print(f"{changed} files {'restored' if '--restore' in argv else 'changed'}")


if __name__ == "__main__":
    main(sys.argv[1:])
