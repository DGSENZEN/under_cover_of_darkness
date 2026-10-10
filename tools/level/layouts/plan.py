"""A district's plan as data (the Zócalo spec,
docs/superpowers/specs/2026-10-10-zocalo-district-design.md, section 2):
before any kit piece exists, the map's ground areas, plots, routes,
underground spaces, landmarks, tram loop, event fields and brink, at true
scale. plan_check.py gates it, plan_draw.py draws its sheets, greybox.py
turns it into plain geometry.

Axes are the pipeline's (lay.py): x east, y up, z south, metres; north is
-z. Polygons are lists of (x, z), counter-clockwise in the (x, z) plane
(positive shoelace area), which is clockwise seen from above with north up.
"""

import math

GROUND_KINDS = ("plaza", "street", "atrium", "courtyard", "market", "canal", "landing", "dig", "well")
# Below the street: cut out of the ground as rectangles.
SUNKEN_KINDS = ("canal", "landing", "dig", "well")
# Above the street, a pavement up (the plaza: its kerbs 0.2 proud): cut out of
# the street as rectangles, standing on it.
RAISED_KINDS = ("plaza",)
# What a plot may face.
# (A tower may stand in a dig, facing it on every side.)
FRONTAGE_KINDS = ("plaza", "street", "atrium", "market", "canal", "landing", "courtyard", "dig")
ROUTE_KINDS = ("roof_link", "climb", "stair", "bridge", "tunnel")
EVENT_KINDS = ("subsidence", "water", "seepage", "use")


def rect(x0, z0, x1, z1):
    """An axis-aligned rectangle, its corners in this module's orientation."""
    x0, x1 = min(x0, x1), max(x0, x1)
    z0, z1 = min(z0, z1), max(z0, z1)
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


def signed_area(polygon):
    pts = [tuple(p) for p in polygon]
    return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1])) / 2.0


def area(polygon):
    return abs(signed_area(polygon))


def oriented(polygon):
    """The polygon in this module's orientation (positive shoelace area)."""
    pts = [(float(p[0]), float(p[1])) for p in polygon]
    return pts if signed_area(pts) >= 0 else list(reversed(pts))


def centroid(polygon):
    pts = [tuple(p) for p in polygon]
    a = signed_area(pts)

    if abs(a) < 1e-9:
        return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))

    cx = cz = 0.0

    for p, q in zip(pts, pts[1:] + pts[:1]):
        cross = p[0] * q[1] - q[0] * p[1]
        cx += (p[0] + q[0]) * cross
        cz += (p[1] + q[1]) * cross

    return (cx / (6 * a), cz / (6 * a))


def top(plot):
    """A plot's roof height."""
    return plot["base"] + plot["height"]


def _pts(polygon):
    return [[float(p[0]), float(p[1])] for p in oriented(polygon)]


class Plan:
    def __init__(self, name):
        self.name = name
        self.grounds, self.plots, self.routes, self.spaces = [], [], [], []
        self.landmarks, self.loop, self.events, self.edge = [], [], [], []
        self.band = []

    def ground(self, name, kind, polygon, level=0.0):
        if kind not in GROUND_KINDS:
            raise ValueError("no ground kind " + kind)

        self.grounds.append({"name": name, "kind": kind, "polygon": _pts(polygon), "level": float(level)})

    def plot(self, name, family, polygon, storeys, height, base=0.0, roof=True, interior=False):
        self.plots.append({"name": name, "family": family, "polygon": _pts(polygon), "storeys": int(storeys),
                           "height": float(height), "base": float(base), "roof": bool(roof), "interior": bool(interior)})

    def route(self, name, kind, points, between=None):
        """A route; a tunnel names the two spaces it joins in `between`."""
        if kind not in ROUTE_KINDS:
            raise ValueError("no route kind " + kind)

        if len(points) < 2:
            raise ValueError("a route needs two ends: " + name)

        entry = {"name": name, "kind": kind, "points": [[float(v) for v in p] for p in points]}

        if between is not None:
            entry["between"] = list(between)

        self.routes.append(entry)

    def space(self, name, polygon, floor, height, openings=(), interior=False):
        self.spaces.append({"name": name, "polygon": _pts(polygon), "floor": float(floor), "height": float(height),
                            "interior": bool(interior),
                            "openings": [{"to": o["to"], "at": [float(o["at"][0]), float(o["at"][1])],
                                          "width": float(o.get("width", 3.0))} for o in openings]})

    def landmark(self, name, kind, at, **props):
        self.landmarks.append({"name": name, "kind": kind, "at": [float(v) for v in at], "props": props})

    def tram(self, points):
        self.loop = [[float(p[0]), float(p[1])] for p in points]

    def causeway(self, points):
        """The old causeway's line under the colonial grid (x, z), which the
        street kit's band of darker stone follows."""
        self.band = [[float(p[0]), float(p[1])] for p in points]

    def event(self, kind, **shape):
        if kind not in EVENT_KINDS:
            raise ValueError("no event kind " + kind)

        entry = {"kind": kind, "strength": float(shape["strength"])}

        if "centre" in shape:
            entry.update(centre=[float(v) for v in shape["centre"]], radius=float(shape["radius"]))
        else:
            entry.update(line=[[float(v) for v in p] for p in shape["line"]], reach=float(shape["reach"]))

        self.events.append(entry)

    def brink(self, polygon):
        self.edge = _pts(polygon)

    def data(self):
        return {"name": self.name, "ground": self.grounds, "plots": self.plots, "routes": self.routes,
                "spaces": self.spaces, "landmarks": self.landmarks, "tram": self.loop, "causeway": self.band, "events": self.events,
                "brink": self.edge}


def _segment_distance(p, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    length = dx * dx + dz * dz
    t = 0.0 if length < 1e-12 else max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / length))
    return math.hypot(p[0] - (ax + t * dx), p[1] - (az + t * dz))


def _smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def field(data, kind, x, z):
    """How strongly an event shaped the place (x, z), 0-1: the strongest of
    that kind's shapes, each falling smoothly from its centre or line to
    nothing at its radius or reach."""
    best = 0.0

    for e in data["events"]:
        if e["kind"] != kind:
            continue

        if "centre" in e:
            d, reach = math.hypot(x - e["centre"][0], z - e["centre"][1]), e["radius"]
        else:
            line = e["line"]
            d = min(_segment_distance((x, z), a, b) for a, b in zip(line, line[1:]))
            reach = e["reach"]

        best = max(best, e["strength"] * _smooth(1.0 - d / reach))

    return min(1.0, best)
