; Hook for partisans. Entered through a jmp written over the kill handler's civ test of the
; guerrilla; leaves through an explicit jmp to its verified continuation (docs/engine-symbols.md,
; "Partisans").
.686
.model flat, c
option casemap :none

include common.inc

; Decides and spawns the guerrilla of a dying unit; `flag` is the kill handler's first byte argument.
UhcPartisansOnDeath PROTO STDCALL unit:DWORD, flag:DWORD

.data
civTestNext     dd 004B533Fh    ; mov ecx,[esi+5Ch]: the proto flag 44h test after the guerrilla

.code

; Replaces mov ecx,[esi+44h] / call 4B4EBDh / cmp al,1 / je 6A3F04h (16 bytes) at 0x4B532F in the
; kill handler FUN_004B4F70 (ESI = the dying unit; its frame: 8Ch of locals, then EBP, ESI, EDI and
; EBX pushed, so the first byte argument is at [esp+0A0h]). The stock code tests the owner's civ,
; and its cold block 0x6A3F04 the count, that argument and the build, then calls the spawn
; 0x9C07D6; UhcPartisansOnDeath makes the same tests with the key's data and calls that spawn
; itself. EAX, ECX and EDX are dead at the continuation (it loads ECX, and EAX is written before
; it is read on every path, 0x4B5348 / 0x4B5362); EBX, ESI, EDI and EBP are kept by the stdcall.
UhcPartisansHook PROC
    TRACE_ONCE "partisans (0x4B532F)"
    movzx eax, byte ptr [esp+0A0h]  ; the kill handler's first byte argument
    push eax
    push esi                        ; the dying unit
    call UhcPartisansOnDeath
    jmp civTestNext
UhcPartisansHook ENDP

END
