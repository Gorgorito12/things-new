; Hook for buildingGather. Entered through a jmp written over the Gather update's exit test at 0x4EC76B; leaves
; through an explicit jmp to one of its two verified continuations (docs/engine-symbols.md, "Gather action").
.686
.model flat, c
option casemap :none

include common.inc

UhcBuildingGatherApproach PROTO STDCALL action:DWORD   ; state 0 of an immobile gatherer: state 5 or 9

.data
stateCNext      dd 00586D8Bh    ; the stock branch for state 0Ch (je 586D8Bh)
exitNext        dd 004EC773h    ; pop ebx / pop edi / pop esi / pop ebp / add esp,0Ch / ret

.code

; Replaces cmp al,0Ch / je 586D8Bh (8 bytes) at 0x4EC76B, in the Gather update FUN_004EC4FA (thiscall(action),
; plain ret; vtable 0xB97880 +3Ch). On entry AL = the action's state byte [esi+61h] (just read at 0x4EC760 and
; compared with 5), ESI = the action, EBX and EDI the update's saved registers on the stack. State 0Ch goes to the
; stock branch with the flags of the same compare. State 0 (approach) asks UhcBuildingGatherApproach, with every
; register kept; any other state leaves as stock. Both continuations only pop the saved registers (0x4EC773) or
; read the world (0x586D8B): nothing reads the flags or EAX before writing them, but EAX is kept anyway (the
; update's caller ignores it).
UhcBuildingGatherHook PROC
    TRACE_ONCE "buildingGather (0x4EC76B)"
    cmp al, 0Ch                     ; stolen 0x4EC76B
    jne notC
    jmp stateCNext                  ; stolen je 586D8Bh, taken
notC:
    test al, al
    je ask
    cmp al, 0FFh
    jne done
ask:
    pushad
    push esi                        ; the action
    call UhcBuildingGatherApproach
    popad
done:
    jmp exitNext                    ; stolen je 586D8Bh, not taken
UhcBuildingGatherHook ENDP

END
