"""Makes every test GIF of docs/media to one standard, from the lossless masters of `testbed.py record --master`.

The standard: 800 px wide, 8 fps, at most 12 s, at most 4 MB. The cut of each GIF is in tools/gifs.txt:
name, start and length in the video's seconds, speed and, when small text must stay readable, an area
of the master as w:h:x:y. A GIF over the limit is tried again with
fewer frames and colours, then with a shorter cut; the last resort is reported, so that its caption
can be checked.

    python -I tools/make_gifs.py [names]      makes all the GIFs, or the ones named
    python -I tools/make_gifs.py --check      exit code 1 if a GIF is not to the standard

The masters are in rea/media-masters (gitignored). A GIF is never enlarged, and only made from a master.
"""
import concurrent.futures
import pathlib
import struct
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
MEDIA = ROOT / "docs" / "media"
MASTERS = ROOT / "rea" / "media-masters"
TABLE = pathlib.Path(__file__).with_name("gifs.txt")
FFMPEG = r"C:\Tools\ffmpeg\ffmpeg.exe"
WIDTH = 800
FPS = 8
SECONDS = 12.0
LIMIT = 4_000_000
# (fps, colours, share of the cut). Each step is only tried when the one before is over the limit.
STEPS = [(8, 192, 1.0), (6, 192, 1.0), (6, 128, 1.0), (6, 96, 0.75), (5, 96, 0.6), (4, 64, 0.5)]


def table():
    rows = {}
    for line in TABLE.read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            name, start, length, speed, *crop = line.split()
            rows[name] = (float(start), float(length), float(speed), crop[0] if crop else None)
    return rows


def encode(name, start, length, speed, crop, fps, colours, out):
    area = f"crop={crop}," if crop else ""
    video = (f"setpts=PTS/{speed},fps={fps},{area}scale={WIDTH}:-1:flags=lanczos,split[a][b];"
             f"[a]palettegen=max_colors={colours}:stats_mode=full[p];"
             "[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle")
    subprocess.run([FFMPEG, "-nostdin", "-y", "-loglevel", "error", "-ss", str(start), "-t", str(length),
                    "-i", str(MASTERS / f"{name}.mkv"), "-vf", video, str(out)], check=True)


def make(name, cut):
    start, length, speed, crop = cut
    speed = max(speed, length / SECONDS)  # at most SECONDS of GIF
    with tempfile.TemporaryDirectory() as work:
        out = pathlib.Path(work) / "out.gif"
        for step, (fps, colours, share) in enumerate(STEPS):
            encode(name, start, length * share, speed, crop, fps, colours, out)
            size = out.stat().st_size
            if size <= LIMIT:
                break
        (MEDIA / f"{name}.gif").write_bytes(out.read_bytes())
    return name, size, step, f"{fps} fps, {colours} colours, {share:.0%} of the cut"


def gif_width(path):
    with path.open("rb") as f:
        return struct.unpack("<H", f.read(8)[6:8])[0]


def check():
    rows = table()
    bad = []
    for path in sorted(MEDIA.glob("*.gif")):
        if path.stem not in rows:
            bad.append(f"{path.name}: not in {TABLE.name}")
        if gif_width(path) != WIDTH:
            bad.append(f"{path.name}: {gif_width(path)} px wide")
        if path.stat().st_size > LIMIT:
            bad.append(f"{path.name}: {path.stat().st_size / 1e6:.1f} MB")
    total = sum(p.stat().st_size for p in MEDIA.glob("*.gif")) / 1e6
    print(f"make_gifs: {len(list(MEDIA.glob('*.gif')))} GIFs, {total:.0f} MB")
    for line in bad:
        print(" ", line)
    return 1 if bad else 0


def main(argv):
    if "--check" in argv:
        sys.exit(check())
    rows = table()
    names = argv or list(rows)
    missing = [n for n in names if n not in rows or not (MASTERS / f"{n}.mkv").exists()]
    if missing:
        sys.exit(f"make_gifs: no cut or no master for {missing}")
    with concurrent.futures.ThreadPoolExecutor(4) as pool:
        results = list(pool.map(lambda n: make(n, rows[n]), names))
    for name, size, step, how in results:
        if step or size > LIMIT:
            over = "  OVER THE LIMIT" if size > LIMIT else ""
            print(f"{name}: {size / 1e6:.1f} MB, {how}{over}")
    print(f"make_gifs: {len(results)} made, {sum(r[1] for r in results) / 1e6:.0f} MB")


if __name__ == "__main__":
    main(sys.argv[1:])
