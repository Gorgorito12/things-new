; autoScout (src/features/autoscout.cpp). Entered through a jmp written over the stock code; it leaves
; through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcAutoScoutCommand PROTO STDCALL command:DWORD

.data
cmdExecuteNext dd 007C8E51h   ; jbe 7C8E85h, after the four instructions this hook re-executes

.code

; Replaces 0x7C8E49..0x7C8E50 (push ecx / push esi / mov esi,ecx / cmp dword [esi+5Ch],5), the head of the
; command execute FUN_007C8E49, thiscall(cmd), called once per command by the world update's command
; processing (0x64D31A, inside 0x490015, called at 0x481BC2): the simulation, on every machine, in the
; same order. On entry ECX = the command. UhcAutoScoutCommand (stdcall, keeps EBX, ESI, EDI, EBP) looks at
; the command first: a unit order (move, attack, garrison, stop) to a unit in the scouting tactic puts that
; unit back in its other tactic before the order applies. Then the stock head runs, and the jbe at
; 0x7C8E51 takes the flags of its cmp.
UhcAutoScoutCmdHook PROC
    TRACE_ONCE "autoScout command (0x7C8E49)"
    push eax
    push ecx
    push edx
    push ecx                        ; the command
    call UhcAutoScoutCommand
    pop edx
    pop ecx
    pop eax
    push ecx
    push esi
    mov esi, ecx
    cmp dword ptr [esi+5Ch], 5
    jmp cmdExecuteNext
UhcAutoScoutCmdHook ENDP

END
