; Hook for customRevolutionBanners. Entered through a jmp written over the stock code; leaves
; through an explicit jmp to a verified continuation (src/generated/sites.h).
.686
.model flat, c
option casemap :none

include common.inc

UhcRevBannerPath PROTO STDCALL techName:DWORD

.data
bstringCtor      dd 00401A12h   ; BString::BString(const wchar_t*), thiscall
setBannerTexture dd 00638823h   ; thiscall(this = EBP, BString* path)
revBannerDtor    dd 0081A7ECh   ; call 4010CAh (BString dtor on ECX), then falls to 0x81A7F1
revBannerNone    dd 0081A7F1h   ; no banner

.code

; Replaces 0x81A7CC (jne 81A7F1h). On entry the flags hold `repe cmpsb` of the tech name (EAX)
; against "XPRevolutionOHiggins", the only revolution stock gives a banner. The 5-byte jmp also
; covers stock's push of that banner's path, so the O'Higgins case is handled here too.
UhcRevBannerHook PROC
    TRACE_ONCE "customRevolutionBanners (0x81A7CC)"
    mov edx, 0C0ECC8h               ; L"ui\ingame\politicians\REV_banner_chile" (flags kept)
    je build
    push eax
    call UhcRevBannerPath           ; EAX = banner path for XPRevolution<Name>, or 0
    test eax, eax
    jz none
    mov edx, eax
build:
    ; Same sequence and stack slot (ESP+44h) as stock 0x81A7CE..0x81A7E8.
    push edx
    lea ecx, [esp+48h]
    call bstringCtor
    lea eax, [esp+44h]
    push eax
    mov ecx, ebp
    call setBannerTexture
    lea ecx, [esp+44h]
    jmp revBannerDtor
none:
    jmp revBannerNone
UhcRevBannerHook ENDP

END
