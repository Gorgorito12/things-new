; Hooks for spreadAnyAccuracy (features/spread.cpp). Each is entered through a jmp written over the
; stock code and leaves through an explicit jmp to a verified continuation (docs/engine-symbols.md,
; "Projectile accuracy and spread"). The tags are read through the shared action tag hook
; (actiontag_hooks.asm).
.686
.model flat, c
option casemap :none

include common.inc

UhcSpreadForceMiss PROTO STDCALL :DWORD, :DWORD
UhcSpreadSelect PROTO STDCALL :DWORD, :DWORD
UhcSpreadDone PROTO STDCALL            ; returns the hit result to store: 2 or 3

EXTERNDEF g_uhcSpreadFactor:DWORD       ; float: SpreadFactor of the shot being offset (stock 0.25)
EXTERNDEF g_uhcSpreadMax:DWORD          ; float: MaxSpread of the shot being offset (stock 5.0)
EXTERNDEF g_uhcSpreadRadius:DWORD       ; float: the radius the offset used, for the log

.data
afterRoll           dd 00499899h    ; mov [esi+20h],ebx: the projectile's hit result
missOffsetFn        dd 004CEF8Ch    ; FUN_004CEF8C, bool thiscall(projectile, Vector* point), ret 4
radiusCheck         dd 004CF026h    ; fld [esp+0Ch] / fcomp [1e-6]: the stock "r > 0" test

.code

; Replaces cmp ebx,2 / je 4CEF7Bh (9 bytes) at 0x499890 in the projectile launch, after the
; precalculated roll (EBX = 1 hit, 2 miss) and the target leading 0x4A5B02. ESI = the projectile,
; EDI = the shooting (tactics) action, [esp+18h] = the unit action, [esp+0E8h] = the shooting unit,
; [esp+28h] = the impact point. A miss goes on to the miss stub as in stock; any other result
; (a hit, or PerfectAccuracy's 1) of a unit whose proto has the marker type goes there too with
; EBX = 2, and the miss hook then makes it a ground shot. EAX, ECX, EDX and the flags are free on
; both continuations: 0x499899 stores EBX and overwrites them before reading them
; (mov [esi+20h],ebx / mov ebx,[esp+18h] / mov edi,[esp+0ECh] / mov ecx,[esp+10h] / ... /
; test eax,eax), and the miss stub calls FUN_004CEF8C, which clobbers them.
UhcSpreadHitHook PROC
    TRACE_ONCE "spreadAnyAccuracy hit roll (0x499890)"
    cmp ebx, 2                          ; stolen 0x499890
    je UhcSpreadMissHook                ; stolen 0x499893: je 4CEF7Bh (the stub this file replaces)
    pushad
    push edi                            ; the shooting action
    push dword ptr [esp+24h+0E8h]       ; the shooting unit
    call UhcSpreadForceMiss             ; AL = 1: scatter this shot
    test al, al
    popad                               ; keeps the flags
    jne forced
    jmp afterRoll
forced:
    mov ebx, 2                          ; a miss: [projectile+20h] = 2 at 0x499899
    jmp UhcSpreadMissHook
UhcSpreadHitHook ENDP

; Replaces lea eax,[esp+28h] / push eax / mov ecx,esi (7 bytes) at 0x4CEF7B, the stub every miss
; reaches (from 0x499893, now this file's hit hook, and from the failed lead at 0x6A4BCA, both with
; EBX = 2). The stub's stock code is call 4CEF8Ch / jmp 499899h; the hook makes that call itself,
; with the shooting action's SpreadFactor and MaxSpread in the two globals the radius hook reads,
; then puts the stock values back. For a marked shooter EBX becomes 3, the TargetGround mode, so the
; projectile deals its attack where it lands (a miss, 2, deals none). Same frame as the hit hook.
; FUN_004CEF8C keeps EBX, ESI, EDI and EBP (it saves them), and the stock call already clobbered
; EAX, ECX and EDX.
UhcSpreadMissHook PROC
    TRACE_ONCE "spreadAnyAccuracy miss offset (0x4CEF7B)"
    pushad
    push dword ptr [esp+20h+0E8h]       ; the shooting unit
    push dword ptr [esp+24h+18h]        ; the unit action
    call UhcSpreadSelect
    popad
    lea eax, dword ptr [esp+28h]        ; stolen 0x4CEF7B: the impact point
    push eax
    mov ecx, esi                        ; the projectile
    call missOffsetFn                   ; stock 0x4CEF82
    pushad
    call UhcSpreadDone                  ; the log; the stock values back; EAX = the hit result
    mov dword ptr [esp+10h], eax        ; popad's EBX: 2, or 3 (a ground shot) for a marked unit
    popad
    jmp afterRoll                       ; stock 0x4CEF87: jmp 499899h
UhcSpreadMissHook ENDP

; Replaces fmul [0BA0AECh] (0.25) / fst [esp+0Ch] / fcomp [0BA0AF8h] (5.0) / fnstsw ax / test ah,41h /
; je 4E2CE3h (27 bytes) at 0x4CF00B in FUN_004CEF8C, with ST0 = d, the 2D distance from the
; projectile to the impact point (or 1.0 without a projectile unit, from 0x4E2CFD). It computes
; r = min(d * g_uhcSpreadFactor, g_uhcSpreadMax) into [esp+0Ch] as the stock code does with 0.25 and
; 5.0, and continues at the stock "r > 1e-6" test, so the two random draws uniform(-r, r) stay the
; stock code's. The stock clamp at 0x4E2CE3 skipped that test, which only matters for a MaxSpread
; of 0: then nothing is drawn, as for a stock r of 0. The x87 stack is empty on leaving, as after the
; stock fcomp; EAX is free (the test overwrites AX with fnstsw).
UhcSpreadRadiusHook PROC
    fmul dword ptr [g_uhcSpreadFactor]
    fst dword ptr [esp+0Ch]
    fcomp dword ptr [g_uhcSpreadMax]
    fnstsw ax
    TRACE_ONCE "spreadAnyAccuracy miss radius (0x4CF00B)" ; after the fcomp: the x87 stack is empty
    test ah, 41h
    jne notAbove                        ; r <= MaxSpread (or unordered)
    mov eax, g_uhcSpreadMax
    mov dword ptr [esp+0Ch], eax
notAbove:
    mov eax, dword ptr [esp+0Ch]
    mov g_uhcSpreadRadius, eax
    jmp radiusCheck
UhcSpreadRadiusHook ENDP

END
