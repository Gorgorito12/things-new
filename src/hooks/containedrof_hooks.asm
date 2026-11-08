; Hooks for containedUnitsROF (features/containedrof.cpp). Each is entered through a jmp written over the
; stock code and leaves through an explicit jmp to a verified continuation (docs/engine-symbols.md,
; "Garrison scaling").
.686
.model flat, c
option casemap :none

include common.inc

UhcContainedRofTag PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
UhcContainedRofScale PROTO STDCALL :DWORD, :DWORD

EXTERNDEF g_uhcContainedRofCount:DWORD     ; actions with target="ROF"; 0: the hooks skip the call

.data
tagStock        dd 005FEE14h    ; jne 5FE713h: the stock handler's test of the value
tagNext         dd 005FA126h    ; mov eax,[esp+1Ch]: the parser's next child
waitA           dd 0048A826h    ; jbe 4A86C6h
waitB           dd 0048A99Fh    ; jbe 4B33D5h
waitC           dd 0048EA11h    ; jbe 4A857Fh
shotNext        dd 0048F8BAh    ; jbe 48F8BEh
animNext        dd 004A118Fh    ; test eax,eax (the override ROF [[esi+6Ch]+28h])

.code

; Replaces cmp dword ptr [esp+10h],1 / mov eax,[ebp+64h] (8 bytes) at 0x5FEE0C, in the ScaleByContainedUnits
; handler of the action parser FUN_005F98A0, after the stock read of the text into [esp+10h] (0 when it is not a
; number). EDI = the tag's node, EBP = the action; the parser's arguments are at [esp+0C4h] (proto) and
; [esp+0C8h] (action), its return address at [esp+0C0h] (0x5FA213 a protoy <ProtoAction>, 0x5FA623 a tactics
; <action>; the frame of the action tag hook at 0x5FA11E, same depth). EAX and the flags are free at both
; continuations: the stock test sets them, and the next-child code overwrites them.
UhcContainedRofTagHook PROC
    TRACE_ONCE "containedUnitsROF tag (0x5FEE0C)"
    mov eax, dword ptr [esp+0C0h]
    cmp eax, 005FA213h
    je dispatch
    cmp eax, 005FA623h
    jne stock
dispatch:
    pushad
    push eax                            ; return address
    push dword ptr [esp+24h+10h]        ; the stock value
    push ebp                            ; action (the handler's own, also [esp+0C8h])
    push dword ptr [esp+2Ch+0C4h]       ; proto
    push edi                            ; the tag's node
    call UhcContainedRofTag
    mov dword ptr [esp+1Ch], eax        ; popad's EAX
    popad
    test eax, eax
    jne handled
stock:
    cmp dword ptr [esp+10h], 1          ; stolen 0x5FEE0C
    mov eax, dword ptr [ebp+64h]        ; stolen 0x5FEE11
    jmp tagStock
handled:
    jmp tagNext
UhcContainedRofTagHook ENDP

; The three waits after an attack that did not fire (the attack update FUN_0048A330 and the attack step at
; 0x48E9DB), each `mov r,[r+34h] / test r,r` (5 bytes) before `jbe` and the delay call 0x48FA69(action
; manager, ms). The hook re-executes the read, passes the value through UhcContainedRofScale and re-executes the
; test, so the jbe sees the stock flags. Nothing else changes: pushad/popad keep every other register.

; 0x48A821: EDI = the tactics action ([esi+4]), ESI = the unit action.
UhcContainedRofWaitAHook PROC
    TRACE_ONCE "containedUnitsROF wait (0x48A821)"
    mov edi, dword ptr [edi+34h]        ; stolen 0x48A821
    cmp g_uhcContainedRofCount, 0
    je done
    pushad
    push edi
    push esi
    call UhcContainedRofScale
    mov dword ptr [esp], eax            ; popad's EDI
    popad
done:
    test edi, edi                       ; stolen 0x48A824
    jmp waitA
UhcContainedRofWaitAHook ENDP

; 0x48A99A: EDI = the tactics action ([esi+4]), ESI = the unit action.
UhcContainedRofWaitBHook PROC
    TRACE_ONCE "containedUnitsROF wait (0x48A99A)"
    mov edi, dword ptr [edi+34h]        ; stolen 0x48A99A
    cmp g_uhcContainedRofCount, 0
    je done
    pushad
    push edi
    push esi
    call UhcContainedRofScale
    mov dword ptr [esp], eax            ; popad's EDI
    popad
done:
    test edi, edi                       ; stolen 0x48A99D
    jmp waitB
UhcContainedRofWaitBHook ENDP

; 0x48EA0C: ESI = the tactics action ([ebp+4]), EBP = the unit action.
UhcContainedRofWaitCHook PROC
    TRACE_ONCE "containedUnitsROF wait (0x48EA0C)"
    mov esi, dword ptr [esi+34h]        ; stolen 0x48EA0C
    cmp g_uhcContainedRofCount, 0
    je done
    pushad
    push esi
    push ebp
    call UhcContainedRofScale
    mov dword ptr [esp+4], eax          ; popad's ESI
    popad
done:
    test esi, esi                       ; stolen 0x48EA0F
    jmp waitC
UhcContainedRofWaitCHook ENDP

; Replaces mov eax,[eax+34h] / cmp eax,ebx (5 bytes) at 0x48F8B5, the wait after a shot (ranged, through the
; launch 0x499422, and melee, through 0x4DCFE2, join at 0x48F892): EAX = the tactics action ([ebp+4]), EBP = the
; unit action, EBX = 0. The stock code then waits ROF minus the time since the attack began ([ebp+78h]).
UhcContainedRofShotHook PROC
    TRACE_ONCE "containedUnitsROF shot (0x48F8B5)"
    mov eax, dword ptr [eax+34h]        ; stolen 0x48F8B5
    cmp g_uhcContainedRofCount, 0
    je done
    pushad
    push eax
    push ebp
    call UhcContainedRofScale
    mov dword ptr [esp+1Ch], eax        ; popad's EAX
    popad
done:
    cmp eax, ebx                        ; stolen 0x48F8B8
    jmp shotNext
UhcContainedRofShotHook ENDP

; Replaces mov ebx,[eax+34h] / mov eax,[esi+6Ch] (6 bytes) at 0x4A1189, where an attack begins
; ([esi+78h] = now) and sets its animation rate [unit+0B0h] from the ROF: EAX = the tactics action ([esi+4]),
; ESI = the unit action. The flags are free: test eax,eax follows.
UhcContainedRofAnimHook PROC
    TRACE_ONCE "containedUnitsROF attack start (0x4A1189)"
    mov ebx, dword ptr [eax+34h]        ; stolen 0x4A1189
    cmp g_uhcContainedRofCount, 0
    je done
    pushad
    push ebx
    push esi
    call UhcContainedRofScale
    mov dword ptr [esp+10h], eax        ; popad's EBX
    popad
done:
    mov eax, dword ptr [esi+6Ch]        ; stolen 0x4A118C
    jmp animNext
UhcContainedRofAnimHook ENDP

END
