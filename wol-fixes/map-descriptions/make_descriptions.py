"""Builds descriptions.csv (what apply_fix.py writes into the game) from the map facts, the credits and
the hand-written texts. Format v2 (2026-11-18, JTMaston's request).

    python make_descriptions.py [--facts mapfacts.json] [--texts texts.csv] [--credits credits.csv]
                                [--out descriptions.csv] [--maps a,b] [--report]

Inputs:
- mapfacts.json: written by tools/mapfacts.py (trade route, natives, resources, outlaws, region, King
  of the Hill, map size), with what the game placed (game_* columns);
- texts.csv: per map, desc_en / desc_es: the description, written by hand (v2). Maps not rewritten yet
  fall back to the v1 columns (summary_* in the lobby, story_* on the loading screen). A column such as
  natives_en replaces that fact line (region, trade, koth, natives, outlaws, hunt, herd, mines,
  berries, sea; each with _en and _es);
- credits.csv: the creator of each map (creator_en / creator_es, people = how many);
- string-ids.csv: the two string IDs of every map (lobby, loading), fixed for all 208 maps.

The text, lobby and loading screen alike (the loading screen shows the map's name above the box, so
it leaves out the "<Name>: " of the lobby), one fact per line in both places (on the loading screen
since 2026-11-19, JTMaston's request):
    <Name>: <description>
    ────────                                   (a thin horizontal line, see RULE)
    Region: ...
    Trade route: ...
    King of the Hill: ...
    Natives: ...
    Outlaws: ...
    ────────
    Hunts: ...
    Herds: ...
    Mines: ...
    Berries: ...
    Fish: ...
    ────────
    Map size: 311 / 440 / 622 m (2 / 4 / 8 players)
    ────────
    Creator: ...                               (only when the map has one; never trimmed)
In the lobby lines break at 44 characters.

Markup (tested in game, 2026-11-18; README.txt, "Format v2"):
- keys bold, through a bold font entry: on the loading screen MapDescFactKey (AgeUpgradeSmall 12, 2
  pixels smaller at 1024x768), in the lobby MapDescTipKey (Tooltips_UI made bold); apply_fix.py adds
  both to FONTS\\fonts3.xml;
- key colours: white, Hunts reddish brown, Mines gold, Berries green; values on the loading screen in
  off-white (the story text there is already white), in the lobby in the rollover's own grey;
- the facts on the loading screen in a smaller font, MapDescFact (PostgameTableEntrySmall 12, 2 pixels
  smaller at 1024x768), so the box keeps room for the description at 1024x768;
- RULE: an underline over no-break spaces in a 4-pixel font (MapDescRule 4, added by apply_fix.py):
  a thin line that costs about 5 pixels, a third of a text row;
- the game drops a space right after a closing tag, so every space that must stay goes inside the tag;
- a font tag ends at the end of its line and at any </font>: each piece has its own tag.
"""
import csv
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
NL = "\\n"  # the game's line break inside a string
NB = " "

COLORS = {"key": "1,1,1", "hunts": "0.80,0.45,0.32", "mines": "0.90,0.75,0.35", "berries": "0.55,0.85,0.50"}
VALUE_COLOR = "0.85,0.85,0.85"  # loading screen only
FONTS = {"lobby": {"key": "MapDescTipKey", "value": None},
         "loading": {"key": "MapDescFactKey", "value": "MapDescFact"}}
RULE_WIDTH = {"lobby": 130, "loading": 150}  # no-break spaces: about the box width at 1024x768


def rule(place):
    return f"<font=MapDescRule 4><u>{NB * RULE_WIDTH[place]}</u></font>"


WORDS = {
    "en": {"region": "Region:", "trade": "Trade route:", "koth": "King of the Hill:", "natives": "Natives:",
           "outlaws": "Outlaws:", "hunts": "Hunts:", "herds": "Herds:", "mines": "Mines:", "berries": "Berries:",
           "fish": "Fish:", "size": "Map size:", "creator": "Creator:", "creators": "Creators:",
           "yes": "Yes", "no": "No", "none": "none", "none_f": "none", "players": "players"},
    "es": {"region": "Región:", "trade": "Ruta comercial:", "koth": "Rey de la Colina:", "natives": "Nativos:",
           "outlaws": "Forajidos:", "hunts": "Animales de caza:", "herds": "Rebaños:", "mines": "Minas:",
           "berries": "Bayas:", "fish": "Peces:", "size": "Tamaño del mapa:", "creator": "Creador:",
           "creators": "Creadores:", "yes": "Sí", "no": "No", "none": "ninguno", "none_f": "ninguna",
           "players": "jugadores"},
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


MAX_ITEMS = 5  # a longer list ends in "…"


def cap(names):
    names = [n for n in names if n]
    return ", ".join(names[:MAX_ITEMS]) + (", …" if len(names) > MAX_ITEMS else "")


def short(names):
    """'Silver Mine, Gold Mine' -> 'Silver, Gold'; 'Fish - Tuna' -> 'Tuna'."""
    out = []
    for n in [x.strip() for x in names.split(",") if x.strip()]:
        for cut in (" Mine", "Mina de ", "Fish - ", "Pez - ", "Pescado - "):
            n = n.replace(cut, "")
        out.append(n[:1].upper() + n[1:])
    return cap(list(dict.fromkeys(out)))


def played(f):
    """True when the map was checked in game: its descriptions use what the game placed."""
    return bool(f.get("game_trade_route"))


def fact(f, key, lang):
    return f.get(f"game_{key}_{lang}", "") if played(f) else f.get(f"{key}_{lang}", "")


def natives(f, lang):
    """The natives the game placed, or, when the script picks them per game, the script's list marked
    as varying. WoL's African trade sites are grouped under one label."""
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
            if len(others) > MAX_ITEMS:
                out.append(f"{', '.join(others[:MAX_ITEMS])}{more} ({vary})")
            else:
                out.append(f"{', '.join(others[:-1])}{word}{others[-1]} ({vary})")
        else:
            out.append(cap(others))
    if sites:
        label = "African trade sites" if lang == "en" else "Puestos comerciales africanos"
        rnd = (" (random)" if lang == "en" else " (al azar)") if varies and len(sites) > 1 else ""
        out.append(f"{label}{rnd}: {cap(sites)}")
    return "; ".join(out)


def facts_blocks(f, t, credit, lang):
    """The fact lines as blocks of [(kind, label, value)], kind = colour key ('key', 'hunts', ...)."""
    w = WORDS[lang]
    col = {"en": 0, "es": 1}[lang]

    def pick(key, default):
        v = t.get(f"{key}_{lang}", "").strip()
        return v or default

    route = f["game_trade_route"] if played(f) else f["trade_route"]
    region = REGIONS.get(f["region"], (f["region"], f["region"]))[col]
    fish = short(", ".join(x for x in (fact(f, "fish", lang), fact(f, "whale", lang)) if x))
    sea = pick("sea", fish)
    general = [
        ("key", w["region"], pick("region", region)),
        ("key", w["trade"], pick("trade", w["no"] if route == "No" else w["yes"])),
        ("key", w["koth"], pick("koth", w["yes"] if f["koth"] == "Yes" else w["no"])),
        ("key", w["natives"], pick("natives", natives(f, lang) or w["none"])),
        ("key", w["outlaws"], pick("outlaws", f[f"outlaws_{lang}"] or w["none"])),
    ]
    resources = [
        ("hunts", w["hunts"], pick("hunt", short(fact(f, "hunt", lang)) or w["none"])),
        ("key", w["herds"], pick("herd", short(fact(f, "herd", lang)) or w["none"])),
        ("mines", w["mines"], pick("mines", short(fact(f, "mine", lang)) or w["none_f"])),
        ("berries", w["berries"], pick("berries", short(fact(f, "berry", lang)) or w["none_f"])),
        ("key", w["fish"], sea if sea and sea != "-" else w["none"]),
    ]
    blocks = [general, resources]
    size = f.get(f"map_size_{lang}", "")
    if size:
        blocks.append([("key", w["size"], size)])
    if credit:
        blocks.append([("key", w["creators"] if credit[1] > 1 else w["creator"], credit[0])])
    return blocks


def key_tag(kind, label, place):
    return f"<font={FONTS[place]['key']}><color={COLORS[kind]}>{label} </color></font>"


def value_tag(text, place):
    if place == "lobby":
        return text
    return f"<font={FONTS[place]['value']}><color={VALUE_COLOR}>{text}</color></font>"


# --- the lobby --------------------------------------------------------------------------------------
LOBBY_WIDTH = 44  # characters per lobby line, so the rollover stays narrow


def wrap_words(text, first, width):
    """Words (split at plain spaces only: a no-break space keeps its neighbours together) into lines."""
    lines, cur, room = [], "", first
    for word in [w for w in re.split(r"[ \t\r\n]+", text) if w]:
        if cur and len(cur) + 1 + len(word) > room:
            lines.append(cur)
            cur, room = word, width
        else:
            cur = f"{cur} {word}" if cur else word
    return lines + ([cur] if cur else [])


def lobby_text(name, desc, blocks):
    """The rollover opens to the right of the mouse and grows up to about 55 characters; with lines of
    at most 44 characters the box stays narrow enough not to be cut by the screen edge."""
    out = wrap_words(f"{name}: {desc}" if name and not desc.startswith(name) else desc, LOBBY_WIDTH, LOBBY_WIDTH)
    for block in blocks:
        out.append(rule("lobby"))
        for kind, label, value in block:
            # "... 622 m (2 / 4 / 8 players)": no-break spaces keep "622 m" and the parenthesis whole
            # (lobby only: in the loading screen's font a no-break space is wider than a space)
            if re.search(r" m \(.*\)$", value):  # and "275 x 400" whole
                value = re.sub(r" m \((.*)\)$", lambda m: f"{NB}m ({m.group(1).replace(' ', NB)})", value)
                value = value.replace(" x ", f"{NB}x{NB}")
            words = wrap_words(value, LOBBY_WIDTH - len(label) - 1, LOBBY_WIDTH) or [""]
            out.append(key_tag(kind, label, "lobby") + words[0])
            out.extend(words[1:])
    return NL.join(out)


# --- the loading screen -----------------------------------------------------------------------------
# The box (gadget RMSetup-MapDetail, scaled with the screen), measured in game on 2026-11-19: for the
# description (SPLoadingScreenText 14) and the facts (MapDescFact and MapDescFactKey, added by
# apply_fix.py), (row height, font size, wrap width), all in pixels, and the cost of a rule. Anything
# after the last row is cut off. At 1920x1080 the game takes the fonts' ResX="1280" sizes. At 1024x768
# description lines of up to 324 pixels fitted and one of 327 wrapped; the facts' width keeps 4 pixels for
# the rounding at their size (width() is within 1% there); at 1920x1080 a line of 598 fitted. A bold
# key counts one pixel more per character (measured: 0.5 to 0.9). WoL's box is 328 x 216 at 1024x768;
# apply_fix.py installs data\uirmsetup.xml, where it is 328 x 326 (STOCK_BOX gives the old heights,
# --stock-box).
BOXES = {"1024x768": {"height": 326, "story": (17, 14, 324), "facts": (12, 10, 318), "rule": 5},
         "1920x1080": {"height": 458, "story": (21, 16, 590), "facts": (17, 14, 590), "rule": 7}}
MARGIN = 4  # pixels a text leaves free at the bottom of the box
STOCK_BOX = {"1024x768": 216, "1920x1080": 304}
if "--stock-box" in sys.argv:
    for _box, _h in STOCK_BOX.items():
        BOXES[_box]["height"] = _h

# Advance widths of the loading screen's typeface (Formal436 BT, the TypeFace of SPLoadingScreenText and
# of the facts fonts) in thousandths of an em, read from the game's own font file; the game rounds each
# one to whole pixels, as width() does (checked in game: equal to the pixel at 1024x768). A character
# not listed (drawn from a fallback font, such as ō) counts 600.
ADVANCE = {
    ' ': 282, '!': 292, '"': 300, '#': 769, '$': 565, '%': 856, '&': 681, "'": 155, '(': 319, ')': 319,
    '*': 500, '+': 833, ',': 282, '-': 310, '.': 282, '/': 278, '0': 565, '1': 565, '2': 565, '3': 565,
    '4': 565, '5': 565, '6': 565, '7': 565, '8': 565, '9': 565, ':': 282, ';': 282, '<': 833, '=': 833,
    '>': 833, '?': 509, '@': 1000, 'A': 671, 'B': 625, 'C': 699, 'D': 711, 'E': 611, 'F': 556, 'G': 736,
    'H': 741, 'I': 294, 'J': 292, 'K': 650, 'L': 495, 'M': 889, 'N': 736, 'O': 764, 'P': 593, 'Q': 764,
    'R': 644, 'S': 593, 'T': 579, 'U': 708, 'V': 671, 'W': 968, 'X': 634, 'Y': 644, 'Z': 611, '[': 319,
    '\\': 278, ']': 319, '^': 1000, '_': 500, '`': 500, 'a': 602, 'b': 600, 'c': 523, 'd': 602, 'e': 556,
    'f': 377, 'g': 602, 'h': 590, 'i': 259, 'j': 259, 'k': 537, 'l': 229, 'm': 958, 'n': 620, 'o': 583,
    'p': 604, 'q': 602, 'r': 458, 's': 514, 't': 398, 'u': 620, 'v': 502, 'w': 773, 'x': 542, 'y': 532,
    'z': 519, '{': 500, '|': 500, '}': 500, '~': 833, '¡': 292, '¿': 509, 'Á': 671, 'É': 611, 'Í': 294,
    'Ñ': 736, 'Ó': 764, 'Ú': 708, 'Ü': 708, 'á': 602, 'ã': 602, 'ç': 523, 'é': 556, 'í': 259, 'ñ': 620,
    'ó': 583, 'ú': 620, 'ü': 620, '…': 1000, '\xa0': 565,
}


def width(text, size, bold=False):
    """Pixels of `text` in the loading screen's typeface at `size` pixels (bold: one more per character)."""
    return sum(round(ADVANCE.get(c, 600) * size / 1000) + bold for c in text)


def wrapped_rows(words, size, room):
    """Rows of [(word, bold)] wrapped at `room` pixels on the spaces between words, as the game does."""
    n, line = 1, 0
    for word, bold in words:
        w = width(word, size, bold)
        gap = width(" ", size, bold) if line else 0
        if line and line + gap + w > room:
            n, line = n + 1, w
        else:
            line += gap + w
    return n


def split_words(text, bold=False):
    return [(w, bold) for w in re.split(r"[ \t\r\n]+", text) if w]


def loading_lines(blocks):
    """[(kind of row, [(word, bold)], markup)] of the facts on the loading screen: one fact per row, in
    the lobby's order (JTMaston, 2026-11-19: "line breaks after each key value pair like the lobby
    ones")."""
    rows = []
    for block in blocks:
        rows.append(("rule", [], None))
        for kind, label, value in block:
            markup = key_tag(kind, label, "loading") + value_tag(value, "loading")
            rows.append(("facts", split_words(label, True) + split_words(value), markup))
    return rows


def loading_height(story, rows, box):
    b = BOXES[box]
    h = wrapped_rows(split_words(story), *b["story"][1:]) * b["story"][0] if story else 0
    for kind, words, _ in rows:
        h += b["rule"] if kind == "rule" else wrapped_rows(words, *b["facts"][1:]) * b["facts"][0]
    return h


def fit_loading(desc, blocks):
    """The loading text: the description, then the facts. If it does not fit the box at 1024x768 (or
    1920x1080), the description's last sentences go first; the facts and the creator always stay.
    Returns (text, what was cut)."""
    sentences = [s for s in re.split(r"(?<=[.!?])\s+", desc.strip()) if s]
    rows = loading_lines(blocks)
    cut = []
    while True:
        story = " ".join(sentences)
        if all(loading_height(story, rows, box) <= BOXES[box]["height"] - MARGIN for box in BOXES):
            break
        if len(sentences) > 1:
            sentences, cut = sentences[:-1], cut + ["a sentence"]
        else:
            cut.append("still too long")
            break
    text = NL.join(([story] if story else []) + [rule("loading") if k == "rule" else m for k, _, m in rows])
    return text, ", ".join(cut)


def main():
    facts = {r["map"]: r for r in json.load(open(arg("--facts", HERE / "mapfacts.json"), encoding="utf-8"))}
    texts = list(csv.DictReader(open(arg("--texts", HERE / "texts.csv"), encoding="utf-8", newline="")))
    ids = {r["map"]: r for r in csv.DictReader(open(HERE / "string-ids.csv", encoding="utf-8", newline=""))}
    credits = {r["map"]: r for r in csv.DictReader(open(arg("--credits", HERE / "credits.csv"), encoding="utf-8", newline=""))}
    only = set(arg("--maps", "").split(",")) - {""}
    rows, report = [], []
    for t in texts:
        m = t["map"]
        if only and m not in only:
            continue
        f, i = facts[m], ids[m]
        row = {"map": m, "lobby_id": i["lobby_id"], "loading_id": i["loading_id"]}
        for lang in ("en", "es"):
            c = credits.get(m)
            credit = (c[f"creator_{lang}"], int(c["people"])) if c else None
            blocks = facts_blocks(f, t, credit, lang)
            name = f[f"name_{lang}"].strip('"')
            desc = (t.get(f"desc_{lang}") or "").strip()
            if desc:  # v2: one description for both places
                lobby_desc, loading_desc = desc, desc
            else:     # not rewritten yet: the v1 sentences
                lobby_desc, loading_desc = t[f"summary_{lang}"].strip(), t[f"story_{lang}"].strip()
            row[f"lobby_{lang}"] = lobby_text(name, lobby_desc, blocks)
            row[f"loading_{lang}"], row[f"trim_{lang}"] = fit_loading(loading_desc, blocks)
            report.append((m, lang, row[f"trim_{lang}"]))
        rows.append(row)
    out = pathlib.Path(arg("--out", HERE / "descriptions.csv"))
    with open(out, "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, ["map", "lobby_id", "loading_id", "lobby_en", "loading_en", "lobby_es", "loading_es"],
                           extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows)} maps -> {out}")
    if "--report" in sys.argv:
        for m, lang, trim in report:
            if trim:
                print(f"  {m} ({lang}): {trim}")
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
