; Hook for faithResource (src/features/faith.cpp). Entered through a jmp over add [esi+1F4h],edx (6 bytes) at
; 0x852A3B in the home city bank FUN_00852924: EDX = int(resource 4) that the stock code adds to the home city's
; skill points, ESI = the home city, ECX = its player (thiscall of the call at 0x852A45), the three arguments of
; that call already pushed, the x87 stack empty. The hook adds nothing, optionally logs EDX and [esi+1F4h], and
; leaves to 0x852A41 (fldcw [esp+1Ch] / call 49A8C5h) with every register and the flags as they came in (the
; stock add's flags are dead: fldcw and the call follow).
.686
.model flat, c
option casemap :none

include common.inc

UhcFaithBankSkipped PROTO STDCALL faith:DWORD, skillPoints:DWORD

EXTERN g_uhcFaithLog:DWORD

EXTERN g_uhcFaithAnim:DWORD

.data
faithBankContinue dd 00852A41h   ; fldcw [esp+1Ch] / call 49A8C5h (resource 5 = 0)
gatherAnimSet     dd 004ED3FAh   ; mov ecx,[edi+5Ch]: after the gather animation [esi+74h] is chosen
gatherAnimNext    dd 004ED36Bh   ; the stock chain's second test (je target of the first)
gatherAnimFirst   dd 004ED35Ch   ; push 8 / call 44CAC4h: the stock chain's first test
modelAnimIndex    dd 00471D24h   ; thiscall(unit, anim) -> the model's index of that anim, < 0 when it lacks it

.code

; Entered through a jmp over mov ecx,[edi+5Ch] / cmp ecx,ebx / je 4ED36Bh (7 bytes) at 0x4ED355 in the Gather
; action's state change FUN_004ED254, where the stock code picks the gather animation [esi+74h] from the target's
; unit types (a mine, a tree, a farm, a hunt, a fish, a crate, a fire pit, else GatherBush or GatherFarm) and
; never reads the tactics action's <anim>. ESI = the Gather action ([esi+4] its tactics action, whose <anim> is at
; +58h, -1 for none; [esi+10h] the gatherer; [esi+70h] the resource it gathers), EDI = the target unit (not null:
; 0x4ED34D tested it), EBX = 0. When the resource is 4 (faith) and the gatherer's model has the action's <anim>,
; that anim is stored and the hook leaves to 0x4ED3FA, where every stock case leaves after storing its own;
; otherwise it re-executes the three instructions. EAX, ECX and EDX are dead here (the stock cases overwrite
; ECX at once and never read EAX or EDX after 0x4ED3FA before setting them).
UhcFaithGatherAnimHook PROC
    TRACE_ONCE "faithResource gather animation (0x4ED355)"
    cmp g_uhcFaithAnim, 0
    je stock
    cmp dword ptr [esi+70h], 4
    jne stock
    mov eax, [esi+4]
    test eax, eax
    jz stock
    mov eax, [eax+58h]
    test eax, eax
    jl stock
    push eax                    ; keep the anim
    push eax
    mov ecx, [esi+10h]
    call modelAnimIndex         ; ret 4
    pop edx
    test eax, eax
    jl stock
    TRACE_ONCE "faithResource gather animation: the action's own <anim> played"
    mov [esi+74h], edx
    jmp gatherAnimSet
stock:
    mov ecx, [edi+5Ch]
    cmp ecx, ebx
    je next
    jmp gatherAnimFirst
next:
    jmp gatherAnimNext
UhcFaithGatherAnimHook ENDP

UhcFaithBankHook PROC
    TRACE_ONCE "faithResource home city bank (0x852A3B)"
    cmp g_uhcFaithLog, 0
    je done
    pushfd
    pushad
    push dword ptr [esi+1F4h]
    push edx
    call UhcFaithBankSkipped
    popad
    popfd
done:
    jmp faithBankContinue
UhcFaithBankHook ENDP

END
