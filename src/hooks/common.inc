; Shared macros for the hook files.

UhcTraceHook PROTO STDCALL hookName:DWORD

; Logs "hook reached: <text>" to UHC.log the first time execution passes here. Preserves every
; register and the flags (some hooks branch on the flags they are entered with), and leaves
; ESP as it found it, so it can sit before any stack-relative access.
TRACE_ONCE MACRO text:REQ
    LOCAL hookText, reached, done
    .data
    hookText db text, 0
    reached  db 0
    .code
    pushfd
    cmp reached, 0
    jne done
    mov reached, 1
    pushad
    push OFFSET hookText
    call UhcTraceHook
    popad
done:
    popfd
ENDM
