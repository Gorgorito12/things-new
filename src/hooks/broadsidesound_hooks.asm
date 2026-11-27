; The hook of broadsideSoundSet (features/broadsidesound.cpp): the sound set of a broadside shot, entered through a jmp
; written over the stock push of its name and left through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcBroadsideSoundName PROTO STDCALL :DWORD

.data
soundNext       dd 004CECC2h    ; add edx,14h: the unit's position, then push edx / call 4AA24Ch

.code

; Replaces push 0BA1D5Ch ("ShipCannonShoot", 5 bytes) at 0x4CECBD, in FUN_004CEB37, the broadside fire step's effect
; of one shot (its only caller 0x4CEA02, before the launch 0x4CEA43): EDI = the unit action (the ECX of the call),
; EDX = its unit [edi+10h], ECX = the game [0C66234h], the third argument of 0x4AA24C already pushed. The hook pushes
; the name UhcBroadsideSoundName gives (the stock one when the action has no <BroadsideSoundSet>) and goes on at
; 0x4CECC2, which writes EDX and pushes it, then calls 0x4AA24C(game, position, name, extra). EAX is not read before
; that call writes it; no x87 value is live (the angle was stored at 0x4CEC0D).
UhcBroadsideSoundHook PROC
    TRACE_ONCE "broadsideSoundSet (0x4CECBD)"
    push ecx
    push edx
    push edi
    call UhcBroadsideSoundName          ; EAX = the set's name, ASCII
    pop edx
    pop ecx
    push eax
    jmp soundNext
UhcBroadsideSoundHook ENDP

END
