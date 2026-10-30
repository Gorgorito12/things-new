; The action tag hook (actiontags.cpp), shared by every key that reads extra action tags
; (damageOverTime, spreadAnyAccuracy). Entered through a jmp written over the stock code at 0x5FA11E;
; it leaves through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Damage and
; poison").
.686
.model flat, c
option casemap :none

include common.inc

UhcActionTag PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD, :DWORD

.data
lastTagHandler      dd 005FD4EDh    ; stock je target: the "ModifyExclusive" handler
nextChild           dd 005FA126h    ; mov eax,[esp+1Ch]: the loop's next child

.code

; Replaces test eax,eax / je 5FD4EDh at 0x5FA11E in FUN_005F98A0 (thiscall(actionSet, proto, action,
; node)), after its last tag compare ("ModifyExclusive"). Reached only by that tag and by tags the
; stock parser does not know.
; ESI = the address of the child's tag-name BString (its UTF-16 text is [esi]), EDI = the child node;
; the arguments are at [esp+0C4h] (proto) and [esp+0C8h] (action), the return address at [esp+0C0h]:
; 0x5FA213 for a protoy.xml <ProtoAction>, 0x5FA623 for a .tactics <action>. Unknown tags of either go
; to the C++ dispatcher. EAX and the flags are free: the next-child code overwrites them
; (mov eax,[esp+1Ch] / ... / cmp eax,[ecx+0Ch]).
UhcActionTagHook PROC
    test eax, eax                   ; stolen 0x5FA11E
    jne unknownTag
    jmp lastTagHandler              ; stolen 0x5FA120: je 5FD4EDh
unknownTag:
    mov eax, dword ptr [esp+0C0h]
    cmp eax, 005FA213h              ; the <ProtoAction> handler's call
    je dispatch
    cmp eax, 005FA623h              ; the tactics <action> creator's call
    jne next
dispatch:
    TRACE_ONCE "action tag (0x5FA11E)"
    pushad
    push dword ptr [esp+20h+0C0h]       ; return address: the action's source
    push dword ptr [esp+24h+0C8h]       ; action
    push dword ptr [esp+28h+0C4h]       ; proto
    push edi                            ; child node
    push esi                            ; tag-name BString address
    call UhcActionTag
    popad
next:
    jmp nextChild
UhcActionTagHook ENDP

END
