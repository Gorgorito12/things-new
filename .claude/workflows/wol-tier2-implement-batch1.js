export const meta = {
  name: 'wol-tier2-implement-batch1',
  description: 'Implement 7 WoL Tier 2 requests as opt-in UHC.dll features, each in its own copy of the repo, built and self-checked',
  phases: [{ title: 'Implement', detail: 'one agent per request: isolated copy, code, build, site checks, docs draft, test plan' }],
}

const REPO = String.raw`C:\Users\Jeison\Documents\GitHub\Unharcoded-AOE3- NEW`
const SCRATCH = String.raw`C:\Users\Jeison\AppData\Local\Temp\claude\C--Users-Jeison-Documents-GitHub-Unharcoded-AOE3--NEW\46abd73e-673c-487a-b3c4-39b183d75b79\scratchpad`
const VENV_PY = SCRATCH + String.raw`\venv\Scripts\python.exe`
const CMAKE = String.raw`C:\Program Files\Microsoft Visual Studio\18\Insiders\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe`
const STEAM_EXE = String.raw`C:\Program Files (x86)\Steam\steamapps\common\Age Of Empires 3\bin\age3y.exe`

const ITEMS = [
  { n: '05', slug: 'workrate', key: 'liveBuildingWorkRate', cpp: 'workrate.cpp', asm: 'workrate_hooks.asm', fn: 'ApplyLiveBuildingWorkRate' },
  { n: '06', slug: 'techprereq', key: 'techPrereqRecheck', cpp: 'techprereq.cpp', asm: 'techprereq_hooks.asm', fn: 'ApplyTechPrereqRecheck' },
  { n: '08', slug: 'maintain', key: 'maintainWaitForPop', cpp: 'maintain.cpp', asm: 'maintain_hooks.asm', fn: 'ApplyMaintainWaitForPop' },
  { n: '10', slug: 'transform', key: 'transformUpdatesLOS', cpp: 'transform.cpp', asm: 'transform_hooks.asm', fn: 'ApplyTransformUpdatesLos' },
  { n: '15', slug: 'broadside', key: 'broadsideMuzzleLimit', cpp: 'broadside.cpp', asm: 'broadside_hooks.asm', fn: 'ApplyBroadsideMuzzleLimit' },
  { n: '16', slug: 'abilityslots', key: 'abilitySlots', cpp: 'abilityslots.cpp', asm: 'abilityslot_hooks.asm', fn: 'ApplyAbilitySlots' },
  { n: '20', slug: 'wonderpanel', key: 'wonderPanelSkipAuras', cpp: 'wonderpanel.cpp', asm: 'wonderpanel_hooks.asm', fn: 'ApplyWonderPanelSkipAuras' },
]

const RESULT = {
  type: 'object',
  properties: {
    status: { type: 'string', enum: ['built', 'blocked'] },
    key: { type: 'string' },
    cfgSyntax: { type: 'string' },
    copyDir: { type: 'string' },
    newFiles: { type: 'array', items: { type: 'string' } },
    genSitesLines: { type: 'string', description: 'the exact lines appended to SITES in tools/gen_sites.py, with their comments' },
    featuresH: { type: 'string', description: 'the exact declaration, kFeatures entry and kHandledKeys additions' },
    logLines: { type: 'array', items: { type: 'string' } },
    deviations: { type: 'string', description: 'where the code departs from the report FIX / VERIFIER CORRECTIONS, and why' },
    risks: { type: 'string', description: 'what only the in-game test can settle' },
    build: { type: 'string', description: 'warning and error counts, export check, hook disassembly check' },
    docsDraft: { type: 'string', description: 'absolute path of DOCS-DRAFT.md' },
  },
  required: ['status', 'key', 'cfgSyntax', 'copyDir', 'newFiles', 'genSitesLines', 'featuresH', 'logLines', 'deviations', 'risks', 'build', 'docsDraft'],
}

function prompt(it) {
  const COPY = `${SCRATCH}\\impl\\item${it.n}-${it.slug}`
  return `You implement ONE feature request from the Wars of Liberty (WoL) mod as an opt-in feature of the UHC.dll project, in a private copy of the repository. Request #${it.n}; its title is the first line of the report below.

INPUT
- The scoping report with the verified design: ${SCRATCH}\\t2\\report-${it.n}.md. Read all of it. Sections: FIX (the proposed design), SITES, VERIFIER CORRECTIONS (an independent verifier's fixes; they override FIX where they disagree), MISSED PATHS, SITE CHECKS, RECOMMENDATION, TEST PLAN, OPEN QUESTIONS, MECHANISM. Helper scripts and raw outputs of that scoping are in ${SCRATCH}\\t2\\item${it.n} and ${SCRATCH}\\t2\\item${it.n}-verify.
- Proposed names (keep them unless the report's corrections give a reason): cfg key \`${it.key}\`, files src/features/${it.cpp} and src/hooks/${it.asm}, apply function uhc::${it.fn}. Implement the design the RECOMMENDATION and VERIFIER CORRECTIONS settle on; if the report leaves a choice open, take the smallest safe option and say so in deviations.

SETUP
1. Make your copy with the PowerShell tool (robocopy exit codes below 8 are success):
   robocopy "${REPO}" "${COPY}" /E /XD build rea reference .git .claude dist /NFL /NDL /NJH /NJS /NP
   Work ONLY inside ${COPY}. Never write to ${REPO}, to the Steam install, or to any C:\\AoE3-UHC-* folder.
2. Read the patterns you must follow, in the copy: src/features/dodge.cpp + src/hooks/dodge_hooks.asm (marker unit type, "[UnitType] [log]" arguments, VerifyAll before any write, log lines), src/features/heal.cpp + src/hooks/heal_hooks.asm, src/hooks/common.inc (TRACE_ONCE), src/patch.h, src/unittypes.h (RequestAbstractUnitType, OnDatabaseLoad), src/config.h, src/features.h, tools/gen_sites.py, CMakeLists.txt.

RULES
- No REA / MCP calls: one shared Ghidra session serves another agent (CLAUDE.md: run REA calls sequentially, never fanned out). For byte checks use the read-only capstone helpers on the stock exe:
  "${VENV_PY}" -I "${SCRATCH}\\x86.py" d <va hex> <nbytes>      (disassemble)
  "${VENV_PY}" -I "${SCRATCH}\\x86.py" callers <va hex>        (E8/E9 sites targeting va)
  "${VENV_PY}" -I "${SCRATCH}\\x86.py" refs <dword hex>        (.text places containing the dword)
  "${VENV_PY}" -I "${SCRATCH}\\sitecheck.py" <va>:<len> ...    (instruction boundary + branches into the overwritten range)
  plus the report's own evidence.
- Never launch the game and never run tools/testbed.py launch/scenario/exec/deploy/map: the single game slot belongs to the coordinator, who runs your test plan later. No git commands at all.
- Hook conventions (CLAUDE.md "Layout"): a 5-byte jmp (or a redirected call) at a verified instruction boundary, NOP-filled to the stolen length by WriteJmp; the hook re-executes or replaces the stolen instructions itself and leaves through an explicit jmp to a verified continuation stored as a dd in .data; TRACE_ONCE "${it.key} (0x<VA>)" first in every hook; preserve every register and flag that the stock code after the continuation reads (disassemble past the continuation to check); balance the stack; C++ helpers called from MASM are extern "C" __stdcall with a matching PROTO STDCALL.
- Every site the feature writes or depends on (continuation targets and any instruction a hook assumes included) goes into SITES in tools/gen_sites.py with a comment in the existing style, is regenerated with: python -I tools/gen_sites.py "${STEAM_EXE}"   (it only reads the exe), and is checked by one VerifyAll before the first write.
- Opt-in and failure-safe: nothing is patched unless the key is in uhc.cfg; validate every argument and log a clear "...; feature not applied" reason; return Outcome::kFailed on any failure.
- A simulation change must be deterministic for multiplayer: it depends only on game state, never on the local player, UI state, wall-clock time or a non-game RNG. A UI-only feature may read the local player.
- Give the feature a \`log\` argument whose lines prove in game that the new behaviour happened (one line per event; rate-limit or log once per unit if the event can fire every frame), like "dodgeAnyUnit: unit %d (%hs) dodged a hit". The startup line of a simulation change ends with "(multiplayer unverified)".
- Match the surrounding code: a header comment explaining the stock behaviour and the change, the same comment density and naming, /W4 clean. A .asm file must not share a base name with any .cpp.
- Register the feature in the copy: src/features.h (declaration, kFeatures entry after the dodge entry, lowercase key(s) in kHandledKeys), CMakeLists.txt (both files, alphabetical), examples/Startup/uhc.cfg (a commented block like the others), and the README.txt key list inside tools/package_release.py.

BUILD AND CHECK
- Configure and build the copy (cmake is not on PATH):
  "${CMAKE}" -S "${COPY}" -B "${COPY}\\build" -G "Visual Studio 18 2026" -A Win32
  "${CMAKE}" --build "${COPY}\\build" --config Release
  Zero warnings and zero errors. Check the export with dumpbin (under C:\\Program Files\\Microsoft Visual Studio\\18\\Insiders\\VC\\Tools\\MSVC\\*\\bin\\Hostx64\\x86\\dumpbin.exe) /exports: it must list _UHCMain@0.
- Disassemble your built hooks (dumpbin /disasm on the DLL, or capstone) and check them once more against the stock code: stolen instructions, flags, stack, continuation addresses.

DELIVERABLES (in the copy)
- The new source files and the registration edits above.
- ${COPY}\\DOCS-DRAFT.md with, in this order: (1) a README.md feature-table row; (2) a docs/modding-guide.md section, using the dodgeAnyUnit section there as the template (what it does, cfg syntax, data needed, log lines, limits, status "not tested in game"); (3) a docs/how-it-works.md section (the stock mechanism, the hooks, why it is safe); (4) docs/uhc-address-map.md "Beyond upstream" rows; (5) docs/engine-symbols.md rows (functions, globals and offsets the feature relies on; "confirmed" only where you checked the bytes); (6) docs/porting-to-another-dll.md site-table rows and the hook contract; (7) the TEST PLAN.
- TEST PLAN, for the coordinator: concrete steps with tools/testbed.py (read its docstring: map specs p<N>=Proto*count@x,z, tech<N>=Tech, go<N>=sec@x,z, size=, and \"at<seconds>=<Effect>;<Param>=<value>;...\" which runs any trigger effect of C:\\AoE3-UHC-Test\\trigger3\\typetest.xml once at that game time, e.g. Change Unit Type (in-place transform), Kill, Convert, Damage Unit, Unit Create, Set Tech Status, Unit Work, Grant Resources; values g<i> = every unit of the i-th p<N>= group, g<i>.<k> = one unit, tech:<Name>, pt:<x>,<z> - verified in game; then scenario, wait, units, log --grep, shot) and tools/protoy_testdata.py for marker unit types. Name the stock protos and techs to use and check they exist in the TAD data (read-only: C:\\AoE3-UHC-Test\\data\\protoy.xml and techtreey.xml), give the uhc.cfg lines, the exact UHC.log lines expected, what the control run (key off, or a marker that no unit has) must show, and any data edit or testbed extension the test needs (describe it; do not apply it).

Return the structured result. Keep its text fields short; the details belong in DOCS-DRAFT.md.`
}

phase('Implement')
const results = await parallel(ITEMS.map(it => () =>
  agent(prompt(it), { label: `impl #${it.n} ${it.key}`, phase: 'Implement', schema: RESULT })
    .then(r => (r ? { item: it.n, ...r } : { item: it.n, status: 'blocked', key: it.key, risks: 'agent returned nothing' }))
))
return results
