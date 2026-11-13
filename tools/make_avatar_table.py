"""Writes the avatar table of playerIcon from the pictures a WoL install already ships.

    python -I tools/make_avatar_table.py <WoL folder> [--out <file>]

Reads the WoL folder (nothing in it is changed except the output file) and writes an avatar table, by default
<WoL folder>\\data\\avatar_wol.xml, that names:

  1. every art\\spec\\avatars\\*.ddt, the player pictures WoL's observer files show by player name;
     ID = the file name in lower case (e.g. kaiserklein);
  2. the portrait of every public civ, the <portraittexture> of <matchmakingtextures> in data\\civs.xml when it is a
     cpai_avatar_* texture; ID = civ_ + the civ's <name> in lower case (e.g. civ_dutch). Skipped: the civs that are
     not public (Tawantinsuyu, Tupinamba, XPAztec), a civ with <visible>0</visible> (the campaign's), and a civ
     whose portrait is another texture.

A texture is listed only when it exists, loose under art\\ or inside art\\*.bar; a missing one is reported and
skipped. Every picture is square (64 x 64 avatars, 128 x 128 portraits); the lobby shows it at 48 x 48. Players
pick one with `playerIcon <id>` in their cfg. The tool copies no picture and writes only the table.
"""
import pathlib
import re
import sys
from xml.sax.saxutils import escape, quoteattr

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bar  # noqa: E402

NOT_PUBLIC = {"tawantinsuyu", "tupinamba", "xpaztec"}
HEADER = "<!-- WoL's own pictures for playerIcon, listed by tools/make_avatar_table.py. -->"


def archived_textures(art):
    """The lower-case paths, below art\\ and without .ddt, of the textures inside art\\*.bar."""
    names = set()
    for archive in sorted(art.glob("*.bar")):
        for stored, _offset, _size in bar.read_entries(archive):
            path = stored.replace("/", "\\").lower()
            if path.startswith("art\\"):
                path = path[4:]
            if path.endswith(".ddt"):
                names.add(path[:-4])
    return names


def exists(art, archived, texture):
    return (art / (texture.replace("\\", "/") + ".ddt")).is_file() or texture.lower() in archived


def player_avatars(art):
    folder = art / "spec" / "avatars"
    files = sorted(folder.glob("*.ddt"), key=lambda p: p.stem.lower()) if folder.is_dir() else []
    return [(p.stem.lower(), "spec\\avatars\\" + p.stem) for p in files]


def civ_portraits(wol):
    civs = wol / "data" / "civs.xml"
    if not civs.is_file():
        sys.exit(f"make_avatar_table: {civs} not found (WoL ships it as plain XML)")
    text = civs.read_bytes().decode("utf-8-sig", "replace")
    found, skipped = [], []
    for body in re.findall(r"<civ>(.*?)</civ>", text, re.S | re.I):
        name = re.search(r"<name>\s*(.*?)\s*</name>", body, re.S | re.I)
        textures = re.search(r"<matchmakingtextures>(.*?)</matchmakingtextures>", body, re.S | re.I)
        portrait = textures and re.search(r"<portraittexture>\s*(.*?)\s*</portraittexture>", textures.group(1),
                                          re.S | re.I)
        if not name or not portrait:
            continue
        name, portrait = name.group(1), portrait.group(1)
        if name.lower() in NOT_PUBLIC:
            skipped.append(f"{name} (not public)")
        elif re.search(r"<visible>\s*0\s*</visible>", body, re.I):
            skipped.append(f"{name} (visible 0)")
        elif "cpai_avatar_" not in portrait.lower():
            skipped.append(f"{name} (portrait {portrait})")
        else:
            found.append(("civ_" + name.lower(), portrait))
    return found, skipped


def table(entries):
    lines = ['<?xml version="1.0" encoding="utf-8"?>', HEADER, "<avatars>"]
    for avatar_id, texture in entries:
        lines.append(f"  <avatar id={quoteattr(avatar_id)}><image>{escape(texture)}</image></avatar>")
    lines.append("</avatars>")
    return ("\r\n".join(lines) + "\r\n").encode("utf-8")


def main(argv):
    args = list(argv)
    out = None
    if "--out" in args:
        i = args.index("--out")
        if i + 1 >= len(args):
            sys.exit("--out needs a file")
        out = pathlib.Path(args[i + 1])
        del args[i:i + 2]
    if len(args) != 1:
        sys.exit(__doc__)
    wol = pathlib.Path(args[0])
    art = wol / "art"
    if not (wol / "data").is_dir() or not art.is_dir():
        sys.exit(f"make_avatar_table: {wol} has no data and art folders")
    out = out or wol / "data" / "avatar_wol.xml"
    if out.exists() and HEADER.encode() not in out.read_bytes():
        sys.exit(f"make_avatar_table: {out} exists and was not written by this tool; give another --out")

    archived = archived_textures(art)
    portraits, skipped = civ_portraits(wol)
    entries, missing, seen = [], [], set()
    for group in (player_avatars(art), portraits):
        for avatar_id, texture in group:
            if avatar_id in seen:
                missing.append(f"{avatar_id} (duplicate ID)")
            elif not exists(art, archived, texture):
                missing.append(f"{avatar_id} (art\\{texture}.ddt missing)")
            else:
                seen.add(avatar_id)
                entries.append((avatar_id, texture))

    out.write_bytes(table(entries))
    players = [i for i, _ in entries if not i.startswith("civ_")]
    civs = [i for i, _ in entries if i.startswith("civ_")]
    print(f"make_avatar_table: wrote {out}, {len(entries)} avatars")
    print(f"  player avatars ({len(players)}): {' '.join(players)}")
    print(f"  civ portraits ({len(civs)}): {' '.join(civs)}")
    for line in skipped:
        print(f"  skipped civ: {line}")
    for line in missing:
        print(f"  skipped: {line}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
