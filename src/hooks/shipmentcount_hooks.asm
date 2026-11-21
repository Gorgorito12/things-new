; Hook for shipmentCounts: the call of the tech activation in the shipment of a card. It leaves through an explicit
; jmp to its verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcShipBegin PROTO STDCALL entry:DWORD, player:DWORD, hc:DWORD, shipment:DWORD
UhcShipEnd PROTO STDCALL

.data
activate        dd 0094CF27h    ; the tech activation, thiscall(entry, player, unit, 0, &ok, flags), ret 14h
shipReturn      dd 0            ; 0x858504, the call's return address while the activation runs

.code

; Replaces call 94CF27h at 0x8584FF in FUN_00858299. ECX = EDI = the card tech's status entry, ESI = the home
; city, [esp+4] = the player (the first of the five arguments), [esp] = the return address 0x858504, and
; [esp+3Ch] = FUN_00858299's argument, the queue entry being shipped ([esp+24h] before the five pushes and the
; return address). UhcShipBegin notes the player and the age of the entry's card; the activation runs with the
; stock arguments (it pops them, ret 14h) and its effects see the shipment as current; UhcShipEnd counts it. EAX,
; the activation's result, is kept; ECX and EDX are free after the call, and the code at 0x858504 reloads ECX from
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

END
