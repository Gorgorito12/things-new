; Hooks for broadsideMuzzleLimit. Entered through a jmp written over the stock code; each leaves
; through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Broadside attacks").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcBroadsideType:SDWORD     ; marker unittype ID, set on each database load; -1 before
EXTERNDEF g_uhcBroadsideAll:DWORD       ; 1 when no UnitType is given: every ship gets the limit
EXTERNDEF g_uhcBroadsideLimit:DWORD     ; muzzles per side, 1..255
EXTERNDEF g_uhcBroadsideAction:DWORD    ; the action whose limit the hook set last, else 0

UhcBroadsideLogSetup PROTO STDCALL action:DWORD, leftMuzzles:DWORD, limit:DWORD

.data
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): proto IDs and abstract types
limitNext       dd 005033DAh    ; mov [esp+0Ch],esi (the limit, kept in a local) / je 503424h
clampLNext      dd 005034E8h    ; jg 6A8252h: more MuzzleL points than the limit -> count = limit

.code

; Replaces 0x5033D5 (mov esi,6) in FUN_0050339A, the set-up of a BroadsideAttack action, where ESI
; becomes the most muzzles per side that get a firing slot. EDI = the action; its owner unit
; [edi+10h] and the owner's proto were tested non-null, and the proto is a Ship (0x5033AA..0x5033C9).
; ECX = [edi+4], the proto action, and ZF comes from its test at 0x5033D2: the je at 0x5033DE and
; the mov edx,ecx at 0x5033E9 read them. The caller's ESI is already pushed (0x5033D4); EAX and EDX
; are written before they are read on both paths. A marked owner (or any ship, without a UnitType)
; gets the configured limit; any other owner keeps the stock 6. A <SingleUsePlayer> action still
; drops it to 1 after the continuation (0x5033E0 / 0x6A8236).
UhcBroadsideLimitHook PROC
    TRACE_ONCE "broadsideMuzzleLimit (0x5033D5)"
    mov esi, 6                      ; stolen 0x5033D5: the stock limit
    mov g_uhcBroadsideAction, 0
    cmp g_uhcBroadsideAll, 0
    jne setLimit
    cmp g_uhcBroadsideType, 0
    jl done                         ; marker not resolved yet: stock
    push ecx                        ; the proto action, read again after the continuation
    mov ecx, dword ptr [edi+10h]    ; owner unit
    test ecx, ecx
    je restore
    mov ecx, dword ptr [ecx+5Ch]    ; owner proto
    test ecx, ecx
    je restore
    push g_uhcBroadsideType
    call protoIsType                ; saves ESI; clobbers only EAX, ECX, EDX
    test al, al
    je restore
    pop ecx
setLimit:
    mov esi, g_uhcBroadsideLimit
    mov g_uhcBroadsideAction, edi
    jmp done
restore:
    pop ecx
done:
    test ecx, ecx                   ; the stock ZF of 0x5033D2, for the je at 0x5033DE
    jmp limitNext
UhcBroadsideLimitHook ENDP

; Replaces 0x5034E2..0x5034E7 (cmp eax,esi / mov [esp+1Ch],eax) in the same function, only with
; "log": the MuzzleL clamp. EAX = the MuzzleL points of the owner's model, ESI = the limit (1 for a
; <SingleUsePlayer> action), EDI = the action, whose MuzzleR slots are already counted in
; [edi+80h] (0x5034BA). For the action the hook above gave the configured limit, logs the set-up,
; then re-executes both instructions: the jg at 0x5034E8 reads the flags of the compare.
UhcBroadsideLogHook PROC
    TRACE_ONCE "broadsideMuzzleLimit log (0x5034E2)"
    cmp edi, g_uhcBroadsideAction
    jne stock
    pushad
    push esi                        ; the limit
    push eax                        ; MuzzleL points
    push edi                        ; the action
    call UhcBroadsideLogSetup
    popad
    mov g_uhcBroadsideAction, 0
stock:
    cmp eax, esi                    ; stolen 0x5034E2
    mov dword ptr [esp+1Ch], eax    ; stolen 0x5034E4: the MuzzleL count, in the argument slot
    jmp clampLNext
UhcBroadsideLogHook ENDP

END
