"""Cross-check a campaign's definition and scenarios against a game folder's data. Read-only.

Usage:
    python -I tools/campaigncheck.py <game folder> [--campaign <xml> ...] [--scn <file> ...] [--all]

<game folder> is a test copy (e.g. C:\\AoE3-UHC-WoLReal3). Without --campaign it reads the campaign
definitions the exe and the main menu name: Campaign\\Wonders\\ChinaIndiaJapan.xml (the path the
menu passes to startCampaign) and, when present, the second copy Campaign\\chinaindiajapan.xml.
--scn checks the scenarios named (alone, without the definitions, unless --campaign is given);
--all prints every reference, not only the misses.

What it checks (what the game does with each is in docs/wol-campaign.md, "How a scenario loads"):
- the campaign XML: every string ID (DisplayNameStringID, RolloverStringID, HCNote*, LoadTextID)
  against data\\stringtabley.xml, and every node's Filename against Campaign\\<name>.age3Yscn;
- each scenario, decompressed in memory ("l33t", size, zlib stream, CRC-32):
  * the civ table ("SH" records, one per civ with its default deck): a civ civs.xml no longer has
    makes the game refuse the whole scenario ("Scenario: ... failed to load."): MISS;
  * each player's civ ("BP" records): stored as a number, the civ's position in civs.xml when the
    scenario was saved, and NOT re-mapped at load. The civ that number is now, and the civs whose
    <homecityfilename> is the player's home city file, so a player whose civ moved shows up: MISS;
  * the name tables saved with it (protos, unit types, techs): the game maps saved IDs to the
    current ones by these names, so only a name the data lost matters;
  * the protos of the placed units (the UN chunks), through the saved proto table;
  * the home city files of the players (data\\, Campaign\\, Campaign\\Wonders\\);
  * every trigger effect and condition: its name against trigger3\\typetest.xml (a name missing
    there still runs, since the scenario keeps its own command text, but the editor cannot show
    it), and its parameters by type: protounit / unittype against protoy, tech through the saved
    tech table (the game re-maps a tech parameter by name: a MISS only when the name is gone),
    stringid against the string table, camtrack against the tracks saved in the scenario.
"""
import argparse
import re
import struct
import sys
import zlib
from collections import Counter, defaultdict
from pathlib import Path

DEFAULT_CAMPAIGNS = [r"Campaign\Wonders\ChinaIndiaJapan.xml", r"Campaign\chinaindiajapan.xml"]


# ---------------------------------------------------------------- the game folder's data

def read_text(path):
    raw = path.read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16")
    return raw.decode("utf-8", errors="replace")


def strip_comments(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


class GameData:
    def __init__(self, root):
        self.root = root
        data = root / "data"
        proto = strip_comments(read_text(data / "protoy.xml"))
        self.protos = {n.lower() for n in re.findall(r"<Unit\b[^>]*\bname\s*=\s*['\"]([^'\"]+)['\"]", proto)}
        self.unittypes = {t.strip().lower() for t in re.findall(r"<UnitType>([^<]+)</UnitType>", proto)}
        tech = strip_comments(read_text(data / "techtreey.xml"))
        names = re.findall(r"<Tech\s+name\s*=\s*['\"]([^'\"]+)['\"]", tech)
        self.tech_index = {}
        for i, n in enumerate(names):
            self.tech_index.setdefault(n.lower(), i)
        self.tech_names = names
        civs = strip_comments(read_text(data / "civs.xml"))
        # Civ IDs: 0 is Mother Nature's, then the <civ> entries in file order from 1 (seen in game:
        # a player stored as civ 30 shows the flag of the 30th entry).
        self.civ_list = []
        self.civ_homecity = {}
        for block in re.findall(r"<civ>(.*?)</civ>", civs, flags=re.S | re.I):
            n = re.search(r"<name>([^<]+)</name>", block, flags=re.I)
            hc = re.search(r"<homecityfilename>([^<]+)</homecityfilename>", block, flags=re.I)
            name = n.group(1).strip() if n else "?"
            self.civ_list.append(name)
            if hc:
                self.civ_homecity[name] = hc.group(1).strip()
        self.civs = {n.lower() for n in self.civ_list}
        strings = read_text(data / "stringtabley.xml")
        self.strings = {int(i) for i in re.findall(r"_locID\s*=\s*['\"](\d+)['\"]", strings)}
        tt = root / "trigger3" / "typetest.xml"
        self.trigger_types = {}  # (kind, name lower) -> {param lower: vartype}
        if tt.exists():
            text = strip_comments(read_text(tt))
            for kind, name, body in re.findall(r"<(Effect|Condition)\s+name\s*=\s*\"([^\"]+)\"[^>]*>(.*?)</\1>", text, flags=re.S):
                params = {p.lower(): v.lower() for p, v in re.findall(
                    r"<Param\s+name\s*=\s*\"([^\"]+)\"[^>]*?[vV]ar[tT]ype\s*=\s*\"([^\"]+)\"", body)}
                self.trigger_types[(kind.lower(), name.lower())] = params
        self.hc_dirs = [data, root / "Campaign", root / "Campaign" / "Wonders"]
        self.camtracks = root / "CAMERATRACKS"

    def civ_name(self, civ_id):
        if civ_id == 0:
            return "(Mother Nature)"
        return self.civ_list[civ_id - 1] if 1 <= civ_id <= len(self.civ_list) else f"#{civ_id}"

    def civs_with_homecity(self, hc_file):
        return [c for c, f in self.civ_homecity.items() if f.lower() == hc_file.lower()]

    def homecity_where(self, name):
        for d in self.hc_dirs:
            if not d.is_dir():
                continue
            for f in d.iterdir():
                if f.name.lower() == name.lower():
                    return f
        return None


# ---------------------------------------------------------------- scenarios

def decompress(path):
    blob = path.read_bytes()
    if blob[:4] != b"l33t":
        raise ValueError(f"{path.name}: not an l33t scenario (header {blob[:4]!r})")
    size = struct.unpack_from("<I", blob, 4)[0]
    raw = zlib.decompress(blob[8:])
    if len(raw) != size:
        print(f"  note: {path.name}: header says {size} bytes, zlib gave {len(raw)}")
    return raw


def ascii_table_at(raw, p, count):
    out = []
    for _ in range(count):
        n = struct.unpack_from("<I", raw, p)[0]
        s = raw[p + 4:p + 4 + n]
        if n < 1 or n > 200 or s[-1:] != b"\0":
            return None, p
        out.append(s[:-1].decode("latin-1"))
        p += 4 + n
    return out, p


def name_tables(raw):
    """The editor's saved name tables, in file order: chunk tag ("PT" protos, then "TM" unit types,
    techs and powers), size, 0, count, then count length-prefixed names."""
    tables = []
    p = 0
    while True:
        m = re.compile(rb"(PT|TM)(....)\x00\x00\x00\x00(....)", re.S).search(raw, p)
        if not m:
            break
        size = struct.unpack_from("<I", m.group(2))[0]
        count = struct.unpack_from("<I", m.group(3))[0]
        names = None
        if 30 <= count <= 30000 and count * 5 <= size <= len(raw):
            names, end = ascii_table_at(raw, m.end(), count)
        if names:
            tables.append((m.group(1).decode(), m.start(), names))
            p = end
        else:
            p = m.start() + 1
    return tables


def utf16_strings(raw):
    return [(m.start(), m.group().decode("utf-16le"))
            for m in re.finditer(rb"(?:[\x20-\xff]\x00){2,}", raw)]


def civ_records(raw):
    """The civ table: (offset, name) of each SH record (tag, size, version 2, UTF-16 name)."""
    out = []
    for m in re.finditer(rb"SH(....)\x02\x00\x00\x00(....)", raw, flags=re.S):
        size = struct.unpack_from("<I", m.group(1))[0]
        n = struct.unpack_from("<I", m.group(2))[0]
        if 100 < size < 0x100000 and 0 < n < 64:
            out.append((m.end(), raw[m.end():m.end() + 2 * n].decode("utf-16le", errors="replace")))
    return out


def player_records(raw, strs):
    """(name, civ ID, home city file) of each player: a BP record (tag, size, version, player
    number, UTF-16 name), whose civ ID sits 17 bytes after the name; the home city file is the next
    homecity*.xml string. Seen in the WoL scenarios saved in 2022; older layouts give no players."""
    out = []
    for m in re.finditer(rb"BP(....)(....)(....)(....)", raw, flags=re.S):
        ver = struct.unpack_from("<I", m.group(2))[0]
        player = struct.unpack_from("<I", m.group(3))[0]
        n = struct.unpack_from("<I", m.group(4))[0]
        if not (0 < n < 64 and ver < 1000 and player < 16):
            continue
        end = m.end() + 2 * n
        if raw[end:end + 2] != b"\0\0" or raw[end + 4:end + 8] != b"\xff\xff\xff\xff":
            continue
        name = raw[m.end():end].decode("utf-16le", errors="replace")
        civ_id = struct.unpack_from("<i", raw, end + 17)[0]
        hc = next((s for off, s in strs if off > end and re.fullmatch(r"(?i)homecity\w*\.xml", s)), None)
        out.append((name, civ_id, hc))
    return out


def unit_protos(raw):
    """(proto index, count) of the placed units: UN chunks hold the unit's name, then its proto index twice."""
    c = Counter()
    for m in re.finditer(rb"UN", raw):
        p = m.start()
        if p + 18 > len(raw):
            continue
        n, l = struct.unpack_from("<II", raw, p + 2)
        if not (4 <= n <= 200 and l == n - 4):
            continue
        q = p + 10 + l
        a, b = struct.unpack_from("<II", raw, q)
        if a == b:
            c[a] += 1
    return c


def triggers(raw):
    """Trigger effects and conditions: (offset, name, [(param, display, type, value)])."""
    out = []
    end = len(raw) - 16
    p = 0
    lenok = lambda n: 2 <= n <= 120  # noqa: E731
    while p < end:
        n1 = struct.unpack_from("<I", raw, p)[0]
        if not lenok(n1):
            p += 1
            continue
        s1 = raw[p + 4:p + 4 + n1]
        if s1[-1:] != b"\0" or not all(32 <= c < 127 for c in s1[:-1]):
            p += 1
            continue
        q = p + 4 + n1
        if q + 8 > len(raw):
            break
        n2 = struct.unpack_from("<I", raw, q)[0]
        s2 = raw[q + 4:q + 4 + n2]
        if not lenok(n2) or s2 != s1:
            p += 1
            continue
        q += 4 + n2
        cnt = struct.unpack_from("<I", raw, q)[0]
        q += 4
        if cnt > 40:
            p += 1
            continue
        params = []
        ok = True
        for _ in range(cnt):
            r = parse_param(raw, q)
            if r is None:
                ok = False
                break
            params.append(r[0])
            q = r[1]
        if ok and (cnt or raw[q:q + 1]):
            out.append((p, s1[:-1].decode(), params))
            p = q
        else:
            p += 1
    return out


def parse_param(raw, q):
    try:
        ver, n = struct.unpack_from("<II", raw, q)
        if ver > 16 or not (2 <= n <= 80):
            return None
        name = raw[q + 8:q + 8 + n]
        if name[-1:] != b"\0":
            return None
        q += 8 + n
        m = struct.unpack_from("<I", raw, q)[0]
        if not (1 <= m <= 200):
            return None
        disp = raw[q + 4:q + 4 + m]
        if disp[-1:] != b"\0":
            return None
        q += 4 + m
        vtype, one, ln = struct.unpack_from("<III", raw, q)
        if vtype > 64 or one > 16 or ln > 20000:
            return None
        len_at = q + 8  # the value's length (UTF-16 units), then the value
        q += 12
        value = raw[q:q + 2 * ln].decode("utf-16le", errors="replace")
        q += 2 * ln
        return (name[:-1].decode("latin-1"), disp[:-1].decode("latin-1"), vtype, value, len_at), q
    except struct.error:
        return None


# ---------------------------------------------------------------- report

class Report:
    def __init__(self, show_all):
        self.show_all = show_all
        self.misses = 0

    def miss(self, text):
        self.misses += 1
        print(f"  MISS {text}")

    def ok(self, text):
        if self.show_all:
            print(f"  ok   {text}")

    def note(self, text):
        print(f"  note {text}")


def check_campaign(gd, xml_path, rep):
    print(f"\n== campaign {xml_path}")
    text = read_text(xml_path)
    body = strip_comments(text)
    for tag in ("DisplayNameStringID", "RolloverStringID", "HCNoteTitle", "HCNoteText",
                "HCNote2Title", "HCNote2Text", "LoadTextID"):
        for v in re.findall(rf"<{tag}>\s*(-?\d+)\s*</{tag}>", body):
            (rep.ok if int(v) in gd.strings else rep.miss)(f"{tag} {v} {'in' if int(v) in gd.strings else 'not in'} the string table")
    nodes = re.findall(r"<CampaignNode>(.*?)</CampaignNode>", body, flags=re.S)
    files = []
    for i, node in enumerate(nodes):
        fn = re.search(r"<Filename>([^<]+)</Filename>", node)
        cine = re.search(r"<Cinematic>([^<]+)</Cinematic>", node)
        img = re.search(r"<LoadImage>([^<]+)</LoadImage>", node)
        name = fn[1].strip() if fn else "?"
        scn = gd.root / "Campaign" / (name + ".age3Yscn")
        found = scn.exists()
        (rep.ok if found else rep.miss)(f"node {i}: {name} -> {scn.relative_to(gd.root)} {'exists' if found else 'MISSING'}"
                                        f" (Cinematic {cine[1] if cine else '-'}, LoadImage {img[1] if img else '-'})")
        if found:
            files.append(scn)
    return files


def check_scenario(gd, path, rep):
    print(f"\n== scenario {path.relative_to(gd.root) if path.is_relative_to(gd.root) else path}")
    raw = decompress(path)
    strs = utf16_strings(raw)
    if strs:
        rep.note(f"saved by: {strs[0][1]}")
    lists = name_tables(raw)
    # The order seen in the WoL and TAD scenarios: protos (PT), protos + abstract types, techs, powers (TM).
    proto_t = lists[0][2] if len(lists) > 0 else []
    tech_t = lists[2][2] if len(lists) > 2 else []
    first_table = lists[0][1] if lists else len(raw)
    rep.note("saved tables: " + ", ".join(f"{k}@{hex(o)}={len(v)}" for k, o, v in lists))
    rep.note(f"data now: {len(gd.protos)} protos, {len(gd.tech_names)} techs (saved: {len(proto_t)} protos, {len(tech_t)} techs)")

    # Placed units, through the saved proto table.
    used = unit_protos(raw)
    lost = Counter()
    for idx, n in used.items():
        name = proto_t[idx] if idx < len(proto_t) else f"#{idx}"
        if name.lower() not in gd.protos:
            lost[name] += n
    rep.note(f"placed units: {sum(used.values())} of {len(used)} protos")
    for name, n in sorted(lost.items()):
        rep.miss(f"placed unit proto {name} x{n}: not in protoy.xml")
    gone = [n for n in proto_t if n.lower() not in gd.protos]
    if gone:
        rep.note(f"{len(gone)} names of the saved proto table are not in protoy.xml (only the placed ones above matter): "
                 + ", ".join(gone[:25]) + (" ..." if len(gone) > 25 else ""))
    gone_t = [n for n in tech_t if n.lower() not in gd.tech_index]
    if gone_t:
        rep.note(f"{len(gone_t)} names of the saved tech table are not in techtreey.xml: "
                 + ", ".join(gone_t[:25]) + (" ..." if len(gone_t) > 25 else ""))
    shifted_table = sum(1 for i, n in enumerate(tech_t) if gd.tech_index.get(n.lower(), i) != i)
    rep.note(f"saved tech table vs techtreey.xml: {shifted_table} of {len(tech_t)} techs have another index now "
             "(harmless: the game re-maps them by name)")

    # The civ table: one SH record per civ (name, home city file, default deck). A name civs.xml
    # lacks fails the whole load (FUN_0085BA5E); tools/scnfix.py renames such a record.
    table = civ_records(raw)
    lost_civs = [n for _, n in table if n.lower() not in gd.civs]
    rep.note(f"civ table: {len(table)} civs")
    for n in lost_civs:
        rep.miss(f"civ table: {n} is not in civs.xml: the game refuses to load the scenario")
    deck_cards = {s for off, s in strs if off < first_table and re.fullmatch(r"(?i)\w*HC\w+", s)}
    lost_cards = sorted(c for c in deck_cards if c.lower() not in gd.tech_index)
    rep.note(f"default deck cards: {len(deck_cards)}, {len(lost_cards)} not in techtreey.xml (decks of civs no player has)")

    # The players: name, civ (a number, not re-mapped), home city file.
    for name, civ_id, hc in player_records(raw, strs):
        now = gd.civ_name(civ_id)
        where = gd.homecity_where(hc) if hc else None
        if hc and not where:
            rep.miss(f"player '{name}': home city {hc} not found in data, Campaign or Campaign\\Wonders")
        if civ_id == 0 or not hc:
            rep.ok(f"player '{name}': civ {civ_id} {now}, home city {hc}")
            continue
        fits = gd.civs_with_homecity(hc)
        if re.fullmatch(r"Player \d+", name):
            rep.note(f"player '{name}' (an unused slot): civ {civ_id} = {now}, home city {hc}")
        elif fits and now not in fits:
            rep.miss(f"player '{name}': civ {civ_id} is {now} now, but its home city {hc} belongs to "
                     f"{'/'.join(fits)} (civ IDs are stored as numbers; civs.xml moved)")
        else:
            rep.note(f"player '{name}': civ {civ_id} = {now}, home city {hc}")

    # Triggers.
    trig = triggers(raw)
    kinds = Counter()
    unknown = Counter()
    by_type = defaultdict(Counter)
    for off, name, params in trig:
        key_e, key_c = ("effect", name.lower()), ("condition", name.lower())
        tdef = gd.trigger_types.get(key_e) or gd.trigger_types.get(key_c)
        if tdef is None:
            unknown[name] += 1
        kinds[name] += 1
        for pname, disp, vtype, value, _ in params:
            vt = (tdef or {}).get(pname.lower(), f"#{vtype}")
            by_type[vt][value] += 1
            v = value.strip()
            if vt in ("protounit",):
                if v and v.lower() not in gd.protos:
                    rep.miss(f"@{hex(off)} {name}.{pname} = {v}: proto not in protoy.xml")
            elif vt == "unittype":
                if v and v.lower() not in gd.protos and v.lower() not in gd.unittypes:
                    rep.miss(f"@{hex(off)} {name}.{pname} = {v}: not a proto or unit type in protoy.xml")
            elif vt == "tech":
                if re.fullmatch(r"-?\d+", v):
                    i = int(v)
                    saved = tech_t[i] if 0 <= i < len(tech_t) else None
                    now = gd.tech_names[i] if 0 <= i < len(gd.tech_names) else None
                    if saved is None:
                        rep.miss(f"@{hex(off)} {name}.{pname} = {i}: outside the saved tech table")
                    elif saved.lower() not in gd.tech_index:
                        rep.miss(f"@{hex(off)} {name}.{pname} = {i} ({saved}): tech not in techtreey.xml")
                    else:
                        # The game re-maps it by name (trigtemp.xs shows the current index).
                        rep.ok(f"@{hex(off)} {name}.{pname} = {i} ({saved}, now {gd.tech_index[saved.lower()]};"
                               f" index {i} alone would be {now})")
            elif vt == "stringid":
                if re.fullmatch(r"\d+", v) and int(v) > 0 and int(v) not in gd.strings:
                    rep.miss(f"@{hex(off)} {name}.{pname} = {v}: string ID not in the string table")
            elif vt == "camtrack":
                # The editor saves its camera tracks in the scenario (ASCII names after the map).
                if v and v.encode("latin-1", "replace") + b"\0" not in raw and not any(
                        (gd.camtracks / (v + ext)).exists() for ext in ("", ".cam")):
                    rep.miss(f"@{hex(off)} {name}.{pname} = {v}: no such camera track in the scenario or CAMERATRACKS")
    rep.note(f"trigger effects/conditions parsed: {len(trig)} ({len(kinds)} kinds)")
    for name, n in sorted(unknown.items()):
        rep.note(f"'{name}' x{n}: not in trigger3\\typetest.xml (runs from the scenario's own command text)")
    if rep.show_all:
        for vt, c in sorted(by_type.items()):
            print(f"  type {vt}: {len(c)} distinct values")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root", type=Path)
    ap.add_argument("--campaign", action="append", default=[])
    ap.add_argument("--scn", action="append", default=[])
    ap.add_argument("--all", action="store_true")
    a = ap.parse_args()
    gd = GameData(a.root)
    rep = Report(a.all)
    print(f"{a.root}: {len(gd.protos)} protos, {len(gd.unittypes)} unit types, {len(gd.tech_names)} techs, "
          f"{len(gd.civs)} civs, {len(gd.strings)} strings, {len(gd.trigger_types)} trigger types")
    # --scn alone checks only those files (e.g. a fixed set outside the game folder).
    campaigns = [a.root / c for c in (a.campaign or ([] if a.scn else DEFAULT_CAMPAIGNS))]
    scns = []
    for c in campaigns:
        if c.exists():
            for f in check_campaign(gd, c, rep):
                if f not in scns:
                    scns.append(f)
        elif a.campaign:
            rep.miss(f"campaign {c} not found")
    scns += [Path(s) if Path(s).is_absolute() else a.root / s for s in a.scn]
    for s in scns:
        check_scenario(gd, s, rep)
    print(f"\n{rep.misses} miss(es)")
    return 1 if rep.misses else 0


if __name__ == "__main__":
    sys.exit(main())
