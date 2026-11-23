"""Installs the minimized unit panel of the DLL key `minUIStats` in a Wars of Liberty folder: the layout, the rows file,
the drawn stat icons and the four unit type icons from JTMaston's art (Line, Skirmisher, Standing, Maneuver).

    python apply_fix.py <WoL folder>              apply (a backup of every file it replaces goes to
                                                  <WoL folder>\\min-ui-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back, byte for byte, and delete the files
                                                  it added
    python apply_fix.py <WoL folder> --check      compare each file byte for byte with the pack, change nothing
    (a folder under steamapps is refused unless --force is given)

What it writes (README.txt has the why):
- data\\uiunitselectionmin.xml: proposed-uiunitselectionmin.xml (WoL's own file is backed up);
- data\\uhc\\minuirows.xml: minuirows.xml;
- art\\ui\\ingame\\stat_icon_rof, _traintime, _armor, _los, _speed, _projectiles .ddt (new): the six drawn stat icons;
- the unit type icons of the multipliers (version 8, 2026-11-23: JTMaston's art, converted, not redrawn), at the
  paths the panels draw, so no data changes (WoL's own files are backed up):
    art\\ui\\ingame\\stat_icon_heavy_infantry.ddt                Line (AbstractHeavyInfantry): blue coat, the musket
                                                               upright in front
    art\\ui\\ingame\\stat_icon_skirmisher.ddt                    Skirmisher (AbstractRangedInfantry, the path WoL's
                                                               attackTypeIcons line names): green coat, the musket
                                                               held diagonally
    art\\ui\\ingame\\stat_icon_infantry.ddt                       Standing (AbstractInfantry): purple coat, no weapon;
                                                               the panels draw this file for AbstractInfantry
    art\\WoL\\ui\\ingame\\staticons\\stat_icon_standing_unit.ddt   the same picture, at the path wol.cfg names
    art\\WoL\\ui\\ingame\\staticons\\stat_icon_ranged.ddt          Maneuver (AbstractRangedCavalry): a winged Minie
                                                               bullet, the bullet in copper (#C75A21);
- Startup\\wol.cfg: the line `minUIStats`, when the file has no such line.
"""
import json
import pathlib
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
BACKUP = "min-ui-backup"
FILES = {  # target, relative to the WoL folder -> source, relative to this folder
    "data/uiunitselectionmin.xml": "proposed-uiunitselectionmin.xml",
    "data/uhc/minuirows.xml": "minuirows.xml",
}
for _p in sorted((HERE / "art").rglob("*.ddt")):
    FILES["art/" + _p.relative_to(HERE / "art").as_posix()] = _p.relative_to(HERE).as_posix()
CFG = "Startup/wol.cfg"
KEY = "minUIStats"


def has_key(text):
    return any(line.split("#")[0].split()[:1] == [KEY] for line in text.splitlines())


def apply(root):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        print(f"already applied ({backup} exists); run --restore first")
        return 1
    manifest = {"changed": [], "added": []}
    for rel, src in FILES.items():
        target = root / rel
        if target.exists():
            (backup / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup / rel)
            manifest["changed"].append(rel)
        else:
            manifest["added"].append(rel)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(HERE / src, target)
        print(f"wrote {rel}")
    cfg = root / CFG
    raw = cfg.read_bytes()
    text = raw.decode("latin-1")
    if not has_key(text):
        (backup / CFG).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(cfg, backup / CFG)
        manifest["changed"].append(CFG)
        newline = "\r\n" if "\r\n" in text else "\n"
        cfg.write_bytes((text + ("" if text.endswith(("\n", "\r")) or not text else newline) + KEY + newline)
                        .encode("latin-1"))
        print(f"added {KEY} to {CFG}")
    backup.mkdir(exist_ok=True)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(f"done; backup in {backup}")
    return 0


def restore(root):
    backup = root / BACKUP
    manifest_path = backup / "manifest.json"
    if not manifest_path.exists():
        print(f"nothing to restore ({manifest_path} not found)")
        return 1
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for rel in manifest["added"]:
        (root / rel).unlink(missing_ok=True)
        print(f"deleted {rel}")
    for rel in manifest["changed"]:
        shutil.copy2(backup / rel, root / rel)
        print(f"restored {rel}")
    shutil.rmtree(backup)
    return 0


def check(root):
    for rel, src in FILES.items():
        target = root / rel
        state = "missing" if not target.exists() else (
            "applied" if target.read_bytes() == (HERE / src).read_bytes() else "differs")
        print(f"{state:8} {rel}")
    cfg = root / CFG
    print(f"{'applied' if cfg.exists() and has_key(cfg.read_bytes().decode('latin-1')) else 'missing':8} {CFG}: {KEY}")
    print(f"backup: {'yes' if (root / BACKUP / 'manifest.json').exists() else 'no'}")
    return 0


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 1:
        print(__doc__)
        return 2
    root = pathlib.Path(args[0]).resolve()
    if "steamapps" in str(root).lower() and "--force" not in sys.argv:
        print("refused: a folder under steamapps (add --force if you mean it)")
        return 2
    if not (root / CFG).exists():
        print(f"not a WoL folder: {root / CFG} not found")
        return 2
    if "--restore" in sys.argv:
        return restore(root)
    if "--check" in sys.argv:
        return check(root)
    return apply(root)


if __name__ == "__main__":
    sys.exit(main())
