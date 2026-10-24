"""The old town's ways up its walls laid (plan B1a, Task 16b, the user's
playtest): the lead downpipes and the ivy where town.climbs puts them, and
their ways up; the thief's ways over the gardens' walls, along the Ribeira
houses' varandas and onto the Baixa's sacadas. Laid after the quarters
(over their houses and walls)."""

import math

import geo
import kit_recipes as kit
import kit_terrace
import kit_town

import town
from town import baixa, climbs as plan, judiaria, stairs


def world(at, yaw, local):
    return geo.add(list(at), geo.apply(geo.rotation(yaw), list(local[:3])))


def placed(at, yaw, points):
    return [world(at, yaw, p) + [p[3]] for p in points]


def checks(L, route, points, **props):
    sector = town.sector_of(points[0][0], points[0][2])

    for i, p in enumerate(points):
        L.mark("%s_%d" % (route, i + 1), "route_check", p[:3], 0.0, sector, route=route, order=i + 1, move=p[3], **props)


def lay(L):
    _pipes(L)
    _ivy(L)
    _garden_walls(L)
    _varandas(L)
    _sacadas(L)


def _boxes(L, names):
    """The colliders of the named pieces as laid."""
    return [b for p in L.pieces if p["name"] in names for b in geo.piece_boxes(kit.PIECES[p["piece"]], p["position"], p["basis"])]


def _top(boxes, x, z, under):
    """The highest top of `boxes` over (x, z) below `under`, or None."""
    hits = [t for t in (b.ray([x, under, z], [0.0, -1.0, 0.0]) for b in boxes) if t is not None]
    return under - min(hits) if hits else None


def _pipes(L):
    """Each quarter's pipes (town.climbs: PIPES of its party lines, spread,
    none where a lamp or a torch hangs on the line), and their ways: up one,
    onto the lower roof (over its parapet onto an azotea)."""
    lights = [m["position"] for m in L.markers if m["ucd"] == "light"]
    chosen = []

    for quarter, _plan in plan.QUARTERS:
        free = [p for p in plan.pipes() if p[0] == quarter
                and not any(math.hypot(q[0] - plan.side_of(p[1], 1.0)[0], q[2] - plan.side_of(p[1], 1.0)[1]) < 1.2 for q in lights)]
        chosen += [(n + 1,) + p for n, p in enumerate(plan.spread(free, plan.PIPES))]

    for n, quarter, a, _b, low, side, kind, height in chosen:
        at = world((a.x, a.y, a.z), a.yaw, [a.width / 2.0, 0.0, 0.0])
        name = kit_terrace.drainpipe(height)
        route = "%s_pipe_%d" % (quarter, n)
        L.put(name, at, a.yaw, town.sector_of(at[0], at[2]), name=route, climbs=True)
        # (Up it on the lower house's side of the line, onto its roof (or its
        # parapet's top, down onto its azotea), clear of what stands on the
        # line: a Pombaline firewall 0.5 m thick, the higher house's wall.)
        tour = kit.PIECES[name]["tour"][:-1]
        tour = placed(at, a.yaw, tour[:-1] + [[side * 0.3] + tour[-1][1:]])
        inward = side * 1.15

        if kind == "parapet":
            tour += placed(at, a.yaw, [[inward, height, -0.25, "mantle"], [inward, height - kit_town.PARAPET, -1.6, "drop"]])
        else:
            boxes = _boxes(L, {low.name})
            ups = [world(at, a.yaw, [inward, 0.0, z]) for z in (-0.8, -1.8)]
            tops = [_top(boxes, p[0], p[2], a.y + height + 4.0) for p in ups]

            if None in tops:
                raise ValueError("%s: no roof behind its top" % route)

            tour += [[ups[0][0], tops[0], ups[0][2], "mantle"], [ups[1][0], tops[1], ups[1][2], "walk"]]

        checks(L, route, tour, way="thief")


def _ivy(L):
    """The Judiaria's ivy (town.climbs) up a step behind a garden and up its
    west cliff: its way up, over the parapet onto the terrace above."""
    t = kit_terrace.PARAPET[1]

    for n, each in enumerate(plan.ivy()):
        at, yaw, rise = each["at"], each["yaw"], each["rise"]
        name = kit_terrace.ivy(plan.IVY_WIDTH, rise)
        route = "judiaria_ivy_%d" % (n + 1)
        L.put(name, at, yaw, town.sector_of(at[0], at[2]), name=route, climbs=True)
        tour = placed(at, yaw, kit.PIECES[name]["tour"])[:-1]
        tour += placed(at, yaw, [[0.0, rise, -t / 2.0, "mantle"], [0.0, rise - each["parapet"], -1.6, "drop"]])
        checks(L, route, tour, way="thief", step=each["step"])


def _garden_walls(L):
    """Over a garden's front from its lane, beside its gate: mantled from
    the lane, dropped inside."""
    # (Wide enough for a run of wall beside its gateway, deep enough to
    # drop into.)
    fronts = [w for w in judiaria.WALLS["garden"] if w["kind"] == "yard_front" and w["args"][0] >= 5.0 and _garden_depth(w) >= 2.5]

    for n, w in enumerate(plan.spread(fronts, 2)):
        width = w["args"][0]
        at, yaw = w["at"], w["yaw"]
        # (Over the middle of its run of wall, clear of the gateway's pier
        # and of the garden's side wall, down which a man would walk.)
        gate = min(1.4, width - 1.0)
        span = gate + 2.0 * min(kit_terrace.GATEWAY[1], (width - gate) / 2.0)
        x = (span / 2.0 + width / 2.0) / 2.0
        top = kit_terrace.YARD_WALL[0] + 0.1
        route = "judiaria_garden_%d" % (n + 1)
        checks(L, route, placed(at, yaw, [[x, 0.0, 1.5, "walk"], [x, top, -kit_terrace.YARD_WALL[1] / 2.0, "mantle"], [x, 0.0, -1.5, "drop"]]),
               way="thief")


def _garden_depth(w):
    """How deep a garden is behind its front `w`, to its terrace's edge."""
    plate = [p for p in judiaria.PLATES if abs(judiaria.level(p) - w["at"][1]) < 0.01][0]
    back = judiaria.north(plate) if abs(w["yaw"]) < 0.01 else judiaria.south(plate)
    return abs(back - w["at"][2])


def _varandas(L):
    """Along a Ribeira house's varanda, hung from the street: grabbed at one
    end, shimmied to the other, let go."""
    lots = [each for each in stairs.LOTS if each.family == "porto" and each.storeys >= 2 and each.quirk in ("", "dormer") and each.width >= 4.5
            and abs(each.yaw % 180.0) < 0.01]

    for n, each in enumerate(plan.spread(sorted(lots, key=lambda e: e.x), 2)):
        design = kit.PIECES[town.design_key(each)]
        _x, top, wide, deep = [b for b in design["balconies"] if abs(b[0]) < 0.01][0]
        a, b = -wide / 2.0 + 0.5, wide / 2.0 - 0.5
        route = "stairs_varanda_%d" % (n + 1)
        checks(L, route, placed((each.x, each.y, each.z), each.yaw, [[a, 0.0, 1.6, "walk"], [a, top, deep - 0.08, "grab"], [b, top, deep - 0.08, "shimmy"],
                                                                   [b, 0.0, 1.6, "drop"]]), way="thief")


def _sacadas(L):
    """Onto a Baixa front's sacada from the street: grabbed, let go."""
    lots = [each for each in baixa.LOTS if each.family == "pombal" and abs(each.yaw % 180.0) < 0.01]

    for n, each in enumerate(plan.spread(sorted(lots, key=lambda e: e.x), 2)):
        design = kit.PIECES[town.design_key(each)]

        if not design["balconies"]:
            continue

        x, top, _wide, deep = design["balconies"][0]
        route = "baixa_sacada_%d" % (n + 1)
        checks(L, route, placed((each.x, each.y, each.z), each.yaw, [[x, 0.0, 1.6, "walk"], [x, top, deep - 0.08, "grab"], [x, 0.0, 1.6, "drop"]]),
               way="thief")
