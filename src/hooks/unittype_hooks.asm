; Hook for the extra abstract unit types (unittypes.cpp). Entered through a jmp written over the
; stock code; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcRegisterAbstractUnitTypes PROTO STDCALL :DWORD

.data
epilogueRest    dd 0051BA36h    ; pop ecx / ret

.code

; Replaces 0x51BA31..0x51BA35 (pop edi / pop esi / mov al,1 / pop ebx), the epilogue of
; FUN_0051A5DC once the stock abstract types are registered. EDI = database.
UhcAbstractUnitTypesHook PROC
    TRACE_ONCE "abstract unit types (0x51BA31)"
    pushad
    push edi
    call UhcRegisterAbstractUnitTypes
    popad
    pop edi
    pop esi
    mov al, 1
    pop ebx
    jmp epilogueRest
UhcAbstractUnitTypesHook ENDP

END
