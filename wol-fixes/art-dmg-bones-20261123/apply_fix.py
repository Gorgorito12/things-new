"""Puts the fixed anim files of WoL-dmg-bones-fix.zip into a Wars of Liberty folder: <definebone> lines for the bones
that damage templates name and the models have (132 files; see README.txt).

    python apply_fix.py <WoL folder>              apply (a backup of every file it replaces goes to
                                                  <WoL folder>\\dmg-bones-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back and delete the files it added
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

Every file is checked first against manifest.json: a file the pack replaces must hold WoL 1.0.15c's bytes, and a file
it adds (a loose copy of an anim file that is only in an art\\*.bar archive) must not exist. If any file differs,
nothing is written and the files that differ are listed (--force-other writes them anyway, with the same backup).
--restore puts back the exact bytes; --check reports each file as original, fixed, missing or other.
"""
import hashlib
import json
import pathlib
import shutil
import sys
import zipfile

HERE = pathlib.Path(__file__).resolve().parent
ZIP = HERE / "WoL-dmg-bones-fix.zip"
MANIFEST = HERE / "manifest.json"
BACKUP = "dmg-bones-backup"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def state(root, rel, entry):
    path = root / rel
    if not path.exists():
        return "missing"
    digest = sha(path.read_bytes())
    if digest == entry["fixed"]:
        return "fixed"
    if digest == entry["original"]:
        return "original"
    return "other"


def apply(root, files, force_other):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        sys.exit(f"apply_fix: already applied ({backup} exists); run --restore first")
    if not (root / "art").is_dir():
        sys.exit(f"apply_fix: {root} has no art folder: is this a Wars of Liberty folder?")
    wrong = []
    for rel, entry in files.items():
        s = state(root, rel, entry)
        expected = "missing" if entry["original"] is None else "original"
        if s not in (expected, "fixed"):
            wrong.append(f"{rel}: {s}")
    if wrong and not force_other:
        sys.exit("apply_fix: these files are not WoL 1.0.15c's; nothing changed (--force-other writes them anyway):\n  "
                 + "\n  ".join(wrong))
    with zipfile.ZipFile(ZIP) as z:
        data = {rel: z.read(rel) for rel in files}
    for rel, entry in files.items():
        if sha(data[rel]) != entry["fixed"]:
            sys.exit(f"apply_fix: {rel} in the zip does not match manifest.json; nothing changed")
    backup.mkdir()
    done = {"replaced": [], "added": []}
    for rel in files:
        target = root / rel
        if target.exists():
            (backup / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup / rel)
            done["replaced"].append(rel)
        else:
            done["added"].append(rel)
    (backup / "manifest.json").write_text(json.dumps(done, indent=1), encoding="utf-8")
    for rel in files:
        target = root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data[rel])
    print(f"applied: {len(done['replaced'])} files replaced, {len(done['added'])} added; backup in {backup}")


def restore(root):
    backup = root / BACKUP
    manifest_path = backup / "manifest.json"
    if not manifest_path.exists():
        sys.exit(f"apply_fix: no backup at {backup}")
    done = json.loads(manifest_path.read_text(encoding="utf-8"))
    for rel in done["replaced"]:
        shutil.copy2(backup / rel, root / rel)
    for rel in done["added"]:
        (root / rel).unlink(missing_ok=True)
    shutil.rmtree(backup)
    print(f"restored: {len(done['replaced'])} files put back, {len(done['added'])} removed")


def check(root, files):
    counts = {}
    for rel, entry in files.items():
        s = state(root, rel, entry)
        counts[s] = counts.get(s, 0) + 1
        if s == "other":
            print(f"{rel}: other (neither WoL 1.0.15c's nor the fixed file)")
    print(", ".join(f"{v} {k}" for k, v in sorted(counts.items())))
    applied = (root / BACKUP / "manifest.json").exists()
    print(f"backup: {'present (applied)' if applied else 'none'}")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root = pathlib.Path(sys.argv[1])
    if "steamapps" in str(root).lower() and "--force" not in sys.argv:
        sys.exit("apply_fix: this is a Steam folder; work on a copy, or add --force to change it anyway")
    files = json.loads(MANIFEST.read_text(encoding="utf-8"))["files"]
    if "--restore" in sys.argv:
        restore(root)
    elif "--check" in sys.argv:
        check(root, files)
    else:
        apply(root, files, "--force-other" in sys.argv)


if __name__ == "__main__":
    main()
