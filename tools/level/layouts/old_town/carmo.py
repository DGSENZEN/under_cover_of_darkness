"""The Carmo hill laid (the old town's spec, sections 4.3, 4.4 and 16; plan
B1a, Task 17): its rows are the lot plan's (town/carmo.py, placed with the
rest); here its cliff over the Rossio and the towers and ledges up it, its
terraces' walls, stairs and parapets; the burned church, its axis on the
comet, the comet's light on its altar, the watch's shunned nave; the watch
house its convent, its household and its three ways in; the lookout's
pergola, benches and lamp posts; the Largo's fountain; the roof chains,
lamps, vantages, zones and ways."""

import geo
import kit_recipes as kit
import kit_terrace
import kit_town
import kit_watch

import town
from old_town.baixa import roof_route
from town import carmo as plan


def _sector(x, z):
    return town.sector_of(x, z)


def world(at, yaw, local):
    return geo.add(list(at), geo.apply(geo.rotation(yaw), list(local[:3])))


def placed(at, yaw, points):
    """A piece's points [x, y, z, move] (its tour, its ways) in the world."""
    return [world(at, yaw, p) + [p[3]] for p in points]


def checks(L, route, points, **props):
    """A route's checks: points [x, y, z, move] in order, each saying what
    the route is."""
    sector = _sector(points[0][0], points[0][2])

    for i, p in enumerate(points):
        L.mark("%s_%d" % (route, i + 1), "route_check", p[:3], 0.0, sector, route=route, order=i + 1, move=p[3], **props)


def piece(w):
    return getattr(kit_terrace, w["kind"])(*w["args"])


def lay(L):
    for group, walls in plan.WALLS.items():
        for i, w in enumerate(walls):
            name = piece(w)
            x, y, z = w["at"]
            L.put(name, (x, y, z), w["yaw"], _sector(x, z), name="carmo_%s_%d" % (group, i + 1), climbs=bool(kit.PIECES[name].get("climbs")))

    _ruin(L)
    _watch(L)
    _lookout(L)
    _largo(L)
    _steps(L)
    _chains(L)
    _office_pipe(L)
    _lamps(L)
    _vantages(L)
    _zones(L)


def _ruin(L):
    """The church along its axis, its buttresses; the watch's shunned box
    over its nave; the comet's light on its altar (Task 20 hangs the shaft
    along the comet's direction, aimed at this marker)."""
    sector = "carmo"

    for i, (name, at, _s) in enumerate(plan.ruin_parts()):
        L.put(name, at, plan.RUIN_YAW, sector, name="carmo_ruin_%d" % (i + 1))

    for i, at in enumerate(plan.buttresses()):
        L.put("carmo_buttress", at, plan.RUIN_YAW, sector, name="carmo_buttress_%d" % (i + 1))

    L.mark("carmo_nave", "shunned", plan.ruin_at([0.0, 12.0, -27.5]), plan.RUIN_YAW, sector, size=[25.2, 24.0, 52.0], label="the ruin's nave")
    altar = plan.apse_at(kit.PIECES["carmo_apse"]["places"]["altar"])
    L.mark("carmo_altar_comet", "light", altar, plan.RUIN_YAW, sector, kind="comet_shaft")


def _watch(L):
    """The watch house beside the apse, turned with the church: its doors,
    its household and its three ways in, its beds kept, its places."""
    at, yaw = (plan.WATCH[0], plan.SQUARE, plan.WATCH[1]), plan.WATCH_YAW
    sector = _sector(at[0], at[2])
    recipe = kit.PIECES["watch_house"]
    L.put("watch_house", at, yaw, sector, name="carmo_watch_house", climbs=True)

    for i, d in enumerate(recipe["doors"]):
        L.mark("carmo_watch_door_%d" % (i + 1), "door", world(at, yaw, d), yaw + d[3], sector)

    # (From a little under its floor, where its ways end, to its eaves.)
    middle = world(at, yaw, [0.0, (kit_watch.EAVES - 0.5) / 2.0, -kit_watch.DEPTH / 2.0])
    L.mark("carmo_watch_house_household", "household", middle, yaw, sector, size=[kit_watch.WIDTH, kit_watch.EAVES + 0.5, kit_watch.DEPTH],
           label="watch_house", ways=3)

    for way in recipe["ways"]:
        checks(L, "carmo_watch_way_%s" % way["kind"], placed(at, yaw, way["points"]), into="watch_house", kind=way["kind"])

    for i, bed in enumerate(recipe["beds"]):
        L.mark("carmo_watch_bed_%d" % (i + 1), "home", world(at, yaw, bed), yaw, sector, label="watch_house")

    for name, p in sorted(recipe["places"].items()):
        L.mark("carmo_watch_%s" % name, "mark", world(at, yaw, p), yaw, sector)


def _lookout(L):
    """The miradouro: its pergola against the square's wall, benches along
    its parapet facing the view and under the pergola, its two lamp posts
    (lit on dark nights only)."""
    x0, x1, depth = plan.PERGOLA
    y = plan.LOOK
    L.put("pergola", ((x0 + x1) / 2.0, y, plan.STEP_Z + depth / 2.0 + 0.3), 0.0, "carmo", name="carmo_pergola")

    for i, x in enumerate(plan.BENCHES):
        under = x0 < x < x1
        z = plan.STEP_Z + 1.2 if under else plan.CLIFF_Z - 1.3
        L.put("bench_azulejo", (x, y, z), 0.0, "carmo", name="carmo_bench_%d" % (i + 1))

    for i, x in enumerate(plan.LAMP_POSTS):
        L.mark("carmo_lookout_lamp_%d" % (i + 1), "light", (x, y, -178.0), 0.0, "carmo", kind="lamp_post", dark_only=True)


def _largo(L):
    """The dolphin fountain under its canopy in the Largo; its water masks
    a man near it."""
    x, z = plan.FOUNTAIN
    at = (x, plan.SQUARE, z)
    L.put("fountain_carmo", at, 0.0, "carmo", name="carmo_fountain")
    water = world(at, 0.0, kit.PIECES["fountain_carmo"]["sockets"]["water"][0])
    L.mark("carmo_fountain_noise", "noise_zone", water, 0.0, "carmo", size=[8.0, 4.0, 8.0], db=45.0, label="the dolphin fountain")


def _steps(L):
    """The three steps' boxes and their ways: the Rossio's towers (public)
    and ledges (a thief's) up the cliff onto the lookout; the lookout's
    stair-lanes (public) and a hang over its parapet (a thief's) onto the
    square; the square's wall stairs (public) and ledges (a thief's) onto
    the high terrace."""
    middle = (plan.WEST + plan.EAST) / 2.0
    width = plan.EAST - plan.WEST

    for label, y0, y1, z in (("carmo_step_baixa", plan.BAIXA_G, plan.LOOK, plan.CLIFF_Z), ("carmo_step_1", plan.LOOK, plan.SQUARE, plan.STEP_Z),
                             ("carmo_step_2", plan.SQUARE, plan.HIGH, plan.HIGH_Z)):
        L.mark(label, "terrace_step", (middle, (y0 + y1) / 2.0, z), 0.0, _sector(middle, z), size=[width, y1 - y0 + 2.0, 6.0], label=label,
               public=2, thief=1)

    for n, w in enumerate(plan.WALLS["towers"]):
        tour = placed(w["at"], w["yaw"], kit.PIECES[piece(w)]["tour"])
        last = tour[-1]
        checks(L, "carmo_tower_%d" % (n + 1), tour + [[last[0], plan.LOOK, plan.CLIFF_Z - 3.0, "walk"]], way="public", step="carmo_step_baixa")

    for w in plan.WALLS["ledges"]:
        tour = placed(w["at"], w["yaw"], kit.PIECES[piece(w)]["tour"])
        last = tour[-1]
        top = plan.LOOK if w["step"] == "carmo_step_baixa" else plan.HIGH
        z = (plan.CLIFF_Z if w["step"] == "carmo_step_baixa" else plan.HIGH_Z) - 2.0
        checks(L, "carmo_ledges_%s" % w["step"].split("_")[-1], tour + [[last[0], top, z, "walk"]], way="thief", step=w["step"])

    for n, w in enumerate(plan.WALLS["stair1"]):
        tour = placed(w["at"], w["yaw"], kit.PIECES[piece(w)]["tour"])
        last = tour[-1]
        checks(L, "carmo_step_1_lane_%d" % (n + 1), tour + [[last[0], plan.SQUARE, plan.STEP_Z - 2.0, "walk"]], way="public", step="carmo_step_1")

    x, top = plan.STEP1_HANG, plan.SQUARE + kit_terrace.PARAPET[0]
    checks(L, "carmo_step_1_hang", [[x, plan.LOOK, plan.STEP_Z + 2.0, "walk"], [x, top, plan.STEP_Z - kit_terrace.PARAPET[1] / 2.0, "hang"],
                                    [x, plan.SQUARE, plan.STEP_Z - 1.6, "drop"]], way="thief", step="carmo_step_1")

    for n, w in enumerate(plan.WALLS["stair2"]):
        tour = placed(w["at"], w["yaw"], kit.PIECES[piece(w)]["tour"])
        last = tour[-1]
        checks(L, "carmo_step_2_lane_%d" % (n + 1), tour + [[last[0], plan.HIGH, plan.HIGH_Z - 2.0, "walk"]], way="public", step="carmo_step_2")


def _chains(L):
    """Two roof chains: up a scaffold on the south row's west corner and
    east along its back slope over the lookout; up a scaffold on the high
    row and east along its back slope under the upper town's cliff."""
    scaffold = kit_terrace.scaffold(plan.EAVES, plan.SCAFFOLD_WIDTH)
    recipe = kit.PIECES[scaffold]
    named = {each.name: each for each in plan.LOTS}
    s1, h2 = named["carmo_s_1"], named["carmo_h_2"]
    back_s = plan.SOUTH_ROW[2] + plan.DEPTH - 2.5
    back_h = plan.HIGH_ROW[2] - plan.DEPTH + 2.5
    # (The south row's off its corner's middle, where a dormer stands; to
    # the east, the Largo open round its end.)
    xs = s1.x + 2.5
    chains = [(s1, xs, [(xs, s1.z + 0.6), (xs, back_s), (plan.SOUTH_ROW[0] + 30.0, back_s)], "carmo_s_"),
              (h2, h2.x, [(h2.x, h2.z - 0.6), (h2.x, back_h), (h2.x + 49.0, back_h)], "carmo_h_")]

    for n, (lot, x, path, row) in enumerate(chains):
        at = (x, lot.y, lot.z)
        sector = _sector(x, lot.z)
        L.put(scaffold, at, lot.yaw, sector, name="carmo_scaffold_%d" % (n + 1), climbs=True)
        up = placed(at, lot.yaw, recipe["tour"])
        lots = {each.name for each in plan.LOTS if each.name.startswith(row)}
        boxes = [b for p in L.pieces if p["name"] in lots for b in geo.piece_boxes(kit.PIECES[p["piece"]], p["position"], p["basis"])]
        checks(L, "roof_carmo_%d" % (n + 1), up + roof_route(boxes, path), way="roof")
        L.mark("carmo_vantage_deck_%d" % (n + 1), "vantage", world(at, lot.yaw, [0.0, recipe["top"], kit_terrace.DECK_OFF + kit_terrace.DECK / 2.0]),
               lot.yaw + 180.0, sector)


def _office_pipe(L):
    """A lead pipe up the convent's office's front at its far corner, onto
    its parapet and down onto its azotea (where the watch house's roof way
    starts): a thief's."""
    office = [each for each in plan.LOTS if each.name == "carmo_office"][0]
    height = 8.6
    name = kit_terrace.drainpipe(height)
    at = world((office.x, office.y, office.z), office.yaw, [office.width / 2.0, 0.0, 0.0])
    L.put(name, at, office.yaw, _sector(at[0], at[2]), name="carmo_pipe_1", climbs=True)
    tour = kit.PIECES[name]["tour"][:-1]
    tour = placed(at, office.yaw, tour[:-1] + [[-0.3] + tour[-1][1:]])
    tour += placed(at, office.yaw, [[-1.15, height, -0.25, "mantle"], [-1.15, height - kit_town.PARAPET, -1.6, "drop"]])
    checks(L, "carmo_pipe_1", tour, way="thief")


def _lamps(L):
    """Corner lamps on the fronts and the square's north wall, their two
    lanterns lit on dark nights only."""
    for i, (x, y, z, yaw) in enumerate(plan.LAMPS):
        name = "carmo_lamp_%d" % (i + 1)
        L.put("corner_lamp", (x, y, z), yaw, _sector(x, z), name=name)

        for side, hook in zip("ab", kit.PIECES["corner_lamp"]["sockets"]["lamp"]):
            L.mark("%s_%s" % (name, side), "light", world((x, y, z), yaw, hook), yaw, _sector(x, z), kind="lantern", dark_only=True)


def _vantages(L):
    """Unlit spots to scout from: each tower's top over the cliff, each
    run of ledges' top, each wall stair's landing, the watch house's roof
    lookout."""
    out = []

    for w in plan.WALLS["towers"]:
        top = world(w["at"], w["yaw"], kit.PIECES[piece(w)]["top"])
        out.append([top[0], plan.LOOK, plan.CLIFF_Z - 1.2])

    for w in plan.WALLS["ledges"]:
        last = placed(w["at"], w["yaw"], kit.PIECES[piece(w)]["tour"])[-1]
        out.append([last[0], last[1], last[2]])

    for w in plan.WALLS["stair2"]:
        head = world(w["at"], w["yaw"], kit.PIECES[piece(w)]["head"])
        out.append([head[0] - 0.7, plan.HIGH, plan.HIGH_Z - 1.0])

    out.append(world((plan.WATCH[0], plan.SQUARE, plan.WATCH[1]), plan.WATCH_YAW, kit.PIECES["watch_house"]["places"]["lookout"]))

    for i, at in enumerate(out):
        L.mark("carmo_vantage_%d" % (i + 1), "vantage", at, 0.0, _sector(at[0], at[2]))


def _zones(L):
    """The quarter outside (the ruin's nave too: roofless); inside the
    watch house."""
    x0, z0, x1, z1 = town.QUARTERS["carmo"]
    L.mark("carmo_zone", "zone", ((x0 + x1) / 2.0, 45.0, (z0 + z1) / 2.0), 0.0, "carmo", size=[x1 - x0, 50.0, z1 - z0], grade="outside")
    middle = plan.watch_point([0.0, kit_watch.EAVES / 2.0, -kit_watch.DEPTH / 2.0])
    L.mark("carmo_zone_watch", "zone", middle, plan.WATCH_YAW, "carmo", size=[kit_watch.WIDTH, kit_watch.EAVES, kit_watch.DEPTH], grade="indoors")
