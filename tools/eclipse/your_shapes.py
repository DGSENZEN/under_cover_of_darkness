"""The user's shapes kept through a kit's rebuild (docs/superpowers/plans/2026-10-30-metro-station.md, Task 2): the big
pieces are built with the user in their live Blender, and they may push vertices in a piece's .blend themselves.

- `stamp`: each piece's shape as built, fingerprinted on it as it is saved (export_piece);
- `harvest`: read before the next build (harvest.py, run by lab.sh on the piece's last .blend): every piece whose
  shape no longer matches its fingerprint is the user's, written to YOURS/<kit>/<piece>.npz;
- `keep`: in the next build, before it is unwrapped and gated (export_piece), each piece with a shape of the user's
  takes it in place of the generated one, its slots kept. A shape for a piece the script no longer builds is
  reported and left where it is.

Only shapes: the build unwraps and paints every piece again. (Not for a weathered piece, which the build densifies.)
"""

import hashlib
from pathlib import Path

import bpy
import numpy as np

YOURS = Path(__file__).resolve().parents[2] / "assets" / "eclipse" / "source" / "yours"


def _shape(o):
    """Its vertices, each face's size and the vertices round each face."""
    mesh = o.data
    co = np.zeros(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("co", co)
    sizes = np.zeros(len(mesh.polygons), dtype=np.int32)
    mesh.polygons.foreach_get("loop_total", sizes)
    loops = np.zeros(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", loops)
    return co.reshape(-1, 3), sizes, loops


def fingerprint(o):
    """Its shape's hash: its vertices to a tenth of a millimetre, its faces."""
    co, sizes, loops = _shape(o)
    h = hashlib.sha1()
    h.update(np.round(co * 10000.0).astype(np.int64).tobytes())
    h.update(sizes.tobytes())
    h.update(loops.tobytes())
    return h.hexdigest()


def stamp(objects):
    for o in objects:
        o["built"] = fingerprint(o)


def harvest(objects, kit):
    """The pieces the user has reshaped since they were built, written out; their names."""
    touched = []

    for o in objects:
        if "built" not in o or o["built"] == fingerprint(o):
            continue

        co, sizes, loops = _shape(o)
        materials = np.zeros(len(o.data.polygons), dtype=np.int32)
        o.data.polygons.foreach_get("material_index", materials)
        smooth = np.zeros(len(o.data.polygons), dtype=bool)
        o.data.polygons.foreach_get("use_smooth", smooth)
        folder = YOURS / kit
        folder.mkdir(parents=True, exist_ok=True)
        np.savez_compressed(folder / (o.name + ".npz"), co=co, sizes=sizes, loops=loops, materials=materials,
                            smooth=smooth)
        touched.append(o.name)

    return touched


def keep(objects, kit):
    """Each piece the user has reshaped given their shape, its slots kept; their names."""
    folder = YOURS / kit

    if not folder.exists():
        return []

    by_name = {o.name: o for o in objects}
    kept = []

    for path in sorted(folder.glob("*.npz")):
        o = by_name.get(path.stem)

        if o is None:
            print("yours: %s/%s no longer built" % (kit, path.stem))
            continue

        shape = np.load(path)
        faces = np.split(shape["loops"], np.cumsum(shape["sizes"])[:-1])
        mesh = bpy.data.meshes.new(o.data.name + "_yours")
        mesh.from_pydata([tuple(v) for v in shape["co"]], [], [list(f) for f in faces])

        for material in o.data.materials:
            mesh.materials.append(material)

        mesh.polygons.foreach_set("material_index", shape["materials"])
        mesh.polygons.foreach_set("use_smooth", shape["smooth"])
        mesh.update()
        old = o.data
        o.data = mesh

        if old.users == 0:
            bpy.data.meshes.remove(old)

        kept.append(o.name)

    return kept
