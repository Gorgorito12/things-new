"""Writes the resource panel (SettlerCountDialog, 12 variants) of Wars of Liberty's data\\uimainnew.xml with a faith
row under oil (request #101, layout A), on the rows that art\\rows.json gives (the panel backgrounds rebuilt by
aoe3-blender-tools tools/panel_rows.py from art\\panel-spec.json).

    python -I make_layout.py <WoL folder> [--out layout\\settlercount.xml]

It reads WoL's own uimainnew.xml (1.0.15c: the panel block must have the SHA-256 below) and writes the new block
(the text from <gadget name="SettlerCountDialog" to the last </gadget> before timeDisplay); apply_fix.py puts it in
place of WoL's block. Nothing else of uimainnew.xml changes.

What it does to each variant:
- every gadget keeps its x, its attributes and its text; its y moves with the row it sits in: a gadget's top and
  bottom are taken relative to its row in the old background (oil, export, fire, food, wood, gold, villagers, or
  the house row / population header above them) and put at the same place in that row of the new background;
  a gadget taller than 2.2 rows (the tribute buttons) has each edge moved with its own row;
- the faith row is a copy of the variant's food row (its label button, its gatherer count if the variant shows
  counts, its value) with food replaced by skillpoints, the tooltip string FAITH_ID, the names faithLabel,
  faith, minimapPanel-faith; Asian and Native variants always get the gatherer count (left), like their food row;
- the gadgets that show oil but are named minimapPanel-trade (4 of them) are named minimapPanel-fame (no other
  file, nor the game, uses those names);
- defaultPanelAsiMin: the population moves into the header above the rows (it sat on the oil row and hid the oil
  amount, which it never showed): the oil row gets its count, label and value like the other rows;
- defaultPanelNatMin: its background was a part of nat_ui_max with no panel in it (no icons, an empty top). It
  now uses the native minimized panel that ingame_ui_small_01_ypack holds (rebuilt with faith) and the gadgets of
  defaultPanelNatMax, moved to its rows, the population in its header.
- the population of the three minimized defaults is centred in its header (textcentervert).

--no-faith writes layout\\settlercount-nofaith.xml: the same fixes (the Asian and Native minimized panels, the
renamed oil gadgets, the numbers centred in their rows) on WoL's own rows and backgrounds, without the faith row.
"""
import hashlib
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
BLOCK_SHA = "30e05cdc914ad626cc9dfa6610d355a53d7d35090a7fb199e9fc57f05d8c52d8"   # WoL 1.0.15c
FAITH_ID = 1010101
FAITH_RES = "skillpoints"
NO_FAITH = "--no-faith" in sys.argv     # the fixes only: WoL's rows, no faith row (layout\settlercount-nofaith.xml)

# variant -> (panel id in rows.json, culture). The advanced variants and the Max ones use the Max textures.
VARIANTS = {
    "defaultPanelNatMin": ("NatMin", "Nat"), "defaultPanelAsiMin": ("AsiMin", "Asi"),
    "defaultPanelAsiMax": ("AsiMax", "Asi"), "defaultPanelEurMin": ("EurMin", "Eur"),
    "defaultPanelNatMax": ("NatMax", "Nat"), "defaultPanelEurMax": ("EurMax", "Eur"),
    "advancedPanelNatMax": ("NatMax", "Nat"), "advancedPanelNatMin": ("NatMax", "Nat"),
    "advancedPanelAsiMax": ("AsiMax", "Asi"), "advancedPanelAsiMin": ("AsiMax", "Asi"),
    "advancedPanelEurMax": ("EurMax", "Eur"), "advancedPanelEurMin": ("EurMax", "Eur"),
}
# defaultPanelNatMin's new background: the native minimized panel of ingame_ui_small_01_ypack, framed as the
# Asian minimized panel (same place in its texture).
NATMIN_BACKGROUND = 'background="ui\\ingame\\ingame_ui_small_01_ypack" texturecoords="0.4296875 0.443 0.669921875 0.72"'
NATMIN_SIZE = "220 628 344 770"

TAG = re.compile(r"<gadget\b[^>]*?(/?)>|</gadget\s*>", re.S)
ATTR = lambda name: re.compile(r'(\b%s\s*=\s*")([^"]*)(")' % name, re.I)  # noqa: E731


def elements(text, start, end):
    """(open_start, open_end, close_end, depth) of every <gadget> element in text[start:end]."""
    out, stack = [], []
    for m in TAG.finditer(text, start, end):
        if m.group(0).startswith("</"):
            s, e, d = stack.pop()
            out.append((s, e, m.end(), d))
        elif m.group(1) == "/":
            out.append((m.start(), m.end(), m.end(), len(stack)))
        else:
            stack.append((m.start(), m.end(), len(stack)))
    return sorted(out)


def attr(tag, name):
    m = ATTR(name).search(tag)
    return m.group(2) if m else None


def set_attr(tag, name, value):
    m = ATTR(name).search(tag)
    if m:
        return tag[:m.start(2)] + value + tag[m.end(2):]
    return tag[:-1].rstrip("/") + f' {name}="{value}"' + ("/>" if tag.endswith("/>") else ">")


class Frame:
    """A variant's background: texture rows <-> layout rows (1024 x 768 space)."""

    def __init__(self, texcoords, size, rows, top_name):
        u0, v0, u1, v1 = (float(v) for v in texcoords.split())
        x0, y0, x1, y1 = (float(v) for v in size.split())
        self.v0, self.k = v0 * 1024, (y1 - y0) / ((v1 - v0) * 1024)
        self.y0 = y0
        top = rows[0][1]
        self.rows = [(top_name, self.v0, top)] + rows          # (name, tex top, tex bottom)

    def ly(self, ty):
        return self.y0 + (ty - self.v0) * self.k

    def ty(self, ly):
        return self.v0 + (ly - self.y0) / self.k

    def row_at(self, ly):
        t = self.ty(ly)
        for name, a, b in self.rows:
            if t < b:
                return name
        return self.rows[-1][0]

    def span(self, name):
        for n, a, b in self.rows:
            if n == name:
                return a, b
        raise KeyError(name)


def move_y(y0, y1, old, new):
    """A gadget's top and bottom from the old frame to the new one."""
    h_row = min(b - a for _, a, b in old.rows[1:]) * old.k
    if y1 - y0 > 2.2 * h_row:
        out = []
        for y in (y0, y1):
            n = old.row_at(y - 0.01 if y == y1 else y)
            a, b = old.span(n)
            c, d = new.span(n)
            out.append(new.ly(c + (old.ty(y) - a) * (d - c) / (b - a)))
        return out
    n = old.row_at((y0 + y1) / 2)
    a, b = old.span(n)
    c, d = new.span(n)
    f = lambda y: new.ly(c + (old.ty(y) - a) * (d - c) / (b - a))  # noqa: E731
    return f(y0), f(y1)


BODY = 8      # texels of rope bar (and its shadow) at the top of a row: the text sits in the rest


def remap_size(tag, old, new):
    """The tag with its size1024 moved to the new rows. A text (formatText) of a resource row is set to that row's
    body (under the rope bar) and centred in it, so every row's numbers line up with its icon."""
    s = attr(tag, "size1024")
    if not s:
        return tag
    x0, y0, x1, y1 = (int(v) for v in s.split())
    n0, n1 = move_y(y0, y1, old, new)
    h_row = min(b - a for _, a, b in old.rows[1:]) * old.k
    row = old.row_at((y0 + y1) / 2)
    if (attr(tag, "type") or "").lower() == "formattext" and y1 - y0 <= 2.2 * h_row and row not in ("top", "above"):
        a, b = new.span(row)
        n0, n1 = new.ly(a + BODY), new.ly(b)
        if "textcentervert" not in tag:
            tag = tag.replace(' z="', ' textcentervert="" z="', 1) if ' z="' in tag else tag
    return set_attr(tag, "size1024", f"{x0} {round(n0)} {x1} {round(n1)}")


def frames(spec_rows, positions, variant_tag, panel):
    pos = positions[panel]
    old_rows = spec_rows[panel]
    names = [r[0] for r in old_rows]
    tops = pos["row_tops"]
    new_rows = [(n, tops[i], tops[i + 1]) for i, n in enumerate(pos["order"])]
    tc, size = attr(variant_tag, "texturecoords"), attr(variant_tag, "size1024")
    top_name = "top"
    old = Frame(tc, size, [list(r) for r in old_rows], top_name)
    new = Frame(tc, size, new_rows, top_name)
    hdr = pos.get("header_top")
    if hdr is not None:                       # the header shrinks: its own linear map
        old.rows[0] = (top_name, hdr, old_rows[0][1])
        new.rows[0] = (top_name, hdr, tops[0])
        # the part of the texture above the header stays
        old.rows.insert(0, ("above", old.v0, hdr))
        new.rows.insert(0, ("above", new.v0, hdr))
    return old, new


def faith_from_food(chunk):
    """The food row's gadgets made into the faith row's."""
    c = chunk
    c = c.replace("SettlerCountDialog-foodLabel", "SettlerCountDialog-faithLabel")
    c = c.replace('"SettlerCountDialog-food"', '"SettlerCountDialog-faith"')
    c = c.replace("minimapPanel-dpfood", "minimapPanel-dpfaith").replace("minimapPanel-food", "minimapPanel-faith")
    c = re.sub(r'mouseovertext="[^"]*"', f'mouseovertext="$${FAITH_ID}$$"', c)
    c = c.replace("{numGatherers(food)}", "{numGatherers(%s)}" % FAITH_RES)
    c = c.replace("{resource(food)}", "{resource(%s)}" % FAITH_RES)
    c = c.replace('uiFindResourceGatherers("food")', 'uiFindResourceGatherers("%s")' % FAITH_RES)
    return c


COUNT_TEMPLATE = ('<gadget name="SettlerCountDialog-faith" type="formatText" transparent="" textcenterhoriz="" '
                  'size1024="227 {y0} 247 {y1}" anchortooltiptopright="" donthighlight="" datarefreshrate="100" '
                  'textcolor="255 255 255" textfont="NumbersFont" textfontsize="12" textcentervert="" z="9" '
                  'background="">{{numGatherers(%s)}}</gadget>' % FAITH_RES)


def build_variant(text, s, e, old, new, culture, name):
    """The variant's element text with every gadget moved and the faith row added."""
    els = elements(text, s, e)
    root = els[0]
    pieces, last = [], s
    food_chunks, oil_end, has_count = [], None, False
    for (os_, oe, ce, d) in els[1:]:
        tag = text[os_:oe]
        pieces.append(text[last:os_])
        pieces.append(remap_size(tag, old, new))
        last = oe
    pieces.append(text[last:e])
    out = "".join(pieces)
    # rename the oil values named minimapPanel-trade
    out = re.sub(r'name="minimapPanel-trade"([^>]*>\{resource\(fame\)\})', r'name="minimapPanel-fame"\1', out)
    out = re.sub(r'name="minimapPanel-trade"([^>]*mouseovertext="[^"]*fame[^"]*"[^>]*>\{resource\(fame\)\})',
                 r'name="minimapPanel-fame"\1', out)
    if NO_FAITH:
        return out
    # the food row's elements (top level children), in the moved text
    els2 = elements(out, 0, len(out))
    rootd = els2[0][3]
    food = []
    for (os_, oe, ce, d) in els2:
        if d != rootd + 1:
            continue
        chunk = out[os_:ce]
        nm = attr(out[os_:oe], "name") or ""
        if re.search(r"(SettlerCountDialog-food(Label)?|minimapPanel-(dp)?food)$", nm):
            food.append((os_, ce, chunk))
            if nm == "SettlerCountDialog-food":
                has_count = True
    if not food:
        raise SystemExit(f"{name}: no food row")
    fa, fb = new.span("food")
    ga, gb = new.span("faith")
    moved = []
    for _, _, chunk in food:
        c = faith_from_food(chunk)
        tagm = TAG.search(c)
        tag = c[tagm.start():tagm.end()]
        x0, y0, x1, y1 = (int(v) for v in attr(tag, "size1024").split())
        f = lambda y: new.ly(ga + (new.ty(y) - fa) * (gb - ga) / (fb - fa))  # noqa: E731
        tag2 = set_attr(tag, "size1024", f"{x0} {round(f(y0))} {x1} {round(f(y1))}")
        c = c[:tagm.start()] + tag2 + c[tagm.end():]
        # nested gadgets in the copy (none in WoL's food rows) would keep their y: there are none
        moved.append(c)
    if culture in ("Asi", "Nat") and not has_count:
        lab = [c for c in moved if "faithLabel" in c][0]
        y0, y1 = attr(TAG.search(lab).group(0), "size1024").split()[1::2]
        moved.insert(1, COUNT_TEMPLATE.format(y0=y0, y1=y1))
    # insert before the first food element, with the food row's indentation
    at = food[0][0]
    line_start = out.rfind("\n", 0, at) + 1
    indent = out[line_start:at] if out[line_start:at].strip() == "" else "\t\t"
    nl = "\r\n" if "\r\n" in out else "\n"
    block = "".join(m + nl + nl + indent for m in moved)
    out = out[:at] + block + out[at:]
    return out


def header_pop(out, new, name_re, x0, x1):
    """Puts the population text in the header box, centred."""
    a, b = new.span("top")
    y0, y1 = round(new.ly(a + 7)), round(new.ly(b + 2))

    def fix(m):
        tag = set_attr(m.group(0), "size1024", f"{x0} {y0} {x1} {y1}")
        if "textcentervert" not in tag:
            tag = tag.replace('textcenterhoriz=""', 'textcenterhoriz="" textcentervert=""')
        return tag
    return re.sub(r'<gadget name="%s"[^>]*>' % name_re, fix, out, count=1)


OIL_ASIMIN = ('<gadget name="SettlerCountDialog-fameLabel" type="stateButton" z="9" size1024="227 {y0} 277 {y1}" '
              'anchortooltiptopright="" mouseovertext="Oil Gatherers: {{numGatherers(fame)}}" statebuttonuseinternalstates="" '
              'activateondown="" textfont="SmallButtonFont" textfontsize="10" textcolor="255 255 255">{nl}'
              '{i}\t<command>uiFindResourceGatherers("fame")</command>{nl}{i}\t<stateentry background=""/>{nl}{i}</gadget>{nl}{nl}{i}'
              '<gadget name="SettlerCountDialog-fame" type="formatText" transparent="" textcenterhoriz="" size1024="227 {y0} 247 {y1}" '
              'anchortooltiptopright="" donthighlight="" datarefreshrate="100" textcolor="255 255 255" textfont="NumbersFont" '
              'textfontsize="12" textcentervert="" z="9" background="">{{numGatherers(fame)}}</gadget>{nl}{nl}{i}'
              '<gadget name="minimapPanel-fame" type="formatText" mouseovertext="Oil Gatherers: {{numGatherers(fame)}}" '
              'anchortooltiptopright="" size1024="283 {y0} 335 {y1}" donthighlight="" datarefreshrate="100" textcolor="255 255 255" '
              'textfont="NumbersFont" textfontsize="12" textcentervert="" z="9" background="">{{resource(fame)}}</gadget>{nl}{nl}{i}')


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    wol = pathlib.Path(sys.argv[1])
    default = "settlercount-nofaith.xml" if NO_FAITH else "settlercount.xml"
    out_path = pathlib.Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else HERE / "layout" / default
    text = (wol / "data" / "uimainnew.xml").read_bytes().decode("utf-8")
    start = text.index('<gadget name="SettlerCountDialog" ')
    stop = text.index('<gadget name="timeDisplay"')
    end = text.rindex("</gadget>", start, stop) + len("</gadget>")
    block = text[start:end]
    sha = hashlib.sha256(block.encode("utf-8")).hexdigest()
    if "--print-sha" in sys.argv:
        print(sha)
        return
    if sha != BLOCK_SHA and "--force" not in sys.argv:
        sys.exit(f"the panel block of {wol / 'data' / 'uimainnew.xml'} is not WoL 1.0.15c's (sha {sha})")
    spec = json.loads((HERE / "art" / "panel-spec.json").read_text(encoding="utf-8"))
    spec_rows = {p["id"]: [tuple(r) for r in p["rows"]] for t in spec["textures"] for p in t["panels"]}
    positions = json.loads((HERE / "art" / "rows.json").read_text(encoding="utf-8"))
    if NO_FAITH:                # WoL's own rows: the backgrounds stay as they are
        positions = {p["id"]: {"texture": t["file"], "row_tops": [r[1] for r in p["rows"]] + [p["bottom"]],
                               "order": [r[0] for r in p["rows"]], "header_top": None, "x": p["x"]}
                     for t in spec["textures"] for p in t["panels"]}
    nl = "\r\n" if "\r\n" in block else "\n"
    # top-level variants
    els = elements(block, 0, len(block))
    tops = [x for x in els if x[3] == 0]
    out, last = [], 0
    for (os_, oe, ce, d) in tops:
        tag = block[os_:oe]
        name = (attr(tag, "name") or "").replace("SettlerCountDialog-", "")
        out.append(block[last:os_])
        last = ce
        if name not in VARIANTS:
            out.append(block[os_:ce])
            continue
        panel, culture = VARIANTS[name]
        if name == "defaultPanelNatMin":
            out.append(None)               # filled after NatMax is built
            continue
        old, new = frames(spec_rows, positions, tag, panel)
        v = build_variant(block, os_, ce, old, new, culture, name)
        if name == "defaultPanelAsiMin":
            v = header_pop(v, new, "SettlerCountDialog-totalPopLeft", 271, 344)
            a, b = new.span("oil")
            y0, y1 = round(new.ly(a + 8)), round(new.ly(b))
            at = v.index('<gadget name="SettlerCountDialog-tradeLabel"')
            ls = v.rfind("\n", 0, at) + 1
            v = v[:at] + OIL_ASIMIN.format(y0=y0, y1=y1, nl=nl, i=v[ls:at]) + v[at:]
        if name == "defaultPanelEurMin" and not NO_FAITH:      # its header shrinks only with the faith row
            v = header_pop(v, new, "minimapPanel-dptotalPopLeft", 274, 347)
        if name == "defaultPanelNatMax":
            natmax = (v, tag, old, new)
        out.append(v)
    out.append(block[last:])
    # defaultPanelNatMin: defaultPanelNatMax's gadgets on the native minimized panel
    v, tag, _, nmax = natmax
    i = out.index(None)
    nat_tag = [x for x in tops if "defaultPanelNatMin" in block[x[0]:x[1]]][0]
    head = block[nat_tag[0]:nat_tag[1]]
    head = re.sub(r'background="[^"]*"\s+texturecoords="[^"]*"', lambda _: NATMIN_BACKGROUND, head)
    head = set_attr(head, "size1024", NATMIN_SIZE)
    nmin_old, nmin = frames(spec_rows, positions, head, "NatMin")
    m = TAG.match(v)
    body = v[m.end():]
    # move every gadget of the NatMax copy from NatMax's new rows to NatMin's rows (same names)
    pieces, last2 = [], 0
    for mm in TAG.finditer(body):
        if mm.group(0).startswith("</"):
            continue
        pieces.append(body[last2:mm.start()])
        t = mm.group(0)
        s = attr(t, "size1024")
        if s:
            x0, y0, x1, y1 = (int(q) for q in s.split())
            n0, n1 = move_y(y0, y1, nmax, nmin)
            t = set_attr(t, "size1024", f"{x0} {round(n0)} {x1} {round(n1)}")
        pieces.append(t)
        last2 = mm.end()
    pieces.append(body[last2:])
    natmin = head + "".join(pieces)
    natmin = header_pop(natmin, nmin, "SettlerCountDialog-totalPopLeft", 271, 344)
    out[i] = natmin
    new_block = "".join(out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(new_block.encode("utf-8"))
    print(f"make_layout: {out_path} ({len(new_block)} chars; WoL's block {len(block)})")


if __name__ == "__main__":
    main()
