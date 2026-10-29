"""Write the damageOverTime test data into a test copy of the game.

Usage: python -I tools/dot_testdata.py <test folder>

Never point it at the Steam install: it refuses any folder under "steamapps".
- data\\protoy.xml: the Explorer's HandAttack and VolleyRangedAttack get
  <AttachProtoUnit>UHCPoisonTest</AttachProtoUnit>, and a new proto UHCPoisonTest is appended
  (Lifespan 10 s; Attaching: 20 Ranged damage every 1 s, DamageFlags GAIAEnemy).
- data\\protoy.xml.XMB: compiled from that XML with xmbedit (compressed, like the stock file).
- data\\tactics\\uhcpoisontest.tactics and .tactics.xmb: the Attaching action the proto needs.

The first run keeps the folder's protoy files as *.dot-orig. Every run starts again from
protoy.xml.dot-orig and compiles the XMB from the result, so it can be repeated after changing the
values below; protoy.xml.XMB.dot-orig is only a backup.
"""
import os
import pathlib
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import xmbedit  # noqa: E402

ATTACHMENT = "UHCPoisonTest"
ATTACKER = "Explorer"
ACTIONS = ("HandAttack", "VolleyRangedAttack")
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


def main(argv):
    if len(argv) != 1:
        sys.exit(__doc__)
    folder = pathlib.Path(argv[0]).resolve()
    data = (folder / "data").resolve()
    # Resolved, so a junction or symlink inside the copy cannot lead the writes into Steam.
    for path in (folder, data, (data / "tactics").resolve()):
        if "steamapps" in (part.lower() for part in path.parts):
            sys.exit(f"dot_testdata: {path} is inside a Steam library; use a test copy")
    xml_path, xmb_path = data / "protoy.xml", data / "protoy.xml.XMB"
    for path in (xml_path, xmb_path):
        keep = path.with_name(path.name + ".dot-orig")
        if not keep.exists():
            shutil.copy2(path, keep)
    text = (data / "protoy.xml.dot-orig").read_text(encoding="utf-8")

    unit = re.search(r"<Unit id ='\d+' name ='" + ATTACKER + r"'>.*?</Unit>", text, re.S)
    if unit is None:
        sys.exit(f"dot_testdata: no <Unit name='{ATTACKER}'> in {xml_path}")
    block = unit.group(0)
    for action in ACTIONS:
        pa = re.search(r"(<ProtoAction>\s*<Name>" + action + r"</Name>.*?)(\s*</ProtoAction>)", block, re.S)
        if pa is None:
            sys.exit(f"dot_testdata: {ATTACKER} has no ProtoAction {action}")
        tag = f"\n\t\t\t<AttachProtoUnit>{ATTACHMENT}</AttachProtoUnit>"
        block = block[:pa.start()] + pa.group(1) + tag + pa.group(2) + block[pa.end():]
    text = text[:unit.start()] + block + text[unit.end():]

    unit_id = max(int(i) for i in re.findall(r"<Unit id ='(\d+)'", text)) + 1
    dbid = max(int(i) for i in re.findall(r"<DBID>(\d+)</DBID>", text)) + 1
    new_unit = f"""\t<Unit id ='{unit_id}' name ='{ATTACHMENT}'>
\t\t<DBID>{dbid}</DBID>
\t\t<Lifespan>10.0000</Lifespan>
\t\t<Tactics>uhcpoisontest.tactics</Tactics>
\t\t<ProtoAction>
\t\t\t<Name>Attaching</Name>
\t\t\t<Damage>20.000000</Damage>
\t\t\t<DamageType>Ranged</DamageType>
\t\t\t<ROF>1.000000</ROF>
\t\t\t<DamageFlags>GAIAEnemy</DamageFlags>
\t\t</ProtoAction>
\t</Unit>
"""
    end = text.rindex("</Proto>")
    text = text[:end] + new_unit + text[end:]
    xml_path.write_text(text, encoding="utf-8", newline="\n")
    xmb_path.write_bytes(xmbedit.wrap(xmbedit.encode(*xmbedit.from_xml(text.encode("utf-8"))), compressed=True))

    tactics = data / "tactics"
    tactics.mkdir(exist_ok=True)
    (tactics / "uhcpoisontest.tactics").write_text(TACTICS, encoding="utf-8", newline="\n")
    (tactics / "uhcpoisontest.tactics.xmb").write_bytes(xmbedit.encode(*xmbedit.from_xml(TACTICS.encode("utf-8"))))
    print(f"{ATTACKER} {'/'.join(ACTIONS)} attach {ATTACHMENT}: unit id {unit_id}, DBID {dbid}")
    print(f"wrote {xml_path}, {xmb_path} and {tactics / 'uhcpoisontest.tactics'} (+ .xmb)")


if __name__ == "__main__":
    main(sys.argv[1:])
