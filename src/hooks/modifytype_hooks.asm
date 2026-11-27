; The shared hook for new ModifyType names (src/modifytypes.h). Entered through a jmp written over
; the stock code; it leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcModifyTypeByName PROTO STDCALL :DWORD, :DWORD, :DWORD

.data
nameTailNext    dd 005FE6DDh    ; pop esi / add eax,0Eh / ret: FUN_005F5645 returns EAX + 0Eh

.code

; Replaces 0x5FE6D7..0x5FE6DC (neg eax / sbb eax,eax / and al,0F1h) in FUN_005F5645, the
; ModifyType name -> stat parser, after its last compare. EAX = that compare's result for
; "AutoGatherRate" (0: the same name), ESI = the name (BString*), [esp] = the ESI the function
; saved. Stock turns EAX into 0 (a match) or -0Fh and the tail adds 0Eh: stat 0Eh, or -1 for an
; unknown name. The hook keeps a match; for any other name the helper returns the stat - 0Eh, or
; -0Fh. ECX, EDX and the flags are dead at the tail, which sets the flags, and its two callers read
; only EAX. [esp+4] = the caller; for the action parser, its proto argument is at [esp+0D0h] (0C4h in its loop, with
; the return address and the argument of this call on top, and the saved ESI).
UhcModifyTypeHook PROC
    TRACE_ONCE "ModifyType names (0x5FE6D7)"
    test eax, eax
    je done                         ; "AutoGatherRate": EAX = 0, the tail returns 0Eh
    push dword ptr [esp+0D0h]
    push dword ptr [esp+8]
    push esi
    call UhcModifyTypeByName
done:
    jmp nameTailNext
UhcModifyTypeHook ENDP

END
