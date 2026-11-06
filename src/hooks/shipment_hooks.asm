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
UhcGatherLastResortUnit PROTO STDCALL hc:DWORD ; any building, then a hero, of the player, or 0
UhcGatherFirstTcUnit PROTO STDCALL hc:DWORD   ; the player's FirstTC if it is a valid point, else 0
UhcGatherNoPoint PROTO STDCALL hc:DWORD, store:DWORD ; the warning, interface only

LAST_RESORT_ENTRY EQU -3                    ; the same for the keyword LastResort
FIRST_TC_ENTRY EQU -2                       ; g_uhcGatherFallbackTypes entry of the keyword FirstTC

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

; Replaces 0x669E2E..0x669E32, the "no valid gather unit" exit of FUN_004C6B9E, reached after
; the stock search of its ten fixed unit types (TownCenter at 0x4C6BF1, then nine in the cold
; chunk 0x669804..0x669E2C). State on entry, as in the stock blocks: ESI = unit query object,
; [esp+10h] = home city, [esp+18h] = store flag. EBX, EBP and EDI are free (the epilogue pops
; them). Each configured proto is searched exactly like a stock block (0x6698B4..0x669963), and
; the first unit that passes the same checks becomes the point. A FirstTC entry runs no query:
; UhcGatherFirstTcUnit returns the player's first town center when it passes the stock check
; 0x85302C, and it becomes the point the same way.
UhcHcGatherFallbackHook PROC
    TRACE_ONCE "hcShipmentPointFallback (0x669E2E)"
    cmp resolved, 0
    jne gatherSearch
    mov resolved, 1
    pushad
    call UhcResolveGatherFallbackTypes
    popad
gatherSearch::
    mov typeIndex, 0
nextType:
    mov eax, typeIndex
    cmp eax, g_uhcGatherFallbackCount
    jge notFound
    mov edx, g_uhcGatherFallbackTypes[eax*4]
    cmp edx, FIRST_TC_ENTRY
    je firstTc
    cmp edx, LAST_RESORT_ENTRY
    je lastResort
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
firstTc:
    TRACE_ONCE "hcShipmentPointFallback FirstTC (0x669E2E)"
    push dword ptr [esp+10h]        ; home city (address taken before the push)
    call UhcGatherFirstTcUnit       ; Unit* or 0; clobbers EAX/ECX/EDX only
    test eax, eax
    je typeDone
    mov edi, eax
    jmp storeAndReturn              ; 0x4C6CB2: stores [hc+18Ch] when [esp+18h]==1, returns EDI
lastResort:
    TRACE_ONCE "hcShipmentPointFallback LastResort (0x669E2E)"
    push dword ptr [esp+10h]        ; home city (address taken before the push)
    call UhcGatherLastResortUnit    ; Unit* or 0; clobbers EAX/ECX/EDX only
    test eax, eax
    je typeDone
    mov edi, eax
    jmp storeAndReturn
notFound:
    movzx eax, byte ptr [esp+18h]   ; store
    push eax
    push dword ptr [esp+14h]        ; home city (address taken after the push above)
    call UhcGatherNoPoint           ; clobbers EAX/ECX/EDX only
    pop ebp                         ; stolen 0x669E2E..0x669E32
    pop edi
    pop esi
    xor eax, eax
    jmp notFoundReturn
UhcHcGatherFallbackHook ENDP

; Replaces 0x4C6BCF..0x4C6BD5 with the keyword replace: the list runs instead of the ten stock types.
; The stored point was refused just before. With the push of EBP, the stack is as at 0x669E2E.
UhcHcGatherReplaceHook PROC
    TRACE_ONCE "hcShipmentPointFallback replace (0x4C6BCF)"
    push ebp
    cmp resolved, 0
    jne gatherSearch
    mov resolved, 1
    pushad
    call UhcResolveGatherFallbackTypes
    popad
    jmp gatherSearch
UhcHcGatherReplaceHook ENDP

END
