; detonationDeath (src/features/detonation.cpp): the delete command's executor FUN_007CCF7F calls the HP setter (0x7CD0CF)
; or the kill queue (0x7CD0DC); both calls are rewritten to these hooks, which hand the helper the unit and the command
; (EDI in the executor, from its mov edi,ecx at 0x7CCF8A), then jump to the stock callee with the caller's arguments and
; return address untouched, so it returns to the executor as before.
.686
.model flat, c
option casemap :none

include common.inc

UhcDetonationDeleteSetHp PROTO STDCALL unit:DWORD, command:DWORD
UhcDetonationDeleteKill PROTO STDCALL unit:DWORD, command:DWORD

.data
hpSetter dd 004820A1h    ; thiscall(unit, float, int), ret 8
killAsk  dd 004B4DC2h    ; thiscall(unit, a, b, c), ret 0Ch

.code

; In place of call 4820A1h at 0x7CD0CF: ECX = the unit, [esp+4] = 0.0, [esp+8] = 1, EDI = the command. The helper may
; fire the blast while the unit is whole; ECX is restored for the setter (the stdcall helper keeps EDI, ESI, EBX, EBP).
UhcDetonationSetHpHook PROC
    TRACE_ONCE "detonationDeath delete command, HP setter (0x7CD0CF)"
    push ecx
    push edi
    push ecx
    call UhcDetonationDeleteSetHp
    pop ecx
    jmp hpSetter
UhcDetonationSetHpHook ENDP

; In place of call 4B4DC2h at 0x7CD0DC (a proto with flag 0Dh): ECX = the unit, three flag arguments on the stack,
; EDI = the command. The helper notes whether the kill is a delete or a trigger's Kill for the death observer.
UhcDetonationKillAskHook PROC
    TRACE_ONCE "detonationDeath delete command, kill queue (0x7CD0DC)"
    push ecx
    push edi
    push ecx
    call UhcDetonationDeleteKill
    pop ecx
    jmp killAsk
UhcDetonationKillAskHook ENDP

END
