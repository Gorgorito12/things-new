"""Write the damageOverTime test data into a test copy of the game.

Usage: python -I tools/dot_testdata.py <test folder> [--ai]

--ai also gives common military units (AI_ATTACKERS) a long, weak poison, so that an AI game
(two AI players fighting) has poisoned army units whose attacker has died and been removed.

Never point it at the Steam install: it refuses any folder under "steamapps".
- data\\protoy.xml: each attacker of ATTACKERS gets <AttachProtoUnit> (and the extra tags of its
  row) in the listed ProtoActions, and the attachment protos of ATTACHMENTS are appended.
- data\\techtreey.xml: the techs of TECHS are appended (status UNOBTAINABLE; a test turns them on
  with a trigger).
- the .XMB of both, compiled from that XML with xmbedit (compressed, like the stock files).
- data\\tactics\\uhcpoisontest.tactics and .tactics.xmb: the Attaching action the protos need.

The first run keeps the folder's files as *.dot-orig. Every run starts again from the .dot-orig
XML and compiles the XMB from the result, so it can be repeated after changing the tables below;
the .XMB.dot-orig files are only backups.
"""
import os
import pathlib
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import xmbedit  # noqa: E402

TACTICS_FILE = "uhcpoisontest.tactics"

# Attachment protos: name -> (Lifespan s, Damage, DamageType, ROF s, DamageFlags, extra lines of
# the Attaching action).
ATTACHMENTS = {
    # The Explorer's poison of the first tests: 20 every second for 10 s.
    "UHCPoisonTest": (10, 20, "Ranged", 1, "GAIAEnemy", []),
    # Grenadier: an area attack with a flying grenade; Enemy only, so a unit converted to the
    # attacker's side is excluded.
    "UHCPoisonGrenade": (6, 10, "Siege", 1, "Enemy", []),
    # Crossbowman: a flying arrow; triple damage against cavalry; UHCPoisonArrowUpgrade doubles it.
    "UHCPoisonArrow": (8, 6, "Hand", 1, "GAIAEnemy", ["<DamageBonus type ='AbstractCavalry'>3.000000</DamageBonus>"]),
    # Falconet: a cannon ball.
    "UHCPoisonCannon": (9, 15, "Siege", 1, "GAIAEnemy", []),
    # Longbowman: the phase 2 tags (stacks, snare, tick text) are on its attacks.
    "UHCPoisonStack": (6, 5, "Siege", 1, "GAIAEnemy", []),
}

RANGED = ("VolleyRangedAttack", "StaggerRangedAttack", "DefendRangedAttack")

# Attacker proto -> (ProtoActions, attachment, extra tags in those ProtoActions).
ATTACKERS = {
    "Explorer": (("HandAttack", "VolleyRangedAttack"), "UHCPoisonTest", []),
    "Grenadier": (RANGED, "UHCPoisonGrenade", []),
    "Crossbowman": (RANGED, "UHCPoisonArrow", []),
    "Falconet": (("CannonAttack",), "UHCPoisonCannon", []),
    "Longbowman": (RANGED, "UHCPoisonStack", [
        "<AttachMaxStacks>3</AttachMaxStacks>",
        "<AttachSnare>0.5</AttachSnare>",
        "<AttachTickText>40FF40</AttachTickText>",
    ]),
}

# With --ai: a 30 s poison of 2 per second on units every European AI trains.
AI_ATTACHMENTS = {"UHCPoisonLong": (30, 2, "Siege", 1, "GAIAEnemy", [])}
AI_ATTACKERS = {
    "Musketeer": (RANGED, "UHCPoisonLong", []),
    "Skirmisher": (RANGED, "UHCPoisonLong", []),
    "Pikeman": (("MeleeHandAttack",), "UHCPoisonLong", []),
    "Hussar": (("MeleeHandAttack",), "UHCPoisonLong", []),
}

# Techs: name -> effects (each a Data effect on the Attaching action of an attachment proto).
TECHS = {
    "UHCPoisonArrowUpgrade": [
        "<Effect type ='Data' action ='Attaching' amount ='2.0000' subtype ='Damage' relativity ='BasePercent'>"
        "\n\t\t\t\t<Target type ='ProtoUnit'>UHCPoisonArrow</Target></Effect>",
    ],
}

# The tactic's first child follows its name on the same line: when the game reads the XML (no
# .xmb), a line feed after the name stays in it, and the AI scripts then fail to compile
# (docs/modding-guide.md, "Tactics files").
TACTICS = """<?xml version="1.0" encoding="utf-8"?>
<tactics>
  <action>
    <name>Attaching</name>
    <type>Attack</type>
    <rate type="Unit">1.0</rate>
  </action>
  <tactic>Normal<action priority="100">Attaching</action></tactic>
</tactics>
"""


def keep_originals(data, names):
    for name in names:
        path = data / name
        keep = path.with_name(path.name + ".dot-orig")
        if not keep.exists():
            shutil.copy2(path, keep)


def compile_xmb(text, path):
    path.write_bytes(xmbedit.wrap(xmbedit.encode(*xmbedit.from_xml(text.encode("utf-8"))), compressed=True))


def edit_protos(text):
    for attacker, (actions, attachment, tags) in ATTACKERS.items():
        unit = re.search(r"<Unit id ='\d+' name ='" + attacker + r"'>.*?</Unit>", text, re.S)
        if unit is None:
            sys.exit(f"dot_testdata: no <Unit name='{attacker}'> in protoy.xml")
        block = unit.group(0)
        for action in actions:
            pa = re.search(r"(<ProtoAction>\s*<Name>" + action + r"</Name>.*?)(\s*</ProtoAction>)", block, re.S)
            if pa is None:
                sys.exit(f"dot_testdata: {attacker} has no ProtoAction {action}")
            added = "".join(f"\n\t\t\t{tag}" for tag in [f"<AttachProtoUnit>{attachment}</AttachProtoUnit>", *tags])
            block = block[:pa.start()] + pa.group(1) + added + pa.group(2) + block[pa.end():]
        text = text[:unit.start()] + block + text[unit.end():]
        print(f"{attacker} {'/'.join(actions)} attach {attachment}{' + ' + ', '.join(tags) if tags else ''}")

    unit_id = max(int(i) for i in re.findall(r"<Unit id ='(\d+)'", text)) + 1
    dbid = max(int(i) for i in re.findall(r"<DBID>(\d+)</DBID>", text)) + 1
    units = ""
    for name, (lifespan, damage, damage_type, rof, flags, extra) in ATTACHMENTS.items():
        lines = "".join(f"\t\t\t{line}\n" for line in extra)
        units += f"""\t<Unit id ='{unit_id}' name ='{name}'>
\t\t<DBID>{dbid}</DBID>
\t\t<Lifespan>{lifespan:.4f}</Lifespan>
\t\t<Tactics>{TACTICS_FILE}</Tactics>
\t\t<ProtoAction>
\t\t\t<Name>Attaching</Name>
\t\t\t<Damage>{damage:.6f}</Damage>
\t\t\t<DamageType>{damage_type}</DamageType>
\t\t\t<ROF>{rof:.6f}</ROF>
\t\t\t<DamageFlags>{flags}</DamageFlags>
{lines}\t\t</ProtoAction>
\t</Unit>
"""
        print(f"{name}: unit id {unit_id}, DBID {dbid}: {damage} {damage_type} every {rof} s for {lifespan} s, {flags}")
        unit_id += 1
        dbid += 1
    end = text.rindex("</Proto>")
    return text[:end] + units + text[end:]


def edit_techs(text):
    index = len(re.findall(r"<Tech name\s*=", text))
    dbid = max(int(i) for i in re.findall(r"<DBID>(\d+)</DBID>", text)) + 1
    techs = ""
    for name, effects in TECHS.items():
        body = "".join(f"\n\t\t\t{effect}" for effect in effects)
        techs += f"""\t<Tech name ='{name}' type ='Normal'>
\t\t<DBID>{dbid}</DBID>
\t\t<DisplayNameID>23370</DisplayNameID>
\t\t<ResearchPoints>1.0000</ResearchPoints>
\t\t<Status>UNOBTAINABLE</Status>
\t\t<Effects>{body}
\t\t</Effects>
\t</Tech>
"""
        print(f"tech {name}: index {index}, DBID {dbid}")
        index += 1
        dbid += 1
    end = text.rindex("</TechTree>")
    return text[:end] + techs + text[end:]


def main(argv):
    if len(argv) not in (1, 2) or argv[1:] not in ([], ["--ai"]):
        sys.exit(__doc__)
    if argv[1:] == ["--ai"]:
        ATTACHMENTS.update(AI_ATTACHMENTS)
        ATTACKERS.update(AI_ATTACKERS)
    folder = pathlib.Path(argv[0]).resolve()
    data = (folder / "data").resolve()
    # Resolved, so a junction or symlink inside the copy cannot lead the writes into Steam.
    for path in (folder, data, (data / "tactics").resolve()):
        if "steamapps" in (part.lower() for part in path.parts):
            sys.exit(f"dot_testdata: {path} is inside a Steam library; use a test copy")
    keep_originals(data, ("protoy.xml", "protoy.xml.XMB", "techtreey.xml", "techtreey.xml.XMB"))

    protos = edit_protos((data / "protoy.xml.dot-orig").read_text(encoding="utf-8"))
    (data / "protoy.xml").write_text(protos, encoding="utf-8", newline="\n")
    compile_xmb(protos, data / "protoy.xml.XMB")

    techs = edit_techs((data / "techtreey.xml.dot-orig").read_text(encoding="utf-8"))
    (data / "techtreey.xml").write_text(techs, encoding="utf-8", newline="\n")
    compile_xmb(techs, data / "techtreey.xml.XMB")

    tactics = data / "tactics"
    tactics.mkdir(exist_ok=True)
    (tactics / TACTICS_FILE).write_text(TACTICS, encoding="utf-8", newline="\n")
    (tactics / (TACTICS_FILE + ".xmb")).write_bytes(xmbedit.encode(*xmbedit.from_xml(TACTICS.encode("utf-8"))))
    print(f"wrote protoy.xml, techtreey.xml (+ .XMB) and tactics\\{TACTICS_FILE} (+ .xmb) in {data}")


if __name__ == "__main__":
    main(sys.argv[1:])
