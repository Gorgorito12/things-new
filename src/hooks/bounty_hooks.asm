; teamKillBounty and resourceBounty (src/features/bounty.cpp). Entered through a jmp written over the stock code; it leaves
; through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcIsTeamBounty PROTO STDCALL victim:DWORD, amount:DWORD
UhcPayResourceBounty PROTO STDCALL victim:DWORD, killer:DWORD

.data
teamPayNext     dd 0049BDB1h    ; push 0 / push ecx / push edx / mov ecx,eax / call 0x49BDC0
killBranchNext  dd 004D4E11h    ; mov ecx,esi / call 0x4D4DC5

.code

; Replaces 0x49BDAB..0x49BDB0 (mov ecx,[esp+14h] / mov edx,[esi]) in FUN_0049BD52, its only caller being
; TakeDamage at 0x49B73C. EAX = the killer's team, ESI = the killer's player, [esp] = the ESI the function
; saved: the caller's, the victim. EDX and ECX go to the XP routine: the player ID, -1 for the whole
; team, and the amount. The routine runs on every hit, with an amount of 0 unless the hit kills, so the
; helper only runs for a bounty.
UhcTeamBountyHook PROC
    TRACE_ONCE "teamKillBounty (0x49BDAB)"
    cmp dword ptr [esp+14h], 0
    je killer
    push eax
    mov ecx, dword ptr [esp+4]
    mov edx, dword ptr [esp+18h]
    invoke UhcIsTeamBounty, ecx, edx
    test al, al
    pop eax
    je killer
    mov ecx, dword ptr [esp+14h]
    or edx, -1
    jmp teamPayNext
killer:
    mov ecx, dword ptr [esp+14h]
    mov edx, dword ptr [esi]
    jmp teamPayNext
UhcTeamBountyHook ENDP

; Replaces 0x4D4E0C..0x4D4E10 (mov ecx,[esp+28h] / push ecx), re-executed here, on the kill branch of
; TakeDamage. ESI = the victim, [esp+20h] = the killer's player. The next call overwrites EAX, ECX and EDX.
UhcResourceBountyHook PROC
    TRACE_ONCE "resourceBounty (0x4D4E0C)"
    mov ecx, dword ptr [esp+20h]
    invoke UhcPayResourceBounty, esi, ecx
    mov ecx, dword ptr [esp+28h]
    push ecx
    jmp killBranchNext
UhcResourceBountyHook ENDP

END
