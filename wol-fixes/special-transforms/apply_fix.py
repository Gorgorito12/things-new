"""Turns Wars of Liberty's "placed" transforms into command buttons: the Zulu youth's four kraal maturings
(Askari, Escort, Revolving Cannon, Mountain Gun) and the Greek fishing boat's fireship. A click transforms the
selected units where they stand, as the youth's six other transform buttons already do; nothing is placed on the
ground any more.

    python apply_fix.py <WoL folder>              apply (a backup of every file it changes goes to
                                                  <WoL folder>\\special-transforms-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

What it changes (README.txt has the why):
- data\\protoy.xml: AFRICANyouth loses its four <Train> rows of AFRICAN*MATURING and gets four <Command> rows in the
  same columns; FishingBoat loses its <Train> row of PyrpolikoMaturing and gets a <Command> row in the same column;
  the five target protos get <Flag>NonCollideable</Flag> (as the six WOL*Maturing protos have), else the unit that
  transforms stands in the way of its own target and the game refuses it;
- data\\protounitcommands.xml: five commands, uiTransformSelectedUnit("<target>"), with the target's own icon (the
  fireship's with <associatedtech>Age0Greeks</associatedtech>, so that only the Greeks see it); the
  commented-out TransformPyrpolikon entry (which named a proto that does not exist, PyrpolikonMATURING) stays as it is,
  and a working one is added after the other entries;
- data\\uhc\\customprotounitcommands.xml: the four new command names (TransformPyrpolikon is there already);
- data\\stringtabley.xml and translations\\_originals\\stringtabley.xml: the five tooltips in English (IDs
  690911..690915), written like WoL's TransformBowmanMaturing tooltip: name, cost, where it can mature, the unit's
  own description. Other languages fall back to nothing: translate them there.
- art\\War of the Triple Alliance\\Buildingsets\\Delta\\Discovery\\maturing\\maturing2.xml, maturing3.xml and
  maturing4.xml (the anim files of the four kraal maturings): their "finished" stage, the one a transformed maturing
  shows from its first moment (the transform creates it built), gets the dancing youth of the last construction stage
  (lvl6: the model, the dance or the Escort's heal2, the chant, the rifle of the Askari, the shockwave), without its
  Death anim; the decal stays. CRLF line endings are kept (an anim file with LF made a building invisible);
The near-kraal rule needs nothing new: the game checks the target's own PlacementFile (maturinggunpowder.xml,
maturinghorse.xml) at the unit's position when the button is pressed, on every machine.
The DLL key `transformChecks` (optional) greys a button out with the reason and enforces the target's BuildLimit; the script adds it to Startup\\wol.cfg with
--key.
"""
import json
import pathlib
import re
import shutil
import sys

BACKUP = "special-transforms-backup"
YOUTH = "AFRICANyouth"
BOAT = "FishingBoat"
# (command name, target proto, unit that gets the button, string ID)
COMMANDS = [
    ("TransformAskariMaturing", "AFRICANaskariMATURING", YOUTH, 690911),
    ("TransformEscortMaturing", "AFRICANescortMATURING", YOUTH, 690912),
    ("TransformRevolvingCannonMaturing", "AFRICANrevolvingcannonMATURING", YOUTH, 690913),
    ("TransformMountainGunMaturing", "AFRICANmountaingunMATURING", YOUTH, 690914),
    ("TransformPyrpolikon", "PyrpolikoMaturing", BOAT, 690915),
]
# The fishing boat is every civ's: its button shows only for a player with this tech, the Greeks' start tech, which is
# never obtainable (a button with an <associatedtech> researches that tech when it is obtainable, so not
# WOLColonializeGreeks, the age-up tech WoL's commented-out entry named). The game does not check that the target is
# enabled for the player when the command runs.
ASSOCIATED_TECH = {"TransformPyrpolikon": "Age0Greeks"}
MATURING_ART = "art/War of the Triple Alliance/Buildingsets/Delta/Discovery/maturing"
# The anim files of the four kraal maturings (maturing.xml is the other AFRICAN*MATURING protos', which no button
# makes; WoL's own button maturings use art\WoL\units\maturing\maturing.xml, which dances already).
ANIMS = [f"{MATURING_ART}/maturing2.xml", f"{MATURING_ART}/maturing3.xml", f"{MATURING_ART}/maturing4.xml"]
DANCE_MARK = "<!-- special-transforms: the finished stage dances too -->"
CHANGED = [
    "data/protoy.xml",
    "data/protounitcommands.xml",
    "data/uhc/customprotounitcommands.xml",
    "data/stringtabley.xml",
    "translations/_originals/stringtabley.xml",
    "Startup/wol.cfg",
] + ANIMS
RESOURCE_ICONS = {
    "food": "ui/ingame/resource_food", "wood": "ui/ingame/resource_wood", "gold": "ui/ingame/resource_gold",
    "trade": "ui/ingame/resource_export", "fame": "ui/ingame/resource_fame", "xp": "ui/ingame/resource_xp",
}


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
    return m.start(), text.index("</Unit>", m.end())


def tag(block, name):
    m = re.search(r"<%s>([^<]*)</%s>" % (name, name), block)
    return m.group(1).strip() if m else None


def strings_by_id(root):
    path = root / "data/stringtabley.xml"
    text, _ = read_text(path)
    return {int(i): s for i, s in re.findall(r"<String _locID='(\d+)'[^>]*>([^<]*)</String>", text)}


def placement_rule_text(root, placement, strings):
    """The error text of the distanceatmostfromtype rules of a placement file other than FirstTC's (the kraal)."""
    path = root / "data/placementrules" / placement
    if not path.exists():
        return []
    text, _ = read_text(path)
    out = []
    for attrs, unit in re.findall(r"<distanceatmostfromtype([^>]*)>([^<]+)</distanceatmostfromtype>", text):
        if unit.strip().lower() == "firsttc":
            continue
        dist = re.search(r'distance="([\d.]+)"', attrs)
        sid = re.search(r'errorstringid="(\d+)"', attrs)
        line = strings.get(int(sid.group(1)), f"Near a {unit.strip()}") if sid else f"Near a {unit.strip()}"
        if dist:
            line = f"{line.rstrip('.')} (within {float(dist.group(1)):g} m)."
        out.append(line)
    return out


def tooltip(root, text, target, strings):
    start, end = unit_block(text, target)
    block = text[start:end]
    name_id = tag(block, "DisplayNameID")
    roll_id = tag(block, "RolloverTextID")
    name = strings.get(int(name_id), target) if name_id else target
    costs = re.findall(r'<Cost resourcetype="(\w+)">([\d.]+)</Cost>', block)
    parts = []
    for res, amount in costs:
        icon = RESOURCE_ICONS.get(res.lower())
        value = f"{float(amount):g}"
        parts.append(f'{value} &lt;icon="(32)({icon})"&gt;' if icon else f"{value} {res}")
    lines = [name]
    if parts:
        lines.append(" ∙  Cost: " + ", ".join(parts))
    placement = tag(block, "PlacementFile")
    for rule in placement_rule_text(root, placement, strings) if placement else []:
        lines.append(" ∙  " + rule)
    limit = tag(block, "BuildLimit")
    if limit:
        lines.append(f" ∙  Limit: {int(float(limit))}")
    if roll_id and int(roll_id) in strings:
        lines.append(" ∙  " + strings[int(roll_id)])
    return "\\n".join(lines)


def edit_protoy(text):
    """The <Train> rows become <Command> rows in the same columns; the targets get NonCollideable."""
    for command, target, unit, _ in COMMANDS:
        start, end = unit_block(text, unit)
        block = text[start:end]
        if f">{command}</Command>" in block:
            continue
        m = re.search(r'([ \t]*)<Train column="(\d+)" page="(\d+)"[^>]*>%s</Train>\r?\n' % re.escape(target), block)
        if m is None:
            sys.exit(f"apply_fix: {unit} has no <Train> row of {target}")
        line = f'{m.group(1)}<Command column="{m.group(2)}" page="{m.group(3)}">{command}</Command>\r\n'
        block = block[:m.start()] + line + block[m.end():]
        text = text[:start] + block + text[end:]
    for _, target, _, _ in COMMANDS:
        start, end = unit_block(text, target)
        block = text[start:end]
        if "<Flag>NonCollideable</Flag>" in block:
            continue
        m = list(re.finditer(r"([ \t]*)<Flag>[^<]*</Flag>\r?\n", block))[-1]
        block = block[:m.end()] + f"{m.group(1)}<Flag>NonCollideable</Flag>\r\n" + block[m.end():]
        text = text[:start] + block + text[end:]
    return text


def dancing_finished(text):
    """The anim file with its "finished" submodel replaced by a copy of "lvl6" (the dancer) without its Death anim.
    None when the file has no such pair. The text keeps its line endings."""
    if DANCE_MARK in text:
        return text
    stage = r"<submodel>[ \t]*\r?\n[ \t]*%s[ \t]*\r?\n.*?</submodel>"
    lvl6 = re.search(stage % "lvl6", text, flags=re.S)
    finished = re.search(stage % "finished", text, flags=re.S)
    if lvl6 is None or finished is None:
        return None
    nl = "\r\n" if "\r\n" in text else "\n"
    block = re.sub(r"(<submodel>[ \t]*\r?\n[ \t]*)lvl6", r"\g<1>finished", lvl6.group(0), count=1)
    block = re.sub(r"[ \t]*<anim>[ \t]*\r?\n[ \t]*Death[ \t]*\r?\n.*?</anim>[ \t]*\r?\n", "", block, flags=re.S)
    block = DANCE_MARK + nl + block
    return text[:finished.start()] + block + text[finished.end():]


def command_entries(text):
    out = ""
    for command, target, _, sid in COMMANDS:
        if f"<name>{command}</name>" in re.sub(r"<!--.*?-->", "", text, flags=re.S):
            continue
        out += "\t<protounitcommand>\r\n"
        out += f"\t\t<name>{command}</name>\r\n"
        out += f"\t\t<icon>{{icon:{target}}}</icon>\r\n"
        out += f'\t\t<command>uiTransformSelectedUnit("{target}")</command>\r\n'
        out += f"\t\t<rollovertextid>{sid}</rollovertextid>\r\n"
        if command in ASSOCIATED_TECH:
            out += f"\t\t<associatedtech>{ASSOCIATED_TECH[command]}</associatedtech>\r\n"
        out += "\t</protounitcommand>\r\n"
    return out


def apply(root, key):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        sys.exit(f"apply_fix: already applied ({backup} exists); run --restore first")
    for rel in ["data/protoy.xml", "data/protounitcommands.xml", "data/uhc/customprotounitcommands.xml",
                "data/stringtabley.xml"]:
        if not (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} is missing: is this a Wars of Liberty folder?")
    protoy, protoy_enc = read_text(root / "data/protoy.xml")
    new_protoy = edit_protoy(protoy)  # checks every row before anything is written
    anims = {}
    for rel in ANIMS:
        if not (root / rel).exists():
            print(f"apply_fix: {rel} is missing; its maturing keeps its look")
            continue
        text, enc = read_text(root / rel)
        new = dancing_finished(text)
        if new is None:
            print(f"apply_fix: {rel} has no lvl6 and finished stages; left as it is")
        elif new != text:
            anims[rel] = (new, enc)
    strings = strings_by_id(root)

    backup.mkdir()
    manifest = {"changed": []}
    for rel in CHANGED:
        if (root / rel).exists():
            (backup / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, backup / rel)
            manifest["changed"].append(rel)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")

    write_text(root / "data/protoy.xml", new_protoy, protoy_enc)
    for rel, (text, enc) in anims.items():
        write_text(root / rel, text, enc)

    path = root / "data/protounitcommands.xml"
    text, enc = read_text(path)
    entries = command_entries(text)
    for _, target, _, _ in COMMANDS:  # the button's icon: the target's own <Icon>
        start, end = unit_block(protoy, target)
        icon = tag(protoy[start:end], "Icon") or ""
        if icon and not icon.lower().startswith("art\\"):
            icon = "art\\" + icon  # the command entries name icons from the game folder, as WoL's others do
        entries = entries.replace(f"{{icon:{target}}}", icon)
    if entries:
        i = text.rindex("</protounitcommands>")
        text = text[:i] + entries + text[i:]
        write_text(path, text, enc)

    path = root / "data/uhc/customprotounitcommands.xml"
    text, enc = read_text(path)
    for command, _, _, _ in COMMANDS:
        if not re.search(r"<CommandType>\s*%s\s*</CommandType>" % command, text):
            i = text.rindex("</ProtoUnitCommandTypes>")
            text = text[:i] + f"    <CommandType>{command}</CommandType>\r\n" + text[i:]
    write_text(path, text, enc)

    tips = {sid: tooltip(root, protoy, target, strings) for _, target, _, sid in COMMANDS}
    for rel in ("data/stringtabley.xml", "translations/_originals/stringtabley.xml"):
        path = root / rel
        if not path.exists():
            continue
        text, enc = read_text(path)
        add = "".join(f"\t\t<String _locID='{i}' symbol='cStringCommand'>{s}</String>\r\n" for i, s in tips.items()
                      if f"_locID='{i}'" not in text and f'_locID="{i}"' not in text)
        if add:
            marker = text.find("<!-- DON'T WRITE STRINGS DOWN HERE -->")
            i = text.rfind("\n", 0, marker) + 1 if marker >= 0 else text.rindex("\t</Language>")
            text = text[:i] + add + text[i:]
            write_text(path, text, enc)

    if key:
        path = root / "Startup/wol.cfg"
        if path.exists():
            text, enc = read_text(path)
            if not re.search(r"(?im)^\s*transformChecks\b", text):
                text = text.rstrip("\r\n") + "\r\ntransformChecks\r\n"
                write_text(path, text, enc)
    print(f"applied; backup in {backup}")


def restore(root):
    backup = root / BACKUP
    manifest_path = backup / "manifest.json"
    if not manifest_path.exists():
        sys.exit(f"apply_fix: no backup at {backup}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for rel in manifest["changed"]:
        shutil.copy2(backup / rel, root / rel)
    shutil.rmtree(backup)
    print("restored")


def check(root):
    text, _ = read_text(root / "data/protoy.xml")
    for command, target, unit, _ in COMMANDS:
        start, end = unit_block(text, unit)
        block = text[start:end]
        state = "applied" if f">{command}</Command>" in block else (
            "not applied" if f">{target}</Train>" in block else "neither row found")
        print(f"{unit} {command}: {state}")
    for rel in ANIMS:
        if (root / rel).exists():
            text, _ = read_text(root / rel)
            print(f"{rel}: {'finished stage dances' if DANCE_MARK in text else 'not applied'}")


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
        apply(root, "--key" in sys.argv)


if __name__ == "__main__":
    main()
