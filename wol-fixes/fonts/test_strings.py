"""Puts test texts with the Romanian and other Latin Extended-A letters into a copy's string table,
so the fonts can be checked on screen; --restore puts the table back.

    python -I test_strings.py <game folder>            # data\\stringtabley.xml gets the test texts
    python -I test_strings.py <game folder> --restore  # the original back, checked by SHA-256

Only for a test copy. The original is kept as data\\stringtabley.xml.fonttest-orig. The game reads
the table once, at startup: close it before either step.

Where the texts show (Wars of Liberty, English table):
  main menu buttons ......... 19826-19831 (Campaign, Single Player, Multiplayer, Options, More, Exit)
  skirmish setup title ...... 35898
  "Create Your Home City" ... 36437 (its title is in Monotype Corsiva)
  a Settler's panel ......... 22806 (name), 22814 (rollover text), 25708 (short rollover text)
  a Town Center's panel ..... 22841 (name), 22840 (rollover text)
  a Dutch Settler's panel ... 430006 (name), 430008 (rollover text), 430009 (short rollover text)
  Great Plains (large) ...... 43408 (name: the loading screen's title), 28599 (lobby rollover), 35943 (loading text)
  the strings of the Spanish (ES-LA) table that hold these letters keep their IDs and texts.
"""
import hashlib
import pathlib
import re
import sys
from xml.sax.saxutils import escape

UPPER = "ĀĂĄĆĈĊČĎĐĒĔĖĘĚĜĞĠĢĤĦĨĪĬĮİĲĴĶĹĻĽĿŁŃŅŇŊŌŎŐŒŔŖŘŚŜŞŠŢŤŦŨŪŬŮŰŲŴŶŸŹŻŽȘȚ"
LOWER = "āăąćĉċčďđēĕėęěĝğġģĥħĩīĭįıĳĵķĸĺļľŀłńņňŉŋōŏőœŕŗřśŝşšţťŧũūŭůűųŵŷźżžſșț"

# The ES-LA strings with ă, â, î, ș or ț (stringtabley.xml of translations\ES-LA, 2026-11-18).
ES_LA = {
    83561: "Sarja Roșior",
    6000659: "EQUIPO Arquitectura Neobrâncoveană",
    6000668: "Combate de Vânători",
    6000669: "Ataque y puntos de vida de Vânători y Carabineros aumentados.",
    6000670: "Combate de Vânători ha llegado.",
    6000672: "Ataque de Dorobanți y Călărași aumentado.",
    6000675: "Puntos de vida de Dorobanți y Călărași aumentados.",
    6000678: "Ataque y puntos de vida de Dorobanți y Călărași aumentados.",
    6000697: "Emil Racoviță",
    6000702: "Este Puesto Comercial está entregando Dorobanți.",
    6000703: "Solicitar entregas de Dorobanți en este Puesto Comercial.",
}

TESTS = {
    19826: "Ă Â Î Ș Ț ă â î ș ț",
    19827: "Sarja Roșior",
    19828: "Emil Racoviță",
    19829: "ĄĘŃŚŹŻ ąęńśźż",
    19830: "ŐŰĎĚŇŘŤŮ őűďěňřťů",
    19831: "ĽĹŔĀĒĪŪ ľĺŕāēīū",
    35898: "Ștefan Țepeș: Ăă Șș Țț Şş Ţţ",
    36437: "Țara Românească: Ăă Șș Țț",
    22806: "Călărași Roșior Şş Ţţ",
    22814: " / ".join(ES_LA.values()),
    25708: LOWER,
    22841: "Dorobanți ĢĶĻŅ ģķļņ",
    22840: UPPER + " " + LOWER,
    430006: "Călărași Roșior Şş Ţţ",
    430008: " / ".join(ES_LA.values()),
    430009: LOWER,
    43408: "Câmpia Română: Ăă Șș Țț",
    28599: UPPER + " " + LOWER,
    35943: " / ".join(ES_LA.values()),
}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main(argv):
    if not argv or argv[0].startswith("-"):
        sys.exit(__doc__)
    folder = pathlib.Path(argv[0])
    if "steamapps" in str(folder.resolve()).lower():
        sys.exit("test_strings: refusing a folder inside a Steam library; use a test copy")
    table = folder / "data" / "stringtabley.xml"
    orig = table.with_name(table.name + ".fonttest-orig")
    if "--restore" in argv:
        if not orig.exists():
            sys.exit(f"test_strings: no {orig.name}; nothing to restore")
        want = sha256(orig)
        table.write_bytes(orig.read_bytes())
        if sha256(table) != want:
            sys.exit("test_strings: the restored table differs from the original")
        orig.unlink()
        print(f"test_strings: {table} restored, SHA-256 {want}")
        return
    if not orig.exists():
        orig.write_bytes(table.read_bytes())
    raw = orig.read_bytes()
    text = raw.decode("utf-16")
    texts = dict(ES_LA)
    texts.update(TESTS)
    done = set()

    def sub(m):
        loc = int(m.group("id"))
        if loc not in texts:
            return m.group(0)
        done.add(loc)
        return m.group("head") + escape(texts[loc]) + "</String>"

    text = re.sub(r"(?P<head><String _locID=(?P<q>['\"])(?P<id>\d+)(?P=q)[^>]*>)[^<]*</String>", sub, text)
    missing = sorted(set(texts) - done)
    if missing:  # IDs the table lacks: append them before the end of the language block
        extra = "".join(f"\t\t<String _locID='{loc}'>{escape(texts[loc])}</String>\r\n" for loc in missing)
        text = text.replace("\t</Language>", extra + "\t</Language>", 1)
    table.write_bytes(b"\xff\xfe" + text.encode("utf-16-le"))
    print(f"test_strings: {len(done)} strings replaced, {len(missing)} added; original kept as {orig.name}")


if __name__ == "__main__":
    main(sys.argv[1:])
