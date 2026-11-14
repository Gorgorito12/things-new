; The tag hook of containedUnitsROF (features/containedrof.cpp), entered through a jmp written over the stock code
; and left through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Garrison scaling"). Its
; ROF reads are the shared hooks of rofreads_hooks.asm.
.686
.model flat, c
option casemap :none

include common.inc

UhcContainedRofTag PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD, :DWORD

.data
tagStock        dd 005FEE14h    ; jne 5FE713h: the stock handler's test of the value
tagNext         dd 005FA126h    ; mov eax,[esp+1Ch]: the parser's next child

.code

; Replaces cmp dword ptr [esp+10h],1 / mov eax,[ebp+64h] (8 bytes) at 0x5FEE0C, in the ScaleByContainedUnits
; handler of the action parser FUN_005F98A0, after the stock read of the text into [esp+10h] (0 when it is not a
; number). EDI = the tag's node, EBP = the action; the parser's arguments are at [esp+0C4h] (proto) and
; [esp+0C8h] (action), its return address at [esp+0C0h] (0x5FA213 a protoy <ProtoAction>, 0x5FA623 a tactics
; <action>; the frame of the action tag hook at 0x5FA11E, same depth). EAX and the flags are free at both
; continuations: the stock test sets them, and the next-child code overwrites them.
UhcContainedRofTagHook PROC
    TRACE_ONCE "containedUnitsROF tag (0x5FEE0C)"
    mov eax, dword ptr [esp+0C0h]
    cmp eax, 005FA213h
    je dispatch
    cmp eax, 005FA623h
    jne stock
dispatch:
    pushad
    push eax                            ; return address
    push dword ptr [esp+24h+10h]        ; the stock value
    push ebp                            ; action (the handler's own, also [esp+0C8h])
    push dword ptr [esp+2Ch+0C4h]       ; proto
    push edi                            ; the tag's node
    call UhcContainedRofTag
    mov dword ptr [esp+1Ch], eax        ; popad's EAX
    popad
    test eax, eax
    jne handled
stock:
    cmp dword ptr [esp+10h], 1          ; stolen 0x5FEE0C
    mov eax, dword ptr [ebp+64h]        ; stolen 0x5FEE11
    jmp tagStock
handled:
    jmp tagNext
UhcContainedRofTagHook ENDP

END
