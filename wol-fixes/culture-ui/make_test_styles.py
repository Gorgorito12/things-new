"""Makes PROVISIONAL test styles for the key cultureUI: the minimised interface's atlases recoloured for two families
(Asian `as`, Middle Eastern `me`), each with a Great War variant (`_gw`). They only show that the key switches the
textures; they are not art for the mod and are not kept in the repository.

    <aoe3-blender-tools>\\venv\\Scripts\\python.exe -I make_test_styles.py <WoL folder> <out folder>
        [--tools <aoe3-blender-tools>]

Writes <out>\\ui\\ingame\\<atlas>_<suffix>.ddt (the layout aoe3-blender-tools' ui_preview --override reads and
apply_fix.py --styles copies into the game) with aoe3-blender-tools' recolouring (tools/recolor_textures.py: OKLCH, each
file's format, size and mip levels kept). The resource icons keep their colours: they are painted inside the resource
panels' backgrounds, so in those panels (RESOURCE_PANELS, the textureCoords of the SettlerCountDialog variants of
uimainnew.xml) the boxes around the bright or colourful pixels are left as they were. Run it with the venv's Python of
aoe3-blender-tools (numpy).
"""
import argparse
import pathlib
import sys

DEFAULT_TOOLS = pathlib.Path(__file__).resolve().parents[3] / "aoe3-blender-tools"

# The loose atlases of the minimised interface (wol-fixes/culture-ui/inventory.md): the three resource panel skins and
# the frames, buttons and panels around them. Every style recolours all three skins: the Middle East family (`me`)
# needs the European one (Afghans, Persians, Saudis, Uzbeks) and the Asian one (the Egyptians, in asianCivs), and
# the Asian family (`as`) the Asian one.
ATLASES = [
    "asi_ui_max", "eur_max_ui", "nat_ui_max", "ingame_ui_small_01_asian", "ingame_ui_small_01_ypack",
    "ingame_ui_02x_ypack", "ingame_ui_small_02_ypack", "ingame_ui_small_03x_ypack", "ingame_ui_small_04x_ypack",
    "warwick_timer_panel",
]
# suffix -> (hue degrees, chroma factor, lightness factor). Deliberately loud, so a picture shows at once which style
# is drawn.
STYLES = {
    "as": (-35, 1.8, 1.0),     # lacquer red
    "as_gw": (-35, 0.35, 0.8),  # the same, grey and darker
    "me": (150, 1.7, 1.0),     # turquoise
    "me_gw": (40, 0.6, 0.9),    # khaki
}
# The resource panels' rectangles in each atlas (u0, v0, u1, v1, from the top left), from the textureCoords of the
# SettlerCountDialog-{default,advanced}Panel{Eur,Asi,Nat}{Max,Min} gadgets: the resource icons are painted there.
RESOURCE_PANELS = {
    "eur_max_ui": [(0.4296875, 0.72, 0.675, 1.0)],
    "asi_ui_max": [(0.4296875, 0.72, 0.675, 1.0)],
    "nat_ui_max": [(0.4296875, 0.29, 0.68, 0.5664), (0.4296875, 0.72, 0.68, 1.0)],
    "ingame_ui_small_01_asian": [(0.4296875, 0.443, 0.67, 0.72)],
    "ingame_ui_small_01_ypack": [(0.675, 0.73, 0.913, 1.0)],
}
DILATE = 6   # pixels around an icon's bright or colourful pixels that join them into one box
MARGIN = 3   # pixels added around each box


def dilate(mask, radius):
    out = mask.copy()
    for _ in range(radius):
        grown = out.copy()
        grown[1:, :] |= out[:-1, :]
        grown[:-1, :] |= out[1:, :]
        grown[:, 1:] |= out[:, :-1]
        grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def boxes(mask):
    """The bounding boxes (y0, y1, x0, x1) of the 4-connected parts of a boolean mask."""
    seen = mask.copy()
    found = []
    h, w = mask.shape
    for y, x in zip(*mask.nonzero()):
        if not seen[y, x]:
            continue
        seen[y, x] = False
        stack, y0, y1, x0, x1 = [(y, x)], y, y, x, x
        while stack:
            cy, cx = stack.pop()
            y0, y1, x0, x1 = min(y0, cy), max(y1, cy), min(x0, cx), max(x1, cx)
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < h and 0 <= nx < w and seen[ny, nx]:
                    seen[ny, nx] = False
                    stack.append((ny, nx))
        found.append((y0, y1 + 1, x0, x1 + 1))
    return found


def icon_mask(np, R, ddt, data, panels):
    """True where the top level's pixels are a resource icon: inside each panel, the boxes around its bright or
    colourful pixels (OKLCH chroma above 0.07 with lightness above 0.45, or lightness above 0.72)."""
    px = ddt.decode(data, 0)
    h, w = px.shape[:2]
    keep = np.zeros((h, w), bool)
    for u0, v0, u1, v1 in panels:
        x0, x1, y0, y1 = int(u0 * w), int(round(u1 * w)), int(v0 * h), int(round(v1 * h))
        lch = R.srgb_to_oklch(px[y0:y1, x0:x1, :3].astype(np.float64))
        bright = ((lch[..., 1] > 0.07) & (lch[..., 0] > 0.45)) | (lch[..., 0] > 0.72)
        for by0, by1, bx0, bx1 in boxes(dilate(bright, DILATE)):
            if (by1 - by0) * (bx1 - bx0) < 64:
                continue
            keep[max(y0, y0 + by0 - MARGIN):min(y1, y0 + by1 + MARGIN),
                 max(x0, x0 + bx0 - MARGIN):min(x1, x0 + bx1 + MARGIN)] = True
    return keep


class Masked:
    """A recolor_textures transform that leaves the masked pixels as they were, at every mip level."""

    def __init__(self, np, base, keep):
        self.np, self.base, self.keep = np, base, keep

    def apply(self, rgb):
        np = self.np
        out = self.base.apply(rgb)
        if self.keep is None:
            return out
        h, w = rgb.shape[:2]
        ys = np.arange(h) * self.keep.shape[0] // h
        xs = np.arange(w) * self.keep.shape[1] // w
        keep = self.keep[ys][:, xs]
        out[keep] = np.asarray(rgb)[keep]
        return out


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("wol")
    parser.add_argument("out")
    parser.add_argument("--tools", default=str(DEFAULT_TOOLS))
    args = parser.parse_args()
    tools = pathlib.Path(args.tools)
    sys.path[:0] = [str(tools / "aoe3_blender_tools"), str(tools / "tools")]
    try:
        import numpy as np
        import recolor_textures as R
        from aoe3game import ddt
    except ImportError as error:
        sys.exit(f"make_test_styles: {error}: run it with aoe3-blender-tools' venv Python, and --tools if needed")
    source = pathlib.Path(args.wol) / "art" / "ui" / "ingame"
    out = pathlib.Path(args.out) / "ui" / "ingame"
    missing = [a for a in ATLASES if not (source / (a + ".ddt")).exists()]
    if missing:
        sys.exit(f"make_test_styles: not in {source}: {', '.join(missing)}")
    out.mkdir(parents=True, exist_ok=True)
    masks = {}
    for atlas in ATLASES:
        data = (source / (atlas + ".ddt")).read_bytes()
        masks[atlas] = icon_mask(np, R, ddt, data, RESOURCE_PANELS[atlas]) if atlas in RESOURCE_PANELS else None
        if masks[atlas] is not None:
            print(f"{atlas}: {int(masks[atlas].sum())} icon pixels kept")
    for suffix, (hue, chroma, lightness) in STYLES.items():
        base = R.Transform(hue, chroma, lightness)
        for atlas in ATLASES:
            data = (source / (atlas + ".ddt")).read_bytes()
            (out / f"{atlas}_{suffix}.ddt").write_bytes(R.recolor_ddt(data, Masked(np, base, masks[atlas])))
        print(f"{suffix}: {len(ATLASES)} atlases")
    print(f"written to {out}")


if __name__ == "__main__":
    main()
