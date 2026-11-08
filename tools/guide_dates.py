"""Write the dates of docs/modding-guide.md from git: run it after every test video or new key.

Usage: python -I tools/guide_dates.py [--check]

Each feature section of "5. Feature reference" (a "#### key" heading) starts with one line in italics
that says in plain words what the feature does. It is written by hand, and a section without it is an
error. Under that line the section gets:
- the day, date and time its key was added: the first commit whose src/features.h names the key;
- the same for its latest test video: the newest commit of docs/media/<key>-wol*.mp4 or
  docs/media/<key>-<suffix>-wol*.mp4. A video counts for the longest key of the section headings
  (or video name of VIDEO_ALIASES) that its name before "-wol" equals or starts with, followed by
  "-". A video that is not committed yet counts as "now", so run this before the commit that adds it.

"## Latest changes" lists every section, newest first. Its table holds the latest change of each
section: a new test video counts as new.

What each row says comes from the index tables of section 5: the first sentence of "What it does",
and "In-game status". --check only reports what would change. This script is never exported.
"""
import datetime
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
GUIDE = ROOT / "docs" / "modding-guide.md"
SECTION_5, SECTION_6 = "## 5. Feature reference", "## 6. Editing the game data"
LATEST = "## Latest changes"
NEXT_AFTER_LATEST = "## Adding these features to WoL"

# A key whose video is not named after it (its own videos count too).
VIDEO_ALIASES = {"dodgeanyunit": "dodge", "dodgechance": "dodge", "overhealsources": "overhealhitpointbars",
                 "overhealdecay": "overhealhitpointbars"}


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, check=True).stdout.decode("utf-8", "replace")


def stamp(when):
    """Thursday 2026-10-29 13:19"""
    return when.strftime("%A %Y-%m-%d %H:%M")


def key_added_dates():
    """Lowercase key -> the date of the first commit whose src/features.h names it."""
    added = {}
    log = git("log", "--reverse", "--format=%H %aI", "--", "src/features.h")
    for line in log.splitlines():
        commit, when = line.split(" ", 1)
        when = datetime.datetime.fromisoformat(when).replace(tzinfo=None)
        text = git("show", f"{commit}:src/features.h").lower()
        for name in re.findall(r'"([a-z0-9_/ ]+)"', text):
            for key in name.split("/"):
                added.setdefault(key.strip(), when)
    return added


def video_key(stem, known):
    """The longest known name (lowercase) that the stem equals or starts with followed by "-"."""
    stem = stem.lower()
    matches = [k for k in known if stem == k or stem.startswith(k + "-")]
    return max(matches, key=len) if matches else None


def video_dates(known):
    """Known key or video name (lowercase) -> the date of its newest test video."""
    dates = {}
    log = git("log", "--format=@%aI", "--name-only", "--diff-filter=AM", "--", "docs/media/*-wol*.mp4")
    when = None
    for line in log.splitlines():
        if line.startswith("@"):
            when = datetime.datetime.fromisoformat(line[1:]).replace(tzinfo=None)
        elif line:
            key = video_key(pathlib.Path(line).name.split("-wol")[0], known)
            if key is not None:
                dates.setdefault(key, when)  # the log is newest first
    now = datetime.datetime.now()
    for line in git("status", "--porcelain", "--", "docs/media").splitlines():
        match = re.search(r"([^/\s]+?)-wol[^/\s]*\.mp4", line)
        key = video_key(match.group(1), known) if match else None
        if key is not None:
            dates[key] = now
    return dates


def section_keys(heading):
    return [k for k in re.split(r",\s*|\s+and\s+", heading) if k]


def index_rows(text):
    """Key -> (what it does, status), from the tables of section 5."""
    rows = {}
    for line in text.split("\n"):
        cells = [c.strip() for c in line.strip().strip("|").split(" | ")]
        keys = re.findall(r"`([^`]+)`", cells[0]) if line.startswith("| [`") else []
        for key in keys:
            rows.setdefault(key, (cells[1], cells[3] if len(cells) > 3 else ""))
    return rows


def first_sentence(text):
    match = re.match(r"(.+?[.])(\s|$)", text)
    return match.group(1) if match else text


def anchor(heading):
    return "#" + re.sub(r"[^\w\- ]", "", heading.lower()).replace(" ", "-")


def update(text):
    start, end = text.index(SECTION_5), text.index(SECTION_6)
    body = text[start:end]
    parts = re.split(r"(?m)^(?=#### )", body)
    known = {k.lower() for part in parts[1:] for k in section_keys(part.split("\n", 1)[0][5:].strip())}
    known |= set(VIDEO_ALIASES.values())
    added_dates, videos = key_added_dates(), video_dates(known)
    rows = index_rows(body)
    entries = []
    out = [parts[0]]
    for part in parts[1:]:
        # A group heading after the section's text belongs to the next section.
        heading, rest = part.split("\n", 1)
        heading = heading[5:].strip()
        keys = section_keys(heading)
        found = [added_dates[k.lower()] for k in keys if k.lower() in added_dates]
        if not found:
            sys.exit(f"guide_dates: no commit of src/features.h names {heading}")
        added = min(found)
        names = {n for k in keys for n in (k.lower(), VIDEO_ALIASES.get(k.lower(), k.lower()))}
        filmed = [videos[s] for s in names if s in videos]
        filmed = max(filmed) if filmed else None
        summary = re.match(r"\A\n?(\*[^*\n][^\n]*\*)\n", rest)
        if summary is None:
            sys.exit(f"guide_dates: {heading} has no one-line description under its heading")
        rest = re.sub(r"\A\n?(\*\*Added:\*\*[^\n]*\n)+", "", rest[summary.end():])
        rest = rest.lstrip("\n")
        if filmed is not None:
            lines = f"**Added:** {stamp(added)} · **Filmed in WoL:** {stamp(filmed)}\n"
        else:
            lines = f"**Added:** {stamp(added)}\n"
        out.append(f"#### {heading}\n\n{summary.group(1)}\n\n{lines}\n{rest}")
        what, status = next((rows[k] for k in keys if k in rows), ("", ""))
        link = ", ".join(f"[`{k}`]({anchor(heading)})" for k in keys)
        entries.append((added, filmed, link, first_sentence(what), status))
    text = text[:start] + "".join(out) + text[end:]

    rows_out = []
    for added, filmed, link, what, status in sorted(entries, key=lambda e: e[1] or e[0], reverse=True):
        if filmed is not None and filmed > added:
            rows_out.append(f"| {stamp(filmed)} | {link} | Filmed in WoL, with a control. {what} | {status} |")
        else:
            rows_out.append(f"| {stamp(added)} | {link} | Added. {what} | {status} |")
    block = "\n".join([
        LATEST, "",
        "Every feature, newest first, with the day, date and time of its latest change (the commit's",
        "local time). The details are in the feature's section, under its heading.", "",
        "A new test video counts as a change: a feature filmed again in WoL moves back to the top.", "",
        "| Date and time | Key | What changed | Status |", "|---|---|---|---|", *rows_out, "", "",
    ])
    first, last = text.index(LATEST), text.index(NEXT_AFTER_LATEST)
    return text[:first] + block + text[last:]


def main(argv):
    raw = GUIDE.read_bytes()
    crlf = b"\r\n" in raw
    text = raw.decode("utf-8").replace("\r\n", "\n")
    new = update(text)
    if new == text:
        print("guide_dates: nothing to change")
        return
    if "--check" in argv:
        sys.exit("guide_dates: the dates of the guide are out of date")
    GUIDE.write_bytes((new.replace("\n", "\r\n") if crlf else new).encode("utf-8"))
    print("guide_dates: docs/modding-guide.md updated")


if __name__ == "__main__":
    main(sys.argv[1:])
