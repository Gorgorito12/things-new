"""Adds the missing letters (ă ș ț and the rest of Latin Extended-A) to the game's fonts in a Wars of
Liberty folder, built from each font's own letters and accents, and points FONTS\\fonts3.xml at them.

    python apply_fix.py <WoL folder> --tool <aoe3-blender-tools folder> [--python <python>] [--out <folder>]
    python apply_fix.py <WoL folder> --restore

What it does:
1. reads the three fonts from the folder's own FONTS\\Fonts.bar (it never changes that archive):
     TT1141M_.TTF  Formal436 BT            (most of the interface)
     framd.ttf     Franklin Gothic Medium  (tooltips, stat text)
     MTCORSVA.TTF  Monotype Corsiva        (titles, the loading screen's map name)
2. runs tools/extend_font.py of aoe3-blender-tools on each (it needs fontTools and Pillow:
   `pip install -r requirements-fonts.txt` in that folder; --python names the Python that has them);
3. writes the new fonts next to Fonts.bar as loose files, under new family names so they never clash
   with the originals:
     FONTS\\TT1141M_WoL.TTF   "Formal436 BT WoL"
     FONTS\\framd_WoL.ttf     "Franklin Gothic Medium WoL"
     FONTS\\MTCORSVA_WoL.TTF  "Monotype Corsiva WoL"
   The game loads loose .ttf files of FONTS\\ as it loads those of Fonts.bar (tested in game);
4. changes, in FONTS\\fonts3.xml, every TypeFace of those three families to the new names (edit_fonts3.py,
   beside this script: only those values change, whatever entries the file holds, so it can be run again
   after the file was edited).
A proof sheet and a report per font go to <WoL folder>\\fonts-fix-backup\\ (or <out>\\), with the copy
of fonts3.xml from before the change. --restore deletes the three fonts and puts the old names back in
fonts3.xml (only the TypeFace values; the rest of the file is left as it is now).

--out <folder> writes FONTS\\<the three fonts> and FONTS\\fonts3.xml there instead, and changes nothing in
the WoL folder.

The fonts belong to Bitstream (Formal436 BT) and Monotype/ITC (Franklin Gothic, Monotype Corsiva). This
script ships no font: it changes the copies the team already has. Whether the changed files may be
shipped with the mod is the team's decision under those licences.
"""
import json
import os
import pathlib
import shutil
import struct
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import edit_fonts3  # noqa: E402

FONTS = [  # stored name in Fonts.bar, loose file written, new family
    ("TT1141M_.TTF", "TT1141M_WoL.TTF", "Formal436 BT WoL"),
    ("framd.ttf", "framd_WoL.ttf", "Franklin Gothic Medium WoL"),
    ("MTCORSVA.TTF", "MTCORSVA_WoL.TTF", "Monotype Corsiva WoL"),
]


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def bar_entries(path):
    """[(stored name, offset, size)] of a legacy .bar archive (header ESPN)."""
    raw = path.read_bytes()
    if raw[:4] != b"ESPN":
        sys.exit(f"apply_fix: {path} is not a .bar archive")
    pos = struct.unpack_from("<I", raw, 0x11C)[0]

    def u32():
        nonlocal pos
        pos += 4
        return struct.unpack_from("<I", raw, pos - 4)[0]

    def text(n):
        nonlocal pos
        pos += 2 * n
        return raw[pos - 2 * n:pos].decode("utf-16-le")
    root = text(u32())
    out = []
    for _ in range(u32()):
        offset, size, _ = u32(), u32(), u32()
        pos += 16
        out.append((root + text(u32()), offset, size))
    return raw, out


def extract(bar, folder):
    raw, entries = bar_entries(bar)
    found = {}
    for stored, offset, size in entries:
        name = stored.replace("/", "\\").split("\\")[-1]
        for want, _, _ in FONTS:
            if name.lower() == want.lower():
                path = folder / want
                path.write_bytes(raw[offset:offset + size])
                found[want] = path
    missing = [w for w, _, _ in FONTS if w not in found]
    if missing:
        sys.exit(f"apply_fix: {bar} has no " + ", ".join(missing))
    return found


def restore(wol):
    fonts = wol / "FONTS"
    for _, loose, _ in FONTS:
        p = fonts / loose
        if p.exists():
            p.unlink()
            print(f"apply_fix: removed {p}")
    edit_fonts3.main([str(fonts / "fonts3.xml"), "--restore"])


def main():
    if len(sys.argv) < 2 or sys.argv[1].startswith("-"):
        sys.exit(__doc__)
    wol = pathlib.Path(sys.argv[1])
    fonts = wol / "FONTS"
    if not (fonts / "Fonts.bar").exists() or not (fonts / "fonts3.xml").exists():
        sys.exit(f"apply_fix: {fonts} has no Fonts.bar or fonts3.xml")
    if "--restore" in sys.argv:
        restore(wol)
        return
    tool = arg("--tool")
    if not tool or not (pathlib.Path(tool) / "tools" / "extend_font.py").exists():
        sys.exit("apply_fix: --tool must name the aoe3-blender-tools folder (with tools\\extend_font.py)")
    script = pathlib.Path(tool) / "tools" / "extend_font.py"
    python = arg("--python", sys.executable)
    out = pathlib.Path(arg("--out")) if arg("--out") else None
    target = (out / "FONTS") if out else fonts
    side = out or (wol / "fonts-fix-backup")
    target.mkdir(parents=True, exist_ok=True)
    side.mkdir(parents=True, exist_ok=True)
    if not out and not (side / "fonts3.xml").exists():
        shutil.copy2(fonts / "fonts3.xml", side / "fonts3.xml")
    summary = []
    with tempfile.TemporaryDirectory() as tmp:
        src = extract(fonts / "Fonts.bar", pathlib.Path(tmp))
        for stored, loose, family in FONTS:
            stem = loose.rsplit(".", 1)[0]
            cmd = [python, "-I", "-X", "utf8", str(script), str(src[stored]), str(target / loose), "--family", family,
                   "--proof", str(side / f"proof-{stem}.png"), "--report", str(side / f"report-{stem}.json")]
            r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
            print(r.stdout, end="")
            if r.returncode:
                sys.exit(f"apply_fix: extend_font failed on {stored}:\n{r.stderr}")
            report = json.loads((side / f"report-{stem}.json").read_text(encoding="utf-8"))
            summary.append((loose, family, report["added_count"], "".join(report["not_built"])))
    xml = target / "fonts3.xml"
    if out:
        shutil.copy2(fonts / "fonts3.xml", xml)
    edit_fonts3.main([str(xml)])
    print()
    for loose, family, count, failed in summary:
        print(f"apply_fix: {target / loose}: {family!r}, {count} letters added"
              + (f", not built: {failed}" if failed else ""))
    print(f"apply_fix: proof sheets and reports in {side}")


if __name__ == "__main__":
    main()
