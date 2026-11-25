"""Adds to Wars of Liberty's game screen the button of the DLL key `selectFattened` (WoL request #106): a square
button just above the resource panel, at its left end, that shows how many of the player's livestock have reached
their maximum food and selects them when clicked; and a hotkey for the same command (Shift+Ctrl+F).

    python apply_fix.py <WoL folder>              apply (a backup of every file it changes goes to
                                                  <WoL folder>\\select-fattened-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back and delete the files it added
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing (exit code 0 only when all is)
    (a folder under steamapps is refused unless --force is given)

What it changes (README.txt has the why):
- data\\uimainnew.xml: one gadget `uhcFattened` (hidden; the key shows it while the count is above 0) added at the end
  of the layout, outside the resource panel's block, so the oil and faith panel packs still find theirs unchanged.
  It holds the button (`<command>uhcSelectFattened</command>`) and the count `{uhcFattened}`;
- data\\DefaultKeyMapY.xml: the entry "Select Fattened Livestock" (shift-control-f, context game) in the group
  "Find Unit Hotkeys", after "Find Idle Military";
- the string tables (data, translations\\_originals in English, translations\\ES-LA in Spanish): the tooltip 690911
  and the hotkey's name 690912;
- art\\ui\\ingame\\uhc_select_fattened.ddt (new): the button's picture;
- Startup\\wol.cfg: the line `selectFattened` (when the file has no such line).
"""
import json
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
FILES = HERE / "files"
BACKUP = "select-fattened-backup"

ICON = "art/ui/ingame/uhc_select_fattened.ddt"
LAYOUT = "data/uimainnew.xml"
KEYMAP = "data/DefaultKeyMapY.xml"
TABLES = ["data/stringtabley.xml", "translations/_originals/stringtabley.xml", "translations/ES-LA/stringtabley.xml"]
CFG = "Startup/wol.cfg"
CHANGED = [LAYOUT, KEYMAP, CFG] + TABLES

TOOLTIP, HOTKEY_NAME = 690911, 690912
STRINGS = {
    "en": {TOOLTIP: "Fattened livestock: {uhcFattened}. Click to select them (Shift+Ctrl+F).",
           HOTKEY_NAME: "Select Fattened Livestock"},
    "es": {TOOLTIP: "Ganado engordado: {uhcFattened}. Haz clic para seleccionarlo (Mayús+Ctrl+F).",
           HOTKEY_NAME: "Seleccionar ganado engordado"},
}
HOTKEY = "shift-control-f"

# 40 x 40 pixels at 1920 x 1080 (size1024 scales x by width / 1024 and y by height / 768), its left edge on the
# resource panel's (x 221), its bottom on the top of the panel's art (y 625 in the tallest variants).
GADGET = (
    '\t<gadget name="uhcFattened" type="gadget" size1024="221 594 242 623" transparent="" z="12" hidden="">\r\n'
    '\t\t<gadget name="uhcFattened-button" type="button" z="13" size1024="221 594 242 623" '
    'background="ui\\ingame\\uhc_select_fattened" foreground="" donthighlight="" activateondown="" '
    f'mouseovertext="$${TOOLTIP}$$Fattened livestock: {{uhcFattened}}" anchortooltiptopright="">\r\n'
    '\t\t\t<command>uhcSelectFattened</command>\r\n'
    '\t\t</gadget>\r\n'
    '\t\t<gadget name="uhcFattened-count" type="formatText" size1024="228 609 241 623" datarefreshrate=".5" '
    'textcolor="255 255 255" textfont="NumbersFont" textfontsize="12" textcentervert="" donthighlight="" '
    'transparent="" z="14" background="">{uhcFattened}</gadget>\r\n'
    '\t</gadget>\r\n'
)
KEY_ENTRY = (
    "        <keymapdata>\n"
    "            <name>Select Fattened Livestock</name>\n"
    f"            <displayname>$${HOTKEY_NAME}$$Select Fattened Livestock</displayname>\n"
    f"            <event>{HOTKEY}</event>\n"
    "            <context>game</context>\n"
    "            <command>uhcSelectFattened</command>\n"
    "        </keymapdata>\n"
)
KEY_AFTER = re.compile(r"<name>Find Idle Military</name>.*?</keymapdata>\r?\n", re.S)


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


def language(rel, text):
    if "_originals" in rel:
        return "en"
    if "ES-LA" in rel:
        return "es"
    m = re.search(r"<String\s+_locID\s*=\s*['\"]10670['\"][^>]*>(.*?)</String>", text, re.S)
    return "en" if m and m.group(1).startswith("Villagers") else "es"


def set_string(text, sid, value):
    nl = "\r\n" if "\r\n" in text else "\n"
    quote = '"' if re.search(r'<String _locID="', text) else "'"
    entry = f"<String _locID={quote}{sid}{quote}>{value}</String>"
    pat = re.compile(r"<String\s+_locID\s*=\s*['\"]%d['\"][^>]*>(.*?)</String>" % sid, re.S)
    if pat.search(text):
        return pat.sub(lambda _: entry, text, count=1)
    m = re.search(r"\n([ \t]*)<String ", text)
    at = text.rindex("</Language>")
    line_start = text.rindex("\n", 0, at) + 1
    return text[:line_start] + (m.group(1) if m else "\t\t") + entry + nl + text[line_start:]


def new_layout(text):
    if 'name="uhcFattened"' in text:
        return text
    at = text.rindex("</layout>")
    return text[:at] + GADGET + "\r\n" + text[at:]


def new_keymap(text):
    if "<command>uhcSelectFattened</command>" in text:
        return text
    if re.search(r"<event>\s*%s\s*</event>" % re.escape(HOTKEY), text, re.I):
        sys.exit(f"apply_fix: {KEYMAP} already binds {HOTKEY}; nothing changed")
    m = KEY_AFTER.search(text)
    if m is None:
        sys.exit(f"apply_fix: {KEYMAP} has no entry 'Find Idle Military'; nothing changed")
    entry = KEY_ENTRY.replace("\n", "\r\n") if "\r\n" in text else KEY_ENTRY
    return text[:m.end()] + entry + text[m.end():]


def new_cfg(text):
    if re.search(r"(?im)^\s*selectFattened\b", text):
        return text
    nl = "\r\n" if "\r\n" in text else "\n"
    return text.rstrip("\r\n") + nl + "selectFattened" + nl


def edited(root):
    """{relative path: new bytes} for every file this pack changes that exists in the folder."""
    out = {}
    for rel, change in ((LAYOUT, new_layout), (KEYMAP, new_keymap), (CFG, new_cfg)):
        path = root / rel
        if path.exists():
            text, kind = decode(path.read_bytes())
            out[rel] = encode(change(text), kind)
    for rel in TABLES:
        path = root / rel
        if not path.exists():
            continue
        text, kind = decode(path.read_bytes())
        for sid, value in STRINGS[language(rel, text)].items():
            text = set_string(text, sid, value)
        out[rel] = encode(text, kind)
    return out


def apply(root):
    backup = root / BACKUP
    if backup.exists():
        sys.exit(f"apply_fix: {backup} exists: applied already (run --restore first)")
    for rel in (LAYOUT, KEYMAP):
        if not (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} is missing: is this a Wars of Liberty folder?")
    if not (FILES / ICON).exists():
        sys.exit(f"apply_fix: the pack has no {ICON}")
    changes = edited(root)  # made and checked before anything is written
    backup.mkdir()
    manifest = {"changed": [], "added": []}
    for rel in CHANGED:
        if (root / rel).exists():
            (backup / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, backup / rel)
            manifest["changed"].append(rel)
    if (root / ICON).exists():
        sys.exit(f"apply_fix: {root / ICON} exists already")
    (root / ICON).parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(FILES / ICON, root / ICON)
    manifest["added"].append(ICON)
    for rel, data in changes.items():
        (root / rel).write_bytes(data)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(f"applied; backup in {backup}")


def restore(root):
    backup = root / BACKUP
    manifest_path = backup / "manifest.json"
    if not manifest_path.exists():
        sys.exit(f"apply_fix: no backup at {backup}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for rel in manifest["added"]:
        (root / rel).unlink(missing_ok=True)
    for rel in manifest["changed"]:
        shutil.copy2(backup / rel, root / rel)
    shutil.rmtree(backup)
    print("restored")


def check(root):
    ok = True
    for rel, data in edited(root).items():
        same = (root / rel).read_bytes() == data
        ok &= same
        print(f"{rel}: {'applied' if same else 'not applied'}")
    present = (root / ICON).exists() and (FILES / ICON).exists() and \
        (root / ICON).read_bytes() == (FILES / ICON).read_bytes()
    ok &= present
    print(f"{ICON}: {'present' if present else 'missing or different'}")
    return 0 if ok else 1


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root = pathlib.Path(sys.argv[1])
    if "steamapps" in str(root).lower() and "--force" not in sys.argv:
        sys.exit("apply_fix: this is a Steam folder; work on a copy, or add --force to change it anyway")
    if "--restore" in sys.argv:
        restore(root)
    elif "--check" in sys.argv:
        sys.exit(check(root))
    else:
        apply(root)


if __name__ == "__main__":
    main()
