"""Test data for sharedBuildLimit with real units, in a WoL bed: a real wagon and a team's livestock.

    python -I tools/sharedlimit_testdata.py <bed>            writes the data, keeping .limit-orig copies
    python -I tools/sharedlimit_testdata.py <bed> --restore  puts them back

- `OutpostWagon` is trained at the Town Center and takes the limit of `Outpost` (4 here), with the Outposts counting
  toward it. `Outpost` stays untagged, so the wagons stop and the last wagon can still build.
- `ypGoat`, what the Ethiopians' pen trains, has a team limit of 10 over every `Herdable`; a `Cow` counts 2.
"""
import pathlib
import re
import shutil
import sys

LIMIT = 4
HERD = 10
TRAIN = '<Train column="4" page="0" row="0">OutpostWagon</Train>'
ENABLE = ("\r\n\t\t\t<Effect type ='Data' amount ='1.00' subtype ='Enable' relativity ='Absolute'>\r\n"
          "\t\t\t\t<Target type ='ProtoUnit'>{}</Target></Effect>")


def block(text, name):
    at = re.search(r'<Unit id="\d+" name="%s">' % name, text).start()
    return text[at:text.index("</Unit>", at) + len("</Unit>")]


def tag(text, name, lines):
    """Adds the lines to the proto, in front of its first <Flag> or at its end."""
    old = block(text, name)
    at = old.index("<Flag>") if "<Flag>" in old else old.index("</Unit>")
    return text.replace(old, old[:at] + "".join(f"{line}\r\n\t\t" for line in lines) + old[at:], 1)


def set_limit(text, name, value):
    old = block(text, name)
    new, count = re.subn(r"<BuildLimit>[^<]*</BuildLimit>", f"<BuildLimit>{value}</BuildLimit>", old, count=1)
    assert count == 1, name
    return text.replace(old, new, 1)


def main():
    bed = pathlib.Path(sys.argv[1])
    proto = bed / "data" / "protoy.xml"
    tree = bed / "data" / "techtreey.xml"
    pairs = [(path, path.with_name(path.name + ".limit-orig")) for path in (proto, tree)]
    if "--restore" in sys.argv:
        for live, keep in pairs:
            if keep.exists():
                shutil.copy2(keep, live)
                keep.unlink()
        print("sharedlimit_testdata: restored")
        return
    for live, keep in pairs:
        if not keep.exists():
            shutil.copy2(live, keep)
    text = pairs[0][1].read_bytes().decode("utf-8")
    text = set_limit(text, "Outpost", LIMIT)
    text = set_limit(text, "ypGoat", HERD)
    text = tag(text, "OutpostWagon", ["<SharedBuildLimitUnit>Outpost</SharedBuildLimitUnit>",
                                      "<SharedBuildLimitUnitType>Outpost</SharedBuildLimitUnitType>"])
    # The first entry that reaches a proto sets its weight, so the Cow goes before the type that holds it.
    text = tag(text, "ypGoat", ['<SharedBuildLimitUnitType weight="2">Cow</SharedBuildLimitUnitType>',
                                "<SharedBuildLimitUnitType>Herdable</SharedBuildLimitUnitType>",
                                "<TeamBuildLimit>1</TeamBuildLimit>"])
    old = block(text, "OutpostWagon")  # 60 s by stock
    text = text.replace(old, old.replace("<TrainPoints>60.0000</TrainPoints>", "<TrainPoints>8.0000</TrainPoints>"), 1)
    old = block(text, "TownCenter")
    at = old.index("<Train column")
    text = text.replace(old, old[:at] + TRAIN + "\r\n\t\t" + old[at:], 1)
    proto.write_bytes(text.encode("utf-8"))
    data = pairs[1][1].read_bytes().decode("utf-8", "surrogateescape")
    effects = ENABLE.format("OutpostWagon") + ENABLE.format("Outpost")
    data, count = re.subn(r"(<Tech name\s*=\s*'[^']*Age0[^']*'.*?<Effects>)", lambda m: m.group(1) + effects, data,
                          flags=re.S)
    # Techs that raise the limit would hide the number of the test.
    data, raised = re.subn(r"<Effect type ='Data' amount ='[^']*' subtype ='BuildLimit' relativity ='Absolute'>\s*"
                           r"<Target type ='ProtoUnit'>(?:Outpost|ypGoat)</Target></Effect>", "", data)
    tree.write_bytes(data.encode("utf-8", "surrogateescape"))
    print(f"sharedlimit_testdata: enabled in {count} techs, {raised} limit effects removed")


if __name__ == "__main__":
    main()
