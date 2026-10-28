# Developer guide

How to build `UHC.dll`, test it safely, add a feature, and reverse engineer `age3y.exe` the way
this project did. For using the DLL in a mod, see [modding-guide.md](modding-guide.md); for the
internals of each feature, [how-it-works.md](how-it-works.md).

## 1. Build

**Requirements:**
- Windows, with Visual Studio's "Desktop development with C++" workload: MSVC x86 tools and
  MASM (`ml.exe`). This project uses Visual Studio 2026; 2022 should work but was not tested.
- CMake 3.25 or later. The copy bundled with Visual Studio works:
  `<VS>\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe`.
- Python 3, for the tools. The capstone checks in [section 5](#5-reverse-engineering-workflow)
  also need `pip install capstone pefile`, preferably in a virtual environment.

**Commands**, from an "x86 Native Tools Command Prompt" or with full paths:

```
cmake -S . -B build -G "Visual Studio 18 2026" -A Win32
cmake --build build --config Release
dumpbin /exports build\Release\UHC.dll
```

- The game is 32-bit, so configure with `-A Win32`; `CMakeLists.txt` stops an x64 configure on
  purpose. For Visual Studio 2022 the generator is `"Visual Studio 17 2022"`.
- The output is `build\Release\UHC.dll`, linked with the static C runtime, so it needs no
  redistributable.
- `dumpbin /exports` must list `_UHCMain@0`, the exact name the loader asks for.

**Layout:**

| Path | What |
|---|---|
| `src/dllmain.cpp` | Host guard, cfg load, the feature loop. |
| `src/config.*` | The `uhc.cfg` parser. |
| `src/patch.*`, `src/site.h` | Verify-then-patch helpers. |
| `src/features.h` | The feature registry (`kFeatures`) and the handled keys (`kHandledKeys`). |
| `src/features/*.cpp` | One apply function per key or key group. |
| `src/hooks/*.asm` | The MASM hooks; `common.inc` holds `TRACE_ONCE`. |
| `src/unittypes.*` | Extra abstract unit types requested by features. |
| `src/generated/sites.h` | Expected stock bytes, written by `tools/gen_sites.py`. Do not edit it. |
| `tools/` | `gen_sites.py`, the data tools and `re/` (tracers); see [tools/README.md](../tools/README.md). |
| `docs/` | This guide, the [modding guide](modding-guide.md) and the research notes. |
| `examples/` | A complete `Startup\uhc.cfg`. |

## 2. A safe test bed

Never modify the Steam install. Work on a copy:

1. **Copy the game folder**, e.g.
   `robocopy "<Steam>\steamapps\common\Age Of Empires 3\bin" C:\AoE3-UHC-Test /E`.
2. **Replace the copy's `age3y.exe`** with a UHC-patched exe
   ([modding guide, section 1](modding-guide.md#getting-an-exe-with-the-uhc-loader)).
3. **Copy `build\Release\UHC.dll`** next to it, and `examples\Startup\uhc.cfg` into its
   `Startup\` folder.
4. **Start it** any way you like: a double-click, or from PowerShell:

   ```powershell
   Start-Process -FilePath C:\AoE3-UHC-Test\age3y.exe
   ```

   `UHC.dll` makes the exe's folder the working directory, and the log's second line,
   `UHCMain: working directory …`, confirms it.

5. **Read `UHC.log`** next to the exe. Delete it before each run: it is appended.

**Shared profile.** The copy uses your normal user profile
(`Documents\My Games\Age of Empires 3\Users3\<profile>.xml`, a UTF-16 file). A first run of a
copy may reset the resolution there (`optiongrfxres`). Back the profile up before testing.

**Safety checks**, before and after a session:

```powershell
$root = "<Steam>\steamapps\common\Age Of Empires 3\bin"
function Listing { Get-ChildItem -LiteralPath $root -Recurse -File |
    ForEach-Object { "{0}`t{1}`t{2}" -f $_.FullName.Substring($root.Length), $_.Length, $_.LastWriteTimeUtc.ToString("o") } }
Listing | Set-Content steam-before.tsv                        # once, before working
Compare-Object (Get-Content steam-before.tsv) (Listing)       # later: must print nothing
(Get-FileHash "$root\age3y.exe" -Algorithm SHA256).Hash       # must be B1A1DAB7…11D9D
```

Use the same `Get-ChildItem` options both times: `-Force` adds hidden files and makes the two
listings differ.

## 3. Adding a feature, step by step

The worked example is `healNonIdle` (`src/features/heal.cpp`, `src/hooks/heal_hooks.asm`).

1. **Find the code.**
   - Start from strings and cross-references, then decompile ([section 5](#5-reverse-engineering-workflow)).
   - When static reading is not enough, trace the running game. For `healNonIdle`:
     - the hit points field (`unit+64h`) came from a write breakpoint while a monk healed;
     - its writer's call chain led to the heal tick FUN_009E0B53 and its "target busy" check at
       `0x9E0C79`;
     - the first in-game test showed that the tick hook never ran. An execute-breakpoint trace
       then found the automatic target search FUN_009CD865 and its idle test.
2. **Choose the site and check it.** It must be an instruction boundary, no branch may land
   inside the bytes you overwrite, and you must know what is live at the continuation
   ([section 5](#byte-level-checks-with-capstone)).
3. **Add the site** to `SITES` in `tools/gen_sites.py`, with a comment saying what the bytes
   are. Make the range cover the overwritten bytes and the continuation. Regenerate:

   ```
   python -I tools/gen_sites.py "<Steam>\steamapps\common\Age Of Empires 3\bin\age3y.exe"
   ```

   It only reads the exe, and refuses any exe that is not the stock build.
4. **Write the hook** in `src/hooks/<area>_hooks.asm`, following
   [how-it-works.md, section 3](how-it-works.md#3-hook-conventions):
   - `TRACE_ONCE` first;
   - continuations as data dwords;
   - a comment stating the registers on entry and what the hook may clobber.
5. **Write the feature** in `src/features/<area>.cpp`:
   - parse its arguments;
   - `VerifyAll(feature, {&sites::kYourSite, …})`, then `WriteJmp`;
   - log what it did, including `(multiplayer unverified)` for simulation changes.

   Share values with the hook through `extern "C"` globals.
6. **Register it** in `src/features.h`: declare `Apply…`, then add it to `kFeatures` and its
   lowercase key to `kHandledKeys`.
7. **Add the files** to `CMakeLists.txt`. Give the `.asm` a base name that no `.cpp` uses
   (`heal_hooks.asm`, not `heal.asm`): otherwise MASM fails with error A1000.
8. **Build and test:**
   1. check the hook's bytes in the built DLL, with `dumpbin /disasm` or capstone;
   2. smoke test: `UHC.log` says `applied`;
   3. in-game test: the `hook reached` lines appear and the behavior changes;
   4. control test: without the key, the game behaves as in stock.
9. **Document it:**
   - a row in [uhc-address-map.md](uhc-address-map.md), "Beyond upstream";
   - the engine functions in [engine-symbols.md](engine-symbols.md);
   - a section in [modding-guide.md](modding-guide.md);
   - a line in [examples/Startup/uhc.cfg](../examples/Startup/uhc.cfg).

Test data goes in the test copy only. For example, add a marker unit type with
`tools/xmbedit.py add-unittype`.

## 4. Conventions

- **English** for code, comments and documentation.
- **No code from other projects in `src/`:**
  - the original UnHardcoded project has no license;
  - the Wars of Liberty DLL is closed.

  Use them for addresses and behavior only, and verify every address against the stock exe.
- **Opt-in:** every feature is off unless its key is in `uhc.cfg`.
- **Honest status:** each finding in the research docs carries a status (`unverified`,
  `confirmed`, `mismatch`) and its evidence. Observations, inferences and unknowns are kept
  apart.
- **Copies only:** never modify the Steam install.

## 5. Reverse-engineering workflow

### Static analysis: REA and Ghidra

This project used [REA](https://github.com/morluto/rea) (npm package `rea-agents`, 6.7.0) as an
MCP server, with Ghidra as its provider. Any disassembler or decompiler works the same way on
these addresses.

**Setup:**
- Ghidra 12.1.x. REA 6.7 accepts only 12.1; do not upgrade to 12.2.
- JDK 21. On Windows, REA finds Java only through `JAVA_HOME`.
- Environment for the REA server: `GHIDRA_INSTALL_DIR`, `JAVA_HOME`,
  `REA_ANALYSIS_PROVIDER=ghidra`, a long startup timeout (`REA_GHIDRA_STARTUP_TIMEOUT_MS`) and
  enough memory (`GHIDRA_HEADLESS_MAXMEM=8G`).

**Using it:**
- The first analysis of the 11.6 MB exe takes 15 to 30 minutes. Do not cancel it: cancelling
  discards the database.
- On Windows the Ghidra mode is read-only: functions cannot be renamed, so record names in the
  docs.
- Useful operations: string search, cross-references, `resolve_containing_procedure`,
  pseudocode, assembly, batch decompile.
- Large results are saved to a file instead of being shown.
- Export evidence bundles and a snapshot before closing a session; a snapshot replays cached
  queries later.

**Reading the exe:**
- ImageBase is `0x400000`, with no ASLR, so the VAs in the docs are the runtime addresses.
- For `.text`, `.rdata` and `.data`, file offset = VA − `0x400000`.
- Ghidra's pseudocode is analysis output, not source. Check anything important in the assembly.

### Byte-level checks with capstone

Two checks back every patch site in this project. A short script with capstone and the file
bytes does both:
- **Instruction boundary:** decode from each of `site−1` … `site−48`. A correct site is where
  those decodes resynchronize.
- **No branch into the overwritten bytes:** scan the whole `.text` section for `E8`/`E9`/`0F 8x`
  (rel32) and `EB`/`7x` (rel8) branches whose target falls inside `[site, site+length)`.

```python
import struct, capstone
exe = open(r"<Steam>\...\bin\age3y.exe", "rb").read()
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
def code(va, n):                       # .text/.rdata/.data: file offset = VA - 0x400000
    return exe[va - 0x400000: va - 0x400000 + n]
site, length = 0x9CD9C7, 5
for back in (16, 24, 32):              # boundary: these decodes should all land on the site
    print(back, any(i.address == site for i in md.disasm(code(site - back, back + 8), site - back)))
for o in range(0x1000, 0x784000 - 6):  # .text is file 0x1000..0x784000
    va, b = o + 0x400000, exe[o]
    if b in (0xE8, 0xE9):                                   # call / jmp rel32
        target = va + 5 + struct.unpack_from("<i", exe, o + 1)[0]
    elif b == 0x0F and 0x80 <= exe[o + 1] <= 0x8F:          # jcc rel32
        target = va + 6 + struct.unpack_from("<i", exe, o + 2)[0]
    elif b == 0xEB or 0x70 <= b <= 0x7F:                    # jmp / jcc rel8
        target = va + 2 + struct.unpack_from("<b", exe, o + 1)[0]
    else:
        continue
    if site < target < site + length:  # a candidate: confirm it is real code in a disassembly
        print("branch into the site from", hex(va))
```

### Dynamic analysis: hardware-breakpoint tracers

`tools/re/` holds a small debugger, Python with ctypes and no packages. It attaches to the
running game, sets up to four hardware breakpoints and logs who hits them:
- `trace_writes.py`: who writes (or reads) a field;
- `trace_exec.py`: who runs an address, with the registers and a call chain.

Usage is in [tools/README.md](../tools/README.md). The traces behind this project's features:

| Question | Command |
|---|---|
| What moves the shipment point when a Town Center dies? | `trace_writes.py gather.txt hc:1+0x18C hc:1+0x190 --rw` |
| Which code changes a unit's hit points? | `trace_writes.py hp.txt unit:Explorer+0x64` |
| What starts a heal, and does the command predicate run? | `trace_exec.py heal.txt 0x4C6D91=pred-0x41@esi 0x4C6DDD=pred-0x42@esi 0x9E0B53=heal-tick@[ecx+0x10]` |

**Rules:**
1. Start the tracer, then start (or switch to) the game, then play the scenario.
2. Stop a tracer with **Ctrl+C**, or let it run out of time. **Never kill its process:** a
   hardware breakpoint left behind raises an exception nobody handles, and the game crashes.
   This happened once during testing.
3. Only one debugger can attach at a time.
4. A breakpoint on code that runs very often slows the game down while it is attached.
5. A data breakpoint stops after the access, so the logged `after=` address is the
   instruction that follows the writer.
6. The call chain is a heuristic, built from the return addresses found on the stack. Stale
   entries can appear.
7. The tracer reports second-chance exceptions, so a game crash is never mistaken for a normal
   exit.

### Reading game memory

`tools/re/debugger.py` also reads game objects without attaching, which is safe to do next to a
tracer:

```python
import sys; sys.path.insert(0, "tools/re")
import debugger as D
proc = D.Process(D.find_pid())
db = D.database(proc)                                    # [[0xC66234]+0x140]
levels, count = proc.u32(db + 0x60D0), proc.u32(db + 0x60D4)
print([proc.i32(levels + 12 * i + 4) for i in range(count)][:12])   # maxdecksize per HC level
```

`tools/re/inspect_unittypes.py` is a complete example: it walks the unit type table and the
proto bitsets.

**Finding an unknown field.** The hit points field was found by polling the memory of the units
while they fought and were healed, looking for a float that dropped when hit and rose in small
steps while the unit stood still. It was then confirmed with a write breakpoint on that offset.
The same method works for any field whose value you can make change in game.

### Recording evidence

The research notes cite their evidence:
- `ev_…` IDs are REA records, stored locally under `rea/` (not in the repository);
- `cs` means a capstone check on the file bytes;
- traces name the tool and the scenario.

Each entry gives the address, the function and the method, so anyone can rerun it with the
stock exe.

## 6. Making a release

Modders download a zip, so they never need a compiler. The version has a single source,
`project(UHC VERSION x.y.z)` in `CMakeLists.txt`. CMake writes it into `version.h`, which
`src/dllmain.cpp` and `src/version.rc` include. It appears as:
- the first line of `UHC.log`, `UHC.dll x.y.z`;
- the file's Properties → Details.

1. **Bump the version** in `CMakeLists.txt`:
   - the third number for fixes;
   - the second for new features;
   - the first for changes that break existing `uhc.cfg` files or data.
2. **Build:** `cmake --build build --config Release`. Then check the DLL:
   - `dumpbin /exports` lists `_UHCMain@0`;
   - `(Get-Item build\Release\UHC.dll).VersionInfo` shows the new version.
3. **Package:** `python -I tools/package_release.py`. Before writing anything, it checks the DLL:
   - it is 32-bit;
   - it exports `_UHCMain@0`;
   - it carries the version in `CMakeLists.txt`;
   - it is newer than `CMakeLists.txt` and every file in `src/`.

   It then writes `dist\UHC-x.y.z.zip`:

   ```
   UHC-x.y.z\
       UHC.dll
       Startup\uhc.cfg     examples/Startup/uhc.cfg with every key commented out
       README.txt          the modder's quick start
       LICENSE.txt
   ```

   It prints the SHA-256 of the zip and of the DLL, and refuses to replace an existing zip
   unless given `--force`. The game exe is never included: it is Microsoft's binary, and each
   modder patches their own copy.
4. **Test the zip as a modder would:**
   1. unzip it somewhere, then copy the **contents** of its `UHC-x.y.z\` folder into a test copy
      that has a patched exe, replacing its `UHC.dll` and `Startup\uhc.cfg` (the zip's top
      folder is not a game folder);
   2. delete the old `UHC.log`, since the log is appended;
   3. enable a few keys;
   4. start the game, from any folder;
   5. check the log: its first line shows the new version, the next one is
      `UHCMain: working directory <the copy>`, and every enabled key says `applied`.
5. **Publish it by hand** on the repository's GitHub Releases page:
   - a tag `vx.y.z`;
   - the zip as the release asset;
   - notes listing the new and changed keys, with the in-game status column of the README;
   - the two SHA-256 values.

When a key is added, update the release material too:
- `examples/Startup/uhc.cfg`: the template in the zip comes from it;
- the key list in `README.txt`, inside `tools/package_release.py`.
