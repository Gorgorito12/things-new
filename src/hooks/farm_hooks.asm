; Hooks for enableFarmAnim, enableRectFarmAnim and farmingRadius (src/features/farms.cpp). Each
; site is in a chain that compares a gather target's proto ID with the cached Mill ([db+5E58h]),
; Rice Paddy ([db+607Ch]) and other IDs. A listed proto takes the branch stock takes for a Mill
; (kind 1) or a Rice Paddy (kind 2), with the registers that branch has; anything else runs the
; replaced stock instruction(s). Every hook leaves through an explicit jmp.
.686
.model flat, c
option casemap :none

include common.inc

UhcFarmKind PROTO STDCALL protoId:DWORD
UhcFarmRadius PROTO STDCALL protoId:DWORD
EXTERNDEF g_uhcFarmKind:SDWORD

.data
farm1Cont     dd 004EDA8Bh   ; mov ebx,[edx+5E58h]
farm1Mill     dd 004E3069h   ; the chain's Mill branch
farm1Rect     dd 006A8A55h   ; the chain's Rice Paddy branch
farm2Cont     dd 004EDD6Ch   ; the next compares (stock jne target)
farm2Mill     dd 006A8E67h
farm2Rect     dd 0050DF51h
farm3Cont     dd 0073D427h
farm3Mill     dd 0073D49Bh
farm3Sacred   dd 0073D264h
farm4Callee   dd 004E2C50h
farm4Cont     dd 008CECA4h
farm4Mill     dd 008CED20h
farm5Cont     dd 009DDB7Fh   ; sete dl (the Mill flag)
farm6Cont     dd 004EE085h
farm6Mill     dd 00586DFFh
farm7Cont     dd 004EE304h
farm7Mill     dd 00586E11h
farm8Callee   dd 0044CB0Ah   ; unit -> proto ID
farm8Cont     dd 006A900Ch
farm8Mill     dd 006A8FEAh
rect1Ok       dd 009DDD9Eh
rect1No       dd 009DDECAh
rect2Null     dd 004743DDh
rect2Cont     dd 004741F6h
rect2Rect     dd 00689BBEh
rect3Cont     dd 004EEDBAh
rect3Rect     dd 004EEE18h
rect4Cont     dd 004EEEA4h
rect4Rect     dd 004ED756h
radiusCont    dd 009DE053h   ; push ecx (the stock X)
radiusAfter   dd 009DE06Bh   ; push edx (Z) for the second draw
rngFloat      dd 00422648h   ; float thiscall(Rng*, int stream, float min, float max)
farmRadiusPtr dd 0

.code

; Asks UhcFarmKind(reg) with every register and the flags preserved; the answer is in
; g_uhcFarmKind.
FARM_KIND MACRO reg
    pushfd
    pushad
    push reg
    call UhcFarmKind
    popad
    popfd
ENDM

; EAX = the proto ID of the unit in `unit` ([[unit+5Ch]+8]), or -1 without a proto.
PROTO_OF MACRO unit
    LOCAL none, done
    mov eax, dword ptr [unit+5Ch]
    test eax, eax
    jz none
    mov eax, dword ptr [eax+8]
    jmp done
none:
    or eax, -1
done:
ENDM

; 0x4EDA85: mov edx,[ebp+140h] (6 B), before the chain on [[esi+5Ch]+8]. At the chain's Mill
; branch (0x4EDAA3) and Rice Paddy branch (0x4EDB20) stock has EDX = db, ECX = ESI, EAX = the
; proto ID and EBX = the compared ID.
UhcFarm1Hook PROC
    TRACE_ONCE "enableFarmAnim site 1 (0x4EDA85)"
    pushad
    PROTO_OF esi
    push eax
    call UhcFarmKind
    popad
    mov edx, dword ptr [ebp+140h]
    cmp g_uhcFarmKind, 1
    je asMill
    cmp g_uhcFarmKind, 2
    je asRect
    jmp farm1Cont
asMill:
    mov ebx, dword ptr [edx+5E58h]
    mov ecx, esi
    PROTO_OF esi
    jmp farm1Mill
asRect:
    mov ebx, dword ptr [edx+607Ch]
    mov ecx, esi
    PROTO_OF esi
    jmp farm1Rect
UhcFarm1Hook ENDP

; 0x50DE33: jne 4EDD6Ch (6 B) after cmp eax,ebx; EAX = the proto ID of EDI. Equal falls to
; jmp 6A8E67h (the Mill branch); the Rice Paddy branch is 0x50DF51 (stock 0x4EDDAA, with
; EBX = [db+607Ch], ECX = EDI, EDX = the game).
UhcFarm2Hook PROC
    TRACE_ONCE "enableFarmAnim site 2 (0x50DE33)"
    je asMill
    FARM_KIND eax
    cmp g_uhcFarmKind, 1
    je asMill
    cmp g_uhcFarmKind, 2
    je asRect
    jmp farm2Cont
asMill:
    jmp farm2Mill
asRect:
    mov edx, dword ptr ds:[0C66234h]
    mov ecx, dword ptr [edx+140h]
    mov ebx, dword ptr [ecx+607Ch]
    mov ecx, edi
    jmp farm2Rect
UhcFarm2Hook ENDP

; 0x73D41A: jne 73D427h / mov eax,[eax+5F4Ch] (8 B) after cmp ebx,[eax+5FB0h]; EBX = the proto
; ID, EAX = db. Listed farms of either kind take the Mill / Farm / Rice Paddy branch 0x73D49B.
UhcFarm3Hook PROC
    TRACE_ONCE "enableFarmAnim site 3 (0x73D41A)"
    je sacred
    FARM_KIND ebx
    cmp g_uhcFarmKind, 0
    jne asMill
    jmp farm3Cont
asMill:
    jmp farm3Mill
sacred:
    mov eax, dword ptr [eax+5F4Ch]
    jmp farm3Sacred
UhcFarm3Hook ENDP

; 0x8CEC9F: call 4E2C50h (5 B); then ESI (a proto ID) is compared with the cached farm IDs, all
; of which branch to 0x8CED20.
UhcFarm4Hook PROC
    TRACE_ONCE "enableFarmAnim site 4 (0x8CEC9F)"
    call dword ptr [farm4Callee]
    FARM_KIND esi
    cmp g_uhcFarmKind, 0
    jne asMill
    jmp farm4Cont
asMill:
    jmp farm4Mill
UhcFarm4Hook ENDP

; 0x9DDB79 in the gather action FUN_009DDADE: cmp ecx,[eax+5E58h] (6 B), ECX = the target's
; proto ID, EAX = db. A listed farm makes the compare equal, so the Mill flag (sete dl and the
; frame bytes after it) is set as for a Mill.
UhcFarm5Hook PROC
    TRACE_ONCE "enableFarmAnim site 5 (0x9DDB79)"
    cmp ecx, dword ptr [eax+5E58h]
    je done
    FARM_KIND ecx
    cmp g_uhcFarmKind, 1
    jne stock
    cmp eax, eax                    ; ZF = 1: the Mill test succeeds
    jmp done
stock:
    cmp ecx, dword ptr [eax+5E58h]  ; the flags of the real compare
done:
    jmp farm5Cont
UhcFarm5Hook ENDP

; 0x4EE07F: je 586DFFh (6 B) after the chain's last compare; EAX = the proto ID.
UhcFarm6Hook PROC
    TRACE_ONCE "enableFarmAnim site 6 (0x4EE07F)"
    je asMill
    FARM_KIND eax
    cmp g_uhcFarmKind, 1
    je asMill
    jmp farm6Cont
asMill:
    jmp farm6Mill
UhcFarm6Hook ENDP

; 0x4EE2FE: je 586E11h (6 B); EAX = the proto ID of EBP's unit.
UhcFarm7Hook PROC
    TRACE_ONCE "enableFarmAnim site 7 (0x4EE2FE)"
    je asMill
    FARM_KIND eax
    cmp g_uhcFarmKind, 1
    je asMill
    jmp farm7Cont
asMill:
    jmp farm7Mill
UhcFarm7Hook ENDP

; 0x6A8FE1: call 44CB0Ah / cmp eax,ebx / jne 6A900Ch (9 B), ECX = EDI.
UhcFarm8Hook PROC
    TRACE_ONCE "enableFarmAnim site 8 (0x6A8FE1)"
    call dword ptr [farm8Callee]
    cmp eax, ebx
    je asMill
    FARM_KIND eax
    cmp g_uhcFarmKind, 1
    je asMill
    jmp farm8Cont
asMill:
    jmp farm8Mill
UhcFarm8Hook ENDP

; 0x9DDD80 in FUN_009DDADE: the four loads and cmp ecx,[eax+607Ch] (18h B) before jne 9DDECAh.
UhcRectFarm1Hook PROC
    TRACE_ONCE "enableRectFarmAnim site 1 (0x9DDD80)"
    mov edx, dword ptr ds:[0C66234h]
    mov ecx, dword ptr [edi+5Ch]
    mov eax, dword ptr [edx+140h]
    mov ecx, dword ptr [ecx+4]
    cmp ecx, dword ptr [eax+607Ch]
    je ok
    FARM_KIND ecx
    cmp g_uhcFarmKind, 2
    je ok
    jmp rect1No
ok:
    jmp rect1Ok
UhcRectFarm1Hook ENDP

; 0x4741F0: je 4743DDh (6 B) after test esi,esi; EBX = the unit. Stock's Rice Paddy branch
; (0x474221) has [esp+14h] = [ebx+18h], EDX = the game, EBP = [db+607Ch], ECX = EBX, EAX = the
; proto ID.
UhcRectFarm2Hook PROC
    TRACE_ONCE "enableRectFarmAnim site 2 (0x4741F0)"
    je null
    pushad
    PROTO_OF ebx
    push eax
    call UhcFarmKind
    popad
    cmp g_uhcFarmKind, 2
    je asRect
    jmp rect2Cont
asRect:
    mov ecx, dword ptr [ebx+18h]
    mov dword ptr [esp+14h], ecx
    mov edx, dword ptr ds:[0C66234h]
    mov eax, dword ptr [edx+140h]
    mov ebp, dword ptr [eax+607Ch]
    mov ecx, ebx
    PROTO_OF ebx
    jmp rect2Rect
null:
    jmp rect2Null
UhcRectFarm2Hook ENDP

; 0x4EEDB4: mov ecx,[0C66234h] (6 B); EAX = the proto ID of EDI. Stock's Rice Paddy branch
; (0x4EEDD8) has EDX = db, EBP = [db+607Ch], ECX = EDI.
UhcRectFarm3Hook PROC
    TRACE_ONCE "enableRectFarmAnim site 3 (0x4EEDB4)"
    FARM_KIND eax
    cmp g_uhcFarmKind, 2
    je asRect
    mov ecx, dword ptr ds:[0C66234h]
    jmp rect3Cont
asRect:
    mov ecx, dword ptr ds:[0C66234h]
    mov edx, dword ptr [ecx+140h]
    mov ebp, dword ptr [edx+607Ch]
    mov ecx, edi
    jmp rect3Rect
UhcRectFarm3Hook ENDP

; 0x4EEE9E: mov ecx,[0C66234h] (6 B), before the chain on [[edi+5Ch]+8]. Stock's Rice Paddy
; branch (0x4EEEC2) has EDX = db, EBP = [db+607Ch], ECX = EDI, EAX = the proto ID.
UhcRectFarm4Hook PROC
    TRACE_ONCE "enableRectFarmAnim site 4 (0x4EEE9E)"
    pushad
    PROTO_OF edi
    push eax
    call UhcFarmKind
    popad
    cmp g_uhcFarmKind, 2
    je asRect
    mov ecx, dword ptr ds:[0C66234h]
    jmp rect4Cont
asRect:
    mov ecx, dword ptr ds:[0C66234h]
    mov edx, dword ptr [ecx+140h]
    mov ebp, dword ptr [edx+607Ch]
    mov ecx, edi
    PROTO_OF edi
    jmp rect4Rect
UhcRectFarm4Hook ENDP

; 0x9DE04D in FUN_009DDADE: mov ecx,[0C0BBE0h] (6 B), the stock 4.5 that the two synced draws use
; as X (here) and Z (0x9DE065). EAX, ECX and EDX are free here: the draws overwrite them.
UhcFarmRadiusHook PROC
    TRACE_ONCE "farmingRadius (0x9DE04D)"
    mov ecx, dword ptr [edi+5Ch]
    push dword ptr [ecx+4]
    call UhcFarmRadius
    test eax, eax
    jz stock
    mov farmRadiusPtr, eax
    push dword ptr [eax]            ; X
    push ebp
    push 2
    mov ecx, 0C66588h
    call dword ptr [rngFloat]
    fstp dword ptr [esp+14h]
    mov eax, farmRadiusPtr
    mov edx, dword ptr [eax+4]      ; Z, pushed at 0x9DE06B
    jmp radiusAfter
stock:
    mov ecx, dword ptr ds:[0C0BBE0h]
    jmp radiusCont
UhcFarmRadiusHook ENDP

END
