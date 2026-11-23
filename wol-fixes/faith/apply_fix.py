"""Faith as its own resource (request #101): villagers pray at their church or mosque and gather faith, the
engine's resource 4 ("SkillPoints"), with a praying animation; oil stays on resource 3. It needs the DLL key
`faithResource` (UHC.dll, in Startup\\wol.cfg), which cuts resource 4 from the home city's skill points: without
it the counter would start at the player's unspent home city points, and the faith gathered in a game would be
banked as free home city skill points.

    python apply_fix.py <WoL folder>              apply (a backup of every file it changes goes to
                                                  <WoL folder>\\faith-backup\\ first)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back, byte for byte (and their file
                                                  times), and delete the files it added
    python apply_fix.py <WoL folder> --check      say what is applied, change nothing
    python apply_fix.py <WoL folder> --no-ai      apply without the AI script change
    (a folder under steamapps is refused unless --force is given)

What it changes:
- data\\protoy.xml:
  - the worship buildings (WORSHIP below: Church, WOLChurchGreek, EGYchurchCARAVAN, TempleCaravan) hold faith:
    <InitialResource> and <CarryCapacity> of SkillPoints, <ResourceSubType>Fame (as the Congress, which gives
    XP), <GathererLimit> GATHERER_LIMIT, <Flag>UnlimitedSupply</Flag>, <UnitType>Resource</UnitType>;
  - every praying villager (VILLAGERS) gets a <ProtoAction> Pray with a rate of PRAY_RATE on each of them.
- data\\tactics\\*.tactics of those villagers: a Gather action Pray (<anim>Pray</anim>, rates on the four
  buildings), listed after Gather in every tactic that lists Gather.
- data\\techtreey.xml: Age0zulu turns the Pray action off for AFRICANvillager (the Zulu share the Ethiopians'
  villager; the Zulu do not pray).
- the villagers' anim files (ANIMS): three anims after each villager model's Idle: PrayIn, Pray, PrayOut, copies
  of that Idle (its models, attachments and hats) playing the new clips: design 1 (kneel, hands together) for the
  Christian civs, design 3 (bow to the ground) for the Islamic civs, the male or female clips after the model.
- art\\WoL\\units\\villagers\\settler\\pray\\*.gr2: the 12 clips (aoe3-blender-tools tools/make_pray.py).
- data\\stringtabley.xml and translations\\*\\stringtabley.xml: resource 4's name (28530,
  cStringResourceNameSkillPoints) becomes "Faith"; the Pray action's name (STRING_PRAY); in the English tables a
  line at the end of the four buildings' rollovers.
- AI4\\aiWoLMain.xs (unless --no-ai): the rule buyCards read its card budget through
  kbResourceGet(cResourceSkillPoints), which the engine gave as resource 4 plus the home city's unspent skill points;
  with faithResource it is resource 4 alone, so the rule adds kbGetHCLevel(cMyID) - 1 (an AI home city's points) and
  buys as many cards as before.
"""
import json
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
FILES = HERE / "files"
BACKUP = "faith-backup"

PRAY_RATE = 0.25          # faith per second per villager (the Maypole's XP rate); a value for JTMaston
GATHERER_LIMIT = 10       # villagers per building at once; a value for JTMaston
WORSHIP = ["Church", "WOLChurchGreek", "EGYchurchCARAVAN", "TempleCaravan"]
STRING_PRAY = 1010001
STRING_SKILLPOINTS = 28530
ROLLOVER_LINE = " Villagers pray here to gather faith."
ROLLOVER_IDS = {"Church": 444312, "WOLChurchGreek": 81534, "EGYchurchCARAVAN": 72336, "TempleCaravan": 2018053}
CLIPS = "WoL\\units\\villagers\\settler\\pray\\villager_{sex}_pray{design}_{part}"
KNEEL, BOW = 1, 3

# Villager protos that pray (their civs: README), and their tactics files.
VILLAGERS = [
    "Settler", "DutchSettler", "AfricanSlave", "AfricanSlaveBrit", "WOLPiedNoir", "Merchant", "WOLPioneer",
    "ConvictLabourer", "Mitayo", "WOLJornalero", "Roto", "WoLJuana", "WOLSevite", "Tlaquehual",
    "Villero", "WOLCholo", "WoLBaqueano", "Peasant", "RomaSlave", "AFRICANvillager", "SettlerME",
    "EGYPTIANvillager",
]
TACTICS = ["settler", "coureur", "convictLabourer", "jornalero", "roto", "juana",
           "wolVillagerKoygua", "peasant", "romaSlave"]
OFF_FOR = {"Age0zulu": ["AFRICANvillager"]}

# Anim file -> design, or a function of the submodel name (None: that model does not pray).


def settler_models(name):
    low = name.lower()
    if low.startswith(("we_", "ee_", "med_")):
        return KNEEL
    if low.startswith("ottoman_"):
        return BOW
    return None


ANIMS = {
    "WoL/units/villagers/settler/villager.xml": settler_models,          # Europeans; Ottomans (their models)
    "WoL/units/villagers/egyptian_villager/egyptian_villager.xml": BOW,   # Egyptians, Afghans, Persians, Saudis, Uzbeks
    "War of the Triple Alliance/Units/Delta/Balkans/villagers/bulgarian.xml": KNEEL,
    "War of the Triple Alliance/Units/Delta/Zulu/villager/villager.xml": KNEEL,   # Ethiopians (Zulu: off)
    "War of the Triple Alliance/Units/Delta/Italians/Villagers/merchant.xml": KNEEL,
    "War of the Triple Alliance/units/african slave/africanslave.xml": KNEEL,
    "War of the Triple Alliance/Units/convict_labourer.xml": KNEEL,
    "WoL/units/villagers/sansculotte/sansculotte.xml": KNEEL,
    "WoL/units/villagers/pioneer/pioneer.xml": KNEEL,
    "WoL/units/villagers/pongo/Pongo.xml": KNEEL,
    "WoL/units/villagers/Centralamericans/Jornalero.xml": KNEEL,
    "wol/Units/villagers/Roto/roto.xml": KNEEL,
    "WoL/units/villagers/juana/juana.xml": KNEEL,
    "WoL/units/villagers/sevite/sevite.xml": KNEEL,
    "WoL/Units/Villagers/Tlaquehual/Tlaquehual.xml": KNEEL,
    "WoL/units/villagers/koygua/koygua.xml": KNEEL,
    "WoL/units/villagers/cholo/cholo.xml": KNEEL,
    "Wol/Units/Villagers/Baqueano/Baqueano.xml": KNEEL,
    "WoL/units/villagers/rom/rom.xml": KNEEL,
}

AI_FILE = "AI4/aiWoLMain.xs"
# kbResourceGet(cResourceSkillPoints) was resource 4 plus the home city's unspent skill points (level - 1 for an AI's
# home city: 9 at level 10, measured); with faithResource it is resource 4 alone, so buyCards adds that part back
# and sees what it saw before (the AI's card budget is still resource 4, set to level + 15 at the start).
AI_OLD = "kbResourceGet(cResourceSkillPoints)"
AI_NEW = "(kbResourceGet(cResourceSkillPoints) + kbGetHCLevel(cMyID) - 1)"
AI_MARK = "kbGetHCLevel(cMyID) - 1)"


# ---------------------------------------------------------------------------------------------------- text files

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


def find_ci(root, rel):
    """The file at rel below root, matching each part without case (the game's file system is not case
    sensitive; WoL's paths are written in several cases)."""
    cur = root
    for part in rel.replace("\\", "/").split("/"):
        if not cur.is_dir():
            return None
        names = {p.name.lower(): p for p in cur.iterdir()}
        if part.lower() not in names:
            return None
        cur = names[part.lower()]
    return cur


def nl(text):
    return "\r\n" if "\r\n" in text else "\n"


# ---------------------------------------------------------------------------------------------------- protoy.xml

def unit_span(text, name):
    m = re.search(r'<Unit\b[^>]*\bname="%s"[^>]*>' % re.escape(name), text)
    if m is None:
        sys.exit(f"apply_fix: protoy.xml has no unit {name}")
    return m.start(), text.index("</Unit>", m.end())


def indent_of(text, pos):
    line = text[text.rindex("\n", 0, pos) + 1:pos]
    return re.match(r"[ \t]*", line).group(0)


def insert_before_first(body, tag, lines, eol):
    """lines inserted before the first <tag> of a unit body (or before its end), at that tag's indentation."""
    m = re.search(r"\n([ \t]*)<%s\b" % tag, body)
    if m is None:
        m = re.search(r"\n([ \t]*)<(UnitType|Flag|ProtoAction)\b", body)
    if m is None:
        return body + "".join(f"\t\t{x}{eol}" for x in lines)
    ind = m.group(1)
    add = "".join(f"{ind}{x}{eol}" for x in lines)
    return body[:m.start() + 1] + add + body[m.start() + 1:]


def edit_building(body, eol):
    add = []
    if 'resourcetype="SkillPoints">' not in body or "<InitialResource resourcetype=\"SkillPoints\"" not in body:
        add.append('<InitialResource resourcetype="SkillPoints">999.0000</InitialResource>')
    if '<CarryCapacity resourcetype="SkillPoints">' not in body:
        add.append('<CarryCapacity resourcetype="SkillPoints">100.0000</CarryCapacity>')
    if "<ResourceSubType>" not in body:
        add.append("<ResourceSubType>Fame</ResourceSubType>")
    if "<GathererLimit>" not in body:
        add.append(f"<GathererLimit>{GATHERER_LIMIT}</GathererLimit>")
    if add:
        body = insert_before_first(body, "UnitType", add, eol)
    if "<UnitType>Resource</UnitType>" not in body:
        body = insert_before_first(body, "UnitType", ["<UnitType>Resource</UnitType>"], eol)
    if "<Flag>UnlimitedSupply</Flag>" not in body:
        body = insert_before_first(body, "Flag", ["<Flag>UnlimitedSupply</Flag>"], eol)
    return body


def pray_protoaction(ind, eol):
    rates = "".join(f'{ind}\t<Rate type="{b}">{PRAY_RATE:.6f}</Rate>{eol}' for b in WORSHIP)
    return f"{ind}<ProtoAction>{eol}{ind}\t<Name>Pray</Name>{eol}{rates}{ind}</ProtoAction>{eol}"


def edit_villager(body, eol):
    if re.search(r"<Name>Pray</Name>", body):
        return body
    m = re.search(r"\n([ \t]*)<ProtoAction>", body)
    if m is None:
        m = re.search(r"\n([ \t]*)</Unit>", body + "\n\t</Unit>")
    ind = m.group(1)
    return body[:m.start() + 1] + pray_protoaction(ind, eol) + body[m.start() + 1:]


def edit_protoy(text):
    eol = nl(text)
    for names, fn in ((WORSHIP, edit_building), (VILLAGERS, edit_villager)):
        for name in names:
            s, e = unit_span(text, name)
            text = text[:s] + fn(text[s:e], eol) + text[e:]
    return text


# ---------------------------------------------------------------------------------------------------- tactics

def pray_action(eol):
    rates = "".join(f'\t\t<rate type="{b}">1.0</rate>{eol}' for b in WORSHIP)
    return (f"\t<action>{eol}\t\t<name stringid=\"{STRING_PRAY}\">Pray</name>{eol}\t\t<type>Gather</type>{eol}"
            f"\t\t<anim>Pray</anim>{eol}\t\t<maxrange>1.0</maxrange>{eol}{rates}\t</action>{eol}")


def edit_tactics(text):
    if re.search(r">\s*Pray\s*</name>", text):
        return text
    eol = nl(text)
    m = re.search(r"\n[ \t]*<tactic>", text)
    if m is None:
        sys.exit("apply_fix: a tactics file without <tactic>")
    text = text[:m.start() + 1] + pray_action(eol) + text[m.start() + 1:]

    def one(mm):
        return mm.group(0) + f"{eol}{mm.group(1)}<action>Pray</action>"
    return re.sub(r"([ \t]*)<action>Gather</action>", one, text)


# ---------------------------------------------------------------------------------------------------- techtreey

def edit_techtree(text):
    eol = nl(text)
    for tech, protos in OFF_FOR.items():
        m = re.search(r"<Tech name\s*=\s*'%s'[^>]*>" % re.escape(tech), text)
        if m is None:
            sys.exit(f"apply_fix: techtreey.xml has no tech {tech}")
        end = text.index("</Tech>", m.end())
        body = text[m.end():end]
        if "action ='Pray'" in body:
            continue
        em = re.search(r"\n([ \t]*)<Effect\b", body)
        if em is None:
            sys.exit(f"apply_fix: tech {tech} has no effects")
        ind = em.group(1)
        add = "".join(f"{ind}<Effect type ='Data' action ='Pray' amount ='0.00' subtype ='ActionEnable' "
                      f"relativity ='Absolute'>{eol}{ind}\t<Target type ='ProtoUnit'>{p}</Target></Effect>{eol}"
                      for p in protos)
        pos = m.end() + em.start() + 1
        text = text[:pos] + add + text[pos:]
    return text


# ---------------------------------------------------------------------------------------------------- anim files

TAG = re.compile(r"<(/?)([A-Za-z_][\w]*)([^>]*?)(/?)>|<!--.*?-->|<\?.*?\?>", re.S)


def elements(text):
    """(name, start, end, parent index, first text) of every element, in document order."""
    out, stack = [], []
    for m in TAG.finditer(text):
        if m.group(2) is None:
            continue
        closing, name, selfclose = m.group(1) == "/", m.group(2), m.group(4) == "/"
        if closing:
            while stack:
                i = stack.pop()
                if out[i][0] == name:
                    out[i][2] = m.end()
                    break
            continue
        nxt = text.find("<", m.end())
        first = text[m.end():nxt].strip() if nxt >= 0 else ""
        out.append([name, m.start(), m.end() if selfclose else None, stack[-1] if stack else None, first])
        if not selfclose:
            stack.append(len(out) - 1)
    return out


def sex_of(idle_block, model_name):
    files = " ".join(re.findall(r"<file>([^<]*)</file>", idle_block)).lower()
    if "female" in files or "female" in model_name.lower():
        return "female"
    if re.search(r"(_f(\d|i+)?\b|_f_|\\f\d|woman|girl)", files + " " + model_name.lower()):
        return "female"
    return "male"


def pray_blocks(idle, sex, design, indent, eol):
    out = ""
    for part, name in (("in", "PrayIn"), ("loop", "Pray"), ("out", "PrayOut")):
        clip = CLIPS.format(sex=sex, design=design, part=part)

        def granny(m, clip=clip):
            return re.sub(r"<file>[^<]*</file>", lambda _m: f"<file>{clip}</file>", m.group(0))
        b = re.sub(r'<assetreference type="GrannyAnim">.*?</assetreference>', granny, idle, flags=re.S)
        b = re.sub(r"<tag\b[^>]*>[^<]*</tag>\s*", "", b)
        # No tool or weapon in the hands while praying (the Balkan peasant's pitchfork, a gun): only the attached
        # clothes (hats, hoods, hair) stay.
        b = re.sub(r'<attach a="(?![^"]*(?:hat|hood|hair|braid|head|cap|skirt))[^"]*"[^>]*/>\s*', "", b, flags=re.I)
        b = re.sub(r"(<anim>\s*)Idle", lambda m: m.group(1) + name, b, count=1)
        out += eol + indent + b
    return out


def edit_anim(text, rule):
    """text with PrayIn, Pray and PrayOut after each praying model's Idle; (new text, report lines)."""
    if re.search(r"<anim>\s*Pray\s*<", text):
        return text, ["already has Pray"]
    eol = nl(text)
    els = elements(text)
    containers = [i for i, e in enumerate(els) if e[0] in ("submodel", "animfile")]
    inserts, report = [], []
    for ci in containers:
        c = els[ci]
        idle = next((e for e in els if e[3] == ci and e[0] == "anim" and e[4] == "Idle"), None)
        fallback = False
        if idle is None:
            # No Idle of its own (WOLPiedNoir's file): the Cheer, with the model component that has no weapon.
            idle = next((e for e in els if e[3] == ci and e[0] == "anim" and e[4] == "Cheer"), None)
            fallback = True
        if idle is None:
            continue
        model = c[4] if c[0] == "submodel" else "(file)"
        design = rule(model) if callable(rule) else rule
        if design is None:
            report.append(f"{model}: no prayer")
            continue
        block = text[idle[1]:idle[2]]
        if fallback:
            block = re.sub(r"(<anim>\s*)Cheer", lambda m: m.group(1) + "Idle", block, count=1)
            if re.search(r"<component>\s*ModelCompNoWeapon\s", text):
                block = re.sub(r"<component>ModelComp</component>", "<component>ModelCompNoWeapon</component>", block)
        sex = sex_of(block, model)
        indent = indent_of(text, idle[1])
        inserts.append((idle[2], pray_blocks(block, sex, design, indent, eol)))
        report.append(f"{model}: design {design}, {sex}" + (" (from its Cheer)" if fallback else ""))
    for pos, add in sorted(inserts, reverse=True):
        text = text[:pos] + add + text[pos:]
    return text, report


# ---------------------------------------------------------------------------------------------------- strings, AI

def string_tables(root):
    out = [root / "data/stringtabley.xml"]
    out += sorted((root / "translations").glob("*/stringtabley.xml")) if (root / "translations").is_dir() else []
    return [p for p in out if p.exists()]


def edit_strings(text):
    # Every table says <Language name="English">; the Spanish one is told by its words (18900 is "Food").
    english = re.search(r"<String _locID\s*=\s*(['\"])18900\1[^>]*>Food</String>", text) is not None

    def setstr(t, sid, value):
        pat = re.compile(r"(<String _locID\s*=\s*(['\"])%d\2[^>]*>)(.*?)(</String>)" % sid, re.S)
        if pat.search(t):
            return pat.sub(lambda m: m.group(1) + value(m.group(3)) + m.group(4), t, count=1), True
        return t, False
    text, _ = setstr(text, STRING_SKILLPOINTS, lambda _old: "Faith")
    if f"_locID='{STRING_PRAY}'" not in text and f'_locID="{STRING_PRAY}"' not in text:
        marker = text.find("<!-- DON'T WRITE STRINGS DOWN HERE -->")
        i = text.rfind("\n", 0, marker) + 1 if marker >= 0 else text.rindex("\t</Language>")
        text = text[:i] + f"\t\t<String _locID='{STRING_PRAY}'>Pray</String>{nl(text)}" + text[i:]
    if english:
        for sid in ROLLOVER_IDS.values():
            text, _ = setstr(text, sid, lambda old: old if old.endswith(ROLLOVER_LINE) else old + ROLLOVER_LINE)
    return text


def edit_ai(text):
    if AI_MARK in text:
        return text
    i = text.find("rule buyCards")
    if i < 0 or AI_OLD not in text[i:]:
        sys.exit(f"apply_fix: {AI_FILE} has no rule buyCards reading {AI_OLD}; nothing changed")
    j = text.find("\nrule ", i + 1)
    j = len(text) if j < 0 else j
    return text[:i] + text[i:j].replace(AI_OLD, AI_NEW) + text[j:]


# ---------------------------------------------------------------------------------------------------- driver

def plan(root, with_ai=True):
    """[(relative path, new text, encoding)] of every changed file, and the report."""
    changes, report = [], []
    p = root / "data/protoy.xml"
    t, enc = read_text(p)
    changes.append(("data/protoy.xml", edit_protoy(t), enc))
    for name in TACTICS:
        f = find_ci(root, f"data/tactics/{name}.tactics")
        if f is None:
            sys.exit(f"apply_fix: data\\tactics\\{name}.tactics is missing")
        if (f.parent / (f.name + ".xmb")).exists():
            sys.exit(f"apply_fix: {f}.xmb exists: the game would read it instead of the edited tactics")
        t, enc = read_text(f)
        changes.append((f.relative_to(root).as_posix(), edit_tactics(t), enc))
    t, enc = read_text(root / "data/techtreey.xml")
    changes.append(("data/techtreey.xml", edit_techtree(t), enc))
    for rel, rule in ANIMS.items():
        f = find_ci(root, "art/" + rel)
        if f is None:
            sys.exit(f"apply_fix: art\\{rel} is missing")
        t, enc = read_text(f)
        new, rep = edit_anim(t, rule)
        changes.append((f.relative_to(root).as_posix(), new, enc))
        report.append(f"{rel}: " + "; ".join(rep))
    for f in string_tables(root):
        t, enc = read_text(f)
        changes.append((f.relative_to(root).as_posix(), edit_strings(t), enc))
    if with_ai:
        t, enc = read_text(root / AI_FILE)
        changes.append((AI_FILE, edit_ai(t), enc))
    return changes, report


def clip_files():
    return [(src, src.relative_to(FILES).as_posix()) for src in sorted((FILES / "art").rglob("*.gr2"))]


def apply(root, with_ai=True):
    backup = root / BACKUP
    if (backup / "manifest.json").exists():
        sys.exit(f"apply_fix: already applied ({backup} exists); run --restore first")
    if not (root / "data/protoy.xml").exists() or not (root / "art").is_dir():
        sys.exit(f"apply_fix: {root} has no data\\protoy.xml or art folder: is this a Wars of Liberty folder?")
    for x in ("data/protoy.xml.xmb", "data/techtreey.xml.xmb"):
        if (root / x).exists():
            sys.exit(f"apply_fix: {root / x} exists: the game would read it instead of the edited XML")
    for _src, rel in clip_files():
        if (root / rel).exists():
            sys.exit(f"apply_fix: {root / rel} exists already; nothing changed")
    changes, report = plan(root, with_ai)
    backup.mkdir()
    manifest = {"changed": [], "added": [], "ai": with_ai}
    for rel, _t, _e in changes:
        dst = backup / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / rel, dst)
        manifest["changed"].append(rel)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    for rel, text, enc in changes:
        write_text(root / rel, text, enc)
    for src, rel in clip_files():
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, root / rel)
        manifest["added"].append(rel)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    for line in report:
        print(line)
    print(f"applied: {len(changes)} files changed, {len(manifest['added'])} clips added"
          + ("" if with_ai else " (no AI change)") + f"; backup in {backup}")


def restore(root):
    backup = root / BACKUP
    manifest_path = backup / "manifest.json"
    if not manifest_path.exists():
        sys.exit(f"apply_fix: no backup at {backup}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for rel in manifest["added"]:
        (root / rel).unlink(missing_ok=True)
    folder = find_ci(root, "art/WoL/units/villagers/settler/pray")
    if folder is not None and not any(folder.iterdir()):
        folder.rmdir()
    for rel in manifest["changed"]:
        shutil.copy2(backup / rel, root / rel)
    shutil.rmtree(backup)
    print(f"restored: {len(manifest['changed'])} files put back, {len(manifest['added'])} clips removed")


def check(root):
    text, _ = read_text(root / "data/protoy.xml")
    for name in WORSHIP:
        s, e = unit_span(text, name)
        print(f"{name}: {'holds faith' if 'resourcetype=\"SkillPoints\"' in text[s:e] else 'no faith'}")
    praying = [n for n in VILLAGERS if "<Name>Pray</Name>" in text[slice(*unit_span(text, n))]]
    print(f"villagers with Pray: {len(praying)} of {len(VILLAGERS)}")
    for rel in ANIMS:
        f = find_ci(root, "art/" + rel)
        t = read_text(f)[0] if f else ""
        print(f"art\\{rel}: {len(re.findall(r'<anim>\s*Pray\s*<', t))} Pray anims")
    present = [rel for _s, rel in clip_files() if (root / rel).exists()]
    print(f"clips: {len(present)} of {len(clip_files())} present")
    ai = read_text(root / AI_FILE)[0]
    print(f"AI buyCards: {'changed' if AI_MARK in ai else 'stock'}")
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
        apply(root, "--no-ai" not in sys.argv)


if __name__ == "__main__":
    main()
