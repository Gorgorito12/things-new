; Hook for orPrereqsQty. Entered through a jmp written over the head of the prerequisite list evaluator
; FUN_005094B4; leaves through an explicit jmp to the verified continuation, or returns from the evaluator itself.
.686
.model flat, c
option casemap :none

include common.inc

UhcOrQtyEval PROTO STDCALL list:DWORD, player:DWORD, orFlag:DWORD

.data
evalNext        dd 005094B9h    ; push ebp / push esi / test bl,bl: the stock evaluator after its first two instructions

.code

; Replaces 0x5094B4..0x5094B8 (push ebx / mov bl,[esp+0Ch]). bool thiscall(list = ECX, Player* [esp+4], bool or
; [esp+8]), ret 8. UhcOrQtyEval returns 0 or 1 for a list it evaluates (returned as AL, ret 8, as the stock exits
; 0x5094D5 and 0x67C418 do), or -1: then ECX is restored and the two stolen instructions run before the stock code.
; EAX and EDX are free on entry (thiscall); EBX, ESI, EDI and EBP are kept by the C++ code.
UhcOrQtyEvalHook PROC
    TRACE_ONCE "orPrereqsQty (0x5094B4)"
    push ecx
    push dword ptr [esp+0Ch]        ; or, [esp+8] + the push
    push dword ptr [esp+0Ch]        ; player, [esp+4] + two pushes
    push ecx                        ; list
    call UhcOrQtyEval
    pop ecx
    cmp eax, -1
    je stock
    ret 8
stock:
    push ebx                        ; stolen 0x5094B4
    mov bl, byte ptr [esp+0Ch]      ; stolen 0x5094B5
    jmp evalNext
UhcOrQtyEvalHook ENDP

END
