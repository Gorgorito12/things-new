; Hooks for workRateByAbstractType. Entered through a jmp written over the stock code; each leaves
; through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Action rates").
.686
.model flat, c
option casemap :none

include common.inc

UhcWorkRateByType PROTO STDCALL target:DWORD, base:DWORD, actionId:DWORD, key:DWORD, amount:DWORD, relativity:DWORD, unapply:DWORD

.data
applyNext   dd 008F9881h    ; je 8FAEF4h: the rest of the stock WorkRate case of applyData
unapplyNext dd 008FB11Fh    ; je 8FC19Ah: the same in unapplyData

.code

; Replaces 0x8F987C..0x8F9880 (mov edi,[edi+44h] / cmp edi,ebp), the head of case 3 (WorkRate) of
; applyData FUN_008F973F. EDI = target proto, ESI = its base proto, EBP = 0, FPU stack empty.
; Frame: action [esp+20h], rate key [esp+24h], amount [esp+28h], relativity [esp+2Ch].
UhcWorkRateApplyHook PROC
    TRACE_ONCE "workRateByAbstractType apply (0x8F987C)"
    pushad
    lea eax, [esp+20h]
    push 0
    push dword ptr [eax+2Ch]
    push dword ptr [eax+28h]
    push dword ptr [eax+24h]
    push dword ptr [eax+20h]
    push esi
    push edi
    call UhcWorkRateByType
    popad
    mov edi, dword ptr [edi+44h]    ; stolen 0x8F987C
    cmp edi, ebp                    ; stolen 0x8F987F
    jmp applyNext
UhcWorkRateApplyHook ENDP

; Replaces 0x8FB11A..0x8FB11E (mov esi,[esi+44h] / cmp esi,ebp), the same case of unapplyData
; FUN_008FB01C, which saves one register less and swaps these two. ESI = target proto, EDI = its
; base proto, EBP = 0, FPU stack empty. Frame: action [esp+1Ch], rate key [esp+20h], amount
; [esp+24h], relativity [esp+28h].
UhcWorkRateUnapplyHook PROC
    TRACE_ONCE "workRateByAbstractType unapply (0x8FB11A)"
    pushad
    lea eax, [esp+20h]
    push 1
    push dword ptr [eax+28h]
    push dword ptr [eax+24h]
    push dword ptr [eax+20h]
    push dword ptr [eax+1Ch]
    push edi
    push esi
    call UhcWorkRateByType
    popad
    mov esi, dword ptr [esi+44h]    ; stolen 0x8FB11A
    cmp esi, ebp                    ; stolen 0x8FB11D
    jmp unapplyNext
UhcWorkRateUnapplyHook ENDP

END
