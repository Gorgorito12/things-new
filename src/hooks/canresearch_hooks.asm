; The can-research test's head (src/canresearch.cpp), shared by shipTechLimit and homeCityTechsInUnits.
.686
.model flat, c
option casemap :none

include common.inc

UhcCanResearchRefused PROTO STDCALL status:DWORD, unit:DWORD
EXTERN g_uhcCanResearchFilters:DWORD

.data
canResearchNext dd 004C696Dh    ; push esi: the stock test after its first two instructions

.code

; 0x4C6968: push ebp / mov ebp,[esp+8] (5 B), the head of bool thiscall(status, unit), ret 4. No branch lands
; inside it. On entry ECX = the status, [esp+4] = the unit. EAX and EDX are free (the caller expects them
; clobbered); ECX is kept for the stock test. A refused tech returns 0 with ret 4, as the stock test's false.
UhcCanResearchHook PROC
    TRACE_ONCE "can-research test (0x4C6968)"
    cmp g_uhcCanResearchFilters, 0
    je stock
    push ecx
    push dword ptr [esp+8]          ; the unit
    push ecx                        ; the status
    call UhcCanResearchRefused
    pop ecx
    test al, al
    jne refused
stock:
    push ebp
    mov ebp, dword ptr [esp+8]
    jmp canResearchNext
refused:
    xor eax, eax
    ret 4
UhcCanResearchHook ENDP

END
