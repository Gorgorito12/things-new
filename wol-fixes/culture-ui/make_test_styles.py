"""Makes PROVISIONAL test styles for the key cultureUI: the minimised interface's atlases recoloured for two families
(Asian `as`, Middle Eastern `me`), each with a Great War variant (`_gw`). They only show that the key switches the
textures; they are not art for the mod and are not kept in the repository.

    python make_test_styles.py <WoL folder> <out folder> [--tools <aoe3-blender-tools>] [--python <its venv python>]

Writes <out>\\ui\\ingame\\<atlas>_<suffix>.ddt (the layout aoe3-blender-tools' ui_preview --override reads and
apply_fix.py --styles copies into the game) with aoe3-blender-tools' tools/recolor_textures.py, which keeps each file's
format, size and mip levels and changes only the colours (OKLCH). The atlases are read from <WoL folder>\\art\\ui\\ingame.
"""
import argparse
import pathlib
import shutil
import subprocess
import sys
import tempfile

# The loose atlases of the minimised interface (wol-fixes/culture-ui/inventory.md): the three resource panel skins and
# the frames, buttons and panels around them.
ATLASES = [
    "asi_ui_max", "eur_max_ui", "nat_ui_max", "ingame_ui_small_01_asian", "ingame_ui_small_01_ypack",
    "ingame_ui_02x_ypack", "ingame_ui_small_02_ypack", "ingame_ui_small_03x_ypack", "ingame_ui_small_04x_ypack",
    "warwick_timer_panel",
]
# suffix -> recolor_textures.py options. Deliberately loud, so a picture shows at once which style is drawn.
STYLES = {
    "as": ["--hue", "-35", "--chroma", "1.8"],                          # lacquer red
    "as_gw": ["--hue", "-35", "--chroma", "0.35", "--lightness", "0.8"],  # the same, grey and darker
    "me": ["--hue", "150", "--chroma", "1.7"],                          # turquoise
    "me_gw": ["--hue", "40", "--chroma", "0.6", "--lightness", "0.9"],   # khaki
}
DEFAULT_TOOLS = pathlib.Path(__file__).resolve().parents[3] / "aoe3-blender-tools"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("wol")
    parser.add_argument("out")
    parser.add_argument("--tools", default=str(DEFAULT_TOOLS))
    parser.add_argument("--python")
    args = parser.parse_args()
    source = pathlib.Path(args.wol) / "art" / "ui" / "ingame"
    tools = pathlib.Path(args.tools)
    python = args.python or str(tools / "venv" / "Scripts" / "python.exe")
    out = pathlib.Path(args.out) / "ui" / "ingame"
    out.mkdir(parents=True, exist_ok=True)
    missing = [a for a in ATLASES if not (source / (a + ".ddt")).exists()]
    if missing:
        sys.exit(f"make_test_styles: not in {source}: {', '.join(missing)}")
    with tempfile.TemporaryDirectory() as temp:
        inputs = pathlib.Path(temp) / "in"
        inputs.mkdir()
        for atlas in ATLASES:
            shutil.copy2(source / (atlas + ".ddt"), inputs / (atlas + ".ddt"))
        for suffix, options in STYLES.items():
            result = pathlib.Path(temp) / suffix
            command = [python, "-I", str(tools / "tools" / "recolor_textures.py"), str(inputs), "--out", str(result)]
            subprocess.run(command + options, check=True, stdout=subprocess.DEVNULL)
            for atlas in ATLASES:
                shutil.copy2(result / (atlas + ".ddt"), out / f"{atlas}_{suffix}.ddt")
            print(f"{suffix}: {len(ATLASES)} atlases")
    print(f"written to {out}")


if __name__ == "__main__":
    main()
