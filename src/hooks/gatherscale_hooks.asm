; Hook for autoGatherScaleByContained. Entered through a jmp written over the stock code; it leaves
; through an explicit jmp to a verified continuation, or returns for the stock body it called
; (docs/engine-symbols.md, "Garrison scaling").
.686
.model flat, c
option casemap :none

include common.inc

.data
rateBody    dd 0049EBEAh    ; test ebx,ebx: the AutoGather rate getter after its first three instructions
capFloor    dd 0.0          ; the value of 0xB84BE4, which the stock attack code compares the cap with

.code

; Replaces 0x49EBE4..0x49EBE9 (push ecx / push ebx / mov ebx,[esp+0Ch]), the entry of the AutoGather
; rate getter, float thiscall(action, int resource), ret 4. ECX = the unit action, whose [ecx+4] is
; the tactics action. Without the tactics flag ScaleByContainedUnits (bit 18 of the flag bytes
; [+64h], count of bits [+68h]) the stock body runs as if nothing happened. With it, the stock body
; runs as a call, and the rate is multiplied as the stock attack multiplies its damage (0x4996C7,
; 0x6A4B83): by the unit's contained count [unit+74h], at most DamageFactorCap [+48h] when that is
; above 0. EAX, ECX and EDX are free at a thiscall entry; ST0 holds the result on return.
UhcAutoGatherRateHook PROC
    TRACE_ONCE "autoGatherScaleByContained (0x49EBE4)"
    mov eax, dword ptr [ecx+4]
    cmp dword ptr [eax+68h], 12h
    jbe stock
    mov eax, dword ptr [eax+64h]
    test byte ptr [eax+2], 4
    jne scaled
stock:
    push ecx                        ; stolen 0x49EBE4
    push ebx                        ; stolen 0x49EBE5
    mov ebx, dword ptr [esp+0Ch]    ; stolen 0x49EBE6
    jmp rateBody
scaled:
    push esi
    mov esi, ecx
    push dword ptr [esp+8]          ; the resource
    call body                       ; returns here with its ret 4 done, the rate in ST0
    mov ecx, dword ptr [esi+10h]
    mov eax, dword ptr [esi+4]
    pop esi
    fild dword ptr [ecx+74h]        ; ST0 = factor, ST1 = rate
    fld dword ptr [eax+48h]         ; ST0 = cap
    fcom st(1)                      ; cap against factor
    fnstsw ax
    test ah, 41h                    ; cap <= factor?
    je keep                         ; no: the factor stands
    fcom capFloor
    fnstsw ax
    test ah, 41h                    ; cap <= 0?
    jne keep                        ; yes: no cap
    fxch st(1)
keep:
    fstp st(0)                      ; drop the one not used
    fmulp st(1), st(0)
    ret 4
body:
    push ecx                        ; stolen 0x49EBE4
    push ebx                        ; stolen 0x49EBE5
    mov ebx, dword ptr [esp+0Ch]    ; stolen 0x49EBE6
    jmp rateBody
UhcAutoGatherRateHook ENDP

END
