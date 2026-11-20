; The hook of transformChecks in the transform command's per-unit execute FUN_007D64F7 (thiscall(cmd, unit),
; ret 4), which every machine runs inside the world update. Entered through a jmp written over the stock code, it
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcXformAllowed PROTO STDCALL player:DWORD, playerProto:DWORD, unit:DWORD

.data
placeNext  dd 007D65EBh    ; cmp byte [esi+90h],0: the payment, then the new unit
placeFail  dd 007D6762h    ; the refusal: the cost list's destructor, AL = 0, ret 4

.code

; 0x7D65E3: test al,al / je 7D6762h (8 B), right after PLACE (world vtable +14h) returned in AL. ESI = the
; command, EBP = the unit, [esp+30h] the player, [esp+14h] the player's copy of the target proto. A refusal of
; PLACE goes to the refusal as in stock; an acceptance asks UhcXformAllowed (the build limit) and goes on to the
; payment only when it agrees. Every register but EAX is kept; EAX is not read before it is loaded again at
; either continuation (AL only fed the stolen test).
UhcXformPlaceHook PROC
    TRACE_ONCE "transformChecks placement result (0x7D65E3)"
    test al, al
    je refuse
    pushad
    push ebp                            ; the unit
    push dword ptr [esp+24h+14h]        ; the player's proto (pushad 20h + one push)
    push dword ptr [esp+28h+30h]        ; the player (pushad 20h + two pushes)
    call UhcXformAllowed
    mov dword ptr [esp+1Ch], eax        ; the EAX that popad restores
    popad
    test al, al
    je refuse
    jmp placeNext
refuse:
    jmp placeFail
UhcXformPlaceHook ENDP

END
