; Hooks for nativePreview, in the bottom panel chooser FUN_00454270 and in the command panel refresh
; FUN_0046188E. Each is entered through a jmp written over the stock code and leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Native socket preview"). Nothing
; here writes game state: the hooks only change which panel shows, which entries the command panel
; collects and how it draws them.
.686
.model flat, c
option casemap :none

include common.inc

UhcNpChooserPreview PROTO STDCALL unit:DWORD
UhcNpGate PROTO STDCALL selection:DWORD
UhcNpTakeEntry PROTO STDCALL entry:DWORD

EXTERN g_uhcNpActive:DWORD      ; nativepreview.cpp: 1 while the refresh builds a socket's preview
EXTERN g_uhcNpEntries:DWORD     ; the building proto's command entries ([proto+0E8h])

.data
socketPanelNext dd 00645FF3h    ; mov eax,[esi+5Ch]: the trade route socket test, then the settlement panel
socketPanelSkip dd 00454354h    ; the end of the unit tests, as for a unit none of them claims
subCivNext      dd 0064612Bh    ; cmp al,0FFh after the <SubCiv> read
subCivSkip      dd 00646163h    ; the chooser's next test, as for a unit with no <SubCiv>
gateNext        dd 00461947h    ; cmp edx,[ecx+3C0h]: the selection's player against the local one
protoNext       dd 00461BC6h    ; push 1, after EBX = the proto's command entries
collectNext     dd 004C58B3h    ; je 6959D1h: the Train branch of the collection
collectAppend   dd 004C59F5h    ; the collection's append of the entry (index, column, page)
collectSkip     dd 00461C3Fh    ; the collection loop's next entry
techNext        dd 004620C0h    ; call 4C6968h: can this unit research the tech
techBuild       dd 00462172h    ; the tech button's build-up (rollover, icon, cost)
layoutNext      dd 0046268Ah    ; the layout's next entry
buttonNext      dd 0046231Eh    ; jge 69700Dh: the grid is full

.code

; 0x645FE7: mov ecx,[0C66234h] / mov edx,[ecx+140h] (12 B), in the chooser's branch for a selected
; unit of type Socket (4Bh), which ends with the settlement panel in place of the command panel.
; ESI = the unit; EAX, ECX and EDX are dead at both continuations (each reloads what it reads), and
; the stack is the chooser's frame at both (0x4BC5D7 jumps to 0x454354 from the same level). A
; socket that gets a preview goes on at 0x454354 as a unit no test claims: [esp+12h] stays 1, so
; the chooser keeps the command grid ([grid+342h] = 0, set by 0x45447D) and its refresh runs.
UhcNpSocketPanelHook PROC
    TRACE_ONCE "nativePreview chooser socket (0x645FE7)"
    push esi
    call UhcNpChooserPreview        ; -> al = 1: preview
    test al, al
    jne preview
    mov ecx, dword ptr ds:[0C66234h]
    mov edx, dword ptr [ecx+140h]
    jmp socketPanelNext
preview:
    jmp socketPanelSkip
UhcNpSocketPanelHook ENDP

; 0x646124: mov ecx,ebx / call 4BC54Ah (7 B), the <SubCiv> read of the chooser's test that hides the
; command panel for a native socket. EBX = the unit. The stock call (it returns the byte
; [[unit+5Ch]+1D1h] in AL) is made here for any other unit; a socket that gets a preview goes on at
; 0x646163, as a unit without one. ECX and EDX are dead at both continuations.
UhcNpSubCivHook PROC
    TRACE_ONCE "nativePreview chooser sub-civ (0x646124)"
    push ebx
    call UhcNpChooserPreview        ; -> al = 1: preview
    test al, al
    jne preview
    mov ecx, ebx
    mov eax, 004BC54Ah
    call eax
    jmp subCivNext
preview:
    jmp subCivSkip
UhcNpSubCivHook ENDP

; 0x46193E: mov edx,[eax+0Ch] / mov ecx,[0C66234h] (9 B). EAX = the selection (count >= 1 checked
; above), EBX = the panel, ESI = 0; the stock compares EDX with the local player at 0x461947 and
; leaves the refresh when they differ. The helper returns the selection's player, or the local
; player when the selection is a native socket that gets a preview. EAX, EBX, ESI, EDI and EBP are
; kept; ECX is reloaded as in stock.
UhcNpGateHook PROC
    TRACE_ONCE "nativePreview gate (0x46193E)"
    push eax
    push eax
    call UhcNpGate                  ; -> eax = the player to compare with the local one
    mov edx, eax
    pop eax
    mov ecx, dword ptr ds:[0C66234h]
    jmp gateNext
UhcNpGateHook ENDP

; 0x461BBD: mov ebx,[esi+5Ch] / add ebx,0E8h (9 B). ESI = the selected unit. In a preview EBX gets
; the building's command entries instead of the socket proto's (which has none). No flag is read
; before the next write.
UhcNpProtoHook PROC
    TRACE_ONCE "nativePreview entries (0x461BBD)"
    cmp g_uhcNpActive, 0
    jne preview
    mov ebx, dword ptr [esi+5Ch]
    add ebx, 0E8h
    jmp protoNext
preview:
    mov ebx, g_uhcNpEntries
    jmp protoNext
UhcNpProtoHook ENDP

; 0x4C58AD: mov cl,[esi+eax+2] / test cl,cl (6 B), the kind test of the collection loop. EAX = the
; entries, ESI = 6 * index, EBX = &entries. In a preview the helper decides: an entry of the
; native goes straight to the append (the stock availability tests and the unit's action check
; would drop it), any other entry to the next one. ECX and EDX are dead at both targets.
UhcNpCollectHook PROC
    TRACE_ONCE "nativePreview collection (0x4C58AD)"
    cmp g_uhcNpActive, 0
    jne preview
    mov cl, byte ptr [esi+eax+2]
    test cl, cl
    jmp collectNext
preview:
    push eax
    lea ecx, [eax+esi]
    push ecx
    call UhcNpTakeEntry             ; -> al = 1: show it
    test al, al
    pop eax
    jne take
    jmp collectSkip
take:
    jmp collectAppend
UhcNpCollectHook ENDP

; 0x4620B9: mov edi,[esp+28h] / push edi / mov ecx,esi (7 B), before the call of 0x4C6968 in the
; tech branch of the layout. ESI = the player's tech entry, [esp+20h] = the player. In a preview the
; tech skips the "can research here" test and the status tests (the socket has no actions and the
; tech is not obtainable for the player), but keeps the stock prerequisite test of 0x462115..
; 0x462136: 0x4C7330, then 0x4C5DDA, whose -1 (a tech prerequisite not met) hides the tech and
; whose age index goes to [esp+6Ch] for the age mark. It then goes to the stock build-up as a
; disabled button ([esp+24h] = 1), with EBX = the player as at 0x4C6918. Both calls are thiscall
; on the tech entry and keep EBX, ESI, EDI and EBP.
UhcNpTechLayoutHook PROC
    TRACE_ONCE "nativePreview tech button (0x4620B9)"
    mov edi, dword ptr [esp+28h]
    cmp g_uhcNpActive, 0
    jne preview
    push edi
    mov ecx, esi
    jmp techNext
preview:
    mov ebx, dword ptr [esp+20h]
    push edi
    mov ecx, esi
    mov eax, 004C7330h
    call eax                        ; al = 1: no prerequisite to show
    test al, al
    jne build
    push edi
    push ebx
    mov ecx, esi
    mov eax, 004C5DDAh
    call eax                        ; eax = -1: hidden; else the age it waits for
    test eax, eax
    jl hidden
    mov dword ptr [esp+6Ch], eax
build:
    mov dword ptr [esp+24h], 1
    jmp techBuild
hidden:
    jmp layoutNext
UhcNpTechLayoutHook ENDP

; 0x462317: mov ebx,[esp+1Ch] / cmp ebx,6 (7 B), where every grid button joins before it is placed.
; In a preview the button is disabled ([esp+24h] = 1; its age mark [esp+6Ch] stays as the stock
; code set it) and has no command for a click or a shift-click (the strings at [esp+1C0h] and
; [esp+3C0h]). The flags of the stolen cmp reach the jge at the continuation.
UhcNpButtonHook PROC
    TRACE_ONCE "nativePreview button (0x462317)"
    cmp g_uhcNpActive, 0
    je stock
    mov dword ptr [esp+24h], 1
    mov byte ptr [esp+1C0h], 0
    mov byte ptr [esp+3C0h], 0
stock:
    mov ebx, dword ptr [esp+1Ch]
    cmp ebx, 6
    jmp buttonNext
UhcNpButtonHook ENDP

END
