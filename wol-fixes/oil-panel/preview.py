"""Draws the resource panel's 12 variants before and after the Great War (request #103) as the game shows them at a
resolution, next to WoL's panel of today: the review sheets of this pack. It uses the faith panel pack's renderer
(wol-fixes\\faith-panel\\preview.py: the background cut by its texturecoords, every formatText gadget's text with
sample values in the game's number font).

    python -I preview.py --wol <WoL folder> --png <folder> --font <Formal436 BT .ttf> --out <folder> [--res 1920x1080]

--png: the panel textures as PNG, by file name (eur_max_ui.png, eur_max_ui_pregw.png, ...), in two subfolders:
nofaith\\ (WoL's textures and files\\nofaith's) and faith\\ (the faith panel pack's and files\\faith's).
Writes oil-panel-default.png (the six default variants) and oil-panel-advanced.png (the six advanced ones).
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wol", required=True)
    ap.add_argument("--png", required=True)
    ap.add_argument("--font", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--res", default="1920x1080")
    a = ap.parse_args()
    W, H = (int(v) for v in a.res.split("x"))
    font = ImageFont.truetype(a.font, 16 if W >= 1600 else 13 if W >= 1280 else 11)
    title = ImageFont.truetype(a.font, 24)
    small = ImageFont.truetype(a.font, 16)
    text = (pathlib.Path(a.wol) / "data" / "uimainnew.xml").read_text(encoding="utf-8")
    s = text.index('<gadget name="SettlerCountDialog" ')
    wol = text[s:text.rindex("</gadget>", s, text.index('<gadget name="timeDisplay"')) + len("</gadget>")]
    gw = (HERE / "layout" / "settlercount-gw.xml").read_text(encoding="utf-8")
    gwf = (HERE / "layout" / "settlercount-gw-faith.xml").read_text(encoding="utf-8")
    fp.SAMPLE["{resource(fame)}"] = "150"
    fp.SAMPLE["{numGatherers(fame)}"] = "2"
    nof, fai = os.path.join(a.png, "nofaith"), os.path.join(a.png, "faith")
    cols = [("WoL today", lambda v: panel(wol, "SettlerCountDialog-" + v), nof),
            ("before GW", lambda v: panel(gw, f"SettlerCountDialog-{v}-preGW"), nof),
            ("after GW", lambda v: panel(gw, f"SettlerCountDialog-{v}-postGW"), nof),
            ("before GW, faith", lambda v: panel(gwf, f"SettlerCountDialog-{v}-preGW"), fai),
            ("after GW, faith", lambda v: panel(gwf, f"SettlerCountDialog-{v}-postGW"), fai)]
    os.makedirs(a.out, exist_ok=True)
    for sheet_name, variants in (("oil-panel-default.png", DEFAULT), ("oil-panel-advanced.png", ADVANCED)):
        tiles = [[fp.render(*get(v), png, font, W, H) for _, get, png in cols] for v in variants]
        pw = max(t.width for row in tiles for t in row)
        ph = max(t.height for row in tiles for t in row)
        gap, left, head = 24, 190, 150
        W2 = left + len(cols) * (pw + gap) + gap
        H2 = head + len(variants) * (ph + gap) + gap
        sheet = Image.new("RGBA", (W2, H2), (24, 20, 18, 255))
        d = ImageDraw.Draw(sheet)
        kind = "default" if variants is DEFAULT else "advanced (shown when the player switches to the detailed view)"
        d.text((gap, 12), f"Oil only after the Great War (#103): the {kind} panels at {W}x{H}", font=title,
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
