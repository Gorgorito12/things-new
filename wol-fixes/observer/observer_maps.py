"""Repairs ESOC's observer panel in the Wars of Liberty random maps that carry it (request #81).

    python -I observer_maps.py apply  <WoL folder> --stock <TAD bin folder> [--switch-only | --ids-only] [--emulate-observer]
    python -I observer_maps.py revert <WoL folder>
    python -I observer_maps.py check  <WoL folder>
    python -I observer_maps.py apply  <WoL folder> --stock <TAD bin folder> --out <folder>   (writes elsewhere)

<WoL folder> is a Wars of Liberty game folder (the one with RM4\\ and data\\). `apply` changes every map of
RM4\\ that carries the panel (the ones that create the trigger StartInsertion: 36 in WoL 1.0.15c) in
place, after keeping the original as <map>.xs.obs-orig (once: a second apply starts again from that
copy); `revert` puts the originals back and removes the copies; `check` says which maps are patched.
With --out the maps are written to that folder and RM4 is left alone.

Step 1, always:
  1. the switch: `if (false == true) {` becomes `if (rmIsObserverMode() == true) {`, so the observer
     branch runs only when the lobby's Observer mode box is ticked (rmIsObserverMode is WoL's uhc.dll);
  2. the map's own trigger helper `kbGetTechID` (a loop over the first 2550 techs) is removed: wolai.upl
     registers a syscall of that name, `int kbGetTechID(string techName)`, so the helper stopped the
     whole trigger script from compiling ("'kbGetTechID' is already defined"); the map's calls now
     reach the syscall, which knows all of WoL's techs.
Step 2, the IDs, unless --switch-only (needs --stock, the folder of a stock Age of Empires III: The
Asian Dynasties, bin\\ with data\\techtreey.xml and data\\protoy.xml, only read):
  ESOC wrote the panel's tables with the numeric IDs of the stock game's techs and protos (ESOC 1.12.2
  uses the stock numbering: 2056 of the 2065 tech rows carry the string ID of the stock tech at that
  index, and the other 9 are the consulate rows labelled on purpose with the intervention string; all
  460 unit rows carry the stock proto of their name). WoL's data has other numbers (10542 techs and 3634
  protos, against 2549 and 1463; none of the 2065 tech rows has the same index in WoL), so the panel
  showed other techs' icons and names and counted other units. The tables become names, looked up when
  the trigger script starts (kbGetTechID for techs, kbGetProtoUnitID for protos):
  - AEU/AMU/AWU/ARU(id,"Name",...): the id becomes -1, so the map's own code asks kbGetProtoUnitID;
  - ITT/ITS(id,string,icon): the stock tech's name goes in the function's fourth argument;
  - ATT/ATTR(type,tech): new functions ATTW/ATTRW with the tech's name, and for a proto type its name
    too (passed as 100000 + its ID, which the panel's UTcorrect now decodes; abstract types keep the
    stock numbering, which UTcorrect already shifts to WoL's and which matches WoL's list);
  - CKSUM(sum,tech) and the shipment checksum lines: the tech by name;
  - cNumAllTechs (the size of the panel's tech arrays and of its research scan): WoL's tech count plus
    room for 1000 more;
  - the population bar counts AbstractVillager and AbstractFishingBoat instead of the stock villager protos
    (none of which is a WoL villager), and the other numbers written in the trigger code for protos
    (kbUnitCount, kbProtoUnitIsType, kbUnitQuerySetUnitType) and techs (kbGetTechPercentComplete, i==N)
    become names;
  - a cEf line whose string grew past 127 characters (the compiler's limit) is cut into several cEf calls.
  A row whose stock name WoL no longer has is commented out (`//obs: not in WoL:`); the counts are
  printed per map.
Step 3, WoL's own data, unless --ids-only (tables generated from WoL's techtreey.xml, protoy.xml and
civs.xml; their hashes go in a comment at the end of each map, and `check` says when the data changed
since, so that apply must run again):
  - each observer's bat by player (rmGetUnitPlacedOfPlayer), at the start and at the end of the game,
    instead of a range of unit IDs assumed to follow each other;
  - the observers' two techs (stock 529 and 446) by name: SPCKillXPTrickle and Spies;
  - stock civ numbers: the view lock (Ottomans) and the shipment bar's XP tables by civs.xml (the
    modifier groups, and a generic curve for the modifiers ESOC had no table for); the rice paddy
    tracker runs for every civ;
  - stock tech ranges and lists to arrays filled by name when the panel loads: the revolutions (every
    RevoltTech tech and its civ, for the flag), the consulate relations an intervention researches,
    the re-researchable consulate techs, the age-up techs (ESOC's list, the AgeUpgrade techs and each
    civ's researched age techs), the tech upgrade pairs;
  - oil: the fourth resource row showed export (resource 7, which WoL's own panel does not show) and
    shows oil (resource 3) with WoL's oil icon; oil counts in the unspent total;
  - the Great War: a player whose civ's Age5 tech (GreatWarButton) is researched shows WoL's age-6
    icon (the Great War leaves the player in the engine's age 4);
  - WoL's own units in the four unit tables (every obtainable proto with a portrait and a name: about
    1,400 rows) and WoL's portraits for the rows ESOC left without one.
  The flags are the observer layout's gadgets Spec_Flag_<pos>_<civ ID>: `flags` prints the ones WoL's
  civs need.
    python -I observer_maps.py flags  <WoL folder>
--emulate-observer (test only, never for players) makes the map's trigger code treat the local player
as an observer (FP = the last slot), which shows the panel to the host of a game on one PC.
Byte-level edits: line endings (CRLF) and encoding are kept.
"""
import hashlib
import pathlib
import re
import sys

MARK = b"StartInsertion"
SWITCH_OLD = b"if (false == true) {"
SWITCH_NEW = b"if (rmIsObserverMode() == true) {"
HELPER = re.compile(rb'[ \t]*cEf\(" int kbGetTechID\(string tkname=\\"\\"\)\{ "\);\r?\n'
                    rb'[ \t]*cEf\(" for \(i=0;<"\+cNumAllTechs\+"\)\{ "\);\r?\n'
                    rb'[ \t]*cEf\(" if\(kbGetTechName\(i\)==tkname\)\{return\(i\);\} "\);\r?\n'
                    rb'[ \t]*cEf\(" \} "\);\r?\n'
                    rb'[ \t]*cEf\(" return\(-1\); "\);\r?\n'
                    rb'[ \t]*cEf\(" \} "\);(\r?\n)')
HELPER_NOTE = b'\t// kbGetTechID: the syscall of wolai.upl (observer_maps.py removed the map\'s own helper)'
EMULATE_OLD = b"FP=trCurrentPlayer(); if(trGetWorldDifficulty()"
EMULATE_NEW = b'FP="+cNumberNonGaiaPlayers+"; if(trGetWorldDifficulty()'  # the last slot, an observer
UTC_OLD = b'cEf(" int UTcorrect(int typeid=0){if(typeid<1463){return(typeid);}return(typeid+UTshift);} ");'
UTC_NEW = (b'cEf(" int UTcorrect(int typeid=0){if(typeid>=100000){return(typeid-100000);} ",'
           b'"if(typeid<1463){return(typeid);}return(typeid+UTshift);} ");')
MAX_LITERAL = 120  # the XS compiler refuses a string literal of 128 characters or more ("Token Error 0006")
NAMED_TYPE_OLD = b'"kbGetUnitTypeID(\\""+unittypenm+"\\"),'
NAMED_TYPE_NEW = b'"100000+kbGetUnitTypeID(\\""+unittypenm+"\\"),'
FUNCS_AT = b"/*[User defined functions end]*/"
FUNCS = b"""//observer_maps.py: the tables by name (WoL's IDs differ from the stock ones the tables were written with)
void ATTW(int unittypeid=0, string protonm="", string technm="", int isteamtech=0){
if(protonm>""){cEf(" ATT("+cNumTrackedTechs+",100000+kbGetProtoUnitID(\\""+protonm+"\\"),kbGetTechID(\\""+technm+"\\"),"+isteamtech+"); ");}
else{cEf(" ATT("+cNumTrackedTechs+","+unittypeid+",kbGetTechID(\\""+technm+"\\"),"+isteamtech+"); ");}
cNumTrackedTechs++;
}
void ATTRW(int unittypeid=0, string protonm="", string technm=""){
if(protonm>""){cEf(" ATTR("+cNumTrackedTechsRemoved+",100000+kbGetProtoUnitID(\\""+protonm+"\\"),kbGetTechID(\\""+technm+"\\")); ");}
else{cEf(" ATTR("+cNumTrackedTechsRemoved+","+unittypeid+",kbGetTechID(\\""+technm+"\\")); ");}
cNumTrackedTechsRemoved++;
}
void CKSUMW(int checksam=0, string technm=""){
cEf(" else if(ciksum=="+checksam+"){xsArraySetInt(array,kbGetTechID(\\""+technm+"\\"),2);} ");
}
"""
STOCK_PROTOS = 1463  # the stock game's proto count: IDs below it are protos, the abstract types follow


def read_xml(path):
    raw = path.read_bytes()
    text = raw.decode("utf-16") if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else raw.decode("utf-8", "replace")
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def names(path, tag):
    """The name of each <Tech> or <Unit> of a data file, in file order (its index is the game's ID)."""
    return re.findall(r"<%s\s[^>]*?name\s*=\s*['\"]([^'\"]+)['\"]" % tag, read_xml(path), flags=re.I)


def records(text, tag):
    """(name, body) of each <Tech name=...> or <Unit name=...> element, in file order."""
    return re.findall(r"<%s\s[^>]*?name\s*=\s*['\"]([^'\"]+)['\"][^>]*>(.*?)</%s>" % (tag, tag), text,
                      flags=re.S | re.I)


def tags(body, tag):
    return [v.strip() for v in re.findall(r"<%s(?:\s[^>]*)?>([^<]*)</%s>" % (tag, tag), body, flags=re.I)]


# The stock civ IDs written as numbers in ESOC's panel (the stock civs.xml in Data3.bar, ID = position + 1).
STOCK_CIVS = {1: "Spanish", 7: "Germans", 8: "Ottomans", 15: "XPIroquois", 16: "XPSioux", 17: "XPAztec",
              19: "Japanese", 20: "Chinese", 21: "Indians"}
DATA_FILES = ("techtreey.xml", "protoy.xml", "civs.xml")


def data_stamp(wol):
    """The short hash of each WoL data file the tables come from, as written at the end of a repaired map."""
    return " ".join(f"{f} {hashlib.sha256((wol / 'data' / f).read_bytes()).hexdigest()[:12]}" for f in DATA_FILES)


class Data:
    def __init__(self, stock, wol):
        self.stock_techs = names(stock / "data" / "techtreey.xml", "Tech")
        self.stock_protos = names(stock / "data" / "protoy.xml", "Unit")
        wol_techs = names(wol / "data" / "techtreey.xml", "Tech")
        self.wol_tech_count = len(wol_techs)
        # lower case -> WoL's own spelling, which goes into the map (the lookups may compare case)
        self.wol_techs = {n.lower(): n for n in wol_techs}
        self.wol_protos = {n.lower(): n for n in names(wol / "data" / "protoy.xml", "Unit")}
        if len(self.stock_techs) != 2549 or len(self.stock_protos) != STOCK_PROTOS:
            sys.exit(f"--stock: {len(self.stock_techs)} techs and {len(self.stock_protos)} protos; "
                     "the stock TAD data has 2549 and 1463")
        self.wol = WolTables(wol)

    def tech(self, tid):
        tid = abs(int(tid))
        return self.stock_techs[tid] if 0 <= tid < len(self.stock_techs) else None

    def wol_tech(self, stock_id):
        """WoL's spelling of the stock tech `stock_id`, or None when WoL has no tech of that name."""
        name = self.tech(stock_id)
        return self.wol_techs.get(name.lower()) if name else None


class WolTables:
    """What the panel needs from WoL's own data: its units, civs, revolutions, age-up and consulate techs."""

    def __init__(self, wol):
        self.stamp = data_stamp(wol)
        tech_text = read_xml(wol / "data" / "techtreey.xml")
        proto_text = read_xml(wol / "data" / "protoy.xml")
        civ_text = read_xml(wol / "data" / "civs.xml")
        self.techs = records(tech_text, "Tech")
        self.tech_names = {n.lower(): n for n, _ in self.techs}
        self.protos = records(proto_text, "Unit")
        # civ ID = position in civs.xml + 1 (0 is Gaia): the stock flags Spec_Flag_<pos>_1 .. _21 follow it
        self.civs = [(i + 1, (tags(b, "name") or [""])[0], b)
                     for i, b in enumerate(re.findall(r"<civ>(.*?)</civ>", civ_text, flags=re.S | re.I))]
        self.civ_ids = {name.lower(): cid for cid, name, _ in self.civs}
        self.obtainable = self._obtainable(proto_text, tech_text, civ_text)

    def civ_id(self, name):
        return self.civ_ids.get(name.lower())

    def main_civs(self):
        return [(cid, name, body) for cid, name, body in self.civs if (tags(body, "main") or ["0"])[0] == "1"]

    @staticmethod
    def _obtainable(proto_text, tech_text, civ_text):
        """The protos a player can get: trained or built (<Train>), shipped or granted by a tech
        (FreeHomeCityUnit*, AddTrain), enabled by a tech, or in a civ's start."""
        got = {x.strip().lower() for x in re.findall(r"<Train[^>]*>([^<]*)</Train>", proto_text, flags=re.I)}
        for m in re.finditer(r"<Effect[^>]*subtype\s*=\s*['\"](?:FreeHomeCityUnit\w*|AddTrain)['\"][^>]*>",
                             tech_text, flags=re.I):
            u = re.search(r"unittype\s*=\s*['\"]([^'\"]+)", m.group(0))
            if u:
                got.add(u.group(1).lower())
        for m in re.finditer(r"<Effect[^>]*subtype\s*=\s*['\"]Enable['\"][^>]*>\s*<Target\s+type\s*=\s*"
                             r"['\"]ProtoUnit['\"]\s*>([^<]*)<", tech_text, flags=re.I):
            got.add(m.group(1).strip().lower())
        got |= {x.strip().lower() for x in re.findall(r"<(?:town)?startingunit[^>]*>([^<]*)<", civ_text, flags=re.I)}
        return got

    # Resources and things that a player does not own, though a tech or card may place them.
    NOT_OWNED = {"huntable", "tree", "abstractfish", "abstractwhale", "abstractfruit", "abstractmine", "mine",
                 "abstractnugget", "nugget"}

    def unit_rows(self, have):
        """ESOC's four unit tables (AEU economic, AMU military, AWU navy, ARU the rest: heroes, armies,
        buildings) extended with every obtainable WoL proto that has a portrait and a name and is not in
        them yet (`have`: lower-case names already in the tables). {kind: [row, ...]}"""
        rows = {"AEU": [], "AMU": [], "AWU": [], "ARU": []}
        for name, body in self.protos:
            if name.lower() in have or name.lower() not in self.obtainable:
                continue
            portrait = (tags(body, "PortraitIcon") or [""])[0]
            sid = (tags(body, "DisplayNameID") or [""])[0]
            if not portrait or not sid.isdigit():
                continue
            types = {t.lower() for t in tags(body, "UnitType")}
            if types & self.NOT_OWNED:
                continue
            if "abstractvillager" in types:
                kind = "AEU"
            elif "hero" in types or "building" in types:
                kind = "ARU"
            elif "ship" in types and ("military" in types or "abstractwarship" in types):
                kind = "AWU"
            elif "military" in types:
                kind = "AMU"
            else:
                kind = "AEU"  # fishing boats, wagons, crates, herds, priests, scouts: as ESOC's table
            rows[kind].append(f'{kind}(-1,"{name}",{sid},"{art_path(portrait)}");')
        return rows

    def portrait(self, name):
        for n, body in self.protos:
            if n.lower() == name.lower():
                return art_path((tags(body, "PortraitIcon") or [""])[0])
        return ""

    def revolutions(self):
        """[(tech, civ ID)] for each tech flagged RevoltTech: the civ is the one named after
        `XPRevolution` (XPRevolutionWOLAlbania -> WOLAlbania); -1 when there is none."""
        out = []
        for name, body in self.techs:
            if "revolttech" in {f.lower() for f in tags(body, "Flag")}:
                civ = self.civ_id(re.sub(r"^XPRevolution", "", name, flags=re.I))
                out.append((name, civ if civ else -1))
        return out

    def consulate_relations(self):
        """The consulate relation techs an intervention card researches (ESOC clears them so that they do
        not show as shipments): every `...ConsulateRelations...` tech that is not the card itself."""
        return [n for n, _ in self.techs if re.search(r"ConsulateRelations", n, flags=re.I)
                and not re.match(r"ypHCConsulateRelations", n, flags=re.I)]

    def age_techs(self, esoc_names):
        """The age-up techs whose progress the panel shows: ESOC's list (by name), every tech flagged
        AgeUpgrade except the wonder `...Disable` techs (the rule ESOC's list follows in the stock data),
        and each civ's researched age techs (civs.xml <agetech>, e.g. GreatWarButton)."""
        out, seen = [], set()

        def add(n):
            real = self.tech_names.get(n.lower())
            if real and real.lower() not in seen:
                seen.add(real.lower())
                out.append(real)
        for n in esoc_names:
            add(n)
        bodies = {n.lower(): b for n, b in self.techs}
        for n, b in self.techs:
            if "ageupgrade" in {f.lower() for f in tags(b, "Flag")} and not n.lower().endswith("disable"):
                add(n)
        for _, _, civ in self.main_civs():
            for t in re.findall(r"<agetech>.*?<tech>([^<]*)</tech>.*?</agetech>", civ, flags=re.S | re.I):
                if re.search(r"<ResearchPoints>", bodies.get(t.strip().lower(), ""), flags=re.I):
                    add(t.strip())
        return out

    def great_war_techs(self):
        """Each main civ's Age5 <agetech> (GreatWarButton): researched, the player is in the Great War."""
        out = []
        for _, _, civ in self.main_civs():
            for age, t in re.findall(r"<agetech>\s*<age>([^<]*)</age>\s*<tech>([^<]*)</tech>", civ, flags=re.I):
                real = self.tech_names.get(t.strip().lower())
                if age.strip().lower() == "age5" and real and real not in out:
                    out.append(real)
        return out

    def shipment_groups(self):
        """ESOC's shipment progress bar has XP tables for four stock modifier groups of civs.xml (Spanish
        0.73, Germans 1.10, Japanese and Chinese 1.001234 with growth, Indians 1.08) and one for the rest
        (1.0). Returns ({group: [civ IDs]}, {modifier: [civ IDs]}) for WoL's main civs; the second holds the
        modifiers ESOC has no table for."""
        groups = {"spanish": [], "german": [], "asian": [], "indian": []}
        other = {}
        for cid, name, body in self.main_civs():
            mod = float((tags(body, "hcshipmentmodifier") or ["1"])[0])
            growth = float((tags(body, "hcshipmentgrowthmodifier") or ["0"])[0])
            if growth > 0:
                groups["asian"].append(cid)
            elif abs(mod - 0.73) < 1e-6:
                groups["spanish"].append(cid)
            elif abs(mod - 1.10) < 1e-6:
                groups["german"].append(cid)
            elif abs(mod - 1.08) < 1e-6:
                groups["indian"].append(cid)
            elif abs(mod - 1.0) > 1e-6:
                other.setdefault(mod, []).append(cid)
        return groups, other

    def flags(self):
        """[(civ ID, civ name, large flag button set)] for the observer layout's Spec_Flag_<pos>_<civ ID>
        gadgets: every main civ with a flag and every revolution civ."""
        rev = {c for _, c in self.revolutions() if c > 0}
        out = []
        for cid, name, body in self.civs:
            main = (tags(body, "main") or ["0"])[0] == "1"
            flag = (tags(body, "homecityflagbuttonsetlarge") or [""])[0]
            if flag and (main or cid in rev):
                out.append((cid, name, flag))
        return out


def art_path(path):
    """An art path as the panel's <icon=..> tags take it: forward slashes, so that XS never reads a
    backslash in it as an escape (`\\n`)."""
    return path.strip().replace("\\", "/")


def remap(text, data, counts):
    """Step 2 on one map's text (str, latin-1 decoded so the bytes round-trip)."""
    def missing(line, why):
        counts["missing"] = counts.get("missing", 0) + 1
        return f"//obs: not in WoL ({why}): {line.strip()}"

    def units(m):
        indent, kind, uid, name, rest = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
        counts["units"] = counts.get("units", 0) + 1
        if name.lower() not in data.wol_protos:
            return indent + missing(m.group(0), name)
        return f'{indent}{kind}(-1,"{data.wol_protos[name.lower()]}"{rest}'
    text = re.sub(r'^([ \t]*)(AEU|AMU|AWU|ARU)\((-?\d+),"([^"]*)"(,[^\r\n]*)', units, text, flags=re.M)

    def techs(m):
        indent, kind, tid, sid, img = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5) or ""
        name = data.tech(tid)
        counts["techs"] = counts.get("techs", 0) + 1
        if not name or name.lower() not in data.wol_techs:
            return indent + missing(m.group(0), name or tid)
        return f'{indent}{kind}(-1,{sid},"{img}","{data.wol_techs[name.lower()]}");'
    text = re.sub(r'^([ \t]*)(ITT|ITS)\((-?\d+),(-?\d+)(?:,"([^"]*)")?\);', techs, text, flags=re.M)

    def tracked(m):
        indent, kind, ut, tid = m.group(1), m.group(2), int(m.group(3)), int(m.group(4))
        name = data.tech(tid)
        counts["tracked"] = counts.get("tracked", 0) + 1
        if not name or name.lower() not in data.wol_techs:
            return indent + missing(m.group(0), name or tid)
        proto = data.stock_protos[ut] if 0 <= ut < STOCK_PROTOS else ""
        if proto and proto.lower() not in data.wol_protos:
            return indent + missing(m.group(0), proto)
        team = ",1" if tid < 0 and kind == "ATT" else ""
        proto = data.wol_protos[proto.lower()] if proto else ""
        return f'{indent}{kind}W({ut if not proto else 0},"{proto}","{data.wol_techs[name.lower()]}"{team});'
    text = re.sub(r'^([ \t]*)(ATT|ATTR)\((-?\d+),(-?\d+)\);', tracked, text, flags=re.M)

    def cksum(m):
        name = data.tech(m.group(3))
        counts["checksums"] = counts.get("checksums", 0) + 1
        if not name or name.lower() not in data.wol_techs:
            return m.group(1) + missing(m.group(0), name or m.group(3))
        return f'{m.group(1)}CKSUMW({m.group(2)},"{data.wol_techs[name.lower()]}");'
    text = re.sub(r'^([ \t]*)CKSUM\((-?\d+),(-?\d+)\);', cksum, text, flags=re.M)

    # The checksum lines written out in the trigger code: xsArraySetInt(array,<tech>,2).
    def literal(m):
        name = data.tech(m.group(1))
        counts["checksums"] = counts.get("checksums", 0) + 1
        if not name or name.lower() not in data.wol_techs:
            counts["missing"] = counts.get("missing", 0) + 1
            return "xsArraySetInt(array,-1,2)"
        return f'xsArraySetInt(array,kbGetTechID(\\"{data.wol_techs[name.lower()]}\\"),2)'
    text = re.sub(r"xsArraySetInt\(array,(\d+),2\)", literal, text)

    # The population bar counts villagers by stock proto IDs (Settler 284, Coureur 379 ...), none of which is
    # a WoL villager (DutchSettler, JavaneseLabourer ...): count the abstract types instead, which UTcorrect
    # already maps to WoL's list (1485 AbstractVillager, 1586 AbstractFishingBoat).
    pop = re.compile(r'^([ \t]*cEf\(" popVil"\+p\+"=popVil"\+p\+"\+)kbUnitCount\((column"\+p\+"player),(\d+),2\)'
                     r'(; "\);)(\r?\n)', re.M)

    def popline(m):
        stock = int(m.group(3))
        if stock in (284, 315):
            abstract = 1485 if stock == 284 else 1586
            counts["pop"] = counts.get("pop", 0) + 1
            return f"{m.group(1)}kbUnitCount({m.group(2)},UTcorrect({abstract}),2){m.group(4)}{m.group(5)}"
        if stock in (379, 517, 721, 928, 1130, 1047, 1109):  # villagers and fishing boats: counted above
            counts["pop"] = counts.get("pop", 0) + 1
            return ""
        return m.group(0)
    text = pop.sub(popline, text)

    # Other stock IDs written as numbers in the trigger code: protos in unit counts and queries, techs in
    # research checks. A name WoL does not have becomes -1 (counts 0, never complete).
    def proto_ref(n):
        name = data.stock_protos[n] if 0 <= n < STOCK_PROTOS else None
        if not name or name.lower() not in data.wol_protos:
            counts["missing"] = counts.get("missing", 0) + 1
            return "-1"
        counts["literals"] = counts.get("literals", 0) + 1
        return f'kbGetProtoUnitID(\\"{data.wol_protos[name.lower()]}\\")'

    def tech_ref(n):
        name = data.tech(n)
        if not name or name.lower() not in data.wol_techs:
            counts["missing"] = counts.get("missing", 0) + 1
            return "-1"
        counts["literals"] = counts.get("literals", 0) + 1
        return f'kbGetTechID(\\"{data.wol_techs[name.lower()]}\\")'
    text = re.sub(r'(kbUnitCount\([^,()]+,)(\d+),', lambda m: m.group(1) + proto_ref(int(m.group(2))) + ",", text)
    text = re.sub(r'(kbProtoUnitIsType\([^,()]+,[^,()]+,)(\d+)\)', lambda m: m.group(1) + proto_ref(int(m.group(2))) + ")", text)
    text = re.sub(r'(kbUnitQuerySetUnitType\([^,()]+,\s*)(\d+)\)', lambda m: m.group(1) + proto_ref(int(m.group(2))) + ")", text)
    text = re.sub(r'kbGetTechPercentComplete\((\d+)\)', lambda m: f"kbGetTechPercentComplete({tech_ref(int(m.group(1)))})", text)
    text = re.sub(r'\bi==(\d{3,4})\b', lambda m: f"i=={tech_ref(int(m.group(1)))}", text)

    text, n = re.subn(r"^int cNumAllTechs=\d+;", f"int cNumAllTechs={data.wol_tech_count + 1000};", text, flags=re.M)
    counts["cNumAllTechs"] = n
    return split_long(text)


def split_long(text):
    """A cEf line whose one string grew past the compiler's limit becomes several cEf calls, cut after a `;`:
    consecutive cEf calls write their code one after the other, so the trigger code is the same."""
    def cut(m):
        indent, body = m.group(1), m.group(2)
        if len(body) <= 127:  # the map's own lines up to 127 compile: left as they are
            return m.group(0)
        pieces, rest = [], body
        while len(rest) > MAX_LITERAL:
            at = rest.rfind(";", 0, MAX_LITERAL) + 1
            if at <= 0:
                raise ValueError(f"cannot cut a long string: {body[:60]}...")
            pieces.append(rest[:at])
            rest = rest[at:]
        pieces.append(rest)
        return "\r\n".join(f'{indent}cEf("{p}");' for p in pieces) if "\r\n" in text else \
            "\n".join(f'{indent}cEf("{p}");' for p in pieces)
    return re.sub(r'^([ \t]*)cEf\("((?:[^"\\\r\n]|\\.)*)"\);[ \t]*(?=\r?$)', cut, text, flags=re.M)


IMPERIAL_AGE = 4  # kbGetAgeForPlayer: 0 Discovery .. 4 Imperial; the Great War leaves the player in age 4
GREAT_WAR_ICON = "WoL/ui/ingame/icon_age_6"  # WoL's own age icon; the stock score_age_1..5 stop at Imperial
OIL = 3  # WoL's fourth resource (oil) is the game's resource 3 (Fame): minimapPanel-fame, {resource(fame)}
TRADE = 7  # the export row ESOC shows fourth; WoL's own resource panel shows oil there and no export


def cef(code, indent="\t"):
    """One cEf line of trigger code (up to three strings joined by `","`); each string must stay under the
    compiler's 128-character limit."""
    for piece in code.split('","'):
        if len(piece) > MAX_LITERAL + 7:
            raise ValueError(f"generated string too long ({len(piece)}): {piece[:60]}...")
    return f'{indent}cEf("{code}");'


def one(pattern, repl, text, what, count=1, flags=re.M):
    """re.subn that insists on `count` matches (None: at least one)."""
    new, n = re.subn(pattern, repl, text, flags=flags)
    if (count is None and n < 1) or (count is not None and n != count):
        raise ValueError(f"{what}: {n} matches, expected {count if count is not None else '1 or more'}")
    return new


def array_init(name, label, values, nl):
    """The trigger lines that create array `name` and fill it with kbGetTechID of each tech name, or
    with plain numbers."""
    size = max(1, len(values))
    lines = [cef(f' {name}=xsArrayCreateInt({size},-1,\\"{label}\\"); ')]
    for k, v in enumerate(values):
        value = f'kbGetTechID(\\"{v}\\")' if isinstance(v, str) else str(v)
        lines.append(cef(f" xsArraySetInt({name},{k},{value}); "))
    return nl.join(lines)


def wolize(text, data, counts):
    """The WoL fixes of the panel code (step 3 of the module doc): fixed stock numbers to WoL's data,
    the observers' bats, oil, the Great War age, WoL's own units."""
    wol = data.wol
    nl = "\r\n" if "\r\n" in text else "\n"

    # 1. The two techs every observer gets: no XP trickle, and Spies (shared LOS).
    def tech_set(m):
        name = data.wol_tech(int(m.group(1)))
        if not name:
            raise ValueError(f"stock tech {m.group(1)} ({data.tech(int(m.group(1)))}) is not in WoL")
        return f'trTechSetStatus("+p+", kbGetTechID(\\"{name}\\"), 2)'
    text = one(r'trTechSetStatus\("\+p\+", (\d+), 2\)', tech_set, text, "observer techs", 2)

    # 2. The observers' bats, by player (rmGetUnitPlacedOfPlayer) rather than as consecutive unit IDs.
    first_last = (r'cEf\(" for\(m="\+rmGetUnitPlaced\(BCOSIMBATMAN,0\)\+";<="\+rmGetUnitPlaced\(BCOSIMBATMAN,'
                  r'rmGetNumberUnitsPlaced\(BCOSIMBATMAN\)-1\)\+"\)\{ "\);\r?\n')
    bat = 'trUnitSelectByID("+rmGetUnitPlacedOfPlayer(BCOSIMBATMAN,obsBatP)+");'

    def start_bats(m):
        i = m.group(1)
        return nl.join([
            f"{i}for(obsBatP=(cNumNonObsPlayers+1);<=cNumberNonGaiaPlayers){{ //observer_maps.py: each observer's own bat",
            f'{i}cEf(" if(kbIsPlayerHuman("+obsBatP+")){{{bat}",'
            f'"trUnitChangeProtoUnit(\\"Target\\");trUnitSelectClear();}} ");',
            f'{i}cEf(" else{{{bat}","trUnitChangeProtoUnit(\\"CinematicBlock\\");trUnitSelectClear();}} ");',
            f"{i}}}"]) + m.group(2)
    text = one(r'^([ \t]*)' + first_last +
               r'[ \t]*cEf\(" if\(kbIsPlayerHuman\(m-"\+rmGetUnitPlaced\(BCOSIMBATMAN,0\)\+"\+"\+cNumNonObsPlayers\+"\+1\)\)\{ "\);\r?\n'
               r'[ \t]*cEf\(" trUnitSelectByID\(m\);trUnitChangeProtoUnit\(\\"Target\\"\);trUnitSelectClear\(\); "\);\r?\n'
               r'[ \t]*cEf\(" \} "\);\r?\n[ \t]*cEf\(" else\{ "\);\r?\n'
               r'[ \t]*cEf\(" trUnitSelectByID\(m\);trUnitChangeProtoUnit\(\\"CinematicBlock\\"\);trUnitSelectClear\(\); "\);\r?\n'
               r'[ \t]*cEf\(" \} "\);\r?\n[ \t]*cEf\(" \} "\);(\r?\n)', start_bats, text, "observer bats at the start")

    def end_bats(m):
        i = m.group(1)
        return nl.join([
            f"{i}for(obsBatP=(cNumNonObsPlayers+1);<=cNumberNonGaiaPlayers){{ //observer_maps.py: each observer's own bat",
            f'{i}cEf(" {bat}","trUnitChangeProtoUnit(\\"CinematicBlock\\");trUnitSelectClear(); ");',
            f"{i}}}"]) + m.group(2)
    text = one(r'^([ \t]*)' + first_last +
               r'[ \t]*cEf\(" trUnitSelectByID\(m\);trUnitChangeProtoUnit\(\\"CinematicBlock\\"\);trUnitSelectClear\(\); "\);\r?\n'
               r'[ \t]*cEf\(" \} "\);(\r?\n)', end_bats, text, "observer bats at the end")

    # 3. Stock civ numbers. The view lock is for an observer playing the Ottomans (stock civ 8).
    ottomans = wol.civ_id(STOCK_CIVS[8])
    text = one(r'(rmGetPlayerCiv\(cNumNonObsPlayers\+1\)==)8(\)\{cAllowViewLock=1;\}\}[^\r\n]*)',
               lambda m: f"{m.group(1)}{ottomans if ottomans else -1}{m.group(2)} //observer_maps.py: "
                         f"{STOCK_CIVS[8]} in WoL's civs.xml", text, "view lock civ")
    # The rice paddy tracker ran only for the three stock Asian civs (19-21); WoL has more civs with paddies
    # (ypRicePaddy), so it always runs: two unit queries per player every 2 s.
    text = one(r'if\(InI\(rmGetPlayerCiv\(p\),19,21\)\)\{', "if(true){ //observer_maps.py: any civ may build paddies",
               text, "rice paddy civs")

    # 4. Revolutions: the stock techs 1531-1538 and flags 53-60 (tech - 1478) become WoL's RevoltTech
    # techs and their civs; the flag that goes is the player's civ at the start.
    revs = wol.revolutions()
    text = one(r'if\(InI\(i,1531,1538\)\)\{handleRevolt\(i,', "if(obsRevCiv(i)>0){handleRevolt(i,", text,
               "revolution check")
    text = one(r'cEf\(" xsSetContextPlayer\(plyr\); myciv=kbGetCiv\(\); "\);',
               'cEf(" myciv=xsArrayGetInt(OBPCIV,plyr); ");', text, "revolution start civ")
    text = one(r'\(tID-1478\)', "obsRevCiv(tID)", text, "revolution flag")
    text = one(r'cEf\(" for\(d=1531;<=1538\)\{ "\);(\r?\n[ \t]*)cEf\(" if\(kbGetTechPercentComplete\(d\)==1\)',
               lambda m: f'cEf(" for(d=0;<{max(1, len(revs))}){{ ");{m.group(1)}'
                         f'cEf(" if(kbGetTechPercentComplete(xsArrayGetInt(OBREV,d))==1)', text, "hasRevolted")

    # 5. Consulate relations cleared after an intervention card (stock 196-203 and 2451).
    cons = wol.consulate_relations()
    text = one(r'for\(k=196;<204\)\{xsArraySetInt\(C1P"\+p\+",k,0\);\}',
               f'for(k=0;<{max(1, len(cons))}){{xsArraySetInt(C1P"+p+",xsArrayGetInt(OBCON,k),0);}}', text,
               "consulate relations")
    text = one(r'^[ \t]*cEf\(" [ \t]*xsArraySetInt\(C1P"\+p\+",2451,0\); "\);\r?\n', "", text, "consulate 2451")

    # 6. canReResearch: the consulate techs that can be researched again, by name.
    m = re.search(r'(cEf\(" bool canReResearch\(int i=0\)\{ "\);)(.*?)(\r?\n[ \t]*cEf\(" return\(false\); "\);)',
                  text, flags=re.S)
    if not m:
        raise ValueError("canReResearch not found")
    rr = re.findall(r'kbGetTechID\(\\"([^"\\]+)\\"\)', m.group(2))
    for a, b in re.findall(r"InI\(i,(\d+),(\d+)\)", m.group(2)):
        rr += [n for n in (data.wol_tech(k) for k in range(int(a), int(b) + 1)) if n]
    text = text[:m.start(2)] + nl + cef(f" for(k=0;<{max(1, len(rr))}){{if(xsArrayGetInt(OBRR,k)==i){{return(true);}}}} ") \
        + text[m.end(2):]

    # 7. The age-up techs whose progress is shown (stock numbers in RMS loops), by name.
    m = re.search(r'^for\(k=522; <= 528\)\{AgeUpPCT\(k\);\}.*?AgeUpPCT\(2544\);[ \t]*\r?\n', text, flags=re.M | re.S)
    if not m:
        raise ValueError("the age-up list not found")
    esoc_ages = set()
    for a, b in re.findall(r"for\(k=(\d+); <= (\d+)\)", m.group(0)):
        esoc_ages |= set(range(int(a), int(b) + 1))
    esoc_ages |= {int(x) for x in re.findall(r"AgeUpPCT\((\d+)\)", m.group(0))}
    ages = wol.age_techs([data.tech(k) for k in sorted(esoc_ages) if data.tech(k)])
    text = text[:m.start()] + cef(
        f' for(k=0;<{max(1, len(ages))}){{if(InI(kbGetTechPercentComplete(xsArrayGetInt(OBAGE,k)),0.01,0.99))","'
        '{setAgeUpPCT(plyr,100*kbGetTechPercentComplete(xsArrayGetInt(OBAGE,k)));break;}} ') + nl + text[m.end():]

    # 8. isPROGRESSION: the tech upgrade pairs, by name.
    m = re.search(r'(cEf\(" int isPROGRESSION\(int new=-1, int old=-1\)\{ "\);)(.*?)(\r?\n[ \t]*cEf\(" return\(0\); "\);)',
                  text, flags=re.S)
    if not m:
        raise ValueError("isPROGRESSION not found")
    pairs = []
    for a, b in re.findall(r"new==(\d+) && old==(\d+)", m.group(2)):
        na, nb = data.wol_tech(int(a)), data.wol_tech(int(b))
        if na and nb:
            pairs.append((na, nb))
    counts["progression pairs"] = len(pairs)
    text = text[:m.start(2)] + nl + cef(
        f" for(k=0;<{max(1, len(pairs))}){{if(xsArrayGetInt(OBPN,k)==new){{if(xsArrayGetInt(OBPO,k)==old)"
        "{return(1);}}} ") + text[m.end(2):]

    # 9. The shipment progress bar's XP tables, by civs.xml's shipment modifiers.
    groups, other = wol.shipment_groups()

    def cond(ids):
        return "||".join(f"civ=={c}" for c in ids) or "civ==-1"
    text = one(r'cEf\(" if\(civ==1\)\{ "\);', f'cEf(" if({cond(groups["spanish"])}){{ ");', text, "SHP Spanish")
    text = one(r'cEf\(" else if\(civ==7\)\{ "\);', f'cEf(" else if({cond(groups["german"])}){{ ");', text, "SHP German")
    text = one(r'cEf\(" else if\(civ==19 \|\| civ==20\)\{ "\);', f'cEf(" else if({cond(groups["asian"])}){{ ");',
               text, "SHP Asian")
    text = one(r'cEf\(" else if\(civ==21\)\{ "\);', f'cEf(" else if({cond(groups["indian"])}){{ ");', text, "SHP Indian")
    extra = "".join(cef(f" else if({cond(ids)}){{perc=obsSHPgen(XP,{mod:g});}} ") + nl for mod, ids in sorted(other.items()))
    text = one(r'(//Others\r?\n)([ \t]*cEf\(" else \{ "\);)', lambda m: m.group(1) + extra + m.group(2), text,
               "SHP others")

    # 10. Oil: the fourth resource row showed export (resource 7, which WoL's own panel does not show);
    # it shows oil (resource 3) with WoL's oil icon, in all four display modes, and oil counts in the
    # unspent total.
    text = one(r'kbResourceGet\(%d\)' % TRADE, f"kbResourceGet({OIL})", text, "oil now", None)
    text = one(r'kbTotalResourceGet\(%d\)' % TRADE, f"kbTotalResourceGet({OIL})", text, "oil total", None)
    text = one(r'kbUnitCostPerResource\(ldeadunitid,%d\)' % TRADE, f"kbUnitCostPerResource(ldeadunitid,{OIL})",
               text, "oil dead cost")
    text = one(r'\\"resource_trade\\"', '\\"resource_fame\\"', text, "oil icon", None)
    text = one(r'temptotal=kbResourceGet\(0\)\+kbResourceGet\(1\)\+kbResourceGet\(2\);',
               f"temptotal=kbResourceGet(0)+kbResourceGet(1)+kbResourceGet(2)+kbResourceGet({OIL});", text,
               "unspent total")

    # 11. The Great War age icon. The Great War is not an engine age (no tech sets Age5: the player stays in
    # age 4, Imperial); it is each civ's Age5 <agetech> of civs.xml (GreatWarButton) once researched.
    gw_techs = wol.great_war_techs()
    text = one(r'SC\(16,\\"score_age_\\"\+\(curAge\+1\)\)\+popInfo\((\w+)\)', r"obsAgeIcon(curAge,\1)+popInfo(\1)",
               text, "age icon", 3)

    # 12. WoL's own units in the four unit tables, and WoL's portraits for the rows ESOC left without one.
    have = {n.lower() for n in re.findall(r'^[ \t]*(?:AEU|AMU|AWU|ARU)\(-?\d+,"([^"]*)"', text, flags=re.M)}

    def fill(m):
        art = wol.portrait(m.group(2))
        return f'{m.group(1)}"{m.group(2)}",{m.group(3)},"{art}");' if art else m.group(0)
    text = re.sub(r'^([ \t]*(?:AEU|AMU|AWU|ARU)\(-?\d+,)"([^"]*)",(\d+),""\);', fill, text, flags=re.M)
    rows = wol.unit_rows(have)
    for kind in ("AEU", "AMU", "AWU", "ARU"):
        last = None
        for last in re.finditer(r'^[ \t]*(?://obs: not in WoL[^\r\n]*?: )?%s\([^\r\n]*\r?\n' % kind, text, flags=re.M):
            pass
        if not last:
            raise ValueError(f"no {kind} rows")
        block = "".join(f"{r}{nl}" for r in rows[kind])
        text = text[:last.end()] + block + text[last.end():]
        counts[f"wol {kind}"] = len(rows[kind])

    # 13. The helpers and arrays, declared with the panel's other globals and filled when it loads.
    gw = f'\\"<icon=16({GREAT_WAR_ICON})>\\"'
    helpers = [
        f"//observer_maps.py: WoL's tables, generated from its data ({wol.stamp})",
        cef(" int OBREV=-1; int OBREVC=-1; int OBCON=-1; int OBRR=-1; int OBAGE=-1; int OBPN=-1; int OBPO=-1; "),
        cef(" int OBPCIV=-1; int OBGW=-1; "),
        cef(f' int obsRevCiv(int t=-1){{if(t<0){{return(-1);}} for(k=0;<{max(1, len(revs))}){{","'
            'if(xsArrayGetInt(OBREV,k)==t){return(xsArrayGetInt(OBREVC,k));}} return(-1);} '),
        cef(f' string obsAgeIcon(int a=0, int p=-1){{if(a>={IMPERIAL_AGE}){{xsSetContextPlayer(p); ","'
            f'for(k=0;<{max(1, len(gw_techs))}){{if(kbGetTechPercentComplete(xsArrayGetInt(OBGW,k))==1)'
            f'{{return({gw});}}}}}} '),
        cef(' return(\\"<icon=16(ui/ingame/score_age_\\"+(a+1)+\\")>\\");} '),
        cef(' int obsSHPgen(float XP=0, float m=1){float need=300.0*m; float at=0; int r=0; for(n=0;<300){","'
            'if(XP<(at+need)){r=100*(XP-at)/need; return(r);} '),
        cef(" at=at+need; need=need*1.15; if(need>2500){need=2500;}} return(0);} "),
        cef(" void obsInitWoL(int wtv=-1){ "),
        array_init("OBREV", "obsRev", [n for n, _ in revs], nl),
        array_init("OBREVC", "obsRevCiv", [c for _, c in revs], nl),
        array_init("OBCON", "obsConsulate", cons, nl),
        array_init("OBRR", "obsReResearch", rr, nl),
        array_init("OBAGE", "obsAgeUps", ages, nl),
        array_init("OBPN", "obsProgNew", [a for a, _ in pairs], nl),
        array_init("OBPO", "obsProgOld", [b for _, b in pairs], nl),
        array_init("OBGW", "obsGreatWar", gw_techs, nl),
        cef(' OBPCIV=xsArrayCreateInt(9,-1,\\"obsPlayerCiv\\"); '),
        "for(obsCivP=1;<=cNumberNonGaiaPlayers){"
        'cEf(" xsArraySetInt(OBPCIV,"+obsCivP+","+rmGetPlayerCiv(obsCivP)+"); ");}',
        cef(" } "),
    ]
    text = one(r'^([ \t]*cEf\(" int UTshift=0; "\);[^\r\n]*\r?\n)', lambda m: m.group(1) + nl.join(helpers) + nl,
               text, "panel globals")
    text = one(r'^([ \t]*)(cEf\(" loadTPs\(\); loadprotoarrays\(\);)', lambda m: cef(" obsInitWoL(); ", m.group(1))
               + nl + m.group(1) + m.group(2), text, "panel loader")
    counts.update({"revolutions": len(revs), "consulate": len(cons), "re-research": len(rr), "age-ups": len(ages)})
    return text + f"{nl}// observer_maps.py tables: {wol.stamp}{nl}"


def patch(data_bytes, data, emulate, counts, wol_step=True):
    out = data_bytes.replace(SWITCH_OLD, SWITCH_NEW)
    out, n = HELPER.subn(lambda m: HELPER_NOTE + m.group(1), out)
    counts["helper"] = n
    if emulate:
        if out.count(EMULATE_OLD) != 1:
            raise ValueError("the observer test line was not found")
        out = out.replace(EMULATE_OLD, EMULATE_NEW)
    if data is not None:
        if out.count(UTC_OLD) != 1 or out.count(FUNCS_AT) != 1:
            raise ValueError("UTcorrect or the end of the user functions was not found")
        out = out.replace(UTC_OLD, UTC_NEW)
        # ATT/ATTR rows given by type name get WoL's runtime ID from kbGetUnitTypeID: mark it for UTcorrect
        # too, which would otherwise shift an abstract type a second time.
        out = out.replace(NAMED_TYPE_OLD, NAMED_TYPE_NEW)
        newline = b"\r\n" if b"\r\n" in out else b"\n"
        out = out.replace(FUNCS_AT, FUNCS.replace(b"\n", newline) + FUNCS_AT)
        text = remap(out.decode("latin-1"), data, counts)
        if wol_step:
            text = split_long(wolize(text, data, counts))
        out = text.encode("latin-1")
    return out


def observer_maps(rm4):
    for path in sorted(rm4.glob("*.xs")):
        orig = path.with_name(path.name + ".obs-orig")
        source = orig if orig.exists() else path
        raw = source.read_bytes()
        if raw.count(SWITCH_OLD) == 1 and MARK in raw:
            yield path, orig, raw


STAMP = re.compile(rb"// observer_maps\.py tables: ([^\r\n]*)")


def print_flags(wol):
    """The flag gadgets the observer layout needs for WoL's civs (step 3 of the module doc)."""
    tables = WolTables(wol)
    rows = tables.flags()
    print(f"# {len(rows)} civs; the layout needs Spec_Flag_<pos>_<civ ID> for pos 0-5, each a stateButton with "
          "usebuttonset = the civ's homecityflagbuttonsetlarge")
    print("# civ ID, civ name, button set")
    for cid, name, flag in rows:
        print(f"{cid}\t{name}\t{flag}")


def main(argv):
    if len(argv) < 2 or argv[0] not in ("apply", "revert", "check", "flags"):
        sys.exit(__doc__)
    cmd, wol = argv[0], pathlib.Path(argv[1])
    if cmd == "flags":
        print_flags(wol)
        return
    rm4 = wol / "RM4"
    if not rm4.is_dir():
        sys.exit(f"{rm4} is not a folder")
    if "steamapps" in str(wol.resolve()).lower() and "--out" not in argv and cmd != "check":
        print("note: this is a Steam folder; make sure you mean to change it")
    maps = list(observer_maps(rm4))
    if cmd == "check":
        stamp, stale = data_stamp(wol), 0
        for path, orig, raw in maps:
            now = path.read_bytes()
            state = "original" if now == raw and not orig.exists() else \
                "patched" if SWITCH_NEW in now else "changed by hand?"
            m = STAMP.search(now)
            if m and m.group(1).decode("latin-1") != stamp:
                state += ", TABLES OUT OF DATE (WoL's data changed since apply: run apply again)"
                stale += 1
            elif state == "patched" and not m:
                state += " (steps 1-2 only, without WoL's tables)"
            print(f"{path.name}: {state}")
        print(f"{len(maps)} maps carry the observer panel" +
              (f"; {stale} have tables from older data ({stamp} now)" if stale else ""))
        return
    if cmd == "revert":
        n = 0
        for path, orig, raw in maps:
            if orig.exists():
                path.write_bytes(raw)
                orig.unlink()
                n += 1
        print(f"{n} maps restored")
        return
    switch_only = "--switch-only" in argv
    data = None
    if not switch_only:
        if "--stock" not in argv:
            sys.exit("apply needs --stock <TAD bin folder> (or --switch-only)")
        data = Data(pathlib.Path(argv[argv.index("--stock") + 1]), wol)
    out_dir = pathlib.Path(argv[argv.index("--out") + 1]) if "--out" in argv else None
    if out_dir:
        out_dir.mkdir(parents=True, exist_ok=True)
    total = 0
    for path, orig, raw in maps:
        counts = {}
        try:
            new = patch(raw, data, "--emulate-observer" in argv, counts, "--ids-only" not in argv)
        except ValueError as e:
            print(f"{path.name}: skipped, {e}")
            continue
        if out_dir:
            (out_dir / path.name).write_bytes(new)
        else:
            if not orig.exists():
                orig.write_bytes(raw)
            path.write_bytes(new)
        total += 1
        print(f"{path.name}: switch, helper removed ({counts.get('helper')})"
              + ("" if switch_only else f", {counts.get('units', 0)} unit rows, {counts.get('techs', 0)} tech rows, "
                 f"{counts.get('tracked', 0)} tracked techs, {counts.get('checksums', 0)} checksums, "
                 f"{counts.get('missing', 0)} rows not in WoL, cNumAllTechs {'set' if counts.get('cNumAllTechs') else 'NOT FOUND'}")
              + ("" if switch_only or "--ids-only" in argv else
                 f"; WoL: {sum(counts.get('wol ' + k, 0) for k in ('AEU', 'AMU', 'AWU', 'ARU'))} unit rows added "
                 f"({', '.join(str(counts.get('wol ' + k, 0)) + ' ' + k for k in ('AEU', 'AMU', 'AWU', 'ARU'))}), "
                 f"{counts.get('age-ups')} age-ups, {counts.get('revolutions')} revolutions, "
                 f"{counts.get('consulate')} consulate relations, {counts.get('re-research')} re-researchable, "
                 f"{counts.get('progression pairs')} upgrade pairs")
              + (", local player as observer (TEST ONLY)" if "--emulate-observer" in argv else ""))
    print(f"{total} maps written" + (f" to {out_dir}" if out_dir else " in place (originals kept as *.xs.obs-orig)"))


if __name__ == "__main__":
    main(sys.argv[1:])
