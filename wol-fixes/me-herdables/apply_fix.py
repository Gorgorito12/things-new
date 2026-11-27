"""Makes Wars of Liberty's Middle East nomads work as moving livestock pens: herdables gather (fatten) from a nomad
a few metres away and follow it when it walks, idle herdables within 10 m are drawn to it, and a fattened herdable
walks a few metres away from it and stays there (with the DLL key `herdWalkAwayFix`).

    python apply_fix.py <WoL folder>              apply (a backup of every file it changes goes to
                                                  <WoL folder>\\me-herdables-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    (a folder under steamapps is refused unless --force is given)

What it changes (README.txt has the why):
- data\\protoy.xml, the six nomads (Nomad, NomadKarakalpak, NomadTurkman, NomadKyrgyz, Bedouin, BedouinFree):
  the unit types AbstractTypeHerdableMagnet and Resource, the flag UnlimitedSupply, <GathererLimit>10 and
  <InitialResource resourcetype="Food">999 (what a LivestockPen has; the stock gather refuses a target without
  them, and the magnet type is what draws idle herdables and sends fattened ones away);
- data\\tactics\\herd.tactics and herdcoin.tactics, the Gather action: a <rate> for each nomad, and a
  <typedmaxrange> of 6 m for each (pens keep the action's 0.5 m), so the herd gathers from a few metres away and
  follows the nomad;
- Startup\\wol.cfg: the line `herdWalkAwayFix` (added when the file has no such line).
The nomads' CattleFatteningAura is left as it is.
"""
import json
import pathlib
import re
import shutil
import sys

BACKUP = "me-herdables-backup"
NOMADS = ["Nomad", "NomadKarakalpak", "NomadTurkman", "NomadKyrgyz", "Bedouin", "BedouinFree"]
DISTANCE = "6"
TACTICS = ["data/tactics/herd.tactics", "data/tactics/herdcoin.tactics"]
CHANGED = ["data/protoy.xml"] + TACTICS + ["Startup/wol.cfg"]
MARK = "AbstractTypeHerdableMagnet"


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


def unit_block(text, name):
    """(start, end) of <Unit ... name="name"> ... </Unit> in protoy.xml, or None."""
    m = re.search(r"<Unit\b[^>]*\bname\s*=\s*['\"]%s['\"][^>]*>" % re.escape(name), text)
    if m is None:
        return None
    return m.start(), text.index("</Unit>", m.end())


def edit_nomad(text, name):
    span = unit_block(text, name)
    if span is None:
        print(f"apply_fix: protoy.xml has no unit {name}; skipped")
        return text
    start, end = span
    block = text[start:end]
    nl = "\r\n" if "\r\n" in block else "\n"
    types = re.findall(r"<UnitType>([^<]+)</UnitType>", block)
    add = "".join(f"<UnitType>{t}</UnitType>{nl}\t\t" for t in (MARK, "Resource") if t not in types)
    if add:
        i = block.index("<UnitType>")
        block = block[:i] + add + block[i:]
    if "<Flag>UnlimitedSupply</Flag>" not in block:
        i = block.index("<Flag>") if "<Flag>" in block else block.index("<UnitType>")
        block = block[:i] + f"<Flag>UnlimitedSupply</Flag>{nl}\t\t" + block[i:]
    extra = ""
    if "<GathererLimit>" not in block:
        extra += f"<GathererLimit>10</GathererLimit>{nl}\t\t"
    if not re.search(r"<InitialResource\s+resourcetype\s*=\s*['\"]Food['\"]", block):
        extra += f'<InitialResource resourcetype="Food">999.0000</InitialResource>{nl}\t\t'
    if extra:
        i = block.index("<Tactics>")
        block = block[:i] + extra + block[i:]
    return text[:start] + block + text[end:]


def edit_tactics(text):
    """The Gather action (the one named Gather) gets a rate and a typed range for each nomad."""
    m = re.search(r"<action>\s*<name[^>]*>Gather</name>.*?</action>", text, re.S)
    if m is None:
        sys.exit("apply_fix: a herd tactics file has no action named Gather; nothing changed")
    action = m.group(0)
    nl = "\r\n" if "\r\n" in action else "\n"
    add = ""
    for name in NOMADS:
        if not re.search(r"<rate type\s*=\s*['\"]%s['\"]" % name, action):
            add += f'\t\t<rate type="{name}">1.0</rate>{nl}'
        if not re.search(r"<typedmaxrange type\s*=\s*['\"]%s['\"]" % name, action):
            add += f'\t\t<typedmaxrange type="{name}">{DISTANCE}</typedmaxrange>{nl}'
    i = action.rindex("</action>")
    line_start = action.rfind("\n", 0, i) + 1
    action = action[:line_start] + add + action[line_start:]
    return text[:m.start()] + action + text[m.end():]


def apply(root):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        sys.exit(f"apply_fix: already applied ({backup} exists); run --restore first")
    for rel in ["data/protoy.xml"] + TACTICS:
        if not (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} is missing: is this a Wars of Liberty folder?")
    # Everything is made in memory and checked before anything is written.
    protoy, protoy_enc = read_text(root / "data/protoy.xml")
    for name in NOMADS:
        protoy = edit_nomad(protoy, name)
    tactics = {}
    for rel in TACTICS:
        text, enc = read_text(root / rel)
        tactics[rel] = (edit_tactics(text), enc)

    backup.mkdir()
    manifest = {"changed": []}
    for rel in CHANGED:
        if (root / rel).exists():
            (backup / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, backup / rel)
            manifest["changed"].append(rel)
    write_text(root / "data/protoy.xml", protoy, protoy_enc)
    for rel, (text, enc) in tactics.items():
        write_text(root / rel, text, enc)
    cfg = root / "Startup/wol.cfg"
    if cfg.exists():
        text, enc = read_text(cfg)
        if not re.search(r"(?im)^\s*herdWalkAwayFix\b", text):
            write_text(cfg, text.rstrip("\r\n") + "\r\nherdWalkAwayFix\r\n", enc)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(f"applied; backup in {backup}")


def restore(root):
    backup = root / BACKUP
    manifest_path = backup / "manifest.json"
    if not manifest_path.exists():
        sys.exit(f"apply_fix: no backup at {backup}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for rel in manifest["changed"]:
        shutil.copy2(backup / rel, root / rel)
    shutil.rmtree(backup)
    print("restored")


def check(root):
    text, _ = read_text(root / "data/protoy.xml")
    for name in NOMADS:
        span = unit_block(text, name)
        state = "missing" if span is None else ("applied" if MARK in text[span[0]:span[1]] else "not applied")
        print(f"{name}: {state}")
    for rel in TACTICS:
        body, _ = read_text(root / rel)
        if not re.search(r"<rate type=.Nomad.", body):
            print(f"{rel}: not applied")
            continue
        names = "|".join(NOMADS)
        ranges = sorted(set(re.findall(r"<typedmaxrange type\s*=\s*['\"](?:%s)['\"]>\s*([0-9.]+)" % names, body)))
        note = "" if ranges == [DISTANCE] else f" (this version uses {DISTANCE} m: run --restore, then apply again)"
        print(f"{rel}: applied, distance {', '.join(ranges) or '?'} m{note}")
    cfg = root / "Startup/wol.cfg"
    if cfg.exists():
        on = re.search(r"(?im)^\s*herdWalkAwayFix\b", read_text(cfg)[0])
        print(f"Startup/wol.cfg: herdWalkAwayFix {'on' if on else 'off'}")


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
