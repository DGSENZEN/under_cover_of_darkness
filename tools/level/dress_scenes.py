"""The Zócalo's life staged as scenes (the scenes plan, Task 5;
docs/superpowers/specs/2026-10-10-zocalo-scenes-design.md), after the
rules' furniture (dress_life.py):

- `sites(d, life)`: the real places a scene can stand, each with its reason
  (tram stops, Metro mouths, the god's ring, the market hall's doors, canal
  landings, church steps, arcades, street mouths, house fronts, corners,
  dark spots, where the ground sank, sealed hatches, claw-scored stone,
  the rails, the plaza's edge and corners, the market lanes, narrow streets
  to string washing across).
- `scenes(d, life)`: the landmark scenes at their places, then each zone
  filled to its density with the catalogue's scenes (scenes_catalogue.py),
  a scene staged whole or not at all.
- `garden(d, life)`: the plaza's garden (beds, edging, benches, trees), the
  street's trees, the pigeons' flocks, the canal's fog and the lamps' dust.

Everything goes on the dress.Dresser: pieces and colliders (a scene's
tagged with its index and, if it keeps to the day or the night, `when`),
`scenes`, `stations` (one per stand-in, for the NPCs to come), `emitters`
(Ambient.gd), `flocks` (Pigeons.gd) and `decals`.
"""

import json
import math
import random
from dataclasses import dataclass

import dress
import dress_life
import plan_check
import scenes_catalogue as catalogue
import street_dims as D

TREES = set(dress_life.TRUNKS)
# Pieces with no footprint of their own: overhead (washing on a line).
OVERHEAD = {"laundry_line"}
# Stand-ins and props that stop a man (figures, dogs, and the scenes' props
# a hand-span or more across); held things and things lying flat do not.
STANDS = ("fig_", "dog_")
NO_COLLIDER = {"laundry_line", "candles_drift", "petals_marigold", "flowers_bucket", "basket", "censer",
               "lantern_carried", "lantern_set", "firewood_bundle", "exvoto_plate"}

KINDS = ("god_ring", "hall_door", "market", "landing", "church_steps", "evangelistas", "arcade", "frontage",
         "street_mouth", "corner", "dark_spot", "subsidence", "sealed_hatch", "claw_slab", "rails", "tram_stop",
         "metro_mouth", "plaza_edge", "plaza_corner", "plaza_walk", "street_span")

# One scene in so many metres of a zone (the spec's table): a scene stands no
# nearer than this to another in its zone; none at all at the lanes' far ends.
DENSITY = {"plaza": 25.0, "hall": 25.0, "madero": 40.0, "side": 60.0, "other": 60.0, "lane_end": None}
# Outside the plaza and the hall, different scenes keep at least this apart.
APART = 15.0
ORDER = ("plaza", "hall", "madero", "side", "other")
MAIN = ("north_street", "south_street", "west_street", "east_street", "madero", "santo_domingo")
HALL_REACH = 60.0
LANE_END = 90.0
# The god's walk round its ring (Z16 walks it at 7 m): no stand-in or prop on it.
GOD_WALK = (6.4, 7.6)
# Rare places are staged before common ones, so a common scene never takes
# the room a rare one needed (a Metro mouth before the plaza's edge round it).
COMMON = ("frontage", "plaza_edge", "plaza_walk", "corner", "market", "dark_spot")
SEED = 1921
HANDS = json.loads((dress.ROOT / "assets" / "eclipse" / "source" / "figures_kit_hands.json").read_text()) \
    if hasattr(dress, "ROOT") else None


@dataclass
class Site:
    kind: str
    at: tuple
    facing: tuple
    reason: str
    zone: str = ""
    span: float = 0.0
    key: str = ""


def _unit(v):
    length = math.hypot(v[0], v[1]) or 1.0
    return (v[0] / length, v[1] / length)


def _hands():
    global HANDS

    if HANDS is None:
        from pathlib import Path
        root = Path(__file__).resolve().parents[2]
        HANDS = json.loads((root / "assets" / "eclipse" / "source" / "figures_kit_hands.json").read_text())

    return HANDS


# Zones

class Zones:
    def __init__(self, d):
        data = d.data
        self.plaza = plan_check._bounds(d.plaza["polygon"])
        hall = next(p for p in data["plots"] if p["name"] == "market_hall")
        b = plan_check._bounds(hall["polygon"])
        self.hall = ((b[0] + b[2]) / 2, (b[1] + b[3]) / 2)
        self.markets = [g["polygon"] for g in data["ground"] if g["kind"] == "market"]
        self.main = [g["polygon"] for g in data["ground"] if g["name"] in MAIN]
        self.streets = [g["polygon"] for g in data["ground"] if g["kind"] in ("street", "atrium", "courtyard")]
        self.fronts = [p["polygon"] for p in data["plots"] if p.get("family") in ("arcade", "evangelistas")]

    def of(self, x, z):
        r = self.plaza

        if r[0] <= x <= r[2] and r[1] <= z <= r[3]:
            return "plaza"

        to_hall = math.hypot(x - self.hall[0], z - self.hall[1])

        if to_hall <= HALL_REACH:
            return "hall"

        if any(plan_check.inside((x, z), g) for g in self.markets):
            return "lane_end" if to_hall > LANE_END else "other"

        if any(plan_check.inside((x, z), g) for g in self.main) or any(
                plan_check._bounds(f)[0] - 6 < x < plan_check._bounds(f)[2] + 6
                and plan_check._bounds(f)[1] - 6 < z < plan_check._bounds(f)[3] + 6 for f in self.fronts):
            return "madero"

        if any(plan_check.inside((x, z), g) for g in self.streets):
            return "side"

        return "other"


# Sites

def sites(d, life):
    """Every place a scene may stand, with its reason and zone."""
    data = d.data
    zones = Zones(d)
    out = [Site("god_ring", (0.0, 0.0), (0.0, 1.0), "the god's ring, where its offerings are", key="god_ring")]
    families = {"cathedral", "sagrario", "church"}

    for w in life.walls:
        plot = w["plot"]
        n = w["n"]
        d_ = ((w["b"][0] - w["a"][0]) / w["length"], (w["b"][1] - w["a"][1]) / w["length"])
        mid = ((w["a"][0] + w["b"][0]) / 2, (w["a"][1] + w["b"][1]) / 2)
        family = plot.get("family", "")
        name = plot["name"]
        out_at = lambda t, off: (w["a"][0] + d_[0] * t + n[0] * off, w["a"][1] + d_[1] * t + n[1] * off)

        if name == "market_hall" and w["length"] > 12.0:
            out.append(Site("hall_door", (mid[0] + n[0] * 3.0, mid[1] + n[1] * 3.0), n, "the market hall's doors"))
        elif family in families or name in families:
            out.append(Site("church_steps", (mid[0] + n[0] * 4.0, mid[1] + n[1] * 4.0), n, "before %s" % name.replace("_", " ")))
        elif family == "evangelistas" and w["length"] > 14.0:
            out.append(Site("evangelistas", (mid[0] + n[0] * 1.6, mid[1] + n[1] * 1.6), n, "Santo Domingo's arcade"))
        elif family == "arcade":
            t = 4.5

            while t < w["length"] - 2.0:
                out.append(Site("arcade", out_at(t, 1.6), n, "under the Portales"))
                t += 9.0

        if family in ("house", "palace", "town_hall", "pawnshop", "iturbide", "deco_tower", "inquisition") \
                and w["length"] > 5.0:
            t = 6.0

            while t < w["length"] - 3.0:
                out.append(Site("frontage", out_at(t, 1.8), n, "before a %s's front" % family.replace("_", " ")))
                t += 12.0

    # The plaza's edge (8 m in from its kerb, the kiosks' walk left clear) and corners.
    x0, z0, x1, z1 = zones.plaza
    edges = [((x0 + 8, z0 + 8), (x1 - 8, z0 + 8), (0.0, 1.0)), ((x0 + 8, z1 - 8), (x1 - 8, z1 - 8), (0.0, -1.0)),
             ((x0 + 8, z0 + 8), (x0 + 8, z1 - 8), (1.0, 0.0)), ((x1 - 8, z0 + 8), (x1 - 8, z1 - 8), (-1.0, 0.0))]

    for a, b, inward in edges:
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        u = _unit((b[0] - a[0], b[1] - a[1]))
        t = 14.0

        while t < length - 14.0:
            out.append(Site("plaza_edge", (a[0] + u[0] * t, a[1] + u[1] * t), inward, "the plaza's edge, its walk"))
            t += 12.0

    for sx in (-1, 1):
        for sz in (-1, 1):
            out.append(Site("plaza_corner", (sx * 92.0, sz * 80.0), (-sx, 0.0), "a corner of the plaza"))

    # The garden's central walks (the cross between its quarters, 32 m wide):
    # both its sides, every 12 m, facing the walk's middle.
    for t in range(-80, 81, 12):
        if abs(t) < 18:
            continue

        for s in (-1, 1):
            out.append(Site("plaza_walk", (float(t), s * 11.0), (0.0, -s), "the garden's central walk"))
            out.append(Site("plaza_walk", (s * 11.0, float(t)), (-s, 0.0), "the garden's central walk"))

    for lm in data["landmarks"]:
        if lm["kind"] == "metro_entrance":
            sx = 1.0 if lm["at"][0] > 0 else -1.0
            out.append(Site("metro_mouth", (lm["at"][0] - sx * 12.0, lm["at"][1]), (-sx, 0.0), "the Metro's mouth"))

    for p in d.pieces:
        yaw = math.radians(p["yaw"])
        f = (math.sin(yaw), math.cos(yaw))
        at = (p["at"][0], p["at"][2])

        if p["piece"] == "tram_stop":
            w = dress.world(p, (3.6, 0.0, 0.8))
            out.append(Site("tram_stop", (w[0], w[2]), f, "the tram stop"))
        elif p["piece"] == "idol_surfacing":
            out.append(Site("subsidence", at, (0.0, 1.0), "where the ground sank and a god's head came up"))
        elif p["piece"] == "hatch_sealed":
            out.append(Site("sealed_hatch", at, (0.0, 1.0), "a sealed hatch over the old corridors"))
        elif p["piece"] == "claw_scored_slab":
            out.append(Site("claw_slab", at, (0.0, 1.0), "claw-scored stone under a dead lamp"))

    # The market lanes, both edges, every 6 m.
    for g in data["ground"]:
        if g["kind"] != "market":
            continue

        bx0, bz0, bx1, bz1 = plan_check._bounds(g["polygon"])
        along_x = (bx1 - bx0) >= (bz1 - bz0)
        length = (bx1 - bx0) if along_x else (bz1 - bz0)
        t = 4.0

        while t < length - 4.0:
            for side in (0, 1):
                if along_x:
                    at, face = (bx0 + t, bz0 + 2.4 if side == 0 else bz1 - 2.4), (0.0, 1.0 if side == 0 else -1.0)
                else:
                    at, face = (bx0 + 2.4 if side == 0 else bx1 - 2.4, bz0 + t), (1.0 if side == 0 else -1.0, 0.0)

                out.append(Site("market", at, face, "a market lane"))

            t += 6.0

    for g in d.landings:
        bx0, bz0, bx1, bz1 = plan_check._bounds(g["polygon"])
        out.append(Site("landing", (bx0 - 5.0, (bz0 + bz1) / 2 - 0.5), (0.0, -1.0), "the canal landing, where boats come in",
                        key=g["name"]))

    # The side streets: their mouths, and the narrow ones to string washing across.
    for g in data["ground"]:
        if g["kind"] != "street" or g["name"] in MAIN or g["name"].startswith(("quay", "dig")):
            continue

        bx0, bz0, bx1, bz1 = plan_check._bounds(g["polygon"])
        along_x = (bx1 - bx0) >= (bz1 - bz0)
        width = (bz1 - bz0) if along_x else (bx1 - bx0)
        length = (bx1 - bx0) if along_x else (bz1 - bz0)

        if length > 20.0:
            for end, out_way in ((5.0, -1.0), (length - 5.0, 1.0)):
                at = (bx0 + end, (bz0 + bz1) / 2) if along_x else ((bx0 + bx1) / 2, bz0 + end)
                out.append(Site("street_mouth", at, (out_way, 0.0) if along_x else (0.0, out_way),
                                "where %s meets the street" % g["name"].replace("_", " ")))

        # (The line is 8 m, stretched to the street's width: twice at most.)
        if 5.0 <= width <= 16.0:
            t = 12.0

            while t < length - 12.0:
                at = (bx0 + t, bz0) if along_x else (bx0, bz0 + t)
                out.append(Site("street_span", at, (0.0, 1.0) if along_x else (1.0, 0.0), "a narrow street, wall to wall",
                                span=width))
                t += 25.0

    # Corners: every plot corner on open ground, a few metres out.
    for p in data["plots"]:
        pts = p["polygon"]
        cx = sum(q[0] for q in pts) / len(pts)
        cz = sum(q[1] for q in pts) / len(pts)

        for v in pts:
            b = _unit((v[0] - cx, v[1] - cz))
            at = (v[0] + b[0] * 2.5, v[1] + b[1] * 2.5)

            if life.open(*at):
                out.append(Site("corner", at, b, "a street corner"))

    # Dark spots: open ground further than DARK from every lit lamp.
    lights = [(lt["at"][0], lt["at"][2]) for lt in d.lights]
    bx0, bz0, bx1, bz1 = plan_check._bounds(data["brink"])
    x = bx0 + 5.0

    while x < bx1:
        z = bz0 + 5.0

        while z < bz1:
            if life.open(x, z) and all(math.hypot(x - a, z - b) > dress_life.DARK for a, b in lights):
                out.append(Site("dark_spot", (x, z), (0.0, 1.0), "where the Company let the lamps go dark"))

            z += 10.0

        x += 10.0

    # The rails: along the tram loop, 4.2 m either side of the track.
    loop = [tuple(q) for q in data["tram"]]

    for a, b in zip(loop, loop[1:] + loop[:1]):
        u = _unit((b[0] - a[0], b[1] - a[1]))
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        n = (u[1], -u[0])
        t = 15.0

        while t < length - 15.0:
            for s in (-1.0, 1.0):
                at = (a[0] + u[0] * t + n[0] * 4.2 * s, a[1] + u[1] * t + n[1] * 4.2 * s)

                # (Facing away from the track: the onlookers stand off the rails.)
                if life.open(*at):
                    out.append(Site("rails", at, (n[0] * s, n[1] * s), "beside the tram rails"))

            t += 20.0

    for s in out:
        s.zone = zones.of(*s.at)

    return out


def clearance(spot, x, z):
    """How far (x, z) is outside a keep-clear spot: a point's circle, or a
    way's band either side of its line ("a", "b")."""
    if "a" in spot:
        (ax, az), (bx, bz) = spot["a"], spot["b"]
        length2 = (bx - ax) ** 2 + (bz - az) ** 2 or 1.0
        t = max(0.0, min(1.0, ((x - ax) * (bx - ax) + (z - az) * (bz - az)) / length2))
        d = math.hypot(x - (ax + t * (bx - ax)), z - (az + t * (bz - az)))
    else:
        d = math.hypot(x - spot["at"][0], z - spot["at"][1])

    return d - spot["radius"] - 0.6


def keep_clear(data, dressing):
    """Where no scene may stand: a ladder's or a stair's foot, a bridge's
    ends, a door's front, a dropped kerb ({"at", "radius", "what"}), and
    the causeway, the plaza's processional way ({"a", "b", "radius", "what"})."""
    out = []
    way = data.get("causeway", [])

    # (It ends at the god, where the devotees kneel: clear only to 12 m from it.)
    for a, b in zip(way, way[1:]):
        a, b = list(a), list(b)

        for end, other in ((a, b), (b, a)):
            if math.hypot(*end) < 12.0 <= math.hypot(*other):
                u = _unit((end[0] - other[0], end[1] - other[1]))
                t = 0.0

                while math.hypot(other[0] + u[0] * t, other[1] + u[1] * t) > 12.0:
                    t += 0.5

                end[0], end[1] = other[0] + u[0] * t, other[1] + u[1] * t

        out.append({"a": tuple(a), "b": tuple(b), "radius": 6.0, "what": "the causeway"})

    for r in data["routes"]:
        if r["kind"] in ("climb", "stair", "bridge"):
            for q in (r["points"][0], r["points"][-1]):
                if abs(q[1]) < 0.5:
                    out.append({"at": (q[0], q[2]), "radius": 2.0 if r["kind"] == "bridge" else 1.2, "what": r["name"]})

    for lm in data["landmarks"]:
        if lm["kind"] == "door":
            out.append({"at": tuple(lm["at"]), "radius": 1.6, "what": lm["name"]})

    for p in dressing["pieces"]:
        if p["piece"] == "kerb_drop":
            c = dress.world(p, (1.5, 0.0, -0.5))
            out.append({"at": (c[0], c[2]), "radius": 2.2, "what": "a dropped kerb"})

    return out


# Staging

class Stage:
    def __init__(self, d, life):
        self.d = d
        self.life = life
        self.clear = keep_clear(d.data, {"pieces": d.pieces})
        self.placed = []          # (x, z, name, zone)

    def _frame(self, site):
        f = _unit(site.facing)
        right = (f[1], -f[0])
        yaw = dress_life.facing(f)
        world = lambda x, z: (site.at[0] + right[0] * x + f[0] * z, site.at[1] + right[1] * x + f[1] * z)
        return world, yaw

    def _blocked(self, x, z, reach):
        if any(clearance(c, x, z) < reach for c in self.clear):
            return True

        r = math.hypot(x, z)
        return GOD_WALK[0] - reach < r < GOD_WALK[1] + reach

    def stage(self, r, site):
        """Lays recipe `r` at `site` if every part of it fits; the scene's index or None."""
        world, yaw0 = self._frame(site)
        level = self.life.level(*site.at)
        when = r.when
        parts = []

        for part in list(r.pieces) + list(r.figures):
            name, (lx, lz), turn = part[0], part[1], part[2]
            lift = part[4] if part in r.figures and len(part) > 4 else (part[3] if part in r.pieces and len(part) > 3 else 0.0)
            x, z = world(lx, lz)
            yaw = yaw0 + turn

            if name in OVERHEAD:
                stretch = site.span / 8.0 if site.span else 1.0
                p = dress.place(name, (x, self.life.level(x, z), z), yaw, stretch)
            else:
                p = self.life.fits(name, x, z, yaw, y=self.life.level(x, z) + lift, ground=lift == 0.0, when=when)

                if p is None:
                    return None

                f = dress_life.foot(p, self.life.faces)
                reach = math.hypot(f[2] - f[0], f[3] - f[1]) / 2

                if self._collides(name) and self._blocked(x, z, reach):
                    return None

            parts.append((part, p))

        index = len(self.d.scenes)
        figures = []

        for part, p in parts:
            p["scene"] = index

            if p["piece"] in OVERHEAD:
                if when in ("day", "night"):
                    p["when"] = when

                self.d.add(p)
            else:
                self.life.commit(p, when)

                if self._collides(p["piece"]) and p["piece"] not in dress_life.COLLIDE:
                    self.life.collide(p)

                    if when in ("day", "night"):
                        self.d.boxes[-1]["when"] = when

                if self.d.boxes and self.d.boxes[-1].get("scene") is None and self._collides(p["piece"]):
                    self.d.boxes[-1]["scene"] = index

            if p["kit"] == "figures_kit":
                figures.append(p)
                self.d.stations.append({"role": part[3], "pose": p["piece"], "at": p["at"], "yaw": p["yaw"],
                                        "scene": index, "when": when})

        for piece, k, hand, grip in r.holds:
            fig = figures[k]
            hx, hy, hz = _hands()[fig["piece"]][hand]
            at = dress.world(fig, (hx, hy - grip, hz))
            held = dress.place(piece, at, fig["yaw"])
            held["scene"] = index
            held["held"] = True

            if when in ("day", "night"):
                held["when"] = when

            self.d.add(held)

        for effect, (ex, ey, ez) in r.emitters:
            x, z = world(ex, ez)
            e = {"effect": effect, "at": [round(x, 3), round(level + ey, 3), round(z, 3)], "scene": index}

            if when in ("day", "night"):
                e["when"] = when

            self.d.emitters.append(e)

        for texture, (dx, dz), size in r.decals:
            x, z = world(dx, dz)
            self.d.decals.append({"texture": texture, "at": [round(x, 3), round(level, 3), round(z, 3)], "size": size,
                                  "yaw": yaw0, "scene": index, **({"when": when} if when in ("day", "night") else {})})

        self.d.scenes.append({"name": r.name, "site": site.kind, "reason": site.reason, "zone": site.zone,
                              "at": [round(site.at[0], 3), round(level, 3), round(site.at[1], 3)], "yaw": round(yaw0, 2),
                              "when": when, "story": r.story})
        self.placed.append((site.at[0], site.at[1], r.name, site.zone))
        return index

    def _collides(self, piece):
        return piece.startswith(STANDS) or (piece not in NO_COLLIDER and piece not in OVERHEAD)

    def room(self, r, site):
        """Whether `site` keeps its zone's spacing from every scene laid, and
        `r` its own spacing from its own kind."""
        need = DENSITY.get(site.zone)

        if need is None:
            return False

        for x, z, name, zone in self.placed:
            d = math.hypot(site.at[0] - x, site.at[1] - z)

            if name == r.name and d < r.spacing:
                return False

            if zone == site.zone and d < need:
                return False

            if d < APART:
                return False

        return True


def _landmark(key, all_sites, zones):
    hall = zones.hall

    def nearest(kind, to, skip=()):
        pool = [s for s in all_sites if s.kind == kind and s not in skip]
        return sorted(pool, key=lambda s: math.hypot(s.at[0] - to[0], s.at[1] - to[1]))

    if key == "god_ring":
        return nearest("god_ring", (0.0, 0.0))
    if key == "hall_door":
        return nearest("hall_door", (0.0, 0.0))
    if key == "evangelistas":
        return nearest("evangelistas", (-170.0, -250.0))
    if key == "market":
        return nearest("market", hall)
    if key == "market_flowers":
        return nearest("market", (hall[0], hall[1] - 30.0))
    if key == "landing":
        return [s for s in all_sites if s.kind == "landing"]
    return []


def scenes(d, life, seed=SEED):
    """The landmarks at their places, then the zones filled to their density."""
    stage = Stage(d, life)
    all_sites = sites(d, life)
    zones = Zones(d)
    rng = random.Random(seed)
    by_base = {}

    for r in catalogue.RECIPES:
        if r.variant_of:
            by_base.setdefault(r.variant_of, []).append(r)

    def with_variants(r, site):
        index = stage.stage(r, site)

        if index is not None:
            for v in by_base.get(r.name, []):
                stage.stage(v, site)

        return index

    for r in [r for r in catalogue.RECIPES if r.landmark and not r.variant_of]:
        for site in _landmark(r.landmark, all_sites, zones):
            if stage.room(r, site) or r.landmark == "god_ring":
                if with_variants(r, site) is not None:
                    break

    fill = [r for r in catalogue.RECIPES if not r.landmark and not r.variant_of]
    counts = {r.name: 0 for r in fill}
    order = list(all_sites)
    rng.shuffle(order)
    order.sort(key=lambda s: (ORDER.index(s.zone) if s.zone in ORDER else len(ORDER), s.kind in COMMON))

    for site in order:
        if DENSITY.get(site.zone) is None:
            continue

        options = [r for r in fill if site.kind in r.sites and (r.zones is None or site.zone in r.zones)]
        rng.shuffle(options)
        # The least laid first, and of those the most particular (fewest kinds of place).
        options.sort(key=lambda r: (counts[r.name], len(r.sites)))

        for r in options:
            if stage.room(r, site) and with_variants(r, site) is not None:
                counts[r.name] += 1
                break


# The garden, the street's trees, the pigeons, the canal's fog, the lamps' dust

def garden(d, life):
    """The plaza's four quarters round the god as the Porfirian garden: beds
    of earth (three by three a quarter, 4 m walks between), hooped edging,
    trees in them (palms lining the central walks, ash), benches facing the
    walks; laurels at the market hall's doors, willows on the canal's quays,
    young ash in guards along the wide side streets, the split ahuehuete by
    the dig; three flocks on the plaza; fog on the canal at night, dust in
    one lit lamp's light in four."""
    level = d.level
    trees = 0

    for sx in (-1, 1):
        for sz in (-1, 1):
            xs = sorted((sx * 16.0, sx * 86.0))
            zs = sorted((sz * 16.0, sz * 96.0))
            w = (xs[1] - xs[0] - 8.0) / 3.0
            h = (zs[1] - zs[0] - 8.0) / 3.0

            for i in range(3):
                for j in range(3):
                    bed = (xs[0] + i * (w + 4.0), zs[0] + j * (h + 4.0), xs[0] + i * (w + 4.0) + w, zs[0] + j * (h + 4.0) + h)
                    margin = (bed[0] - 1.0, bed[1] - 1.0, bed[2] + 1.0, bed[3] + 1.0)

                    if not (life._clear(life.cells, margin) and life._clear(life.flush, margin)):
                        continue

                    if not all(life.open(x, z) for x in (bed[0], bed[2]) for z in (bed[1], bed[3])):
                        continue

                    d.beds.append(tuple(round(v, 3) for v in bed))
                    trees += _bed(d, life, bed, (sx, sz), i, j, level)

    _edging(d, life, level)
    trees += _street_trees(d, life)
    d.flocks += [{"at": [8.0, level, -36.0], "count": 14, "radius": 2.5}, {"at": [-40.0, level, 8.0], "count": 12, "radius": 2.2},
                 {"at": [46.0, level, -6.0], "count": 10, "radius": 2.0}]

    cx0, cz0, cx1, cz1 = plan_check._bounds(d.canal["polygon"])
    x = cx0 + 20.0

    while x < cx1:
        d.emitters.append({"effect": "canal_fog", "at": [round(x, 3), D.WATER + 0.3, (cz0 + cz1) / 2], "when": "night"})
        x += 40.0

    for k, lt in enumerate(d.lights):
        if k % 4 == 0:
            d.emitters.append({"effect": "dust", "at": [lt["at"][0], lt["at"][1] - 3.5, lt["at"][2]], "when": "night"})

    return trees


def _bed(d, life, bed, quarter, i, j, level):
    """A bed's trees: three, staggered; the corner nearest the god a palm (they
    line the central walks), the rest ash; a bench on its side to a central
    walk; a few trees drop their leaves."""
    x0, z0, x1, z1 = bed
    spots = [(x0 + (x1 - x0) * 0.3, z0 + (z1 - z0) * 0.3), (x0 + (x1 - x0) * 0.7, z0 + (z1 - z0) * 0.45),
             (x0 + (x1 - x0) * 0.4, z0 + (z1 - z0) * 0.75)]
    near = min(spots, key=lambda s: math.hypot(*s))
    count = 0

    for k, (x, z) in enumerate(spots):
        piece = "palm_canary" if (x, z) == near and (i == 0 or j == 0) else "tree_ash"
        yaw = (k * 97 + i * 31 + j * 53) % 360

        if life.put(piece, x, z, yaw):
            count += 1

            if (k + i + j) % 5 == 0 and piece == "tree_ash":
                d.emitters.append({"effect": "leaves", "at": [round(x, 3), level + 6.5, round(z, 3)], "floor": level})

    # Clipped shrubs round its edge, flowers through it (staggered), where
    # the trees leave room.
    for (ax, az), (bx, bz) in (((x0, z0), (x1, z0)), ((x1, z0), (x1, z1)), ((x1, z1), (x0, z1)), ((x0, z1), (x0, z0))):
        u = _unit((bx - ax, bz - az))
        inward = (-u[1], u[0])
        length = math.hypot(bx - ax, bz - az)
        t = 1.5

        while t < length - 1.0:
            life.put("garden_shrub", ax + u[0] * t + inward[0] * 0.9, az + u[1] * t + inward[1] * 0.9, (t * 41) % 360)
            t += 3.5

    row = 0
    z = z0 + 3.0

    while z < z1 - 2.5:
        x = x0 + 3.0 + (2.0 if row % 2 else 0.0)

        while x < x1 - 2.5:
            life.put("flower_clump", x, z, (x * 17 + z * 7) % 360)
            x += 4.0

        z += 3.5
        row += 1

    # A bench by the bed's side on a central walk, facing the walk.
    sx, sz = quarter

    if i == 0:
        x = x0 - 1.2 if sx > 0 else x1 + 1.2
        life.put("garden_bench", x, (z0 + z1) / 2, dress_life.facing((-sx * -1.0, 0.0)) if sx < 0 else dress_life.facing((-1.0, 0.0)))

    if j == 0:
        z = z0 - 1.2 if sz > 0 else z1 + 1.2
        life.put("garden_bench", (x0 + x1) / 2, z, dress_life.facing((0.0, -1.0)) if sz > 0 else dress_life.facing((0.0, 1.0)))

    return count


def _edging(d, life, level):
    """Hooped iron edging round every bed, 4 m to a piece (the 2 m piece
    stretched twice its length)."""
    for x0, z0, x1, z1 in d.beds:
        for a, b in (((x0, z0), (x1, z0)), ((x1, z0), (x1, z1)), ((x1, z1), (x0, z1)), ((x0, z1), (x0, z0))):
            u = _unit((b[0] - a[0], b[1] - a[1]))
            length = math.hypot(b[0] - a[0], b[1] - a[1])
            yaw = math.degrees(math.atan2(-u[1], u[0]))
            t = 0.0

            while t < length - 0.5:
                step = min(4.0, length - t)
                d.add(dress.place("garden_edging", (a[0] + u[0] * t, level, a[1] + u[1] * t), yaw, step / 2.0))
                t += step


def _street_trees(d, life):
    data = d.data
    count = 0

    # Laurels shading the market hall's doors, two a door.
    for w in life.walls:
        if w["plot"]["name"] != "market_hall" or w["length"] < 12.0:
            continue

        u = ((w["b"][0] - w["a"][0]) / w["length"], (w["b"][1] - w["a"][1]) / w["length"])
        mid = ((w["a"][0] + w["b"][0]) / 2, (w["a"][1] + w["b"][1]) / 2)

        for s in (-1, 1):
            x, z = mid[0] + u[0] * 9.0 * s + w["n"][0] * 7.0, mid[1] + u[1] * 9.0 * s + w["n"][1] * 7.0

            if life.put("tree_laurel", x, z, 37.0 * s):
                count += 1

    # Willows on the quays, leaning over the water, every 40 m.
    cx0, cz0, cx1, cz1 = plan_check._bounds(d.canal["polygon"])

    for z, lean, offset in ((cz0 - D.COPING_BACK - 1.6, -90.0, 0.0), (cz1 + D.COPING_BACK + 1.6, 90.0, 20.0)):
        x = cx0 + 15.0 + offset

        while x < cx1 - 10.0:
            if life.put("tree_willow", x, z, lean):
                count += 1

                if count % 4 == 0:
                    d.emitters.append({"effect": "leaves", "at": [round(x, 3), 5.0, round(z, 3)], "floor": 0.0})

            x += 40.0

    # Young ash in iron guards along the wide side streets.
    planted = 0

    for g in data["ground"]:
        if g["kind"] != "street" or g["name"] in MAIN or g["name"].startswith(("quay", "dig")):
            continue

        bx0, bz0, bx1, bz1 = plan_check._bounds(g["polygon"])
        along_x = (bx1 - bx0) >= (bz1 - bz0)
        width = (bz1 - bz0) if along_x else (bx1 - bx0)
        length = (bx1 - bx0) if along_x else (bz1 - bz0)

        if width < 12.0:
            continue

        t = 15.0

        while t < length - 10.0 and planted < 20:
            x, z = (bx0 + t, bz0 + 2.6) if along_x else (bx0 + 2.6, bz0 + t)

            if life.put("tree_ash_young", x, z, (t * 13) % 360):
                d.add(dress.place("tree_guard", (x, life.level(x, z), z), 0.0))
                count += 1
                planted += 1

            t += 30.0

    # The ahuehuete by the dig's north-west pit, where the ground sank.
    digs = [plan_check._bounds(g["polygon"]) for g in data["ground"] if g["kind"] == "dig"]

    if digs:
        bx0, bz0, bx1, bz1 = min(digs, key=lambda b: b[0] + b[1])

        for dx, dz in ((-5.0, -5.0), (-5.0, 3.0), (3.0, -5.0), (-7.0, -1.0), (-1.0, -7.0)):
            if life.put("ahuehuete_split", bx0 + dx, bz0 + dz, 20.0):
                count += 1
                break

    return count
