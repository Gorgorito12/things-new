; pillageGold (src/features/pillage.cpp). Reached through a call retargeted in TakeDamage; it runs the
; stock function it replaces and leaves through an explicit jmp to it.
.686
.model flat, c
option casemap :none

include common.inc

UhcPillageHit PROTO STDCALL attacker:DWORD, attackerPlayer:DWORD, action:DWORD, victim:DWORD

.data
teamXpFn    dd 0049BD52h    ; the stock function of the call at 0x49B73C, thiscall with 3 stack arguments and more

.code

; Replaces the target of the call at 0x49B73C in TakeDamage FUN_0049B3D9. The call pushed four
; arguments, so on entry the frame of TakeDamage starts at [esp+14h]. ESI = the unit hit, EBX = the
; attacking player ([frame+20h]), [frame+28h] the attacking unit, [frame+A8h] the action, TakeDamage's
; third argument. No register survives the helper unless pushed, so all are saved.
UhcPillageHook PROC
    TRACE_ONCE "pillageGold hit (0x49B73C)"
    pushad
    mov eax, dword ptr [esp+20h+14h+28h]
    mov edx, dword ptr [esp+20h+14h+0A8h]
    invoke UhcPillageHit, eax, ebx, edx, esi
    popad
    jmp teamXpFn
UhcPillageHook ENDP

END
