; Hook for techPrereqRecheck. Entered through a jmp written over the stock dirty test of a
; player's tech tree; leaves through an explicit jmp to one of the test's two verified
; continuations (docs/engine-symbols.md, "Tech prerequisites").
.686
.model flat, c
option casemap :none

include common.inc

UhcTechPrereqMaybeMark PROTO STDCALL techTree:DWORD, player:DWORD

.data
recheckPass     dd 005096D4h    ; xor esi,esi / cmp [edi+8],esi / mov byte [edi+10h],0: the stock re-check
noRecheck       dd 00491A22h    ; pop esi / pop ebx / pop edi / pop ebp / add esp,0Ch / ret 4

.code

; Replaces 0x491A18..0x491A21 (cmp byte ptr [edi+10h],0 / jne 5096D4h) in FUN_004919CE, the
; per-player tech tree update, thiscall(tree, Player*), run for each live player on every world
; update. EDI = the tree, EBP = the player (non-null); ESI, EBX, EDI and EBP are pushed below the
; return address and the 0Ch locals. The C++ check may set the dirty byte [edi+10h]; the stock
; test then runs as written, so a set byte enters the stock re-check of every tech in this same
; call. Every register is preserved, and the flags are those of the re-executed cmp, as in stock.
UhcTechPrereqHook PROC
    TRACE_ONCE "techPrereqRecheck (0x491A18)"
    pushad
    push ebp                        ; Player*
    push edi                        ; the player's tech tree
    call UhcTechPrereqMaybeMark
    popad
    cmp byte ptr [edi+10h], 0       ; stolen 0x491A18
    jne recheck                     ; stolen 0x491A1C: jne 5096D4h
    jmp noRecheck
recheck:
    jmp recheckPass
UhcTechPrereqHook ENDP

END
