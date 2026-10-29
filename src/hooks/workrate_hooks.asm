; Hook for liveBuildingWorkRate. Entered through a jmp written over the first two instructions of
; the BuildingWorkRate getter; leaves through an explicit jmp to the getter's own tail
; (docs/engine-symbols.md, "Building work rate").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcBwrLog:SDWORD        ; 1 with "liveBuildingWorkRate log", else 0

UhcBwrLogUnit PROTO STDCALL unit:DWORD

.data
bwrTail         dd 009BFE3Eh    ; mov eax,[ecx+5Ch] / fld dword ptr [eax+0D0h] / ret: the proto's rate

.code

; Replaces 0x9BFE33..0x9BFE37 (mov eax,[ecx+68h] / test eax,eax) in the getter, float
; thiscall(unit), whose next instruction (je 9BFE3Eh) chose between the building data's snapshot
; [[ecx+68h]+28h] and the proto's current rate [[ecx+5Ch]+0D0h]. ECX = the unit and the x87
; stack is empty (the callers are compiled calls). The hook always takes the proto's rate. It
; re-executes the two stolen instructions last, so EFLAGS are the ones stock returns with; EAX
; returns as the tail leaves it (the proto, not the building data), which all four callers
; overwrite before reading. Every other register, ESP and the x87 stack depth are as in stock.
UhcBwrGetterHook PROC
    TRACE_ONCE "liveBuildingWorkRate (0x9BFE33)"
    cmp g_uhcBwrLog, 0
    je live
    pushad
    push ecx
    call UhcBwrLogUnit              ; logs the unit if its snapshot differs from the proto's rate
    popad
live:
    mov eax, dword ptr [ecx+68h]    ; stolen 0x9BFE33 (building data), for the flags
    test eax, eax                   ; stolen 0x9BFE36
    jmp bwrTail
UhcBwrGetterHook ENDP

END
