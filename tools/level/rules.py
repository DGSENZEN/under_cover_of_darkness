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

import geo
import kit_recipes
import markers as schema

# Triangle budget per sector (stage 1 blocks; the art pass raises it).
BUDGET = {"stage1": 60000, "stage2": 120000}
# Markers that stand on the floor, and how far below them it may be.
STANDING = {"station", "hide", "guard", "spawn", "waypoint"}
FLOOR_BELOW = 1.0
# A man stands up to this high; a marker whose body is in a wall is wrong.
BODY_HEIGHTS = (0.5, 1.2, 1.7)


def colliders(data):
    out = []

    for p in data["pieces"]:
        recipe = kit_recipes.PIECES.get(p["piece"])

        if recipe is not None:
            out.extend(geo.piece_boxes(recipe, p["position"], p["basis"]))

    return out


def floor_under(boxes, point):
    """How far below `point` the first collider is (None within FLOOR_BELOW)."""
    origin = geo.add(point, [0.0, 0.05, 0.0])
    best = None

    for box in boxes:
        t = box.ray(origin, [0.0, -1.0, 0.0])

        if t is not None and (best is None or t < best):
            best = t

    return best if best is not None and best <= FLOOR_BELOW + 0.05 else None


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


def problems(data, stage="stage1"):
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

    # Standing markers: on a floor, not in a wall.
    boxes = colliders(data)

    for m in data["markers"]:
        if m["ucd"] not in STANDING:
            continue

        if floor_under(boxes, m["position"]) is None:
            out.append("%s (%s): no floor under it within %.1f m" % (m["name"], m["ucd"], FLOOR_BELOW))

        for height in BODY_HEIGHTS:
            point = geo.add(m["position"], [0.0, height, 0.0])

            if any(box.contains(point, 0.02) for box in boxes):
                out.append("%s (%s): its body is inside something at %.1f m up" % (m["name"], m["ucd"], height))
                break

    ground = None
    out.extend(move_problems(data, boxes, ground))
    out.extend(headroom_problems(data, boxes, ground))
    out.extend(key_problems(data))

    # Budgets.
    tris = data.get("tris", {})
    per_sector = {}

    for p in data["pieces"]:
        recipe = kit_recipes.PIECES.get(p["piece"])
        count = tris.get(p["piece"], len(recipe["boxes"]) * 12 if recipe else 0)
        per_sector[p["sector"]] = per_sector.get(p["sector"], 0) + count

    for sector, count in per_sector.items():
        if count > BUDGET[stage]:
            out.append("sector %s: %d triangles, over its %d" % (sector, count, BUDGET[stage]))

    return out


# ---------------------------------------------------------------------------
# Rays against the level: its colliders and (when it has one) its ground, a
# geo.TriGrid of its terrain's triangles
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Route checks: each point of a way through the level reached from the one
# before by its move, the move measured
# ---------------------------------------------------------------------------

def _jump(boxes, ground, a, b, move):
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


def _move(boxes, ground, volumes, a, b, move):
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

        return []

    if move == "drop":
        fall = a[1] - b[1]
        return ["a drop of %.2f m: the player is hurt past %.2f" % (fall, SAFE_DROP)] if fall > SAFE_DROP else []

    if move in ("walk", "stairs", "balance"):
        steps = max(1, int(total / WALK_STEP))

        for k in range(steps + 1):
            p = [a[i] + (b[i] - a[i]) * k / steps for i in range(3)]

            if _floor_y(boxes, ground, p) is None:
                return ["no floor at (%.1f, %.1f) on the %s" % (p[0], p[2], move)]

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

    for m in data["markers"]:
        if m["ucd"] == "route_check":
            routes.setdefault(m["props"].get("route"), []).append(m)

    for route, points in sorted(routes.items()):
        points.sort(key=lambda m: int(m["props"].get("order", 0)))

        for first, then in zip(points, points[1:]):
            a, b = first["position"], then["position"]
            near = _near(boxes, a, b, 3.0)

            for problem in _move(near, ground, volumes, a, b, then["props"].get("move")):
                out.append("%s: %s -> %s: %s" % (route, first["name"], then["name"], problem))

    return out


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
