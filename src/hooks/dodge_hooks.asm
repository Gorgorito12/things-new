; Hooks for dodgeAnyUnit, dodgeSoundSet and criticalSoundSet. Entered through a jmp (or, for the
; log wrapper, a call) written over the stock code; each leaves through an explicit jmp to a
; verified continuation (docs/engine-symbols.md, "Dodge and critical hits").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcDodgeType:SDWORD      ; marker unittype ID, set on each database load; -1 before

UhcDodgeLogHit PROTO STDCALL unit:DWORD
UhcDodgeSoundFor PROTO STDCALL unit:DWORD
UhcCriticalSoundFor PROTO STDCALL unit:DWORD

.data
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): proto IDs and abstract types
dodgePath       dd 006A249Ch    ; the dodge: push "ypDodge" / tech lookup / 15 % roll
protoCompares   dd 0049ACEBh    ; stock: cmp eax,[ecx+5E88h] ... the three Japanese monk IDs
dodgeStock      dd 0049ACAAh    ; bool thiscall(unit): the dodge test the damage function calls
dodgeSoundNext  dd 006A262Dh    ; add esi,14h / push esi / call 4AA24Ch (play sound set)
critSoundNext   dd 006A2A9Fh    ; lea eax,[ebx+14h] / push eax / call 4AA24Ch (play sound set)

.code

; Replaces 0x49ACE5..0x49ACEA (mov eax,[esi+5Ch] / mov eax,[eax+4]) in FUN_0049ACAA, where only
; the three ypMonkJapanese protos may dodge. ESI = the unit being hit, ECX = database, EBX = its
; player, EDI = [world+7Ch]; the frame is the stock one. A unit whose proto is of the marker type
; enters the stock dodge path (tech ypDodge, 15 % roll); any other unit runs the stock compares.
UhcDodgeProtoHook PROC
    TRACE_ONCE "dodgeAnyUnit (0x49ACE5)"
    cmp g_uhcDodgeType, 0
    jl stock
    push ecx                        ; the database, needed by the stock compares
    mov ecx, dword ptr [esi+5Ch]    ; target proto
    test ecx, ecx
    je restore
    push g_uhcDodgeType
    call protoIsType
    test al, al
    je restore
    pop ecx
    jmp dodgePath
restore:
    pop ecx
stock:
    mov eax, dword ptr [esi+5Ch]    ; stolen 0x49ACE5
    mov eax, dword ptr [eax+4]      ; stolen 0x49ACE8
    jmp protoCompares
UhcDodgeProtoHook ENDP

; Called instead of 0x49ACAA by the call at 0x49B023 (only with "dodgeAnyUnit … log"), so it
; returns to 0x49B028 (test al,al). ECX = the unit being hit. Logs every dodge; EAX, ECX and EDX
; are not preserved by a call in the stock code either.
UhcDodgeCallHook PROC
    TRACE_ONCE "dodgeAnyUnit log (0x49B023)"
    push ecx
    call dodgeStock
    pop ecx
    test al, al
    je done
    push eax
    push ecx
    call UhcDodgeLogHit
    pop eax
done:
    ret
UhcDodgeCallHook ENDP

; Replaces 0x6A2628 (push "PowerEvade") in FUN_0049ACAA, the sound set a dodge plays. ESI = the
; unit that dodged, ECX = game (used by the call that follows), EAX already pushed.
UhcDodgeSoundHook PROC
    TRACE_ONCE "dodgeSoundSet (0x6A2628)"
    push ecx
    push esi
    call UhcDodgeSoundFor           ; -> the configured sound set, or "PowerEvade"
    pop ecx
    push eax
    jmp dodgeSoundNext
UhcDodgeSoundHook ENDP

; Replaces 0x6A2A9A (push "PowerCriticalStrike") in the damage function's critical-hit path.
; EBX = the attacking unit (non-null here), ECX = game, EDX already pushed.
UhcCriticalSoundHook PROC
    TRACE_ONCE "criticalSoundSet (0x6A2A9A)"
    push ecx
    push ebx
    call UhcCriticalSoundFor        ; -> the configured sound set, or "PowerCriticalStrike"
    pop ecx
    push eax
    jmp critSoundNext
UhcCriticalSoundHook ENDP

END
