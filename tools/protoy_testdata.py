"""Edit the protoy data of a test copy of the game for a feature test.

Usage:
    python -I tools/protoy_testdata.py <test folder> <verb> <edit> [...] [<verb> <edit> [...]] ...
    python -I tools/protoy_testdata.py <test folder> reset

Verbs (several can follow each other in one run; each applies to the edits after it):
unittype  <Proto>=<UnitType>  adds <UnitType>UnitType</UnitType> after the unit's last UnitType,
          e.g. Explorer=AbstractDodge for dodgeAnyUnit.
flag      <Proto>=+<Flag>     adds <Flag>Flag</Flag> after the unit's last Flag (or before
          </Unit> when it has none); <Proto>=-<Flag> removes that flag.
line      <Proto>=<xml>       inserts one XML element before the unit's </Unit>, e.g.
          "House=<Lifespan>20</Lifespan>".
reset     puts the two files back as they were before the first run of this tool.

After the edits it compiles data\\protoy.xml.XMB from the result, so the game sees the same data
whichever of the two it loads. The first run keeps the folder's protoy files as *.testdata-orig;
every run starts again from those, so each run applies exactly the edits it is given (give all of
a test's edits in one run). Never point it at the Steam install: it refuses any folder under
"steamapps".
"""
import os
import pathlib
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import xmbedit  # noqa: E402

VERBS = ("unittype", "flag", "line")


def unit_block(text, proto, source):
    unit = re.search(r"<Unit id ='\d+' name ='" + re.escape(proto) + r"'>.*?</Unit>", text, re.S)
    if unit is None:
        sys.exit(f"protoy_testdata: no <Unit name='{proto}'> in {source}")
    return unit


def insert_after_last(block, tag, element, proto):
    """Inserts element after the last <tag> line of the unit, or before </Unit> without one."""
    lines = list(re.finditer(r"\n(\s*)<" + tag + r">[^<]*</" + tag + ">", block))
    if lines:
        last = lines[-1]
        return block[:last.end()] + f"\n{last.group(1)}{element}" + block[last.end():]
    end = block.rindex("</Unit>")
    indent = re.search(r"\n(\s*)<", block).group(1)
    return block[:end].rstrip() + f"\n{indent}{element}\n\t" + block[end:]


def apply(text, verb, edit, source):
    proto, _, value = edit.partition("=")
    if not proto or not value:
        sys.exit(f"protoy_testdata: expected <Proto>=<value> after {verb}, got {edit!r}")
    unit = unit_block(text, proto, source)
    block = unit.group(0)
    if verb == "unittype":
        if f"<UnitType>{value}</UnitType>" in block:
            print(f"{proto} already has {value}")
            return text
        if "<UnitType>" not in block:
            sys.exit(f"protoy_testdata: {proto} has no <UnitType> to insert after")
        block = insert_after_last(block, "UnitType", f"<UnitType>{value}</UnitType>", proto)
        print(f"{proto} gets unit type {value}")
    elif verb == "flag":
        sign, flag = value[0], value[1:]
        if sign not in "+-" or not flag:
            sys.exit(f"protoy_testdata: expected <Proto>=+<Flag> or <Proto>=-<Flag>, got {edit!r}")
        present = re.search(r"\n\s*<Flag>" + re.escape(flag) + r"</Flag>", block)
        if sign == "+":
            if present:
                print(f"{proto} already has flag {flag}")
                return text
            block = insert_after_last(block, "Flag", f"<Flag>{flag}</Flag>", proto)
            print(f"{proto} gets flag {flag}")
        else:
            if not present:
                print(f"{proto} has no flag {flag}")
                return text
            block = block[:present.start()] + block[present.end():]
            print(f"{proto} loses flag {flag}")
    else:
        if not re.fullmatch(r"\s*<(\w+)[^>]*>.*</\1>\s*|\s*<\w+[^>]*/>\s*", value, re.S):
            sys.exit(f"protoy_testdata: {value!r} is not one XML element")
        end = block.rindex("</Unit>")
        indent = re.search(r"\n(\s*)<", block).group(1)
        block = block[:end].rstrip() + f"\n{indent}{value.strip()}\n\t" + block[end:]
        print(f"{proto} gets {value.strip()}")
    return text[:unit.start()] + block + text[unit.end():]


def main(argv):
    if len(argv) < 2 or argv[1] not in VERBS + ("reset",):
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
    verb = None
    for arg in argv[1:]:
        if arg in VERBS:
            verb = arg
            continue
        text = apply(text, verb, arg, keeps[0])
    xml_path.write_text(text, encoding="utf-8", newline="\n")
    xmb_path.write_bytes(xmbedit.wrap(xmbedit.encode(*xmbedit.from_xml(text.encode("utf-8"))), compressed=True))
    print(f"wrote {xml_path} and {xmb_path}")


if __name__ == "__main__":
    main(sys.argv[1:])
