"""The review sheet of a darker border on the five rank marks (border-review.png): each variant at 4 times the
texture and in the game at its real size. Private: the design is the WoL team's.

    venv/Scripts/python -I wol-fixes/veterancy-marks/trace_marks.py --out <scratch>/b<N> --border <N>   per variant
    venv/Scripts/python -I -B <aoe3-blender-tools>/tools/make_rings.py --out <scratch>/rings_b<N> --folder uhc_rings
        --rank-shapes <scratch>/b<N> --sheet <scratch>/sheet_b<N>.png                                   per variant
    venv/Scripts/python -I wol-fixes/veterancy-marks/border_review.py --scratch <scratch> --borders 0,6,12,18
        --tools <aoe3-blender-tools> [--out wol-fixes/veterancy-marks/border-review.png]

The game part: the Crossbowman cuts of marks-ingame.png (the game's own pixels, default camera, 1920x1080; nothing drawn
there today but the approved marks). For each rank the sprite of today's texture is fitted to the mark in the cut (its
size on screen and a sub-pixel offset from the HP bar's centre), then every variant's texture is drawn there as the
graphics card does: trilinear filtering over its mip levels (512 down to 64 texels), alpha blended over the cut. The
silhouette is the same in every variant, so each covers today's mark exactly and only the metal and the border differ.
"""
import argparse
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).parent
CUT_W, CUT_H, ZOOM_IN = 130, 115, 3  # marks-ingame.png: cuts of 130 x 115 game pixels shown 3 times larger
ROW2_Y = 371  # the Crossbowman row (the Hussar row has other units' marks near the bar)
CROP = (64, 50)  # game pixels around a mark in the sheet
GRASS = (96, 112, 58)
LOD_BIAS = 0.0  # the mip level's bias (--lod-bias), and whether the card blends two levels (--mip linear) or not
MIP_LINEAR = True
INK = (235, 230, 215)
BACK = (24, 22, 20)


def font(size):
    for name in ("segoeui.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def game_cuts():
    """The five Crossbowman cuts of marks-ingame.png in game pixels (float RGB)."""
    img = np.asarray(Image.open(HERE / "marks-ingame.png").convert("RGB")).astype(np.float32)
    cuts = []
    for i in range(5):
        big = img[ROW2_Y:ROW2_Y + CUT_H * ZOOM_IN, i * 400:i * 400 + CUT_W * ZOOM_IN]
        cuts.append(big[1::ZOOM_IN, 1::ZOOM_IN])
    return cuts


def bar_of(cut):
    """The centre (x, y) of the blue HP bar nearest the cut's centre, in pixel coordinates (edges at integers)."""
    r, g, b = cut[..., 0], cut[..., 1], cut[..., 2]
    blue = (b > 140) & (r < 110) & (g < 110)
    ys, xs = np.nonzero(blue)
    # the bar under the cut's centre: the rows with the most blue pixels near the middle
    near = np.abs(xs - CUT_W / 2) < 25
    ys, xs = ys[near], xs[near]
    row = np.bincount(ys).argmax()
    keep = np.abs(ys - row) <= 2
    ys, xs = ys[keep], xs[keep]
    # the bar's dark (lost hit points) part continues it: take the bar's full length from its frame
    dark = (cut.sum(axis=2) < 150)
    x0, x1 = xs.min(), xs.max() + 1
    while x1 < CUT_W and dark[row, x1]:
        x1 += 1
    return (x0 + x1) / 2, (ys.min() + ys.max() + 1) / 2


class Sprite:
    def __init__(self, ddt_bytes, ddt):
        hd = ddt.read_header(ddt_bytes)
        self.levels = [ddt.decode(ddt_bytes, k).astype(np.float32) / 255 for k in range(len(hd.levels))]
        self.size = hd.width

    def _bilinear(self, tex, u, v):
        n = tex.shape[0]
        x, y = u * n - 0.5, v * n - 0.5
        x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
        fx, fy = (x - x0)[..., None], (y - y0)[..., None]

        def at(yy, xx):
            inside = (yy >= 0) & (yy < n) & (xx >= 0) & (xx < n)
            px = tex[np.clip(yy, 0, n - 1), np.clip(xx, 0, n - 1)]
            return px * inside[..., None]  # outside the sprite: transparent
        return (at(y0, x0) * (1 - fx) * (1 - fy) + at(y0, x0 + 1) * fx * (1 - fy) +
                at(y0 + 1, x0) * (1 - fx) * fy + at(y0 + 1, x0 + 1) * fx * fy)

    def sample(self, shape, cx, cy, side):
        """The sprite of `side` screen pixels centred on (cx, cy), straight RGBA 0..1, on a shape (H, W) screen."""
        h, w = shape
        px = np.arange(w) + 0.5
        py = np.arange(h) + 0.5
        u = ((px - cx) / side + 0.5)[None, :].repeat(h, 0)
        v = ((py - cy) / side + 0.5)[:, None].repeat(w, 1)
        lod = min(max(math.log2(self.size / side) + LOD_BIAS, 0.0), len(self.levels) - 1.0)
        k0 = int(math.floor(lod))
        k1 = min(k0 + 1, len(self.levels) - 1)
        f = lod - k0
        if not MIP_LINEAR:
            k0 = k1 = int(round(lod))
            f = 0.0
        return self._bilinear(self.levels[k0], u, v) * (1 - f) + self._bilinear(self.levels[k1], u, v) * f

    def draw(self, ground, cx, cy, side, tone=None):
        """`ground` (H x W x 3, 0..255) with the sprite alpha blended over it; `tone` (gain, offset per channel)
        maps the texture's colours to the game's lit ones."""
        px4 = self.sample(ground.shape[:2], cx, cy, side)
        a = px4[..., 3:4]
        rgb = px4[..., :3] * 255
        if tone is not None:
            rgb = rgb * tone[0] + tone[1]
        return rgb * a + ground * (1 - a)


def fit_tone(sprites, cuts, placed):
    """Per channel, the gain and offset that bring today's texture to the game's pixels of the marks (the game lights
    and fogs the sprite): least squares of cut - ground share = alpha (gain x rgb + offset)."""
    gain, offset = np.ones(3), np.zeros(3)
    rows = {c: ([], []) for c in range(3)}
    for sprite, cut, (_, side, cx, cy) in zip(sprites, cuts, placed):
        px4 = sprite.sample(cut.shape[:2], cx, cy, side)
        a = px4[..., 3]
        # the ground under the mark: the cut's median around it stands in for it
        ground = np.median(cut.reshape(-1, 3), axis=0)
        keep = a > 0.05
        for c in range(3):
            target = cut[..., c] - ground[c] * (1 - a)
            rows[c][0].append(np.stack([a[keep] * px4[..., c][keep] * 255, a[keep]], axis=1))
            rows[c][1].append(target[keep])
    for c in range(3):
        m, t = np.concatenate(rows[c][0]), np.concatenate(rows[c][1])
        (gain[c], offset[c]), *_ = np.linalg.lstsq(m, t, rcond=None)
    return gain, offset


def fit(sprites, cuts, bars, scales):
    """One screen scale k (sprite side = k x make_rings' rank_scale) for all five ranks, and per rank the sprite's
    centre near its HP bar's centre, that reproduce today's marks in the cuts best."""
    def best_offset(i, side, around=None, steps=(-2.0, -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0)):
        bx, by = bars[i] if around is None else around
        best = None
        for dx in steps:
            for dy in steps:
                err = _err(sprites[i], cuts[i], bx + dx, by + dy, side)
                if best is None or err < best[0]:
                    best = (err, bx + dx, by + dy)
        return best

    best = None
    for k in np.arange(10.0, 60.0, 0.5):
        total = sum(best_offset(i, k * scales[i])[0] for i in range(5))
        if best is None or total < best[0]:
            best = (total, k)
    k = best[1]
    for step in (0.25, 0.1):
        for kk in np.arange(k - 4 * step, k + 4 * step + 1e-9, step):
            total = sum(best_offset(i, kk * scales[i])[0] for i in range(5))
            if total < best[0]:
                best = (total, kk)
        k = best[1]
    out = []
    for i in range(5):
        side = k * scales[i]
        err, cx, cy = best_offset(i, side)
        err, cx, cy = best_offset(i, side, (cx, cy), (-0.25, 0.0, 0.25))
        out.append((err, side, cx, cy))
    return k, out


def _err(sprite, cut, cx, cy, side):
    px4 = sprite.sample(cut.shape[:2], cx, cy, side)
    alpha = px4[..., 3]
    drawn = px4[..., :3] * 255 * alpha[..., None] + cut * (1 - alpha[..., None])
    diff = np.abs(drawn - cut).sum(axis=2)
    # the mean over what the sprite covers, so that a smaller sprite does not win by covering less
    return float((diff * alpha).sum() / max(alpha.sum(), 1e-3))


def crop(img, cx, cy):
    w, h = CROP
    x0 = int(round(cx - w / 2))
    y0 = int(round(cy - h * 0.72))
    return img[y0:y0 + h, x0:x0 + w]


def to_image(arr):
    return Image.fromarray(np.clip(arr + 0.5, 0, 255).astype(np.uint8))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scratch", required=True)
    ap.add_argument("--borders", default="0,6,12,18")
    ap.add_argument("--tools", required=True, help="an aoe3-blender-tools checkout (its DDT reader and make_rings)")
    ap.add_argument("--recommend", type=float, default=None)
    ap.add_argument("--lod-bias", type=float, default=0.0)
    ap.add_argument("--mip", choices=("linear", "point"), default="linear")
    ap.add_argument("--no-tone", dest="tone", action="store_false")
    ap.add_argument("--out", default=str(HERE / "border-review.png"))
    a = ap.parse_args()
    global LOD_BIAS, MIP_LINEAR
    LOD_BIAS, MIP_LINEAR = a.lod_bias, a.mip == "linear"
    sys.path.insert(0, str(pathlib.Path(a.tools) / "aoe3_blender_tools"))
    sys.path.insert(0, str(pathlib.Path(a.tools) / "tools"))
    from aoe3game import ddt
    import make_rings

    scratch = pathlib.Path(a.scratch)
    borders = [float(b) for b in a.borders.split(",")]
    names = {b: ("today (0)" if b == 0 else f"+{b:g} px") for b in borders}
    cuts = game_cuts()

    # the game part: fit today's sprites to the marks in the cuts, then draw each variant there
    make_rings.RANK_SHAPES = str(scratch / "b0")  # the sprites' sizes (the same alpha in every variant)
    scales = [make_rings.rank_scale(rank) for rank in range(1, 6)]
    bars = [bar_of(c) for c in cuts]
    sprites = {b: [Sprite((scratch / f"rings_b{b:g}" / f"icon_rank_{rank}.ddt").read_bytes(), ddt)
                   for rank in range(1, 6)] for b in borders}
    k, placed = fit(sprites[0.0], cuts, bars, scales)
    print(f"screen scale: {k:.2f} px per unit of rank_scale")
    tone = fit_tone(sprites[0.0], cuts, placed) if a.tone else None
    print(f"fit error {sum(p[0] for p in placed):.1f} (lod bias {LOD_BIAS:g}, mip {a.mip})")
    if tone is not None:
        err = 0.0
        for i, (_, side, cx, cy) in enumerate(placed):
            px4 = sprites[0.0][i].sample(cuts[i].shape[:2], cx, cy, side)
            al = px4[..., 3]
            drawn = sprites[0.0][i].draw(cuts[i], cx, cy, side, tone)
            err += float((np.abs(drawn - cuts[i]).sum(axis=2) * al).sum() / al.sum())
        print(f"error with the tone {err:.1f}")
    if tone is not None:
        print("tone: gain " + ", ".join(f"{g:.2f}" for g in tone[0]) + "; offset " + ", ".join(f"{o:.1f}" for o in tone[1]))
    ingame = {b: [] for b in borders}
    whole = {b: [] for b in borders}
    real = []
    fits = []
    for i, (err, side, cx, cy) in enumerate(placed):
        bar = bars[i]
        fits.append((i + 1, side, cx - bar[0], cy - bar[1], err))
        real.append(crop(cuts[i], bar[0], bar[1]))
        for b in borders:
            drawn = sprites[b][i].draw(cuts[i], cx, cy, side, tone)
            ingame[b].append(crop(drawn, bar[0], bar[1]))
            whole[b].append(drawn)

    zoom = 4
    fb, fs = font(22), font(17)
    label_w = 230
    x4 = {b: Image.open(scratch / f"sheet_b{b:g}.png").convert("RGB") for b in borders}
    sw, sh = x4[borders[0]].size
    grass_h = sh // 2
    cw, ch = CROP[0] * zoom, CROP[1] * zoom
    width = label_w + max(sw, 5 * (cw + 16))
    rows = [("in the game today", real)] + [(names[b], ingame[b]) for b in borders]
    rows1 = [("in the game today", cuts)] + [(names[b], whole[b]) for b in borders]
    height = 140 + len(borders) * (grass_h + 8) + 90 + len(rows) * (ch + 8) + 90 + len(rows1) * (CUT_H + 8) + 140
    sheet = Image.new("RGB", (width, height), BACK)
    d = ImageDraw.Draw(sheet)
    y = 14
    d.text((16, y), "Rank marks: a darker border, inward only. The silhouette and the loop holes do not move; the metal "
           "narrows.", fill=INK, font=fb)
    y += 32
    d.text((16, y), "Border added, in pixels of the traced image (trace_marks.py --border): today's border is about 33 to "
           "43 px there; one game pixel at the default camera is about 55 px of it.", fill=INK, font=fs)
    y += 34
    d.text((16, y), "1. Four times the texture, on grass (aoe3-blender-tools' make_rings.py --rank-shapes, --sheet)",
           fill=INK, font=fb)
    y += 36
    for b in borders:
        d.text((16, y + grass_h // 2 - 12), names[b], fill=INK, font=fb)
        sheet.paste(x4[b].crop((0, 0, sw, grass_h)), (label_w, y))
        y += grass_h + 8
    y += 16
    d.text((16, y), "2. In the game, enlarged: a Crossbowman's HP bar and mark, ranks 1 to 5, default camera, 1920x1080, "
           "each game pixel shown 4 x 4", fill=INK, font=fb)
    y += 30
    d.text((16, y), "Top row: the game's own pixels today. Below: each variant's texture drawn at the same place over "
           "them, filtered as the graphics card does (its 64-texel level), colours matched to the game's lighting.",
           fill=INK, font=fs)
    y += 30
    for label, cells in rows:
        d.text((16, y + ch // 2 - 12), label, fill=INK, font=fb)
        for i, c in enumerate(cells):
            sheet.paste(to_image(c).resize((cw, ch), Image.NEAREST), (label_w + i * (cw + 16), y))
        y += ch + 8
    y += 16
    d.text((16, y), "3. The same at the real size: one game pixel is one pixel (the whole 130 x 115 cut)", fill=INK,
           font=fb)
    y += 36
    for label, cells in rows1:
        d.text((16, y + CUT_H // 2 - 12), label, fill=INK, font=fb)
        for i, c in enumerate(cells):
            sheet.paste(to_image(c), (label_w + i * (CUT_W + 12), y))
        y += CUT_H + 8
    y += 12
    d.text((16, y), "Fit of today's sprite to the game's pixels (sprite side; its centre from the HP bar's centre, "
           "x and y):", fill=INK, font=fs)
    y += 24
    d.text((16, y), "   ".join(f"rank {r}: {s:.1f} px, {dx:+.2f}, {dy:+.2f}" for r, s, dx, dy, _ in fits),
           fill=INK, font=fs)
    if a.recommend is not None:
        y += 32
        d.text((16, y), f"Recommended: {names[a.recommend]}", fill=INK, font=fb)
    sheet = sheet.crop((0, 0, width, y + 50))
    sheet.save(a.out)
    for r, s, dx, dy, err in fits:
        print(f"rank {r}: sprite {s:.2f} px, centre {dx:+.2f}, {dy:+.2f} px from the bar's centre, error {err:.1f}")
    print(f"wrote {a.out}")


main()
