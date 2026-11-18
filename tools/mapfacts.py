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
  never used), its <tech> and <forcetech> that enable a military unit. The block's <randomtech>
  draws are mercenaries, not outlaws: they are not listed (outlaws_random keeps their number);
  `dead_block_for_file` names a block written for this map that the game ignores;
- map size: main() run as a small numeric program up to rmSetMapSize, for 2, 4 and 8 players
  (size_2/4/8 in metres per side, "X x Z" on a rectangular map, "a-b" where a random number
  changes it; map_size_en/es the line for the descriptions; size_note when it cannot be evaluated);
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
import math
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
            # 'string a = "";' then 'a = "Sufi";': the empty first value is only a declaration
            if "" in out and any(isinstance(v, str) and v not in ("", UNKNOWN) for v in out):
                out.discard("")
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


# --- map size ----------------------------------------------------------------------------------------
# main() is run as a small numeric program, once per player count, up to its first rmSetMapSize(x, z)
# (metres per side): declarations, assignments, if/else, for and while, with the game's values for
# the player count (2 teams, players split evenly, no FFA, no King of the Hill, normal map size
# cMapSize 0). A random number (rmRandInt, rmRandFloat) is run at its lowest and at its highest value,
# so a size that varies shows as a range. Calls of the map's own functions are run when they set the
# size or a variable the size needs; any other call is skipped.

class SizeUnknown(Exception):
    pass


class _Stop(Exception):
    pass


def parse_block(code):
    """The statements of a code block as a tree: ('if', cond, then, else), ('for', init, cond, step,
    body), ('while', cond, body), ('block', body), ('stmt', text)."""
    nodes, i, n = [], 0, len(code)

    def skip_ws(j):
        while j < n and code[j].isspace():
            j += 1
        return j

    def one(j):
        j = skip_ws(j)
        while j < n and code[j] in "};":  # a stray brace or an empty statement
            j = skip_ws(j + 1)
        if j >= n:
            return None, j
        if code[j] == "{":
            close = matching_brace(code, j)
            return ("block", parse_block(code[j + 1:close])), close + 1
        m = re.match(r"(if|while|for)\s*\(", code[j:])
        if m:
            p = matching_paren(code, j + m.end() - 1)
            head = code[j + m.end():p]
            body, k = one(p + 1)
            if m.group(1) == "if":
                k2 = skip_ws(k)
                els = None
                if re.match(r"else\b", code[k2:]):
                    els, k = one(k2 + 4)
                return ("if", head, body, els), k
            if m.group(1) == "while":
                return ("while", head, body), k
            parts = [x.strip() for x in head.split(";")]
            return ("for", *(parts + ["", "", ""])[:3], body), k
        # a plain statement up to its ';' (outside strings and parentheses)
        depth, k = 0, j
        while k < n:
            c = code[k]
            if c == '"':
                k = code.find('"', k + 1)
                if k < 0:
                    k = n
            elif c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
            elif c == ";" and depth <= 0:
                return ("stmt", code[j:k].strip()), k + 1
            elif c == "}" and depth <= 0:
                return ("stmt", code[j:k].strip()), k
            k += 1
        return ("stmt", code[j:].strip()), n

    while True:
        node, i = one(i)
        if node is None:
            break
        nodes.append(node)
    return nodes


def matching_brace(text, at):
    depth, i = 0, at
    while i < len(text):
        c = text[i]
        if c == '"':
            j = text.find('"', i + 1)
            i = (len(text) if j < 0 else j) + 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return len(text)


def function_bodies(code):
    """{name: (params, body text)} of the script's functions."""
    out = {}
    for m in re.finditer(r"(?:^|\n)\s*(?:void|int|float|string|bool|vector)\s+(\w+)\s*\(([^)]*)\)\s*\{", code):
        close = matching_brace(code, m.end() - 1)
        params = []
        for p in split_args(m.group(2)):
            pm = re.match(r"(?:const\s+)?\w+\s+(\w+)", p.strip())
            if pm:
                params.append(pm.group(1))
        out.setdefault(m.group(1), (params, code[m.end():close]))
    return out


class SizeRun:
    """One run of main() for `players` players; `rand` is 'lo' or 'hi'."""
    MAX_STEPS = 20000

    def __init__(self, funcs, players, rand):
        self.funcs, self.rand, self.steps = funcs, rand, 0
        teams = 2
        self.consts = {"cNumberNonGaiaPlayers": players, "cNumberPlayers": players + 1, "cNumberTeams": teams,
                       "cMapSize": 0, "true": True, "false": False, "cInvalidID": -1, "PI": math.pi}
        self.players, self.teams = players, teams
        self.vars, self.types = {}, {}
        self.size = None

    # expressions
    def call(self, name, args):
        f = {"sqrt": lambda a: math.sqrt(a), "xsPow": lambda a, b: a ** b, "abs": abs, "xsAbs": abs,
             "rmGetIsFFA": lambda: False, "rmGetIsKOTH": lambda: False, "rmGetIsTreaty": lambda: False,
             "rmGetIsRelicCapture": lambda: False, "rmGetIsKingOfTheHill": lambda: False,
             "rmGetNumberPlayersOnTeam": lambda t: self.players // self.teams + (1 if t < self.players % self.teams else 0),
             "rmGetPlayerTeam": lambda p: (p - 1) % self.teams,
             "rmRandInt": lambda a, b: a if self.rand == "lo" else b,
             "rmRandFloat": lambda a, b: a if self.rand == "lo" else b,
             "min": min, "max": max, "xsMin": min, "xsMax": max}.get(name)
        if f is None:
            raise SizeUnknown(f"call {name}")
        return f(*args)

    def eval(self, expr):
        expr = expr.strip()
        if not expr:
            raise SizeUnknown("empty expression")
        py = expr.replace("&&", " and ").replace("||", " or ")
        py = re.sub(r"!(?!=)", " not ", py)
        names = {}

        def ident(m):
            word = m.group(0)
            if word in ("and", "or", "not"):
                return word
            names[word] = True
            return f"_v['{word}']" if not re.match(r"\s*\(", py[m.end():]) else f"_f('{word}')"
        if '"' in py:
            raise SizeUnknown("string expression")
        code = re.sub(r"(?<![\w.])[A-Za-z_]\w*", ident, py)

        class Lookup(dict):
            def __missing__(_, key):
                if key in self.vars:
                    v = self.vars[key]
                elif key in self.consts:
                    v = self.consts[key]
                else:
                    raise SizeUnknown(f"name {key}")
                if v is None:
                    raise SizeUnknown(f"unresolved {key}")
                return v
        try:
            return eval(code, {"__builtins__": {}}, {"_v": Lookup(), "_f": lambda n: (lambda *a: self.call(n, a))})
        except SizeUnknown:
            raise
        except Exception as e:  # noqa: BLE001 (a construct the evaluator does not know)
            raise SizeUnknown(f"{type(e).__name__} in {expr[:60]}")

    def assign(self, name, value):
        if self.types.get(name) == "int" and isinstance(value, (int, float)) and not isinstance(value, bool):
            value = int(value)
        self.vars[name] = value

    # statements
    def run(self, nodes):
        for node in nodes:
            self.steps += 1
            if self.steps > self.MAX_STEPS:
                raise SizeUnknown("too many steps")
            kind = node[0]
            if kind in ("if", "while", "for"):
                try:
                    self.control(node)
                except SizeUnknown:
                    # a condition the evaluator cannot read (a call such as rmAllocateSubCivs): the
                    # statement is skipped and what it assigns becomes unknown, unless it sets the size
                    text = repr(node)
                    if "rmSetMapSize" in text:
                        raise
                    for name in re.findall(r"\b(\w+)\s*(?:[-+*/]?=(?!=)|\+\+|--)", text):
                        if name in self.vars:
                            self.vars[name] = None
                continue
            if kind == "block":
                self.run(node[1])
            else:
                self.stmt(node[1])

    def control(self, node):
        """if, while or for."""
        kind = node[0]
        if kind == "if":
            if self.truth(node[1]):
                self.run([node[2]])
            elif node[3] is not None:
                self.run([node[3]])
            return
        if kind == "for" and node[1]:
            self.stmt(node[1])
        cond = node[1] if kind == "while" else node[2]
        while not cond or self.truth(cond):
            self.run([node[2] if kind == "while" else node[4]])
            if kind == "for" and node[3]:
                self.stmt(node[3])
            self.steps += 1
            if self.steps > self.MAX_STEPS:
                raise SizeUnknown("loop")

    def truth(self, cond):
        return bool(self.eval(cond))

    def stmt(self, text):
        text = text.strip()
        if not text or text in ("break", "continue") or text.startswith("return"):
            return
        m = re.match(r"rmSetMapSize\s*\((.*)\)$", text, re.S)
        if m:
            args = split_args(m.group(1))
            self.size = (float(self.eval(args[0])), float(self.eval(args[1])))
            raise _Stop()
        m = re.match(r"(?:const\s+|extern\s+|static\s+)*(int|float|bool|string|vector)\s+(\w+)\s*(?:=\s*(.+))?$", text, re.S)
        if m:
            self.types[m.group(2)] = m.group(1)
            self.try_assign(m.group(2), m.group(3) if m.group(3) is not None else ("0" if m.group(1) in ("int", "float") else None))
            return
        m = re.match(r"(\w+)\s*([-+*/])=\s*(.+)$", text, re.S)
        if m:
            self.try_assign(m.group(1), f"({m.group(1)}) {m.group(2)} ({m.group(3)})")
            return
        m = re.match(r"(\w+)\s*(\+\+|--)$", text) or re.match(r"(\+\+|--)\s*(\w+)$", text)
        if m:
            name = m.group(1) if m.group(1) not in ("++", "--") else m.group(2)
            op = "+" if "++" in text else "-"
            self.try_assign(name, f"({name}) {op} 1")
            return
        m = re.match(r"(\w+)\s*=\s*(.+)$", text, re.S)
        if m:
            self.try_assign(m.group(1), m.group(2))
            return
        m = re.match(r"(\w+)\s*\((.*)\)$", text, re.S)
        if m and m.group(1) in self.funcs and re.search(r"rmSetMapSize", self.funcs[m.group(1)][1]):
            params, body = self.funcs[m.group(1)]
            for p, a in zip(params, split_args(m.group(2))):
                self.try_assign(p, a)
            self.run(parse_block(body))

    def try_assign(self, name, expr):
        if expr is None:
            self.vars[name] = None
            return
        try:
            self.assign(name, self.eval(expr))
        except SizeUnknown:
            self.vars[name] = None  # unknown; an error only if the size needs it


def map_size(code):
    """{players: (x, z) or (x_lo, z_lo, x_hi, z_hi)} for 2, 4 and 8 players, or raises SizeUnknown."""
    funcs = function_bodies(code)
    if "main" not in funcs:
        raise SizeUnknown("no main")
    if not re.search(r"\brmSetMapSize\s*\(", code):
        raise SizeUnknown("no rmSetMapSize")
    # the global declarations (int PlayerNum = cNumberNonGaiaPlayers;) run first
    top = re.sub(r"(?m)^\s*include\s+\"[^\"]*\"\s*;", "", code)
    for name, (_, body) in sorted(funcs.items(), key=lambda kv: -len(kv[1][1])):
        top = top.replace(body, "")
    top = re.sub(r"(?:void|int|float|string|bool|vector)\s+\w+\s*\([^)]*\)\s*\{\s*\}", "", top)
    globals_tree = [n for n in parse_block(top) if n[0] == "stmt"]
    tree = globals_tree + parse_block(funcs["main"][1])
    out = {}
    for players in (2, 4, 8):
        got = []
        for rand in ("lo", "hi"):
            run = SizeRun(funcs, players, rand)
            try:
                run.run(tree)
            except _Stop:
                pass
            if run.size is None:
                raise SizeUnknown("rmSetMapSize not reached")
            got.append(tuple(int(v) for v in run.size))
        if sorted(got[0]) == sorted(got[1]):
            got[1] = got[0]  # the same rectangle, turned one way or the other
        out[players] = got[0] if got[0] == got[1] else (min(got[0][0], got[1][0]), min(got[0][1], got[1][1]),
                                                         max(got[0][0], got[1][0]), max(got[0][1], got[1][1]))
    return out


def size_one(s):
    """(x, z) -> '310' or '275 x 400'; (x_lo, z_lo, x_hi, z_hi) -> '309-357' or '655 x 655-720'."""
    def side(a, b):
        return f"{a}" if a == b else f"{a}-{b}"
    if len(s) == 4:
        x, z = side(s[0], s[2]), side(s[1], s[3])
        return x if x == z else f"{x} x {z}"
    return f"{s[0]}" if s[0] == s[1] else f"{s[0]} x {s[1]}"


def size_text(sizes, lang="en"):
    """'310 / 440 / 620 m (2 / 4 / 8 players)', or 'X x Z' per count on a rectangular map."""
    parts = " / ".join(size_one(sizes[p]) for p in (2, 4, 8))
    word = "players" if lang == "en" else "jugadores"
    return f"{parts} m (2 / 4 / 8 {word})"


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
    # the route type is the route's look: TAD's land maps (Mongolia, Deccan) use "water" too, so it
    # says nothing about land or sea (trade_route_types keeps it)
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
    # the block's <randomtech> units are mercenaries, not outlaws: only the fixed outlaws are listed
    # (outlaws_random keeps how many random techs the block draws)
    row["outlaws"] = ", ".join(dict.fromkeys(fixed))
    row["outlaws_en"] = ", ".join(dict.fromkeys(data.proto_label(u) for u in fixed))
    row["outlaws_es"] = ", ".join(dict.fromkeys(data.proto_label(u, "es") for u in fixed))
    row["outlaws_random"] = str(random_n) if random_n else ""
    # map size, metres per side, for 2, 4 and 8 players
    try:
        sizes = map_size(sc.code)
        row["size_2"], row["size_4"], row["size_8"] = (size_one(sizes[p]) for p in (2, 4, 8))
        row["map_size_en"], row["map_size_es"] = size_text(sizes, "en"), size_text(sizes, "es")
        row["size_note"] = ""
    except SizeUnknown as e:
        row["size_2"] = row["size_4"] = row["size_8"] = row["map_size_en"] = row["map_size_es"] = ""
        row["size_note"] = f"not evaluated: {e}"
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
    game_facts(row, seen, data)
    return "; ".join(dict.fromkeys(notes))


def native_label(data, n, table="en"):
    """A native's name: a civ's display name, or an African trade site 'Cocoa (trade site)'."""
    by_key = {civ_key(c[0]): c for c in data.civs.values()}
    c = data.civs.get(n.lower()) or by_key.get(civ_key(n))
    if c:
        return data.text(c[1], table) or data.text(c[1], "local") or c[0]
    if n.lower() in data.protos:
        res = re.sub(r"^(Socket|Ranura de)\s+", "", data.proto_label(n, table))
        return f"{res} ({'trade site' if table == 'en' else 'puesto comercial'})"
    return n


def game_facts(row, seen, data):
    """The facts as the game showed them, for the descriptions: the game wins over the script.
    Resources: what the game placed for gaia, plus what the script places that the game showed
    (a starting herd belongs to its player; a civ's own starting animals are not counted).
    Natives: the villages seen, or the script's when it picks them at random (2 games are a sample).
    Trade route: seen or not."""
    for cat, _ in Data.CATEGORIES:
        said = {p.split(" (")[0].lower() for p in row[cat].split("; ") if p}
        anyone = set().union(*(s[cat] for s in seen.values()))
        gaia = set().union(*(s.get(f"gaia_{cat}", set()) for s in seen.values()))
        got = sorted(gaia | {p for p in anyone if p.lower() in said})
        row[f"game_{cat}"] = " ".join(got)
        row[f"game_{cat}_en"] = ", ".join(dict.fromkeys(data.proto_label(p) for p in got))
        row[f"game_{cat}_es"] = ", ".join(dict.fromkeys(data.proto_label(p, "es") for p in got))
    nat = sorted(set().union(*(s["natives"] for s in seen.values())))
    script = [n for n in row["natives"].split(", ") if n]
    if row.get("natives_varies") == "yes" and nat:
        names, varies = script, "yes"   # random: the script's list, marked as varying
    else:
        names, varies = nat, ""
    row["game_natives_varies"] = varies
    row["game_natives_en"] = ", ".join(dict.fromkeys(native_label(data, n) for n in names))
    row["game_natives_es"] = ", ".join(dict.fromkeys(native_label(data, n, "es") for n in names))
    trade = any(s["trade"] for s in seen.values())
    if not trade:
        row["game_trade_route"] = "No"
    elif row["trade_route"] == "No":
        row["game_trade_route"] = "Yes"
    else:
        row["game_trade_route"] = row["trade_route"]


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
          "outlaws_random", "size_2", "size_4", "size_8", "map_size_en", "map_size_es", "size_note", "unresolved", "defined_not_placed", "missing_groupings", "xml_attr_typos", "lobby_source", "lobby_en", "loading_source", "loading_en"]
CHECK_FIELDS = ["seen_hunt", "seen_herd", "seen_mine", "seen_berry", "seen_fish", "seen_whale", "seen_natives",
                "seen_trade", "check", "game_trade_route", "game_natives_varies", "game_natives_en",
                "game_natives_es"] + [f"game_{c}{s}" for c, _ in Data.CATEGORIES for s in ("", "_en", "_es")]


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
