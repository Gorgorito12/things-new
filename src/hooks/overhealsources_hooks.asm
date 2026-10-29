; Hooks for overhealSources (and the add-HP hook overhealDecay shares). Entered through a jmp
; written over the stock code; each leaves through an explicit jmp to a verified continuation
; (docs/engine-symbols.md, "Unit types and healing").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcOverhealAllow:SDWORD   ; 1 while a source healer's heal tick adds HP
EXTERNDEF g_uhcOverhealRegen:SDWORD   ; 1 while a regeneration adds HP (overhealDecay)

UhcOverhealAddHp PROTO STDCALL unit:DWORD, amount:DWORD         ; may lower [amount]
UhcOverhealUseReference PROTO STDCALL target:DWORD, healer:DWORD  ; AL: a normal healer, a marked target
UhcOverhealIsSource PROTO STDCALL healer:DWORD                   ; AL: the healer gives overheal
UhcOverhealPowerLimit PROTO C unit:DWORD                          ; ST0: the power heal's limit
UhcOverhealReferenceOf PROTO C unit:DWORD                         ; ST0 (overheal_hooks.asm)
UhcOverhealRatioOf PROTO C unit:DWORD                             ; ST0 (overheal_hooks.asm)

.data
addHpNext       dd 004823ABh    ; jbe 4823FEh: the adder after its stolen cmp [esi+8],8
addHp           dd 004823A3h    ; thiscall(unit, amount, flag), ret 8: HP += amount (our hook first)
maxHitpoints    dd 00480408h    ; float thiscall(unit): the stock max
healthRatio     dd 0045F295h    ; float thiscall(unit): the stock HP / max
tickMaxNext     dd 009E0BC0h    ; fcomp [edi+64h] / fnstsw / test ah,41h / jnp 9E0D3Fh: HP < max?
tickAddNext     dd 009E0CEEh    ; fld [esp+10h] / fadd [esi+68h]: the tick's bookkeeping
searchRatioNext dd 009CD989h    ; fcomp 1.0 / fnstsw / test ah,1 / je 9CDA3Fh: ratio < 1?
regenNext       dd 00490886h    ; mov ecx,[esp+1Ch] / add ecx,1: the regeneration loop
danceRegenNext  dd 0067A040h    ; add ebp,1 / cmp ebp,ebx / jl: the Regeneration dance loop
powerCompareNext dd 009E0377h   ; fcomp [esp+18h]: the power heal's limit vs HP + amount
powerRoomNext   dd 009E0390h    ; fsub [esp+1Ch]: the power heal's limit - HP

.code

; Replaces push ecx / push esi / mov esi,ecx / cmp dword ptr [esi+8],8 (8 bytes) at the entry of
; the add-HP function FUN_004823A3 (ECX = unit, [esp+4] = amount, [esp+8] = flag). Every heal
; and every damage that goes through it passes here first: UhcOverhealAddHp may lower a positive
; amount (the cap) and notes a unit that goes above its reference (overhealDecay). Then the
; stolen instructions run as they were; jbe at 0x4823AB reads the flags of the stolen cmp.
UhcOverhealAddHook PROC
    TRACE_ONCE "overheal add HP (0x4823A3)"
    pushad
    lea eax, dword ptr [esp+24h]    ; &amount: [esp+4] at entry, +20h for pushad
    push eax
    push ecx                        ; unit
    call UhcOverhealAddHp
    popad
    push ecx                        ; stolen 0x4823A3
    push esi                        ; stolen 0x4823A4
    mov esi, ecx                    ; stolen 0x4823A5
    cmp dword ptr [esi+8], 8        ; stolen 0x4823A7
    jmp addHpNext
UhcOverhealAddHook ENDP

; Replaces call 480408h at 0x9E0BBB in the heal tick FUN_009E0B53 (ECX = EDI = target, ESI = the
; heal action, healer at [esi+10h]): each tick heals only while HP < this value, and ends the
; action (state 10) otherwise. For a healer that gives no overheal and a marked target the value
; is the target's reference, so the action ends there; else the stock max. The FPU stack is empty
; at the site; ECX and EDX are written again after 0x9E0BC0 before they are read.
UhcOverhealTickMaxHook PROC
    TRACE_ONCE "overhealSources heal tick (0x9E0BBB)"
    push dword ptr [esi+10h]        ; healer
    push edi                        ; target
    call UhcOverhealUseReference
    test al, al
    jne useReference
    mov ecx, edi
    call maxHitpoints               ; stolen 0x9E0BBB
    jmp tickMaxNext
useReference:
    push edi
    call UhcOverhealReferenceOf
    add esp, 4
    jmp tickMaxNext
UhcOverhealTickMaxHook ENDP

; Replaces call 4823A3h at 0x9E0CE9, where the heal tick adds this tick's HP to the target (ECX =
; EDI = target, the amount and 1 pushed, ESI = the action). A source healer's heal is let through
; above the reference: g_uhcOverhealAllow is set for the call and cleared after it.
UhcOverhealTickAddHook PROC
    TRACE_ONCE "overhealSources heal (0x9E0CE9)"
    push ecx
    push dword ptr [esi+10h]        ; healer
    call UhcOverhealIsSource
    pop ecx
    movzx eax, al
    mov g_uhcOverhealAllow, eax
    call addHp                      ; stolen 0x9E0CE9
    mov g_uhcOverhealAllow, 0
    jmp tickAddNext
UhcOverhealTickAddHook ENDP

; Replaces the first call 45F295h at 0x9CD984 in the automatic heal search FUN_009CD865 (ECX =
; ESI = candidate, healer at [ebp+4]), whose result must be below 1.0 for the candidate to count.
; For a healer that gives no overheal and a marked candidate it is HP / reference, so a unit at
; its reference is no candidate; else the stock ratio. The second ratio call (the 1e-6 floor) is
; stock.
UhcOverhealSearchRatioHook PROC
    TRACE_ONCE "overhealSources heal search (0x9CD984)"
    push dword ptr [ebp+4]          ; healer
    push esi                        ; candidate
    call UhcOverhealUseReference
    test al, al
    jne useReference
    mov ecx, esi
    call healthRatio                ; stolen 0x9CD984
    jmp searchRatioNext
useReference:
    push esi
    call UhcOverhealRatioOf
    add esp, 4
    jmp searchRatioNext
UhcOverhealSearchRatioHook ENDP

; Replace call 480408h at 0x9E0372 and 0x9E038B in the power heal tick FUN_009E0280 (PowerHeal;
; ECX = EDI = the target, FPU stack empty): the tick clamps each unit's amount to this limit - HP
; and adds the unclamped part of the tick to the power's budget [esi+68h] after the add, so a
; marked unit at its reference would take 0 HP from the cap but still spend budget. ST0 =
; UhcOverhealPowerLimit(unit): max(reference, HP) for a marked unit, the stock max otherwise.
; EAX, ECX, EDX and the flags are written again after both continuations before they are read.
UhcOverhealPowerCompareHook PROC
    TRACE_ONCE "overhealSources power heal (0x9E0372)"
    push edi
    call UhcOverhealPowerLimit
    add esp, 4
    jmp powerCompareNext
UhcOverhealPowerCompareHook ENDP

UhcOverhealPowerRoomHook PROC
    TRACE_ONCE "overhealSources power heal (0x9E038B)"
    push edi
    call UhcOverhealPowerLimit
    add esp, 4
    jmp powerRoomNext
UhcOverhealPowerRoomHook ENDP

; overhealDecay: replace call 4823A3h at 0x490881 (the unit's own regeneration, FUN_004905E1) and
; at 0x67A03B (the Regeneration dance), with the amount and 1 pushed and ECX = ESI = the unit:
; g_uhcOverhealRegen is set around the call, so these gains do not restart the decay's delay.
; Only memory writes are added; registers and flags are as after the stock call.
UhcOverhealRegenAddHook PROC
    TRACE_ONCE "overhealDecay regeneration (0x490881)"
    mov g_uhcOverhealRegen, 1
    call addHp                      ; stolen 0x490881
    mov g_uhcOverhealRegen, 0
    jmp regenNext
UhcOverhealRegenAddHook ENDP

UhcOverhealDanceRegenAddHook PROC
    TRACE_ONCE "overhealDecay Regeneration dance (0x67A03B)"
    mov g_uhcOverhealRegen, 1
    call addHp                      ; stolen 0x67A03B
    mov g_uhcOverhealRegen, 0
    jmp danceRegenNext
UhcOverhealDanceRegenAddHook ENDP

END
