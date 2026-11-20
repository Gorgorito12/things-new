; The tech button's rollover (src/techrollover.cpp), shared by researchGrants and shipTechLimit. Display only.
.686
.model flat, c
option casemap :none

include common.inc

UhcTechRolloverLines PROTO STDCALL entry:DWORD, player:DWORD, unit:DWORD, rollover:DWORD, overlay:DWORD

.data
kTechRollover dd 004C737Ch      ; the tech rollover builder, cdecl with 8 arguments

.code

; Replaces the call of the tech rollover builder 0x4C737C at 0x4622C5 in the command panel refresh FUN_0046188E.
; Entry: the 8 cdecl arguments at [esp+4]..[esp+20h] (the rollover, the tech entry, the player, the unit, 1, 0, 1,
; 1); the panel's ESP before it pushed them is ESP+24h here, so the button's overlay text [esp+2C0h] there is
; [esp+2E4h]. Calls the builder with the same arguments, then the keys' lines. The panel cleans the arguments
; (add esp,20h) and reloads EAX, ECX and EDX before use; EBX, ESI, EDI and EBP are kept by both calls.
UhcTechRolloverHook PROC
    TRACE_ONCE "tech rollover (0x4622C5)"
    push dword ptr [esp+20h]
    push dword ptr [esp+20h]
    push dword ptr [esp+20h]
    push dword ptr [esp+20h]
    push dword ptr [esp+20h]
    push dword ptr [esp+20h]
    push dword ptr [esp+20h]
    push dword ptr [esp+20h]
    call dword ptr [kTechRollover]
    add esp, 20h
    lea eax, [esp+2E4h]
    push eax                    ; the overlay text
    push dword ptr [esp+8]      ; the rollover
    push dword ptr [esp+18h]    ; the unit
    push dword ptr [esp+18h]    ; the player
    push dword ptr [esp+18h]    ; the tech entry
    call UhcTechRolloverLines
    ret
UhcTechRolloverHook ENDP

END
