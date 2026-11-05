; cantBeSlowed (src/features/cantslow.cpp). Entered through a jmp written over the stock code; it leaves
; through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcCantBeSlowed PROTO STDCALL unit:DWORD

.data
snareNext       dd 004DD207h    ; push 0BB8h: the rest of the creator's arguments
snareExit       dd 0048FA49h    ; pop esi / pop ecx ..., where the snare ends

.code

; Replaces 0x4DD201..0x4DD206 (push 1 / push -1 / push -1), the creator's last arguments, re-executed
; here. ESI = the target. The code after it sets ECX itself and reads neither EAX nor EDX.
UhcCantBeSlowedHook PROC
    TRACE_ONCE "cantBeSlowed (0x4DD201)"
    invoke UhcCantBeSlowed, esi
    test al, al
    jne skip
    push 1
    push -1
    push -1
    jmp snareNext
skip:
    jmp snareExit
UhcCantBeSlowedHook ENDP

END
