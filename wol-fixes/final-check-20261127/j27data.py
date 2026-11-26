"""Test data for the 2026-11-27 joint check (agent J), from N3's n3_data.py and GC2's gc2data.py.

python -I j27data.py <bed> apply smoke|load [cfg lines...]   |   python -I j27data.py <bed> restore

Applied on top of the bed's current files (after the packs), with one backup per file (*.j27bak, copy2:
same bytes and times), so restore gives back exactly the files the packs left.
smoke: the Bank as a nursery (N3: exponential b 2 every 8 s, cap 10, goats and Settlers taken, three buttons,
       the third makes 3 Settlers: the pop-cap test), the Blockhouse with two GarrisonConvertTo tags that take
       turns and put the units out, art\\ui\\uhc\\pie (the pie after the row).
load:  the Bank as a nursery every 20 s (b 2, cap 10), techs J27Base (GrowthBase = 3), J27Max (Max +10),
       N3TestShip2 (FreeHomeCityUnitByNurseryFactor CrateofCoin, consume 2), N2TestShip (consume all).
"""
import os
import shutil
import sys

BED = sys.argv[1]
SUFFIX = ".j27bak"
FILES = [r"data\protoy.xml", r"data\protounitcommands.xml", r"data\uhc\customprotounitcommands.xml",
         r"data\techtreey.xml", r"Startup\wol.cfg"]
PIE_SRC = r"C:\Users\Jeison\Documents\GitHub\UHC-r1127\tools\pie"
PIE_DIR = r"art\ui\uhc"   # created by apply, removed by restore (the bed has none)


def bank_tags(interval, commands):
    tags = [f"<NurseryFactorInterval>{interval}</NurseryFactorInterval>",
            "<NurseryFactorGrowth>exponential</NurseryFactorGrowth>",
            "<NurseryFactorGrowthBase>2</NurseryFactorGrowthBase>",
            "<NurseryFactorName>minks</NurseryFactorName>",
            "<NurseryFactorRolloverCount>{current} out of {max} minks.</NurseryFactorRolloverCount>",
            "<NurseryFactorRolloverRate>The next step brings {step} minks in {seconds} seconds.</NurseryFactorRolloverRate>",
            '<NurseryFactorGarrisonUnit amount="3">Herdable</NurseryFactorGarrisonUnit>',
            '<NurseryFactorGarrisonUnit amount="1">Settler</NurseryFactorGarrisonUnit>']
    if commands:
        tags += ['<NurseryFactorCommand factor="-4" unit="CrateofCoin" count="2">NurserySellMinks</NurseryFactorCommand>',
                 '<NurseryFactorCommand factor="3" cost="Wood 100, Food 50">NurseryBuyMinks</NurseryFactorCommand>',
                 '<NurseryFactorCommand factor="-1" unit="Settler" count="3">NurserySettlers</NurseryFactorCommand>']
    tags += ["<MaxContained>10</MaxContained>", "<Contain>Herdable</Contain>", "<Contain>AbstractVillager</Contain>"]
    if commands:
        tags += ['<Command column="0" page="0">NurserySellMinks</Command>',
                 '<Command column="1" page="0">NurseryBuyMinks</Command>',
                 '<Command column="2" page="0">NurserySettlers</Command>',
                 '<Command column="3" page="10">Eject</Command>']
    return "".join(f"\t\t{t}\r\n" for t in tags)


GC_TAGS = ('\t\t<GarrisonConvertTo from="Settler" delay="3" eject="true">Pikeman</GarrisonConvertTo>\r\n'
           '\t\t<GarrisonConvertTo from="Settler" delay="3" eject="true">Musketeer</GarrisonConvertTo>\r\n')


def tech(name, dbid, effect):
    return (f"\t<Tech name ='{name}' type ='Normal'>\r\n\t\t<DBID>{dbid}</DBID>\r\n\t\t<DisplayNameID>77154</DisplayNameID>\r\n"
            "\t\t<ResearchPoints>0.0000</ResearchPoints>\r\n\t\t<Status>UNOBTAINABLE</Status>\r\n\t\t<Effects>\r\n"
            f"{effect}\t\t</Effects>\r\n\t</Tech>\r\n")


def proto_effect(subtype, amount, relativity):
    return (f"\t\t\t<Effect type ='Data' amount ='{amount}' subtype ='{subtype}' relativity ='{relativity}'>\r\n"
            "\t\t\t\t<Target type ='ProtoUnit'>Bank</Target></Effect>\r\n")


def ship(consume):
    return ("\t\t\t<Effect type ='Data' amount ='1.00' subtype ='FreeHomeCityUnitByNurseryFactor' unittype ='CrateofCoin' "
            f"nursery ='Bank' consume ='{consume}' relativity ='Absolute'>\r\n\t\t\t\t<Target type ='Player' /></Effect>\r\n")


TECHS = (tech("J27Base", 99911, proto_effect("NurseryFactorGrowthBase", "3.00", "Assign"))
         + tech("J27Max", 99912, proto_effect("NurseryFactorMax", "10.00", "Absolute"))
         + tech("N3TestShip2", 99904, ship("2"))
         + tech("N2TestShip", 99903, ship("all")))


def command(name, icon, rollover):
    return (f"\t<protounitcommand>\r\n\t\t<name>{name}</name>\r\n\t\t<command>nurseryFactorCommand(\"{name}\")</command>\r\n"
            f"\t\t<icon>art\\ui\\command\\{icon}</icon>\r\n\t\t<rollovertextid>{rollover}</rollovertextid>\r\n"
            "\t</protounitcommand>\r\n")


COMMANDS = (command("NurserySellMinks", "trade_sell_food", 19224) + command("NurseryBuyMinks", "trade_buy_food", 19222)
            + command("NurserySettlers", "trade_buy_wood", 19223))
NAMES = ["NurserySellMinks", "NurseryBuyMinks", "NurserySettlers"]


def path(rel):
    return os.path.join(BED, rel)


def read(rel):
    with open(path(rel), "rb") as f:
        return f.read().decode("utf-8")


def write(rel, text):
    with open(path(rel), "wb") as f:
        f.write(text.encode("utf-8"))


def insert_in_unit(proto, name, text, replace=None):
    anchor = f' name="{name}">'
    at = proto.index(anchor)
    at = proto.rindex("<Unit ", 0, at)
    end = proto.index("</Unit>", at)
    block = proto[at:end]
    if replace:
        assert replace[0] in block, replace
        block = block.replace(replace[0], replace[1])
    return proto[:at] + block + text.lstrip("\t") + "\t" + proto[end:]


def apply(mode, extra_cfg):
    for rel in FILES:
        if os.path.exists(path(rel) + SUFFIX):
            sys.exit(f"{rel}{SUFFIX} exists: restore first")
    for rel in FILES:
        shutil.copy2(path(rel), path(rel) + SUFFIX)
    smoke = mode == "smoke"
    proto = read(r"data\protoy.xml")
    proto = insert_in_unit(proto, "Bank", bank_tags(8 if smoke else 20, smoke),
                           ('<Rate type="Gold">2.750000</Rate>', '<Rate type="Gold">0.500000</Rate>'))
    if smoke:
        proto = insert_in_unit(proto, "Blockhouse", GC_TAGS)
    write(r"data\protoy.xml", proto)
    tree = read(r"data\techtreey.xml")
    close = tree.rindex("</TechTree>")
    write(r"data\techtreey.xml", tree[:close] + TECHS + tree[close:])
    if smoke:
        cmds = read(r"data\protounitcommands.xml")
        close = cmds.rindex("</protounitcommands>")
        write(r"data\protounitcommands.xml", cmds[:close] + COMMANDS + cmds[close:])
        names = read(r"data\uhc\customprotounitcommands.xml")
        close = names.rindex("</")
        write(r"data\uhc\customprotounitcommands.xml",
              names[:close] + "".join(f"\t<CommandType>{n}</CommandType>\r\n" for n in NAMES) + names[close:])
        assert not os.path.exists(path(PIE_DIR)), "art\\ui\\uhc exists already"
        os.makedirs(path(PIE_DIR + r"\pie"))
        for name in sorted(os.listdir(PIE_SRC)):
            shutil.copy2(os.path.join(PIE_SRC, name), path(PIE_DIR + r"\pie\\" + name))
    if extra_cfg:
        cfg = read(r"Startup\wol.cfg")
        write(r"Startup\wol.cfg", cfg.rstrip("\r\n") + "\r\n" + "\r\n".join(extra_cfg) + "\r\n")
    print(f"applied ({mode}); cfg +", extra_cfg)


def restore():
    for rel in FILES:
        backup = path(rel) + SUFFIX
        if os.path.exists(backup):
            shutil.copy2(backup, path(rel))
            os.remove(backup)
            print("restored", rel)
    if os.path.exists(path(PIE_DIR)):
        shutil.rmtree(path(PIE_DIR))
        print("removed", PIE_DIR)


if __name__ == "__main__":
    if sys.argv[2] == "apply":
        apply(sys.argv[3], sys.argv[4:])
    else:
        restore()
