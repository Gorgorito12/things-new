; The research payment (src/researchpay.cpp), shared by nextResearchFree and researchGrants. Both replace a call
; of the payment 0x8D946A, whose argument, the cost, is already on the stack, and return to the stock code as
; that call did: al, ret 4.
.686
.model flat, c
option casemap :none

include common.inc

UhcResearchPay PROTO STDCALL action:DWORD, player:DWORD, cost:DWORD

.code

; The call at 0x9E67E1 in the Research action's start. ECX = the player, EBP = the action.
UhcResearchPayHook PROC
    TRACE_ONCE "research payment (0x9E67E1)"
    mov eax, dword ptr [esp+4]
    invoke UhcResearchPay, ebp, ecx, eax
    ret 4
UhcResearchPayHook ENDP

; The call at 0x9D54CF in the CommandResearch action's start. ECX = the player, ESI = the action.
UhcCommandResearchPayHook PROC
    TRACE_ONCE "command research payment (0x9D54CF)"
    mov eax, dword ptr [esp+4]
    invoke UhcResearchPay, esi, ecx, eax
    ret 4
UhcCommandResearchPayHook ENDP

END
