"""The Light Company's cable runs in the Zócalo station (docs/superpowers/specs/2026-10-31-station-machinery-design.md;
plan docs/superpowers/plans/2026-10-31-station-machinery.md, Task 4): bundles of chunky brass cable from the engine's crown
junction to what it powers (the turnstile banks' blade signs, the taquillas' crests, the platforms' Company lamps),
three cables side by side sagging between iron hangers from the ceiling, a glazed insulator bell round each (the user
dropped the tesla arcs, Oct 31: cables and pipework carry the Company's power).

Each run is a piece of its own in the set's frame (placed at the origin, no turn). Its anchors are given in Godot's
axes (x, y up, z); the kit builds in Blender's (x, -z, y), so the glTF lands where the set wants it. Its sampled path
(path()) goes to station_runs.json for the arcs and the checks.

    Blender -b --factory-startup --python tools/eclipse/station_runs.py
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
from underground_shapes import pipe, smooth_object, turned  # noqa: E402

NAME = "station_runs"
ATLAS = 4096
SLOTS = ["brass", "iron", "talavera_glaze"]
JSON = common.ROOT / "assets" / "eclipse" / "kit" / "station_runs.json"

# The engine's crown junction every run leaves from (the set's frame; the engine stands at the hall's middle), under the
# ceiling's mains (station_pipes): the hall's runs hang at its height, passing under them.
ENGINE_TERMINAL = (0.0, 9.45, 0.0)
# The cable's radius; a hanger every this far at most along a level span; a span's sag (share of its length, at most);
# how the cable rounds a corner (m).
CABLE_R = 0.032
# The bundle (the user, Oct 31: "add more cables"): each cable's offset across the run (m, level, square to it) and its
# sag against the bundle's middle, so the three hang a little apart between hangers.
BUNDLE = (-0.095, 0.0, 0.095)
BUNDLE_SAG = (1.2, 1.0, 0.85)
HANG_EVERY = 3.6
SAG = (0.035, 0.3)
CORNER = 0.15
# The ceilings the hangers reach (the set's frame): the hall's, the stairwells', the platforms'.
HALL, STAIRS, PLATFORM = 11.0, 11.0, 5.5

# Each run: what it powers, its anchors (x, y, z, the ceiling its hanger reaches or None).
RUNS = {
    "bank_west": {"to": "blade_company", "anchors": [
        (0.0, 9.45, 0.0, None), (-7.0, 9.45, 1.9, HALL), (-13.2, 9.45, 3.72, HALL), (-14.0, 10.08, 3.72, None)]},
    "bank_east": {"to": "blade_company", "anchors": [
        (0.0, 9.45, 0.0, None), (7.0, 9.45, -1.9, HALL), (13.2, 9.45, -3.72, HALL), (14.0, 10.08, -3.72, None)]},
    "taquilla_east": {"to": "taquilla_east", "anchors": [
        (0.0, 9.45, 0.0, None), (9.0, 9.45, -5.0, HALL), (17.0, 9.45, -10.0, HALL), (20.0, 9.45, -11.95, HALL),
        (20.0, 9.65, -11.95, None)]},
    "taquilla_west": {"to": "taquilla_west", "anchors": [
        (0.0, 9.45, 0.0, None), (-9.0, 9.45, 5.0, HALL), (-17.0, 9.45, 10.0, HALL), (-20.0, 9.45, 11.95, HALL),
        (-20.0, 9.65, 11.95, None)]},
}


def _platform_run(s):
    """The north run (s = 1) or its mirror (s = -1): over the hall, down under the stair head's sign, through the
    hall's door to the stairwell, high along it, down its corner and through the platform's door at its east jamb (clear
    of the sign hung inside it), up the platform's back wall and along it over the signs, down to the Company lamp at its
    far end."""
    def m(x, y, z, c):
        return (x * s, y, z * s, c)
    return [m(0.0, 9.45, 0.0, None), m(-5.2, 9.45, -9.0, HALL), m(-5.2, 8.6, -12.0, None), m(-5.2, 8.6, -14.6, None),
            m(-5.2, 10.6, -15.6, STAIRS), m(-5.2, 10.6, -27.0, STAIRS), m(-0.7, 10.6, -27.0, STAIRS),
            m(-0.7, 10.6, -14.4, STAIRS), m(-0.7, 2.7, -14.4, None), m(-0.7, 2.7, -13.4, None),
            m(-0.7, 5.25, -13.4, None), m(-0.7, 5.25, -10.5, PLATFORM), m(-31.0, 5.25, -10.5, PLATFORM),
            m(-32.0, 5.25, -13.5, None), m(-32.0, 3.9, -13.62, None)]


RUNS["platform_n"] = {"to": "ward_bracket", "anchors": _platform_run(1)}
RUNS["platform_s"] = {"to": "ward_bracket", "anchors": _platform_run(-1)}


def _sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def _len(v):
    return math.sqrt(sum(x * x for x in v))


def _lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def hangers(name):
    """The run's hanger points (x, y, z, ceiling): its anchors with a ceiling, and more along a long level span."""
    anchors = RUNS[name]["anchors"]
    out = []
    for k, a in enumerate(anchors):
        if a[3] is not None:
            out.append(a)
        if k + 1 < len(anchors):
            b = anchors[k + 1]
            span = _len(_sub(b[:3], a[:3]))
            if a[3] is not None and b[3] is not None and abs(a[1] - b[1]) < 0.05 and span > HANG_EVERY:
                n = int(math.ceil(span / HANG_EVERY))
                for j in range(1, n):
                    p = _lerp(a[:3], b[:3], j / n)
                    out.append((*p, a[3]))
    return out


def path(name, sag_scale=1.0):
    """The run's cable, sampled: sagging between hangers on level spans, straight elsewhere, rounded at its corners
    (the bundle's middle; `sag_scale` deepens or eases its sag)."""
    anchors = RUNS[name]["anchors"]
    # (The points the cable is held at, in order: anchors and the extra hangers between.)
    held = []
    for k, a in enumerate(anchors):
        held.append(a)
        if k + 1 < len(anchors):
            b = anchors[k + 1]
            span = _len(_sub(b[:3], a[:3]))
            if a[3] is not None and b[3] is not None and abs(a[1] - b[1]) < 0.05 and span > HANG_EVERY:
                n = int(math.ceil(span / HANG_EVERY))
                held += [(*_lerp(a[:3], b[:3], j / n), a[3]) for j in range(1, n)]
    out = []
    for k in range(len(held) - 1):
        a, b = held[k][:3], held[k + 1][:3]
        span = _len(_sub(b, a))
        level = abs(a[1] - b[1]) < 0.05 and span > 1.0
        steps = max(2, int(span / 0.4)) if level else 1
        sag = min(SAG[1], SAG[0] * span) * sag_scale if level else 0.0
        for j in range(steps):
            t = j / steps
            p = _lerp(a, b, t)
            out.append((p[0], p[1] - sag * 4 * t * (1 - t), p[2]))
    out.append(held[-1][:3])
    return _rounded(out)


def _rounded(points):
    """Each sharp corner replaced by three points round it, so the tube never pinches."""
    out = [points[0]]
    for k in range(1, len(points) - 1):
        a, p, b = points[k - 1], points[k], points[k + 1]
        d1, d2 = _sub(p, a), _sub(b, p)
        l1, l2 = _len(d1), _len(d2)
        cos = sum(x * y for x, y in zip(d1, d2)) / max(l1 * l2, 1e-9)
        r = min(CORNER, l1 / 2, l2 / 2)
        if cos > 0.95 or r < 0.02:
            out.append(p)
            continue
        u1 = tuple(x / l1 for x in d1)
        u2 = tuple(x / l2 for x in d2)
        before = tuple(pi - ui * r for pi, ui in zip(p, u1))
        after = tuple(pi + ui * r for pi, ui in zip(p, u2))
        middle = tuple(pi + (v - w) * r * 0.3 for pi, v, w in zip(p, u2, u1))
        out += [before, middle, after]
    out.append(points[-1])
    return out


def _b(p):
    """Godot (x, y, z) to Blender (x, -z, y)."""
    return (p[0], -p[2], p[1])


def _across(points, k, last):
    """The level direction square to the run at its k-th point (the last one kept where the run drops straight)."""
    a, b = points[max(k - 1, 0)], points[min(k + 1, len(points) - 1)]
    dx, dz = b[0] - a[0], b[2] - a[2]
    n = math.hypot(dx, dz)
    return (-dz / n, 0.0, dx / n) if n > 1e-3 else last


def cables(name):
    """The bundle's cables: each its own sag, offset level across the run."""
    out = []
    for off, sag in zip(BUNDLE, BUNDLE_SAG):
        points = path(name, sag)
        n, cable = (1.0, 0.0, 0.0), []
        for k, p in enumerate(points):
            n = _across(points, k, n)
            cable.append((p[0] + n[0] * off, p[1], p[2] + n[2] * off))
        out.append(cable)
    return out


def _run(name):
    def build(m):
        for cable in cables(name):
            pipe(m, [_b(p) for p in cable], CABLE_R, 10, "brass")
        # (Its hangers: an iron rod up to the ceiling, a crossbar under the bundle, a glazed bell round each cable.)
        middle = path(name)
        for x, y, z, ceiling in hangers(name):
            at = [k for k, p in enumerate(middle) if abs(p[0] - x) < 0.01 and abs(p[2] - z) < 0.01]
            k = at[0] if at else min(range(len(middle)), key=lambda j: (middle[j][0] - x) ** 2 + (middle[j][2] - z) ** 2)
            hang = middle[k][1] if at else y
            n = _across(middle, k, (1.0, 0.0, 0.0))
            half = max(abs(o) for o in BUNDLE) + 0.05
            bar = hang + 0.075
            pipe(m, [_b((x - n[0] * half, bar, z - n[2] * half)), _b((x + n[0] * half, bar, z + n[2] * half))], 0.016,
                 6, "iron")
            pipe(m, [_b((x, bar, z)), _b((x, ceiling, z))], 0.014, 6, "iron")
            for off in BUNDLE:
                turned(m, [(0.03, -0.02), (0.055, 0.02), (0.045, 0.06), (0.02, 0.075)], 12, "talavera_glaze",
                       at=_b((x + n[0] * off, hang - 0.03, z + n[2] * off)))
    return build


PIECES = [("run_" + n, _run(n)) for n in RUNS]

BUDGET = {n: 26000 for n, _ in PIECES}
SLIVER = {n: 0.004 for n, _ in PIECES}


def write_json():
    JSON.write_text(json.dumps({n: {"to": RUNS[n]["to"], "cables": len(BUNDLE), "points": [list(p) for p in path(n)]}
                                for n in RUNS}, indent=1))


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
