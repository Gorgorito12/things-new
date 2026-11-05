; Hooks for resourceDebt. Entered through a jmp written over the stock code; each leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Resource debt").
.686
.model flat, c
option casemap :none

include common.inc

EXTERN g_uhcDebtResources:BYTE

.data
addNext     dd 0049A9D0h    ; mov ecx,[esp+18h]: the add goes on to the set
setNext     dd 0049A8E3h    ; mov edi,[esp+70h]: the set goes on

.code

; Replaces 0x679A0E (mov dword ptr [esp+10h],0), the clamp of the add 0x49A98A, reached when the sum
; is below 1e-6. ESI = the resource; [esp+10h] holds the sum. EAX is free: the continuation reloads it.
UhcDebtAddHook PROC
    TRACE_ONCE "resourceDebt add (0x679A0E)"
    cmp esi, 16
    jae clamp
    cmp byte ptr g_uhcDebtResources[esi], 0
    jne done
clamp:
    mov dword ptr [esp+10h], 0      ; stolen 0x679A0E
done:
    jmp addNext
UhcDebtAddHook ENDP

; Replaces 0x6798F4 (mov dword ptr [esp+74h],0), the clamp of the set 0x49A8C5. [esp+70h] = the
; resource, [esp+74h] the value. EAX is free: the continuation writes it before reading it.
UhcDebtSetHook PROC
    TRACE_ONCE "resourceDebt set (0x6798F4)"
    mov eax, dword ptr [esp+70h]
    cmp eax, 16
    jae clamp
    cmp byte ptr g_uhcDebtResources[eax], 0
    jne done
clamp:
    mov dword ptr [esp+74h], 0      ; stolen 0x6798F4
done:
    jmp setNext
UhcDebtSetHook ENDP

END
