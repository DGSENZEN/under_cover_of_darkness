"""The weathering rules (docs/superpowers/specs/2026-10-09-eclipse-vertex-paint-design.md,
section 3.2): what each vertex of a kit piece gets in its four vertex-paint
channels, from what weather.py measured round it.

    R grime and soot     rising damp from the floor below, inside corners, soot plumes
    G wear-through       how far the top material has worn to the one under it
    B tint               0.5 neutral; below, damp streaks under overhangs; above, sun-bleach
    A baked light        ambient occlusion, a little bounce on faces that look down

Plain numpy: every array is per vertex, in the piece's own space (Blender,
Z up, metres). Deterministic for a seed (seed_of the piece's name).
"""

import zlib

import numpy as np

# Rising damp and street dirt reach this high above the floor (m).
DAMP = 1.2
# How ragged the damp's top edge is (m) and how long its wobble (m).
DAMP_RAGGED = 0.25
DAMP_WOBBLE = 0.6
# Plaster wears through to this height above the floor (m).
FOOT_WEAR = 0.6
# A soot plume's height over its origin (m), its radius at the origin and the top.
SOOT_HEIGHT = 1.5
SOOT_RADIUS = (0.2, 0.5)
# Rain streaks: how far under an overhang they can hang (m), and the width
# of a streak's column along the wall (m).
STREAK_REACH = 2.0
STREAK_COLUMN = 0.25
# The share of columns that carry no streak at all.
STREAK_GAPS = 0.3
# The lab sun's toward-vector in Blender axes (style_lab.gd: the sun turned
# -50 degrees in x and -35 in y, Godot's +Z basis, Y up -> Z up).
SUN = np.array([-0.369, -0.527, 0.766]) / np.linalg.norm([-0.369, -0.527, 0.766])
# Edge proximity reaches (m), measured by weather.py: convex edges wear,
# concave ones gather dirt.
WEAR_REACH = 0.3
CAVITY_REACH = 0.12
# Patches: the noise that breaks every story into places, its cell size (m).
PATCH = 0.8


def seed_of(name):
    """A piece's seed, from its name."""
    return zlib.crc32(name.encode()) & 0x7FFFFFFF


def _hash(i, seed, salt=0.0):
    """0-1 per lattice point (any shape of integer-valued floats)."""
    return np.modf(np.abs(np.sin(i * 12.9898 + seed * 0.0001 + salt * 78.233) * 43758.5453))[0]


def _noise1(t, seed, cell, salt=0.0):
    """Smooth value noise along t, 0-1."""
    k = t / cell
    i = np.floor(k)
    f = k - i
    f = f * f * (3 - 2 * f)
    return _hash(i, seed, salt) * (1 - f) + _hash(i + 1, seed, salt) * f


def _patches(points, seed, salt):
    """Smooth 3D value noise over the piece, 0-1: where a story is told
    strongly and where weakly."""
    k = points / PATCH
    i = np.floor(k)
    f = k - i
    f = f * f * (3 - 2 * f)
    out = np.zeros(len(points))

    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                corner = i + (dx, dy, dz)
                h = _hash(corner[:, 0] * 1.0 + corner[:, 1] * 57.0 + corner[:, 2] * 113.0, seed, salt)
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out += h * w

    return out


def grime(points, floor_gap, concave, soot, seed):
    """R: rising damp under a ragged top edge, dirt in inside corners, soot
    plumes over each origin in `soot`."""
    along = points[:, 0] + points[:, 1]
    top = DAMP + DAMP_RAGGED * (2 * _noise1(along, seed, DAMP_WOBBLE, 1.0) - 1)
    damp = np.clip(1.0 - floor_gap / top, 0.0, 1.0)
    damp *= 0.8 + 0.2 * _patches(points, seed, 2.0)
    corners = 0.5 * np.asarray(concave, dtype=np.float64)
    smoke = np.zeros(len(points))

    for origin in soot:
        d = points - np.asarray(origin, dtype=np.float64)
        rise = d[:, 2]
        inside = (rise > 0) & (rise < SOOT_HEIGHT)
        radius = SOOT_RADIUS[0] + (SOOT_RADIUS[1] - SOOT_RADIUS[0]) * np.clip(rise / SOOT_HEIGHT, 0.0, 1.0)
        across = np.hypot(d[:, 0], d[:, 1])
        plume = (1 - rise / SOOT_HEIGHT) * np.clip(1 - across / radius, 0.0, 1.0)
        smoke = np.maximum(smoke, np.where(inside, 0.8 * plume, 0.0))

    return np.clip(1 - (1 - damp) * (1 - corners) * (1 - smoke), 0.0, 1.0)


def blend(points, floor_gap, convex, blendable, seed):
    """G: the top material worn through at the foot of walls and on convex
    edges, only where there is something under it."""
    along = points[:, 0] + points[:, 1]
    top = FOOT_WEAR + 0.2 * (2 * _noise1(along, seed, DAMP_WOBBLE, 3.0) - 1)
    foot = np.clip(1.0 - floor_gap / top, 0.0, 1.0)
    worn = np.maximum(foot, np.asarray(convex, dtype=np.float64))
    worn *= 0.7 + 0.3 * _patches(points, seed, 4.0)
    return np.where(blendable, np.clip(worn, 0.0, 1.0), 0.0)


def tint(points, normals, overhang_gap, seed):
    """B: 0.5 neutral. Rain streaks hang down vertical faces under an
    overhang (darker, below 0.5); faces that look up or toward the sun are
    bleached (above 0.5)."""
    column = np.floor((points[:, 0] + points[:, 1]) / STREAK_COLUMN)
    strength = 0.3 + 0.7 * _hash(column, seed, 5.0)
    strength = np.where(_hash(column, seed, 6.0) < STREAK_GAPS, 0.0, strength)
    length = 0.6 + (STREAK_REACH - 0.6) * _hash(column, seed, 7.0)
    upright = np.abs(normals[:, 2]) < 0.5
    hanging = upright & (overhang_gap < length)
    gap = np.where(np.isfinite(overhang_gap), overhang_gap, length)
    streak = np.where(hanging, strength * (1 - gap / length), 0.0)
    bleach = 0.2 * np.maximum(normals[:, 2], 0.0) + 0.1 * np.maximum(normals @ SUN, 0.0)
    shift = (bleach - 0.35 * streak) * (0.7 + 0.3 * _patches(points, seed, 8.0))
    return np.clip(0.5 + shift, 0.0, 1.0)


def light(open_sky, normals):
    """A: how much of the sky a vertex sees, with a little bounce from the
    ground on faces that look down. Never above 1."""
    seen = np.clip(np.asarray(open_sky, dtype=np.float64), 0.0, 1.0) ** 0.8
    bounce = 0.12 * np.maximum(-normals[:, 2], 0.0) * (1 - seen)
    return np.clip(seen + bounce, 0.0, 1.0)


def rules(points, normals, floor_gap, overhang_gap, convex, concave, open_sky, blendable, soot, seed):
    """Every vertex's RGBA (n, 4), 0-1."""
    points = np.asarray(points, dtype=np.float64)
    normals = np.asarray(normals, dtype=np.float64)
    out = np.stack([grime(points, floor_gap, concave, soot, seed),
                    blend(points, floor_gap, convex, blendable, seed),
                    tint(points, normals, overhang_gap, seed),
                    light(open_sky, normals)], axis=1)
    return np.clip(out, 0.0, 1.0)
