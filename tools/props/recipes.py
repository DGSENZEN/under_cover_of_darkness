"""The light fixtures, as data: what each is made of, its sockets, its light.

Plain data (any Python reads it: props.sh list needs no Blender). Blender
space, metres, Z up. A wall fixture's wall is the XZ plane at y = 0 and it
stands out toward -Y; in Godot that is +Z out of the wall.

Every part: "type" (see build.py: lathe, tube, box, ring, chain, stones,
logs, blob, panes, collider), "name", "slot" (a surface slot, SLOTS), and
optionally "glow" (it shines from inside when lit, chars when cold), "at"
(x, y, z), "rotate" (degrees about x, y, z, before `at`), "seed".

"sockets": name -> list of points: "flame" (every flame), "corona" (the
halo), "mount" (where it meets its wall or floor), "hang" (the top of what
it hangs by), "grip" (a hand's hold).

"burner": Torch.gd exports set on the fixture (color is a hex string, loop
a name in audio/ambience/, "" for none).

"shadow_parts": the parts that cast shadows (none by default: small parts
right under their own light would throw huge wedges of shadow, which PS2
fixtures never did; a hearth's masonry should).
"""

import copy

# Every surface slot a part may use (scripts/Visual/Materials.gd has their
# photos and flat colours); "<slot>_glow" is the same surface shining.
SLOTS = ["iron", "chain", "wood_old", "bark", "stone", "ashlar", "pitch", "brass", "clay", "wax", "horn", "char", "coal"]

# Flat colours (sRGB) for Blender's own previews, as Materials.gd has them.
SLOT_COLOURS = {
    "iron": "2A2826", "chain": "33302C", "wood_old": "4A3524", "bark": "3D2E22", "stone": "5E5A55",
    "ashlar": "6B665F", "pitch": "17110D", "brass": "8C6A35", "clay": "8A5236", "wax": "D9C9A3",
    "horn": "C8964B", "char": "1C1714", "coal": "2B1A12",
}

TORCH_BURNER = {
    "sheet": "torch", "ramp": "torch", "low_ramp": "dying", "flicker_kind": "torch", "flicker": 0.12,
    "energy": 2.4, "light_range": 9.0, "shadows": True, "color": "FF9829", "corona_px": 48.0,
    "ember_rate": 6.0, "smoke_rate": 3.0, "flame_size": 0.34, "flame_layers": 2, "core": True,
    "loop": "torch_loop", "loop_db": -13.0, "loop_reach": 11.0,
}

def _along(base, axis, distance):
    return tuple(round(b + a * distance, 4) for b, a in zip(base, axis))


def _round(point, radius, angle_deg):
    """A point on a flat circle of `radius` round `point` (about Z)."""
    import math
    a = math.radians(angle_deg)
    return (round(point[0] + radius * math.cos(a), 4), round(point[1] + radius * math.sin(a), 4), point[2])


# The wall torch: its stick leans 20 degrees out from the wall, through a
# basket cup on a bent bar from a riveted plate; a tow head flared at the
# top, bound with an iron band.
_LEAN = (0.0, -0.342, 0.940)
_STICK = (0.0, -0.17, -0.02)
_HEAD = _along(_STICK, _LEAN, 0.46)
_CUP = (0.0, -0.221, 0.12)
_CUP_LOW = (0.0, -0.199, 0.06)

FIXTURES = {
    "wall_torch": {
        "family": "torches",
        "mount": "wall",
        "budget": 300,
        "soot": True,
        "cookie": False,
        "parts": [
            {"type": "box", "name": "plate", "slot": "iron", "size": (0.09, 0.02, 0.2), "at": (0.0, -0.01, 0.0)},
            {"type": "lathe", "name": "rivet_top", "slot": "iron", "segments": 3, "profile": [(0.009, 0.0), (0.0, 0.007)],
             "rotate": (90.0, 0.0, 0.0), "at": (0.0, -0.02, 0.075)},
            {"type": "lathe", "name": "rivet_low", "slot": "iron", "segments": 3, "profile": [(0.009, 0.0), (0.0, 0.007)],
             "rotate": (90.0, 0.0, 0.0), "at": (0.0, -0.02, -0.075)},
            {"type": "tube", "name": "arm", "slot": "iron", "radius": 0.008, "sides": 4,
             "points": [(0.0, -0.02, -0.06), (0.0, -0.09, -0.04), (0.0, -0.15, 0.03), (0.0, -0.181, 0.105)]},
            {"type": "ring", "name": "cup", "slot": "iron", "radius": 0.04, "thickness": 0.011, "sides": 3, "segments": 8, "axis": "Z", "at": _CUP},
            {"type": "ring", "name": "cup_low", "slot": "iron", "radius": 0.026, "thickness": 0.009, "sides": 3, "segments": 6, "axis": "Z", "at": _CUP_LOW},
        ] + [
            {"type": "tube", "name": "strap_%d" % i, "slot": "iron", "radius": 0.004, "sides": 3,
             "points": [_round(_CUP_LOW, 0.026, a), _round(_CUP, 0.04, a)]}
            for i, a in enumerate((90.0, 210.0, 330.0))
        ] + [
            {"type": "lathe", "name": "stick", "slot": "bark", "segments": 5,
             "profile": [(0.0, 0.0), (0.019, 0.0), (0.021, 0.25), (0.024, 0.5), (0.0, 0.5)],
             "rotate": (20.0, 0.0, 0.0), "at": _STICK},
            {"type": "blob", "name": "head", "slot": "pitch", "glow": True, "segments": 7, "noise": 0.005, "seed": 3,
             "profile": [(0.0, 0.0), (0.026, 0.0), (0.034, 0.03), (0.046, 0.08), (0.044, 0.11), (0.03, 0.13), (0.0, 0.135)],
             "rotate": (20.0, 0.0, 0.0), "at": _HEAD},
            {"type": "ring", "name": "band", "slot": "iron", "radius": 0.037, "thickness": 0.01, "sides": 3, "segments": 7,
             "axis": "Z", "rotate": (20.0, 0.0, 0.0), "at": _along(_HEAD, _LEAN, 0.045)},
        ],
        "sockets": {
            "flame": [_along(_HEAD, _LEAN, 0.12)],
            "corona": [tuple(round(v, 4) for v in (_along(_HEAD, _LEAN, 0.12)[0], _along(_HEAD, _LEAN, 0.12)[1], _along(_HEAD, _LEAN, 0.12)[2] + 0.06))],
            "mount": [(0.0, 0.0, 0.0)],
        },
        "burner": dict(TORCH_BURNER),
    },
}

KINDS = list(FIXTURES)


def variant(base, **changes):
    """A copy of recipe `base` with `changes` laid over it."""
    recipe = copy.deepcopy(FIXTURES[base])
    recipe.update(copy.deepcopy(changes))
    return recipe
