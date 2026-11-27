"""Lets Wars of Liberty's Mapuche council research while it walks, fights or does anything else, with the DLL key
`researchOnTheMove`: it gives the six council units the abstract type ResearchOnTheMove.

    python apply_fix.py <WoL folder>                    apply (a backup of every file it changes goes to
                                                        <WoL folder>\\research-on-the-move-backup\\ first)
    python apply_fix.py <WoL folder> --units A,B,C      the same for the units named instead of the council
    python apply_fix.py <WoL folder> --restore          put the backed-up files back
    python apply_fix.py <WoL folder> --check            say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

What it changes (README.txt has the why):
- data\\protoy.xml: <UnitType>ResearchOnTheMove</UnitType> after the last <UnitType> of each unit;
- Startup\\wol.cfg, or engine-ext\\engine-ext.cfg when the folder has our dinput8.dll beside WoL's own DLL: the line
  `researchOnTheMove`, when the file has none.
A data\\protoy.xml.XMB next to the XML would be loaded instead of the XML when it is newer: the script stops if one
exists, since WoL ships none.
"""
import json
import pathlib
import re
import shutil
import sys

BACKUP = "research-on-the-move-backup"
TYPE = "ResearchOnTheMove"
KEY = "researchOnTheMove"
COUNCIL = ["MapucheWarchief", "MapucheWiseWoman", "MapucheShaman", "MapucheWarrior", "MapucheMessenger", "MapucheToki"]


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


def unit_block(text, name):
    """(start, end) of <Unit ... name="name"> ... </Unit> in protoy.xml."""
    m = re.search(r"""<Unit\b[^>]*\bname\s*=\s*["']%s["'][^>]*>""" % re.escape(name), text)
    if m is None:
        sys.exit(f"apply_fix: protoy.xml has no unit {name}")
    return m.start(), text.index("</Unit>", m.end())


def has_type(block):
    return re.search(r"<UnitType>\s*%s\s*</UnitType>" % TYPE, block) is not None


def add_type(text, name):
    start, end = unit_block(text, name)
    block = text[start:end]
    if has_type(block):
        return text, False
    last = None
    for last in re.finditer(r"([ \t]*)<UnitType>[^<]*</UnitType>(\r?\n)", block):
        pass
    if last is None:
        sys.exit(f"apply_fix: unit {name} has no <UnitType>")
    line = f"{last.group(1)}<UnitType>{TYPE}</UnitType>{last.group(2)}"
    block = block[:last.end()] + line + block[last.end():]
    return text[:start] + block + text[end:], True


def cfg_path(root):
    if (root / "engine-ext").is_dir():
        return root / "engine-ext" / "engine-ext.cfg"
    return root / "Startup" / "wol.cfg"


def apply(root, units):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        sys.exit(f"apply_fix: already applied ({backup} exists); run --restore first")
    protoy = root / "data" / "protoy.xml"
    if not protoy.exists():
        sys.exit(f"apply_fix: {protoy} is missing: is this a Wars of Liberty folder?")
    if (root / "data" / "protoy.xml.XMB").exists():
        sys.exit("apply_fix: data\\protoy.xml.XMB exists; compile it from the edited XML yourself, or remove it")
    cfg = cfg_path(root)
    backup.mkdir()
    manifest = {"changed": []}
    for path in (protoy, cfg):
        if path.exists():
            rel = path.relative_to(root)
            (backup / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, backup / rel)
            manifest["changed"].append(str(rel))

    text, enc = read_text(protoy)
    for name in units:
        text, added = add_type(text, name)
        print(f"{name}: {'type added' if added else 'had the type already'}")
    write_text(protoy, text, enc)

    if cfg.exists():
        text, enc = read_text(cfg)
    else:
        cfg.parent.mkdir(parents=True, exist_ok=True)
        text, enc = "", "utf-8"
    if not re.search(r"(?im)^\s*%s\b" % KEY, text):
        text = (text.rstrip("\r\n") + "\r\n" if text else "") + KEY + "\r\n"
        write_text(cfg, text, enc)
        print(f"{cfg}: {KEY} added")

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


def check(root, units):
    text, _ = read_text(root / "data" / "protoy.xml")
    for name in units:
        start, end = unit_block(text, name)
        print(f"{name}: {'applied' if has_type(text[start:end]) else 'not applied'}")
    cfg = cfg_path(root)
    on = cfg.exists() and re.search(r"(?im)^\s*%s\b" % KEY, read_text(cfg)[0]) is not None
    print(f"{cfg}: {KEY} {'on' if on else 'missing'}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit(__doc__)
    root = pathlib.Path(args[0])
    units = COUNCIL
    if "--units" in sys.argv:
        i = sys.argv.index("--units")
        if i + 1 >= len(sys.argv):
            sys.exit("apply_fix: --units needs a comma-separated list")
        units = [u for u in sys.argv[i + 1].split(",") if u]
    if "steamapps" in str(root).lower() and "--force" not in sys.argv:
        sys.exit("apply_fix: this is a Steam folder; work on a copy, or add --force to change it anyway")
    if "--restore" in sys.argv:
        restore(root)
    elif "--check" in sys.argv:
        check(root, units)
    else:
        apply(root, units)


if __name__ == "__main__":
    main()
