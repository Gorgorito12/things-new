; The shared floating bar hooks (floatingbars.cpp): overhealHitpointBars segment and inventoryBars add their bars
; through them. Each is entered through a jmp written over the stock code and leaves through an explicit jmp to a
; verified continuation (docs/how-it-works.md, "overhealHitpointBars", "The segment").
.686
.model flat, c
option casemap :none

include common.inc

UhcFloatingBarQueued PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD
UhcFloatingBarFit PROTO STDCALL :DWORD
UhcFloatingBarVertices PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD

.data
barQueueExit    dd 004516B3h    ; where the bar chunk goes after queueing the bar (jmp at 0x45FB6C)
renderCountNext dd 0045C4BFh    ; test ebx,ebx / mov [esp+3Ch],ebx / jle: the renderer's record count
vertexLoopNext  dd 0045CB78h    ; add edi,24h / add ebx,24h / cmp eax,[ebp+8D4h]: the next record

.code

; Replaces jmp 4516B3h (5 bytes) at 0x45FB6C, right after the bar chunk queued unit ESI's HP bar at [esp+18h]
; (FUN_0045FB71, ret 14h). [esp+15h] is set for a foundation (the bar is its build fraction); BL is the Alt state
; the chunk read at 0x452EB3 (0x473E37(2), kept in BL through the chunk). Every register is kept for 0x4516B3; the x87
; stack is empty here.
UhcFloatingBarQueuedHook PROC
    TRACE_ONCE "floating bars: bar queued (0x45FB6C)"
    pushad
    movzx eax, bl
    push eax                        ; Alt held
    movzx eax, byte ptr [esp+39h]   ; constructing: [esp+15h] at entry, +20h pushad, +4
    push eax
    lea eax, [esp+40h]              ; the position: [esp+18h] at entry, +20h pushad, +8
    push eax
    push esi                        ; unit
    call UhcFloatingBarQueued
    popad
    jmp barQueueExit
UhcFloatingBarQueuedHook ENDP

; Replaces mov ebx,[ebp+8D4h] at 0x45C4B9 in the bar renderer FUN_0045C4AF (EBP = world): before the vertex lock,
; UhcFloatingBarFit drops the added bars when the queue would not fit in the dynamic vertex buffer; then the stolen
; load of the count.
UhcFloatingBarFitHook PROC
    TRACE_ONCE "floating bars: fit (0x45C4B9)"
    pushad
    push ebp
    call UhcFloatingBarFit
    popad
    mov ebx, dword ptr [ebp+8D4h]   ; stolen 0x45C4B9
    jmp renderCountNext
UhcFloatingBarFitHook ENDP

; Replaces add eax,1 / add ecx,1Ch at 0x45CB72, the end of the renderer's per-record loop: ECX = the record's offset
; in [ebp+8D0h], EDI = its sixth vertex, ESI = the camera. The six vertices of an added bar (a negative player ID)
; go to UhcFloatingBarVertices; every other record is left as the stock loop wrote it. The FPU stack is empty here
; (checked over one iteration); the flags are set again by the stolen adds.
UhcFloatingBarVertexHook PROC
    TRACE_ONCE "floating bars: vertices (0x45CB72)"
    push edx
    mov edx, dword ptr [ebp+8D0h]
    cmp dword ptr [edx+ecx+14h], 0
    pop edx
    jge done
    pushad
    push esi                        ; camera
    lea eax, [edi-0B4h]             ; the first vertex, five 24h-byte vertices back
    push eax
    push ecx                        ; the record's offset
    push ebp                        ; world
    call UhcFloatingBarVertices
    popad
done:
    add eax, 1                      ; stolen 0x45CB72
    add ecx, 1Ch                    ; stolen 0x45CB75
    jmp vertexLoopNext
UhcFloatingBarVertexHook ENDP

END
