"""OPTIONAL pack. Wars of Liberty's resource panel without the oil row before the Great War (request #103): each of
the 12 variants of the panel holds two panels, <variant>-preGW (no oil row, the other rows spread over its space)
and <variant>-postGW (today's, with oil). The DLL key techGadgets shows one and hides the other by the local
player's tech GreatWarizeALL; without the key the panel is today's (postGW shown, preGW hidden).

    python apply_fix.py <WoL folder>              apply (each file it changes is copied first to
                                                  <WoL folder>\\oil-panel-backup\\; the files it adds are listed there)
    python apply_fix.py <WoL folder> --faith      the same with the faith row of wol-fixes\\faith-panel in both panels
                                                  (it includes that pack: needs the faith-panel folder next to this one)
    python apply_fix.py <WoL folder> --rates      with either mode: the income per second of each resource under its
                                                  amount and in the row's tooltip (request #105; needs the DLL key
                                                  incomeRates perSecond, and adds strings 1010111 to 1010116)
    python apply_fix.py <WoL folder> --check      say, file by file, whether it is WoL's original, this pack's version
                                                  or something else; change nothing (with --faith: that mode's files)
    python apply_fix.py <WoL folder> --restore    put the backed-up files back, byte for byte, delete the added ones
                                                  and remove the backup
    (--force: apply over files that are neither WoL 1.0.15c's nor this pack's; a folder under steamapps is refused
    unless --force is given. To switch between the two modes, --restore first. If wol-fixes\\faith-panel is
    applied, restore it first: --faith includes it.)

What it changes:
- adds art\\ui\\ingame\\eur_max_ui_pregw.ddt, ASI_UI_MAX_pregw.ddt, nat_ui_max_pregw.ddt,
  ingame_ui_small_01_asian_pregw.ddt, ingame_ui_small_01_ypack_pregw.ddt: the panel backgrounds without the oil row
  (files\\nofaith\\ or, with --faith, files\\faith\\; WoL's textures with only the panel's part changed);
- data\\uimainnew.xml: the SettlerCountDialog block (12 variants) is replaced by layout\\settlercount-gw.xml (or
  settlercount-gw-faith.xml); the rest of the file stays byte for byte. The postGW panels are those of the faith
  panel pack (its --no-faith fixes, or with --faith its faith row);
- with --faith, also what wol-fixes\\faith-panel changes: WoL's five panel textures and string 1010101.
"""
import importlib.util
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
FAITH = HERE.parent / "faith-panel"
_spec = importlib.util.spec_from_file_location("faith_apply", FAITH / "apply_fix.py")
fa = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fa)
_spec = importlib.util.spec_from_file_location("faith_layout", FAITH / "make_layout.py")
ml = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ml)

BACKUP = "oil-panel-backup"
CREATED = "created.txt"
PREGW = ["eur_max_ui_pregw", "ASI_UI_MAX_pregw", "nat_ui_max_pregw", "ingame_ui_small_01_asian_pregw",
         "ingame_ui_small_01_ypack_pregw"]


def layout_name(faith, rates):
    return "settlercount-gw" + ("-faith" if faith else "") + ("-rates" if rates else "") + ".xml"


RATE_BASE = {"food": 18397, "wood": 18419, "gold": 18420, "trade": 61365}     # each row's tooltip today
RATE_OIL = {"en": "Oil Gatherers: {numGatherers(fame)}", "es": "Recolectores de petróleo: {numGatherers(fame)}"}
RATE_LINE = {"en": "\\nIncome: +{uhcIncome(%s)} per second", "es": "\\nIngresos: +{uhcIncome(%s)} por segundo"}


def string_of(text, sid):
    m = re.search(r"<String\s+_locID\s*=\s*['\"]%d['\"][^>]*>(.*?)</String>" % sid, text, re.S)
    return m.group(1) if m else None


def set_string_id(text, sid, value):
    nl = "\r\n" if "\r\n" in text else "\n"
    quote = '"' if re.search(r'<String _locID="', text) else "'"
    entry = f"<String _locID={quote}{sid}{quote}>{value}</String>"
    pat = re.compile(r"<String\s+_locID\s*=\s*['\"]%d['\"][^>]*>(.*?)</String>" % sid, re.S)
    if pat.search(text):
        return pat.sub(lambda _: entry, text, count=1)
    m = re.search(r"\n([ \t]*)<String ", text)
    at = text.rindex("</Language>")
    line_start = text.rindex("\n", 0, at) + 1
    return text[:line_start] + (m.group(1) if m else "\t\t") + entry + nl + text[line_start:]


def rate_strings(text, lang, faith):
    """The table with the rows' tooltips plus the income line (--rates), ids RATE_IDS of make_layout."""
    for res, sid in ml.RATE_IDS.items():
        if res == "skillpoints":
            if not faith:
                continue
            base = fa.STRINGS[lang]
        elif res == "fame":
            base = RATE_OIL[lang]
        else:
            base = string_of(text, RATE_BASE[res])
            if base is None:
                sys.exit(f"string {RATE_BASE[res]} is missing from a string table")
        text = set_string_id(text, sid, base + RATE_LINE[lang] % res)
    return text


def new_files(wol, faith, rates=False):
    """{relative path: (new bytes, state of the current file)}; state 'absent' for a file this pack adds."""
    out = {}
    for name in PREGW:
        rel = f"art/ui/ingame/{name}.ddt"
        new = (HERE / "files" / ("faith" if faith else "nofaith") / rel).read_bytes()
        p = wol / rel
        out[rel] = (new, "absent" if not p.exists() else "applied" if p.read_bytes() == new else "other")
    if faith:                               # the faith panel's textures and string
        for rel, v in fa.new_files(wol).items():
            if rel != fa.LAYOUT:
                out[rel] = v
    if rates:                               # the tooltips with the income line, over the faith string if any
        for rel in fa.TABLES:
            p = wol / rel
            if not p.exists():
                continue
            raw = out[rel][0] if rel in out else p.read_bytes()
            text, kind = fa.decode(raw)
            lang = "en" if "_originals" in rel else "es" if "ES-LA" in rel else fa.language_of(text)
            new = fa.encode(rate_strings(text, lang, faith), kind)
            cur = p.read_bytes()
            out[rel] = (new, "applied" if cur == new else "original")
    text = (wol / fa.LAYOUT).read_bytes().decode("utf-8")
    a, b = fa.panel_block(text)
    block = (HERE / "layout" / layout_name(faith, rates)).read_bytes().decode("utf-8")
    cur = text[a:b]
    others = [layout_name(f, r) for f in (False, True) for r in (False, True) if (f, r) != (faith, rates)]
    if any(cur == (HERE / "layout" / n).read_bytes().decode("utf-8") for n in others):
        sys.exit("this pack is applied in another mode: run --restore first")
    state = "applied" if cur == block else "original" if fa.sha(cur.encode("utf-8")) == fa.BLOCK_SHA else "other"
    out[fa.LAYOUT] = ((text[:a] + block + text[b:]).encode("utf-8"), state)
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    wol = pathlib.Path(sys.argv[1])
    force = "--force" in sys.argv
    if "steamapps" in str(wol).lower() and not force:
        sys.exit("refused: that is the Steam install (copy it, or pass --force)")
    backup = wol / BACKUP
    if "--restore" in sys.argv:
        if not backup.exists():
            sys.exit(f"no backup in {backup}")
        created = backup / CREATED
        if created.exists():
            for rel in created.read_text(encoding="utf-8").split():
                (wol / rel).unlink(missing_ok=True)
                print("removed ", rel)
        for f in sorted(backup.rglob("*")):
            if f.is_file() and f != created:
                shutil.copy2(f, wol / f.relative_to(backup))
                print("restored", f.relative_to(backup).as_posix())
        shutil.rmtree(backup)
        return
    if (wol / fa.BACKUP).exists() and "--check" not in sys.argv:
        sys.exit(f"wol-fixes\\faith-panel is applied ({wol / fa.BACKUP}): restore it first "
                 "(this pack's --faith includes it)")
    files = new_files(wol, "--faith" in sys.argv, "--rates" in sys.argv)
    if "--check" in sys.argv:
        for rel, (_, state) in files.items():
            print(f"{state:9} {rel}")
        sys.exit(1 if any(s != "applied" for _, s in files.values()) else 0)
    other = [r for r, (_, s) in files.items() if s == "other" and not r.endswith("stringtabley.xml")]
    if other and not force:
        sys.exit("neither WoL 1.0.15c's nor this pack's (use --force to apply anyway):\n  " + "\n  ".join(other))
    for rel, (data, state) in files.items():
        if state == "applied":
            print("already  ", rel)
            continue
        keep = backup / rel
        if state == "absent":
            backup.mkdir(parents=True, exist_ok=True)
            listed = (backup / CREATED).read_text(encoding="utf-8").split() if (backup / CREATED).exists() else []
            if rel not in listed:
                (backup / CREATED).write_text("\n".join(listed + [rel]) + "\n", encoding="utf-8")
        elif not keep.exists():
            keep.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(wol / rel, keep)
        (wol / rel).parent.mkdir(parents=True, exist_ok=True)
        (wol / rel).write_bytes(data)
        print("wrote    ", rel)


if __name__ == "__main__":
    main()
