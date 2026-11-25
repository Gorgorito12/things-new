; The entries of a unit into another, shared by the keys that observe them (src/garrisonobservers.cpp). Entered
; through a jmp written over the stock code; it leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcGarrisonDispatch PROTO STDCALL container:DWORD, unit:DWORD

.data
enterNext       dd 009C26E8h    ; mov eax,[0C66234h]: the store of the game time in the action manager
enterDone       dd 009C26FFh    ; pop ebx: the load returns true

.code

; Replaces mov edi,[edi+58h] / test edi,edi / je 9C26FFh (7 bytes) at 0x9C26E1, the success tail of the load
; FUN_009C24B5: EDI = the container, ESI = the unit, after [unit+6Ch] = the container's ID (0x9C25C2) and the
; append of the unit's ID to [container+70h] (0x9C26DC). The stock code after it reads EDI (the action manager,
; replayed here) and writes EAX, ECX and EDX before reading them; invoke keeps EBX, ESI and EDI.
UhcGarrisonEnterHook PROC
    TRACE_ONCE "garrison entries (0x9C26E1)"
    invoke UhcGarrisonDispatch, edi, esi
    mov edi, dword ptr [edi+58h]
    test edi, edi
    je skip
    jmp enterNext
skip:
    jmp enterDone
UhcGarrisonEnterHook ENDP

END
