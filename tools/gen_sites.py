"""Emit src/generated/sites.h: the stock bytes UHC.dll expects at every patch site.

Usage: python -I tools/gen_sites.py <stock age3y.exe> [out.h]

The DLL compares live memory against these bytes before patching, so a site is only written
when the host really is the build this script was run on (the stock exe). Ranges cover the
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
    # noAILimitV2: test al,al / je 658900h (TAD table branch) / the 14-entry count and table
    # stores, up to the shared continuation xor eax,eax at 0x603C4F
    ("AiLimitV2", 0x603C34, 0x1B),
    # customSyscalls: the first stock registration of each syscall module (ESI = the module):
    # push 1 / push <fn> (7 B), then push <name> / mov ecx,esi / call 624F52h. The UI module's
    # return-type push comes before its site, so only push <fn> (5 B) is replaced there.
    ("SyscallAi", 0x7294F4, 7),
    ("SyscallHc", 0x5B5E08, 7),
    ("SyscallKb", 0x885D14, 7),
    ("SyscallRm", 0x60B8BF, 7),
    ("SyscallTr", 0x988E03, 7),
    ("SyscallUi", 0x539542, 5),
    ("SyscallUi2", 0x53575E, 7),
    ("SyscallXs", 0x6257D9, 7),
    # asianCivs: the last compare with the cached Asian civ ID [0C6FB88h] in isAsianCiv 0x454ED7
    # (cmp eax,[0C6FB88h] / je 454F2Ah) and in FUN_008D6A7D (cmp eax,[0C6FB88h] / jne 8D6B0Ch)
    ("AsianCivCheck", 0x454F1D, 8),
    ("AsianCivBranch", 0x8D6AC4, 8),
    # asianCivs: the wonder age-up list FUN_0081807A, call 49A2D8h (is Indian) / test al,al /
    # je 8182EBh, after push 1 / mov ecx,ebp
    ("WonderAgeUpCiv", 0x818284, 9),
    # the civ ID by name, int thiscall(database, const char*), -1 if none (verify only)
    ("CivIdByName", 0x58E71F, 0x10),
    # twoScoutCivs: the hero UI's civ tests (mov eax,[esi+1DCh]; push eax / call 8D0318h after push
    # ebx; mov ecx,[esi+1DCh]; mov edx,[0C66234h])
    ("TwoScout1", 0x77EBB2, 6),
    ("TwoScout2", 0x77EF29, 6),
    ("TwoScout3", 0x77DDD2, 6),
    ("TwoScout4", 0x77DFF4, 6),
    # marketUnits: mov edx,[0C66234h] before the market trade test's Market count (0x4C846D)
    ("MarketUnits", 0x7DEF70, 6),
    # explorerUnits: the hero name (lea ecx,[eax+18h] / call 401F47h in FUN_004702DC) and the knockout
    # message (mov edx,[esi+10h] / mov eax,[edx+5Ch])
    ("ExplorerName", 0x6A012A, 8),
    ("ExplorerKnockout", 0x50B01F, 6),
    # nativeCivs: the civs.xml loader's end (lea ecx,[esp+100h], after it sets [civ+10h] for the
    # native civs), four native civ tests and the council age-up list's first compare
    ("NativeCivMark", 0x52B581, 7),
    ("NativeCivTest2", 0x51271F, 8),
    ("NativeCivTest4", 0x453D5E, 15),
    ("NativeCivTest7", 0x67B0A5, 8),
    ("NativeCivTest9", 0x8D52AF, 6),
    ("NativeCouncil", 0x81ADEB, 8),
    # bigButtonCivs / noBigButtonBlds: jne 695955h after isNativeCiv in the command panel FUN_0046188E
    ("BigButton", 0x461BD8, 6),
    # enableFarmAnim: the gather code's compares of a target's proto with the cached Mill and farm IDs
    ("FarmAnim1", 0x4EDA85, 6),    # mov edx,[ebp+140h], before the chain
    ("FarmAnim2", 0x50DE33, 6),    # jne 4EDD6Ch (then jmp 6A8E67h, the Mill branch)
    ("FarmAnim3", 0x73D41A, 8),    # jne 73D427h / mov eax,[eax+5F4Ch]
    ("FarmAnim4", 0x8CEC9F, 5),    # call 4E2C50h, before the proto compares
    ("FarmAnim5", 0x9DDB79, 6),    # cmp ecx,[eax+5E58h] (the Mill flag)
    ("FarmAnim6", 0x4EE07F, 6),    # je 586DFFh
    ("FarmAnim7", 0x4EE2FE, 6),    # je 586E11h
    ("FarmAnim8", 0x6A8FE1, 9),    # call 44CB0Ah / cmp eax,ebx / jne 6A900Ch
    # enableRectFarmAnim: the same for the cached Rice Paddy ID [db+607Ch]
    ("RectFarm1", 0x9DDD80, 0x18), # four loads and cmp ecx,[eax+607Ch]
    ("RectFarm2", 0x4741F0, 6),    # je 4743DDh after test esi,esi
    ("RectFarm3", 0x4EEDB4, 6),    # mov ecx,[0C66234h], before the Rice Paddy compare
    ("RectFarm4", 0x4EEE9E, 6),    # mov ecx,[0C66234h], before the Rice Paddy compare
    # farmingRadius: mov ecx,[0C0BBE0h], the 4.5 X of the gatherer spread
    ("FarmRadius", 0x9DE04D, 6),
    # wonderCivUnitType: call 44CAC4h (is type 16h) in the two wonder age-up placement tests
    ("WonderAgeUnit1", 0x7E6919, 5),
    ("WonderAgeUnit2", 0x7E8050, 5),
    # trainSingleAbstractType: call 44CAC4h (is type 5Dh) in the two train-one-at-a-time tests
    ("TrainSingle1", 0x9CE573, 5),
    ("TrainSingle2", 0x9CE767, 5),
    # selectionLimit: mov eax,32h (the 50-unit selection cap), the getter 0x4E0BEE and seven compares
    ("SelectionCap1", 0x4E0BEE, 5),
    ("SelectionCap2", 0x4E0F5F, 5),
    ("SelectionCap3", 0x4E0F7E, 5),
    ("SelectionCap4", 0x4E10A5, 5),
    ("SelectionCap5", 0x4FC457, 5),
    ("SelectionCap6", 0x4FE663, 5),
    ("SelectionCap7", 0x4FEB94, 5),
    ("SelectionCap8", 0x503DCE, 5),
    # enableAllTeams: push 8D31h ("?"), the last entry of the single-player team list FUN_007A0628
    ("TeamDropdownSp", 0x7A0709, 5),
    # enableAllTeams: the Team 2 entry before it, whose frame offsets the hook repeats (verify only):
    # temporary BString [esp+10h], BString array [esp+14h], int array [esp+20h]
    ("TeamDropdownBlock", 0x7A06A8, 0x61),
    # customCheats: the epilogue of the cheat table build FUN_005515F1 (pop edi / pop esi / pop ebx /
    # add esp,10h), then its ret
    ("CheatTableEnd", 0x551FE6, 6),
    # customCheats: the last stock entry's store before it ({id, enabled, BString, fn}, 16 B) and the
    # cheat text encryption, void cdecl(const char* text, char* out, int size) (verify only)
    ("CheatTableEntry", 0x551FAF, 0x37),
    ("CheatEncrypt", 0x513F73, 0x13),
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
    # hcShipmentPointFallback (FUN_004C6B9E, "get a valid HC gather unit")
    ("GatherFallbackExit", 0x669E2E, 10),  # pop ebp/edi/esi, xor eax,eax, pop ebx/ecx, ret 4
    ("GatherFallbackStore", 0x4C6CB2, 12), # cmp byte [esp+18h],1 / je 669E38h: store-and-return
    ("GatherFallbackBlock", 0x6698B4, 0xB0),  # the stock FortFrontier search block the hook mirrors
    # hcShipmentPointFallback FirstTC: the stored-point check 0x85302C, bool thiscall(hc, unit),
    # null-safe, alive vtbl+A4h, then call 44DDB4h, then call 4802C6h != 1 (setne al), ret 4; the
    # FirstTC helper calls it on the player's first town center
    ("GatherPointValid", 0x85302C, 0x38),
    # healNonIdle (FUN_009E0B53, heal action applying a tick): the "target busy" check, from
    # mov ecx,[edi+58h] through the two busy tests to the heal path at 0x9E0C9F
    ("HealIdleCheck", 0x9E0C79, 0x2C),
    # healNonIdle (FUN_009CD865, a healer's automatic target search): mov ecx,[esi+58h] /
    # test / je, the "target is idle" call 0x44F1A7 / test al,al / je, and the next check
    ("HealAutoSearchIdle", 0x9CD9C0, 0x15),
    # smartHealTargets (FUN_009CD865, the automatic heal search; EBP = owner, healer at [ebp+4],
    # EDI = the query, ESI = candidate): the loop head, cmp [edi+4],esi (the result count) / ... /
    # the entry's unit ID at [[edi]+[esp+10h]] / the unit table lookup / not the healer
    ("SmartHealLoop", 0x9CD923, 0x5F),
    # smartHealTargets: the range test, push esi / mov ecx,ebx / call 470F5Eh (the action's range)
    # / ... / push esi / call 7FCF2Dh (replaced, 5 bytes at 0x9CDA36) / test al,al / jne 9CDA62h
    ("SmartHealRange", 0x9CDA21, 0x1E),
    # smartHealTargets: the loop step at 0x9CDA3F (38h-byte entries), the no-target exit
    # pop esi / pop ebx / pop edi / xor al,al (replaced, 5 bytes at 0x9CDA58) / pop ebp / add esp,
    # 10h / ret, and the accept path 0x9CDA62: healer vtbl+64h(1), 0x9CBDC4(owner, [esi+10h])
    ("SmartHealLoopEnd", 0x9CDA3F, 0x40),
    # overhealSources: the add-HP function FUN_004823A3 (ECX = unit, [esp+4] = amount, [esp+8] =
    # flag): push ecx / push esi / mov esi,ecx / cmp dword ptr [esi+8],8 (replaced, 8 bytes) and
    # the jbe 4823FEh that reads the cmp's flags
    ("OverhealAddEntry", 0x4823A3, 0x0A),
    # overhealSources (the heal tick FUN_009E0B53, EDI = target, ESI = the action, healer at
    # [esi+10h]): fld [edi+64h] / fcomp 1e-6 / ... / mov ecx,edi / call 480408h (replaced, 5 bytes
    # at 0x9E0BBB) / fcomp [edi+64h] / fnstsw / test ah,41h / jnp 9E0D3Fh (HP < max, else state 10)
    ("HealTickMax", 0x9E0BA5, 0x29),
    # overhealSources: the tick's heal, call 487C45h (rate) / fmul / push 1 / ... / push ecx /
    # mov ecx,edi / call 4823A3h (replaced, 5 bytes at 0x9E0CE9) / fld [esp+10h] / fadd [esi+68h]
    ("HealTickAdd", 0x9E0CCF, 0x26),
    # overhealSources (the automatic heal search, ESI = candidate, healer at [ebp+4]): mov ecx,esi /
    # call 45F295h (replaced, 5 bytes at 0x9CD984) / fcomp 1.0 / fnstsw / test ah,1 / je 9CDA3Fh
    ("HealSearchRatio", 0x9CD982, 0x18),
    # overhealDecay, verify only: the HP setter FUN_004820A1 it calls (thiscall(unit, value, flag),
    # ret 8): sub esp,0Ch / push edi / mov edi,ecx / ... / mov [edi+64h],ecx (the store) / the
    # override test
    ("HpSetter", 0x4820A1, 0x22),
    # overhealDecay: the adder's two regeneration calls, push 1 / push eax / mov ecx,esi /
    # call 4823A3h (replaced) / the loop after it: the unit's own regeneration in FUN_004905E1
    # (0x490881) and the Regeneration dance (0x67A03B)
    ("RegenAddHp", 0x49087C, 0x12),
    ("DanceRegenAddHp", 0x67A036, 0x15),
    # extra abstract unit types (FUN_0051A5DC, registers the built-in abstract types): the last
    # loop's jl and the epilogue pop edi / pop esi / mov al,1 / pop ebx / pop ecx / ret. It starts at
    # the jl because the loop's bounds are not ours: a DLL that lengthens the list writes them
    ("AbstractTypesEnd", 0x51BA2F, 9),
    # damageOverTime: TakeDamage FUN_0049B3D9's entry, sub esp,8Ch, and the cmp byte
    # [esp+0C0h],1 the trampoline continues at
    ("DotTakeDamageEntry", 0x49B3D9, 14),
    # damageOverTime: world update FUN_00481A57's entry, sub esp,0Ch / push ebx / push ebp, and
    # the push esi / mov esi,ecx the trampoline continues at
    ("DotWorldUpdateEntry", 0x481A57, 8),
    # the shared action tag hook (actiontags.cpp: damageOverTime, spreadAnyAccuracy) in
    # FUN_005F98A0, which parses the children of an action: the last tag compare
    # ("ModifyExclusive"), its je to the handler, and the next-child code at 0x5FA126
    ("DotProtoActionTag", 0x5FA10F, 0x1B),
    # the action tag hook: the ProtoAction handler's call 5F98A0h; the hook checks its return
    # address 0x5FA213 to know the action comes from a protoy.xml <ProtoAction>
    ("DotProtoActionCall", 0x5FA20E, 5),
    # the action tag hook: FUN_005FA5B3 (a tactics file's <action>, called by the tactics loader
    # FUN_005FAA4F with the proto that loads the file) and its call 5F98A0h; return address
    # 0x5FA623 means the action comes from a .tactics file
    ("TacticsActionCall", 0x5FA60A, 0x19),
    # spreadAnyAccuracy (the projectile launch, after the precalculated roll and the target
    # leading 0x4A5B02): cmp ebx,2 / je 4CEF7Bh (replaced, 9 bytes), then the continuation
    # mov [esi+20h],ebx / mov ebx,[esp+18h] (the unit action) / mov edi,[esp+0ECh] (the target)
    ("SpreadHitRoll", 0x499890, 0x17),
    # spreadAnyAccuracy: the miss stub every miss reaches (from 0x499893 and from the failed lead
    # at 0x6A4BCA): lea eax,[esp+28h] / push eax / mov ecx,esi (replaced, 7 bytes) /
    # call 4CEF8Ch / jmp 499899h
    ("SpreadMissStub", 0x4CEF7B, 0x11),
    # spreadAnyAccuracy (FUN_004CEF8C, the miss offset): fmul [0.25] / fst [esp+0Ch] /
    # fcomp [5.0] / fnstsw ax / test ah,41h / je 4E2CE3h (replaced, 27 bytes), then the
    # continuation fld [esp+0Ch] / fcomp [1e-6] / fnstsw ax / test ah,5 / jnp 4CF073h
    ("SpreadRadius", 0x4CF00B, 0x2C),
    # spreadAnyAccuracy, verify only: the two random draws uniform(-r, r) of FUN_004CEF8C
    # (0x422648 on the sync RNG 0xC66588, stream 2) that the hook leaves to the stock code
    ("SpreadDraws", 0x4CF037, 0x40),
    # dodgeAnyUnit (FUN_0049ACAA, "is this hit dodged?"): mov eax,[esi+5Ch] / mov eax,[eax+4],
    # the target's proto ID, and the first compare with the cached ypMonkJapanese ID
    ("DodgeProtoCheck", 0x49ACE5, 12),
    # dodgeAnyUnit: the dodge path the hook enters, push "ypDodge" / call 600BE1h (tech by name)
    ("DodgeTechCheck", 0x6A249C, 10),
    # dodgeAnyUnit log: call 49ACAAh in the damage function and the test al,al after it
    ("DodgeCall", 0x49B023, 7),
    # dodgeChance, verify only: the dodge test FUN_0049ACAA up to its "not dodged" exit (the frame:
    # push esi / push ebx = [esi+44h] / push edi, the caller's EDI, then EDI = [world+7Ch]); the
    # whole roll path 0x6A249C..0x6A2650 (tech, roll 0x407CE7(2, 100) against 15.0, then from
    # 0x6A24FC the floating text and the sound, which read only ESI, EBX and locals); the caller from
    # mov edi,[ebp+24h] (the damage info) to the call; the synced RNG, the tech test, the tech by
    # name and the damage type loader FUN_0052D454 (the list at [db+44h], count [db+48h])
    ("DodgeTest", 0x49ACAA, 0x6E),
    ("DodgeRollPath", 0x6A249C, 0x1B5),
    ("DodgeCaller", 0x49AF98, 0x92),
    ("SyncRandom", 0x407CE7, 0x40),
    ("TechActive", 0x94AF27, 0x33),
    ("TechByName", 0x600BE1, 0x10),
    ("DamageTypeLoad", 0x52D454, 0x51),
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
    # liveBuildingWorkRate, TrainPoints: the Train fraction function, void thiscall(action), whose
    # only caller is the Train update (call at 0x9EA4B3): frac [ecx+6Ch] = progress [ecx+68h] /
    # points [ecx+64h]. The hook replaces its head, fld [ecx+64h] / fcomp [0C3755Ch] (9 bytes),
    # and re-executes it
    ("TrainFrac", 0x9EA1FA, 0x45),
    # liveBuildingWorkRate, TrainPoints: the rule the hook repeats, verify only. The Train enqueue
    # FUN_009EAC35 looks up the trainer's player's proto (mov ebx,[[esi+10h]+44h] ... push eax /
    # mov ecx,ebx / call 45311Bh / mov edi,eax) and, for the first entry of an empty action
    # (cmp [esi+74h],0 / jg), stores [edi+6Ch] in [esi+64h], or with the trainer flag 9Eh
    # (YPForceTrainAtBaseTrainPoints, call 44D063h) the base proto's (call 45316Eh) [eax+6Ch]
    ("TrainPointsProto", 0x9EAC3D, 0x29),
    ("TrainPointsSet", 0x9EB19F, 0x43),
    # liveBuildingWorkRate, TrainPoints: the same for Maintain. Its fraction function (only caller
    # 0x6AB264, inside maintainWaitForPop's MaintainCycleDone, which the head hook leaves stock):
    # [ecx+74h] = [ecx+70h] / [ecx+6Ch], head fld [ecx+6Ch] / fcomp [0C37468h]; the cycle start
    # (FUN_009E2829) that stores the proto ID in [esi+64h], looks it up for the trainer's player
    # and sets [esi+6Ch] = count [esi+68h] x [edi+6Ch], or with flag 9Eh the base proto's
    # [eax+6Ch] (not multiplied)
    ("MaintainFrac", 0x9E27E4, 0x45),
    ("MaintainPointsProto", 0x9E28BD, 0x11),
    ("MaintainPointsSet", 0x9E2A05, 0x3D),
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
    # transformSpan: BTransformUnitEffect's vtable (0xB96B60) slots setData (0x622822, thiscall(effect, node))
    # and apply (0x7FBBAF, thiscall(effect, 4 arguments), ret 10h), and the apply's call of 0x9C754C
    ("TransformEffectSetDataSlot", 0xB96B64, 0x04),
    ("TransformEffectApplySlot", 0xB96B9C, 0x04),
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
    ("AbilityButtonCost", 0x696C70, 11),
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
    # damageOverTime <AttachSnare>, verify only: the stock snare's target test before that call
    # (unit vtable slot 90h, 0x45EE55: true for a unit that can move) and the creator it calls,
    # int thiscall(unit, stat, value, -1f, -1f, 0, op, ms, -1, -1, exclusive), ret 28h, -1 without
    # an action manager [unit+58h]; it allocates the modifier record [[unit+0B4h]+0C8h] if missing
    ("SnareTargetCheck", 0x4DD1DE, 0x23),
    # the part of SnareCreate after what cantBeSlowed writes: push 0BB8h, and the pushes up to the creator
    ("SnareDurationPush", 0x4DD207, 5),
    ("SnareCreateTail", 0x4DD20C, 0x21),
    ("SnareApply", 0x4DD22D, 0x82),
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
    # the head of getFirePit: mov eax,[0C66234h]; the lookup it calls, thiscall(player, type, startId, 0, -1)
    ("FirePitHead", 0x4819EF, 5),
    ("UnitOfTypeLookup", 0x48195C, 0xC),
    # the dancer count 0x9C1577: mov eax,[eax+5Ch] / test eax,eax / je 9C161Fh
    ("DancerProtoRead", 0x9C1604, 7),
    # startingTC (FUN_0049874F, Player::addUnit, ESI = player, EDI = unit): cmp dword ptr
    # [esi+4F0h],0 / jl 506B2Ah, FirstTC (the placementrules keyword) is only set while it is
    # still -1, and the exit pop ebx / pop ebp / pop edi / mov al,1 / pop esi / ret 8 after it
    ("FirstTcGate", 0x49880A, 0x16),
    # startingTC: the cold chunk the jl enters, mov eax,[0C66234h] / mov ecx,[eax+140h]
    # (database) / mov edx,[edi+5Ch] / mov eax,[edx+4] (the unit's exact proto ID)
    ("FirstTcChunk", 0x506B2A, 0x11),
    # startingTC: cmp eax,[ecx+5E08h] (TownCenter), replaced by the hook, and the jne 498817h /
    # jmp 67ABD4h after it
    ("FirstTcProtoCheck", 0x506B3B, 0x11),
    # startingTC: the store both hooks leave through, mov ecx,[edi+10h] / mov [esi+4F0h],ecx /
    # jmp 498817h
    ("FirstTcSet", 0x67ABD4, 14),
    # startingTC: the FirstTC rule FUN_008CE515 reads [player+4F0h] and looks the unit up in the
    # world's table ([world+0Ch], count [+10h], [unit+10h] = the ID) with no alive test, then
    # calls the distance vtbl+B8h; UnitById mirrors that lookup
    ("FirstTcRuleLookup", 0x8CE597, 0x44),
    # startingTC: setLifespan FUN_0048DCB9 stores the seconds and, when they are > 0, sets state
    # bit 3 (or byte [[esi+4]],8): a FirstTC with that bit has a pending lifespan
    ("SetLifespanArm", 0x48DCB9, 0x28),
    # startingTC: the unit vtable's alive slot A4h (.rdata 0xB9355C = 0x44D019), called for the
    # old FirstTC
    ("UnitAliveSlot", 0xB9355C, 4),
    # transformInventory (FUN_009C754C, a unit changes proto in place): mov eax,[esi+58h] /
    # test eax,eax / je 9C763Ch, which the hook re-executes, and the action manager release
    # push eax / call 4BA630h / add esp,4 / mov dword [esi+58h],0 it continues at (the other
    # continuation, 0x9C763C, is TransformPushProto)
    ("TransformInvHook", 0x9C7625, 0x17),
    # transformInventory: push ebx / mov ebx,[esi+44h] through the other players' knowledge base
    # loop (call 876D3Bh drops the unit, reading its old resource type) and the own player's
    # call 472AFDh, which run before the hook; ESI and EBP are unchanged in it
    ("TransformKbRemove", 0x9C75CF, 0x56),
    # transformInventory: the other players' knowledge base loop after setProto, up to its
    # call 483DA5h (takes the unit back, reading its amounts)
    ("TransformKbReAdd", 0x9C766F, 0x23),
    # transformInventory: unit creation's inventory seed (cold chunk of FUN_00498274), which the
    # helper repeats: call 9BFE5Ah (a fresh inventory) / test / je, then push [ebp+0E0h] (the
    # proto's resource object, InitialResource first) / lea ecx,[eax+4] / call 480A73h
    ("InventorySeed", 0x67DE0D, 0x1E),
    # transformInventory: FUN_009BFE5A, thiscall(unit) -> inventory: frees [[unit+0B4h]+94h]
    # (cdecl 4BA757h), allocates a new one (86A865h: pool 0CAFCA8h, -1 at +0Ch/+10h), stores the
    # unit ID at +0 and returns it; both exits through ret
    ("InventoryRecreate", 0x9BFE5A, 0x6E),
    # transformInventory all: FUN_004BA757, cdecl(inventory): clears the list, -1 at +0/+0Ch/+10h,
    # and returns the object to the pool's free list; through its ret
    ("InventoryFree", 0x4BA757, 0x50),
    # transformInventory: ResList copy 0x480A73, thiscall(dst, src), ret 4: the [0C6DF38h] raw
    # encoded entries and the total, when both arrays exist
    ("ResListCopy", 0x480A73, 0x49),
    # transformInventory scale: ResList scale 0x480B94, thiscall(list, float f), ret 4: each
    # decoded entry times f, then the total recompute 58EF02h
    ("ResListScale", 0x480B94, 0x7E),
    # transformInventory: ResList total recompute 0x58EF02, the encoding the helper decodes:
    # entry r = [list][r] XOR [0C6DF14h+4r] for r < [0C6DF38h], total [list+4] XOR [0C6DF10h]
    ("ResListTotal", 0x58EF02, 0x81),
    # noTrainNearEnemyTC hooks WorkRateTrainCall (mov ecx,[esi+10h] / call 9BFE33h in the Train
    # update FUN_009EA28B, and mov ebx,[0C66234h] / mov eax,[ebx+13Ch] at the continuation
    # 0x9EA418). Its head: mov eax,[esi+10h] / push edi / mov edi,[eax+44h] / test edi,edi / jne,
    # ESI = the Train action, [esi+10h] = the trainer, [trainer+44h] = its player
    ("TrainUpdateTrainer", 0x9EA2B2, 0x0B),
    # noTrainNearEnemyTC: after the continuation, fmul [eax+310h] / push 16h / mov ecx,esi /
    # fstp [esp+14h] / call 485D2Ch: ECX is written before it is read, EDX is not read (0x485D2C
    # starts with mov edx,ecx)
    ("TrainRateScale", 0x9EA424, 0x13),
    # noTrainNearEnemyTC (FUN_008CE935, the placement rule distanceAtLeastFromType): its FirstTC
    # loop, world [[0C66234h]+13Ch], players 1 .. [world+5Ch]-1 through call 44CB21h, FirstTC
    # [player+4F0h] (-1: none), the unit table [world+0Ch] below [world+10h] with the ID check
    # [unit+10h], and the distance call [vtbl+0B8h](point) on the TC
    ("FirstTcRuleLoop", 0x8CE9BE, 0x68),
    # noTrainNearEnemyTC: the same rule's player filter [ebp+18h]: 3 (enemy) calls 484D2Dh and
    # 2 (ally) 4707ECh, both thiscall(the TC's owner [tc+44h], the builder's player ID); 1 (self)
    # compares [[tc+44h]], the owner's player ID
    ("FirstTcRuleFilter", 0x8CEB45, 0x37),
    # noTrainNearEnemyTC: player by ID 0x44CB21, thiscall(world, id): [world+58h][id] for
    # 0 <= id < [world+5Ch], ret 4; out of range its null exit xor eax,eax / ret 4
    ("PlayerById", 0x44CB21, 0x1E),
    ("PlayerByIdNull", 0x4649E1, 5),
    # noTrainNearEnemyTC: unit by ID 0x44CC6D, thiscall(world, id): [[world+0Ch]+4*(id & 3FFFFh)]
    # below [world+10h] whose [unit+10h] is id, ret 4; otherwise its null exit
    ("UnitById", 0x44CC6D, 0x3A),
    ("UnitByIdNull", 0x4E2A35, 5),
    # noTrainNearEnemyTC: isEnemy 0x484D2D, bool thiscall(player, id): [player+1D4h+4*id] == 2 for
    # 0 <= id < 10h, ret 4
    ("PlayerIsEnemy", 0x484D2D, 0x20),
    # noTrainNearEnemyTC near, verify only: the world's spatial query FUN_004A1C55, int
    # thiscall(world, const float* point, float radius, char precise, list*), ret 10h (a box query
    # through 0x462DBA into the obstruction manager's scratch, then with precise the entries whose
    # vtable+0B8h(point) <= radius are copied to the list {data, count, capacity}), and the type
    # branch of the placement rule FUN_008CE935 that calls it with precise 1
    ("UnitsNearPoint", 0x4A1C55, 0xF8),
    ("TypeRuleQuery", 0x8CEA69, 0x22),
    # noTrainNearEnemyTC warning, verify only: the dodge's floating text 0x6A24FC..0x6A2608 (text
    # manager [world+8A8h], visible-to test 0x4818F4(unit, [game+3C0h]), ret 4; the config reads,
    # 0x46A144 for the two times, int thiscall(0C66500h, [[id ptr]], out*), ret 8; then
    # 0x8023AE(text, time1, time2, unit ID, float[3] motion, colour ARGB, 1.0, 0, -1), ret 24h,
    # whose head refuses an empty text or a negative unit ID and whose body reads the three floats
    # and appends the text to the manager's list, returning its index)
    ("DodgeFloatingText", 0x6A24FC, 0x10D),
    ("FloatingTextAdd", 0x8023AE, 0xC4),
    ("UnitVisibleTo", 0x4818F4, 0x45),
    ("ConfigInt", 0x46A144, 0x3F),
    # overhealHitpointBars, the floating HP bars (bar chunk 0x45FAA2 of the unit visual update):
    # mov ecx,esi (the unit) / jne 6A1431h (under construction: the build fraction instead), the
    # hooked call 45F295h (health ratio, the bar's fill) and the fstp [esp+10h] it continues at
    ("OverhealBarRatio", 0x45FAA7, 0x11),
    # overhealHitpointBars (FUN_004C4FB5, adds a unit to a selection group): mov ecx,ebp (the
    # unit) / the hooked call 45F295h, and fadd [esi+1Ch] / pop edi / pop ebx / fidiv [esi+14h]
    # (the group's average health, read by the group bar and 'Group Health') it continues at
    ("OverhealGroupRatio", 0x4C5012, 0x0F),
    # overhealHitpointBars, selection panel unitHitPointsValue: mov ecx,ebx (the unit) / ... /
    # fistp [esp+88h] (the HP) / fldcw, the hooked call 480408h (max HP) and the fnstcw after it
    ("OverhealPanelMax", 0x698B18, 0x26),
    # overhealHitpointBars, selection panel stat row 'Hit Points': mov ecx,edi (the unit) / fld
    # [edi+64h] / ... / fistp [esp+30h] (the HP), the max HP getter inlined at 0x4D7575..0x4D75AC
    # (its first instruction hooked; its branches stay inside or rejoin, as do the cold
    # 0x69FB66/0x69FB6E, at 0x4D75AD) and the fnstcw at 0x4D75AD it continues at
    ("OverhealStatMax", 0x4D7560, 0x51),
    # overhealHitpointBars, same row: EAX = the database proto ([[[game+140h]+54h]+[proto+8]*4],
    # not null), the hooked fld [eax+98h] (the base of '%d/%d (%d+%d)') and the fnstcw after it
    ("OverhealStatBase", 0x4D75DA, 0x45),
    # overhealHitpointBars (FUN_009AF31A, ObjectInfo_singleUnitStats): call 45316Eh, the database
    # proto of the unit, stored at [esp+2Ch] ([esp+30h] after the push ebp at 0x9AF354)
    ("OverhealInfoProto", 0x9AF33B, 0x19),
    # overhealHitpointBars, same panel: fld [esi+64h] / mov ecx,[esp+30h] (the database proto) /
    # ... / fistp [esp+28h] (the HP), the hooked fld [ecx+98h] (the base) and the fnstcw after it;
    # then mov ecx,esi (the unit) / ... / fistp [esp+20h], the hooked call 480408h (max HP) and
    # the fnstcw after it
    ("OverhealInfoBase", 0x9AFA07, 0x2D),
    ("OverhealInfoMax", 0x9AFA34, 0x23),
    # overhealHitpointBars segment, the floating bar's queueing: lea ecx,[esp+18h] (the bar's
    # position, computed by 0x406BDB) / ... / push [unit+88h] (colour byte) / push [[unit+44h]]
    # (player ID) / push [esp+10h] (fill) / push 1.0 (scale) / push ecx / mov ecx,[[0C66234h]+13Ch]
    # (world) / call 45FB71h, and the replaced jmp 4516B3h after it
    ("OverhealSegmentQueue", 0x45FB3F, 0x32),
    # overhealHitpointBars segment: the queue function FUN_0045FB71, thiscall(world, pos*, scale,
    # fill, player, colour byte), ret 14h: grows [world+8D0h] to count [world+8D4h] + 1 (0x408308)
    # and fills a 28-byte record (+0 position, +0Ch scale, +10h fill, +14h player, +18h byte)
    ("HpBarQueue", 0x45FB71, 0x6F),
    # overhealHitpointBars segment, the bar renderer FUN_0045C4AF (ECX = EBP = world): the replaced
    # mov ebx,[ebp+8D4h] (the record count), test / jle, then the vertex lock 0x40A6A2(count*6,
    # 24h, &start) of the device [0C66044h]
    ("HpBarRenderStart", 0x45C4AF, 0x3F),
    # overhealHitpointBars segment, the renderer's per-record loop 0x45C60B..0x45CB91 (colour from
    # the byte or [player+0C8h], then six 24h-byte vertices: +0 position, +0Ch the constant at
    # 0C66544h, +18h colour, +1Ch u, +20h v; the left ones (v0, v2, v3) at P - scale/2 x B with
    # u = 0.5 + fill/2, the right ones at P + scale/2 x B with u = fill/2, B = [[game+148h]+28h]),
    # and its end, add eax,1 / add ecx,1Ch (replaced, 6 bytes at 0x45CB72) / add edi,24h / ...
    ("HpBarRenderLoop", 0x45C60B, 0x587),
    # overhealHitpointBars segment: the dynamic vertex buffer behind 0x40A6A2 ([device+660h]): a
    # request larger than its size [vb+4] returns null (0x40A689), and the renderer then draws no
    # bar that frame
    ("DynamicVbLock", 0x40A6A2, 0x45),
    ("DynamicVbFull", 0x40A689, 0x19),
    # overhealHitpointBars segment, the stat row's HP text formats, a push of '%d/%d' (0BA2054h,
    # 0x4D7651) or of '%d/%d (%d+%d)' (0C34A54h, cold 0x69A9C0) right after the HP and the max are
    # pushed ([esp] = HP, [esp+4] = max), followed by a push of the buffer and the swprintf 0x444EFB
    ("OverhealTextStat", 0x4D7647, 0x15),
    ("OverhealTextStatSplit", 0x69A9B0, 0x1B),
    # overhealHitpointBars segment, the portrait bar: the selection panel's group bar from mov edx,
    # [esp+78h] (the group) to the tail lea ecx,[esp+70h] / call 4010CAh (0x4C83DF, the hook, after
    # the chosen colour gadget was filled through 0x44B8B8 / 0x590772 and raised through 0x447F7B;
    # [esp+50h] = the panel, the same stack level all along), and the cold yellow / red choices
    ("OverhealPortraitTail", 0x4C82E6, 0x102),
    ("OverhealPortraitColours", 0x69A614, 0x16),
    # the panel's lookups of its three bar gadgets by name (0xAB7C2F(panel, &handle, &name, 1),
    # stored at [panel+310h] / +314h / +318h) and the lookup itself: 0x402733 narrows the name,
    # 0x433812 searches the panel's gadgets and writes [0C672C0h] (no gadget) when none matches
    ("HealthBarGadgets", 0x9BAEE5, 0x87),
    ("GadgetByName", 0xAB7C2F, 0x26),
    # a progress bar gadget from its handle (cdecl, null if none), the handle release, the fill
    # (thiscall(bar, float), clamped to [0, 1]), and the show and hide behind the UI commands
    # gadgetReal (0x7E2244) and gadgetUnreal (0x442BE7): thiscall(manager, handle), ret 4, a call of
    # the gadget's vtable +54h / +58h(0)
    ("ProgressGadget", 0x44B8B8, 0x23),
    ("GadgetRelease", 0x40431B, 0x2C),
    ("ProgressFill", 0x590772, 0x49),
    ("GadgetShow", 0x447F7B, 0x46),
    ("GadgetHide", 0x448F13, 0x39),
    # overhealHitpointBars stat: after the stat panel's HP row, mov edi,2 / mov [esp+2Ch],edi at
    # 0x4D76DB (the row counter; EDI is the row the Group Health branch writes), and that Group
    # Health row (0x69A9D3..0x69AB0F), whose calls the overheal row repeats: the row gadgets through
    # 0x4C519C, the label style 0D6F5D0h and the value style 0C6657Ch (vtable +84h), the text
    # (+80h), +54h, the help texts [gadget+68h] cleared, then add edi,1 / mov [esp+2Ch],edi
    ("OverhealStatRow", 0x4D76DB, 0x09),
    ("GroupHealthRow", 0x69A9D3, 0x13C),
    ("GadgetRef", 0x4C519C, 0x1B),
    ("BStringFromWide", 0x401A12, 0x28),
    ("BStringSet", 0x40196F, 0x24),
    # overhealHitpointBars, verify only: the max HP getter FUN_00480408 the hooks call (override
    # [[[unit+0B4h]+0C8h]+4] if > -1e-6, else [proto+98h], 0 with no proto), the health ratio
    # FUN_0045F295 the ratio helper mirrors (0 below 1e-6, 1.0 when HP >= max, else HP / max),
    # and the stores of the <InitialHitpoints> and <MaxHitpoints> tag handlers, fstp [ecx+9Ch] /
    # fstp [ecx+98h], the proto fields the hooks read
    ("MaxHitpointsGetter", 0x480408, 0x26),
    ("HealthRatio", 0x45F295, 0x48),
    ("InitialHitpointsTag", 0x5F5CE3, 6),
    ("MaxHitpointsTag", 0x5F5D39, 6),
    # showGatherRate (FUN_004ECD87, the gather tick BUnitGatherAction::collectStuff_2, thiscall
    # on the action, ret 4): sub esp,1Ch / push esi / push edi / ... / mov esi,ecx (ESI = the
    # action), and the two later pushes, push ebp and push ebx, that put the elapsed-time
    # argument at [esp+30h]; push ebx follows mov ecx,[esi+14h] (the target's ID)
    ("GatherTickHead", 0x4ECD87, 0x14),
    ("GatherTickPushEbp", 0x4ECDCC, 7),
    ("GatherTickPushEbx", 0x4ECE16, 0x0A),
    # showGatherRate: mov eax,[esi+10h] / test / je, cmp dword [eax+44h],0 / je: the gatherer
    # and its player are not null past this point
    ("GatherTickGatherer", 0x4ECE6D, 0x15),
    # showGatherRate: call 4ECD39h (Gathering dance) / fmul [esp+14h], ST0 = the rate per second,
    # the fcom / jnp 6A8AEAh that ends the action at <= 1e-6, the record hook's fmul [esp+30h]
    # (elapsed) / fst [esp+14h], and the fcomp [esp+1Ch] it continues at
    ("GatherTickRate", 0x4ED02A, 0x26),
    # showGatherRate: the amount times [player+37Ch] (the record applies it to the rate), then
    # the AbstractShrine test push 58h / call 44CAC4h on the target that zeroes the amount
    ("GatherTickPlayerRate", 0x4ED130, 0x2A),
    # showGatherRate: cmp dword [player+338h],0 / jne 6A8CBEh, which also zeroes the amount
    ("GatherTickPlayerBlock", 0x4ED1A4, 0x14),
    # showGatherRate: the add to the stockpile, push [esi+70h] (the resource) / call 49A98Ah
    ("GatherTickAddResource", 0x4ED1E1, 0x12),
    # showGatherRate (FUN_004D70ED, stat panel fill, EBP frame): the stock AutoGather row gate
    # the panel hook mirrors, byte [[ebp+8]+21h], row [esp+2Ch] in 0..8, [[ebp+8]+14h] = 1
    # selected unit, unit [esp+38h] built, [unit+58h], proto flag 9Bh, not Herdable, and the
    # call 485CAC(mgr, 1Dh) / jne 69AF6Dh into the row writer (verify only)
    ("StatPanelAutoGatherGate", 0x4D76FF, 0x135),
    # showGatherRate: mov esi,[esp+38h] / mov ecx,[esi+5Ch], the join point after the
    # AutoGather row (the panel hook), and the test ecx,ecx / je it continues at
    ("StatPanelAfterAutoGather", 0x4D7834, 0x0B),
    # showGatherRate: the row writer's head, the label and value gadgets of row EBX from
    # [[esp+50h]+174h/198h]; a missing gadget jumps back to 0x4D7834
    ("StatPanelRowWriter", 0x69AF7C, 0x64),
    # showGatherRate: the AutoGather resource loop, mov ecx,[0C66234h] (the row hook) / mov edx,
    # [ecx+140h] ..., whose only outputs to the formatter are EBX (resource) and [esp+1Ch] (rate)
    ("StatPanelAgLoop", 0x69AFE0, 0x4A),
    # showGatherRate: the row formatter, "%s (<icon=...>):" and "%.2f/s" or "%d/s", the row
    # count add [esp+2Ch],1 and the jmp 4D7834h back
    ("StatPanelRowFormat", 0x69B02A, 0x15D),
    # showGatherRate, the minimized interface (the stat panel fill above returns at 0x4D7261 there):
    # the unit panel's own AutoGather rate, gadgets [[esp+50h]+33Ch/340h] (unitResourceRateLabel
    # and unitResourceRateValue), label "%s (<icon>):" through 0x706EFB and 0x444EFB (verify only)
    ("UnitPanelRateRow", 0x69922D, 0x6C),
    # ... and its join point, mov edi,[esp+54h] / mov ecx,edi, the hook
    ("UnitPanelAfterRate", 0x699456, 0x06),
    ("ResourceIconText", 0x706EFB, 0x10),
    # ... the current selection, from the UI globals only (the stat panel fill's [ebp+8])
    ("CurrentSelectionGroup", 0x453B28, 0x21),
    # showGatherRate (FUN_005CFA7C, data-ref registration): mov dword ptr [esp+2Ch],5FDE49h, the
    # provider of id 68h currentUnitGatherRateString (type 3); the imm32 at 0x5D2D3C is replaced
    ("GatherRateStringRef", 0x5D2D38, 8),
    # showGatherRate: the stub that provider was, xor al,al / ret 4
    ("DataRefStub", 0x5FDE49, 5),
    # showGatherRate: the formatText evaluator's type-3 case: value {type 3, BString 0}, the
    # provider call through jmp eax with [0C6DF7Ch] = the argument, the BString copy and free
    ("DataRefStringEval", 0x44A635, 0x64),
    # showGatherRate: the data refs' current unit, [[[0C67310h]+920h]+13Ch] in world
    # [[0C66234h]+13Ch], as currentUnitBuildingWorkRate FUN_006F49B1 looks it up
    ("CurrentUnitRef", 0x6F49B1, 0x41),
    # fld dword ptr [edx+0D0h] in it: the rate the panel shows
    ("CurrentUnitRateRead", 0x6F49FC, 6),
    # showGatherRate: the proto flag test 0x45EE02 (thiscall(proto, bit), ret 4), bitset
    # [proto+50h] / count [proto+54h]
    ("ProtoFlag", 0x45EE02, 0x35),
    # showGatherRate: the abstract index test 0x44CAC4 (thiscall(proto, index), ret 4)
    ("IsAbstractIndex", 0x44CAC4, 0x46),
    # showGatherRate: the resource's name string ID 0x60782A (thiscall(database, resource),
    # [db+180h] / count [db+184h], -1 out of range)
    ("ResourceNameId", 0x60782A, 0x22),
    # showGatherRate: BString from a string ID 0x58EA52 (thiscall(this, id), ret 4), the
    # assign forwarder 0x443BB8 (thiscall(this, BString*, -1, -1)) and the free 0x4010CA
    ("BStringFromId", 0x58EA52, 0x19),
    ("BStringAssign", 0x443BB8, 0x0F),
    ("BStringFree", 0x4010CA, 0x1F),
    # buildingWorkRateAuras (FUN_005F5645, ModifyType name -> stat): the last compare, push -1 /
    # push 0 / push "AutoGatherRate" / mov ecx,esi (ESI = the name) / call 443C10h, the hooked
    # neg eax / sbb eax,eax / and al,0F1h, and the pop esi / add eax,0Eh / ret it continues at
    ("ModifyTypeNameTail", 0x5FE6C7, 0x1B),
    # buildingWorkRateAuras: the head of the name compare 0x443C10 the hook calls again, int
    # thiscall(BString*, const wchar_t*, flag, n), ret 0Ch; 0 = equal, case ignored for flag 0
    ("ModifyTypeNameCompare", 0x443C10, 0x10),
    # tech subtypes: BDataEffect::setData's call of the subtype name lookup 0x61FF5D, and the two subtype
    # switches of applyData and unapplyData: cmp eax,63h / ja, cmp eax,5Eh / ja. No branch lands inside.
    ("DataSubtypeLookupHead", 0x61FF5D, 5),
    ("DataSubtypeAttrCall", 0x6206B2, 5),
    # teamKillBounty: FUN_0049BD52's mov ecx,[esp+14h] / mov edx,[esi], the amount and the killer's ID for
    # the team's XP routine 0x49BDC0
    ("TeamBountyPay", 0x49BDAB, 6),
    # resourceBounty: the handler the tag table's builder registers for <Bounty> (mov [esp+10h],5F5D79h, its
    # immediate), and the head of TakeDamage's kill branch, mov ecx,[esp+28h] / push ecx
    ("BountyTagHandler", 0x51D669, 4),
    ("BountyKillBranch", 0x4D4E0C, 5),
    # hcTargetTechs: the head of the tech <Flag> reader FUN_00620C2F (push esi / mov esi,[esp+8]), the only call of applyEffects, and the
    # heads of removeEffects (push ebx / push ebp / mov ebp,[esp+0Ch]) and of the pass after a load
    # (push ebx / push ebp / push edi / mov edi,[esp+10h]); the check of who is an enemy, verify only
    ("TechFlagHead", 0x620C2F, 5),
    ("TechApplyCall", 0x94D0AE, 5),
    ("TechRemoveHead", 0x94DCB2, 6),
    ("TechLoadHead", 0x94DDEA, 7),
    ("IsEnemyHead", 0x484D2D, 6),
    # detonationDeath: the only call of the kill handler, in the kill queue's drain 0x493D46; the head of
    # the area damage, verify only
    ("DetonationKillCall", 0x493D8F, 5),
    ("DetonationAreaHead", 0x4C9D89, 10),
    # detonationDeath, the delete command: in its executor FUN_007CCF7F (slot 21 of the type-7 command's
    # vtable 0xB87E30) the call of the HP setter 0x4820A1 with (0, 1) for a proto without flag 0Dh, and the
    # call of the kill queue 0x4B4DC2 with (1, 0, 0) for one with it; ESI = the unit at both
    ("DeleteSetHpCall", 0x7CD0CF, 5),
    ("DeleteKillCall", 0x7CD0DC, 5),
    # displayedRange: the ID of a model path, thiscall(table [0xC66240], path, 1, 0, 0), called at 0x5FC94C; the ID
    # of a bone name, thiscall(0xD6F478, name), called at 0x5FC8FC; both verify only
    ("ModelPathLookup", 0x58F68F, 10),
    ("BoneNameLookup", 0x58E506, 10),
    # auraStacking: the one call of the filter in the aura update, the filter's head, and mov ebx,eax /
    # cmp ebx,-1 after the apply
    ("AuraFilterCall", 0x9D0633, 5),
    ("AuraFilter", 0x9D0238, 6),
    ("AuraAppliedNext", 0x9D0675, 5),
    # xsErrorLog: sub esp,804h at the head of each XS reporter, and the formatter they call
    ("XsReportHead", 0x43A3A4, 6),
    ("XsMessageHead", 0xA5667F, 6),
    ("XsFormat", 0x435D99, 6),
    # linkedResource: mov eax,[0xC66234], the head of the inventory add; the 9 bytes at the head of the inventory
    # recreate, up to mov eax,[esi+0B4h]; mov edi,[esp+10h] / mov edx,[esi+10h] in the AutoGather pay, before the add
    # 0x4C3798; the ResList set
    ("InventoryAddHead", 0x49A5E6, 5),
    ("InventoryRecreateHead", 0x9BFE5A, 9),
    ("AutoGatherPayPoint", 0x4C378A, 7),
    ("ResListSet", 0x58EF83, 10),
    # dataLint: push 0EB4h at the <UnitType> handler's failure; test al,al / je / mov edx,[esp+14h] after the proto tag
    # table's find; je at the <ProtoAction> handler's failure; the call of the tech parser 0x61FD02; in that
    # parser, mov esi,eax / mov ecx,esi / mov edx,[ecx+18h] with the next <Tech>; je on setData's false in the effect parse;
    # push 512h, the effect type's failure
    ("LintUnitTypeMiss", 0x5FCB61, 5),
    ("LintProtoTagMiss", 0x5F62A2, 8),
    ("LintProtoActionMiss", 0x5FA202, 6),
    ("LintTechLoadCall", 0x61FE4A, 5),
    ("LintTechNode", 0x61FDB8, 7),
    ("LintEffectDrop", 0x6205E9, 6),
    ("LintEffectType", 0x65BC56, 5),
    # the kill queue's ask, thiscall(unit, a, b, c), ret 0Ch: it pushes [unit+10h] for 0x4B4D80; verify only
    ("KillQueueAsk", 0x4B4DC2, 8),
    # TakeDamage's subtraction through the add-HP entry 0x4823A3, verify only
    ("DetonationTakeDamageHp", 0x49B822, 5),
    # proto tags: the tail of the tag table's builder FUN_0051CE1D, pop edi / mov al,1 / pop esi / pop ecx
    # / ret; the hook needs the ret at 0x51DB14
    ("ProtoTagsTail", 0x51DB0F, 6),
    # veterancyBonus: mov ecx,[0xC66234], the head of TakeDamage's cold kill path; its only entry is the je
    # at 0x49B746
    ("VeterancyKillPath", 0x4D4F37, 6),
    # veterancyBonus: the seven calls of the transform in place FUN_009C754C, thiscall(unit, proto), ret 4
    ("TransformCall1", 0x7FBC79, 5),
    ("TransformCall2", 0x7FBEF2, 5),
    ("TransformCall3", 0x8C2D08, 5),
    ("TransformCall4", 0x8EB78A, 5),
    ("TransformCall5", 0x8F05F5, 5),
    ("TransformCall6", 0x9BB6D5, 5),
    ("TransformCall7", 0x9C7C16, 5),
    # trainBatchSize: the call of the limit per Train action, and the routine's read of the proto ID
    ("TrainBatchLimitCall", 0x9CE645, 5),
    # sharedBuildLimit: the entry of the build limit, sub esp,10h / mov edx,ecx (no branch lands inside);
    # the heads of the count it calls, thiscall(proto, player, bool, bool), and of the player's proto
    ("BuildLimitEntry", 0x4C7B5F, 5),
    ("BuildCountEntry", 0x4C7BC5, 8),
    ("BuildCountTooltip1", 0x4C8B81, 5),
    ("BuildCountTooltip2", 0x70F5EF, 5),
    ("PlayerProtoEntry", 0x45311B, 8),
    ("TrainBatchProtoArg", 0x9CE6DE, 4),
    # pillageGold: TakeDamage's call of 0x49BD52, on every hit with an attacking player, and the
    # instructions that load its arguments: EBX the player [esp+20h], and the frame it relies on
    ("PillageHitCall", 0x49B72B, 22),
    # doNotQueue: the queue routine's call of the action add 0x494894
    ("TrainQueueAddCall", 0x9CE81A, 5),
    # and the send of a card's call of the add to the shipment queue 0x857204
    ("ShipQueueAddCall", 0x85AD38, 5),
    # nextResearchFree: the payment 0x8D946A and the copy of the cost 0x480A73 into the action, in the
    # starts of the Research (EBP = the action) and CommandResearch (ESI = the action) actions
    ("ResearchPayCall", 0x9E67E1, 5),
    ("CommandResearchPayCall", 0x9D54CF, 5),
    ("ResearchCostCopyCall", 0x9E68A0, 5),
    ("CommandResearchCostCopyCall", 0x9D5548, 5),
    # trainBatchSize: the four calls of the queue routine FUN_009CE2BE, thiscall with 7 arguments, ret 1Ch:
    # arg 3 the proto ID, arg 4 the count
    ("TrainQueueCall1", 0x7560B5, 5),
    ("TrainQueueCall2", 0x7CAF6E, 5),
    ("TrainQueueCall3", 0x7D797A, 5),
    ("TrainQueueCall4", 0x9EBF03, 5),
    ("DataApplySwitch", 0x8F978D, 9),
    ("DataUnapplySwitch", 0x8FB051, 9),
    # tech subtypes on actions: setData's push "action"; and how protoUnitApply and Unapply turn the
    # allactions bit 40h of [effect+9] into applyData's 8th argument
    ("DataActionAttribute", 0x6216A3, 5),
    ("DataAllActionsApply", 0x7F86CA, 0x0E),
    ("DataAllActionsUnapply", 0x7F870F, 0x0E),
    # cratePriority: the only calls of the crate rank FUN_004DBF40 (thiscall(db, resource, civ), ret 8)
    # and of the next crate FUN_00501786 (thiscall(player, proto, int* next, int* resource), ret 0Ch),
    # and that one's read of the civ: mov ecx,[esi+4] / mov ecx,[ecx+44h]
    ("CrateRankCall", 0x49A03C, 5),
    ("CrateNextCall", 0x50170B, 5),
    ("CrateNextCivRead", 0x50184A, 6),
    # buildingWorkRateAuras: the Train update's mov ecx,[esi+10h] / call 9BFE33h. Checked alone, not
    # in the VerifyAll: noTrainNearEnemyTC hooks these bytes and calls g_uhcBwrTrainGetter, and the
    # call is redirected only while they are stock
    ("BwrTrainCall", 0x9EA410, 8),
    # buildingWorkRateAuras: after that call, mov ebx,[0C66234h] / mov eax,[ebx+13Ch], up to the first
    # write of EAX (the wrapper returns another EAX)
    ("BwrTrainCallNext", 0x9EA418, 0x0C),
    # buildingWorkRateAuras: the getter after its first two instructions (liveBuildingWorkRate may
    # replace those), je 9BFE3Eh / fld [eax+28h] / ret / mov eax,[ecx+5Ch] / fld [eax+0D0h] / ret:
    # the wrapper calls it as a float thiscall(unit) that changes only EAX and the flags
    ("BwrGetterTail", 0x9BFE38, 0x10),
    # buildingWorkRateAuras, the GatherRate reader whose rule the factor mirrors: FUN_004ECD87's
    # mov eax,[ecx+0B4h] / mov ecx,[eax+0C8h] (the modifier record) / test / jne 69FE53h, and that
    # chunk's fld [ecx+24h] / fcomp [0B9FB64h] (1e-6) / fnstsw / test ah,5 / jnp (1.0) / fld [ecx+24h]
    ("BwrGatherRateRecord", 0x4ECFE9, 0x14),
    ("BwrGatherRateRule", 0x69FE53, 0x1C),
    # civFirstTC (FUN_0052A590, the civs.xml parser, ESI = the child node, EBX = database,
    # [esp+10h] = the civ): the last tag compare of the <civ> child loop, call 443C10h /
    # test eax,eax / je 65A549h, then the unknown-tag path, xor edi,edi / cmp [ebx+80h],edi
    # (replaced, 8 bytes at 0x52BB07) and the jle 52B43Dh / jmp 52C066h the hook resumes at
    ("CivTagUnknown", 0x52BAFA, 0x20),
    # civFirstTC: the next-child step every handled tag jumps to, mov eax,[esp+80h] /
    # mov ebp,[esp+0B0h] / add eax,1 / cmp eax,[ebp+0Ch]
    ("CivTagNextNode", 0x52B43D, 0x14),
    # civFirstTC: the civ by ID 0x405C2E, thiscall(database, id) = [[db+24h]+4*id] (count
    # [db+28h]), ret 4; a civ's ID is [civ+8] and its name [civ+4] (char*)
    ("CivById", 0x405C2E, 0x18),
    # civFirstTC: a player's civ ID 0x4539D3, [[player+20h]] when [player+24h] > 0, else -1
    ("CivOfPlayer", 0x4539D3, 0x10),
    # civFirstTC: proto by name 0x5A2346, thiscall(database, const char*), ret 4: a
    # case-insensitive scan of [db+54h] (count [db+58h]) by [proto+10h], -1 if none
    ("ProtoByName", 0x5A2346, 0x20),
    # civFirstTC: proto by ID 0x45316E, thiscall(database, id) = [[db+54h]+4*id], ret 4
    ("ProtoById", 0x45316E, 0x1E),
    # civFirstTC (FUN_00925F11, the step every rmPlaceObjectDef* reaches): mov eax,[edi] /
    # push ecx / mov ecx,[eax+esi*4] (the object def) / push edx / call 925936h / mov ebx,eax;
    # the call at 0x925F4C is redirected
    ("RmPlaceCall", 0x925F45, 0x0E),
    # civFirstTC: objectDef::place FUN_00925936, thiscall(def, player, x, z, count), ret 10h, up to
    # its Special_StartingUnits test cmp byte [esi+55h],0 at 0x925988 (those defs rebuild their
    # items from the civ's <startingunit> inside place); the RM is [game+92Ch]
    ("RmPlace", 0x925936, 0x6F),
    # civFirstTC: objectDef::addItem's footprint, proto flag 2 (0x45EE02), then
    # (int)([proto+88h] * [[world+88h]+1Ch] * 2 + 0.5) and the same with [proto+8Ch], stored at
    # item +0Ch / +10h (items: [def+8], count [def+0Ch], 20 bytes, +0 the proto ID)
    ("RmItemFootprint", 0x924B1D, 0x9E),
    # civFirstTC: rmGetNomadStart, byte [[[0C66234h]+92Ch]+1A95h] (0 without an RM)
    ("RmNomadStart", 0x90B683, 0x19),
    # civFirstTC (FUN_0049039A, the town starting units, EDI = player): mov ecx,[eax+140h] /
    # push ebx / mov ebx,[ecx+5E08h] (TownCenter, replaced, 6 bytes at 0x679AC8) / push ebp /
    # push esi / mov esi,[edi+80h]; the query after it takes the first built unit of proto EBX
    ("TownStartQuery", 0x679AC1, 0x15),
    # civFirstTC: the spawn, FUN_007C238E([player+3E0h], unit ID), then [player+349h] &= 0BFh,
    # which clears the pending bit whether or not anything spawned
    ("TownStartSpawn", 0x679B50, 0x1A),
    # civFirstTC: FUN_007C238E spawns only if bit 0 of [colonies] is clear and a colony has
    # [colony+28h] == the unit (count [edi+18h], indices [edi+14h], colonies [edi+8]); the
    # helper repeats this test
    ("TownStartColonyLoop", 0x7C2407, 0x31),
    # decimalPopulation: the int parse 0x59A71D(text, int* out) of <PopulationCount> (FUN_005FB8FA,
    # then [proto+0D8h]) and <PopulationCapAddition> (FUN_005FD6E5, then [proto+0D4h]), up to the
    # store; the two calls are redirected
    ("PopCountParse", 0x5FB92E, 0x1E),
    ("PopCapAddParse", 0x5FD719, 0x1E),
    # decimalPopulation: the proto effects PopulationCount (case 0x8FA814) and
    # PopulationCapAddition (case 0x8FA8AB) of the effect switch 0x8F978D call the int effect
    # FUN_007F899B(rel, int* out, base, float amount, negate), cdecl; both calls are redirected,
    # and PopulationCount's "result <= 0 -> 1" (mov eax,1 at 0x8FA849) becomes K
    ("PopCountEffect", 0x8FA835, 0x1D),
    ("PopCapAddEffect", 0x8FA8CF, 0x1A),
    ("IntEffect", 0x7F899B, 0x23),
    # decimalPopulation: the player effect PopulationCap (FUN_008D842B case 14h, and its removal
    # at 0x8D20AB): fld [esp+X] (the amount) / fnstcw [esp+X], then a truncating fistp; the
    # amount is scaled in between
    ("PopCapEffectAdd", 0x8D87AB, 0x08),
    ("PopCapEffectRemove", 0x8D20AB, 0x08),
    # decimalPopulation: getCap's shared-team path (GameTeamSharePop): per ally
    # min(raw, 200, [world+31Ch]), from cmp eax,0C8h to add ebx,eax
    ("TeamPopCap", 0x679694, 0x26),
    # decimalPopulation: game start: setCap(getCap() + [player+7Ch] + [world+320h]), from
    # add eax,ebx / add eax,[esi+320h] to push eax
    ("StartPopBonus", 0xA0D2D1, 0x09),
    # decimalPopulation: XS registrations, push impl / push name (the impl is replaced)
    ("XsAiGetAvailableEconomyPop", 0x72A333, 0x0A),
    ("XsAiGetAvailableMilitaryPop", 0x72A49B, 0x0A),
    ("XsAiGetCurrentEconomyPop", 0x72A382, 0x0A),
    ("XsAiGetEconomyPop", 0x72A3D1, 0x0A),
    ("XsAiGetMilitaryPop", 0x72A4EA, 0x0A),
    ("XsAiGetPopNeeds", 0x7319AA, 0x0A),
    ("XsAiSetEconomyPop", 0x72A420, 0x0A),
    ("XsAiSetMilitaryPop", 0x72A539, 0x0A),
    ("XsKbGetPop", 0x885EE5, 0x0A),
    ("XsKbGetPopCap", 0x885F34, 0x0A),
    ("XsKbGetPopCapAddition", 0x887BB1, 0x0A),
    ("XsKbGetPopSlots", 0x887C58, 0x0A),
    ("XsKbGetPopulationSlotsByQueryID", 0x887DA6, 0x0A),
    ("XsKbGetPopulationSlotsByUnitTypeID", 0x887CFF, 0x0A),
    ("XsKbUnitPickGetMaximumPop", 0x88F88A, 0x0A),
    ("XsKbUnitPickGetMinimumPop", 0x88F768, 0x0A),
    ("XsKbUnitPickSetMaximumPop", 0x88F7E3, 0x0A),
    ("XsKbUnitPickSetMinimumPop", 0x88F6C1, 0x0A),
    ("XsTrPlayerGetPopulation", 0x98C439, 0x0A),
    # decimalPopulation: the formatText data refs pop (22h), popcap (23h), futurepop (24h) and
    # totalpop (25h) (FUN_005CFA7C), entries {id, type, name, provider}: mov [esp+2Ch],provider /
    # call 5ACE63h / test / je / mov edx,[esp+18h] (the id) / ... / mov [edi],edx /
    # mov eax,[esp+1Ch] (the type: EBX = 2, int, here; 3 is text) / push ecx / lea ecx,[edi+8] /
    # mov [edi+4],eax
    ("RefPopReg", 0x5D0B47, 0x2B),
    ("RefPopCapReg", 0x5D0BC3, 0x2B),
    ("RefFuturePopReg", 0x5D0C3F, 0x2B),
    ("RefTotalPopReg", 0x5D0CBB, 0x2B),
    # decimalPopulation: their stock int providers, bool stdcall(Value*) (they write [value+4])
    ("RefPopProvider", 0x6F2274, 0x0A),
    ("RefPopCapProvider", 0x458244, 0x0A),
    ("RefFuturePopProvider", 0x44CE3A, 0x0A),
    ("RefTotalPopProvider", 0x45809D, 0x0A),
    # decimalPopulation: colorizePop (6Ch, 0x6F5736): the argument parse call 6F2A1Dh
    # (atoi of the text in parentheses, -1 on failure), then getPop + [player+78h] + N > getCap
    # (red), then the "%s%d%s" format call
    ("ColorizePopArg", 0x6F576F, 0x08),
    ("ColorizePopFormat", 0x6F580C, 0x0C),
    # decimalPopulation: BString sprintf 0x444EFB(dest, fmt, ...), cdecl, and the calls that print
    # a population: unit help "Population: %d" (0x63F98D, 0x70FF3A, str 11725), the pop costs
    # "{colorizePop(%d)}" (0x63FEC5, 0x70F58F, str 20395; 0x710651, str 37461 / 20395), the pop
    # counter's help "%d %s = %d" (0x6F2DB5) and str 18963 with getCap (0x6F2E34)
    ("BStringFormat", 0x444EFB, 0x14),
    ("PopFormatHelp", 0x63F98D, 0x08),
    ("PopFormatHelp2", 0x70FF3A, 0x08),
    ("PopFormatCost", 0x63FEC5, 0x08),
    ("PopFormatCost2", 0x70F58F, 0x08),
    ("PopFormatCost3", 0x710651, 0x08),
    ("PopFormatCapLine", 0x6F2DB5, 0x08),
    ("PopFormatCap", 0x6F2E34, 0x08),
    # kbUnitSyscalls: engine functions the added kb syscalls call (thiscall, verified heads).
    # ResList get 0x44EFFF(list, r) -> float; unit isSeeable 0x48A9EF(unit, player) -> bool (the
    # visibility bit [[unit+B4h]+ACh] & 1<<player, else the explored bit [+B0h] and the proto's
    # under-fog flags, 0x55F5B2); unit getSquad 0x4E2A03(unit) -> [[world+148h]][[unit+B4h]+14h];
    # inventory isFull 0x4DC520(inventory) -> bool; unit getCarryCapacity 0x494503(unit, r) ->
    # float, through [unit+5Ch] (the proto)
    ("ResListGet", 0x44EFFF, 0x3D),
    ("UnitIsSeeable", 0x48A9EF, 0x3B),
    ("UnitGetSquad", 0x4E2A03, 0x32),
    ("InventoryIsFull", 0x4DC520, 0x3D),
    ("UnitCarryCapacity", 0x494503, 0x10),
    # customProtoUnitCommands: FUN_0052277E registers the command type names 0..128 in the
    # database's name table ([db+2648h], count [db+264Ch]) with 0x537683(db, id, name), thiscall,
    # ret 8, which accepts only id == count; the last call (RansomExplorerAsian, 80h) is at
    # 0x5269FB. 0x5274AB(db, name), thiscall, ret 4: the name's ID, -1 if absent.
    ("CmdTypeRegLast", 0x5269FB, 0x05),
    ("CmdTypeRegister", 0x537683, 0x37),
    ("CmdTypeLookup", 0x5274AB, 0x34),
    # customProtoUnitCommands: the protounitcommands.xml loader (FUN_00527090) sizes the record
    # array [db+2968h] (4Ch-byte records indexed by command type ID, readers bound by its count
    # [+4]) with push 82h / mov ecx,ebx / call 5276EAh: 130 records for the 129 stock types
    ("CmdRecordReserve", 0x52711D, 0x05),
    # multiarmor: a proto keeps one armor, type byte [proto+1D3h] and value [proto+C4h].
    # The <Armor> tag handler 0x5F5E62 (cdecl(ctx, node, proto); the type name through
    # 0x5F562D on ctx) stores them at its end: mov [ecx+1D3h],al / mov [ecx+0C4h],edx
    ("ArmorStore", 0x5F5EB7, 0x0C),
    # multiarmor: the armor getter 0x49B323 (thiscall(unit, byte damageType, ...), ret 8), EAX =
    # proto, BL = the damage type: cmp [eax+1D3h],bl / mov [esp+8],0 / jne / mov eax,[eax+0C4h]
    # (22 B), then mov [esp+8],eax at 0x49B345
    ("ArmorGetter", 0x49B32F, 0x16),
    # multiarmor: BProtoUnit destructor 0x58633D (push esi / mov esi,ecx / mov [esi],0B9F404h) and
    # the proto copy 0x67E011 (thiscall(dst, src, bool), ret 8: sub esp,0Ch / push ebp /
    # mov ebp,[esp+14h]), which clones a proto for a player
    ("ProtoDtorHead", 0x58633D, 0x09),
    ("ProtoCopyHead", 0x67E011, 0x08),
    # multiarmor: BDataEffect's vtable slots setData (0x6205F6), protoUnitApply (0x7F86C0) and
    # protoUnitUnapply (0x7F8705); the data subtype Armor is 5Ch, applied through 0x7F892A
    # (cdecl(byte relativity, float* target, float base, float amount, bool unapply)) on the
    # effect's amount [+18h] and relativity [+1Ch]
    ("DataEffectSetDataSlot", 0xB9E5AC, 0x04),
    ("DataEffectApplySlot", 0xB9E5CC, 0x04),
    ("DataEffectUnapplySlot", 0xB9E5D0, 0x04),
    # multiarmor: BDataEffect playerApply (0x7F874A, through 0x8D842B to every target proto's
    # applyData) and playerUnapply (0x7F877F) slots, and the Armor (5Ch) cases of applyData
    # 0x8F973F (EDI = target proto, ESI = its base proto, [esp+28h] amount, [esp+2Ch] relativity,
    # EBP = 0: mov edx,[esp+28h] / mov eax,[esi+0C4h]) and of unapplyData 0x8FB01C (ESI = target,
    # EDI = base, [esp+24h] amount, [esp+28h] relativity: mov eax,[esp+24h] / mov ecx,[edi+0C4h])
    ("DataEffectPlayerApplySlot", 0xB9E5C4, 0x04),
    ("DataEffectPlayerUnapplySlot", 0xB9E5C8, 0x04),
    ("DataApplyArmorCase", 0x8FAE52, 0x0A),
    ("DataUnapplyArmorCase", 0x8FC144, 0x0A),
    ("EffectValueApply", 0x7F892A, 0x10),
    # workRateByAbstractType: the head of the WorkRate case (Data subtype 3) of applyData, mov edi,[edi+44h]
    # / cmp edi,ebp, and the je it continues at; the same in unapplyData with ESI. No branch lands inside.
    ("WorkRateApplyCase", 0x8F987C, 11),
    ("WorkRateUnapplyCase", 0x8FB11A, 11),
    # workRateByAbstractType, verify only: action by ID in a proto's action set, the rate list's getter
    # (0.0 for no entry) and setter
    ("ActionById", 0x48D22E, 0x10),
    ("ActionRateGet", 0x49EBB3, 0x10),
    ("ActionRateSet", 0x5FA2FC, 0x10),
    # autoGatherScaleByContained: the entry of the AutoGather rate getter, push ecx / push ebx /
    # mov ebx,[esp+0Ch], and the test ebx,ebx it continues at. No branch lands inside.
    ("AutoGatherRateEntry", 0x49EBE4, 8),
    # unitResourceAuras: the aura update's mov eax,[0C66234h] and the sub esp,10h it continues at
    ("UnitResourceAuraEntry", 0x9D033E, 8),
    # unitResourceAuras, verify only: the aura's scan (thiscall(action, IdList*)), inventory add
    # (thiscall(inventory, resource, float)), unit state check, main resource of a unit, dead test,
    # add resource to a player
    ("AuraScan", 0x9CFF9A, 0x10),
    # unitResourceAuras: the stock update's reading of <ModelAttachment> ([protoAction+A4h], the bone at
    # +A8h) and the functions it calls: model by ID, has it (thiscall(unit, model), ret 4), hang it
    # (thiscall(unit, object, bone, byte), ret 0Ch), take it off (thiscall(unit, model), ret 4)
    ("AuraModelBlock", 0x9D053F, 9),
    # resourceGatherAuras: the update's two decisions on the ring: has it, for a unit that stays in range,
    # and hang it, for a new one
    ("AuraHasModelCall", 0x9D0584, 5),
    ("AuraHangModelCall", 0x9D06DC, 5),
    ("ModelById", 0x405E83, 6),
    ("UnitHasModel", 0x9C28DE, 8),
    ("UnitAttachModel", 0x9C04F3, 8),
    ("UnitRemoveModel", 0x9C2885, 8),
    ("InventoryAdd", 0x49A5E6, 0x10),
    ("CheckState", 0x482152, 0x10),
    ("MainResource", 0x4DBEC1, 0x10),
    ("UnitIsDead", 0x4802C6, 0x10),
    ("PlayerAddResource", 0x49A98A, 0x10),
    # resourceGatherAuras: call 4ECD39h in the gather tick. showGatherRate verifies the same bytes, so
    # that key must be applied first.
    ("GatherDanceCall", 0x4ED02A, 5),
    # resourceDebt: the clamps of the add 0x49A98A and the set 0x49A8C5 in their cold parts, and the
    # jmp back each continues at
    ("DebtAddClamp", 0x679A0E, 13),
    ("DebtSetClamp", 0x6798F4, 13),
    # resourceDebt: the third clamp, in the add's shared-resources path, and the mov it continues at. A
    # jp at 0x6799D2 jumps over it to that continuation.
    ("DebtShareClamp", 0x6799D4, 12),
    # resourceDebt: the three gates that stop negative rates before the add: jp 4C0F1Fh in the AutoGather
    # update, jp 4C0A34h at the end of its rate getter, jnp 6A8AEAh in the gather tick. No branch lands
    # inside; each holds its own target, so its bytes prove the continuation.
    ("DebtAutoGate", 0x48D186, 6),
    ("DebtAutoRate", 0x49EE07, 6),
    ("DebtGatherGate", 0x4ED03E, 6),
    # multiarmor: XML attribute 0x598F37 (thiscall(node, name, void** out), ret 8), its text
    # 0x402733 (thiscall(out) -> const char*), and the damage type list lookup 0x5F55EA
    # (thiscall(ctx, name) -> entry, its ID at +8; ctx [+44h] array, [+48h] count)
    ("XmlAttribute", 0x598F37, 0x10),
    ("XmlText", 0x402733, 0x09),
    ("DamageTypeLookup", 0x5F55EA, 0x10),
    # betterfreedynamicunit: a FreeHomeCityUnit amount below -1e-6 ([0B9FB60h]) is a "dynamic"
    # count: -amount * min([world+134h], 15) (an integer). Two copies, after the jp that skips
    # them for other amounts: 0x7FA6ED (four nops, then the computation into [esp+24h], up to
    # 0x7FA72A) and 0x8D8C88 (into [esp+38h], up to 0x8D8CBD)
    ("FreeDynamicUnit1", 0x7FA6ED, 0x3D),
    ("FreeDynamicUnit2", 0x8D8C88, 0x35),
    # nowalkfarm: in the gather action, once the game time passes [action+A0h], mov ecx,esi /
    # call 9DDADEh picks the gatherer a new spot around the farm (the function farmingRadius
    # hooks); the other four callers (0x4ED5E8, 0x4ED6F4, 0x50DF53, 0x6A8E7C) place it first
    ("FarmWalkCall", 0x6A9067, 0x05),
    # repairWallGlobal: BGame::commandAutoRepair 0x830AC4 (thiscall(game, int player, int unitId),
    # ret 8; player < 0 means [game+3C0h], the local player), the call the one-wall repair at
    # 0x7DEDC3 makes
    ("CommandAutoRepair", 0x830AC4, 0x12),
    # compatMode: FUN_0054D663 adds each adapter display mode (16 B, its D3D format at +0Ch) to the
    # renderer's list with push eax / mov ecx,ebp / call 54D605h (thiscall(renderer, mode), ret 4)
    ("DisplayModeAddCall", 0x54D6D1, 0x05),
    ("DisplayModeAdd", 0x54D605, 0x12),
    # gatherFix: BUnitGatherAction's update ends with [action+88h] += [world+104h] (the elapsed time)
    # then pop ebx / pop edi / ... ret (0x4EC8DE, 32 B up to pop esi at 0x4EC8FE); and
    # doAnimationLooped 0x4ECC88 collects on each animation loop: cmp byte [esi+61h],5 / jne ... up
    # to 0x4ECCE7 (89 B), collectStuff 0x9DD7B4 or collectStuff_2 0x4ECD87 (thiscall(action, float))
    ("GatherTimeAdd", 0x4EC8DE, 0x20),
    ("GatherAnimLoopCollect", 0x4ECC8E, 0x59),
    ("GatherCollect", 0x9DD7B4, 0x10),
    ("GatherCollect2", 0x4ECD87, 0x10),
    # rofFix: FUN_009CEB5C (an ability/command order on a unit) clears the unit AI's [+B8h] with
    # mov dword [edi+0B8h],0 before issuing the order
    ("RofTimerReset", 0x9CECB4, 0x0A),
    # stunMovingTargetFix: BUnitStunAction's update, state 8: call [eax+0CCh] (the target check) /
    # test al,al / jne 9E90F9h; on a failed check it ends the action (setState 0Ah)
    ("StunTargetCheck", 0x9E909E, 0x02),
    # noDamageOnUnbuiltFoundations: in the damage function FUN_0049B3D9 (thiscall(unit, int
    # attackerPlayer, ...), ret 34h; ESI = unit, ECX = its proto, the attacker at [esp+94h]), the
    # proto flag 9Ch (Invulnerable) test: cmp [ecx+54h],9Ch / jbe 49B40Fh / ... / ja 4CA52Bh
    # (no damage) (22 B)
    ("DamageInvulnerableTest", 0x49B3F3, 0x16),
    # fallenHeroTacticsFix: four places reset the unit AI's tactic ([ai+A8h]) to 0 through
    # 0x4F7389 (thiscall(ai, int tactic), ret 4) when it is not 0 already: push ebx|0 / call 4F7389h
    ("TacticReset1", 0x6AAE6D, 0x06),
    ("TacticReset2", 0x7D8F07, 0x07),
    ("TacticReset3", 0x9D6BE7, 0x07),
    ("TacticReset4", 0x9EBB0B, 0x07),
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
