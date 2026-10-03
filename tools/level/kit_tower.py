"""The tower-house (the old town's spec, section 5.2; old_town_porto.md
section 9, old_town_spain.md section 6): the upper town's granite towers,
generated on kit_town's grammar.

Square, `side` across, WALL thick, STOREY a floor, one room a floor; lancets
in its faces, its door at the foot of its front; inside, straight steep
flights up alternate walls (a riser of RISER, as the kit's tower stair) to
its top.

    cut      cut down to its house's roof and a floor over it: a platform
             under a plain PARAPET (the upper town's roof platforms)
    full     to its full height under crenellations, machicolation boxes
             at its corners (the landmark: side 8, nine storeys, about 30 m)

Quirks: chute (a latrine chute up its right face, a ladder in it from the
lane to a hatch into its top room), dovecote (on its top).

The piece's frame: x along its front, the front's face at z 0, the tower to
-z, its foot on the street.
"""

import random

import kit_recipes as k  # noqa: F401 (first: it registers every kit)
import kit_shapes as ks
import kit_town as town

WALL = 1.0
STOREY = 3.3
RISER = 0.24
TREAD = 0.25
STAIR_WIDTH = 0.9
DOOR = (1.2, 2.2)
LANCET = (0.5, 1.4, 1.2)
MERLON = (0.8, 0.9)
CRENEL = 0.6
BASE = 0.8
MACHICOLATION = (1.4, 1.2, 0.5)
CHUTE = (1.0, 0.8)
HATCH = (0.7, 1.2)
DOVECOTE = (1.5, 1.2)
# A balcony on corbels, its door (balcony=).
BALCONY = (1.8, 1.0)
BALCONY_DOOR = (1.0, 2.1)
KINDS = ("cut", "full")
QUIRKS = ("", "chute", "dovecote")
# Triangles a storey walked in (its floor and flight) over its budget.
INSIDE = 250


def design(side=7.0, storeys=4, kind="cut", quirk="", enterable=False, front="granite", seed=0, balcony=None):
    """A tower-house: see the module's doc. A kit_town design with
    `openings`, `eaves`, `wall`, `doors`, `entries`, `rooms_at`, `tour`,
    (chute) `climbs` and `chute_tour`, `places`. `balcony` (face, storey[,
    along: its middle along the face's wall]):
    a machicolated balcony on that face at that storey, a door onto it
    (live in a tower walked in): places["balcony"] its outer edge's
    middle."""
    if kind not in KINDS or quirk not in QUIRKS:
        raise ValueError("no tower %s / %s" % (kind, quirk))

    rng = random.Random(seed * 3571 + int(side * 10) + storeys)
    eaves = storeys * STOREY
    inner = side - 2.0 * WALL
    levels = [s * STOREY for s in range(storeys)]
    out = {"openings": [], "doors": [], "entries": [], "places": {}, "eaves": eaves, "wall": WALL, "climbs": [],
           "budget": (2400 if storeys >= 9 else 1600) + (INSIDE * storeys if enterable else 0)}
    shapes, cols = [], []
    chute_z = -side + 1.5

    # Its four faces: lancets up them, the door at the front's foot; the
    # chute's hatch through the right face into the top room.
    faces = {"front": (side, (0.0, -WALL / 2.0, 0.0)), "back": (side, (0.0, -side + WALL / 2.0, 180.0)),
             "left": (inner, (-side / 2.0 + WALL / 2.0, -side / 2.0, -90.0)), "right": (inner, (side / 2.0 - WALL / 2.0, -side / 2.0, 90.0))}
    walls = []

    for face, (length, place) in faces.items():
        openings = []

        if face == "front":
            openings.append(town.Opening(0.0, 0.0, DOOR[0], DOOR[1], "door" if enterable else "barred"))

        for s in range(1, storeys):
            kind_of = "lit" if rng.random() < 0.2 else "shut"

            if balcony and (face, s) == tuple(balcony[:2]):
                along = balcony[2] if len(balcony) > 2 else 0.0
                openings.append(town.Opening(along, levels[s], BALCONY_DOOR[0], BALCONY_DOOR[1], "door" if enterable else "shut"))
            else:
                openings.append(town.Opening(0.0, levels[s] + LANCET[2], LANCET[0], LANCET[1], kind_of))

        if face == "right" and quirk == "chute" and enterable:
            # (Turned 90 degrees the wall's x runs to -z.)
            openings.append(town.Opening(-side / 2.0 - chute_z, levels[-1], HATCH[0], HATCH[1], "hatch"))

        for o in openings:
            out["openings"].append([0 if o.y < STOREY else int(o.y // STOREY), face, o.x, o.y, o.width, o.height, o.kind])

        # (Slits in granite: surrounds on the front alone, round its door.)
        s, c = town.wall(length, eaves, WALL, openings, front, place, inside=enterable, frames=face == "front")
        shapes += s
        walls += c

        if balcony and face == balcony[0]:
            y = levels[balcony[1]]
            along = balcony[2] if len(balcony) > 2 else 0.0
            b, bc = town.balcony(along, y, BALCONY[0], BALCONY[1], WALL / 2.0)
            b, bc = town.placed(b, bc, place[0], place[1], place[2])
            shapes += b
            cols += bc
            edge = town.placed([ks.box(along, y, WALL / 2.0 + BALCONY[1], 0.1, 0.1, 0.1, "granite")], [], place[0], place[1], place[2])[0][0]
            out["places"]["balcony"] = list(edge["centre"])

    if enterable:
        _inside(out, shapes, cols, side, storeys, levels, eaves)
        cols += walls
    else:
        cols += walls + [town.col(0.0, eaves / 2.0, -side / 2.0, inner + 0.02, eaves, inner + 0.02)]

    _top(out, shapes, cols, side, eaves, kind, enterable, storeys, levels)

    if quirk == "chute":
        _chute(out, shapes, cols, side, levels, chute_z, enterable)
    elif quirk == "dovecote":
        w, h = DOVECOTE
        x, z = side / 2.0 - WALL - w / 2.0, -side + WALL + w / 2.0
        shapes += [ks.box(x, eaves + h / 2.0, z, w, h, w, "whitewash"), ks.box(x, eaves + h + 0.1, z, w + 0.2, 0.2, w + 0.2, "terracotta")]
        shapes += [ks.card(x, eaves + h * 0.6, z + w / 2.0 + 0.02, w * 0.7, 0.3, "pitch")]
        cols.append(town.col(x, eaves + (h + 0.2) / 2.0, z, w + 0.2, h + 0.2, w + 0.2))

    top = eaves + (BASE + MERLON[1] if kind == "full" else town.PARAPET)
    out.update({"shapes": shapes, "cols": cols, "size": [side, top, side], "front": front})
    return out


def _inside(out, shapes, cols, side, storeys, levels, eaves):
    """A tower walked in: a floor a storey, a steep flight up alternate
    walls from each to the next and the last onto its top; one room a
    storey; its door, rooms' places and tour to the top."""
    inner = side - 2.0 * WALL
    stairs = []

    for s in range(storeys):
        if s % 2 == 0:
            stairs.append((-inner / 2.0 + STAIR_WIDTH / 2.0, -side + WALL + 0.1, 0.0, levels[s]))
        else:
            stairs.append((inner / 2.0 - STAIR_WIDTH / 2.0, -WALL - 0.1, 180.0, levels[s]))

    reach = town.stair_reach("straight", STAIR_WIDTH, STOREY, RISER, TREAD)
    run = reach["run"]

    # (Each floor over the ground, and the top, a hole over the flight that
    # comes up through it.)
    for s in range(storeys + 1):
        y = levels[s] if s < storeys else eaves
        hole = None

        if s >= 1:
            x, z, yaw, _y = stairs[s - 1]
            hole = (x - STAIR_WIDTH / 2.0, z, x + STAIR_WIDTH / 2.0, z + run) if yaw == 0.0 else \
                (x - STAIR_WIDTH / 2.0, z - run, x + STAIR_WIDTH / 2.0, z)
            hole = (hole[0], hole[1] + side / 2.0, hole[2], hole[3] + side / 2.0)

        if s < storeys:
            f, c = town.floors(inner, inner, [y], hole, "flagstone" if s == 0 else "boards", "stone" if s == 0 else "wood")
            f, c = town.placed(f, c, z=-side / 2.0)
            shapes += f
            cols += c
        else:
            out["roof_hole"] = hole

    for x, z, yaw, y in stairs:
        s, c = town.stair("straight", STAIR_WIDTH, STOREY, (x, y, z), yaw, "flagstone", "stone", True, RISER, TREAD)
        shapes += s
        cols += c

    out["doors"].append([0.0, 0.0, -WALL / 2.0, 0.0])
    out["entries"].append("door")
    out["rooms_at"] = [[0.0, levels[s], -side / 2.0] for s in range(storeys)]
    tour = [[0.0, 0.0, 1.0, "walk"], [0.0, 0.0, -WALL - 0.6, "walk"], out["rooms_at"][0] + ["walk"]]

    for s, (x, z, yaw, y) in enumerate(stairs):
        tour += town.stair_tour("straight", STAIR_WIDTH, STOREY, (x, y, z), yaw, RISER, TREAD)
        tour.append(out["rooms_at"][s + 1] + ["walk"] if s + 1 < storeys else [0.0, eaves, -side / 2.0, "walk"])

    out["tour"] = tour


def _top(out, shapes, cols, side, eaves, kind, enterable, storeys, levels):
    """The tower's top: a floor at the eaves (its hole over the last flight
    in a tower walked in), and round it a plain parapet (cut) or a base and
    merlons with machicolation boxes at the corners (full)."""
    hole = out.get("roof_hole") if enterable else None
    s, c = town.floors(side, side, [eaves], hole, "flagstone", "stone")
    s, c = town.placed(s, c, z=-side / 2.0)
    shapes += s
    cols += c
    t = town.PARAPET_THICK if kind == "cut" else 0.5
    height = town.PARAPET if kind == "cut" else BASE
    edges = [(0.0, -t / 2.0, side, t), (0.0, -side + t / 2.0, side, t), (-side / 2.0 + t / 2.0, -side / 2.0, t, side - 2.0 * t),
             (side / 2.0 - t / 2.0, -side / 2.0, t, side - 2.0 * t)]

    for x, z, w, d in edges:
        shapes.append(ks.box(x, eaves + height / 2.0, z, w, height, d, "granite"))
        cols.append(town.col(x, eaves + height / 2.0, z, w, height, d))

    if kind != "full":
        return

    # Merlons along each edge, crenels between them.
    pitch = MERLON[0] + CRENEL

    for x, z, w, d in edges:
        along_x = w > d
        length = w if along_x else d
        count = int((length + CRENEL) // pitch)
        start = -(count * pitch - CRENEL) / 2.0 + MERLON[0] / 2.0

        for i in range(count):
            u = start + i * pitch
            mx, mz = (x + u, z) if along_x else (x, z + u)
            mw, md = (MERLON[0], d) if along_x else (w, MERLON[0])
            shapes.append(ks.box(mx, eaves + BASE + MERLON[1] / 2.0, mz, mw, MERLON[1], md, "granite"))
            cols.append(town.col(mx, eaves + BASE + MERLON[1] / 2.0, mz, mw, MERLON[1], md))

    # Machicolation boxes on corbels at the corners, out over the faces.
    w, h, out_by = MACHICOLATION

    for sx in (-1.0, 1.0):
        for sz in (0.0, -side):
            x, z = sx * (side / 2.0 + out_by / 2.0 - 0.1), sz + (out_by / 2.0 - 0.1 if sz == 0.0 else -(out_by / 2.0 - 0.1))
            shapes += [ks.box(x, eaves - h / 2.0, z, out_by + 0.2, h, w, "granite"),
                       ks.box(x, eaves - h - 0.15, z, out_by, 0.3, 0.3, "granite")]
            cols.append(town.col(x, eaves - h / 2.0, z, out_by + 0.2, h, w))


def _chute(out, shapes, cols, side, levels, chute_z, enterable):
    """A latrine chute up the tower's right face: its housing (three thin
    walls round it, open at its foot), and in a tower walked in a ladder in
    it from the lane to the hatch into the top room."""
    w, d = CHUTE
    x = side / 2.0 + d / 2.0
    y0, y1 = 1.0, levels[-1] + 2.2
    t = 0.15

    for dz in (-1.0, 1.0):
        shapes.append(ks.box(x, (y0 + y1) / 2.0, chute_z + dz * (w / 2.0 - t / 2.0), d, y1 - y0, t, "granite"))
        cols.append(town.col(x, (y0 + y1) / 2.0, chute_z + dz * (w / 2.0 - t / 2.0), d, y1 - y0, t))

    shapes += [ks.box(x + d / 2.0 - t / 2.0, (y0 + y1) / 2.0, chute_z, t, y1 - y0, w, "granite"),
               ks.box(x, y1 + 0.1, chute_z, d + 0.1, 0.2, w + 0.1, "granite")]
    cols.append(town.col(x + d / 2.0 - t / 2.0, (y0 + y1) / 2.0, chute_z, t, y1 - y0, w))
    out["places"]["chute"] = [x, 0.0, chute_z]

    if not enterable:
        return

    # (The ladder through the wall into the room: the climber comes out on
    # the top room's floor.)
    top = levels[-1]
    # (Turned to face the wall, the box's depth runs along x: from the room's
    # floor inside to the chute's housing, its middle out in the chute.)
    out["climbs"].append([side / 2.0 + 0.2, (top + 0.6) / 2.0, chute_z, 0.8, top + 0.6, 1.6, 90.0])
    out["entries"].append("below")
    out["chute_tour"] = [[x, 0.0, chute_z, "walk"], [side / 2.0 - WALL - 0.4, top, chute_z, "climb"]]
