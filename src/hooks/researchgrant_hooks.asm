; researchGrants (src/features/researchgrants.cpp). Its line in the tech rollover goes through the shared hook of
; techrollover_hooks.asm. The step of a research with a Time factor. Each hook replaces
; `fadd dword ptr [esi+X] / fstp dword ptr [esi+X]` (6 bytes), the add of this update's step to the progress,
; and continues at the call of the fraction that follows it, whose argument is already pushed. On entry ST0 is the
; step (the only value on the x87 stack), ESI the action, ECX = ESI. With no such research in progress the step
; is added as in stock; otherwise UhcGrantResearchStep gives the step to add. pushad / popad keep every register.
.686
.model flat, c
option casemap :none

include common.inc

UhcGrantResearchStep PROTO STDCALL action:DWORD, offs:DWORD, entry:DWORD, stp:DWORD
UhcGrantTipCost PROTO STDCALL list:DWORD, from:DWORD, entry:DWORD, player:DWORD, unit:DWORD
EXTERN g_uhcGrantTimed:DWORD

.data
kResearchStepBack dd 009E6628h  ; call 9E5F19h, the Research fraction
kCommandStepBack  dd 009D5905h  ; call 9D539Bh, the CommandResearch fraction

.code

; 0x9E6622 in the Research update FUN_009E648B: the progress is [esi+6Ch], EBX the tech's status entry.
UhcGrantResearchStepHook PROC
    TRACE_ONCE "researchGrants research step (0x9E6622)"
    cmp g_uhcGrantTimed, 0
    je add_step
    sub esp, 4
    fstp dword ptr [esp]
    pushad
    push dword ptr [esp+32]
    push ebx
    push 6Ch
    push esi
    call UhcGrantResearchStep
    popad
    add esp, 4
add_step:
    fadd dword ptr [esi+6Ch]
    fstp dword ptr [esi+6Ch]
    jmp dword ptr [kResearchStepBack]
UhcGrantResearchStepHook ENDP

; 0x9D58FF in the CommandResearch update FUN_009D5843: the progress is [esi+70h], EDI the tech's status entry.
UhcGrantCommandStepHook PROC
    TRACE_ONCE "researchGrants command research step (0x9D58FF)"
    cmp g_uhcGrantTimed, 0
    je add_step
    sub esp, 4
    fstp dword ptr [esp]
    pushad
    push dword ptr [esp+32]
    push edi
    push 70h
    push esi
    call UhcGrantResearchStep
    popad
    add esp, 4
add_step:
    fadd dword ptr [esi+70h]
    fstp dword ptr [esi+70h]
    jmp dword ptr [kCommandStepBack]
UhcGrantCommandStepHook ENDP

; Replaces the call of the ResList copy 0x480A73 at 0x4C73FD in the rollover builder 0x4C737C, the copy of the
; tech's cost into the list whose cost the rollover shows. ECX = that list, [esp+4] = the cost to copy; the
; builder's ESP before it pushed it is ESP+8 here, so its arguments are the tech entry [esp+58h], the player
; [esp+5Ch] and the unit [esp+60h]. UhcGrantTipCost copies and returns the list as the copy does (ret 4); the
; builder keeps nothing in EAX, ECX or EDX across the call.
UhcGrantTipCostHook PROC
    TRACE_ONCE "researchGrants tech rollover cost (0x4C73FD)"
    push dword ptr [esp+60h]    ; the unit
    push dword ptr [esp+60h]    ; the player
    push dword ptr [esp+60h]    ; the tech entry
    push dword ptr [esp+10h]    ; the cost to copy
    push ecx                    ; the list
    call UhcGrantTipCost
    ret 4
UhcGrantTipCostHook ENDP

END
