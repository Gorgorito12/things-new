; Hook for wonderPanelSkipAuras. Entered through a call redirected from the stock code, so it
; leaves through ret 24h, like the function it stands in for, to the verified test al,al after
; the call (docs/engine-symbols.md, "Abilities and the wonder power panel").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcWonderPanelLog:SDWORD   ; nonzero with "wonderPanelSkipAuras log"

UhcWonderPanelLogAbility PROTO STDCALL unit:DWORD, n:DWORD, recIdx:DWORD, powerId:DWORD

.data
nthAbility      dd 006EE5CCh    ; bool thiscall(mgr, n, player, unit, cost*, icon*, rollover*,
                                ; usable*, recIdx*, powerId*), ret 24h: the unit's n-th visible ability
abilityByIndex  dd 0044E702h    ; record* thiscall(mgr, int index), ret 4; 0 when out of range

.code

; Called instead of 0x6EE5CC by the call at 0x69EE5D in the wonder power panel refresh, so it
; returns to 0x69EE62 (test al,al / je 69F31Bh). ECX = the ability manager ([world+56Ch], never 0
; here: 0x458744 skips the panel otherwise); the nine stack arguments are those of 0x6EE5CC, with
; n = 0 (push 0 at 0x69EE5B). Asks for n = 0..7 and returns true with the first ability that
; exists, is available (tech and age, checked by 0x6EE5CC) and is not AlwaysDisabledInGrid (byte
; +1Dh bit 0, a passive aura); the outputs are those of that call. With none it returns false.
; EBX and ESI are saved, EDI and EBP are kept by every callee; the stock code after the call
; reads neither EAX above AL, ECX, EDX nor the flags it was entered with.
UhcWonderPanelAbilityHook PROC
    TRACE_ONCE "wonderPanelSkipAuras (0x69EE5D)"
    push ebx
    push esi
    mov esi, ecx                    ; ability manager
    xor ebx, ebx                    ; n
scan:
    push dword ptr [esp+2Ch]        ; powerId*   (each push moves the next argument to +2Ch)
    push dword ptr [esp+2Ch]        ; recIdx*
    push dword ptr [esp+2Ch]        ; usable*
    push dword ptr [esp+2Ch]        ; rollover*
    push dword ptr [esp+2Ch]        ; icon*
    push dword ptr [esp+2Ch]        ; cost*
    push dword ptr [esp+2Ch]        ; unit
    push dword ptr [esp+2Ch]        ; player
    push ebx                        ; n
    mov ecx, esi
    call nthAbility
    test al, al
    je next                         ; no n-th ability, or its tech or age is not reached
    mov eax, dword ptr [esp+28h]    ; recIdx*
    push dword ptr [eax]
    mov ecx, esi
    call abilityByIndex             ; the record, as the stock code after the call reads it
    test eax, eax
    je next
    test byte ptr [eax+1Dh], 1      ; AlwaysDisabledInGrid: a passive aura, never a panel button
    je found
next:
    inc ebx
    cmp ebx, 8
    jb scan
    xor al, al
    jmp done
found:
    test ebx, ebx
    je shown                        ; n = 0: the ability stock shows
    cmp g_uhcWonderPanelLog, 0
    je shown
    mov eax, dword ptr [esp+2Ch]    ; powerId*
    push dword ptr [eax]
    mov eax, dword ptr [esp+2Ch]    ; recIdx* (one push deeper)
    push dword ptr [eax]
    push ebx                        ; n
    push dword ptr [esp+20h]        ; unit
    call UhcWonderPanelLogAbility
shown:
    mov al, 1
done:
    pop esi
    pop ebx
    ret 24h
UhcWonderPanelAbilityHook ENDP

END
