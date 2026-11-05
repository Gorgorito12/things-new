"""Writes docs/porting-code/*.md, the complete code of the features WoL's DLL does not have, from src/.

One page per theme of the modding guide, so that none is too large for GitHub to show (it stops
rendering a Markdown file at about 512 KB). The pages are generated: change src/ and run this script
in the commit, never edit them by hand.

    python -I tools/porting_code.py           writes the pages
    python -I tools/porting_code.py --check   exit code 1 if a page differs from src/
"""
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
OUT = REPO / "docs" / "porting-code"
GUIDE = "../porting-to-another-dll.md"

# Page: (title, {section: [files]}). Section names are the headings of section 4 of the porting guide.
PAGES = {
    "helpers": ("Helpers", {
        "Site table": ["src/site.h", "src/generated/sites.h"],
        "Patching": ["src/patch.h", "src/patch.cpp"],
        "Log": ["src/log.h", "src/log.cpp", "src/hooks/common.inc"],
        "Cfg reader": ["src/config.h", "src/config.cpp"],
        "Results": ["src/features.h"],
        "Extra abstract unit types": ["src/unittypes.h", "src/unittypes.cpp", "src/hooks/unittype_hooks.asm"],
        "World tick": ["src/worldtick.h", "src/worldtick.cpp", "src/hooks/worldtick_hooks.asm"],
        "Action tags": ["src/actiontags.h", "src/actiontags.cpp", "src/hooks/actiontag_hooks.asm"],
        "Proto tags": ["src/prototags.h", "src/prototags.cpp", "src/hooks/prototag_hooks.asm"],
        "Tech subtypes": ["src/techsubtypes.h", "src/techsubtypes.cpp", "src/hooks/techsubtype_hooks.asm"],
        "Modify types": ["src/modifytypes.h", "src/modifytypes.cpp", "src/hooks/modifytype_hooks.asm"],
        "Floating text": ["src/floatingtext.h", "src/floatingtext.cpp"],
        "Modifier walk": ["src/modifiers.h"],
        "Unit panel row (the minimized interface)": ["src/unitpanel.h", "src/unitpanel.cpp", "src/hooks/unitpanelrow_hooks.asm"],
        "Name lists": ["src/namelists.h", "src/namelists.cpp"],
    }),
    "game-files": ("Game files", {
        "bufferedFileReads": ["src/features/fileio.cpp"],
    }),
    "population": ("Population", {
        "decimalPopulation": ["src/features/decimalpop.cpp", "src/hooks/decimalpop_hooks.asm",
                              "src/features/limits.cpp", "src/hooks/limit_hooks.asm"],
    }),
    "data": ("Data and scripting", {
        "customHotkeyContexts": ["src/features/hotkeys.cpp", "src/hooks/hotkey_hooks.asm"],
        "techRenameEffect": ["src/features/techrename.cpp", "src/hooks/techrename_hooks.asm"],
    }),
    "civs": ("Civs", {
        "danceBonusCivs": ["src/features/dance.cpp", "src/hooks/dance_hooks.asm"],
        "startingTC": ["src/features/startingtc.cpp", "src/hooks/startingtc_hooks.asm"],
        "civFirstTC": ["src/features/civfirsttc.cpp", "src/hooks/civfirsttc_hooks.asm"],
    }),
    "healing": ("Healing and hit points", {
        "healNonIdle": ["src/features/heal.cpp", "src/hooks/heal_hooks.asm"],
        "smartHealTargets": ["src/features/smartheal.cpp", "src/hooks/smartheal_hooks.asm"],
        "overhealHitpointBars": ["src/features/overheal.cpp", "src/hooks/overheal_hooks.asm"],
        "overhealSources": ["src/features/overhealsources.cpp", "src/hooks/overhealsources_hooks.asm"],
        "overhealDecay": ["src/features/overhealdecay.cpp"],
    }),
    "combat": ("Combat", {
        "dodgeAnyUnit, dodgeSoundSet and criticalSoundSet": ["src/features/dodge.cpp", "src/hooks/dodge_hooks.asm"],
        "damageOverTime": ["src/features/damageovertime.cpp", "src/hooks/dot_hooks.asm"],
        "spreadAnyAccuracy": ["src/features/spread.cpp", "src/hooks/spread_hooks.asm"],
        "accuracyTechs": ["src/features/accuracy.cpp"],
        "broadsideMuzzleLimit": ["src/features/broadside.cpp", "src/hooks/broadside_hooks.asm"],
        "snareOnlyHitUnit": ["src/features/snare.cpp", "src/hooks/snare_hooks.asm"],
        "cantBeSlowed": ["src/features/cantslow.cpp", "src/hooks/cantslow_hooks.asm"],
        "killBountyTechs, resourceBounty and teamKillBounty": ["src/features/bounty.cpp", "src/hooks/bounty_hooks.asm"],
    }),
    "gathering": ("Gathering", {
        "showGatherRate": ["src/features/gatherrate.cpp", "src/hooks/gatherrate_hooks.asm"],
        "workRateByAbstractType": ["src/features/workratetype.cpp", "src/hooks/workratetype_hooks.asm"],
        "cratePriority": ["src/features/cratepriority.cpp"],
        "autoGatherScaleByContained": ["src/features/gatherscale.cpp", "src/hooks/gatherscale_hooks.asm"],
        "unitResourceAuras": ["src/features/unitresource.cpp", "src/hooks/unitresource_hooks.asm"],
        "resourceGatherAuras": ["src/features/gatherauras.cpp", "src/hooks/gatherauras_hooks.asm"],
        "resourceDebt": ["src/features/resourcedebt.cpp", "src/hooks/resourcedebt_hooks.asm"],
    }),
    "buildings": ("Buildings and training", {
        "liveBuildingWorkRate": ["src/features/workrate.cpp", "src/hooks/workrate_hooks.asm"],
        "buildingWorkRateAuras": ["src/features/bwrauras.cpp", "src/hooks/bwraura_hooks.asm"],
        "costEscalationTechs": ["src/features/costescalation.cpp"],
        "trainBatchSize": ["src/features/trainbatch.cpp", "src/hooks/trainbatch_hooks.asm"],
        "sharedBuildLimit": ["src/features/sharedlimit.cpp", "src/hooks/sharedlimit_hooks.asm"],
        "doNotQueue": ["src/features/donotqueue.cpp"],
        "nextResearchFree": ["src/features/freeresearch.cpp", "src/hooks/freeresearch_hooks.asm"],
        "maintainWaitForPop": ["src/features/maintain.cpp", "src/hooks/maintain_hooks.asm"],
        "noTrainNearEnemyTC": ["src/features/notrainneartc.cpp", "src/hooks/notrainneartc_hooks.asm"],
        "lifespanAfterConstruction": ["src/features/lifespan.cpp", "src/hooks/lifespan_hooks.asm"],
        "gaiaSocketsOnly": ["src/features/sockets.cpp", "src/hooks/socket_hooks.asm"],
        "hcShipmentPointFallback": ["src/features/shipments.cpp", "src/hooks/shipment_hooks.asm"],
    }),
    "techs": ("Techs and transforms", {
        "techPrereqRecheck": ["src/features/techprereq.cpp", "src/hooks/techprereq_hooks.asm"],
        "transformUpdatesLOS": ["src/features/transform.cpp", "src/hooks/transform_hooks.asm"],
        "transformInventory": ["src/features/transforminv.cpp", "src/hooks/transforminv_hooks.asm"],
    }),
    "interface": ("Interface", {
        "abilitySlots": ["src/features/abilityslots.cpp", "src/hooks/abilityslot_hooks.asm"],
        "wonderPanelSkipAuras": ["src/features/wonderpanel.cpp", "src/hooks/wonderpanel_hooks.asm"],
        "noCorpseDopples": ["src/features/dopples.cpp", "src/hooks/dopple_hooks.asm"],
    }),
}

# include name -> the section of the helpers page that has it
HELPER_OF = {
    "generated/sites.h": "site-table", "site.h": "site-table", "patch.h": "patching", "log.h": "log",
    "config.h": "cfg-reader", "features.h": "results", "unittypes.h": "extra-abstract-unit-types",
    "worldtick.h": "world-tick", "actiontags.h": "action-tags", "modifytypes.h": "modify-types", "techsubtypes.h": "tech-subtypes", "prototags.h": "proto-tags", "floatingtext.h": "floating-text",
    "modifiers.h": "modifier-walk", "unitpanel.h": "unit-panel-row-the-minimized-interface",
    "namelists.h": "name-lists",
}
LANG = {".cpp": "cpp", ".h": "cpp", ".asm": "asm", ".inc": "asm"}


def anchor(title):
    return re.sub(r"[^a-z0-9 -]", "", title.lower()).replace(" ", "-")


def read(rel):
    return re.sub(r"\r*\n", "\n", (REPO / rel).read_bytes().decode("utf-8")).rstrip()


def site_table():
    text = read("src/generated/sites.h")
    sizes = {}
    for m in re.finditer(r"(k\w+)\[\] = \{([^}]*)\}", text):
        sizes[m.group(1)] = m.group(2).count(",") + 1
    table = {}
    for m in re.finditer(r'Site (k\w+)\{"(\w+)", 0x([0-9A-Fa-f]+), (k\w+), sizeof', text):
        table[m.group(1)] = (int(m.group(3), 16), m.group(2), sizes[m.group(4)])
    return table


def helpers_used(files):
    found = set()
    for rel in files:
        if rel.endswith(".cpp"):
            for name in re.findall(r'#include "(?:\.\./)?([^"]+)"', read(rel)):
                if name in HELPER_OF and name not in ("site.h", "generated/sites.h", "patch.h", "log.h", "features.h"):
                    found.add(name)
    return sorted(found)


def sites_used(files, table):
    names = set()
    for rel in files:
        if rel.endswith(".cpp"):
            names |= set(re.findall(r"sites::(k\w+)", read(rel)))
    return sorted(table[n] for n in names if n in table)


def section_text(page, title, files, table):
    out = [f"## {title}", ""]
    if page != "helpers":
        out += [f"Contract: [{title}]({GUIDE}#{anchor(title)}).", ""]
        needed = helpers_used(files)
        if needed:
            links = ", ".join(f"[`{n}`](helpers.md#{HELPER_OF[n]})" for n in needed)
            out += [f"Besides the core helpers, it needs: {links}.", ""]
        sites = sites_used(files, table)
        if sites:
            out += ["Sites: " + ", ".join(f"`{n}` `0x{va:X}` ({size} B)" for va, n, size in sites) + ".", ""]
    for rel in files:
        code = read(rel)
        fence = "````" if "```" in code else "```"
        out += [f"### {rel}", "", fence + LANG[pathlib.Path(rel).suffix], code, fence, ""]
    return out


def page_text(page, title, sections, table):
    out = [f"# Code for WoL: {title}", ""]
    out += ["Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the",
            "script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.", ""]
    if page == "helpers":
        out += [f"What every feature uses. [The porting guide]({GUIDE}#helpers-you-need) says what each one maps to in",
                "WoL's DLL.", ""]
    else:
        out += [f"Read the [porting guide]({GUIDE}) first: it says what each hook expects and what it must preserve.",
                "Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.", ""]
    if len(sections) > 1:
        out += ["Contents:"] + [f"- [{t}](#{anchor(t)})" for t in sections] + [""]
    for t, files in sections.items():
        out += section_text(page, t, files, table)
    return "\n".join(out).rstrip("\n") + "\n"


def build():
    table = site_table()
    return {f"{page}.md": page_text(page, title, sections, table) for page, (title, sections) in PAGES.items()}


def main(argv):
    if argv not in ([], ["--check"]):
        sys.exit(__doc__)
    pages = build()
    if argv:
        bad = [n for n, text in pages.items()
               if not (OUT / n).exists() or (OUT / n).read_bytes().decode("utf-8").replace("\r\n", "\n") != text]
        extra = [p.name for p in OUT.glob("*.md") if p.name not in pages] if OUT.exists() else []
        if bad or extra:
            print("porting_code: out of date:", ", ".join(bad + extra))
            sys.exit(1)
        print(f"porting_code: {len(pages)} pages match src/")
        return
    OUT.mkdir(exist_ok=True)
    for name, text in pages.items():
        (OUT / name).write_bytes(text.encode("utf-8"))
    sizes = {n: len(t.encode("utf-8")) // 1024 for n, t in pages.items()}
    print("porting_code: wrote", sizes, "KB")


if __name__ == "__main__":
    main(sys.argv[1:])
