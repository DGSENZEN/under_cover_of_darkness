"""The level check's rules (tools/level), on a level's data; pure Python.

A level's data (what build.py makes a .blend from, and read.py reads back):

    {"level": "garrison",
     "pieces": [{"name", "piece", "sector", "position": [x, y, z], "basis": 3x3 rows}, ...],
     "markers": [{"name", "ucd", "sector", "position", "basis", "size": [x, y, z] or None,
                  "props": {...}}, ...],
     "tris": {"piece name": triangles}}         # optional: the kit's own counts

Everything in Godot's axes. `problems(data)` lists what is wrong, one
sentence each, naming the object and the rule; an empty list passes.
"""

import districts
import math

import geo
import jobs
import kit_recipes
import markers as schema
from terrain import NAME as terrain_names

# Triangle budget per sector (stage 1 blocks; the art pass raises it).
BUDGET = {"stage1": 60000, "stage2": 120000}
# Markers that stand on the floor, and how far below them it may be.
STANDING = {"station", "hide", "guard", "spawn", "waypoint", "arrival", "home", "seat", "work"}
FLOOR_BELOW = 1.0
# An arrival stands at least this far out of every exit's box (m).
ARRIVAL_CLEAR = 2.0
# A man stands up to this high; a marker whose body is in a wall is wrong.
BODY_HEIGHTS = (0.5, 1.2, 1.7)


def colliders(data):
    """Return list[geo.Box] from known layout pieces; unknown recipes are skipped."""
    out = []

    for p in data["pieces"]:
        recipe = kit_recipes.PIECES.get(p["piece"])

        if recipe is not None:
            out.extend(geo.piece_boxes(recipe, p["position"], p["basis"]))

    return out


def floor_under(boxes, point, ground=None):
    """Return float hit distance or None within FLOOR_BELOW + 0.05 metres.

    boxes: iterable[geo.Box]; point: world three-vector; ground: TriGrid|None.
    Distances start 0.05 metres above point, not exactly at point's y.
    """
    origin = geo.add(point, [0.0, 0.05, 0.0])
    best = None

    for box in boxes:
        t = box.ray(origin, [0.0, -1.0, 0.0])

        if t is not None and (best is None or t < best):
            best = t

    if ground is not None:
        t = ground.down(origin, FLOOR_BELOW + 0.05)

        if t is not None and (best is None or t < best):
            best = t

    return best if best is not None and best <= FLOOR_BELOW + 0.05 else None


def ground_of(data):
    """Return geo.TriGrid|None from layout verts/faces or read-back tris.

    data is the level dictionary; absent/empty terrain returns None.
    """
    tris = []

    for t in data.get("terrain", []):
        tris.extend(t["tris"] if "tris" in t else [[t["verts"][i] for i in face] for face in t["faces"]])

    return geo.TriGrid(tris) if tris else None


def terrain_tris(t):
    return len(t["tris"]) if "tris" in t else len(t["faces"])


# A piece's scale this far from 1 is a scaled piece.
SCALE_SLACK = 0.001

# The moves a route check measures (the canal spec, section 5): the widest
# gap each jump clears (m), the band past the assisted jump that may or may
# not be made, and the gap never made; the highest mantle and hang (m over
# the feet), the room a hanging man needs under his lip (tall, wide), how
# deep a lip must be; how far down the player drops unhurt (m: his
# fall_damage_speed 17 m/s under his gravity 24 m/s² times its fall
# multiplier 1.35, scripts/PlayerController.gd), the most a jump may land
# above its take-off; a man's headroom on a guard's route.
GAPS = {"jump": 4.0, "sprint_jump": 5.3, "assist_jump": 6.2}
NEVER = 6.5
MANTLE = 2.3
HANG = 3.9
HANG_CLEAR = (2.05, 1.0)
HANG_DEPTH = 0.4
LIP = 0.15
SAFE_DROP = 17.0 ** 2 / (2.0 * 24.0 * 1.35)
LEAP_RISE = 0.6
HEADROOM = 1.95
# A floor within this of a point is the floor it stands on (m); the walk
# along a way looks at every WALK_STEP (m); an edge is found to EDGE_STEP.
STEP_DOWN = 0.45
WALK_STEP = 0.5
EDGE_STEP = 0.02
# The player's body as the controller has it (scripts/PlayerUtils/
# TraversalScanner.gd): its radius, the margin a mantle lands in from the
# lip past it, its height standing; how far below a thin top the floor
# beyond may lie for him to climb over it.
BODY_RADIUS = 0.5
LANDING_MARGIN = 0.05
BODY_HEIGHT = 2.0
CLIMB_OVER_DROP = 1.5
# (A man stood on a slope rides this far over it at his middle: a roof's
# 27 degrees, a little over.)
STANDING_LIFT = 0.1
# The steepest built slope stood on (the controller's floor, 45 degrees).
MAX_SLOPE = 45.0


def problems(data, stage="stage1"):
    """Return list[str] validation failures; [] passes without changing data.

    data is the level layout/read-back dict. stage selects the per-sector
    triangle budget ('stage1' or 'stage2'); geometry uses Godot axes/metres.
    """
    out = []
    names = {}

    for p in data["pieces"]:
        if p["piece"] not in kit_recipes.PIECES:
            out.append("%s: no kit piece called '%s'" % (p["name"], p["piece"]))

        # Its colliders are the recipe's, unscaled: a scaled piece would look
        # one size and stop men at another.
        scale = p.get("scale", [1.0, 1.0, 1.0])

        if any(abs(float(k) - 1.0) > SCALE_SLACK for k in scale):
            out.append("%s: scaled (%s); pieces are used at their own size (use a bigger piece)" % (p["name"], ", ".join("%.2f" % float(k) for k in scale)))

    for m in data["markers"]:
        if m["name"] in names:
            out.append("%s: two markers have this name" % m["name"])

        names[m["name"]] = m
        out.extend(schema.problems(m))

    # Links: a guard's route, a waypoint's route, a station's drop, a route's
    # waypoints.
    routes = {m["name"] for m in data["markers"] if m["ucd"] == "route"}
    waypoints = {}

    for m in data["markers"]:
        props = m.get("props", {})

        if m["ucd"] == "guard" and props.get("route") and props["route"] not in routes:
            out.append("%s: its route '%s' is not a route" % (m["name"], props["route"]))

        if m["ucd"] == "waypoint":
            if props.get("route") not in routes:
                out.append("%s: its route '%s' is not a route" % (m["name"], props.get("route")))
            else:
                waypoints.setdefault(props["route"], []).append(m)

        if m["ucd"] == "station" and props.get("drop_to") and props["drop_to"] not in names:
            out.append("%s: it carries to '%s', which is not a marker" % (m["name"], props["drop_to"]))

    for route in routes:
        if len(waypoints.get(route, [])) < 2:
            out.append("%s: a route needs two waypoints or more" % route)

    # The terrain: named as Godot keeps it (a copy made in Blender is
    # "bank.001"), each name once.
    seen = set()

    for t in data.get("terrain", []):
        if not terrain_names.match(t["name"]):
            out.append("%s: a terrain's name is small letters, digits and underscores (Godot finds its collider by it)" % t["name"])

        if t["name"] in seen:
            out.append("%s: two terrains have this name" % t["name"])

        seen.add(t["name"])

    # Standing markers: on a floor, not in a wall, not under the ground (nor
    # under an overhang lower than a man).
    boxes = colliders(data)
    ground = ground_of(data)
    buried = set()

    for m in data["markers"]:
        if m["ucd"] not in STANDING:
            continue

        if floor_under(boxes, m["position"], ground) is None:
            out.append("%s (%s): no floor under it within %.1f m" % (m["name"], m["ucd"], FLOOR_BELOW))

        for height in BODY_HEIGHTS:
            point = geo.add(m["position"], [0.0, height, 0.0])

            if any(box.contains(point, 0.02) for box in boxes):
                out.append("%s (%s): its body is inside something at %.1f m up" % (m["name"], m["ucd"], height))
                break

        if ground is not None and ground.up(geo.add(m["position"], [0.0, 0.05, 0.0]), BODY_HEIGHTS[-1]) is not None:
            out.append("%s (%s): its body is under the ground" % (m["name"], m["ucd"]))
            buried.add(m["name"])

    # Every point marker (a key, loot, a probe, a guard on a quay): not
    # under the ground, however deep the ground sculpted over it.
    for m in data["markers"]:
        point = geo.add(m["position"], [0.0, 0.05, 0.0])

        if ground is not None and not m.get("size") and m["name"] not in buried and ground.under(point) and not _tunnelled(boxes, ground, point):
            out.append("%s (%s): it is under the ground" % (m["name"], m["ucd"]))

    # Arrivals: clear of every exit's box, or the player is sent straight
    # back through it.
    exits = [geo.Box(m["position"], m["basis"], m["size"]) for m in data["markers"] if m["ucd"] == "exit" and m.get("size")]
    exit_names = [m["name"] for m in data["markers"] if m["ucd"] == "exit" and m.get("size")]

    for m in data["markers"]:
        if m["ucd"] != "arrival":
            continue

        for box, exit_name in zip(exits, exit_names):
            local = box.local(m["position"])
            gap = sum(max(0.0, abs(local[i]) - box.half[i]) ** 2 for i in range(3)) ** 0.5

            if gap < ARRIVAL_CLEAR:
                out.append("%s (arrival): %.1f m from %s's box, under %.1f m: the player would go straight back" % (m["name"], gap, exit_name,
                                                                                                                 ARRIVAL_CLEAR))

    out.extend(move_problems(data, boxes, ground))
    out.extend(way_problems(data))
    out.extend(door_problems(data))
    out.extend(headroom_problems(data, boxes, ground))
    out.extend(key_problems(data))
    district = districts.district_of(districts.load(), data["level"])
    out.extend(readable_problems(data, jobs.readable_slots(district) if district else None))

    # Budgets.
    tris = data.get("tris", {})
    per_sector = {}

    for p in data["pieces"]:
        recipe = kit_recipes.PIECES.get(p["piece"])
        count = tris.get(p["piece"], len(recipe["boxes"]) * 12 if recipe else 0)
        per_sector[p["sector"]] = per_sector.get(p["sector"], 0) + count

    for t in data.get("terrain", []):
        per_sector[t["sector"]] = per_sector.get(t["sector"], 0) + terrain_tris(t)

    for sector, count in per_sector.items():
        if count > BUDGET[stage]:
            out.append("sector %s: %d triangles, over its %d" % (sector, count, BUDGET[stage]))

    return out


def _tunnelled(boxes, ground, point):
    """Whether something built is over `point` under the ground's face over
    it (a sewer's vault, a cellar's ceiling): in a tunnel, not buried."""
    faces = [y for y in ground.heights(point[0], point[2]) if y >= point[1] - 1e-6]
    reach = min(faces) - point[1] if faces else 0.0
    return any(t is not None and t <= reach for t in (box.ray(point, [0.0, 1.0, 0.0]) for box in boxes))


# Rays against the level: its colliders and (when it has one) its ground, a
# geo.TriGrid of its terrain's triangles

def _ray(boxes, ground, point, sign, reach):
    """How far from `point` straight down (sign -1) or up (1) the first solid
    thing is, or None within `reach` (0 from inside something)."""
    best = None

    for box in boxes:
        t = box.ray(point, [0.0, float(sign), 0.0])

        if t is not None and t <= reach and (best is None or t < best):
            best = t

    if ground is not None:
        t = ground.down(point, reach) if sign < 0 else ground.up(point, reach)

        if t is not None and (best is None or t < best):
            best = t

    return best


def _steep(boxes, point, floor):
    """Whether the floor at `floor` under `point` is a built slope a man
    cannot stand on (over MAX_SLOPE: a mansard's lower slope): a slab's
    face across its thinnest side, wherever on it (its edge too) the ray
    down meets it. A bulky box's top is no slope."""
    start = [point[0], floor + 0.05, point[2]]

    for box in boxes:
        t = box.ray(start, [0.0, -1.0, 0.0])

        if t is None or abs(t - 0.05) > 0.02:
            continue

        thin = min(range(3), key=lambda i: box.half[i])
        others = [box.half[i] for i in range(3) if i != thin]

        tilt = abs(box.axes()[thin][1])

        # (Tilted past a floor, not yet a wall: a wall's top is an edge.)
        if box.half[thin] <= 0.2 and min(others) >= 2.0 * box.half[thin] and math.cos(math.radians(80.0)) < tilt < math.cos(math.radians(MAX_SLOPE)):
            return True

    return False


def _floor_y(boxes, ground, point, above=0.05, reach=STEP_DOWN):
    """The height of the floor under `point` (looked for from `above` over
    it to `reach` under it), or None."""
    start = geo.add(point, [0.0, above, 0.0])
    t = _ray(boxes, ground, start, -1, above + reach)
    return None if t is None else start[1] - t


def _near(boxes, a, b, margin):
    """The boxes that come within `margin` of the box round a and b."""
    low = [min(a[i], b[i]) - margin for i in range(3)]
    high = [max(a[i], b[i]) + margin for i in range(3)]
    out = []

    for box in boxes:
        reach = (box.half[0] ** 2 + box.half[1] ** 2 + box.half[2] ** 2) ** 0.5

        if all(low[i] - reach <= box.centre[i] <= high[i] + reach for i in range(3)):
            out.append(box)

    return out


def _flat(a, b):
    """The level way from a to b: its unit direction and its length."""
    dx, dz = b[0] - a[0], b[2] - a[2]
    length = (dx * dx + dz * dz) ** 0.5
    return ([dx / length, 0.0, dz / length] if length > 1e-6 else [0.0, 0.0, 0.0]), length


def _edge(boxes, ground, start, direction, limit):
    """How far from `start` along `direction` its floor (at start's height)
    goes before it drops away; `limit` if it goes on."""
    s = 0.0

    while s < limit:
        p = [start[0] + direction[0] * s, start[1], start[2] + direction[2] * s]

        if _floor_y(boxes, ground, p, 0.05, 0.3) is None:
            return max(0.0, s - EDGE_STEP / 2.0)

        s += EDGE_STEP

    return limit


def _lip(boxes, ground, top, back, limit=1.0):
    """Where a top's lip is, walking from `top` along `back` (toward the man
    below it), and how deep the top is behind it (to `limit`)."""
    behind = _edge(boxes, ground, top, back, limit)
    ahead = _edge(boxes, ground, top, [-back[0], 0.0, -back[2]], limit)
    lip = [top[0] + back[0] * behind, top[1], top[2] + back[2] * behind]
    return lip, behind + ahead


def _width(boxes, foot, direction):
    """How wide the way is across `direction` at a man's knee and chest over
    `foot` (the narrower), each side looked at to a metre and a half."""
    across = [-direction[2], 0.0, direction[0]]
    out = None

    for h in (0.5, 1.4):
        start = [foot[0], foot[1] + h, foot[2]]
        sides = []

        for sign in (1.0, -1.0):
            hits = [t for t in (box.ray(start, [sign * across[0], 0.0, sign * across[2]]) for box in boxes) if t is not None and t <= 1.5]
            sides.append(min(hits) if hits else 1.5)

        out = sum(sides) if out is None else min(out, sum(sides))

    return out


def _sloped(boxes, foot):
    """Whether what `foot` stands on (the box whose face a ray down meets
    there) is tilted off level."""
    start = [foot[0], foot[1] + 0.05, foot[2]]

    for box in boxes:
        t = box.ray(start, [0.0, -1.0, 0.0])

        if t is not None and abs(t - 0.05) <= 0.03:
            return max(abs(axis[1]) for axis in box.axes()) < 0.999

    return False


def _fits(boxes, foot):
    """Whether a man stands at `foot`: his body (a capsule, its foot and head
    round) clear of everything built."""
    r = BODY_RADIUS * 0.95
    # (Through him: his middle, rings at half his radius and at it, eight
    # ways round, each from the capsule's round foot to its round head
    # there; on a slope the whole of him STANDING_LIFT over `foot`, as a
    # capsule resting on a roof's slope rides over it, touching it uphill
    # of him; on a flat floor, on it.)
    spots = [(0.0, 0.0)] + [(f * r * math.cos(a), f * r * math.sin(a)) for f in (0.5, 1.0) for a in (i * math.pi / 4.0 for i in range(8))]
    lift = STANDING_LIFT if _sloped(boxes, foot) else 0.0

    for dx, dz in spots:
        round_off = BODY_RADIUS - math.sqrt(BODY_RADIUS ** 2 - dx * dx - dz * dz)
        low, high = lift + round_off + 0.02, lift + BODY_HEIGHT - round_off - 0.02

        for k in range(7):
            p = [foot[0] + dx, foot[1] + low + (high - low) * k / 6.0, foot[2] + dz]

            if any(box.contains(p) for box in boxes):
                return False

    return True


def _stands_on_top(boxes, ground, lip, back, depth):
    """Whether a mantle or a pull-up from a hang at `lip` lands a man: as the
    controller does, a body's radius and a margin in from the lip (half the
    top on a narrower one), standing there; else a thin top with a floor
    just beyond it, climbed over."""
    inward = [-back[0], 0.0, -back[2]]
    reach = BODY_RADIUS + LANDING_MARGIN
    land = reach if depth >= 2.0 * reach else max(depth * 0.5, 0.05)
    spot = [lip[0] + inward[0] * land, lip[1], lip[2] + inward[2] * land]
    floor = _floor_y(boxes, ground, spot, 0.3, 0.5)

    if floor is not None and _fits(boxes, [spot[0], floor, spot[2]]):
        return True

    # (Over a thin top, down onto the floor beyond it.)
    beyond = [lip[0] + inward[0] * (depth + BODY_RADIUS + 0.1), lip[1] + 0.5, lip[2] + inward[2] * (depth + BODY_RADIUS + 0.1)]

    if any(box.contains(beyond) for box in boxes):
        return False

    below = _floor_y(boxes, ground, beyond, 0.0, CLIMB_OVER_DROP + 0.5)
    return below is not None and lip[1] - below <= CLIMB_OVER_DROP + 1e-6


def _shimmy(boxes, ground, a, b, d, total):
    """What is wrong with moving hand over hand from a hang at a to one at b
    along a ledge: level, its top and lip all the way, a hanging man's room
    under it on its open side."""
    if abs(b[1] - a[1]) > 0.1:
        return ["a shimmy %.2f m up or down" % (b[1] - a[1])]

    across = [-d[2], 0.0, d[0]]
    middle = [(a[i] + b[i]) / 2.0 for i in range(3)]
    # (Its open side: where, under the ledge, nothing is built.)
    out = None

    for sign in (1.0, -1.0):
        p = [middle[0] + sign * across[0] * 0.5, middle[1] - 0.6, middle[2] + sign * across[2] * 0.5]

        if not any(box.contains(p) for box in boxes):
            out = [sign * across[0], 0.0, sign * across[2]]
            break

    if out is None:
        return ["no open side to hang from"]

    steps = max(1, int(total / 0.25))

    for k in range(steps + 1):
        p = [a[i] + (b[i] - a[i]) * k / steps for i in range(3)]
        top = _floor_y(boxes, ground, p, 0.15, 0.3)

        if top is None or abs(top - a[1]) > 0.1:
            return ["no ledge to hang from at (%.1f, %.1f)" % (p[0], p[2])]

        lip, depth = _lip(boxes, ground, [p[0], top, p[2]], out)

        if depth < LIP:
            return ["its lip is %.2f m deep at (%.1f, %.1f), under %.2f" % (depth, p[0], p[2], LIP)]

        if not _hanging_room(boxes, lip, out, -1e9):
            return ["no room for a hanging man at (%.1f, %.1f)" % (p[0], p[2])]

    return []


def _hanging_room(boxes, lip, back, floor):
    """Whether a hanging man fits under `lip`: HANG_CLEAR tall (not below
    `floor`) and wide, HANG_DEPTH out from its face along `back`, clear."""
    across = [-back[2], 0.0, back[0]]
    top = lip[1] - 0.05
    bottom = max(lip[1] - HANG_CLEAR[0], floor + 0.05)

    for depth in (0.1, 0.25, HANG_DEPTH):
        for side in (-HANG_CLEAR[1] / 2.0 + 0.05, 0.0, HANG_CLEAR[1] / 2.0 - 0.05):
            for k in range(5):
                y = bottom + (top - bottom) * k / 4.0
                p = [lip[0] + back[0] * depth + across[0] * side, y, lip[2] + back[2] * depth + across[2] * side]

                if any(box.contains(p) for box in boxes):
                    return False

    return True


def _volumes(data):
    """The boxes a man climbs (ladders, ropes) and swims (water) in."""
    climbs, waters = [], []

    for m in data["markers"]:
        props = m.get("props", {})

        if m["ucd"] == "ladder" and m.get("size"):
            climbs.append(geo.Box(m["position"], m["basis"], m["size"]))
        elif m["ucd"] == "rope":
            length = float(props.get("length", 0.0))
            climbs.append(geo.Box(geo.add(m["position"], [0.0, -length / 2.0, 0.0]), geo.IDENTITY, [1.2, length, 1.2]))
        elif m["ucd"] == "water" and m.get("size"):
            waters.append(geo.Box(m["position"], m["basis"], m["size"]))

    return climbs, waters


# Route checks: each point of a way through the level reached from the one
# before by its move, the move measured

def _jump(boxes, ground, a, b, move):
    if _floor_y(boxes, ground, b) is None:
        return ["lands on nothing"]

    d, total = _flat(a, b)
    gap = max(0.0, total - _edge(boxes, ground, a, d, total) - _edge(boxes, ground, b, [-d[0], 0.0, -d[2]], total))
    rise = b[1] - a[1]
    out = []

    if gap >= NEVER:
        out.append("a gap of %.2f m: never made (%.1f or more)" % (gap, NEVER))
    elif gap > GAPS["assist_jump"]:
        out.append("a gap of %.2f m: uncertain (%.1f to %.1f)" % (gap, GAPS["assist_jump"], NEVER))
    elif gap > GAPS[move]:
        needs = "a sprint" if gap <= GAPS["sprint_jump"] else "an assisted jump"
        out.append("a gap of %.2f m, too wide for a %s: needs %s" % (gap, move.replace("_", " "), needs))

    if rise > LEAP_RISE:
        out.append("lands %.2f m higher, more than a jump's %.1f" % (rise, LEAP_RISE))

    return out


def _move(boxes, ground, volumes, a, b, move, doors=()):
    """What is wrong with reaching b from a by `move` (sentences)."""
    rise = b[1] - a[1]
    d, total = _flat(a, b)
    back = [-d[0], 0.0, -d[2]]

    if move in GAPS:
        return _jump(boxes, ground, a, b, move)

    if move in ("mantle", "hang"):
        highest = MANTLE if move == "mantle" else HANG

        if rise > highest:
            return ["a %s of %.2f m, over %.1f" % (move, rise, highest)]

        if _floor_y(boxes, ground, b) is None:
            return ["nothing to %s onto" % move]

        lip, depth = _lip(boxes, ground, b, back)

        if depth < LIP:
            return ["its lip is %.2f m deep, under %.2f" % (depth, LIP)]

        if move == "hang" and not _hanging_room(boxes, lip, back, a[1]):
            return ["no room under its lip for a hanging man (%.2f x %.1f m)" % HANG_CLEAR]

        if not _stands_on_top(boxes, ground, lip, back, depth):
            return ["no room to stand on its top past the lip (%.2f m deep), nor a floor just beyond to climb over onto" % depth]

        return []

    if move == "grab":
        # (Hung from, not pulled up onto: a string course, a sill.)
        if rise > HANG:
            return ["a grab of %.2f m, over %.1f" % (rise, HANG)]

        if _floor_y(boxes, ground, b) is None:
            return ["nothing to grab"]

        lip, depth = _lip(boxes, ground, b, back)

        if depth < LIP:
            return ["its lip is %.2f m deep, under %.2f" % (depth, LIP)]

        return [] if _hanging_room(boxes, lip, back, a[1]) else ["no room under its lip for a hanging man (%.2f x %.1f m)" % HANG_CLEAR]

    if move == "shimmy":
        return _shimmy(boxes, ground, a, b, d, total)

    if move == "drop":
        fall = a[1] - b[1]

        if _floor_y(boxes, ground, b) is None:
            return ["drops onto nothing"]

        return ["a drop of %.2f m: the player is hurt past %.2f" % (fall, SAFE_DROP)] if fall > SAFE_DROP else []

    if move in ("walk", "stairs", "balance"):
        steps = max(1, int(total / WALK_STEP))

        for k in range(steps + 1):
            p = [a[i] + (b[i] - a[i]) * k / steps for i in range(3)]
            floor = _floor_y(boxes, ground, p)

            if floor is None:
                return ["no floor at (%.1f, %.1f) on the %s" % (p[0], p[2], move)]

            if _steep(boxes, p, floor):
                return ["too steep to stand on at (%.1f, %.1f) on the %s" % (p[0], p[2], move)]

            # (A man a body across: a beam is balanced, not walked; in a
            # doorway its door's width is the way.)
            in_door = any(math.hypot(p[0] - dx, p[2] - dz) <= half + 0.6 for dx, dz, half in doors)

            if move != "balance" and total > 1e-6 and not in_door:
                width = _width(boxes, [p[0], floor, p[2]], d)

                if width < 2.0 * BODY_RADIUS + 0.02:
                    return ["narrower than a man (%.2f m) at (%.1f, %.1f) on the %s" % (width, p[0], p[2], move)]

        return []

    climbs, waters = volumes

    if move in ("climb", "rope"):
        middle = [(a[i] + b[i]) / 2.0 for i in range(3)]
        return [] if any(box.contains(middle) for box in climbs) else ["no ladder or rope between them"]

    if move == "swim":
        return [] if any(box.contains(a) for box in waters) and any(box.contains(b) for box in waters) else ["not in water"]

    return []


def move_problems(data, boxes, ground):
    """Every route check against the move that reaches it."""
    out = []
    routes = {}
    volumes = _volumes(data)
    doors = [(m["position"][0], m["position"][2], float(m.get("props", {}).get("width", 1.2)) / 2.0) for m in data["markers"] if m["ucd"] == "door"]

    for m in data["markers"]:
        if m["ucd"] == "route_check":
            routes.setdefault(m["props"].get("route"), []).append(m)

    for route, points in sorted(routes.items()):
        points.sort(key=lambda m: int(m["props"].get("order", 0)))

        for first, then in zip(points, points[1:]):
            a, b = first["position"], then["position"]
            near = _near(boxes, a, b, 3.0)

            for problem in _move(near, ground, volumes, a, b, then["props"].get("move"), doors):
                out.append("%s: %s -> %s: %s" % (route, first["name"], then["name"], problem))

    return out


def way_problems(data):
    """The old town's ways (its spec, sections 5.3 and 6): every household
    entered by `ways` routes of different kinds, each ending inside it, and
    every terrace step crossed by its public and thief's connectors. A route
    says what it is on its first route check (into, kind; step, way)."""
    out = []
    routes = {}

    for m in data["markers"]:
        if m["ucd"] == "route_check":
            routes.setdefault(m["props"].get("route"), []).append(m)

    firsts = {}

    for route, points in routes.items():
        points.sort(key=lambda m: int(m["props"].get("order", 0)))
        firsts[route] = (points[0]["props"], points[-1]["position"])

    for m in data["markers"]:
        if m["ucd"] == "household" and m.get("size"):
            label = m["props"]["label"]
            box = geo.Box(m["position"], m["basis"], m["size"])
            kinds = set()

            for route, (props, end) in sorted(firsts.items()):
                if props.get("into") != label:
                    continue

                if not box.contains(end, 0.0):
                    out.append("route %s ends outside %s" % (route, label))
                else:
                    kinds.add(props.get("kind", ""))

            needs = int(m["props"].get("ways", 3))

            if len(kinds) < needs:
                out.append("%s (household): %d ways in (%s), needs %d of different kinds" % (label, len(kinds), ", ".join(sorted(kinds)),
                                                                                             needs))

        if m["ucd"] == "terrace_step":
            label = m["props"]["label"]
            count = {"public": 0, "thief": 0}

            for props, _end in firsts.values():
                if props.get("step") == label and props.get("way") in count:
                    count[props["way"]] += 1

            public, thief = int(m["props"].get("public", 2)), int(m["props"].get("thief", 1))

            if count["public"] < public or count["thief"] < thief:
                out.append("%s (terrace step): %d public and %d thief connectors, needs %d and %d" % (label, count["public"], count["thief"],
                                                                                                    public, thief))

    return out


def door_problems(data):
    """The old town's doors (its spec's rule 22): every live door of a
    placed town piece (its recipe's `doors`) has a door marker within 0.3 m
    of it, and no door marker stands in a town piece's colliders (on a shut
    front) but at one of its live doors."""
    out = []
    doors = [m for m in data["markers"] if m["ucd"] == "door"]
    live, solid = [], []

    for p in data["pieces"]:
        recipe = kit_recipes.PIECES.get(p["piece"])

        if not recipe or recipe.get("family") != "town":
            continue

        for d in recipe.get("doors", []):
            where = geo.add(p["position"], geo.apply(p["basis"], d[0:3]))
            live.append(where)

            if not any(_apart(m["position"], where) <= 0.3 for m in doors):
                out.append("%s: its door at (%.1f, %.1f, %.1f) has no door marker" % (p["name"], where[0], where[1], where[2]))

        solid.append((p["name"], geo.piece_boxes(recipe, p["position"], p["basis"])))

    for m in doors:
        if any(_apart(m["position"], where) <= 0.3 for where in live):
            continue

        # (A door's middle, a metre over its foot: in a wall drawn shut.)
        middle = geo.add(m["position"], [0.0, 1.0, 0.0])

        for name, boxes in solid:
            if any(box.contains(middle, 0.05) for box in boxes):
                out.append("%s (door): on a shut front of %s" % (m["name"], name))
                break

    return out


def _apart(a, b):
    return sum((a[i] - b[i]) ** 2 for i in range(3)) ** 0.5


def headroom_problems(data, boxes, ground):
    """Every guard's route walked round: a man's headroom all the way."""
    out = []
    routes = {m["props"].get("route") for m in data["markers"] if m["ucd"] == "guard" and m["props"].get("route")}
    waypoints = {}

    for m in data["markers"]:
        if m["ucd"] == "waypoint" and m["props"].get("route") in routes:
            waypoints.setdefault(m["props"]["route"], []).append(m)

    for route, points in sorted(waypoints.items()):
        points.sort(key=lambda m: int(m["props"].get("order", 0)))

        for first, then in zip(points, points[1:] + points[:1]):
            a, b = first["position"], then["position"]
            near = _near(boxes, a, b, 3.0)
            _, total = _flat(a, b)
            steps = max(1, int(total / WALK_STEP))

            for k in range(steps + 1):
                p = [a[i] + (b[i] - a[i]) * k / steps for i in range(3)]
                floor = _floor_y(near, ground, p, 1.0, 1.0 + STEP_DOWN)

                if floor is None:
                    continue

                over = _ray(near, ground, [p[0], floor + 0.1, p[2]], 1, HEADROOM - 0.1)

                if over is not None:
                    out.append("%s: no headroom at (%.1f, %.1f) (%.2f m)" % (route, p[0], p[2], over + 0.1))
                    break

    return out


def key_problems(data):
    """Every locked door or chest that cannot be picked has its key in the
    level; every key opens something."""
    out = []
    keys = {m["props"].get("key_id") for m in data["markers"] if m["ucd"] == "key"}
    wanted = set()

    for m in data["markers"]:
        if m["ucd"] not in ("door", "chest"):
            continue

        props = m.get("props", {})
        key = props.get("key", "")

        if key:
            wanted.add(key)

        if props.get("locked") and not props.get("pick", True) and key not in keys:
            out.append("%s: locked, cannot be picked, and there is no key '%s' in the level" % (m["name"], key))

    for m in data["markers"]:
        if m["ucd"] == "key" and m["props"].get("key_id") not in wanted:
            out.append("%s: its key '%s' opens nothing" % (m["name"], m["props"].get("key_id")))

    return out


def readable_problems(data, slots):
    """Every readable marker names a slot in its district's job file; `slots`
    is that file's readable ids, None for a level of no district."""
    out = []

    for m in data["markers"]:
        if m["ucd"] != "readable":
            continue

        if slots is None:
            out.append("%s: a readable in a level of no district" % m["name"])
        elif m["props"].get("slot") not in slots:
            out.append("%s: reads slot '%s', not in the district's job file" % (m["name"], m["props"].get("slot")))

    return out


def district_problems(registry, datas):
    """Return list[str]: the gates between districts, checked across their
    levels; [] passes.

    registry is data/districts.json's (districts.load()); datas maps each
    level's name to its data. An exit's `to` names a district (it must then
    say where it arrives, and that district must have the arrival) or an
    unbuilt one (sealed); every marker name is in one level only, since a
    district's state and a guard following the player keep their names."""
    out = []
    arrivals = {}
    where = {}

    for level, data in datas.items():
        for m in data["markers"]:
            where.setdefault(m["name"], []).append(level)

            if m["ucd"] == "arrival":
                arrivals.setdefault(m["name"], set()).add(level)

    for level, data in datas.items():
        for m in data["markers"]:
            to = m.get("props", {}).get("to", "") if m["ucd"] == "exit" else ""

            if not to or to in registry.get("unbuilt", []):
                continue

            if to not in registry["districts"]:
                out.append("%s: goes to '%s', which is no district" % (m["name"], to))
                continue

            arrive = m["props"].get("arrive", "")

            if not arrive:
                out.append("%s: goes to %s but does not say where it arrives" % (m["name"], to))
            elif not arrivals.get(arrive, set()) & set(registry["districts"][to]["levels"]):
                out.append("%s: arrives at '%s', which %s does not have" % (m["name"], arrive, to))

    for name, levels in where.items():
        if len(set(levels)) > 1:
            out.append("%s: in %s" % (name, " and ".join(sorted(set(levels)))))

    return out


def kit_problems():
    """The kit against the metrics (canal spec section 5)."""
    out = []

    for name, recipe in kit_recipes.PIECES.items():
        opening = recipe.get("opening")

        if recipe["family"] == "wall" and opening and "door" in name:
            if opening[0] < 1.1 or opening[1] < 2.0:
                out.append("%s: a door %.2f x %.2f m, under 1.1 x 2.0" % (name, opening[0], opening[1]))

        if name == "stair_straight":
            if kit_recipes.RISER > 0.35:
                out.append("%s: risers of %.2f m, over 0.35" % (name, kit_recipes.RISER))

    return out
