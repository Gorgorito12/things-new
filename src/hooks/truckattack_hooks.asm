; Hook for truckAttackResourceFix (src/features/truckattack.cpp). Replaces the inventory reset of the TruckAttack
; hit at 0x9EC635 (EBP = the action, EDI = the target, EBX = 0; EAX, ECX and EDX are written before they are read on
; both continuations). A building keeps its resources: the hook goes on at the damage, 0x9EC64D. Any other target
; re-executes mov edx,[edi+0B4h] and goes on at 0x9EC63B, the stock reset.
.686
.model flat, c
option casemap :none

include common.inc

UhcTruckKeepsInventory PROTO STDCALL action:DWORD, target:DWORD

.data
truckReset  dd 009EC63Bh   ; mov eax,[edx+94h] / ... / call 58F070h
truckDamage dd 009EC64Dh   ; mov ecx,[edi+5Ch]: the damage

.code

UhcTruckInventoryHook PROC
    TRACE_ONCE "truckAttackResourceFix (0x9EC635)"
    push edi
    push ebp
    call UhcTruckKeepsInventory
    test al, al
    jnz keep
    mov edx, dword ptr [edi+0B4h]
    jmp truckReset
keep:
    jmp truckDamage
UhcTruckInventoryHook ENDP

END
