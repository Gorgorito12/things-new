; Hook for enableAllTeams (src/features/teams.cpp). Entered through a jmp over push 8D31h at
; 0x7A0709 in FUN_007A0628; leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcAddTeamEntries PROTO STDCALL frame:DWORD

.data
teamDropdownReturn dd 007A070Eh   ; lea ecx,[esp+14h] / call 58EA52h (the "?" entry)

.code

UhcTeamDropdownHook PROC
    TRACE_ONCE "enableAllTeams setup list (0x7A0709)"
    pushfd
    pushad
    lea eax, [esp+36]               ; ESP at the hooked instruction (pushad 32 B + pushfd 4 B)
    push eax
    call UhcAddTeamEntries
    popad
    popfd
    push 00008D31h
    jmp teamDropdownReturn
UhcTeamDropdownHook ENDP

END
