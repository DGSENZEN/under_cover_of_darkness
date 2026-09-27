"""What each kind of NPC wears: pure data, no Blender (build.py reads it).

Heights and lengths are measured off the skeleton, not written in metres,
so a recipe carries over to another body: a place is (bone, fraction along
it from head to tail), e.g. ("thigh_l", 0.5) is halfway down the left thigh.
Colours are the fabric's own colour before any light (sRGB, 0..1), taken
from the old painted outfits (tools/dress_characters.py) so the kinds keep
the colours they had.

Garment types (build.py):
  shell     body regions copied and pushed out by `thickness` (+ `pads`)
  mittens   a mitten and thumb lofted along the finger bones (+ a `cuff`)
  boots     the feet and lower calves, with a turned-down `cuff` (0: none)
  collar    a standing collar on a shell's neck edge
  skirt     panels hanging from the belt, flaring to `hem` (front, back, sides)
  panels    front and back panels hanging from under the belt to `hem`
  tabard    painted onto `over` above the belt, panels below it to `hem`
  belt      a band round the waist, with a buckle
  sash      a cloth band round the waist, and tails hanging from its knot
  pauldron  a plate over the shoulder, on the upper arm
  bracer    a leather ring round one forearm
  prop      a pouch, a key ring, a scabbard, a quiver, a knife: on one bone
"""

# The fabrics a garment can be made of (the bake paints each its own way).
# Their indices are baked into the parts (wr_fabric): new ones go at the end.
FABRICS = ["skin", "quilted_linen", "wool", "leather", "mail", "iron", "wrapped", "hair", "fur"]

TAN = (0.36, 0.29, 0.20)
MUSTARD = (0.62, 0.52, 0.16)
BLACK = (0.08, 0.08, 0.08)
HOSE_BROWN = (0.20, 0.19, 0.18)
BOOT_BROWN = (0.24, 0.15, 0.09)
GLOVE_BROWN = (0.20, 0.13, 0.08)
BELT_BROWN = (0.20, 0.12, 0.07)
SCABBARD_BLACK = (0.10, 0.08, 0.07)
IRON = (0.34, 0.34, 0.36)
MAIL = (0.36, 0.36, 0.38)
# The archer's green (his tunic's and hood's first dye).
ARCHER_GREEN = (0.20, 0.30, 0.14)
# Bare skin: the detailed heads' skin before his tone (build.SKIN's).
SKIN_COLOUR = (0.63, 0.42, 0.30)

WATCHMAN = {
    "kind": "watchman",
    "body": "male",
    # Built as the user approved him (batch 0): his belt sloped from ring to
    # ring every 30 degrees, his cloth rows where they hang. Batch 1's
    # upright belt and cloth built clear of his legs (build.band,
    # build.collider_push) would move his belt, skirts, tabard and props;
    # dropping this rebuilds (and rebakes) him with them: the user's call.
    "batch": 0,
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
         # Their chains are skirt_l and skirt_r (build.skirt names them).
         "panels": {"left": [40, 140], "right": [-140, -40]}},
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
        # His hair shows only under the bare hat (the coif hides it); his
        # beard under either.
        "faces": ["young", "weathered", "heavy", "old"], "tones": ["light", "dark"], "hair": ["parted", "buzzed", "tied"],
        "beards": ["", "short", "moustache", "full"],
        "hair_colours": [[0.20, 0.14, 0.09], [0.10, 0.08, 0.06], [0.35, 0.25, 0.15], [0.45, 0.30, 0.18]],
        "headgear": [["kettlehat", "coif"], ["kettlehat_bare"]],
        # A watch wears one livery: its hue moves a little, washing and dirt
        # (fade, grime) do the rest.
        "dye": {"colour": list(MUSTARD), "shift": 0.025, "fade": [0.0, 0.3]},
        # How dirty he is (the shader's grime): from lately washed to
        # never; below 0.25 the mud barely reads.
        "grime": [0.25, 1.0],
    },
}

SWORD_RED = (0.52, 0.09, 0.07)

# The swordsman (the `swordsman` archetype): a mail hauberk to the thigh over
# quilted sleeves, its mail skirt hanging to the knee, a red surcoat over it
# all to mid-shin with a pale stripe down it, leather gauntlets, iron
# pauldrons, the watchman's belt and scabbard; a nasal helm and mail curtain.
SWORDSMAN = {
    "kind": "swordsman",
    "body": "male",
    "base_tris": 1300,
    "bare": ["head"],
    "belt": ("spine_01", 0.0),
    "garments": [
        {"name": "sleeves", "type": "shell", "fabric": "quilted_linen", "colour": (0.42, 0.40, 0.37),
         "regions": ["lower"], "sleeve_end": ("hand_l", 0.0), "sleeve_back": 0.016, "thickness": 0.02, "lips": ["sleeve"]},
        {"name": "hose", "type": "shell", "fabric": "wool", "colour": (0.24, 0.23, 0.22),
         "regions": ["pelvis", "thigh", "calf"], "bottom": ("calf_l", 0.6), "top": ("spine_01", 0.0),
         "thickness": 0.006, "smooth": 2},
        {"name": "boots", "type": "boots", "fabric": "leather", "colour": BOOT_BROWN,
         "top": ("calf_l", 0.45), "thickness": 0.012, "sole": 0.004, "cuff": 0.04, "smooth": 3},
        {"name": "mail", "type": "shell", "fabric": "mail", "colour": MAIL,
         "regions": ["torso", "pelvis", "upper"], "bottom": ("thigh_l", 0.2), "sleeve_end": ("lowerarm_l", 0.1),
         "thickness": 0.022, "smooth": 8, "lips": ["sleeve", "bottom"],
         "pads": [{"from": ("spine_02", 0.6), "to": ("spine_03", 0.9), "front": True, "amount": 0.01}]},
        {"name": "gauntlets", "type": "mittens", "fabric": "leather", "colour": (0.22, 0.14, 0.08),
         "cuff_into_sleeve": 0.045, "cuff": 0.035},
        # Under the surcoat, riding its chains (build.ride_chains): two
        # layers on their own chains swung through each other (K21).
        {"name": "mail_skirt", "type": "panels", "fabric": "mail", "colour": MAIL,
         "width": 0.36, "hem": ("calf_l", 0.05), "bones": 2, "rides": "surcoat"},
        {"name": "surcoat", "type": "tabard", "fabric": "wool", "colour": SWORD_RED, "dye": True, "stripe": (0.86, 0.84, 0.78),
         "over": "mail", "proud": 0.006, "tuck": 0.015, "hem": ("calf_l", 0.25), "width": 0.30, "bones": 3},
        {"name": "belt", "type": "belt", "fabric": "leather", "colour": BELT_BROWN,
         "height": 0.045, "buckle": {"fabric": "iron", "colour": IRON, "size": (0.055, 0.014, 0.05)}},
        {"name": "pauldron", "type": "pauldron", "fabric": "iron", "colour": (0.30, 0.30, 0.32), "over": "mail",
         "reach": 0.14, "drop": 0.12, "rings": 3, "clearance": 0.012, "roll": 0.01},
        {"name": "scabbard", "type": "prop", "shape": "scabbard", "fabric": "leather", "colour": SCABBARD_BLACK,
         "at": 100, "length": 0.9, "back": 25, "size": (0.05, 0.026, 0.9), "fittings": {"fabric": "iron", "colour": IRON},
         "bone": "pelvis"},
    ],
    # The surcoat's chains carry the mail skirt under it too: stiffer and
    # heavier-dragged than the watchman's tabard (three bones hang further
    # from how they were made: at 1.2 a restart settled at 3.6 m/s, K12; at
    # 2.2 and drag 0.6 a knockdown whipped the hem to 11.3 m/s, K6b); it
    # swings as far (K4). Its joints keep 5 cm off his legs (the watchman's
    # 3): at 3 his overhead cut swung the front's hem up to 1.8 cm into his
    # right thigh (K5); at 6 a knockdown whipped it to 12.1 m/s (K6b).
    # Stiffness 3 (from 2): at 2 a restart after some idle sways settled at
    # 3.04 m/s (K12); at 4 a limp body flung it at 16 m/s (K6).
    "chains": {
        "surcoat_front": {"stiffness": 3.0, "drag": 0.9, "gravity": 1.0, "radius": 0.05},
        "surcoat_back": {"stiffness": 3.0, "drag": 0.9, "gravity": 1.0, "radius": 0.05},
    },
    "colliders": [
        {"bone": "thigh_l", "radius": 0.09}, {"bone": "thigh_r", "radius": 0.09},
        {"bone": "calf_l", "radius": 0.065}, {"bone": "calf_r", "radius": 0.065},
        {"bone": "spine_01", "radius": 0.16},
    ],
    "metal": ["spine_01", "spine_02", "spine_03", "pelvis", "upperarm_l", "upperarm_r"],
    "options": {
        "faces": ["young", "weathered", "heavy", "old"], "tones": ["light", "dark"], "hair": [], "beards": [],
        "headgear": [["nasalhelm", "curtain"]],
        "dye": {"colour": list(SWORD_RED), "shift": 0.02, "fade": [0.0, 0.3]},
        "grime": [0.2, 0.9],
    },
}

# The archer (the `archer` archetype): a dyed wool tunic (green, brown or
# grey) to mid-thigh under a leather jerkin, hose, leg wraps and low boots,
# bare hands, a bracer on his bow arm, belt, pouch, knife and a swinging
# quiver; his hood dyed as his tunic.
ARCHER = {
    "kind": "archer",
    "body": "male",
    "base_tris": 1300,
    "bare": ["head", "hand"],
    "belt": ("spine_01", 0.0),
    "garments": [
        # To mid-thigh: its thighs are the shell's too (a hem needs them),
        # and the hose starts where it ends.
        {"name": "tunic", "type": "shell", "fabric": "wool", "colour": ARCHER_GREEN, "dye": True,
         "regions": ["pelvis", "thigh", "upper", "lower"], "bottom": ("thigh_l", 0.35),
         "sleeve_end": ("hand_l", 0.0), "sleeve_back": 0.016, "thickness": 0.008, "lips": ["sleeve", "bottom"]},
        {"name": "jerkin", "type": "shell", "fabric": "leather", "colour": (0.26, 0.17, 0.10),
         "regions": ["torso"], "thickness": 0.016, "smooth": 6},
        # Down under his boots' tops (calf_l 0.72): no bare shin between.
        {"name": "hose", "type": "shell", "fabric": "wool", "colour": (0.22, 0.20, 0.17),
         "regions": ["pelvis", "thigh", "calf"], "top": ("thigh_l", 0.35), "bottom": ("calf_l", 0.8),
         "thickness": 0.006, "smooth": 2},
        {"name": "wraps", "type": "shell", "fabric": "wrapped", "colour": (0.46, 0.41, 0.33),
         "regions": ["calf"], "top": ("calf_l", 0.05), "bottom": ("calf_l", 0.7), "thickness": 0.01, "smooth": 2},
        {"name": "boots", "type": "boots", "fabric": "leather", "colour": (0.26, 0.18, 0.11),
         "top": ("calf_l", 0.72), "thickness": 0.008, "sole": 0.004, "cuff": 0, "smooth": 3},
        # Bare hands: mittens of his own skin (the game tones them as his face).
        {"name": "hands", "type": "mittens", "fabric": "skin", "colour": SKIN_COLOUR, "cuff": 0},
        {"name": "bracer", "type": "bracer", "fabric": "leather", "colour": (0.22, 0.14, 0.08),
         "bone": "lowerarm_l", "from": 0.35, "to": 0.85, "thickness": 0.008},
        {"name": "belt", "type": "belt", "fabric": "leather", "colour": BELT_BROWN,
         "height": 0.045, "buckle": {"fabric": "iron", "colour": IRON, "size": (0.055, 0.014, 0.05)}},
        {"name": "pouch", "type": "prop", "shape": "pouch", "fabric": "leather", "colour": BELT_BROWN,
         "at": -110, "size": (0.12, 0.05, 0.10), "bone": "pelvis"},
        {"name": "knife", "type": "prop", "shape": "knife", "fabric": "leather", "colour": (0.18, 0.11, 0.06),
         "at": 30, "bone": "pelvis", "fittings": {"fabric": "iron", "colour": IRON}},
        {"name": "quiver", "type": "prop", "shape": "quiver", "fabric": "leather", "colour": (0.30, 0.20, 0.12),
         "at": 110, "length": 0.42, "bone": "pelvis"},
    ],
    # A heavy case of arrows: it swings lazily. Soft, so a body falling on
    # it lets it go (stiff, it was held into the floor under him and then
    # thrown out: 14.6 m/s at the plan's 2.0/0.8/1.2, K6).
    "chains": {
        "quiver": {"stiffness": 0.5, "drag": 0.95, "gravity": 0.8, "radius": 0.035},
    },
    "colliders": [
        {"bone": "thigh_l", "radius": 0.09}, {"bone": "thigh_r", "radius": 0.09},
        {"bone": "calf_l", "radius": 0.065}, {"bone": "calf_r", "radius": 0.065},
        {"bone": "spine_01", "radius": 0.16},
    ],
    "metal": [],
    "options": {
        "faces": ["young", "weathered", "heavy", "old"], "tones": ["light", "dark"], "hair": [], "beards": [],
        "headgear": [["hood"]],
        # His tunic and hood: green, brown or grey (baked in the first).
        "dye": {"colours": [list(ARCHER_GREEN), [0.34, 0.25, 0.15], [0.37, 0.37, 0.35]], "shift": 0.02, "fade": [0.0, 0.35]},
        "grime": [0.3, 1.0],
    },
}

DOUBLET = (0.62, 0.58, 0.50)

# The arms master (the `trainer` archetype): one old man, grey-haired and
# bearded, in a pale quilted doublet with a standing collar and a short
# four-panel skirt, a dark sash knotted at his front (10 degrees to his
# left) with two tails, hose, ankle boots, gloves, his sword hung from the
# sash. No headgear, no dye.
ARMS_MASTER = {
    "kind": "arms_master",
    "body": "male",
    "base_tris": 1300,
    "bare": ["head"],
    "belt": ("spine_01", 0.0),
    "garments": [
        # Down under his ankle boots' tops (calf_l 0.82).
        {"name": "hose", "type": "shell", "fabric": "wool", "colour": (0.20, 0.19, 0.18),
         "regions": ["pelvis", "thigh", "calf"], "bottom": ("calf_l", 0.9), "top": ("spine_01", 0.0),
         "thickness": 0.006, "smooth": 2},
        {"name": "boots", "type": "boots", "fabric": "leather", "colour": (0.24, 0.16, 0.10),
         "top": ("calf_l", 0.82), "thickness": 0.01, "sole": 0.004, "cuff": 0, "smooth": 3},
        {"name": "doublet", "type": "shell", "fabric": "quilted_linen", "colour": DOUBLET,
         "regions": ["torso", "pelvis", "upper", "lower"], "bottom": ("thigh_l", 0.05), "sleeve_end": ("hand_l", 0.0),
         "sleeve_back": 0.016, "thickness": 0.016, "smooth": 8, "lips": ["sleeve", "bottom"],
         "pads": [{"from": ("spine_02", 0.6), "to": ("spine_03", 0.9), "front": True, "amount": 0.008}]},
        {"name": "gloves", "type": "mittens", "fabric": "leather", "colour": (0.30, 0.22, 0.15), "cuff": 0.02},
        # His bare neck's seam goes under it (check heads' seam rule).
        {"name": "collar", "type": "collar", "fabric": "quilted_linen", "colour": DOUBLET,
         "on": "doublet", "height": 0.045, "lean_in": 0.25},
        {"name": "doublet_skirt", "type": "skirt", "fabric": "quilted_linen", "colour": DOUBLET,
         "hem": ("thigh_l", 0.35), "flare": 1.25, "clearance": 0.02, "bones": 1,
         "panels": {"front": [-40, 40], "back": [140, 220], "left": [45, 135]}},
        {"name": "sash", "type": "sash", "fabric": "wool", "colour": (0.14, 0.12, 0.13),
         "height": 0.07, "tails": 2, "at": 10, "length": 0.35, "bones": 3},
        {"name": "scabbard", "type": "prop", "shape": "scabbard", "fabric": "leather", "colour": SCABBARD_BLACK,
         "at": 100, "length": 0.9, "back": 25, "size": (0.05, 0.026, 0.9), "fittings": {"fabric": "iron", "colour": IRON},
         "bone": "pelvis"},
    ],
    "chains": {
        # 4.5 cm off his legs (the plan's 3: his attacks swung the skirt
        # 1.1 cm into a thigh, K5), and stiffer than the plan's 1.6: at 1.6,
        # stopped, his right hem sagged onto his right thigh and rode its
        # sway (2.4 cm/s, K4); at 2.4 it holds its flare just off it.
        "doublet_skirt_front": {"stiffness": 2.4, "drag": 0.7, "gravity": 1.0, "radius": 0.045},
        "doublet_skirt_back": {"stiffness": 2.4, "drag": 0.7, "gravity": 1.0, "radius": 0.045},
        "doublet_skirt_l": {"stiffness": 2.4, "drag": 0.7, "gravity": 1.0, "radius": 0.045},
        "doublet_skirt_r": {"stiffness": 2.4, "drag": 0.7, "gravity": 1.0, "radius": 0.045},
        # A little stiffer than the plan's 1.0/0.5: three bones hanging from
        # his sash sagged far enough from how they were made that a restart
        # (K12) settled at 3.0 m/s.
        "sash_1": {"stiffness": 1.5, "drag": 0.7, "gravity": 1.0, "radius": 0.025},
        "sash_2": {"stiffness": 1.5, "drag": 0.7, "gravity": 1.0, "radius": 0.025},
    },
    "colliders": [
        {"bone": "thigh_l", "radius": 0.09}, {"bone": "thigh_r", "radius": 0.09},
        {"bone": "calf_l", "radius": 0.065}, {"bone": "calf_r", "radius": 0.065},
        {"bone": "spine_01", "radius": 0.16},
    ],
    "metal": [],
    "options": {
        "faces": ["old"], "tones": ["light"], "hair": ["parted"], "beards": ["full"],
        "hair_colours": [[0.72, 0.70, 0.66]],
        "headgear": [[]],
        "grime": [0.1, 0.3],
    },
}

# The brute: huge fur shoulders, bare arms, strips at the waist (spec §8;
# 3,500 triangles, common.BUDGETS). A shaved head and a full beard; bare
# arms with bracers; a stiff fur mantle; a studded leather jerkin over a
# padded gut; a wide belt; hide strips; one crude iron pauldron on his
# right; fur-topped boots. Browns, dark leather, iron. No dye.
BRUTE = {
    "kind": "brute",
    "body": "male",
    # (1,400 before his neck was kept: the neck's faces came out of his
    # shoulders', and big faces touching his mantle left holes there.)
    "base_tris": 1500,
    # His bare neck kept up under his head (build.low_poly_base): cut at the
    # head's bone weights, its dark stub showed between the teeth of the
    # head's edge (K34).
    # (Up to just over the head's edge, 1.567 at its highest: higher, it
    # reached under his jaw, and his beard cut it.)
    "neck_under": {"up_to": 1.572, "from": 1.515, "tuck": 0.005},
    "bare": ["head", "upper", "lower", "hand"],
    "belt": ("spine_01", 0.0),
    "garments": [
        {"name": "trousers", "type": "shell", "fabric": "wool", "colour": (0.24, 0.19, 0.14),
         "regions": ["pelvis", "thigh", "calf"], "bottom": ("calf_l", 0.6), "top": ("spine_01", 0.0),
         "thickness": 0.008, "smooth": 2},
        {"name": "boots", "type": "boots", "fabric": "leather", "colour": (0.20, 0.14, 0.09), "top": ("calf_l", 0.5),
         "thickness": 0.012, "sole": 0.004, "cuff": 0.05, "cuff_fabric": "fur", "cuff_colour": (0.36, 0.28, 0.20),
         "smooth": 3},
        {"name": "hands", "type": "mittens", "fabric": "skin", "colour": SKIN_COLOUR, "cuff": 0},
        # His gut, padded out in front.
        {"name": "gut", "type": "shell", "fabric": "quilted_linen", "colour": (0.40, 0.33, 0.24),
         "regions": ["torso", "pelvis"], "bottom": ("thigh_l", 0.05), "thickness": 0.014, "smooth": 4,
         "pads": [{"from": ("pelvis", 0.0), "to": ("spine_02", 0.5), "amount": 0.05, "front": True}]},
        # Over the gut (shells stand off his body: thicker than the gut, and
        # padded as it is, so it lies over it).
        {"name": "jerkin", "type": "shell", "fabric": "leather", "colour": (0.24, 0.16, 0.10), "regions": ["torso"],
         "thickness": 0.026, "smooth": 4, "studs": {"spacing": 0.05},
         "pads": [{"from": ("pelvis", 0.0), "to": ("spine_02", 0.5), "amount": 0.05, "front": True}]},
        {"name": "bracer_l", "type": "bracer", "fabric": "leather", "colour": (0.22, 0.15, 0.09),
         "bone": "lowerarm_l", "from": 0.3, "to": 0.85, "thickness": 0.008},
        {"name": "bracer_r", "type": "bracer", "fabric": "leather", "colour": (0.22, 0.15, 0.09),
         "bone": "lowerarm_r", "from": 0.3, "to": 0.85, "thickness": 0.008},
        # Four hide strips on his diagonals, over the fronts and backs of his
        # thighs: none between his legs, where a sweeping thigh crosses (a
        # strip there went 5.6 cm into it, K5). As two skirts (a skirt
        # mirrors one side panel).
        # Each rides its thigh (its chain hangs from it): hung from his
        # pelvis, a strip's root sat where his thigh swings up in his blows,
        # and its first joint could not get clear (9 cm into it, K5).
        {"name": "hides", "type": "skirt", "fabric": "leather", "colour": (0.34, 0.26, 0.18), "hem": ("thigh_l", 0.45),
         "flare": 1.3, "clearance": 0.03, "bones": 2, "ride": "thigh", "panels": {"left": [25, 75], "right": [-75, -25]}},
        {"name": "hides_rear", "type": "skirt", "fabric": "leather", "colour": (0.34, 0.26, 0.18), "hem": ("thigh_l", 0.45),
         "flare": 1.3, "clearance": 0.03, "bones": 2, "ride": "thigh",
         "panels": {"left": [105, 155], "right": [-155, -105]}},
        {"name": "belt", "type": "belt", "fabric": "leather", "colour": (0.16, 0.11, 0.07), "height": 0.09,
         "buckle": {"fabric": "iron", "colour": IRON, "size": (0.07, 0.012, 0.06)}},
        # It stands clear of him: the skin under it stays (cut away, its
        # ragged edge let the roll's unlit underside show as black shards
        # round his throat).
        {"name": "mantle", "type": "mantle", "fabric": "fur", "colour": (0.30, 0.24, 0.18), "over": "jerkin",
         "reach": 0.16, "thickness": 0.05, "depth_front": 0.12, "depth_back": 0.18, "clear": 0.02, "dip": 0.08,
         "hides": False},
        {"name": "pauldron", "type": "pauldron", "fabric": "iron", "colour": (0.28, 0.27, 0.27), "side": "right",
         "over": "jerkin", "reach": 0.14, "drop": 0.12, "rings": 3, "clearance": 0.012, "roll": 0.01},
        {"name": "pouch", "type": "prop", "shape": "pouch", "fabric": "leather", "colour": BELT_BROWN,
         "at": -100, "size": (0.12, 0.05, 0.10), "bone": "pelvis"},
    ],
    # Stiff hide, 6 cm off his legs: at 1.8/0.8/1.0/0.035 a restart
    # settled at 3.5 m/s (K12) and his blows swung them into his thighs
    # (K5); riding his thighs their rest follows the leg, so at full gravity
    # a restart swung them 3.7 m/s back to hanging; at 0.6, 3.1 m/s in
    # metres at his size (1.25: K12 had read it in his scaled frame): 0.5.
    # Stiffness 8 (from 4): through whole blows (windup, strike, recover)
    # his sweep swung a hide 2.9 cm into the thigh it rides; at 8, 1-1.6
    # (K5 allows him 2 cm); stiffer did no better.
    "chains": {name: {"stiffness": 8.0, "drag": 0.95, "gravity": 0.5, "radius": 0.06}
               for name in ("hides_l", "hides_r", "hides_rear_l", "hides_rear_r")},
    "colliders": [
        {"bone": "thigh_l", "radius": 0.10}, {"bone": "thigh_r", "radius": 0.10},
        {"bone": "calf_l", "radius": 0.07}, {"bone": "calf_r", "radius": 0.07},
        {"bone": "spine_01", "radius": 0.18},
    ],
    "metal": ["upperarm_r"],
    "options": {
        "faces": ["heavy", "weathered"], "tones": ["light", "dark"], "hair": ["buzzed"], "beards": ["short", "full"],
        "hair_colours": [[0.25, 0.20, 0.18], [0.14, 0.11, 0.09], [0.45, 0.30, 0.18]],
        "headgear": [[]],
        "grime": [0.4, 1.0],
    },
}

# The duelist, on the female body: puffed shoulders, a half-cape, tall boots
# (spec §8). Bare-headed, her hair up; a fitted doublet with slashed, puffed
# sleeves and a short skirt; the half-cape on her left shoulder; breeches;
# folded thigh boots; her rapier on a hanger. Crimson and gold over black;
# the doublet's shade varies (its dye).
CRIMSON = (0.50, 0.06, 0.08)
GOLD = (0.78, 0.60, 0.22)
DUELIST = {
    "kind": "duelist",
    "body": "female",
    "base_tris": 1300,
    "bare": ["head"],
    "belt": ("spine_01", 0.0),
    "garments": [
        {"name": "breeches", "type": "shell", "fabric": "wool", "colour": (0.10, 0.09, 0.10), "regions": ["pelvis", "thigh"],
         "bottom": ("calf_l", 0.1), "top": ("spine_01", 0.0), "thickness": 0.008, "smooth": 2},
        # A warm brown: black on her black breeches, her tall boots were
        # lost (Task 7's look).
        {"name": "boots", "type": "boots", "fabric": "leather", "colour": (0.28, 0.18, 0.10), "top": ("thigh_l", 0.35),
         "thickness": 0.01, "sole": 0.004, "cuff": 0.06, "smooth": 3},
        {"name": "doublet", "type": "shell", "fabric": "wool", "colour": CRIMSON, "dye": True,
         "regions": ["torso", "pelvis", "upper", "lower"], "bottom": ("thigh_l", 0.05), "sleeve_end": ("hand_l", 0.0),
         "sleeve_back": 0.016, "thickness": 0.012, "smooth": 8, "lips": ["sleeve", "bottom"]},
        {"name": "puffs", "type": "puff", "fabric": "wool", "colour": CRIMSON, "dye": True, "from": 0.0, "to": 0.55,
         "peak": 0.25, "puff": 0.035, "slashes": {"count": 6, "colour": GOLD}},
        {"name": "gloves", "type": "mittens", "fabric": "leather", "colour": (0.10, 0.08, 0.07), "cuff": 0.03},
        {"name": "collar", "type": "collar", "fabric": "wool", "colour": GOLD, "on": "doublet", "height": 0.035,
         "lean_in": 0.25},
        # Its side panels ride her thighs (as the brute's strips): hung from
        # her pelvis, her lunging thigh went through the right one (K5).
        {"name": "skirt", "type": "skirt", "fabric": "wool", "colour": CRIMSON, "dye": True, "hem": ("thigh_l", 0.25),
         "flare": 1.25, "clearance": 0.02, "bones": 1, "ride": "thigh",
         "panels": {"front": [-40, 40], "back": [140, 220], "left": [45, 135]}},
        {"name": "belt", "type": "belt", "fabric": "leather", "colour": (0.10, 0.08, 0.07), "height": 0.04,
         "buckle": {"fabric": "iron", "colour": GOLD, "size": (0.045, 0.01, 0.04)}},
        # From her left shoulder across her upper back: its top line from
        # her right shoulder blade (14 cm past her spine: at 6 it read as a
        # strap across her back, Task 7's look) to 5 cm inside her left
        # shoulder point (over her upper arm, where her arm hangs and swings,
        # it was thrown about: 10 m/s restarts, K12; into it, K27).
        {"name": "half_cape", "type": "half_cape", "fabric": "wool", "colour": (0.10, 0.09, 0.11),
         "hem": ("spine_01", -0.05), "clear": 0.02, "chains": 3, "bones": 3, "inner": -0.14, "reach": -0.05,
         "stance": 0.01, "hang_from": "spine_02"},
        # The half-cape over her left shoulder: its cloth on her shoulder and
        # the top of her puff, riding her arm (the half-cape alone was a
        # dark strip on her back, not seen from in front: Task 7's look);
        # 2.5 cm off her puff (at 1 its round slashes came through the
        # drape's flat facets).
        {"name": "cape_shoulder", "type": "pauldron", "fabric": "wool", "colour": (0.10, 0.09, 0.11), "side": "left",
         "over": "puffs", "reach": 0.15, "drop": 0.13, "rings": 4, "clearance": 0.025, "roll": 0.01},
        {"name": "hanger", "type": "prop", "shape": "hanger", "fabric": "leather", "colour": (0.10, 0.08, 0.07),
         "at": 100, "back": 35, "size": (0.03, 0.018, 0.95), "fittings": {"fabric": "iron", "colour": GOLD},
         "bone": "pelvis"},
    ],
    # Through whole blows (windup, strike, recover: the strike a quick
    # 0.12 s) her skirt went 0.8 cm into a thigh (K5) and her cape 1.4 into
    # her left arm (K27) at 2 and 3; at 4 and 6 (her cape's drag 0.8: at
    # 0.6 her slow motion outran K4b's 0.4) both stay out.
    "chains": {
        **{name: {"stiffness": 4.0, "drag": 0.7, "gravity": 1.0, "radius": 0.045}
           for name in ("skirt_front", "skirt_back", "skirt_l", "skirt_r")},
        **{"half_cape_%d" % n: {"stiffness": 6.0, "drag": 0.8, "gravity": 0.7, "radius": 0.06} for n in (1, 2, 3)},
    },
    # Sized to her: her waist and back are 6-10 cm deep of her spine (the
    # men's 14-16 cm put her skirt's roots and her cape inside them), her
    # upper arm 4 cm off its bone and 6 with its puff (at 8, its round end
    # at her shoulder took in her cape's roots there).
    "colliders": [
        {"bone": "thigh_l", "radius": 0.08}, {"bone": "thigh_r", "radius": 0.08},
        {"bone": "calf_l", "radius": 0.06}, {"bone": "calf_r", "radius": 0.06},
        {"bone": "spine_01", "radius": 0.09}, {"bone": "spine_02", "radius": 0.10},
        {"bone": "upperarm_l", "radius": 0.06},
    ],
    "metal": [],
    "options": {
        "faces": ["sharp", "soft"], "tones": ["light", "dark"], "hair": ["buns", "tail"], "beards": [],
        "hair_colours": [[0.35, 0.22, 0.14], [0.12, 0.09, 0.07], [0.55, 0.38, 0.20]],
        "headgear": [[]],
        "dye": {"colours": [list(CRIMSON), [0.40, 0.05, 0.10], [0.56, 0.12, 0.06]], "shift": 0.02, "fade": [0.0, 0.3]},
        "grime": [0.1, 0.5],
    },
}

KINDS = {"watchman": WATCHMAN, "swordsman": SWORDSMAN, "archer": ARCHER, "arms_master": ARMS_MASTER, "brute": BRUTE,
         "duelist": DUELIST}

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
    # The weathered face grown old (the arms master): cheeks sunk further,
    # jowls dropped at the jaw's sides, a heavier brow; smaller eyes, deep
    # bags and lines, a little grey stubble, grey brows.
    "old": {
        "body": "male",
        "tris": 340,
        "shape": [
            {"at": (0.047, -0.07, 1.648), "radius": 0.028, "along_normal": -0.005},
            {"at": (0.032, -0.088, 1.722), "radius": 0.03, "move": (0.0, -0.004, -0.003)},
            {"at": (0.0, -0.09, 1.575), "radius": 0.04, "move": (0.0, -0.002, -0.004)},
            # Older: the cheeks sunken, the jowls dropped, the brow heavier.
            {"at": (0.047, -0.07, 1.648), "radius": 0.03, "along_normal": -0.007},
            {"at": (0.052, -0.06, 1.595), "radius": 0.03, "move": (0.0, 0.0, -0.005)},
            {"at": (0.032, -0.088, 1.725), "radius": 0.03, "move": (0.0, -0.003, -0.002)},
        ],
        "eyes": 0.8,
        "grit": {"stubble": 0.35, "bags": 0.9, "lines": 1.0},
        "brows": (0.62, 0.60, 0.57),
        "tones": TONES,
    },
    # A young man (batch 3): cheeks full where the weathered face is hollow,
    # a shorter jaw, a lighter brow; a little stubble, no wear yet.
    "young": {
        "body": "male",
        "tris": 340,
        "shape": [
            {"at": (0.047, -0.07, 1.648), "radius": 0.03, "along_normal": 0.005},
            # A narrower, lighter jaw (its side is at x ~0.04 at y -0.04,
            # z 1.60). (A smaller chin, pushed in at y -0.087, took his lower
            # lip into the detailed head's mouth: the bake painted a dark
            # streak from its corner.)
            {"at": (0.04, -0.04, 1.60), "radius": 0.03, "move": (-0.003, 0.0, 0.0)},
            {"at": (0.032, -0.088, 1.722), "radius": 0.03, "move": (0.0, 0.002, 0.002)},
        ],
        "eyes": 0.95,
        "grit": {"stubble": 0.1, "bags": 0.05, "lines": 0.05},
        "brows": (0.20, 0.14, 0.09),
        "tones": TONES,
    },
    # A heavy man (batch 3; the brute's other face): the jaw's sides wider,
    # full jowls, a broad nose, a low heavy brow; dark stubble. (Anchored on
    # his head's surface as measured: the jaw's side is at x 0.037-0.044
    # at y -0.04, z 1.60; the nose's tip at z 1.665.)
    "heavy": {
        "body": "male",
        "tris": 340,
        "shape": [
            {"at": (0.04, -0.04, 1.60), "radius": 0.03, "move": (0.012, 0.0, 0.0)},
            {"at": (0.044, -0.015, 1.60), "radius": 0.03, "move": (0.008, 0.0, 0.0)},
            {"at": (0.036, -0.058, 1.61), "radius": 0.025, "along_normal": 0.008},
            {"at": (0.0, -0.087, 1.598), "radius": 0.025, "move": (0.0, -0.004, -0.002)},
            {"at": (0.012, -0.1, 1.65), "radius": 0.012, "move": (0.004, 0.0, 0.0)},
            {"at": (0.032, -0.088, 1.722), "radius": 0.03, "move": (0.0, -0.006, -0.003)},
        ],
        "eyes": 0.8,
        "grit": {"stubble": 1.0, "bags": 0.5, "lines": 0.4},
        "brows": (0.12, 0.09, 0.07),
        "tones": TONES,
    },
    # The duelist's face, on the female head (her face sits 4.2 cm under a
    # man's and 0.5 cm further back): cheekbones higher and fuller, the jaw
    # narrower at its sides, a straighter nose; no stubble, a little wear,
    # a thin scar through her left brow.
    "sharp": {
        "body": "female",
        "tris": 340,
        "shape": [
            {"at": (0.05, -0.063, 1.63), "radius": 0.025, "move": (0.002, -0.002, 0.004)},
            {"at": (0.05, -0.045, 1.558), "radius": 0.03, "move": (-0.004, 0.0, 0.0)},
            {"at": (0.0, -0.1, 1.633), "radius": 0.015, "along_normal": 0.002},
        ],
        "eyes": 0.85,
        "grit": {"stubble": 0.0, "bags": 0.3, "lines": 0.3, "scar": "brow"},
        "brows": (0.14, 0.10, 0.08),
        "tones": TONES,
    },
    # Her other face (batch 3): fuller low cheeks, a rounder jaw, a smaller
    # nose; hardly any wear. (Her jaw's side is at x ~0.03 at y -0.045,
    # z 1.56; her nose's front at y -0.107.)
    "soft": {
        "body": "female",
        "tris": 340,
        "shape": [
            {"at": (0.05, -0.063, 1.61), "radius": 0.028, "along_normal": 0.006},
            {"at": (0.03, -0.045, 1.56), "radius": 0.028, "move": (0.006, 0.0, 0.002)},
            {"at": (0.0, -0.105, 1.628), "radius": 0.012, "along_normal": -0.002},
        ],
        "eyes": 0.9,
        "grit": {"stubble": 0.0, "bags": 0.15, "lines": 0.1},
        "brows": (0.25, 0.17, 0.10),
        "tones": TONES,
    },
}


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
             "rigid_above": 1.68, "limit": 240,
             # The beards he may wear under it (§6: a coif "allows a beard"),
             # each at least `beard_clear` under its mail below his chin, and
             # nowhere nearer than `beard_margin` (his head turns on his neck
             # in his idle: a beard on his head moves against mail on his
             # neck).
             "over_beards": ["short", "moustache", "full"], "beard_clear": 0.006, "beard_margin": 0.01,
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
    # The same hat on a bare head (batch 3; §8: "coif or bare head under the
    # kettle hat"), his hair and beard showing under its brim: fitted over
    # every male head and the hair he may wear under it (`over_hair`), its
    # band just over his brows. check.py holds it `clearance` to `rest` off
    # the outermost of them along `fit_rays` (above its band: lower rays
    # meet the brim, and one near its top: a hair's crest rises between
    # sampled points, build.kettle fits its upper bowl over the most any way
    # near each point needs); clearing the thickest hair, its round bowl
    # stands up to 4.9 cm off his bare crown, as the coif's hat does off his
    # head (3.2 over 1.5 of mail).
    "kettlehat_bare": {"type": "kettle", "bone": "Head", "over": "head", "over_hair": ["parted", "buzzed", "tied"],
                       "clearance": 0.006, "slack": 0.009, "rest": 0.05, "base_z": 1.735, "centre_y": 0.02, "drop": 0.05,
                       "segments": 16, "elevations": [15, 38, 60, 80], "comb": 0.0, "brim": 0.07, "droop": 0.036,
                       "lip": 0.012, "rivets": 12, "fabric": "iron", "colour": IRON_HAT, "band": ("leather", LEATHER),
                       "fit_rays": {"elevations": [35, 55, 75, 85], "azimuths": list(range(0, 360, 30))},
                       "metal": ["Head"], "hides_hair": False, "allows_beard": True, "body": "male"},
    # The swordsman's nasal helm (build.helm): the kettle's bowl without a
    # brim, set straight on his head (every head he may wear it on), its
    # crown drawn up `point` to a point, an iron brow band `band` tall
    # standing `proud` of it (riveted, in the bake) and a nasal bar down his
    # nose. check.py holds it `clearance` to `rest` off every head along
    # `fit_rays` (its sides: the drawn-up point stands further off by
    # design).
    "nasalhelm": {"type": "helm", "bone": "Head", "over": "head", "clearance": 0.006, "slack": 0.009, "rest": 0.035,
                  "base_z": 1.722, "centre_y": 0.009, "drop": 0.05, "segments": 16, "elevations": [40, 68],
                  "point": 0.03, "band": 0.028, "proud": 0.004, "rivets": 12,
                  "nasal": {"width": 0.022, "length": 0.075, "proud": 0.008},
                  "fit_rays": {"elevations": [15, 35, 55], "azimuths": list(range(0, 360, 30))},
                  "fabric": "iron", "colour": IRON_HAT, "limit": 220,
                  "metal": ["Head"], "hides_hair": True, "allows_beard": True},
    # Mail hanging from the helm's foot ring round his sides and back
    # (build.curtain), open at his face, laid clear of his neck and
    # shoulders; its top rides his head, its hem his neck and chest (K13b).
    "curtain": {"type": "curtain", "on": "nasalhelm", "tuck": 0.004, "open": 40, "length_side": 0.15,
                "length_back": 0.19, "clear": 0.07, "fabric": "mail", "colour": MAIL, "thickness": 0.012, "limit": 140,
                "metal": ["neck_01", "spine_03"], "hides_hair": True, "allows_beard": True},
    # The archer's hood: the coif's grid and opening in wool, dyed as his
    # tunic, a shorter cape, and a tail (a liripipe) down his back that
    # swings on its own chain (K13c); a capsule on his upper back keeps it
    # off him. Its cape faces out (`out`), so it is baked from above, as it
    # is seen: the coif's still faces in, as approved in batch 0 (its
    # outside is baked from underneath); turning it is the user's call.
    "hood": {"type": "coif", "fabric": "wool", "colour": ARCHER_GREEN, "dye": True, "thickness": 0.012, "slack": 0.004,
             "segments": 12, "rings": [-40, -12, 20, 48, 75], "open": 36,
             "opening": {"x": 0.07, "from_z": 1.585, "to_z": 1.738},
             "cape": {"top_z": 1.575, "clear": 0.06, "tilt_front": 62, "tilt_side": 45,
                      "length_front": 0.13, "length_side": 0.14, "out": True},
             "covers_head": True, "inside": 0.006, "rigid_above": 1.68,
             "tail": {"length": 0.32, "width": 0.07, "bones": 3, "elevation": 40, "clear": 0.035},
             "chains": {"hood_tail": {"stiffness": 1.0, "drag": 0.5, "gravity": 1.0, "radius": 0.025}},
             "colliders": [{"bone": "spine_03", "radius": 0.12}], "limit": 280,
             "metal": [], "hides_hair": True, "allows_beard": True},
}


# Where check.py looks for a gap between hair and head (degrees round from
# his front, and up from the middle of his head): over his crown, round his
# jaw.
CROWN = {"elevations": [25, 45, 65, 85], "azimuths": list(range(0, 360, 30))}
JAW = {"elevations": [-60, -45, -30], "azimuths": [-75, -45, -15, 15, 45, 75]}

# Hair and beards (build_hair): shells cut down from the Quaternius styles
# to `tris` (evenly either side), pushed out until they clear every head
# they may go on by `clearance`, weighed on his Head and neck, all of it
# hair and dyed (a grey the game tints his hair's colour).
HAIR = {
    "parted": {"from": "assets/characters/hair/Hair_SimpleParted.gltf", "body": "male", "kind": "hair", "tris": 180,
               "clearance": 0.004,
               "fit_rays": CROWN},
    # The brute's shaved head: a shell close over the scalp.
    "buzzed": {"from": "assets/characters/hair/Hair_Buzzed.gltf", "body": "male", "kind": "hair", "tris": 120,
               "clearance": 0.002, "fit_rays": CROWN},
    # The duelist's hair up.
    "buns": {"from": "assets/characters/hair/Hair_Buns.gltf", "body": "female", "kind": "hair", "tris": 200,
             "clearance": 0.004, "fit_rays": CROWN},
    "full": {"from": "assets/characters/hair/Hair_Beard.gltf", "body": "male", "kind": "beard", "tris": 120,
             "clearance": 0.003,
             "fit_rays": JAW},
    # Batch 3. The Quaternius pack has no short beard, moustache or tied
    # hair: they are cut from its styles (`keep`, `trim`) and tied (`tail`).
    # The short beard: the full beard under his mouth (his jaw and chin; it
    # ends at the chin as the full one does, 1.55: its shortness is no
    # cheeks and no moustache), close to his skin.
    "short": {"from": "assets/characters/hair/Hair_Beard.gltf", "body": "male", "kind": "beard", "tris": 70,
              "keep": {"box": [[-0.2, -0.2, 1.50], [0.2, 0.2, 1.612]]}, "clearance": 0.002, "fit_rays": JAW},
    # His upper lip alone (his mouth's line is at z 1.623, bake.weather; his
    # nose's base above 1.645); the check's rays aimed there from his head's
    # middle (about 36 degrees down).
    "moustache": {"from": "assets/characters/hair/Hair_Beard.gltf", "body": "male", "kind": "beard", "tris": 36,
                  "keep": {"box": [[-0.035, -0.13, 1.624], [0.035, -0.075, 1.648]]}, "clearance": 0.002,
                  "fit_rays": {"elevations": [-40, -36, -32], "azimuths": [-15, 0, 15]}},
    # The parted cut tied back: a tail from the back of his hair (its back
    # edge ends at z 1.66, y 0.1) down his neck, over the collars.
    "tied": {"from": "assets/characters/hair/Hair_SimpleParted.gltf", "body": "male", "kind": "hair", "tris": 200,
             "tail": {"length": 0.13, "width": 0.035, "sides": 6, "at": [0.095, 1.675]}, "clearance": 0.004,
             "fit_rays": CROWN},
    # Her hair pulled back tight (the female buzzed cap: z 1.60-1.77, its
    # back edge at y 0.115) and tied in a short tail down her neck, clear of
    # her half-cape's top. (Her long hair cut under her ears left spiky
    # locks and a jagged edge where it was cut: batch 3's look.)
    "tail": {"from": "assets/characters/hair/Hair_BuzzedFemale.gltf", "body": "female", "kind": "hair", "tris": 200,
             # Leaning back off her neck: in her fighting idle her head
             # tips back, and a tail hanging straight cut her collar (K33).
             "tail": {"length": 0.14, "width": 0.04, "sides": 6, "at": [0.1, 1.645], "lean": 0.4},
             "clearance": 0.004, "fit_rays": CROWN},
}
