"""Test data for the aura rings in a WoL bed: the Explorer gets display-only auras (AutoRangedModify, Damage x1.0, so
nothing changes but the ring), one per ring, each on one proto, so a scene shows every size and the anti-rings.

    python -I tools/ring_testdata.py <bed>            writes data\\tactics\\explorer.tactics, the original kept as
                                                      explorer.tactics.ring-orig
    python -I tools/ring_testdata.py <bed> --restore  puts the original back

The tactics file keeps its CRLF. Copy tools\\rings (and the private pack wol-fixes\\aura-rings, for the mesh rings) to
art\\effects\\uhc_rings in the bed, and remove it after.
"""
import pathlib
import shutil
import sys

# proto -> ring: units, cavalry, the three building sizes, two anti-rings
RINGS = {
    "Settler": "gold",
    "Skirmisher": "rof",
    "Grenzer": "hp_neg",
    "WOLJaeger": "damage_neg",
    "Hussar": "speed",
    "TownCenter": "work",
    "Barracks": "damage",
    "House": "heal",
}


def action(proto, ring):
    lines = [f"<name>UhcRing{proto}</name>", "<type>AutoRangedModify</type>", "<active>1</active>",
             "<maxrange>40</maxrange>", "<persistent>1</persistent>", "<modifytype>Damage</modifytype>",
             "<modifymultiplier>1.0</modifymultiplier>", f"<modifyprotoid>{proto}</modifyprotoid>",
             f"<modelattachment>effects\\uhc_rings\\ring_{ring}.xml</modelattachment>",
             "<modelattachmentbone>bonethatdoesntexist</modelattachmentbone>"]
    return "\r\n".join(["\t<action>"] + ["\t\t" + line for line in lines] + ["\t</action>", ""])


def main():
    bed = pathlib.Path(sys.argv[1])
    path = bed / "data" / "tactics" / "explorer.tactics"
    orig = path.with_name(path.name + ".ring-orig")
    if "--restore" in sys.argv:
        shutil.copy2(orig, path)
        orig.unlink()
        print("ring_testdata: restored")
        return
    if not orig.exists():
        shutil.copy2(path, orig)
    text = orig.read_bytes().decode("utf-8")
    at = text.index("<tactic>")
    at = text.rfind("\n", 0, at) + 1
    text = text[:at] + "".join(action(p, r) for p, r in RINGS.items()) + text[at:]
    names = "".join(f"\t\t<action>UhcRing{p}</action>\r\n" for p in RINGS)
    parts = text.split("<tactic>")
    for k in range(1, len(parts)):  # every tactic of the file lists them, before its first action
        first = parts[k].find("<action>")
        if first < 0:  # a tactic with no action of its own
            continue
        line = parts[k].rfind("\n", 0, first) + 1
        parts[k] = parts[k][:line] + names + parts[k][line:]
    path.write_bytes("<tactic>".join(parts).encode("utf-8"))
    print(f"ring_testdata: {len(RINGS)} ring auras on the Explorer in {path}")


if __name__ == "__main__":
    main()
