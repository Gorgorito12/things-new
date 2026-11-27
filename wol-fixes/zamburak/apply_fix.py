"""Wars of Liberty's zamburak cannon: MEZamburak gets a new model and animations. The zamburak's camel
without its swivel gun carries a bronze cannon (the midfa's barrel at 2/3 of its length, 0.6 of its
size) on a swivel on its withers; its rider limbers and unlimbers it. One unit with two modes, as the
stock field guns (data\\tactics\\zamburakCannon.tactics):

- Limber (as trained): it walks and runs, the gun angled down beside the camel's neck; it cannot fire.
  An attack order unlimbers it first.
- Bombard: the camel lies down, the artillerist gets off and stands at his station behind the breech,
  the gun resting at +90 (square to the camel's spine); he fires it by touching the vent with the hot
  tip of a short stick, then reloads by hand (the gun swung round to him through its back, charge and
  ball pushed in, swung back). With the DLL key turretArc (one line in engine-ext\\engine-ext.cfg, below) the gun
  turns on its swivel from +30 to +150 instead of the camel turning.

    python apply_fix.py <WoL folder>              apply (a backup of every file it changes goes to
                                                  <WoL folder>\\zamburak-backup\\ first)
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    python apply_fix.py <WoL folder> --restore    put the backed-up files back, byte for byte, and delete the
                                                  files it added
    (a folder under steamapps is refused unless --force is given)

Files it adds: art\\WoL\\units\\cavalry_ranged\\zamburak_cannon\\ (the models, the animations, their tag files,
the aim file, the anim files and the fuse's particle files),
data\\tactics\\zamburakCannon.tactics. File it changes: data\\protoy.xml
(MEZamburak's <AnimFile>, <Tactics> and its CannonAttack's <ROF>, 4.0 -> 5.0: a proposal, see the README).
The current files (art\\WoL\\units\\cavalry_ranged\\zamburak\\, zamburakME.tactics) are not touched.

The turning gun (the pack does not edit the cfg): this line in engine-ext\\engine-ext.cfg (our dinput8.dll beside
WoL's own uhc.dll), or in Startup\\wol.cfg if our UHC.dll is used in place of WoL's:
    turretArc MEZamburak art\\WoL\\units\\cavalry_ranged\\zamburak_cannon\\zamburak_cannon.aim
"""
import json
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
FILES = HERE / "files"
BACKUP = "zamburak-backup"
UNIT = "MEZamburak"
ANIM = r"WoL\units\cavalry_ranged\zamburak_cannon\zamburak_cannon.xml"
TACTICS = "zamburakCannon.tactics"
ROF = "5.000000"          # its fire (2.0 s) and its reload (3.0 s): a proposal for WoL's team
FOLDER = "art/WoL/units/cavalry_ranged/zamburak_cannon"


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
    """protoy.xml with MEZamburak on the new art and tactics, its cannon's ROF 5.0."""
    span = unit_block(text, UNIT)
    if span is None:
        sys.exit(f"apply_fix: protoy.xml has no unit {UNIT}")
    start, end = span
    old = text[start:end]
    for tag in ("AnimFile", "Tactics"):
        if f"<{tag}>" not in old:
            sys.exit(f"apply_fix: unit {UNIT} has no <{tag}>")
    new = re.sub(r"<AnimFile>[^<]*</AnimFile>", lambda _m: f"<AnimFile>{ANIM}</AnimFile>", old, count=1)
    new = re.sub(r"<Tactics>[^<]*</Tactics>", f"<Tactics>{TACTICS}</Tactics>", new, count=1)
    m = re.search(r"(<ProtoAction>\s*<Name>CannonAttack</Name>.*?<ROF>)([^<]*)(</ROF>)", new, re.S)
    if m is None:
        sys.exit(f"apply_fix: unit {UNIT} has no CannonAttack with a <ROF>")
    new = new[:m.start(2)] + ROF + new[m.end(2):]
    # unlimbered it moves slowly (its Bombard tactic's speedmodifier) and turns on the spot to a target outside the
    # gun's arc, as the gatling camel and the falconet do
    if "<Flag>RotateInPlace</Flag>" not in new:
        f = re.search(r"([ \t]*)<Flag>ConstrainOrientation</Flag>", new)
        if f is None:
            sys.exit(f"apply_fix: unit {UNIT} has no <Flag>ConstrainOrientation</Flag> to put RotateInPlace before")
        new = new[:f.start()] + f"{f.group(1)}<Flag>RotateInPlace</Flag>\r\n" + new[f.start():]
    # the unlimber and limber buttons, as the falconet has them (page 9: Tactic4 unlimbers, Tactic3 limbers)
    if ">Tactic4</Command>" not in new:
        c = re.search(r'([ \t]*)<Command [^>]*page="10"[^>]*>', new)
        if c is None:
            sys.exit(f"apply_fix: unit {UNIT} has no page 10 <Command> to put the tactic buttons before")
        ind = c.group(1)
        new = (new[:c.start()] + f'{ind}<Command column="0" page="9">Tactic4</Command>\r\n'
               f'{ind}<Command column="1" page="9">Tactic3</Command>\r\n' + new[c.start():])
    return text[:start] + new + text[end:]


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
    protos = edit_protos(text)
    backup.mkdir()
    manifest = {"changed": ["data/protoy.xml"], "added": []}
    (backup / "data").mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / "data/protoy.xml", backup / "data/protoy.xml")
    for src, rel in files:
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        if rel.endswith(".tactics"):
            # CRLF whatever the checkout gave: with bare LF and a line break after a tactic's name the
            # game defines cTacticNormal twice and the AI script stops compiling
            raw = src.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
            (root / rel).write_bytes(raw)
        else:
            shutil.copy2(src, root / rel)
        manifest["added"].append(rel)
    write_text(root / "data/protoy.xml", protos, enc)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(f"applied: {len(files)} files added, {UNIT} on the new art and tactics (ROF {float(ROF):g}); backup in {backup}")


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
    folder = root / FOLDER
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
    on = ANIM in block and TACTICS in block
    rof = re.search(r"<Name>CannonAttack</Name>.*?<ROF>([^<]*)</ROF>", block, re.S)
    print(f"{UNIT}: {'new art and tactics' if on else 'as WoL ships it'}, ROF {rof.group(1) if rof else '?'}")
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
