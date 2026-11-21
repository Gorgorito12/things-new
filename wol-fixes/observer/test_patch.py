"""The two map edits used to diagnose WoL's observer mode (request #81), for a TEST COPY of the game.

    python -I test_patch.py <RM4 folder> <output folder> [--emulate-observer]

For each of the 36 maps that carry the ESOC observer code it writes a patched copy to <output folder>
(the input folder is never written):
  1. the switch: `if (false == true) {` becomes `if (rmIsObserverMode() == true) {`, so the observer
     branch runs only when the lobby's Observer mode box is ticked (rmIsObserverMode is a syscall of
     WoL's uhc.dll);
  2. the map's own trigger helper `kbGetTechID` becomes `obsGetTechID`: wolai.upl now registers a
     syscall of that name, so the generated trigger script stops compiling with
     "trigtemp.xs: Error 0034: 'kbGetTechID' is already defined".
--emulate-observer (test only, never for players) also makes the map's trigger code treat the local
player as an observer (`FP=trCurrentPlayer()+2`), which is how the observer panel was seen on a single
PC, where the lobby host cannot sit in the last slot.
Byte-level replacements: line endings (CRLF) and encoding are kept.
"""
import pathlib
import sys

SWITCH_OLD = b"if (false == true) {"
SWITCH_NEW = b"if (rmIsObserverMode() == true) {"
EMULATE_OLD = b"FP=trCurrentPlayer(); if(trGetWorldDifficulty()"
EMULATE_NEW = b"FP=trCurrentPlayer()+2; if(trGetWorldDifficulty()"


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    src, dst = pathlib.Path(argv[0]), pathlib.Path(argv[1])
    emulate = "--emulate-observer" in argv
    if src.resolve() == dst.resolve():
        sys.exit("the output folder must differ from the RM4 folder")
    dst.mkdir(parents=True, exist_ok=True)
    count = 0
    for path in sorted(src.glob("*.xs")):
        data = path.read_bytes()
        if data.count(SWITCH_OLD) != 1 or b"StartInsertion" not in data:
            continue
        out = data.replace(SWITCH_OLD, SWITCH_NEW).replace(b"kbGetTechID", b"obsGetTechID")
        if emulate:
            if out.count(EMULATE_OLD) != 1:
                print(f"{path.name}: the observer test line was not found; skipped")
                continue
            out = out.replace(EMULATE_OLD, EMULATE_NEW)
        (dst / path.name).write_bytes(out)
        count += 1
        print(f"{path.name}: switch, {data.count(b'kbGetTechID')} kbGetTechID renamed"
              + (", local player as observer (test)" if emulate else ""))
    print(f"{count} maps written to {dst}")


if __name__ == "__main__":
    main(sys.argv[1:])
