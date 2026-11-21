; Hooks for ageFiveShipments: the row of a card in the in-game shipment panel and in the deck editor. A card of the
; fifth age (age 4) takes the row of age 3; its own age [card+18h] is left alone. Each leaves through an explicit
; jmp to its verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

.data
panelContinue   dd 009A5A27h    ; FUN_009A5658: jl 9A620Bh, after the replaced mov / cmp
deckContinue    dd 009A77C3h    ; FUN_009A7670: jge 9A77D1h, after the replaced mov / cmp
builderContinue dd 009A048Eh    ; the deck builder's fill: jge 9A049Ch, after the replaced mov / cmp

.code

; Replaces mov eax,[esi+18h] / cmp eax,edi (5 bytes) at 0x9A5A22 in the panel fill FUN_009A5658: ESI = the card,
; EDI = 0; EAX becomes the card's row (its age, 4 -> 3); the cmp is re-run for the jl at 0x9A5A27.
UhcAgeFivePanelHook PROC
    TRACE_ONCE "ageFiveShipments panel (0x9A5A22)"
    mov eax, dword ptr [esi+18h]
    cmp eax, 4
    jne panelRow
    mov eax, 3
panelRow:
    cmp eax, edi
    jmp panelContinue
UhcAgeFivePanelHook ENDP

; Replaces mov eax,[esi+18h] / cmp ebx,eax (5 bytes) at 0x9A77BE in the deck editor fill FUN_009A7670: ESI = the
; card, EBX = the current row; EAX becomes the card's row (4 -> 3); the cmp is re-run for the jge at 0x9A77C3.
UhcAgeFiveDeckHook PROC
    TRACE_ONCE "ageFiveShipments deck editor (0x9A77BE)"
    mov eax, dword ptr [esi+18h]
    cmp eax, 4
    jne deckRow
    mov eax, 3
deckRow:
    cmp ebx, eax
    jmp deckContinue
UhcAgeFiveDeckHook ENDP

; Replaces mov eax,[esi+18h] / cmp edi,eax (5 bytes) at 0x9A0489 in the deck builder's fill (the home city screen's
; "Build a Deck", uihcdeckbuilder.xml, buttons hcDeck-button<row><column>): ESI = the card, EDI = the current row;
; EAX becomes the card's row (4 -> 3); the cmp is re-run for the jge at 0x9A048E.
UhcAgeFiveBuilderHook PROC
    TRACE_ONCE "ageFiveShipments deck builder (0x9A0489)"
    mov eax, dword ptr [esi+18h]
    cmp eax, 4
    jne builderRow
    mov eax, 3
builderRow:
    cmp edi, eax
    jmp builderContinue
UhcAgeFiveBuilderHook ENDP

END
