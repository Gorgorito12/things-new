"""Draws the resource panel's 12 variants before and after the Great War (request #103) as the game shows them at a
resolution, next to WoL's panel of today: the review sheets of this pack. It uses the faith panel pack's renderer
(wol-fixes\\faith-panel\\preview.py: the background cut by its texturecoords, every formatText gadget's text with
sample values in the game's number font).

    python -I preview.py --wol <WoL folder> --png <folder> --font <Formal436 BT .ttf> --out <folder> [--res 1920x1080]

--png: the panel textures as PNG, by file name (eur_max_ui.png, eur_max_ui_pregw.png, ...), in two subfolders:
nofaith\\ (WoL's textures and files\\nofaith's) and faith\\ (the faith panel pack's and files\\faith's).
Writes oil-panel-default.png (the six default variants) and oil-panel-advanced.png (the six advanced ones); with
--rates, the layouts with the income rates (request #105, *-rates.xml) into rates-default.png and rates-advanced.png,
each text in its own size and colour.
"""
import argparse
import os
import pathlib
import re
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "faith-panel"))
import make_layout as ml  # noqa: E402
import preview as fp  # noqa: E402

DEFAULT = ["defaultPanelEurMax", "defaultPanelEurMin", "defaultPanelAsiMax", "defaultPanelAsiMin",
           "defaultPanelNatMax", "defaultPanelNatMin"]
ADVANCED = ["advancedPanelEurMax", "advancedPanelEurMin", "advancedPanelAsiMax", "advancedPanelAsiMin",
            "advancedPanelNatMax", "advancedPanelNatMin"]


def panel(block, name):
    """(attrs of the gadget named name, [its formatText gadgets' attrs + text]) of a layout block."""
    for (os_, oe, ce, d) in ml.elements(block, 0, len(block)):
        if ml.attr(block[os_:oe], "name") == name:
            part = block[os_:ce]
            first = fp.TAG.search(part)
            texts = []
            for m in fp.TAG.finditer(part, first.end()):
                a = fp.attrs(m.group(1))
                if a.get("type") == "formatText" and m.group(3):
                    a["text"] = m.group(3).strip()
                    texts.append(a)
            return fp.attrs(first.group(1)), texts
    raise KeyError(name)


RATES = {"food": "4.2", "wood": "2.8", "gold": "1.4", "fame": "0.6", "trade": "0.9", "skillpoints": "0.8"}


def render(panel, texts, pngdir, font_path, W, H):
    """fp.render with each text in its textfontsize (12 = the font of fp.render) and textcolor."""
    img = fp.render(panel, [], pngdir, None, W, H)
    sx, sy = W / 1024.0, H / 768.0
    x0, y0 = (float(v) for v in panel["size1024"].split()[:2])
    d = ImageDraw.Draw(img)
    base = 16 if W >= 1600 else 13 if W >= 1280 else 11
    for t in texts:
        s = t["text"]
        for k, v in fp.SAMPLE.items():
            s = s.replace(k, v)
        s = re.sub(r"\{uhcIncome\((\w+)\)\}", lambda m: RATES.get(m.group(1), "0.0"), s)
        if not s or "{" in s:
            continue
        size = max(6, round(base * float(t.get("textfontsize", "12")) / 12))
        f = ImageFont.truetype(font_path, size)
        col = tuple(int(c) for c in t.get("textcolor", "255 255 255").split()) + (255,)
        gx0, gy0, gx1, gy1 = (float(v) for v in t["size1024"].split())
        bx0, by0, bx1, by1 = (gx0 - x0) * sx, (gy0 - y0) * sy, (gx1 - x0) * sx, (gy1 - y0) * sy
        tw = d.textbbox((0, 0), s, font=f)[2]
        tx = bx0 + ((bx1 - bx0) - tw) / 2 if "textcenterhoriz" in t else bx0
        ty = by0 + ((by1 - by0) - 0.75 * size) / 2 - 0.25 * size if "textcentervert" in t else by0 - 0.05 * size
        d.text((tx + 1, ty + 1), s, font=f, fill=(0, 0, 0, 150))
        d.text((tx, ty), s, font=f, fill=col)
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wol", required=True)
    ap.add_argument("--png", required=True)
    ap.add_argument("--font", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--res", default="1920x1080")
    ap.add_argument("--rates", action="store_true")
    a = ap.parse_args()
    W, H = (int(v) for v in a.res.split("x"))
    font = ImageFont.truetype(a.font, 16 if W >= 1600 else 13 if W >= 1280 else 11)
    title = ImageFont.truetype(a.font, 24)
    small = ImageFont.truetype(a.font, 16)
    text = (pathlib.Path(a.wol) / "data" / "uimainnew.xml").read_text(encoding="utf-8")
    s = text.index('<gadget name="SettlerCountDialog" ')
    wol = text[s:text.rindex("</gadget>", s, text.index('<gadget name="timeDisplay"')) + len("</gadget>")]
    suffix = "-rates" if a.rates else ""
    gw = (HERE / "layout" / f"settlercount-gw{suffix}.xml").read_text(encoding="utf-8")
    gwf = (HERE / "layout" / f"settlercount-gw-faith{suffix}.xml").read_text(encoding="utf-8")
    fp.SAMPLE["{resource(fame)}"] = "150"
    fp.SAMPLE["{numGatherers(fame)}"] = "2"
    nof, fai = os.path.join(a.png, "nofaith"), os.path.join(a.png, "faith")
    cols = [("WoL today", lambda v: panel(wol, "SettlerCountDialog-" + v), nof),
            ("before GW", lambda v: panel(gw, f"SettlerCountDialog-{v}-preGW"), nof),
            ("after GW", lambda v: panel(gw, f"SettlerCountDialog-{v}-postGW"), nof),
            ("before GW, faith", lambda v: panel(gwf, f"SettlerCountDialog-{v}-preGW"), fai),
            ("after GW, faith", lambda v: panel(gwf, f"SettlerCountDialog-{v}-postGW"), fai)]
    os.makedirs(a.out, exist_ok=True)
    stem = "rates" if a.rates else "oil-panel"
    for sheet_name, variants in ((f"{stem}-default.png", DEFAULT), (f"{stem}-advanced.png", ADVANCED)):
        tiles = [[(render(*get(v), png, a.font, W, H) if a.rates else fp.render(*get(v), png, font, W, H))
                  for _, get, png in cols] for v in variants]
        pw = max(t.width for row in tiles for t in row)
        ph = max(t.height for row in tiles for t in row)
        gap, left, head = 24, 190, 150
        W2 = left + len(cols) * (pw + gap) + gap
        H2 = head + len(variants) * (ph + gap) + gap
        sheet = Image.new("RGBA", (W2, H2), (24, 20, 18, 255))
        d = ImageDraw.Draw(sheet)
        kind = "default" if variants is DEFAULT else "advanced (shown when the player switches to the detailed view)"
        d.text((gap, 12), (f"Income rates under the amounts (#105, B; per second; samples +4.2 food, +2.8 wood, "
                           f"+1.4 gold, +0.6 oil, +0.9 export, +0.8 faith): the {kind} panels at {W}x{H}" if a.rates
                           else f"Oil only after the Great War (#103): the {kind} panels at {W}x{H}"), font=title,
               fill=(236, 226, 200, 255))
        d.text((gap, 48), "Before GW: no oil row, the other rows spread over its space. After GW: today's panel (with the "
               "fixes of the faith panel pack's --no-faith: Asian minimized oil", font=small, fill=(190, 180, 160, 255))
        d.text((gap, 70), "amount, Native minimized icons). Right: the same with the optional faith row. Sample values: "
               "oil 150, faith 120, export 104, food 200, wood 100, gold 100, 6 villagers.", font=small,
               fill=(190, 180, 160, 255))
        for k, (lab, _, _) in enumerate(cols):
            d.text((left + k * (pw + gap), head - 30), lab, font=small, fill=(236, 226, 200, 255))
        for r, (v, row) in enumerate(zip(variants, tiles)):
            y = head + r * (ph + gap)
            d.text((gap, y + 6), re.sub(r"Panel", "\n", v), font=small, fill=(236, 226, 200, 255))
            for k, t in enumerate(row):
                sheet.alpha_composite(t, (left + k * (pw + gap), y))
        p = os.path.join(a.out, sheet_name)
        sheet.convert("RGB").save(p)
        print("preview:", p, sheet.size)


if __name__ == "__main__":
    main()
