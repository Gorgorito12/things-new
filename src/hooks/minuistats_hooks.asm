; minUIStats (features/minuistats.cpp): the stat panel fill's minimized-interface gate. Entered through a jmp written
; over the stock code; leaves through an explicit jmp to one of the two stock continuations.
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcMinUiForceFill:DWORD     ; 1 while minUIStats runs the fill for the minimized panel's rows

.data
statFillReturn  dd 004D81A1h    ; pop edi / ... / ret 4: the fill's end, stock with option 49h
statFillGo      dd 004D7267h    ; lea ecx,[esp+14h]: the first row

.code

; Replaces 0x4D725C..0x4D7266 (cmp byte ptr [esp+63h],1 / je 4D81A1h) in FUN_004D70ED: byte [esp+63h] is profile
; option 49h, optionminimizedui, read just above. Stock returns there; this goes on to the rows when the DLL asked
; for them (g_uhcMinUiForceFill), and otherwise does what stock does. Registers are untouched; the flags are dead
; at both continuations (lea, then the fill's own tests).
UhcStatFillMinGate PROC
    TRACE_ONCE "minUIStats stat fill gate (0x4D725C)"
    cmp byte ptr [esp+63h], 1
    jne go
    cmp g_uhcMinUiForceFill, 0
    jne go
    jmp statFillReturn
go:
    jmp statFillGo
UhcStatFillMinGate ENDP

END
