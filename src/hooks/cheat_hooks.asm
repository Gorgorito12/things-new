; Hook for customCheats (src/features/plugins.cpp). Replaces the epilogue of the cheat table build
; FUN_005515F1 (pop edi / pop esi / pop ebx / add esp,10h at 0x551FE6), appends the plugin cheats,
; re-executes the epilogue and leaves through an explicit jmp to the function's ret.
.686
.model flat, c
option casemap :none

include common.inc

UhcAppendCheats PROTO STDCALL

.data
cheatTableReturn dd 00551FECh   ; ret

.code

UhcCheatTableHook PROC
    TRACE_ONCE "customCheats cheat table (0x551FE6)"
    pushad
    call UhcAppendCheats
    popad
    pop edi
    pop esi
    pop ebx
    add esp, 10h
    jmp cheatTableReturn
UhcCheatTableHook ENDP

END
