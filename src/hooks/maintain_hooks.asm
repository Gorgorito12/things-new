; Hook for maintainWaitForPop. Entered through a jmp written over the stock code; leaves through
; an explicit jmp to a verified continuation (docs/engine-symbols.md, "Maintain (automatic
; production)").
.686
.model flat, c
option casemap :none

include common.inc

UhcMaintainPopBlocked PROTO STDCALL action:DWORD

.data
spawnNext       dd 006AB283h    ; push edx / push eax / call 9E2DEFh (spawn), then the restart
notDone         dd 006AB180h    ; pop ebx / jmp 493039h: the update's "cycle not complete" exit

.code

; Replaces 0x6AB27D..0x6AB282 (mov edx,[esi+68h] / mov eax,[esi+64h]) in the cold chunk of the
; Maintain update FUN_00492F3E, reached only by the fall-through of the "cycle complete" test
; ([esi+74h] >= 1.0). ESI = the Maintain action, ECX = ESI (this of the spawn call), EBX pushed
; by the chunk, FPU stack empty. When the first unit of the cycle does not fit in its player's
; population and the building has the marker type, the cycle stays complete and the update leaves
; as for an unfinished cycle: no spawn, no restart. Otherwise the stock spawn and restart run.
UhcMaintainSpawnHook PROC
    TRACE_ONCE "maintainWaitForPop (0x6AB27D)"
    pushad
    push esi
    call UhcMaintainPopBlocked      ; AL = 1: hold the finished unit
    test al, al
    popad                           ; leaves the flags of the test
    jne hold
    mov edx, dword ptr [esi+68h]    ; stolen 0x6AB27D: units per cycle
    mov eax, dword ptr [esi+64h]    ; stolen 0x6AB280: proto ID to spawn
    jmp spawnNext
hold:
    mov eax, dword ptr [esi+6Ch]    ; train points of a whole cycle
    mov dword ptr [esi+70h], eax    ; progress stays exactly complete; EAX is not read after
    jmp notDone
UhcMaintainSpawnHook ENDP

END
