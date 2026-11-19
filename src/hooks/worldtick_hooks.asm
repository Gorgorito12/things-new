; The world update wrapper's entry and trampoline (worldtick.cpp), shared by every key that needs a
; per-step tick. Entered through a jmp written over the stock code at 0x481A57.
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcWorldUpdate:DWORD        ; bool fastcall(world, -, the 2 stock arguments)

.data
worldUpdateBody     dd 00481A5Ch    ; push esi / mov esi,ecx, after the stolen prologue

.code

; Replaces sub esp,0Ch / push ebx / push ebp (5 bytes) at 0x481A57, the entry of the world update
; FUN_00481A57 (thiscall(world, int, deltaMs), ret 8).
; The frame is unchanged, so the fastcall wrapper receives it as its own: ECX = world, the stack
; arguments in place.
UhcWorldUpdateHook PROC
    TRACE_ONCE "world update (0x481A57)"
    jmp g_uhcWorldUpdate
UhcWorldUpdateHook ENDP

; The stock world update for the wrapper: the stolen prologue, then the rest of the function.
UhcWorldUpdateStock PROC
    sub esp, 0Ch
    push ebx
    push ebp
    jmp worldUpdateBody
UhcWorldUpdateStock ENDP

END
