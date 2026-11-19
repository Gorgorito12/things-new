; Hooks for shipmentCounts: the call of the tech activation in the shipment of a card, the head of the shipment
; queue's add (a card is sent) and the head of its removal (a card shipped or cancelled). Each leaves through an
; explicit jmp to its verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcShipBegin PROTO STDCALL entry:DWORD, player:DWORD, hc:DWORD, shipment:DWORD
UhcShipEnd PROTO STDCALL
UhcShipQueued PROTO STDCALL queue:DWORD, entry:DWORD
UhcShipUnqueued PROTO STDCALL queue:DWORD, index:DWORD, shift:DWORD

.data
activate        dd 0094CF27h    ; the tech activation, thiscall(entry, player, unit, 0, &ok, flags), ret 14h
shipReturn      dd 0            ; 0x858504, the call's return address while the activation runs
addContinue     dd 0085720Bh    ; the queue add after its replaced head
removeContinue  dd 0085725Ch    ; the queue removal after its replaced compare

.code

; Replaces call 94CF27h at 0x8584FF in FUN_00858299. ECX = EDI = the card tech's status entry, ESI = the home
; city, [esp+4] = the player (the first of the five arguments), [esp] = the return address 0x858504, and
; [esp+3Ch] = FUN_00858299's argument, the queue entry being shipped ([esp+24h] before the five pushes and the
; return address). UhcShipBegin notes the player and the card's send age; the activation runs with the stock
; arguments (it pops them, ret 14h) and its effects see the shipment as current; UhcShipEnd counts it. EAX, the
; activation's result, is kept; ECX and EDX are free after the call, and the code at 0x858504 reloads ECX from
; EDI. One shipment at a time: the activation does not ship another card.
UhcShipActivateHook PROC
    TRACE_ONCE "shipmentCounts (0x8584FF)"
    push ecx
    push dword ptr [esp+40h]        ; the queue entry, [esp+3Ch] + the push
    push esi                        ; the home city
    push dword ptr [esp+10h]        ; player, [esp+4] + three pushes
    push ecx                        ; entry
    call UhcShipBegin
    pop ecx
    pop eax                         ; the return address
    mov shipReturn, eax
    call activate                   ; the five arguments are on the stack, as at the stock call
    push eax
    call UhcShipEnd
    pop eax
    jmp shipReturn
UhcShipActivateHook ENDP

; Replaces the head of FUN_00857204 (thiscall(queue, entry*), ret 4), the shipment queue's add: ECX = the queue,
; [esp+4] = the new entry. UhcShipQueued notes the card and its send age; then the replaced push esi / push edi /
; mov edi,ecx / mov esi,[edi+4] run here and the add goes on at 0x85720B.
UhcShipQueueAddHook PROC
    TRACE_ONCE "shipmentCounts send (0x857204)"
    push eax
    push ecx
    push edx
    push dword ptr [esp+10h]        ; the entry, [esp+4] + three pushes
    push ecx                        ; the queue
    call UhcShipQueued
    pop edx
    pop ecx
    pop eax
    push esi
    push edi
    mov edi, ecx
    mov esi, dword ptr [edi+4]
    jmp addContinue
UhcShipQueueAddHook ENDP

; Replaces the head of FUN_00857257 (thiscall(queue, index, bool shift), ret 8), the shipment queue's removal:
; ECX = the queue, [esp+4] = the index, [esp+8] = shift. UhcShipUnqueued forgets the entry; then the replaced
; cmp byte ptr [esp+8],0 runs here (its flags feed the jz at 0x857260) and the removal goes on at 0x85725C.
UhcShipQueueRemoveHook PROC
    TRACE_ONCE "shipmentCounts queue removal (0x857257)"
    push eax
    push ecx
    push edx
    push dword ptr [esp+14h]        ; shift, [esp+8] + three pushes
    push dword ptr [esp+14h]        ; index, [esp+4] + four pushes
    push ecx                        ; the queue
    call UhcShipUnqueued
    pop edx
    pop ecx
    pop eax
    cmp byte ptr [esp+8], 0
    jmp removeContinue
UhcShipQueueRemoveHook ENDP

END
