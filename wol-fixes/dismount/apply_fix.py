"""Gives Wars of Liberty's Chasseur a Cheval a second stance, Dismounted: the rider gets off on the horse's left
side, fights on foot with the infantry's own animations (the horse hidden, or kept beside him), and mounts again;
no DLL key is needed.

    python apply_fix.py <WoL folder> [--horse hide|keep] [--test]
                                                  apply (a backup of every file it changes goes to
                                                  <WoL folder>\\dismount-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back and delete the files it added
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

--horse hide (the default): the horse is drawn while the rider gets off and on, and not while he is on foot.
--horse keep: the horse stays beside him on foot.
--test: also a TEST unit, ChasseuraChevalDismountTest (a copy of the Chasseur with a build and a heal action on
foot), to see those animations in a test copy of the game. Not for a release: WoL's Chasseur builds and heals
nothing.

What it changes (README.txt has the why and the recipe for another unit):
- data\\tactics\\wolChasseurDismount.tactics (new, made from the folder's own musketCavalry.tactics): the same
  actions and tactics, plus the actions DismountedRangedAttack, DismountedHandAttack and DismountedBuildingAttack
  (copies of DefendRangedAttack, MeleeHandAttack and BuildingAttack with the animations on foot), a tactic
  "Dismounted" (speed x0.67) and a transition from every mounted tactic to it (animation Dismount, 2.5 s; 3.5 s
  with the horse hidden, the rider then stepping to the unit's centre) and back (Mount, the same); with --test, the file's Build and Heal actions are active and in the stance on foot only;
- data\\protoy.xml: ChasseuraCheval uses that file and gets the ProtoActions of the three new attacks (copies of
  its own) and the buttons DismountStance and MountStance on its command row (page 10, the first free columns);
  with --test, the unit ChasseuraChevalDismountTest;
- data\\protounitcommands.xml: those buttons, unitSetTactic("Dismounted") and unitSetTactic("Stagger");
- data\\uhc\\customprotounitcommands.xml: their names, which the game must know to keep the buttons (DLL key
  customProtoUnitCommands);
- data\\techtreey.xml: every effect on DefendRangedAttack, MeleeHandAttack or BuildingAttack gets a twin on the
  new action, so upgrades and cards reach the attacks on foot too;
- data\\battle.xml: the squad mode CavalryDismounted (the stance button) for AbstractWoLRangedCavalry;
- data\\stringtabley.xml and translations\\_originals\\stringtabley.xml: the tooltips (IDs 690911, 690912);
- art\\WoL\\units\\cavalry\\chasseur_a_cheval\\chasseur_a_cheval_horse.xml and chasseur_a_cheval_rider.xml: the
  animations Dismounted_* (idle, bored, walk, jog, run, attack, reload, melee, death, raze idle and attack),
  Dismount and Mount; with the horse hidden, the clips chasseur_hidden_* (the rider on the unit's centre on foot)
  and chasseur_horse_hidden_* (the horse under the ground while he is on foot);
- art\\WoL\\units\\cavalry\\chasseur_a_cheval\\dismount\\*.gr2 (new): the rider's animations and the horse clips
  that go with them, the ones the chosen blocks name (made with aoe3-blender-tools' tools/make_dismount.py).
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
# the transitions' <length>, as long as their animations: hidden, the rider also steps between the horse's side and
# the unit's centre (make_dismount.py's step_length, 1 s)
LENGTH = {"keep": "2.5", "hide": "3.5"}
ART = "art/WoL/units/cavalry/chasseur_a_cheval"
HORSE_XML = ART + "/chasseur_a_cheval_horse.xml"
RIDER_XML = ART + "/chasseur_a_cheval_rider.xml"
# mounted action -> (action on foot, its animations); each has a ProtoAction on the unit, copied, and tech twins
ACTIONS = {
    "DefendRangedAttack": ("DismountedRangedAttack", {"anim": "Dismounted_Attack", "reloadanim": "Dismounted_Reload",
                                                      "idleanim": "Dismounted_Idle"}),
    "MeleeHandAttack": ("DismountedHandAttack", {"anim": "Dismounted_Melee", "idleanim": "Dismounted_Idle"}),
    "BuildingAttack": ("DismountedBuildingAttack", {"anim": "Dismounted_Raze_attack",
                                                    "idleanim": "Dismounted_Raze_idle"}),
}
PRIORITY = {"DismountedRangedAttack": 100, "DismountedHandAttack": 90, "DismountedBuildingAttack": 75}
# --test only: the Build and Heal actions of the tactics file (which the Chasseur has no ProtoAction for) are made
# active and are in the stance on foot only; the test unit gets the ProtoActions. Measured in game (2026-11-22):
# copies named DismountedHeal / DismountedBuild never healed or built, and with <anim>Dismounted_Heal / _Build the
# unit healed and built in its idle pose; the anim files' Heal and Build (files\anims-*-test*.xml) are what plays.
TEST_ACTIONS = {"Build": {}, "Heal": {}}
TEST_UNIT = "ChasseuraChevalDismountTest"
TEST_PROTO_ACTIONS = ("\t\t<ProtoAction>\r\n\t\t\t<Name>Build</Name>\r\n"
                      "\t\t\t<Rate type=\"Building\">1.000000</Rate>\r\n\t\t</ProtoAction>\r\n"
                      "\t\t<ProtoAction>\r\n\t\t\t<Name>Heal</Name>\r\n\t\t\t<Type>Heal</Type>\r\n"
                      "\t\t\t<Rate type=\"LogicalTypeHealed\">20.000000</Rate>\r\n\t\t</ProtoAction>\r\n"
                      # heals damaged units nearby on its own, as the Surgeon has the flag; a house in its build list,
                      # so a trigger (trUnitBuildUnit) can have it place and build one
                      "\t\t<Flag>CanAutoHeal</Flag>\r\n"
                      "\t\t<Train column=\"0\" page=\"6\" row=\"0\">House</Train>\r\n")
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


def action_block(text, name):
    """The <action> whose <name> is exactly `name` (BuildingAttack is not a Build)."""
    m = re.search(r"\n\t<action>\s*<name[^>]*>\s*%s\s*</name>.*?\n\t</action>\r?\n" % re.escape(name), text, re.S)
    if m is None:
        sys.exit(f"apply_fix: {SOURCE_TACTICS} has no action {name}")
    return m


def tactics_file(text, test=False, horse="hide"):
    """The source tactics with the stance on foot (see the module's note)."""
    if re.search(r"<tactic>\s*%s\b" % STANCE, text):
        sys.exit(f"apply_fix: {SOURCE_TACTICS} has a tactic {STANCE} already")
    actions = dict(ACTIONS)
    # 1. the actions on foot, after the last action: copies with their animations on foot, always active
    new_actions = ""
    for old, (new, anims) in actions.items():
        a = action_block(text, old).group(0)
        a = re.sub(r"(<name[^>]*>)\s*%s\s*(</name>)" % old, r"\g<1>%s\2" % new, a, count=1)
        for tag, value in anims.items():
            a = re.sub(r"<%s>[^<]*</%s>" % (tag, tag), f"<{tag}>{value}</{tag}>", a, count=1)
        a = re.sub(r"[ \t]*<active>0</active>\r?\n", "", a)
        new_actions += a.lstrip("\r\n")
    last = list(re.finditer(r"\n\t</action>\r?\n", text))[-1]
    text = text[:last.end()] + new_actions + text[last.end():]
    # 1b. --test: Build and Heal play the animations on foot and are active (see TEST_ACTIONS)
    if test:
        for name, anims in TEST_ACTIONS.items():
            m = action_block(text, name)
            a = m.group(0)
            for tag, value in anims.items():
                a = re.sub(r"<%s>[^<]*</%s>" % (tag, tag), f"<{tag}>{value}</{tag}>", a, count=1)
            a = re.sub(r"[ \t]*<active>0</active>\r?\n", "", a)
            text = text[:m.start()] + a + text[m.end():]
    # 2. every mounted tactic gets the way to the stance on foot (and, --test, loses Build and Heal)
    for t in MOUNTED:
        m = block(text, "tactic", t, SOURCE_TACTICS)
        b = m.group(0)
        if test:
            b = re.sub(r"(?m)^\t\t<action>\s*(?:%s)\s*</action>\r?\n" % "|".join(TEST_ACTIONS), "", b)
        i = b.index("\t\t<attacktype>") if "\t\t<attacktype>" in b else b.rindex("\t</tactic>")
        trans = (f"\t\t<transition>\n\t\t\t<tactic>{STANCE}</tactic>\n\t\t\t<action>Limber</action>\n\t\t\t<anim>Dismount</anim>\n"
                 f"\t\t\t<length>{LENGTH[horse]}</length>\n\t\t\t<exit>1</exit>\n\t\t</transition>\n")
        text = text[:m.start()] + b[:i] + trans + b[i:] + text[m.end():]
    # 3. the stance on foot, after the last tactic: the name and the first child on one line (a line break after
    #    the name defines the tactic's XS constant twice)
    first = block(text, "tactic", MOUNTED[1], SOURCE_TACTICS).group(0)
    # the tactic's own actions only (two tabs in), not the <action>Limber</action> of its transitions
    keep = [line.group(0) for line in re.finditer(r"(?m)^\t\t<action[^>]*>\s*([^<]*?)\s*</action>", first)
            if line.group(1) not in actions and line.group(1) != "JezailRangedAttack"]
    back = "".join(f"\t\t<transition>\n\t\t\t<tactic>{t}</tactic>\n\t\t\t<action>Limber</action>\n\t\t\t<anim>Mount</anim>\n"
                   f"\t\t\t<length>{LENGTH[horse]}</length>\n\t\t\t<exit>1</exit>\n\t\t</transition>\n" for t in MOUNTED)
    on_foot = "".join(f"\t\t<action priority=\"{PRIORITY[new]}\">{new}</action>\n" for new, _a in actions.values())
    if test:
        on_foot += "".join(f"\t\t<action>{name}</action>\n" for name in TEST_ACTIONS)
    stance = (f"\t<tactic>{STANCE}\n" + "\n".join(keep) + "\n" + on_foot +
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


def edit_proto(text, test=False):
    start, end = unit_block(text, UNIT)
    b = text[start:end]
    if TACTICS in b:
        return text
    b, n = re.subn(r"<Tactics>[^<]*</Tactics>", f"<Tactics>{TACTICS}</Tactics>", b, count=1)
    if n != 1:
        sys.exit(f"apply_fix: unit {UNIT} has no <Tactics>")
    add = ""
    for old, (new, _anims) in ACTIONS.items():
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
    text = text[:start] + b + text[end:]
    if test and f'name="{TEST_UNIT}"' not in text:
        # a TEST copy of the unit with a build and a heal action on foot, after the last unit; a new id
        ids = [int(x) for x in re.findall(r'<Unit\b[^>]*\bid="(\d+)"', text)]
        copy_ = re.sub(r'\bid="\d+"', f'id="{max(ids) + 1}"', b, count=1)
        copy_ = copy_.replace(f'name="{UNIT}"', f'name="{TEST_UNIT}"', 1)
        i = copy_.rindex("\n") + 1                    # before the line of </Unit>
        copy_ = copy_[:i] + TEST_PROTO_ACTIONS + copy_[i:] + "</Unit>\r\n"
        indent = re.match(r"[ \t]*", text[text.rindex("\n", 0, start) + 1:]).group(0)
        last = text.index("\n", text.rindex("</Unit>")) + 1
        text = text[:last] + indent + copy_ + text[last:]
    return text


def snippets(horse, test):
    """The anim blocks to add, per anim file: the horse's for the choice (hidden: its clips on foot keep the horse
    under the ground), and the test unit's with --test."""
    hidden = "-hidden" if horse == "hide" else ""
    return {HORSE_XML: [f"anims-horse{hidden}.xml"] + ([f"anims-horse-test{hidden}.xml"] if test else []),
            RIDER_XML: [f"anims-rider{hidden}.xml"] + ([f"anims-rider-test{hidden}.xml"] if test else [])}


def needed_art(horse, test):
    """The names (without .gr2) of the files of files\\art the chosen blocks name."""
    names = set()
    for parts in snippets(horse, test).values():
        for s in parts:
            for f in re.findall(r"<file>([^<]+)</file>", (FILES / s).read_text(encoding="utf-8")):
                names.add(f.strip().split("\\")[-1].lower())
    return names


def edit_techtree(text):
    """Every effect on an old action gets a twin on the new one, right after it (on its own line). An effect ends
    at its own </Effect>, never past the next <Effect> or </Effects>: WoL writes some as `</Effect></Effects>` on
    one line, and a match that ran on to a later line duplicated whole techs (7 of them, 2026-11-22: the AI then
    failed to compile, "Error 0172: 'cTechypConsulateBritishBrigade' is not a valid operator")."""
    count = 0
    techs = len(re.findall(r"<Tech\b", text))
    for old, (new, _anims) in ACTIONS.items():
        pat = re.compile(r"([ \t]*)(<Effect\b[^>]*?\baction\s*=\s*(['\"])%s\3[^>]*?"
                         r"(?:/>|>(?:(?!</?Effects?\b).)*?</Effect>))" % old, re.S)

        def twin(m):
            nonlocal count
            count += 1
            copy = re.sub(r"(\baction\s*=\s*['\"])%s(['\"])" % old, r"\g<1>%s\2" % new, m.group(2), count=1)
            return m.group(0) + "\r\n" + m.group(1) + copy
        if f"'{new}'" in text or f'"{new}"' in text:
            continue
        text = pat.sub(twin, text)
    if len(re.findall(r"<Tech\b", text)) != techs:
        sys.exit("apply_fix: twinning the tech effects would change the number of techs; nothing changed")
    return text, count


def apply(root, horse="hide", test=False):
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
    tactics = tactics_file((root / "data/tactics" / SOURCE_TACTICS).read_text(encoding="utf-8"), test, horse)
    rider_text, _ = read_text(root / RIDER_XML)
    if not re.search(r"<attachment>\s*torch\b", rider_text):
        sys.exit(f"apply_fix: {RIDER_XML} defines no attachment torch (the attack on buildings on foot holds it)")
    needed = needed_art(horse, test)
    techtree, techtree_enc = read_text(root / "data/techtreey.xml")
    techtree, twins = edit_techtree(techtree)
    try:
        ElementTree.fromstring(techtree.encode("utf-8"))
    except ElementTree.ParseError as error:
        sys.exit(f"apply_fix: the edited techtreey.xml would not be valid XML ({error}); nothing changed")
    backup.mkdir()
    manifest = {"changed": [], "added": [], "horse": horse, "test": test}
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
        if src.stem.lower() not in needed:
            continue
        rel = src.relative_to(FILES).as_posix()
        if (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} exists already")
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, root / rel)
        manifest["added"].append(rel)

    path = root / "data/protoy.xml"
    text, enc = read_text(path)
    write_text(path, edit_proto(text, test), enc)

    write_text(root / "data/techtreey.xml", techtree, techtree_enc)
    print(f"techtreey.xml: {twins} effects twinned")

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

    for rel, parts in snippets(horse, test).items():
        path = root / rel
        text, enc = read_text(path)
        if "<anim>Dismounted_Idle" in text:
            continue
        add = crlf("".join((FILES / s).read_text(encoding="utf-8") for s in parts))
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
    manifest = root / BACKUP / "manifest.json"
    if manifest.exists():
        m = json.loads(manifest.read_text(encoding="utf-8"))
        print(f"horse on foot: {m.get('horse', 'keep')}; test unit {TEST_UNIT}: {'yes' if m.get('test') else 'no'}")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root = pathlib.Path(sys.argv[1])
    horse = "hide"
    if "--horse" in sys.argv:
        i = sys.argv.index("--horse")
        horse = sys.argv[i + 1] if i + 1 < len(sys.argv) else ""
        if horse not in ("hide", "keep"):
            sys.exit("apply_fix: --horse takes hide or keep")
    if "steamapps" in str(root).lower() and "--force" not in sys.argv:
        sys.exit("apply_fix: this is a Steam folder; work on a copy, or add --force to change it anyway")
    if "--restore" in sys.argv:
        restore(root)
    elif "--check" in sys.argv:
        check(root)
    else:
        apply(root, horse, "--test" in sys.argv)


if __name__ == "__main__":
    main()
