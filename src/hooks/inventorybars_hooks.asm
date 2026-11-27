; The hook of inventoryBars for units with no HP bar (features/inventorybars.cpp), entered through a jmp written over
; the stock code and left through an explicit jmp to one of its two stock targets (docs/how-it-works.md,
; "inventoryBars").
.686
.model flat, c
option casemap :none

include common.inc

UhcInventoryNoHpBar PROTO STDCALL :DWORD, :DWORD, :DWORD

EXTERNDEF g_uhcInventorySites:DWORD     ; 1 with the bars on units with no HP bar
EXTERNDEF g_uhcInventoryAlways:DWORD    ; 1 with "always"

.data
hpBarChecks     dd 0045F78Bh    ; cmp byte [esp+16h],0: the unit has the HP bar flag; the bar's conditions
noHpBar         dd 00452F23h    ; mov eax,[esi+0B4h]: no HP bar for this unit
flagTest        dd 00452EDCh    ; sub esp,4: the inlined test of proto flag 5

.code

; Replaces test al,al / jne 45F78Bh (8 bytes) at 0x452F1B in FUN_00451F9D, the unit visual update: AL = proto flag 5
; (the HP bar flag) of unit ESI, BL = the Alt state (0x452EBD). A unit with the flag goes on to the stock bar
; conditions. A unit without it (a mine, a tree, a bush) while Alt is held, or always with "always", is given to
; UhcInventoryNoHpBar with [esp+48h], the pointer to its position that the bar chunk's fallback (0x460633) reads in
; this same frame. Both targets write EAX, ECX, EDX and the flags before they read them (0x45F78B cmp, 0x452F23 mov /
; fld / fcomp).
UhcInventoryNoHpBarHook PROC
    TRACE_ONCE "inventoryBars no HP bar (0x452F1B)"
    test al, al
    jne hasFlag
    cmp g_uhcInventorySites, 0
    je done
    test bl, bl
    jne queue
    cmp g_uhcInventoryAlways, 0
    je done
queue:
    pushad
    movzx eax, bl
    push eax                        ; Alt held
    push dword ptr [esp+24h+48h]    ; the position pointer
    push esi                        ; unit
    call UhcInventoryNoHpBar
    popad
done:
    jmp noHpBar
hasFlag:
    jmp hpBarChecks
UhcInventoryNoHpBarHook ENDP

; Replaces test al,al / je 452F23h / push 5 / mov ecx,esi (8 bytes) at 0x452ED4, right after the unit's vtable +A4h
; test (0x452ECF; false for a corpse, which stock never gives an HP bar): AL = its result, BL = Alt, ESI = the unit.
; A unit that passes goes on with the re-executed push 5 / mov ecx,esi at 0x452EDC (the inlined test of proto flag 5,
; then the hook above). One that fails (a hunted animal's corpse that settlers gather) is given to
; UhcInventoryNoHpBar like a unit with no HP bar, then goes to the stock target 0x452F23.
UhcInventoryCorpseHook PROC
    TRACE_ONCE "inventoryBars corpse (0x452ED4)"
    test al, al
    je corpse
    push 5                          ; stolen 0x452ED8
    mov ecx, esi                    ; stolen 0x452EDA
    jmp flagTest
corpse:
    cmp g_uhcInventorySites, 0
    je skip
    test bl, bl
    jne queue
    cmp g_uhcInventoryAlways, 0
    je skip
queue:
    pushad
    movzx eax, bl
    push eax                        ; Alt held
    push dword ptr [esp+24h+48h]    ; the position pointer
    push esi                        ; unit
    call UhcInventoryNoHpBar
    popad
skip:
    jmp noHpBar
UhcInventoryCorpseHook ENDP

END
