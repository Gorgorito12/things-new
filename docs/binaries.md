# Binaries

Identity of every `age3y.exe` and loader binary found under
`C:\Program Files (x86)\Steam\steamapps\common\Age Of Empires 3` (surveyed 2026-10-27).
All findings here come from byte diffs against the stock exe, not from REA.

## age3y.exe builds

| Build | Size (B) | SHA-256 | Notes |
|---|---|---|---|
| **Stock Steam** (`bin\`) | 11,598,648 | `b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d` | Analysis target. Also shipped unchanged by Improvement Mod, Hundred Days, Age of Dynasties (Remake). |
| Wars of Liberty | 11,591,680 | `0a277f14e08df516fe1abd3fd9f8175b40664f3371793afff507f652d5067726` | Loader + extra patches (below). |
| Knights and Barbarians | 11,591,680 | `d21d0173c3028c190055ae1f14f9a4c282e8e58318975fc5d4cefdeb61a15df9` | Loader only. Its stored PE checksum (0xB11FCF) is stale; the contents give 0xB18410. |
| Test bed LAA copy (`C:\AoE3-UHC-Test\age3y-laa.exe`) | 11,591,680 | `8970565c2d3bd01ad5d96280271a2ca1cc6926b19d653fb7e541a2c146b1f611` | K&B exe + Large-Address-Aware (Characteristics 0x10F → 0x12F) + correct checksum 0xB18430. Made by `tools/set_laa.py` (2026-10-28). |
| Struggle of Indonesia | 11,598,648 | `25ec02bef535c8e6aabf5cc1706b8cd5a289e7e6ff79d223d037a3419a29d072` | Registry key rename only. |
| The Ottoman Empire | 11,598,648 | `962c716b33576223d1a5681d0df7285c27a02a69d1d2dc423d83b6509c21937f` | Registry key rename only. |

Stock layout: PE32 i386, ImageBase `0x400000`, no ASLR, no NX, not LAA, EP RVA `0x1876AC` (VA `0x5876AC`).
Raw offsets equal RVAs for `.text`, `.rdata`, `.data`, so file offset = VA − `0x400000` there. The
Authenticode certificate sits at file `0xB0E000`, size `0x1B38` (6,968 B).

## AoE3 Definitive Edition (comparison only)

| Build | Size (B) | SHA-256 | Notes |
|---|---|---|---|
| `AoE3DE\AoE3DE_s.exe`, Steam build 25969874, game 100.19.18658.0 | 59,276,600 | `31fad98fc4fd82b4b7b3049b131b37be6918022e4637a4075c7ec7a119bd8cab` | PE32+ x64, studied read-only in [de-architecture.md](de-architecture.md). About 42 % of its functions are encrypted on disk by a protection layer. |

## Loader patch (Patch.uhc, upstream v1.6+)

A loader exe is the stock exe with the certificate removed (`ImageRemoveCertificate`, hence −6,968 B)
plus three byte records. **The import table is not touched.**

| File offset | VA | Change |
|---|---|---|
| `0x170` | header | AddressOfEntryPoint `0x1876AC` → `0x7836BE` |
| `0x1A0` | header | CheckSum recomputed |
| `0x1E1` | header | Security data directory zeroed |
| `0x7836BE` | `0xB836BE` | 79-byte stub in `.text` slack (below) |
| `0x865016` | `0xC65016` | Strings in `.rdata` slack: `"UHC.dll"`, `"_UHCMain@0"`, `L"Failed to load UHC.dll!"`, `L"Initialization Error"`, `L"Startup\uhc.cfg"` |
| `0x865083` | `0xC65083` | Config path the DLL reads (≤20 wchar, default `Startup\uhc.cfg`) |

Stub at VA `0xB836BE`:

```
push 0xC65016            ; "UHC.dll"
call [0xB84228]          ; LoadLibraryA
test eax, eax
jz   fail
push 0xC6501E            ; "_UHCMain@0"
push eax
call [0xB84354]          ; GetProcAddress
test eax, eax
jz   fail
call eax                 ; UHCMain() — runs before the game's own entry code
mov  eax, [0xC66228]
jmp  0x5876AC            ; original entry point
fail:
push 0x10 / push 0xC65059 / push 0xC65029 / push 0
call [0xB8459C]          ; MessageBoxW
push 0
call [0xB8438C]          ; ExitProcess
```

## Extra patches in the Wars of Liberty exe

| File offset | VA | Stock → WoL |
|---|---|---|
| `0x15E` | header | Characteristics `0x10F` → `0x12F` (Large-Address-Aware on) |
| `0x7E3A9C` | `0xBE3A9C` | `L"AI3\"` → `L"AI4\"` (AI folder; string starts at `0xBE3A98`) |
| `0x7E3ABC`, `0x7E3ADC` | `0xBE3ABC`, `0xBE3ADC` | `L"RM3\groupings\"` / `L"RM3\"` → `RM4` (random-map folders) |
| `0x839568` | `0xC39568` | `"eso.com"` → `"age3.us"` (online host) |

## Registry key strings (renamed by SoI / Ottoman)

`Software\Microsoft\Microsoft Games\Age of Empires 3 Expansion Pack 2\1.0` appears three times:
wide at VA `0xBA3900` and `0xC3A1E0`, ANSI at `0xBE3890`. SoI and Ottoman overwrite all three in
place (same length or shorter) and change nothing else; their certificate is left in place but no
longer valid.

## Loader DLLs and tools

| File | Size (B) | SHA-256 |
|---|---|---|
| `Wars of Liberty\uhc.dll` | 1,187,840 | `c070d138c2b4ead70ef07f44dae57a6667ffc53b59a178ddade39db48e01efb2` |
| `Knights and Barbarians\UHC.DLL` | 380,416 | `ddb31bb41a831098ed9dc907d6bbef3a5df6735b8175311dd7e44da3fa4282b8` |
| `Knights and Barbarians\Startup\UHCPatcher.exe` | 43,520 | `9a3afc7647091949ff8eb67ea05d4924a22a6e061d3805c1895abd74fbab7337` |

The WoL DLL implements options that are not in upstream (e.g. `noAILimitV2`); its source is not
public.
