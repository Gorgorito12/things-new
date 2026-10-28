; Hooks for the limit features (deckCardCount, basePop/extraPop).
; Each hook is entered through a jmp written over the stock code and leaves through an explicit
; jmp to the continuation verified in docs/uhc-address-map.md; nothing is relocated.
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcDeckCardCount:SDWORD
EXTERNDEF g_uhcBasePop:SDWORD
EXTERNDEF g_uhcExtraPop:SDWORD

.data
deckLimitReturn dd 007EF030h    ; ret 4
popLimitReturn  dd 0045823Fh    ; pop esi / add esp,8 / ret

.code

; Replaces 0x7EF026..0x7EF02F (cmp eax,19h / jle / mov eax,19h). EAX holds the deck size.
UhcDeckLimitHook PROC
    TRACE_ONCE "deckCardCount (0x7EF026)"
    cmp eax, g_uhcDeckCardCount
    jle done
    mov eax, g_uhcDeckCardCount
done:
    jmp deckLimitReturn
UhcDeckLimitHook ENDP

; Replaces 0x4581F3..0x45823E. In: ECX = extra population, EAX = population cap,
; EDX = the player data whose [+4F4h] adds a bonus. ESI is free: the continuation pops it.
; Stock also clamps against [[[C66234h]+13Ch]+31Ch] (initialized to 200) and caps at 250;
; both are dropped, as upstream does, or basePop above 200 would have no effect.
UhcPopLimitHook PROC
    TRACE_ONCE "basePop/extraPop (0x4581F3)"
    cmp ecx, g_uhcExtraPop
    jle UhcPopLimitBaseHook
    mov ecx, g_uhcExtraPop
UhcPopLimitHook ENDP
; Falls through. Also entered from 0x4581FC, where stock jumps with ECX = 0 when the extra
; population is negative (0x679611); upstream misses that path.
UhcPopLimitBaseHook PROC
    mov esi, g_uhcBasePop
    add esi, ecx
    cmp eax, esi
    jle capOk
    mov eax, esi
capOk:
    mov edx, [edx + 4F4h]
    test edx, edx
    jle done
    add eax, edx
done:
    jmp popLimitReturn
UhcPopLimitBaseHook ENDP

END
