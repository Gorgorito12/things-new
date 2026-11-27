"""Export the public version of this repository into a clone of the public repo.

Usage: python -I tools/export_public.py --check
       python -I tools/export_public.py --out <public-clone>

This repository is private. The public repo (Gorgorito12/tad-engine-extensions) gets a copy of an
allowlist of files, never this repository's history. Changes flow one way, private -> public:
never pull or merge the public repo back into this one.

What the export does:
  - copies the files in INCLUDE, plus the docs/media files that the exported docs reference;
  - in .md files, drops every line that contains <!-- private --> and every block between a line
    <!-- private:begin --> and a line <!-- private:end --> (both markers included);
  - in .md files, unwraps text that only the public version shows, hidden here as a comment: a
    line <!-- public: TEXT --> becomes TEXT, and the lines between a line <!-- public:begin and a
    line public:end --> are kept without those two marker lines;
  - refuses to write anything if an exported text file still matches a BANNED pattern, or if a
    .md link points to a file or a heading anchor that is not exported.

--check builds the export in memory and only reports. --out empties the target folder (all but
its .git and KEEP_IN_CLONE) and writes the export there; commit and push it by hand. The script itself, CLAUDE.md
and the private docs are never exported: this file's BANNED list alone would name what the
public repo leaves out.
"""
import argparse
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]

INCLUDE = [
    ".gitignore",
    "CMakeLists.txt",
    "LICENSE",
    "README.md",
    "src",
    "examples",
    "docs/how-it-works.md",
    "tools/bar.py",
    "tools/gen_sites.py",
    "tools/package_release.py",
    "tools/xmbedit.py",
]

# Written for one mod since 2026-11-04, so no longer exported. The public clone keeps what it has at
# these paths: --out leaves them alone and links to them count as exported.
KEEP_IN_CLONE = ("docs/modding-guide.md", "docs/media")

BANNED = [
    r"\bWoL\b", r"(?-i:WoL)", r"Wars of Liberty", r"\bMandos\b", r"\bMaston\b",
    r"\bDE\b", r"AoE3DE", r"Definitive Edition", r"World'?s Edge",
    r"Pereira", r"Un-?har(?:d)?coded", r"\bupstream\b", r"UHC 1\.\d",
    r"Knights and Barbarians", r"Cosas_magicas",
    # Names from one mod's data that identify it without naming it.
    r"Maori", r"Mapuche", r"Guatemala", r"alguacil", r"EGYtowncenter", r"Presidio", r"saltpeter",
    r"FloatingBattery", r"uimainnew",
    r"wol-(?:requests|uhc-map|migration)", r"de-(?:parity|architecture)", r"porting-to-another-dll",
    r"uhc-address-map", r"export_public", r"[A-Za-z]:\\Users\\",
]
# Private docs that code comments may still cite (they name nothing sensitive); a .md link to them
# fails the link check instead.
BANNED_RE = re.compile("|".join(BANNED), re.IGNORECASE)

TEXT_SUFFIXES = {".md", ".cpp", ".h", ".asm", ".inc", ".py", ".txt", ".cfg", ".in", ".rc",
                 ".tactics", ".xml", ".gitignore", ""}

LINE_MARK = "<!-- private -->"
BEGIN_MARK = "<!-- private:begin -->"
END_MARK = "<!-- private:end -->"
PUBLIC_LINE_RE = re.compile(r"^(\s*)<!-- public: (.*) -->\s*$")
PUBLIC_BEGIN = "<!-- public:begin"
PUBLIC_END = "public:end -->"

LINK_RE = re.compile(r"\]\(([^)\s]+)\)")
MEDIA_RE = re.compile(r"(?:\.\./)?(?:docs/)?media/[A-Za-z0-9_.-]+")


def strip_private(rel, text, problems):
    out, depth, public = [], 0, False
    for n, line in enumerate(text.split("\n"), 1):
        mark = line.strip()
        if mark == PUBLIC_BEGIN or mark == PUBLIC_END:
            if public == (mark == PUBLIC_BEGIN):
                problems.append(f"{rel}:{n}: unbalanced {mark}")
            public = mark == PUBLIC_BEGIN
            continue
        m = PUBLIC_LINE_RE.match(line)
        if m and not depth:
            out.append(m.group(1) + m.group(2))
            continue
        if mark == BEGIN_MARK:
            if depth:
                problems.append(f"{rel}:{n}: nested {BEGIN_MARK}")
            depth += 1
            continue
        if mark == END_MARK:
            if not depth:
                problems.append(f"{rel}:{n}: {END_MARK} without {BEGIN_MARK}")
            depth = max(depth - 1, 0)
            continue
        if depth or LINE_MARK in line:
            continue
        out.append(line)
    if depth:
        problems.append(f"{rel}: {BEGIN_MARK} never closed")
    if public:
        problems.append(f"{rel}: {PUBLIC_BEGIN} never closed")
    return re.sub(r"\n{3,}", "\n\n", "\n".join(out))


def slugs(text):
    """GitHub heading anchors of a Markdown text (code fences skipped)."""
    seen, result, fence = {}, set(), False
    for line in text.split("\n"):
        if line.lstrip().startswith("```"):
            fence = not fence
            continue
        m = None if fence else re.match(r"#{1,6}\s+(.*?)\s*#*\s*$", line)
        if not m:
            continue
        title = re.sub(r"`|\*\*|\*|\[([^\]]*)\]\([^)]*\)", lambda x: x.group(1) or "", m.group(1))
        slug = re.sub(r"[^\w\- ]", "", title.lower()).replace(" ", "-")
        count = seen.get(slug, 0)
        seen[slug] = count + 1
        result.add(slug if count == 0 else f"{slug}-{count}")
    return result


def collect():
    files = {}
    for entry in INCLUDE:
        path = ROOT / entry
        paths = sorted(p for p in path.rglob("*") if p.is_file()) if path.is_dir() else [path]
        for p in paths:
            files[p.relative_to(ROOT).as_posix()] = p
    return files


def build():
    problems, out = [], {}
    for rel, path in collect().items():
        data = path.read_bytes()
        if path.suffix in TEXT_SUFFIXES or path.name in (".gitignore", "LICENSE", "CMakeLists.txt"):
            text = data.decode("utf-8")
            if path.suffix == ".md":
                text = strip_private(rel, text, problems)
            out[rel] = text
        else:
            out[rel] = data

    docs = {rel: t for rel, t in out.items() if rel.endswith(".md")}
    for rel, text in docs.items():
        for m in MEDIA_RE.finditer(text):
            media = (ROOT / rel).parent.joinpath(m.group(0)).resolve().relative_to(ROOT).as_posix()
            if media not in out:
                if not (ROOT / media).is_file():
                    problems.append(f"{rel}: missing media {m.group(0)}")
                else:
                    out[media] = (ROOT / media).read_bytes()

    anchors = {rel: slugs(t) for rel, t in docs.items()}
    for rel, text in docs.items():
        for n, line in enumerate(text.split("\n"), 1):
            for m in LINK_RE.finditer(line):
                target = m.group(1)
                if re.match(r"[a-z]+:", target):
                    continue
                file_part, _, anchor = target.partition("#")
                dest = rel if not file_part else (
                    (ROOT / rel).parent.joinpath(file_part).resolve().relative_to(ROOT).as_posix())
                if dest in KEEP_IN_CLONE:
                    continue
                if dest not in out and not any(k.startswith(dest + "/") for k in out):
                    problems.append(f"{rel}:{n}: link to a file that is not exported: {target}")
                elif anchor and dest in anchors and anchor not in anchors[dest]:
                    problems.append(f"{rel}:{n}: link to a missing anchor: {target}")

    for rel, content in out.items():
        if isinstance(content, str):
            for n, line in enumerate(content.split("\n"), 1):
                m = BANNED_RE.search(line)
                if m:
                    problems.append(f"{rel}:{n}: banned '{m.group(0)}': {line.strip()[:120]}")
    return out, problems


def empty(folder, target):
    """Deletes what is in folder, but for .git, KEEP_IN_CLONE and the folders that lead to them."""
    for child in folder.iterdir():
        rel = child.relative_to(target).as_posix()
        if rel == ".git" or rel in KEEP_IN_CLONE:
            continue
        if child.is_dir() and any(k.startswith(rel + "/") for k in KEEP_IN_CLONE):
            empty(child, target)
        elif child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink()


def main():
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--out", type=pathlib.Path)
    args = parser.parse_args()

    out, problems = build()
    if problems:
        print("\n".join(problems))
        sys.exit(f"export_public: {len(problems)} problem(s); nothing written")
    if args.check:
        print(f"export_public: OK, {len(out)} files")
        return

    target = args.out.resolve()
    if target == ROOT or ROOT in target.parents:
        sys.exit("export_public: --out must be outside this repository")
    if not (target / ".git").is_dir():
        sys.exit(f"export_public: {target} is not a git clone")
    empty(target, target)
    for rel, content in out.items():
        dest = target / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, str):
            dest.write_text(content, encoding="utf-8", newline="\n")
        else:
            dest.write_bytes(content)
    print(f"export_public: wrote {len(out)} files to {target}")


if __name__ == "__main__":
    main()
