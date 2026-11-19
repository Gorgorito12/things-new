; Hook for noDamageOnUnbuiltFoundations (src/features/smallfixes.cpp). Replaces the proto
; Invulnerable test of the damage function at 0x49B3F3 (ESI = the unit, the attacking player at
; [esp+94h]); leaves to the no-damage path or to the next test.
.686
.model flat, c
option casemap :none

include common.inc

UhcTakesNoDamage PROTO STDCALL unit:DWORD, attacker:DWORD

.data
noDamagePath dd 004CA52Bh   ; fld 0.0 / ... / ret 34h
nextTest     dd 0049B40Fh   ; cmp [ecx+54h],67h

.code

UhcInvulnerableTestHook PROC
    TRACE_ONCE "noDamageOnUnbuiltFoundations (0x49B3F3)"
    push dword ptr [esp+94h]
    push esi
    call UhcTakesNoDamage
    mov ecx, dword ptr [esi+5Ch]
    test al, al
    jnz noDamage
    jmp nextTest
noDamage:
    jmp noDamagePath
UhcInvulnerableTestHook ENDP

END
