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
    """An empty scene, set up to bake."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bake.cycles()


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


CASES = {"alone": case_alone, "others": case_others, "png": case_png, "json": case_json,
         "wrapped": case_wrapped, "hair": case_hair, "plates": case_plates, "tint": case_tint}


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
