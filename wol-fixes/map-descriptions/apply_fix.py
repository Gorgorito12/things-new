"""Puts the standard map descriptions into a Wars of Liberty folder (or writes the changed files to
an output folder).

    python apply_fix.py <WoL folder> [--out <folder>] [--csv descriptions.csv] [--restore]

For every row of descriptions.csv (map, lobby_id, loading_id, lobby_en, loading_en, lobby_es,
loading_es):
1. the string tables get the two strings (an existing string with the same ID is replaced):
   - translations\\_originals\\stringtabley.xml: English,
   - translations\\ES-LA\\stringtabley.xml: Spanish,
   - data\\stringtabley.xml: English or Spanish, whichever language that file holds (the launcher
     copies a translation over it);
2. RM4\\<map>.xml gets details="<lobby_id>" and loadDetails="<loading_id>", and loses its literal
   texts (detailsText, loadDetailsText, also misspelt ones such as detailstext or loadDetailsTexT),
   so every language shows the string table's text.

A text holds "\\n" (backslash, n) where a line break goes, as the game's own strings do.
Before the first change each file is copied to <WoL folder>\\map-descriptions-backup\\; --restore puts
those copies back and deletes the backup folder.
"""
import csv
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def decode(raw):
    if raw[:2] == b"\xff\xfe":
        return raw[2:].decode("utf-16-le"), "utf-16"
    if raw[:3] == b"\xef\xbb\xbf":
        return raw[3:].decode("utf-8"), "utf-8-sig"
    return raw.decode("utf-8"), "utf-8"


def encode(text, kind):
    if kind == "utf-16":
        return b"\xff\xfe" + text.encode("utf-16-le")
    if kind == "utf-8-sig":
        return b"\xef\xbb\xbf" + text.encode("utf-8")
    return text.encode("utf-8")


def xml_text(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def set_strings(text, strings):
    """Replaces or adds <String _locID='id'>text</String> entries before </Language>."""
    nl = "\r\n" if "\r\n" in text else "\n"
    quote = '"' if re.search(r'<String _locID="', text) else "'"
    m = re.search(r"\n([ \t]*)<String ", text)
    indent = m.group(1) if m else "\t\t"
    added = []
    for sid, value in strings:
        entry = f"<String _locID={quote}{sid}{quote}>{xml_text(value)}</String>"
        pattern = re.compile(r"<String\s+_locID\s*=\s*['\"]%d['\"][^>]*>.*?</String>" % sid, re.S)
        if pattern.search(text):
            text = pattern.sub(lambda _: entry, text, count=1)
        else:
            added.append(indent + entry)
    if added:
        at = text.rindex("</Language>")
        line_start = text.rindex("\n", 0, at) + 1
        text = text[:line_start] + nl.join(added) + nl + text[line_start:]
    return text


def language_of(text):
    """'en' or 'es': string 10670 is "Villagers gather wood faster." in English."""
    m = re.search(r"<String\s+_locID\s*=\s*['\"]10670['\"][^>]*>(.*?)</String>", text, re.S)
    return "en" if m and m.group(1).startswith("Villagers") else "es"


ATTRS = ("details", "detailstext", "loaddetails", "loaddetailstext")


def set_map_xml(text, lobby_id, loading_id):
    m = re.search(r"<mapinfo\b(.*?)(/?)>", text, re.S)
    if not m:
        raise SystemExit("no <mapinfo> tag")
    attrs = m.group(1)
    # drop every details attribute, whatever its case, with the space before it
    attrs = re.sub(r"\s*\b(\w+)\s*=\s*\"[^\"]*\"",
                   lambda a: "" if a.group(1).lower() in ATTRS else a.group(0), attrs)
    attrs = attrs.rstrip() + f'\ndetails="{lobby_id}" \nloadDetails="{loading_id}"'
    return text[:m.start(1)] + attrs + text[m.end(1):]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    wol = pathlib.Path(sys.argv[1])
    backup = wol / "map-descriptions-backup"
    if "--restore" in sys.argv:
        if not backup.exists():
            sys.exit(f"no backup in {backup}")
        for f in backup.rglob("*"):
            if f.is_file():
                shutil.copy2(f, wol / f.relative_to(backup))
                print("restored", f.relative_to(backup))
        shutil.rmtree(backup)
        return
    out = pathlib.Path(arg("--out")) if arg("--out") else None
    rows = list(csv.DictReader(open(arg("--csv", HERE / "descriptions.csv"), encoding="utf-8", newline="")))
    rm = wol / "RM4"
    for r in rows:
        if not (rm / f"{r['map']}.xml").exists():
            sys.exit(f"no {rm / (r['map'] + '.xml')}")

    def write(rel, data):
        target = (out or wol) / rel
        if not out:
            keep = backup / rel
            if not keep.exists():
                keep.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(wol / rel, keep)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        print("wrote", target)

    tables = [pathlib.Path("translations/_originals/stringtabley.xml"), pathlib.Path("translations/ES-LA/stringtabley.xml"),
              pathlib.Path("data/stringtabley.xml")]
    for rel in tables:
        if not (wol / rel).exists():
            continue
        text, kind = decode((wol / rel).read_bytes())
        lang = "en" if "_originals" in rel.parts else "es" if "ES-LA" in rel.parts else language_of(text)
        strings = []
        for r in rows:
            strings.append((int(r["lobby_id"]), r[f"lobby_{lang}"]))
            strings.append((int(r["loading_id"]), r[f"loading_{lang}"]))
        write(rel, encode(set_strings(text, strings), kind))
    for r in rows:
        rel = pathlib.Path("RM4") / f"{r['map']}.xml"
        text, kind = decode((wol / rel).read_bytes())
        write(rel, encode(set_map_xml(text, r["lobby_id"], r["loading_id"]), kind))


if __name__ == "__main__":
    main()
