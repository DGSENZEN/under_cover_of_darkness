"""Whether two placed pieces' meshes pass through each other: their faces
from the kits' exports (assets/eclipse/source/<kit>_faces.json, Godot axes),
placed as the dressing places them, and the edges of one counted where they
pass through the other's triangles (a figure standing in a drift of
candles; not two boxes merely near)."""

import json
import math
from pathlib import Path

import numpy as np

SOURCE = Path(__file__).resolve().parents[2] / "assets" / "eclipse" / "source"
_faces = {}


def triangles(kit, piece):
    """A piece's faces as triangles (n, 3, 3), in its own axes."""
    if kit not in _faces:
        _faces[kit] = json.loads((SOURCE / (kit + "_faces.json")).read_text())["objects"]

    out = []

    for f in _faces[kit].get(piece, []):
        pts = f["points"]
        out += [[pts[0], pts[k], pts[k + 1]] for k in range(1, len(pts) - 1)]

    return np.array(out, dtype=float).reshape(-1, 3, 3)


def placed(p):
    """A dressing piece's triangles where it stands (its yaw, stretch, spot)."""
    t = triangles(p["kit"], p["piece"])
    a = math.radians(p["yaw"])
    c, s = math.cos(a), math.sin(a)
    x, y, z = t[..., 0] * p.get("stretch", 1.0), t[..., 1], t[..., 2]
    return np.stack([x * c + z * s + p["at"][0], y + p["at"][1], -x * s + z * c + p["at"][2]], axis=-1)


def _through(a, b):
    """Edges of a's triangles passing through b's triangles."""
    if len(a) == 0 or len(b) == 0:
        return 0

    lo, hi = b.reshape(-1, 3).min(0) - 0.01, b.reshape(-1, 3).max(0) + 0.01
    e0 = np.concatenate([a[:, 0], a[:, 1], a[:, 2]])
    e1 = np.concatenate([a[:, 1], a[:, 2], a[:, 0]])
    near = ~((np.maximum(e0, e1) < lo).any(1) | (np.minimum(e0, e1) > hi).any(1))
    e0, e1 = e0[near], e1[near]

    if len(e0) == 0:
        return 0

    d = e1 - e0
    v0, e_1, e_2 = b[:, 0], b[:, 1] - b[:, 0], b[:, 2] - b[:, 0]
    p = np.cross(d[:, None, :], e_2[None, :, :])
    det = np.einsum("ijk,jk->ij", p, e_1)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
    t = e0[:, None, :] - v0[None, :, :]
    u = np.einsum("ijk,ijk->ij", t, p) * inv
    q = np.cross(t, e_1[None, :, :])
    v = np.einsum("ik,ijk->ij", d, q) * inv
    w = np.einsum("jk,ijk->ij", e_2, q) * inv
    return int((ok & (u > 1e-4) & (v > 1e-4) & (u + v < 1 - 1e-4) & (w > 1e-4) & (w < 1 - 1e-4)).sum())


def crossings(p, q):
    """How many edges of the two pieces pass through the other (0: apart, or
    only touching)."""
    a, b = placed(p), placed(q)
    return _through(a, b) + _through(b, a)
