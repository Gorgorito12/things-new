"""Trace the five rank marks of the WoL team's approved sheet (reference-approved-hires.webp, 1536 x 1024 with real
alpha: ranks 1 to 3 in its first row, 4 and 5 in the second) into
smooth closed curves, and
render each as an RGBA image for aoe3-blender-tools' make_rings.py --rank-shapes. Private: the design is the team's.

    venv/Scripts/python -I wol-fixes/veterancy-marks/trace_marks.py [--out traced] [--border PX]

For each rank (the sheet's green row, which separates the dark outline from the ground best):
- a soft silhouette (how far each pixel is from the ground's green) and a soft metal mask (the bright part inside the
  dark outline), both upscaled 4 times with a bicubic filter;
- each made symmetric about the stem's axis (the mask averaged with its mirror; the axis found by correlation);
- the 0.5 level of each traced with marching squares (sub-pixel), every closed contour smoothed along its length
  (a Gaussian of SMOOTH pixels): the outer outline, the metal's edge and every loop hole; written to rank_N.json;
- rendered back from those curves (even-odd fill, supersampled): the outline's dark brown, the metal in the sheet's own
  colours, low-pass filtered, so the light band along the top of each strand and the dark underside read as on the sheet;
  written to rank_N.png, with shapes.json giving the scale (pixels per glyph unit).
Then the silhouette's and the holes' IoU against the sheet, at the sheet's resolution.

--border PX widens the dark border inward by PX pixels of rank_N.png: the metal is eroded by a disk of that radius
before the colours are laid, so the silhouette (the alpha) and the loop holes stay as they are and only the metal
narrows. The sheet's border is about 33 to 43 pixels there (0.065 glyph units); 12, the default, is the border the
owner approved on 2026-11-21 (border-review.png), a little darker in the game; 0 traces the sheet's border as it is."""
import argparse
import json
import math
import pathlib
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = pathlib.Path(__file__).parent
COLUMNS = [(0, 340), (340, 720), (720, 1060), (1060, 1420), (1420, 1788)]
ROWS = (40, 440)
UP = 2  # upscaling (the sheet is large already)
OLD_RANK1_WIDTH = 252 / 150  # rank 1's width in glyph units, as the knots and the first sheet had it
UNIT = 150.0  # the sheet's pixels per glyph unit (measured on rank 1, as make_rings' knots)
SMOOTH = 1.2  # sigma of the contour smoothing, in upscaled pixels
OUTLINE = (27, 13, 0)


def soft_masks(img):
    ground = np.median(img[5:30, 5:30].reshape(-1, 3), axis=0)
    dist = np.abs(img - ground).sum(axis=2)
    sil = np.clip((dist - 50) / 70, 0, 1)
    lum = img @ np.array([0.3, 0.59, 0.11])
    metal = sil * np.clip((lum - 70) / 45, 0, 1)
    return sil, metal


def largest_blob(mask):
    seen = np.zeros_like(mask)
    best = []
    h, w = mask.shape
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]:
            continue
        q, blob = deque([(y0, x0)]), []
        seen[y0, x0] = True
        while q:
            y, x = q.popleft()
            blob.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        if len(blob) > len(best):
            best = blob
    out = np.zeros_like(mask)
    for y, x in best:
        out[y, x] = True
    return out


def largest_blobs(mask, count):
    """The `count` largest 4-connected blobs of mask, each as a mask."""
    seen = np.zeros_like(mask)
    blobs = []
    h, w = mask.shape
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]:
            continue
        q, blob = deque([(y0, x0)]), []
        seen[y0, x0] = True
        while q:
            y, x = q.popleft()
            blob.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        blobs.append(blob)
    out = []
    for blob in sorted(blobs, key=len, reverse=True)[:count]:
        m = np.zeros_like(mask)
        for y, x in blob:
            m[y, x] = True
        out.append(m)
    return out


def up(a):
    h, w = a.shape
    return np.asarray(Image.fromarray(a.astype(np.float32), "F").resize((w * UP, h * UP), Image.BICUBIC))


def symmetric(a, axis):
    """a averaged with its mirror about column `axis` (half-integer positions allowed)."""
    w = a.shape[1]
    xs = np.arange(w)
    src = 2 * axis - xs
    lo = np.floor(src).astype(int)
    f = src - lo
    ok = (lo >= 0) & (lo + 1 < w)
    mirror = np.zeros_like(a)
    mirror[:, ok] = a[:, lo[ok]] * (1 - f[ok]) + a[:, lo[ok] + 1] * f[ok]
    return (a + mirror) / 2


def find_axis(a):
    w = a.shape[1]
    centre = (np.nonzero(a.max(axis=0) > 0.5)[0][[0, -1]].sum()) / 2
    best, axis = -1, centre
    for c in np.arange(centre - 6, centre + 6.01, 0.5):
        s = symmetric(a, c)
        score = -np.abs(s - a).sum()
        if score > best or best == -1:
            best, axis = score, c
    return axis


def marching_squares(a, level=0.5):
    """Closed contours of a at `level`: lists of (x, y) points (sub-pixel), each a loop."""
    a = np.pad(a, 1)
    h, w = a.shape
    segs = {}

    def edge_point(y0, x0, y1, x1):
        v0, v1 = a[y0, x0], a[y1, x1]
        t = (level - v0) / (v1 - v0)
        return (x0 + (x1 - x0) * t - 1, y0 + (y1 - y0) * t - 1)

    b = a > level
    codes = b[:-1, :-1] * 8 + b[:-1, 1:] * 4 + b[1:, 1:] * 2 + b[1:, :-1]
    for y, x in zip(*np.nonzero((codes != 0) & (codes != 15))):
        y, x = int(y), int(x)
        code = int(codes[y, x])
        if True:
            e = {"t": ((y, x), (y, x + 1)), "r": ((y, x + 1), (y + 1, x + 1)), "b": ((y + 1, x + 1), (y + 1, x)),
                 "l": ((y + 1, x), (y, x))}
            pairs = {1: [("l", "b")], 2: [("b", "r")], 3: [("l", "r")], 4: [("r", "t")], 5: [("l", "t"), ("r", "b")],
                     6: [("b", "t")], 7: [("l", "t")], 8: [("t", "l")], 9: [("t", "b")], 10: [("t", "r"), ("b", "l")],
                     11: [("t", "r")], 12: [("r", "l")], 13: [("r", "b")], 14: [("b", "l")]}[code]
            for p, q in pairs:
                kp = (e[p][0], e[p][1]) if e[p][0] < e[p][1] else (e[p][1], e[p][0])
                kq = (e[q][0], e[q][1]) if e[q][0] < e[q][1] else (e[q][1], e[q][0])
                segs.setdefault(kp, []).append(kq)
                segs.setdefault(kq, []).append(kp)
    loops, used = [], set()
    for start in list(segs):
        if start in used:
            continue
        loop, cur, prev = [], start, None
        while True:
            used.add(cur)
            (y0, x0), (y1, x1) = cur
            loop.append(edge_point(y0, x0, y1, x1))
            nxt = [n for n in segs[cur] if n != prev and n not in used]
            if not nxt:
                break
            prev, cur = cur, nxt[0]
        if len(loop) > 8:
            loops.append(loop)
    return loops


def smooth(loop, sigma=SMOOTH):
    p = np.array(loop)
    n = len(p)
    r = int(3 * sigma) + 1
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    out = np.zeros_like(p)
    for i, kv in enumerate(k):
        out += kv * np.roll(p, i - r, axis=0)
    return out[: n]


def fill(loops, shape, ss=2):
    """Even-odd fill of closed loops, supersampled ss times: coverage 0..1."""
    h, w = shape
    im = Image.new("L", (w * ss, h * ss), 0)
    canvas = np.zeros((h * ss, w * ss), bool)
    for loop in loops:
        layer = Image.new("1", (w * ss, h * ss), 0)
        ImageDraw.Draw(layer).polygon([((x + 0.5) * ss - 0.5, (y + 0.5) * ss - 0.5) for x, y in loop], fill=1)
        canvas ^= np.asarray(layer, bool)
    im = Image.fromarray((canvas * 255).astype(np.uint8))
    return np.asarray(im.resize((w, h), Image.BOX)).astype(np.float32) / 255


def holes(mask):
    h, w = mask.shape
    out = np.zeros_like(mask)
    q = deque([(y, x) for y in range(h) for x in (0, w - 1) if not mask[y, x]] +
              [(y, x) for x in range(w) for y in (0, h - 1) if not mask[y, x]])
    for y, x in q:
        out[y, x] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not mask[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                q.append((ny, nx))
    return ~mask & ~out


def erode(cover, radius):
    """Grey erosion of a coverage map by a disk of `radius` pixels: each pixel the least coverage within it."""
    if radius <= 0:
        return cover
    r = int(math.ceil(radius))
    h, w = cover.shape
    padded = np.pad(cover, r)
    out = cover.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= radius * radius:
                np.minimum(out, padded[r + dy:r + dy + h, r + dx:r + dx + w], out=out)
    return out


def iou(a, b):
    return (a & b).sum() / max(1, (a | b).sum())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(HERE / "traced"))
    ap.add_argument("--no-symmetry", dest="symmetry", action="store_false", help="trace the sheet as it is (to measure)")
    ap.add_argument("--border", type=float, default=12.0,
                    help="widen the dark border inward by this many pixels of rank_N.png (12, approved; 0: the sheet's)")
    a = ap.parse_args()
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    sheet = np.asarray(Image.open(HERE / "reference-approved-hires.webp").convert("RGBA")).astype(np.float32)
    alpha = sheet[..., 3] / 255
    # the five marks: the five largest blobs of the alpha, first row left to right, then the second
    blobs, seen = [], np.zeros(alpha.shape, bool)
    solid = alpha > 0.5
    small = np.asarray(Image.fromarray((solid * 255).astype(np.uint8)).resize((alpha.shape[1] // 4, alpha.shape[0] // 4)))
    lab = largest_blobs(small > 127, 5)
    marks = []
    for m in lab:
        ys, xs = np.nonzero(m)
        y0, y1, x0, x1 = ys.min() * 4 - 8, ys.max() * 4 + 12, xs.min() * 4 - 8, xs.max() * 4 + 12
        marks.append((y0 + y1 > alpha.shape[0], (x0 + x1) / 2, (max(0, y0), y1, max(0, x0), x1)))
    marks.sort()
    unit = None
    rows = []
    for rank, (_, _, (y0, y1, x0, x1)) in enumerate(marks, start=1):
        img = sheet[y0:y1, x0:x1, :3]
        lum = img @ np.array([0.3, 0.59, 0.11])
        sil = alpha[y0:y1, x0:x1]
        metal = sil * np.clip((lum - 70) / 45, 0, 1)
        keep = largest_blob(sil > 0.5)
        ys, xs = np.nonzero(keep)
        pad = 6
        box = (max(0, ys.min() - pad), ys.max() + pad + 1, max(0, xs.min() - pad), xs.max() + pad + 1)
        img, sil, metal, keep = (v[box[0]:box[1], box[2]:box[3]] for v in (img, sil, metal, keep))
        if unit is None:  # rank 1 keeps its width in glyph units
            cols_ = np.nonzero(keep.any(axis=0))[0]
            unit = (cols_[-1] + 1 - cols_[0]) / OLD_RANK1_WIDTH
        near = np.asarray(Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
        sil, metal = sil * near, metal * near  # nothing of the ground outside the mark
        usil, umetal = up(sil), up(metal)
        axis = find_axis(usil)
        if a.symmetry:
            usil, umetal = symmetric(usil, axis), symmetric(umetal, axis)
        outer = [smooth(l) for l in marching_squares(usil)]
        inner = [smooth(l) for l in marching_squares(umetal)]
        h, w = usil.shape
        cov = fill(outer, (h, w))
        met = np.minimum(fill(inner, (h, w)), cov)
        if rank == 1:  # its crossing: the sheet draws one strand over the other, which no symmetric shape keeps; close the seam
            seam = Image.fromarray((met * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))
            met = np.minimum(np.asarray(seam).astype(np.float32) / 255, cov)
        if a.border > 0:  # a wider dark border, inward only: the silhouette and the holes do not move
            met = np.minimum(erode(met, a.border), cov)
        colour = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        colour = np.asarray(colour.filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32)
        if a.symmetry:  # the colour too, so the shading matches the symmetric shape (the light band along the tops)
            colour = np.dstack([symmetric(colour[..., c], axis) for c in range(3)])
        # the metal's colour where the sheet is metal; at the metal's edge the blur mixes in the outline, so take the
        # colour of the brightest neighbour there instead (a dilation of the metal's colour)
        bright = np.asarray(Image.fromarray(colour.astype(np.uint8)).filter(ImageFilter.MaxFilter(7))).astype(np.float32)
        um = np.clip(umetal, 0, 1)[..., None]
        fillc = colour * um + bright * (1 - um)
        rgb = fillc * met[..., None] + np.array(OUTLINE, np.float32) * (1 - met[..., None])
        rgba = np.dstack([np.clip(rgb, 0, 255), cov * 255]).astype(np.uint8)
        Image.fromarray(rgba, "RGBA").save(out / f"rank_{rank}.png")
        json.dump({"outline": [l.round(2).tolist() for l in outer], "metal": [l.round(2).tolist() for l in inner],
                   "axis": axis, "size": [w, h]}, open(out / f"rank_{rank}.json", "w"))
        # the IoU against the sheet, at the sheet's resolution
        traced = np.asarray(Image.fromarray((cov * 255).astype(np.uint8)).resize(sil.shape[::-1], Image.BOX)) > 127
        refm = keep
        refs = symmetric(sil, (axis + 0.5) / UP - 0.5) > 0.5  # the sheet made symmetric: what a symmetric trace aims at
        rows.append((rank, iou(refm, traced), iou(holes(refm), holes(traced)), iou(refs, traced),
                     iou(holes(refs), holes(traced))))
    json.dump({"pixels_per_unit": unit * UP, "reference_pixels_per_unit": unit,
               "reference_boxes": [list(map(int, b)) for _, _, b in marks]}, open(out / "shapes.json", "w"))
    print("rank  silhouette IoU  holes IoU   (against the sheet made symmetric: silhouette, holes)")
    for rank, s, h, s2, h2 in rows:
        print(f"{rank:4d}  {s:14.3f}  {h:9.3f}  {s2:14.3f}  {h2:9.3f}")


main()
