; attackTypeIcons (features/attacktypeicons.cpp): the bonus multipliers' type chain of the two selection panels.
; Entered through a jmp written over lea edx,[eax+11h] / cmp esi,edx; leaves through an explicit jmp to the stock
; jne that follows (an unlisted type, the two instructions re-executed) or to the stock path of a type with an icon.
.686
.model flat, c
option casemap :none

include common.inc

UhcAttackTypeIcon PROTO STDCALL unitType:DWORD, iconText:DWORD, iconSize:DWORD

.data
typeIconId      dd -1           ; the listed type's string ID, or -1
statFound       dd 004D7F44h    ; lea ecx,[esp+40h] / call 447719h: the fill's path of a type with an icon
statNext        dd 0069B90Eh    ; jne 69B939h: the fill's next type test
minFound        dd 00699DE6h    ; lea ecx,[esp+44h] / call 447719h: the minimized block's path
minNext         dd 00699D36h    ; jne 699D65h: the minimized block's next type test

.code

; Replaces 0x69B909..0x69B90D in the stat panel fill's cold part. ESI = the bonus's unittype, EAX = the proto count
; [db+19B0h], ECX = the game; the row's icon BString is [esp+28h] (a stock branch pushes the texture, then formats
; into [esp+2Ch]). A listed type: the icon goes there, its string ID is pushed and the stock path joined, as the
; stock branches do (they leave EAX, ECX and EDX dead there). Otherwise every register is as it was and the test is
; re-executed.
UhcTypeIconStatHook PROC
    TRACE_ONCE "attackTypeIcons stat panel (0x69B909)"
    pushad
    push 16
    lea edx, [esp+4+20h+28h]            ; the icon BString, past pushad and the push above
    push edx
    push esi
    call UhcAttackTypeIcon
    mov typeIconId, eax
    popad
    cmp typeIconId, -1
    je statStock
    push typeIconId
    jmp statFound
statStock:
    lea edx, [eax+11h]
    cmp esi, edx
    jmp statNext
UhcTypeIconStatHook ENDP

; Replaces 0x699D31..0x699D35 in the minimized block's attack rows: the same registers; the icon BString is
; [esp+24h] (a stock branch pushes the texture, then formats into [esp+28h]).
UhcTypeIconMinHook PROC
    TRACE_ONCE "attackTypeIcons minimized panel (0x699D31)"
    pushad
    push 10
    lea edx, [esp+4+20h+24h]
    push edx
    push esi
    call UhcAttackTypeIcon
    mov typeIconId, eax
    popad
    cmp typeIconId, -1
    je minStock
    push typeIconId
    jmp minFound
minStock:
    lea edx, [eax+11h]
    cmp esi, edx
    jmp minNext
UhcTypeIconMinHook ENDP

END
