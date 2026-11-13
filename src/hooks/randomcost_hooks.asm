; randomCost (src/features/randomcost.cpp). Each hook replaces one call and returns to the stock code as that call
; did: the same ret and AL where the stock code tests it. The C functions keep EBX, ESI, EDI and EBP.
.686
.model flat, c
option casemap :none

include common.inc

UhcRandomCostCopy PROTO STDCALL dst:DWORD, src:DWORD, playerProto:DWORD, player:DWORD
UhcRandomCostPay PROTO STDCALL player:DWORD, cost:DWORD, protoId:DWORD, count:DWORD
UhcRandomCostRecord PROTO STDCALL player:DWORD, protoId:DWORD, cost:DWORD, count:DWORD
UhcRandomCostRefund PROTO STDCALL player:DWORD, cost:DWORD

.code

; The cost getter's copy of the proto's cost at 0x480B5B: call 480A73h, thiscall(dst = ECX, src), ret 4.
; EBX = the player, EDI = the player's proto. Nothing after it reads EAX, ECX or EDX before setting them.
UhcRandomCostCopyHook PROC
    TRACE_ONCE "randomCost cost getter (0x480B5B)"
    mov eax, dword ptr [esp+4]
    invoke UhcRandomCostCopy, ecx, eax, edi, ebx
    ret 4
UhcRandomCostCopyHook ENDP

; The batch payment at 0x9EAF9A: call 8D946Ah, thiscall(player = ECX, cost), ret 4. EDI = the player's proto,
; EBP = the number of units paid at once. The stock code tests AL.
UhcRandomCostPayBatchHook PROC
    TRACE_ONCE "randomCost batch payment (0x9EAF9A)"
    mov eax, dword ptr [esp+4]
    mov edx, dword ptr [edi+8]
    invoke UhcRandomCostPay, ecx, eax, edx, ebp
    ret 4
UhcRandomCostPayBatchHook ENDP

; The per-unit payment at 0x9EB053, the same call for one unit.
UhcRandomCostPayOneHook PROC
    TRACE_ONCE "randomCost payment (0x9EB053)"
    mov eax, dword ptr [esp+4]
    mov edx, dword ptr [edi+8]
    invoke UhcRandomCostPay, ecx, eax, edx, 1
    ret 4
UhcRandomCostPayOneHook ENDP

; The entry's cost record at 0x9EB291: call 480B1Eh, thiscall(player = ECX, protoId, cost, count), ret 0Ch.
UhcRandomCostRecordHook PROC
    TRACE_ONCE "randomCost entry cost (0x9EB291)"
    push dword ptr [esp+12]  ; count
    push dword ptr [esp+12]  ; cost
    push dword ptr [esp+12]  ; protoId
    push ecx
    call UhcRandomCostRecord
    ret 0Ch
UhcRandomCostRecordHook ENDP

; The three refunds of an entry's cost record: call 8D7004h, thiscall(player = ECX, cost = entry + 8), ret 4.
UhcRandomCostRefundCancelHook PROC
    TRACE_ONCE "randomCost refund, cancel (0x9EB43E)"
    mov eax, dword ptr [esp+4]
    invoke UhcRandomCostRefund, ecx, eax
    ret 4
UhcRandomCostRefundCancelHook ENDP

UhcRandomCostRefundAllHook PROC
    TRACE_ONCE "randomCost refund, queue emptied (0x9EB60D)"
    mov eax, dword ptr [esp+4]
    invoke UhcRandomCostRefund, ecx, eax
    ret 4
UhcRandomCostRefundAllHook ENDP

UhcRandomCostRefundSpawnHook PROC
    TRACE_ONCE "randomCost refund, failed spawn (0x9EBA5D)"
    mov eax, dword ptr [esp+4]
    invoke UhcRandomCostRefund, ecx, eax
    ret 4
UhcRandomCostRefundSpawnHook ENDP

END
