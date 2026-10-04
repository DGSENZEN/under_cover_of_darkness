"""The Judiaria laid (the old town's spec, sections 4.3 and 6; plan B1a,
Task 16): its patio houses are the lot plan's (town/judiaria.py, placed
with the rest); here its terraces' retaining walls and the stair-lanes up
them, its parapets, its cliffs over the Baixa, the Carmo and the harbour's
shipyard, the palace's garden wall and its sealed gate; the Baixa's stair
towers into the quarter's two gated courts, the Carmo's stairs, the
corbels; the adarves' gates, the gardens, the cisterns, the chains of
linked roofs; its lamps, shrines, vantages, zones and ways."""

import math

import geo
import kit_recipes as kit
import kit_terrace

import town
from town import judiaria as plan


def _sector(x, z):
    return town.sector_of(x, z)


def world(at, yaw, local):
    return geo.add(list(at), geo.apply(geo.rotation(yaw), list(local[:3])))


def checks(L, route, points, **props):
    """A route's checks: points [x, y, z, move] in order, each saying what
    the route is."""
    sector = _sector(points[0][0], points[0][2])

    for i, p in enumerate(points):
        L.mark("%s_%d" % (route, i + 1), "route_check", p[:3], 0.0, sector, route=route, order=i + 1, move=p[3], **props)


def placed(at, yaw, points):
    """A piece's points [x, y, z, move] (its tour, its ways) in the world."""
    return [world(at, yaw, p) + [p[3]] for p in points]


def piece(w):
    return getattr(kit_terrace, w["kind"])(*w["args"])


def lay(L):
    for group, walls in plan.WALLS.items():
        for i, w in enumerate(walls):
            name = piece(w)
            x, y, z = w["at"]
            L.put(name, (x, y, z), w["yaw"], _sector(x, z), name="judiaria_%s_%d" % (group, i + 1), climbs=bool(kit.PIECES[name].get("climbs")))

    _gates(L)
    _towers(L)
    _climbs(L)
    _corral(L)
    _cisterns(L)
    _planting(L)
    _walk(L)
    _steps(L)
    vantages = _vantages(L)
    _lamps(L, vantages)
    _shrines(L, vantages)
    _zones(L)
    _chains(L)
    _payoffs(L)


def _gates(L):
    """The quarter's two gates and the adarves' (iron, shut at the curfew
    bell), the palace's sealed gate."""
    quarter = [w for w in plan.WALLS["gate"] if w.get("quarter")]

    for n, w in enumerate(quarter):
        d = kit.PIECES[piece(w)]["doors"][0]
        where = world(w["at"], w["yaw"], d)
        L.mark("judiaria_gate_%d" % (n + 1), "door", where, w["yaw"] + d[3], _sector(where[0], where[2]), kind="gate", curfew=True, width=d[4],
               height=d[5], label="the Judiaria's gate")

    for n, w in enumerate(plan.WALLS["adarve"]):
        d = kit.PIECES[piece(w)]["doors"][0]
        where = world(w["at"], w["yaw"], d)
        L.mark("judiaria_adarve_%d_gate" % (n + 1), "door", where, w["yaw"] + d[3], _sector(where[0], where[2]), kind="gate", curfew=True,
               width=d[4], height=d[5], label="an adarve's gate")

    palace = [w for w in plan.WALLS["gate"] if w.get("palace")][0]
    x, y, z = palace["at"]
    L.mark("judiaria_palace", "exit", (plan.EAST - 0.3, y + 1.2, z), 0.0, _sector(x, z), size=[0.6, 2.4, plan.GATE[1]],
           label="the palace's garden (sealed)", to="palace")


def _court_way(plate, door_z, gate_z, lane_z):
    """From a tower's top door or a stair's landing across its court and
    through its gate onto the lane: [x, y, z, move]."""
    y = plan.level(plate)
    x = plan.WEST + plan.COURT / 2.0
    return [[x, y, door_z, "walk"], [x, y, gate_z, "walk"], [x, y, lane_z, "walk"]]


def _towers(L):
    """The Baixa's stair towers: their doors, and their ways up from the
    Rossio through each court's gate onto its lane (public)."""
    for n, (w, (name, z)) in enumerate(zip(plan.WALLS["towers"], plan.TOWERS)):
        recipe = kit.PIECES[piece(w)]
        at, yaw = w["at"], w["yaw"]

        for i, d in enumerate(recipe["doors"]):
            where = world(at, yaw, d)
            L.mark("judiaria_tower_%d_door_%d" % (n + 1, i + 1), "door", where, yaw + d[3], _sector(where[0], where[2]))

        plate = plan.plate_named(name)
        door = plan.tower_at(name, z)[2]
        row = plan.row_at(plate, plan.WEST + 1.0, door)
        gate = plan.front(plate, row, plan.WEST + 1.0)
        zn, zs = plan.lane(plate, plan.WEST + 1.0)
        tour = placed(at, yaw, recipe["tour"])
        checks(L, "judiaria_tower_%d" % (n + 1), tour + _court_way(plate, door, gate, (zn + zs) / 2.0), way="public", step="judiaria_step_baixa")


def _climbs(L):
    """The corbels up the cliffs (a thief's: up them, hung from the parapet
    on the top, over it), the Carmo's stairs along its cliff (public), the
    corbels at each plazuela's back."""
    t, h = kit_terrace.PARAPET[1], kit_terrace.PARAPET[0]

    for w in [w for w in plan.WALLS["corbels"] if "plate" in w]:
        plate = plan.plate_named(w["plate"])
        y = plan.level(plate)
        at = w["at"]
        tops = placed(at, w["yaw"], [p + ["mantle"] for p in kit.PIECES[piece(w)]["tops"]])
        z = at[2]
        street = [plan.WEST - 1.4, at[1], z, "walk"]
        rail = [plan.WEST + t / 2.0, y + h + 0.08, tops[-1][2], "hang"]
        inside = [plan.WEST + 1.25, y, z, "drop"]
        step = "judiaria_step_baixa" if w["plate"] == plan.BAIXA_CORBELS[0] else "judiaria_step_carmo"
        checks(L, "judiaria_corbels_%s" % step.split("_")[-1], [street] + tops + [rail, inside], way="thief", step=step)

    for n, w in enumerate(plan.WALLS["carmo"]):
        plate = plan.plate_named(w["plate"])
        tour = placed(w["at"], w["yaw"], kit.PIECES[piece(w)]["tour"])
        last = tour[-1]
        zn, zs = plan.lane(plate, plan.WEST + 1.0)
        out = [[plan.WEST + 1.2, last[1], last[2], "walk"], [plan.WEST + plan.COURT / 2.0, last[1], last[2], "walk"],
               [plan.WEST + plan.COURT / 2.0, last[1], (zn + zs) / 2.0, "walk"]]
        checks(L, "judiaria_carmo_%d" % (n + 1), tour + out, way="public", step="judiaria_step_carmo")

    for w in [w for w in plan.WALLS["corbels"] if "step" in w]:
        k = w["step"]
        step = plan.STEPS[k]
        y = step["y"] + step["rise"]
        at = w["at"]
        tops = placed(at, w["yaw"], [p + ["mantle"] for p in kit.PIECES[piece(w)]["tops"]])
        # (Hung from the parapet square over the last corbel.)
        street = [at[0], step["y"], step["z"] + 1.4, "walk"]
        rail = [tops[-1][0], y + h + 0.08, step["z"] - t / 2.0, "hang"]
        inside = [tops[-1][0], y, step["z"] - 1.25, "drop"]
        checks(L, "judiaria_step_%d_corbels" % (k + 1), [street] + tops + [rail, inside], way="thief", step="judiaria_step_%d" % (k + 1))


def _corral(L):
    """The tenement court kept for its people: a home at each cell's door
    on the court."""
    each = [lot for lot in plan.LOTS if dict(lot.params).get("kind") == "corral"][0]
    recipe = kit.PIECES[town.design_key(each)]
    at = (each.x, each.y, each.z)

    for i, (x0, z0, x1, z1) in enumerate(recipe["cells"]):
        x = x1 + 0.6 if x0 < 0.0 else x0 - 0.6
        where = world(at, each.yaw, [x, 0.0, (z0 + z1) / 2.0])
        L.mark("%s_home_cell_%d" % (each.name, i + 1), "home", where, each.yaw, _sector(where[0], where[2]), label="the corral")


def _cisterns(L):
    """Each cistern's water along its channel, its way down the hatch and
    along the ledge to its far end, a payoff there."""
    w, _h = plan.CISTERN_SIZE

    for n, k in enumerate(plan.CISTERNS):
        x, y, (hx, hz), back = plan.cistern(k)
        front = hz + plan.CISTERN_CHAMBER / 2.0
        width = w - plan.CISTERN_LEDGE
        cx = x - plan.CISTERN_LEDGE / 2.0
        surface = y - kit_terrace.CHANNEL + 0.4
        L.mark("judiaria_cistern_%d_water" % (n + 1), "water", (cx, surface - 0.2, (front + back) / 2.0), 0.0, _sector(cx, hz),
               size=[width, 0.4, front - back], murk=0.9)
        ledge = x + w / 2.0 - plan.CISTERN_LEDGE / 2.0
        ladder = x + w / 2.0 - 0.4
        top = plan.level(plan.PLATES[k])
        points = [[hx, top, hz + 1.0, "walk"], [ladder, y, hz - 0.6, "climb"], [ledge, y, hz - 1.2, "walk"], [ledge, y, back + 0.6, "walk"]]
        checks(L, "judiaria_cistern_%d" % (n + 1), points, way="below")
        L.mark("payoff_judiaria_cistern_%d" % (n + 1), "mark", (ledge, y, back + 0.5), 0.0, _sector(ledge, back))


def _planting(L):
    """A cypress in each garden wide enough, an orange tree in each
    plazuela."""
    n = 0

    for plate in plan.PLATES:
        y = plan.level(plate)

        for row in ("north", "south"):
            for item in plan.ROWS.get((plate[0], row), []):
                if item["kind"] != "garden" or item["x1"] - item["x0"] < 2.2:
                    continue

                zf = plan.front(plate, row, (item["x0"] + item["x1"]) / 2.0)
                back = plan.north(plate) if row == "north" else plan.south(plate)

                # (One every 8 m along a long garden.)
                count = max(1, int((item["x1"] - item["x0"]) / 8.0))

                for i in range(count):
                    x = item["x0"] + (item["x1"] - item["x0"]) * (i + 0.5) / count
                    n += 1
                    L.put("cypress", (x, y, (zf + back) / 2.0), 30.0 * n, _sector(x, zf), name="judiaria_cypress_%d" % n)

    for k, step in enumerate(plan.STEPS):
        if k in plan.CISTERNS:
            continue

        plate = plan.PLATES[k]
        p = step["plazuela"]
        zn, _zs = plan.lane(plate, p + plan.PLAZUELA / 2.0)
        x, z = p + plan.PLAZUELA - 2.0, (zn + step["z"]) / 2.0
        L.put("orange_tree", (x, step["y"], z), 0.0, _sector(x, z), name="judiaria_orange_%d" % (k + 1))


def _walk(L):
    """The harbour's east wall-walk's arrival on the first terrace's south-
    east corner: a way from it into the lane."""
    arrival = (148.0, town.height(148.0, -78.0), -78.0)
    first = plan.PLATES[0]
    zn, zs = plan.lane(first, 144.0)
    y = plan.level(first)
    checks(L, "judiaria_walk_way", [[arrival[0], y, arrival[2], "walk"], [144.0, y, zs - 0.5, "walk"], [140.0, y, (zn + zs) / 2.0, "walk"]],
           way="public")


def _steps(L):
    """Each terrace step's box and its ways up: its two stairs (public), the
    corbels at its plazuela's back (a thief's, laid with the climbs); the
    boundary steps to the Baixa and the Carmo."""
    middle = (plan.WEST + plan.EAST) / 2.0

    for k, step in enumerate(plan.STEPS):
        label = "judiaria_step_%d" % (k + 1)
        L.mark(label, "terrace_step", (middle, step["y"] + step["rise"] / 2.0, step["z"]), 0.0, _sector(middle, step["z"]),
               size=[plan.EAST - plan.WEST, step["rise"] + 2.0, 6.0], label=label, public=2, thief=1)

        for j, w in enumerate(w for w in plan.WALLS["stair"] if w["step"] == k):
            tour = placed(w["at"], w["yaw"], kit.PIECES[piece(w)]["tour"])

            if w["kind"] == "wall_steps":
                last = tour[-1]
                tour.append([last[0], last[1], step["z"] - 1.0, "walk"])

            checks(L, "%s_lane_%d" % (label, j + 1), tour, way="public", step=label)

    for label, y0, y1, z0, z1 in (("judiaria_step_baixa", plan.BAIXA_G, plan.level(plan.plate_named("judiaria_4")), -170.0, -73.0),
                                  ("judiaria_step_carmo", 26.0, plan.level(plan.plate_named("judiaria_6")), -290.0, -170.0)):
        L.mark(label, "terrace_step", (plan.WEST, (y0 + y1) / 2.0, (z0 + z1) / 2.0), 0.0, _sector(plan.WEST, (z0 + z1) / 2.0),
               size=[6.0, y1 - y0 + 2.0, z1 - z0], label=label, public=2, thief=1)


def _vantages(L):
    """Unlit spots to scout from: at each stair's head, at each lane's west
    end over the cliff, at each corbels' top; their places."""
    out = []

    for w in plan.WALLS["stair"]:
        head = world(w["at"], w["yaw"], kit.PIECES[piece(w)]["head"])
        z = plan.STEPS[w["step"]]["z"]
        out.append([head[0] - (0.7 if w["kind"] == "wall_steps" else 0.0), head[1], z - 1.0])

    for plate in plan.PLATES:
        zn, zs = plan.lane(plate, plan.WEST + 1.0)
        out.append([plan.WEST + 1.0, plan.level(plate), (zn + zs) / 2.0])

    for w in [w for w in plan.WALLS["corbels"] if "plate" in w]:
        out.append([plan.WEST + 1.25, plan.level(plan.plate_named(w["plate"])), w["at"][2]])

    for i, at in enumerate(out):
        L.mark("judiaria_vantage_%d" % (i + 1), "vantage", at, 0.0, _sector(at[0], at[2]))

    return out


# Lamps along each lane: this far in from its ends, about this far apart;
# on a house's front (clear of its corners) within LAMP_SNAP of where they
# fall; none within LAMP_CLEAR of a vantage.
LAMP_FIRST, LAMP_APART = 16.0, 30.0
LAMP_SNAP = 9.0
LAMP_CLEAR = 5.0


def _lamps(L, vantages):
    """Corner lamps on the house fronts along each terrace's lane, about
    30 m apart, lit on dark nights only."""
    n = 0

    for plate in plan.PLATES:
        y = plan.level(plate)
        spots = []

        for row, yaw in (("north", 0.0), ("south", 180.0)):
            for item in plan.ROWS.get((plate[0], row), []):
                if item["kind"] != "house":
                    continue

                zf = plan.front(plate, row, (item["x0"] + item["x1"]) / 2.0)
                count = int((item["x1"] - item["x0"] - 1.2) / 0.5)
                spots += [(item["x0"] + 0.6 + 0.5 * i, zf, yaw) for i in range(count + 1)]

        spots = [s for s in spots if all(math.hypot(s[0] - v[0], s[1] - v[2]) >= LAMP_CLEAR or abs(v[1] - y) > 1.0 for v in vantages)]
        span = plan.EAST - plan.WEST - 2.0 * LAMP_FIRST
        gaps = max(1, int(math.ceil(span / LAMP_APART - 1e-9)))
        targets = [plan.WEST + LAMP_FIRST + span * i / gaps for i in range(gaps + 1)]

        for target in targets:
            near = [s for s in spots if abs(s[0] - target) <= LAMP_SNAP]

            if not near:
                continue

            sx, sz, yaw = min(near, key=lambda s: abs(s[0] - target))
            n += 1
            name = "judiaria_lamp_%d" % n
            sector = _sector(sx, sz)
            L.put("corner_lamp", (sx, y, sz), yaw, sector, name=name)

            for side, hook in zip("ab", kit.PIECES["corner_lamp"]["sockets"]["lamp"]):
                L.mark("%s_%s" % (name, side), "light", world((sx, y, sz), yaw, hook), yaw, sector, kind="lantern", dark_only=True)


def _shrines(L, vantages):
    """A candle in each corner house's tile shrine, burning all night (none
    so near a vantage it would light it)."""
    for each in plan.LOTS:
        if each.quirk != "shrine":
            continue

        recipe = kit.PIECES[town.design_key(each)]
        at = world((each.x, each.y, each.z), each.yaw, geo.add(recipe["places"]["shrine"], [0.0, 0.3, 0.1]))

        if any(math.dist(at, v) < 4.5 for v in vantages):
            continue

        L.mark("%s_candle" % each.name, "light", at, each.yaw, _sector(at[0], at[2]), kind="candle", douse=True)


def _zones(L):
    """The quarter outside; inside its towers; its cisterns cellars (the
    smallest box a point is in is its)."""
    x0, x1, z0, z1 = plan.WEST, 151.0, -290.0, -73.0
    L.mark("judiaria_zone", "zone", ((x0 + x1) / 2.0, 45.0, (z0 + z1) / 2.0), 0.0, "judiaria_hi", size=[x1 - x0, 70.0, z1 - z0], grade="outside")

    for n, w in enumerate(plan.WALLS["towers"]):
        size = kit.PIECES[piece(w)]["size"]
        x, y, z = w["at"]
        L.mark("judiaria_tower_%d_zone" % (n + 1), "zone", (x, y + size[1] / 2.0, z), 0.0, _sector(x, z), size=size, grade="indoors")

    w, h = plan.CISTERN_SIZE

    for n, k in enumerate(plan.CISTERNS):
        x, y, (_hx, hz), back = plan.cistern(k)
        front = hz + plan.CISTERN_CHAMBER / 2.0
        low, high = y - kit_terrace.CHANNEL, y + h + 0.3
        L.mark("judiaria_cistern_%d_zone" % (n + 1), "zone", (x, (low + high) / 2.0, (front + back) / 2.0), 0.0, _sector(x, hz),
               size=[w, high - low, front - back], grade="cellar")


def _chains(L):
    """The roofs' chains: up the wall stair on the plazuela's west side onto
    the chain's first azotea, west along the roofs through the gaps in
    their parapets."""
    for n, (k, w) in enumerate(zip(plan.CHAINS, plan.WALLS["chain"])):
        plate = plan.PLATES[k]
        lots = plan.chain_lots(k)
        up = placed(w["at"], w["yaw"], kit.PIECES[piece(w)]["tour"])
        y = plan.level(plate) + w["args"][0]
        link = plan.north(plate) + 2.5
        route = [[lots[0].x + lots[0].width / 2.0 - 0.6, y, link, "walk"]]

        for each in lots:
            route.append([each.x - each.width / 2.0 + 0.6, y, link, "walk"])

        checks(L, "roof_judiaria_%d" % (n + 1), up + route, way="roof")
        last = route[-1]
        L.mark("judiaria_chain_%d_vantage" % (n + 1), "vantage", [lots[0].x, y, link], 0.0, _sector(lots[0].x, link))
        L.mark("payoff_judiaria_roof_%d" % (n + 1), "mark", last[:3], 0.0, _sector(last[0], last[2]))


def _payoffs(L):
    """Each adarve's dead end, each lane's east end at the garden wall, each
    plazuela without a cistern: a payoff kept for B1b's loot."""
    for n, (name, (x0, w)) in enumerate(plan.ADARVES.items()):
        plate = plan.plate_named(name)
        x, z = x0 + w / 2.0, plan.north(plate) + 1.0
        L.mark("payoff_judiaria_adarve_%d" % (n + 1), "mark", (x, plan.level(plate), z), 0.0, _sector(x, z))

    for n, plate in enumerate(plan.PLATES):
        zn, zs = plan.lane(plate, plan.EAST - 1.0)

        if plate[0] == "judiaria_6":
            continue

        L.mark("payoff_judiaria_lane_%d" % (n + 1), "mark", (plan.EAST - 1.0, plan.level(plate), (zn + zs) / 2.0), 0.0,
               _sector(plan.EAST, zn))

    for k, step in enumerate(plan.STEPS):
        if k in plan.CISTERNS:
            continue

        x, z = step["plazuela"] + plan.PLAZUELA - 1.2, step["z"] + 1.2
        L.mark("payoff_judiaria_plazuela_%d" % (k + 1), "mark", (x, step["y"], z), 0.0, _sector(x, z))
