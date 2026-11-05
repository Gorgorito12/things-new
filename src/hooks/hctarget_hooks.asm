; hcTargetTechs (src/features/hctargets.cpp): the stock heads of the two routines the key replaces with a
; jmp. The C++ wrappers call these, which re-execute the replaced instructions and leave through an
; explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

.data
removeNext      dd 0094DCB8h    ; push edi, in removeEffects
loadNext        dd 0094DDF1h    ; xor ebx,ebx, in the pass after a load

.code

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
