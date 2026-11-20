; The shared <Tech> node hook (src/techtags.cpp). Entered through a jmp written over the stock code; it re-executes
; the replaced instructions and leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcTechNodeDispatch PROTO STDCALL node:DWORD

.data
techNodeNext dd 0061FDBFh   ; cmp edx,-1: the node's name index

.code

; Replaces mov esi,eax / mov ecx,esi / mov edx,[ecx+18h] at 0x61FDB8, the tech parser's loop over the tree's nodes:
; EAX = the node. pushad / popad keep every register for the re-executed instructions; the flags are written by the
; cmp that follows.
UhcTechNodeHook PROC
    TRACE_ONCE "tech tags (0x61FDB8)"
    pushad
    push eax
    call UhcTechNodeDispatch
    popad
    mov esi, eax
    mov ecx, esi
    mov edx, dword ptr [ecx+18h]
    jmp techNodeNext
UhcTechNodeHook ENDP

END
