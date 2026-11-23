"""Draws the 12 resource panel variants of a uimainnew.xml panel block as the game shows them at a resolution: the
background texture cut by its texturecoords and stretched to the gadget (the game stretches the 1024 x 768 layout
to the screen), and every formatText gadget's text with sample values in the game's number font.

    python -I preview.py --old-block <xml> --old-png <folder> --new-block <xml> --new-png <folder>
                         --font <Formal436 BT .ttf> --out <sheet.png> [--res 1920x1080] [--icons <a.png> <b.png>]

--old-png / --new-png: the panel textures as PNG (eur_max_ui.png, ...). Sample values: population 6 / 10, oil 0,
faith 120 (3 praying), export 104, food 200, wood 100, gold 100, 6 villagers (1 idle), 2 houses.
"""
import argparse
import os
import re

from PIL import Image, ImageDraw, ImageFont

VARIANTS = ["defaultPanelEurMax", "defaultPanelEurMin", "defaultPanelAsiMax", "defaultPanelAsiMin",
            "defaultPanelNatMax", "defaultPanelNatMin", "advancedPanelEurMax", "advancedPanelEurMin",
            "advancedPanelAsiMax", "advancedPanelAsiMin", "advancedPanelNatMax", "advancedPanelNatMin"]
SAMPLE = {
    "{totalPop} / {popcap}": "6 / 10", "{resource(fame)}": "0", "{resource(skillpoints)}": "120",
    "{resource(trade)}": "104", "{resource(food)}": "200", "{resource(wood)}": "100", "{resource(gold)}": "100",
    "{numGatherers(fame)}": "0", "{numGatherers(skillpoints)}": "3", "{numGatherers(trade)}": "0",
    "{numGatherers(food)}": "2", "{numGatherers(wood)}": "2", "{numGatherers(gold)}": "1",
    "{numUnits(AbstractVillager)}": "6", "{numIdle(AbstractVillager)}": "1", "{numIdle(AbstractHouse)}": "2",
    "{numDancers}": "0", "{danceQuickValue}": "",
}
TAG = re.compile(r"<gadget\b([^>]*?)(/?)>(?:([^<]*)</gadget>)?", re.S)


def attrs(s):
    return {k.lower(): v for k, v in re.findall(r'(\w+)\s*=\s*"([^"]*)"', s)}


def variants(block):
    """{variant: (panel attrs, [text gadget attrs + text])} of a SettlerCountDialog block."""
    out = {}
    starts = [(m.start(), m.group(1)) for m in re.finditer(r'<gadget\s+name="SettlerCountDialog-((?:default|advanced)Panel\w+)"', block)]
    for i, (pos, name) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else len(block)
        part = block[pos:end]
        first = TAG.search(part)
        panel = attrs(first.group(1))
        texts = []
        for m in TAG.finditer(part, first.end()):
            a = attrs(m.group(1))
            if a.get("type") == "formatText" and m.group(3):
                a["text"] = m.group(3).strip()
                texts.append(a)
        out[name] = (panel, texts)
    return out


def render(panel, texts, pngdir, font, W, H):
    sx, sy = W / 1024.0, H / 768.0
    x0, y0, x1, y1 = (float(v) for v in panel["size1024"].split())
    tex = os.path.basename(panel["background"].replace("\\", "/"))
    im = Image.open(os.path.join(pngdir, tex + ".png")).convert("RGBA")
    u0, v0, u1, v1 = (float(v) * 1024 for v in panel["texturecoords"].split())
    w, h = round((x1 - x0) * sx), round((y1 - y0) * sy)
    out = im.transform((w, h), Image.EXTENT, (u0, v0, u1, v1), Image.BILINEAR)
    bg = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    bg.alpha_composite(out)
    d = ImageDraw.Draw(bg)
    for t in texts:
        s = t["text"]
        for k, v in SAMPLE.items():
            s = s.replace(k, v)
        if not s or "{" in s:
            continue
        gx0, gy0, gx1, gy1 = (float(v) for v in t["size1024"].split())
        bx0, by0, bx1, by1 = (gx0 - x0) * sx, (gy0 - y0) * sy, (gx1 - x0) * sx, (gy1 - y0) * sy
        bb = d.textbbox((0, 0), s, font=font)
        tw, th = bb[2] - bb[0], 0.75 * font.size
        tx = bx0 + ((bx1 - bx0) - tw) / 2 if "textcenterhoriz" in t else bx0
        ty = by0 + ((by1 - by0) - th) / 2 - 0.25 * font.size if "textcentervert" in t else by0 - 0.05 * font.size
        sh = Image.new("RGBA", bg.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        for dx in (0, 1):
            sd.text((tx + 1 + dx, ty + 1), s, font=font, fill=(0, 0, 0, 128))
        bg.alpha_composite(sh)
        for dx in (0, 1):
            d.text((tx + dx, ty), s, font=font, fill=(255, 255, 255, 255))
    return bg


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--old-block", required=True)
    ap.add_argument("--old-png", required=True)
    ap.add_argument("--new-block", required=True)
    ap.add_argument("--new-png", required=True)
    ap.add_argument("--font", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--res", default="1920x1080")
    ap.add_argument("--icons", nargs=2)
    a = ap.parse_args()
    W, H = (int(v) for v in a.res.split("x"))
    font = ImageFont.truetype(a.font, 16 if W >= 1600 else 13 if W >= 1280 else 11)
    title = ImageFont.truetype(a.font, 22)
    small = ImageFont.truetype(a.font, 15)
    old = variants(open(a.old_block, encoding="utf-8").read())
    new = variants(open(a.new_block, encoding="utf-8").read())
    tiles = []
    for v in VARIANTS:
        o = render(*old[v], a.old_png, font, W, H)
        n = render(*new[v], a.new_png, font, W, H)
        tiles.append((v, o, n))
    pw = max(t[1].width for t in tiles)
    ph = max(t[1].height for t in tiles)
    gap = 16
    colw = [pw, pw, 2 * pw, 2 * pw]
    W2 = sum(colw) + gap * 5 + 170
    head = 170
    icon_h = 0
    if a.icons:
        icon_h = 260
    H2 = head + icon_h + len(tiles) * (2 * ph + gap) + gap
    sheet = Image.new("RGBA", (W2, H2), (24, 20, 18, 255))
    d = ImageDraw.Draw(sheet)
    d.text((gap, 12), "Faith row in the resource panel (#101, layout A): every variant, today and new", font=title,
           fill=(236, 226, 200, 255))
    d.text((gap, 46), f"Rendered from WoL's uimainnew.xml and the panel textures at {W}x{H} (the game stretches its "
           "1024x768 layout to the screen). Sample values: oil 0, faith 120 with 3 praying villagers, export 104,",
           font=small, fill=(190, 180, 160, 255))
    d.text((gap, 66), "food 200, wood 100, gold 100, 6 villagers (1 idle), 2 houses. The advanced variants are hidden "
           "until the player switches the panel to its detailed view.", font=small, fill=(190, 180, 160, 255))
    d.text((gap, 86), "Also fixed: Asian minimized (the population sat on the oil row and hid the oil amount: now in its "
           "header, oil shown), Native minimized (it showed an empty part of", font=small, fill=(190, 180, 160, 255))
    d.text((gap, 106), "another texture: now its own panel with icons). The faith icon is one PNG baked into the "
           "backgrounds by one command, so it can be replaced in one step.", font=small, fill=(190, 180, 160, 255))
    xs = [170 + gap]
    for w in colw[:-1]:
        xs.append(xs[-1] + w + gap)
    for x, lab in zip(xs, ["today (native size)", "new (native size)", "today (x2)", "new (x2)"]):
        d.text((x, head + icon_h - 26), lab, font=small, fill=(236, 226, 200, 255))
    y = head
    if a.icons:
        d.text((gap, y), "Icon: agent Q's praying hands (left) and the improved one (right), 128 px, and at the "
               "panel's size", font=small, fill=(236, 226, 200, 255))
        x = gap
        for p in a.icons:
            ic = Image.open(p).convert("RGBA")
            for s in (128, 64, 34, 24):
                bgt = Image.new("RGBA", (s + 16, s + 16), (40, 20, 16, 255))
                bgt.alpha_composite(ic.resize((s, s), Image.LANCZOS), (8, 8))
                sheet.alpha_composite(bgt, (x, y + 30 + (128 - s)))
                x += s + 26
            x += 60
        y += icon_h
    for v, o, n in tiles:
        d.text((gap, y + 6), v.replace("Panel", "\n"), font=small, fill=(236, 226, 200, 255))
        sheet.alpha_composite(o, (xs[0], y))
        sheet.alpha_composite(n, (xs[1], y))
        sheet.alpha_composite(o.resize((o.width * 2, o.height * 2), Image.NEAREST), (xs[2], y))
        sheet.alpha_composite(n.resize((n.width * 2, n.height * 2), Image.NEAREST), (xs[3], y))
        y += 2 * ph + gap
    sheet.convert("RGB").save(a.out)
    print("preview:", a.out, sheet.size)


if __name__ == "__main__":
    main()
