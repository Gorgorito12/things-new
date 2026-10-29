; Hook for gaiaSocketsOnly. Entered through a jmp written over the stock code; leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Sockets and placement").
.686
.model flat, c
option casemap :none

include common.inc

UhcGaiaSocketAllowed PROTO STDCALL socket:DWORD, building:DWORD, player:DWORD

.data
socketFoundNext dd 00508CC6h    ; jmp 50757Eh: PLACE's next obstruction entry

.code

; Replaces 0x508CC1 (mov byte ptr [esp+37h],1) in FUN_0050703D, PLACE, where a socketed building
; records that a socket of its type stands exactly at its position. Reached only by falling
; through from 0x508CBB: ESI = the socket unit + 14h (its position), EDI = the building's proto,
; EBP = the world; PLACE's frame: a1 (the player) at [esp+1C0h], a5 (knowledge) at [esp+1D0h],
; the found flag at [esp+37h]. EAX, ECX, EDX and the flags are dead at the continuation; the
; helper keeps EBX, ESI, EDI and EBP. With a5 = 0 (editor, engine, in-place conversion), or a
; socket the rule accepts, the flag is set as in stock; otherwise the socket does not count.
UhcGaiaSocketFoundHook PROC
    TRACE_ONCE "gaiaSocketsOnly (0x508CC1)"
    cmp dword ptr [esp+1D0h], 0     ; a5 = 0: placement without a player's knowledge
    je found
    lea eax, [esi-14h]              ; the socket unit
    push dword ptr [esp+1C0h]       ; a1, the placing player
    push edi                        ; the building's proto
    push eax
    call UhcGaiaSocketAllowed       ; -> al = 0 when the rule refuses the socket's owner
    test al, al
    je refused
found:
    mov byte ptr [esp+37h], 1       ; stolen 0x508CC1: socket found
refused:
    jmp socketFoundNext
UhcGaiaSocketFoundHook ENDP

END
