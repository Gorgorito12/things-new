"""Emit src/generated/sites.h: the stock bytes UHC.dll expects at every patch site.

Usage: python -I tools/gen_sites.py <stock age3y.exe> [out.h]

The DLL compares live memory against these bytes before patching, so a site is only written
when the host really is the build documented in docs/uhc-address-map.md. Ranges cover the
bytes a feature overwrites or skips, plus the instruction it continues at.
"""
import hashlib
import pathlib
import sys

STOCK_SHA256 = "b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d"
IMAGE_BASE = 0x400000

# name, VA, length. For .text, .rdata and .data, file offset = VA - IMAGE_BASE.
SITES = [
    # removeConversionRestriction: je 9D5BADh
    ("ConversionRestriction", 0x9D5B6C, 2),
    # ignoreRegistryPath: jl 6420A1h, and the instruction at its target
    ("RegistryPath", 0x57CB54, 6),
    ("RegistryPathTarget", 0x6420A1, 4),
    # deckCardCount: the clamp at 0x7EF026..0x7EF02F plus its ret 4, and the
    # out-of-table path's mov eax,19h
    ("DeckLimit", 0x7EF026, 13),
    ("DeckOutOfRange", 0x7EF005, 5),
    # basePop / extraPop: the clamp sequence plus pop esi / add esp,8 it continues at
    ("PopLimit", 0x4581F3, 0x50),
    # noAILimit: the hard-coded personality table setup plus the xor eax,eax it continues at
    ("AiLimit", 0x603B0B, 0x146),
    # customRevolutionBanners: jne 81A7F1h, the O'Higgins banner block, its dtor call and
    # the instruction at 0x81A7F1
    ("RevBanner", 0x81A7CC, 0x28),
    # removeFameRestriction
    ("FameTrickle", 0x51B025, 5),          # push 0BCD49Ch ("FavoriteUnit")
    ("FameKey", 0xBD62F8, 5),              # "Fame"
    ("FameHcIcons", 0x5C1E1F, 0x1D),       # icon loads, up to and including call 58E3EBh
    ("FameIconSlot", 0x9A218C, 4),         # jump-table slot 3 (Fame) -> default 0x9A20A0
    ("XpIconSlot", 0x9A2194, 4),           # jump-table slot 5 (XP) -> default 0x9A20A0
    ("IconSetCase", 0x9A2098, 8),          # mov ecx,esi / push eax / call 593D42h
    ("IconDefaultCase", 0x9A20A0, 4),      # lea ecx,[esp+18h]
    ("PoliticianCosts", 0x80E490, 7),      # mov eax,[edi] / lea ecx,[esp+14h] / push ecx
    ("PoliticianCosts2", 0x81943D, 7),     # mov edx,[esi] / lea eax,[esp+14h] / push eax
    # hcShipmentPointFallback (FUN_004C6CAE, "get a valid HC gather unit")
    ("GatherFallbackExit", 0x669E2E, 10),  # pop ebp/edi/esi, xor eax,eax, pop ebx/ecx, ret 4
    ("GatherFallbackStore", 0x4C6CB2, 12), # cmp byte [esp+18h],1 / je 669E38h: store-and-return
    ("GatherFallbackBlock", 0x6698B4, 0xB0),  # the stock FortFrontier search block the hook mirrors
    # healNonIdle (FUN_009E0B53, heal action applying a tick): the "target busy" check, from
    # mov ecx,[edi+58h] through the two busy tests to the heal path at 0x9E0C9F
    ("HealIdleCheck", 0x9E0C79, 0x2C),
    # healNonIdle (FUN_009CD865, a healer's automatic target search): mov ecx,[esi+58h] /
    # test / je, the "target is idle" call 0x44F1A7 / test al,al / je, and the next check
    ("HealAutoSearchIdle", 0x9CD9C0, 0x15),
    # extra abstract unit types (FUN_0051A5DC, registers the built-in abstract types): the tail
    # of its last loop and the epilogue pop edi / pop esi / mov al,1 / pop ebx / pop ecx / ret
    ("AbstractTypesEnd", 0x51BA23, 0x15),
    # damageOverTime: TakeDamage FUN_0049B3D9's entry, sub esp,8Ch, and the cmp byte
    # [esp+0C0h],1 the trampoline continues at
    ("DotTakeDamageEntry", 0x49B3D9, 14),
    # damageOverTime: world update FUN_00481A57's entry, sub esp,0Ch / push ebx / push ebp, and
    # the push esi / mov esi,ecx the trampoline continues at
    ("DotWorldUpdateEntry", 0x481A57, 8),
    # damageOverTime (FUN_005F98A0, parses the children of an action): the last tag compare
    # ("ModifyExclusive"), its je to the handler, and the next-child code at 0x5FA126
    ("DotProtoActionTag", 0x5FA10F, 0x1B),
    # damageOverTime: the ProtoAction handler's call 5F98A0h; the tag hook checks its return
    # address 0x5FA213 to know the action comes from protoy.xml
    ("DotProtoActionCall", 0x5FA20E, 5),
    # dodgeAnyUnit (FUN_0049ACAA, "is this hit dodged?"): mov eax,[esi+5Ch] / mov eax,[eax+4],
    # the target's proto ID, and the first compare with the cached ypMonkJapanese ID
    ("DodgeProtoCheck", 0x49ACE5, 12),
    # dodgeAnyUnit: the dodge path the hook enters, push "ypDodge" / call 600BE1h (tech by name)
    ("DodgeTechCheck", 0x6A249C, 10),
    # dodgeAnyUnit log: call 49ACAAh in the damage function and the test al,al after it
    ("DodgeCall", 0x49B023, 7),
    # dodgeSoundSet: push "PowerEvade", the sound set a dodge plays, and the add esi,14h after it
    ("DodgeSound", 0x6A2628, 8),
    # criticalSoundSet: push "PowerCriticalStrike", played at the attacker, and lea eax,[ebx+14h]
    ("CriticalSound", 0x6A2A9A, 8),
    # multipleInstances: call [CreateSemaphoreW] of the single-instance check; the IAT hook knows
    # that call by its return address, 0x55A18B
    ("SingleInstanceSemaphore", 0x55A185, 6),
]


def main():
    exe = pathlib.Path(sys.argv[1]).read_bytes()
    digest = hashlib.sha256(exe).hexdigest()
    if digest != STOCK_SHA256:
        sys.exit(f"refusing: {sys.argv[1]} has SHA-256 {digest}, expected the stock build {STOCK_SHA256}")
    out = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else pathlib.Path(__file__).parents[1] / "src/generated/sites.h"

    lines = [
        "// Generated by tools/gen_sites.py from the stock age3y.exe",
        f"// (SHA-256 {STOCK_SHA256}). Do not edit by hand.",
        "#pragma once",
        "",
        "#include <cstdint>",
        "",
        '#include "../site.h"',
        "",
        "namespace uhc::sites {",
        "",
    ]
    for name, va, size in SITES:
        raw = exe[va - IMAGE_BASE:va - IMAGE_BASE + size]
        body = ", ".join(f"0x{b:02X}" for b in raw)
        lines.append(f"inline constexpr std::uint8_t k{name}Bytes[] = {{{body}}};")
        lines.append(f'inline constexpr Site k{name}{{"{name}", 0x{va:08X}, k{name}Bytes, sizeof(k{name}Bytes)}};')
        lines.append("")
    lines.append("}  // namespace uhc::sites")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {out} ({len(SITES)} sites)")


if __name__ == "__main__":
    main()
