"""Build the release zip that modders download: dist/UHC-<version>.zip.

Usage: python -I tools/package_release.py [--force] [--dxvk <folder>] [--dinput8-only]

--dinput8-only writes dist/dinput8-<version>.zip instead: dinput8.dll at the top with
engine-ext/engine-ext.cfg, the same art, DXVK and LICENSE, and its own README.txt; no UHC.dll,
no Startup folder and no check of build/Release/UHC.dll.

Run it from the repository root after a Release build (docs/developer-guide.md, "Making a
release"). It checks build/Release/UHC.dll first and stops if:
  - the DLL is not a 32-bit x86 PE, or does not export _UHCMain@0;
  - the DLL is not the version in CMakeLists.txt (it must contain the UTF-16 "UHC.dll <ver>");
  - a file under src/, or CMakeLists.txt, is newer than the DLL (rebuild first).

The zip holds one folder, UHC-<version>/, with:
  UHC.dll
  Startup/uhc.cfg    examples/Startup/uhc.cfg with every key commented out (stock behavior)
  beside-another-dll/dinput8.dll              the same code, for a game that keeps another UHC.dll
  beside-another-dll/engine-ext/engine-ext.cfg  the same template, for that DLL
  art/effects/uhc_rings/  the aura rings of tools/rings, for a game's art folder
  art/ui/uhc/health_overheal.ddt  the orange end of the portrait HP bar (tools/bars, overhealHitpointBars)
  art/ui/uhc/pie/pie_00.ddt ... pie_31.ddt  the small progress pie after a panel row (tools/pie, nurseryFactor)
  dxvk/d3d9.dll, dxvk/LICENSE.txt   DXVK 3.1.1 (32-bit) and its zlib license, for rendererOption
  LICENSE.txt
  README.txt         the quick start for modders
The game exe is not included: each modder patches their own copy with the loader's patcher.
DXVK is not in git: its d3d9.dll (x32 of the 3.1.1 release, SHA-256 checked) and its LICENSE come from
rea/vendor/dxvk-3.1.1/ (gitignored), or the folder given with --dxvk; the script stops if either is missing.
An existing zip is kept unless --force is given. The SHA-256 of the zip and the DLL are printed.
"""
import hashlib
import pathlib
import re
import struct
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
REPO_URL = "https://github.com/Gorgorito12/things-new"
DXVK_VERSION = "3.1.1"
DXVK_D3D9_SHA256 = "265888c31ca78dffa290c39cb7e50bfb02762590e41927906e46fb32f01497fa"


def fail(message):
    sys.exit(f"package_release: {message}")


def read_version():
    text = (ROOT / "CMakeLists.txt").read_text(encoding="utf-8")
    m = re.search(r"project\(UHC VERSION (\d+\.\d+\.\d+)", text)
    if not m:
        fail("no 'project(UHC VERSION x.y.z' in CMakeLists.txt")
    return m.group(1)


def pe_exports(data):
    """Names exported by a PE32 image, after checking it is 32-bit x86."""
    if data[:2] != b"MZ":
        fail("UHC.dll is not a PE file")
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        fail("UHC.dll is not a PE file")
    machine, sections, _, _, _, opt_size, _ = struct.unpack_from("<HHIIIHH", data, pe + 4)
    opt = pe + 24
    if machine != 0x14C or struct.unpack_from("<H", data, opt)[0] != 0x10B:
        fail("UHC.dll is not a 32-bit x86 DLL (configure CMake with -A Win32)")
    export_rva, _ = struct.unpack_from("<II", data, opt + 96)
    table = [struct.unpack_from("<8sIIII", data, opt + opt_size + 40 * i) for i in range(sections)]

    def offset(rva):
        for _, vsize, va, rawsize, raw in table:
            if va <= rva < va + max(vsize, rawsize):
                return raw + rva - va
        fail(f"RVA {rva:#x} is outside every section")

    if not export_rva:
        return []
    e = offset(export_rva)
    count, names_rva = struct.unpack_from("<I", data, e + 24)[0], struct.unpack_from("<I", data, e + 32)[0]
    names = []
    for i in range(count):
        o = offset(struct.unpack_from("<I", data, offset(names_rva) + 4 * i)[0])
        names.append(data[o:data.index(b"\0", o)].decode("ascii"))
    return names


def check_fresh(dll, wanted):
    sources = [ROOT / "CMakeLists.txt"] + [p for p in (ROOT / "src").rglob("*") if p.is_file() and wanted(p)]
    newer = [p for p in sources if p.stat().st_mtime > dll.stat().st_mtime]
    if newer:
        fail(f"{newer[0].relative_to(ROOT)} is newer than {dll.name}; rebuild first")


def check_dll(dll, version):
    if not dll.exists():
        fail(f"{dll} not found; build first: cmake --build build --config Release")
    data = dll.read_bytes()
    if "_UHCMain@0" not in pe_exports(data):
        fail("UHC.dll does not export _UHCMain@0")
    if f"UHC.dll {version}".encode("utf-16-le") not in data:
        fail(f"UHC.dll is not version {version}; rebuild after changing CMakeLists.txt")
    check_fresh(dll, lambda p: not p.name.startswith("engineext"))  # those are only in dinput8.dll
    return data


def check_proxy(dll, version):
    """dinput8.dll: the same checks, and the system DLL's main export."""
    if not dll.exists():
        fail(f"{dll} not found; build first: cmake --build build --config Release")
    data = dll.read_bytes()
    if "DirectInput8Create" not in pe_exports(data):
        fail("dinput8.dll does not export DirectInput8Create")
    if f"dinput8.dll {version}".encode("utf-16-le") not in data:
        fail(f"dinput8.dll is not version {version}; rebuild after changing CMakeLists.txt")
    check_fresh(dll, lambda p: True)
    return data


def read_dxvk(folder):
    """DXVK's 32-bit d3d9.dll and its license, checked against the release this DLL was tested with."""
    dll, license_file = folder / "d3d9.dll", folder / "LICENSE"
    if not dll.exists() or not license_file.exists():
        fail(f"{folder} must hold DXVK {DXVK_VERSION}'s x32 d3d9.dll and its LICENSE (from the "
             f"v{DXVK_VERSION} release and tag of github.com/doitsujin/dxvk); see docs/developer-guide.md, "
             f"section 7")
    data = dll.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != DXVK_D3D9_SHA256:
        fail(f"{dll} has SHA-256 {digest}, not DXVK {DXVK_VERSION}'s x32 d3d9.dll ({DXVK_D3D9_SHA256})")
    text = license_file.read_text(encoding="utf-8")
    if "zlib" not in text:
        fail(f"{license_file} is not DXVK's zlib license")
    return data, text.replace("\r\n", "\n").replace("\n", "\r\n")


def template_cfg(version, title=None):
    """The example cfg with every key line commented out."""
    lines = [
        title or f"# Startup\\uhc.cfg template for UHC.dll {version}.",
        "# Every key is commented out, so the game behaves as stock until you enable one: remove",
        "# the \"#\" in front of a key line. Keep the other comment lines as they are.",
        "#",
    ]
    active = 0
    for line in (ROOT / "examples" / "Startup" / "uhc.cfg").read_text(encoding="utf-8").splitlines():
        words = line.split()
        if words and not words[0].startswith("#"):
            lines.append("# " + line)
            active += 1
        else:
            lines.append(line)
    if not active:
        fail("examples/Startup/uhc.cfg has no keys")
    return "\r\n".join(lines) + "\r\n"


def readme(version):
    text = f"""UHC.dll {version} for Age of Empires III: The Asian Dynasties (Steam)
=====================================================================

UHC.dll removes hard-coded limits of the game and adds new engine features. A mod turns each
feature on in Startup\\uhc.cfg. It needs the Steam version of TAD and the loader.

Full guide:  {REPO_URL}/blob/main/docs/modding-guide.md
Downloads:   {REPO_URL}/releases

Adding it to your mod
---------------------
1. Make your mod folder a complete game folder: a copy of the game's bin folder plus your
   mod's files. Never modify the Steam install.
2. Patch that folder's age3y.exe once with UHCPatcher.exe.
   Keep the patcher outside the game folders and drag the exe onto it. The exe must be the
   unmodified Steam exe (SHA-256 b1a1dab7...11d9d). In the dialog, leave the checkboxes as
   they are (they only choose keys for the uhc.cfg you replace next), keep the default config
   path Startup\\uhc.cfg, and click Apply. The patcher also writes its own UHC.dll and a
   new Startup\\uhc.cfg next to the exe.
3. From this package's UHC-{version} folder, copy UHC.dll next to the exe and the Startup
   folder into the mod folder, replacing the patcher's files. If you run the patcher again
   later, keep a copy of your own uhc.cfg first, then copy UHC.dll and your uhc.cfg back.
4. In Startup\\uhc.cfg, remove the "#" in front of ignoreRegistryPath (always needed in a mod
   folder) and of the keys you want. Some keys need data or art from your mod: see the guide.
5. Start the mod's age3y.exe. UHC.log appears next to it: its first line is "UHC.dll {version}",
   and every key you enabled says "applied".
6. Ship your files, the patched age3y.exe, UHC.dll and Startup\\uhc.cfg (not UHC.log or
   age3y.backupuhc). Do not ship a copy of the game: your installer builds the complete folder
   from each player's own game install. Players can then start it however they like, because
   UHC.dll makes the exe's folder the working directory. They install nothing else.

A game that must keep another UHC.dll
-------------------------------------
If your game's loader runs a UHC.dll you do not want to replace, use the beside-another-dll
folder instead. Nothing of that game changes: not its exe, its UHC.dll, its cfg or data\\uhc.
1. Copy what is in beside-another-dll (dinput8.dll and the engine-ext folder) next to the exe.
2. In engine-ext\\engine-ext.cfg, remove the "#" in front of the keys you want. Data files
   that keys read by default go in engine-ext\\ too.
3. Start the game. engine-ext\\engine-ext.log says "applied" or "FAILED" for each key. A key
   fails, and changes nothing, when the other DLL already patched a place it needs.
To remove it, delete dinput8.dll and the engine-ext folder.
If the game already has a dinput8.dll that loads another DLL (a mod's proxy), keep that file
aside and put "preloadDll <its DLL>" in engine-ext\\engine-ext.cfg: this dinput8.dll then loads
it at the same moment, before the game starts.

Aura rings
----------
art\\effects\\uhc_rings holds coloured rings that show which units an aura is working on. They
are data: copy that folder to the game's art\\effects and name one in an aura, with
<modelattachment>effects\\uhc_rings\\ring_gold.xml</modelattachment> and
<modelattachmentbone>bonethatdoesntexist</modelattachmentbone>. Every player needs the folder.
aura_<name>.xml adds a floating icon, for gathering auras (gold, wood, food, hunt, berry, farm, fish,
export, xp, oil, work). The colours: wood, food, gold, work (work rate), export, xp, oil, damage, rof
(rate of fire), hp (max hit points), heal and speed. displayedRange shows range_<metres>.xml, a line in
the owner's colour, with rangefill_<metres>_p<player>.xml, a soft fill in that colour, or range_<metres>_ships.xml,
a dashed line for an attack that reaches only ships or buildings. These rings are the defaults: an aura with a model of its own keeps it.
veterancyBonus shows rank_1.xml to rank_5.xml over a unit with a rank when the folder is there.
art\\ui\\uhc\\health_overheal.ddt is the orange end of the HP bar under the portrait, which
overhealHitpointBars segment shows for units above their 100 %: copy it to the game's art\\ui\\uhc
(every player who wants it). Without it that end uses the game's yellow bar texture.
art\\ui\\uhc\\pie holds the 32 frames of the small progress pie nurseryFactor puts after its
"3/10 minks" row while a nursery grows: copy the folder to the game's art\\ui\\uhc (every player).
Without it the pie is drawn over the unit's portrait instead.

A uhc.cfg written by the patcher is read as it is (basePop=500 and // comments are
accepted). Keys that this DLL does not implement are logged in UHC.log and ignored.
Keys that need data edits use Python tools from the source code (Code > Download ZIP).

Keys
----
ignoreRegistryPath            read the game data from the mod folder
deckCardCount N               decks of more than 25 cards
basePop N, extraPop N         higher population limits (no 250 cap)
decimalPopulation [K] [log]   population with decimals (PopulationCount 0.5), steps of 1/K
noAILimit                     every AI3\\*.personality file in game setup
noAILimitV2                   the same list, hooked later (cfgs that use this name)
customAbstractTypes [file]    abstract unit types from an XML file
                              (default data\\uhc\\customabstracttypes.xml)
customProtoUnitCommands [file]   command types (buttons) from an XML file
multiarmor                    one armor per damage type; Armor effects follow damagetype
betterfreedynamicunit         dynamic free units grow smoothly with game time
gatherFix                     gather on a fixed interval (the data's rate)
rofFix, stunMovingTargetFix   orders keep the attack timer; stuns survive a moving target
noDamageOnUnbuiltFoundations  unbuilt foundations take no damage
truckAttackResourceFix [log] a TruckAttack no longer empties the buildings it hits
deadReplacementAtZeroInventory [log] a hunt or herdable leaves its DeadReplacement when its body is used up
fallenHeroTacticsFix          knocked-out or stunned units keep their tactic
impactBoneFix [all] [log]     impact effects hung on scaled bones keep their size
customImpactTypes <names> [log]   impact types after the 15 stock ones (.dmg, ImpactType)
nowalkfarm                    farm gatherers keep their first spot
repairWallGlobal              UI syscall repairWallGlobal(): repair all walls
compatMode                    32-bit display modes also offered at 16 bits
modelCacheLimit [MB] [log]    the model cache unloads no model in use (0: never; stock 30 MB)
dmgPartBoneFix [log]          a damage part's unknown bone no longer reloads the model in use
customSyscalls [files]        load .upl plugins and their XS syscalls
customCheats                  the cheats plugins register work in the chat
asianCivs Civ ... [log]       these civs count as Asian civs (consulate, wonders)
selectionLimit N              a selection holds up to N units (stock 50)
enableAllTeams                Team 3 and Team 4 in the single-player setup
twoScoutCivs Civ ...          these civs get the two-hero interface
nativeCivs Civ ...            these civs count as native civs (dances, council)
bigButtonCivs, noBigButtonBlds   the native big button for more civs / not on buildings
enableFarmAnim, enableRectFarmAnim   gatherers work these buildings like a Mill / Rice Paddy
farmingRadius I X Z ...       per enableFarmAnim entry, the gatherers' area (stock 4.5)
trainSingleAbstractType [T]   units of type T leave training one at a time
wonderCivUnitType Proto ...   these units may start a wonder civ's age-up
ageUpBuildings [log] Proto ...   these buildings open the age-up dialog, with the politicians they list
politicianPlacesFix [log]     the age-up dialog shows as many politicians as it has places, no crash
politicianEnablesTech [log] [flag U V]   a politician shows the techs of its <PoliticianEnablesTech> lines, with rollovers
kbUnitSyscalls                five KB syscalls for AI scripts (unit inventory, workers)
marketUnits Proto ...         these buildings count as a Market for trading
explorerUnits P T S ...       hero names (Type) and knockout messages (StringID)
customRevolutionBanners       a banner for every XPRevolution<Name> tech
removeFameRestriction         Fame, XP and shipment costs and icons
removeConversionRestriction   ConvertGuardian works on any unit
hcShipmentPointFallback ...   when no stock fallback building is left, the shipment point
                              moves to the building types you list; FirstTC = the
                              player's first town center (with startingTC or civFirstTC);
                              LastResort = any building, then a hero
healNonIdle [UnitType] [moving] [fighting] [busyRate=P]   marked healers heal busy
                              units (moving, fighting, ...), at P % on a busy one
smartHealTargets [UnitType ...] [switch=P] [log]   automatic healing picks the most
                              hurt unit (listed types first) instead of the first one;
                              switch: leaves a heal for a unit more than P % lower
damageOverTime [log] [noticktext]   poison: attacks with <AttachProtoUnit> damage over
                              time (+ AttachMaxStacks, AttachSnare, AttachTickText)
dodgeAnyUnit [UnitType] [log] marked units dodge like the Japanese monk (tech YPDodge)
dodgeChance T P [tech X | notech] [ranged | melee | all] [log]   dodge chance P % per
                              unit type, with a tech (YPDodge by default) and a hit filter
dodgeSoundSet T S, criticalSoundSet T S   sound set for a type's dodge / critical hit
spreadAnyAccuracy [UnitType] [log]   <MaxSpread>/<SpreadFactor> per attack for every miss;
                              marked units scatter every shot, InstantBallistics ones too
                              (area damage where it lands; a stray shot without DamageArea
                              hits the unit it lands on)
liveBuildingWorkRate [log]    BuildingWorkRate techs also speed up existing buildings,
                              TrainPoints techs units already queued or training
techPrereqRecheck [N] [log]   <TypeCount> tech prerequisites react when units are
                              created or die, not only at the next house or age-up
orPrereqsQty [log]            <Flag qty="N">OrPrereqs</Flag>: a tech needs N of its
                              prerequisites instead of one
ageFiveShipments              cards of <age>4</age> (Imperial Age) in the deck, at the right end of
                              the Age IV row, sendable in the Imperial Age
resendableCards [log]         <resendeveryage>1</resendeveryage> on a card: sendable again (its
                              maxcount) each time its player reaches a new age
quickArrivalCards [stringid N] [log]  <Flag>QuickArrival</Flag> on a card's tech: the bullet line
                              "This is a QUICK-ARRIVAL card." in the card's rollover
shipmentCounts [log]          cards shipped per player and card age, kept in saved games; Data
                              subtype FreeHomeCityUnitByShipmentCount, XS
                              xsGetShipmentCount and xsGetShipmentCountRange
kothTimer [players|teams] N=s ...   King of the Hill time by the number of players or teams
maintainWaitForPop [UnitType] [log]  marked buildings keep a finished auto-produced unit
                              (Maintain action) until there is population room
transformUpdatesLOS [log]     units transformed by a tech or revolution get the new LOS
broadsideMuzzleLimit N [UnitType] [log]   broadsides fire from up to N muzzles per side (stock 6);
                              <NumberProjectiles> P: P shots per side over the muzzles
broadsideSoundSet [log]       a BroadsideAttack action's <BroadsideSoundSet> sound set at each
                              shot instead of ShipCannonShoot (rocket ships)
abilitySlots N [log]          command panel shows up to N abilities per unit (stock 6)
displayedRange [noPlacement] [log]   a selected unit shows a ring per ranged attack while Alt is
                              held (<AlwaysDisplayRange>: without Alt); a building being placed
                              shows its rings (noPlacement: not); with menuOptions displayedRange
                              the player turns them on or off in the options menu, at once
steadyHitpointBars [UnitType ...] [log]   floating HP bars keep one height over each unit
                              instead of jumping with its animations
inventoryBars [UnitType] [always] [noSites] [trees] [other=RRGGBB] [log]   while Alt is held,
                              a bar of what a unit, mine or carcass still holds
playerIcon <avatarId>         LAN lobby: your slot shows that avatar of data\\avatar_*.xml,
                              kept over civ changes
wonderPanelSkipAuras [log]    wonder power panel: a power listed after an aura gets a button
nativePreview [tagged] [log] [Proto]   an empty native socket shows its Trading Post's
                              units and techs, read-only
lifespanAfterConstruction [UnitType] [log]   a marked building's Lifespan starts when
                              its construction ends, not when it is placed
gaiaSocketsOnly [UnitType] [log]  socketed buildings only on sockets owned by Gaia
customHotkeyContexts [log]    keymap contexts <ProtoName>Accel: hotkeys for new buildings
snareOnlyHitUnit [log]        a snared unit no longer slows the group it moves with
techRenameEffect [log]        tech effect SetTechName: rename a tech per player (alias
                              enableTechRenameEffect)
noCorpseDopples [UnitType] [expire=S] [log]   dead marked units (hunt carcasses) leave no dopple
danceBonusCivs Civ ... [log]  fire pit train/XP/gather/regen dances for more civs
startingTC [UnitType] [log]   marked buildings count as a player's first town center
                              (FirstTC in placementrules), like TownCenter
civFirstTC [log]              a civ's <firstTC> in civs.xml replaces the TownCenter maps
                              place for its players (not Nomad); it is their FirstTC
firstTC [UnitType] [log]      civFirstTC, and startingTC when a type is named, in one line
scenarioCivs [log]            data\\scenariocivs.xml: more civs after civs.xml, for scenarios
                              and campaigns, not in the skirmish list, in the editor's
                              player civ list
transformInventory [all] [scale] [UnitType] [log]   units transformed by a tech get the
                              resources (InitialResource) of their new proto
noTrainNearEnemyTC M [UnitType] [near UnitType]... [nowarn | warn=Text] [refuse] [log]   marked units
                              (Daimyos) do not train within M metres of an enemy's first
                              Town Center or of an enemy building of a near type
overhealHitpointBars [UnitType ...] [segment[=RRGGBB]] [bar=Texture] [stat[=Label]] [log]   HP bars and texts
                              of marked units use InitialHitpoints as 100 % (overheal up to
                              MaxHitpoints); segment: the HP above it in orange, Overwatch style
                              and on the portrait bar; stat: an Overheal row
overhealSources [UnitType [cap=P] ...] [log]   only heal actions with <CanOverheal>1
                              heal overheal units above InitialHitpoints, up to
                              <OverhealCap> (Data subtypes CanOverheal, OverhealCap)
overhealDecay [R[%] [D]] [UnitType ...] [holdNear Type M] [log]   overheal above
                              InitialHitpoints decays at <OverhealDecay> % per s (default 2), D s after the last
                              heal (Overwatch style); not while an own unit of Type is
                              within M metres
showGatherRate [UnitType] [log]   stat panel shows a gathering unit's rate (Food 0.84/s)
minUIStats [file]             the minimized interface shows what the normal one shows, and
                              more (rows in minuirows.xml: ROF, range, cost, pop, ...; building
                              armor; {{uhc...}} texts)
multiplierDecimals [N]        the attack rows' bonus multipliers with N decimals (default 2):
                              1.25x instead of 1.3x, in both panels and their tooltips
attackTypeIcons T S P ...     a bonus multiplier against these unit types shows in the attack
                              rows, with that icon (P) and name (string S)
techGadgets <Tech> <GadgetAfter> [<GadgetBefore>]   (repeatable) a gadget of the interface
                              shows once the tech is active, the other one before it
cultureUI [file.xml]          the minimised in-game interface takes textures by the player's civ
                              and by tech stages (data\\uhc\\cultureui.xml); a texture X is drawn
                              as X_<suffix> where art\\ui\\ingame\\X_<suffix>.ddt exists
incomeRates [seconds] [perMinute|perSecond] [log]   {{uhcIncome(<resource>)}} in a formatText
                              gadget: what the shown player gathered and trickled over the
                              last seconds (default 20), per second or per minute
selectFattened [gadget <name>] [log]   the command uhcSelectFattened selects the player's
                              fattened livestock; {{uhcFattened}} counts it; the gadget shows
                              while there is some
workRateByAbstractType [UnitType ...] [log | log=Proto]   WorkRate effects on an abstract
                              type also reach the rates units have for its protos
autoGatherScaleByContained    ScaleByContainedUnits also works on AutoGather actions
nurseryFactor [log]           NurseryFactor* units keep a factor that grows with time, takes in
                              garrisoned units and has its own buttons; it multiplies their
                              AutoGather rate and a shipment
containedUnitsROF [log]       ScaleByContainedUnits target="ROF": an attack fires faster with
                              the units inside (ROF / count, at most DamageFactorCap)
numberOfShots [projectiles] [log]   <NumberOfShots> shots <ShotInterval> s apart before the
                              reload, the firing pose kept between them (<BurstPose>);
                              projectiles: <NumberProjectiles> per shot
retargetInAction [log]        an attack with <RetargetInAction>1 whose target dies during its
                              attack animation fires the rest of its shots at a new target
powerShots [log]              an ability's attack with <PowerShots>N fires at each Attack tag of
                              its animation, up to N shots a use, instead of one
turretArc <Proto> <aim> ... [log]   an attack with <Turret> turns its gun on the mount, not the
                              unit, toward a target inside the turret's arc
unitResourceAuras [log]       auras with ModifyType UnitResource gather from units in range
linkedResource [log]          a resource building takes the stock of the mine beside it
auraStacking [log]            <ForbidUnitType> on any aura
dataLint [log] [file]         while the data loads, says what it asks for and the game drops
resourceGatherAuras [log]     ModifyType names for one kind of target or one resource
resourceDebt [Food] [Wood] [Gold] [log]   trickles and unit rates may go below 0
costEscalationTechs [log]     a Data tech effect may change CostEscalation
randomCost [log]              <RandomCost> rolls a unit's price in a range, a new one per purchase
unitTypeTechs [log]           Data tech effects AddUnitType and RemoveUnitType, for one player's copy of a proto
veterancyBonus [notext] [log] [file]   <VeterancyBonus> rows give a proto bonuses by its kills, with a
                              rank mark; tech="..." rows; data\\uhc\\veterancy.xml: rows by unit type and
                              <Civilization> blocks, rank names and colours; notext: no floating text at a new rank
killSpawn [log]               civs.xml <killSpawn>: enemies a civ kills become animals, by weight
trainBatchSize [log]          <TrainBatchSize> limits a proto's units per Train action
pillageGold [log]             AbstractCanPillage units steal <PillageAmount> gold from buildings' owners
transformSpan [log]           transformspan on a TransformUnit effect turns the units back
hcTargetTechs [log]           tech flags HCTargetEnemy and HCTargetAll
perCivEffects [log]           onlyciv on a tech <Effect>: it works only for that civ
detonationDeath [log]         <DetonationProtoAction> fires an action when a unit dies
accuracyTechs [log]           a Data tech effect may change an action's Accuracy
cratePriority <Civ|all> <Res> <Res> <Res>   a civ's order of gathering crates (repeatable;
                              a line "cratePriority log" logs)
sharedBuildLimit [log]        protos share a build limit, by type, with weights, or by team
annexFacing [log]             <AnnexOf> annexes face their parent building and fall with it
customWalls [log]             <WallPiece> tags: a wallBuild proto lays its own posts and pieces
doNotQueue [log]              <DoNotQueue/> trains a proto, and a card with that tech flag ships, ahead of the queue
researchOnTheMove [log]       units of type ResearchOnTheMove take orders and walk while they research
nextResearchFree [log]        a Data tech effect makes a building's next research free
researchGrants [log]          <ResearchGrantInterval> buildings gather points that make researches cheaper or free
shipTechLimit [log]           <ShipTechLimit>N</ShipTechLimit> in a civ caps its techs that cost Ships per game
                              (repeatable techs excepted)
homeCityTechsInUnits [log]    a home city card listed in a proto's <Tech> rows is researched there like a tech
killBountyTechs [log]         a Data tech effect may change a proto's Bounty
resourceBounty [log]          <Bounty resourcetype> pays a resource at the kill
teamKillBounty [log]          the XP of a marked victim goes to the killer's team
cantBeSlowed [log]            a marked unit ignores TargetSpeedBoost
snareValues [strongest] [log]  SnareFactor and SnareDuration by action and by tech; the strongest snare counts
stealthTargeting [log]        large units in stealth hidden from enemies; no attack on an unseen stealthed unit
autoScout [Tactic [Return]] [noAvoid] [noBack] [log]  units in that tactic explore the map on their own,
                              away from enemy towers, backing off when hit; an order switches it off
autoGatherFrom [log]          a unit idle for a few seconds gathers from what its gather action's
                              <AutogatherFrom> names, if one is within the action's range
buildingGather [log]          a building with a Gather action gathers from what is within its range
herdWalkAwayFix [log]         a fattened herdable that walks away from its pen or nomad stays there
faithResource [log]           optional: resource 4 (SkillPoints) a plain resource, cut from the home city;
                              a Gather of it plays the action's own <anim>
transformChecks [log]         transform buttons grey out with the reason; a transform respects BuildLimit
garrisonConvert [log]         <GarrisonConvertTo delay="S" eject="true" from="Type">Unit</GarrisonConvertTo>:
                              the units that enter a building become that unit, at once or one every S
                              seconds; several tags take turns; waits at the population cap; techs
                              change the tags (Data subtypes GarrisonConvert*)
lanAutoStart [host [rules=N] | join <address>]   from the main menu straight to hosting or joining
                              a LAN game; +uhcLanHost / uhcLanJoin="<address>" on the command line
editorSearch [log]            search fields in the editor's Objects palette, Forbidden Units/Techs
                              dialog and trigger editor (the fields come in the layouts)
editorAutosave [minutes] [keep N] [log]   the editor saves the open scenario every few minutes
                              (default 5) to autosave-1 ... autosave-N (default 3), its name unchanged
directionalAttack [log]       <DirectionalAttack>: a shot flies past its target and hits what it flies over
buildingWorkRateAuras [log]   auras with ModifyType BuildingWorkRate change train,
                              research, Maintain, heal and build speed
bufferedFileReads [KB] [readahead] [verify]  buffered file reads: fewer stutters, faster
                              loading; readahead reads the next block on a worker thread
fastVertexFill [verify] [log]   waving flags drawn without reading video memory: more fps with
                              flags on screen
fastLastInLine [log] [verify]  no freeze after a home city shipment in a mod with many techs
xsErrorLog [lines]            the XS compiler's and runtime's messages go to the log
multipleInstances [background]  run beside a copy of the game from another folder
preloadDll <file> ...         engine-ext.cfg only: dinput8.dll also loads these DLLs of the game
                              folder before the game starts, as another dinput8.dll proxy would
rendererOption [vulkan|dx9] [folder=D] [log] [conf=...]   a Renderer entry in the options
                              menu: Vulkan (DXVK, from dxvk\\) at the next start, more fps
menuOptions <key> ...         players switch bufferedFileReads / fastVertexFill / fastLastInLine
                              on or off in the options menu, from the next start, and the
                              range rings of displayedRange at once, also during a match

What each key needs from your mod, and how well it is tested: see the guide.
Single player only: no feature has been tested in multiplayer. License: MIT, see LICENSE.txt.

Vulkan renderer (rendererOption)
--------------------------------
The dxvk folder holds DXVK {DXVK_VERSION} (https://github.com/doitsujin/dxvk), a Direct3D 9 to
Vulkan translation layer by Philip Rebohle and its contributors, under the zlib license
(dxvk\\LICENSE.txt). It is shipped unmodified. With rendererOption on, copy the dxvk folder next
to the game's exe and add the Renderer field to data\\options.xml (see the guide). The menu
entry picks the renderer for the next start; DirectX 9 stays the default. If a start with
Vulkan fails before its first frame, the next start goes back to DirectX 9 on its own. To
remove it, delete the dxvk folder.
"""
    return text.replace("\n", "\r\n")


def readme_dinput8(version):
    """README.txt of the --dinput8-only package: dinput8.dll and engine-ext, no UHC.dll."""
    full = readme(version).replace("\r\n", "\n")
    rings = full[full.index("Aura rings\n"):full.index("A uhc.cfg written by the patcher")]
    # The keys' default data folder is engine-ext\ in this build (src/engineext.cpp, kDataFolder).
    keys = full[full.index("Keys that need data edits"):].replace("data\\uhc\\", "engine-ext\\")
    text = f"""dinput8.dll {version} for Age of Empires III: The Asian Dynasties (Steam)
=========================================================================

dinput8.dll removes hard-coded limits of the game and adds new engine features. A mod turns each
feature on in engine-ext\\engine-ext.cfg. It needs the Steam version of TAD (age3y.exe, SHA-256
b1a1dab7...11d9d). It needs no loader and no patcher, and it also works in a game whose loader
runs another UHC.dll: nothing of that game changes, not its exe, its UHC.dll, its cfg or data\\uhc.

Full guide:  {REPO_URL}/blob/main/docs/modding-guide.md
Downloads:   {REPO_URL}/releases

Adding it to your mod
---------------------
1. Make your mod folder a complete game folder: a copy of the game's bin folder plus your
   mod's files. Never modify the Steam install.
2. Copy dinput8.dll and the engine-ext folder of this package next to the mod's age3y.exe.
3. In engine-ext\\engine-ext.cfg, remove the "#" in front of the keys you want, and in front of
   ignoreRegistryPath if nothing else in the mod folder makes the game read its data from there.
   Data files that keys read by default go in engine-ext\\. Some keys need data or art from your
   mod: see the guide.
4. Start the mod's age3y.exe. engine-ext\\engine-ext.log appears: its first line is
   "dinput8.dll {version}", and every key you enabled says "applied". A key fails, and changes
   nothing, when another DLL of the game already patched a place it needs.
5. Ship dinput8.dll and engine-ext\\engine-ext.cfg with your mod (not engine-ext.log). Players
   install nothing else.
To remove it, delete dinput8.dll and the engine-ext folder.
If the game already has a dinput8.dll that loads another DLL (a mod's proxy), keep that file
aside and put "preloadDll <its DLL>" in engine-ext\\engine-ext.cfg: this dinput8.dll then loads
it at the same moment, before the game starts.

"""
    return (text + rings + keys).replace("\n", "\r\n")


def main_dinput8(argv, force):
    """dist/dinput8-<version>.zip: dinput8.dll with its engine-ext cfg, the art and DXVK; no UHC.dll."""
    dxvk_folder = ROOT / "rea" / "vendor" / f"dxvk-{DXVK_VERSION}"
    if "--dxvk" in argv:
        dxvk_folder = pathlib.Path(argv[argv.index("--dxvk") + 1])
    dxvk_dll, dxvk_license = read_dxvk(dxvk_folder)
    version = read_version()
    proxy = check_proxy(ROOT / "build" / "Release" / "dinput8.dll", version)
    out = ROOT / "dist" / f"dinput8-{version}.zip"
    if out.exists() and not force:
        fail(f"{out.relative_to(ROOT)} already exists; pass --force to replace it")
    out.parent.mkdir(exist_ok=True)
    top = f"dinput8-{version}"
    license_text = (ROOT / "LICENSE").read_text(encoding="utf-8").replace("\r\n", "\n").replace("\n", "\r\n")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr(f"{top}/dinput8.dll", proxy)
        z.writestr(f"{top}/engine-ext/engine-ext.cfg",
                   template_cfg(version, f"# engine-ext\\engine-ext.cfg template for dinput8.dll {version}."))
        for ring in sorted((ROOT / "tools" / "rings").glob("*")):
            z.write(ring, f"{top}/art/effects/uhc_rings/{ring.name}")
        for bar in sorted((ROOT / "tools" / "bars").glob("*.ddt")):
            z.write(bar, f"{top}/art/ui/uhc/{bar.name}")
        for frame in sorted((ROOT / "tools" / "pie").glob("*.ddt")):
            z.write(frame, f"{top}/art/ui/uhc/pie/{frame.name}")
        z.writestr(f"{top}/dxvk/d3d9.dll", dxvk_dll)
        z.writestr(f"{top}/dxvk/LICENSE.txt", dxvk_license)
        z.writestr(f"{top}/LICENSE.txt", license_text)
        z.writestr(f"{top}/README.txt", readme_dinput8(version))
    print(f"wrote {out.relative_to(ROOT)}")
    print(f"  SHA-256 zip         {hashlib.sha256(out.read_bytes()).hexdigest()}")
    print(f"  SHA-256 dinput8.dll {hashlib.sha256(proxy).hexdigest()}")


def main(argv):
    force = "--force" in argv
    if "--dinput8-only" in argv:
        return main_dinput8(argv, force)
    dxvk_folder = ROOT / "rea" / "vendor" / f"dxvk-{DXVK_VERSION}"
    if "--dxvk" in argv:
        dxvk_folder = pathlib.Path(argv[argv.index("--dxvk") + 1])
    dxvk_dll, dxvk_license = read_dxvk(dxvk_folder)
    version = read_version()
    dll_path = ROOT / "build" / "Release" / "UHC.dll"
    dll = check_dll(dll_path, version)
    proxy = check_proxy(ROOT / "build" / "Release" / "dinput8.dll", version)
    out = ROOT / "dist" / f"UHC-{version}.zip"
    if out.exists() and not force:
        fail(f"{out.relative_to(ROOT)} already exists; pass --force to replace it")
    out.parent.mkdir(exist_ok=True)
    top = f"UHC-{version}"
    license_text = (ROOT / "LICENSE").read_text(encoding="utf-8").replace("\r\n", "\n").replace("\n", "\r\n")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr(f"{top}/UHC.dll", dll)
        z.writestr(f"{top}/Startup/uhc.cfg", template_cfg(version))
        z.writestr(f"{top}/beside-another-dll/dinput8.dll", proxy)
        z.writestr(f"{top}/beside-another-dll/engine-ext/engine-ext.cfg",
                   template_cfg(version, f"# engine-ext\\engine-ext.cfg template for dinput8.dll {version}."))
        for ring in sorted((ROOT / "tools" / "rings").glob("*")):
            z.write(ring, f"{top}/art/effects/uhc_rings/{ring.name}")
        for bar in sorted((ROOT / "tools" / "bars").glob("*.ddt")):
            z.write(bar, f"{top}/art/ui/uhc/{bar.name}")
        for frame in sorted((ROOT / "tools" / "pie").glob("*.ddt")):
            z.write(frame, f"{top}/art/ui/uhc/pie/{frame.name}")
        z.writestr(f"{top}/dxvk/d3d9.dll", dxvk_dll)
        z.writestr(f"{top}/dxvk/LICENSE.txt", dxvk_license)
        z.writestr(f"{top}/LICENSE.txt", license_text)
        z.writestr(f"{top}/README.txt", readme(version))
    print(f"wrote {out.relative_to(ROOT)}")
    print(f"  SHA-256 zip     {hashlib.sha256(out.read_bytes()).hexdigest()}")
    print(f"  SHA-256 UHC.dll {hashlib.sha256(dll).hexdigest()}")
    print(f"  SHA-256 dinput8.dll {hashlib.sha256(proxy).hexdigest()}")


if __name__ == "__main__":
    main(sys.argv[1:])
