; Hooks for damageOverTime (features/damageovertime.cpp). Each is entered through a jmp written
; over the stock code and leaves through an explicit jmp to a verified continuation
; (docs/engine-symbols.md, "Damage and poison").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcDotTakeDamage:DWORD      ; float fastcall(target, -, the 13 stock arguments)

.data
takeDamageBody      dd 0049B3DFh    ; cmp byte ptr [esp+0C0h],1, after the stolen sub esp,8Ch

.code

; Replaces sub esp,8Ch at 0x49B3D9, the entry of TakeDamage (float thiscall(unit, 13 arguments),
; ret 34h). The frame is unchanged, so the fastcall wrapper receives it as its own: ECX = the
; damaged unit, the stack arguments in place.
UhcDotTakeDamageHook PROC
    TRACE_ONCE "damageOverTime TakeDamage (0x49B3D9)"
    jmp g_uhcDotTakeDamage
UhcDotTakeDamageHook ENDP

; The stock TakeDamage for the wrapper: the stolen instruction, then the rest of the function.
UhcDotTakeDamageStock PROC
    sub esp, 8Ch
    jmp takeDamageBody
UhcDotTakeDamageStock ENDP

; The world update's tick goes through the shared wrapper of worldtick.cpp (AddWorldTick), and the
; <ProtoAction> tags through the shared action tag hook of actiontags.cpp (AddActionTagHandler).

END
