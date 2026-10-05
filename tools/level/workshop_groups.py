"""What a district's workshop (workshop.py) holds: its buildings, each as
the level places it (its pieces moved so the building stands round its own
middle, its foot at 0) and the kit pieces it is the home of (each piece
homed once, in the first building that uses it: its colliders are edited
there). Pure Python, no Blender.

    harbour   the layout's own buildings, found by which of its functions
              placed each piece (the customs house is shipyard._customs')
    old_town  one house of each family and quirk, the key buildings, the
              Carmo strung along its axis, the scaffolds, one of each kind
              of terrace, vault and street piece, then three street samples
              cut from the layout round a scaffold, the tavern and a
              Judiaria cistern (homes for what else they use)

A group: {"name", "placed": [{"name", "piece", "position", "basis"}],
"kit": [piece], "origin": [x, y, z] (the level's point at the building's
middle), "context": [terrain names, shown from the level's .blend],
"note"}.
"""

import importlib
import inspect
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

import geo  # noqa: E402
import kit_carmo  # noqa: E402
import kit_recipes  # noqa: E402

HOUSE_PREFIXES = ("town_porto_", "town_pombal_", "town_patio_")
# Pieces laid in a row stand this far apart (m).
ROW_GAP = 4.0

# The harbour's buildings: the layout functions whose pieces each holds (a
# piece goes to the first whose function is in its chain of callers), a
# test of the piece where one function lays several, the swept ground shown
# with it. Groups with no functions hold only kit rows.
HARBOUR = [
    ("Customs house", ["shipyard:_customs"], None, [], "Lisbon-Manueline customs house: hall, store, office, loggia, tower."),
    ("Shipyard naves", ["shipyard:_naves", "shipyard:_yard_work", "shipyard:_rope_yard"], None, [],
     "Ribeira das Naus: the vaulted naves, the slipway and the yard's work."),
    ("Golden tower (lighthouse)", ["mole:lay"], lambda p: p.startswith("gold_stage_"), [],
     "The golden tower on the mole's head, in its three stages (the beacon's brazier burns on its top)."),
    ("Mole", ["mole:lay"], None, ["mole_body"], "The mole's head, steps, riprap, the harbour chain and its rings. "
     "The mole's body is swept ground: edit it in city_harbour.blend."),
    ("Sea fort", ["fort:lay"], None, [], "The fort on its bastion, its tower and domed turrets."),
    ("Causeway and bridge", ["spit:lay"], None, ["spit_causeway"],
     "The bridge's posts. The causeway and bridge are swept ground: edit them in city_harbour.blend."),
    ("Terreiro and the Sea Gate", ["terreiro:lay"], None, [], "The square's arcades, the Sea Gate and its drum towers, the Cais das Colunas."),
    ("Ribeira houses", ["ribeira:lay"], None, [], "The Ribeira's casas, arcade and granite flights."),
    ("City walls and the Nasrid gate", ["__init__:wall_run", "shipyard:_walls"], None, [], "The city wall's runs, corners, postern, stair and the Nasrid gate."),
    ("Quays", ["quays:lay"], None, [], "The quays, their steps and bollards."),
    ("Ships", ["ships:lay"], None, [], "The carrack (and its great cabin), the caravel and the boats."),
    ("Smugglers' cave", ["cave:lay"], None, ["smugglers_cave", "cave_mouth", "cave_lintel", "cave_beach", "blowhole_shaft"],
     "The cave's boards and stores. The cave itself is ground: edit it in city_harbour.blend."),
    ("Coast: rocks, plants and life", ["coast:"], None, [], "Scattered along the shore: the kit pieces only."),
    ("Paving and the rest", [""], None, [], "Floors and everything else the harbour uses."),
]
# Shown as kit rows only (scattered over the whole level).
ROWS_ONLY = ("Coast: rocks, plants and life", "Paving and the rest")

# The old town's key buildings, made by hand.
KEY_BUILDINGS = ["tavern", "watch_house", "merchant_house", "town_chapel", "landmark_tower", "garden_house", "upper_gate", "tannery",
                 "stair_tower_180", "stair_tower_215", "stair_tower_243", "stair_tower_265", "stair_tower_270", "stair_tower_335"]
# Kinds of terrace and street piece whose sizes are made to order (one of
# each kind is shown: the rest are in the street samples, or the level).
TERRACE_FAMILIES = ("wall", "stair")
UNDER_FAMILIES = ("vault",)


def _chain():
    """The layout functions (module:function) calling now, innermost first."""
    out = []

    for frame in inspect.stack()[2:]:
        if os.sep + "layouts" + os.sep in frame.filename and not frame.filename.endswith("lay.py"):
            out.append("%s:%s" % (os.path.splitext(os.path.basename(frame.filename))[0], frame.function))

    return out


def traced(level):
    """The level's layout data, and each placed piece's chain of layout
    functions (by its record's id)."""
    import lay

    chains = {}
    original = lay.Layout.put

    def put(self, piece, *args, **kwargs):
        name = original(self, piece, *args, **kwargs)
        record = self.pieces[-1]
        chains[id(record)] = (record, _chain())
        return name

    lay.Layout.put = put

    try:
        data = importlib.import_module(level).layout()
    finally:
        lay.Layout.put = original

    return data, {k: v[1] for k, v in chains.items()}


def _centred(placed):
    """Pieces moved to stand round their middle (x, z) with their foot at 0;
    and the level's point that went to the origin."""
    if not placed:
        return [], [0.0, 0.0, 0.0]

    xs = [p["position"][0] for p in placed]
    zs = [p["position"][2] for p in placed]
    origin = [(min(xs) + max(xs)) / 2.0, min(p["position"][1] for p in placed), (min(zs) + max(zs)) / 2.0]
    return [dict(p, position=geo.sub(p["position"], origin)) for p in placed], origin


def _row(pieces, prefix=""):
    """Pieces stood side by side along x, each its own width apart."""
    out, x = [], 0.0

    for i, piece in enumerate(pieces):
        width = (kit_recipes.PIECES[piece].get("size") or [2.0, 2.0, 2.0])[0]
        x += width / 2.0
        out.append({"name": "%s%s" % (prefix, piece), "piece": piece, "position": [x, 0.0, 0.0], "basis": geo.IDENTITY})
        x += width / 2.0 + ROW_GAP

    return out


def _group(name, placed, homes, note, context=(), extra_kit=()):
    """A group of `placed` (and `extra_kit` shown only in its rows): its kit
    the pieces not yet homed, in the order first used."""
    placed, origin = _centred(placed)
    kit = []

    for piece in [p["piece"] for p in placed] + list(extra_kit):
        if piece not in homes:
            homes.add(piece)
            kit.append(piece)

    return {"name": name, "placed": placed, "kit": kit, "origin": origin, "context": list(context), "note": note}


def harbour():
    data, chains = traced("city_harbour")
    members = {name: [] for name, *_ in HARBOUR}

    def depth(chain, functions):
        """How far out the innermost of `functions` calls (None: not at all)."""
        for i, c in enumerate(chain):
            if any(c == f or (f.endswith(":") and c.startswith(f)) for f in functions if f):
                return i

        return len(chain) if "" in functions else None

    # (A piece belongs to the building whose function placed it most
    # directly: a wall run the Terreiro asks for is the walls'.)
    for p in data["pieces"]:
        chain = chains.get(id(p), [])
        best = None

        for order, (name, functions, test, _, _) in enumerate(HARBOUR):
            d = depth(chain, functions)

            if d is not None and (test is None or test(p["piece"])) and (best is None or (d, order) < best[0]):
                best = ((d, order), name)

        members[best[1]].append(p)

    groups, homes = [], set()

    for name, _, _, context, note in HARBOUR:
        mine = members[name]

        if name in ROWS_ONLY:
            group = _group(name, [], homes, note, context, extra_kit=list(dict.fromkeys(p["piece"] for p in mine)))
        else:
            group = _group(name, mine, homes, note, context)

        if group["placed"] or group["kit"]:
            groups.append(group)

    return groups


def house_style(piece):
    """A generated house's (family, quirk): town_porto_45x22_s3_jetty_e2_467b78
    is ("porto", "jetty")."""
    family, rest = piece[len("town_"):].split("_", 1)
    words = rest.split("_")[2:-1]
    return family, "_".join(w for w in words if not re.fullmatch(r"e\d+", w))


def _house_reps():
    """One house of each family and quirk: an enterable one if there is
    one, then the one nearest the middle width."""
    styles = {}

    for name in sorted(kit_recipes.PIECES):
        if name.startswith(HOUSE_PREFIXES):
            styles.setdefault(house_style(name), []).append(name)

    reps = []

    for style in sorted(styles):
        names = styles[style]
        widths = sorted(kit_recipes.PIECES[n]["size"][0] for n in names)
        middle = widths[len(widths) // 2]
        reps.append(min(names, key=lambda n: (not re.search(r"_e\d+_", n), abs(kit_recipes.PIECES[n]["size"][0] - middle), n)))

    return reps


def kind(piece):
    """A made-to-order piece's kind: retaining_250_50 is "retaining"."""
    return re.split(r"_\d", piece, maxsplit=1)[0]


def _one_of_each_kind(pieces):
    seen = {}

    for piece in pieces:
        seen.setdefault(kind(piece), piece)

    return list(seen.values())


def _carmo():
    """The Carmo strung along its axis as its kit says (the front at z 0,
    the church going -z: four bays, the transept, the apse; five flying
    buttresses down its +x side) until its quarter's layout lays it."""
    placed, z = [], 0.0

    for piece, length in (("carmo_front", kit_carmo.FRONT), ("carmo_bay_whole", kit_carmo.BAY), ("carmo_bay_broken", kit_carmo.BAY),
                          ("carmo_bay_broken", kit_carmo.BAY), ("carmo_bay_whole", kit_carmo.BAY), ("carmo_transept", kit_carmo.BAY),
                          ("carmo_apse", kit_carmo.APSE)):
        placed.append({"name": "%s.%03d" % (piece, len(placed) + 1), "piece": piece, "position": [0.0, 0.0, z], "basis": geo.IDENTITY})
        z -= length

    span = kit_carmo.BUTTRESS[3]

    for i in range(5):
        at = [kit_carmo.PIER_X + span, 0.0, -(kit_carmo.FRONT + (i + 1) * kit_carmo.BAY)]
        placed.append({"name": "carmo_buttress.%03d" % (i + 1), "piece": "carmo_buttress", "position": at, "basis": geo.IDENTITY})

    return placed


def _near(pieces, centre, radius):
    return [p for p in pieces if abs(p["position"][0] - centre[0]) <= radius and abs(p["position"][2] - centre[2]) <= radius]


def old_town():
    data, _ = traced("old_town")
    placed = data["pieces"]
    used = list(dict.fromkeys(p["piece"] for p in placed))
    groups, homes = [], set()
    families = {n: kit_recipes.PIECES[n]["family"] for n in used}

    groups.append(_group("House styles", _row(_house_reps()), homes,
                         "One house of each family (Porto, Pombaline, patio) and quirk. Every lot's house is its own piece: "
                         "an edit here changes this one design (and every lot built to it)."))
    groups.append(_group("Key buildings", _row(KEY_BUILDINGS), homes, "The old town's buildings made by hand, and the stair towers."))
    groups.append(_group("The Carmo", _carmo(), homes, "The roofless Carmo, strung along its axis (its quarter lays it in Task 17)."))
    scaffolds = [n for n in kit_recipes.PIECES if n.startswith("scaffold_")]
    groups.append(_group("Buildings being built", _row(scaffolds), homes, "The scaffolds of the houses going up after the fire."))
    street = [n for n in kit_recipes.PIECES if kit_recipes.PIECES[n]["family"] == "street" and n not in homes]
    groups.append(_group("Street pieces", _row(street), homes, "Lamps, shrines, the comet's and the king's panels, fountains."))
    terraces = _one_of_each_kind(sorted(n for n in used if families[n] in TERRACE_FAMILIES and n not in homes))
    groups.append(_group("Terraces, stairs and walls", _row(terraces), homes,
                         "One of each kind: each length and height is its own piece (the rest are in the street samples)."))
    under = _one_of_each_kind(sorted(n for n in used if families[n] in UNDER_FAMILIES and n not in homes))
    groups.append(_group("Under the streets", _row(under), homes, "Vaults, the sewer, cisterns, streams and their hatches: one of each kind."))
    dressing = [n for n in used if families[n] in ("dressing", "floor") and n not in homes]
    groups.append(_group("Gardens and paving", _row(dressing), homes, "Trees, hedges and the paving."))

    def first(piece):
        return next(p for p in placed if p["piece"] == piece)["position"]

    def cistern():
        return next(p for p in placed if p["piece"].startswith("cistern_") or p["piece"].startswith("grate_hatch_3_c25x25"))["position"]

    for name, centre, radius in (("Street: the Baixa", first("scaffold_142_40"), 30.0), ("Street: the stairs", first("tavern"), 30.0),
                                 ("Street: the Judiaria", cistern(), 25.0)):
        groups.append(_group(name, _near(placed, centre, radius), homes, "Cut from the level round its middle: every piece as placed."))

    return [g for g in groups if g["placed"] or g["kit"]]


def groups(district):
    return {"harbour": harbour, "old_town": old_town}[district]()
