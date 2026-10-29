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
EXTERNDEF g_uhcOverhealTextColor:SDWORD  ; 1 with "segment": an HP text above its 100 % is coloured
EXTERNDEF g_uhcOverhealFmtPlain:WORD     ; '<color=r, g, b>%d/%d</color>'
EXTERNDEF g_uhcOverhealFmtSplit:WORD     ; '<color=r, g, b>%d/%d (%d+%d)</color>'

UhcOverhealLogReference PROTO STDCALL unit:DWORD, reference:DWORD, maxHp:DWORD
UhcOverhealQueueSegment PROTO STDCALL unit:DWORD, pos:DWORD, reference:DWORD
UhcOverhealSegmentFit PROTO STDCALL world:DWORD
UhcOverhealSegmentVertices PROTO STDCALL world:DWORD, recordOffset:DWORD, vertices:DWORD, camera:DWORD
UhcOverhealPortrait PROTO STDCALL panel:DWORD, selGroup:DWORD
UhcOverhealStatRow PROTO STDCALL panel:DWORD, unit:DWORD, row:DWORD

SEGMENT_PLAYER EQU 804F5648h            ; the player ID of a segment record ('OVH', negative: no player colour)

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
barQueueExit    dd 004516B3h    ; where the bar chunk goes after queueing the bar (jmp at 0x45FB6C)
renderCountNext dd 0045C4BFh    ; test ebx,ebx / mov [esp+3Ch],ebx / jle: the renderer's record count
vertexLoopNext  dd 0045CB78h    ; add edi,24h / add ebx,24h / cmp eax,[ebp+8D4h]: the next record
textStatNext    dd 004D7656h    ; push eax / call 444EFBh: the stat row's '%d/%d'
textStatSplitNext dd 0069A9C5h  ; push ecx / call 444EFBh: the stat row's '%d/%d (%d+%d)'
bstringFree     dd 004010CAh    ; void thiscall(BString*): the free 0x4C83E3 calls
portraitNext    dd 004C83E8h    ; mov ecx,[esp+1C4h] / call 4C83F6h: after the portrait bar
statRowNext     dd 004D76E4h    ; mov edx,[0CF059Ch]: the rows after the HP row

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

; Replaces jmp 4516B3h at 0x45FB6C, right after the floating bar of unit ESI was queued (0x45FB67):
; with "segment", a unit above its 100 % gets a second record, the overheal segment, which the
; renderer hooks below draw over the right end of the bar. [esp+18h] = the bar's position (the
; record copies it), [esp+15h] = under construction (that bar is the build progress). The FPU
; stack is empty here and every register is kept for 0x4516B3.
UhcOverhealSegmentQueueHook PROC
    TRACE_ONCE "overhealHitpointBars segment queue (0x45FB6C)"
    cmp byte ptr [esp+15h], 0
    jne done
    pushad
    mov ecx, esi
    call OverhealReference          ; ST0 = the unit's 100 % (its max when not marked)
    sub esp, 4
    fstp dword ptr [esp]            ; reference
    lea eax, [esp+3Ch]              ; the position: [esp+18h] at entry, +20h pushad, +4 reference
    push eax
    push esi                        ; unit
    call UhcOverhealQueueSegment    ; queues the segment when HP > reference
    popad
done:
    jmp barQueueExit
UhcOverhealSegmentQueueHook ENDP

; Replaces mov ebx,[ebp+8D4h] at 0x45C4B9 in the bar renderer FUN_0045C4AF (EBP = world): before
; the vertex lock, UhcOverhealSegmentFit drops the segment records when the queue would not fit
; in the dynamic vertex buffer, so they never cost a stock bar; then the stolen load of the count.
UhcOverhealSegmentRenderHook PROC
    TRACE_ONCE "overhealHitpointBars segment fit (0x45C4B9)"
    pushad
    push ebp
    call UhcOverhealSegmentFit
    popad
    mov ebx, dword ptr [ebp+8D4h]   ; stolen 0x45C4B9
    jmp renderCountNext
UhcOverhealSegmentRenderHook ENDP

; Replaces add eax,1 / add ecx,1Ch at 0x45CB72, the end of the renderer's per-record loop: ECX =
; the record's offset in [ebp+8D0h], EDI = its sixth vertex, ESI = the camera. The six vertices of
; a segment record are rewritten (UhcOverhealSegmentVertices); every other record is left as the
; stock loop wrote it. The FPU stack is empty here (checked over one iteration); the flags are
; set again by the stolen adds.
UhcOverhealSegmentVertexHook PROC
    TRACE_ONCE "overhealHitpointBars segment vertices (0x45CB72)"
    push edx
    mov edx, dword ptr [ebp+8D0h]
    cmp dword ptr [edx+ecx+14h], SEGMENT_PLAYER
    pop edx
    jne done
    pushad
    push esi                        ; camera
    lea eax, [edi-0B4h]             ; the first vertex, five 24h-byte vertices back
    push eax
    push ecx                        ; the record's offset
    push ebp                        ; world
    call UhcOverhealSegmentVertices
    popad
done:
    add eax, 1                      ; stolen 0x45CB72
    add ecx, 1Ch                    ; stolen 0x45CB75
    jmp vertexLoopNext
UhcOverhealSegmentVertexHook ENDP

; Replaces a push of an HP text's format (5 bytes) right after the HP ([esp]) and the 100 % value
; ([esp+4]) were pushed: with "segment", an HP above it gets the coloured copy of the format. Only
; the flags change (the next instruction does not read them); stock HP never exceeds the max, so
; an unmarked unit always gets the stock format. Only the stat row's two formats are hooked: its
; gadget draws the <color> markup (seen in game). The minimized UI's unitHitPointsValue (0x698B63)
; formats the same way, but its gadget prints the markup as text (seen in game), so it stays white;
; ObjectInfo (0x9AFA8B, 0x9AFAA5), an editor panel, is not hooked either.
OVERHEAL_TEXT_HOOK MACRO hookName:REQ, traceText:REQ, stockFormat:REQ, colourFormat:REQ, nextAddress:REQ
hookName PROC
    TRACE_ONCE traceText
    push stockFormat
    cmp g_uhcOverhealTextColor, 0
    je @F
    push eax
    mov eax, dword ptr [esp+8]      ; HP
    cmp eax, dword ptr [esp+0Ch]    ; the 100 % value
    pop eax
    jle @F
    mov dword ptr [esp], OFFSET colourFormat
@@:
    jmp nextAddress
hookName ENDP
ENDM

OVERHEAL_TEXT_HOOK UhcOverhealTextStatHook, "overhealHitpointBars text (0x4D7651)", 0BA2054h, g_uhcOverhealFmtPlain, textStatNext
OVERHEAL_TEXT_HOOK UhcOverhealTextStatSplitHook, "overhealHitpointBars text (0x69A9C0)", 0C34A54h, g_uhcOverhealFmtSplit, textStatSplitNext

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

; Replaces lea ecx,[esp+70h] / call 4010CAh (9 bytes) at 0x4C83DF, the end of the selection
; panel's portrait bar: the colour gadget was filled and raised. [esp+50h] = the panel, [esp+78h] =
; the group, at the stack level of 0x4C82E6. UhcOverhealPortrait fills and raises the UI data's
; overheal gadget, if any; then the stolen free. The FPU stack is empty (the fcomp pairs at
; 0x4C82F5 / 0x4C830A pop what they load); EAX, ECX, EDX and the flags are dead after the free.
UhcOverhealPortraitHook PROC
    TRACE_ONCE "overhealHitpointBars portrait bar (0x4C83DF)"
    pushad
    push dword ptr [esp+20h+78h]    ; group
    push dword ptr [esp+24h+50h]    ; panel
    call UhcOverhealPortrait
    popad
    lea ecx, [esp+70h]              ; stolen 0x4C83DF
    call bstringFree                ; stolen 0x4C83E3: call 4010CAh
    jmp portraitNext
UhcOverhealPortraitHook ENDP

; Replaces mov edi,2 / mov [esp+2Ch],edi (9 bytes) at 0x4D76DB, the stat panel fill right after
; the HP row: EDI and [esp+2Ch] are the next free row (the Group Health branch 0x69A9D3 writes row
; EDI, then adds 1 to both). UhcOverhealStatRow writes the overheal row there for a marked unit
; ([esp+38h], the panel [esp+50h]); when it did, the row is counted the same way. EAX, ECX, EDX
; and the flags are dead at 0x4D76E4 (mov edx,[0CF059Ch] / mov eax,[edx] / ... / mov ecx,0C66500h).
UhcOverhealStatRowHook PROC
    TRACE_ONCE "overhealHitpointBars stat row (0x4D76DB)"
    mov edi, 2                      ; stolen 0x4D76DB
    mov dword ptr [esp+2Ch], edi    ; stolen 0x4D76E0
    pushad
    push edi                        ; row
    push dword ptr [esp+24h+38h]    ; unit
    push dword ptr [esp+28h+50h]    ; panel
    call UhcOverhealStatRow
    mov dword ptr [esp+1Ch], eax    ; the pushad slot of EAX: the result survives popad
    popad
    test al, al
    jz done
    add edi, 1
    mov dword ptr [esp+2Ch], edi
done:
    jmp statRowNext
UhcOverhealStatRowHook ENDP

; Public forms of the reference helpers for the other overheal keys (overhealSources,
; overhealDecay), cdecl so the C++ side can call them: the same definition, not a copy.
; float UhcOverhealReferenceOf(unit): the 100 % reference in ST0 (the stock max for an unmarked unit).
UhcOverhealReferenceOf PROC
    mov ecx, dword ptr [esp+4]
    jmp OverhealReference
UhcOverhealReferenceOf ENDP

; float UhcOverhealRatioOf(unit): HP / reference with the stock rules of 0x45F295, in ST0.
UhcOverhealRatioOf PROC
    mov ecx, dword ptr [esp+4]
    jmp OverhealRatio
UhcOverhealRatioOf ENDP

; int UhcOverhealMarked(proto): 1 if the proto is of a configured type and 1e-6 <
; InitialHitpoints < MaxHitpoints (a unit of it has a reference below its max), else 0.
UhcOverhealMarked PROC
    mov ecx, dword ptr [esp+4]
    call OverhealUsesInitial
    movzx eax, al
    ret
UhcOverhealMarked ENDP

END
