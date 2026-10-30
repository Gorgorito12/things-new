; Hooks for decimalPopulation (features/decimalpop.cpp): the player effect PopulationCap, the
; shared-team cap and the game-start cap bonus get the population scale K.
; Each hook is entered through a jmp written over the stock code and leaves through an explicit
; jmp to the continuation verified in tools/gen_sites.py; nothing is relocated.
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcPopScale:SDWORD

.data
popCapAddReturn     dd 008D87B3h    ; movzx eax, word ptr [esp+34h]
popCapRemoveReturn  dd 008D20B3h    ; movzx eax, word ptr [esp+20h]
teamPopCapReturn    dd 006796B8h    ; add ebx, eax
startPopBonusReturn dd 00A0D2D9h    ; push eax

.code

; Replaces 0x8D87AB..0x8D87B2 (fld dword ptr [esp+34h] / fnstcw word ptr [esp+34h]) in the
; player effect switch FUN_008D842B, case 14h (PopulationCap, absolute only): the amount, a
; float, is then truncated by fistp and added to getCap(). It is multiplied by K and rounded
; first, so the truncation keeps an exact integer.
UhcPopCapEffectAddHook PROC
    TRACE_ONCE "decimalPopulation PopulationCap effect (0x8D87AB)"
    fld dword ptr [esp+34h]
    fimul g_uhcPopScale
    frndint
    fnstcw word ptr [esp+34h]
    jmp popCapAddReturn
UhcPopCapEffectAddHook ENDP

; The same at 0x8D20AB..0x8D20B2 (fld / fnstcw at [esp+20h]), where the effect is taken back:
; getCap() minus the truncated amount.
UhcPopCapEffectRemoveHook PROC
    TRACE_ONCE "decimalPopulation PopulationCap effect removed (0x8D20AB)"
    fld dword ptr [esp+20h]
    fimul g_uhcPopScale
    frndint
    fnstcw word ptr [esp+20h]
    jmp popCapRemoveReturn
UhcPopCapEffectRemoveHook ENDP

; Replaces 0x679694..0x6796B7 in getCap's shared-team path (GameTeamSharePop): each ally adds
; min(its raw cap, 200, [world+31Ch]). EAX = that ally's raw cap, already scaled; the 200 and
; the world's limit are scaled here. ECX and EDX are free (stock overwrites both).
UhcTeamPopCapHook PROC
    TRACE_ONCE "decimalPopulation team population cap (0x679694)"
    mov ecx, 0C8h
    imul ecx, g_uhcPopScale
    cmp eax, ecx
    jle belowBase
    mov eax, ecx
belowBase:
    mov ecx, dword ptr ds:[00C66234h]
    mov edx, [ecx+13Ch]
    mov ecx, [edx+31Ch]
    imul ecx, g_uhcPopScale
    cmp eax, ecx
    jle belowWorld
    mov eax, ecx
belowWorld:
    jmp teamPopCapReturn
UhcTeamPopCapHook ENDP

; Replaces 0xA0D2D1..0xA0D2D8 (add eax,ebx / add eax,[esi+320h]) at game start, where each
; player's cap becomes getCap() + [player+7Ch] + [world+320h]: the two bonuses are in whole
; population and get K. EBX is kept as stock leaves it; EDX is free (the next call is a
; thiscall that does not take it).
UhcStartPopBonusHook PROC
    TRACE_ONCE "decimalPopulation start cap bonus (0xA0D2D1)"
    mov edx, ebx
    add edx, dword ptr [esi+320h]
    imul edx, g_uhcPopScale
    add eax, edx
    jmp startPopBonusReturn
UhcStartPopBonusHook ENDP

END
