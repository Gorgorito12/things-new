"""Turns on the DLL key `cultureUI` in a Wars of Liberty folder: the in-game interface (minimised) per family of civs,
with a second look from the Great War on.

    python apply_fix.py <WoL folder> [--styles <folder>] [--engine-ext]   apply (a backup of every file it changes goes
                                                         to <WoL folder>\\culture-ui-backup\\ first)
    python apply_fix.py <WoL folder> --restore           put the backed-up files back and delete the files it added
    python apply_fix.py <WoL folder> --check             say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

What it changes:
- data\\uhc\\cultureui.xml (new): the nine families (files\\data\\uhc\\cultureui.xml: suffixes eu, an, la, ns, af,
  as, me, na, po, each with a Great War stage <suffix>_gw on the tech GreatWarizeALL);
- Startup\\wol.cfg: a line `cultureUI` (when the file has none);
- with --styles <folder>: the textures of <folder>\\ui\\ingame\\*.ddt (named <texture>_<suffix>.ddt or
  <texture>_<suffix>_gw.ddt) are copied to art\\ui\\ingame\\. A family with no textures keeps today's interface.
- when the folder has an engine-ext folder (our dinput8.dll beside WoL's own uhc.dll), or with --engine-ext:
  engine-ext\\cultureui.xml and engine-ext\\engine-ext.cfg instead of data\\uhc\\cultureui.xml and Startup\\wol.cfg
  (those two are for our UHC.dll in place of WoL's). --check shows both; --restore undoes what apply wrote.
"""
import hashlib
import json
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
DATA = HERE / "files" / "data" / "uhc" / "cultureui.xml"
BACKUP = "culture-ui-backup"
STYLE_NAME = re.compile(r"^[\w]+_(eu|an|la|ns|af|as|me|na|po)(_gw)?\.ddt$", re.I)


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


def targets(root, engine_ext):
    if engine_ext:
        return root / "engine-ext" / "cultureui.xml", root / "engine-ext" / "engine-ext.cfg"
    return root / "data" / "uhc" / "cultureui.xml", root / "Startup" / "wol.cfg"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def apply(root, styles, engine_ext):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        sys.exit(f"apply_fix: already applied ({backup} exists); run --restore first")
    engine_ext = engine_ext or (root / "engine-ext").is_dir()
    data, cfg = targets(root, engine_ext)
    if not (root / "art" / "ui" / "ingame").is_dir() or not (root / "Startup" / "wol.cfg").exists():
        sys.exit(f"apply_fix: {root} has no art\\ui\\ingame or no Startup\\wol.cfg: is this a Wars of Liberty folder?")
    style_files = []
    if styles is not None:
        folder = pathlib.Path(styles) / "ui" / "ingame"
        style_files = sorted(p for p in folder.glob("*.ddt") if STYLE_NAME.match(p.name))
        if not style_files:
            sys.exit(f"apply_fix: no <texture>_<family>[_gw].ddt in {folder}")
        for p in style_files:
            if (root / "art" / "ui" / "ingame" / p.name).exists():
                sys.exit(f"apply_fix: art\\ui\\ingame\\{p.name} exists already; nothing changed")
    backup.mkdir()
    manifest = {"changed": [], "added": [], "folders": []}
    if not data.parent.exists() and engine_ext:
        manifest["folders"].append("engine-ext")  # made here for --engine-ext; removed by --restore when empty

    def keep(path):
        rel = path.relative_to(root).as_posix()
        if path.exists():
            (backup / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, backup / rel)
            manifest["changed"].append(rel)
        else:
            manifest["added"].append(rel)

    keep(data)
    data.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(DATA, data)

    text, enc = read_text(cfg) if cfg.exists() else ("", "utf-8")
    if not re.search(r"(?im)^\s*cultureUI\b", text):
        keep(cfg)
        write_text(cfg, (text.rstrip("\r\n") + "\r\n" if text else "") + "cultureUI\r\n", enc)

    for p in style_files:
        dst = root / "art" / "ui" / "ingame" / p.name
        manifest["added"].append(dst.relative_to(root).as_posix())
        shutil.copy2(p, dst)

    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(f"applied: {data.relative_to(root)}, cultureUI in {cfg.relative_to(root)}, {len(style_files)} style "
          f"texture(s); backup in {backup}")


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
    for rel in manifest.get("folders", []):
        if (root / rel).is_dir() and not any((root / rel).iterdir()):
            (root / rel).rmdir()
    shutil.rmtree(backup)
    print(f"restored: {len(manifest['changed'])} file(s) put back, {len(manifest['added'])} removed")


def check(root):
    for engine_ext in (False, True):
        data, cfg = targets(root, engine_ext)
        if not cfg.exists():
            continue
        text, _ = read_text(cfg)
        on = re.search(r"(?im)^\s*cultureUI\b", text) is not None
        print(f"{cfg.relative_to(root)}: cultureUI {'on' if on else 'absent'}; {data.relative_to(root)}: "
              f"{'present ' + sha(data) if data.exists() else 'missing'}")
    found = sorted(p.name for p in (root / "art" / "ui" / "ingame").glob("*.ddt") if STYLE_NAME.match(p.name))
    families = sorted({STYLE_NAME.match(n).group(1).lower() + (STYLE_NAME.match(n).group(2) or "") for n in found})
    print(f"style textures in art\\ui\\ingame: {len(found)} ({', '.join(families) or 'none'})")
    print(f"backup: {'present' if (root / BACKUP / 'manifest.json').exists() else 'none'}")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root = pathlib.Path(sys.argv[1])
    if "steamapps" in str(root).lower() and "--force" not in sys.argv:
        sys.exit("apply_fix: this is a Steam folder; work on a copy, or add --force to change it anyway")
    styles = sys.argv[sys.argv.index("--styles") + 1] if "--styles" in sys.argv else None
    if "--restore" in sys.argv:
        restore(root)
    elif "--check" in sys.argv:
        check(root)
    else:
        apply(root, styles, "--engine-ext" in sys.argv)


if __name__ == "__main__":
    main()
