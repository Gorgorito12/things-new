"""marks-ingame.png: the rank marks in the game at their real size, each cut around its unit's HP bar, enlarged 3 times,
with how far the mark's centre is from the bar's centre. Private: the design is the WoL team's.

    venv/Scripts/python -I wol-fixes/veterancy-marks/ingame_sheet.py --shots <folder>
        [--units Hussar,Crossbowman] [--out wol-fixes/veterancy-marks/marks-ingame.png]

<folder> holds native screenshots (testbed.py shot <png> 1) named <Unit>-<rank>.png, e.g. Hussar-3.png, each taken
with that unit selected and the camera centred on it (uiLookAtAndSelectUnit, uiLookAtUnit), so its HP bar is the one
over the screen's centre. Rows are the unit names in the order of --units.

The bar: its pixels in the game's colours (the player's colour, and the dark of the hit points lost), a run of 20 to 28
pixels on a row over the screen's centre; its centre is the middle of that run. The mark: every mark is symmetric about
its stem, so its centre is the axis about which the pixels above the bar match their mirror image best (whole and half
pixels, over the rows just above the bar, where nothing but the mark and the ground is). The offset is that axis minus
the bar's centre.
"""
import argparse
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).parent
CUT_W, CUT_H, ZOOM = 130, 115, 3
BAR_Y = 96  # the bar's upper row in a cut
MARK_ROWS = (64, 94)  # the rows of a cut the marks sit in (all five end the same height over the bar)
HALF = 14  # half the width of the window the symmetry is measured in
INK = (235, 230, 215)
BACK = (24, 22, 20)


def font(size):
    for name in ("segoeui.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def find_bar(img):
    """(left, right, row) of the HP bar over the screen's centre (its upper row): right is one past the last pixel."""
    h, w = img.shape[:2]
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    blue = (b > r + 40) & (b > 120)
    bar = blue | (np.maximum(np.maximum(r, g), b) < 100) & (b < r + 20)  # the colour, or the dark of hit points lost
    best = None
    x_lo = w // 2 - 120
    for y in range(h // 2 - 300, h // 2 + 60):
        row = bar[y, x_lo:w // 2 + 120]
        x = 0
        while x < len(row):
            if not row[x]:
                x += 1
                continue
            start = x
            while x < len(row) and row[x]:
                x += 1
            # a bar is 23 to 25 pixels long at this camera; the selection ring's blue arcs are not that straight
            if 20 <= x - start <= 28 and blue[y, x_lo + start:x_lo + x].any():
                centre = x_lo + (start + x) / 2
                score = (-round(abs(centre - w / 2) / 10), -y)  # the one over the screen's centre, the highest
                if best is None or score > best[0]:
                    best = (score, x_lo + start, x_lo + x, y)
    if best is None:
        raise SystemExit("ingame_sheet: no HP bar over the screen's centre")
    return best[1:]


def mark_axis(cut, bar_x):
    """The x (pixel edges at integers) about which the mark's rows mirror best, near the bar's centre."""
    rows = cut[MARK_ROWS[0]:MARK_ROWS[1]]
    best = None
    for twice in range(int(round(2 * bar_x)) - 12, int(round(2 * bar_x)) + 13):  # the axis in half pixels
        axis = twice / 2
        xs = np.arange(int(np.floor(axis - HALF)), int(np.ceil(axis + HALF)))
        mirror = (2 * axis - 1 - xs).astype(int)  # pixel x mirrors to 2 axis - 1 - x (edges at integers)
        keep = (mirror >= 0) & (mirror < cut.shape[1]) & (xs >= 0) & (xs < cut.shape[1])
        err = np.abs(rows[:, xs[keep]] - rows[:, mirror[keep]]).mean()
        if best is None or err < best[0]:
            best = (err, axis)
    return best[1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shots", required=True)
    ap.add_argument("--units", default="Hussar,Crossbowman")
    ap.add_argument("--out", default=str(HERE / "marks-ingame.png"))
    a = ap.parse_args()

    units = a.units.split(",")
    shots = []
    for unit in units:
        for rank in range(1, 6):
            path = pathlib.Path(a.shots) / f"{unit}-{rank}.png"
            if not path.exists():
                continue
            img = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
            left, right, row = find_bar(img)
            bx = (left + right) / 2
            x0, y0 = int(round(bx - CUT_W / 2)), row - BAR_Y
            cut = img[y0:y0 + CUT_H, x0:x0 + CUT_W]
            axis = mark_axis(cut, bx - x0)
            shots.append({"unit": unit, "rank": rank, "cut": cut, "bar": bx - x0, "dx": axis - (bx - x0),
                          "bar_px": right - left})
            print(f"{unit}, rank {rank}: mark {axis - (bx - x0):+.1f} px from the bar's centre (bar {right - left} px)")

    cw, ch = CUT_W * ZOOM, CUT_H * ZOOM
    f = font(15)
    rows = [u for u in units if any(s["unit"] == u for s in shots)]
    sheet = Image.new("RGB", (5 * (cw + 10), len(rows) * (ch + 26) + 26), BACK)
    d = ImageDraw.Draw(sheet)
    for ri, unit in enumerate(rows):
        for s in (s for s in shots if s["unit"] == unit):
            x, y = (s["rank"] - 1) * (cw + 10), ri * (ch + 26)
            img = Image.fromarray(np.clip(s["cut"] + 0.5, 0, 255).astype(np.uint8))
            sheet.paste(img.resize((cw, ch), Image.NEAREST), (x, y))
            tick = x + int(round(s["bar"] * ZOOM))
            d.line([(tick, y + ch), (tick, y + ch + 5)], fill=(230, 40, 40), width=2)
            d.text((x + 6, y + ch + 6), f"{unit}, rank {s['rank']}: {s['dx']:+.1f} px from the bar's centre", fill=INK,
                   font=f)
    d.text((6, sheet.height - 20), "WoL, default camera, 1920x1080, the border of 2026-11-21: each cut 130 x 115 game "
           "pixels around a unit's HP bar, shown 3 times larger, nothing drawn over the game's pixels; the red tick under "
           "each is the bar's centre.", fill=INK, font=f)
    sheet.save(a.out)
    print(f"wrote {a.out}")


if __name__ == "__main__":
    main()
