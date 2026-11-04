; Hook for unitResourceAuras. Entered through a jmp written over the stock code; it leaves through
; an explicit jmp to a verified continuation, or returns for the stock function it replaces
; (docs/engine-symbols.md, "Resource auras").
.686
.model flat, c
option casemap :none

include common.inc

UhcUnitResourceAura PROTO STDCALL action:DWORD

kStatUnitResource EQU 41h           ; the new ModifyType stat; unitresource.cpp uses the same value

.data
auraNext    dd 009D0343h            ; sub esp,10h: the aura update after its first instruction

.code

; Replaces 0x9D033E (mov eax,[0C66234h]), the first instruction of the aura update FUN_009D033E,
; void thiscall(action), a plain ret. ECX = the unit action, [ecx+4] its tactics action, whose
; ModifyType is the byte [+B8h]. An aura of the new stat is handled by the helper and the stock
; update does not run: it would give each target a modifier. EAX, ECX and EDX are free here.
UhcUnitResourceAuraHook PROC
    mov eax, dword ptr [ecx+4]
    test eax, eax
    je stock
    cmp byte ptr [eax+0B8h], kStatUnitResource
    jne stock
    TRACE_ONCE "unitResourceAuras (0x9D033E)"
    push ecx
    call UhcUnitResourceAura
    ret
stock:
    mov eax, ds:[0C66234h]          ; stolen 0x9D033E
    jmp auraNext
UhcUnitResourceAuraHook ENDP

END
