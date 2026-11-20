; The shared hook on each command panel button (panelbuttons.*), in the refresh FUN_0046188E. Entered
; through a jmp written over the stock code, it leaves through an explicit jmp to the verified
; continuation. Interface only: the filters change how a button looks and what a click on it sends.
.686
.model flat, c
option casemap :none

include common.inc

UhcPanelButton PROTO STDCALL frame:DWORD

.data
buttonNext dd 0046231Eh    ; jge 69700Dh: the grid is full

.code

; 0x462317: mov ebx,[esp+1Ch] / cmp ebx,6 (7 B, followed by the jge at 0x46231E), at the start of the
; layout of one button: [esp+24h] its state, [esp+1C0h] / [esp+3C0h] its click and shift-click
; commands, [esp+2C0h] its overlay text, [esp+18h] its rollover. The filters get the frame (ESP at the
; site); every register is kept, then the stock instructions run again and set the flags of the jge.
UhcPanelButtonHook PROC
    TRACE_ONCE "command panel button (0x462317)"
    pushad
    lea eax, [esp+20h]
    push eax
    call UhcPanelButton
    popad
    mov ebx, dword ptr [esp+1Ch]
    cmp ebx, 6
    jmp buttonNext
UhcPanelButtonHook ENDP

END
