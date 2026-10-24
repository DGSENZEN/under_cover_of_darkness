"""What hangs in the librarian's shop (docs/superpowers/plans/2026-10-19-librarian-shop-part-2.md, dressing), each
from the trades already in the room:

- drying_line: the book-mender's line across the back-right corner, from a cup hook on the hunting case to one on the
  metaphysics case, freshly sewn signatures pegged over it to dry (their pages blank: what is on them is the user's);
- herb_rail: a peg rail on the back wall over the quarantine cage, rue, rosemary and dried marigold hung from it in
  bundles (the exorcist's: rue is kept against the evil eye);
- milagros: a red ribbon tied across the cage's bars, tin milagros hung from it (a heart, an eye, a leg, a hand), left
  as petitions by whoever brought him the books inside;
- censer: his brass thurible, hung by its chains from the coat stand's back hook, behind his coat;
- armillary: a brass armillary sphere on a chain from the vault over the chronology case (the shop turns it, slowly,
  with no draught; its middle is its wick).

The frame: the shop's (tools/eclipse/library_room.py): x across, y into the shop from its front wall, z up; Godot's x,
-z, y. The bay places it at the shop's origin.

    Blender -b --factory-startup --python tools/eclipse/library_hangings.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from library_corner import _chain, _link  # noqa: E402
from mathutils import Vector  # noqa: E402
from underground_shapes import box, pipe, smooth_object, turned  # noqa: E402

NAME = "library_hangings"
ATLAS = 1024
SLOTS = ["wood", "brass", "steel", "paper", "cloth", "herb", "herb_dry", "marigold", "leather_red", "tin"]
# (The censer's three chains of links are most of its.)
BUDGET = {"drying_line": 3000, "herb_rail": 3000, "milagros": 3000, "censer": 4000, "armillary": 3000}
# Small hung things are millimetres thick by nature: a face is a sliver under 4 mm.
SLIVER = 0.004

rng = random.Random(1926)

# The drying line: its cup hooks (on the hunting case's front, on the metaphysics case's), how far it sags, how many
# signatures hang on it and their size (across, down).
LINE = ((1.95, 5.5, 2.52), (3.5, 5.0, 2.52))
SAG = 0.1
PAGES = 5
PAGE = (0.18, 0.24)
# The rail over the cage: its ends (x), height, the wall's face (y); what hangs from each peg.
RAIL = (-2.3, -1.4, 2.35, 6.0)
BUNDLES = [(-2.15, "herb_dry"), (-1.85, "herb"), (-1.55, "marigold")]
# The ribbon on the cage: its ends (x), height, how far before the bars (y), how far it sags.
RIBBON = (-2.177, -1.526, 1.45, 5.54, 0.07)
CHARMS = ["heart", "eye", "leg", "hand", "heart", "hand", "eye", "leg", "heart"]
# The coat stand's back hook the censer hangs from (the corner's coat_hook at (1.18, 0.42) in its frame, set at y 4.4).
CENSER_HOOK = (1.18 + 0.15 * math.cos(math.radians(45)), 4.4 + 0.42 + 0.15 * math.sin(math.radians(45)), 1.8)
# The armillary: its middle, its rings' radius, where its chain meets the vault.
ARMILLARY = (-2.9, 1.0, 3.12)
ARMILLARY_R = 0.17
VAULT_AT = 3.72


def _sagging(a, b, sag, n=16):
    a, b = Vector(a), Vector(b)
    return [a.lerp(b, k / n) - Vector((0, 0, sag * 4 * (k / n) * (1 - k / n))) for k in range(n + 1)]


def _plate(m, outline, centre, thick, slot):
    """A flat plate facing the room (-y): `outline` [(across, up)] about `centre`, `thick` deep."""
    c = Vector(centre)
    front = [c + Vector((u, -thick / 2, v)) for u, v in outline]
    back = [c + Vector((u, thick / 2, v)) for u, v in outline]
    m.shell()
    m.face(front, slot)
    m.face(back[::-1], slot)
    n = len(outline)
    for k in range(n):
        m.face([front[(k + 1) % n], front[k], back[k], back[(k + 1) % n]], slot)


def drying_line(m):
    """The book-mender's line: cup hooks, the cord, signatures pegged over it."""
    points = _sagging(LINE[0], LINE[1], SAG)
    pipe(m, points, 0.006, 6, "cloth")
    for end, into in ((LINE[0], Vector((0, 0.04, 0))), (LINE[1], Vector((0.04, 0, 0)))):
        e = Vector(end)
        pipe(m, [e + into, e + Vector((0, 0, -0.012))], 0.006, 6, "brass")
    along = (Vector(LINE[1]) - Vector(LINE[0])).normalized()
    for k in range(PAGES):
        t = (k + 1) / (PAGES + 1)
        top = points[0].lerp(points[-1], t) - Vector((0, 0, SAG * 4 * t * (1 - t) + 0.006))
        w, h = PAGE
        lean = rng.uniform(-0.04, 0.04)
        side = along.cross(Vector((0, 0, 1))).normalized()
        corners = [top - along * w / 2, top + along * w / 2,
                   top + along * w / 2 - Vector((0, 0, h)) + side * lean, top - along * w / 2 - Vector((0, 0, h)) + side * lean]
        # (A signature folded over the cord: one solid, its leaves a fold's thickness either side of the cord; two
        # leaves apart would lay their faces too near each other.)
        front = [c - side * 0.006 for c in corners]
        back = [c + side * 0.006 for c in corners]
        m.shell()
        m.face(front, "paper")
        m.face(back[::-1], "paper")
        for i in range(4):
            m.face([front[(i + 1) % 4], front[i], back[i], back[(i + 1) % 4]], "paper")
        # Its peg, astride the cord.
        box(m, tuple(top - along * 0.007 - side * 0.012 - Vector((0, 0, 0.03))),
            tuple(top + along * 0.007 + side * 0.012 + Vector((0, 0, 0.018))), "wood", r=0.0)


def herb_rail(m):
    """The rail on the back wall, its pegs, a bundle tied and hung head down from each."""
    x0, x1, z, wall = RAIL
    box(m, (x0, wall - 0.03, z - 0.035), (x1, wall, z + 0.035), "wood", r=0.0)
    for x, slot in BUNDLES:
        turned(m, [(0.012, 0.0), (0.012, 0.08), (0.016, 0.09)], 8, "wood", at=(x, wall - 0.03, z),
               lean=math.pi / 2, towards=math.pi)
        # (Its twine from the peg, the bundle hung head down, tied at its stems.)
        pipe(m, [(x, wall - 0.1, z + 0.005), (x, wall - 0.1, z - 0.06)], 0.005, 6, "cloth")
        top = z - 0.06
        length = rng.uniform(0.26, 0.32)
        turned(m, [(0.022, -0.01), (0.026, -0.035), (0.05, -0.12), (0.068, -0.2), (0.06, -length + 0.03), (0.035, -length)],
               9, slot, at=(x, wall - 0.1, top), jitter=0.22, twist=rng.uniform(0, 1))
        turned(m, [(0.027, -0.015), (0.027, -0.03)], 9, "cloth", at=(x, wall - 0.1, top))


def _charm(kind):
    """A milagro's outline (m: across, up; hung from its top)."""
    if kind == "heart":
        pts = []
        # (Ten points on its curve: more crowd its cleft into faces thinner than the tin.)
        for k in range(10):
            t = 2 * math.pi * k / 10
            x = 16 * math.sin(t) ** 3
            y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
            pts.append((x * 0.0013, y * 0.0013 - 0.02))
        return pts[::-1]
    if kind == "eye":
        return [(-0.022, -0.02), (-0.011, -0.012), (0.011, -0.012), (0.022, -0.02), (0.011, -0.028), (-0.011, -0.028)]
    if kind == "leg":
        return [(-0.008, 0.0), (0.008, 0.0), (0.006, -0.04), (0.018, -0.046), (0.018, -0.052), (-0.008, -0.052)]
    return [(-0.012, 0.0), (0.012, 0.0), (0.012, -0.03), (0.02, -0.024), (0.022, -0.03), (0.012, -0.045), (-0.012, -0.045)]


def milagros(m):
    """The ribbon tied across the cage's bars, its knots, the milagros hung from it on threads."""
    x0, x1, z, y, sag = RIBBON
    points = _sagging((x0, y, z), (x1, y, z), sag, n=12)
    for a, b in zip(points, points[1:]):
        box(m, (min(a.x, b.x) - 0.002, y - 0.0025, min(a.z, b.z) - 0.0125), (max(a.x, b.x) + 0.002, y + 0.0025, max(a.z, b.z) + 0.0125),
            "leather_red", r=0.0)
    for end in (points[0], points[-1]):
        turned(m, [(0.014, -0.012), (0.016, 0.0), (0.014, 0.012)], 8, "leather_red", at=tuple(end + Vector((0, -0.004, 0))),
               lean=math.pi / 2, towards=math.pi)
    for k, kind in enumerate(CHARMS):
        t = (k + 1) / (len(CHARMS) + 1)
        at = points[0].lerp(points[-1], t) - Vector((0, 0, sag * 4 * t * (1 - t) + 0.0125))
        drop = rng.uniform(0.02, 0.05)
        box(m, (at.x - 0.0025, y - 0.0025, at.z - drop), (at.x + 0.0025, y + 0.0025, at.z), "cloth", r=0.0)
        _plate(m, _charm(kind), (at.x, y - 0.005, at.z - drop), 0.005, "tin")


def censer(m):
    """His thurible on the coat stand's back hook: its ring, three chains, the pierced lid's dome, the bowl, its foot."""
    hook = Vector(CENSER_HOOK)
    ring = hook - Vector((0, 0, 0.02))
    _link(m, tuple(ring), (1, 0, 0), (0, 0, 1), 0.02, 0.0065, "brass", steps=10)
    rim = ring - Vector((0, 0, 0.36))
    for k in range(3):
        a = 2 * math.pi * k / 3
        end = rim + Vector((0.05 * math.cos(a), 0.05 * math.sin(a), 0.0))
        _chain(m, [ring - Vector((0, 0, 0.02)), end], 0.014, 0.0055, 0.036, "brass")
    turned(m, [(0.018, 0.13), (0.03, 0.115), (0.05, 0.08), (0.062, 0.035), (0.064, 0.0)], 12, "brass", at=tuple(rim))
    turned(m, [(0.064, 0.0), (0.062, -0.035), (0.05, -0.06), (0.03, -0.068), (0.03, -0.085), (0.045, -0.095),
               (0.045, -0.105)], 16, "brass", at=tuple(rim))
    # (Where its smoke would rise: the lid's top.)
    m.wick(tuple(rim + Vector((0, 0, 0.13))))


def armillary(m):
    """The armillary sphere: its meridian, equator and ecliptic rings, the axis through the poles, the earth at its
    middle; the chain up to the vault."""
    c = Vector(ARMILLARY)
    r = ARMILLARY_R
    _link(m, tuple(c), (1, 0, 0), (0, 0, 1), r, 0.008, "brass", steps=40, sides=6)
    _link(m, tuple(c), (1, 0, 0), (0, 1, 0), r * 0.97, 0.008, "brass", steps=40, sides=6)
    tilt = math.radians(23.4)
    _link(m, tuple(c), (1, 0, 0), (0, math.cos(tilt), math.sin(tilt)), r * 0.94, 0.008, "brass", steps=40, sides=6)
    pipe(m, [c - Vector((0, 0, r + 0.03)), c + Vector((0, 0, r + 0.03))], 0.006, 6, "steel")
    m.shell()
    m.sphere(tuple(c), 0.035, 6, 10, "brass")
    _chain(m, [c + Vector((0, 0, r + 0.03)), Vector((c.x, c.y, VAULT_AT))], 0.014, 0.0055, 0.036, "steel")
    m.wick(tuple(c))


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1926)
    for f in (drying_line, herb_rail, milagros, censer, armillary):
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=SLIVER)


if __name__ == "__main__":
    main()
