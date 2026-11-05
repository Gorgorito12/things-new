; veterancyBonus (src/features/veterancy.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcVeterancyKill PROTO STDCALL attacker:DWORD, victim:DWORD

.data
killPathNext    dd 004D4F3Dh    ; call 0x4D520C

.code

; Replaces 0x4D4F37 (mov ecx,[0xC66234]), the head of TakeDamage's cold kill path: the only way here
; is the je at 0x49B746 on [esp+1Fh] = 1, set at 0x4D484B for the blow that takes the unit from alive
; to no hit points. ESI = the unit killed, [esp+28h] = the attacker unit, null when it is gone. The code
; that follows reads neither EAX nor EDX before writing them.
UhcVeterancyHook PROC
    TRACE_ONCE "veterancyBonus kill (0x4D4F37)"
    mov eax, dword ptr [esp+28h]
    invoke UhcVeterancyKill, eax, esi
    mov ecx, dword ptr ds:[00C66234h]
    jmp killPathNext
UhcVeterancyHook ENDP

END
