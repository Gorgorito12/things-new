; Hooks for techRenameEffect (features/techrename.cpp). Each is entered through a jmp written over
; the stock code and leaves through an explicit jmp to a verified continuation, or, for a
; SetTechName effect, through the factory's own epilogue (docs/engine-symbols.md, "Tech tree and
; tech effects").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcTechRenameType:SDWORD    ; SetTechName's effect type ID; -1 until registered

UhcTechRenameRegister PROTO STDCALL :DWORD
UhcTechRenameCreate PROTO STDCALL

.data
registerNext    dd 00524CBCh    ; mov dword ptr [esp+10h],0 / jne 524CDBh (the Data subtypes)
factoryUnknown  dd 00621474h    ; mov ecx,0D5E620h / call 59AD7Ah (error 51Fh) / return 0

.code

; Replaces cmp dword ptr [esi+3504h],0 at 0x524CB5 in FUN_0052277E (database init), right after
; the last stock effect type (Data2, ID 16) is registered. ESI = database. Registers SetTechName,
; then re-executes the cmp last: its flags feed the jne at 0x524CC4, and the mov at 0x524CBC
; between them does not change the flags.
UhcTechRenameRegisterHook PROC
    TRACE_ONCE "techRenameEffect register (0x524CB5)"
    pushad
    push esi
    call UhcTechRenameRegister
    popad
    cmp dword ptr [esi+3504h], 0    ; stolen 0x524CB5
    jmp registerNext
UhcTechRenameRegisterHook ENDP

; Replaces push 51Fh at 0x62146F, the default case of the effect factory FUN_00620535
; (BEffect* cdecl(uchar type)), which the ja at 0x62053E takes for every type above 10h.
; EAX = the type (movzx), [esp] = the ESI the factory pushed. SetTechName's type gets a new
; effect (or 0, which the parse drops at 0x6205D4) and returns like the stock cases, through
; pop esi / ret (0x621480); any other type takes the stock "unknown type" path.
UhcTechRenameFactoryHook PROC
    TRACE_ONCE "techRenameEffect factory (0x62146F)"
    cmp eax, g_uhcTechRenameType
    jne unknownType
    call UhcTechRenameCreate         ; -> the new effect, or 0
    pop esi
    ret
unknownType:
    push 51Fh                        ; stolen 0x62146F
    jmp factoryUnknown
UhcTechRenameFactoryHook ENDP

END
