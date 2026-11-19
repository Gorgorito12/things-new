; The unit panel's shared row (unitpanel.cpp). Entered through a jmp written over the stock code.
.686
.model flat, c
option casemap :none

include common.inc

UhcUnitPanelRows PROTO STDCALL panel:DWORD, unit:DWORD
UhcUnitPanelTail PROTO STDCALL panel:DWORD, selection:DWORD, unit:DWORD, minimized:DWORD

.data
unitPanelNext   dd 0069945Ch    ; call 4826B5h: the unit panel goes on, after the stolen load
unitTailNext    dd 004C828Bh    ; push edi: the portrait count, after the two stolen loads

.code

; Replaces 0x699456..0x69945B (mov edi,[esp+54h] / mov ecx,edi) in the unit panel's cold part, the
; join point after its own AutoGather rate row ([esp+50h] = the panel, [esp+54h] = the unit). The
; stat panel fill does not run with the minimized interface; this is where that interface's row
; is written. Nothing else changes.
UhcUnitPanelHook PROC
    TRACE_ONCE "unit panel row (0x699456)"
    pushad
    push dword ptr [esp+20h+54h]        ; the unit
    push dword ptr [esp+24h+50h]        ; the panel
    call UhcUnitPanelRows
    popad
    mov edi, dword ptr [esp+54h]        ; stolen 0x699456
    mov ecx, edi                        ; stolen 0x69945A
    jmp unitPanelNext
UhcUnitPanelHook ENDP

; Replaces 0x4C8281..0x4C828A (mov esi,[esp+50h] / mov edi,[esi+308h]) in the selection panel fill
; FUN_004C7E52, where both interfaces pass: the minimized block (0x6987D7..0x69A60F) jumps back here. The frame:
; [esp+50h] the panel, [esp+54h] the first selected unit (null when none), [esp+78h] the selection, byte
; [esp+5Eh] the profile option 49h the block was chosen by. Every register is restored; the flags are dead (the
; continuation pushes and calls).
UhcUnitPanelTailHook PROC
    TRACE_ONCE "unit panel tail (0x4C8281)"
    pushad
    movzx eax, byte ptr [esp+20h+5Eh]
    push eax                            ; the minimized block ran
    push dword ptr [esp+24h+54h]        ; the unit
    push dword ptr [esp+28h+78h]        ; the selection
    push dword ptr [esp+2Ch+50h]        ; the panel
    call UhcUnitPanelTail
    popad
    mov esi, dword ptr [esp+50h]        ; stolen 0x4C8281
    mov edi, dword ptr [esi+308h]       ; stolen 0x4C8285
    jmp unitTailNext
UhcUnitPanelTailHook ENDP

END
