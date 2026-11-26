"""Build the release zip in one command, from a clean checkout: dist/UHC-<version>.zip.

Usage: python -I tools/make_release.py [--ref REF] [--out DIR] [--force] [--dinput8-only]
                                       [--dxvk DIR] [--cmake EXE] [--keep]

It does what a release needs, in this order, so that the zip never picks up an uncommitted or
half-merged file from the working folder:
  1. git fetch, then a temporary detached worktree of REF (default origin/main);
  2. CMake (Visual Studio 18 2026, Win32) and a Release build of UHC.dll and dinput8.dll there;
  3. tools/package_release.py in that worktree, which checks the DLL (32-bit, exports
     _UHCMain@0, carries the version of CMakeLists.txt) and writes the zip;
  4. the zip copied to DIR (default dist/ of this repository), the SHA-256 printed;
  5. the temporary worktree removed (kept with --keep, for a look at the build).

The version is the one in REF's CMakeLists.txt (project(UHC VERSION x.y.z)): to release a new
version, commit the bump first (docs/developer-guide.md, section 7) and pass that branch as --ref
if it is not merged yet. An existing zip in DIR is kept unless --force is given.

--dinput8-only   the dinput8-<version>.zip instead (no UHC.dll), as package_release.py does.
--dxvk DIR       DXVK 3.1.1's d3d9.dll and LICENSE (default rea/vendor/dxvk-3.1.1 of this repository).
--cmake EXE      cmake.exe; otherwise $UHC_CMAKE, the one of Visual Studio 2026 (found with vswhere),
                 or cmake on PATH.
"""
import argparse
import hashlib
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
GENERATOR = "Visual Studio 18 2026"
VS_CMAKE = r"Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
VSWHERE = pathlib.Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) / \
    "Microsoft Visual Studio" / "Installer" / "vswhere.exe"


def fail(message):
    sys.exit(f"make_release: {message}")


def run(cmd, cwd=None, log=None):
    """Runs a command; on failure prints the tail of its output and stops."""
    shown = " ".join(f'"{c}"' if " " in str(c) else str(c) for c in cmd)
    print(f"> {shown}", flush=True)
    proc = subprocess.run([str(c) for c in cmd], cwd=cwd, capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    output = proc.stdout + proc.stderr
    if log:
        log.write_text(output, encoding="utf-8")
    if proc.returncode:
        tail = "\n".join(output.splitlines()[-25:])
        fail(f"failed with exit code {proc.returncode}:\n{tail}" + (f"\n(full output: {log})" if log else ""))
    return proc.stdout


def find_cmake(given):
    candidates = [given, os.environ.get("UHC_CMAKE")]
    if VSWHERE.is_file():
        for path in subprocess.run([str(VSWHERE), "-all", "-prerelease", "-version", "[18.0,19.0)",
                                    "-property", "installationPath"],
                                   capture_output=True, text=True).stdout.splitlines():
            candidates.append(str(pathlib.Path(path.strip()) / VS_CMAKE))
    candidates.append(str(pathlib.Path(r"C:\Program Files\Microsoft Visual Studio\18\Insiders") / VS_CMAKE))
    candidates.append(shutil.which("cmake"))
    for c in candidates:
        if c and pathlib.Path(c).is_file():
            return pathlib.Path(c)
    fail("cmake.exe not found; pass --cmake or set UHC_CMAKE (Visual Studio 2026's own cmake)")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--ref", default="origin/main", help="what to build (default origin/main)")
    parser.add_argument("--out", type=pathlib.Path, default=ROOT / "dist", help="where the zip goes")
    parser.add_argument("--force", action="store_true", help="replace an existing zip")
    parser.add_argument("--dinput8-only", action="store_true", help="the dinput8-<version>.zip instead")
    parser.add_argument("--dxvk", type=pathlib.Path, default=ROOT / "rea" / "vendor" / "dxvk-3.1.1")
    parser.add_argument("--cmake", help="cmake.exe to use")
    parser.add_argument("--keep", action="store_true", help="keep the temporary worktree")
    args = parser.parse_args()

    if not (args.dxvk / "d3d9.dll").is_file():
        fail(f"no DXVK d3d9.dll in {args.dxvk} (see docs/developer-guide.md, section 7)")
    cmake = find_cmake(args.cmake)

    if args.ref.startswith("origin/"):
        run(["git", "-C", ROOT, "fetch", "origin"])
    commit = run(["git", "-C", ROOT, "rev-parse", "--verify", f"{args.ref}^{{commit}}"]).strip()
    subject = run(["git", "-C", ROOT, "log", "-1", "--format=%s", commit]).strip()
    print(f"building {args.ref} = {commit[:8]} ({subject})")

    work = pathlib.Path(tempfile.mkdtemp(prefix="uhc-release-"))
    tree = work / "src"
    run(["git", "-C", ROOT, "worktree", "add", "--detach", tree, commit])
    try:
        build = tree / "build"
        run([cmake, "-S", tree, "-B", build, "-G", GENERATOR, "-A", "Win32"], log=work / "configure.log")
        run([cmake, "--build", build, "--config", "Release"], log=work / "build.log")

        package = [sys.executable, "-I", tree / "tools" / "package_release.py", "--force", "--dxvk", args.dxvk]
        if args.dinput8_only:
            package.append("--dinput8-only")
        print(run(package, cwd=tree).rstrip())

        zips = sorted((tree / "dist").glob("*.zip"))
        if len(zips) != 1:
            fail(f"expected one zip in {tree / 'dist'}, found {[z.name for z in zips]}")
        built = zips[0]
        args.out.mkdir(parents=True, exist_ok=True)
        target = args.out / built.name
        if target.exists() and not args.force:
            fail(f"{target} exists; pass --force to replace it (the new one is in {built}, kept with --keep)")
        shutil.copy2(built, target)
        print(f"\n{target}\n  from {args.ref} = {commit}\n  SHA-256 {sha256(target)}")
    finally:
        if args.keep:
            print(f"worktree kept: {tree} (remove it with: git worktree remove --force \"{tree}\")")
        else:
            subprocess.run(["git", "-C", str(ROOT), "worktree", "remove", "--force", str(tree)],
                           capture_output=True)
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
