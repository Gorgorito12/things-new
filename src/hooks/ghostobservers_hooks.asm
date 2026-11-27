; The placement ghost's update (src/ghostobservers.cpp), shared by annexFacing and displayedRange. The hook is entered
; through a jmp written over the stock code, re-executes the instruction it replaced, and leaves through an explicit jmp
; to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcGhostUpdate PROTO STDCALL visual:DWORD

.data
ghostNext   dd 0096E4ECh    ; mov ecx,[eax+13Ch]

.code

; Replaces 0x96E4E7 (mov eax,[0C66234h]) in the placement ghost's update FUN_0096E062, before its placement test:
; ESI = the ghost's visual. The observers may turn the visual's axes or hang models on it; every register and the
; flags are kept, then the replaced line writes EAX, which 0x96E4EC reads.
UhcGhostUpdateHook PROC
    TRACE_ONCE "placement ghost update (0x96E4E7)"
    pushfd
    pushad
    push esi
    call UhcGhostUpdate
    popad
    popfd
    mov eax, dword ptr ds:[0C66234h]
    jmp ghostNext
UhcGhostUpdateHook ENDP

END
