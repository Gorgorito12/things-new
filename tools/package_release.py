"""Build the release zip that modders download: dist/UHC-<version>.zip.

Usage: python -I tools/package_release.py [--force]

Run it from the repository root after a Release build (docs/developer-guide.md, "Making a
release"). It checks build/Release/UHC.dll first and stops if:
  - the DLL is not a 32-bit x86 PE, or does not export _UHCMain@0;
  - the DLL is not the version in CMakeLists.txt (it must contain the UTF-16 "UHC.dll <ver>");
  - a file under src/, or CMakeLists.txt, is newer than the DLL (rebuild first).

The zip holds one folder, UHC-<version>/, with:
  UHC.dll
  Startup/uhc.cfg    examples/Startup/uhc.cfg with every key commented out (stock behavior)
  LICENSE.txt
  README.txt         the quick start for modders
The game exe is not included: each modder patches their own copy with the loader's patcher.
An existing zip is kept unless --force is given. The SHA-256 of the zip and the DLL are printed.
"""
import hashlib
import pathlib
import re
import struct
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
REPO_URL = "https://github.com/Gorgorito12/tad-engine-extensions"


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


def check_dll(dll, version):
    if not dll.exists():
        fail(f"{dll} not found; build first: cmake --build build --config Release")
    data = dll.read_bytes()
    if "_UHCMain@0" not in pe_exports(data):
        fail("UHC.dll does not export _UHCMain@0")
    if f"UHC.dll {version}".encode("utf-16-le") not in data:
        fail(f"UHC.dll is not version {version}; rebuild after changing CMakeLists.txt")
    sources = [ROOT / "CMakeLists.txt"] + [p for p in (ROOT / "src").rglob("*") if p.is_file()]
    newer = [p for p in sources if p.stat().st_mtime > dll.stat().st_mtime]
    if newer:
        fail(f"{newer[0].relative_to(ROOT)} is newer than UHC.dll; rebuild first")
    return data


def template_cfg(version):
    """The example cfg with every key line commented out."""
    lines = [
        f"# Startup\\uhc.cfg template for UHC.dll {version}.",
        "# Every key is commented out, so the game behaves as stock until you enable one: remove",
        "# the \"# \" in front of a key line. Keep the other comment lines as they are.",
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
4. In Startup\\uhc.cfg, remove the "# " in front of ignoreRegistryPath (always needed in a mod
   folder) and of the keys you want. Some keys need data or art from your mod: see the guide.
5. Start the mod's age3y.exe. UHC.log appears next to it: its first line is "UHC.dll {version}",
   and every key you enabled says "applied".
6. Ship your files, the patched age3y.exe, UHC.dll and Startup\\uhc.cfg (not UHC.log or
   age3y.backupuhc). Do not ship a copy of the game: your installer builds the complete folder
   from each player's own game install. Players can then start it however they like, because
   UHC.dll makes the exe's folder the working directory. They install nothing else.

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
customProtoUnitCommands [file]   command types (buttons) from an XML file
multiarmor                    one armor per damage type; Armor effects follow damagetype
betterfreedynamicunit         dynamic free units grow smoothly with game time
gatherFix                     gather on a fixed interval (the data's rate)
rofFix, stunMovingTargetFix   orders keep the attack timer; stuns survive a moving target
noDamageOnUnbuiltFoundations  unbuilt foundations take no damage
fallenHeroTacticsFix          knocked-out or stunned units keep their tactic
nowalkfarm                    farm gatherers keep their first spot
repairWallGlobal              UI syscall repairWallGlobal(): repair all walls
compatMode                    32-bit display modes also offered at 16 bits
                              (default data\\uhc\\customabstracttypes.xml)
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
kbUnitSyscalls                five KB syscalls for AI scripts (unit inventory, workers)
marketUnits Proto ...         these buildings count as a Market for trading
explorerUnits P T S ...       hero names (Type) and knockout messages (StringID)
customRevolutionBanners       a banner for every XPRevolution<Name> tech
removeFameRestriction         Fame, XP and shipment costs and icons
removeConversionRestriction   ConvertGuardian works on any unit
hcShipmentPointFallback ...   when no stock fallback building is left, the shipment point
                              moves to the building types you list; FirstTC = the
                              player's first town center (with startingTC or civFirstTC)
healNonIdle [UnitType]        marked healers heal busy units (moving, fighting, ...)
smartHealTargets [UnitType ...] [log]   automatic healing picks the most hurt unit
                              (listed types first) instead of the first one
damageOverTime [log] [noticktext]   poison: attacks with <AttachProtoUnit> damage over
                              time (+ AttachMaxStacks, AttachSnare, AttachTickText)
dodgeAnyUnit [UnitType] [log] marked units dodge like the Japanese monk (tech YPDodge)
dodgeChance T P [tech X | notech] [ranged | melee | all] [log]   dodge chance P % per
                              unit type, with a tech (YPDodge by default) and a hit filter
dodgeSoundSet T S, criticalSoundSet T S   sound set for a type's dodge / critical hit
spreadAnyAccuracy [UnitType] [log]   <MaxSpread>/<SpreadFactor> per attack for every miss;
                              marked units scatter every shot (area damage where it lands)
liveBuildingWorkRate [log]    BuildingWorkRate techs also speed up existing buildings,
                              TrainPoints techs units already queued or training
techPrereqRecheck [N] [log]   <TypeCount> tech prerequisites react when units are
                              created or die, not only at the next house or age-up
maintainWaitForPop [UnitType] [log]  marked buildings keep a finished auto-produced unit
                              (Maintain action) until there is population room
transformUpdatesLOS [log]     units transformed by a tech or revolution get the new LOS
broadsideMuzzleLimit N [UnitType] [log]   broadsides fire from up to N muzzles per side (stock 6)
abilitySlots N [log]          command panel shows up to N abilities per unit (stock 6)
wonderPanelSkipAuras [log]    wonder power panel: a power listed after an aura gets a button
lifespanAfterConstruction [UnitType] [log]   a marked building's Lifespan starts when
                              its construction ends, not when it is placed
gaiaSocketsOnly [UnitType] [log]  socketed buildings only on sockets owned by Gaia
customHotkeyContexts [log]    keymap contexts <ProtoName>Accel: hotkeys for new buildings
snareOnlyHitUnit [log]        a snared unit no longer slows the group it moves with
techRenameEffect [log]        tech effect SetTechName: rename a tech per player
noCorpseDopples [UnitType] [log]   dead marked units (hunt carcasses) leave no dopple
danceBonusCivs Civ ... [log]  fire pit train/XP/gather/regen dances for more civs
startingTC [UnitType] [log]   marked buildings count as a player's first town center
                              (FirstTC in placementrules), like TownCenter
civFirstTC [log]              a civ's <firstTC> in civs.xml replaces the TownCenter maps
                              place for its players (not Nomad); it is their FirstTC
transformInventory [all] [scale] [UnitType] [log]   units transformed by a tech get the
                              resources (InitialResource) of their new proto
noTrainNearEnemyTC M [UnitType] [near UnitType]... [nowarn | warn=Text] [log]   marked units
                              (Daimyos) do not train within M metres of an enemy's first
                              Town Center or of an enemy building of a near type
overhealHitpointBars [UnitType ...] [segment[=RRGGBB]] [bar=Texture] [stat[=Label]] [log]   HP bars and texts
                              of marked units use InitialHitpoints as 100 % (overheal up to
                              MaxHitpoints); segment: the HP above it in orange, Overwatch style
                              and on the portrait bar; stat: an Overheal row
overhealSources [UnitType ...] [log]   only marked healers (AbstractOverhealer) heal
                              overheal units above InitialHitpoints
overhealDecay R[%] [D] [UnitType ...] [log]   overheal above InitialHitpoints decays
                              at R HP/s, D s after the last heal (Overwatch style)
showGatherRate [UnitType] [log]   stat panel shows a gathering unit's rate (Food 0.84/s)
workRateByAbstractType [UnitType ...] [log | log=Proto]   WorkRate effects on an abstract
                              type also reach the rates units have for its protos
buildingWorkRateAuras [log]   auras with ModifyType BuildingWorkRate change train,
                              research and Maintain speed
bufferedFileReads [KB]        buffered file reads: fewer stutters, faster loading
multipleInstances [background]  run beside a copy of the game from another folder

What each key needs from your mod, and how well it is tested: see the guide.
No feature has been tested in multiplayer yet. License: MIT, see LICENSE.txt.
"""
    return text.replace("\n", "\r\n")


def main(argv):
    force = "--force" in argv
    version = read_version()
    dll_path = ROOT / "build" / "Release" / "UHC.dll"
    dll = check_dll(dll_path, version)
    out = ROOT / "dist" / f"UHC-{version}.zip"
    if out.exists() and not force:
        fail(f"{out.relative_to(ROOT)} already exists; pass --force to replace it")
    out.parent.mkdir(exist_ok=True)
    top = f"UHC-{version}"
    license_text = (ROOT / "LICENSE").read_text(encoding="utf-8").replace("\r\n", "\n").replace("\n", "\r\n")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr(f"{top}/UHC.dll", dll)
        z.writestr(f"{top}/Startup/uhc.cfg", template_cfg(version))
        z.writestr(f"{top}/LICENSE.txt", license_text)
        z.writestr(f"{top}/README.txt", readme(version))
    print(f"wrote {out.relative_to(ROOT)}")
    print(f"  SHA-256 zip     {hashlib.sha256(out.read_bytes()).hexdigest()}")
    print(f"  SHA-256 UHC.dll {hashlib.sha256(dll).hexdigest()}")


if __name__ == "__main__":
    main(sys.argv[1:])
