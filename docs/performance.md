# Performance: what limits CPU and GPU use

What in the stock `age3y.exe` (`b1a1dab7…`, see [binaries.md](binaries.md)) decides how much CPU and
GPU the game uses. It was written for the "late-game lag and stutter" investigation of 2026-10-28.

§1–§7 are **static** (Ghidra through REA, plus capstone on the file bytes) unless a row says otherwise.
§8 and §9 are runtime measurements on the test bed.

**Evidence**
- REA records are in `rea/evidence/age3y-b1a1dab7/bundle-perf-20261028.json` (28 records). They are cited
  by ID prefix, e.g. `ev_3f571458…`.
- `cs` = capstone 5.0.6 over the file bytes. File offset = VA − 0x400000 for `.text`/`.rdata`/`.data`.
  - The scans searched for 4-byte VAs and disassembled windows around each hit.
  - They were run from stdin, so no script is saved.
- Function names are Ghidra's `FUN_<va>`. Roles are inferred from the code and are not original names.

## Summary

- **No artificial cap in a running match.**
  - There is no frame limiter, no CPU affinity and no non-zero sleep in the frame path.
  - The timer resolution is 1 ms, and vsync is off by default.
- **One main thread does the work.** It runs the simulation, the AI, rendering and all Direct3D 9 calls.
  This matches the DE developers' description of the engine they inherited
  ([Tantalus, 2025](https://forums.ageofempires.com/t/tantalus-dropping-engine-works-on-3de-aomre/275456)).
  - In single player a sim update covers the real time elapsed, up to **100 ms**.
  - When a frame takes longer than that, game time falls behind real time. That is the late-game "lag".
- **Only one helper thread does game work.** It deforms (skins) animated meshes. While the main thread
  flushes the queue, the helper is told to stop taking jobs.
- **The Direct3D 9 device adds overhead on that main thread.**
  - It is always created with `D3DCREATE_MULTITHREADED`, and with MIXED or SOFTWARE vertex processing.
  - It always has one back buffer, so with vsync on it is double-buffered.
- **The GPU is not capped by a quality profile.** An RTX 4090 gets the best stock profile (`geforce fx 6800`, SM3 + FP16).
- **Measured in a late 8-AI game (§8):** the main thread runs at about 95 % of one core, 77 % of it in the game's own code.
  The GPU sits at 10–13 % even at 4K.
  - DXVK lowers FPS by 28 % there, and by 14 % in §11's procedure (2560×1600); at 720p it is 6 % faster.
    With `d3d9.cachedWriteOnlyBuffers = True` it is 14–18 % faster than stock at every resolution tried (§11).
  - Skinning and Direct3D are too small a share for a DLL feature to win much.
- **Split of a late-game frame (§9, stack sampling):** update (simulation) 43.5 %, render 55.6 %. The game's
  own timers agree: 4.3 ms and 5.4 ms per frame.
  - The simulation must stay on one thread for multiplayer.
  - The render-side work that could move runs inside the per-unit draw calls, so moving it means restructuring
    exe code for at most about +30 % FPS. No multi-core change is worth its risk.
- **The stutters (about 4 per minute over 100 ms) are file loads inside the simulation (§9).**
  - 90 % of their samples are in the world update.
  - Their leaves are `ZwReadFile` (48 %) and granny (28 %).
  - The game's file reader issues one unbuffered `ReadFile` per 4-byte read.
- **`bufferedFileReads` fixes the reading part (§9, A/B; multiplayer-safe):**
  - frames over 100 ms dropped from 11 to 3, and stutter time from 2.3 s to 0.9 s per 150 s;
  - time in `ReadFile` per session fell from 14.9 s to 1.0 s, which also speeds up loading.
  - What remains is granny building the newly loaded data.
- **Multi-core or D3D11 (§11, 2026-11-10):** all Direct3D 9 calls cost 0.49 ms of a 4.96 ms frame, so a D3D11
  renderer alone gains at most about 11 %; dgVoodoo's D3D11 path lost 5–8 %. Overlapping update and render
  could give up to about +80 %, but the render writes into simulation objects and the simulation calls into
  render objects. The particle update (0.54 ms) looked like the one self-contained piece that could move to a
  worker. The safety check for that (§11, "particleWorker: safety check") found it is not self-contained: pass 0
  draws the particles it updates, and both share the game's pose code, which writes global buffers. Not built.

## 1. Frame pacing and timers

| What | Where | Evidence |
|---|---|---|
| `timeBeginPeriod(1)` at startup | FUN_005aa825, `push 1` 0x5AA842, call 0x5AA84E | `ev_d4419de7…`, cs |
| `timeEndPeriod(1)` at shutdown | FUN_0057d028, `push 1` 0x57D07F, call 0x57D081 | `ev_d4419de7…`, cs |
| No `SetProcessAffinityMask` / `SetThreadAffinityMask` import | import table | cs |

All 7 `Sleep` sites (IAT 0xB84324) and all 20 `SleepEx` sites (IAT 0xB84364) were classified, including
the register-loaded calls (`mov reg,[IAT]` … `call reg`):

| Wait | Where | Context |
|---|---|---|
| Sleep(100) loop | 0x643455 | Startup: waits for the loading-screen thread (gated by `noIntroCinematics`). |
| Sleep(100) loop | 0x5A2105 (`edi` loaded at 0x5A20D6) | Inside the loading-screen thread proc 0x5A1FF1. It ends with `ExitThread(1)` once FUN_0075cdf5 sets `[0xC6623C]`/`[0xD6F514]`. |
| Sleep(100) loop | FUN_0075cd59 | Waits up to 2400 × 100 ms for that thread to exit. |
| Sleep(10) loop | 0x6E7E6B, in FUN_005979f3 | Only when a DirectSound buffer reports BUFFERLOST: retries while Restore returns 0x88780096. |
| Sleep(1) loop | FUN_008a34fa | The credits mode's own frame limiter: frame time ≥ recent max − 5 ms, clamped 10–100 ms. It is slot 4 of vtable 0xB96D54. `ev_ae1c5114…` |
| Sleep(20) loop | 0x402312, in FUN_00402135 | Body of the sound-mixer thread (proc 0x5FF655, TIME_CRITICAL), timed with QPC. |
| Sleep(25) | 0xB68981 | ZoneStats thread cleanup. |
| SleepEx(100) | 0xB59FA7, 0xB5A011, 0xB5A0D2 | Periodic loop of the network background thread 0xB59FD7. |
| SleepEx(1/5) | 0xA9FCF3, 0xAA0C9B, 0xAA0D66, 0xAA0DC7 | Network: send-all retry after a partial send (FUN_00a9fcb4), and loops in FUN_00aa0692 (run from a destructor). |
| SleepEx(1) loop | FUN_00771a3a | Waits up to 30 s for outstanding ESO tasks. Reached only from the virtual method FUN_00634072; looks like a leave/exit flush. `ev_c25c71f6…` |
| SleepEx(0,1) spin | FUN_00b5a3f2 (callers 0xA25805, 0xA2582F) | Spins while the network singleton `[0xD98544]` is busy (byte `+6`, held by the background thread around its periodic work). **On the main thread during an online match, this would be a stutter source** (runtime check pending). |
| SleepEx(0,1) | 0x63DE6A, 0x6B61E4, 0xA1C194, 0xA2D3EB, 0xA2D475, 0xA2D4EC, 0xAA74A7, 0xAA75AF, 0xAA75FD, 0xB59F87, 0xB5A2A3, 0xB5A426 | Zero-ms yields after subsystem work and in socket retries. |
| SleepEx(0,1) | 0x57D238, 0x57E1A3 | Shutdown (FUN_0057d0e6) and a destructor (FUN_0057e105). `ev_d4419de7…` |

None of the non-zero waits is tied to the main thread's per-frame path. Two static candidates were left
for a runtime check (FUN_00771a3a, FUN_00b5a3f2). Neither shows up in the single-player late-game samples of
§9. FUN_00b5a3f2 concerns online play, which has not been measured.

The one main-thread stall that is visible statically is the skinning flush in §4. It busy-spins on
`GetTickCount` with no pause, for up to 5 s.

## 2. Simulation step

FUN_00455d91 computes the length of each sim update (`ev_d5e75398…`):
- **Single player, default:** the update length is the real time since the last update, capped at
  **100 ms** and scaled by game speed (`[world+120h]`). A one-off update of 30 ms applies when
  `[world+6918h] == 1`.
- **`fixedUpdate` defined:** fixed-length updates. Without `RunAsFastAsPossible`, the next one waits
  until its interval has elapsed. `MinRandUpdate` together with the next variable (ID store 0xD993A8)
  randomizes the interval (0x422648).
- **Multiplayer** (`[[C66234h]+934h]` type 2) and recorded-game playback take other branches. Playback
  asks the recording for the length and caps it at 100 ms.

The cap means that when a frame takes longer than 100 ms, game time falls behind real time.

These switches change the simulation and are not candidates for a multiplayer-safe feature.

## 3. Threads and priorities

| Thread | Created by | Priority | Evidence |
|---|---|---|---|
| Main (sim, AI, render, D3D) | process | normal | — |
| Skinning worker FUN_004058bf | FUN_005d6b8a, through the CRT wrapper FUN_0062486f | normal | `ev_7c105482…`, `ev_8dd8ca8e…` |
| Sound mixer (proc 0x5FF655, body FUN_00402135, Sleep(20) loop) | FUN_0052928e, through BThread::start 0x527CFF | TIME_CRITICAL (`SetThreadPriority` 0x5295A5) | `ev_d4419de7…`, cs |
| Network background (LAB_00b59fd7, SleepEx(100) loop) | FUN_00b5a3f2, through 0x527CFF | TIME_CRITICAL | `ev_7c105482…` |
| Loading screen (proc 0x5A1FF1) | FUN_00539059, `CreateThread` at 0x539101; only **with** `noIntroCinematics` | normal; exits after loading | `ev_d4419de7…`, cs |
| ZoneStats (`CThread` / `CReportThread` / `CQueryThread`) | FUN_00b68694 | — | `ev_7c105482…` |

- FUN_00a4806c is a one-shot TSC-frequency measurement. It raises the process to REALTIME and the thread to
  TIME_CRITICAL around a 5 s semaphore wait, then restores both. The result is cached in `[0xDD6A10]`.
- `deformerdlly.dll`, `granny2.dll` and `RockallDLL.dll` create no threads. `binkw32.dll` does, for video.

## 4. Skinning (mesh deformation)

**Gate chain** (`ev_5ac67504…`, `ev_fd6ed5da…`, cs):
1. FUN_0054edaa, called from the renderer ctor FUN_0054ef1e:
   - it sets `MT = !defined(singleThreadedBatcher) && SYSTEM_INFO.dwNumberOfProcessors > 1`;
   - it calls FUN_0054ed40 twice: `(renderer+8EE4h, index 0, MT)` and `(renderer+9294h, index 1, 0)`.
     FUN_0054ed40 stores `+3A8h` = index and `+3ACh` = MT, so the first batcher's flag lands at renderer+9290h.
   - The ID it tests comes through `[0xD9076C]`, which a static initializer (0x56FBD7) sets to `&id(singleThreadedBatcher)` = 0xD9982C.
2. A one-time init at 0x46DCA3 (flag byte `[0xD6F488]`, cold code at 0x5D6B53) calls FUN_005d6b8a only
   when `renderer+9290h != 0`. It also sets the function pointers `[0xC674FC] = 0x4157DB` and
   `[0xC67508] = 0x40F29A`.
3. FUN_005d6b8a creates **one** thread, FUN_004058bf. A second call does nothing while
   `[0xC674F8] != -1`. If thread creation fails, the cold path at 0x6E6CC0 closes the event and deletes
   the CS.

**Queue globals**

| Address | Role |
|---|---|
| 0xC674B8 | Auto-reset event that wakes the worker (`CreateEventW(0,0,0,0)`). |
| 0xC674C8 | `CRITICAL_SECTION` guarding the queue. |
| 0xC674C0 | Byte: workers may take jobs. Set to 1 at init. |
| 0xC674EC | Byte: quit. Only ever written 0, so the worker is never stopped and dies with the process. |
| 0xC674F0 / 0xC674F4 | Job count / next job index. Count cap 0x100. |
| 0xC67500 | Jobs finished by the worker (`InterlockedIncrement`). |
| 0xC67504 | Matrix scratch fill, in `__m128` units. Cap 0x5000; the buffer is at 0xD0E620. |
| 0xC69398 | Job array, 0x14 bytes per job: `{deformer, bones/0xD0E420, matrices, out verts, format}`. |
| 0xC692DC | Byte: asynchronous deformation allowed. Initialized to 1 in `.data`; no instruction writes it. |
| 0xC692E0 / 0xC692E4 | Counters of jobs run on the main thread / by the worker. |

**Flow** (`ev_fda43e73…`, `ev_8dd8ca8e…`)

- **Producer FUN_0040b65e** (the deformer's deform call), when `[C692DC]`, the caller's async flag and
  the worker all hold:
  - it flushes first if the queue is full or the scratch would overflow;
  - it copies the bone matrices to the scratch when needed;
  - it appends the job under the CS and calls `SetEvent`.
  - Otherwise it deforms synchronously on the calling thread, so the main thread and the worker already
    run the job code concurrently.
- **Worker FUN_004058bf:**
  - sets MXCSR FTZ;
  - waits on the event (250 ms timeout);
  - takes jobs under the CS while `[C674C0] != 0`;
  - runs FUN_0040b54f(job) with ECX = the job's deformer;
  - counts each finished job.
- **Flush FUN_0040599c.** Callers (`ev_0c5ce832…`, cs):
  - the functions 0x4075AB, 0x40B65E, 0x46C210, 0x589402 and 0x590A06 (call sites include 0x4157DB,
    0x46C216, 0x4F0C86, 0x589411 and 0x590A0A);
  - the producer's flush-when-full at 0x6E6C89;
  - a renderer callback 0x5ADF07 (a `jmp` to it, registered through 0x602200).

  Its steps:
  - it saves `[C674C0]`;
  - it runs the remaining jobs itself, storing `[C674C0] = 0` before each one (0x4606C0) so the
    worker takes no new ones;
  - it restores the flag (0x405A17);
  - it spins on `GetTickCount`, with no pause or yield and a 5 s timeout, until worker + own jobs = count;
  - it resets count, index, done and scratch under the CS;
  - it clears FTZ (`and ah,7Fh`) instead of restoring MXCSR.

  So the worker runs in parallel only between a `SetEvent` and the next flush.
- **Job FUN_0040b54f** dispatches on the vertex format (1 NoTan, 2 full, 3 PosOnly) to the
  `BFastMeshDeformer::dllDeformer*SSE` exports of `deformerdlly.dll`.

**Reentrancy of the deformer DLL (cs, evidence not proof).**
- The 9 exports are `jmp` stubs.
- Following direct jmp/call from them reaches 34 functions. None of them stores to an absolute address in the
  DLL's writable `.data` (0x1000D000, 0x14F8 bytes).
- The scan is linear and stops at the first `ret`.

## 5. Direct3D 9

The renderer object is ECX in the functions below. Its global is `[0xC66044]` (inference from
FUN_005d6b8a and FUN_00539059).

| Offset | Field | Evidence |
|---|---|---|
| +44Ch | Device window HWND | FUN_0054e60b |
| +488h | `IDirect3D9*`, from `Direct3DCreate9(0x20)` through thunk 0x54D17F (IAT 0xB84164) | `ev_8a0b14c4…`, `ev_3fa1881b…` |
| +4D0h | `IDirect3DDevice9*` | `ev_3f571458…` |
| +604h | `D3DPRESENT_PARAMETERS` (0x38 bytes) | `ev_3f571458…` |
| +63Ch | Device type, always 1 (HAL) | `ev_3f571458…` |
| +640h | Adapter, from cfg `d3dadapter` (`[0xD90764]` → 0xD99804) | `ev_8a0b14c4…`, cs |
| +658h / +65Ch | Desktop width / height, from `GetAdapterDisplayMode` | `ev_8a0b14c4…` |
| +8EE4h / +9294h | Batcher 0 / batcher 1 (see §4) | `ev_5ac67504…` |

**CreateDevice / Reset: FUN_00545bb5** (`ev_3f571458…`, cs)

- **Present parameters.**
  - Width, height and format come from the caller.
  - `BackBufferCount` (+610h) is set to **1** at 0x545C08. This is the only renderer write to `+610h`;
    the other `[reg+610h]` stores in `.text` are UI-gadget fields (`mpsetup-*`).
  - `SwapEffect` = 1 (DISCARD), no multisample, no auto depth-stencil, `Flags` = 0.
  - `FullScreen_RefreshRateInHz` = windowed ? 0 : the refresh argument.
- **BehaviorFlags.**
  - `edi = 0x80` (MIXED_VERTEXPROCESSING) when an adapter-caps bit is set (the loop over `[+490h]`
    entries, byte `+26h` bit 0). Otherwise `0x20` (SOFTWARE).
  - Then `or edi, 4` (MULTITHREADED) at 0x545D34, unconditionally, before the push at 0x545D57.
  - HARDWARE_VERTEXPROCESSING and PUREDEVICE are never used.
- **The call.** `call [edx+40h]` at 0x545D78 is the only CreateDevice on a normal system. When
  `GetSystemMetrics(SM_MEDIACENTER)` (0x57) is non-zero, the path at 0x6C7239 retries up to 10 times,
  50 ms apart, pumping messages, with the same flags.
- **No `D3DCREATE_FPU_PRESERVE`.** Stock d3d9 therefore sets the x87 FPU of the device-creating thread
  (the main thread) to single precision. That thread also runs the simulation, so anything that changes
  the FPU mode can desync against stock players in multiplayer. That includes adding FPU_PRESERVE, and a
  D3D9 replacement such as DXVK that handles this differently. Check before any online use.
- **Reset** of an existing device is `device vtbl+40h` with the same `+604h` block:
  - With AA on, the device is Reset right after creation with `MultiSampleType` = the AA level
    (0x6C74C0…0x6C7524). That Reset's HRESULT is ignored, because 0x6C7527 tests the stale CreateDevice result.
  - The cfg `useDeviceReset` (ID 0xD99818 through `[0xDBE4B8]`) makes the device-exists path Reset the
    device (FUN_005b1bcb) instead of releasing and recreating it. That is relevant to mode-change stutter.

**Present interval (+638h).**
- The renderer ctor FUN_0054ef1e sets it to `0x80000000` (IMMEDIATE) at 0x54F502 (`ev_e245e8e6…`).
- The vsync setters at 0x54114F, 0x5ACB8F and 0x5AD568 write `on ? 1 : 0x80000000`, i.e. ONE or IMMEDIATE (cs).
- Vsync on is therefore double-buffered: a frame that misses a vblank waits for the next one (60 → 30 FPS steps).

**Display-mode list.** FUN_0054d663 / FUN_0054d605 collect the adapter's modes at 16 and 32 bpp
(`ev_8d2633fc…`). WoL's `compatMode` hooks this pair ([wol-uhc-map.md](wol-uhc-map.md)); it is not a performance patch.

## 6. Config variables

**Registration.** `push 0; push 0|default; push desc; push name; mov ecx, 0xC66500; call 0x5734E0`, then
the returned ID is stored, usually after the next registration's pushes. 441 names map this way.

**Lookup.**
- The usual test is `FUN_004020c3(id)` with `ecx = 0xC66500`, which returns "defined".
- The inlined form checks `0 ≤ id < [0xC6651C]`, `[0xC66530] != 0`, `idx = [[0xC66518]+id*4]+14Ch` with
  `idx != -1`, and value entry `[0xC66504] + idx*28h` with flags byte `+18h` bit 3 clear.
- Some IDs are reached through pointer slots that static initializers fill (0x56FB69…0x56FC86, e.g.
  `[0xD9076C] = 0xD9982C`). Others use a pointer stored right before the ID (`[0xCEFF90] = 0xCEFF94`).

| Variable (description in the exe) | ID store | Readers found | Effect |
|---|---|---|---|
| `RunAsFastAsPossible` ("ignore realtime & always run updates") | 0xCEFF94 (ptr 0xCEFF90) | 0x482570, FUN_00455d91 | Sim pacing (not MP-safe). |
| `fixedUpdate` | 0xC6F89C (ptr 0xC6F898) | FUN_00455d91, FUN_0045a1c5, 0x4825CD, 0x648160 | Sim pacing. |
| `MinRandUpdate` | 0xD993A4 (ptr 0xD993A0) | FUN_00455d91 | Sim pacing. |
| `disableMidUpdateRender` ("Turn off the distributed update rendering") | 0xCEFF8C (ptr 0xCEFF88) | 0x482532 (not a Ghidra function) | Rendering inside long updates. |
| `singleThreadedBatcher` | 0xD9982C (`[0xD9076C]`) | FUN_0054edaa | Disables the skinning worker. |
| `showFPS` | 0xC674AC (ptr 0xC674A8) | 0x41C812 | FPS overlay. |
| `performanceClass` | 0xD95C68 (ptr 0xD95C64) | 0x5585BF, 0x5585D9 | Not traced. |
| `DontCheckUnsupported` | 0xD96A28 (ptr 0xD96A24) | 0x557E93, 0x67BBE2 | Unsupported-system check. |
| `d3dadapter`, `enableShadows`, `forceD3DConfigFile`, `HDRMultisampleFactor`, `shadowQualityOverride`, `batcherPrivateVBSize` / `IBSize` | 0xD99804, 0xD99808, 0xD99814, 0xD99838, 0xD99848, 0xD9985C / 0xD99868 | through the pointer slots at 0x56FB69… | Renderer setup. |
| `useDeviceReset` ("Reset the device instead of destroying and re-creating it") | 0xD99818 (`[0xDBE4B8]`) | FUN_00545bb5 (device-exists path) | Reset instead of recreate on mode changes (§5). |
| `backBufferCount` ("Number of backbuffers: 1 - 3. Default: 1") | 0xD998D8 | none | No effect: +610h is always 1 (§5). |
| `AlwaysActive`, `cputnl`, `syncUpdateInterval` | 0xD98FC4, 0xD998BC, 0xD98EE8 | none found by ID store | Not established (could be read some other way). |

## 7. Data and settings

These are files on disk, read 2026-10-28 by a read-only pass.

**GPU profile.**
- The profiles live in `bin\render\render3.bar` (`Render\config\*.d3dconfig.xmb`, `devices.xml.xmb`).
- `Age3Log.txt` on this PC shows the RTX 4090 (10DE:2684) as unlisted, so the game picks the generic
  `geforce fx 6800` profile: SM3, FP16 bloom/tonemap, NV shadow maps quality 2. That is the best stock tier.
- The shader-quality option chooses the tier.
- No d3dconfig field controls frame rate, threads, vertex-processing mode or AA samples.

**`Startup\gamey.cfg`** has `alwaysActive`, `demandLoadMeshes`, `maxParticles=-1`,
`MemoryStackHeapSize=2097152`, `EnableSLI` and `updateAIs`. `megaPostLoadForceTextures` is commented out.

**Live profile on 2026-10-28** (`NewProfile3.xml`):
- shader quality 0 (Low), 16-bit, windowed 1920×1080, vsync off;
- the September backup had Very High, 32-bit, 2560×1440, fullscreen.

**Address space.** The stock exe and the test-bed exe are not Large-Address-Aware (2 GB user space).

## 8. Runtime observations

**2026-10-28 13:25, first sample.**
- Run: `tools/perfprobe.py`, 15 s, against a test-bed instance (`C:\AoE3-UHC-Test`, PID 4308) that was
  already running. On screen was an unknown scene, the profile was Low shaders, and the DLL had no `perfStats`,
  so there are no frame times.
- This is a single sample, not the benchmark. It is kept because it already answers one question.

| Thread / counter | Mean | Max |
|---|---|---|
| Main thread | 78 % of a core | 88 % |
| Skinning worker | 8 % | 15 % |
| `nvd3dum.dll+0x45A344` (NVIDIA D3D9 driver worker) | 50–70 % | — |
| GPU 3D engine | 17 % | 20 % |
| Skinning jobs/s, worker / main thread | ~25,000 / ~170 | — |

Reading (inference):
- The main thread is close to saturation while the GPU idles.
- Skinning is already almost all on the worker, which has plenty of slack. More skinning workers would
  not help here.
- The NVIDIA driver spends most of another core on this D3D9 stream. That points at Direct3D
  overhead (device flags, DXVK) as the render-side lever.

**2026-10-28 13:30, main menu with `perfStats`** (test bed, Low shaders, 16-bit, windowed 2560×1600):
- about 1,270 FPS, frames 0.8 ms (1.4–2.2 ms worst per second);
- main thread 78 %, worker 5 %, GPU 16 %, 577 MB of address space;
- device log: `BehaviorFlags 0x84` (MIXED | MULTITHREADED), 1 back buffer, DISCARD, interval ONE at
  creation, then Reset to IMMEDIATE;
- right after CreateDevice the main thread has **x87 control word 0x007F** (single precision, all
  exceptions masked) and MXCSR 0x1FA0. This is the stock FPU state any D3D9 change must keep.

**2026-10-28 ~13:45–14:03, a full 8-player game played by the user** (test bed, `perfStats` on,
exit summary only; `perfprobe` was not recording):
- settings: Very High shaders, 16-bit, windowed 3840×2160 (changed in game, so the device was
  released and recreated); vsync off;
- `config("AIvsAI")` and `gameSpeedMult(8.0)` had been sent before and during the game for the
  intended AI-only benchmark;
- result: **52 frames over 100 ms and 90 over 50 ms** in 1.25 M frames (menus included). Peak working
  set 644 MB, private 100 MB, so nowhere near the 2 GB limit.

### Late-game A/B: native D3D9 vs DXVK (2026-10-28 14:40–14:48)

**Setup.**
- Save `uhcbench25`: 8 AI players (Hard), ~25 game minutes. It was made with `AIvsAI` and fast-forwarded
  with `fixedUpdate`=100 + `RunAsFastAsPossible`.
- Each run was driven by the user: load the save and click the same spot on the minimap.
- `bench_watch` unpaused the game through `perfExecFile` and recorded 136–137 s with `perfprobe --sample-hz 100`.
- Test bed at 3840×2160 windowed, Very High shaders, 16-bit, vsync off.
- Files: `rea/evidence/age3y-b1a1dab7/bench-nativo.csv`, `bench-dxvk.csv` and their `.samples.txt`.

| | Native d3d9 | DXVK 3.1.1 |
|---|---|---|
| FPS (mean / max) | 125.6 / 204.8 | 90.9 / 127.4 |
| Frames over 50 ms / 100 ms | 19 / 10 | 17 / 8 |
| Simulation speed | 1.0× | 1.0× |
| Main thread | 94.7 % (max 101) | 98.3 % (max 101) |
| Skinning worker | 4.4 % | 3.1 % |
| GPU 3D engine | 13.4 % | 10.4 % |
| Address space (max) | 1,024 MB | 1,256 MB |
| x87 control word after CreateDevice | 0x007F | 0x007F |

Main-thread profile (share of samples):

| Module | Native | DXVK |
|---|---|---|
| age3y.exe | 77.1 % | 83.6 % |
| ntdll.dll | 8.0 % | 3.6 % |
| granny2.dll (animation) | 6.8 % | 5.8 % |
| d3d9.dll | 3.2 % | 2.8 % |
| nvd3dum.dll (NVIDIA) | 1.3 % | — |
| deformerdlly.dll (skinning) | 1.2 % | 2.6 % |
| d3dx9_25.dll | 0.5 % | 0.6 % |

Hottest exe functions (native run; `ev_e25829f2…`):

| Share | Function | Role |
|---|---|---|
| 5.2 % | FUN_0040d25b | Renderer: shader/material parameters (`blendColor`, `pixelxformColor`) |
| 3.5 % | FUN_0044d863 / FUN_0044d898 | Small float tests, many callers |
| 2.4 % | FUN_00407a06 | Vector math |
| 2.2 % | FUN_00485f10 | Large spatial query with float vectors |
| 1.3 % | FUN_004bbad9 | — |
| ~3 % | FUN_00422ba9, FUN_00424e33, FUN_004234d7 | Per-object update math |

Everything else is under 1 % per 256-byte block.

**Conclusions** (single save, two runs, so treat ±10 % as noise):
- A late game is bound by the main thread running the game's own code, at about 95 % of one core.
  - The GPU stays at 10–13 % even at 4K.
  - Direct3D and the driver are about 5 % of the main thread; skinning about 1–3 %.
- **DXVK makes it worse here: −28 % FPS and +230 MB of address space.** Measured again on 2026-11-10 with
  §11's procedure: −14 % at 2560×1600, +6 % at 720p (§11, "A/B runs").
  - Stutter is about the same.
  - It does keep the stock FPU state (0x007F), so it would not desync.
- Feature ideas are capped by those shares, so neither is worth its risk:
  - `deformWorkers`: at most about 1–3 %;
  - `d3dNoMultithreaded`: well under the 3 % that d3d9.dll takes.
- Large-Address-Aware is not needed with the stock data: 1.0 GB of address space at 25 minutes. It may be with DXVK or heavier mods.
- **Stutter:** the remaining problem is about 4 frames per minute over 100 ms. §9 traces their cause to file
  loads inside the simulation.

## 9. Where the main thread's time goes (stack sampling, 2026-10-28)

Answers two questions:
- How does a late-game frame split between simulation and rendering? That bounds any multi-core change (Amdahl).
- What runs during the stutters?

### Method

- `tools/perfprobe.py --sample-hz 200` suspends the main thread, reads EIP, ESP and the stack, and resumes it.
  - It keeps the stack values that are return addresses into the exe: an address that follows a call
    instruction in `.text`.
  - Raw samples go to `<csv>.stacks.gz`; `--analyze` rebuilds the report from them.
- The analysis rebuilds each call chain top-down, from the return address into the main loop.
  - After a direct call it takes the outermost candidate inside the called function.
  - After an indirect call, or a tail call, it takes the outermost candidate whose own call is consistent with what lies below.
  - Values left on the stack by earlier calls are mostly skipped, not always.
- Function entries come from Ghidra's function list: `rea/evidence/age3y-b1a1dab7/functions.txt`, built from
  `ev_da144e22…`, with the 105 switch-case pseudo-functions dropped.
- **Function boundaries.** Ghidra splits some functions at calls to tiny `timeGetTime` stubs and at
  cold-code chunks (POGO layout). Those pieces show up as separate nodes, listed below.
- **Checks.**
  - 99.6 % of the late-game samples anchor under the per-frame call.
  - The update/render split below matches the game's own timers to within a percent.
- **Overhead** is not measured: FPS was 108.6 here and 125.6 in the earlier run of the same save. That run
  had a different resolution and camera and sampled at 100 Hz without reading stacks.

### Frame structure (static, REA `bundle-perf-20261028-d.json`)

| VA | Role | Evidence |
|---|---|---|
| 0x404EE0 | Main loop (WinMain body). Each turn: message pump 0x402EF7 (returns to 0x404F7F), then `[0xC66234]->vtable[74h]` through the `jmp eax` stub 0x406A01 (call at 0x404FA8, returns to 0x404FAD). Ends on `[0xC6623C]`. | `ev_2c667950…`, `ev_bbbe9b38…` |
| 0x40542F, 0x405523, 0x405574 | The per-frame function (vtable+74h). Ghidra cut it into three pieces at `call 0x405510` / `call 0x405561`, which are `timeGetTime` stubs followed by `jmp` to the next piece. | `ev_0cf19746…`, bytes `ev_66b6966f…` |
| 0x40542F | **Start piece.** Once a second it stores the game's own per-frame averages: render ms at `[game+CBCh]` and update ms at `[game+CC0h]`. They come from QPC tick sums `[game+CACh]` / `[game+CB4h]` (QPC read by 0x404104) and the frame count `[game+CA8h]`. Then input/console (0x406A1E, 0x406A33, 0x406A5C). | `ev_0cf19746…` |
| 0x405523 | **Update piece.** Calls the mode manager update 0x405248 (returns to 0x405535) and adds its time to `[game+CB4h]`. | same |
| 0x405248 | Mode manager: pops/pushes modes ("Mode to be terminated is: %d…") and updates each active mode through 0x405339. | same |
| 0x405574 | **Render piece.** Calls `game->vtable[78h]` through the stub 0x408FE4 (call at 0x4056AC, returns to 0x4056B1) and adds its time to `[game+CACh]`. It then bumps the frame counters and calls `_control87(0x9001F, 0xFFFFF)`, which sets 53-bit precision with all exceptions masked. That restores the x87 mode that Direct3D 9 changes (§5). | same, bytes `ev_fa2d724b…` |
| 0x44E0CD (+0x44E183, 0x48FFD9, 0x48FFF3) | Game-mode update, also cut into pieces. 0x44E183 is the only caller of the step-length function 0x455D91 (`ev_ad8fe973…`). The cold chunk 0x48FFD9 jumps into 0x48FFF3, which calls the world update at 0x49000B (returns to 0x490010). | `ev_ee973830…` |
| 0x481B1C | **World update**: assert `.\world.cpp`; `this` = `[game+13Ch]`. Phases are separated by 0x491C94 checks and counted in `[world+810h]`. It advances the simulation RNG at `[0xC6658C]+18h` (an MSVC-style LCG: ×0x343FD + 0x269EC3). | `ev_dd5f48b8…` |
| 0x4848BB | Unit update loop over the world's unit lists `[world+D4h/D8h]`, `[+E0h/E4h]` and `[+ECh/F0h]`. The per-unit update is 0x482F50 (movement 0x4829FA, actions 0x48971A). | `ev_4677dfc3…` |
| 0x4910CF | Loop over the `[world+148h/14Ch]` entries (0x491902, then 0x49108A). Role not identified. | same |
| 0x45084C | Render pass dispatcher; pass 1 (main view) → 0x450A4E → 0x44FC96. | `ev_cf045b59…` |
| 0x44FC96 | **World draw.** Builds the visible-unit lists, draws each unit through 0x452392, flushes batches (0x4516D9, 0x40A4ED), sets render states (0x4203AB) and material parameters (0x40D25B). The other passes under 0x408399 → 0x40B9BA → 0x424A9B / 0x425200 → 0x4597A4 call it again; which passes those are (shadow, reflection) is not established. | same |

### Late-game split

**Setup:** `uhcbench25` (8 AI, ~25 game minutes) at 2560×1600 windowed with vsync off. 150 s, 27,183 samples.
**Files:** `rea/evidence/age3y-b1a1dab7/bench-late25.csv`, plus `.stacks.gz` and `.samples.txt`.

FPS was 108.6 mean (max 177). The main thread ran at 95.1 %, the skinning worker at 5.6 % and the GPU at 12.7 %.

| Part (inclusive share of main-thread samples) | Share | Game's own timer |
|---|---|---|
| **Update** (mode manager) | **43.5 %** | **4.3 ms / frame** |
| └ world update 0x481B1C | 41.6 % | |
| &nbsp;&nbsp;└ unit update loop 0x4848BB (per-unit 0x482F50: 11.5 %) | 15.9 % | |
| &nbsp;&nbsp;└ `[world+148h]` loop 0x4910CF | 11.0 % | |
| &nbsp;&nbsp;└ other phases (0x48FD70 3.0 %, 0x491961 2.7 %, the call at 0x481CE9 ≈ 6 %, …) | ≈ 14.7 % | |
| **Render** (vtable+78h) | **55.6 %** | **5.4 ms / frame** |
| └ main world pass 0x40BAFE → 0x45084C → 0x44FC96 | 20.5 % | |
| └ 0x408399: other world passes 0x40B9BA (18.7 %), UI 0x41C6D3 (4.1 %), Present wrapper (2.8 %), … | 27.3 % | |
| └ other render work (0x44F4D5 4.9 %, 0x4159EF 1.9 %, …) | ≈ 7.8 % | |
| Frame start piece and message pump | ≈ 1 % | |

By module, `granny2.dll` (animation) is 7.6 % of all samples. `deformerdlly.dll` (skinning) is 2.8 %, and
`d3d9.dll` with the driver is 4.6 %.

### The stutters

There were 16 frames over 50 ms in 150 s: 11 over 100 ms, the longest 214 ms, 2.1 s in total. `perfStats` v2
recorded their QPC windows, and 377 samples fall inside them.

- **90.2 % are in the update part**, against 43.5 % overall:
  - the world update holds 84.9 %;
  - the unit update loop holds 63.1 % of it;
  - 0x490960 → 0x4BF814 holds 19.9 %.
- **The leaves are file reads.**

  | Leaf | Inside slow frames | Other frames |
  |---|---|---|
  | `ntdll!ZwReadFile` | 48.0 % | 0.3 % |
  | `granny2.dll` | 28.4 % | 7.6 % |
  | `ntdll!ZwWaitForSingleObject` | 3.4 % | 3.1 % |
  | `ntdll!ZwCreateFile` | 1.9 % | 0.1 % |

- **The chains end in the game's file reader:** … → 0x43B8FF → 0x599121 → 0x5990D1 → 0x4683F4 → `ReadFile`.
  They come from two places:
  - the unit update, 0x482F50 → 0x48971A → 0x488A40;
  - 0x490960 → 0x4BF814 → 0x66A452 → 0x858299.

  Both go through a recursive evaluator (0x94CF27 / 0x94DAE1 / 0x7F7E97, possibly the XS interpreter;
  not identified).
- **The reader does no buffering** (`ev_1c4e2090…`, `ev_bb0bb32c…`):
  - 0x4683F4 issues one `ReadFile` per call;
  - 0x599121 reads 4 bytes;
  - 0x43B8FF reads a 16-byte header as four 4-byte calls;
  - 0x468450 (open) checks for the `l33t` header of compressed files (stream vtable 0xBA3318) and
    otherwise uses a raw stream.

**Inference.** The stutters are data loads that the simulation needs the first time it meets something new.
Granny parses what was just read, so they are probably a unit's model or animation data. The loads run on the
main thread through thousands of 4-byte unbuffered reads. **Unknown:** which files they are. That needs a
file-open log.

### What it means for "more cores"

- The user requires multiplayer safety, so only render-side work may move. That is 55.6 % of the main thread.
- **Pipelining** the whole render beside the next update, as Age of Mythology: Retold does, would give at most
  max(4.3, 5.4) ms per frame, about +70 % FPS. It is out: the render reads live simulation objects, and the exe
  has no double-buffered state.
- **Splitting the render passes across threads.** The world passes do three things:
  - visibility;
  - animation (granny, 7.6 %);
  - Direct3D 9 submission.

  Submission has to stay on one thread, because there is one D3D9 device and `MULTITHREADED` only serializes.
  Visibility and animation run inside the per-unit draw calls, interleaved with submission. Moving them is a
  restructuring of exe code, not a hook-sized change. Even if a quarter of the frame went perfectly parallel,
  the gain would be about +30 % FPS. The real gain would be well below that, and the crash and desync risks are high.
- **No multiplayer-safe multi-core change has a good cost/benefit ratio here.**
- **The Definitive Edition was measured the same way** ([de-architecture.md](de-architecture.md)). Its
  main thread still saturates in a battle (91–95 %), and the simulation is still on it. It adds a
  PopcornFX particle pool, streaming texture loads and a sound thread; in total it uses about 2.1 cores.
  The thread first read as a render thread (45–61 % of a core) is the sound thread: DE renders and
  presents on its main thread (§11, "How DE does it", 2026-11-10).
- **The stutters have a concrete multiplayer-safe lever:** buffered file reads (§10). The bytes stay the same and
  far fewer syscalls are made. `ZwReadFile` was 48 % of the stutter samples.

### bufferedFileReads A/B (2026-10-28, ~15:55–16:30)

The feature is in `src/features/fileio.cpp`; its design is in [how-it-works.md](how-it-works.md).

**Setup.**
- Three user-driven runs of `uhcbench25` with the §8 protocol: 2560×1600, vsync off, 150 s,
  `perfprobe --sample-hz 200`.
- `perfFileLog 1` was on in all three, so each run carries the same hooks.
- Files: `bench-verify`, `bench-base-filelog` and `bench-buffered` (`.csv`, `.stacks.gz`, `.samples.txt`),
  plus the matching `fileio-*-UHC.log`, all in `rea/evidence/age3y-b1a1dab7/`.

**Correctness run** (`bufferedFileReads 64 verify`):
- every buffered read was read again from the file at the same offset and compared;
- 7,529,881 reads were checked, with **0 mismatches**;
- the game ran normally, slower because of the double reads.

| | No buffer | `bufferedFileReads 64` |
|---|---|---|
| Frames over 50 ms (total time) | 19 (2.3 s) | **11 (0.9 s)** |
| Frames over 100 ms | 11 | **3** |
| Longest frames | 251, 228, 155 ms | **116, 106, 104 ms** |
| Mean of the per-second longest frame | 74.8 ms | **46.0 ms** |
| `ZwReadFile` inside the slow frames | 44.1 % | **1.8 %** |
| `granny2.dll` inside the slow frames | 28.0 % (≈ 0.58 s) | 47.6 % (≈ 0.39 s) |
| FPS (mean) | 88.1 | 103.8 |
| Session `ReadFile` calls: by the game / made to Windows | 10.3 M / 10.3 M | 10.2 M / **17,797** |
| Session time in `ReadFile` (mostly loading) | 14.9 s | **0.96 s** |

**Reading.**
- The cause is confirmed: once reads come from memory, `ZwReadFile` disappears from the stutters.
  Frames over 100 ms drop from 11 to 3, and the total stutter time from 2.3 s to 0.9 s.
- The last frame of the load shrank from 5.2 s to 2.7 s, and about 14 s of `ReadFile` per
  session are gone, so loading is faster too. Load time itself was not timed.
- **What is left** in the slow frames is mostly `granny2.dll` building what was just read. That is
  CPU work, about the same in both runs.
- **Noise.** One run each, and in single player the simulation step follows real frame time, so two
  runs of the same save drift apart. FPS differences are within that noise; earlier runs of this
  save gave 88–109 FPS. The mechanism is the firm evidence: the `ZwReadFile` share and the syscall
  counts.
- Multiplayer is not tested. The feature never changes the bytes the game receives, so it cannot
  desynchronize.

## Benchmark harness

These parts of `src/features/perf.cpp` exist for measurement. The game behaves as stock with them.

| Key | What it does |
|---|---|
| `perfStats` | Wraps `Direct3DCreate9` through IAT slot 0xB84164, then CreateDevice/Reset/Present through the d3d9 vtables. It logs the device setup and the FPU state, and publishes frame counters in `Local\UHCPerfStats-<pid>` for `tools/perfprobe.py`. Since version 2 that mapping also holds a ring of the last 64 frames over 50 ms, as QPC start/end pairs. The IAT slot holds a runtime address, so it is checked against `GetProcAddress` instead of `generated/sites.h`. |
| `perfAutoExec <frame> <command>` | After that many Presents, runs a console command on the main thread. |
| `perfExecFile <path>` | Every 30 frames, runs the lines of `<path>` as console commands and deletes the file. Lets a script drive the game without keyboard focus. |
| `perfFileLog [ms]` | Counts every `ReadFile` the exe makes, per file, through the same IAT hooks as `bufferedFileReads` (`src/features/fileio.cpp`). At exit it writes the session totals to `UHC.log`, then each file with at least `[ms]` (default 1) of read time: reads, how many were 16 bytes or less, bytes, calls made to Windows, read time and open time (QPC seconds, the clock of `perfprobe`'s slow-frame list). Until exit the lines stay in memory, so logging adds no disk access during a match. |

Console commands run through 0x433D0D, `thiscall(console = [0xC672E4], const char* command, const char* source)`
with `ret 8`. The game uses the same call for its own commands, e.g. `uiOpenScenarioBrowser()` with
source `"console"` at 0x7E279D. The `.con` loader FUN_005bc4c1 runs each line through it.

**Useful commands** (from the exe's own help strings):
- `startRandomGame2(<filename> <#players> <random seed> <scenarioFilename> <debug> <teamCount> <mapsize> <resources> <random_civs>)`,
  handler 0x6F10FC. It writes the game settings `GameFilename`, `GameNumPlayers`, `GameRandomSeed`,
  `GameMapSize`, `GameMapResources`, `GameSpeed` and `GamePlayer<n>*`. The settings table is at
  0xD840E4 with stride 0x88; each player block is 0x18 entries starting at index 0x3A.
- `loadGame` / `saveGame(<file>)`, `restart()`.
- `config` / `configUndef(<name>)`, `gameSpeedMult(<x>)`.

**What was tried for an unattended AI battle (2026-10-28):**
- The game has to run with no keyboard focus, so the screenshots use `PrintWindow`. Posted keyboard
  messages do not reach the console.
- `startRandomGame2` does nothing unless `[[0xC66234]+0xB3A]` is set.
  - `startRandomGame(true)` (handler 0x6F041C) sets that flag and opens the **scenario editor**.
  - `startRandomGame2` then generates the random map **in the editor**.
- `saveScenario` / `leaveGame()` / `loadScenario` play that map, but its players have no AI.
- `AIvsAI` ("If defined SP RM games will make player1 an AI", read at 0x6AEF6C and 0x987E96) only
  applies to single-player random-map games started from the setup screen. The setup screen is native
  UI with no console command behind its Play button, so it needs real clicks.
- Without `DontPauseWhenLosingFocus` the game pauses whenever another window has focus. A background
  benchmark must define it.
- The practical route is therefore one real setup-screen launch (8 AI players, `AIvsAI`), then
  `gameSpeedMult` and `saveGame` through `perfExecFile`, and later `loadGame` for each run.

**Unattended benchmark (2026-10-28).** `tools/legacybench.py` replays that save with no keyboard or
mouse input at all:
1. it starts `age3y.exe +noIntroCinematics` with an inactive window;
2. it loads `uhcbench25` and unpauses it through `perfExecFile`;
3. it records with `perfprobe` (and `threadprobe`);
4. it sends `leaveGame()` and closes the window with a posted `WM_CLOSE`.

First run, `bench-threadval` (test copy `C:\AoE3-UHC-Perf`, 2560×1600, the camera where the save left it,
the window never focused):
- **Without focus the game runs at full speed** once `DontPauseWhenLosingFocus` is defined: 194.6 FPS
  on average.
- The main thread was at 94.4 %. Update took 2.4 ms and render 2.8 ms per frame, against 4.3 and 5.4 ms in
  §9, because the saved camera shows fewer units than the battle view the user clicked to.
- `threadprobe` and `perfprobe` gave the same per-thread numbers ([de-architecture.md](de-architecture.md),
  "Verification").

The game allows one running copy per machine. With `multipleInstances background` in its copy's cfg
([modding guide](modding-guide.md#multipleinstances)), the benchmark can run beside another session's
game. Run `bench-parallel` did that: 60 s beside a second copy idling at the main menu, at 179.1 FPS,
with the main thread at 94.7 %. Runs that share the machine are only comparable with each other.

## 10. Levers (multiplayer-safe), status

| Lever | Kind | Status |
|---|---|---|
| Buffered file reads (`bufferedFileReads`): a read-ahead buffer per read-only file, behind the exe's `ReadFile` / `SetFilePointer` IAT entries | DLL feature | **Implemented and measured** (§9, A/B). Frames over 100 ms dropped from 11 to 3, and session `ReadFile` time from 14.9 s to 1.0 s. `verify` checked 7.5 M reads: 0 mismatches. Not tested in multiplayer; it does not change the simulation. |
| The stutters' remaining work: granny building newly loaded models and animations | — | Open. It is CPU work on the main thread. Preloading would trade memory and load time for it. |
| Moving render-side work to other threads | DLL feature | Rejected for now (§9): at most about +30 % FPS even if perfect, and it needs a restructuring of exe code. §11 measures the parts: the particle update (0.54 ms of 4.96) looked like the only self-contained one. Its safety check (§11, "particleWorker: safety check") rejected it: pass 0 reads what it writes, and it races with the world draw on the pose code's global buffers. |
| More skinning workers (`deformWorkers`), plus letting them help during the flush | DLL feature | Not built. The late-game A/B puts skinning at 1–3 % of the main thread. |
| Device flags: drop MULTITHREADED, HARDWARE vertex processing, back buffers | DLL feature, opt-in | Measured in a local build (§11): no change beyond noise. Dropping MULTITHREADED is unsafe, because the loading-screen thread calls Direct3D. Back buffers only matter with vsync on. |
| Frame-time statistics and device logging (`perfStats`) | DLL feature, passive | Implemented (`src/features/perf.cpp`). Version 2 also records the QPC window of every frame over 50 ms. Read by `tools/perfprobe.py`, which also profiles the main thread's stack (§9). |
| Large-Address-Aware on the test exe | header bit | Planned: `tools/set_laa.py`. |
| `-demandLoadMeshes`, `megaPostLoadForceTextures`, `useDeviceReset` | cfg | Planned A/B. |
| DXVK (D3D9 → Vulkan) | wrapper | Measured twice, both with 3.1.1 (still the latest release on 2026-11-10): −28 % FPS in §8's 4K battle; **−14 % warm, −16 % cold** at 2560×1600 in §11's procedure, but +6 % at 1280×720. The extra time is one loop in 0x40D25B that reads back from a locked buffer (§11). **With `d3d9.cachedWriteOnlyBuffers = True` in `dxvk.conf` that loop costs nothing and DXVK beats stock: +14 % at 2560×1600, +18 % at 3840×2160, +14 % at 720p**, no frame over 50 ms, the picture unchanged on the frames compared. FPU state kept (0x007F), +225–255 MB of address space. Without the option: not recommended. With it: the only D3D layer measured that is faster than stock, as a user-side setup; a multiplayer game and a full-length game come before it is recommended. |
| The read-back loop in 0x40D25B (0x40D5C0…0x40D5FD) on stock D3D9 | DLL feature | Not built [I]. It is 5.6–7.5 % of the main thread at 2560×1600 and above (§11), and DXVK's cached buffers make it free. A key that makes the second copy read from the source record instead of the locked buffer could give stock D3D9 up to that share. The function and its buffer are not analysed yet. |
| dgVoodoo2 (D3D9 → D3D11) | wrapper | Measured (§11): −5…−8 % FPS; FPU state kept. Not recommended. |
| `RunAsFastAsPossible`, `fixedUpdate`, `MinRandUpdate`, `syncUpdateInterval`, the 100 ms cap | — | Rejected: they change the simulation. |

## 11. Multi-core or D3D11 (2026-11-10)

The question: should legacy be sped up by moving work to more cores, or by a Direct3D 11 renderer? This
section measures the render side of the frame, what it shares with the simulation, and what Direct3D costs.
Every statement is marked **[O]** observed (REA listing, bytes, or a runtime measurement), **[I]** inferred,
or **[?]** open.

### Method

- **Static.** REA (Ghidra 12.1.4) on the stock exe; records in `rea/evidence/age3y-b1a1dab7/perf-20261110.json`
  (37 records), cited by ID prefix. `cs` = capstone over the file bytes.
- **Probe build.** A local, uncommitted build of `src/features/perf.cpp`
  (`rea/evidence/age3y-b1a1dab7/multicore-20261110/probe.patch`). With `UHC_PROBE=1` in the environment:
  - 68 exe `call rel32` sites are pointed at generated stubs that time the callee with `rdtsc`
    (inclusive time, nesting-safe, the same length as the call, so nothing is relocated);
  - every `IDirect3DDevice9` method (slots 3–118) is wrapped the same way, and counts calls made from a
    thread other than the device's creator, and calls made while the update part runs;
  - it records the x87 control word at every update entry and every Present;
  - every 16th frame it copies the first 0x400 bytes of every unit, 0x200 bytes of each unit's `[unit+B4h]`
    object and 0x8000 bytes of the world before the render call, and counts the dwords that changed after it.
  - `UHC_DEVFLAGS=hw|nomt` changes the CreateDevice behavior flags.
  - Overhead: 201.6 FPS with the probe against 194.6–201.4 without it [O].
- **Runs.** `uhcbench25` in `C:\AoE3-UHC-Test`, driven like `tools/legacybench.py` (the camera where the save left
  it, as in `bench-threadval`, not the battle view of §9), 60 s each, `perfprobe --sample-hz 200`,
  Very High shaders, 16-bit, windowed, vsync off, 2560×1600 unless stated. One run per setting; two baselines
  gave 194.6 and 201.4 FPS, so treat ±3 % as noise.
- **Files.** `rea/evidence/age3y-b1a1dab7/bench-{ab-*,probe-*,probe1110}.csv` (+ `.samples.txt`, `.stacks.gz`,
  `.UHC.log`); the summaries and scripts in `multicore-20261110/`.

### The render frame

`vtable[78h]` of the game is **0x408399** [O] (`ev_91eb3a47…`). It ends with `_control87(0x9001F, 0xFFFFF)`.
Times are the probe's inclusive ms per frame at 2560×1600 (201.5 FPS, frame 4.96 ms) [O]:

| Step | Function (call site) | ms/frame | What it is |
|---|---|---|---|
| **Update** | 0x405248 (0x405530) | **2.12** | Simulation and AI (§9). |
| **Render** | 0x408399 (0x4056AC) | **2.73** | |
| └ particles | 0x408AAB (0x408498) | 0.54 | Walks the particle emitters, updates them (0x408E36 → 0x425018 → 0x424A9B / 0x424E33: velocity, gravity, drag) and sorts them by distance. Its state is visual only (`ev_084ed1cb…`, `ev_d8d52214…`). |
| └ world | 0x40B9BA (0x40858D) | 1.71 | 0x40BAFE is its tail, reached by a `jmp` at 0x40BAB3, not a separate pass (`ev_89f7c631…`). |
| &nbsp;&nbsp;└ views, pass 0 | 0x40BCF0(0) (0x40BA32) | 0.70 | Calls `vtable[14h]` of each view; the world view 0x45084C(0) → 0x459719 → 0x4597A4: a walk 0x459637 → 0x4593CB, a frustum between two horizontal clip planes (0x411409, 0.06), then the world draw 0x44FC96 (0.50) (`ev_13da66a1…`, `ev_faaa8ead…`). Its purpose is not established [?]: setting `optiongrfxenableshadows` or `optiongrfxwaterreflections` to false in the profile left it at 0.70–0.72 ms. |
| &nbsp;&nbsp;└ 0x415B51 | (0x40BA4A) | 0.12 | Extra per-view draws (0x459E7C, 0x415BA4, 0x417D69, a loop over `[world+860h]`) (`ev_966f6457…`). |
| &nbsp;&nbsp;└ views, pass 1 | 0x40BCF0(1) (0x40BB9B) | 0.85 | The main view: 0x45084C(1) → 0x450A4E → world draw 0x44FC96 (0.84). |
| └ UI | 0x41C6D3 (0x4085E8) | 0.22 | |
| └ Present wrapper | 0x41CA31 (0x408620) | 0.21 | `IDirect3DDevice9::Present` itself: 0.21. |
| └ the rest | | 0.05 | |

Inside the two world draws (1.34 ms together) [O]: batch flush 0x4516D9 0.69 (of it model batches 0x4510C3 0.34,
163 calls per frame), material parameters 0x40D25B 0.32, 0x4524EE 0.21, the rest 0.13. The per-unit call 0x452392
(47 per frame) costs nothing measurable: it queues, and the flush draws. Animation is evaluated there, per model
batch (0x4510C3 → 0x44EA4B → 0x407380 → 0x407272 → granny).

**A correction to §9.** Its stack chains have stale return addresses in the middle. 0x424A9B and 0x424E33 are
particle code, not passes, and "0x40BAFE main world pass 20.5 %" plus "0x40B9BA other world passes 18.7 %" are one
function. The per-pass split above comes from the probe's timers, not from stacks.

**What the render costs, by kind** (render 2.73 ms = 100 %):

| Kind | ms/frame | Share of render | Evidence |
|---|---|---|---|
| (a) Direct3D calls (all device methods, driver included) | 0.49 (Present 0.21, the other 3,862 calls 0.28) | 18 % | [O] probe; d3d9 + nvd3dum + win32u are 6.2 % of main-thread samples |
| (b) CPU work that reads simulation state and writes render state | ≈ 2.2 (particles 0.54, world passes ≈ 1.4 without their D3D calls, UI 0.22) | ≈ 80 % | [O] timers; the D3D split inside the world passes is [I] |
| (c) Writes into simulation objects | no separate time: inside (b) | — | [O], below |

The NVIDIA driver already runs its own worker thread beside the game (`nvd3dum.dll+0x4633B4`, 20–35 % of a
core) [O].

### What the render shares with the simulation

- **Writes from the render into simulation objects** [O]:
  - Across the render call, the first 0x400 bytes of every unit and 0x8000 bytes of the world never changed
    (778 sampled frames, 1.84 M unit reads). Fields of the object at `[unit+B4h]` did: `+34h…+74h`, `+DCh/+E0h`
    (34,631 changes, 1.9 % of unit samples) and `+174h…+1B0h`. The same object holds the per-player
    visibility mask at `+ACh` that the AI reads (`kbUnitVisible`, [engine-symbols.md](engine-symbols.md)).
  - `+DCh/+E0h` is a damped spring integrated with the frame time at 0x452D7B…0x452DC5 (in 0x452B8E, under the
    per-unit draw 0x452392 and the batch flush; hardware write breakpoint, `multicore-20261110/trace-sub.txt`). The
    simulation zeroes it at 0x47253F (0x4722E6, world update). It is visual state stored in a simulation object.
  - `+34h…+74h` is a bounding box rebuilt by 0x48241C from the unit's model bounds and orientation
    (`ev_de03df52…`). The render reaches it through 0x4592FE in the pass-0 walk when the unit's dirty bit
    (`[[unit+4]+5]` bit 3) is set, clears that bit, and sets or clears bit 5 of `[[unit+4]+1]`. The simulation
    calls 0x48241C from 0x487A21, 0x48DD3F and others (`cs`). So whichever side comes first does the
    recomputation. 0x48241C also calls `_control87(0x9001F, 0xFFFFF)`.
  - Whether the simulation reads that box or bit 5 for decisions is not established [?].
- **Calls from the simulation into render objects** [O]:
  - the model and pose code (0x44EA87 → 0x407380, 0x4073F9 → 0x407272 → granny) is entered about 1.5 times per
    frame while the update runs (18,424 times in 12,450 frames); one caller is 0x49CD3E, which takes a model
    point (0x44EA4B) and places a terrain effect (`ev_9c30aa30…`; purpose [I]);
  - `IDirect3DDevice9::CreateTexture` is called 10–16 times per minute from inside the update: textures loaded
    on demand.
- **Direct3D off the main thread** [O]: in every probe run, 13–14 frames of device calls (Present,
  BeginScene/EndScene, Clear, SetRenderState, SetTexture, DrawPrimitive, SetStreamSource) came from another
  thread before the match, and none during it. With `+noIntroCinematics` that is the loading-screen thread
  0x5A1FF1 (§3) [I]. So `D3DCREATE_MULTITHREADED` is needed, and dropping it is not safe.
- **FPU** [O]: the x87 control word was 0x027F at every update entry and every Present in all probe runs
  (stock d3d9 and dgVoodoo). It is 0x007F only right after CreateDevice; the game sets 53-bit precision again
  at the end of every render and inside 0x48241C. A different D3D layer can only matter for sync if it changes
  the control word inside a call made during the update (only CreateTexture was seen there) [I].

### A/B runs (60 s each)

| Run | FPS | p5 FPS | Update / render (game's timers, ms) | Main thread | GPU 3D | Draws per frame |
|---|---|---|---|---|---|---|
| Base 2560×1600 (two runs) | 201.4 / 194.6 | 180 / 169 | 2.22–2.34 / 2.76–2.80 | 95 % | 10–11 % | 919 |
| 1280×720 | 239.1 (+19 %) | 214 | 2.19 / 2.00 | 90 % | 15 % | 475 |
| 3840×2160 | 188.2 (−7 %) | 166 | 2.24 / 3.09 | 95 % | 14 % | 1,051 |
| HARDWARE vertex processing (flags 0x44) | 202.9 | 177 | 2.26 / 2.71 | 95 % | 11 % | — |
| No MULTITHREADED (flags 0x80) | 200.5 | 173 | 2.27 / 2.75 | 94 % | 10 % | — |
| dgVoodoo2 2.87.6, D3D9 → D3D11 FL 11.0 | 185.0 (−5…−8 %) | 163 | 2.36 / 3.07 | 99 % | 18 % | 931 |
| **DXVK 3.1.1 (D3D9 → Vulkan), 2026-11-10**: base again, no `d3d9.dll` (two runs) | 207.8 / 204.3 | 182 / 178 | 2.12–2.19 / 2.70–2.71 | 94 % | 11 % | — |
| &nbsp;&nbsp;DXVK cold (empty DXVK and driver caches) | 173.9 (−16 %) | 120 | 2.48 / 3.32 | 97 % | 10 % | — |
| &nbsp;&nbsp;DXVK warm (two runs) | 178.7 / 177.1 (**−14 %**) | 157 / 154 | 2.33–2.41 / 3.26–3.29 | 97–98 % | 8–9 % | — |
| &nbsp;&nbsp;1280×720: base / DXVK warm | 261.5 / 277.9 (+6 %) | 222 / 246 | 2.09 / 1.74 against 2.10 / 1.51 | 94 % / 98 % | 13 % / 5 % | — |
| **DXVK 3.1.1 with a `dxvk.conf`, 10:25–10:55**: base again (three runs) | 195.9 / 196.4 / 197.8 | 164 / 157 / 176 | 2.28–2.31 / 2.79–2.84 | 93–95 % | 9–10 % | — |
| &nbsp;&nbsp;`d3d9.cachedWriteOnlyBuffers = True` (two runs) | 223.8 / 226.0 (**+14 %**) | 186 / 196 | 2.22–2.27 / 2.23–2.26 | 97–98 % | 10 % | — |
| &nbsp;&nbsp;`d3d9.allowDirectBufferMapping = False` | 222.1 (+13 %) | 200 | 2.21 / 2.30 | 98 % | 19 % | — |
| &nbsp;&nbsp;both options | 227.2 (+16 %) | 198 | 2.15 / 2.27 | 98 % | 17 % | — |
| &nbsp;&nbsp;3840×2160: base / `cachedWriteOnlyBuffers` | 183.4 / 217.2 (**+18 %**) | 166 / 198 | 2.31 / 3.17 against 2.17 / 2.44 | 96 % / 98 % | 13 % / 17 % | — |
| &nbsp;&nbsp;1280×720: base / `cachedWriteOnlyBuffers` | 241.7 / 275.0 (+14 %) | 218 / 249 | 2.21 / 1.96 against 2.15 / 1.49 | 90 % / 98 % | 12 % / 5 % | — |

- **Resolution** [O]: the GPU stays at 8–15 %. The CPU render time follows what is on screen: a larger
  window shows more of the map (475 → 1,051 draws per frame), so 720p is faster for the CPU, not for the GPU.
- **Device flags** [O]: both created the device (hr 0) and ran the save; both are within noise. They are not levers.
- **dgVoodoo2** [O]: the official `dgVoodoo2_87_6.zip` (SHA-256 `9afa4933…`; `MS\x86\D3D9.dll` `060cb161…`), with
  `OutputAPI = d3d11_fl11_0`, `AdapterIDType = nvidia`, `VRAM = 2048` and no watermark
  (`multicore-20261110/dgVoodoo.conf`). It drives the game; the picture was not inspected. Its device calls cost
  0.77 ms per frame against 0.49 (Present 0.06 against 0.21, the other calls 0.71 against 0.28), and its
  `d3d9.dll` is 9.2 % of main-thread samples. The x87 control word was unchanged (0x007F after CreateDevice, 0x027F
  in play). MXCSR after CreateDevice was 0x1FBD instead of 0x1FA0: only the sticky exception flags differ, the
  masks and rounding do not [O]. It was removed from the bed afterwards.
- **DXVK** (2026-11-10, 09:10–09:35; the base and DXVK runs of the same session) [O]:
  - The latest release is still v3.1.1 (2026-09-15), the version of §8: `dxvk-3.1.1.tar.gz` SHA-256
    `40565b4a…` (matches GitHub's digest), `x32\d3d9.dll` `265888c3…`, byte-identical to the copy in the bed's
    `_dxvk-off`. NVIDIA driver 621.14 (§8: 616.92). No `dxvk.conf` (the HUD is off by default).
  - 3.1.1 keeps its cache in `%LOCALAPPDATA%\dxvk\<hash>.dxvk.bin`, not next to the exe. For an empty cache the runs
    set `DXVK_SHADER_CACHE_PATH`, `__GL_SHADER_DISK_CACHE_PATH` (the NVIDIA driver honored it: 3 MB of `GLCache`)
    and `DXVK_LOG_PATH` to new empty folders; the warm runs reused them ("Found cache file" in the log).
  - **−14 % warm (177.9 against 206.1 FPS), −16 % cold** at 2560×1600; **+6 % at 1280×720** (one run each).
    So the cost grows with what is on screen (475 → 919 draws per frame), and §8's −28 % at 4K in the battle
    view fits that trend [I]. The difference from §8 is the scene and resolution, not the DXVK version.
  - **Cold** [O]: p5 FPS 120 against 154–157 warm, and 7 seconds with a frame over 20 ms against 6 warm and
    4–5 base; no frame over 50 ms in the window in any run. The session totals (load included) were 25 / 27 / 27
    frames over 50 ms with DXVK against 24 / 26 base, so shader compilation shows as uneven frames, not hitches.
  - **Where the time goes** [O]: the main thread's samples in `age3y.exe` rose from 79.6 % to 88 %, and
    `ntdll.dll` fell from 8 % to 2.4 %; `d3d9.dll` stayed at 3.7–3.8 % (DXVK's own) against 4.0 % (stock).
    0x40D25B (§8's material-parameter function) went from **6.2 % to 21.2 % exclusive**, almost all in the loop
    0x40D5C0…0x40D5FD, which copies 32-byte records from `[eax]` to `[edx]` and scales three floats by
    `[0xB856B8]` (`cs`). Both pointers come from one buffer that 0x40A6A2 returns (0x40D4F9, stride 20h): the
    loop first writes each record at `[eax]` (0x40D549…0x40D5BB) and then **reads it back** to write a second,
    scaled copy at `[edx]` [O]. [I] 0x40A6A2 locks a write-only vertex buffer, and reading from the uncached
    memory DXVK maps for it is what costs. The options below test that.
  - Other threads [O]: DXVK's submission thread `d3d9.dll+0x290460` takes 18 % of a core in place of the NVIDIA
    driver's worker (27 %); the process uses 120 % of a core against 126 %.
  - **FPU** [O]: after CreateDevice x87 control word 0x007F and MXCSR 0x1FA0 in every DXVK run, as stock. The
    control word during play was not checked (that needs the probe build).
  - **Memory** [O]: address space 1,163–1,179 MB against 924–925 (**+240–255 MB**, of the 2 GB a non-LAA exe gets);
    peak working set 545–591 MB against 500–502, private (perfStats) 145–166 MB against 91–95.
  - It was removed from the bed afterwards; the bed's files, cfg and profile hash as before.
- **DXVK with buffer options** (2026-11-10, 10:25–10:55, warm cache, a `dxvk.conf` next to the exe with only the
  options named; names and defaults from v3.1.1's `src/d3d9/d3d9_options.cpp`) [O]:
  - `d3d9.cachedWriteOnlyBuffers` (default False) puts write-only buffers in cached system memory instead of
    host-visible VRAM. `d3d9.allowDirectBufferMapping` defaults to **True** and is not in the release's `dxvk.conf`,
    so the value to test is False: dynamic buffers then get a staging copy. The log's "Effective configuration"
    showed each option taken.
  - **Each of them removes the read-back loop**: 0x40D25B falls from 21 % of the main thread's samples to
    0.0–0.1 %, and DXVK goes from −14 % to **+13…+16 % over stock** (224.9 against 196.7 FPS for
    `cachedWriteOnlyBuffers`, two runs against three). The three settings are within noise of each other;
    without direct mapping DXVK's submission thread takes 35–37 % of a core instead of 21 %, so
    `cachedWriteOnlyBuffers = True` alone is the one to use.
  - **Stock D3D9 pays for the same loop**: 5.6–6.2 % of the main thread at 2560×1600 and 7.5 % at 3840×2160; at
    1280×720 it does not run at all (0.0 % in base and DXVK). So about half of the gain is that loop, and the rest
    is what DXVK already showed at 720p: `ntdll.dll` 7.7 % → 2.6 % and no `nvd3dum.dll` (1.6 %) on the main thread.
    Render time 2.23–2.26 ms against 2.79–2.84; update unchanged.
  - **Resolution**: +18 % at 3840×2160 and +14 % at 1280×720, one pair of runs each. At 720p the option changes
    nothing (275.0 against 277.9 without it); base there varied from 239 to 262 FPS between today's runs.
  - **Frames over 50 ms**: none in the window in any DXVK run (one in one base run); session totals 24–26 with
    DXVK, 24–35 base.
  - **Picture**: one screen grab per run at mid-run, compared with base at half size: terrain, shadows, smoke,
    flags, units and UI look the same; no missing or corrupt geometry. The game did not crash. That is one frame
    per run, not a visual test.
  - **FPU**: 0x007F and MXCSR 0x1FA0 after CreateDevice in all eight DXVK runs. **Memory**: address space
    1,148–1,156 MB against 924–933 (+225 MB); peak working set 587–612 MB against 493–506.
  - **Conditions**: base was 4 % lower than at 09:15 (196–198 against 204–208) [?]. Another session's C# builds
    (`VBCSCompiler`, 24–60 % of a core) overlapped two base runs and both `cachedWriteOnlyBuffers` runs at
    2560×1600; the clean base run gave 197.8, so the effect is within 1 %. A run at 10:05, while a whole-disk `find`
    was running, was discarded.
  - **Not tested** [?]: multiplayer (only the FPU state after CreateDevice is known), a full-length game, §8's
    battle view, another GPU or driver, and the control word during play.

### What each path could gain

Measured base: frame 4.96 ms = update 2.1–2.2 + render 2.7–2.8 + 0.1. The battle view of §9: 4.3 + 5.4.

| Path | Upper bound (perfect overlap) | What it needs | Multiplayer risk | Effort |
|---|---|---|---|---|
| **Render on a second thread with a simulation snapshot** (pipelining) | frame = max(update, render): **+75–80 %** here and in the §9 battle [I, Amdahl] | A per-frame copy of everything the render reads (unit transforms, `[unit+B4h]`, models and poses, particles, UI state); moving the render's writes (the spring, the bounding box, the dirty and visibility bits) out of simulation objects; answering the simulation's pose queries and texture loads without the render's objects. The copy's own cost comes off the gain [?]. | High: any of those shared fields read by the simulation while the render thread writes it is a race, and a race in the simulation is a desync | Very high: an ownership rewrite of unit, visual and particle code in a closed exe |
| **Split work inside the render** | Particles (0.54) on a worker beside pass 0 (0.70): ≤ +12 %. The world passes' CPU part (≈ 1.4) on two threads with submission kept on the main thread: ≤ +16 %. Both: **≤ +30 %** [I] | Particles: one call site (0x408498) and a join before pass 1; a thread-safety check of the particle code and the allocator. The world passes: D3D9 cannot record command lists, so the CPU preparation would have to be split from the D3D calls inside 0x44FC96 / 0x4516D9 | Low for particles (visual only; they use the table at 0xC6BBB0, not the simulation RNG [O]). Medium for the world passes, because of the bounding-box and bit writes in the pass-0 walk | Medium for particles; high for the world passes |
| **Direct3D 11 renderer** | All D3D9 calls cost 0.49 ms: **≤ +11 %** even if free. dgVoodoo's D3D11 path measured **−5…−8 %**, DXVK −14 % here (−28 % in §8's 4K battle, +6 % at 720p), and **+14…+18 %** with `d3d9.cachedWriteOnlyBuffers = True`: more than the D3D calls cost, because it also removes a read-back loop of the game (5.6–7.5 % of the main thread) | A real gain needs D3D11 deferred contexts, i.e. the same multithreaded restructuring as the split above, plus a new renderer | Low if the D3D layer keeps the x87 control word (dgVoodoo does) | Wrapper: none; a native renderer: very high |

**Reading** [I]: the main thread's time is game code, not Direct3D. A D3D11 renderer by itself buys at most
about a tenth. The large prize is overlapping update and render (+75–80 %), and it is blocked by shared mutable
state in both directions, which is the costly and risky part. The cheapest real step is to run the particle
update on a worker during pass 0 (≤ +12 %).

### How DE does it

Measured on 2026-11-10 on AoE3 DE, the build of [de-architecture.md](de-architecture.md):
- offline skirmish, 8 players (7 Hard AIs), California, deathmatch;
- 3840×2160, the profile's `optionfpslimit` 60, vsync off, the camera on a battle;
- evidence and scripts in `rea/evidence/aoe3de-31fad98f/runtime-20261110/`.

**Method: from outside the process only.**
- Per-thread CPU: `threadprobe.py`.
- Stack samples: suspend the thread (about 0.1 ms), copy its stack, resume it, then walk the copy with
  dbghelp. 50 Hz on chosen threads, 4 Hz on all 120.
- A 1 kHz phase probe of the main thread, which looks for the return addresses of the frame steps in the
  stack copy (22 µs per sample).
- Microsoft public symbols for the system DLLs.

**Frida was not used [O].** In DE's process, ntdll's `Wow64PrepareForException` pointer is set to
RVA 0x2206DC9, in the protection region; in a plain 64-bit process it is null. Frida's exception
handler on x64 Windows installs itself through that same pointer, so attaching it would have replaced the
protection's hook. That rules out D3D11 call counts and hooked Present times.

| Question | Finding |
|---|---|
| Render thread? | **None.** [O] Only the main thread calls `d3d11.dll`. It uses immediate-context methods (`CContext::TID3D11DeviceContext_*`): Map, SetShaderResources, IASetVertexBuffers, DrawIndexed, DrawIndexedInstancedIndirect and compute UAVs. It also calls `CDXGISwapChain::Present`, through the Steam overlay's hook. No `CommandList` or deferred-context symbol appeared on any thread in about 21,000 samples; the other threads with d3d11 frames are the NVIDIA driver's own (about 55, almost all waiting). |
| The "render thread" of de-architecture.md | **It is the sound thread** [O]: it creates DirectSound buffers, decodes MP3 through ACM (`l3codeca.acm`) and reads files. Its CPU follows battle noise: 11–20 % of a core, 75 % in a large battle. Its `KiUserExceptionDispatcher` samples are illegal-instruction exceptions (0xC000001D) at fn 0xA31FF0+0 and +0x63, an encrypted function in its decode path, dispatched through the protection's hook [O]. [I] This is a protection cost, not rendering. |
| Main-thread frame (30 s, 1,772 frames) | [O] 59.1 fps against the 60 cap. Frame time: mean 16.9 ms, median 17.0, p99 25.0, max 35.4 (1 ms resolution); 1 % low 34 fps. 1,617 frames slept in the limiter. Per frame: **update 9.0 ms** (fn 0x124B1A0 → mode-stack update fn 0x151340, obstruction manager inside); **render 4.1 ms** (fn 0xAB14F0); other 0.35 ms; limiter sleep 3.5 ms. |
| Inside the render (stacks, share of main samples) | [O] Mode render fn 0xAB1210 → fn 0x151780: 7.7 %. Scene draw fn 0x749DC0: 2.9 % (draw issuer fn 0x76A7D0). UI fn 0xAAD710: 2.8 %. PopcornFX runtime fn 0x779440: 1.2 %. Present wrapper fn 0x756830. All D3D11 and DXGI time: **2.4 % of main ≈ 0.4 ms per frame**; Present alone is 0.25 %. |
| Off the main thread (CPU per 16.9 ms frame, large battle) | [O] Main 13.7 ms; sound 12.7; PopcornFX pool 5.7 (16 threads); engine and CRT workers 2.3; protection 2.2; NVIDIA driver 1.3. Process 2.27 cores. |
| Handoffs | [O] Main wakes the PopcornFX workers with a semaphore from fn 0x779440 and seldom waits for them (0.1 % of its samples). Inside the scene draw it waits on an engine fork/join (fn 0x76C4F0 → 0x1B74E30, 0.4 %). 7 of 10 busy PopcornFX samples fell in the main thread's update [I: particles run asynchronously and overlap the next update]. No snapshot or command buffer goes to another render thread, because there is none. [?] The GPU queue depth (frames in flight). |
| Frame limiter fn 0xA4F530 (decrypted in memory) | [O] It applies `optionfpslimit`, raising values from 0 to 30 up to 30. When the window is not active the cap is 15 fps, and when minimized 5. Each frame it sleeps with `Sleep(1)` until 2 ms are left, then spins on `Sleep(0)`. Losing focus therefore cuts the main thread to about 30 % and must be avoided in measurements. |

**What it means for legacy** [I]:
- **DE's D3D11 port is not multi-threaded rendering.** It has no render thread and no deferred contexts, and
  its main thread still runs update then render each frame, like legacy. Its D3D11 calls cost about 0.4 ms
  per frame, close to legacy's D3D9 calls (0.49 ms above). D3D11 alone did not buy DE more cores.
- **The render's share of DE's frame is smaller** than legacy's: 4.1 of 13.4 busy ms against 2.7 of
  4.96 here (and 5.4 of 9.7 in the §9 battle). Likely reasons: GPU instancing (indirect draws, compute) and
  particles moved to a worker pool.
- **What DE runs in parallel is the "split work inside the render" row above:**
  - particles on a pool, kicked from the render and simulated alongside the next update;
  - engine fork/join jobs (terrain, model instances);
  - sound decoding on its own thread.

  That is the path to copy, starting with particles. DE gives no precedent for a render thread fed by a
  simulation snapshot.
- **DE's simulation still dominates its frame:** 9.0 ms, 67 % of busy time.

### Recommendation (2026-11-10)

1. **Not a Direct3D 11 renderer.** All of legacy's D3D9 calls cost 0.49 ms of a 4.96 ms frame (≤ +11 % even if
   free), a D3D9→D3D11 wrapper lost 5–8 % and DXVK 14 % (28 % at 4K), and DE's own D3D11 port did not make it multi-threaded.

   **Update (2026-11-10, 10:55): DXVK with one option is faster than stock.** `d3d9.cachedWriteOnlyBuffers = True`
   gave +14 % at 2560×1600, +18 % at 3840×2160 and +14 % at 720p ("A/B runs"). That does not change this point: it
   is a wrapper, not a renderer to write, and half of its gain is a read-back loop of the game (0x40D25B) that
   stock D3D9 also pays for. Two things follow: (a) DXVK with that option is worth offering as an optional,
   user-side setup once a multiplayer game and a full-length game have been run with it; (b) the loop is a
   candidate for a small DLL key on stock D3D9 (≤ 6–7 % [I]; §10).
2. **Not a render thread fed by a snapshot.** It is the only large prize (+75–80 % [I]), but the render and the
   simulation write each other's objects, a race there is a desync, and DE never did it either.
3. **Yes, split work inside the render, the way DE does, starting with particles:** the particle update on a
   worker during pass 0, one call site (0x408498) and a join before pass 1, visual only (≤ +12 % [I]). If it holds
   up in game, A/B and an AI skirmish, the CPU preparation of the world passes is the next step (≤ +30 % with
   particles [I]), with the bounding-box and bit writes of the pass-0 walk to solve first.

   **Result (2026-11-10): not built.** The safety check below found two blockers before any code was written:
   pass 0 draws the particles of the same frame, and the particle update and the world draw both run the pose
   code 0x407272, which writes a global pose buffer, a global matrix and a global cache. The allocator is not a
   blocker. No overlap is left that would beat the ±3 % noise, so the prize of point 3 is gone for particles.

### particleWorker: safety check (2026-11-10)

The planned key `particleWorker`: at 0x408498 hand the particle update 0x408AAB to a worker thread, go on with
pass 0, join before pass 1 (the call 0x40BB9B, `push 1` / `call 0x40BCF0`, `ecx = [[0xC66244]+60h]`). The check
came first, as asked. Evidence: REA bundle `rea/evidence/age3y-b1a1dab7/particleworker-20261110.json` (33 records),
runtime files and scripts in `particleworker-20261110/`.

**Frame order** [O] (`ev_b43a5f13…`, `ev_9632d14a…`): 0x408488 `0x408FEB` on the particle manager
`[[0xC66240]+C1A0h]` → 0x408498 particle update → 0x4084A3 a loop over `[[0xC66240]+C1A4h]` (0xAD9032 per item)
→ `IsIconic` (0x4084DE) → world render 0x40B9BA: pass 0 0x40BA32, 0x415B51, pass 1 0x40BB9B, then **the main
particle draw 0x40BC6E** (`0x418CFB(pos, 0, 0)`) → UI → Present.

**Blocker 1: pass 0 draws the particles of the same frame** [O].
- 0x418CFB is the particle draw (`ev_903075e4…`): it walks the manager's draw list `[mgr+154h]` / count `[mgr+158h]`,
  which the update fills (0x41C51B `add ecx,154h` / `call 0x401F74`), reads each emitter's particle state, and
  clears the count when its third argument is 0.
- Its callers are 0x40BAFE (the main draw, after pass 1), **0x4597A4** and 0x779CE9 (`ev_08f05b15…`). 0x4597A4 is
  pass 0's world view (§11; containment `ev_51672f93…`): after the world draw it calls `0x418CFB(0xC6657C, ebx, 1)`
  at 0x459C70, a filtered draw (emitters whose type has byte `+45h` set) that keeps the list.
- Runtime (`trace-pose.txt`, 30 s of `uhcbench25`): 0x459C70 ran **619 times, as often as the main draw 0x40BC6E
  (619)**: every frame. The join would have to come before 0x459C70, not before pass 1.

**Blocker 2: the pose code's global buffers** [O].
- The update places emitters attached to model bones: 0x408E36 → 0x408F21 → 0x423ED3 → 0x423C6E → 0x407380 /
  0x407272 (call graph `ev_31f599cd…`, 582 functions reachable by direct calls; plus an indirect callback
  through `[0xC665DC]` at 0x423F8A whose targets are unknown [?]).
- 0x407272 (`ev_f83d7cd0…`) is the shared "world matrix of a model bone" helper. On a miss it calls
  `GrannySampleModelAnimations(instance, 0, bone+1, [[0xC67318]+8])` into **one global local pose**, then
  `GrannyGetWorldMatrixFromLocalPose(…, 0xC6FC38)` into **one global matrix**, and copies 40h bytes into an entry
  of **the global cache `[0xC67318]`** (0x405C49 lookup with create = 1, then 0x422E81). None of it is locked.
- The world draw of pass 0 runs the same helper per model batch (0x4510C3 → 0x44EA4B → 0x407380 → 0x407272, §11).
  Runtime, same 30 s: 0x407272 ran 127,157 times (≈ 205 per frame); by caller chain [I, stack-scanned] about
  42,400 came through 0x423D55 (the particle path) and 72,600 through 0x44EA8C / 0x451446 (the draw). The two would
  run at the same time on one global pose and one global matrix: wrong bone matrices at best, a corrupted cache
  entry at worst.
- The simulation also reads this cache: 0x49CDD5 → 0x422CDD (§11's terrain-effect placement, 3,200 hits in the
  trace). A cache entry torn by the race could therefore reach the simulation later [I]: a desync risk, not only a
  visual one.

**Not a blocker: the allocator** [O].
- Every `new` goes through `0x401234` with `ecx = 0xC66010` (`ev_58499e96…`, `ev_dc3e6cc9…`). At runtime that
  object's vtable is at 0x1000D188, in `rockalldll.dll` (base 0x10000000). Its alloc slot (+14h) calls the heap's
  bucket allocator 0x1000AB30, which takes a lock (`lock cmpxchg`; on contention 0x100070F0, a wait [I]: the DLL
  imports `CreateSemaphoreA` and `WaitForSingleObject`) when the lock object's byte `+20h` is set (`alloc.txt`).
- In the running game every bucket from 4 to 8,192 bytes has that byte at 1 and no owner thread (`lockflag.txt`).
  The path above 32,768 bytes (0x1000ACC0) was not read [?].

**What overlap is left** [I]. Joining before 0x459C70 still leaves the world draw of pass 0 (0.50 of its 0.70 ms)
in the window, and that is where blocker 2 sits. Before the world draw only the 0x4084A3 loop, the pass-0 walk
and the frustum test remain, about 0.2 ms. At most about 4 % even if perfect, inside the ±3 % noise of these runs,
and the 582-function update was not audited against them. A lock around 0x407272 would serialize a third of the
update's pose calls against the draw's, and would still leave the unaudited rest.

**Other overlaps** [I]: after Present against the next simulation update is worse. The simulation reads the same
pose cache (above) and creates and removes emitters: code outside the render reaches `[[0xC66240]+C1A0h]`, e.g.
0x4CAB7C, 0x4E3D77, 0x9D8226, 0x9F91A6 (`cs`, `finddisp.py`).

**Verdict:** `particleWorker` is not safe as specified and was not built. Nothing in `src/` changed. Making the
particle update thread-safe would mean giving the pose helper per-thread buffers and a locked cache (or a
per-thread copy of 0x407272 inside the DLL), splitting the pass-0 particle draw out of the window, and auditing the
rest of the update's 582 functions. That is the restructuring §9 rejected, for ≤ 12 % in the best case.

Runtime commands (bed `C:\AoE3-UHC-Test`, one game, nothing else running):
```
python -I tools/legacybench.py trace-particles --bed C:/AoE3-UHC-Test --seconds 150 --hz 0
set UHC_GAME_DIR=C:\AoE3-UHC-Test
python -I tools/re/trace_exec.py trace-pose.txt 0x407272=pose 0x423c6e=emitter-attach 0x459c70=pass0-particle-draw 0x40bc6e=main-particle-draw --minutes 0.5 --max-per-chain 2
python -I rea/evidence/age3y-b1a1dab7/particleworker-20261110/allocprobe.py <pid>
python -I rea/evidence/age3y-b1a1dab7/particleworker-20261110/lockflag.py <pid>
```
The tracer was started while the bench recorded and detached by itself after 30 s; the game went on and closed
normally (the §11 incident did not repeat).

### To reproduce

```
git apply rea/evidence/age3y-b1a1dab7/multicore-20261110/probe.patch      # local only, never commit
cmake --build build --config Release                                      # copy UHC.dll to the bed
python -I rea/evidence/age3y-b1a1dab7/multicore-20261110/bench2.py <label> [--probe] [--res WxH] [--devflags hw|nomt] [--set <profile option>=<value>] --seconds 60
python -I rea/evidence/age3y-b1a1dab7/multicore-20261110/summ.py <label> ...        # FPS, CPU, GPU per run
python -I rea/evidence/age3y-b1a1dab7/multicore-20261110/probeparse.py <label>      # per-pass ms from <label>.UHC.log
git checkout -- src/features/perf.cpp
```

`bench2.py` edits the shared profile (resolution, options): back it up first. The bed's cfg needs `perfStats`
and `perfExecFile`.

DXVK (labels `vk-*`; no probe build, the bed's normal `UHC.dll`). `bench2.py` passes its environment to the game:
```
mkdir <scratch>\dxvk && tar -xzf dxvk-3.1.1.tar.gz -C <scratch>\dxvk                # from github.com/doitsujin/dxvk/releases
python -I rea/evidence/age3y-b1a1dab7/multicore-20261110/bench2.py vk-base1 --seconds 60   # and vk-base2, no d3d9.dll
copy <scratch>\dxvk\dxvk-3.1.1\x32\d3d9.dll C:\AoE3-UHC-Test\
set DXVK_SHADER_CACHE_PATH=<empty dir>\cache
set __GL_SHADER_DISK_CACHE_PATH=<empty dir>\nvcache
set DXVK_LOG_PATH=<empty dir>\log
python -I rea/evidence/age3y-b1a1dab7/multicore-20261110/bench2.py vk-dxvk-cold --seconds 60
python -I rea/evidence/age3y-b1a1dab7/multicore-20261110/bench2.py vk-dxvk-warm1 --seconds 60   # and warm2; vk-dxvk-720 with --res 1280x720
del C:\AoE3-UHC-Test\d3d9.dll                                                          # then vk-base-720 with --res 1280x720
python -I rea/evidence/age3y-b1a1dab7/multicore-20261110/summ.py vk-base1 vk-base2 vk-dxvk-cold vk-dxvk-warm1 vk-dxvk-warm2 vk-base-720 vk-dxvk-720
```
The option runs (labels `vk2-*`) use `dxvk-20261110/runconf.sh <label> base|dxvk <WxH> ["<dxvk.conf line>" ...]`:
it copies `d3d9.dll` and writes `dxvk.conf` into the bed, runs `bench2.py`, takes a screen grab 30 s into the
recording (`screengrab.py`; the window must not be covered), logs the machine's other CPU use (`othercpu.py`),
prints the summary line, the FPU line and the share of 0x40D25B, and removes both files again. Its paths are
those of that session's scratch folder: edit them first.
```
bash rea/evidence/age3y-b1a1dab7/dxvk-20261110/runconf.sh vk2-base1 base 2560x1600
bash rea/evidence/age3y-b1a1dab7/dxvk-20261110/runconf.sh vk2-cached dxvk 2560x1600 "d3d9.cachedWriteOnlyBuffers = True"
bash rea/evidence/age3y-b1a1dab7/dxvk-20261110/runconf.sh vk2-nodirect dxvk 2560x1600 "d3d9.allowDirectBufferMapping = False"
bash rea/evidence/age3y-b1a1dab7/dxvk-20261110/runconf.sh vk2-both dxvk 2560x1600 "d3d9.cachedWriteOnlyBuffers = True" "d3d9.allowDirectBufferMapping = False"
bash rea/evidence/age3y-b1a1dab7/dxvk-20261110/runconf.sh vk2-cached-4k dxvk 3840x2160 "d3d9.cachedWriteOnlyBuffers = True"   # and vk2-base-4k, vk2-*-720
```
DXVK's logs and the cold run's caches: `rea/evidence/age3y-b1a1dab7/dxvk-20261110/`. The module and function shares
are in each run's `.csv.samples.txt`.

**Incident.** After `tools/re/trace_writes.py` detached from a running bench, the game stopped presenting frames
with its main thread at 100 % (in `MultiByteToWideChar` / `CompareStringW`) and had to be killed. It is not known
whether the tracer caused it.

## Next steps

1. `bufferedFileReads` follow-ups:
   - a multiplayer game with one player using it and the other not, to show it may differ between
     players;
   - a timed load with and without it.
2. **The remaining stutter work.**
   - Find which granny calls take the remaining slow-frame samples: resolve the
     `granny2.dll` exports, as for `ntdll`.
   - Find what the simulation loads on first use; in-match file opens are in the `perfFileLog`
     output.
   - Then decide whether a preload is worth its memory, with Large-Address-Aware as a fallback.
3. The zero-code A/B runs (§10, cfg row).
4. Open questions:
   - which passes call the world draw 0x44FC96 under 0x408399: answered in §11 (pass 0 of the views and the
     main view), except what pass 0 renders;
   - what the `[world+148h]` loop 0x4910CF updates;
   - whether 0x94CF27 / 0x94DAE1 / 0x7F7E97 is the XS interpreter;
   - why `[world+FCh]` read about 12,800 minutes on `uhcbench25` (only its rate is used, as the sim clock);
   - the reader of `AlwaysActive`;
   - what `disableMidUpdateRender` changes at 0x482532;
   - whether any D3D call happens off the main thread: answered in §11 (yes, about 14 frames from
     another thread while loading, very likely the loading-screen thread; none during a match);
   - whether the simulation reads the fields the render writes (§11): the bounding box at `[unit+B4h]+34h`
     and bit 5 of `[[unit+4]+1]`.
5. Answered for single player: FUN_00771a3a and FUN_00b5a3f2 (§1) do not run during a match.
   - Neither appears in the 27,183 late-game samples of §9.
   - FUN_00771a3a is the wait for "outstanding ESO tasks": `SleepEx(1,1)` plus a `PeekMessageA` pump, for up
     to 30 s (`ev_109439de…`).
   - FUN_00b5a3f2 is the network spin, so it still needs a check in an online match.

The static claims in §1, §4 and §5 were re-checked from the raw bytes by an independent pass (2026-10-28).
It confirmed them and supplied the corrections already folded in above:
- the loading-screen thread;
- the sound-mixer loop;
- `SM_MEDIACENTER`;
- FPU_PRESERVE;
- the flush callers.
