; editorSearch (editorsearch.cpp): redirected calls of the scenario editor's list fills. Each asks the key
; whether the entry matches the search text and either goes on to the stock add (a jmp, so the stock routine returns
; to the fill as the original call did) or drops the entry with the add's own stack cleanup.
.686
.model flat, c
option casemap :none

include common.inc

UhcEditorPaletteKeep PROTO C pal:DWORD, unitProto:DWORD
UhcEditorForbidKeep PROTO C dlg:DWORD, entryText:DWORD, entry:DWORD, isTech:DWORD

UhcEditorTriggerKeep PROTO C editor:DWORD, trigGroup:DWORD, pos:DWORD, entryText:DWORD
UhcEditorTypeFill PROTO C editor:DWORD, typeField:DWORD, names:DWORD, entryData:DWORD
UhcEditorParamList PROTO C paramField:DWORD, names:DWORD, param:DWORD

.data
paletteAdd      dd 00AD0056h    ; the palette's add entry, thiscall(palette, entry*, categories*), ret 8
listAdd         dd 00AC9228h    ; the list's add item, thiscall(list, BString* text), ret 4
typeFillNext    dd 008258B8h    ; mov ecx,edi / call 8246E8h: after the type list's two sets
setList         dd 005BECAAh    ; a textField's dropdown names, thiscall(field, array*), ret 4

.code

; Replaces call 0AD0056h at 0x7F537D in the Objects palette fill FUN_007F501E. ECX = the palette, ESI = the
; player's proto of the entry, [esp+4] the entry, [esp+8] its category bits. After the call the fill reloads every
; register it reads (0x7F5382: mov ecx,[0C66234h]); EAX and EDX are not read.
UhcEditorPaletteAddHook PROC
    TRACE_ONCE "editorSearch: Objects palette entry (0x7F537D)"
    push ecx
    push esi
    push ecx
    call UhcEditorPaletteKeep
    add esp, 8
    pop ecx
    test al, al
    jz drop
    jmp dword ptr [paletteAdd]
drop:
    ret 8
UhcEditorPaletteAddHook ENDP

; Replaces call 0AC9228h at 0x9991D0 in the Forbidden Units/Techs dialog's allowed units fill FUN_0099912F.
; ECX = the allowed list, EBX = the dialog, ESI = the proto, [esp+4] the BString of the entry's text. After the call
; the fill frees that BString (0x9991D5) and reads no register the add sets.
UhcEditorForbidUnitHook PROC
    TRACE_ONCE "editorSearch: allowed units entry (0x9991D0)"
    push ecx
    push 0
    push esi
    push dword ptr [esp+10h]
    push ebx
    call UhcEditorForbidKeep
    add esp, 10h
    pop ecx
    test al, al
    jz drop
    jmp dword ptr [listAdd]
drop:
    ret 4
UhcEditorForbidUnitHook ENDP

; Replaces call 0AC9228h at 0x999547 in the allowed techs fill FUN_00999493. ECX = EBP = the allowed list, EDI = the
; dialog, ESI = the tech's index, [esp+4] the BString of its name. After the call: lea ecx,[esp+14h] / call free.
UhcEditorForbidTechHook PROC
    TRACE_ONCE "editorSearch: allowed techs entry (0x999547)"
    push ecx
    push 1
    push esi
    push dword ptr [esp+10h]
    push edi
    call UhcEditorForbidKeep
    add esp, 10h
    pop ecx
    test al, al
    jz drop
    jmp dword ptr [listAdd]
drop:
    ret 4
UhcEditorForbidTechHook ENDP

; Replaces call 0AC9228h at 0x8248C3 in the trigger list fill FUN_0082481C. ECX = ESI = trEdit-Trigger-list,
; EBP = the current group, EDI = the trigger's position in it, [esp+4] the BString of its name, [esp+1Ch] the editor
; (the fill keeps it at [esp+4] of its frame, under four pushes and the argument). The fill gives the row the add
; returns the position as its data (push eax / push edi / call 0AC6CC0h): a dropped entry returns -1, a row that
; call ignores. After that call the loop reads no register but EDI, EBP, EBX and ESI, which are kept.
UhcEditorTriggerAddHook PROC
    TRACE_ONCE "editorSearch: trigger list entry (0x8248C3)"
    push ecx
    push dword ptr [esp+8]
    push edi
    push ebp
    push dword ptr [esp+2Ch]
    call UhcEditorTriggerKeep
    add esp, 10h
    pop ecx
    test al, al
    jz drop
    jmp dword ptr [listAdd]
drop:
    or eax, -1
    ret 4
UhcEditorTriggerAddHook ENDP

; Replaces 0x8258A0..0x8258B7 in the trigger editor's type fill FUN_00825757: lea ecx,[esp+20h] / push ecx /
; mov ecx,ebx / call 5BECAAh (the names) and lea edx,[esp+2Ch] / push edx / mov ecx,ebx / call 0AC19D9h (each entry's
; type index). EBX = the "Type:" textField, EDI = the editor object, [esp+20h] and [esp+2Ch] the two arrays. Every
; register is kept; the continuation 0x8258B8 (mov ecx,edi) reads no flag. Nothing branches into the replaced bytes.
UhcEditorTypeFillHook PROC
    TRACE_ONCE "editorSearch: trigger type list (0x8258A0)"
    lea eax, [esp+20h]
    lea edx, [esp+2Ch]
    pushad
    push edx
    push eax
    push ebx
    push edi
    call UhcEditorTypeFill
    add esp, 10h
    popad
    jmp dword ptr [typeFillNext]
UhcEditorTypeFillHook ENDP

; Replaces call 5BECAAh at 0x8289D5 (tech), 0x828A27 (unit) and 0x828A4E (unit type) in the trigger parameter builder.
; ECX = the parameter's textField, ESI = the parameter (its definition at [esi+13Ch]), [esp+4] the array of names. The array to set comes back in EAX (the same one, or a
; filtered copy the key keeps); the stock setter then runs with the return address of the builder's call. After the
; call the builder jumps to 0x828B61 (or reads EDI, kept) and reads no register the setter sets.
UhcEditorParamListHook PROC
    TRACE_ONCE "editorSearch: trigger parameter list (0x828A27)"
    push ecx
    push esi
    push dword ptr [esp+0Ch]
    push ecx
    call UhcEditorParamList
    add esp, 0Ch
    pop ecx
    mov dword ptr [esp+4], eax
    jmp dword ptr [setList]
UhcEditorParamListHook ENDP

END
