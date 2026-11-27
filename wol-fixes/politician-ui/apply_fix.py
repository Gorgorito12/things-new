"""Sets up Wars of Liberty's politicians for the DLL key `politicianEnablesTech` (request #70): the age-up dialog shows
the flag of an immigrant politician apart from the techs it makes available, each tech with its own icon, its name
and, on hover, the tech's own rollover.

    python apply_fix.py <WoL folder>                apply (a backup of every file it changes goes to
                                                    <WoL folder>\\politician-ui-backup\\ first)
    python apply_fix.py <WoL folder> --strings      also take the hand-written tech list out of the politicians'
                                                    rollover texts, in every string table (the dialog shows the
                                                    techs now); prints one string before and after
    python apply_fix.py <WoL folder> --check        say what is applied, change nothing
    python apply_fix.py <WoL folder> --restore      put the backed-up files back
    python apply_fix.py --layout <in.xml> <out.xml> only write the dialog file (any number of places)
    (a folder under steamapps is refused unless --force is given)

What it changes (README.txt has the why):
- data\\techtreey.xml: every <Tech> flagged AgeUpgrade gets one <PoliticianEnablesTech>Name</PoliticianEnablesTech>
  per `TechStatus obtainable` effect on an immigrant tech (a tech whose name holds "immigrant"), in effect order,
  after its <Icon>. Nothing else in the tech changes: the effects still make the techs available;
- data\\uipoliticianEuropeandlg.xml: in each place, the key's gadgets (hidden until the DLL fills them), sized from
  that place's own portrait and description; and PoliticianButton3 made as tall as the other three buttons (it
  stopped at 381, so the bottom of the fourth place took no clicks);
- Startup\\wol.cfg: the line `politicianEnablesTech` when the file has none;
- with --strings: data\\stringtabley.xml, translations\\*\\stringtabley.xml and data\\stringtabley.xml.* copies.
The pictures (politiciandata.xml and the DDTs) stay as they are: the DLL shows the flag part of the same picture.
"""
import pathlib
import re
import shutil
import sys

BACKUP = "politician-ui-backup"
TECHTREE = "data/techtreey.xml"
DIALOG = "data/uipoliticianEuropeandlg.xml"
CFG = "Startup/wol.cfg"
KEY = "politicianEnablesTech"
TAG = "PoliticianEnablesTech"

# The flag in WoL's 192 x 396 politician pictures: 145 x 231 pixels at the top left. The portrait shows 0.75 x
# 0.7734375 of the picture (the exe sets those texture coordinates), the flag 0.75 x FLAG_V of it.
FLAG_V = 0.5833
STOCK_V = 0.7734375
GAP = 8         # between the flag and the techs, and between the description and the techs
ROW = 30        # a tech row's height
ROW_STEP = 33
ICON_W = 22     # 22 x 30 in the 1024 x 768 space is square at 16:9 (1920 x 1080: 41 x 42 pixels)


# --- files ------------------------------------------------------------------------------------------------------

def read_text(path):
    raw = path.read_bytes()
    if raw[:2] == b"\xff\xfe":
        return raw[2:].decode("utf-16-le"), "utf-16"
    if raw[:3] == b"\xef\xbb\xbf":
        return raw[3:].decode("utf-8"), "utf-8-sig"
    return raw.decode("utf-8"), "utf-8"


def write_text(path, text, encoding):
    if encoding == "utf-16":
        path.write_bytes(b"\xff\xfe" + text.encode("utf-16-le"))
    elif encoding == "utf-8-sig":
        path.write_bytes(b"\xef\xbb\xbf" + text.encode("utf-8"))
    else:
        path.write_bytes(text.encode("utf-8"))


def backup(root, rel):
    src = root / rel
    dst = root / BACKUP / rel
    if src.exists() and not dst.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


# --- techtreey.xml ----------------------------------------------------------------------------------------------

TECH_RE = re.compile(r"(<Tech\s+name\s*=\s*['\"]([^'\"]+)['\"][^>]*>)(.*?)(</Tech>)", re.S)
OBTAINABLE_RE = re.compile(r"<Effect\s+type\s*=\s*['\"]TechStatus['\"]\s+status\s*=\s*['\"]obtainable['\"]\s*>"
                           r"\s*([^<\s]+)\s*</Effect>", re.I)


def politician_tags(body):
    """The immigrant techs a politician's effects make obtainable, in order, no repeats."""
    if not re.search(r"<Flag>\s*AgeUpgrade\s*</Flag>", body, re.I):
        return []
    out = []
    for name in OBTAINABLE_RE.findall(body):
        if "immigrant" in name.lower() and name not in out:
            out.append(name)
    return out


def add_tags(text):
    """Returns (new text, {politician: [techs]}) with the tags added where missing."""
    added = {}

    def one(m):
        head, name, body, tail = m.group(1), m.group(2), m.group(3), m.group(4)
        if TAG.lower() in body.lower():
            return m.group(0)
        techs = politician_tags(body)
        if not techs:
            return m.group(0)
        icon = re.search(r"(\r?\n)([ \t]*)<Icon>[^<]*</Icon>", body)
        anchor = icon or re.search(r"(\r?\n)([ \t]*)<", body)
        nl, indent = anchor.group(1), anchor.group(2)
        lines = "".join(f"{nl}{indent}<{TAG}>{t}</{TAG}>" for t in techs)
        pos = anchor.end() if icon else anchor.start()
        added[name] = techs
        return head + body[:pos] + lines + body[pos:] + tail

    return TECH_RE.sub(one, text), added


def tagged(text):
    """{politician: ([techs], rollover ID)} as the file has them."""
    out = {}
    for m in TECH_RE.finditer(text):
        techs = re.findall(rf"<{TAG}>\s*([^<]+?)\s*</{TAG}>", m.group(3))
        if techs:
            rollover = re.search(r"<RolloverTextID>\s*(\d+)\s*<", m.group(3))
            out[m.group(2)] = (techs, int(rollover.group(1)) if rollover else None)
    return out


# --- uipoliticianEuropeandlg.xml --------------------------------------------------------------------------------

def rect(line):
    return [int(v) for v in re.search(r'size1024="([^"]+)"', line).group(1).split()]


def with_attrs(line, name, box, extra=""):
    line = re.sub(r'name="[^"]+"', f'name="{name}"', line, count=1)
    line = re.sub(r'size1024="[^"]+"', 'size1024="%d %d %d %d"' % tuple(box), line, count=1)
    line = re.sub(r'\s+hidden=""', "", line)
    return line.replace("/>", f' hidden=""{extra}/>', 1) if line.rstrip().endswith("/>") else line


def place_gadgets(n, portrait_line, description_line, name_line, indent, nl):
    px0, py0, px1, py1 = rect(portrait_line)
    dx0, dy0, dx1, _ = rect(description_line)
    flag_bottom = py0 + round((py1 - py0) * FLAG_V / STOCK_V)
    band = flag_bottom + GAP
    p = f"PoliticianDlg-Poli{n}"
    out = []
    flag = with_attrs(portrait_line.strip(), f"{p}EnablesTechPortrait", [px0, py0, px1, flag_bottom])
    flag = re.sub(r'texturecoords="[^"]*"', f'texturecoords="0 0 0.75 {FLAG_V}"', flag)
    out.append(flag)
    out.append(with_attrs(description_line.strip(), f"{p}EnablesTechDescription", [dx0, dy0, dx1, flag_bottom - 2]))
    # The tech names in the description's own font and colour.
    font = re.search(r'textfont="[^"]*"', description_line)
    size = re.search(r'textfontsize="[^"]*"', description_line)
    colour = re.search(r'textcolor="[^"]*"', description_line)
    name_style = (' type="formatText" textmarkup="" formattextconvertuserlf="" texttruecentervert="" '
                  + " ".join(m.group(0) for m in (colour, font, size) if m))
    icon_tpl = ('<gadget name="{name}" type="gadget" size1024="{x0} {y0} {x1} {y1}" '
                'background="ui\\ingame\\politicians\\politician_admiral" hidden="" z="6"/>')
    name_tpl = '<gadget name="{name}"' + name_style + ' size1024="{x0} {y0} {x1} {y1}" hidden="" z="6"/>'
    # One or two techs: one per row, the full width of the place.
    for k in range(2):
        y0 = band + k * ROW_STEP
        out.append(icon_tpl.format(name=f"{p}EnablesTech{k}Icon", x0=px0, y0=y0, x1=px0 + ICON_W, y1=y0 + ROW))
        out.append(name_tpl.format(name=f"{p}EnablesTech{k}Name", x0=px0 + ICON_W + 6, y0=y0, x1=dx1, y1=y0 + ROW))
    # Three or four: two per row.
    col = (dx1 - px0 - 6) // 2
    for k in range(4):
        x0 = px0 + (k % 2) * (col + 6)
        y0 = band + (k // 2) * ROW_STEP
        out.append(icon_tpl.format(name=f"{p}EnablesTechGrid{k}Icon", x0=x0, y0=y0, x1=x0 + ICON_W, y1=y0 + ROW))
        out.append(name_tpl.format(name=f"{p}EnablesTechGrid{k}Name", x0=x0 + ICON_W + 4, y0=y0, x1=x0 + col,
                                   y1=y0 + ROW))
    return "".join(f"{nl}{indent}{line}" for line in out)


def make_layout(text):
    """The dialog file with the key's gadgets in every place it has; unchanged places keep every byte."""
    if "EnablesTechPortrait" in text:
        return text, 0
    nl = "\r\n" if "\r\n" in text else "\n"
    places = 0
    for n in range(5):
        portrait = re.search(rf'([ \t]*)(<gadget name="PoliticianDlg-Poli{n}Portrait"[^\n]*?/>)', text)
        description = re.search(rf'<gadget name="PoliticianDlg-Poli{n}Description"[^\n]*?/>', text)
        name = re.search(rf'<gadget name="PoliticianDlg-Poli{n}Name"[^\n]*?/>', text)
        if not (portrait and description and name):
            continue
        block = place_gadgets(n, portrait.group(2), description.group(0), name.group(0), portrait.group(1), nl)
        text = text[:portrait.end()] + block + text[portrait.end():]
        places += 1
    # PoliticianButton3 as tall as the others (WoL's file has 381 for this one only).
    buttons = re.findall(r'name="PoliticianDlg-PoliticianButton\d" type="button"[^>]*size1024="(\d+ \d+ \d+) (\d+)"',
                         text)
    bottoms = [int(b) for _, b in buttons]
    if bottoms:
        tallest = max(bottoms)
        text = re.sub(r'(name="PoliticianDlg-PoliticianButton\d" type="button"[^>]*size1024="\d+ \d+ \d+ )(\d+)"',
                      lambda m: m.group(1) + str(tallest) + '"', text)
    return text, places


# --- strings ----------------------------------------------------------------------------------------------------

# The hand-written list at the end of a rollover: a line "+ Technologies:" (any language: a "+ " line that ends
# with ":") and the "- Name: what it does" lines after it. In the XML the line breaks are the two characters \n.
LIST_RE = re.compile(r"\\n\+ [^\\<]*:(?:\\n- (?:(?!\\n).)*)+")


def strip_list(value):
    return LIST_RE.sub("", value)


def strip_strings(text, ids):
    changed = []

    def one(m):
        start, sid, value, end = m.group(1), int(m.group(3)), m.group(4), m.group(5)
        if sid not in ids:
            return m.group(0)
        new = strip_list(value)
        if new == value:
            return m.group(0)
        changed.append((sid, value, new))
        return start + new + end

    out = re.sub(r"(<String _locID=(['\"])(\d+)\2>)(.*?)(</String>)", one, text, flags=re.S)
    return out, changed


def string_tables(root):
    out = [root / "data/stringtabley.xml"]
    out += sorted((root / "translations").glob("*/stringtabley.xml"))
    out += [p for p in sorted((root / "data").glob("stringtabley.xml.*")) if p.suffix not in (".bak",)]
    return [p for p in out if p.exists()]


# --- main -------------------------------------------------------------------------------------------------------

def apply(root, strings):
    tree_path = root / TECHTREE
    tree, enc = read_text(tree_path)
    new_tree, added = add_tags(tree)
    if added:
        backup(root, TECHTREE)
        write_text(tree_path, new_tree, enc)
    print(f"{TECHTREE}: {len(added)} politicians got <{TAG}> lines ({sum(len(v) for v in added.values())} tags)")

    dlg_path = root / DIALOG
    dlg, enc = read_text(dlg_path)
    new_dlg, places = make_layout(dlg)
    if new_dlg != dlg:
        backup(root, DIALOG)
        write_text(dlg_path, new_dlg, enc)
    print(f"{DIALOG}: the key's gadgets in {places} places" if places else f"{DIALOG}: already has the gadgets")

    cfg_path = root / CFG
    if cfg_path.exists():
        cfg, enc = read_text(cfg_path)
        if not re.search(rf"^\s*{KEY}\b", cfg, re.I | re.M):
            backup(root, CFG)
            nl = "\r\n" if "\r\n" in cfg else "\n"
            write_text(cfg_path, cfg.rstrip("\r\n") + nl + KEY + nl, enc)
            print(f"{CFG}: added the line {KEY}")

    if strings:
        ids = {rid for _, rid in tagged(new_tree).values() if rid is not None}
        shown = False
        for path in string_tables(root):
            text, enc = read_text(path)
            new, changed = strip_strings(text, ids)
            if changed:
                rel = path.relative_to(root).as_posix()
                backup(root, rel)
                write_text(path, new, enc)
                print(f"{rel}: the tech list taken out of {len(changed)} rollover texts")
                if not shown:
                    shown = True
                    sid, before, after = changed[0]
                    print(f"  string {sid} before: {before}")
                    print(f"  string {sid} after:  {after}")


def check(root):
    tree, _ = read_text(root / TECHTREE)
    tags = tagged(tree)
    dlg, _ = read_text(root / DIALOG)
    print(f"{TECHTREE}: {len(tags)} politicians with <{TAG}>")
    print(f"{DIALOG}: {'has' if 'EnablesTechPortrait' in dlg else 'does not have'} the key's gadgets")
    cfg = root / CFG
    if cfg.exists():
        text, _ = read_text(cfg)
        print(f"{CFG}: {'has' if re.search(rf'^\s*{KEY}\b', text, re.I | re.M) else 'does not have'} {KEY}")


def restore(root):
    saved = root / BACKUP
    if not saved.exists():
        print("nothing to restore")
        return
    for path in sorted(saved.rglob("*")):
        if path.is_file():
            rel = path.relative_to(saved)
            shutil.copy2(path, root / rel)
            print(f"restored {rel.as_posix()}")
    shutil.rmtree(saved)


def main(argv):
    if len(argv) >= 3 and argv[0] == "--layout":
        text, enc = read_text(pathlib.Path(argv[1]))
        out, places = make_layout(text)
        write_text(pathlib.Path(argv[2]), out, enc)
        print(f"wrote {argv[2]}: the key's gadgets in {places} places")
        return
    args = [a for a in argv if not a.startswith("--")]
    if len(args) != 1:
        sys.exit(__doc__)
    root = pathlib.Path(args[0])
    if not (root / TECHTREE).exists():
        sys.exit(f"{root}: no {TECHTREE}")
    if "steamapps" in str(root.resolve()).lower() and "--force" not in argv:
        sys.exit("refusing a folder under steamapps (pass --force to allow it)")
    if "--restore" in argv:
        restore(root)
    elif "--check" in argv:
        check(root)
    else:
        apply(root, "--strings" in argv)


if __name__ == "__main__":
    main(sys.argv[1:])
