; Hooks for removeFameRestriction. Entered through jmps (or jump-table slots) written over the
; stock code; each leaves through an explicit jmp to a verified continuation
; (src/generated/sites.h).
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcXpIcon:SDWORD
EXTERNDEF g_uhcFameIcon:SDWORD
EXTERNDEF g_uhcXpIconPath:WORD
EXTERNDEF g_uhcFameIconPath:WORD

.data
loadIcon          dd 0058E3EBh  ; int thiscall(this, const wchar_t* path, bool, int, int)
fameIconsReturn   dd 005C1E37h  ; call 58E3EBh for the trade-route icon
setIconCase       dd 009A2098h  ; mov ecx,esi / push eax / call 593D42h (set icon = EAX)
defaultIconCase   dd 009A20A0h  ; no icon
costReset         dd 0058F070h
costAmount        dd 0044EFFFh
costSet           dd 0058EF83h
costOwner         dd 004539D3h
textAppend        dd 004439E3h
textAppendLiteral dd 00443960h
politicianReturn  dd 0080E496h  ; push ecx / mov ecx,edi / call [eax+80h]
politician2Return dd 00819443h  ; push eax / mov ecx,esi / call [edx+80h]

.code

; One cost line for resource `resource`. This is the block the stock functions repeat for each
; resource they show (e.g. 0x80E41D..0x80E48F for resource 7). Stack-neutral: every callee
; pops its arguments. `owner` is the register stock passes to 0x4539D3 in that function.
COST_LINE MACRO resource:REQ, owner:REQ
    lea ecx, [esp+28h]
    call costReset
    push resource
    lea ecx, [esp+34h]
    call costAmount
    push ecx
    fstp dword ptr [esp]
    push resource
    lea ecx, [esp+30h]
    call costSet
    mov edx, dword ptr ds:[0C66234h]
    mov ebx, dword ptr [edx]
    mov ecx, owner
    call costOwner
    push eax
    push 1
    push 1
    push 1
    lea eax, [esp+28h]
    push eax
    lea ecx, [esp+3Ch]
    push ecx
    mov ecx, dword ptr ds:[0C66234h]
    call dword ptr [ebx+134h]
    push -1
    push -1
    lea edx, [esp+20h]
    push edx
    lea ecx, [esp+20h]
    call textAppend
    push -1
    push -1
    push 0B9FFDCh
    lea ecx, [esp+20h]
    call textAppendLiteral
ENDM

; Detour at 0x80E490 (FUN_0080E20A). Stock lists resources 2, 1, 0 and 7; add fame (3),
; XP (5) and shipments (6). The owner is ESI in this function.
UhcPoliticianCostsHook PROC
    TRACE_ONCE "removeFameRestriction costs #1 (0x80E490)"
    COST_LINE 3, esi
    COST_LINE 5, esi
    COST_LINE 6, esi
    mov eax, dword ptr [edi]        ; stolen 0x80E490
    lea ecx, [esp+14h]              ; stolen 0x80E492
    jmp politicianReturn
UhcPoliticianCostsHook ENDP

; Detour at 0x81943D (FUN_0081922A). Stock lists resources 2, 1, 0; add 3, 5, 6 and 7 (export).
; The owner is EDI here (ESI is the UI object, the wrong owner).
UhcPoliticianCosts2Hook PROC
    TRACE_ONCE "removeFameRestriction costs #2 (0x81943D)"
    COST_LINE 3, edi
    COST_LINE 5, edi
    COST_LINE 6, edi
    COST_LINE 7, edi
    mov edx, dword ptr [esi]        ; stolen 0x81943D
    lea eax, [esp+14h]              ; stolen 0x81943F
    jmp politician2Return
UhcPoliticianCosts2Hook ENDP

; Replaces 0x5C1E1F..0x5C1E36. Stock: call 58E3EBh (arguments already pushed, ECX = EDI), then
; the pushes for the next icon, mov ecx,edi and mov [esi+168h],eax. Two extra icons are loaded
; in between, for the jump-table cases below.
UhcFameIconsHook PROC
    TRACE_ONCE "removeFameRestriction icon load (0x5C1E1F)"
    call loadIcon                   ; stolen call
    mov dword ptr [esi+168h], eax
    push -1
    push 0
    push 0
    push OFFSET g_uhcXpIconPath
    mov ecx, edi
    call loadIcon
    mov g_uhcXpIcon, eax
    push -1
    push 0
    push 0
    push OFFSET g_uhcFameIconPath
    mov ecx, edi
    call loadIcon
    mov g_uhcFameIcon, eax
    push -1                         ; stock 0x5C1E24..0x5C1E2F
    push 0
    push 0
    push 0BA96C4h
    mov ecx, edi
    jmp fameIconsReturn
UhcFameIconsHook ENDP

; Jump-table cases 3 (fame) and 5 (XP) of the resource-icon switch at 0x9A2180. Stock sends both
; to the default case, which sets no icon. A missing icon (-1) keeps that default.
UhcFameIconCase PROC
    TRACE_ONCE "removeFameRestriction fame icon case (0x9A218C)"
    mov eax, g_uhcFameIcon
    cmp eax, -1
    je noIcon
    jmp setIconCase
noIcon:
    jmp defaultIconCase
UhcFameIconCase ENDP

UhcXpIconCase PROC
    TRACE_ONCE "removeFameRestriction XP icon case (0x9A2194)"
    mov eax, g_uhcXpIcon
    cmp eax, -1
    je noIcon
    jmp setIconCase
noIcon:
    jmp defaultIconCase
UhcXpIconCase ENDP

END
