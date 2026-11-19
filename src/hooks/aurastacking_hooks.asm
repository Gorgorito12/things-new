; auraStacking (src/features/aurastacking.cpp). Two hooks in the aura update FUN_009D033E.
.686
.model flat, c
option casemap :none

include common.inc

UhcAuraFilter PROTO STDCALL action:DWORD, target:DWORD
UhcAuraApplied PROTO STDCALL action:DWORD, target:DWORD, modifier:DWORD

EXTERNDEF C g_uhcAuraAppliedNext:DWORD

.code

; Replaces the target of the call at 0x9D0633: the filter 0x9D0238, thiscall(action, target), ret 4.
; The update reads AL. The C++ code calls the filter itself.
UhcAuraFilterHook PROC
    TRACE_ONCE "auraStacking filter (0x9D0633)"
    mov eax, dword ptr [esp+4]
    invoke UhcAuraFilter, ecx, eax
    ret 4
UhcAuraFilterHook ENDP

; Replaces, at 0x9D0675 right after the call of 0x4DD22D, mov ebx,eax / cmp ebx,-1. EAX = the modifier's
; ID, EBX = the target, ESI = the action. ECX and EDX hold nothing, as 0x4DD22D has just run.
UhcAuraAppliedHook PROC
    TRACE_ONCE "auraStacking applied (0x9D0675)"
    push eax
    invoke UhcAuraApplied, esi, ebx, eax
    pop eax
    mov ebx, eax
    cmp ebx, -1
    jmp g_uhcAuraAppliedNext
UhcAuraAppliedHook ENDP

END
