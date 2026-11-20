"""Fit our procedural rank knots (aoe3-blender-tools' tools/make_rings.py, KNOT_SHAPES) to the WoL team's approved
reference sheet (reference-approved.webp), by the overlap of the silhouettes. Private: the reference is the team's art
and is only a measuring target here; nothing cut from it is shipped.

    venv/Scripts/python -I wol-fixes/veterancy-marks/fit_marks.py <make_rings.py> [--fit] [--out <dir>]

The reference's top row (green ground) gives each rank's silhouette: every pixel that is not the ground, the loops' holes
left empty. Ours is drawn from the knot's circles (cord and border) at 150 pixels a glyph unit, the reference's scale,
centred and standing on the same baseline. IoU = overlap / union. --fit improves KNOT_SHAPES and the cord's thickness by
coordinate descent and prints the new table; --out writes the masks and the difference images (red: reference only,
blue: ours only)."""
import argparse
import copy
import importlib.util
import pathlib

import numpy as np
from PIL import Image, ImageDraw

HERE = pathlib.Path(__file__).parent
UNIT = 150.0
COLUMNS = [(0, 340), (340, 720), (720, 1060), (1060, 1420), (1420, 1788)]
KINDS = ["loop", "trefoil", "eyes", "five", "fiveeyes"]


def reference_masks():
    img = np.asarray(Image.open(HERE / "reference-approved.webp").convert("RGB")).astype(int)[:440]
    ground = np.median(img[5:40, 5:40].reshape(-1, 3), axis=0)
    mask = np.abs(img - ground).sum(axis=2) > 75
    # close the one-pixel seams the sheet's anti-aliasing leaves inside the cord (a 3x3 dilation, then erosion)
    grow = mask.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            grow |= np.roll(np.roll(mask, dy, 0), dx, 1)
    mask = grow.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            mask &= np.roll(np.roll(grow, dy, 0), dx, 1)
    out = []
    for a, b in COLUMNS:
        m = mask[:, a:b]
        ys, xs = np.nonzero(m)
        keep = np.zeros_like(m)
        # the largest blob only (no stray noise of the ground)
        from collections import deque
        seen = np.zeros_like(m)
        best = []
        for y0, x0 in zip(ys, xs):
            if seen[y0, x0]:
                continue
            q, blob = deque([(y0, x0)]), []
            seen[y0, x0] = True
            while q:
                y, x = q.popleft()
                blob.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < m.shape[0] and 0 <= nx < m.shape[1] and m[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            if len(blob) > len(best):
                best = blob
        for y, x in best:
            keep[y, x] = True
        ys, xs = np.nonzero(keep)
        out.append(keep[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    return out


def our_mask(mr, kind, shape, width, border):
    points = mr.knot_points(kind, shape)
    r = (width + border) * UNIT
    xs = [x for x, _ in points]
    ys = [y for _, y in points]
    x0, y0 = min(xs) * UNIT - r - 2, min(ys) * UNIT - r - 2
    w, h = int(max(xs) * UNIT + r + 2 - x0) + 1, int(max(ys) * UNIT + r + 2 - y0) + 1
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    for x, y in points:
        cx, cy = x * UNIT - x0, y * UNIT - y0
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    m = np.asarray(im) > 127
    ys_, xs_ = np.nonzero(m)
    return m[ys_.min():ys_.max() + 1, xs_.min():xs_.max() + 1]


def place(ref, ours):
    """Both masks on one canvas: horizontally centred, bottoms on one line."""
    h, w = max(ref.shape[0], ours.shape[0]), max(ref.shape[1], ours.shape[1])
    a, b = np.zeros((h, w), bool), np.zeros((h, w), bool)
    for m, c in ((ref, a), (ours, b)):
        c[h - m.shape[0]:, (w - m.shape[1]) // 2:(w - m.shape[1]) // 2 + m.shape[1]] = m
    return a, b


def holes(mask):
    """The loops' holes: the empty pixels that the empty pixels at the border cannot reach."""
    from collections import deque
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


def iou(ref, ours, parts=False):
    """The silhouettes' IoU and the holes' IoU, averaged (the holes carry the loops' shapes: a blob that covers the
    reference's silhouette but not its holes is not the same knot)."""
    a, b = place(ref, ours)
    sil = (a & b).sum() / max(1, (a | b).sum())
    ha, hb = holes(a), holes(b)
    hol = (ha & hb).sum() / max(1, (ha | hb).sum())
    if parts:
        return sil, hol
    # the same outer size too: a knot wider than the reference's by thin tips barely lowers the silhouettes' IoU
    size = 1 - abs(ours.shape[1] - ref.shape[1]) / ref.shape[1] - abs(ours.shape[0] - ref.shape[0]) / ref.shape[0]
    return (sil + hol) / 2 * size


def vector(kind, shape):
    """The shape's free numbers as a flat list, and a function that puts such a list back."""
    if kind == "loop":
        keys = [("cross",), ("length",), ("width",), ("end", 0), ("end", 1), ("c1", 0), ("c1", 1), ("c2", 0), ("c2", 1)]
    else:
        keys = [("top", 0), ("top", 1), ("top", 2)]
        keys += [("tiers", i, j) for i in range(len(shape["tiers"])) for j in range(4)]
        keys += [("bar", 0), ("bar", 1), ("bar", 2)]

    def get(s, k):
        v = s[k[0]]
        for i in k[1:]:
            v = v[i]
        return v

    def put(values):
        s = copy.deepcopy(shape)
        s = {k: (list(map(list, v)) if k == "tiers" else (list(v) if isinstance(v, tuple) else v)) for k, v in s.items()}
        for k, v in zip(keys, values):
            if len(k) == 1:
                s[k[0]] = v
            elif len(k) == 2:
                s[k[0]][k[1]] = v
            else:
                s[k[0]][k[1]][k[2]] = v
        return s
    return [get(shape, k) for k in keys], put


def plausible(kind, s):
    """Keep the fit to shapes a cord can make: no loop flattened to a line, a tail bar whose ends only curve up a
    little, side loops that tilt at most 15 degrees, and the loops in their order from top to bottom."""
    if kind == "loop":
        return s["width"] >= 0.25 and s["length"] >= 0.8
    root, length, width, _ = s["top"]
    if width < 0.2 or length < 0.35:
        return False
    if not 0.05 <= s["bar"][1] <= 0.22:
        return False
    if len(s["tiers"]) > 1:  # the reference's two tiers are alike
        (l1, w1), (l2, w2) = (tuple(s["tiers"][0][1:3]), tuple(s["tiers"][1][1:3]))
        if abs(w1 - w2) > 0.2 * max(w1, w2) or abs(l1 - l2) > 0.15 * max(l1, l2):
            return False
    previous = root
    for y, tl, tw, rise, *_ in s["tiers"]:
        if tw < 0.15 or tl < 0.45 or abs(rise) > 20 or y < previous - 0.05:
            return False
        previous = y
    return True


def fit(mr, refs, rounds=8):
    shapes = {k: copy.deepcopy(mr.KNOT_SHAPES[k]) for k in KINDS}
    width, border = mr.KNOT_WIDTH, mr.KNOT_OUTLINE

    def score_all(w):
        return [iou(refs[i], our_mask(mr, k, shapes[k], w, border)) for i, k in enumerate(KINDS)]
    # the cord's thickness first, shared by every rank
    step = 0.01
    best = sum(score_all(width))
    for _ in range(12):
        moved = False
        for cand in (width - step, width + step):
            s = sum(score_all(cand))
            if s > best:
                best, width, moved = s, cand, True
        if not moved:
            step /= 2
    for i, kind in enumerate(KINDS):
        values, put = vector(kind, shapes[kind])
        tiers = 0 if kind == "loop" else len(shapes[kind]["tiers"])
        rises = {3 + 4 * n + 3 for n in range(tiers)}
        steps = [0 if isinstance(v, bool) else (2.0 if j in rises else 0.04) for j, v in enumerate(values)]
        cur = iou(refs[i], our_mask(mr, kind, put(values), width, border))
        for _ in range(rounds):
            for j, v in enumerate(values):
                if isinstance(v, bool) or steps[j] == 0:
                    continue
                for d in (-steps[j], steps[j]):
                    trial = list(values)
                    trial[j] = v + d
                    if not plausible(kind, put(trial)):
                        continue
                    try:
                        s = iou(refs[i], our_mask(mr, kind, put(trial), width, border))
                    except ValueError:
                        continue
                    if s > cur:
                        cur, values = s, trial
                        break
                else:
                    steps[j] /= 2
        shapes[kind] = put(values)
    return shapes, width


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("make_rings")
    ap.add_argument("--fit", action="store_true")
    ap.add_argument("--out")
    a = ap.parse_args()
    spec = importlib.util.spec_from_file_location("make_rings", a.make_rings)
    mr = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mr)
    refs = reference_masks()
    shapes = {k: mr.KNOT_SHAPES[k] for k in KINDS}
    width = mr.KNOT_WIDTH
    for i, k in enumerate(KINDS):
        print("rank %d (%s): IoU silhouette %.3f, holes %.3f" % ((i + 1, k) + iou(refs[i], our_mask(mr, k, shapes[k], width, mr.KNOT_OUTLINE), True)))
    if a.fit:
        shapes, width = fit(mr, refs)
        print(f"fitted: KNOT_WIDTH = {width:.3f}")
        for i, k in enumerate(KINDS):
            print("rank %d (%s): IoU silhouette %.3f, holes %.3f" % ((i + 1, k) + iou(refs[i], our_mask(mr, k, shapes[k], width, mr.KNOT_OUTLINE), True)))
        print("KNOT_SHAPES = {")
        for k in KINDS:
            s = shapes[k]
            print(f"    {k!r}: " + repr({kk: (tuple(tuple(round(x, 3) for x in t) for t in v) if kk == "tiers" else
                                          (tuple(round(x, 3) if not isinstance(x, bool) else x for x in v)
                                           if isinstance(v, (list, tuple)) else round(v, 3)))
                                     for kk, v in s.items()}) + ",")
        print("}")
    if a.out:
        out = pathlib.Path(a.out)
        out.mkdir(parents=True, exist_ok=True)
        for i, k in enumerate(KINDS):
            ref, ours = place(refs[i], our_mask(mr, k, shapes[k], width, mr.KNOT_OUTLINE))
            diff = np.zeros(ref.shape + (3,), np.uint8)
            diff[ref & ours] = (200, 200, 200)
            diff[ref & ~ours] = (230, 40, 40)
            diff[ours & ~ref] = (40, 90, 230)
            Image.fromarray(diff).save(out / f"diff_rank_{i + 1}.png")
            Image.fromarray((refs[i] * 255).astype(np.uint8)).save(out / f"reference_rank_{i + 1}.png")


main()
