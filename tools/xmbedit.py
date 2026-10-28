"""Legacy AoE3 compiled XML (.xmb: l33t + zlib, X1/XR version 8): round trip and unittype edits.

Usage: python -I tools/xmbedit.py <in.xmb> <out.xmb> [unitName unitType]...
With no edits it only checks that decode + encode reproduces the inner XMB exactly. Each
pair appends <unittype>unitType</unittype> to the proto named unitName (protoy.xml.XMB).
"""
import struct
import sys
import zlib


class Node:
    __slots__ = ("text", "name", "line", "attrs", "children")


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0], o + 4


def wstr(b, o):
    n, o = u32(b, o)
    return b[o:o + 2 * n].decode("utf-16-le"), o + 2 * n


def decode(raw):
    assert raw[:4] == b"l33t"
    size = struct.unpack_from("<I", raw, 4)[0]
    inner = zlib.decompress(raw[8:])
    assert len(inner) == size
    return inner


def parse(x):
    assert x[:2] == b"X1"
    total, o = u32(x, 2)
    assert x[o:o + 2] == b"XR"
    o += 2
    ident, o = u32(x, o)
    ver, o = u32(x, o)
    assert (ident, ver) == (4, 8), (ident, ver)
    n, o = u32(x, o)
    elems = []
    for _ in range(n):
        s, o = wstr(x, o)
        elems.append(s)
    n, o = u32(x, o)
    attrs = []
    for _ in range(n):
        s, o = wstr(x, o)
        attrs.append(s)

    def node(o):
        assert x[o:o + 2] == b"XN", hex(o)
        length, o = u32(x, o + 2)
        end = o + length
        nd = Node()
        nd.text, o = wstr(x, o)
        nd.name, o = u32(x, o)
        nd.line, o = u32(x, o)
        n, o = u32(x, o)
        nd.attrs = []
        for _ in range(n):
            k, o = u32(x, o)
            v, o = wstr(x, o)
            nd.attrs.append((k, v))
        n, o = u32(x, o)
        nd.children = []
        for _ in range(n):
            c, o = node(o)
            nd.children.append(c)
        assert o == end, (hex(o), hex(end))
        return nd, o

    root, o = node(o)
    assert o == len(x) and total == len(x) - 6
    return elems, attrs, root


def enc_w(s):
    return struct.pack("<I", len(s)) + s.encode("utf-16-le")


def encode(elems, attrs, root):
    def node(nd):
        body = enc_w(nd.text) + struct.pack("<II", nd.name, nd.line)
        body += struct.pack("<I", len(nd.attrs))
        for k, v in nd.attrs:
            body += struct.pack("<I", k) + enc_w(v)
        body += struct.pack("<I", len(nd.children))
        body += b"".join(node(c) for c in nd.children)
        return b"XN" + struct.pack("<I", len(body)) + body

    head = b"XR" + struct.pack("<II", 4, 8)
    head += struct.pack("<I", len(elems)) + b"".join(enc_w(s) for s in elems)
    head += struct.pack("<I", len(attrs)) + b"".join(enc_w(s) for s in attrs)
    body = head + node(root)
    return b"X1" + struct.pack("<I", len(body)) + body


def main():
    src, dst = sys.argv[1], sys.argv[2]
    edits = list(zip(sys.argv[3::2], sys.argv[4::2]))
    inner = decode(open(src, "rb").read())
    elems, attrs, root = parse(inner)
    assert encode(elems, attrs, root) == inner, "round trip differs"
    print(f"round trip ok: {len(inner)} B, {len(elems)} element names, {len(attrs)} attribute names")
    if not edits:
        return
    unit_e, type_e = elems.index("unit"), elems.index("unittype")
    name_a = attrs.index("name")
    wanted = dict(edits)
    done = []
    for unit in root.children:
        if unit.name != unit_e:
            continue
        name = next((v for k, v in unit.attrs if k == name_a), None)
        if name not in wanted:
            continue
        types = [c for c in unit.children if c.name == type_e]
        if any(c.text == wanted[name] for c in types):
            continue
        last = types[-1] if types else unit.children[-1]
        add = Node()
        add.text, add.name, add.line, add.attrs, add.children = wanted[name], type_e, last.line, [], []
        unit.children.insert(unit.children.index(last) + 1, add)
        done.append(name)
    out = encode(elems, attrs, root)
    open(dst, "wb").write(b"l33t" + struct.pack("<I", len(out)) + zlib.compress(out, 9))
    print("added to:", done, "->", dst, len(out), "B inner")


if __name__ == "__main__":
    main()
