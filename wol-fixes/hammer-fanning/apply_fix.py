"""Hammer fanning for Wars of Liberty's European explorers: their two pistol abilities ("Hammer Fanning",
PowerRevolverSharpshooter, and "Slip Hammering", PowerRevolverCrackshot) get an animation of their own (the pistol
at the hip, the left palm sweeping back over the hammer at each of six shots) and fire every shot of it, each at the
next target when one falls.

    python apply_fix.py <WoL folder>              apply (a backup of every file it changes goes to
                                                  <WoL folder>\\hammer-fanning-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back and delete the files it added
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

What it changes (README.txt has the why):
- art\\WoL\\units\\explorers\\europeans\\explorer.xml: the anim RangedAttackSharpshoot uses the new clip
  explorer_fanning_attack with six Attack tags (each with the shot's sound and muzzle flash, as before) instead of
  the outlaw's nuggets\\outlaw_kidnap\\outlaw_pistol_attackA, and the anim SharpshootIdle (named by explorer.tactics,
  defined nowhere until now) is added;
- art\\WoL\\units\\explorers\\europeans\\fanning\\ (new): the two clips and their tag files (.gr2.precomp);
- data\\protoy.xml: the Explorer's ProtoActions SharpshooterAttack and CrackshotAttack get
  <RetargetInAction>1</RetargetInAction> and <PowerShots>6</PowerShots>;
- Startup\\wol.cfg: the lines `retargetInAction` and `powerShots` when the file has none.
"""
import json
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
FILES = HERE / "files"
BACKUP = "hammer-fanning-backup"
ANIM_FILE = "art/WoL/units/explorers/europeans/explorer.xml"
CLIP_DIR = "art/WoL/units/explorers/europeans/fanning"
CLIPS = ["explorer_fanning_attack.gr2", "explorer_fanning_attack.gr2.precomp",
         "explorer_fanning_idle.gr2", "explorer_fanning_idle.gr2.precomp"]
NEW_FILES = [f"{CLIP_DIR}/{name}" for name in CLIPS]
CHANGED = [ANIM_FILE, "data/protoy.xml", "Startup/wol.cfg"]
UNIT = "Explorer"
ACTIONS = ["SharpshooterAttack", "CrackshotAttack"]
TAGS = ["<RetargetInAction>1</RetargetInAction>", "<PowerShots>6</PowerShots>"]
KEYS = ["retargetInAction", "powerShots"]
OLD_CLIP = "nuggets\\outlaw_kidnap\\outlaw_pistol_attackA"
NEW_CLIP = "WoL\\units\\explorers\\europeans\\fanning\\explorer_fanning_attack"


def crlf(text):
    return text.replace("\r\n", "\n").replace("\n", "\r\n")


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


def anim_block(text, name):
    """(start, end) of the <anim> whose name is `name`, from its line's start to after its </anim> line."""
    m = re.search(r"[ \t]*<anim>\s*%s\s*\r?\n.*?</anim>[ \t]*\r?\n" % re.escape(name), text, re.S)
    if m is None or "<anim>" in m.group(0)[m.group(0).index("<anim>") + 6:]:
        return None
    return m.start(), m.end()


def new_anim_file(text):
    """explorer.xml with the new RangedAttackSharpshoot and SharpshootIdle; refuses a file it does not expect."""
    if anim_block(text, "SharpshootIdle") is not None:
        sys.exit("apply_fix: explorer.xml has a SharpshootIdle already")
    span = anim_block(text, "RangedAttackSharpshoot")
    if span is None or OLD_CLIP not in text[span[0]:span[1]]:
        sys.exit("apply_fix: explorer.xml has no RangedAttackSharpshoot with the outlaw's clip; nothing changed")
    blocks = crlf((FILES / "explorer-anims.xml").read_text(encoding="utf-8"))
    if not blocks.endswith("\r\n"):
        blocks += "\r\n"
    return text[:span[0]] + blocks + text[span[1]:]


def unit_block(text, name):
    m = re.search(r'<Unit\b[^>]*\bname="%s"[^>]*>' % re.escape(name), text)
    if m is None:
        sys.exit(f"apply_fix: protoy.xml has no unit {name}")
    return m.start(), text.index("</Unit>", m.end())


def edit_protoy(text):
    start, end = unit_block(text, UNIT)
    block = text[start:end]
    for action in ACTIONS:
        m = re.search(r"([ \t]*)<Name>%s</Name>\r?\n" % action, block)
        if m is None:
            sys.exit(f"apply_fix: the {UNIT} has no ProtoAction {action}")
        close = block.index("</ProtoAction>", m.end())
        body = block[m.end():close]
        add = "".join(f"{m.group(1)}{tag}\r\n" for tag in TAGS if tag.split(">")[0] + ">" not in body)
        block = block[:m.end()] + add + block[m.end():]
    return text[:start] + block + text[end:]


def apply(root):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        sys.exit(f"apply_fix: already applied ({backup} exists); run --restore first")
    for rel in (ANIM_FILE, "data/protoy.xml"):
        if not (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} is missing: is this a Wars of Liberty folder?")
    anim_text, anim_enc = read_text(root / ANIM_FILE)
    anim_text = new_anim_file(anim_text)          # made and checked before anything is written
    proto_text, proto_enc = read_text(root / "data/protoy.xml")
    proto_text = edit_protoy(proto_text)
    for rel in NEW_FILES:
        if (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} exists already")
    backup.mkdir()
    manifest = {"changed": [], "added": []}
    for rel in CHANGED:
        if (root / rel).exists():
            (backup / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, backup / rel)
            manifest["changed"].append(rel)
    for rel in NEW_FILES:
        dst = root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(FILES / rel, dst)
        manifest["added"].append(rel)
    write_text(root / ANIM_FILE, anim_text, anim_enc)
    write_text(root / "data/protoy.xml", proto_text, proto_enc)
    path = root / "Startup/wol.cfg"
    if path.exists():
        text, enc = read_text(path)
        for key in KEYS:
            if not re.search(r"(?im)^\s*%s\b" % key, text):
                text = text.rstrip("\r\n") + f"\r\n{key}\r\n"
        write_text(path, text, enc)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(f"applied; backup in {backup}")


def restore(root):
    backup = root / BACKUP
    manifest_path = backup / "manifest.json"
    if not manifest_path.exists():
        sys.exit(f"apply_fix: no backup at {backup}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for rel in manifest["added"]:
        (root / rel).unlink(missing_ok=True)
    folder = root / CLIP_DIR
    if folder.exists() and not any(folder.iterdir()):
        folder.rmdir()
    for rel in manifest["changed"]:
        shutil.copy2(backup / rel, root / rel)
    shutil.rmtree(backup)
    print("restored")


def check(root):
    text, _ = read_text(root / ANIM_FILE)
    span = anim_block(text, "RangedAttackSharpshoot")
    print("explorer.xml RangedAttackSharpshoot:",
          "new clip" if span and NEW_CLIP in text[span[0]:span[1]] else "stock (outlaw clip)")
    print("explorer.xml SharpshootIdle:", "present" if anim_block(text, "SharpshootIdle") else "missing")
    text, _ = read_text(root / "data/protoy.xml")
    start, end = unit_block(text, UNIT)
    block = text[start:end]
    for action in ACTIONS:
        i = block.index(f"<Name>{action}</Name>")
        body = block[i:block.index("</ProtoAction>", i)]
        print(f"{UNIT}/{action}:", ", ".join(t for t in TAGS if t in body) or "no tags")
    for rel in NEW_FILES:
        print(f"{rel}: {'present' if (root / rel).exists() else 'missing'}")
    cfg = root / "Startup/wol.cfg"
    if cfg.exists():
        text, _ = read_text(cfg)
        for key in KEYS:
            on = re.search(r"(?im)^\s*%s\b" % key, text) is not None
            print(f"wol.cfg {key}: {'on' if on else 'off'}")


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
