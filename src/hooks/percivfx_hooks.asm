; perCivEffects (src/features/percivfx.cpp): an effect with onlyciv="<civ>" works only for a receiving player of that
; civ. Three hooks: the success tail of the effect parse, which records the attribute per effect, and the heads of
; the effect apply dispatcher and of the effect removal, which skip such an effect for a player of another civ.
; Each re-executes the stock instructions it replaces and leaves through an explicit jmp (or the stock ret).
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcPerCivCount:DWORD        ; effects with an onlyciv attribute; 0: the heads cost one compare

UhcPerCivParsed PROTO C effect:DWORD, node:DWORD, ret0:DWORD, def:DWORD
UhcPerCivAllowApply PROTO C effect:DWORD, player:DWORD, techId:DWORD
UhcPerCivAllowRemove PROTO C effect:DWORD, player:DWORD

.data
applyNext   dd 007F7E9Dh    ; mov edx,[0C66234h], in the apply dispatcher
removeNext  dd 007F816Eh    ; push -1, in the effect removal

.code

; Replaces 0x6205EF..0x6205F3 (mov eax,esi / pop esi / pop edi / ret) in the effect parse 0x620572, reached when
; setData returned true. ESI = the effect, EDI = its node. The frame there: [esp] saved ESI, [esp+4] saved EDI,
; [esp+8] the return into the <Effect> handler (0x6204BB), [esp+18h] that handler's second argument, the tech's
; definition (the C++ side reads it only when the return address is 0x6204BB).
UhcPerCivParseHook PROC
    TRACE_ONCE "perCivEffects effect parse (0x6205EF)"
    push dword ptr [esp+18h]        ; def
    push dword ptr [esp+0Ch]        ; the return address, [esp+8] before the push above
    push edi
    push esi
    call UhcPerCivParsed
    add esp, 10h
    mov eax, esi
    pop esi
    pop edi
    ret
UhcPerCivParseHook ENDP

; Replaces mov eax,fs:[0] at 0x7F7E97, the head of the apply dispatcher: thiscall(effect = ECX, player, unit,
; techId, a, b), ret 14h. A skipped effect returns 1, as the dispatcher does for an effect it has nothing to do with.
UhcPerCivApplyHook PROC
    TRACE_ONCE "perCivEffects apply (0x7F7E97)"
    cmp g_uhcPerCivCount, 0
    jne check
stock:
    db 64h, 0A1h, 0, 0, 0, 0        ; mov eax,fs:[0]
    jmp applyNext
check:
    push ecx
    push dword ptr [esp+10h]        ; techId ([esp+0Ch] at the head)
    push dword ptr [esp+0Ch]        ; player ([esp+4] at the head)
    push ecx
    call UhcPerCivAllowApply
    add esp, 0Ch
    pop ecx
    test al, al
    jnz stock
    mov al, 1
    ret 14h
UhcPerCivApplyHook ENDP

; Replaces mov eax,fs:[0] at 0x7F8168, the head of the effect removal: thiscall(effect = ECX, player, a, b), ret 0Ch.
UhcPerCivRemoveHook PROC
    TRACE_ONCE "perCivEffects remove (0x7F8168)"
    cmp g_uhcPerCivCount, 0
    jne check
stock:
    db 64h, 0A1h, 0, 0, 0, 0        ; mov eax,fs:[0]
    jmp removeNext
check:
    push ecx
    push dword ptr [esp+8]          ; player ([esp+4] at the head)
    push ecx
    call UhcPerCivAllowRemove
    add esp, 8
    pop ecx
    test al, al
    jnz stock
    mov al, 1
    ret 0Ch
UhcPerCivRemoveHook ENDP

END
