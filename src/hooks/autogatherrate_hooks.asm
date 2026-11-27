; The shared hook of the AutoGather rate getter (autogatherrate.cpp): autoGatherScaleByContained and
; nurseryFactor. Entered through a jmp written over the stock code; it leaves through an explicit jmp to the
; verified continuation, or returns for the stock body it called (docs/how-it-works.md, "autoGatherScaleByContained").
.686
.model flat, c
option casemap :none

include common.inc

UhcAutoGatherRateAsk PROTO STDCALL unitAction:DWORD, resource:DWORD
EXTERN g_uhcAgFactor:DWORD

.data
rateBody    dd 0049EBEAh    ; test ebx,ebx: the AutoGather rate getter after its first three instructions

.code

; Replaces 0x49EBE4..0x49EBE9 (push ecx / push ebx / mov ebx,[esp+0Ch]), the entry of the AutoGather rate getter,
; float thiscall(unitAction, int resource), ret 4. ECX = the unit action; [esp+4] = the resource. EAX, ECX and EDX
; are free at a thiscall entry, and the x87 stack is empty. The asker (stdcall, C) keeps EBX, ESI, EDI and EBP.
; It returns 0: the stock getter runs as if nothing happened, bit for bit. 1: the stock body runs as a call, so that
; its ret 4 comes back here with the rate in ST0, which is multiplied by g_uhcAgFactor (a float).
UhcAutoGatherRateHook PROC
    TRACE_ONCE "AutoGather rate filters (0x49EBE4)"
    push ecx                        ; keep the unit action
    push dword ptr [esp+8]          ; the resource
    push ecx                        ; the unit action
    call UhcAutoGatherRateAsk
    pop ecx
    test eax, eax
    jne scaled
    push ecx                        ; stolen 0x49EBE4
    push ebx                        ; stolen 0x49EBE5
    mov ebx, dword ptr [esp+0Ch]    ; stolen 0x49EBE6
    jmp rateBody
scaled:
    push dword ptr [esp+4]          ; the resource, for the body's ret 4
    call body                       ; returns here with the rate in ST0
    fmul dword ptr g_uhcAgFactor
    ret 4
body:
    push ecx                        ; stolen 0x49EBE4
    push ebx                        ; stolen 0x49EBE5
    mov ebx, dword ptr [esp+0Ch]    ; stolen 0x49EBE6
    jmp rateBody
UhcAutoGatherRateHook ENDP

END
