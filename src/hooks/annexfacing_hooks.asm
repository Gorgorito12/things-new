; annexFacing (src/features/annexfacing.cpp). Each hook is entered through a jmp written over the stock code, re-executes
; the instruction it replaced, and leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcAnnexForward PROTO STDCALL command:DWORD, unitProto:DWORD, player:DWORD
UhcAnnexGhost PROTO STDCALL visual:DWORD
UhcAnnexAiPlace PROTO STDCALL fwd:DWORD, rightVec:DWORD, point:DWORD, protoId:DWORD, playerId:DWORD
UhcAnnexAiScan PROTO STDCALL fwd:DWORD, rightVec:DWORD, point:DWORD, protoId:DWORD, playerId:DWORD

.data
forwardNext dd 007D7CF7h    ; push eax: the forward's address, for the right vector 0x423792
ghostNext   dd 0096E4ECh    ; mov ecx,[eax+13Ch]
aiPlaceNext dd 0073D7D7h    ; lea edi,[ebp+50h]
aiScanNext  dd 0087DBA5h    ; call [esi+14h], the PLACE of the scan

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

; Replaces 0x73D7D2 (lea ebx,[esp+38h] / push ebx) in an AI build plan's placement test, before PLACE at 0x73D7E3:
; EBX becomes the forward's address, [esp] holds the right vector's (pushed first), EBP = the plan's data (position
; +50h, proto +ACh), EAX = the player. The helper may write both vectors; every register and the flags are kept.
UhcAnnexAiPlaceHook PROC
    lea ebx, [esp+38h]
    TRACE_ONCE "annexFacing AI placement (0x73D7D2)"
    pushfd
    pushad
    push eax                        ; player
    push dword ptr [ebp+0ACh]       ; proto
    lea ecx, [ebp+50h]
    push ecx                        ; position
    push dword ptr [esp+30h]        ; right: [esp] at entry, +4 pushfd, +20h pushad, +0Ch the three pushes
    push ebx                        ; forward
    call UhcAnnexAiPlace
    popad
    popfd
    push ebx
    jmp aiPlaceNext
UhcAnnexAiPlaceHook ENDP

; Replaces 0x87DB9F (fchs / fstp [esp+60h], the last store of the world's axes) in the AI's scan of candidate spots,
; with PLACE's arguments pushed: [esp] proto, +4 player, +8 position, +0Ch forward, +10h right. The FPU stack is
; empty after the replayed store; the helper may write both vectors; every register and the flags are kept.
UhcAnnexAiScanHook PROC
    fchs
    fstp dword ptr [esp+60h]
    TRACE_ONCE "annexFacing AI spot scan (0x87DB9F)"
    pushfd
    pushad
    push dword ptr [esp+24h+4]      ; player: [esp+4] at entry, +24h for pushfd and pushad
    push dword ptr [esp+24h+4]      ; proto: [esp] at entry, +4 for the push above
    push dword ptr [esp+24h+10h]    ; position: [esp+8] at entry, +8
    push dword ptr [esp+24h+1Ch]    ; right: [esp+10h] at entry, +0Ch for the three pushes above
    push dword ptr [esp+24h+1Ch]    ; forward: [esp+0Ch] at entry, +10h for the four pushes above
    call UhcAnnexAiScan
    popad
    popfd
    jmp aiScanNext
UhcAnnexAiScanHook ENDP

END
