; directionalAttack (src/features/directional.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcDirLaunch PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD

.data
launchNext dd 004998AEh     ; mov ecx,[ebx+4], after the two instructions this hook re-executes

.code

; Replaces mov ecx,[esp+10h] / mov [esi+14h],ecx (7 bytes) at 0x4998A7 in the projectile launch FUN_004995C7,
; where every launch path meets once the mode [esi+20h] and the impact point [esp+28h] are final: the
; precalculated roll (0x49989C), the InstantBallistics branch (0x4998A0), the TargetGround store (0x4C4DF3)
; and the skipped block (0x4997B0, 0x4997B8). Nothing branches inside the 7 bytes. ESI = the projectile,
; [esp+18h] the unit action, [esp+0E8h] the shooting unit, [esp+0ECh] the target unit or 0, [esp+10h] the
; damage multiplier the stolen code copies to [projectile+14h], [esp+44h] the value the launch keeps at
; [projectile+0C0h]. Every launch call after it (0x4A5725, 0x7A8CDF, the instant 0x4A95A5) reads the point at
; [esp+28h], so a point and a mode rewritten here are where the shot flies and how it lands. Registers are
; saved around the call; the continuation sets the flags before it reads them (test eax,eax at 0x4998B4).
UhcDirLaunchHook PROC
    TRACE_ONCE "directionalAttack launch (0x4998A7)"
    pushad
    lea eax, dword ptr [esp+20h+28h]    ; the impact point
    push eax
    push dword ptr [esp+24h+10h]        ; the damage multiplier (float)
    push dword ptr [esp+28h+44h]        ; [projectile+0C0h] to be
    push dword ptr [esp+2Ch+0ECh]       ; the target unit (or 0)
    push dword ptr [esp+30h+0E8h]       ; the shooting unit
    push dword ptr [esp+34h+18h]        ; the unit action
    push esi                            ; the projectile
    call UhcDirLaunch
    popad
    mov ecx, dword ptr [esp+10h]        ; stolen
    mov dword ptr [esi+14h], ecx        ; stolen
    jmp launchNext
UhcDirLaunchHook ENDP

END
