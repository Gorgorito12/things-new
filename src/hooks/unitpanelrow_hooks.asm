; The unit panel's shared row (unitpanel.cpp). Entered through a jmp written over the stock code.
.686
.model flat, c
option casemap :none

include common.inc

UhcUnitPanelRows PROTO STDCALL panel:DWORD, unit:DWORD

.data
unitPanelNext   dd 0069945Ch    ; call 4826B5h: the unit panel goes on, after the stolen load

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

END
