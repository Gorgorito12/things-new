r"""Wars of Liberty's guerrilla for the Spanish (request #114): a guerrilla of their own on three buildings, with the
DLL key `partisans`, and the Tupinamba's UybassyArcher back.

    python apply_fix.py <WoL folder> [--unit Proto] [--nearby M [--cooldown S]]
                                                                  apply (a backup of every file it changes goes to
                                                                  <WoL folder>\guerrilla-backup\ first)
    python apply_fix.py <WoL folder> --restore                    put the backed-up files back, then delete the backup
    python apply_fix.py <WoL folder> --check                      say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

What it changes (README.txt has the why):
- data\protoy.xml: <CivPartisan civ="Spanish" count="N">Unit</CivPartisan> in TownCenter (4), Barracks (2) and
  Stable (2); the unit is Rodelero unless --unit names another. <CivPartisan civ="Tupinamba">UybassyArcher</CivPartisan>
  in TownCenter, ArtilleryDepot and Market (no count: each building's own PartisanCount). A <PartisanFromNearby> line
  of the 0.7.0 pack in those buildings is taken out (the DLL no longer reads it).
- data\civs.xml: with --nearby M, <PartisanNearby>M</PartisanNearby> in the Spanish civ (the nearby mode: when a
  Spanish building dies, each Spanish building with a guerrilla within M metres gives its own, and they walk to its
  gather point; the destroyed building gives none). Without --nearby, a <PartisanNearby> line there is taken out.
  With --cooldown S too, <PartisanCooldown>S</PartisanCooldown> under it (a building that gave waits S seconds of game
  time before it gives again); without --cooldown, a <PartisanCooldown> line there is taken out.
- Startup\wol.cfg (or engine-ext\engine-ext.cfg when that folder exists): the line `partisans`, when the file has none.
The Serbians keep what they have: a civ with no <CivPartisan> line uses PartisanType and PartisanCount as before (on
those three buildings the last <PartisanType>, SerbianInferno).
"""
import pathlib
import re
import shutil
import sys

BACKUP = "guerrilla-backup"
CIV = "Spanish"
BUILDINGS = {"TownCenter": 4, "Barracks": 2, "Stable": 2}
TUPI = "Tupinamba"
TUPI_UNIT = "UybassyArcher"
TUPI_BUILDINGS = ["TownCenter", "ArtilleryDepot", "Market"]
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
    return [root / "data" / "protoy.xml", root / "data" / "civs.xml", cfg_path(root)]


def proto_block(text, name):
    m = re.search(r"<Unit [^>]*name\s*=\s*['\"]" + name + r"['\"][^>]*>.*?</Unit>", text, re.S | re.I)
    if not m:
        sys.exit(f"apply_fix: no proto {name} in protoy.xml")
    return m


def line_of(block, civ):
    return re.search(r"<CivPartisan\s+civ=\"" + civ + r"\"[^>]*>([^<]*)</CivPartisan>", block, re.I)


def drop_line(block, civ):
    return re.sub(r"[ \t]*<CivPartisan\s+civ=\"" + civ + r"\"[^>]*>[^<]*</CivPartisan>\r?\n", "", block, flags=re.I)


def put_before_end(block, add):
    end = block.rindex("</Unit>")
    nl = "\r\n" if "\r\n" in block else "\n"
    start = block.rfind(nl, 0, end) + len(nl)
    return block[:start] + add + block[start:]


def add_lines(text, unit):
    for name in dict.fromkeys(list(BUILDINGS) + TUPI_BUILDINGS):
        m = proto_block(text, name)
        block = m.group(0)
        nl = "\r\n" if "\r\n" in block else "\n"
        block = drop_line(drop_line(block, CIV), TUPI)
        block = re.sub(r"[ \t]*<PartisanFromNearby>[^<]*</PartisanFromNearby>\r?\n", "", block, flags=re.I)
        add = ""
        if name in BUILDINGS:
            add += f"\t\t<CivPartisan civ=\"{CIV}\" count=\"{BUILDINGS[name]}\">{unit}</CivPartisan>{nl}"
        if name in TUPI_BUILDINGS:
            add += f"\t\t<CivPartisan civ=\"{TUPI}\">{TUPI_UNIT}</CivPartisan>{nl}"
        block = put_before_end(block, add)
        text = text[:m.start()] + block + text[m.end():]
    return text


def civ_block(text, civ):
    m = re.search(r"<civ>\s*<name>" + civ + r"</name>.*?</civ>", text, re.S)
    if not m:
        sys.exit(f"apply_fix: no civ {civ} in civs.xml")
    return m


def set_nearby(text, nearby, cooldown):
    m = civ_block(text, CIV)
    block = re.sub(r"[ \t]*<PartisanNearby>[^<]*</PartisanNearby>\r?\n", "", m.group(0), flags=re.I)
    block = re.sub(r"[ \t]*<PartisanCooldown>[^<]*</PartisanCooldown>\r?\n", "", block, flags=re.I)
    if nearby is not None:
        name = re.search(r"<name>" + CIV + r"</name>(\r?\n)", block)
        nl = name.group(1)
        add = f"\t\t<PartisanNearby>{nearby}</PartisanNearby>{nl}"
        if cooldown is not None:
            add += f"\t\t<PartisanCooldown>{cooldown}</PartisanCooldown>{nl}"
        block = block[:name.end()] + add + block[name.end():]
    return text[:m.start()] + block + text[m.end():]


def add_key(text):
    nl = "\r\n" if "\r\n" in text else "\n"
    present = {line.split()[0].lower() for line in text.splitlines() if line.split()}
    if KEY.lower() not in present:
        text = text.rstrip("\r\n") + nl + KEY + nl
    return text


def status(root):
    proto, _ = read(root / "data" / "protoy.xml")
    out = {}
    for name in dict.fromkeys(list(BUILDINGS) + TUPI_BUILDINGS):
        block = proto_block(proto, name).group(0)
        lines = [m.group(0).strip() for m in (line_of(block, CIV), line_of(block, TUPI)) if m]
        old = re.search(r"<PartisanFromNearby>([^<]*)</PartisanFromNearby>", block, re.I)
        out[name] = (lines, old.group(1) if old else None)
    civs, _ = read(root / "data" / "civs.xml")
    block = civ_block(civs, CIV).group(0)
    near = re.search(r"<PartisanNearby>([^<]*)</PartisanNearby>", block, re.I)
    wait = re.search(r"<PartisanCooldown>([^<]*)</PartisanCooldown>", block, re.I)
    cfg = cfg_path(root)
    keys = {line.split()[0].lower() for line in read(cfg)[0].splitlines() if line.split()} if cfg.exists() else set()
    return out, near.group(1) if near else None, wait.group(1) if wait else None, KEY.lower() in keys


def main():
    args = sys.argv[1:]
    if not args or args[0].startswith("--"):
        sys.exit(__doc__)
    root = pathlib.Path(args[0])
    if "steamapps" in str(root).lower() and "--force" not in args:
        sys.exit("apply_fix: refusing a folder under steamapps (pass --force to do it anyway)")
    for name in ("protoy.xml", "civs.xml"):
        if not (root / "data" / name).exists():
            sys.exit(f"apply_fix: {root} has no data/{name}")
    backup = root / BACKUP
    if "--check" in args:
        protos, near, wait, key = status(root)
        for name, (lines, old) in protos.items():
            print(f"{name}: {'; '.join(lines) if lines else 'no Spanish or Tupinamba line'}"
                  + (f" (old <PartisanFromNearby>{old}</PartisanFromNearby>: no longer read)" if old else ""))
        print(f"civs.xml, {CIV}: " + (f"<PartisanNearby>{near}</PartisanNearby>" if near else "no <PartisanNearby>")
              + ", " + (f"<PartisanCooldown>{wait}</PartisanCooldown>" if wait else "no <PartisanCooldown>"))
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
            if not 0 < float(nearby) <= 200:
                raise ValueError
        except ValueError:
            sys.exit("apply_fix: --nearby takes a radius in metres above 0, up to 200")
    cooldown = args[args.index("--cooldown") + 1] if "--cooldown" in args else None
    if cooldown is not None:
        if nearby is None:
            sys.exit("apply_fix: --cooldown counts only in the nearby mode: give --nearby too")
        try:
            if not 0 <= float(cooldown) <= 3600:
                raise ValueError
        except ValueError:
            sys.exit("apply_fix: --cooldown takes seconds from 0 to 3600")
    proto_path = root / "data" / "protoy.xml"
    proto, bom = read(proto_path)
    for name in (unit, TUPI_UNIT):
        if not re.search(r"<Unit [^>]*name\s*=\s*['\"]" + re.escape(name) + r"['\"]", proto, re.I):
            sys.exit(f"apply_fix: no proto {name} in protoy.xml")
    civs_path = root / "data" / "civs.xml"
    civs, cbom = read(civs_path)
    civ_block(civs, CIV)
    for path in changed_files(root):
        saved = backup / path.relative_to(root)
        if path.exists() and not saved.exists():
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, saved)
    write(proto_path, add_lines(proto, unit), bom)
    write(civs_path, set_nearby(civs, nearby, cooldown), cbom)
    cfg = cfg_path(root)
    text, kbom = read(cfg) if cfg.exists() else ("", False)
    write(cfg, add_key(text), kbom)
    print(f"applied: the Spanish get {unit} from {', '.join(f'{b} ({c})' for b, c in BUILDINGS.items())}"
          + (f", in the nearby mode within {nearby} m" if nearby is not None else "")
          + (f", a cooldown of {cooldown} s per building" if cooldown is not None else "")
          + f"; the {TUPI} get {TUPI_UNIT} from {', '.join(TUPI_BUILDINGS)}; `{KEY}` in {cfg}")
    if (root / "data" / "civs.xml.XMB").exists() or (root / "data" / "protoy.xml.XMB").exists():
        print("note: an .XMB of civs.xml or protoy.xml exists; the game reads the newer file")


if __name__ == "__main__":
    main()
