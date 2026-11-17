; Data refs (datarefs.cpp). Reached through the call at 0x5D3229, which the stock parser constructor makes to the
; registration FUN_005CFA7C; this runs it, appends the DLL's refs, and returns to the constructor.
.686
.model flat, c
option casemap :none

include common.inc

UhcRegisterDataRefs PROTO STDCALL parser:DWORD

.code

; ECX = the parser (the stock call's this). Returns to 0x5D322E (mov eax,esi), which reloads EAX; ESI is kept by
; the callee, as the stock registration keeps it.
UhcDataRefRegisterHook PROC
    TRACE_ONCE "data refs registration (0x5D3229)"
    push ecx
    call UhcRegisterDataRefs
    ret
UhcDataRefRegisterHook ENDP

END
