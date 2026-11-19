; Hook for kothTimer. Entered through a jmp over the head of FUN_009F02DD, the King of the Hill time; returns from
; that function itself, or leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcKothTime PROTO STDCALL vp:DWORD

.data
kothNext        dd 009F02E2h    ; mov edx,[eax+13Ch]: the stock function after its first instruction

.code

; Replaces 0x9F02DD..0x9F02E1 (mov eax,[0C66234h]). int thiscall(victory settings = ECX), no arguments, plain ret;
; its only caller is 0x948F95, which reads EAX. UhcKothTime returns the seconds, or 80000000h: then ECX is restored
; and the stolen load runs before the stock code. EAX, ECX and EDX are free in a thiscall.
UhcKothTimeHook PROC
    TRACE_ONCE "kothTimer (0x9F02DD)"
    push ecx
    push ecx                        ; the victory settings
    call UhcKothTime
    pop ecx
    cmp eax, 80000000h
    je stock
    ret
stock:
    mov eax, dword ptr ds:[0C66234h]  ; stolen 0x9F02DD
    jmp kothNext
UhcKothTimeHook ENDP

END
