; The home city loader's commit of a card (src/cardtags.cpp), shared by the keys that read card tags of their own.
.686
.model flat, c
option casemap :none

include common.inc

UhcCardTagsDispatch PROTO STDCALL node:DWORD, array:DWORD, index:DWORD

.data
cardAppend      dd 0062FBC7h    ; the card array's append, thiscall(array, card*), ret 4, the new index in EAX

.code

; Replaces call 62FBC7h at 0x630017 in the home city loader FUN_0062E6C9. ECX = the home city's card array
; (hc+204h), [esp+4] = the card built on the stack, [esp] = the return address 0x63001C, EBX = the <card> node.
; Calls the append with the same this and argument, then the dispatch, and returns its index with ret 4 as the
; append does. The loader overwrites ECX and EDX after the call (lea ecx,[esp+0A8h] at 0x63001C) and does not read
; EAX again; EBX, ESI, EDI and EBP are kept by both calls.
UhcCardCommitHook PROC
    TRACE_ONCE "card tags (0x630017)"
    push ecx                        ; the array, kept
    push dword ptr [esp+8]          ; the card, [esp+4] + the push
    call dword ptr [cardAppend]     ; ECX is still the array; pops the card
    pop ecx
    push eax                        ; the index, returned
    push eax
    push ecx
    push ebx
    call UhcCardTagsDispatch
    pop eax
    ret 4
UhcCardCommitHook ENDP

END
