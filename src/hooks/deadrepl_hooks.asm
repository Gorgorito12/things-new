; Hook for deadReplacementAtZeroInventory. Entered through a jmp written over the head of the death
; replacement FUN_004B4F2F; leaves through an explicit jmp to its verified continuation, or returns
; for it (docs/engine-symbols.md, "Death replacement").
.686
.model flat, c
option casemap :none

include common.inc

; EAX: 1 to skip this replacement, 0 for stock. `caller` is the return address.
UhcDeadReplacementSkip PROTO STDCALL unit:DWORD, caller:DWORD
UhcDeadReplacementOnRemove PROTO STDCALL unit:DWORD     ; places a body's waiting replacement

.data
headNext        dd 004B4F36h    ; test eax,eax / jne 4E6220h: the replacement after its stolen head
removeNext      dd 00495D70h    ; push esi / push edi: the removal notice after its stolen head

.code

; Replaces push ecx / push esi / mov esi,ecx / mov eax,[esi+68h] (7 bytes) at 0x4B4F2F, the head of
; the death replacement (thiscall(unit), plain ret; ECX = unit). Its four callers: the kill handler
; 0x4B527E, the two removal paths of a DeadReplacementWhenDestroyed proto 0x4E6FC6 and 0x6A4013, and
; 0x4F1680, where the state check 0x482152 has just turned a unit with DieAtZeroResources at 0 HP
; into a corpse (state bit 12, owner gaia). UhcDeadReplacementSkip, given the return address, says
; whether to leave the replacement for later (EAX = 1: return to the caller with nothing done, no
; state bit 29h set, no unit placed); it only says so for the corpse caller. Each caller reloads EAX
; before reading it, and EDX is not live across the call (thiscall, no arguments). Otherwise the
; stolen instructions run and the stock body follows.
UhcDeadReplacementHook PROC
    TRACE_ONCE "deadReplacementAtZeroInventory (0x4B4F2F)"
    push ecx
    push dword ptr [esp+4]          ; the caller's return address
    push ecx                        ; unit
    call UhcDeadReplacementSkip
    pop ecx
    test eax, eax
    je stock
    ret
stock:
    push ecx                        ; stolen 0x4B4F2F
    push esi                        ; stolen 0x4B4F30
    mov esi, ecx                    ; stolen 0x4B4F31
    mov eax, dword ptr [esi+68h]    ; stolen 0x4B4F33
    jmp headNext
UhcDeadReplacementHook ENDP

; Replaces mov eax,[0C66234h] (5 bytes) at 0x495D6B, the head of the removal notice (thiscall(unit),
; plain ret; ECX = unit), which the two updates call for a unit marked for removal (state bit 7) just
; before they remove it: 0x495DEE in the unit update 0x482F16, 0x6A3FF0 in 0x5116xx. Both then place
; the replacement only for a DeadReplacementWhenDestroyed proto. UhcDeadReplacementOnRemove places it
; for a body whose replacement waited (through the head above, which is then stock: the return
; address is ours). It keeps ECX; EAX is written by the stolen instruction, EDX is not an argument.
UhcDeadReplacementRemoveHook PROC
    TRACE_ONCE "deadReplacementAtZeroInventory removal (0x495D6B)"
    push ecx
    push ecx                        ; unit
    call UhcDeadReplacementOnRemove
    pop ecx
    mov eax, dword ptr ds:[0C66234h]   ; stolen 0x495D6B
    jmp removeNext
UhcDeadReplacementRemoveHook ENDP

END
