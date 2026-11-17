WoL.dll v1.22x - review notes
=============================

Hello, and thank you for sharing the source of WoL.dll. We read it to make sure our
DLL and yours can run in the same game, and we found a few things worth telling you.
All addresses are for the stock TAD age3y.exe (the build your guards expect).
Nothing here needs an answer by a date; take what is useful.


1. hcGatherPointByCommand writes the wrong register (a one-byte fix)
--------------------------------------------------------------------

WoLGpThread replaces each of the seven proto ID loads

    8B 91 <slot>        mov edx, [ecx+slot]

with

    8B 0D <cell>        mov ecx, [cell]

but the next instructions, in all seven blocks, are

    52                  push edx            ; the proto ID for the query
    6A 00               push 0
    8B CE               mov ecx, esi        ; ECX is overwritten here
    E8 ...              call 0x45356D       ; query: add unit type

So the cell value goes to ECX and is thrown away, and the query gets whatever EDX
held. EDX there is what the previous call (0x453618, "set player") left, which is
the player's number on its normal path. The seven blocks therefore search for
proto ID 1..8 (the player number), not for your candidates.

We saw it live on 2026-11-17: 0x669824 = 8B 0D 30 52 C6 00 ... 0x669D9E = 8B 0D 48 52 C6 00,
and the cells held 130h 156h 191h 1B7h 206h 263h 2D2h (your seven candidates).

Fix: write 0x15 instead of 0x0D as the second byte:

    *(volatile unsigned char *)(va + 1u) = 0x15;    /* mov edx,[abs] */

8B 15 <cell> is 6 bytes, like the original, so nothing else changes.


2. Code patched from a background thread, with no way back
-----------------------------------------------------------

WoLGpThread changes the seven loads in 0x669000 while the game is running,
from a thread that is not the game's. The sim thread may be executing
those instructions at that moment (6-byte writes are not atomic), and
VirtualProtect on the page races with anyone else changing the same page.
If one of the seven guards fails, the others stay patched and the cells stay
filled: there is no rollback to the original bytes.

Safer: write the code in DllMain, as your other keys do, and let the late step
only fill the data the new code reads. For example, in DllMain send each load
to a small cave that reads its cell and falls back to the stock [ecx+slot]
while the cell is still 0, so the blocks behave as stock until the thread has
the IDs. Then the thread writes data, never code.
If you keep patching from the thread, check all seven guards first and write
only if all pass, so a partial patch cannot happen.


3. The deck scanner writes by pattern into all memory
-----------------------------------------------------

For hcRevolutionDeck, WoLDeckScanThread (999 passes, 3 s apart) and
sync_scan_patch40 walk every committed region below 0x7F000000 and write dwords
with WriteProcessMemory wherever a 40-byte "deck entry" pattern matches.
WriteProcessMemory also writes read-only pages. Any object that happens to match
the pattern (in the game, in another DLL, in a driver buffer) gets overwritten,
and this runs for about 50 minutes. Such a corruption would look random and be
very hard to trace back to WoL.dll.

Safer: reach the deck from the objects you already hold. Your hooks already know
the player, its home city object (g_hc_obj) and the revolution deck object
([hc+0xD4], g_deck_obj). Write only into arrays reached from those pointers, in
the game thread (the POSTREV hook), and stop the scanner. If a scan is still
needed while you find the path, log candidates only and do not write.


4. No check of the exe build
----------------------------

DllMain patches when the original bytes at each site match, but never checks
which exe it is in. Another exe with the same bytes at one site and different
code around it would still be patched. Our DLL checks, before any write,
ImageBase 0x400000, TimeDateStamp 0x49EF86AC and SizeOfImage 0xB22000 of the
main module (GetModuleHandle(NULL), then the PE header). Three compares, and
every key stays off in a wrong build.


5. Sites shared with our DLL
----------------------------

We checked every site you write against every site our DLL writes or verifies.

  - 0x6698D4..0x6698D9 (hcGatherPointByCommand, block 3): inside a block our
    hcShipmentPointFallback copies (0x6698B4..0x669963). We changed our check so
    those 6 bytes are no longer required, in either load order. Our fallback
    still runs only after the ten stock blocks, including your seven.
  - 0x699227..0x69922C (trickleDisplay NOP) ends right before our check of the
    unit panel's rate row (0x69922D). No shared byte. Our hook at 0x699456 runs
    after the stock (and your) rate row: when one of our features writes a row
    there (gather rate, veterancy, lifespan...), ours is the one shown.
  - 0x7F8114 (hcRevolutionDeck) starts right after a call we verify (0x7F80FD..0x7F8113).
    No shared byte.
  - Your caves and cells (0xC65230..0xC65B87) do not touch what we read in that
    page (0xC65083..0xC650AB, the cfg path).

Both orders were run at the main menu and in a skirmish: your DLL as WoL.upl in
customSyscalls, loaded by your uhc.dll before ours, and by ours after our keys.
All your hooks reported active, and ours applied with no failure.

If you move a site, or add one, please tell us the address and length.


6. Caves run from a read-only, non-executable page
--------------------------------------------------

The caves are in the .rdata slack page 0xC65000. After writing them,
VirtualProtect sets the page back to its old protection (read-only), and the
game then executes code there. It works today only because age3y.exe is not
marked NX-compatible, so Windows does not enforce DEP for it by default. On a
machine with DEP set to AlwaysOn (some companies and security tools do this),
the first call into a cave crashes the game.

Safer: put the caves in memory you own with execute rights, for example
VirtualAlloc(..., PAGE_EXECUTE_READWRITE) once at start, or a code section of
WoL.dll itself, and keep only data cells in the exe's slack.


7. A small request
------------------

Could you send us WOL_DLL.md (the master documentation named in the header)
and the WoL.dll binary you ship? We built your source ourselves for the test
(zig was not available here, so with MSVC), and we would like to test with the
exact file players get.

Thank you again for the source. Happy to help with any of the above.
