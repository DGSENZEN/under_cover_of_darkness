"""The ground a level stands on, made from numbers (tools/level; pure Python,
no Blender): rock, cliffs, banks, the sea bed, a cave. Unlike the kit's
pieces each terrain is its own mesh, built once by a layout
(Layout.terrain), then the user's to sculpt in the level's .blend; its
collider is its mesh (LevelLoader makes a trimesh of it).

    grid    a height field over a rectangle, `cell` m apart: the sea bed,
            banks, a spit, slopes (a face's slot chosen by its slope)
    cliff   a face along a path of (x, z) points, looking to the path's
            left: rows of strata bands, each stepped in or out a little
            (seeded) and leaning back as it rises
    tunnel  rings round a path of (x, y, z) points, looking inward: a sea
            cave, a shaft; what falls below `floor` is laid flat on it

Each returns {"name", "sector", "surface", "occluder", "verts": [[x, y, z]],
"faces": [[i, j, k]] (triangles wound counter-clockwise seen from the side
they look to), "slots": [one per face], "tints": [[r, g, b] per vertex]}.
The tint (strata() unless given) is multiplied into the baked shading: bands
that read the rock's height, darker and greener where the sea wets it.

Everything in Godot's axes (x east, y up, z south), metres.
"""

import math
import random
import re

import geo

# The most triangles one terrain may have (the PS2 budget).
TERRAIN_TRIS = 24000
# A terrain's name is a Godot node's (no dots, no spaces).
NAME = re.compile(r"^[a-z0-9_]+$")
# Tunnels and cliffs are cut this finely along their paths (m).
TUNNEL_STEP = 3.0


def strata(x, y, z, band=6.0, depth=0.12, wet=(0.0, 1.5)):
    """The rock's tint at a point: bands `band` m tall, alternately lighter
    and darker by `depth`, each a little its own; darker and greener in the
    wet band (`wet`: from, to), darker still under the sea."""
    index = int(math.floor(y / band))
    value = 1.0 + (depth if index % 2 == 0 else -depth) + ((index * 7919) % 13 - 6) / 6.0 * depth * 0.3
    colour = [value, value * 0.98, value * 0.94]

    if y < wet[0]:
        colour = [c * 0.55 for c in (colour[0] * 0.85, colour[1] * 0.95, colour[2] * 0.9)]
    elif y < wet[1]:
        colour = [c * 0.72 for c in (colour[0] * 0.85, colour[1] * 0.97, colour[2] * 0.86)]

    return [max(0.0, min(1.0, c)) for c in colour]


def _check(name, faces):
    if not NAME.match(name):
        raise ValueError("terrain '%s': a name of small letters, digits and underscores only" % name)

    if len(faces) > TERRAIN_TRIS:
        raise ValueError("terrain '%s': %d triangles, over its %d" % (name, len(faces), TERRAIN_TRIS))


def _normal(a, b, c):
    n = [(b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]),
         (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]),
         (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])]
    length = math.sqrt(sum(v * v for v in n))
    return [v / length for v in n] if length > 1e-12 else [0.0, 0.0, 0.0]


def _area(a, b, c):
    n = [(b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]), (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]),
         (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])]
    return 0.5 * math.sqrt(sum(v * v for v in n))


def _facing(verts, face, toward):
    """The triangle wound so it looks along `toward`."""
    n = _normal(*(verts[i] for i in face))
    return face if geo.dot(n, toward) >= 0.0 else [face[0], face[2], face[1]]


def _made(name, sector, surface, occluder, verts, faces, slot, tint):
    """The terrain's dict: its faces' slots (by slope) and its tints."""
    _check(name, faces)
    slots = []

    for face in faces:
        a, b, c = (verts[i] for i in face)
        n = _normal(a, b, c)
        slope = math.degrees(math.acos(max(-1.0, min(1.0, n[1]))))
        middle = [(a[i] + b[i] + c[i]) / 3.0 for i in range(3)]
        slots.append(slot(middle[0], middle[1], middle[2], slope) if callable(slot) else slot)

    tints = [(tint or strata)(v[0], v[1], v[2]) for v in verts]
    return {"name": name, "sector": sector, "surface": surface, "occluder": bool(occluder),
            "verts": [[float(c) for c in v] for v in verts], "faces": faces, "slots": slots, "tints": tints}


def grid(name, sector, x0, z0, x1, z1, cell, height, slot, surface="stone", tint=None, keep=None, skirt=0.0, occluder=False):
    """A height field from (x0, z0) to (x1, z1), a vertex every `cell` m at
    height(x, z); a face's slot is slot(x, y, z, slope in degrees); keep(ys)
    (the four corners' heights) False drops a quad; `skirt` m hangs down
    round the edge of what is kept (hiding the crack against a neighbour)."""
    nx = max(1, int(round((x1 - x0) / cell)))
    nz = max(1, int(round((z1 - z0) / cell)))
    heights = [[height(x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * k / nz) for k in range(nz + 1)] for i in range(nx + 1)]
    kept = [(i, k) for i in range(nx) for k in range(nz)
            if keep is None or keep([heights[i][k], heights[i + 1][k], heights[i][k + 1], heights[i + 1][k + 1]])]
    index = {}
    verts = []

    def vertex(i, k):
        if (i, k) not in index:
            index[(i, k)] = len(verts)
            verts.append([x0 + (x1 - x0) * i / nx, heights[i][k], z0 + (z1 - z0) * k / nz])

        return index[(i, k)]

    faces = []
    up = [0.0, 1.0, 0.0]

    for i, k in kept:
        a, b, c, d = vertex(i, k), vertex(i + 1, k), vertex(i + 1, k + 1), vertex(i, k + 1)

        # (The diagonals alternate: no grain running one way across the ground.)
        pair = ([a, b, c], [a, c, d]) if (i + k) % 2 == 0 else ([a, b, d], [b, c, d])

        for tri in pair:
            faces.append(_facing(verts, tri, up))

    if skirt > 0.0:
        faces.extend(_skirt(verts, faces, skirt))

    return _made(name, sector, surface, occluder, verts, faces, slot, tint)


def _skirt(verts, faces, drop):
    """Faces hanging `drop` m under the open edges of `faces`, looking out."""
    count = {}

    for face in faces:
        for e in range(3):
            edge = (face[e], face[(e + 1) % 3])
            key = tuple(sorted(edge))
            count[key] = count.get(key, 0) + 1

    middle = [sum(verts[i][c] for f in faces for i in f) / (3.0 * len(faces)) for c in range(3)]
    below = {}
    out = []

    for face in faces:
        for e in range(3):
            a, b = face[e], face[(e + 1) % 3]

            if count[tuple(sorted((a, b)))] != 1:
                continue

            for v in (a, b):
                if v not in below:
                    below[v] = len(verts)
                    verts.append([verts[v][0], verts[v][1] - drop, verts[v][2]])

            outward = [(verts[a][0] + verts[b][0]) / 2.0 - middle[0], 0.0, (verts[a][2] + verts[b][2]) / 2.0 - middle[2]]
            out.append(_facing(verts, [a, b, below[b]], outward))
            out.append(_facing(verts, [a, below[b], below[a]], outward))

    return out


def _along(path, step):
    """Points every `step` m or so along a path, each with its fraction of
    the way from the point before it (for the radii) and its segment."""
    out = []

    for s in range(len(path) - 1):
        a, b = path[s], path[s + 1]
        length = math.sqrt(sum((b[i] - a[i]) ** 2 for i in range(len(a))))
        n = max(1, int(math.ceil(length / step)))

        for j in range(n + (1 if s == len(path) - 2 else 0)):
            out.append((s, j / n))

    return out


def cliff(name, sector, path, base, top, band=6.0, jitter=0.6, seed=0, slot="cliff", surface="stone", step=4.0, lean=0.15,
          tint=None, occluder=True, blocks=None):
    """A cliff face from `base` to `top` along `path` [(x, z)], looking to
    its left: each strata band a vertical face stepped out or back by up to
    `jitter` (a little different along it), a short slope up to the next;
    each band `lean` m further back than the one under it. `blocks`
    (columns, m): granite's upright joints too, the bands broken every
    `columns` columns into blocks each standing out or back by up to `m` on
    its own (in place of the little wander along a band)."""
    rng = random.Random(seed)
    heights = []
    y = base

    while y < top - 1e-6:
        heights.append(y)
        y = min(top, y + band)

    heights.append(top)
    bands = len(heights) - 1
    shift = [rng.uniform(-jitter, jitter) for _ in range(bands)]
    columns = _along([(p[0], p[1]) for p in path], step)
    jointed = random.Random(seed + 1)
    offsets = [[jointed.uniform(-blocks[1], blocks[1]) for _ in range(bands + 1)] for _ in range(len(columns) // blocks[0] + 2)] if blocks else None
    normals = []

    for s in range(len(path) - 1):
        dx, dz = path[s + 1][0] - path[s][0], path[s + 1][1] - path[s][1]
        length = math.hypot(dx, dz)
        normals.append((dz / length, -dx / length))

    verts, rows = [], []

    for c, (s, f) in enumerate(columns):
        a, b = path[s], path[s + 1]
        x, z = a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f
        nx, nz = normals[s]

        # (At a corner the face turns halfway between its two sides.)
        if f == 0.0 and s > 0:
            nx, nz = (nx + normals[s - 1][0]) / 2.0, (nz + normals[s - 1][1]) / 2.0
        elif f == 1.0 and s + 1 < len(normals):
            nx, nz = (nx + normals[s + 1][0]) / 2.0, (nz + normals[s + 1][1]) / 2.0

        wobble = rng.uniform(-0.3, 0.3) * jitter
        column = []

        for k in range(bands):
            out = shift[k] + (offsets[c // blocks[0]][k] if blocks else wobble) - lean * k
            # The band's face, then its top sloping back to the next band's.
            for y in (heights[k], heights[k] + (heights[k + 1] - heights[k]) * 0.85):
                column.append(len(verts))
                verts.append([x + nx * out, y, z + nz * out])

        out = (shift[-1] if shift else 0.0) + (offsets[c // blocks[0]][bands] if blocks else wobble) - lean * bands
        column.append(len(verts))
        verts.append([x + nx * out, top, z + nz * out])
        rows.append((column, (nx, nz)))

    faces = []

    for (left, n), (right, _) in zip(rows, rows[1:]):
        toward = [n[0], 0.0, n[1]]

        for r in range(len(left) - 1):
            faces.append(_facing(verts, [left[r], right[r], right[r + 1]], toward))
            faces.append(_facing(verts, [left[r], right[r + 1], left[r + 1]], toward))

    return _made(name, sector, surface, occluder, verts, faces, slot, tint)


def tunnel(name, sector, path, radii, floor=None, sides=10, seed=0, slot="rock", surface="stone", tint=None, occluder=False):
    """A tunnel along `path` [(x, y, z)], `radii` [(across, up)] at each
    point (between them eased), looking inward, its rock a little uneven
    (seeded); what falls under `floor` is laid flat on it."""
    rng = random.Random(seed)
    verts, rings = [], []

    for s, f in _along(path, TUNNEL_STEP):
        a, b = path[s], path[s + 1]
        centre = [a[i] + (b[i] - a[i]) * f for i in range(3)]
        rx = radii[s][0] + (radii[s + 1][0] - radii[s][0]) * f
        ry = radii[s][1] + (radii[s + 1][1] - radii[s][1]) * f
        d = [b[i] - a[i] for i in range(3)]
        flat = math.hypot(d[0], d[2])

        # Across and up the ring; a shaft (a steep path) has its rings level.
        if flat > abs(d[1]) * 0.5:
            across, up = [d[2] / flat, 0.0, -d[0] / flat], [0.0, 1.0, 0.0]
        else:
            across, up = [1.0, 0.0, 0.0], [0.0, 0.0, 1.0]

        ring = []

        for i in range(sides):
            angle = 2.0 * math.pi * i / sides
            rough = 1.0 + rng.uniform(-0.1, 0.1)
            p = [centre[c] + (across[c] * rx * math.cos(angle) + up[c] * ry * math.sin(angle)) * rough for c in range(3)]

            if floor is not None and p[1] < floor:
                p[1] = floor

            ring.append(len(verts))
            verts.append(p)

        rings.append((ring, centre))

    faces = []

    for (ring, centre), (after, _) in zip(rings, rings[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            for tri in ([ring[i], after[i], after[j]], [ring[i], after[j], ring[j]]):
                middle = [sum(verts[v][c] for v in tri) / 3.0 for c in range(3)]
                faces.append(_facing(verts, tri, [centre[c] - middle[c] for c in range(3)]))

    return _made(name, sector, surface, occluder, verts, faces, slot, tint)


def frame(name, sector, outline, centre, along, toward, bottom, top, reach, slot="cliff", surface="stone", tint=None, occluder=True):
    """The rock round an opening (a cave's mouth in a cliff's gap): from
    `outline` (its points in order round it, in the plane through `centre`
    along `along` (level) and up) out to a rectangle `reach` m either side of
    the middle along it, from `bottom` to `top`, looking `toward`: each
    outline point carried straight out from the middle to the rectangle, its
    corners filled between."""
    def local(p):
        return geo.dot([p[i] - centre[i] for i in range(3)], along), p[1] - centre[1]

    def world(a, h):
        return [centre[0] + along[0] * a, centre[1] + h, centre[2] + along[2] * a]

    flat = [local(p) for p in outline]

    # (Round it counter-clockwise, along then up.)
    if sum(a0 * h1 - a1 * h0 for (a0, h0), (a1, h1) in zip(flat, flat[1:] + flat[:1])) < 0.0:
        outline, flat = outline[::-1], flat[::-1]

    up, down = top - centre[1], bottom - centre[1]
    # The rectangle's sides counter-clockwise (right, top, left, bottom) and
    # the corner after each.
    corners = [(reach, up), (-reach, up), (-reach, down), (reach, down)]

    def out(a, h):
        hits = []

        if a > 1e-9:
            hits.append((reach / a, 0))
        elif a < -1e-9:
            hits.append((-reach / a, 2))

        if h > 1e-9:
            hits.append((up / h, 1))
        elif h < -1e-9:
            hits.append((down / h, 3))

        t, side = min(hits)
        return (a * t, h * t), side

    verts = [list(p) for p in outline]
    edge = []

    for a, h in flat:
        (pa, ph), side = out(a, h)
        edge.append((len(verts), side))
        verts.append(world(pa, ph))

    corner_index = []

    for a, h in corners:
        corner_index.append(len(verts))
        verts.append(world(a, h))

    faces = []
    n = len(outline)

    for i in range(n):
        j = (i + 1) % n
        (pi, si), (pj, sj) = edge[i], edge[j]
        between = []
        k = si

        while k != sj:
            between.append(corner_index[k])
            k = (k + 1) % 4

        ring = [i, j, pj] + between[::-1] + [pi]

        for a, b in zip(ring[1:], ring[2:]):
            # (None where a point carried out lands on a corner.)
            if _area(verts[ring[0]], verts[a], verts[b]) > 1e-6:
                faces.append(_facing(verts, [ring[0], a, b], list(toward)))

    return _made(name, sector, surface, occluder, verts, faces, slot, tint)


def triangles(t):
    """A terrain's triangles, each three [x, y, z] corners."""
    return [[t["verts"][i] for i in face] for face in t["faces"]]


def height_at(t, x, z):
    """The terrain's highest height over (x, z), or None off it."""
    heights = geo.TriGrid(triangles(t)).heights(x, z)
    return max(heights) if heights else None
