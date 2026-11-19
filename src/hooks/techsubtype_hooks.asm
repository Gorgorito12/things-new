; The shared hooks for new Data effect subtypes (src/techsubtypes.h). Entered through a jmp written
; over the stock code; they leave through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcTechSubtypeLookup PROTO STDCALL db_:DWORD, subtypeName:DWORD, returnAddress:DWORD
EXTERN g_uhcSubtypeEffect:DWORD
EXTERN g_uhcSubtypeNode:DWORD
UhcTechPlayerSubtypeRun PROTO STDCALL subtype:DWORD, player:DWORD, field:DWORD, amount:DWORD
UhcTechSubtypeRun PROTO STDCALL subtype:DWORD, target:DWORD, base:DWORD, amount:DWORD, relativity:DWORD, unapply:DWORD, actionId:DWORD, allActions:DWORD

.data
xmlAttribute      dd 00598F37h    ; the XML attribute read
lookupNext        dd 0061FF62h    ; test edi,edi, in the name lookup
applySwitchNext   dd 008F9796h    ; movzx ecx, the subtype's jump index
applyDone         dd 008FAE9Eh    ; pop edi / esi / ebp, mov al,1, pop ebx / ecx, ret 20h
applyFail         dd 008FAEF4h    ; the same with xor al,al
unapplySwitchNext dd 008FB05Ah    ; movzx eax, the subtype's jump index
unapplyDone       dd 008FC191h    ; pop edi / esi / ebp, mov al,1, pop ebx, ret 20h
unapplyFail       dd 008FC19Ah    ; the same with xor al,al
playerSwitchNext  dd 008D8444h    ; movzx eax,[eax+8D93D8h] / jmp [eax*4+8D9330h]: the stock player cases
playerDone        dd 008D8D23h    ; pop edi / esi / ebp / ebx, add esp,0Ch, ret 1Ch (AL as left)
playerFail        dd 008D878Fh    ; pop edi / esi / ebp, xor al,al, pop ebx, add esp,0Ch, ret 1Ch

.code

; Replaces the call at 0x6206B2 in BDataEffect::setData, which reads the attribute subtype. ESI = the
; effect, EBP = its XML node: kept here because another DLL may do the rest of the lookup its own way.
UhcTechSubtypeAttrHook PROC
    mov g_uhcSubtypeEffect, esi
    mov g_uhcSubtypeNode, ebp
    jmp xmlAttribute
UhcTechSubtypeAttrHook ENDP

; The head of the name lookup 0x61FF5D, thiscall(db, name), ret 4.
UhcTechSubtypeLookupHook PROC
    TRACE_ONCE "tech subtype lookup (0x61FF5D)"
    mov eax, dword ptr [esp]
    mov edx, dword ptr [esp+4]
    invoke UhcTechSubtypeLookup, ecx, edx, eax
    ret 4
UhcTechSubtypeLookupHook ENDP

; The stock lookup: re-executes 0x61FF5D..0x61FF61 (push edi / mov edi,[esp+8]).
UhcTechSubtypeLookupStock PROC
    push edi
    mov edi, dword ptr [esp+8]
    jmp lookupNext
UhcTechSubtypeLookupStock ENDP

; Replaces 0x8F978D..0x8F9795 (cmp eax,63h / ja 0x8FAEF4) in applyData. EAX = subtype, EDI = target
; proto, ESI = its base proto, [esp+20h] the action's ID, [esp+28h] amount, [esp+2Ch] relativity,
; [esp+34h] the allactions flag, the function's arguments 3, 5, 6 and 8 (0x7F86C0).
UhcTechSubtypeApplyHook PROC
    TRACE_ONCE "tech subtype apply (0x8F978D)"
    cmp eax, 100h
    jae custom
    cmp eax, 63h
    ja fail
    jmp applySwitchNext
custom:
    movzx ecx, byte ptr [esp+34h]
    push ecx                        ; allActions
    push dword ptr [esp+24h]        ; actionId, 20h + the push
    push 0                          ; unapply
    movzx ecx, byte ptr [esp+38h]   ; relativity, 2Ch + 3 pushes
    push ecx
    push dword ptr [esp+38h]        ; amount, 28h + 4 pushes
    push esi
    push edi
    push eax
    call UhcTechSubtypeRun
    test al, al
    je fail
    jmp applyDone
fail:
    jmp applyFail
UhcTechSubtypeApplyHook ENDP

; Replaces 0x8FB051..0x8FB059 (cmp eax,5Eh / ja 0x8FC19A) in unapplyData. EAX = subtype, ESI = target
; proto, EDI = its base proto, [esp+1Ch] the action's ID, [esp+24h] amount, [esp+28h] relativity,
; [esp+30h] the allactions flag: the same arguments, with one register less saved.
UhcTechSubtypeUnapplyHook PROC
    TRACE_ONCE "tech subtype unapply (0x8FB051)"
    cmp eax, 100h
    jae custom
    cmp eax, 5Eh
    ja fail
    jmp unapplySwitchNext
custom:
    movzx ecx, byte ptr [esp+30h]
    push ecx                        ; allActions
    push dword ptr [esp+20h]        ; actionId, 1Ch + the push
    push 1                          ; unapply
    movzx ecx, byte ptr [esp+34h]   ; relativity, 28h + 3 pushes
    push ecx
    push dword ptr [esp+34h]        ; amount, 24h + 4 pushes
    push edi
    push esi
    push eax
    call UhcTechSubtypeRun
    test al, al
    je fail
    jmp unapplyDone
fail:
    jmp unapplyFail
UhcTechSubtypeUnapplyHook ENDP

; Replaces 0x8D843E..0x8D8443 (ja 8D878Fh) in the player Data apply FUN_008D842B, thiscall(player, a1, a2, subtype,
; field, a5, amount, relativity), ret 1Ch. EBP = subtype, EAX = subtype - 0Ah, the flags those of cmp eax,5Ah;
; ESI = the player; EBX, EBP, ESI, EDI pushed below the 0Ch locals, so the field is [esp+2Ch], the amount
; [esp+34h], the subtype argument [esp+28h]. A stock ID goes on as stock; a key's ID asks UhcTechPlayerSubtypeRun,
; which ends the effect (done, AL = 1; or failed) or names a stock subtype to run with the rewritten arguments.
UhcTechPlayerSubtypeHook PROC
    TRACE_ONCE "tech subtype on a player (0x8D843E)"
    jbe stockCase                   ; the stolen ja, inverted: 0Ah..64h are the stock cases
    cmp ebp, 100h
    jb fail
    lea ecx, [esp+34h]
    lea edx, [esp+2Ch]
    push ecx                        ; &amount
    push edx                        ; &field
    push esi                        ; player
    push ebp                        ; subtype
    call UhcTechPlayerSubtypeRun
    cmp eax, -2
    je done
    cmp eax, -1
    je fail
    mov ebp, eax                    ; run as that stock subtype
    mov dword ptr [esp+28h], eax
    sub eax, 0Ah
    cmp eax, 5Ah
    ja fail
stockCase:
    jmp playerSwitchNext
done:
    mov al, 1
    jmp playerDone
fail:
    jmp playerFail
UhcTechPlayerSubtypeHook ENDP

END
