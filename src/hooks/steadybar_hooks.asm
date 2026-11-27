; Hook for steadyHitpointBars. Entered through a jmp written over the stock code and left through
; an explicit jmp to a verified continuation (docs/how-it-works.md, "steadyHitpointBars").
;
; The floating bar chunk of the unit visual update (0x45FAE2..0x45FB6C): 0x45F22D(tag, 0, &v, 0, 0)
; returns AL = 1 when the current animation has the HITPOINTBAR tag, and then wrote its position in
; model space to v at [esp+2Ch]. Stock then tests AL (test al,al / jz 460633h at 0x45FB24, 8 bytes):
; with the tag it goes on at 0x45FB2C, which takes v to the world (0x406BDB) with the unit's matrix
; [esp+74h]; without it the cold block 0x460633 places the bar at the unit's position plus a height
; from data. The hook asks UhcSteadyBarLocal(unit, &v, AL): 1 = v holds the unit's steady position
; (go on at 0x45FB2C), 0 = no steady position, the stock fallback (0x460633). ESI = the unit.
; EAX, ECX, EDX and the flags are written before they are read on both paths (0x45FB2C: lea ecx /
; push ecx / lea edx; 0x460633: mov eax,[esp+48h] / mov ecx,[eax] / mov edx,[eax+4]); the helper
; keeps EBX, ESI, EDI and EBP, and the x87 stack is empty here and after it.
.686
.model flat, c
option casemap :none

include common.inc

UhcSteadyBarLocal PROTO STDCALL unit:DWORD, modelPos:DWORD, found:DWORD

.data
steadyBarNext     dd 0045FB2Ch  ; lea ecx,[esp+18h] / push ecx / lea edx,[esp+30h] / push edx / call 406BDBh
steadyBarFallback dd 00460633h  ; the stock position without the tag: the unit's position + a height

.code

UhcSteadyBarHook PROC
    TRACE_ONCE "steadyHitpointBars bar position (0x45FB24)"
    movzx eax, al                   ; 1: the tag was found and v holds it
    lea ecx, [esp+2Ch]              ; v: the tag's position in model space
    push eax
    push ecx
    push esi                        ; the unit
    call UhcSteadyBarLocal
    test al, al
    jz noSteady
    jmp steadyBarNext
noSteady:
    jmp steadyBarFallback
UhcSteadyBarHook ENDP

END
