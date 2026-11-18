"""Builds descriptions.csv (what apply_fix.py writes into the game) from the map facts and the
hand-written texts.

    python make_descriptions.py [--facts mapfacts.json] [--texts texts.csv] [--out descriptions.csv]

- mapfacts.json: written by tools/mapfacts.py (trade route, natives, resources, outlaws, region, KOTH);
- texts.csv: per map, the sentences written by hand (summary_en/es: one line for the lobby;
  story_en/es: 2-3 sentences for the loading screen) and, where the facts need a correction, a
  column that replaces that fact line (region, trade, koth, natives, outlaws, hunt, herd, mines,
  berries, sea; each with _en and _es);
- string-ids.csv: the two string IDs of every map (lobby, loading), fixed once for all 208 maps.

The facts block follows the template:
    <summary>
    Region: ... | Trade route: ... | King of the Hill: ...
    Natives: ...
    Outlaws: ...
    Hunt: ... | Herd: ...
    Mines: ... | Berries: ...
    Sea: ...                  (only on maps with fish or whales)
The lobby text is the summary and the block; the loading text adds the story before the block.
"""
import csv
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
# The labels in gold (tested in the lobby and loading screen). The game drops a space that follows
# </color>, so the space after the label goes inside the tag; LABEL already ends with it.
LABEL = "<color=0.95,0.78,0.42>{} </color>"
NL = "\\n"  # the game's line break inside a string

WORDS = {
    "en": {"region": "Region:", "trade": "Trade route:", "koth": "King of the Hill:", "natives": "Natives:",
           "outlaws": "Outlaws:", "hunt": "Hunt:", "herd": "Herd:", "mines": "Mines:", "berries": "Berries:",
           "sea": "Sea:", "yes": "Yes", "no": "No", "none": "none", "none_f": "none", "water": "water", "random": "random"},
    "es": {"region": "Región:", "trade": "Ruta comercial:", "koth": "Rey de la Colina:", "natives": "Nativos:",
           "outlaws": "Forajidos:", "hunt": "Caza:", "herd": "Ganado:", "mines": "Minas:", "berries": "Bayas:",
           "sea": "Mar:", "yes": "Sí", "no": "No", "none": "ninguno", "none_f": "ninguna", "water": "acuática",
           "random": "al azar"},
}
REGIONS = {
    "America N": ("North America", "Norteamérica"), "America S": ("South America", "Sudamérica"),
    "Europe": ("Europe", "Europa"), "Africa": ("Africa", "África"), "Middle East": ("Middle East", "Oriente Medio"),
    "Asia": ("Asia", "Asia"), "Oceania": ("Oceania", "Oceanía"),
    "Indian Subcontinent": ("Indian Subcontinent", "Subcontinente indio"), "Space": ("Space", "Espacio"),
    "Other": ("Other", "Otro"),
}


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def short(names, lang):
    """'Silver Mine, Gold Mine' -> 'Silver, Gold'; 'Fish - Tuna' -> 'Tuna'."""
    out = []
    for n in [x.strip() for x in names.split(",") if x.strip()]:
        for cut in (" Mine", "Mina de ", "Fish - ", "Pez - ", "Pescado - "):
            n = n.replace(cut, "")
        out.append(n[:1].upper() + n[1:])
    return cap(list(dict.fromkeys(out)))


MAX_ITEMS = 5  # a longer list ends in "…", so a line stays short enough for the loading box


def cap(names):
    names = [n for n in names if n]
    return ", ".join(names[:MAX_ITEMS]) + (", …" if len(names) > MAX_ITEMS else "")


def played(f):
    """True when the map was checked in game: its descriptions use what the game placed."""
    return bool(f.get("game_trade_route"))


def fact(f, key, lang):
    """A resource list as the game placed it (game_*), or the script's when there was no run."""
    return f.get(f"game_{key}_{lang}", "") if played(f) else f.get(f"{key}_{lang}", "")


def natives(f, lang):
    """The natives: the villages the game placed, or, when the script picks them per game, the
    script's list marked as varying. WoL's African trade sites are grouped under one label."""
    if played(f):
        names, varies = f[f"game_natives_{lang}"], f.get("game_natives_varies") == "yes"
    else:
        names, varies = f[f"natives_{lang}"], f.get("natives_varies") == "yes"
    names = [n for n in names.split(", ") if n]
    tag = " (trade site)" if lang == "en" else " (puesto comercial)"
    sites = [n[:-len(tag)] for n in names if n.endswith(tag)]
    others = [n for n in names if not n.endswith(tag)]
    out = []
    if others:
        if varies and len(others) > 1:
            word, more, vary = (" or ", " or others", "varies") if lang == "en" else (" o ", " u otros", "varía")
            if len(others) > MAX_ITEMS:   # "A, B, C, D, E or others (varies)"
                out.append(f"{', '.join(others[:MAX_ITEMS])}{more} ({vary})")
            else:                         # "A, B or C (varies)"
                out.append(f"{', '.join(others[:-1])}{word}{others[-1]} ({vary})")
        else:
            out.append(cap(others))
    if sites:
        label = "African trade sites" if lang == "en" else "Puestos comerciales africanos"
        rnd = (" (random)" if lang == "en" else " (al azar)") if varies and len(sites) > 1 else ""
        out.append(f"{label}{rnd}: {cap(sites)}")
    return "; ".join(out)


def facts_lines(f, t, lang, compact=False):
    """The fact lines. compact (the loading screen): lists of at most 3, and King of the Hill only
    when the map has it, so the block fits the loading box at 1024x768."""
    global MAX_ITEMS
    saved, MAX_ITEMS = MAX_ITEMS, (3 if compact else MAX_ITEMS)
    try:
        return _facts_lines(f, t, lang, compact)
    finally:
        MAX_ITEMS = saved


def _facts_lines(f, t, lang, compact):
    w = WORDS[lang]
    col = {"en": 0, "es": 1}[lang]

    def pick(key, default):
        v = t.get(f"{key}_{lang}", "").strip()
        return v or default

    route = f["game_trade_route"] if played(f) else f["trade_route"]
    trade = w["no"] if route == "No" else w["yes"]
    region = REGIONS.get(f["region"], (f["region"], f["region"]))[col]
    outlaws = f[f"outlaws_{lang}"] or w["none"]
    koth = pick("koth", w["yes"] if f["koth"] == "Yes" else w["no"])
    sea = short(", ".join(x for x in (fact(f, "fish", lang), fact(f, "whale", lang)) if x), lang)
    lines = [
        " | ".join([f"{LABEL.format(w['region'])}{pick('region', region)}",
                    f"{LABEL.format(w['trade'])}{pick('trade', trade)}"]
                   + ([] if compact and koth == w["no"] else [f"{LABEL.format(w['koth'])}{koth}"])),
        f"{LABEL.format(w['natives'])}{pick('natives', natives(f, lang) or w['none'])}",
        f"{LABEL.format(w['outlaws'])}{pick('outlaws', outlaws)}",
        f"{LABEL.format(w['hunt'])}{pick('hunt', short(fact(f, 'hunt', lang), lang) or w['none_f'])} | "
        f"{LABEL.format(w['herd'])}{pick('herd', short(fact(f, 'herd', lang), lang) or w['none'])}",
        f"{LABEL.format(w['mines'])}{pick('mines', short(fact(f, 'mine', lang), lang) or w['none_f'])} | "
        f"{LABEL.format(w['berries'])}{pick('berries', short(fact(f, 'berry', lang), lang) or w['none_f'])}",
    ]
    sea = pick("sea", sea)
    if sea and sea != "-":
        lines.append(f"{LABEL.format(w['sea'])}{sea}")
    return lines


# The loading screen's text box, measured in game: at 1920x1080 about 80 characters by 15 lines, at
# 1024x768 about 45 characters by 12 lines (the font keeps its size; the box shrinks). The text must
# fit the smaller one, so the widths below are on the safe side.
BOXES = {"1024x768": (43, 12), "1920x1080": (76, 15)}


def est_lines(text, width):
    """Lines the game needs for a text: "\\n" breaks, words wrap at `width` characters."""
    total = 0
    for part in re.sub(r"<[^>]+>", "", text).split(NL):
        line, n = 0, 1
        for word in part.split():
            if line and line + 1 + len(word) > width:
                n, line = n + 1, len(word)
            else:
                line += (1 if line else 0) + len(word)
        total += n
    return total


LOBBY_WIDTH = 44  # characters per lobby line, so the rollover stays narrow (see narrow())


def wrap_words(text, first, width):
    """Plain words into lines: the first line has `first` characters, the others `width`."""
    lines, cur, room = [], "", first
    for word in text.split():
        if cur and len(cur) + 1 + len(word) > room:
            lines.append(cur)
            cur, room = word, width
        else:
            cur = f"{cur} {word}" if cur else word
    return lines + ([cur] if cur else [])


def narrow(text):
    """The lobby text with its own line breaks every LOBBY_WIDTH characters. The rollover opens to
    the right of the mouse and grows up to about 460 px (55 characters at 1920x1080); hovering the
    right half of the minimap, the screen edge then cuts it. With shorter lines the box is narrower
    and fits. "A | B" pairs go on separate lines; a label keeps its colour tag."""
    out = []
    for line in text.split(NL):
        parts = line.split(" | ")
        for part in parts:
            m = re.match(r"(<color=[^>]*>[^<]*</color>)(.*)$", part)
            label, value = (m.group(1), m.group(2)) if m else ("", part)
            shown = len(re.sub(r"<[^>]+>", "", label))
            words = wrap_words(value, LOBBY_WIDTH - shown, LOBBY_WIDTH) or [""]
            out.append(label + words[0])
            out.extend(words[1:])
    return NL.join(out)


def fits(text):
    return all(est_lines(text, w) <= h for w, h in BOXES.values())


def fit_loading(story, credit, block):
    """The loading text: the story (the lobby's first line is not repeated: the screen shows the
    map's name above it), the credit, then the facts. If it does not fit the smaller box, the credit
    goes first, then the story's last sentences; the facts always stay. Returns (text, what was cut)."""
    sentences = re.split(r"(?<=[.!?])\s+", story)
    lines = block.split(NL)
    cut = []
    while True:
        text = NL.join(([" ".join(sentences) + credit] if sentences else []) + lines)
        if fits(text):
            return text, ", ".join(cut)
        if credit:
            credit, cut = "", cut + ["credit"]
        elif len(sentences) > 1:
            sentences, cut = sentences[:-1], cut + ["a sentence"]
        elif len(lines) > 5:          # the Sea line is the least needed on the loading screen
            lines, cut = lines[:5], cut + ["sea line"]
        elif sentences:
            sentences, cut = [], cut + ["story"]
        else:
            return text, ", ".join(cut + ["still too long"])


def main():
    facts = {r["map"]: r for r in json.load(open(arg("--facts", HERE / "mapfacts.json"), encoding="utf-8"))}
    texts = list(csv.DictReader(open(arg("--texts", HERE / "texts.csv"), encoding="utf-8", newline="")))
    ids = {r["map"]: r for r in csv.DictReader(open(HERE / "string-ids.csv", encoding="utf-8", newline=""))}
    rows = []
    for t in texts:
        m = t["map"]
        f, i = facts[m], ids[m]
        row = {"map": m, "lobby_id": i["lobby_id"], "loading_id": i["loading_id"]}
        for lang in ("en", "es"):
            block = NL.join(facts_lines(f, t, lang))
            row[f"lobby_{lang}"] = t[f"summary_{lang}"].strip() + NL + block
            # the loading screen's box shows about 15 lines of 80 characters and cuts the rest: no
            # empty line between the story and the block
            compact = NL.join(facts_lines(f, t, lang, compact=True))
            credit = (t.get("credit") or "").strip()
            credit = (f" Map by {credit}." if lang == "en" else f" Mapa de {credit}.") if credit else ""
            row[f"loading_{lang}"], row[f"trim_{lang}"] = fit_loading(t[f"story_{lang}"].strip(), credit, compact)
            if credit:  # the lobby has room: the author's credit always ends it
                row[f"lobby_{lang}"] += NL + credit.strip()
            row[f"lobby_{lang}"] = narrow(row[f"lobby_{lang}"])
        rows.append(row)
    out = pathlib.Path(arg("--out", HERE / "descriptions.csv"))
    with open(out, "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, ["map", "lobby_id", "loading_id", "lobby_en", "loading_en", "lobby_es", "loading_es"],
                           extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows)} maps -> {out}")
    # the same strings as <String> lines, for a team that prefers to paste them by hand
    for lang in ("en", "es"):
        lines = []
        for r in rows:
            for key in ("lobby", "loading"):
                text = r[f"{key}_{lang}"].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                lines.append(f"\t\t<String _locID='{r[key + '_id']}'>{text}</String>")
        (out.parent / f"strings-{lang}.xml").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
