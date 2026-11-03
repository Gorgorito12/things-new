; Hooks for asianCivs (src/features/civs.cpp). Each replaces the last compare of a stock civ test
; with the cached civ ID [0C6FB88h], re-executes it, and for any other civ asks the DLL whether
; the cfg lists it; it leaves through an explicit jmp to one of the stock continuations.
.686
.model flat, c
option casemap :none

include common.inc

UhcIsListedAsianCiv PROTO STDCALL civ:DWORD
UhcAsianWonderOption PROTO STDCALL player:DWORD, optionCiv:DWORD
UhcIsTwoScoutCiv PROTO STDCALL civ:DWORD
UhcIsNativeCiv PROTO STDCALL civ:DWORD
UhcBigButtonPath PROTO STDCALL native:DWORD, player:DWORD, unit:DWORD
UhcMarkNativeCivs PROTO STDCALL database:DWORD, value:DWORD
UhcNativeCouncilOption PROTO STDCALL civ:DWORD, optionCiv:DWORD

.data
asianCheckTrue    dd 00454F2Ah   ; mov al,1 / ret 4
asianCheckFalse   dd 00454F25h   ; xor al,al / ret 4
asianBranchTrue   dd 008D6ACCh   ; test edx,edx (the Asian civs' values)
asianBranchFalse  dd 008D6B0Ch   ; the other civs' value
isIndianCiv       dd 0049A2D8h   ; bool thiscall(player, bool)
wonderIndianTest  dd 0081828Dh   ; compare the option's civ with "Indians"
wonderAddOption   dd 008182A9h   ; add the option
wonderSkipOption  dd 008182EBh   ; next option
twoScout1Listed   dd 0077EBF6h   ; test bl,bl (the Asian, not Chinese branch)
twoScout1Stock    dd 0077EBB8h   ; push eax / call 8D0318h
twoScout2Listed   dd 0077EF68h   ; push 1
twoScout2Stock    dd 0077EF2Fh   ; after call 8D0318h
civTest8D0318     dd 008D0318h   ; bool cdecl(civ): caches the civ IDs, is the civ Asian
twoScout3Listed   dd 0077DE16h   ; lea ecx,[esp+30h] (the two-hero branch)
twoScout3Stock    dd 0077DDD8h   ; push ecx / call 8D0318h
twoScout4Listed   dd 0077E039h   ; lea ecx,[esp+10h] (the Japanese / Indian branch)
twoScout4Stock    dd 0077DFFAh   ; mov ecx,[edx+140h]
nativeMarkReturn  dd 0052B588h   ; call 59992Ch
native2True       dd 0051272Ah   ; mov al,1 / ret
native2False      dd 00512727h   ; xor al,al / ret
native4True       dd 00453D72h   ; mov al,1 / ret 4
native4False      dd 00453D6Dh   ; xor al,al / ret 4
native7True       dd 0067B0BBh
native7False      dd 0067B0ADh
native9True       dd 008D53B4h
native9False      dd 008D52B5h
councilAdd        dd 0081AE59h   ; add the option
councilStock      dd 0081ADF3h   ; jne 81AE11h (with the stock compare's flags)
bigButtonNative   dd 00695955h   ; the native civs' path (big button if the unit is of type 2)
bigButtonNone     dd 00461BDEh   ; no big button

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

; twoScoutCivs: four tests in the hero UI (FUN_0077EB91, FUN_0077DBFE and a third function) on the
; civ at [esi+1DCh] (or [esp+10h]) choose between the two-hero civs (Japanese and Indians: Asian
; and not Chinese) and the others. A listed civ takes the two-hero branch.

; 0x77EBB2: mov eax,[esi+1DCh] (6 B). Listed: BL = 1 and the flags [esp+0Fh] = 1 (Asian),
; [esp+0Eh] = 0 (not Chinese), as the stock code would store them, then 0x77EBF6.
UhcTwoScout1Hook PROC
    TRACE_ONCE "twoScoutCivs hero UI 1 (0x77EBB2)"
    push ecx
    push edx
    push dword ptr [esi+1DCh]
    call UhcIsTwoScoutCiv
    pop edx
    pop ecx
    test al, al
    jz stock1
    mov bl, 1
    mov byte ptr [esp+0Fh], 1
    mov byte ptr [esp+0Eh], 0
    jmp twoScout1Listed
stock1:
    mov eax, dword ptr [esi+1DCh]
    jmp twoScout1Stock
UhcTwoScout1Hook ENDP

; 0x77EF29: push eax / call 8D0318h (6 B), after push ebx; the civ is EAX = [esp+14h] here.
UhcTwoScout2Hook PROC
    TRACE_ONCE "twoScoutCivs hero UI 2 (0x77EF29)"
    push ecx
    push edx
    push eax
    call UhcIsTwoScoutCiv
    pop edx
    pop ecx
    test al, al
    jz stock2
    jmp twoScout2Listed
stock2:
    mov eax, dword ptr [esp+14h]
    push eax
    call civTest8D0318
    jmp twoScout2Stock
UhcTwoScout2Hook ENDP

; 0x77DDD2: mov ecx,[esi+1DCh] (6 B).
UhcTwoScout3Hook PROC
    TRACE_ONCE "twoScoutCivs hero UI 3 (0x77DDD2)"
    push eax
    push edx
    push dword ptr [esi+1DCh]
    call UhcIsTwoScoutCiv
    test al, al
    pop edx
    pop eax
    jz stock3
    jmp twoScout3Listed
stock3:
    mov ecx, dword ptr [esi+1DCh]
    jmp twoScout3Stock
UhcTwoScout3Hook ENDP

; 0x77DFF4: mov edx,[0C66234h] (6 B).
UhcTwoScout4Hook PROC
    TRACE_ONCE "twoScoutCivs hero UI 4 (0x77DFF4)"
    push eax
    push ecx
    push dword ptr [esi+1DCh]
    call UhcIsTwoScoutCiv
    test al, al
    pop ecx
    pop eax
    jz stock4
    jmp twoScout4Listed
stock4:
    mov edx, dword ptr ds:[0C66234h]
    jmp twoScout4Stock
UhcTwoScout4Hook ENDP

; --- nativeCivs ------------------------------------------------------------------------------

; Tests EAX against the listed native civs with ECX and EDX preserved; ZF clear if listed.
NATIVE_TEST MACRO
    push ecx
    push edx
    push eax
    call UhcIsNativeCiv
    pop edx
    pop ecx
    test al, al
ENDM

; 0x52B581, the end of the civs.xml loader: lea ecx,[esp+100h] (7 B). EDI = the database, EBX =
; the value the loader stores at [civ+10h] for the stock native civs.
UhcNativeCivMarkHook PROC
    TRACE_ONCE "nativeCivs civ flags (0x52B581)"
    pushad
    push ebx
    push edi
    call UhcMarkNativeCivs
    popad
    lea ecx, [esp+100h]
    jmp nativeMarkReturn
UhcNativeCivMarkHook ENDP

; 0x51271F in FUN_00512651 (bool cdecl(civ), EAX = civ): cmp eax,[0C6FB58h] / je 51272Ah (8 B).
UhcNativeCivTest2Hook PROC
    TRACE_ONCE "nativeCivs test 2 (0x51271F)"
    cmp eax, dword ptr ds:[0C6FB58h]
    je yes2
    NATIVE_TEST
    jnz yes2
    jmp native2False
yes2:
    jmp native2True
UhcNativeCivTest2Hook ENDP

; 0x453D5E in isNativeCiv (0x453D37, bool thiscall(player, bool extended)): cmp byte [esp+4],0 /
; je 453D6Dh / cmp eax,[0C6FB5Ch] / je 453D72h (15 B). The byte is compared as a byte.
UhcNativeCivTest4Hook PROC
    TRACE_ONCE "nativeCivs isNativeCiv (0x453D5E)"
    cmp byte ptr [esp+4], 0
    je listed4
    cmp eax, dword ptr ds:[0C6FB5Ch]
    je yes4
listed4:
    NATIVE_TEST
    jnz yes4
    jmp native4False
yes4:
    jmp native4True
UhcNativeCivTest4Hook ENDP

; 0x67B0A5 (FUN_00490960's loop): cmp eax,[0C6FB58h] / je 67B0BBh (8 B).
UhcNativeCivTest7Hook PROC
    TRACE_ONCE "nativeCivs test 7 (0x67B0A5)"
    cmp eax, dword ptr ds:[0C6FB58h]
    je yes7
    NATIVE_TEST
    jnz yes7
    jmp native7False
yes7:
    jmp native7True
UhcNativeCivTest7Hook ENDP

; 0x8D52AF in FUN_008D51D0: je 8D53B4h (6 B), after cmp eax,[0C6FB58h].
UhcNativeCivTest9Hook PROC
    TRACE_ONCE "nativeCivs test 9 (0x8D52AF)"
    je yes9
    NATIVE_TEST
    jnz yes9
    jmp native9False
yes9:
    jmp native9True
UhcNativeCivTest9Hook ENDP

; 0x81ADEB in the council age-up list FUN_0081ABFC: cmp [esp+10h],ebx / mov [esp+20h],eax (8 B).
; [esp+10h] = the player's civ, ESI = the UI object, EDI = the option's offset in [esi+18Ch].
UhcNativeCouncilHook PROC
    TRACE_ONCE "nativeCivs council age-up (0x81ADEB)"
    mov dword ptr [esp+20h], eax
    pushad
    mov eax, dword ptr [esi+18Ch]
    lea eax, [eax+edi+8]
    push eax
    push dword ptr [esp+34h]        ; [esp+10h] before pushad (32 B) and the push above
    call UhcNativeCouncilOption
    mov dword ptr [esp+28], eax     ; EAX's slot in the pushad frame
    popad
    test al, al
    jnz addOption
    mov eax, dword ptr [esp+20h]    ; EAX as the stock code left it
    cmp dword ptr [esp+10h], ebx
    jmp councilStock
addOption:
    jmp councilAdd
UhcNativeCouncilHook ENDP

; 0x461BD8 in the command panel FUN_0046188E: jne 695955h (6 B) after isNativeCiv(EDI = the
; player, true) and test al,al; ESI = the selected unit.
UhcBigButtonHook PROC
    TRACE_ONCE "bigButtonCivs command panel (0x461BD8)"
    pushad
    movzx eax, al
    push esi
    push edi
    push eax
    call UhcBigButtonPath
    mov dword ptr [esp+28], eax     ; EAX's slot in the pushad frame
    popad
    test eax, eax
    jnz native
    jmp bigButtonNone
native:
    jmp bigButtonNative
UhcBigButtonHook ENDP

END
