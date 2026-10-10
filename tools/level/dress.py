"""The Zócalo dressed in its street and canal kit (the street and canal
kit's plan, docs/superpowers/plans/2026-10-10-zocalo-street-canal-kit.md,
Task 8): from the plan and its event fields, every kit piece placed (the
plaza's kerbs and drops, gutter grates, junction boxes, hatches, the tram
loop and its seeped rail, the causeway's band, the canal's walls, culverts,
rings and landings, the three bridges), the ground's areas round them (flags,
setts, the landings' floors, the canal's silt) with the flush pieces set in
as inlays, the colliders, the greybox elements the dressing replaces; then a
district-wide overlap gate over every placed face and the greybox kept.

    python3 tools/level/dress.py <plan.json> <greybox.json> <dressing.json>   (exits 1 if the gate fails)

Axes are the plan's: x east, y up, z south. A piece's faces come from
assets/eclipse/source/<kit>_faces.json in its own Godot axes; a placement
turns it `yaw` degrees about +Y (its local +X to (cos, -sin), its front, +Z,
to (sin, cos)), stretches it along its local X and sets it `at`.
"""

import json
import math
import os
import sys
import zlib
from collections import defaultdict
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = Path(HERE).parents[1]
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))
sys.path.insert(0, str(ROOT / "tools" / "eclipse"))

import overlap  # noqa: E402
import plan  # noqa: E402
import street_dims as D  # noqa: E402

SOURCE = ROOT / "assets" / "eclipse" / "source"
KITS = ("street_kit", "canal_kit", "bridge_stone", "bridge_steel")
# How far a run's pieces may be stretched (or squeezed) to fill it.
STRETCH = (0.95, 1.05)
# The events' thresholds: subsidence heaves a kerb or shims a track; the
# seepage lays the third rail and the Company's boxes.
HEAVE = 0.2
SEEPED = 0.3
BOXED = 0.25
# The plaza's crossings: (side, where along it) — Calle 20 de Noviembre, the
# cathedral, the palace's gate, Calle 16 de Septiembre.
GATES = (("north", 0.0), ("south", 0.0), ("east", 0.0), ("west", 42.5))
# The Line 2 service hatches: over the corridors' middles and the hall.
HATCHES = [(sx * 55.0, sz * 98.0) for sx in (-1, 1) for sz in (-1, 1)] + \
          [(sx * 20.0, sz * 12.0) for sx in (-1, 1) for sz in (-1, 1)]
GRATE_EVERY = 10
BOX_EVERY = 20
CULVERT_EVERY = 10
RING_EVERY = 4              # wall pieces: a ring at every fourth one's middle
# Culverts and rings keep this far from a bridge's or a landing's edge (m).
CLEAR = 6.0
# Flush pieces: set into the ground, which is cut round them.
FLUSH = ("tram_track", "tram_track_shimmed", "tram_track_curve", "causeway_band", "hatch", "gutter_grate")
# The greybox the dressing takes over (its routes by kind, its grounds by kind).
SKIP_GROUNDS = ("plaza", "canal", "landing")
SKIP_ROUTES = ("bridge",)
# The canal's walls stop this far short of the brink, so their ends never lie
# in the cliff's plane.
BRINK_GAP = 0.05
# The district gate's spatial buckets (m).
CELL = 25.0
LAYER_GAP = 0.03


# Kits and placements

def load_faces(source=SOURCE):
    """Each built kit's faces and triangles, by object, in its Godot axes."""
    out = {}

    for kit in KITS:
        path = Path(source) / (kit + "_faces.json")

        if path.exists():
            out[kit] = json.loads(path.read_text())

    return out


def kit_of(piece):
    if piece in ("bridge_stone", "bridge_steel"):
        return piece

    canal = ("canal_wall", "culvert", "canal_landing_steps", "mooring_ring")
    return "canal_kit" if piece.startswith(canal) else "street_kit"


def place(piece, at, yaw, stretch=1.0, collider=None):
    out = {"kit": kit_of(piece), "piece": piece, "at": [float(v) for v in at], "yaw": float(yaw),
           "stretch": float(stretch)}

    if collider:
        out["collider"] = collider

    return out


def _axes(yaw):
    r = math.radians(yaw)
    c, s = math.cos(r), math.sin(r)
    return (c, -s), (s, c)


def world(p, local):
    """A point in a placement's local Godot axes, in the plan's."""
    (ax, az), (bx, bz) = _axes(p["yaw"])
    x, y, z = local
    x *= p.get("stretch", 1.0)
    return (p["at"][0] + x * ax + z * bx, p["at"][1] + y, p["at"][2] + x * az + z * bz)


def yaw_of(u):
    """The yaw that turns a piece's local +X along u (x, z); its front then
    looks to (-u_z, u_x)."""
    return math.degrees(math.atan2(-u[1], u[0]))


def outline(p):
    """A flush piece's footprint (street_dims, Blender x, y) on the ground."""
    return [(w[0], w[2]) for w in (world(p, (x, 0.0, -y)) for x, y in D.footprint(p["piece"]))]


_BOXES = {}


def box(p, faces):
    """A placement's world box: (lo, hi) corners."""
    key = (p["kit"], p["piece"])

    if key not in _BOXES:
        points = [q for f in faces[p["kit"]]["objects"][p["piece"]] for q in f["points"]]
        _BOXES[key] = [tuple(min(q[k] for q in points) for k in range(3)), tuple(max(q[k] for q in points) for k in range(3))]

    lo, hi = _BOXES[key]
    corners = [world(p, (x, y, z)) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
    return tuple(min(c[k] for c in corners) for k in range(3)), tuple(max(c[k] for c in corners) for k in range(3))


def middle(p, faces):
    lo, hi = box(p, faces)
    return ((lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2)


def boxes_meet(a, b):
    ax0, az0 = min(q[0] for q in a), min(q[1] for q in a)
    ax1, az1 = max(q[0] for q in a), max(q[1] for q in a)
    bx0, bz0 = min(q[0] for q in b), min(q[1] for q in b)
    bx1, bz1 = max(q[0] for q in b), max(q[1] for q in b)
    return ax0 < bx1 and bx0 < ax1 and az0 < bz1 and bz0 < az1


# Runs

def fill(length, pitch):
    """A run of `length` in pieces of `pitch`: how many, and how much each is
    stretched to fill it exactly."""
    n = max(1, round(length / pitch))
    s = length / (n * pitch)

    if not STRETCH[0] <= s <= STRETCH[1]:
        raise ValueError("a run of %.2f m in %.1f m pieces would stretch them %.3f" % (length, pitch, s))

    return n, s


def fill_mixed(length, pitches):
    """A run of `length` in long pieces and at most two short ones
    (pitches (long, short)): their pitches in order, the stretch."""
    long, short = pitches
    best = None

    for b in range(3):
        for a in range(int(length / long) + 2):
            total = a * long + b * short

            if total <= 0:
                continue

            s = length / total
            key = (round(abs(s - 1.0), 9), b)

            if best is None or key < best[0]:
                best = (key, [long] * a + [short] * b, s)

    if best is None or not STRETCH[0] <= best[2] <= STRETCH[1]:
        raise ValueError("a run of %.2f m cannot be filled with %s" % (length, pitches))

    return best[1], best[2]


def _unit(a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    return (dx / length, dz / length), length


def _along(a, u, t):
    return (a[0] + u[0] * t, a[1] + u[1] * t)


# The dressing

class Dresser:
    def __init__(self, data, faces):
        self.data = data
        self.faces = faces
        self.pieces = []
        self.boxes = []          # colliders
        self.inlays = defaultdict(list)       # level -> [polygon]
        self.openings = defaultdict(list)     # level -> [rect]
        grounds = data["ground"]
        self.plaza = next(g for g in grounds if g["kind"] == "plaza")
        self.level = self.plaza["level"]
        self.canal = next(g for g in grounds if g["kind"] == "canal")
        self.landings = [g for g in grounds if g["kind"] == "landing"]
        self.bridges = [r for r in data["routes"] if r["kind"] == "bridge"]

    def field(self, kind, at):
        return plan.field(self.data, kind, at[0], at[1])

    def add(self, p):
        self.pieces.append(p)

        if p["piece"] in FLUSH:
            self.inlays[round(p["at"][1], 3)].append(outline(p))

        return p

    def collide_run(self, a, u, length, section):
        """A box collider along a run from a (x, z) along u: `section` its
        local (y0, y1, z0, z1) across the run (front +z)."""
        y0, y1, z0, z1 = section
        yaw = yaw_of(u)
        centre = world({"at": [a[0], 0.0, a[1]], "yaw": yaw}, (length / 2, (y0 + y1) / 2, (z0 + z1) / 2))
        self.boxes.append({"box": [*centre, length, y1 - y0, z1 - z0], "yaw": yaw})

    # The plaza

    def plaza_kerbs(self):
        x0, z0, x1, z1 = _bounds(self.plaza["polygon"])
        sides = {"north": ((x1, z0), (x0, z0)), "south": ((x0, z1), (x1, z1)),
                 "west": ((x0, z0), (x0, z1)), "east": ((x1, z1), (x1, z0))}
        leg = 0.6
        kerb = (D.KERB_FOOT, D.KERB_PROUD, -D.KERB_DEPTH, 0.0)

        for corner, yaw in (((x0, z1), 0.0), ((x1, z1), 90.0), ((x1, z0), 180.0), ((x0, z0), -90.0)):
            p = self.add(place("kerb_corner", (corner[0], 0.0, corner[1]), yaw))
            centre = world(p, (leg / 2, (D.KERB_FOOT + D.KERB_PROUD) / 2, -leg / 2))
            self.boxes.append({"box": [*centre, leg, D.KERB_PROUD - D.KERB_FOOT, leg], "yaw": yaw})

        for side, (a, b) in sides.items():
            u, length = _unit(a, b)
            gate = next(g for s, g in GATES if s == side)
            # Where along the side the gate's middle falls.
            t_gate = abs((gate - a[0]) if side in ("north", "south") else (gate - a[1]))
            start = _along(a, u, t_gate - D.DROP_LENGTH / 2)
            drop = self.add(place("kerb_drop", (start[0], 0.0, start[1]), yaw_of(u), collider="mesh"))
            self.openings[round(self.level, 3)].append(_rect_of(outline(drop)))

            for t0, t1 in ((leg, t_gate - D.DROP_LENGTH / 2), (t_gate + D.DROP_LENGTH / 2, length - leg)):
                self.kerb_run(_along(a, u, t0), u, t1 - t0)
                self.collide_run(_along(a, u, t0), u, t1 - t0, kerb)

    def kerb_run(self, a, u, length):
        n, s = fill(length, D.KERB_LENGTH)
        yaw = yaw_of(u)
        inward = (u[1], -u[0])

        for k in range(n):
            at = _along(a, u, k * D.KERB_LENGTH * s)
            p = place("kerb_straight", (at[0], 0.0, at[1]), yaw, s)

            if self.field("subsidence", middle(p, self.faces)) >= HEAVE:
                p["piece"] = "kerb_heaved"

            self.add(p)

            if k % GRATE_EVERY == GRATE_EVERY // 2:
                self.add(place("gutter_grate", (at[0], 0.0, at[1]), yaw, s))

            if k % BOX_EVERY == BOX_EVERY // 2 and self.field("seepage", middle(p, self.faces)) >= BOXED:
                spot = _along(at, u, D.KERB_LENGTH * s / 2)
                back = D.KERB_DEPTH + 0.45
                self.add(place("junction_box", (spot[0] + inward[0] * back, self.level, spot[1] + inward[1] * back), yaw,
                               collider="mesh"))

    def hatches(self):
        for x, z in HATCHES:
            self.add(place("hatch", (x, self.level, z), 0.0))

            # The hall's hatches each have the Company's box beside them.
            if abs(z) < 50:
                self.add(place("junction_box", (x, self.level, z + math.copysign(1.4, z)), 0.0 if z > 0 else 180.0,
                               collider="mesh"))

    # The tram

    def tram(self):
        loop = [tuple(p) for p in self.data["tram"]][::-1]     # turning left at each corner
        r = D.CURVE_RADIUS

        for i, a in enumerate(loop):
            b = loop[(i + 1) % len(loop)]
            u, length = _unit(a, b)
            start = _along(a, u, r)
            n, s = fill(length - 2 * r, D.TRACK_LENGTH)

            if abs(s - 1.0) > 1e-9:
                raise ValueError("the tram's run %s-%s is not whole track pieces (%.4f)" % (a, b, s))

            for k in range(n):
                at = _along(start, u, k * D.TRACK_LENGTH)
                p = place("tram_track", (at[0], 0.0, at[1]), yaw_of(u))
                mid = middle(p, self.faces)

                if self.field("subsidence", mid) >= HEAVE:
                    p["piece"] = "tram_track_shimmed"

                self.add(p)

                if self.field("seepage", mid) >= SEEPED:
                    self.add(place("tram_conductor", (at[0], 0.0, at[1]), yaw_of(u)))

            end = _along(b, u, -r)
            self.add(place("tram_track_curve", (end[0], 0.0, end[1]), yaw_of(u)))

    # The causeway

    def causeway(self):
        line = [tuple(p) for p in self.data.get("causeway", [])]
        x0, z0, x1, z1 = _bounds(self.plaza["polygon"])
        tram = [tuple(p) for p in self.data["tram"]]

        for a, b in zip(line, line[1:]):
            u, length = _unit(a, b)
            cuts = []

            # Across the tram's strip.
            for c, d in zip(tram, tram[1:] + tram[:1]):
                t = _crossing(a, b, c, d)

                if t is not None:
                    cuts.append((t * length - D.STRIP_HALF, t * length + D.STRIP_HALF))

            # Across the plaza's kerb, where the drop lets it through.
            corners = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]

            for c, d in zip(corners, corners[1:] + corners[:1]):
                t = _crossing(a, b, c, d)

                if t is not None:
                    edge = t * length
                    inside = _inside_rect(_along(a, u, edge + 0.01), (x0, z0, x1, z1))
                    cuts.append((edge, edge + D.KERB_DEPTH + D.DROP_RAMP) if inside else (edge - D.KERB_DEPTH - D.DROP_RAMP, edge))

            for t0, t1 in _gaps(0.0, length, cuts):
                mid = _along(a, u, (t0 + t1) / 2)
                y = self.level if _inside_rect(mid, (x0, z0, x1, z1)) else 0.0
                n, s = fill(t1 - t0, D.BAND)

                for k in range(n):
                    at = _along(a, u, t0 + k * D.BAND * s)
                    self.add(place("causeway_band", (at[0], y, at[1]), yaw_of(u), s))

    # The canal

    def canal_walls(self):
        x0, z0, x1, z1 = _bounds(self.canal["polygon"])
        x0, x1 = x0 + BRINK_GAP, x1 - BRINK_GAP
        landings = sorted(_bounds(g["polygon"])[0::2] for g in self.landings)
        mouths = sorted(o["at"][0] for s in self.data["spaces"] for o in s["openings"] if o["to"] == self.canal["name"])
        bridges = [b["points"][0][0] for b in self.bridges]
        body = (D.WALL_FOOT, 0.0, -D.WALL_THICK, 0.0)
        lip = (-D.COPING_DEPTH, 0.0, 0.0, D.COPING_PROUD)

        # The north wall, its face on the canal's north edge, looking south;
        # broken at each landing (its low wet wall a metre down).
        cuts = [(lx0, lx1) for lx0, lx1 in landings]
        north = _gaps(x0, x1, cuts)

        for a, b in north:
            self.wall_run((a, z0), (1.0, 0.0), b - a, "canal_wall", 0.0, avoid=bridges + [v for c in cuts for v in c])
            self.collide_run((a, z0), (1.0, 0.0), b - a, body)
            self.collide_run((a, z0), (1.0, 0.0), b - a, lip)

        # The south wall looking north, from the east, broken at the walkway's mouths.
        width = D.WALL_LENGTH
        cuts = [(m - width / 2, m + width / 2) for m in mouths]

        for a, b in _gaps(x0, x1, cuts)[::-1]:
            self.wall_run((b, z1), (-1.0, 0.0), b - a, "canal_wall", 0.0, avoid=bridges + [v for c in cuts for v in c])
            self.collide_run((b, z1), (-1.0, 0.0), b - a, body)
            self.collide_run((b, z1), (-1.0, 0.0), b - a, lip)

        for m in mouths:
            self.add(place("culvert_open", (m + width / 2, 0.0, z1), yaw_of((-1.0, 0.0)), collider="mesh"))


    def wall_run(self, a, u, length, piece, y, avoid=()):
        """A canal wall's run from a along u, a culvert in every tenth piece
        and a mooring ring on every fourth one's coping, clear of `avoid`
        (bridges and landings, by x)."""
        n, s = fill(length, D.WALL_LENGTH)
        # The coping's middle, behind the wall's face.
        back = (D.COPING_BACK - D.COPING_PROUD) / 2
        behind = (u[1], -u[0])

        for k in range(n):
            at = _along(a, u, k * D.WALL_LENGTH * s)
            centre = _along(at, u, D.WALL_LENGTH * s / 2)
            clear = all(abs(centre[0] - v) > CLEAR + D.WALL_LENGTH for v in avoid)
            name = "culvert" if k % CULVERT_EVERY == CULVERT_EVERY // 2 and clear else piece
            self.add(place(name, (at[0], y, at[1]), yaw_of(u), s))

            if k % RING_EVERY == RING_EVERY // 2 and clear and name == piece:
                self.add(place("mooring_ring", (centre[0] + behind[0] * back, y, centre[1] + behind[1] * back), 0.0))

    def landing(self, g):
        x0, z0, x1, z1 = _bounds(g["polygon"])
        c = D.CORNER
        low = (D.WALL_FOOT + 1.0, 0.0, -D.WALL_THICK, 0.0)
        self.add(place("canal_wall_corner", (x0, 0.0, z0), 0.0, collider="mesh"))
        self.add(place("canal_wall_corner", (x1, 0.0, z0), -90.0, collider="mesh"))

        for a, u, length, y, names in (((x0 + c, z0), (1.0, 0.0), x1 - x0 - 2 * c, 0.0, ("canal_wall_low", "canal_wall_low_short")),
                                       ((x0, z1 - c), (0.0, -1.0), z1 - z0 - 2 * c, 0.0, ("canal_wall_low", "canal_wall_low_short")),
                                       ((x1, z0 + c), (0.0, 1.0), z1 - z0 - 2 * c, 0.0, ("canal_wall_low", "canal_wall_low_short")),
                                       ((x0, z1), (1.0, 0.0), x1 - x0, D.LANDING, ("canal_wall_low_wet", "canal_wall_low_wet_short"))):
            pitches, s = fill_mixed(length, (D.WALL_LENGTH, D.WALL_SHORT))
            t = 0.0

            for pitch in pitches:
                at = _along(a, u, t)
                self.add(place(names[0] if pitch == D.WALL_LENGTH else names[1], (at[0], y, at[1]), yaw_of(u), s))
                t += pitch * s

            yaw = yaw_of(u)
            centre = world({"at": [a[0], y, a[1]], "yaw": yaw}, (length / 2, low[0] / 2, -D.WALL_THICK / 2))
            self.boxes.append({"box": [*centre, length, -low[0], D.WALL_THICK], "yaw": yaw})
            # Its coping, proud of its face.
            lip = world({"at": [a[0], y, a[1]], "yaw": yaw}, (length / 2, -D.COPING_DEPTH / 2, D.COPING_PROUD / 2))
            self.boxes.append({"box": [*lip, length, D.COPING_DEPTH, D.COPING_PROUD], "yaw": yaw})

        # From the quay down to the landing beside its west wall (its back
        # wall stands against the town hall), reached over that wall's coping;
        # from the landing down to the water.
        self.add(place("canal_landing_steps", (x0 + D.COPING_PROUD + D.STEP_WIDTH / 2, 0.0, z0 + D.COPING_PROUD),
                       yaw_of((0.0, 1.0)), collider="mesh"))
        self.add(place("canal_landing_steps", (x0 + 12.0, D.LANDING, z1 + D.COPING_PROUD), yaw_of((0.0, 1.0)),
                       collider="mesh"))

    def bridges_(self):
        def nearness(route):
            x, z = route["points"][0][0], (route["points"][0][2] + route["points"][-1][2]) / 2
            return min(math.hypot(x - e["centre"][0], z - e["centre"][1]) / e["radius"]
                       for e in self.data["events"] if e["kind"] == "seepage" and "centre" in e), -x

        steel = min(self.bridges, key=nearness)

        for route in self.bridges:
            (ax, _, az), (bx, _, bz) = route["points"][0], route["points"][-1]
            mid = ((ax + bx) / 2, (az + bz) / 2)
            u, _ = _unit((ax, az), (bx, bz))
            name = "bridge_steel" if route is steel else "bridge_stone"
            self.add(place(name, (mid[0], 0.0, mid[1]), yaw_of(u), collider="mesh"))
            half = D.BRIDGE_WIDTH / 2
            self.openings[0.0].append([mid[0] - half, min(az, bz), mid[0] + half, max(az, bz)])

    # The ground

    def ground(self):
        bx0, bz0, bx1, bz1 = _bounds(self.data["brink"])
        px0, pz0, px1, pz1 = _bounds(self.plaza["polygon"])
        cx0, cz0, cx1, cz1 = _bounds(self.canal["polygon"])
        back = D.COPING_BACK
        flags = [g for g in self.data["ground"] if g["kind"] in ("atrium", "courtyard")]
        sunken = [g for g in self.data["ground"] if g["kind"] in plan.SUNKEN_KINDS and g["kind"] not in ("canal", "landing")]
        openings = [[px0, pz0, px1, pz1], [cx0, cz0 - back, cx1, cz1 + back]]
        # A landing: its floor and back wall's coping; its side walls' copings
        # only as far as they run (the corners by its mouth keep the setts).
        for x0, z0, x1, z1 in (_bounds(g["polygon"]) for g in self.landings):
            openings += [[x0, z0 - back, x1, z1], [x0 - back, z0 - back, x0, z1 - D.CORNER],
                         [x1, z0 - back, x1 + back, z1 - D.CORNER]]
        openings += [list(_bounds(g["polygon"])) for g in flags + sunken]
        openings += self.openings[0.0]
        footprints = [{"rect": list(_bounds(p["polygon"])), "roofed": False} for p in self.data["plots"] if p["base"] >= 0]
        areas = [{"tile": "ground_setts", "level": 0.0, "rect": [bx0, bz0, bx1, bz1], "openings": openings,
                  "covered": [p["polygon"] for p in self.data["plots"] if p["base"] >= 0],
                  "inlays": self.inlays[0.0], "patches": self.patches(), "footprints": footprints}]
        inset = D.KERB_DEPTH
        wells = [list(_bounds(g["polygon"])) for g in self.data["ground"] if g["kind"] == "well"]
        areas.append({"tile": "ground_flags", "level": self.level, "rect": [px0 + inset, pz0 + inset, px1 - inset, pz1 - inset],
                      "openings": wells + self.openings[round(self.level, 3)], "covered": [],
                      "inlays": self.inlays[round(self.level, 3)], "patches": [], "footprints": []})
        areas += [{"tile": "ground_flags", "level": 0.0, "rect": list(_bounds(g["polygon"])), "openings": [], "covered": [],
                   "inlays": [], "patches": [], "footprints": []} for g in flags]
        areas += [{"tile": "ground_setts", "level": D.LANDING, "rect": [x0, z0, x1, z1 - back], "openings": [], "covered": [],
                   "inlays": [], "patches": [], "footprints": []} for x0, z0, x1, z1 in (_bounds(g["polygon"]) for g in self.landings)]
        areas.append({"tile": "ground_earth", "level": D.WATER, "rect": [cx0, cz0, cx1, cz1], "openings": [], "covered": [],
                      "inlays": [], "patches": [], "footprints": []})
        return {"chunk": 50.0, "areas": areas}

    def patches(self):
        """Stone relaid where the ground sank: a 2-4 m patch every 150 m2 or
        so of street where subsidence is 0.3 or more."""
        out = []
        step = math.sqrt(150.0)
        streets = [g["polygon"] for g in self.data["ground"] if g["kind"] in ("street", "market")]
        bx0, bz0, bx1, bz1 = _bounds(self.data["brink"])
        x = bx0 + step / 2

        while x < bx1:
            z = bz0 + step / 2

            while z < bz1:
                if self.field("subsidence", (x, z)) >= 0.3 and any(_inside(x, z, g) for g in streets):
                    h = [(zlib.crc32(("%d,%d,%d" % (round(x), round(z), k)).encode()) % 1000) / 1000.0 for k in range(4)]
                    w, d = 2.0 + 2.0 * h[0], 2.0 + 2.0 * h[1]
                    cx, cz = x + (h[2] - 0.5) * 4.0, z + (h[3] - 0.5) * 4.0
                    out.append([round(cx - w / 2, 3), round(cz - d / 2, 3), round(cx + w / 2, 3), round(cz + d / 2, 3)])

                z += step

            x += step

        return out

    def skip(self):
        out = ["ground"] + [g["name"] for g in self.data["ground"] if g["kind"] in SKIP_GROUNDS]
        out += [r["name"] for r in self.data["routes"] if r["kind"] in SKIP_ROUTES]
        out += [r["name"] for r in self.data["routes"]
                if r["kind"] == "stair" and any(r["name"].startswith(g["name"] + "_") for g in self.landings)]
        return out


def dress(data, faces):
    d = Dresser(data, faces)
    d.plaza_kerbs()
    d.hatches()
    d.tram()
    d.causeway()
    d.canal_walls()

    for g in d.landings:
        d.landing(g)

    d.bridges_()
    return {"skip": d.skip(), "pieces": d.pieces, "colliders": d.boxes, "ground": d.ground()}


# Geometry

def _bounds(polygon):
    xs = [p[0] for p in polygon]
    zs = [p[1] for p in polygon]
    return (min(xs), min(zs), max(xs), max(zs))


def _rect_of(points):
    return list(_bounds(points))


def _inside_rect(p, r):
    return r[0] < p[0] < r[2] and r[1] < p[1] < r[3]


def _inside(x, z, polygon):
    inside = False

    for (ax, az), (bx, bz) in zip(polygon, polygon[1:] + polygon[:1]):
        if (az > z) != (bz > z) and x < ax + (z - az) * (bx - ax) / (bz - az):
            inside = not inside

    return inside


def _crossing(a, b, c, d):
    """Where along a-b (0-1) it crosses the segment c-d, or None."""
    rx, rz = b[0] - a[0], b[1] - a[1]
    sx, sz = d[0] - c[0], d[1] - c[1]
    cross = rx * sz - rz * sx

    if abs(cross) < 1e-12:
        return None

    t = ((c[0] - a[0]) * sz - (c[1] - a[1]) * sx) / cross
    v = ((c[0] - a[0]) * rz - (c[1] - a[1]) * rx) / cross
    return t if 0.0 < t < 1.0 and 0.0 <= v <= 1.0 else None


def _gaps(lo, hi, cuts):
    """The stretches of [lo, hi] left between the cuts (lo, hi pairs)."""
    out = []
    at = lo

    for c0, c1 in sorted(cuts):
        if c0 > at:
            out.append((at, c0))

        at = max(at, c1)

    if hi > at:
        out.append((at, hi))

    return out


# The gate

def placed_faces(dressing, faces):
    """Every placed piece's faces in the plan's axes, its owner the placement."""
    out = []

    for k, p in enumerate(dressing["pieces"]):
        (ax, az), (bx, bz) = _axes(p["yaw"])
        s = p.get("stretch", 1.0)

        for f in faces[p["kit"]]["objects"][p["piece"]]:
            nx, ny, nz = f["normal"]
            n = (nx / s * ax + nz * bx, ny, nx / s * az + nz * bz)
            length = math.sqrt(sum(c * c for c in n)) or 1.0
            out.append({"owner": "%s#%d" % (p["piece"], k), "normal": [c / length for c in n],
                        "points": [world(p, q) for q in f["points"]]})

    return out


def gate(dressing, greybox_data, faces):
    """One line a problem: two pieces' (or a piece's and the greybox's) faces
    in one plane facing one way, or same-facing within LAYER_GAP."""
    kept = [{"owner": m["name"], "normal": f["normal"], "points": [tuple(p) for p in f["points"]]}
            for m in greybox_data["meshes"] if m["name"] not in dressing["skip"] for f in m["faces"]]
    placed = placed_faces(dressing, faces)
    every = placed + kept
    first_kept = len(placed)
    normals = [overlap._unit(f["normal"]) for f in every]
    distances = [overlap._dot(n, f["points"][0]) for n, f in zip(normals, every)]
    buckets = defaultdict(list)

    for i, f in enumerate(every):
        n = normals[i]
        xs = [p[0] for p in f["points"]]
        zs = [p[2] for p in f["points"]]
        plane = (round(n[0], 2), round(n[1], 2), round(n[2], 2), math.floor(distances[i] / LAYER_GAP))

        for cx in range(math.floor(min(xs) / CELL), math.floor(max(xs) / CELL) + 1):
            for cz in range(math.floor(min(zs) / CELL), math.floor(max(zs) / CELL) + 1):
                buckets[plane + (cx, cz)].append(i)

    seen = set()
    problems = []

    for key, members in buckets.items():
        near = members + buckets.get(key[:3] + (key[3] + 1,) + key[4:], [])

        for x, i in enumerate(members):
            for j in near[x + 1:]:
                if i >= first_kept and j >= first_kept:
                    continue

                pair = (min(i, j), max(i, j))

                if pair in seen or every[i]["owner"] == every[j]["owner"]:
                    continue

                seen.add(pair)
                apart = abs(distances[i] - distances[j])

                if apart > LAYER_GAP or overlap._dot(normals[i], normals[j]) < overlap.SAME_WAY:
                    continue

                axes = overlap._axes(normals[i])
                pi, pj = overlap._flat(every[i]["points"], axes), overlap._flat(every[j]["points"], axes)
                bi, bj = overlap._box(pi), overlap._box(pj)

                if bi[2] <= bj[0] or bj[2] <= bi[0] or bi[3] <= bj[1] or bj[3] <= bi[1]:
                    continue

                shared = overlap._clipped(pi, pj)
                area = abs(overlap._area(shared)) if len(shared) >= 3 else 0.0

                if area >= overlap.LEAST:
                    what = "fight" if apart <= overlap.TOLERANCE else "layered %.1f cm" % (apart * 100)
                    problems.append("%s: %s and %s, %.3f m2 near (%.1f, %.1f, %.1f)" % (
                        what, every[i]["owner"], every[j]["owner"], area, *every[i]["points"][0]))

    return problems


def main(argv):
    data = json.loads(Path(argv[0]).read_text())
    box_data = json.loads(Path(argv[1]).read_text())
    faces = load_faces()
    missing = [k for k in KITS if k not in faces]

    if missing:
        print("dress: kits not built: %s (tools/eclipse/lab.sh all)" % ", ".join(missing))
        return 1

    dressing = dress(data, faces)
    Path(argv[2]).write_text(json.dumps(dressing))
    problems = gate(dressing, box_data, faces)

    for p in problems[:40]:
        print("dress:", p)

    print("dress: %d pieces, %d colliders, %d ground areas, %d problems -> %s" % (
        len(dressing["pieces"]), len(dressing["colliders"]), len(dressing["ground"]["areas"]), len(problems), argv[2]))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
