"""Test data for unitResourceAuras with the tags of a Torp, in a WoL bed: the WOLSawmill gets one aura per kind of
resource, a panel row, and two test techs.

    python -I tools/torp_testdata.py <bed>            writes the data, keeping the originals as *.torp-orig
    python -I tools/torp_testdata.py <bed> --restore  puts the originals back

Writes data\\tactics\\sawmill.tactics, data\\protoy.xml and data\\techtreey.xml, with CRLF as they are. Copy tools\\rings to
art\\effects\\uhc_rings in the bed for the markers, and remove it after.
"""
import os
import pathlib
import shutil
import sys

TAB = "\t"


def aura(name, target, amount, maxrange, colour, *tags):
    lines = [f"<name>{name}</name>", "<type>AutoRangedModify</type>", f"<modifyabstracttype>{target}</modifyabstracttype>",
             "<active>1</active>", f"<maxrange>{maxrange}</maxrange>", "<persistent>1</persistent>",
             "<modifytype>UnitResource</modifytype>", f"<modifyamount>{amount}</modifyamount>",
             f"<modelattachment>effects\\uhc_rings\\aura_{colour}.xml</modelattachment>",
             "<modelattachmentbone>bonethatdoesntexist</modelattachmentbone>"]
    return "\r\n".join(["\t<action>"] + [TAB * 2 + line for line in lines + list(tags)] + ["\t</action>", ""])


# Wider than a Torp's, so a test map need not place things to the metre.
AURAS = {
    "AreaGatherMine": aura("AreaGatherMine", "AbstractMine", "0.27", 14, "gold", "<includegaia>1</includegaia>",
                           "<forbidunittype>Plantation</forbidunittype>", "<singleunit>1</singleunit>"),
    "AreaGatherBerry": aura("AreaGatherBerry", "AbstractFruit", "0.30", 14, "food", "<includegaia>1</includegaia>",
                            "<donotignoredead>1</donotignoredead>", "<singleunit>1</singleunit>"),
    "AreaGatherHuntable": aura("AreaGatherHuntable", "Huntable", "0.42", 14, "food", "<targetgaia>1</targetgaia>",
                               "<donotignoredead>1</donotignoredead>", "<deadexclusive>1</deadexclusive>",
                               "<singleunit>1</singleunit>"),
    "AreaGatherHerdable": aura("AreaGatherHerdable", "Herdable", "1.00", 14, "food", "<targetgaia>1</targetgaia>",
                               "<donotignoredead>1</donotignoredead>", "<deadexclusive>1</deadexclusive>",
                               "<singleunit>1</singleunit>"),
    "AreaGatherCrate": aura("AreaGatherCrate", "AbstractResourceCrate", "4.00", 14, "gold",
                            "<includegaia>1</includegaia>", "<modifytargetlimit>20</modifytargetlimit>"),
}
TECHS = (
    ("UhcTorpHalfMine", "<Effect type ='Data' amount ='0.50' subtype ='ModifyRate' action ='AreaGatherMine' relativity ='BasePercent'>"),
    ("UhcTorpNoTree", "<Effect type ='Data' amount ='0.00' subtype ='ActionEnable' action ='AreaGatherTree' relativity ='Absolute'>"),
)


def backup(path):
    orig = path.with_name(path.name + ".torp-orig")
    if not orig.exists():
        shutil.copy2(path, orig)


def restore(path):
    orig = path.with_name(path.name + ".torp-orig")
    if orig.exists():
        shutil.copy2(orig, path)
        orig.unlink()


def main():
    bed = pathlib.Path(sys.argv[1])
    data = bed / "data"
    tactics, proto, tree = data / "tactics" / "sawmill.tactics", data / "protoy.xml", data / "techtreey.xml"
    if "--restore" in sys.argv:
        for path in (tactics, proto, tree):
            restore(path)
        print("torp_testdata: restored")
        return
    for path in (tactics, proto, tree):
        backup(path)

    text = tactics.read_bytes().decode("utf-8")
    if "AreaGatherMine" not in text:
        at = text.index("<tactic>")
        text = text[:at].rstrip("\t") + "".join(AURAS.values()) + "\t" + text[at:]
        marker = "<action>AreaGatherTree</action>\r\n"
        lines = "".join(f"\t\t<action>{name}</action>\r\n" for name in AURAS)
        text = text.replace(marker, marker + lines, 1)
        text = text.replace("effects\\ypack_auras\\torpgatherpower.xml", "effects\\uhc_rings\\aura_wood.xml")
        tactics.write_bytes(text.encode("utf-8"))

    text = proto.read_bytes().decode("utf-8")
    start = text.index('name="WOLSawmill"') if 'name="WOLSawmill"' in text else text.index("name ='WOLSawmill'")
    flag = text.index("<Flag>", start)
    if "ShowUnitResourceActionRates" not in text[start:flag]:
        tags = "<ShowUnitResourceActionRates>1</ShowUnitResourceActionRates>\r\n\t\t"
        text = text[:flag] + tags + text[flag:]
        proto.write_bytes(text.encode("utf-8"))

    text = tree.read_bytes().decode("utf-8")
    if "UhcTorpHalfMine" not in text:
        out = ""
        for name, effect in TECHS:
            out += (f"\t<Tech name ='{name}' type ='Normal'>\r\n\t\t<Status>OBTAINABLE</Status>\r\n\t\t<Effects>\r\n"
                    f"\t\t\t{effect}\r\n\t\t\t\t<Target type ='ProtoUnit'>WOLSawmill</Target></Effect>\r\n"
                    "\t\t</Effects>\r\n\t</Tech>\r\n")
        at = text.rfind("</TechTree>")
        tree.write_bytes((text[:at] + out + text[at:]).encode("utf-8"))
    print(f"torp_testdata: {len(AURAS)} auras on WOLSawmill, {len(TECHS)} techs in {os.fspath(bed)}")


if __name__ == "__main__":
    main()
