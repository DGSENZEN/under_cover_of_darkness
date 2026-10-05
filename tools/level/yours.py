"""Reads your edits out of the workshops (workshop.py) into yours.json
(yours_data): each kit mesh whose shape, faces, UVs or slots differ from the
one it was built from, and each piece whose colliders were moved, scaled,
turned, added, deleted or given another surface. A mesh marked kit_revert
is given back to its generator. A piece edited in two workshops is refused
(revert it in one).

    Blender -b --factory-startup --python tools/level/yours.py -- <workshop.blend>... [--out yours.json]
"""

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402

import common  # noqa: E402
import geo  # noqa: E402
import workshop  # noqa: E402
import yours_data  # noqa: E402

TOLERANCE = 1e-4


def _flat(m):
    return [v for row in m for v in row]


def collider_from(rel, surface):
    """A unit cube's matrix in its piece's frame (Blender's) as a collider
    record in the piece's (Godot's)."""
    blender = [[rel[r][c] for c in range(3)] for r in range(3)]
    godot = geo.from_blender_basis(blender)
    sizes = [sum(godot[r][c] ** 2 for r in range(3)) ** 0.5 for c in range(3)]
    basis = [[godot[r][c] / sizes[c] if sizes[c] > 1e-9 else (1.0 if r == c else 0.0) for c in range(3)] for r in range(3)]

    # (Mirrored by a negative scale: the box is the same box.)
    if Matrix(basis).determinant() < 0.0:
        basis = [[basis[r][0], basis[r][1], -basis[r][2]] for r in range(3)]

    centre = geo.from_blender(list(rel.translation))
    angles = geo.yxz_angles(basis)
    return [round(v, 5) for v in centre] + [round(s, 5) for s in sizes] + [surface] + [round(a, 4) for a in angles]


def placed(obj):
    """An object's matrix from its own transform and its parents' (not the
    file's last evaluated one: a file saved in the background holds stale
    ones)."""
    m = obj.matrix_basis.copy()

    while obj.parent is not None:
        m = obj.parent.matrix_basis @ obj.matrix_parent_inverse @ m
        obj = obj.parent

    return m


def piece_cols(row, boxes):
    """(changed, colliders, occlusion_exclude) of a kit piece's row object
    and its collider boxes as they are now."""
    base = json.loads(row["kit_cols_base"])
    hidden = set(json.loads(row.get("kit_cols_exclude", "[]")))
    inverse = placed(row).inverted()
    changed = len(boxes) != len(base)
    cols, exclude = [], []

    def order(box):
        # (The boxes made with the piece first, in their order; then yours.)
        if box.name == box.get("collider_name"):
            return (0, box.get("collider_index", 0), box.name)

        return (1, 0, box.name)

    for box in sorted(boxes, key=order):
        # (In its piece's own frame: a row far down the file holds its
        # place only to a few tenths of a millimetre.)
        rel = box.matrix_parent_inverse @ box.matrix_basis if box.parent == row else inverse @ placed(box)
        index = box.get("collider_index")
        surface = str(box.get("surface", "stone"))
        occluder = bool(box.get("occluder", 1))
        original = index is not None and box.name == box.get("collider_name") and 0 <= index < len(base)
        was = (base[index][6] if len(base[index]) > 6 else surface) if original else None
        # (Glass never hides what is behind it, listed or not.)
        same = (original and all(abs(a - b) < TOLERANCE for a, b in zip(_flat(rel), box["m"]))
                and surface == was and occluder == (index not in hidden and was != "glass"))

        if same:
            cols.append(base[index])
        else:
            changed = True
            cols.append(collider_from(rel, surface))

        if not occluder and surface != "glass":
            exclude.append(len(cols) - 1)

    return changed, cols, exclude


def same_cols(a, b):
    """Two sets of colliders the same boxes (to a millimetre), in order."""
    if len(a) != len(b):
        return False

    for x, y in zip(a, b):
        if (x[6] if len(x) > 6 else "") != (y[6] if len(y) > 6 else ""):
            return False

        if any(abs(p - q) > 1e-3 for p, q in zip(_flat(workshop.collider_matrix(x)), _flat(workshop.collider_matrix(y)))):
            return False

    return True


def read(path):
    """{piece: {"mesh": ..., "base": ..., "cols": ..., "occlusion_exclude": ...}}
    edited in the workshop at `path`; and its problems."""
    bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False)
    known = set(common.SLOT_COLOURS) | set(workshop.slot_photos())
    out, problems = {}, []
    reverted = set()

    for mesh in bpy.data.meshes:
        if not mesh.name.startswith(common.KIT_PREFIX) or "kit_base" not in mesh:
            continue

        piece = mesh.name[len(common.KIT_PREFIX):]

        if mesh.get("kit_revert"):
            reverted.add(piece)
            continue

        shape = workshop.mesh_hash(mesh)

        # (Untouched; or the generator's own again.)
        if shape == mesh["kit_base"] or shape == mesh.get("kit_generated"):
            continue

        unknown = sorted({workshop.base_name(m.name) for m in mesh.materials if m is not None} - known)

        if unknown or any(m is None for m in mesh.materials):
            problems.append("%s: %s has materials that are not the kit's slots: %s" % (path.name, piece, ", ".join(unknown) or "an empty slot"))

        base = mesh["kit_generated"] if mesh.get("kit_from") else mesh["kit_base"]
        out[piece] = {"mesh": True, "base": base}

    boxes = {}

    for obj in bpy.data.objects:
        if "collider_of" in obj:
            boxes.setdefault(obj["collider_of"], []).append(obj)

    for row in bpy.data.objects:
        piece = row.get("kit_piece")

        if piece is None or "kit_cols_base" not in row or piece in reverted:
            continue

        changed, cols, exclude = piece_cols(row, boxes.get(piece, []))
        generated, generated_exclude = json.loads(row.get("kit_cols_generated", "[null, null]"))

        # (The generator's own again: not yours.)
        if generated is not None and sorted(exclude) == sorted(generated_exclude) and same_cols(cols, generated):
            continue

        if changed or row.get("kit_cols_yours"):
            out.setdefault(piece, {}).update(cols=cols, occlusion_exclude=exclude)

    return out, problems


def harvest(paths, to=None):
    if to is None and yours_data.path() is None:
        print("yours: off (LEVEL_YOURS)")
        return {}

    result, problems = {}, []

    for path in paths:
        found, trouble = read(Path(path))
        problems += trouble
        name = Path(path).name

        for piece, mine in found.items():
            entry = result.setdefault(piece, {"file": None, "mesh": False, "cols": None, "cols_file": None})

            if mine.get("mesh"):
                if entry["file"]:
                    problems.append("%s's mesh is edited in both %s and %s: set kit_revert on one" % (piece, entry["file"], name))

                entry.update(file=name, mesh=True, base=mine["base"])

            if "cols" in mine:
                if entry["cols_file"]:
                    problems.append("%s's colliders are edited in both %s and %s: set kit_revert on one" % (piece, entry["cols_file"], name))

                entry.update(cols=mine["cols"], occlusion_exclude=mine["occlusion_exclude"], cols_file=name)

    if problems:
        common.fail("yours:\n  " + "\n  ".join(problems))

    target = to or yours_data.path()
    yours_data.save(result, target)
    print("yours: %d meshes, %d sets of colliders -> %s" % (sum(1 for e in result.values() if e["mesh"]),
                                                           sum(1 for e in result.values() if e["cols"] is not None), target))
    return result


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    to = None

    if "--out" in args:
        i = args.index("--out")
        to = args[i + 1]
        args = args[:i] + args[i + 2:]

    harvest(args, to)
