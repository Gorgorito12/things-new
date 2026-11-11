"""Play every random map of a test copy for a short while and write one CSV row per run: does the map
generate, load and run, or does the game crash, hang or report an XS error?

    python -I tools/mapsweep.py --bed <copy> --csv <out.csv> [options]

Options:
  --maps A,B,...        these maps (file names without .xs); default: every .xs of the copy's map
                        folder (RM4 in WoL) that has an .xml, so the include libraries are skipped
  --list <file>         the maps of a text file, one per line (# comments)
  --match <regex>       only the maps whose name matches
  --players 2[,4,8]     player counts (default 2)
  --seeds 1[,2,3]       map seeds (default 1)
  --seconds 30          game time to let pass once the map runs (default 30)
  --route scenario      scenario (default): testbed's editor route, startRandomGame2 then save and
                        load as a scenario, players without AI. skirmish: the profile's skirmish with
                        AIs (see below); only one copy at a time, as the profile is shared
  --ai <personality>    skirmish: the AI personalities left in AI4 (one per AI: players - 1; an AI with
                        none starts without a civ and the game falls at 0x7C252C); default wolOtto
  --shard K/N           only the maps whose index modulo N is K (from 0), for copies run in parallel
  --evidence <dir>      where crash reports, per-run logs and shots go (default: next to the CSV)
  --no-debugger         do not attach tools/re/debugger.py's crash watch; a crash then comes from the
                        Windows Application log (Application Error, the faulting offset)
  --dry-run             print the runs left and stop

Results: ok, crash (the process died: code, EIP, module from the crash watch or the event log), hang
(window not responding, or the world clock stood still 60 s), xs-error (the run went on but
engine-ext.log got xsErrorLog lines: the copy's cfg needs xsErrorLog), timeout (a step did not finish
and the game still answers), launch-failed. The CSV is resumable: a run already in it is skipped, so
the sweep can be stopped and started again. Rows also list the units per player once the map runs.

The copy needs testbed.py's harness: perfExecFile and multipleInstances background in the cfg the
exe reads (engine-ext\\engine-ext.cfg beside another UHC.dll). Before each run the sweep waits for
6 GB of free memory (UHC_SWEEP_MIN_FREE_GB). A game it started and that hangs is killed; a game it
did not start is never touched: the sweep refuses to begin while the copy is already running.

Skirmish route: the profile (Users3\\*.xml of the copy's My Games folder) is backed up when the
sweep starts and restored byte for byte when it ends, as are the AI personalities
(tools/ai_personality.py ... restore); the home city and the AI's memory files are copied back too.
The game is closed before each profile edit (it rewrites the profile when it exits).
"""
import csv
import ctypes
import ctypes.wintypes as wt
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time

TOOLS = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(TOOLS / "re"))
import testbed as T  # noqa: E402

FIELDS = ["map", "players", "seed", "route", "result", "code", "eip", "module", "detail", "units",
          "xs_errors", "log_tail", "age3log_tail", "started", "seconds", "bed"]
MIN_FREE_GB = float(os.environ.get("UHC_SWEEP_MIN_FREE_GB", "6"))


class MEMORYSTATUSEX(ctypes.Structure):
    _fields_ = [("dwLength", wt.DWORD), ("dwMemoryLoad", wt.DWORD), ("ullTotalPhys", ctypes.c_ulonglong),
                ("ullAvailPhys", ctypes.c_ulonglong), ("ullTotalPageFile", ctypes.c_ulonglong),
                ("ullAvailPageFile", ctypes.c_ulonglong), ("ullTotalVirtual", ctypes.c_ulonglong),
                ("ullAvailVirtual", ctypes.c_ulonglong), ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]


def free_gb():
    m = MEMORYSTATUSEX()
    m.dwLength = ctypes.sizeof(m)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m))
    return m.ullAvailPhys / 2 ** 30


def wait_memory():
    told = False
    while free_gb() < MIN_FREE_GB:
        if not told:
            print(f"mapsweep: {free_gb():.1f} GB free, waiting for {MIN_FREE_GB:g}", flush=True)
            told = True
        time.sleep(30)


def say(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


# --- the CSV --------------------------------------------------------------------------------------

def done_runs(path):
    if not path.exists():
        return set()
    with open(path, newline="", encoding="utf-8") as f:
        return {(r["map"], r["players"], r["seed"], r["route"]) for r in csv.DictReader(f)}


def append_row(path, row):
    """Appends one row under a lock file, as several copies may write the same CSV."""
    lock = path.with_suffix(".lock")
    while True:
        try:
            os.close(os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY))
            break
        except FileExistsError:
            if time.time() - lock.stat().st_mtime > 60:
                lock.unlink(missing_ok=True)
            time.sleep(0.2)
    try:
        new = not path.exists()
        with open(path, "a", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, FIELDS)
            if new:
                w.writeheader()
            w.writerow({k: row.get(k, "") for k in FIELDS})
    finally:
        lock.unlink(missing_ok=True)


# --- the game -----------------------------------------------------------------------------------

def testbed(bed, *args, timeout=600):
    """Runs a testbed.py command; returns (exit code, output). A step that overruns its own timeout
    is reported as exit code 2."""
    try:
        r = subprocess.run([sys.executable, "-I", str(TOOLS / "testbed.py"), "--bed", str(bed), *args],
                           capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()
    except subprocess.TimeoutExpired as e:
        out = ((e.stdout or b"").decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or ""))
        return 2, out + f"\nmapsweep: testbed {' '.join(args)} overran {timeout} s"


class Game:
    """The copy's game, started by this sweep, and its crash watch."""

    def __init__(self, bed, evidence, debugger=True):
        self.bed, self.evidence, self.debugger = bed, evidence, debugger
        self.pid, self.watch, self.report = None, None, None

    def running(self):
        return self.pid is not None and T.bed_pid() == self.pid

    def start(self):
        if T.bed_pid():
            sys.exit(f"mapsweep: a game this sweep did not start runs in {self.bed}; close it first")
        for attempt in (1, 2):
            rc, out = testbed(self.bed, "launch", timeout=420)
            pid = T.bed_pid()
            if rc == 0 and pid:
                self.pid = pid
                break
            say(f"launch failed (attempt {attempt}): {out[-300:]}")
            if pid:
                self.kill(pid)
        else:
            return False
        if self.debugger:
            self.report = self.evidence / f"crash-{self.bed.name}-{self.pid}.jsonl"
            env = dict(os.environ, UHC_GAME_DIR=str(self.bed))
            self.watch = subprocess.Popen(
                [sys.executable, "-I", str(TOOLS / "re" / "debugger.py"), "crash", "--out", str(self.report),
                 "--log", str(self.report.with_suffix(".log"))],
                env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(2)
        say(f"game started, pid {self.pid}" + (", crash watch attached" if self.watch else ""))
        return True

    def reports(self):
        if not self.report or not self.report.exists():
            return []
        return [json.loads(line) for line in self.report.read_text(encoding="utf-8").splitlines() if line.strip()]

    def kill(self, pid=None):
        pid = pid or self.pid
        if pid and T.bed_pid() == pid:
            subprocess.run(["taskkill", "/F", "/PID", str(pid)], capture_output=True)
            for _ in range(30):
                if T.bed_pid() != pid:
                    break
                time.sleep(1)
        self.ended()

    def close(self):
        if self.running():
            testbed(self.bed, "close", timeout=120)
            if self.running():
                self.kill()
        self.ended()

    def ended(self):
        if self.watch:
            try:
                self.watch.wait(timeout=20)  # it ends by itself when the game exits
            except subprocess.TimeoutExpired:
                self.watch.kill()  # no breakpoint is set, so this cannot hurt the game
            self.watch = None
        self.pid = None


def event_log_crash(pid, since):
    """The Application Error entry (event 1000) of this pid after `since`, from the Windows log."""
    script = ("$e = Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Application Error'; "
              f"StartTime=[datetime]::Parse('{time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(since - 5))}')}} "
              "-ErrorAction SilentlyContinue | Where-Object { $_.Id -eq 1000 }; "
              "$e | ForEach-Object { ($_.Properties | ForEach-Object { $_.Value }) -join '|' }")
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-Command", script], capture_output=True, text=True,
                             timeout=60).stdout
    except subprocess.TimeoutExpired:
        return None
    for line in out.splitlines():
        p = line.split("|")
        # 0 app, 1 version, 2 stamp, 3 module, 4 version, 5 stamp, 6 code, 7 offset, 8 pid (decimal)
        if len(p) > 8 and p[0].lower() == "age3y.exe" and p[8].strip().isdigit() and int(p[8]) == pid:
            offset = int(p[7], 16)
            eip = offset + 0x400000 if p[3].lower() == "age3y.exe" else None
            return {"code": "0x" + p[6].lower().removeprefix("0x").zfill(8), "module": f"{p[3]}+{offset:#x}",
                    "eip": f"{eip:#x}" if eip is not None else ""}
    return None


# --- one run --------------------------------------------------------------------------------------

def tail_since(path, offset, lines=6, pattern=None):
    if not path.exists():
        return "", []
    with open(path, "rb") as f:
        f.seek(offset if path.stat().st_size >= offset else 0)
        text = f.read().decode("utf-8", "replace")
    rows = [r for r in text.splitlines() if r.strip()]
    if pattern:
        rows = [r for r in rows if re.search(pattern, r)]
    return text, rows[-lines:]


def size(path):
    return path.stat().st_size if path.exists() else 0


def unit_counts(bed):
    rc, out = testbed(bed, "units", timeout=60)
    counts = {}
    for line in out.splitlines():
        m = re.match(r"\s*\d+\s+player (-?\d+)", line)
        if m:
            counts[m.group(1)] = counts.get(m.group(1), 0) + 1
    return " ".join(f"p{k}:{v}" for k, v in sorted(counts.items(), key=lambda kv: int(kv[0])))


XS_LINE = r"xsErrorLog: (?!applied)|XS: "


def run_one(game, bed, map_name, players, seed, seconds, route, evidence, ai):
    row = {"map": map_name, "players": players, "seed": seed, "route": route, "bed": bed.name,
           "started": time.strftime("%Y-%m-%d %H:%M:%S")}
    t0 = time.time()
    tag = re.sub(r"[^\w.-]+", "_", f"{map_name}-p{players}-s{seed}-{route}")
    log = T.log_path(bed)
    age3log = T.my_games(bed) / "Age3Log.txt"
    if route == "skirmish":
        game.close()
        set_skirmish(bed, map_name, players, ai)
    wait_memory()
    if not game.running() and not game.start():
        row.update(result="launch-failed", seconds=round(time.time() - t0))
        return row
    pid = game.pid
    log_at, age3_at = size(log), size(age3log)
    reports_before = len(game.reports())
    if route == "scenario":
        rc, out = testbed(bed, "scenario", map_name, "--players", str(players), "--seed", str(seed), timeout=900)
    else:
        rc, out = testbed(bed, "skirmish", timeout=600)
    step = route
    if rc == 0:
        row["units"] = unit_counts(bed)
        rc, out = testbed(bed, "wait", str(seconds), "--hang", "60", timeout=int(seconds * 10 + 200))
        step = "wait"
    alive = T.bed_pid() == pid
    if rc == 0 and alive:
        row["result"] = "ok"
        testbed(bed, "shot", str(evidence / "shots" / f"{tag}.png"), "4", timeout=60)
    elif rc == 3 or not alive:
        row["result"] = "crash"
        game.ended()  # waits for the crash watch to write its report
    elif rc == 4:
        row["result"] = "hang"
    else:
        row["result"] = "timeout"
    if row["result"] in ("hang", "timeout"):
        testbed(bed, "shot", str(evidence / "shots" / f"{tag}.{row['result']}.png"), "4", timeout=60)
    row["detail"] = f"{step}: " + " / ".join(line for line in out.splitlines()[-2:])[:300]
    if row["result"] == "crash":
        crash = [r for r in game.reports()[reports_before:] if not r["first_chance"]]
        first = [r for r in game.reports()[reports_before:] if r["first_chance"]]
        r = (crash or first or [None])[-1]
        if r:
            row.update(code=r["code"], eip=r["eip"], module=r["module"])
            row["detail"] += f" | chain {' '.join(r['call_chain'][:8])}"
            if r.get("access"):
                row["detail"] += f" | {r['access']} of {r['target']}"
        else:
            ev = event_log_crash(pid, t0)
            if ev:
                row.update(code=ev["code"], eip=ev["eip"], module=ev["module"] + " (event log)")
    elif row["result"] in ("hang", "timeout"):
        game.kill()  # a game this sweep started; the next run starts a new one
        ev = event_log_crash(pid, t0)  # without the crash watch, Windows' error dialog keeps a crash alive
        if ev:
            row.update(result="crash", code=ev["code"], eip=ev["eip"], module=ev["module"] + " (event log)")
    text, xs = tail_since(log, log_at, 8, XS_LINE)
    if xs:
        row["xs_errors"] = " || ".join(xs)[:800]
        if row["result"] == "ok":
            row["result"] = "xs-error"
    row["log_tail"] = " || ".join(tail_since(log, log_at, 4)[1])[:500]
    age3_text, age3_rows = tail_since(age3log, age3_at, 4)
    row["age3log_tail"] = " || ".join(age3_rows)[:500]
    runs = evidence / "runs"
    runs.mkdir(parents=True, exist_ok=True)
    (runs / f"{tag}.log").write_text(f"{out}\n--- {log.name}\n{text}\n--- Age3Log.txt\n{age3_text}\n",
                                     encoding="utf-8")
    scn = T.my_games(bed) / "Scenario" / f"uhc-{map_name}.age3Yscn"
    if route == "scenario" and scn.exists() and row["result"] in ("ok", "xs-error"):
        scn.unlink(missing_ok=True)  # this sweep's scenario; a failed one is kept for a look
    if route == "skirmish":
        game.close()
    row["seconds"] = round(time.time() - t0)
    return row


# --- the skirmish route's profile ----------------------------------------------------------------

def display_name(bed, map_name):
    """The name the setup screen shows: the .xml's displayName, or its displayNameID's string."""
    xml = (bed / T.bed_profile(bed)["rm"] / f"{map_name}.xml").read_text(encoding="utf-8", errors="replace")
    m = re.search(r'displayName\s*=\s*"([^"]*)"', xml)
    if m:
        return re.sub(r"&#(\d+);", lambda g: chr(int(g.group(1))), m.group(1)).replace("&quot;", '"')
    m = re.search(r'displayNameID\s*=\s*"(\d+)"', xml)
    if m:
        raw = (bed / "data" / "stringtabley.xml").read_bytes()
        text = raw.decode("utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8", "replace")
        s = re.search(r"""_locID\s*=\s*['"]%s['"][^>]*>([^<]*)<""" % m.group(1), text)
        if s:
            return s.group(1)
    return map_name


def profiles(bed):
    return sorted((T.my_games(bed) / "Users3").glob("*.xml"))


def set_skirmish(bed, map_name, players, ai):
    values = {"gamefilename": map_name, "gamemapname": display_name(bed, map_name),
              "gamenumplayers": str(players)}
    for path in profiles(bed):
        text = path.read_bytes().decode("utf-16")
        b0 = text.find('<GameSettings Name="RandomMapGameSettings"')
        if b0 < 0:
            continue
        b1 = text.index("</GameSettings>", b0)
        block = text[b0:b1]
        for name, value in values.items():
            block = re.sub(r'(<Setting Name="%s">)[^<]*(<)' % name,
                           lambda m: m.group(1) + value.replace("&", "&amp;").replace('"', "&quot;")
                           .replace("<", "&lt;") + m.group(2), block)
        path.write_bytes(b"\xff\xfe" + (text[:b0] + block + text[b1:]).encode("utf-16-le"))


class SkirmishState:
    """Backs up what a skirmish changes and puts it back."""

    def __init__(self, bed, ai):
        self.bed, self.ai = bed, ai
        games = T.my_games(bed)
        self.files = [*profiles(bed), *(games / "Savegame").glob("sp_*_homecity.xml"),
                      *(games / "Savegame").glob("LastHomeCity*.xml"), *(games / "AI4").glob("*.personality")]
        self.saved = {p: p.read_bytes() for p in self.files}

    def __enter__(self):
        rc = subprocess.run([sys.executable, "-I", str(TOOLS / "ai_personality.py"), str(self.bed), *self.ai]).returncode
        if rc:
            sys.exit("mapsweep: ai_personality.py failed")
        return self

    def __exit__(self, *exc):
        subprocess.run([sys.executable, "-I", str(TOOLS / "ai_personality.py"), str(self.bed), "restore"])
        for path, data in self.saved.items():
            if not path.exists() or path.read_bytes() != data:
                path.write_bytes(data)
                print(f"mapsweep: restored {path}")


# --- main -----------------------------------------------------------------------------------------

def arg(argv, name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


def map_list(bed, argv):
    folder = bed / T.bed_profile(bed)["rm"]
    if "--maps" in argv:
        maps = [m.strip() for m in arg(argv, "--maps").split(",") if m.strip()]
    elif "--list" in argv:
        maps = [line.split("#")[0].strip() for line in open(arg(argv, "--list"), encoding="utf-8")]
        maps = [m for m in maps if m]
    else:
        maps = sorted(p.stem for p in folder.glob("*.xs") if (folder / f"{p.stem}.xml").exists())
    missing = [m for m in maps if not (folder / f"{m}.xs").exists()]
    if missing:
        sys.exit(f"mapsweep: not in {folder}: {', '.join(missing)}")
    if "--match" in argv:
        maps = [m for m in maps if re.search(arg(argv, "--match"), m)]
    if "--shard" in argv:
        k, n = (int(v) for v in arg(argv, "--shard").split("/"))
        maps = [m for i, m in enumerate(maps) if i % n == k]
    return maps


def main(argv):
    if "--bed" not in argv or "--csv" not in argv:
        sys.exit(__doc__)
    bed = T.BED = T.bed_folder(arg(argv, "--bed"))
    out = pathlib.Path(arg(argv, "--csv")).resolve()
    evidence = pathlib.Path(arg(argv, "--evidence", str(out.parent))).resolve()
    (evidence / "shots").mkdir(parents=True, exist_ok=True)
    route = arg(argv, "--route", "scenario")
    players = [int(v) for v in arg(argv, "--players", "2").split(",")]
    seeds = [int(v) for v in arg(argv, "--seeds", "1").split(",")]
    seconds = float(arg(argv, "--seconds", "30"))
    ai = arg(argv, "--ai", "wolOtto").split(",")
    maps = map_list(bed, argv)
    done = done_runs(out)
    runs = [(m, p, s) for m in maps for p in players for s in seeds if (m, str(p), str(s), route) not in done]
    print(f"mapsweep: {bed}, {len(maps)} maps, {len(runs)} runs left (route {route})", flush=True)
    if "--dry-run" in argv:
        for r in runs:
            print("  ", *r)
        return
    if route == "skirmish" and "--shard" in argv:
        sys.exit("mapsweep: the skirmish route edits the shared profile: one copy at a time, no --shard")
    game = Game(bed, evidence, "--no-debugger" not in argv)
    if T.bed_pid():
        sys.exit(f"mapsweep: a game already runs in {bed}; close it first (the sweep only kills games it started)")
    state = SkirmishState(bed, ai) if route == "skirmish" else None
    try:
        if state:
            state.__enter__()
        for i, (m, p, s) in enumerate(runs, 1):
            row = run_one(game, bed, m, p, s, seconds, route, evidence, ai)
            append_row(out, row)
            say(f"[{i}/{len(runs)}] {m} p{p} s{s}: {row['result']} {row.get('code', '')} {row.get('eip', '')} "
                f"{row.get('module', '')} ({row['seconds']} s) {row.get('units', '')}")
    finally:
        game.close()
        if state:
            state.__exit__()
        T.remove_own_scenarios(bed)


if __name__ == "__main__":
    main(sys.argv[1:])
