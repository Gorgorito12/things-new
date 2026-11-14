; Hooks for smartHealTargets. Entered through a jmp written over the stock code; each leaves
; through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Unit types and
; healing").
.686
.model flat, c
option casemap :none

include common.inc

UhcSmartHealConsider PROTO STDCALL healer:DWORD, unit:DWORD
UhcSmartHealPick PROTO STDCALL healer:DWORD
UhcSmartHealRecheck PROTO STDCALL healer:DWORD, target:DWORD   ; AL: end this heal

.data
inRange         dd 007FCF2Dh    ; bool thiscall(healer, unit, range), ret 8: the search's last test
nextCandidate   dd 009CDA3Fh    ; the loop's step to the next query entry
acceptCandidate dd 009CDA62h    ; healer vtbl+64h(1), then 0x9CBDC4(owner, [esi+10h]): heal ESI
searchFailExit  dd 009CDA5Dh    ; pop ebp / add esp,10h / ret: AL = 0, no target
healingNext     dd 009E0C43h    ; push 5 / mov ecx,edi / call 9C2E40h: the healing state goes on
healEnd         dd 009E0D3Fh    ; the action's vtbl+34h(10): the heal ends, the healer goes idle

.code

; switch=<percent>: replaces mov ecx,[esi+24h] / push 8 / mov [esp+14h],ecx (9 bytes at 0x9E0C3A),
; the start of the healing state (8) of the heal tick FUN_009E0B53 (ESI = the heal action, healer
; at [esi+10h], EDI = target). UhcSmartHealRecheck may run the search as a dry run; when a
; candidate beats the target by the margin, the tick ends through its own end path 0x9E0D3F (the
; stack there is this one, as for the stock jumps to it). Otherwise the stolen bytes run again.
; Every register is kept (pushad; popad leaves the flags of the test).
UhcSmartHealSwitchHook PROC
    TRACE_ONCE "smartHealTargets switch (0x9E0C3A)"
    pushad
    push edi                        ; target
    push dword ptr [esi+10h]        ; healer
    call UhcSmartHealRecheck
    test al, al
    popad
    jne switchTarget
    mov ecx, dword ptr [esi+24h]    ; stolen 0x9E0C3A
    push 8                          ; stolen 0x9E0C3D
    mov dword ptr [esp+14h], ecx    ; stolen 0x9E0C3F
    jmp healingNext
switchTarget:
    jmp healEnd
UhcSmartHealSwitchHook ENDP

; Replaces call 7FCF2Dh at 0x9CDA36 in the automatic heal search FUN_009CD865, the last of the
; stock tests: ECX = healer, the candidate and the action's range are pushed, ESI = candidate,
; EBP = the search's owner (healer at [ebp+4]). Stock heals the first candidate in range
; (jne 9CDA62h); here a candidate in range is only recorded (UhcSmartHealConsider keeps the best
; one) and the loop goes on. EBX, ESI, EDI and EBP are kept; EAX, ECX, EDX and the flags are
; written again at 0x9CDA3F before they are read.
UhcSmartHealRangeHook PROC
    TRACE_ONCE "smartHealTargets candidate (0x9CDA36)"
    call inRange                    ; stolen 0x9CDA36
    test al, al
    je next
    pushad
    push esi                        ; candidate
    push dword ptr [ebp+4]          ; healer
    call UhcSmartHealConsider
    popad
next:
    jmp nextCandidate
UhcSmartHealRangeHook ENDP

; Replaces pop esi / pop ebx / pop edi / xor al,al at 0x9CDA58, where the search ends without a
; target (the loop is exhausted, or the query was empty, 0x9CD92A). The stack is the one the
; accept path 0x9CDA62 expects (it pops ESI, EBX, EDI and EBP at 0x9CDA77): with a recorded best
; candidate the hook jumps there with ESI = that unit; without one it re-does the stolen bytes.
UhcSmartHealPickHook PROC
    TRACE_ONCE "smartHealTargets pick (0x9CDA58)"
    push dword ptr [ebp+4]          ; healer
    call UhcSmartHealPick           ; EAX = the best candidate, or 0; clobbers ECX, EDX
    test eax, eax
    je none
    mov esi, eax
    jmp acceptCandidate
none:
    pop esi                         ; stolen 0x9CDA58
    pop ebx                         ; stolen 0x9CDA59
    pop edi                         ; stolen 0x9CDA5A
    xor al, al                      ; stolen 0x9CDA5B
    jmp searchFailExit
UhcSmartHealPickHook ENDP

END
