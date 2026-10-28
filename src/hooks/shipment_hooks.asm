; Hook for hcShipmentPointFallback. Entered through a jmp written over the stock code; leaves
; through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Home city
; gather point").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcGatherFallbackTypes:DWORD    ; proto IDs, resolved on first use
EXTERNDEF g_uhcGatherFallbackCount:SDWORD
UhcResolveGatherFallbackTypes PROTO STDCALL

.data
querySetPlayer   dd 00453618h   ; thiscall(query, 0, playerId, 1)
queryAddType     dd 0045356Dh   ; thiscall(query, 0, protoId)
querySetState    dd 004532B4h   ; thiscall(query, 0, 2 = alive)
queryRun         dd 00453484h   ; thiscall(query, 0) -> count
queryUnitId      dd 00453A36h   ; thiscall(query, 0, index) -> unit ID
unitCheckA       dd 0044DDB4h   ; thiscall(unit) -> bool, required
unitCheckB       dd 004802C6h   ; thiscall(unit) -> 1 rejects the unit
storeAndReturn   dd 004C6CB2h   ; stores [hc+18Ch] = [EDI+10h] if [esp+18h] == 1; returns EDI
notFoundReturn   dd 00669E33h   ; pop ebx / pop ecx / ret 4
typeIndex        dd 0
resolved         db 0

.code

; Replaces 0x669E2E..0x669E32, the "no valid gather unit" exit of FUN_004C6CAE, reached after
; the stock search of its eight fixed unit types. State on entry, as in the stock blocks:
; ESI = unit query object, [esp+10h] = home city, [esp+18h] = store flag. EBX, EBP and EDI are
; free (the epilogue pops them). Each configured proto is searched exactly like a stock block
; (0x6698B4..0x669963), and the first unit that passes the same checks becomes the point.
UhcHcGatherFallbackHook PROC
    TRACE_ONCE "hcShipmentPointFallback (0x669E2E)"
    cmp resolved, 0
    jne searchTypes
    mov resolved, 1
    pushad
    call UhcResolveGatherFallbackTypes
    popad
searchTypes:
    mov typeIndex, 0
nextType:
    mov eax, typeIndex
    cmp eax, g_uhcGatherFallbackCount
    jge notFound
    mov edx, g_uhcGatherFallbackTypes[eax*4]
    cmp edx, -1
    je typeDone
    mov eax, dword ptr [esp+10h]    ; home city
    mov ecx, dword ptr [eax+8]
    mov eax, dword ptr [ecx]        ; owning player ID
    push 1
    push eax
    push 0
    mov ecx, esi
    call querySetPlayer
    mov eax, typeIndex
    mov edx, g_uhcGatherFallbackTypes[eax*4]
    push edx
    push 0
    mov ecx, esi
    call queryAddType
    push 2
    push 0
    mov ecx, esi
    call querySetState
    push 0
    mov ecx, esi
    call queryRun
    mov ebx, eax
    xor ebp, ebp
    test ebx, ebx
    jle typeDone
unitLoop:
    mov eax, dword ptr ds:[0C66234h]
    mov edi, dword ptr [eax+13Ch]   ; world
    push ebp
    push 0
    mov ecx, esi
    call queryUnitId
    test eax, eax
    jl unitNext
    mov ecx, eax
    and ecx, 3FFFFh
    cmp ecx, dword ptr [edi+10h]
    jge unitNext
    mov edx, dword ptr [edi+0Ch]
    mov edi, dword ptr [edx+ecx*4]
    test edi, edi
    je unitNext
    cmp dword ptr [edi+10h], eax
    jne unitNext
    mov eax, dword ptr [edi]
    mov ecx, edi
    call dword ptr [eax+0A4h]
    test al, al
    je unitNext
    mov ecx, edi
    call unitCheckA
    test al, al
    je unitNext
    mov ecx, edi
    call unitCheckB
    cmp al, 1
    jne found
unitNext:
    add ebp, 1
    cmp ebp, ebx
    jl unitLoop
typeDone:
    inc typeIndex
    jmp nextType
found:
    jmp storeAndReturn              ; EDI = the chosen unit
notFound:
    pop ebp                         ; stolen 0x669E2E..0x669E32
    pop edi
    pop esi
    xor eax, eax
    jmp notFoundReturn
UhcHcGatherFallbackHook ENDP

END
