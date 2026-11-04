; Hooks for showGatherRate. Each is entered through a jmp written over the stock code (or, for the
; data ref, through the provider pointer of the registration) and leaves through an explicit jmp
; to a verified continuation (docs/engine-symbols.md, "Gathering and the stat panel").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcGatherRecords:BYTE         ; 4000h records of 20h bytes, by unit ID & 3FFFh
EXTERNDEF g_uhcGatherRowPending:SDWORD    ; 1 while the stock row writer writes our row
EXTERNDEF g_uhcGatherRowRes:SDWORD        ; that row's resource
EXTERNDEF g_uhcGatherRowRate:DWORD        ; that row's rate per second (float)

UhcGatherPanelRow PROTO STDCALL unit:DWORD, selection:DWORD, row:DWORD
UhcGatherRateRef PROTO STDCALL value:DWORD
UhcGatherUnitPanel PROTO STDCALL panel:DWORD, unit:DWORD

; Record layout, shared with features/gatherrate.cpp (GatherRecord).
REC_UNIT        EQU 00h     ; the gatherer's unit ID
REC_ACTION      EQU 04h     ; the Gather action (the tick's this)
REC_RESOURCE    EQU 08h     ; [action+70h]
REC_TARGET      EQU 0Ch     ; [action+14h], the target's unit ID
REC_RATE        EQU 10h     ; float: rate per second times [player+37Ch]
REC_ELAPSED     EQU 14h     ; float: the tick's elapsed seconds
REC_TIME        EQU 18h     ; game time in ms, [world+108h]

.data
gatherTickNext  dd 004ED04Ch    ; fcomp [esp+1Ch]: the amount against what the target holds
panelNext       dd 004D783Bh    ; test ecx,ecx / je 4D784Eh, after the stolen proto load
rowWriter       dd 0069AF7Ch    ; the stock row writer: the label and value gadgets of row EBX
agLoopNext      dd 0069AFE6h    ; mov edx,[ecx+140h]: the stock AutoGather resource loop
unitPanelNext   dd 0069945Ch    ; call 4826B5h: the unit panel goes on, after the stolen load
rowFormat       dd 0069B02Ah    ; the stock row formatter: ESI/EDI gadgets, EBX resource, [esp+1Ch] rate

.code

; Replaces 0x4ED044..0x4ED04B (fmul dword ptr [esp+30h] / fst dword ptr [esp+14h]) in the gather
; tick FUN_004ECD87, on the simulation path. ST0 = R, the rate per second (the x87 stack holds
; only R), before the elapsed time [esp+30h] (the tick's argument) is multiplied in. ESI = the
; Gather action, [esi+10h] = the gatherer (not null, 0x4ECE70), its player [+44h] (not null,
; 0x4ECE78). Writes the gatherer's record in DLL memory only: nothing in the game changes, ST0 and
; the x87 stack are as they were, and EAX/ECX/EDX are restored (the flags are dead: the fcomp /
; fnstsw / test after the continuation set them).
UhcGatherRecordHook PROC
    TRACE_ONCE "showGatherRate record (0x4ED044)"
    push eax
    push ecx
    push edx
    mov ecx, dword ptr [esi+10h]        ; the gatherer
    test ecx, ecx
    je done
    cmp dword ptr [ecx+44h], 0          ; its player
    je done
    cmp dword ptr [esi+70h], 0          ; the resource this tick adds to
    jl done
    mov edx, dword ptr [ecx+10h]        ; the gatherer's unit ID
    test edx, edx
    jl done
    and edx, 3FFFh
    shl edx, 5
    add edx, OFFSET g_uhcGatherRecords
    mov eax, dword ptr [esi+70h]
    mov dword ptr [edx+REC_RESOURCE], eax
    mov dword ptr [edx+REC_ACTION], esi
    mov eax, dword ptr [esi+14h]
    mov dword ptr [edx+REC_TARGET], eax
    mov eax, dword ptr [esp+3Ch]        ; elapsed, the tick's [esp+30h] (3 pushes deeper)
    mov dword ptr [edx+REC_ELAPSED], eax
    mov eax, dword ptr [ecx+44h]        ; the player
    fld st(0)                           ; a copy of R; R itself stays in ST1, untouched
    fmul dword ptr [eax+37Ch]           ; the player's gather multiplier, as 0x4ED13A applies it
    fstp dword ptr [edx+REC_RATE]
    mov eax, dword ptr ds:[0C66234h]    ; game
    mov eax, dword ptr [eax+13Ch]       ; world (the tick reads it with no null test)
    mov eax, dword ptr [eax+108h]       ; game time, ms
    mov dword ptr [edx+REC_TIME], eax
    mov eax, dword ptr [ecx+10h]
    mov dword ptr [edx+REC_UNIT], eax   ; last: the record is complete
done:
    pop edx
    pop ecx
    pop eax
    fmul dword ptr [esp+30h]            ; stolen 0x4ED044
    fst dword ptr [esp+14h]             ; stolen 0x4ED048
    jmp gatherTickNext
UhcGatherRecordHook ENDP

; Replaces 0x4D7834..0x4D783A (mov esi,[esp+38h] / mov ecx,[esi+5Ch]) in the stat panel fill
; FUN_004D70ED, the join point after the stock AutoGather row (EBP frame: [ebp+8] = the
; selection; [esp+2Ch] = the next free row, [esp+38h] = the first selected unit). When the
; selected unit is gathering, sends the stock row writer to write one more row with its rate; the
; writer comes back here (0x69AFD2, 0x69AFDA or 0x69B182), where g_uhcGatherRowPending makes this
; hook take the stock path. Every register the hook does not mean to set is preserved; the stock
; AutoGather path already arrives here with EAX, EBX, EDX and EDI changed, and the code after the
; continuation reloads them.
UhcGatherPanelHook PROC
    TRACE_ONCE "showGatherRate panel (0x4D7834)"
    cmp g_uhcGatherRowPending, 0
    jne written
    push eax
    push ecx
    push edx
    push dword ptr [esp+0Ch+2Ch]        ; the row
    push dword ptr [ebp+8]              ; the selection
    push dword ptr [esp+14h+38h]        ; the unit
    call UhcGatherPanelRow              ; -> 1 with g_uhcGatherRowRes / g_uhcGatherRowRate set
    test al, al
    pop edx
    pop ecx
    pop eax
    jne addRow
stock:
    mov esi, dword ptr [esp+38h]        ; stolen 0x4D7834
    mov ecx, dword ptr [esi+5Ch]        ; stolen 0x4D7838
    jmp panelNext
written:
    mov g_uhcGatherRowPending, 0        ; back from the row writer (row written or skipped)
    jmp stock
addRow:
    mov g_uhcGatherRowPending, 1
    mov ebx, dword ptr [esp+2Ch]        ; the row, as the stock path sets EBX for the writer
    jmp rowWriter
UhcGatherPanelHook ENDP

; Replaces 0x699456..0x69945B (mov edi,[esp+54h] / mov ecx,edi) in the unit panel's cold part, the
; join point after its own AutoGather rate row ([esp+50h] = the panel, [esp+54h] = the unit). The
; stat panel fill does not run with the minimized interface; this is where that interface's rate
; gadgets are written. The C function writes them for a gathering unit; nothing else changes.
UhcGatherUnitPanelHook PROC
    TRACE_ONCE "showGatherRate unit panel (0x699456)"
    pushad
    push dword ptr [esp+20h+54h]        ; the unit
    push dword ptr [esp+24h+50h]        ; the panel
    call UhcGatherUnitPanel
    popad
    mov edi, dword ptr [esp+54h]        ; stolen 0x699456
    mov ecx, edi                        ; stolen 0x69945A
    jmp unitPanelNext
UhcGatherUnitPanelHook ENDP

; Replaces 0x69AFE0 (mov ecx,[0C66234h]) in the stat panel fill's cold part, the start of the
; AutoGather resource loop, reached only by fall-through once the row's gadgets are resolved
; (ESI = label, EDI = value). For our row, skips the loop and enters the formatter with what the
; loop would leave: EBX = the resource and [esp+1Ch] = the rate (EAX is set again at 0x69B02A).
; Otherwise runs the stock loop.
UhcGatherRowValueHook PROC
    TRACE_ONCE "showGatherRate row value (0x69AFE0)"
    cmp g_uhcGatherRowPending, 0
    jne ours
    mov ecx, dword ptr ds:[0C66234h]    ; stolen 0x69AFE0
    jmp agLoopNext
ours:
    mov ebx, g_uhcGatherRowRes
    mov eax, g_uhcGatherRowRate
    mov dword ptr [esp+1Ch], eax
    jmp rowFormat
UhcGatherRowValueHook ENDP

; The provider of data ref id 68h (currentUnitGatherRateString): its pointer replaces the stub
; 0x5FDE49 in the registration (imm32 at 0x5D2D3C). Called as bool provider(Value*), ret 4, ECX
; unused; the C++ function has the same stdcall frame, so the hook only traces and jumps.
UhcGatherRateRefHook PROC
    TRACE_ONCE "showGatherRate data ref (0x5D2D3C)"
    jmp UhcGatherRateRef
UhcGatherRateRefHook ENDP

END
