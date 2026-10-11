"""The Zócalo's street life laid densely over family 1's dressing (the
street-life plan, docs/superpowers/plans/2026-10-10-zocalo-street-life.md,
Task 6; the card's density table): guard stones and Talavera plaques at
every street corner, the Company's poles, wires and lamps round the ring,
wards where streets go dark, kiosks round the plaza, carts down the market
lanes, poster columns and boards, the seeped future, the Bound God and its
offerings, the dead's booths, El Secreto's containment, the market's pulp.

`life(d)` adds to a dress.Dresser: its pieces, box colliders, inlays and a
`lights` list (one per lit lamp). A standing piece is laid only where it
fits: on open ground, clear of plots, sunken places, flush pieces and
every other standing piece.
"""

import math
import zlib

import dress
import plan
import plan_check
import street_dims as D

# Pieces on walls (4 cm off a plot's face) and pieces hung from others.
ON_WALLS = {"plaque_talavera", "plate_street", "poster_cluster"}
HUNG = {"span_wire", "trolley_wire", "traffic_light_dead", "sigil_disc", "ward_plate", "payphone_seeped", "chain_span"}
POLES = {"tram_pole", "tram_pole_lamp", "lamp_dead", "ward_cage_lamp"}
# Standing pieces that may overlap these (the heap at the god's foot, chain posts and their chain).
TOGETHER = {("offerings_heap", "bound_god"), ("bound_god", "offerings_heap")}
# Pieces that may stand on a flush piece (the offerings on the causeway's band, petals on anything).
ON_FLUSH = {"offerings_heap", "petals_marigold", "bound_god"}
# Pieces that stand on the canal's copings (over the walls' footprints).
ON_COPING = {"bollard_chain_post"}
COPING_PIECES = ("canal_wall", "culvert", "mooring_ring")
OFF_WALL = 0.04
OPEN_KINDS = ("street", "market", "plaza", "atrium", "courtyard")
# The overhead: poles this far either side of the track, about this far apart.
POLE_OFF = 5.4
POLE_EVERY = 30.0
SPAN = 10.8                      # the span wire piece's length
TROLLEY = 30.0                   # the trolley wire piece's length
GOD_RING = 9.0
LAMP_RANGE = 14.0
COMPANY = "#e8d8a8"
WARD = "#CFE8F0"
DARK = 20.0                      # a spot further than this from a lit lamp is dark
CARTS = ["cart_hand", "cart_flower", "cart_tamale", "cart_ice", "cart_firewood"]
COLLIDE = {"bollard_guardstone", "bollard_cannon", "bollard_company", "bollard_chain_post", "bollard_seeped",
           "tram_stop", "parking_meter", "sign_bus_stop", "poster_column", "notice_board", "ward_hoarding",
           "kiosk_news", "kiosk_lottery", "kiosk_sweets", "shoeshine_stand", "booth_photographer", "stand_curiosities",
           "wagon_monster", "shrine_luchador", "crates_relics", "booth_line_of_dead", "booth_testimony", "cage_trap",
           "cage_trap_chaneque", "cage_trap_lechuza", "secreto_barrier", "idol_surfacing"} | set(CARTS) | POLES


def _hash(*keys):
    return (zlib.crc32(",".join("%.2f" % k for k in keys).encode()) % 100000) / 100000.0


def facing(f):
    """The yaw that turns a piece's front (local +Z) to look along f (x, z)."""
    return math.degrees(math.atan2(f[0], f[1]))


def _unit(v):
    length = math.hypot(v[0], v[1])
    return (v[0] / length, v[1] / length)


# Walls

def street_walls(data):
    """Every plot's wall that faces open ground: {"a", "b", "n" (outward),
    "plot", "length"}."""
    out = []
    grounds = [g["polygon"] for g in data["ground"] if g["kind"] in OPEN_KINDS]

    for p in data["plots"]:
        pts = [tuple(q) for q in p["polygon"]]

        for a, b in zip(pts, pts[1:] + pts[:1]):
            length = math.hypot(b[0] - a[0], b[1] - a[1])

            if length < 1.0:
                continue

            n = ((b[1] - a[1]) / length, -(b[0] - a[0]) / length)
            mid = ((a[0] + b[0]) / 2 + n[0] * 0.6, (a[1] + b[1]) / 2 + n[1] * 0.6)

            if any(plan_check.inside(mid, g) for g in grounds) and \
                    not any(plan_check.inside(mid, q["polygon"]) for q in data["plots"] if q is not p):
                out.append({"a": a, "b": b, "n": n, "plot": p, "length": length})

    return out


def wall_distance(w, p):
    return (p[0] - w["a"][0]) * w["n"][0] + (p[1] - w["a"][1]) * w["n"][1]


def within(w, p):
    d = ((w["b"][0] - w["a"][0]) / w["length"], (w["b"][1] - w["a"][1]) / w["length"])
    t = (p[0] - w["a"][0]) * d[0] + (p[1] - w["a"][1]) * d[1]
    return -1e-6 <= t <= w["length"] + 1e-6


# Footprints

# A tree's trunk (half its width, m): its footprint and its collider; its
# limbs and crown are overhead.
TRUNKS = {"tree_ash": 0.35, "tree_ash_young": 0.25, "palm_canary": 0.55, "tree_laurel": 0.7, "tree_willow": 0.4,
          "ahuehuete_split": 1.5}


def foot(p, faces):
    """A placement's footprint (x0, z0, x1, z1): a pole's its shaft only
    (its arm and lamp hang over the street), the god's its plinth, a tree's
    its trunk."""
    x, z = p["at"][0], p["at"][2]

    if p["piece"] in POLES:
        return (x - 0.2, z - 0.2, x + 0.2, z + 0.2)

    if p["piece"] in TRUNKS:
        r = TRUNKS[p["piece"]]
        return (x - r, z - r, x + r, z + r)

    lo, hi = dress.box(p, faces)
    return (lo[0], lo[2], hi[0], hi[2])


def insulator(p):
    """Where a pole's span wire bracket ends (x, z)."""
    w = dress.world(p, (0.0, 6.0, 0.34))
    return (w[0], w[2])


def globe(p):
    return dress.world(p, (0.0, 6.5, 1.15))


class Life:
    def __init__(self, d):
        self.d = d
        self.data = d.data
        self.faces = d.faces
        self.cells = {}
        self.flush = {}
        self.grounds = [g["polygon"] for g in self.data["ground"] if g["kind"] in OPEN_KINDS]
        self.sunken = [plan_check._bounds(g["polygon"]) for g in self.data["ground"] if g["kind"] in plan.SUNKEN_KINDS]
        self.plots = self.data["plots"]
        self.walls = street_walls(self.data)
        self.lamps = []
        px0, pz0, px1, pz1 = plan_check._bounds(d.plaza["polygon"])
        self.plaza = (px0 + D.KERB_DEPTH, pz0 + D.KERB_DEPTH, px1 - D.KERB_DEPTH, pz1 - D.KERB_DEPTH)

        for p in d.pieces:
            if p["piece"] in dress.FLUSH:
                self._index(self.flush, dress._bounds(dress.outline(p)), p["piece"], dress.outline(p))
            else:
                self._index(self.cells, foot(p, self.faces), p["piece"])

        # Walls carrying a greybox ladder (its board 2 cm off them) take no posters.
        self.climbs = [r for r in self.data["routes"] if r["kind"] == "climb"]

    # Occupancy

    def _index(self, table, f, name="", outline=None, when=None):
        for i in range(math.floor(f[0] / 10), math.floor(f[2] / 10) + 1):
            for j in range(math.floor(f[1] / 10), math.floor(f[3] / 10) + 1):
                table.setdefault((i, j), []).append((f, name, outline, when))

    def _clear(self, table, f, ignore=(), when=None):
        """Whether `f` meets nothing in `table` but what it may (`ignore`'s
        names; a day part meets a night part, never seen together)."""
        for i in range(math.floor(f[0] / 10), math.floor(f[2] / 10) + 1):
            for j in range(math.floor(f[1] / 10), math.floor(f[3] / 10) + 1):
                for g, name, outline, at in table.get((i, j), []):
                    if name.startswith(ignore) if ignore else False:
                        continue

                    if {when, at} == {"day", "night"}:
                        continue

                    if f[0] + 0.02 < g[2] and g[0] + 0.02 < f[2] and f[1] + 0.02 < g[3] and g[1] + 0.02 < f[3]:
                        # A curved flush piece: its own outline, not its box.
                        if outline is not None and len(outline) > 4:
                            rect = plan_check.oriented([(f[0], f[1]), (f[2], f[1]), (f[2], f[3]), (f[0], f[3])]) \
                                if hasattr(plan_check, "oriented") else [(f[0], f[1]), (f[2], f[1]), (f[2], f[3]), (f[0], f[3])]

                            if plan_check.overlap_area(outline, rect) < 1e-4:
                                continue

                        return False

        return True

    def open(self, x, z):
        if not any(plan_check.inside((x, z), g) for g in self.grounds):
            return False

        if any(s[0] < x < s[2] and s[1] < z < s[3] for s in self.sunken):
            return False

        return not any(plan_check.inside((x, z), p["polygon"]) for p in self.plots)

    def level(self, x, z):
        r = self.plaza
        return self.d.level if r[0] < x < r[2] and r[1] < z < r[3] else 0.0

    def put(self, piece, x, z, yaw, stretch=1.0, y=None, ground=True, collider=None, when=None):
        """Lay a standing piece if it fits: its footprint on open ground (if
        `ground`), clear of every standing piece and (most) flush ones."""
        p = self.fits(piece, x, z, yaw, stretch, y, ground, collider, when)
        return self.commit(p, when) if p is not None else None

    def fits(self, piece, x, z, yaw, stretch=1.0, y=None, ground=True, collider=None, when=None):
        """The placement `put` would lay, if it fits; nothing laid."""
        p = dress.place(piece, (x, self.level(x, z) if y is None else y, z), yaw, stretch, collider=collider)
        f = foot(p, self.faces)

        if ground:
            corners = [(f[0] + 0.03, f[1] + 0.03), (f[2] - 0.03, f[1] + 0.03), (f[0] + 0.03, f[3] - 0.03),
                       (f[2] - 0.03, f[3] - 0.03), ((f[0] + f[2]) / 2, (f[1] + f[3]) / 2)]

            if not all(self.open(*c) for c in corners):
                return None

            # A piece stands on one level (never across the plaza's kerb).
            if len({self.level(*c) for c in corners}) > 1:
                return None

        if not self._clear(self.cells, f, COPING_PIECES if piece in ON_COPING else (), when):
            return None

        if piece not in ON_FLUSH and not self._clear(self.flush, f, (), when):
            return None

        return p

    def commit(self, p, when=None):
        """Lays a placement `fits` gave: its footprint taken, its collider
        made (a part of the day or the night tagged so)."""
        if when in ("day", "night"):
            p["when"] = when

        self.d.add(p)
        self._index(self.cells, foot(p, self.faces), p["piece"], None, when)

        if p["piece"] in COLLIDE:
            self.collide(p)

            if when in ("day", "night"):
                self.d.boxes[-1]["when"] = when

        return p

    def hang(self, piece, at, yaw, stretch=1.0):
        """A piece hung from or bolted to another: no footprint of its own."""
        return self.d.add(dress.place(piece, at, yaw, stretch))

    def collide(self, p):
        lo, hi = self._local_box(p)
        centre = dress.world(p, tuple((lo[k] + hi[k]) / 2 for k in range(3)))
        self.d.boxes.append({"box": [*centre, (hi[0] - lo[0]) * p.get("stretch", 1.0), hi[1] - lo[1], hi[2] - lo[2]],
                             "yaw": p["yaw"]})

    def _local_box(self, p):
        if p["piece"] in POLES:
            return (-0.15, 0.0, -0.15), (0.15, 8.0, 0.15)

        if p["piece"] in TRUNKS:
            r = TRUNKS[p["piece"]]
            return (-r, 0.0, -r), (r, 3.0, r)

        points = [q for f in self.faces[p["kit"]]["objects"][p["piece"]] for q in f["points"]]
        lo = [min(q[k] for q in points) for k in range(3)]
        hi = [max(q[k] for q in points) for k in range(3)]
        lo[1] = max(lo[1], 0.0)
        return lo, hi

    # Corners and walls

    def corners(self):
        """Guard stones and cannons at every plot corner on open ground; the
        old street name's Talavera plaque and the 1921 plate beside each
        corner on its street faces (plots at least 5 m high)."""
        by_plot = {}

        for w in self.walls:
            by_plot.setdefault(id(w["plot"]), []).append(w)

        for walls in by_plot.values():
            plot = walls[0]["plot"]
            pts = [tuple(q) for q in plot["polygon"]]

            for k, c in enumerate(pts):
                prev, nxt = pts[k - 1], pts[(k + 1) % len(pts)]
                n1 = _unit(((c[1] - prev[1]), -(c[0] - prev[0])))
                n2 = _unit(((nxt[1] - c[1]), -(nxt[0] - c[0])))
                bis = _unit((n1[0] + n2[0], n1[1] + n2[1])) if abs(n1[0] + n2[0]) + abs(n1[1] + n2[1]) > 1e-6 else n1
                stone = "bollard_guardstone" if _hash(c[0], c[1]) < 0.65 else "bollard_cannon"
                self.put(stone, c[0] + bis[0] * 0.45, c[1] + bis[1] * 0.45, facing(bis))

            if plan.top(plot) < 5.0:
                continue

            for w in walls:
                if w["length"] < 2.0:
                    continue

                d = ((w["b"][0] - w["a"][0]) / w["length"], (w["b"][1] - w["a"][1]) / w["length"])

                for end, sign in ((w["a"], 1), (w["b"], -1)):
                    x = end[0] + d[0] * 0.6 * sign + w["n"][0] * OFF_WALL
                    z = end[1] + d[1] * 0.6 * sign + w["n"][1] * OFF_WALL
                    base = self.level(x + w["n"][0] * 0.5, z + w["n"][1] * 0.5)
                    self.hang("plaque_talavera", (x, base + 4.5, z), facing(w["n"]))
                    self.hang("plate_street", (x, base + 3.9, z), facing(w["n"]))

    def _climbed(self, w):
        """Whether a greybox ladder stands on this wall (its board 2 cm off it)."""
        for r in self.climbs:
            a, b = r["points"][0], r["points"][-1]
            mid = ((a[0] + b[0]) / 2, (a[2] + b[2]) / 2)

            if abs(wall_distance(w, mid)) < 1.5 and within(w, mid):
                return True

        return False

    def posters(self):
        """Posters pasted over posters on one street wall in three (3 m or longer)."""
        for k, w in enumerate(self.walls):
            if k % 3 or w["length"] < 3.0 or self._climbed(w):
                continue

            n = w["n"]
            d = (n[1], -n[0])          # local +X along the wall, the face looking out along n
            ax, az = w["a"]
            bx, bz = w["b"]
            mid = ((ax + bx) / 2, (az + bz) / 2)
            x = mid[0] - d[0] * 1.2 + n[0] * OFF_WALL
            z = mid[1] - d[1] * 1.2 + n[1] * OFF_WALL
            base = self.level(mid[0] + n[0] * 0.5, mid[1] + n[1] * 0.5)
            self.hang("poster_cluster", (x, base + 1.2, z), facing(n))

    # The Company's overhead

    def overhead(self):
        loop = [tuple(p) for p in self.data["tram"]][::-1]
        r = D.CURVE_RADIUS
        mids = []                  # span middles in order round the loop
        poles = []

        for i, a in enumerate(loop):
            b = loop[(i + 1) % len(loop)]
            c = loop[(i + 2) % len(loop)]
            u, length = dress._unit(a, b)
            u2, _ = dress._unit(b, c)
            start = dress._along(a, u, r)
            run = length - 2 * r
            m = max(1, round(run / POLE_EVERY))

            for k in range(m + 1):
                p = dress._along(start, u, run * k / m)
                poles.append(self._pole_pair(p, (u[1], -u[0]), i, k, k == m // 2))
                mids.append(p)

            # The curve's middle: a pair standing radially from its centre.
            centre = (b[0] - u[0] * r + u2[0] * r, b[1] - u[1] * r + u2[1] * r)
            out = _unit((b[0] - centre[0], b[1] - centre[1]))
            mid = (centre[0] + out[0] * r, centre[1] + out[1] * r)
            poles.append(self._pole_pair(mid, out, i, -1, False, curve=True))
            mids.append(mid)

        # The trolley wire over the track from span to span, round the loop.
        for k, a in enumerate(mids):
            b = mids[(k + 1) % len(mids)]
            u, length = dress._unit(a, b)
            self.hang("trolley_wire", (a[0], 0.0, a[1]), dress.yaw_of(u), length / TROLLEY)

    def _pole_pair(self, p, n, leg, k, middle, curve=False):
        """Two poles across the track at p (n across it), a span between."""
        laid = []

        for side in (1, -1):
            x, z = p[0] + n[0] * side * POLE_OFF, p[1] + n[1] * side * POLE_OFF
            count = len(self.lamps) + len([q for q in self.d.pieces if q["piece"] in POLES])
            piece = "tram_pole"

            if middle:
                piece = "ward_cage_lamp"
            elif count % 2 == 0:
                piece = "lamp_dead" if count % 8 == 0 and self.d.field("seepage", (x, z)) < 0.3 else "tram_pole_lamp"

            q = self.put(piece, x, z, facing((-n[0] * side, -n[1] * side)))

            if q is None:
                q = self.put("tram_pole", x, z, facing((-n[0] * side, -n[1] * side)), ground=False)

            if q is not None:
                laid.append(q)
                self.light(q)

        if len(laid) == 2:
            a, b = insulator(laid[0]), insulator(laid[1])
            u, length = dress._unit(a, b)
            self.hang("span_wire", (a[0], 0.0, a[1]), dress.yaw_of(u), length / SPAN)

            if curve:
                mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
                # Turned across the wire, its hanger never lies along the wire's facets.
                self.hang("traffic_light_dead", (mid[0], 6.0 - 0.3, mid[1]), dress.yaw_of(u) + 45.0)

        return laid

    def light(self, p):
        if p["piece"] in ("tram_pole_lamp", "ward_cage_lamp"):
            ward = p["piece"] == "ward_cage_lamp"
            self.lamps.append((p["at"][0], p["at"][2]))
            self.d.lights.append({"at": list(globe(p)), "colour": WARD if ward else COMPANY, "range": LAMP_RANGE,
                                  "shadow": ward and math.hypot(p["at"][0], p["at"][2]) < GOD_RING + 0.5})

    def wards(self):
        """A sigil disc and a ward plate on every pole whose back looks into a
        side street, a dead lamp's foot scored by claws, petals under it."""
        for p in [q for q in self.d.pieces if q["piece"] in POLES]:
            # (The god's ring is ward enough: its cages.)
            if math.hypot(p["at"][0], p["at"][2]) < GOD_RING + 1.0:
                continue

            back = dress.world(p, (0.0, 0.0, -1.0))
            out = _unit((back[0] - p["at"][0], back[2] - p["at"][2]))
            probe = (p["at"][0] + out[0] * 12.0, p["at"][2] + out[1] * 12.0)

            if self.open(*probe) and not self._ring(probe):
                for piece, h in (("sigil_disc", 2.3), ("ward_plate", 1.7)):
                    self.hang(piece, (p["at"][0] + out[0] * 0.13, p["at"][1] + h, p["at"][2] + out[1] * 0.13), facing(out))

            if p["piece"] == "lamp_dead":
                front = dress.world(p, (0.0, 0.0, 1.3))
                slab = dress.place("claw_scored_slab", (front[0], p["at"][1], front[2]), p["yaw"])

                if self._clear(self.flush, dress._bounds(dress.outline(slab))):
                    self.d.add(slab)
                    self._index(self.flush, dress._bounds(dress.outline(slab)), "claw_scored_slab", dress.outline(slab))

    def _ring(self, xz):
        ring = [g["polygon"] for g in self.data["ground"] if g["name"] in ("north_street", "south_street", "west_street",
                                                                           "east_street")]
        return any(plan_check.inside(xz, g) for g in ring)

    # The plaza

    def plaza_life(self):
        x0, z0, x1, z1 = self.plaza
        # The Bound God, its offerings, its ring of ward lamps.
        self.put("bound_god", 0.0, 0.0, 0.0, collider="mesh")
        self.put("offerings_heap", 0.0, 3.4, 0.0)

        for k in range(8):
            a = math.radians(22.5 + 45 * k)
            x, z = GOD_RING * math.cos(a), GOD_RING * math.sin(a)
            p = self.put("ward_cage_lamp", x, z, facing((-x, -z)))

            if p:
                self.light(p)

                if k in (1, 5):
                    out = _unit((x, z))
                    self.hang("payphone_seeped", (x + out[0] * 0.12, p["at"][1], z + out[1] * 0.12), facing(out))

        # Company bollards either side of each drop and round each corner.
        for p in [q for q in self.d.pieces if q["piece"] == "kerb_drop"]:
            for local in ((-0.5, 0.0, -0.9), (3.5, 0.0, -0.9), (-0.5, 0.0, -2.2), (3.5, 0.0, -2.2)):
                w = dress.world(p, local)
                self.put("bollard_company", w[0], w[2], p["yaw"])

        for cx, cz in ((x0, z0), (x1, z0), (x0, z1), (x1, z1)):
            ix, iz = (1 if cx < 0 else -1), (1 if cz < 0 else -1)

            for dx, dz in ((1.2, 0.5), (0.5, 1.2), (2.2, 0.5), (0.5, 2.2)):
                self.put("bollard_company", cx + ix * dx, cz + iz * dz, facing((-ix, -iz)))

        # The tram stop (its kiosk, the voceadores and the plaza's sellers are
        # the scenes', dress_scenes.py).
        self.put("tram_stop", 9.0, 126.0, facing((0.0, -1.0)))

        # Poster columns ringing the plaza's middle.
        for k in range(8):
            a = math.radians(22.5 + 45 * k)
            self.put("poster_column", 45.0 * math.cos(a), 45.0 * math.sin(a), 0.0)

        # El Secreto's boards (the dead's booths are the scenes').
        for x, z in ((-60.0, -104.0), (60.0, 104.0)):
            self.put("notice_board", x, z, facing((0.0, -1.0 if z < 0 else 1.0)))

        # Before El Secreto's palace (Santo Domingo's Inquisition), its registry boards.
        laid = 0

        for w in self.walls:
            if w["plot"]["family"] != "inquisition" or laid >= 2:
                continue

            mid = ((w["a"][0] + w["b"][0]) / 2, (w["a"][1] + w["b"][1]) / 2)

            for t in (0.0, 2.0, -2.0, 4.0, -4.0):
                d = ((w["b"][0] - w["a"][0]) / w["length"], (w["b"][1] - w["a"][1]) / w["length"])
                x = mid[0] + d[0] * t + w["n"][0] * 1.5
                z = mid[1] + d[1] * t + w["n"][1] * 1.5

                if self.put("notice_board", x, z, facing(w["n"])):
                    laid += 1
                    break

        # The seeped future where the seepage runs strongest (the plaza's middle).
        seeped = ["bollard_seeped", "parking_meter", "sign_bus_stop"]
        k = 0

        for r in (16.0, 24.0, 32.0):
            for a in range(12):
                if k >= 12:
                    break
                ang = math.radians(15 + 30 * a + 7 * r)
                x, z = r * math.cos(ang), r * math.sin(ang)

                if self.d.field("seepage", (x, z)) >= 0.5 and self.put(seeped[k % 3], x, z, facing((-x, -z))):
                    k += 1

    # The canal's chains

    def chains(self):
        cx0, cz0, cx1, cz1 = plan_check._bounds(self.d.canal["polygon"])
        back = (D.COPING_BACK - D.COPING_PROUD) / 2
        runs = []

        for b in self.d.bridges:
            x = b["points"][0][0]

            for z, y in ((cz0 - back, 0.0), (cz1 + back, 0.0)):
                runs += [(x - 22.0, x - 2.6, z, y), (x + 2.6, x + 22.0, z, y)]

        for g in self.d.landings:
            x0, _, x1, z1 = plan_check._bounds(g["polygon"])
            runs += [(x0 + 0.6, x0 + 10.5, z1 - back, D.LANDING)]

        for a, b, z, y in runs:
            last = None
            x = a

            while x <= b + 1e-6:
                p = self.put("bollard_chain_post", x, z, 0.0, y=y, ground=False)

                if p and last is not None and abs(last - x + 1.5) < 1e-6:
                    self.hang("chain_span", (last, y, z), 0.0)

                last = x if p else None
                x += 1.5

    # Streets and the market

    def side_streets(self):
        """Ward hoardings along the dark ends of the streets off the ring and
        Madero, standing out from a side wall (never across the way)."""
        laid = 0

        for g in self.data["ground"]:
            if g["kind"] != "street" or g["name"] in ("north_street", "south_street", "west_street", "east_street", "madero"):
                continue

            x0, z0, x1, z1 = plan_check._bounds(g["polygon"])
            along_x = (x1 - x0) >= (z1 - z0)
            width = (z1 - z0) if along_x else (x1 - x0)

            if width < 8.0 or laid >= 10:
                continue

            # 2.2 m out from the side wall: its braces reach 1.6 m behind it.
            for t in (0.85, 0.15, 0.5):
                if along_x:
                    x, z, face = x0 + (x1 - x0) * t, z0 + 2.2, (0.0, 1.0)
                else:
                    x, z, face = x0 + 2.2, z0 + (z1 - z0) * t, (1.0, 0.0)

                if self.put("ward_hoarding", x, z, facing(face)):
                    laid += 1
                    break

    def idols(self):
        """Where the ground sank hardest, a god's head surfaces through the
        setts, El Secreto's barrier before it."""
        candidates = []
        bx0, bz0, bx1, bz1 = plan_check._bounds(self.data["brink"])

        for i in range(int((bx1 - bx0) / 6)):
            for j in range(int((bz1 - bz0) / 6)):
                x, z = bx0 + 3 + 6 * i, bz0 + 3 + 6 * j
                s = self.d.field("subsidence", (x, z))

                if s >= 0.3 and self.open(x, z):
                    candidates.append((-s, x, z))

        laid = []

        for _, x, z in sorted(candidates):
            if len(laid) >= 3:
                break

            # (Its barrier, its copal and the city come to look: the idol_surfacing scene.)
            if all(math.hypot(x - a, z - b) > 30.0 for a, b in laid) and self.put("idol_surfacing", x, z, 0.0):
                laid.append((x, z))

    def sealed(self):
        for p in self.d.pieces:
            if p["piece"] == "hatch" and p["at"][2] < 0:
                p["piece"] = "hatch_sealed"
                p["kit"] = dress.kit_of("hatch_sealed")


def life(d):
    """The street's furniture by rule (the real city had these by rule);
    its life is the scenes' (dress_scenes.py): no market carts, kiosks,
    shoeshine stands, candles, petals or traps laid here."""
    L = Life(d)
    L.plaza_life()
    L.overhead()
    L.wards()
    L.corners()
    L.posters()
    L.chains()
    L.side_streets()
    L.idols()
    L.sealed()
    return L
