; nurseryFactor's commands (src/features/nurseryfactor.cpp). Entered through a jmp written over the stock code; it
; leaves through an explicit jmp to the verified continuation, or returns for the stock function.
.686
.model flat, c
option casemap :none

include common.inc

UhcNurseryCommand PROTO STDCALL command:DWORD, unit:DWORD

NURSERY_MAGIC_MASK  EQU 0FFFF0000h
NURSERY_MAGIC       EQU 4E520000h   ; 'NR' in the high half of [cmd+8Ch]: a nursery command, never a proto ID

.data
executeNext     dd 007D64FCh    ; mov ebp,[esp+28h], after the five bytes this hook re-executes

.code

; Replaces sub esp,1Ch / push ebx / push ebp (5 bytes) at 0x7D64F7, the head of the type 17h command's per-unit
; execute FUN_007D64F7, thiscall(cmd, unit), ret 4, AL the result; the command loop 0x7C86A4 calls it (vtable +54h)
; for each of the command's units that its player owns, on every machine, in the world update. ECX = the command,
; [esp+4] = the unit. A command whose [cmd+8Ch] carries NURSERY_MAGIC (sent by the UI syscall nurseryFactorCommand)
; is nurseryFactor's: UhcNurseryCommand runs it and the hook returns its result as the stock function would. Any
; other command (a transform, [cmd+8Ch] a proto ID or -1) takes the stock code.
UhcNurseryCmdHook PROC
    TRACE_ONCE "nurseryFactor command (0x7D64F7)"
    mov eax, dword ptr [ecx+8Ch]
    and eax, NURSERY_MAGIC_MASK
    cmp eax, NURSERY_MAGIC
    jne stock
    push dword ptr [esp+4]          ; the unit
    push ecx                        ; the command
    call UhcNurseryCommand          ; stdcall, keeps EBX, ESI, EDI, EBP; AL the result
    ret 4
stock:
    sub esp, 1Ch                    ; stolen 0x7D64F7
    push ebx                        ; stolen 0x7D64FA
    push ebp                        ; stolen 0x7D64FB
    jmp executeNext
UhcNurseryCmdHook ENDP

END
