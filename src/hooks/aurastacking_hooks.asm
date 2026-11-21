; auraStacking (src/features/aurastacking.cpp). One hook in the aura update FUN_009D033E.
.686
.model flat, c
option casemap :none

include common.inc

UhcAuraFilter PROTO STDCALL action:DWORD, target:DWORD

.code

; Replaces the target of the call at 0x9D0633: the filter 0x9D0238, thiscall(action, target), ret 4.
; The update reads AL. The C++ code calls the filter itself.
UhcAuraFilterHook PROC
    TRACE_ONCE "auraStacking filter (0x9D0633)"
    mov eax, dword ptr [esp+4]
    invoke UhcAuraFilter, ecx, eax
    ret 4
UhcAuraFilterHook ENDP

END
