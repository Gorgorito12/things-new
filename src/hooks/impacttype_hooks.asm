; Hooks for customImpactTypes (src/features/impacttypes.cpp).
.686
.model flat, c
option casemap :none

include common.inc

UhcCustomImpactType   PROTO STDCALL nameString:DWORD
UhcAddCustomImpact    PROTO STDCALL effect:DWORD, impactType:DWORD, entry:DWORD
UhcFinishImpactEffect PROTO STDCALL effect:DWORD
UhcSpawnCustomImpact  PROTO STDCALL effect:DWORD, args:DWORD

.data
listAdd       dd 00401F74h
weights       dd 005FE8CDh
spawn         dd 0049C1E5h
addContinue   dd 005FEC89h   ; add ebp,1
weightsCont   dd 005FECA0h   ; lea ecx,[esp+24h]
unitContinue  dd 0049D873h   ; push eax
terrainCont   dd 004CB312h   ; pop edi

.code

; 0x59F464, the not-found end of the impact type by name (EBX = the name's string object, EDI/ESI/EBX
; still pushed). Replaces pop edi / pop esi / or eax,-1 / pop ebx / ret: EAX = 15 + the custom type's
; index, or -1.
UhcImpactTypeNotFoundHook PROC
    TRACE_ONCE "customImpactTypes name lookup (0x59F464)"
    push ebx
    call UhcCustomImpactType
    pop edi
    pop esi
    pop ebx
    ret
UhcImpactTypeNotFoundHook ENDP

; 0x5FEC74, the add of a parsed entry to its type's list (EBX = the type, [esp+20h] = the impact effect,
; [esp+14h] = the entry). Stock types run the stock add; custom ones go to the DLL's lists.
UhcImpactEffectAddHook PROC
    TRACE_ONCE "customImpactTypes impact effect entry (0x5FEC74)"
    cmp ebx, 15
    jge custom
    mov edx, dword ptr [esp+20h]
    lea eax, dword ptr [esp+14h]
    lea ecx, dword ptr [ebx+ebx*2]
    push eax
    lea ecx, dword ptr [edx+ecx*4+4]
    call listAdd
    jmp addContinue
custom:
    push dword ptr [esp+14h]
    push ebx
    push dword ptr [esp+28h]      ; [esp+20h] before the two pushes
    call UhcAddCustomImpact
    jmp addContinue
UhcImpactEffectAddHook ENDP

; 0x5FEC99, the cumulative weights of the 15 stock lists (EBX = the impact effect); the custom lists get
; theirs too.
UhcImpactEffectWeightsHook PROC
    TRACE_ONCE "customImpactTypes impact effect weights (0x5FEC99)"
    mov ecx, ebx
    call weights
    push ebx
    call UhcFinishImpactEffect
    jmp weightsCont
UhcImpactEffectWeightsHook ENDP

; The two calls of the spawn FUN_0049C1E5: ECX = the impact effect, its 8 arguments on the stack, the type
; 4th ([esp+0Ch]). A custom type is spawned by the DLL, which lends it a stock list for the stock call; the
; 8 arguments are then dropped as the callee would have.
SPAWN_HOOK MACRO hookName:REQ, traceText:REQ, continueAt:REQ
hookName PROC
    TRACE_ONCE traceText
    cmp dword ptr [esp+0Ch], 15
    jge custom
    call spawn
    jmp continueAt
custom:
    mov eax, esp
    push eax
    push ecx
    call UhcSpawnCustomImpact
    add esp, 20h
    jmp continueAt
hookName ENDP
ENDM

SPAWN_HOOK UhcImpactSpawnUnitHook, "customImpactTypes impact spawn, projectile hit (0x49D86E)", unitContinue
SPAWN_HOOK UhcImpactSpawnTerrainHook, "customImpactTypes impact spawn, terrain (0x4CB30D)", terrainCont

END
