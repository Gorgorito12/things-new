; Hooks for resourceDebt. Entered through a jmp written over the stock code; each leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Resource debt").
.686
.model flat, c
option casemap :none

include common.inc

EXTERN g_uhcDebtResources:BYTE
UhcDebtFloor PROTO STDCALL player:DWORD, resource:DWORD, value:DWORD, caller:DWORD

.data
addNext       dd 0049A9D0h    ; mov ecx,[esp+18h]: the add goes on to the set
setNext       dd 0049A8E3h    ; mov edi,[esp+70h]: the set goes on
shareNext     dd 006799DCh    ; mov ecx,[esp+20h]: the shared add goes on to the set
autoGo        dd 004C0F1Fh    ; mov ecx,[esi+4]: the AutoGather update books the amount
autoSkip      dd 0048D18Ch    ; the AutoGather update's next resource
rateGo        dd 004C0A34h    ; cmp dword ptr [edi],0: the getter returns the rate it computed
rateZero      dd 0049EE0Dh    ; fld 0: the getter returns 0
gatherGo      dd 004ED044h    ; fmul [esp+30h]: the gather tick goes on
gatherEnd     dd 006A8AEAh    ; the gather tick ends the action

.code

; Replaces 0x679A0E (mov dword ptr [esp+10h],0), the clamp of the add 0x49A98A, reached when the sum
; is below 1e-6. EBP = the player, ESI = the resource; [esp+0Ch] the add's return address, [esp+10h]
; the sum. EAX is free: the continuation reloads it. FPU stack empty.
UhcDebtAddHook PROC
    TRACE_ONCE "resourceDebt add (0x679A0E)"
    cmp esi, 16
    jae clamp
    cmp byte ptr g_uhcDebtResources[esi], 0
    je clamp
    lea eax, dword ptr [esp+10h]
    pushad
    push dword ptr [eax-4]
    push eax
    push esi
    push ebp
    call UhcDebtFloor
    popad
    jmp addNext
clamp:
    mov dword ptr [esp+10h], 0      ; stolen 0x679A0E
    jmp addNext
UhcDebtAddHook ENDP

; Replaces 0x6798F4 (mov dword ptr [esp+74h],0), the clamp of the set 0x49A8C5. ESI = the player,
; [esp+6Ch] the set's return address, [esp+70h] the resource, [esp+74h] the value. A value from the
; add's own two calls (returns 0x49A9E2 and 0x6799EE) was settled by the two hooks of the add. EAX is
; free: the continuation writes it before reading it. FPU stack empty.
UhcDebtSetHook PROC
    TRACE_ONCE "resourceDebt set (0x6798F4)"
    mov eax, dword ptr [esp+70h]
    cmp eax, 16
    jae clamp
    cmp byte ptr g_uhcDebtResources[eax], 0
    je clamp
    cmp dword ptr [esp+6Ch], 0049A9E2h
    je settled
    cmp dword ptr [esp+6Ch], 006799EEh
    je settled
    lea ecx, dword ptr [esp+74h]
    pushad
    push dword ptr [ecx-8]
    push ecx
    push eax
    push esi
    call UhcDebtFloor
    popad
settled:
    jmp setNext
clamp:
    mov dword ptr [esp+74h], 0      ; stolen 0x6798F4
    jmp setNext
UhcDebtSetHook ENDP

; Replaces 0x6799D4 (mov dword ptr [esp+18h],0), the clamp of the add's shared-resources path, once
; per teammate. EDI = the teammate, EBP = the resource; [esp+14h] the add's return address, [esp+18h]
; the sum. EAX is free: the continuation does not read it. FPU stack empty.
UhcDebtShareHook PROC
    TRACE_ONCE "resourceDebt shared add (0x6799D4)"
    cmp ebp, 16
    jae clamp
    cmp byte ptr g_uhcDebtResources[ebp], 0
    je clamp
    lea eax, dword ptr [esp+18h]
    pushad
    push dword ptr [eax-4]
    push eax
    push ebp
    push edi
    call UhcDebtFloor
    popad
    jmp shareNext
clamp:
    mov dword ptr [esp+18h], 0      ; stolen 0x6799D4
    jmp shareNext
UhcDebtShareHook ENDP

; Replaces 0x48D186 (jp 0x4C0F1F), in the AutoGather update: stock books an amount of 1e-6 or more
; (the flags come from its test) and skips the rest. Here a negative amount of a listed resource is
; booked too. EBX = the resource, [esp+10h] the amount.
UhcDebtAutoGateHook PROC
    jp book
    TRACE_ONCE "resourceDebt AutoGather gate (0x48D186)"
    cmp ebx, 16
    jae skip
    cmp byte ptr g_uhcDebtResources[ebx], 0
    je skip
    test dword ptr [esp+10h], 80000000h
    je skip
book:
    jmp autoGo
skip:
    jmp autoSkip
UhcDebtAutoGateHook ENDP

; Replaces 0x49EE07 (jp 0x4C0A34), at the end of the AutoGather rate getter 0x49EBE4: stock returns a
; rate of 1e-6 or more (the flags come from its test) and 0 for the rest. Here a negative rate of a
; listed resource is returned too. EBX = the resource, [esp+14h] the rate.
UhcDebtAutoRateHook PROC
    jp keep
    TRACE_ONCE "resourceDebt AutoGather rate (0x49EE07)"
    cmp ebx, 16
    jae zero
    cmp byte ptr g_uhcDebtResources[ebx], 0
    je zero
    test dword ptr [esp+14h], 80000000h
    je zero
keep:
    jmp rateGo
zero:
    jmp rateZero
UhcDebtAutoRateHook ENDP

; Replaces 0x4ED03E (jnp 0x6A8AEA), in the gather tick: stock ends the action at a rate of 1e-6 or
; less (the flags come from its test). Here a negative rate of a listed resource goes on. ST0 = the
; rate, kept; [esi+70h] the resource. EAX is free: fnstsw just wrote it.
UhcDebtGatherGateHook PROC
    jnp small
    jmp gatherGo
small:
    TRACE_ONCE "resourceDebt gather gate (0x4ED03E)"
    mov eax, dword ptr [esi+70h]
    cmp eax, 16
    jae stop
    cmp byte ptr g_uhcDebtResources[eax], 0
    je stop
    ftst
    fnstsw ax
    test ah, 1                      ; below 0?
    je stop
    jmp gatherGo
stop:
    jmp gatherEnd
UhcDebtGatherGateHook ENDP

END
