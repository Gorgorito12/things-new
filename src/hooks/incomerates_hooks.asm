; Hook for incomeRates. Entered through a jmp written over the stock code; leaves through an explicit jmp
; to the verified continuation (docs/engine-symbols.md, "Income rates").
.686
.model flat, c
option casemap :none

include common.inc

EXTERN g_uhcIncomeAdds:DWORD
UhcIncomeCount PROTO STDCALL player:DWORD, resource:DWORD, amount:DWORD, caller:DWORD

.data
addNext       dd 0049A990h    ; push ebp: the add goes on

.code

; Replaces the head of the add 0x49A98A (push ecx / mov eax,[0C66234h], 6 bytes), bool thiscall(player,
; resource, float amount, bool), ret 0Ch. ECX = the player; [esp] the return address, [esp+4] the resource,
; [esp+8] the amount. Only the three income callers are counted: the global trickle (returns to 0x4E0CFE),
; unit AutoGather (0x4C379D) and the gather tick (0x4ED1F3). EAX is free: the stolen mov writes it.
UhcIncomeAddHook PROC
    inc g_uhcIncomeAdds                 ; for `log`'s cost line (the flags are not read before the next cmp)
    mov eax, dword ptr [esp]
    cmp eax, 004ED1F3h
    je count
    cmp eax, 004C379Dh
    je count
    cmp eax, 004E0CFEh
    je count
stock:
    push ecx                            ; stolen 0x49A98A
    mov eax, dword ptr ds:[00C66234h]   ; stolen 0x49A98B
    jmp addNext
count:
    TRACE_ONCE "incomeRates add (0x49A98A)"
    pushad
    push eax                            ; the return address
    push dword ptr [esp+2Ch]            ; the amount ([esp+8] before pushad, one push later)
    push dword ptr [esp+2Ch]            ; the resource ([esp+4] before pushad, two pushes later)
    push ecx
    call UhcIncomeCount
    popad
    jmp stock
UhcIncomeAddHook ENDP

END
