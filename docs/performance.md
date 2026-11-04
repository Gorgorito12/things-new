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
  - DXVK lowers FPS by 28 %.
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
- **DXVK makes it worse here: −28 % FPS and +230 MB of address space.**
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
  main thread still saturates in a battle (91–95 %), and the simulation is still on it. It adds a render
  thread (45–61 % of a core), a PopcornFX particle pool and streaming texture loads; in total it uses
  about 2.1 cores. The render-thread part is the "pipelining" ruled out above for a binary patch.
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
| Moving render-side work to other threads | DLL feature | Rejected for now (§9): at most about +30 % FPS even if perfect, and it needs a restructuring of exe code. |
| More skinning workers (`deformWorkers`), plus letting them help during the flush | DLL feature | Not built. The late-game A/B puts skinning at 1–3 % of the main thread. |
| Device flags: drop MULTITHREADED, HARDWARE vertex processing, back buffers | DLL feature, opt-in | Not built. d3d9.dll is about 3 % of the main thread. Back buffers only matter with vsync on. |
| Frame-time statistics and device logging (`perfStats`) | DLL feature, passive | Implemented (`src/features/perf.cpp`). Version 2 also records the QPC window of every frame over 50 ms. Read by `tools/perfprobe.py`, which also profiles the main thread's stack (§9). |
| Large-Address-Aware on the test exe | header bit | Planned: `tools/set_laa.py`. |
| `-demandLoadMeshes`, `megaPostLoadForceTextures`, `useDeviceReset` | cfg | Planned A/B. |
| DXVK | wrapper | Measured: −28 % FPS in a late game. FPU state kept (0x007F). Not recommended. |
| `RunAsFastAsPossible`, `fixedUpdate`, `MinRandUpdate`, `syncUpdateInterval`, the 100 ms cap | — | Rejected: they change the simulation. |

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
   - which passes call the world draw 0x44FC96 under 0x408399 (shadows, reflections?);
   - what the `[world+148h]` loop 0x4910CF updates;
   - whether 0x94CF27 / 0x94DAE1 / 0x7F7E97 is the XS interpreter;
   - why `[world+FCh]` read about 12,800 minutes on `uhcbench25` (only its rate is used, as the sim clock);
   - the reader of `AlwaysActive`;
   - what `disableMidUpdateRender` changes at 0x482532;
   - whether any D3D call happens off the main thread (the loading-screen thread is a candidate).
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
