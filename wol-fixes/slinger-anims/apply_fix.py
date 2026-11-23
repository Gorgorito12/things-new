"""Puts the Aztec Macehualtin's slinger animations within reach of other models: the 35 clips retargeted on the
standard infantry skeleton (Bip01), one set made on Wars of Liberty's skirmisher model and one on the game's
native rifleman, each with its tag file. No DLL key is needed, and nothing of the mod changes: the clips are new
files that a unit's anim file names (files\\skirmisher-anims.xml and files\\native-anims.xml hold the blocks).

    python apply_fix.py <WoL folder> [--test]     apply (a backup of every file it changes goes to
                                                  <WoL folder>\\slinger-anims-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back, byte for byte, and delete the
                                                  files it added
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

What it adds:
- art\\WoL\\units\\infantry_ranged\\slinger\\anims_skirmisher\\<clip>.gr2 and .gr2.precomp (35 clips: made on
  WoL\\units\\infantry_ranged\\skirmisher\\skirmisher_age2) and anims_native\\ (made on units\\natives\\rifleman), by
  aoe3-blender-tools' tools/retarget_anims.py.

--test (for a test copy, not a release) also adds three TEST units, copies of POLYMarauder (the Polynesian slinger)
with their own anim files in art\\WoL\\units\\infantry_ranged\\slinger\\test\\:
- SlingerTestSkirmisher: the skirmisher model with the retargeted clips and the Macehualtin's sling;
- SlingerTestNative: the native rifleman with the retargeted clips and the sling;
- SlingerTestControl: the skirmisher model with the Macehualtin's own clips (what a modder gets today).
It changes data\\protoy.xml for that (backed up first).
"""
import json
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
FILES = HERE / "files"
BACKUP = "slinger-anims-backup"
ART = "art/WoL/units/infantry_ranged/slinger"
BASE_UNIT = "POLYMarauder"
TEST_UNITS = {"SlingerTestSkirmisher": "slinger_test_skirmisher",
              "SlingerTestNative": "slinger_test_native",
              "SlingerTestControl": "slinger_test_control"}


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


def clip_files():
    """(source, relative destination) of every clip and tag file the pack adds."""
    out = []
    for src in sorted((FILES / "art").rglob("*")):
        if src.is_file():
            out.append((src, src.relative_to(FILES).as_posix()))
    return out


def test_units(text):
    """protoy.xml with the three TEST units after the last unit (copies of BASE_UNIT, new ids)."""
    m = re.search(r'<Unit\b[^>]*\bname="%s"[^>]*>' % re.escape(BASE_UNIT), text)
    if m is None:
        sys.exit(f"apply_fix: protoy.xml has no unit {BASE_UNIT}")
    start, end = m.start(), text.index("</Unit>", m.end())
    base = text[start:end]
    if "<AnimFile>" not in base:
        sys.exit(f"apply_fix: unit {BASE_UNIT} has no <AnimFile>")
    ids = [int(x) for x in re.findall(r'<Unit\b[^>]*\bid="(\d+)"', text)]
    nxt = max(ids) + 1
    indent = re.match(r"[ \t]*", text[text.rindex("\n", 0, start) + 1:]).group(0)
    add = ""
    for name, anim in TEST_UNITS.items():
        if f'name="{name}"' in text:
            continue
        b = re.sub(r'\bid="\d+"', f'id="{nxt}"', base, count=1)
        b = b.replace(f'name="{BASE_UNIT}"', f'name="{name}"', 1)
        path = (ART + "/test/" + anim + ".xml").replace("art/", "", 1).replace("/", "\\")
        b = re.sub(r"<AnimFile>[^<]*</AnimFile>", lambda _m, p=path: f"<AnimFile>{p}</AnimFile>", b, count=1)
        add += indent + b + "</Unit>\r\n"
        nxt += 1
    last = text.index("\n", text.rindex("</Unit>")) + 1
    return text[:last] + add + text[last:]


def apply(root, test=False):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        sys.exit(f"apply_fix: already applied ({backup} exists); run --restore first")
    if not (root / "data/protoy.xml").exists() or not (root / "art").is_dir():
        sys.exit(f"apply_fix: {root} has no data\\protoy.xml or art folder: is this a Wars of Liberty folder?")
    if test and (root / "data/protoy.xml.xmb").exists():
        sys.exit(f"apply_fix: {root / 'data/protoy.xml.xmb'} exists: the game would read it instead of the edited XML")
    files = clip_files()
    if test:
        files += [(src, f"{ART}/test/{src.name}") for src in sorted((FILES / "test").glob("*.xml"))]
    for _src, rel in files:
        if (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} exists already; nothing changed")
    proto = None
    if test:
        text, enc = read_text(root / "data/protoy.xml")
        proto = (test_units(text), enc)
    backup.mkdir()
    manifest = {"changed": [], "added": [], "test": test}
    if test:
        (backup / "data").mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / "data/protoy.xml", backup / "data/protoy.xml")
        manifest["changed"].append("data/protoy.xml")
    for src, rel in files:
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, root / rel)
        manifest["added"].append(rel)
    if proto is not None:
        write_text(root / "data/protoy.xml", *proto)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(f"applied: {len(files)} files added" + (", 3 test units in protoy.xml" if test else "")
          + f"; backup in {backup}")


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
    for sub in ("anims_skirmisher", "anims_native", "test"):
        folder = root / ART / sub
        if folder.exists() and not any(folder.iterdir()):
            folder.rmdir()
    shutil.rmtree(backup)
    print("restored")


def check(root):
    present = [rel for _s, rel in clip_files() if (root / rel).exists()]
    print(f"clips and tag files: {len(present)} of {len(clip_files())} present")
    text, _ = read_text(root / "data/protoy.xml")
    for name in TEST_UNITS:
        print(f"test unit {name}: {'present' if f'name=\"{name}\"' in text else 'absent'}")
    print(f"backup {BACKUP}: {'yes' if (root / BACKUP / 'manifest.json').exists() else 'no'}")


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
        apply(root, "--test" in sys.argv)


if __name__ == "__main__":
    main()
