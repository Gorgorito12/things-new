; Hook for scenarioCivs. Entered through a jmp written over the stock code; it leaves through an explicit
; jmp to a verified continuation (docs/engine-symbols.md, "Scenario civs").
.686
.model flat, c
option casemap :none

include common.inc

UhcScenarioCivsNext PROTO STDCALL reader:DWORD, database:DWORD  ; features/scenariocivs.cpp

.data
civsEndResume   dd 0052B48Ah    ; lea ecx,[esp+30h]: the rest of the loader, after the civ list
civsRootResume  dd 0052A62Bh    ; mov ecx,[esp+108h]: the root of the document just loaded, and the <civ> loop

.code

; Replaces 0x52B485..0x52B489 (push 0BCEE80h) in the civs.xml loader FUN_0052A590, where the loop over the
; document's top-level elements ends (reached from 0x52B480 after the last one, and from 0x52A68C when the root
; has none). The loader's frame: [esp+1Ch] = the civ database (EDI here as well), [esp+100h] = the XML reader
; it loaded civs.xml with (root node at [esp+108h]). UhcScenarioCivsNext loads data\scenariocivs.xml into that
; reader and returns true: the hook then runs the stock loop again on that document from 0x52A62B, which
; re-reads the root, checks its name (Civs) and appends each <civ> through FUN_0052A4DB like any other. When the
; second pass ends here, it returns false (after marking the new civs) and the loader goes on as stock: it does
; not read the reader again before its destructor (0x52B588). The stack is the same at both places.
UhcScenarioCivsHook PROC
    TRACE_ONCE "scenarioCivs civs.xml end (0x52B485)"
    pushad
    push dword ptr [esp+20h+1Ch]    ; the database: [esp+1Ch] at entry, +20h for pushad
    lea eax, [esp+24h+100h]         ; the reader: [esp+100h] at entry, +20h pushad, +4 the push above
    push eax
    call UhcScenarioCivsNext
    mov dword ptr [esp+1Ch], eax    ; popad's EAX slot
    popad
    test al, al
    jne again
    push 0BCEE80h                   ; stolen 0x52B485
    jmp civsEndResume
again:
    mov edi, dword ptr [esp+1Ch]    ; the database, as 0x52A705 expects it in EDI
    jmp civsRootResume
UhcScenarioCivsHook ENDP

END
