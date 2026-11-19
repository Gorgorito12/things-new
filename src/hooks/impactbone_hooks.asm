; Hooks for impactBoneFix (src/features/impactbones.cpp). Each replaces a call of the model's bone frame
; getter FUN_00407272 in the visual's dummy attachment update (5 B), makes that call itself with the
; arguments the stock code pushed, and, when it succeeded, lets UhcFixDummyAxes scale the three axis vectors
; it wrote back to unit length. EAX (the getter's bool), ECX and EDX are kept; the stock test al,al / je
; follows at the continuation. ESP after the call is the frame both paths read the axes from.
.686
.model flat, c
option casemap :none

include common.inc

UhcFixDummyAxes PROTO STDCALL dummyType:DWORD, frame:DWORD, firstAxis:DWORD

.data
boneFrameGetter dd 00407272h
continue1       dd 004BE223h   ; test al,al / je 4E3B3Ah
continue2       dd 004BE892h   ; test al,al / je 4BEA2Bh

.code

; 0x4BE21E: EDI = the dummy type, the axes at [esp+24h], [esp+30h], [esp+40h] after the call.
UhcImpactBoneFrame1 PROC
    TRACE_ONCE "impactBoneFix dummy frame, path 1 (0x4BE21E)"
    call boneFrameGetter
    test al, al
    jz done
    push eax
    push ecx
    push edx
    lea eax, [esp+0Ch]
    push 24h
    push eax
    push edi
    call UhcFixDummyAxes
    pop edx
    pop ecx
    pop eax
done:
    jmp continue1
UhcImpactBoneFrame1 ENDP

; 0x4BE88D: EBX = the dummy type, the axes at [esp+20h], [esp+30h], [esp+40h] after the call.
UhcImpactBoneFrame2 PROC
    TRACE_ONCE "impactBoneFix dummy frame, path 2 (0x4BE88D)"
    call boneFrameGetter
    test al, al
    jz done
    push eax
    push ecx
    push edx
    lea eax, [esp+0Ch]
    push 20h
    push eax
    push ebx
    call UhcFixDummyAxes
    pop edx
    pop ecx
    pop eax
done:
    jmp continue2
UhcImpactBoneFrame2 ENDP

END
