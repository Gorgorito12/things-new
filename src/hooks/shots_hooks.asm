; The hooks of numberOfShots (features/shots.cpp): the launch hook of "projectiles", entered through a jmp written over
; the stock call and left through an explicit jmp to its verified continuation (docs/engine-symbols.md, "Rate of
; fire"), and the reload hook, at the head of the reload animation's start.
.686
.model flat, c
option casemap :none

include common.inc

UhcShotsProjectiles PROTO STDCALL :DWORD
UhcShotsSkipReload PROTO STDCALL :DWORD

EXTERNDEF g_uhcShotsProjectiles:DWORD      ; above 0 while some action has more than one projectile
EXTERNDEF g_uhcShotsBurst:DWORD            ; above 0 while some action has a burst (the reload hook asks only then)

.data
stockLaunch     dd 00499422h    ; thiscall(unitAction, unit, target, [[frame+2CCh]+28h], byte, [ua+6Ch]), ret 14h
launchNext      dd 0048F892h    ; mov eax,[ebp+6Ch]: after the launch, ranged and melee join
reloadBody      dd 004976D1h    ; mov eax,[esi+10h]: the body of the reload animation's start
animVariant     dd 00471D24h    ; thiscall(unit, anim ID): the unit's model's index of that animation, below 0 if none

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

; Replaces sub esp,8 / push esi / mov esi,ecx (6 bytes) at 0x4976CB, the head of FUN_004976CB, thiscall(unitAction):
; once the attack animation of a shot has played it starts the reload animation ([ua+84h], its model index [ua+88h]),
; paced to end with the wait before the next cycle, and returns AL 1 (0 without a reload animation). Called from
; setState(15h)'s case (0x497813) and from the update in state 19h (0x49A3E6); both go on as stock with either result.
; After a shot that does not end its burst (UhcShotsSkipReload) the function runs on the action's idle animation
; ([tactics action+60h], the aiming pose) instead: [ua+84h] and [ua+88h] are swapped for the call and put back, so the
; action's states, its timing and the cycle that follows are the stock ones, and the unit aims instead of reloading.
; Without an idle animation, or when the model lacks it, the reload plays as stock.
UhcShotsReloadHook PROC
    TRACE_ONCE "numberOfShots reload (0x4976CB)"
    cmp g_uhcShotsBurst, 0
    je stockReload
    push ecx
    push ecx
    call UhcShotsSkipReload             ; true: the burst goes on
    pop ecx
    test al, al
    je stockReload
    mov eax, [ecx+4]                    ; the tactics action
    test eax, eax
    je stockReload
    mov eax, [eax+60h]                  ; its idle animation
    test eax, eax
    jl stockReload
    push ebx
    push esi
    push edi
    mov esi, ecx
    mov ebx, eax
    mov ecx, [esi+10h]                  ; the unit
    test ecx, ecx
    je giveUp
    push ebx
    call animVariant
    test eax, eax
    jl giveUp
    mov edi, eax
    push dword ptr [esi+88h]
    push dword ptr [esi+84h]
    mov [esi+84h], ebx
    mov [esi+88h], edi
    mov ecx, esi
    call reloadStart                    ; the stock function on the idle animation; AL its result
    pop dword ptr [esi+84h]
    pop dword ptr [esi+88h]
    pop edi
    pop esi
    pop ebx
    ret
giveUp:
    mov ecx, esi
    pop edi
    pop esi
    pop ebx
stockReload:
    sub esp, 8
    push esi
    mov esi, ecx
    jmp reloadBody
UhcShotsReloadHook ENDP

; The stock function, called from the hook: its head re-executed, then its body; it returns to the caller.
reloadStart PROC
    sub esp, 8
    push esi
    mov esi, ecx
    jmp reloadBody
reloadStart ENDP

END
