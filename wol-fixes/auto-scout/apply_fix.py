"""Gives Wars of Liberty's flying scouts (the Romanian raven, the two pet parrots, the French hot-air balloon)
the auto scout of the DLL key `autoScout`, and the Dutch envoy a pair of buttons to switch it on and off.

    python apply_fix.py <WoL folder>              apply (a backup of every file it changes goes to
                                                  <WoL folder>\\auto-scout-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back and delete the files it added
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

What it changes (README.txt has the why and how to do the same for any unit):
- data\\tactics\\wolautoscoutflyer.tactics (new): the raven's tactics with a tactic "AutoScout" first (so a
  unit with this file scouts from birth) and "Normal" second;
- data\\tactics\\wolenvoyautoscout.tactics (new): the envoy's tactics with "Normal" first and "AutoScout" second
  (off at birth);
- data\\protoy.xml: WOLraven, PetMacaw, PetGreyParrot and WoLHotAirBalloonFrench use the first file and get the
  two buttons on the command row; WOLraven loses its <WanderDistance>; Envoy uses the second file and gets the two buttons;
- data\\protounitcommands.xml: the buttons AutoScoutStart (unitSetTactic("AutoScout")) and AutoScoutStop
  (unitSetTactic("Normal"));
- data\\uhc\\customprotounitcommands.xml: the two command names, which the game must know to keep the buttons;
- data\\stringtabley.xml and translations\\_originals\\stringtabley.xml: the two tooltips, in English (IDs
  690901 and 690902);
- art\\ui\\command\\uhc_autoscout_start.ddt and uhc_autoscout_stop.ddt (new): the button icons.
The key itself goes in Startup\\wol.cfg: `autoScout` (the script adds it when the file has no such line).
"""
import json
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
FILES = HERE / "files"
BACKUP = "auto-scout-backup"

FLYERS = ["WOLraven", "PetMacaw", "PetGreyParrot", "WoLHotAirBalloonFrench"]
ENVOY = "Envoy"
FLYER_TACTICS = "wolautoscoutflyer.tactics"
ENVOY_TACTICS = "wolenvoyautoscout.tactics"
NO_WANDER = ["WOLraven"]
START, STOP = "AutoScoutStart", "AutoScoutStop"
STRINGS = {
    690901: "Auto scout: this unit explores the map on its own, unexplored ground first, until it gets another order.",
    690902: "Stop scouting: this unit stops exploring and waits for orders.",
}
NEW_FILES = [
    "data/tactics/" + FLYER_TACTICS,
    "data/tactics/" + ENVOY_TACTICS,
    "art/ui/command/uhc_autoscout_start.ddt",
    "art/ui/command/uhc_autoscout_stop.ddt",
]
CHANGED = [
    "data/protoy.xml",
    "data/protounitcommands.xml",
    "data/uhc/customprotounitcommands.xml",
    "data/stringtabley.xml",
    "translations/_originals/stringtabley.xml",
    "Startup/wol.cfg",
]
COMMANDS = f"""\t<protounitcommand>\r
\t\t<name>{START}</name>\r
\t\t<icon>art\\ui\\command\\uhc_autoscout_start</icon>\r
\t\t<rollovertextid>690901</rollovertextid>\r
\t\t<command>unitSetTactic("AutoScout")</command>\r
\t</protounitcommand>\r
\t<protounitcommand>\r
\t\t<name>{STOP}</name>\r
\t\t<icon>art\\ui\\command\\uhc_autoscout_stop</icon>\r
\t\t<rollovertextid>690902</rollovertextid>\r
\t\t<command>unitSetTactic("Normal")</command>\r
\t</protounitcommand>\r
"""


def crlf(text):
    return text.replace("\r\n", "\n").replace("\n", "\r\n")


def read_text(path):
    raw = path.read_bytes()
    if raw[:2] == b"\xff\xfe":
        return raw[2:].decode("utf-16-le"), "utf-16"
    if raw[:3] == b"\xef\xbb\xbf":
        return raw[3:].decode("utf-8"), "utf-8-sig"
    return raw.decode("utf-8"), "utf-8"


def write_text(path, text, encoding):
    if encoding == "utf-16":
        path.write_bytes(b"\xff\xfe" + text.encode("utf-16-le"))
    elif encoding == "utf-8-sig":
        path.write_bytes(b"\xef\xbb\xbf" + text.encode("utf-8"))
    else:
        path.write_bytes(text.encode("utf-8"))


def unit_block(text, name):
    """(start, end) of <Unit ... name="name"> ... </Unit> in protoy.xml."""
    m = re.search(r'<Unit\b[^>]*\bname="%s"[^>]*>' % re.escape(name), text)
    if m is None:
        sys.exit(f"apply_fix: protoy.xml has no unit {name}")
    end = text.index("</Unit>", m.end())
    return m.start(), end


def edit_unit(text, name, tactics, columns, no_wander):
    start, end = unit_block(text, name)
    block = text[start:end]
    if f">{START}</Command>" in block:
        return text, False
    block, n = re.subn(r"<Tactics>[^<]*</Tactics>", f"<Tactics>{tactics}</Tactics>", block, count=1)
    if n != 1:
        sys.exit(f"apply_fix: unit {name} has no <Tactics>")
    if no_wander:
        block = re.sub(r"[ \t]*<WanderDistance>[^<]*</WanderDistance>\r?\n", "", block, count=1)
    # The command row (page 10): the game shows command types added by customProtoUnitCommands there, not on the
    # tactics page (page 9), where a unit's ToggleStealth sits.
    used = {int(c) for c in re.findall(r'<Command column="(\d+)" page="10">', block)}
    free = [c for c in range(0, 8) if c not in used][:2]
    lines = "".join(f'\t\t<Command column="{c}" page="10">{cmd}</Command>\r\n' for c, cmd in zip(free, (START, STOP)))
    i = block.index("\t\t<Tactics>")
    block = block[:i] + lines + block[i:]
    return text[:start] + block + text[end:], True


def apply(root):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        sys.exit(f"apply_fix: already applied ({backup} exists); run --restore first")
    for rel in ["data/protoy.xml", "data/protounitcommands.xml", "data/tactics/WOLraven.tactics",
                "data/tactics/envoy.tactics"]:
        if not (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} is missing: is this a Wars of Liberty folder?")
    backup.mkdir()
    manifest = {"changed": [], "added": []}
    for rel in CHANGED:
        if (root / rel).exists():
            (backup / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, backup / rel)
            manifest["changed"].append(rel)

    # New files
    for rel in NEW_FILES:
        src, dst = FILES / rel, root / rel
        if dst.exists():
            sys.exit(f"apply_fix: {dst} exists already")
        dst.parent.mkdir(parents=True, exist_ok=True)
        if src.suffix == ".tactics":
            dst.write_bytes(crlf(src.read_text(encoding="utf-8")).encode("utf-8"))
        else:
            shutil.copy2(src, dst)
        manifest["added"].append(rel)

    # protoy.xml
    path = root / "data/protoy.xml"
    text, enc = read_text(path)
    for name in FLYERS:
        text, _ = edit_unit(text, name, FLYER_TACTICS, None, name in NO_WANDER)
    text, _ = edit_unit(text, ENVOY, ENVOY_TACTICS, None, False)
    write_text(path, text, enc)

    # protounitcommands.xml
    path = root / "data/protounitcommands.xml"
    text, enc = read_text(path)
    if f"<name>{START}</name>" not in text:
        i = text.rindex("</protounitcommands>")
        text = text[:i] + COMMANDS + text[i:]
        write_text(path, text, enc)

    # data\uhc\customprotounitcommands.xml
    path = root / "data/uhc/customprotounitcommands.xml"
    if path.exists():
        text, enc = read_text(path)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        text, enc = '<?xml version="1.0" encoding="utf-8"?>\r\n\r\n<ProtoUnitCommandTypes>\r\n</ProtoUnitCommandTypes>\r\n', "utf-8"
        manifest["added"].append("data/uhc/customprotounitcommands.xml")
    for name in (START, STOP):
        if f">{name}<" not in text:
            i = text.rindex("</ProtoUnitCommandTypes>")
            text = text[:i] + f"    <CommandType>{name}</CommandType>\r\n" + text[i:]
    write_text(path, text, enc)

    # The English string tables
    for rel in ("data/stringtabley.xml", "translations/_originals/stringtabley.xml"):
        path = root / rel
        if not path.exists():
            continue
        text, enc = read_text(path)
        add = "".join(f"\t\t<String _locID='{i}'>{s}</String>\r\n" for i, s in STRINGS.items()
                      if f"_locID='{i}'" not in text and f'_locID="{i}"' not in text)
        if add:
            marker = text.find("<!-- DON'T WRITE STRINGS DOWN HERE -->")
            i = text.rfind("\n", 0, marker) + 1 if marker >= 0 else text.rindex("\t</Language>")
            text = text[:i] + add + text[i:]
            write_text(path, text, enc)

    # The key
    path = root / "Startup/wol.cfg"
    if path.exists():
        text, enc = read_text(path)
        if not re.search(r"(?im)^\s*autoScout\b", text):
            text = text.rstrip("\r\n") + "\r\nautoScout\r\n"
            write_text(path, text, enc)

    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(f"applied; backup in {backup}")


def restore(root):
    backup = root / BACKUP
    manifest_path = backup / "manifest.json"
    if not manifest_path.exists():
        sys.exit(f"apply_fix: no backup at {backup}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for rel in manifest["added"]:
        (root / rel).unlink(missing_ok=True)
    for rel in manifest["changed"]:
        shutil.copy2(backup / rel, root / rel)
    shutil.rmtree(backup)
    print("restored")


def check(root):
    text, _ = read_text(root / "data/protoy.xml")
    for name in FLYERS + [ENVOY]:
        start, end = unit_block(text, name)
        print(f"{name}: {'applied' if START in text[start:end] else 'not applied'}")
    for rel in NEW_FILES:
        print(f"{rel}: {'present' if (root / rel).exists() else 'missing'}")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root = pathlib.Path(sys.argv[1])
    if "steamapps" in str(root).lower() and "--force" not in sys.argv:
        sys.exit("apply_fix: this is a Steam folder; work on a copy, or add --force to change it anyway")
    if "--restore" in sys.argv:
        restore(root)
    elif "--check" in sys.argv:
        check(root)
    else:
        apply(root)


if __name__ == "__main__":
    main()
