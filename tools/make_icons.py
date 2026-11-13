"""Draws three small test icons for playerIcon, and the avatar table that names them, into tools/playericons/.

    python -I tools/make_icons.py            writes tools/playericons/*.ddt and avatar_uhctest.xml
    python -I tools/make_icons.py --check    exit code 1 if a file differs from what this script writes
    python -I tools/make_icons.py --install <game folder>   also copies them to <game>\\data and <game>\\art\\ui\\playericons
                                             (a file already there is kept as <name>.uhc-orig first)

Each icon is 64x64 texels, DXT1, one mip, in the RTS3 container of the game's textures: a coloured square with a
lighter frame and a white glyph (a diamond, a cross, a ring). No pixel comes from the game. The table gives each one
the avatar ID uhc_<name> and the texture ui\\playericons\\uhc_<name>, so `playerIcon uhc_blue` shows the first one.
"""
import pathlib
import shutil
import struct
import sys

OUT = pathlib.Path(__file__).with_name("playericons")
SIZE = 64
WHITE = (255, 255, 255)
ICONS = {
    # name: (background, glyph)
    "blue": ((0x1F, 0x4E, 0xB4), "diamond"),
    "red": ((0xB4, 0x1F, 0x1F), "cross"),
    "green": ((0x1F, 0x8C, 0x3C), "ring"),
}


def inside(glyph, x, y):
    u, v = (x + 0.5) / SIZE - 0.5, (y + 0.5) / SIZE - 0.5  # -0.5 .. 0.5
    if glyph == "diamond":
        return abs(u) + abs(v) < 0.30
    if glyph == "cross":
        return (abs(u) < 0.08 and abs(v) < 0.32) or (abs(v) < 0.08 and abs(u) < 0.32)
    if glyph == "ring":
        r = (u * u + v * v) ** 0.5
        return 0.18 < r < 0.30
    raise ValueError(glyph)


def texel(background, glyph, x, y):
    if x < 4 or y < 4 or x >= SIZE - 4 or y >= SIZE - 4:
        return tuple(min(255, c + 70) for c in background)  # the frame
    return WHITE if inside(glyph, x, y) else background


def rgb565(colour):
    r, g, b = colour
    return (r >> 3) << 11 | (g >> 2) << 5 | b >> 3


def expand(value):
    r, g, b = value >> 11 & 31, value >> 5 & 63, value & 31
    return (r * 255 // 31, g * 255 // 63, b * 255 // 31)


def block(texels):
    """A DXT1 block of 16 texels (row by row), four-colour mode: the two most distant colours are the ends."""
    values = sorted({rgb565(c) for c in texels}, reverse=True)
    first, second = values[0], values[-1]
    if first == second:
        return struct.pack("<HHI", first, first, 0)
    a, b = expand(first), expand(second)
    palette = [a, b, tuple((2 * x + y) // 3 for x, y in zip(a, b)), tuple((x + 2 * y) // 3 for x, y in zip(a, b))]
    indices = 0
    for i, colour in enumerate(texels):
        index = min(range(4), key=lambda k: sum((p - c) ** 2 for p, c in zip(palette[k], colour)))
        indices |= index << (2 * i)
    return struct.pack("<HHI", first, second, indices)


def ddt(background, glyph):
    data = b""
    for by in range(0, SIZE, 4):
        for bx in range(0, SIZE, 4):
            data += block([texel(background, glyph, bx + x, by + y) for y in range(4) for x in range(4)])
    header = b"RTS3" + bytes((0, 0, 4, 1)) + struct.pack("<II", SIZE, SIZE)  # usage 0, alpha 0, DXT1, one mip
    return header + struct.pack("<II", len(header) + 8, len(data)) + data


def table():
    lines = ["<?xml version=\"1.0\" encoding=\"utf-8\"?>",
             "<!-- Test avatars for playerIcon, drawn by tools/make_icons.py. -->", "<avatars>"]
    for name in ICONS:
        lines.append(f"  <avatar id=\"uhc_{name}\"><image>ui\\playericons\\uhc_{name}</image></avatar>")
    lines.append("</avatars>")
    return ("\r\n".join(lines) + "\r\n").encode("utf-8")


def wanted():
    files = {f"uhc_{name}.ddt": ddt(*spec) for name, spec in ICONS.items()}
    files["avatar_uhctest.xml"] = table()
    return files


def install(game, files):
    for name, data in files.items():
        folder = game / "data" if name.endswith(".xml") else game / "art" / "ui" / "playericons"
        folder.mkdir(parents=True, exist_ok=True)
        target = folder / name
        if target.exists() and target.read_bytes() != data and not target.with_name(name + ".uhc-orig").exists():
            shutil.copy2(target, target.with_name(name + ".uhc-orig"))
        target.write_bytes(data)
        print(f"make_icons: wrote {target}")


def main():
    args = sys.argv[1:]
    files = wanted()
    if "--check" in args:
        bad = [n for n, d in files.items() if not (OUT / n).exists() or (OUT / n).read_bytes() != d]
        print(f"make_icons: {'differs: ' + ', '.join(bad) if bad else 'current'}")
        return 1 if bad else 0
    OUT.mkdir(exist_ok=True)
    for name, data in files.items():
        (OUT / name).write_bytes(data)
    print(f"make_icons: wrote {len(files)} files to {OUT}")
    if "--install" in args:
        install(pathlib.Path(args[args.index("--install") + 1]), files)
    return 0


if __name__ == "__main__":
    sys.exit(main())
