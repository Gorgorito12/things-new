; The stat panel's rows after its HP row, shared by the keys that add one (src/statpanelrows.cpp). Entered through a
; jmp written over the stock code; it leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcStatPanelRows PROTO STDCALL panel:DWORD, unit:DWORD, row:DWORD

.data
statRowNext     dd 004D76E4h    ; mov edx,[0CF059Ch]: the rows after the HP row

.code

; Replaces mov edi,2 / mov [esp+2Ch],edi (9 bytes) at 0x4D76DB, the stat panel fill FUN_004D70ED right after the HP
; row: EDI and [esp+2Ch] are the next free row (the Group Health branch 0x69A9D3 writes row EDI, then adds 1 to both).
; UhcStatPanelRows writes the keys' rows from there for the panel's unit ([esp+38h], the panel [esp+50h]) and returns
; how many; both counters move on by that many. EAX, ECX, EDX and the flags are dead at 0x4D76E4 (mov edx,[0CF059Ch] /
; mov eax,[edx] / ... / mov ecx,0C66500h).
UhcStatPanelRowsHook PROC
    TRACE_ONCE "stat panel rows (0x4D76DB)"
    mov edi, 2                      ; stolen 0x4D76DB
    mov dword ptr [esp+2Ch], edi    ; stolen 0x4D76E0
    pushad
    push edi                        ; row
    push dword ptr [esp+24h+38h]    ; unit
    push dword ptr [esp+28h+50h]    ; panel
    call UhcStatPanelRows
    mov dword ptr [esp+1Ch], eax    ; the pushad slot of EAX: the result survives popad
    popad
    add edi, eax
    mov dword ptr [esp+2Ch], edi
    jmp statRowNext
UhcStatPanelRowsHook ENDP

END
