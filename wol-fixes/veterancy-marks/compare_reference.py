"""compare-reference.png: the team's sheet (top row), the traced marks (middle), the traced marks at 50 % over the sheet
(bottom), each rank in its box of the sheet at the sheet's scale, on grass. Private: the design is the team's.

    venv/Scripts/python -I wol-fixes/veterancy-marks/compare_reference.py [--traced traced] [--out compare-reference.png]

The boxes are shapes.json's reference_boxes; a traced mark (rank_N.png, UP times the sheet) is scaled back to the sheet
and put where its alpha covers the sheet's best (a search over whole pixels)."""
import argparse
import json
import pathlib

import numpy as np
from PIL import Image

HERE = pathlib.Path(__file__).parent
GRASS = np.array((92, 107, 47), np.float32)
LINE = (28, 28, 28)
GAP = 12


def over(ground, rgba, opacity=1.0):
    a = rgba[..., 3:4] / 255 * opacity
    return rgba[..., :3] * a + ground * (1 - a)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--traced", default=str(HERE / "traced"))
    ap.add_argument("--out", default=str(HERE / "compare-reference.png"))
    a = ap.parse_args()
    traced = pathlib.Path(a.traced)
    shapes = json.load(open(traced / "shapes.json"))
    up = shapes["pixels_per_unit"] / shapes["reference_pixels_per_unit"]
    sheet = np.asarray(Image.open(HERE / "reference-approved-hires.webp").convert("RGBA")).astype(np.float32)
    boxes = shapes["reference_boxes"]
    height = max(y1 - y0 for y0, y1, _, _ in boxes)
    width = sum(x1 - x0 for _, _, x0, x1 in boxes) + GAP * (len(boxes) - 1)
    out = np.zeros((3 * height + 2 * GAP, width, 3), np.float32) + np.array(LINE, np.float32)
    x = 0
    for rank, (y0, y1, x0, x1) in enumerate(boxes, start=1):
        ref = sheet[y0:y1, x0:x1]
        h, w = ref.shape[:2]
        mark = Image.open(traced / f"rank_{rank}.png").convert("RGBA")
        mark = np.asarray(mark.resize((round(mark.width / up), round(mark.height / up)), Image.BOX)).astype(np.float32)
        mh, mw = mark.shape[:2]
        best = None
        for dy in range(0, max(1, h - mh + 1)):
            for dx in range(0, max(1, w - mw + 1)):
                score = np.minimum(ref[dy:dy + mh, dx:dx + mw, 3], mark[:h - dy, :w - dx, 3]).sum()
                if best is None or score > best[0]:
                    best = (score, dy, dx)
        _, dy, dx = best
        ours = np.zeros_like(ref)
        ours[dy:dy + mh, dx:dx + mw] = mark[:h - dy, :w - dx]
        ground = np.zeros((h, w, 3), np.float32) + GRASS
        rows = [over(ground, ref), over(ground, ours), over(over(ground, ref), ours, 0.5)]
        for r, cell in enumerate(rows):
            top = r * (height + GAP) + (height - h)
            out[r * (height + GAP):(r + 1) * (height + GAP) - GAP, x:x + w] = GRASS
            out[top:top + h, x:x + w] = cell
        x += w + GAP
    Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8)).save(a.out)
    print(f"wrote {a.out}")


if __name__ == "__main__":
    main()
