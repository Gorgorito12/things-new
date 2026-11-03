; Hooks for betterfreedynamicunit (src/features/freeunits.cpp). Each replaces the stock
; "dynamic" free unit count (a negative amount times min([world+134h], 15)) and leaves through an
; explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcDynamicUnitCount PROTO C amount:DWORD

.data
freeUnit1Back dd 007FA72Ah   ; lea ecx,[esp+20h] (the count is in [esp+24h])
freeUnit2Back dd 008D8CBDh   ; mov ecx,[esp+24h] (the count is in [esp+38h])

.code

; 0x7FA6ED: the amount (negative) is in [esp+24h]; the count goes back there.
UhcFreeDynamicUnit1Hook PROC
    TRACE_ONCE "betterfreedynamicunit (0x7FA6ED)"
    push dword ptr [esp+24h]
    call UhcDynamicUnitCount
    add esp, 4
    mov dword ptr [esp+24h], eax
    jmp freeUnit1Back
UhcFreeDynamicUnit1Hook ENDP

; 0x8D8C88: the amount (negative) is in [esp+34h]; the count goes to [esp+38h].
UhcFreeDynamicUnit2Hook PROC
    TRACE_ONCE "betterfreedynamicunit (0x8D8C88)"
    push dword ptr [esp+34h]
    call UhcDynamicUnitCount
    add esp, 4
    mov dword ptr [esp+38h], eax
    jmp freeUnit2Back
UhcFreeDynamicUnit2Hook ENDP

END
