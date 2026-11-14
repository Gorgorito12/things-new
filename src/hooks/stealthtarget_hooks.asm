; stealthTargeting (src/features/stealthtarget.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to a verified continuation, or returns -1 as the stock failure path does.
.686
.model flat, c
option casemap :none

include common.inc

UhcStealthHidden PROTO STDCALL attacker:DWORD, target:DWORD

.data
attackActionNext dd 00489ED3h   ; push esi, after the four instructions this hook re-executes
footprintNext    dd 00493048h   ; fnstcw [esp+68h], after the two instructions this hook re-executes

.code

; Replaces 0x493040..0x493047 (fld dword [esp+4Ch] / movzx edx, byte [esi+0Dh]), the start of the footprint
; branch of the per-player visibility 0x486B1A, taken for a proto whose obstruction radius is over 1.0 (a ship,
; a large unit). That branch never reads the stealth argument [esp+68h] (the next instruction overwrites its
; slot), so enemies saw a large stealthed unit. Here a set stealth byte sets the local [esp+38h], the "only
; allies see it" byte that the branch's player loop already honours (0x493201 -> 0x4E0B1F: a non-allied
; player is skipped; an ally goes on to its LOS test), the same outcome as the stealth test of the small-unit
; branch (0x486CD0 -> 0x4E0B12). Flags and registers are as the re-executed instructions leave them.
UhcStealthFootprintHook PROC
    TRACE_ONCE "stealthTargeting footprint (0x493040)"
    cmp byte ptr [esp+68h], 0
    je go
    mov byte ptr [esp+38h], 1
go:
    fld dword ptr [esp+4Ch]
    movzx edx, byte ptr [esi+0Dh]
    jmp footprintNext
UhcStealthFootprintHook ENDP

; Replaces 0x489ECC..0x489ED2 (push ecx / push ebx / push ebp / mov ebp,[esp+10h]), the head of
; int __thiscall(tactic, attacker, target, ...), ret 1Ch: the attack action the attacker would use on the
; target, -1 for none. On entry [esp+4] = attacker, [esp+8] = target, ECX = this. A target whose unit state
; bit 42h (stealth, set by the Stealth action's update 0x9E8AE5) is clear goes on at once. For a stealthed
; one, UhcStealthHidden decides; when it is hidden from the attacker's player, the function returns -1 as
; its own failure path 0x4974C1 does (or eax,-1 / ret 1Ch), and EBX, ESI, EDI, EBP are untouched.
UhcStealthTargetHook PROC
    TRACE_ONCE "stealthTargeting (0x489ECC)"
    mov eax, [esp+8]
    test eax, eax
    je stock
    cmp dword ptr [eax+8], 42h      ; the state bitset's bit count
    jbe stock
    mov edx, [eax+4]
    test byte ptr [edx+8], 4        ; bit 42h
    je stock
    push ecx
    push eax                        ; target
    push dword ptr [esp+0Ch]        ; attacker ([esp+4] on entry)
    call UhcStealthHidden
    pop ecx
    test al, al
    jne refuse
stock:
    push ecx
    push ebx
    push ebp
    mov ebp, [esp+10h]
    jmp attackActionNext
refuse:
    or eax, -1
    ret 1Ch
UhcStealthTargetHook ENDP

END
