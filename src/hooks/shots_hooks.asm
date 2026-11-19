; The launch hook of numberOfShots "projectiles" (features/shots.cpp), entered through a jmp written over the
; stock call and left through an explicit jmp to its verified continuation (docs/engine-symbols.md, "Rate of fire").
.686
.model flat, c
option casemap :none

include common.inc

UhcShotsProjectiles PROTO STDCALL :DWORD

EXTERNDEF g_uhcShotsProjectiles:DWORD      ; above 0 while some action has more than one projectile

.data
stockLaunch     dd 00499422h    ; thiscall(unitAction, unit, target, [[frame+2CCh]+28h], byte, [ua+6Ch]), ret 14h
launchNext      dd 0048F892h    ; mov eax,[ebp+6Ch]: after the launch, ranged and melee join

.code

; Replaces call 499422h (5 bytes) at 0x48F88D, the attack step's launch of a shot: ECX = EBP = the unit action, the
; five arguments pushed ([esp] the unit [ebp+10h], [esp+4] the target EDI, [esp+8] [[esp+2CCh]+28h], [esp+0Ch] the
; byte of tactics flag 18h, [esp+10h] the override object [ebp+6Ch], pushed at 0x48F83B). For an action with N
; projectiles the launch runs N - 1 extra times with copies of the five arguments, then once with the stock ones.
; The launch keeps EBX, ESI, EDI and EBP (callee-saved); the code at 0x48F892 reloads EAX from [ebp+6Ch] and
; compares it with EBX (0), and writes ECX and EDX before it reads them.
UhcShotsLaunchHook PROC
    TRACE_ONCE "numberOfShots projectiles (0x48F88D)"
    cmp g_uhcShotsProjectiles, 0
    je single
    push ebp
    call UhcShotsProjectiles            ; EAX = projectiles for this shot (at least 1)
    cmp eax, 1
    jle single
    push esi
    mov esi, eax
extra:
    push dword ptr [esp+14h]            ; the override object ([esp+10h] before push esi)
    push dword ptr [esp+14h]            ; the byte
    push dword ptr [esp+14h]            ; the third
    push dword ptr [esp+14h]            ; the target
    push dword ptr [esp+14h]            ; the unit
    mov ecx, ebp
    call stockLaunch                    ; ret 14h
    dec esi
    cmp esi, 1
    jg extra
    pop esi
single:
    mov ecx, ebp                        ; the unit action, as at 0x48F88B
    call stockLaunch                    ; the stock call, on the stock arguments
    jmp launchNext
UhcShotsLaunchHook ENDP

END
