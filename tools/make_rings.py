"""Generates the coloured rings that show what an aura does, into tools/rings/.

    python -I tools/make_rings.py          writes every ring
    python -I tools/make_rings.py --check  exit code 1 if a file differs from what this script writes

A ring is two files, copied to art/effects/uhc_rings/ in the game folder:
- ring_<name>.ddt, a 128x128 DXT3 texture drawn here: no pixel comes from the game;
- ring_<name>.xml, the game's own ring mesh with that texture, through <replacetexture>.

An aura uses one with <modelattachment>effects\\uhc_rings\\ring_<name>.xml</modelattachment>.
"""
import math
import pathlib
import struct
import sys

OUT = pathlib.Path(__file__).with_name("rings")
SIZE = 128  # thin lines need more texels than the game's 64
MIPS = 6
MESH = r"effects\ypack_auras\aura_econ"
MESH_CAVALRY = r"effects\ypack_auras\aura_econ_cav"

# One meaning per ring: its main colour, on the outside, and the lighter one it fades to.
RINGS = {
    "wood": ((235, 130, 20), (255, 225, 130)),    # amber: gathering wood
    "food": ((220, 30, 30), (255, 160, 110)),     # red: gathering food, as the food icon of the panel
    "gold": ((255, 205, 0), (255, 250, 170)),     # yellow: gathering gold, as the coin icon of the panel
    "work": ((50, 205, 50), (220, 245, 90)),      # green: gathers or works faster
    "damage": ((225, 20, 180), (255, 160, 235)),  # magenta: damage, kept away from the three colours above
    "heal": ((245, 248, 255), (150, 215, 255)),   # white: hit points, healing
    "speed": ((30, 105, 255), (140, 235, 255)),   # blue: moves faster
}

# Radii as fractions of the half width, as (inner, outer): two thin lines, never a band.
BANDS = ((0.905, 0.955), (0.70, 0.73))
EDGE = 0.02  # the soft edge of a line, in the same fraction
OPACITY = 0.85  # a thin line needs more than a band to show, and the ground still shows between the lines
SPLIT = 0.8  # the radius between the outer line, in the main colour, and the inner one, in the light colour


def coverage(r):
    """How opaque a texel at radius r is, from 0 to 1."""
    best = 0.0
    for inner, outer in BANDS:
        value = min((r - inner) / EDGE + 0.5, (outer - r) / EDGE + 0.5)
        best = max(best, min(1.0, max(0.0, value)))
    return best


def alpha_map(size):
    """Alpha by texel, 0 to 15, averaged over four samples per side so small mips stay round."""
    samples = 4
    out = []
    for y in range(size):
        row = []
        for x in range(size):
            total = 0.0
            for sy in range(samples):
                for sx in range(samples):
                    u = (x + (sx + 0.5) / samples) / size * 2 - 1
                    v = (y + (sy + 0.5) / samples) / size * 2 - 1
                    total += coverage(math.hypot(u, v))
            row.append(round(total / samples ** 2 * OPACITY * 15))
        out.append(row)
    return out


def shade(x, y, size):
    """The block index of a texel: 0, the main colour, on the outer line; 1, the light one, on the inner."""
    return 0 if math.hypot((x + 0.5) / size * 2 - 1, (y + 0.5) / size * 2 - 1) >= SPLIT else 1


def rgb565(colour):
    r, g, b = colour
    return (r >> 3) << 11 | (g >> 2) << 5 | b >> 3


def dxt3(size, colours):
    """DXT3 blocks: explicit alpha in 4 bits, then the two colours and a 2-bit index per texel."""
    alpha = alpha_map(size)
    main, light = rgb565(colours[0]), rgb565(colours[1])
    out = bytearray()
    for by in range(0, size, 4):
        for bx in range(0, size, 4):
            indices = 0
            for y in range(4):
                row = 0
                for x in range(4):
                    row |= alpha[by + y][bx + x] << (4 * x)
                    indices |= shade(bx + x, by + y, size) << (2 * (y * 4 + x))
                out += struct.pack("<H", row)
            out += struct.pack("<HHI", main, light, indices)
    return bytes(out)


def ddt(colour):
    """The RTS3 container: usage 0, alpha 1, format 8, then an (offset, size) pair per mip."""
    levels = [dxt3(SIZE >> i, colour) for i in range(MIPS)]
    out = b"RTS3" + bytes((0, 1, 8, MIPS)) + struct.pack("<II", SIZE, SIZE)
    offset = len(out) + 8 * MIPS
    for level in levels:
        out += struct.pack("<II", offset, len(level))
        offset += len(level)
    return out + b"".join(levels)


def mesh(path, texture):
    return f"""\t\t\t\t\t<assetreference type="GrannyModel">
\t\t\t\t\t\t<file>{path}</file>
\t\t\t\t\t\t<replacetexture>
\t\t\t\t\t\t\t<from>{MESH}</from>
\t\t\t\t\t\t\t<to>{texture}</to>
\t\t\t\t\t\t</replacetexture>
\t\t\t\t\t</assetreference>
"""


def xml(name):
    texture = rf"effects\uhc_rings\ring_{name}"
    return f"""<?xml version="1.0" encoding="utf-8"?>

<animfile>
\t<definebone>bone_main</definebone>
\t<attachment>
\t\tchiefpower_a
\t\t<component>
\t\t\tchiefpower_a
\t\t\t<notshadowcaster/>
\t\t\t<logic type="UnitType">
\t\t\t\t<none>
{mesh(MESH, texture)}\t\t\t\t</none>
\t\t\t\t<abstractcavalry>
{mesh(MESH_CAVALRY, texture)}\t\t\t\t</abstractcavalry>
\t\t\t\t<abstractartillery>
{mesh(MESH_CAVALRY, texture)}\t\t\t\t</abstractartillery>
\t\t\t</logic>
\t\t</component>
\t\t<anim>
\t\t\tIdle
\t\t\t<component>chiefpower_a</component>
\t\t</anim>
\t</attachment>
\t<component>
\t\tchiefpower_a
\t\t<assetreference type="GrannyModel">
\t\t\t<file>effects\\Chiefpower\\chiefpower</file>
\t\t</assetreference>
\t\t<decal>
\t\t\t<effecttype>default</effecttype>
\t\t\t<width>0.00</width>
\t\t\t<height>0.00</height>
\t\t\t<zoffset>0.00</zoffset>
\t\t</decal>
\t</component>
\t<anim>
\t\tIdle
\t\t<component>chiefpower_a</component>
\t\t<attach a="chiefpower_a" frombone="HITPOINTBAR" tobone="HITPOINTBAR" syncanims="0"/>
\t</anim>
</animfile>
"""


def main():
    check = "--check" in sys.argv
    wanted = {}
    for name, colour in RINGS.items():
        wanted[f"ring_{name}.ddt"] = ddt(colour)
        wanted[f"ring_{name}.xml"] = xml(name).replace("\n", "\r\n").encode("utf-8")
    bad = 0
    OUT.mkdir(exist_ok=True)
    for name, data in wanted.items():
        path = OUT / name
        if check:
            if not path.exists() or path.read_bytes() != data:
                print(f"make_rings: {name} differs")
                bad += 1
        else:
            path.write_bytes(data)
    print(f"make_rings: {len(wanted)} files, {bad} differ" if check else f"make_rings: wrote {len(wanted)} files")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
