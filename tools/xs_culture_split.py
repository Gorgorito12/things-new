"""Simulate splitting an AI script into a shared core and one file per culture (measurement only).

    python -I tools/xs_culture_split.py <aiMain.xs> --report
    python -I tools/xs_culture_split.py <aiMain.xs> --keep European --out <copy.xs>
    python -I tools/xs_culture_split.py <aiMain.xs> --keep European|all --split <folder>

Made for the question "what would splitting aiWoLMain.xs per culture cost or save"
(docs/performance.md, "Splitting the AI script per culture"). It reads the script's top-level items
(rules, functions, globals), files each culture-specific rule under a culture by its name (the
table CULTURE below; WoL's naming: Euro*, NA*, LA*, ME*, Asian*, African*, Balkan*, NS*, ...),
and a function under a culture when every call of it lies inside that culture's items. The rest is
the shared core.

--report   the items, lines and bytes per culture.
--keep C --out F   one file: the core, culture C's items as they are, every other culture's item
           replaced by a stub (a rule keeps its header, so groups and xsEnableRule calls still
           find it, and its body only disables it; a function keeps its signature and returns a
           default). The upper bound of what a loader for culture C would compile.
--keep C|all --split D   the same code as files: D\\aiWoLCore.xs (core, culture functions, the stubs)
           and D\\aiWoL<Culture>.xs with each kept culture's rules (rules are named by string, so
           they may come last). Prints the include lines for the loader. With `all`, nothing is
           stubbed: the same program as the original in 1 + 8 files, to time the includes alone.

The output is for a test copy; this tool does not change any game file by itself.
"""
import re
import sys
from pathlib import Path

TYPES = "void|int|bool|float|string|vector"
RULE_RE = re.compile(r"\s*rule\s+(\w+)")
FUNC_RE = re.compile(r"\s*(?:mutable\s+)?(?:extern\s+)?(" + TYPES + r")\s+(\w+)\s*\(")

# Rules filed by name (WoL's aiWoLMain.xs, 2026-11). Rules that check several cultures inside
# (the generic upgrade monitors, raids, forts, explorers) stay in the core.
CULTURE = {
    "European": r"Euro\w+|royalDecreeMonitor|HospitalTechs|veteranUpgradeMonitor|guardUpgradeMonitor|"
                r"royalGuardUpgradeMonitor|BuildBanks",
    "Anglo": r"NA\w+|AmericansExtraTechs|maintainCreeCoureurs",
    "American": r"LA\w+|PeruInvestmentTechs|bolivianMonitor|ageDownMonitor|paraguayanMonitor|ImmigrantsMonitor|"
                r"CACoffeeGatherPlan|FazendaGatherMonitor|ChooseCAFaction",
    "African": r"African\w+|IkhandaTechs|SpiceStallGatherPlan|ZULU_MATURING|WagonMonitor",
    "MiddleEastern": r"ME[A-Z]\w+|SaudiArmyMonitor|FountainTacticMonitor|EgyptianMonitor",
    "Asian": r"Asian\w+|HaeinsaTempleTechs|JapaneseCherryGatherPlan|disciplinedUpgradeMonitor|"
             r"honoredUpgradeMonitor|minorAsian\w+|FaithMonitor|HerdableGatherPlan|TEMPLE_OF_HEAVEN_POWER|"
             r"TAJ_MAHAL_POWER|ricepaddyMonitor|shrineMonitor|consulateMonitor|artilleryUpgradeMonitor",
    "NativeAmerican": r"championUpgradeMonitor|eliteUpgradeMonitor|warriorSocietyUpgradeMonitor|"
                      r"minorNativeChampionUpgradeMonitor|WighamMonitor|danceMonitor",
    "NationState": r"NS[A-Z]\w+|RomanianMarketTechs|Balkan\w+",
    "Polynesian": r"(?!x)x",  # the Maori AI has its own script (_TeRauparaha.xs)
}
DEFAULTS = {"void": "", "int": "return(-1);", "bool": "return(false);", "float": "return(0.0);",
            "string": 'return("");', "vector": "return(cInvalidVector);"}


def items(text):
    """Top-level items: (start, end, kind, name, type, body start). A chunk ends at the brace that
    closes its block, or at a semicolon at depth 0. Comments and strings are skipped."""
    out, i, n, depth, start, body = [], 0, len(text), 0, 0, None
    while i < n:
        c = text[i]
        if text.startswith("//", i):
            i = text.find("\n", i)
            i = n if i < 0 else i
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        if c == '"':
            i += 1
            while i < n and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
            i += 1
            continue
        if c == "{":
            if depth == 0:
                body = i
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                out.append(_item(text, start, i + 1, body))
                start, body = i + 1, None
        elif c == ";" and depth == 0:
            out.append(_item(text, start, i + 1, None))
            start = i + 1
        i += 1
    if start < n:
        out.append((start, n, "other", "", "", None))
    return out


def _strip_comments(chunk):
    chunk = re.sub(r"/\*.*?\*/", " ", chunk, flags=re.S)
    return re.sub(r"//[^\n]*", " ", chunk)


def _item(text, start, end, body):
    head = _strip_comments(text[start:body if body is not None else end])
    m = RULE_RE.match(head)
    if m and body is not None:
        return (start, end, "rule", m.group(1), "", body)
    m = FUNC_RE.match(head)
    if m and body is not None:
        return (start, end, "function", m.group(2), m.group(1), body)
    return (start, end, "other", "", "", body)


def classify(text, its):
    pattern = {c: re.compile(r"(?:%s)\Z" % p) for c, p in CULTURE.items()}
    culture = {}
    for k, (s, e, kind, name, _, _) in enumerate(its):
        if kind == "rule":
            for c, p in pattern.items():
                if p.match(name):
                    culture[k] = c
                    break
    # A function belongs to a culture when every call of it lies in that culture's items.
    funcs = {name: k for k, (s, e, kind, name, _, _) in enumerate(its) if kind == "function"}
    changed = True
    while changed:
        changed = False
        for name, k in funcs.items():
            if k in culture or name in ("main", "preInit", "postInit"):
                continue
            owners = set()
            for m in re.finditer(r"\b%s\s*\(" % re.escape(name), text):
                at = m.start()
                j = next(i for i, it in enumerate(its) if it[0] <= at < it[1])
                if j == k or (its[j][2] == "function" and its[j][3] == name):
                    continue  # its own definition, or a mutable forward one
                owners.add(culture.get(j, "core"))
            if len(owners) == 1 and "core" not in owners:
                culture[k] = owners.pop()
                changed = True
    return culture


def stub(text, item):
    s, e, kind, name, typ, body = item
    head = text[s:body]
    if kind == "rule":
        return head + "{\n   xsDisableSelf();\n}"
    return head + "{\n   " + DEFAULTS[typ] + "\n}"


def report(text, its, culture):
    total_lines, total_bytes = text.count("\n"), len(text.encode("utf-8"))
    print(f"{len(its)} top-level items, {total_lines} lines, {total_bytes} bytes")
    for c in ["core", *CULTURE]:
        ks = [k for k in range(len(its)) if culture.get(k, "core") == c]
        rules = sum(1 for k in ks if its[k][2] == "rule")
        funcs = sum(1 for k in ks if its[k][2] == "function")
        lines = sum(text.count("\n", its[k][0], its[k][1]) for k in ks)
        size = sum(len(text[its[k][0]:its[k][1]].encode("utf-8")) for k in ks)
        print(f"  {c:15s} {rules:4d} rules {funcs:4d} functions {lines:6d} lines ({100 * lines / total_lines:4.1f} %) "
              f"{size:8d} bytes ({100 * size / total_bytes:4.1f} %)")
        if c != "core":
            print("    " + " ".join(its[k][3] for k in ks))


def build(text, its, culture, keep, split):
    """(core text, {culture: rules text}). keep: a culture name or "all"."""
    core, files = [], {}
    pos = 0
    for k, it in enumerate(its):
        s, e = it[0], it[1]
        core.append(text[pos:s])
        pos = e
        c = culture.get(k)
        if c is None or keep == "all" or c == keep:
            if split and c is not None and it[2] == "rule":
                files.setdefault(c, []).append(text[s:e])
            else:
                core.append(text[s:e])
        else:
            core.append(stub(text, it))
    core.append(text[pos:])
    return "".join(core), {c: "\n".join(v) + "\n" for c, v in files.items()}


def main(argv):
    if not argv or len(argv) < 2:
        sys.exit(__doc__)
    src = Path(argv[0])
    raw = src.read_bytes()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig").replace("\r\n", "\n")
    its = items(text)
    culture = classify(text, its)
    if "--report" in argv:
        report(text, its, culture)
        return
    keep = argv[argv.index("--keep") + 1] if "--keep" in argv else sys.exit("--keep <culture|all> needed")
    if keep != "all" and keep not in CULTURE:
        sys.exit(f"unknown culture {keep}: {', '.join(CULTURE)}")

    def write(path, body):
        path.write_bytes((b"\xef\xbb\xbf" if bom else b"") + body.replace("\n", "\r\n").encode("utf-8"))
        print(f"wrote {path} ({path.stat().st_size} bytes)")

    if "--out" in argv:
        if keep == "all":
            sys.exit("--out needs one culture")
        core, _ = build(text, its, culture, keep, split=False)
        write(Path(argv[argv.index("--out") + 1]), core)
    elif "--split" in argv:
        folder = Path(argv[argv.index("--split") + 1])
        folder.mkdir(parents=True, exist_ok=True)
        core, files = build(text, its, culture, keep, split=True)
        write(folder / "aiWoLCore.xs", core)
        names = ["aiWoLCore.xs"]
        for c, body in files.items():
            write(folder / f"aiWoL{c}.xs", body)
            names.append(f"aiWoL{c}.xs")
        print("loader includes:\n" + "\n".join(f'include "{n}";' for n in names))
    else:
        sys.exit("--report, --out or --split")


if __name__ == "__main__":
    main(sys.argv[1:])
