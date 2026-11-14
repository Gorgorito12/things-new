; Hooks for the limit features (deckCardCount, basePop/extraPop; decimalPopulation scales the
; population cap hook).
; Each hook is entered through a jmp written over the stock code and leaves through an explicit
; jmp to the continuation verified in src/generated/sites.h; nothing is relocated.
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcDeckCardCount:SDWORD
EXTERNDEF g_uhcBasePop:SDWORD
EXTERNDEF g_uhcExtraPop:SDWORD
EXTERNDEF g_uhcPopScale:SDWORD
EXTERNDEF g_uhcPopStockClamps:SDWORD

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
; basePop/extraPop drop both, or basePop above 200 would have no effect.
; decimalPopulation installs the same hook when neither key is set, with g_uhcPopStockClamps
; = 1 so both clamps stay. Every limit (base, extra, world, bonus, 250) is in whole population and
; is multiplied by g_uhcPopScale (1 without decimalPopulation), the scale of EAX.
UhcPopLimitHook PROC
    TRACE_ONCE "basePop/extraPop/decimalPopulation (0x4581F3)"
    cmp ecx, g_uhcExtraPop
    jle UhcPopLimitBaseHook
    mov ecx, g_uhcExtraPop
UhcPopLimitHook ENDP
; Falls through. Also entered from 0x4581FC, where stock jumps with ECX = 0 when the extra
; population is negative (0x679611); that path must be covered too.
UhcPopLimitBaseHook PROC
    mov esi, g_uhcBasePop
    add esi, ecx
    imul esi, g_uhcPopScale
    cmp eax, esi
    jle capOk
    mov eax, esi
capOk:
    cmp g_uhcPopStockClamps, 0
    je bonus
    mov esi, dword ptr ds:[00C66234h]   ; stock 0x45820A: min(cap, extra + [world+31Ch])
    mov esi, [esi + 13Ch]
    mov esi, [esi + 31Ch]
    add esi, ecx
    imul esi, g_uhcPopScale
    cmp eax, esi
    jle bonus
    mov eax, esi
bonus:
    mov edx, [edx + 4F4h]
    test edx, edx
    jle bonusDone
    imul edx, g_uhcPopScale
    add eax, edx
bonusDone:
    cmp g_uhcPopStockClamps, 0
    je done
    mov esi, 0FAh                       ; stock 0x458234: at most 250
    imul esi, g_uhcPopScale
    cmp eax, esi
    jle done
    mov eax, esi
done:
    jmp popLimitReturn
UhcPopLimitBaseHook ENDP

END
