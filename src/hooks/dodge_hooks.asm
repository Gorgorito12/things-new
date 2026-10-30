; Hooks for dodgeAnyUnit, dodgeChance, dodgeSoundSet and criticalSoundSet. Entered through a jmp (or, for the
; log wrapper, a call) written over the stock code; each leaves through an explicit jmp to a
; verified continuation (docs/engine-symbols.md, "Dodge and critical hits").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcDodgeType:SDWORD      ; marker unittype ID, set on each database load; -1 before

UhcDodgeLogHit PROTO STDCALL unit:DWORD
UhcDodgeDecide PROTO STDCALL unit:DWORD, damageInfo:DWORD   ; EAX: DECIDE_*
UhcDodgeSoundFor PROTO STDCALL unit:DWORD
UhcCriticalSoundFor PROTO STDCALL unit:DWORD

.data
dodgePath       dd 006A249Ch    ; the dodge: push "ypDodge" / tech lookup / 15 % roll
protoCompares   dd 0049ACEBh    ; stock: cmp eax,[ecx+5E88h] ... the three Japanese monk IDs
dodgeStock      dd 0049ACAAh    ; bool thiscall(unit): the dodge test the damage function calls
dodgeShown      dd 006A24FCh    ; after the stock roll: floating text, sound set, mov al,1 / ret
dodgeNone       dd 0049AD0Fh    ; pop edi / pop ebx / xor al,al / pop esi / add esp,78h / ret

DECIDE_STOCK_COMPARES EQU 0     ; UhcDodgeDecide's answers (dodge.cpp, Decision)
DECIDE_STOCK_PATH     EQU 1
DECIDE_DODGED         EQU 2
DECIDE_NOT_DODGED     EQU 3
dodgeSoundNext  dd 006A262Dh    ; add esi,14h / push esi / call 4AA24Ch (play sound set)
critSoundNext   dd 006A2A9Fh    ; lea eax,[ebx+14h] / push eax / call 4AA24Ch (play sound set)

.code

; Replaces 0x49ACE5..0x49ACEA (mov eax,[esi+5Ch] / mov eax,[eax+4]) in FUN_0049ACAA, where only
; the three ypMonkJapanese protos may dodge. ESI = the unit being hit, ECX = database, EBX = its
; player, EDI = [world+7Ch]; [esp] = the caller's EDI, saved at 0x49ACDD: the hit's damage info
; [action+24h] at the only call, 0x49B023 (dodge.cpp). The frame is the stock one and the FPU stack
; is empty. UhcDodgeDecide (dodgeChance's rules, then dodgeAnyUnit's marker) picks the way out:
; the stock compares (the stolen loads redone), the stock dodge path (tech ypDodge, 15 % roll; ECX
; = database and EDI = [world+7Ch] as it expects), the end of that path after its roll (0x6A24FC:
; ESI and EBX are all it reads), or the stock "not dodged" exit. EAX and EDX are written there
; before they are read.
UhcDodgeProtoHook PROC
    TRACE_ONCE "dodge test (0x49ACE5)"
    push ecx                        ; the database
    push dword ptr [esp+4]          ; the damage info (the caller's EDI)
    push esi                        ; the unit being hit
    call UhcDodgeDecide
    pop ecx
    cmp eax, DECIDE_DODGED
    je dodged
    cmp eax, DECIDE_NOT_DODGED
    je notDodged
    cmp eax, DECIDE_STOCK_PATH
    je stockPath
    mov eax, dword ptr [esi+5Ch]    ; stolen 0x49ACE5
    mov eax, dword ptr [eax+4]      ; stolen 0x49ACE8
    jmp protoCompares
stockPath:
    jmp dodgePath
dodged:
    jmp dodgeShown
notDodged:
    jmp dodgeNone
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
