; customWalls (src/features/customwalls.cpp). Entered through a jmp written over the stock code; each hook
; leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcCustomWallPieces PROTO STDCALL player:DWORD, caller:DWORD, pieces:DWORD
UhcCustomWallPost PROTO STDCALL placed:DWORD

.data
civPiecesNext  dd 009F6780h   ; cmp dword [edi+1E4h],-1, the civ's own pieces
stockNames     dd 009F67D5h   ; push "WallConnector", the stock names
piecesMerge    dd 009F6815h   ; xor esi,esi, where both branches meet with the four pieces
postOverlapNext dd 00508DDAh  ; push "WallConnector", after the instruction this hook re-executes
postOverlapOk  dd 00508DF3h   ; add esi,14h, the accepted overlap

.code

; Replaces 0x9F677A..0x9F677F (mov edi,eax / cmp edi,ebp / je 9F67D5h) in the wall layout 0x9F66D9, right after
; it found the player's civ (EAX; EBP is 0, ESI the player). Four DWORDs on the stack get the pieces of a custom
; wall: the connector, the 5-long straight, the 2-long straight and the gate, the player's copies. The
; function's return address is at [esp+100h] on entry (sub esp,0F0h and four pushes). When UhcCustomWallPieces
; fills them, the hook leaves them where both stock branches do at 0x9F6815: EBP the connector, EDI and
; [esp+44h] the 5-long straight, [esp+48h] the 2-long one, [esp+4Ch] and EAX the gate. Otherwise it runs the
; three stock instructions.
UhcCustomWallLayoutHook PROC
    TRACE_ONCE "customWalls layout (0x9F677A)"
    mov edi, eax
    sub esp, 10h
    mov eax, esp
    push eax                        ; pieces
    push dword ptr [esp+114h]       ; the return address ([esp+100h] on entry)
    push esi                        ; player
    call UhcCustomWallPieces
    test al, al
    je stock
    mov ebp, [esp]
    mov edi, [esp+4]
    mov eax, [esp+8]
    mov ecx, [esp+0Ch]
    add esp, 10h
    mov [esp+44h], edi
    mov [esp+48h], eax
    mov [esp+4Ch], ecx
    mov eax, ecx
    jmp piecesMerge
stock:
    add esp, 10h
    cmp edi, ebp
    je names
    jmp civPiecesNext
names:
    jmp stockNames
UhcCustomWallLayoutHook ENDP

; Replaces 0x508DD4..0x508DD9 (mov ecx,[0C66234h]) in the placement obstruction test: EDI is the proto being
; placed, ESI the unit in the way, both WallBuild, the same proto and the same owner. The stock code accepts
; the overlap only when EDI is the player's "WallConnector"; a custom wall's connector is accepted too.
UhcCustomWallPostHook PROC
    TRACE_ONCE "customWalls post overlap (0x508DD4)"
    push edi
    call UhcCustomWallPost
    test al, al
    jne accept
    mov ecx, dword ptr ds:[00C66234h]
    jmp postOverlapNext
accept:
    jmp postOverlapOk
UhcCustomWallPostHook ENDP

END
