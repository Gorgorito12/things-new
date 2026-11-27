r"""Wars of Liberty's guerrilla for the Spanish (request #114): a guerrilla of their own on three buildings, with the
DLL key `partisans`.

    python apply_fix.py <WoL folder> [--unit Proto] [--nearby M]   apply (a backup of every file it changes goes to
                                                                  <WoL folder>\guerrilla-backup\ first)
    python apply_fix.py <WoL folder> --restore                    put the backed-up files back, then delete the backup
    python apply_fix.py <WoL folder> --check                      say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

What it changes (README.txt has the why):
- data\protoy.xml: <CivPartisan civ="Spanish" count="N">Unit</CivPartisan> in TownCenter (4), Barracks (2) and
  Stable (2); the unit is Rodelero unless --unit names another. With --nearby M, also
  <PartisanFromNearby>M</PartisanFromNearby> in those three (it then holds for every civ with a guerrilla there).
- Startup\wol.cfg (or engine-ext\engine-ext.cfg when that folder exists): the line `partisans`, when the file has none.
The Serbians and the Tupinamba keep what they have: a civ with no <CivPartisan> line uses PartisanType and
PartisanCount as before. civs.xml is not touched: a <CivPartisan> line turns the guerrilla on for its civ by itself.
"""
import pathlib
import re
import shutil
import sys

BACKUP = "guerrilla-backup"
CIV = "Spanish"
BUILDINGS = {"TownCenter": 4, "Barracks": 2, "Stable": 2}
KEY = "partisans"


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
    return [root / "data" / "protoy.xml", cfg_path(root)]


def proto_block(text, name):
    m = re.search(r"<Unit [^>]*name\s*=\s*['\"]" + name + r"['\"][^>]*>.*?</Unit>", text, re.S | re.I)
    if not m:
        sys.exit(f"apply_fix: no proto {name} in protoy.xml")
    return m


def line_of(block):
    m = re.search(r"<CivPartisan\s+civ=\"" + CIV + r"\"[^>]*>([^<]*)</CivPartisan>", block, re.I)
    return m


def add_lines(text, unit, nearby):
    for name, count in BUILDINGS.items():
        m = proto_block(text, name)
        block = m.group(0)
        nl = "\r\n" if "\r\n" in block else "\n"
        block = re.sub(r"[ \t]*<CivPartisan\s+civ=\"" + CIV + r"\"[^>]*>[^<]*</CivPartisan>\r?\n", "", block, flags=re.I)
        block = re.sub(r"[ \t]*<PartisanFromNearby>[^<]*</PartisanFromNearby>\r?\n", "", block, flags=re.I)
        add = f"\t\t<CivPartisan civ=\"{CIV}\" count=\"{count}\">{unit}</CivPartisan>{nl}"
        if nearby is not None:
            add += f"\t\t<PartisanFromNearby>{nearby}</PartisanFromNearby>{nl}"
        end = block.rindex("</Unit>")
        start = block.rfind(nl, 0, end) + len(nl)
        block = block[:start] + add + block[start:]
        text = text[:m.start()] + block + text[m.end():]
    return text


def add_key(text):
    nl = "\r\n" if "\r\n" in text else "\n"
    present = {line.split()[0].lower() for line in text.splitlines() if line.split()}
    if KEY.lower() not in present:
        text = text.rstrip("\r\n") + nl + KEY + nl
    return text


def status(root):
    proto, _ = read(root / "data" / "protoy.xml")
    out = {}
    for name in BUILDINGS:
        block = proto_block(proto, name).group(0)
        m = line_of(block)
        near = re.search(r"<PartisanFromNearby>([^<]*)</PartisanFromNearby>", block, re.I)
        out[name] = (m.group(0).strip() if m else None, near.group(1) if near else None)
    cfg = cfg_path(root)
    keys = {line.split()[0].lower() for line in read(cfg)[0].splitlines() if line.split()} if cfg.exists() else set()
    return out, KEY.lower() in keys


def main():
    args = sys.argv[1:]
    if not args or args[0].startswith("--"):
        sys.exit(__doc__)
    root = pathlib.Path(args[0])
    if "steamapps" in str(root).lower() and "--force" not in args:
        sys.exit("apply_fix: refusing a folder under steamapps (pass --force to do it anyway)")
    if not (root / "data" / "protoy.xml").exists():
        sys.exit(f"apply_fix: {root} has no data/protoy.xml")
    backup = root / BACKUP
    if "--check" in args:
        protos, key = status(root)
        for name, (line, near) in protos.items():
            print(f"{name}: {line or 'no Spanish line'}" + (f", from nearby buildings within {near} m" if near else ""))
        print(f"`{KEY}` in {cfg_path(root)}: {'yes' if key else 'no'}")
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
        print(f"removed {backup}")
        return
    unit = args[args.index("--unit") + 1] if "--unit" in args else "Rodelero"
    nearby = args[args.index("--nearby") + 1] if "--nearby" in args else None
    if nearby is not None:
        try:
            if not 0 <= float(nearby) <= 200:
                raise ValueError
        except ValueError:
            sys.exit("apply_fix: --nearby takes a radius in metres from 0 to 200")
    proto_path = root / "data" / "protoy.xml"
    proto, bom = read(proto_path)
    if not re.search(r"<Unit [^>]*name\s*=\s*['\"]" + re.escape(unit) + r"['\"]", proto, re.I):
        sys.exit(f"apply_fix: no proto {unit} in protoy.xml")
    for path in changed_files(root):
        saved = backup / path.relative_to(root)
        if path.exists() and not saved.exists():
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, saved)
    write(proto_path, add_lines(proto, unit, nearby), bom)
    cfg = cfg_path(root)
    text, cbom = read(cfg) if cfg.exists() else ("", False)
    write(cfg, add_key(text), cbom)
    print(f"applied: the Spanish get {unit} from {', '.join(f'{b} ({c})' for b, c in BUILDINGS.items())}"
          + (f", from the buildings within {nearby} m" if nearby is not None else "") + f"; `{KEY}` in {cfg}")


if __name__ == "__main__":
    main()
