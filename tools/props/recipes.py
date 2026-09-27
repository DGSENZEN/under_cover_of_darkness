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

# The stick leans 20 degrees out from the wall; along it (0, -sin 20, cos 20).
_LEAN = (0.0, -0.342, 0.940)

FIXTURES = {
    "wall_torch": {
        "family": "torches",
        "mount": "wall",
        "budget": 300,
        "soot": True,
        "cookie": False,
        "parts": [
            {"type": "box", "name": "plate", "slot": "iron", "size": (0.10, 0.02, 0.22), "at": (0.0, -0.01, 0.0)},
            {"type": "tube", "name": "arm", "slot": "iron", "radius": 0.009, "sides": 4,
             "points": [(0.0, -0.02, -0.03), (0.0, -0.12, 0.01), (0.0, -0.215, 0.11)]},
            {"type": "ring", "name": "cup", "slot": "iron", "radius": 0.045, "thickness": 0.012, "sides": 4, "segments": 8,
             "axis": "Z", "at": (0.0, -0.22, 0.12)},
            {"type": "lathe", "name": "stick", "slot": "bark", "segments": 6,
             "profile": [(0.0, 0.0), (0.016, 0.0), (0.019, 0.28), (0.022, 0.55), (0.0, 0.55)],
             "rotate": (20.0, 0.0, 0.0), "at": (0.0, -0.17, -0.02)},
            {"type": "blob", "name": "head", "slot": "pitch", "glow": True, "segments": 8, "noise": 0.005, "seed": 3,
             "profile": [(0.0, 0.0), (0.03, 0.0), (0.042, 0.04), (0.04, 0.09), (0.025, 0.12), (0.0, 0.13)],
             "rotate": (20.0, 0.0, 0.0), "at": (0.0, -0.341, 0.45)},
        ],
        "sockets": {
            "flame": [(0.0, -0.383, 0.565)],
            "corona": [(0.0, -0.383, 0.625)],
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
