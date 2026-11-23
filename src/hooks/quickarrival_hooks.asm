; quickArrivalCards (src/features/quickarrival.cpp): the card rollover builder's join before the advanced info. It
; leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcQuickArrivalLine PROTO STDCALL list:DWORD, tech:DWORD, listMode:DWORD

.data
advancedNext    dd 0071090Fh    ; mov edx,[ecx], in the card rollover builder

.code

; Replaces mov ecx,[0D6F6F0h] at 0x710909 in FUN_007103CE (cdecl(list, hc, tech, ...), frame: sub esp,30h and four
; pushes), reached from 0x7108C3, 0x7108DB and the fall-through at 0x710904, all with no push outstanding: the
; list is [esp+44h], the tech ID [esp+4Ch], the list-mode byte [esp+58h] (EBX holds it too). ECX is reloaded here,
; EDX at 0x71090F and EAX by the call at 0x710917; EBX, ESI, EDI and EBP are kept by the call.
UhcQuickArrivalHook PROC
    TRACE_ONCE "quickArrivalCards (0x710909)"
    push dword ptr [esp+58h]        ; list mode
    push dword ptr [esp+50h]        ; tech, [esp+4Ch] + one push
    push dword ptr [esp+4Ch]        ; list, [esp+44h] + two pushes
    call UhcQuickArrivalLine
    mov ecx, dword ptr ds:[0D6F6F0h]
    jmp advancedNext
UhcQuickArrivalHook ENDP

END
