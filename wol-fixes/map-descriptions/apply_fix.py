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
   so every language shows the string table's text;
3. FONTS\\fonts3.xml gets the two font entries the texts use (FONT_ENTRIES), added before </Fonts>
   only when the file has no entry of that name: other entries are never changed, and running it
   again adds nothing;
4. data\\uirmsetup.xml (the loading screen's layout, a loose copy of WoL's DataP.bar version) with a
   taller description box: the map's text gets 326 of the box's 542 rows (was 216) and the player
   list moves down (it keeps its 208).

A text holds "\\n" (backslash, n) where a line break goes, as the game's own strings do.
Before the first change each file is copied to <WoL folder>\\map-descriptions-backup\\ (a file that
did not exist is listed in new-files.txt there); --restore puts those copies back, deletes the new
files and the backup folder.
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
    nl = "\r\n" if "\r\n" in text else "\n"
    attrs = attrs.rstrip() + f'{nl}details="{lobby_id}"{nl}loadDetails="{loading_id}"'
    return text[:m.start(1)] + attrs + text[m.end(1):]


# The font entries the texts use (tested in game, README.txt "Format v2"). The TypeFace of each is
# read from the entry it copies (FONT_SOURCES), so the result is the same whether the fonts pack
# (wol-fixes/fonts, which renames the families) ran before or after this one; the face given here
# is only the fallback when that entry is missing.
FONT_ENTRIES = {
    # Tooltips_UI (the lobby rollover's font) with Bold="true": the keys in the lobby
    "MapDescTipKey": ("Franklin Gothic Medium", 11, True, {640: 11, 800: 13, 1280: 17, 1600: 21}),
    # a 4-pixel font: an underline over no-break spaces in it is a thin line that costs a third of a row
    "MapDescRule 4": ("Formal436 BT", 4, False, {640: 3, 800: 4, 1280: 6, 1600: 8}),
}
FONT_SOURCES = {"MapDescTipKey": "Tooltips_UI", "MapDescRule 4": "SPLoadingScreenText 14"}


def source_face(text, name, fallback):
    """The TypeFace of the entry named `name` in fonts3.xml, or `fallback` when there is none."""
    m = re.search(r'<Font\s+Name\s*=\s*"%s"\s*>.*?<param\s+TypeFace\s*=\s*"([^"]*)"' % re.escape(name),
                  text, re.S)
    return m.group(1) if m else fallback


def font_entry(name, face, height, bold, overrides, nl):
    lines = [f'\t<Font Name="{name}">', f'\t\t<param TypeFace="{face}"/>', f'\t\t<param AscentHeight="{height}"/>',
             '\t\t<param Antialiased="true"/>', f'\t\t<param Bold="{"true" if bold else "false"}"/>',
             '\t\t<param Italic="false"/>', '\t\t<param BackgroundOutline="false"/>',
             '\t\t<param BackgroundShadow="false"/>', '\t\t<param BackgroundOffset="2"/>',
             '\t\t<param BackgroundAlpha="1"/>']
    for res, h in sorted(overrides.items()):
        lines += [f'\t\t<ResolutionOverride ResX="{res}">', f'\t\t\t<param AscentHeight="{h}"/>',
                  '\t\t</ResolutionOverride>']
    lines.append("\t</Font>")
    return nl.join(lines)


def add_fonts(text):
    """Adds each FONT_ENTRIES entry the file does not have yet, before </Fonts>; nothing else changes."""
    nl = "\r\n" if "\r\n" in text else "\n"
    for name, (face, *rest) in FONT_ENTRIES.items():
        if re.search(r'<Font\s+Name\s*=\s*"%s"' % re.escape(name), text):
            continue
        face = source_face(text, FONT_SOURCES[name], face)
        at = text.rindex("</Fonts>")
        text = text[:at] + font_entry(name, face, *rest, nl) + nl + text[at:]
    return text


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    wol = pathlib.Path(sys.argv[1])
    backup = wol / "map-descriptions-backup"
    if "--restore" in sys.argv:
        if not backup.exists():
            sys.exit(f"no backup in {backup}")
        new = backup / "new-files.txt"
        for f in backup.rglob("*"):
            if f.is_file() and f != new:
                shutil.copy2(f, wol / f.relative_to(backup))
                print("restored", f.relative_to(backup))
        if new.exists():
            for rel in new.read_text(encoding="utf-8").splitlines():
                if rel and (wol / rel).exists():
                    (wol / rel).unlink()
                    print("removed", rel)
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
            new = backup / "new-files.txt"
            listed = new.read_text(encoding="utf-8").splitlines() if new.exists() else []
            if not (wol / rel).exists():
                if str(rel) not in listed:
                    new.parent.mkdir(parents=True, exist_ok=True)
                    new.write_text("\n".join(listed + [str(rel)]) + "\n", encoding="utf-8")
            elif not keep.exists() and str(rel) not in listed:
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
    rel = pathlib.Path("FONTS/fonts3.xml")
    text, kind = decode((wol / rel).read_bytes())
    fonts = add_fonts(text)
    if fonts != text:
        write(rel, encode(fonts, kind))
    else:
        print("FONTS\\fonts3.xml already has the entries")
    write(pathlib.Path("data/uirmsetup.xml"), (HERE / "uirmsetup.xml").read_bytes())


if __name__ == "__main__":
    main()
