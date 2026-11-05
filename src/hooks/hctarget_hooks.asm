; hcTargetTechs (src/features/hctargets.cpp): the hook on the tech flag reader, and the stock heads of the
; two routines the key replaces with a jmp. The C++ wrappers call these, which re-execute the replaced
; instructions and leave through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

.data
flagNext        dd 00620C34h    ; test esi,esi, in the flag reader
removeNext      dd 0094DCB8h    ; push edi, in removeEffects
loadNext        dd 0094DDF1h    ; xor ebx,ebx, in the pass after a load

.code

UhcTechFlag PROTO STDCALL :DWORD, :DWORD

; The flag reader, cdecl (entry, name): replaces 0x620C2F..0x620C33 (push esi / mov esi,[esp+8]). The head,
; not its one call: another DLL may wrap the call, and what it does not know still reaches this head.
UhcTechFlagHook PROC
    TRACE_ONCE "hcTargetTechs flag (0x620C2F)"
    push dword ptr [esp+8]
    push dword ptr [esp+8]
    call UhcTechFlag
    test al, al
    jz stock
    ret
stock:
    push esi
    mov esi, dword ptr [esp+8]
    jmp flagNext
UhcTechFlagHook ENDP

; removeEffects: replaces 0x94DCB2..0x94DCB7 (push ebx / push ebp / mov ebp,[esp+0Ch]).
UhcTechRemoveStock PROC
    TRACE_ONCE "hcTargetTechs remove (0x94DCB2)"
    push ebx
    push ebp
    mov ebp, dword ptr [esp+0Ch]
    jmp removeNext
UhcTechRemoveStock ENDP

; The pass after a load: replaces 0x94DDEA..0x94DDF0 (push ebx / push ebp / push edi / mov edi,[esp+10h]).
UhcTechLoadStock PROC
    TRACE_ONCE "hcTargetTechs load (0x94DDEA)"
    push ebx
    push ebp
    push edi
    mov edi, dword ptr [esp+10h]
    jmp loadNext
UhcTechLoadStock ENDP

END
