; Hooks for startingTC. Entered through a jmp written over the stock code; each leaves through an
; explicit jmp to a verified continuation (docs/engine-symbols.md, "Starting town center").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcStartingTcType:SDWORD   ; marker unittype ID, set on each database load; -1 before
EXTERNDEF g_uhcStartingTcLog:SDWORD    ; 1 with "startingTC ... log"
EXTERNDEF g_uhcCivFirstTcOn:SDWORD     ; 1 with civFirstTC (features/civfirsttc.cpp)

UhcStartingTcFirst PROTO STDCALL player:DWORD, unit:DWORD
UhcStartingTcStale PROTO STDCALL player:DWORD, unit:DWORD
UhcCivFirstTcMatches PROTO STDCALL player:DWORD, protoId:DWORD, unit:DWORD

.data
protoIsType     dd 0044D7FAh    ; bool thiscall(proto, int unitTypeId): proto IDs and abstract types
firstTcChunk    dd 00506B2Ah    ; stock: EAX = the unit's proto ID, ECX = database, then the TownCenter compare
firstTcSet      dd 0067ABD4h    ; mov ecx,[edi+10h] / mov [esi+4F0h],ecx / jmp 498817h: the unit is FirstTC
addUnitExit     dd 00498817h    ; pop ebx / pop ebp / pop edi / mov al,1 / pop esi / ret 8

.code

; Replaces 0x49880A..0x498816 (cmp dword ptr [esi+4F0h],0 / jl 506B2Ah) at the end of
; Player::addUnit FUN_0049874F. ESI = player, EDI = the unit just added; EBX and EBP are the
; function's. 0x498817 pops EBX, EBP, EDI and ESI and reads no other register and no flag, and
; 0x67ABD4 reads only EDI and ESI. A player whose FirstTC [esi+4F0h] is still -1 runs the stock
; cold chunk (and the proto hook below). For a player that has one, a unit whose proto is of the
; marker type becomes FirstTC when UhcStartingTcStale finds the old one gone, dead or with a
; pending lifespan; every other unit leaves as in stock.
UhcStartingTcGateHook PROC
    TRACE_ONCE "startingTC (0x49880A)"
    cmp dword ptr [esi+4F0h], 0     ; stolen 0x49880A
    jl noFirstTc                    ; stolen 0x498811
    cmp g_uhcStartingTcType, 0
    jl done
    mov ecx, dword ptr [edi+5Ch]    ; the unit's proto
    test ecx, ecx
    je done
    push g_uhcStartingTcType
    call protoIsType
    test al, al
    je done
    push edi
    push esi
    call UhcStartingTcStale         ; true: the old FirstTC no longer counts
    test al, al
    je done
    jmp firstTcSet
done:
    jmp addUnitExit
noFirstTc:
    jmp firstTcChunk
UhcStartingTcGateHook ENDP

; Replaces 0x506B3B..0x506B40 (cmp eax,[ecx+5E08h]) in the cold chunk of Player::addUnit, which
; runs only while the player has no FirstTC. EAX = the unit's exact proto ID, ECX = database,
; EDX = proto, EDI = unit, ESI = player. Stock makes the unit FirstTC only when the ID is
; TownCenter's (jne 498817h / jmp 67ABD4h); the hook also accepts, with civFirstTC, the <firstTC>
; proto of the player's civ and, with startingTC, a unit whose proto is of the marker type.
; Both exits read only EDI and ESI. Installed once for both keys (features/startingtc.cpp).
UhcStartingTcProtoHook PROC
    TRACE_ONCE "FirstTC proto check (0x506B3B)"
    cmp eax, dword ptr [ecx+5E08h]  ; stolen 0x506B3B: TownCenter
    je setFirst
    cmp g_uhcCivFirstTcOn, 0
    je marker
    push edi
    push eax
    push esi
    call UhcCivFirstTcMatches       ; the civ's <firstTC> proto (logs it); clobbers EAX/ECX/EDX
    test al, al
    jne setFirst
marker:
    cmp g_uhcStartingTcType, 0
    jl done
    mov ecx, dword ptr [edi+5Ch]    ; the unit's proto
    test ecx, ecx
    je done
    push g_uhcStartingTcType
    call protoIsType
    test al, al
    je done
    cmp g_uhcStartingTcLog, 0
    je setFirst
    push edi
    push esi
    call UhcStartingTcFirst         ; logs the new FirstTC
setFirst:
    jmp firstTcSet
done:
    jmp addUnitExit
UhcStartingTcProtoHook ENDP

END
