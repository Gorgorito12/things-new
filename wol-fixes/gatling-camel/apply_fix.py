"""Wars of Liberty's new gatling camel, which replaces the current one: the zamburak's camel without its
swivel gun, carrying the stock Gatling gun's barrels, casing, crank and magazine on its back, with a rider
who cranks it. Two units:

- GatlingCamel (the existing unit, its new model and animations): fires from the saddle, moving and
  firing like the zamburak (data\\tactics\\GatlingCamelSaddle.tactics: the zamburak's tactics with the
  gatling camel's attack). Its stats, cost, cards and string IDs do not change.
- GatlingCamelDeployed (new): a copy of GatlingCamel that keeps its deploy tactics: the camel lies down,
  the gunner fires from the saddle (data\\tactics\\GatlingCamelDeployed.tactics: GatlingCamel.tactics
  with the deploy lasting 3.33 s and the undeploy 2.17 s, the length of their animations). Its name and
  description are new strings (690950 to 690952, English); no card or building trains it yet.

    python apply_fix.py <WoL folder>              apply (a backup of every file it changes goes to
                                                  <WoL folder>\\gatling-camel-backup\\ first)
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    python apply_fix.py <WoL folder> --restore    put the backed-up files back, byte for byte, and delete the
                                                  files it added
    (a folder under steamapps is refused unless --force is given)

Files it adds: art\\WoL\\units\\cavalry_ranged\\gatling_camel\\ (the models, the animations and the anim files),
data\\tactics\\GatlingCamelSaddle.tactics and GatlingCamelDeployed.tactics. Files it changes: data\\protoy.xml
(GatlingCamel's <AnimFile> and <Tactics>; the new unit after it), data\\stringtabley.xml and the
translations' stringtabley.xml (the three new strings).
"""
import json
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
FILES = HERE / "files"
BACKUP = "gatling-camel-backup"
UNIT = "GatlingCamel"
NEW_UNIT = "GatlingCamelDeployed"
ANIM_A = r"WoL\units\cavalry_ranged\gatling_camel\gatling_camel.xml"
ANIM_B = r"WoL\units\cavalry_ranged\gatling_camel\gatling_camel_deployed.xml"
TACTICS_A = "GatlingCamelSaddle.tactics"
TACTICS_B = "GatlingCamelDeployed.tactics"
STRINGS = {
    690950: "Deployed Gatling Camel",
    690951: "AR-M Deployed Gatling Camel",
    690952: ("Machine gun on camel back, fired with the camel lying down and the gunner on foot: it must deploy "
             "before it fires. Better against &lt;color=0.74, 0.11, 0.58&gt;standing units &lt;/color&gt;than buildings."),
}
SHORT_ROLLOVER = 2018154          # "Mercenary", as GatlingCamel
TABLES = ("data/stringtabley.xml", "translations/_originals/stringtabley.xml", "translations/ES-LA/stringtabley.xml")


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


def added_files():
    """(source, relative destination) of every file the pack adds."""
    return [(src, src.relative_to(FILES).as_posix()) for src in sorted(FILES.rglob("*")) if src.is_file()]


def unit_block(text, name):
    m = re.search(r'<Unit\b[^>]*\bname="%s"[^>]*>' % re.escape(name), text)
    if m is None:
        return None
    return m.start(), text.index("</Unit>", m.end()) + len("</Unit>")


def edit_protos(text):
    """protoy.xml with GatlingCamel on the new art and tactics, and GatlingCamelDeployed after it."""
    span = unit_block(text, UNIT)
    if span is None:
        sys.exit(f"apply_fix: protoy.xml has no unit {UNIT}")
    start, end = span
    old = text[start:end]
    for tag in ("AnimFile", "Tactics", "DisplayNameID", "EditorNameID", "RolloverTextID"):
        if f"<{tag}>" not in old:
            sys.exit(f"apply_fix: unit {UNIT} has no <{tag}>")
    a = re.sub(r"<AnimFile>[^<]*</AnimFile>", lambda _m: f"<AnimFile>{ANIM_A}</AnimFile>", old, count=1)
    a = re.sub(r"<Tactics>[^<]*</Tactics>", f"<Tactics>{TACTICS_A}</Tactics>", a, count=1)
    ids = [int(x) for x in re.findall(r'<Unit\b[^>]*\bid="(\d+)"', text)]
    dbids = [int(x) for x in re.findall(r"<DBID>(\d+)</DBID>", text)]
    nid, ndb = max(ids) + 1, max(dbids) + 1
    b = re.sub(r'\bid="\d+"', f'id="{nid}"', old, count=1)
    b = b.replace(f'name="{UNIT}"', f'name="{NEW_UNIT}"', 1)
    b = re.sub(r"<DBID>\d+</DBID>", f"<DBID>{ndb}</DBID>", b, count=1)
    b = re.sub(r"<DisplayNameID>\d+</DisplayNameID>", "<DisplayNameID>690950</DisplayNameID>", b, count=1)
    b = re.sub(r"<EditorNameID>\d+</EditorNameID>", "<EditorNameID>690951</EditorNameID>", b, count=1)
    b = re.sub(r"<RolloverTextID>\d+</RolloverTextID>", "<RolloverTextID>690952</RolloverTextID>", b, count=1)
    b = re.sub(r"<ShortRolloverTextID>\d+</ShortRolloverTextID>",
               f"<ShortRolloverTextID>{SHORT_ROLLOVER}</ShortRolloverTextID>", b, count=1)
    b = re.sub(r"<AnimFile>[^<]*</AnimFile>", lambda _m: f"<AnimFile>{ANIM_B}</AnimFile>", b, count=1)
    b = re.sub(r"<Tactics>[^<]*</Tactics>", f"<Tactics>{TACTICS_B}</Tactics>", b, count=1)
    indent = re.match(r"[ \t]*", text[text.rindex("\n", 0, start) + 1:]).group(0)
    return text[:start] + a + "\r\n" + indent + b + text[end:]


def edit_strings(text):
    add = "".join(f"\t\t<String _locID='{i}'>{s}</String>\r\n" for i, s in STRINGS.items()
                  if f"_locID='{i}'" not in text and f'_locID="{i}"' not in text and f"_locID ='{i}'" not in text)
    if not add:
        return text
    marker = text.find("<!-- DON'T WRITE STRINGS DOWN HERE -->")
    i = text.rfind("\n", 0, marker) + 1 if marker >= 0 else text.rindex("\t</Language>")
    return text[:i] + add + text[i:]


def apply(root):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        sys.exit(f"apply_fix: already applied ({backup} exists); run --restore first")
    if not (root / "data/protoy.xml").exists() or not (root / "art").is_dir():
        sys.exit(f"apply_fix: {root} has no data\\protoy.xml or art folder: is this a Wars of Liberty folder?")
    if (root / "data/protoy.xml.xmb").exists():
        sys.exit(f"apply_fix: {root / 'data/protoy.xml.xmb'} exists: the game would read it instead of the edited XML")
    files = added_files()
    for _src, rel in files:
        if (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} exists already; nothing changed")
    text, enc = read_text(root / "data/protoy.xml")
    if unit_block(text, NEW_UNIT) is not None:
        sys.exit(f"apply_fix: protoy.xml has a unit {NEW_UNIT} already; nothing changed")
    protos = edit_protos(text)
    tables = []
    for rel in TABLES:
        if (root / rel).exists():
            t, e = read_text(root / rel)
            tables.append((rel, edit_strings(t), e))
    backup.mkdir()
    manifest = {"changed": [], "added": []}
    for rel in ["data/protoy.xml"] + [r for r, _t, _e in tables]:
        (backup / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / rel, backup / rel)
        manifest["changed"].append(rel)
    for src, rel in files:
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, root / rel)
        manifest["added"].append(rel)
    write_text(root / "data/protoy.xml", protos, enc)
    for rel, t, e in tables:
        write_text(root / rel, t, e)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(f"applied: {len(files)} files added, {UNIT} on the new art and tactics, {NEW_UNIT} added, "
          f"{len(tables)} string tables; backup in {backup}")


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
    folder = root / "art/WoL/units/cavalry_ranged/gatling_camel"
    if folder.exists() and not any(folder.iterdir()):
        folder.rmdir()
    shutil.rmtree(backup)
    print("restored")


def check(root):
    present = [rel for _s, rel in added_files() if (root / rel).exists()]
    print(f"files: {len(present)} of {len(added_files())} present")
    text, _ = read_text(root / "data/protoy.xml")
    span = unit_block(text, UNIT)
    block = text[span[0]:span[1]] if span else ""
    print(f"{UNIT}: {'new art and tactics' if ANIM_A in block and TACTICS_A in block else 'as WoL ships it'}")
    print(f"{NEW_UNIT}: {'present' if unit_block(text, NEW_UNIT) else 'absent'}")
    for rel in TABLES:
        if (root / rel).exists():
            t, _ = read_text(root / rel)
            n = sum(1 for i in STRINGS if f"'{i}'" in t or f'"{i}"' in t)
            print(f"{rel}: {n} of {len(STRINGS)} strings")
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
        apply(root)


if __name__ == "__main__":
    main()
