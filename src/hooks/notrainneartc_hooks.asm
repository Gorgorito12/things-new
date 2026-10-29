; Hook for noTrainNearEnemyTC. Entered through a jmp written over the stock code; leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Training near an enemy Town
; Center").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcNoTrainType:SDWORD      ; marker unittype ID, set on each database load; -1 before
; float thiscall(unit): the trainer's BuildingWorkRate in st0. 0x9BFE33 (the stock getter), or
; buildingWorkRateAuras' wrapper, which multiplies in the unit's auras (features/bwrauras.cpp).
EXTERNDEF g_uhcBwrTrainGetter:DWORD

UhcNoTrainBlocked PROTO STDCALL trainer:DWORD

.data
trainRateNext   dd 009EA418h    ; mov ebx,[0C66234h] / mov eax,[ebx+13Ch] / fmul [eax+310h]

.code

; Replaces 0x9EA410..0x9EA417 (mov ecx,[esi+10h] / call 9BFE33h) in FUN_009EA28B, the Train
; update, where an active queue reads its trainer's work rate; the code after it multiplies the
; rate by the game speed and the civ's train rate and adds it to the progress [esi+68h].
; ESI = the Train action (trainer at [esi+10h]), EDI = the trainer's player, and the x87 stack is
; empty (no x87 code runs in the function before this point). A trainer that UhcNoTrainBlocked
; holds gets the rate 0.0, so the queue keeps its progress and waits; any other trainer runs the
; two stolen instructions. Both paths leave st0 = the rate, one x87 slot, as the getter does.
; EAX, EBX and ECX are written after 0x9EA418 before they are read, EDX is not read (0x485D2C,
; called at 0x9EA432, overwrites it), nor are the flags; the helper keeps ESI, EDI, EBP and EBX.
UhcNoTrainHook PROC
    TRACE_ONCE "noTrainNearEnemyTC (0x9EA410)"
    cmp g_uhcNoTrainType, 0
    jl stock
    push dword ptr [esi+10h]        ; the trainer
    call UhcNoTrainBlocked          ; bool: marked, and an enemy FirstTC is alive within range
    test al, al
    je stock
    fldz                            ; rate 0.0: no progress this tick
    jmp trainRateNext
stock:
    mov ecx, dword ptr [esi+10h]    ; stolen 0x9EA410
    call g_uhcBwrTrainGetter        ; stolen 0x9EA413 (call 9BFE33h), or the aura wrapper
    jmp trainRateNext
UhcNoTrainHook ENDP

END
