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
    return ", ".join(dict.fromkeys(out))


def facts_lines(f, t, lang):
    w = WORDS[lang]
    col = {"en": 0, "es": 1}[lang]

    def pick(key, default):
        v = t.get(f"{key}_{lang}", "").strip()
        return v or default

    trade = w["no"] if f["trade_route"] == "No" else w["yes"] + (f" ({w['water']})" if "(water)" in f["trade_route"] else "")
    region = REGIONS.get(f["region"], (f["region"], f["region"]))[col]
    outlaws = f[f"outlaws_{lang}"] or w["none"]
    sea = short(", ".join(x for x in (f[f"fish_{lang}"], f[f"whale_{lang}"]) if x), lang)
    lines = [
        " | ".join([f"{LABEL.format(w['region'])}{pick('region', region)}",
                    f"{LABEL.format(w['trade'])}{pick('trade', trade)}",
                    f"{LABEL.format(w['koth'])}{pick('koth', w['yes'] if f['koth'] == 'Yes' else w['no'])}"]),
        f"{LABEL.format(w['natives'])}{pick('natives', f[f'natives_{lang}'] or w['none'])}",
        f"{LABEL.format(w['outlaws'])}{pick('outlaws', outlaws)}",
        f"{LABEL.format(w['hunt'])}{pick('hunt', short(f[f'hunt_{lang}'], lang) or w['none_f'])} | "
        f"{LABEL.format(w['herd'])}{pick('herd', short(f[f'herd_{lang}'], lang) or w['none'])}",
        f"{LABEL.format(w['mines'])}{pick('mines', short(f[f'mine_{lang}'], lang) or w['none_f'])} | "
        f"{LABEL.format(w['berries'])}{pick('berries', short(f[f'berry_{lang}'], lang) or w['none_f'])}",
    ]
    sea = pick("sea", sea)
    if sea and sea != "-":
        lines.append(f"{LABEL.format(w['sea'])}{sea}")
    return lines


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
            row[f"loading_{lang}"] = t[f"summary_{lang}"].strip() + " " + t[f"story_{lang}"].strip() + NL + block
        rows.append(row)
    out = pathlib.Path(arg("--out", HERE / "descriptions.csv"))
    with open(out, "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, ["map", "lobby_id", "loading_id", "lobby_en", "loading_en", "lobby_es", "loading_es"])
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
