; linkedResource (src/features/linkedresource.cpp). Each hook is entered through a jmp written over the stock code and
; leaves through an explicit jmp to a verified continuation, or returns for the function it replaces.
.686
.model flat, c
option casemap :none

include common.inc

UhcLinkedRegister PROTO STDCALL unit:DWORD
UhcLinkedInventory PROTO STDCALL inventory:DWORD, resource:DWORD, amount:DWORD, result:DWORD
UhcLinkedAutoGather PROTO STDCALL action:DWORD, resource:DWORD, amount:DWORD

EXTERNDEF g_uhcLinkedOn:DWORD

.data
inventoryNext   dd 0049A5EBh    ; push ebx: the rest of the stock add
recreateNext    dd 009BFE63h    ; mov eax,[eax+94h]
payNext         dd 004C3791h    ; mov ecx,[edx+44h] / push 0 / push edi / push ebx / call 49A98Ah

.code

; The stock add, for the C++ code, so that a call to it does not come back to the hook.
UhcLinkedInventoryStock PROC
    mov eax, dword ptr ds:[0C66234h]    ; replaced at 0x49A5E6
    jmp inventoryNext
UhcLinkedInventoryStock ENDP

; Replaces 0x49A5E6 (mov eax,[0xC66234]), the head of bool thiscall(inventory, resource, float), ret 8. ECX = the
; inventory. Nothing but ECX is an argument register, and the replaced line writes EAX.
UhcLinkedInventoryHook PROC
    cmp g_uhcLinkedOn, 0
    je stock
    TRACE_ONCE "linkedResource inventory (0x49A5E6)"
    push ecx
    sub esp, 4                      ; the result, written by the helper
    mov eax, esp
    push eax
    push dword ptr [esp+14h]        ; amount: [esp+8] at entry, +8 for the two above, +4 for this frame's push
    push dword ptr [esp+14h]        ; resource: [esp+4] at entry
    push ecx
    call UhcLinkedInventory
    test eax, eax
    pop eax                         ; the result
    pop ecx
    jne done
stock:
    jmp UhcLinkedInventoryStock
done:
    ret 8
UhcLinkedInventoryHook ENDP

; Runs the stock body of 0x9BFE5A, inventory recreate, up to its own ret: replaced push esi / mov esi,ecx /
; mov eax,[esi+0B4h].
recreateBody PROC
    push esi
    mov esi, ecx
    mov eax, dword ptr [esi+0B4h]
    jmp recreateNext
recreateBody ENDP

; Replaces those 9 bytes at 0x9BFE5A, thiscall(unit), plain ret, returns the inventory. After it a tagged unit joins
; the links; the helper keeps EBX, ESI, EDI and EBP, and the stock callers read only EAX of what is left.
UhcLinkedRecreateHook PROC
    TRACE_ONCE "linkedResource recreate (0x9BFE5A)"
    push ecx
    call recreateBody
    pop ecx
    push eax
    push ecx
    call UhcLinkedRegister
    pop eax
    ret
UhcLinkedRecreateHook ENDP

; Replaces 0x4C378A..0x4C3790 (mov edi,[esp+10h] / mov edx,[esi+10h]) before the AutoGather pay at 0x4C3798. ESI = the
; action, EBX = the resource, [esp+10h] = the amount. Nothing reads EAX or ECX before they are written.
UhcLinkedAutoGatherHook PROC
    TRACE_ONCE "linkedResource AutoGather (0x4C378A)"
    lea eax, [esp+10h]
    push eax
    push ebx
    push esi
    call UhcLinkedAutoGather
    mov edi, dword ptr [esp+10h]    ; replaced
    mov edx, dword ptr [esi+10h]    ; replaced
    jmp payNext
UhcLinkedAutoGatherHook ENDP

END
