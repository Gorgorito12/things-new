# Performance: what limits CPU and GPU use

What in the stock `age3y.exe` (`b1a1dab7…`, see [binaries.md](binaries.md)) decides how much CPU and
GPU the game uses. It was written for the "late-game lag and stutter" investigation of 2026-10-28.

Everything below is **static** (Ghidra through REA, plus capstone on the file bytes) unless a row says otherwise.
No runtime measurement has been made yet; see "Next steps".

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

None of the non-zero waits is tied to the main thread's per-frame path. Two static candidates are left
for a runtime check (FUN_00771a3a, FUN_00b5a3f2).

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
  already running. On screen was an unknown scene, the profile was Low shaders, and UHC.dll had no `perfStats`,
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

## 9. Levers (multiplayer-safe), status

| Lever | Kind | Status |
|---|---|---|
| More skinning workers (`deformWorkers`), plus letting them help during the flush | UHC feature | Designed. The first sample (§8) shows the single worker at ~8 %, so it is deprioritized unless the benchmark disagrees. |
| Device flags: drop MULTITHREADED, HARDWARE vertex processing, back buffers | UHC feature, opt-in | Designed. Needs proof that no D3D call runs off the main thread and that `SetSoftwareVertexProcessing` is unused. Must keep the FPU behavior (§5). |
| Frame-time statistics and device logging (`perfStats`) | UHC feature, passive | Implemented (`src/features/perf.cpp`). Read by `tools/perfprobe.py`. |
| Large-Address-Aware on the test exe | header bit | Planned: `tools/set_laa.py`. |
| `-demandLoadMeshes`, `megaPostLoadForceTextures`, `useDeviceReset` | cfg | Planned A/B. |
| DXVK | wrapper | Planned A/B. Single-player only until its FPU handling is checked (§5). |
| `RunAsFastAsPossible`, `fixedUpdate`, `MinRandUpdate`, `syncUpdateInterval`, the 100 ms cap | — | Rejected: they change the simulation. |

## Next steps

1. **Runtime baseline** with `tools/perfprobe.py` in a recorded large battle. It records:
   - per-thread CPU, with threads named by start address;
   - GPU 3D-engine use;
   - working set;
   - jobs per second from `[0xC692E0]` / `[0xC692E4]`.

   The questions: is the main thread saturated, is the worker saturated, and how close is the process to 2 GB?
2. The zero-code A/B runs, then only the features the numbers justify.
3. Open questions:
   - the reader of `AlwaysActive`;
   - what `disableMidUpdateRender` changes at 0x482532;
   - whether any D3D call happens off the main thread (the loading-screen thread is a candidate);
   - whether FUN_00771a3a or FUN_00b5a3f2 (§1) runs on the main thread during a match.

The static claims in §1, §4 and §5 were re-checked from the raw bytes by an independent pass (2026-10-28).
It confirmed them and supplied the corrections already folded in above:
- the loading-screen thread;
- the sound-mixer loop;
- `SM_MEDIACENTER`;
- FPU_PRESERVE;
- the flush callers.
