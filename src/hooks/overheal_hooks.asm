; Hooks for overhealHitpointBars. Each is entered through a jmp written over the stock code and
; leaves through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Hit
; points"). Only display code is hooked: the max HP getter 0x480408 and the health ratio 0x45F295
; stay stock for their simulation callers. At every hook site the FPU stack is empty (the HP was
; just stored with fistp, or the site is a call) and EAX, ECX, EDX and the flags are dead after
; the continuation; the helpers preserve EBX, ESI, EDI and EBP.
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcOverhealTypes:SDWORD      ; marker unittype IDs, set on each database load; -1 before
EXTERNDEF g_uhcOverhealTypeCount:SDWORD  ; how many of them the cfg line names
EXTERNDEF g_uhcOverhealLog:SDWORD        ; 1 with "overhealHitpointBars ... log"

UhcOverhealLogReference PROTO STDCALL unit:DWORD, reference:DWORD, maxHp:DWORD

.data
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): integer code, ret 4
maxHitpoints    dd 00480408h    ; float thiscall(unit): override if > -1e-6, else [proto+98h], else 0
barNext         dd 0045FAB4h    ; fstp [esp+10h]: the floating bar's fill, then its clamp to [0, 1]
groupNext       dd 004C5019h    ; fadd [esi+1Ch] / pop edi / pop ebx / fidiv [esi+14h]: group average
panelMaxNext    dd 00698B3Ah    ; fnstcw / ... / fistp: the max of unitHitPointsValue's '%d/%d'
statMaxNext     dd 004D75ADh    ; fnstcw / ... / fistp [esp+18h]: the stat row's max
statBaseNext    dd 004D761Bh    ; fnstcw / ... / fistp [esp+0Ch]: the stat row's base
infoBaseNext    dd 009AFA30h    ; fnstcw / mov ecx,esi / ... / fistp [esp+20h]: ObjectInfo's base
infoMaxNext     dd 009AFA53h    ; fnstcw / ... / fistp [esp+24h]: ObjectInfo's max
minHitpoints    real4 1.0E-6    ; the stock threshold of 0x45F295 (0xB9FB64)

.code

; AL = 1 if proto ECX has one of the configured unit types and 1e-6 < InitialHitpoints [+9Ch] <
; MaxHitpoints [+98h], else AL = 0. Clobbers EAX, ECX, EDX and the flags, like the is-a test it
; calls; leaves the FPU stack as it found it (it needs one free slot).
OverhealUsesInitial PROC PRIVATE
    push esi
    push edi
    mov esi, ecx                    ; proto
    xor edi, edi
nextType:
    cmp edi, g_uhcOverhealTypeCount
    jge notMarked
    mov eax, g_uhcOverhealTypes[edi*4]
    inc edi
    test eax, eax
    jl nextType                     ; not registered yet (no database loaded)
    push eax
    mov ecx, esi
    call protoIsType
    test al, al
    je nextType
    fld dword ptr [esi+9Ch]         ; InitialHitpoints
    fcom minHitpoints
    fnstsw ax
    test ah, 45h                    ; C0, C2 or C3: not above 1e-6, or NaN
    jne popNo
    fcomp dword ptr [esi+98h]       ; against MaxHitpoints, and popped
    fnstsw ax
    and ah, 45h
    cmp ah, 1                       ; C0 alone: InitialHitpoints < MaxHitpoints
    sete al
    jmp done
popNo:
    fstp st(0)
notMarked:
    xor eax, eax
done:
    pop edi
    pop esi
    ret
OverhealUsesInitial ENDP

; float thiscall(unit ECX): the 100 % reference of the unit's HP, in ST0 like 0x480408. Stock it
; is the max (0x480408); for a unit whose proto uses its InitialHitpoints (OverhealUsesInitial)
; it is InitialHitpoints, or max x InitialHitpoints / MaxHitpoints when a modifier gave the unit
; another max. InitialHitpoints is returned as it is, not through the product: the texts truncate
; (fistp with RC = 11b), and 165 x 150 / 165 rounded at single precision could print 149. Called
; with an empty FPU stack; preserves EBX, ESI, EDI and EBP.
OverhealReference PROC PRIVATE
    push esi
    push edi
    mov esi, ecx                    ; unit
    call maxHitpoints               ; ST0 = max
    mov edi, dword ptr [esi+5Ch]    ; the unit's proto (its player's copy)
    test edi, edi
    je done
    mov ecx, edi
    call OverhealUsesInitial
    test al, al
    je done
    fld dword ptr [edi+98h]
    fcomp st(1)                     ; MaxHitpoints against the unit's max
    fnstsw ax
    test ah, 40h                    ; C3: equal, no modifier
    je scaled
    fld dword ptr [edi+9Ch]         ; reference = InitialHitpoints, max
    jmp haveReference
scaled:
    fld st(0)                       ; max, max
    fmul dword ptr [edi+9Ch]
    fdiv dword ptr [edi+98h]        ; reference = max x InitialHitpoints / MaxHitpoints, max
haveReference:
    cmp g_uhcOverhealLog, 0
    jne logReference
    fstp st(1)                      ; reference
    jmp done
logReference:
    sub esp, 8
    fstp dword ptr [esp]            ; [esp] = reference
    fstp dword ptr [esp+4]          ; [esp+4] = max; the FPU stack is empty for the C++ call
    push dword ptr [esp+4]          ; maxHp
    push dword ptr [esp+4]          ; reference (moved to [esp+4] by the push above)
    push esi                        ; unit
    call UhcOverhealLogReference
    fld dword ptr [esp]             ; ST0 = reference
    add esp, 8
done:
    pop edi
    pop esi
    ret
OverhealReference ENDP

; float thiscall(unit ECX): HP [+64h] / reference, with the stock rules of 0x45F295 for HP / max:
; 0 when the reference is below 1e-6, 1.0 when the HP reaches it. Returns in ST0; preserves EBX,
; ESI, EDI and EBP.
OverhealRatio PROC PRIVATE
    push esi
    mov esi, ecx                    ; unit
    call OverhealReference          ; ST0 = reference
    fcom minHitpoints
    fnstsw ax
    test ah, 5
    jnp zero                        ; C0 alone, as at 0x45F2C5: reference < 1e-6
    fcom dword ptr [esi+64h]
    fnstsw ax
    test ah, 41h
    jnp full                        ; C0 or C3 alone, as at 0x45F2D3: reference <= HP
    fdivr dword ptr [esi+64h]       ; HP / reference
    jmp done
zero:
    fstp st(0)
    fldz
    jmp done
full:
    fstp st(0)
    fld1
done:
    pop esi
    ret
OverhealRatio ENDP

; float thiscall(database proto ECX): the base of the '(%d+%d)' split, which stock reads from the
; database proto's MaxHitpoints [+98h]: its InitialHitpoints [+9Ch] instead when it uses them.
; Returns in ST0; preserves EBX, ESI, EDI and EBP.
OverhealBase PROC PRIVATE
    push esi
    mov esi, ecx                    ; database proto
    call OverhealUsesInitial
    test al, al
    je useMax
    fld dword ptr [esi+9Ch]
    jmp done
useMax:
    fld dword ptr [esi+98h]
done:
    pop esi
    ret
OverhealBase ENDP

; Replaces call 45F295h at 0x45FAAF in the unit visual update's bar chunk 0x45FAA2: the floating
; HP bar's fill, which 0x45FAB8 clamps to [0, 1] before 0x45FB71 queues the bar. ECX = ESI = the
; unit. A unit under construction takes the build fraction (0x6A1431) and does not come here.
UhcOverhealBarHook PROC
    TRACE_ONCE "overhealHitpointBars (0x45FAAF)"
    call OverhealRatio
    jmp barNext
UhcOverhealBarHook ENDP

; Replaces call 45F295h at 0x4C5014 in FUN_004C4FB5, which adds unit EBP (= ECX) to the selection
; group ESI: [esi+1Ch] keeps the group's average health, which the group bar (colour and fill,
; 0x4C82EA) and 'Group Health' (0x69AA75) show. EBX and EDI are popped at 0x4C501C.
UhcOverhealGroupHook PROC
    TRACE_ONCE "overhealHitpointBars (0x4C5014)"
    call OverhealRatio
    jmp groupNext
UhcOverhealGroupHook ENDP

; Replaces call 480408h at 0x698B35, the max of the selection panel's unitHitPointsValue text
; ('%d/%d', 0x698B63). ECX = EBX = the unit; the HP is already stored at [esp+88h].
UhcOverhealPanelMaxHook PROC
    TRACE_ONCE "overhealHitpointBars (0x698B35)"
    call OverhealReference
    jmp panelMaxNext
UhcOverhealPanelMaxHook ENDP

; Replaces mov eax,[ecx+0B4h] at 0x4D7575, the first instruction of the max HP getter inlined in
; the selection panel's 'Hit Points' stat row: 0x4D7575..0x4D75AC leaves the max in ST0 at
; 0x4D75AD, and every branch of it stays inside or rejoins there. ECX = EDI = the unit.
UhcOverhealStatMaxHook PROC
    TRACE_ONCE "overhealHitpointBars (0x4D7575)"
    call OverhealReference
    jmp statMaxNext
UhcOverhealStatMaxHook ENDP

; Replaces fld [eax+98h] at 0x4D7615, the same row's base (EAX = the database proto, not null):
; below the max, the row prints '%d/%d (%d+%d)' (0x69A9B0) with this base.
UhcOverhealStatBaseHook PROC
    TRACE_ONCE "overhealHitpointBars (0x4D7615)"
    mov ecx, eax
    call OverhealBase
    jmp statBaseNext
UhcOverhealStatBaseHook ENDP

; Replaces fld [ecx+98h] at 0x9AFA2A in FUN_009AF31A (the ObjectInfo_singleUnitStats panel), the
; base of its '%d/%d (%d+%d)' (0x9AFA8B). ECX = the database proto ([esp+30h], from 0x45316E).
UhcOverhealInfoBaseHook PROC
    TRACE_ONCE "overhealHitpointBars (0x9AFA2A)"
    call OverhealBase
    jmp infoBaseNext
UhcOverhealInfoBaseHook ENDP

; Replaces call 480408h at 0x9AFA4E, the same panel's max ('%d/%d' 0x9AFAA5, or the split).
; ECX = ESI = the unit.
UhcOverhealInfoMaxHook PROC
    TRACE_ONCE "overhealHitpointBars (0x9AFA4E)"
    call OverhealReference
    jmp infoMaxNext
UhcOverhealInfoMaxHook ENDP

END
