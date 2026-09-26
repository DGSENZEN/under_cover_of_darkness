"""What each kind of NPC wears: pure data, no Blender (build.py reads it).

Heights and lengths are measured off the skeleton, not written in metres,
so a recipe carries over to another body: a place is (bone, fraction along
it from head to tail), e.g. ("thigh_l", 0.5) is halfway down the left thigh.
Colours are the fabric's own colour before any light (sRGB, 0..1), taken
from the old painted outfits (tools/dress_characters.py) so the kinds keep
the colours they had.

Garment types (build.py):
  shell    body regions copied and pushed out by `thickness` (+ `pads`)
  mittens  a mitten and thumb lofted along the finger bones
  boots    the feet and lower calves, with a turned-down cuff
  collar   a standing collar on a shell's neck edge
  skirt    panels hanging from the belt, flaring to `hem`
  tabard   painted onto `over` above the belt, panels below it to `hem`
  belt     a band round the waist, with a buckle
  prop     a pouch, a key ring, a scabbard: rigid on one bone
"""

# The fabrics a garment can be made of (the bake paints each its own way).
FABRICS = ["skin", "quilted_linen", "wool", "leather", "mail", "iron"]

TAN = (0.36, 0.29, 0.20)
MUSTARD = (0.62, 0.52, 0.16)
BLACK = (0.08, 0.08, 0.08)
HOSE_BROWN = (0.20, 0.19, 0.18)
BOOT_BROWN = (0.24, 0.15, 0.09)
GLOVE_BROWN = (0.20, 0.13, 0.08)
BELT_BROWN = (0.20, 0.12, 0.07)
SCABBARD_BLACK = (0.10, 0.08, 0.07)
IRON = (0.34, 0.34, 0.36)

WATCHMAN = {
    "kind": "watchman",
    "body": "male",
    # The body, headless, is cut to this many triangles before anything is
    # made from it (shells share its low-poly shape).
    "base_tris": 1300,
    # Where his skin may show (common.REGIONS): anywhere else is a hole.
    "bare": ["head"],
    "belt": ("spine_01", 0.0),
    "garments": [
        {"name": "gambeson", "type": "shell", "fabric": "quilted_linen", "colour": TAN,
         "regions": ["torso", "pelvis", "upper", "lower"],
         # Up to his neck (the regions stop there): a height would cut the
         # tops of his shoulders away, and his big trapezius rises above
         # where his neck starts.
         "bottom": ("thigh_l", 0.1), "sleeve_end": ("hand_l", 0.0), "sleeve_back": 0.016,
         "thickness": 0.03, "smooth": 10, "lips": ["sleeve", "bottom"],
         # Padding: fuller over the chest and the belly (front only).
         "pads": [{"from": ("spine_02", 0.6), "to": ("spine_03", 0.9), "front": True, "amount": 0.015},
                  {"from": ("spine_01", 0.0), "to": ("spine_02", 0.6), "front": True, "amount": 0.01}]},
        {"name": "hose", "type": "shell", "fabric": "wool", "colour": HOSE_BROWN,
         "regions": ["pelvis", "thigh", "calf"],
         "bottom": ("calf_l", 0.6), "top": ("spine_01", 0.0),
         "thickness": 0.006, "smooth": 2},
        {"name": "boots", "type": "boots", "fabric": "leather", "colour": BOOT_BROWN,
         "top": ("calf_l", 0.5), "thickness": 0.012, "sole": 0.004, "cuff": 0.05, "smooth": 3},
        {"name": "mittens", "type": "mittens", "fabric": "leather", "colour": GLOVE_BROWN,
         "cuff_into_sleeve": 0.045},
        {"name": "skirt", "type": "skirt", "fabric": "quilted_linen", "colour": TAN,
         "hem": ("thigh_l", 0.5), "flare": 1.35, "clearance": 0.03,
         # Side panels (degrees round from his front); his tabard covers the
         # front and back, so nothing is made there that would never show.
         "panels": {"left": [40, 140], "right": [-140, -40]},
         "chains": {"left": "skirt_l", "right": "skirt_r"}},
        # Painted onto his gambeson above the belt, swelling 6 mm; as wide
        # as his waist allows (0.33 m there, with the gambeson), so front
        # and back part at his sides and join only over his shoulders.
        {"name": "tabard", "type": "tabard", "fabric": "wool", "colour": MUSTARD, "dye": True, "stripe": BLACK,
         "over": "gambeson", "proud": 0.006, "tuck": 0.015, "hem": ("calf_l", 0.0), "width": 0.30},
        {"name": "belt", "type": "belt", "fabric": "leather", "colour": BELT_BROWN,
         "height": 0.045, "buckle": {"fabric": "iron", "colour": IRON, "size": (0.055, 0.014, 0.05)}},
        {"name": "pouch", "type": "prop", "shape": "pouch", "fabric": "leather", "colour": BELT_BROWN,
         "at": -110, "size": (0.12, 0.05, 0.10), "bone": "pelvis"},
        {"name": "keyring", "type": "prop", "shape": "keyring", "fabric": "iron", "colour": IRON,
         "at": 35, "size": (0.05, 0.01, 0.05), "bone": "pelvis"},
        {"name": "scabbard", "type": "prop", "shape": "scabbard", "fabric": "leather", "colour": SCABBARD_BLACK,
         "at": 100, "length": 0.9, "back": 25, "size": (0.05, 0.026, 0.9), "fittings": {"fabric": "iron", "colour": IRON},
         "bone": "pelvis"},
    ],
    # Cloth: two bones a chain. Kept after the stager (Sept 25 2026): stiff
    # and heavily dragged, the panels hang like wool and settle in about a
    # second (K4-K6 pin the swing, the settling and the speeds).
    "chains": {
        "tabard_front": {"stiffness": 1.4, "drag": 0.7, "gravity": 1.0, "radius": 0.03},
        "tabard_back": {"stiffness": 1.4, "drag": 0.7, "gravity": 1.0, "radius": 0.03},
        "skirt_l": {"stiffness": 1.4, "drag": 0.7, "gravity": 1.0, "radius": 0.03},
        "skirt_r": {"stiffness": 1.4, "drag": 0.7, "gravity": 1.0, "radius": 0.03},
    },
    # What keeps the cloth out of him: capsules along these bones.
    "colliders": [
        {"bone": "thigh_l", "radius": 0.085}, {"bone": "thigh_r", "radius": 0.085},
        {"bone": "calf_l", "radius": 0.06}, {"bone": "calf_r", "radius": 0.06},
        {"bone": "spine_01", "radius": 0.15},
    ],
    "metal": [],
    "options": {
        "faces": ["weathered"], "tones": ["light", "dark"], "hair": [], "beards": [],
        "headgear": [["kettlehat", "coif"]],
        # A watch wears one livery: its hue moves a little, washing and dirt
        # (fade, grime) do the rest.
        "dye": {"colour": list(MUSTARD), "shift": 0.025, "fade": [0.0, 0.3]},
        # How dirty he is (the shader's grime): from lately washed to
        # never; below 0.25 the mud barely reads.
        "grime": [0.25, 1.0],
    },
}

KINDS = {"watchman": WATCHMAN}

# Skin tones: the Quaternius skin times these (linear light). Heads are baked
# in each; a kind's JSON carries them too, so his bare skin matches his face.
TONES = {"light": [1.0, 1.0, 1.0], "dark": [0.52, 0.4, 0.32]}

# Faces: the Quaternius head, reshaped by smooth pushes (the same on the
# detailed head the bake reads and on the low one it paints), cut to ~400
# triangles. Places are metres on his left (mirrored to his right); a push
# moves the surface `along_normal` (+ out) or by `move`, fading to nothing at
# `radius`. Positions: eyes (0.035, -0.066, 1.699), mouth (0, -0.085, 1.623).
HEADS = {
    "weathered": {
        "body": "male",
        "tris": 340,
        "shape": [
            # Hollow under the cheekbones.
            {"at": (0.047, -0.07, 1.648), "radius": 0.028, "along_normal": -0.005},
            # A heavier brow ridge, and the brows sitting lower.
            {"at": (0.032, -0.088, 1.722), "radius": 0.03, "move": (0.0, -0.004, -0.003)},
            # A longer, heavier jaw.
            {"at": (0.0, -0.09, 1.575), "radius": 0.04, "move": (0.0, -0.002, -0.004)},
        ],
        # The eyeballs, smaller: painted eyes that read less wide.
        "eyes": 0.85,
        "grit": {"stubble": 0.6, "bags": 0.5, "lines": 0.5, "scar": "left_cheek"},
        # His brows' colour (the Quaternius brows are pale grey strands).
        "brows": (0.16, 0.11, 0.08),
        "tones": TONES,
    },
}

MAIL = (0.36, 0.36, 0.38)
# His hat's iron: the buckle's, a shade darker (a big plate reads lighter).
IRON_HAT = (0.25, 0.25, 0.27)
LEATHER = (0.20, 0.13, 0.08)

# What goes on heads. Every piece is skinned (the hat wholly to his Head),
# so the game binds them all one way and no bone frames are matched by hand.
HEADGEAR = {
    # A mail hood over his head, open from brow to chin, with a short cape
    # over the neck and shoulders.
    # Built as an even grid (build.coif): cut down from his head's own shape
    # it spent its triangles on the face it then lost, and his skull showed
    # through the few big faces left on the crown.
    "coif": {"type": "coif", "fabric": "mail", "colour": MAIL, "thickness": 0.015, "slack": 0.004,
             "segments": 12, "rings": [-40, -12, 20, 48, 75], "open": 36,
             "opening": {"x": 0.07, "from_z": 1.585, "to_z": 1.738},
             "cape": {"top_z": 1.575, "clear": 0.075, "tilt_front": 62, "tilt_side": 45,
                      "length_front": 0.17, "length_side": 0.17},
             # Every head it goes over at least this far under it (check.py).
             "covers_head": True, "inside": 0.006,
             # Above this (his ears) the hood rides his Head alone (K15).
             "rigid_above": 1.68,
             "metal": ["neck_01", "Head"], "hides_hair": True, "allows_beard": True},
    # A kettle hat forged over the coif (build.kettle): a round bowl (a
    # ridge read as a peak from the front: a coolie hat), a leather band at
    # its foot (just above his brows and the coif's opening), a curved brim
    # 7 cm wide turning down to a lip. Built here, not the old armour GLB (the user's look review,
    # Sept 26: the hat must belong with the outfit). check.py holds it at
    # least `clearance` and at most `rest` (its ridge included) off the coif
    # over his crown; the build adds `slack` for its flat faces' sag
    # between the points it measured.
    "kettlehat": {"type": "kettle", "bone": "Head", "over": "coif", "clearance": 0.006, "slack": 0.009, "rest": 0.032,
                  "base_z": 1.748, "centre_y": 0.02, "drop": 0.05, "segments": 16, "elevations": [15, 38, 60, 80],
                  "comb": 0.0, "brim": 0.07, "droop": 0.036, "lip": 0.012, "rivets": 12,
                  "fabric": "iron", "colour": IRON_HAT, "band": ("leather", LEATHER),
                  "metal": ["Head"], "hides_hair": False, "allows_beard": True},
}


# Hair and beards (build_hair): solid shells cut down from the Quaternius
# styles, fitted over the heads they go on. Filled by batch 1's Task 5.
HAIR = {}
