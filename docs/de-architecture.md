# What AoE3 DE does with threads and loading, compared with legacy

The question behind this page: the Definitive Edition shares its engine lineage with the 2007 game.
Does it use more cores, and how? If it does, could legacy copy the ideas through this DLL? The legacy side
is in [performance.md](performance.md) §9–§10. The game mechanics DE adds over legacy, for WoL's
requests, are in [de-parity.md](de-parity.md).

**Target.**
- `AoE3DE\AoE3DE_s.exe`, Steam build 25969874, game version 100.19.18658.0.
- SHA-256 `31fad98fc4fd82b4b7b3049b131b37be6918022e4637a4075c7ec7a119bd8cab`.
- PE32+ x64, 59 MB.

**Rules followed.**
- The installed copy was read and run offline only.
- No DE code or data is copied into this DLL; only architectural facts are reused.
- The code protection (below) was not studied or bypassed.
- Every statement is marked **[O]** observed (bytes, a listing, or a runtime measurement) or **[I]** inferred.
  Unknowns are listed as such.

**Evidence.** Everything is in `rea/evidence/aoe3de-31fad98f/` (gitignored):
- the runtime CSVs and console logs of three runs;
- the per-question investigation folders, `q1-threads/` and so on.

**Tools.**
- `tools/re/pe64.py` for static work.
- `tools/threadprobe.py` for runtime work: per-thread CPU and names, instruction-pointer sampling, and
  in run 3 a one-off stack read of the busiest secondary thread.
- `tools/gameui.py` to drive the game.

## Summary

- **DE still runs its game on one main thread, and that thread is the bottleneck.**
  - [O] In a busy 8-AI battle it runs at 91–95 % of a core in every run.
  - [O] Its instruction-pointer profile is spread over many functions, among them the obstruction manager
    (pathing and collision).
  - [I] No job type exists for units, AI, pathing, scripts or sync, so the simulation is single-threaded,
    as in legacy. This agrees with Tantalus's statement that the DE code base "runs as a single main
    thread responsible for the world simulation updates, rendering…".
- **DE adds work on other threads.** [O] In the battle view the process uses 2.05–2.17 cores; legacy uses
  about 1.25:

  | Thread | Share of a core | Status |
  |---|---|---|
  | One heavy thread, first read as a render thread; it is the **sound thread** (2026-11-10, below) | 45–61 % | [O] |
  | A 16-thread pool, very likely **PopcornFX particles** | 20–24 % | [I] |
  | Engine job workers ('Worker #%i'), texture-loading threads and services | about 12 % | — |
  | Driver threads | 5–7 % | — |

- **About 21 % of a core goes to a code-protection layer**, in every phase including the main menu.
  - [O] About 42 % of the exe's functions are encrypted on disk.
  - [O] Four threads run from that layer, one of them mostly from private (non-image) memory.
- **Loading is reworked.**
  - [O] Archives are BAR v6. Compressed entries (61,653 of 132,380) are whole-file LZ4 blocks.
  - [I] Such an entry must be read whole, so legacy's 4-byte reads cannot happen for it. Raw entries,
    every `.gr2` model and animation among them, can still be read in small pieces; DE's real read sizes
    are unknown because its archive reader is encrypted.
  - [O] A `TextureLoadingThread` consumer and a cache of 35,443 low-resolution placeholder textures exist.
    [I] Full textures stream in behind those placeholders.
  - [O] A **world asset preloader** exists but ships as a **Beta option, off by default**.
- **For legacy**, see the last section. The ideas that fit a binary patch are the loading ones, and one
  of them is already done (`bufferedFileReads`). The threading ones need source-level restructuring.

## Runtime measurements

**Setup.**
- Offline skirmish: 8 players (me plus 7 Hard AIs), California, "A muerte" (deathmatch, 20,000 of each
  resource).
- 3840×2160, default ("Ultra High" detected) settings.
- The AIs reach Age IV and fight from about 5–6 game minutes.
- `tools/threadprobe.py` read per-thread CPU every second for whole sessions. It opens the process with
  query rights only.
- Runs 2 and 3 also sampled the instruction pointer of the 4 busiest threads at 100 Hz (suspend and read
  the context; no memory read). Run 3 read a few stack snapshots of the busiest secondary thread.

**Per-thread CPU** (% of one core; thread roles explained below):

| Run, phase | Process | Main | Sound thread (first read as render) | PopcornFX pool [I] | Other CRT threads | Protection | Driver |
|---|---|---|---|---|---|---|---|
| 1, main menu (221 s) | 48.6 | 12.6 | 1.8 | 0.6 | 2.2 | 21.3 | 5.6 |
| 1, loading the match (32 s) | 121.7 | 64.3 | 12.4 | 4.9 | 9.3 | 22.4 | 4.9 |
| 1, match 0–6 min (328 s) | 144.8 | 66.9 | 19.3 | 15.8 | 11.6 | 21.4 | 6.5 |
| 1, battle view (167 s) | **217.0** | **94.5** | **60.6** | 20.0 | 11.5 | 20.8 | 5.2 |
| 3, match 0–4 min (220 s) | 126.4 | 56.8 | 15.9 | 13.3 | 11.3 | 20.8 | 5.7 |
| 3, match 4–7 min (146 s) | 191.3 | 88.5 | 35.1 | 23.9 | 12.7 | 21.8 | 6.1 |
| 3, battle view (126 s) | **205.1** | **90.8** | **45.5** | 23.5 | 12.7 | 21.7 | 6.9 |

Legacy, for comparison (performance.md §9, `uhcbench25`, 8 AIs at 25 minutes): main 95 %, skinning
worker 5.6 %, process about 125 %. The GPU was below 15 % in both games.

**Instruction-pointer profiles in the battle view** (run 3, 120 s, about 11,300 samples per thread;
samples include waits):

| Thread | Where it is | Reading |
|---|---|---|
| Main (77 % CPU in this window) | `ZwDelayExecution` (Sleep) 21.7 %; spread over many exe functions; the largest are 3.7 % (encrypted fn 0x106D2D0), 3.3 % (fn 0x10DDE60), 2.8 % and 2.1 % (fn 0xB69F20 / fn 0xB6C800, the **obstruction manager**: "Bad index … in obstruction manager") | [I] the main thread does the simulation and the game-side render work, and sleeps in the FPS limiter fn 0xA4F530 (2026-11-10), which was first read as a wait for a render thread |
| Sound thread (55 % CPU; first read as render) | `ZwDelayExecution` 42.9 %, **`KiUserExceptionDispatcher` 27.0 %**, encrypted fn 0xA31FF0 19.9 % | [O] 2026-11-10: illegal-instruction exceptions at fn 0xA31FF0, dispatched through the protection's hook (below) |
| Protection (21 % CPU) | 94 % in private executable memory (`?+0x2B0`), the rest in the 0x2140000–0x2320000 region | [I] protection runtime |
| PopcornFX pool [I] | 99.9 % `ZwWaitForSingleObject` per thread | many threads, each mostly waiting |
| NVIDIA driver | 94 % waiting; `NtGdiDdDDISubmitCommandToHwQueue`, `NtDxgkSubmitPresentToHwQueue` | the driver's submission thread |

**Why the busiest secondary thread was first read as the render thread** (refuted on 2026-11-10, see
"Runtime, 2026-11-10" below: it is the sound thread).
- **[O] Its stack** (run 3, five snapshots), outermost first:
  1. protection fn 0x2227DA8;
  2. CRT `thread_start` (return 0x16AB354);
  3. the engine thread trampoline fn 0x1B72140 (return 0x1B7219C);
  4. **fn 0x7A9040**, a plain wrapper that calls the encrypted loop fn 0x7A93E0;
  5. CRT condition-variable waits (fn 0x167CAAC, fn 0x1684B2C), into `ntdll`.
- **[O] The code around fn 0x7A9040** is the D3D11 render module: `render\d3d11buffer.cpp` (fn 0x7A29A0),
  `render\d3d11constantbuffer.h`, DDT texture loading (fn 0x792A70), and `TextureLoadingThread` (fn 0x72EFE0).
- **[O] Its CPU follows what is on screen.** In run 1 it went from 19 % with the camera on my base to 61 %
  over a battle.
- **[O] Meanwhile the main thread sleeps** 22 % of the time.
- **[I] Conclusion (October, refuted).** A dedicated render thread, pipelined with the main thread. The code
  near fn 0x7A9040 is a proximity argument only: deeper stacks show DirectSound and MP3 decoding on this
  thread, and every D3D11 call on the main thread.

## Runtime, 2026-11-10: render, frame and threads

Same build, the same offline 8-player deathmatch on California, 3840×2160. The profile caps the game at
`optionfpslimit` 60, with vsync off. Every number is from a focused window. Evidence:
`rea/evidence/aoe3de-31fad98f/runtime-20261110/` (CSVs, stack samples, symbol maps, the scripts, and the
in-memory listings `mem-fn-*.txt`).

**Method.** Everything ran from outside the process: `threadprobe.py`, plus a sampler that suspends a
thread, copies its stack, resumes it, and walks the copy with dbghelp. A 1 kHz main-thread probe matched the
return addresses of the frame steps. System DLLs were resolved with Microsoft's public symbols.

**Frida was not attached** [O]. ntdll's `Wow64PrepareForException` pointer, null in a plain 64-bit
process, points to RVA 0x2206DC9 in the protection region. Frida's x64 Windows exception handling uses
the same pointer. Nothing was loaded into the process.

**Main thread** [O]:
- **It does every D3D11 call** on the immediate context, and `IDXGISwapChain::Present` (through the Steam
  overlay's hook). D3D11 and DXGI are 2.4 % of its samples, about 0.4 ms per frame.
- **No deferred context or command list** was seen on any thread, in about 21,000 samples.
- **Its frame is** fn 0xA4D4B0 → fn 0xAB0710 (the update fn 0x124B1A0 → mode-stack update fn 0x151340,
  then the render fn 0xAB14F0), then the FPS limiter fn 0xA4F530.
- **In a large battle** (30 s, 1,772 frames): 59.1 fps. Frame time: mean 16.9 ms, p99 25.0, max 35.4.
  Per frame: update 9.0 ms, render 4.1 ms, sleep 3.5 ms.
- **Inside the render:**
  - mode render fn 0xAB1210 → fn 0x151780;
  - scene draw fn 0x749DC0 (draw issuer fn 0x76A7D0);
  - UI fn 0xAAD710;
  - PopcornFX runtime fn 0x779440 (`popcornruntime.cpp`);
  - Present wrapper fn 0x756830.

**The FPS limiter fn 0xA4F530** [O, decrypted in memory]:
- It applies `optionfpslimit`, raising values from 0 to 30 up to 30.
- When the window is not active the cap is 15 fps, and when minimized 5.
- It calls `Sleep(1)` until 2 ms are left, then spins on `Sleep(0)`.
- So the October runs' 22 % main-thread sleep was this limiter, not a wait for a render thread [I].
- Losing focus halves the main thread's CPU. Another window took the foreground several times during
  these runs, and those intervals were dropped.

**The sound thread** (CRT `thread_start`, fn 0x7A9040 → loop fn 0x7A93E0) [O]:
- It calls `IDirectSound::CreateSoundBuffer`, decodes MP3 through ACM (`l3codeca.acm`) and reads files.
- Its CPU follows battle noise: 11–20 % of a core, 75 % in a large battle.
- 14–42 % of its samples are inside `KiUserExceptionDispatcher`, handling `0xC000001D` (illegal
  instruction) at fn 0xA31FF0+0 and +0x63. That function is encrypted on disk and is called from the decode
  path fn 0x7AC520 → fn 0xA323F0 → fn 0xA32410.
- [I] Those faults are how the protection runs that function, so its cost lands on sound, not on
  rendering. How the protection works was not studied further.

**Other threads** (large battle, CPU per 16.9 ms frame) [O]:
- PopcornFX pool [I], 16 threads: 5.7 ms. The main thread wakes them with a semaphore from fn 0x779440.
  Most of their busy samples fall in the main thread's next update [I: asynchronous particles].
- Engine and CRT workers: 2.3 ms. The main thread joins engine jobs inside the scene draw
  (fn 0x76C4F0 → 0x1B74E30).
- Protection: 2.2 ms.
- NVIDIA driver: 1.3 ms. That is about 55 driver threads, almost all waiting.
- One CRT thread polls `D3DKMTQueryStatistics` (fn 0x75C740), [I] a VRAM monitor.

## Static findings

About 42 % of the functions (47,892 of 114,087; about half of the `.text` bytes) are **encrypted on disk**.
- [O] Their bytes contradict their own unwind information and have the entropy of random data.
- [O] Plaintext code calls encrypted functions directly, and `WinMain` itself (fn 0xC3910, called from the
  CRT at 0x165A321) is encrypted. The image has no TLS callbacks. [I] The code is therefore restored
  before `WinMain` runs, during CRT initialization or from outside the exe's own code.
- [O] 302 of the 649 import slots have no user in plaintext code, among them `PeekMessageW`,
  `DispatchMessageW`, `D3D11CreateDevice`, `SteamAPI_Init` and almost the whole Win32 thread-pool family.
  The message loop, device setup and most thread-pool use are hidden.
- [O] The protection runtime lives around 0x2140000–0x2320000. It resolves Windows APIs by FNV-1a hash
  (86 resolved), among them `NtCreateThreadEx`, hardware-ID and window-enumeration APIs.
- [I] It is a commercial anti-tamper layer; the vendor is not identified.
- [O] Unlike legacy, DE uses ASLR (DllCharacteristics 0x8160). Addresses on this page are RVAs.
- **Consequence:** a missing reference means "no reference in plaintext code". It does not mean dead
  code. The scheduler internals, every job submitter, most simulation code and the preloader are not
  readable. Verification status of the findings below: see "Verification".

**Threads (Q1)** [O unless marked]:

| Start (RVA) | Count | Procedure | Name | Role |
|---|---|---|---|---|
| 0x165A394 (entry point) | 1 | mainCRTStartup → WinMain (encrypted) | none | main thread; the engine records its id (IsMainThread 0x1B74860) |
| 0x16AB304 (CRT `thread_start`) | 17 | std::thread / engine trampoline 0x1B72140 | none in retail | includes the sound thread (first read as a render thread), the 'Worker #%i' engine job workers (seen parked on their semaphore through fn 0x1B73FD0 → 0x1B8DA60) and the texture loaders; std::thread services (Steam init, mod manager, HTTPS GET, XSAPI, 1DS telemetry, a 30–45 s heartbeat) |
| 0x1E3E5E0 | 16 (one per logical CPU) | encrypted; a thread class tied to PopcornFX vtables and its CPU-set builder 0x1F77920 | none | [I] PopcornFX worker pool |
| 0x1C92BD0 | 7 | Havok trampoline | 'HavokWorkerThread' (SetThreadDescription, Havok only) | Havok physics workers, nearly idle |
| 0x17D2EB0 | 5 | std::function runner in RelicLink code | none | [I] online networking |
| 0x424E80 | 1 | next to AVUI::Thread | none | [I] the UI library's thread |
| 0xA54F10 | 1 | startup module (amain.cpp) | none | [I] loading-related; one 88 % burst |
| 0x218A288, 0x21D47EC, 0x21D8F90, 0x22A70D8 | 1 each | protection region | none | [I] protection |

Engine thread names ('Worker #%i', 'TextureLoadingThread', 'SchedulerThread') only go to a RAD Telemetry
hook, which does nothing without `rad_tm_win64.dll`, and the install does not ship it. That is why
`GetThreadDescription` shows nothing.

Other thread facts [O]:
- 14 `std::thread` entry types are compiled in; only two of their creation sites are in plaintext
  (XSAPI, fn 0x1978FD0, and 1DS telemetry, fn 0x249B8B0). The six Steam-glue ones are short-lived helpers.
- The amain.cpp `std::thread` (fn 0xA4BDC0) sleeps a random 30–45 **seconds** per loop.
- libHttpClient calls the Win32 thread pool directly (`SetThreadpoolTimer` at 0x8A5F03). PPL tasks use the
  pool through `CreateThreadpoolWork`, which the runtime resolves by name.
- The exe does not import `BinkStartAsyncThread`, so it does not ask Bink for decode threads. Audio is
  loaded dynamically (`dsound.dll`, `DirectSoundCreate8`) by hidden code.
- The 16-thread pool at 0x1E3E5E0 is tied to PopcornFX by its surroundings, not by a reference to its
  start address, which no plaintext code has. A vtable of its thread class (no RTTI) sits between the
  '(User Thread Pool)' and 'PopcornFX' strings, and code in the PopcornFX range (0x1F51AC0–0x1F52D60)
  calls into that class (0x1E3C400). Whether PopcornFX also feeds the engine's job workers is unknown.

**Job system (Q2).**
- [O] The engine has its own scheduler: a 0xA0-byte singleton at .data 0x3640080 and 'Worker #%i' threads
  at below-normal priority.
- [O] Each worker has a CRITICAL_SECTION, three deques and a semaphore.
- [O] Jobs are polymorphic, with state 1 → 8 → 0x10, and fork/join goes through a counter plus a
  manual-reset event.
- [O] RTTI has exactly **8 job classes**:
  - terrain data generation ×3, including a parent job with 36 child jobs;
  - terrain mesh tiles ×2;
  - the model system / particle-system instances ×1;
  - render ×1, whose strings sit between `rendereffectinfo.cpp` and `debugprimitives.cpp`. It is not
    shown to be PopcornFX's;
  - BWorld ×1, encrypted.
- [O] None of them is in the unit, unit action, squad, AI, pathing, XS or sync source blocks.
- [O] Every visible fork/join site splits its work into exactly 36 jobs. [I] The split is fixed, not
  derived from the core count.
- [O] The scheduler is created by fn 0x1B74DA0(int n), which has no visible caller. [I] `n` is the best
  candidate for the worker count.
- [I] Submitters push into a central queue that the 'SchedulerThread' hands out to the per-worker
  queues (inferred from the destructor tables).
- [O] The fibers in the exe belong to OpenSSL's ASYNC code, not to the engine.
- [O] At runtime the workers were nearly idle in a battle: they are a few % together.

**World asset preloading (Q3)** [O unless marked]:
- **What it is.** `worldassetpreloading.cpp` is linked. The switch is option index 0x43,
  `OptionEnableAssetPreloading` (bool, a graphics-profile option, **default false**), under
  Options › Graphics › "Beta Settings".
- **What it does.** It shows its own "Asset Preloading (Beta)" screen with two status messages, in an
  order that is not established:
  - "Finding assets to load", whose scope is unknown;
  - "Loading static assets": 85 assets from `Data\static_asset_collection.xml`, of which 55 are animxml
    (props, projectiles, flags, minutemen) and 30 are textures.

  It logs `WorldAssetPreloadingTime %fms`.
- **The encrypted code is live.** DE's log (`%USERPROFILE%\Games\Age of Empires 3 DE\Logs\Age3Log.txt`)
  prints lines whose format strings have no plaintext reference, e.g. "Game startup complete (18.89 sec)",
  plus "CPU Cores: 16".
- **Unknown.** The preloader's code is encrypted, so these are unknown: what discovery walks, whether it
  runs on a worker, and its memory cost (the UI warns about RAM).
- [I] Shipping it as opt-in Beta suggests the developers judged the memory and load-time cost too high to
  make it the default.

**Loading and file I/O (Q4)** [O unless marked]:
- **Archives.** They are BAR version 6 ('ESPN', 64-bit offsets; `UI\UIResources1.bar` is 5.26 GB). Legacy's
  TAD archives are version 2. Art archives are aligned to 2 KB. The 43 archives hold 132,380 entries:

  | Kind | Entries | Stored size | Notes |
  |---|---|---|---|
  | 'alz4' | 61,653 | 30.25 GB | one LZ4 block per file; [I] read as a unit |
  | raw | 44,493 | 15.92 GB | every `.gr2` (16,465), `.png`, `.precomp` |
  | flag 2 | 26,234 | 2.53 GB | `Sound.bar`, `Sound-es-ES.bar` |

- **Decompression.** The LZ4 match-copy helper (fn 0x222D60) is plaintext, but nothing visible calls it.
  [I] The decode loop is encrypted.
- **Reads.** They are synchronous `ReadFile`, with no overlapped, mapped or IOCP file I/O in plaintext
  code. Stdio-buffered CRT reads (4 KB) and whole-file reads in 2 MB / 64 KB pieces are visible.
  - DE keeps a plaintext Granny reader (fn 0x142760) that seeks and then reads the caller's size on every
    call. Whether archive content goes through it is unknown.
  - The archive reader itself is encrypted, so DE's real read sizes are not known.
- **Texture streaming.**
  - `TextureLoadingThread` (fn 0x72EFE0, at most 2 threads) consumes a locked request queue.
  - `Data.bar` ships `streamingdata\TextureCache.cache`: 35,443 placeholder textures of 32×32 pixels or
    less, the full textures being mostly 2048×2048, plus 83 per-scenario `.texprimer` files.
  - [I] Full textures stream in the background. Plaintext code does not show when the requests are
    queued (map load or play).
- **Removed settings.** Legacy's `demandLoadMeshes` and `megaPostLoadForceTextures` no longer exist.

## Legacy vs DE

| Aspect | Legacy 2007 (`age3y.exe`) | DE (`AoE3DE_s.exe`) |
|---|---|---|
| Simulation | main thread | main thread [I] |
| Rendering | main thread (D3D9) | main thread (D3D11 immediate context, Present on main) [O, 2026-11-10] |
| Main thread in a late battle | 95 % | 91–95 % |
| Process CPU in a late battle | ~1.25 cores | ~2.1 cores (about 0.2 of it protection) |
| Helper threads doing game work | 1 skinning worker (~5 %) | sound thread (11–75 %), PopcornFX pool (14–34 %), job workers and texture loaders (~6–14 %) |
| Archive reads | one `ReadFile` per 1–16 bytes, about 10 M calls per session | whole LZ4 entries for compressed files [I]; raw entries (all `.gr2`) unknown |
| Texture loading | synchronous, on first use | background streaming behind placeholders [I] |
| Model/animation loading | synchronous, on first use, inside the simulation (legacy stutters) | not visible (encrypted); an opt-in Beta preloader exists |
| Code protection | none | about 42 % of functions encrypted; about 21 % of a core at runtime |

## What legacy could take from DE

Each candidate is bounded by the legacy numbers of performance.md §9: simulation 44 %, render 56 % on one
thread, and stutters from first-use loads.

1. **Whole-file / buffered archive reads.** **Done:** `bufferedFileReads`.
   - DE's closest equivalent is the whole-entry LZ4 design of its compressed entries.
   - In legacy it took frames over 100 ms from 11 to 3 and cut 14 s of `ReadFile` per session.
2. **Preload unit models and animations at load time.** DE ships this as an opt-in Beta.
   - In legacy it would target what is left of the stutters: granny building first-use data, about
     0.4–0.6 s per 150 s.
   - It needs the legacy visual-load entry (§9 chains 0x487A21 … 0x58EC9C) and a list of what to load,
     for example every proto of the civilizations in the match.
   - Its costs are memory (legacy has a 2 GB limit; LAA is possible) and a longer load.
   - **Multiplayer safety must be checked.** If load order assigns IDs that the simulation sees,
     preloading could desync players with different settings.
   - **Candidate.**
3. **Background texture streaming with placeholders.** Not measured as a legacy problem: texture loads
   did not show up in the stutter profiles. It would need a data pipeline (placeholder cache), not just
   a patch. **Not recommended.**
4. **A render thread pipelined with the main thread.** DE does not have one (2026-11-10): the half core
   first credited to it is sound decoding.
   - Legacy's renderer reads live simulation objects (performance.md §9), so this needs a copy or
     double-buffering of render state the 2007 code was never built for.
   - It is far beyond a binary patch. **Not feasible.**
5. **A job pool for terrain, particles and model work.** In DE these jobs are a few % of a core in
   battle; legacy has no PopcornFX or job-based terrain, so there is nothing to gain. **Not worth it.**

## Verification

The static findings come from four investigator agents, one per question. For each question an
independent verifier agent re-derived every finding from the bytes. Runtime numbers come from three runs
on 2026-10-28 and agree across runs to within a few points.

**`threadprobe.py` was validated on legacy**, where `perfprobe.py` already gives per-thread CPU through a
different code path. Both recorded the same process during the same 150 s (`uhcbench25`, run
`bench-threadval` in `rea/evidence/age3y-b1a1dab7/`, 2026-10-28):

| Thread (legacy) | `perfprobe` | `threadprobe` |
|---|---|---|
| Main thread | 94.4 % | 94.4 % |
| NVIDIA driver thread (`nvd3dum.dll`) | 26.9 % | 26.9 % |
| Skinning worker | 2.5 % | 2.6 % |
| Whole process | 124.7 % | 124.7 % |

| Question | Findings | Confirmed | Refuted | Unclear |
|---|---|---|---|---|
| Q1 threads | 23 | 21 | 1 | 1 |
| Q2 job system | 18 | 16 | 2 | 0 |
| Q3 preloading | 23 | 20 | 1 | 2 |
| Q4 loading and I/O | 21 | 18 | 1 | 2 |

What the verifiers changed on this page:
- **Refuted.**
  - The amain.cpp thread sleeps 30–45 seconds, not milliseconds (Q1).
  - "No code calls the Win32 thread pool" is wrong: libHttpClient calls `SetThreadpoolTimer` (Q2).
  - "Two `std::thread` types" is wrong: there are 14, with two visible creators (Q2).
  - "The LZ4 decoder tables are unused": the plaintext helper fn 0x222D60 indexes them relative to the
    image base, a form the investigator's search missed (Q4).
  - "The options code has only setters": plaintext getters exist. The narrower claim stands: no
    plaintext code reads option 0x43 by its index (Q3).
- **Unclear, kept as inferences.**
  - That the render job class belongs to PopcornFX (Q1).
  - That texture streaming happens during play rather than at load (Q4).
  - That DE's reads are whole-entry: true only for compressed entries (Q4).
  - Two details of the preloader's options path and the order of its two steps (Q3).
- **Added from the verifiers' own checks:** the IAT census, WinMain being encrypted, ASLR, the archive
  breakdown, the 36-job splits and the scheduler's integer parameter.

Every finding and verdict, with its evidence, is in
`rea/evidence/aoe3de-31fad98f/static-findings-and-verdicts.json`; the scripts behind them are in the
`q1-threads/`, `q2/`, `q3/`, `q3-verify/` and `q4/` folders next to it.

## Unknowns

- The engine worker count and how it is chosen. The scheduler's creator is encrypted; its integer
  parameter is the best candidate.
- When texture requests are queued (map load or play), and how DE reads raw archive entries such as
  `.gr2` models.
- The preloader's discovery scope, thread and memory cost.
- Whether DE also loads models and animations synchronously on first use.
- D3D11 calls per frame and the GPU queue depth (frames in flight): they need in-process hooks, which
  the protection's exception hook rules out for Frida (below). Frame times are known only to 1 ms, from the
  phase probe.
- Whether DE's simulation ticks at a fixed rate apart from frames, and what fn 0xA31FF0 computes for the
  sound thread.
