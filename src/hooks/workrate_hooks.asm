; Hooks for liveBuildingWorkRate.
; - The BuildingWorkRate getter: entered through a jmp written over its first two instructions;
;   leaves through an explicit jmp to the getter's own tail (docs/engine-symbols.md, "Building
;   work rate").
; - TrainPoints: the Train and Maintain fraction functions, entered through a jmp written over
;   their first two instructions (fld / fcomp); each refreshes the action's cached points, then
;   re-executes the two instructions and continues in the stock function (docs/engine-symbols.md,
;   "Train points").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcBwrLog:SDWORD        ; 1 with "liveBuildingWorkRate log", else 0

UhcBwrLogUnit PROTO STDCALL unit:DWORD
UhcTrainPointsRefresh PROTO STDCALL action:DWORD
UhcMaintainPointsRefresh PROTO STDCALL action:DWORD

.data
bwrTail         dd 009BFE3Eh    ; mov eax,[ecx+5Ch] / fld dword ptr [eax+0D0h] / ret: the proto's rate
trainFracNext   dd 009EA203h    ; fnstsw ax, after fld [ecx+64h] / fcomp [0C3755Ch]
maintainFracNext dd 009E27EDh   ; fnstsw ax, after fld [ecx+6Ch] / fcomp [0C37468h]

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

; Replaces 0x9EA1FA..0x9EA202 (fld dword ptr [ecx+64h] / fcomp dword ptr [0C3755Ch]), the head of
; the Train fraction function, void thiscall(action), frac [ecx+6Ch] = progress [ecx+68h] /
; points [ecx+64h]. Its only caller is the Train update (0x9EA4B3), with an empty x87 stack.
; UhcTrainPointsRefresh writes the current TrainPoints into [ecx+64h] (stock took them once, when
; the unit was queued). pushad / popad keep every register; the two stolen instructions run after
; it, so the x87 stack and the FPU status are the ones stock has at 0x9EA203, whose fnstsw / test
; set the flags again. Every register, ESP and the return address are as in stock.
UhcTrainFracHook PROC
    TRACE_ONCE "liveBuildingWorkRate TrainPoints (0x9EA1FA)"
    pushad
    push ecx
    call UhcTrainPointsRefresh      ; [ecx+64h] = the current TrainPoints, when they differ
    popad
    fld dword ptr [ecx+64h]         ; stolen 0x9EA1FA
    fcomp dword ptr ds:[00C3755Ch]  ; stolen 0x9EA1FD (1e-6)
    jmp trainFracNext
UhcTrainFracHook ENDP

; Replaces 0x9E27E4..0x9E27EC (fld dword ptr [ecx+6Ch] / fcomp dword ptr [0C37468h]), the head of
; the Maintain fraction function, [ecx+74h] = [ecx+70h] / [ecx+6Ch], called only by the Maintain
; update (0x6AB264). Same contract as UhcTrainFracHook; UhcMaintainPointsRefresh writes the cycle's
; current points into [ecx+6Ch] (stock took them when the cycle started).
UhcMaintainFracHook PROC
    TRACE_ONCE "liveBuildingWorkRate Maintain TrainPoints (0x9E27E4)"
    pushad
    push ecx
    call UhcMaintainPointsRefresh   ; [ecx+6Ch] = the cycle's current points, when they differ
    popad
    fld dword ptr [ecx+6Ch]         ; stolen 0x9E27E4
    fcomp dword ptr ds:[00C37468h]  ; stolen 0x9E27E7
    jmp maintainFracNext
UhcMaintainFracHook ENDP

END
