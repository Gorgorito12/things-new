"""Read and edit legacy AoE3 compiled XML (.xmb), e.g. data\\protoy.xml.XMB.

Usage:
    python -I tools/xmbedit.py check <file.xmb>
    python -I tools/xmbedit.py to-xml <file.xmb> <out.xml>
    python -I tools/xmbedit.py add-unittype <in.xmb> <out.xmb> <Unit> <UnitType> [<Unit> <UnitType> ...]

check         decodes and re-encodes the file and confirms the result is byte-identical, so an
              edit cannot change anything else.
to-xml        writes a readable XML copy (element names as stored, which is lowercase). Use it
              to read files extracted from the BAR archives with tools/bar.py.
add-unittype  adds <unittype>UnitType</unittype> after the last unittype of each named
              <unit name='Unit'> (a protoy XMB). It reports units that are missing or already
              have the type. The output keeps the input's compression.

Format (legacy TAD, as read from the stock files):
    optional "l33t" + uint32 inflated size + zlib stream, then
    "X1" uint32 size, "XR" uint32 4, uint32 8 (version),
    uint32 n + n UTF-16 element names, uint32 n + n UTF-16 attribute names, root node.
    node: "XN" uint32 size, UTF-16 text, uint32 element index, uint32 source line,
          uint32 n + n (uint32 attribute index, UTF-16 value), uint32 n + n child nodes.
    UTF-16 strings are uint32 length (in characters) + characters, no terminator.
"""
import struct
import sys
import zlib
from xml.sax.saxutils import escape, quoteattr


class Node:
    __slots__ = ("text", "name", "line", "attrs", "children")


def is_compressed(raw):
    return raw[:4] == b"l33t"


def decode(raw):
    """Returns the inner X1 document of a compressed or uncompressed .xmb file."""
    if is_compressed(raw):
        size = struct.unpack_from("<I", raw, 4)[0]
        inner = zlib.decompress(raw[8:])
        if len(inner) != size:
            raise ValueError(f"inflated {len(inner)} bytes, header says {size}")
        return inner
    if raw[:2] != b"X1":
        raise ValueError(f"not an XMB file (starts with {raw[:4]!r})")
    return raw


def parse(x):
    """Returns (element names, attribute names, root node) of an X1 document."""
    pos = 0

    def u32():
        nonlocal pos
        value = struct.unpack_from("<I", x, pos)[0]
        pos += 4
        return value

    def wstr():
        nonlocal pos
        n = u32()
        text = x[pos:pos + 2 * n].decode("utf-16-le")
        pos += 2 * n
        return text

    def expect(tag):
        nonlocal pos
        if x[pos:pos + 2] != tag:
            raise ValueError(f"expected {tag!r} at {pos:#x}")
        pos += 2

    expect(b"X1")
    total = u32()
    expect(b"XR")
    if (u32(), u32()) != (4, 8):
        raise ValueError("unsupported XMB version (expected XR 4, 8)")
    elems = [wstr() for _ in range(u32())]
    attrs = [wstr() for _ in range(u32())]

    def node():
        expect(b"XN")
        end = u32()
        end += pos
        nd = Node()
        nd.text = wstr()
        nd.name = u32()
        nd.line = u32()
        nd.attrs = [(u32(), wstr()) for _ in range(u32())]
        nd.children = [node() for _ in range(u32())]
        if pos != end:
            raise ValueError(f"node size mismatch at {pos:#x}")
        return nd

    root = node()
    if pos != len(x) or total != len(x) - 6:
        raise ValueError("trailing data or bad document size")
    return elems, attrs, root


def _wstr(s):
    return struct.pack("<I", len(s)) + s.encode("utf-16-le")


def encode(elems, attrs, root):
    def node(nd):
        body = _wstr(nd.text) + struct.pack("<II", nd.name, nd.line)
        body += struct.pack("<I", len(nd.attrs))
        body += b"".join(struct.pack("<I", k) + _wstr(v) for k, v in nd.attrs)
        body += struct.pack("<I", len(nd.children))
        body += b"".join(node(c) for c in nd.children)
        return b"XN" + struct.pack("<I", len(body)) + body

    body = b"XR" + struct.pack("<II", 4, 8)
    body += struct.pack("<I", len(elems)) + b"".join(_wstr(s) for s in elems)
    body += struct.pack("<I", len(attrs)) + b"".join(_wstr(s) for s in attrs)
    body += node(root)
    return b"X1" + struct.pack("<I", len(body)) + body


def wrap(inner, compressed):
    return b"l33t" + struct.pack("<I", len(inner)) + zlib.compress(inner, 9) if compressed else inner


def load_checked(path):
    raw = open(path, "rb").read()
    inner = decode(raw)
    elems, attrs, root = parse(inner)
    if encode(elems, attrs, root) != inner:
        raise ValueError(f"{path}: re-encoding does not reproduce the file; refusing to edit it")
    return raw, inner, elems, attrs, root


def to_xml(elems, attrs, root):
    lines = ['<?xml version="1.0" encoding="utf-8"?>']

    def node(nd, depth):
        pad = "  " * depth
        tag = elems[nd.name]
        attr_text = "".join(f" {attrs[k]}={quoteattr(v)}" for k, v in nd.attrs)
        text = escape(nd.text.strip())
        if not nd.children:
            lines.append(f"{pad}<{tag}{attr_text}>{text}</{tag}>" if text else f"{pad}<{tag}{attr_text}/>")
            return
        lines.append(f"{pad}<{tag}{attr_text}>{text}")
        for child in nd.children:
            node(child, depth + 1)
        lines.append(f"{pad}</{tag}>")

    node(root, 0)
    return "\n".join(lines) + "\n"


def add_unittypes(elems, attrs, root, pairs):
    """pairs: [(unit name, unittype)]. Returns (added, already, missing) unit name lists."""
    if "unit" not in elems or "unittype" not in elems or "name" not in attrs:
        raise ValueError("this file has no <unit name=...> / <unittype> elements (not a protoy XMB?)")
    unit_e, type_e, name_a = elems.index("unit"), elems.index("unittype"), attrs.index("name")
    wanted = {}
    for unit, utype in pairs:
        wanted.setdefault(unit, []).append(utype)
    added, already, found = [], [], set()
    for unit in root.children:
        if unit.name != unit_e:
            continue
        name = next((v for k, v in unit.attrs if k == name_a), None)
        if name not in wanted:
            continue
        found.add(name)
        for utype in wanted[name]:
            types = [c for c in unit.children if c.name == type_e]
            if any(c.text == utype for c in types):
                already.append(f"{name}:{utype}")
                continue
            last = types[-1] if types else (unit.children[-1] if unit.children else None)
            new = Node()
            new.text, new.name, new.attrs, new.children = utype, type_e, [], []
            new.line = last.line if last else unit.line
            unit.children.insert(unit.children.index(last) + 1 if last else 0, new)
            added.append(f"{name}:{utype}")
    missing = [u for u in wanted if u not in found]
    return added, already, missing


def main(argv):
    if not argv or argv[0] not in ("check", "to-xml", "add-unittype"):
        sys.exit(__doc__)
    command, args = argv[0], argv[1:]
    if command == "check" and len(args) == 1:
        raw, inner, elems, attrs, _ = load_checked(args[0])
        kind = "compressed" if is_compressed(raw) else "uncompressed"
        print(f"{args[0]}: round trip ok ({kind}, {len(inner)} bytes, {len(elems)} element names, "
              f"{len(attrs)} attribute names)")
    elif command == "to-xml" and len(args) == 2:
        _, _, elems, attrs, root = load_checked(args[0])
        with open(args[1], "w", encoding="utf-8") as f:
            f.write(to_xml(elems, attrs, root))
        print(f"wrote {args[1]}")
    elif command == "add-unittype" and len(args) >= 4 and len(args) % 2 == 0:
        raw, _, elems, attrs, root = load_checked(args[0])
        added, already, missing = add_unittypes(elems, attrs, root, list(zip(args[2::2], args[3::2])))
        with open(args[1], "wb") as f:
            f.write(wrap(encode(elems, attrs, root), is_compressed(raw)))
        print(f"added: {added or 'nothing'}")
        if already:
            print(f"already present: {already}")
        if missing:
            print(f"WARNING: no <unit> with these names: {missing}")
        print(f"wrote {args[1]}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
