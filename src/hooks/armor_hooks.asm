; Hooks for multiarmor (src/features/multiarmor.cpp). Each re-executes the instructions it
; replaces and leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcArmorRecord PROTO C ctx:DWORD, protoPtr:DWORD, damageType:DWORD, value:DWORD
UhcArmorFor PROTO STDCALL protoPtr:DWORD, damageType:DWORD
UhcArmorErase PROTO C protoPtr:DWORD
UhcArmorCopy PROTO C dst:DWORD, src:DWORD
UhcArmorTypedEffect PROTO C target:DWORD, base:DWORD, amount:DWORD, relativity:DWORD, unapply:DWORD

.data
armorStoreBack  dd 005F5EC3h   ; mov al,1 (the handler's success return)
armorGetterBack dd 0049B345h   ; mov [esp+8],eax
protoDtorBack   dd 00586346h   ; call 5862B2h
protoCopyBack   dd 0067E019h   ; test ebp,ebp
applyCaseBack   dd 008FAE5Ch   ; mov ecx,[esp+2Ch] (the stock Armor change)
applyCaseDone   dd 008FAE73h   ; pop edi (after the stock change)
unapplyCaseBack dd 008FC14Eh   ; mov edx,[esp+28h]
unapplyCaseDone dd 008FC166h   ; pop edi

.code

; 0x5F5EB7, the end of the <Armor> tag handler: ECX = proto, AL = damage type, EDX = value bits,
; [esp+10h] = the handler's first argument (the parse context that owns the damage type list).
UhcArmorStoreHook PROC
    TRACE_ONCE "multiarmor <Armor> tag (0x5F5EB7)"
    pushad
    push edx
    movzx eax, al
    push eax
    push ecx
    push dword ptr [esp+20h+0Ch+10h]
    call UhcArmorRecord
    add esp, 10h
    popad
    mov byte ptr [ecx+1D3h], al
    mov dword ptr [ecx+0C4h], edx
    jmp armorStoreBack
UhcArmorStoreHook ENDP

; 0x49B32F in the armor getter: EAX = proto, BL = damage type; the getter wants the armor value
; (bits) in EAX at 0x49B345. UhcArmorFor is stdcall and keeps EBX, ESI and EDI.
UhcArmorGetterHook PROC
    TRACE_ONCE "multiarmor armor getter (0x49B32F)"
    movzx ecx, bl
    push ecx
    push eax
    call UhcArmorFor
    jmp armorGetterBack
UhcArmorGetterHook ENDP

; 0x58633D, the head of the BProtoUnit destructor (ECX = proto).
UhcProtoDtorHook PROC
    pushad
    push ecx
    call UhcArmorErase
    add esp, 4
    popad
    push esi
    mov esi, ecx
    mov dword ptr [esi], 0B9F404h
    jmp protoDtorBack
UhcProtoDtorHook ENDP

; 0x67E011, the head of the proto copy (ECX = destination, [esp+4] = source).
UhcProtoCopyHook PROC
    pushad
    push dword ptr [esp+20h+4]
    push ecx
    call UhcArmorCopy
    add esp, 8
    popad
    sub esp, 0Ch
    push ebp
    mov ebp, dword ptr [esp+14h]
    jmp protoCopyBack
UhcProtoCopyHook ENDP

; 0x8FAE52, the Armor case of applyData: EDI = target proto, ESI = base proto, EBP = the unapply
; flag (0), [esp+28h] = amount, [esp+2Ch] = relativity.
UhcArmorApplyCaseHook PROC
    TRACE_ONCE "multiarmor Armor effect apply (0x8FAE52)"
    pushad
    push ebp
    push dword ptr [esp+24h+2Ch]
    push dword ptr [esp+28h+28h]
    push esi
    push edi
    call UhcArmorTypedEffect
    add esp, 14h
    test al, al
    popad
    jnz handled
    mov edx, dword ptr [esp+28h]
    mov eax, dword ptr [esi+0C4h]
    jmp applyCaseBack
handled:
    jmp applyCaseDone
UhcArmorApplyCaseHook ENDP

; 0x8FC144, the Armor case of unapplyData: ESI = target proto, EDI = base proto, [esp+24h] =
; amount, [esp+28h] = relativity.
UhcArmorUnapplyCaseHook PROC
    TRACE_ONCE "multiarmor Armor effect unapply (0x8FC144)"
    pushad
    push 1
    push dword ptr [esp+24h+28h]
    push dword ptr [esp+28h+24h]
    push edi
    push esi
    call UhcArmorTypedEffect
    add esp, 14h
    test al, al
    popad
    jnz handled
    mov eax, dword ptr [esp+24h]
    mov ecx, dword ptr [edi+0C4h]
    jmp unapplyCaseBack
handled:
    jmp unapplyCaseDone
UhcArmorUnapplyCaseHook ENDP

END
