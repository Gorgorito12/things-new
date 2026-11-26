; Hooks for cultureUI. Entered through a jmp written over the stock code; each leaves through an explicit jmp to the
; verified continuation (docs/engine-symbols.md, "Culture UI: the style switch during a game").
.686
.model flat, c
option casemap :none

include common.inc

EXTERN g_uhcCultureUiTable:DWORD
EXTERN g_uhcCultureUiCount:DWORD
EXTERN g_uhcCultureUiWorld:DWORD
UhcCultureUiHudBuild PROTO STDCALL

.data
bindNext dd 00407D2Fh       ; cmp ebp,[esi+30E0h]: the bind goes on
hudNext  dd 0076166Fh       ; sub esp,60h: the HUD build goes on

.code

; Replaces the head of the texture bind 0x407D27 (push ebp / mov ebp,[esp+8] / push esi / mov esi,ecx, 8 bytes),
; bool thiscall(texMgr, stage, handle), ret 8: [esp+4] the stage, [esp+8] the handle. With no style active this is
; one compare. With one, the handle is replaced by the style table's entry, as long as the game's world is the one
; the table was made for; a game that ended (another world, or none) switches the table off here.
UhcCultureUiBindHook PROC
    cmp g_uhcCultureUiCount, 0
    jne active
stock:
    push ebp
    mov ebp, dword ptr [esp+8]
    push esi
    mov esi, ecx
    jmp bindNext
active:
    push eax
    mov eax, dword ptr ds:[00C66234h]   ; the game
    test eax, eax
    jz off
    mov eax, dword ptr [eax+13Ch]       ; its world
    cmp eax, g_uhcCultureUiWorld
    jne off
    mov eax, dword ptr [esp+0Ch]        ; the handle ([esp+8] before the push)
    cmp eax, g_uhcCultureUiCount        ; unsigned: a negative handle is left alone too
    jae done
    push edx
    mov edx, g_uhcCultureUiTable
    mov edx, dword ptr [edx+eax*4]
    cmp edx, eax
    je same
    TRACE_ONCE "cultureUI texture bind (0x407D27)"
    mov dword ptr [esp+10h], edx        ; the handle, one push later
same:
    pop edx
done:
    pop eax
    jmp stock
off:
    mov g_uhcCultureUiCount, 0
    pop eax
    jmp stock
UhcCultureUiBindHook ENDP

; Replaces the head of the HUD build 0x76166A (mov eax,[0C672C0h], 5 bytes), thiscall(screen). The style is chosen
; before the HUD's gadgets exist, so the first frame of the game already draws it.
UhcCultureUiHudHook PROC
    TRACE_ONCE "cultureUI HUD build (0x76166A)"
    pushad
    call UhcCultureUiHudBuild
    popad
    mov eax, dword ptr ds:[00C672C0h]   ; stolen 0x76166A
    jmp hudNext
UhcCultureUiHudHook ENDP

END
