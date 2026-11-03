; Hook for marketUnits (src/features/unitlists.cpp). Entered through a jmp over mov edx,[0C66234h]
; at 0x7DEF70 (6 B), where ESI is the player, ECX = [esi+80h] its kb, and [esp+10h] the player ID;
; leaves through an explicit jmp to the verified continuations.
.686
.model flat, c
option casemap :none

include common.inc

UhcHasMarketUnit PROTO STDCALL kb:DWORD, player:DWORD
UhcExplorerType PROTO STDCALL protoId:DWORD
UhcExplorerString PROTO STDCALL protoId:DWORD

.data
marketAllowed dd 007DEFC3h   ; the player owns a market: trade
marketStock   dd 007DEF76h   ; mov eax,[edx+140h] (the stock Market tests)
explorerNameExplorer dd 006A0179h   ; the home city's explorer name
explorerNameOther    dd 006A0203h   ; the path for other units
explorerNameHero     dd 006A01B8h   ; push 0: the first hero name
explorerNameStock    dd 006A0132h   ; test al,al after the name-empty test
bstringIsEmpty       dd 00401F47h
explorerKoPush       dd 0050B039h   ; lea ecx,[esp+18h] / call 447719h (load the pushed string)
explorerKoStock      dd 0050B025h   ; mov eax,[eax+4]

.code

UhcMarketUnitsHook PROC
    TRACE_ONCE "marketUnits trade test (0x7DEF70)"
    push ecx
    push dword ptr [esp+14h]        ; the player ID ([esp+10h] at the site)
    push ecx
    call UhcHasMarketUnit
    pop ecx
    test al, al
    jz stock
    jmp marketAllowed
stock:
    mov edx, dword ptr ds:[0C66234h]
    jmp marketStock
UhcMarketUnitsHook ENDP

; 0x6A012A in the unit name function FUN_004702DC: lea ecx,[eax+18h] / call 401F47h (8 B), with
; EAX = the home city ([edi+84h]), [ebp+8] = the unit's proto ID, ESI = the database.
UhcExplorerNameHook PROC
    TRACE_ONCE "explorerUnits hero name (0x6A012A)"
    push ecx
    push edx
    push eax                        ; the home city
    push dword ptr [ebp+8]
    call UhcExplorerType            ; EAX = the Type, or -1
    mov dword ptr [esp+8], eax      ; into the saved ECX slot
    pop eax
    pop edx
    pop ecx                         ; ECX = the Type
    cmp ecx, -1
    je stockName
    cmp ecx, 1
    je asExplorer
    test ecx, ecx
    je asOther
    jmp explorerNameHero
asExplorer:
    jmp explorerNameExplorer
asOther:
    jmp explorerNameOther
stockName:
    lea ecx, [eax+18h]
    call bstringIsEmpty
    jmp explorerNameStock
UhcExplorerNameHook ENDP

; 0x50B01F in the hero knockout message: mov edx,[esi+10h] / mov eax,[edx+5Ch] (6 B); ESI+10h
; holds the unit, [proto+4] its proto ID. A listed proto pushes its string ID and continues where
; the stock Explorer case loads its pushed string (0x50B039).
UhcExplorerKnockoutHook PROC
    TRACE_ONCE "explorerUnits knockout message (0x50B01F)"
    mov edx, dword ptr [esi+10h]
    mov eax, dword ptr [edx+5Ch]
    push ecx
    push edx
    push eax
    push dword ptr [eax+4]
    call UhcExplorerString
    mov ecx, eax
    pop eax
    pop edx
    cmp ecx, -1
    je stockKo
    xchg ecx, dword ptr [esp]       ; restore ECX, leave the string ID on the stack
    jmp explorerKoPush
stockKo:
    pop ecx
    jmp explorerKoStock
UhcExplorerKnockoutHook ENDP

END
