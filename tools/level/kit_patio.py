"""The patio house and the corral (the old town's spec, section 5.2;
old_town_spain.md's kit and sections 2-4): the Judiaria's houses turned
inward behind blank whitewashed walls, generated on kit_town's grammar.

A blank front (at most 15% of it open: a street door, a grilled window or
two) on the lane; inside it the hall (the zaguan), the street door at one
end and the iron gate (the cancela) onto the patio at the other, so no one
sees in from the lane; the patio, a quarter of the lot or more, open to the
sky, its well-head in the middle; rooms round it in ranges RANGE deep, each
with its door off the patio; over them a storage loft (sealed) under the
flat roof, the azotea, walled by a PARAPET, reached from the patio by a
ladder up its wall: the Judiaria's second roof highway.

    small     6 x 18: the hall, the patio, a back room
    merchant  10 x 25: and a side range of two rooms, a lookout (mirador)
    corral    16 x 20: the tenement court, cells of 3 x 4 down both sides
    corner    8 x 8, one storey: the hall, a room, a small patio

An honest one is solid, its patio under an awning stretched over it (the
roof walked across it). The piece's frame: x along its front, the front's
face at z 0, the house to -z, its foot on the lane.
"""

import random

import kit_recipes as k  # noqa: F401 (first: it registers every kit)
import kit_shapes as ks
import kit_town as town

LOTS = {"small": (6.0, 18.0), "merchant": (10.0, 25.0), "corral": (16.0, 20.0), "corner": (8.0, 8.0)}
KINDS = tuple(LOTS)
QUIRKS = ("", "linked", "lookout", "bridge", "shrine")
WALL = 0.5
INNER_WALL = 0.3
GROUND = 4.0
UPPER = 3.6
RANGE = 4.0
CORNER_RANGE = 3.0
CELL = 3.0
STREET_DOOR = (2.2, 3.2)
SMALL_DOOR = (1.6, 2.6)
CANCELA = (1.6, 2.6)
GRILLE = (0.8, 1.2, 1.5)
WINDOW = (0.9, 1.4, 1.0)
WELL = 1.0
MIRADOR = (2.5, 2.5, 3.0)
BRIDGE = (3.0, 4.0)
LINK = 1.4
LADDER_GAP = 1.0
BUDGET = {"small": 2400, "corner": 2400, "merchant": 3600, "corral": 3600}


def _plan(kind, ix0, ix1, iz0, iz1):
    """The ground floor's rooms (x0, z0, x1, z1): the hall first, the patio
    second, then the rest; the side the ladder climbs from the patio."""
    r = CORNER_RANGE if kind == "corner" else RANGE
    hall = (ix0, iz1 - r, ix1, iz1)

    if kind == "small":
        return [hall, (ix0, iz0 + r, ix1, iz1 - r), (ix0, iz0, ix1, iz0 + r)], "back", []

    if kind == "merchant":
        zm = (iz1 - r + iz0 + r) / 2.0
        return [hall, (ix0 + r, iz0 + r, ix1, iz1 - r), (ix0, zm, ix0 + r, iz1 - r), (ix0, iz0 + r, ix0 + r, zm),
                (ix0, iz0, ix1, iz0 + r)], "back", []

    if kind == "corner":
        return [hall, (ix0 + r, iz0, ix1, iz1 - r), (ix0, iz0, ix0 + r, iz1 - r)], "left", []

    # The corral: cells CELL along each side, the court between them to the
    # back wall.
    cells = []
    z = iz1 - r

    while z - CELL >= iz0 - 1e-6:
        cells += [(ix0, z - CELL, ix0 + r, z), (ix1 - r, z - CELL, ix1, z)]
        z -= CELL

    return [hall, (ix0 + r, iz0, ix1 - r, iz1 - r)] + cells, "left", cells


def _edge(a, b):
    """The middle of the edge rooms a and b share, or None."""
    eps = 1e-6

    for xa, xb in ((a[2], b[0]), (b[2], a[0])):
        lo, hi = max(a[1], b[1]), min(a[3], b[3])

        if abs(xa - xb) < eps and hi - lo > 1.0:
            return (xa, (lo + hi) / 2.0)

    for za, zb in ((a[3], b[1]), (b[3], a[1])):
        lo, hi = max(a[0], b[0]), min(a[2], b[2])

        if abs(za - zb) < eps and hi - lo > 1.0:
            return ((lo + hi) / 2.0, za)

    return None


def design(width, depth, kind="small", quirk="", enterable=True, front="whitewash", side="whitewash", seed=0):
    """A patio house: see the module's doc. A kit_town design with
    `openings`, `patio`, `cells`, `eaves`, `doors`, `entries`, `rooms_at`,
    `tour`, `climbs`, `places`."""
    if kind not in KINDS or quirk not in QUIRKS:
        raise ValueError("no patio house %s / %s" % (kind, quirk))

    rng = random.Random(seed * 4241 + int(width) * 29 + int(depth))
    storeys = 1 if kind == "corner" else 2
    eaves = GROUND + (UPPER if storeys == 2 else 0.0)
    ix0, ix1, iz0, iz1 = -width / 2.0 + WALL, width / 2.0 - WALL, -(depth - WALL), -WALL
    plan, ladder_side, cells = _plan(kind, ix0, ix1, iz0, iz1)
    hall, patio = plan[0], plan[1]
    out = {"openings": [], "doors": [], "entries": [], "places": {}, "eaves": eaves, "patio": patio, "cells": cells, "climbs": [],
           "budget": BUDGET[kind]}
    shapes, cols = [], []

    # The front: its door near one end, a grilled window or two, blank.
    door_w, door_h = SMALL_DOOR if width < 9.0 else STREET_DOOR
    dx = ix0 + door_w / 2.0 + 0.4
    openings = [town.Opening(dx, 0.0, door_w, door_h, "door" if enterable else "barred")]

    # (A corner house's single storey shows its door alone, its shrine on its
    # corner.)
    for i in range(0 if kind == "corner" else 1 if width < 9.0 else 2):
        gx = ix1 - 1.2 - i * 3.0
        openings.append(town.Opening(gx, GRILLE[2], GRILLE[0], GRILLE[1], "shut"))
        shapes += [ks.card(gx, GRILLE[2] + GRILLE[1] / 2.0, 0.3, GRILLE[0] + 0.1, GRILLE[1] + 0.1, "window_grille"),
                   ks.box(gx, GRILLE[2] - 0.05, 0.15, GRILLE[0] + 0.2, 0.08, 0.32, "iron")]

    for o in openings:
        out["openings"].append([0, "front", o.x, o.y, o.width, o.height, o.kind])

    s, c = town.wall(width, eaves, WALL, openings, front, (0.0, -WALL / 2.0, 0.0), frames=False, inside=enterable)
    shapes += s
    walls = c
    s, c = town.wall(width, eaves, WALL, [], side, (0.0, -depth + WALL / 2.0, 180.0), frames=False, inside=enterable)
    shapes += s
    walls += c

    for sx in (-1.0, 1.0):
        x = sx * (width / 2.0 - WALL / 2.0)
        shapes.append(ks.box(x, eaves / 2.0, -depth / 2.0, WALL, eaves, depth, side))
        cols.append(town.col(x, eaves / 2.0, -depth / 2.0, WALL, eaves, depth))

    if enterable:
        _inside(out, shapes, cols, plan, ladder_side, kind, dx, door_w, eaves, storeys, rng, side)
        cols += walls
    else:
        cols.append(town.col(0.0, eaves / 2.0, -depth / 2.0, ix1 - ix0, eaves, iz1 - iz0))

    _roof(out, shapes, cols, plan, width, depth, eaves, enterable, ladder_side, quirk)
    _quirk(out, shapes, cols, quirk, kind, width, depth, eaves, plan)

    if kind == "merchant" and quirk != "lookout":
        _quirk(out, shapes, cols, "lookout", kind, width, depth, eaves, plan)

    out.update({"shapes": shapes, "cols": cols, "size": [width, eaves + 4.0, depth], "front": front})
    return out


def _inside(out, shapes, cols, plan, ladder_side, kind, dx, door_w, eaves, storeys, rng, slot):
    """An enterable patio house's ground floor (its floors, the walls
    between its rooms, their doors off the patio, the cancela), the loft
    over it sealed, the patio's walls up to the roof, its well; its doors,
    rooms' places, ladder and tour."""
    hall, patio = plan[0], plan[1]
    px0, pz0, px1, pz1 = patio
    cancela = max(dx + door_w / 2.0 + 0.9 + CANCELA[0] / 2.0, px0 + CANCELA[0] / 2.0 + 0.3)
    openings = [(cancela, pz1, CANCELA[0], CANCELA[1], "door")]
    live_rooms = []

    for i, room in enumerate(plan[2:], start=2):
        edge = _edge(room, patio)

        if edge is None:
            continue

        # (The corral's cells shut but its first; every other room open.)
        live = kind != "corral" or i == 2
        openings.append((edge[0], edge[1], town.ROOM_DOOR[0], town.ROOM_DOOR[1], "door" if live else "shut"))

        if live:
            live_rooms.append((room, edge))

    s, c = town.rooms(plan, 0.0, GROUND, openings, slot, "stone", INNER_WALL)
    shapes += s
    cols += c

    # Floors: the patio's tiles, the rooms' flags; over the rooms a ceiling
    # and the loft over it sealed to the roof.
    for i, room in enumerate(plan):
        w, d = room[2] - room[0], room[3] - room[1]
        cx, cz = (room[0] + room[2]) / 2.0, (room[1] + room[3]) / 2.0
        s, c = town.floors(w, d, [0.0], None, "terracotta" if i == 1 else "flagstone", "stone")
        s, c = town.placed(s, c, cx, cz)
        shapes += s
        cols += c

        if i != 1:
            shapes.append(ks.box(cx, GROUND - 0.1, cz, w, 0.2, d, "beam"))

            if storeys == 2:
                cols.append(town.col(cx, (GROUND + eaves) / 2.0, cz, w, eaves - GROUND, d))

    # Over the ground floor, the patio's walls go up to the roof: their
    # windows shut or lit.
    if storeys == 2:
        upper = []

        for room in plan[2:] + [plan[0]]:
            edge = _edge(room, patio)

            if edge is not None:
                upper.append((edge[0], edge[1], WINDOW[0], WINDOW[1], "lit" if rng.random() < 0.3 else "shut", WINDOW[2]))

        s, c = town.rooms(plan, GROUND, UPPER, upper, slot, "stone", INNER_WALL, only=1, inside=False)
        shapes += s
        cols += c

    # The well-head in the patio's middle.
    mx, mz = (px0 + px1) / 2.0, (pz0 + pz1) / 2.0
    shapes += [ks.prism(mx, WELL / 2.0, mz, 0.55, WELL, 8, "granite"), ks.box(mx, 2.0, mz, 0.08, 2.0, 1.2, "iron")]
    cols.append(town.col(mx, WELL / 2.0, mz, 1.1, WELL, 1.1))
    # (Each door hung its opening's size.)
    front = [o for o in out["openings"] if o[6] == "door"][0]
    out["doors"].insert(0, [dx, 0.0, -WALL / 2.0, 0.0, front[4], front[5]])
    out["doors"].append([cancela, 0.0, pz1, 0.0, CANCELA[0], CANCELA[1]])
    out["entries"].insert(0, "door")
    patio_at = [mx + 1.5 if px1 - px0 > 4.0 else mx, 0.0, mz - 1.5]
    out["rooms_at"] = [patio_at] + [[(r[0] + r[2]) / 2.0, 0.0, (r[1] + r[3]) / 2.0] for r, _e in live_rooms]
    hall_z = (hall[1] + hall[3]) / 2.0
    tour = [[dx, 0.0, 1.0, "walk"], [dx, 0.0, hall_z, "walk"], [cancela, 0.0, hall_z, "walk"], [cancela, 0.0, pz1 - 0.8, "walk"],
            patio_at + ["walk"]]

    for room, edge in live_rooms:
        tour += [[edge[0], 0.0, edge[1], "walk"], [(room[0] + room[2]) / 2.0, 0.0, (room[1] + room[3]) / 2.0, "walk"],
                 [edge[0], 0.0, edge[1], "walk"], patio_at + ["walk"]]

    # The ladder up the patio's wall to the azotea, through a gap in the
    # parapet round the patio.
    if ladder_side == "back":
        lx, lz = mx, pz0
        out["climbs"].append([lx, (eaves + 1.0) / 2.0, lz, 0.8, eaves + 1.0, 1.2, 0.0])
        foot, top = [lx, 0.0, lz + 0.6], [lx, eaves, lz - 0.7]
    else:
        lx, lz = px0, mz
        out["climbs"].append([lx, (eaves + 1.0) / 2.0, lz, 0.8, eaves + 1.0, 1.2, 90.0])
        foot, top = [lx + 0.6, 0.0, lz], [lx - 0.7, eaves, lz]

    shapes += [ks.box(lx + (0.0 if ladder_side == "back" else 0.18), (eaves + 1.0) / 2.0, lz + (0.18 if ladder_side == "back" else 0.0),
                      0.6 if ladder_side == "back" else 0.06, eaves + 1.0, 0.06 if ladder_side == "back" else 0.6, "timber")]
    out["places"]["ladder"] = [lx, 0.0, lz]
    out["tour"] = tour + [foot + ["walk"], top + ["climb"]]


def _roof(out, shapes, cols, plan, width, depth, eaves, enterable, ladder_side, quirk):
    """The azotea: a floor at the eaves over the rooms (over the patio too,
    on an honest house, under an awning), a PARAPET round its edge and the
    patio's, gaps where the ladder comes up and (linked) onto the
    neighbour's roof."""
    patio = plan[1]
    t = town.PARAPET_THICK
    rects = plan if not enterable else [r for i, r in enumerate(plan) if i != 1]

    for r in rects:
        w, d = r[2] - r[0], r[3] - r[1]
        s, c = town.floors(w, d, [eaves], None, "terracotta", "stone")
        s, c = town.placed(s, c, (r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)
        shapes += s
        cols += c

    # (The roof over the walls' tops, round the inner floors.)
    for x, z, w, d in ((0.0, -WALL / 2.0, width, WALL), (0.0, -depth + WALL / 2.0, width, WALL),
                       (-width / 2.0 + WALL / 2.0, -depth / 2.0, WALL, depth), (width / 2.0 - WALL / 2.0, -depth / 2.0, WALL, depth)):
        shapes.append(ks.box(x, eaves - town.SLAB / 2.0, z, w, town.SLAB, d, "terracotta"))
        cols.append(town.col(x, eaves - town.SLAB / 2.0, z, w, town.SLAB, d))

    if not enterable:
        px0, pz0, px1, pz1 = patio
        shapes.append(ks.card((px0 + px1) / 2.0, eaves + 0.02, (pz0 + pz1) / 2.0, px1 - px0, pz1 - pz0, "sailcloth", 0.0, 90.0))

    # Parapets: round the roof's edge (a gap for the linked neighbour), and
    # round the patio's (a gap at the ladder's head).
    link_z = (plan[0][1] + plan[0][3]) / 2.0
    edges = [(-width / 2.0, 0.0 - t / 2.0 + t, width / 2.0, -t, "x"), (-width / 2.0, -depth + t, width / 2.0, -depth, "x"),
             (-width / 2.0, 0.0, -width / 2.0 + t, -depth, "z"), (width / 2.0 - t, 0.0, width / 2.0, -depth, "z")]

    for i, (x0, z0, x1, z1, along) in enumerate(edges):
        gaps = [(link_z + LINK / 2.0, link_z - LINK / 2.0)] if quirk == "linked" and i == 3 else []
        _parapet(shapes, cols, x0, z0, x1, z1, along, eaves, gaps)

    if enterable:
        px0, pz0, px1, pz1 = patio
        lx, lz = out["places"]["ladder"][0], out["places"]["ladder"][2]
        back_gap = [(lx - LADDER_GAP / 2.0, lx + LADDER_GAP / 2.0)] if ladder_side == "back" else []
        left_gap = [(lz + LADDER_GAP / 2.0, lz - LADDER_GAP / 2.0)] if ladder_side == "left" else []
        _parapet(shapes, cols, px0, pz1 + t, px1, pz1, "x", eaves, [])
        _parapet(shapes, cols, px0, pz0, px1, pz0 - t, "x", eaves, back_gap)
        _parapet(shapes, cols, px0 - t, pz1, px0, pz0, "z", eaves, left_gap)
        _parapet(shapes, cols, px1, pz1, px1 + t, pz0, "z", eaves, [])

    if quirk == "linked":
        out["places"]["link"] = [width / 2.0, eaves, link_z]


def _parapet(shapes, cols, x0, z0, x1, z1, along, eaves, gaps):
    """A parapet PARAPET high over the roof along x (z0 to z1 its
    thickness) or along z, less `gaps` ((from, to) along it)."""
    if along == "x":
        runs = [(a0, a1) for a0, a1, _b0, _b1 in town.split(min(x0, x1), max(x0, x1), 0.0, 1.0, [(g[0], g[1], 0.0, 1.0) for g in gaps])]

        for a0, a1 in runs:
            box = ((a0 + a1) / 2.0, (z0 + z1) / 2.0, a1 - a0, abs(z1 - z0))
            shapes.append(ks.box(box[0], eaves + town.PARAPET / 2.0, box[1], box[2], town.PARAPET, box[3], "whitewash"))
            cols.append(town.col(box[0], eaves + town.PARAPET / 2.0, box[1], box[2], town.PARAPET, box[3]))
    else:
        lo, hi = min(z0, z1), max(z0, z1)
        runs = [(a0, a1) for a0, a1, _b0, _b1 in town.split(lo, hi, 0.0, 1.0, [(min(g), max(g), 0.0, 1.0) for g in gaps])]

        for a0, a1 in runs:
            box = ((x0 + x1) / 2.0, (a0 + a1) / 2.0, abs(x1 - x0), a1 - a0)
            shapes.append(ks.box(box[0], eaves + town.PARAPET / 2.0, box[1], box[2], town.PARAPET, box[3], "whitewash"))
            cols.append(town.col(box[0], eaves + town.PARAPET / 2.0, box[1], box[2], town.PARAPET, box[3]))


def _quirk(out, shapes, cols, quirk, kind, width, depth, eaves, plan):
    """The house's quirk: a lookout on its roof, a room bridging the lane,
    a shrine on its corner (linked is the roof's)."""
    if quirk == "lookout":
        w, d, h = MIRADOR
        x, z = -width / 2.0 + WALL + w / 2.0 + 0.3, -depth + WALL + d / 2.0 + 0.3
        shapes += [ks.box(x, eaves + h / 2.0, z, w, h, d, "whitewash"), ks.box(x, eaves + h + 0.1, z, w + 0.3, 0.2, d + 0.3, "terracotta")]

        for yaw in (0.0, 90.0, 180.0, 270.0):
            shapes += ks.moved([ks.card(0.0, eaves + h * 0.6, d / 2.0 + 0.02, w * 0.6, h * 0.5, "glass_dark")], yaw, (x, 0.0, z))

        cols.append(town.col(x, eaves + (h + 0.2) / 2.0, z, w + 0.3, h + 0.2, d + 0.3))
        out["places"]["lookout"] = [x, eaves + h + 0.2, z]
    elif quirk == "bridge":
        lane, clear = BRIDGE
        hall = plan[0]
        x, z, d = width / 2.0 + lane / 2.0, (hall[1] + hall[3]) / 2.0, hall[3] - hall[1]
        shapes += [ks.box(x, (clear + eaves) / 2.0, z, lane, eaves - clear, d, "whitewash"),
                   ks.box(x, clear - 0.15, z, lane, 0.3, d + 0.2, "timber")]
        cols += [town.col(x, (clear + eaves) / 2.0, z, lane, eaves - clear, d)]
        out["places"]["bridge"] = [x, 0.0, z]
    elif quirk == "shrine":
        x, y = -width / 2.0 + 0.7, 2.5
        shapes.append(ks.box(x, y + 0.45, 0.01, 0.62, 0.92, 0.04, "pitch"))
        out["places"]["shrine"] = [x, y, 0.05]


# (Its lots, if the kit was entered through this module and passed them by.)
town.register_town()
