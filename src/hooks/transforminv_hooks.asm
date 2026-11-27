; Hook for transformInventory. Entered through a jmp written over the stock code; leaves through
; an explicit jmp to a verified continuation (docs/engine-symbols.md, "Resource inventories").
.686
.model flat, c
option casemap :none

include common.inc

UhcTransformInventory PROTO STDCALL unit:DWORD, newProto:DWORD

.data
transformActions    dd 009C762Ch    ; push eax / call 4BA630h / add esp,4 / mov dword [esi+58h],0
transformSetProto   dd 009C763Ch    ; push ebp / mov ecx,esi / call 4981F3h (setProto)

.code

; Replaces 0x9C7625..0x9C762B (mov eax,[esi+58h] / test eax,eax / je 9C763Ch) in FUN_009C754C,
; where a unit changes proto in place. ESI = the unit, EBP = the new proto (the player's copy,
; from 0x9C7560, unchanged until 0x9C764D), [esi+5Ch] = the old proto. The other players'
; knowledge bases dropped the unit at 0x9C75FE (reading its old resource type) and take it back at
; 0x9C768D (reading its amounts); setHP's checkState runs at 0x9C76F3. The C++ helper gives the
; unit its new proto's inventory in between. Every register is preserved for the stolen code; the
; flags are dead after its je, which the hook re-executes, and the x87 stack is empty here.
UhcTransformInventoryHook PROC
    TRACE_ONCE "transformInventory (0x9C7625)"
    pushad
    push ebp                        ; the new proto
    push esi                        ; the unit
    call UhcTransformInventory
    popad
    mov eax, dword ptr [esi+58h]    ; stolen 0x9C7625: the unit's action manager
    test eax, eax                   ; stolen 0x9C7628
    je noActions                    ; stolen 0x9C762A (je 9C763Ch)
    jmp transformActions            ; 0x9C762C: push eax / call 4BA630h (needs EAX = [esi+58h])
noActions:
    jmp transformSetProto
UhcTransformInventoryHook ENDP

END
