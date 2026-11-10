; fastVertexFill (src/features/vertexfill.cpp). Each hook is entered through a jmp written over the stock code,
; replaces or re-executes what it overwrote, and leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcClothFillShadow PROTO STDCALL front:DWORD, back:DWORD, src:DWORD, pitch:DWORD, w:DWORD, h:DWORD, uv:DWORD, oneSided:DWORD
UhcClothFillCompare PROTO STDCALL

EXTERNDEF g_uhcClothFills:DWORD
EXTERNDEF g_uhcClothVertices:DWORD

.data
fillNext    dd 0040D655h    ; mov ebp,[esp+34h]: the loops' exit
stockLoop   dd 0040D52Bh    ; shl ecx,5: the stock loops, after the two instructions the jmp replaced
unlockNext  dd 0040D65Fh    ; mov eax,[ecx+660h]

.code

; The eight arguments of UhcClothFillRecords, pushed from the frame of the cloth flag draw 0x40D25B as it is at
; 0x40D523. `bias` is what the hook has pushed since then. On entry EAX = half the vertex count of the lock (the stock
; cdq / sub / sar at 0x40D50E), ESI = the flag manager, EDI = the index of the source buffer. Uses EAX, ECX, EDX, EBP.
;   [esp+14h] rows, [esp+18h] columns, [esp+4Ch] the locked pointer, [esp+50h] three floats (U scale, V scale,
;   V offset), [esp+70h] the byte "front side only".
CLOTH_ARGS MACRO bias:REQ
    mov edx, [esp+4Ch+bias]             ; front side: the locked pointer
    shl eax, 5
    add eax, edx                        ; back side: half the lock further
    movzx ecx, byte ptr [esp+70h+bias]
    lea ebp, [esp+50h+bias]
    push ecx                            ; front side only
    push ebp                            ; the three floats
    push dword ptr [esp+14h+bias+8]     ; rows
    push dword ptr [esp+18h+bias+0Ch]   ; columns
    push dword ptr [esi+14h]            ; columns in a row of the source buffer
    push dword ptr [esi+edi*4+3Ch]      ; the source buffer
    push eax
    push edx
ENDM

; void stdcall UhcClothFillRecords(front, back, src, pitch, w, h, uv, oneSided)
; Writes what the stock loops 0x40D523..0x40D654 write, byte for byte: per row and column one 32-byte vertex at `front`
; (position and normal copied, U = uv[0] * source U, V = uv[1] * source V - uv[2]) and, unless `oneSided`, the same
; vertex at `back` with its normal times -1.0. The stock code builds the back vertex from the front one it has just
; written, i.e. it reads the locked buffer; this reads the source vertex again instead. The float operations are the
; stock ones, on the x87 stack and in the stock order, so the rounding is the same under any control word: the U and V
; products are stored twice from the same register (fst, fstp) where stock stores once and copies the dword.
UhcClothFillRecords PROC STDCALL USES ebx esi edi, front:DWORD, back:DWORD, src:DWORD, pitch:DWORD, w:DWORD, h:DWORD, uv:DWORD, oneSided:DWORD
    LOCAL rowEnd:DWORD
    mov eax, front
    mov edx, back
    mov esi, uv
    xor edi, edi                        ; row
    cmp w, 0
    jle done
    cmp h, 0
    jle done
row:
    mov ecx, pitch
    imul ecx, edi
    shl ecx, 5
    add ecx, src                        ; the row's first source vertex
    mov ebx, w
    shl ebx, 5
    add ebx, ecx
    mov rowEnd, ebx
    cmp byte ptr oneSided, 0
    jne single
both:
    mov ebx, [ecx]
    mov [eax], ebx
    mov [edx], ebx
    mov ebx, [ecx+4]
    mov [eax+4], ebx
    mov [edx+4], ebx
    mov ebx, [ecx+8]
    mov [eax+8], ebx
    mov [edx+8], ebx
    mov ebx, [ecx+0Ch]
    mov [eax+0Ch], ebx
    mov ebx, [ecx+10h]
    mov [eax+10h], ebx
    mov ebx, [ecx+14h]
    mov [eax+14h], ebx
    fld dword ptr [ecx+0Ch]
    fmul dword ptr ds:[0B856B8h]
    fstp dword ptr [edx+0Ch]
    fld dword ptr [ecx+10h]
    fmul dword ptr ds:[0B856B8h]
    fstp dword ptr [edx+10h]
    fld dword ptr [ecx+14h]
    fmul dword ptr ds:[0B856B8h]
    fstp dword ptr [edx+14h]
    fld dword ptr [esi]
    fmul dword ptr [ecx+18h]
    fst dword ptr [eax+18h]
    fstp dword ptr [edx+18h]
    fld dword ptr [esi+4]
    fmul dword ptr [ecx+1Ch]
    fsub dword ptr [esi+8]
    fst dword ptr [eax+1Ch]
    fstp dword ptr [edx+1Ch]
    add ecx, 20h
    add eax, 20h
    add edx, 20h
    cmp ecx, rowEnd
    jb both
    jmp nextRow
single:
    mov ebx, [ecx]
    mov [eax], ebx
    mov ebx, [ecx+4]
    mov [eax+4], ebx
    mov ebx, [ecx+8]
    mov [eax+8], ebx
    mov ebx, [ecx+0Ch]
    mov [eax+0Ch], ebx
    mov ebx, [ecx+10h]
    mov [eax+10h], ebx
    mov ebx, [ecx+14h]
    mov [eax+14h], ebx
    fld dword ptr [esi]
    fmul dword ptr [ecx+18h]
    fstp dword ptr [eax+18h]
    fld dword ptr [esi+4]
    fmul dword ptr [ecx+1Ch]
    fsub dword ptr [esi+8]
    fstp dword ptr [eax+1Ch]
    add ecx, 20h
    add eax, 20h
    cmp ecx, rowEnd
    jb single
nextRow:
    inc edi
    cmp edi, h
    jl row
done:
    ret
UhcClothFillRecords ENDP

; Replaces 0x40D523 (mov ecx,[esp+18h] / mov edx,[esp+4Ch]) and the two loops after it, up to their exit 0x40D655.
; Entered once per lock, after the stock test of the row count ([esp+14h] > 0). There, EAX, ECX, EDX and EBP are dead
; (0x40D655 loads EBP, 0x40D659 ECX, 0x40D65F EAX, 0x40D682 EDX), EBX is the value stock reloads from [esp+60h] at
; 0x40D617 (the callee keeps it), and the slots the stock loops use as counters ([esp+28h], [esp+2Ch], [esp+30h],
; [esp+5Ch]) are written again at 0x40D68A before anything reads them. The x87 stack is empty on both sides.
UhcClothFillHook PROC
    TRACE_ONCE "fastVertexFill cloth flag fill (0x40D523)"
    inc g_uhcClothFills
    mov ecx, [esp+18h]
    imul ecx, [esp+14h]
    add g_uhcClothVertices, ecx
    CLOTH_ARGS 0
    call UhcClothFillRecords
    jmp fillNext
UhcClothFillHook ENDP

; `verify`, at the same site: fills a buffer of the DLL with the arguments the hook above would use, then runs the
; stock loops themselves on the locked buffer. Every register is kept for them.
UhcClothFillVerifyHook PROC
    TRACE_ONCE "fastVertexFill verify, before the stock fill (0x40D523)"
    pushad
    CLOTH_ARGS 20h
    call UhcClothFillShadow
    popad
    mov ecx, [esp+18h]
    mov edx, [esp+4Ch]
    jmp stockLoop
UhcClothFillVerifyHook ENDP

; `verify`: replaces 0x40D659 (mov ecx,[0C66044h]), which the loops' exit falls into and the "no rows" branch 0x40D51D
; jumps to, before the Unlock. The helper compares what the stock loops wrote with the DLL's buffer. Every register is
; kept (EBX, ESI, EDI and EBP are live); the flags are dead (test eax,eax at 0x40D665).
UhcClothFillUnlockHook PROC
    TRACE_ONCE "fastVertexFill verify, after the stock fill (0x40D659)"
    pushad
    call UhcClothFillCompare
    popad
    mov ecx, dword ptr ds:[0C66044h]
    jmp unlockNext
UhcClothFillUnlockHook ENDP

END
