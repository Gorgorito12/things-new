; rendererOption (src/features/renderer.cpp): the options menu's virtual option OptionRenderer. The game's option
; values live in a settings object (vtable 0BA3854h) with a fixed list of 93 entries; every accessor checks the ID
; against [settings+8] and fails beyond it. These hooks take over that failure path for one ID the game never uses,
; kVirtualId, which only the name lookup hook hands out. The game's own IDs never reach the new code but through the
; stock failure paths, which return as before.
.686
.model flat, c
option casemap :none

include common.inc

UhcRendererOptionLookup PROTO STDCALL optionName:DWORD, settings:DWORD
UhcRendererOptionSet PROTO STDCALL value:DWORD

EXTERNDEF g_uhcRendererChoice:DWORD

; The virtual option's ID: far beyond the 93 entries, and none of the IDs the options screen maps itself (9, 0Ah,
; 30h). Keep it in step with kVirtualId in renderer.cpp.
VIRTUAL_ID EQU 55480001h

.data
lookupNext  dd 009322A6h    ; pop ecx / ret 4: the end of the name lookup

.code

; The name lookup 0x932264 (thiscall(settings, const wchar_t* name), ret 4) found no entry; it would return -1.
; On entry EDI = the name (may be null), ESI = settings+234h (its name map); [esp] the saved EDI, [esp+4] the saved
; ESI. Replaces pop edi / or eax,-1 / pop esi. EAX = -1 or VIRTUAL_ID; ECX and EDX are free (the caller is told
; nothing of them: the function ends with pop ecx / ret 4).
UhcRendererNameHook PROC
    TRACE_ONCE "rendererOption: option name lookup miss (0x9322A1)"
    lea eax, [esi-234h]
    push eax
    push edi
    call UhcRendererOptionLookup
    pop edi
    pop esi
    jmp dword ptr [lookupNext]
UhcRendererNameHook ENDP

; The type getter 0x553028 (thiscall(settings, id) -> al, ret 4) was given an ID beyond the entries. On entry
; EAX = the ID, ECX = settings. Replaces xor al,al / ret 4. The virtual option is an int (type 2).
UhcRendererTypeHook PROC
    cmp eax, VIRTUAL_ID
    jne notOurs
    TRACE_ONCE "rendererOption: option type (0x6B794B)"
    mov al, 2
    ret 4
notOurs:
    xor al, al
    ret 4
UhcRendererTypeHook ENDP

; The int getter 0x402E6A (thiscall(settings, id, int* out) -> al, ret 8) was given an ID beyond the entries. On
; entry EAX = settings, ECX = the ID, [esp+8] = out. Replaces xor al,al / ret 8.
UhcRendererGetHook PROC
    cmp ecx, VIRTUAL_ID
    jne notOurs
    TRACE_ONCE "rendererOption: option read (0x6B7676)"
    mov eax, [esp+8]
    mov ecx, g_uhcRendererChoice
    mov [eax], ecx
    mov al, 1
    ret 8
notOurs:
    xor al, al
    ret 8
UhcRendererGetHook ENDP

; The int setter 0x518AE0 (thiscall(settings, id, int value) -> al, ret 8) failed: an ID beyond the entries
; (0x518AEB) or not an int (0x518B15). On entry EDI = the ID; [esp] the saved EDI, [esp+4] the saved ESI, [esp+0Ch]
; the ID, [esp+10h] the value. Replaces pop edi / xor al,al / pop esi / ret 8. ECX and EDX are volatile across the
; call, as in stock.
UhcRendererSetHook PROC
    cmp edi, VIRTUAL_ID
    jne notOurs
    TRACE_ONCE "rendererOption: option write (0x518B26)"
    push dword ptr [esp+10h]
    call UhcRendererOptionSet
    pop edi
    mov al, 1
    pop esi
    ret 8
notOurs:
    pop edi
    xor al, al
    pop esi
    ret 8
UhcRendererSetHook ENDP

END
