; annexFacing (src/features/annexfacing.cpp). Each hook is entered through a jmp written over the stock code, re-executes
; the instruction it replaced, and leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcAnnexForward PROTO STDCALL command:DWORD, unitProto:DWORD, player:DWORD
UhcAnnexGhost PROTO STDCALL visual:DWORD

.data
forwardNext dd 007D7CF7h    ; push eax: the forward's address, for the right vector 0x423792
ghostNext   dd 0096E4ECh    ; mov ecx,[eax+13Ch]

.code

; Replaces 0x7D7CF1 (lea eax,[edi+0A8h]) in the build command's executor: EDI = the command, EBX = the player's copy of
; the proto, EBP = the player. The helper may write the forward at [edi+0A8h]; every register and the flags are kept,
; then the replaced lea writes EAX as stock does.
UhcAnnexForwardHook PROC
    TRACE_ONCE "annexFacing build command (0x7D7CF1)"
    pushfd
    pushad
    push ebp
    push ebx
    push edi
    call UhcAnnexForward
    popad
    popfd
    lea eax, [edi+0A8h]
    jmp forwardNext
UhcAnnexForwardHook ENDP

; Replaces 0x96E4E7 (mov eax,[0C66234h]) in the placement ghost's update, before its placement test: ESI = the ghost's
; visual. The helper may turn the visual's axes; every register and the flags are kept, then the replaced line.
UhcAnnexGhostHook PROC
    TRACE_ONCE "annexFacing ghost (0x96E4E7)"
    pushfd
    pushad
    push esi
    call UhcAnnexGhost
    popad
    popfd
    mov eax, dword ptr ds:[0C66234h]
    jmp ghostNext
UhcAnnexGhostHook ENDP

END
