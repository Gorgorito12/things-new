; Hook for gatherFix (src/features/gatherfix.cpp). Entered through a jmp over the end of the gather
; action's update at 0x4EC8DE (ESI = the action); runs the C tick, then the update's own epilogue.
.686
.model flat, c
option casemap :none

include common.inc

UhcGatherTick PROTO STDCALL action:DWORD

.data
gatherEpilogue dd 004EC8FEh   ; pop esi / pop ebp / add esp,0Ch / ret

.code

UhcGatherTimeHook PROC
    TRACE_ONCE "gatherFix gather tick (0x4EC8DE)"
    push esi
    call UhcGatherTick
    pop ebx
    pop edi
    jmp gatherEpilogue
UhcGatherTimeHook ENDP

END
