; Hooks for ageFiveShipments: the row and the column of a card in the in-game shipment panel, the deck builder and
; the deck editor. A card of the fifth age (age 4) takes the row of age 3; its own age [card+18h] is left alone.
; In that row the Age IV cards stay at the left and the Age V cards go to the right (UhcAgeFiveColumn). Each hook
; leaves through an explicit jmp to its verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcAgeFiveColumn PROTO STDCALL list:DWORD, card:DWORD, column:DWORD, counter:DWORD, where:DWORD

.data
panelContinue   dd 009A5A27h    ; FUN_009A5658: jl 9A620Bh, after the replaced mov / cmp
deckContinue    dd 009A77C3h    ; FUN_009A7670: jge 9A77D1h, after the replaced mov / cmp
builderContinue dd 009A048Eh    ; the deck builder's fill: jge 9A049Ch, after the replaced mov / cmp
panelColContinue   dd 009A5A84h ; FUN_009A5658: lea eax,[ebx+ebx*2], after the replaced mov ecx / mov edx
panelColSkip       dd 009A620Bh ; FUN_009A5658: the next card, as for a twelfth card of a row
builderColContinue dd 009A04B8h ; the deck builder's fill: lea ecx,[edi+edi*2], after the replaced mov edx / mov eax
builderColSkip     dd 009A076Ch ; the deck builder's fill: the next card
deckColContinue    dd 009A77ECh ; FUN_009A7670: add eax,eax, after the replaced mov ecx / lea eax
deckColSkip        dd 009A7A73h ; FUN_009A7670: the next card

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

; Replaces mov ecx,[esp+28h] / mov edx,[esp+14h] (8 bytes) at 0x9A5A7C in the panel fill FUN_009A5658, once the
; card's row is set: ESI = the card, EBX = its row, [esp+28h] = its column, [esp+14h] = the panel, [esp+2Ch] = the
; card list. UhcAgeFiveColumn gives the column (written back to [esp+28h]) or -1: the card is left out and its
; count in the row's counter [panel+4D0h+4*row] is taken back. EAX and the flags are free (the code after it sets
; them); the other registers are kept.
UhcAgeFivePanelColumnHook PROC
    TRACE_ONCE "ageFiveShipments panel column (0x9A5A7C)"
    pushad
    mov eax, dword ptr [esp+20h+14h]        ; the panel
    lea eax, [eax+ebx*4+4D0h]               ; the row's counter
    push 0                                  ; where: the in-game panel
    push eax
    push dword ptr [esp+20h+8+28h]          ; the column
    push esi                                ; the card
    push dword ptr [esp+20h+10h+2Ch]        ; the card list
    call UhcAgeFiveColumn
    mov dword ptr [esp+1Ch], eax            ; EAX after the popad
    popad
    cmp eax, -1
    je panelColLeftOut
    mov dword ptr [esp+28h], eax
    mov ecx, eax
    mov edx, dword ptr [esp+14h]
    jmp panelColContinue
panelColLeftOut:
    jmp panelColSkip
UhcAgeFivePanelColumnHook ENDP

; Replaces mov edx,[esp+14h] / mov eax,[esp+28h] (8 bytes) at 0x9A04B0 in the deck builder's fill: ESI = the card,
; EBP = the deck's card list, [esp+14h] = the column, [esp+28h] = the builder. -1 leaves the card out. ECX and the
; flags are free (lea ecx follows); EAX and EDX get the replaced loads.
UhcAgeFiveBuilderColumnHook PROC
    TRACE_ONCE "ageFiveShipments deck builder column (0x9A04B0)"
    pushad
    push 1                                  ; where: the deck builder
    push 0                                  ; no row counter
    push dword ptr [esp+20h+8+14h]          ; the column
    push esi                                ; the card
    push ebp                                ; the card list
    call UhcAgeFiveColumn
    mov dword ptr [esp+1Ch], eax
    popad
    cmp eax, -1
    je builderColLeftOut
    mov dword ptr [esp+14h], eax
    mov edx, eax
    mov eax, dword ptr [esp+28h]
    jmp builderColContinue
builderColLeftOut:
    jmp builderColSkip
UhcAgeFiveBuilderColumnHook ENDP

; Replaces mov ecx,[esp+30h] / lea eax,[ebx+ebx*2] (7 bytes) at 0x9A77E5 in the deck editor fill FUN_009A7670:
; ESI = the card, EBP = the deck's card list, EBX = the row, [esp+1Ch] = the column (added at 0x9A77F2). -1 leaves
; the card out. EAX, ECX and the flags get the replaced instructions' values.
UhcAgeFiveDeckColumnHook PROC
    TRACE_ONCE "ageFiveShipments deck editor column (0x9A77E5)"
    pushad
    push 2                                  ; where: the deck editor
    push 0                                  ; no row counter
    push dword ptr [esp+20h+8+1Ch]          ; the column
    push esi                                ; the card
    push ebp                                ; the card list
    call UhcAgeFiveColumn
    mov dword ptr [esp+1Ch], eax
    popad
    cmp eax, -1
    je deckColLeftOut
    mov dword ptr [esp+1Ch], eax
    mov ecx, dword ptr [esp+30h]
    lea eax, [ebx+ebx*2]
    jmp deckColContinue
deckColLeftOut:
    jmp deckColSkip
UhcAgeFiveDeckColumnHook ENDP

END
