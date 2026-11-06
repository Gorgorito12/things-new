; Hooks for xsErrorLog. Entered through a jmp written over the first 6 bytes of each reporter, both
; cdecl with their arguments on the stack, so EAX, ECX and EDX are free. Each one replays
; sub esp,804h and leaves through an explicit jmp to the verified next instruction.
.686
.model flat, c
option casemap :none

include common.inc

UhcXsReport PROTO STDCALL args:DWORD
UhcXsMessage PROTO STDCALL args:DWORD

.data
reportNext  dd 0043A3AAh    ; mov eax,[0C66228h]
messageNext dd 00A56685h    ; mov eax,[0C66228h]

.code

UhcXsReportHook PROC
    TRACE_ONCE "xsErrorLog report (0x43A3A4)"
    lea eax, [esp+4]
    push eax
    call UhcXsReport
    sub esp, 804h           ; replaced
    jmp reportNext
UhcXsReportHook ENDP

UhcXsMessageHook PROC
    TRACE_ONCE "xsErrorLog message (0xA5667F)"
    lea eax, [esp+4]
    push eax
    call UhcXsMessage
    sub esp, 804h           ; replaced
    jmp messageNext
UhcXsMessageHook ENDP

END
