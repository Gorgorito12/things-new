; Hook for healNonIdle. Entered through a jmp written over the stock code; leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Healing").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcHealNonIdleType:SDWORD      ; unittype ID, set on each database load; -1 before

.data
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): proto IDs and abstract types
healPath        dd 009E0C9Fh    ; apply this tick's heal
busyChecks      dd 009E0C80h    ; stock: push -1 / call 4802D4h (target moving?) / call 9CA5ACh
targetIsIdle    dd 0044F1A7h    ; bool thiscall(actionManager): no current action, or an idle one
autoSearchNext  dd 009CD9CCh    ; test al,al / je 9CDA3Fh (skip this candidate)

.code

; Replaces 0x9E0C79..0x9E0C7D (mov ecx,[edi+58h] / test ecx,ecx) in FUN_009E0B53, where each heal
; tick stops if the target has a current action that is a move or a fight. EDI = target unit,
; ESI = heal action (healer unit at [esi+10h]). A healer whose proto is of the configured
; unittype skips the busy test; any other healer runs the stock code unchanged.
UhcHealNonIdleHook PROC
    TRACE_ONCE "healNonIdle (0x9E0C79)"
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
    jne heal
stock:
    mov ecx, dword ptr [edi+58h]    ; stolen 0x9E0C79
    test ecx, ecx                   ; stolen 0x9E0C7C
    je heal                         ; stock 0x9E0C7E: no current action -> heal
    jmp busyChecks
heal:
    jmp healPath
UhcHealNonIdleHook ENDP

; Replaces the call 44F1A7h at 0x9CD9C7 in FUN_009CD865, where a healer's automatic search skips
; every candidate that is not idle. ECX = the candidate's action manager ([esi+58h]),
; ESI = candidate, EBP = the search's owner, with the healer at [ebp+4]. For a healer of the
; configured unittype the candidate counts as idle; any other healer runs the stock test.
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
    pop ecx
    mov al, 1
    jmp autoSearchNext
restore:
    pop ecx
idleTest:
    call targetIsIdle               ; stolen 0x9CD9C7
    jmp autoSearchNext
UhcHealAutoSearchHook ENDP

END
