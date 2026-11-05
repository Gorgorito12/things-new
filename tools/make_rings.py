"""Generates the coloured rings that show what an aura does, into tools/rings/.

    python -I tools/make_rings.py          writes every ring
    python -I tools/make_rings.py --check  exit code 1 if a file differs from what this script writes

Everything goes to art/effects/uhc_rings/ in the game folder. No pixel and no mesh comes from the game:
- ring_<name>.xml, the model: by <logic type="UnitType">, one flat particle on the ground of the size in SHAPES;
- ring_<name>_<size>.particle, that particle, for each size;
- ring_<name>.ddt, the 64x64 DXT3 texture of a unit, a tree or a cavalryman;
- ring_<name>_<size>.ddt, the texture of a building, with lines as thick in metres as those of a unit's ring.

An aura uses one with <modelattachment>effects\\uhc_rings\\ring_<name>.xml</modelattachment>.
"""
import functools
import math
import pathlib
import struct
import sys

OUT = pathlib.Path(__file__).with_name("rings")
SIZE = 64

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

# Radii as fractions of the half width, as (inner, outer): a wide band and a thin one.
BANDS = ((0.74, 0.97), (0.52, 0.60))
EDGE = 0.035  # the soft edge of a band, in the same fraction
UNIT_RADIUS = 2.2  # metres, the half width of the texture on a unit; its rim is at 0.97 of that
# By logic branch, most specific first: the size in the file names, the half width in metres, and for a building
# the side of its own texture. <none> is everything else, a tree too.
SHAPES = (
    ("none", "unit", UNIT_RADIUS, None),
    ("abstractcavalry", "cavalry", 4.6, None),
    ("abstractartillery", "cavalry", 4.6, None),
    ("abstracttowncenter", "large", 20, 256),
    ("abstracthouse", "small", 9, 128),
    ("building", "medium", 16, 256),
)
OPACITY = 0.70  # the ground shows through
# A DXT3 block holds two colours and two mixes of them. By how much of the main colour: 1, 2/3, 1/3, 0.
SHADES = (0, 2, 3, 1)


def building_shape(radius):
    """The bands and the edge at a building's radius, the same metres as on a unit: only the gap to the rim is kept."""
    scale = UNIT_RADIUS / radius
    wide, gap, thin = (BANDS[0][1] - BANDS[0][0]) * scale, (BANDS[0][0] - BANDS[1][1]) * scale, (BANDS[1][1] - BANDS[1][0]) * scale
    rim = BANDS[0][1]
    return ((rim - wide, rim), (rim - wide - gap - thin, rim - wide - gap)), EDGE * scale


def coverage(r, bands, edge):
    """How opaque a texel at radius r is, from 0 to 1."""
    best = 0.0
    for inner, outer in bands:
        value = min((r - inner) / edge + 0.5, (outer - r) / edge + 0.5)
        best = max(best, min(1.0, max(0.0, value)))
    return best


@functools.lru_cache(maxsize=None)
def alpha_map(size, bands, edge):
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
                    total += coverage(math.hypot(u, v), bands, edge)
            row.append(round(total / samples ** 2 * OPACITY * 15))
        out.append(row)
    return out


def shade(x, y, size, bands):
    """The block index of a texel: the wide band fades from the main colour at its rim, the thin one is light."""
    r = math.hypot((x + 0.5) / size * 2 - 1, (y + 0.5) / size * 2 - 1)
    inner, outer = bands[0]
    main = min(1.0, max(0.0, (r - inner) / (outer - inner)))
    return SHADES[min(3, int((1.0 - main) * 4))]


def rgb565(colour):
    r, g, b = colour
    return (r >> 3) << 11 | (g >> 2) << 5 | b >> 3


def dxt3(size, colours, bands, edge):
    """DXT3 blocks: explicit alpha in 4 bits, then the two colours and a 2-bit index per texel."""
    alpha = alpha_map(size, bands, edge)
    main, light = rgb565(colours[0]), rgb565(colours[1])
    out = bytearray()
    for by in range(0, size, 4):
        for bx in range(0, size, 4):
            indices = 0
            for y in range(4):
                row = 0
                for x in range(4):
                    row |= alpha[by + y][bx + x] << (4 * x)
                    indices |= shade(bx + x, by + y, size, bands) << (2 * (y * 4 + x))
                out += struct.pack("<H", row)
            out += struct.pack("<HHI", main, light, indices)
    return bytes(out)


def ddt(colour, size=SIZE, bands=BANDS, edge=EDGE):
    """The RTS3 container: usage 0, alpha 1, format 8, then an (offset, size) pair per mip, down to 4x4."""
    mips = int(math.log2(size)) - 1
    levels = [dxt3(size >> i, colour, bands, edge) for i in range(mips)]
    out = b"RTS3" + bytes((0, 1, 8, mips)) + struct.pack("<II", size, size)
    offset = len(out) + 8 * mips
    for level in levels:
        out += struct.pack("<II", offset, len(level))
        offset += len(level)
    return out + b"".join(levels)


def branches(name):
    out = ""
    for branch, size, _, _ in SHAPES:
        out += f"""\t\t\t\t<{branch}>
\t\t\t\t\t<assetreference type="ParticleSystem">
\t\t\t\t\t\t<file>effects\\uhc_rings\\ring_{name}_{size}.particle</file>
\t\t\t\t\t</assetreference>
\t\t\t\t</{branch}>
"""
    return out


def xml(name):
    return f"""<?xml version="1.0" encoding="utf-8"?>

<animfile>
\t<definebone>bone_main</definebone>
\t<attachment>
\t\tchiefpower_a
\t\t<component>
\t\t\tchiefpower_a
\t\t\t<notshadowcaster/>
\t\t\t<logic type="UnitType">
{branches(name)}\t\t\t</logic>
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


# Every field of a .particle file, in the order the game writes them. <appearancetype>2 lies flat on the
# ground, 0 faces the camera; <materialtype>0 with <material>0 honours the alpha of the texture, and the
# one particle lives for an hour, is back at once, and <startfull> has it there from the first frame.
PARTICLE = (
    ("emitter", """tiedtoemitter=1 ignorerotation=0 emitbymotion=0 loop=1 inheritvelocity=0 useminvelocity=0
        usemaxvelocity=0 alwaysactive=1 syncwithattackanim=0 maxparticles=1 appearancetype=2 updateradius=0.000
        maxparticlesvar=0.000 particlelife=2.000 particlelifevar=0.000 globalfadein=0.000 globalfadeinvar=0.000
        globalfadeout=0.000 globalfadeoutvar=0.000 emitdistance=1.000 emitdistancevar=0.000 emissionrate=100.000
        emissionratevar=0.000 initialdormancy=0.000 initialdormancyvar=0.000 initialupdate=0.000
        initialupdatevar=0.000 emissiontime=0.000 emissiontimevar=0.000 dormanttime=0.000 dormanttimevar=0.000
        initialdistance=0.000 initialdistancevar=0.000 initialvelocity=0.000 initialvelocityvar=0.000
        acceleration=0.000 accelerationvar=0.000 inheritinfluence=0.000 inheritinfluencevar=0.000 minvelocity=0.000
        minvelocityvar=0.000 maxvelocity=0.000 maxvelocityvar=0.000"""),
    ("shape", """startfull=1 emitawayfrombias=0 usespreader=0 shapetype=0 outerxradius=0.000 innerxradius=0.000
        outeryradius=0.000 inneryradius=0.000 outerzradius=0.000 innerzradius=0.000 centerheight=0.200 offaxis=0.000
        offaxisspread=0.000 offplane=0.000 offplanespread=0.000 biaspointheight=0.000"""),
    ("appearance", """orientbymotion=0 numfiles=1 numframes=0 framewidth=0 frameheight=0 materialtype=0
        emissive=16777215 specular=16777215 specularexponent=2.000 framespersecond=0.000 animationrate=1.000
        animationratevar=0.000"""),
    ("appearanceweights", None),
    ("opacity", """loopingcycle=0 numstages=0 opacity=1.000 opacityvar=0.000 cycletime=0.000 cycletimevar=0.000"""),
    ("opacitystages", ""),
    ("scale", """loopingcycle=0 numstages=0 scale={radius:.3f} scalevar=0.000 xscale=1.000 xscalevar=0.000 yscale=1.000
        yscalevar=0.000 zscale=1.000 zscalevar=0.000 cycletime=0.000 cycletimevar=0.000"""),
    ("scalestages", ""),
    ("speed", """loopingcycle=0 numstages=0 speed=1.000 speedvar=0.000 xspeed=1.000 xspeedvar=0.000 yspeed=1.000
        yspeedvar=0.000 zspeed=1.000 zspeedvar=0.000 cycletime=0.000 cycletimevar=0.000"""),
    ("speedstages", ""),
    ("color", """usepalette=0 loopingcycle=0 numpalettecolors=0 numstages=0 cycletime=0.000 cycletimevar=0.000
        fworldlightinginfluence=0.000 color=16777215"""),
    ("palettecolors", ""),
    ("colorstages", ""),
    ("forces", """randomorientation=0 tumble=0 tumblebothdirections=0 randomaxis=0 internalgravity=0.000
        internalgravityvar=0.000 internalwinddirection=0.000 internalwinddirectionvar=0.000 internalwindspeed=0.000
        internalwindspeedvar=0.000 internalwinddelay=0.000 internalwinddelayvar=0.000 externalwindinfluence=0.000
        externalwindinfluencevar=0.000 externalwinddelay=0.000 externalwinddelayvar=0.000 riverflowinfluence=0.000
        riverflowinfluencevar=0.000 minangularvelocity=0.000 maxangularvelocity=0.000 xaxis=0.000 xaxisvar=0.000
        yaxis=0.000 yaxisvar=0.000 zaxis=0.000 zaxisvar=0.000"""),
    ("collision", "numtypes=0 terraininteractiontype=-1 terrainheight=0.000 terrainheightvar=0.000"),
    ("collisionstages", ""),
)


def particle(texture, radius):
    out = "<particlefile>\n"
    for section, fields in PARTICLE:
        if fields is None:
            out += (f"\t<{section}>\n\t\t<stage>\n\t\t\t<file>effects\\uhc_rings\\{texture}</file>\n"
                    f"\t\t\t<material>0</material>\n\t\t\t<weight>1.000</weight>\n\t\t</stage>\n\t</{section}>\n")
        elif fields:
            out += f"\t<{section}>\n"
            for field in fields.format(radius=radius).split():
                key, value = field.split("=")
                out += f"\t\t<{key}>{value}</{key}>\n"
            out += f"\t</{section}>\n"
        else:
            out += f"\t<{section}/>\n"
    return out + "</particlefile>\n"


def text(body):
    return body.replace("\n", "\r\n").encode("utf-8")


def main():
    check = "--check" in sys.argv
    wanted = {}
    for name, colour in RINGS.items():
        wanted[f"ring_{name}.ddt"] = ddt(colour)
        wanted[f"ring_{name}.xml"] = text(xml(name))
        for _, size, radius, side in SHAPES:
            texture = f"ring_{name}_{size}" if side else f"ring_{name}"
            wanted[f"ring_{name}_{size}.particle"] = text(particle(texture, radius))
            if side:
                wanted[f"{texture}.ddt"] = ddt(colour, side, *building_shape(radius))
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
