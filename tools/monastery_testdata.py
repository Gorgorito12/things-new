"""Test data for linkedResource in a WoL bed: the building UhcMonastery, a gold resource with a trickle and a heal.

    python -I tools/monastery_testdata.py <bed>            writes the data, keeping protoy.xml as protoy.xml.link-orig
    python -I tools/monastery_testdata.py <bed> --model    the same, buildable and with a model of a monastery
    python -I tools/monastery_testdata.py <bed> --ai       --model, and a rule that makes the AI build one by a mine
    python -I tools/monastery_testdata.py <bed> --restore  puts it all back and removes the tactics file

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


# Stock art of the bed. The builders get the building in a free cell of their build list.
MODEL = {
    "AnimFile": "War of the Triple Alliance\\Natives\\ethiopian_monastery\\monastery_buildings.xml",
    "Icon": "War of the Triple Alliance\\Natives\\ethiopian_monastery\\native_ethiopian_monastery_icon_64",
    "PortraitIcon": "War of the Triple Alliance\\Natives\\ethiopian_monastery\\native_ethiopian_monastery_icon_portrait",
    "DisplayNameID": "1000457",
    "BuildPoints": "30.0000",
}
BUILDERS = ("AFRICANvillager", "Settler", "ypSettlerAsian", "ypSettlerJapanese")
TRAIN = '<Train column="9" page="0" row="1">UhcMonastery</Train>'
ENABLE = ("\r\n\t\t\t<Effect type ='Data' amount ='1.00' subtype ='Enable' relativity ='Absolute'>\r\n"
          "\t\t\t\t<Target type ='ProtoUnit'>UhcMonastery</Target></Effect>")
AI_RULE = """

// uhc test: one monastery by the mine nearest to the Town Center, through a plain build plan, and a gather plan for it.
// The scripts know nothing of this building: these two plans are all it takes. The spot is on the far side of
// the mine, as a mine can sit so close to the Town Center that nothing fits between them.
rule uhcMonasteryBuild
active
minInterval 5
{
   int proto = kbGetProtoUnitID("UhcMonastery");
   static int plan = -1;
   int building = getUnit(proto, cMyID, cUnitStateAlive);
   if (building >= 0)
   {
      // As the scripts do for a Tupi Wigham: a gather plan filtered on the building, as stock gatherers never pick it.
      int gather = aiPlanCreate("Monastery Gather", cPlanGather);
      aiPlanSetBaseID(gather, kbBaseGetMainID(cMyID));
      aiPlanSetVariableInt(gather, cGatherPlanResourceUnitTypeFilter, 0, proto);
      aiPlanSetVariableInt(gather, cGatherPlanResourceType, 0, cResourceGold);
      aiPlanAddUnitType(gather, gEconUnit, 3, 3, 3);
      aiPlanSetDesiredPriority(gather, 90);
      aiPlanSetActive(gather);
      aiChat(1, "uhc: built " + building + " at " + xsGetTime() + ", gather plan " + gather);
      xsDisableSelf();
      return;
   }
   if (plan >= 0)
   {
      if (aiPlanGetState(plan) >= 0)
      {
         aiChat(1, "uhc: plan " + plan + " state " + aiPlanGetState(plan));
         return;
      }
      if (kbUnitCount(cMyID, proto, cUnitStateBuilding) > 0)
         return;
   }
   int tc = getUnit(cUnitTypeTownCenter, cMyID);
   if (tc < 0)
      return;
   vector base = kbUnitGetPosition(tc);
   kbLookAtAllUnitsOnMap();
   static int query = -1;
   if (query < 0)
   {
      query = kbUnitQueryCreate("uhcMineQuery");
      kbUnitQuerySetPlayerID(query, 0);
      kbUnitQuerySetUnitType(query, cUnitTypeAbstractMine);
      kbUnitQuerySetState(query, cUnitStateAlive);
      kbUnitQuerySetAscendingSort(query, true);
   }
   kbUnitQuerySetPosition(query, base);
   kbUnitQuerySetMaximumDistance(query, 70.0);
   kbUnitQueryResetResults(query);
   if (kbUnitQueryExecute(query) < 1)
      return;
   int mine = kbUnitQueryGetResult(query, 0);
   vector position = kbUnitGetPosition(mine);
   position = position + xsVectorNormalize(position - base) * 9.0;
   plan = createLocationBuildPlan(proto, 1, 100, true, -1, position, 2);
   aiPlanSetVariableFloat(plan, cBuildPlanCenterPositionDistance, 0, 6.0);
   aiChat(1, "uhc: plan " + plan + " by mine " + mine + ", " + xsVectorLength(kbUnitGetPosition(mine) - base) + " m from the TC");
}
""".replace("\n", "\r\n")


def block(text, name):
    at = re.search(r'<Unit id="\d+" name="%s">' % name, text).start()
    return text[at:text.index("</Unit>", at) + len("</Unit>")]


def main():
    bed = pathlib.Path(sys.argv[1])
    proto = bed / "data" / "protoy.xml"
    tactics = bed / "data" / "tactics" / "uhcmonastery.tactics"
    orig = proto.with_name(proto.name + ".link-orig")
    ai = bed / "AI4" / "aiWoLMain.xs"
    ai_orig = ai.with_name(ai.name + ".link-orig")
    tree = bed / "data" / "techtreey.xml"
    tree_orig = tree.with_name(tree.name + ".link-orig")
    if "--restore" in sys.argv:
        for keep, live in ((orig, proto), (ai_orig, ai), (tree_orig, tree)):
            if keep.exists():
                shutil.copy2(keep, live)
                keep.unlink()
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
        if "--model" in sys.argv or "--ai" in sys.argv:
            for tag, value in MODEL.items():
                unit, n = re.subn(rf"<{tag}>[^<]*</{tag}>", lambda _: f"<{tag}>{value}</{tag}>", unit, count=1)
                assert n == 1, tag
            for name in BUILDERS:
                old = block(text, name)
                at = old.index("<Train column")
                text = text.replace(old, old[:at] + TRAIN + "\r\n\t\t" + old[at:], 1)
        at = text.rfind("</Proto>")
        text = text[:at] + "\t" + unit + "\r\n\t" + mine + "\r\n" + text[at:]
        proto.write_bytes(text.encode("utf-8"))
    if ("--model" in sys.argv or "--ai" in sys.argv) and not tree_orig.exists():
        # Each civ's first tech enables the building.
        shutil.copy2(tree, tree_orig)
        data = tree.read_bytes().decode("utf-8", "surrogateescape")
        data, count = re.subn(r"(<Tech name\s*=\s*'[^']*Age0[^']*'.*?<Effects>)", lambda m: m.group(1) + ENABLE, data,
                              flags=re.S)
        tree.write_bytes(data.encode("utf-8", "surrogateescape"))
        print(f"monastery_testdata: enabled in {count} techs")
    if "--ai" in sys.argv and not ai_orig.exists():
        shutil.copy2(ai, ai_orig)
        ai.write_bytes(ai.read_bytes() + AI_RULE.encode("utf-8"))
    tactics.write_bytes(TACTICS.encode("utf-8"))
    print("monastery_testdata: UhcMonastery and UhcSmallMine written")


if __name__ == "__main__":
    main()
