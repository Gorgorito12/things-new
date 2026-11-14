; The hooks of dataLint (src/features/datalint.cpp). Each one reads a failure exit of the data load, does what the
; stock code there does, and leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcLintUnitType PROTO STDCALL :DWORD, :DWORD
UhcLintProtoTag PROTO STDCALL :DWORD, :DWORD
UhcLintProtoAction PROTO STDCALL :DWORD, :DWORD
UhcLintDone PROTO STDCALL
UhcLintEffect PROTO STDCALL :DWORD
EXTERN g_uhcLintTech:DWORD

.data
unitTypeNext    dd 005FCB66h    ; mov ecx,0D5E620h: the handler's error, then its failure return
protoTagNext    dd 005F62AAh    ; mov eax,[edx+4]: the found handler's call
protoTagSkip    dd 005F62BCh    ; add ebp,1: the next child
protoActionNext dd 005FA208h    ; mov ecx,[edi+44h]: the action exists
protoActionMiss dd 005FC891h    ; the handler's failure
techLoad        dd 0061FD02h    ; the tech parser
techNodeNext    dd 0061FDBFh    ; cmp edx,-1: the tech's name
effectNext      dd 006205EFh    ; mov eax,esi: the effect is good
effectDelete    dd 00621ECAh    ; setData was false: the effect is deleted
effectTypeNext  dd 0065BC5Bh    ; mov ecx,0D5E620h: the type's error
loadReturn      dd 0            ; where the database load's call goes back to

.code

; Replaces push 0EB4h at 0x5FCB61, the failure of the <UnitType> handler 0x5F62D4, cdecl(database, node, proto).
; EDI = the name, 0 for an empty node. [esp] and [esp+4] = the saved EDI and ESI, [esp+14h] = proto. Only EAX, ECX and
; EDX change, and the stock code overwrites them here.
UhcLintUnitTypeHook PROC
    TRACE_ONCE "dataLint unit type (0x5FCB61)"
    invoke UhcLintUnitType, edi, dword ptr [esp+14h]
    push 0EB4h
    jmp unitTypeNext
UhcLintUnitTypeHook ENDP

; Replaces test al,al / je 5F62BCh / mov edx,[esp+14h] at 0x5F62A2, after the find in the proto tag table, in the proto
; parser 0x5F611D. ESI = the child's name, EBX = the proto.
UhcLintProtoTagHook PROC
    test al, al
    jne found
    TRACE_ONCE "dataLint proto tag (0x5F62A2)"
    invoke UhcLintProtoTag, esi, ebx
    jmp protoTagSkip
found:
    mov edx, dword ptr [esp+14h]
    jmp protoTagNext
UhcLintProtoTagHook ENDP

; Replaces je 5FC891h at 0x5FA202 in the <ProtoAction> handler, after the look-up of the action by name. The flags are
; those of test eax,eax. ESI = the address of the <Name> text's BString, EDI = the proto. On the failure path the handler
; reads no register the call changes.
UhcLintProtoActionHook PROC
    jne found
    TRACE_ONCE "dataLint proto action (0x5FA202)"
    invoke UhcLintProtoAction, esi, edi
    jmp protoActionMiss
found:
    jmp protoActionNext
UhcLintProtoActionHook ENDP

; The call of the tech parser 0x61FD02 at 0x61FE4A, the last thing the data load reads. Its arguments stay on the
; stack, and it pops whatever it pops, so only the return address is swapped.
UhcLintDoneHook PROC
    TRACE_ONCE "dataLint load end (0x61FE4A)"
    pop loadReturn
    call techLoad
    push eax
    call UhcLintDone
    pop eax
    jmp loadReturn
UhcLintDoneHook ENDP

; Replaces mov esi,eax / mov ecx,esi / mov edx,[ecx+18h] at 0x61FDB8, the loop over the tree's nodes: EAX = node.
UhcLintTechHook PROC
    mov g_uhcLintTech, eax
    mov esi, eax
    mov ecx, esi
    mov edx, dword ptr [ecx+18h]
    jmp techNodeNext
UhcLintTechHook ENDP

; Replaces je 621ECAh at 0x6205E9 in the effect parse 0x620572. The flags are those of test al,al. EDI = the node.
UhcLintEffectHook PROC
    jne good
    TRACE_ONCE "dataLint effect (0x6205E9)"
    invoke UhcLintEffect, edi
    jmp effectDelete
good:
    jmp effectNext
UhcLintEffectHook ENDP

; Replaces push 512h at 0x65BC56, the effect type's failure. EDI = the node.
UhcLintEffectTypeHook PROC
    TRACE_ONCE "dataLint effect type (0x65BC56)"
    invoke UhcLintEffect, edi
    push 512h
    jmp effectTypeNext
UhcLintEffectTypeHook ENDP

END
