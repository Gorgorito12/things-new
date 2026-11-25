"""Rebuilds the observer interface files of Wars of Liberty on WoL's current interface (request #81).

    python -I observer_ui.py build  <WoL folder> --out <folder> [--res 1920x1080,...] [--report <file>]
    python -I observer_ui.py apply  <WoL folder> --from <folder>
    python -I observer_ui.py check  <WoL folder> [--from <folder>]
    python -I observer_ui.py revert <WoL folder>
    python -I observer_ui.py gadgets <map.xs> --from <folder> [--res ...]

`gadgets` lists every gadget name a map's panel code shows, hides or tests (gadgetReal, gadgetUnreal,
gadgetToggle, trIsGadgetVisible; names built at run time by their fixed prefix) and checks that the
built files of each resolution have them.

<WoL folder> holds data\\. Everything there is only read, except by `apply` and `revert`.

What WoL's uhc.dll does for a local observer: it loads `uimainnewobserver<W>x<H>.xml` (and `...jp.xml` for
Japanese) instead of `uimainnew.xml` at 7 resolutions, and seven `...observer.xml` copies instead of the
minimized panels and two home city panels. Those copies were made from an older WoL interface: the one
WoL still ships in data\\Data3.bar. `build` finds what the observer copies changed in that older
interface and makes the same changes to the interface WoL uses now (the loose files of data\\, or
Data3.bar where there is none):

  - the observer's own gadgets (the ESOC panel: Spec_*, RTD*, m8ihazui2, the unit icon library ...) are
    added where the observer copy has them;
  - the containers the map hides (`...-SpecContainer`) are put around the same panels;
  - the attributes the observer copy changed (a panel moved out of the way, a background moved to its
    container ...) are changed the same way, unless WoL changed that attribute itself since, which is
    reported;
  - everything WoL added since (oil, the building search buttons, the colour picker ...) stays, and the
    observer-only rules below are applied to it.

Observer-only rules (observer_rules below), each seen in game:
  - WoL's 13 resource panels (SettlerCountDialog*: the observer's own, empty economy, drawn under the
    panel's player rows) go into one hidden container, Spec_WoLResourcePanels;
  - WoL's icon row (Menu > Icons) and building search row move below the observer's top band (the
    population box), as they would cover it;
  - the home city button and its shipment counter go back where the observer copy has them (WoL moved
    them over the panel's options bar);
  - the panel's flags: one Spec_Flag_<column>_<civ ID> per WoL civ (civ ID = its place in civs.xml,
    commented-out civs left out, plus one: what kbGetCiv() returns), with the civ's large flag button
    set, instead of ESOC's stock-numbered ones;
  - WoL's later texts of the unit panel (LOS, Train Points, Speed, Garrison, two empty ones), placed for
    WoL's centre panel, are moved out of the screen and hidden: ESOC moved the unit panel to the right
    and shows speed and garrison in its own row.

New resolutions (NEW_RES): the panel is laid out in pixels (the map's loadWxH() presets and its icons
are pixel offsets and 49 px cells written into text, fonts are pixel sizes), so a new resolution starts
from the widest existing one not wider, and each panel gadget keeps its pixel size and its place from
the screen's centre and from the top or bottom edge (retarget). The layout keeps that resolution's
Spec_PresetConfig gadget, so the map runs its loadWxH() and needs no new code. These files are only
loaded if WoL's DLL adds the resolutions to its list.

`apply` copies the built files into data\\, keeping each file it replaces as <file>.obs-orig (once);
`revert` puts them back and deletes the files `apply` added (listed in data\\observer-ui.obs-added).
`check` says what is installed; with --from, whether data\\ holds exactly those files.
"""
import hashlib
import os
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent


def _tools_repo():
    """aoe3-blender-tools: AOE3_BLENDER_TOOLS, else a folder of that name beside this repo (or beside
    any folder above it, for a worktree)."""
    if os.environ.get("AOE3_BLENDER_TOOLS"):
        return pathlib.Path(os.environ["AOE3_BLENDER_TOOLS"])
    for up in REPO.parents:
        if (up / "aoe3-blender-tools").is_dir():
            return up / "aoe3-blender-tools"
    return REPO.parent / "aoe3-blender-tools"


TOOLS_REPO = _tools_repo()
sys.path.insert(0, str(REPO / "tools"))
sys.path.insert(0, str(TOOLS_REPO / "aoe3_blender_tools" / "aoe3game"))
try:
    import uilayout as U  # aoe3-blender-tools: a layout file as a tree that keeps every byte
except ImportError:
    sys.exit(f"observer_ui: needs aoe3-blender-tools' uilayout.py (looked in {TOOLS_REPO}; set AOE3_BLENDER_TOOLS)")
import bar as BAR  # noqa: E402  (this repo's tools/)
import xmbedit as XMB  # noqa: E402

RESOLUTIONS = ["1280x720", "1280x768", "1280x800", "1366x768", "1600x900", "1680x1050", "1920x1080"]
PANELS = ["uicommandpanelnewmin", "uiminimappanelnewmin", "uinativecommandpanel2min", "uiunitselectionmin",
          "uiunitstatpanel3min", "uihomecitycommandpanel", "uihomecitytransportpanelheader"]
MAIN = "uimainnew"
ADDED_LIST = "observer-ui.obs-added"


# --- reading WoL's files -------------------------------------------------------------------------

class Data:
    """WoL's data folder: loose files first, then its .bar archives (Data3, Data2, Data)."""

    def __init__(self, wol):
        self.data = pathlib.Path(wol) / "data"
        if not self.data.is_dir():
            sys.exit(f"observer_ui: {self.data} is not a folder")
        self.bars = [self.data / b for b in ("Data3.bar", "Data2.bar", "Data.bar") if (self.data / b).exists()]
        self._entries = {}

    def entries(self, archive):
        if archive not in self._entries:
            self._entries[archive] = {name.lower(): (off, size) for name, off, size in BAR.read_entries(archive)}
        return self._entries[archive]

    def from_bar(self, name, archive=None):
        """The text of data\\<name> from an archive (the first that has it), or None."""
        for archive in ([archive] if archive else self.bars):
            hit = self.entries(archive).get(("data\\" + name + ".xmb").lower())
            if hit:
                with open(archive, "rb") as f:
                    f.seek(hit[0])
                    raw = f.read(hit[1])
                elems, attrs, root = XMB.parse(XMB.decode(raw))
                xml = XMB.to_xml(elems, attrs, root)
                return xml if isinstance(xml, str) else xml.decode("utf-8")
        return None

    def loose(self, name):
        """data\\<name> as WoL ships it: the .obs-orig copy when `apply` replaced it."""
        for p in (self.data / (name + ".obs-orig"), self.data / name):
            if p.exists():
                return p.read_bytes()
        return None

    def current(self, name):
        """The file the game loads now for a player (loose, else the archives), as a Doc."""
        raw = self.loose(name)
        if raw is not None:
            return U.parse(raw), "loose"
        text = self.from_bar(name)
        if text is None:
            sys.exit(f"observer_ui: data\\{name} is neither loose nor in an archive")
        return U.Doc(U.parse_text(text), "utf-8", b""), "Data3.bar"

    def base(self, name):
        """The older interface the observer copies were made from: WoL's Data3.bar."""
        text = self.from_bar(name, self.data / "Data3.bar")
        if text is None:
            sys.exit(f"observer_ui: data\\{name} is not in Data3.bar")
        return U.Doc(U.parse_text(text), "utf-8", b"")

    def observer(self, name):
        raw = self.loose(name)
        if raw is None:
            sys.exit(f"observer_ui: data\\{name} is missing (WoL's observer copy)")
        return U.parse(raw)


# --- matching gadgets ------------------------------------------------------------------------------

def gname(el):
    return (el.get("name") or "").lower()


def is_gadget(el):
    return isinstance(el, U.Element) and el.name_lower == "gadget"


def kids(el):
    return [c for c in el.children if is_gadget(c)]


def layout_root(doc):
    for c in doc.root.children:
        if isinstance(c, U.Element) and c.name_lower == "layout":
            return c
    raise U.LayoutError("no <layout> element")


def keyed(doc, skip=lambda el: False):
    """{key: element} for every gadget; key = the names of its ancestors and its own, with the gadgets
    `skip` names left out of the chain, plus a number when that chain repeats. Document order."""
    out = {}
    seen = {}

    def walk(el, chain):
        for c in kids(el):
            if skip(c):
                walk(c, chain)
                continue
            ch = chain + (gname(c),)
            seen[ch] = seen.get(ch, 0) + 1
            out[ch + (seen[ch],)] = c
            walk(c, ch)
    walk(layout_root(doc), ())
    return out


def by_name(doc):
    out = {}
    for g in layout_root(doc).walk():
        if is_gadget(g):
            out.setdefault(gname(g), []).append(g)
    return out


class Diff:
    """What an observer copy O changed in its base B."""

    def __init__(self, base, obs):
        self.base, self.obs = base, obs
        bnames = {gname(g) for g in layout_root(base).walk() if is_gadget(g)}
        self.base_names = bnames
        self.obs_names = {gname(g) for g in layout_root(obs).walk() if is_gadget(g)}
        self.added = set()  # observer-added gadgets (ids)
        for g in layout_root(obs).walk():
            if is_gadget(g) and gname(g) not in bnames:
                self.added.add(id(g))
        self.bk = keyed(base)
        self.ok = keyed(obs, skip=lambda el: id(el) in self.added)
        self.okey = {id(v): k for k, v in self.ok.items()}
        self.missing = [k for k in self.bk if k not in self.ok]  # base gadgets the copy dropped or moved
        self.edits = []  # (key, attr, base value, observer value)
        for k, b in self.bk.items():
            o = self.ok.get(k)
            if o is None:
                continue
            ba, oa = b.attributes(), o.attributes()
            for a in sorted(set(ba) | set(oa)):
                if ba.get(a) != oa.get(a):
                    self.edits.append((k, a, ba.get(a), oa.get(a)))
        # the top-most observer-added gadgets: wrappers (they hold base gadgets) and plain insertions
        self.wrappers, self.inserts = [], []
        for g in layout_root(obs).walk():
            if not is_gadget(g) or id(g) not in self.added:
                continue
            parent = g.parent
            if is_gadget(parent) and id(parent) in self.added:
                continue
            held = [c for c in kids(g) if id(c) not in self.added]
            if held:
                self.wrappers.append((g, held))
            else:
                self.inserts.append(g)
        # taken before the merge moves anything out of the observer copy
        self.top_order = kids(layout_root(obs))
        self.before = {}
        self.pkey = {}
        for g in self.inserts:
            sib = kids(g.parent)
            self.before[id(g)] = sib[:sib.index(g)]
            self.pkey[id(g)] = self.parent_key(g)

    def anchor(self, el):
        """The nearest earlier sibling of `el` in the observer copy: ('base', key) or ('added', element),
        or None when it is the first gadget of its parent."""
        sib = kids(el.parent)
        i = sib.index(el)
        if i == 0:
            return None
        prev = sib[i - 1]
        if id(prev) in self.added:
            return ("added", prev)
        return ("base", self.okey[id(prev)])

    def parent_key(self, el):
        """The key of `el`'s parent gadget (wrappers left out), or () for the layout."""
        p = el.parent
        while is_gadget(p) and id(p) in self.added:
            p = p.parent
        if not is_gadget(p):
            return ()
        return self.okey[id(p)]


# --- editing a tree --------------------------------------------------------------------------------

def indent_of(parent):
    """The indentation of `parent`'s children (from its first child line), and the line end."""
    for c in parent.children:
        if isinstance(c, U.Raw) and c.kind == "text" and "\n" in c.raw:
            nl = "\r\n" if "\r\n" in c.raw else "\n"
            return c.raw.rsplit("\n", 1)[1], nl
    return "\t", "\n"


def detach(el):
    U.remove(el)


def put(parent, el, after=None):
    """Puts element `el` into `parent` after child element `after` (None: first), on a line of its own."""
    U._open_up(parent)
    ind, nl = indent_of(parent)
    if parent.name_lower == "gadget" and not any(isinstance(c, U.Element) for c in parent.children):
        pind, _ = U._indent_of(parent) if parent.parent is not None else ("", nl)
        ind = pind + "\t"
    ch = parent.children
    if after is None:
        i = 0
        # after the leading text of the parent (its own text, e.g. a button label), before the first element
        while i < len(ch) and not isinstance(ch[i], U.Element):
            i += 1
        ch[i:i] = [U.Raw("text", nl + ind, parent), el]
    else:
        i = ch.index(after) + 1
        ch[i:i] = [U.Raw("text", nl + ind, parent), el]
    el.parent = parent
    if not any(isinstance(c, U.Raw) and c.kind == "text" and "\n" in c.raw for c in ch[ch.index(el) + 1:]) \
            and parent.close and ch[-1] is el:
        pind = U._indent_of(parent)[0] if parent.parent is not None and parent.parent.parent is not None else ""
        ch.append(U.Raw("text", nl + pind, parent))


def rect_text(r):
    return " ".join(str(int(v)) if float(v).is_integer() else f"{v:g}" for v in r)


def parse_rect(v):
    try:
        return [float(t) for t in v.split()[:4]]
    except (AttributeError, ValueError):
        return None


# --- the merge -------------------------------------------------------------------------------------

class Merge:
    """Applies Diff(base, obs) to the current file `cur`, in place. `log` collects what was done."""

    def __init__(self, diff, cur, log):
        self.d, self.cur, self.log = diff, cur, log
        self.ck = keyed(cur)
        self.cnames = by_name(cur)
        self.placed = {}  # id(observer-added element) -> element now in cur
        self.conflicts = []
        self.rect_edited = set()  # ids of WoL's gadgets the observer copy moved

    def find(self, key):
        """The current gadget for a base key: the same chain, else the only gadget of that name."""
        el = self.ck.get(key)
        if el is not None:
            return el
        same = self.cnames.get(key[-2], [])
        base_same = [k for k in self.d.bk if k[-2] == key[-2]]
        if len(same) == 1 and len(base_same) == 1:
            return same[0]
        return None

    def run(self):
        self.inherit = self.inherited()
        self.apply_wrappers()   # before the edits: a container follows WoL's own moves, not the observer's
        self.apply_edits()
        self.apply_inserts()
        self.reorder_top()
        for el, attr, value in self.inherit:
            U.set_attr(el, attr, value)

    ART = ("background", "texturecoords", "clickthrufile", "clickthrucoords", "backgroundcolor")

    def inherited(self):
        """Art the observer copy moved from one of WoL's panels to its own container (the container then
        draws the panel's background, and the map can hide both): the container takes the panel's art
        as WoL draws it now. Returns [(container, attribute, WoL's current value)]."""
        out = []
        added_by_parent = {}
        for g in layout_root(self.d.obs).walk():
            if is_gadget(g) and id(g) in self.d.added:
                p = g.parent
                while is_gadget(p) and id(p) in self.d.added:
                    p = p.parent
                if is_gadget(p):
                    added_by_parent.setdefault(id(p), []).append(g)
        wrapped = {}
        for w, held in self.d.wrappers:
            for h in held:
                wrapped.setdefault(id(h), []).append(w)
        for key, attr, bval, oval in self.d.edits:
            if attr not in self.ART or not bval or oval:
                continue
            o = self.d.ok[key]
            cur = self.find(key)
            if cur is None:
                continue
            for g in added_by_parent.get(id(o), []) + wrapped.get(id(o), []):
                if g.get(attr) == bval:
                    out.append((g, attr, cur.attributes().get(attr)))
        return out

    def apply_edits(self):
        n = 0
        for key, attr, bval, oval in self.d.edits:
            el = self.find(key)
            if el is None:
                self.log.append(f"edit skipped, gadget gone from WoL's file: {'/'.join(key[:-1])} {attr}")
                continue
            cval = el.attributes().get(attr)
            if cval != bval:
                # WoL changed this attribute itself since the observer copy was made
                self.conflicts.append((key, attr, bval, oval, cval))
                if attr == "size1024" and oval is not None and bval is not None and cval is not None:
                    # the observer moved it and WoL moved it too: move WoL's rectangle by the observer's shift
                    ob, bb, cb = parse_rect(oval), parse_rect(bval), parse_rect(cval)
                    if ob and bb and cb:
                        new = [c + (o - b) for c, o, b in zip(cb, ob, bb)]
                        U.set_attr(el, attr, rect_text(new))
                        n += 1
                        continue
                # otherwise the observer's value wins (it is what the panel was laid out with)
            U.set_attr(el, attr, oval)
            if attr == "size1024":
                self.rect_edited.add(id(el))
            n += 1
        self.log.append(f"{n} attribute edits of the observer copy applied, {len(self.conflicts)} on attributes WoL changed too")

    def apply_wrappers(self):
        for wrapper, held in self.d.wrappers:
            targets = []
            for h in held:
                el = self.find(self.d.okey[id(h)])
                if el is None:
                    self.log.append(f"wrapper {wrapper.get('name')}: {h.get('name')} is gone from WoL's file")
                else:
                    targets.append((h, el))
            if not targets:
                continue
            first = targets[0][1]
            parent = first.parent
            obase = [c for c in kids(wrapper.parent) if id(c) not in self.d.added]
            if not obase and len(held) > 1:
                # the container holds the whole content of its panel: WoL's newer gadgets there go in too
                have = {id(el) for _, el in targets}
                extra = [c for c in kids(parent) if id(c) not in have]
                if extra:
                    self.log.append(f"wrapper {wrapper.get('name')}: also holds WoL's "
                                    + ", ".join(c.get("name") or "?" for c in extra))
                targets = [(None, c) for c in kids(parent)]
                first = targets[0][1]
            prev = [c for c in parent.children[:parent.children.index(first)] if isinstance(c, U.Element)]
            # a container that covers its panel exactly follows the panel where WoL moved it
            if is_gadget(wrapper.parent) and is_gadget(parent):
                pkey = self.d.okey.get(id(wrapper.parent))
                pbase = self.d.bk.get(pkey) if pkey else None
                wr = parse_rect(wrapper.get("size1024"))
                pb = parse_rect(pbase.get("size1024")) if pbase is not None else None
                pc = parse_rect(parent.get("size1024"))
                if wr and pb and pc and wr == pb and pc != pb:
                    U.set_attr(wrapper, "size1024", parent.get("size1024"))
                    self.log.append(f"wrapper {wrapper.get('name')} follows its panel, moved by WoL to {parent.get('size1024')}")
            # take the held gadgets out of the observer's wrapper and out of the current tree
            for h, el in targets:
                detach(el)
            for h in held:
                detach(h)
            detach(wrapper)
            put(parent, wrapper, prev[-1] if prev else None)
            last = None
            for h, el in targets:
                put(wrapper, el, last)
                last = el
            # observer-added gadgets inside the wrapper (none known) stay as they were
            self.placed[id(wrapper)] = wrapper
        self.log.append(f"{len(self.d.wrappers)} containers put around WoL's panels")

    def apply_inserts(self):
        n = 0
        for el in self.d.inserts:
            same = self.cnames.get(gname(el), [])
            if same and not kids(el):
                # WoL has since added a gadget of that name itself (the unit panel's health bars): WoL's is
                # kept, where the observer copy put its own, rather than a second gadget of the same name
                for c in same:
                    if el.get("size1024"):
                        U.set_attr(c, "size1024", el.get("size1024"))
                self.log.append(f"{el.get('name')}: WoL's own gadget kept, placed where the observer copy has it")
                continue
            pkey = self.d.pkey[id(el)]
            parent = layout_root(self.cur) if pkey == () else self.find(pkey)
            if parent is None:
                self.log.append(f"insert skipped, parent gone: {el.get('name')} in {'/'.join(pkey[:-1])}")
                continue
            # the nearest earlier sibling that is in the current tree
            after = None
            for prev in reversed(self.d.before[id(el)]):
                if id(prev) in self.placed:
                    if self.placed[id(prev)].parent is parent:
                        after = self.placed[id(prev)]
                        break
                    continue
                if id(prev) not in self.d.added:
                    cand = self.find(self.d.okey[id(prev)])
                    if cand is not None and cand.parent is parent:
                        after = cand
                        break
            detach(el)
            put(parent, el, after)
            self.placed[id(el)] = el
            n += 1
        self.log.append(f"{n} observer gadgets added")

    def reorder_top(self):
        """The observer copy draws some of WoL's top-level gadgets in another order (RecordGameCtrl,
        overlayWindow and messageWindow first, chatInput late): keep that order for them."""
        root = layout_root(self.cur)
        order = self.d.top_order
        rank = {}
        for i, g in enumerate(order):
            if id(g) in self.d.added:
                rank[id(self.placed.get(id(g), g))] = i
            else:
                el = self.find(self.d.okey[id(g)])
                if el is not None and el.parent is root:
                    rank[id(el)] = i
        top = kids(root)
        ranked = [g for g in top if id(g) in rank]
        want = sorted(ranked, key=lambda g: rank[id(g)])
        if [id(g) for g in ranked] == [id(g) for g in want]:
            return
        # WoL's own new gadgets keep their place after the gadget they follow in WoL's file
        seq, follow = [], {}
        last = None
        for g in top:
            if id(g) in rank:
                last = g
            else:
                follow.setdefault(id(last) if last is not None else None, []).append(g)
        seq += follow.get(None, [])
        for g in want:
            seq.append(g)
            seq += follow.get(id(g), [])
        for g in top:
            detach(g)
        prev = None
        for g in seq:
            put(root, g, prev)
            prev = g
        self.log.append("top-level order of the observer copy kept")


# --- observer-only rules ---------------------------------------------------------------------------

# WoL's minimized resource panels: the observer's own economy (empty) drawn under the panel's player rows
RESOURCE_PANELS = re.compile(r"^SettlerCountDialog", re.I)
RESOURCE_HIDER = "Spec_WoLResourcePanels"
# WoL's icon row (Menu > Icons) and building search row: moved below the observer's top band
ICON_ROW = ["extraButtonhelp", "extraButtonPower", "extraButtonPlaceUnits", "extraButtonLights",
            "extraButtonDebugger", "extraButtonfind", "extraButtonhero", "extraButtonScreenshot",
            "extraButtonBlackmap", "extraButtonFog", "minimapEventButton", "extraButtonPatrol",
            "cameraSaveModus2", "cameraLoadModus2", "showUnitButtons"]
ICON_ROW_TOP = 40  # where WoL puts the row (size1024 y)
# the home city button and its shipment counter: WoL moved them above the minimap, into the observer's
# options bar; the observer copy has them where the panel was laid out around them
HC_BUTTON = ["shipsDisplay", "uimain-homeCityToggle", "shipsDisplayBG", "shipsTimerBG", "shipsTimerFG"]
HC_BUTTON_MOVE = (-86, -39)  # the copy's 222..274 x 629..667 to 136..188 x 590..628 (the minimap starts at y 628)


def shift(el, dx, dy):
    for g in [el] + [c for c in el.walk() if is_gadget(c)]:
        r = parse_rect(g.get("size1024"))
        if r:
            U.set_attr(g, "size1024", rect_text([r[0] + dx, r[1] + dy, r[2] + dx, r[3] + dy]))


def first_named(doc, name):
    hits = U.find(doc, name)
    return hits[0] if hits else None


def hide_resource_panels(cur, log):
    root = layout_root(cur)
    panels = [g for g in kids(root) if RESOURCE_PANELS.match(g.get("name") or "")]
    if not panels:
        return
    rects = [parse_rect(g.get("size1024")) for g in panels if parse_rect(g.get("size1024"))]
    box = [min(r[0] for r in rects), min(r[1] for r in rects), max(r[2] for r in rects), max(r[3] for r in rects)]
    prev = [c for c in root.children[:root.children.index(panels[0])] if isinstance(c, U.Element)]
    holder = U.parse_text(f'<gadget name="{RESOURCE_HIDER}" type="gadget" hidden="" transparent="" '
                          f'size1024="{rect_text(box)}" z="1"></gadget>').children[0]
    for g in panels:
        detach(g)
    put(root, holder, prev[-1] if prev else None)
    last = None
    for g in panels:
        put(holder, g, last)
        last = g
    log.append(f"rule: WoL's {len(panels)} resource panels put in the hidden {RESOURCE_HIDER} "
               "(the observer's own economy, drawn under the player rows)")


def move_icon_rows(merge, cur, log):
    win = first_named(cur, "messageWindow")  # where the observer copy put it (after a retarget)
    band = parse_rect(win.get("size1024")) if win is not None else None
    if not band:
        return
    dy = band[3] + 4 - ICON_ROW_TOP
    if dy <= 0:
        return
    n = 0
    for name in ICON_ROW:
        for g in U.find(cur, name):
            if g.parent is layout_root(cur):
                shift(g, 0, dy)
                n += 1
    log.append(f"rule: WoL's icon and search rows ({n} gadgets) moved down {dy:g} below the observer's top band "
               f"(its population box ends at y {band[3]:g})")


def restore_hc_button(merge, cur, log):
    """The observer copy's button group (flag, shipment count, XP bar), moved as one to just above the
    minimap's top right corner, left of the panel's options toggle: in the copy's place, inside the player
    rows' top left corner, the first row covers it at 1280 x 720 and in 3v3 (seen in game)."""
    n = 0
    for name in HC_BUTTON:
        o, c = first_named(merge.d.obs, name), first_named(cur, name)
        r = parse_rect(o.get("size1024")) if o is not None else None
        if r and c is not None:
            dx, dy = HC_BUTTON_MOVE
            U.set_attr(c, "size1024", rect_text([r[0] + dx, r[1] + dy, r[2] + dx, r[3] + dy]))
            n += 1
    if n:
        log.append(f"rule: the home city button and its counter ({n} gadgets) above the minimap's top right corner")


def civ_flags(data):
    """[(civ ID as kbGetCiv() gives it, large flag button set)] from WoL's civs.xml: the ID is the civ's
    place in the file plus one (checked in game: the stock numbers 5 and 15 showed WoL's 4th and 14th
    civs' flags in round 1)."""
    raw = data.loose("civs.xml")
    text = raw.decode("utf-8", "replace") if raw is not None else data.from_bar("civs.xml")
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)  # 21 civs of WoL's file are commented out
    out = []
    for i, block in enumerate(re.findall(r"<civ>(.*?)</civ>", text, re.S | re.I)):
        m = re.search(r"<homecityflagbuttonsetlarge>\s*([^<\s]+)\s*<", block, re.I)
        if m:
            out.append((i + 1, m.group(1)))
    return out


def regenerate_flags(cur, flags, log):
    """The panel shows Spec_Flag_<column>_<kbGetCiv()>: ESOC wrote one per stock civ (and the stock
    revolutions by tech number), so WoL's civs showed another civ's flag or none. One per WoL civ."""
    pattern = re.compile(r"^Spec_Flag_(\d+)_(\d+)$", re.I)
    found = [g for g in layout_root(cur).walk() if is_gadget(g) and pattern.match(g.get("name") or "")]
    templates, old = {}, []
    for g in found:
        col, civ = pattern.match(g.get("name")).groups()
        if civ != "0":
            templates.setdefault(col, g)
            old.append(g)
    if not templates:
        return
    parent = old[0].parent
    anchor = [c for c in parent.children[:parent.children.index(old[0])] if isinstance(c, U.Element)]
    anchor = anchor[-1] if anchor else None
    texts = {col: g.text() for col, g in templates.items()}
    for g in old:
        detach(g)
    last = anchor
    for col in sorted(texts, key=int):
        for civ, buttons in flags:
            t = re.sub(r'name="Spec_Flag_\d+_\d+"', f'name="Spec_Flag_{col}_{civ}"', texts[col], count=1)
            t = re.sub(r'usebuttonset="[^"]*"', f'usebuttonset="{buttons}"', t, count=1)
            el = U.parse_text(t).children[0]
            put(parent, el, last)
            last = el
    log.append(f"rule: flags: {len(old)} stock-numbered Spec_Flag gadgets replaced by {len(flags) * len(texts)} "
               f"({len(flags)} WoL civs x {len(texts)} columns, named by kbGetCiv())")


def park_new_unit_panel_texts(merge, cur, log):
    """ESOC laid the unit panel out again, smaller, at the right (where the command panel was), with its
    own speed and garrison row (unitselectionpanelAdvanced). WoL's later texts in that panel (LOS, Train
    Points, Speed, Garrison and two empty ones) are placed for WoL's centre panel and would be drawn over
    the observer's player rows: they are moved out of the screen, as the observer copy hides gadgets
    (x + 1000), and hidden."""
    base, obs = merge.d.base_names, merge.d.obs_names
    moved = []
    for g in layout_root(cur).walk():
        if is_gadget(g) and gname(g) not in base and gname(g) not in obs:
            r = parse_rect(g.get("size1024"))
            if r:
                U.set_attr(g, "size1024", rect_text([r[0] + 1000, r[1], r[2] + 1000, r[3]]))
            U.set_attr(g, "hidden", "")
            moved.append(g.get("name"))
    if moved:
        log.append(f"rule: WoL's {len(moved)} later unit panel texts moved out of sight ({', '.join(sorted(set(moved)))}); "
                   "the observer's panel shows speed and garrison in its own row")


def observer_rules(merge, data, normal, res, log):
    """The changes the observer needs beyond the copy's own: see README.md, "The rebuilt files"."""
    cur = merge.cur
    if normal == MAIN:
        hide_resource_panels(cur, log)
        move_icon_rows(merge, cur, log)
        regenerate_flags(cur, data.flags, log)
    elif normal == "uiminimappanelnewmin":
        restore_hc_button(merge, cur, log)
    elif normal == "uiunitselectionmin":
        park_new_unit_panel_texts(merge, cur, log)


# --- resolutions WoL's DLL does not know yet ---------------------------------------------------------

# new resolution -> the existing layout it is made from (the widest one not wider). The map then runs
# that layout's loadWxH() preset (the layout keeps its Spec_PresetConfig gadget), so the map needs no
# new code. Used only if WoL's DLL adds the resolution to its list.
NEW_RES = {"1440x900": "1366x768", "1600x1200": "1600x900", "1920x1200": "1920x1080",
           "2560x1080": "1920x1080", "2560x1440": "1920x1080", "3440x1440": "1920x1080",
           "3840x2160": "1920x1080"}
ZONE_X = {0, 214, 810, 1024}  # the panel's columns in 1024 units: minimap | player rows | unit panel
# the subtitle canvases the panel writes its text into: the shipment counters under the flags first, then
# numLFs empty lines of "Graphicz 32", then the icons of the player rows. Kept at the top, so a resolution
# of another height needs its own numLFs (the preset): see NEW_PRESETS.
TOP_CANVASES = {"subtitlename", "widesubtitlename"}


def wh(res):
    w, h = res.lower().split("x")
    return int(w), int(h)


def retarget(merge, cur, src, dst, log):
    """The ESOC panel is laid out in pixels: its icons are 49 px cells written into text, its fonts are
    pixel sizes, its loadWxH() presets are pixel offsets. So at a new resolution each of its gadgets keeps
    its size in pixels and its place relative to the screen's centre (x) and to the top or bottom edge
    (y: the half of the screen it is in), and the 1024-unit numbers are worked out again. WoL's own
    panels stay in 1024 units (the game stretches them), and so do the panel's wood backgrounds, which
    span the columns between the minimap and the unit panel (ZONE_X), and the gadgets inside the minimap
    or the unit panel column."""
    (ws, hs), (wd, hd) = wh(src), wh(dst)
    dx = (wd - ws) / 2
    added = set()
    for el in merge.placed.values():
        added.add(id(el))
        added |= {id(g) for g in el.walk() if is_gadget(g)}
    n = kept = 0
    for g in list(layout_root(cur).walk()):
        if not is_gadget(g) or (id(g) not in added and id(g) not in merge.rect_edited):
            continue
        r = parse_rect(g.get("size1024"))
        if not r:
            continue
        x1, y1, x2, y2 = r
        if kids(g) and x1 <= 0 and x2 >= 1024 and y1 <= 0 and y2 >= 768:
            continue  # a full-screen container: its children are placed one by one
        px = [x1 * ws / 1024, y1 * hs / 768, x2 * ws / 1024, y2 * hs / 768]
        bottom = (px[1] + px[3]) / 2 >= hs / 2
        if gname(g) in TOP_CANVASES:
            bottom = False
        if bottom and x1 >= 810:
            kept += 1
            continue  # over the unit panel column: stretched with it
        dy = (hd - hs) if bottom else 0
        if x1 in ZONE_X and x2 in ZONE_X:
            nx1, nx2 = x1, x2  # a background over whole columns: stays stretched over them
        else:
            nx1, nx2 = (px[0] + dx) * 1024 / wd, (px[2] + dx) * 1024 / wd
        ny1, ny2 = (px[1] + dy) * 768 / hd, (px[3] + dy) * 768 / hd
        U.set_attr(g, "size1024", " ".join(str(round(v)) for v in (nx1, ny1, nx2, ny2)))
        n += 1
    log.append(f"retarget {src} -> {dst}: {n} panel gadgets keep their pixel size (centre-anchored, "
               f"top or bottom), {kept} over the unit panel column stay stretched; preset "
               f"Spec_PresetConfig-{src}-1 kept, so the map runs load{src}()")


# --- build ------------------------------------------------------------------------------------------

def merge_one(data, normal, obs_name, res, log, retarget_to=None):
    base = data.base(normal + ".xml")
    obs = data.observer(obs_name)
    cur, where = data.current(normal + ".xml")
    diff = Diff(base, obs)
    log.append(f"{obs_name}: base Data3.bar {normal}.xml, current {where}; "
               f"{len(diff.added)} observer gadgets, {len(diff.edits)} edits, {len(diff.wrappers)} containers")
    if diff.missing:
        log.append(f"  base gadgets the observer copy lacks: {len(diff.missing)} "
                   f"(e.g. {', '.join('/'.join(k[:-1]) for k in diff.missing[:5])})")
    m = Merge(diff, cur, log)
    m.run()
    for key, attr, bval, oval, cval in m.conflicts:
        log.append(f"  WoL changed it too: {'/'.join(key[:-1])} {attr}: base {bval!r}, observer {oval!r}, WoL {cval!r}")
    if retarget_to:
        retarget(m, cur, res, retarget_to, log)
    observer_rules(m, data, normal, retarget_to or res, log)
    return cur


def write_doc(doc, path):
    data = doc.data()
    path.write_bytes(data)
    return hashlib.sha256(data).hexdigest()[:8]


def build(wol, out, resolutions, report):
    data = Data(wol)
    data.flags = civ_flags(data)
    out.mkdir(parents=True, exist_ok=True)
    log = []
    for res in resolutions:
        src = res if res in RESOLUTIONS else NEW_RES.get(res)
        if not src:
            sys.exit(f"observer_ui: {res}: neither one of WoL's {len(RESOLUTIONS)} nor in NEW_RES")
        for jp in ("", "jp"):
            name = f"uimainnewobserver{res}{jp}.xml"
            doc = merge_one(data, MAIN, f"uimainnewobserver{src}{jp}.xml", src, log,
                            retarget_to=None if src == res else res)
            log.append(f"  -> {name} {write_doc(doc, out / name)}")
    for p in PANELS:
        for jp in ("", "jp"):
            name = f"{p}observer{jp}.xml"
            doc = merge_one(data, p, name, None, log)
            log.append(f"  -> {name} {write_doc(doc, out / name)}")
    text = "\n".join(log) + "\n"
    if report:
        pathlib.Path(report).write_text(text, encoding="utf-8")
    print(text)


# --- the gadgets the maps' panel code asks for ---------------------------------------------------------

# names the panel code tests that no observer file ever had (WoL's nor ESOC's): option switches that are
# off when their gadget is missing, and the other layout family ("m8ihazui2" without "-1")
OPTIONAL = {"specenablemusic-1": "music option, off (the file has SpecEnableMusic-0)",
            "specenableunitticker-1": "unit ticker option, off (SpecEnableUnitTicker-0)",
            "m8ihazui2": "the other layout family; these files are m8ihazui2-1",
            "specenableotherlocale-1": "other-locale option (the jp files have it on)",
            "specmutefindunitsounds-1": "mute option, off (SpecMuteFindUnitSounds-0 in the jp files)",
            "player status": "a stock dialog name, only in the console command hcmd2",
            "rtdb-": "prefix of an optional row family, absent in every observer file",
            "specCustomConfig-".lower(): "custom display configs, absent in every observer file"}

GADGET_CALL = re.compile(r'(gadgetReal|gadgetUnreal|gadgetToggle|trIsGadgetVisible)\(\\"([^"\\]*)\\"(\s*\+)?', re.I)


def map_gadgets(xs_path):
    """(static names, dynamic prefixes) the trigger code of a map shows, hides or tests: the text of
    its cEf lines (the pieces of a split literal joined), comments left out."""
    static, prefixes = set(), set()
    for line in pathlib.Path(xs_path).read_text(encoding="latin-1").splitlines():
        if line.lstrip().startswith("//"):
            continue
        line = line.replace('","', "")
        for m in GADGET_CALL.finditer(line):
            (prefixes if m.group(3) else static).add(m.group(2))
    return static, prefixes


def gadget_check(xs_path, built, resolutions):
    static, prefixes = map_gadgets(xs_path)
    print(f"{pathlib.Path(xs_path).name}: {len(static)} gadget names and {len(prefixes)} name prefixes in its trigger code")
    bad = 0
    for res in resolutions:
        names = set()
        files = [built / f"uimainnewobserver{res}.xml"] + [built / f"{p}observer.xml" for p in PANELS]
        for f in files:
            if not f.exists():
                sys.exit(f"observer_ui: {f} is missing")
            names |= {gname(g) for g in U.parse(f.read_bytes()).gadgets()}
        presets = [n for n in static if n.lower().startswith("spec_presetconfig-")]
        # each layout carries the preset gadget of its own resolution only; the map tests them all
        missing = sorted(n for n in static if n.lower() not in names and n not in presets and n.lower() not in OPTIONAL)
        nopre = sorted(p for p in prefixes
                       if not any(n.startswith(p.lower()) for n in names) and p.lower() not in OPTIONAL)
        own = [n for n in names if n.startswith("spec_presetconfig-")]
        line = f"  {res}: {len(names)} gadgets; preset gadget {', '.join(own) or 'NONE'}"
        if own and not any(o == p.lower() for o in own for p in presets):
            line += " (the map has no loadWxH() for it: see NEW_RES)"
        if missing:
            line += f"; missing: {', '.join(missing)}"
        if nopre:
            line += f"; no gadget for prefix: {', '.join(nopre)}"
        print(line)
        bad += bool(missing or nopre)
    return bad


# --- install -----------------------------------------------------------------------------------------

def apply(wol, src):
    data = pathlib.Path(wol) / "data"
    added_list = data / ADDED_LIST
    added = set(added_list.read_text(encoding="utf-8").split()) if added_list.exists() else set()
    n = 0
    for f in sorted(pathlib.Path(src).glob("*.xml")):
        target = data / f.name
        orig = data / (f.name + ".obs-orig")
        if target.exists() and not orig.exists() and f.name not in added:
            orig.write_bytes(target.read_bytes())
        elif not target.exists():
            added.add(f.name)
        target.write_bytes(f.read_bytes())
        n += 1
    if added:
        added_list.write_text("\n".join(sorted(added)) + "\n", encoding="utf-8")
    print(f"observer_ui: {n} files installed in {data} (replaced ones kept as *.obs-orig, "
          f"{len(added)} new ones listed in {ADDED_LIST})")


def revert(wol):
    data = pathlib.Path(wol) / "data"
    n = 0
    for orig in sorted(data.glob("*.obs-orig")):
        if orig.name.endswith(".xs.obs-orig"):
            continue
        target = data / orig.name[:-len(".obs-orig")]
        target.write_bytes(orig.read_bytes())
        orig.unlink()
        n += 1
    added_list = data / ADDED_LIST
    k = 0
    if added_list.exists():
        for name in added_list.read_text(encoding="utf-8").split():
            (data / name).unlink(missing_ok=True)
            k += 1
        added_list.unlink()
    print(f"observer_ui: {n} files restored, {k} added files removed")


def check(wol, src):
    data = pathlib.Path(wol) / "data"
    origs = sorted(p.name for p in data.glob("*.obs-orig") if not p.name.endswith(".xs.obs-orig"))
    added_list = data / ADDED_LIST
    added = added_list.read_text(encoding="utf-8").split() if added_list.exists() else []
    print(f"observer_ui: {len(origs)} WoL files replaced (kept as *.obs-orig), {len(added)} added")
    if src:
        bad = 0
        for f in sorted(pathlib.Path(src).glob("*.xml")):
            t = data / f.name
            if not t.exists() or t.read_bytes() != f.read_bytes():
                print(f"  differs: {f.name}")
                bad += 1
        print("  data\\ holds the built files" if not bad else f"  {bad} files differ from {src}")


def main(argv):
    if len(argv) < 2 or argv[0] not in ("build", "apply", "check", "revert", "gadgets"):
        sys.exit(__doc__)
    if argv[0] == "gadgets":
        res = argv[argv.index("--res") + 1].split(",") if "--res" in argv else RESOLUTIONS
        built = pathlib.Path(argv[argv.index("--from") + 1])
        sys.exit(1 if gadget_check(argv[1], built, res) else 0)
    cmd, wol = argv[0], pathlib.Path(argv[1])

    def arg(name, default=None):
        return argv[argv.index(name) + 1] if name in argv else default
    if "steamapps" in str(wol.resolve()).lower() and cmd in ("apply", "revert"):
        sys.exit("observer_ui: refused: a Steam folder; install into a copy, or by hand")
    if cmd == "build":
        out = arg("--out") or sys.exit("build needs --out <folder>")
        res = arg("--res")
        build(wol, pathlib.Path(out), res.split(",") if res else RESOLUTIONS + list(NEW_RES), arg("--report"))
    elif cmd == "apply":
        apply(wol, arg("--from") or sys.exit("apply needs --from <folder>"))
    elif cmd == "revert":
        revert(wol)
    else:
        check(wol, arg("--from"))


if __name__ == "__main__":
    main(sys.argv[1:])
