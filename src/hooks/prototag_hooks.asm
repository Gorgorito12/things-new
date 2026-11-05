; The shared hook for new proto tags (src/prototags.h). Entered through a jmp written over the stock
; code; it leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcProtoTagsRegister PROTO STDCALL table:DWORD

.data
tableBuilderRet dd 0051DB14h    ; ret of FUN_0051CE1D

.code

; Replaces 0x51DB0F..0x51DB13 (pop edi / mov al,1 / pop esi / pop ecx), the tail of the tag table's
; builder, after its last registration. EDI = the builder's object: the protos' table is at +0Ch
; (0x51CE27), and ESI by now is the second table, at +0C2Ch (0x51D807). The hook re-executes those
; instructions after the helper.
UhcProtoTagsHook PROC
    TRACE_ONCE "proto tags (0x51DB0F)"
    lea eax, [edi+0Ch]
    invoke UhcProtoTagsRegister, eax
    pop edi
    mov al, 1
    pop esi
    pop ecx
    jmp tableBuilderRet
UhcProtoTagsHook ENDP

END
