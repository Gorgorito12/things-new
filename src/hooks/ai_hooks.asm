; Hook for noAILimit. Entered through a jmp written over the stock code; leaves through an
; explicit jmp to the verified continuation (src/generated/sites.h).
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcPersonalityCount:SDWORD
EXTERNDEF g_uhcPersonalities:DWORD

.data
aiLimitReturn dd 00603C4Fh      ; xor eax,eax / loop over the personality table

.code

; Replaces 0x603B0B..0x603C4E, which builds the stock table of 11 or 14 names on the stack and
; stores its count at [esp+40h] and its address at [esp+50h]. Every register that range sets is
; rewritten before use after the continuation.
UhcAiLimitHook PROC
    TRACE_ONCE "noAILimit (0x603B0B)"
    ; The range also holds two initializations the rest of the function relies on (stock
    ; 0x603B44/0x603B4C, written after a push, hence their +4 offsets there).
    mov dword ptr [esp+24h], 0      ; loaded-personality counter, used as an array index
    mov byte ptr [esp+1Bh], 0       ; the function's return flag
    mov esi, g_uhcPersonalityCount
    mov dword ptr [esp+40h], esi
    mov esi, g_uhcPersonalities
    mov dword ptr [esp+50h], esi
    jmp aiLimitReturn
UhcAiLimitHook ENDP

; noAILimitV2: replaces only 0x603C34..0x603C4E (the TAD-flag test, the 14-entry count and the
; table store), so the stock range before it runs as is, including both initializations above.
; The stack is the same as at 0x603C4F (the push 2 at 0x603B42 is popped at 0x603C31). EAX is the
; only register the replaced range sets, and the continuation clears it.
UhcAiLimitV2Hook PROC
    TRACE_ONCE "noAILimitV2 (0x603C34)"
    mov eax, g_uhcPersonalityCount
    mov dword ptr [esp+40h], eax
    mov eax, g_uhcPersonalities
    mov dword ptr [esp+50h], eax
    jmp aiLimitReturn
UhcAiLimitV2Hook ENDP

END
