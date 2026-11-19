; Hooks for customHotkeyContexts (features/hotkeys.cpp). Two replace a stock call (written as a
; call to the hook, which returns to the stock return address); two are entered through a jmp and
; leave through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Hotkey
; contexts").
.686
.model flat, c
option casemap :none

include common.inc

UhcHotkeyContextFor PROTO STDCALL dbProto:DWORD, unit:DWORD
UhcHotkeyTrainerHasContext PROTO STDCALL unit:DWORD
UhcHotkeyTipAddContexts PROTO STDCALL list:DWORD
UhcHotkeyTipFindBuild PROTO STDCALL

EXTERNDEF g_uhcHotkeyFindContext:DWORD      ; int fastcall(manager, -, name, record), ret 8
EXTERNDEF g_uhcHotkeyDeactivateAll:DWORD    ; int fastcall(manager, -, name, flag), ret 8

.data
unitContextNext     dd 0079F89Dh    ; test edi,edi / jge 79F9BFh: turn context EDI on
trainerQualified    dd 0064A05Ah    ; mov bl,1 / mov edi,esi: the unit enters its own context
trainerNext         dd 0064A05Ch    ; mov edi,esi: the target of the stock jmp after the stolen mov
tipListNext         dd 008F969Ch    ; mov eax,[edx+74h]: the context list is done
tipBuildFound       dd 008F9102h    ; a key was found: its text goes out
tipBuildMissing     dd 008F96AFh    ; no key: return false

.code

; Called by the call at 0x5C1778 in FUN_005C16EA (applies DefaultKeyMapY.xml), which called
; 0x5C16AB: find the entry's context, thiscall(manager, &entry->Context, &record), ret 8. ECX =
; the manager and the arguments are in place, so the fastcall wrapper takes the frame as its own
; and returns to 0x5C177D (cmp eax,3 / je: 3 drops the entry). EAX, ECX and EDX are not preserved
; by the stock call either.
UhcHotkeyFindContextHook PROC
    TRACE_ONCE "customHotkeyContexts (0x5C1778)"
    jmp g_uhcHotkeyFindContext
UhcHotkeyFindContextHook ENDP

; Called by the call at 0x79F1A5 in FUN_0079EF9C (switches off the 35 stock unit contexts before a
; selection turns one on), which called 0x4421F3 for "WonderAccel": thiscall(manager, name, flag),
; ret 8. As above, the wrapper takes the frame and returns to 0x79F1AA (pop esi / ret); ESI is
; callee-saved in the wrapper.
UhcHotkeyDeactivateHook PROC
    TRACE_ONCE "customHotkeyContexts (0x79F1A5)"
    jmp g_uhcHotkeyDeactivateAll
UhcHotkeyDeactivateHook ENDP

; Replaces mov edi,[esi+178h] at 0x79F897 in FUN_0079F851, which turns on the selected unit's
; context. ESI = the unit's database proto ([proto+178h] = its context from the stock proto table,
; -1 = none), EBP = the unit; EDI was saved by the push just before. A proto with an added
; <ProtoName>Accel context gets that one instead. The continuation sets the flags it reads
; (test edi,edi), and EAX, ECX and EDX are reloaded on both of its paths.
UhcHotkeyContextHook PROC
    TRACE_ONCE "customHotkeyContexts (0x79F897)"
    push ebp
    push esi
    call UhcHotkeyContextFor        ; -> the added context's ID, or -1
    test eax, eax
    jl stock
    mov edi, eax
    jmp unitContextNext
stock:
    mov edi, dword ptr [esi+178h]   ; stolen 0x79F897
    jmp unitContextNext
UhcHotkeyContextHook ENDP

; Replaces mov byte ptr [esp+13h],1 at 0x64A034 in the selection chunk 0x649FA4. A selected unit
; with a <Train> list that is not a Building only sets that byte ("turn BuildAccel on") and never
; enters a context of its own; a Building takes 0x64A05A (BL = 1: call FUN_0079F851 with EDI =
; this unit). ESI = the unit. A unit whose proto has an added context takes the Building path
; (without BuildAccel); any other unit runs the stock code. Also reached from 0x64A027 (no proto),
; where the C++ test is false. EAX, ECX and EDX are reloaded after both continuations, and no flag
; is read before an instruction there sets it.
UhcHotkeyTrainerHook PROC
    TRACE_ONCE "customHotkeyContexts (0x64A034)"
    push esi
    call UhcHotkeyTrainerHasContext ; -> AL = 1 if its proto has an added context
    test al, al
    jne qualifies
    mov byte ptr [esp+13h], 1       ; stolen 0x64A034: turn BuildAccel on
    jmp trainerNext                 ; as the stock jmp 64A05Ch at 0x64A039
qualifies:
    jmp trainerQualified
UhcHotkeyTrainerHook ENDP

; Replaces mov edx,[0C66244h] at 0x8F9696 in FUN_008F8F5E, which writes the hotkey text of a proto's
; tooltip. The function builds a list of the 37 stock context names at [esp+18h] and looks the unit's
; tis("name") up in each. The added contexts join that list here, after the stock names, so a stock
; mapping is found first. EDX is what the stolen read loads, and nothing else is live but the
; callee-saved registers.
UhcHotkeyTipListHook PROC
    TRACE_ONCE "customHotkeyContexts tooltip (0x8F9696)"
    lea eax, [esp+18h]
    push eax
    call UhcHotkeyTipAddContexts
    mov edx, dword ptr ds:[0C66244h]    ; stolen 0x8F9696
    jmp tipListNext
UhcHotkeyTipListHook ENDP

; Replaces jle 8F96AFh at 0x8F90FC. A proto with the Building bit is looked up in BuildAccel only.
; With no key there, the added contexts are tried. The flags are those of the stock test eax,eax.
UhcHotkeyTipBuildHook PROC
    jg found
    TRACE_ONCE "customHotkeyContexts tooltip, building (0x8F90FC)"
    call UhcHotkeyTipFindBuild
    test eax, eax
    jg found
    jmp tipBuildMissing
found:
    jmp tipBuildFound
UhcHotkeyTipBuildHook ENDP

END
