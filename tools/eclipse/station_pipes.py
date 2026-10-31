"""The Light Company's pipe racks in the Zócalo station (the user, Oct 31 2026: "add more cables, piping around";
docs/superpowers/specs/2026-10-31-station-machinery-design.md): big pipes along the hall's long walls and the platforms'
back walls, high over the walks, on iron brackets, flanged, a valve wheel on each rack, each run elbowing out of the
wall at one end and back into it at the other (where it comes from and goes is left to interpretation).

Each rack is a piece of its own in the set's frame (placed at the origin, no turn), built in Blender's axes from Godot's
(x, y, z) as station_runs is. The platforms' racks break round their doors (the cable runs climb there) and stop short
of the Company lamps the runs feed at their ends.

    Blender -b --factory-startup --python tools/eclipse/station_pipes.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
from station_runs import _b, _rounded  # noqa: E402
from underground_shapes import box, pipe, smooth_object, turned  # noqa: E402

NAME = "station_pipes"
ATLAS = 4096
SLOTS = ["brass", "iron", "pipe_red", "pipe_green"]

# The plaster's face over the tiles (the set's frame: 14 less the wall and the mortar the plaster sheets stand on).
FACE = 14.0 - 0.3 - 0.032
# The pipes, top to bottom: (slot, radius, how far under the rack's height); all this far out from the wall's face.
PIPES = [("brass", 0.09, 0.0), ("pipe_red", 0.07, 0.25), ("pipe_green", 0.06, 0.45)]
OUT = 0.2
# A bracket every this far at most (m); a flange every second bracket; where a rack elbows into the wall (m in from its
# end).
BRACKET_EVERY = 2.4
ELBOW = 0.35
# The racks: (the wall's side, -1 north or 1 south; from x; to x; the floor; the top pipe's height over it).
RACKS = {
    "hall_n": (-1, -29.4, 29.4, 6.0, 4.15),
    "hall_s": (1, -29.4, 29.4, 6.0, 4.15),
    "platform_n_w": (-1, -28.0, -4.2, 0.0, 4.95),
    "platform_n_e": (-1, 0.2, 28.0, 0.0, 4.95),
    "platform_s_w": (1, -28.0, -0.2, 0.0, 4.95),
    "platform_s_e": (1, 4.2, 28.0, 0.0, 4.95),
}


def _rack(name):
    side, x0, x1, floor, height = RACKS[name]
    wall = side * FACE
    out = wall - side * OUT

    def build(m):
        top = floor + height
        for slot, r, under in PIPES:
            y = top - under
            # (Out of the wall, along it, back into the wall: its ends sunk 5 cm into the plaster, its elbows round.)
            line = [(x0, y, wall + side * 0.05), (x0, y, out), (x1, y, out), (x1, y, wall + side * 0.05)]
            pipe(m, [_b(p) for p in _rounded(line)], r, 14, slot)
        # (A bracket every BRACKET_EVERY: a plate on the wall, an arm out under each pipe.)
        span = x1 - x0 - 2 * ELBOW
        n = max(1, int(math.ceil(span / BRACKET_EVERY)))
        for k in range(n + 1):
            x = x0 + ELBOW + span * k / n
            lo = top - PIPES[-1][2] - PIPES[-1][1] - 0.08
            _gbox(m, (x - 0.05, lo, wall), (x + 0.05, top + 0.12, wall - side * 0.03), "iron")
            for slot, r, under in PIPES:
                y = top - under - r + 0.005
                # (From the plate's face, never alongside it: no faces of the two in one plane.)
                _gbox(m, (x - 0.03, y - 0.035, wall - side * 0.03), (x + 0.03, y, out - side * (r + 0.04)), "iron")
            # (A flange round each pipe at every second bracket.)
            if k % 2 == 0 and k < n:
                for slot, r, under in PIPES:
                    turned(m, [(r + 0.04, -0.03), (r + 0.04, 0.03)], 14, "iron",
                           at=_b((x + 0.3, top - under, out)), lean=math.pi / 2, towards=math.pi / 2)
        # (A valve wheel on the red pipe at the rack's middle, its stem out toward the room.)
        xm = (x0 + x1) / 2 + 0.6
        y = top - PIPES[1][2]
        stem = out - side * (PIPES[1][1] + 0.12)
        pipe(m, [_b((xm, y, out - side * PIPES[1][1] * 0.5)), _b((xm, y, stem))], 0.018, 8, "iron")
        ring = [_b((xm + 0.13 * math.cos(2 * math.pi * j / 16), y + 0.13 * math.sin(2 * math.pi * j / 16), stem))
                for j in range(16)]
        pipe(m, ring, 0.016, 8, "brass", closed=True)
        for j in range(3):
            a = 2 * math.pi * j / 3 + 0.3
            pipe(m, [_b((xm, y, stem)), _b((xm + 0.12 * math.cos(a), y + 0.12 * math.sin(a), stem))], 0.011, 6, "brass")
    return build


def _gbox(m, a, b, slot):
    """A box between two Godot corners, in Blender's axes (its corners re-sorted after the turn)."""
    p, q = _b(a), _b(b)
    box(m, tuple(min(u, v) for u, v in zip(p, q)), tuple(max(u, v) for u, v in zip(p, q)), slot, r=0.0)


PIECES = [("rack_" + n, _rack(n)) for n in RACKS]

BUDGET = {n: 24000 for n, _ in PIECES}
SLIVER = {n: 0.004 for n, _ in PIECES}


def build():
    common.reset()
    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()), pack_margin=0.0015)


if __name__ == "__main__":
    main()
