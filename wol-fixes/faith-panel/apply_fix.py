"""OPTIONAL pack. Puts the faith row into Wars of Liberty's resource panel (request #101, layout A: faith under oil),
in all 12 variants of the panel (default / advanced, European / Asian / Native, big / minimized UI). It changes
nothing until it is applied, and goes with the faith pack (wol-fixes\\faith) and the DLL key faithResource.

    python apply_fix.py <WoL folder>              apply (each file it changes is copied first to
                                                  <WoL folder>\\faith-panel-backup\\)
    python apply_fix.py <WoL folder> --no-faith   apply only the panel fixes that do not need faith (Asian minimized
                                                  oil amount, Native minimized icons, oil gadgets renamed, numbers
                                                  centred in their rows) on WoL's own rows: data\\uimainnew.xml only
    python apply_fix.py <WoL folder> --check      say, file by file, whether it is WoL's original, this pack's
                                                  version or something else; change nothing (with --no-faith: that
                                                  mode's file)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back, byte for byte, and remove the backup
    (--force: apply over files that are neither WoL 1.0.15c's nor this pack's; a folder under steamapps is refused
    unless --force is given. To switch between the two modes, --restore first.)

What it changes:
- art\\ui\\ingame\\eur_max_ui.ddt, ASI_UI_MAX.ddt, nat_ui_max.ddt, ingame_ui_small_01_asian.ddt,
  ingame_ui_small_01_ypack.ddt: the panel backgrounds with the faith row painted in (files\\ in this folder;
  only the panel's part of each texture differs from WoL's);
- data\\uimainnew.xml: the SettlerCountDialog block (12 variants) is replaced by layout\\settlercount.xml; the rest
  of the file stays byte for byte;
- the string tables get string 1010101, the faith row's tooltip:
  translations\\_originals\\stringtabley.xml (English), translations\\ES-LA\\stringtabley.xml (Spanish) and
  data\\stringtabley.xml (in the language it holds: the launcher copies a translation over it).
The faith value is resource 4 (SkillPoints): the faith pack (wol-fixes\\faith, the DLL key faithResource) makes it
faith. Without that key the row shows the home city's unspent skill points.
"""
import hashlib
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
BACKUP = "faith-panel-backup"
TEXTURES = ["eur_max_ui", "ASI_UI_MAX", "nat_ui_max", "ingame_ui_small_01_asian", "ingame_ui_small_01_ypack"]
# WoL 1.0.15c's files (SHA-256)
ORIGINAL = {
    "art/ui/ingame/eur_max_ui.ddt": "4eddb3c932ab383aa303073fbce22cc55056f259a6e8c1969b0ac15682447c4b",
    "art/ui/ingame/ASI_UI_MAX.ddt": "9ecc3eaa7e1e1ce8e06fae50dafc9ea49afd7f5e605c4aa212d30e8838a1bc5b",
    "art/ui/ingame/nat_ui_max.ddt": "090078090f51e4a523ed638ad0992db86cc4eb3eb8f7258f01145748248e5d85",
    "art/ui/ingame/ingame_ui_small_01_asian.ddt": "13b09de4bf0236c9ba4ff7e4d2738e699f00046d222c559ea211a24860b6248c",
    "art/ui/ingame/ingame_ui_small_01_ypack.ddt": "a955d0b1319ec0e1594ac4f7ad0909722869b404fa5d225eee4ea4fa248f11fe",
}
LAYOUT = "data/uimainnew.xml"
BLOCK_SHA = "30e05cdc914ad626cc9dfa6610d355a53d7d35090a7fb199e9fc57f05d8c52d8"   # WoL 1.0.15c's panel block
STRING_ID = 1010101
STRINGS = {"en": "Faith Gatherers: {numGatherers(skillpoints)}",
           "es": "Recolectores de fe: {numGatherers(skillpoints)}"}
TABLES = ["translations/_originals/stringtabley.xml", "translations/ES-LA/stringtabley.xml", "data/stringtabley.xml"]


def sha(b):
    return hashlib.sha256(b).hexdigest()


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


def panel_block(text):
    """(start, end) of the SettlerCountDialog block: from its first gadget to the last </gadget> before timeDisplay."""
    start = text.index('<gadget name="SettlerCountDialog" ')
    end = text.rindex("</gadget>", start, text.index('<gadget name="timeDisplay"')) + len("</gadget>")
    return start, end


def language_of(text):
    """'en' or 'es': string 10670 is "Villagers gather wood faster." in English."""
    m = re.search(r"<String\s+_locID\s*=\s*['\"]10670['\"][^>]*>(.*?)</String>", text, re.S)
    return "en" if m and m.group(1).startswith("Villagers") else "es"


def string_re():
    return re.compile(r"<String\s+_locID\s*=\s*['\"]%d['\"][^>]*>(.*?)</String>" % STRING_ID, re.S)


def set_string(text, value):
    nl = "\r\n" if "\r\n" in text else "\n"
    quote = '"' if re.search(r'<String _locID="', text) else "'"
    m = re.search(r"\n([ \t]*)<String ", text)
    indent = m.group(1) if m else "\t\t"
    entry = f"<String _locID={quote}{STRING_ID}{quote}>{value}</String>"
    if string_re().search(text):
        return string_re().sub(lambda _: entry, text, count=1)
    at = text.rindex("</Language>")
    line_start = text.rindex("\n", 0, at) + 1
    return text[:line_start] + indent + entry + nl + text[line_start:]


def new_files(wol, no_faith=False):
    """{relative path: (new bytes, state of the current file)}. no_faith: only data\\uimainnew.xml, with the layout
    of WoL's own rows (layout\\settlercount-nofaith.xml); the backgrounds and string tables are left alone."""
    out = {}
    for rel in ([] if no_faith else ORIGINAL):
        cur = (wol / rel).read_bytes()
        new = (HERE / "files" / rel).read_bytes()
        state = "applied" if cur == new else "original" if sha(cur) == ORIGINAL[rel] else "other"
        out[rel] = (new, state)
    raw = (wol / LAYOUT).read_bytes()
    text = raw.decode("utf-8")
    a, b = panel_block(text)
    mine, theirs = ("settlercount-nofaith.xml", "settlercount.xml") if no_faith else ("settlercount.xml", "settlercount-nofaith.xml")
    block = (HERE / "layout" / mine).read_bytes().decode("utf-8")
    cur = text[a:b]
    if cur == (HERE / "layout" / theirs).read_bytes().decode("utf-8"):
        sys.exit("this pack is applied in the other mode: run --restore first")
    state = "applied" if cur == block else "original" if sha(cur.encode("utf-8")) == BLOCK_SHA else "other"
    out[LAYOUT] = ((text[:a] + block + text[b:]).encode("utf-8"), state)
    if no_faith:
        return out
    for rel in TABLES:
        p = wol / rel
        if not p.exists():
            continue
        text, kind = decode(p.read_bytes())
        lang = "en" if "_originals" in rel else "es" if "ES-LA" in rel else language_of(text)
        m = string_re().search(text)
        state = "applied" if m and m.group(1) == STRINGS[lang] else "other" if m else "original"
        out[rel] = (encode(set_string(text, STRINGS[lang]), kind), state)
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    wol = pathlib.Path(sys.argv[1])
    force = "--force" in sys.argv
    if "steamapps" in str(wol).lower() and not force:
        sys.exit("refused: that is the Steam install (copy it, or pass --force)")
    backup = wol / BACKUP
    if "--restore" in sys.argv:
        if not backup.exists():
            sys.exit(f"no backup in {backup}")
        for f in sorted(backup.rglob("*")):
            if f.is_file():
                shutil.copy2(f, wol / f.relative_to(backup))
                print("restored", f.relative_to(backup).as_posix())
        shutil.rmtree(backup)
        return
    files = new_files(wol, "--no-faith" in sys.argv)
    if "--check" in sys.argv:
        for rel, (_, state) in files.items():
            print(f"{state:9} {rel}")
        bad = [r for r, (_, s) in files.items() if s != "applied"]
        sys.exit(1 if bad else 0)
    other = [r for r, (_, s) in files.items() if s == "other" and not r.endswith("stringtabley.xml")]
    if other and not force:
        sys.exit("neither WoL 1.0.15c's nor this pack's (use --force to apply anyway):\n  " + "\n  ".join(other))
    for rel, (data, state) in files.items():
        if state == "applied":
            print("already  ", rel)
            continue
        keep = backup / rel
        if not keep.exists():
            keep.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(wol / rel, keep)
        (wol / rel).write_bytes(data)
        print("wrote    ", rel)


if __name__ == "__main__":
    main()
