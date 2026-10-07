"""Where the old town's ways up its walls go (plan B1a, Task 16b, the user's
playtest): lead downpipes on the party lines between houses, spread along
each quarter's rows, up to the lower of the two roofs; ivy up the step
behind the Judiaria's gardens whose top is a parapet. The kit lists their
pieces from here (`terrace`) before the layout lays them (layouts' climbs).
"""

import math

import town
from town import judiaria

# How many pipes a quarter has, spread along it; how many steps' ivy.
PIPES = 2
IVY = 1
# Ivy up the Judiaria's west cliff from the Baixa's lane under it, where its
# top is a parapet (the third terrace's, clear of the towers and the
# ledges): (terrace, z).
CLIFF_IVY = [("judiaria_3", -141.0)]
# Ivy's width up a garden's back, at most.
IVY_WIDTH = 2.4
# The families whose party lines take a pipe, and what tops a front: a
# pitched roof behind its cornice, or a patio's parapet (its azotea behind).
# (A patio house's: over its parapet onto its azotea. Not a pitched roof's:
# a Pombaline's tiles overhang its cornice, so from a pipe's top a climber
# meets the slope, not a face; Porto's hipped roofs meet in a valley on the
# party line, rising either side, beside the higher house's wall: no
# landing a man fits on.)
FAMILIES = {"patio": "parapet"}
# Quirks out on a front or on a roof's edge that a pipe keeps away from.
PLAIN = ("", "dormer", "privy_tower", "against_wall")
QUARTERS = (("judiaria", judiaria),)


def spread(items, n):
    """n of `items`, spread along them (their nths' middles)."""
    if len(items) <= n:
        return list(items)

    return [items[int((i + 0.5) * len(items) / n)] for i in range(n)]


def side_of(lot, s):
    """Where a lot's front meets its party wall on its local +x side (s 1)
    or -x side (s -1): (x, z)."""
    turn = math.radians(lot.yaw)
    return (lot.x + s * math.cos(turn) * lot.width / 2.0, lot.z - s * math.sin(turn) * lot.width / 2.0)


def pairs(lots):
    """Neighbours in a row (one front line, one way, one family, b across
    a's local +x party wall) whose party line takes a pipe: two storeys or
    more, plain; in the row's order."""
    fit = [each for each in lots if each.family in FAMILIES and each.storeys >= 2 and each.quirk in PLAIN and abs(each.yaw % 90.0) < 0.01]
    out = []

    for a in fit:
        for b in fit:
            if b is not a and abs(b.yaw - a.yaw) < 0.01 and abs(b.y - a.y) < 0.01 and b.family == a.family \
                    and math.dist(side_of(a, 1.0), side_of(b, -1.0)) < 0.05:
                out.append((a, b))

    return sorted(out, key=lambda ab: (ab[0].yaw, side_of(ab[0], 1.0)))


def pipes():
    """Every party line that could take a pipe, by quarter in its rows'
    order: (quarter, a, b, the lower lot, its side of the line (-1 a's, +1
    b's), what tops it, the pipe's height). The layout lays PIPES of each
    quarter's, spread, where no lamp hangs (the kit has them all)."""
    import kit_recipes as kit
    import kit_town

    out = []

    for quarter, plan in QUARTERS:
        for a, b in pairs(plan.LOTS):
            keys = [town.design_key(each) for each in (a, b)]

            # (The kit registers houses as their families' modules load: a
            # pass before theirs leaves the pipe to the next.)
            if any(key not in kit.PIECES for key in keys):
                continue

            ea, eb = (kit.PIECES[key]["eaves"] for key in keys)
            low, side = (a, -1.0) if ea <= eb else (b, 1.0)
            kind = FAMILIES[a.family]
            height = round(min(ea, eb) + (kit_town.PARAPET if kind == "parapet" else 0.0), 3)
            out.append((quarter, a, b, low, side, kind, height))

    return out


def ivy():
    """The Judiaria's ivy, each {at, yaw, rise (up its wall and parapet),
    parapet, step}: up a step where a garden or a plazuela is open under it
    (clear of its ledges) and its top is a parapet (no house's back, no
    stair's or ledges' head on it); up the west cliff from the Baixa."""
    import kit_terrace

    plan = judiaria
    half = IVY_WIDTH / 2.0
    found = []

    for k, step in enumerate(plan.STEPS):
        low, high = plan.PLATES[k], plan.PLATES[k + 1]
        blocked = [(i["x0"], i["x1"]) for i in plan.ROWS.get((high[0], "south"), []) if i["kind"] in ("house", "stair_head", "corbel_head")]
        ledges = [(w["at"][0] - 0.5, w["at"][0] + kit_terrace.LEDGE[0] * (int(math.ceil(step["rise"] / kit_terrace.LEDGE_RISE - 1e-9)) - 1) + 0.5)
                  for w in plan.WALLS["ledges"] if w.get("step") == k]

        for item in plan.ROWS.get((low[0], "north"), []):
            if item["kind"] not in ("garden", "plazuela"):
                continue

            # (Each end of it, the ivy's width in from its side.)
            for x in (item["x0"] + half + 0.3, item["x1"] - half - 0.3):
                clear = item["x1"] - item["x0"] >= IVY_WIDTH + 0.6 and not any(a - half - 0.3 < x < b + half + 0.3 for a, b in ledges)

                if clear and not any(a - half - 0.4 < x < b + half + 0.4 for a, b in blocked):
                    found.append({"at": (round(x, 3), step["y"], step["z"]), "yaw": 0.0, "rise": round(step["rise"] + kit_terrace.PARAPET[0], 3),
                                  "parapet": kit_terrace.PARAPET[0], "step": "judiaria_step_%d" % (k + 1)})

    out = spread(sorted(found, key=lambda f: (f["at"][2], f["at"][0])), IVY)
    wall = kit_terrace.PARAPET[0]

    for name, z in CLIFF_IVY:
        height = plan.level(plan.plate_named(name)) - plan.BAIXA_G
        out.append({"at": (plan.WEST, plan.BAIXA_G, z), "yaw": -90.0, "rise": round(height + wall, 3), "parapet": wall, "step": "judiaria_step_baixa"})

    return out


def terrace():
    """The pieces the climbs ask the kit for: (kind, args) pairs."""
    return sorted({("drainpipe", (p[6],)) for p in pipes()}) + [("ivy", (IVY_WIDTH, i["rise"])) for i in ivy()]
