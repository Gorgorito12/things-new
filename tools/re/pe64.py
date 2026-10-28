"""Static helpers for a 64-bit Windows executable (PE32+) too large to import comfortably into a
full disassembler, such as AoE3 DE's AoE3DE_s.exe (docs/de-architecture.md). Everything is read
from the file: nothing is executed, and nothing is written next to it.

Usage: python -I tools/re/pe64.py <exe> <command> [arguments]

  info                      sections, function count and imported DLLs
  imports [REGEX]           imported functions with their IAT RVAs
  strings REGEX             ASCII and UTF-16 strings that match REGEX, with their RVAs
  xrefs RVA|re:REGEX        code that uses RVA through a RIP-relative operand (lea, mov, cmp,
                            call [..], ...), with the containing function. re:REGEX does it for
                            every string that matches.
  func RVA [--max N]        the function that contains RVA: its chunks, the strings, imports and
                            functions it references, and (with capstone) a listing of N lines
  callers RVA               direct calls and jumps (E8/E9 rel32) to the function at RVA
  threads                   calls to thread, fiber and thread-pool creation imports, with the
                            procedure a nearby `lea` passes in the matching argument register

RVAs are hexadecimal (the 0x prefix is optional). Function bounds come from the exception
directory (.pdata). Chunks with chained unwind info are folded into their primary function.
The E8/E9 index is cached in --cache DIR, by default rea/evidence/<exe>-<sha8>/ in this repository.

`func` listings, and the confirmation of xref candidates, need capstone (pip install capstone;
docs/developer-guide.md describes the evidence venv). Without it, xrefs come from the byte-pattern
scan alone and are marked "unconfirmed".
"""
import argparse
import array
import bisect
import hashlib
import os
import re
import struct
import sys

try:
    import capstone
except ImportError:  # optional
    capstone = None

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# RIP-relative operand: optional legacy prefix, optional REX, an opcode that takes ModRM, then a
# ModRM byte with mod=00, rm=101 (any reg). The disp32 follows; some opcodes add an immediate.
# VEX-encoded (AVX) forms are matched by their C5/C4 prefix with any opcode; MSVC uses them, for
# instance, to copy short constant strings. Candidates are confirmed with capstone when available.
RIP_FORM = re.compile(
    rb"(?:[\x66\xF2\xF3]?[\x40-\x4F]?"
    rb"(\x8D|\x8B|\x89|\x3B|\x39|\x63|\x83|\x80|\x81|\xC7|\xC6|\xFF|\x88|\x8A|\x38|\x3A|\x85|\x84|"
    rb"\x0F[\x10\x11\x28\x29\xB6\xB7\xBE\xBF\x2E\x2F\x54\x57\x58\x59\x5C\x5E\x6F\x7F\x18\x0D])"
    rb"|\xC5[\x00-\xFF][\x00-\xFF]|\xC4[\x00-\xFF][\x00-\xFF][\x00-\xFF])"
    rb"[\x05\x0D\x15\x1D\x25\x2D\x35\x3D]", re.S)
IMMEDIATE = {0x80: 1, 0x83: 1, 0xC6: 1, 0x81: 4, 0xC7: 4}
# Creation imports and the argument register (x64 calling convention) that carries the procedure.
CREATORS = {
    "CreateThread": "r8", "CreateRemoteThread": "r9", "CreateRemoteThreadEx": "r9",
    "CreateFiber": "rdx", "CreateFiberEx": "r9", "CreateThreadpoolWork": "rcx",
    "CreateThreadpoolTimer": "rcx", "CreateThreadpoolWait": "rcx", "CreateThreadpoolIo": "rdx",
    "TrySubmitThreadpoolCallback": "rcx", "QueueUserWorkItem": "rcx",
    "RegisterWaitForSingleObject": "r8", "CreateTimerQueueTimer": "r8",
}
LEA_REG = {b"\x48\x8D\x0D": "rcx", b"\x48\x8D\x15": "rdx", b"\x4C\x8D\x05": "r8", b"\x4C\x8D\x0D": "r9"}


class PE64:
    def __init__(self, path):
        self.path = path
        with open(path, "rb") as f:
            self.data = f.read()
        d = self.data
        nt = struct.unpack_from("<I", d, 0x3C)[0]
        if d[nt:nt + 4] != b"PE\0\0":
            sys.exit("not a PE file")
        sections, optional_size = struct.unpack_from("<H", d, nt + 6)[0], struct.unpack_from("<H", d, nt + 20)[0]
        opt = nt + 24
        if struct.unpack_from("<H", d, opt)[0] != 0x20B:
            sys.exit("not a PE32+ (64-bit) image")
        self.image_base = struct.unpack_from("<Q", d, opt + 24)[0]
        self.dirs = [struct.unpack_from("<II", d, opt + 112 + 8 * i) for i in range(16)]
        self.sections = []
        for i in range(sections):
            h = opt + optional_size + 40 * i
            vsize, va, raw_size, raw_offset = struct.unpack_from("<IIII", d, h + 8)
            self.sections.append((d[h:h + 8].rstrip(b"\0").decode(errors="replace"), va, vsize, raw_offset,
                                  raw_size, struct.unpack_from("<I", d, h + 36)[0]))
        text = next(s for s in self.sections if s[5] & 0x20000000)
        self.text_va, self.text_off, self.text_size = text[1], text[3], min(text[2], text[4])
        self._functions = self._imports = None

    def rva_to_off(self, rva):
        for _, va, vsize, raw_offset, raw_size, _ in self.sections:
            if va <= rva < va + max(vsize, raw_size):
                return rva - va + raw_offset if rva - va < raw_size else None
        return None

    def section_of(self, rva):
        return next((s[0] for s in self.sections if s[1] <= rva < s[1] + max(s[2], s[4])), None)

    def cstring(self, rva, limit=200):
        """The ASCII or UTF-16 string at rva, or None."""
        off = self.rva_to_off(rva)
        if off is None:
            return None
        chunk = self.data[off:off + 2 * limit]
        if len(chunk) > 3 and chunk[1] == 0 and 0x20 <= chunk[0] < 0x7F and chunk[3] == 0:
            m = re.match(rb"((?:[\x20-\x7e]\x00)+)\x00\x00", chunk)
            return m.group(1).decode("utf-16le") if m and len(m.group(1)) >= 6 else None
        m = re.match(rb"([\x20-\x7e\t\r\n]+)\x00", chunk)
        return m.group(1).decode() if m and len(m.group(1)) >= 4 else None

    # --- functions (.pdata) ---------------------------------------------------------------
    def functions(self):
        if self._functions is None:
            rva, size = self.dirs[3]
            off = self.rva_to_off(rva)
            entries = sorted(struct.unpack_from("<III", self.data, off + 12 * i) for i in range(size // 12))
            begins, ends, primary = array.array("I"), array.array("I"), array.array("I")
            for begin, end, unwind in entries:
                begins.append(begin)
                ends.append(end)
                primary.append(self._primary(begin, unwind))
            self._functions = (begins, ends, primary)
        return self._functions

    def _primary(self, begin, unwind, depth=0):
        """Follows chained unwind info (UNW_FLAG_CHAININFO) to the function's primary entry."""
        if unwind & 1:  # indirect: the RVA of another RUNTIME_FUNCTION
            off = self.rva_to_off(unwind & ~1)
            return struct.unpack_from("<I", self.data, off)[0] if off is not None else begin
        off = self.rva_to_off(unwind)
        if off is None or depth > 32:
            return begin
        if (self.data[off] >> 3) & 0x4:
            codes = (self.data[off + 2] + 1) & ~1
            parent, _, parent_unwind = struct.unpack_from("<III", self.data, off + 4 + 2 * codes)
            return self._primary(parent, parent_unwind, depth + 1)
        return begin

    def function_of(self, rva):
        """(chunk begin, chunk end, primary entry) of the code at rva, or None."""
        begins, ends, primary = self.functions()
        k = bisect.bisect_right(begins, rva) - 1
        return (begins[k], ends[k], primary[k]) if k >= 0 and rva < ends[k] else None

    def chunks(self, entry):
        begins, ends, primary = self.functions()
        return [(begins[i], ends[i]) for i in range(len(begins)) if primary[i] == entry]

    def is_entry(self, rva):
        begins, _, primary = self.functions()
        k = bisect.bisect_left(begins, rva)
        return k < len(begins) and begins[k] == rva and primary[k] == rva

    # --- imports ----------------------------------------------------------------------------
    def imports(self):
        """IAT slot RVA -> 'dll!name'."""
        if self._imports is None:
            self._imports = {}
            rva, _ = self.dirs[1]
            off = self.rva_to_off(rva)
            while off is not None:
                lookup, _, _, name_rva, iat = struct.unpack_from("<IIIII", self.data, off)
                if name_rva == 0:
                    break
                dll = self.cstring(name_rva) or "?"
                table = self.rva_to_off(lookup or iat)
                i = 0
                while True:
                    thunk = struct.unpack_from("<Q", self.data, table + 8 * i)[0]
                    if thunk == 0:
                        break
                    name = f"#{thunk & 0xFFFF}" if thunk >> 63 else self.cstring((thunk & 0x7FFFFFFF) + 2) or "?"
                    self._imports[iat + 8 * i] = f"{dll}!{name}"
                    i += 1
                off += 20
        return self._imports

    # --- strings ------------------------------------------------------------------------------
    def strings(self, pattern, min_len=5):
        rx = re.compile(pattern, re.I)
        found = []
        for _, va, vsize, raw_offset, raw_size, characteristics in self.sections:
            if characteristics & 0x20000000:
                continue
            blob = self.data[raw_offset:raw_offset + min(vsize, raw_size)]
            for m in re.finditer(rb"[\x20-\x7e]{%d,}" % min_len, blob):
                if rx.search(text := m.group().decode()):
                    found.append((va + m.start(), "a", text))
            for m in re.finditer(rb"(?:[\x20-\x7e]\x00){%d,}" % min_len, blob):
                if rx.search(text := m.group().decode("utf-16le")):
                    found.append((va + m.start(), "w", text))
        return sorted(found)

    # --- references ---------------------------------------------------------------------------
    def rip_refs(self, targets, start=None, end=None):
        """[(instruction rva, target rva)] for RIP-relative operands that hit `targets` (a set), or
        any target when it is None, within [start, end) of .text."""
        text = self.data[self.text_off:self.text_off + self.text_size]
        lo = 0 if start is None else start - self.text_va
        hi = len(text) if end is None else end - self.text_va
        found = []
        for m in RIP_FORM.finditer(text, lo, hi):
            legacy = m.group(1)
            disp_at = m.end()
            if disp_at + 4 > len(text):
                continue
            imm = IMMEDIATE.get(legacy[0], 0) if legacy and len(legacy) == 1 else 0
            next_ip = self.text_va + disp_at + 4 + imm
            target = (next_ip + struct.unpack_from("<i", text, disp_at)[0]) & 0xFFFFFFFF
            if targets is None or target in targets:
                found.append((self.text_va + m.start(), target, next_ip - (self.text_va + m.start())))
        return found

    def confirm(self, site, target, length):
        """True if capstone decodes one instruction at `site` of `length` bytes that uses `target`;
        None without capstone."""
        if capstone is None:
            return None
        md = _disassembler()
        off = self.rva_to_off(site)
        for insn in md.disasm(self.data[off:off + 16], site, 1):
            if insn.size != length:
                return False
            return any(op.type == capstone.x86.X86_OP_MEM and op.mem.base == capstone.x86.X86_REG_RIP and
                       (site + insn.size + op.mem.disp) & 0xFFFFFFFF == target for op in insn.operands)
        return False

    def pointers_to(self, targets):
        """[(slot rva, target rva)] for 8-byte absolute pointers (image base + RVA) in the data
        sections, e.g. string tables and static descriptors."""
        wanted = {struct.pack("<Q", self.image_base + t): t for t in targets}
        found = []
        for _, va, vsize, raw_offset, raw_size, characteristics in self.sections:
            if characteristics & 0x20000000:
                continue
            blob = self.data[raw_offset:raw_offset + min(vsize, raw_size)]
            for needle, target in wanted.items():
                at = blob.find(needle)
                while at != -1:
                    if at % 8 == 0:
                        found.append((va + at, target))
                    at = blob.find(needle, at + 1)
        return found

    def where(self, rva):
        """'fn X' for code inside a .pdata function, else the leaf code's neighbourhood."""
        f = self.function_of(rva)
        if f:
            return f"fn {f[2]:#x}"
        begins, ends, primary = self.functions()
        k = bisect.bisect_right(begins, rva) - 1
        return f"leaf code after fn {primary[k]:#x}" if k >= 0 else "no function"

    def branch_index(self, cache_dir):
        """Sorted (target, site, kind) arrays of every E8/E9 rel32 whose target is a function entry."""
        os.makedirs(cache_dir, exist_ok=True)
        path = os.path.join(cache_dir, "pe64-branches.bin")
        digest = hashlib.sha256(self.data).digest()
        if os.path.exists(path):
            with open(path, "rb") as f:
                if f.read(32) == digest:
                    raw = array.array("I")
                    raw.frombytes(f.read())
                    n = len(raw) // 3
                    return raw[:n], raw[n:2 * n], raw[2 * n:]
        text = self.data[self.text_off:self.text_off + self.text_size]
        pairs = []
        for m in re.finditer(rb"[\xE8\xE9]", text):
            i = m.start()
            if i + 5 > len(text):
                continue
            target = (self.text_va + i + 5 + struct.unpack_from("<i", text, i + 1)[0]) & 0xFFFFFFFF
            if self.is_entry(target):
                pairs.append((target, self.text_va + i, text[i] == 0xE9))
        pairs.sort()
        targets, sites, kinds = (array.array("I", (p[k] for p in pairs)) for k in range(3))
        with open(path, "wb") as f:
            f.write(digest)
            f.write(targets.tobytes() + sites.tobytes() + kinds.tobytes())
        return targets, sites, kinds


_md = None


def _disassembler():
    global _md
    if _md is None:
        _md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
        _md.detail = True
    return _md


def parse_rva(text):
    return int(text, 16)


def describe(pe, rva):
    """A short label for an address: import, string, or function."""
    imports = pe.imports()
    if rva in imports:
        return imports[rva]
    if pe.section_of(rva) and pe.section_of(rva) != ".text":
        s = pe.cstring(rva)
        if s:
            return repr(s if len(s) < 90 else s[:87] + "...")
        return f"{pe.section_of(rva)}:{rva:#x}"
    f = pe.function_of(rva)
    if f:
        return f"fn {f[2]:#x}" + (f"+{rva - f[2]:#x}" if rva != f[2] else "")
    return f"{rva:#x}"


def cmd_info(pe, args):
    begins, _, primary = pe.functions()
    print(f"{pe.path}\n  image base {pe.image_base:#x}, {len(begins)} .pdata entries, "
          f"{len(set(primary))} functions")
    for name, va, vsize, _, raw_size, characteristics in pe.sections:
        print(f"  {name:8s} rva {va:#010x} vsize {vsize:10d} raw {raw_size:10d} flags {characteristics:#010x}")
    dlls = {}
    for name in pe.imports().values():
        dll = name.split("!")[0]
        dlls[dll] = dlls.get(dll, 0) + 1
    print("  imports: " + ", ".join(f"{dll} ({n})" for dll, n in dlls.items()))


def cmd_imports(pe, args):
    rx = re.compile(args.args[0], re.I) if args.args else None
    for slot, name in sorted(pe.imports().items()):
        if rx is None or rx.search(name):
            print(f"  {slot:#010x}  {name}")


def cmd_strings(pe, args):
    for rva, kind, text in pe.strings(args.args[0] if args.args else "."):
        print(f"  {rva:#010x} {kind} {text[:150]}")


def cmd_xrefs(pe, args):
    spec = args.args[0]
    if spec.startswith("re:"):
        wanted = {rva: text for rva, _, text in pe.strings(spec[3:])}
    else:
        wanted = {parse_rva(spec): describe(pe, parse_rva(spec))}
    hits = pe.rip_refs(set(wanted))
    by_target = {}
    for site, target, length in hits:
        ok = pe.confirm(site, target, length)
        if ok is False:
            continue
        by_target.setdefault(target, []).append((site, ok))
    pointers = {}
    for slot, target in pe.pointers_to(set(wanted)):
        pointers.setdefault(target, []).append(slot)
    slot_refs = {}
    for site, slot, length in pe.rip_refs({s for slots in pointers.values() for s in slots}):
        if pe.confirm(site, slot, length) is not False:
            slot_refs.setdefault(slot, []).append(site)
    for target in sorted(wanted):
        refs = by_target.get(target, [])
        print(f"{target:#010x} {wanted[target]!r}: {len(refs)} code reference(s), "
              f"{len(pointers.get(target, []))} data pointer(s)")
        for site, ok in refs:
            print(f"    {site:#010x}  in {pe.where(site)}{'' if ok else '  (unconfirmed)'}")
        for slot in pointers.get(target, []):
            users = ", ".join(f"{site:#x} in {pe.where(site)}" for site in slot_refs.get(slot, [])) or                 "no RIP-relative use of that exact slot (likely a table read by index)"
            print(f"    pointer at {pe.section_of(slot)}:{slot:#010x}; used by: {users}")


def cmd_func(pe, args):
    rva = parse_rva(args.args[0])
    f = pe.function_of(rva)
    if f is None:
        sys.exit(f"{rva:#x} is not inside a .pdata function")
    entry = f[2]
    chunks = pe.chunks(entry)
    print(f"function {entry:#x}: " + ", ".join(f"{b:#x}-{e:#x}" for b, e in chunks))
    refs, calls, imports = {}, {}, {}
    for begin, end in chunks:
        for site, target, length in pe.rip_refs(None, begin, end):
            if pe.confirm(site, target, length) is False:
                continue
            if target in pe.imports():
                imports[pe.imports()[target]] = imports.get(pe.imports()[target], 0) + 1
            elif pe.section_of(target) != ".text":
                s = pe.cstring(target)
                if s:
                    refs[target] = s
        text = pe.data[pe.rva_to_off(begin):pe.rva_to_off(begin) + (end - begin)]
        for m in re.finditer(rb"[\xE8\xE9]", text):
            i = m.start()
            if i + 5 <= len(text):
                target = (begin + i + 5 + struct.unpack_from("<i", text, i + 1)[0]) & 0xFFFFFFFF
                if pe.is_entry(target):
                    calls[target] = calls.get(target, 0) + 1
    if refs:
        print("  strings:")
        for target, s in sorted(refs.items()):
            print(f"    {target:#010x}  {s[:140]!r}")
    if imports:
        print("  imports: " + ", ".join(f"{name} x{n}" for name, n in sorted(imports.items())))
    if calls:
        print("  calls (E8/E9 to function entries; byte scan, may include a stray match): " +
              ", ".join(f"{t:#x}" + (f" x{n}" if n > 1 else "") for t, n in sorted(calls.items())))
    if capstone is None:
        print("  (install capstone for a listing)")
        return
    md = _disassembler()
    shown = 0
    for begin, end in chunks:
        off = pe.rva_to_off(begin)
        for insn in md.disasm(pe.data[off:off + (end - begin)], begin):
            note = ""
            for op in insn.operands:
                if op.type == capstone.x86.X86_OP_MEM and op.mem.base == capstone.x86.X86_REG_RIP:
                    note = describe(pe, (insn.address + insn.size + op.mem.disp) & 0xFFFFFFFF)
            if insn.mnemonic in ("call", "jmp") and insn.operands and insn.operands[0].type == capstone.x86.X86_OP_IMM:
                note = describe(pe, insn.operands[0].imm & 0xFFFFFFFF)
            print(f"    {insn.address:#010x}  {insn.mnemonic:8s} {insn.op_str:40s}" + (f" ; {note}" if note else ""))
            shown += 1
            if shown >= args.max:
                print(f"    ... (--max {args.max})")
                return


def cmd_callers(pe, args):
    rva = parse_rva(args.args[0])
    targets, sites, kinds = pe.branch_index(args.cache)
    lo, hi = bisect.bisect_left(targets, rva), bisect.bisect_right(targets, rva)
    print(f"{rva:#x}: {hi - lo} direct call(s)/jump(s)")
    for k in range(lo, hi):
        f = pe.function_of(sites[k])
        print(f"    {sites[k]:#010x}  {'jmp ' if kinds[k] else 'call'} in {f'fn {f[2]:#x}' if f else 'no function'}")


def cmd_threads(pe, args):
    slots = {slot: name.split("!")[1] for slot, name in pe.imports().items() if name.split("!")[1] in CREATORS}
    for site, slot, length in sorted(pe.rip_refs(set(slots))):
        if pe.confirm(site, slot, length) is False:
            continue
        api = slots[slot]
        f = pe.function_of(site)
        window = pe.data[pe.rva_to_off(max(site - 64, f[0] if f else site - 64)):pe.rva_to_off(site)]
        proc = "?"
        for i in range(len(window) - 7, -1, -1):  # the last lea into the procedure register wins
            if LEA_REG.get(window[i:i + 3]) == CREATORS[api]:
                lea_rva = site - len(window) + i
                proc = describe(pe, (lea_rva + 7 + struct.unpack_from("<i", window, i + 3)[0]) & 0xFFFFFFFF)
                break
        print(f"  {site:#010x}  {api:28s} in {f'fn {f[2]:#x}' if f else '?':14s} procedure {proc}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("exe")
    parser.add_argument("command", choices=["info", "imports", "strings", "xrefs", "func", "callers", "threads"])
    parser.add_argument("args", nargs="*")
    parser.add_argument("--max", type=int, default=200, help="listing lines for func")
    parser.add_argument("--cache", help="directory for the E8/E9 index")
    args = parser.parse_args()
    pe = PE64(args.exe)
    if args.cache is None:
        stem = os.path.splitext(os.path.basename(args.exe))[0].lower().replace("_s", "")
        args.cache = os.path.join(REPO, "rea", "evidence", f"{stem}-{hashlib.sha256(pe.data).hexdigest()[:8]}")
    globals()["cmd_" + args.command](pe, args)


if __name__ == "__main__":
    main()
