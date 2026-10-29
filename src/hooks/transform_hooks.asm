; Hook for transformUpdatesLOS. Entered through a jmp written over the stock code; leaves through
; an explicit jmp to a verified continuation (docs/engine-symbols.md, "Line of sight and
; transforms").
.686
.model flat, c
option casemap :none

include common.inc

UhcTransformLos PROTO STDCALL unit:DWORD, newProto:DWORD

.data
setProto        dd 004981F3h    ; void thiscall(unit, Proto* proto), ret 4: writes [unit+5Ch]
transformNext   dd 009C7644h    ; mov ecx,[esi+5Ch] / push esi / call 8F7AD2h

.code

; Replaces the call 4981F3h (setProto) at 0x9C763F in FUN_009C754C, where a unit changes proto in
; place. ESI = ECX = the unit, [esp] = the new proto (the player's copy, pushed at 0x9C763C from
; EBP), [esi+5Ch] = the old proto. The unit left the visibility map at 0x9C7570 with its old LOS
; and goes back on it at 0x9C7730 with whatever [[esi+B4h]+90h] holds then, so the C++ helper
; writes the new proto's LOS there first. Every register is preserved for the stolen call;
; afterwards EAX, ECX, EDX and the flags are what setProto leaves, as in stock.
UhcTransformLosHook PROC
    TRACE_ONCE "transformUpdatesLOS (0x9C763F)"
    pushad
    push dword ptr [esp+20h]        ; the new proto, setProto's argument (above the 8 saved registers)
    push esi                        ; the unit
    call UhcTransformLos
    popad
    call setProto                   ; stolen 0x9C763F: ECX = unit, the argument is still at [esp]
    jmp transformNext
UhcTransformLosHook ENDP

END
