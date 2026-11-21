; displayedRange (src/features/displayrange.cpp): <Flag>AlwaysDisplayRange</Flag>.
.686
.model flat, c
option casemap :none

include common.inc

UhcUnknownProtoFlag PROTO STDCALL protoUnit:DWORD, flagName:DWORD

EXTERNDEF C g_uhcStringCompare:DWORD

.code

; Replaces the call at 0x5F726F of the string compare 0x4028B4 (cdecl(text, name), 0 = equal), the last compare of the
; proto flag parser 0x5F640A (stdcall(proto, name), ret 8; ESI = name, its own ESI saved by its first push). On entry:
; [esp+4] the flag text, [esp+8] the name, [esp+0Ch] the saved ESI, [esp+10h] the parser's return, [esp+14h] the
; proto. The stock compare runs; when it does not match (the name is no stock flag), the name goes to the key. EAX is
; the compare's result, as the parser's test eax,eax / je after the call expects; ECX and EDX are free there.
UhcProtoFlagCompareHook PROC
    TRACE_ONCE "displayedRange: proto flag parser's last compare (0x5F726F)"
    push dword ptr [esp+8]
    push dword ptr [esp+8]
    call dword ptr [g_uhcStringCompare]
    add esp, 8
    test eax, eax
    jz done
    push eax
    ; [esp+0Ch] the name, [esp+18h] the proto
    push dword ptr [esp+0Ch]
    push dword ptr [esp+1Ch]
    call UhcUnknownProtoFlag
    pop eax
done:
    ret
UhcProtoFlagCompareHook ENDP

END
