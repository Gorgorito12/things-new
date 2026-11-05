"""Leave some AI personalities in a test copy, so that a random AI in a skirmish is one of them.

    python -I tools/ai_personality.py <bed> <personality> ...   e.g. C:\\AoE3-UHC-WoLReal wolOtto (Germans)
    python -I tools/ai_personality.py <bed> restore

Leave one per AI, each of a civ the human player does not have: an AI left with no personality free
starts with no civ, and the game falls at 0x7C252C.

A personality forces its civ (<forcedciv>) and wins over gameplayer2civ in the profile, so the saved
setup cannot choose the AI's civ. The others wait in AI4\\_uhc-aside until `restore`. The game must be
closed. Only test copies: the script refuses a path under steamapps.
"""
import pathlib
import sys


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    bed, names = pathlib.Path(argv[0]), argv[1:]
    if "steamapps" in str(bed).lower():
        print("ai_personality: refused: test copies only")
        return 1
    folder = bed / "AI4"
    if not folder.is_dir():
        folder = bed / "AI3"
    aside = folder / "_uhc-aside"
    if names[0].lower() == "restore":
        moved = list(aside.glob("*"))
        for path in moved:
            path.rename(folder / path.name)
        aside.rmdir()
        print(f"ai_personality: {len(moved)} personalities back")
        return 0
    for name in names:
        if not (folder / f"{name}.personality").exists():
            print(f"ai_personality: no {name}.personality in {folder}")
            return 1
    aside.mkdir(exist_ok=True)
    keep = {name.lower() for name in names}
    others = [p for p in folder.glob("*.personality") if p.stem.lower() not in keep]
    for path in others:
        path.rename(aside / path.name)
    print(f"ai_personality: {len(others)} moved aside, {' '.join(names)} left")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
