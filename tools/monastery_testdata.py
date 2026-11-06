"""Test data for linkedResource in a WoL bed: the building UhcMonastery, a gold resource with a trickle and a heal.

    python -I tools/monastery_testdata.py <bed>            writes the data, keeping protoy.xml as protoy.xml.link-orig
    python -I tools/monastery_testdata.py <bed> --restore  puts it back and removes the tactics file

The proto is a copy of ypBerryBuilding, a stock resource building: gold, no DieAtZeroResources, AbstractMine so that a
villager's mine rate works on it. A 200-gold UhcSmallMine is added to see a mine run out.
"""
import pathlib
import re
import shutil
import sys

TACTICS = """<?xml version="1.0" encoding="utf-8"?>

<tactics>
\t<action>
\t\t<name>AutoGatherGold</name>
\t\t<type>AutoGather</type>
\t\t<active>1</active>
\t\t<persistent>1</persistent>
\t\t<gatherlinkedresource>1</gatherlinkedresource>
\t</action>
\t<action>
\t\t<name>Heal</name>
\t\t<type>Heal</type>
\t\t<maxrange>20</maxrange>
\t\t<rate type="LogicalTypeHealed">3.0</rate>
\t\t<active>1</active>
\t</action>
\t<tactic>
\t\tNormal
\t\t<action>AutoGatherGold</action>
\t\t<action>Heal</action>
\t</tactic>
</tactics>
""".replace("\n", "\r\n")


def block(text, name):
    at = re.search(r'<Unit id="\d+" name="%s">' % name, text).start()
    return text[at:text.index("</Unit>", at) + len("</Unit>")]


def main():
    bed = pathlib.Path(sys.argv[1])
    proto = bed / "data" / "protoy.xml"
    tactics = bed / "data" / "tactics" / "uhcmonastery.tactics"
    orig = proto.with_name(proto.name + ".link-orig")
    if "--restore" in sys.argv:
        if orig.exists():
            shutil.copy2(orig, proto)
            orig.unlink()
        tactics.unlink(missing_ok=True)
        print("monastery_testdata: restored")
        return
    if not orig.exists():
        shutil.copy2(proto, orig)
    text = proto.read_bytes().decode("utf-8")
    if "UhcMonastery" not in text:
        ids = [int(i) for i in re.findall(r'<Unit id="(\d+)"', text)]
        dbids = [int(i) for i in re.findall(r"<DBID>(\d+)</DBID>", text)]
        unit = block(text, "ypBerryBuilding")
        unit = re.sub(r'<Unit id="\d+" name="ypBerryBuilding">', f'<Unit id="{max(ids) + 1}" name="UhcMonastery">', unit)
        unit = re.sub(r"<DBID>\d+</DBID>", f"<DBID>{max(dbids) + 1}</DBID>", unit)
        unit = re.sub(r'<InitialResource resourcetype="Food">[^<]*</InitialResource>',
                      '<InitialResource resourcetype="Gold">900.0000</InitialResource>', unit)
        unit = unit.replace("<ResourceSubType>forage</ResourceSubType>", "<ResourceSubType>Gold</ResourceSubType>")
        unit = unit.replace("<UnitType>Food</UnitType>", "<UnitType>Gold</UnitType>")
        unit = unit.replace("<UnitType>AbstractFruit</UnitType>", "<UnitType>AbstractMine</UnitType>")
        unit = unit.replace("\t\t<Flag>DieAtZeroResources</Flag>\r\n", "")
        extra = ("\t\t<Tactics>uhcmonastery.tactics</Tactics>\r\n\t\t<ProtoAction>\r\n\t\t\t<Name>AutoGatherGold</Name>\r\n"
                 '\t\t\t<Rate type="Gold">0.5000</Rate>\r\n\t\t</ProtoAction>\r\n'
                 "\t\t<LinkedResourceType>AbstractMine</LinkedResourceType>\r\n"
                 "\t\t<LinkedResourceRange>12</LinkedResourceRange>\r\n\t\t")
        flag = unit.index("<Flag>")
        unit = unit[:flag] + extra.lstrip("\t") + unit[flag:]
        mine = block(text, "Mine")
        mine = re.sub(r'<Unit id="\d+" name="Mine">', f'<Unit id="{max(ids) + 2}" name="UhcSmallMine">', mine)
        mine = re.sub(r"<DBID>\d+</DBID>", f"<DBID>{max(dbids) + 2}</DBID>", mine)
        mine = re.sub(r'(<InitialResource resourcetype="Gold">)[^<]*', r"\g<1>200.0000", mine)
        at = text.rfind("</Proto>")
        text = text[:at] + "\t" + unit + "\r\n\t" + mine + "\r\n" + text[at:]
        proto.write_bytes(text.encode("utf-8"))
    tactics.write_bytes(TACTICS.encode("utf-8"))
    print("monastery_testdata: UhcMonastery and UhcSmallMine written")


if __name__ == "__main__":
    main()
