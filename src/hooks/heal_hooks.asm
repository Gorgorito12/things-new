; Hooks for healNonIdle. Entered through a jmp written over the stock code; leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Healing").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcHealNonIdleType:SDWORD      ; unittype ID, set on each database load; -1 before
EXTERNDEF g_uhcHealAllowMoving:SDWORD      ; 1: a marked healer heals a moving target
EXTERNDEF g_uhcHealAllowFighting:SDWORD    ; 1: a marked healer heals a fighting target
EXTERNDEF g_uhcHealCheckBusy:SDWORD        ; 1: a state is excluded or busyRate is not 100
EXTERNDEF g_uhcHealBusyAction:DWORD        ; the heal action whose target is busy this tick, or 0
EXTERNDEF g_uhcHealBusyFactor:REAL4        ; busyRate / 100

.data
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): proto IDs and abstract types
healPath        dd 009E0C9Fh    ; apply this tick's heal
busyChecks      dd 009E0C80h    ; stock: push -1 / call 4802D4h (target moving?) / call 9CA5ACh
tickEnd         dd 009E0D3Fh    ; the action's vtbl+34h(10): the heal ends
targetIsIdle    dd 0044F1A7h    ; bool thiscall(actionManager): no current action, or an idle one
targetMoving    dd 004802D4h    ; bool thiscall(actionManager, -1), ret 4: the current action moves
targetFighting  dd 009CA5ACh    ; bool thiscall(actionManager): the unit fights
autoSearchNext  dd 009CD9CCh    ; test al,al / je 9CDA3Fh (skip this candidate)
factorsNext     dd 009E0CCFh    ; call 487C45h: the heal rate of the target

.code

; Replaces 0x9E0C79..0x9E0C7D (mov ecx,[edi+58h] / test ecx,ecx) in FUN_009E0B53, where each heal
; tick stops if the target has a current action that is a move or a fight. EDI = target unit,
; ESI = heal action (healer unit at [esi+10h]). A healer whose proto is of the configured
; unittype skips the busy test (with "moving" or "fighting" alone, only that state's test; with
; busyRate, a busy target is noted for the factors hook); any other healer runs the stock code
; unchanged.
UhcHealNonIdleHook PROC
    TRACE_ONCE "healNonIdle (0x9E0C79)"
    mov g_uhcHealBusyAction, 0
    cmp g_uhcHealNonIdleType, 0
    jl stock
    mov ecx, dword ptr [esi+10h]    ; healer unit
    test ecx, ecx
    je stock
    mov ecx, dword ptr [ecx+5Ch]    ; healer proto
    test ecx, ecx
    je stock
    push g_uhcHealNonIdleType
    call protoIsType
    test al, al
    jne marked
stock:
    mov ecx, dword ptr [edi+58h]    ; stolen 0x9E0C79
    test ecx, ecx                   ; stolen 0x9E0C7C
    je heal                         ; stock 0x9E0C7E: no current action -> heal
    jmp busyChecks
marked:
    cmp g_uhcHealCheckBusy, 0
    je heal                         ; both states, full rate: no test at all
    mov ecx, dword ptr [edi+58h]
    test ecx, ecx
    je heal                         ; no current action: not busy
    push -1
    call targetMoving               ; the stock tick's first test
    test al, al
    je notMoving
    cmp g_uhcHealAllowMoving, 0
    je stop
    mov g_uhcHealBusyAction, esi
notMoving:
    mov ecx, dword ptr [edi+58h]
    call targetFighting             ; the stock tick's second test
    test al, al
    je heal
    cmp g_uhcHealAllowFighting, 0
    je stop
    mov g_uhcHealBusyAction, esi
heal:
    jmp healPath
stop:
    jmp tickEnd
UhcHealNonIdleHook ENDP

; Replaces mov [esp+0Ch],edx / mov [esp+14h],eax (8 bytes at 0x9E0CC7) in the heal path of
; FUN_009E0B53, which store [world+104h] and [world+318h], the two factors of this tick's heal
; (0x9E0CD4 and 0x9E0CDA multiply the rate 0x487C45 by them; the product is the HP added at
; 0x9E0CE9 and the action's total at 0x9E0CF2). For the action the busy hook noted, the second
; factor is multiplied by busyRate / 100. ESI = the action. The flags and ECX are written again
; at 0x9E0CCF; the FPU stack is empty here and after the hook.
UhcHealBusyRateHook PROC
    TRACE_ONCE "healNonIdle busyRate (0x9E0CC7)"
    mov dword ptr [esp+0Ch], edx    ; stolen 0x9E0CC7
    mov dword ptr [esp+14h], eax    ; stolen 0x9E0CCB
    cmp esi, g_uhcHealBusyAction
    jne done
    fld dword ptr [esp+14h]
    fmul g_uhcHealBusyFactor
    fstp dword ptr [esp+14h]
done:
    mov g_uhcHealBusyAction, 0
    jmp factorsNext
UhcHealBusyRateHook ENDP

; Replaces the call 44F1A7h at 0x9CD9C7 in FUN_009CD865, where a healer's automatic search skips
; every candidate that is not idle. ECX = the candidate's action manager ([esi+58h]),
; ESI = candidate, EBP = the search's owner, with the healer at [ebp+4]. For a healer of the
; configured unittype the candidate counts as idle unless it is in a state the cfg excludes
; (moving without "moving", fighting without "fighting"); any other healer runs the stock test.
UhcHealAutoSearchHook PROC
    TRACE_ONCE "healNonIdle auto-search (0x9CD9C7)"
    cmp g_uhcHealNonIdleType, 0
    jl idleTest
    push ecx
    mov ecx, dword ptr [ebp+4]      ; healer unit
    test ecx, ecx
    je restore
    mov ecx, dword ptr [ecx+5Ch]    ; healer proto
    test ecx, ecx
    je restore
    push g_uhcHealNonIdleType
    call protoIsType
    test al, al
    je restore
    pop ecx                         ; the candidate's action manager
    cmp g_uhcHealAllowMoving, 0
    jne movingOk
    push ecx
    push -1
    call targetMoving
    pop ecx
    test al, al
    jne reject
movingOk:
    cmp g_uhcHealAllowFighting, 0
    jne accept
    call targetFighting
    test al, al
    jne reject
accept:
    mov al, 1
    jmp autoSearchNext
reject:
    xor al, al
    jmp autoSearchNext
restore:
    pop ecx
idleTest:
    call targetIsIdle               ; stolen 0x9CD9C7
    jmp autoSearchNext
UhcHealAutoSearchHook ENDP

END
