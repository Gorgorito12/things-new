; Hooks for ageUpBuildings (src/features/ageupbuildings.cpp). Each one replaces the TownCenter compare of an age-up
; picker (reached for a civ that isAsianCiv(player, true) rejects), re-executes it, and when it fails asks the DLL
; whether the cfg lists the player's proto. It leaves through an explicit jmp to the stock accepted or rejected
; continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcAgeUpListed PROTO STDCALL playerProto:DWORD

.data
pickerAccept        dd 007E6926h   ; mov ecx,[0C67310h] (find the dialog)
pickerReject        dd 007E6A2Eh   ; pop edi / pop esi / pop ebp / pop ebx
selectedAccept      dd 007E8059h   ; mov ecx,[esp+14h] (open it for this unit)
selectedReject      dd 007E8092h   ; pop ebp / pop edi / pop esi / pop ebx

.code

; 0x7E6905 in uiPoliticianUI 0x7E686E (16 B replaced). ESI = the player's proto (not null), EDI = the database.
; EAX, ECX and EDX are free: both continuations reload what they use.
UhcAgeUpPickerTcHook PROC
    TRACE_ONCE "ageUpBuildings uiPoliticianUI (0x7E6905)"
    mov eax, dword ptr [edi+5E08h]
    cmp eax, dword ptr [esi+4]
    je accept
    push esi
    call UhcAgeUpListed
    test al, al
    jz reject
accept:
    jmp pickerAccept
reject:
    jmp pickerReject
UhcAgeUpPickerTcHook ENDP

; 0x7E803F in uiPoliticianUIInSelected 0x7E7EC1 (13 B replaced). ECX = the database, EDI = the player's proto of the
; selected unit, EBX = the player, ESI = the unit. EAX, ECX and EDX are free.
UhcAgeUpSelectedTcHook PROC
    TRACE_ONCE "ageUpBuildings uiPoliticianUIInSelected (0x7E803F)"
    mov edx, dword ptr [ecx+5E08h]
    cmp edx, dword ptr [edi+4]
    je accept
    push edi
    call UhcAgeUpListed
    test al, al
    jz reject
accept:
    jmp selectedAccept
reject:
    jmp selectedReject
UhcAgeUpSelectedTcHook ENDP

END
