; The tech <Flag> reader's head (src/techflags.cpp), shared by the keys that read flags of their own. It leaves
; through an explicit jmp to the verified continuation, or returns for a flag a key took.
.686
.model flat, c
option casemap :none

include common.inc

UhcTechFlagDispatch PROTO STDCALL :DWORD, :DWORD

.data
flagNext        dd 00620C34h    ; test esi,esi, in the flag reader

.code

; The flag reader, cdecl (record, name): replaces 0x620C2F..0x620C33 (push esi / mov esi,[esp+8]). The head, not
; its one call 0x620C23: another DLL may wrap the call, and what it does not know still reaches this head. EAX, ECX
; and EDX are free at a cdecl head.
UhcTechFlagHook PROC
    TRACE_ONCE "tech flags (0x620C2F)"
    push dword ptr [esp+8]          ; name
    push dword ptr [esp+8]          ; record, [esp+4] + the push
    call UhcTechFlagDispatch
    test al, al
    jz stock
    ret
stock:
    push esi
    mov esi, dword ptr [esp+8]
    jmp flagNext
UhcTechFlagHook ENDP

END
