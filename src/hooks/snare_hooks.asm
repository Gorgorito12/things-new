; Hooks for snareOnlyHitUnit. Entered through a jmp written over the stock code; each leaves
; through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Snare and group
; movement").
.686
.model flat, c
option casemap :none

include common.inc

UhcSnareGroupPace PROTO STDCALL member:DWORD, grp:DWORD
UhcSnareSkipsWait PROTO STDCALL member:DWORD, site:DWORD
UhcSnareSkipsWaitById PROTO STDCALL memberId:DWORD

.data
paceNext        dd 004FD417h    ; mov ecx,[edi+5Ch]: the rest of the member loop body
paceStore       dd 004FD53Ah    ; stock: call the member's vtbl[34h] again, fstp [esi+7Ch], jmp 4FD417h
slotWaitNext    dd 004FA183h    ; fld dword ptr [esp+18h]: the member step goes on
pathWaitNext    dd 006AA51Ah    ; mov eax,[esi+10h]: the member's slot distance check
pathCheckNext   dd 006AA570h    ; jmp 4F9F99h: the next member

.code

; Replaces 0x4FD3FD..0x4FD416 in FUN_004FD289 (group recompute): the member's max velocity
; (vtbl[34h]) compared with the group's pace [esi+7Ch], stored by 0x4FD53A when it is lower.
; ESI = group, EDI = member, EBP/EBX = loop index/count, FPU stack empty. EAX, ECX, EDX and the
; flags are dead on both continuations. A member with an active snare is handled by the helper
; (its velocity without the snare); any other member runs the stock compare unchanged.
UhcSnareGroupPaceHook PROC
    TRACE_ONCE "snareOnlyHitUnit (0x4FD3FD)"
    push esi
    push edi
    call UhcSnareGroupPace          ; -> al = 1: the helper did the compare and the store
    test al, al
    jne done
    mov edx, dword ptr [edi]        ; stolen 0x4FD3FD
    mov ecx, edi                    ; stolen 0x4FD3FF
    mov eax, dword ptr [edx+34h]    ; stolen 0x4FD401
    call eax                        ; stolen 0x4FD404: call 4A974Ah, which is jmp eax
    fcomp dword ptr [esi+7Ch]       ; stolen 0x4FD409
    fnstsw ax                       ; stolen 0x4FD40C
    test ah, 5                      ; stolen 0x4FD40E
    jnp store                       ; stolen 0x4FD411: jnp 4FD53Ah (velocity < pace)
done:
    jmp paceNext
store:
    jmp paceStore
UhcSnareGroupPaceHook ENDP

; Replaces 0x4FA17D..0x4FA182 (mov eax,[esi+4] / or byte ptr [eax],80h) in the member step
; FUN_004FA03B, reached when the member is farther from its formation slot than 0x4F9B69 allows:
; group bit 7 makes the group move at 0.8333x its pace (0x4FAAA5). ESI = group, EBP = member,
; FPU stack empty. EAX and the flags are dead at 0x4FA183; ECX and EDX are kept anyway.
UhcSnareSlotWaitHook PROC
    TRACE_ONCE "snareOnlyHitUnit (0x4FA17D)"
    push ecx
    push edx
    push 004FA17Dh
    push ebp
    call UhcSnareSkipsWait          ; -> al = 1: snared member, the group does not wait
    pop edx
    pop ecx
    test al, al
    jne skip
    mov eax, dword ptr [esi+4]      ; stolen 0x4FA17D
    or byte ptr [eax], 80h          ; stolen 0x4FA180
skip:
    jmp slotWaitNext
UhcSnareSlotWaitHook ENDP

; Replaces 0x6AA514..0x6AA519 (mov eax,[ebx+4] / or byte ptr [eax],80h), where a member that
; got its own path to its slot (FUN_004F9E05's member loop, from 0x6AA408) makes its group wait.
; EBX = group, ESI = member, EDI = member+14h. EAX and the flags are dead at 0x6AA51A; ECX and
; EDX are kept anyway.
UhcSnarePathWaitHook PROC
    TRACE_ONCE "snareOnlyHitUnit (0x6AA514)"
    push ecx
    push edx
    push 006AA514h
    push esi
    call UhcSnareSkipsWait          ; -> al = 1: snared member, the group does not wait
    pop edx
    pop ecx
    test al, al
    jne skip
    mov eax, dword ptr [ebx+4]      ; stolen 0x6AA514
    or byte ptr [eax], 80h          ; stolen 0x6AA517
skip:
    jmp pathWaitNext
UhcSnarePathWaitHook ENDP

; Replaces 0x6AA56A..0x6AA56F (mov eax,[eax+4] / or byte ptr [eax],80h), the same path's slot
; distance check, which sets the bit again. EAX = EBX = EBP = group, ESI = the member's ID
; (0x6AA537 loaded it over the pointer). EAX and the flags are dead after the jmp 4F9F99h.
UhcSnarePathCheckHook PROC
    TRACE_ONCE "snareOnlyHitUnit (0x6AA56A)"
    push ecx
    push edx
    push eax                        ; the group, for the stolen code
    push esi
    call UhcSnareSkipsWaitById      ; -> al = 1: snared member, the group does not wait
    test al, al
    pop eax                         ; pop leaves the flags alone
    pop edx
    pop ecx
    jne skip
    mov eax, dword ptr [eax+4]      ; stolen 0x6AA56A
    or byte ptr [eax], 80h          ; stolen 0x6AA56D
skip:
    jmp pathCheckNext
UhcSnarePathCheckHook ENDP

END
