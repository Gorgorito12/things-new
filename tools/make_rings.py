"""Generates the coloured rings that show what an aura does, into tools/rings/.

    python -I tools/make_rings.py          writes every ring
    python -I tools/make_rings.py --check  exit code 1 if a file differs from what this script writes

A ring is two files, copied to art/effects/uhc_rings/ in the game folder:
- ring_<name>.ddt, a 64x64 DXT3 texture drawn here: no pixel comes from the game;
- ring_<name>.xml, the game's own ring mesh with that texture, through <replacetexture>.

An aura uses one with <modelattachment>effects\\uhc_rings\\ring_<name>.xml</modelattachment>.
"""
import math
import pathlib
import struct
import sys

OUT = pathlib.Path(__file__).with_name("rings")
SIZE = 64
MIPS = 5
MESH = r"effects\ypack_auras\aura_econ"
MESH_CAVALRY = r"effects\ypack_auras\aura_econ_cav"

# One colour, one meaning.
RINGS = {
    "wood": (240, 160, 40),    # amber: gathering wood
    "food": (225, 45, 40),     # red: gathering food, as the food icon of the panel
    "gold": (250, 228, 70),    # yellow: gathering gold, as the coin icon of the panel
    "work": (90, 225, 70),     # green: gathers or works faster
    "damage": (235, 40, 200),  # magenta: damage, kept away from the three colours above
    "heal": (245, 245, 245),   # white: hit points, healing
    "speed": (60, 140, 255),   # blue: moves faster
}

# Radii as fractions of the half width, as (inner, outer): a wide band and a thin one.
BANDS = ((0.74, 0.97), (0.52, 0.60))
EDGE = 0.035  # the soft edge of a band, in the same fraction


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
            row.append(round(total / samples ** 2 * 15))
        out.append(row)
    return out


def rgb565(colour):
    r, g, b = colour
    return (r >> 3) << 11 | (g >> 2) << 5 | b >> 3


def dxt3(size, colour):
    """DXT3 blocks: explicit alpha in 4 bits, and one colour for every texel."""
    alpha = alpha_map(size)
    pixel = rgb565(colour)
    out = bytearray()
    for by in range(0, size, 4):
        for bx in range(0, size, 4):
            for y in range(4):
                row = 0
                for x in range(4):
                    row |= alpha[by + y][bx + x] << (4 * x)
                out += struct.pack("<H", row)
            out += struct.pack("<HHI", pixel, pixel, 0)
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
