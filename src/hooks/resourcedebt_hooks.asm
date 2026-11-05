; Hooks for resourceDebt. Entered through a jmp written over the stock code; each leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Resource debt").
.686
.model flat, c
option casemap :none

include common.inc

EXTERN g_uhcDebtResources:BYTE
UhcDebtNote PROTO STDCALL player:DWORD, resource:DWORD, amount:DWORD

.data
addNext     dd 0049A9D0h    ; mov ecx,[esp+18h]: the add goes on to the set
setNext     dd 0049A8E3h    ; mov edi,[esp+70h]: the set goes on
shareNext   dd 006799DCh    ; mov ecx,[esp+20h]: the shared add goes on to the set

.code

; Replaces 0x679A0E (mov dword ptr [esp+10h],0), the clamp of the add 0x49A98A, reached when the sum
; is below 1e-6. EBP = the player, ESI = the resource; [esp+10h] holds the sum. EAX is free: the
; continuation reloads it. FPU stack empty.
UhcDebtAddHook PROC
    TRACE_ONCE "resourceDebt add (0x679A0E)"
    cmp esi, 16
    jae clamp
    cmp byte ptr g_uhcDebtResources[esi], 0
    je clamp
    pushad
    push dword ptr [esp+30h]
    push esi
    push ebp
    call UhcDebtNote
    popad
    jmp addNext
clamp:
    mov dword ptr [esp+10h], 0      ; stolen 0x679A0E
    jmp addNext
UhcDebtAddHook ENDP

; Replaces 0x6798F4 (mov dword ptr [esp+74h],0), the clamp of the set 0x49A8C5. ESI = the player,
; [esp+70h] = the resource, [esp+74h] the value. EAX is free: the continuation writes it before
; reading it. FPU stack empty.
UhcDebtSetHook PROC
    TRACE_ONCE "resourceDebt set (0x6798F4)"
    mov eax, dword ptr [esp+70h]
    cmp eax, 16
    jae clamp
    cmp byte ptr g_uhcDebtResources[eax], 0
    je clamp
    jmp setNext
clamp:
    mov dword ptr [esp+74h], 0      ; stolen 0x6798F4
    jmp setNext
UhcDebtSetHook ENDP

; Replaces 0x6799D4 (mov dword ptr [esp+18h],0), the clamp of the add's shared-resources path, once
; per teammate. EDI = the teammate, EBP = the resource; [esp+18h] holds the sum. EAX is free: the
; continuation does not read it. FPU stack empty.
UhcDebtShareHook PROC
    TRACE_ONCE "resourceDebt shared add (0x6799D4)"
    cmp ebp, 16
    jae clamp
    cmp byte ptr g_uhcDebtResources[ebp], 0
    je clamp
    pushad
    push dword ptr [esp+38h]
    push ebp
    push edi
    call UhcDebtNote
    popad
    jmp shareNext
clamp:
    mov dword ptr [esp+18h], 0      ; stolen 0x6799D4
    jmp shareNext
UhcDebtShareHook ENDP

END
