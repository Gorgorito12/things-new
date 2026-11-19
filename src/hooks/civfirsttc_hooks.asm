; Hooks for civFirstTC. Entered through a jmp written over the stock code; each leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Civ first town center"). The
; FirstTC test is in startingtc_hooks.asm (UhcStartingTcProtoHook), shared with startingTC, and the
; map placement wrapper is C++ (UhcRmPlaceObjectDef in features/civfirsttc.cpp).
.686
.model flat, c
option casemap :none

include common.inc

UhcCivTagDispatch PROTO STDCALL node:DWORD, civ:DWORD  ; civtags.cpp; true: a registered tag, consumed
UhcCivFirstTcTownProto PROTO STDCALL player:DWORD      ; the proto for the town units, or -1
UhcCivFirstTcColonyFlag PROTO STDCALL unit:DWORD       ; true: this unit counts as StartingColonyBuilding

.data
civTagResume    dd 0052BB0Fh    ; jle 52B43Dh / jmp 52C066h: the stock unknown-tag path, on the flags
civTagNext      dd 0052B43Dh    ; the next child of the <civ> node
colonyFlagResume dd 006A2136h   ; and eax,1 / mov [esp+74h],eax: the rest of the test of flag 136
townQueryResume dd 00679ACEh    ; push ebp / push esi / mov esi,[edi+80h]: the query of proto EBX

.code

; Replaces 0x52BB07..0x52BB0E (xor edi,edi / cmp dword ptr [ebx+80h],edi) in the civs.xml
; parser FUN_0052A590: a child tag of <civ> that matched none of the stock names. ESI = the node,
; EBX = database, [esp+10h] = the civ. UhcCivTagDispatch (civtags.cpp, shared by civFirstTC and
; sharedBuildLimit) reads a registered tag and the hook goes to the next child, as every stock
; handler does; any other tag runs the stock path (the resource names, then a silent skip).
; 0x52B43D reads only the stack.
UhcCivTagsHook PROC
    TRACE_ONCE "civ tags civs.xml (0x52BB07)"
    pushad
    push dword ptr [esp+30h]        ; the civ: [esp+10h] at entry, +20h for pushad
    push esi                        ; the node
    call UhcCivTagDispatch
    mov dword ptr [esp+1Ch], eax    ; popad's EAX slot
    popad
    test al, al
    jne nextChild
    xor edi, edi                    ; stolen 0x52BB07
    cmp dword ptr [ebx+80h], edi    ; stolen 0x52BB09: the flags the jle at 0x52BB0F reads
    jmp civTagResume
nextChild:
    jmp civTagNext
UhcCivTagsHook ENDP

; Replaces 0x679AC8..0x679ACD (mov ebx,[ecx+5E08h]) in FUN_0049039A, which gives the civ's
; <townstartingunit> units to the first built unit of proto EBX (stock: TownCenter) when a colony
; starts at it. EDI = player. EAX, ECX and EDX are written before they are read after 0x679ACE.
; UhcCivFirstTcTownProto returns the civ's <firstTC> proto when the player's FirstTC is such a
; building with a colony; otherwise EBX stays TownCenter.
UhcCivFirstTcTownHook PROC
    TRACE_ONCE "civFirstTC town units (0x679AC8)"
    mov ebx, dword ptr [ecx+5E08h]  ; stolen 0x679AC8: TownCenter
    push edi
    call UhcCivFirstTcTownProto
    test eax, eax
    jl done
    mov ebx, eax
done:
    jmp townQueryResume
UhcCivFirstTcTownHook ENDP

; Replaces 0x6A2130..0x6A2135 with the key firstTC, at the creation of a unit, ESI: the test of flag 136 of its
; proto, StartingColonyBuilding. A civ's <firstTC> building counts as having it, without writing the proto,
; which every civ shares. AL is what `and eax,1` reads; EAX's other bytes do not matter there.
UhcCivFirstTcColonyHook PROC
    TRACE_ONCE "firstTC colony flag (0x6A2130)"
    mov edx, dword ptr [eax+50h]    ; stolen 0x6A2130
    mov al, byte ptr [edx+11h]      ; stolen 0x6A2133
    test al, 1
    jne done
    push eax
    push ecx
    push edx
    push esi
    call UhcCivFirstTcColonyFlag
    test al, al
    pop edx
    pop ecx
    pop eax
    je done
    or al, 1
done:
    jmp colonyFlagResume
UhcCivFirstTcColonyHook ENDP

END
