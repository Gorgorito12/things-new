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

--oil-gw <rows.json> --out <file> (request #103, wol-fixes\\oil-panel): every variant becomes a holder (its name, place
and visibility, no background) of two full panels: <variant>-postGW, the panel above (shown), and <variant>-preGW
(hidden), built on rows.json's rows (the backgrounds without the oil row, written by panel_rows.py as *_pregw.ddt)
without the gadgets that show oil; a gadget of the oil row that does not show oil goes to the next row. The DLL key
techGadgets swaps them by the tech GreatWarizeALL. With --no-faith, rows.json must have no faith row; without it, one.

--rates (request #105, with the DLL key incomeRates): under each resource amount, the player's income per second
({uhcIncome(<resource>)}, green, smaller), and the row's tooltip gets a second line (strings 1010111 to 1010116,
written by wol-fixes\\oil-panel\\apply_fix.py --rates). A panel whose every row has room for two lines puts the
income under the amount; one with a lower row (the 7-row Asian and Native panels with faith, WoL's advanced Native
panel) puts it right of the amount, set to the panel's right edge, with the amounts' column a little closer to the icons
(2026-11-25), so an amount of 8 digits keeps clear of it. The amount stays at NumbersFont 12 (at 11 the game draws
another face).
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

    alias = {}            # a row this frame drops -> the row that takes its gadgets (--oil-gw: oil -> the next row)

    def span(self, name):
        name = self.alias.get(name, name)
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
    # a row of the old panel that the new one drops (the oil row before the Great War): its gadgets that stay
    # (none that show oil: drop_oil removes those) go to the next row that is kept
    kept = [n for n in names if n in pos["order"]]
    new.alias = {n: next((k for k in names[i + 1:] if k in kept), kept[-1])
                 for i, n in enumerate(names) if n not in pos["order"]}
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


def drop_oil(v):
    """The variant's text without the gadgets that show oil (resource fame): every child whose element mentions
    fame (its value, its gatherer count, its tooltip, its click), with the blank line before it."""
    els = elements(v, 0, len(v))
    rootd = els[0][3]
    cut = [(os_, ce) for (os_, oe, ce, d) in els if d == rootd + 1 and "fame" in v[os_:ce]]
    for os_, ce in reversed(cut):
        ls = v.rfind("\n", 0, os_) + 1
        end = ce
        if v[ls:os_].strip():               # not alone on its line: the element only
            ls = os_
        else:                               # its whole line, and one blank line after it
            m = re.match(r"[ \t]*\r?\n(?:[ \t]*\r?\n)?", v[ce:])
            end = ce + (m.end() if m else 0)
        v = v[:ls] + v[end:]
    return v


def build_variant(text, s, e, old, new, culture, name, pre=False):
    """The variant's element text with every gadget moved and the faith row added. pre: the panel before the
    Great War (--oil-gw): the gadgets that show oil are left out."""
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
    if pre:
        out = drop_oil(out)
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


# --rates (request #105, the DLL key incomeRates perSecond): the player's income per second of each resource
# under its amount, smaller, and in the row's tooltip. resource -> the string id of its new tooltip (the row's
# tooltip, a line break, "Income: +{uhcIncome(<resource>)} per second"; apply_fix writes them).
RATE_IDS = {"food": 1010111, "wood": 1010112, "gold": 1010113, "fame": 1010114, "trade": 1010115,
            "skillpoints": 1010116}
RATE_COLOR = "150 225 120"
RATE_UNDER_MIN = 15        # every row body of a panel at least this high (1024 x 768 units): the rate under the amount
RATE_ROOMY = 19            # and from this high the rate a size bigger (10, else 9)
RATE_COLUMN = 25           # a panel with a lower row: the rate's box starts this far right of the amount, a little lower,
RATE_EDGE = 5              # and ends this far inside the panel's right edge, its text set to the right (textjustifyright);
AMOUNT_LEFT = 5            # the amounts (and the other numbers of that column) this much closer to the icons. The amount
                           # (left) and the rate (right) grow away from each other: an amount of 8 digits keeps clear of
                           # the rate (#105, 2026-11-25: seen in game with 99,999,992 and 100,000,000)
COLUMN_VALUES = ("{numUnits(AbstractVillager)}", "{danceQuickValue}")   # in the amounts' column: moved with them
# The amount keeps NumbersFont 12: at 11 the game draws another, thinner face (seen in game).

VALUE = re.compile(r'<gadget\b[^>]*>\{resource\((\w+)\)\}</gadget>')


def add_rates(v):
    """The variant with a rate under each resource amount and the rows' tooltips pointing at RATE_IDS. One layout per
    panel, from its lowest row: under the amount when every row has room for two lines, else in a column."""
    nl = "\r\n" if "\r\n" in v else "\n"
    heights = [int(attr(m.group(0), "size1024").split()[3]) - int(attr(m.group(0), "size1024").split()[1])
               for m in VALUE.finditer(v) if m.group(1) in RATE_IDS]
    low = min(heights) if heights else 0
    right = int(attr(TAG.match(v).group(0), "size1024").split()[2]) - RATE_EDGE    # the panel's inner right edge
    column = low < RATE_UNDER_MIN
    column_x = set()
    out, last = [], 0
    for m in VALUE.finditer(v):
        res = m.group(1)
        if res not in RATE_IDS:
            continue
        tag = v[m.start():v.index(">", m.start()) + 1]
        x0, y0, x1, y1 = (int(q) for q in attr(tag, "size1024").split())
        h = y1 - y0
        size, rate_size = "12", "10" if low >= RATE_ROOMY else "9"
        justify = ""
        if not column:                     # amount in the upper part, rate in the lower part, same column
            amount = (x0, y0 + round(h * 0.5) - 12, x1, y0 + round(h * 0.5) + 2)
            rate = (x0, y0 + round(h * 0.5), x1, y0 + round(h * 0.5) + 12)
        else:                              # too low for two lines: the rate right of the amount, set to the right
            amount = (x0 - AMOUNT_LEFT, y0 - 1, x1, y1 - 1)
            rate = (x0 + RATE_COLUMN, y0 + round(h * 0.3), right, y1 + 2)
            justify = 'textjustifyright="" '
            column_x.add(x0)
        new_tag = set_attr(set_attr(tag, "size1024", " ".join(str(q) for q in amount)), "textfontsize", size)
        ls = v.rfind("\n", 0, m.start()) + 1
        indent = v[ls:m.start()] if v[ls:m.start()].strip() == "" else ""
        z = attr(tag, "z") or "12"
        rate_gadget = (f'<gadget name="uhcIncome-{res}" type="formatText" mouseovertext="$${RATE_IDS[res]}$$" '
                       f'anchortooltiptopright="" size1024="{" ".join(str(q) for q in rate)}" donthighlight="" '
                       f'datarefreshrate="100" textcolor="{RATE_COLOR}" textfont="NumbersFont" textfontsize="{rate_size}" '
                       f'textcentervert="" {justify}z="{z}" background="">+{{uhcIncome({res})}}</gadget>')
        out.append(v[last:m.start()] + new_tag + v[m.start() + len(tag):m.end()] + nl + indent + rate_gadget)
        last = m.end()
    out.append(v[last:])
    v = "".join(out)
    if column_x:                           # the other numbers of the amounts' column move with them

        def shift(m):
            x0, y0, x1, y1 = (int(q) for q in attr(m.group(1), "size1024").split())
            if x0 not in column_x:
                return m.group(0)
            return set_attr(m.group(1), "size1024", f"{x0 - AMOUNT_LEFT} {y0} {x1} {y1}") + m.group(2)
        v = re.sub(r'(<gadget\b[^>]*type="formatText"[^>]*>)(%s)' % "|".join(re.escape(c) for c in COLUMN_VALUES),
                   shift, v)
    # the tooltips of every gadget of a resource's row (its label button, its count, its amount)
    def tip(m):
        tag = m.group(1)
        for res, sid in RATE_IDS.items():
            label = "faith" if res == "skillpoints" else res
            if re.search(r'uiFindResourceGatherers\("%s"\)|\{(?:numGatherers|resource)\(%s\)\}|'
                         r'name="SettlerCountDialog-%sLabel"' % (res, res, label), m.group(1) + m.group(2)):
                return re.sub(r'mouseovertext="[^"]*"', f'mouseovertext="$${sid}$$"', tag, count=1)
        return tag
    return re.sub(r'(<gadget\b[^>]*mouseovertext="[^"]*"[^>]*>)((?:(?!<gadget\b)[\s\S])*?)(?=<gadget\b|</gadget>)',
                  lambda m: tip(m) + m.group(2), v)


def build(block, spec_rows, positions, pre=False):
    """The panel block's pieces (text between the variants, and each variant built on positions' rows) and
    {variant name: index in pieces}. pre: the panel before the Great War (no oil row, no oil gadgets)."""
    nl = "\r\n" if "\r\n" in block else "\n"
    # top-level variants
    els = elements(block, 0, len(block))
    tops = [x for x in els if x[3] == 0]
    out, last, where = [], 0, {}
    for (os_, oe, ce, d) in tops:
        tag = block[os_:oe]
        name = (attr(tag, "name") or "").replace("SettlerCountDialog-", "")
        out.append(block[last:os_])
        last = ce
        if name not in VARIANTS:
            out.append(block[os_:ce])
            continue
        where[name] = len(out)
        panel, culture = VARIANTS[name]
        if name == "defaultPanelNatMin":
            out.append(None)               # filled after NatMax is built
            continue
        old, new = frames(spec_rows, positions, tag, panel)
        v = build_variant(block, os_, ce, old, new, culture, name, pre)
        if name == "defaultPanelAsiMin":
            v = header_pop(v, new, "SettlerCountDialog-totalPopLeft", 271, 344)
            if not pre:                    # the oil row's gadgets (WoL's panel has none)
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
    return out, where


def drop_attr(tag, name):
    return re.sub(r'\s+%s\s*=\s*"[^"]*"' % name, "", tag, flags=re.I)


def two_panels(post, pre, name, pre_texture):
    """A variant as a holder (its name, place and visibility, no background) with two full panels in it:
    <variant>-postGW (today's, shown) and <variant>-preGW (no oil row, hidden, on pre_texture)."""
    nl = "\r\n" if "\r\n" in post else "\n"
    mpost, mpre = TAG.match(post), TAG.match(pre)
    root = post[:mpost.end()]
    holder = drop_attr(drop_attr(root, "background"), "texturecoords")
    full = "SettlerCountDialog-" + name
    post_tag = drop_attr(set_attr(root, "name", full + "-postGW"), "hidden")
    pre_tag = drop_attr(set_attr(pre[:mpre.end()], "name", full + "-preGW"), "hidden")
    bg = attr(pre_tag, "background").strip()
    new_bg = "ui\\ingame\\" + pathlib.PurePosixPath(pre_texture).stem
    if pathlib.PureWindowsPath(bg).name.lower() != new_bg.lower().replace("_pregw", "").split("\\")[-1]:
        raise SystemExit(f"{name}: background {bg} is not the texture of its rows ({pre_texture})")
    pre_tag = re.sub(r'(background\s*=\s*)"[^"]*"', lambda m: f'{m.group(1)}"{new_bg}"', pre_tag, count=1)
    pre_tag = pre_tag[:-1] + ' hidden="">'
    indent = "\t"
    shift = lambda s: s.replace(nl, nl + indent)  # noqa: E731
    return (holder + nl + indent + "\t" + post_tag + shift(post[mpost.end():]) + nl
            + indent + "\t" + pre_tag + shift(pre[mpre.end():]) + nl + indent + "</gadget>")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    wol = pathlib.Path(sys.argv[1])
    pregw = pathlib.Path(sys.argv[sys.argv.index("--oil-gw") + 1]) if "--oil-gw" in sys.argv else None
    default = "settlercount-nofaith.xml" if NO_FAITH else "settlercount.xml"
    if pregw and "--out" not in sys.argv:
        sys.exit("--oil-gw needs --out")
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
    out, where = build(block, spec_rows, positions)
    rates = add_rates if "--rates" in sys.argv else (lambda v: v)
    for i in where.values():
        out[i] = rates(out[i])
    if pregw:
        pre_positions = json.loads(pregw.read_text(encoding="utf-8"))
        for panel, pos in pre_positions.items():
            if "oil" in pos["order"] or ("faith" in pos["order"]) == NO_FAITH:
                sys.exit(f"{pregw}: {panel} is not a panel without oil for this mode ({pos['order']})")
        pre, _ = build(block, spec_rows, pre_positions, pre=True)
        for name, i in where.items():
            out[i] = two_panels(out[i], rates(pre[i]), name, pre_positions[VARIANTS[name][0]]["texture"])
    new_block = "".join(out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(new_block.encode("utf-8"))
    print(f"make_layout: {out_path} ({len(new_block)} chars; WoL's block {len(block)})")


if __name__ == "__main__":
    main()
