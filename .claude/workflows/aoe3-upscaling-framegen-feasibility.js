export const meta = {
  name: 'aoe3-upscaling-framegen-feasibility',
  description: 'Read-only research: can DLSS, FSR, frame generation and similar work for legacy AoE3 (D3D9), with adversarial verification',
  phases: [
    { title: 'Research', detail: 'upscalers, frame generation, engine fit (parallel)' },
    { title: 'Verify', detail: 'one adversarial verifier per research report' },
  ],
}

const CONTEXT = `
Context (facts already measured in this project; treat as given):
- Target: Age of Empires III: The Asian Dynasties, legacy 2009 Steam build, age3y.exe (PE32 x86, no ASLR, not large-address-aware).
  Renderer: Direct3D 9 only. One main thread runs simulation, AI, rendering and every D3D9 call; one helper thread skins meshes.
- Repo: the current working directory. UHC.dll is our in-process DLL loaded before the game's code; src/features/perf.cpp already hooks Direct3DCreate9 (IAT), CreateDevice, Reset and Present (vtable) for frame statistics. docs/performance.md has the measurements (sections 5 Direct3D 9, 8 runtime observations, 9 frame structure / stack sampling, 10 levers).
- Measurements: the game is CPU-bound. Late 8-AI game at 2560x1600 windowed, vsync off: 108.6 FPS mean, main thread 95 % of one core, GPU 3D engine 10-13 % (also at 3840x2160) on an RTX 4090. At the save's default camera: about 195 FPS. Frame split: update (simulation) 43.5 %, render 55.6 % of the main thread, all CPU time. DXVK lowered FPS by 28 %.
- The user's problems: "lag" in big games (single-player sim steps cover real time up to 100 ms; when a frame takes longer, game time falls behind) and stutters (frames of 100-250 ms from file loads and granny model/animation setup on first use; bufferedFileReads already cut them from 11 to 3 per 150 s).
- Hardware: NVIDIA GeForce RTX 4090, Windows driver version 32.0.16.1692; an AMD Radeon integrated GPU also present (not driving the display); monitor max refresh 120 Hz (currently 2560x1440 at 59 Hz). Windows 11. Nothing like Lossless Scaling, Magpie, ReShade, PresentMon, Special K or dgVoodoo is installed.
- Constraints: multiplayer-safe only (no change to the simulation); no third-party SDK code may be copied into UHC.dll without a compatible license; the Steam install must never be modified.
- Today is 2026-10-28. Vendor features changed a lot in 2024-2026; prefer primary sources (NVIDIA, AMD, Intel, GPUOpen, GitHub repos, official docs) and give dates/versions.
STRICTLY READ-ONLY: do not install, download-and-run, launch the game, or write/edit any file. Reading repo files, web search and web fetch only.
`

const RESEARCH_SCHEMA = {
  type: 'object',
  properties: {
    topic: { type: 'string' },
    summary: { type: 'string' },
    claims: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          claim: { type: 'string' },
          kind: { type: 'string', enum: ['observed', 'inferred', 'unknown'] },
          evidence: { type: 'string' },
          sources: { type: 'array', items: { type: 'string' } },
        },
        required: ['id', 'claim', 'kind', 'evidence'],
      },
    },
    options: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          works_with_d3d9_aoe3: { type: 'string' },
          needs_code_in_uhc: { type: 'string' },
          expected_benefit_here: { type: 'string' },
          costs_and_risks: { type: 'string' },
        },
        required: ['name', 'works_with_d3d9_aoe3', 'needs_code_in_uhc', 'expected_benefit_here', 'costs_and_risks'],
      },
    },
    unknowns: { type: 'array', items: { type: 'string' } },
  },
  required: ['topic', 'summary', 'claims', 'options', 'unknowns'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    verdicts: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          verdict: { type: 'string', enum: ['confirmed', 'refuted', 'unclear'] },
          notes: { type: 'string' },
        },
        required: ['id', 'verdict', 'notes'],
      },
    },
    missed: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdicts', 'missed'],
}

const TOPICS = [
  {
    key: 'upscalers',
    prompt: `${CONTEXT}
Question A - UPSCALERS and image-quality tech for this game: NVIDIA DLSS Super Resolution / Ray Reconstruction / DLAA, NVIDIA Image Scaling (NIS), AMD FSR 1, FSR 2, FSR 3.x upscaling, FSR 4, AMD CAS, Intel XeSS, plus driver-side options (NVIDIA DSR/DLDSR, forced MSAA/SGSSAA through NVIDIA Profile Inspector, AMD RSR/VSR).
For each: which graphics APIs it supports (is D3D9 possible at all?), what engine data it needs (motion vectors, depth, camera jitter, exposure, separate UI pass), GPU/vendor requirements, license of any SDK or shader (could UHC.dll legally include it?), and known ways people apply it to old D3D9 games without source code (ReShade shaders, Magpie, dgVoodoo2 or DXVK as a bridge, OptiScaler, Special K).
Then judge, for THIS game (CPU-bound, GPU at 10-13 % on an RTX 4090), whether each would raise FPS, reduce lag or stutter, or only change image quality. Be concrete and cite sources with dates.`,
  },
  {
    key: 'framegen',
    prompt: `${CONTEXT}
Question B - FRAME GENERATION for this game: NVIDIA DLSS Frame Generation and Multi Frame Generation, NVIDIA Smooth Motion (driver-level), AMD FSR 3 / 3.1 frame generation, AMD Fluid Motion Frames (AFMF 1/2/2.1+), Lossless Scaling (LSFG 2/3), OptiScaler's frame generation, Intel XeSS Frame Generation.
For each: supported APIs (D3D9? D3D11? D3D12? Vulkan? any window?), GPU requirements (does an RTX 4090 qualify for Smooth Motion as of late 2026? which driver version added RTX 40 support, if any?), required engine inputs (motion vectors, depth, UI separation), latency added, what happens when the base frame rate is ALREADY above the monitor refresh (here 108-195 FPS vs a 120 Hz max monitor), what happens during a single long hitch of 100-250 ms (can interpolation hide it?), and what happens to the simulation lag (game time falling behind when frames exceed 100 ms).
Also: could a D3D9 game reach a driver-level FG through a D3D9->D3D11/D3D12/Vulkan bridge (dgVoodoo2, DXVK, D3D9On12), and what that bridge costs (DXVK already measured at -28 % FPS here)?
Judge the real benefit for this game and this hardware. Cite primary sources with dates.`,
  },
  {
    key: 'enginefit',
    prompt: `${CONTEXT}
Question C - ENGINE FIT, from the repository only (read docs/performance.md sections 1, 5, 8, 9, 10; src/features/perf.cpp; docs/engine-symbols.md section "Rendering, threads and timing"; docs/how-it-works.md if useful).
Answer with file:line citations:
1. What UHC.dll can already intercept on the D3D9 path (Direct3DCreate9, CreateDevice, Reset, Present) and what device/back-buffer parameters the game uses (windowed, swap effect, back buffer count, formats, presentation interval, MULTITHREADED/MIXED vertex processing).
2. Whether the game exposes anything a temporal upscaler or engine-integrated frame generation needs: motion vectors, a readable depth buffer (D3D9 needs INTZ/RAWZ for that), camera jitter, a UI pass separate from the 3D world pass. Is there any render-scale or internal-resolution option? (Search the docs and the cfg/config-variable notes.)
3. What an in-DLL post-process at Present (e.g. a spatial upscale such as FSR 1 EASU+RCAS, or sharpening/AA such as CAS/SMAA) would have to do in D3D9: copying the back buffer (StretchRect/GetBackBuffer), pixel shader model available on the device, state save/restore, interaction with the UI (drawn into the same back buffer?), mouse coordinates if the back buffer were made smaller than the window, and its CPU cost on a main thread that is already at 95 %.
4. Which of the repo's measured numbers decide whether upscaling or frame generation can help this game at all (CPU-bound proof, GPU %, frame time split), and whether a cheap measurement would settle it (e.g. the same benchmark at a much lower resolution: if FPS does not change, upscaling cannot raise it). tools/legacybench.py and tools/perfprobe.py can run such a benchmark unattended; describe, do not run.
Mark each claim observed (from the files) or inferred.`,
  },
]

const results = await pipeline(
  TOPICS,
  t => agent(t.prompt, { label: `research:${t.key}`, phase: 'Research', schema: RESEARCH_SCHEMA, agentType: 'Explore' }),
  (found, t) => agent(`${CONTEXT}
You are an adversarial verifier. Another agent researched topic "${t.key}" for this game and returned the JSON below.
For EVERY claim, try to refute it from primary sources (vendor docs, GPUOpen, NVIDIA developer pages, GitHub repos, driver release notes) or, for repository claims, from the files themselves. Pay special attention to: API support lists, GPU-generation requirements, dates and driver versions, license terms, and whether "works with D3D9" is really true. Default to "unclear" when you cannot check a claim, and to "refuted" when a source contradicts it. Also list important facts the researcher missed.
Research JSON:
${JSON.stringify(found)}`, { label: `verify:${t.key}`, phase: 'Verify', schema: VERDICT_SCHEMA, agentType: 'Explore' })
    .then(v => ({ topic: t.key, found, verdicts: v })),
)
return results.filter(Boolean)
