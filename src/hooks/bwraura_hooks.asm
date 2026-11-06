; Hooks for buildingWorkRateAuras. The rate wrapper is the target of the redirected calls of the BuildingWorkRate getter and returns to its caller
; (docs/engine-symbols.md, "Building work rate auras").
.686
.model flat, c
option casemap :none

include common.inc

UhcBwrAuraRate PROTO STDCALL base:DWORD, unit:DWORD, caller:DWORD

kStatBuildingWorkRate EQU 40h       ; the new ModifyType stat; bwrauras.cpp uses the same value

UhcBwrPanelRate PROTO STDCALL unit:DWORD

.data
panelNext       dd 006F4A02h    ; jne 6F4A0Dh
workRateGetter  dd 009BFE33h    ; float thiscall(unit): the BuildingWorkRate getter (liveBuildingWorkRate may hook it)

.code

; Target of the calls of the getter at 0x9EA413 (Train), 0x9E65F7 (Research), 0x9D58D4
; (CommandResearch) and 0x6AB23F (Maintain), whose rel32 is redirected here, and of
; g_uhcBwrTrainGetter. Same contract as the getter, float thiscall(unit): ECX = the unit (the
; callers' mov ecx,[esi+10h]), x87 stack empty, [esp] = the return address into the caller.
; Returns ST0 = the rate, with ECX, EDX, EBX, ESI, EDI and EBP unchanged; EAX and the flags differ
; from stock, which the four callers allow (each writes EAX before reading it and calls a function
; before reading the flags). A unit without a modifier record ([[ecx+0B4h]+0C8h], created with its
; first modifier) tail-calls the getter, exactly the stock call. Any other unit gets the getter's
; rate times its BuildingWorkRate factor.
UhcBwrAuraCall PROC
    TRACE_ONCE "buildingWorkRateAuras (calls of 0x9BFE33)"
    mov eax, dword ptr [ecx+0B4h]   ; the unit's extension
    test eax, eax
    je stock
    cmp dword ptr [eax+0C8h], 0     ; its modifier record
    je stock
    TRACE_ONCE "buildingWorkRateAuras: a unit with modifiers (calls of 0x9BFE33)"
    push ecx
    push edx
    push dword ptr [esp+8]          ; caller: the return address, for the log
    push ecx                        ; unit
    call workRateGetter             ; ST0 = the stock rate; ECX is still the unit
    sub esp, 4
    fstp dword ptr [esp]            ; base: the getter's float (an fld of a float, so exact)
    call UhcBwrAuraRate             ; -> ST0 = base x factor; pops its three arguments
    pop edx
    pop ecx
    ret
stock:
    jmp workRateGetter              ; no modifier record: the stock call
UhcBwrAuraCall ENDP

; Replaces 0x6F49FC, fld dword ptr [edx+0D0h], in the data refs' reader. EAX = the selected unit, ECX
; the result; the jne at the continuation reads the flags of a cmp above, so they are kept. The rate is
; left on the x87 stack, as the fld did.
UhcBwrPanelHook PROC
    TRACE_ONCE "buildingWorkRateAuras panel (0x6F49FC)"
    pushfd
    push ecx
    push eax
    call UhcBwrPanelRate
    pop ecx
    popfd
    jmp panelNext
UhcBwrPanelHook ENDP

END
