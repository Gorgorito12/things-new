"""Points FONTS\\fonts3.xml at the extended fonts: every TypeFace of an extended family gets the new name.

    python -I edit_fonts3.py <fonts3.xml>             # edits it in place (the first run keeps fonts3.xml.orig)
    python -I edit_fonts3.py <fonts3.xml> --check     # exit code 1 if an entry still names an old family
    python -I edit_fonts3.py <fonts3.xml> --restore   # the old family names back, the rest untouched

It changes only TypeFace values, and only those of the three extended families, whatever entries the file
holds when it runs, so it can run again after new entries were added. Everything else (other params,
comments, the UTF-16 encoding with its byte order mark, the line ends) stays byte for byte.
"""
import pathlib
import re
import shutil
import sys

FAMILIES = {
    "Formal436 BT": "Formal436 BT WoL",
    "Franklin Gothic Medium": "Franklin Gothic Medium WoL",
    "Monotype Corsiva": "Monotype Corsiva WoL",
}
TYPEFACE = re.compile(r'(?P<head>\bTypeFace\s*=\s*(?P<q>["\']))(?P<value>[^"\']*)(?P=q)', re.IGNORECASE)


def read(path):
    raw = path.read_bytes()
    for bom, codec in ((b"\xff\xfe", "utf-16-le"), (b"\xfe\xff", "utf-16-be"), (b"\xef\xbb\xbf", "utf-8")):
        if raw.startswith(bom):
            return bom, codec, raw[len(bom):].decode(codec)
    return b"", "utf-8", raw.decode("utf-8")


def edit(text, mapping):
    """Returns the new text and the number of values changed. Names compare without case, as Windows does."""
    lower = {k.lower(): v for k, v in mapping.items()}
    count = 0

    def sub(m):
        nonlocal count
        new = lower.get(m.group("value").strip().lower())
        if new is None or m.group("value") == new:
            return m.group(0)
        count += 1
        return m.group("head") + new + m.group("q")
    return TYPEFACE.sub(sub, text), count


def faces(text):
    out = {}
    for m in TYPEFACE.finditer(text):
        out[m.group("value")] = out.get(m.group("value"), 0) + 1
    return out


def main(argv):
    if not argv or argv[0].startswith("-"):
        sys.exit(__doc__)
    path = pathlib.Path(argv[0])
    bom, codec, text = read(path)
    if "--check" in argv:
        left = {f: n for f, n in faces(text).items() if f.strip().lower() in {k.lower() for k in FAMILIES}}
        for face, n in sorted(faces(text).items()):
            print(f"  {n:4d}  TypeFace={face!r}")
        if left:
            sys.exit(f"edit_fonts3: {sum(left.values())} entries still name an old family")
        print("edit_fonts3: every entry of the extended families names the new fonts")
        return
    mapping = {v: k for k, v in FAMILIES.items()} if "--restore" in argv else FAMILIES
    new, count = edit(text, mapping)
    if count:
        backup = path.with_name(path.name + ".orig")
        if not backup.exists() and "--restore" not in argv:
            shutil.copy2(path, backup)
        path.write_bytes(bom + new.encode(codec))
    print(f"edit_fonts3: {count} TypeFace values changed in {path}")


if __name__ == "__main__":
    main(sys.argv[1:])
