; Hooks for buildingWorkRateAuras. The name hook is entered through a jmp written over the stock
; code and leaves through an explicit jmp to a verified continuation; the rate wrapper is the
; target of the redirected calls of the BuildingWorkRate getter and returns to its caller
; (docs/engine-symbols.md, "Building work rate auras").
.686
.model flat, c
option casemap :none

include common.inc

UhcBwrAuraRate PROTO STDCALL base:DWORD, unit:DWORD, caller:DWORD

kStatBuildingWorkRate EQU 40h       ; the new ModifyType stat; bwrauras.cpp uses the same value

.data
compareName     dd 00443C10h    ; int thiscall(BString*, const wchar_t*, flag, n), ret 0Ch: 0 = same name (case ignored)
nameTailNext    dd 005FE6DDh    ; pop esi / add eax,0Eh / ret: FUN_005F5645 returns EAX + 0Eh
workRateGetter  dd 009BFE33h    ; float thiscall(unit): the BuildingWorkRate getter (liveBuildingWorkRate may hook it)
bwrName         dw 'B','u','i','l','d','i','n','g','W','o','r','k','R','a','t','e',0

.code

; Replaces 0x5FE6D7..0x5FE6DC (neg eax / sbb eax,eax / and al,0F1h) in FUN_005F5645, the
; ModifyType name -> stat parser, after its last compare. EAX = that compare's result for
; "AutoGatherRate" (0: the same name), ESI = the name (BString*), [esp] = the ESI the function
; saved. Stock turns EAX into 0 (a match) or -0Fh and the tail adds 0Eh: stat 0Eh, or -1 for an
; unknown name. The hook keeps a match, gives "BuildingWorkRate" 40h - 0Eh and any other name
; -0Fh. EBX, ESI, EDI and EBP are kept (the compare is a compiled thiscall); ECX, EDX and the flags
; are dead at the tail, which sets the flags, and its two callers read only EAX.
UhcBwrModifyTypeHook PROC
    TRACE_ONCE "buildingWorkRateAuras (0x5FE6D7)"
    test eax, eax
    je done                         ; "AutoGatherRate": EAX = 0, the tail returns 0Eh
    push -1
    push 0
    push OFFSET bwrName
    mov ecx, esi
    call compareName                ; -> EAX = 0 for "BuildingWorkRate"
    test eax, eax
    jne unknown
    TRACE_ONCE "buildingWorkRateAuras ModifyType BuildingWorkRate (0x5FE6D7)"
    mov eax, kStatBuildingWorkRate - 0Eh
    jmp done
unknown:
    mov eax, -0Fh                   ; the tail returns -1, as in stock
done:
    jmp nameTailNext
UhcBwrModifyTypeHook ENDP

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

END
