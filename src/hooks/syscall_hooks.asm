; Hooks for the syscall registry (src/syscalls.cpp). The game builds each syscall module (AI, HC,
; KB, RM, TR, UI, UI2, XS) in one function that registers the stock syscalls one after the other;
; these hooks sit on the first registration of each, where ESI is the module (the code after
; them passes it as `this`). Each hook registers the extra syscalls of its group, re-executes the
; pushes it replaced, and leaves through an explicit jmp to the verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcRegisterSyscallGroup PROTO STDCALL groupId:DWORD, module:DWORD

.data
syscallAiReturn  dd 007294FBh   ; push 0C018E0h (the first stock syscall's name)
syscallHcReturn  dd 005B5E0Fh
syscallKbReturn  dd 00885D1Bh
syscallRmReturn  dd 0060B8C6h
syscallTrReturn  dd 00988E0Ah
syscallUiReturn  dd 00539547h
syscallUi2Return dd 00535765h
syscallXsReturn  dd 006257E0h

.code

; Registers the group's extra syscalls with every register and the flags preserved.
REGISTER_GROUP MACRO groupId
    pushfd
    pushad
    push esi
    push groupId
    call UhcRegisterSyscallGroup
    popad
    popfd
ENDM

; 0x7294F4: push 1 / push 7286DFh
UhcSyscallAiHook PROC
    TRACE_ONCE "syscall group AI (0x7294F4)"
    REGISTER_GROUP 0
    push 1
    push 007286DFh
    jmp syscallAiReturn
UhcSyscallAiHook ENDP

; 0x5B5E08: push 1 / push 4011E6h
UhcSyscallHcHook PROC
    TRACE_ONCE "syscall group HC (0x5B5E08)"
    REGISTER_GROUP 1
    push 1
    push 004011E6h
    jmp syscallHcReturn
UhcSyscallHcHook ENDP

; 0x885D14: push 1 / push 88112Ch
UhcSyscallKbHook PROC
    TRACE_ONCE "syscall group KB (0x885D14)"
    REGISTER_GROUP 2
    push 1
    push 0088112Ch
    jmp syscallKbReturn
UhcSyscallKbHook ENDP

; 0x60B8BF: push 1 / push 9017E5h
UhcSyscallRmHook PROC
    TRACE_ONCE "syscall group RM (0x60B8BF)"
    REGISTER_GROUP 3
    push 1
    push 009017E5h
    jmp syscallRmReturn
UhcSyscallRmHook ENDP

; 0x988E03: push 1 / push 4011E6h
UhcSyscallTrHook PROC
    TRACE_ONCE "syscall group TR (0x988E03)"
    REGISTER_GROUP 4
    push 1
    push 004011E6h
    jmp syscallTrReturn
UhcSyscallTrHook ENDP

; 0x539542: push 5D5E92h (its return-type push comes before the site)
UhcSyscallUiHook PROC
    TRACE_ONCE "syscall group UI (0x539542)"
    REGISTER_GROUP 5
    push 005D5E92h
    jmp syscallUiReturn
UhcSyscallUiHook ENDP

; 0x53575E: push 1 / push 6F1E6Eh
UhcSyscallUi2Hook PROC
    TRACE_ONCE "syscall group UI2 (0x53575E)"
    REGISTER_GROUP 6
    push 1
    push 006F1E6Eh
    jmp syscallUi2Return
UhcSyscallUi2Hook ENDP

; 0x6257D9: push 1 / push 0A5D578h
UhcSyscallXsHook PROC
    TRACE_ONCE "syscall group XS (0x6257D9)"
    REGISTER_GROUP 7
    push 1
    push 00A5D578h
    jmp syscallXsReturn
UhcSyscallXsHook ENDP

END
