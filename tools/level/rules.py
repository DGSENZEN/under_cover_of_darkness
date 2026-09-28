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


def problems(data, stage="stage1"):
    out = []
    names = {}

    for p in data["pieces"]:
        if p["piece"] not in kit_recipes.PIECES:
            out.append("%s: no kit piece called '%s'" % (p["name"], p["piece"]))

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
