"""The Baixa laid (the old town's spec, sections 4.3, 4.4 and 6; plan B1a,
Task 14): its blocks are the lot plan's (town/baixa.py, placed with the
rest); here its sewer under the main street and the two hatches down to
it, the scaffolds up three fronts still being rebuilt (each the watch's way
up to a roof chain, a scout's deck over a square), its lamps, the Rossio's
fountain, the comet's tiles inside the Sea Gate, its trades by street, its
zone; every way checked by its route."""

import math

import geo
import kit_recipes as kit
import kit_street
import kit_terrace
import rules

import town
from town import baixa as plan

G = plan.GROUND
STEP = 0.25
# Along a roof, a rise or fall more than this between two samples is a
# step (a fire wall, a higher roof), not a slope walked; a walk's point
# where its line leaves the roof by more than SLACK.
SLOPE = 0.2
SLACK = 0.15


def _sector(x, z):
    return town.sector_of(x, z)


def world(at, yaw, local):
    return geo.add(list(at), geo.apply(geo.rotation(yaw), local))


def checks(L, route, points, way, sector, **props):
    """A route's checks: points [x, y, z, move] in order."""
    for i, p in enumerate(points):
        L.mark("%s_%d" % (route, i + 1), "route_check", p[:3], 0.0, sector, route=route, order=i + 1, move=p[3], way=way, **props)


def lay(L):
    _sewer(L)
    _lamps(L)
    _chains(L)
    _places(L)


def _sewer(L):
    """The sewer under the main street: its vaults and the chambers under
    the hatches, walled at both ends (a grating toward the sea); the
    hatches with their collars; a way down each and along it."""
    x, floor = plan.SEWER_X, plan.SEWER_FLOOR
    sector = "baixa_s"

    for i, (kind, args, z) in enumerate(plan.sewer()):
        name = getattr(kit_terrace, kind)(*args)
        L.put(name, (x, floor, z), 0.0, _sector(x, z), name="baixa_sewer_%d" % (i + 1), climbs=kind == "hatch_chamber")

    end = kit_terrace.vault_end(*plan.SEWER_SIZE)
    L.put(end, (x, floor, plan.SEWER_Z[0] + 0.15), 180.0, sector, name="baixa_sewer_outfall")
    L.put(end, (x, floor, plan.SEWER_Z[1] - 0.15), 0.0, _sector(x, plan.SEWER_Z[1]), name="baixa_sewer_head")
    hatch = kit_terrace.grate_hatch(plan.HATCH_DEPTH, plan.COLLAR)
    ends = [plan.SEWER_Z[1] + 2.0, plan.SEWER_Z[0] - 2.0]

    for i, (hx, hz) in enumerate(plan.HATCHES):
        L.put(hatch, (hx, G, hz), 0.0, _sector(hx, hz), name="baixa_hatch_%d" % (i + 1), climbs=True)
        # (Down from its collar to the chamber's floor against its ladder,
        # then along the sewer to its far end.)
        ladder_x = x + plan.SEWER_SIZE[0] / 2.0 - 0.4
        checks(L, "below_baixa_%d" % (i + 1), [[hx - 1.2, G + kit_terrace.COLLAR_PROUD, hz, "walk"], [hx + 0.2, G - 0.2, hz, "climb"],
                                               [ladder_x, floor, hz - 0.3, "climb"],
                                               [x, floor, hz - 1.5 if i == 0 else hz + 1.5, "walk"], [x, floor, ends[i], "walk"]],
               "below", _sector(hx, hz))


def lamp(L, name, x, z, yaw):
    """A corner lamp on the front at (x, z) facing yaw, its two lanterns
    lit on dark nights only."""
    sector = _sector(x, z)
    L.put("corner_lamp", (x, G, z), yaw, sector, name=name)

    for side, hook in zip("ab", kit.PIECES["corner_lamp"]["sockets"]["lamp"]):
        L.mark("%s_%s" % (name, side), "light", world((x, G, z), yaw, hook), yaw, sector, kind="lantern", dark_only=True)


# The lamps: on the main street, the secondary and the street under the
# cliff, every 30-40 m from the Sea Gate's square to the Rossio, alternating
# sides; at the squares' mouths. (x, z, the way the front faces.)
LAMPS = [(plan.MAIN[0], -106.0, 90.0), (plan.MAIN[1], -140.0, -90.0), (plan.EAST[0], -108.0, 90.0), (plan.EAST[1], -142.0, -90.0),
         (plan.WEST[1], -110.0, -90.0), (plan.WEST[1], -143.0, -90.0), (-68.0, -104.0, 0.0), (-42.0, -104.0, 0.0), (-68.0, -150.0, 180.0),
         (-42.0, -150.0, 180.0)]


def _lamps(L):
    for i, (x, z, yaw) in enumerate(LAMPS):
        lamp(L, "baixa_lamp_%d" % (i + 1), x, z, yaw)


def _top(boxes, x, z):
    """The highest top of `boxes` over (x, z), or None."""
    hits = [t for t in (b.ray([x, 80.0, z], [0.0, -1.0, 0.0]) for b in boxes) if t is not None]
    return 80.0 - min(hits) if hits else None


def _walk(samples, ys, a, b):
    """A walk's points from sample a to b along a roof: one wherever the
    straight line from the last would leave the roof by SLACK."""
    out, last = [], a

    for j in range(a + 2, b + 1):
        for k in range(last + 1, j):
            t = (k - last) / float(j - last)

            if abs(ys[last] + (ys[j] - ys[last]) * t - ys[k]) > SLACK:
                out.append(j - 1)
                last = j - 1
                break

    if not out or out[-1] != b:
        out.append(b)

    return [[samples[k][0], ys[k], samples[k][1], "walk"] for k in out if k != a]


def roof_route(boxes, path):
    """A way over roofs along `path` [(x, z)], its first point mantled onto:
    the roofs' tops sampled every STEP; walked where they slope, mantled
    (or hung) up a step, dropped down one. [[x, y, z, move]]."""
    samples = []

    for (ax, az), (bx, bz) in zip(path, path[1:]):
        n = max(1, int(math.hypot(bx - ax, bz - az) / STEP))
        samples += [(ax + (bx - ax) * i / n, az + (bz - az) * i / n) for i in range(n)]

    samples.append(path[-1])
    ys = [_top(boxes, x, z) for x, z in samples]

    if any(y is None for y in ys):
        raise ValueError("a roof route off its roofs at %s" % (samples[ys.index(None)],))

    out = [[samples[0][0], ys[0], samples[0][1], "mantle"]]
    i, run = 0, 0

    while i < len(samples) - 1:
        dy = ys[i + 1] - ys[i]

        if abs(dy) <= SLOPE:
            i += 1
            continue

        out += _walk(samples, ys, run, i)
        # (Onto a step's top a little past its edge, or down off it.)
        land = i + 2 if i + 2 < len(samples) and abs(ys[i + 2] - ys[i + 1]) <= SLOPE else i + 1
        rise = ys[land] - ys[i]

        if rise > rules.HANG:
            raise ValueError("a roof route meets a step of %.2f m at %s" % (rise, samples[i]))

        out.append([samples[land][0], ys[land], samples[land][1], "drop" if rise < 0.0 else "mantle" if rise <= rules.MANTLE else "hang"])
        i = run = land

    out += _walk(samples, ys, run, len(samples) - 1)
    return out


# The roof chains: a scaffold up the side of a block's corner building (x,
# z on its face, the way it faces), onto its roof, along its side's eaves
# to the block's spine, then down the valley where the two rows' back
# slopes meet (out of the streets' sight, a fire wall to vault every few
# buildings), a little off the spine on its row's side. (block, the
# scaffold, the path after it.)
def _chain_plans():
    w, e, f = plan.BLOCKS["baixa_w"], plan.BLOCKS["baixa_e"], plan.BLOCKS["baixa_f"]
    # (Off the valley onto the rows' gentle slopes: a mansard's steep lower
    # slope comes down to it, on the blocks that keep theirs.)
    d, off = plan.DEPTH, 1.5
    return [("baixa_w", (w[0] + d / 2.0, w[3], 0.0), [(w[0] + d / 2.0, w[3] - 0.6), (w[0] + d - off, w[3] - 0.6), (w[0] + d - off, w[1] + 0.6)]),
            ("baixa_e", (e[2] - d / 2.0, e[1], 180.0), [(e[2] - d / 2.0, e[1] + 0.6), (e[2] - d + off, e[1] + 0.6), (e[2] - d + off, e[3] - 0.6)]),
            # (Down the east row's side.)
            ("baixa_f", (f[0] + d / 2.0, f[3], 0.0), [(f[0] + d / 2.0, f[3] - 0.6), (f[0] + d + off, f[3] - 0.6), (f[0] + d + off, f[3] - 46.0)])]


def _chains(L):
    scaffold = kit_terrace.scaffold(plan.EAVES, plan.SCAFFOLD_WIDTH)
    recipe = kit.PIECES[scaffold]

    for n, (block, (x, z, yaw), path) in enumerate(_chain_plans()):
        sector = _sector(x, z)
        name = L.put(scaffold, (x, G, z), yaw, sector, name="baixa_scaffold_%d" % (n + 1), climbs=True)
        up = [world((x, G, z), yaw, p[:3]) + [p[3]] for p in recipe["tour"]]
        # (Its foot on the street, which rises up the Rossio.)
        up = [[p[0], town.height(p[0], p[2]), p[2], p[3]] if abs(p[1] - G) < 1e-6 else p for p in up]
        lots = {each.name for each in plan.LOTS if each.name.startswith(block + "_")}
        boxes = [b for p in L.pieces if p["name"] in lots for b in geo.piece_boxes(kit.PIECES[p["piece"]], p["position"], p["basis"])]
        checks(L, "roof_baixa_%d" % (n + 1), up + roof_route(boxes, path), "roof", sector)
        # (Its top deck a scout's, railed and unlit.)
        L.mark("baixa_vantage_%d" % (n + 1), "vantage", world((x, G, z), yaw, [0.0, recipe["top"], kit_terrace.DECK_OFF + kit_terrace.DECK / 2.0]),
               yaw + 180.0, sector)
        assert name


def _places(L):
    # The Rossio's fountain on the main street's axis; its water masks the
    # player near it.
    x, z = (plan.MAIN[0] + plan.MAIN[1]) / 2.0, (plan.ROSSIO[1] + plan.ROSSIO[3]) / 2.0
    y = town.height(x, z)
    L.put("fountain_bowls", (x, y, z), 0.0, _sector(x, z), name="baixa_rossio_fountain")
    water = world((x, y, z), 0.0, kit.PIECES["fountain_bowls"]["sockets"]["water"][0])
    L.mark("baixa_fountain", "noise_zone", water, 0.0, _sector(x, z), size=[10.0, 4.0, 10.0], db=50.0, label="the Rossio's fountain")

    # The comet in the tiles inside the Sea Gate, on its passage's west
    # wall at the city's end.
    L.put("panel_comet", (-57.0, G + 1.3, -88.0), 90.0, "wall", name="baixa_sea_gate_comet")
    # A shrine to the forgotten king on the corner under the cliff, its lamp
    # burning all night.
    shrine = (plan.WEST[1], G, plan.BLOCKS["baixa_w"][3] - 0.8)
    L.put("shrine_alminha", shrine, -90.0, _sector(shrine[0], shrine[2]), name="baixa_shrine")
    L.mark("baixa_shrine_lamp", "light", world(shrine, -90.0, kit.PIECES["shrine_alminha"]["sockets"]["lamp"][0]), -90.0,
           _sector(shrine[0], shrine[2]), kind="candle", douse=True)

    # A baker's oven kept for the townsfolk, on the ground floor of the last
    # house walked in.
    bakery = [each for each in plan.LOTS if each.enterable][-1]
    oven = kit.PIECES[town.design_key(bakery)]["rooms_at"][0]
    L.mark("baixa_baker", "work", world((bakery.x, bakery.y, bakery.z), bakery.yaw, oven), bakery.yaw, _sector(bakery.x, bakery.z), kind="baker")

    # The trades by street (B1b's loot map): gold under the cliff, cloth on
    # the main street, silver on the secondary.
    for name, lane in (("trade_gold", plan.WEST), ("trade_cloth", plan.MAIN), ("trade_silver", plan.EAST)):
        mx = (lane[0] + lane[1]) / 2.0
        L.mark(name, "mark", (mx, G, -127.0), 0.0, _sector(mx, -127.0))

    x0, z0, x1, z1 = town.QUARTERS["baixa"]
    L.mark("zone_baixa", "zone", ((x0 + x1) / 2.0, G + 12.0, (z0 + z1) / 2.0), 0.0, "baixa_s", size=[x1 - x0, 24.0, z1 - z0], grade="outside")
