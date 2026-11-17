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
minBlockGo      dd 006987D7h    ; the selection panel's minimized block
panelTailGo     dd 004C8281h    ; the fill's tail (the shared tail hook, unitpanel.cpp)

.code

; Replaces 0x4C8276..0x4C8280 (cmp byte ptr [esp+5Eh],1 / je 6987D7h) in the selection panel fill FUN_004C7E52:
; byte [esp+5Eh] is profile option 49h, optionminimizedui. Stock runs the minimized block with the option on.
; This also runs it when the panel was built from a minimized layout with the option off (another DLL can force
; that layout without the option): the panel's unitHitPointsLabel handle [panel+2F0h] (bound at 0x9BAD77) is a real
; gadget only in the minimized layouts. The byte is then set to 1, as the block's way back and the tail read it.
; EAX is kept (the block and the tail reload what they use: EBX, the unit, is untouched); the flags are dead.
UhcMinBlockChoice PROC
    TRACE_ONCE "minUIStats minimized block choice (0x4C8276)"
    cmp byte ptr [esp+5Eh], 1
    je minimized
    push eax
    mov eax, dword ptr [esp+4+50h]      ; the panel
    mov eax, dword ptr [eax+2F0h]       ; its unitHitPointsLabel handle
    test eax, eax
    jz normal
    cmp eax, dword ptr ds:[00C672C0h]   ; the "no gadget" handle
    je normal
    pop eax
    mov byte ptr [esp+5Eh], 1
minimized:
    jmp minBlockGo
normal:
    pop eax
    jmp panelTailGo
UhcMinBlockChoice ENDP

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
