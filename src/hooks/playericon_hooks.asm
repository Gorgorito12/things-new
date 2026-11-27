; playerIcon (src/features/playericon.cpp). The two calls of the lobby slot's civ portrait FUN_00774D56 (0x776FFC and
; 0x7773DD, ECX = the slot) call this hook instead. It runs the stock function itself, then the helper, and returns
; to the caller with every register as the stock function left it.
.686
.model flat, c
option casemap :none

include common.inc

UhcPlayerIconAfterPortrait PROTO STDCALL slot:DWORD


.data
civPortrait dd 00774D56h   ; FUN_00774D56, the slot's civ portrait

.code

UhcPlayerIconHook PROC
    TRACE_ONCE "playerIcon civ portrait (0x776FFC / 0x7773DD)"
    push ecx
    call civPortrait             ; thiscall(slot), no arguments
    pop ecx
    pushfd
    pushad
    push ecx
    call UhcPlayerIconAfterPortrait
    popad
    popfd
    ret
UhcPlayerIconHook ENDP

END
