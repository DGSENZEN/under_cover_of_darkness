"""The stairs quarter laid (the old town's spec, sections 4.3 and 6; plan
B1a, Task 15): its houses are the lot plan's (town/stairs.py, placed with
the rest); here its terraces' retaining walls and the stair-lanes up them,
its parapets, the cliffs to the Baixa and the Carmo, the city wall's footing
and the old rampart along the gorge, its light plots' fronts; the places
laid by hand: the fountain square and its bastion, the vaulted stream, the
tavern, the tannery, the Guindais postern, the west wall's stair, the
bricked-up alley; and the ways through them."""

import math

import geo
import kit_recipes as kit
import kit_terrace
import rules

import town
from town import stairs as plan


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


def lay(L):
    for group, walls in plan.WALLS.items():
        for i, w in enumerate(walls):
            name = getattr(kit_terrace, w["kind"])(*w["args"])
            x, y, z = w["at"]
            L.put(name, (x, y, z), w["yaw"], _sector(x, z), name="stairs_%s_%d" % (group, i + 1), climbs=bool(kit.PIECES[name].get("climbs")))

    _stream(L)
    _tavern(L)
    _tower(L)
    _square(L)
    _places(L)
    _ways(L)
    _steps(L)
    vantages = _vantages(L)
    _torches(L, vantages)
    _shrines(L, vantages)
    _zones(L)
    _chains(L)
    _payoffs(L)


def _stream(L):
    """The stream's water along its channel (a cascade's at both its
    levels), the payoff at its outfall."""
    w, _h = plan.STREAM_SIZE
    width = w - plan.STREAM_LEDGE
    x = plan.STREAM_X - plan.STREAM_LEDGE / 2.0

    for i, (kind, args, z, y) in enumerate(plan.STREAM):
        surface = y - kit_terrace.CHANNEL + 0.4

        if kind == "cascade":
            half = plan.CASCADE / 2.0
            spans = [(z + half / 2.0, surface), (z - half / 2.0, surface + args[2])]
            length = half
        else:
            length = kit.PIECES[getattr(kit_terrace, kind)(*args)]["size"][2]
            spans = [(z, surface)]

        for j, (zc, top) in enumerate(spans):
            L.mark("stairs_stream_water_%d_%d" % (i + 1, j + 1), "water", (x, top - 0.2, zc), 0.0, _sector(x, zc), size=[width, 0.4, length],
                   murk=0.8)

    L.mark("payoff_1", "mark", (plan.STREAM_X + 0.9, plan.PLATES[0][6] - plan.STREAM_DEPTH, plan.RIBEIRA - 1.0), 0.0, "stairs_lo")


def tavern_at():
    x, z, yaw = plan.TAVERN
    return (x, plan.level(plan.PLATES[1]), z), yaw


def _tavern(L):
    """The tavern on the second terrace: its doors, its household and its
    four ways in, its twelve seats, its lamp and its noise, the cellar's
    barred door to the undercroft (sealed)."""
    import kit_tavern
    at, yaw = tavern_at()
    sector = _sector(at[0], at[2])
    recipe = kit.PIECES["tavern"]
    L.put("tavern", at, yaw, sector, name="stairs_tavern")

    for i, d in enumerate(recipe["doors"]):
        L.mark("stairs_tavern_door_%d" % (i + 1), "door", world(at, yaw, d), yaw + d[3], sector)

    depth, eaves = kit_tavern.DEPTH, kit_tavern.EAVES
    middle = world(at, yaw, [0.0, (eaves - kit_tavern.CELLAR) / 2.0, -depth / 2.0])
    L.mark("stairs_tavern_house", "household", middle, yaw, sector, size=[kit_tavern.WIDTH, eaves + kit_tavern.CELLAR, depth], label="tavern",
           ways=4)

    for way in recipe["ways"]:
        checks(L, "stairs_tavern_way_%s" % way["kind"], placed(at, yaw, way["points"]), into="tavern", kind=way["kind"])

    for i, seat in enumerate(recipe["seats"]):
        L.mark("stairs_tavern_seat_%d" % (i + 1), "seat", world(at, yaw, seat), yaw, sector, label="tavern")

    bar = recipe["places"]["bar"]
    L.mark("stairs_tavern_lamp", "light", world(at, yaw, [bar[0], 2.6, bar[2]]), yaw, sector, kind="lantern", douse=True)
    L.mark("stairs_tavern_noise", "noise_zone", world(at, yaw, [0.0, 1.5, -depth / 2.0]), yaw, sector, size=[kit_tavern.WIDTH + 2.0, 4.0, depth],
           db=55.0, label="the tavern")
    door = recipe["places"]["undercroft_door"]
    inside = [door[0] - 0.4, door[1] + 1.2, door[2]]
    L.mark("stairs_undercroft", "exit", world(at, yaw, inside), yaw, sector, size=[0.8, 2.4, 1.6], label="the undercroft (sealed)",
           to="undercroft")


def _tower(L):
    """The stair towers' doors (each foot's on the street below, each top's
    on its terrace) and their ways up; the corbels' ways up beside them."""
    for n, (tower, (_plate, _z, _ground, quarter)) in enumerate(zip(plan.WALLS["towers"], plan.TOWERS)):
        name = getattr(kit_terrace, tower["kind"])(*tower["args"])
        at, yaw = tower["at"], tower["yaw"]

        for i, d in enumerate(kit.PIECES[name]["doors"]):
            where = world(at, yaw, d)
            L.mark("stairs_tower_%d_door_%d" % (n + 1, i + 1), "door", where, yaw + d[3], _sector(where[0], where[2]))

        checks(L, "stairs_tower_%d" % (n + 1), placed(at, yaw, kit.PIECES[name]["tour"]), way="public", step="stairs_step_%s" % quarter)

    for n, (corbel, (plate, _z, _ground, quarter)) in enumerate(zip(plan.WALLS["corbels"], plan.CORBEL_CLIMBS)):
        name = getattr(kit_terrace, corbel["kind"])(*corbel["args"])
        at, yaw = corbel["at"], corbel["yaw"]
        tops = placed(at, yaw, [t + ["mantle"] for t in kit.PIECES[name]["tops"]])
        first = tops[0]
        y = plan.level([p for p in plan.PLATES if p[0] == plate][0])
        street = [first[0] + 1.0, at[1], first[2], "walk"]
        # (Over the parapet on the cliff's top: hung from, stood on, dropped
        # from onto the terrace.)
        rail = [plan.EAST - kit_terrace.PARAPET[1] / 2.0, y + kit_terrace.PARAPET[0] + 0.08, tops[-1][2], "hang"]
        inside = [plan.EAST - 1.5, y, tops[-1][2], "drop"]
        checks(L, "stairs_corbels_%d" % (n + 1), [street] + tops + [rail, inside], way="thief", step="stairs_step_%s" % quarter)


def _square(L):
    """The fountain in the bastion's face over the square, the shrine and
    the forgotten king's panel on the square's sides, the vantage on the
    bastion."""
    y3 = plan.level(plan.PLATES[2])
    x0, z0, x1, z1 = plan.BASTION
    fountain = ((x0 + x1) / 2.0, y3, z1)
    sector = _sector(fountain[0], fountain[2])
    L.put("fountain_wall", fountain, 0.0, sector, name="stairs_fountain")
    water = world(fountain, 0.0, kit.PIECES["fountain_wall"]["sockets"]["water"][0])
    L.mark("stairs_fountain_noise", "noise_zone", water, 0.0, sector, size=[8.0, 4.0, 8.0], db=50.0, label="the square's fountain")
    # (The shrine on the slot house's side, facing the square; the panel on
    # the south-east block's, across it.)
    sx0, sz0, sx1, sz1 = plan.SQUARE
    shrine = (sx0, y3, (sz1 + plan.CROSS[1]) / 2.0)
    L.put("shrine_retablo", shrine, 90.0, sector, name="stairs_shrine")

    for i, hook in enumerate(kit.PIECES["shrine_retablo"]["sockets"]["lamp"]):
        L.mark("stairs_shrine_lamp_%d" % (i + 1), "light", world(shrine, 90.0, hook), 90.0, sector, kind="candle", douse=True)

    L.put("panel_king", (sx1, y3 + 1.3, (sz1 + plan.CROSS[1]) / 2.0), -90.0, sector, name="stairs_panel_king")
    L.mark("stairs_bastion_vantage", "vantage", ((x0 + x1) / 2.0, plan.level(plan.PLATES[3]), z1 - 1.2), 180.0, sector)


def _places(L):
    """The slot house's and the alley's secrets, the tannery's work spot."""
    slot = [each for each in plan.LOTS if each.quirk == "slot"][0]
    r = plan.lot_rect(slot)
    L.mark("stairs_slot_secret", "secret", ((r[0] + r[2]) / 2.0, slot.y + 4.0, (r[1] + r[3]) / 2.0), 0.0, _sector(slot.x, slot.z),
           size=[r[2] - r[0] - 0.2, 8.0, r[3] - r[1] - 0.4], label="the slot house")
    x0, z0, x1, z1 = plan.ALLEY
    y4 = plan.level(plan.PLATES[3])
    L.mark("stairs_alley_secret", "secret", ((x0 + x1) / 2.0, y4 + 2.0, (z0 + z1 - 0.4) / 2.0), 0.0, _sector(x0, z0),
           size=[x1 - x0, 4.0, z1 - 0.4 - z0], label="the bricked-up alley")
    tannery = [w for w in plan.WALLS["tannery"] if w["kind"] == "tannery"][0]
    work = world(tannery["at"], tannery["yaw"], kit.PIECES["tannery"]["work"])
    L.mark("stairs_tannery_work", "work", work, 0.0, _sector(work[0], work[2]), kind="tannery")

    for i, gate in enumerate(w for w in plan.WALLS["tannery"] if w["kind"] == "yard_front"):
        name = getattr(kit_terrace, gate["kind"])(*gate["args"])

        for d in kit.PIECES[name]["doors"]:
            where = world(gate["at"], gate["yaw"], d)
            L.mark("stairs_tannery_gate_%d" % (i + 1), "door", where, gate["yaw"] + d[3], _sector(where[0], where[2]), width=d[4], height=d[5])


def _stair_tour(k, c):
    """The tour up the stair-lane at c on step k, in the world."""
    w = [w for w in plan.WALLS["stair"] if w["step"] == k and abs(w["at"][0] - c) < 0.01][0]
    name = getattr(kit_terrace, w["kind"])(*w["args"])
    return placed(w["at"], w["yaw"], kit.PIECES[name]["tour"])


def _ways(L):
    y3 = plan.level(plan.PLATES[2])
    cross = (plan.CROSS[0] + plan.CROSS[1]) / 2.0
    x0, z0, x1, z1 = plan.SQUARE
    bx0, _bz0, bx1, bz1 = plan.BASTION
    start = [(bx0 + bx1) / 2.0, y3, bz1 + 3.0, "walk"]
    south = plan.south(plan.PLATES[2]) - plan.LANE / 2.0
    passage = (plan.PASSAGE[0] + plan.PASSAGE[1]) / 2.0
    alley = (plan.TANNERY_ALLEY[0] + plan.TANNERY_ALLEY[1]) / 2.0
    # (The Guindais lane's way keeps to its south side, past the hatch's
    # open shaft.)
    lanes = [
        [[x0, y3, plan.CROSS[1] - 0.5, "walk"], [x0 - 15.0, y3, plan.CROSS[1] - 0.5, "walk"]],
        [[x1, y3, cross, "walk"], [plan.MIRADOURO[0] - 2.0, y3, cross, "walk"]],
        [[sum(plan.SOUTH_LANES[0]) / 2.0, y3, z1, "walk"], [sum(plan.SOUTH_LANES[0]) / 2.0, y3, south, "walk"]],
        [[sum(plan.SOUTH_LANES[1]) / 2.0, y3, z1, "walk"], [sum(plan.SOUTH_LANES[1]) / 2.0, y3, south, "walk"]],
        [[plan.GAPS[2][0], y3, z0, "walk"]] + _stair_tour(2, plan.GAPS[2][0])[1:],
        [[plan.GAPS[2][1], y3, z0, "walk"]] + _stair_tour(2, plan.GAPS[2][1])[1:],
        [[passage, y3, z0, "walk"], [passage, y3, alley + 1.0, "walk"], [passage - 2.0, y3, alley, "walk"],
         [plan.TANNERY[2] + 1.0, y3, alley, "walk"]],
    ]

    for i, points in enumerate(lanes):
        checks(L, "stairs_square_lane_%d" % (i + 1), [start] + points, way="public")

    # Through each two-level house: in at its front door off the lane below,
    # up its stair, out at its back door onto the lane above (a thief's way
    # up the step).
    for each in plan.LOTS:
        if each.quirk != "two_level":
            continue

        recipe = kit.PIECES[town.design_key(each)]
        at = (each.x, each.y, each.z)
        back = recipe["out_back"][-1]
        out = [back[0], back[1], -each.depth - 1.5, "walk"]
        k = [n for n, st in enumerate(plan.STEPS) if abs(st["z"] - (each.z - each.depth)) < 0.05][0]
        checks(L, "stairs_through_%s" % each.name, placed(at, each.yaw, recipe["tour"] + recipe["out_back"] + [out]), way="thief",
               step="stairs_step_%d" % (k + 1))

    # The west wall's stair from the first lane to the walk.
    stair = plan.WALLS["climbs"][0]
    name = getattr(kit_terrace, stair["kind"])(*stair["args"])
    tour = placed(stair["at"], stair["yaw"], kit.PIECES[name]["tour"])
    last = tour[-1]
    checks(L, "stairs_west_wall", tour + [[plan.WALL_X, last[1], last[2], "walk"]], way="public")

    # Below: down the hatch in the Guindais lane, along the stream's ledge
    # and down its cascade to the tavern's cellar door; on down to the
    # grating at its outfall.
    hx, hz = plan.HATCH
    ledge = plan.STREAM_X + plan.STREAM_SIZE[0] / 2.0 - plan.STREAM_LEDGE / 2.0
    ladder = plan.STREAM_X + plan.STREAM_SIZE[0] / 2.0 - 0.4
    points = [[hx, y3, hz + 1.0, "walk"], [ladder, y3 - plan.STREAM_DEPTH, hz - 0.6, "climb"], [ledge, y3 - plan.STREAM_DEPTH, hz + 1.2, "walk"]]
    tavern_z = plan.TAVERN[1]

    for kind, args, z, y in plan.STREAM[::-1]:
        if kind == "cascade" and z < tavern_z:
            name = getattr(kit_terrace, kind)(*args)
            points += [p for p in placed((plan.STREAM_X, y, z), 0.0, kit.PIECES[name]["tour"])[::-1]]

    points = _downstream(points)
    points.append([ledge, plan.level(plan.PLATES[1]) - plan.STREAM_DEPTH, tavern_z - 1.0, "walk"])
    checks(L, "stairs_below_stream", points, way="below")
    points = [[ledge, plan.level(plan.PLATES[1]) - plan.STREAM_DEPTH, tavern_z + 1.0, "walk"]]

    for kind, args, z, y in plan.STREAM[::-1]:
        if kind == "cascade" and z > tavern_z:
            name = getattr(kit_terrace, kind)(*args)
            points += [p for p in placed((plan.STREAM_X, y, z), 0.0, kit.PIECES[name]["tour"])[::-1]]

    points = _downstream(points)
    points.append([ledge, plan.level(plan.PLATES[0]) - plan.STREAM_DEPTH, plan.RIBEIRA - 1.0, "walk"])
    checks(L, "stairs_below_outfall", points, way="below")


def _downstream(points):
    """A way below walked from its first point on (cascades' tours walked
    backwards): each move a climb where it joins two levels (a ladder), a
    walk along one."""
    out = [points[0][:3] + ["walk"]]

    for p in points[1:]:
        out.append(p[:3] + ["climb" if abs(p[1] - out[-1][1]) > 1.0 else "walk"])

    return out


def _steps(L):
    """Each terrace step's box and its public ways up (its two stair-lanes;
    its thief's, the two-level house through it, laid with the ways); the
    boundary steps down to the Baixa and the Carmo (their towers and corbels,
    laid with them)."""
    middle = (plan.WEST + plan.EAST) / 2.0

    for k, step in enumerate(plan.STEPS):
        label = "stairs_step_%d" % (k + 1)
        L.mark(label, "terrace_step", (middle, step["y"] + step["rise"] / 2.0, step["z"]), 0.0, _sector(middle, step["z"]),
               size=[plan.EAST - plan.WEST, step["rise"] + 2.0, 6.0], label=label, public=2, thief=1)

        for j, c in enumerate(step["gaps"]):
            checks(L, "%s_lane_%d" % (label, j + 1), _stair_tour(k, c), way="public", step=label)

    for label, y0, y1, z0, z1 in (("stairs_step_baixa", plan.BAIXA_G, plan.level(plan.PLATES[4]), -170.0, -72.5),
                                  ("stairs_step_carmo", plan.CARMO_G, plan.level(plan.PLATES[-1]), -290.0, -170.0)):
        L.mark(label, "terrace_step", (plan.EAST, (y0 + y1) / 2.0, (z0 + z1) / 2.0), 0.0, _sector(plan.EAST, (z0 + z1) / 2.0),
               size=[6.0, y1 - y0 + 2.0, z1 - z0], label=label, public=2, thief=1)


def _vantages(L):
    """Unlit, parapeted spots to scout from: at each stair-lane's head, at
    each terrace's lane's end over the cliff, on the miradouro; the
    bastion's laid with the square. Their places."""
    out = []

    for w in plan.WALLS["stair"]:
        name = getattr(kit_terrace, w["kind"])(*w["args"])
        head = world(w["at"], w["yaw"], kit.PIECES[name]["head"])
        out.append(geo.add(head, [0.0, 0.0, -1.0]))

    for plate in plan.PLATES:
        out.append([plan.EAST - 1.0, plan.level(plate), plan.south(plate) - plan.LANE / 2.0])

    out.append([plan.EAST - 1.5, plan.level(plan.PLATES[2]), plan.CORBEL_CLIMBS[0][1]])

    for i, at in enumerate(out):
        L.mark("stairs_vantage_%d" % (i + 1), "vantage", at, 0.0, _sector(at[0], at[2]))

    x0, _z0, x1, z1 = plan.BASTION
    return out + [[(x0 + x1) / 2.0, plan.level(plan.PLATES[3]), z1 - 1.2]]


# Torches on the fronts along each lane: this far from the lane's ends and
# apart, snapped to a party line or a house's corner; none near a vantage.
TORCH_TARGETS = (14.0, 0.5, 14.0)
TORCH_SNAP = 8.0
TORCH_CLEAR = 5.0


def _torches(L, vantages):
    """Torches on the house fronts (or backs) lining each terrace's lane,
    about 25 m apart, 2.6 m up, the player can douse them; one on the
    square."""
    n = 0

    for plate in plan.PLATES:
        y = plan.level(plate)
        face = plan.south(plate) - plan.LANE
        lining = [plan.lot_rect(each) for each in plan.LOTS if abs(each.y - y) < 0.01 and abs(plan.lot_rect(each)[3] - face) < 0.01]
        # (Spots: the party lines and corners on the faces along the lane,
        # and the row's last gable where it stops short of the cliff.)
        spots = sorted({(x, face + 0.3, 0.0) for r in lining for x in (r[0], r[2])})
        last_x = max(r[2] for r in lining)

        if last_x < plan.EAST - 2.0:
            spots.append((last_x + 0.3, face - 0.8, 90.0))

        spots = [sp for sp in spots if all(math.hypot(sp[0] - v[0], sp[1] - v[2]) >= TORCH_CLEAR or abs(v[1] - y) > 1.0 for v in vantages)]
        first, middle, last = TORCH_TARGETS
        targets = [plan.WEST + first, (plan.WEST + plan.EAST) / 2.0, plan.EAST - last]

        for target in targets:
            near = [sp for sp in spots if abs(sp[0] - target) <= TORCH_SNAP]

            if not near:
                continue

            x, z, yaw = min(near, key=lambda sp: abs(sp[0] - target))
            n += 1
            L.mark("stairs_torch_%d" % n, "light", (x, y + 2.6, z), yaw, _sector(x, z), kind="torch", douse=True)

    # (The square's: on the middle block's front, between its first two
    # houses.)
    ms = sorted((each for each in plan.LOTS if each.name.startswith("stairs_ms_") and not each.name.startswith("stairs_ms_east")),
                key=lambda each: each.x)
    x = plan.lot_rect(ms[0])[2]
    n += 1
    L.mark("stairs_torch_%d" % n, "light", (x, plan.level(plan.PLATES[2]) + 2.6, plan.SQUARE[3] - 0.3), 180.0, _sector(x, plan.SQUARE[3]),
           kind="torch", douse=True)


def _shrines(L, vantages):
    """A candle in each corner shrine's niche, burning all night (none so
    near a vantage it would light it)."""
    for each in plan.LOTS:
        if each.quirk != "corner_shrine":
            continue

        recipe = kit.PIECES[town.design_key(each)]
        at = world((each.x, each.y, each.z), each.yaw, geo.add(recipe["places"]["shrine"], [0.0, 0.3, 0.1]))

        if any(math.dist(at, v) < 4.5 for v in vantages):
            continue

        L.mark("%s_candle" % each.name, "light", at, each.yaw, _sector(at[0], at[2]), kind="candle", douse=True)


def _zones(L):
    """The quarter outside; inside the tavern (its cellar a cellar), its
    stair towers, the stream (the smallest box a point is in is its)."""
    middle = (plan.WEST + plan.EAST) / 2.0
    L.mark("stairs_zone", "zone", (middle, 45.0, -155.5), 0.0, "stairs_mid", size=[plan.EAST - plan.WEST, 110.0, 269.0], grade="outside")
    import kit_tavern
    at, yaw = tavern_at()
    depth, eaves, cellar = kit_tavern.DEPTH, kit_tavern.EAVES, kit_tavern.CELLAR
    sector = _sector(at[0], at[2])
    L.mark("stairs_tavern_zone", "zone", world(at, yaw, [0.0, eaves / 2.0, -depth / 2.0]), yaw, sector, size=[kit_tavern.WIDTH, eaves, depth],
           grade="indoors")
    L.mark("stairs_tavern_cellar_zone", "zone", world(at, yaw, [0.0, -cellar / 2.0, -depth / 2.0]), yaw, sector,
           size=[kit_tavern.WIDTH, cellar, depth], grade="cellar")

    for n, tower in enumerate(plan.WALLS["towers"]):
        name = getattr(kit_terrace, tower["kind"])(*tower["args"])
        size = kit.PIECES[name]["size"]
        x, y, z = tower["at"]
        L.mark("stairs_tower_%d_zone" % (n + 1), "zone", (x, y + size[1] / 2.0, z), 0.0, _sector(x, z), size=size, grade="indoors")

    w, h = plan.STREAM_SIZE

    for i, (kind, args, z, y) in enumerate(plan.STREAM):
        length = kit.PIECES[getattr(kit_terrace, kind)(*args)]["size"][2]
        drop = args[2] if kind == "cascade" else 0.0
        low, high = y - kit_terrace.CHANNEL, y + drop + h
        L.mark("stairs_stream_zone_%d" % (i + 1), "zone", (plan.STREAM_X, (low + high) / 2.0, z), 0.0, _sector(plan.STREAM_X, z),
               size=[w, high - low, length], grade="cellar")


def _payoffs(L):
    """Each lane's west end, where it meets the city wall or the old
    rampart with no way on: a payoff kept for B1b's loot (the first
    terrace's lane goes on up the wall's stair)."""
    for k, plate in enumerate(plan.PLATES[1:]):
        L.mark("payoff_%d" % (k + 2), "mark", (plan.WEST + 1.0, plan.level(plate), plan.south(plate) - plan.LANE / 2.0), 0.0,
               _sector(plan.WEST, plan.south(plate)))


def _chains(L):
    """The roof chains (the plan's CHAINS): up each scaffold (laid with the
    plan's pieces), along its row's roofs."""
    named = {each.name: each for each in plan.LOTS}

    for n, ((_plate, _sz, end), scaffold) in enumerate(zip(plan.CHAINS, plan.WALLS["scaffolds"])):
        x, y, sz = scaffold["at"]
        corner = named[scaffold["corner"]]
        assert abs(kit.PIECES[town.design_key(corner)]["eaves"] - scaffold["args"][0]) < 0.01, corner.name
        recipe = kit.PIECES[kit_terrace.scaffold(*scaffold["args"])]
        n += 1
        up = placed((x, y, sz), 90.0, recipe["tour"])
        row = [each for each in plan.LOTS if abs(each.y - y) < 0.01 and plan.lot_rect(each)[1] <= sz <= plan.lot_rect(each)[3]
               and end - 0.01 <= plan.lot_rect(each)[0] and plan.lot_rect(each)[2] <= x + 0.01]
        names = {each.name for each in row}
        boxes = [b for p in L.pieces if p["name"] in names for b in geo.piece_boxes(kit.PIECES[p["piece"]], p["position"], p["basis"])]
        route = _chain(boxes, row, x, end, corner, sz)
        checks(L, "roof_stairs_%d" % n, up + route, way="roof")
        L.mark("stairs_scaffold_%d_vantage" % n, "vantage", world((x, y, sz), 90.0, [0.0, recipe["top"], kit_terrace.DECK_OFF + kit_terrace.DECK / 2.0]),
               270.0, _sector(x, sz))


def _chain(boxes, row, x, end, corner, sz):
    """The way along a row's roofs from its scaffold at x, z sz, up the
    gable's slope, then west to end along a line a little behind the
    ridges (tried at a few depths), the roofs sampled; where it meets a
    stair-lane's gap, a leap across (never more than a leap's rise up)."""
    from old_town.baixa import roof_route
    r = plan.lot_rect(corner)
    spans = sorted(((plan.lot_rect(each)[0], plan.lot_rect(each)[2]) for each in row), reverse=True)
    runs = []

    for a, b in spans:
        if runs and abs(runs[-1][0] - b) < 0.01:
            runs[-1][0] = a
        else:
            runs.append([a, b])

    # (Behind the ridge: toward the house's back, which for a house facing
    # north is to +z.)
    back = 1.0 if abs(corner.yaw - 180.0) < 0.01 else -1.0

    for off in (0.6, 1.0, 1.5, 0.3, 2.0):
        z = (r[1] + r[3]) / 2.0 + back * off
        route = []

        try:
            for i, (a, b) in enumerate(runs):
                path = [(min(b, x) - 0.6, z), (max(a, end) + 0.6, z)]

                if i == 0:
                    path.insert(0, (min(b, x) - 0.6, sz))

                part = roof_route(boxes, path)

                if i > 0:
                    if part[0][1] - route[-1][1] > rules.LEAP_RISE:
                        raise ValueError("a leap up")

                    part[0][3] = "jump"

                route += part
        except ValueError:
            continue

        return route

    raise ValueError("no roof chain over %s" % [each.name for each in row])
