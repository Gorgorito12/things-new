"""Low-poly neoclassical government house ("White House") for Age of Empires III.

Builds the mesh from exact primitives (flat walls, straight edges), lays out one UV atlas, paints the
diffuse texture procedurally from the real facade measurements, then exports GLB / FBX / OBJ / .blend
and renders previews.

Run with Blender:      blender -b -P make_whitehouse.py -- [--out <dir>] [--no-render]   (default: model/)
or with the bpy module: python make_whitehouse.py [--out <dir>] [--no-render]

Units: 1 Blender unit = 1 m. Blender is Z-up; the front (portico) faces -Y. The origin is the centre of
the footprint (steps included) at ground level. Scale it to match a stock building before export to
Granny (see README.md).
"""
import math
import os
import sys

import bpy  # noqa: I001  (bpy must come first: it makes bmesh and mathutils importable)
import bmesh
import numpy as np
from mathutils import Vector
from PIL import Image, ImageDraw

# --------------------------------------------------------------------------------------------------
# Arguments

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath(argv[argv.index("--out") + 1]) if "--out" in argv else os.path.abspath("model")
RENDER = "--no-render" not in argv
os.makedirs(OUT, exist_ok=True)

ATLAS = 2048          # painted size; saved downscaled to TEX
TEX = 1024
NAME = "WhiteHouse"

# --------------------------------------------------------------------------------------------------
# Dimensions (metres)

W, D = 14.0, 9.0              # main block
PLINTH = 0.8                  # ground floor level
WALL_TOP = 7.0
CORNICE_TOP = 7.4
EAVE_X, EAVE_Y = 7.3, 4.8     # cornice / roof eave half sizes
RIDGE_Z = 10.0
RIDGE_HALF = EAVE_X - EAVE_Y  # equal pitch on all four sides
PITCH = (RIDGE_Z - CORNICE_TOP) / EAVE_Y

FRONT_Y = -D / 2              # front wall plane
PORT_HALF = 3.6               # portico half width
PORT_Y = -7.8                 # portico front (platform and entablature)
COL_X = (-2.7, -0.9, 0.9, 2.7)
COL_Y = -7.2
COL_R = 0.34
COL_SIDES = 10
ENT_BOTTOM = 6.6
PED_HALF = 3.75
PED_Y = -7.85
PED_APEX = CORNICE_TOP + PED_HALF * PITCH
PED_BACK_Y = -EAVE_Y + (PED_APEX - CORNICE_TOP) / PITCH   # where the main roof reaches the apex

# --------------------------------------------------------------------------------------------------
# Atlas regions: pixel rect (x, y, w, h) in the ATLAS-sized image, and the world size (m) it covers

R = {
    "front":  ((0, 0, 1120, 496), (W, WALL_TOP - PLINTH)),
    "side":   ((1120, 0, 720, 496), (D, WALL_TOP - PLINTH)),
    "back":   ((0, 496, 1120, 496), (W, WALL_TOP - PLINTH)),
    "pedi":   ((1120, 496, 600, 163), (2 * PED_HALF, PED_APEX - CORNICE_TOP)),
    "roof":   ((0, 992, 1280, 480), (16.0, 6.0)),
    "plinth": ((0, 1472, 1280, 64), (16.0, 0.8)),
    "trim":   ((0, 1536, 1280, 64), (16.0, 0.8)),
    "stone":  ((1280, 992, 640, 320), (8.0, 4.0)),
    "column": ((1840, 0, 176, 464), (2 * math.pi * COL_R, 5.8)),
    "brick":  ((1280, 1312, 320, 240), (4.0, 3.0)),
    "cupwin": ((1600, 1312, 80, 160), (0.8, 1.6)),
    "white":  ((1700, 1312, 220, 160), (2.2, 1.6)),
    "lead":   ((1600, 1472, 320, 160), (7.0, 2.5)),
}


def atlas_uv(region, u, v):
    (x, y, w, h), (sw, sh) = R[region]
    if u > sw + 1e-4 or v > sh + 1e-4 or u < -1e-4 or v < -1e-4:
        raise ValueError(f"{region}: local ({u:.2f}, {v:.2f}) outside {sw} x {sh}")
    px = x + u / sw * w
    py = y + h - v / sh * h
    return (px / ATLAS, 1.0 - py / ATLAS)


# --------------------------------------------------------------------------------------------------
# Mesh building

bm = bmesh.new()
uv_layer = bm.loops.layers.uv.new("UVMap")
_vcache = {}


def vert(p):
    key = tuple(round(c, 5) for c in p)
    v = _vcache.get(key)
    if v is None:
        v = bm.verts.new(key)
        _vcache[key] = v
    return v


def add_face(pts, region, uvs, smooth=False):
    f = bm.faces.new([vert(p) for p in pts])
    f.smooth = smooth
    for loop, (u, v) in zip(f.loops, uvs):
        loop[uv_layer].uv = atlas_uv(region, u, v)
    return f


def newell(pts):
    n = Vector((0, 0, 0))
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        n.x += (a[1] - b[1]) * (a[2] + b[2])
        n.y += (a[2] - b[2]) * (a[0] + b[0])
        n.z += (a[0] - b[0]) * (a[1] + b[1])
    return n.normalized()


def auto_face(pts, region, anchor=None, smooth=False):
    """Planar UVs: u to the right as seen from outside, v up (or up-slope); origin at `anchor` or at
    the face's minimum."""
    n = newell(pts)
    if abs(n.z) > 0.999:                       # horizontal
        ua, va = Vector((1, 0, 0)), Vector((0, 1, 0))
    else:
        ua = Vector((-n.y, n.x, 0)).normalized()
        va = n.cross(ua).normalized()
    loc = [(Vector(p).dot(ua), Vector(p).dot(va)) for p in pts]
    if anchor is None:
        u0, v0 = min(c[0] for c in loc), min(c[1] for c in loc)
    else:
        u0, v0 = Vector(anchor).dot(ua), Vector(anchor).dot(va)
    loc = [(u - u0, v - v0) for u, v in loc]
    # a face larger than its region (e.g. the plinth top, mostly under the walls) is scaled to fit
    sw, sh = R[region][1]
    eu, ev = max(c[0] for c in loc), max(c[1] for c in loc)
    k = min(1.0, sw / eu if eu > sw else 1.0, sh / ev if ev > sh else 1.0)
    return add_face(pts, region, [(u * k, v * k) for u, v in loc], smooth)


def box(x0, x1, y0, y1, z0, z1, side, top, skip=()):
    """Axis-aligned box without its bottom face. `skip`: '+x', '-x', '+y', '-y', 'top'."""
    faces = {
        "-y": [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
        "+y": [(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)],
        "-x": [(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)],
        "+x": [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
        "top": [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
    }
    for k, pts in faces.items():
        if k not in skip:
            auto_face(pts, top if k == "top" else side)


def prism_ring(cx, cy, r, z0, z1, sides, region, per_face=False, smooth=False, phase=0.0, top=None):
    """Vertical n-gon prism. per_face: each side face maps from the region's origin (repeated
    pattern); else the sides wrap around the region once (circumference)."""
    ang = [phase + 2 * math.pi * i / sides for i in range(sides + 1)]
    pts = [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in ang]
    seg = 2 * r * math.sin(math.pi / sides)
    for i in range(sides):
        (ax, ay), (bx, by) = pts[i], pts[i + 1]
        quad = [(ax, ay, z0), (bx, by, z0), (bx, by, z1), (ax, ay, z1)]
        if per_face:
            uvs = [(0, 0), (seg, 0), (seg, z1 - z0), (0, z1 - z0)]
        else:
            uvs = [(i * seg, 0), ((i + 1) * seg, 0), ((i + 1) * seg, z1 - z0), (i * seg, z1 - z0)]
        add_face(quad, region, uvs, smooth)
    if top:
        cap = [(x, y, z1) for x, y in pts[:-1]]
        rr = R[top][1]
        add_face(cap, top, [((x - cx) / (2 * r) * min(rr) * 0.98 + min(rr) / 2 * 0.98,
                             (y - cy) / (2 * r) * min(rr) * 0.98 + min(rr) / 2 * 0.98) for x, y, _ in cap])


# Plinth, walls, cornice
box(-W / 2 - 0.2, W / 2 + 0.2, -D / 2 - 0.2, D / 2 + 0.2, 0, PLINTH, "plinth", "stone")
auto_face([(-W / 2, FRONT_Y, PLINTH), (W / 2, FRONT_Y, PLINTH), (W / 2, FRONT_Y, WALL_TOP),
           (-W / 2, FRONT_Y, WALL_TOP)], "front", anchor=(-W / 2, FRONT_Y, PLINTH))
auto_face([(W / 2, D / 2, PLINTH), (-W / 2, D / 2, PLINTH), (-W / 2, D / 2, WALL_TOP),
           (W / 2, D / 2, WALL_TOP)], "back", anchor=(W / 2, D / 2, PLINTH))
auto_face([(-W / 2, D / 2, PLINTH), (-W / 2, -D / 2, PLINTH), (-W / 2, -D / 2, WALL_TOP),
           (-W / 2, D / 2, WALL_TOP)], "side", anchor=(-W / 2, D / 2, PLINTH))
auto_face([(W / 2, -D / 2, PLINTH), (W / 2, D / 2, PLINTH), (W / 2, D / 2, WALL_TOP),
           (W / 2, -D / 2, WALL_TOP)], "side", anchor=(W / 2, -D / 2, PLINTH))
box(-EAVE_X, EAVE_X, -EAVE_Y, EAVE_Y, WALL_TOP, CORNICE_TOP, "trim", "trim", skip=("top",))

# Hipped roof
e = CORNICE_TOP
auto_face([(-EAVE_X, -EAVE_Y, e), (EAVE_X, -EAVE_Y, e), (RIDGE_HALF, 0, RIDGE_Z), (-RIDGE_HALF, 0, RIDGE_Z)], "roof")
auto_face([(EAVE_X, EAVE_Y, e), (-EAVE_X, EAVE_Y, e), (-RIDGE_HALF, 0, RIDGE_Z), (RIDGE_HALF, 0, RIDGE_Z)], "roof")
auto_face([(-EAVE_X, EAVE_Y, e), (-EAVE_X, -EAVE_Y, e), (-RIDGE_HALF, 0, RIDGE_Z)], "roof")
auto_face([(EAVE_X, -EAVE_Y, e), (EAVE_X, EAVE_Y, e), (RIDGE_HALF, 0, RIDGE_Z)], "roof")

# Portico: platform, steps, columns, entablature, pediment
# the platform stops at the plinth front: an overlap there would be coplanar with the plinth top
# (z-fighting in game, shadow acne in the renders)
box(-PORT_HALF, PORT_HALF, PORT_Y, -D / 2 - 0.2, 0, PLINTH, "plinth", "stone", skip=("+y",))
for i, h in enumerate((0.6, 0.4, 0.2)):
    y1 = PORT_Y - 0.6 * i
    box(-3.0, 3.0, y1 - 0.6, y1, 0, h, "stone", "stone", skip=("+y",))
for cx in COL_X:
    box(cx - 0.45, cx + 0.45, COL_Y - 0.45, COL_Y + 0.45, PLINTH, PLINTH + 0.25, "white", "white")
    prism_ring(cx, COL_Y, COL_R, PLINTH + 0.25, 6.3, COL_SIDES, "column", smooth=True)
    box(cx - 0.48, cx + 0.48, COL_Y - 0.48, COL_Y + 0.48, 6.3, ENT_BOTTOM, "white", "white", skip=("top",))
box(-PORT_HALF, PORT_HALF, PORT_Y, FRONT_Y, ENT_BOTTOM, CORNICE_TOP, "trim", "trim", skip=("+y", "top"))
auto_face([(-PED_HALF, PED_Y, e), (PED_HALF, PED_Y, e), (0, PED_Y, PED_APEX)], "pedi",
          anchor=(-PED_HALF, PED_Y, e))
auto_face([(-PED_HALF, PED_BACK_Y, e), (-PED_HALF, PED_Y, e), (0, PED_Y, PED_APEX), (0, PED_BACK_Y, PED_APEX)], "roof")
auto_face([(PED_HALF, PED_Y, e), (PED_HALF, PED_BACK_Y, e), (0, PED_BACK_Y, PED_APEX), (0, PED_Y, PED_APEX)], "roof")
# soffit strip under the pediment's front edge (seen between the columns from above at a low angle)
box(-PED_HALF, PED_HALF, PED_Y, PORT_Y, e - 0.12, e, "trim", "trim", skip=("+y", "top"))

# Cupola: octagonal drum, cornice ring, dome, lantern, spire
DRUM_R, DRUM_Z0, DRUM_Z1 = 0.95, 9.4, 11.0
prism_ring(0, 0, DRUM_R, DRUM_Z0, DRUM_Z1, 8, "cupwin", per_face=True, phase=math.pi / 8)
prism_ring(0, 0, 1.12, DRUM_Z1, DRUM_Z1 + 0.15, 8, "white", per_face=True, phase=math.pi / 8)
# ring top (annulus between the cornice ring and the dome base is covered by the dome's first ring)
DOME_R, DOME_H, DOME_Z = 1.05, 0.95, DRUM_Z1 + 0.15
rings = [0, 25, 50, 72]                       # elevation angles (deg); top closed by the lantern
dome_pts = []
for a in rings:
    t = math.radians(a)
    dome_pts.append((DOME_R * math.cos(t) if a else 1.12, DOME_Z + DOME_H * math.sin(t)))
for j in range(len(dome_pts) - 1):
    (r0, z0), (r1, z1) = dome_pts[j], dome_pts[j + 1]
    arc0 = sum(math.hypot(dome_pts[k + 1][0] - dome_pts[k][0], dome_pts[k + 1][1] - dome_pts[k][1]) for k in range(j))
    arc1 = arc0 + math.hypot(r1 - r0, z1 - z0)
    for i in range(8):
        a0 = math.pi / 8 + 2 * math.pi * i / 8
        a1 = math.pi / 8 + 2 * math.pi * (i + 1) / 8
        u0, u1 = i * 7.0 / 8, (i + 1) * 7.0 / 8
        add_face([(r0 * math.cos(a0), r0 * math.sin(a0), z0), (r0 * math.cos(a1), r0 * math.sin(a1), z0),
                  (r1 * math.cos(a1), r1 * math.sin(a1), z1), (r1 * math.cos(a0), r1 * math.sin(a0), z1)],
                 "lead", [(u0, arc0), (u1, arc0), (u1, arc1), (u0, arc1)], smooth=True)
LAN_Z0 = dome_pts[-1][1]
prism_ring(0, 0, dome_pts[-1][0], LAN_Z0, LAN_Z0 + 0.45, 8, "white", per_face=True, phase=math.pi / 8)
SPIRE_TOP = LAN_Z0 + 1.2
r_top = dome_pts[-1][0]
for i in range(8):
    a0 = math.pi / 8 + 2 * math.pi * i / 8
    a1 = math.pi / 8 + 2 * math.pi * (i + 1) / 8
    zb = LAN_Z0 + 0.45
    add_face([(r_top * math.cos(a0), r_top * math.sin(a0), zb), (r_top * math.cos(a1), r_top * math.sin(a1), zb),
              (0, 0, SPIRE_TOP)], "lead", [(i * 0.4, 0), ((i + 1) * 0.4, 0), ((i + 0.5) * 0.4, 0.8)])

# Chimney (its foot is inside the roof)
box(-5.4, -4.6, 1.6, 2.4, 8.2, 11.0, "brick", "brick", skip=("top",))
box(-5.5, -4.5, 1.5, 2.5, 11.0, 11.2, "white", "brick")

# Recentre: footprint centre at the origin, ground at z = 0
xs = [v.co.x for v in bm.verts]
ys = [v.co.y for v in bm.verts]
shift = Vector((-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, 0))
for v in bm.verts:
    v.co += shift
footprint = (max(xs) - min(xs), max(ys) - min(ys))
height = max(v.co.z for v in bm.verts)

# --------------------------------------------------------------------------------------------------
# Texture painting

rng = np.random.default_rng(1870)
img = Image.new("RGB", (ATLAS, ATLAS), (128, 128, 128))
dr = ImageDraw.Draw(img)


def P(region, u, v):
    (x, y, w, h), (sw, sh) = R[region]
    return (x + u / sw * w, y + h - v / sh * h)


def rect(region, u0, v0, u1, v1, fill, outline=None, width=1):
    a, b = P(region, u0, v1), P(region, u1, v0)
    dr.rectangle([a, b], fill=fill, outline=outline, width=width)


def fill_region(region, color):
    (x, y, w, h), _ = R[region]
    dr.rectangle([x, y, x + w - 1, y + h - 1], fill=color)


def hline(region, v, u0, u1, color, width=1):
    dr.line([P(region, u0, v), P(region, u1, v)], fill=color, width=width)


def vline(region, u, v0, v1, color, width=1):
    dr.line([P(region, u, v0), P(region, u, v1)], fill=color, width=width)


WALL = (232, 225, 204)
WALL_LINE = (214, 206, 184)
WHITE = (243, 240, 231)
GLASS = (52, 66, 82)
GLASS_HI = (88, 106, 124)
WOOD = (64, 50, 40)
SHADOW = (170, 162, 142)


def stone_courses(region, course=0.42, joint=1.15):
    _, (sw, sh) = R[region]
    n = 0
    v = course
    while v < sh - 0.4:
        hline(region, v, 0, sw, WALL_LINE)
        off = (n % 2) * joint / 2
        u = off
        while u < sw:
            vline(region, u, v - course, v, WALL_LINE)
            u += joint
        v += course
        n += 1


def quoins(region):
    _, (sw, sh) = R[region]
    for u0, u1 in ((0, 0.45), (sw - 0.45, sw)):
        v, k = 0, 0
        while v < sh - 0.4:
            w = 0.45 if k % 2 == 0 else 0.3
            a, b = (u0, u0 + w) if u0 == 0 else (u1 - w, u1)
            rect(region, a, v, b, v + 0.42, (238, 232, 213), outline=WALL_LINE)
            v += 0.42
            k += 1


def window(region, uc, v0, h, w=1.0, cap="flat"):
    # frame and sill
    rect(region, uc - w / 2 - 0.12, v0 - 0.08, uc + w / 2 + 0.12, v0 + h + 0.1, WHITE, outline=SHADOW)
    rect(region, uc - w / 2 - 0.2, v0 - 0.16, uc + w / 2 + 0.2, v0 - 0.04, WHITE, outline=SHADOW)
    # glass with a lighter upper part, sash bars
    rect(region, uc - w / 2, v0, uc + w / 2, v0 + h, GLASS)
    rect(region, uc - w / 2, v0 + h * 0.62, uc + w / 2, v0 + h, GLASS_HI)
    vline(region, uc, v0, v0 + h, WHITE, 3)
    for k in (1, 2):
        hline(region, v0 + h * k / 3, uc - w / 2, uc + w / 2, WHITE, 3)
    # cap
    top = v0 + h + 0.1
    if cap == "pediment":
        pts = [P(region, uc - w / 2 - 0.3, top), P(region, uc + w / 2 + 0.3, top), P(region, uc, top + 0.45)]
        dr.polygon(pts, fill=WHITE, outline=SHADOW)
    else:
        rect(region, uc - w / 2 - 0.25, top, uc + w / 2 + 0.25, top + 0.16, WHITE, outline=SHADOW)


def door(region, uc):
    w, h = 1.4, 2.6
    rect(region, uc - w / 2 - 0.18, 0, uc + w / 2 + 0.18, h + 0.15, WHITE, outline=SHADOW)
    rect(region, uc - w / 2, 0, uc + w / 2, h - 0.55, WOOD)
    vline(region, uc, 0, h - 0.55, (40, 30, 24), 3)
    for k in (0.35, 1.15):
        rect(region, uc - w / 2 + 0.12, k, uc - 0.08, k + 0.6, None, outline=(84, 68, 54), width=2)
        rect(region, uc + 0.08, k, uc + w / 2 - 0.12, k + 0.6, None, outline=(84, 68, 54), width=2)
    # fanlight
    a, b = P(region, uc - w / 2, h + 0.0), P(region, uc + w / 2, h - 1.1)
    dr.pieslice([a, b], 180, 360, fill=GLASS_HI, outline=WHITE, width=3)
    rect(region, uc - w / 2, h - 0.62, uc + w / 2, h - 0.55, WHITE)


def facade(region, bays, door_at=None):
    _, (sw, sh) = R[region]
    fill_region(region, WALL)
    stone_courses(region)
    quoins(region)
    # string course between the floors and frieze under the cornice
    rect(region, 0, 3.05, sw, 3.3, (240, 235, 218), outline=WALL_LINE)
    rect(region, 0, sh - 0.4, sw, sh, (240, 235, 218), outline=WALL_LINE)
    for uc in bays:
        if door_at is not None and abs(uc - door_at) < 0.01:
            door(region, uc)
        else:
            window(region, uc, 0.8, 1.9, cap="pediment")
        window(region, uc, 3.65, 1.65, cap="flat")


facade("front", [W / 2 + x for x in (-5.6, -4.0, -1.8, 0.0, 1.8, 4.0, 5.6)], door_at=W / 2)
facade("back", [W / 2 + x for x in (-5.7, -3.8, -1.9, 0.0, 1.9, 3.8, 5.7)])
facade("side", [1.5, 4.5, 7.5])

# Pediment: white tympanum, raking cornice band and an oculus
fill_region("pedi", WHITE)
_, (pw, ph) = R["pedi"]
dr.line([P("pedi", 0, 0.05), P("pedi", pw, 0.05)], fill=SHADOW, width=6)
dr.line([P("pedi", 0.05, 0.02), P("pedi", pw / 2, ph - 0.02)], fill=SHADOW, width=6)
dr.line([P("pedi", pw - 0.05, 0.02), P("pedi", pw / 2, ph - 0.02)], fill=SHADOW, width=6)
c = P("pedi", pw / 2, 0.75)
rr = 0.32 / pw * R["pedi"][0][2]
dr.ellipse([c[0] - rr - 4, c[1] - rr - 4, c[0] + rr + 4, c[1] + rr + 4], fill=WHITE, outline=SHADOW, width=2)
dr.ellipse([c[0] - rr, c[1] - rr, c[0] + rr, c[1] + rr], fill=GLASS)

# Roof slate: staggered rows with per-tile variation
fill_region("roof", (70, 78, 90))
_, (rw, rh) = R["roof"]
row = 0.24
v = 0.0
k = 0
while v < rh:
    u = -(k % 2) * 0.15
    while u < rw:
        t = int(rng.integers(-9, 10))
        rect("roof", max(u, 0), v, min(u + 0.3, rw), min(v + row, rh), (70 + t, 78 + t, 91 + t), outline=(52, 58, 68))
        u += 0.3
    v += row
    k += 1

# Plinth (rusticated), trim (dentils), stone, column flutes, brick, cupola, white, lead
fill_region("plinth", (192, 188, 177))
for vv in (0.0, 0.4):
    hline("plinth", vv, 0, 16, (150, 146, 136), 2)
    u = (vv / 0.4) * 0.5
    while u < 16:
        vline("plinth", u, vv, vv + 0.4, (150, 146, 136), 2)
        u += 1.0
fill_region("trim", WHITE)
hline("trim", 0.02, 0, 16, SHADOW, 2)
hline("trim", 0.3, 0, 16, (225, 221, 210), 2)
u = 0.05
while u < 16:
    rect("trim", u, 0.48, u + 0.1, 0.62, (247, 245, 238), outline=(205, 200, 188))
    u += 0.2
hline("trim", 0.7, 0, 16, (225, 221, 210), 2)
fill_region("stone", (206, 202, 192))
for vv in np.arange(0, 4.0, 0.4):
    hline("stone", vv, 0, 8, (176, 172, 162))
    off = (int(vv / 0.4) % 2) * 0.4
    for uu in np.arange(off, 8, 0.8):
        vline("stone", uu, vv, vv + 0.4, (176, 172, 162))
fill_region("column", (241, 238, 229))
_, (cw, chh) = R["column"]
for i in range(20):
    vline("column", cw * (i + 0.5) / 20, 0, chh, (222, 218, 207), 2)
fill_region("brick", (190, 180, 170))
for j, vv in enumerate(np.arange(0, 3.0, 0.09)):
    off = (j % 2) * 0.12
    for uu in np.arange(-off, 4.0, 0.25):
        t = int(rng.integers(-12, 12))
        rect("brick", max(uu + 0.01, 0), vv + 0.012, min(uu + 0.24, 4.0), min(vv + 0.08, 3.0), (150 + t, 64 + t // 2, 48))
fill_region("cupwin", WHITE)
rect("cupwin", 0.2, 0.25, 0.6, 1.05, GLASS)
dr.pieslice([P("cupwin", 0.2, 1.25), P("cupwin", 0.6, 0.85)], 180, 360, fill=GLASS)
rect("cupwin", 0.0, 0.0, 0.8, 0.12, (228, 224, 214))
fill_region("white", WHITE)
fill_region("lead", (96, 106, 114))
for uu in np.arange(0, 7.0, 7.0 / 16):
    vline("lead", uu, 0, 2.5, (80, 88, 96), 2)

# Subtle noise everywhere, then downscale
arr = np.asarray(img).astype(np.int16)
arr += rng.integers(-5, 6, size=arr.shape[:2])[..., None]
img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
img = img.resize((TEX, TEX), Image.LANCZOS)
tex_path = os.path.join(OUT, f"{NAME.lower()}_diffuse.png")
img.save(tex_path)

# --------------------------------------------------------------------------------------------------
# Scene objects

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

mesh = bpy.data.meshes.new(NAME)
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new(NAME, mesh)
bpy.context.scene.collection.objects.link(obj)

image = bpy.data.images.load(tex_path)
image.pack()
mat = bpy.data.materials.new(f"{NAME}_mat")
try:
    mat.use_nodes = True
except Exception:
    pass
nt = mat.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
texn = nt.nodes.new("ShaderNodeTexImage")
texn.image = image
texn.interpolation = "Closest" if False else "Linear"
nt.links.new(texn.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 1.0
for key in ("Specular IOR Level", "Specular"):
    if key in bsdf.inputs:
        bsdf.inputs[key].default_value = 0.0
mesh.materials.append(mat)
tri = obj.modifiers.new("Triangulate", "TRIANGULATE")

flag = bpy.data.objects.new("flag_attach", None)
flag.empty_display_type = "ARROWS"
flag.empty_display_size = 0.5
flag.location = (shift.x, shift.y, SPIRE_TOP)
flag.parent = obj
bpy.context.scene.collection.objects.link(flag)

depsgraph = bpy.context.evaluated_depsgraph_get()
eval_mesh = obj.evaluated_get(depsgraph).to_mesh()
TRIS = len(eval_mesh.polygons)
VERTS = len(eval_mesh.vertices)
obj.evaluated_get(depsgraph).to_mesh_clear()

# --------------------------------------------------------------------------------------------------
# Export

bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
flag.select_set(True)
bpy.context.view_layer.objects.active = obj
base = os.path.join(OUT, NAME.lower())
bpy.ops.export_scene.gltf(filepath=base + ".glb", export_format="GLB", use_selection=True, export_apply=True)
bpy.ops.export_scene.fbx(filepath=base + ".fbx", use_selection=True, use_mesh_modifiers=True,
                         path_mode="COPY", embed_textures=True, axis_forward="-Z", axis_up="Y")
bpy.ops.wm.obj_export(filepath=base + ".obj", export_selected_objects=True, apply_modifiers=True,
                      export_triangulated_mesh=True, path_mode="STRIP", forward_axis="NEGATIVE_Z", up_axis="Y")
bpy.context.preferences.filepaths.save_version = 0   # no .blend1 backup next to the asset
bpy.ops.wm.save_as_mainfile(filepath=base + ".blend", compress=True)

stats = (f"{NAME}: {TRIS} triangles, {VERTS} vertices; footprint {footprint[0]:.1f} x {footprint[1]:.1f} m "
         f"(steps included), height {height:.1f} m; texture {TEX} x {TEX}")
print(stats)
with open(os.path.join(OUT, "stats.txt"), "w") as fh:
    fh.write(stats + "\n")

# --------------------------------------------------------------------------------------------------
# Preview renders (not part of the asset)

if RENDER:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    try:
        scene.cycles.use_denoising = True
    except Exception:
        pass
    scene.render.resolution_x, scene.render.resolution_y = 1280, 960
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.color = (0.55, 0.65, 0.8)
    try:
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.65, 0.8, 1)
        world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
    except Exception:
        pass
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.2
    sun_data.angle = math.radians(8)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(42), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
    ground = bpy.context.active_object
    gmat = bpy.data.materials.new("Grass")
    try:
        gmat.use_nodes = True
    except Exception:
        pass
    gb = next(n for n in gmat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    gb.inputs["Base Color"].default_value = (0.18, 0.26, 0.08, 1)
    gb.inputs["Roughness"].default_value = 1.0
    ground.data.materials.append(gmat)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 25
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    def shoot(name, azimuth_deg, elevation_deg, freestyle=False, clay=False):
        az, el = math.radians(azimuth_deg), math.radians(elevation_deg)
        target = Vector((0, 0, 4.5))
        dist = 60
        cam.location = target + Vector((math.sin(az) * math.cos(el) * dist,
                                        -math.cos(az) * math.cos(el) * dist, math.sin(el) * dist))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.use_freestyle = freestyle
        if freestyle:
            scene.render.line_thickness = 0.8
        links = list(nt.links)
        if clay:
            for l in links:
                if l.to_socket == bsdf.inputs["Base Color"]:
                    nt.links.remove(l)
            bsdf.inputs["Base Color"].default_value = (0.75, 0.75, 0.75, 1)
        scene.render.image_settings.file_format = "JPEG"
        scene.render.image_settings.quality = 88
        scene.render.filepath = os.path.join(OUT, f"preview_{name}.jpg")
        bpy.ops.render.render(write_still=True)
        if clay:
            nt.links.new(texn.outputs["Color"], bsdf.inputs["Base Color"])

    shoot("front34", -35, 42)
    shoot("back34", 145, 42)
    shoot("wire", -35, 42, freestyle=True, clay=True)
