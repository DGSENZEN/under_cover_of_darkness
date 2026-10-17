"""Take the realistic hand from Blender Studio's Human Base Meshes bundle (CC0)
and make it the start of the Prosecutor's hand: subdivided once, turned into
the rig's frame (a right hand, wrist at the origin, fingers along +Y, palm
down), scaled to SPEC["hand_length"], with its joints found from the mesh.

Writes assets/characters/fp_arms/source/base_hand.blend (one mesh, BaseHand)
and assets/characters/fp_arms/source/base_hand_joints.json, which
build_fp_arms.joints() reads. Run once, by hand, when the source changes:

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \\
        <human_base_meshes_bundle.blend> --python tools/arms/extract_base_hand.py -- <repo root>

The bundle: https://www.blender.org/download/demo-files/ (Human Base Meshes,
v1.4.1, CC0). Its face sets mark each finger's phalanges: the joints are the
middles of the loops between them.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from build_fp_arms import SPEC  # noqa: E402

# The bundle's face sets, per finger: proximal, middle, distal (thumb:
# metacarpal end, proximal, distal). 24 is the palm and back, 10 the nails.
FACE_SETS = {
    "index": (19, 16, 3),
    "middle": (18, 15, 4),
    "ring": (17, 14, 5),
    "pinky": (13, 12, 11),
    "thumb": (23, 22, 21),
}
PALM, NAILS = 24, 10
# A proximal phalanx is about 1.65 times the middle one (adult hands).
PROXIMAL_PER_MIDDLE = 1.65
# The metacarpal is about 0.87 of the finger's length from its knuckle to the
# tip (middle finger, SPEC hand 0.09 against 0.104).
PALM_PER_FINGER = 0.87


def main(root_dir):
    import bpy
    from collections import defaultdict
    from mathutils import Matrix, Vector

    hand = bpy.data.objects["Hand  - Realistic"]

    for o in list(bpy.data.objects):
        if o != hand:
            bpy.data.objects.remove(o, do_unlink=True)

    me = hand.data
    mw = hand.matrix_world.copy()
    sets = me.attributes[".sculpt_face_set"].data
    face_set = [sets[p.index].value for p in me.polygons]

    # --- Joints from the face sets (bundle space)
    by_set = defaultdict(set)
    edge_sets = defaultdict(set)

    for p in me.polygons:
        by_set[face_set[p.index]].update(p.vertices)

        for ek in p.edge_keys:
            edge_sets[ek].add(face_set[p.index])

    loops = defaultdict(set)

    for ek, s in edge_sets.items():
        if len(s) == 2:
            loops[tuple(sorted(s))].update(ek)

    def co(i):
        return mw @ me.vertices[i].co

    def loop_centre(a, b):
        vs = loops[tuple(sorted((a, b)))]
        assert vs, "no loop between face sets %d and %d" % (a, b)
        return sum((co(i) for i in vs), Vector()) / len(vs)

    def set_centre(k):
        return sum((co(i) for i in by_set[k]), Vector()) / len(by_set[k])

    def tip(joint, k):
        """The fingertip: from the last joint toward the distal set's middle,
        as far as its skin reaches, a little inside."""
        d = (set_centre(k) - joint).normalized()
        reach = max((co(i) - joint).dot(d) for i in by_set[k])
        return joint + d * reach * 0.92

    found = {}

    for finger, (prox, mid, dist) in FACE_SETS.items():
        a = loop_centre(prox, mid)
        b = loop_centre(mid, dist)
        end = tip(b, dist)

        if finger == "thumb":
            base = loop_centre(prox, PALM)
            root = a + (base - a).normalized() * (b - a).length * 1.5
            found[finger] = [root, a, b, end]
        else:
            base = loop_centre(prox, PALM)
            knuckle = a + (base - a).normalized() * (b - a).length * PROXIMAL_PER_MIDDLE
            found[finger] = [knuckle, a, b, end]

    knuckle = found["middle"][0]
    finger_length = sum(((found["middle"][k + 1] - found["middle"][k]).length for k in range(3)))
    # The wrist: up the stump (+Z in the bundle) from the middle knuckle.
    wrist_z = knuckle.z + finger_length * PALM_PER_FINGER
    near = [co(v.index) for v in me.vertices if abs(co(v.index).z - wrist_z) < 0.006]
    wrist = sum(near, Vector()) / len(near)
    wrist.z = wrist_z

    # --- Into the rig's frame: fingers -Z -> +Y, palm +Y -> -Z (and the thumb
    # +X -> -X: it is a right hand, the thumb toward the body), the wrist at
    # the origin, the middle knuckle straight ahead on +Y, scaled.
    turn = Matrix(((-1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, -1.0, 0.0))).to_4x4()
    frame = turn @ Matrix.Translation(-wrist)
    k = frame @ knuckle
    level = Vector((0.0, 1.0, 0.0)).rotation_difference(k.normalized()).inverted().to_matrix().to_4x4()
    frame = level @ frame
    tip_length = (frame @ found["middle"][3]).length
    frame = Matrix.Scale(SPEC["hand_length"] / tip_length, 4) @ frame

    # Subdivide once (the bundle's multires level 1), then bake the frame in.
    bpy.context.view_layer.objects.active = hand
    hand.select_set(True)

    for m in list(hand.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)

    hand.data.transform(frame @ mw)
    hand.matrix_world = Matrix.Identity(4)
    hand.name = "BaseHand"
    hand.data.name = "BaseHand"
    hand.data.attributes.active = None

    # Which finger each vertex belongs to (0 the palm and wrist, 1-5 index to
    # thumb), from the face sets the subdivision kept: weights stay on their
    # own finger.
    owner = {}

    for f, (prox, mid, dist) in enumerate(FACE_SETS.values()):
        for s in (prox, mid, dist):
            owner[s] = f + 1

    sets = hand.data.attributes[".sculpt_face_set"].data
    finger_of = hand.data.attributes.new("finger", "INT", "POINT")
    # The nails are one face set for all five: each nail face goes to the
    # finger whose fingertip set is nearest.
    tips = {}

    for p in hand.data.polygons:
        s = sets[p.index].value

        if s in (dist for _, _, dist in FACE_SETS.values()):
            tips.setdefault(owner[s], []).append(p.center.copy())

    tips = {f: sum(cs, Vector()) / len(cs) for f, cs in tips.items()}
    best = {}

    for p in hand.data.polygons:
        f = owner.get(sets[p.index].value, 0)

        if sets[p.index].value == NAILS:
            f = min(tips, key=lambda k: (tips[k] - p.center).length)

        for v in p.vertices:
            best[v] = max(best.get(v, 0), f) if f else best.get(v, 0)

    for v, f in best.items():
        finger_of.data[v].value = f

    # Which way each nail faces: the back of its finger, for the bones' roll.
    nails = {}

    for p in hand.data.polygons:
        if sets[p.index].value == NAILS:
            f = min(tips, key=lambda k: (tips[k] - p.center).length)
            nails[f] = nails.get(f, Vector()) + p.normal * p.area

    nails = {name: [round(c, 4) for c in nails[f + 1].normalized()] for f, name in enumerate(FACE_SETS)}

    out_dir = os.path.join(root_dir, "assets", "characters", "fp_arms", "source")
    os.makedirs(out_dir, exist_ok=True)
    points = {name: [list(frame @ p) for p in pts] for name, pts in found.items()}
    points = {name: [[round(c, 5) for c in p] for p in pts] for name, pts in points.items()}
    knuckles = [round(c, 5) for c in (frame @ knuckle)]

    with open(os.path.join(out_dir, "base_hand_joints.json"), "w") as f:
        json.dump({"source": "Blender Studio Human Base Meshes v1.4.1 (CC0), Hand - Realistic",
                   "knuckles": knuckles, "fingers": points, "nails": nails}, f, indent=1)

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "base_hand.blend"))
    print("BASEHAND verts %d faces %d knuckles %s tip %s" % (len(hand.data.vertices), len(hand.data.polygons), knuckles, points["middle"][3]))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1])
