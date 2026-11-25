"""Adds a "Show Range Rings" check box to Wars of Liberty's options menu (Options -> UI Options -> Game UI Options), for
the DLL key `displayedRange` through `menuOptions`: the player turns the range rings on or off, and the change shows at
once, also during a match.

    python apply_fix.py <WoL folder>              apply (a backup of every file it changes goes to
                                                  <WoL folder>\\options-menu-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

What it changes (README.txt has the why):
- data\\options.xml: a CheckBox field OptionDisplayedRange, right after "(Alt) Shows hitpoint bars"
  (OptionShowHPOnAlt), or at the end of the first section of the first group when the mod has no such field;
- Startup\\wol.cfg (and engine-ext\\engine-ext.cfg when the folder has one): a line `menuOptions displayedRange`
  when no menuOptions line names it yet, and a line `displayedRange` when the file has none, so the rings start on
  for a player who never chose. A `displayedRange` line already there, with its arguments, is left as it is.
The file keeps its encoding and its line ends (WoL's options.xml has Windows line ends; a field written with Unix line
ends in it is left off the screen with no error).
"""
import json
import pathlib
import re
import shutil
import sys
from xml.etree import ElementTree

BACKUP = "options-menu-backup"
FIELD_NAME = "OptionDisplayedRange"
AFTER = "OptionShowHPOnAlt"
LABEL = "Show Range Rings"
TOOLTIP = ("Shows how far the selected units and buildings shoot, as rings on the ground, and the range of a building "
           "while you place it. Takes effect at once.")
CFGS = ["Startup/wol.cfg", "engine-ext/engine-ext.cfg"]


def read_text(path):
    raw = path.read_bytes()
    if raw[:2] == b"\xff\xfe":
        return raw[2:].decode("utf-16-le"), "utf-16"
    if raw[:3] == b"\xef\xbb\xbf":
        return raw[3:].decode("utf-8"), "utf-8-sig"
    return raw.decode("utf-8"), "utf-8"


def write_text(path, text, encoding):
    if encoding == "utf-16":
        path.write_bytes(b"\xff\xfe" + text.encode("utf-16-le"))
    elif encoding == "utf-8-sig":
        path.write_bytes(b"\xef\xbb\xbf" + text.encode("utf-8"))
    else:
        path.write_bytes(text.encode("utf-8"))


def field(indent, newline):
    """The field, in the file's own indentation (that of the <field> lines) and line ends."""
    inner = indent + ("\t" if "\t" in indent or not indent else "    ")
    lines = [f"{indent}<field>",
             f"{inner}CheckBox",
             f"{inner}<name>{FIELD_NAME}</name>",
             f"{inner}<label>{LABEL}</label>",
             f"{inner}<tooltip>{TOOLTIP}</tooltip>",
             f"{indent}</field>"]
    return newline.join(lines) + newline


def insert_field(text):
    """options.xml with the field: after the OptionShowHPOnAlt field, else before the end of the first section."""
    newline = "\r\n" if "\r\n" in text else "\n"
    m = re.search(r"<name>\s*%s\s*</name>" % AFTER, text, re.I)
    if m is not None:
        end = text.index("</field>", m.end()) + len("</field>")
        start = text.rfind("\n", 0, text.rfind("<field>", 0, m.start())) + 1
        indent = re.match(r"[ \t]*", text[start:]).group(0)
        eol = text.index("\n", end) + 1
        where = f"after the {AFTER} field"
    else:
        section = text.find("</section>")
        if section < 0:
            sys.exit("apply_fix: options.xml has no <section>; nothing changed")
        eol = text.rfind("\n", 0, section) + 1
        first = text.rfind("<field>", 0, section)
        line = text.rfind("\n", 0, first) + 1
        indent = re.match(r"[ \t]*", text[line:]).group(0) if first >= 0 else "\t\t\t"
        where = "at the end of the first section"
    out = text[:eol] + field(indent, newline) + text[eol:]
    try:
        root = ElementTree.fromstring(out.encode("utf-8"))
    except ElementTree.ParseError as error:
        sys.exit(f"apply_fix: options.xml would not be valid XML ({error}); nothing changed")
    names = [(n.text or "").strip() for n in root.iter("name")]
    if names.count(FIELD_NAME) != 1:
        sys.exit(f"apply_fix: unexpected result: {names.count(FIELD_NAME)} {FIELD_NAME} fields; nothing changed")
    return out, where


def has_field(text):
    return re.search(r"<name>\s*%s\s*</name>" % FIELD_NAME, text, re.I) is not None


def names_key(text):
    return re.search(r"(?im)^[ \t]*menuOptions\b[^\r\n#]*\bdisplayedRange\b", text) is not None


def has_key(text):
    return re.search(r"(?im)^[ \t]*displayedRange\b", text) is not None


def apply(root):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        sys.exit(f"apply_fix: already applied ({backup} exists); run --restore first")
    options = root / "data/options.xml"
    if not options.exists():
        sys.exit(f"apply_fix: {options} is missing: is this a Wars of Liberty folder?")
    text, enc = read_text(options)
    if has_field(text):
        sys.exit(f"apply_fix: options.xml has a {FIELD_NAME} field already; nothing changed")
    out, where = insert_field(text)  # made and checked before anything is written

    backup.mkdir()
    manifest = {"changed": []}
    for rel in ["data/options.xml"] + CFGS:
        if (root / rel).exists():
            (backup / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, backup / rel)
            manifest["changed"].append(rel)

    write_text(options, out, enc)
    print(f"data\\options.xml: the {LABEL!r} check box, {where}")

    for rel in CFGS:
        path = root / rel
        if not path.exists():
            continue
        cfg, cfg_enc = read_text(path)
        newline = "\r\n" if "\r\n" in cfg or not cfg else "\n"
        added = []
        if not names_key(cfg):
            added.append("menuOptions displayedRange")
        if not has_key(cfg):
            added.append("displayedRange")  # the rings start on until the player chooses
        if not added:
            print(f"{rel}: has both lines already")
            continue
        cfg = cfg.rstrip("\r\n") + newline + newline.join(added) + newline
        write_text(path, cfg, cfg_enc)
        print(f"{rel}: added " + ", ".join(f"`{line}`" for line in added))

    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(f"applied; backup in {backup}")


def restore(root):
    backup = root / BACKUP
    manifest_path = backup / "manifest.json"
    if not manifest_path.exists():
        sys.exit(f"apply_fix: no backup at {backup}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for rel in manifest["changed"]:
        shutil.copy2(backup / rel, root / rel)
    shutil.rmtree(backup)
    print("restored")


def check(root):
    text, _ = read_text(root / "data/options.xml")
    print(f"data\\options.xml: {FIELD_NAME} {'present' if has_field(text) else 'missing'}")
    for rel in CFGS:
        path = root / rel
        if path.exists():
            cfg, _ = read_text(path)
            print(f"{rel}: menuOptions {'names' if names_key(cfg) else 'does not name'} displayedRange; "
                  f"{'a' if has_key(cfg) else 'no'} displayedRange line")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root = pathlib.Path(sys.argv[1])
    if "steamapps" in str(root).lower() and "--force" not in sys.argv:
        sys.exit("apply_fix: this is a Steam folder; work on a copy, or add --force to change it anyway")
    if "--restore" in sys.argv:
        restore(root)
    elif "--check" in sys.argv:
        check(root)
    else:
        apply(root)


if __name__ == "__main__":
    main()
