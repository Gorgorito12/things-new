; Hook for noCorpseDopples. Entered through a jmp written over the stock code; leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Dopples").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcNoCorpseDoppleType:SDWORD   ; marker unittype ID, set on each database load; -1 before
EXTERNDEF g_uhcNoCorpseDoppleLog:SDWORD    ; 1 with "noCorpseDopples ... log"

UhcNoCorpseDoppleLog PROTO STDCALL unit:DWORD, player:DWORD

.data
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): proto IDs and abstract types
doppleCreate    dd 00495355h    ; mov edx,[esi+10h] / push eax / ... / call 4DB3D0h (create the dopples)
noDopple        dd 00486A30h    ; the stock exit when no dopple is made: on to the next player

.code

; Replaces 0x49534D..0x495354 (mov eax,[esp+2Ch] / mov ecx,[esp+54h]) in FUN_0048679A, the unit
; visibility update, where unit ESI has left the view of player EBX (EBP = 1 << EBX, EDI = that
; player) and has passed the stock dopple tests. The frame is the stock one: [esp+2Ch] is the new
; visibility mask and [esp+54h] the forced argument, both passed on to 0x4DB3D0. EAX, ECX, EDX
; and the flags are dead here and at 0x486A30. A unit whose proto is of the marker type and that
; is not alive skips the creation; any other unit, and gaia (for whom 0x4DB3D0 makes nothing),
; runs the stock code.
UhcNoCorpseDoppleHook PROC
    TRACE_ONCE "noCorpseDopples (0x49534D)"
    cmp g_uhcNoCorpseDoppleType, 0
    jl stock
    test ebx, ebx                   ; player 0 (gaia)
    je stock
    mov ecx, dword ptr [esi+5Ch]    ; proto
    test ecx, ecx
    je stock
    push g_uhcNoCorpseDoppleType
    call protoIsType
    test al, al
    je stock
    mov eax, dword ptr [esi]        ; unit vtable
    mov ecx, esi
    call dword ptr [eax+0A4h]       ; isAlive, called as the stock code does at 0x4868FA
    test al, al
    jne stock
    cmp g_uhcNoCorpseDoppleLog, 0
    je skip
    pushad
    push ebx
    push esi
    call UhcNoCorpseDoppleLog
    popad
skip:
    jmp noDopple
stock:
    mov eax, dword ptr [esp+2Ch]    ; stolen 0x49534D
    mov ecx, dword ptr [esp+54h]    ; stolen 0x495351
    jmp doppleCreate
UhcNoCorpseDoppleHook ENDP

END
