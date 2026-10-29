"""Emit src/generated/sites.h: the stock bytes UHC.dll expects at every patch site.

Usage: python -I tools/gen_sites.py <stock age3y.exe> [out.h]

The DLL compares live memory against these bytes before patching, so a site is only written
when the host really is the build documented in docs/uhc-address-map.md. Ranges cover the
bytes a feature overwrites or skips, plus the instruction it continues at.
"""
import hashlib
import pathlib
import sys

STOCK_SHA256 = "b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d"
IMAGE_BASE = 0x400000

# name, VA, length. For .text, .rdata and .data, file offset = VA - IMAGE_BASE.
SITES = [
    # removeConversionRestriction: je 9D5BADh
    ("ConversionRestriction", 0x9D5B6C, 2),
    # ignoreRegistryPath: jl 6420A1h, and the instruction at its target
    ("RegistryPath", 0x57CB54, 6),
    ("RegistryPathTarget", 0x6420A1, 4),
    # deckCardCount: the clamp at 0x7EF026..0x7EF02F plus its ret 4, and the
    # out-of-table path's mov eax,19h
    ("DeckLimit", 0x7EF026, 13),
    ("DeckOutOfRange", 0x7EF005, 5),
    # basePop / extraPop: the clamp sequence plus pop esi / add esp,8 it continues at
    ("PopLimit", 0x4581F3, 0x50),
    # noAILimit: the hard-coded personality table setup plus the xor eax,eax it continues at
    ("AiLimit", 0x603B0B, 0x146),
    # customRevolutionBanners: jne 81A7F1h, the O'Higgins banner block, its dtor call and
    # the instruction at 0x81A7F1
    ("RevBanner", 0x81A7CC, 0x28),
    # removeFameRestriction
    ("FameTrickle", 0x51B025, 5),          # push 0BCD49Ch ("FavoriteUnit")
    ("FameKey", 0xBD62F8, 5),              # "Fame"
    ("FameHcIcons", 0x5C1E1F, 0x1D),       # icon loads, up to and including call 58E3EBh
    ("FameIconSlot", 0x9A218C, 4),         # jump-table slot 3 (Fame) -> default 0x9A20A0
    ("XpIconSlot", 0x9A2194, 4),           # jump-table slot 5 (XP) -> default 0x9A20A0
    ("IconSetCase", 0x9A2098, 8),          # mov ecx,esi / push eax / call 593D42h
    ("IconDefaultCase", 0x9A20A0, 4),      # lea ecx,[esp+18h]
    ("PoliticianCosts", 0x80E490, 7),      # mov eax,[edi] / lea ecx,[esp+14h] / push ecx
    ("PoliticianCosts2", 0x81943D, 7),     # mov edx,[esi] / lea eax,[esp+14h] / push eax
    # hcShipmentPointFallback (FUN_004C6CAE, "get a valid HC gather unit")
    ("GatherFallbackExit", 0x669E2E, 10),  # pop ebp/edi/esi, xor eax,eax, pop ebx/ecx, ret 4
    ("GatherFallbackStore", 0x4C6CB2, 12), # cmp byte [esp+18h],1 / je 669E38h: store-and-return
    ("GatherFallbackBlock", 0x6698B4, 0xB0),  # the stock FortFrontier search block the hook mirrors
    # healNonIdle (FUN_009E0B53, heal action applying a tick): the "target busy" check, from
    # mov ecx,[edi+58h] through the two busy tests to the heal path at 0x9E0C9F
    ("HealIdleCheck", 0x9E0C79, 0x2C),
    # healNonIdle (FUN_009CD865, a healer's automatic target search): mov ecx,[esi+58h] /
    # test / je, the "target is idle" call 0x44F1A7 / test al,al / je, and the next check
    ("HealAutoSearchIdle", 0x9CD9C0, 0x15),
    # extra abstract unit types (FUN_0051A5DC, registers the built-in abstract types): the tail
    # of its last loop and the epilogue pop edi / pop esi / mov al,1 / pop ebx / pop ecx / ret
    ("AbstractTypesEnd", 0x51BA23, 0x15),
    # damageOverTime: TakeDamage FUN_0049B3D9's entry, sub esp,8Ch, and the cmp byte
    # [esp+0C0h],1 the trampoline continues at
    ("DotTakeDamageEntry", 0x49B3D9, 14),
    # damageOverTime: world update FUN_00481A57's entry, sub esp,0Ch / push ebx / push ebp, and
    # the push esi / mov esi,ecx the trampoline continues at
    ("DotWorldUpdateEntry", 0x481A57, 8),
    # damageOverTime (FUN_005F98A0, parses the children of an action): the last tag compare
    # ("ModifyExclusive"), its je to the handler, and the next-child code at 0x5FA126
    ("DotProtoActionTag", 0x5FA10F, 0x1B),
    # damageOverTime: the ProtoAction handler's call 5F98A0h; the tag hook checks its return
    # address 0x5FA213 to know the action comes from protoy.xml
    ("DotProtoActionCall", 0x5FA20E, 5),
    # dodgeAnyUnit (FUN_0049ACAA, "is this hit dodged?"): mov eax,[esi+5Ch] / mov eax,[eax+4],
    # the target's proto ID, and the first compare with the cached ypMonkJapanese ID
    ("DodgeProtoCheck", 0x49ACE5, 12),
    # dodgeAnyUnit: the dodge path the hook enters, push "ypDodge" / call 600BE1h (tech by name)
    ("DodgeTechCheck", 0x6A249C, 10),
    # dodgeAnyUnit log: call 49ACAAh in the damage function and the test al,al after it
    ("DodgeCall", 0x49B023, 7),
    # dodgeSoundSet: push "PowerEvade", the sound set a dodge plays, and the add esi,14h after it
    ("DodgeSound", 0x6A2628, 8),
    # criticalSoundSet: push "PowerCriticalStrike", played at the attacker, and lea eax,[ebx+14h]
    ("CriticalSound", 0x6A2A9A, 8),
    # multipleInstances: call [CreateSemaphoreW] of the single-instance check; the IAT hook knows
    # that call by its return address, 0x55A18B
    ("SingleInstanceSemaphore", 0x55A185, 6),
    # liveBuildingWorkRate: the whole BuildingWorkRate getter, float thiscall(unit):
    # mov eax,[ecx+68h] / test eax,eax / je 9BFE3Eh / fld [eax+28h] (the building's copy) / ret,
    # and the tail the hook continues at, mov eax,[ecx+5Ch] / fld [eax+0D0h] (the proto's) / ret
    ("BuildingWorkRateGetter", 0x9BFE33, 0x15),
    # liveBuildingWorkRate: the getter's four callers, mov ecx,[esi+10h] (ECX = the unit) / call
    # 9BFE33h, up to the first write of EAX after the call (the hook returns another EAX)
    ("WorkRateTrainCall", 0x9EA410, 0x14),            # Train update FUN_009EA28B
    ("WorkRateResearchCall", 0x9E65F4, 0x0D),         # Research update FUN_009E648B
    ("WorkRateCommandResearchCall", 0x9D58D1, 0x0D),  # CommandResearch update FUN_009D5843
    ("WorkRateMaintainCall", 0x6AB23C, 0x14),         # Maintain update FUN_00492F3E (cold chunk)
    # techPrereqRecheck (FUN_004919CE, a player's tech tree update): cmp byte [edi+10h],0 /
    # jne 5096D4h, the dirty test the hook replaces and re-executes
    ("TechPrereqDirtyCheck", 0x491A18, 10),
    # techPrereqRecheck: the not-dirty continuation, pop esi/ebx/edi/ebp / add esp,0Ch / ret 4
    ("TechPrereqNoPass", 0x491A22, 10),
    # techPrereqRecheck: the dirty continuation, xor esi,esi / cmp [edi+8],esi / mov byte
    # [edi+10h],0, the start of the stock re-check of every tech
    ("TechPrereqPassEntry", 0x5096D4, 9),
    # techPrereqRecheck: the re-check loop, entries [tree+4] / count [tree+8], each non-null
    # entry through push ebp / call 5094D8h, up to the loop's end at 0x509618
    ("TechPrereqPassLoop", 0x5095A1, 0x77),
    # techPrereqRecheck (FUN_005094D8, one entry): bit 3 (cached result) and bit 21 (OrPrereqs)
    # of the status bits, then call 5094B4h with ecx = [entry]+1Ch, the player and the flag
    ("TechPrereqEntryUpdate", 0x5094EB, 0x51),
    # techPrereqRecheck: the prerequisite list evaluator FUN_005094B4 the check calls, its head
    # and the loop over [list] / byte [list+4] through vtable slot +8
    ("TechPrereqListEval", 0x5094B4, 0x24),
    ("TechPrereqListLoop", 0x50946A, 0x4A),
    # techPrereqRecheck: the TypeCount ctor (push 0 = type 0, vtable 0BA533Ch) and the base
    # prerequisite ctor that stores the type in byte [+5]
    ("TypeCountCtor", 0x8EE860, 0x10),
    ("PrereqBaseCtor", 0x6201AA, 0x16),
    # techPrereqRecheck: the TypeCount evaluator, up to its KB count call: the KB is
    # [player+80h], used with no null check
    ("TypeCountEval", 0x8EE8E7, 0x34),
    # techPrereqRecheck: the template status records, [[db+5D9Ch]+0Ch] with stride 24h
    # (FUN_004804D1's fallback), and their count [+10h] (the techtree build FUN_0061FE17)
    ("TechTemplateFallback", 0x48050F, 0x1B),
    ("TechTemplateLoop", 0x61FE63, 0x3C),
    # techPrereqRecheck log: the tech name getter, [db+3824h] / count [db+3828h]
    ("TechNameById", 0x5C400B, 0x19),
    # techPrereqRecheck: the world update's call to the tech status update 491A40h, gated by
    # [world+7Ch] and byte [game+0B3Ah]
    ("TechStatusUpdateCall", 0x481D3D, 0x19),
    # techPrereqRecheck: add dword [esi+0F8h],1, the step count the schedule reads, and the game
    # time [esi+108h] the log reads
    ("WorldStepCount", 0x481A87, 0xF),
    # maintainWaitForPop (cold chunk of the Maintain update FUN_00492F3E): call 9E27E4h (the
    # progress fraction [esi+74h]) and the >= 1.0 test whose jne 6AB180h leaves an unfinished
    # cycle; the hook site after it is reached only by this fall-through
    ("MaintainCycleDone", 0x6AB264, 0x19),
    # maintainWaitForPop: mov edx,[esi+68h] / mov eax,[esi+64h] (the hook), the push edx /
    # push eax / call 9E2DEFh (the spawn) it continues at, then the SingleUse test, setState(0Ah)
    # and ret that a held cycle skips
    ("MaintainSpawn", 0x6AB27D, 0x2C),
    # maintainWaitForPop: setState(14h) / ret, the restart a held cycle skips
    ("MaintainRestart", 0x6AB2D1, 0x0F),
    # maintainWaitForPop: the hold continuation, pop ebx / jmp 493039h (the "cycle not complete"
    # exit), and the epilogue it reaches, pop edi / pop esi / pop ebp / add esp,10h / ret
    ("MaintainNotDone", 0x6AB180, 6),
    ("MaintainEpilogue", 0x493039, 7),
    # maintainWaitForPop: the spawn FUN_009E2DEF code the population predicate repeats, verify
    # only: the revolution remap, the proto lookup 45311Bh, the group call 9E2AC8h, the
    # AbstractMonk and count tests and the first used-population sum
    ("MaintainSpawnSetup", 0x9E2E35, 0xBA),
    # maintainWaitForPop: the spawn loop's population test (PopulationCount, flags A3h and 9Fh,
    # cap - used > 0) up to its blocked exit 0x9E2FE2, and the cap >= used + pop branch
    ("MaintainSpawnPopTest", 0x9E2F79, 0x6D),
    ("MaintainSpawnPopTest2", 0x9E3110, 0x19),
    # maintainWaitForPop: the same population test in the group spawn FUN_009E2AC8, verify only
    ("MaintainGroupPopTest", 0x9E2B69, 0x71),
    # transformUpdatesLOS (FUN_009C754C, a unit changes proto in place): call 4981F3h (setProto),
    # which the hook re-executes, and mov ecx,[esi+5Ch] / push esi / call 8F7AD2h it continues at
    ("TransformSetProto", 0x9C763F, 14),
    # transformUpdatesLOS: the entry through call 45311Bh / mov ebp,eax, the player's copy of the
    # new proto (EBP), and push ebp / mov ecx,esi, which make it setProto's argument at [esp]
    ("TransformProtoLookup", 0x9C754C, 22),
    ("TransformPushProto", 0x9C763C, 3),
    # transformUpdatesLOS: push 1 / push 0 / mov ecx,esi / call 483262h (the unit leaves the
    # visibility map with its old LOS) and push 1 / push 1 / ... (it goes back with the new one)
    ("TransformVisRemove", 0x9C756A, 11),
    ("TransformVisAdd", 0x9C772A, 11),
    # transformUpdatesLOS: the layout it relies on. Build completion FUN_006A1F82 copies the
    # proto's LOS, mov edx,[esi+5Ch] / test al,al / mov eax,[edx+48h], to the unit's LOS,
    # mov ecx,[esi+0B4h] / mov edx,[esp+78h] / mov [ecx+90h],edx; the LOS getter FUN_0048206D
    # reads mov edx,[ecx+0B4h] ... fmul dword ptr [edx+90h]
    ("LosBuildCopyRead", 0x6A20B2, 8),
    ("LosBuildCopyWrite", 0x6A20ED, 16),
    ("LosGetter", 0x48207E, 0x20),
    # broadsideMuzzleLimit (FUN_0050339A, set-up of a BroadsideAttack action): from the entry
    # (mov edi,ecx: EDI = the action) through the owner and proto null tests and the Ship test
    # push 1 / call 44CAC4h / jne 50353Ch, which the hook relies on
    ("BroadsideInitHead", 0x50339A, 0x35),
    # broadsideMuzzleLimit: mov ecx,[edi+4] / test ecx,ecx / push esi, the mov esi,6 the hook
    # replaces (the stock 6 muzzles per side), and mov [esp+0Ch],esi / je 503424h after it
    ("BroadsideMuzzleCap", 0x5033CF, 0x11),
    # broadsideMuzzleLimit: the MuzzleR clamp that reads ESI, cmp eax,esi / mov [esp+14h],eax /
    # jg 6A8247h
    ("BroadsideMuzzleClampR", 0x503447, 0x0C),
    # broadsideMuzzleLimit: mov esi,[esp+14h] (the limit again) / mov edx,[edi+6Ch] /
    # mov [edi+80h],edx (the MuzzleR slots, read by the log hook)
    ("BroadsideMuzzleReload", 0x5034B3, 0x0D),
    # broadsideMuzzleLimit: the MuzzleL clamp, cmp eax,esi / mov [esp+1Ch],eax (replaced by the
    # log hook) and the jg 6A8252h it continues at
    ("BroadsideMuzzleClampL", 0x5034E2, 0x0C),
    # broadsideMuzzleLimit: the <SingleUsePlayer> cold block, mov [esp+0Ch],1 / mov esi,[esp+0Ch] /
    # jmp 503424h (limit 1, left unchanged)
    ("BroadsideSingleUseCap", 0x6A8236, 0x11),
    # broadsideMuzzleLimit: the two cold clamp blocks, count = limit, back to 0x503453 / 0x5034EE
    ("BroadsideClampCold", 0x6A8247, 0x16),
    # abilitySlots (FUN_0046188E, command panel refresh): the cold block that appends a page-11
    # (Abilities) command entry 5 more times, from mov ecx,[esp+40h] through mov edi,5 (the count,
    # 0x695BD2) and the do-while that ends in sub edi,1 / je 461C3Fh / jmp 695BD7h
    ("AbilitySlotCopies", 0x695BB6, 0x4C),
    # abilitySlots: cmp byte [eax+esi+3],0Bh / jne 461C3Fh / jmp 695BB6h, the page-11 branch into
    # that block, taken after the first copy is appended
    ("AbilityPage11Branch", 0x4C5AEB, 0x10),
    # abilitySlots: n = [esp+34h]++, the 9-argument call 6EE5CCh (AbilityMgr::GetNth) and its
    # test al,al / lea ecx,[esp+58h] / jne 696C70h; the log hook reads n and GetNth's out slots
    ("AbilityNthCall", 0x696C0B, 0x65),
    # abilitySlots log: call 45EE37h on GetNth's "true" path, and the fcomp it continues at
    ("AbilityButtonRecharge", 0x696C70, 11),
    # wonderPanelSkipAuras (cold chunk of FUN_004586B1, wonder power panel refresh): the eight
    # argument pushes, mov ecx,[esp+5Ch] (the ability manager) and push 0 (n) of the panel's
    # ability request; the hook re-pushes these arguments in this order
    ("WonderPanelAbilityArgs", 0x69EE37, 0x26),
    # wonderPanelSkipAuras: call 6EE5CCh (redirected to the hook), the test al,al / je 69F31Bh it
    # returns to, and the stock record re-check call 44E702h / test byte [eax+1Dh],1 / jne after it
    ("WonderPanelAbilityCall", 0x69EE5D, 0x2D),
    # wonderPanelSkipAuras: the entry of AbilityMgr::GetNthVisibleAbility 0x6EE5CC, which the hook
    # calls once per n: sub esp,3Ch / mov eax,[0C66234h] / push esi / push edi / xor edi,edi / ...
    ("NthVisibleAbility", 0x6EE5CC, 0x14),
    # wonderPanelSkipAuras: the ability record lookup 0x44E702 (thiscall(mgr, index), ret 4), up
    # to its ret 4; out of range it jumps to xor eax,eax / ret 4 at 0x4842F8
    ("AbilityByIndex", 0x44E702, 0x1D),
    # lifespanAfterConstruction (FUN_00482BF6, the lifespan tick): its hot part, push ecx through
    # the ja 483EECh into the cold part, which sets ESI = unit and the frame the tick hook reads
    ("LifespanTickHead", 0x482BF6, 0x2A),
    # lifespanAfterConstruction: fld [esp+0Ch] / fcomp [0B84BE4h] (dt against 0) at the start of
    # the cold part, and the fnstsw ax the tick hook continues at
    ("LifespanTick", 0x483EEC, 12),
    # lifespanAfterConstruction: the tick's exit pop esi / pop ecx / ret 4, where a held unit leaves
    ("LifespanTickReturn", 0x482C20, 5),
    # lifespanAfterConstruction (FUN_004829FA, the fade update): push ecx through the fstp of
    # t = [sub+88h] - dt, which set the frame, EAX, ESI and the commit flags the fade hook reads
    ("FadeUpdateHead", 0x4829FA, 0x20),
    # lifespanAfterConstruction: jne 482A26h / mov ecx,[esp+10h], and the store of t at 0x482A20
    # the fade hook continues at
    ("FadeTimerCommit", 0x482A1A, 12),
    # lifespanAfterConstruction: the fade branches after the store (bit 61, then 4, then 5) up to
    # the ret 8; a held unit continues at 0x482A26
    ("FadeDispatch", 0x482A26, 0x63),
    # lifespanAfterConstruction: the start of the bit-5 branch (the lifespan fade-out), which
    # returns while t > 0; the held path relies on it
    ("FadeOutTimerTest", 0x4A174A, 0x15),
    # lifespanAfterConstruction: FUN_0044DDB4, bool thiscall(unit) "fully built" (no BuildInfo
    # or percent >= 1.0), which changes EAX only, and its false exit
    ("IsBuilt", 0x44DDB4, 0x1F),
    ("IsBuiltFalse", 0x69F904, 3),
    # the is-a test 0x44D7FA, bool thiscall(proto, typeId), ret 4, and its true exit; called by
    # lifespanAfterConstruction (healNonIdle and dodgeAnyUnit call it without a site)
    ("IsA", 0x44D7FA, 0x69),
    ("IsATrue", 0x44F139, 5),
    # gaiaSocketsOnly (FUN_0050703D, the placement check "PLACE"), a unit obstruction of a
    # socketed building: from cmp [esp+1D0h],0 (a5, knowledge) and push [esp+1C0h] (a1, the
    # player) through mov edi,[esp+24h] (the building's proto), the socket type match 0x466C31,
    # add esi,14h (the socket's position) and the exact-position test that falls into the hook
    ("GaiaSocketMatch", 0x508BE6, 0xDB),
    # gaiaSocketsOnly: mov byte [esp+37h],1 (socket found), replaced by the hook, and the
    # jmp 50757Eh it continues at
    ("GaiaSocketFound", 0x508CC1, 10),
    # gaiaSocketsOnly: PLACE's next obstruction entry, mov eax,[esp+50h] / add / cmp / mov / jl;
    # EAX, ECX, EDX and the flags are dead there
    ("GaiaSocketLoopNext", 0x50757E, 0x11),
    # gaiaSocketsOnly: after the loop, cmp byte [esp+37h],0 / jne / mov byte [esp+13h],0 / jmp:
    # a socketed building with no socket found is refused
    ("GaiaSocketMissing", 0x509215, 0x15),
    # customHotkeyContexts (FUN_005C16EA, applies DefaultKeyMapY.xml): call 5C16ABh, find the
    # entry's context by name, and the cmp eax,3 / je 5C17F1h that drops an unknown context
    ("HotkeyFindCall", 0x5C1778, 10),
    # customHotkeyContexts: the whole find function 0x5C16AB the wrapper calls twice (thiscall
    # manager, BString* name, {id,layer}* out; 0 found, 3 through 0x6D0B23 unknown; ret 8)
    ("HotkeyFindContext", 0x5C16AB, 0x3F),
    # customHotkeyContexts: the whole register function 0x628FC0 (thiscall manager, char* name,
    # layer; the record is {[manager+34h], layer}, so the new ID is [manager+34h]; 0 = registered;
    # ret 8)
    ("HotkeyRegisterContext", 0x628FC0, 0x2F),
    # customHotkeyContexts (FUN_0079F851, turns on the selected unit's context): mov edi,[esi+178h]
    # and the test edi,edi / jge 79F9BFh the hook continues at
    ("HotkeyUnitContext", 0x79F897, 14),
    # customHotkeyContexts: the jge target, which reads the manager [[[0C66244h]+74h]+34h] and
    # turns context EDI on with call 0AB3EE3h
    ("HotkeyUnitActivate", 0x79F9BF, 0x26),
    # customHotkeyContexts (FUN_0079EF9C, switches off the 35 stock unit contexts): the last
    # call 4421F3h ("WonderAccel") and the pop esi / ret it returns to
    ("HotkeyDeactivateLast", 0x79F1A5, 7),
    # customHotkeyContexts: the head of 0xAB397F, switch a context off by ID (thiscall manager,
    # id, flag; ret 8), which the wrapper calls for each added context
    ("HotkeyDeactivateById", 0xAB397F, 14),
    # customHotkeyContexts (selection chunk 0x649FA4): mov byte [esp+13h],1 / jmp 64A05Ch, where
    # a selected non-building with a <Train> list only turns BuildAccel on
    ("HotkeyTrainerBuildFlag", 0x64A034, 7),
    # customHotkeyContexts: mov bl,1 / mov edi,esi, the path of a selected Building, which then
    # enters its own context through FUN_0079F851
    ("HotkeyTrainerQualified", 0x64A05A, 4),
    # snareOnlyHitUnit (FUN_004FD289, group recompute): the member's vtbl[34h] velocity, fcomp
    # with the group's pace [esi+7Ch], jnp 4FD53Ah, and the mov ecx,[edi+5Ch] it continues at
    ("SnareGroupPace", 0x4FD3FD, 0x1D),
    # snareOnlyHitUnit: the store path the hook jumps to, vtbl[34h] again / fstp [esi+7Ch] /
    # jmp 4FD417h
    ("SnareGroupPaceStore", 0x4FD53A, 0x14),
    # snareOnlyHitUnit (FUN_004FA03B, member step): fcomp of the slot distance with the limit
    # 0x4F9B69 / jp 4FA183h, mov eax,[esi+4] / or byte [eax],80h (group bit 7, "wait"), and
    # the fld dword [esp+18h] it continues at
    ("SnareSlotWait", 0x4FA172, 0x15),
    # snareOnlyHitUnit (FUN_004F9E05, member loop, a member with its own path): mov ebx,[esp+10h]
    # (the group), mov eax,[ebx+4] / or byte [eax],80h, and the mov eax,[esi+10h] after it
    ("SnarePathWait", 0x6AA510, 0x0D),
    # snareOnlyHitUnit: the same path's slot distance check, from mov esi,[esi+10h] (the member
    # pointer is replaced by its ID) through mov eax,[eax+4] / or byte [eax],80h and the
    # jmp 4F9F99h it continues at
    ("SnarePathCheck", 0x6AA537, 0x3E),
    # snareOnlyHitUnit, code the helpers mirror: the TargetSpeedBoost call 0x4DD22D(target, 0,
    # 0.65f, -1f, -1f, 0, 2, 3000, -1, -1, 1), the snare signature
    ("SnareCreate", 0x4DD201, 0x2C),
    # snareOnlyHitUnit: the modifier init 0x4B3D44 ([+64h] stat, [+68h] value, [+78h] op, flag
    # 15h or 14h by duration, flag 16h exclusive)
    ("SnareModifierInit", 0x4B3D44, 0x5A),
    # snareOnlyHitUnit: the collector's per-action step 0x49F34B (type [+60h], children at
    # [+40h]) and its list loop 0x49F397 ({count +0, data +8})
    ("SnareCollector", 0x49F34B, 0x79),
    # snareOnlyHitUnit: the velocity modifier sum 0x4B3C48 / 0x4B3C7D and its two cold chunks
    ("SnareModifierSum", 0x4B3C48, 0xB7),
    ("SnareModifierSumEnd", 0x4E2A8E, 0x1B),
    ("SnareModifierSumTactic", 0x6A88D6, 0x22),
    # snareOnlyHitUnit: the unit max-velocity getter 0x487E27 (vtable 0xB934B8 slot 34h) and its
    # per-unit record chunk
    ("SnareVelocityGetter", 0x487E27, 0x4D),
    ("SnareVelocityRecord", 0x488612, 0x1E),
    # snareOnlyHitUnit: the unit-by-ID lookup of the member loop, which UnitById mirrors
    ("SnareUnitById", 0x4F9EB7, 0x44),
    # techRenameEffect (FUN_0052277E, database init): lea ecx,[esi+335Ch] / call 5375ACh, the last
    # stock effect type registration (Data2, ESI = database), the cmp dword ptr [esi+3504h],0 the
    # hook re-executes, and the mov dword ptr [esp+10h],0 / jne 524CDBh it continues at
    ("TechRenameRegister", 0x524CAA, 0x1C),
    # techRenameEffect: FUN_0061FF1B, effect type ID by name, which reads the table at [db+335Ch]
    ("TechRenameTypeByName", 0x61FF1B, 0x10),
    # techRenameEffect: the effect factory FUN_00620535's head, movzx eax,byte ptr [esp+4] /
    # cmp eax,10h / push esi / ja 62146Fh: the state its default case is entered with
    ("TechRenameFactoryHead", 0x620535, 0x0F),
    # techRenameEffect: the factory's default case, push 51Fh / mov ecx,0D5E620h / call 59AD7Ah
    # (error) / xor eax,eax / pop esi / ret
    ("TechRenameFactoryDefault", 0x62146F, 0x13),
    # techRenameEffect: the parse FUN_00620572's call of the factory, its null check (je 65BC65h)
    # and the setData call through [vtbl+4] (false: je 621ECAh, which deletes the effect)
    ("TechRenameEffectParse", 0x6205C7, 0x2D),
    # techRenameEffect: BEffect::BEffect(uchar type): vtable 0B965C0h, +4 = -1, +8 = type,
    # +9 = 28h (a general effect, re-applied after a saved game is loaded)
    ("TechRenameEffectCtor", 0x620B8F, 0x1D),
    # techRenameEffect: the stock BEffect vtable (17 slots, .rdata); SetTechName's copies it
    ("TechRenameEffectVtable", 0xB965C0, 0x44),
    # techRenameEffect: the apply dispatcher FUN_007F7E97's call of a general effect,
    # [vtbl+3Ch](player, source tech, unit, flags)
    ("TechRenameApplyCall", 0x7F80FD, 0x17),
    # techRenameEffect: BPlayer::getLocalTechNode FUN_008D0005, the player's node of a tech,
    # created on first use; 0 without a tech manager
    ("TechRenameLocalTechNode", 0x8D0005, 0x27),
    # noCorpseDopples (FUN_0048679A, unit visibility update; unit ESI has left player EBX's view):
    # mov eax,[esp+2Ch] / mov ecx,[esp+54h], the hook site, and the dopple creation it continues
    # at, mov edx,[esi+10h] / ... / call 4DB3D0h, through the jmp 486A30h after it
    ("NoCorpseDoppleCreate", 0x49534D, 0x24),
    # noCorpseDopples: the other way into the site, the DoppleOnlyWhenDead owner test
    # mov edx,[esi+44h] / cmp dword [edx],0 / je 49534Dh / jmp 486A30h
    ("NoCorpseDoppleGaiaCheck", 0x4F1088, 0x11),
    # noCorpseDopples: the stock "no dopple" exit the hook skips to, cmp dword [esp+38h],0 / jne /
    # mov ecx,[esp+3Ch] / test ecx,ebp / jne (then the next player)
    ("NoCorpseDoppleSkip", 0x486A30, 0x17),
    # noCorpseDopples: the stock isAlive call in the same function, mov eax,[esi] / ... /
    # mov eax,[eax+0A4h] / call 502853h (jmp eax); the hook calls unit vtable slot A4h the same way
    ("NoCorpseDoppleAliveCall", 0x4868FA, 0x15),
    # danceBonusCivs, the four dance readers. Each gate: mov eax,[reg+20h] / mov eax,[eax] (the
    # player's first civ ID), the hooked cmp eax,[0C6FB50h] (XPIroquois, the first of the four
    # native compares) and the je the hook continues at. Each branch: the native civs' path the
    # hook enters for a listed civ. The later compares stay free for a nativeCivs port.
    # FUN_008D4790 (train rate): ECX = player; je 8D47CFh; branch call 4819EFh / test / je
    ("DanceTrainGate", 0x8D47A6, 0xD),
    ("DanceTrainBranch", 0x8D47CF, 0xD),
    # FUN_004E0DE5 (XP trickle): ECX = player; je 4E0E29h; branch call 4819EFh / jmp 679D72h
    ("DanceXpGate", 0x4E0DFA, 0xD),
    ("DanceXpBranch", 0x4E0E29, 10),
    # FUN_004ECD39 (gather rate): ECX = player; je 4ECD7Dh; branch call 4819EFh / jmp 679DECh
    ("DanceGatherGate", 0x4ECD4E, 0xD),
    ("DanceGatherBranch", 0x4ECD7D, 10),
    # FUN_00490476 (regeneration): EDI = player; near je 679E66h; branch cmp dword ptr
    # [edi+80h],0 / je 4904BBh (no unit list: no regeneration)
    ("DanceRegenGate", 0x490486, 0x11),
    ("DanceRegenBranch", 0x679E66, 0xD),
]


def main():
    exe = pathlib.Path(sys.argv[1]).read_bytes()
    digest = hashlib.sha256(exe).hexdigest()
    if digest != STOCK_SHA256:
        sys.exit(f"refusing: {sys.argv[1]} has SHA-256 {digest}, expected the stock build {STOCK_SHA256}")
    out = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else pathlib.Path(__file__).parents[1] / "src/generated/sites.h"

    lines = [
        "// Generated by tools/gen_sites.py from the stock age3y.exe",
        f"// (SHA-256 {STOCK_SHA256}). Do not edit by hand.",
        "#pragma once",
        "",
        "#include <cstdint>",
        "",
        '#include "../site.h"',
        "",
        "namespace uhc::sites {",
        "",
    ]
    for name, va, size in SITES:
        raw = exe[va - IMAGE_BASE:va - IMAGE_BASE + size]
        body = ", ".join(f"0x{b:02X}" for b in raw)
        lines.append(f"inline constexpr std::uint8_t k{name}Bytes[] = {{{body}}};")
        lines.append(f'inline constexpr Site k{name}{{"{name}", 0x{va:08X}, k{name}Bytes, sizeof(k{name}Bytes)}};')
        lines.append("")
    lines.append("}  // namespace uhc::sites")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {out} ({len(SITES)} sites)")


if __name__ == "__main__":
    main()
