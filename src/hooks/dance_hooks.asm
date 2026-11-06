; Hooks for danceBonusCivs. Each is entered through a jmp written over the first native civ
; compare of one dance reader, cmp eax,[0C6FB50h] (XPIroquois), and leaves through an explicit jmp
; to a verified continuation (docs/engine-symbols.md, "Dances"). Both paths into that compare
; arrive with EAX = the player's first civ ID, or -1 when [player+24h] (the civ count) is 0.
;
; A listed civ jumps to the branch the stock code takes for a native civ (the fire pit lookup).
; Any other civ re-executes the stolen compare and continues at the stock je, which reads its
; flags; the other three native compares then run unchanged. EAX, ECX, EDX and ESP are the same
; on both exits; no x87 value is live at these sites.
.686
.model flat, c
option casemap :none

include common.inc

UhcDanceCivAllowed PROTO STDCALL kind:DWORD, player:DWORD, civ:DWORD
UhcFirePit PROTO STDCALL player:DWORD
UhcDancerWeight PROTO STDCALL unitProto:DWORD

.data
trainNext       dd 008D47B1h    ; je 8D47CFh, then the XPSioux, XPAztec and XPSPC compares
trainDance      dd 008D47CFh    ; call 4819EFh (the player's first fire pit) / test eax,eax
xpNext          dd 004E0E05h    ; je 4E0E29h, then the other three compares
xpDance         dd 004E0E29h    ; call 4819EFh / jmp 679D72h
gatherNext      dd 004ECD59h    ; je 4ECD7Dh, then the other three compares
gatherDance     dd 004ECD7Dh    ; call 4819EFh / jmp 679DECh
regenNext       dd 00490491h    ; je 679E66h (near), then the other three compares
firePitNext     dd 004819F4h    ; mov edx,[eax+140h], the rest of getFirePit
dancerType      dd 009C160Bh    ; push 16h / mov ecx,eax / call 44CAC4h: EAX = the proto
dancerOther     dd 009C161Fh    ; add [esp+10h],2: a dancer that is not a villager
dancerNext      dd 009C1629h    ; add esi,1, the next worker
regenDance      dd 00679E66h    ; cmp dword ptr [edi+80h],0 / je 4904BBh, then the fire pit

.code

; Replaces 0x4819EF, the head of getFirePit, thiscall(player), no arguments: mov eax,[0C66234h]. EDX
; and ECX are free on return, as they are after the stock body.
UhcFirePitHook PROC
    TRACE_ONCE "danceBonusCivs fire pit (0x4819EF)"
    push ecx
    push ecx
    call UhcFirePit
    pop ecx
    cmp eax, -1
    je stock
    ret
stock:
    mov eax, dword ptr ds:[0C66234h]    ; replaced
    jmp firePitNext
UhcFirePitHook ENDP

; Replaces 0x9C1604 in the dancer count 0x9C1577, with EAX = the worker unit: mov eax,[eax+5Ch] /
; test eax,eax / je 9C161Fh. The stale workers it removes are handled before this. [esp+10h] is the
; count; EAX, ECX and EDX are free at every exit but the type test, which wants the proto in EAX.
UhcDancerHook PROC
    TRACE_ONCE "danceBonusCivs dancer (0x9C1604)"
    mov eax, dword ptr [eax+5Ch]        ; replaced
    test eax, eax                       ; replaced
    je other
    push eax
    push eax
    call UhcDancerWeight
    mov ecx, eax
    pop eax
    test ecx, ecx
    jl stock
    add dword ptr [esp+10h], ecx
    jmp dancerNext
stock:
    jmp dancerType
other:
    jmp dancerOther
UhcDancerHook ENDP

; Replaces 0x8D47AB in FUN_008D4790 (train rate, thiscall; ret 4 with the trained proto ID).
; ECX = player; the fire pit lookup at the continuation takes it as this.
UhcDanceTrainHook PROC
    TRACE_ONCE "danceBonusCivs Training (0x8D47AB)"
    push eax
    push ecx
    push edx
    push eax                        ; civ ID
    push ecx                        ; player
    push 1                          ; DanceBonusType Training
    call UhcDanceCivAllowed
    test al, al
    pop edx
    pop ecx
    pop eax
    jne dance
    cmp eax, dword ptr ds:[0C6FB50h]    ; stolen 0x8D47AB
    jmp trainNext
dance:
    jmp trainDance
UhcDanceTrainHook ENDP

; Replaces 0x4E0DFF in FUN_004E0DE5 (XP trickle multiplier, thiscall). ECX = player. Also
; reached from the dance tooltips (0x9D6D98, 0x9D793F), which show the same multiplier.
UhcDanceXpHook PROC
    TRACE_ONCE "danceBonusCivs XPTrickle (0x4E0DFF)"
    push eax
    push ecx
    push edx
    push eax                        ; civ ID
    push ecx                        ; player
    push 2                          ; DanceBonusType XPTrickle
    call UhcDanceCivAllowed
    test al, al
    pop edx
    pop ecx
    pop eax
    jne dance
    cmp eax, dword ptr ds:[0C6FB50h]    ; stolen 0x4E0DFF
    jmp xpNext
dance:
    jmp xpDance
UhcDanceXpHook ENDP

; Replaces 0x4ECD53 in FUN_004ECD39 (gather rate multiplier, thiscall). ECX = player.
UhcDanceGatherHook PROC
    TRACE_ONCE "danceBonusCivs Gathering (0x4ECD53)"
    push eax
    push ecx
    push edx
    push eax                        ; civ ID
    push ecx                        ; player
    push 8                          ; DanceBonusType Gathering
    call UhcDanceCivAllowed
    test al, al
    pop edx
    pop ecx
    pop eax
    jne dance
    cmp eax, dword ptr ds:[0C6FB50h]    ; stolen 0x4ECD53
    jmp gatherNext
dance:
    jmp gatherDance
UhcDanceGatherHook ENDP

; Replaces 0x49048B in FUN_00490476 (regeneration, thiscall, this in EDI since 0x49047A; ECX
; holds the same value). The continuation reads EDI.
UhcDanceRegenHook PROC
    TRACE_ONCE "danceBonusCivs Regeneration (0x49048B)"
    push eax
    push ecx
    push edx
    push eax                        ; civ ID
    push edi                        ; player
    push 5                          ; DanceBonusType Regeneration
    call UhcDanceCivAllowed
    test al, al
    pop edx
    pop ecx
    pop eax
    jne dance
    cmp eax, dword ptr ds:[0C6FB50h]    ; stolen 0x49048B
    jmp regenNext
dance:
    jmp regenDance
UhcDanceRegenHook ENDP

END
