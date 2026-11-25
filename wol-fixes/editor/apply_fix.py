"""Installs the scenario editor search fields of the DLL key `editorSearch` in a Wars of Liberty folder: the three
editor layouts of files\\data, and the key in Startup\\wol.cfg.

    python apply_fix.py <WoL folder>              apply (a backup of every file it replaces goes to
                                                  <WoL folder>\\editor-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back, byte for byte, and delete the files
                                                  it added
    python apply_fix.py <WoL folder> --check      compare each file byte for byte with the pack, change nothing
    (a folder under steamapps is refused unless --force is given)

What it writes (README.txt has the why):
- data\\uieditorpalettes.xml, data\\uiforbiddenunitstechs.xml, data\\uitriggereditor.xml: the game's own layouts with
  the search fields (WoL ships none of them today, so they are new files; one that is there is backed up);
- Startup\\wol.cfg: the line `editorSearch`, when the file has no such line.
"""
import json
import pathlib
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
BACKUP = "editor-backup"
FILES = {  # target, relative to the WoL folder -> source, relative to this folder
    f"data/{name}": f"files/data/{name}"
    for name in ("uieditorpalettes.xml", "uiforbiddenunitstechs.xml", "uitriggereditor.xml")
}
CFG = "Startup/wol.cfg"
KEY = "editorSearch"


def has_key(text):
    return any(line.split("#")[0].split("//")[0].split()[:1] == [KEY] for line in text.splitlines())


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
    text = cfg.read_bytes().decode("latin-1")
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
