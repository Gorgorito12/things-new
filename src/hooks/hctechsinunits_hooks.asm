; homeCityTechsInUnits (src/features/hctechsinunits.cpp): a HomeCity tech researched in a unit or a building whose
; proto lists it. Both hooks are in the Research action (vtable 0xB98078): its start 0x9E667A and its update 0x9E648B.
.686
.model flat, c
option casemap :none

include common.inc

UhcHcTechAllowed PROTO STDCALL action:DWORD, status:DWORD
EXTERN g_uhcHcGatherCheck:DWORD

.data
startAccepted dd 009E67DBh      ; lea ebx,[esi+10h]: the payment (0x9E67E1) and the rest of the start
startRefused  dd 009E67C5h      ; xor al,al: the start fails, nothing paid
gatherNext    dd 009E655Ch      ; test al,al: AL = 1 runs the land gather point check

.code

; 0x9E67CE: push 12h / mov ecx,esi / call 44D863h / cmp al,1 / je 9E67C5h (13 B), the start's refusal of a HomeCity
; tech, after the can-research test 0x9E670B passed. ESI = the player's status of the tech, EDI = the player,
; EBP = the action ([action+10h] the unit). A tech without the HomeCity flag goes on as in stock; a HomeCity tech
; goes on when UhcHcTechAllowed says the unit's proto lists it. ECX and EDX are dead at both continuations (the
; payment reloads ECX from EDI; the failure path returns).
UhcHcTechStartHook PROC
    TRACE_ONCE "homeCityTechsInUnits research start (0x9E67CE)"
    push 12h
    mov ecx, esi
    mov eax, 0044D863h
    call eax                        ; al = 1: the HomeCity flag
    cmp al, 1
    jne accepted
    push esi
    push ebp
    call UhcHcTechAllowed
    test al, al
    je refused
accepted:
    jmp startAccepted
refused:
    jmp startRefused
UhcHcTechStartHook ENDP

; 0x9E6553: push 1Eh / mov ecx,ebx / call 44D863h (9 B) in the Research update: AL = the CheckLandHCGatherPoint
; flag, tested at 0x9E655C (set: with a home city and no land gather point the research is cancelled and refunded,
; state 13h). EBX = the status, EDI = the player. A HomeCity tech without CheckWaterHCGatherPoint gets AL = 1 here,
; so it waits for a land gather point as the council techs do (g_uhcHcGatherCheck, on unless `nogathercheck`).
; Only a HomeCity tech this key let through is ever researched by a Research action. ECX and EDX are reloaded by
; both paths after 0x9E655C.
UhcHcTechGatherHook PROC
    TRACE_ONCE "homeCityTechsInUnits gather point check (0x9E6553)"
    push 1Eh
    mov ecx, ebx
    mov eax, 0044D863h
    call eax
    test al, al
    jne done
    cmp g_uhcHcGatherCheck, 0
    je done
    push 12h
    mov ecx, ebx
    mov eax, 0044D863h
    call eax                        ; the HomeCity flag
    test al, al
    je done
    push 1Fh
    mov ecx, ebx
    mov eax, 0044D863h
    call eax                        ; CheckWaterHCGatherPoint: the stock water check follows
    test al, al
    mov al, 1
    je done
    xor al, al
done:
    jmp gatherNext
UhcHcTechGatherHook ENDP

END
