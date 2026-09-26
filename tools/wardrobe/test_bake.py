"""The bake's passes (bake.py) on tiny parts, and what the bake and the
export write over.

    tools/wardrobe/wardrobe.sh test

Each case bakes a small clean part and checks what the bake saw, or writes
over a file and checks what was kept. Runs in a factory-fresh Blender,
headless (Cycles). Exit code 1 on any failure.
"""

import os
import sys

# No __pycache__ beside the tools (Blender would write one each run).
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import pathlib  # noqa: E402
import tempfile  # noqa: E402

import numpy as np  # noqa: E402

import bake  # noqa: E402
import common  # noqa: E402
import export  # noqa: E402


def fresh():
    """An empty scene, set up to bake (on the CPU: case_cpu)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bake.cycles(gpu=False)


def plate(name, z=0.0):
    """A flat 20 cm square facing up at height z, unwrapped, a garment."""
    bpy.ops.mesh.primitive_plane_add(size=0.2, location=(0.0, 0.0, z))
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=True)
    common.set_faces(obj, 1, 1, 0.004, False, False, (0.5, 0.5, 0.5))
    return obj


def occlusion(obj):
    low, high = bake.bounds(obj)
    passes = bake.data_passes(obj, 32, low, high)
    return passes["ao"][passes["covered"]]


def case_alone():
    """Nothing over a lone flat part: nothing darkens it (the part itself,
    under the copy the bake works on, must not)."""
    fresh()
    ao = occlusion(plate("Part"))
    return [] if ao.size and ao.mean() > 0.95 else ["ao: a lone flat part baked occluded (mean %.2f)" % ao.mean()]


def case_others():
    """Another part 5 cm over it (a hat over a coif): each part is baked on
    its own, since it may be worn without the other."""
    fresh()
    part = plate("Part")
    plate("Over", z=0.05)
    ao = occlusion(part)
    return [] if ao.size and ao.mean() > 0.95 else ["ao: another part darkened this one (mean %.2f)" % ao.mean()]


def kept(write, name):
    """A file written over by `write`: its old bytes kept in the backup
    folder (a repainted texture, a hand-edited JSON)."""
    folder = pathlib.Path(tempfile.mkdtemp(prefix="wardrobe_kept_"))
    common.BACKUP = folder / "backup"
    path = folder / name
    path.write_bytes(b"painted by hand")
    write(path)
    copies = list(common.BACKUP.glob("*")) if common.BACKUP.exists() else []
    return [] if any(c.read_bytes() == b"painted by hand" for c in copies) else ["kept: %s written over, no copy kept" % name]


def case_png():
    """The bake writes over a texture: the one there (maybe repainted by
    hand) is kept first."""
    fresh()
    return kept(lambda path: bake.save_png(np.zeros((4, 4, 3)), str(path)), "face.png")


def case_json():
    """The export writes over a part's JSON: the one there is kept first."""
    fresh()
    return kept(lambda path: export.write_json(path, {"piece": "test"}), "piece.json")


def case_wrapped():
    """Leg wraps: bands wound on the diagonal, 3 cm apart (10 dark seams up
    30 cm of shin)."""
    import fabrics

    z = np.linspace(0.3, 0.6, 1200)
    points = np.stack([np.full_like(z, 0.1), np.full_like(z, -0.05), z], axis=1)
    normals = np.tile([0.0, -1.0, 0.0], (len(z), 1))
    shade = fabrics.paint(np.full(len(z), fabrics.WRAPPED), points, normals, np.full((len(z), 3), 0.5))[:, 0] / 0.5
    dark = shade < np.percentile(shade, 15)
    seams = int(np.count_nonzero(dark[1:] & ~dark[:-1]))
    return [] if 9 <= seams <= 11 else ["wrapped: %d dark seams in 30 cm (want 10)" % seams]


def case_hair():
    """Hair: strands that run with it (down and back), so the shade changes
    far faster across them than along them."""
    import fabrics

    flow = np.array([0.0, 0.5, -1.0]) / np.linalg.norm([0.0, 0.5, -1.0])
    across = np.cross([1.0, 0.0, 0.0], flow)
    start = np.array([0.08, 0.0, 1.72])
    steps = np.linspace(0.0, 0.03, 600)[:, None]
    normals = np.tile([1.0, 0.0, 0.0], (len(steps), 1))

    def rough(points):
        shade = fabrics.paint(np.full(len(points), fabrics.HAIR), points, normals, np.full((len(points), 3), 0.5))[:, 0]
        return float(np.mean(np.abs(np.diff(shade))))

    along, over = rough(start + steps * flow), rough(start + steps * across)
    return [] if over > 3.0 * along and over > 0.0 else ["hair: across %.4f, along %.4f" % (over, along)]


def case_plates():
    """A pauldron's trim (its build's notes): each lame's edge bright over a
    dark line, the rolled rim bright; only iron, only on the plate."""
    import fabrics

    fresh()
    obj = plate("Outfit")
    obj["wr_details"] = common.dump({"plates": [{"joint": [0.2, 0.0, 1.5], "axis": [1.0, 0.0, 0.0], "reach": 0.14,
                                                 "lames": [0.05, 0.1]}]})
    x = np.linspace(0.15, 0.4, 2500)
    # Along his left arm, the same along his right (mirrored), and at his waist.
    rows = [np.stack([x, np.zeros_like(x), np.full_like(x, 1.58)], axis=1),
            np.stack([-x, np.zeros_like(x), np.full_like(x, 1.58)], axis=1),
            np.stack([x, np.zeros_like(x), np.full_like(x, 1.0)], axis=1)]
    position = np.stack(rows)
    messages = []

    for fabric, want in ((fabrics.IRON, True), (fabrics.MAIL, False)):
        passes = {"position": position, "fabric": np.full(position.shape[:2], fabric)}
        out = bake.trim(obj, passes, np.full(position.shape, 0.5))[..., 0] / 0.5

        def at(row, along):
            return out[row, int(np.argmin(np.abs(x - 0.2 - along)))]

        painted = [at(r, 0.047) > 1.2 and at(r, 0.053) < 0.8 and at(r, 0.097) > 1.2 and at(r, 0.143) > 1.5
                   and abs(at(r, 0.02) - 1.0) < 1e-6 for r in (0, 1)]
        untouched = bool(np.all(np.abs(out[2] - 1.0) < 1e-6))

        if want and not (all(painted) and untouched):
            messages.append("plates: iron painted %s, waist untouched %s" % (painted, untouched))
        elif not want and not np.all(np.abs(out - 1.0) < 1e-6):
            messages.append("plates: mail was painted")

    return messages


def case_fur():
    """Fur: tufts about 1.5 cm across (along a line the shade changes far
    faster than wool's), their tips catching the light (lighter facing up
    than facing down)."""
    import fabrics

    x = np.linspace(0.0, 0.06, 600)
    points = np.stack([x + 0.1, np.full_like(x, -0.12), np.full_like(x, 1.4)], axis=1)
    base = np.full((len(x), 3), 0.5)

    def shades(fabric, normal):
        return fabrics.paint(np.full(len(x), fabric), points, np.tile(normal, (len(x), 1)), base)[:, 0]

    fur, wool = (float(np.mean(np.abs(np.diff(shades(f, [0.0, -1.0, 0.0]))))) for f in (fabrics.FUR, fabrics.WOOL))
    up, down = (float(shades(fabrics.FUR, n).mean()) for n in ([0.0, 0.0, 1.0], [0.0, 0.0, -1.0]))
    ok = fur > 2.0 * wool and up > 1.1 * down
    return [] if ok else ["fur: along 6 cm %.4f (wool %.4f); facing up %.3f, down %.3f" % (fur, wool, up, down)]


def case_studs():
    """A studded part (its build's notes): iron dots with a dark ring round
    each, in rows `spacing` apart round his trunk, on that part alone."""
    import fabrics

    fresh()
    obj = plate("Outfit")
    obj["wr_details"] = common.dump({"studs": [{"part": 2, "spacing": 0.05, "centre_y": 0.0}]})
    # Across his chest through a row of studs: the jerkin (part 2), then the
    # same line on another part (3).
    x = np.linspace(-0.1, 0.1, 800)
    line = np.stack([x, np.full_like(x, -0.15), np.full_like(x, 1.30)], axis=1)
    position = np.stack([line, line])
    passes = {"position": position, "fabric": np.full(position.shape[:2], fabrics.LEATHER),
              "part": np.stack([np.full(len(x), 2), np.full(len(x), 3)])}
    out = bake.trim(obj, passes, np.full(position.shape, 0.5))[..., 0] / 0.5
    ok = out[0].max() > 1.3 and out[0].min() < 0.8 and bool(np.all(np.abs(out[1] - 1.0) < 1e-6))
    return [] if ok else ["studs: on the jerkin %.2f..%.2f; elsewhere %.2f..%.2f" % (out[0].min(), out[0].max(),
                                                                                      out[1].min(), out[1].max())]


def case_slashes():
    """A puff's slashes (its build's notes): `count` stripes of the lining
    round his arm between `from` and `to`, on that part alone (his right arm
    too, mirrored), in the lining's colour and out of the dye."""
    import fabrics

    fresh()
    obj = plate("Outfit")
    gold = [0.78, 0.60, 0.22]
    obj["wr_details"] = common.dump({"slashes": [{"part": 5, "joint": [0.2, 0.0, 1.45], "axis": [1.0, 0.0, 0.0],
                                                  "from": 0.0, "to": 0.15, "count": 6, "colour": gold}]})
    phi = np.linspace(0.0, 2.0 * np.pi, 720, endpoint=False)
    ring = np.stack([np.full_like(phi, 0.27), 0.05 * np.sin(phi), 1.45 + 0.05 * np.cos(phi)], axis=1)
    right = ring * np.array([-1.0, 1.0, 1.0])
    position = np.stack([ring, right, ring])
    passes = {"position": position, "fabric": np.full(position.shape[:2], fabrics.WOOL),
              "part": np.stack([np.full(len(phi), 5), np.full(len(phi), 5), np.full(len(phi), 1)])}
    slashed, lining = bake.slashes(obj, passes)
    stripes = [int(np.count_nonzero(row & ~np.roll(row, 1))) for row in slashed]
    coloured = np.allclose(lining[0][slashed[0]], bake.to_linear(np.array(gold)), atol=1e-4) if slashed[0].any() else False
    ok = stripes == [6, 6, 0] and coloured
    return [] if ok else ["slashes: stripes %s (want 6, 6, 0), lining coloured %s" % (stripes, coloured)]


def case_tint():
    """Two faces' brows (copies sharing the Quaternius material) tinted each
    their own colour: one face's tint never reaches the other's."""
    fresh()
    material = bpy.data.materials.new("Brows")
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    texture = nodes.new("ShaderNodeTexImage")
    links.new(texture.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    brows = []

    for name in ("High_a_brows", "High_b_brows"):
        obj = plate(name)
        obj.data.materials.append(material)
        brows.append(obj)

    bake.tint(brows[0], (0.16, 0.11, 0.08))
    bake.tint(brows[1], (0.62, 0.60, 0.57))
    mixes = [sum(1 for n in o.data.materials[0].node_tree.nodes if n.type == "MIX") for o in brows]
    shared = brows[0].data.materials[0] == brows[1].data.materials[0]
    return [] if mixes == [1, 1] and not shared else ["tint: multiplies %s, one material %s" % (mixes, shared)]


def case_gear_bones():
    """A headgear piece's GLB carries its own cloth bones and no other
    piece's (headgear.blend has one armature for every piece: a coif would
    carry the hood's tail), and the export leaves the file as it found it."""
    import json
    import struct

    fresh()
    folder = pathlib.Path(tempfile.mkdtemp(prefix="wardrobe_gear_bones_"))
    common.BACKUP = folder / "backup"
    data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(arm)
    common.select_only([arm], active=arm)
    bpy.ops.object.mode_set(mode="EDIT")
    bones = {}

    for name, head, tail, parent in (("root", (0, 0, 0), (0, 0, 0.1), None), ("Head", (0, 0, 1.6), (0, 0, 1.8), "root"),
                                     ("cloth_hood_tail_1", (0, 0.1, 1.7), (0, 0.1, 1.5), "Head"),
                                     ("cloth_other_1", (0.1, 0, 1.7), (0.1, 0, 1.5), "Head")):
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        bone.parent = bones.get(parent)
        bones[name] = bone

    bpy.ops.object.mode_set(mode="OBJECT")
    piece = plate("Gear_hood", z=1.7)
    common.group(piece, "Head", 1.0)
    piece.parent = arm
    piece.modifiers.new("Armature", "ARMATURE").object = arm
    path = folder / "hood.glb"
    root, common.ROOT = common.ROOT, folder

    try:
        export.glb(piece, arm, path, cloth=["cloth_hood_tail_1"])
    finally:
        common.ROOT = root

    blob = path.read_bytes()
    doc = json.loads(blob[20:20 + struct.unpack_from("<I", blob, 12)[0]])
    joints = {doc["nodes"][j]["name"] for skin in doc.get("skins", []) for j in skin["joints"]}
    kept = sorted(b.name for b in arm.data.bones)
    messages = []

    if "cloth_other_1" in joints or not {"Head", "cloth_hood_tail_1"} <= joints:
        messages.append("gear bones: the GLB's joints are %s" % sorted(joints))

    if kept != ["Head", "cloth_hood_tail_1", "cloth_other_1", "root"] or piece.modifiers["Armature"].object != arm \
            or piece.parent != arm or arm.name != "Armature":
        messages.append("gear bones: the file was left changed (bones %s, rig %s)" % (kept, piece.modifiers["Armature"].object))

    return messages


def case_cpu():
    """The tests bake on the CPU: their scenes are tiny, and compiling the
    Metal kernels in every fresh Blender now and then crashed it (Cycles'
    shader cache, a double free: an abort and a crash report, Sept 26)."""
    fresh()
    device = bpy.context.scene.cycles.device
    return [] if device == "CPU" else ["cpu: the tests bake on %s" % device]


CASES = {"cpu": case_cpu, "alone": case_alone, "others": case_others, "png": case_png, "json": case_json,
         "wrapped": case_wrapped, "hair": case_hair, "plates": case_plates, "tint": case_tint,
         "gear_bones": case_gear_bones, "fur": case_fur, "studs": case_studs, "slashes": case_slashes}


def main():
    failed = 0

    for name, run in CASES.items():
        try:
            messages = run()
        except Exception as error:  # a crash is a failure of that case
            messages = ["crash: %r" % error]

        print("%s %s%s" % ("PASS" if not messages else "FAIL", name, "" if not messages else ": %s" % messages))
        failed += 1 if messages else 0

    print("bake: %d/%d" % (len(CASES) - failed, len(CASES)))
    sys.exit(1 if failed else 0)


main()
