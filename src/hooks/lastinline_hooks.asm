; fastLastInLine (src/features/lastinline.cpp). Each hook is entered through a jmp written over the stock code,
; replaces or re-executes what it overwrote, and leaves through an explicit jmp to a verified continuation or a ret
; that the stock function would have made itself.
.686
.model flat, c
option casemap :none

include common.inc

UhcLastInLine PROTO STDCALL tree:DWORD, player:DWORD
UhcLastInLineCompare PROTO STDCALL tree:DWORD

.data
stockDirtyTest  dd 004918B3h    ; cmp byte ptr [ebp+11h],0 / jne 68FB0Ch, then pop ebp / pop ecx / ret 4
scanExitNext    dd 0068FC20h    ; mov ecx,[eax+920h]: after the mov eax,[0C66234h] the verify hook replaces

.code

; Replaces 0x4918A8..0x4918B0 (push ecx / cmp dword ptr [esp+8],0 / push ebp / mov ebp,ecx), the head of the
; LastInLine recompute, thiscall(tree = ECX, Player* = [esp+4]), ret 4. With no player or a clean tree it returns
; as the stock code does (the stock pushes and pops ECX and EBP and writes nothing). Otherwise the C++ recompute runs;
; when it returns 1 (verify, or an index that does not fit the tree) the head is re-executed and the stock dirty
; test at 0x4918B3 takes over, with the stack laid out as the stock code expects: EBP and ECX pushed, EBP = the tree.
; EAX, ECX and EDX are free in a thiscall; EBX, ESI, EDI and EBP are preserved by the stdcall.
UhcLastInLineHook PROC
    TRACE_ONCE "fastLastInLine (0x4918A8)"
    cmp dword ptr [esp+4], 0        ; the player, as the stolen cmp [esp+8],0 after push ecx
    je done
    cmp byte ptr [ecx+11h], 0       ; the dirty byte, as 0x4918B3
    je done
    push ecx                        ; keep the tree
    push dword ptr [esp+8]          ; Player*
    push ecx                        ; tree
    call UhcLastInLine
    pop ecx
    test eax, eax
    jnz stock
done:
    ret 4
stock:
    push ecx                        ; stolen 0x4918A8
    push ebp                        ; stolen 0x4918AE
    mov ebp, ecx                    ; stolen 0x4918AF
    jmp stockDirtyTest
UhcLastInLineHook ENDP

; `verify`: replaces mov eax,[0C66234h] at 0x68FC1B, where the stock loop ends (from its last iteration, and from
; jle 68FC1Bh at 0x68FB16 when the tree is empty). EBP = the tree. Compares, re-executes the instruction and goes on.
UhcLastInLineVerifyEndHook PROC
    TRACE_ONCE "fastLastInLine verify (0x68FC1B)"
    pushad
    pushfd
    push ebp
    call UhcLastInLineCompare
    popfd
    popad
    mov eax, dword ptr ds:[00C66234h]   ; stolen 0x68FC1B
    jmp scanExitNext
UhcLastInLineVerifyEndHook ENDP

END
