; Hooks for lifespanAfterConstruction. Entered through a jmp written over the stock code; each
; leaves through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Lifespan
; and construction").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcLifespanType:SDWORD       ; marker unittype ID, set on each database load; -1 before
EXTERNDEF g_uhcLifespanLog:SDWORD        ; 1 with "lifespanAfterConstruction ... log"
EXTERNDEF g_uhcLifespanHeldCount:SDWORD  ; logged held units not yet running again (log only)

UhcLifespanHeld PROTO STDCALL unit:DWORD
UhcLifespanTicking PROTO STDCALL unit:DWORD
UhcLifespanFadeHeld PROTO STDCALL unit:DWORD

.data
isBuilt         dd 0044DDB4h    ; bool thiscall(unit): no BuildInfo [unit+68h], or percent [+8] >= 1.0
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): proto IDs and abstract types
tickNext        dd 00483EF6h    ; fnstsw ax / test ah,41h / jne 482C20h (dt <= 0: no countdown)
tickReturn      dd 00482C20h    ; pop esi / pop ecx / ret 4: the lifespan tick's exit
fadeCommit      dd 00482A20h    ; mov [eax+88h],ecx: store the fade timer t
fadeSkip        dd 00482A26h    ; cmp dword ptr [esi+8],3Dh: the fade branches, timer not stored

.code

; Replaces 0x483EEC..0x483EF5 (fld dword ptr [esp+0Ch] / fcomp dword ptr [0B84BE4h], dt against
; 0), the start of the cold part of the lifespan tick FUN_00482BF6, which only runs for a unit
; whose lifespan is armed (state bit 3). ESI = unit; [esp] = saved ESI, [esp+4] = local,
; [esp+8] = return address, [esp+0Ch] = dt. EAX, ECX and EDX are free (the stock code writes
; them before it reads them); EBX, EDI and EBP are the caller's. A unit that is alive (state
; bit 11 clear, the test the stock expiry makes), not fully built and of the marker type leaves
; through the stock exit 0x482C20, the one taken for dt <= 0: no countdown, no expiry. Any other
; unit re-executes the two instructions and continues at 0x483EF6.
UhcLifespanTickHook PROC
    TRACE_ONCE "lifespanAfterConstruction (0x483EEC)"
    cmp g_uhcLifespanType, 0
    jl stock
    cmp dword ptr [esi+8], 0Bh      ; bit count of the unit state [esi+4]
    jbe alive
    mov ecx, dword ptr [esi+4]
    test byte ptr [ecx+1], 08h      ; bit 11: dead or dying, the expiry only removes the corpse
    jne ticking
alive:
    mov ecx, esi
    call isBuilt                    ; changes EAX only
    test al, al
    jne ticking
    mov ecx, dword ptr [esi+5Ch]    ; proto
    test ecx, ecx
    je ticking
    push g_uhcLifespanType
    call protoIsType
    test al, al
    je ticking
    cmp g_uhcLifespanLog, 0
    je hold
    pushad
    push esi
    call UhcLifespanHeld
    popad
hold:
    jmp tickReturn
ticking:
    cmp g_uhcLifespanHeldCount, 0
    je stock
    pushad
    push esi
    call UhcLifespanTicking         ; logs a held unit whose countdown runs again
    popad
stock:
    fld dword ptr [esp+0Ch]         ; stolen 0x483EEC: dt
    fcomp dword ptr ds:[0B84BE4h]   ; stolen 0x483EF0: against 0.0
    jmp tickNext
UhcLifespanTickHook ENDP

; Replaces 0x482A1A..0x482A1F (jne 482A26h / mov ecx,[esp+10h]) in the fade update FUN_004829FA,
; which runs for every unit on every step. t = [sub+88h] - dt is in [esp+10h], and 0x482A20
; stores it when the commit flag is set (the flags of cmp bl,1 at 0x482A00). EAX = the unit's
; sub-object [esi+0B4h], ESI = unit, EBX = commit flag; [esp] = saved ESI, [esp+4] = saved EBX,
; [esp+8] = local, [esp+0Ch] = return address, [esp+10h] = t, [esp+14h] = commit. ECX and EDX
; are reloaded at 0x482A2A and 0x482A30. A unit whose pending fade is the lifespan fade-out
; (state bits 5 and 3 set; bits 4 and 61, whose fades take priority with the same timer, clear),
; alive (bit 11 clear: a corpse's fade is the same bit 5), not fully built and of the marker type
; keeps its stored timer, and this step sees that value as t: the fade-out neither advances nor
; starts. Every other unit runs the stock code.
UhcLifespanFadeHook PROC
    TRACE_ONCE "lifespanAfterConstruction fade (0x482A1A)"
    jne skip                        ; stolen 0x482A1A: no commit asked
    cmp g_uhcLifespanType, 0
    jl commit
    mov edx, dword ptr [esi+8]      ; bit count of the unit state
    cmp edx, 5
    jbe commit
    mov ecx, dword ptr [esi+4]      ; unit state bits
    test byte ptr [ecx], 20h        ; bit 5: fade-out pending
    je commit
    test byte ptr [ecx], 10h        ; bit 4: a fade-in, which takes priority
    jne commit
    test byte ptr [ecx], 08h        ; bit 3: the lifespan is armed
    je commit
    cmp edx, 0Bh
    jbe alive
    test byte ptr [ecx+1], 08h      ; bit 11: dead or dying
    jne commit
    cmp edx, 3Dh
    jbe alive
    test byte ptr [ecx+7], 20h      ; bit 61: another fade, which takes priority
    jne commit
alive:
    push eax                        ; the sub-object, needed by the stock store
    mov ecx, esi
    call isBuilt
    test al, al
    jne notHeld
    mov ecx, dword ptr [esi+5Ch]    ; proto
    test ecx, ecx
    je notHeld
    push g_uhcLifespanType
    call protoIsType
    test al, al
    je notHeld
    cmp g_uhcLifespanLog, 0
    je hold
    pushad
    push esi
    call UhcLifespanFadeHeld
    popad
hold:
    pop eax
    mov ecx, dword ptr [eax+88h]    ; the stored timer: no time passes for this fade-out
    mov dword ptr [esp+10h], ecx
    jmp fadeSkip
notHeld:
    pop eax
commit:
    mov ecx, dword ptr [esp+10h]    ; stolen 0x482A1C
    jmp fadeCommit
skip:
    jmp fadeSkip
UhcLifespanFadeHook ENDP

END
