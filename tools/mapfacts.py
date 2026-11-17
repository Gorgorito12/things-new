"""The facts of each random map of a Wars of Liberty copy, read from its map scripts and data, for the
map descriptions: trade route, natives, huntables, herdables, mines, berries, fish, whales, outlaws,
region and King of the Hill.

    python -I tools/mapfacts.py <copy> [--out DIR] [--maps A,B] [--check UNITS_DIR]

<copy> is a game folder with RM4 (or RM3) and data (C:\\WoL-Test). Writes DIR/mapfacts.csv and
DIR/mapfacts.json (default: the current folder). Read only: it never writes into the copy.

How a map script is read (the .xs without comments; the include libraries are not read):
- every assignment to a variable, every call argument bound to a function's parameter and every
  xsArraySetString give that variable its possible values, whatever the branch: a value chosen by
  rmRandInt or in an if/else shows as several values ("one of");
- a string is evaluated through concatenation and rmRandInt (ranges of up to 40 values);
- rmAddObjectDefItem's second argument is classified by its proto's UnitTypes in protoy.xml:
  Huntable, Herdable, AbstractMine, AbstractFruit, AbstractFish, AbstractWhale;
- natives: the sockets in the grouping files the map uses (RM4\\groupings), named by civs.xml, and
  WoL's African trade sites (AUR<resource>); without them the values of rmSetSubCiv; "varies" when
  a slot takes a random civ or a village is placed inside an if/else;
- an object definition that no live statement places counts as nothing (defined_not_placed);
  rmCreateGrouping files that do not exist are listed (missing_groupings);
- trade route: rmCreateTradeRoute and rmBuildTradeRoute, with the conditions around the build
  (e.g. "not in FFA");
- outlaws: the data\\mapspecifictechs.xml block that the game uses for the map (outlaw_block: the
  first block in file order named after one of the map's types; a block named after a map file is
  never used), its <tech> and <forcetech> that enable a military unit, plus "<randomnumtouse> random"
  from <randomtech>; `dead_block_for_file` names a block written for this map that the game ignores;
- region: the continent .set files, then the imagepath folder, then REGION_OVERRIDES (checked by
  hand; the folders have errors);
- King of the Hill: rmGetIsKOTH with ypKingsHillPlacer or a "ypKingsHill" object.
Calls in a function that main never reaches are left out. A value the reader cannot resolve shows
as "?".

--check UNITS_DIR compares the facts with the unit lists of tools/mapsweep.py (<map>-p<N>-s<S>-*.txt,
gaia units at the start of the game) and adds per map: seen_* columns, and `check`, the mismatches.
"""
import csv
import json
import pathlib
import re
import sys

# --- reading files ------------------------------------------------------------------------------


def read_text(path):
    raw = pathlib.Path(path).read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16")
    if raw[:3] == b"\xef\xbb\xbf":
        raw = raw[3:]
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("cp1252", "replace")


def strings_of(path):
    """A string table: {id: text}."""
    text = read_text(path)
    return {int(m.group(1)): unescape(m.group(2)) for m in re.finditer(
        r"""<String\s+_locID\s*=\s*['"](\d+)['"][^>]*>(.*?)</String>""", text, re.S)}


def unescape(s):
    s = re.sub(r"&#(\d+);", lambda m: chr(int(m.group(1))), s)
    s = re.sub(r"&#x([0-9a-fA-F]+);", lambda m: chr(int(m.group(1), 16)), s)
    return s.replace("&quot;", '"').replace("&apos;", "'").replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&")


class Data:
    """protoy.xml, civs.xml, techtreey.xml, mapspecifictechs.xml and the string tables of a copy."""

    CATEGORIES = [("hunt", "Huntable"), ("herd", "Herdable"), ("mine", "AbstractMine"), ("berry", "AbstractFruit"),
                  ("fish", "AbstractFish"), ("whale", "AbstractWhale")]

    def __init__(self, bed):
        data = bed / "data"
        self.en = strings_of(bed / "translations" / "_originals" / "stringtabley.xml") \
            if (bed / "translations" / "_originals" / "stringtabley.xml").exists() else {}
        self.local = strings_of(data / "stringtabley.xml")
        es = bed / "translations" / "ES-LA" / "stringtabley.xml"
        self.es = strings_of(es) if es.exists() else {}
        rms = data / "randommapstringsy.xml"
        if rms.exists():
            for k, v in strings_of(rms).items():
                self.en.setdefault(k, v)
                self.local.setdefault(k, v)
        proto = re.sub(r"<!--.*?-->", "", read_text(data / "protoy.xml"), flags=re.S)
        self.protos = {}  # lower name -> (name, types, display id)
        for m in re.finditer(r"""<Unit\s[^>]*name\s*=\s*['"]([^'"]+)['"][^>]*>(.*?)</Unit>""", proto, re.S):
            body = m.group(2)
            types = {t.strip() for t in re.findall(r"<UnitType>([^<]+)</UnitType>", body)}
            did = re.search(r"<DisplayNameID>\s*(\d+)", body)
            self.protos[m.group(1).lower()] = (m.group(1), types, int(did.group(1)) if did else None)
        self.unit_types = {t.lower() for p in self.protos.values() for t in p[1]}
        civs = re.sub(r"<!--.*?-->", "", read_text(data / "civs.xml"), flags=re.S)
        self.civs = {}
        for m in re.finditer(r"<civ>(.*?)</civ>", civs, re.S | re.I):
            n = re.search(r"<name>\s*([^<]*?)\s*</name>", m.group(1), re.I)
            d = re.search(r"<displaynameid>\s*(\d+)", m.group(1), re.I)
            if n:
                self.civs[n.group(1).lower()] = (n.group(1), int(d.group(1)) if d else None)
        tech = re.sub(r"<!--.*?-->", "", read_text(data / "techtreey.xml"), flags=re.S)
        self.techs = {}  # lower name -> (name, enabled protos, display id)
        for m in re.finditer(r"""<Tech\s+name\s*=\s*['"]([^'"]+)['"][^>]*>(.*?)</Tech>""", tech, re.S):
            body = m.group(2)
            enables = re.findall(r"""subtype\s*=\s*['"]Enable['"][^>]*>\s*<Target\s+type\s*=\s*['"]ProtoUnit['"]\s*>([^<]+)<""",
                                 body, re.I)
            did = re.search(r"<DisplayNameID>\s*(\d+)", body)
            self.techs[m.group(1).lower()] = (m.group(1), [e.strip() for e in enables],
                                              int(did.group(1)) if did else None)
        self.map_types = {t.strip().lower() for t in re.findall(
            r"<type>([^<]+)</type>", re.sub(r"<!--.*?-->", "", read_text(data / "maptypes.xml"), flags=re.S), re.I)}
        mst = re.sub(r"<!--.*?-->", "", read_text(data / "mapspecifictechs.xml"), flags=re.S)
        self.blocks = []  # in file order: (name, [(kind, tech)], random count, random pool)
        for m in re.finditer(r"""<map\s+name\s*=\s*['"]([^'"]*)['"]\s*>(.*?)</map>""", mst, re.S | re.I):
            body = m.group(2)
            fixed = [(k.lower(), t.strip()) for k, t in re.findall(r"<(tech|forcetech)>\s*([^<]*?)\s*</\1>", body, re.I)]
            pool = [t.strip() for t in re.findall(r"<randomtech>\s*([^<]*?)\s*</randomtech>", body, re.I)]
            n = re.search(r"<randomnumtouse>\s*(\d+)", body, re.I)
            self.blocks.append((m.group(1), fixed, int(n.group(1)) if n else 0, pool))

    def text(self, sid, table="en"):
        t = {"en": self.en, "es": self.es, "local": self.local}[table]
        return t.get(sid) if sid is not None else None

    def category(self, name):
        p = self.protos.get(name.lower())
        if not p:
            return None
        for cat, utype in self.CATEGORIES:
            if utype in p[1]:
                return cat
        return None

    def proto_label(self, name, table="en"):
        p = self.protos.get(name.lower())
        if not p:
            return name
        return self.text(p[2], table) or self.text(p[2], "local") or p[0]

    def civ_label(self, name, table="en"):
        c = self.civs.get(name.lower())
        if not c:
            return name
        return self.text(c[1], table) or self.text(c[1], "local") or c[0]


# --- the XS reader ------------------------------------------------------------------------------

UNKNOWN = "?"
MAX_VALUES = 64


def strip_comments(src):
    """The script without // and /* */ comments; string literals are kept (XS has no escapes)."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == '"':
            j = src.find('"', i + 1)
            j = n - 1 if j < 0 else j
            out.append(src[i:j + 1])
            i = j + 1
        elif src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2)
            i = n if j < 0 else j + 2
            out.append(" ")
        else:
            out.append(c)
            i += 1
    return "".join(out)


class Stmt:
    def __init__(self, text, conds, func, line):
        self.text, self.conds, self.func, self.line = text, conds, func, line


def statements(code):
    """Splits the code into statements, each with the headers of the blocks it is in (if, else, for,
    the function) and the brace-less if/else prefixes of its own text."""
    stmts, stack, buf, depth, i, n = [], [], [], 0, 0, len(code)
    line = 1
    start_line = 1
    func = None
    while i < n:
        c = code[i]
        if c == '"':
            j = code.find('"', i + 1)
            j = n - 1 if j < 0 else j
            buf.append(code[i:j + 1])
            line += code.count("\n", i, j + 1)
            i = j + 1
            continue
        if c == "\n":
            line += 1
        if c == "(":
            depth += 1
        elif c == ")":
            depth = max(0, depth - 1)
        if depth == 0 and c in ";{}":
            text = "".join(buf).strip()
            buf = []
            if c == "{":
                header = text
                m = re.match(r"(?:void|int|float|string|bool|vector)\s+(\w+)\s*\(", header)
                if not stack and m:
                    func = m.group(1)
                stack.append(header)
            elif c == "}":
                if text:
                    stmts.append(Stmt(text, list(stack), func, start_line))
                if stack:
                    stack.pop()
                if not stack:
                    func = None
            elif text:
                stmts.append(Stmt(text, list(stack), func, start_line))
            start_line = line
            i += 1
            continue
        if not buf and c.isspace():
            start_line = line + (1 if c == "\n" else 0) - (1 if c == "\n" else 0)
        buf.append(c)
        i += 1
    for s in stmts:
        s.conds = [h for h in s.conds if h]
        # a brace-less "if (x) stmt" / "else stmt" prefix belongs to the conditions
        t = s.text
        while True:
            m = re.match(r"(else\s+)?if\s*\(", t)
            if m:
                close = matching_paren(t, m.end() - 1)
                if close < 0:
                    break
                s.conds.append(t[:close + 1].strip())
                t = t[close + 1:].strip()
                continue
            m = re.match(r"else\b\s*", t)
            if m and not t.startswith("else if"):
                s.conds.append("else")
                t = t[m.end():].strip()
                continue
            break
        s.text = t
    return stmts


def matching_paren(text, at):
    depth = 0
    i = at
    while i < len(text):
        c = text[i]
        if c == '"':
            j = text.find('"', i + 1)
            if j < 0:
                return -1
            i = j + 1
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def split_args(s):
    """Top-level comma split."""
    out, depth, buf, i = [], 0, [], 0
    while i < len(s):
        c = s[i]
        if c == '"':
            j = s.find('"', i + 1)
            j = len(s) - 1 if j < 0 else j
            buf.append(s[i:j + 1])
            i = j + 1
            continue
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        if c == "," and depth == 0:
            out.append("".join(buf).strip())
            buf = []
        else:
            buf.append(c)
        i += 1
    if buf or out:
        out.append("".join(buf).strip())
    return out


def calls(text, name):
    """Every call of `name` in a statement: its argument list."""
    for m in re.finditer(r"\b%s\s*\(" % re.escape(name), text):
        close = matching_paren(text, m.end() - 1)
        if close > 0:
            yield split_args(text[m.end():close])


class Script:
    def __init__(self, src):
        self.code = strip_comments(src)
        self.stmts = statements(self.code)
        self.assign = {}   # var -> [expr]
        self.arrays = {}   # var -> [expr]
        self.funcs = {}    # name -> [params]
        for s in self.stmts:
            for h in s.conds[:1]:
                m = re.match(r"(?:void|int|float|string|bool|vector)\s+(\w+)\s*\((.*)\)\s*$", h, re.S)
                if m and m.group(1) not in self.funcs:
                    params = []
                    for p in split_args(m.group(2)):
                        pm = re.match(r"(?:const\s+)?(?:int|float|string|bool|vector)\s+(\w+)(?:\s*=\s*(.+))?$", p.strip(), re.S)
                        if pm:
                            params.append(pm.group(1))
                            if pm.group(2):
                                self.assign.setdefault(pm.group(1), []).append(pm.group(2))
                    self.funcs[m.group(1)] = params
        for s in self.stmts:
            for part in self.assignments(s.text):
                var, expr = part
                self.assign.setdefault(var, []).append(expr)
            for args in calls(s.text, "xsArraySetString"):
                if len(args) >= 3:
                    self.arrays.setdefault(args[0], []).append(args[2])
            for fname, params in self.funcs.items():
                if fname == "main":
                    continue
                for args in calls(s.text, fname):
                    for p, a in zip(params, args):
                        self.assign.setdefault(p, []).append(a)
        self.reached = self.reachable()
        self.memo = {}

    @staticmethod
    def assignments(text):
        # "string a = x", "a = x", "int a=1, b=2" is rare: only the first is read
        m = re.match(r"(?:const\s+|extern\s+|static\s+)*(?:int|float|string|bool|vector)?\s*(\w+)\s*=(?!=)\s*(.+)$", text, re.S)
        if m and m.group(1) not in ("if", "for", "while", "return"):
            yield m.group(1), m.group(2).strip()
        m = re.match(r"for\s*\(\s*(?:int\s+)?(\w+)\s*=\s*([^;]+);", text)
        if m:
            yield m.group(1), m.group(2).strip()

    def reachable(self):
        """The functions that main calls, directly or not."""
        body = {}
        for s in self.stmts:
            body.setdefault(s.func, []).append(s.text)
        seen, todo = set(), ["main"]
        while todo:
            f = todo.pop()
            if f in seen:
                continue
            seen.add(f)
            text = "\n".join(body.get(f, []))
            for g in self.funcs:
                if g not in seen and re.search(r"\b%s\s*\(" % re.escape(g), text):
                    todo.append(g)
        return seen

    def live(self, s):
        return s.func is None or s.func in self.reached

    # values ------------------------------------------------------------------------------------
    def values(self, expr, guard=()):
        """The possible values of an expression: a set of str / int, UNKNOWN when unresolved."""
        expr = expr.strip()
        while expr.startswith("(") and matching_paren(expr, 0) == len(expr) - 1:
            expr = expr[1:-1].strip()
        terms = self.split_plus(expr)
        if len(terms) > 1:
            parts = [self.values(t, guard) for t in terms]
            out = {""}
            stringy = any(isinstance(v, str) and v != UNKNOWN for p in parts for v in p)
            if not stringy:
                return {UNKNOWN}
            for p in parts:
                nxt = set()
                for a in out:
                    for b in p:
                        nxt.add(UNKNOWN if UNKNOWN in (a, b) else f"{a}{b}")
                out = nxt
                if len(out) > MAX_VALUES:
                    return {UNKNOWN}
            return out
        if re.fullmatch(r'"[^"]*"', expr):
            return {expr[1:-1]}
        if re.fullmatch(r"-?\d+", expr):
            return {int(expr)}
        m = re.fullmatch(r"rmRandInt\s*\((.*)\)", expr, re.S)
        if m:
            args = split_args(m.group(1))
            if len(args) == 2:
                lo, hi = self.values(args[0], guard), self.values(args[1], guard)
                if len(lo) == 1 and len(hi) == 1:
                    lo, hi = next(iter(lo)), next(iter(hi))
                    if isinstance(lo, int) and isinstance(hi, int) and 0 <= hi - lo <= 40:
                        return set(range(lo, hi + 1))
            return {UNKNOWN}
        m = re.fullmatch(r"xsArrayGetString\s*\(\s*(\w+)\s*,.*\)", expr, re.S)
        if m:
            out = set()
            for e in self.arrays.get(m.group(1), []):
                out |= self.values(e, guard)
            return out or {UNKNOWN}
        if re.fullmatch(r"[A-Za-z_]\w*", expr):
            if expr in ("true", "false"):
                return {expr}
            if expr in guard:
                return set()
            if expr in self.memo:
                return self.memo[expr]
            out = set()
            for e in self.assign.get(expr, []):
                out |= self.values(e, guard + (expr,))
            out = out or {UNKNOWN}
            if not guard:
                self.memo[expr] = out
            return out
        return {UNKNOWN}

    @staticmethod
    def split_plus(expr):
        out, depth, buf, i = [], 0, [], 0
        while i < len(expr):
            c = expr[i]
            if c == '"':
                j = expr.find('"', i + 1)
                j = len(expr) - 1 if j < 0 else j
                buf.append(expr[i:j + 1])
                i = j + 1
                continue
            if c in "([":
                depth += 1
            elif c in ")]":
                depth -= 1
            if c == "+" and depth == 0 and buf and "".join(buf).strip():
                out.append("".join(buf))
                buf = []
            else:
                buf.append(c)
            i += 1
        out.append("".join(buf))
        return [t.strip() for t in out if t.strip()]

    def string_values(self, expr):
        vals = self.values(expr)
        out = {v for v in vals if isinstance(v, str) and v != ""}
        return out


# --- facts per map ---------------------------------------------------------------------------------

# Continent sets of RM4 -> region
SET_REGIONS = {
    "africanrandom": "Africa", "americanorthrandom": "America N", "americasouthrandom": "America S",
    "asianrandom": "Asia", "europeanrandom": "Europe", "oceaniapacificrandom": "Oceania",
}
# imagepath folder (RMs\SMALL\<folder>\...) -> region, when the map is in no continent set
FOLDER_REGIONS = {
    "africa": "Africa", "africa and middle east": "Africa", "north america": "America N",
    "northamerica": "America N", "south america": "America S", "southamerica": "America S",
    "asia": "Asia", "europe": "Europe", "oceania": "Oceania", "pacific": "Oceania",
}
# Checked by hand from the map's name, current text and map types; wins over the sets and folders.
# A note marks a choice someone may see otherwise (it goes to the region_note column).
REGION_OVERRIDES = {
    # in a continent set, but Maston's list has a closer region
    "deccan": ("Indian Subcontinent", ""), "deccanLarge": ("Indian Subcontinent", ""),
    "vividlyKashmir": ("Indian Subcontinent", ""), "vividlyKolkata": ("Indian Subcontinent", "Bengal"),
    "WolGujarat": ("Indian Subcontinent", ""), "GANPunjab": ("Indian Subcontinent", ""),
    "Ceylon": ("Indian Subcontinent", "Sri Lanka"), "ESOC_Bengal": ("Indian Subcontinent", ""),
    "ESOC_Thar Desert": ("Indian Subcontinent", ""),
    "himalayas": ("Indian Subcontinent", "Himalayas: Indian natives and map type; Asia also fits"),
    "himalayasUpper": ("Indian Subcontinent", "Himalayas: Indian natives and map type; Asia also fits"),
    "hollows": ("Other", "Halloween fantasy map; in both America sets"),
    "Delta TWC": ("Other", "'Unknown Delta area'; in the European set"),
    # not in a continent set (or a wrong folder)
    "amazonia": ("America S", ""), "Prairie TWC": ("America S", "Llanos"), "great chaco": ("America S", "Pantanal"),
    "galapagos": ("America S", ""), "DansilCerroAcahay": ("America S", "Paraguay"),
    "DansilFalklands": ("America S", ""), "dansil Rio De Plata": ("America S", ""), "NEWTiticaca": ("America S", ""),
    "Yungas": ("America S", ""), "ESOC_Gran Chaco": ("America S", ""), "ESOC_Pampas Sierras": ("America S", ""),
    "caribbean": ("America N", "Caribbean counted as North America, as the set does"),
    "carolinaLarge": ("America N", ""), "great plainsLarge": ("America N", ""), "saguenayLarge": ("America N", ""),
    "saskatchewan": ("America N", ""), "sonoraLarge": ("America N", ""), "texasLarge": ("America N", ""),
    "Finger Lake-V": ("America N", ""), "dansil Manicouagan Basin": ("America N", "Quebec"),
    "dansil92 Manitoba": ("America N", ""), "dansil92Kwadacha": ("America N", "British Columbia"),
    "dansil_Owikeno": ("America N", "British Columbia"), "ESOC_Adirondacks": ("America N", ""),
    "ESOC_Alaska": ("America N", ""), "ESOC_Arizona": ("America N", ""), "ESOC_Arkansas": ("America N", ""),
    "ESOC_Baja California": ("America N", ""), "ESOC_Cascade Range": ("America N", ""),
    "ESOC_Colorado": ("America N", ""), "ESOC_Florida": ("America N", ""), "ESOC_Great Basin": ("America N", ""),
    "ESOC_High Plains": ("America N", ""), "ESOC_Hudson Bay": ("America N", ""), "ESOC_Iowa": ("America N", ""),
    "ESOC_Klondike": ("America N", ""), "ESOC_Manchac": ("America N", "Louisiana"),
    "ESOC_Mendocino": ("America N", "California"), "ESOC_Wadmalaw": ("America N", "South Carolina"),
    "anatolia": ("Middle East", ""), "Arabia": ("Middle East", ""), "NEWLevant": ("Middle East", ""),
    "NEWMesoMarshes": ("Middle East", "Mesopotamian Marshes"), "NEWIranianPlateau": ("Middle East", ""),
    "NEWZagros": ("Middle East", ""), "ESOC_Fertile Crescent": ("Middle East", ""),
    "NEWHinduKush": ("Middle East", "Afghanistan; Asia also fits"),
    "WOLsocotra": ("Middle East", "Socotra (Yemen); Africa also fits"),
    "NEWFerghana": ("Asia", "Central Asia"), "NEWKarakum": ("Asia", "Central Asia"),
    "NEWKhorezm": ("Asia", "Central Asia"), "NEWKyzylkum": ("Asia", "Central Asia"),
    "GANWakhan": ("Asia", "Wakhan corridor (Afghanistan); Middle East also fits"),
    "DansilIbalong": ("Asia", "Philippines"), "dansilRed Beach": ("Asia", "China"),
    "dansilRedRiver": ("Asia", "Red River (Vietnam/China)"), "DansilZavkhan": ("Asia", "Mongolia"),
    "ESOC_Indonesia": ("Asia", ""), "ESOC_Kamchatka": ("Asia", ""), "ESOC_Malaysia": ("Asia", ""),
    "ESOC_Manchuria": ("Asia", ""), "ESOC_Parallel Rivers": ("Asia", "Yunnan"), "ESOC_Tibet": ("Asia", ""),
    "ESOC_Herald Island": ("Asia", "Russian Arctic island in the Chukchi Sea"),
    "honshuRegicide": ("Asia", ""), "Korea": ("Asia", ""), "siberiaLarge": ("Asia", ""),
    "silkRoadLarge": ("Asia", ""), "yellow riverLarge": ("Asia", ""), "Team Archipelago Asian": ("Asia", ""),
    "NEWBarbary": ("Africa", ""), "GANNiger": ("Africa", ""), "DansilLCongo": ("Africa", ""),
    "WOLatlas": ("Africa", ""), "WolBioko": ("Africa", ""), "WOLsavannah": ("Africa", ""),
    "ESOC_Tassili": ("Africa", "Algeria"), "ESOC_Jebel Musa": ("Africa", "Morocco, Strait of Gibraltar"),
    "WOLAlps": ("Europe", ""), "WOLbalkans": ("Europe", "Aegean"), "WOLbritishislands": ("Europe", ""),
    "WOLIberianPeninsula": ("Europe", ""), "WOLScandinavia": ("Europe", ""), "WoLverdongorge": ("Europe", ""),
    "WOLazores": ("Europe", "Azores (Portugal); the folder says Africa"),
    "WOLGibraltar": ("Europe", "Strait of Gibraltar; Africa also fits"),
    "dansil_greatbarrierreef": ("Oceania", "Australia"), "dansil_Micronesia": ("Oceania", ""),
    "dansil_Outback": ("Oceania", ""), "dansil_Westernterritory": ("Oceania", "Australia"),
    "dansilFiji": ("Oceania", ""), "everglades": ("Oceania", "file 'everglades' is Pohnpei; folder says Asia"),
    "WOLaustralia": ("Oceania", ""), "WOLnewzealand": ("Oceania", ""), "WOLnlnz": ("Oceania", ""),
    "WOLvandiemansland": ("Oceania", "Tasmania"),
    "WOLmoon": ("Space", ""),
    "Barrier Ridge TWC": ("Other", "random terrain from any continent"),
    "Transcontinental TAD": ("Other", "random terrain from any continent"),
    "unknown": ("Other", ""), "Christmas": ("Other", "Winter Wonderland"),
    "WOLEcruteak": ("Other", "fictional (Ecruteak City)"),
}
REGIONS = ["America N", "America S", "Europe", "Africa", "Middle East", "Asia", "Oceania",
           "Indian Subcontinent", "Space", "Other"]


def map_xml(path):
    text = read_text(path)
    m = re.search(r"<mapinfo(.*?)>", text, re.S)
    attrs = {}
    raw_names = []
    if m:
        for a, v in re.findall(r'(\w+)\s*=\s*"([^"]*)"', m.group(1)):
            attrs.setdefault(a.lower(), unescape(v))
            raw_names.append(a)
    canonical = {"displayname": "displayName", "displaynameid": "displayNameID", "details": "details",
                 "detailstext": "detailsText", "loaddetails": "loadDetails", "loaddetailstext": "loadDetailsText",
                 "imagepath": "imagepath", "loadbackground": "loadBackground", "cannotreplace": "cannotReplace"}
    misspelt = [a for a in raw_names if a.lower() in canonical and a != canonical[a.lower()]]
    return attrs, misspelt


def set_members(folder):
    out = {}
    for s in folder.glob("*.set"):
        text = re.sub(r"<!--.*?-->", "", read_text(s), flags=re.S)
        for m in re.findall(r"<map>\s*([^<]*?)\s*</map>", text, re.I):
            out.setdefault(m.lower(), []).append(s.stem.lower())
    return out


def conditions_summary(stmts):
    """The conditions of the calls, '' when one call is unconditional (apart from the function)."""
    sets = []
    for s in stmts:
        conds = [c for c in s.conds if not re.match(r"(?:void|int|float|string|bool)\s+\w+\s*\(", c)]
        if not conds:
            return ""
        sets.append(" && ".join(re.sub(r"\s+", " ", c) for c in conds))
    return " || ".join(dict.fromkeys(sets))


def trade_phrase(cond):
    # built in an if and in its else (e.g. one layout for FFA, another for teams): always there
    if not cond or "else" in cond.split(" || "):
        return "Yes"
    c = cond.lower()
    bits = []
    if "ffa" in c:
        bits.append("not in FFA" if re.search(r"rmgetisffa\s*\(\s*\)\s*==\s*false|!\s*rmgetisffa|isffa\s*==\s*false", c) else "FFA-dependent")
    if "koth" in c:
        bits.append("not in KOTH" if re.search(r"koth\s*\(\s*\)\s*==\s*false|!\s*rmgetiskoth", c) else "KOTH-dependent")
    if "cnumberteams" in c or "teamnum" in c or "cnumbernongaiaplayers" in c or "playernum" in c:
        bits.append("depends on teams/players")
    if not bits:
        bits.append("varies")
    return "Yes (" + ", ".join(dict.fromkeys(bits)) + ")"


def outlaw_block(data, map_name, map_types):
    """The mapspecifictechs.xml block the game uses. Verified with REA on the stock exe (docs/wol-maps.md,
    "Outlaws"): each <map name> is turned into a map type ID of maptypes.xml when the file loads (a name
    that is no map type gets -1 and is never used: a block named after a map file is dead); rmSetMapType
    sets the map's types (an unknown one is ignored) and "default" is always set; the game takes the
    FIRST block in file order whose type the map has. Names compare without case. The order of the
    map's rmSetMapType calls does not matter."""
    have = {t.lower() for t in map_types if t.lower() in data.map_types} | {"default"}
    for b in data.blocks:
        name = b[0].lower()
        if name in data.map_types and name in have:
            return b, "default" if name == "default" else f"map type {b[0]}"
    return None, "none"


def facts(bed, data, xs_path, sets):
    name = xs_path.stem
    src = read_text(xs_path)
    sc = Script(src)
    attrs, misspelt = map_xml(xs_path.with_suffix(".xml"))
    row = {"map": name}
    # names and current texts
    did = attrs.get("displaynameid", "").strip()
    row["name_en"] = attrs.get("displayname") or (data.text(int(did)) if did.isdigit() else "") or name
    row["name_es"] = attrs.get("displayname") or (data.text(int(did), "es") if did.isdigit() else "") or row["name_en"]
    for key, idk, txk in (("lobby", "details", "detailstext"), ("loading", "loaddetails", "loaddetailstext")):
        sid = attrs.get(idk, "").strip()
        row[f"{key}_source"] = "id" if sid.isdigit() else ("text" if attrs.get(txk) else ("bad id" if sid else "none"))
        row[f"{key}_en"] = (data.text(int(sid)) if sid.isdigit() else attrs.get(txk) or "") or ""
    row["xml_attr_typos"] = " ".join(misspelt)
    # objects
    cats = {c: {} for c, _ in Data.CATEGORIES}
    unknown_protos = set()
    # an object definition counts only if a live statement places it (rmPlaceObjectDef*), or hands
    # it to something else (a function, a grouping): a definition whose placement is commented out
    # puts nothing on the map
    placed_text = "\n".join(s.text for s in sc.stmts if sc.live(s) and not re.match(
        r"(?:int\s+)?\w+\s*=\s*rmCreateObjectDef\s*\(", s.text) and "rmAddObjectDef" not in s.text
        and "rmSetObjectDef" not in s.text)
    unplaced = set()
    for s in sc.stmts:
        if not sc.live(s):
            continue
        for args in calls(s.text, "rmAddObjectDefItem"):
            if len(args) < 2:
                continue
            var = args[0].strip()
            if re.fullmatch(r"[A-Za-z_]\w*", var) and not re.search(r"\b%s\b" % re.escape(var), placed_text):
                unplaced.update(v for v in sc.string_values(args[1]) if data.category(v))
                continue
            vals = sc.string_values(args[1])
            # inside an if/else (or a switch) the item is placed in some games only
            conditional = any(re.match(r"(?:else\b|if\b|switch\b|while\b)", c) for c in s.conds)
            for v in vals:
                cat = data.category(v)
                if cat:
                    entry = cats[cat].setdefault(data.protos[v.lower()][0], set())
                    entry.add("one of" if len(vals) > 1 or conditional else "fixed")
                elif v.lower() not in data.protos and v != UNKNOWN and v.lower() not in data.unit_types:
                    unknown_protos.add(v)
            if UNKNOWN in sc.values(args[1]):
                unknown_protos.add(f"?{args[1]}")
    for cat, items in cats.items():
        row[cat] = "; ".join(f"{p}{'' if 'fixed' in how else ' (varies)'}" for p, how in sorted(items.items()))
        row[f"{cat}_en"] = ", ".join(dict.fromkeys(data.proto_label(p) for p in sorted(items)))
        row[f"{cat}_es"] = ", ".join(dict.fromkeys(data.proto_label(p, "es") for p in sorted(items)))
    row["unresolved"] = " ".join(sorted(unknown_protos))[:300]
    placed = {p.lower() for items in cats.values() for p in items}
    row["defined_not_placed"] = " ".join(sorted({u for u in unplaced if u.lower() not in placed}))
    # groupings (native villages, among others) whose file does not exist place nothing
    gfolder = xs_path.parent / "groupings"
    have = {p.stem.lower() for p in gfolder.glob("*.xml")} if gfolder.exists() else set()
    missing = set()
    for s in sc.stmts:
        if sc.live(s):
            for args in calls(s.text, "rmCreateGrouping"):
                if len(args) > 1:
                    missing |= {v for v in sc.string_values(args[1]) if v.lower().strip() not in have}
    row["missing_groupings"] = "; ".join(sorted(missing))[:300]
    # natives
    natives, varies, slots = [], False, {}
    for s in sc.stmts:
        if not sc.live(s):
            continue
        for args in calls(s.text, "rmSetSubCiv"):
            if len(args) < 2:
                continue
            vals = sc.string_values(args[1])
            if len(vals) > 1:
                varies = True
            slot = slots.setdefault(re.sub(r"\s+", "", args[0]), [])
            for v in sorted(vals):
                if v.lower() not in [x.lower() for x in slot]:
                    slot.append(v)
                if v not in natives:
                    natives.append(v)
    real = [n for n in natives if n.lower() in data.civs]
    row["natives_unknown"] = ", ".join(n for n in natives if n.lower() not in data.civs)
    # one slot given several civs (in an if/else or by a random pick): the civs vary per game
    varies = varies or any(len(v) > 1 for v in slots.values())
    varies = varies or len(real) > max(1, len(slots))
    # The villages themselves come from groupings: the sockets in the grouping files a map really
    # uses say which natives appear (ESOC Bengal sets Sufi and Udasi but places Bhakti villages).
    by_key = {civ_key(c[0]): c[0] for c in data.civs.values()}
    from_groupings, gvaries = [], False
    for s in sc.stmts:
        if not sc.live(s):
            continue
        for args in calls(s.text, "rmCreateGrouping"):
            if len(args) < 2:
                continue
            vals = sc.string_values(args[1])
            found = set()
            for v in vals:
                if v.lower().strip() in have:
                    found |= grouping_sockets(gfolder / f"{v.strip()}.xml")
            if len(vals) > 1 and len(found) > 1:
                gvaries = True
            if found and any(re.match(r"(?:else\b|if\b|switch\b|while\b)", c) for c in s.conds):
                gvaries = True  # a village placed in some games only
            for k in sorted(found):
                civ = k[1:] if k.startswith("@") and k[1:].lower() in data.protos else by_key.get(k)
                if civ and civ not in from_groupings:
                    from_groupings.append(civ)
    if from_groupings:
        real = [n.lower() for n in from_groupings]
        varies = gvaries or (varies and len(from_groupings) > 1)
        row["natives_source"] = "groupings"
    else:
        # civs set but no grouping with their sockets: when the map's village groupings are missing,
        # no village appears (Alps, Hawai'i)
        row["natives_source"] = ("rmSetSubCiv, village groupings missing" if missing else "rmSetSubCiv") if real else ""

    def native_name(n, table="en"):
        if n.lower() in data.civs:
            return data.civs[n.lower()][0] if table is None else data.civ_label(n, table)
        if table is None:
            return data.protos[n.lower()][0]
        # an African trade site: "Socket Cocoa" -> "Cocoa (trade site)"
        res = re.sub(r"^(Socket|Ranura de)\s+", "", data.proto_label(n, table))
        return f"{res} ({'trade site' if table == 'en' else 'puesto comercial'})"
    row["natives"] = ", ".join(native_name(n, None) for n in real)
    row["natives_varies"] = "yes" if varies and len(real) > 1 else ""
    row["natives_slots"] = "; ".join(f"{k}: {'/'.join(v)}" for k, v in slots.items())[:300]
    row["natives_en"] = ", ".join(dict.fromkeys(native_name(n) for n in real))
    row["natives_es"] = ", ".join(dict.fromkeys(native_name(n, "es") for n in real))
    # trade route
    created = [s for s in sc.stmts if sc.live(s) and re.search(r"\brmCreateTradeRoute\s*\(", s.text)]
    built = [s for s in sc.stmts if sc.live(s) and re.search(r"\brmBuildTradeRoute\s*\(", s.text)]
    cond = conditions_summary(built)
    row["trade_route"] = trade_phrase(cond) if created and built else "No"
    row["trade_route_conditions"] = cond[:300]
    route_types = set()
    for s in built:
        for args in calls(s.text, "rmBuildTradeRoute"):
            if len(args) > 1:
                route_types |= sc.string_values(args[1])
    row["trade_route_types"] = " ".join(sorted(route_types))
    if row["trade_route"] != "No":
        water = {t for t in route_types if "water" in t.lower()}
        row["trade_route"] += " (water)" if water and water == route_types else " (land and water)" if water else ""
    # KOTH
    koth = bool(re.search(r"\brmGetIsKOTH\s*\(", sc.code)) and bool(
        re.search(r"\bypKingsHillPlacer\s*\(|\"ypKingsHill\"", sc.code))
    row["koth"] = "Yes" if koth else "No"
    # map types and outlaws
    types = []
    for s in sc.stmts:
        if not sc.live(s):
            continue
        for args in calls(s.text, "rmSetMapType"):
            for v in sorted(sc.string_values(args[0])) if args else []:
                if v not in types:
                    types.append(v)
    row["map_types"] = " ".join(types)
    block, why = outlaw_block(data, name, types)
    row["outlaw_block"] = f"{block[0]} ({why})" if block else ""
    fixed, random_n = [], 0
    if block:
        for kind, t in block[1]:
            tech = data.techs.get(t.lower())
            if tech and tech[1]:
                for unit in tech[1]:
                    p = data.protos.get(unit.lower())
                    if p and "Military" in p[1]:
                        fixed.append(p[0])
        random_n = block[2] if block[3] else 0
    def outlaw_text(names, word):
        names = ", ".join(dict.fromkeys(names))
        extra = f"{random_n} {word}" if random_n else ""
        return f"{names} (+{extra})" if names and extra else (names or extra)
    row["outlaws"] = outlaw_text(fixed, "random")
    row["outlaws_en"] = outlaw_text([data.proto_label(u) for u in fixed], "random")
    row["outlaws_es"] = outlaw_text([data.proto_label(u, "es") for u in fixed], "al azar")
    name_block = next((b for b in data.blocks if b[0].lower() == name.lower()), None)
    row["dead_block_for_file"] = name_block[0] if name_block and name.lower() not in data.map_types else ""
    # region
    member = [s for s in sets.get(name.lower(), []) if s in SET_REGIONS]
    folder = re.match(r"RMs\\SMALL\\([^\\]+)\\", attrs.get("imagepath", ""), re.I)
    folder = folder.group(1) if folder else ""
    row["region_sets"] = " ".join(member)
    row["image_folder"] = folder
    row["region_note"] = ""
    if name in REGION_OVERRIDES:
        row["region"], row["region_note"] = REGION_OVERRIDES[name]
        row["region_source"] = "checked by hand"
    elif member:
        row["region"], row["region_source"] = SET_REGIONS[member[0]], "set"
    elif folder.lower() in FOLDER_REGIONS:
        row["region"], row["region_source"] = FOLDER_REGIONS[folder.lower()], "folder (unchecked)"
    else:
        row["region"], row["region_source"] = "", "unknown"
    return row


# --- the in-game check -------------------------------------------------------------------------

def seen_in_game(units_dir, data, name):
    """The gaia units of the sweep's unit lists for this map: {seed: {category: set(protos)}}."""
    out = {}
    safe = re.sub(r"[^\w.-]+", "_", name)
    for f in sorted(pathlib.Path(units_dir).glob(f"{safe}-p*-s*-*.txt")):
        if not re.fullmatch(re.escape(safe) + r"-p\d+-s\d+-\w+\.txt", f.name):
            continue
        seed = re.search(r"-s(\d+)-", f.name).group(1)
        got = {c: set() for c, _ in Data.CATEGORIES}
        got["natives"], got["trade"], got["kingshill"] = set(), set(), set()
        for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
            m = re.match(r"\s*\d+\s+player (-?\d+)\s+(\S+)", line)
            if not m:
                continue
            player, proto = int(m.group(1)), m.group(2)
            cat = data.category(proto)
            if cat:  # any owner: the starting herd belongs to its player
                got[cat].add(proto)
                if player == 0:
                    got.setdefault(f"gaia_{cat}", set()).add(proto)
            low = proto.lower()
            if low in ("sockettraderoute", "yptradingpostcapture", "sockettraderoutewater") or low.startswith("tradingpost"):
                got["trade"].add(proto)
            m = re.match(r"(?:yp|wottanat)?socket(\w+)$", low)
            if m and not m.group(1).startswith("traderoute"):
                got["natives"].add(m.group(1))
            if re.fullmatch(r"AUR[A-Za-z]+", proto) and data.proto_label(proto).startswith("Socket "):
                got["natives"].add(proto)  # an African trade site
            if low == "ypkingshill":
                got["kingshill"].add(proto)
        out[seed] = got
    return out


def compare(row, seen, data):
    """Mismatches between the script facts and the units seen, by category."""
    notes = []
    if not seen:
        return "no run"
    for cat, _ in Data.CATEGORIES:
        said = {p.split(" (")[0].lower() for p in row[cat].split("; ") if p}
        said_fixed = {p.lower() for p in row[cat].split("; ") if p and "(varies)" not in p}
        union = set().union(*(s[cat] for s in seen.values()))
        row[f"seen_{cat}"] = " ".join(sorted(union))
        # a unit the civ starts with (a hen, a cow) is no map resource: "seen, not in the script"
        # counts gaia units only
        gaia = set().union(*(s.get(f"gaia_{cat}", set()) for s in seen.values()))
        extra = {p for p in gaia if p.lower() not in said}
        missing = {p for p in said_fixed if all(p not in {x.lower() for x in s[cat]} for s in seen.values())}
        if extra:
            notes.append(f"{cat}: seen not in script {sorted(extra)}")
        if missing:
            notes.append(f"{cat}: script not seen {sorted(missing)}")
    trade_seen = any(s["trade"] for s in seen.values())
    row["seen_trade"] = "yes" if trade_seen else "no"
    if (row["trade_route"] != "No") != trade_seen:
        notes.append(f"trade: script {row['trade_route']}, seen {'yes' if trade_seen else 'no'}")
    nat = set().union(*(s["natives"] for s in seen.values()))
    row["seen_natives"] = " ".join(sorted(nat))
    said = {civ_key(n) for n in row["natives"].split(", ") if n}
    extra = sorted(n for n in nat if civ_key(n) not in said)
    if extra:
        notes.append(f"natives: seen not in script {extra}")
    missing = sorted(n for n in row["natives"].split(", ") if n and civ_key(n) not in {civ_key(x) for x in nat})
    if missing and row.get("natives_varies") != "yes" and len(missing) < len(row["natives"].split(", ")):
        notes.append(f"natives: script not seen {missing}")
    if said and not nat:
        notes.append("natives: script has natives, none seen")
    return "; ".join(dict.fromkeys(notes))


_GROUPING_SOCKETS = {}


def grouping_sockets(path):
    """The native civs (civ_key) whose sockets a grouping file places."""
    if path not in _GROUPING_SOCKETS:
        found = set()
        try:
            text = read_text(path)
        except OSError:
            text = ""
        for proto in re.findall(r">\s*((?:yp|WOTTANat)?Socket\w+)\s*</unit>", text, re.I):
            k = re.sub(r"^(?:yp|wottanat)?socket", "", proto.lower())
            if not k.startswith("traderoute"):
                found.add(civ_key(k))
        # WoL's African trade sites: a unit AUR<Resource> (shown as "Socket <Resource>")
        for proto in re.findall(r">\s*(AUR[A-Za-z]+)\s*</unit>", text):
            if not re.search(r"props$|^AUR(?:buildings|civilian\w*|flag|timbuktu)$", proto, re.I):
                found.add("@" + proto)
        _GROUPING_SOCKETS[path] = found
    return _GROUPING_SOCKETS[path]


def civ_key(name):
    """A civ name and its socket's name compared: case, a plural s and a trailing 's' differ
    (Seminoles / SocketSeminole, orderofchrist / WOTTANatSocketOrderOfChrist)."""
    k = name.lower().replace(" ", "")
    return k[:-1] if k.endswith("s") else k


# --- main ------------------------------------------------------------------------------------------

FIELDS = ["map", "name_en", "name_es", "region", "region_source", "region_note", "region_sets", "image_folder", "trade_route",
          "trade_route_conditions", "trade_route_types", "koth", "natives", "natives_source", "natives_varies", "natives_slots", "natives_en",
          "natives_es", "natives_unknown", "hunt", "hunt_en", "hunt_es", "herd", "herd_en", "herd_es", "mine",
          "mine_en", "mine_es", "berry", "berry_en", "berry_es", "fish", "fish_en", "fish_es", "whale", "whale_en",
          "whale_es", "map_types", "outlaw_block", "dead_block_for_file", "outlaws", "outlaws_en", "outlaws_es",
          "unresolved", "defined_not_placed", "missing_groupings", "xml_attr_typos", "lobby_source", "lobby_en", "loading_source", "loading_en"]
CHECK_FIELDS = ["seen_hunt", "seen_herd", "seen_mine", "seen_berry", "seen_fish", "seen_whale", "seen_natives",
                "seen_trade", "check"]


def main(argv):
    if not argv or argv[0].startswith("-"):
        sys.exit(__doc__)
    bed = pathlib.Path(argv[0])
    out = pathlib.Path(argv[argv.index("--out") + 1]) if "--out" in argv else pathlib.Path(".")
    rm = bed / ("RM4" if (bed / "RM4").exists() else "RM3")
    data = Data(bed)
    sets = set_members(rm)
    maps = sorted(p for p in rm.glob("*.xs") if p.with_suffix(".xml").exists())
    if "--maps" in argv:
        want = {m.lower() for m in argv[argv.index("--maps") + 1].split(",")}
        maps = [p for p in maps if p.stem.lower() in want]
    rows = [facts(bed, data, p, sets) for p in maps]
    fields = list(FIELDS)
    if "--check" in argv:
        units = argv[argv.index("--check") + 1]
        for r in rows:
            r["check"] = compare(r, seen_in_game(units, data, r["map"]), data)
        fields += CHECK_FIELDS
    out.mkdir(parents=True, exist_ok=True)
    with open(out / "mapfacts.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    (out / "mapfacts.json").write_text(json.dumps(rows, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"mapfacts: {len(rows)} maps -> {out / 'mapfacts.csv'}")
    if "--check" in argv:
        bad = [r for r in rows if r.get("check") not in ("", "no run")]
        print(f"mapfacts: {len(bad)} maps with mismatches, "
              f"{sum(1 for r in rows if r.get('check') == 'no run')} without a run")


if __name__ == "__main__":
    main(sys.argv[1:])
