; snareValues (src/features/snarevalues.cpp). Entered through a jmp written over the stock code, left
; through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcSnareValues PROTO STDCALL unitAction:DWORD, factor:DWORD, ms:DWORD

.data
snareCreate     dd 004DD22Dh    ; thiscall(unit, stat, value, -1f, -1f, 0, operation, ms, -1, -1, exclusive)
snareExit       dd 0048FA49h    ; pop esi / pop ecx ..., where the snare ends

.code

; Replaces 0x4DD207, push 0BB8h. The stack already has the creator's last three arguments, from stock or
; cantBeSlowed, whose hook continues here. ESI = the target; EBP = the attacker's unit action. The stock
; code from here to the creator is only pushes, so it is done here with the action's values, and the
; flow ends at the exit, as stock's jmp 48FA49h does.
UhcSnareValuesHook PROC
    TRACE_ONCE "snareValues (0x4DD207)"
    sub esp, 8                      ; [esp] the factor, [esp+4] the ms
    lea eax, [esp+4]
    push eax
    lea eax, [esp+4]
    push eax
    push ebp
    call UhcSnareValues
    pop ecx
    pop edx
    test edx, edx
    je none
    push edx
    push 2
    push 0
    push 0BF800000h
    push 0BF800000h
    push ecx
    push 0
    mov ecx, esi
    call snareCreate
    jmp snareExit
none:
    add esp, 0Ch
    jmp snareExit
UhcSnareValuesHook ENDP

END
