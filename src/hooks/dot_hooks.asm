; Hooks for damageOverTime (features/damageovertime.cpp). Each is entered through a jmp written
; over the stock code and leaves through an explicit jmp to a verified continuation
; (docs/engine-symbols.md, "Damage and poison").
.686
.model flat, c
option casemap :none

include common.inc

UhcDotProtoActionTag PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD

EXTERNDEF g_uhcDotTakeDamage:DWORD      ; float fastcall(target, -, the 13 stock arguments)

.data
takeDamageBody      dd 0049B3DFh    ; cmp byte ptr [esp+0C0h],1, after the stolen sub esp,8Ch
lastTagHandler      dd 005FD4EDh    ; stock je target: the "ModifyExclusive" handler
nextChild           dd 005FA126h    ; mov eax,[esp+1Ch]: the loop's next child

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

; The world update's tick goes through the shared wrapper of worldtick.cpp (AddWorldTick).

; Replaces test eax,eax / je 5FD4EDh at 0x5FA11E in FUN_005F98A0, after its last tag compare
; ("ModifyExclusive"). Reached only by that tag and by tags the stock parser does not know.
; ESI = the address of the child's tag-name BString (its UTF-16 text is [esi]), EDI = the child node; the
; arguments are at [esp+0C4h] (proto) and [esp+0C8h] (action), the return address at
; [esp+0C0h]. Unknown tags of a protoy.xml <ProtoAction> go to the C++ handler.
UhcDotProtoActionTagHook PROC
    test eax, eax                   ; stolen 0x5FA11E
    jne unknownTag
    jmp lastTagHandler              ; stolen 0x5FA120: je 5FD4EDh
unknownTag:
    cmp dword ptr [esp+0C0h], 005FA213h ; return address of the ProtoAction handler's call
    jne next
    TRACE_ONCE "damageOverTime ProtoAction tag (0x5FA11E)"
    pushad
    mov eax, dword ptr [esp+20h+0C4h]   ; proto
    mov ecx, dword ptr [esp+20h+0C8h]   ; action
    push ecx
    push eax
    push edi
    push esi
    call UhcDotProtoActionTag
    popad
next:
    jmp nextChild
UhcDotProtoActionTagHook ENDP

END
