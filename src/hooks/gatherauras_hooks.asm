; Wrapper for resourceGatherAuras: the target of the redirected call at 0x4ED02A
; (docs/engine-symbols.md, "Gathering and the stat panel").
.686
.model flat, c
option casemap :none

include common.inc

UhcGatherAuraFactor PROTO STDCALL action:DWORD

.data
danceFactor dd 004ECD39h    ; float thiscall(player): the Gathering dance factor

.code

; Replaces the target of call 4ECD39h at 0x4ED02A in the gather tick FUN_004ECD87. ECX = the
; gatherer's player, ESI = the Gather action, FPU stack empty. It returns the stock factor times the
; helper's, in ST0, as the stock call does; the tick reads no other register from it.
UhcGatherAuraCall PROC
    TRACE_ONCE "resourceGatherAuras (0x4ED02A)"
    call danceFactor
    sub esp, 4
    fstp dword ptr [esp]
    push esi
    call UhcGatherAuraFactor
    fmul dword ptr [esp]
    add esp, 4
    ret
UhcGatherAuraCall ENDP

END
