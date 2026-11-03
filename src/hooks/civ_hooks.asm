; Hooks for asianCivs (src/features/civs.cpp). Each replaces the last compare of a stock civ test
; with the cached civ ID [0C6FB88h], re-executes it, and for any other civ asks the DLL whether
; the cfg lists it; it leaves through an explicit jmp to one of the stock continuations.
.686
.model flat, c
option casemap :none

include common.inc

UhcIsListedAsianCiv PROTO STDCALL civ:DWORD
UhcAsianWonderOption PROTO STDCALL player:DWORD, optionCiv:DWORD

.data
asianCheckTrue    dd 00454F2Ah   ; mov al,1 / ret 4
asianCheckFalse   dd 00454F25h   ; xor al,al / ret 4
asianBranchTrue   dd 008D6ACCh   ; test edx,edx (the Asian civs' values)
asianBranchFalse  dd 008D6B0Ch   ; the other civs' value
isIndianCiv       dd 0049A2D8h   ; bool thiscall(player, bool)
wonderIndianTest  dd 0081828Dh   ; compare the option's civ with "Indians"
wonderAddOption   dd 008182A9h   ; add the option
wonderSkipOption  dd 008182EBh   ; next option

.code

; 0x454F1D in isAsianCiv (0x454ED7, bool thiscall(player, bool extended)), reached only with
; `extended` set: cmp eax,[0C6FB88h] / je 454F2Ah (8 B). EAX = the player's first civ.
UhcAsianCivCheckHook PROC
    TRACE_ONCE "asianCivs isAsianCiv (0x454F1D)"
    cmp eax, dword ptr ds:[0C6FB88h]
    je isTrue
    push ecx
    push edx
    push eax
    call UhcIsListedAsianCiv
    pop edx
    pop ecx
    test al, al
    jnz isTrue
    jmp asianCheckFalse
isTrue:
    jmp asianCheckTrue
UhcAsianCivCheckHook ENDP

; 0x8D6AC4 in FUN_008D6A7D: cmp eax,[0C6FB88h] / jne 8D6B0Ch (8 B). EAX = the first civ; ECX, EDX
; (the civ count), ESI and EDI are read after the continuation, EAX is reloaded there.
UhcAsianCivBranchHook PROC
    TRACE_ONCE "asianCivs civ value (0x8D6AC4)"
    cmp eax, dword ptr ds:[0C6FB88h]
    je isAsian
    push ecx
    push edx
    push eax
    call UhcIsListedAsianCiv
    pop edx
    pop ecx
    test al, al
    jnz isAsian
    jmp asianBranchFalse
isAsian:
    jmp asianBranchTrue
UhcAsianCivBranchHook ENDP

; 0x818284 in the wonder age-up list FUN_0081807A: call 49A2D8h / test al,al / je 8182EBh (9 B),
; with push 1 and ECX = EBP (the player) already done. EBP = the player, ESI = the UI object,
; EDI = the option's offset in [esi+18Ch] (its civ name BString at +8). Stock adds an option to
; an Indian player only if its civ is "Indians" and to any other non-Chinese, non-Japanese player
; none at all; a listed civ gets the options whose civ name is its cfg name.
UhcWonderAgeUpHook PROC
    TRACE_ONCE "asianCivs wonder age-up (0x818284)"
    call isIndianCiv
    test al, al                     ; AL: the callee leaves EAX's upper bytes as they were
    jnz indian
    pushad
    mov eax, dword ptr [esi+18Ch]
    lea eax, [eax+edi+8]
    push eax
    push ebp
    call UhcAsianWonderOption
    mov dword ptr [esp+28], eax     ; EAX's slot in the pushad frame
    popad
    test al, al
    jz skip
    jmp wonderAddOption
skip:
    jmp wonderSkipOption
indian:
    jmp wonderIndianTest
UhcWonderAgeUpHook ENDP

END
