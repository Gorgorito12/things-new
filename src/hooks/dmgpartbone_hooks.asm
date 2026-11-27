; Hook for dmgPartBoneFix with `log` (src/features/dmgpartbone.cpp). Entered through a jmp over test bl,bl / je
; 658C3Ah at 0x658C18 in the part declaration FUN_004F0187, after its "Invalid bone name" error. When BL is set
; (the stock code would reload the model through 0x658C35), UhcPartBoneReloadSkipped logs the bone and the model;
; either way it leaves to 0x658C3A, the stock path that skips the reload. ESP is the function's body ESP there:
; [esp+44h] = the part's bone attribute (its text pointer at +4), EDI = the model's cache entry (name at +4).
.686
.model flat, c
option casemap :none

include common.inc

UhcPartBoneReloadSkipped PROTO STDCALL model:DWORD, bone:DWORD

.data
partBoneContinue dd 00658C3Ah   ; lea ecx,[esp+14h] / call 4010CAh / jmp 4F0246h

.code

UhcPartBoneReloadHook PROC
    TRACE_ONCE "dmgPartBoneFix part bone reload (0x658C18)"
    test bl, bl
    jz done
    pushad
    mov eax, [esp+20h+44h]
    xor edx, edx
    test eax, eax
    jz noBone
    mov edx, [eax+4]
noBone:
    push edx
    push dword ptr [edi+4]
    call UhcPartBoneReloadSkipped
    popad
done:
    jmp partBoneContinue
UhcPartBoneReloadHook ENDP

END
