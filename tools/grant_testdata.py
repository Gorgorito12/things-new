"""Test data for researchGrants in a WoL bed: grant tags on the Market, with scope self, and four test techs of
300 wood that the Market researches, so one building both holds the points and spends them.

    python -I tools/grant_testdata.py <bed>            writes the data, keeping the originals as *.grant-orig
    python -I tools/grant_testdata.py <bed> --restore  puts the originals back

Writes data\\protoy.xml and data\\techtreey.xml, with CRLF as they are (a WoL bed reads its data loose: no XMB).
The Market gets ResearchGrantInterval 20, ResearchGrantMax 3, ResearchGrantCost 0 and ResearchGrantScope self, and
the buttons of the techs UhcGrantTest1 to 4 (OBTAINABLE, 300 wood, 8 research points, no effect; the icons and
names of four stock Church techs) on its second row of techs.
"""
import os
import pathlib
import shutil
import sys

TAGS = (("ResearchGrantInterval", "20"), ("ResearchGrantMax", "3"), ("ResearchGrantCost", "0"),
        ("ResearchGrantScope", "self"))
# name, display name ID and icon of a stock Church tech, so that no Market button looks the same
TECHS = (
    ("UhcGrantTest1", 23389, r"WoL\ui\techs\euros\optics"),
    ("UhcGrantTest2", 23882, r"WoL\ui\techs\euros\public_lighting"),
    ("UhcGrantTest3", 23984, r"WoL\ui\techs\euros\reservists"),
    ("UhcGrantTest4", 36207, r"WoL\ui\techs\euros\mass_cavalry"),
)
PROTO = "Market"


def backup(path):
    orig = path.with_name(path.name + ".grant-orig")
    if not orig.exists():
        shutil.copy2(path, orig)


def restore(path):
    orig = path.with_name(path.name + ".grant-orig")
    if orig.exists():
        shutil.copy2(orig, path)
        orig.unlink()


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    bed = pathlib.Path(sys.argv[1])
    if "steamapps" in os.fspath(bed).lower():
        sys.exit("grant_testdata: refusing a folder inside a Steam library")
    data = bed / "data"
    proto, tree = data / "protoy.xml", data / "techtreey.xml"
    if "--restore" in sys.argv:
        for path in (proto, tree):
            restore(path)
        print("grant_testdata: restored")
        return
    for path in (proto, tree):
        backup(path)

    text = proto.read_bytes().decode("utf-8")
    start = text.index(f'name="{PROTO}"')
    flag = text.index("<Flag>", start)
    if "ResearchGrantInterval" not in text[start:flag]:
        lines = [f"<{tag}>{value}</{tag}>" for tag, value in TAGS]
        lines += [f"<Tech column='{i}' page='1' row='1'>{name}</Tech>" for i, (name, _, _) in enumerate(TECHS)]
        text = text[:flag] + "".join(line + "\r\n\t\t" for line in lines) + text[flag:]
        proto.write_bytes(text.encode("utf-8"))

    text = tree.read_bytes().decode("utf-8")
    if TECHS[0][0] not in text:
        out = ""
        for name, display, icon in TECHS:
            out += (f"\t<Tech name ='{name}' type ='Normal'>\r\n\t\t<DisplayNameID>{display}</DisplayNameID>\r\n"
                    "\t\t<Cost resourcetype ='Wood'>300.0000</Cost>\r\n\t\t<ResearchPoints>8.0000</ResearchPoints>\r\n"
                    f"\t\t<Status>OBTAINABLE</Status>\r\n\t\t<Icon>{icon}</Icon>\r\n\t</Tech>\r\n")
        at = text.rfind("</TechTree>")
        tree.write_bytes((text[:at] + out + text[at:]).encode("utf-8"))
    print(f"grant_testdata: {len(TAGS)} tags and {len(TECHS)} tech buttons on {PROTO}, {len(TECHS)} techs in "
          f"{os.fspath(bed)}")


if __name__ == "__main__":
    main()
