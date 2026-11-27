; The options menu's registry (src/menuoptions.h): virtual options such as OptionRenderer. The game's option values
; live in a settings object (vtable 0BA3854h) with a fixed list of 93 entries; every accessor checks the ID against
; [settings+8] and fails beyond it. These hooks take over that failure path for the IDs FIRST_VIRTUAL_ID to
; FIRST_VIRTUAL_ID + g_uhcMenuOptionCount - 1, which the game never uses and only the name lookup hook hands out.
; The game's own IDs never reach the new code but through the stock failure paths, which return as before.
.686
.model flat, c
option casemap :none

include common.inc

UhcMenuOptionLookup PROTO STDCALL optionName:DWORD, settings:DWORD
UhcMenuOptionSet PROTO STDCALL slot:DWORD, value:DWORD

EXTERNDEF g_uhcMenuOptionCount:DWORD
EXTERNDEF g_uhcMenuOptionValues:DWORD
EXTERNDEF g_uhcMenuOptionFlags:DWORD
EXTERNDEF g_uhcMenuOptionChecks:DWORD

; The first virtual option's ID: far beyond the 93 entries, and none of the IDs the options screen maps itself
; (9, 0Ah, 30h). Keep it in step with kFirstVirtualId in menuoptions.h.
FIRST_VIRTUAL_ID EQU 55480001h

.data
lookupNext  dd 009322A6h    ; pop ecx / ret 4: the end of the name lookup

.code

; The name lookup 0x932264 (thiscall(settings, const wchar_t* name), ret 4) found no entry; it would return -1.
; On entry EDI = the name (may be null), ESI = settings+234h (its name map); [esp] the saved EDI, [esp+4] the saved
; ESI. Replaces pop edi / or eax,-1 / pop esi. EAX = -1 or a virtual ID; ECX and EDX are free (the caller is told
; nothing of them: the function ends with pop ecx / ret 4).
UhcMenuNameHook PROC
    TRACE_ONCE "menu options: option name lookup miss (0x9322A1)"
    lea eax, [esi-234h]
    push eax
    push edi
    call UhcMenuOptionLookup
    pop edi
    pop esi
    jmp dword ptr [lookupNext]
UhcMenuNameHook ENDP

; The type getter 0x553028 (thiscall(settings, id) -> al, ret 4) was given an ID beyond the entries. On entry
; EAX = the ID, ECX = settings. Replaces xor al,al / ret 4. A virtual option is an int (type 2). Only EAX and the
; flags change, and on the stock path EAX keeps its upper bytes. An option the screen read as a CheckBox (the bool
; getter hook marks it) is a bool (type 5), so that Apply writes it through the bool setter.
UhcMenuTypeHook PROC
    sub eax, FIRST_VIRTUAL_ID
    cmp eax, g_uhcMenuOptionCount
    jae notOurs
    TRACE_ONCE "menu options: option type (0x6B794B)"
    cmp g_uhcMenuOptionChecks[eax*4], 0
    mov al, 2
    je typeDone
    mov al, 5
typeDone:
    ret 4
notOurs:
    add eax, FIRST_VIRTUAL_ID
    xor al, al
    ret 4
UhcMenuTypeHook ENDP

; The int getter 0x402E6A (thiscall(settings, id, int* out) -> al, ret 8) was given an ID beyond the entries. On
; entry EAX = settings, ECX = the ID, [esp+8] = out. Replaces xor al,al / ret 8. On the stock path ECX is the ID
; again on return.
UhcMenuGetHook PROC
    sub ecx, FIRST_VIRTUAL_ID
    cmp ecx, g_uhcMenuOptionCount
    jae notOurs
    TRACE_ONCE "menu options: option read (0x6B7676)"
    mov eax, [esp+8]
    mov ecx, g_uhcMenuOptionValues[ecx*4]
    mov [eax], ecx
    mov al, 1
    ret 8
notOurs:
    add ecx, FIRST_VIRTUAL_ID
    xor al, al
    ret 8
UhcMenuGetHook ENDP

; The int setter 0x518AE0 (thiscall(settings, id, int value) -> al, ret 8) failed: an ID beyond the entries
; (0x518AEB) or not an int (0x518B15). On entry EDI = the ID; [esp] the saved EDI, [esp+4] the saved ESI, [esp+0Ch]
; the ID, [esp+10h] the value. Replaces pop edi / xor al,al / pop esi / ret 8. ECX and EDX are volatile across the
; call, as in stock. EDI is restored from the stack on both paths, so it holds the slot meanwhile.
UhcMenuSetHook PROC
    sub edi, FIRST_VIRTUAL_ID
    cmp edi, g_uhcMenuOptionCount
    jae notOurs
    TRACE_ONCE "menu options: option write (0x518B26)"
    push dword ptr [esp+10h]
    push edi
    call UhcMenuOptionSet
    pop edi
    mov al, 1
    pop esi
    ret 8
notOurs:
    pop edi
    xor al, al
    pop esi
    ret 8
UhcMenuSetHook ENDP

; The option flag test 0xA41707 (thiscall(settings, id, mask) -> al = the entry's flags & mask has a bit of 0F0h,
; ret 8) was given an ID beyond the entries. The options screen asks it with mask 40h, during a match only, to enable
; a field. On entry EAX = the ID, ECX = settings; [esp+4] the ID, [esp+8] the mask. Replaces xor al,al / ret 8 at
; 0xA41710. A virtual option answers from its flags (40h for a live one); on the stock path EAX keeps its upper bytes.
UhcMenuFlagHook PROC
    sub eax, FIRST_VIRTUAL_ID
    cmp eax, g_uhcMenuOptionCount
    jae notOurs
    TRACE_ONCE "menu options: option flag test (0xA41710)"
    mov eax, g_uhcMenuOptionFlags[eax*4]
    and eax, [esp+8]
    test al, 0F0h
    setne al
    ret 8
notOurs:
    add eax, FIRST_VIRTUAL_ID
    xor al, al
    ret 8
UhcMenuFlagHook ENDP

; The bool getter 0x402CE9 (thiscall(settings, id, bool* out) -> al, ret 8) was given an ID beyond the entries: the
; CheckBox builder reads its field with it. On entry EAX = settings, ECX = the ID, [esp+8] = out. Replaces
; xor al,al / ret 8 at 0x6B77B6. Marks the option as a CheckBox and writes its value (0 or 1) as a byte. On the stock
; path ECX is the ID again on return.
UhcMenuBoolGetHook PROC
    sub ecx, FIRST_VIRTUAL_ID
    cmp ecx, g_uhcMenuOptionCount
    jae notOurs
    TRACE_ONCE "menu options: option read as a CheckBox (0x6B77B6)"
    mov g_uhcMenuOptionChecks[ecx*4], 1
    mov eax, [esp+8]
    cmp g_uhcMenuOptionValues[ecx*4], 0
    setne byte ptr [eax]
    mov al, 1
    ret 8
notOurs:
    add ecx, FIRST_VIRTUAL_ID
    xor al, al
    ret 8
UhcMenuBoolGetHook ENDP

; The bool setter 0x518C7C (thiscall(settings, id, bool value), ret 8) failed: an ID beyond the entries (0x518C87)
; or not a bool (0x518CB1). Same frame as the int setter's: EDI = the ID; [esp] the saved EDI, [esp+4] the saved ESI,
; [esp+0Ch] the ID, [esp+10h] the value (its low byte; the caller pushes a whole register). Replaces
; pop edi / xor al,al / pop esi / ret 8 at 0x518CC2.
UhcMenuBoolSetHook PROC
    sub edi, FIRST_VIRTUAL_ID
    cmp edi, g_uhcMenuOptionCount
    jae notOurs
    TRACE_ONCE "menu options: option write as a CheckBox (0x518CC2)"
    movzx eax, byte ptr [esp+10h]
    neg eax
    sbb eax, eax
    neg eax                     ; 0 or 1
    push eax
    push edi
    call UhcMenuOptionSet
    pop edi
    mov al, 1
    pop esi
    ret 8
notOurs:
    pop edi
    xor al, al
    pop esi
    ret 8
UhcMenuBoolSetHook ENDP

END
