"""Write the decimalPopulation test data into a test copy of the game.

Usage: python -I tools/pop_testdata.py <test folder> [--restore]

Never point it at the Steam install: it refuses any folder under "steamapps".
- data\\protoy.xml: the decimal values of PROTO_VALUES (Settler, Crossbowman and Hussar 1.5,
  Pikeman 0.5, Manor +7.5).
- data\\techtreey.xml: the techs of TECHS appended (status UNOBTAINABLE; a test turns them on with
  a trigger, e.g. "at35=Set Tech Status;PlayerID=1;TechID=tech:UHCPopCountTest;Status=2" in a
  testbed.py map). Appended, so the stock tech indices do not change.
- the .XMB of both, compiled from that XML with xmbedit (compressed, like the stock files).

The first run keeps the folder's four files as *.pop-before. Every run starts again from the
.xml.pop-before files, so it can be repeated after changing the tables below; --restore puts the
four files back.
"""
import os
import pathlib
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import xmbedit  # noqa: E402

FILES = ["protoy.xml", "protoy.xml.XMB", "techtreey.xml", "techtreey.xml.XMB"]

# (proto, tag, value)
PROTO_VALUES = [
    ("Settler", "PopulationCount", "1.5"),
    ("Pikeman", "PopulationCount", "0.5"),
    ("Crossbowman", "PopulationCount", "1.5"),
    ("Hussar", "PopulationCount", "1.5"),
    ("Manor", "PopulationCapAddition", "7.5"),
]

# name -> effects: (subtype, relativity, amount, target type, target)
TECHS = {
    # The training test: Crossbowman 1.5 -> 2, Musketeer 1 -> 0.5, Town Center 10 -> 12.5.
    "UHCPopCountTest": [
        ("PopulationCount", "Absolute", "0.50", "ProtoUnit", "Crossbowman"),
        ("PopulationCount", "Assign", "0.50", "ProtoUnit", "Musketeer"),
        ("PopulationCapAddition", "Absolute", "2.50", "ProtoUnit", "TownCenter"),
    ],
    # The player's cap + 2.5.
    "UHCPopCapTest": [("PopulationCap", "Absolute", "2.50", "Player", "")],
    # The cap + 300, to reach the limits (200 in stock, basePop with that key).
    "UHCPopCapBig": [("PopulationCap", "Absolute", "300.00", "Player", "")],
    # BasePercent, rounded to the nearest step: Hussar 1.5 x 0.6 -> 0.9, Pikeman 0.5 x 3 -> 1.5.
    "UHCPopPercentTest": [
        ("PopulationCount", "BasePercent", "0.60", "ProtoUnit", "Hussar"),
        ("PopulationCount", "BasePercent", "3.00", "ProtoUnit", "Pikeman"),
    ],
}


def set_tag(text, unit, tag, value):
    m = re.search(r"<Unit\s[^>]*name\s*=\s*['\"]%s['\"][^>]*>.*?</Unit>" % re.escape(unit), text, re.S)
    if not m:
        sys.exit(f"pop_testdata: no unit {unit} in protoy.xml")
    block, n = re.subn(r"<%s>[^<]*</%s>" % (tag, tag), f"<{tag}>{value}</{tag}>", m.group(0))
    if n != 1:
        sys.exit(f"pop_testdata: {unit} has {n} <{tag}> elements, expected 1")
    return text[:m.start()] + block + text[m.end():]


def tech_xml(name, dbid, effects):
    lines = [f"\t<Tech name ='{name}' type ='Normal'>", f"\t\t<DBID>{dbid}</DBID>",
             "\t\t<ResearchPoints>0.0000</ResearchPoints>", "\t\t<Status>UNOBTAINABLE</Status>",
             "\t\t<Flag>Shadow</Flag>", "\t\t<Effects>"]
    for subtype, relativity, amount, target_type, target in effects:
        lines.append(f"\t\t\t<Effect type ='Data' amount ='{amount}' subtype ='{subtype}' "
                     f"relativity ='{relativity}'>")
        lines.append(f"\t\t\t\t<Target type ='{target_type}'>{target}</Target></Effect>")
    lines += ["\t\t</Effects>", "\t</Tech>"]
    return "\n".join(lines) + "\n"


def main(argv):
    if not argv or argv[0].startswith("-"):
        sys.exit(__doc__)
    folder = pathlib.Path(argv[0]).resolve()
    if "steamapps" in (p.lower() for p in folder.parts):
        sys.exit("pop_testdata: refusing a folder inside a Steam library; use a test copy")
    data = folder / "data"
    if "--restore" in argv:
        for f in FILES:
            shutil.copy2(data / (f + ".pop-before"), data / f)
        print("pop_testdata: restored the *.pop-before files")
        return
    for f in FILES:
        if not (data / (f + ".pop-before")).exists():
            shutil.copy2(data / f, data / (f + ".pop-before"))

    protoy = (data / "protoy.xml.pop-before").read_bytes().decode("utf-8")
    for unit, tag, value in PROTO_VALUES:
        protoy = set_tag(protoy, unit, tag, value)
    (data / "protoy.xml").write_bytes(protoy.encode("utf-8"))

    techs = (data / "techtreey.xml.pop-before").read_bytes().decode("utf-8")
    dbid = max(int(x) for x in re.findall(r"<DBID>(\d+)</DBID>", techs))
    added = "".join(tech_xml(name, dbid + 1 + i, effects) for i, (name, effects) in enumerate(TECHS.items()))
    if techs.count("</TechTree>") != 1:
        sys.exit("pop_testdata: techtreey.xml has no single </TechTree>")
    techs = techs.replace("</TechTree>", added + "</TechTree>")
    (data / "techtreey.xml").write_bytes(techs.encode("utf-8"))
    count = len(re.findall(r"<Tech\s", techs))
    first = count - len(TECHS)
    print("pop_testdata: techs " + ", ".join(f"{name} {first + i}" for i, name in enumerate(TECHS)))

    for name in ("protoy.xml", "techtreey.xml"):
        xmbedit.main(["from-xml", str(data / name), str(data / (name + ".XMB")), "--compress"])


if __name__ == "__main__":
    main(sys.argv[1:])
