; resendableCards (src/features/resendcards.cpp): the age setter's join and the card rollover's cost test. Each
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcResendAgeUp PROTO STDCALL player:DWORD, notAdvance:DWORD
UhcResendCard PROTO STDCALL card:DWORD

.data
ageNext         dd 008D5034h    ; mov ecx,[eax+13Ch], in the age setter
costShow        dd 0071080Ah    ; mov eax,[ebp] / push eax / mov ecx,edi / call 852F11h: the sends-left test
costHide        dd 00710863h    ; past the cost line

.code

; Replaces mov eax,[0C66234h] at 0x8D502F in the age setter FUN_008D4E01 (thiscall(player, age, announce, tech)),
; the join every path takes once the new age is in [esi+50h] (0x8D4F49, 0x8D4F54, 0x8D4F5F and the fall-through
; after the age-up message). ESI = the player; the byte [esp+13h] is 1 when the old age was the same or higher
; (0x8D4EE3..0x8D4EF2, same frame). EAX, ECX and EDX are written before they are read after 0x8D5034
; (mov ecx,[eax+13Ch], the cmp at 0x8D503A, mov edx,[esi] at 0x8D505D); EBX, ESI, EDI and EBP are kept by the call.
UhcResendAgeHook PROC
    TRACE_ONCE "resendableCards age (0x8D502F)"
    movzx eax, byte ptr [esp+13h]
    push eax
    push esi
    call UhcResendAgeUp
    mov eax, dword ptr ds:[0C66234h]
    jmp ageNext
UhcResendAgeHook ENDP

; Replaces cmp dword ptr [eax+50h],4 / jne 710863h at 0x710804 in the card rollover builder FUN_007103CE, reached
; only for the local player's own card whose byte [ebp+24h] is not 0, with EAX = the player and EBP = the card.
; Age 4 goes on as stock; otherwise a card with the resend bit goes on to the sends-left test too, and any other
; card skips the cost line as stock. EAX and ECX are reloaded at 0x71080A; EDX is not read before it is written.
UhcResendCostHook PROC
    TRACE_ONCE "resendableCards rollover (0x710804)"
    cmp dword ptr [eax+50h], 4
    je show
    push ebp
    call UhcResendCard
    test al, al
    jz hide
show:
    jmp costShow
hide:
    jmp costHide
UhcResendCostHook ENDP

END
