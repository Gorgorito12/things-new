; retargetInAction (features/retarget.cpp): the attack update's "no live target" branch. Entered through a jmp written
; over the stock code, left through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcRetargetAction PROTO STDCALL :DWORD

EXTERNDEF g_uhcRetargetOn:DWORD    ; above 0 while some attack action carries <RetargetInAction>

.data
afterCompare    dd 0048783Dh    ; je 48A40Fh: the stock branch on the compare this hook re-executes
updateTarget    dd 0048A359h    ; mov ecx,[esi+14h]: the update reads its target again

.code

; Replaces mov al,[esi+61h] / cmp al,19h (5 bytes) at 0x487838, in the attack unit action's update FUN_0048A330 (vtable
; 0xB96278 +3Ch), where it goes when its target [esi+14h] is no unit (0x48A3D3, by way of 0x48782F), not alive (vtable
; +A4h, 0x48A3EA) or inside another unit (0x48A3F9, 0x48A409). ESI = the unit action, EBX = 0, the update's saved EDI on
; top of the stack (pushed at 0x48A36A), then ESI, EBX and its two locals. The stock code then waits out the cycle in
; state 19h, sets state 19h from state 1 or 15h (the attack animation), or ends the attack (setState 0Ah).
; UhcRetargetAction decides, for an action with the tag, whether a new target takes the dead one's place; it writes it
; to [esi+14h] and returns 1. Then EDI is popped and the update starts again at its target read 0x48A359, where it
; checks the new target as it does at every update (alive, the attack action for it, range, visibility) and goes on
; with it. Otherwise the stock compare runs, with EAX, ECX and EDX as they came.
UhcRetargetHook PROC
    TRACE_ONCE "retargetInAction (0x487838)"
    cmp g_uhcRetargetOn, 0
    je stock
    push eax
    push ecx
    push edx
    push esi
    call UhcRetargetAction              ; EAX = 1: [esi+14h] is the new target
    test eax, eax
    pop edx
    pop ecx
    pop eax
    jne swapped
stock:
    mov al, byte ptr [esi+61h]
    cmp al, 19h
    jmp afterCompare
swapped:
    pop edi                             ; as at 0x48A359, before the update's push edi
    jmp updateTarget
UhcRetargetHook ENDP

END
