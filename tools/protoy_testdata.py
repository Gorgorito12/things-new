"""Edit the protoy data of a test copy of the game for a feature test.

Usage:
    python -I tools/protoy_testdata.py <test folder> unittype <Proto>=<UnitType> [...]
    python -I tools/protoy_testdata.py <test folder> reset

unittype  adds <UnitType>UnitType</UnitType> to each named <Unit> of data\\protoy.xml (after its
          last UnitType), e.g. Explorer=AbstractDodge for dodgeAnyUnit, then compiles
          data\\protoy.xml.XMB from the result, so the game sees the same data whichever of the
          two it loads.
reset     puts the two files back as they were before the first run of this tool.

The first run keeps the folder's protoy files as *.testdata-orig; every run starts again from
those, so each run applies exactly the edits it is given. Never point it at the Steam install:
it refuses any folder under "steamapps".
"""
import os
import pathlib
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import xmbedit  # noqa: E402


def main(argv):
    if len(argv) < 2 or argv[1] not in ("unittype", "reset"):
        sys.exit(__doc__)
    folder = pathlib.Path(argv[0]).resolve()
    if "steamapps" in (part.lower() for part in folder.parts):
        sys.exit(f"protoy_testdata: {folder} is inside a Steam library; use a test copy")
    data = folder / "data"
    xml_path, xmb_path = data / "protoy.xml", data / "protoy.xml.XMB"
    keeps = [path.with_name(path.name + ".testdata-orig") for path in (xml_path, xmb_path)]
    for path, keep in zip((xml_path, xmb_path), keeps):
        if not keep.exists():
            shutil.copy2(path, keep)
    if argv[1] == "reset":
        for path, keep in zip((xml_path, xmb_path), keeps):
            shutil.copy2(keep, path)
            os.utime(path)  # newer than anything a run wrote, so the game loads the restored pair
        print(f"restored {xml_path} and {xmb_path}")
        return

    text = keeps[0].read_text(encoding="utf-8")
    for pair in argv[2:]:
        proto, _, unit_type = pair.partition("=")
        if not proto or not unit_type:
            sys.exit(f"protoy_testdata: expected <Proto>=<UnitType>, got {pair!r}")
        unit = re.search(r"<Unit id ='\d+' name ='" + re.escape(proto) + r"'>.*?</Unit>", text, re.S)
        if unit is None:
            sys.exit(f"protoy_testdata: no <Unit name='{proto}'> in {keeps[0]}")
        block = unit.group(0)
        if f"<UnitType>{unit_type}</UnitType>" in block:
            print(f"{proto} already has {unit_type}")
            continue
        types = list(re.finditer(r"\n(\s*)<UnitType>[^<]*</UnitType>", block))
        if not types:
            sys.exit(f"protoy_testdata: {proto} has no <UnitType> to insert after")
        last = types[-1]
        block = block[:last.end()] + f"\n{last.group(1)}<UnitType>{unit_type}</UnitType>" + block[last.end():]
        text = text[:unit.start()] + block + text[unit.end():]
        print(f"{proto} gets {unit_type}")
    xml_path.write_text(text, encoding="utf-8", newline="\n")
    xmb_path.write_bytes(xmbedit.wrap(xmbedit.encode(*xmbedit.from_xml(text.encode("utf-8"))), compressed=True))
    print(f"wrote {xml_path} and {xmb_path}")


if __name__ == "__main__":
    main(sys.argv[1:])
