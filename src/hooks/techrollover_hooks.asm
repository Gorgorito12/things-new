; The tech rollover (src/techrollover.cpp), shared by researchGrants and shipTechLimit. Display only.
.686
.model flat, c
option casemap :none

include common.inc

UhcTechRolloverExit PROTO STDCALL frame:DWORD

.data
kRolloverRet dd 004C78F8h       ; the builder's stock ret

.code

; Replaces pop ebp / pop ebx / add esp,40h at 0x4C78F3, the only exit of the tech rollover builder 0x4C737C (cdecl
; with 8 arguments; its early exits jump to 0x4C78F3 too). After those three instructions [esp] is the return
; address and [esp+4]..[esp+20h] the arguments: the rollover, the tech entry, the player, the unit, then four flags.
; UhcTechRolloverExit gets that frame, tells the caller by its return address (the command panel, the native or the
; trade route panel) and calls the keys' lines. Every register is kept (EAX too: one caller, 0x703F99, returns it);
; then the stock ret.
UhcTechRolloverExitHook PROC
    TRACE_ONCE "tech rollover (0x4C78F3)"
    pop ebp
    pop ebx
    add esp, 40h
    pushad
    lea eax, [esp+20h]          ; the frame: the return address, then the arguments
    push eax
    call UhcTechRolloverExit
    popad
    jmp dword ptr [kRolloverRet]
UhcTechRolloverExitHook ENDP

END
