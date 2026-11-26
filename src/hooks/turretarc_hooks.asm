; turretArc (features/turretarc.cpp): the unit's turn toward what it attacks, and the start of its shots. Entered through
; jmps written over the stock code, left through explicit jmps to verified continuations.
.686
.model flat, c
option casemap :none

include common.inc

UhcTurretFace PROTO STDCALL :DWORD, :DWORD
UhcTurretLaunch PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD
UhcTurretHold PROTO STDCALL :DWORD

EXTERNDEF g_uhcTurretOn:DWORD    ; above 0 while the key has a unit to serve
EXTERNDEF g_uhcTurnCount:DWORD   ; turns beyond the arc under way
EXTERNDEF g_uhcTurretPoint:DWORD ; the point the stock turn gets instead when UhcTurretFace returns 2

.data
faceContinue    dd 0048AAA5h    ; mov eax,[esi]: the stock body after the three instructions re-executed here
launchContinue  dd 004995DEh    ; fsub dword ptr [esp+20h]: the shot's direction, after the two re-executed here
stateContinue   dd 0048A661h    ; ja 48A728h: the state switch, on the flags of the cmp re-executed here
stateWait       dd 0048BFC7h    ; the stock wait of a slow turner: vtable+34h(0), then the update's epilogue

.code

; Replaces sub esp,18h / push esi / mov esi,ecx (6 bytes) at 0x48AA9F, the head of FUN_0048AA9F, bool thiscall(unit,
; Vector* point), ret 4: the unit turns to face the point (0x48AB4A stores the wanted forward at [[unit+4Ch]+18h]) and
; returns 1. The attack update calls it on every update (through 0x48AA5D for a unit target). UhcTurretFace returns 1
; when the unit's attack has the key's turret and the point is inside its arc: then the body keeps its facing and the
; function returns 1 as the stock one does; 2 when the arc is about a rest yaw that is not ahead and the point is beyond
; it: the stock function runs with its argument replaced by g_uhcTurretPoint (the point turned by minus the rest yaw,
; so the unit turns until the target sits at the rest yaw; the argument slot is the caller's, dead after the call,
; ret 4); otherwise the stock function runs.
UhcTurretFaceHook PROC
    TRACE_ONCE "turretArc facing (0x48AA9F)"
    cmp g_uhcTurretOn, 0
    je stock
    push ecx
    push edx
    push dword ptr [esp+0Ch]            ; the point (the stock argument, above the return address and the two pushes)
    push ecx                            ; the unit
    call UhcTurretFace
    pop edx
    pop ecx
    test eax, eax
    je stock
    cmp eax, 2
    je redirect
    mov al, 1
    ret 4
redirect:
    mov dword ptr [esp+4], OFFSET g_uhcTurretPoint
stock:
    sub esp, 18h
    push esi
    mov esi, ecx
    jmp faceContinue
UhcTurretFaceHook ENDP

; Replaces fld dword ptr [esp+28h] / push 40A00000h (9 bytes) at 0x4995D5 in FUN_00499422, the projectile launch
; (thiscall(attack unit action, unit, target, ...)), where every way of placing the shot's start meets: EBX = the attack
; unit action, EDI = the unit, the start (world) at [esp+1Ch], the aim point at [esp+28h]. UhcTurretLaunch turns the
; start about the unit's turret pivot by the gun's yaw; then the two instructions run as they were.
UhcTurretLaunchHook PROC
    TRACE_ONCE "turretArc launch (0x4995D5)"
    cmp g_uhcTurretOn, 0
    je stock
    pushad
    lea eax, [esp+20h+28h]              ; the aim point (pushad moved esp by 20h)
    push eax
    lea eax, [esp+24h+1Ch]              ; the start (and the push above)
    push eax
    push edi
    push ebx
    call UhcTurretLaunch
    popad
stock:
    fld dword ptr [esp+28h]
    push 40A00000h
    jmp launchContinue
UhcTurretLaunchHook ENDP

; Replaces movzx eax,byte ptr [esi+61h] / cmp eax,16h (7 bytes) at 0x48A65A, the state switch of the attack update
; FUN_0048A330 (ESI = the attack unit action, [esi+61h] its state, [esi+10h] its unit). In state 1 (firing), while the
; unit's body turns beyond its turret's arc on screen, UhcTurretHold returns 1 and the update leaves through the stock
; wait 0x48BFC7, which a slow turner takes in the same frame (0x4B3382): the action goes back to state 0 and the attack
; starts again once the turn has settled. Otherwise the two instructions run as they were (the ja at 0x48A661 reads
; the cmp's flags). ECX and EDX are kept for the switch's cases.
UhcTurretStateHook PROC
    TRACE_ONCE "turretArc attack state (0x48A65A)"
    cmp g_uhcTurnCount, 0
    je stock
    cmp byte ptr [esi+61h], 1
    jne stock
    push ecx
    push edx
    push esi
    call UhcTurretHold
    pop edx
    pop ecx
    test eax, eax
    je stock
    jmp stateWait
stock:
    movzx eax, byte ptr [esi+61h]
    cmp eax, 16h
    jmp stateContinue
UhcTurretStateHook ENDP

END
