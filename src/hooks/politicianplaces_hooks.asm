; politicianPlacesFix (src/features/politicianplaces.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcPoliticianNoPlace PROTO STDCALL dlg:DWORD, techStatus:DWORD

.data
techIdGetter dd 0058EA03h   ; int thiscall(techStatus): the tech ID [[status]]
placeNext    dd 0081A461h   ; cmp dword [esp+24h],0, after the two instructions this hook re-executes
listEnd      dd 0081A848h   ; mov eax,[ebx+26Ch], the builder's own exit after the fifth politician

.code

; Replaces 0x81A45A..0x81A460 (mov ecx,edi / call 58EA03h) in the European politician list builder FUN_0081A2B8,
; reached for each politician the builder accepted (next age, or a revolution, and 0x4C6968 said yes), before it
; fills the next place [ebx+26Ch]. EBX = the dialog, EDI = the tech status. EAX, ECX and EDX are dead here: the
; re-executed call returns EAX and the code after it writes ECX (0x81A466) and EDX (0x81A487) before reading them.
; When the place has no gadgets, the builder ends at 0x81A848 with the stack as the loop leaves it there (no local of
; this iteration exists yet; the per-entry local is built at 0x81A559).
UhcPoliticianPlacesHook PROC
    TRACE_ONCE "politicianPlacesFix (0x81A45A)"
    push edi                        ; tech status
    push ebx                        ; dialog
    call UhcPoliticianNoPlace
    test al, al
    jne full
    mov ecx, edi
    call techIdGetter
    jmp placeNext
full:
    jmp listEnd
UhcPoliticianPlacesHook ENDP

END
