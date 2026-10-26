"""The candle lane's landmarks (docs/superpowers/specs/2026-10-24-lane-landmarks-design.md; plan
docs/superpowers/plans/2026-10-25-lane-landmarks.md): what makes the curandera's stall and the librarian's shop read from
the Pasaje.
- garland: her cempasúchil garland strung across the lane from a riser lashed to her stall's east front post to an iron
  hook-plate on the south wall, sagging, papel picado flags hung under it (cut abstract, no letters). She strings it
  each season for the dead she prays for. Over the walk (lane z 0.2-2.6) nothing of it hangs under 2.6 m.
Built where they stand in the lane (x along it, y the lane's -z, z up: Godot's x, -z, y) and set at the lane's origin.
    Blender -b --factory-startup --python tools/eclipse/lane_landmarks.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from mathutils import Vector  # noqa: E402
from underground_shapes import box, pipe, smooth_object  # noqa: E402

NAME = "lane_landmarks"
ATLAS = 2048
SLOTS = ["marigold", "herb", "picado", "picado_b", "iron"]
# (The garland is a rope of heads ~15 cm thick, three round the cord at each step, so it reads from the Pasaje.)
BUDGET = {"garland": 6000}
# Cords, flags and lashings are millimetres across by nature: a face there is a sliver under 4 mm.
SLIVER = {name: 0.004 for name in BUDGET}

rng = random.Random(2410)

# The lane (maps/candle_lane.gd): its south wall's tile face (lane z).
FAR_WALL = 4.55
# Her stall (tools/eclipse/stall.py): its east front post (lane x), its front rail's height.
POST_X = 1.5
FRONT_H = 2.35
# The garland (lane x, z, height): the riser's top (where it ties on), the hook on the south wall, how far it sags, its heads' size and
# spacing, its flags (across, tall) and how many.
TIE = (POST_X + 0.07, -0.04, 3.32)
HOOK = (1.95, FAR_WALL - 0.1, 3.42)
SAG = 0.28
HEAD_R = 0.055
HEAD_EVERY = 0.075
HEADS_ROUND = 3
FLAG = (0.24, 0.28)
FLAGS = 7


def _lane(x, z, y):
    """A point given in the lane's (x along, z across, y up), in Blender's axes."""
    return Vector((x, -z, y))


def _rope(a, b, sag, n=24):
    """Points along a cord from `a` to `b` (Blender), sagging `sag` at its middle."""
    return [a.lerp(b, k / n) - Vector((0, 0, sag * 4 * (k / n) * (1 - k / n))) for k in range(n + 1)]


def garland(m):
    """Her cempasúchil garland across the lane, from her riser to the south wall's hook, its flags under it."""
    tie = _lane(*TIE)
    hook = _lane(*HOOK)
    # The riser: an iron rod lashed to her post above the rail, its top bent into an eye.
    foot = _lane(TIE[0], TIE[1], FRONT_H - 0.12)
    pipe(m, [foot, tie + Vector((0, 0, 0.04))], 0.016, 6, "iron")
    for h in (FRONT_H - 0.05, FRONT_H + 0.25):
        m.shell()
        ring = [_lane(TIE[0] - 0.035 + 0.05 * math.cos(a), TIE[1] + 0.05 * math.sin(a), h)
                for a in (2 * math.pi * k / 6 for k in range(6))]
        pipe(m, ring, 0.009, 4, "herb", closed=True)
    # The hook-plate on the wall, its ring.
    box(m, _lane(HOOK[0] - 0.07, FAR_WALL - 0.018, HOOK[2] - 0.09), _lane(HOOK[0] + 0.07, FAR_WALL, HOOK[2] + 0.09),
        "iron", r=0.006)
    pipe(m, [_lane(HOOK[0], FAR_WALL - 0.018, HOOK[2]), hook], 0.01, 6, "iron")
    # The cord and its heads, crowded along it.
    cord = _rope(tie, hook, SAG)
    pipe(m, cord, 0.008, 4, "herb")
    length = sum((cord[k + 1] - cord[k]).length for k in range(len(cord) - 1))
    heads = int(length / HEAD_EVERY)
    for k in range(1, heads):
        t = k / heads
        on = tie.lerp(hook, t) - Vector((0, 0, SAG * 4 * t * (1 - t)))
        across = (hook - tie).normalized().cross(Vector((0, 0, 1))).normalized()
        # (Three round the cord, turned a little at each step: a rope of heads, not a string of beads.)
        for j in range(HEADS_ROUND):
            a = 2 * math.pi * j / HEADS_ROUND + k * 0.9
            at = on + across * math.cos(a) * HEAD_R * 0.75 + Vector((0, 0, math.sin(a) * HEAD_R * 0.75 - HEAD_R * 0.3))
            at += Vector((rng.uniform(-0.01, 0.01), rng.uniform(-0.01, 0.01), rng.uniform(-0.01, 0.01)))
            m.shell()
            m.sphere(tuple(at), HEAD_R * rng.uniform(0.85, 1.1), 3, 6, "marigold")
    # The flags, hung from the cord between the heads, each a little turned in the draught.
    along = (hook - tie).normalized()
    side = along.cross(Vector((0, 0, 1))).normalized()
    w, h = FLAG
    for k in range(1, FLAGS + 1):
        t = (k - 0.5) / FLAGS
        top = tie.lerp(hook, t) - Vector((0, 0, SAG * 4 * t * (1 - t) + HEAD_R * 1.4))
        turn = side * rng.uniform(-0.03, 0.03)
        corners = [top - along * w / 2, top + along * w / 2, top + along * w / 2 - Vector((0, 0, h)) + turn,
                   top - along * w / 2 - Vector((0, 0, h)) + turn]
        front = [c - side * 0.006 for c in corners]
        back = [c + side * 0.006 for c in corners]
        slot = "picado" if k % 2 else "picado_b"
        m.shell()
        m.face(front, slot)
        m.face(back[::-1], slot)
        for i in range(4):
            m.face([front[(i + 1) % 4], front[i], back[i], back[(i + 1) % 4]], slot)


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(2410)
    for f in (garland,):
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()))


if __name__ == "__main__":
    main()
