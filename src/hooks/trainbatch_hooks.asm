; trainBatchSize (src/features/trainbatch.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcTrainBatchLimit PROTO STDCALL stockLimit:DWORD, protoId:DWORD, player:DWORD

.data
stockLimitFn    dd 008D051Bh    ; the limit of units per Train action, thiscall(player)
limitCallNext   dd 009CE64Ah    ; cmp bl,1 / mov ebp,eax

.code

; Replaces 0x9CE645 (call 0x8D051B) in the routine that queues units in a building. ECX = the player,
; [esp+30h] = the proto ID, as the routine reads it at 0x9CE6DE. The code that follows reads only EAX
; of what the call leaves (EDX is free).
UhcTrainBatchHook PROC
    TRACE_ONCE "trainBatchSize limit (0x9CE645)"
    push ecx                        ; the player, for the tech subtype's copy
    call stockLimitFn
    pop edx
    mov ecx, dword ptr [esp+30h]
    invoke UhcTrainBatchLimit, eax, ecx, edx
    jmp limitCallNext
UhcTrainBatchHook ENDP

END
