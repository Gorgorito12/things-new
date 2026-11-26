; quickArrivalCards (src/features/quickarrival.cpp): the joins before the advanced info of the two card rollover
; builders. Each hook leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcQuickArrivalLine PROTO STDCALL list:DWORD, tech:DWORD, listMode:DWORD

.data
advancedNext    dd 0071090Fh    ; mov edx,[ecx], in the card rollover builder
treeAdvancedNext dd 00710F2Ah   ; mov edx,[ecx], in the card tree's rollover builder

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

; Replaces mov ecx,[0D6F6F0h] at 0x710F24 in FUN_00710991 (cdecl(out, hc, tech, a4, a5, list), the rollover of the
; home city's card tree, "View All Cards"; frame: sub esp,28h and four pushes), reached from 0x710EDE, 0x710EF6 and
; the fall-through at 0x710F1F, all with no push outstanding: out is [esp+3Ch], the tech ID [esp+44h], the list-mode
; byte [esp+50h] (BL holds it too). ECX is reloaded here, EDX at 0x710F2A and EAX by the call at 0x710F32; EBX, ESI
; (the card entry, an argument of the advanced info at 0x710F3C), EDI and EBP (out) are kept by the call.
UhcQuickArrivalTreeHook PROC
    TRACE_ONCE "quickArrivalCards card tree (0x710F24)"
    push dword ptr [esp+50h]        ; list mode
    push dword ptr [esp+48h]        ; tech, [esp+44h] + one push
    push dword ptr [esp+44h]        ; out, [esp+3Ch] + two pushes
    call UhcQuickArrivalLine
    mov ecx, dword ptr ds:[0D6F6F0h]
    jmp treeAdvancedNext
UhcQuickArrivalTreeHook ENDP

END
