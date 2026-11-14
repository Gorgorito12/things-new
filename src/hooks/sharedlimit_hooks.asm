; sharedBuildLimit (src/features/sharedlimit.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcSharedLimit PROTO STDCALL player:DWORD, protoUnit:DWORD, returnAddress:DWORD

.data
limitEntryNext  dd 004C7B64h    ; mov ecx,[esp+14h], the rest of the stock limit

.code

; Replaces 0x4C7B5F..0x4C7B63 (sub esp,10h / mov edx,ecx), the entry of the limit, thiscall(player,
; proto), ret 4. No branch lands inside them.
UhcSharedLimitHook PROC
    TRACE_ONCE "sharedBuildLimit limit (0x4C7B5F)"
    mov eax, dword ptr [esp+4]
    mov edx, dword ptr [esp]
    invoke UhcSharedLimit, ecx, eax, edx
    ret 4
UhcSharedLimitHook ENDP

; The stock limit, for the helper: the two instructions the hook replaced, then the rest.
UhcSharedLimitStock PROC
    sub esp, 10h
    mov edx, ecx
    jmp limitEntryNext
UhcSharedLimitStock ENDP

END
