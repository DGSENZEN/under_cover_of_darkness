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
SLOTS = ["brass", "iron", "pipe_red", "pipe_green", "sign", "glass", "rubber"]

# The plaster's face over the tiles (the set's frame: 14 less the wall and the mortar the plaster sheets stand on).
FACE = 14.0 - 0.3 - 0.032
# The pipes, top to bottom: (slot, radius, how far under the rack's height); all this far out from the wall's face.
PIPES = [("brass", 0.14, 0.0), ("pipe_red", 0.11, 0.34), ("pipe_green", 0.09, 0.6)]
OUT = 0.25
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


# The ceiling's mains (the user, Oct 31: "more, on the ceiling, bigger, the feel of a large machine"; then "more
# engrained"): wall to wall, held up on rods from the ceiling, flanged, each (its z; its radius; its middle's height in
# the set's frame; how far it reaches either way, into its end walls; its floor; how high its top may reach). The hall's
# under its coffers' beams (4.4 m over its floor), two with governor drums, two by the walls branching into every
# riser's top; one along each platform's ceiling.
END_FACE = 30.0 - 0.3 - 0.032
PLATFORM_END = 50.0 - 0.3 - 0.032
MAINS = {"main_n": (-5.5, 0.25, 10.1, END_FACE, 6.0, 10.4), "main_s": (5.5, 0.25, 10.1, END_FACE, 6.0, 10.4),
         "main_nw": (-10.5, 0.22, 10.1, END_FACE, 6.0, 10.4), "main_sw": (10.5, 0.22, 10.1, END_FACE, 6.0, 10.4),
         "main_pn": (-10.0, 0.18, 5.1, PLATFORM_END, 0.0, 5.45), "main_ps": (10.0, 0.18, 5.1, PLATFORM_END, 0.0, 5.45)}
GOVERNED = ("main_n", "main_s")
BRANCH_R = 0.12
MAIN_HANG = 4.8
GOVERNOR = (8.0, 0.42, 0.9)
# The floor's mains along the walls' feet, half sunk, the risers teeing up out of them (the user, Oct 31: "more
# engrained towards the terrain"): its radius, its middle over the floor (half of it sunk), where it dives under the
# floor (x ranges: doors, booths, the banks' railings) and how far it slopes to dive.
FLOOR_MAIN = (0.22, 0.02)
DIVE = (0.6, 0.55)
FLOOR_MAINS = {
    "floor_hall_n": (-1, -29.6, 29.6, 6.0, [(-7.9, -4.1), (-14.4, -13.6), (13.6, 14.4), (16.8, 23.2)]),
    "floor_hall_s": (1, -29.6, 29.6, 6.0, [(-11.9, -8.1), (4.1, 7.9), (-14.4, -13.6), (13.6, 14.4), (-22.3, -17.7)]),
    "floor_platform_n": (-1, -49.6, 49.6, 0.0, [(-3.9, -0.1)]),
    "floor_platform_s": (1, -49.6, 49.6, 0.0, [(0.1, 3.9)]),
}
# The cable trays under the coffers, from the engine's place to the hall's end walls (z; from x; to x), their foot and
# top, how many cables each carries, a cable's radius.
TRAYS = {"tray_e": (1.6, 3.2, END_FACE + 0.05), "tray_w": (-1.6, -END_FACE - 0.05, -3.2)}
TRAY_Y = (10.25, 10.38)
TRAY_CABLES = 6
TRAY_CABLE_R = 0.026
# The walls' risers: huge pipes from the floor into the ceiling, out from their wall (its middle this far from the
# plaster's face), each a collar at its foot, bands, a valve wheel and a gauge at hand's height, strapped to the wall:
# (the wall's side; x; the floor; the ceiling over it).
RISER = (0.3, 0.75)
HALL_RISERS = [(-1, x) for x in (-27.0, -20.0, -2.0, 12.0, 27.0)] + [(1, x) for x in (-27.0, -16.5, -3.0, 12.0, 20.0, 27.0)]
PLATFORM_RISERS = [(side, x) for side in (-1, 1) for x in (-47.0, -36.0, -12.0, 12.0, 36.0, 47.0)]
RISERS = {"riser_h%d" % k: (side, x, 6.0, 11.0) for k, (side, x) in enumerate(HALL_RISERS)}
RISERS.update({"riser_p%d" % k: (side, x, 0.0, 5.5) for k, (side, x) in enumerate(PLATFORM_RISERS)})
# A pipe mouth in the floor, venting the Company's fuel fumes: its body's radius and height, its bell's radius (m).
MOUTH = (0.45, 0.9, 0.62)


def _main(name):
    z, r, y, reach, floor, _ = MAINS[name]
    ceiling = 11.0 if floor > 3.0 else 5.5

    def build(m):
        pipe(m, [_b((-reach - 0.05, y, z)), _b((reach + 0.05, y, z))], r, 18, "iron")
        n = int(2 * reach // MAIN_HANG)
        for k in range(n + 1):
            x = -reach + 0.6 + (2 * reach - 1.2) * k / n
            turned(m, [(r + 0.05, -0.05), (r + 0.05, 0.05)], 18, "brass", at=_b((x, y, z)), lean=math.pi / 2,
                   towards=math.pi / 2)
            pipe(m, [_b((x + 0.2, y + r * 0.6, z)), _b((x + 0.2, ceiling, z))], 0.025, 8, "iron")
        if name in GOVERNED:
            # (Its governors: a drum swelling the main, a gauge on its face toward the hall's middle.)
            for gx in (-GOVERNOR[0], GOVERNOR[0]):
                turned(m, [(r + 0.03, -GOVERNOR[2] / 2 - 0.08), (GOVERNOR[1], -GOVERNOR[2] / 2),
                           (GOVERNOR[1], GOVERNOR[2] / 2), (r + 0.03, GOVERNOR[2] / 2 + 0.08)], 20, "brass",
                       at=_b((gx, y, z)), lean=math.pi / 2, towards=math.pi / 2)
                face = -math.copysign(1.0, z)
                turned(m, [(0.16, 0.0), (0.16, 0.06)], 20, "brass", at=_b((gx, y, z + face * (GOVERNOR[1] - 0.02))),
                       lean=math.pi / 2, towards=0.0 if face < 0 else math.pi)
                turned(m, [(0.12, 0.05), (0.12, 0.095)], 20, "sign", at=_b((gx, y, z + face * (GOVERNOR[1] - 0.02))),
                       lean=math.pi / 2, towards=0.0 if face < 0 else math.pi)
        if name in ("main_nw", "main_sw"):
            # (A branch from it into the top of each of its wall's risers, flanged at the main.)
            side = 1 if z > 0 else -1
            for k, (rs, rx) in enumerate(HALL_RISERS):
                if rs != side:
                    continue
                rz = side * (FACE - RISER[1])
                pipe(m, [_b((rx, y, z)), _b((rx, y, rz))], BRANCH_R, 12, "iron")
                turned(m, [(BRANCH_R + 0.045, -0.04), (BRANCH_R + 0.045, 0.04)], 12, "brass",
                       at=_b((rx, y, z + side * (r + 0.08))), lean=math.pi / 2, towards=0.0 if side > 0 else math.pi)
    return build


def _floor_main(name):
    side, x0, x1, floor, dives = FLOOR_MAINS[name]
    r, up = FLOOR_MAIN
    z = side * (FACE - RISER[1])
    top, deep = floor + up, floor - DIVE[1]

    def build(m):
        # (Along the wall's foot, half sunk; diving under the floor before each door, booth and railing and coming up
        # after it; its ends sunk too.)
        line = [(x0, deep, z)]
        for a, b in sorted(dives):
            line += [(a - DIVE[0], top, z), (a, deep, z), (b, deep, z), (b + DIVE[0], top, z)]
        line += [(x1, deep, z)]
        line = [line[0], (x0 + DIVE[0], top, z)] + line[1:-1] + [(x1 - DIVE[0], top, z), line[-1]]
        pipe(m, [_b(p) for p in _rounded(line)], r, 16, "iron")
        # (A flange every 4.8 m where it runs above the floor.)
        x = x0 + 2.4
        while x < x1 - 2.4:
            if all(not (a - DIVE[0] - 0.3 <= x <= b + DIVE[0] + 0.3) for a, b in dives):
                turned(m, [(r + 0.05, -0.05), (r + 0.05, 0.05)], 16, "brass", at=_b((x, top, z)), lean=math.pi / 2,
                       towards=math.pi / 2)
            x += 4.8
    return build


def _tray(name):
    z, x0, x1 = TRAYS[name]
    foot, top = TRAY_Y
    half = 0.2

    def build(m):
        # (An iron ladder: its two rails, its rungs, its cables lying in it, rods up to the ceiling.)
        for side in (-1, 1):
            _gbox(m, (x0, foot, z + side * half - 0.02), (x1, top, z + side * half + 0.02), "iron")
        x = x0 + 0.15
        while x < x1 - 0.1:
            _gbox(m, (x - 0.02, foot, z - half + 0.02), (x + 0.02, foot + 0.03, z + half - 0.02), "iron")
            x += 0.3
        for k in range(TRAY_CABLES):
            cz = z - half + 0.05 + (2 * half - 0.1) * k / (TRAY_CABLES - 1)
            cy = foot + 0.03 + TRAY_CABLE_R + (0.01 if k % 2 else 0.0)
            pipe(m, [_b((x0, cy, cz)), _b((x1, cy, cz))], TRAY_CABLE_R, 8, "rubber" if k % 3 else "brass")
        x = x0 + 1.2
        while x < x1 - 0.5:
            for side in (-1, 1):
                pipe(m, [_b((x, top - 0.01, z + side * half)), _b((x, 11.0, z + side * half))], 0.012, 6, "iron")
            x += 2.4
    return build


def _riser(height):
    """A riser, built once and placed at each of RISERS (the set turns it to its wall): its axis at the origin, standing
    on z = 0 (Godot's y), its wall behind it toward Godot's -z (out from the plaster's face), the room toward +z."""
    side, x, floor, ceiling = -1, 0.0, 0.0, height
    r, out = RISER
    z = 0.0
    face = out

    def build(m):
        # (Its foot inside its collar, never in the collar's plane.)
        pipe(m, [_b((x, floor + 0.04, z)), _b((x, ceiling, z))], r, 18, "iron")
        # (Its foot a tee on the floor's main under it: a collar over the main's back.)
        turned(m, [(r + 0.08, floor + 0.12), (r + 0.08, floor + 0.34), (r + 0.04, floor + 0.4)], 18, "brass",
               at=_b((x, 0.0, z)))
        k = 1
        while floor + 1.2 * k < ceiling - 0.4:
            y = floor + 1.2 * k
            turned(m, [(r + 0.035, y - 0.04), (r + 0.035, y + 0.04)], 18, "brass", at=_b((x, 0.0, z)))
            k += 1
        # (The valve wheel at hand's height, its stem out toward the room; the gauge over it.)
        toward = -side
        stem_from, stem_to = z + toward * (r - 0.05), z + toward * (r + 0.16)
        y = floor + 1.5
        pipe(m, [_b((x, y, stem_from)), _b((x, y, stem_to))], 0.03, 8, "iron")
        ring = [_b((x + 0.26 * math.cos(2 * math.pi * j / 20), y + 0.26 * math.sin(2 * math.pi * j / 20), stem_to))
                for j in range(20)]
        pipe(m, ring, 0.025, 8, "brass", closed=True)
        for j in range(4):
            a = math.pi * j / 2 + 0.4
            pipe(m, [_b((x, y, stem_to)), _b((x + 0.24 * math.cos(a), y + 0.24 * math.sin(a), stem_to))], 0.016, 6,
                 "brass")
        towards = 0.0 if toward < 0 else math.pi
        gauge_at = _b((x, floor + 2.05, z + toward * (r - 0.04)))
        turned(m, [(0.15, 0.0), (0.15, 0.08)], 20, "brass", at=gauge_at, lean=math.pi / 2, towards=towards)
        turned(m, [(0.115, 0.07), (0.115, 0.115)], 20, "sign", at=gauge_at, lean=math.pi / 2, towards=towards)
        # (Strapped to the wall over and under the racks' height.)
        for y in (floor + 2.8, ceiling - 0.35):
            a, b = sorted((side * face, z - side * (r - 0.05)))
            _gbox(m, (x - 0.06, y - 0.05, a), (x + 0.06, y + 0.05, b), "iron")
    return build


def mouth(m):
    """A pipe mouth come up through the floor: a bolted collar, an iron throat flaring to a bell, open (its throat
    dropping inside it), a brass lip round it, a grate down in the throat."""
    r, h, bell = MOUTH
    inner = bell - 0.06
    turned(m, [(r + 0.12, 0.0), (r + 0.12, 0.08), (r + 0.06, 0.12)], 20, "brass", at=(0.0, 0.0, 0.0))
    turned(m, [(r, 0.04), (r, h - 0.25), (bell, h - 0.05), (bell, h), (inner, h), (inner, h - 0.45)], 20, "iron",
           at=(0.0, 0.0, 0.0))
    lip = [(bell * math.cos(2 * math.pi * k / 24), bell * math.sin(2 * math.pi * k / 24), h) for k in range(24)]
    pipe(m, lip, 0.035, 8, "brass", closed=True)
    for k in range(-2, 3):
        x = k * inner * 0.32
        half = math.sqrt(max(inner ** 2 - x ** 2, 0.0))
        box(m, (x - 0.02, -half, h - 0.14), (x + 0.02, half, h - 0.1), "iron", r=0.0)
    for k in range(8):
        a = 2 * math.pi * k / 8
        turned(m, [(0.025, 0.08), (0.025, 0.11), (0.012, 0.125)], 6, "iron",
               at=(math.cos(a) * (r + 0.08), math.sin(a) * (r + 0.08), 0.0))


def feed(m):
    """A mouth's feed: half sunk across the floor from its wall's floor main (at y = 0 in the piece) to the mouth's
    throat (at y = -FEED_LENGTH), flanged at the main."""
    pipe(m, [(0.0, 0.0, FLOOR_MAIN[1]), (0.0, -FEED_LENGTH, FLOOR_MAIN[1])], 0.15, 14, "iron")
    turned(m, [(0.2, -0.04), (0.2, 0.04)], 14, "brass", at=(0.0, -FLOOR_MAIN[0] - 0.12, FLOOR_MAIN[1]),
           lean=math.pi / 2)


# A feed's length: from the floor main's middle to its mouth's middle (the mouths stand this far out from it).
FEED_LENGTH = 1.32

PIECES = [("rack_" + n, _rack(n)) for n in RACKS] + [(n, _main(n)) for n in MAINS] + \
    [("riser_hall", _riser(5.0)), ("riser_platform", _riser(5.5))]
# (The floor's mains, the trays, the mouths and their feeds paint on an atlas of their own: station_ducts.)
DUCT_PIECES = [(n, _floor_main(n)) for n in FLOOR_MAINS] + [(n, _tray(n)) for n in TRAYS] + \
    [("mouth", mouth), ("feed", feed)]

BUDGET = {n: 24000 for n, _ in PIECES}
# (The mouth's height over the floor where it breathes, for the Fumes the set stands in it.)
FUME_AT = MOUTH[1] + 0.05
SLIVER = {n: 0.004 for n, _ in PIECES}


JSON = common.ROOT / "assets" / "eclipse" / "kit" / "station_pipes.json"


def write_json():
    """Where each riser stands (the set's frame): its piece, x, its floor, its wall's side (-1 north, 1 south), and its
    axis's z."""
    import json
    JSON.write_text(json.dumps([{"piece": "riser_hall" if floor > 3.0 else "riser_platform", "x": x, "floor": floor,
                                 "side": side, "z": side * (FACE - RISER[1])}
                                for side, x, floor, ceiling in RISERS.values()], indent=1))


def build():
    common.reset()
    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    write_json()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()), pack_margin=0.0015)


if __name__ == "__main__":
    main()
