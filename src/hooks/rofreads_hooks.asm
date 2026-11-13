; The five reads of an attack's tactics ROF (rofreads.cpp), shared by containedUnitsROF and numberOfShots. Each is
; entered through a jmp written over the stock code and leaves through an explicit jmp to a verified continuation
; (docs/engine-symbols.md, "Rate of fire").
.686
.model flat, c
option casemap :none

include common.inc

UhcRofRead PROTO STDCALL :DWORD, :DWORD, :DWORD

EXTERNDEF g_uhcRofGate:DWORD        ; above 0 while a key has something to change; 0: the hooks skip the call

.data
waitA           dd 0048A826h    ; jbe 4A86C6h
waitB           dd 0048A99Fh    ; jbe 4B33D5h
waitC           dd 0048EA11h    ; jbe 4A857Fh
shotNext        dd 0048F8BAh    ; jbe 48F8BEh
animNext        dd 004A118Fh    ; test eax,eax (the override ROF [[esi+6Ch]+28h])

.code

; The three waits after an attack that did not fire (the attack update FUN_0048A330 and the attack step at
; 0x48E9DB), each `mov r,[r+34h] / test r,r` (5 bytes) before `jbe` and the delay call 0x48FA69(action
; manager, ms). The hook re-executes the read, passes the value through UhcRofRead and re-executes the test, so the
; jbe sees the stock flags. Nothing else changes: pushad/popad keep every other register.

; 0x48A821: EDI = the tactics action ([esi+4]), ESI = the unit action.
UhcRofWaitAHook PROC
    TRACE_ONCE "ROF read: wait (0x48A821)"
    mov edi, dword ptr [edi+34h]        ; stolen 0x48A821
    cmp g_uhcRofGate, 0
    je done
    pushad
    push 0                              ; RofRead::kNoShotA
    push edi
    push esi
    call UhcRofRead
    mov dword ptr [esp], eax            ; popad's EDI
    popad
done:
    test edi, edi                       ; stolen 0x48A824
    jmp waitA
UhcRofWaitAHook ENDP

; 0x48A99A: EDI = the tactics action ([esi+4]), ESI = the unit action.
UhcRofWaitBHook PROC
    TRACE_ONCE "ROF read: wait (0x48A99A)"
    mov edi, dword ptr [edi+34h]        ; stolen 0x48A99A
    cmp g_uhcRofGate, 0
    je done
    pushad
    push 1                              ; RofRead::kNoShotB
    push edi
    push esi
    call UhcRofRead
    mov dword ptr [esp], eax            ; popad's EDI
    popad
done:
    test edi, edi                       ; stolen 0x48A99D
    jmp waitB
UhcRofWaitBHook ENDP

; 0x48EA0C: ESI = the tactics action ([ebp+4]), EBP = the unit action.
UhcRofWaitCHook PROC
    TRACE_ONCE "ROF read: wait (0x48EA0C)"
    mov esi, dword ptr [esi+34h]        ; stolen 0x48EA0C
    cmp g_uhcRofGate, 0
    je done
    pushad
    push 2                              ; RofRead::kNoShotC
    push esi
    push ebp
    call UhcRofRead
    mov dword ptr [esp+4], eax          ; popad's ESI
    popad
done:
    test esi, esi                       ; stolen 0x48EA0F
    jmp waitC
UhcRofWaitCHook ENDP

; Replaces mov eax,[eax+34h] / cmp eax,ebx (5 bytes) at 0x48F8B5, the wait after a shot (ranged, through the
; launch 0x499422, and melee, through 0x4DCFE2, join at 0x48F892; [ebp+68h] was just incremented): EAX = the
; tactics action ([ebp+4]), EBP = the unit action, EBX = 0. The stock code then waits ROF minus the time since the
; attack began ([ebp+78h]) when that is smaller.
UhcRofShotHook PROC
    TRACE_ONCE "ROF read: after a shot (0x48F8B5)"
    mov eax, dword ptr [eax+34h]        ; stolen 0x48F8B5
    cmp g_uhcRofGate, 0
    je done
    pushad
    push 3                              ; RofRead::kAfterShot
    push eax
    push ebp
    call UhcRofRead
    mov dword ptr [esp+1Ch], eax        ; popad's EAX
    popad
done:
    cmp eax, ebx                        ; stolen 0x48F8B8
    jmp shotNext
UhcRofShotHook ENDP

; Replaces mov ebx,[eax+34h] / mov eax,[esi+6Ch] (6 bytes) at 0x4A1189, where an attack begins
; ([esi+78h] = now) and sets its animation rate [unit+0B0h] from the ROF: EAX = the tactics action ([esi+4]),
; ESI = the unit action. The flags are free: test eax,eax follows.
UhcRofAnimHook PROC
    TRACE_ONCE "ROF read: attack start (0x4A1189)"
    mov ebx, dword ptr [eax+34h]        ; stolen 0x4A1189
    cmp g_uhcRofGate, 0
    je done
    pushad
    push 4                              ; RofRead::kAttackStart
    push ebx
    push esi
    call UhcRofRead
    mov dword ptr [esp+10h], eax        ; popad's EBX
    popad
done:
    mov eax, dword ptr [esi+6Ch]        ; stolen 0x4A118C
    jmp animNext
UhcRofAnimHook ENDP

END
