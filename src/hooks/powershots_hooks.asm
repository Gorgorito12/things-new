; powerShots (features/powershots.cpp): the power check of an Attack tag of a power-launched attack. Entered through a
; jmp written over the stock code, left through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcPowerShotsAllow PROTO STDCALL :DWORD

EXTERNDEF g_uhcPowerShotsOn:DWORD   ; above 0 while some action carries <PowerShots> above 1

.data
fireShot        dd 0048F7F1h    ; mov ecx,[ebp+4]: the shot's path (the stock jne target)
noShot          dd 0048CF7Bh    ; pop edi ... ret 4: the event handler's exit without a shot (the stock jmp target)

.code

; Replaces test al,al / jne 48F7F1h (8 bytes) at 0x4B7766, reached only by the jmp at 0x48EA9D after the power
; manager's 0x6EDB7E answered whether the power of this attack ([ebp+6Ch], its record [+1Ch]) is ready. AL = that
; answer, EBP = the attack unit action, EBX = 0, ESI = the record; the event handler FUN_0048CED0's frame is intact.
; Ready: the shot, as stock. Not ready: UhcPowerShotsAllow decides (EAX, ECX and EDX saved); 1 = the shot, else the
; stock exit without one. Both continuations are the stock targets of the two replaced branches.
UhcPowerShotsHook PROC
    TRACE_ONCE "powerShots (0x4B7766)"
    test al, al
    jne fire
    cmp g_uhcPowerShotsOn, 0
    je stock
    push eax
    push ecx
    push edx
    push ebp
    call UhcPowerShotsAllow             ; EAX = 1: fire this tag
    test eax, eax
    pop edx
    pop ecx
    pop eax
    jne fire
stock:
    jmp noShot
fire:
    jmp fireShot
UhcPowerShotsHook ENDP

END
