; researchGrants (src/features/researchgrants.cpp): the step of a research with a Time factor. Each hook replaces
; `fadd dword ptr [esi+X] / fstp dword ptr [esi+X]` (6 bytes), the add of this update's step to the progress,
; and continues at the call of the fraction that follows it, whose argument is already pushed. On entry ST0 is the
; step (the only value on the x87 stack), ESI the action, ECX = ESI. With no such research in progress the step
; is added as in stock; otherwise UhcGrantResearchStep gives the step to add. pushad / popad keep every register.
.686
.model flat, c
option casemap :none

include common.inc

UhcGrantResearchStep PROTO STDCALL action:DWORD, offs:DWORD, entry:DWORD, stp:DWORD
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

END
