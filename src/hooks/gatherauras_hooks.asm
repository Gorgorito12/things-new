; Wrapper for resourceGatherAuras: the target of the redirected call at 0x4ED02A
; (docs/engine-symbols.md, "Gathering and the stat panel").
.686
.model flat, c
option casemap :none

include common.inc

UhcGatherAuraFactor PROTO STDCALL action:DWORD
UhcGatherAuraHasRing PROTO STDCALL auraAction:DWORD, unit:DWORD, model:DWORD
UhcGatherAuraHangRing PROTO STDCALL auraAction:DWORD, unit:DWORD, object:DWORD, bone:DWORD, flag:DWORD

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

; Replaces the target of call 9C28DEh at 0x9D0584 in the aura update FUN_009D033E, thiscall(unit,
; model), ret 4. ESI = the aura action. The update reads only AL after it.
UhcGatherAuraHasRingHook PROC
    TRACE_ONCE "resourceGatherAuras ring (0x9D0584)"
    invoke UhcGatherAuraHasRing, esi, ecx, dword ptr [esp+4]
    ret 4
UhcGatherAuraHasRingHook ENDP

; Replaces the target of call 9C04F3h at 0x9D06DC in the same update, thiscall(unit, object, bone,
; byte), ret 0Ch. ESI = the aura action. The update ignores the result.
UhcGatherAuraHangRingHook PROC
    TRACE_ONCE "resourceGatherAuras ring (0x9D06DC)"
    invoke UhcGatherAuraHangRing, esi, ecx, dword ptr [esp+4], dword ptr [esp+8], dword ptr [esp+0Ch]
    ret 0Ch
UhcGatherAuraHangRingHook ENDP

END
