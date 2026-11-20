"""Wars of Liberty's Mapuche (request #72): a per-game limit on the council's shipment techs, and one council tech
swapped for the home city card it duplicates.

    python apply_fix.py <WoL folder> [--limit N]   apply (a backup of every file it changes goes to
                                                  <WoL folder>\\mapuche-backup\\ first); N defaults to 10
    python apply_fix.py <WoL folder> --restore     put the backed-up files back
    python apply_fix.py <WoL folder> --check       say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

What it changes (README.txt has the why):
- data\\civs.xml: <ShipTechLimit>N</ShipTechLimit> in the WallMapu civ (DLL key shipTechLimit);
- data\\protoy.xml: MapucheWiseWoman researches HCNativeLore where it had MapucheNativeLore (DLL key
  homeCityTechsInUnits);
- data\\techtreey.xml: Age0Mapuche makes HCNativeLore obtainable instead of MapucheNativeLore (a card that is not in
  the deck is unobtainable, so the council button would never show);
- Startup\\wol.cfg (or engine-ext\\engine-ext.cfg when that folder exists): the lines `shipTechLimit` and
  `homeCityTechsInUnits`, when the file has none.
MapucheNativeLore itself stays in the techtree, unused, so nothing else that names it breaks.
"""
import pathlib
import re
import shutil
import sys

BACKUP = "mapuche-backup"
CIV = "WallMapu"
OLD_TECH, NEW_TECH = "MapucheNativeLore", "HCNativeLore"
COUNCIL = "MapucheWiseWoman"
AGE0 = "Age0Mapuche"
KEYS = ["shipTechLimit", "homeCityTechsInUnits"]


def read(path):
    raw = path.read_bytes()
    bom = raw.startswith(b"\xef\xbb\xbf")
    return raw.decode("utf-8-sig"), bom


def write(path, text, bom):
    path.write_bytes((b"\xef\xbb\xbf" if bom else b"") + text.encode("utf-8"))


def cfg_path(root):
    ext = root / "engine-ext"
    return ext / "engine-ext.cfg" if ext.is_dir() else root / "Startup" / "wol.cfg"


def changed_files(root):
    return [root / "data" / "civs.xml", root / "data" / "protoy.xml", root / "data" / "techtreey.xml", cfg_path(root)]


# --- the edits -------------------------------------------------------------------------------------------------

def civ_block(text):
    m = re.search(r"<civ>\s*<name>" + CIV + r"</name>.*?</civ>", text, re.S)
    if not m:
        sys.exit(f"apply_fix: no civ {CIV} in civs.xml")
    return m


def set_limit(text, limit):
    m = civ_block(text)
    block = m.group(0)
    nl = "\r\n" if "\r\n" in block else "\n"
    if re.search(r"<ShipTechLimit>", block):
        block = re.sub(r"<ShipTechLimit>[^<]*</ShipTechLimit>", f"<ShipTechLimit>{limit}</ShipTechLimit>", block)
    else:
        block = block.replace(f"<name>{CIV}</name>",
                              f"<name>{CIV}</name>{nl}\t\t<ShipTechLimit>{limit}</ShipTechLimit>", 1)
    return text[:m.start()] + block + text[m.end():]


def proto_block(text, name):
    m = re.search(r'<Unit id="\d+" name="' + name + r'">.*?</Unit>', text, re.S)
    if not m:
        sys.exit(f"apply_fix: no proto {name} in protoy.xml")
    return m


def swap_council(text):
    m = proto_block(text, COUNCIL)
    block = re.sub(r"(<Tech [^>]*>)" + OLD_TECH + "(</Tech>)", r"\g<1>" + NEW_TECH + r"\2", m.group(0))
    return text[:m.start()] + block + text[m.end():]


def tech_block(text, name):
    m = re.search(r"<Tech name\s*=\s*'" + name + r"'.*?</Tech>", text, re.S)
    if not m:
        sys.exit(f"apply_fix: no tech {name} in techtreey.xml")
    return m


def swap_age0(text):
    m = tech_block(text, AGE0)
    block = m.group(0).replace(f"status ='obtainable'>{OLD_TECH}</Effect>", f"status ='obtainable'>{NEW_TECH}</Effect>")
    return text[:m.start()] + block + text[m.end():]


def add_keys(text):
    nl = "\r\n" if "\r\n" in text else "\n"
    present = {line.split()[0].lower() for line in text.splitlines() if line.split()}
    for key in KEYS:
        if key.lower() not in present:
            text = text.rstrip("\r\n") + nl + key + nl
    return text


# --- check / apply / restore -----------------------------------------------------------------------------------

def status(root):
    civs, _ = read(root / "data" / "civs.xml")
    m = re.search(r"<ShipTechLimit>([^<]*)</ShipTechLimit>", civ_block(civs).group(0))
    proto, _ = read(root / "data" / "protoy.xml")
    council = proto_block(proto, COUNCIL).group(0)
    tree, _ = read(root / "data" / "techtreey.xml")
    age0 = tech_block(tree, AGE0).group(0)
    cfg = cfg_path(root)
    keys = {line.split()[0].lower() for line in read(cfg)[0].splitlines() if line.split()} if cfg.exists() else set()
    return {
        "limit": m.group(1) if m else None,
        "council": f">{NEW_TECH}<" in council,
        "age0": f">{NEW_TECH}</Effect>" in age0,
        "keys": [k for k in KEYS if k.lower() in keys],
    }


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    root = pathlib.Path(args[0])
    if "steamapps" in str(root).lower() and "--force" not in args:
        sys.exit("apply_fix: refusing a folder under steamapps (pass --force to do it anyway)")
    if not (root / "data" / "civs.xml").exists():
        sys.exit(f"apply_fix: {root} has no data\\civs.xml")
    backup = root / BACKUP
    if "--check" in args:
        s = status(root)
        print(f"WallMapu <ShipTechLimit>: {s['limit'] or 'none'}")
        print(f"{COUNCIL} researches {NEW_TECH if s['council'] else OLD_TECH}")
        print(f"{AGE0} makes {NEW_TECH if s['age0'] else OLD_TECH} obtainable")
        print(f"keys in {cfg_path(root)}: {', '.join(s['keys']) or 'none'}")
        return
    if "--restore" in args:
        if not backup.is_dir():
            sys.exit("apply_fix: no backup to restore")
        for path in changed_files(root):
            saved = backup / path.relative_to(root)
            if saved.exists():
                shutil.copy2(saved, path)
                print(f"restored {path}")
        shutil.rmtree(backup)
        return
    limit = 10
    if "--limit" in args:
        try:
            limit = int(args[args.index("--limit") + 1])
        except (IndexError, ValueError):
            sys.exit("apply_fix: --limit needs a number")
        if limit < 0:
            sys.exit("apply_fix: --limit needs a number from 0")
    for path in changed_files(root):
        saved = backup / path.relative_to(root)
        if path.exists() and not saved.exists():
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, saved)
    text, bom = read(root / "data" / "civs.xml")
    write(root / "data" / "civs.xml", set_limit(text, limit), bom)
    text, bom = read(root / "data" / "protoy.xml")
    write(root / "data" / "protoy.xml", swap_council(text), bom)
    text, bom = read(root / "data" / "techtreey.xml")
    write(root / "data" / "techtreey.xml", swap_age0(text), bom)
    cfg = cfg_path(root)
    text, bom = read(cfg) if cfg.exists() else ("", False)
    write(cfg, add_keys(text), bom)
    print(f"applied: WallMapu limit {limit}, {COUNCIL} and {AGE0} use {NEW_TECH}, keys in {cfg}")
    for name in ("protoy.xml.XMB", "techtreey.xml.XMB", "civs.xml.XMB"):
        if (root / "data" / name).exists():
            print(f"note: data\\{name} exists and is older than the XML now; the game reads the newer file")


if __name__ == "__main__":
    main()
