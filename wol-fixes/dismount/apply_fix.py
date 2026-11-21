"""Gives Wars of Liberty's Chasseur a Cheval a second stance, Dismounted: the rider gets off on the horse's left
side, fights on foot beside it with the infantry's own animations, and mounts again; no DLL key is needed.

    python apply_fix.py <WoL folder>              apply (a backup of every file it changes goes to
                                                  <WoL folder>\\dismount-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back and delete the files it added
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

What it changes (README.txt has the why and the recipe for another unit):
- data\\tactics\\wolChasseurDismount.tactics (new, made from the folder's own musketCavalry.tactics): the same
  actions and tactics, plus the actions DismountedRangedAttack and DismountedHandAttack (copies of
  DefendRangedAttack and MeleeHandAttack with the animations on foot), a tactic "Dismounted" (speed x0.67) and a
  transition from every mounted tactic to it (animation Dismount, 2 s) and back (Mount, 2 s);
- data\\protoy.xml: ChasseuraCheval uses that file and gets the ProtoActions DismountedRangedAttack and
  DismountedHandAttack (copies of its DefendRangedAttack and MeleeHandAttack) and the buttons DismountStance and
  MountStance on its command row (page 10, the first free columns);
- data\\protounitcommands.xml: those buttons, unitSetTactic("Dismounted") and unitSetTactic("Stagger");
- data\\uhc\\customprotounitcommands.xml: their names, which the game must know to keep the buttons (DLL key
  customProtoUnitCommands);
- data\\techtreey.xml: every effect on DefendRangedAttack or MeleeHandAttack gets a twin on the new action, so
  upgrades and cards reach the attacks on foot too;
- data\\battle.xml: the squad mode CavalryDismounted (the stance button) for AbstractWoLRangedCavalry;
- data\\stringtabley.xml and translations\\_originals\\stringtabley.xml: the tooltips (IDs 690911, 690912);
- art\\WoL\\units\\cavalry\\chasseur_a_cheval\\chasseur_a_cheval_horse.xml and chasseur_a_cheval_rider.xml: the
  animations Dismounted_* (idle, bored, walk, jog, run, attack, reload, melee, death), Dismount and Mount;
- art\\WoL\\units\\cavalry\\chasseur_a_cheval\\dismount\\*.gr2 (new): the rider's animations and the horse clips
  that go with them (made with aoe3-blender-tools' tools/make_dismount.py).
"""
import json
import pathlib
import re
import shutil
import sys
from xml.etree import ElementTree

HERE = pathlib.Path(__file__).resolve().parent
FILES = HERE / "files"
BACKUP = "dismount-backup"

UNIT = "ChasseuraCheval"
SOURCE_TACTICS = "musketCavalry.tactics"
TACTICS = "wolChasseurDismount.tactics"
MOUNTED = ["Stagger", "Defend", "Melee"]
STANCE = "Dismounted"
SPEED = "0.67"
ART = "art/WoL/units/cavalry/chasseur_a_cheval"
HORSE_XML = ART + "/chasseur_a_cheval_horse.xml"
RIDER_XML = ART + "/chasseur_a_cheval_rider.xml"
ACTIONS = {"DefendRangedAttack": "DismountedRangedAttack", "MeleeHandAttack": "DismountedHandAttack"}
STRING_ID = 690911
STRINGS = {
    690911: "Dismount: the rider gets off and fights on foot beside his horse. Slower on foot; the same attacks.",
    690912: "Mount: the rider gets back on his horse (Stagger stance).",
}
MOUNT_TACTIC = "Stagger"
DISMOUNT_CMD, MOUNT_CMD = "DismountStance", "MountStance"
COMMANDS = f"""\t<protounitcommand>\r
\t\t<name>{DISMOUNT_CMD}</name>\r
\t\t<icon>art\\War of the Triple Alliance\\Icons\\musketok</icon>\r
\t\t<rollovertextid>690911</rollovertextid>\r
\t\t<command>unitSetTactic("{STANCE}")</command>\r
\t</protounitcommand>\r
\t<protounitcommand>\r
\t\t<name>{MOUNT_CMD}</name>\r
\t\t<icon>art\\WoL\\icons\\15eChaos\\ChasseurACheval_icon</icon>\r
\t\t<rollovertextid>690912</rollovertextid>\r
\t\t<command>unitSetTactic("{MOUNT_TACTIC}")</command>\r
\t</protounitcommand>\r
"""
SQUAD_MODE = f"""\t<squadmode>\r
\t\t<name>CavalryDismounted</name>\r
\t\t<tactic>{STANCE}</tactic>\r
\t\t<allowautopick>0</allowautopick>\r
\t\t<unittype>AbstractWoLRangedCavalry</unittype>\r
\t\t<targetunittype>All</targetunittype>\r
\t\t<stance>Defensive</stance>\r
\t\t<formationtype>Line</formationtype>\r
\t\t<maxnumberformationlines>3</maxnumberformationlines>\r
\t\t<formationlinelinespacing>1.4</formationlinelinespacing>\r
\t\t<formationlinecolumnspacing>1.6</formationlinecolumnspacing>\r
\t\t<randomspacingoffset>0.35</randomspacingoffset>\r
\t\t<cooldowntime>5000</cooldowntime>\r
\t\t<transitiontimein>500</transitiontimein>\r
\t\t<activeicon>art\\War of the Triple Alliance\\Icons\\musketok</activeicon>\r
\t\t<availableicon>art\\War of the Triple Alliance\\Icons\\musketnull</availableicon>\r
\t\t<unavailableicon>art\\War of the Triple Alliance\\Icons\\musketnull</unavailableicon>\r
\t\t<rolloverstringid>{STRING_ID}</rolloverstringid>\r
\t</squadmode>\r
"""
CHANGED = [
    "data/protoy.xml",
    "data/protounitcommands.xml",
    "data/uhc/customprotounitcommands.xml",
    "data/techtreey.xml",
    "data/battle.xml",
    "data/stringtabley.xml",
    "translations/_originals/stringtabley.xml",
    HORSE_XML,
    RIDER_XML,
]


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


def block(text, tag, name, what):
    """The text of the <tag> element whose name (its first text, or its <name>) is `name`, one tab in."""
    pat = r"\n\t<%s>\s*(?:<name[^>]*>)?\s*%s\s*(?:</name>)?.*?\n\t</%s>\r?\n" % (tag, re.escape(name), tag)
    m = re.search(pat, text, re.S)
    if m is None:
        sys.exit(f"apply_fix: {what} has no {tag} {name}")
    return m


def tactics_file(text):
    """The source tactics with the stance on foot (see the module's note)."""
    if re.search(r"<tactic>\s*%s\b" % STANCE, text):
        sys.exit(f"apply_fix: {SOURCE_TACTICS} has a tactic {STANCE} already")
    # 1. the two actions on foot, after the last action
    new_actions = ""
    for old, new in ACTIONS.items():
        a = block(text, "action", old, SOURCE_TACTICS).group(0)
        a = re.sub(r"(<name[^>]*>)\s*%s\s*(</name>)" % old, r"\g<1>%s\2" % new, a, count=1)
        if "Ranged" in old:
            a = re.sub(r"<anim>[^<]*</anim>", "<anim>Dismounted_Attack</anim>", a, count=1)
            a = re.sub(r"<reloadanim>[^<]*</reloadanim>", "<reloadanim>Dismounted_Reload</reloadanim>", a, count=1)
        else:
            a = re.sub(r"<anim>[^<]*</anim>", "<anim>Dismounted_Melee</anim>", a, count=1)
        a = re.sub(r"<idleanim>[^<]*</idleanim>", "<idleanim>Dismounted_Idle</idleanim>", a, count=1)
        a = re.sub(r"[ \t]*<active>0</active>\r?\n", "", a)
        new_actions += a.lstrip("\r\n")
    last = list(re.finditer(r"\n\t</action>\r?\n", text))[-1]
    text = text[:last.end()] + new_actions + text[last.end():]
    # 2. every mounted tactic gets the way to the stance on foot
    for t in MOUNTED:
        m = block(text, "tactic", t, SOURCE_TACTICS)
        b = m.group(0)
        i = b.index("\t\t<attacktype>") if "\t\t<attacktype>" in b else b.rindex("\t</tactic>")
        trans = (f"\t\t<transition>\n\t\t\t<tactic>{STANCE}</tactic>\n\t\t\t<action>Limber</action>\n\t\t\t<anim>Dismount</anim>\n"
                 f"\t\t\t<length>2</length>\n\t\t\t<exit>1</exit>\n\t\t</transition>\n")
        text = text[:m.start()] + b[:i] + trans + b[i:] + text[m.end():]
    # 3. the stance on foot, after the last tactic: the name and the first child on one line (a line break after
    #    the name defines the tactic's XS constant twice)
    first = block(text, "tactic", MOUNTED[1], SOURCE_TACTICS).group(0)
    keep = [line for line in re.findall(r"\t\t<action[^>]*>[^<]*</action>", first)
            if not any(old in line for old in ACTIONS) and "BuildingAttack" not in line
            and "JezailRangedAttack" not in line]
    back = "".join(f"\t\t<transition>\n\t\t\t<tactic>{t}</tactic>\n\t\t\t<action>Limber</action>\n\t\t\t<anim>Mount</anim>\n"
                   f"\t\t\t<length>2</length>\n\t\t\t<exit>1</exit>\n\t\t</transition>\n" for t in MOUNTED)
    stance = (f"\t<tactic>{STANCE}\n" + "\n".join(keep) + "\n"
              f"\t\t<action priority=\"100\">{ACTIONS['DefendRangedAttack']}</action>\n"
              f"\t\t<action priority=\"90\">{ACTIONS['MeleeHandAttack']}</action>\n"
              f"\t\t<speedmodifier>{SPEED}</speedmodifier>\n" + back +
              "\t\t<attacktype>LogicalTypeRangedUnitsAttack</attacktype>\n"
              "\t\t<autoattacktype>LogicalTypeRangedUnitsAutoAttack</autoattacktype>\n"
              "\t\t<attackresponsetype>LogicalTypeRangedUnitsAttack</attackresponsetype>\n"
              "\t\t<runaway>0</runaway>\n\t\t<autoretarget>1</autoretarget>\n"
              "\t\t<idleanim>Dismounted_Idle</idleanim>\n\t\t<boredanim>Dismounted_Bored</boredanim>\n"
              "\t\t<deathanim>Dismounted_Death</deathanim>\n\t\t<walkanim>Dismounted_Walk</walkanim>\n"
              "\t\t<joganim>Dismounted_Jog</joganim>\n\t\t<runanim>Dismounted_Run</runanim>\n\t</tactic>\n")
    end = text.rindex("</tactics>")
    text = text[:end] + stance + text[end:]
    out = crlf(text)
    try:
        root = ElementTree.fromstring(out.encode("utf-8"))
    except ElementTree.ParseError as error:
        sys.exit(f"apply_fix: the new tactics file would not be valid XML ({error}); nothing changed")
    names = [t.text.strip() for t in root.findall("tactic")]
    if names.count(STANCE) != 1 or any(t not in names for t in MOUNTED):
        sys.exit(f"apply_fix: unexpected tactics in the new file: {names}; nothing changed")
    return out


def unit_block(text, name):
    m = re.search(r'<Unit\b[^>]*\bname="%s"[^>]*>' % re.escape(name), text)
    if m is None:
        sys.exit(f"apply_fix: protoy.xml has no unit {name}")
    return m.start(), text.index("</Unit>", m.end())


def edit_proto(text):
    start, end = unit_block(text, UNIT)
    b = text[start:end]
    if TACTICS in b:
        return text
    b, n = re.subn(r"<Tactics>[^<]*</Tactics>", f"<Tactics>{TACTICS}</Tactics>", b, count=1)
    if n != 1:
        sys.exit(f"apply_fix: unit {UNIT} has no <Tactics>")
    add = ""
    for old, new in ACTIONS.items():
        m = re.search(r"([ \t]*)<ProtoAction>\s*<Name>%s</Name>.*?</ProtoAction>\r?\n" % old, b, re.S)
        if m is None:
            sys.exit(f"apply_fix: unit {UNIT} has no ProtoAction {old}")
        add += m.group(0).replace(f"<Name>{old}</Name>", f"<Name>{new}</Name>")
    i = b.rindex("\n", 0, len(b)) + 1                 # before the line of </Unit>
    b = b[:i] + add + b[i:]
    # the two buttons on the command row (page 10: the row where the game shows command types added through
    # data\uhc\customprotounitcommands.xml), in its first free columns
    used = {int(c) for c in re.findall(r'<Command\b[^>]*column\s*=\s*"(\d+)"[^>]*page\s*=\s*"10"', b)}
    used |= {int(c) for c in re.findall(r'<Command\b[^>]*page\s*=\s*"10"[^>]*column\s*=\s*"(\d+)"', b)}
    free = [c for c in range(0, 8) if c not in used][:2]
    lines = "".join(f'\t\t<Command column="{c}" page="10">{cmd}</Command>\r\n'
                    for c, cmd in zip(free, (DISMOUNT_CMD, MOUNT_CMD)))
    i = b.index("\t\t<Tactics>")
    b = b[:i] + lines + b[i:]
    return text[:start] + b + text[end:]


def edit_techtree(text):
    """Every effect on an old action gets a twin on the new one, right after it."""
    count = 0
    for old, new in ACTIONS.items():
        pat = re.compile(r"([ \t]*)(<Effect\b[^>]*\baction\s*=\s*(['\"])%s\3[^>]*>.*?</Effect>)(\r?\n)" % old, re.S)

        def twin(m):
            nonlocal count
            count += 1
            copy = re.sub(r"(\baction\s*=\s*['\"])%s(['\"])" % old, r"\g<1>%s\2" % new, m.group(2), count=1)
            return m.group(0) + m.group(1) + copy + m.group(4)
        if f"'{new}'" in text or f'"{new}"' in text:
            continue
        text = pat.sub(twin, text)
    return text, count


def apply(root):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        sys.exit(f"apply_fix: already applied ({backup} exists); run --restore first")
    for rel in ["data/protoy.xml", "data/techtreey.xml", "data/battle.xml", "data/tactics/" + SOURCE_TACTICS,
                HORSE_XML, RIDER_XML]:
        if not (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} is missing: is this a Wars of Liberty folder?")
    for rel in ["data/protoy.xml.xmb", "data/techtreey.xml.xmb", HORSE_XML + ".xmb",
                RIDER_XML + ".xmb"]:
        if (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} exists: the game would read it instead of the edited XML")
    # Made and checked before anything is written.
    tactics = tactics_file((root / "data/tactics" / SOURCE_TACTICS).read_text(encoding="utf-8"))
    backup.mkdir()
    manifest = {"changed": [], "added": []}
    for rel in CHANGED:
        if (root / rel).exists():
            (backup / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, backup / rel)
            manifest["changed"].append(rel)

    dst = root / "data/tactics" / TACTICS
    if dst.exists():
        sys.exit(f"apply_fix: {dst} exists already")
    dst.write_bytes(tactics.encode("utf-8"))
    manifest["added"].append("data/tactics/" + TACTICS)
    for src in sorted((FILES / "art").rglob("*.gr2")):
        rel = src.relative_to(FILES).as_posix()
        if (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} exists already")
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, root / rel)
        manifest["added"].append(rel)

    path = root / "data/protoy.xml"
    text, enc = read_text(path)
    write_text(path, edit_proto(text), enc)

    path = root / "data/techtreey.xml"
    text, enc = read_text(path)
    text, n = edit_techtree(text)
    write_text(path, text, enc)
    print(f"techtreey.xml: {n} effects twinned")

    path = root / "data/battle.xml"
    text, enc = read_text(path)
    if "<name>CavalryDismounted</name>" not in text:
        i = text.rindex("</battles>")
        text = text[:i] + SQUAD_MODE + text[i:]
        write_text(path, text, enc)

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

    path = root / "data/protounitcommands.xml"
    text, enc = read_text(path)
    if f"<name>{DISMOUNT_CMD}</name>" not in text:
        i = text.rindex("</protounitcommands>")
        text = text[:i] + COMMANDS + text[i:]
        write_text(path, text, enc)

    path = root / "data/uhc/customprotounitcommands.xml"
    if path.exists():
        text, enc = read_text(path)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        text, enc = '<?xml version="1.0" encoding="utf-8"?>\r\n\r\n<ProtoUnitCommandTypes>\r\n</ProtoUnitCommandTypes>\r\n', "utf-8"
        manifest["added"].append("data/uhc/customprotounitcommands.xml")
    for name in (DISMOUNT_CMD, MOUNT_CMD):
        if f">{name}<" not in text:
            i = text.rindex("</ProtoUnitCommandTypes>")
            text = text[:i] + f"    <CommandType>{name}</CommandType>\r\n" + text[i:]
    write_text(path, text, enc)

    for rel, snippet in ((HORSE_XML, "anims-horse.xml"), (RIDER_XML, "anims-rider.xml")):
        path = root / rel
        text, enc = read_text(path)
        if "<anim>Dismounted_Idle" in text:
            continue
        add = crlf((FILES / snippet).read_text(encoding="utf-8"))
        i = text.rindex("</animfile>")
        text = text[:i] + add + text[i:]
        try:
            ElementTree.fromstring(text.encode("utf-8"))
        except ElementTree.ParseError as error:
            sys.exit(f"apply_fix: {rel} would not be valid XML ({error}); run --restore")
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
    folder = root / ART / "dismount"
    if folder.exists() and not any(folder.iterdir()):
        folder.rmdir()
    shutil.rmtree(backup)
    print("restored")


def check(root):
    text, _ = read_text(root / "data/protoy.xml")
    start, end = unit_block(text, UNIT)
    print(f"{UNIT}: {'applied' if TACTICS in text[start:end] else 'not applied'}")
    print(f"data/tactics/{TACTICS}: {'present' if (root / 'data/tactics' / TACTICS).exists() else 'missing'}")


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
