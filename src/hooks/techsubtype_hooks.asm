; The shared hooks for new Data effect subtypes (src/techsubtypes.h). Entered through a jmp written
; over the stock code; they leave through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcTechSubtypeRun PROTO STDCALL subtype:DWORD, target:DWORD, base:DWORD, amount:DWORD, relativity:DWORD, unapply:DWORD

.data
applySwitchNext   dd 008F9796h    ; movzx ecx, the subtype's jump index
applyDone         dd 008FAE9Eh    ; pop edi / esi / ebp, mov al,1, pop ebx / ecx, ret 20h
applyFail         dd 008FAEF4h    ; the same with xor al,al
unapplySwitchNext dd 008FB05Ah    ; movzx eax, the subtype's jump index
unapplyDone       dd 008FC191h    ; pop edi / esi / ebp, mov al,1, pop ebx, ret 20h
unapplyFail       dd 008FC19Ah    ; the same with xor al,al

.code

; Replaces 0x8F978D..0x8F9795 (cmp eax,63h / ja 0x8FAEF4) in applyData. EAX = subtype, EDI = target
; proto, ESI = its base proto, [esp+28h] amount, [esp+2Ch] relativity.
UhcTechSubtypeApplyHook PROC
    TRACE_ONCE "tech subtype apply (0x8F978D)"
    cmp eax, 100h
    jae custom
    cmp eax, 63h
    ja fail
    jmp applySwitchNext
custom:
    movzx ecx, byte ptr [esp+2Ch]
    mov edx, dword ptr [esp+28h]
    invoke UhcTechSubtypeRun, eax, edi, esi, edx, ecx, 0
    test al, al
    je fail
    jmp applyDone
fail:
    jmp applyFail
UhcTechSubtypeApplyHook ENDP

; Replaces 0x8FB051..0x8FB059 (cmp eax,5Eh / ja 0x8FC19A) in unapplyData. EAX = subtype, ESI = target
; proto, EDI = its base proto, [esp+24h] amount, [esp+28h] relativity.
UhcTechSubtypeUnapplyHook PROC
    TRACE_ONCE "tech subtype unapply (0x8FB051)"
    cmp eax, 100h
    jae custom
    cmp eax, 5Eh
    ja fail
    jmp unapplySwitchNext
custom:
    movzx ecx, byte ptr [esp+28h]
    mov edx, dword ptr [esp+24h]
    invoke UhcTechSubtypeRun, eax, esi, edi, edx, ecx, 1
    test al, al
    je fail
    jmp unapplyDone
fail:
    jmp unapplyFail
UhcTechSubtypeUnapplyHook ENDP

END
